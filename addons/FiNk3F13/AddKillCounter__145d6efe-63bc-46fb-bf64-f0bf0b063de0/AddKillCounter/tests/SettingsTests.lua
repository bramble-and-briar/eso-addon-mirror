dofile("tests/IntegrationTests.lua")
local A = AddKillCounter
local checks = 0
local function eq(actual, expected, help)
    checks = checks + 1
    assert(actual == expected, (help or "Mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function near(actual, expected, help)
    checks = checks + 1
    assert(math.abs(actual - expected) < 0.001, help)
end
TOPLEFT = 1; TOPRIGHT = 2; BOTTOMLEFT = 3; BOTTOMRIGHT = 4
GuiRoot = {GetWidth = function() return 1920 end, GetHeight = function() return 1080 end}
local h = A.hud
h.x = 90; h.y = 180; h.scale = 1
function h:GetLeft() return self.x end
function h:GetTop() return self.y end
function h:GetWidth() return (self.width or 500) * self.scale end
function h:GetHeight() return 96 * self.scale end
function h:SetScale(value) self.scale = value end
function h:SetAnchor(_, _, _, x, y) self.x, self.y = x, y end
function A.hudFragment:SetHiddenForReason(_, value) self.testHidden = value end
SCENE_SHOWING = "showing"; SCENE_HIDING = "hiding"
local scenes = {}
function ZO_Scene:New(name)
    local scene = {AddFragment = function() end, AddFragmentGroup = function() end}
    function scene:RegisterCallback(_, callback) self.callback = callback end
    scenes[name] = scene
    return scene
end
KEYBIND_STRIP = {AddKeybindButtonGroup = function() end, RemoveKeybindButtonGroup = function() end}
function SCENE_MANAGER:Push(name)
    self.current = scenes[name]
    if self.current then self.current.callback(nil, SCENE_SHOWING) end
end
function SCENE_MANAGER:HideCurrentScene()
    if self.current then self.current.callback(nil, SCENE_HIDING) end
    self.current = nil
end
local updates = {}
function EVENT_MANAGER:RegisterForUpdate(name, interval, fn) updates[name] = fn end
function EVENT_MANAGER:UnregisterForUpdate(name) updates[name] = nil end
local now, sx, sy = 10, 0, 0
function GetFrameTimeSeconds() return now end
function GetGamepadRightStickX() return sx end
function GetGamepadRightStickY() return sy end
local settings = {}
LibHarvensAddonSettings = {ST_SECTION = 1, ST_LABEL = 2, ST_BUTTON = 3, ST_CHECKBOX = 4, ST_SLIDER = 5}
function LibHarvensAddonSettings:AddAddon(name, options)
    eq(name, "Add Kill Counter", "Library registration")
    eq(options.allowRefresh, true, "Dynamic labels enabled")
    return {AddSetting = function(_, descriptor) settings[#settings + 1] = descriptor end}
end
dofile("Settings.lua")
A:CreateSettings()
local function find(label)
    for _, descriptor in ipairs(settings) do if descriptor.label == label then return descriptor end end
    error("Missing setting: " .. label)
end
eq(find("Move UI").type, LibHarvensAddonSettings.ST_BUTTON, "Movement button")
find("Kills erfassen").setFunction(false)
eq(A.sv.enabled, false, "Library checkbox persistence")
find("Kills erfassen").setFunction(true)
eq(A.sv.enabled, true, "Resume")
find("Zählergröße").setFunction(1.25)
near(A.sv.hudScale, 1.25, "Scale saved")
local x, y = A:ClampHUDPosition(5000, -100)
near(x, 1920 - 272 * 1.25, "Right edge uses text width plus padding at the selected scale")
near(y, 0, "Negative position clamps")
local opened
local originalOpen = A.Open
function A:Open(view) opened = view or {kind = "home"} end
-- There are multiple Statistik actions: check summary and dynamic total text.
local summary
for _, descriptor in ipairs(settings) do
    if descriptor.type == LibHarvensAddonSettings.ST_LABEL and descriptor.label():find("Getötete Adds", 1, true) then summary = descriptor end
end
A.sv.stats.total = 123
eq(summary.label():find("123", 1, true) ~= nil, true, "Live total label")
A.Open = originalOpen
A.sv.showHUD = false; A.sv.combatOnly = true; A.sv.hudCustom = false
A:StartHUDMove()
eq(A.moving, true, "Move scene starts")
eq(A.hudFragment.testHidden, false, "Movement preview overrides hidden HUD")
local startX, startY = A.sv.hudX, A.sv.hudY
sx, sy = 1, 1; now = now + 0.016; A:UpdateHUDMove()
near(A.sv.hudX, startX + 11.52, "Right stick moves horizontally")
near(A.sv.hudY, startY - 11.52, "Right stick up moves vertically")
sx, sy = 0, 0; now = now + 3.01; A:UpdateHUDMove()
eq(A.moving, false, "Three seconds idle auto-saves")
eq(A.sv.hudCustom, true, "Custom position retained")
eq(updates[A.name .. "MoveHUD"], nil, "Movement timer stopped")
eq(A.hudFragment.testHidden, true, "Normal HUD visibility restored")
local savedX = A.sv.hudX
A:StartHUDMove(); sx = -1; now = now + 0.016; A:UpdateHUDMove()
A.moveKeybinds[2].callback()
near(A.sv.hudX, savedX, "Cancel restores saved position")
eq(A.moving, false, "Cancel ends movement")
A:StartHUDMove(); now = now + 0.016; A:UpdateHUDMove()
SCENE_MANAGER:HideCurrentScene()
near(A.sv.hudX, savedX, "Interrupted scene restores saved position")
eq(updates[A.name .. "MoveHUD"], nil, "Interrupted scene cleans timer")
find("Position").clickHandler()
eq(A.sv.hudCustom, false, "Position reset uses preset")
eq(A.sv.stats.total, 123, "Position reset preserves statistics")
print("Settings/movement: " .. checks .. " checks passed (mock ESO API)")
