-- Independent compact group frames, GPL-3.0-or-later.
local root,settings,ru
local rows={}
local hoveredRow
local function IsRemote(tag)
    if AreUnitsEqual and AreUnitsEqual(tag,"player") then return false end
    if GetUnitZoneIndex then
        local here,there=GetUnitZoneIndex("player"),GetUnitZoneIndex(tag)
        if here and there and here>0 and there>0 and here~=there then return true end
    end
    if IsGroupMemberInSameWorldAsPlayer and not IsGroupMemberInSameWorldAsPlayer(tag) then return true end
    return IsUnitInGroupSupportRange and not IsUnitInGroupSupportRange(tag) or false
end
local function ShowLocation(row)
    if not InformationTooltip or not row.unitTag then return end
    local tag=row.unitTag
    local online=row.companion or IsUnitOnline(tag)
    local zone=online and GetUnitZone and GetUnitZone(tag) or ""
    if not zone or zone=="" then
        zone=ru and "Локация неизвестна" or "Location unavailable"
    end
    local name=row.companion and GetUnitName(tag) or ZO_GetPrimaryPlayerNameFromUnitTag(tag)
    local text=zo_strformat(SI_UNIT_NAME,name).."\n"..zone
    if not online then text=text.."\n"..(ru and "Не в сети" or "Offline") end
    InitializeTooltip(InformationTooltip,row.bg,TOPLEFT,8,0,TOPRIGHT)
    SetTooltipText(InformationTooltip,text)
end
local function Box(parent)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_BACKDROP)
    c:SetEdgeTexture(nil,1,1,1) c:SetEdgeColor(0.12,0.12,0.1,1)
    c:SetCenterColor(0.06,0.06,0.06,0.9) c:SetMouseEnabled(false)
    return c
end
local function Label(parent,x,width,align)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    c:SetDimensions(width,26) c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,3)
    c:SetHorizontalAlignment(align) c:SetMouseEnabled(false)
    c:SetDrawTier(DT_HIGH)
    return c
end
local function Icon(parent,x,texture)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    c:SetDimensions(18,18) c:SetAnchor(LEFT,parent,LEFT,x,0)
    c:SetDrawTier(DT_HIGH) c:SetMouseEnabled(false)
    if texture then c:SetTexture(texture) end
    return c
end
local function Row(index)
    if rows[index] then return rows[index] end
    local bg=Box(root) bg:SetDimensions(254,30)
    bg:SetAnchor(TOPLEFT,root,TOPLEFT,math.floor((index-1)/12)*262,((index-1)%12)*34)
    local fill=Box(bg) fill:SetAnchor(TOPLEFT,bg,TOPLEFT,1,1) fill:SetHeight(28)
    local name=Label(bg,46,146,TEXT_ALIGN_LEFT)
    local hp=Label(bg,196,84,TEXT_ALIGN_RIGHT)
    local role=Icon(bg,4)
    local crown=Icon(bg,24,"EsoUI/Art/UnitFrames/groupIcon_leader.dds")
    local row={bg=bg,fill=fill,name=name,hp=hp,role=role,crown=crown}
    -- Dedicated input surface above the visual children. The movable root must
    -- not compete with rows for mouse input.
    local hit=WINDOW_MANAGER:CreateControl(nil,bg,CT_CONTROL)
    hit:SetAnchorFill(bg)
    hit:SetDrawTier(DT_HIGH) hit:SetDrawLayer(DL_OVERLAY) hit:SetDrawLevel(20)
    hit:SetMouseEnabled(true)
    row.hit=hit
    local function ClearHover()
        if hoveredRow==row then
            hoveredRow=nil
            if InformationTooltip then ClearTooltip(InformationTooltip) end
        end
    end
    hit:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and IsShiftKeyDown() then
            ClearHover()
            root:SetMovable(true) root:StartMoving()
            row.dragging=true
        end
    end)
    hit:SetHandler("OnMouseUp",function(_,button,inside)
        if row.dragging then
            root:StopMovingOrResizing() root:SetMovable(false)
            settings.x=root:GetLeft() settings.y=root:GetTop()
            row.dragging=false
            return
        end
        if button==MOUSE_BUTTON_INDEX_RIGHT and inside~=false then
            ClearHover()
            DIAhelpGroupMenu.Show(hit,row.unitTag,row.companion)
        end
    end)
    hit:SetHandler("OnMouseEnter",function()
        if not row.dragging then hoveredRow=row ShowLocation(row) end
    end)
    hit:SetHandler("OnMouseExit",ClearHover)
    hit:SetHandler("OnHide",ClearHover)
    rows[index]=row return row
