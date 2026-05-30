local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.CharacterSheetImprovements then
		return
	end

	-- Tyfon Character Sheet
	local characterOpen = false

	-- itemIDs for async loading
	---@type table<number, { unit: string, slot: number }>
	local itemInfoRequested = {}

	-- Hooking NotifyInspect to remember the unit last inspected
	-- This will be used async when INSPECT_READY is called
	local inspecting = false
	---@type string|nil
	local lastInspectUnit = nil
	---@type string|nil
	local lastInspectGuid = nil

	hooksecurefunc("NotifyInspect", function(unit)
		if unit == "mouseover" or unit == GetUnitName("player") then
			return
		end

		lastInspectUnit = unit
		lastInspectGuid = UnitGUID(unit)
	end)

	---@type table<number, string>
	local slotNameMap = {
		[Enum.InventoryType.IndexHeadType] = "Head",
		[Enum.InventoryType.IndexNeckType] = "Neck",
		[Enum.InventoryType.IndexShoulderType] = "Shoulder",
		[Enum.InventoryType.IndexBodyType] = "Shirt",
		[Enum.InventoryType.IndexChestType] = "Chest",
		[Enum.InventoryType.IndexWaistType] = "Waist",
		[Enum.InventoryType.IndexLegsType] = "Legs",
		[Enum.InventoryType.IndexFeetType] = "Feet",
		[Enum.InventoryType.IndexWristType] = "Wrist",
		[Enum.InventoryType.IndexHandType] = "Hands",
		[Enum.InventoryType.IndexFingerType] = "Finger0",
		[Enum.InventoryType.IndexTrinketType] = "Finger1",
		[Enum.InventoryType.IndexWeaponType] = "Trinket0",
		[Enum.InventoryType.IndexShieldType] = "Trinket1",
		[Enum.InventoryType.IndexRangedType] = "Back",
		[Enum.InventoryType.IndexCloakType] = "MainHand",
		[Enum.InventoryType.Index2HweaponType] = "SecondaryHand",
		[Enum.InventoryType.IndexTabardType] = "Tabard",
	}

	local function SlotIsEnchantable(slot)
		return slot == Enum.InventoryType.IndexHeadType
			or slot == Enum.InventoryType.IndexShoulderType
			or slot == Enum.InventoryType.IndexChestType
			or slot == Enum.InventoryType.IndexLegsType
			or slot == Enum.InventoryType.IndexFeetType
			or slot == Enum.InventoryType.IndexFingerType
			or slot == Enum.InventoryType.IndexTrinketType
			or slot == Enum.InventoryType.IndexCloakType
	end

	---@param unit string
	---@param slot number
	---@return string?
	local function GetSlotFrameName(unit, slot)
		return slotNameMap[slot]
			and string.format("%s%sSlot", unit == "player" and "Character" or "Inspect", slotNameMap[slot])
			or nil
	end

	-- Returns true if the slot is on the right side of the character panel
	---@param slot number
	---@return boolean
	local function IsRightSide(slot)
		return slot == Enum.InventoryType.IndexWaistType
			or slot == Enum.InventoryType.IndexLegsType
			or slot == Enum.InventoryType.IndexFeetType
			or slot == Enum.InventoryType.IndexHandType
			or slot == Enum.InventoryType.IndexFingerType
			or slot == Enum.InventoryType.IndexTrinketType
			or slot == Enum.InventoryType.IndexWeaponType
			or slot == Enum.InventoryType.IndexShieldType
			or slot == Enum.InventoryType.IndexCloakType
	end

	---@param slot number
	---@param slotFrameName string
	---@return FontString, FontString, [Button, Button, Button]
	local function SetupFrames(slot, slotFrameName)
		local rightSide = IsRightSide(slot)
		local framePoint = rightSide and "RIGHT" or "LEFT"
		local parentPoint = rightSide and "LEFT" or "RIGHT"
		local offsetX = rightSide and -10 or 9

		---@type Frame
		local parentFrame = _G[slotFrameName]

		local LevelText = _G[slotFrameName .. "XephIlvl"]
		if LevelText == nil then
			LevelText = parentFrame:CreateFontString(slotFrameName .. "XephIlvl", "ARTWORK", "GameTooltipText")

			if slot == 16 or slot == 17 then -- weapons put the ilvl on top
				LevelText:SetPoint("BOTTOM", parentFrame, "TOP", 0, 5)
			else
				LevelText:SetPoint(framePoint, parentFrame, parentPoint, offsetX, 0)
			end

			LevelText:SetShadowColor(0, 0, 0)
			LevelText:SetShadowOffset(1, -1)
		end

		local EnchantText = _G[slotFrameName .. "XephEnchant"]
		if EnchantText == nil then
			EnchantText = parentFrame:CreateFontString(slotFrameName .. "XephEnchant", "ARTWORK", "GameTooltipText")
			EnchantText:SetPoint(framePoint, parentFrame, parentPoint, offsetX, -12)
			EnchantText:SetShadowColor(0, 0, 0)
			EnchantText:SetShadowOffset(1, -1)
		end

		local ilvlSpacingX = 27
		local GemFrames = {}

		for i = 1, 3 do
			GemFrames[i] = _G[slotFrameName .. "XephGem" .. i]

			if GemFrames[i] == nil then
				GemFrames[i] = CreateFrame("Button", slotFrameName .. "XephGem" .. i, parentFrame,
					"UIPanelButtonTemplate")
				GemFrames[i]:SetSize(14, 14)
			end

			if slot == 16 or slot == 17 then
				GemFrames[i]:SetPoint("BOTTOM", parentFrame, "TOP", -14 + (15 * (i - 1)), 18)
			else
				local gemOffsetX = rightSide and offsetX - (15 * (i - 1)) or offsetX + (15 * (i - 1))
				gemOffsetX = rightSide and gemOffsetX - ilvlSpacingX or gemOffsetX + ilvlSpacingX
				GemFrames[i]:SetPoint(framePoint, parentFrame, parentPoint, gemOffsetX, 0)
			end
		end

		return LevelText, EnchantText, GemFrames
	end

	local missingEnchantsLabel = "cheap fuck"

	---@param slot number
	---@param itemLink string
	---@param initialItemLevel number
	---@return number, string
	local function ParseItemLevelAndEnchant(slot, itemLink, initialItemLevel)
		---@type GameTooltip
		local ItemTooltip = _G["XephScanningTooltip"]

		if ItemTooltip == nil then
			ItemTooltip = CreateFrame("GameTooltip", "XephScanningTooltip", WorldFrame, "GameTooltipTemplate")
		end

		-- SetOwner must be called before every SetHyperlink; omitting it causes
		-- the tooltip to silently stop populating after certain UI events
		ItemTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
		ItemTooltip:SetHyperlink(itemLink)

		local enchant = ""

		for i = 1, ItemTooltip:NumLines() do
			local leftText = _G["XephScanningTooltipTextLeft" .. i]:GetText()
			local foundEnchant = leftText:match(ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)"))

			if foundEnchant ~= nil then
				local qualityPosition = string.find(foundEnchant, "|A:")

				if qualityPosition ~= nil then
					qualityPosition = qualityPosition - 2
					foundEnchant = string.sub(foundEnchant, 1, qualityPosition)
					enchant = foundEnchant:gsub("^.-%s%-%s", "")
				else
					enchant = foundEnchant
				end
			end

			local foundLevel = leftText:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))

			if foundLevel then
				initialItemLevel = foundLevel
			end
		end

		if enchant == "" and SlotIsEnchantable(slot) then
			enchant = missingEnchantsLabel
		end

		return initialItemLevel, enchant
	end

	---@type FontString|nil
	local AverageItemLevelText = nil

	---@param unit string
	---@param slot number
	local function UpdateSlot(unit, slot)
		if unit == nil or slot == nil then
			return
		end

		local slotFrameName = GetSlotFrameName(unit, slot)
		if slotFrameName == nil or _G[slotFrameName] == nil then
			return
		end

		if not UnitIsUnit("player", unit) and slot == Enum.InventoryType.IndexHeadType then
			if AverageItemLevelText == nil then
				AverageItemLevelText = InspectModelFrame:CreateFontString("XephAvgIlvl", "OVERLAY", "GameTooltipText")
				AverageItemLevelText:SetPoint("TOP", InspectModelFrame, "TOP", 0, -5)
				AverageItemLevelText:SetShadowColor(0, 0, 0)
				AverageItemLevelText:SetShadowOffset(1, -1)
			end

			local averageLevel = C_PaperDollInfo.GetInspectItemLevel(unit)

			AverageItemLevelText:SetText("|cFFFFFFFF" .. averageLevel .. "|r")
			AverageItemLevelText:Show()
		end

		local LevelText, EnchantText, GemFrames = SetupFrames(slot, slotFrameName)
		local itemLink = GetInventoryItemLink(unit, slot)

		-- clear all if no item equipped
		if itemLink == nil or itemLink == "" then
			LevelText:SetText("")
			EnchantText:SetText("")

			for i = 1, 3 do
				GemFrames[i]:Hide()
			end

			return
		end

		-- get item information
		local _, _, itemQuality, initialItemLevel = C_Item.GetItemInfo(itemLink)
		if initialItemLevel == nil then
			local itemId = C_Item.GetItemInfoInstant(itemLink)
			itemInfoRequested[itemId] = { unit = unit, slot = slot }
			return
		end

		local itemLevel, enchant = ParseItemLevelAndEnchant(slot, itemLink, initialItemLevel)

		-- -- set iLvl
		local levelFont = LevelText:GetFont()
		LevelText:SetFont(levelFont, 12)

		local colorInfo = ColorManager.GetColorDataForItemQuality(itemQuality)
		LevelText:SetText(colorInfo.hex .. itemLevel .. "|r")
		LevelText:Show()

		-- set enchant
		local enchantFont = EnchantText:GetFont()
		EnchantText:SetFont(enchantFont, 10)

		local color = enchant == missingEnchantsLabel and "FFFF0000" or "FF00FF00"

		-- find and strip existing color
		local newColor, coloredEnchant = enchant:match("|c(%x%x%x%x%x%x%x%x)(.+)|r") -- hex codes
		if coloredEnchant == nil then
			newColor, coloredEnchant = enchant:match("|c(n.+:)(.+)|r")         -- named color
		end
		if coloredEnchant then
			color = newColor
			enchant = coloredEnchant
		end

		-- need to check for quality symbols
		local qualityStart = string.find(enchant, "|A")
		local quality = ""
		if qualityStart then
			quality = string.sub(enchant, qualityStart)
			enchant = string.sub(enchant, 1, qualityStart - 1)
		end

		local maxLength = 18
		if maxLength > 0 and strlen(enchant) > maxLength then
			enchant = format("%." .. maxLength .. "s", enchant) .. "..."
		end
		enchant = enchant .. quality
		EnchantText:SetText("|c" .. color .. enchant .. "|r")
		EnchantText:Show()

		-- set gems
		local gemCount = C_Item.GetItemNumSockets(itemLink)
		for i = 1, 3 do
			if i <= gemCount then
				local gemId = C_Item.GetItemGemID(itemLink, i)

				if gemId ~= nil then
					-- todo: this taints
					-- local gem = Item:CreateFromItemID(gemId)
					local gemIcon = C_Item.GetItemIconByID(gemId)
					-- local _, gemLink = C_Item.GetItemInfo(gemId)
					GemFrames[i]:SetNormalTexture(gemIcon)
					GemFrames[i]:Show()

					-- Gem may not be loaded even if the item is, load async
					-- gem:ContinueOnItemLoad(function()
					-- GemFrames[i]:SetScript("OnEnter", function()
					-- 	GameTooltip:SetOwner(GemFrames[i], "ANCHOR_CURSOR")
					-- 	GameTooltip:SetHyperlink(gemLink)
					-- 	GameTooltip:Show()
					-- end)
					-- GemFrames[i]:SetScript("OnLeave", function()
					-- 	GameTooltip:Hide()
					-- end)
					-- end)
				else
					GemFrames[i]:SetNormalTexture("Interface\\ITEMSOCKETINGFRAME\\UI-EmptySocket-Prismatic.blp")
					-- GemFrames[i]:SetScript("OnEnter", nil)
					-- GemFrames[i]:SetScript("OnLeave", nil)
					GemFrames[i]:Show()
				end
			else
				GemFrames[i]:Hide()
			end
		end
	end

	---@param unit string
	local function UpdateAllSlots(unit)
		for slot = Enum.InventoryType.IndexHeadType, Enum.InventoryType.IndexTabardType do
			UpdateSlot(unit, slot)
		end
	end

	hooksecurefunc("PaperDollFrame_UpdateStats", function()
		local maxItemLevel, equippedItemLevel = GetAverageItemLevel()
		local str = maxItemLevel == equippedItemLevel and string.format("%.2f", equippedItemLevel)
			or string.format("%.2f/%.2f", equippedItemLevel, maxItemLevel)

		CharacterStatsPane.ItemLevelFrame.Value:SetText(str)
	end)

	-- instead of using triggers, just run when the character frame is shown
	PaperDollFrame:HookScript("OnShow", function(self)
		if not characterOpen then -- OnShow can be called multiple times?
			UpdateAllSlots("player")
		end

		characterOpen = true
	end)

	PaperDollFrame:HookScript("OnHide", function(self)
		characterOpen = false
	end)

	-- inspect is delay loaded, but we can hook functions instead
	do
		local inspectHooked = false

		hooksecurefunc("InspectFrame_LoadUI", function()
			if not inspectHooked then
				InspectPaperDollFrame:HookScript("OnShow", function(self)
					inspecting = true
				end)
				InspectPaperDollFrame:HookScript("OnHide", function(self)
					inspecting = false
				end)
				inspectHooked = true
			end

			inspecting = true
		end)
	end

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	eventFrame:RegisterEvent("INSPECT_READY")
	eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")

	eventFrame:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_EQUIPMENT_CHANGED" then
			if not characterOpen then
				return
			end

			local slotId = ...
			if slotId == nil then
				return
			end

			UpdateSlot("player", slotId)
		elseif event == "INSPECT_READY" then
			-- Fired, possibly multiple times, when inspect data is ready
			if not inspecting then
				return
			end

			local inspectGuid = ...
			if inspectGuid == nil or inspectGuid ~= lastInspectGuid or lastInspectUnit == nil then
				return
			end

			UpdateAllSlots(lastInspectUnit)
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			-- GetItemInfo for uncached item data is ready
			if not characterOpen and not inspecting then
				return
			end

			local itemId = ...
			if itemId == nil or itemInfoRequested[itemId] == nil then
				return
			end

			local request = itemInfoRequested[itemId]
			itemInfoRequested[itemId] = nil
			UpdateSlot(request.unit, request.slot)
		elseif event == "UNIT_INVENTORY_CHANGED" then
			-- needed for item enchants
			if not characterOpen then
				return
			end

			local unit = ...
			if unit ~= "player" then
				return
			end

			UpdateAllSlots(unit)
		end
	end)
end)
