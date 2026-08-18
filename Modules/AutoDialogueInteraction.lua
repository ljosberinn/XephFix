local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoDialogueInteraction then
		return
	end

	-- Gossip options that are selected as soon as they show up, no modifier
	-- needed. The value records whether the option raises a confirmation popup
	-- that has to be accepted along with it.
	---@type table<number, boolean>
	local gossipIdsToAutoSelect = {
		-- Dire Maul
		[29281] = false, -- Ironbark the Redeemer, open the door
		-- Old Hillsbrad Foothills
		[33853] = false, -- Erozion, pack of incendiary bombs
		[34081] = false, -- Brazen, ride to Durnholde Keep
		[33364] = false, -- Thrall, free him from his cell
		[34372] = false, -- Thrall, Taretha cannot see you
		[35171] = false, -- Thrall, head into the mountains
		[34362] = false, -- Thrall, Tarren Mill
		[32900] = false, -- Thrall, we're ready
		[34893] = false, -- Taretha, strange wizard
		[33525] = false, -- Taretha, we'll get you out
		-- The Slave Pens
		[135555] = false, -- summon Lord Ahune
		-- The Culling of Stratholme
		[35027] = false, -- Chromie, skip us all ahead (skip 1/2)
		[38140] = false, -- Chromie, yes please (skip 2/2)
		[35026] = false, -- Chromie, yes please (skip, on a second visit)
		[35025] = false, -- Chromie, why have I been sent back (no skip 1/3)
		[37031] = false, -- Chromie, what was this decision (no skip 2/3)
		[36608] = false, -- Chromie, how does the Infinite Dragonflight interfere (no skip 3/3)
		-- Trial of the Champion
		[38517] = false, -- I am ready, skip the pageantry (only after one clear)
		[38514] = false, -- I am ready (boss 1)
		[38515] = false, -- I am ready for the next challenge (boss 2)
		[38516] = false, -- I am ready (boss 3)
		-- Pit of Saron
		[136624] = false,
		[136271] = false,
		[136316] = false,
		[136280] = false,
		[136301] = false,
		[138618] = false,
		-- The Deadmines
		[39764] = false, -- continue reading Vanessa's note, alerts her
		-- Hour of Twilight
		[38993] = false, -- Thrall, begin first boss trash
		[39796] = false, -- Thrall, begin first boss
		[39657] = false, -- Thrall, leave first boss area
		[39487] = false, -- Thrall, begin second boss trash
		[39155] = false, -- Thrall, begin third boss trash
		-- Scarlet Monastery
		[110383] = true, -- Headless Horseman, accept the curse (embers)
		[110379] = true, -- Headless Horseman, accept the curse (thorns)
		[110372] = true, -- Headless Horseman, accept the curse (shadows)
		[110377] = true, -- Headless Horseman, accept the curse (delusions)
		[111387] = true, -- Headless Horseman, accept all curses
		[36316] = false, -- call the Headless Horseman
		-- Siege of Niuzao Temple
		[34873] = false, -- Vojak, we're ready to defend
		-- Court of Stars
		[45674] = false, -- suspicious noble clue, cape
		[45675] = false, -- suspicious noble clue, no cape
		[45660] = false, -- suspicious noble clue, pouch
		[45666] = false, -- suspicious noble clue, potions
		[45676] = false, -- suspicious noble clue, long sleeves
		[45677] = false, -- suspicious noble clue, short sleeves
		[45673] = false, -- suspicious noble clue, gloves
		[45672] = false, -- suspicious noble clue, no gloves
		[45657] = false, -- suspicious noble clue, male
		[45658] = false, -- suspicious noble clue, female
		[45636] = false, -- suspicious noble clue, light vest
		[45635] = false, -- suspicious noble clue, dark vest
		[45667] = false, -- suspicious noble clue, no potions
		[45659] = false, -- suspicious noble clue, book
		[45624] = false, -- signal lantern, starts the boat RP
		[45656] = false, -- Ly'leth Lunastre, take the costume
		-- Halls of Valor
		[44910] = true, -- Odyn, start the encounter
		[44755] = false, -- King Ranulf, begin combat
		[44801] = false, -- King Haldor, begin combat
		[44802] = false, -- King Bjorn, begin combat
		[44754] = false, -- King Tor, begin combat
		-- Return to Karazhan
		[46684] = false, -- Barnes, I'm not an actor
		[46685] = false, -- Barnes, ok I'll give it a try then
		-- Freehold
		[48039] = true, -- Harlan Sweete, a fight? bring it on
		-- Horrific Vision of Orgrimmar
		[49742] = false, -- Garona Halforcen, continue the vision
		-- Temple of Sethraliss
		[48126] = false, -- Avatar of Sethraliss, start the encounter
		-- Mists of Tirna Scithe
		[52979] = false, -- activate the anima seed after the first boss
		[52980] = false, -- activate the anima seed after the second boss
		-- Tazavesh
		[53719] = false, -- portal right after Zo'phex the Sentinel
		[53721] = false, -- portal outside Myza's Oasis
		[53722] = false, -- portal outside The P.O.S.T.
		[53723] = false, -- portal before So'azmi
		[53724] = false, -- portal on the way to The Grand Menagerie
		-- Algeth'ar Academy
		[107065] = false, -- crit
		[107081] = false, -- haste
		[107082] = false, -- mastery
		[107083] = false, -- healing taken
		[107088] = false, -- versatility
		-- Brackenhide Hollow
		[56025] = false, -- detoxify cauldron, requires Alchemy
		-- Dawn of the Infinite
		[110513] = false, -- attempt to open the rift
		-- Halls of Infusion
		[107192] = false, -- limited immortality device, requires Engineering
		[107206] = false, -- infused mushroom, requires Herbalism
		-- Neltharus
		[55886] = false, -- party movement speed, requires Cooking
		[107310] = false, -- blacksmith damage ability, requires Blacksmithing
		-- The Azure Vault
		[56056] = false, -- proceed to Upper Chambers
		[56247] = false, -- proceed to Middle Chambers
		[56248] = false, -- proceed to Mausoleum of Legends
		[56250] = false, -- proceed to Lower Chambers
		[56251] = false, -- proceed to Crystal Chambers
		[56378] = false, -- return from Mausoleum of Legends
		-- Ara-Kara, City of Echoes
		[121214] = false, -- pull on a bit of thread, requires Tailoring
		-- Cinderbrew Meadery
		[121210] = false, -- boil the mead, requires Alchemy or Cooking
		[121215] = false, -- boil the mead, requires Alchemy or Cooking
		[121318] = false, -- flamethrower, requires Engineering or Gnome/Goblin/Mechagnome
		-- City of Threads
		[122351] = false, -- sabotage the device, Rogue
		[122352] = false, -- tinker with the device, Engineering
		[122353] = false, -- manipulate the device, Priest
		-- Priory of the Sacred Flame
		[120715] = false, -- harness the Sacred Flame, Priest
		[120716] = false, -- harness the Sacred Flame, Paladin
		-- The Stonevault
		[124023] = false, -- earthen bar, Dwarf/Dark Iron Dwarf/Earthen
		[124024] = false, -- earthen bar, Blacksmithing
		[124025] = false, -- earthen bar, Warrior
		-- Brawler's Guild
		[41149] = false, -- Brawl'gar Arena Grunt, sign me up for a fight
		[41787] = false, -- Bizmo's Brawlpub Bouncer, sign me up for a fight
		-- Zekvir rares
		[123520] = false, -- Reno Jackson, start combat
		-- Altar of Fangs
		[141730] = false, -- complete the mixture, requires Cooking or Alchemy
		-- Den of Nalorakk
		[135009] = false, -- Ethereal Pyre, start the dungeon
		[135010] = false, -- Ethereal Pyre, continue the dungeon
		[137694] = false, -- warding incense, requires Alchemy or Druid Bear Form
		-- Maisara Caverns
		[137387] = false, -- cooking stew
		[137428] = false, -- ritual cauldron, dip your weapon
		-- Nexus-Point Xenas
		[137133] = false, -- tripwire
		-- The War Within delves. Disabled by default,
		-- because selecting them commits you to a delve objective.
		[133907] = false, -- Archival Assault, start (Vaultwarden Falnora)
		[134070] = false, -- Archival Assault, start (Xeronia)
		[134016] = false, -- Archival Assault, start (Vaultwarden Gandrus)
		[134202] = false, -- Archival Assault, start (Spymaster Casnegosa)
		[134281] = false, -- Archival Assault, continue (Spymaster Casnegosa)
		[111366] = false, -- Fungal Folly, start (Stoneguard Benston)
		[113928] = false, -- Fungal Folly, continue (Patreux)
		[113929] = false, -- Fungal Folly, continue (One Tusk)
		[113937] = false, -- Fungal Folly, continue (Kasthrik)
		[113939] = false, -- Fungal Folly, continue (Twizzle Runabout)
		[113941] = false, -- Fungal Folly, continue (Bill)
		[132634] = false, -- Fungal Folly, start (Engineer Fizzlepickle)
		[133267] = false, -- Fungal Folly, continue (Engineer Fizzlepickle)
		[131267] = false, -- Fungal Folly, start (Gila Crosswires)
		[121536] = false, -- Mycomancer Cavern, start (Aliya Hillhelm)
		[121445] = false, -- Mycomancer Cavern, start (Peculiar Fungi)
		[122875] = false, -- Mycomancer Cavern, continue (Brann)
		[121493] = false, -- Mycomancer Cavern, continue (Alekk)
		[121564] = false, -- Mycomancer Cavern, continue (Alekk)
		[121539] = false, -- Mycomancer Cavern, start (Chief Dinaire)
		[121541] = false, -- Mycomancer Cavern, continue (Chief Dinaire)
		[125513] = false, -- The Waterworks, start (Prospera Cogwail)
		[120018] = false, -- The Waterworks, start (Foreman Bruknar)
		[120096] = false, -- The Waterworks, continue (Foreman Bruknar)
		[120081] = false, -- The Waterworks, start (Pagsly)
		[120082] = false, -- The Waterworks, continue (Pagsly)
		[131152] = false, -- Earthcrawl Mines, start (Exterminator Janx)
		[120551] = false, -- Earthcrawl Mines, start (Maklin Drillstab)
		[120553] = false, -- Earthcrawl Mines, continue (Maklin Drillstab)
		[120330] = false, -- Earthcrawl Mines, start (Foreman Pivk)
		[120383] = false, -- Earthcrawl Mines, continue (Foreman Pivk)
		[120540] = false, -- Earthcrawl Mines, start (Lamplighter Rathling)
		[120541] = false, -- Earthcrawl Mines, continue (Lamplighter Rathling)
		[131312] = false, -- Kriegval's Rest, start (Balga Wicksfix)
		[119802] = false, -- Kriegval's Rest, start (Kuvkel)
		[119930] = false, -- Kriegval's Rest, start (Dagran Thaurissan II)
		[133710] = false, -- Kriegval's Rest, start (Waxmonger Squick)
		[131401] = false, -- The Dread Pit, start (Prospera Cogwail)
		[121508] = false, -- The Dread Pit, start (Vant)
		[123392] = false, -- The Dread Pit, continue (Vant)
		[121526] = false, -- The Dread Pit, start (Vanathia)
		[131427] = false, -- Skittering Breach, start (Lamplighter Kaerter)
		[121408] = false, -- Skittering Breach, start (Lamplighter Havrik Chayvn)
		[125516] = false, -- Nightfall Sanctum, start (Nimsi Loosefire)
		[120767] = false, -- Nightfall Sanctum, start (Great Kyron)
		[131402] = false, -- The Spiral Weave, start (Nerubian Scout)
		[121566] = false, -- The Spiral Weave, start (Weaver's Instructions)
		[131474] = false, -- Tek-Rethan Abyss, start (Pamsy)
		[120132] = false, -- Tek-Rethan Abyss, start (Partially-Chewed Goblin)
		[120255] = false, -- Tek-Rethan Abyss, start (Vetiverian)
		[131318] = false, -- The Underkeep, start (Madam Goya)
		[121502] = false, -- The Underkeep, start (Weaver's Instructions)
		[121578] = false, -- The Sinkhole, start (Raen Dawncavalyr)
		[131349] = false, -- The Sinkhole, start (Alyza Bowblaze)
		[131159] = false, -- Excavation Site 9, start (Craggle Fritzbrains)
		[131162] = false, -- Excavation Site 9, continue (Craggle Fritzbrains)
		[132946] = false, -- Excavation Site 9, start (Chef Carl)
		[132991] = false, -- Excavation Site 9, start (Lostalot)
		-- Midnight delves, likewise disabled by default.
		[136318] = false, -- Atal'Aman, start (Fleek)
		[136385] = false, -- Atal'Aman, start (Kasha)
		[136317] = false, -- Atal'Aman, start (Torundo The Grizzled)
		[138496] = false, -- Atal'Aman, teleport to boss (Mojo)
		[135708] = false, -- Collegiate Calamity, start (Bloomkeeper Thornflare)
		[135865] = false, -- Collegiate Calamity, start (Celoenus Blackflame)
		[135798] = false, -- Collegiate Calamity, start (Thalandri Fatesinger)
		[139635] = false, -- Gnarldor Isle, start (Artolla)
		[139585] = false, -- Gnarldor Isle, start (Minchi)
		[136477] = false, -- Parhelion Plaza, start (Grand Artificer Romuul)
		[134669] = false, -- Parhelion Plaza, start (Grand Artificer Romuul)
		[136446] = false, -- Parhelion Plaza, start (Vindicator Xayann)
		[134949] = false, -- Shadowguard Point, start (Lysikas)
		[136275] = false, -- Sunkiller Sanctum, start (Riftblade Maella)
		[136279] = false, -- Sunkiller Sanctum, start (Darkmender Deremius Duskwalk)
		[136086] = false, -- Sunkiller Sanctum, start (Null-Theorist Selune)
		[138009] = false, -- The Darkway, start (Technician Mireille)
		[138317] = false, -- The Darkway, start (Technician Mireille)
		[136141] = false, -- The Darkway, start (Technician Mireille)
		[137248] = false, -- The Gulf of Memory, start (Ashayo)
		[137389] = false, -- The Gulf of Memory, start (Ashayo)
		[134668] = false, -- The Grudge Pit, start (Boletus)
		[137619] = false, -- The Shadow Enclave, start (Doleana Silverstalk)
		[137580] = false, -- The Shadow Enclave, start (Gabby Flashwiks)
		[135239] = false, -- Twilight Crypts, start (Dulgor Legstuck)
		[135634] = false, -- Twilight Crypts, start (Twilight Hostage)
		[135811] = false, -- Twilight Crypts, start (Scout Lok'aemon)
	}

	-- NPCs whose first gossip option is always taken, no modifier needed.
	-- Keyed by string, because the ID is read out of the unit GUID. The value
	-- records whether the option raises a confirmation popup that has to be
	-- accepted along with it.
	---@type table<string, boolean>
	local alwaysSkippedNpcIDs = {
		["132969"] = false, -- Katy Stampwhistle (toy)
		["104201"] = false, -- Katy Stampwhistle (npc)
		["26499"] = false, -- Arthas (The Culling of Stratholme)
		["55500"] = false, -- Illidan (Well of Eternity)
		["102278"] = false, -- Lieutenant Sinclari (Assault on Violet Hold)
		["118884"] = true, -- Aegis of Aggramar (Cathedral of Eternal Night)
		-- Court of Stars buff items
		["105157"] = false, -- Arcane Power Conduit
		["105117"] = false, -- Flask of the Solemn Night
		["105160"] = false, -- Fel Orb
		["105831"] = false, -- Infernal Tome
		["106024"] = false, -- Magical Lantern
		["105249"] = false, -- Nightshade Refreshments
		["106108"] = false, -- Starlight Rose Brew
		["105340"] = false, -- Umbral Bloom
		["106110"] = false, -- Waterlogged Scroll
	}

	-- NPCs whose first gossip option is taken while alt is held, even though they
	-- offer more than one option
	---@type table<string, boolean>
	local altSkippedNpcIDs = {
		["96782"] = false, -- Lucian Trias (rogue doors, Dalaran, Broken Isles)
		["93188"] = false, -- Mongar (rogue doors, Dalaran, Broken Isles)
		["97004"] = false, -- "Red" Jack Findle (rogue doors, Dalaran, Broken Isles)
	}

	---@param needsConfirmation boolean
	---@return nil
	local function SelectFirstGossipOption(needsConfirmation)
		local options = C_GossipInfo.GetOptions()

		if not options[1] then
			return
		end

		if options[1].gossipOptionID then
			C_GossipInfo.SelectOption(options[1].gossipOptionID, "", needsConfirmation)
		elseif GossipFrame and GossipFrame:IsShown() then
			-- Some options have no gossip option ID, such as the Suspicious Noble
			-- NPCs in Court of Stars, Suramar
			GossipFrame:SelectGossipOption(1)
		end
	end

	---@return string? npcID
	local function GetInteractedNpcID()
		-- npc works when the SoftTargetInteract cvar is set to 3, target does not
		local npcGuid = UnitGUID("npc")

		if not npcGuid or not canaccessvalue(npcGuid) then
			return nil
		end

		return select(6, strsplit("-", npcGuid))
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("GOSSIP_SHOW")

	---@param self Frame
	---@param event WowEvent
	frame:SetScript("OnEvent", function(self, event, ...)
		if event == "GOSSIP_SHOW" then
			local options = C_GossipInfo.GetOptions()

			for i = 1, #options do
				local needsConfirmation = gossipIdsToAutoSelect[options[i].gossipOptionID]

				if needsConfirmation ~= nil then
					C_GossipInfo.SelectOption(options[i].gossipOptionID, "", needsConfirmation)
					return
				end
			end

			local npcID = GetInteractedNpcID()

			if npcID then
				local needsConfirmation = alwaysSkippedNpcIDs[npcID]

				if needsConfirmation ~= nil then
					SelectFirstGossipOption(needsConfirmation)
					return
				end
			end

			if not IsAltKeyDown() then
				return
			end

			if npcID then
				local needsConfirmation = altSkippedNpcIDs[npcID]

				if needsConfirmation ~= nil then
					SelectFirstGossipOption(needsConfirmation)
					return
				end
			end

			-- A single option with nothing else on offer is never a choice
			if
				#options == 1
				and C_GossipInfo.GetNumAvailableQuests() == 0
				and C_GossipInfo.GetNumActiveQuests() == 0
			then
				SelectFirstGossipOption(false)
			end
		end
	end)
end)
