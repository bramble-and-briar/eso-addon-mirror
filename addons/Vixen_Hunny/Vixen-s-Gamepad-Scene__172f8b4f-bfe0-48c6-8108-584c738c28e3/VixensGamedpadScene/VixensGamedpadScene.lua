-- Vixen's Gamepad Scene
-- Re-skins the gamepad menus with a theme: pink hearts, cool looks (Midnight,
-- Ember, Frost, Void, Neon, Carbon) or class themes (one per class, or
-- "My class" to follow the current character). Themes live in Themes.lua.
--
-- Where it applies:
--   * the shared gamepad menu backgrounds (ZO_SharedGamepadNavQuadrant_*),
--     used by inventory, character, skills, journal, crafting and more
--   * the button bar along the bottom (keybind strip)
--   * any other large background panel found on a gamepad scene when it opens
--     (and in gamepad dialogs), recognised by name or by its background art
--
-- Drawing ("Drawing style" setting):
--   images     every theme has smooth .dds art in textures/<theme id>/
--   pixel art  gradients and pixel shapes built from plain colored blocks,
--              which works on every client
--   auto       images, switching to pixel art by itself if they don't load
--              (some clients, e.g. console, don't load add-on image files)

VGS = VGS or {}
local VGS = VGS

VGS.name = "VixensGamedpadScene"
VGS.displayName = "|cFF7EB9Vixen's|r Gamepad Scene"

VGS.defaults = {
    enabled = true,
    theme = "hearts",    -- a theme id from Themes.lua, or "class"
    allScenes = true,    -- also theme backgrounds found on other gamepad scenes
    keybindStrip = true, -- theme the button bar along the bottom
    style = "shapes",    -- "shapes" (pixel art) or "textures" (images)
    washAlpha = 0.55,
    heartsAlpha = 0.6,
    heartScale = 1.0,
    floating = true,
    floatSpeed = 0.02,
    showCorner = true,
    cornerAlpha = 0.35,
    showDivider = true,
    showRibbon = true,
    -- Stored as hex text like Bloom HPS's colors: a { r, g, b } table didn't
    -- persist on this client, hex strings do.
    tintHex = "FFFFFF",
}

-- Tint helpers ---------------------------------------------------------------
local function Clamp255(v)
    return math.max(0, math.min(255, math.floor((tonumber(v) or 1) * 255 + 0.5)))
end

function VGS.RGBToHex(r, g, b)
    return string.format("%02X%02X%02X", Clamp255(r), Clamp255(g), Clamp255(b))
end

function VGS.HexToRGB(hex)
    hex = type(hex) == "string" and hex:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return 1, 1, 1 end
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

-- The current tint as { r, g, b } (0-1), read from the saved hex text.
function VGS.GetTint()
    local r, g, b = VGS.HexToRGB(VGS.sv and VGS.sv.tintHex)
    return { r = r, g = g, b = b }
end

VGS.skins = {}      -- one entry per skinned background control
VGS.skinnedBy = {}  -- control -> skin
VGS.errors = {}

local TEX = "VixensGamedpadScene/textures/"
local TILE_SIZE = 256          -- tile.dds is 256x256
local DIVIDER_TEX_HEIGHT = 256 -- divider.dds is 32x256

local HEART_COUNT = 14      -- floating particles on a full menu panel
local DIVIDER_SPRITES = 6   -- little emblems along the side divider
local QUADRANT_LEVEL = 1001 -- draw level on the shared menu panels
local CORNER_SIZE = 180     -- approx. pixel size of the corner emblem
local WASH_BANDS = 16       -- horizontal bands making up the background wash

-- Extra panels found by scanning scenes
local MIN_PANEL_W, MIN_PANEL_H = 250, 200
local SCAN_MAX_DEPTH = 7
local SCAN_MAX_NODES = 4000

-------------------------------------------------------------------------------
-- Finding the shared gamepad menu backgrounds
-------------------------------------------------------------------------------
local function IsControl(v)
    return type(v) == "userdata" and type(v.GetType) == "function"
end

-- ZO_SharedGamepadNavQuadrant_<n>_Background, shown through fragments named
-- GAMEPAD_NAV_QUADRANT_<n>_BACKGROUND_FRAGMENT. <n> is a run of adjacent
-- quadrants ("1", "2_3", "1_2_3", ...). Each candidate name is looked up
-- directly: iterating _G with pairs() touches private functions, which the
-- client forbids.
local function QuadrantSpans()
    local spans = {}
    for first = 1, 4 do
        local parts = {}
        for last = first, 4 do
            parts[#parts + 1] = tostring(last)
            spans[#spans + 1] = table.concat(parts, "_")
        end
    end
    return spans
end

local function FindQuadrantBackgrounds()
    local found, seen = {}, {}
    local function add(ctrl)
        if IsControl(ctrl) and not seen[ctrl] then
            seen[ctrl] = true
            found[#found + 1] = ctrl
        end
    end
    for _, span in ipairs(QuadrantSpans()) do
        add(_G["ZO_SharedGamepadNavQuadrant_" .. span .. "_Background"])
        local fragment = _G["GAMEPAD_NAV_QUADRANT_" .. span .. "_BACKGROUND_FRAGMENT"]
        if type(fragment) == "table" then
            add(fragment.control)
        end
    end
    return found
end

-------------------------------------------------------------------------------
-- Block and sprite helpers
-------------------------------------------------------------------------------
local controlCounter = 0
local function NextName(prefix)
    controlCounter = controlCounter + 1
    return prefix .. controlCounter
end

-- Draw layer used while building (set per skin before creating controls).
local buildLayer = DL_OVERLAY

local function NewBlock(parent, level)
    local tex = WINDOW_MANAGER:CreateControl(NextName("VGS_Block"), parent, CT_TEXTURE)
    tex:SetDrawLayer(buildLayer)
    tex:SetDrawLevel(level)
    tex:SetMouseEnabled(false)
    return tex
end

local function NewContainer(parent)
    local c = WINDOW_MANAGER:CreateControl(NextName("VGS_Group"), parent, CT_CONTROL)
    c:SetMouseEnabled(false)
    return c
end

-- A pixel-art sprite: one block per horizontal run of the shape.
local function NewSprite(parent, level, baseCell, shape, color, alpha)
    local sprite = {
        control = NewContainer(parent),
        parts = {},
        shape = shape,
        baseCell = baseCell,
        color = color,
        alpha = alpha,
    }
    for _, run in ipairs(shape.runs) do
        sprite.parts[#sprite.parts + 1] = { tex = NewBlock(sprite.control, level), run = run }
    end
    if shape.shine then
        sprite.shine = NewBlock(sprite.control, level + 1)
    end
    return sprite
end

local function LayoutSprite(sprite, scale)
    local cell = math.max(1, math.floor(sprite.baseCell * scale + 0.5))
    local shape = sprite.shape
    sprite.control:SetDimensions(shape.w * cell, shape.h * cell)
    for _, part in ipairs(sprite.parts) do
        local row, c0, c1 = part.run[1], part.run[2], part.run[3]
        part.tex:ClearAnchors()
        part.tex:SetAnchor(TOPLEFT, sprite.control, TOPLEFT, c0 * cell, row * cell)
        part.tex:SetDimensions((c1 - c0 + 1) * cell, cell)
    end
    if sprite.shine then
        sprite.shine:ClearAnchors()
        sprite.shine:SetAnchor(TOPLEFT, sprite.control, TOPLEFT, shape.shine[2] * cell, shape.shine[1] * cell)
        sprite.shine:SetDimensions(cell, cell)
    end
end

local function ColorSprite(sprite, t, alphaMul)
    local c, a = sprite.color, sprite.alpha * alphaMul
    for _, part in ipairs(sprite.parts) do
        part.tex:SetColor(c[1] * t.r, c[2] * t.g, c[3] * t.b, a)
    end
    if sprite.shine then
        sprite.shine:SetColor(1, 1, 1, math.min(1, a * 1.2))
    end
end

-------------------------------------------------------------------------------
-- Image style (.dds art per theme, in textures/<theme id>/)
-------------------------------------------------------------------------------
-- Images only when the player picks them. There's no automatic detection:
-- on console the game can report add-on images as loaded while drawing them
-- as flat blocks of the tint color, so "try images, fall back to pixel art"
-- left the theme stuck as a flat sheet that looked like max opacity.
--
-- On console it's always pixel art: add-on images only ever draw as flat
-- blocks there, and the settings menu (LibGamepad) fires stale writes when it
-- closes, which could flip the style to images and leave a flat sheet.
local function IsConsole()
    return type(IsConsoleUI) == "function" and IsConsoleUI()
end

function VGS.UseTextures()
    if IsConsole() then return false end
    return VGS.sv.style == "textures"
end

-- Textures are assigned per theme in ApplyTextureSkin.
local function BuildTextureSkin(skin, bg, base)
    local ts = {}
    ts.root = NewContainer(bg)
    ts.root:SetAnchorFill(bg)

    ts.wash = NewBlock(ts.root, base)
    ts.wash:SetAnchorFill(bg)

    ts.hearts = NewBlock(ts.root, base + 1) -- the theme's particle pattern
    ts.hearts:SetAnchorFill(bg)
    ts.hearts:SetAddressMode(TEX_MODE_WRAP)

    ts.corner = NewBlock(ts.root, base + 2)
    ts.corner:SetDimensions(300, 300)
    ts.corner:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, 70, 40)

    ts.divider = NewBlock(ts.root, base + 3)
    ts.divider:SetWidth(24)
    ts.divider:SetAnchor(TOPRIGHT, bg, TOPRIGHT, 12, 0)
    ts.divider:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, 12, 0)
    ts.divider:SetAddressMode(TEX_MODE_WRAP)

    ts.ribbon = NewBlock(ts.root, base + 3)
    ts.ribbon:SetHeight(24)
    ts.ribbon:SetAnchor(TOPLEFT, bg, TOPLEFT, 10, 4)
    ts.ribbon:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -10, 4)

    ts.hearts:SetHandler("OnUpdate", function(self)
        local sv = VGS.sv
        local now = GetFrameTimeSeconds()

        -- Tile the particle pattern at its natural size and drift it upward.
        local w, h = self:GetDimensions()
        local tile = TILE_SIZE * sv.heartScale
        local off = sv.floating and ((now * sv.floatSpeed) % 1) or 0
        self:SetTextureCoords(0, w / tile, off, h / tile + off)
        local dh = ts.divider:GetHeight()
        if dh > 0 then
            ts.divider:SetTextureCoords(0, 1, 0, dh / DIVIDER_TEX_HEIGHT)
        end
    end)

    skin.tex = ts
end

local function ApplyTextureSkin(skin, show)
    local sv, ts, opts = VGS.sv, skin.tex, skin.opts
    local t = VGS.GetTint()
    ts.root:SetHidden(not show)
    if not show then return end

    local theme = VGS.GetTheme()
    if ts.themeId ~= theme.id then
        local dir = TEX .. theme.id .. "/"
        ts.wash:SetTexture(dir .. "wash.dds")
        ts.hearts:SetTexture(dir .. "tile.dds")
        ts.corner:SetTexture(dir .. "corner.dds")
        ts.divider:SetTexture(dir .. "divider.dds")
        ts.ribbon:SetTexture(dir .. "ribbon.dds")
        ts.themeId = theme.id
    end

    ts.wash:SetHidden(sv.washAlpha <= 0)
    ts.wash:SetColor(t.r, t.g, t.b, sv.washAlpha)
    ts.hearts:SetHidden(sv.heartsAlpha <= 0)
    ts.hearts:SetColor(t.r, t.g, t.b, sv.heartsAlpha)
    ts.corner:SetHidden(not (sv.showCorner and opts.corner))
    ts.corner:SetColor(t.r, t.g, t.b, sv.cornerAlpha)
    ts.divider:SetHidden(not (sv.showDivider and opts.divider))
    ts.divider:SetColor(t.r, t.g, t.b, 1)
    ts.ribbon:SetHidden(not (sv.showRibbon and opts.ribbon))
    ts.ribbon:SetColor(t.r, t.g, t.b, 1)
end

-------------------------------------------------------------------------------
-- Block style: gradient wash, lines and pixel sprites for any theme
-------------------------------------------------------------------------------
-- Stack the wash bands over the panel's height (redone when the height changes).
local function LayoutWashBands(skin)
    local _, h = skin.bg:GetDimensions()
    if not h or h <= 0 or h == skin.washHeight then return end
    skin.washHeight = h
    for i, band in ipairs(skin.washBands) do
        local top = math.floor((i - 1) * h / WASH_BANDS)
        local bottom = math.floor(i * h / WASH_BANDS)
        band:ClearAnchors()
        band:SetAnchor(TOPLEFT, skin.bg, TOPLEFT, 0, top)
        band:SetAnchor(BOTTOMRIGHT, skin.bg, TOPRIGHT, 0, bottom)
    end
end

local function BuildBlockSkin(skin, bg)
    local base = skin.opts.level
    skin.sets = {} -- theme id -> sprites for that theme, built on first use

    -- Root container so the whole skin can be shown/hidden at once.
    skin.root = NewContainer(bg)
    skin.root:SetAnchorFill(bg)

    -- Background wash: a top-to-bottom fade built from plain colored bands.
    -- (Not SetGradientColors: on console its per-corner opacity was ignored and
    -- the wash drew at full strength whatever the opacity setting.)
    skin.washBands = {}
    for i = 1, WASH_BANDS do
        skin.washBands[i] = NewBlock(skin.root, base)
    end

    skin.particleLayer = NewContainer(skin.root)
    skin.particleLayer:SetAnchorFill(bg)

    if skin.opts.divider then
        skin.divider = NewContainer(skin.root)
        skin.divider:SetAnchor(TOPRIGHT, bg, TOPRIGHT, 0, 0)
        skin.divider:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, 0, 0)
        skin.divider:SetWidth(24)
        skin.dividerGlow = NewBlock(skin.divider, base + 3)
        skin.dividerGlow:SetAnchor(TOP, skin.divider, TOP, 0, 0)
        skin.dividerGlow:SetAnchor(BOTTOM, skin.divider, BOTTOM, 0, 0)
        skin.dividerGlow:SetWidth(8)
        skin.dividerLine = NewBlock(skin.divider, base + 4)
        skin.dividerLine:SetAnchor(TOP, skin.divider, TOP, 0, 0)
        skin.dividerLine:SetAnchor(BOTTOM, skin.divider, BOTTOM, 0, 0)
        skin.dividerLine:SetWidth(2)
    end

    if skin.opts.ribbon then
        -- A line fading in from both ends, with an emblem in the middle.
        skin.ribbon = NewContainer(skin.root)
        skin.ribbon:SetAnchor(TOPLEFT, bg, TOPLEFT, 10, 6)
        skin.ribbon:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -10, 6)
        skin.ribbon:SetHeight(24)
        skin.ribbonLeft = NewBlock(skin.ribbon, base + 3)
        skin.ribbonLeft:SetAnchor(LEFT, skin.ribbon, LEFT, 0, 0)
        skin.ribbonLeft:SetAnchor(RIGHT, skin.ribbon, CENTER, 0, 0)
        skin.ribbonLeft:SetHeight(2)
        skin.ribbonRight = NewBlock(skin.ribbon, base + 3)
        skin.ribbonRight:SetAnchor(LEFT, skin.ribbon, CENTER, 0, 0)
        skin.ribbonRight:SetAnchor(RIGHT, skin.ribbon, RIGHT, 0, 0)
        skin.ribbonRight:SetHeight(2)
    end

    -- Particle motion and size-dependent positions. OnUpdate only fires
    -- while the panel is visible.
    skin.particleLayer:SetHandler("OnUpdate", function()
        LayoutWashBands(skin)
        local set = skin.activeSet
        if not set then return end
        local sv = VGS.sv
        local w, h = bg:GetDimensions()
        if w <= 0 or h <= 0 then return end
        local now = GetFrameTimeSeconds()
        local motion = set.theme.particles.motion
        local speed = sv.floatSpeed * (set.theme.particles.speed or 1)
        local drift = sv.floating and (now * speed) or 0
        local margin = 40
        for _, p in ipairs(set.particles) do
            local y
            if motion == "down" then
                y = (p.y + drift) % 1
            elseif motion == "twinkle" then
                y = (p.y - drift * 0.3) % 1
            else -- "up", "flicker"
                y = (p.y - drift) % 1
            end
            local sway = sv.floating and math.sin(now * 0.8 + p.phase) * 6 or 0
            p.sprite.control:ClearAnchors()
            p.sprite.control:SetAnchor(TOPLEFT, bg, TOPLEFT,
                p.x * (w - 30) + sway, y * (h + margin) - margin)

            if sv.floating and motion == "twinkle" then
                p.sprite.control:SetAlpha(0.25 + 0.75 * (0.5 + 0.5 * math.sin(now * 1.7 + p.phase * 3)))
            elseif sv.floating and motion == "flicker" then
                p.sprite.control:SetAlpha(0.55 + 0.45 * math.sin(now * 9 + p.phase * 5))
            else
                p.sprite.control:SetAlpha(1)
            end
        end
        for i, sprite in ipairs(set.dividerSprites) do
            sprite.control:ClearAnchors()
            sprite.control:SetAnchor(CENTER, skin.divider, TOP, 0, (i - 0.5) * h / DIVIDER_SPRITES)
        end
    end)
