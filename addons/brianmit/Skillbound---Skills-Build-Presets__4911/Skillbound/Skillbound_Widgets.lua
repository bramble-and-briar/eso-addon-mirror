-- Skillbound_Widgets.lua : building blocks in look "K" (hearth ember): warm near-black
-- panels, gilded frames with a lit top edge, glow lights (additive), the pointed plate
-- button (Wear) with a sheen, the game's divider with a diamond.
-- Every interactive widget animates the same way (Skillbound_Anim.lua): hover 120 ms
-- Out, press 80 ms, the plate's sheen on hover.
-- No special characters in texts (the game font has no ✕ ★ ✓ ●: they show as boxes).

local B = Skillbound
local C = B.COLOR
local Anim = B.Anim
local W = {}
B.W = W

local counter = 0
function W.Name(prefix)
    counter = counter + 1
    return "Skillbound_" .. (prefix or "C") .. counter
end

function W.Label(parent, font, color, text, align)
    local l = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font or B.Font("text", 14))
    l:SetColor(B.RGBA(color or C.text))
    l:SetText(text or "")
    if align then l:SetHorizontalAlignment(align) end
    l:SetMouseEnabled(false)
    return l
end

function W.Tex(parent, texture, w, h, color, alpha)
    local t = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    if texture then t:SetTexture(texture) end
    if w then t:SetDimensions(w, h or w) end
    if color then t:SetColor(B.RGBA(color, alpha)) end
    t:SetMouseEnabled(false)
    return t
end

