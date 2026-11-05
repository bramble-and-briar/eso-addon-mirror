local env = dofile("tests/standalone.lua")
local panel, window = SimpleGroupDPS_PersonalDPSPanel, env.personalWindow
assert(window and window.hidden and env.saved.personalPosX == 32,
    "Separate HUD starts at lower left with no invented result")
assert(env.saved.personalPosY > GuiRoot:GetHeight() / 2)
local size = env.menu["Anteil-HUD-Größe"]
assert(size and size.min == 50 and size.max == 200 and size.getFunction() == 70,
    "Personal scale initially preserves the previous visible size")
local groupScale, originalX, originalY = env.window.scale, env.saved.personalPosX, env.saved.personalPosY
size.setFunction(150)
assert(window.scale == 1.5 and env.saved.personalScale == 1.5 and env.window.scale == groupScale,
    "Enlarging personal HUD leaves group scale unchanged and saves the preference")
assert(env.saved.personalPosX == originalX and env.saved.personalPosY == originalY)
env.menu["HUD-Gesamtgröße"].setFunction(100)
assert(window.scale == 1.5, "Group size changes cannot override personal size")
env.menu["HUD-Gesamtgröße"].setFunction(70)
size.setFunction(70)
local all, boss = panel:GetShares({total = 2000000, groupTotal = 10000000,
    bossTotal = 1000000, groupBossTotal = 2500000})
assert(all == 20 and boss == 40, "All-target and boss shares use matching raw damage totals")
assert(panel:GetShares({total = 0, groupTotal = 0}) == 0, "Known no-damage result avoids division by zero")
assert(panel:GetShares({total = 10}) == nil and panel:GetShares({total = 10, groupTotal = 0}) == nil,
    "Missing or inconsistent group totals cannot invent a percentage")
assert(panel:GetShares({total = 10, groupTotal = math.huge}) == nil)

-- Own damage and group damage go through the actual collector and HUD update.
env.setClock(800000)
env.setCombat(true)
env.events["SimpleGroupDPSDamageState:combat"](nil, true)
env.setClock(801000)
env.events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Target", 0,
    2000, nil, nil, nil, 10, 20)
env.events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 4, "Target", 0,
    8000, nil, nil, nil, 30, 20)
env.tick()
assert(not window.hidden and window.primary.text == "DPS: 2,0 Tsd. | 20,0 %" and window.secondary.hidden)
local groupPositionX, groupPositionY = env.saved.posX, env.saved.posY
env.showScene("inventory")
assert(window.hidden and env.window.hidden, "Both HUDs hide in menus")
env.menu["Anteil-HUD verschieben"].clickHandler()
assert(not window.hidden and window.movable and env.window.hidden and not env.window.movable,
    "Own HUD can move independently while group HUD stays hidden in the menu")
window.left, window.top = 100, 750
window.handlers.OnMoveStop()
env.updates.SimpleGroupDPSMove()
env.setClock(804000)
env.updates.SimpleGroupDPSMove()
assert(env.saved.personalPosX == 100 and env.saved.personalPosY == 750 and not window.movable)
assert(env.saved.posX == groupPositionX and env.saved.posY == groupPositionY, "Own move preserves group position")
assert(window.hidden, "Auto-saving restores menu hiding")
env.showScene("hud")
assert(not window.hidden)

-- Boss totals use the same local filter; hiding group roles does not change the denominator.
function DoesUnitExist(tag) return tag == "boss1" or tag == "group1" end
function GetRawUnitName(tag) return tag == "boss1" and "Boss" or "" end
env.events["SimpleGroupDPSDamageBosses:boss"]()
env.setClock(805000)
env.events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 1, "Boss", 0,
    1000, nil, nil, nil, 10, 40)
env.events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, nil, 4, "Boss", 0,
    3000, nil, nil, nil, 30, 40)
env.tick()
assert(window.primary.text == "Boss: 250 DPS | 25,0 %")
assert(window.secondary.text == "(Gesamt: 750 DPS | 21,4 %)" and not window.secondary.hidden)
env.menu["Tanks anzeigen"].setFunction(false)
env.menu["Heiler anzeigen"].setFunction(false)
assert(window.primary.text == "Boss: 250 DPS | 25,0 %", "Role visibility cannot alter local group shares")
env.setCombat(false)
env.events["SimpleGroupDPSDamageState:combat"](nil, false)
env.updates.SimpleGroupDPSDamageReset()
env.setClock(810000)
env.tick()
assert(window.primary.text == "Boss: 250 DPS | 25,0 %", "Final shares freeze with stored totals")
env.saved.lingerSeconds = 60
env.setClock(865000)
env.tick()
assert(window.hidden, "Retention expiry hides and clears the personal result too")
print("PASS: personal DPS/boss shares, unknown totals, separate movement, menus, role filters and final retention")
