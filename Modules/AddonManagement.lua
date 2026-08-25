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

StaticPopupDialogs["XEPHUI_ADDON_PROFILE_NAME"] = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	OnShow = function(dialog, data)
		dialog:SetText(data.text)
		dialog:GetEditBox():SetText(data.name or "")
		dialog:GetEditBox():HighlightText()
	end,
	OnAccept = function(dialog, data)
		data.callback(strtrim(dialog:GetEditBox():GetText()))
	end,
	EditBoxOnEnterPressed = function(editBox, data)
		local dialog = editBox:GetParent()

		if not dialog:GetButton1():IsEnabled() then
			return
		end

		data.callback(strtrim(editBox:GetText()))
		dialog:Hide()
	end,
	EditBoxOnTextChanged = StaticPopup_StandardNonEmptyTextHandler,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

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

---@param contentTypes table<number, boolean>
---@return number
local function ContentTypesToMask(contentTypes)
	local mask = 0

	for value in pairs(contentTypes) do
		mask = bit.bor(mask, bit.lshift(1, value - 1))
	end

	return mask
end

---@param mask number
---@param contentTypes table<number, boolean>
local function ApplyMaskToContentTypes(mask, contentTypes)
	table.wipe(contentTypes)

	for _, value in ipairs(CONTENT_TYPE_ORDER) do
		if bit.band(mask, bit.lshift(1, value - 1)) ~= 0 then
			contentTypes[value] = true
		end
	end
end

local PANEL_TITLE = "XephUI Addon Management"
local NO_PROFILE_LABEL = "No profile"
local NONE_SELECTED_LABEL = "None"

local editingProfileId
local settingsCategory

---@return table?
local function GetEditingProfile()
	if not editingProfileId then
		return nil
	end

	return (FindProfileById(editingProfileId))
end

local function RefreshPanel()
	Settings.NotifyUpdate("XephUIAddonManagementProfile")
	Settings.NotifyUpdate("XephUIAddonManagementAddons")
	Settings.NotifyUpdate("XephUIAddonManagementCharacters")
	Settings.NotifyUpdate("XephUIAddonManagementContentTypes")
end

---@param selected table<string, boolean>
---@param total number
---@return string
local function SummariseSelection(selected, total)
	local count = 0

	for _ in pairs(selected) do
		count = count + 1
	end

	if count == 0 then
		return NONE_SELECTED_LABEL
	end

	return count .. " / " .. total
end

---@param characterKey string
---@param className string?
---@return string
local function GetCharacterLabel(characterKey, className)
	local color = className and C_ClassColor.GetClassColor(className)

	if not color then
		return characterKey
	end

	return color:WrapTextInColorCode(characterKey)
end

local FOLLOWER_DUNGEON_DIFFICULTY_ID = 205
local DELVE_DIFFICULTY_ID = 208

---@param instanceType string
---@param difficultyId number
---@return number
local function ResolveContentType(instanceType, difficultyId)
	if instanceType == "raid" then
		return ContentType.Raid
	end

	if
		instanceType == "party"
		and (
			difficultyId == DifficultyUtil.ID.DungeonTimewalker
			or difficultyId == DifficultyUtil.ID.DungeonNormal
			or difficultyId == DifficultyUtil.ID.DungeonHeroic
			or difficultyId == DifficultyUtil.ID.DungeonMythic
			or difficultyId == DifficultyUtil.ID.DungeonChallenge
			or difficultyId == FOLLOWER_DUNGEON_DIFFICULTY_ID
		)
	then
		return ContentType.Dungeon
	end

	if instanceType == "pvp" then
		return ContentType.Battleground
	end

	if instanceType == "arena" then
		return ContentType.Arena
	end

	if instanceType == "scenario" and difficultyId == DELVE_DIFFICULTY_ID then
		return ContentType.Delve
	end

	return ContentType.OpenWorld
end

local lastContentType

---@param contentType number
---@return table[]
local function GetCandidateProfiles(contentType)
	local characterKey = GetCharacterKey()
	local candidates = {}

	for _, profile in ipairs(GetDatabase().Profiles) do
		if profile.ContentTypes[contentType] and profile.Characters[characterKey] then
			table.insert(candidates, profile)
		end
	end

	return candidates
end

local function EvaluateContentType()
	local _, instanceType, difficultyId = GetInstanceInfo()
	local contentType = ResolveContentType(instanceType, difficultyId)

	-- Only a change may prompt, which is also what makes a dismissal stick.
	if contentType == lastContentType then
		return
	end

	lastContentType = contentType

	local activeProfile = GetActiveProfile()

	if activeProfile and activeProfile.ContentTypes[contentType] then
		return
	end

	local candidates = GetCandidateProfiles(contentType)

	if #candidates == 0 then
		return
	end

	local options = {}

	for _, profile in ipairs(candidates) do
		table.insert(options, { text = profile.Name, value = profile.Id })
	end

	StaticPopup_ShowGenericDropdown(
		"Content changed to " .. CONTENT_TYPE_LABELS[contentType] .. ". Switch addon profile and reload?",
		function(profileId)
			local profile = FindProfileById(profileId)

			if not profile then
				return
			end

			ApplyProfile(profile)
		end,
		options,
		true,
		options[1].value
	)
end

