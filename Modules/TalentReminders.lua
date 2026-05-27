local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.TalentReminders then
		return
	end

	local frame = CreateFrame("Frame")
	frame.lastMapId = nil
	frame.pattern = "Consider talenting the following spells: %s"
	frame.untalentPattern = "Consider untalenting the following spells: %s"
	---@type table<number, number[]>
	frame.zoneIdToSpellIdsMap = {}
	---@type FunctionContainer?
	frame.timer = nil

	frame:RegisterEvent("ZONE_CHANGED")
	frame:RegisterEvent("LOADING_SCREEN_DISABLED")
	frame:RegisterEvent("READY_CHECK")
	frame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")

	function frame:BuildReminders()
		local zoneIdToSpellIdsMap = {}

		local classId = select(3, UnitClass("player"))
		local specId = PlayerUtil.GetCurrentSpecID()

		local dungeons = {
			algetharAcademy = 2097,
			magistersTerrace = 2515,
			maisaraCaverns = 2501,
			nexusPointXenas = 2566,
			pitOfSaron = 184,
			seatOfTheTriumvirate = 903,
			skyreach = 601,
			windrunnersSpire = 2492,
		}

		if classId == Constants.UICharacterClasses.Evoker then
			local CauterizingFlame = 374251
			local BestowWeyrnstone = 408233
			local Zephyr = 374227
			local SleepWalk = 360806
			local Overawe = 374346
			local TerrofOfTheSkies = 371032

			zoneIdToSpellIdsMap[dungeons.algetharAcademy] = {
				CauterizingFlame,
				Zephyr,
				SleepWalk,
				TerrofOfTheSkies,
			}

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
				Overawe,
			}

			zoneIdToSpellIdsMap[dungeons.windrunnersSpire] = {
				CauterizingFlame,
				Zephyr,
				Overawe,
			}

			zoneIdToSpellIdsMap[dungeons.magistersTerrace] = {
				Zephyr,
				SleepWalk,
				CauterizingFlame,
			}

			if specId == 1473 then
				table.insert(zoneIdToSpellIdsMap[dungeons.pitOfSaron], BestowWeyrnstone)
				table.insert(zoneIdToSpellIdsMap[dungeons.skyreach], BestowWeyrnstone)
				table.insert(zoneIdToSpellIdsMap[dungeons.magistersTerrace], BestowWeyrnstone)
			end
		end

		return zoneIdToSpellIdsMap
	end

	---@param text string
	function frame:ExecuteTTTS(text)
		for _, v in pairs(C_VoiceChat.GetTtsVoices()) do
			if string.find(v.name, "English") then
				C_VoiceChat.SpeakText(v.voiceID, text, 3, C_TTSSettings.GetSpeechVolume())
				return
			end
		end
	end

	frame:SetScript("OnEvent", function(self, event)
		if event == "ZONE_CHANGED" or event == "LOADING_SCREEN_DISABLED" or event == "READY_CHECK" or event == "PLAYER_DIFFICULTY_CHANGED" then
			if self.timer ~= nil and not self.timer:IsCancelled() then
				self.timer:Cancel()
				self.timer = nil
			end

			self.timer = C_Timer.NewTimer(1, function()
				if C_ChallengeMode.IsChallengeModeActive() or InCombatLockdown() then
					return
				end

				if select(2, GetInstanceInfo()) == "none" then
					self.lastMapId = nil
					return
				end

				local reminders = self:BuildReminders()
				local mapId = C_Map.GetBestMapForUnit("player")


				if mapId == nil or self.lastMapId == mapId then
					return
				end

				self.lastMapId = mapId

				local currentZoneSpells = reminders[mapId] or {}

				-- talent reminders
				local spellNames = {}
				local spellLinks = {}

				for _, spellId in ipairs(currentZoneSpells) do
					if not C_SpellBook.IsSpellKnown(spellId) then
						table.insert(
							spellLinks,
							string.format("|T%d:16|t %s", C_Spell.GetSpellTexture(spellId), C_Spell.GetSpellLink(spellId))
						)
						table.insert(spellNames, C_Spell.GetSpellName(spellId))
					end
				end

				if #spellNames > 0 then
					print(self.pattern:format(table.concat(spellLinks, ", ")))

					self:ExecuteTTTS(self.pattern:format(table.concat(spellNames, ", ")))
				end

				-- untalent reminders
				if #currentZoneSpells == 0 then
					return
				end

				local currentZoneSet = {}
				for _, spellId in ipairs(currentZoneSpells) do
					currentZoneSet[spellId] = true
				end

				local allTrackedSpells = {}
				for _, spells in pairs(reminders) do
					for _, spellId in ipairs(spells) do
						allTrackedSpells[spellId] = true
					end
				end

				local untalentNames = {}
				local untalentLinks = {}

				for spellId in pairs(allTrackedSpells) do
					if not currentZoneSet[spellId] and C_SpellBook.IsSpellKnown(spellId) then
						table.insert(
							untalentLinks,
							string.format("|T%d:16|t %s", C_Spell.GetSpellTexture(spellId), C_Spell.GetSpellLink(spellId))
						)
						table.insert(untalentNames, C_Spell.GetSpellName(spellId))
					end
				end

				if #untalentNames == 0 then
					return
				end

				print(self.untalentPattern:format(table.concat(untalentLinks, ", ")))

				C_Timer.After(2, function()
					self:ExecuteTTTS(self.untalentPattern:format(table.concat(untalentNames, ", ")))
				end)
			end)
		end
	end)
end)
