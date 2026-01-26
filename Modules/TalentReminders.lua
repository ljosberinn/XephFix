local addonName, Private = ...

---@type table<number, number[]>
local zoneIdToSpellIdsMap = {}

local shouldLoad = false

do
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

	-- see classID here: https://wago.tools/db2/ChrSpecialization
	if classId == 13 then -- evoker
		local Expunge = 365585
		local CauterizingFlame = 374251
		local BestowWeyrnstone = 408233
		local Zephyr = 374227

		zoneIdToSpellIdsMap[dungeons.araKara] = {
			Expunge,
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.algetharAcademy] = {
			CauterizingFlame,
			Expunge,
			Zephyr,
		}

		if specId == 1473 then
			table.insert(zoneIdToSpellIdsMap[dungeons.algetharAcademy], BestowWeyrnstone)
		end

		zoneIdToSpellIdsMap[dungeons.maisaraCaverns] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.nexusPointXenas] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.pitOfSaron] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.seatOfTheTriumvirate] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.skyreach] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.windrunnersSpire] = {
			CauterizingFlame,
			Zephyr,
		}

		zoneIdToSpellIdsMap[dungeons.magistersTerrace] = {
			Zephyr,
		}

		shouldLoad = true
	end
end

if not shouldLoad then
	return
end

local frame = CreateFrame("Frame")
frame.lastMapId = nil
frame.pattern = "Consider talenting the following spells: %s"

frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("READY_CHECK")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ZONE_CHANGED" or event == "LOADING_SCREEN_DISABLED" or event == "READY_CHECK" then
		if C_ChallengeMode.IsChallengeModeActive() or InCombatLockdown() then
			return
		end

		local mapId = C_Map.GetBestMapForUnit("player")

		if mapId == nil or frame.lastMapId == mapId or zoneIdToSpellIdsMap[mapId] == nil then
			return
		end

		frame.lastMapId = mapId

		local spells = zoneIdToSpellIdsMap[mapId]
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

		print(frame.pattern:format(table.concat(spellLinks, ", ")))

		for _, v in pairs(C_VoiceChat.GetTtsVoices()) do
			if string.find(v.name, "English") then
				C_VoiceChat.SpeakText(
					v.voiceID,
					frame.pattern:format(table.concat(spellNames, ", ")),
					3,
					C_TTSSettings.GetSpeechVolume()
				)
				return
			end
		end
	end
end)