-- soft light (glow.dds, additive: it brightens what's under it)
function W.Glow(parent, w, h, color, alpha)
    local t = W.Tex(parent, B.TEX .. "glow.dds", w, h, color or C.glow, 1)
    if t.SetBlendMode then t:SetBlendMode(TEX_BLEND_MODE_ADD) end
    t:SetAlpha(alpha or 1)
    return t
end

-- 1 px frame around a control (four lines). frame:SetFrameColor(color, alpha)
function W.Frame(parent, color, alpha, thickness)
    thickness = thickness or 1
    local lines = {}
    local function Line(a1, a2, horizontal)
        local t = W.Tex(parent)
        t:SetAnchor(a1, parent, a1, 0, 0)
        t:SetAnchor(a2, parent, a2, 0, 0)
        if horizontal then t:SetHeight(thickness) else t:SetWidth(thickness) end
        t:SetDrawLevel(3)
        lines[#lines + 1] = t
    end
    Line(TOPLEFT, TOPRIGHT, true)
    Line(BOTTOMLEFT, BOTTOMRIGHT, true)
    Line(TOPLEFT, BOTTOMLEFT, false)
    Line(TOPRIGHT, BOTTOMRIGHT, false)
    local frame = { lines = lines }
    function frame:SetFrameColor(c, a)
        for _, t in ipairs(self.lines) do t:SetColor(B.RGBA(c, a)) end
    end
    function frame:SetHidden(hidden)
        for _, t in ipairs(self.lines) do t:SetHidden(hidden) end
    end
    frame:SetFrameColor(color or C.line, alpha)
    return frame
end

-- a thin gold line along the top edge: light falling on the frame from above
function W.TopLight(parent, inset, alpha)
    local t = W.Tex(parent, nil, 10, 1, C.gold, alpha or 0.45)
    t:SetAnchor(TOPLEFT, parent, TOPLEFT, inset or 12, 1)
    t:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -(inset or 12), 1)
    t:SetDrawLevel(4)
    return t
end

-- warm dark panel: fill (optionally the ember background picture) + dark gold frame + top light
function W.Panel(parent, alpha, ember)
    local p = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    p.fill = W.Tex(p, ember and (B.BG) or nil)
    p.fill:SetAnchorFill(p)
    if ember then
        p.fill:SetColor(1, 1, 1, alpha or 1)
    else
        p.fill:SetColor(B.RGBA(C.panel, alpha or 0.97))
    end
    p.frame = W.Frame(p, C.goldDark, 1)
    p.light = W.TopLight(p, 14, 0.4)
    return p
end

-- the game's divider: a line with a small diamond in the middle
function W.Divider(parent, color)
    local d = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    d:SetHeight(9)
    local gem = W.Tex(d, B.TEX .. "diamond_fill.dds", 9, 9, color or C.gold)
    gem:SetAnchor(CENTER, d, CENTER, 0, 0)
    local left = W.Tex(d, nil, 10, 1, C.faint)
    left:SetAnchor(LEFT, d, LEFT, 0, 0)
    left:SetAnchor(RIGHT, gem, LEFT, -5, 0)
    local right = W.Tex(d, nil, 10, 1, C.faint)
    right:SetAnchor(LEFT, gem, RIGHT, 5, 0)
    right:SetAnchor(RIGHT, d, RIGHT, 0, 0)
    d.left, d.right, d.gem = left, right, gem
    return d
end

-- small section header: "SKILLS ———"
function W.Header(parent, text)
    local h = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    h:SetHeight(14)
    h.label = W.Label(h, B.Font("head", 13), C.dim, zo_strupper(text))
    h.label:SetAnchor(LEFT, h, LEFT, 0, 0)
    h.line = W.Tex(h, nil, 10, 1, C.line)
    h.line:SetAnchor(LEFT, h.label, RIGHT, 8, 0)
    h.line:SetAnchor(RIGHT, h, RIGHT, 0, 0)
    return h
end

-- ---------------------------------------------------------------------------
-- Buttons. kind:
--   "plate"  : the pointed amber plate (Wear, Save build, Share...). Hover (sketch 6, picked
--              2026-10-01): it lifts 3 px with a dark shadow under it and gets a bit brighter.
--              Click (sketches A + B): it drops down flat while pressed, springs back up on
--              release, and the inside flashes bright amber and fades (450 ms).
--   "normal" : dark, gold-dark frame with a lit top edge; hover = warmer, frame lighter, 4 % bigger
--   "quiet"  : text only (amber), hover = cream
-- Press (normal / quiet): the label sinks 1 px and the fill darkens.

function W.Button(parent, text, onClick, kind, width, height)
    kind = kind or "normal"
    height = height or 30
    local b = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    b:SetDimensions(width or 120, height)
    b:SetMouseEnabled(true)
    b.kind = kind
    b.hoverP = 0
    -- what the label / logo sit on: the plate's body (it lifts and drops), else the button
    local holder = b
    if kind == "plate" then
        -- the shadow stays on the ground; everything else is in the body that lifts
        b.shadow = W.Tex(b, B.TEX .. "plate_fill.dds", (width or 120) * 0.86, 7, C.slot, 0)
        b.shadow:SetAnchor(CENTER, b, BOTTOM, 0, 1)
        b.body = WINDOW_MANAGER:CreateControl(nil, b, CT_CONTROL)
        Anim.Anchor(b.body, TOPLEFT, b, TOPLEFT, 0, 0)
        Anim.Anchor2(b.body, BOTTOMRIGHT, b, BOTTOMRIGHT, 0, 0)
        holder = b.body
        b.fill = W.Tex(b.body, B.TEX .. "plate_fill.dds")
        b.fill:SetAnchorFill(b.body)
        b.flash = W.Tex(b.body, B.TEX .. "plate_fill.dds")
        b.flash:SetAnchorFill(b.body)
        if b.flash.SetBlendMode then b.flash:SetBlendMode(TEX_BLEND_MODE_ADD) end
        b.flash:SetColor(1, 0.82, 0.48, 0)
        b.flash:SetDrawLevel(2)
        b.edge = W.Tex(b.body, B.TEX .. "plate_edge.dds")
        b.edge:SetAnchorFill(b.body)
        b.edge:SetDrawLevel(3)
        b.pressY = 0
        -- (no logo by default: only Wear and Save build show it, via b:AddLogo())
    elseif kind == "normal" then
        b.fill = W.Tex(b)
        b.fill:SetAnchorFill(b)
        b.frame = W.Frame(b)
        b.light = W.TopLight(b, 4, 0.3)
    end
    b.label = W.Label(holder, B.Font(kind == "quiet" and "bold" or "head", kind == "plate" and 16 or 14), C.text, text, TEXT_ALIGN_CENTER)
    Anim.Anchor(b.label, CENTER, holder, CENTER, 0, 0)
    b.label:SetDrawLevel(4)
    -- the logo at the left end of a plate (only Wear and Save build, user's choice); the text
    -- then moves into the room right of it (logo ends at height + 4, the pointed end ~16 px),
    -- else long texts ran into the logo
    function b:AddLogo()
        if self.gem then return end
        self.gem = W.Tex(holder, B.LOGO, height - 12, height - 12)
        self.gem:SetAnchor(LEFT, holder, LEFT, 16, 0)
        self.gem:SetDrawLevel(4)
        Anim.Anchor(self.label, CENTER, holder, CENTER, math.floor((height - 6) / 2), 0)
    end
    -- a soft light behind it on hover (not for text-only buttons)
    if kind ~= "quiet" then
        b.glow = W.Glow(b, (width or 120) * 1.2, height * 2, kind == "plate" and C.theme or C.glow, 0)
        b.glow:SetAnchor(CENTER, b, CENTER, 0, 0)
        b.glow:SetDrawLevel(1)
    end

    local function Paint()
        local p = b.hoverP
        b:SetAlpha(b.disabled and 0.4 or 1)
        if b.glow then b.glow:SetAlpha(0.22 * p) end
        if kind == "plate" then
            -- hover: lifts 3 px, its shadow shows; pressed: down flat (pressY 0..4), no shadow
            local down = b.pressY / 4
            Anim.Offset(b.body, 0, -3 * p + b.pressY)
            b.shadow:SetAlpha(0.6 * p * (1 - down))
            b.fill:SetColor(B.RGBA(C.theme, Anim.Lerp(0.16, 0.30, p) * (1 + 0.4 * down)))
            b.edge:SetColor(B.RGBA(C.theme, Anim.Lerp(0.85, 1, p)))
            b.label:SetColor(B.RGBA(C.text))
            return   -- (no size change: the lift is the hover)
        end
        -- normal / quiet: hover grows a tiny bit (4 %), a soft light comes up behind it
        b:SetScale(1 + 0.04 * p)
        if kind == "normal" then
            local c = b.pressed and C.slot or C.hover
            b.fill:SetColor(c.r, c.g, c.b, Anim.Lerp(0.85, 1, p))
            b.frame:SetFrameColor(p > 0.5 and C.gold or C.goldDark, Anim.Lerp(0.8, 1, p))
            b.label:SetColor(Anim.Lerp(C.soft.r, C.text.r, p), Anim.Lerp(C.soft.g, C.text.g, p), Anim.Lerp(C.soft.b, C.text.b, p), 1)
        else
            b.label:SetColor(Anim.Lerp(C.theme.r, C.text.r, p), Anim.Lerp(C.theme.g, C.text.g, p), Anim.Lerp(C.theme.b, C.text.b, p), 1)
        end
    end
    b.Paint = Paint
    local key = W.Name("Btn")
    local function Hover(on)
        local from = b.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            b.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint()
        end)
    end
    Paint()
    -- plate click: back up from pressed (220 ms) and the amber flash fades (450 ms)
    local function Release(flash)
        local from = b.pressY
        Anim.Run(key .. "P", 220, Anim.Out, function(p)
            b.pressY = Anim.Lerp(from, 0, p)
            Paint()
        end)
        if flash then
            Anim.Run(key .. "F", 450, Anim.Out, function(p) b.flash:SetAlpha(0.8 * (1 - p)) end,
                function() b.flash:SetAlpha(0) end, 0, true)
        end
    end
    b:SetHandler("OnMouseEnter", function()
        if b.disabled then return end
        Hover(true)
        if b.tooltip then
            InitializeTooltip(InformationTooltip, b, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, type(b.tooltip) == "function" and b.tooltip() or b.tooltip)
        end
    end)
    b:SetHandler("OnMouseExit", function()
        Hover(false)
        b.pressed = false
        if kind == "plate" then
            if b.pressY > 0 then Release(false) end
        else
            Anim.Offset(b.label, 0, 0)
        end
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or b.disabled then return end
        b.pressed = true
        if kind == "plate" then
            Anim.Stop(key .. "P")
            b.pressY = 4   -- down flat (from 3 px up to 1 px below rest)
        else
            Anim.Offset(b.label, 0, 1)
        end
        Paint()
    end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        b.pressed = false
        if kind == "plate" then
            Release(upInside and not b.disabled)
        else
            Anim.Offset(b.label, 0, 0)
        end
        Paint()
        if upInside and not b.disabled then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            onClick(b)
        end
    end)
    function b:SetText(t) self.label:SetText(t) end
    function b:SetDisabled(off)
        self.disabled = off
        Paint()
    end
    function b:FitWidth(pad)
        self:SetWidth(self.label:GetTextWidth() + (pad or 30))
    end
    return b
end

-- Round glass button (close, minimize): dark disc, gilded rim, a gloss on the top half,
-- a crisp glyph (x.dds / minus.dds / restore.dds). Hover: rim lights up, a warm glow,
-- grows 8 %; press: shrinks a little.
function W.GlassButton(parent, glyph, onClick, size, tooltip)
    size = size or 26
    local b = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    b:SetDimensions(size, size)
    b:SetMouseEnabled(true)
    b.glow = W.Glow(b, size * 2.2, size * 2.2, C.glow, 0)
    b.glow:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.disc = W.Tex(b, B.TEX .. "disc.dds", size, size, C.card, 0.95)
    b.disc:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.gloss = W.Tex(b, B.TEX .. "gloss.dds", size, size, C.text, 0.22)
    b.gloss:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.gloss:SetDrawLevel(2)
    b.rim = W.Tex(b, B.TEX .. "ring.dds", size, size, C.goldDark)
    b.rim:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.rim:SetDrawLevel(3)
    b.glyph = W.Tex(b, B.TEX .. glyph, size, size, C.soft)
    b.glyph:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.glyph:SetDrawLevel(4)
    b.hoverP = 0
    local key = W.Name("Glass")
    local function Paint()
        local p = b.hoverP
        b:SetScale((1 + 0.08 * p) * (b.pressed and 0.92 or 1))
        b.glow:SetAlpha(0.3 * p)
        b.rim:SetColor(Anim.Lerp(C.goldDark.r, C.gold.r, p), Anim.Lerp(C.goldDark.g, C.gold.g, p), Anim.Lerp(C.goldDark.b, C.gold.b, p), 1)
        b.glyph:SetColor(Anim.Lerp(C.soft.r, C.text.r, p), Anim.Lerp(C.soft.g, C.text.g, p), Anim.Lerp(C.soft.b, C.text.b, p), 1)
        b.gloss:SetAlpha(0.22 + 0.15 * p)
    end
    local function Hover(on)
        local from = b.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            b.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint()
        end)
    end
    Paint()
    b:SetHandler("OnMouseEnter", function()
        Hover(true)
        local t = type(tooltip) == "function" and tooltip() or tooltip
        if t then
            InitializeTooltip(InformationTooltip, b, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, t)
        end
    end)
    b:SetHandler("OnMouseExit", function()
        b.pressed = false
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            b.pressed = true
            Paint()
        end
    end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        b.pressed = false
        Paint()
        if upInside then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            onClick(b)
        end
    end)
    function b:SetGlyph(file) self.glyph:SetTexture(B.TEX .. file) end
    return b
