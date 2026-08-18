local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.TalkingHeadBlocker then
		return
	end

	---@param self Frame
	hooksecurefunc(TalkingHeadFrame, "PlayCurrent", function(self)
		self:Hide()
	end)
end)
