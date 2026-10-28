-- DLC Roulette. Copyright (c) 2026 -chin. All rights reserved: no copying, sharing, changes or reuse.
-- Settings panel (LibHarvensAddonSettings): the Dungeon list, one tick per DLC dungeon, X to tick or untick.
local DR = DLCRoulette
local L = DR.L
local Settings = {}
DR.Settings = Settings

local LHAS

local function SetAll(included)
    for _, dungeon in ipairs(DR.Dungeons.List()) do
        DR.sv.excluded[dungeon.zoneId] = (not included) or nil
    end
    Settings.panel:UpdateControls()
end

-- Built on the first loading screen, when the Dungeon Finder knows every dungeon.
function Settings.Init()
    LHAS = LibHarvensAddonSettings
    if not LHAS then
        CHAT_ROUTER:AddSystemMessage(L.NO_SETTINGS_LIB)
        return
    end
    local panel = LHAS:AddAddon("DLC Roulette", { allowDefaults = true, allowRefresh = true })
    Settings.panel = panel
    panel:AddSetting({ type = LHAS.ST_SECTION, label = L.LIST_SECTION })
    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = L.ALL_LABEL,
        buttonText = L.ALL_BUTTON,
        clickHandler = function() SetAll(true) end,
    })
    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = L.NONE_LABEL,
        buttonText = L.NONE_BUTTON,
        clickHandler = function() SetAll(false) end,
    })
    for _, dungeon in ipairs(DR.Dungeons.List()) do
        local zoneId = dungeon.zoneId
        panel:AddSetting({
            type = LHAS.ST_CHECKBOX,
            label = dungeon.name,
            default = true,
            getFunction = function() return not DR.sv.excluded[zoneId] end,
            setFunction = function(value) DR.sv.excluded[zoneId] = (not value) or nil end,
        })
    end
end
