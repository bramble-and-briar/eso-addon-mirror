local env = dofile('tests/standalone.lua')
function GetCVar(name) assert(name == 'language.2'); return 'en' end
dofile('Localization.lua')
assert(SimpleGroupDPS2_Language.english and SimpleGroupDPS2_Translate('Allgemein') == 'General')
assert(SimpleGroupDPS2_Translate('not a translation key') == 'not a translation key')
local settingsPanel
local addAddon = LibHarvensAddonSettings.AddAddon
function LibHarvensAddonSettings:AddAddon(...)
    settingsPanel = addAddon(self, ...)
    return settingsPanel
end
local windows = {}
local create = WINDOW_MANAGER.CreateTopLevelWindow
function WINDOW_MANAGER:CreateTopLevelWindow(name)
    local c = create(self, name)
    windows[name] = c
    return c
end
for _, file in ipairs({'DPSPanel.lua','PersonalDPSPanel.lua','SimpleGroupDPS.lua'}) do dofile(file) end
env.events['SimpleGroupDPS2:load'](nil, 'SimpleGroupDPS2')
assert(env.menu['General'] and env.menu['Group Share HUD'] and env.menu['DPS HUD'])
assert(env.menu['Author: FiNk3--F13--'])
assert(env.menu['Show after combat'].getFunction() == '1 minute')
assert(env.menu['Show after combat'].items[5].name == '5 minutes')
assert(env.menu['Window width'].tooltip:find('Long names', 1, true))
local format = SimpleGroupDPS2_DPSPanel
assert(format:FormatValue(13822) == '13.8k')
assert(format:FormatValue(1200000) == '1.2M')
assert(format:FormatValue(42) == '42')
local lib = LibHarvensAddonSettings
lib.scene = SCENE_MANAGER:GetCurrentScene()
local scene = lib.scene
local oldScene = SCENE_MANAGER.GetCurrentScene
SCENE_MANAGER.GetCurrentScene = function() return scene end
lib.list = {currentSection = {labelText = 'DPS HUD'}}
settingsPanel.selected = true
env.tick()
assert(not windows.SimpleGroupDPS2Window.hidden and windows.SimpleGroupDPS2PersonalWindow.hidden)
lib.list.currentSection = {labelText = 'Group Share HUD'}
env.tick()
assert(windows.SimpleGroupDPS2Window.hidden and not windows.SimpleGroupDPS2PersonalWindow.hidden,
    'English sections retain the correct settings preview')
settingsPanel.selected = false
env.tick()
assert(windows.SimpleGroupDPS2Window.hidden and windows.SimpleGroupDPS2PersonalWindow.hidden)
local personal = SimpleGroupDPS2_PersonalDPSPanel:Create()
assert(personal.title.text == 'Your Damage · Group Share')
SimpleGroupDPS2_PersonalDPSPanel:Render(personal,
    {dps=13822,total=13822,groupTotal=27644,bossDPS=1000,bossTotal=1000,groupBossTotal=4000},true)
assert(personal.primary.text == 'Boss: 1.0k DPS | 25.0 %')
assert(personal.secondary.text == '(Total: 13.8k DPS | 50.0 %)')
local parent = WINDOW_MANAGER:CreateTopLevelWindow('EnglishGroupTest')
format:Render(parent,{{name='Player',dps=13822}},false,1000,env.saved,{})
assert(parent.swtGroupDPSLabels[0].text == 'Total Damage')
assert(parent.swtGroupDPSLabels[0].swtDPSValue.text == '0:01')
assert(parent.swtGroupDPSLabels.summary.text == 'Total')
format:Render(parent,{{name='Player'}},true,1000,env.saved,{})
assert(parent.swtGroupDPSLabels[0].text == 'Boss Damage (Total Damage)')
assert(parent.swtGroupDPSLabels[1].swtDPSValue.text == '0')
SCENE_MANAGER.GetCurrentScene = oldScene
function GetCVar() return 'de' end
dofile('Localization.lua')
assert(not SimpleGroupDPS2_Language.english and SimpleGroupDPS2_Translate('Allgemein') == 'Allgemein')
assert(format:FormatValue(13822) == '13,8 Tsd.')
print('PASS: automatic English/German selection, translated menus/HUD, English numbers and German preservation')
