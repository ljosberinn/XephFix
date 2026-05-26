local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.Stopwatch then
		return
	end

	local function PatchStopwatch()
		for i = 1, StopwatchFrame:GetNumRegions() do
			local child = select(i, StopwatchFrame:GetRegions())

			child:Hide()
		end

		local function PlayPauseHook(self)
			self:Hide()
		end

		local function ResetHook(self)
			self:Hide()
		end

		local function HoursHook(self)
			self:Hide()
		end

		StopwatchPlayPauseButton:Hide()

		StopwatchResetButton:Hide()

		StopwatchTickerHour:Hide()

		for i = StopwatchTicker:GetNumRegions(), 1, -1 do
			local child = select(i, StopwatchTicker:GetRegions())

			if child:GetName() == nil then
				child:Hide()
				break
			end
		end

		hooksecurefunc(StopwatchPlayPauseButton, "Show", PlayPauseHook)
		hooksecurefunc(StopwatchResetButton, "Show", ResetHook)
		hooksecurefunc(StopwatchTickerHour, "Show", HoursHook)

		local function Reset()
			StopwatchResetButton_OnClick()
		end

		local function Toggle()
			StopwatchPlayPauseButton_OnClick(StopwatchPlayPauseButton)
		end

		local function Show()
			StopwatchFrame:Show()
		end

		-- dying in an encounter shouldn't pause the stopwatch
		local inEncounter = false

		EventRegistry:RegisterFrameEventAndCallback("CHALLENGE_MODE_START", function()
			inEncounter = false

			Show()

			if StopwatchPlayPauseButton.playing then
				Toggle()
			end

			Reset()
		end)

		EventRegistry:RegisterFrameEventAndCallback("ENCOUNTER_START", function()
			inEncounter = true

			Show()
			Reset()
			Toggle()
		end)

		EventRegistry:RegisterFrameEventAndCallback("ENCOUNTER_END", function()
			inEncounter = false

			if StopwatchPlayPauseButton.playing then
				Toggle()
			end
		end)

		EventRegistry:RegisterFrameEventAndCallback("CHALLENGE_MODE_COMPLETED", function()
			if StopwatchPlayPauseButton.playing then
				Show()
				Toggle()
			end
		end)

		EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_ENABLED", function()
			if StopwatchPlayPauseButton.playing or inEncounter then
				Show()
				Toggle()
			end
		end)

		EventRegistry:RegisterFrameEventAndCallback("PLAYER_REGEN_DISABLED", function()
			if not StopwatchPlayPauseButton.playing then
				Show()
				Reset()
				Toggle()
			end
		end)
	end

	if not C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") then
		local frame = CreateFrame("Frame")

		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, name)
			if event == "ADDON_LOADED" and name == "Blizzard_TimeManager" then
				self:UnregisterEvent("ADDON_LOADED")
				PatchStopwatch()
			end
		end)
	else
		PatchStopwatch()
	end
end)
