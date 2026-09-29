local DIAhelp = DIAhelp
DIAhelp.CombatHUD = {}
-- DIAhelp combat meter and stat gauges, alabuzya. GPL-3.0-or-later.
-- Independent implementation; no Bandits UI code or assets included.
local M=DIAhelp.CombatModel
local session=M.New()
local observedIds={}
local settings, meter, summary, gauges, labels
local ru=false
local damageResults={ [ACTION_RESULT_DAMAGE]=true, [ACTION_RESULT_CRITICAL_DAMAGE]=true,
    [ACTION_RESULT_BLOCKED_DAMAGE]=true,[ACTION_RESULT_DOT_TICK]=true,[ACTION_RESULT_DOT_TICK_CRITICAL]=true }
local healResults={ [ACTION_RESULT_HEAL]=true,[ACTION_RESULT_CRITICAL_HEAL]=true,
    [ACTION_RESULT_HOT_TICK]=true,[ACTION_RESULT_HOT_TICK_CRITICAL]=true }
local criticalResults={ [ACTION_RESULT_CRITICAL_DAMAGE]=true,[ACTION_RESULT_DOT_TICK_CRITICAL]=true }
local function Text(parent,font)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont(font or "$(BOLD_FONT)|16|soft-shadow-thick")
    c:SetMouseEnabled(false)
    return c
end
local function HUD(root)
    local fragment=ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
end
local function Number(v)
    if v>=1000000 then return string.format("%.2fm",v/1000000) end
    if v>=10000 then return string.format("%.1fk",v/1000) end
    return tostring(math.floor(v+0.5))
end
local function Paint()
    if not meter then return end
    local duration,dps,hps,dtps,crit=M.Values(session,GetFrameTimeSeconds())
    local time=string.format("%d:%02d",math.floor(duration/60),math.floor(duration%60))
    local rows
    if settings.compact then
        meter:SetDimensions(300,30)
        local share=M.Share(session)
        local digits=string.format("%.0f",dps):reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
        rows={{"DPS",digits,"",share and string.format("~%.1f%%",share) or "--",time}}
    else
        meter:SetDimensions(350,78)
        rows={
            {ru and "Урон" or "Damage",Number(session.damage),"DPS",Number(dps),string.format("%.0f%%",crit)},
            {ru and "Лечение" or "Healing",Number(session.healing),"HPS",Number(hps),""},
            {ru and "Входящий" or "Taken",Number(session.incoming),"DTPS",Number(dtps),time}}
    end
    for row=1,3 do
        for col=1,5 do
            local c=labels[row][col]
            c:SetHidden(not rows[row])
            if rows[row] then
                c:ClearAnchors()
                local offsets=settings.compact and {8,44,154,166,250} or {8,96,169,215,290}
                local widths=settings.compact and {32,106,8,78,48} or {86,70,44,72,56}
                c:SetAnchor(TOPLEFT,meter,TOPLEFT,offsets[col],5+(row-1)*23)
                c:SetDimensions(widths[col],22)
                c:SetText(rows[row][col])
            end
        end
    end
end
local function SavePosition(root,key)
    settings[key]={x=root:GetLeft()/GuiRoot:GetWidth(),y=root:GetTop()/GuiRoot:GetHeight()}
end
local function Position(root,key,x,y)
    local p=settings[key]
    root:ClearAnchors()
    root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,p and p.x*GuiRoot:GetWidth() or x,p and p.y*GuiRoot:GetHeight() or y)
end
local function Movable(root,key)
    root:SetMouseEnabled(true) root:SetMovable(true) root:SetClampedToScreen(true)
    root:SetHandler("OnMoveStop",function() SavePosition(root,key) end)
end
local function Gauge(name,title,x)
    local root=WINDOW_MANAGER:CreateTopLevelWindow(name)
    root:SetDimensions(170,82)
    Position(root,name,x,98)
    Movable(root,name)
    local titleLabel=Text(root)
    titleLabel:SetAnchor(TOP,root,TOP,0,0)
    titleLabel:SetText(title)
    local value=Text(root,"$(BOLD_FONT)|20|soft-shadow-thick")
    value:SetAnchor(BOTTOM,root,BOTTOM,0,-2)
    local ticks={}
    for i=1,25 do
        local angle=-0.65+(i-1)*1.3/24
        local tick=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
        tick:SetEdgeTexture(nil,1,1,1)
        tick:SetEdgeColor(0,0,0,0.9)
        tick:SetDimensions(5,10)
        tick:SetAnchor(CENTER,root,TOPLEFT,85+math.sin(angle)*117,153-math.cos(angle)*117)
        tick:SetCenterColor(0.48,0.53,0.50,0.9)
        tick:SetMouseEnabled(false)
        ticks[i]=tick
    end
    local marker=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
    marker:SetDimensions(8,17)
    marker:SetEdgeTexture(nil,1,1,1) marker:SetEdgeColor(0.03,0.08,0.05,1)
    marker:SetCenterColor(0.65,1,0.7,1) marker:SetDrawTier(DT_HIGH)
    marker:SetMouseEnabled(false)
    HUD(root)
    return {root=root,value=value,ticks=ticks,marker=marker}
end
local function SetGauge(g,value,fraction)
    g.value:SetText(value)
    local angle=-0.65+math.max(0,math.min(1,fraction))*1.3
    g.marker:ClearAnchors()
    g.marker:SetAnchor(CENTER,g.root,TOPLEFT,85+math.sin(angle)*117,153-math.cos(angle)*117)

