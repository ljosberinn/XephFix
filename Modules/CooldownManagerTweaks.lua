local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.CooldownManagerTweaks then
		return
	end

	-- key: cast spell ID (which doubles as the aura ID to display)
	---@type table<integer, ItemInfo>
	local castToItemInfo = {
		[1260459] = {
			itemId = 249346,
			duration = 15,
		},
	}

	-- key: cast spell ID, value carries a separate aura ID to display
	---@type table<integer, AuraSpellInfo>
	local castToAuraInfo = {
		-- [spellId] = { auraId = ..., duration = ... },
	}

	---@class ApplicationsFrame : Frame
	---@field Applications FontString?

	---@class ChargeCountFrame : Frame
	---@field Current FontString?

	---@class PandemicFrame : Frame
	---@field Border Frame?

	---@class CooldownViewerItem : Frame
	---@field Icon Texture?
	---@field Cooldown CooldownFrame?
	---@field Applications ApplicationsFrame?
	---@field ChargeCount ChargeCountFrame?
	---@field CustomBorderFrame Frame?
	---@field layoutIndex integer?
	---@field DebuffBorder Frame?
	---@field PandemicIcon PandemicFrame?
	---@field TriggerPandemicAlert (fun(self: CooldownViewerItem))?
	---@field ShowPandemicStateFrame (fun(self: CooldownViewerItem))?
	---@field PandemicHooked boolean?
	---@field PandemicBorderHooked boolean?
	---@field RecenterHooked boolean?
	---@field OnActiveStateChanged (fun())?
	---@field OnUnitAuraAddedEvent (fun())?
	---@field OnUnitAuraRemovedEvent (fun())?

	---@class StackConfig
	---@field point string
	---@field y integer
	---@field size integer

	---@alias ViewerName "EssentialCooldownViewer"|"UtilityCooldownViewer"|"BuffIconCooldownViewer"

	---@class ItemInfo
	---@field itemId integer
	---@field duration integer

	---@class AuraSpellInfo
	---@field auraId integer
	---@field duration integer

	---@class AuraFrame : Frame
	---@field Icon Texture
	---@field Cooldown CooldownFrame
	---@field timer FunctionContainer?

	---@class AuraListenerFrame : Frame
	---@field UpdateEventRegistration fun(self: AuraListenerFrame)

	---@type string
	local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

	---@type integer
	local BORDER_PIXELS = 1

	---@type string?
	local cachedFontPath

	---@return string
	local function GetFont()
		if cachedFontPath then
			return cachedFontPath
		end

		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

		if LSM then
			local fetchedPath = LSM:Fetch("font", "Roboto Condensed Bold")
			if fetchedPath then
				cachedFontPath = fetchedPath
				return cachedFontPath
			end
		end

		cachedFontPath = "Interface/AddOns/Platynator/Assets/Fonts/RobotoCondensed-Bold.ttf"

		return cachedFontPath
	end

	---@param button CooldownViewerItem
	local function ApplySquare(button)
		local icon = button.Icon

		if not icon then
			return
		end

		-- Fill icon to button edges with no zoom crop
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		if icon.SetTexCoord then
			icon:SetTexCoord(0, 1, 0, 1)
		end

		-- Replace circular swipe with square, inset by border width
		for i = 1, select("#", button:GetChildren()) do
			local child = select(i, button:GetChildren())

			if child and child.SetSwipeTexture then
				child:SetSwipeTexture(SQUARE_TEXTURE)
				child:ClearAllPoints()
				child:SetPoint("TOPLEFT", button, "TOPLEFT", BORDER_PIXELS, -BORDER_PIXELS)
				child:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BORDER_PIXELS, BORDER_PIXELS)
			end
		end

		for _, region in next, { button:GetRegions() } do
			if region:IsObjectType("MaskTexture") then
				---@cast region MaskTexture
				region:SetTexture(SQUARE_TEXTURE)
			elseif region:IsObjectType("Texture") then
				---@cast region Texture
				if region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
					region:SetAlpha(0)
				end
			end
		end

		if button.DebuffBorder then
			button.DebuffBorder:SetAlpha(0)
		end

		if button.TriggerPandemicAlert and not button.PandemicHooked then
			button.PandemicHooked = true

			hooksecurefunc(button, "TriggerPandemicAlert", function()
				if button.PandemicIcon then
					button.PandemicIcon:SetScale(1.38)
				end

				C_Timer.After(0, function()
					if button.PandemicIcon then
						button.PandemicIcon:SetScale(1.38)
					end
				end)
			end)
		end

		if button.ShowPandemicStateFrame and not button.PandemicBorderHooked then
			button.PandemicBorderHooked = true

			hooksecurefunc(button, "ShowPandemicStateFrame", function()
				if button.PandemicIcon and button.PandemicIcon.Border then
					button.PandemicIcon.Border:SetAlpha(0)
				end
			end)
		end

		-- Black border overlay
		if not button.CustomBorderFrame then
			local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")

			borderFrame:SetFrameLevel(button:GetFrameLevel() + 1)
			borderFrame:SetAllPoints(button)
			borderFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = BORDER_PIXELS })
			borderFrame:SetBackdropBorderColor(0, 0, 0, 1)
			button.CustomBorderFrame = borderFrame
		end
	end

	---@type table<ViewerName, StackConfig>
	local stackConfig = {
		EssentialCooldownViewer = { point = "BOTTOM", y = -8, size = 18 },
		UtilityCooldownViewer = { point = "BOTTOM", y = -8, size = 14 },
		BuffIconCooldownViewer = { point = "TOP", y = 7, size = 16 },
	}

	---@param button CooldownViewerItem
	---@param viewerName ViewerName
	local function ApplyStack(button, viewerName)
		local config = stackConfig[viewerName]

		if not config then
			return
		end

		local fontString = (button.Applications and button.Applications.Applications)
			or (button.ChargeCount and button.ChargeCount.Current)

		if not fontString then
			return
		end

		if button.Applications and button.Applications.SetFrameLevel then
			button.Applications:SetFrameLevel(20)
		end

		if button.ChargeCount and button.ChargeCount.SetFrameLevel then
			button.ChargeCount:SetFrameLevel(20)
		end

		fontString:SetFont(GetFont(), config.size, "OUTLINE")
		fontString:ClearAllPoints()
		fontString:SetPoint(config.point, button, config.point, 0, config.y)
	end

	---@type table<ViewerName, integer>
	local cooldownFontSize = {
		EssentialCooldownViewer = 20,
		UtilityCooldownViewer = 12,
		BuffIconCooldownViewer = 16,
	}

	---@param button CooldownViewerItem
	---@param viewerName ViewerName
	local function ApplyCountdownFont(button, viewerName)
		local size = cooldownFontSize[viewerName]

		if not size then
			return
		end

		local cooldown = button.Cooldown

		if not cooldown or not cooldown.GetCountdownFontString then
			return
		end

		local fontString = cooldown:GetCountdownFontString()

		if not fontString then
			return
		end

		fontString:SetFont(GetFont(), size, "OUTLINE")
		fontString:SetTextColor(1, 1, 1, 1)
	end

	---@param button CooldownViewerItem
	---@param viewerName ViewerName
	local function StyleButton(button, viewerName)
		ApplySquare(button)
		ApplyStack(button, viewerName)
		ApplyCountdownFont(button, viewerName)
	end

	---@param viewerFrame Frame
	---@param viewerName ViewerName
	local function StyleViewer(viewerFrame, viewerName)
		for _, child in ipairs({ viewerFrame:GetChildren() }) do
			---@cast child CooldownViewerItem
			if child.Icon then
				StyleButton(child, viewerName)
			end
		end
	end

	---@return CooldownViewerItem[], CooldownViewerItem[]
	local function CollectBuffIconChildren()
		local allIconChildren = {}
		local visibleIcons = {}

		for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
			---@cast child CooldownViewerItem
			if child.Icon and child.layoutIndex ~= nil then
				allIconChildren[#allIconChildren + 1] = child

				if child:IsShown() then
					visibleIcons[#visibleIcons + 1] = child
				end
			end
		end

		table.sort(visibleIcons, function(firstChild, secondChild)
			return (firstChild.layoutIndex or 0) < (secondChild.layoutIndex or 0)
		end)

		return visibleIcons, allIconChildren
	end

	-- keyed by auraId, which is the common identifier across both maps
	---@type table<integer, AuraFrame>
	local childFrames = {}

	---@type FunctionContainer?
	local recenterTimer

	---@type boolean
	local isRecentering = false

	---@type fun()
	local RecenterBuffIcons

	---@return boolean ranOrSkipped false only when the viewer is not initialized yet
	local function PerformRecenter()
		if isRecentering then
			return true
		end

		if not BuffIconCooldownViewer.IsInitialized or not BuffIconCooldownViewer:IsInitialized() then
			return false
		end

		if EditModeManagerFrame and EditModeManagerFrame.layoutApplyInProgress then
			return true
		end

		isRecentering = true

		local visibleNativeIcons, allIconChildren = CollectBuffIconChildren()

		for _, child in ipairs(allIconChildren) do
			if not child.RecenterHooked and child.OnActiveStateChanged then
				child.RecenterHooked = true
				hooksecurefunc(child, "OnActiveStateChanged", PerformRecenter)
				hooksecurefunc(child, "OnUnitAuraAddedEvent", PerformRecenter)
				hooksecurefunc(child, "OnUnitAuraRemovedEvent", PerformRecenter)
			end
		end

		local orderedAuraIds = {}
		for auraId, auraFrame in pairs(childFrames) do
			if auraFrame:IsShown() then
				orderedAuraIds[#orderedAuraIds + 1] = auraId
			end
		end
		table.sort(orderedAuraIds)

		local totalSlots = #allIconChildren
		local visibleNativeCount = #visibleNativeIcons
		local customCount = #orderedAuraIds

		if visibleNativeCount + customCount == 0 then
			isRecentering = false
			return true
		end

		local iconWidth, iconHeight
		if visibleNativeCount > 0 then
			iconWidth = visibleNativeIcons[1]:GetWidth()
			iconHeight = visibleNativeIcons[1]:GetHeight()
		else
			local referenceFrame = childFrames[orderedAuraIds[1]]
			iconWidth = referenceFrame:GetWidth()
			iconHeight = referenceFrame:GetHeight()
		end

		if not iconWidth or iconWidth == 0 or not iconHeight or iconHeight == 0 then
			isRecentering = false
			return true
		end

		local isHorizontal = BuffIconCooldownViewer.isHorizontal ~= false
		local isNormalDirection = BuffIconCooldownViewer.iconDirection == 1
		local missingSlots = totalSlots - visibleNativeCount - customCount

		if isHorizontal then
			local padding = BuffIconCooldownViewer.childXPadding or 0
			local directionModifier = isNormalDirection and 1 or -1
			local startX = ((iconWidth + padding) * missingSlots / 2) * directionModifier
			local anchor = isNormalDirection and "TOPLEFT" or "TOPRIGHT"

			for index, icon in ipairs(visibleNativeIcons) do
				local xOffset = startX + (index - 1) * (iconWidth + padding) * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, xOffset, 0)
			end

			for index, auraId in ipairs(orderedAuraIds) do
				local auraFrame = childFrames[auraId]
				local xOffset = startX
					+ (visibleNativeCount + index - 1) * (iconWidth + padding) * directionModifier
				auraFrame:ClearAllPoints()
				auraFrame:SetPoint(anchor, BuffIconCooldownViewer, anchor, xOffset, 0)
			end
		else
			local padding = BuffIconCooldownViewer.childYPadding or 0
			local directionModifier = isNormalDirection and -1 or 1
			local startY = -((iconHeight + padding) * missingSlots / 2) * directionModifier
			local anchor = isNormalDirection and "BOTTOMLEFT" or "TOPLEFT"

			for index, icon in ipairs(visibleNativeIcons) do
				local yOffset = startY - (index - 1) * (iconHeight + padding) * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, 0, yOffset)
			end

			for index, auraId in ipairs(orderedAuraIds) do
				local auraFrame = childFrames[auraId]
				local yOffset = startY
					- (visibleNativeCount + index - 1) * (iconHeight + padding) * directionModifier
				auraFrame:ClearAllPoints()
				auraFrame:SetPoint(anchor, BuffIconCooldownViewer, anchor, 0, yOffset)
			end
		end

		isRecentering = false
		return true
	end

	function RecenterBuffIcons()
		if recenterTimer then
			return
		end

		recenterTimer = C_Timer.NewTimer(0, function()
			recenterTimer = nil

			if not PerformRecenter() then
				RecenterBuffIcons()
			end
		end)
	end

	---@type AuraListenerFrame
	local listenerFrame = CreateFrame("Frame", nil, UIParent)
	listenerFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	listenerFrame:RegisterEvent("LOADING_SCREEN_DISABLED")

	---@param auraFrame AuraFrame
	local function Teardown(auraFrame)
		if auraFrame.timer then
			auraFrame.timer:Cancel()
			auraFrame.timer = nil
		end

		if auraFrame:IsShown() then
			auraFrame:Hide()
			CooldownFrame_Clear(auraFrame.Cooldown)
			RecenterBuffIcons()
		end
	end

	local function TeardownAll()
		for _, auraFrame in pairs(childFrames) do
			Teardown(auraFrame)
		end
	end

	---@param auraId integer
	---@return AuraFrame
	local function GetOrCreateAuraFrame(auraId)
		if childFrames[auraId] then
			return childFrames[auraId]
		end

		---@type AuraFrame
		local auraFrame = CreateFrame("Frame", nil, listenerFrame)
		auraFrame:SetSize(40, 40)
		auraFrame:Hide()

		auraFrame.Icon = auraFrame:CreateTexture(nil, "ARTWORK")
		auraFrame.Icon:SetAllPoints(auraFrame)

		auraFrame.Cooldown = CreateFrame("Cooldown", nil, auraFrame)
		auraFrame.Cooldown:SetPoint("TOPLEFT", auraFrame, "TOPLEFT", BORDER_PIXELS, -BORDER_PIXELS)
		auraFrame.Cooldown:SetPoint("BOTTOMRIGHT", auraFrame, "BOTTOMRIGHT", -BORDER_PIXELS, BORDER_PIXELS)
		---@diagnostic disable-next-line: missing-parameter
		auraFrame.Cooldown:SetSwipeTexture(SQUARE_TEXTURE)
		auraFrame.Cooldown:SetReverse(true)
		auraFrame.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
		auraFrame.Cooldown:SetUseAuraDisplayTime(true)

		local borderFrame = CreateFrame("Frame", nil, auraFrame, "BackdropTemplate")
		borderFrame:SetFrameLevel(auraFrame:GetFrameLevel() + 1)
		borderFrame:SetAllPoints(auraFrame)
		borderFrame:SetBackdrop({ edgeFile = SQUARE_TEXTURE, edgeSize = BORDER_PIXELS })
		borderFrame:SetBackdropBorderColor(0, 0, 0, 1)

		childFrames[auraId] = auraFrame
		return auraFrame
	end

	function listenerFrame:UpdateEventRegistration()
		local hasCastEntries = next(castToAuraInfo) ~= nil
		local anyItemEquipped = false

		for _, itemInfo in pairs(castToItemInfo) do
			if C_Item.IsEquippedItem(itemInfo.itemId) then
				anyItemEquipped = true
				break
			end
		end

		if hasCastEntries or anyItemEquipped then
			self:RegisterEvent("PLAYER_DEAD")
			self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		else
			self:UnregisterEvent("PLAYER_DEAD")
			self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
			TeardownAll()
		end
	end

	listenerFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "PLAYER_EQUIPMENT_CHANGED" or event == "LOADING_SCREEN_DISABLED" then
			self:UpdateEventRegistration()
		elseif event == "PLAYER_DEAD" then
			TeardownAll()
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local _, _, spellId = ...

			local itemInfo = castToItemInfo[spellId]
			local auraInfo = castToAuraInfo[spellId]

			---@type { auraId: integer, duration: integer }?
			local matched = itemInfo and { auraId = spellId, duration = itemInfo.duration }
				or auraInfo and { auraId = auraInfo.auraId, duration = auraInfo.duration }
				or nil

			if matched == nil then
				return
			end

			local auraFrame = GetOrCreateAuraFrame(matched.auraId)

			if auraFrame.timer then
				auraFrame.timer:Cancel()
			end

			auraFrame.Icon:SetTexture(C_Spell.GetSpellTexture(matched.auraId))
			CooldownFrame_Set(auraFrame.Cooldown, GetTime(), matched.duration, true, false, 1)
			auraFrame:Show()
			RecenterBuffIcons()

			auraFrame.timer = C_Timer.NewTimer(matched.duration, function()
				Teardown(auraFrame)
			end)
		end
	end)

	local function SetupBuffIconItem(item)
		local cd = item.Cooldown

		if not cd then
			return
		end

		cd:SetCountdownFont("GameFontHighlightOutline")
		cd:SetCountdownMillisecondsThreshold(4)
		cd:SetUseAuraDisplayTime(true)
	end

	-- Essential and Utility items already have their font set via cooldownFont KeyValues;
	-- only the threshold needs to be added here.
	local function SetupCooldownItem(item)
		local cd = item.Cooldown

		if not cd then
			return
		end

		cd:SetCountdownMillisecondsThreshold(4)
	end

	EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
		hooksecurefunc(CooldownViewerEssentialItemMixin, "OnLoad", function(self)
			StyleButton(self, "EssentialCooldownViewer")
			SetupCooldownItem(self)
		end)

		hooksecurefunc(CooldownViewerUtilityItemMixin, "OnLoad", function(self)
			StyleButton(self, "UtilityCooldownViewer")
			SetupCooldownItem(self)
		end)

		hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnLoad", function(self)
			StyleButton(self, "BuffIconCooldownViewer")
			SetupBuffIconItem(self)
		end)

		hooksecurefunc(EssentialCooldownViewer, "RefreshLayout", function()
			StyleViewer(EssentialCooldownViewer, "EssentialCooldownViewer")
		end)

		hooksecurefunc(UtilityCooldownViewer, "RefreshLayout", function()
			StyleViewer(UtilityCooldownViewer, "UtilityCooldownViewer")
		end)

		hooksecurefunc(BuffIconCooldownViewer, "RefreshLayout", function()
			StyleViewer(BuffIconCooldownViewer, "BuffIconCooldownViewer")
			RecenterBuffIcons()
		end)

		hooksecurefunc(BuffIconCooldownViewer, "Layout", function()
			PerformRecenter()
		end)

		StyleViewer(EssentialCooldownViewer, "EssentialCooldownViewer")
		StyleViewer(UtilityCooldownViewer, "UtilityCooldownViewer")
		StyleViewer(BuffIconCooldownViewer, "BuffIconCooldownViewer")

		RecenterBuffIcons()

		for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
			SetupBuffIconItem(child)
		end

		for _, child in ipairs({ EssentialCooldownViewer:GetChildren() }) do
			SetupCooldownItem(child)
		end

		for _, child in ipairs({ UtilityCooldownViewer:GetChildren() }) do
			SetupCooldownItem(child)
		end
	end)
end)
