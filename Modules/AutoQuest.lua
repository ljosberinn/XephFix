local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoQuest then
		return
	end

	-- NPCs that are never automated, because automating them has consequences
	---@type table<string, boolean>
	local blockedNpcIDs = {
		["15192"] = true, -- Anachronos (Caverns of Time)
		["119388"] = true, -- Chieftain Hatuun (Krokul Hovel, Krokuun)
		["6566"] = true, -- Estelle Gendry (Heirloom Curator, Undercity)
		["45400"] = true, -- Fiona's Caravan (Eastern Plaguelands)
		["18166"] = true, -- Khadgar (Allegiance to Aldor/Scryer, Shattrath)
		["55402"] = true, -- Korgol Crushskull (Darkmoon Faire, Pit Master)
		["6294"] = true, -- Krom Stoutarm (Heirloom Curator, Ironforge)
		["109227"] = true, -- Meliah Grayfeather (Tradewind Roost, Highmountain)
		["99183"] = true, -- Renegade Ironworker (Tanaan Jungle, repeatable quest)
		["114719"] = true, -- Trader Caelen (Obliterum Forge, Dalaran, Broken Isles)
		-- Seals of Fate
		["111243"] = true, -- Archmage Lan'dalock (Dalaran)
		["87391"] = true, -- Fate-Twister Seress (Stormshield)
		["88570"] = true, -- Fate-Twister Tiklal (Horde)
		["142063"] = true, -- Tezran (Boralus Harbor, Alliance)
		["141584"] = true, -- Zurvan (Dazar'alor, Horde)
		-- Wartime Donations (Alliance)
		["142994"] = true, -- Brandal Darkbeard (Boralus)
		["142995"] = true, -- Charlane (Boralus)
		["142993"] = true, -- Chelsea Strand (Boralus)
		["142998"] = true, -- Faella (Boralus)
		["143004"] = true, -- Larold Kyne (Boralus)
		["143005"] = true, -- Liao (Boralus)
		["143007"] = true, -- Mae Wagglewand (Boralus)
		["143008"] = true, -- Norber Togglesprocket (Boralus)
		["142685"] = true, -- Paymaster Vauldren (Boralus)
		["142700"] = true, -- Quartermaster Peregrin (Boralus)
		["142997"] = true, -- Senedras (Boralus)
		-- Wartime Donations (Horde)
		["142970"] = true, -- Kuma Longhoof (Dazar'alor)
		["142969"] = true, -- Logarr (Dazar'alor)
		["142973"] = true, -- Mai-Lu (Dazar'alor)
		["142977"] = true, -- Meredith Swane (Dazar'alor)
		["142981"] = true, -- Merill Redgrave (Dazar'alor)
		["142157"] = true, -- Paymaster Grintooth (Dazar'alor)
		["142158"] = true, -- Quartermaster Rauka (Dazar'alor)
		["142975"] = true, -- Seamstress Vessa (Dazar'alor)
		["142983"] = true, -- Swizzle Fizzcrank (Dazar'alor)
		["142992"] = true, -- Uma'wi (Dazar'alor)
		["142159"] = true, -- Zen'kin (Dazar'alor)
		-- Dragonflight
		["193110"] = true, -- Khadin <Master Artisan> (Ohn'ahran Plains)
	}

	-- NPCs whose quests are never selected automatically, but may still be
	-- accepted and turned in
	---@type table<string, boolean>
	local selectionBlockedNpcIDs = {
		["87706"] = true, -- Gazmolf Futzwangler (Reputation quests, Nagrand, Draenor)
		["70022"] = true, -- Ku'ma (Isle of Giants, Pandaria)
		["12944"] = true, -- Lokhtos Darkbargainer (Thorium Brotherhood, Blackrock Depths)
		["87393"] = true, -- Sallee Silverclamp (Reputation quests, Nagrand, Draenor)
		["10307"] = true, -- Witch Doctor Mau'ari (E'Ko quests, Winterspring)
	}

	---@type table<number, boolean>
	local blockedQuestIDs = {
		[43923] = true, -- Starlight Rose
		[43924] = true, -- Leyblood
		[43925] = true, -- Runescale Koi
		[71162] = true, -- Waygate: Algeth'era (Thaelin Darkanvil, Dragonflight)
		[71165] = true, -- Waygate: Eon's Fringe (Thaelin Darkanvil, Dragonflight)
		[71138] = true, -- Waygate: Rusza'thar Reach (Thaelin Darkanvil, Dragonflight)
		[71178] = true, -- Waygate: Shady Sanctuary (Thaelin Darkanvil, Dragonflight)
		[71157] = true, -- Waygate: Skytop Observatory (Thaelin Darkanvil, Dragonflight)
		[71161] = true, -- Waygate: Vakthros (Thaelin Darkanvil, Dragonflight)
	}

	-- Khuri (The Dragon Isles), Catch and Release. Blocked unless the turn-in
	-- requirement is already met, counting bank and warband bank storage.
	---@type table<number, { itemID: number, count: number }>
	local questsBlockedBelowItemCount = {
		[70199] = { itemID = 194730, count = 20 }, -- Scalebelly Mackerel
		[70200] = { itemID = 194966, count = 20 }, -- Thousandbite Piranha
		[70201] = { itemID = 194967, count = 20 }, -- Aileron Seamoth
		[70202] = { itemID = 194968, count = 20 }, -- Cerulean Spinefish
		[70203] = { itemID = 194969, count = 20 }, -- Temporal Dragonhead
		[70935] = { itemID = 194970, count = 20 }, -- Islefin Dorado
	}

	-- Quests that are only selected once the required items are carried. A
	-- maximum leaves the larger turn-in available for its own quest.
	---@type table<number, { itemID: number, minimum: number, maximum: number? }>
	local questItemRequirements = {
		[62293] = { itemID = 180720, minimum = 25 }, -- Darkened Scourgestones
		[62292] = { itemID = 183200, minimum = 25 }, -- Pitch Black Scourgestones
		[10325] = { itemID = 29425, minimum = 10 }, -- More Marks of Kil'jaeden
		[10326] = { itemID = 29425, minimum = 10 }, -- More Marks of Kil'jaeden
		[10655] = { itemID = 30809, minimum = 1, maximum = 10 }, -- Marks of Sargeras
		[10828] = { itemID = 30809, minimum = 1, maximum = 10 }, -- Marks of Sargeras
		[10654] = { itemID = 30809, minimum = 10 }, -- More Marks of Sargeras
		[10827] = { itemID = 30809, minimum = 10 }, -- More Marks of Sargeras
		[10412] = { itemID = 29426, minimum = 10 }, -- Firewing Signets
		[10415] = { itemID = 29426, minimum = 10 }, -- Firewing Signets
		[10659] = { itemID = 30810, minimum = 1, maximum = 10 }, -- Sunfury Signets
		[10822] = { itemID = 30810, minimum = 1, maximum = 10 }, -- Sunfury Signets
		[10658] = { itemID = 30810, minimum = 10 }, -- More Sunfury Signets
		[10823] = { itemID = 30810, minimum = 10 }, -- More Sunfury Signets
	}

	---@param isSelecting boolean
	---@return boolean
	local function IsNpcBlocked(isSelecting)
		-- npc works when the SoftTargetInteract cvar is set to 3, target does not
		local npcGuid = UnitGUID("npc")

		if not npcGuid or not canaccessvalue(npcGuid) then
			return false
		end

		local npcID = select(6, strsplit("-", npcGuid))

		if not npcID then
			return false
		end

		if blockedNpcIDs[npcID] then
			return true
		end

		return isSelecting and selectionBlockedNpcIDs[npcID] or false
	end

	---@param questID number?
	---@return boolean
	local function IsQuestIDBlocked(questID)
		if not questID then
			return false
		end

		if blockedQuestIDs[questID] then
			return true
		end

		local requirement = questsBlockedBelowItemCount[questID]

		if requirement then
			local includeBank, includeUses, includeReagentBank = true, true, true

			return C_Item.GetItemCount(requirement.itemID, includeBank, includeUses, includeReagentBank)
				< requirement.count
		end

		return false
	end

	---@param questID number?
	---@return boolean
	local function DoesQuestHaveRequirementsMet(questID)
		if not questID then
			return false
		end

		local requirement = questItemRequirements[questID]

		if not requirement then
			return true
		end

		local carried = C_Item.GetItemCount(requirement.itemID)

		if carried < requirement.minimum then
			return false
		end

		if requirement.maximum and carried >= requirement.maximum then
			return false
		end

		return true
	end

	---@param itemID number
	---@return boolean
	local function IsItemAccountBound(itemID)
		local tooltipData = C_TooltipInfo.GetItemByID(itemID)

		if not tooltipData then
			return false
		end

		for _, line in ipairs(tooltipData.lines) do
			local leftText = line.leftText

			if
				leftText == ITEM_BNETACCOUNTBOUND
				or leftText == ITEM_BIND_TO_BNETACCOUNT
				or leftText == ITEM_BIND_TO_ACCOUNT
				or leftText == ITEM_ACCOUNTBOUND
			then
				return true
			end
		end

		return false
	end

	-- Turning in currency, crafting reagents or account-bound items is never
	-- automated, since those hand-ins are rarely reversible
	---@return boolean
	local function DoesQuestRequireProtectedItem()
		for i = 1, 6 do
			local progressItem = _G["QuestProgressItem" .. i]

			if progressItem and progressItem:IsShown() and progressItem.type == "required" then
				if progressItem.objectType == "currency" then
					return true
				elseif progressItem.objectType == "item" then
					local name, _, _, _, _, itemID = GetQuestItemInfo("required", i)

					if name and itemID then
						local isCraftingReagent = select(17, C_Item.GetItemInfo(itemID))

						if isCraftingReagent or IsItemAccountBound(itemID) then
							return true
						end
					end
				end
			end
		end

		return false
	end

	---@return boolean
	local function DoesQuestRequireGold()
		local goldRequired = GetQuestMoneyToGet()

		return goldRequired ~= nil and goldRequired > 0
	end

	---@return boolean
	local function CanTurnInQuest()
		if IsNpcBlocked(false) then
			return false
		end

		if DoesQuestRequireProtectedItem() then
			return false
		end

		return not DoesQuestRequireGold()
	end

	-- Gossip entries that carry a color code or angle brackets are treated as
	-- special interactions (skip ahead, scenario choices) and stop automation.
	-- Purple Darkmoon Faire daily quest text is the one exception.
	---@return boolean
	local function HasDecoratedGossipOption()
		local options = C_GossipInfo.GetOptions()

		for i = 1, #options do
			local name = options[i].name and string.upper(options[i].name)

			if name and (string.find(name, "|C", 1, true) or string.find(name, "<", 1, true)) then
				if not string.find(name, "FF0008E8", 1, true) then
					return true
				end
			end
		end

		return false
	end

	---@return nil
	local function SelectQuestFromGossip()
		local activeQuests = C_GossipInfo.GetActiveQuests()

		for _, questInfo in ipairs(activeQuests) do
			if questInfo.title and questInfo.isComplete and questInfo.questID then
				return C_GossipInfo.SelectActiveQuest(questInfo.questID)
			end
		end

		local availableQuests = C_GossipInfo.GetAvailableQuests()

		for _, questInfo in ipairs(availableQuests) do
			if
				questInfo.questID
				and not IsQuestIDBlocked(questInfo.questID)
				and DoesQuestHaveRequirementsMet(questInfo.questID)
			then
				return C_GossipInfo.SelectAvailableQuest(questInfo.questID)
			end
		end
	end

	-- Both take the 1-based index into the quest greeting list, the same way
	-- QuestTitleButton_OnClick passes the title button's ID. The bundled
	-- annotations declare them without parameters, which is wrong.
	---@type fun(index: number)
	local SelectActiveQuestByIndex = SelectActiveQuest
	---@type fun(index: number)
	local SelectAvailableQuestByIndex = SelectAvailableQuest

	---@return nil
	local function SelectQuestFromGreeting()
		for i = 1, GetNumActiveQuests() do
			local title, isComplete = GetActiveTitle(i)

			if title and isComplete then
				return SelectActiveQuestByIndex(i)
			end
		end

		for i = 1, GetNumAvailableQuests() do
			local title, isComplete = GetAvailableTitle(i)

			if title and not isComplete then
				return SelectAvailableQuestByIndex(i)
			end
		end
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("QUEST_DETAIL")
	frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
	frame:RegisterEvent("QUEST_PROGRESS")
	frame:RegisterEvent("QUEST_COMPLETE")
	frame:RegisterEvent("QUEST_GREETING")
	frame:RegisterEvent("QUEST_AUTOCOMPLETE")
	frame:RegisterEvent("GOSSIP_SHOW")
	frame:RegisterEvent("QUEST_FINISHED")

	---@param self Frame
	---@param event WowEvent
	---@param arg1 number? questID, only sent with QUEST_AUTOCOMPLETE
	frame:SetScript("OnEvent", function(self, event, arg1)
		-- Progress items linger after the interaction ends and would otherwise be
		-- seen by the next quest
		if event == "QUEST_FINISHED" then
			for i = 1, 6 do
				local progressItem = _G["QuestProgressItem" .. i]

				if progressItem and progressItem:IsShown() then
					progressItem:Hide()
				end
			end

			return
		end

		-- Holding shift overrides the automation
		if IsShiftKeyDown() then
			return
		end

		if event == "QUEST_DETAIL" then
			if IsNpcBlocked(false) then
				return
			end

			if QuestGetAutoAccept() then
				-- The client accepted the quest already, so only the window is left
				CloseQuest()
			else
				AcceptQuest()
			end
		elseif event == "QUEST_ACCEPT_CONFIRM" then
			-- Shared escort quests and similar
			ConfirmAcceptQuest()
			StaticPopup_Hide("QUEST_ACCEPT")
		elseif event == "QUEST_PROGRESS" then
			if IsQuestCompletable() and CanTurnInQuest() then
				CompleteQuest()
			end
		elseif event == "QUEST_COMPLETE" then
			if CanTurnInQuest() and GetNumQuestChoices() <= 1 then
				GetQuestReward(GetNumQuestChoices())
			end
		elseif event == "QUEST_AUTOCOMPLETE" then
			-- Show the dialog for objective tracker quests, which then completes
			-- through the regular QUEST_COMPLETE path
			local questLogIndex = C_QuestLog.GetLogIndexForQuestID(arg1)
			local questInfo = questLogIndex and C_QuestLog.GetInfo(questLogIndex)

			if questInfo and questInfo.isAutoComplete then
				C_QuestLog.SetSelectedQuest(C_QuestLog.GetQuestIDForLogIndex(questLogIndex))
				ShowQuestComplete(C_QuestLog.GetSelectedQuest())
			end
		elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
			if not UnitExists("npc") and not QuestFrameGreetingPanel:IsShown() then
				return
			end

			if HasDecoratedGossipOption() then
				return
			end

			if IsNpcBlocked(true) then
				return
			end

			if event == "QUEST_GREETING" then
				SelectQuestFromGreeting()
			else
				SelectQuestFromGossip()
			end
		end
	end)
end)
