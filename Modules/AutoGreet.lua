local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoGreet then
		return
	end

	local lastGroupSize = 0

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("GROUP_JOINED")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
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
		elseif event == "GROUP_JOINED" then
			if IsInRaid() then
				return
			end

			lastGroupSize = GetNumGroupMembers()

			self:GreetAfterCombat()
		elseif event == "GROUP_ROSTER_UPDATE" then
			if IsInRaid() then
				lastGroupSize = 0
				return
			end

			local currentSize = GetNumGroupMembers()

			if currentSize > lastGroupSize then
				self:GreetAfterCombat()
			end

			lastGroupSize = currentSize
		end
	end)
end)
