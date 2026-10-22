-- Boot the complete addon with no SimpleWarhornTimer or LibCombat globals.
local clock, inCombat = 0, false
local windows, events, updates, menu, saved, logs, intervals = {}, {}, {}, {}, {}, {}, {}
ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE = 1, 2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP = 1, 3, 4
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_GROUP_UPDATE = "load", "activate", "group"
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = "damage", "combat", "boss", "effect"
local function control()
    return setmetatable({ left = 0, top = 0, handlers = {} }, { __index = function(_, name)
        if not name:match("^[A-Z]") then return nil end
        if name == "GetLeft" then return function(self) return self.left end end
        if name == "GetTop" then return function(self) return self.top end end
        if name == "GetWidth" then return function(self) return (self.width or 0) * (self.scale or 1) end end
        if name == "GetHeight" then return function(self) return (self.height or 0) * (self.scale or 1) end end
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
GuiRoot:SetDimensions(1920, 1080)
MOUSE_BUTTON_INDEX_LEFT = 1
local cursor, camera, stickX, stickY = false, false, 0, 0
local sceneName, sceneChanged = "hud", nil
SCENE_MANAGER = { IsInUIMode = function() return cursor end, SetInUIMode = function(_, value) cursor = value end }
function SCENE_MANAGER:GetCurrentScene() return { GetName = function() return sceneName end } end
function SCENE_MANAGER:RegisterCallback(event, callback)
    assert(event == "SceneStateChanged")
    sceneChanged = callback
end
local function showScene(name)
    sceneName = name
    sceneChanged(SCENE_MANAGER:GetCurrentScene(), "showing")
end
function IsGameCameraUIModeActive() return camera end
function SetGameCameraUIMode(value) camera = value end
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return inCombat end
function DoesUnitExist() return false end
function GetUnitDisplayName() return "@Me" end
function IsUnitGrouped() return false end
function GetGamepadRightStickX() return stickX end
function GetGamepadRightStickY() return stickY end
function d(message) logs[#logs + 1] = message end
SLASH_COMMANDS = {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, event, fn) events[name..":"..event] = fn end,
    UnregisterForEvent = function(_, name, event) events[name..":"..event] = nil end,
    RegisterForUpdate = function(_, name, interval, fn) updates[name] = fn; intervals[name] = interval end,
    UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
ZO_SavedVars = { NewAccountWide = function(_, namespace, _, _, defaults)
    assert(namespace == "SimpleGroupDPS_SavedVariables", "private saved variable namespace")
    assert(defaults.lingerSeconds == 60, "Default retention must be one minute")
    for key, value in pairs(defaults) do saved[key] = value end
    saved.showUI = false -- Old saved preference must no longer hide the display.
    saved.scale, saved.displaySizeAdjusted = 1, true -- Undo the unintended scale migration.
    saved.dpsFontSize = 14
    saved.dpsWidth = 800
    saved.lingerSeconds = 0 -- Migrate the former permanent-display option.
    saved.chatSummary = true -- Old preferences must not restore automatic chat output.
    return saved
end }
LibHarvensAddonSettings = {
    ST_SECTION = 1, ST_CHECKBOX = 2, ST_SLIDER = 3, ST_LABEL = 4, ST_BUTTON = 5, ST_DROPDOWN = 6,
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
assert(window.scale == 0.7 and saved.displaySizeAdjusted == nil and saved.posX == 720 and saved.posY == 300,
    "unintended overall enlargement is reverted without moving the display")
assert(intervals.SimpleGroupDPSUI == 300 and updates.SimpleGroupDPSSend == nil,
    "display and outgoing values share one 300ms tick")
assert(window and window.hidden, "standalone addon starts without buff addon")
assert(menu["Move UI"].type == LibHarvensAddonSettings.ST_BUTTON)
local retention = menu["Nach Kampfende anzeigen"]
assert(retention and retention.type == LibHarvensAddonSettings.ST_DROPDOWN and #retention.items == 5)
assert(not menu["Nach Kampfende anzeigen (Sekunden)"] and retention.getFunction() == "1 Minute")
assert(saved.lingerSeconds == 60, "Legacy zero must migrate to the new one-minute minimum")
for minutes, item in ipairs(retention.items) do
    assert(item.data == minutes * 60)
    retention.setFunction(nil, item.name, item)
    assert(saved.lingerSeconds == minutes * 60 and retention.getFunction() == item.name)
end
retention.setFunction(nil, nil, retention.items[1])
assert(menu["Fensterbreite"].min == 280 and menu["Fensterbreite"].max == 400 and menu["Fensterbreite"].step == 10)
assert(saved.dpsWidth == 400, "Legacy oversized width must be normalized when loading")
menu["Fensterbreite"].setFunction(800)
assert(window.width == 400 and saved.dpsWidth == 400, "Width setter must enforce the compact maximum")
menu["Fensterbreite"].setFunction(280)
assert(window.width == 280 and saved.dpsWidth == 280, "Compact width setting applies immediately and persists")
menu["Move UI"].clickHandler()
assert(not window.hidden and window.movable and updates.SimpleGroupDPSMove)
assert(cursor and camera and not windows.SimpleGroupDPSMoveOverlay.hidden)
menu["Fensterbreite"].setFunction(420)
menu["Zeilenabstand"].setFunction(0)
assert(window.width == 400 and window.scale == 0.7 and saved.dpsFontSize == 14)
menu["DPS-Zahlengröße"].setFunction(28)
assert(saved.dpsFontSize == 14 and saved.scale == 0.7 and window.width == 400,
    "DPS number control leaves name size, overall scale and width unchanged")
local menuCount = 0
for _ in pairs(menu) do menuCount = menuCount + 1 end
assert(menuCount == 6, "menu adds just the requested linger control to five existing display controls")
window.left, window.top = 900, 200
window.handlers.OnMoveStop()
updates.SimpleGroupDPSMove()
clock = 2999
updates.SimpleGroupDPSMove()
assert(window.movable, "Move UI remains open until three seconds of inactivity")
clock = 3000
updates.SimpleGroupDPSMove()
assert(saved.posX == 900 and saved.posY == 200 and not window.movable)
assert(updates.SimpleGroupDPSMove == nil and windows.SimpleGroupDPSMoveOverlay.hidden)
assert(not cursor and not camera, "original gameplay cursor state is restored")
cursor, camera = true, true
menu["Move UI"].clickHandler()
window.handlers.OnMouseDown(window, 1)
clock = 7000
updates.SimpleGroupDPSMove()
assert(window.movable, "holding a mouse drag cannot time out")
window.handlers.OnMouseUp(window, 1)
stickX, stickY = 1, -1
for i = 1, 100 do updates.SimpleGroupDPSMove() end
assert(window:GetLeft() == 1920 - window:GetWidth() and window:GetTop() == 1080 - window:GetHeight()
    and math.abs(saved.posX - window:GetLeft()) <= 0.5 and math.abs(saved.posY - window:GetTop()) <= 0.5,
    "stick movement clamps scaled dimensions to screen edges")
stickX, stickY = 0, 0
clock = 10000
updates.SimpleGroupDPSMove()
assert(not window.movable and cursor and camera, "existing menu cursor is preserved")
-- Mouse-only clients must also auto-save without controller APIs.
local readX, readY = GetGamepadRightStickX, GetGamepadRightStickY
GetGamepadRightStickX, GetGamepadRightStickY = nil, nil
menu["Move UI"].clickHandler()
clock = 13000
updates.SimpleGroupDPSMove()
assert(not window.movable, "mouse-only Move UI also ends automatically")
GetGamepadRightStickX, GetGamepadRightStickY = readX, readY
clock, inCombat = 1000, true
events["SimpleGroupDPSDamageState:combat"](nil, true)
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Enemy", 2, 10000, nil, nil, nil, 99, 10)
clock = 2000
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Enemy", 2, 2000, nil, nil, nil, 99, 10)
updates.SimpleGroupDPSUI()
assert(not window.hidden and window.swtGroupDPSLabels[1].text == "Me")
for _, name in ipairs({ "worldMap", "gamepad_worldMap", "gameMenuInGame", "inventory", "LibHarvensAddonSettingsScene", "gamepad_textChat" }) do
    showScene(name)
    assert(window.hidden, "display hides immediately in " .. name)
    updates.SimpleGroupDPSUI()
    assert(window.hidden and SimpleGroupDPS_DamageMeter:GetStats().total == 12000,
        "hidden display neither reopens on tick nor stops damage measurement")
end
menu["Move UI"].clickHandler()
assert(not window.hidden, "Move UI is visible even in addon settings")
SLASH_COMMANDS["/sgdmove"]()
assert(window.hidden, "ending Move UI restores menu hiding")
showScene("hudui")
assert(not window.hidden, "HUD cursor mode remains visible")
showScene("hud")
clock = 3500
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].swtDPSValue.text == "0:01"
    and window.swtGroupDPSLabels[1].swtDPSValue.text == "12,0 Tsd.",
    "HUD timer and DPS use the same measured damage duration")
clock = 4000
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].swtDPSValue.text == "0:01", "idle wall time cannot advance HUD beyond measured duration")
clock = 4999
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].swtDPSValue.text == "0:01", "HUD keeps the same time base during damage pauses")
local sentStats
local originalSend = SimpleGroupDPS_BattleScrolls.SendDPS
SimpleGroupDPS_BattleScrolls.SendDPS = function(_, dps) sentStats = dps end
updates.SimpleGroupDPSUI()
SimpleGroupDPS_BattleScrolls.SendDPS = originalSend
assert(sentStats == 12000, "group sending continues without DoTs and uses the correct damage window")
clock, inCombat = 5000, false
events["SimpleGroupDPSDamageState:combat"](nil, false)
assert(updates.SimpleGroupDPSDamageReset, "combat exit schedules Battle Scrolls-style finish check")
clock = clock + 150
updates.SimpleGroupDPSDamageReset()
assert(saved.lastSummary.dps == 12000 and saved.lastSummary.damageTotal == 12000
    and saved.lastSummary.damageDurationMS == 1000, "normal final DPS adds no idle combat time")
