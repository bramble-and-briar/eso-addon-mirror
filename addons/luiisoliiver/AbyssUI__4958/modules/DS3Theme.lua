local NagaMapUI = NagaMapUI
-- DS_3 presentation. Shared inventory, map, quest and combat modules own their data.
NagaMapUI.DS3Theme = {}
local D=NagaMapUI.DS3Theme
local T=NagaMapUI.Theme
local WM=WINDOW_MANAGER
local function Texture(parent,path)
    local c=WM:CreateControl(nil,parent,CT_TEXTURE)
    c:SetTexture(path) c:SetMouseEnabled(false)
    c:SetDrawLayer(DL_OVERLAY) return c
end
local function HUD(c)
    local f=ZO_HUDFadeSceneFragment:New(c)
    HUD_SCENE:AddFragment(f) HUD_UI_SCENE:AddFragment(f)
end
local function Window(key,w,h,x,y)
    local c=WM:CreateTopLevelWindow('NagaMapUI'..key)
    local saved=NagaMapUI.SavedVariables.Account(key,{})
    c:SetDimensions(w,h) c:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,saved.x or x,saved.y or y)
    c:SetClampedToScreen(true) c:SetMouseEnabled(true) c:SetMovable(true)
    c:SetHandler('OnMoveStop',function() saved.x=c:GetLeft() saved.y=c:GetTop() end)
    -- Transparent host: content (map ring / quest list) draws itself; no solid black fill.
    local bg=WM:CreateControl(nil,c,CT_BACKDROP)
    bg:SetAnchorFill() bg:SetCenterColor(0,0,0,0) bg:SetEdgeColor(0,0,0,0)
    bg:SetMouseEnabled(false) bg:SetDrawLayer(DL_BACKGROUND)
    HUD(c) return c
end
function D.Panel(parent,_,openBottom)
    if parent.nagamapuiFrame then return end
    parent.nagamapuiFrame=true
    -- A real nine-slice: transparent center, fixed corners, stretching edge strips.
    local uv={0,.12,.88,1}
    for y=1,3 do for x=1,3 do
        if (x~=2 or y~=2) and (not openBottom or y~=3) then
            local c=Texture(parent,'AbyssUI/assets/MiniMap/DS3Panel.dds')
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
    -- ClassicTheme skipped (not bundled)
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
    -- Ring art is 266px; map view must match the inner circle (~250).
    T.MapHost=function()
        if not D.map then
            D.map=Window('DS3MapPosition',280,340,GuiRoot:GetWidth()-300,12)
            D.map:SetMovable(true)
            D.map:SetMouseEnabled(true)
        end
        return D.map
    end
    T.QuestHost=function()
        if not D.quests then
            -- No DS3 panel DDS: plain movable host matching focused-quest look.
            -- Default near top-right; fully free to move anywhere after.
            local w, h = 280, 320
            local x = GuiRoot:GetWidth() - w - 4
            local y = 80
            D.quests=Window('DS3QuestPosition', w, h, x, y)
            D.quests:SetMovable(true)
            D.quests:SetMouseEnabled(true)
            D.quests:SetClampedToScreen(true)
        end
        return D.quests
    end
end
-- Inner map diameter that fits inside DS3Ring.dds (266 outer).
D.MAP_VIEW = 250
D.MAP_RING = 266
D.WHEEL_DIR = 'AbyssUI/assets/MiniMap/Wheelframes/'
-- Cada moldura: nome, arquivo e raio interno (px, em 256) onde o aro ja esta 50% opaco
-- (a sombra interna, mais fina, fica por cima do mapa em vez de deixar uma faixa vazia).
-- Usado para escalar a moldura de modo que o buraco dela fique do tamanho do mapa.
-- Only Daedric frame ships with AbyssUI (other Wheelframes removed).
D.WHEEL_FRAMES = {
    {name='Daedric', file='Daedric.dds', inner=195},
}
D.WHEEL_DEFAULT = 'Daedric'
-- Retorna arquivo, tamanho total da moldura e se ela deve girar junto com o mapa.
-- O tamanho e calculado para o ponto 50% opaco do aro cair na borda do mapa:
-- o mapa preenche todo o circulo e a moldura so cobre a borda translucida.
-- frameAdjust (D.wheelAdjust) still applied from SavedVariables for compatibility,
-- but the UI slider was removed so players cannot change it.
function D.WheelInfo(name)
    -- Always use Daedric; ignore legacy saved frame names
    name = D.WHEEL_DEFAULT
    for _, f in ipairs(D.WHEEL_FRAMES) do
        if f.name == name then
            local size = math.floor((D.MAP_VIEW - 4) * 256 / f.inner + 0.5) + (D.wheelAdjust or -40)
            return D.WHEEL_DIR .. f.file, size, true
        end
    end
    return D.WHEEL_DIR .. 'Daedric.dds', math.floor((D.MAP_VIEW - 4) * 256 / 195 + 0.5) + (D.wheelAdjust or -40), true
end
function D.WheelChoices()
    return { D.WHEEL_DEFAULT }
