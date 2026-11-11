-- Group Bearings: everything drawn on the compass.
--
-- The game draws its own pins on the compass: symbols (target markers), group
-- members and the crown. We add distance text under them and never change or
-- hide them. We draw icons of our own only where the game has none: preview
-- members and symbols, symbols while the game's compass markers setting is off,
-- and the crown kept on top (Keep the crown when overlapping, Crown always on
-- top), drawn one tier above the game's pins so no compass marker can cover it.

local GB = GroupBearings
local Core = GB.Core
local Compass = {}
GB.Compass = Compass

local MEMBER_TEXTURE = "EsoUI/Art/Compass/groupMember.dds"
local LEADER_TEXTURE = "EsoUI/Art/Compass/groupLeader.dds"

local STYLES = {
    gamepad = {
        markerFont = "ZoFontGamepadBold27", markerFontSize = 27,
        groupFont = "ZoFontGamepadBold22", groupFontSize = 22,
        labelY = 26, iconPx = 32, symbolPx = 36,
    },
    keyboard = {
        markerFont = "ZoFontGamepadBold22", markerFontSize = 22,
        groupFont = "ZoFontGamepadBold18", groupFontSize = 18,
        labelY = 8, iconPx = 28, symbolPx = 32,
    },
}
Compass.STYLES = STYLES

-- Draw levels inside our layer: member icons under the crown under text.
local LEVEL_MEMBER, LEVEL_CROWN, LEVEL_SYMBOL, LEVEL_TEXT = 2, 3, 4, 5

local root, container
local style = STYLES.gamepad
local nativeMarkersShown = true
local pools = {}

---------------------------------------------------------------------------
-- Control pools
---------------------------------------------------------------------------
local function NewPool(factory)
    local pool = { factory = factory, items = {}, used = 0, shown = 0 }
    pools[#pools + 1] = pool
    return pool
end

local function Next(pool)
    pool.used = pool.used + 1
    local c = pool.items[pool.used]
    if not c then
        c = pool.factory()
        pool.items[pool.used] = c
    end
    return c
end

local function Show(c)
    if not c.gbShown then
        c:SetHidden(false)
        c.gbShown = true
    end
end

local function Hide(c)
    if c.gbShown ~= false then
        c:SetHidden(true)
        c.gbShown = false
    end
end

local function BeginFrame()
    for _, pool in ipairs(pools) do pool.used = 0 end
end

local function EndFrame()
    for _, pool in ipairs(pools) do
        for i = pool.used + 1, pool.shown do Hide(pool.items[i]) end
        pool.shown = pool.used
    end
end

local function Layer(c, level)
    c:SetDrawTier(DT_LOW)
    c:SetDrawLayer(DL_OVERLAY)
    c:SetDrawLevel(level)
    c:SetMouseEnabled(false)
    c:SetHidden(true)
    c.gbShown = false
    return c
end

local function MakeLabel(fontKey)
    return function()
        local label = Layer(WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL), LEVEL_TEXT)
        label.gbFontKey = fontKey
        label:SetFont(style[fontKey])
        label:SetColor(1, 1, 1, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        return label
    end
end

local function MakeTexture(level, setup)
    return function()
        local tex = Layer(WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE), level)
        setup(tex)
        return tex
    end
end

local markerLabels = NewPool(MakeLabel("markerFont"))
local groupLabels = NewPool(MakeLabel("groupFont"))
local memberPins = NewPool(MakeTexture(LEVEL_MEMBER, function(tex) tex:SetTexture(MEMBER_TEXTURE) end))
local crownPins = NewPool(MakeTexture(LEVEL_CROWN, function(tex) tex:SetTexture(LEADER_TEXTURE) end))
local symbols = NewPool(MakeTexture(LEVEL_SYMBOL, function() end))

---------------------------------------------------------------------------
-- Placement
---------------------------------------------------------------------------
local function PlaceLabel(pool, x, text)
    local label = Next(pool)
    if label.gbText ~= text then
        label:SetText(text)
        label.gbText = text
    end
    local y = style.labelY + (GB.sv.labelOffset or 0)
    if label.gbX ~= x or label.gbY ~= y then
        label:ClearAnchors()
        label:SetAnchor(TOP, root, BOTTOM, x, y)
        label.gbX, label.gbY = x, y
    end
    Show(label)
end

local function PlacePin(pool, x, size, halfWidth)
    local tex = Next(pool)
    -- Shrink toward the edges like the game's own pins do.
    local edge = halfWidth > 0 and math.min(1, math.abs(x) / halfWidth) or 0
    local px = math.floor(size * (1 - 0.25 * edge) + 0.5)
    if tex.gbSize ~= px then
        tex:SetDimensions(px, px)
        tex.gbSize = px
    end
    if tex.gbX ~= x then
        tex:ClearAnchors()
        tex:SetAnchor(CENTER, root, CENTER, x, 0)
        tex.gbX = x
    end
    Show(tex)
    return tex
end

---------------------------------------------------------------------------
-- Symbols the game reports at the centre of the compass. This covers anything
-- you mark (enemies, NPCs, players outside your group) while you face it; the
-- game does not share those positions with add-ons any other way.
---------------------------------------------------------------------------
local function AddCenterOveredMarkers(entries, n, seen)
    if not (container and container.GetNumCenterOveredPins) then return n end
    if COMPASS_FRAME and COMPASS_FRAME.GetBossBarActive and COMPASS_FRAME:GetBossBarActive() then return n end
    for i = 1, container:GetNumCenterOveredPins() do
        local markerType = GB.markerByPinType[container:GetCenterOveredPinType(i)]
        if markerType and not seen[markerType] and not container:IsCenterOveredPinSuppressed(i) then
            local cm = container:GetCenterOveredPinDistance(i)
            if cm and cm > 0 then
                seen[markerType] = true
                n = n + 1
                local e = GB.NewEntry(entries, n)
                e.order = 200 + i
                e.markerType = markerType
                e.dist = cm / 100
                e.angle = 0
                e.text = Core.FormatDistance(e.dist)
                e.drawIcon = false
                e.isCrown = false
            end
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function Compass.Initialize()
    local parent = ZO_Compass or (COMPASS and COMPASS.control)
    container = (COMPASS and COMPASS.container) or ZO_CompassContainer
    if not (parent and container) then
        error("game compass not found")
    end
    root = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    root:SetAnchorFill(parent)
    root:SetMouseEnabled(false)
    Compass.root = root
