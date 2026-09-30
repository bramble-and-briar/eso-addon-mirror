BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

Addon.Menu = Addon.Menu or {}
local Menu = Addon.Menu

local MODE_ITEMS = {
    { name = "PvE (Per-Skill)", data = "pve" },
    { name = "PvP (Grouped)", data = "pvp" },
    { name = "Dual-Bar HUD", data = "hud" },
}

local function GetModeName()
    for _, item in ipairs(MODE_ITEMS) do
        if item.data == Addon.sv.mode then return item.name end
    end
    return "Dual-Bar HUD"
end

local function ResolveMode(name, item)
    if type(item) == "table" and item.data then return item.data end
    for _, candidate in ipairs(MODE_ITEMS) do
        if candidate.name == name then return candidate.data end
    end
    return "hud"
end

local function AddSlotToggle(settings, lib, hotbar, slot)
    local settingsKey = hotbar == HOTBAR_CATEGORY_PRIMARY and "frontSlots" or "backSlots"
    local barName = hotbar == HOTBAR_CATEGORY_PRIMARY and "Front" or "Back"
    local positionName = string.format("Skill %d", slot - 2)
    settings:AddSetting({
        type = lib.ST_CHECKBOX,
        label = string.format("%s %s", barName, positionName),
        tooltip = string.format("Track %s on the %s bar in Dual-Bar HUD mode.",
            string.lower(positionName), string.lower(barName)),
        default = true,
        getFunction = function() return Addon.sv[settingsKey][slot] ~= false end,
        setFunction = function(value)
            Addon.sv[settingsKey][slot] = value == true
            Addon.HUD:Refresh()
            Addon.Tracker:RefreshScheduler()
        end,
    })
end

