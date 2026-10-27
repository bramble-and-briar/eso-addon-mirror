local O=ObsidianHUD
O.skillFonts={
    {name="Fett",data="bold",font="$(BOLD_FONT)"},
    {name="Normal",data="normal",font="$(MEDIUM_FONT)"},
    {name="Fantasy",data="fantasy",font="$(ANTIQUE_FONT)"},
}
O.skillTextStyles={
    {name="Kraeftiger Schatten",data="soft-shadow-thick"},
    {name="Feiner Schatten",data="soft-shadow-thin"},
    {name="Kontur",data="outline"},
    {name="Ohne Effekt",data=""},
}
function O.SkillTextFont(kind,backScale)
    local font="$(BOLD_FONT)"
    for _,entry in ipairs(O.skillFonts) do if entry.data==O.vars[kind.."Font"] then font=entry.font; break end end
    local style="soft-shadow-thick"
    for _,entry in ipairs(O.skillTextStyles) do if entry.data==O.vars[kind.."Style"] then style=entry.data; break end end
    local size=O.vars[kind.."Size"]
    if type(backScale)=="number" then size=(tonumber(size) or 18)*backScale end
    size=math.max(8,math.min(48,math.floor(tonumber(size) or 18)))
    return font.."|"..size.."|"..style
end

function O.StyleSkillText(skin)
    local frontWidth=O.SkillIconRestSize(skin.button)
    local backWidth=O.skillScaleDimensions and skin.previewWidth or skin.back:GetWidth()
    local backScale=frontWidth>0 and backWidth>0 and backWidth/frontWidth or 43/64
    if O.vars.skillHudView=="equal" or O.IsFixedSkillView() then backScale=1 end
    if skin.textRevision==O.textRevision and skin.textBackScale==backScale then return end
    skin.textRevision=O.textRevision
    skin.textBackScale=backScale
    for _,entry in ipairs({{skin.activeTimer,"timer",false},{skin.timer,"timer",true},
        {skin.activeStacks,"stack",false},{skin.backStacks,"stack",true}}) do
        local label,kind,back=unpack(entry)
        label:SetFont(O.SkillTextFont(kind,back and backScale or nil))
        local c=O.vars[kind.."Color"]
        label:SetColor(c[1],c[2],c[3],1)
    end
end

function O.UpdateStackText(label,slot,bar)
    local preview=O.stackPreviewUntil and GetFrameTimeSeconds()<O.stackPreviewUntil
    local count=preview and 3 or O.GetSkillStackCount(slot,bar)
    label:SetText(count and count>0 and tostring(count) or "")
end

function O.UpdateActiveSkillText(skin)
    if not skin.activeTextVisible then return end
    local bar=GetActiveHotbarCategory()
    if bar~=skin.activeTextBar or GetSlotBoundId(skin.activeTextSlot,bar)==0 then
        O.UpdateSkillProcHighlight(skin,false,skin.activeTextSlot,bar,false)
        skin.activeTimer:SetText(""); skin.activeStacks:SetText(""); return
    end
    if O.NoSkillAnimationsView() then O.FinishNativeSkillAnimations(skin.button)
    elseif skin.activeTextSlot==8 then O.FinishFixedUltimateSwap() end
    O.UpdateFixedSkillBindings(skin)
    O.SuppressNativeSkillText(skin.button)
    skin.activeTimer:SetText(O.BackBarTimerText(skin.activeTextSlot,bar))
    O.UpdateStackText(skin.activeStacks,skin.activeTextSlot,bar)
    O.UpdateSkillProcHighlight(skin,false,skin.activeTextSlot,bar,true)
    if skin.activeTextSlot==8 then O.UpdateUltimateCharge(skin) end
end

function O.HideSkillText(skin)
    skin.activeTextVisible=false
    skin.textRoot:SetHidden(true)
    O.StopSkillProcHighlight(skin.procFront)
    O.StopSkillProcHighlight(skin.procBack)
end

function O.CreateSkillText(skin)
    local root=WINDOW_MANAGER:CreateControl(nil,skin.button.slot,CT_CONTROL)
    root:SetAnchorFill(skin.button.icon)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_TEXT)
    root:SetDrawLevel(30)
    root:SetHidden(true)
    skin.textRoot=root
    skin.activeTimer=O.Label(root,24)
    skin.activeTimer:SetAnchor(CENTER,skin.button.icon,CENTER,0,0)
    skin.activeStacks=O.Label(root,18)
    skin.activeStacks:SetAnchor(TOPRIGHT,skin.button.icon,TOPRIGHT,-3,3)
    skin.activeStacks:SetDrawTier(DT_HIGH)
    skin.activeStacks:SetDrawLevel(40)
    skin.backStacks=O.Label(skin.back,18)
    skin.backStacks:SetAnchor(TOPRIGHT,skin.backIcon,TOPRIGHT,-3,3)
    skin.backStacks:SetDrawTier(DT_HIGH)
    skin.backStacks:SetDrawLevel(40)
    root:SetHandler("OnUpdate",function() O.UpdateActiveSkillText(skin) end)
end
