local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.CinematicBlocker then
		return
	end

	---@type table<number, boolean>
	local blockedUiMapIDs = {
		[1004] = true, -- Kings' Rest, before Dazar
	}

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("CINEMATIC_START")

	frame:SetScript("OnEvent", function()
		local uiMapID = C_Map.GetBestMapForUnit("player")

		if not uiMapID or not blockedUiMapIDs[uiMapID] then
			return
		end

		CinematicFrame_CancelCinematic()
	end)
end)
