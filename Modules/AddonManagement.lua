local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AddonManagement then
		return
	end

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
	---@return boolean
	local function DoesProfileMatchLoadedAddons(profile)
		for index = 1, C_AddOns.GetNumAddOns() do
			local name = C_AddOns.GetAddOnInfo(index)

			if IsManagedAddon(name) and not C_AddOns.IsAddOnLoadOnDemand(name) then
				if (profile.Addons[name] == true) ~= C_AddOns.IsAddOnLoaded(name) then
					return false
				end
			end
		end

		return true
	end

	---@param profile table
	local function ApplyProfile(profile)
		-- C_AddOns.EnableAddOn/DisableAddOn take the player's GUID, not their name; see Blizzard_AddonList/AddonList.lua's addonCharacter.
		local characterGuid = UnitGUID("player")

		for index = 1, C_AddOns.GetNumAddOns() do
			local name = C_AddOns.GetAddOnInfo(index)

			if IsManagedAddon(name) then
				if profile.Addons[name] then
					C_AddOns.EnableAddOn(name, characterGuid)
				else
					C_AddOns.DisableAddOn(name, characterGuid)
				end
			end
		end

		-- Disabling the host would strand the profile UI with no way back in game.
		C_AddOns.EnableAddOn(addonName, characterGuid)
		C_AddOns.SaveAddOns()

		GetDatabase().ActiveProfile[GetCharacterKey()] = profile.Id

		ReloadUI()
	end

	StaticPopupDialogs["XEPHUI_ADDON_PROFILE_NAME"] = {
		-- Empty, not "%s": OnShow supplies the text directly, as GENERIC_INPUT_BOX/GENERIC_DROP_DOWN do.
		text = "",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = 1,
		OnShow = function(dialog, data)
			dialog:SetText(data.text)
			dialog:GetEditBox():SetText(data.name or "")
			dialog:GetEditBox():HighlightText()

			-- SetupStartDelay unconditionally enables button 1, and OnHide already cleared the edit box, so SetText above fires no OnTextChanged to correct it.
			StaticPopup_StandardNonEmptyTextHandler(dialog:GetEditBox())
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
		self.forceSteppersHidden = true

		SettingsDropdownControlMixin.OnLoad(self)
	end

	function XephUIMultiSelectDropdownControlMixin:SetupDropdownMenu(_, _, _, _, initializer)
		local dropdown = self.Control.Dropdown

		dropdown:SetupMenu(function(_, rootDescription)
			rootDescription:SetScrollMode(MULTI_SELECT_SCROLL_EXTENT)
			initializer.data.buildMenu(rootDescription)
		end)
	end

	---@param setting table
	---@param buildMenu fun(rootDescription: table)
	---@param getSummary fun(): string
	---@return table
	local function CreateMultiSelectInitializer(setting, buildMenu, getSummary)
		local initializer =
			Settings.CreateControlInitializer("XephUIMultiSelectDropdownControlTemplate", setting, {}, nil)

		initializer.data.buildMenu = buildMenu
		initializer.getSelectionTextFunc = getSummary

		return initializer
	end

	local NONE_SELECTED_LABEL = NONE

	local editingProfileId
	local settingsCategory

	---@return table?
	local function GetEditingProfile()
		if not editingProfileId then
			return nil
		end

		return (FindProfileById(editingProfileId))
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

	-- Neither ID has a DifficultyUtil.ID constant; both are observed values with no verifiable Blizzard source.
	local FOLLOWER_DUNGEON_DIFFICULTY_ID = 205
	local DELVE_DIFFICULTY_ID = 208

	local lastContentType

	local function EvaluateContentType()
		local _, instanceType, difficultyId = GetInstanceInfo()
		local contentType = ContentType.OpenWorld

		if instanceType == "raid" then
			contentType = ContentType.Raid
		elseif
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
			contentType = ContentType.Dungeon
		elseif instanceType == "pvp" then
			contentType = ContentType.Battleground
		elseif instanceType == "arena" then
			contentType = ContentType.Arena
		elseif instanceType == "scenario" and difficultyId == DELVE_DIFFICULTY_ID then
			contentType = ContentType.Delve
		end

		-- Only a change may prompt, which is also what makes a dismissal stick.
		if contentType == lastContentType then
			return
		end

		lastContentType = contentType

		local activeProfile = GetActiveProfile()

		if activeProfile and activeProfile.ContentTypes[contentType] then
			return
		end

		local characterKey = GetCharacterKey()
		local options = {}

		for _, profile in ipairs(GetDatabase().Profiles) do
			if profile.ContentTypes[contentType] and profile.Characters[characterKey] then
				table.insert(options, { text = profile.Name, value = profile.Id })
			end
		end

		if #options == 0 then
			return
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

	do
		local PANEL_TITLE = "XephUI Addon Management"
		local NO_PROFILE_LABEL = "No profile"

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
			end
		)

		Settings.CreateDropdown(category, profileSetting, function()
			local container = Settings.CreateControlTextContainer()
			local profiles = GetDatabase().Profiles

			-- editingProfileId is not persisted, so option 0 must always exist to match the getter's fallback on login and after a delete.
			container:Add(0, NO_PROFILE_LABEL)

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
						if name == "" then
							print("|cff33ff99XephUI|r: profile name cannot be empty.")
						else
							print('|cff33ff99XephUI|r: a profile named "' .. name .. '" already exists.')
						end

						return
					end

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

					editingProfileId = profile.Id
				end,
			})
		end, nil, true))

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
						if name == "" then
							print("|cff33ff99XephUI|r: profile name cannot be empty.")
						else
							print('|cff33ff99XephUI|r: a profile named "' .. name .. '" already exists.')
						end

						return
					end

					profile.Name = name
				end,
			})
		end, nil, true))

		layout:AddInitializer(CreateSettingsButtonInitializer("", "Delete Profile", function()
			local profile = GetEditingProfile()

			if not profile then
				return
			end

			StaticPopup_ShowCustomGenericConfirmation({
				-- GENERIC_CONFIRMATION's OnShow formats data.text, so a literal "%" in the name would break it if concatenated in directly.
				text = 'Delete the profile "%s"?',
				text_arg1 = profile.Name,
				callback = function()
					local database = GetDatabase()
					local _, index = FindProfileById(profile.Id)

					if index then
						table.remove(database.Profiles, index)

						for characterKey, activeProfileId in pairs(database.ActiveProfile) do
							if activeProfileId == profile.Id then
								database.ActiveProfile[characterKey] = nil
							end
						end
					end

					editingProfileId = nil
				end,
			})
		end, nil, true))

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
				local className = GetDatabase().KnownCharacters[characterKey]
				local color = className and C_ClassColor.GetClassColor(className)
				local label = color and color:WrapTextInColorCode(characterKey) or characterKey

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
			-- default here taints to narnia
			nil,
			function()
				local profile = GetEditingProfile()

				if not profile then
					return 0
				end

				local mask = 0

				for value in pairs(profile.ContentTypes) do
					mask = bit.bor(mask, bit.lshift(1, value - 1))
				end

				return mask
			end,
			function(mask)
				local profile = GetEditingProfile()

				if not profile then
					return
				end

				table.wipe(profile.ContentTypes)

				for _, value in ipairs(CONTENT_TYPE_ORDER) do
					if bit.band(mask, bit.lshift(1, value - 1)) ~= 0 then
						profile.ContentTypes[value] = true
					end
				end
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

	EventUtil.ContinueOnPlayerLogin(function()
		local database = GetDatabase()
		local characterKey = GetCharacterKey()

		database.KnownCharacters[characterKey] = select(2, UnitClass("player"))

		-- The loaded addon set is the ground truth: the player may have toggled addons in the Blizzard list since the last apply, leaving the recorded profile stale. A still-matching record wins over an arbitrary first match because profiles may share an addon set.
		local recordedProfile = GetActiveProfile()

		if not (recordedProfile and DoesProfileMatchLoadedAddons(recordedProfile)) then
			database.ActiveProfile[characterKey] = nil

			for _, profile in ipairs(database.Profiles) do
				if DoesProfileMatchLoadedAddons(profile) then
					database.ActiveProfile[characterKey] = profile.Id
					break
				end
			end
		end

		-- editingProfileId is not persisted, so the panel would open on "No profile" even once the active one is known. Seeding the upvalue is enough because the dropdown's getter reads it live.
		editingProfileId = database.ActiveProfile[characterKey]
	end)

	EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", EvaluateContentType)
	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", EvaluateContentType)

	SLASH_XEPHUI1 = "/xephui"

	SlashCmdList.XEPHUI = function(argument)
		local name = strtrim(argument)

		if name == "" then
			if settingsCategory then
				Settings.OpenToCategory(settingsCategory:GetID())
			end

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
