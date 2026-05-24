local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not Private.IsXeph then
		return
	end

	---@class ApplicationsFrame : Frame
	---@field Applications FontString?

	---@class ChargeCountFrame : Frame
	---@field Current FontString?

	---@class CooldownViewerItem : Frame
	---@field Icon Texture?
	---@field Cooldown CooldownFrame?
	---@field Applications ApplicationsFrame?
	---@field ChargeCount ChargeCountFrame?
	---@field CustomBorderFrame Frame?
	---@field layoutIndex integer?
	---@field DebuffBorder Frame?
	---@field PandemicIcon Frame?
	---@field TriggerPandemicAlert (fun(self: CooldownViewerItem))?
	---@field PandemicHooked boolean?
	---@field RecenterHooked boolean?

	---@class StackConfig
	---@field point string
	---@field y integer
	---@field size integer

	---@alias ViewerName "EssentialCooldownViewer"|"UtilityCooldownViewer"|"BuffIconCooldownViewer"

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

		-- Replace circular mask texture / hide the round CDM overlay
		for _, region in next, { button:GetRegions() } do
			if region:IsObjectType("Texture") then
				---@cast region Texture
				local texture = region:GetTexture()
				local atlas = region:GetAtlas()

				if not issecretvalue(texture) and texture == 6707800 then
					region:SetTexture(SQUARE_TEXTURE)
				elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
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

	local function RecenterBuffIcons()
		if not BuffIconCooldownViewer.IsInitialized or not BuffIconCooldownViewer:IsInitialized() then
			C_Timer.After(0, RecenterBuffIcons)
			return
		end

		if EditModeManagerFrame and EditModeManagerFrame.layoutApplyInProgress then
			return
		end

		local visibleIcons, allIconChildren = CollectBuffIconChildren()

		for _, child in ipairs(allIconChildren) do
			if not child.RecenterHooked then
				child.RecenterHooked = true
				hooksecurefunc(child, "OnActiveStateChanged", RecenterBuffIcons)
				hooksecurefunc(child, "OnUnitAuraAddedEvent", RecenterBuffIcons)
				hooksecurefunc(child, "OnUnitAuraRemovedEvent", RecenterBuffIcons)
			end
		end

		local totalSlots = #allIconChildren
		local visibleCount = #visibleIcons

		if visibleCount == 0 then
			return
		end

		local referenceIcon = visibleIcons[1]
		local iconWidth = referenceIcon:GetWidth()
		local iconHeight = referenceIcon:GetHeight()

		if not iconWidth or iconWidth == 0 or not iconHeight or iconHeight == 0 then
			return
		end

		local isHorizontal = BuffIconCooldownViewer.isHorizontal ~= false
		local isNormalDirection = BuffIconCooldownViewer.iconDirection == 1
		local missingSlots = totalSlots - visibleCount

		if isHorizontal then
			local padding = BuffIconCooldownViewer.childXPadding or 0
			local directionModifier = isNormalDirection and 1 or -1
			local startX = ((iconWidth + padding) * missingSlots / 2) * directionModifier
			local anchor = isNormalDirection and "TOPLEFT" or "TOPRIGHT"

			for index, icon in ipairs(visibleIcons) do
				local xOffset = startX + (index - 1) * (iconWidth + padding) * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, xOffset, 0)
			end
		else
			local padding = BuffIconCooldownViewer.childYPadding or 0
			local directionModifier = isNormalDirection and -1 or 1
			local startY = -((iconHeight + padding) * missingSlots / 2) * directionModifier
			local anchor = isNormalDirection and "BOTTOMLEFT" or "TOPLEFT"

			for index, icon in ipairs(visibleIcons) do
				local yOffset = startY - (index - 1) * (iconHeight + padding) * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, 0, yOffset)
			end
		end
	end

	EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
		hooksecurefunc(CooldownViewerEssentialItemMixin, "OnLoad", function(self)
			StyleButton(self, "EssentialCooldownViewer")
		end)

		hooksecurefunc(CooldownViewerUtilityItemMixin, "OnLoad", function(self)
			StyleButton(self, "UtilityCooldownViewer")
		end)

		hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnLoad", function(self)
			StyleButton(self, "BuffIconCooldownViewer")
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

		StyleViewer(EssentialCooldownViewer, "EssentialCooldownViewer")
		StyleViewer(UtilityCooldownViewer, "UtilityCooldownViewer")
		StyleViewer(BuffIconCooldownViewer, "BuffIconCooldownViewer")

		RecenterBuffIcons()
	end)
end)
