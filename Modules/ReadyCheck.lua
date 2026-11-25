local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.ReadyCheck then
		return
	end

	if C_AddOns.IsAddOnLoaded("NorthernSkyRaidTools") then
		return
	end

	---@class ReadyCheckPanel : Frame

	---@class PixelBorderFrame : Frame
	---@field HorizontalLines Texture[]
	---@field VerticalLines Texture[]

	---@class ReadyCheckIconOverlay : Frame
	---@field ReadyMark Texture
	---@field Timer FontString

	---@class ReadyCheckIcon : Button
	---@field Icon Texture
	---@field Overlay ReadyCheckIconOverlay
	---@field Border PixelBorderFrame
	---@field tooltipItemID number?
	---@field tooltipSpellID number?
	---@field expirationTime number?

	---@class ReadyCheckIconInfo
	---@field itemID number?
	---@field spellID number?
	---@field useLocation string? "bag slot" of the stack a click uses; nil keeps the icon inert
	---@field targetSlot number?
	---@field isActive boolean
	---@field expirationTime number?

	---@class ReadyCheckConsumableType
	---@field itemIDs number[] best quality first
	---@field buffID number?
	---@field enchantIDs table<number, true>?

	local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8x8"
	local BORDER_PIXELS = 1
	local ICON_SIZE = 36
	local ICON_GAP = 4
	local CONTENT_PADDING = 10
	local TIMER_FONT_SIZE = 14
	-- Keeps the title clear of the close button when only a few icons show.
	local MINIMUM_PANEL_WIDTH = 160
	local SHOW_DELAY_SECONDS = 5
	-- On zone-in, instance info can still be settling at LOADING_SCREEN_DISABLED.
	local INSTANCE_SETTLE_SECONDS = 1
	local COUNTDOWN_THRESHOLD_SECONDS = 40 * 60
	local SOURCE_OF_MAGIC_SPELL_ID = 369459
	local PRESERVATION_SPEC_ID = 1468
	local FOOD_FALLBACK_SPELL_ID = 1285644

	-- The Bg insets in Templates/ReadyCheck.xml.
	local BACKGROUND_INSET_LEFT = 8
	local BACKGROUND_INSET_RIGHT = 3
	local BACKGROUND_INSET_TOP = 23
	local BACKGROUND_INSET_BOTTOM = 3

	-- 12 above the top of ReadyCheckFrame, which is 100 tall and centred 10 below UIParent's centre (ReadyCheck.xml).
	-- Mirrored rather than anchored to, so the secure buttons never hang off a Blizzard frame.
	local PANEL_OFFSET_Y = -10 + 100 / 2 + 12

	-- Items best quality first: max fleeting, fleeting, max personal, personal.
	---@type ReadyCheckConsumableType[]
	local flaskTypes = {
		{ buffID = 1235111, itemIDs = { 245929, 245928, 241326, 241327 } }, -- Flask of the Shattered Sun
		{ buffID = 1235108, itemIDs = { 245933, 245932, 241322, 241323 } }, -- Flask of the Magisters
		{ buffID = 1235110, itemIDs = { 245931, 245930, 241324, 241325 } }, -- Flask of the Blood Knights
		{ buffID = 1235057, itemIDs = { 245926, 245927, 241320, 241321 } }, -- Flask of Thalassian Resistance
	}

	-- Every "Hearty Well Fed" added in 12.0 or later: Wowhead's spell names minus those already in SpellName at
	-- 11.2.7.65299 (wago.tools).
	local foodBuffIDs = {
		1232076,
		1232078,
		1232080,
		1232082,
		1284641,
		1284642,
		1284643,
		1284644,
		1284647,
		1284648,
		1284649,
		1284650,
		1285644,
		1305150,
		1305153,
		1305155,
		1305157,
	}

	for spellID = 1233703, 1233733 do
		table.insert(foodBuffIDs, spellID)
	end

	---@type ReadyCheckConsumableType[]
	local augmentRuneTypes = {
		{ buffID = 1264426, itemIDs = { 259085 } }, -- Void-Touched Augment Rune
	}

	-- Each quality applies its own enchant.
	---@type ReadyCheckConsumableType[]
	local weaponEnhancementTypes = {
		{ itemIDs = { 243734, 243733 }, enchantIDs = { [8052] = true, [8051] = true } }, -- Thalassian Phoenix Oil
	}

	-- Keyed by C_Map.GetBestMapForUnit at zone-in, like TalentReminders.
	---@type table<number, number[]>
	local dungeonGear = {
		[2433] = { 270168 }, -- Murder Row: Font of Venomous Rage
		[1004] = { 270168 }, -- Kings' Rest: Font of Venomous Rage
		[2588] = { 270168 }, -- Altar of Fangs: Font of Venomous Rage
		[2095] = { 270168 }, -- Ruby Life Pools: Font of Venomous Rage
		[1038] = { 270168 }, -- Temple of Sethraliss: Font of Venomous Rage
		[2564] = { 270168 }, -- Den of Nalorakk: Font of Venomous Rage
		[2574] = { 270168 }, -- Voidscar Arena: Font of Venomous Rage
		[2500] = { 270168 }, -- The Blinding Vale: Font of Venomous Rage
	}

	local auraUnits = {
		player = true,
		party1 = true,
		party2 = true,
		party3 = true,
		party4 = true,
	}

	local liveEvents = {
		"UNIT_AURA",
		"BAG_UPDATE_DELAYED",
		"PLAYER_EQUIPMENT_CHANGED",
		"WEAPON_ENCHANT_CHANGED",
		"WEAPON_SLOT_CHANGED",
		"GROUP_ROSTER_UPDATE",
		"SPELLS_CHANGED",
	}

	for _, consumableTypes in ipairs({ flaskTypes, augmentRuneTypes, weaponEnhancementTypes }) do
		for _, consumableType in ipairs(consumableTypes) do
			for _, itemID in ipairs(consumableType.itemIDs) do
				C_Item.RequestLoadItemDataByID(itemID)
			end
		end
	end

	for _, itemIDs in pairs(dungeonGear) do
		for _, itemID in ipairs(itemIDs) do
			C_Item.RequestLoadItemDataByID(itemID)
		end
	end

	local panel = CreateFrame("Frame", "XephUIReadyCheck", UIParent, "XephUIReadyCheckPanelTemplate") --[[@as ReadyCheckPanel]]
	-- Assigned once InitializeIcon exists; acquiring is what creates the secure buttons, always out of combat.
	local iconPool
	---@type ReadyCheckIcon[]
	local shownIcons = {}
	---@type FunctionContainer?
	local showTimer
	---@type FunctionContainer?
	local countdownTicker
	local isRefreshQueued = false
	---@type number?
	local dungeonInstanceID
	---@type number?
	local dungeonMapID

	---@type string?
	local cachedFontPath

	---@return string
	local function GetFont()
		if cachedFontPath then
			return cachedFontPath
		end

		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

		if LSM then
			local fetchedPath = LSM:Fetch("font", "Roboto Condensed Bold")
			if fetchedPath then
				cachedFontPath = fetchedPath
				return cachedFontPath
			end
		end

		cachedFontPath = "Interface/AddOns/Platynator/Assets/Fonts/RobotoCondensed-Bold.ttf"

		return cachedFontPath
	end

	---@param parent Frame
	---@return PixelBorderFrame
	local function CreatePixelBorder(parent)
		---@type PixelBorderFrame
		local borderFrame = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
		borderFrame:SetAllPoints(parent)
		borderFrame.HorizontalLines = {}
		borderFrame.VerticalLines = {}

		for _, edge in ipairs({ "TOP", "BOTTOM" }) do
			local line = borderFrame:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint(edge .. "LEFT", borderFrame, edge .. "LEFT", 0, 0)
			line:SetPoint(edge .. "RIGHT", borderFrame, edge .. "RIGHT", 0, 0)
			table.insert(borderFrame.HorizontalLines, line)
		end

		for _, edge in ipairs({ "LEFT", "RIGHT" }) do
			local line = borderFrame:CreateTexture(nil, "OVERLAY")
			line:SetTexture(SQUARE_TEXTURE)
			line:SetVertexColor(0, 0, 0, 1)
			line:SetPoint("TOP" .. edge, borderFrame, "TOP" .. edge, 0, 0)
			line:SetPoint("BOTTOM" .. edge, borderFrame, "BOTTOM" .. edge, 0, 0)
			table.insert(borderFrame.VerticalLines, line)
		end

		return borderFrame
	end

	---@return boolean
	local function IsInMythicDungeon()
		return select(3, GetInstanceInfo()) == DifficultyUtil.ID.DungeonMythic
	end

	---@return boolean
	local function CanShow()
		return IsInMythicDungeon()
			and not C_ChallengeMode.IsChallengeModeActive()
			and not InCombatLockdown()
			and not C_Secrets.ShouldAurasBeSecret()
	end

	-- The map ID changes per floor, so the zone-in one is kept for the whole visit.
	local function RememberDungeon()
		local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

		if instanceType ~= "party" then
			dungeonInstanceID = nil
			dungeonMapID = nil
			return
		end

		local mapID = C_Map.GetBestMapForUnit("player")

		-- Within a visit, only a map with gear replaces the remembered one: a /reload deeper in records that floor,
		-- and the next loading screen at the entrance has to be able to correct it.
		if not mapID or (instanceID == dungeonInstanceID and not dungeonGear[mapID]) then
			return
		end

		dungeonInstanceID = instanceID
		dungeonMapID = mapID
	end

	---@return table<number, string>
	local function FindCarriedItems()
		local itemLocations = {}

		for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local itemID = C_Container.GetContainerItemID(bag, slot)

				if itemID and not itemLocations[itemID] then
					itemLocations[itemID] = bag .. " " .. slot
				end
			end
		end

		return itemLocations
	end

	---@param aura AuraData
	---@return number?
	local function GetAuraExpirationTime(aura)
		local expirationTime = aura.expirationTime

		if issecretvalue(expirationTime) or expirationTime == 0 then
			return nil
		end

		return expirationTime
	end

	---@param consumableType ReadyCheckConsumableType
	---@return boolean isActive
	---@return number? expirationTime
	local function GetBuffState(consumableType)
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(consumableType.buffID)

		if not aura then
			return false
		end

		return true, GetAuraExpirationTime(aura)
	end

	-- One icon per type that's carried or active. With neither, the first type stands in, inert and desaturated.
	---@param icons ReadyCheckIconInfo[]
	---@param consumableTypes ReadyCheckConsumableType[]
	---@param itemLocations table<number, string>
	---@param GetActiveState fun(consumableType: ReadyCheckConsumableType): boolean, number?
	---@param targetSlot number?
	local function CollectConsumables(icons, consumableTypes, itemLocations, GetActiveState, targetSlot)
		local countBefore = #icons

		for _, consumableType in ipairs(consumableTypes) do
			local isActive, expirationTime = GetActiveState(consumableType)
			local carriedItemID

			for _, itemID in ipairs(consumableType.itemIDs) do
				if itemLocations[itemID] then
					carriedItemID = itemID
					break
				end
			end

			if carriedItemID or isActive then
				table.insert(icons, {
					itemID = carriedItemID or consumableType.itemIDs[1],
					useLocation = carriedItemID and itemLocations[carriedItemID],
					targetSlot = targetSlot,
					isActive = isActive,
					expirationTime = expirationTime,
				})
			end
		end

		if #icons > countBefore then
			return
		end

		table.insert(icons, { itemID = consumableTypes[1].itemIDs[1], isActive = false })
	end

	-- Status only, unlike the other consumables: NSRT's food list leads with a feast, which a click would drop.
	---@param icons ReadyCheckIconInfo[]
	local function CollectFood(icons)
		for _, spellID in ipairs(foodBuffIDs) do
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)

			if aura then
				table.insert(
					icons,
					{ spellID = spellID, isActive = true, expirationTime = GetAuraExpirationTime(aura) }
				)
				return
			end
		end

		table.insert(icons, { spellID = FOOD_FALLBACK_SPELL_ID, isActive = false })
	end

	---@param slot number
	---@return boolean
	local function HoldsWeapon(slot)
		local itemID = GetInventoryItemID("player", slot)

		if not itemID then
			return false
		end

		return select(6, C_Item.GetItemInfoInstant(itemID)) == Enum.ItemClass.Weapon
	end

	---@param icons ReadyCheckIconInfo[]
	---@param itemLocations table<number, string>
	local function CollectWeaponEnhancements(icons, itemLocations)
		for _, slot in ipairs({ INVSLOT_MAINHAND, INVSLOT_OFFHAND }) do
			if HoldsWeapon(slot) then
				local enchantInfo = C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)

				-- Matched per type, so one applied oil doesn't mark every type on that hand as active.
				CollectConsumables(icons, weaponEnhancementTypes, itemLocations, function(enhancementType)
					if not enchantInfo or not enhancementType.enchantIDs[enchantInfo.enchantID] then
						return false
					end

					return true, GetTime() + enchantInfo.remainingTimeMs / 1000
				end, slot)
			end
		end
	end

	---@param icons ReadyCheckIconInfo[]
	local function CollectSourceOfMagic(icons)
		if
			not IsInGroup()
			or PlayerUtil.GetCurrentSpecID() == PRESERVATION_SPEC_ID
			or not C_SpellBook.IsSpellKnown(SOURCE_OF_MAGIC_SPELL_ID)
		then
			return
		end

		local spellName = C_Spell.GetSpellName(SOURCE_OF_MAGIC_SPELL_ID)
		local aura

		for index = 1, GetNumSubgroupMembers() do
			aura = C_UnitAuras.GetAuraDataBySpellName("party" .. index, spellName, "HELPFUL|PLAYER")

			if aura then
				break
			end
		end

		table.insert(icons, {
			spellID = SOURCE_OF_MAGIC_SPELL_ID,
			isActive = aura ~= nil,
			expirationTime = aura and GetAuraExpirationTime(aura),
		})
	end

	---@param icons ReadyCheckIconInfo[]
	local function CollectDungeonGear(icons)
		local itemIDs = dungeonMapID and dungeonGear[dungeonMapID]

		if not itemIDs then
			return
		end

		for _, itemID in ipairs(itemIDs) do
			local isEquipped = C_Item.IsEquippedItem(itemID)

			if isEquipped or C_Item.GetItemCount(itemID) > 0 then
				table.insert(icons, { itemID = itemID, isActive = isEquipped })
			end
		end
	end

	-- In display order.
	---@type (fun(icons: ReadyCheckIconInfo[], itemLocations: table<number, string>))[]
	local collectors = {
		function(icons, itemLocations)
			CollectConsumables(icons, flaskTypes, itemLocations, GetBuffState)
		end,
		CollectFood,
		function(icons, itemLocations)
			CollectConsumables(icons, augmentRuneTypes, itemLocations, GetBuffState)
		end,
		CollectWeaponEnhancements,
		CollectSourceOfMagic,
		CollectDungeonGear,
	}

	local function UpdateCountdowns()
		local now = GetTime()

		for _, icon in ipairs(shownIcons) do
			local remaining = icon.expirationTime and icon.expirationTime - now

			if remaining and remaining < COUNTDOWN_THRESHOLD_SECONDS then
				icon.Overlay.Timer:SetText(SecondsToClock(math.max(0, math.ceil(remaining))))
				icon.Overlay.Timer:Show()
			else
				icon.Overlay.Timer:Hide()
			end
		end
	end

	-- Everything is snapped to whole physical pixels here, so a 1 pixel border stays 1 pixel and gaps stay even.
	local function Layout()
		local scale = panel:GetEffectiveScale()
		local pixelSize = PixelUtil.GetPixelToUIUnitFactor() / scale
		local borderSize = BORDER_PIXELS * pixelSize
		local iconSize = PixelUtil.GetNearestPixelSize(ICON_SIZE, scale)
		local step = PixelUtil.GetNearestPixelSize(ICON_SIZE + ICON_GAP, scale)
		local rowWidth = (#shownIcons - 1) * step + iconSize
		local rowTop = PixelUtil.GetNearestPixelSize(BACKGROUND_INSET_TOP + CONTENT_PADDING, scale)
		local panelWidth = PixelUtil.GetNearestPixelSize(
			math.max(
				BACKGROUND_INSET_LEFT + CONTENT_PADDING * 2 + rowWidth + BACKGROUND_INSET_RIGHT,
				MINIMUM_PANEL_WIDTH
			),
			scale
		)
		local panelHeight = rowTop
			+ iconSize
			+ PixelUtil.GetNearestPixelSize(CONTENT_PADDING + BACKGROUND_INSET_BOTTOM, scale)
		-- Centered on the background, which sits off-centre in the frame.
		local rowLeft = math.round(
			(panelWidth - rowWidth + BACKGROUND_INSET_LEFT - BACKGROUND_INSET_RIGHT) / 2 / pixelSize
		) * pixelSize

		panel:SetSize(panelWidth, panelHeight)

		for index, icon in ipairs(shownIcons) do
			icon:SetSize(iconSize, iconSize)
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", panel, "TOPLEFT", rowLeft + (index - 1) * step, -rowTop)

			for _, line in ipairs(icon.Border.HorizontalLines) do
				line:SetHeight(borderSize)
			end

			for _, line in ipairs(icon.Border.VerticalLines) do
				line:SetWidth(borderSize)
			end
		end

		-- UIParent's centre and an odd pixel width can both leave the panel between pixels, which would blur
		-- every icon border; nudge it onto the grid instead.
		panel:ClearAllPoints()
		panel:SetPoint("BOTTOM", UIParent, "CENTER", 0, PANEL_OFFSET_Y)

		local left, bottom = panel:GetLeft(), panel:GetBottom()

		if not left or not bottom then
			return
		end

		panel:SetPoint(
			"BOTTOM",
			UIParent,
			"CENTER",
			math.round(left / pixelSize) * pixelSize - left,
			math.round(bottom / pixelSize) * pixelSize - bottom + PANEL_OFFSET_Y
		)
	end

	---@return ReadyCheckIconInfo[]
	local function CollectIcons()
		local itemLocations = FindCarriedItems()
		---@type ReadyCheckIconInfo[]
		local icons = {}

		for _, Collect in ipairs(collectors) do
			Collect(icons, itemLocations)
		end

		return icons
	end

	-- A countdown still asks for attention, so only icons with time to spare count as ready.
	---@param icons ReadyCheckIconInfo[]
	---@return boolean
	local function IsEverythingReady(icons)
		local now = GetTime()

		for _, info in ipairs(icons) do
			if
				not info.isActive or (info.expirationTime and info.expirationTime - now < COUNTDOWN_THRESHOLD_SECONDS)
			then
				return false
			end
		end

		return true
	end

	---@param icons ReadyCheckIconInfo[]
	local function Render(icons)
		iconPool:ReleaseAll()
		table.wipe(shownIcons)

		for index, info in ipairs(icons) do
			---@type ReadyCheckIcon
			local icon = iconPool:Acquire()
			local isClickable = info.useLocation ~= nil

			icon.tooltipItemID = info.itemID
			icon.tooltipSpellID = info.spellID
			icon.expirationTime = info.expirationTime
			icon.Icon:SetTexture(
				info.itemID and C_Item.GetItemIconByID(info.itemID) or C_Spell.GetSpellTexture(info.spellID)
			)
			icon.Icon:SetDesaturated(not info.isActive)
			icon.Overlay.ReadyMark:SetShown(info.isActive)
			icon:GetHighlightTexture():SetAlpha(isClickable and 1 or 0)

			-- Bag and slot rather than an item name, which would match every quality rank. SecureCmdItemParse
			-- resolves it to C_Container.UseContainerItem.
			icon:SetAttribute("type", isClickable and "item" or nil)
			icon:SetAttribute("item", info.useLocation)
			icon:SetAttribute("target-slot", info.targetSlot)
			icon:Show()

			shownIcons[index] = icon
		end

		Layout()
		UpdateCountdowns()
	end

	-- Closes the panel once nothing is left to fix, whether a trigger finds it so or the last icon just turned green.
	local function Refresh()
		if InCombatLockdown() then
			return
		end

		local icons = CollectIcons()

		if IsEverythingReady(icons) then
			panel:Hide()
			return
		end

		panel:Show()
		Render(icons)
	end

	local function QueueRefresh()
		if isRefreshQueued then
			return
		end

		isRefreshQueued = true

		RunNextFrame(function()
			isRefreshQueued = false

			if panel:IsShown() then
				Refresh()
			end
		end)
	end

	---@param icon ReadyCheckIcon
	local function InitializeIcon(icon)
		-- With both edges registered, SecureActionButton_OnClick acts on whichever one ActionButtonUseKeyDown asks for.
		icon:RegisterForClicks("AnyUp", "AnyDown")

		icon.Border = CreatePixelBorder(icon)
		icon.Border:SetFrameLevel(icon:GetFrameLevel() + 1)
		icon.Overlay:SetFrameLevel(icon:GetFrameLevel() + 2)
		icon.Overlay.Timer:SetFont(GetFont(), TIMER_FONT_SIZE, "OUTLINE")
		icon.Overlay.Timer:SetTextColor(1, 1, 1, 1)

		icon:SetScript("OnEnter", function()
			GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")

			if icon.tooltipItemID then
				GameTooltip:SetItemByID(icon.tooltipItemID)
			else
				GameTooltip:SetSpellByID(icon.tooltipSpellID)
			end

			GameTooltip:Show()
		end)

		icon:SetScript("OnLeave", GameTooltip_Hide)
	end

	iconPool = CreateFramePool("Button", panel, "XephUIReadyCheckIconTemplate", nil, false, InitializeIcon)

	-- The queued refresh covers coming back from a hidden UIParent, which unregistered the events in between.
	panel:SetScript("OnShow", function()
		FrameUtil.RegisterFrameForEvents(panel, liveEvents)
		countdownTicker = C_Timer.NewTicker(1, UpdateCountdowns)
		QueueRefresh()
	end)

	panel:SetScript("OnHide", function()
		FrameUtil.UnregisterFrameForEvents(panel, liveEvents)
		countdownTicker:Cancel()
		countdownTicker = nil
	end)

	panel:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" and not auraUnits[unit] then
			return
		end

		QueueRefresh()
	end)

	local function OnPixelScaleChanged()
		if not panel:IsShown() or InCombatLockdown() then
			return
		end

		Layout()
	end

	EventRegistry:RegisterFrameEventAndCallback("UI_SCALE_CHANGED", OnPixelScaleChanged, panel)
	EventRegistry:RegisterFrameEventAndCallback("DISPLAY_SIZE_CHANGED", OnPixelScaleChanged, panel)

	local function ShowPanel()
		if not CanShow() then
			return
		end

		Refresh()
	end

	local function HidePanel()
		if not panel:IsShown() or InCombatLockdown() then
			return
		end

		panel:Hide()
	end

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("LOADING_SCREEN_DISABLED")
	eventFrame:RegisterEvent("READY_CHECK")
	eventFrame:RegisterEvent("CHALLENGE_MODE_START")
	-- Dispatched before combat lockdown starts, which is the last chance to hide a parent of secure buttons.
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

	eventFrame:SetScript("OnEvent", function(_, event)
		if event == "READY_CHECK" then
			ShowPanel()
			return
		end

		if event ~= "LOADING_SCREEN_DISABLED" then
			HidePanel()
			return
		end

		if showTimer then
			showTimer:Cancel()
		end

		showTimer = C_Timer.NewTimer(INSTANCE_SETTLE_SECONDS, function()
			RememberDungeon()

			if not IsInMythicDungeon() then
				showTimer = nil
				HidePanel()
				return
			end

			showTimer = C_Timer.NewTimer(SHOW_DELAY_SECONDS - INSTANCE_SETTLE_SECONDS, function()
				showTimer = nil
				ShowPanel()
			end)
		end)
	end)
end)
