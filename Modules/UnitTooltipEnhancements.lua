local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
	if not XephUISaved.UnitTooltipEnhancements then
		return
	end

	-- Hide the health bar
	GameTooltipStatusBarTexture:SetTexture("")

	-- Needed to tell tooltips for world units apart from tooltips anchored to a
	-- UI frame
	WorldFrame:EnableMouseMotion(true)

	local isColorBlindModeEnabled = C_CVar.GetCVarBool("colorblindMode")

	CVarCallbackRegistry:RegisterCallback("colorblindMode", function()
		isColorBlindModeEnabled = C_CVar.GetCVarBool("colorblindMode")
	end)

	local LEVEL_LABEL = "Level"
	local LEVEL_LINE_PATTERN = "level .+"

	---@type table<string, string>
	local CLASSIFICATION_LABELS = {
		elite = "(Elite)",
		rare = "|c00e066ff(Rare)",
		rareelite = "|c00e066ff(Rare Elite)",
		worldboss = "(Boss)",
	}

	local BOSS_LABEL = "(Boss)"
	local RARE_BOSS_LABEL = "|c00e066ff(Rare Boss)"

	---@param unit UnitToken
	---@return string hexColor
	local function GetHexDifficultyColor(unit)
		local difficulty = C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit)
		local color = GetDifficultyColor(difficulty)

		return string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
	end

	---@param lineIndex number
	---@param text string
	local function SetTooltipLine(lineIndex, text)
		local line = _G["GameTooltipTextLeft" .. lineIndex]

		if line then
			line:SetText(text)
		end
	end

	---@param unit UnitToken
	---@param unitName string
	---@param unitRealm string?
	---@param classColorCode string
	---@param isPlayer boolean
	local function ApplyPlayerNameLine(unit, unitName, unitRealm, classColorCode, isPlayer)
		local nameColor

		if isPlayer then
			nameColor = classColorCode
		elseif UnitIsPVP(unit) then
			nameColor = "|cff00ff00"
		else
			nameColor = "|cff00aaff"
		end

		-- Some units, such as Demolition Fan, return an empty PVP name
		local nameText = UnitPVPName(unit) or unitName

		if nameText == "" then
			nameText = unitName
		end

		if unitRealm and unitRealm ~= "" then
			nameText = nameText .. " - " .. unitRealm
		end

		if UnitIsDeadOrGhost(unit) then
			nameColor = "|c88888888"
		end

		SetTooltipLine(1, nameColor .. nameText .. "|cffffffff|r")
	end

	---@param guildLine number
	---@param guildName string
	---@param guildRank string
	local function ApplyGuildLine(guildLine, guildName, guildRank)
		SetTooltipLine(guildLine, "|c00aaaaff" .. guildName .. " - " .. guildRank .. "|r")
	end

	---@param unit UnitToken
	---@param infoLine number
	---@param specLine number
	---@param reaction number
	---@param classColorCode string
	local function ApplyPlayerInfoLine(unit, infoLine, specLine, reaction, classColorCode)
		local effectiveLevel = UnitEffectiveLevel(unit)
		local realLevel = UnitLevel(unit)
		local infoText

		if reaction < 5 then
			if effectiveLevel == -1 then
				infoText = "|cffff3333" .. LEVEL_LABEL .. " ??|cffffffff"
			else
				infoText = "|cff" .. GetHexDifficultyColor(unit) .. LEVEL_LABEL .. " " .. effectiveLevel .. "|cffffffff"
			end
		elseif effectiveLevel ~= realLevel then
			infoText = LEVEL_LABEL .. " " .. effectiveLevel .. " (" .. realLevel .. ")"
		else
			infoText = LEVEL_LABEL .. " " .. effectiveLevel
		end

		local playerRace = UnitRace(unit)

		if playerRace then
			infoText = infoText .. " " .. playerRace
		end

		-- Color the specialisation line in the unit's class color
		local specializationLine = _G["GameTooltipTextLeft" .. specLine]

		if specializationLine then
			specializationLine:SetText(classColorCode .. (specializationLine:GetText() or "") .. "|r")
		end

		SetTooltipLine(infoLine, infoText .. "|cffffffff|r")
	end

	---@return number? lineIndex
	local function FindMobLevelLine()
		for lineIndex = 2, 4 do
			local line = _G["GameTooltipTextLeft" .. lineIndex]
			local text = line and line:GetText()

			if text and string.lower(text):find(LEVEL_LINE_PATTERN) then
				return lineIndex
			end
		end

		return nil
	end

	---@param unit UnitToken
	local function ApplyMobLevelLine(unit)
		local levelLine = FindMobLevelLine()

		if not levelLine then
			return
		end

		local existingText = _G["GameTooltipTextLeft" .. levelLine]:GetText()
		local effectiveLevel = UnitEffectiveLevel(unit)
		local infoText

		if effectiveLevel == -1 then
			infoText = "|cffff3333" .. LEVEL_LABEL .. " ??|cffffffff "
		else
			infoText = "|cff" .. GetHexDifficultyColor(unit) .. LEVEL_LABEL .. " " .. effectiveLevel .. "|cffffffff "
		end

		local creatureType = UnitCreatureType(unit)

		if creatureType and creatureType ~= "Not specified" then
			infoText = infoText .. "|cffffffff" .. creatureType .. "|cffffffff "
		end

		local classification = UnitClassification(unit)
		local classificationLabel

		if classification == "elite" then
			-- Dungeon and raid bosses report as elite, the tooltip already says boss
			classificationLabel = strfind(existingText, BOSS_LABEL, 1, true) and BOSS_LABEL
				or CLASSIFICATION_LABELS.elite
		elseif classification == "rareelite" then
			classificationLabel = strfind(existingText, BOSS_LABEL, 1, true) and RARE_BOSS_LABEL
				or CLASSIFICATION_LABELS.rareelite
		elseif classification == "normal" and effectiveLevel == -1 then
			classificationLabel = strfind(existingText, BOSS_LABEL, 1, true) and BOSS_LABEL or nil
		else
			classificationLabel = CLASSIFICATION_LABELS[classification]
		end

		if classificationLabel then
			infoText = infoText .. classificationLabel
		end

		SetTooltipLine(levelLine, infoText)
	end

	---@param tooltip GameTooltip
	local function EnhanceUnitTooltip(tooltip)
		if tooltip ~= GameTooltip then
			return
		end

		local firstLineText = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()

		if not firstLineText or not canaccessvalue(firstLineText) then
			return
		end

		---@type UnitToken?
		local unit

		if WorldFrame:IsMouseMotionFocus() then
			unit = "mouseover"
		else
			unit = select(2, GameTooltip:GetUnit())
		end

		if not unit then
			return
		end

		local reaction = UnitReaction(unit, "player")

		if not reaction then
			return
		end

		if UnitIsWildBattlePet(unit) then
			return
		end

		local unitName, unitRealm = UnitName(unit)
		local isPlayer = UnitIsPlayer(unit)
		local isPlayerControlled = UnitPlayerControlled(unit)
		local classBase = UnitClassBase(unit)
		local classColorCode = ""

		if classBase and RAID_CLASS_COLORS[classBase] then
			classColorCode = "|c" .. RAID_CLASS_COLORS[classBase].colorStr
		end

		---@type number?, number?, number?
		local guildLine, infoLine, specLine
		---@type string?, string?
		local guildName, guildRank

		if isPlayer then
			guildName, guildRank = GetGuildInfo(unit)

			if guildName and guildRank then
				guildLine = 2
				infoLine = isColorBlindModeEnabled and 4 or 3
				specLine = isColorBlindModeEnabled and 5 or 4
			else
				guildName = nil
				guildLine = 0
				infoLine = isColorBlindModeEnabled and 3 or 2
				specLine = isColorBlindModeEnabled and 4 or 3
			end

			-- A charmed unit gets an extra line above the information line
			local isCharmed = UnitIsCharmed(unit)

			if canaccessvalue(isCharmed) and isCharmed then
				infoLine = infoLine + 1
				specLine = specLine + 1
			end

			-- Some units, such as Akunda the Nimble in Vol'dun, have no
			-- specialisation line at all
			local specializationLine = _G["GameTooltipTextLeft" .. specLine]

			if not specializationLine or not specializationLine:GetText() then
				return
			end
		end

		if isPlayer or isPlayerControlled or reaction > 4 then
			ApplyPlayerNameLine(unit, unitName, unitRealm, classColorCode, isPlayer)
		elseif UnitIsDeadOrGhost(unit) then
			SetTooltipLine(1, "|c88888888" .. firstLineText .. "|cffffffff|r")
			return
		end

		if isPlayer and guildName then
			ApplyGuildLine(guildLine, guildName, guildRank)
		end

		if isPlayer then
			ApplyPlayerInfoLine(unit, infoLine, specLine, reaction, classColorCode)
		end

		-- Living mobs in brighter red, tap denied mobs in steel blue
		if not isPlayer and not isPlayerControlled and reaction < 4 then
			if UnitIsTapDenied(unit) then
				SetTooltipLine(1, "|c8888bbbb" .. unitName .. "|r")
			else
				SetTooltipLine(1, "|cffff3333" .. unitName .. "|r")
			end
		end

		if not isPlayer and not isPlayerControlled and reaction < 5 and UnitCanAttack(unit, "player") then
			ApplyMobLevelLine(unit)
		end
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, EnhanceUnitTooltip)
end)
