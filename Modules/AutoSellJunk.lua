local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoSellJunk then
		return
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("MERCHANT_SHOW")

	frame:SetScript("OnEvent", function()
		-- Holding shift overrides the automation
		if IsShiftKeyDown() then
			return
		end

		if not C_MerchantFrame.IsSellAllJunkEnabled() then
			return
		end

		local junkItemsBefore = C_MerchantFrame.GetNumJunkItems()

		if junkItemsBefore <= 0 then
			return
		end

		local moneyBefore = GetMoney()

		C_MerchantFrame.SellAllJunkItems()

		C_Timer.After(1, function()
			if C_MerchantFrame.GetNumJunkItems() >= junkItemsBefore then
				print("selling junk failed, C_MerchantFrame.SellAllJunkItems() had no effect")
				return
			end

			local earned = GetMoney() - moneyBefore

			if earned > 0 then
				print(string.format("sold junk for %s", C_CurrencyInfo.GetCoinText(earned)))
			end
		end)
	end)
end)
