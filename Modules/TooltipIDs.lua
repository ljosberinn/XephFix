local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.TooltipIDs then
		return
	end

	TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
		if not data or not data.id or issecretvalue(data.type) then
			return
		end

		local lineAdded = false

		if tooltip.GetItem then
			local _, link = tooltip:GetItem()

			if link then
				local itemString = link:match("item:([%-%d:]+)")

				if itemString then
					-- item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:linkLevel:specID:modifiersMask:itemContext:numBonusIDs[:bonusIDs...]
					local fields = { strsplit(":", itemString) }

					tooltip:AddDoubleLine("Item ID", fields[1], 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
					lineAdded = true

					local numBonusIDs = tonumber(fields[13])

					if numBonusIDs and numBonusIDs > 0 then
						local bonusIDs = table.concat(fields, ", ", 14, 13 + numBonusIDs)
						tooltip:AddDoubleLine("Bonus IDs", bonusIDs, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
					end
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
end)
