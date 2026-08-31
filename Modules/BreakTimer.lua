local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.BreakTimer then
		return
	end

	-- Both render their own break display, and competing with it means double bars. Bailing also
	-- makes the wire the sole ingest path, which is fine: a solo /break dispatches locally inside the
	-- boss mod and sends nothing, but without a boss mod there is no /break to issue.
	-- ## OptionalDeps in the TOC is what makes this readable this early.
	if C_AddOns.IsAddOnLoaded("BigWigs") or C_AddOns.IsAddOnLoaded("DBM-Core") then
		return
	end

	C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
	C_ChatInfo.RegisterAddonMessagePrefix("D5")

	local BREAK_ICON_FILE_ID = 134062 -- inv_misc_fork&knife, the icon BigWigs' own break bar uses
	local BREAK_LABEL = "Break"
	local OFFSET_TOLERANCE = 0.01

	-- Long track alpha from EncounterTimelineTrackAlphaCurve, and the frame level bump a Medium
	-- severity event gets from EncounterTimelineSeverityFrameLevelCurve.
	local LONG_TRACK_ALPHA = 0.6
	local MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET = 20

	local Phase = {
		Parked = 1,
		Timeline = 2,
		Fallback = 3,
	}

	local currentPhase = nil
	local breakEndTime = nil
	local breakSender = nil
	local scriptEventId = nil
	local hasValidatedLayout = false
	local isLayoutMismatched = false
	local lastStartTime = 0
	local updateTicker = nil
	local parkedIcon = nil
	local fallbackFrame = nil

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_ACTIVATED")
	eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_DEACTIVATED")

	-------------------------------------------------------------------------------
	-- Track layout replication

	-- Replicates EncounterTimelineTrackLayoutMixin:SetTrackList plus :UpdateLayout without touching
	-- Blizzard's frame, because the track view's OnUpdate does not run while an ancestor is hidden:
	-- cold, tracksByID is empty, the layout is dirty and CalculateEventOffset throws.
	---@return table<number, table> offsetsByTrack, number primaryAxisExtent
	local function ComputeTrackLayout()
		local layoutDefaults = EncounterTimelineTrackLayoutDefaults
		local trackView = EncounterTimeline:GetTrackView()
		local sortedEventExtent = trackView:GetSortedEventExtent()
		local paddingStart, paddingEnd = trackView:GetPrimaryAxisPadding()
		local shortTrackExtent = GetAtlasSize("combattimeline-line-left") + GetAtlasSize("combattimeline-line-right")
		local trackList = C_EncounterTimeline.GetTrackList()
		local offsetsByTrack = {}
		local offset = paddingStart or layoutDefaults.PrimaryAxisStartPadding

		-- SetTrackList walks the list with ipairs_reverse, building longest track to shortest.
		for index = #trackList, 1, -1 do
			local trackInfo = trackList[index]
			local track = trackInfo.id

			if trackInfo.type == Enum.EncounterTimelineTrackType.Sorted then
				local maximumEventCount = trackInfo.maximumEventCount or math.huge

				-- Per-track padding is not part of the C track list; OnTracksUpdated hardcodes this one.
				offset = offset + (track == Enum.EncounterTimelineTrack.Queued and 10 or 0)

				offsetsByTrack[track] = {
					offsetStart = offset,
					maximumEventCount = maximumEventCount,
					sortDirection = trackInfo.sortDirection,
					sortedEventExtent = sortedEventExtent,
				}

				offset = offset + maximumEventCount * sortedEventExtent
				offsetsByTrack[track].offsetEnd = offset
			elseif trackInfo.type == Enum.EncounterTimelineTrackType.Linear then
				offsetsByTrack[track] = { offsetStart = offset }

				-- Likewise the extents, and CalculateMediumTrackExtent is a bare literal on their side.
				offset = offset + (track == Enum.EncounterTimelineTrack.Medium and 55 or shortTrackExtent)
				offsetsByTrack[track].offsetEnd = offset
			end
		end

		return offsetsByTrack, offset + (paddingEnd or layoutDefaults.PrimaryAxisEndPadding)
	end

	---@param trackOffsets table
	---@param trackSortIndex number
	---@return number
	local function ComputeSortedEventOffset(trackOffsets, trackSortIndex)
		local index

		if trackOffsets.sortDirection == Enum.EncounterTimelineEventSortDirection.Ascending then
			index = trackSortIndex
		else
			index = trackOffsets.maximumEventCount - trackSortIndex + 1
		end

		return trackOffsets.offsetStart + index * trackOffsets.sortedEventExtent
	end

	---@return number
	local function GetHandoffThreshold()
		return C_EncounterTimeline.GetTrackMaxEventDuration(Enum.EncounterTimelineTrack.Long)
	end

	-------------------------------------------------------------------------------
	-- Display phases

	---@param remainingSeconds number
	local function UpdateFallbackText(remainingSeconds)
		fallbackFrame.NameText:SetText(breakSender and (BREAK_LABEL .. " - " .. breakSender) or BREAK_LABEL)
		fallbackFrame.TimeText:SetText(SecondsToClock(remainingSeconds))
	end

	local function ReleaseTimeline()
		if parkedIcon ~= nil then
			parkedIcon:Hide()
			parkedIcon:SetParent(UIParent)
			parkedIcon:ClearAllPoints()
		end

		if EncounterTimeline ~= nil then
			EncounterTimeline:SetExplicitlyShown(false)
		end
	end

	local function EnterFallbackPhase()
		ReleaseTimeline()

		if fallbackFrame == nil then
			fallbackFrame = CreateFrame("Frame", nil, UIParent, "XephUIBreakTimerFallbackTemplate")
			fallbackFrame.IconContainer.IconTexture:SetTexture(BREAK_ICON_FILE_ID)
			fallbackFrame:SetPoint("TOP", UIParent, "TOP", 0, -220)
		end

		UpdateFallbackText(breakEndTime - GetTime())
		fallbackFrame:Show()

		currentPhase = Phase.Fallback
	end

	local function EnterParkedPhase()
		if fallbackFrame ~= nil then
			fallbackFrame:Hide()
		end

		if parkedIcon == nil then
			parkedIcon = CreateFrame("Frame", nil, UIParent, "XephUIBreakTimerParkedIconTemplate")
			parkedIcon.IconContainer.IconTexture:SetTexture(BREAK_ICON_FILE_ID)
		end

		-- EvaluateVisibility only shows the timeline outside an encounter once it has visible events
		-- or event frames, and an event above the long track's maximum duration has neither. Forcing
		-- it shown is also what gets the track view to build its layout, which the validation below
		-- needs. This writes a field on Blizzard's frame from our tainted stack.
		EncounterTimeline:SetExplicitlyShown(true)

		do
			local trackView = EncounterTimeline:GetTrackView()
			local orientation = trackView:GetTrackOrientation()
			local frameLevel = trackView:GetFrameLevel()

			-- StartPrimaryAxisSortedTranslation synthesizes an entry offset one slot further from the
			-- medium end than the resting slot whenever a frame enters a sorted track while hidden,
			-- then slides in over SortedTrackTranslationDuration. A frame is never acquired while an
			-- event sits in the indeterminate track, so every arrival into the long track is such an
			-- initial entry. Parking on the entry offset rather than the resting one is what stops
			-- the handoff popping backwards.
			--
			-- Slot 2 below is therefore the entry offset for slot 1, which is where the break comes to
			-- rest. It is assumed to be alone on the long track, which it is: a break is the
			-- furthest-out thing on screen. Concurrent long track events would share these
			-- coordinates, and the timeline offers no lever to pin an event to a slot.
			local entryOffset = ComputeSortedEventOffset(ComputeTrackLayout()[Enum.EncounterTimelineTrack.Long], 2)

			-- Event frames are anchored by their centre to the track view's start point, and the
			-- offset origin is the track view rather than EncounterTimeline. The two rects coincide
			-- today, but only the track view sizes itself from the primary axis extent.
			parkedIcon:SetParent(trackView)
			parkedIcon:ClearAllPoints()
			parkedIcon:SetPoint("CENTER", trackView, orientation:GetStartPoint(), 0, 0)
			parkedIcon:SetPointsOffset(orientation:GetOrientedOffsets(entryOffset, trackView:GetCrossAxisOffset()))

			parkedIcon:SetFrameLevel(frameLevel)
			parkedIcon.IconContainer:SetFrameLevel(frameLevel + MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET)
			parkedIcon.Countdown:SetFrameLevel(frameLevel + MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET)
			parkedIcon.IconContainer:SetAlpha(LONG_TRACK_ALPHA)
			parkedIcon.Countdown:SetAlpha(LONG_TRACK_ALPHA)
		end

		parkedIcon.Countdown:SetCooldownDuration(breakEndTime - GetTime())
		parkedIcon.Countdown:Show()
		parkedIcon:Show()

		currentPhase = Phase.Parked
		hasValidatedLayout = false
	end

	-- Routes a break to the phase its remaining duration calls for. Assigned below, once the handoff
	-- it has to be able to reach is in scope.
	---@type fun(remainingSeconds: number)
	local SelectPhase

	local function RefreshDisplay()
		if currentPhase == nil or currentPhase == Phase.Timeline then
			return
		end

		SelectPhase(breakEndTime - GetTime())
	end

	-- CreateFromMixins copies function references onto the frame, so the mixin tables are not the
	-- hook target.
	if EncounterTimeline ~= nil then
		-- A settings change releases and reinitialises every event frame and re-runs the entry slide,
		-- so the parked icon has to re-derive its offsets from the new layout too.
		hooksecurefunc(EncounterTimeline:GetTrackView(), "OnLayoutUpdated", function()
			if currentPhase ~= Phase.Parked then
				return
			end

			RefreshDisplay()
		end)

		-- A view type change can take the track view out from under the parked icon entirely.
		hooksecurefunc(EncounterTimeline, "UpdateSystemSettingViewType", function()
			RefreshDisplay()
		end)
	end

	-------------------------------------------------------------------------------
	-- Handoff

	---@param remainingSeconds number
	local function HandOffToTimeline(remainingSeconds)
		local eventId = C_EncounterTimeline.AddScriptEvent({
			spellID = 0,
			iconFileID = BREAK_ICON_FILE_ID,
			duration = remainingSeconds,
			maxQueueDuration = 0,
			overrideName = BREAK_LABEL,
			severity = Enum.EncounterEventSeverity.Medium,
			paused = false,
		})

		if eventId == nil or eventId == Constants.EncounterTimelineEventConstants.ENCOUNTER_TIMELINE_INVALID_EVENT then
			return
		end

		scriptEventId = eventId
		currentPhase = Phase.Timeline

		if fallbackFrame ~= nil then
			fallbackFrame:Hide()
		end
	end

	---@param remainingSeconds number
	function SelectPhase(remainingSeconds)
		local longOffsets

		-- A mismatch disqualifies the timeline for the rest of the session rather than being
		-- re-evaluated: it means the replication above no longer describes this build.
		-- Blizzard_EncounterTimeline is gated on AllowLoadGameType standard, so neither the frame nor
		-- the layout globals it defines are guaranteed to exist either.
		if
			not isLayoutMismatched
			and EncounterTimeline ~= nil
			and EncounterTimelineTrackLayoutDefaults ~= nil
			and C_EncounterTimeline.IsFeatureEnabled()
			and C_EncounterTimeline.GetViewType() == Enum.EncounterTimelineViewType.Timeline
		then
			longOffsets = ComputeTrackLayout()[Enum.EncounterTimelineTrack.Long]
		end

		if longOffsets == nil or longOffsets.maximumEventCount == math.huge then
			EnterFallbackPhase()

			return
		end

		if remainingSeconds > GetHandoffThreshold() then
			EnterParkedPhase()

			return
		end

		-- Short enough to belong on the long track already, so there is nothing to park.
		HandOffToTimeline(remainingSeconds)

		if currentPhase ~= Phase.Timeline then
			EnterFallbackPhase()
		end
	end

	-------------------------------------------------------------------------------
	-- Lifecycle

	---@param shouldCancelScriptEvent boolean
	local function TearDown(shouldCancelScriptEvent)
		if updateTicker ~= nil then
			updateTicker:Cancel()
			updateTicker = nil
		end

		ReleaseTimeline()

		if fallbackFrame ~= nil then
			fallbackFrame:Hide()
		end

		if scriptEventId ~= nil and shouldCancelScriptEvent then
			C_EncounterTimeline.CancelScriptEvent(scriptEventId)
		end

		currentPhase = nil
		breakEndTime = nil
		breakSender = nil
		scriptEventId = nil
		hasValidatedLayout = false
	end

	-- Compute the geometry rather than reading it, but cross-check against the live values as soon as
	-- they exist: a future change to EncounterTimelineTrackLayout.lua would otherwise misplace the
	-- parked icon with no signal at all.
	local function ValidateParkedLayout()
		if hasValidatedLayout then
			return
		end

		local trackView = EncounterTimeline:GetTrackView()

		-- Blizzard's offsets do not exist until the track view has been shown and laid out.
		if not trackView:HasTrack(Enum.EncounterTimelineTrack.Long) or trackView:IsLayoutDirty() then
			return
		end

		hasValidatedLayout = true

		local offsetsByTrack, primaryAxisExtent = ComputeTrackLayout()
		local longOffsets = offsetsByTrack[Enum.EncounterTimelineTrack.Long]
		local matches = math.abs(trackView:GetPrimaryAxisExtent() - primaryAxisExtent) <= OFFSET_TOLERANCE

		for trackSortIndex = 1, longOffsets.maximumEventCount do
			local liveOffset = trackView:CalculateEventOffset(Enum.EncounterTimelineTrack.Long, trackSortIndex, nil)

			matches = matches
				and math.abs(liveOffset - ComputeSortedEventOffset(longOffsets, trackSortIndex)) <= OFFSET_TOLERANCE
		end

		if matches then
			return
		end

		isLayoutMismatched = true

		print(
			"|cff33ff99XephUI|r: the encounter timeline layout no longer matches what the break timer replicates, falling back to a plain display."
		)
		RefreshDisplay()
	end

	local function OnUpdateTick()
		local remainingSeconds = breakEndTime - GetTime()

		if remainingSeconds <= 0 then
			-- A handed-off event runs its own finish animation, so let it play out rather than
			-- cancelling it.
			TearDown(false)

			return
		end

		-- The script event is created while it still resolves to the indeterminate track, where no
		-- frame is acquired for it. Keeping the parked icon up until it has actually moved onto a
		-- visible track is what stops a gap where neither display is drawn.
		if currentPhase == Phase.Timeline then
			if
				parkedIcon ~= nil
				and parkedIcon:IsShown()
				and C_EncounterTimeline.GetEventTrack(scriptEventId) ~= Enum.EncounterTimelineTrack.Indeterminate
			then
				parkedIcon:Hide()
			end

			return
		end

		if currentPhase == Phase.Fallback then
			UpdateFallbackText(remainingSeconds)

			return
		end

		ValidateParkedLayout()

		if currentPhase ~= Phase.Parked or remainingSeconds > GetHandoffThreshold() then
			return
		end

		HandOffToTimeline(remainingSeconds)

		-- Retrying a rejected AddScriptEvent every tick would achieve nothing but noise.
		if currentPhase ~= Phase.Timeline then
			EnterFallbackPhase()
		end
	end

	---@param seconds number?
	---@param senderName string?
	local function StartBreak(seconds, senderName)
		if seconds == nil then
			return
		end

		-- Zero is BigWigs' cancel: tear down whichever phase is live.
		if seconds == 0 then
			TearDown(true)

			return
		end

		if C_InstanceEncounter.IsEncounterInProgress() then
			return
		end

		local now = GetTime()

		-- A single /break puts both wire formats on the air so that BigWigs and DBM users alike see
		-- it, so every break arrives here twice. BigWigs throttles its own StartBreak identically.
		if now - lastStartTime < 0.5 then
			return
		end

		lastStartTime = now

		TearDown(true)

		-- The same bounds BigWigs' own StartBreak clamps to.
		local remainingSeconds = Clamp(seconds, 60, 3600)

		breakEndTime = GetTime() + remainingSeconds
		breakSender = senderName

		SelectPhase(remainingSeconds)

		updateTicker = C_Timer.NewTicker(0.1, OnUpdateTick)
	end

	-------------------------------------------------------------------------------
	-- Ingest

	eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event ~= "CHAT_MSG_ADDON" then
			RefreshDisplay()

			return
		end

		local addonPrefix, message, _, senderName = ...
		local seconds

		if addonPrefix == "BigWigs" then
			local bodyPrefix, subMessage, breakSeconds = strsplit("^", message)

			if bodyPrefix == "P" and subMessage == "Break" then
				seconds = breakSeconds
			end
		elseif addonPrefix == "D5" then
			local _, _, subPrefix, breakSeconds = strsplit("\t", message)

			if subPrefix == "BT" then
				seconds = breakSeconds
			end
		end

		if seconds == nil then
			return
		end

		-- The DBM body carries <name>-<RealmWithoutSpacesOrHyphens>, which does not round-trip to a
		-- resolvable unit cross-realm. The event's own sender argument is the authoritative
		-- name-realm, so rank is checked against that and the body name is never used.
		if IsInGroup() and not (UnitIsGroupLeader(senderName) or UnitIsGroupAssistant(senderName)) then
			return
		end

		StartBreak(tonumber(seconds), Ambiguate(senderName, "short"))
	end)
end)
