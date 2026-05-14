EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
	local function setupItem(item)
		local cd = item.Cooldown
		if not cd then
			return
		end
		cd:SetCountdownFont("GameFontHighlightOutline")
		cd:SetCountdownMillisecondsThreshold(3.01)
		cd:SetUseAuraDisplayTime(true)
	end

	hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnLoad", setupItem)

	for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
		setupItem(child)
	end
end)
