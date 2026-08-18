local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoRepair then
		return
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("MERCHANT_SHOW")

	frame:SetScript("OnEvent", function()
		-- Holding shift overrides the automation
		if IsShiftKeyDown() then
			return
		end

		if not CanMerchantRepair() then
			return
		end

		local repairCost, canRepair = GetRepairAllCost()

		if not canRepair then
			return
		end

		if IsInGuild() and CanGuildBankRepair() then
			-- Try guild funds first, then fall back to character funds if the daily
			-- guild gold limit has already been reached
			RepairAllItems(true)
			RepairAllItems()
		else
			RepairAllItems()
		end

		print(string.format("repaired for %s", C_CurrencyInfo.GetCoinText(repairCost)))
	end)
end)
