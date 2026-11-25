local addonName, Private = ...

---@class XephUIModuleDefinition
---@field key string
---@field name string
---@field description string
---@field enabledByDefault boolean
---@field isStandardOnly boolean?

-- isStandardOnly mirrors [ExcludeLoadGameType forever] in the .toc: those files never load there, so their toggles would do nothing.
---@type XephUIModuleDefinition[]
Private.ModuleDefinitions = {
	{
		key = "ActionTracker",
		name = "Action Tracker",
		description = "Shows your recently cast spells and your current cast as icons beneath the main action bar.",
		enabledByDefault = false,
	},
	{
		key = "AddonManagement",
		name = "Addon Management",
		description =
		"Saves addon profiles per character and content type, and offers a profile switch when entering new content. /xephui <profile> applies one.",
		enabledByDefault = true,
	},
	{
		key = "ApplicantListVisibility",
		name = "Applicant List Visibility",
		description = "Lets you view the Group Finder applicant list even when you are not the group leader.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "AuraSounds",
		name = "Aura Sounds",
		description = "Plays a sound when you receive a major external defensive or proc cheat death effects.",
		enabledByDefault = true,
	},
	{
		key = "AutoDialogueInteraction",
		name = "Auto Dialogue Interaction",
		description =
		"Automatically picks known dungeon and event dialogue options. Hold Alt to auto-pick an NPC's only option.",
		enabledByDefault = true,
	},
	{
		key = "AutoGreet",
		name = "Auto Greet",
		description = "Automatically greets players joining your party.",
		enabledByDefault = true,
	},
	{
		key = "AutoKeystone",
		name = "Auto Keystone",
		description = "Automatically inserts your Mythic Keystone when you open the Font of Power.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "AutoQuest",
		name = "Auto Quest",
		description = "Automatically accepts and turns in quests. Hold Shift to skip.",
		enabledByDefault = true,
	},
	{
		key = "AutoRepair",
		name = "Auto Repair",
		description =
		"Automatically repairs your gear at merchants, using guild funds first when available. Hold Shift to skip.",
		enabledByDefault = true,
	},
	{
		key = "AutoRoleSelect",
		name = "Auto Role Select",
		description = "Automatically accepts Group Finder role checks with your current role.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "AutoSellJunk",
		name = "Auto Sell Junk",
		description = "Automatically sells junk when you open a merchant. Hold Shift to skip.",
		enabledByDefault = true,
	},
	{
		key = "BreakTimer",
		name = "Break Timer",
		description = "Shows break timers started by BigWigs or DBM users when you have neither installed.",
		enabledByDefault = true,
	},
	{
		key = "BuffWarningPatch",
		name = "Buff Expiration Fix",
		description = "Stops buffs and debuffs from flashing when they are about to expire.",
		enabledByDefault = true,
	},
	{
		key = "CharacterSheetImprovements",
		name = "Character Sheet Improvements",
		description = "Shows item level, enchants and gems on the character and inspect windows.",
		enabledByDefault = true,
	},
	{
		key = "CharacterStatsFormatting",
		name = "Character Stats Formatting",
		description = "Shows secondary stats as rating plus percentage, and your item level with decimals.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "ChatItemEnhancements",
		name = "Chat Item Enhancements",
		description = "Adds icons to item links in chat, plus item level and slot for gear.",
		enabledByDefault = true,
	},
	{
		key = "CinematicBlocker",
		name = "Cinematic Blocker",
		description = "Automatically skips certain cinematics.",
		enabledByDefault = true,
	},
	{
		key = "CleanNamesInInstances",
		name = "Clean Names In Instances",
		description = "Hides player titles and guild names inside instances, otherwise shows them.",
		enabledByDefault = false,
	},
	{
		key = "CooldownManagerMountOpacity",
		name = "Cooldown Manager Mount Opacity",
		description = "Fades the Cooldown Manager while mounted, restoring it when combat starts.",
		enabledByDefault = true,
	},
	{
		key = "CooldownManagerTweaks",
		name = "Cooldown Manager Tweaks",
		description =
		"Gives the Cooldown Manager square bordered icons and cleaner fonts, and keeps buff icons centered.",
		enabledByDefault = true,
	},
	{
		key = "DamageMeterToggle",
		name = "Damage Meter Toggle",
		description = "Automatically enables the Damage Meter in Dungeons, otherwise disables it.",
		enabledByDefault = false,
	},
	{
		key = "DebuffDurationDecimals",
		name = "Debuff Duration Decimals",
		description = "Shows fractions of a second on your debuff timers when under five seconds remain.",
		enabledByDefault = true,
	},
	{
		key = "DraggableFrames",
		name = "Draggable Frames",
		description = "Lets you drag the Talents/Spellbook and Group Finder windows.",
		enabledByDefault = true,
	},
	{
		key = "EventToastBlocker",
		name = "Event Toast Blocker",
		description = "Hides waystone discovery, new stage and boss kill banners.",
		enabledByDefault = true,
	},
	{
		key = "EvokerLetFly",
		name = "Evoker Let Fly",
		description = "Replaces the Dracthyr shout on Deep Breath and Breath of Eons with a different voice line.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "FocusMarkerAnnouncement",
		name = "Focus Marker Announcement",
		description = "Announces the marker from your focus macro in party chat on ready checks.",
		enabledByDefault = true,
	},
	{
		key = "GearUpgradeRankTooltipRenamer",
		name = "Gear Upgrade Rank Tooltip Renamer",
		description = "Shows the upgrade track in its color with its item level range on item tooltips.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "GearUpgradeReminder",
		name = "Gear Upgrade Reminder",
		description = "Tells you in chat when equipped gear can be upgraded without spending crests.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "KeystoneAnnouncer",
		name = "Keystone Announcer",
		description = "Announces your new Mythic Keystone in party chat.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "KeystoneInfo",
		name = "Keystone Info",
		description = "/keys lists your party members' keystones and ratings in chat.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "MDTSim",
		name = "MDT Sim",
		description =
		"Adds buttons to Mythic Dungeon Tools to export your route, and optionally your group, for SimulationCraft.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "PlayerFrameChain",
		name = "Player Frame Chain",
		description = "Adds a gold winged elite border to your player frame portrait.",
		enabledByDefault = true,
	},
	{
		key = "ReadyCheck",
		name = "Ready Check",
		description =
		"Shows missing flask, food, rune and weapon oil in Mythic dungeons and on ready checks. Click an icon to use the item.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "SelfAbsorb",
		name = "Self Absorb",
		description = "Shows absorb shields on your player frame's health bar.",
		enabledByDefault = true,
	},
	{
		key = "Stopwatch",
		name = "Stopwatch",
		description = "Turns the stopwatch into a combat timer.",
		enabledByDefault = true,
	},
	{
		key = "TalentReminders",
		name = "Talent Reminders",
		description = "Reminds you in chat and by voice which utility talents to pick or drop for each dungeon.",
		enabledByDefault = true,
		isStandardOnly = true,
	},
	{
		key = "TalkingHeadBlocker",
		name = "Talking Head Blocker",
		description = "Hides the talking head dialogue popup.",
		enabledByDefault = true,
	},
	{
		key = "TargetShield",
		name = "Target Shield",
		description = "Shows your hostile target's absorb shield amount in the middle of the screen.",
		enabledByDefault = true,
	},
	{
		key = "TooltipIDs",
		name = "Tooltip IDs",
		description = "Adds item, bonus and spell IDs to tooltips.",
		enabledByDefault = true,
	},
	{
		key = "UIScale",
		name = "UI Scale",
		description = "Keeps the UI scale fixed at a pixel-perfect value for 1440p screens.",
		enabledByDefault = false,
	},
	{
		key = "UnitTooltipEnhancements",
		name = "Unit Tooltip Enhancements",
		description = "Restyles unit tooltips with class-colored names, guild, level, race, Mythic+ score and mob type.",
		enabledByDefault = true,
	},
}

