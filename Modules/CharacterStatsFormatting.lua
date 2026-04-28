local addonName, Private = ...

hooksecurefunc("PaperDollFrame_SetItemLevel", function()
	CharacterStatsPane.ItemLevelFrame.Value:SetText(select(2, GetAverageItemLevel()))
end)

hooksecurefunc("PaperDollFrame_SetLabelAndText", function(statFrame, label, text, isPercentage, numericValue)
	if
		label == STAT_CRITICAL_STRIKE
		or label == STAT_HASTE
		or label == STAT_MASTERY
		or label == STAT_SPEED
		or label == STAT_LIFESTEAL
		or label == STAT_AVOIDANCE
		or label == STAT_VERSATILITY
	then
		local rawStatAmount = 0

		if label == STAT_HASTE then
			numericValue = GetHaste()
			rawStatAmount = GetCombatRating(CR_HASTE_RANGED)
		elseif label == STAT_CRITICAL_STRIKE then
			rawStatAmount = GetCombatRating(CR_CRIT_RANGED)
		elseif label == STAT_MASTERY then
			rawStatAmount = GetCombatRating(CR_MASTERY)
		elseif label == STAT_SPEED then
			rawStatAmount = GetCombatRating(CR_SPEED)
		elseif label == STAT_LIFESTEAL then
			rawStatAmount = GetCombatRating(CR_LIFESTEAL)
		elseif label == STAT_AVOIDANCE then
			rawStatAmount = GetCombatRating(CR_AVOIDANCE)
		elseif label == STAT_VERSATILITY then
			rawStatAmount = GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
		end

		statFrame.Value:SetText(string.format("%s | %.2f %%", BreakUpLargeNumbers(rawStatAmount), numericValue))
	end
end)
