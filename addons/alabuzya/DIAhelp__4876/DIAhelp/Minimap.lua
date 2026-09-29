local DIAhelp = DIAhelp
DIAhelp.Minimap = {}
-- Original DIAhelp minimap. Uses ESO map tiles; no third-party addon dependency.
local root,view,title,clock,settings,player
local tiles,pins={},{}
local points={}
local key,nextPoints='',0
local SIZE=326
local lastX,lastY,lastTime,movingUntil,currentZoom
local nextClock,nextMotionSample
nextMotionSample=0
nextClock=0
movingUntil=0
local function Label(parent,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    c:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick') c:SetMouseEnabled(false)
    return c
end
local function Texture(parent)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    c:SetMouseEnabled(false) return c
end
local function Time(seconds)
    return string.format('%02d:%02d',math.floor(seconds/3600)%24,math.floor(seconds/60)%60)
end
local function CollectPoints()
    points={}
    local manager=ZO_WorldMap_GetPinManager()
    if not manager or not manager.GetActiveObjects then return end
    manager:UpdateMovingPins()
    for _,native in pairs(manager:GetActiveObjects()) do
        local kind=native:GetPinType()
        local control=native:GetControl()
        local texture=native.backgroundControl
        -- Parent map is hidden on HUD: test local visibility, not IsHidden().
        if kind~=MAP_PIN_TYPE_PLAYER and kind~=MAP_PIN_TYPE_GROUP and texture
            and not control:IsControlHidden() and not texture:IsControlHidden() then
            local x,y=native:GetNormalizedPosition()
            local filename=texture:GetTextureFileName()
            if x and y and x>=0 and x<=1 and y>=0 and y<=1 and filename and filename~='' then
                points[#points+1]={x=x,y=y,texture=filename,
                    color={texture:GetColor()},coords={texture:GetTextureCoords()},
                    rotation=0,level=texture:GetDrawLevel()}
            end
        end
    end
    table.sort(points,function(a,b) return a.level<b.level end)
end
local function Pin(index,x,y,texture,name,rotation,style)
    local pin=pins[index]
    if not pin then
        pin=Texture(view) pin:SetDimensions(22,22) pin:SetDrawLayer(DL_OVERLAY)
        pin:SetMouseEnabled(true)
        pin:SetHandler('OnMouseEnter',function(self)
            if self.caption then ZO_Tooltips_ShowTextTooltip(self,TOPLEFT,self.caption) end
        end)
        pin:SetHandler('OnMouseExit',function() ZO_Tooltips_HideTextTooltip() end)
        pins[index]=pin
    end
    pin.caption=name
    if pin.diaTexture~=texture then pin:SetTexture(texture) pin.diaTexture=texture end
    pin:SetTextureRotation(rotation or 0)
    if style then
        pin:SetColor(unpack(style.color)) pin:SetTextureCoords(unpack(style.coords))
    else
        pin:SetColor(1,1,1,1) pin:SetTextureCoords(0,1,0,1)
    end
    pin:SetDrawLevel(index)
    pin:ClearAnchors() pin:SetAnchor(CENTER,view,TOPLEFT,x,y)
    pin:SetHidden(false)
end
local function Update()
    local now=GetFrameTimeSeconds()
    if now>=nextClock then
        clock:SetText(Time(GetSecondsSinceMidnight())..'  |cBBB6A0'..Time((GetTimeStamp()%20955)*86400/20955)..'|r')
        nextClock=now+1
    end
    -- Only change global map context on HUD; never interrupt world-map browsing.
    if root:IsHidden() or ZO_WorldMap_IsWorldMapShowing() then return end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local result=SetMapToPlayerLocation()
        if result==SET_MAP_RESULT_MAP_CHANGED then CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged') end
        if result==SET_MAP_RESULT_FAILED then return end
    end
    if not DoesCurrentMapMatchMapForPlayerLocation() then return end
    local columns,rows=GetMapNumTiles()
    if columns<1 or rows<1 then return end
    local x,y,heading,shown=GetMapPlayerPosition('player')
    if not shown then return end
    local context=tostring(GetCurrentMapId())..':'..tostring(GetMapTileTexture(1))
    local changed=context~=key
    if changed then key=context nextPoints=0 lastX=nil lastTime=nil currentZoom=nil movingUntil=0 nextMotionSample=0 end
    if now>=nextPoints then CollectPoints() nextPoints=now+0.5 end
    if changed then title:SetText(zo_strformat('<<1>>',GetMapName())) end
    -- Sample displacement over a fixed interval, not per render frame.
    -- High frame rates previously made walking look like intermittent stops.
    if now>=nextMotionSample then
        if lastX and ((x-lastX)^2+(y-lastY)^2)>0.0000000001 then movingUntil=now+2 end
        lastX,lastY=x,y
        nextMotionSample=now+0.25
    end
    local moving=now<movingUntil
    local zoneMap=GetMapType()==MAPTYPE_ZONE
    local base=zoneMap and 20 or 3
    local target=base*(IsMounted() and 0.55 or moving and 0.85 or 1.15)*settings.zoomBias
    target=math.max(1,math.min(48,target))
    local dt=lastTime and math.max(0,math.min(0.5,now-lastTime)) or 0
    currentZoom=currentZoom and currentZoom+(target-currentZoom)*(1-math.exp(-dt*3)) or target
    if math.abs(target-currentZoom)<0.002 then currentZoom=target end
    lastTime=now
    local zoom=currentZoom
    local width=SIZE*zoom local height=width*rows/columns
    -- Fixed player center, including map edges. No delayed position or heading.
    local left=x*width-SIZE/2
    local top=y*height-SIZE/2
    for i=1,columns*rows do
        local tile=tiles[i]
        if not tile then tile=Texture(view) tile:SetDrawLayer(DL_BACKGROUND) tiles[i]=tile end
        if changed then tile:SetTexture(GetMapTileTexture(i)) end
        tile:SetDimensions(width/columns,height/rows)
        tile:ClearAnchors()
        tile:SetAnchor(TOPLEFT,view,TOPLEFT,((i-1)%columns)*width/columns-left,math.floor((i-1)/columns)*height/rows-top)
        tile:SetHidden(false)
    end
    for i=columns*rows+1,#tiles do tiles[i]:SetHidden(true) end
    local count=0
    local function Put(px,py,texture,name,rotation,style)
        local sx,sy=px*width-left,py*height-top
        if sx>=0 and sx<=SIZE and sy>=0 and sy<=SIZE then
            count=count+1 Pin(count,sx,sy,texture,name,rotation,style)
        end
    end
    for _,point in ipairs(points) do Put(point.x,point.y,point.texture,nil,point.rotation,point) end
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and not AreUnitsEqual(tag,'player') then
            local gx,gy,gh,visible=GetMapPlayerPosition(tag)
            if visible then Put(gx,gy,'EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds',GetUnitName(tag),gh) end
        end
    end
    for i=count+1,#pins do pins[i]:SetHidden(true) end
    -- Player anchor is fixed at initialization; only heading changes here.
    player:SetDrawLevel(count+1) player:SetTextureRotation(heading) player:SetHidden(false)
end
function DIAhelp.Minimap.Initialize()
    settings=DIAhelp.SavedVariables.Account('minimap',{zoomBias=1})
    root=WINDOW_MANAGER:CreateTopLevelWindow('DIAhelpMinimap')
    root:SetDimensions(SIZE+8,SIZE+64)
    root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,settings.x or GuiRoot:GetWidth()-SIZE-16,settings.y or 0)
    root:SetMouseEnabled(true) root:SetMovable(true) root:SetClampedToScreen(true)
    root:SetHandler('OnMoveStop',function() settings.x=root:GetLeft() settings.y=root:GetTop() end)
    local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_BACKDROP)
    bg:SetAnchorFill() bg:SetCenterColor(0,0,0,0.7) bg:SetEdgeColor(0.3,0.28,0.2,0.8)
    bg:SetEdgeTexture(nil,1,1,1) bg:SetMouseEnabled(false)
    title=Label(root,18) title:SetDimensions(SIZE,24) title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT,root,TOPLEFT,4,0)
    view=WINDOW_MANAGER:CreateControl(nil,root,CT_SCROLL)
    view:SetDimensions(SIZE,SIZE) view:SetAnchor(TOPLEFT,root,TOPLEFT,4,26)
    view:SetScrollBounding(SCROLL_BOUNDING_UNBOUND) view:SetMouseEnabled(true)
    view:SetHandler('OnMouseWheel',function(_,delta)
        settings.zoomBias=math.max(0.25,math.min(3,settings.zoomBias+delta*0.1)) Update()
    end)
    player=Texture(view) player:SetDimensions(18,18)
    player:SetAnchor(CENTER,view,CENTER,0,0)
    player:SetTexture('EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds')
    player:SetDrawLayer(DL_OVERLAY) player:SetDrawLevel(10)
    clock=Label(root,24) clock:SetAnchor(TOPLEFT,root,TOPLEFT,8,SIZE+29)
    local fragment=ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    root:SetHandler('OnUpdate',Update)
end