end
function D.LayoutMapLabels(map, view, title, clock, opts)
    opts = opts or {}
    local VIEW, RING = D.MAP_VIEW, D.MAP_RING
    local showZone = opts.showZone ~= false
    local showClock = opts.showClock ~= false
    local zonePos = opts.zonePosition == 'bottom' and 'bottom' or 'top'
    local clockPos = opts.clockPosition == 'top' and 'top' or 'bottom'
    local ring = D.mapRing
    -- O = quanto a moldura ultrapassa o mapa de cada lado (8px no DS3 original).
    local O = math.max(0, math.floor((RING - VIEW) / 2 + 0.5))
    local topPad, bottomPad = O, O

    -- Place the circular map first so anchors for labels resolve against the ring.
    view:ClearAnchors()
    view:SetAnchor(CENTER, map, TOP, 0, topPad + VIEW / 2)

    if title then
        title:SetHidden(not showZone)
        title:SetDimensions(RING, 24)
        title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        title:ClearAnchors()
        if showZone then
            local anchorTo = ring or view
            local gap = ring and 0 or 6
            if zonePos == 'top' then
                title:SetAnchor(BOTTOM, anchorTo, TOP, 0, -gap)
                topPad = O + 24
            else
                title:SetAnchor(TOP, anchorTo, BOTTOM, 0, gap)
                bottomPad = O + 24
            end
        end
    end
    if clock then
        local cx = tonumber(opts.clockOffsetX) or 0 -- desloca o relogio (+ direita)
        clock:SetHidden(not showClock)
        clock:SetDimensions(RING, 22)
        clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        clock:ClearAnchors()
        if showClock then
            local anchorTo = ring or view
            if clockPos == 'top' then
                if showZone and zonePos == 'top' then
                    clock:SetAnchor(BOTTOM, title, TOP, cx, -2)
                    topPad = O + 46
                else
                    clock:SetAnchor(BOTTOM, anchorTo, TOP, cx, -6)
                    topPad = math.max(topPad, O + 24)
                end
            else
                if showZone and zonePos == 'bottom' then
                    clock:SetAnchor(TOP, title, BOTTOM, cx, 2)
                    bottomPad = O + 46
                else
                    clock:SetAnchor(TOP, anchorTo, BOTTOM, cx, 6)
                    bottomPad = math.max(bottomPad, O + 24)
                end
            end
        end
    end
    -- Re-apply view position with final padding.
    view:ClearAnchors()
    view:SetAnchor(CENTER, map, TOP, 0, topPad + VIEW / 2)
    if ring then
        ring:ClearAnchors()
        ring:SetAnchor(CENTER, view, CENTER, 0, 0)
    end
    local h = RING + (topPad - O) + (bottomPad - O) + 16
    map:SetDimensions(RING + 14, h)
    local host = map:GetParent()
    if host and host.SetDimensions then
        host:SetDimensions(RING + 14, h)
    end
end
-- Troca a moldura do minimapa (arquivos da pasta Wheelframes) e refaz o layout.
function D.SetWheelFrame(name, map, view, title, clock, opts)
    local file, size, rotates = D.WheelInfo(name)
    D.MAP_RING = size
    D.wheelRotates = rotates
    if D.mapRing then
        D.mapRing:SetTexture(file)
        D.mapRing:SetDimensions(size, size)
        if not rotates then D.mapRing:SetTextureRotation(0, 0.5, 0.5) end
    end
    if map and view then D.LayoutMapLabels(map, view, title, clock, opts) end
end
function D.SkinMap(map, view, title, clock, zoom, opts)
    local VIEW = D.MAP_VIEW
    view:SetDimensions(VIEW, VIEW)
    view:SetMaskMode(CONTROL_MASK_MODE_BASIC)
    view:SetMaskTexture('AbyssUI/assets/MiniMap/ClassicCircleMask.dds')
    local file, RING, rotates = D.WheelInfo(opts and opts.wheelFrame or D.WHEEL_DEFAULT)
    D.MAP_RING = RING
    D.wheelRotates = rotates
    local ring = Texture(map, file)
    ring:SetDimensions(RING, RING)
    ring:SetAnchor(CENTER, view, CENTER, 0, 0)
    ring:SetDrawLevel(100)
    D.mapRing = ring
    if title then
        T.Text(title, 18)
        title:SetMouseEnabled(true)
        title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    if clock then
        T.Text(clock, 16)
        clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    D.LayoutMapLabels(map, view, title, clock, opts)
    view:SetMouseEnabled(true)
    view:SetHandler('OnMouseWheel', function(_, delta) zoom(delta) end)
    local function startDrag()
        local h = map:GetParent()
        if h and h.StartMoving then h:StartMoving() end
    end
    if title then
        title:SetHandler('OnMouseDown', function(_, btn)
            if btn == MOUSE_BUTTON_INDEX_LEFT then startDrag() end
        end)
    end
    local host = map:GetParent()
    if host then
        host:SetMouseEnabled(true)
        host:SetMovable(true)
        host:SetHandler('OnMouseDown', function(_, btn)
            if btn == MOUSE_BUTTON_INDEX_LEFT then startDrag() end
        end)
    end
end
