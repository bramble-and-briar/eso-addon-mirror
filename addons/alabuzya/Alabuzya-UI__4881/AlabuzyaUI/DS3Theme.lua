local AlabuzyaUI = AlabuzyaUI
-- DS_3 presentation. Shared inventory, map, quest and combat modules own their data.
AlabuzyaUI.DS3Theme = {}
local D=AlabuzyaUI.DS3Theme
local T=AlabuzyaUI.Theme
local WM=WINDOW_MANAGER
local root,player,chatIcon,damageLabel,shareLabel
local cells,resources={},{}
local slide,unread,chatReady=16,false,false
local pendingDamage,pendingShare=0,nil
local BAR_WIDTH,BAR_HEIGHT=490,174
local CHAT_GAP=56
local function Texture(parent,path)
    local c=WM:CreateControl(nil,parent,CT_TEXTURE)
    c:SetTexture(path) c:SetMouseEnabled(false)
    c:SetDrawLayer(DL_OVERLAY) return c
end
local function Label(parent,size)
    local c=WM:CreateControl(nil,parent,CT_LABEL)
    T.Text(c,size) c:SetMouseEnabled(false) c:SetDrawLayer(DL_OVERLAY)
    return c
end
local function HUD(c)
    local f=ZO_HUDFadeSceneFragment:New(c)
    HUD_SCENE:AddFragment(f) HUD_UI_SCENE:AddFragment(f)
end
local function Window(key,w,h,x,y)
    local c=WM:CreateTopLevelWindow('AlabuzyaUI'..key)
    local saved=AlabuzyaUI.SavedVariables.Account(key,{})
    c:SetDimensions(w,h) c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,saved.x or x,saved.y or y)
    c:SetClampedToScreen(true) c:SetMouseEnabled(false)
    c:SetHandler('OnMoveStop',function() saved.x=c:GetLeft() saved.y=c:GetTop() end)
    HUD(c) return c
end
function D.Panel(parent,_,openBottom)
    if parent.alabuzyauiFrame then return end
    parent.alabuzyauiFrame=true
    -- A real nine-slice: transparent center, fixed corners, stretching edge strips.
    local uv={0,.12,.88,1}
    for y=1,3 do for x=1,3 do
        if (x~=2 or y~=2) and (not openBottom or y~=3) then
            local c=Texture(parent,'AlabuzyaUI/Textures/DS3Panel.dds')
            c:SetTextureCoords(uv[x],uv[x+1],uv[y],uv[y+1]) c:SetDrawLevel(5)
            if x==2 then
                c:SetHeight(5)
                c:SetAnchor(y==1 and TOPLEFT or BOTTOMLEFT,parent,y==1 and TOPLEFT or BOTTOMLEFT,6,0)
                c:SetAnchor(y==1 and TOPRIGHT or BOTTOMRIGHT,parent,y==1 and TOPRIGHT or BOTTOMRIGHT,-6,0)
            elseif y==2 then
                c:SetWidth(5)
                c:SetAnchor(x==1 and TOPLEFT or TOPRIGHT,parent,x==1 and TOPLEFT or TOPRIGHT,0,6)
                c:SetAnchor(x==1 and BOTTOMLEFT or BOTTOMRIGHT,parent,x==1 and BOTTOMLEFT or BOTTOMRIGHT,0,-6)
            else
                c:SetDimensions(6,6)
                local anchor=y==1 and (x==1 and TOPLEFT or TOPRIGHT) or (x==1 and BOTTOMLEFT or BOTTOMRIGHT)
                c:SetAnchor(anchor,parent,anchor,0,0)
            end
        end
    end end
end
function D.Configure()
    -- Reuse separate-window presentation plumbing, never duplicate functional modules.
    AlabuzyaUI.ClassicTheme.Configure()
    T.ds3=true T.Panel=D.Panel
    -- ESO standard localized interface face for this theme.
    T.font='$(MEDIUM_FONT)'
    T.Text=function(c,size) c:SetFont(T.Font(size)) c:SetColor(.91,.88,.79,1) end
    T.Backdrop=function(parent)
        local c=WM:CreateControl(nil,parent,CT_BACKDROP)
        c:SetAnchorFill() c:SetCenterColor(.035,.033,.03,.74)
        c:SetEdgeColor(0,0,0,0) c:SetEdgeTexture(nil,1,1,1)
        c:SetMouseEnabled(false) c:SetDrawLayer(DL_BACKGROUND) return c
    end
    T.MapHost=function()
        if not D.map then D.map=Window('DS3MapPosition',272,330,GuiRoot:GetWidth()-292,12) end
        return D.map
    end
    T.QuestHost=function()
        if not D.quests then D.quests=Window('DS3QuestPosition',342,300,GuiRoot:GetWidth()-350,338) end
        return D.quests
    end