end

-- Window corners, sketch 4 (picked 2026-10-01, replaced the corner.dds filigree): a heavy
-- outer L in pewter right at each corner and a thin inner L a little further in.
function W.Brackets(win, outer, inner)
    outer, inner = outer or 3, inner or 10
    local CORNERS = {
        { TOPLEFT, 1, 1 }, { TOPRIGHT, -1, 1 }, { BOTTOMLEFT, 1, -1 }, { BOTTOMRIGHT, -1, -1 },
    }
    local function L(point, sx, sy, inset, len, thick, alpha)
        local h = W.Tex(win, nil, len, thick, C.gold, alpha)
        h:SetAnchor(point, win, point, sx * inset, sy * inset)
        h:SetDrawLevel(4)
        local v = W.Tex(win, nil, thick, len, C.gold, alpha)
        v:SetAnchor(point, win, point, sx * inset, sy * inset)
        v:SetDrawLevel(4)
    end
    for _, c in ipairs(CORNERS) do
        L(c[1], c[2], c[3], outer, 34, 2, 0.9)
        L(c[1], c[2], c[3], inner, 16, 1, 0.45)
    end
end

-- Close button, sketch A (picked 2026-10-01, replaced the round glass button): a bare X in
-- the amber accent. Hover: turns a quarter round, grows 15 %, goes lighter, a soft amber
-- light comes up; press: shrinks a little.
function W.CloseButton(parent, onClick, size, tooltip)
    size = size or 26
    local b = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    b:SetDimensions(size, size)
    b:SetMouseEnabled(true)
    b.glow = W.Glow(b, size * 2, size * 2, C.theme, 0)
    b.glow:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.x = W.Tex(b, B.TEX .. "x.dds", size, size, C.theme)
    b.x:SetAnchor(CENTER, b, CENTER, 0, 0)
    b.x:SetDrawLevel(4)
    b.hoverP = 0
    local key = W.Name("Close")
    local function Paint()
        local p = b.hoverP
        b.x:SetScale((1 + 0.15 * p) * (b.pressed and 0.88 or 1))
        b.x:SetTextureRotation(p * math.pi / 2, 0.5, 0.5)
        b.x:SetColor(Anim.Lerp(C.theme.r, 1, p * 0.45), Anim.Lerp(C.theme.g, 1, p * 0.45), Anim.Lerp(C.theme.b, 1, p * 0.45), 1)
        b.glow:SetAlpha(0.3 * p)
    end
    local function Hover(on)
        local from = b.hoverP
        Anim.Run(key, Anim.STD, Anim.Out, function(p)
            b.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint()
        end)
    end
    Paint()
    b:SetHandler("OnMouseEnter", function()
        Hover(true)
        if tooltip then
            InitializeTooltip(InformationTooltip, b, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, tooltip)
        end
    end)
    b:SetHandler("OnMouseExit", function()
        b.pressed = false
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            b.pressed = true
            Paint()
        end
    end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        b.pressed = false
        Paint()
        if upInside then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            onClick(b)
        end
    end)
    return b
