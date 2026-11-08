-- Saved variable validation and migrations from older versions.
local BEV = BetterEffectViewer

local VALID_ENUMS = {
    filterMode = { none = true, whitelist = true, blacklist = true },
    sortMode = { shortest = true, longest = true, newest = true, oldest = true },
    performanceMode = { balanced = true, low = true, ultra = true },
    alignment = { left = true, center = true, right = true },
    groupOrder = { buffsFirst = true, debuffsFirst = true },
}

local function copyEnabled(source, target)
    for abilityId, isEnabled in pairs(source) do
        if isEnabled then
            target[abilityId] = true
        end
    end
end

function BEV:MigrateSavedVars()
    local sv, defaults = self.sv, self.defaults

    -- Filter lists: seed only on a fresh install, never re-seed a list the user emptied.
    for listName, seed in pairs({ whitelist = self.DEFAULT_WHITELIST, blacklist = self.DEFAULT_BLACKLIST }) do
        if type(sv[listName]) ~= "table" then
            sv[listName] = {}
            copyEnabled(seed, sv[listName])
        end
    end

    -- v1.x stored the lists under pveLayout.
    for _, layoutKey in ipairs({ "pveLayout", "pvpLayout" }) do
        local layout = sv[layoutKey]
        if type(layout) ~= "table" then
            layout = {}
            sv[layoutKey] = layout
        end
        for _, listName in ipairs({ "whitelist", "blacklist" }) do
            if type(layout[listName]) == "table" then
                copyEnabled(layout[listName], sv[listName])
                layout[listName] = nil
            end
        end
        for field, value in pairs(defaults[layoutKey]) do
            if type(layout[field]) ~= "number" then
                layout[field] = value
            end
        end
    end

    for key, valid in pairs(VALID_ENUMS) do
        if not valid[sv[key]] then
            sv[key] = defaults[key]
        end
    end

    -- v2.0 anchors the window by its top edge instead of its centre, so rows grow
    -- downward without shifting the target name. Convert the old centre offset.
    if (sv.positionVersion or 1) < 2 then
        sv.offsetY = (sv.offsetY or defaults.offsetY) - 40
        sv.positionVersion = 2
    end

    -- Keys from v1.x that no longer do anything.
    sv.iconSize = nil
    sv.fontSize = nil
    sv.targetSwitchDelay = nil
end
