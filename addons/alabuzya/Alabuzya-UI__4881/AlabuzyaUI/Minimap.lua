local AlabuzyaUI = AlabuzyaUI
AlabuzyaUI.Minimap = {}
-- Original AlabuzyaUI minimap. Uses ESO map tiles; no third-party addon dependency.
local root,view,title,clock,settings,player
local tiles,pins={},{}
local points={}
local key,nextPoints='',0
local SIZE=326
local nextClock=0
local mapDirty=true
local wasBrowsing=false

local function MapKey()
    local floor=GetMapFloorInfo and GetMapFloorInfo() or 0
    return tostring(GetCurrentMapId())..':'..tostring(floor)..':'..tostring(GetMapTileTexture(1))
end

function AlabuzyaUI.Minimap.GetZoom()
    -- Keep scale constant while walking, mounting and teleporting. In particular,
    -- dungeon maps must not inherit the 12x zoom formerly used for all zone maps.
    local dungeon=GetMapContentType and GetMapContentType()==MAP_CONTENT_DUNGEON
    local base=dungeon and 1.35 or (GetMapType()==MAPTYPE_ZONE and 8 or 2.2)
    local limit=GetMapCustomMaxZoom and GetMapCustomMaxZoom()
    if limit and limit>0 then base=math.min(base,limit) end
    return math.max(1,math.min(dungeon and 3 or 16,base*settings.zoomBias))
end

local function RefreshMapPins()
    -- Refresh even when SetMapToPlayerLocation reports no change: on login or
    -- after another addon selects a map, the hidden map's pin pool can be empty.
    CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged')
    local manager=ZO_WorldMap_GetPinManager()
    if manager and manager.RefreshObjectives then manager:RefreshObjectives() end
    if ZO_WorldMap_RefreshWorldEvents then ZO_WorldMap_RefreshWorldEvents() end
    mapDirty=false
end
local function Label(parent,size)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
    AlabuzyaUI.Theme.Text(c,size) c:SetMouseEnabled(false)
    return c
end
local function Texture(parent)
    local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
    -- Match ESO's ZO_MapTile template. Rounding moving texture edges to whole
    -- pixels causes uneven steps and resampling ripples during fractional pans.
    -- Pins use the same subpixel coordinates as the map underneath them.
    c:SetPixelRoundingEnabled(false)
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
        if kind~=MAP_PIN_TYPE_PLAYER and kind~=MAP_PIN_TYPE_GROUP
            and kind~=MAP_PIN_TYPE_GROUP_LEADER and kind~=MAP_PIN_TYPE_LOCATION and texture
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
    -- Location pins (banks, crafting stations, doors, etc.) otherwise remain
    -- queued in the hidden world map's refresh group. Read this map directly,
    -- so an interior can never inherit the previous city's location pins.
    if GetNumMapLocations then
        for i=1,GetNumMapLocations() do
            if IsMapLocationVisible(i) then
                local texture,x,y=GetMapLocationIcon(i)
                if texture and texture~='' and x and y and x>=0 and x<=1 and y>=0 and y<=1 then
                    points[#points+1]={x=x,y=y,texture=texture,color={1,1,1,1},
                        coords={0,1,0,1},rotation=0,level=20,
                        caption=GetMapLocationTooltipHeader(i)}
                end
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
    if ZO_WorldMap_IsWorldMapShowing() then wasBrowsing=true return end
    if root:IsHidden() then return end
    if wasBrowsing then mapDirty=true wasBrowsing=false end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local result=SetMapToPlayerLocation()
        if result==SET_MAP_RESULT_MAP_CHANGED then mapDirty=true end
        if result==SET_MAP_RESULT_FAILED then return end
    end
    if not DoesCurrentMapMatchMapForPlayerLocation() then return end
    local columns,rows=GetMapNumTiles()
    if columns<1 or rows<1 then return end
    local x,y,heading,shown=GetMapPlayerPosition('player')
    if not shown then return end
    local context=MapKey()
    local changed=context~=key
    if changed or mapDirty then
        points={}
        for _,pin in ipairs(pins) do pin:SetHidden(true) end
        RefreshMapPins()
        -- Callbacks may change context. Never pair old coordinates with new pins.
        if MapKey()~=context or not DoesCurrentMapMatchMapForPlayerLocation() then
            mapDirty=true return
        end
        key=context nextPoints=0
    end
    if now>=nextPoints then CollectPoints() nextPoints=now+0.5 end
    if changed then title:SetText(zo_strformat('<<1>>',GetMapName())) end
    local zoom=AlabuzyaUI.Minimap.GetZoom()
    local width=SIZE*zoom local height=width*rows/columns
    -- Fixed player center, including map edges. No delayed position or heading.
    local left=x*width-SIZE/2
    local top=y*height-SIZE/2
    for i=1,columns*rows do
        local tile=tiles[i]
        if not tile then tile=Texture(view) tile:SetDrawLayer(DL_BACKGROUND) tiles[i]=tile end
        local filename=GetMapTileTexture(i)
        if tile.diaTexture~=filename then tile:SetTexture(filename) tile.diaTexture=filename end
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
    for _,point in ipairs(points) do Put(point.x,point.y,point.texture,point.caption,point.rotation,point) end
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
function AlabuzyaUI.Minimap.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.StyleEnabled() then return end
    settings=AlabuzyaUI.SavedVariables.Account('minimap',{zoomBias=1})
    local theme=AlabuzyaUI.Theme
    if theme.classic then SIZE=248 end
    local sidebar=theme.MapHost and theme.MapHost() or theme.Sidebar()
    root=WINDOW_MANAGER:CreateControl('AlabuzyaUIMinimap',sidebar,CT_CONTROL)
    root:SetDimensions(SIZE+16,SIZE+80)
    root:SetAnchor(TOPLEFT,sidebar,TOPLEFT,0,0)
    root:SetMouseEnabled(false)
    AlabuzyaUI.Theme.mapHeight=SIZE+80
    if not theme.classic then
    AlabuzyaUI.Theme.Separator(root,34)
    AlabuzyaUI.Theme.Separator(root,SIZE+39)
    AlabuzyaUI.Theme.Separator(root,SIZE+77)
    end
    title=Label(root,24) title:SetDimensions(SIZE,32) title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetAnchor(TOPLEFT,root,TOPLEFT,8,0)
    view=WINDOW_MANAGER:CreateControl(nil,root,CT_SCROLL)
    view:SetDimensions(SIZE,SIZE) view:SetAnchor(TOPLEFT,root,TOPLEFT,8,39)
    view:SetScrollBounding(SCROLL_BOUNDING_UNBOUND) view:SetMouseEnabled(true)
    local function Zoom(delta)
        settings.zoomBias=math.max(0.25,math.min(3,settings.zoomBias+delta*0.1)) Update()
    end
    view:SetHandler('OnMouseWheel',function(_,delta) Zoom(delta) end)
    player=Texture(view) player:SetDimensions(18,18)
    player:SetAnchor(CENTER,view,CENTER,0,0)
    player:SetTexture('EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds')
    player:SetDrawLayer(DL_OVERLAY) player:SetDrawLevel(10)
    clock=Label(root,24) clock:SetAnchor(TOPLEFT,root,TOPLEFT,12,SIZE+44)
    if theme.classic then AlabuzyaUI.ClassicTheme.SkinMap(root,view,title,clock,Zoom) end
    CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged',function() mapDirty=true end)
    EVENT_MANAGER:RegisterForEvent('AlabuzyaUIMinimap',EVENT_PLAYER_ACTIVATED,function() mapDirty=true end)
    root:SetHandler('OnUpdate',Update)
end
