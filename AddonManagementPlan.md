# Addon Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Named addon profiles that the player edits in the default UI settings and that the addon offers to swap when the content type changes.

**Architecture:** One self-contained module, `Modules/AddonManagement.lua`, plus one XML template file for a reusable multi-select settings control. Profile data lives in the existing account-wide `XephUISaved`. The settings panel is a Blizzard `Settings` vertical-layout category built from stock initializers, with one custom control subclassing `SettingsDropdownControlMixin` for the two string-keyed multi-selects. A content-type driver resolves the current instance on loading-screen boundaries and, on a mismatch, raises the stock `GENERIC_DROP_DOWN` static popup listing every eligible profile.

**Tech Stack:** Lua 5.1 (WoW 12.1 client, Interface 120100), Blizzard `Settings` framework, Blizzard `Menu` framework (`SetupMenu` / `CreateCheckbox`), `StaticPopupDialogs`, `C_AddOns`. Formatting enforced by `stylua` 2.5.2.

**Spec:** This document. Sections "Data Model", "Content Type Resolution", and "Global Constraints" are the spec the tasks argue from.

---

## Global Constraints

- Interface version 120100. No compatibility shims for older clients.
- The addon ships exactly one SavedVariable, `XephUISaved` (account-wide), declared in `XephUI.toc`. Do not add a second one.
- `XephUISaved.AddonManagement` is already a **boolean module toggle** consumed by `Init.lua`. Profile data MUST live under the separate key `XephUISaved.AddonManagementDB`. Never overwrite the boolean.
- Every module body runs inside `table.insert(Private.LoginFnQueue, function() ... end)` and returns early when its toggle is false. Follow that pattern.
- Nothing in this feature is placed on `Private`. No other module consumes it, so everything is file-local. The only intentional globals are the two XML-referenced names (`XephUIMultiSelectDropdownControlMixin`) and the slash-command globals.
- Comments state non-obvious *why* only: intent, invariants, magic constants, workarounds. No narration of control flow, no restating names or types, no multi-line prose. Single sentence where possible.
- No reference to any other addon by name, in code or comments.
- No minimap button and no `AddonCompartmentFrame` registration.
- Variable names are full and descriptive. No single-letter or abbreviated names (`p`, `cfg`, `fs`, `cd`, `tex`).
- Early returns are always multi-line:
  ```lua
  if not value then
      return
  end
  ```
  Never `if not value then return end` on one line.
- Type annotations for local functions go inline above the function. The repo has no `Types.lua`; do not create one.
- Formatting: tabs, indent width 4, column width 120, double quotes preferred, always call parentheses. Run `stylua` before every commit.
- Localisation: the repo has no localisation table. Hardcode enUS strings as file-local constants.

### Testing constraints

This repository has **no test harness** — no `busted`, no `luacheck`, no CI beyond the release packager. Every line of this feature is bound to live WoW API calls (`C_AddOns`, `Settings`, `GetInstanceInfo`, `ReloadUI`), so unit tests would test mocks rather than behaviour. Standing up a harness plus a WoW API mock layer is explicitly out of scope for this feature.

Therefore each task's verification gate is:

1. `stylua --check` passes on the changed files.
2. The named in-game verification steps are performed and produce the stated output.

In-game steps use `/run` and `/dump`. `/dump` requires the Blizzard debug tools, available by default. When a step says "reload", the tester types `/reload`.

---

## Data Model

Stored under `XephUISaved.AddonManagementDB`:

```lua
{
    NextProfileId = 3,
    Profiles = {                                       -- array; order is dropdown order
        {
            Id = 1,                                    -- stable, never reused
            Name = "Raid",
            Addons = { Details = true, WeakAuras = true },        -- addon folder names
            ContentTypes = { [4] = true },                        -- ContentType values
            Characters = { ["Xephyris-Blackrock"] = true },       -- character keys
        },
    },
    KnownCharacters = { ["Xephyris-Blackrock"] = "MAGE" },        -- lazily grown roster
    ActiveProfile = { ["Xephyris-Blackrock"] = 1 },               -- per character, profile Id
}
```

