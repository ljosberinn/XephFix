local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.ChatItemEnhancements then
		return
	end

	local ICON_SIZE = 12
	local CURRENCY_LINK_PATTERN = "(|Hcurrency:(%d+)[^|]*|h%[[^%]]+%]|h%|r)"
	local ITEM_LINK_PATTERN = "|Hitem:.-|h%[.-%]|h|r"

	---@param texture integer|string|nil
	---@param link string
	---@return string
	local function AppendIcon(texture, link)
		if not texture then
			return link
		end

		return string.format("|T%s:%d|t%s", texture, ICON_SIZE, link)
	end

	---@param link string
	---@return integer|string|nil
	local function GetItemTexture(link)
		local itemID = link:match("item:(%d+)")

		if itemID then
			return C_Item.GetItemIconByID(tonumber(itemID))
		end

		return nil
	end

	---@param link string
	---@return integer|nil level, string|nil equipLoc
	local function GetItemLevelAndEquipLoc(link)
		local level = C_Item.GetDetailedItemLevelInfo(link)
		local _, _, _, baseLevel, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(link)

		if not level or level == 0 then
			level = baseLevel
		end

		if level and level > 0 then
			return level, itemEquipLoc
		end

		return nil, itemEquipLoc
	end

	---@param link string
	---@return string
	local function FormatItemLinkWithLevel(link)
		local prefix, label, suffix = link:match("^(|Hitem:[^|]+|h)%[(.-)%](|h|r)$")

		if not prefix or not label or not suffix then
			return link
		end

		local level, equipLoc = GetItemLevelAndEquipLoc(link)

		if not level then
			return link
		end

		if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
			return link
		end

		---@type string[]
		local parts = {}

		if _G[equipLoc] then
			parts[#parts + 1] = _G[equipLoc]
		end

		parts[#parts + 1] = tostring(level)

		return string.format("%s[%s (%s)]%s", prefix, label, table.concat(parts, " "), suffix)
	end

	---@param link string
	---@return string
	local function FormatItemLink(link)
		return AppendIcon(GetItemTexture(link), link)
	end

	---@param link string
	---@param id string
	---@return string
	local function FormatCurrencyLink(link, id)
		local idNum = tonumber(id)
		if not idNum then
			return link
		end

		local info = C_CurrencyInfo.GetCurrencyInfo(idNum)
		local texture = info and (info.iconFileID or info.icon)

		return AppendIcon(texture, link)
	end

	---@param _ ChatFrame
	---@param event WowEvent
	---@param message string
	---@return boolean?, string?, ...
	local function FilterChatMessage(_, event, message, ...)
		if issecretvalue and issecretvalue(message) then
			return
		end

		if type(message) ~= "string" or message == "" then
			return false
		end

		message = message:gsub(ITEM_LINK_PATTERN, function(link)
			link = FormatItemLinkWithLevel(link)
			return FormatItemLink(link)
		end)

		if event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_CURRENCY" then
			message = message:gsub(CURRENCY_LINK_PATTERN, FormatCurrencyLink)
		end

		return false, message, ...
	end

	for _, event in ipairs({
		"CHAT_MSG_LOOT",
		"CHAT_MSG_CURRENCY",
		"CHAT_MSG_CHANNEL",
		"CHAT_MSG_COMMUNITIES_CHANNEL",
		"CHAT_MSG_SAY",
		"CHAT_MSG_YELL",
		"CHAT_MSG_WHISPER",
		"CHAT_MSG_WHISPER_INFORM",
		"CHAT_MSG_BN_WHISPER",
		"CHAT_MSG_BN_WHISPER_INFORM",
		"CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"CHAT_MSG_BATTLEGROUND",
		"CHAT_MSG_BATTLEGROUND_LEADER",
		"CHAT_MSG_EMOTE",
		"CHAT_MSG_TEXT_EMOTE",
		"CHAT_MSG_SYSTEM",
		"CHAT_MSG_ACHIEVEMENT",
		"CHAT_MSG_GUILD_ACHIEVEMENT",
		"CHAT_MSG_GUILD_ITEM_LOOTED",
	}) do
		ChatFrameUtil.AddMessageEventFilter(event, FilterChatMessage)
	end
end)