assert(saved.lastSummary.elapsedMS == nil and window.swtGroupDPSLabels[0].swtDPSValue.text == "0:01",
    "finishing saves only the common HUD/DPS/chat duration")
clock = 5500
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].swtDPSValue.text == "0:01", "result timer remains frozen after finish")
assert(#logs == 0 and saved.chatSummary == nil, "Completed fights must not print automatic chat summaries")
assert(not window.hidden, "last result remains visible")
COMBAT_UNIT_TYPE_TARGET_DUMMY = 7
clock, inCombat = 6000, true
events["SimpleGroupDPSDamageState:combat"](nil, true)
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Dummy", 7, 2000, nil, nil, nil, 99, 10)
clock = 6677
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Dummy", 7, 2319, nil, nil, nil, 99, 10)
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].swtDPSValue.text == "0:00", "dummy uses Battle Scrolls' exact subsecond clock")
clock, inCombat = 9000, false
updates.SimpleGroupDPSUI()
local dummyLive = SimpleGroupDPS_DamageMeter:GetStats()
events["SimpleGroupDPSDamageState:combat"](nil, false)
updates.SimpleGroupDPSDamageReset()
assert(saved.lastSummary.dps == dummyLive.dps and saved.lastSummary.damageDurationMS == 677
    and math.floor(saved.lastSummary.dps + 0.5) == 6380 and #logs == 0,
    "Dummy result must retain the calculation without printing a chat summary")
