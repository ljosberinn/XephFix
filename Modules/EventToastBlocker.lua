local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.EventToastBlocker then
		return
	end

	local blockedIDs = {
		[288] = true, -- Discover Waystone
		[290] = true, -- Discover Waystone
		[5] = true, -- New Stage
	}

	local origDisplayToast = EventToastManagerFrame.DisplayToast

	function EventToastManagerFrame:DisplayToast(firstToast)
		if not firstToast then
			C_EventToastManager.RemoveCurrentToast()
		end

		local tbl = C_EventToastManager.GetNextToastToDisplay()

		while tbl and blockedIDs[tbl.eventToastID] do
			C_EventToastManager.RemoveCurrentToast()
			tbl = C_EventToastManager.GetNextToastToDisplay()
		end

		origDisplayToast(self, true)
	end
end)
