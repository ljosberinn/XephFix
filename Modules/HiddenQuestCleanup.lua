local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	local numShownEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()

	if numShownEntries <= numQuests then
		return
	end

	local total = 0

	for i = 1, C_QuestLog.GetNumQuestLogEntries() do
		local quest = C_QuestLog.GetInfo(i)

		if quest and quest.isHidden and not quest.isHeader then
			local wasRemoved = C_QuestLog.RemoveQuestWatch(quest.questID)

			if wasRemoved then
				print(string.format("unwatched quest %s (%d)", quest.title, quest.questID))
				total = total + 1
			else
				print(string.format("could not unwatch quest %s (%d)", quest.title, quest.questID))
			end
		end
	end

	if total > 0 then
		print(string.format("unwatched %d quests", total))
	end
end)