Rules:

- **Profile identity is `Id`, never the array index and never the name.** Deleting or reordering profiles must not break `ActiveProfile`.
- **Two different character identifiers exist and must not be confused.**
  - *Character key* — `"Name-Realm"`, used for `KnownCharacters`, `ActiveProfile`, and `Profile.Characters`.
  - *Addon API character name* — the bare `UnitName("player")`, the only form `C_AddOns.EnableAddOn` / `DisableAddOn` accept.
- `KnownCharacters` grows one entry per login. This is the "lazy population": a character is only offered in the character multi-select after it has logged in once.
- A newly created profile automatically contains the creating character in `Characters`.
- **Soft gate:** every profile is selectable and editable from any character. `Characters` restricts only which profiles the content-type swap prompt may offer.
- `Addons` never contains `Blizzard_*` addons and never contains `XephUI` — those are outside profile control.

## Content Type Resolution

```lua
local ContentType = {
    OpenWorld = 1,
    Delve = 2,
    Dungeon = 3,
    Raid = 4,
    Arena = 5,
    Battleground = 6,
}
```

Resolved from `GetInstanceInfo()`'s `instanceType` and `difficultyID`, in this order: raid; party with a dungeon difficulty (`DungeonTimewalker`, `DungeonNormal`, `DungeonHeroic`, `DungeonMythic`, `DungeonChallenge`, or `205`); pvp; arena; scenario with difficulty `208`; otherwise open world.

The profile-to-content-type link is stored as a set in `Profile.ContentTypes`, but the Blizzard multi-select dropdown is bitmask-backed, so the setting layer converts. Bit index is `value - 1` — this matches `Settings.CreateDropdownOptionInserter`, which computes `bit.lshift(1, optionData.value - (optionData.enumValueOffset or 1))`.

## Swap Prompt Behaviour

Evaluated on `PLAYER_ENTERING_WORLD` and `LOADING_SCREEN_DISABLED`:

1. Resolve the content type. If it equals the last resolved content type, stop.
2. Record it as the last resolved content type.
3. If the character's active profile covers this content type, stop.
4. Collect candidate profiles: `ContentTypes[current]` is set **and** `Characters[characterKey]` is set. If none, stop.
5. Show `GENERIC_DROP_DOWN` listing every candidate. Accepting applies the chosen profile and reloads.

Step 1 is the entire dismissal story: because the prompt only fires on a *change* of content type, dismissing it (Cancel or Escape — `GENERIC_DROP_DOWN` sets `hideOnEscape = 1`) needs no extra suppression state and cannot re-fire until the player enters different content.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `Modules/AddonManagement.lua` (create) | Everything: enum, store, apply engine, settings panel, driver, slash command. Single file because nothing here is shared and the module never grows past a few hundred lines. |
| `Templates/AddonManagement.xml` (create) | `XephUIMultiSelectDropdownControlTemplate` only. |
| `XephUI.toc` (modify) | Add the template file; remove the retired module line. |
| `Init.lua` (modify) | Remove the retired module's default key. |
| `Modules/AddonSuiteProfileSwapReminder.lua` (delete) | Superseded — this feature replaces it. |

Task order is dictated by dependencies: store → apply engine → custom control → panel → driver → cleanup.

---

## Task 0: Branch

- [ ] **Step 1: Create the feature branch**

```bash
git checkout -b feature/addon-management
```

---

## Task 1: Profile store and character roster

Pure data layer. No UI, no addon toggling.

**Files:**
- Create: `Modules/AddonManagement.lua`
- Modify: `XephUI.toc` (add `Modules/AddonManagement.lua` to the module list, alphabetically before `Modules/AddonSuiteProfileSwapReminder.lua`)

