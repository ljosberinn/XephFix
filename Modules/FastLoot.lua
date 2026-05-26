local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.FastLoot then
		return
	end

	if C_AddOns.DoesAddOnExist("Plumber") or C_AddOns.DoesAddOnExist("Leatrix_Plus") then
		return
	end

	local frame = CreateFrame("Frame")
	frame.lastLoot = 0

	frame:RegisterEvent("LOOT_READY")
	frame:RegisterEvent("LOOT_BIND_CONFIRM")
	frame:SetScript("OnEvent", function(self, event, ...)
		if event == "LOOT_READY" then
			if GetTime() - self.lastLoot < 0.1 then
				return
			end

			self.lastLoot = GetTime()

			if C_CVar.GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
				for i = GetNumLootItems(), 1, -1 do
					LootSlot(i)
				end
			end
		elseif event == "LOOT_BIND_CONFIRM" then
			local slot = ...
			ConfirmLootSlot(slot)
		end
	end)
end)
