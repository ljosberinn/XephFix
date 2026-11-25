local addonName, Private = ...

Private.LoginFnQueue = {}
Private.IsClassicForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	XephUISaved = XephUISaved or {}

	for _, module in ipairs(Private.ModuleDefinitions) do
		if XephUISaved[module.key] == nil then
			XephUISaved[module.key] = module.enabledByDefault
		end
	end

	-- Modules may add controls to their own category while the queue runs, so the root is registered only afterwards.
	local rootCategory = Private.CreateSettingsCategories()

	for i = 1, #Private.LoginFnQueue do
		Private.LoginFnQueue[i]()
	end

	table.wipe(Private.LoginFnQueue)

	Settings.RegisterAddOnCategory(rootCategory)
end)
