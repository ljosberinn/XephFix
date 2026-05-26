local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.AutoRoleSelect then
		return
	end

	local frame = CreateFrame("Frame")

	frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")

	frame:SetScript("OnEvent", function()
		local role = UnitGroupRolesAssigned("player")

		if role == "NONE" then
			role = GetSpecializationRole(C_SpecializationInfo.GetSpecialization())
		end

		local isTank = role == "TANK"
		local isHealer = role == "HEALER"
		local isDPS = role == "DAMAGER"

		if LFDRoleCheckPopupRoleButtonTank.checkButton:IsEnabled() then
			LFDRoleCheckPopupRoleButtonTank.checkButton:SetChecked(isTank)
		end

		if LFDRoleCheckPopupRoleButtonHealer.checkButton:IsEnabled() then
			LFDRoleCheckPopupRoleButtonHealer.checkButton:SetChecked(isHealer)
		end

		if LFDRoleCheckPopupRoleButtonDPS.checkButton:IsEnabled() then
			LFDRoleCheckPopupRoleButtonDPS.checkButton:SetChecked(isDPS)
		end

		LFDRoleCheckPopupAcceptButton:Enable()
		LFDRoleCheckPopupAcceptButton:Click()
	end)
end)
