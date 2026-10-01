local AlabuzyaUI = AlabuzyaUI
-- Presentation only. Inventory, maintenance, chat, quests and map data stay in shared modules.
AlabuzyaUI.ClassicTheme = {}
local C = AlabuzyaUI.ClassicTheme
local T = AlabuzyaUI.Theme
local WM = WINDOW_MANAGER
local root, container, xp, playerFrame, playerName, levelLabel, playerCrest
local resources, inactive, activeFrames = {}, {}, {}
local classIcons = {}
local groupResources, groupedLayout
local function Texture(parent, path, layer)
    local c=WM:CreateControl(nil,parent,CT_TEXTURE)
    c:SetTexture(path) c:SetMouseEnabled(false)
    c:SetDrawLayer(layer or DL_BACKGROUND)
    return c
end
local function Label(parent,size)
    local c=WM:CreateControl(nil,parent,CT_LABEL)
    T.Text(c,size) c:SetMouseEnabled(false)
    c:SetDrawLayer(DL_OVERLAY) c:SetDrawLevel(30)
    return c
end
local function HUD(c)
    local f=ZO_HUDFadeSceneFragment:New(c)
    c.alabuzyaHUDFragment=f
    HUD_SCENE:AddFragment(f) HUD_UI_SCENE:AddFragment(f)
end
function C.ClassIcon(tag)
    if not next(classIcons) and GetNumClasses and GetClassInfo then
        for i=1,GetNumClasses() do
            local id,_,normal,_,_,_,ingame=GetClassInfo(i)
            classIcons[id]=ingame or normal
        end
    end
    return classIcons[GetUnitClassId and GetUnitClassId(tag) or 0]
        or 'EsoUI/Art/Icons/achievement_dungeon_001.dds'
end
function C.RoleIcon(tag)
    local role
    if tag=='player' or (AreUnitsEqual and AreUnitsEqual(tag,'player')) then
        role=GetSelectedLFGRole and GetSelectedLFGRole()
    else
        role=GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag)
    end
    if not role or role==LFG_ROLE_INVALID then return nil end
    return ZO_GetRoleIcon(role)
end
function C.UpdateRole(crest,tag)
    local icon=C.RoleIcon(tag)
    crest.icon:SetHidden(not icon)
    if icon then crest.icon:SetTexture(icon) end
end
function C.Crest(parent,size)
    local c=WM:CreateControl(nil,parent,CT_CONTROL)
    c:SetDimensions(size,size) c:SetMouseEnabled(false)
    local icon=Texture(c,C.RoleIcon('player') or '',DL_CONTROLS)
    icon:SetHidden(not C.RoleIcon('player'))
    icon:SetDimensions(size*.68,size*.68) icon:SetAnchor(CENTER,c,CENTER,0,0)
    icon:SetMaskMode(CONTROL_MASK_MODE_BASIC)
    icon:SetMaskTexture('AlabuzyaUI/Textures/ClassicCircleMask.dds')
    local ring=Texture(c,'AlabuzyaUI/Textures/ClassicRing.dds',DL_OVERLAY)
    ring:SetAnchorFill() ring:SetDrawLevel(10)
    c.icon=icon
    return c
end
-- Real nine-slice borders: corners never stretch with chat/quest resizing.
function C.Panel(parent,_,openBottom)
    if parent.alabuzyauiFrame then return end
    parent.alabuzyauiFrame=true
    local uv={0,.085,.915,1}
    for y=1,3 do for x=1,3 do
        if (x~=2 or y~=2) and (not openBottom or y~=3) then
            local c=Texture(parent,'AlabuzyaUI/Textures/ClassicPanel.dds',DL_OVERLAY)
            c:SetTextureCoords(uv[x],uv[x+1],uv[y],uv[y+1])
            c:SetDrawLevel(5)
            local corner=10
            if x==2 then
                c:SetHeight(6)
                c:SetAnchor(y==1 and TOPLEFT or BOTTOMLEFT,parent,y==1 and TOPLEFT or BOTTOMLEFT,corner,0)
                c:SetAnchor(y==1 and TOPRIGHT or BOTTOMRIGHT,parent,y==1 and TOPRIGHT or BOTTOMRIGHT,-corner,0)
            elseif y==2 then
                c:SetWidth(6)
                c:SetAnchor(x==1 and TOPLEFT or TOPRIGHT,parent,x==1 and TOPLEFT or TOPRIGHT,0,corner)
                c:SetAnchor(x==1 and BOTTOMLEFT or BOTTOMRIGHT,parent,x==1 and BOTTOMLEFT or BOTTOMRIGHT,0,openBottom and 0 or -corner)
            else
                local point=y==1 and (x==1 and TOPLEFT or TOPRIGHT) or (x==1 and BOTTOMLEFT or BOTTOMRIGHT)
                c:SetDimensions(corner,corner) c:SetAnchor(point,parent,point,0,0)
            end
        end
    end end
