local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.PlayerFrameChain then
		return
	end

	-- Keep the chain from clipping through the pet portrait and the rune frame
	if PetPortrait then
		PetPortrait:GetParent():SetFrameLevel(4)
	end

	if RuneFrame then
		RuneFrame:SetFrameLevel(4)
	end

	---@type Texture
	local chainTexture = PlayerFrame.PlayerFrameContainer:CreateTexture(nil, "OVERLAY")
	chainTexture:SetTexCoord(1, 0, 0, 1)
	chainTexture:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", true)
	chainTexture:SetPoint("TOPLEFT", -11, -8)
	chainTexture:SetVertexColor(1, 1, 1, 1)
end)
