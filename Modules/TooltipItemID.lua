TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
	if not data or not data.id or not tooltip.GetItem or issecretvalue(data.type) then
		return
	end

	local _, link = tooltip:GetItem()

	if not link then
		return
	end

	local itemID = link:match("item:(%d+)")

	if itemID then
		tooltip:AddDoubleLine("Item ID", itemID, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
		tooltip:Show()
	end
end)