**Interfaces:**
- Consumes: `Private.LoginFnQueue` from `Init.lua`; `XephUISaved.AddonManagement` (boolean toggle).
- Produces, all file-local:
  - `ContentType` — table, the six named values above.
  - `CONTENT_TYPE_ORDER` — array of the six values in display order.
  - `CONTENT_TYPE_LABELS` — map from value to enUS label.
  - `GetDatabase() -> table` — returns `XephUISaved.AddonManagementDB`, creating and back-filling every field.
  - `GetCharacterKey() -> string` — `"Name-Realm"`.
  - `RecordCharacter()` — writes the current character into `KnownCharacters`.
  - `FindProfileById(profileId: number) -> table?, number?` — profile and its array index.
  - `IsNameAvailable(name: string, exceptProfileId: number?) -> boolean`
  - `CreateProfile(name: string) -> table`
  - `RenameProfile(profileId: number, name: string)`
  - `DeleteProfile(profileId: number)`
  - `GetActiveProfile() -> table?`

- [ ] **Step 1: Write the module skeleton and the store**

Create `Modules/AddonManagement.lua`:

```lua
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

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AddonManagement then
		return
	end

	-- UnitFullName's realm and GetNormalizedRealmName are both nil this early on ADDON_LOADED; defer until login supplies one.
	EventUtil.ContinueOnPlayerLogin(RecordCharacter)
end)
```

- [ ] **Step 2: Register the module in the TOC**

In `XephUI.toc`, insert `Modules/AddonManagement.lua` immediately before `Modules/AddonSuiteProfileSwapReminder.lua`.

- [ ] **Step 3: Silence the unused-symbol noise deliberately**

`ContentType`, `CONTENT_TYPE_ORDER`, `CONTENT_TYPE_LABELS`, `CreateProfile`, `RenameProfile`, `DeleteProfile`, `IsNameAvailable`, and `GetActiveProfile` are unused until later tasks. Leave them defined. Do not add `---@diagnostic` suppressions and do not delete them.

- [ ] **Step 4: Format**

```bash
stylua Modules/AddonManagement.lua
```

- [ ] **Step 5: Verify in game**

Reload, then run each line and confirm the stated result:

```
/dump XephUISaved.AddonManagementDB
```
Expected: a table with `NextProfileId = 1`, empty `Profiles`, `KnownCharacters` containing exactly one entry keyed `"Name-Realm"` whose value is the player's class file name (e.g. `"MAGE"`), empty `ActiveProfile`.

Log out, log in on a second character on any realm, then:
```
/dump XephUISaved.AddonManagementDB.KnownCharacters
```
Expected: two entries. This confirms lazy roster growth.

- [ ] **Step 6: Commit**

```bash
git add Modules/AddonManagement.lua XephUI.toc
git commit -m "Add addon profile store and character roster"
```

---

## Task 2: Apply engine and slash command

**Files:**
- Modify: `Modules/AddonManagement.lua`

**Interfaces:**
- Consumes: `GetDatabase`, `GetCharacterKey`, `FindProfileById` from Task 1.
- Produces, all file-local:
  - `IsManagedAddon(name: string) -> boolean`
  - `GetManagedAddons() -> table[]` — array of `{ name = string, title = string }`, sorted by `name`.
  - `ApplyProfile(profile: table)` — writes the enable/disable state, records the active profile, reloads.
  - `OpenSettings()` — forward-declared in this task, assigned in Task 4.

- [ ] **Step 1: Add the addon helpers and apply engine**

Insert above the `table.insert(Private.LoginFnQueue, ...)` block:

```lua
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
```

- [ ] **Step 2: Add the forward declaration and the slash command**

Add near the top of the file, after `CONTENT_TYPE_LABELS`:

```lua
-- Assigned once the settings category exists.
local OpenSettings
```

Add inside the `LoginFnQueue` function, after the deferred `RecordCharacter()` call:

```lua
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

		print("|cff33ff99XephUI|r: no profile named \"" .. name .. "\". Available:")

		for _, profile in ipairs(GetDatabase().Profiles) do
			print(" - " .. profile.Name)
		end
	end
```

