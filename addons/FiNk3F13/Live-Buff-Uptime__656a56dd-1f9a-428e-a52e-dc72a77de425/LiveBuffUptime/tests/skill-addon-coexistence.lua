local env=dofile("tests/addon.lua")
local originalReports,originalSaved=LiveBuffUptimeReports,env.saved()
local originalHistory=originalSaved.lastUptimeReport
local standaloneSaved={uptimeHistory={}}
local newSaved=ZO_SavedVars.NewAccountWide
function ZO_SavedVars:NewAccountWide(name,...)
    if name=="SkillDamageStats_SavedVariables" then return standaloneSaved end
    return newSaved(self,name,...)
end
local addPanel=LibHarvensAddonSettings.AddAddon
function LibHarvensAddonSettings:AddAddon(name,...)
    if name=="SkillDamageStats" then return {AddSettings=function() end} end
    return addPanel(self,name,...)
end
EVENT_COMBAT_EVENT,ACTION_RESULT_DAMAGE=90,10
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET=1,2
for i,name in ipairs({"EVENT_MESSAGES","MESSAGE_COMBATSTART","EVENT_DAMAGE_OUT","EVENT_FIGHTSUMMARY"}) do _G["LIBCOMBAT_"..name]=100+i end
local callbacks={}
LibCombat2=nil
LibCombat={name="LibCombat",RegisterForCombatEvent=function(_,name,event,callback)
    assert(name=="SkillDamageStats");callbacks[event]=callback
end}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
dofile("../SkillDamageStats/lang/en.lua")
dofile("../SkillDamageStats/Localization.lua")
dofile("../SkillDamageStats/CombatBridge.lua")
dofile("../SkillDamageStats/SkillReports.lua")
dofile("../SkillDamageStats/SkillDamageStats.lua")
env.events[EVENT_ADD_ON_LOADED](nil,"SkillDamageStats")
env.setClock(100)
callbacks[LIBCOMBAT_EVENT_MESSAGES](nil,200000,LIBCOMBAT_MESSAGE_COMBATSTART)
callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil,200000,10,1,900,123,5000,1,0)
env.setClock(110)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil,{endtime=210000,dpstime=10,units={[900]={name="Boss",unitType=4}}})
assert(standaloneSaved.lastUptimeReport.ownDamage==5000 and standaloneSaved.lastUptimeReport.skillDamageDuration==10)
assert(LiveBuffUptimeReports==originalReports and originalSaved.lastUptimeReport==originalHistory,
    "Standalone loading and damage collection must not replace LiveBuffUptime globals, history or settings")
assert(standaloneSaved~=originalSaved and SLASH_COMMANDS["/sds"] and SLASH_COMMANDS["/lbu"])
print("Coexistence: independent collectors, globals, command names and SavedVariables; original buff history unchanged")
