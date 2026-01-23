local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if select(4, GetBuildInfo()) < 120000 then
		return
	end

	if not Private.IsXeph then
		return
	end

	local interruptId = 351338

	local FocusCastBarFrame = CreateFrame("Frame", "XephUIFocusCastBar", UIParent)
	FocusCastBarFrame:SetSize(250, 16)
	FocusCastBarFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -50)

	FocusCastBarFrame.CastBar = CreateFrame("StatusBar", nil, FocusCastBarFrame)
	FocusCastBarFrame.CastBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	FocusCastBarFrame.CastBar:SetSize(250, 16)

	do
		local texture = FocusCastBarFrame.CastBar:GetStatusBarTexture()
		if texture then
			texture:SetDrawLayer("BACKGROUND")
		end
	end

	FocusCastBarFrame.Background = FocusCastBarFrame:CreateTexture(nil, "BACKGROUND")
	FocusCastBarFrame.Background:SetAllPoints(FocusCastBarFrame.CastBar)
	FocusCastBarFrame.Background:SetColorTexture(0.1, 0.1, 0.1, 1)

	FocusCastBarFrame.Border = CreateFrame("Frame", nil, FocusCastBarFrame, "BackdropTemplate")
	FocusCastBarFrame.Border:SetPoint("TOPLEFT", FocusCastBarFrame, -1, 1)
	FocusCastBarFrame.Border:SetPoint("BOTTOMRIGHT", FocusCastBarFrame, 1, -1)
	FocusCastBarFrame.Border:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	FocusCastBarFrame.Border:SetBackdropBorderColor(0, 0, 0, 1)

	FocusCastBarFrame.Icon = FocusCastBarFrame:CreateTexture(nil, "ARTWORK")
	FocusCastBarFrame.Icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	FocusCastBarFrame.Icon:ClearAllPoints()
	FocusCastBarFrame.Icon:SetPoint("TOPLEFT", FocusCastBarFrame, "TOPLEFT", 0, 0)
	FocusCastBarFrame.Icon:SetPoint("BOTTOMLEFT", FocusCastBarFrame, "BOTTOMLEFT", 0, 0)
	FocusCastBarFrame.Icon:SetWidth(16)

	FocusCastBarFrame.CastBar:ClearAllPoints()
	FocusCastBarFrame.CastBar:SetPoint("TOPLEFT", FocusCastBarFrame.Icon, "TOPRIGHT", 0, 0)
	FocusCastBarFrame.CastBar:SetPoint("BOTTOMRIGHT", FocusCastBarFrame, "BOTTOMRIGHT", 0, 0)

	FocusCastBarFrame.SpellNameText =
		FocusCastBarFrame.CastBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	FocusCastBarFrame.SpellNameText:SetJustifyH("LEFT")
	FocusCastBarFrame.SpellNameText:SetFont(select(1, FocusCastBarFrame.SpellNameText:GetFont()), 16, "OUTLINE")
	FocusCastBarFrame.SpellNameText:SetShadowOffset(0, 0)
	FocusCastBarFrame.SpellNameText:SetPoint("LEFT", FocusCastBarFrame.CastBar, "LEFT", 4, 0)

	FocusCastBarFrame.TimeText = FocusCastBarFrame.CastBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	FocusCastBarFrame.TimeText:SetJustifyH("RIGHT")
	FocusCastBarFrame.TimeText:SetFont(select(1, FocusCastBarFrame.TimeText:GetFont()), 16, "OUTLINE")
	FocusCastBarFrame.TimeText:SetShadowOffset(0, 0)
	FocusCastBarFrame.TimeText:SetPoint("RIGHT", FocusCastBarFrame.CastBar, "RIGHT", -4, 0)

	FocusCastBarFrame.InterruptCooldownFrame = CreateFrame("Frame", nil, FocusCastBarFrame)
	FocusCastBarFrame.InterruptCooldownFrame:ClearAllPoints()
	FocusCastBarFrame.InterruptCooldownFrame:SetPoint("TOPRIGHT", FocusCastBarFrame, "TOPRIGHT", 16, 0)
	FocusCastBarFrame.InterruptCooldownFrame:SetPoint("BOTTOMRIGHT", FocusCastBarFrame, "BOTTOMRIGHT", 16, 0)
	FocusCastBarFrame.InterruptCooldownFrame:SetWidth(16)
	FocusCastBarFrame.InterruptCooldownFrame.Cooldown =
		CreateFrame("Cooldown", nil, FocusCastBarFrame.InterruptCooldownFrame)
	FocusCastBarFrame.InterruptCooldownFrame.Cooldown:SetAllPoints()
	FocusCastBarFrame.InterruptCooldownFrame.Icon =
		FocusCastBarFrame.InterruptCooldownFrame:CreateTexture(nil, "ARTWORK")
	FocusCastBarFrame.InterruptCooldownFrame.Icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	FocusCastBarFrame.InterruptCooldownFrame.Icon:ClearAllPoints()
	FocusCastBarFrame.InterruptCooldownFrame.Icon:SetPoint(
		"TOPLEFT",
		FocusCastBarFrame.InterruptCooldownFrame,
		"TOPLEFT",
		0,
		0
	)
	FocusCastBarFrame.InterruptCooldownFrame.Icon:SetPoint(
		"BOTTOMLEFT",
		FocusCastBarFrame.InterruptCooldownFrame,
		"BOTTOMLEFT",
		0,
		0
	)
	FocusCastBarFrame.InterruptCooldownFrame.Icon:SetWidth(16)
	FocusCastBarFrame.InterruptCooldownFrame.Icon:SetTexture(C_Spell.GetSpellTexture(interruptId))

	FocusCastBarFrame.InterruptCooldownFrame.Border =
		CreateFrame("Frame", nil, FocusCastBarFrame.InterruptCooldownFrame, "BackdropTemplate")
	FocusCastBarFrame.InterruptCooldownFrame.Border:SetPoint("TOPLEFT", FocusCastBarFrame.InterruptCooldownFrame, -1, 1)
	FocusCastBarFrame.InterruptCooldownFrame.Border:SetPoint(
		"BOTTOMRIGHT",
		FocusCastBarFrame.InterruptCooldownFrame,
		1,
		-1
	)
	FocusCastBarFrame.InterruptCooldownFrame.Border:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	FocusCastBarFrame.InterruptCooldownFrame.Border:SetBackdropBorderColor(0, 0, 0, 1)
	FocusCastBarFrame:Hide()
	FocusCastBarFrame.interruptOnCooldown = false

	FocusFrame.spellbar:HookScript("OnShow", function(self)
		FocusCastBarFrame:Show()
		FocusCastBarFrame.Icon:SetTexture(C_Spell.GetSpellTexture(self.spellID))
		FocusCastBarFrame.SpellNameText:SetText(self.Text:GetText())

		local min, max = self:GetMinMaxValues()
		FocusCastBarFrame.CastBar.min = min
		FocusCastBarFrame.CastBar.max = max
		FocusCastBarFrame.CastBar:SetMinMaxValues(min, max)
		FocusCastBarFrame.isInterruptable = self:IsInterruptable()

		FocusCastBarFrame:UpdateCastBarColor()
	end)

	function FocusCastBarFrame:UpdateCastBarColor()
		if self.isInterruptable then
			if self.interruptOnCooldown then
				local yellow = { 1.0, 1.0, 0.0, 1.0 }
				self.CastBar:SetStatusBarColor(unpack(yellow))
			else
				local green = { 0.0, 1.0, 0.0, 1.0 }
				self.CastBar:SetStatusBarColor(unpack(green))
			end
		else
			local red = { 1.0, 0.0, 0.0, 1.0 }
			self.CastBar:SetStatusBarColor(unpack(red))
		end
	end

	FocusFrame.spellbar:HookScript("OnHide", function()
		FocusCastBarFrame:Hide()
	end)

	-- these override the default behaviour to instantly hide the cast bar on interrupt/finish
	function FocusFrame.spellbar:PlayInterruptAnims()
		FocusFrame.spellbar:Hide()
	end

	function FocusFrame.spellbar:PlayFadeAnim()
		FocusFrame.spellbar:Hide()
	end

	local pattern = string.format("%s/%s", CAST_BAR_CAST_TIME, CAST_BAR_CAST_TIME)

	FocusFrame.spellbar:HookScript(
		"OnUpdate",
		---@param self StatusBar
		---@param elapsed number
		function(self, elapsed)
			local progress = self:GetValue()
			FocusCastBarFrame.CastBar:SetValue(progress)
			FocusCastBarFrame.TimeText:SetFormattedText(pattern, progress, FocusCastBarFrame.CastBar.max)
		end
	)

	FocusCastBarFrame:SetScript("OnEvent", function(self, event, ...)
		if event == "PLAYER_FOCUS_CHANGED" then
			if not InCombatLockdown() then
				return
			end

			if not UnitExists("focus") then
				for _, v in pairs(C_VoiceChat.GetTtsVoices()) do
					if string.find(v.name, "English") then
						C_VoiceChat.SpeakText(v.voiceID, "focus", 3, C_TTSSettings.GetSpeechVolume())

						return
					end
				end
			end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unit, castGUID, spellId = ...

			if spellId == interruptId then
				self.interruptOnCooldown = true
				self:UpdateCastBarColor()

				-- todo: adjust this for all specs etc
				FocusCastBarFrame.InterruptCooldownFrame.Cooldown:SetCooldown(GetTime(), 20)

				C_Timer.After(20, function()
					self.interruptOnCooldown = false

					if self:IsShown() then
						self:UpdateCastBarColor()
					end
				end)
			end
		elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
			if self.isInterruptable then
				return
			end

			self.isInterruptable = true

			self:UpdateCastBarColor()
		elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
			if not self.isInterruptable then
				return
			end

			self.isInterruptable = false

			self:UpdateCastBarColor()
		end
	end)

	FocusCastBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	FocusCastBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "focus")
	FocusCastBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "focus")
	FocusCastBarFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
end)
