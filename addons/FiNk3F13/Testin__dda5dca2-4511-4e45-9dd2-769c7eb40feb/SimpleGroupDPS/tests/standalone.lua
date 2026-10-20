-- Boot the complete addon with no SimpleWarhornTimer or LibCombat globals.
local clock, inCombat = 0, false
local windows, events, updates, menu, saved, logs = {}, {}, {}, {}, {}, {}
ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE = 1, 2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP = 1, 3, 4
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_GROUP_UPDATE = "load", "activate", "group"
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = "damage", "combat", "boss", "effect"
local function control()
    return setmetatable({ left = 0, top = 0, handlers = {} }, { __index = function(_, name)
        if not name:match("^[A-Z]") then return nil end
        if name == "GetLeft" then return function(self) return self.left end end
        if name == "GetTop" then return function(self) return self.top end end
        return function(self, value, ...)
            if name == "SetText" then self.text = value end
            if name == "SetHidden" then self.hidden = value end
            if name == "SetDimensions" then self.width = value; self.height = ... end
            if name == "SetScale" then self.scale = value end
            if name == "SetMovable" then self.movable = value end
            if name == "SetAnchor" then local args = { value, ... }; self.left, self.top = args[4] or 0, args[5] or 0 end
            if name == "SetHandler" then self.handlers[value] = ... end
        end
    end })
end
WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name) local c = control(); windows[name] = c; return c end,
    CreateControl = function() return control() end,
}
GuiRoot = control()
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return inCombat end
function DoesUnitExist() return false end
function GetUnitDisplayName() return "@Me" end
function IsUnitGrouped() return false end
function GetGamepadRightStickX() return 0 end
function GetGamepadRightStickY() return 0 end
function d(message) logs[#logs + 1] = message end
SLASH_COMMANDS = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, fn) events[name..":"..event] = fn end,
    UnregisterForEvent = function(_, name, event) events[name..":"..event] = nil end,
    RegisterForUpdate = function(_, name, _, fn) updates[name] = fn end,
    UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
ZO_SavedVars = { NewAccountWide = function(_, namespace, _, _, defaults)
    assert(namespace == "SimpleGroupDPS_SavedVariables", "private saved variable namespace")
    for key, value in pairs(defaults) do saved[key] = value end
    return saved
end }
LibHarvensAddonSettings = {
    ST_SECTION = 1, ST_CHECKBOX = 2, ST_SLIDER = 3, ST_LABEL = 4, ST_BUTTON = 5,
    AddAddon = function(_, name)
        assert(name == "SimpleGroupDPS", "separate settings menu")
        return { AddSettings = function(_, entries)
            for _, entry in ipairs(entries) do menu[entry.label] = entry end
        end }
    end,
}
for _, file in ipairs({ "BattleScrollsBridge.lua", "DamageMeter.lua", "DPSPanel.lua", "SimpleGroupDPS.lua" }) do dofile(file) end
assert(SimpleWarhornTimer_DamageMeter == nil and LibCombat == nil)
events["SimpleGroupDPS:load"](nil, "SimpleGroupDPS")
local window = windows.SimpleGroupDPSWindow
assert(window and window.hidden, "standalone addon starts without buff addon")
menu["Move UI (Verschieben)"].setFunction(true)
assert(not window.hidden and window.movable and updates.SimpleGroupDPSMove)
for i = 1, 300 do updates.SimpleGroupDPSMove() end
assert(window.movable, "Move UI persists until saved")
menu["Breite der DPS-Anzeige"].setFunction(420)
menu["Schriftgroesse der DPS-Anzeige"].setFunction(14)
menu["Zeilenabstand (kleiner = enger)"].setFunction(0)
menu["Gesamtgroesse der Anzeige"].setFunction(1.8)
assert(window.width == 420 and window.scale == 1.8 and saved.dpsFontSize == 14)
window.left, window.top = 900, 200
window.handlers.OnMoveStop()
menu["Position speichern / Move UI beenden"].clickHandler()
assert(saved.posX == 900 and saved.posY == 200 and not window.movable)
assert(updates.SimpleGroupDPSMove == nil)
clock, inCombat = 1000, true
events["SimpleGroupDPSDamageState:combat"](nil, true)
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Enemy", 2, 10000, nil, nil, nil, 99, 10)
clock = 2000
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Enemy", 2, 2000, nil, nil, nil, 99, 10)
updates.SimpleGroupDPSUI()
assert(not window.hidden and window.swtGroupDPSLabels[1].text == "Me")
clock, inCombat = 5000, false
events["SimpleGroupDPSDamageState:combat"](nil, false)
assert(saved.lastSummary.dps == 12000 and saved.lastSummary.damageTotal == 12000)
assert(#logs == 1 and logs[1]:find("SimpleGroupDPS", 1, true))
assert(not window.hidden, "last result remains visible")
events["SimpleGroupDPSConnect:activate"]()
menu["DPS-Anzeige aktiv"].setFunction(false)
assert(window.hidden and updates.SimpleGroupDPSUI == nil)
assert(updates.SimpleGroupDPSSend, "sharing loop is independent of window visibility")
menu["Anzeige-Layout zuruecksetzen"].clickHandler()
assert(saved.dpsWidth == 520 and saved.dpsFontSize == 22 and saved.dpsRowSpacing == 8)
assert(saved.scale == 1 and saved.posX == 720 and saved.posY == 300)
assert(type(SLASH_COMMANDS["/sgdmove"]) == "function")
print("PASS: full standalone startup, private menu/storage, Move UI, layout, combat summary and optional dependencies")
