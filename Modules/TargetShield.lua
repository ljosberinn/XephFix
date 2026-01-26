local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not Private.IsXeph then
		return
	end

	local frame = CreateFrame("Frame", "XephUITargetShieldTracker", UIParent)

	frame:SetSize(100, 24)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
	frame.text:SetPoint("CENTER", frame)
	frame.text:SetFontHeight(18)

	frame:SetScript("OnEvent", function(self, event, ...)
		if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
			local unit = ...

			if unit ~= "target" then
				return
			end
		end

		if self.timer then
			return
		end

		self.timer = C_Timer.NewTimer(0.33, function()
			self.timer = nil

			if
				not UnitExists("target")
				or UnitIsPlayer("target")
				or (UnitIsFriend("player", "target") and not UnitCanAttack("player", "target"))
			then
				return
			end

			local total = UnitGetTotalAbsorbs("target")

			self.text:SetText(string.format("ABSORB: %s", AbbreviateNumbers(total)))
			self.text:ClearAllPoints()
			self.text:SetPoint("CENTER", self)
			self:SetAlpha(total)
		end)
	end)
end)
