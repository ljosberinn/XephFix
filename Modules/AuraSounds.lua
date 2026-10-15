local addonName, Private = ...

table.insert(Private.LoginFnQueue, function()
    if not XephUISaved.AuraSounds then
        return
    end

    ---@param auras table<number, number>
    ---@param soundFileName string
    local function RegisterAuraSound(auras, soundFileName)
        for _, aura in ipairs(auras) do
            C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added, {
                unitToken = "player",
                spellID = aura,
                soundFileName = soundFileName,
                outputChannel = "Master"
            })
        end

        print("registered " .. #auras .. " auras for " .. soundFileName)
    end

    do
        local huh = "Interface\\AddOns\\XephUI\\Media\\Sound\\Gasp.ogg"
        local auras = {
            6940,   -- Blessing of Sacrifice
            102342, -- Ironbark
            33206,  -- Pain Suppression
            47788,  -- Guardian Spirit
            116849, -- Life Cocoon
            357170, -- Time Dilation
            204018, -- Blessing of Spellwarding
            81782,  -- Power Word: Barrier
            443526, -- Premonition of Solace
            209426, -- Darkness
        }

        RegisterAuraSound(auras, huh)
    end

    do
        local wilhelmScream = "Interface\\AddOns\\XephUI\\Media\\Sound\\wilhelm.ogg"
        local auras = {
            404369, -- Augmentation: Empty Hourglass
        }

        RegisterAuraSound(auras, wilhelmScream)
    end
end)