end
local function Window(key,w,h,x,y,framed)
    local saved=AlabuzyaUI.SavedVariables.Account(key,{})
    local c=WM:CreateTopLevelWindow('AlabuzyaUI'..key)
    c:SetDimensions(w,h)
    c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,saved.x or x,saved.y or y)
    c:SetClampedToScreen(true) c:SetMovable(true) c:SetMouseEnabled(true)
    c:SetHandler('OnMoveStop',function() saved.x=c:GetLeft() saved.y=c:GetTop() end)
    if framed then T.Backdrop(c) C.Panel(c) end
    HUD(c) return c
end
function C.Configure()
    T.classic=true
    T.Panel=C.Panel
    T.Text=function(c,size) c:SetFont(T.Font(size)) c:SetColor(.95,.83,.56,1) end
    T.Backdrop=function(parent)
        local b=WM:CreateControl(nil,parent,CT_BACKDROP)
        b:SetAnchorFill() b:SetCenterColor(.035,.037,.04,.82)
        b:SetEdgeColor(.40,.31,.17,.9) b:SetEdgeTexture(nil,1,1,1)
        b:SetMouseEnabled(false) b:SetDrawLayer(DL_BACKGROUND)
        return b
    end
    T.Separator=function(parent,y)
        local c=WM:CreateControl(nil,parent,CT_TEXTURE)
        c:SetColor(.55,.43,.24,.65) c:SetHeight(1)
        c:SetAnchor(TOPLEFT,parent,TOPLEFT,10,y) c:SetAnchor(TOPRIGHT,parent,TOPRIGHT,-10,y)
        c:SetMouseEnabled(false)
    end
    T.MapHost=function()
        if not C.mapHost then C.mapHost=Window('ClassicMapPosition',272,362,GuiRoot:GetWidth()-298,18,false) end
        return C.mapHost
    end
    T.QuestHost=function()
        if not C.questHost then C.questHost=Window('ClassicQuestPosition',342,300,GuiRoot:GetWidth()-364,404,true) end
        return C.questHost
    end
    T.SidebarHeight=function(h) T.QuestHost():SetHeight(h) end
end
function C.SkinMap(map,view,title,clock,zoom)
    view:ClearAnchors() view:SetAnchor(TOPLEFT,map,TOPLEFT,8,55)
    map:SetHeight(362)
    view:SetMaskMode(CONTROL_MASK_MODE_BASIC)
    view:SetMaskTexture('AlabuzyaUI/Textures/ClassicCircleMask.dds')
    local ring=Texture(map,'AlabuzyaUI/Textures/ClassicRing.dds',DL_OVERLAY)
    ring:SetDimensions(298,298) ring:SetAnchor(CENTER,view,CENTER,0,0) ring:SetDrawLevel(100)
    title:ClearAnchors() title:SetAnchor(TOP,view,TOP,0,-53)
    title:SetDimensions(256,30) T.Text(title,19)
    local plaque=WM:CreateControl(nil,map,CT_CONTROL)
    plaque:SetDimensions(254,30) plaque:SetAnchor(CENTER,title,CENTER,0,0)
    T.Backdrop(plaque) C.Panel(plaque) plaque:SetMouseEnabled(false)
    clock:ClearAnchors() clock:SetAnchor(TOP,view,BOTTOM,0,23)
    clock:SetDimensions(232,26) clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER) T.Text(clock,17)
    if zoom then
        for _,spec in ipairs({{'+',130,75,1},{'-',110,112,-1}}) do
            local delta=spec[4]
            local button=WM:CreateControl(nil,map,CT_CONTROL)
            button:SetDimensions(30,30) button:SetAnchor(CENTER,view,CENTER,spec[2],spec[3])
            button:SetMouseEnabled(true)
            local bg=WM:CreateControl(nil,button,CT_TEXTURE)
            bg:SetAnchorFill() bg:SetColor(.04,.04,.04,.96)
            bg:SetMaskMode(CONTROL_MASK_MODE_BASIC) bg:SetMaskTexture('AlabuzyaUI/Textures/ClassicCircleMask.dds')
            local edge=Texture(button,'AlabuzyaUI/Textures/ClassicRing.dds',DL_OVERLAY)
            edge:SetAnchorFill() edge:SetDrawLevel(101)
            local sign=Label(button,22) sign:SetText(spec[1]) sign:SetAnchor(CENTER,button,CENTER,0,0)
            sign:SetDrawLevel(102)
            button:SetHandler('OnMouseUp',function(_,key,inside)
                if key==MOUSE_BUTTON_INDEX_LEFT and inside then zoom(delta) end
            end)
        end
    end
