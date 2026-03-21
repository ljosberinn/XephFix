local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not Private.IsXeph then
		return
	end

	local function Callback()
		local inInstance, instanceType = IsInInstance()

		local difficultyId = select(3, GetInstanceInfo())
		-- use this if you want to enable damage meters in raids aswell:
		-- and (instanceType == "party" or instanceType == "raid")
		local enable = inInstance and instanceType == "party" and difficultyId ~= 208 -- delves

		C_CVar.SetCVar("damageMeterEnabled", enable and 1 or 0)
	end

	EventRegistry:RegisterFrameEventAndCallback("LOADING_SCREEN_DISABLED", Callback)
	EventRegistry:RegisterFrameEventAndCallback("UPDATE_INSTANCE_INFO", Callback)
end)