end
function D.SkinMap(map,view,title,clock,zoom)
    view:ClearAnchors() view:SetAnchor(TOPLEFT,map,TOPLEFT,8,35)
    view:SetMaskMode(CONTROL_MASK_MODE_BASIC)
    view:SetMaskTexture('AlabuzyaUI/Textures/ClassicCircleMask.dds')
    local ring=Texture(map,'AlabuzyaUI/Textures/DS3Ring.dds')
    ring:SetDimensions(266,266) ring:SetAnchor(CENTER,view,CENTER,0,0) ring:SetDrawLevel(100)
    title:ClearAnchors() title:SetAnchor(TOP,view,TOP,0,-31)
    title:SetDimensions(248,25) T.Text(title,18)
    clock:ClearAnchors() clock:SetAnchor(TOP,view,BOTTOM,0,12)
    clock:SetDimensions(248,25) clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER) T.Text(clock,16)
    map:SetHeight(330)
    view:SetMouseEnabled(true)
    view:SetHandler('OnMouseWheel',function(_,delta) zoom(delta) end)
end
local function Cell(key,x,y,size)
    if cells[key] then return cells[key] end
    local c=WM:CreateControl(nil,root,CT_CONTROL)
    c:SetDimensions(size,size) c:SetAnchor(TOPLEFT,root,TOPLEFT,x,y)
    T.Backdrop(c)
    local edge=Texture(c,'AlabuzyaUI/Textures/DS3SlotV2.dds') edge:SetAnchorFill() edge:SetDrawLevel(10)
    c.icon=Texture(c,'') c.icon:SetAnchor(TOPLEFT,c,TOPLEFT,4,4)
    c.icon:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-4,-4)
    c.keyPlate=WM:CreateControl(nil,c,CT_BACKDROP)
    c.keyPlate:SetDimensions(24,18) c.keyPlate:SetAnchor(TOP,c,BOTTOM,0,3)
    c.keyPlate:SetCenterColor(.025,.024,.022,.9) c.keyPlate:SetEdgeColor(.42,.38,.27,.9)
    c.keyPlate:SetEdgeTexture(nil,1,1,1) c.keyPlate:SetMouseEnabled(false)
    c.keyPlate:SetDrawTier(DT_HIGH) c.keyPlate:SetDrawLayer(DL_OVERLAY) c.keyPlate:SetDrawLevel(100)
    c.key=Label(c.keyPlate,14) c.key:SetAnchor(CENTER,c.keyPlate,CENTER,0,0)
    c.key:SetDrawTier(DT_HIGH) c.key:SetDrawLevel(101)
    c.timer=WM:CreateControl(nil,c,CT_STATUSBAR)
    c.timer:SetDimensions(size-8,3) c.timer:SetAnchor(BOTTOM,c,BOTTOM,0,-4)
    c.timer:SetMinMax(0,1) c.timer:SetColor(.75,.65,.38,1)
    c.timer:SetDrawLayer(DL_OVERLAY) c.timer:SetDrawLevel(15)
    c:SetMouseEnabled(false) cells[key]=c return c