end
local function SizeButton(button,anchor)
    if not button or not button.slot then return end
    local slot=button.slot
    slot:ClearAnchors() slot:SetDimensions(46,46)
    slot:SetAnchor(CENTER,anchor,CENTER,0,0)
    if button.flipCard then button.flipCard:SetDimensions(46,46) end
    if button.icon then
        button.icon:ClearAnchors()
        if button.flipCard then
            button.icon:SetAnchor(TOPLEFT,button.flipCard,TOPLEFT,0,0)
            button.icon:SetAnchor(BOTTOMRIGHT,button.flipCard,BOTTOMRIGHT,0,0)
        else button.icon:SetAnchor(CENTER,slot,CENTER,0,0) end
        button.icon:SetDimensions(46,46)
    end
    if button.button then button.button:SetDimensions(46,46) end
    if button.status then button.status:SetDimensions(46,46) end
    if button.buttonText then
        button.buttonText:ClearAnchors()
        button.buttonText:SetAnchor(TOPRIGHT,slot,TOPRIGHT,-1,0)
        button.buttonText:SetFont(T.Font(14,'thick-outline'))
    end
    if button.timerText then button.timerText:SetFont(T.Font(20,'thick-outline')) end
    if button.countText then button.countText:SetFont(T.Font(15,'thick-outline')) end
    local decoration=slot:GetNamedChild('Decoration')
    if decoration then decoration:SetHidden(true) end
    if button.ApplySwapAnimationStyle then button:ApplySwapAnimationStyle() end
end
function C.LayoutBar()
    if not container or IsInGamepadPreferredMode() then return end
    local active=GetActiveHotbarCategory()
    local other=active==HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP
        or active==HOTBAR_CATEGORY_BACKUP and HOTBAR_CATEGORY_PRIMARY or nil
    for i=1,7 do
        if not activeFrames[i] then
            local c=WM:CreateControl(nil,root,CT_CONTROL)
            c:SetDimensions(52,52) c:SetMouseEnabled(false)
            T.Backdrop(c) C.Panel(c) activeFrames[i]=c
        end
        local cell=activeFrames[i]
        cell:ClearAnchors() cell:SetAnchor(LEFT,container,LEFT,(i-1)*60,0)
        local button
        if i==1 then button=ZO_ActionBar_GetButton(1,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        elseif i==7 then button=ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX+1)
        else button=ZO_ActionBar_GetButton(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+i-1) end
        SizeButton(button,cell)
        if i>1 then
            local slotIndex=i==7 and ACTION_BAR_ULTIMATE_SLOT_INDEX+1 or ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+i-1
            if not inactive[i] then
                local c=WM:CreateControl(nil,root,CT_CONTROL)
                c:SetDimensions(46,46) c:SetMouseEnabled(false)
                T.Backdrop(c) C.Panel(c)
                c.icon=Texture(c,'',DL_CONTROLS)
                c.icon:SetAnchor(CENTER,c,CENTER,0,0) c.icon:SetDimensions(38,38)
                c.timer=WM:CreateControl(nil,c,CT_STATUSBAR)
                c.timer:SetDimensions(36,3) c.timer:SetAnchor(BOTTOM,c,BOTTOM,0,-5)
                c.timer:SetMinMax(0,1) c.timer:SetColor(.85,.70,.26,1)
                c.timer:SetDrawLayer(DL_OVERLAY) c.timer:SetDrawLevel(15)
                c:SetAlpha(.62) inactive[i]=c
            end
            local c=inactive[i]
            c:ClearAnchors() c:SetAnchor(BOTTOM,cell,TOP,0,-8)
            local tex=other and GetSlotTexture(slotIndex,other)
            c.icon:SetTexture(tex or '') c.icon:SetHidden(not tex or tex=='')
            c:SetHidden(not other)
            -- Retain ESO's back-bar duration bookkeeping without drawing its
            -- second, differently anchored icon on top of our always-visible row.
            local timer=other and ZO_ActionBar_GetButton(slotIndex,other)
            if timer and timer.iconTexture and timer.slot then
                timer.slot:SetAlpha(0)
                c.nativeTimer=timer
            else c.nativeTimer=nil end
        end
    end
    AlabuzyaUI.Companion.ApplyPolicy()
    if C.AfterLayout then C.AfterLayout() end
