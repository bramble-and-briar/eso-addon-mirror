local clock = 0
local combat = false
local targetExists = false
local buffs = { player = {}, reticleover = {} }
local controls, events, messages = {}, {}, {}
local rawEvents = {}
local panel = {}
local saved
local uiMode, cameraMode = false, false
local stickX, stickY = 0, 0

TOPLEFT, LEFT, RIGHT, BOTTOM = 1, 2, 3, 4
CENTER, DT_HIGH, GAMEPAD_INCLUDE_DEADZONE = 15, 16, 17
CT_BACKDROP, CT_TEXTURE, CT_LABEL = 5, 6, 7
DL_OVERLAY, TEXT_ALIGN_CENTER, MOUSE_BUTTON_INDEX_LEFT = 8, 9, 1
EVENT_ADD_ON_LOADED, EVENT_PLAYER_COMBAT_STATE = 10, 11
EVENT_RETICLE_TARGET_CHANGED, EVENT_EFFECT_CHANGED, EVENT_PLAYER_ACTIVATED = 12, 13, 14
InformationTooltip = {}
SLASH_COMMANDS = {}

local methods = {}
function methods:SetHandler(name, callback) self.handlers[name] = callback end
function methods:SetAnchor(_, _, _, x, y) self.x, self.y = x, y end
function methods:GetLeft() return self.x end
function methods:GetTop() return self.y end
function methods:SetText(text) self.text = text end
function methods:SetColor(r, g, b, a) self.color = { r, g, b, a } end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetHidden(hidden) self.hidden = hidden end
function methods:SetMouseEnabled(enabled) self.mouse = enabled end
function methods:SetDimensions(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
setmetatable(methods, { __index = function() return function() end end })
local function control(name, parent)
    local item = setmetatable({ handlers = {}, parent = parent, x = 0, y = 0 }, { __index = methods })
    if name then controls[name] = item end
    return item
end
GuiRoot = control("GuiRoot")
GuiRoot:SetDimensions(1920, 1080)
WINDOW_MANAGER = {
    CreateTopLevelWindow = function(_, name) return control(name) end,
    CreateControl = function(_, name, parent, kind)
        local item = control(name, parent)
        if kind == CT_LABEL then
            parent.labels = rawget(parent, "labels") or {}
            table.insert(parent.labels, item)
        end
        return item
    end,
}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, callback)
        events[name] = callback
        rawEvents[event] = callback
        -- Single-event UI tests advance the scheduled tick; named callbacks allow unflushed bursts.
        events[event] = function(...)
            callback(...)
            if events.tick and (event == EVENT_EFFECT_CHANGED or event == EVENT_RETICLE_TARGET_CHANGED
                or event == EVENT_COMBAT_EVENT or event == EVENT_UNIT_DEATH_STATE_CHANGED or event == EVENT_GROUP_UPDATE) then
                events.tick()
            end
        end
    end,
    UnregisterForEvent = function(_, _, event) events[event] = nil end,
    RegisterForUpdate = function(_, _, interval, callback)
        if interval == 100 then events.tick = callback
        elseif interval == 16 then events.move = callback
        else error("Unexpected interval") end
    end,
    UnregisterForUpdate = function(_, name) if name == "LiveBuffUptimeMove" then events.move = nil end end,
}
SCENE_MANAGER = {
    IsInUIMode = function() return uiMode end,
    SetInUIMode = function(_, value) uiMode = value end,
}
function IsGameCameraUIModeActive() return cameraMode end
function SetGameCameraUIMode(value) cameraMode = value end
function GetGamepadRightStickX() return stickX end
function GetGamepadRightStickY() return stickY end
LibHarvensAddonSettings = {
    ST_CHECKBOX = 1, ST_BUTTON = 2, ST_SECTION = 3, ST_EDIT = 4, ST_DROPDOWN = 5, ST_SLIDER = 6,
    AddAddon = function(_, title) assert(title == "LiveBuffUptime"); return panel end,
}
function panel:RemoveAllSettings() self.descriptors = {} end
function panel:AddSettings(descriptors) self.descriptors = descriptors; return descriptors end
ZO_SavedVars = { NewAccountWide = function(_, _, _, _, defaults) saved = defaults; return saved end }
function GetFrameTimeSeconds() return clock end
function GetAbilityName(id) return id > 0 and "Effect " .. id or "" end
function GetAbilityIcon(id) return "icon" .. id .. ".dds" end
function zo_strformat(_, text) return text end
function DoesUnitExist(unit) return unit == "player" or targetExists end
function AreUnitsCurrentlyAllied() return false end
function IsUnitDead() return false end
function IsUnitInCombat() return combat end
function GetNumBuffs(unit) return #buffs[unit] end
function GetUnitBuffInfo(unit, index)
    local b = buffs[unit][index]
    return "Effect", b[2], b[3], index, 1, GetAbilityIcon(b[1]), nil, nil, nil, nil, b[1]
