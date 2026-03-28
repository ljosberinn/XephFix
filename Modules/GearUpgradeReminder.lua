local addonName, Private = ...

-- https://www.raidbots.com/static/data/xptr/bonuses.json
-- copy(JSON.stringify(Object.values(JSON.parse($0.textContent)).filter(x => x.upgrade?.seasonId === 34).reduce((acc, data) => {
--     acc[data.id] = data.upgrade.name
--     return acc
-- }, {})))

local bonusToTierMap = {
	[12769] = "Adventurer",
	[12770] = "Adventurer",
	[12771] = "Adventurer",
	[12772] = "Adventurer",
	[12773] = "Adventurer",
	[12774] = "Adventurer",
	[12777] = "Veteran",
	[12778] = "Veteran",
	[12779] = "Veteran",
	[12780] = "Veteran",
	[12781] = "Veteran",
	[12782] = "Veteran",
	[12785] = "Champion",
	[12786] = "Champion",
	[12787] = "Champion",
	[12788] = "Champion",
	[12789] = "Champion",
	[12790] = "Champion",
	[12793] = "Hero",
	[12794] = "Hero",
	[12795] = "Hero",
	[12796] = "Hero",
	[12797] = "Hero",
	[12798] = "Hero",
	[12801] = "Myth",
	[12802] = "Myth",
	[12803] = "Myth",
	[12804] = "Myth",
	[12805] = "Myth",
	[12806] = "Myth",
}
-- copy(JSON.stringify(Object.values(JSON.parse($0.textContent)).filter(x => x.upgrade?.seasonId === 34).reduce((acc, data) => {
--     const [tier] = data.upgrade.fullName.split(' ')
--     if (acc[tier]) {
--         if (data.upgrade.itemLevel > acc[tier].max) {
--             acc[tier].max = data.upgrade.itemLevel
--         } else if (data.upgrade.itemLevel < acc[tier].min) {
--             acc[tier].min = data.upgrade.itemLevel
--         }
--     } else {
--         acc[tier] = {
--             min: data.upgrade.itemLevel,
--             max: data.upgrade.itemLevel,
--         }
--     }

--     return acc
-- }, {})).replaceAll(':', '=').replaceAll('"', ''))

local tiers = {
	Adventurer = { min = 220, max = 237 },
	Veteran = { min = 233, max = 250 },
	Champion = { min = 246, max = 263 },
	Hero = { min = 259, max = 276 },
	Myth = { min = 272, max = 289 },
}

local craftedBonusIds = {
	[12066] = true, -- Radiance Crafted
	-- https://wago.tools/db2/ItemBonus?filter%5BValue_2%5D=2061%7C2062%7C2063&page=1
	-- presumably 15587?
}

local function GetUpgradeTrack(bonusIds)
	for i = 1, #bonusIds do
		local id = tonumber(bonusIds[i])

		if craftedBonusIds[id] ~= nil then
			return
		end

		local key = bonusToTierMap[id]

		if key then
			return tiers[key]
		end
	end
end

local function GetBonusIds(link)
	local itemString = string.match(link, "item:([%-?%d:]+)")
	if not itemString then
		return {}
	end

	local bonuses = {}
	local itemSplit = {}

	for v in string.gmatch(itemString, "(%d*:?)") do
		if v == ":" then
			itemSplit[#itemSplit + 1] = 0
		else
			itemSplit[#itemSplit + 1] = string.gsub(v, ":", "")
		end
	end

	for index = 1, tonumber(itemSplit[13]) do
		bonuses[#bonuses + 1] = itemSplit[13 + index]
	end

	return bonuses
end

---@type table<number, string>
local reportedUpgrades = {}

local function OnUpdate()
	local itemSlots = {
		INVSLOT_HEAD,
		INVSLOT_NECK,
		INVSLOT_SHOULDER,
		INVSLOT_CHEST,
		INVSLOT_WAIST,
		INVSLOT_LEGS,
		INVSLOT_FEET,
		INVSLOT_WRIST,
		INVSLOT_HAND,
		INVSLOT_FINGER1,
		INVSLOT_FINGER2,
		INVSLOT_TRINKET1,
		INVSLOT_TRINKET2,
		INVSLOT_BACK,
		INVSLOT_MAINHAND,
		INVSLOT_OFFHAND,
	}

	for i = 1, #itemSlots do
		local slot = itemSlots[i]
		local itemLoc = ItemLocation:CreateFromEquipmentSlot(slot)

		if itemLoc:IsValid() then
			local currentItemLevel = C_Item.GetCurrentItemLevel(itemLoc)

			if currentItemLevel >= tiers.Adventurer.min then
				local itemLink = C_Item.GetItemLink(itemLoc)

				if itemLink then
					local bonusIds = GetBonusIds(itemLink)
					local upgradeTrack = GetUpgradeTrack(bonusIds)

					if upgradeTrack and currentItemLevel < upgradeTrack.max then
						local redundancySlot = slot == INVSLOT_OFFHAND and Enum.ItemRedundancySlot.Offhand
							or C_ItemUpgrade.GetHighWatermarkSlotForItem(C_Item.GetItemID(itemLoc))

						local characterWatermark, accountWatermark =
							C_ItemUpgrade.GetHighWatermarkForSlot(redundancySlot)

						local watermark = characterWatermark < accountWatermark and characterWatermark
							or accountWatermark

						local finalIlvlToCompareWith = upgradeTrack.max < watermark and upgradeTrack.max or watermark

						if currentItemLevel < finalIlvlToCompareWith and reportedUpgrades[slot] ~= itemLink then
							reportedUpgrades[slot] = itemLink
							print(
								string.format(
									"%s can be upgraded to item level %d without using crests!",
									itemLink,
									finalIlvlToCompareWith
								)
							)
						end
					end
				end
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", OnUpdate)
