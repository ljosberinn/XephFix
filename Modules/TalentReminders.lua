local _ = ...

local frame = CreateFrame("Frame")
frame.lastMapId = nil
frame.pattern = "Consider talenting the following spells: %s"
---@type table<number, number[]>
frame.zoneIdToSpellIdsMap = {}

function frame:BuildReminders()
	self.zoneIdToSpellIdsMap = {}

	local classId = select(3, UnitClass("player"))
	local specId = PlayerUtil.GetCurrentSpecID()

	local dungeons = {
		araKara = 2357,
		algetharAcademy = 2097,
		magistersTerrace = 2511,
		maisaraCaverns = 2501,
		nexusPointXenas = 2566,
		pitOfSaron = 184,
		seatOfTheTriumvirate = 903,
		skyreach = 601,
		windrunnersSpire = 2492,
	}

	if classId == Constants.UICharacterClasses.Evoker then
		local Expunge = 365585
		local CauterizingFlame = 374251
		local BestowWeyrnstone = 408233
		local Zephyr = 374227

		self.zoneIdToSpellIdsMap[dungeons.araKara] = {
			Expunge,
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.algetharAcademy] = {
			CauterizingFlame,
			Expunge,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.maisaraCaverns] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.nexusPointXenas] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.pitOfSaron] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.seatOfTheTriumvirate] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.skyreach] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.windrunnersSpire] = {
			CauterizingFlame,
			Zephyr,
		}

		self.zoneIdToSpellIdsMap[dungeons.magistersTerrace] = {
			Zephyr,
		}

		if specId == 1473 then
			-- table.insert(self.zoneIdToSpellIdsMap[dungeons.algetharAcademy], BestowWeyrnstone)
			table.insert(self.zoneIdToSpellIdsMap[dungeons.pitOfSaron], BestowWeyrnstone)
			table.insert(self.zoneIdToSpellIdsMap[dungeons.skyreach], BestowWeyrnstone)
			table.insert(self.zoneIdToSpellIdsMap[dungeons.magistersTerrace], BestowWeyrnstone)
		end
	end
end

frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("READY_CHECK")

frame:SetScript("OnEvent", function(self, event)
	if event == "ZONE_CHANGED" or event == "LOADING_SCREEN_DISABLED" or event == "READY_CHECK" then
		if C_ChallengeMode.IsChallengeModeActive() or InCombatLockdown() then
			return
		end

		self:BuildReminders()

		local mapId = C_Map.GetBestMapForUnit("player")

		if mapId == nil or self.lastMapId == mapId or self.zoneIdToSpellIdsMap[mapId] == nil then
			return
		end

		self.lastMapId = mapId

		local spells = self.zoneIdToSpellIdsMap[mapId]
		local spellNames = {}
		local spellLinks = {}

		for _, spellId in ipairs(spells) do
			if not C_SpellBook.IsSpellKnown(spellId) then
				table.insert(
					spellLinks,
					string.format("|T%d:16|t %s", C_Spell.GetSpellTexture(spellId), C_Spell.GetSpellLink(spellId))
				)
				table.insert(spellNames, C_Spell.GetSpellName(spellId))
			end
		end

		if #spellNames == 0 then
			return
		end

		print(self.pattern:format(table.concat(spellLinks, ", ")))

		for _, v in pairs(C_VoiceChat.GetTtsVoices()) do
			if string.find(v.name, "English") then
				C_VoiceChat.SpeakText(
					v.voiceID,
					self.pattern:format(table.concat(spellNames, ", ")),
					3,
					C_TTSSettings.GetSpeechVolume()
				)
				return
			end
		end
	end
end)
