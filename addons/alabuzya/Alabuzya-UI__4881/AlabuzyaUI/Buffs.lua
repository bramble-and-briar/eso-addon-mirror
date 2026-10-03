local AlabuzyaUI = AlabuzyaUI
-- Original AlabuzyaUI player-effect panels. GPL-3.0-or-later.
AlabuzyaUI.Buffs={}
local M=AlabuzyaUI.Buffs
function M.IsLong(startTime,endTime,effectType)
    return effectType~=BUFF_EFFECT_TYPE_DEBUFF and (endTime<=startTime or endTime-startTime>=120)
end
function M.Timer(remaining)
    if remaining<=0 then return '' end
    if remaining>=3600 then return string.format('%dh%02d',math.floor(remaining/3600),math.floor(remaining/60)%60) end
    if remaining>=60 then return string.format('%d:%02d',math.floor(remaining/60),math.floor(remaining)%60) end
    return string.format('%.0f',math.ceil(remaining))
end
local longRoot,shortRoot,groupedLayout
local longIcons,shortIcons={},{}
local function Root(name,width,height,point,relative,x,y)
    local c=WINDOW_MANAGER:CreateTopLevelWindow(name)
    c:SetDimensions(width,height) c:SetAnchor(point,GuiRoot,relative,x,y)
    c:SetMouseEnabled(false)
    local fragment=ZO_HUDFadeSceneFragment:New(c)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    return c
end
local function Label(parent,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont(AlabuzyaUI.Theme.Font(size))
    c:SetDrawLayer(DL_OVERLAY) c:SetMouseEnabled(false) return c
end
local function Icon(pool,index,root,size)
    if pool[index] then return pool[index] end
    local c=WINDOW_MANAGER:CreateControl(nil,root,CT_CONTROL)
    c:SetDimensions(size,size) c:SetMouseEnabled(true)
    AlabuzyaUI.Theme.Panel(c,2)
    local bg=WINDOW_MANAGER:CreateControl(nil,c,CT_BACKDROP)
    bg:SetAnchorFill() bg:SetCenterColor(0,0,0,0.85) bg:SetEdgeTexture(nil,1,1,1)
    bg:SetMouseEnabled(false)
    local texture=WINDOW_MANAGER:CreateControl(nil,c,CT_TEXTURE)
    texture:SetAnchor(CENTER,c,CENTER,0,0) texture:SetDimensions(size-4,size-4)
    texture:SetMouseEnabled(false)
    local timer=Label(c,size==32 and 14 or 18) timer:SetAnchor(BOTTOM,c,BOTTOM,0,2)
    local stack=Label(c,14) stack:SetAnchor(TOPRIGHT,c,TOPRIGHT,-1,0)
    c:SetHandler('OnMouseEnter',function(self)
        ZO_Tooltips_ShowTextTooltip(self,TOPLEFT,self.caption or '')
    end)
    c:SetHandler('OnMouseExit',function() ZO_Tooltips_HideTextTooltip() end)
    local item={control=c,texture=texture,timer=timer,stack=stack,bg=bg}
    pool[index]=item return item
end
local function Draw(list,pool,root,long,now)
    local size=long and 32 or 40
    local perColumn=math.max(1,math.floor((GuiRoot:GetHeight()*0.45)/(size+5)))
    for i,effect in ipairs(list) do
        local item=Icon(pool,i,root,size) local c=item.control
        c:ClearAnchors()
        if long then
            c:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,-math.floor((i-1)/perColumn)*37,-((i-1)%perColumn)*37)
        else
            local count=math.min(10,#list-math.floor((i-1)/10)*10)
            c:SetAnchor(BOTTOM,root,BOTTOM,((i-1)%10-(count-1)/2)*45,-math.floor((i-1)/10)*45)
        end
        c.caption=effect.name item.texture:SetTexture(effect.icon)
        item.timer:SetText(effect.ending>effect.started and M.Timer(effect.ending-now) or '')
        item.stack:SetText(effect.stacks>1 and tostring(effect.stacks) or '')
        if effect.effectType==BUFF_EFFECT_TYPE_DEBUFF then item.bg:SetEdgeColor(0.8,0.15,0.12,1)
        else item.bg:SetEdgeColor(0.35,0.45,0.35,0.95) end
        c:SetHidden(false)
    end
    for i=#list+1,#pool do pool[i].control:SetHidden(true) end
end
local function Update()
    if AlabuzyaUI.Theme.ds3 then
        AlabuzyaUI.DS3Theme.ShortBuffAnchor(shortRoot)
    elseif AlabuzyaUI.Theme.classic then
        local grouped=AlabuzyaUI.ClassicTheme.IsGrouped()
        if groupedLayout~=grouped then
            groupedLayout=grouped
            shortRoot:ClearAnchors()
            shortRoot:SetAnchor(BOTTOM,GuiRoot,BOTTOM,0,grouped and -211 or -151)
        end
    end
    local now=GetFrameTimeSeconds() local longs,shorts={},{}
    local function Add(name,icon,started,ending,stacks,effectType,key)
        if not icon or icon=='' or (ending>started and ending<=now) then return end
        local list=M.IsLong(started,ending,effectType) and longs or shorts
        list[#list+1]={name=name,icon=icon,started=started,ending=ending,stacks=stacks or 0,effectType=effectType,key=key}
    end
    for i=1,GetNumBuffs('player') do
        local name,started,ending,slot,stacks,icon,_,effectType,_,_,id=GetUnitBuffInfo('player',i)
        Add(name,icon,started,ending,stacks,effectType,'b'..tostring(id)..':'..tostring(slot))
    end
    for id in ZO_GetNextActiveArtificialEffectIdIter do
        local name,icon,effectType,_,started,ending=GetArtificialEffectInfo(id)
        Add(name,icon,started,ending,0,effectType,'a'..id)
    end
    local function Sort(a,b) return a.key<b.key end
    table.sort(longs,Sort) table.sort(shorts,Sort)
    Draw(longs,longIcons,longRoot,true,now) Draw(shorts,shortIcons,shortRoot,false,now)
end
function AlabuzyaUI.Buffs.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.StyleEnabled() then return end
    longRoot=Root('AlabuzyaUILongBuffs',32,32,BOTTOMRIGHT,BOTTOMRIGHT,-5,-8)
    shortRoot=Root('AlabuzyaUIShortBuffs',450,40,BOTTOM,BOTTOM,0,-230)
    if AlabuzyaUI.Theme.ds3 then
        AlabuzyaUI.DS3Theme.ShortBuffAnchor(shortRoot)
    elseif AlabuzyaUI.Theme.classic then
        shortRoot:ClearAnchors() shortRoot:SetAnchor(BOTTOM,GuiRoot,BOTTOM,0,-151)
    end
    -- Replace only the player's native panel, preserving target effects.
    local native=BUFF_DEBUFF and BUFF_DEBUFF.containerObjectsByUnitTag['player']
    if native then
        native.control:SetHidden(true)
        ZO_PostHookHandler(native.control,'OnShow',function(c) c:SetHidden(true) end)
    end
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIBuffs',250,Update)
    Update()
end
