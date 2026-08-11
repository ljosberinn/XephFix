local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.MDTSim then
		return
	end

	EventUtil.ContinueOnAddOnLoaded("MythicDungeonTools_UI", function()
		local API = MythicDungeonToolsAPI

		if not API then
			return
		end

		-- MDT 6.2 moved its interface into the load-on-demand MythicDungeonTools_UI addon and stopped
		-- publishing a global MDT table; MythicDungeonToolsAPI is the only global left. The interface
		-- table does keep `__index = MythicDungeonToolsAPI` as its fallback, so methods it does not
		-- define itself resolve through the public API table with the interface table as `self`.
		-- Hooking such a method is the only way left to get hold of it. See CaptureInterfaceTable below.
		local MDT

		local ignoredNpcIds = {
			[170147] = true, -- Volatile Memory
			[44566] = true, -- Ozumat
			[204449] = true, -- Chromie
			[205212] = true, -- Infinite Keeper
			[205265] = true, -- Time-Displaced Trooper
			[101008] = true, -- Stinging Swarm
			[84399] = true, -- Vicious Mandragora
			[84400] = true, -- Gnarled Ancient
			[213219] = true, -- Bubbling Ooze
			[44404] = true, -- Naz'jar Frost Witch
			[213607] = true, -- Deep Sea Murloc
			[40633] = true, -- Naz'jar Honor Guard
			[213942] = true, -- Sludge
			[213806] = true, -- Splotch
			[40825] = true, -- Erunak Stonespeaker
			[214117] = true, -- Stormflurry Totem
			[98362] = true, -- Troubled Soul
			[204918] = true, -- Iridikron's Creation
			[213008] = true, -- Wriggling Darkspawn
			[129246] = true, -- Azerite Footbomb
			[141303] = true, -- B.O.O.M.B.A
			[132056] = true, -- Venture Co. Skyscorcher
			[166524] = true, -- Deathwalker
			[234443] = true, -- Lost Soul
			[211140] = true, -- Arathi Neophyte
		}

		local raceNames = {
			[1] = "human",
			[2] = "orc",
			[3] = "dwarf",
			[4] = "night_elf",
			[5] = "undead",
			[6] = "tauren",
			[7] = "gnome",
			[8] = "troll",
			[9] = "goblin",
			[10] = "blood_elf",
			[11] = "draenei",
			[22] = "worgen",
			[24] = "pandaren",
			[25] = "pandaren_alliance",
			[26] = "pandaren_horde",
			[27] = "nightborne",
			[28] = "highmountain_tauren",
			[29] = "void_elf",
			[30] = "lightforged_draenei",
			[31] = "zandalari_troll",
			[32] = "kul_tiran",
			[34] = "dark_iron_dwarf",
			[35] = "vulpera",
			[36] = "maghar_orc",
			[37] = "mechagnome",
			[52] = "dracthyr_alliance",
			[70] = "dracthyr_horde",
		}

		local classNames = {
			[1] = "warrior",
			[2] = "paladin",
			[3] = "hunter",
			[4] = "rogue",
			[5] = "priest",
			[6] = "deathknight",
			[7] = "shaman",
			[8] = "mage",
			[9] = "warlock",
			[10] = "monk",
			[11] = "druid",
			[12] = "demonhunter",
			[13] = "evoker",
		}

		local specializationNames = {
			[250] = "blood",
			[251] = "frost",
			[252] = "unholy",
			[577] = "havoc",
			[581] = "vengeance",
			[102] = "balance",
			[103] = "feral",
			[104] = "guardian",
			[105] = "restoration",
			[1467] = "devastation",
			[1468] = "preservation",
			[1473] = "augmentation",
			[253] = "beast_mastery",
			[254] = "marksmanship",
			[255] = "survival",
			[62] = "arcane",
			[63] = "fire",
			[64] = "frost",
			[268] = "brewmaster",
			[270] = "mistweaver",
			[269] = "windwalker",
			[65] = "holy",
			[66] = "protection",
			[70] = "retribution",
			[256] = "discipline",
			[257] = "holy",
			[258] = "shadow",
			[259] = "assassination",
			[260] = "outlaw",
			[261] = "subtlety",
			[262] = "elemental",
			[263] = "enhancement",
			[264] = "restoration",
			[265] = "affliction",
			[266] = "demonology",
			[267] = "destruction",
			[71] = "arms",
			[72] = "fury",
			[73] = "protection",
		}

		local roleHealthContribution = {
			["DAMAGER"] = 27,
			["TANK"] = 14,
			["HEALER"] = 5,
		}

		local inventorySlotNames = {
			[Enum.InventoryType.IndexHeadType] = "head",
			[Enum.InventoryType.IndexNeckType] = "neck",
			[Enum.InventoryType.IndexShoulderType] = "shoulders",
			[Enum.InventoryType.IndexChestType] = "chest",
			[Enum.InventoryType.IndexWaistType] = "waist",
			[Enum.InventoryType.IndexLegsType] = "legs",
			[Enum.InventoryType.IndexFeetType] = "feet",
			[Enum.InventoryType.IndexWristType] = "wrist",
			[Enum.InventoryType.IndexHandType] = "hands",
			[Enum.InventoryType.IndexFingerType] = "finger1",
			[Enum.InventoryType.IndexFingerType + 1] = "finger2",
			[Enum.InventoryType.IndexTrinketType + 1] = "trinket1",
			[Enum.InventoryType.IndexTrinketType + 2] = "trinket2",
			[Enum.InventoryType.IndexCloakType - 1] = "back",
			[16] = "main_hand",
			[17] = "off_hand",
		}

		local partyUnits = {
			"party1",
			"party2",
			"party3",
			"party4",
		}

		---@class MDTSimExportWindow : ScrollFrame
		---@field background Texture
		---@field editBox EditBox

		---@class MDTSimMobHealthInput : EditBox
		---@field label FontString

		---@class MDTSimFrames
		---@field eventFrame Frame
		---@field exportWindow MDTSimExportWindow
		---@field routeExportButton Button
		---@field groupExportButton Button
		---@field mobHealthInput MDTSimMobHealthInput

		---@class MDTSimInspectInfo
		---@field talents string
		---@field specializationId integer
		---@field items string

		---@type table<string, fun(): Frame>
		local frameBuilders = {}

		---@type MDTSimFrames
		local frames = setmetatable({}, {
			---@param self table
			---@param frameName string
			---@return Frame?
			__index = function(self, frameName)
				local builder = frameBuilders[frameName]

				if not builder then
					return nil
				end

				local frame = builder()
				self[frameName] = frame

				return frame
			end,
		})

		---@type table<string, string> unit guid to unit token
		local pendingInspects = {}

		---@type table<string, MDTSimInspectInfo> unit token to collected profile data
		local inspectInfo = {}

		local inspectElapsed = 0
		local successMessage = ""

		---@param unit string
		---@return string
		local function GenerateItemsText(unit)
			local items = ""

			for slotIndex, slotName in pairs(inventorySlotNames) do
				local line = slotName .. "="
				local itemLink = GetInventoryItemLink(unit, slotIndex)

				if itemLink then
					local payload = { strsplit(":", itemLink) }

					line = line .. ",id=" .. payload[2]

					local bonusIdCount = tonumber(payload[14])

					if bonusIdCount then
						line = line .. ",bonus_id="
						for payloadIndex = 15, 14 + bonusIdCount do
							if payloadIndex > 15 then
								line = line .. "/"
							end
							line = line .. payload[payloadIndex]
						end
					end

					if tonumber(payload[3]) then
						line = line .. ",enchant_id=" .. payload[3]
					end

					local hasGem = false
					for payloadIndex = 4, 8 do
						if tonumber(payload[payloadIndex]) then
							if not hasGem then
								line = line .. ",gem_id="
								hasGem = true
							else
								line = line .. "/"
							end
							line = line .. payload[payloadIndex]
						end
					end
				end

				items = items .. line .. "\n"
			end

			return items .. "\n"
		end

		local function FinishCollection()
			frames.routeExportButton:Enable()
			frames.groupExportButton:Enable()

			frames.eventFrame:SetScript("OnUpdate", nil)
			pendingInspects = {}

			local profiles = ""
			local _, _, _, _, playerRole = GetSpecializationInfo(GetSpecialization())
			local roleHealthTotal = roleHealthContribution[playerRole]
			local text = ""
			local profileCount = 0

			local skyfury = "0"
			local arcaneIntellect = "0"
			local powerWordFortitude = "0"
			local battleShout = "0"
			local markOfTheWild = "0"

			local mysticTouch = "0"
			local chaosBrand = "0"
			local huntersMark = "0"

			local _, _, playerClassId = UnitClass("player")

			if playerClassId == 7 then
				skyfury = "1"
			end
			if playerClassId == 8 then
				arcaneIntellect = "1"
			end
			if playerClassId == 5 then
				powerWordFortitude = "1"
			end
			if playerClassId == 1 then
				battleShout = "1"
			end
			if playerClassId == 11 then
				markOfTheWild = "1"
			end

			if playerClassId == 10 then
				mysticTouch = "1"
			end
			if playerClassId == 12 then
				chaosBrand = "1"
			end
			if playerClassId == 3 then
				huntersMark = "1"
			end

			for unit, info in pairs(inspectInfo) do
				local name = UnitName(unit)
				if name then
					local profile = ""

					local _, _, classId = UnitClass(unit)
					local _, _, raceId = UnitRace(unit)
					local specializationName = specializationNames[info.specializationId]

					if not classId or not raceId or not specializationName then
						print("MDT Sim: Couldn't generate profile for " .. unit .. " with name " .. name .. ".")
					else
						profile = profile .. classNames[classId] .. '="' .. name .. '"\n'
						profile = profile .. "spec=" .. specializationName .. "\n"
						profile = profile .. "level=" .. UnitLevel(unit) .. "\n"
						profile = profile .. "race=" .. raceNames[raceId] .. "\n"
						profile = profile .. "talents=" .. info.talents .. "\n"

						profile = profile .. "\n" .. info.items .. "\n"

						profiles = profiles .. profile .. "\n"

						local _, _, _, _, role = GetSpecializationInfoByID(info.specializationId)
						roleHealthTotal = roleHealthTotal + roleHealthContribution[role]
						profileCount = profileCount + 1

						if classId == 7 then
							skyfury = "1"
						end
						if classId == 8 then
							arcaneIntellect = "1"
						end
						if classId == 5 then
							powerWordFortitude = "1"
						end
						if classId == 1 then
							battleShout = "1"
						end
						if classId == 11 then
							markOfTheWild = "1"
						end

						if classId == 10 then
							mysticTouch = "1"
						end
						if classId == 12 then
							chaosBrand = "1"
						end
						if classId == 3 then
							huntersMark = "1"
						end
					end
				end
			end

			text = text .. "\n" .. profiles

			local healthPercent
			if profileCount == 0 then
				healthPercent = tonumber(frames.mobHealthInput:GetText())

				if not healthPercent then
					print("MDT Sim - Error: Percent must be a number.")
					return
				else
					if healthPercent < 1 or healthPercent > 100 then
						print("MDT Sim - Error: Percent must be in the 1 to 100 range.")
						return
					end
				end
			else
				healthPercent = roleHealthTotal
				if healthPercent > 100 then
					print("MDT Sim - Warning: Mob health was over 100% because of too many dps profiles.")
					healthPercent = 100
				end
			end

			local preset = MDT:GetCurrentPreset()
			local pulls = MDT:GetPulls(preset)
			local difficulty = preset.difficulty
			local dungeonIndex = preset.value.currentDungeonIdx
			local dungeonEnemies = MDT.dungeonEnemies[dungeonIndex]
			local dungeon = MDT:GetDungeonName(dungeonIndex)

			local raidEvents = {}
			local fenrirCount = 0
			local pullIndex = 1

			for _, pull in pairs(pulls) do
				local pullDelay = math.random(5, 15)
				local pullDelayText = string.format("%03d", pullDelay)

				local raidEvent = "raid_events+=/pull,pull="
					.. string.format("%02d", pullIndex)
					.. ",bloodlust=0,delay="
					.. pullDelayText
					.. ",enemies="
				local enemyCount = 0
				local sharedHealth = false
				local manastormIndex = 1
				local managerieIndex = 1
				local blightIndex = 1
				local subPullCount = 1

				if pull then
					for enemyIndex, cloneIndices in pairs(pull) do
						if tonumber(enemyIndex) and dungeonEnemies[enemyIndex] then
							local enemy = dungeonEnemies[enemyIndex]

							if not ignoredNpcIds[enemy.id] then
								local cloneCounter = 1
								for _, cloneIndex in pairs(cloneIndices) do
									if enemy.clones[cloneIndex] and MDT:IsCloneIncluded(enemyIndex, cloneIndex) then
										local health = MDT:CalculateEnemyHealth(
											enemy.isBoss ~= nil,
											enemy.health,
											difficulty,
											enemy.ignoreFortified
										)
										health = health * (healthPercent / 100)

										-- Mueh'zala
										if enemy.id == 166608 then
											health = health * 0.1
										end

										-- General Kaal
										if enemy.id == 162099 then
											health = health * 0.2
										end

										-- Odyn
										if enemy.id == 95676 then
											health = health * 0.2
										end

										-- Fenrir
										if enemy.id == 95674 or enemy.id == 99868 then
											fenrirCount = fenrirCount + 1
										end

										-- Hymdall
										if enemy.id == 94960 then
											health = health * 0.9
										end

										-- Yalnu, for now cut hp to 1/4
										if enemy.id == 83846 then
											health = health / 4
										end

										-- Witherbark, estimate damage amp uptime
										if enemy.id == 81522 then
											health = health / 1.5
										end

										-- Lady Waycrest
										if enemy.id == 131545 then
											health = health * 0.1
										end

										-- Lord Waycrest
										if enemy.id == 131527 then
											health = health * 3.1
										end

										-- Deios
										if enemy.id == 199000 then
											health = health * 0.15
										end

										-- Iridikron
										if enemy.id == 198933 then
											health = health * 0.15
										end

										-- Priestess Alun'za
										if enemy.id == 122967 then
											health = health * 0.6
										end

										-- Big M.O.M.M.A.
										if enemy.id == 226398 then
											health = health * 0.7
										end

										-- The Darkness
										if enemy.id == 208747 then
											health = health * 0.45
										end

										-- Coin-Operated Crowd Pummeler
										if enemy.id == 129214 then
											health = health * 0.7
										end

										if (enemy.id == 95674 or enemy.id == 99868) and fenrirCount > 1 then
											-- ignore additional Fenrirs if he's in more than 1 pull
										elseif enemy.id == 164556 or enemy.id == 164555 then
											-- Manastorms, separate into 2 pulls so they're not simmed together as a 2 target fight
											subPullCount = 2
											local adjustedHealth = health * 0.9
											local sanitizedName = string.gsub(enemy.name, " ", "_")

											if manastormIndex == 1 then
												if enemyCount > 0 then
													raidEvent = raidEvent .. "|"
												end
												enemyCount = enemyCount + 1
												raidEvent = raidEvent
													.. '"BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
												manastormIndex = 2
											else
												local subPullIndex = pullIndex + (manastormIndex - 1)
												raidEvents[subPullIndex] = "raid_events+=/pull,pull="
													.. string.format("%02d", subPullIndex)
													.. ',bloodlust=0,delay=000,enemies="BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
											end
										elseif enemy.id == 176556 or enemy.id == 176705 or enemy.id == 176555 then
											-- Grand Managerie, separate into 3 pulls so they're not simmed together as a 3 target fight
											subPullCount = 3
											local sanitizedName = string.gsub(enemy.name, " ", "_")

											if managerieIndex == 1 then
												if enemyCount > 0 then
													raidEvent = raidEvent .. "|"
												end
												enemyCount = enemyCount + 1
												raidEvent = raidEvent
													.. '"BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(health)
													.. ":"
													.. enemy.creatureType
												managerieIndex = 2
											else
												local subPullIndex = pullIndex + (managerieIndex - 1)
												raidEvents[subPullIndex] = "raid_events+=/pull,pull="
													.. string.format("%02d", subPullIndex)
													.. ',bloodlust=0,delay=000,enemies="BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(health)
													.. ":"
													.. enemy.creatureType
												managerieIndex = 3
											end
										elseif
											enemy.id == 198997
											or enemy.id == 201788
											or enemy.id == 201790
											or enemy.id == 201792
										then
											-- Blight of Galakrond, separate into a 50% st phase then 25% each 2t phase (hp is shared),
											-- don't care about matching the order perfectly, the hp should just resemble reality (50% st into 2t with 25% each)
											subPullCount = 2
											local sanitizedName = string.gsub(enemy.name, " ", "_")

											if blightIndex == 1 then
												local adjustedHealth = health * 0.5
												if enemyCount > 0 then
													raidEvent = raidEvent .. "|"
												end
												enemyCount = enemyCount + 1
												raidEvent = raidEvent
													.. '"BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
												blightIndex = 2
											elseif blightIndex == 2 then
												-- set up bosses 2 and 3 as the shared hp 2t phase
												local adjustedHealth = health * 0.25
												local subPullIndex = pullIndex + 1
												raidEvents[subPullIndex] = "raid_events+=/pull,pull="
													.. string.format("%02d", subPullIndex)
													.. ',bloodlust=0,delay=000,enemies="BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
												blightIndex = 3
											elseif blightIndex == 3 then
												local adjustedHealth = health * 0.25
												local subPullIndex = pullIndex + 1
												raidEvents[subPullIndex] = raidEvents[subPullIndex]
													.. '|"BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
												blightIndex = 4
											end
											-- ignore whatever boss is 4th since it isn't needed
										elseif enemy.id == 98965 or enemy.id == 98970 then
											subPullCount = 2
											local sanitizedName = string.gsub(enemy.name, " ", "_")

											if enemy.id == 98965 then
												-- Kur'talos
												if enemyCount > 0 then
													raidEvent = raidEvent .. "|"
												end
												enemyCount = enemyCount + 1
												raidEvent = raidEvent
													.. '"BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(health)
													.. ":"
													.. enemy.creatureType
											end

											if enemy.id == 98970 then
												-- Dantalionax
												local adjustedHealth = health / 3
												local subPullIndex = pullIndex + 1
												raidEvents[subPullIndex] = "raid_events+=/pull,pull="
													.. string.format("%02d", subPullIndex)
													.. ',bloodlust=0,delay=000,enemies="BOSS_'
													.. sanitizedName
													.. '":'
													.. math.floor(adjustedHealth)
													.. ":"
													.. enemy.creatureType
											end
										elseif
											enemy.id == 207946
											or enemy.id == 239833
											or enemy.id == 239836
											or enemy.id == 239834
										then
											-- Captain Dailcry or a lieutenant

											if enemy.id == 207946 then
												sharedHealth = true

												-- this is the boss, find the other mob in the pull and adjust; take boss health and divide by 2 and assign that health to each
												-- mob in the pull, use redistribute event so they share health, and pray people are reasonable and properly have 2 in the pull
												local adjustedHealth = health * 0.5

												local foundLieutenant = false
												-- add the lieutenant
												for partnerIndex, partnerClones in pairs(pull) do
													if tonumber(partnerIndex) and dungeonEnemies[partnerIndex] then
														local lieutenant = dungeonEnemies[partnerIndex]
														for _, partnerCloneIndex in pairs(partnerClones) do
															if
																lieutenant.clones[partnerCloneIndex]
																and MDT:IsCloneIncluded(partnerIndex, partnerCloneIndex)
															then
																if
																	lieutenant.id == 239833
																	or lieutenant.id == 239836
																	or lieutenant.id == 239834
																then
																	foundLieutenant = true
																	raidEvent = raidEvent
																		.. '"BOSS_'
																		.. lieutenant.name
																		.. '":'
																		.. math.floor(adjustedHealth)
																		.. ":"
																		.. lieutenant.creatureType
																	enemyCount = enemyCount + 1
																end
															end
														end
													end
												end

												if foundLieutenant then
													raidEvent = raidEvent
														.. '"BOSS_'
														.. enemy.name
														.. '":'
														.. math.floor(adjustedHealth)
														.. ":"
														.. enemy.creatureType
												else
													sharedHealth = false
													raidEvent = raidEvent
														.. '"BOSS_'
														.. enemy.name
														.. '":'
														.. math.floor(health)
														.. ":"
														.. enemy.creatureType
												end
												enemyCount = enemyCount + 1
											else
												-- one of the lieutenants, could be part of the boss or alone
												local foundBoss = false
												for partnerIndex, partnerClones in pairs(pull) do
													if tonumber(partnerIndex) and dungeonEnemies[partnerIndex] then
														local boss = dungeonEnemies[partnerIndex]
														for _, partnerCloneIndex in pairs(partnerClones) do
															if
																boss.clones[partnerCloneIndex]
																and MDT:IsCloneIncluded(partnerIndex, partnerCloneIndex)
															then
																if boss.id == 207946 then
																	foundBoss = true
																	break
																end
															end
														end
													end
												end

												if foundBoss then
													-- ignore since the boss handling will add this lieutenant
												else
													-- handle normally
													if enemyCount > 0 then
														raidEvent = raidEvent .. "|"
													end
													enemyCount = enemyCount + 1
													raidEvent = raidEvent
														.. '"'
														.. enemy.name
														.. '":'
														.. math.floor(health)
														.. ":"
														.. enemy.creatureType
												end
											end
										else
											local unitSuffix = enemy.isBoss and "" or "_" .. cloneCounter
											local bossPrefix = enemy.isBoss and "BOSS_" or ""
											cloneCounter = cloneCounter + 1
											if enemyCount > 0 then
												raidEvent = raidEvent .. "|"
											end
											enemyCount = enemyCount + 1

											local sanitizedName = string.gsub(enemy.name, '"', "`")
											sanitizedName = string.gsub(sanitizedName, "%:", "")
											sanitizedName = string.gsub(sanitizedName, " ", "_")
											sanitizedName = string.gsub(sanitizedName, ",", "")
											sanitizedName = string.gsub(sanitizedName, "/", "")

											local sanitizedCreatureType = string.gsub(enemy.creatureType, " ", "_")

											raidEvent = raidEvent
												.. '"'
												.. bossPrefix
												.. sanitizedName
												.. unitSuffix
												.. '":'
												.. math.floor(health)
												.. ":"
												.. sanitizedCreatureType
										end
									end
								end
							end
						end
					end
				end

				if enemyCount > 0 then
					if sharedHealth then
						raidEvent = raidEvent .. ",shared_health=1"
					end

					raidEvents[pullIndex] = raidEvent
					pullIndex = pullIndex + subPullCount
				end
			end

			text = text .. "fight_style=DungeonRoute\n"
			-- party buffs
			text = text .. "override.skyfury=" .. skyfury .. "\n"
			text = text .. "override.arcane_intellect=" .. arcaneIntellect .. "\n"
			text = text .. "override.power_word_fortitude=" .. powerWordFortitude .. "\n"
			text = text .. "override.battle_shout=" .. battleShout .. "\n"
			text = text .. "override.mark_of_the_wild=" .. markOfTheWild .. "\n"
			-- target debuffs
			text = text .. "override.mystic_touch=" .. mysticTouch .. "\n"
			text = text .. "override.chaos_brand=" .. chaosBrand .. "\n"
			text = text .. "override.hunters_mark=" .. huntersMark .. "\n"

			text = text .. "override.mortal_wounds=0\n"
			text = text .. "override.bleeding=0\n"

			text = text .. "single_actor_batch=0\n"
			text = text .. "max_time=2700\n"
			text = text .. 'enemy="' .. dungeon .. " " .. difficulty .. '"\n'
			text = text .. "enemy_health=99999999\n"
			-- not used in sim currently
			--text = text.."keystone_level="..difficulty.."\n"
			--text = text.."keystone_pct_hp="..healthPercent.."\n"

			for _, raidEvent in pairs(raidEvents) do
				text = text .. "\n" .. raidEvent
			end

			frames.exportWindow.editBox:SetText(text)
			frames.exportWindow.editBox:HighlightText()
			frames.exportWindow:Show()

			print(successMessage)
		end

		local function RequestNextInspect()
			for _, unit in pairs(pendingInspects) do
				if unit and CanInspect(unit) and select(4, UnitPosition("player")) == select(4, UnitPosition(unit)) then
					NotifyInspect(unit)
					return
				end
			end

			pendingInspects = {}

			FinishCollection()
		end

		---@param guid string
		local function HandleInspectReady(guid)
			local unit = pendingInspects[guid]

			if not unit then
				return
			end

			inspectInfo[unit] = {
				talents = C_Traits.GenerateInspectImportString(unit),
				specializationId = GetInspectSpecialization(unit),
				items = GenerateItemsText(unit),
			}

			pendingInspects[guid] = nil
			ClearInspectPlayer()
			RequestNextInspect()
		end

		---@param elapsed number
		local function HandleInspectTimeout(elapsed)
			inspectElapsed = inspectElapsed + elapsed

			if inspectElapsed <= 3 then
				return
			end

			print("MDT Sim - Warning: Party inspection timed out, try again for missing profiles.")
			FinishCollection()
		end

		---@return Frame
		frameBuilders.eventFrame = function()
			local eventFrame = CreateFrame("Frame")
			eventFrame:RegisterEvent("INSPECT_READY")
			eventFrame:SetScript("OnEvent", function(_, _, guid)
				HandleInspectReady(guid)
			end)

			return eventFrame
		end

		-- copyable text window containing the export
		---@return MDTSimExportWindow
		frameBuilders.exportWindow = function()
			---@type MDTSimExportWindow
			local exportWindow = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
			exportWindow:SetFrameStrata("TOOLTIP")
			exportWindow:SetPoint("CENTER")
			exportWindow:SetSize(1200, 600)
			exportWindow:EnableMouse(true)
			exportWindow:Hide()

			exportWindow.background = exportWindow:CreateTexture(nil, "BACKGROUND")
			exportWindow.background:SetAllPoints()
			exportWindow.background:SetColorTexture(0, 0, 0, 1)

			exportWindow.editBox = CreateFrame("EditBox", nil, exportWindow)
			exportWindow.editBox:SetSize(1200, 600)
			exportWindow.editBox:SetMultiLine(true)
			exportWindow.editBox:SetMaxLetters(99999)
			exportWindow.editBox:EnableMouse(true)
			exportWindow.editBox:SetFontObject(ChatFontNormal)
			exportWindow.editBox:SetScript("OnEscapePressed", function()
				exportWindow:Hide()
			end)
			exportWindow:SetScrollChild(exportWindow.editBox)

			return exportWindow
		end

		---@param onlyRoute boolean
		local function StartExport(onlyRoute)
			if onlyRoute then
				successMessage = "MDT Sim: Route exported, copy text and then use ESC to close the window."
			else
				successMessage = "MDT Sim: Group and route exported, copy text and then use ESC to close the window."
			end

			pendingInspects = {}
			inspectInfo = {}
			inspectElapsed = 0

			if onlyRoute then
				FinishCollection()
				return
			end

			frames.routeExportButton:Disable()
			frames.groupExportButton:Disable()

			frames.eventFrame:SetScript("OnUpdate", function(_, elapsed)
				HandleInspectTimeout(elapsed)
			end)

			for _, unit in ipairs(partyUnits) do
				if UnitName(unit) then
					pendingInspects[UnitGUID(unit)] = unit
				end
			end

			RequestNextInspect()
		end

		-- buttons attached to the MDT window to trigger an export
		---@return Button
		frameBuilders.routeExportButton = function()
			local routeExportButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
			routeExportButton:SetSize(180, 20)
			routeExportButton:SetText("SimC Export Route")
			routeExportButton:Hide()
			routeExportButton:SetScript("OnClick", function()
				print("MDT Sim: Exporting route.")
				StartExport(true)
			end)

			return routeExportButton
		end

		---@return Button
		frameBuilders.groupExportButton = function()
			local groupExportButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
			groupExportButton:SetSize(250, 20)
			groupExportButton:SetText("SimC Export Route + Group")
			groupExportButton:Hide()
			groupExportButton:SetScript("OnClick", function()
				print("MDT Sim: Attempting to export group and route...")
				StartExport(false)
			end)

			return groupExportButton
		end

		---@return MDTSimMobHealthInput
		frameBuilders.mobHealthInput = function()
			---@type MDTSimMobHealthInput
			local mobHealthInput = CreateFrame("EditBox", nil, frames.routeExportButton, "InputBoxTemplate")
			mobHealthInput:SetMaxLetters(3)
			mobHealthInput:EnableMouse(true)
			mobHealthInput:SetFontObject(ChatFontNormal)
			mobHealthInput:SetSize(60, 20)
			mobHealthInput:SetText("27")
			mobHealthInput:SetAutoFocus(false)
			mobHealthInput:SetPoint("BOTTOMRIGHT", frames.routeExportButton, "BOTTOMLEFT")

			mobHealthInput.label = mobHealthInput:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
			mobHealthInput.label:SetText("Mob health %:")
			mobHealthInput.label:SetPoint("RIGHT", mobHealthInput, "LEFT", -5, 0)

			return mobHealthInput
		end

		local function AttachToSidePanel()
			if not MDTSidePanel then
				return
			end

			frames.routeExportButton:SetParent(MDTSidePanel)
			frames.routeExportButton:ClearAllPoints()
			frames.routeExportButton:SetPoint("BOTTOMRIGHT", MDTSidePanel, "TOPRIGHT")
			frames.routeExportButton:Show()

			-- the input anchors to the route export button, so it is only built once that button exists
			local mobHealthInput = frames.mobHealthInput
			mobHealthInput:Show()

			frames.groupExportButton:SetParent(MDTSidePanel)
			frames.groupExportButton:ClearAllPoints()
			frames.groupExportButton:SetPoint("BOTTOMRIGHT", frames.routeExportButton, "TOPRIGHT")
			frames.groupExportButton:Show()
		end

		local function OnInterfaceTableAvailable()
			if MDTSidePanel then
				AttachToSidePanel()
				return
			end

			hooksecurefunc(MDT, "MakeSidePanel", AttachToSidePanel)
		end

		-- `caller` is whatever the hooked API method was invoked on: MythicDungeonToolsAPI itself when
		-- another addon calls it directly, or the interface table when MDT calls it on itself and the
		-- lookup falls through. MakeSidePanel only exists on the latter.
		---@param caller any
		local function CaptureInterfaceTable(caller)
			if MDT then
				return
			end

			if type(caller) ~= "table" or caller == API then
				return
			end

			if type(rawget(caller, "MakeSidePanel")) ~= "function" then
				return
			end

			MDT = caller

			OnInterfaceTableAvailable()
		end

		-- ShowInterfaceInternal calls IsCompatibleVersion before it builds any frame, so the interface
		-- table is captured before MakeSidePanel runs. IsRetail is a second chance in case MDT ever
		-- defines IsCompatibleVersion on the interface table itself.
		for _, methodName in ipairs({ "IsCompatibleVersion", "IsRetail" }) do
			if type(API[methodName]) == "function" then
				hooksecurefunc(API, methodName, CaptureInterfaceTable)
			end
		end
	end)
end)
