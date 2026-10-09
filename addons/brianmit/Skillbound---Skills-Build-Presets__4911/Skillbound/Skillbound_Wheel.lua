-- Skillbound_Wheel.lua : quick wheel with your favorite builds (up to 10), like the
-- game's emote / quickslot wheels.
--   Hold the keybind, move the mouse toward a build, let go = wear it.
--   Tap the keybind = the wheel stays open: click a build (or the middle / Escape to close).
-- The mouse cursor is needed to point, so the wheel turns on the game's UI mode while
-- it's open and turns it off again afterwards.

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Wheel = {}
B.Wheel = Wheel

local SIZE = 300
local RADIUS = 106
local ICON = 44
local N = B.MAX_FAV      -- spots round the wheel (wedge.dds is one 36 degree piece = 1/10)
local STEP = 2 * math.pi / N
local DEAD = 34          -- pointer closer to the middle than this = nothing picked
local TAP = 0.25         -- shorter key press = keep the wheel open

local ui = { slots = {} }
local state              -- { list, opened, enteredUI, sticky, hover }

local function Angle(i) return (i - 1) * STEP end

local function Hovered()
    local cx, cy = ui.win:GetCenter()
    local mx, my = GetUIMousePosition()
    local dx, dy = mx - cx, my - cy
    if dx * dx + dy * dy < DEAD * DEAD then return nil end
    local a = math.atan2(dx, -dy)              -- 0 = up, clockwise
    if a < 0 then a = a + 2 * math.pi end
    local i = math.floor((a + STEP / 2) / STEP) % N + 1
    if state and state.list[i] then return i end
    return nil
end

-- the highlight turns to the pointed build (shortest way round, 120 ms); slots grow on hover
local function TurnWedge(i)
    local to = Angle(i)
    local from = ui.wedgeAngle or to
    local diff = (to - from + math.pi) % (2 * math.pi) - math.pi
    ui.wedgeAngle = to
    Anim.Run("Skillbound_Wedge", Anim.MICRO, Anim.InOut, function(p)
        ui.wedge:SetTextureRotation(-(from + diff * p), 0.5, 0.5)
    end)
end

local function Grow(s, on)
    local from = s.grow or 0
    Anim.Run(s.key, Anim.MICRO, Anim.Out, function(p)
        s.grow = Anim.Lerp(from, on and 1 or 0, p)
        s:SetScale(1 + 0.14 * s.grow)
        s.light:SetAlpha(0.35 * s.grow)
    end)
end

local function Paint()
    local i = Hovered()
    local changed = i ~= state.hover
    state.hover = i
    for n, s in ipairs(ui.slots) do
        local b = state.list[n]
        s:SetHidden(b == nil)
        if b then
            s.icon:SetTexture(B.UI.BuildIcon(b))
            local on = n == i
            s.ring:SetColor(B.RGBA(on and C.theme or C.goldDark, 1))
            if changed then Grow(s, on) end
        end
    end
    ui.wedge:SetHidden(i == nil)
    if i and changed then TurnWedge(i) end
    local b = i and state.list[i]
    local worn = B.WornBuild()
    if b then
        ui.center:SetText(b.name)
        ui.center:SetColor(B.RGBA(C.text))
    else
        ui.center:SetText(worn and L("WHEEL_WEARING", worn.name) or L("WHEEL_PICK"))
        ui.center:SetColor(B.RGBA(C.dim))
    end
end

-- closing: fades and shrinks a little (120 ms)
local function Close()
    if not state then return end
    local entered = state.enteredUI
    state = nil
    ui.win:SetHandler("OnUpdate", nil)
    if entered and IsGameCameraUIModeActive() then SCENE_MANAGER:SetInUIMode(false) end
    Anim.Run("Skillbound_WheelOpen", Anim.MICRO, Anim.In, function(p)
        ui.win:SetAlpha(1 - p)
        ui.win:SetScale(Anim.Lerp(1, 0.94, p))
    end, function()
        ui.win:SetHidden(true)
        ui.win:SetAlpha(1)
        ui.win:SetScale(1)
    end)
end

