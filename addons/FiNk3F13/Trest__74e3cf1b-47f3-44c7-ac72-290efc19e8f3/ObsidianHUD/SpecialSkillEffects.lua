local O=ObsidianHUD
-- Independent adaptation of FAB+'s device/reflect facts. These are effect
-- instances and remaining shield charges, not casts or enemy totals.
O.skillDevices={}
for parent,children in pairs({
    [24828]={24830,24832,24833}, [24842]={24844,24846,24847},
    [24834]={25157,25158,25159,25160,25162},
    [86175]={},[86179]={},[86183]={},
}) do
    O.skillDevices[parent]={id=parent,multi=parent>=86175}
    for _,child in ipairs(children) do O.skillDevices[child]={id=parent} end
end
local reflectMax={[28727]=1,[38312]=1,[38317]=1,[86135]=3,[86139]=3,[86143]=3}
O.skillReflectIds={28727,126604,38312,126608,38317,38324,86135,86139,86143}
local devices,charges,phases={},{},{}
local function canonical(id) return O.timerAliases[id] or id end
local function slotted(id)
    for _,bar in ipairs({HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP}) do
        for slot=3,8 do
            local bound=O.GetSkillAbilityId and O.GetSkillAbilityId(slot,bar) or GetSlotBoundId(slot,bar)
            if canonical(bound)==id then return true end
        end
    end
    return false
end
function O.ResetSpecialSkillEffects() devices,charges,phases={},{},{} end
function O.OnSpecialSkillUsed(id)
    id=canonical(id)
    if O.timerPhases[id] then phases[id]={began=GetFrameTimeSeconds(),phase=0} end
    if not reflectMax[id] then return end
    local duration=GetAbilityDuration and GetAbilityDuration(id) or 0
    if duration>0 then
        charges[id]={count=reflectMax[id],began=GetFrameTimeSeconds(),ending=GetFrameTimeSeconds()+duration/1000}
    end
end
function O.OnSpecialSkillEffect(change,slot,tag,began,ending,unit,id)
    local phase=O.timerPhases[id]
    -- Curse/Shalk counters are the actual remaining explosions (2 -> 1),
    -- not the number of targets and not the effect's usual stackCount=0.
    if phase and phase.seconds and phase.id~=37475 and slotted(phase.id) then
        local current=phases[phase.id]
        local start=type(began)=="number" and began>0 and began or GetFrameTimeSeconds()
        if not current or (start>=current.began and phase.phase>=(current.phase or 0)) then
            if change==EFFECT_RESULT_FADED then
                if current and phase.phase==current.phase then current.count=0 end
            else
                phases[phase.id]={began=start,phase=phase.phase,count=3-phase.phase,
                    ending=GetFrameTimeSeconds()+phase.seconds}
            end
        end
    end
    local shield=charges[canonical(id)]
    if shield and tag=="player" and change==EFFECT_RESULT_FADED
        and (not began or began<=0 or began>=(shield.began or 0)) then shield.count=0 end
    local rule=O.skillDevices[id]
    if not rule or not slotted(rule.id) then return false end
    local now=GetFrameTimeSeconds()
    local state=devices[rule.id] or {instances={}}
    devices[rule.id]=state
    began=type(began)=="number" and began>0 and began or now
    -- A parent notification is the lifetime/reset of a group of sorcerer
    -- mines; it must not count as an additional mine.
    if not rule.multi and rule.id==id then
        if state.began and began<state.began then return true end
        if change==EFFECT_RESULT_FADED then
            state.instances={}; state.ending=0; state.children=true
        else
            if not state.began or began>state.began then state.instances={}; state.children=false end
            state.began=began; state.ending=ending
        end
        return true
    end
    if state.began and began<state.began then return true end
    local key=rule.multi and (tostring(unit or tag)..":"..tostring(slot)..":"..id) or tostring(id)
    local old=state.instances[key]
    if old and began<old.began then return true end
    state.children=true
    if change==EFFECT_RESULT_FADED then state.instances[key]=nil
    elseif type(ending)=="number" and ending>now then
        state.instances[key]={began=began,ending=ending}
    end
    return true
end
function O.GetSpecialSkillState(id)
    id=canonical(id)
    local now=GetFrameTimeSeconds()
    local state=devices[id]
    if state then
        local count,ending=0,0
        for key,entry in pairs(state.instances) do
            if entry.ending<=now then state.instances[key]=nil
            else count=count+1; ending=math.max(ending,entry.ending) end
        end
        if not state.children then ending=math.max(ending,state.ending or 0) end
        return math.max(0,ending-now)*1000,count
    end
    local shield=charges[id]
    if shield then
        if shield.ending<=now then shield.count=0 end
        return nil,shield.count
    end
    local phase=phases[id]
    if phase and phase.count then
        return nil,phase.ending and phase.ending>now and phase.count or 0
    end
end
function O.OnSpecialSkillCombat(result,isError,target,id)
    id=canonical(id)
    if isError or target~=COMBAT_UNIT_TYPE_PLAYER or not reflectMax[id] or not slotted(id) then return end
    local shield=charges[id]
    if result==ACTION_RESULT_DAMAGE_SHIELDED and shield and shield.ending>GetFrameTimeSeconds() then
        shield.count=math.max(0,shield.count-1)
    elseif result==ACTION_RESULT_EFFECT_FADED then
        charges[id]={count=0,began=GetFrameTimeSeconds(),ending=0}
    end
end
