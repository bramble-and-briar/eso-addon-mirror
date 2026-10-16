local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
setup.begin(1000)
setup.raw(1000, 2, EFFECT_RESULT_GAINED, 1010)
setup.damage(1002)
local config = env.saved().trackers[1]
local before = env.controls.LiveBuffUptimeTracker1.labels[2].text
local create = WINDOW_MANAGER.CreateControl
function WINDOW_MANAGER:CreateControl(name, parent, kind)
    local control = create(self, name, parent, kind)
    if kind == CT_BACKDROP then
        function control:SetCenterColor(r, g, b, a) self.centerColor = {r, g, b, a} end
    end
    return control
end
assert(not env.controls.LiveBuffUptimeGroupPanel1, "Disabled panels must create no HUD controls")
assert(env.setting("Panel-Tracker").getFunction():find("61771", 1, true))
env.setting("Gruppenpanel anzeigen").setFunction(true)
local panel = assert(env.controls.LiveBuffUptimeGroupPanel1)
assert(config.groupPanel.enabled and not panel.hidden)
assert(panel.width == 420 and panel.height == 172, "Panels must use the compact layout")
local frame = env.controls.LiveBuffUptimeGroupPanel1Frame
assert(frame.hidden and frame.centerColor[4] == 0, "Locked panels must have no black background or frame")
local tint = env.controls.LiveBuffUptimeGroupPanel1Tint2
assert(tint.centerColor[2] > tint.centerColor[1] and tint.centerColor[4] < 0.2,
    "Active player rows must use a subtle green tint")
assert(env.controls.LiveBuffUptimeGroupPanel1Name2.color[2] > env.controls.LiveBuffUptimeGroupPanel1Name2.color[1])
assert(not env.controls.LiveBuffUptimeGroupPanel1Coverage, "The panel head must not contain a 0/1 or coverage counter")
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.text == "8,0")
assert(env.controls.LiveBuffUptimeGroupPanel1Timer3.text == "-")
assert(env.controls.LiveBuffUptimeGroupPanel1Name12.text ~= "")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == before, "Panel enablement must not change uptime")
IsUnitInGroupSupportRange = function(tag) assert(tag ~= "player"); return tag ~= "group2" end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Name2.color[1] == 0.65)
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.color[4] == 0.65)
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.text == "8,0", "Distance must not discard the known buff timer")
assert(env.controls.LiveBuffUptimeTracker1.labels[2].text == before, "Range dimming must not change uptime eligibility")
IsUnitInGroupSupportRange = function() return true end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Name2.color[2] > env.controls.LiveBuffUptimeGroupPanel1Name2.color[1])
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.color[4] == 1, "Returning to range must restore normal colors")
IsUnitInGroupSupportRange = nil
env.setClock(1011); env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Timer2.text == "-", "Expiry must work without an ESO fade event")
assert(tint.centerColor[1] > tint.centerColor[2], "Missing buffs must switch to a red tint")
env.setting("Panelgroesse").setFunction(1.25)
assert(config.groupPanel.scale == 1.25)
env.setting("Group Panel Move UI").clickHandler()
assert(panel.mouse)
assert(not frame.hidden and frame.centerColor[4] == 0, "Movement may show an outline but must not add a black background")
local x = config.groupPanel.x
GetGamepadRightStickX = function() return 1 end
GetGamepadRightStickY = function() return 0 end
env.events.move()
assert(config.groupPanel.x == x + 22, "The controller must move the panel, not the buff icon")
GetGamepadRightStickX = function() return 0 end
env.setClock(1015); env.events.move()
assert(not panel.mouse, "Movement must lock and save after three idle seconds")
assert(frame.hidden)
assert(env.controls.LiveBuffUptimeTracker1.x == config.x)
env.setting("Gruppenpanel anzeigen").setFunction(false)
assert(panel.hidden and not config.groupPanel.enabled)
-- The same panel can display hostile boss and reticle debuffs independently of tracker scope.
GetUnitName = function(tag) return tag == "boss1" and "Boss" or tag == "reticleover" and "Gegner" or tag end
DoesUnitExist = function(tag) return tag == "player" or tag == "boss1" or tag == "reticleover" or tag:match("^group%d+$") ~= nil end
AreUnitsEqual = function(a, b) return a == b end
env.setBuffs("boss1", {{61771, 1015, 1030}})
env.setBuffs("reticleover", {{61771, 1015, 1020}})
env.setting("Panel-Ziel").setFunction(nil, nil, {data = "enemies"})
env.setting("Gruppenpanel anzeigen").setFunction(true)
assert(config.unit == "group", "Enemy panels must not change the tracker's measured unit")
assert(not env.controls.LiveBuffUptimeGroupPanel1Name2.hidden)
assert(env.controls.LiveBuffUptimeGroupPanel1Name1.text == "Boss")
assert(env.controls.LiveBuffUptimeGroupPanel1Timer1.text == "15,0")
assert(env.controls.LiveBuffUptimeGroupPanel1Name3.hidden)
AreUnitsEqual = function(a, b) return a == b or (a == "reticleover" and b == "boss1") end
env.events.tick()
assert(env.controls.LiveBuffUptimeGroupPanel1Name2.hidden, "A boss under the crosshair must not appear twice")
env.setting("Tracker entfernen").clickHandler()
assert(panel.hidden and #env.saved().trackers == 0, "Removing a tracker must hide its panel")
print("Group panels: existing tracker selection, twelve recipients, expiry, scale, controller movement, enemy deduplication and unchanged scope passed")