end
local function SetKey(cell,text)
    cell.key:SetText(text) cell.keyPlate:SetHidden(not text or text=='')
    cell.keyPlate:SetWidth(math.max(24,math.min(100,#(text or '')*7+8)))
end
local function Binding(action,fallback)
    return (ZO_Keybindings_GetHighestPriorityBindingStringFromAction
        and ZO_Keybindings_GetHighestPriorityBindingStringFromAction(action)) or fallback
end
local function PlaceNative(button,cell,size,ultimate)
    AlabuzyaUI.ClassicTheme.SizeButton(button,cell,size)
    if not button then return end
    if button.slot then button.slot:SetAlpha(1) end
    if button.buttonText then
        button.buttonText:SetHidden(ultimate)
        if not ultimate then
            button.buttonText:ClearAnchors() button.buttonText:SetAnchor(TOP,cell,BOTTOM,0,3)
            button.buttonText:SetDrawTier(DT_HIGH) button.buttonText:SetDrawLevel(100)
        end
    end
end
function D.WeaponIcon(active)
    -- Oakensoul is detected from the equipped set's ID, independent of localization.
    for _,slot in ipairs({EQUIP_SLOT_RING1,EQUIP_SLOT_RING2}) do
        local link=GetItemLink(BAG_WORN,slot)
        local hasSet,_,_,_,_,setId=GetItemLinkSetInfo(link,true)
        if hasSet and setId==658 then return GetItemInfo(BAG_WORN,slot),true,true end
    end
    local slot=active==HOTBAR_CATEGORY_BACKUP and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN
    local texture=GetItemInfo(BAG_WORN,slot)
    if not texture or texture=='' then
        texture=GetItemInfo(BAG_WORN,active==HOTBAR_CATEGORY_BACKUP and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF)
    end
    local _,locked=GetActiveWeaponPairInfo()
    return texture or '',locked,false
end
function D.LayoutBar()
    if not root or IsInGamepadPreferredMode() then return end
    local active=GetActiveHotbarCategory()
    local weapon=active==HOTBAR_CATEGORY_PRIMARY or active==HOTBAR_CATEGORY_BACKUP
    local texture,locked,oakensoul=D.WeaponIcon(active)
    local swap=Cell('swap',0,35,64)
    swap.icon:SetTexture(texture) swap:SetHidden(not weapon)
    SetKey(swap,locked and '' or Binding('WEAPON_SWAP','~'))
    swap.timer:SetHidden(true)
    for row=1,2 do
        local category=row==1 and HOTBAR_CATEGORY_PRIMARY or HOTBAR_CATEGORY_BACKUP
        -- A locked single-bar build can be wearing its weapons on the backup pair.
        -- Show that usable bar first; the other row remains a dim reference.
        if weapon and locked then
            category=row==1 and active or (active==HOTBAR_CATEGORY_PRIMARY and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY)
        end
        local isActive=category==active
        for index=1,6 do
            local ultimate=index==6
            local slot=ultimate and ACTION_BAR_ULTIMATE_SLOT_INDEX+1 or ACTION_BAR_FIRST_NORMAL_SLOT_INDEX+index
            -- Four equipment cells form a cross before both fixed five-skill rows.
            local c=Cell(row..':'..index,ultimate and 74 or 230+(index-1)*51,
                (row-1)*70+(ultimate and 0 or 35),ultimate and 64 or 46)
            c:SetHidden(not weapon and row==2)
            if not weapon then isActive=row==1 end
            local targetCategory=isActive and active or category
            c:SetAlpha(isActive and 1 or .42)
            local icon=GetSlotTexture(slot,targetCategory)
            local ringCell=weapon and row==2 and ultimate and locked and oakensoul
            if ringCell then icon=texture c:SetAlpha(.7) end
            c.icon:SetTexture(icon or '') c.icon:SetHidden((isActive and not ringCell) or not icon or icon=='')
            SetKey(c,isActive and ultimate and not ringCell and Binding('ACTION_BUTTON_8','R') or '')
            c.nativeTimer=nil
            if isActive and not ringCell then
                local button=ZO_ActionBar_GetButton(slot)
                PlaceNative(button,c,ultimate and 56 or 38,ultimate)
            else
                local button=ZO_ActionBar_GetButton(slot,category)
                if button and button.slot then button.slot:SetAlpha(0) c.nativeTimer=button end
            end
            c.timer:SetHidden(true)
        end
    end
    local potion=Cell('potion',148,35,64)
    potion.icon:SetHidden(true) SetKey(potion,Binding('ACTION_BUTTON_9','Q')) potion.timer:SetHidden(true)
    local button=ZO_ActionBar_GetButton(1,HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    PlaceNative(button,potion,56,true)
    AlabuzyaUI.Companion.ApplyPolicy()
    if D.AfterLayout then D.AfterLayout() end
end
function D.SetCombatValues(dps,share)
    pendingDamage=dps pendingShare=share
    if damageLabel then
        damageLabel:SetText(string.format('%.0f',dps))
        shareLabel:SetText(share and string.format('~%.1f%%',share) or '--')
    end
end
function D.ImportantMessage(channel,from,text,display)
    if from==GetUnitName('player') or display==GetDisplayName() then return false end
    return channel==CHAT_CHANNEL_WHISPER or channel==CHAT_CHANNEL_PARTY
        or channel==CHAT_CHANNEL_GUILD_1 or channel==CHAT_CHANNEL_GUILD_2
        or channel==CHAT_CHANNEL_GUILD_3 or channel==CHAT_CHANNEL_GUILD_4 or channel==CHAT_CHANNEL_GUILD_5
        or channel==CHAT_CHANNEL_OFFICER_1 or channel==CHAT_CHANNEL_OFFICER_2
        or channel==CHAT_CHANNEL_OFFICER_3 or channel==CHAT_CHANNEL_OFFICER_4 or channel==CHAT_CHANNEL_OFFICER_5
        or channel==CHAT_CHANNEL_SYSTEM
        or (text and string.find(string.lower(text),string.lower(GetDisplayName()),1,true)~=nil)
end
function D.UpdateChat()
    local system=CHAT_SYSTEM
    local container=system and system.primaryContainer
    local control=container and container.control
    if not control then return end
    if not chatReady then
        chatReady=true
        -- Native minimize/maximize remains the source of truth and saves its own geometry.
        if not system:IsTextEntryOpen() then system:Minimize() end
    end
    local input=system:IsTextEntryOpen()
    if input and system:IsMinimized() then system:Maximize() end
    local minimized=system:IsMinimized()
    if not minimized and not input and not container.isMinimizingOrMaximizing and control:GetAlpha()<=(container.minAlpha or 0)+.015 and not MouseIsOver(control) and (container.fadeInReferences or 0)==0 then
        system:Minimize() minimized=true
    end
    if not minimized then unread=false end
    chatIcon:SetHidden(not minimized)
    chatIcon:SetAlpha(unread and (.55+.45*math.abs(math.sin(GetFrameTimeSeconds()*4))) or 1)
    local minBar=system.minBar or ZO_ChatWindowMinBar
    if minBar then minBar:SetHidden(true) end
    local right=control:GetLeft()+control:GetWidth()
    -- Reserve the helper column even before its late initialization, then follow
    -- the real visible panel's edge. Native maximize animation must not shrink this reserve.
    right=math.max(right,container.originalPosition or right)
    if AlabuzyaUI.Settings.Enabled('assistantPanel') and control:GetLeft()<50 then right=right+46 end
    local helpers=AlabuzyaUI.AssistantPanel
    local edge=helpers and helpers.RightEdge and helpers.RightEdge()
    if edge then right=math.max(right,edge) end
    local target=minimized and 16 or math.max(16,right+CHAT_GAP)
    target=math.min(target,math.max(16,GuiRoot:GetWidth()-BAR_WIDTH-16))
    slide=math.abs(target-slide)<.5 and target or slide+(target-slide)*.28
    root:ClearAnchors() root:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT,slide,-40)
end
function D.Update()
    for _,r in ipairs(resources) do
        local value,maximum=GetUnitPower('player',r.power)
        r.bar:SetMinMax(0,math.max(1,maximum)) r.bar:SetValue(value)
        local suffix=''
        if r.power==POWERTYPE_HEALTH and POWERTYPE_DAMAGE_SHIELD then
            local shield=GetUnitPower('player',POWERTYPE_DAMAGE_SHIELD)
            if shield>0 then suffix=' |c88CCFF+'..tostring(math.floor(shield))..'|r' end
        end
        r.label:SetText(string.format('%d / %d',value,maximum)..suffix)
    end
    for _,c in pairs(cells) do
        local timer=c.nativeTimer
        local remaining=timer and timer.endTimeMS and timer.endTimeMS-GetFrameTimeMilliseconds() or 0
        local visible=timer and timer.showBackRowSlot and remaining>0 and timer.durationMS and timer.durationMS>0
        c.timer:SetHidden(not visible)
        if visible then c.timer:SetValue(math.min(1,remaining/timer.durationMS)) end
    end
    D.UpdateChat()
end
function D.ShortBuffAnchor(control)
    if not root then return end
    control:ClearAnchors() control:SetAnchor(BOTTOM,root,TOP,355,-8)
end
function D.InitializeHUD()
    root=WM:CreateTopLevelWindow('AlabuzyaUIDS3ActionBars')
    root:SetDimensions(BAR_WIDTH,BAR_HEIGHT) root:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT,16,-40)
    root:SetMouseEnabled(false) HUD(root)
    player=Window('DS3PlayerPosition',510,112,22,28)
    local ember=Texture(player,'AlabuzyaUI/Textures/DS3Ember.dds')
    ember:SetDimensions(84,84) ember:SetAnchor(TOPLEFT,player,TOPLEFT,0,0)
    for i,power in ipairs({POWERTYPE_HEALTH,POWERTYPE_MAGICKA,POWERTYPE_STAMINA}) do
        local c=WM:CreateControl(nil,player,CT_CONTROL)
        c:SetDimensions(310,16) c:SetAnchor(TOPLEFT,player,TOPLEFT,88,12+(i-1)*22)
        T.Backdrop(c)
        local rim=Texture(c,'AlabuzyaUI/Textures/DS3ResourceV2.dds')
        rim:SetAnchorFill() rim:SetDrawLevel(20)
        local bar=WM:CreateControl(nil,c,CT_STATUSBAR)
        bar:SetAnchor(TOPLEFT,c,TOPLEFT,3,3) bar:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-3,-3)
        local colors={{.65,.09,.07},{.10,.28,.48},{.18,.38,.22}}
        bar:SetColor(unpack(colors[i]))
        local label=Label(player,14) label:SetAnchor(TOPLEFT,c,TOPRIGHT,8,-3)
        resources[i]={bar=bar,label=label,power=power}
    end
    local sword=Texture(player,ZO_GetRoleIcon(LFG_ROLE_DPS))
    sword:SetDimensions(20,20) sword:SetAnchor(TOPLEFT,player,TOPLEFT,90,82)
    damageLabel=Label(player,16) damageLabel:SetAnchor(TOPLEFT,player,TOPLEFT,116,82)
    local percent=Label(player,18) percent:SetText('%') percent:SetAnchor(TOPLEFT,player,TOPLEFT,218,80)
    shareLabel=Label(player,16) shareLabel:SetAnchor(TOPLEFT,player,TOPLEFT,244,82)
    D.SetCombatValues(pendingDamage,pendingShare)
    chatIcon=WM:CreateTopLevelWindow('AlabuzyaUIDS3ChatIcon')
    chatIcon:SetDimensions(76,28) chatIcon:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT,22,-8)
    chatIcon:SetMouseEnabled(true) HUD(chatIcon)
    local icon=Texture(chatIcon,'AlabuzyaUI/Textures/DS3Chat.dds')
    icon:SetDimensions(22,22) icon:SetAnchor(LEFT,chatIcon,LEFT,0,0)
    local label=Label(chatIcon,16) label:SetText(GetCVar('language.2')=='ru' and 'Чат' or 'Chat')
    label:SetAnchor(LEFT,chatIcon,LEFT,27,0)
    chatIcon:SetHandler('OnMouseUp',function(_,button,inside)
        if button==MOUSE_BUTTON_INDEX_LEFT and inside and CHAT_SYSTEM then
            unread=false CHAT_SYSTEM:Maximize()
            if CHAT_SYSTEM.primaryContainer then CHAT_SYSTEM.primaryContainer:FadeIn(0) end
        end
    end)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIDS3Chat',EVENT_CHAT_MESSAGE_CHANNEL,function(_,channel,from,text,_,display)
        if CHAT_SYSTEM and CHAT_SYSTEM:IsMinimized() and D.ImportantMessage(channel,from,text,display) then unread=true end
    end)
    local pending=false
    local function Schedule()
        if pending then return end pending=true
        zo_callLater(function() pending=false D.LayoutBar() end,0)
    end
    for _,event in ipairs({EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,
        EVENT_HOTBAR_SLOT_UPDATED,EVENT_ACTIVE_WEAPON_PAIR_CHANGED,EVENT_PLAYER_ACTIVATED,EVENT_INVENTORY_SINGLE_SLOT_UPDATE}) do
        EVENT_MANAGER:RegisterForEvent('AlabuzyaUIDS3Bar',event,Schedule)
    end
    for i=1,7 do
        local button=i==1 and ZO_ActionBar_GetButton(1,HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or ZO_ActionBar_GetButton(i+1)
        if button and ZO_PostHook then
            if button.ApplyStyle then ZO_PostHook(button,'ApplyStyle',Schedule) end
            if button.ApplyAnchor then ZO_PostHook(button,'ApplyAnchor',Schedule) end
        end
    end
    D.LayoutBar() D.Update()
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIDS3HUD',33,D.Update)
end
