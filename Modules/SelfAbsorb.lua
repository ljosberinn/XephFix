local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.SelfAbsorb then
		return
	end

	local healthBar = PlayerFrame_GetHealthBar()
	local healthBarContainer = PlayerFrame_GetHealthBarContainer()
	local healthTexture = healthBar:GetStatusBarTexture()
	local defaultAbsorbBar = healthBar.TotalAbsorbBar

	-- Blizzard only toggles Show/Hide on these, so alpha 0 sticks without touching their code paths.
	defaultAbsorbBar:SetAlpha(0)
	healthBar.OverAbsorbGlow:SetAlpha(0)

	local healthLayer, healthSubLevel = healthTexture:GetDrawLayer()

	-- Same width and max as the health bar, so absorbs scale exactly like health and spill past the frame edge.
	local absorbBar = CreateFrame("StatusBar", nil, healthBar)
	absorbBar:SetUsingParentLevel(true)
	absorbBar:SetRoundLayoutToNearestPixel(true)
	absorbBar:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT")
	absorbBar:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT")
	absorbBar:SetWidth(healthBar:GetWidth())
	absorbBar:SetStatusBarTexture(defaultAbsorbBar.fillAtlas)

	-- Drawn above the incoming heal prediction, which may never land.
	local fillTexture = absorbBar:GetStatusBarTexture()
	fillTexture:SetDrawLayer(healthLayer, healthSubLevel + 2)
	fillTexture:SetTexelSnappingBias(0)
	fillTexture:SetSnapToPixelGrid(false)
	fillTexture:SetVertexColor(defaultAbsorbBar.Fill:GetVertexColor())

	-- Engine tiling instead of texcoord math, as the fill width is secret.
	local overlay = absorbBar:CreateTexture(nil, healthLayer, nil, healthSubLevel + 3)
	overlay:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
	overlay:SetHorizTile(true)
	overlay:SetVertTile(true)
	overlay:SetAllPoints(fillTexture)

	local overAbsorbGlow = absorbBar:CreateTexture(nil, "ARTWORK")
	overAbsorbGlow:SetRoundLayoutToNearestPixel(true)
	overAbsorbGlow:SetTexture("Interface\\RaidFrame\\Shield-Overshield")
	overAbsorbGlow:SetBlendMode("ADD")
	overAbsorbGlow:SetWidth(16)
	overAbsorbGlow:SetPoint("TOPLEFT", absorbBar, "TOPRIGHT", -7, 0)
	overAbsorbGlow:SetPoint("BOTTOMLEFT", absorbBar, "BOTTOMRIGHT", -7, 0)

	-- The bar caps at one max health past current health, which is exactly the MaximumHealth clamp boundary.
	local calculator = CreateUnitHealPredictionCalculator()
	calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)

	local unit = PlayerFrame.unit

	local function Update()
		absorbBar:SetMinMaxValues(0, UnitHealthMax(unit))
		absorbBar:SetValue(UnitGetTotalAbsorbs(unit))

		UnitGetDetailedHealPrediction(unit, nil, calculator)

		local _, clamped = calculator:GetDamageAbsorbs()

		overAbsorbGlow:SetAlphaFromBoolean(clamped, 1, 0)
	end

	---@param nextUnit string
	local function SetUnit(nextUnit)
		unit = nextUnit
		absorbBar:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
		absorbBar:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
		Update()
	end

	absorbBar:RegisterEvent("PLAYER_ENTERING_WORLD")
	absorbBar:SetScript("OnEvent", Update)

	-- PlayerFrame swaps to the vehicle unit while keeping the same health bar.
	hooksecurefunc("UnitFrame_SetUnit", function(frame, nextUnit)
		if frame ~= PlayerFrame or nextUnit == unit then
			return
		end

		SetUnit(nextUnit)
	end)

	-- Blizzard resizes the health bar from UNIT_MAX_HEALTH_MODIFIERS_CHANGED's secret payload, which makes its width
	-- secret to us. The API exposes the same percent unsecreted, so mirror the resize instead of reading the bar.
	-- PlayerFrame.unit, as this also runs inside UnitFrame_SetUnit before our hook above updates `unit`.
	hooksecurefunc(PlayerFrame_GetTempMaxHealthLossBar(), "Update_MaxHealthLoss", function()
		local lossPercent = Clamp(GetUnitTotalModifiedMaxHealthPercent(PlayerFrame.unit), 0, 1)
		absorbBar:SetWidth(healthBarContainer:GetWidth() * (1 - lossPercent))
	end)

	SetUnit(unit)
end)