end
local function Update()
    local units={}
    local players={}
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then players[#players+1]=tag end
    end
    local raid=#players>4
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag then
            units[#units+1]={tag=tag}
            local companion=GetCompanionUnitTagByGroupUnitTag(tag)
            if not raid and companion and DoesUnitExist(companion) then units[#units+1]={tag=companion,companion=true} end
        end
    end
    local width=raid and 161 or 286
    local perColumn=raid and 6 or 12
    local heights={0,0,0,0}
    local totalHeight=1
    for i,unit in ipairs(units) do
        local tag=unit.tag local row=Row(i)
        row.unitTag=tag row.companion=unit.companion
        local column=math.floor((i-1)/perColumn)+1
        heights[column]=heights[column] or 0
        local height=raid and 38 or (unit.companion and 20 or 30)
        row.bg:ClearAnchors()
        row.bg:SetAnchor(TOPLEFT,root,TOPLEFT,(column-1)*(width+8),heights[column])
        row.bg:SetDimensions(width,height)
        heights[column]=heights[column]+height+4
        totalHeight=math.max(totalHeight,heights[column])
        row.fill:SetHeight(height-2)
        row.name:SetFont(unit.companion and "$(BOLD_FONT)|14|soft-shadow-thick" or "$(BOLD_FONT)|16|soft-shadow-thick")
        row.hp:SetFont(unit.companion and "$(BOLD_FONT)|14|soft-shadow-thick" or "$(BOLD_FONT)|16|soft-shadow-thick")
        row.name:ClearAnchors() row.hp:ClearAnchors()
        row.name:SetAnchor(LEFT,row.bg,LEFT,unit.companion and 26 or 46,0)
        row.name:SetDimensions(unit.companion and 166 or 146,height)
        row.hp:SetAnchor(LEFT,row.bg,LEFT,196,0)
        row.hp:SetDimensions(84,height)
        row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER) row.hp:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if raid then
            -- Separate name and health lines keep long names out of the numbers.
            row.name:ClearAnchors() row.hp:ClearAnchors()
            row.name:SetAnchor(TOPLEFT,row.bg,TOPLEFT,46,1)
            row.name:SetDimensions(width-52,19)
            row.name:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
            row.hp:SetAnchor(TOPLEFT,row.bg,TOPLEFT,46,20)
            row.hp:SetDimensions(width-52,16)
            row.hp:SetFont("$(BOLD_FONT)|13|soft-shadow-thick")
            row.hp:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        else
            row.hp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        end
        row.bg:SetHidden(false)
        local online=unit.companion or IsUnitOnline(tag)
        local remote=not unit.companion and online and IsRemote(tag)
        local alpha=(not online or remote) and 0.45 or 1
        row.fill:SetAlpha(alpha)
        row.name:SetAlpha(alpha) row.hp:SetAlpha(alpha)
        row.role:SetAlpha(alpha) row.crown:SetAlpha(alpha)
        local current,maximum=GetUnitPower(tag,POWERTYPE_HEALTH)
        local fraction=maximum>0 and math.max(0,math.min(1,current/maximum)) or 0
        local dead=online and IsUnitDeadOrReincarnating(tag)
        row.fill:SetWidth(math.max(1,(width-2)*fraction))
        row.fill:SetHidden(not online or dead)
        row.fill:SetCenterColor(unit.companion and 0.23 or 0.45,unit.companion and 0.34 or 0.14,0.15,0.95)
        local leader=not unit.companion and IsUnitGroupLeader(tag)
        row.crown:SetHidden(not leader)
        local role=not unit.companion and GetGroupMemberSelectedRole(tag) or LFG_ROLE_INVALID
        local texture=role~=LFG_ROLE_INVALID and ZO_GetRoleIcon(role) or nil
        row.role:SetHidden(not texture)
        if texture then row.role:SetTexture(texture) end
        -- ESO's formatter follows the current keyboard/gamepad name preference
        -- and preserves the @ prefix of account names.
        local display=unit.companion and GetUnitName(tag) or ZO_GetPrimaryPlayerNameFromUnitTag(tag)
        row.name:SetText(zo_strformat(SI_UNIT_NAME,display))
        row.name:SetColor(online and 1 or 0.5,online and 0.95 or 0.5,online and 0.8 or 0.5,1)
        if not online then row.hp:SetText(ru and "Не в сети" or "Offline")
        elseif dead then row.hp:SetText(ru and "Мёртв" or "Dead")
        else row.hp:SetText(string.format("%.1fk %d%%",current/1000,math.floor(fraction*100+0.5))) end
    end
    for i=#units+1,#rows do
        rows[i].bg:SetHidden(true)
        if hoveredRow==rows[i] then
            hoveredRow=nil
            if InformationTooltip then ClearTooltip(InformationTooltip) end
        end
    end
    if hoveredRow then ShowLocation(hoveredRow) end
    root:SetDimensions(math.max(1,math.ceil(#units/perColumn))*(width+8)-8,totalHeight)
end
EVENT_MANAGER:RegisterForEvent("DIAhelpGroupFrames",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="DIAhelp" then return end
    EVENT_MANAGER:UnregisterForEvent("DIAhelpGroupFrames",EVENT_ADD_ON_LOADED)
    ru=GetCVar("language.2")=="ru"
    settings=ZO_SavedVars:NewAccountWide("DIAhelpSavedVariables",1,"groupFrames",{})
    root=WINDOW_MANAGER:CreateTopLevelWindow("DIAhelpGroupFrames")
    root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,settings.x or 28,settings.y or 100)
    root:SetMouseEnabled(false) root:SetMovable(false) root:SetClampedToScreen(true)
    root:SetHandler("OnMoveStop",function() settings.x=root:GetLeft() settings.y=root:GetTop() end)
    local fragment=ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    local function HideNative()
        if ZO_UnitFramesGroups then ZO_UnitFramesGroups:SetHidden(true) end
    end
    if ZO_UnitFramesGroups then ZO_PostHookHandler(ZO_UnitFramesGroups,"OnShow",HideNative) end
    EVENT_MANAGER:RegisterForEvent("DIAhelpGroupFrames",EVENT_PLAYER_ACTIVATED,function() Update() HideNative() end)
    EVENT_MANAGER:RegisterForUpdate("DIAhelpGroupFrames",250,function() Update() HideNative() end)
end)