function Menu:Initialize()
    local lib = LibHarvensAddonSettings
    if not lib or type(lib.AddAddon) ~= "function" then
        Addon:Log("LibHarvensAddonSettings unavailable; settings menu not registered", true)
        return
    end
    if not lib.ST_DROPDOWN or not lib.ST_SLIDER
        or not lib.ST_CHECKBOX or not lib.ST_BUTTON then
        Addon:Log("Required console settings controls are unavailable", true)
        return
    end

    local settings = lib:AddAddon("BackBarTimer", {
        allowDefaults = true,
        allowRefresh = false,
    })
    if not settings or type(settings.AddSetting) ~= "function" then return end

    settings:AddSetting({
        type = lib.ST_DROPDOWN,
        label = "Mode",
        tooltip = "Choose a legacy BackBarTimer alert mode or the Dual-Bar HUD.",
        items = MODE_ITEMS,
        default = "Dual-Bar HUD",
        getFunction = GetModeName,
        setFunction = function(_, name, item)
            Addon.sv.mode = ResolveMode(name, item)
            Addon.State.clusterAlerted = {}
            Addon.Tracker:OnCadenceSettingsChanged()
            Addon.HUD:Refresh()
        end,
    })

    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Legacy alert lead time",
        tooltip = "Seconds before expiry for PvE and PvP alerts. Dual-Bar HUD always changes at 2 seconds.",
        min = 1, max = 10, step = 1,
        default = 2,
        getFunction = function() return tonumber(Addon.sv.leadSeconds) or 2 end,
        setFunction = function(value) Addon.sv.leadSeconds = value end,
        unit = "s",
        format = "%d",
    })

    if lib.ST_SECTION then
        settings:AddSetting({ type = lib.ST_SECTION, label = "Dual-Bar Skill Tracking" })
    end
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        AddSlotToggle(settings, lib, HOTBAR_CATEGORY_BACKUP, slot)
    end
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        AddSlotToggle(settings, lib, HOTBAR_CATEGORY_PRIMARY, slot)
    end

    if lib.ST_SECTION then
        settings:AddSetting({ type = lib.ST_SECTION, label = "Dual-Bar Countdown" })
    end
    settings:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Show full skill countdown",
        tooltip = "Show each qualifying skill prompt for its full tracked duration. When off, the custom countdown start time is used.",
        default = true,
        getFunction = function() return Addon.sv.hudFullCountdown == true end,
        setFunction = function(value)
            Addon.sv.hudFullCountdown = value == true
            Addon.HUD:Refresh()
        end,
    })
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Custom countdown start",
        tooltip = "When full countdown is off, choose how many seconds before expiry the button prompt appears.",
        min = 3, max = 60, step = 1,
        default = 10,
        getFunction = function() return tonumber(Addon.sv.hudCountdownSeconds) or 10 end,
        setFunction = function(value)
            Addon.sv.hudCountdownSeconds = value
            Addon.HUD:Refresh()
        end,
        unit = "s",
        format = "%d",
    })

    if lib.ST_SECTION then
        settings:AddSetting({ type = lib.ST_SECTION, label = "Cadence Prompts" })
    end
    settings:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Block cadence",
        tooltip = "Show a 1-second count-in followed by the faction shield once per second. The first detected block can start the cadence.",
        default = false,
        getFunction = function() return Addon.sv.blockCadence == true end,
        setFunction = function(value)
            Addon.sv.blockCadence = value == true
            Addon.Tracker:OnCadenceSettingsChanged()
        end,
    })
    settings:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Light-attack cadence",
        tooltip = "Show a 1-second count-in followed by the front-hand weapon once per second. The first detected light attack starts the cadence.",
        default = true,
        getFunction = function() return Addon.sv.lightCadence == true end,
        setFunction = function(value)
            Addon.sv.lightCadence = value == true
            Addon.Tracker:OnCadenceSettingsChanged()
        end,
    })

    if lib.ST_SECTION then
        settings:AddSetting({ type = lib.ST_SECTION, label = "HUD Layout" })
    end
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "HUD scale",
        min = 50, max = 300, step = 5,
        default = 100,
        getFunction = function() return math.floor((tonumber(Addon.sv.hudScale) or 1.0) * 100) end,
        setFunction = function(value)
            Addon.sv.hudScale = value / 100
            Addon.HUD:ApplySettings()
        end,
        unit = "%",
        format = "%d",
    })
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Left inset",
        min = 0, max = 1000, step = 10,
        default = 500,
        getFunction = function() return tonumber(Addon.sv.leftInset) or 500 end,
        setFunction = function(value) Addon.sv.leftInset = value; Addon.HUD:ApplySettings() end,
        unit = "px",
        format = "%d",
    })
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Left vertical offset",
        min = -500, max = 500, step = 10,
        default = -50,
        getFunction = function() return tonumber(Addon.sv.leftY) or -50 end,
        setFunction = function(value) Addon.sv.leftY = value; Addon.HUD:ApplySettings() end,
        unit = "px",
        format = "%d",
    })
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Right inset",
        min = 0, max = 1000, step = 10,
        default = 700,
        getFunction = function() return tonumber(Addon.sv.rightInset) or 700 end,
        setFunction = function(value) Addon.sv.rightInset = value; Addon.HUD:ApplySettings() end,
        unit = "px",
        format = "%d",
    })
    settings:AddSetting({
        type = lib.ST_SLIDER,
        label = "Right vertical offset",
        min = -500, max = 500, step = 10,
        default = -50,
        getFunction = function() return tonumber(Addon.sv.rightY) or -50 end,
        setFunction = function(value) Addon.sv.rightY = value; Addon.HUD:ApplySettings() end,
        unit = "px",
        format = "%d",
    })

    if lib.ST_SECTION then
        settings:AddSetting({ type = lib.ST_SECTION, label = "Diagnostics" })
    end
    settings:AddSetting({
        type = lib.ST_CHECKBOX,
        label = "Debug mode",
        default = false,
        getFunction = function() return Addon.sv.debug == true end,
        setFunction = function(value) Addon.sv.debug = value == true end,
    })
    settings:AddSetting({
        type = lib.ST_BUTTON,
        label = "Rebuild slot cache",
        buttonText = "Rebuild",
        clickHandler = function() Addon.Tracker:OnLayoutChanged() end,
    })

    if lib.ST_LABEL then
        settings:AddSetting({
            type = lib.ST_LABEL,
            label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n"
                .. "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
        })
    end
end