end

-- Compact toggle switch with a label on its left (same look as the save window's):
-- pill track dark -> amber, cream knob glides across (220 ms), hover lights it.
-- getter() -> bool, setter(bool). sw:Refresh() repaints from getter.
function W.Switch(parent, text, getter, setter, tooltip)
    local s = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    s:SetHeight(24)
    s:SetMouseEnabled(true)
    s.label = W.Label(s, B.Font("text", 13), C.soft, text or "")
    s.label:SetAnchor(LEFT, s, LEFT, 0, 0)
    s.track = W.Tex(s, B.TEX .. "pill.dds", 34, 18)
    s.edge = W.Tex(s, B.TEX .. "pill_edge.dds", 34, 18)
    s.edge:SetDrawLevel(2)
    s.knob = W.Tex(s, B.TEX .. "disc.dds", 12, 12)
    s.knob:SetDrawLevel(3)
    local function Place()
        local lw = (text and text ~= "") and (s.label:GetTextWidth() > 5 and s.label:GetTextWidth() or #text * 7) + 8 or 0
        s.track:ClearAnchors()
        s.track:SetAnchor(LEFT, s, LEFT, lw, 0)
        s.edge:ClearAnchors()
        s.edge:SetAnchor(CENTER, s.track, CENTER, 0, 0)
        Anim.Anchor(s.knob, LEFT, s.track, LEFT, 3, 0)
        s:SetWidth(lw + 34)
    end
    Place()
    s.hoverP, s.onP = 0, getter() and 1 or 0
    local key = W.Name("Sw")
    local function Paint()
        local p, on = s.hoverP, s.onP
        s.track:SetColor(Anim.Lerp(C.slot.r, C.theme.r * 0.55, on), Anim.Lerp(C.slot.g, C.theme.g * 0.55, on), Anim.Lerp(C.slot.b, C.theme.b * 0.55, on), 1)
        local edge = on > 0.5 and C.theme or (p > 0.5 and C.gold or C.goldDark)
        s.edge:SetColor(B.RGBA(edge, 1))
        Anim.Offset(s.knob, 16 * on, 0)
        s.knob:SetColor(Anim.Lerp(C.dim.r, C.text.r, on), Anim.Lerp(C.dim.g, C.text.g, on), Anim.Lerp(C.dim.b, C.text.b, on), 1)
        s.knob:SetScale(1 + 0.12 * p)
        local lc = (on > 0.5 or p > 0.5) and C.text or C.soft
        s.label:SetColor(B.RGBA(lc))
    end
    local function To(on, animate)
        local from, to = s.onP, on and 1 or 0
        if not animate then
            Anim.Stop(key .. "T")
            s.onP = to
            Paint()
            return
        end
        Anim.Run(key .. "T", Anim.STD, Anim.Out, function(p)
            s.onP = Anim.Lerp(from, to, p)
            Paint()
        end)
    end
    s:SetHandler("OnMouseEnter", function()
        local from = s.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p) s.hoverP = Anim.Lerp(from, 1, p) Paint() end)
        local t = type(tooltip) == "function" and tooltip() or tooltip
        if t and t ~= "" then
            InitializeTooltip(InformationTooltip, s, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, t)
        end
    end)
    s:SetHandler("OnMouseExit", function()
        local from = s.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p) s.hoverP = Anim.Lerp(from, 0, p) Paint() end)
        ClearTooltip(InformationTooltip)
    end)
    s:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        local v = not getter()
        setter(v)
        To(v, true)
    end)
    function s:Refresh() To(getter() and true or false, false) end
    function s:SetText(t)
        text = t
        self.label:SetText(t)
        Place()
    end
    Paint()
    return s
