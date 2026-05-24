local KEYSTONE_ITEM_IDS = {
	[180653] = true,
	[151086] = true,
}

local frame = CreateFrame("Frame")

frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")

frame:SetScript("OnEvent", function()
	for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)

			if itemID and KEYSTONE_ITEM_IDS[itemID] then
				C_Container.UseContainerItem(bag, slot)
				CloseAllBags()
				return
			end
		end
	end
end)
