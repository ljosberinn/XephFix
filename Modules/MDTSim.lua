local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.MDTSim then
		return
	end

	EventUtil.ContinueOnAddOnLoaded("MythicDungeonTools", function()
		if not MDT then
			return
		end

		local MDT = MDT
		if not MDT.mdt_sim then
			MDT.mdt_sim = {}
		end

		MDT.mdt_sim.ignored_npcs = {
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

		MDT.mdt_sim.export_func = function(only_route)
			if only_route then
				MDT.mdt_sim.success_message = "MDT Sim: Route exported, copy text and then use ESC to close the window."
			else
				MDT.mdt_sim.success_message =
				"MDT Sim: Group and route exported, copy text and then use ESC to close the window."
			end

			MDT.mdt_sim.pending_inspects = {}
			MDT.mdt_sim.inspect_info = {}

			local finish_collection = function()
				MDT.mdt_sim.route_export:Enable()
				MDT.mdt_sim.group_export:Enable()

				MDT.mdt_sim.event_frame:SetScript("OnEvent", nil)
				MDT.mdt_sim.event_frame:SetScript("OnUpdate", nil)
				MDT.mdt_sim.pending_inspects = {}

				local races = {
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

				local classes = {
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

				local specs = {
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

				local roles = {
					["DAMAGER"] = 27,
					["TANK"] = 14,
					["HEALER"] = 5,
				}

				local profiles = ""
				local _, _, _, _, role = GetSpecializationInfo(GetSpecialization())
				local hp_mult = roles[role]
				local text = ""
				local total_profiles = 0

				local skyfury = "0"
				local int = "0"
				local fort = "0"
				local shout = "0"
				local mark = "0"

				local touch = "0"
				local brand = "0"
				local hunters_mark = "0"

				local _, _, class_id = UnitClass("player")

				if class_id == 7 then
					skyfury = "1"
				end
				if class_id == 8 then
					int = "1"
				end
				if class_id == 5 then
					fort = "1"
				end
				if class_id == 1 then
					shout = "1"
				end
				if class_id == 11 then
					mark = "1"
				end

				if class_id == 10 then
					touch = "1"
				end
				if class_id == 12 then
					brand = "1"
				end
				if class_id == 3 then
					hunters_mark = "1"
				end

				for unit, info in pairs(MDT.mdt_sim.inspect_info) do
					local name = UnitName(unit)
					if name then
						local profile = ""

						local _, _, class_id = UnitClass(unit)
						local _, _, race_id = UnitRace(unit)
						local spec = specs[info.spec_id]

						if not class_id or not race_id or not spec then
							print("MDT Sim: Couldn't generate profile for " .. unit .. " with name " .. name .. ".")
						else
							profile = profile .. classes[class_id] .. '="' .. name .. '"\n'
							profile = profile .. "spec=" .. spec .. "\n"
							profile = profile .. "level=" .. UnitLevel(unit) .. "\n"
							profile = profile .. "race=" .. races[race_id] .. "\n"
							profile = profile .. "talents=" .. info.talents .. "\n"

							profile = profile .. "\n" .. info.items .. "\n"

							profiles = profiles .. profile .. "\n"

							local _, _, _, _, role = GetSpecializationInfoByID(info.spec_id)
							hp_mult = hp_mult + roles[role]
							total_profiles = total_profiles + 1

							if class_id == 7 then
								skyfury = "1"
							end
							if class_id == 8 then
								int = "1"
							end
							if class_id == 5 then
								fort = "1"
							end
							if class_id == 1 then
								shout = "1"
							end
							if class_id == 11 then
								mark = "1"
							end

							if class_id == 10 then
								touch = "1"
							end
							if class_id == 12 then
								brand = "1"
							end
							if class_id == 3 then
								hunters_mark = "1"
							end
						end
					end
				end

				text = text .. "\n" .. profiles

				local mult
				if total_profiles == 0 then
					mult = tonumber(MDT.mdt_sim.input:GetText())

					if not mult then
						print("MDT Sim - Error: Percent must be a number.")
						return
					else
						if mult < 1 or mult > 100 then
							print("MDT Sim - Error: Percent must be in the 1 to 100 range.")
							return
						end
					end
				else
					mult = hp_mult
					if mult > 100 then
						print("MDT Sim - Warning: Mob health was over 100% because of too many dps profiles.")
						mult = 100
					end
				end

				local preset = MDT:GetCurrentPreset()
				local pulls = MDT:GetPulls(preset)
				local difficulty = preset.difficulty
				local dungeon = MDT:GetDungeonName(preset.value.currentDungeonIdx)

				local events = {}
				local fenrir = 0
				local pull_i = 1

				for _, pull in pairs(pulls) do
					local delay = math.random(5, 15)
					local delay_str = string.format("%03d", delay)

					local raid_event = "raid_events+=/pull,pull="
						.. string.format("%02d", pull_i)
						.. ",bloodlust=0,delay="
						.. delay_str
						.. ",enemies="
					local e = 0
					local sharedHealth = false
					local manastorm_boss = 1
					local managerie_boss = 1
					local blight_boss = 1
					local sub_pulls = 1

					if pull then
						for enemy_idx, clones in pairs(pull) do
							if tonumber(enemy_idx) and MDT.dungeonEnemies[preset.value.currentDungeonIdx][enemy_idx] then
								local enemy = MDT.dungeonEnemies[preset.value.currentDungeonIdx][enemy_idx]

								if not MDT.mdt_sim.ignored_npcs[enemy.id] then
									local c = 1
									for _, clone_idx in pairs(clones) do
										if enemy.clones[clone_idx] and MDT:IsCloneIncluded(enemy_idx, clone_idx) then
											local health = MDT:CalculateEnemyHealth(
												enemy.isBoss ~= nil,
												enemy.health,
												difficulty,
												enemy.ignoreFortified
											)
											health = health * (mult / 100)

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
												fenrir = fenrir + 1
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

											if (enemy.id == 95674 or enemy.id == 99868) and fenrir > 1 then
												-- ignore additional Fenrirs if he's in more than 1 pull
											elseif enemy.id == 164556 or enemy.id == 164555 then
												-- Manastorms, separate into 2 pulls so they're not simmed together as a 2 target fight
												sub_pulls = 2
												local fixed_health = health * 0.9
												local fixed_name = string.gsub(enemy.name, " ", "_")

												if manastorm_boss == 1 then
													if e > 0 then
														raid_event = raid_event .. "|"
													end
													e = e + 1
													raid_event = raid_event
														.. '"BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
														.. ":"
														.. enemy.creatureType
													manastorm_boss = 2
												else
													local new_pull = pull_i + (manastorm_boss - 1)
													events[new_pull] = "raid_events+=/pull,pull="
														.. string.format("%02d", new_pull)
														.. ',bloodlust=0,delay=000,enemies="BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
														.. ":"
														.. enemy.creatureType
												end
											elseif enemy.id == 176556 or enemy.id == 176705 or enemy.id == 176555 then
												-- Grand Managerie, separate into 3 pulls so they're not simmed together as a 3 target fight
												sub_pulls = 3
												local fixed_name = string.gsub(enemy.name, " ", "_")

												if managerie_boss == 1 then
													if e > 0 then
														raid_event = raid_event .. "|"
													end
													e = e + 1
													raid_event = raid_event
														.. '"BOSS_'
														.. fixed_name
														.. '":'
														.. floor(health)
														.. ":"
														.. enemy.creatureType
													managerie_boss = 2
												else
													local new_pull = pull_i + (managerie_boss - 1)
													events[new_pull] = "raid_events+=/pull,pull="
														.. string.format("%02d", new_pull)
														.. ',bloodlust=0,delay=000,enemies="BOSS_'
														.. fixed_name
														.. '":'
														.. floor(health)
														.. ":"
														.. enemy.creatureType
													managerie_boss = 3
												end
											elseif
												enemy.id == 198997
												or enemy.id == 201788
												or enemy.id == 201790
												or enemy.id == 201792
											then
												-- Blight of Galakrond, separate into a 50% st phase then 25% each 2t phase (hp is shared),
												-- don't care about matching the order perfectly, the hp should just resemble reality (50% st into 2t with 25% each)
												sub_pulls = 2
												local fixed_name = string.gsub(enemy.name, " ", "_")

												if blight_boss == 1 then
													local fixed_health = health * 0.5
													if e > 0 then
														raid_event = raid_event .. "|"
													end
													e = e + 1
													raid_event = raid_event
														.. '"BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
														.. ":"
														.. enemy.creatureType
													blight_boss = 2
												elseif blight_boss == 2 then
													-- set up bosses 2 and 3 as the shared hp 2t phase
													local fixed_health = health * 0.25
													local new_pull = pull_i + 1
													events[new_pull] = "raid_events+=/pull,pull="
														.. string.format("%02d", new_pull)
														.. ',bloodlust=0,delay=000,enemies="BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
														.. ":"
														.. enemy.creatureType
													blight_boss = 3
												elseif blight_boss == 3 then
													local fixed_health = health * 0.25
													local new_pull = pull_i + 1
													events[new_pull] = events[new_pull]
														.. '|"BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
														.. ":"
														.. enemy.creatureType
													blight_boss = 4
												end
												-- ignore whatever boss is 4th since it isn't needed
											elseif enemy.id == 98965 or enemy.id == 98970 then
												sub_pulls = 2
												local fixed_name = string.gsub(enemy.name, " ", "_")

												if enemy.id == 98965 then
													-- Kur'talos
													if e > 0 then
														raid_event = raid_event .. "|"
													end
													e = e + 1
													raid_event = raid_event
														.. '"BOSS_'
														.. fixed_name
														.. '":'
														.. floor(health)
														.. ":"
														.. enemy.creatureType
												end

												if enemy.id == 98970 then
													-- Dantalionax
													local fixed_health = health / 3
													local new_pull = pull_i + 1
													events[new_pull] = "raid_events+=/pull,pull="
														.. string.format("%02d", new_pull)
														.. ',bloodlust=0,delay=000,enemies="BOSS_'
														.. fixed_name
														.. '":'
														.. floor(fixed_health)
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
													local fixed_health = health * 0.5

													local foundLieutenant = false
													-- add the lieutenant
													for enemyIndex, enemyClones in pairs(pull) do
														if
															tonumber(enemyIndex)
															and MDT.dungeonEnemies[preset.value.currentDungeonIdx][enemyIndex]
														then
															local lieutenant =
																MDT.dungeonEnemies[preset.value.currentDungeonIdx]
																[enemyIndex]
															for _, cloneIndex in pairs(enemyClones) do
																if
																	lieutenant.clones[cloneIndex]
																	and MDT:IsCloneIncluded(enemyIndex, cloneIndex)
																then
																	if
																		lieutenant.id == 239833
																		or lieutenant.id == 239836
																		or lieutenant.id == 239834
																	then
																		foundLieutenant = true
																		raid_event = raid_event
																			.. '"BOSS_'
																			.. lieutenant.name
																			.. '":'
																			.. floor(fixed_health)
																			.. ":"
																			.. lieutenant.creatureType
																		e = e + 1
																	end
																end
															end
														end
													end

													if foundLieutenant then
														raid_event = raid_event
															.. '"BOSS_'
															.. enemy.name
															.. '":'
															.. floor(fixed_health)
															.. ":"
															.. enemy.creatureType
													else
														sharedHealth = false
														raid_event = raid_event
															.. '"BOSS_'
															.. enemy.name
															.. '":'
															.. floor(health)
															.. ":"
															.. enemy.creatureType
													end
													e = e + 1
												else
													-- one of the lieutenants, could be part of the boss or alone
													local foundBoss = false
													for enemyIndex, enemyClones in pairs(pull) do
														if
															tonumber(enemyIndex)
															and MDT.dungeonEnemies[preset.value.currentDungeonIdx][enemyIndex]
														then
															local boss =
																MDT.dungeonEnemies[preset.value.currentDungeonIdx]
																[enemyIndex]
															for _, cloneIndex in pairs(enemyClones) do
																if
																	boss.clones[cloneIndex]
																	and MDT:IsCloneIncluded(enemyIndex, cloneIndex)
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
														if e > 0 then
															raid_event = raid_event .. "|"
														end
														e = e + 1
														raid_event = raid_event
															.. '"'
															.. enemy.name
															.. '":'
															.. floor(health)
															.. ":"
															.. enemy.creatureType
													end
												end
											else
												local unit = enemy.isBoss and "" or "_" .. c
												local prefix = enemy.isBoss and "BOSS_" or ""
												c = c + 1
												if e > 0 then
													raid_event = raid_event .. "|"
												end
												e = e + 1

												local fixed_name = string.gsub(enemy.name, '"', "`")
												fixed_name = string.gsub(fixed_name, "%:", "")
												fixed_name = string.gsub(fixed_name, " ", "_")
												fixed_name = string.gsub(fixed_name, ",", "")
												fixed_name = string.gsub(fixed_name, "/", "")

												local fixed_type = string.gsub(enemy.creatureType, " ", "_")

												raid_event = raid_event
													.. '"'
													.. prefix
													.. fixed_name
													.. unit
													.. '":'
													.. floor(health)
													.. ":"
													.. fixed_type
											end
										end
									end
								end
							end
						end
					end

					if e > 0 then
						if sharedHealth then
							raid_event = raid_event .. ",shared_health=1"
						end

						events[pull_i] = raid_event
						pull_i = pull_i + sub_pulls
					end
				end

				text = text .. "fight_style=DungeonRoute\n"
				-- party buffs
				text = text .. "override.skyfury=" .. skyfury .. "\n"
				text = text .. "override.arcane_intellect=" .. int .. "\n"
				text = text .. "override.power_word_fortitude=" .. fort .. "\n"
				text = text .. "override.battle_shout=" .. shout .. "\n"
				text = text .. "override.mark_of_the_wild=" .. mark .. "\n"
				-- target debuffs
				text = text .. "override.mystic_touch=" .. touch .. "\n"
				text = text .. "override.chaos_brand=" .. brand .. "\n"
				text = text .. "override.hunters_mark=" .. hunters_mark .. "\n"

				text = text .. "override.mortal_wounds=0\n"
				text = text .. "override.bleeding=0\n"

				text = text .. "single_actor_batch=0\n"
				text = text .. "max_time=2700\n"
				text = text .. 'enemy="' .. dungeon .. " " .. difficulty .. '"\n'
				text = text .. "enemy_health=99999999\n"
				-- not used in sim currently
				--text = text.."keystone_level="..difficulty.."\n"
				--text = text.."keystone_pct_hp="..mult.."\n"

				for _, event in pairs(events) do
					text = text .. "\n" .. event
				end

				MDT.mdt_sim.scroll:GetScrollChild():SetText(text)
				MDT.mdt_sim.scroll:GetScrollChild():HighlightText()
				MDT.mdt_sim.scroll:Show()

				print(MDT.mdt_sim.success_message)
			end

			if only_route then
				finish_collection()
				return
			end

			MDT.mdt_sim.route_export:Disable()
			MDT.mdt_sim.group_export:Disable()

			local request_inspect = function()
				for _, unit in pairs(MDT.mdt_sim.pending_inspects) do
					if unit and CanInspect(unit) and select(4, UnitPosition("player")) == select(4, UnitPosition(unit)) then
						NotifyInspect(unit)
						return
					end
				end
				MDT.mdt_sim.pending_inspects = {}

				finish_collection()
			end

			local generate_items = function(unit)
				local slots = {
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

				local items = ""

				for index, name in pairs(slots) do
					local line = name .. "="

					local link
					link = GetInventoryItemLink(unit, index)

					if link then
						local payload = { strsplit(":", link) }

						line = line .. ",id=" .. payload[2]

						local num_bonus_ids = tonumber(payload[14])

						if num_bonus_ids then
							line = line .. ",bonus_id="
							for i = 15, 14 + num_bonus_ids do
								if i > 15 then
									line = line .. "/"
								end
								line = line .. payload[i]
							end
						end

						if tonumber(payload[3]) then
							line = line .. ",enchant_id=" .. payload[3]
						end

						local has_gem = false
						for i = 4, 8 do
							if tonumber(payload[i]) then
								if not has_gem then
									line = line .. ",gem_id="
									has_gem = true
								else
									line = line .. "/"
								end
								line = line .. payload[i]
							end
						end
					end

					items = items .. line .. "\n"
				end
				return items .. "\n"
			end

			MDT.mdt_sim.event_frame:SetScript("OnEvent", function(self, event, guid)
				local unit = MDT.mdt_sim.pending_inspects[guid]
				if unit then
					MDT.mdt_sim.inspect_info[unit] = {}
					MDT.mdt_sim.inspect_info[unit].talents = C_Traits.GenerateInspectImportString(unit)
					MDT.mdt_sim.inspect_info[unit].spec_id = GetInspectSpecialization(unit)
					MDT.mdt_sim.inspect_info[unit].items = generate_items(unit)

					MDT.mdt_sim.pending_inspects[guid] = nil
					ClearInspectPlayer()
					request_inspect()
				end
			end)
			MDT.mdt_sim.event_frame.request_time = 0
			MDT.mdt_sim.event_frame:SetScript("OnUpdate", function(self, elapsed)
				MDT.mdt_sim.event_frame.request_time = MDT.mdt_sim.event_frame.request_time + elapsed
				if MDT.mdt_sim.event_frame.request_time > 3 then
					print("MDT Sim - Warning: Party inspection timed out, try again for missing profiles.")
					finish_collection()
				end
			end)

			local members = {
				"party1",
				"party2",
				"party3",
				"party4",
			}

			for _, unit in ipairs(members) do
				local name = UnitName(unit)
				if name then
					MDT.mdt_sim.pending_inspects[UnitGUID(unit)] = unit
				end
			end

			request_inspect()
		end

		if not MDT.mdt_sim.event_frame then
			MDT.mdt_sim.event_frame = CreateFrame("Frame")
		end

		MDT.mdt_sim.event_frame:UnregisterAllEvents()
		MDT.mdt_sim.event_frame:SetScript("OnEvent", nil)
		MDT.mdt_sim.event_frame:SetScript("OnUpdate", nil)
		MDT.mdt_sim.event_frame:RegisterEvent("INSPECT_READY")

		-- copyable text window containing export
		if not MDT.mdt_sim.scroll then
			MDT.mdt_sim.scroll = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
			MDT.mdt_sim.scroll:SetFrameStrata("TOOLTIP")
			MDT.mdt_sim.scroll:SetPoint("CENTER")
			MDT.mdt_sim.scroll:SetSize(1200, 600)
			MDT.mdt_sim.scroll:EnableMouse(true)

			MDT.mdt_sim.scroll.bg = MDT.mdt_sim.scroll:CreateTexture(nil, "BACKGROUND")
			MDT.mdt_sim.scroll.bg:SetAllPoints()
			MDT.mdt_sim.scroll.bg:SetColorTexture(0, 0, 0, 1)

			MDT.mdt_sim.scroll.edit = CreateFrame("EditBox", nil, MDT.mdt_sim.scroll)
			MDT.mdt_sim.scroll.edit:SetSize(1200, 600)
			MDT.mdt_sim.scroll.edit:SetMultiLine(true)
			MDT.mdt_sim.scroll.edit:SetMaxLetters(99999)
			MDT.mdt_sim.scroll.edit:EnableMouse(true)
			MDT.mdt_sim.scroll.edit:SetFontObject(ChatFontNormal)
			MDT.mdt_sim.scroll.edit:SetScript("OnEscapePressed", function()
				MDT.mdt_sim.scroll:Hide()
			end)
			MDT.mdt_sim.scroll:SetScrollChild(MDT.mdt_sim.scroll.edit)
		end
		MDT.mdt_sim.scroll:Hide()

		-- button attached to MDT window to trigger an export
		if not MDT.mdt_sim.route_export then
			MDT.mdt_sim.route_export = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
			MDT.mdt_sim.route_export:SetSize(180, 20)
			MDT.mdt_sim.route_export:SetText("SimC Export Route")
			MDT.mdt_sim.route_export:Hide()
		end

		if not MDT.mdt_sim.group_export then
			MDT.mdt_sim.group_export = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
			MDT.mdt_sim.group_export:SetSize(250, 20)
			MDT.mdt_sim.group_export:SetText("SimC Export Route + Group")
			MDT.mdt_sim.group_export:Hide()
		end

		if not MDT.mdt_sim.input then
			MDT.mdt_sim.input = CreateFrame("EditBox", nil, MDT.mdt_sim.route_export, "InputBoxTemplate")
			MDT.mdt_sim.input:SetMaxLetters(3)
			MDT.mdt_sim.input:EnableMouse(true)
			MDT.mdt_sim.input:SetFontObject(ChatFontNormal)
			MDT.mdt_sim.input:SetSize(60, 20)
			MDT.mdt_sim.input:SetText("27")
			MDT.mdt_sim.input:SetAutoFocus(false)
			MDT.mdt_sim.input:SetPoint("BOTTOMRIGHT", MDT.mdt_sim.route_export, "BOTTOMLEFT")

			if not MDT.mdt_sim.input.label then
				MDT.mdt_sim.input.label = MDT.mdt_sim.input:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
			end

			MDT.mdt_sim.input.label:SetText("Mob health %:")
			MDT.mdt_sim.input.label:SetPoint("RIGHT", MDT.mdt_sim.input, "LEFT", -5, 0)
		end

		MDT.mdt_sim.route_export:SetScript("OnClick", function()
			print("MDT Sim: Exporting route.")
			MDT.mdt_sim.export_func(true)
		end)
		MDT.mdt_sim.group_export:SetScript("OnClick", function()
			print("MDT Sim: Attempting to export group and route...")
			MDT.mdt_sim.export_func(false)
		end)

		if MDTSidePanel then
			MDT.mdt_sim.route_export:SetParent(MDTSidePanel)
			MDT.mdt_sim.route_export:SetPoint("BOTTOMRIGHT", MDTSidePanel, "TOPRIGHT")
			MDT.mdt_sim.route_export:Show()

			MDT.mdt_sim.group_export:SetParent(MDTSidePanel)
			MDT.mdt_sim.group_export:SetPoint("BOTTOMRIGHT", MDT.mdt_sim.route_export, "TOPRIGHT")
			MDT.mdt_sim.group_export:Show()
		else
			hooksecurefunc(MDT, "MakeSidePanel", function()
				MDT.mdt_sim.route_export:SetParent(MDTSidePanel)
				MDT.mdt_sim.route_export:SetPoint("BOTTOMRIGHT", MDTSidePanel, "TOPRIGHT")
				MDT.mdt_sim.route_export:Show()

				MDT.mdt_sim.group_export:SetParent(MDTSidePanel)
				MDT.mdt_sim.group_export:SetPoint("BOTTOMRIGHT", MDT.mdt_sim.route_export, "TOPRIGHT")
				MDT.mdt_sim.group_export:Show()
			end)
		end
	end)
end)