end
local function Short(v) return v>=1000 and string.format('%.1fk',v/1000) or tostring(math.floor(v)) end
function C.IsGrouped()
    return IsUnitGrouped and IsUnitGrouped('player') or false
end
function C.Update()
    if not root then return end
    local grouped=C.IsGrouped()
    if groupedLayout~=grouped then
        groupedLayout=grouped
        playerFrame.alabuzyaHUDFragment:SetHiddenForReason('AlabuzyaUIGroupedResources',grouped)
        groupResources:SetHidden(not grouped)
    end
    for _,cell in pairs(inactive) do
        local native=cell.nativeTimer
        local remaining=native and native.endTimeMS and native.endTimeMS-GetFrameTimeMilliseconds() or 0
        local shown=native and native.showBackRowSlot and remaining>0 and native.durationMS and native.durationMS>0
        cell.timer:SetHidden(not shown)
        if shown then cell.timer:SetValue(math.min(1,remaining/native.durationMS)) end
    end
    for _,r in ipairs(resources) do
        local value,maximum=GetUnitPower('player',r.power)
        r.bar:SetMinMax(0,math.max(1,maximum)) r.bar:SetValue(value)
        local suffix=''
        if r.power==POWERTYPE_HEALTH and POWERTYPE_DAMAGE_SHIELD then
            local shield=GetUnitPower('player',POWERTYPE_DAMAGE_SHIELD)
            if shield>0 then suffix=' |c88CCFF+'..Short(shield)..'|r' end
        end
        r.label:SetText(Short(value)..' / '..Short(maximum)..suffix)
    end
    C.UpdateRole(playerCrest,'player')
    playerName:SetText(zo_strformat('<<1>>',GetUnitName('player')))
    local cp=GetUnitChampionPoints('player') or 0
    levelLabel:SetText(cp>0 and ('CP '..cp) or tostring(GetUnitLevel('player')))
    local earned,needed=0,1
    if IsUnitChampion and IsUnitChampion('player') and GetPlayerChampionXP and GetNumChampionXPInChampionPoint then
        earned=GetPlayerChampionXP() needed=GetNumChampionXPInChampionPoint(GetPlayerChampionPointsEarned())
    elseif GetUnitXP and GetUnitXPMax then earned=GetUnitXP('player') needed=GetUnitXPMax('player') end
    xp:SetMinMax(0,math.max(1,needed or 0)) xp:SetValue(earned or 0)
