ObsidianHUD = {name="ObsidianHUD", version="0.7.53"}
local O=ObsidianHUD
O.defaults={enabled=true,hideOriginals=true,skillFrames=true,backBar=true,
    width=480,scale=1,x=0,y=-215,opacity=0.94,numbers=true,roundBadge=true,customClassIcons=true,
    health={0.78,0.10,0.17},magicka={0.12,0.48,0.94},stamina={0.21,0.76,0.39},
    accent={1,1,1}}
O.defaults.frontResourceOrder={}
O.defaults.hudPositions={}
O.defaults.quickslotFrame=true
O.defaults.skillHudView="fixed"
O.defaults.skillHudScale=1
O.skillHudViews={
    {name="Animation - mit Doppel-Ultimate",data="fixed_dual"},
    {name="Animation - ohne Doppel-Ultimate",data="fixed"},
    {name="Ohne Animation - mit Doppel-Ultimate",data="fixed_dual_static"},
    {name="Ohne Animation - ohne Doppel-Ultimate",data="fixed_static"},
}
O.defaults.timerSize,O.defaults.stackSize=24,18
O.defaults.timerFont,O.defaults.stackFont="bold","bold"
O.defaults.timerStyle,O.defaults.stackStyle="soft-shadow-thick","soft-shadow-thick"
O.defaults.timerColor,O.defaults.stackColor={1,1,1},{1,0.85,0.25}
O.textRevision=0
function O.ApplyFixedFeatures()
    local validView=false
    for _,view in ipairs(O.skillHudViews) do
        if view.data==O.vars.skillHudView then validView=true; break end
    end
    if not validView then O.vars.skillHudView=O.defaults.skillHudView end
    if O.vars.skillHudSize then
        O.vars.skillHudScale=math.max(1,math.min(1.5,O.vars.skillHudSize/100))
        O.vars.skillHudSize=nil
    end
    -- These are now permanent parts of the addon. Migrate older saved false
    -- values as well, so removing a checkbox cannot leave its feature disabled.
    for _,key in ipairs({"enabled","hideOriginals","skillFrames","quickslotFrame","roundBadge","customClassIcons"}) do
        O.vars[key]=true
    end
end
O.resources={
    {key="health",name="LEBEN",power=COMBAT_MECHANIC_FLAGS_HEALTH},
    {key="magicka",name="MAGICKA",power=COMBAT_MECHANIC_FLAGS_MAGICKA},
    {key="stamina",name="AUSDAUER",power=COMBAT_MECHANIC_FLAGS_STAMINA},
}
local staminaOrder={O.resources[1],O.resources[3],O.resources[2]}
function O.ResourceOrder()
    local character=GetCurrentCharacterId and tostring(GetCurrentCharacterId()) or nil
    if character and O.resourceOrderCharacter~=character then
        O.resourceOrderCharacter=character
        O.primaryResource=O.vars.frontResourceOrder[character]
    end
    -- Only the primary weapon bar determines placement. Back-bar maxima may
    -- differ because of equipment and must not swap the resource rows.
    if GetActiveHotbarCategory()~=HOTBAR_CATEGORY_PRIMARY then
        return O.primaryResource=="stamina" and staminaOrder or O.resources
    end
    local _,magickaMax,magickaEffective=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_MAGICKA)
    local _,staminaMax,staminaEffective=GetUnitPower("player",COMBAT_MECHANIC_FLAGS_STAMINA)
    magickaMax=magickaEffective and magickaEffective>0 and magickaEffective or magickaMax or 0
    staminaMax=staminaEffective and staminaEffective>0 and staminaEffective or staminaMax or 0
    if staminaMax>0 and magickaMax>0 then
        if staminaMax>magickaMax then O.primaryResource="stamina"
        elseif magickaMax>staminaMax then O.primaryResource="magicka" end
    end
    if character and O.primaryResource then O.vars.frontResourceOrder[character]=O.primaryResource end
    -- Preserve the previous order on ties or unavailable (zero) maxima.
    return O.primaryResource=="stamina" and staminaOrder or O.resources
end
function O.Ratio(current,maximum)
    if not maximum or maximum<=0 then return 0 end
    return math.max(0,math.min(1,(current or 0)/maximum))
end
function O.Number(value)
    value=math.max(0,value or 0)
    if value>=1000 then return string.format("%.1fk",value/1000) end
    return tostring(math.floor(value))
end
function O.ValueText(current,maximum)
    if not maximum or maximum<=0 then return "--" end
    local ratio=O.Ratio(current,maximum)
    local percent=ratio>=1 and 100 or math.min(99,math.floor(ratio*100+0.5))
    return O.Number(current).." / "..O.Number(maximum).."  "..percent.."%"
end
function O.HealthValueText(current,maximum,shield)
    local text=O.ValueText(current,maximum)
    if shield and shield>0 and maximum and maximum>0 then
        text=text.."  |c9ADDFF("..O.Number(math.max(0,current or 0)+shield).." Ges.)|r"
    end
    return text
end
function O.OtherBar(category)
    if category==HOTBAR_CATEGORY_PRIMARY then return HOTBAR_CATEGORY_BACKUP end
    if category==HOTBAR_CATEGORY_BACKUP then return HOTBAR_CATEGORY_PRIMARY end
end
