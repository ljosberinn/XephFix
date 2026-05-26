local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.UIScale then
		return
	end

	local expectedScale = 768 / 1440
	local currentWidth, currentHeight = GetPhysicalScreenSize()

	local function Scale(scaleNumber)
		local numberedScale = tonumber(scaleNumber) or 1.0

		-- Validate scale
		if numberedScale <= 0.001 or numberedScale > 1 then
			numberedScale = 1.0
		end

		-- Don't call SetCVar during combat
		if not InCombatLockdown() then
			C_CVar.SetCVar("uiScale", numberedScale)
		end

		UIParent:SetScale(numberedScale)
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("LOADING_SCREEN_DISABLED")
	frame:RegisterEvent("UI_SCALE_CHANGED")
	frame:RegisterEvent("DISPLAY_SIZE_CHANGED")

	frame:SetScript("OnEvent", function(self, event, ...)
		if event == "PLAYER_REGEN_ENABLED" then
			C_Timer.After(0.5, function()
				Scale(expectedScale)
			end)

			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		elseif event == "LOADING_SCREEN_DISABLED" then
			self:UnregisterEvent("LOADING_SCREEN_DISABLED")

			if InCombatLockdown() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED")
			else
				C_Timer.After(0.5, function()
					Scale(expectedScale)
				end)
			end
		elseif event == "UI_SCALE_CHANGED" then
			C_Timer.After(0.1, function()
				local current = tonumber(C_CVar.GetCVar("uiScale"))

				if math.abs(current - expectedScale) > 0.001 then
					Scale(expectedScale)
				end
			end)
		elseif event == "DISPLAY_SIZE_CHANGED" then
			local newWidth, newHeight = GetPhysicalScreenSize()

			if newWidth ~= currentWidth or newHeight ~= currentHeight then
				print(
					string.format("Resolution changed from %dx%d to %dx%d", currentWidth, currentHeight, newWidth,
						newHeight
					))
				currentWidth, currentHeight = newWidth, newHeight
				-- Reapply saved scale
				Scale(expectedScale)
				print("UI Scale reapplied: " .. string.format("%.2f", expectedScale))
			end
		end
	end)
end)