end

-- Slider (2026-10-03, Gear check thresholds): a thin dark track, the amber fill up to the knob,
-- a cream knob in an amber ring, the value on the right ("60 %"). Drag it, click on the track,
-- or turn the mouse wheel over it. Hover: the knob grows a little and a soft light comes up.
-- getter() -> number, setter(number) (while dragging), format(v) -> text; s.onDone(v) after a
-- drag / wheel turn. s:Refresh(), s:SetDisabled(bool).
function W.Slider(parent, width, min, max, step, getter, setter, format, tooltip)
    local s = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    local trackW = width - 60
    s:SetDimensions(width, 24)
    s:SetMouseEnabled(true)
    s.track = W.Tex(s, nil, trackW, 4, C.slot)
    s.track:SetAnchor(LEFT, s, LEFT, 8, 0)
    W.Frame(s.track, C.goldDark, 1)
    s.fill = W.Tex(s, nil, 1, 4, C.theme, 0.85)
    s.fill:SetAnchor(LEFT, s.track, LEFT, 0, 0)
    s.fill:SetDrawLevel(4)
    s.glow = W.Glow(s, 30, 30, C.theme, 0)
    s.glow:SetDrawLevel(5)
    s.knob = W.Tex(s, B.TEX .. "disc.dds", 12, 12, C.text)
    s.knob:SetDrawLevel(6)
    s.ring = W.Tex(s, B.TEX .. "ring.dds", 16, 16, C.theme)
    s.ring:SetDrawLevel(7)
    s.value = W.Label(s, B.Font("bold", 13), C.text, "", TEXT_ALIGN_RIGHT)
    s.value:SetAnchor(RIGHT, s, RIGHT, 0, 0)
    s.value:SetWidth(46)
    s.hoverP = 0
    local function Snap(v)
        v = zo_clamp(v, min, max)
        return min + zo_round((v - min) / step) * step
    end
    local function Paint(v)
        local x = trackW * zo_clamp((v - min) / (max - min), 0, 1)
        s.fill:SetWidth(math.max(1, x))
        s.knob:ClearAnchors()
        s.knob:SetAnchor(CENTER, s.track, LEFT, x, 0)
        s.ring:ClearAnchors()
        s.ring:SetAnchor(CENTER, s.knob, CENTER, 0, 0)
        s.glow:ClearAnchors()
        s.glow:SetAnchor(CENTER, s.knob, CENTER, 0, 0)
        s.value:SetText(format and format(v) or tostring(v))
        local p = s.dragging and 1 or s.hoverP
        s.knob:SetScale(1 + 0.18 * p)
        s.ring:SetScale(1 + 0.18 * p)
        s.glow:SetAlpha(0.35 * p)
    end
    local function FromMouse()
        local mx = GetUIMousePosition()
        return Snap(min + (mx - s.track:GetLeft()) / trackW * (max - min))
    end
    local function Set(v)
        v = Snap(v)
        if v ~= getter() then setter(v) end
        Paint(v)
    end
    local key = W.Name("Slider")
    local function Hover(on)
        local from = s.hoverP
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            s.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint(getter())
        end)
    end
    s:SetHandler("OnMouseEnter", function()
        if s.disabled then return end
        Hover(true)
        local t = type(tooltip) == "function" and tooltip() or tooltip
        if t and t ~= "" then
            InitializeTooltip(InformationTooltip, s, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, t)
        end
    end)
    s:SetHandler("OnMouseExit", function()
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    s:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or s.disabled then return end
        s.dragging = true
        Set(FromMouse())
        s:SetHandler("OnUpdate", B.Safe(function() if s.dragging then Set(FromMouse()) end end, "slider"))
    end)
    s:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not s.dragging then return end
        s.dragging = false
        s:SetHandler("OnUpdate", nil)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        Paint(getter())
        if s.onDone then s.onDone(getter()) end
    end)
    s:SetHandler("OnMouseWheel", function(_, delta)
        if s.disabled then return end
        Set(getter() + (delta > 0 and step or -step))
        if s.onDone then s.onDone(getter()) end
    end)
    function s:Refresh() Paint(getter()) end
    function s:SetDisabled(off)
        self.disabled = off
        self:SetAlpha(off and 0.4 or 1)
    end
    Paint(getter())
    return s
