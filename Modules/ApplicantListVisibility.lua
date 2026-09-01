local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.ApplicantListVisibility then
		return
	end

	LFGListFrame.ApplicationViewer.UnempoweredCover:HookScript(
		"OnShow",
		---@param cover Frame
		function(cover)
			cover:Hide()
		end
	)
end)
