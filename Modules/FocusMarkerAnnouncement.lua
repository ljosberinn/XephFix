local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.FocusMarkerAnnouncement then
		return
	end

	local macroName = "focus"

	local function ExtractMarkerFromMacro()
		for i = 1, GetNumMacros() do
			local name, icon, body = GetMacroInfo(i)

			if name == macroName then
				for line in body:gmatch("[^\n]+") do
					if string.find(line, "/tm") ~= nil then
						return tonumber(line:match("^/tm%s+.-(%d+)$"))
					end
				end

				return nil
			end
		end

		return nil
	end

	print(
		"[XephUI] FocusMarkerAnnouncement attempts to extract the target marker you're using from a macro called 'focus'. If you don't use focus, it won't do anything. If you wish to disable this message, disable FocusMarkerAnnouncement.lua"
	)

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("READY_CHECK")
	frame:SetScript("OnEvent", function(self, event, ...)
		if IsInRaid() then
			return
		end

		-- cannot send chat mid key
		if C_ChallengeMode.IsChallengeModeActive() then
			return
		end

		if event == "READY_CHECK" then
			local markerId = ExtractMarkerFromMacro()

			if markerId == nil then
				return
			end

			C_ChatInfo.SendChatMessage(string.format("My Focus Marker is {rt%d}", markerId), "PARTY")
		end
	end)
end)