local function Pick(i)
    local b = state and i and state.list[i]
    Close()
    if b then
        PlaySound(SOUNDS.DEFAULT_CLICK)   -- (same click as the button's favorites)
        B.Apply.Wear(b)
    end
end

local function Create()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Wheel")
    ui.win = win
    win:SetDimensions(SIZE, SIZE)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetDrawTier(DT_HIGH)
    local bg = W.Tex(win, B.TEX .. "disc.dds", SIZE, SIZE, C.panel, 0.88)
    bg:SetAnchor(CENTER, win, CENTER, 0, 0)
    local warm = W.Glow(win, SIZE * 0.9, SIZE * 0.9, C.glow, 0.12)
    warm:SetAnchor(CENTER, win, CENTER, 0, 30)
    local ring = W.Tex(win, B.TEX .. "ring.dds", SIZE, SIZE, C.gold, 0.85)
    ring:SetAnchor(CENTER, win, CENTER, 0, 0)
    ui.wedge = W.Tex(win, B.TEX .. "wedge.dds", SIZE - 6, SIZE - 6, C.theme, 0.28)
    ui.wedge:SetAnchor(CENTER, win, CENTER, 0, 0)
    local inner = W.Tex(win, B.TEX .. "disc.dds", 120, 120, C.card, 0.97)
    inner:SetAnchor(CENTER, win, CENTER, 0, 0)
    local innerRing = W.Tex(win, B.TEX .. "ring.dds", 120, 120, C.goldDark)
    innerRing:SetAnchor(CENTER, win, CENTER, 0, 0)
    local icon = W.Tex(win, B.LOGO, 34, 34)
    icon:SetAnchor(CENTER, win, CENTER, 0, -22)
    ui.center = W.Label(win, B.Font("title", 14), C.text, "", TEXT_ALIGN_CENTER)
    ui.center:SetAnchor(CENTER, win, CENTER, 0, 12)
    ui.center:SetWidth(108)
    ui.center:SetMaxLineCount(2)
    for i = 1, N do
        local s = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
        s:SetDimensions(ICON, ICON)
        local a = Angle(i)
        s:SetAnchor(CENTER, win, CENTER, math.sin(a) * RADIUS, -math.cos(a) * RADIUS)
        s.bg = W.Tex(s, B.TEX .. "disc.dds", ICON, ICON, C.slot)
        s.bg:SetAnchor(CENTER, s, CENTER, 0, 0)
        s.icon = W.Tex(s, nil, ICON - 12, ICON - 12)
        s.icon:SetAnchor(CENTER, s, CENTER, 0, 0)
        s.ring = W.Tex(s, B.TEX .. "ring.dds", ICON, ICON, C.goldDark)
        s.ring:SetAnchor(CENTER, s, CENTER, 0, 0)
        s.light = W.Glow(s, ICON * 1.9, ICON * 1.9, C.glow, 0)
        s.light:SetAnchor(CENTER, s, CENTER, 0, 0)
        s.key = "Skillbound_WheelSlot" .. i
        ui.slots[i] = s
    end
    win:SetHandler("OnMouseUp", function(_, button, upInside)
        if not state or not upInside then return end
        if button == MOUSE_BUTTON_INDEX_LEFT then Pick(Hovered()) else Close() end
    end)
end

-- keybind pressed
function Wheel.Down()
    if state then return end
    if not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()) then return end
    local list = {}
    for _, id in ipairs(B.Char().fav) do
        local b = B.Get(id)
        if b and #list < N then list[#list + 1] = b end
    end
    if #list == 0 then
        B.Print(L("WHEEL_EMPTY"))
        return
    end
    if not ui.win then Create() end
    state = { list = list, opened = GetFrameTimeSeconds(), enteredUI = not IsGameCameraUIModeActive() }
    if state.enteredUI then SCENE_MANAGER:SetInUIMode(true) end
    for _, s in ipairs(ui.slots) do
        s.grow = 0
        s:SetScale(1)
        s.light:SetAlpha(0)
    end
    ui.wedgeAngle = nil
    ui.win:SetHidden(false)
    -- opening: grows from 90 % while it fades in (160 ms)
    Anim.Run("Skillbound_WheelOpen", 160, Anim.Out, function(p)
        ui.win:SetAlpha(p)
        ui.win:SetScale(Anim.Lerp(0.9, 1, p))
    end)
    ui.win:SetHandler("OnUpdate", B.Safe(function()
        if not state then return end
        -- Escape (or the game) left UI mode: close
        if state.sticky and not IsGameCameraUIModeActive() then
            Close()
            return
        end
        Paint()
    end, "quick wheel"))
    Paint()
end

-- keybind released
function Wheel.Up()
    if not state or state.sticky then return end
    local i = Hovered()
    if not i and GetFrameTimeSeconds() - state.opened < TAP then
        state.sticky = true
        return
    end
    Pick(i)
end

function Wheel.Init() end
