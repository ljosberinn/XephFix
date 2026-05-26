local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.BuffWarningPatch then
		return
	end

	-- this turns off the alpha change of auras
	BuffFrame.AuraContainer.GetAuraWarningAlphaForDuration = nil
	DebuffFrame.AuraContainer.GetAuraWarningAlphaForDuration = nil
	ExternalDefensivesFrame.AuraContainer.GetAuraWarningAlphaForDuration = nil
end)
