local env = dofile('tests/standalone.lua')
local lib = LibHarvensAddonSettings
lib.scene = { GetName = function() return 'LibHarvensAddonSettingsScene' end }
local originalScene = SCENE_MANAGER.GetCurrentScene
function SCENE_MANAGER:GetCurrentScene()
    local scene = originalScene(self)
    if scene:GetName() == 'LibHarvensAddonSettingsScene' then return lib.scene end
    return scene
end
lib.list = {currentSection = {labelText = 'DPS-HUD'}}
env.settingsPanel.selected = true
env.showScene('LibHarvensAddonSettingsScene')
assert(not env.window.hidden and env.personalWindow.hidden, 'DPS section previews only group HUD without a fight')
env.setClock(740000)
env.tick()
assert(not env.window.hidden and not env.window.movable and not env.updates.SimpleGroupDPS2Move,
    'Preview remains after three seconds without enabling movement')
assert(not SimpleGroupDPS2_DamageMeter:IsActive() and next(env.saved.lastSummary) == nil,
    'Preview must not create combat or save invented values')
env.menu['Move UI'].clickHandler()
env.setClock(743001)
env.updates.SimpleGroupDPS2Move()
assert(not env.window.hidden and not env.window.movable, 'Ending Move UI keeps settings preview visible')
env.menu['DPS-Zahlengröße'].setFunction(30)
assert(not env.window.hidden and env.saved.dpsValueFontSize == 30)
lib.list.currentSection = {labelText = 'Gruppenanteil-HUD'}
env.tick()
assert(env.window.hidden and not env.personalWindow.hidden, 'Switching sections swaps preview')
env.menu['Anteil-HUD-Größe'].setFunction(150)
assert(not env.personalWindow.hidden and env.personalWindow.scale == 1.5)
env.menu['Anteil-HUD anzeigen'].setFunction(false)
assert(env.personalWindow.hidden, 'Visibility checkbox still hides personal HUD')
env.menu['Anteil-HUD anzeigen'].setFunction(true)
assert(not env.personalWindow.hidden)
lib.list.currentSection = nil
env.tick()
assert(env.window.hidden and env.personalWindow.hidden, 'Backing out of HUD section hides previews')
lib.list.currentSection = {labelText = 'Allgemein'}
env.tick()
assert(not env.window.hidden and not env.personalWindow.hidden)
env.settingsPanel.selected = false
env.tick()
assert(env.window.hidden and env.personalWindow.hidden, 'Other addons never show our previews')
env.settingsPanel.selected = true
env.showScene('inventory')
assert(env.window.hidden and env.personalWindow.hidden, 'Leaving settings ends preview immediately')
env.showScene('hud')
assert(env.window.hidden and env.personalWindow.hidden, 'No preview persists into gameplay')
lib.scene = nil
local hidden = false
lib.container = {IsHidden = function() return hidden end}
env.showScene('options')
assert(not env.window.hidden and not env.personalWindow.hidden, 'PC panel previews both HUDs')
hidden = true
env.tick()
assert(env.window.hidden and env.personalWindow.hidden, 'Hidden PC panel stops preview')
print('PASS: persistent settings preview, console sections, PC panel, movement timeout and clean exit')
