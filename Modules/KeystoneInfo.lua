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

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

frame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
	if IsInRaid() then
		return
	end

	if event == "CHALLENGE_MODE_COMPLETED" then
		C_Timer.NewTimer(3, RequestKeystoneInfo)
	elseif event == "CHAT_MSG_ADDON" and prefix == "LibKS" and channel == "PARTY" then
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
		end
	end
end)