`OpenSettings` stays nil until Task 4 assigns it, so bare `/xephui` errors between the two tasks. That is expected; do not add a stub.

- [ ] **Step 3: Format**

```bash
stylua Modules/AddonManagement.lua
```

- [ ] **Step 4: Verify in game**

Reload. Create a profile by hand and apply it:

```
/run XephUISaved.AddonManagementDB.Profiles[1] = { Id = 1, Name = "Test", Addons = {}, ContentTypes = {}, Characters = {} }
/run XephUISaved.AddonManagementDB.NextProfileId = 2
/xephui Nope
```
Expected: `no profile named "Nope". Available:` followed by ` - Test`.

```
/xephui Test
```
Expected: the UI reloads. After the reload, open the game's own AddOns list: every non-Blizzard addon except XephUI is unchecked, XephUI is still checked.

```
/dump XephUISaved.AddonManagementDB.ActiveProfile
```
Expected: one entry mapping the character key to `1`.

Re-enable your addons through the game's AddOns list before continuing.

- [ ] **Step 5: Commit**

```bash
git add Modules/AddonManagement.lua
git commit -m "Apply addon profiles and add the /xephui slash command"
```

---

## Task 3: Multi-select settings control

A reusable control for the two string-keyed multi-selects (addons, characters). Subclasses the stock dropdown control so the label, tooltip, sizing, and narration all come for free; only the menu build and the summary text are replaced.

**Files:**
- Create: `Templates/AddonManagement.xml`
- Modify: `Modules/AddonManagement.lua`
- Modify: `XephUI.toc`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - Global `XephUIMultiSelectDropdownControlMixin`.
  - XML template `XephUIMultiSelectDropdownControlTemplate`.
  - File-local `CreateMultiSelectInitializer(setting, buildMenu, getSummary) -> initializer` where `buildMenu` is `fun(rootDescription)` and `getSummary` is `fun(): string`. The row label comes from the setting's own name.

- [ ] **Step 1: Create the XML template**

Create `Templates/AddonManagement.xml`:

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/">
	<Frame name="XephUIMultiSelectDropdownControlTemplate" inherits="SettingsListElementTemplate" mixin="XephUIMultiSelectDropdownControlMixin" virtual="true">
		<Size x="280" y="26"/>
		<Scripts>
			<OnLoad method="OnLoad"/>
		</Scripts>
	</Frame>
</Ui>
```

- [ ] **Step 2: Register the template in the TOC**

Append `Templates/AddonManagement.xml` as the last line of `XephUI.toc`. It must load after `Modules/AddonManagement.lua` so the mixin global exists; `SettingsListElementTemplate` is provided by `Blizzard_Settings_Shared`, which is not load-on-demand and is therefore already parsed.

- [ ] **Step 3: Add the mixin**

Insert into `Modules/AddonManagement.lua`, above the `LoginFnQueue` block:

```lua
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
```

- [ ] **Step 4: Format**

```bash
stylua Modules/AddonManagement.lua
```

- [ ] **Step 5: Verify in game**

Reload. The template is not instantiated yet, so verification is limited to load integrity:

```
/dump type(XephUIMultiSelectDropdownControlMixin)
```
Expected: `"table"`.

```
/run local frame = CreateFrame("Frame", nil, UIParent, "XephUIMultiSelectDropdownControlTemplate") print(frame.Control ~= nil)
```
Expected: prints `true` and produces no Lua error. This confirms the XML template resolved its inheritance and mixin.

- [ ] **Step 6: Commit**

```bash
git add Templates/AddonManagement.xml Modules/AddonManagement.lua XephUI.toc
git commit -m "Add a multi-select dropdown control for the settings panel"
```

---

## Task 4: Settings panel

**Files:**
- Modify: `Modules/AddonManagement.lua`

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces, file-local:
  - `editingProfileId` — number or nil, the profile the panel currently edits.
  - `GetEditingProfile() -> table?`
  - `RefreshPanel()` — `Settings.NotifyUpdate` on the three content variables.
  - `BuildSettings()` — registers the category and all rows; called once from the login queue.
  - Assignment of `OpenSettings`.
- Setting variable names, used verbatim: `XephUIAddonManagementProfile`, `XephUIAddonManagementAddons`, `XephUIAddonManagementCharacters`, `XephUIAddonManagementContentTypes`.

- [ ] **Step 1: Add the name-entry static popup**

The stock `GENERIC_INPUT_BOX` cannot pre-fill its edit box, which rename needs, so define one dialog used for both create and rename. Insert above the mixin:

```lua
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
```

- [ ] **Step 2: Add the bitmask conversion helpers**

```lua
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
```

- [ ] **Step 3: Add the panel state and builder**

```lua
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
```

- [ ] **Step 4: Add the category registration**

```lua
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
	end, "Creates an empty profile containing the current character.", true))

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
				DeleteProfile(profile.Id)
				editingProfileId = nil
				RefreshPanel()
			end,
		})
	end, nil, true))

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Profile Contents"))
```

- [ ] **Step 5: Add the addon multi-select row**

Continue inside `BuildSettings`:

```lua
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
```

- [ ] **Step 6: Add the character multi-select row**

```lua
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
```

`GetKeysArray` is a Blizzard `TableUtil` global and is available at addon load.

- [ ] **Step 7: Add the content-type row and close the builder**

```lua
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
```

- [ ] **Step 8: Call the builder at login**

Inside the `LoginFnQueue` function, after the deferred `RecordCharacter()` call and before the slash command block:

```lua
	BuildSettings()