end

-- Sprites for one theme on one skin (built the first time it's needed).
local function EnsureSpriteSet(skin, theme)
    local set = skin.sets[theme.id]
    if set then return set end

    local opts, base = skin.opts, skin.opts.level
    buildLayer = opts.layer
    set = { theme = theme, particles = {}, dividerSprites = {} }
    set.root = NewContainer(skin.root)
    set.root:SetAnchorFill(skin.bg)

    -- Random spots, sizes and colors, seeded per panel so each panel looks
    -- different but stays the same between reloads.
    local seed = skin.index * 7919 + 17
    local function rnd() -- Park-Miller; products stay exact in Lua doubles
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end

    local pdef = theme.particles
    local shape = VGS.SHAPES[pdef.shape]
    -- keep particles roughly the same on-screen size whatever the grid size
    local sizeMul = 7 / math.max(shape.w, shape.h) * (pdef.size or 1)
    local count = math.max(1, math.floor(opts.heartCount * (pdef.count or 1) + 0.5))
    for i = 1, count do
        local color = pdef.colors[1 + math.floor(rnd() * #pdef.colors)]
        local cell = ((opts.cellMin or 3) + math.floor(rnd() * (opts.cellRange or 4))) * sizeMul
        local sprite = NewSprite(set.root, base + 2, cell, shape, color, 0.45 + rnd() * 0.55)
        set.particles[i] = { sprite = sprite, x = rnd(), y = rnd(), phase = rnd() * 6.28 }
    end

    -- Big corner emblem.
    local cshape = VGS.SHAPES[theme.corner.shape]
    set.corner = NewSprite(set.root, base + 1, CORNER_SIZE / math.max(cshape.w, cshape.h), cshape, theme.corner.color, 1)
    set.corner.control:SetAnchor(BOTTOMRIGHT, skin.bg, BOTTOMRIGHT, -30, -40)

    -- Small emblems on the divider and ribbon.
    if opts.divider then
        for i = 1, DIVIDER_SPRITES do
            set.dividerSprites[i] = NewSprite(set.root, base + 5, 2 * sizeMul, shape, theme.corner.color, 1)
        end
    end
    if opts.ribbon then
        set.ribbonSprite = NewSprite(set.root, base + 4, 3 * sizeMul, cshape, theme.corner.color, 1)
        set.ribbonSprite.control:SetAnchor(CENTER, skin.ribbon, CENTER, 0, 0)
    end

    skin.sets[theme.id] = set
    return set
end

local function ApplyBlockSkin(skin, show)
    local sv, opts = VGS.sv, skin.opts
    skin.root:SetHidden(not show)
    if not show then return end

    local theme = VGS.GetTheme()
    local set = EnsureSpriteSet(skin, theme)
    for _, other in pairs(skin.sets) do
        other.root:SetHidden(other ~= set)
    end
    skin.activeSet = set

    local t = VGS.GetTint()
    local top, bottom = theme.wash[1], theme.wash[2]
    LayoutWashBands(skin)
    for i, band in ipairs(skin.washBands) do
        local f = (i - 0.5) / WASH_BANDS -- 0 at the top, 1 at the bottom
        band:SetHidden(sv.washAlpha <= 0)
        band:SetColor(
            (top[1] + (bottom[1] - top[1]) * f) * t.r,
            (top[2] + (bottom[2] - top[2]) * f) * t.g,
            (top[3] + (bottom[3] - top[3]) * f) * t.b,
            sv.washAlpha)
    end

    for _, p in ipairs(set.particles) do
        p.sprite.control:SetHidden(sv.heartsAlpha <= 0)
        LayoutSprite(p.sprite, sv.heartScale)
        ColorSprite(p.sprite, t, sv.heartsAlpha)
    end

    set.corner.control:SetHidden(not (sv.showCorner and opts.corner))
    LayoutSprite(set.corner, 1)
    ColorSprite(set.corner, t, sv.cornerAlpha)

    local line, accent = theme.line, theme.corner.color
    local lr, lg, lb = line[1] * t.r, line[2] * t.g, line[3] * t.b

    if opts.divider then
        skin.divider:SetHidden(not sv.showDivider)
        skin.dividerLine:SetColor(lr, lg, lb, 0.9)
        skin.dividerGlow:SetColor(accent[1] * t.r, accent[2] * t.g, accent[3] * t.b, 0.25)
        for _, sprite in ipairs(set.dividerSprites) do
            sprite.control:SetHidden(not sv.showDivider)
            LayoutSprite(sprite, 1)
            ColorSprite(sprite, t, 1)
        end
    end

    if opts.ribbon then
        skin.ribbon:SetHidden(not sv.showRibbon)
        -- plain colored lines (gradients aren't reliable on console)
        skin.ribbonLeft:SetColor(lr, lg, lb, 0.7)
        skin.ribbonRight:SetColor(lr, lg, lb, 0.7)
        set.ribbonSprite.control:SetHidden(not sv.showRibbon)
        LayoutSprite(set.ribbonSprite, 1)
        ColorSprite(set.ribbonSprite, t, 1)
    end
end

-------------------------------------------------------------------------------
-- Building and applying skins
-------------------------------------------------------------------------------
-- opts:
--   layer, level  where to draw (menu panels: top layer; other panels: just
--                 above their own background so their text stays on top)
--   divider       glowing side line with little emblems (menu panels)
--   ribbon        line + emblem along the top edge (menu panels, keybind strip)
--   corner        big corner emblem (tall panels only)
--   heartCount    number of floating particles (themes can scale this)
--   cellMin/Range pixel size range of the particles (default 3..6)
--   extra         true for panels found by scanning scenes
--   strip         true for the keybind strip
local function BuildSkin(bg, opts)
    local skin = { bg = bg, opts = opts, index = #VGS.skins }
    buildLayer = opts.layer
    BuildTextureSkin(skin, bg, opts.level)
    BuildBlockSkin(skin, bg)
    return skin
end

function VGS.ApplySkin(skin)
    local sv = VGS.sv
    local on = sv.enabled
        and (not skin.opts.extra or sv.allScenes)
        and (not skin.opts.strip or sv.keybindStrip)
    local useTextures = VGS.UseTextures()
    ApplyTextureSkin(skin, on and useTextures)
    ApplyBlockSkin(skin, on and not useTextures)
end

-- Settings menus can hand values over as text: LibGamepad (which shows LAM2
-- menus as native gamepad options) passes sliders as formatted strings such as
-- "0.35". Put every saved value back to the type of its default, so numbers
-- are numbers and checkboxes are true/false, and repair values already
-- stored as text.
function VGS.SanitizeSettings()
    local sv, def = VGS.sv, VGS.defaults
    if not sv then return end
    for key, default in pairs(def) do
        local value = sv[key]
        local kind = type(default)
        if kind == "number" and type(value) ~= "number" then
            sv[key] = tonumber(value) or default
        elseif kind == "boolean" and type(value) ~= "boolean" then
            if value == "true" or value == 1 or value == "1" then
                sv[key] = true
            elseif value == "false" or value == 0 or value == "0" then
                sv[key] = false
            else
                sv[key] = default
            end
        elseif kind == "string" and type(value) ~= "string" then
            sv[key] = value ~= nil and tostring(value) or default
        end
    end
end

function VGS.ApplyAll()
    VGS.SanitizeSettings()
    for _, skin in ipairs(VGS.skins) do
        VGS.ApplySkin(skin)
    end
end

local function AddSkin(bg, opts)
    if VGS.skinnedBy[bg] then return VGS.skinnedBy[bg] end
    local ok, skinOrErr = pcall(BuildSkin, bg, opts)
    if not ok then
        VGS.errors[#VGS.errors + 1] = tostring(bg:GetName()) .. ": " .. tostring(skinOrErr)
        return nil
    end
    VGS.skins[#VGS.skins + 1] = skinOrErr
    VGS.skinnedBy[bg] = skinOrErr
    local applied, err = pcall(VGS.ApplySkin, skinOrErr)
    if not applied then
        VGS.errors[#VGS.errors + 1] = tostring(bg:GetName()) .. ": " .. tostring(err)
    end
    return skinOrErr
end

-- Highest draw layer/level used by any texture or backdrop in a control tree,
-- so a skin can sit just above the control's own background art.
local function TopDrawOrder(ctrl)
    local layer, level = DL_BACKGROUND, 0
    local function visit(c, depth)
        if depth > 5 then return end
        local ctype = c:GetType()
        if (ctype == CT_TEXTURE or ctype == CT_BACKDROP) and c.GetDrawLayer then
            local l = c:GetDrawLayer()
            local lv = c.GetDrawLevel and c:GetDrawLevel() or 0
            if l > layer or (l == layer and lv > level) then layer, level = l, lv end
        end
        for i = 1, c:GetNumChildren() do
            local child = c:GetChild(i)
            if child then visit(child, depth + 1) end
        end
    end
    visit(ctrl, 0)
    return layer, level
end

-- The gamepad keybind strip: the bar along the bottom with Select / Back /
-- Text Chat and the player's name and location. Short and wide, so it gets a
-- slim skin: wash, a row of small hearts and the heart ribbon on top.
function VGS.SkinKeybindStrip()
    local candidates, seen = {}, {}
    local function add(ctrl)
        if IsControl(ctrl) and not seen[ctrl] then
            seen[ctrl] = true
            candidates[#candidates + 1] = ctrl
        end
    end
    local backdrop = _G["KEYBIND_STRIP_GAMEPAD_BACKDROP_FRAGMENT"]
    if type(backdrop) == "table" then add(backdrop.control) end
    add(_G["ZO_KeybindStripGamepadBackground"])

    for _, ctrl in ipairs(candidates) do
        local layer, level = TopDrawOrder(ctrl)
        AddSkin(ctrl, {
            layer = layer, level = level + 1,
            ribbon = true, heartCount = 10, cellMin = 2, cellRange = 2,
            strip = true,
        })
    end
end

function VGS.SkinBackgrounds()
    for _, bg in ipairs(FindQuadrantBackgrounds()) do
        AddSkin(bg, {
            layer = DL_OVERLAY, level = QUADRANT_LEVEL,
            divider = true, ribbon = true, corner = true, heartCount = HEART_COUNT,
        })
    end
    VGS.SkinKeybindStrip()
end

-------------------------------------------------------------------------------
-- Theming every other gamepad scene
-------------------------------------------------------------------------------
local BG_NAME_ENDINGS = { "bg", "background", "backdrop" }
local SKIP_WORDS = { "highlight", "select", "icon", "focus", "glow", "bar", "keybind", "frame", "border", "edge", "divider", "vgs_" }

local function EndsWith(s, suffix)
    return #s >= #suffix and s:sub(-#suffix) == suffix
end

-- Is this control a large background panel we should theme?
local function IsBackgroundPanel(c)
    local ctype = c:GetType()
    if ctype ~= CT_TEXTURE and ctype ~= CT_BACKDROP then return false end
    if c:IsHidden() then return false end
    local w, h = c:GetDimensions()
    if w < MIN_PANEL_W or h < MIN_PANEL_H then return false end

    local name = (c:GetName() or ""):lower()
    for _, word in ipairs(SKIP_WORDS) do
        if name:find(word, 1, true) then return false end
    end
    for _, ending in ipairs(BG_NAME_ENDINGS) do
        if EndsWith(name, ending) then return true end
    end
    if ctype == CT_TEXTURE and c.GetTextureFileName then
        local file = (c:GetTextureFileName() or ""):lower()
        if file:find("gamepad", 1, true) and (file:find("bg", 1, true) or file:find("background", 1, true)) then
            return true
        end
    end
    return false
end

-- Walk a control tree; theme each background panel found (and don't look
-- inside it, nor inside panels we already themed). Returns the number of
-- newly themed panels plus, when collecting, unmatched large textures.
local function ScanControl(root, report)
    local nodes, added = 0, 0
    local function walk(c, depth)
        if nodes >= SCAN_MAX_NODES or depth > SCAN_MAX_DEPTH then return end
        nodes = nodes + 1
        if VGS.skinnedBy[c] then return end
        local name = c:GetName() or ""
        if name:find("^VGS_") then return end

        if IsBackgroundPanel(c) then
            local _, h = c:GetDimensions()
            local w = c:GetWidth()
            local layer = c.GetDrawLayer and c:GetDrawLayer() or DL_BACKGROUND
            local level = (c.GetDrawLevel and c:GetDrawLevel() or 0) + 1
            local count = math.max(3, math.min(HEART_COUNT, math.floor(w * h / 45000)))
            if AddSkin(c, {
                layer = layer, level = level,
                corner = h >= 500,
                heartCount = count, extra = true,
            }) then
                added = added + 1
                if report then report.themed[#report.themed + 1] = name end
            end
            return
        end

        if report and c:GetType() == CT_TEXTURE and not c:IsHidden() then
            local w, h = c:GetDimensions()
            if w >= MIN_PANEL_W and h >= MIN_PANEL_H then
                local file = c.GetTextureFileName and c:GetTextureFileName() or ""
                report.unmatched[#report.unmatched + 1] = string.format("%s (%dx%d) %s", name, w, h, file)
            end
        end

        for i = 1, c:GetNumChildren() do
            local child = c:GetChild(i)
            if child then walk(child, depth + 1) end
        end
    end
    walk(root, 0)
    return added
end

-- The controls a scene shows, via its fragments.
local function SceneRoots(scene)
    local roots = {}
    if type(scene) ~= "table" then return roots end
    local fragments
    if type(scene.GetFragments) == "function" then
        local ok, f = pcall(scene.GetFragments, scene)
        fragments = ok and f or nil
    end
    fragments = fragments or scene.fragments
    if type(fragments) ~= "table" then return roots end
    for _, fragment in pairs(fragments) do
        if type(fragment) == "table" then
            local ctrl = fragment.control
            if not IsControl(ctrl) and type(fragment.GetControl) == "function" then
                local ok, c = pcall(fragment.GetControl, fragment)
                ctrl = ok and c or nil
            end
            if IsControl(ctrl) then roots[#roots + 1] = ctrl end
        end
    end
    return roots
end

function VGS.ScanScene(scene, report)
    local added = 0
    for _, root in ipairs(SceneRoots(scene)) do
        local ok, n = pcall(ScanControl, root, report)
        if ok then added = added + n end
    end
    return added
end

local function OnSceneStateChanged(scene, _, newState)
    if newState ~= SCENE_SHOWN then return end
    if not (VGS.sv and VGS.sv.enabled and VGS.sv.allScenes) then return end
    if not IsInGamepadPreferredMode() then return end
    VGS.ScanScene(scene)
end

-- Gamepad dialogs aren't scenes; scan each one right after it opens.
local function HookDialogs()
    if type(ZO_PostHook) ~= "function" or type(ZO_Dialogs_ShowGamepadDialog) ~= "function" then return end
    local ok, err = pcall(ZO_PostHook, _G, "ZO_Dialogs_ShowGamepadDialog", function(dialogName)
        if not (VGS.sv and VGS.sv.enabled and VGS.sv.allScenes) then return end
        zo_callLater(function()
            local dialog = type(ZO_Dialogs_FindDialog) == "function" and ZO_Dialogs_FindDialog(dialogName)
            if IsControl(dialog) then pcall(ScanControl, dialog) end
        end, 50)
    end)
    if not ok then
        VGS.errors[#VGS.errors + 1] = "dialog hook: " .. tostring(err)
    end
end

-- /vgsscan: theme the current scene now and list what was found, so missed
-- backgrounds can be reported.
function VGS.ScanCurrentScene()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    local report = { themed = {}, unmatched = {} }
    VGS.ScanScene(scene, report)
    d(string.format("[VGS scan] scene: %s, newly themed: %d",
        tostring(scene and scene.name), #report.themed))
    for _, n in ipairs(report.themed) do d("  themed: " .. n) end
    for i, n in ipairs(report.unmatched) do
        if i > 12 then d("  ...") break end
        d("  not themed: " .. n)
    end
end

SLASH_COMMANDS["/vgsscan"] = VGS.ScanCurrentScene

-------------------------------------------------------------------------------
-- Settings write log (/vgslog): records the last changes to settings and
-- whether they were saved or blocked, to track down anything that overwrites
-- them.
-------------------------------------------------------------------------------
VGS.writeLog = {}
local WRITE_LOG_SIZE = 15

function VGS.LogWrite(key, value, result)
    local log = VGS.writeLog
    log[#log + 1] = string.format("%.1fs  %s = %s  (%s)",
        GetFrameTimeSeconds(), tostring(key), tostring(value), tostring(result))
    if #log > WRITE_LOG_SIZE then table.remove(log, 1) end
end

function VGS.ShowWriteLog()
    local sv = VGS.sv
    local t = VGS.GetTint()
    d(string.format("[VGS] current: theme %s, style %s, tint %s (%.2f/%.2f/%.2f), enabled %s",
        tostring(sv.theme), tostring(sv.style), tostring(sv.tintHex), t.r, t.g, t.b, tostring(sv.enabled)))
    d(string.format("[VGS] wash %s, particles %s, corner %s, size %s, speed %s, saved data loaded %s time(s)",
        tostring(sv.washAlpha), tostring(sv.heartsAlpha), tostring(sv.cornerAlpha),
        tostring(sv.heartScale), tostring(sv.floatSpeed), tostring(sv.loadCount)))
    if #VGS.writeLog == 0 then
        d("[VGS] no setting changes this session")
    end
    for _, line in ipairs(VGS.writeLog) do
        d("[VGS] " .. line)
    end
end

SLASH_COMMANDS["/vgslog"] = VGS.ShowWriteLog

-------------------------------------------------------------------------------
-- Saving
-------------------------------------------------------------------------------
-- Saved variables are written by the game itself, like add-ons whose settings
-- persist on this client (e.g. Bloom HPS). On this client that write doesn't
-- seem to happen on every /reloadui: values set late in a session came back
-- as older ones. VGS.SaveNow (Save now button, /vgssave) asks the game to
-- write this add-on's data immediately so we can test whether that keeps the
-- latest values. (An earlier automatic version was tested only while the
-- saved-data name didn't match the folder, so it proved nothing either way.)
function VGS.RequestSave()
end

function VGS.SaveNow()
    local manager = GetAddOnManager and GetAddOnManager()
    if not (manager and manager.RequestAddOnSavedVariablesPrioritySave) then
        d("[Vixen's Gamepad Scene] This client has no save-now request.")
        return
    end
    local ok, err = pcall(manager.RequestAddOnSavedVariablesPrioritySave, manager, VGS.name)
    if ok then
        VGS.LogWrite("save now", "requested", "ok")
        d("[Vixen's Gamepad Scene] Asked the game to save your settings now.")
    else
        VGS.LogWrite("save now", tostring(err), "failed")
        d("[Vixen's Gamepad Scene] Save request failed: " .. tostring(err))
    end
end

SLASH_COMMANDS["/vgssave"] = VGS.SaveNow

-------------------------------------------------------------------------------
-- Status
-------------------------------------------------------------------------------
function VGS.GetStatus()
    local menus, extras, strip = 0, 0, false
    for _, skin in ipairs(VGS.skins) do
        if skin.opts.extra then extras = extras + 1
        elseif skin.opts.strip then strip = true
        else menus = menus + 1 end
    end
    local text = string.format("Themed %d menu panel(s), %d other background(s), button bar: %s",
        menus, extras, strip and "yes" or "not found")
    if VGS.sv then
        local theme = VGS.GetTheme()
        local style = VGS.UseTextures() and "images" or "pixel art"
        text = text .. " | Theme: " .. theme.name .. " (" .. style .. ")"
        text = text .. " | Saved data loaded " .. tostring(VGS.sv.loadCount or 0) .. " time(s)"
    end
    if #VGS.errors > 0 then
        text = text .. " | Errors: " .. table.concat(VGS.errors, "; ")
    end
    return text
end

-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(VGS.name, EVENT_PLAYER_ACTIVATED)
    -- second pass in case any backgrounds were created after addon load
    VGS.SkinBackgrounds()
    d("[Vixen's Gamepad Scene] " .. VGS.GetStatus())
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= VGS.name then return end
    EVENT_MANAGER:UnregisterForEvent(VGS.name, EVENT_ADD_ON_LOADED)

    -- The saved-data name starts with the add-on's folder name
    -- ("VixensGamedpadScene", spelling included), like other add-ons whose
    -- settings persist on this client. The old name ("VixensGamepadScene_SV")
    -- didn't match the folder and its data was never kept.
    VGS.sv = ZO_SavedVars:NewAccountWide("VixensGamedpadScene_SV", 1, nil, VGS.defaults)

    -- Persistence check: counts loads. If this stays at 1 after relogging,
    -- the game isn't keeping this add-on's saved data at all.
    VGS.sv.loadCount = (VGS.sv.loadCount or 0) + 1

    -- One-time move of an old { r, g, b } tint table to hex text.
    if type(VGS.sv.tint) == "table" then
        local t = VGS.sv.tint
        VGS.sv.tintHex = VGS.RGBToHex(t.r, t.g, t.b)
        VGS.sv.tint = nil
    end
    -- Repair values stored as text by earlier versions, before anything is drawn.
    VGS.SanitizeSettings()

    -- "auto" (try images, fall back to pixel art) is gone: move it, and
    -- anything unknown, to pixel art.
    if VGS.sv.style ~= "textures" then
        VGS.sv.style = "shapes"
    end

    VGS.SkinBackgrounds()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    HookDialogs()
    EVENT_MANAGER:RegisterForEvent(VGS.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    if VGS.RegisterSettings then
        VGS.RegisterSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(VGS.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