---@type table<string, { category: table, layout: table }>
Private.SettingsCategories = {}

local RELOAD_REQUIRED_TOOLTIP = "Takes effect after reloading the UI."

XephUISettingsDescriptionMixin = {}

function XephUISettingsDescriptionMixin:Init(initializer)
	self.Text:SetText(initializer.data.text)
end

---@param text string
---@return table
local function CreateDescriptionInitializer(text)
	return Settings.CreateElementInitializer("XephUISettingsDescriptionTemplate", { text = text })
end

---@return table rootCategory
function Private.CreateSettingsCategories()
	local rootCategory, rootLayout = Settings.RegisterVerticalLayoutCategory(addonName)

	rootLayout:AddInitializer(
		CreateDescriptionInitializer("Each module can be toggled in its own category. " .. RELOAD_REQUIRED_TOOLTIP)
	)

	for _, module in ipairs(Private.ModuleDefinitions) do
		if not (module.isStandardOnly and Private.IsClassicForever) then
			local category, layout = Settings.RegisterVerticalLayoutSubcategory(rootCategory, module.name)

			layout:AddInitializer(CreateDescriptionInitializer(module.description))

			local setting = Settings.RegisterAddOnSetting(
				category,
				addonName .. "_" .. module.key,
				module.key,
				XephUISaved,
				Settings.VarType.Boolean,
				ENABLE,
				module.enabledByDefault
			)

			Settings.CreateCheckbox(category, setting, RELOAD_REQUIRED_TOOLTIP)

			Private.SettingsCategories[module.key] = { category = category, layout = layout }
		end
	end

	return rootCategory
end
