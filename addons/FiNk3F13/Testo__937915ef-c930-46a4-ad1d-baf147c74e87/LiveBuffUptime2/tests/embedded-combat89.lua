-- The real library uses ESO globals and initializes its event engine on load.
-- Check its private wiring without replacing or touching any external collector.
local events={"EVENT_MESSAGES","EVENT_FIGHTSUMMARY","EVENT_DAMAGE_OUT","EVENT_DAMAGE_IN","EVENT_DAMAGE_SELF",
    "EVENT_HEAL_OUT","EVENT_HEAL_IN","EVENT_HEAL_SELF","EVENT_EFFECTS_IN","EVENT_EFFECTS_OUT",
    "EVENT_GROUPEFFECTS_IN","EVENT_GROUPEFFECTS_OUT","MESSAGE_COMBATSTART"}
local own={version=89,name="LiveBuffUptime2Combat"}
local external={name="External LibCombat"}
LibCombat,LibCombat2,SimpleGroupDPSCombat=external,{},{}
local other2,otherGroup=LibCombat2,SimpleGroupDPSCombat
LiveBuffUptime2Combat=own
for index,name in ipairs(events) do _G["LBU2COMBAT_"..name]=index+100 end
local oldPairs=pairs
pairs=function(value) assert(value~=_G,"never enumerate protected ESO globals");return oldPairs(value) end
dofile("EmbeddedCombat.lua")
pairs=oldPairs
for index,name in ipairs(events) do assert(own[name]==index+100,"explicit named event exports use the private library constants") end
assert(own.embedded and own.backend=="LibCombat" and own.version==89)
assert(LibCombat==external and LibCombat2==other2 and SimpleGroupDPSCombat==otherGroup,"other collectors must remain untouched")
local function read(path) local f=assert(io.open(path,"r"));local s=f:read("*a");f:close();return s end
local manifest=read("LiveBuffUptime2.addon")
assert(manifest:find("libs/Combat/LibCombat.lua",1,true)<manifest:find("EmbeddedCombat.lua",1,true))
assert(manifest:find("EmbeddedCombat.lua",1,true)<manifest:find("LiveBuffUptime2.lua",1,true))
local source=read("libs/Combat/LibCombat.lua")
assert(source:find("lib.version = 89",1,true) and source:find("LiveBuffUptime2Combat = lib",1,true))
assert(not source:find("SimpleGroupDPSCombat",1,true) and not source:find("SGD_LIBCOMBAT",1,true))
assert(source:find("function lib:RegisterForCombatEvent",1,true))
local addon=read("LiveBuffUptime2.lua")
assert(addon:find("LibCombat = LiveBuffUptime2Combat",1,true))
assert(addon:find('libConstant("EVENT_FIGHTSUMMARY")',1,true) and addon:find('libConstant("EVENT_MESSAGES")',1,true))
print("Embedded LibCombat 89: private identity, explicit exports, load order and callback routing; external addons untouched")
