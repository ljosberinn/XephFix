local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.CooldownManagerTweaks then
		return
	end

	---@class ApplicationsFrame : Frame
	---@field Applications FontString?

	---@class ChargeCountFrame : Frame
	---@field Current FontString?

	---@class PandemicFrame : Frame
	---@field Border Frame?

	---@class PixelBorderFrame : Frame
	---@field HorizontalLines Texture[]
	---@field VerticalLines Texture[]

	---@class CooldownViewerItem : Frame
	---@field Icon Texture?
	---@field Cooldown CooldownFrame?
	---@field Applications ApplicationsFrame?
	---@field ChargeCount ChargeCountFrame?
	---@field CustomBorderFrame PixelBorderFrame?
	---@field layoutIndex integer?
	---@field DebuffBorder Frame?
	---@field PandemicIcon PandemicFrame?
	---@field TriggerPandemicAlert fun(self: CooldownViewerItem)
	---@field ShowPandemicStateFrame fun(self: CooldownViewerItem)
	---@field PandemicHooked boolean?
	---@field PandemicBorderHooked boolean?
	---@field RecenterHooked boolean?
	---@field OnActiveStateChanged fun()
	---@field OnUnitAuraAddedEvent fun()
	---@field OnUnitAuraRemovedEvent fun()

	---@class StackConfig
	---@field point string
	---@field y integer
	---@field size integer

	---@alias ViewerName "EssentialCooldownViewer"|"UtilityCooldownViewer"|"BuffIconCooldownViewer"

	---@type string
	local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8x8"

	---@type integer
	local BORDER_PIXELS = 1

	---@type integer
	local AURA_ICON_SIZE = 40

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

	---@param parent Frame
	---@return PixelBorderFrame
	local function CreatePixelBorder(parent)
		---@type PixelBorderFrame
		local borderFrame = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
		borderFrame:SetAllPoints(parent)
		borderFrame.HorizontalLines = {}
		borderFrame.VerticalLines = {}

		for _, edge in ipairs({ "TOP", "BOTTOM" }) do
			local line = borderFrame:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint(edge .. "LEFT", borderFrame, edge .. "LEFT", 0, 0)
			line:SetPoint(edge .. "RIGHT", borderFrame, edge .. "RIGHT", 0, 0)
			table.insert(borderFrame.HorizontalLines, line)
		end

		for _, edge in ipairs({ "LEFT", "RIGHT" }) do
			local line = borderFrame:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint("TOP" .. edge, borderFrame, "TOP" .. edge, 0, 0)
			line:SetPoint("BOTTOM" .. edge, borderFrame, "BOTTOM" .. edge, 0, 0)
			table.insert(borderFrame.VerticalLines, line)
		end

		return borderFrame
	end

	---@param button CooldownViewerItem
	local function ApplySquare(button)
		local icon = button.Icon

		if not icon then
			return
		end

		-- Edit Mode icon size scales the viewer, so a 1 unit border is rarely 1 pixel.
		local borderSize = BORDER_PIXELS * PixelUtil.GetPixelToUIUnitFactor() / button:GetEffectiveScale()

		-- Fill icon to button edges with no zoom crop
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
		icon:SetTexCoord(0, 1, 0, 1)

		-- Replace circular swipe with square, inset by border width
		for i = 1, select("#", button:GetChildren()) do
			local child = select(i, button:GetChildren())

			if child and child.SetSwipeTexture then
				child:SetSwipeTexture(SQUARE_TEXTURE)
				child:ClearAllPoints()
				child:SetPoint("TOPLEFT", button, "TOPLEFT", borderSize, -borderSize)
				child:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderSize, borderSize)
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

		if not button.PandemicHooked then
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

		if not button.PandemicBorderHooked then
			button.PandemicBorderHooked = true

			hooksecurefunc(button, "ShowPandemicStateFrame", function()
				if button.PandemicIcon and button.PandemicIcon.Border then
					button.PandemicIcon.Border:SetAlpha(0)
				end
			end)
		end

		-- Black border overlay
		if not button.CustomBorderFrame then
			local borderFrame = CreatePixelBorder(button)
			borderFrame:SetFrameLevel(button:GetFrameLevel() + 1)
			button.CustomBorderFrame = borderFrame
		end

		for _, line in ipairs(button.CustomBorderFrame.HorizontalLines) do
			line:SetHeight(borderSize)
		end

		for _, line in ipairs(button.CustomBorderFrame.VerticalLines) do
			line:SetWidth(borderSize)
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

		if button.Applications then
			button.Applications:SetFrameLevel(20)
		end

		if button.ChargeCount then
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

		if not cooldown then
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

		if not BuffIconCooldownViewer:IsInitialized() then
			return false
		end

		if EditModeManagerFrame.layoutApplyInProgress then
			return true
		end

		isRecentering = true

		local visibleNativeIcons, allIconChildren = CollectBuffIconChildren()

		for _, child in ipairs(allIconChildren) do
			if not child.RecenterHooked then
				child.RecenterHooked = true
				hooksecurefunc(child, "OnActiveStateChanged", PerformRecenter)
				hooksecurefunc(child, "OnUnitAuraAddedEvent", PerformRecenter)
				hooksecurefunc(child, "OnUnitAuraRemovedEvent", PerformRecenter)
			end
		end

		local totalSlots = #allIconChildren
		local visibleNativeCount = #visibleNativeIcons

		if visibleNativeCount == 0 then
			isRecentering = false
			return true
		end

		local iconWidth = AURA_ICON_SIZE
		local iconHeight = AURA_ICON_SIZE

		local isHorizontal = BuffIconCooldownViewer.isHorizontal ~= false
		local isNormalDirection = BuffIconCooldownViewer.iconDirection == 1
		local missingSlots = totalSlots - visibleNativeCount
		local padding = isHorizontal and (BuffIconCooldownViewer.childXPadding or 0)
			or (BuffIconCooldownViewer.childYPadding or 0)

		-- Whole-pixel step and start keep every icon on the same sub-pixel offset; otherwise the
		-- half-step centering and per-icon rounding make borders and gaps uneven.
		local scale = BuffIconCooldownViewer:GetEffectiveScale()

		if isHorizontal then
			local directionModifier = isNormalDirection and 1 or -1
			local step = PixelUtil.GetNearestPixelSize(iconWidth + padding, scale)
			local startX = PixelUtil.GetNearestPixelSize(step * missingSlots / 2, scale) * directionModifier
			local anchor = isNormalDirection and "TOPLEFT" or "TOPRIGHT"

			for index, icon in ipairs(visibleNativeIcons) do
				local xOffset = startX + (index - 1) * step * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, xOffset, 0)
			end
		else
			local directionModifier = isNormalDirection and -1 or 1
			local step = PixelUtil.GetNearestPixelSize(iconHeight + padding, scale)
			local startY = -PixelUtil.GetNearestPixelSize(step * missingSlots / 2, scale) * directionModifier
			local anchor = isNormalDirection and "BOTTOMLEFT" or "TOPLEFT"

			for index, icon in ipairs(visibleNativeIcons) do
				local yOffset = startY - (index - 1) * step * directionModifier
				icon:ClearAllPoints()
				icon:SetPoint(anchor, BuffIconCooldownViewer, anchor, 0, yOffset)
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

	local function SetupBuffIconItem(item)
		local cd = item.Cooldown

		if not cd then
			return
		end

		cd:SetCountdownFont("GameFontHighlightOutline")
		cd:SetCountdownMillisecondsThreshold(5)
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

		local function StyleAllViewers()
			StyleViewer(EssentialCooldownViewer, "EssentialCooldownViewer")
			StyleViewer(UtilityCooldownViewer, "UtilityCooldownViewer")
			StyleViewer(BuffIconCooldownViewer, "BuffIconCooldownViewer")

			RecenterBuffIcons()
		end

		-- Border thickness and recenter offsets are derived from the pixel size.
		EventRegistry:RegisterFrameEventAndCallback("UI_SCALE_CHANGED", StyleAllViewers)
		EventRegistry:RegisterFrameEventAndCallback("DISPLAY_SIZE_CHANGED", StyleAllViewers)

		StyleAllViewers()

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
