local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.KeystoneAnnouncer then
		return
	end

	local frame = CreateFrame("Frame")
	frame.mapId = nil
	frame.level = nil

	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("BAG_UPDATE_DELAYED")
	frame:RegisterEvent("GOSSIP_CONFIRM")
	frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

	function frame:ScanForKeystone()
		local level = C_MythicPlus.GetOwnedKeystoneLevel() or 0
		local mapId = C_MythicPlus.GetOwnedKeystoneChallengeMapID() or 0

		return mapId, level
	end

	function frame:AnnounceKeystone(mapId, level)
		if not IsInGroup() or IsInRaid() or mapId == 0 or level == 0 or C_ChallengeMode.IsChallengeModeActive() then
			return
		end

		C_ChatInfo.SendChatMessage(string.format("My key: %s +%d", C_ChallengeMode.GetMapUIInfo(mapId), level), "PARTY")
	end

	frame:SetScript("OnEvent", function(self, event, id)
		if event == "PLAYER_LOGIN" then
			local mapId, level = self:ScanForKeystone()

			self.mapId = mapId
			self.level = level
		elseif event == "BAG_UPDATE_DELAYED" then
			local mapId, level = self:ScanForKeystone()

			if mapId ~= self.mapId or level ~= self.level then
				self.mapId = mapId
				self.level = level

				self:AnnounceKeystone(mapId, level)
			end
		elseif event == "GOSSIP_CONFIRM" then
			if id == 107538 then
				self:RegisterEvent("GOSSIP_CONFIRM_CANCEL")
			end
		elseif event == "GOSSIP_CONFIRM_CANCEL" or event == "CHALLENGE_MODE_COMPLETED" then
			self:UnregisterEvent("GOSSIP_CONFIRM_CANCEL")

			C_Timer.NewTimer(1, function()
				local mapId, level = self:ScanForKeystone()

				if mapId ~= self.mapId or level ~= self.level then
					self.mapId = mapId
					self.level = level

					self:AnnounceKeystone(mapId, level)
				end
			end)
		end
	end)
end)