```

- [ ] **Step 9: Format**

```bash
stylua Modules/AddonManagement.lua
```

- [ ] **Step 10: Verify in game**

Wipe leftover test data first:
```
/run XephUISaved.AddonManagementDB = nil
/reload
```

Then:

```
/xephui
```
Expected: the Settings window opens on a category named **XephUI Addon Management** in the AddOns list, showing rows: Profile, New Profile, Rename Profile, Delete Profile, a "Profile Contents" header, Addons, Characters, Content Types.

Click **New Profile**, type `Raid`, accept. Expected: the Profile dropdown now reads `Raid`.

Open the **Addons** dropdown. Expected: a scrolling checkbox list of your non-Blizzard addons, XephUI absent. Tick three. Expected: the closed dropdown reads `3 / <total>`.

Open the **Characters** dropdown. Expected: the current character listed once, in class colour, already ticked.

Open the **Content Types** dropdown. Expected: six checkboxes, no stepper arrows either side. Tick `Raid`.

```
/reload
/dump XephUISaved.AddonManagementDB.Profiles[1]
```
Expected: `Name = "Raid"`, three entries in `Addons`, `ContentTypes = { [4] = true }`, `Characters` holding the current character key.

Create a second profile, switch the Profile dropdown between them. Expected: the Addons, Characters, and Content Types rows repaint to match the selected profile without leaving the category.

Delete a profile. Expected: it disappears from the Profile dropdown; the remaining profile is unaffected.

- [ ] **Step 11: Commit**

```bash
git add Modules/AddonManagement.lua
git commit -m "Add the addon profile settings panel"
```

---

## Task 5: Content type driver and swap prompt

**Files:**
- Modify: `Modules/AddonManagement.lua`

**Interfaces:**
- Consumes: `ContentType`, `GetDatabase`, `GetCharacterKey`, `GetActiveProfile`, `ApplyProfile`, `FindProfileById`.
- Produces, file-local:
  - `ResolveContentType(instanceType: string, difficultyId: number) -> number`
  - `GetCandidateProfiles(contentType: number) -> table[]`
  - `EvaluateContentType()` — the whole flow from the "Swap Prompt Behaviour" section.
  - `lastContentType` — number or nil.

- [ ] **Step 1: Add the resolver**

Insert above `BuildSettings`:

```lua
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
```

- [ ] **Step 2: Add candidate selection and the prompt**

```lua
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
```

- [ ] **Step 3: Register the events**

Inside the `LoginFnQueue` function, after `BuildSettings()`:

```lua
	EventRegistry:RegisterFrameEventAndCallback("PLAYER_ENTERING_WORLD", EvaluateContentType)
	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", EvaluateContentType)
