local addonName, Private = ...

Private.LoginFnQueue = {}
Private.IsXeph = false

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	local name = UnitName("player")

	if name == "Xephyris" or name == "Xepheris" or name == "Syrihpex" or name == "Vrede" or name == "Xephiscerate" then
		Private.IsXeph = true
	end

	for i = 1, #Private.LoginFnQueue do
		local fn = Private.LoginFnQueue[i]
		fn()
	end

	table.wipe(Private.LoginFnQueue)
end)

-- Zone Change Print
-- do
-- 	local seenMaps = {}

-- 	local function listener()
-- 		local mapID = C_Map.GetBestMapForUnit("player")

-- 		if mapID == nil then
-- 			return
-- 		end

-- 		local mapName = C_Map.GetMapInfo(mapID).name
-- 		local mapGroupID = C_Map.GetMapGroupID(mapID)
-- 		local floorName

-- 		if mapGroupID then
-- 			local floors = C_Map.GetMapGroupMembersInfo(mapGroupID)

-- 			if floors then
-- 				for _, floor in pairs(floors) do
-- 					if floor.mapID == mapID then
-- 						floorName = floor.name
-- 						break
-- 					end
-- 				end
-- 			end
-- 		end

-- 		local cacheKey = mapName .. "|" .. (floorName or "")

-- 		if seenMaps[cacheKey] then
-- 			return
-- 		end

-- 		seenMaps[cacheKey] = true

-- 		if floorName and floorName ~= mapName then
-- 			print("You are in " .. floorName .. " of " .. mapName .. ".")
-- 		else
-- 			print("You are in " .. mapName .. ".")
-- 		end

-- 		print("> mapID " .. mapID)

-- 		if mapGroupID then
-- 			print("> mapGroupID " .. mapGroupID)
-- 		end
-- 	end

-- 	AddListener("ZONE_CHANGED", listener)
-- end

-- if MicroMenu then
-- 	MicroMenu:HookScript("OnShow", function()
-- 		MicroMenu:SetScale(0.75)
-- 	end)

-- 	MicroMenu:SetScale(0.75)
-- end

if GetMapID == nil then
	function GetMapID()
		return 0
	end
end
