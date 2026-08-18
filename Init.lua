local addonName, Private = ...

Private.LoginFnQueue = {}

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	local defaults = {
		AddonSuiteProfileSwapReminder = true,
		AutoDialogueInteraction = true,
		AutoGreet = true,
		AutoKeystone = true,
		AutoQuest = true,
		AutoRepair = true,
		AutoRoleSelect = true,
		AutoSellJunk = true,
		BuffWarningPatch = true,
		CharacterSheetImprovements = true,
		CharacterStatsFormatting = true,
		ChatItemEnhancements = true,
		CleanNamesInInstances = true,
		CooldownManagerMountOpacity = true,
		CooldownManagerTweaks = true,
		DamageMeterToggle = true,
		DraggableFrames = true,
		EventToastBlocker = true,
		EvokerLetFly = true,
		FocusMarkerAnnouncement = true,
		GearUpgradeRankTooltipRenamer = true,
		GearUpgradeReminder = true,
		HiddenQuestCleanup = true,
		KeystoneAnnouncer = true,
		KeystoneInfo = true,
		MDTSim = true,
		PlayerFrameChain = true,
		Stopwatch = true,
		TalkingHeadBlocker = true,
		TargetShield = true,
		TalentReminders = true,
		TooltipIDs = true,
		UIScale = true,
		UnitTooltipEnhancements = true,
	}

	XephUISaved = XephUISaved or {}

	for key, value in pairs(defaults) do
		if XephUISaved[key] == nil then
			XephUISaved[key] = value
		end
	end

	for i = 1, #Private.LoginFnQueue do
		Private.LoginFnQueue[i]()
	end

	table.wipe(Private.LoginFnQueue)
end)
