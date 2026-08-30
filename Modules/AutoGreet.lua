local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoGreet then
		return
	end

	local lastGroupSize = 0
	local hasGroupBaseline = false

	---@return number
	local function GetPartySize()
		if IsInRaid() then
			return 0
		end

		return GetNumGroupMembers()
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("GROUP_JOINED")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("LOADING_SCREEN_DISABLED")
	frame.timer = nil

	function frame:DoGreeting()
		if not InCombatLockdown() and not C_ChallengeMode.IsChallengeModeActive() then
			local num = math.random(1, 100)
			local greeting = "hi"
			if num <= 5 then
				greeting = "hello everypony"
			elseif num <= 10 then
				greeting = "meowdy"
			end

			C_ChatInfo.SendChatMessage(greeting, "PARTY")
		end
	end

	function frame:GreetAfterCombat()
		if C_ChallengeMode.IsChallengeModeActive() then
			return
		end

		if InCombatLockdown() then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			if self.timer then
				self.timer:Cancel()
				self.timer = nil
			end

			self.timer = C_Timer.NewTimer(2, GenerateClosure(self.DoGreeting, self))
		end
	end

	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_REGEN_ENABLED" then
			self:UnregisterEvent("PLAYER_REGEN_ENABLED")
			self:DoGreeting()
		elseif event == "LOADING_SCREEN_DISABLED" then
			-- Zoning and reloads replay the roster from scratch, so resync instead of
			-- reading the rebuilt group as people joining.
			lastGroupSize = GetPartySize()
			hasGroupBaseline = true
		elseif event == "GROUP_JOINED" then
			if IsInRaid() then
				return
			end

			lastGroupSize = GetPartySize()
			hasGroupBaseline = true

			self:GreetAfterCombat()
		elseif event == "GROUP_ROSTER_UPDATE" then
			local currentSize = GetPartySize()

			-- The first roster update of a session reports an existing group; it is a
			-- baseline, not a join.
			if hasGroupBaseline and currentSize > lastGroupSize then
				self:GreetAfterCombat()
			end

			lastGroupSize = currentSize
			hasGroupBaseline = true
		end
	end)
end)