retention.setFunction(nil, nil, retention.items[1])
clock = 68999
updates.SimpleGroupDPSUI()
assert(not window.hidden, "result remains until selected linger duration expires")
clock = 69000
updates.SimpleGroupDPSUI()
assert(window.hidden, "result resets after one minute")
assert(SimpleGroupDPS_DamageMeter:GetStats().total == 0 and next(saved.lastSummary) == nil,
    "Expiry must clear the result and saved summary, not merely hide the window")
showScene("inventory")
showScene("hud")
assert(window.hidden, "menu roundtrip does not restart expired result timer")
menu["Move UI"].clickHandler()
assert(not window.hidden, "Move UI overrides expired result timer")
SLASH_COMMANDS["/sgdmove"]()
assert(window.hidden, "expired result stays hidden after moving")
retention.setFunction(nil, nil, retention.items[2])
assert(window.hidden, "Changing retention must not revive an already cleared result")
clock = 14000 -- Independent group-reception scenario starts with no retained result.
events["SimpleGroupDPSConnect:activate"]()
local receive
BattleScrolls = { dpsShare = { RegisterCallback = function(_, _, callback) receive = callback end } }
function DoesUnitExist(tag) return tag == "group1" end
function AreUnitsEqual(a, b) return a == b end
function GetUnitDisplayName(tag) return tag == "group1" and "@Peer" or "@Me" end
function IsUnitGrouped() return true end
events["SimpleGroupDPSConnect:activate"]()
receive("group1", { messageType = "damage", allTargetsDPS = 20000 })
assert(window.swtGroupDPSLabels[1].text == "Peer", "received group values render without waiting for a UI tick")
receive("group1", { messageType = "damage", allTargetsDPS = 20000, bossDPS = 15000 })
assert(window.swtGroupDPSLabels[0].text == "Gesamtschaden",
    "Remote boss DPS must not switch the local encounter to boss mode")