end

-- A movable window stays where you left it (also after a restart): sv.places[key] = { x, y
-- [, w, h] }. Puts the window there now (true) or leaves the caller's spot (false). Returns
-- that and a Save function; it sets OnMoveStop (and OnResizeStop when resizable) itself unless
-- noHandlers (then call Save from your own handlers).
function W.RememberPlace(win, key, resizable, noHandlers)
    local function Save()
        B.sv.places = B.sv.places or {}
        local p = { x = win:GetLeft(), y = win:GetTop() }
        if resizable then p.w, p.h = win:GetWidth(), win:GetHeight() end
        B.sv.places[key] = p
        Anim.Anchor(win, TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
    end
    if not noHandlers then
        win:SetHandler("OnMoveStop", Save)
        if resizable then win:SetHandler("OnResizeStop", Save) end
    end
    local function Restore()
        local p = B.sv.places and B.sv.places[key]
        if not (p and p.x and p.y) then return false end
        if resizable and p.w and p.h then win:SetDimensions(p.w, p.h) end
        Anim.Anchor(win, TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
        return true
    end
    return Restore(), Save, Restore
end

-- Build picker (replaces the game's white dropdown): a dark framed button with the build's
-- picture and name and a small chevron; click = a menu of all builds with their pictures.
-- getter() -> build id, setter(id). picker:Refresh().
function W.BuildPicker(parent, width, getter, setter, noneText)
    local p = W.Button(parent, "", function(self)
        ClearMenu()
        if noneText then AddMenuItem(noneText, function() setter(nil) self:Refresh() end) end
        for _, b in ipairs(B.SortedBuilds()) do
            AddMenuItem(zo_iconTextFormat(B.UI.BuildIcon(b), 20, 20, b.name), function()
                setter(b.id)
                self:Refresh()
            end)
        end
        ShowMenu(self)
    end, "normal", width or 210, 28)
    p.label:SetFont(B.Font("name", 12))
    p.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    p.icon = W.Tex(p, nil, 20, 20)
    p.icon:SetAnchor(LEFT, p, LEFT, 5, 0)
    p.icon:SetDrawLevel(3)
    Anim.Anchor(p.label, LEFT, p, LEFT, 32, 0)
    p.label:SetWidth((width or 210) - 52)
    p.label:SetMaxLineCount(1)
    p.chev = W.Tex(p, B.TEX .. "chevron.dds", 12, 12, C.dim)
    p.chev:SetAnchor(RIGHT, p, RIGHT, -8, 0)
    p.chev:SetTextureRotation(-math.pi / 2, 0.5, 0.5)   -- pointing down
    p.chev:SetDrawLevel(3)
    function p:Refresh()
        local b = B.Get(getter())
        self.icon:SetHidden(b == nil)
        if b then self.icon:SetTexture(B.UI.BuildIcon(b)) end
        Anim.Anchor(self.label, LEFT, self, LEFT, b and 32 or 10, 0)
        self.label:SetText(b and b.name or (noneText or ""))
        self.label:SetColor(B.RGBA(b and C.text or C.dim))
    end
    return p
end

-- A panel drawn above its siblings (SetDrawLevel) takes the mouse over everything with a
-- lower level, its OWN children too (buttons and the checkbox in "what will change" did
-- nothing). Call this after building the panel: every control inside gets level + its own.
function W.RaiseAll(control, level)
    control:SetDrawLevel(level)
    local function Raise(c)
        for i = 1, c:GetNumChildren() do
            local child = c:GetChild(i)
            if child then
                child:SetDrawLevel(level + 1 + (child:GetDrawLevel() or 0))
                Raise(child)
            end
        end
    end
    Raise(control)
end

-- tooltip on any control (text or function returning text); anchor TOP = under it
function W.Tip(control, text, anchor)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(self)
        local t = type(text) == "function" and text() or text
        if t and t ~= "" then
            local below = anchor == TOP
            InitializeTooltip(InformationTooltip, self, below and TOP or BOTTOM, 0, below and 4 or -4, below and BOTTOM or TOP)
            SetTooltipText(InformationTooltip, t)
        end
    end)
    control:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

-- ESO's dropdown. Returns the container and the combo object.
function W.Combo(parent, width)
    local box = WINDOW_MANAGER:CreateControlFromVirtual(W.Name("Combo"), parent, "ZO_ComboBox")
    box:SetDimensions(width or 180, 26)
    local combo = ZO_ComboBox_ObjectFromContainer(box)
    combo:SetSortsItems(false)
    return box, combo
end

-- choices = { { text, value } }, onPick(value)
function W.FillCombo(combo, choices, selected, onPick)
    combo:ClearItems()
    local selectedText = choices[1] and choices[1].text or ""
    for _, c in ipairs(choices) do
        local value = c.value
        combo:AddItem(combo:CreateItemEntry(c.text, function()
            B.Later(function() onPick(value) end, 1)   -- after the dropdown finished its click
        end), ZO_COMBOBOX_SUPPRESS_UPDATE)
        if value == selected then selectedText = c.text end
    end
    combo:SetSelectedItemText(selectedText)
end

-- dark text field with a gold-dark frame; the edit box inside is ESO's own template
function W.Edit(parent, width, hint, multiLine)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetDimensions(width, multiLine and 90 or 28)
    box:SetMouseEnabled(true)
    local fill = W.Tex(box)
    fill:SetAnchorFill(box)
    fill:SetColor(B.RGBA(C.slot, 0.9))
    W.Frame(box, C.goldDark, 1)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(W.Name("Edit"), box,
        multiLine and "ZO_DefaultEditMultiLineForBackdrop" or "ZO_DefaultEditForBackdrop")
    if hint and edit.SetDefaultText then edit:SetDefaultText(hint) end
    box:SetHandler("OnMouseUp", function() edit:TakeFocus() end)
    return box, edit
end

-- ESO checkbox with a label; only the left mouse button toggles it
function W.Check(parent, text, getter, setter, tooltip)
    local cb = WINDOW_MANAGER:CreateControlFromVirtual(W.Name("Check"), parent, "ZO_CheckButton")
    ZO_CheckButton_SetLabelText(cb, text)
    if cb.EnableMouseButton then
        cb:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, false)
        cb:EnableMouseButton(MOUSE_BUTTON_INDEX_MIDDLE, false)
    end
    ZO_CheckButton_SetCheckState(cb, getter())
    ZO_CheckButton_SetToggleFunction(cb, function(_, checked) setter(checked) end)
    local label = cb.label or GetControl(cb, "Label")
    if label then
        label:SetFont(B.Font("text", 13))
        if tooltip then W.Tip(label, tooltip) end
    end
    function cb:Refresh() ZO_CheckButton_SetCheckState(self, getter()) end
    return cb
end

-- simple text dialog with an edit box (rename, new build name, boss name)
function W.AskText(title, text, initial, onOk)
    ESO_Dialogs["SKILLBOUND_TEXT"] = ESO_Dialogs["SKILLBOUND_TEXT"] or {
        title = { text = "" },
        mainText = { text = "" },
        editBox = {},
        buttons = {
            { text = SI_DIALOG_CONFIRM, callback = function(dialog)
                local value = zo_strtrim(ZO_Dialogs_GetEditBoxText(dialog) or "")
                if value ~= "" and dialog.data and dialog.data.onOk then dialog.data.onOk(value) end
            end },
            { text = SI_DIALOG_CANCEL },
        },
    }
    local d = ESO_Dialogs["SKILLBOUND_TEXT"]
    d.title.text = title
    d.mainText.text = text
    ZO_Dialogs_ShowDialog("SKILLBOUND_TEXT", { onOk = onOk }, { initialEditText = initial or "" })
end

function W.Confirm(title, text, onYes)
    ESO_Dialogs["SKILLBOUND_CONFIRM"] = ESO_Dialogs["SKILLBOUND_CONFIRM"] or {
        title = { text = "" },
        mainText = { text = "" },
        buttons = {
            { text = SI_DIALOG_CONFIRM, callback = function(dialog)
                if dialog.data and dialog.data.onYes then dialog.data.onYes() end
            end },
            { text = SI_DIALOG_CANCEL },
        },
    }
    local d = ESO_Dialogs["SKILLBOUND_CONFIRM"]
    d.title.text = title
    d.mainText.text = text
    ZO_Dialogs_ShowDialog("SKILLBOUND_CONFIRM", { onYes = onYes })
end