end

function Compass.IsReady()
    return root ~= nil
end

function Compass.ApplySettings()
    if not root then return end
    local sv = GB.sv
    local newStyle = (IsInGamepadPreferredMode and IsInGamepadPreferredMode() == false) and STYLES.keyboard or STYLES.gamepad
    if newStyle ~= style then
        style = newStyle
        for _, pool in ipairs({ markerLabels, groupLabels }) do
            for _, label in ipairs(pool.items) do
                label:SetFont(style[label.gbFontKey])
                label.gbX = nil
            end
        end
        for _, pool in ipairs({ memberPins, crownPins, symbols }) do
            for _, tex in ipairs(pool.items) do tex.gbSize = nil end
        end
    end
    if GetSetting_Bool and SETTING_TYPE_UI and UI_SETTING_COMPASS_TARGET_MARKERS then
        local ok, shown = pcall(GetSetting_Bool, SETTING_TYPE_UI, UI_SETTING_COMPASS_TARGET_MARKERS)
        nativeMarkersShown = not ok or shown ~= false
    end
end

function Compass.HideAll()
    for _, pool in ipairs(pools) do
        for _, c in ipairs(pool.items) do Hide(c) end
        pool.used, pool.shown = 0, 0
    end
end

-- Our crown, in the game's own look. The game draws all its compass pins in one
-- control at tier MEDIUM, closer pins over farther ones, so any closer marker
-- covers its crown. Kept on top, ours draws at HIGH, above every one of them.
local function PlaceCrown(x, onTop, halfWidth)
    local tex = PlacePin(crownPins, x, style.iconPx, halfWidth)
    local tier = onTop and DT_HIGH or DT_LOW
    if tex.gbTier ~= tier then
        tex:SetDrawTier(tier)
        tex.gbTier = tier
    end
    return tex
end

local layoutOptions = {
    gapPx = 6,
    markerWidth = function(text) return Core.EstimateLabelWidth(text, style.markerFontSize) end,
    groupWidth = function(text) return Core.EstimateLabelWidth(text, style.groupFontSize) end,
}

function Compass.Render(markers, nMarkers, members, nMembers, seen)
    if not root then return end
    local sv = GB.sv
    local width = root:GetWidth()
    if not width or width <= 0 then
        Compass.HideAll()
        return
    end
    local halfWidth = width / 2
    local showDistances = sv.markerDistances
    local memberDistances = sv.groupDistances

    if showDistances then
        nMarkers = AddCenterOveredMarkers(markers, nMarkers, seen)
    end

    local fov = math.rad(sv.compassFov or Core.DEFAULT_FOV_DEGREES)
    for i = 1, nMarkers do
        local e = markers[i]
        e.x = Core.CompassX(e.angle, fov, width, true)
    end
    local crownTracked, crownKept = GB.IsCrownTracked(), GB.IsCrownKeptOnTop()
    for i = 1, nMembers do
        local e = members[i]
        local shown = memberDistances or e.drawIcon or (e.isLeader and (crownTracked or crownKept))
        e.x = shown and Core.CompassX(e.angle, fov, width, false) or nil
    end

    layoutOptions.iconPx = style.iconPx
    layoutOptions.markerLabels = showDistances
    layoutOptions.groupLabels = memberDistances
    layoutOptions.crownSymbol = sv.crownAsSymbol
    layoutOptions.keepCrown = sv.keepCrown
    layoutOptions.crownOnTop = sv.crownOnTop
    Core.LayoutCompass(markers, nMarkers, members, nMembers, layoutOptions)

    BeginFrame()
    for i = 1, nMarkers do
        local e = markers[i]
        if e.drawIcon or (showDistances and not nativeMarkersShown) then
            local markerStyle = GB.markers[e.markerType]
            if markerStyle then
                local tex = PlacePin(symbols, e.x, style.symbolPx, halfWidth)
                if tex.gbTexture ~= markerStyle.compassTexture then
                    tex:SetTexture(markerStyle.compassTexture)
                    tex.gbTexture = markerStyle.compassTexture
                end
            end
        end
        -- A symbol on the leader is a marker like any other: a kept crown goes
        -- over it too. Only inside the compass arc (the game's crown pin is not
        -- pinned to the edge the way symbol pins are).
        if e.leaderSymbol and crownKept and Core.CompassX(e.angle, fov, width, false) then
            PlaceCrown(e.x, true, halfWidth)
        end
        if e.labelShown then
            PlaceLabel(markerLabels, e.x, e.text)
        end
    end
    -- Real members are drawn by the game; we only add their distance. Icons of
    -- ours: preview members (the game has no pin for them) and a kept crown.
    for i = 1, nMembers do
        local e = members[i]
        if e.mode == "icon" and e.drawIcon then
            PlacePin(memberPins, e.x, style.iconPx, halfWidth)
        elseif e.mode == "crown" and (e.drawIcon or e.onTop) then
            PlaceCrown(e.x, e.onTop, halfWidth)
        end
        if e.labelShown then
            PlaceLabel(groupLabels, e.x, e.text)
        end
    end
    EndFrame()
end
