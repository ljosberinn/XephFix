local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not Private.IsXeph then
		return
	end

	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", function()
		if InCombatLockdown() then
			return
		end

		local inInstance = IsInInstance()

		C_CVar.SetCVar("UnitNamePlayerPVPTitle", inInstance and 0 or 1)
		C_CVar.SetCVar("UnitNamePlayerGuild", inInstance and 0 or 1)
		C_CVar.SetCVar("WorldTextMinSize", inInstance and 12 or 0)
		C_CVar.SetCVar("WorldTextMinAlpha", inInstance and 1 or 0.5)
	end)
end)
