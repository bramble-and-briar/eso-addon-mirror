local env = dofile('tests/standalone.lua')
local meter = SimpleGroupDPS_DamageMeter
local clock = 800123
local register = EVENT_MANAGER.RegisterForUpdate
local starts = {}
EVENT_MANAGER.RegisterForUpdate = function(self, name, interval, callback)
    if name == 'SimpleGroupDPSUI' then
        starts[#starts+1] = {at=clock, due=clock+interval, callback=callback, interval=interval}
    end
    return register(self, name, interval, callback)
end
local function at(value) clock=value; env.setClock(value) end
BattleScrolls = nil
at(800123);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
assert(#starts==1 and starts[1].at==800123 and starts[1].due==800423 and starts[1].interval==300,
    'First combat HUD tick is due 300ms after encounter initialization, matching BattleScrolls')
at(800200)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
assert(#starts==1,'Combat-state re-entry must not shift the encounter update cadence')
at(800250)
env.menu['Move UI'].clickHandler()
SLASH_COMMANDS['/sgdmove']()
assert(#starts==1,'Opening or closing Move UI during combat cannot restart the 300ms cadence')
at(800350);meter:OnDamage(1,false,1,'Enemy',0,1000,42,1)
at(800422);meter:OnDamage(1,false,1,'Enemy',0,500,42,1)
at(800423);starts[1].callback()
assert(meter:GetStats().total==1500 and meter:GetStats().durationMS==299,
    'HUD scheduling does not change measured damage or encounter duration')
at(800723);starts[1].callback()
assert(meter:GetStats().durationMS==299 and #starts==1,'Idle damage time and recurring UI cadence remain independent')
at(801000);meter:Finish()
local dps=meter:GetStats().dps
at(801500);starts[1].callback()
assert(meter:GetStats().dps==dps,'Post-combat UI refresh preserves the final measurement')
at(802111);meter:Start(clock)
assert(#starts==2 and starts[2].due==802411,'Each genuinely new encounter resets cadence once')
assert(type(SimpleGroupDPS_BattleScrolls.SendMetrics)=="function",'No sender is introduced')
print('PASS: encounter-based 300ms HUD cadence, no Move UI/reentry phase shifts, independent measurement and frozen final result')
