local _, Private = ...

table.insert(Private.LoginFnQueue, function()
    if not Private.IsXeph then
        return
    end

    local gossipIdsToAutoSelect = {
        -- Pit of Saron
        [136624] = true,
        [136271] = true,
        [136316] = true,
        [136280] = true,
        [136301] = true,
        [138618] = true,
        -- Algeth'ar Academy
        [107065] = true, -- crit
        [107081] = true, -- haste
        [107082] = true, -- mastery
        [107083] = true, -- healing taken
        [107088] = true, -- versatility
        -- Maisara Caverns
        [137387] = true, -- cooking stew
        -- Nexus-Point Xenas
        [137133] = true, -- tripwire
    }

    local frame = CreateFrame("Frame")

    frame:RegisterEvent("GOSSIP_SHOW")

    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "GOSSIP_SHOW" then
            local options = C_GossipInfo.GetOptions()

            for i = 1, #options do
                if gossipIdsToAutoSelect[options[i].gossipOptionID] then
                    C_GossipInfo.SelectOption(i, "")
                    return
                end
            end
        end
    end)
end)
