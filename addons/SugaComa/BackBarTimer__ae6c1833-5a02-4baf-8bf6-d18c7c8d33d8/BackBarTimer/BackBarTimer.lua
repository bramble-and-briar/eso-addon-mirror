BackBarTimer = BackBarTimer or {}
local Addon = BackBarTimer

local function EnsureSlotSettings(name)
    Addon.sv[name] = Addon.sv[name] or {}
    for slot = Addon.Config.firstSlot, Addon.Config.lastSlot do
        if Addon.sv[name][slot] == nil then Addon.sv[name][slot] = true end
    end
end

function Addon:Initialize()
    if self.initialized then return end
    self.sv = ZO_SavedVars:NewAccountWide(
        self.Config.savedVariablesName,
        self.Config.savedVariablesVersion,
        nil,
        self.Defaults
    )
    EnsureSlotSettings("frontSlots")
    EnsureSlotSettings("backSlots")

    self.State:Reset()
    self.HUD:Initialize()
    self.Tracker:Initialize()
    self.Menu:Initialize()
    self.initialized = true
    self:Log("Standalone milestone initialized", true)
end

function Addon:OnAddOnLoaded(_, addonName)
    if addonName ~= self.Config.addonName then return end
    EVENT_MANAGER:UnregisterForEvent("BackBarTimer_Loaded", EVENT_ADD_ON_LOADED)
    self:Initialize()
end

EVENT_MANAGER:RegisterForEvent("BackBarTimer_Loaded", EVENT_ADD_ON_LOADED,
    function(...) Addon:OnAddOnLoaded(...) end)

SLASH_COMMANDS["/bbtdebug"] = function()
    if not Addon.sv then return end
    Addon.sv.debug = not Addon.sv.debug
    Addon:Log("Debug mode " .. (Addon.sv.debug and "ON" or "OFF"), true)
end

SLASH_COMMANDS["/bbtmode"] = function()
    if not Addon.sv then return end
    local nextMode = { hud = "pve", pve = "pvp", pvp = "hud" }
    Addon.sv.mode = nextMode[Addon.sv.mode] or "hud"
    Addon.State.clusterAlerted = {}
    Addon.Tracker:OnCadenceSettingsChanged()
    Addon.HUD:Refresh()
    Addon:Log("Mode set to " .. tostring(Addon.sv.mode), true)
end

SLASH_COMMANDS["/bbtrebuild"] = function()
    if Addon.Tracker then Addon.Tracker:OnLayoutChanged() end
end

