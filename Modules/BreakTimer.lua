local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.BreakTimer then
		return
	end

	local BREAK_ICON_FILE_ID = 134062 -- inv_misc_fork&knife, the icon BigWigs' own break bar uses
	local BREAK_LABEL = "Break"
	local MINIMUM_BREAK_SECONDS = 60
	local MAXIMUM_BREAK_SECONDS = 3600
	local START_THROTTLE_SECONDS = 0.5
	local UPDATE_INTERVAL = 0.1
	local OFFSET_TOLERANCE = 0.01

	-- Long track alpha from EncounterTimelineTrackAlphaCurve, and the frame level bump a Medium
	-- severity event gets from EncounterTimelineSeverityFrameLevelCurve.
	local LONG_TRACK_ALPHA = 0.6
	local MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET = 20

	-- Layout inputs the C track list does not carry. EncounterTimelineTrackViewMixin:OnTracksUpdated
	-- supplies all three; the medium extent is a bare literal in CalculateMediumTrackExtent and the
	-- queued padding is hardcoded, so neither is readable while the timeline is cold.
	local MEDIUM_TRACK_EXTENT = 55
	local QUEUED_TRACK_PADDING_START = 10
	local LINE_START_ATLAS = "combattimeline-line-left"
	local LINE_END_ATLAS = "combattimeline-line-right"

	-- A break is the furthest-out thing on screen, so it is assumed to be alone on the long track.
	-- Concurrent long-track events would share these coordinates; the timeline offers no lever to
	-- pin an event to a slot, so there is nothing to arbitrate with.
	local PARKED_SORT_INDEX = 1

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
	local hasInstalledTimelineHooks = false

	local eventFrame = CreateFrame("Frame")

	---@return table
	local function GetDatabase()
		local database = XephUISaved.BreakTimerDB or {}

		XephUISaved.BreakTimerDB = database

		return database
	end

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
		local shortTrackExtent = GetAtlasSize(LINE_START_ATLAS) + GetAtlasSize(LINE_END_ATLAS)
		local trackList = C_EncounterTimeline.GetTrackList()
		local offsetsByTrack = {}
		local offset = paddingStart or layoutDefaults.PrimaryAxisStartPadding

		-- SetTrackList walks the list with ipairs_reverse, building longest track to shortest.
		for index = #trackList, 1, -1 do
			local trackInfo = trackList[index]
			local track = trackInfo.id

			if trackInfo.type == Enum.EncounterTimelineTrackType.Sorted then
				local trackPaddingStart = track == Enum.EncounterTimelineTrack.Queued and QUEUED_TRACK_PADDING_START
					or 0
				local maximumEventCount = trackInfo.maximumEventCount or math.huge

				offset = offset + trackPaddingStart

				offsetsByTrack[track] = {
					offsetStart = offset,
					maximumEventCount = maximumEventCount,
					sortDirection = trackInfo.sortDirection,
					sortedEventExtent = sortedEventExtent,
				}

				offset = offset + maximumEventCount * sortedEventExtent
				offsetsByTrack[track].offsetEnd = offset
			elseif trackInfo.type == Enum.EncounterTimelineTrackType.Linear then
				local extent = track == Enum.EncounterTimelineTrack.Medium and MEDIUM_TRACK_EXTENT or shortTrackExtent

				offsetsByTrack[track] = { offsetStart = offset }

				offset = offset + extent
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

	-- StartPrimaryAxisSortedTranslation synthesizes an entry offset one slot further from the medium
	-- end than the resting slot whenever a frame enters a sorted track while hidden, then slides in
	-- over SortedTrackTranslationDuration. A frame is never acquired while an event sits in the
	-- indeterminate track, so every arrival into the long track is such an initial entry. Parking on
	-- the entry offset rather than the resting one is what stops the handoff popping backwards.
	---@param trackOffsets table
	---@param trackSortIndex number
	---@return number
	local function ComputeSortedEventEntryOffset(trackOffsets, trackSortIndex)
		return ComputeSortedEventOffset(trackOffsets, trackSortIndex + 1)
	end

	-- Compute the geometry rather than reading it, but cross-check against the live values whenever
	-- they are valid: a future change to EncounterTimelineTrackLayout.lua would otherwise misplace
	-- the parked icon with no signal at all. Returns nil while the live layout is not yet built.
	---@param offsetsByTrack table<number, table>
	---@param primaryAxisExtent number
	---@return boolean?
	local function ValidateComputedLayout(offsetsByTrack, primaryAxisExtent)
		local trackView = EncounterTimeline:GetTrackView()

		if not trackView:HasTrack(Enum.EncounterTimelineTrack.Long) or trackView:IsLayoutDirty() then
			return nil
		end

		if math.abs(trackView:GetPrimaryAxisExtent() - primaryAxisExtent) > OFFSET_TOLERANCE then
			return false
		end

		local longOffsets = offsetsByTrack[Enum.EncounterTimelineTrack.Long]

		for trackSortIndex = 1, longOffsets.maximumEventCount do
			local liveOffset = trackView:CalculateEventOffset(Enum.EncounterTimelineTrack.Long, trackSortIndex, nil)
			local computedOffset = ComputeSortedEventOffset(longOffsets, trackSortIndex)

			if math.abs(liveOffset - computedOffset) > OFFSET_TOLERANCE then
				return false
			end
		end

		return true
	end

	---@return boolean
	local function IsTimelineUsable()
		-- A mismatch disqualifies the timeline for the rest of the session rather than being
		-- re-evaluated: it means the replication below no longer describes this build.
		if isLayoutMismatched then
			return false
		end

		-- Blizzard_EncounterTimeline is gated on AllowLoadGameType standard, so neither the frame nor
		-- the layout globals it defines are guaranteed to exist.
		if EncounterTimeline == nil or EncounterTimelineTrackLayoutDefaults == nil then
			return false
		end

		if not C_EncounterTimeline.IsFeatureEnabled() then
			return false
		end

		if C_EncounterTimeline.GetViewType() ~= Enum.EncounterTimelineViewType.Timeline then
			return false
		end

		local offsetsByTrack = ComputeTrackLayout()
		local longOffsets = offsetsByTrack[Enum.EncounterTimelineTrack.Long]

		return longOffsets ~= nil and longOffsets.maximumEventCount ~= math.huge
	end

	---@return number
	local function GetHandoffThreshold()
		return C_EncounterTimeline.GetTrackMaxEventDuration(Enum.EncounterTimelineTrack.Long)
	end

	-------------------------------------------------------------------------------
	-- Parked icon

	---@return Frame
	local function AcquireParkedIcon()
		if parkedIcon == nil then
			parkedIcon = CreateFrame("Frame", nil, UIParent, "XephUIBreakTimerParkedIconTemplate")
			parkedIcon.IconContainer.IconTexture:SetTexture(BREAK_ICON_FILE_ID)
		end

		return parkedIcon
	end

	local function ApplyParkedIconCountdown()
		parkedIcon.Countdown:SetCooldownDuration(breakEndTime - GetTime())
		parkedIcon.Countdown:Show()
	end

	local function PositionParkedIcon()
		local trackView = EncounterTimeline:GetTrackView()
		local offsetsByTrack = ComputeTrackLayout()
		local longOffsets = offsetsByTrack[Enum.EncounterTimelineTrack.Long]
		local orientation = trackView:GetTrackOrientation()
		local frameLevel = trackView:GetFrameLevel()

		-- Event frames are anchored by their centre to the track view's start point, and the offset
		-- origin is the track view rather than EncounterTimeline. The two rects coincide today, but
		-- only the track view sizes itself from the primary axis extent, so anchor to that.
		parkedIcon:SetParent(trackView)
		parkedIcon:ClearAllPoints()
		parkedIcon:SetPoint("CENTER", trackView, orientation:GetStartPoint(), 0, 0)
		parkedIcon:SetPointsOffset(
			orientation:GetOrientedOffsets(
				ComputeSortedEventEntryOffset(longOffsets, PARKED_SORT_INDEX),
				trackView:GetCrossAxisOffset()
			)
		)

		parkedIcon:SetFrameLevel(frameLevel)
		parkedIcon.IconContainer:SetFrameLevel(frameLevel + MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET)
		parkedIcon.Countdown:SetFrameLevel(frameLevel + MEDIUM_SEVERITY_FRAME_LEVEL_OFFSET)
		parkedIcon.IconContainer:SetAlpha(LONG_TRACK_ALPHA)
		parkedIcon.Countdown:SetAlpha(LONG_TRACK_ALPHA)
	end

	-------------------------------------------------------------------------------
	-- Fallback display

	local function SaveFallbackPosition()
		local point, _, relativePoint, offsetX, offsetY = fallbackFrame:GetPoint(1)

		GetDatabase().FallbackPoint = {
			point = point,
			relativePoint = relativePoint,
			offsetX = offsetX,
			offsetY = offsetY,
		}
	end

	---@return Frame
	local function AcquireFallbackFrame()
		if fallbackFrame ~= nil then
			return fallbackFrame
		end

		fallbackFrame = CreateFrame("Frame", nil, UIParent, "XephUIBreakTimerFallbackTemplate")
		fallbackFrame.IconContainer.IconTexture:SetTexture(BREAK_ICON_FILE_ID)

		local savedPoint = GetDatabase().FallbackPoint

		if savedPoint then
			fallbackFrame:SetPoint(
				savedPoint.point,
				UIParent,
				savedPoint.relativePoint,
				savedPoint.offsetX,
				savedPoint.offsetY
			)
		else
			fallbackFrame:SetPoint("TOP", UIParent, "TOP", 0, -220)
		end

		fallbackFrame:RegisterForDrag("LeftButton")
		fallbackFrame:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		fallbackFrame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			SaveFallbackPosition()
		end)

		return fallbackFrame
	end

	---@param remainingSeconds number
	local function UpdateFallbackText(remainingSeconds)
		fallbackFrame.NameText:SetText(breakSender and (BREAK_LABEL .. " - " .. breakSender) or BREAK_LABEL)
		fallbackFrame.TimeText:SetText(SecondsToClock(remainingSeconds))
	end

	-------------------------------------------------------------------------------
	-- Display phases

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
		AcquireFallbackFrame()
		UpdateFallbackText(breakEndTime - GetTime())
		fallbackFrame:Show()

		currentPhase = Phase.Fallback
	end

	local function EnterParkedPhase()
		if fallbackFrame ~= nil then
			fallbackFrame:Hide()
		end

		AcquireParkedIcon()

		-- EvaluateVisibility only shows the timeline outside an encounter once it has visible events
		-- or event frames, and an event above the long track's maximum duration has neither. Forcing
		-- it shown is also what gets the track view to build its layout, which the validation below
		-- needs. This writes a field on Blizzard's frame from our tainted stack.
		EncounterTimeline:SetExplicitlyShown(true)

		PositionParkedIcon()
		ApplyParkedIconCountdown()
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

	local function InstallTimelineHooks()
		if hasInstalledTimelineHooks or EncounterTimeline == nil then
			return
		end

		hasInstalledTimelineHooks = true

		local trackView = EncounterTimeline:GetTrackView()

		-- CreateFromMixins copies function references onto the frame, so the mixin tables are not
		-- the hook target.

		-- A settings change releases and reinitialises every event frame and re-runs the entry
		-- slide, so the parked icon has to re-derive its offsets from the new layout too.
		hooksecurefunc(trackView, "OnLayoutUpdated", function()
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
		if not IsTimelineUsable() then
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

	-- The script event is created while it still resolves to the indeterminate track, where no frame
	-- is acquired for it. Keeping the parked icon up until it has actually moved onto a visible track
	-- is what stops a gap where neither display is drawn.
	local function ReleaseParkedIconAfterHandoff()
		if parkedIcon == nil or not parkedIcon:IsShown() then
			return
		end

		if C_EncounterTimeline.GetEventTrack(scriptEventId) == Enum.EncounterTimelineTrack.Indeterminate then
			return
		end

		parkedIcon:Hide()
	end

	-------------------------------------------------------------------------------
	-- Lifecycle

	local function StopUpdating()
		if updateTicker == nil then
			return
		end

		updateTicker:Cancel()
		updateTicker = nil
	end

	-- Tears the display down without touching the saved variable, so that restarting or resuming a
	-- break can reuse it. Callers that actually end a break clear the saved break themselves.
	---@param shouldCancelScriptEvent boolean
	local function TearDown(shouldCancelScriptEvent)
		StopUpdating()
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

	---@param shouldCancelScriptEvent boolean
	local function EndBreak(shouldCancelScriptEvent)
		TearDown(shouldCancelScriptEvent)

		GetDatabase().ActiveBreak = nil
	end

	local function ValidateParkedLayout()
		if hasValidatedLayout then
			return
		end

		local offsetsByTrack, primaryAxisExtent = ComputeTrackLayout()
		local validationResult = ValidateComputedLayout(offsetsByTrack, primaryAxisExtent)

		if validationResult == nil then
			return
		end

		hasValidatedLayout = true

		if validationResult then
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
			EndBreak(false)

			return
		end

		if currentPhase == Phase.Timeline then
			ReleaseParkedIconAfterHandoff()

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

	---@param remainingSeconds number
	---@param senderName string?
	local function BeginBreak(remainingSeconds, senderName)
		TearDown(true)

		breakEndTime = GetTime() + remainingSeconds
		breakSender = senderName

		InstallTimelineHooks()
		SelectPhase(remainingSeconds)

		updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, OnUpdateTick)
	end

	---@param seconds number?
	---@param senderName string?
	local function StartBreak(seconds, senderName)
		if seconds == nil then
			return
		end

		-- Zero is BigWigs' cancel, and needs the same teardown as a start: stop whichever phase is
		-- live and drop the saved variable so a reload does not resurrect the break.
		if seconds == 0 then
			EndBreak(true)

			return
		end

		if C_InstanceEncounter.IsEncounterInProgress() then
			return
		end

		local now = GetTime()

		-- The same break arrives twice whenever BigWigs is loaded: once through its own callback and
		-- once on the wire. BigWigs throttles its own StartBreak identically.
		if now - lastStartTime < START_THROTTLE_SECONDS then
			return
		end

		lastStartTime = now

		local clampedSeconds = Clamp(seconds, MINIMUM_BREAK_SECONDS, MAXIMUM_BREAK_SECONDS)

		BeginBreak(clampedSeconds, senderName)

		GetDatabase().ActiveBreak = {
			startedAt = time(),
			seconds = clampedSeconds,
			sender = senderName,
		}
	end

	-------------------------------------------------------------------------------
	-- Ingest

	-- The DBM body carries <name>-<RealmWithoutSpacesOrHyphens>, which does not round-trip to a
	-- resolvable unit cross-realm. The event's own sender argument is the authoritative name-realm,
	-- so rank is checked against that and the body name is never used.
	---@param senderName string
	---@return boolean
	local function IsSenderPermitted(senderName)
		if not IsInGroup() then
			return true
		end

		return UnitIsGroupLeader(senderName) or UnitIsGroupAssistant(senderName)
	end

	---@param message string
	---@param senderName string
	local function HandleBigWigsMessage(message, senderName)
		local messagePrefix, subMessage, seconds = strsplit("^", message)

		if messagePrefix ~= "P" or subMessage ~= "Break" then
			return
		end

		if not IsSenderPermitted(senderName) then
			return
		end

		StartBreak(tonumber(seconds), Ambiguate(senderName, "short"))
	end

	---@param message string
	---@param senderName string
	local function HandleDeadlyBossModsMessage(message, senderName)
		local _, _, subPrefix, seconds = strsplit("\t", message)

		if subPrefix ~= "BT" then
			return
		end

		if not IsSenderPermitted(senderName) then
			return
		end

		StartBreak(tonumber(seconds), Ambiguate(senderName, "short"))
	end

	C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
	C_ChatInfo.RegisterAddonMessagePrefix("D5")

	eventFrame:RegisterEvent("CHAT_MSG_ADDON")
	eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_ACTIVATED")
	eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_VIEW_DEACTIVATED")

	eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			local messagePrefix, message, _, senderName = ...

			if messagePrefix == "BigWigs" then
				HandleBigWigsMessage(message, senderName)
			elseif messagePrefix == "D5" then
				HandleDeadlyBossModsMessage(message, senderName)
			end

			return
		end

		RefreshDisplay()
	end)

	EventUtil.ContinueOnPlayerLogin(function()
		-- A solo /break dispatches locally and puts nothing on the wire, so the addon message path
		-- alone never sees a break the player started themselves. The loader and core share one
		-- callback registry, so registering directly against it is supported.
		if BigWigsLoader ~= nil and BigWigsLoader.RegisterMessage ~= nil then
			BigWigsLoader.RegisterMessage(eventFrame, "BigWigs_StartBreak", function(_, _, seconds, nick)
				StartBreak(seconds, nick)
			end)

			BigWigsLoader.RegisterMessage(eventFrame, "BigWigs_StopBreak", function()
				EndBreak(true)
			end)
		end

		local activeBreak = GetDatabase().ActiveBreak

		if activeBreak == nil then
			return
		end

		local remainingSeconds = activeBreak.seconds - (time() - activeBreak.startedAt)

		if remainingSeconds <= 0 then
			GetDatabase().ActiveBreak = nil

			return
		end

		BeginBreak(remainingSeconds, activeBreak.sender)
	end)
end)