end
function zo_callLater(callback) callback() end
function d(message) messages[#messages + 1] = message end
function InitializeTooltip() end
function SetTooltipText() end
function ClearTooltip() end
local function setting(label)
    for _, descriptor in ipairs(panel.descriptors) do
        if descriptor.label == label then return descriptor end
    end
    error("Missing setting: " .. label)
end

dofile("Uptime.lua")
dofile("GroupUptime.lua")
dofile("Aliases.lua")
dofile("Cooldowns.lua")
dofile("Diagnostics.lua")
dofile("StackUptime.lua")
dofile("LiveUptime.lua")
dofile("CombatBridge.lua")
dofile("LiveBuffUptime.lua")
events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
setting("Effekt-ID").setFunction("bad")
setting("Tracker hinzufuegen").clickHandler()
assert(#saved.trackers == 0 and #messages == 2)
setting("Effekt-ID").setFunction("123")
setting("Tracker hinzufuegen").clickHandler()
setting("Tracker hinzufuegen").clickHandler()
assert(#saved.trackers == 1)
setting("Einheit").setFunction(nil, nil, { data = "reticleover" })
setting("Tracker hinzufuegen").clickHandler()
assert(#saved.trackers == 2)
local playerWindow = controls.LiveBuffUptimeTracker1
local targetWindow = controls.LiveBuffUptimeTracker2
for _, descriptor in ipairs(panel.descriptors) do
    assert(descriptor.label ~= "Position X" and descriptor.label ~= "Position Y")
    assert(descriptor.label ~= "Anzeige aktiv")
    assert(descriptor.label ~= "Positionen entsperren")
    assert(descriptor.label ~= "Uptime zuruecksetzen")
    if descriptor.label == "Move UI" then
        assert(descriptor.buttonText == "Icon verschieben")
    end
end
assert(setting("Groesse") and setting("Move UI"))
buffs.player = { { 123, -5, 5 }, { 123, -3, 8 } }
targetExists = true
buffs.reticleover = { { 123, -2, 3 } }
combat = true
events[EVENT_PLAYER_COMBAT_STATE](nil, true)
clock = 2
events.tick()
assert(playerWindow.labels[1].text == "6.0")
assert(playerWindow.labels[2].text == "100.0 %")
assert(targetWindow.labels[1].text == "1.0")
clock = 3
targetExists = false
events[EVENT_RETICLE_TARGET_CHANGED]()
clock = 6
events.tick()
assert(targetWindow.labels[2].text == "50.0 %")
assert(targetWindow.labels[1].text == "--")
clock = 8
combat = false
events[EVENT_PLAYER_COMBAT_STATE](nil, false)
clock = 12
events.tick()
assert(playerWindow.labels[2].text == "100.0 %")
assert(targetWindow.labels[2].text == "37.5 %")
SLASH_COMMANDS["/lbu"]("move")
assert(playerWindow.mouse == true)
playerWindow.x, playerWindow.y = 440, 550
playerWindow.handlers.OnMoveStop()
assert(saved.trackers[1].x == 440 and saved.trackers[1].y == 550)
SLASH_COMMANDS["/lbu"]("move")
assert(playerWindow.mouse == false)
assert(not uiMode and not cameraMode and events.move == nil)

-- Match Weaving Metronome: one selected frame, stick movement and 3s idle exit.
SLASH_COMMANDS["/lbu"]("move")
assert(playerWindow.mouse and not targetWindow.mouse)
assert(uiMode and cameraMode and not controls.LiveBuffUptimeMoveOverlay.hidden)
stickX, stickY = 1, 1
events.move()
assert(saved.trackers[1].x == 462 and saved.trackers[1].y == 528)
stickX, stickY = 0, 0
clock = 14.9
events.move()
assert(playerWindow.mouse)
clock = 15
events.move()
assert(not playerWindow.mouse and events.move == nil)
assert(controls.LiveBuffUptimeMoveOverlay.hidden and not uiMode and not cameraMode)

-- A held mouse drag must not time out, even without coordinate changes.
SLASH_COMMANDS["/lbu"]("move")
playerWindow.handlers.OnMouseDown(playerWindow, MOUSE_BUTTON_INDEX_LEFT)
clock = 20
events.move()
assert(playerWindow.mouse)
playerWindow.handlers.OnMouseUp(playerWindow, MOUSE_BUTTON_INDEX_LEFT)
clock = 23
events.move()
assert(not playerWindow.mouse)

-- Per-tracker Move UI selects the correct icon and preserves an existing cursor.
local moveButtons = {}
for _, descriptor in ipairs(panel.descriptors) do
    if descriptor.buttonText == "Icon verschieben" then table.insert(moveButtons, descriptor) end
end
assert(#moveButtons == 2, "Each tracker must retain its Move UI button")
uiMode, cameraMode = true, true
moveButtons[2].clickHandler()
assert(targetWindow.mouse and not playerWindow.mouse)
clock = 26
events.move()
assert(not targetWindow.mouse and uiMode and cameraMode)
uiMode, cameraMode = false, false
setting("Tracker entfernen").clickHandler()
assert(#saved.trackers == 1 and playerWindow.hidden)
combat = true
events[EVENT_PLAYER_COMBAT_STATE](nil, true)
assert(targetWindow.labels[2].text == "0.0 %")
print("Addon: configuration, combat, target loss, freeze, movement, 3s timeout, held drag, selection and cursor restoration passed")
return {
    events = events, rawEvents = rawEvents, controls = controls, panel = panel, setting = setting, messages = messages,
    setClock = function(value) clock = value end,
    setCombat = function(value) combat = value end,
    setBuffs = function(unit, value) buffs[unit] = value end,
    saved = function() return saved end,
}
