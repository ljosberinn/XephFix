local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	local NULLSIGHT_SPELL_ID = 1260459
	local NULLSIGHT_DURATION = 15
	local NULLSIGHT_ITEM_ID = 249346

	EventUtil.ContinueOnAddOnLoaded(addonName, function()
		local frame = CreateFrame("Frame", nil, BuffIconCooldownViewer)
		frame:SetSize(40, 40)
		frame:Hide()

		frame.Icon = frame:CreateTexture(nil, "ARTWORK")
		frame.Icon:SetAllPoints(frame)

		local mask = frame:CreateMaskTexture(nil, "ARTWORK")
		mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
		mask:SetAllPoints(frame)
		frame.Icon:AddMaskTexture(mask)

		local overlay = frame:CreateTexture(nil, "OVERLAY")
		overlay:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
		overlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 7)
		overlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -7)

		frame.Cooldown = CreateFrame("Cooldown", nil, frame)
		frame.Cooldown:SetAllPoints(frame)
		frame.Cooldown:SetReverse(true)
		frame.Cooldown:SetSwipeColor(0, 0, 0, 0.7)
		frame.Cooldown:SetUseAuraDisplayTime(true)

		local function noop()
			return nil
		end

		-- Stubs so CMC can hooksecurefunc all three methods it expects on buff icon children
		frame.OnActiveStateChanged = noop
		frame.OnUnitAuraAddedEvent = noop
		frame.OnUnitAuraRemovedEvent = noop

		-- CMC's HookBuffIconFrame hooks Cooldown.SetCooldown and calls cdmFrame:GetCooldownInfo().
		-- Returning nil lets its early-return guard handle us gracefully.
		frame.GetCooldownInfo = noop

		-- Trigger CMC's UpdateBuffIcons so it recenters after our frame shows/hides.
		-- On first call _wt_isHooked is nil (CMC hasn't seen layoutIndex yet), so we fire
		-- via a native child that CMC has already hooked. Subsequent calls use our own hook.
		function frame:TriggerCMCCenterUpdate()
			C_Timer.After(0, function()
				if self._wt_isHooked then
					self:OnActiveStateChanged()
					return
				end

				for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
					if child._wt_isHooked and child.OnActiveStateChanged and child ~= self then
						child:OnActiveStateChanged()
						return
					end
				end
			end)
		end

		local function Teardown(self)
			if self.timer then
				self.timer:Cancel()
				self.timer = nil
			end

			if self.layoutIndex then
				self:Hide()
				self.layoutIndex = nil
				CooldownFrame_Clear(self.Cooldown)
				self:TriggerCMCCenterUpdate()
			end
		end

		function frame:UpdateEventRegistration()
			if C_Item.IsEquippedItem(NULLSIGHT_ITEM_ID) then
				self:RegisterEvent("PLAYER_DEAD")
				self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
			else
				self:UnregisterEvent("PLAYER_DEAD")
				self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
				Teardown(self)
			end
		end

		frame:SetScript("OnEvent", function(self, event, ...)
			if event == "PLAYER_EQUIPMENT_CHANGED" or event == "LOADING_SCREEN_DISABLED" then
				self:UpdateEventRegistration()
			elseif event == "PLAYER_DEAD" then
				Teardown(self)
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				local _, _, spellId = ...

				if spellId ~= NULLSIGHT_SPELL_ID then
					return
				end

				if self.timer then
					self.timer:Cancel()
				end

				self.layoutIndex = 999
				self.Icon:SetTexture(C_Spell.GetSpellTexture(NULLSIGHT_SPELL_ID))

				local cmc = _G["CooldownManagerCentered"]
				-- SetTexture resets TexCoord to full, so reapply CMC's zoom/crop
				local profile = cmc and cmc.db and cmc.db.profile and cmc.db.profile or nil

				if profile and profile.cooldownManager_squareIcons_BuffIcons then
					local crop = (profile.cooldownManager_squareIconsZoom_BuffIcons or 0.3) * 0.5
					self.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
				elseif not profile then
					-- fallback positioning when CMC is not installed
					self:ClearAllPoints()
					local gap = BuffIconCooldownViewer.iconPadding + BuffIconCooldownViewer:GetAdditionalPaddingOffset()
					if BuffIconCooldownViewer.iconDirection == Enum.CooldownViewerIconDirection.Left then
						self:SetPoint("RIGHT", BuffIconCooldownViewer, "LEFT", -gap, 0)
					else
						self:SetPoint("LEFT", BuffIconCooldownViewer, "RIGHT", gap, 0)
					end
				end

				CooldownFrame_Set(self.Cooldown, GetTime(), NULLSIGHT_DURATION, true, false, 1)
				self:Show()
				self:TriggerCMCCenterUpdate()

				self.timer = C_Timer.NewTimer(NULLSIGHT_DURATION, function()
					Teardown(self)
					self.timer = nil
				end)
			end
		end)

		frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		frame:RegisterEvent("LOADING_SCREEN_DISABLED")
	end)
end)
