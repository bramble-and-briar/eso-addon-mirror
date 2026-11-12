if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
RolePlayMod={name='RolePlayMod',title='RolePlayMod : Les Voies de Tamriel',version='1.2.3-alpha.25-ps5.2'}
local R=RolePlayMod
ZO_CreateStringId('SI_ROLEPLAYMOD_CATEGORY',R.title)
R.defaults={roleplayMode='dice',survival=true,hunger=true,water=true,fatigue=true,partialRests=true,rooms=true,disease=true,alcohol=true,
 conversations=true,questions=true,services=true,rumors=true,travelJournal=true,journal=true,dice=true,trust=true,
 reputation=true,crime=true,origins=true,negativeQuota=true,nativeConversation=true,animations=true,fatigueMinutes=360,fatigueSpeed=1.5,restConsumesNeeds=true,diceSeconds=5,wheelMoveWithCtrl=true,gamepadSupport=true,rumorCooldownHours=2}
local function copy(value)
    if type(value)~='table' then return value end
    -- ZO_SavedVars exposes a proxy. Its data lives in the __index table;
    -- copying pairs(proxy) would copy methods/defaults and lose the real clues.
    local meta=getmetatable(value)
    if type(meta)=='table' and type(meta.__index)=='table' and type(rawget(value,'ResetToDefaults'))=='function' then value=meta.__index end
    local result={};for key,item in pairs(value) do
        if type(item)~='function' and type(item)~='userdata' and type(item)~='thread' then result[key]=copy(item) end
    end
    return result
end
R.Copy=copy
local function fill(value,defaults)
    for key,item in pairs(defaults or {}) do
        if value[key]==nil then value[key]=copy(item)
        elseif type(item)=='table' and type(value[key])=='table' then fill(value[key],item) end
    end
end
function R.Initialize()
    if R.saved then return end
    R.saved=ZO_SavedVars:NewCharacterIdSettings('RolePlayModSavedVars',1,nil,{options=R.defaults},GetWorldName())
    R.shared=ZO_SavedVars:NewAccountWide('RolePlayModSavedVars',1,'World',{data={}},GetWorldName())
    R.shared.data=R.shared.data or {};R.saved.options=R.saved.options or {};fill(R.saved.options,R.defaults)
    if R.saved.options.roleplayMode=='speechcraft' then R.saved.options.dice=false end
end
function R.Options() return R.saved and R.saved.options or R.defaults end
local parents={hunger='survival',water='survival',fatigue='survival',disease='survival',alcohol='survival',
 partialRests='fatigue',rooms='fatigue',questions='conversations',services='conversations',travelJournal='rumors'}
function R.Enabled(key)
    local options=R.Options()
    if key=='dice' and options.roleplayMode=='speechcraft' then return false end
    if key=='trust' and options.roleplayMode=='speechcraft' then return true end
    return options[key]~=false and (not parents[key] or R.Enabled(parents[key]))
end
local function importOptions(key,data)
    local o=R.saved.options
    if key=='survival' then
        o.survival=data.survivalModeOn~=false;o.disease=data.diseasesMechanicEnabled~=false
    elseif key=='conversations' then
        o.conversations=data.enabled~=false
        if data.enabled==false then o.rumors=false;o.journal=false end
        o.trust=data.trustEnabled~=false and data.speechcraftEnabled~=false
        o.reputation=data.reputationEnabled~=false;o.origins=data.originInfluence~=false;o.crime=data.crimeInfluence~=false
        o.nativeConversation=data.nativeConversation~=false
    end
end
function R.Storage(key,legacy,defaults)
    R.Initialize()
    if R.saved[key]==nil then
        local data=legacy and legacy() or {}
        R.saved[key]=copy(data or {});importOptions(key,R.saved[key])
    end
    fill(R.saved[key],defaults)
    return R.saved[key]
end
function R.WorldStorage(key,legacy,defaults)
    R.Initialize()
    if R.shared.data[key]==nil then R.shared.data[key]=copy(legacy and legacy() or {}) end
    fill(R.shared.data[key],defaults)
    return R.shared.data[key]
end
function R.PlaySurvivalEmote(index) if R.Enabled('animations') then return PlayEmoteByIndex(index) end end
function R.Set(key,value)
    R.Initialize()
    if key=='roleplayMode' and R.Speechcraft and R.Speechcraft.Wheel then R.Speechcraft.Wheel.Hide() end
    R.saved.options[key]=value
    if key=='roleplayMode' then
        R.saved.options.roleplayMode=value=='speechcraft' and 'speechcraft' or 'dice'
        R.saved.options.dice=R.saved.options.roleplayMode=='dice'
    end
    if R.saved.options.roleplayMode=='speechcraft' then R.saved.options.dice=false end
    if R.Apply then R.Apply(true) end
end
EVENT_MANAGER:RegisterForEvent('RPMStorage',EVENT_ADD_ON_LOADED,function(_,name)
    if name==R.name then R.Initialize();EVENT_MANAGER:UnregisterForEvent('RPMStorage',EVENT_ADD_ON_LOADED) end
end)
