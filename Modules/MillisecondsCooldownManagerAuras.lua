EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
	local function SetupBuffIconItem(item)
		local cd = item.Cooldown

		if not cd then
			return
		end

		cd:SetCountdownFont("GameFontHighlightOutline")
		cd:SetCountdownMillisecondsThreshold(4)
		cd:SetUseAuraDisplayTime(true)
	end

	-- Essential and Utility items already have their font set via cooldownFont KeyValues;
	-- only the threshold needs to be added here.
	local function SetupCooldownItem(item)
		local cd = item.Cooldown

		if not cd then
			return
		end

		cd:SetCountdownMillisecondsThreshold(4)
	end

	hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnLoad", SetupBuffIconItem)
	hooksecurefunc(CooldownViewerCooldownItemMixin, "OnLoad", SetupCooldownItem)

	for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
		SetupBuffIconItem(child)
	end

	for _, child in ipairs({ EssentialCooldownViewer:GetChildren() }) do
		SetupCooldownItem(child)
	end

	for _, child in ipairs({ UtilityCooldownViewer:GetChildren() }) do
		SetupCooldownItem(child)
	end
end)