```

- [ ] **Step 4: Format**

```bash
stylua Modules/AddonManagement.lua
```

- [ ] **Step 5: Verify in game**

Set up two profiles through the settings panel: `Open World` with Content Types = Open World, and `Raid` with Content Types = Raid. Put the current character in both. Give them different addon sets.

```
/xephui Open World
```
Expected: reload; afterwards `ActiveProfile` points at the Open World profile.

Enter any raid instance. Expected: on the loading screen ending, a dialog reading `Content changed to Raid. Switch addon profile and reload?` with a dropdown listing `Raid`, plus Accept and Cancel.

Press **Escape**. Expected: the dialog closes and does not return while you stay in the raid.

Zone out to the open world, then back into the raid. Expected: the dialog appears again. This confirms the dismissal is scoped to one content-type change.

Accept it. Expected: the UI reloads and the raid profile's addon set is active.

Add a third profile also flagged Raid, containing the current character. Zone out and back in. Expected: the dialog's dropdown lists both raid profiles.

Uncheck the current character from one of those profiles. Zone out and back in. Expected: only the remaining profile is offered. This confirms the soft gate.

- [ ] **Step 6: Commit**

```bash
git add Modules/AddonManagement.lua
git commit -m "Prompt for an addon profile swap when the content type changes"
```

---

## Task 6: Remove the superseded module

**Files:**
- Delete: `Modules/AddonSuiteProfileSwapReminder.lua`
- Modify: `XephUI.toc`
- Modify: `Init.lua`

- [ ] **Step 1: Delete the module**

```bash
git rm Modules/AddonSuiteProfileSwapReminder.lua
```

- [ ] **Step 2: Remove its TOC line**

Delete `Modules/AddonSuiteProfileSwapReminder.lua` from `XephUI.toc`.

- [ ] **Step 3: Remove its default key**

In `Init.lua`, delete the line `AddonSuiteProfileSwapReminder = true,` from the `defaults` table. Leave `AddonManagement = true` in place.

Stale `XephUISaved.AddonSuiteProfileSwapReminder` entries in existing saved variables are harmless — nothing reads the key once the module is gone. Do not add migration code.

- [ ] **Step 4: Verify in game**

```
/reload
```
Expected: no Lua errors, and `/xephui` still opens the settings category.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Remove the superseded profile swap reminder module"
```

---

## Task 7: Pre-merge verification

- [ ] **Step 1: Confirm formatting across the branch**

```bash
stylua --check Modules/AddonManagement.lua
```
Expected: no output, exit code 0.

- [ ] **Step 2: Confirm no stray references**

```bash
git grep -in "addonsuite" -- . ":(exclude)AddonManagementPlan.md"
```
Expected: no matches.

- [ ] **Step 3: Full pass on a clean saved-variables file**

```
/run XephUISaved.AddonManagementDB = nil
/reload
```
Then walk the whole flow once: create a profile, pick addons, pick content types, apply it with `/xephui <name>`, zone into matching and non-matching content, confirm the prompt fires and dismisses correctly.

- [ ] **Step 4: Second-character check**

Log in on a different character. Expected: nothing changes about that character's addons. The settings panel lists every profile. The Characters dropdown now offers the second character, and ticking it makes that profile a swap candidate there.

- [ ] **Step 5: Open the pull request**

```bash
git push -u origin feature/addon-management
```

PR description states what the feature does, that it replaces the old reminder module, and carries this checklist:

- Profiles survive a reload
- Applying a profile enables exactly its addon set and nothing else
- XephUI cannot be disabled by a profile
- `Blizzard_*` addons are never touched
- Swap prompt fires only on a content-type change
- Escape dismisses the prompt and it does not immediately return
- A second character sees all profiles but joins none until opted in
- No Lua errors on a clean saved-variables file
