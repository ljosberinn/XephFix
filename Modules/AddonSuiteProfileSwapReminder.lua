local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AddonSuiteProfileSwapReminder then
		return
	end

	if not C_AddOns.IsAddOnLoaded("AddonSuite") then
		return
	end

	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", function()
		local db = _G.ADDON_SUITE_DB

		if not db or not db.profiles then
			return
		end

		local instanceType = select(2, IsInInstance())

		if instanceType == "raid" then
			if db.profiles.Raid.enable == nil then
				print("[AddonSuite Reminder] change profile to Raid")
			end
		elseif db.profiles.Keys.enable == nil then
			print("[AddonSuite Reminder] change profile to Keys")
		end
	end)
end)
