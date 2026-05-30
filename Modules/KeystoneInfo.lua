local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.KeystoneInfo then
		return
	end

	if C_AddOns.IsAddOnLoaded("BigWigs") or not LibStub then
		return
	end

	local LKS = LibStub("LibKeystone", true)

	if not LKS then
		return
	end

	local reportedPlayers = {}
	local listeningForKeys = false

	local localPlayerName = UnitNameUnmodified("player")

	LKS.Register(Private, function(keyLevel, keyChallengeMapID, playerRating, playerName)
		if not listeningForKeys then
			return
		end

		if playerName == localPlayerName then
			return
		end

		if reportedPlayers[playerName] then
			return
		end

		reportedPlayers[playerName] = true

		local dungeonName = C_ChallengeMode.GetMapUIInfo(keyChallengeMapID) or "Unknown"
		print(string.format("%s: +%d %s (%.0f score)", playerName, keyLevel, dungeonName, playerRating))
	end)

	SLASH_XEPHKEYS1 = "/keys"
	SlashCmdList["XEPHKEYS"] = function()
		if IsInRaid() then
			print("Unavailable in raid.")
			return
		end

		if not IsInGroup() then
			print("Unavailable outside of a group.")
			return
		end

		if listeningForKeys then
			return
		end

		reportedPlayers = {}
		listeningForKeys = true

		LKS.Request("PARTY")

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
				LKS.Request("PARTY")
			end)
		end
	end)
end)
