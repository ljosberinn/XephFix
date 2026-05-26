local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.DraggableFrames then
		return
	end

	-- make more frames draggable
	---@param frameToPatch Frame
	local function PatchFrame(frameToPatch)
		if InCombatLockdown() then
			return
		end

		frameToPatch:SetMovable(true)
		frameToPatch:SetClampedToScreen(true)
		frameToPatch:SetScript(
			"OnMouseDown",
			---@param self Frame
			function(self)
				self:StartMoving()
			end
		)
		frameToPatch:SetScript(
			"OnMouseUp",
			---@param self Frame
			function(self)
				self:StopMovingOrSizing()
			end
		)
	end

	EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
		PatchFrame(PlayerSpellsFrame)
	end)

	-- PatchFrame(FriendsFrame) -- no longer needed, BetterFriendList covers this
	PatchFrame(PVEFrame)
end)
