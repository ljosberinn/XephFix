local addonName, Private = ...

local lowAlpha = 0.25

local frame = CreateFrame("Frame")
frame.lastAlpha = 1
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_REGEN_DISABLED" then
		self:UnregisterEvent("UNIT_AURA")
		self:ToggleAlpha(1)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:RegisterUnitEvent("UNIT_AURA", "player")
	elseif event == "UNIT_AURA" then
		self:ToggleAlpha(IsMounted() and lowAlpha or 1)
	end
end)

function frame:ToggleAlpha(nextAlpha)
	if nextAlpha == self.lastAlpha then
		return
	end

	local frames = {
		UtilityCooldownViewer,
		EssentialCooldownViewer,
		BuffBarCooldownViewer,
		BuffIconCooldownViewer,
		BCDM_SecondaryPowerBar, -- Better Cooldown Manager
	}

	for _, cooldownViewerFrame in ipairs(frames) do
		if cooldownViewerFrame then
			cooldownViewerFrame:SetAlpha(nextAlpha)
		end
	end

	self.lastAlpha = nextAlpha
end

table.insert(Private.LoginFnQueue, function()
	if InCombatLockdown() then
		return
	end

	C_Timer.After(1, function()
		frame:RegisterUnitEvent("UNIT_AURA", "player")

		if IsMounted() then
			frame:ToggleAlpha(lowAlpha)
		end
	end)
end)
