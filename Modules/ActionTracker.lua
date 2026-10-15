local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.ActionTracker then
		return
	end

	-- One slot under each MainActionBar button: history in all but the last, the current cast in the last.
	local SLOT_COUNT = 12
	local HISTORY_SIZE = SLOT_COUNT - 1
	local BORDER_PIXELS = 1
	-- Between an icon and its spell ID label, and between that label and the action bar.
	local LABEL_GAP = 2
	local EXPIRY_SECONDS = 10
	local FADE_SECONDS = 0.3
	local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
	local CROSS_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
	local PLACEHOLDER_TEXTURE = 134400

	-- Spells that fire UNIT_SPELLCAST_SUCCEEDED without being a player action: off-hand and
	-- follow-up hits, periodic components, server-side fake casts.
	local ignoredSpells = {
		[75] = true, -- Auto Shot
		[836] = true, -- Login effect
		[2550] = true, -- Cooking basic
		[4036] = true, -- Engineering basic
		[5374] = true, -- Mutilate
		[7268] = true, -- Arcane Missiles
		[27576] = true, -- Mutilate
		[32175] = true, -- Stormstrike
		[32176] = true, -- Stormstrike (Off-Hand)
		[47750] = true, -- Penance fake
		[50622] = true, -- Bladestorm
		[52174] = true, -- Heroic Leap
		[57794] = true, -- Heroic Leap
		[61391] = true, -- Typhoon
		[64844] = true, -- Divine Hymn fake
		[72734] = true, -- Mass Dispel fake
		[81782] = true, -- PW Barrier fake
		[84721] = true, -- Frozen Orb
		[85384] = true, -- Raging Blow
		[88263] = true, -- Hammer of the Righteous
		[96103] = true, -- Raging Blow
		[102794] = true, -- Ursol's Vortex
		[107270] = true, -- Spinning Crane Kick
		[110745] = true, -- Divine Star
		[114089] = true, -- Windlash
		[114093] = true, -- Windlash Off-Hand
		[115357] = true, -- Windstrike
		[115360] = true, -- Windstrike Off-Hand
		[115464] = true, -- Healing Sphere
		[120692] = true, -- Halo
		[120696] = true, -- Halo
		[121473] = true, -- Shadow Blade
		[121474] = true, -- Shadow Blade Off-hand
		[122128] = true, -- Divine Star
		[126664] = true, -- Charge fake
		[127797] = true, -- Ursol's Vortex
		[132951] = true, -- Flare
		[135299] = true, -- Tar Trap
		[145629] = true, -- AMZ fake
		[155777] = true, -- Germination fake
		[157982] = true, -- Tranquility tick
		[184707] = true, -- Rampage
		[184709] = true, -- Rampage
		[196771] = true, -- Remorseless Winter fake
		[197886] = true, -- Artifact weapon
		[198928] = true, -- Cinderstorm
		[199672] = true, -- Rupture
		[201363] = true, -- Rampage
		[201364] = true, -- Rampage
		[204255] = true, -- Soul Fragments
		[213241] = true, -- Felblade
		[213243] = true, -- Felblade
		[218617] = true, -- Rampage
		[225919] = true, -- Fracture
		[225921] = true, -- Fracture
		[228354] = true, -- Flurry
		[228537] = true, -- Shattered Souls
		[228597] = true, -- Frostbolt
		[240022] = true, -- Broken Shore fake
		[272790] = true, -- Frenzy; BM hunter buff
		[276245] = true, -- Env; envenom buff
		[337819] = true, -- Screaming Brutality - Throw Glaive
		[346665] = true, -- Throw Glaive
		[358734] = true, -- Glide
		[361022] = true, -- Sense Power
		[361195] = true, -- Verdant Embrace friendly heal
		[361509] = true, -- Living Flame friendly heal
		[363922] = true, -- Dream Breath fake
		[367230] = true, -- Spiritbloom
		[370966] = true, -- The Hunt Impact (DH Class Tree Talent)
		[371817] = true, -- Recall fake
		[372120] = true, -- Fake buff
		[383313] = true, -- Abomination Limb periodical
		[384255] = true, -- Change Talents
		[385060] = true, -- Odyn's Fury
		[385061] = true, -- Odyn's Fury
		[385062] = true, -- Odyn's Fury
		[385954] = true, -- Shield Charge
		[388658] = true, -- Blacksmithing fake
		[390259] = true, -- Commander of the Dead
		[390260] = true, -- Commander of the Dead
		[390264] = true, -- Commander of the Dead
		[391312] = true, -- Tailoring fake
		[391775] = true, -- Cooking DNT
		[393035] = true, -- Throw Glaive
		[394003] = true, -- Spark of Madness
		[394007] = true, -- Engineering fake
		[394008] = true, -- A Looker's Charm
		[394009] = true, -- Fishing fake
		[395369] = true, -- Fishing DNT
		[395392] = true, -- Blacksmithing fake
		[395394] = true, -- Alchemy DNT
		[395396] = true, -- Tailoring fake
		[395397] = true, -- Engineering DNT
		[395398] = true, -- Enchanting Tool Equipped (DNT)
		[395469] = true, -- Enchanting Gear Equipped (DNT)
		[395470] = true, -- Engineering DNT
		[395471] = true, -- Engineering DNT
		[395472] = true, -- Cooking
		[395473] = true, -- Alchemy DNT
		[395475] = true, -- Blacksmithing fake
		[396557] = true, -- Verdant Embrace buff
		[397374] = true, -- Empower instant cast fake
		[403758] = true, -- Breath of Eons, landing cast
		[408385] = true, -- Crusading Strikes
		[410499] = true, -- Rested fake
		[429826] = true, -- Hammer of Light
		[431398] = true, -- Empyrean Hammer
		[434144] = true, -- Infliction of Sorrow fake cast
		[437965] = true, -- Pulsing Flames, fake cast in Cinderbrew Area first pull
		[440839] = true, -- Kindness of Chi'ji
		[441426] = true, -- Exterminate cleave
		[441437] = true, -- Arachnophobia
		[455693] = true, -- Tailoring DNT
		[455694] = true, -- Blacksmithing fake
		[455701] = true, -- Engineering profession
		[455706] = true, -- Profession DNT
		[455711] = true, -- Tailoring fake
		[455712] = true, -- Cooking
		[455720] = true, -- Tailoring fake
		[455727] = true, -- Blacksmithing fake
		[455738] = true, -- Cooking
		[455760] = true, -- Alchemy DNT
		[455770] = true, -- Prof Gear Skill Bonus (DNT)
		[455773] = true, -- Profession DNT
		[455779] = true, -- Prof Gear Skill Bonus (DNT)
		[455789] = true, -- Engineering DNT
		[456640] = true, -- Consuming Fire fake cast
		[458357] = true, -- Chain Heal via Lively Totems
		[467455] = true, -- Action tracker fake cast
		[470411] = true, -- Flame Shock fake cast
		[1216737] = true, -- Interrogate
		[1218610] = true, -- Bounce
		[1219488] = true, -- Open (Murder Row 2nd boss door)
		[1234173] = true, -- Prof Gear Skill Bonus (DNT)
		[1240090] = true, -- Construction Window: Midnight Flask Cauldron
		[1251595] = true, -- Flamefang Pitch, Survival Hunter
		[1253859] = true, -- Takedown, Survival Hunter
		[1263886] = true, -- Transmog fake
		[1270292] = true, -- Lunar Beam fake
		[1292664] = true, -- Med'jai's Protection
	}

	---@class ActionTrackerIcon : Frame
	---@field Icon Texture
	---@field HorizontalBorders Texture[]
	---@field VerticalBorders Texture[]
	---@field SpellID FontString
	---@field Cross Texture?
	---@field Stage FontString?
	---@field Cooldown Cooldown?
	---@field Expire AnimationGroup?

	---@alias ActionTrackerCastKind "cast"|"channel"|"empower"

	local container = CreateFrame("Frame", "XephUIActionTracker", UIParent)
	container:EnableMouse(false)

	-- 12.1.0 lacks the native math.round; drop the fallback along with 120100.
	local round = math.round or Round

	local actionButtons = MainActionBar.actionButtons

	-- Layout metrics in container units, refreshed by ApplyPixelLayout.
	local pixelSize = 1
	local rowGap = 0
	---@type number[]
	local slotOffsets = {}

	local function AnchorToActionBar()
		local anchorButton = actionButtons[1]

		container:ClearAllPoints()
		container:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -rowGap)

		-- The action bar rarely sits on whole pixels, which pixel snapping turns into uneven borders
		-- and gaps on every child; nudge the container onto the grid instead.
		local left, top = container:GetLeft(), container:GetTop()

		if not left or not top then
			return
		end

		container:SetPoint(
			"TOPLEFT",
			anchorButton,
			"BOTTOMLEFT",
			round(left / pixelSize) * pixelSize - left,
			round(top / pixelSize) * pixelSize - top - rowGap
		)
	end

	---@return ActionTrackerIcon
	local function CreateIcon()
		---@type ActionTrackerIcon
		local icon = CreateFrame("Frame", nil, container)
		icon:Hide()

		icon.Icon = icon:CreateTexture(nil, "ARTWORK")
		icon.Icon:SetAllPoints()

		-- Above the cooldown swipe, so neither the border nor the spell ID gets darkened.
		local overlay = CreateFrame("Frame", nil, icon)
		overlay:SetAllPoints()
		overlay:SetFrameLevel(icon:GetFrameLevel() + 2)

		icon.HorizontalBorders = {}
		icon.VerticalBorders = {}

		for _, edge in ipairs({ "TOP", "BOTTOM" }) do
			local line = overlay:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint(edge .. "LEFT")
			line:SetPoint(edge .. "RIGHT")
			table.insert(icon.HorizontalBorders, line)
		end

		for _, edge in ipairs({ "LEFT", "RIGHT" }) do
			local line = overlay:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint("TOP" .. edge)
			line:SetPoint("BOTTOM" .. edge)
			table.insert(icon.VerticalBorders, line)
		end

		icon.SpellID = overlay:CreateFontString(nil, "OVERLAY", "NumberFont_Shadow_Tiny")
		icon.SpellID:SetPoint("BOTTOM", icon, "TOP", 0, LABEL_GAP)

		return icon
	end

	---@type ActionTrackerIcon[]
	local historyIcons = {}

	for index = 1, HISTORY_SIZE do
		local icon = CreateIcon()

		icon.Cross = icon:CreateTexture(nil, "OVERLAY", nil, 1)
		icon.Cross:SetTexture(CROSS_TEXTURE)
		icon.Cross:SetPoint("CENTER")
		icon.Cross:Hide()

		icon.Stage = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		icon.Stage:SetDrawLayer("OVERLAY", 7)
		icon.Stage:SetPoint("BOTTOMRIGHT", -2, 2)
		icon.Stage:Hide()

		local expire = icon:CreateAnimationGroup()
		expire:SetToFinalAlpha(true)
		expire:SetScript("OnFinished", function()
			icon:Hide()
		end)

		local fadeOut = expire:CreateAnimation("Alpha")
		fadeOut:SetFromAlpha(1)
		fadeOut:SetToAlpha(0)
		fadeOut:SetStartDelay(EXPIRY_SECONDS - FADE_SECONDS)
		fadeOut:SetDuration(FADE_SECONDS)

		icon.Expire = expire
		historyIcons[index] = icon
	end

	local currentIcon = CreateIcon()
	currentIcon:SetPoint("TOPRIGHT")

	currentIcon.Cooldown = CreateFrame("Cooldown", nil, currentIcon)
	currentIcon.Cooldown:SetSwipeTexture(SQUARE_TEXTURE, 1, 1, 1, 1)
	currentIcon.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
	currentIcon.Cooldown:SetDrawEdge(false)
	currentIcon.Cooldown:SetDrawBling(false)
	currentIcon.Cooldown:SetHideCountdownNumbers(true)

	-- Ring buffer over historyIcons; the slot after the newest is always the oldest.
	local newestIndex = HISTORY_SIZE
	local isEditing = false
	local playerGUID = UnitGUID("player")

	---@type string?
	local currentCastGUID
	---@type number?
	local currentSpellID
	---@type ActionTrackerCastKind?
	local currentKind
	-- Some end events fire more than once per cast; anything for an already resolved cast is dropped.
	---@type string?
	local resolvedCastGUID

	-- Seconds after empower start at which each stage is reached, reused across empowers.
	---@type number[]
	local empowerStageThresholds = {}
	local empowerStageCount = 0
	local empowerStartTime = 0

	local function LayoutHistory()
		for age = 0, HISTORY_SIZE - 1 do
			local icon = historyIcons[(newestIndex - age - 1) % HISTORY_SIZE + 1]
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", slotOffsets[HISTORY_SIZE - age], 0)
		end
	end

	-- PixelUtil only rounds UI unit sizes to whole pixels, so a 1 unit border can still come out
	-- at 2 pixels; borders are sized from the physical pixel instead.
	local function ApplyPixelLayout()
		local scale = container:GetEffectiveScale()
		local firstButton = actionButtons[1]
		local firstButtonScreenLeft = firstButton:GetLeft() * firstButton:GetEffectiveScale()

		pixelSize = PixelUtil.GetPixelToUIUnitFactor() / scale

		local borderSize = BORDER_PIXELS * pixelSize
		local buttonSize = firstButton:GetWidth() * firstButton:GetEffectiveScale() / scale
		local _, labelHeight = currentIcon.SpellID:GetFont()

		rowGap = PixelUtil.GetNearestPixelSize(labelHeight + LABEL_GAP * 2, scale)

		-- Shrinks to the room left below the label row, so a bar near the screen bottom doesn't push the
		-- icons off screen. Floored, since rounding up past that room would clip a pixel row.
		local spaceBelow = firstButton:GetBottom() * firstButton:GetEffectiveScale() / scale - rowGap
		local fittingSize = math.floor(spaceBelow / pixelSize) * pixelSize
		local iconSize = math.max(0, math.min(PixelUtil.GetNearestPixelSize(buttonSize, scale), fittingSize))
		local crossSize = PixelUtil.GetNearestPixelSize(iconSize * 0.6, scale)
		local centeringOffset = (buttonSize - iconSize) / 2

		-- Snapped per slot, since accumulating a snapped step would drift away from the buttons.
		for slot = 1, SLOT_COUNT do
			local button = actionButtons[slot]
			local offset = (button:GetLeft() * button:GetEffectiveScale() - firstButtonScreenLeft) / scale
			slotOffsets[slot] = round((offset + centeringOffset) / pixelSize) * pixelSize
		end

		-- currentIcon is anchored TOPRIGHT, so this width puts it on the last slot.
		container:SetSize(slotOffsets[SLOT_COUNT] + iconSize, iconSize)

		for index = 1, HISTORY_SIZE + 1 do
			local icon = historyIcons[index] or currentIcon
			icon:SetSize(iconSize, iconSize)

			if icon.Cross then
				icon.Cross:SetSize(crossSize, crossSize)
			end

			for _, line in ipairs(icon.HorizontalBorders) do
				line:SetHeight(borderSize)
			end

			for _, line in ipairs(icon.VerticalBorders) do
				line:SetWidth(borderSize)
			end
		end

		currentIcon.Cooldown:SetPoint("TOPLEFT", borderSize, -borderSize)
		currentIcon.Cooldown:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)

		LayoutHistory()
		AnchorToActionBar()
	end

	local isLayoutQueued = false

	-- While applying a layout, Edit Mode parks default-positioned bars at the top of the screen
	-- (EditModeSystemMixin:ApplySystemAnchor) and only moves them into place once it's done, so the
	-- measurement waits for that to settle.
	local function QueuePixelLayout()
		if isLayoutQueued then
			return
		end

		isLayoutQueued = true

		RunNextFrame(function()
			isLayoutQueued = false
			ApplyPixelLayout()
		end)
	end

	---@param spellID number
	---@param cancelled boolean
	---@param stage number?
	local function PushHistory(spellID, cancelled, stage)
		local texture = C_Spell.GetSpellTexture(spellID)

		if not texture then
			texture = PLACEHOLDER_TEXTURE
			print("[ActionTracker] could not resolve icon for", C_Spell.GetSpellLink(spellID) or spellID)
		end

		newestIndex = newestIndex % HISTORY_SIZE + 1

		local icon = historyIcons[newestIndex]
		icon.Icon:SetTexture(texture)
		icon.Icon:SetDesaturated(cancelled)
		icon.Cross:SetShown(cancelled)
		icon.SpellID:SetFormattedText("%d", spellID)
		icon.SpellID:SetShown(not C_SpellBook.IsSpellInSpellBook(spellID))

		if stage then
			icon.Stage:SetFormattedText("%d", stage)
			icon.Stage:Show()
		else
			icon.Stage:Hide()
		end

		icon.Expire:Stop()
		icon:SetAlpha(1)
		icon:Show()
		icon.Expire:Play()

		LayoutHistory()
	end

	---@param cancelled boolean
	---@param stage number?
	local function ResolveCurrent(cancelled, stage)
		PushHistory(currentSpellID, cancelled, stage)

		resolvedCastGUID = currentCastGUID
		currentCastGUID = nil
		currentSpellID = nil
		currentKind = nil

		currentIcon:Hide()
	end

	---@param duration LuaDurationObject?
	local function ApplyCurrentDuration(duration)
		if duration then
			currentIcon.Cooldown:SetCooldownFromDurationObject(duration)
		else
			currentIcon.Cooldown:Clear()
		end
	end

	---@param castGUID string?
	---@param spellID number
	---@param kind ActionTrackerCastKind
	---@param duration LuaDurationObject?
	local function StartCurrent(castGUID, spellID, kind, duration)
		local texture = C_Spell.GetSpellTexture(spellID)

		if not texture then
			return
		end

		currentCastGUID = castGUID
		currentSpellID = spellID
		currentKind = kind

		currentIcon.Icon:SetTexture(texture)
		currentIcon.SpellID:SetFormattedText("%d", spellID)
		currentIcon.SpellID:SetShown(not C_SpellBook.IsSpellInSpellBook(spellID))
		currentIcon.Cooldown:SetReverse(kind ~= "cast")
		ApplyCurrentDuration(duration)
		currentIcon:Show()
	end

	local eventHandlers = {}

	function eventHandlers.UNIT_SPELLCAST_START(castGUID, spellID)
		if ignoredSpells[spellID] then
			return
		end

		StartCurrent(castGUID, spellID, "cast", UnitCastingDuration("player"))
	end

	function eventHandlers.UNIT_SPELLCAST_CHANNEL_START(_, spellID)
		if ignoredSpells[spellID] then
			return
		end

		-- Eye Beam and Fel Devastation fire CHANNEL_START twice per channel.
		if currentKind == "channel" and currentSpellID == spellID then
			ApplyCurrentDuration(UnitChannelDuration("player"))
			return
		end

		StartCurrent(nil, spellID, "channel", UnitChannelDuration("player"))
	end

	function eventHandlers.UNIT_SPELLCAST_EMPOWER_START(_, spellID)
		if ignoredSpells[spellID] then
			return
		end

		StartCurrent(nil, spellID, "empower", UnitEmpoweredChannelDuration("player", true))

		-- Stage thresholds as the default cast bar builds them (CastingBarMixin:AddStages).
		local _, _, _, startTimeMS, _, _, _, _, _, numStages = UnitChannelInfo("player")
		local elapsedMS = 0

		empowerStartTime = startTimeMS and startTimeMS / 1000 or GetTime()
		empowerStageCount = numStages or 0

		for stage = 1, empowerStageCount do
			elapsedMS = elapsedMS + GetUnitEmpowerStageDuration("player", stage - 1)
			empowerStageThresholds[stage] = elapsedMS / 1000
		end
	end

	function eventHandlers.UNIT_SPELLCAST_DELAYED(castGUID)
		if castGUID ~= currentCastGUID then
			return
		end

		ApplyCurrentDuration(UnitCastingDuration("player"))
	end

	function eventHandlers.UNIT_SPELLCAST_CHANNEL_UPDATE()
		if currentKind ~= "channel" then
			return
		end

		ApplyCurrentDuration(UnitChannelDuration("player"))
	end

	function eventHandlers.UNIT_SPELLCAST_EMPOWER_UPDATE()
		if currentKind ~= "empower" then
			return
		end

		ApplyCurrentDuration(UnitEmpoweredChannelDuration("player", true))
	end

	function eventHandlers.UNIT_SPELLCAST_SUCCEEDED(castGUID, spellID)
		if castGUID == resolvedCastGUID then
			return
		end

		if currentKind == "cast" and castGUID == currentCastGUID then
			ResolveCurrent(false)
			return
		end

		-- Channels and empowers fire SUCCEEDED right after they start; their STOP resolves them.
		if currentKind and currentKind ~= "cast" and spellID == currentSpellID then
			return
		end

		if ignoredSpells[spellID] then
			return
		end

		PushHistory(spellID, false)
	end

	function eventHandlers.UNIT_SPELLCAST_INTERRUPTED(castGUID)
		if castGUID ~= currentCastGUID or currentKind ~= "cast" then
			return
		end

		ResolveCurrent(true)
	end

	function eventHandlers.UNIT_SPELLCAST_FAILED(castGUID)
		if castGUID ~= currentCastGUID or currentKind ~= "cast" then
			return
		end

		ResolveCurrent(true)
	end

	-- STOP may arrive before SUCCEEDED or INTERRUPTED, so it only hides the slot and leaves the
	-- cast for those to resolve.
	function eventHandlers.UNIT_SPELLCAST_STOP(castGUID)
		if castGUID ~= currentCastGUID then
			return
		end

		currentIcon:Hide()
	end

	-- Channel and empower events carry no castGUID, so they are matched by kind and spell.
	function eventHandlers.UNIT_SPELLCAST_CHANNEL_STOP(_, spellID, interruptedBy)
		if currentKind ~= "channel" or spellID ~= currentSpellID then
			return
		end

		-- Ending a channel early is a normal success; only an interrupt by someone else cancels it.
		ResolveCurrent(interruptedBy ~= nil and interruptedBy ~= "" and interruptedBy ~= playerGUID)
	end

	function eventHandlers.UNIT_SPELLCAST_EMPOWER_STOP(_, spellID, complete)
		if currentKind ~= "empower" or spellID ~= currentSpellID then
			return
		end

		if not complete then
			ResolveCurrent(true)
			return
		end

		-- Releasing before the first threshold still fires at stage 1 once the minimum hold elapses.
		local elapsed = GetTime() - empowerStartTime
		local stage = 1

		for index = 1, empowerStageCount do
			if elapsed < empowerStageThresholds[index] then
				break
			end

			stage = index
		end

		ResolveCurrent(false, stage)
	end

	for event in pairs(eventHandlers) do
		container:RegisterUnitEvent(event, "player")
	end

	container:SetScript("OnEvent", function(_, event, _, ...)
		if isEditing then
			return
		end

		eventHandlers[event](...)
	end)

	EventRegistry:RegisterCallback("EditMode.Enter", function()
		isEditing = true
		currentCastGUID = nil
		currentSpellID = nil
		currentKind = nil

		local iconProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook, true)
		local hasSpellbookIcons = iconProvider:GetNumIcons() > 1

		---@return string|number
		local function GetPreviewTexture()
			return hasSpellbookIcons and iconProvider:GetRandomIcon() or PLACEHOLDER_TEXTURE
		end

		for index = 1, HISTORY_SIZE do
			local icon = historyIcons[index]
			icon.Expire:Stop()
			icon.Icon:SetTexture(GetPreviewTexture())
			icon.Icon:SetDesaturated(false)
			icon.Cross:Hide()
			icon.Stage:Hide()
			icon.SpellID:SetText("")
			icon:SetAlpha(1)
			icon:Show()
		end

		currentIcon.Icon:SetTexture(GetPreviewTexture())
		currentIcon.SpellID:SetText("")
		currentIcon.Cooldown:Clear()
		currentIcon:Show()
	end, container)

	EventRegistry:RegisterCallback("EditMode.Exit", function()
		isEditing = false

		for index = 1, HISTORY_SIZE do
			historyIcons[index]:Hide()
		end

		currentIcon:Hide()

		-- Dragging the bar in Edit Mode bypasses ApplySystemAnchor, leaving the pixel nudge and the
		-- room below the bar stale.
		QueuePixelLayout()
	end, container)

	hooksecurefunc(MainActionBar, "ApplySystemAnchor", QueuePixelLayout)
	hooksecurefunc(MainActionBar, "UpdateGridLayout", QueuePixelLayout)
	hooksecurefunc(MainActionBar, "UpdateSystemSettingIconSize", QueuePixelLayout)
	EventRegistry:RegisterFrameEventAndCallback("UI_SCALE_CHANGED", QueuePixelLayout, container)
	EventRegistry:RegisterFrameEventAndCallback("DISPLAY_SIZE_CHANGED", QueuePixelLayout, container)

	ApplyPixelLayout()
end)
