if C_AddOns.IsAddOnLoaded("BigWigs") then
	return
end

local frame = CreateFrame("Frame")

C_ChatInfo.RegisterAddonMessagePrefix("LibKS")

local function RequestKeystoneInfo()
	if not IsInGroup() or IsInRaid() then
		return
	end

	C_ChatInfo.SendAddonMessage("LibKS", "R", "PARTY")
end

if SlashCmdList.KEY == nil then
	SLASH_KEY1 = "/key"
	SlashCmdList["KEY"] = RequestKeystoneInfo
end

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

frame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
	if event == "CHALLENGE_MODE_COMPLETED" then
		C_Timer.NewTimer(3, RequestKeystoneInfo)
		return
	end

	if event == "CHAT_MSG_ADDON" and prefix == "LibKS" and channel == "PARTY" then
		if msg == "R" then
			local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel() or 0
			local keyChallengeMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0

			local playerRating = 0
			local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")

			if type(ratingSummary) == "table" and type(ratingSummary.currentSeasonScore) == "number" then
				playerRating = ratingSummary.currentSeasonScore
			end

			C_ChatInfo.SendAddonMessage(
				"LibKS",
				string.format("%d,%d,%d", keyLevel, keyChallengeMapID, playerRating),
				"PARTY"
			)
		else
			local keyLevelStr, keyChallengeMapIDStr = msg:match("^(%d+),(%d+),%d+$")

			if keyLevelStr and keyChallengeMapIDStr then
				local keyLevel = tonumber(keyLevelStr)
				local keyChallengeMapID = tonumber(keyChallengeMapIDStr)
				if keyLevel == 0 or keyChallengeMapID == 0 then
					return
				end

				local senderName = Ambiguate(sender, "none")

				if senderName == UnitName("player") then
					return
				end

				local mapName = C_ChallengeMode.GetMapUIInfo(keyChallengeMapID)
				local colorMarkup = "|cFFFFFFFF"

				for i = 1, GetNumGroupMembers() do
					local unit = "party" .. i

					if UnitName(unit) == senderName then
						local _, classFile = UnitClass(unit)

						if classFile then
							local color = C_ClassColor.GetClassColor(classFile)

							if color then
								colorMarkup = color:GenerateHexColorMarkup()
							end
						end
					end

					break
				end

				print(string.format("%s%s|r: %s +%d", colorMarkup, senderName, mapName or "?", keyLevel))
			end
		end
	end
end)