assert(window.swtGroupDPSLabels[1].swtDPSValue.text == "20,0 Tsd.",
    "Received individual DPS and boss values stay visible")
assert(window.swtGroupDPSLabels.summary.swtDPSValue.text == "20,0 Tsd.",
    "After result reset only newly received group values contribute to the fallback")
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].text == "Gesamtschaden", "Local mode survives UI ticks")
receive("group1", { messageType = "healing" })
assert(window.hidden, "Replacing the last damage metric must not revive a cleared own result")
showScene("inventory")
receive("group1", { messageType = "damage", allTargetsDPS = 20000 })
assert(window.hidden, "network update cannot reopen display while in menu")
assert(SimpleGroupDPS_BattleScrolls:GetRows()[1].dps == 20000, "group reception keeps running in menu")
showScene("hud")
assert(not window.hidden and window.swtGroupDPSLabels[1].text == "Peer", "returning from menu shows latest received data")
assert(menu["DPS-Anzeige aktiv"] == nil, "UI disable switch is removed")
assert(not window.hidden and updates.SimpleGroupDPSUI, "legacy disabled setting cannot hide the DPS display")
assert(updates.SimpleGroupDPSUI, "shared measurement/sending tick is independent of window visibility")
local keepX, keepY, keepScale = saved.posX, saved.posY, saved.scale
menu["Layout zurücksetzen"].clickHandler()
assert(saved.dpsWidth == 400 and saved.dpsFontSize == 14 and saved.dpsRowSpacing == 8)
assert(saved.dpsValueFontSize == 18 and saved.scale == keepScale and saved.posX == keepX and saved.posY == keepY,
    "reset layout preserves position and overall scale")
assert(type(SLASH_COMMANDS["/sgdmove"]) == "function")
assert(type(SLASH_COMMANDS["/sgdstatus"]) == "function")
SLASH_COMMANDS["/sgdstatus"]()
local diagnosticText = table.concat(logs, "\n")
assert(diagnosticText:find("SimpleGroupDPS 1.4.5", 1, true)
    and diagnosticText:find("Takt: 300 ms", 1, true)
    and diagnosticText:find("Letzter Schaden:", 1, true)
    and diagnosticText:find("Schadensereignisse:", 1, true),
    "runtime status identifies the installed build, refresh loop and damage-event clock")
