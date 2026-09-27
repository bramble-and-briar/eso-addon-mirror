-- Health labels independent of the user's native resource-number setting.
local targetLabel
local function GroupDigits(value)
    local digits=string.format("%.0f",value)
    return (digits:reverse():gsub("(%d%d%d)","%1 "):reverse():gsub("^ ",""))
end
local function Format(health,maximum)
    if maximum<=0 then return "" end
    return string.format("%s / %s (%.1f%%)",GroupDigits(health),GroupDigits(maximum),100*health/maximum)
end
local function Update()
    if BOSS_BAR and BOSS_BAR.healthText then
        local health,maximum=0,0
        for i=BOSS_RANK_ITERATION_BEGIN,BOSS_RANK_ITERATION_END do
            local tag="boss"..i
            if DoesUnitExist(tag) then
                local h,m=GetUnitPower(tag,POWERTYPE_HEALTH)
                health=health+h maximum=maximum+m
            end
        end
        BOSS_BAR.healthText:SetText(Format(health,maximum))
        BOSS_BAR.healthText:SetHidden(maximum<=0)
        BOSS_BAR.healthText:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    end
    local frame=UNIT_FRAMES and UNIT_FRAMES:GetFrame("reticleover")
    if not frame then return end
    if not targetLabel then
        targetLabel=WINDOW_MANAGER:CreateControl("DIAhelpTargetHealth",frame.frame,CT_LABEL)
        targetLabel:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        targetLabel:SetAnchor(CENTER,frame.frame,CENTER,0,0)
        targetLabel:SetDrawTier(DT_HIGH) targetLabel:SetMouseEnabled(false)
    end
    local health,maximum=GetUnitPower("reticleover",POWERTYPE_HEALTH)
    local show=DoesUnitExist("reticleover") and IsUnitAttackable("reticleover") and maximum>0
    targetLabel:SetHidden(not show)
    if show then targetLabel:SetText(Format(health,maximum)) end
end
EVENT_MANAGER:RegisterForEvent("DIAhelpTargetHealth",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="DIAhelp" then return end
    EVENT_MANAGER:UnregisterForEvent("DIAhelpTargetHealth",EVENT_ADD_ON_LOADED)
    if BOSS_BAR then ZO_PostHook(BOSS_BAR,"RefreshBossHealthBar",Update) end
    EVENT_MANAGER:RegisterForUpdate("DIAhelpTargetHealth",100,Update)
end)