end
local function Stats()
    local spell=GetPlayerStat(STAT_SPELL_POWER,STAT_BONUS_OPTION_APPLY_BONUS)
    local weapon=GetPlayerStat(STAT_POWER,STAT_BONUS_OPTION_APPLY_BONUS)
    local power=math.max(spell,weapon)
    local rating=math.max(GetPlayerStat(STAT_SPELL_CRITICAL,STAT_BONUS_OPTION_APPLY_BONUS),GetPlayerStat(STAT_CRITICAL_STRIKE,STAT_BONUS_OPTION_APPLY_BONUS))
    local chance=GetCriticalStrikeChance(rating)
    SetGauge(gauges.crit,string.format("%.1f%%",chance),chance/100)
    SetGauge(gauges.power,Number(power),power/10000)
end
local function ObserveTargets()
    local function Observe(tag)
        if DoesUnitExist(tag) and IsUnitAttackable(tag) then
            local health,maximum=GetUnitPower(tag,POWERTYPE_HEALTH)
            local identity=observedIds[tag]
            if identity and identity.name==GetUnitName(tag) then
                M.Observe(session,tostring(identity.id),health,maximum)
            end
        end
    end
    if session.active and DoesUnitExist("reticleover") and IsUnitAttackable("reticleover") then
        local identity=observedIds.reticleover
        session.currentTarget=identity and identity.name==GetUnitName("reticleover") and tostring(identity.id) or nil
    end
    Observe("reticleover")
    for i=BOSS_RANK_ITERATION_BEGIN,BOSS_RANK_ITERATION_END do Observe("boss"..i) end
end
local function Combat(_,result,isError,abilityName,graphic,slotType,sourceName,sourceType,targetName,targetType,value,powerType,damageType,log,sourceId,targetId)
    if isError or not session.active then return end
    local own=sourceType==COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER_PET
    if damageResults[result] then
        if own and targetType~=COMBAT_UNIT_TYPE_PLAYER and targetType~=COMBAT_UNIT_TYPE_PLAYER_PET then
            M.Add(session,"damage",value,criticalResults[result])
            M.TargetDamage(session,tostring(targetId),value)
        end
        if targetType==COMBAT_UNIT_TYPE_PLAYER then M.Add(session,"incoming",value,false) end
    elseif own and healResults[result] then
        M.Add(session,"healing",value,false)
    end
end
function DIAhelp.CombatHUD.Initialize()
    ru=GetCVar("language.2")=="ru"
    settings=DIAhelp.SavedVariables.Account("combatHUD",{compact=false})
    meter=WINDOW_MANAGER:CreateTopLevelWindow("DIAhelpCombatMeter")
    Position(meter,"meter",8,6)
    Movable(meter,"meter")
    local bg=WINDOW_MANAGER:CreateControl(nil,meter,CT_BACKDROP)
    bg:SetAnchorFill() bg:SetCenterColor(0,0,0,0.65) bg:SetEdgeColor(0.25,0.25,0.22,0.5)
    bg:SetEdgeTexture(nil,1,1,1) bg:SetMouseEnabled(false)
    labels={}
    for row=1,3 do
        labels[row]={}
        for col=1,5 do
            local c=Text(meter,"$(BOLD_FONT)|16|soft-shadow-thick")
            c:SetHorizontalAlignment((col==2 or col==4) and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
            if col==1 or col==3 then c:SetColor(0.75,0.74,0.65,1) end
            labels[row][col]=c
        end
    end
    local downX,downY
    meter:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then downX,downY=GetUIMousePosition() end
    end)
    meter:SetHandler("OnMouseUp",function(_,button,upInside)
        local x,y=GetUIMousePosition()
        if button==MOUSE_BUTTON_INDEX_LEFT and upInside and downX and math.abs(x-downX)+math.abs(y-downY)<5 then
            settings.compact=not settings.compact Paint()
        end
        downX=nil
    end)
    HUD(meter)
    gauges={crit=Gauge("DIAhelpCritGauge",ru and "Крит" or "Crit",GuiRoot:GetWidth()*0.35-85),
        power=Gauge("DIAhelpPowerGauge",ru and "Сила" or "Power",GuiRoot:GetWidth()*0.63-85)}
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatHUD",EVENT_PLAYER_COMBAT_STATE,function(_,active)
        if active then M.Start(session,GetFrameTimeSeconds()) ObserveTargets() else ObserveTargets() M.Stop(session,GetFrameTimeSeconds()) end
        Paint()
    end)
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatHUD",EVENT_COMBAT_EVENT,Combat)
    -- ESO exposes unit IDs through effect events, not a GetUnitId function.
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatIdentity",EVENT_EFFECT_CHANGED,function(_,change,slot,effect,tag,beginTime,endTime,stacks,icon,buffType,effectType,abilityType,status,name,id)
        if tag and (tag=="reticleover" or string.match(tag,"^boss%d+$")) and id and id~=0 then
            observedIds[tag]={id=id,name=GetUnitName(tag)}
            ObserveTargets()
        end
    end)
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatIdentity",EVENT_RETICLE_TARGET_CHANGED,function() observedIds.reticleover=nil end)
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatIdentity",EVENT_BOSSES_CHANGED,function() observedIds={} end)
    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatIdentity",EVENT_PLAYER_DEACTIVATED,function() observedIds={} end)

    EVENT_MANAGER:RegisterForEvent("DIAhelpCombatHUD",EVENT_PLAYER_ACTIVATED,function()
        if IsUnitInCombat("player") then M.Start(session,GetFrameTimeSeconds()) else M.Stop(session,GetFrameTimeSeconds()) end
    end)
    EVENT_MANAGER:RegisterForUpdate("DIAhelpCombatHUD",250,function()
        ObserveTargets()
        if not meter:IsHidden() then Paint() Stats() end
    end)
    Paint() Stats()
end
