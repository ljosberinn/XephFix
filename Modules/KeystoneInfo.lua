local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.KeystoneInfo then
		return
	end

	if C_AddOns.IsAddOnLoaded("BigWigs") or not LibStub then
		return
	end

	local LKS = LibStub("LibKeystone")
	local reportedPlayers = {}
	local listeningForKeys = false

	LKS:Register(addonName, function(keyLevel, keyChallengeMapID, playerRating, playerName)
		if not listeningForKeys then
			return
		end

		if reportedPlayers[playerName] then
			return
		end

		reportedPlayers[playerName] = true

		local dungeonName = C_ChallengeMode.GetMapUIInfo(keyChallengeMapID) or "Unknown"
		print(string.format("%s: +%d %s (%.0f io)", playerName, keyLevel, dungeonName, playerRating))
	end)

	SLASH_XEPHKEYS1 = "/keys"
	SlashCmdList["XEPHKEYS"] = function()
		if listeningForKeys or IsInRaid() or not IsInGroup() then
			return
		end

		reportedPlayers = {}
		listeningForKeys = true

		LKS:Request("PARTY")

		C_Timer.NewTimer(10, function()
			listeningForKeys = false
			reportedPlayers = {}
		end)
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
	frame:SetScript("OnEvent", function(self, event)
		if event == "CHALLENGE_MODE_COMPLETED" then
			C_Timer.NewTimer(3, function()
				LKS:Request("PARTY")
			end)
		end
	end)
end)