end
function C.InitializeHUD()
    root=WM:CreateTopLevelWindow('AlabuzyaUIClassicActionBar')
    root:SetDimensions(720,118) root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,0,-4)
    root:SetMouseEnabled(false) HUD(root)
    local art=Texture(root,'AlabuzyaUI/Textures/ClassicChassis.dds')
    art:SetAnchorFill()
    container=WM:CreateControl(nil,root,CT_CONTROL)
    container:SetDimensions(412,52) container:SetAnchor(BOTTOM,root,BOTTOM,0,-18)
    local xpBG=WM:CreateControl(nil,root,CT_CONTROL)
    xpBG:SetDimensions(432,8) xpBG:SetAnchor(BOTTOM,root,BOTTOM,0,-6)
    T.Backdrop(xpBG)
    xp=WM:CreateControl('AlabuzyaUIExperienceBar',xpBG,CT_STATUSBAR)
    xp:SetDimensions(428,4) xp:SetAnchor(CENTER,xpBG,CENTER,0,0)
    xp:SetColor(.48,.26,.83,1)
    for i=1,9 do
        local d=WM:CreateControl(nil,xpBG,CT_TEXTURE)
        d:SetDimensions(1,6) d:SetColor(.08,.06,.04,1)
        d:SetAnchor(LEFT,xpBG,LEFT,i*43.2,0) d:SetDrawLayer(DL_OVERLAY)
    end
    playerFrame=Window('ClassicPlayerPosition',326,104,24,30,false)
    local crest=C.Crest(playerFrame,86) playerCrest=crest crest:SetAnchor(LEFT,playerFrame,LEFT,0,0)
    playerName=Label(playerFrame,19) playerName:SetAnchor(TOPLEFT,playerFrame,TOPLEFT,94,0)
    playerName:SetDimensions(224,25)
    levelLabel=Label(playerFrame,13) levelLabel:SetAnchor(BOTTOM,crest,BOTTOM,0,9)
    local colors={{.16,.62,.12},{.08,.31,.78},{.76,.59,.13}}
    for i,power in ipairs({POWERTYPE_HEALTH,POWERTYPE_MAGICKA,POWERTYPE_STAMINA}) do
        local frame=WM:CreateControl(nil,playerFrame,CT_CONTROL)
        frame:SetDimensions(226,i==1 and 25 or 22)
        frame:SetAnchor(TOPLEFT,playerFrame,TOPLEFT,90,25+(i-1)*24)
        T.Backdrop(frame) C.Panel(frame)
        local bar=WM:CreateControl(nil,frame,CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT,frame,TOPLEFT,5,4) bar:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-5,-4)
        bar:SetColor(unpack(colors[i]))
        local label=Label(frame,14) label:SetAnchor(CENTER,frame,CENTER,0,0)
        resources[i]={bar=bar,label=label,power=power}
    end
    -- Health spans the full width, with magicka/stamina side by side below.
    -- This window follows the action bar; the solo window retains its saved position.
    groupResources=WM:CreateControl('AlabuzyaUIGroupResources',root,CT_CONTROL)
    groupResources:SetDimensions(432,50)
    groupResources:SetAnchor(BOTTOM,root,TOP,0,-8)
    groupResources:SetMouseEnabled(false) groupResources:SetHidden(true)
    for i,power in ipairs({POWERTYPE_HEALTH,POWERTYPE_MAGICKA,POWERTYPE_STAMINA}) do
        local frame=WM:CreateControl(nil,groupResources,CT_CONTROL)
        frame:SetDimensions(i==1 and 432 or 214,24)
        frame:SetAnchor(TOPLEFT,groupResources,TOPLEFT,i==3 and 218 or 0,i==1 and 0 or 26)
        T.Backdrop(frame) C.Panel(frame)
        local bar=WM:CreateControl('AlabuzyaUIGroupResourceBar'..i,frame,CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT,frame,TOPLEFT,5,4) bar:SetAnchor(BOTTOMRIGHT,frame,BOTTOMRIGHT,-5,-4)
        bar:SetColor(unpack(colors[i]))
        local label=Label(frame,14) label:SetAnchor(CENTER,frame,CENTER,0,0)
        resources[#resources+1]={bar=bar,label=label,power=power}
    end
    local pending=false
    local function ScheduleLayout()
        if pending then return end
        pending=true
        zo_callLater(function() pending=false C.LayoutBar() end,0)
    end
    for _,event in ipairs({EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,
        EVENT_HOTBAR_SLOT_UPDATED,EVENT_ACTIVE_WEAPON_PAIR_CHANGED,EVENT_PLAYER_ACTIVATED}) do
        EVENT_MANAGER:RegisterForEvent('AlabuzyaUIClassicBar',event,ScheduleLayout)
    end
    -- Hook actual button methods: ESO's encompassing ApplyStyle is local.
    for i=1,7 do
        local button=i==1 and ZO_ActionBar_GetButton(1,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            or ZO_ActionBar_GetButton(i==7 and ACTION_BAR_ULTIMATE_SLOT_INDEX+1 or ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+i-1)
        if button and ZO_PostHook then
            if button.ApplyStyle then ZO_PostHook(button,'ApplyStyle',ScheduleLayout) end
            if button.ApplyAnchor then ZO_PostHook(button,'ApplyAnchor',ScheduleLayout) end
        end
    end
    C.LayoutBar() C.Update()
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIResources',100,C.Update)
end
