local addonName, Private = ...

-- only Evokers, see classID here: https://wago.tools/db2/ChrSpecialization
if select(3, UnitClass("player")) ~= 13 then
	return
end

local breaths = {
	[357210] = true, -- deep breath
	[433874] = true, -- deep breath maneuverability
	[403631] = true, -- breath of eons
	[442204] = true, -- breath of eons maneuverability
}

MuteSoundFile(4578831) -- third of https://www.wowhead.com/sound=206549/vo-100-dracthyr-soldier-dracthyr-16-m
MuteSoundFile(4578832) -- found via https://wago.tools/files?page=2&search=sound%2Fcreature%2Fdracthyr_soldier_dracthyr%2Fvo_100_dracthyr_soldier_dracthyr_
MuteSoundFile(4578971) -- visage male
MuteSoundFile(4578972) -- visage female

local frame = CreateFrame("Frame")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:SetScript("OnEvent", function(self, event, unit, castGuid, spellId, castbarId)
	if event == "UNIT_SPELLCAST_SUCCEEDED" and breaths[spellId] then
		PlaySoundFile("Interface\\AddOns\\XephFix\\Media\\Sound\\vo_100_centaur_brute_43_f.ogg")
	end
end)
