local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.DebuffDurationDecimals then
		return
	end

	local MILLISECONDS_THRESHOLD = 5
	local ICON_SIZE = 30
	local GROUP_KEY = "Debuffs"

	-- Fields of DebuffFrame.AuraContainer that Edit Mode writes before calling UpdateGridLayout.
	local LAYOUT_FIELDS = {
		"isHorizontal",
		"addIconsToRight",
		"addIconsToTop",
		"iconStride",
		"iconPadding",
		"iconScale",
		"showDispelType",
	}

	local DISPEL_SYMBOLS = {
		Magic = DEBUFF_SYMBOL_MAGIC,
		Curse = DEBUFF_SYMBOL_CURSE,
		Disease = DEBUFF_SYMBOL_DISEASE,
		Poison = DEBUFF_SYMBOL_POISON,
		Bleed = DEBUFF_SYMBOL_BLEED,
	}

	-- Addon code can't format secret aura durations in combat, so the buttons come from Blizzard's
	-- CustomAuraContainer, which renders durations securely with our formatter.
	local durationFormatter = C_StringUtil.CreateSecondsFormatter()

	do
		-- Mirrors DefaultAuraDurationFormatter in Blizzard_AuraContainerShared.lua.
		local maxIntervalCurve = C_CurveUtil.CreateCurve()
		maxIntervalCurve:SetType(Enum.LuaCurveType.Step)
		maxIntervalCurve:AddPoint(0, Enum.SecondsFormatterInterval.Seconds)
		maxIntervalCurve:AddPoint(1 + 1.5 * SECONDS_PER_MIN, Enum.SecondsFormatterInterval.Minutes)
		maxIntervalCurve:AddPoint(1 + 1.5 * SECONDS_PER_HOUR, Enum.SecondsFormatterInterval.Hours)
		maxIntervalCurve:AddPoint(1 + 1.5 * SECONDS_PER_DAY, Enum.SecondsFormatterInterval.Days)

		durationFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
		durationFormatter:SetRounding(Enum.SecondsFormatterRounding.Truncate)
		durationFormatter:SetCanRoundUpLastUnit(true)
		durationFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
		durationFormatter:SetMaxIntervalCurve(maxIntervalCurve)
		durationFormatter:SetDesiredUnitCount(1)
		durationFormatter:SetMillisecondsThreshold(MILLISECONDS_THRESHOLD)
	end

	-- AuraButtonMixin:UpdateDuration colors durations white below BUFF_DURATION_WARNING_TIME, gold above.
	local durationColorCurve = C_CurveUtil.CreateColorCurve()
	durationColorCurve:SetType(Enum.LuaCurveType.Step)
	durationColorCurve:AddPoint(0, HIGHLIGHT_FONT_COLOR)
	durationColorCurve:AddPoint(BUFF_DURATION_WARNING_TIME, NORMAL_FONT_COLOR)

	---@class DebuffButtonRegions
	---@field button table CustomAuraButtonTemplate's public object; its display setters aren't in the type annotations.
	---@field icon Texture
	---@field durationText FontString
	---@field dispelBorder Texture
	---@field dispelBorderStyle number? Enum.CustomAuraButtonDispelTypeTextureStyle
	---@field dispelSymbol FontString

	---@type DebuffButtonRegions[]
	local debuffButtons = {}
	local appliedLayout = {}
	local isLayoutPending = false

	-- Mirrors AuraContainerMixin:UpdateGridLayout and AuraButtonMixin:Update in BuffFrame.lua.
	---@param regions DebuffButtonRegions
	local function ApplyButtonLayout(regions)
		local auraContainer = DebuffFrame.AuraContainer
		local iconPoint, durationRelativePoint

		if auraContainer.isHorizontal then
			regions.button:SetSize(30, 40)
			iconPoint = auraContainer.addIconsToTop and "BOTTOM" or "TOP"
			durationRelativePoint = auraContainer.addIconsToTop and "TOP" or "BOTTOM"
		else
			regions.button:SetSize(60, 30)
			iconPoint = auraContainer.addIconsToRight and "LEFT" or "RIGHT"
			durationRelativePoint = auraContainer.addIconsToRight and "RIGHT" or "LEFT"
		end

		regions.icon:ClearAllPoints()
		regions.icon:SetPoint(iconPoint)
		regions.durationText:ClearAllPoints()
		regions.durationText:SetPoint(iconPoint, regions.icon, durationRelativePoint)
		regions.durationText:SetShown(CVarCallbackRegistry:GetCVarValueBool("buffDurations"))
		regions.dispelSymbol:SetAlpha(CVarCallbackRegistry:GetCVarValueBool("colorblindMode") and 1 or 0)

		local dispelBorderStyle = auraContainer.showDispelType
				and Enum.CustomAuraButtonDispelTypeTextureStyle.BorderWithIcon
			or Enum.CustomAuraButtonDispelTypeTextureStyle.Border

		if regions.dispelBorderStyle == dispelBorderStyle then
			return
		end

		if regions.dispelBorderStyle then
			regions.button:RemoveDispelTypeTexture(regions.dispelBorder)
		end

		regions.button:AddDispelTypeTexture(regions.dispelBorder, {
			style = dispelBorderStyle,
			showWithoutDispelType = true,
		})
		regions.dispelBorderStyle = dispelBorderStyle
	end

	-- Mirrors AuraButtonArtTemplate in BuffFrameTemplates.xml. Runs before the container locks the
	-- button against addon access while auras are secret, so it's safe even when created in combat.
	---@param button table
	local function InitializeDebuffButton(button)
		local icon = button:CreateTexture(nil, "BACKGROUND")
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		button:SetIcon(icon)

		local durationText = button:CreateFontString(nil, "BACKGROUND", DEFAULT_AURA_DURATION_FONT)
		button:SetDurationText(durationText, {
			textFormatter = durationFormatter,
			textColor = {
				curve = durationColorCurve,
				property = Enum.DurationTextBindingProperty.RemainingDuration,
			},
		})

		local countText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		countText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(countText)

		local dispelBorder = button:CreateTexture(nil, "OVERLAY")
		dispelBorder:SetSize(40, 40)
		dispelBorder:SetPoint("CENTER", icon)

		local dispelSymbol = button:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
		dispelSymbol:SetPoint("TOPLEFT", 2, -2)
		button:SetDispelTypeText(dispelSymbol, { customDispelTextMap = DISPEL_SYMBOLS })

		---@type DebuffButtonRegions
		local regions = {
			button = button,
			icon = icon,
			durationText = durationText,
			dispelBorder = dispelBorder,
			dispelSymbol = dispelSymbol,
		}

		table.insert(debuffButtons, regions)
		ApplyButtonLayout(regions)
	end

	---@type table CustomAuraContainerTemplate's public object.
	local container = CreateFrame("AuraContainer", nil, DebuffFrame, "CustomAuraContainerTemplate")
	container:SetUnit(PlayerFrame.unit or "player")
	container:AddAuraGroup(GROUP_KEY, "HARMFUL", {
		maxFrameCount = DebuffFrame.maxAuras,
		initializeFrame = InitializeDebuffButton,
	})

	-- Private aura anchors are siblings of this container and keep their positions, since
	-- DebuffFrame still lays out its hidden buttons in front of them.
	DebuffFrame.AuraContainer:Hide()

	local function ApplyLayout()
		local auraContainer = DebuffFrame.AuraContainer
		local anchorPoint = (auraContainer.addIconsToTop and "BOTTOM" or "TOP")
			.. (auraContainer.addIconsToRight and "LEFT" or "RIGHT")
		local iconStride = auraContainer.iconStride
		local iconPadding = auraContainer.iconPadding

		container:ClearAllPoints()
		container:SetPoint(anchorPoint, auraContainer, anchorPoint)
		container:SetScale(auraContainer.iconScale or 1)
		container:SetFlowLayoutAxis(
			auraContainer.isHorizontal and AnchorUtil.FlowLayoutAxis.Horizontal or AnchorUtil.FlowLayoutAxis.Vertical
		)
		container:SetFlowLayoutAnchorPoint(anchorPoint)
		container:SetFlowLayoutGrowthDirection(
			auraContainer.addIconsToRight and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
			auraContainer.addIconsToTop and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
		)
		container:SetFlowLayoutMaximumLineSize(iconStride * ICON_SIZE + (iconStride - 1) * iconPadding)
		container:SetAuraGroupLayout(GROUP_KEY, {
			elementSpacing = iconPadding,
			lineSpacing = iconPadding,
		})

		for _, regions in ipairs(debuffButtons) do
			ApplyButtonLayout(regions)
		end
	end

	-- The buttons reject addon access while auras are secret, so changes wait for that to lift.
	local function RequestLayout()
		if C_Secrets.ShouldAurasBeSecret() then
			isLayoutPending = true
			return
		end

		isLayoutPending = false
		ApplyLayout()
	end

	local function ApplyPendingLayout()
		if not isLayoutPending then
			return
		end

		RequestLayout()
	end

	hooksecurefunc(DebuffFrame, "UpdateGridLayout", function()
		local auraContainer = DebuffFrame.AuraContainer
		local hasChanged = false

		for _, field in ipairs(LAYOUT_FIELDS) do
			if appliedLayout[field] ~= auraContainer[field] then
				appliedLayout[field] = auraContainer[field]
				hasChanged = true
			end
		end

		if not hasChanged then
			return
		end

		RequestLayout()
	end)

	-- DebuffFrame calls this with the new unit when PlayerFrame switches to or from a vehicle.
	hooksecurefunc(DebuffFrame, "UpdatePrivateAuraAnchors", function(_, unit)
		if not unit then
			return
		end

		container:SetUnit(unit)
	end)

	CVarCallbackRegistry:RegisterCallback("buffDurations", RequestLayout)
	CVarCallbackRegistry:RegisterCallback("colorblindMode", RequestLayout)
	EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_ENABLED", ApplyPendingLayout)
	EventRegistry:RegisterFrameEventAndCallback("ADDON_RESTRICTION_STATE_CHANGED", ApplyPendingLayout)

	RequestLayout()
end)
