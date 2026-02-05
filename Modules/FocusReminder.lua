local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not Private.IsXeph then
		return
	end

	local function FindAppropriateTTSVoiceId()
		local ttsVoiceId = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
		local patternToLookFor = "English"

		for _, voice in pairs(C_VoiceChat.GetTtsVoices()) do
			if string.find(voice.name, patternToLookFor) ~= nil then
				return voice.voiceID
			end
		end

		return ttsVoiceId
	end

	local voiceId = FindAppropriateTTSVoiceId()

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_FOCUS_CHANGED" then
			if UnitExists("focus") then
				return
			end

			C_Timer.After(1, function()
				-- delay this as focus target dying may imply leaving combat
				if not InCombatLockdown() then
					return
				end

				C_VoiceChat.SpeakText(voiceId, "focus", 3, C_TTSSettings.GetSpeechVolume())
			end)
		end
	end)
end)
