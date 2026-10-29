-- DLC Roulette. Copyright (c) 2026 -Chin. All rights reserved: no copying, sharing, changes or reuse.
-- Settings panel (LibHarvensAddonSettings): the Dungeon list, one tick per DLC dungeon, X to tick or untick,
-- and the cooldown, with the dungeons currently held back shown beside each difficulty.
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

-- The list of dungeons on cooldown, built the moment it is looked at, so it is never stale and expired ones
-- simply aren't in it. Keyboard hands a tooltip function the control and expects it to draw; gamepad uses
-- what the function returns for its own panel. One function does both.
local function CooldownPanel(activityType)
    return function(_, sender)
        local text = DR.Cooldown.Text(activityType)
        if sender then
            InitializeTooltip(InformationTooltip, sender, BOTTOMLEFT, 0, 0, TOPLEFT)
            SetTooltipText(InformationTooltip, text, ZO_TOOLTIP_INSTRUCTIONAL_COLOR)
        end
        return text
    end
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

    panel:AddSetting({ type = LHAS.ST_SECTION, label = L.COOLDOWN_SECTION })
    panel:AddSetting({
        type = LHAS.ST_SLIDER,
        label = L.COOLDOWN_HOURS,
        tooltip = L.COOLDOWN_HOURS_TIP,
        min = 0,
        max = 24,
        step = 1,
        format = "%d",
        default = 12,
        getFunction = function() return DR.sv.cooldownHours end,
        setFunction = function(value) DR.sv.cooldownHours = zo_round(value) end,
    })
    panel:AddSetting({
        type = LHAS.ST_LABEL,
        label = L.COOLDOWN_NORMAL,
        tooltip = CooldownPanel(LFG_ACTIVITY_DUNGEON),
    })
    panel:AddSetting({
        type = LHAS.ST_LABEL,
        label = L.COOLDOWN_VET,
        tooltip = CooldownPanel(LFG_ACTIVITY_MASTER_DUNGEON),
    })
    panel:AddSetting({
        type = LHAS.ST_BUTTON,
        label = L.COOLDOWN_CLEAR_LABEL,
        buttonText = L.COOLDOWN_CLEAR_BUTTON,
        clickHandler = function()
            DR.Cooldown.ClearAll()
            Settings.panel:UpdateControls()
        end,
    })
end
