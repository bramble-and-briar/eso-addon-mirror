local AlabuzyaUI = AlabuzyaUI
-- Independent, click-through presentation of the shared current-map snapshot.
AlabuzyaUI.OverlayMap = {}
local M=AlabuzyaUI.OverlayMap
local root,viewport,fragment,db
local tiles,pins,regions={},{},{}
local requested=false
local lastUpdate='not started'
function M.Status()
    local scene=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene:GetName() or '?'
    local text=string.format('Alabuzya UI overlay [1.0.7]: ready=%s enabled=%s requested=%s hidden=%s scene=%s update=%s',
        tostring(db~=nil),tostring(db and db.enabled),tostring(requested),
        tostring(root and root:IsHidden()),name,lastUpdate)
    if d then d(text) end
    return text
end
function M.Refresh()
    if fragment then
        fragment:Refresh()
    end
end
function M.Toggle()
    if not db or not db.enabled then return end
    requested=not requested
    M.Refresh()
end
local function Update()
    if not requested or not db.enabled then lastUpdate='off' return end
    if root:IsHidden() then lastUpdate='window hidden' return end
    local map=AlabuzyaUI.Minimap.ReadFrame()
    if not map then
        lastUpdate='map unavailable'
        viewport:SetHidden(true)
        return
    end
    lastUpdate='drawing '..map.columns..'x'..map.rows
    viewport:SetHidden(false)
    local screenW,screenH=GuiRoot:GetDimensions()
    local extent=math.min(screenW*0.72,screenH*0.78)*db.scale
    root:SetDimensions(extent,extent)
    local width,height=extent,extent*map.rows/map.columns
    -- Show the complete local map; portrait maps fit vertically.
    if height>extent then width=width*extent/height height=extent end
    local left=(width-extent)/2
    local top=(height-extent)/2
    for i=1,map.columns*map.rows do
        local c=tiles[i]
        if not c then
            c=WINDOW_MANAGER:CreateControl(nil,viewport,CT_TEXTURE)
            c:SetMouseEnabled(false) c:SetPixelRoundingEnabled(false)
            c:SetDrawLayer(DL_BACKGROUND) c:SetDrawLevel(0)
            c:SetDesaturation(1)
            tiles[i]=c
        end
        local file=GetMapTileTexture(i)
        if c.mapTexture~=file then c:SetTexture(file) c.mapTexture=file end
        c:SetColor(0.85,0.87,0.90,db.opacity)
        c:SetDimensions(width/map.columns,height/map.rows)
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT,viewport,TOPLEFT,
            ((i-1)%map.columns)*width/map.columns-left,
            math.floor((i-1)/map.columns)*height/map.rows-top)
        c:SetHidden(false)
    end
    for i=map.columns*map.rows+1,#tiles do tiles[i]:SetHidden(true) end
    AlabuzyaUI.Minimap.DrawAreas(viewport,regions,map.areas,width,height,left,top)
    local used=0
    local function Marker(x,y,file,name,rotation,style)
        used=used+1
        AlabuzyaUI.Minimap.DrawPin(viewport,pins,used,x*width-left,y*height-top,
            file,name,rotation,style,false)
    end
    for _,point in ipairs(map.points) do
        Marker(point.x,point.y,point.texture,point.caption,point.rotation,point)
    end
    for i=1,GROUP_SIZE_MAX do
        local tag=GetGroupUnitTagByIndex(i)
        if tag and not AreUnitsEqual(tag,'player') then
            local x,y,heading,visible=GetMapPlayerPosition(tag)
            if visible then
                Marker(x,y,'EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds',GetUnitName(tag),heading)
            end
        end
    end
    Marker(map.x,map.y,'EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds',nil,map.heading)
    for i=used+1,#pins do pins[i]:SetHidden(true) end
end
function M.Initialize()
    db=AlabuzyaUI.Settings.Get().overlayMap
    local ru=GetCVar('language.2')=='ru'
    ZO_CreateStringId('SI_BINDING_NAME_ALABUZYAUI_OVERLAY_MAP',
        ru and 'Alabuzya UI: показать/скрыть оверлей карты' or 'Alabuzya UI: toggle map overlay')
    root=WINDOW_MANAGER:CreateTopLevelWindow('AlabuzyaUIOverlayMap')
    root:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    -- Give the hidden HUD fragment a drawable rectangle before its first show.
    -- A zero-sized control cannot bootstrap its layout through OnUpdate reliably.
    local screenW,screenH=GuiRoot:GetDimensions()
    local extent=math.min(screenW*0.72,screenH*0.78)*db.scale
    root:SetDimensions(extent,extent)
    root:SetHidden(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_MEDIUM)
    viewport=WINDOW_MANAGER:CreateControl(nil,root,CT_SCROLL)
    viewport:SetAnchorFill() viewport:SetMouseEnabled(false)
    viewport:SetScrollBounding(SCROLL_BOUNDING_UNBOUND)
    -- An overlay toggle needs immediate show/hide, not an animation timeline.
    fragment=ZO_SimpleSceneFragment:New(root)
    fragment:SetConditional(function() return requested and db.enabled end)
    HUD_SCENE:AddFragment(fragment) HUD_UI_SCENE:AddFragment(fragment)
    M.Refresh()
    -- Do not depend on control updates while the fragment is hidden/culled.
    EVENT_MANAGER:RegisterForUpdate('AlabuzyaUIOverlayMap',16,Update)
    SLASH_COMMANDS['/auimap']=function(argument)
        if argument~='status' then M.Toggle() end
        M.Status()
    end
end