assert(logs[#logs - 1]:find("BattleScrolls", 1, true), "status explains when local BattleScrolls owns the sender")
assert(logs[#logs]:find("empfangen", 1, true), "status includes observed incoming and queued packet counts")
clock, inCombat = 20000, true
events["SimpleGroupDPSDamageState:combat"](nil, true)
updates.SimpleGroupDPSUI()
assert(#SimpleGroupDPS_BattleScrolls:GetRows() == 1, "Starting a separate fight must preserve received peer values")
events["SimpleGroupDPSGroup:group"]()
assert(#SimpleGroupDPS_BattleScrolls:GetRows() == 1, "Unchanged group update must preserve received peer values")
function DoesUnitExist(tag) return tag == "group1" or tag == "boss1" end
function GetRawUnitName(tag) return tag == "boss1" and "Local Boss" or "" end
events["SimpleGroupDPSDamageBosses:boss"]()
clock = 21000
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 4, "Local Boss", 2, 10000, nil, nil, nil, 100, 42)
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels[0].text == "Boss-Schaden (Gesamtschaden)")
assert(window.swtGroupDPSLabels.summary.swtDPSValue.text == "10,0 Tsd. (10,0 Tsd.)")
assert(SimpleGroupDPS_DamageMeter:GetStats().bossDPS == 0)
clock = 22000
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Local Boss", 2, 4000, nil, nil, nil, 99, 42)
updates.SimpleGroupDPSUI()
assert(window.swtGroupDPSLabels.summary.swtDPSValue.text == "7,0 Tsd. (7,0 Tsd.)", "Shared local fight combines group and own damage once")
clock, inCombat = 23000, false
events["SimpleGroupDPSDamageState:combat"](nil, false)
updates.SimpleGroupDPSDamageReset()
assert(saved.lastSummary.groupDamageTotal == 14000 and saved.lastSummary.groupDPS == 7000)
receive("group1", {messageType = "damage", allTargetsDPS = 40000, bossDPS = 30000})
assert(window.swtGroupDPSLabels.summary.swtDPSValue.text == "7,0 Tsd. (7,0 Tsd.)")
clock = 42000
updates.SimpleGroupDPSUI()
assert(SimpleGroupDPS_BattleScrolls:GetRows()[1].stale, "Old peer values remain visible but stale")
function GetUnitDisplayName(tag) return tag == "group1" and "@Replacement" or "@Me" end
events["SimpleGroupDPSGroup:group"]()
assert(#SimpleGroupDPS_BattleScrolls:GetRows() == 0, "Replacement must not inherit previous member DPS")
clock, inCombat = 50000, true
events["SimpleGroupDPSDamageState:combat"](nil, true)
clock = 51000
events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Enemy", 2, 2000, nil, nil, nil, 99, 99)
clock = 300000
updates.SimpleGroupDPSUI()
assert(SimpleGroupDPS_DamageMeter:GetStats().total == 2000, "Two-minute cleanup must never reset a running encounter")
inCombat = false
events["SimpleGroupDPSDamageState:combat"](nil, false)
updates.SimpleGroupDPSDamageReset()
receive("group1", {messageType = "damage", allTargetsDPS = 20000})
clock = 419999
updates.SimpleGroupDPSUI()
assert(not window.hidden and SimpleGroupDPS_DamageMeter:GetStats().total == 2000,
    "Selected two-minute retention keeps completed results until the deadline")
showScene("inventory")
clock = 420000
updates.SimpleGroupDPSUI()
assert(SimpleGroupDPS_DamageMeter:GetStats().total == 0 and SimpleGroupDPS_DamageMeter:GetStats().durationMS == 0)
assert(next(saved.lastSummary) == nil and #SimpleGroupDPS_BattleScrolls:GetRows() == 0,
    "Two-minute cleanup must clear own and stale group results even in menus")
showScene("hud")
assert(window.hidden, "Returning to HUD cannot revive expired results")
receive("group1", {messageType = "damage", allTargetsDPS = 12345})
assert(not window.hidden and SimpleGroupDPS_BattleScrolls:GetRows()[1].dps == 12345,
    "Fresh group packets must still appear after a reset")
retention.setFunction(nil, nil, retention.items[5])
clock = 719999
updates.SimpleGroupDPSUI()
assert(not window.hidden and #SimpleGroupDPS_BattleScrolls:GetRows() == 1, "Five-minute selection retains fresh peer data until its deadline")
clock = 720000
updates.SimpleGroupDPSUI()
assert(window.hidden and #SimpleGroupDPS_BattleScrolls:GetRows() == 0, "Five-minute selection expires at 300 seconds")
print("PASS: full addon, 1-5 minute retention, legacy migration, local group totals, peer reception and active-fight protection")
