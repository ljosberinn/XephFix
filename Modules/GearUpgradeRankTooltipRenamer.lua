local addonName, Private = ...

-- Gear Upgrade Rank Tooltip Renamer
local CRESTS = {
	[0] = { shortName = "Adventurer", color = HEIRLOOM_BLUE_COLOR, achievement = 61809 },
	[1] = { shortName = "Veteran", color = UNCOMMON_GREEN_COLOR, achievement = 42767 },
	[2] = { shortName = "Champion", color = RARE_BLUE_COLOR, achievement = 42768 },
	[3] = { shortName = "Hero", color = ITEM_EPIC_COLOR, achievement = 42769 },
	[4] = { shortName = "Myth", color = ITEM_LEGENDARY_COLOR, achievement = 42770 },
}

-- Upgrade tiers with crest change points
-- ([i]=CRESTS[x]) where i = the upgrade level where crest type changes
-- i=4 means to upgrade from rank 4 to the next rank.
local UPGRADE_TIERS = {
	{
		name = "Adventurer",
		minIlvl = 220,
		maxIlvl = 237,
		maxUpgrade = 6,
		color = WHITE_FONT_COLOR,
	},
	{
		name = "Veteran",
		minIlvl = 233,
		maxIlvl = 250,
		maxUpgrade = 6,
		color = UNCOMMON_GREEN_COLOR,
	},
	{
		name = "Champion",
		minIlvl = 246,
		maxIlvl = 263,
		maxUpgrade = 6,
		color = RARE_BLUE_COLOR,
	},
	{
		name = "Hero",
		minIlvl = 259,
		maxIlvl = 276,
		maxUpgrade = 6,
		color = ITEM_EPIC_COLOR,
	},
	{
		name = "Myth",
		minIlvl = 272,
		maxIlvl = 289,
		maxUpgrade = 6,
		color = ITEM_LEGENDARY_COLOR,
	},
}

-- Get tier data based on item level and upgrade level
---@param ilvl number
---@param current number
---@param total number
local function GetUpgradeTierData(ilvl, current, total)
	for _, tier in ipairs(UPGRADE_TIERS) do
		if ilvl >= tier.minIlvl and ilvl <= tier.maxIlvl and total == tier.maxUpgrade then
			-- Calculate expected ilvl for current upgrade level
			local step = (tier.maxIlvl - tier.minIlvl) / (tier.maxUpgrade - 1)
			local expectedIlvl = tier.minIlvl + (current - 1) * step
			local diff = math.abs(ilvl - expectedIlvl)

			if diff <= step then
				return {
					name = tier.name, -- english name
					minIlvl = tier.minIlvl,
					maxIlvl = tier.maxIlvl,
					color = tier.color,
				}
			end
		end
	end

	return nil
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
	local _, itemLink = TooltipUtil.GetDisplayedItem(tooltip)

	if not itemLink then
		return
	end

	--Create ItemMixin from itemLink
	local item = Item:CreateFromItemLink(itemLink)

	if item:IsItemEmpty() then
		return
	end

	local itemLevel = item:GetCurrentItemLevel()

	-- Loop over current tooltip lines
	for i = 1, tooltip:NumLines() do
		local line = _G[tooltip:GetName() .. "TextLeft" .. i]
		local text = line:GetText()

		if
			text
			and not issecretvalue(text)
			and text:match(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING:gsub("%%s %%d/%%d", "(%%D+ %%d+/%%d+)"))
		then
			local tier, current, total =
				text:match(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING:gsub("%%s %%d/%%d", "(%%D+) (%%d+)/(%%d+)"))

			local tierData = GetUpgradeTierData(tonumber(itemLevel), tonumber(current), tonumber(total))

			if not tierData then
				return
			end

			-- Modify Upgrade Rank tooltip line
			local minIlvl = tierData.minIlvl
			local maxIlvl = tierData.maxIlvl
			if minIlvl and maxIlvl and itemLevel >= minIlvl and itemLevel <= maxIlvl then
				local tierHexColorMarkup = tierData.color:GenerateHexColorMarkup()
				local rangeHexColorMarkup = CreateColor(157 / 256, 157 / 256, 157 / 256):GenerateHexColorMarkup()

				local newLineText = string.format(
					"%s%d/%d %s|r %s(%d-%d)|r",
					tierHexColorMarkup,
					current,
					total,
					tier,
					rangeHexColorMarkup,
					minIlvl,
					maxIlvl
				)

				line:SetText(newLineText)
				line:Show()
			end
		end
	end
end)
