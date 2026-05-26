TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
	if not data or not data.id or issecretvalue(data.type) then
		return
	end

	local lineAdded = false

	if tooltip.GetItem then
		local _, link = tooltip:GetItem()

		if link then
			local itemID = link:match("item:(%d+)")

			if itemID then
				tooltip:AddDoubleLine("Item ID", itemID, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
				lineAdded = true
			end
		end
	end

	if tooltip.GetSpell then
		local _, spellID = tooltip:GetSpell()

		if spellID then
			tooltip:AddDoubleLine("Spell ID", spellID, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
			lineAdded = true
		end
	end

	if lineAdded then
		tooltip:Show()
	end
end)
