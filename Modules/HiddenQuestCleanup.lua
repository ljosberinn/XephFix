local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	local numShownEntries, numQuests = C_QuestLog:GetNumQuestLogEntries()

	if numShownEntries <= numQuests then
		return
	end

	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local quest = C_QuestLog.GetInfo(i)

		if quest and quest.isHidden then
			C_QuestLog.RemoveQuestWatch(i)
		end
	end
end)