local function BuildSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory(PANEL_TITLE)

	settingsCategory = category

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Profiles"))

	local profileSetting = Settings.RegisterProxySetting(
		category,
		"XephUIAddonManagementProfile",
		Settings.VarType.Number,
		"Profile",
		0,
		function()
			return editingProfileId or 0
		end,
		function(value)
			editingProfileId = value ~= 0 and value or nil
			RefreshPanel()
		end
	)

	Settings.CreateDropdown(category, profileSetting, function()
		local container = Settings.CreateControlTextContainer()
		local profiles = GetDatabase().Profiles

		if #profiles == 0 then
			container:Add(0, NO_PROFILE_LABEL)
		end

		for _, profile in ipairs(profiles) do
			container:Add(profile.Id, profile.Name)
		end

		return container:GetData()
	end, "Profile edited below. Selecting a profile here does not apply it.")

	layout:AddInitializer(CreateSettingsButtonInitializer("", "New Profile", function()
		StaticPopup_Show("XEPHUI_ADDON_PROFILE_NAME", nil, nil, {
			text = "Name the new profile.",
			callback = function(name)
				if not IsNameAvailable(name, nil) then
					return
				end

				editingProfileId = CreateProfile(name).Id
				RefreshPanel()
			end,
		})
	end, "Creates an empty profile containing the current character."))

	layout:AddInitializer(CreateSettingsButtonInitializer("", "Rename Profile", function()
		local profile = GetEditingProfile()

		if not profile then
			return
		end

		StaticPopup_Show("XEPHUI_ADDON_PROFILE_NAME", nil, nil, {
			text = "Rename this profile.",
			name = profile.Name,
			callback = function(name)
				if not IsNameAvailable(name, profile.Id) then
					return
				end

				RenameProfile(profile.Id, name)
				RefreshPanel()
			end,
		})
	end))

	layout:AddInitializer(CreateSettingsButtonInitializer("", "Delete Profile", function()
		local profile = GetEditingProfile()

		if not profile then
			return
		end

		StaticPopup_ShowCustomGenericConfirmation({
			text = 'Delete the profile "' .. profile.Name .. '"?',
			callback = function()
				DeleteProfile(profile.Id)
				editingProfileId = nil
				RefreshPanel()
			end,
		})
	end))

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Profile Contents"))

	local addonsSetting = Settings.RegisterProxySetting(
		category,
		"XephUIAddonManagementAddons",
		Settings.VarType.Number,
		"Addons",
		0,
		function()
			return editingProfileId or 0
		end,
		function() end
	)

	layout:AddInitializer(CreateMultiSelectInitializer(addonsSetting, function(rootDescription)
		local profile = GetEditingProfile()

		if not profile then
			return
		end

		for _, addon in ipairs(GetManagedAddons()) do
			rootDescription:CreateCheckbox(addon.title, function()
				return profile.Addons[addon.name] == true
			end, function()
				profile.Addons[addon.name] = not profile.Addons[addon.name] or nil
			end)
		end
	end, function()
		local profile = GetEditingProfile()

		if not profile then
			return NONE_SELECTED_LABEL
		end

		return SummariseSelection(profile.Addons, #GetManagedAddons())
	end))

	local charactersSetting = Settings.RegisterProxySetting(
		category,
		"XephUIAddonManagementCharacters",
		Settings.VarType.Number,
		"Characters",
		0,
		function()
			return editingProfileId or 0
		end,
		function() end
	)

	layout:AddInitializer(CreateMultiSelectInitializer(charactersSetting, function(rootDescription)
		local profile = GetEditingProfile()

		if not profile then
			return
		end

		local characterKeys = GetKeysArray(GetDatabase().KnownCharacters)
		table.sort(characterKeys)

		for _, characterKey in ipairs(characterKeys) do
			local label = GetCharacterLabel(characterKey, GetDatabase().KnownCharacters[characterKey])

			rootDescription:CreateCheckbox(label, function()
				return profile.Characters[characterKey] == true
			end, function()
				profile.Characters[characterKey] = not profile.Characters[characterKey] or nil
			end)
		end
	end, function()
		local profile = GetEditingProfile()

		if not profile then
			return NONE_SELECTED_LABEL
		end

		local total = 0

		for _ in pairs(GetDatabase().KnownCharacters) do
			total = total + 1
		end

		return SummariseSelection(profile.Characters, total)
	end))

	local contentTypesSetting = Settings.RegisterProxySetting(
		category,
		"XephUIAddonManagementContentTypes",
		Settings.VarType.Number,
		"Content Types",
		0,
		function()
			local profile = GetEditingProfile()

			if not profile then
				return 0
			end

			return ContentTypesToMask(profile.ContentTypes)
		end,
		function(mask)
			local profile = GetEditingProfile()

			if not profile then
				return
			end

			ApplyMaskToContentTypes(mask, profile.ContentTypes)
		end
	)

	Settings.CreateDropdown(category, contentTypesSetting, function()
		local container = Settings.CreateControlTextContainer()

		for _, value in ipairs(CONTENT_TYPE_ORDER) do
			container:AddCheckbox(value, CONTENT_TYPE_LABELS[value])
		end

		return container:GetData()
	end, "Content this profile is offered for.")

	Settings.RegisterAddOnCategory(category)
end

OpenSettings = function()
	if not settingsCategory then
		return
	end

	Settings.OpenToCategory(settingsCategory:GetID())
end

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AddonManagement then
		return
	end

	RecordCharacter()

	BuildSettings()

	EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", EvaluateContentType)
	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", EvaluateContentType)

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
