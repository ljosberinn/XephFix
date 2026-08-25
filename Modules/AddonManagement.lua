local addonName, Private = ...

local ContentType = {
	OpenWorld = 1,
	Delve = 2,
	Dungeon = 3,
	Raid = 4,
	Arena = 5,
	Battleground = 6,
}

local CONTENT_TYPE_ORDER = {
	ContentType.OpenWorld,
	ContentType.Delve,
	ContentType.Dungeon,
	ContentType.Raid,
	ContentType.Arena,
	ContentType.Battleground,
}

local CONTENT_TYPE_LABELS = {
	[ContentType.OpenWorld] = "Open World",
	[ContentType.Delve] = "Delves",
	[ContentType.Dungeon] = "Dungeon",
	[ContentType.Raid] = "Raid",
	[ContentType.Arena] = "Arena",
	[ContentType.Battleground] = "Battleground",
}

-- Assigned once the settings category exists.
local OpenSettings

-- Separate key because XephUISaved.AddonManagement is the boolean module toggle.
---@return table
local function GetDatabase()
	local database = XephUISaved.AddonManagementDB or {}

	database.NextProfileId = database.NextProfileId or 1
	database.Profiles = database.Profiles or {}
	database.KnownCharacters = database.KnownCharacters or {}
	database.ActiveProfile = database.ActiveProfile or {}

	XephUISaved.AddonManagementDB = database

	return database
end

---@return string
local function GetCharacterKey()
	local characterName, realmName = UnitFullName("player")

	if realmName == nil or realmName == "" then
		realmName = GetNormalizedRealmName()
	end

	return characterName .. "-" .. realmName
end

local function RecordCharacter()
	GetDatabase().KnownCharacters[GetCharacterKey()] = select(2, UnitClass("player"))
end

---@param profileId number
---@return table? profile, number? index
local function FindProfileById(profileId)
	for index, profile in ipairs(GetDatabase().Profiles) do
		if profile.Id == profileId then
			return profile, index
		end
	end

	return nil, nil
end

---@param name string
---@param exceptProfileId number?
---@return boolean
local function IsNameAvailable(name, exceptProfileId)
	if name == "" then
		return false
	end

	for _, profile in ipairs(GetDatabase().Profiles) do
		if profile.Name == name and profile.Id ~= exceptProfileId then
			return false
		end
	end

	return true
end

---@param name string
---@return table
local function CreateProfile(name)
	local database = GetDatabase()
	local profile = {
		Id = database.NextProfileId,
		Name = name,
		Addons = {},
		ContentTypes = {},
		Characters = { [GetCharacterKey()] = true },
	}

	database.NextProfileId = database.NextProfileId + 1
	table.insert(database.Profiles, profile)

	return profile
end

---@param profileId number
---@param name string
local function RenameProfile(profileId, name)
	local profile = FindProfileById(profileId)

	if not profile then
		return
	end

	profile.Name = name
end

---@param profileId number
local function DeleteProfile(profileId)
	local database = GetDatabase()
	local _, index = FindProfileById(profileId)

	if not index then
		return
	end

	table.remove(database.Profiles, index)

	for characterKey, activeProfileId in pairs(database.ActiveProfile) do
		if activeProfileId == profileId then
			database.ActiveProfile[characterKey] = nil
		end
	end
end

---@return table?
local function GetActiveProfile()
	local profileId = GetDatabase().ActiveProfile[GetCharacterKey()]

	if not profileId then
		return nil
	end

	return (FindProfileById(profileId))
end

---@param name string
---@return boolean
local function IsManagedAddon(name)
	return not string.find(name, "^Blizzard_") and name ~= addonName
end

---@return table[]
local function GetManagedAddons()
	local addons = {}

	for index = 1, C_AddOns.GetNumAddOns() do
		local name, title = C_AddOns.GetAddOnInfo(index)

		if IsManagedAddon(name) then
			table.insert(addons, { name = name, title = (title ~= nil and title ~= "") and title or name })
		end
	end

	-- Sorted by folder name because titles carry colour escapes.
	table.sort(addons, function(left, right)
		return left.name < right.name
	end)

	return addons
end

---@param profile table
local function ApplyProfile(profile)
	local characterName = UnitName("player")

	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(index)

		if IsManagedAddon(name) then
			if profile.Addons[name] then
				C_AddOns.EnableAddOn(name, characterName)
			else
				C_AddOns.DisableAddOn(name, characterName)
			end
		end
	end

	-- Disabling the host would strand the profile UI with no way back in game.
	C_AddOns.EnableAddOn(addonName, characterName)
	C_AddOns.SaveAddOns()

	GetDatabase().ActiveProfile[GetCharacterKey()] = profile.Id

	ReloadUI()
end

local MULTI_SELECT_SCROLL_EXTENT = 400

XephUIMultiSelectDropdownControlMixin = CreateFromMixins(SettingsDropdownControlMixin)

function XephUIMultiSelectDropdownControlMixin:OnLoad()
	-- Steppers only make sense for single-selection dropdowns.
	self.forceSteppersHidden = true

	SettingsDropdownControlMixin.OnLoad(self)
end

function XephUIMultiSelectDropdownControlMixin:SetupDropdownMenu(_, _, _, _, initializer)
	local dropdown = self.Control.Dropdown

	dropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetScrollMode(MULTI_SELECT_SCROLL_EXTENT)
		initializer.data.buildMenu(rootDescription)
		dropdown:OverrideText(initializer.data.getSummary())
	end)

	dropdown:OverrideText(initializer.data.getSummary())
end

---@param setting table
---@param buildMenu fun(rootDescription: table)
---@param getSummary fun(): string
---@return table
local function CreateMultiSelectInitializer(setting, buildMenu, getSummary)
	-- Options stay empty; the menu is built by buildMenu instead of the option inserter.
	local initializer = Settings.CreateControlInitializer("XephUIMultiSelectDropdownControlTemplate", setting, {}, nil)

	initializer.data.buildMenu = buildMenu
	initializer.data.getSummary = getSummary

	return initializer
end

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AddonManagement then
		return
	end

	RecordCharacter()

	SLASH_XEPHUI1 = "/xephui"

	SlashCmdList["XEPHUI"] = function(argument)
		local name = strtrim(argument)

		if name == "" then
			OpenSettings()
			return
		end

		for _, profile in ipairs(GetDatabase().Profiles) do
			if profile.Name == name then
				ApplyProfile(profile)
				return
			end
		end

		print('|cff33ff99XephUI|r: no profile named "' .. name .. '". Available:')

		for _, profile in ipairs(GetDatabase().Profiles) do
			print(" - " .. profile.Name)
		end
	end
end)
