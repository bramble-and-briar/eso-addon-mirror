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
    style = "auto",      -- Pink Hearts only: "auto", "textures" or "shapes"
    washAlpha = 0.55,
    heartsAlpha = 0.6,
    heartScale = 1.0,
    floating = true,
    floatSpeed = 0.02,
    showCorner = true,
    cornerAlpha = 0.35,
    showDivider = true,
    showRibbon = true,
    tint = { r = 1, g = 1, b = 1 },
}

VGS.skins = {}      -- one entry per skinned background control
VGS.skinnedBy = {}  -- control -> skin
VGS.errors = {}
VGS.texturesFailed = false

local TEX = "VixensGamedpadScene/textures/"
local TILE_SIZE = 256          -- tile.dds is 256x256
local DIVIDER_TEX_HEIGHT = 256 -- divider.dds is 32x256
local TEXTURE_GRACE = 1.5      -- seconds visible before "auto" gives up on textures

local HEART_COUNT = 14      -- floating particles on a full menu panel
local DIVIDER_SPRITES = 6   -- little emblems along the side divider
local QUADRANT_LEVEL = 1001 -- draw level on the shared menu panels
local CORNER_SIZE = 180     -- approx. pixel size of the corner emblem

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
function VGS.UseTextures()
    local style = VGS.sv.style
    return style == "textures" or (style ~= "shapes" and not VGS.texturesFailed)
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

    local lastUpdate, visibleSince = 0, 0
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

        -- "auto": if the art still hasn't loaded after being on screen for a
        -- moment, this client can't load add-on images; switch to blocks.
        if now - lastUpdate > 0.5 then visibleSince = now end
        lastUpdate = now
        if sv.style == "auto" and not VGS.texturesFailed
            and now - math.max(visibleSince, ts.loadStart or 0) > TEXTURE_GRACE
            and not ts.wash:IsTextureLoaded() then
            VGS.texturesFailed = true
            d("[Vixen's Gamepad Scene] Theme images didn't load, switched to pixel art.")
            VGS.ApplyAll()
        end
    end)

    skin.tex = ts
end

local function ApplyTextureSkin(skin, show)
    local sv, ts, opts = VGS.sv, skin.tex, skin.opts
    local t = sv.tint
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
        ts.loadStart = GetFrameTimeSeconds() -- give the new images time to load
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
local function BuildBlockSkin(skin, bg)
    local base = skin.opts.level
    skin.sets = {} -- theme id -> sprites for that theme, built on first use

    -- Root container so the whole skin can be shown/hidden at once.
    skin.root = NewContainer(bg)
    skin.root:SetAnchorFill(bg)

    skin.wash = NewBlock(skin.root, base)
    skin.wash:SetAnchorFill(bg)

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

    local t = sv.tint
    local top, bottom = theme.wash[1], theme.wash[2]
    skin.wash:SetHidden(sv.washAlpha <= 0)
    skin.wash:SetColor(1, 1, 1, 1)
    skin.wash:SetGradientColors(ORIENTATION_VERTICAL,
        top[1] * t.r, top[2] * t.g, top[3] * t.b, sv.washAlpha,
        bottom[1] * t.r, bottom[2] * t.g, bottom[3] * t.b, sv.washAlpha)

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
        skin.ribbonLeft:SetColor(1, 1, 1, 1)
        skin.ribbonLeft:SetGradientColors(ORIENTATION_HORIZONTAL, lr, lg, lb, 0, lr, lg, lb, 0.9)
        skin.ribbonRight:SetColor(1, 1, 1, 1)
        skin.ribbonRight:SetGradientColors(ORIENTATION_HORIZONTAL, lr, lg, lb, 0.9, lr, lg, lb, 0)
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

function VGS.ApplyAll()
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
-- Saving
-------------------------------------------------------------------------------
-- The game normally writes saved variables only at logout / reload, and on
-- clients that keep them server-side (console) changes can be lost before
-- that. After a settings change, ask the game to save this add-on's data
-- right away. Rapid changes (e.g. dragging a slider) are batched into one
-- save, and saves are spaced out so the client doesn't throttle them.
local SAVE_DELAY_MS = 2000     -- wait for changes to settle
local SAVE_MIN_GAP_MS = 10000  -- at most one save request per 10 seconds
local SAVE_UPDATE_NAME = "VixensGamedpadScene_Save"
local lastSaveRequest = nil

function VGS.RequestSave()
    EVENT_MANAGER:UnregisterForUpdate(SAVE_UPDATE_NAME)
    local now = GetGameTimeMilliseconds()
    local delay = SAVE_DELAY_MS
    if lastSaveRequest then
        delay = math.max(delay, lastSaveRequest + SAVE_MIN_GAP_MS - now)
    end
    EVENT_MANAGER:RegisterForUpdate(SAVE_UPDATE_NAME, delay, function()
        EVENT_MANAGER:UnregisterForUpdate(SAVE_UPDATE_NAME)
        lastSaveRequest = GetGameTimeMilliseconds()
        local manager = GetAddOnManager and GetAddOnManager()
        if manager and manager.RequestAddOnSavedVariablesPrioritySave then
            local ok, err = pcall(manager.RequestAddOnSavedVariablesPrioritySave, manager, VGS.name)
            if not ok then
                VGS.errors[#VGS.errors + 1] = "save: " .. tostring(err)
            end
        end
    end)
end

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
        if VGS.texturesFailed then style = style .. ", images failed to load" end
        text = text .. " | Theme: " .. theme.name .. " (" .. style .. ")"
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

    VGS.sv = ZO_SavedVars:NewAccountWide("VixensGamepadScene_SV", 1, nil, VGS.defaults)

    VGS.SkinBackgrounds()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    HookDialogs()
    EVENT_MANAGER:RegisterForEvent(VGS.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    if VGS.RegisterSettings then
        VGS.RegisterSettings()
    end
end

EVENT_MANAGER:RegisterForEvent(VGS.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
