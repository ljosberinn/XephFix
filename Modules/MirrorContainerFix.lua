local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	MirrorTimerContainer:HookScript("OnHide", function()
		MirrorTimerContainer:Show()
	end)
end)
