-- On-screen displays. One window per tracker; its entries (bars, icons, text lines, or a big
-- alert) are pooled per display and reused by state key, so an entry that persists between ticks
-- keeps its control (no flicker, no churn). Fill/sweep/pulse animate every frame from the state's
-- times; labels refresh at most every 0.1s.

local DT = DebuffTracker
local D = DT.Displays
local U = DT.Util
local C = DT.Const
local Style = DT.Style
local WM = WINDOW_MANAGER

local displays = {}     -- [trackerId] = display
local spare = {}        -- released display objects, reused for new trackers
local counter = 0
D.extraScenes = {}      -- scenes (besides the HUD) the displays also show in: the editor

local Display = {}
Display.__index = Display
-- display types with no window of their own: their entries are placed on other things (allies' heads, group frames)
D.NO_WINDOW = { heads = true, onframes = true }

------------------------------------------------------------------------------
-- Small control helpers
------------------------------------------------------------------------------

local function Backdrop(parent, center, edge, edgeSize, level)
    local b = WM:CreateControl(nil, parent, CT_BACKDROP)
    b:SetCenterColor(center[1], center[2], center[3], center[4])
    b:SetEdgeColor(edge[1], edge[2], edge[3], edge[4])
    -- SetEdgeTexture(file, fileWidth, fileHeight, edgeSize): the file size must be a power of two above
    -- zero even without a file; the 4th argument is the border's thickness
    b:SetEdgeTexture(nil, 1, 1, math.max(1, edgeSize or 1))
    if level then b:SetDrawLevel(level) end
    return b
end

local function Label(parent, level, align)
    local l = WM:CreateControl(nil, parent, CT_LABEL)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    l:SetMaxLineCount(1)
    if level then l:SetDrawLevel(level) end
    return l
end

local NONE = { 0, 0, 0, 0 }
-- colours used as fallbacks every update (constants, not a new table each time)
local WHITE, BLACK, ICON_BG = { 1, 1, 1, 1 }, { 0, 0, 0, 1 }, { 0, 0, 0, 0.6 }
local SetCard, GROUP_ICON     -- proc cards (icons), defined with the icons below
local FitBigNumber

-- "Proc highlight" rule: the game's animated action-bar proc glow around an icon (or a bar row).
local PROC_TEXTURE = "/esoui/art/actionbar/abilityhighlight_mage_med.dds"
-- text colours: rule > separate timer/stack colour (if enabled) > text colour
local function TextColors(ds, look)
    local tc = (look and look.textColor) or ds.textColor
    local timer = (look and look.timerColor) or (ds.separateTextColors and ds.timerColor) or tc
    local stack = (look and look.stackColor) or (ds.separateTextColors and ds.stackColor) or tc
    return tc, timer, stack
end
D.TextColors = TextColors

-- The number on a running ability timer: time left of the part it's in (active, then cooldown), or with
-- "Timer counts down to: ready" the time until it can happen again, also while its buff is up (Tony)
local function TimeLeft(ds, s, now)
    if ds.timerTo == "ready" and (s.phase == 1 or s.cycleWhole) and (s.cdEnd or 0) > (s.expire or 0) then return s.cdEnd - now end
    return s.expire - now
end
D.TimeLeft = TimeLeft

local function SetProc(it, around, on)
    if not on then
        if it.procTex and not it.procTex:IsHidden() then
            it.procTex:SetHidden(true)
            if it.procAnim then it.procAnim:Stop() end
        end
        return
    end
    if not it.procTex then
        local t = WM:CreateControl(nil, it.control, CT_TEXTURE)
        t:SetTexture(PROC_TEXTURE)
        t:SetDrawLevel(8)
        t:SetHidden(true)
        it.procTex = t
        if ANIMATION_MANAGER and ANIMATION_TEXTURE then
            local timeline = ANIMATION_MANAGER:CreateTimeline()
            local anim = timeline:InsertAnimation(ANIMATION_TEXTURE, t)
            anim:SetImageData(64, 1)
            anim:SetFramerate(64)
            timeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
            it.procAnim = timeline
        end
    end
    local t = it.procTex
    if it.procAround ~= around then
        it.procAround = around
        t:ClearAnchors()
        t:SetAnchor(TOPLEFT, around, TOPLEFT, -4, -4)
        t:SetAnchor(BOTTOMRIGHT, around, BOTTOMRIGHT, 4, 4)
    end
    if t:IsHidden() then
        t:SetHidden(false)
        if it.procAnim then it.procAnim:PlayFromStart() end
    end
end
D.SetProc = SetProc

local function GrowPoint(grow)
    if grow == "up" then return BOTTOMLEFT end
    if grow == "left" then return TOPRIGHT end
    return TOPLEFT
end

------------------------------------------------------------------------------
-- Item types
------------------------------------------------------------------------------

local Items = {}

-- Bars ---------------------------------------------------------------------

Items.bars = {}

function Items.bars.Create(display)
    local row = WM:CreateControl(nil, display.content, CT_CONTROL)
    local it = { control = row, type = "bars" }
    it.track = Backdrop(row, { 0, 0, 0, 0.4 }, { 0, 0, 0, 0.75 }, 1, 1)
    it.track:SetAnchorFill()
    it.icon = WM:CreateControl(nil, row, CT_TEXTURE)
    it.icon:SetDrawLevel(2)
    it.bar = WM:CreateControl(nil, row, CT_STATUSBAR)
    it.bar:SetDrawLevel(2)
    it.bar:SetMinMax(0, 1)
    -- the end window (global cooldown: your ping) -- drawn over the bar where it runs out
    it.zone = WM:CreateControl(nil, row, CT_TEXTURE)
    it.zone:SetDrawLevel(3)
    it.zone:SetHidden(true)
    it.stack = Label(row, 4, TEXT_ALIGN_CENTER)
    it.time = Label(row, 4, TEXT_ALIGN_RIGHT)
    it.name = Label(row, 4, TEXT_ALIGN_LEFT)
    it.stripe = Backdrop(row, { 1, 0.88, 0.5, 1 }, { 0, 0, 0, 0.8 }, 1, 5)
    -- target highlight / glow border: drawn just OUTSIDE the row and on the overlay layer, so the
    -- bar fill (same rectangle as the row) can never paint over it
    it.edge = Backdrop(row, NONE, NONE, 1, 10)
    it.edge:SetAnchor(TOPLEFT, row, TOPLEFT, -1, -1)
    it.edge:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 1, 1)
    if DL_OVERLAY then it.edge:SetDrawLayer(DL_OVERLAY) end
    return it
end

function Items.bars.Configure(it, display)
    local ds, look = display.ds, display.look
    local h, w = ds.height, display.rowWidth
    it.control:SetDimensions(w, h)
    local font = Style.Font(ds, h)
    it.name:SetFont(font); it.time:SetFont(font); it.stack:SetFont(font)
    it.timeWidths, it.timeBoxW, it.lastTimeText = nil, nil, nil     -- new font: measure the timer again
    it.track:SetHidden(not look.track)
    if not it.customBg then
        local tc = ds.trackColor or { 0, 0, 0, 0.4 }
        it.track:SetCenterColor(tc[1], tc[2], tc[3], tc[4] or 1)
    end
    -- the track has no edge of its own (it drew a 1 px dark line inside the row that ignored Border
    -- thickness -- Tony); the row's outline is it.edge, see SetHighlight
    it.track:SetEdgeColor(0, 0, 0, 0)
    it.bar:SetTexture(ds.texture)
    it.bar:SetAlpha(ds.barAlpha)
    if it.bar.SetBarAlignment and BAR_ALIGNMENT_NORMAL then
        it.bar:SetBarAlignment(ds.fillReverse and BAR_ALIGNMENT_REVERSE or BAR_ALIGNMENT_NORMAL)
    end
    it.icon:SetHidden(not ds.showRowIcon)
    it.icon:ClearAnchors()
    it.bar:ClearAnchors()
    if it.bar2 then it.bar2:SetHidden(true) end
    it.centred, it.zoneSide, it.barCut = false, nil, 0
    it.hvKey = nil      -- shield / trauma pieces: laid out again (new size or colours)
    it.vertical = ds.vertical == true
    if ds.vertical then
        -- a column: icon at the bottom, the bar above it filling upward, timer on top
        local colW, colH = h, ds.width
        it.control:SetDimensions(colW, colH)
        local iconH = ds.showRowIcon and colW or 0
        it.icon:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, 0, 0)
        it.icon:SetDimensions(colW, colW)
        it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0)
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, -iconH)
        if it.bar.SetOrientation then it.bar:SetOrientation(ORIENTATION_VERTICAL) end
        local small = Style.Font(ds, colW, 0.5, 9, 16)
        it.time:SetFont(small); it.stack:SetFont(small)
        it.time:SetDimensions(colW + 16, 18)
        it.stack:SetDimensions(colW, 16)
        it.stripe:SetHidden(true)
        it.configured = display.configVersion
        it.lastLayoutKey = nil
        return
    end
    if it.bar.SetOrientation then it.bar:SetOrientation(ORIENTATION_HORIZONTAL) end
    local iconW = ds.showRowIcon and h or 0
    it.icon:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0)
    it.icon:SetDimensions(h, h)
    it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW, 0)
    it.barLen = w - iconW
    if ds.fillCenter then
        -- empties toward the middle (Combat Metronome's "Center" bar): two halves, each anchored at the centre
        if not it.bar2 then
            it.bar2 = WM:CreateControl(nil, it.control, CT_STATUSBAR)
            it.bar2:SetDrawLevel(2)
            it.bar2:SetMinMax(0, 1)
        end
        it.bar2:SetHidden(false)
        it.bar2:SetTexture(ds.texture)
        it.bar2:SetAlpha(ds.barAlpha)
        it.bar2:ClearAnchors()
        it.bar2:SetAnchor(TOPLEFT, it.control, TOP, iconW / 2, 0)
        it.bar2:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
        if it.bar2.SetOrientation then it.bar2:SetOrientation(ORIENTATION_HORIZONTAL) end
        if it.bar2.SetBarAlignment and BAR_ALIGNMENT_NORMAL then it.bar2:SetBarAlignment(BAR_ALIGNMENT_NORMAL) end
        if it.bar.SetBarAlignment and BAR_ALIGNMENT_REVERSE then it.bar:SetBarAlignment(BAR_ALIGNMENT_REVERSE) end
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOM, iconW / 2, 0)
    else
        if it.bar2 then it.bar2:SetHidden(true) end
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
    end
    it.centred = ds.fillCenter == true
    it.zoneSide = nil
    -- a font bigger than the row (Tony set a size of their own): the text boxes grow to the font's line height,
    -- still centred on the row, and the timer gets room for its digits -- before, the label was only as
    -- tall as the row, so the game cut the text to "R..." and it sat in odd places
    local fs = Style.FontSize(ds, h)
    it.nudge = Style.TextNudge(fs)
    it.lineH = math.max(h, math.ceil(fs * 1.35))
    -- the stack box is as tall as the line, like the name and the timer (Casual player Geldis, font size 25: "stacks are
    -- not matching vertical alignment with big text sizes" -- it was 6 px shorter than the line, and a label shorter
    -- than its text doesn't centre it, so "x2" sat lower than the timer next to it). No dark badge behind it any more
    -- (Geldis: on a see-through window it was a dark box of its own); the count is plain text like the timer.
    it.stack:SetDimensions(math.max(28, math.ceil(fs * 2)), it.lineH)
    it.stack:ClearAnchors()
    it.stack:SetAnchor(RIGHT, it.control, RIGHT, -4, it.nudge)
    it.time:SetDimensions(math.max(48, math.ceil(fs * 2.8)), it.lineH)
    it.stripe:ClearAnchors()
    it.stripe:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW, 0)
    it.stripe:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, iconW, 0)
    it.stripe:SetWidth(5)
    local b = math.max(1, ds.borderSize or 2)
    it.edge:ClearAnchors()
    it.edge:SetAnchor(TOPLEFT, it.control, TOPLEFT, -b, -b)
    it.edge:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, b, b)
    it.edge:SetEdgeTexture(nil, 1, 1, b)
    it.configured = display.configVersion
    it.lastLayoutKey = nil
end

local function SetHighlight(it, display, s, look)
    local ds, lk = display.ds, display.look
    -- every entry about the target is highlighted: active, missing, "ready" and just-ended ones
    local target = ds.highlightTarget and s.isTarget
    it.highlighted = target
    if look and look.glow then
        it.edge:SetEdgeColor(look.glow[1], look.glow[2], look.glow[3], look.glow[4] or 1)
        it.glowing = true
    elseif target then
        local c = lk.highlightEdge
        it.edge:SetEdgeColor(c[1], c[2], c[3], c[4])
        it.glowing = false
    elseif display.ds.rowBorder then
        -- "Border around every entry": one clean border, as thick as "Border thickness" (Tony)
        local c = display.ds.borderColor
        it.edge:SetEdgeColor(c[1], c[2], c[3], c[4] or 1)
        it.glowing = false
    else
        -- the plain dark outline (styles with a track), as thick as Border thickness (0: none)
        it.edge:SetEdgeColor(0, 0, 0, (lk.track and (ds.borderSize or 2) > 0) and 0.75 or 0)
        it.glowing = false
    end
    if it.stripe then it.stripe:SetHidden(not (target and lk.stripe)) end
end

function Items.bars.Set(it, display, s, now)
    local ds = display.ds
    local look = s.look
    it.state = s
    local hasStacks = ds.showStacks and ((s.stacks or 0) > 1 or (s.allStacks and s.active and s.stacks ~= nil))
    -- layout never depends on the highlight: highlighting only shows/hides overlays (edge, stripe), so
    -- nothing in the row moves when your target changes
    local key = (hasStacks and "s" or "-") .. (ds.showTimer and "t" or "-")
    it.stack:SetHidden(not hasStacks)
    if hasStacks then it.stack:SetText("x" .. s.stacks) end
    it.time:SetHidden(not ds.showTimer)
    it.name:SetHidden(not ds.showName or ds.vertical)
    SetHighlight(it, display, s, look)
    local layoutKey = key .. (ds.vertical and "v" or "") .. (ds.labelPos or "left")
    if ds.vertical then
        if it.lastLayoutKey ~= layoutKey then
            it.lastLayoutKey = layoutKey
            it.time:ClearAnchors()
            it.time:SetAnchor(TOP, it.control, TOP, 0, 1)
            it.time:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            it.stack:ClearAnchors()
            it.stack:SetAnchor(TOP, it.time, BOTTOM, 0, 0)
        end
    elseif it.lastLayoutKey ~= layoutKey then
        it.time:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        it.lastLayoutKey = layoutKey
        -- name and timer boxes are as tall as the row with the text centred in them, nudged down a
        -- pixel or two so the letters (not their line box) sit in the middle
        local nudge = it.nudge or 1
        it.time:ClearAnchors()
        if hasStacks then it.time:SetAnchor(RIGHT, it.stack, LEFT, -4, 0)
        else it.time:SetAnchor(RIGHT, it.control, RIGHT, -5, nudge) end
        -- room for the target stripe is always reserved (styles that have one), highlighted or not
        local left = (ds.showRowIcon and ds.height or 0) + (display.look.stripe and 10 or 5)
        it.name:ClearAnchors()
        local pos = ds.labelPos or "left"
        if pos == "above" or pos == "aboveCenter" then
            -- above the bar (HangryGinger: the skill's name over the global cooldown bar): the whole row's width,
            -- sitting on the bar's top edge; the rows make room for it (Display layout)
            it.name:SetAnchor(BOTTOMLEFT, it.control, TOPLEFT, (ds.showRowIcon and ds.height or 0), -1)
            it.name:SetAnchor(BOTTOMRIGHT, it.control, TOPRIGHT, 0, -1)
        else
            it.name:SetAnchor(LEFT, it.control, LEFT, left, nudge)
            if ds.showTimer then it.name:SetAnchor(RIGHT, it.time, LEFT, -5, 0)
            else it.name:SetAnchor(RIGHT, it.control, RIGHT, -5, nudge) end
        end
        it.name:SetHorizontalAlignment((pos == "center" or pos == "aboveCenter") and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
        it.name:SetHeight(it.lineH or ds.height)
    end
    if ds.showName then
        it.name:SetText(U.FormatTemplate(ds.labelFormat, s, now, ds.timeFormat))
    end
    it.icon:SetTexture(s.icon or C.DEFAULT_ICON)
    local tint = display.ds.iconTint                   -- "Icon tint": darken / colour a too-bright icon...
    it.icon:SetColor(tint[1], tint[2], tint[3], 1)
    it.icon:SetAlpha(tint[4] or 1)                     -- ...and its transparency (once, not squared)
    it.icon:SetDesaturation(((not s.active and not s.ready and not s.expired and ds.desaturateInactive)
        or (s.cooldown and ds.cooldownDesaturate) or (look and look.grey)) and 1 or 0)
    local tc, timerC, stackC = TextColors(ds, look)
    if s.cooldown and not (look and (look.timerColor or look.textColor)) then timerC = ds.cooldownColor end
    Style.SetColor(it.name, tc); Style.SetColor(it.time, timerC); Style.SetColor(it.stack, stackC)
    SetProc(it, ds.showRowIcon and it.icon or it.control, look and look.proc)
    local bg = look and look.background
    if bg then
        it.track:SetHidden(false)
        it.track:SetCenterColor(bg[1], bg[2], bg[3], bg[4] or 1)
        it.customBg = true
    elseif it.customBg then
        it.customBg = nil
        local tc = display.ds.trackColor or { 0, 0, 0, 0.4 }
        it.track:SetCenterColor(tc[1], tc[2], tc[3], tc[4] or 1)
        it.track:SetHidden(not display.look.track)
    end
    it.lastTimeText = nil
end

-- The timer box on a bar is as wide as the timer it shows, and the name gets the rest of the row
-- (HangryGinger: a big font left room for only 5-7 letters of a name). Before, the box was a fixed
-- 2.8x the font size whether it showed "13.5" or nothing at all (a missing ally's row). The width is
-- measured for the text with every digit as "0", so it only changes when the timer gains or loses a
-- character (10.0 -> 9.9), not every tenth of a second: the name doesn't flicker.
local function FitTimerBox(it, text, winScale)
    local w = 0
    if text ~= "" then
        local key = text:gsub("%d", "0")
        local cache = it.timeWidths
        if not cache or it.timeWidthCount > 24 or it.timeWidthsScale ~= winScale then
            cache = {}; it.timeWidths = cache; it.timeWidthCount = 0; it.timeWidthsScale = winScale
        end
        w = cache[key]
        if not w then
            if not it.time.GetStringWidth then return end      -- keep the fixed box
            local raw = it.time:GetStringWidth(key) or 0
            -- screen pixels or UI units (esoui divides by the UI scale in one place and not in another), and the
            -- window's own scale: a window made smaller (Yarden, the Miat import at 0.75: the % showed as "3...") measures
            -- its text smaller than the box it needs in its own units. Take the largest, so the timer is never cut.
            local scale = (GetUIGlobalScale and GetUIGlobalScale()) or 1
            if scale <= 0 then scale = 1 end
            local ws = (winScale and winScale > 0) and winScale or 1
            w = math.ceil(math.max(raw, raw / scale, raw / ws, raw / (scale * ws))) + 4
            cache[key] = w
            it.timeWidthCount = it.timeWidthCount + 1
        end
    end
    if w ~= it.timeBoxW then it.time:SetWidth(w); it.timeBoxW = w end
end

-- s.zone (0-1 of the bar): a window at the end the bar runs out toward (left; right with "Fill from the right";
-- the bottom of a column), in the display's zone colour
-- The bar's full length (without an end window cut off it)
local function BarFullLength(it, ds)
    if it.vertical then
        return ds.width - (ds.showRowIcon and ds.height or 0)
    end
    return it.barLen or ds.width
end

-- The bar(s), `cut` px short at the end they run out toward: the end window (the global cooldown's ping) sits there
-- BESIDE the fill, the way Combat Metronome draws it -- its ping segment and its progress segment never overlap
-- (DariansUtilities Bar:Update lays the segments end to end). Before 5.21.21 the window was laid OVER the bar, so its
-- colour mixed with the bar's (Shaxigaming: "get the ping zone color above the bar color ... like on Combat Metronome").
local function AnchorBars(it, ds, cut)
    it.barCut = cut
    it.bar:ClearAnchors()
    if ds.vertical then
        local iconH = ds.showRowIcon and ds.height or 0
        it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0)
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, -iconH - cut)
        return
    end
    local iconW = ds.showRowIcon and ds.height or 0
    if it.centred and it.bar2 then
        it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW, 0)
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOM, iconW / 2 - cut / 2, 0)
        it.bar2:ClearAnchors()
        it.bar2:SetAnchor(TOPLEFT, it.control, TOP, iconW / 2 + cut / 2, 0)
        it.bar2:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
    elseif ds.fillReverse then
        it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW, 0)
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -cut, 0)
    else
        it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW + cut, 0)
        it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
    end
end
D.AnchorBars = AnchorBars

-- what the (shortened) bar shows for a fraction of the whole: the fill reaches the window's edge when the time left
-- is the window
local function CutValue(it, ds, frac)
    local cut = it.barCut or 0
    if cut <= 0 then return frac end
    local full = BarFullLength(it, ds)
    if full <= cut then return 0 end
    return U.Clamp((frac * full - cut) / (full - cut), 0, 1)
end

local function ShowZone(it, ds, s)
    local z = s.active and s.zone or 0
    if z <= 0 then
        if it.zoneShown then it.zone:SetHidden(true); it.zoneShown = false end
        if (it.barCut or 0) > 0 then AnchorBars(it, ds, 0) end
        return
    end
    local key = (ds.vertical and "v" or (it.centred and "c") or (ds.fillReverse and "r" or "l"))
    if it.zoneSide ~= key then
        -- (anchored to the row, not the bar: the bar itself is shortened by the window)
        it.zone:ClearAnchors()
        local icon = ds.showRowIcon and ds.height or 0
        if key == "c" then
            -- both halves run out toward the middle: the window sits there
            it.zone:SetAnchor(CENTER, it.control, CENTER, icon / 2, 0)
            it.zone:SetHeight(ds.height)
        elseif ds.vertical then
            it.zone:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, 0, -icon); it.zone:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, -icon)
        elseif ds.fillReverse then
            it.zone:SetAnchor(TOPRIGHT, it.control, TOPRIGHT, 0, 0); it.zone:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
        else
            it.zone:SetAnchor(TOPLEFT, it.control, TOPLEFT, icon, 0); it.zone:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, icon, 0)
        end
        it.zoneSide = key
    end
    local c = ds.zoneColor or { 1, 0.88, 0.5, 0.45 }
    it.zone:SetColor(c[1], c[2], c[3], c[4] or 1)
    local len = BarFullLength(it, ds)
    if not len or len <= 0 then len = ds.width end
    it.zoneLen = math.max(1, math.floor(z * len + 0.5))
    if ds.vertical then it.zone:SetHeight(it.zoneLen) else it.zone:SetWidth(it.zoneLen) end
    if it.barCut ~= it.zoneLen then AnchorBars(it, ds, it.zoneLen) end
    if not it.zoneShown then it.zone:SetHidden(false); it.zoneShown = true end
end

-- Shield, trauma and "can't be healed" on a health bar (5.22.0), drawn the way LuiExtended's unit frames draw them
-- (UnitAttributeVisuals/PowerShield.lua): the fill is the health you can use (health minus trauma), trauma is the piece
-- of the bar right after it (health that heals away first), the damage shield is a see-through layer from the empty
-- end, and "can't be healed" darkens the health that's left. Three textures over the bar, under the text, made the
-- first time a bar shows one; not on bars that empty toward the middle or are cut by an end window.
local HV_PARTS = { "noHeal", "trauma", "shield" }
local function HealthSegment(it, ds, tex, a, b, len)
    a, b = U.Clamp(a, 0, 1), U.Clamp(b, 0, 1)
    local size = math.floor((b - a) * len + 0.5)
    if size < 1 then tex:SetHidden(true); return end
    local at = math.floor(a * len + 0.5)
    tex:ClearAnchors()
    if it.vertical then
        tex:SetAnchor(BOTTOMLEFT, it.bar, BOTTOMLEFT, 0, -at)
        tex:SetAnchor(BOTTOMRIGHT, it.bar, BOTTOMRIGHT, 0, -at)
        tex:SetHeight(size)
    elseif ds.fillReverse then
        tex:SetAnchor(TOPRIGHT, it.bar, TOPRIGHT, -at, 0)
        tex:SetAnchor(BOTTOMRIGHT, it.bar, BOTTOMRIGHT, -at, 0)
        tex:SetWidth(size)
    else
        tex:SetAnchor(TOPLEFT, it.bar, TOPLEFT, at, 0)
        tex:SetAnchor(BOTTOMLEFT, it.bar, BOTTOMLEFT, at, 0)
        tex:SetWidth(size)
    end
    tex:SetHidden(false)
end

local function HideHealthVisuals(it)
    if not it.hvShown then return end
    for _, k in ipairs(HV_PARTS) do if it.hv[k] then it.hv[k]:SetHidden(true) end end
    it.hvShown, it.hvKey = false, nil
end

-- returns the fill fraction to show instead (health minus trauma), or nil when the bar shows nothing of this
local function ShowHealthVisuals(it, ds, s)
    local max = s.max or 0
    local shield, trauma = s.shield or 0, s.trauma or 0
    if not s.healthVisuals or max <= 0 or it.centred or (it.barCut or 0) > 0
            or (shield <= 0 and trauma <= 0 and not s.noHeal) then
        HideHealthVisuals(it)
        return nil
    end
    local value = s.value or 0
    local usable = math.max(0, value - trauma) / max
    local health = value / max
    local len = BarFullLength(it, ds)
    local key = table.concat({ math.floor(usable * len + 0.5), math.floor(health * len + 0.5),
        math.floor(math.min(1, shield / max) * len + 0.5), s.noHeal and 1 or 0, len,
        it.vertical and "v" or (ds.fillReverse and "r" or "l") }, ":")
    if key ~= it.hvKey then
        it.hvKey = key
        it.hv = it.hv or {}
        for _, k in ipairs(HV_PARTS) do
            if not it.hv[k] then
                local tex = WM:CreateControl(nil, it.control, CT_TEXTURE)
                tex:SetDrawLevel(3)
                tex:SetHidden(true)
                -- a group frame already faded out of range: the new piece fades with it (5.25.6, Yarden: a shield
                -- that came after the fade stayed bright, so the frame didn't look out of range)
                tex:SetAlpha(it.fade or 1)
                it.hv[k] = tex
            end
        end
        local function Paint(k, c, a, b)
            local tex = it.hv[k]
            tex:SetColor(c[1], c[2], c[3], c[4] or 1)
            HealthSegment(it, ds, tex, a, b, len)
        end
        if trauma > 0 then Paint("trauma", ds.traumaColor, usable, health) else it.hv.trauma:SetHidden(true) end
        if s.noHeal then Paint("noHeal", ds.noHealColor, 0, usable) else it.hv.noHeal:SetHidden(true) end
        if shield > 0 then Paint("shield", ds.shieldColor, 0, math.min(1, shield / max)) else it.hv.shield:SetHidden(true) end
        it.hvShown = true
    end
    return usable
end

function Items.bars.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    local look = s.look
    local frac = Style.Fraction(s, now, ds)
    if s.zone or it.zoneShown then ShowZone(it, ds, s) end
    if s.healthVisuals or it.hvShown then frac = ShowHealthVisuals(it, ds, s) or frac end
    local v = CutValue(it, ds, frac)
    it.bar:SetValue(v)
    if it.centred and it.bar2 then it.bar2:SetValue(v) end
    local color
    -- a rule colour wins even on missing/ready entries (e.g. "ready" in green)
    if look and look.color then color = look.color
    elseif s.expired then color = Style.EXPIRED
    elseif s.cooldown then color = ds.cooldownColor
    elseif not s.active then color = Style.INACTIVE
    else color = Style.Color(ds, frac) end
    it.bar:SetColor(color[1], color[2], color[3], color[4] or 1)
    if it.centred and it.bar2 then it.bar2:SetColor(color[1], color[2], color[3], color[4] or 1) end
    if ds.showTimer then
        local text = ""
        if s.text then text = s.text
        elseif s.fillUp then text = string.format("%d%%", math.floor(Style.Fraction(s, now, ds) * 100))
        elseif s.pct and s.max then text = string.format("%d%%", math.floor(s.pct + 0.5))
        elseif s.expired then text = "+" .. U.FormatTime(now - s.endedAt, ds.timeFormat)
        elseif s.active and (s.expire or 0) > 0 and (s.duration or 0) > 0 then text = U.FormatTime(TimeLeft(ds, s, now), ds.timeFormat)
        end
        if text ~= it.lastTimeText then
            it.time:SetText(text); it.lastTimeText = text
            if not ds.vertical then FitTimerBox(it, text, ds.scale) end
        end
    end
    local alpha = ((s.active or s.ready or s.expired) and 1 or 0.65) * ((look and look.alpha) or 1)
    if (look and look.pulse) or Style.ShouldBlink(ds, s, now) then
        alpha = alpha * Style.PulseAlpha(nowMs, 0.35)
    end
    it.control:SetAlpha(alpha)
    if it.glowing then
        local g = look.glow
        it.edge:SetEdgeColor(g[1], g[2], g[3], (g[4] or 1) * Style.PulseAlpha(nowMs, 0.3))
    end
end

-- Icons --------------------------------------------------------------------

-- Proc cards ("Proc details on icons", on by default): resource sets show a gauge of your resource
-- inside the icon with a line where the bonus is full, the bonus as the big number and the resource %
-- on a strip at the bottom -- green when the bonus is full, gold when partial. A proc with a buff
-- (Roaring Opportunist's Major Slayer) shows the seconds left on you (top right) and how many allies
-- have it from you (bottom left). A proc that needs a low resource (Martial Knowledge: stamina under
-- 50%) shows that resource the same way, green while it can proc; a proc counter (Pearls of Ehlnofey)
-- shows its count as the big number, red while procs are wasted (full ultimate). A running proc gets a
-- green frame.
GROUP_ICON = "/esoui/art/mainmenu/menubar_group_up.dds"
local FRAME_SQUARE = "/esoui/art/actionbar/gamepad/gp_abilityframe64.dds"     -- what Cooldowns uses
local FRAME_ROUND = "/esoui/art/actionbar/passiveabilityframe_round_up.dds"
local CARD = {
    max = { 0.36, 0.95, 0.45, 1 }, part = { 1, 0.80, 0.30, 1 }, none = { 0.62, 0.62, 0.62, 1 },
    info = { 0.45, 0.85, 1, 1 }, wasted = { 0.95, 0.30, 0.30, 1 },
    frame = { 1, 1, 1, 0.9 }, frameDown = { 0.5, 0.5, 0.5, 1 },
    gaugeOk = { 0.30, 0.90, 0.40, 0.45 }, gaugeBad = { 0.90, 0.25, 0.25, 0.45 },
    gauge = { magicka = { 0.30, 0.55, 1, 0.42 }, stamina = { 0.35, 0.85, 0.40, 0.42 },
              ultimate = { 0.95, 0.78, 0.30, 0.42 }, health = { 0.85, 0.25, 0.25, 0.42 } },
}
D.CARD = CARD

-- With the game's ability frame drawn over a proc icon, the frame's dark band covers the icon's edge: the
-- stack count, the buff time, the players count and the resource gauge move inside the frame's opening
-- so they sit on the picture, not on the frame (Tony: "the stacks are on the ghost border").
local FRAME_BAND = 0.1      -- the frame's band, as a share of the icon size
-- [position] = { point, x sign, y sign, alignment }
-- "Trim the icon's own edge": the share cut off each side (other addons crop ability icons the same way: Alpha Squad
-- UI 0.04, Vixen's Group Frames 0.07)
local function IconTrim(ds)
    return math.max(0, ds.iconTrim or 0) / 100
end
D.IconTrim = IconTrim

local STACK_POS = {
    bottomright = { BOTTOMRIGHT, -1, -1, TEXT_ALIGN_RIGHT }, bottomleft = { BOTTOMLEFT, 1, -1, TEXT_ALIGN_LEFT },
    topright = { TOPRIGHT, -1, 1, TEXT_ALIGN_RIGHT }, topleft = { TOPLEFT, 1, 1, TEXT_ALIGN_LEFT },
    top = { TOP, 0, 1, TEXT_ALIGN_CENTER }, bottom = { BOTTOM, 0, -1, TEXT_ALIGN_CENTER },
}
local function CardInset(it, inset)
    if it.cardInset == inset then return end
    it.cardInset = inset
    local c = it.control
    -- the stack count in the corner (or edge) the tracker picked (Geldis: "i cant change stacks size and positions")
    local sp = STACK_POS[it.stackPos or "bottomright"] or STACK_POS.bottomright
    it.stack:ClearAnchors()
    it.stack:SetAnchor(sp[1], c, sp[1], sp[2] * (2 + inset), sp[3] * inset)
    it.stack:SetHorizontalAlignment(sp[4])
    it.info:ClearAnchors()
    it.info:SetAnchor(TOPRIGHT, c, TOPRIGHT, -2 - inset, inset)
    it.alliesIcon:ClearAnchors()
    -- raised by half the gap between the line and the icon, so the number's line ends at the same edge
    -- distance as the buff time's line starts at the top
    local lift = math.floor(((it.cornerLine or 0) - (it.cornerFont or 0)) / 2 + 0.5)
    it.alliesIcon:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 2 + inset, -inset - lift)
    local e = 2 + inset
    it.gauge:ClearAnchors()
    it.gauge:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, e, -e)
    it.gauge:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -e, -e)
    it.band:ClearAnchors()
    it.band:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, e, -e)
    it.band:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -e, -e)
    it.mark:SetDimensions(math.max(4, (it.frameSize or 40) - 2 - 2 * inset), 3)
end

-- The big number between the corner numbers and the % strip (Yarden: at the default size they touched).
-- The free height is measured between the GLYPHS (digits are ~0.72 of the font size, centred in a line
-- ~1.3x the size): below the top corner's digits, above the strip's / the bottom corners' digits, with a
-- small gap; the big number is sized to fit it (never above its usual size, and a font size the player set
-- is kept) and centred in it. The label itself stays a full line tall (a shorter label cuts the text).
-- Also applies "Timer text: move" (ExoY's indicator offset).
local GLYPH = 0.72
function FitBigNumber(it, ds, on, strip, info, bottomCorner)
    local sz = it.frameSize or ds.iconSize
    local inset = it.cardInset or 0
    local base = Style.FontSize(ds, sz, 0.38, 11, 32)
    local fs, cy = base, 0
    if on and (strip or info or bottomCorner) then
        local e = 2 + inset
        local gap = math.max(1, math.floor(sz / 32 + 0.5))
        local top, bottom = e, sz - e
        local cf, line = it.cornerFont or 12, it.cornerLine or 16
        if info then top = inset + line / 2 + cf * GLYPH / 2 end
        if strip then
            local bandTop = sz - e - (it.bandH or 12)
            bottom = bandTop + (it.bandH or 12) / 2 - (it.bandFont or 10) * GLYPH / 2
        elseif bottomCorner then
            local bf = math.max(cf, it.stackFont or cf)
            bottom = sz - inset - math.ceil(bf * 1.3) / 2 - bf * GLYPH / 2
        end
        local avail = bottom - top - 2 * gap
        if not (ds.fontSize and ds.fontSize > 0) then
            fs = math.max(8, math.min(base, math.floor(avail / GLYPH)))
        end
        cy = math.floor((top + bottom) / 2 - sz / 2 + 0.5)
    end
    local ox, oy = ds.timerOffsetX or 0, ds.timerOffsetY or 0
    local key = fs .. ":" .. cy .. ":" .. ox .. ":" .. oy .. ":" .. sz
    if it.timeFit == key then return end
    it.timeFit = key
    local face, effect = ds.fontFace, ds.fontEffect
    it.time:SetFont(effect == "none" and string.format("$(%s)|%d", face, fs) or string.format("$(%s)|%d|%s", face, fs, effect))
    it.time:SetDimensions(sz + 20, math.ceil(fs * 1.35))
    it.time:ClearAnchors()
    it.time:SetAnchor(CENTER, it.control, CENTER, ox, cy + oy)
end

-- The proc card colours, from the tracker (Text & colors > Proc colors) with the built-in palette as the
-- default: full bonus / running / can proc, partial bonus, can't proc / wasted, the blue buff-time number.
local function Palette(ds)
    local ok, part, bad = ds.procColorOk or CARD.max, ds.procColorPart or CARD.part, ds.procColorBad or CARD.wasted
    return {
        max = ok, part = part, none = CARD.none, wasted = bad, info = ds.procColorInfo or CARD.info,
        gaugeOk = { ok[1], ok[2], ok[3], 0.45 }, gaugeBad = { bad[1], bad[2], bad[3], 0.45 },
    }
end

SetCard = function(it, display, s, look, target)
    local ds = display.ds
    local on = ds.procCards and display.kind ~= "heads" and display.kind ~= "onframes"
    local P = Palette(ds)
    local framedNow = on and ds.gameFrame and s.procKey ~= nil
    CardInset(it, framedNow and math.floor((it.frameSize or ds.iconSize) * FRAME_BAND + 0.5) or 0)
    -- (the gauge and its line can be switched off -- Hyssia: "The line + the 92% number, want them gone" on Martial
    -- Knowledge -- the state colours stay: green while it runs or can proc, the cooldown look while it can't)
    local gauge = on and s.gauge ~= nil and ds.procGauge
    it.gauge:SetHidden(not gauge)
    local strip = gauge and ds.procPercent
    it.band:SetHidden(not strip)
    it.bandText:SetHidden(not strip)
    it.mark:SetHidden(not (gauge and s.gaugeMark))
    if gauge then
        local inner = (it.size or ds.iconSize) - 4 - 2 * (it.cardInset or 0)
        -- with a line (the proc / full-bonus threshold): green at or below it, red above it;
        -- otherwise the resource's own colour (ultimate sets)
        local g = CARD.gauge[s.gaugePower or "ultimate"] or CARD.gauge.ultimate
        if s.gaugeMark then g = (s.level == "max") and P.gaugeOk or P.gaugeBad end
        it.gauge:SetCenterColor(g[1], g[2], g[3], g[4])
        it.gauge:SetHeight(math.max(1, inner * U.Clamp(s.gauge, 0, 1)))
        if s.gaugeMark then
            it.mark:ClearAnchors()
            it.mark:SetAnchor(CENTER, it.control, BOTTOM, 0, -(2 + (it.cardInset or 0) + inner * s.gaugeMark))
        end
        local lc = P[s.level or "none"] or P.none
        it.bandText:SetText(s.badge or "")
        it.bandText:SetColor(lc[1], lc[2], lc[3], 1)
        it.band:SetCenterColor(lc[1] * 0.18, lc[2] * 0.18, lc[3] * 0.18, 0.78)
        -- the bonus: big, in the level colour (a rule's timer / text colour still wins). A gated proc's
        -- number is its timer: it keeps the timer colours.
        if not (look and (look.timerColor or look.textColor)) then
            if s.counted then
                -- proc counter: red while the proc is wasted (Pearls with a full ultimate), else gold
                local cc = s.wasted and P.wasted or P.part
                it.time:SetColor(cc[1], cc[2], cc[3], 1)
            elseif not s.gate then
                it.time:SetColor(lc[1], lc[2], lc[3], 1)
            end
        end
        if s.counted then it.stack:SetHidden(true) end     -- the count is the big number
    end
    local info = on and s.info ~= nil
    it.info:SetHidden(not info)
    if info then
        it.info:SetText(U.FormatTemplate("{info}", s, 0))
        local ic = s.infoFull and P.max or P.info      -- green at the maximum (like ExoY's "max")
        it.info:SetColor(ic[1], ic[2], ic[3], 1)
    end
    -- stacks coloured by how full they are (ExoY: green at the most, Z'en low / medium / high)
    if on and s.stackLevel and not (look and look.stackColor) and not ds.separateTextColors then
        local sc = (s.stackLevel == "max" and P.max) or (s.stackLevel == "bad" and P.wasted) or (s.stackLevel == "info" and P.info) or P.part
        it.stack:SetColor(sc[1], sc[2], sc[3], 1)
    end
    -- the game's ability frame around proc icons (round for class passives), tinted by state
    local framed = on and ds.gameFrame and s.procKey ~= nil
    it.gameFrame:SetHidden(not framed)
    if framed then
        local round = s.procKind == "passive"
        local tex = round and FRAME_ROUND or FRAME_SQUARE
        if it.gameFrameTex ~= tex then it.gameFrame:SetTexture(tex); it.gameFrameTex = tex end
        local fs = it.frameSize or ds.iconSize
        if round then fs = fs + math.floor(fs * 5 / 64 + 0.5) end
        it.gameFrame:SetDimensions(fs, fs)
        local fc
        if gauge then fc = (s.level == "max" and P.max) or (s.level == "part" and P.part) or CARD.frame
        elseif s.cooldown or s.phase == 2 then fc = CARD.frameDown
        elseif s.active then fc = P.max
        elseif s.gate and s.level == "max" then fc = P.max       -- (gauge hidden: ready and able to proc)
        else fc = CARD.frame end
        it.gameFrame:SetColor(fc[1], fc[2], fc[3], fc[4] or 1)
    end
    local allies = on and (s.allies or 0) > 0
    it.alliesIcon:SetHidden(not allies)
    it.allies:SetHidden(not allies)
    if allies then
        it.allies:SetText(tostring(s.allies))
        -- green: it reached everyone it could; gold: fewer
        local ac = (s.alliesFull and P.max) or (s.alliesLow and P.part) or WHITE
        it.allies:SetColor(ac[1], ac[2], ac[3], 1)
    end
    if display.kind ~= "heads" and display.kind ~= "onframes" then FitBigNumber(it, ds, on, strip, info, allies or not it.stack:IsHidden()) end
    -- the frame tells the state, unless a rule or the target highlight already coloured it
    if on and not it.glowing and not target and not (look and look.color) and (s.procKey or gauge) then
        local c
        if s.gate then
            -- running, or ready and able to proc (under the limit): green; on cooldown / can't proc: plain
            c = ((s.active and not s.cooldown and s.phase ~= 2) or (s.ready and s.level == "max")) and P.max or nil
        elseif gauge then c = (s.level == "max" and P.max) or (s.level == "part" and P.part) or nil
        elseif s.active and not s.cooldown and s.phase ~= 2 then c = P.max end
        if c then it.edge:SetEdgeColor(c[1], c[2], c[3], 1) end
    end
end

Items.icons = {}

function Items.icons.Create(display)
    local cell = WM:CreateControl(nil, display.content, CT_CONTROL)
    local it = { control = cell, type = "icons" }
    -- the plate behind the icon: no edge of its own (a backdrop always draws its edge INSIDE itself; a 1 px
    -- black one here was the "basic black border" that ignored Border thickness -- Tony). The outline is
    -- it.edge, outside the icon, as thick as Border thickness, black when nothing colours it.
    it.frame = Backdrop(cell, { 0, 0, 0, 0.6 }, NONE, 1, 1)
    it.frame:SetAnchorFill()
    it.ghost = WM:CreateControl(nil, cell, CT_TEXTURE)     -- faded full icon behind a shrinking one
    it.ghost:SetDrawLevel(1)
    it.ghost:SetAnchor(TOPLEFT, cell, TOPLEFT, 2, 2)
    it.ghost:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -2, -2)
    it.ghost:SetDesaturation(1)
    it.ghost:SetAlpha(0.3)
    it.ghost:SetHidden(true)
    it.icon = WM:CreateControl(nil, cell, CT_TEXTURE)
    it.icon:SetDrawLevel(2)
    it.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 2, 2)
    it.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -2, -2)
    it.sweep = Backdrop(cell, { 0, 0, 0, 0.62 }, NONE, 1, 3)
    it.time = Label(cell, 5, TEXT_ALIGN_CENTER)
    it.time:SetAnchor(CENTER, cell, CENTER, 0, 0)
    it.stack = Label(cell, 5, TEXT_ALIGN_RIGHT)
    it.stack:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -2, 0)
    it.name = Label(cell, 5, TEXT_ALIGN_CENTER)
    it.edge = Backdrop(cell, NONE, NONE, 2, 10)
    it.edge:SetAnchor(TOPLEFT, cell, TOPLEFT, -1, -1)
    it.edge:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, 1, 1)
    if DL_OVERLAY then it.edge:SetDrawLayer(DL_OVERLAY) end
    -- proc card extras (created hidden; see SetCard)
    it.gauge = Backdrop(cell, NONE, NONE, 0, 3)          -- resource level, filling up from the bottom
    it.gauge:SetHidden(true)
    it.mark = Backdrop(cell, { 1, 1, 1, 0.9 }, { 0, 0, 0, 0.9 }, 1, 4)   -- where the bonus is full
    it.mark:SetHidden(true)
    it.band = Backdrop(cell, { 0, 0, 0, 0.62 }, NONE, 0, 4)   -- resource % strip along the bottom
    it.band:SetHidden(true)
    it.bandText = Label(cell, 6, TEXT_ALIGN_CENTER)
    it.bandText:SetAnchor(CENTER, it.band, CENTER, 0, 0)
    it.bandText:SetHidden(true)
    it.info = Label(cell, 6, TEXT_ALIGN_RIGHT)            -- the proc's buff: seconds left on you
    it.info:SetAnchor(TOPRIGHT, cell, TOPRIGHT, -2, 0)
    it.info:SetHidden(true)
    it.alliesIcon = WM:CreateControl(nil, cell, CT_TEXTURE)  -- ...and how many allies have it from you
    it.alliesIcon:SetTexture(GROUP_ICON)
    it.alliesIcon:SetDrawLevel(6)
    it.alliesIcon:SetHidden(true)
    it.gameFrame = WM:CreateControl(nil, cell, CT_TEXTURE)  -- the action bar's own ability frame (like Cooldowns)
    it.gameFrame:SetDrawLevel(4)
    it.gameFrame:SetAnchor(CENTER, cell, CENTER, 0, 0)
    it.gameFrame:SetHidden(true)
    it.allies = Label(cell, 6, TEXT_ALIGN_LEFT)
    it.allies:SetAnchor(LEFT, it.alliesIcon, RIGHT, 0, 0)
    it.allies:SetHidden(true)
    return it
end

function Items.icons.Configure(it, display)
    local ds = display.ds
    local sz = ds.iconSize
    it.control:SetDimensions(sz, sz)
    -- the picture's distance from its square (Geldis: "empty space between icon and border filled by uneditable
    -- semibackground"): Icon padding, 0 = the picture fills the square
    local pad = ds.iconPadding or 2
    -- ...and "Trim the icon's own edge": the game's ability icons have a thin dark rim drawn into the picture, so even
    -- with no padding and no background a ~1 px dark line stayed inside the border (Geldis). Other addons crop it the
    -- same way (Vixen's Group Frames 0.07, Alpha Squad UI 0.04 of each side, with SetTextureCoords).
    local cr = IconTrim(ds)
    for _, tex in ipairs({ it.icon, it.ghost }) do
        tex:ClearAnchors()
        tex:SetAnchor(TOPLEFT, it.control, TOPLEFT, pad, pad)
        tex:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -pad, -pad)
        tex:SetTextureCoords(cr, 1 - cr, cr, 1 - cr)
    end
    it.shrunk = nil
    it.ghost:SetHidden(true)          -- (the shrinking timer shows it again)
    -- the coloured border: drawn just outside the icon, as thick as the tracker says (0: no plain outline; a
    -- glow, the target highlight or a rule's colour still draw 1 px)
    local b = math.max(1, ds.borderSize or 2)
    it.edge:ClearAnchors()
    it.edge:SetAnchor(TOPLEFT, it.control, TOPLEFT, -b, -b)
    it.edge:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, b, b)
    it.edge:SetEdgeTexture(nil, 1, 1, b)
    local inner = sz - 4
    it.gauge:ClearAnchors()
    it.gauge:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, 2, -2)
    it.gauge:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -2, -2)
    it.mark:SetDimensions(inner + 2, 3)
    local bandH = math.max(9, math.floor(sz * 0.24))
    it.band:ClearAnchors()
    it.band:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, 2, -2)
    it.band:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -2, -2)
    it.band:SetHeight(bandH)
    it.bandText:SetFont(Style.IconFont(ds, sz, 0.21, 8, 22))
    it.bandH, it.bandFont = bandH, U.Clamp(math.floor(sz * 0.21 + 0.5), 8, 22)
    it.bandText:SetDimensions(inner, bandH)
    -- the two corner numbers match: same font, same line height; the players icon is as tall as the
    -- digits and sits on the same line as its number (Tony: "the people counter is a bit mis-matched")
    local fpx = U.Clamp(math.floor(sz * 0.24 + 0.5), 9, 26)
    local lineH = math.ceil(fpx * 1.3)
    it.cornerLine, it.cornerFont = lineH, fpx
    it.info:SetFont(Style.IconFont(ds, sz, 0.24, 9, 26))
    it.info:SetDimensions(inner, lineH)
    it.alliesIcon:SetDimensions(fpx, fpx)
    it.allies:SetFont(Style.IconFont(ds, sz, 0.24, 9, 26))
    it.allies:SetDimensions(inner, lineH)
    it.allies:ClearAnchors()
    it.allies:SetAnchor(LEFT, it.alliesIcon, RIGHT, 1, 0)
    it.frameSize = sz
    it.cardInset = nil          -- re-placed by SetCard (inside the game frame or not)
    it.time:SetFont(Style.Font(ds, sz, 0.38, 11, 32))
    local ss = (ds.iconStackSize or 0) > 0 and ds.iconStackSize or U.Clamp(math.floor(sz * 0.3 + 0.5), 10, 28)
    it.stack:SetFont(Style.FontAt(ds, ss))
    it.stack:SetHeight(math.ceil(ss * 1.3))
    it.stackFont = ss
    it.stackPos = ds.iconStackPos
    it.cardInset = nil
    it.timeFit = nil
    it.name:SetFont(Style.Font(ds, sz, 0.28, 10, 18))
    it.name:SetDimensions(sz + 30, 18)
    it.name:ClearAnchors()
    it.name:SetAnchor(TOP, it.control, BOTTOM, 0, 1)
    it.configured = display.configVersion
end

function Items.icons.Set(it, display, s, now)
    local ds = display.ds
    local look = s.look
    it.state = s
    it.icon:SetTexture(s.icon or C.DEFAULT_ICON)
    local tint = display.ds.iconTint                   -- "Icon tint": darken / colour a too-bright icon
    it.icon:SetColor(tint[1], tint[2], tint[3], 1)     -- (its transparency is applied as the icon's alpha below)
    it.ghost:SetTexture(s.icon or C.DEFAULT_ICON)
    it.icon:SetDesaturation(((not s.active and not s.ready and not s.expired and ds.desaturateInactive)
        or (s.cooldown and ds.cooldownDesaturate) or (look and look.grey)) and 1 or 0)
    -- "Icon tint" transparency = how see-through the icon picture is (Tony, 5.14.4: 0% = only the border,
    -- e.g. a ring around a potion slot). The border, timer and stacks stay as they are.
    local tintA = ds.iconTint[4] or 1
    it.icon:SetAlpha(((s.active or s.ready or s.expired) and 1 or 0.55) * tintA)
    it.ghost:SetAlpha(0.3 * tintA)
    local hasStacks = ds.showStacks and ((s.stacks or 0) > 1 or (s.allStacks and s.active and s.stacks ~= nil))
    it.stack:SetHidden(not hasStacks)
    if hasStacks then it.stack:SetText(tostring(s.stacks)) end
    it.time:SetHidden(not ds.showTimer)
    local showName = ds.iconLabelFormat ~= ""
    it.name:SetHidden(not showName)
    if showName then it.name:SetText(U.FormatTemplate(ds.iconLabelFormat, s, now, ds.timeFormat)) end
    local tc, timerC, stackC = TextColors(ds, look)
    if s.cooldown and not (look and (look.timerColor or look.textColor)) then timerC = ds.cooldownColor end
    Style.SetColor(it.time, timerC); Style.SetColor(it.stack, stackC); Style.SetColor(it.name, tc)
    -- every entry about the target is highlighted: active, missing, "ready" and just-ended ones
    local target = ds.highlightTarget and s.isTarget
    if look and look.glow then
        it.glowing = true
    else
        it.glowing = false
        local c = target and display.look.highlightEdge or ((look and look.color) or (s.expired and Style.EXPIRED)
            or BLACK)
        local plain = not (target or (look and look.color) or s.expired)
        if plain and ds.rowBorder then
            local b = ds.borderColor
            it.edge:SetEdgeColor(b[1], b[2], b[3], b[4] or 1)
        elseif plain and (ds.borderSize or 2) == 0 then
            it.edge:SetEdgeColor(0, 0, 0, 0)        -- Border thickness 0: no plain outline
        else
            it.edge:SetEdgeColor(c[1], c[2], c[3], c[4] or 1)
        end
    end
    it.control:SetScale((look and look.scale) or 1)
    SetProc(it, it.icon, look and look.proc)
    -- the square behind the picture: Icon background (Text & colors), faded with the picture; a rule's "Entry
    -- background" is kept as set
    local bg = (look and look.background) or ds.iconBg or ICON_BG
    it.frame:SetCenterColor(bg[1], bg[2], bg[3], (bg[4] or 1) * ((look and look.background) and 1 or tintA))
    it.lastTimeText = nil
    SetCard(it, display, s, look, target)
end

function Items.icons.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    local look = s.look
    local sz = it.size or ds.iconSize
    local frac = Style.Fraction(s, now, ds)
    local timed = s.active and (s.duration or 0) > 0 and (s.expire or 0) > 0
    local covered = 0
    if s.pct and s.max and not s.text then covered = 1 - frac elseif timed then covered = 1 - frac end
    if ds.iconTimer == "none" and display.kind ~= "heads" then covered = 0 end     -- no sweep, no shrinking
    local shrink = (ds.iconTimer == "shrinkV" or ds.iconTimer == "shrinkH") and display.kind ~= "heads"
    local pad, cr = ds.iconPadding or 2, IconTrim(ds)
    if shrink or it.shrunk then
        -- the icon itself empties (cropped, not squashed); a faded copy shows what's gone
        local inner = sz - 2 * pad
        local f = shrink and math.max(0.001, 1 - covered) or 1
        local span = 1 - 2 * cr
        it.icon:ClearAnchors()
        if shrink and ds.iconTimer == "shrinkH" then
            it.icon:SetAnchor(TOPLEFT, it.control, TOPLEFT, pad, pad)
            it.icon:SetDimensions(inner * f, inner)
            it.icon:SetTextureCoords(cr, cr + span * f, cr, 1 - cr)
        elseif shrink then
            it.icon:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, pad, -pad)
            it.icon:SetDimensions(inner, inner * f)
            it.icon:SetTextureCoords(cr, 1 - cr, 1 - cr - span * f, 1 - cr)
        else
            it.icon:SetAnchor(TOPLEFT, it.control, TOPLEFT, pad, pad)
            it.icon:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -pad, -pad)
            it.icon:SetTextureCoords(cr, 1 - cr, cr, 1 - cr)
        end
        it.ghost:SetHidden(not shrink)
        it.shrunk = shrink
        covered = 0
    end
    if covered > 0.001 then
        it.sweep:SetHidden(false)
        it.sweep:ClearAnchors()
        it.sweep:SetAnchor(TOPLEFT, it.control, TOPLEFT, pad, pad)
        it.sweep:SetAnchor(TOPRIGHT, it.control, TOPRIGHT, -pad, pad)
        it.sweep:SetHeight(math.max(1, (sz - 2 * pad) * covered))
    else
        it.sweep:SetHidden(true)
    end
    if ds.showTimer then
        local text = ""
        if s.text then text = s.text
        elseif s.fillUp then text = string.format("%d%%", math.floor(frac * 100))
        elseif s.pct and s.max then text = string.format("%d%%", math.floor(s.pct + 0.5))
        elseif s.expired then text = "+" .. U.FormatTime(now - s.endedAt, ds.timeFormat)
        elseif timed then text = U.FormatTime(TimeLeft(ds, s, now), ds.timeFormat) end
        if text ~= it.lastTimeText then it.time:SetText(text); it.lastTimeText = text end
        if timed and not s.cooldown and not (look and (look.textColor or look.timerColor)) and not ds.separateTextColors then
            local c = Style.Color(ds, frac)
            if ds.colorMode ~= "solid" and frac < 0.34 then it.time:SetColor(c[1], c[2], c[3], 1) end
        end
    end
    local alpha = 1
    if (look and look.pulse) or Style.ShouldBlink(ds, s, now) then alpha = Style.PulseAlpha(nowMs, 0.35) end
    it.control:SetAlpha(alpha * (it.headAlpha or 1) * ((look and look.alpha) or 1))
    if it.glowing then
        local g = look.glow
        it.edge:SetEdgeColor(g[1], g[2], g[3], (g[4] or 1) * Style.PulseAlpha(nowMs, 0.25))
    end
end

-- Above heads ----------------------------------------------------------------
-- Icon cells like "icons", placed every frame over their unit by DT.World (Display/World.lua),
-- which also sizes them (distance shrink x rule scale) and fades them with distance.

Items.heads = {}

function Items.heads.Create(display)
    local it = Items.icons.Create(display)
    it.type = "heads"
    return it
end

function Items.heads.Configure(it, display)
    it.size, it.timeFont, it.stackFont = nil, nil, nil
    it.name:SetHidden(true)
    it.configured = display.configVersion
end

function Items.heads.Set(it, display, s, now)
    Items.icons.Set(it, display, s, now)
    -- Above heads, a "missing" icon IS the alert (e.g. "this ally has no Major Courage"): full colour.
    -- Only in "Always" mode, where lit and missing icons sit side by side, does missing go grey.
    local tr = display.tracker and display.tracker.trigger
    if not s.active and not s.expired and not (tr and tr.mode == "always" and display.ds.desaturateInactive) then
        it.icon:SetDesaturation(0)
        it.icon:SetAlpha(1)
    end
    it.name:SetHidden(true)
    it.control:SetScale(1)
    -- stays hidden until DT.World has placed it over its unit (no flash at a stale position)
    if not it.placed then it.control:SetHidden(true) end
    it.lookScale = (s.look and s.look.scale) or 1
end

Items.heads.Animate = Items.icons.Animate

-- Size an above-heads cell (called by DT.World when the wanted size changes).
function D.SizeHeadItem(it, display, size)
    if it.size and math.abs(it.size - size) < 0.75 then return end
    it.size = size
    it.control:SetDimensions(size, size)
    local ds = display.ds
    local tf, sf = Style.Font(ds, size, 0.38, 10, 32), Style.Font(ds, size, 0.3, 9, 24)
    if tf ~= it.timeFont then it.time:SetFont(tf); it.timeFont = tf end
    if sf ~= it.stackFont then it.stack:SetFont(sf); it.stackFont = sf end
end

-- Group frames ---------------------------------------------------------------
-- One frame per group member (trigger "Group members", Core/Group.lua): the health bar of a DebuffTracker bar -- its
-- track, texture, fonts, border and rules -- with the member's class icon, leader and role marks, the health (or
-- Dead / Resurrecting / Offline) on the right, the damage shield, trauma and "can't be healed" over the bar, and the
-- frame faded while the member is out of support range. Laid out like bars: "Frames per column", spacing, grow.
-- The mouse: a tooltip and the game's group menu on right-click (Display/GroupFrames.lua).

Items.frames = {}
-- the crown the game's Group list shows for the leader (zo_grouplist_keyboard.xml, layer OVERLAY). 5.25.6: the group
-- frames' own groupIcon_leader.dds left an empty gap before the leader's name in game (Yarden's screenshot)
local MARK_LEADER = "EsoUI/Art/LFG/LFG_leader_icon.dds"
D.MARK_LEADER = MARK_LEADER

function Items.frames.Create(display)
    local it = Items.bars.Create(display)
    it.type = "frames"
    local row = it.control
    it.leader = WM:CreateControl(nil, row, CT_TEXTURE)
    it.leader:SetDrawLevel(5)
    if DL_OVERLAY then it.leader:SetDrawLayer(DL_OVERLAY) end
    it.leader:SetTexture(MARK_LEADER)
    it.leader:SetHidden(true)
    it.roleIcon = WM:CreateControl(nil, row, CT_TEXTURE)
    it.roleIcon:SetDrawLevel(5)
    if DL_OVERLAY then it.roleIcon:SetDrawLayer(DL_OVERLAY) end
    it.roleIcon:SetHidden(true)
    row:SetHandler("OnMouseEnter", function() DT.GroupFrames.OnEnter(it, display) end)
    row:SetHandler("OnMouseExit", function() DT.GroupFrames.OnExit(it, display) end)
    row:SetHandler("OnMouseUp", function(_, button, upInside) DT.GroupFrames.OnClick(it, display, button, upInside) end)
    return it
end

function Items.frames.Configure(it, display)
    local ds, look = display.ds, display.look
    local h, w = ds.height, display.rowWidth
    it.control:SetDimensions(w, h)
    it.vertical, it.centred, it.barCut, it.zoneSide = false, false, 0, nil
    it.hvKey = nil
    local font = Style.Font(ds, h)
    it.name:SetFont(font); it.time:SetFont(font); it.stack:SetFont(font)
    it.timeWidths, it.timeBoxW, it.lastTimeText, it.lastName = nil, nil, nil, nil
    it.track:SetHidden(not look.track and (ds.trackColor[4] or 0) <= 0)
    local tc = ds.trackColor
    it.track:SetCenterColor(tc[1], tc[2], tc[3], tc[4] or 1)
    it.track:SetEdgeColor(0, 0, 0, 0)
    it.bar:SetTexture(ds.texture)
    it.bar:SetAlpha(ds.barAlpha)
    if it.bar.SetOrientation then it.bar:SetOrientation(ORIENTATION_HORIZONTAL) end
    if it.bar.SetBarAlignment and BAR_ALIGNMENT_NORMAL then
        it.bar:SetBarAlignment(ds.fillReverse and BAR_ALIGNMENT_REVERSE or BAR_ALIGNMENT_NORMAL)
    end
    if it.bar2 then it.bar2:SetHidden(true) end
    it.zone:SetHidden(true); it.zoneShown = false
    it.stack:SetHidden(true)
    it.stripe:SetHidden(true)
    -- the class icon: a square at the left end, like a bar's ability icon
    local iconW = ds.frameClassIcon and h or 0
    it.icon:ClearAnchors()
    it.icon:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0)
    it.icon:SetDimensions(h, h)
    it.icon:SetHidden(not ds.frameClassIcon)
    it.bar:ClearAnchors()
    it.bar:SetAnchor(TOPLEFT, it.control, TOPLEFT, iconW, 0)
    it.bar:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, 0, 0)
    it.barLen = w - iconW
    -- leader / role marks: small, before the name
    local fs = Style.FontSize(ds, h)
    it.nudge = Style.TextNudge(fs)
    it.lineH = math.max(h, math.ceil(fs * 1.35))
    local mark = U.Clamp(math.floor(math.min(h, fs * 1.3) + 0.5), 10, 40)
    it.markSize = mark
    it.leader:SetDimensions(mark, mark)
    it.roleIcon:SetDimensions(mark, mark)
    it.nameLeft = iconW + 4
    -- the health text on the right, the name filling the rest
    it.time:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    it.time:ClearAnchors()
    it.time:SetAnchor(RIGHT, it.control, RIGHT, -4, it.nudge)
    it.time:SetDimensions(math.max(40, math.ceil(fs * 4.2)), it.lineH)
    it.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    it.marksKey = nil
    local b = math.max(1, ds.borderSize or 2)
    it.edge:ClearAnchors()
    it.edge:SetAnchor(TOPLEFT, it.control, TOPLEFT, -b, -b)
    it.edge:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, b, b)
    it.edge:SetEdgeTexture(nil, 1, 1, b)
    it.smooth = nil
    it.fade = nil
    it.configured = display.configVersion
end

-- leader and role marks, then the name after them
local function PlaceMarks(it, ds, s)
    local leader = ds.frameLeader and s.leader == true
    local roleTex = ds.frameRoleIcon and U.ROLE_ICONS[s.role or ""] or nil
    local key = (leader and "L" or "-") .. (roleTex or "-") .. (ds.showName and "n" or "-")
    if key == it.marksKey then return end
    it.marksKey = key
    local x = it.nameLeft
    local gap = 2
    it.leader:SetHidden(not leader)
    if leader then
        it.leader:ClearAnchors()
        it.leader:SetAnchor(LEFT, it.control, LEFT, x, 0)
        x = x + it.markSize + gap
    end
    it.roleIcon:SetHidden(roleTex == nil)
    if roleTex then
        it.roleIcon:SetTexture(roleTex)
        it.roleIcon:ClearAnchors()
        it.roleIcon:SetAnchor(LEFT, it.control, LEFT, x, 0)
        x = x + it.markSize + gap
    end
    it.name:ClearAnchors()
    it.name:SetAnchor(LEFT, it.control, LEFT, x, it.nudge)
    it.name:SetAnchor(RIGHT, it.time, LEFT, -4, 0)
    it.name:SetHeight(it.lineH)
end

-- 24500 -> "24.5k", 1250000 -> "1.25M" (the game's frames abbreviate the same way)
local function Short(v)
    v = math.floor((v or 0) + 0.5)
    if v >= 1000000 then return (string.format("%.2fM", v / 1000000):gsub("%.?0+M$", "M")) end
    if v >= 10000 then return (string.format("%.1fk", v / 1000):gsub("%.0k$", "k")) end
    if v >= 1000 then return (string.format("%.2fk", v / 1000):gsub("%.?0+k$", "k")) end
    return tostring(v)
end
D.ShortNumber = Short

local STATUS = { ressing = "Resurrecting", pending = "Rez pending", ghost = "Ghost" }
function D.FrameStatusText(s)
    if s.online == false then return DT.L("Offline") end
    if s.dead then return DT.L(STATUS[s.rez or ""] or "Dead") end
    if s.rez == "ghost" then return DT.L("Ghost") end
    return nil
end

function D.FrameHealthText(ds, s)
    local status = D.FrameStatusText(s)
    if status then return status end
    local mode = ds.frameHealthText
    local text
    if mode == "none" then text = ""
    elseif mode == "pct" then text = string.format("%d%%", math.floor((s.pct or 0) + 0.5))
    elseif mode == "both" then text = Short(s.value) .. "  " .. string.format("%d%%", math.floor((s.pct or 0) + 0.5))
    else text = Short(s.value) end
    if ds.frameShieldText and (s.shield or 0) > 0 then text = text .. " |c" .. U.ColorToHex(ds.shieldColor):sub(1, 6) .. "+" .. Short(s.shield) .. "|r" end
    return text
end

local ROLE_COLOR_KEY = { tank = "tankColor", healer = "healerColor", dps = "dpsColor" }
function D.FrameColor(ds, s, frac)
    if s.companion then return ds.companionColor end
    if ds.frameColorBy == "health" then return Style.Color(ds, frac) end
    if ds.frameColorBy == "role" then
        local k = ROLE_COLOR_KEY[s.role or ""]
        if k then return ds[k] end
    end
    return ds.colorSolid
end

function Items.frames.Set(it, display, s, now)
    local ds = display.ds
    local look = s.look
    it.state = s
    it.icon:SetTexture(s.icon or C.DEFAULT_ICON)
    it.icon:SetDesaturation((s.online == false or s.dead) and 1 or 0)
    PlaceMarks(it, ds, s)
    it.name:SetHidden(not ds.showName)
    if ds.showName then
        local text = U.FormatTemplate(ds.labelFormat, s, now, ds.timeFormat)
        if text ~= it.lastName then it.name:SetText(text); it.lastName = text end
    end
    it.time:SetHidden(not ds.showTimer)
    local tc, timerC = TextColors(ds, look)
    local down = s.online == false or s.dead
    Style.SetColor(it.name, tc, down and 0.6 or 1)
    Style.SetColor(it.time, (D.FrameStatusText(s) and not (look and (look.timerColor or look.textColor))) and Style.EXPIRED or timerC)
    SetHighlight(it, display, s, look)
    it.control:SetScale(1)
    SetProc(it, it.control, look and look.proc)
    local bg = look and look.background
    if bg then it.track:SetCenterColor(bg[1], bg[2], bg[3], bg[4] or 1); it.customBg = true
    elseif it.customBg then
        local t = ds.trackColor
        it.track:SetCenterColor(t[1], t[2], t[3], t[4] or 1); it.customBg = nil
    end
    local mouse = ds.frameMouse and not DT.unlocked
    if it.mouse ~= mouse then it.control:SetMouseEnabled(mouse); it.mouse = mouse end
end

function Items.frames.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    local look = s.look
    local target = U.Clamp((s.pct or 0) / 100, 0, 1)
    if s.dead or s.online == false then target = 0 end
    -- health moves smoothly between updates (the engine reads it ~10x a second)
    local frac = target
    if it.smooth and it.smoothKey == s.key and it.smoothMs then
        local dt = math.max(0, math.min(0.25, (nowMs - it.smoothMs) / 1000))
        frac = it.smooth + (target - it.smooth) * math.min(1, dt * 14)
        if math.abs(frac - target) < 0.002 then frac = target end
    end
    it.smooth, it.smoothKey, it.smoothMs = frac, s.key, nowMs
    local shown = frac
    if s.healthVisuals and not s.dead and s.online ~= false then
        local hv = it.hvProxy
        if not hv then hv = { healthVisuals = true }; it.hvProxy = hv end
        hv.max, hv.value, hv.shield, hv.trauma, hv.noHeal = s.max, frac * (s.max or 0), s.shield, s.trauma, s.noHeal
        shown = ShowHealthVisuals(it, ds, hv) or frac
    elseif it.hvShown then
        HideHealthVisuals(it)
    end
    it.bar:SetValue(shown)
    local color
    if look and look.color then color = look.color
    elseif s.dead or s.online == false then color = Style.INACTIVE
    else color = D.FrameColor(ds, s, frac) end
    it.bar:SetColor(color[1], color[2], color[3], color[4] or 1)
    if ds.showTimer then
        local text = (look and s.text) or D.FrameHealthText(ds, s)
        if text ~= it.lastTimeText then it.time:SetText(text); it.lastTimeText = text end
    end
    local alpha = (look and look.alpha) or 1
    if s.online == false then alpha = alpha * 0.6 end
    if look and look.pulse then alpha = alpha * Style.PulseAlpha(nowMs, 0.35) end
    it.control:SetAlpha(alpha)
    -- out of support range: the bar, its background and the class icon fade; the name and the health stay readable
    -- (Yarden: faded to 40% as a whole, the names were dark on dark)
    local fade = (s.inRange == false and not s.isMe and s.online ~= false) and (ds.frameRangeAlpha or 0.4) or 1
    if fade ~= it.fade then
        it.fade = fade
        it.bar:SetAlpha(ds.barAlpha * fade)
        it.track:SetAlpha(fade)
        it.icon:SetAlpha(fade)
        if it.hv then for _, tex in pairs(it.hv) do tex:SetAlpha(fade) end end
    end
    if it.glowing then
        local g = look.glow
        it.edge:SetEdgeColor(g[1], g[2], g[3], (g[4] or 1) * Style.PulseAlpha(nowMs, 0.3))
    end
end

-- On group frames ------------------------------------------------------------
-- Another tracker's entries shown on each member's group frame (Display/GroupFrames.lua places them): icons like
-- "above heads" -- an ally missing a buff, your heal on them -- or, with "Show as: a bar along the frame", a thin
-- bar under the frame running out with the effect (a buff's time left on that member).

Items.onframes = {}
function Items.onframes.Create(display)
    local it = Items.icons.Create(display)
    it.type = "onframes"
    return it
end
Items.onframes.Configure = function(it, display)
    Items.icons.Configure(it, display)
    it.size = nil
    it.name:SetHidden(true)
end
function Items.onframes.Set(it, display, s, now)
    Items.icons.Set(it, display, s, now)
    it.name:SetHidden(true)
    it.control:SetScale(1)
    if not it.placed then it.control:SetHidden(true) end
end
Items.onframes.Animate = Items.icons.Animate

Items.framebar = {}
function Items.framebar.Create(display)
    local row = WM:CreateControl(nil, display.content, CT_CONTROL)
    local it = { control = row, type = "framebar" }
    it.track = WM:CreateControl(nil, row, CT_TEXTURE)
    it.track:SetAnchorFill()
    it.track:SetDrawLevel(1)
    it.fill = WM:CreateControl(nil, row, CT_TEXTURE)
    it.fill:SetDrawLevel(2)
    return it
end
function Items.framebar.Configure(it, display)
    local tc = display.ds.trackColor
    it.track:SetColor(tc[1], tc[2], tc[3], tc[4] or 1)
    it.configured = display.configVersion
end
function Items.framebar.Set(it, display, s, now)
    it.state = s
    if not it.placed then it.control:SetHidden(true) end
end
function Items.framebar.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s or not it.barW then return end
    local look = s.look
    local frac = s.active and Style.Fraction(s, now, ds) or 0
    local w = math.max(0, math.floor(it.barW * frac + 0.5))
    it.fill:ClearAnchors()
    if ds.fillReverse then it.fill:SetAnchor(TOPRIGHT, it.control, TOPRIGHT, 0, 0) else it.fill:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0) end
    it.fill:SetDimensions(w, it.barH or 3)
    it.fill:SetHidden(w < 1)
    local c = (look and look.color) or (s.expired and Style.EXPIRED) or ((not s.active) and Style.INACTIVE) or Style.Color(ds, frac)
    it.fill:SetColor(c[1], c[2], c[3], c[4] or 1)
    local alpha = (look and look.alpha) or 1
    if (look and look.pulse) or Style.ShouldBlink(ds, s, now) then alpha = alpha * Style.PulseAlpha(nowMs, 0.35) end
    it.control:SetAlpha(alpha)
end

-- Weave strip ----------------------------------------------------------------
-- One column per skill you cast (trigger "Weaving", Core/Weave.lua), the newest on the right -- quiet when it's clean,
-- loud when it's not (5.25.0, Yarden picked it from three drafts: "make it look AMAZING"):
--   * the skill as a DebuffTracker icon tile; greyed when no light attack went in;
--   * under it a thin line that only grows with the time lost (empty = on time), in the colour of how it went;
--   * under that the ms in its colour -- an on-time 0 in the good colour (Yarden: grey "seems neutral rather than
--     positive"); M / X / Q in red when the light attack
--     didn't make it; a small blue B tag on the icon's corner for a bash-weave;
--   * the fight's average as one of DebuffTracker's number tiles at the end of the strip (the Meter display's look: a
--     dark plate, a coloured line on its left, a gold caption, a big number).
-- Motion: a new skill's line grows to its length, the average rolls to its new value (like the Meter tiles).
-- Nothing round it, no header; nothing shown until the first skill of a fight. Empty slots draw nothing.
-- (5.24.3-5.24.7 were a coloured block with white text under every icon: everything as loud as everything else --
-- AyDeeS: "you can make it look much better".)

Items.weave = {}
local WEAVE_QUIET = { 0.60, 0.63, 0.66, 1 }       -- an on-time 0: there, but not asking for attention
local WEAVE_GROW = 0.22                           -- s: a new line grows in

local function WeaveLineH(ds) return math.max(3, math.floor(ds.iconSize * 0.1 + 0.5)) end
local function WeaveNumFs(ds) return U.Clamp(math.floor(ds.iconSize * 0.33 + 0.5), 11, 26) end
-- a column: the icon, 3 px, the line, the number's line
function D.WeaveCellH(ds) return ds.iconSize + 3 + WeaveLineH(ds) + math.ceil(WeaveNumFs(ds) * 1.3) end
local function EaseOut3(t) t = U.Clamp(t, 0, 1); return 1 - (1 - t) ^ 3 end

function Items.weave.Create(display)
    local it = Items.icons.Create(display)
    it.type = "weave"
    it.track = WM:CreateControl(nil, it.control, CT_TEXTURE)
    it.track:SetDrawLevel(2)
    it.line = WM:CreateControl(nil, it.control, CT_TEXTURE)
    it.line:SetDrawLevel(3)
    it.num = Label(it.control, 6, TEXT_ALIGN_CENTER)
    return it
end

function Items.weave.Configure(it, display)
    Items.icons.Configure(it, display)
    local ds = display.ds
    for _, c in ipairs({ it.name, it.time, it.stack, it.gauge, it.mark, it.gameFrame, it.alliesIcon, it.allies, it.sweep, it.ghost,
            it.band, it.bandText }) do
        c:SetHidden(true)
    end
    local w, lh, fs = ds.iconSize, WeaveLineH(ds), WeaveNumFs(ds)
    it.lineH = lh
    it.track:ClearAnchors()
    it.track:SetAnchor(TOPLEFT, it.control, BOTTOMLEFT, 0, 3)
    it.track:SetDimensions(w, lh)
    it.track:SetColor(0, 0, 0, 0.55)
    it.line:ClearAnchors()
    it.line:SetAnchor(TOPLEFT, it.track, TOPLEFT, 0, 0)
    it.line:SetHeight(lh)
    it.num:SetFont(Style.FontAt(ds, fs))
    it.num:ClearAnchors()
    it.num:SetAnchor(TOP, it.track, BOTTOM, 0, 0)
    it.num:SetDimensions(w + 12, math.ceil(fs * 1.3))
    -- the bash-weave's tag: small, on the icon's top right corner
    local bs = math.max(11, math.floor(w * 0.32 + 0.5))
    it.info:SetFont(Style.FontAt(ds, bs))
    it.info:ClearAnchors()
    it.info:SetAnchor(TOPRIGHT, it.control, TOPRIGHT, -1, -math.floor(bs * 0.12))
    it.info:SetDimensions(w, math.ceil(bs * 1.3))
    it.lineLen, it.lineShown = nil, nil
end

-- the colour for a time lost: good up to weaveGoodMs, okay half way to weaveSlowMs, slow from it on (blended)
function D.WeaveColor(ds, delay)
    local good, slow = ds.weaveGoodMs, ds.weaveSlowMs
    if delay <= good then return ds.weaveGoodColor end
    if delay >= slow then return ds.weaveSlowColor end
    local mid = (good + slow) / 2
    if delay <= mid then return U.LerpColor(ds.weaveGoodColor, ds.weaveOkColor, (delay - good) / math.max(1, mid - good)) end
    return U.LerpColor(ds.weaveOkColor, ds.weaveSlowColor, (delay - mid) / math.max(1, slow - mid))
end

-- the number under the line: the ms (0 = on time or early), the letter when the light attack didn't make it
function D.WeaveText(s)
    if s.weaveEmpty or not s.weaveSettled then return "" end
    if s.weaveLight ~= "ok" then return s.weaveLetter or "" end
    if not s.weaveDelay then return "" end
    return tostring((s.weaveDelay <= 1) and 0 or math.floor(s.weaveDelay + 0.5))
end

function Items.weave.Set(it, display, s, now)
    local ds = display.ds
    local look = s.look
    if it.state == nil or it.state.key ~= s.key then it.bornAt, it.lineShown = now, nil end
    it.state = s
    it.control:SetHidden(s.weaveEmpty == true)
    if s.weaveEmpty then return end
    local bg = (look and look.background) or ds.iconBg or ICON_BG
    it.frame:SetCenterColor(bg[1], bg[2], bg[3], bg[4] or 1)
    local missed = s.weaveSettled and s.weaveLight ~= "ok"
    local showIcon = ds.weaveIcons and s.icon ~= nil
    it.icon:SetHidden(not showIcon)
    if showIcon then
        it.icon:SetTexture(s.icon)
        local tint = ds.iconTint
        it.icon:SetColor(tint[1], tint[2], tint[3], 1)
        it.icon:SetDesaturation(missed and 0.8 or 0)
        it.icon:SetAlpha((missed and 0.6 or 1) * (tint[4] or 1))
    end
    if look and look.glow then
        it.glowing = true
    else
        it.glowing = false
        local b = ds.rowBorder and ds.borderColor or nil
        if b then it.edge:SetEdgeColor(b[1], b[2], b[3], b[4] or 1)
        else it.edge:SetEdgeColor(0, 0, 0, (ds.borderSize or 2) == 0 and 0 or 0.85) end
    end
    -- how it went: the line's length and colour, the number's colour
    local c, len = nil, 0
    if s.weaveSettled and not missed and s.weaveDelay then
        c = D.WeaveColor(ds, s.weaveDelay)
        len = s.weaveDelay <= ds.weaveGoodMs and 0 or U.Clamp(s.weaveDelay / ds.weaveScaleMs, 0, 1)
    end
    if look and look.color then c = look.color end
    it.lineColor, it.lineTarget = c, len
    local text = D.WeaveText(s)
    it.num:SetText(text)
    local nc
    if look and look.textColor then nc = look.textColor
    elseif missed then nc = ds.weaveMissColor
    elseif s.weaveDelay and s.weaveDelay <= ds.weaveGoodMs then nc = ds.weaveGoodColor     -- on time: good, not just "nothing"
    else nc = c or WEAVE_QUIET end
    it.num:SetColor(nc[1], nc[2], nc[3], nc[4] or 1)
    local bash = s.weaveSettled and s.weaveLight == "ok" and s.weaveBash and (s.weaveLetter or "") ~= ""
    it.info:SetHidden(not bash)
    if bash then
        it.info:SetText(s.weaveLetter)
        local ic = ds.procColorInfo or CARD.info
        it.info:SetColor(ic[1], ic[2], ic[3], 1)
    end
    it.control:SetScale(1)
end

function Items.weave.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s or s.weaveEmpty then return end
    local look = s.look
    -- the line grows in once the skill is judged
    local target = it.lineTarget or 0
    if target > 0 and it.lineColor then
        if not it.lineShown then it.lineShown = now end
        local f = EaseOut3((now - it.lineShown) / WEAVE_GROW)
        local w = math.floor(target * ds.iconSize * f + 0.5)
        if w ~= it.lineLen then
            it.lineLen = w
            it.line:SetWidth(math.max(1, w))
        end
        it.line:SetHidden(w < 1)
        local c = it.lineColor
        it.line:SetColor(c[1], c[2], c[3], c[4] or 1)
    else
        it.line:SetHidden(true)
        it.lineLen = 0
    end
    local alpha = (look and look.alpha) or 1
    if look and look.pulse then alpha = alpha * Style.PulseAlpha(nowMs, 0.35) end
    it.control:SetAlpha(alpha)
    if it.glowing and look and look.glow then
        local g = look.glow
        it.edge:SetEdgeColor(g[1], g[2], g[3], (g[4] or 1) * Style.PulseAlpha(nowMs, 0.25))
    end
end

-- The average tile: the Meter display's look (a dark plate, a coloured line on its left, a gold caption, a big number
-- that rolls to its new value).
local function WeaveTile(self)
    local t = self.weaveTile
    if t then return t end
    t = {}
    t.plate = Backdrop(self.window, { 0.055, 0.067, 0.082, 0.82 }, { 0.29, 0.32, 0.36, 1 }, 1, 1)
    t.accent = WM:CreateControl(nil, t.plate, CT_TEXTURE)
    t.accent:SetDrawLevel(2)
    t.caption = Label(t.plate, 3, TEXT_ALIGN_LEFT)
    t.value = Label(t.plate, 3, TEXT_ALIGN_LEFT)
    self.weaveTile = t
    return t
end
D.WEAVE_TILE_GAP = 10
function D.WeaveTileW(ds) return math.floor(ds.iconSize * 1.75 + 0.5) end

function Display:WeaveTileUpdate(avg, now)
    local t = self.weaveTile
    if not t or t.plate:IsHidden() then return end
    local ds = self.ds
    -- the number rolls to its new value
    if avg then
        if t.target ~= avg then t.from, t.target, t.since = t.shown or avg, avg, now end
        local f = EaseOut3((now - (t.since or now)) / 0.35)
        t.shown = (t.from or avg) + (t.target - (t.from or avg)) * f
    else
        t.shown, t.target = nil, nil
    end
    local text = t.shown and string.format("%.2fs", t.shown / 1000) or "-"
    if text ~= t.text then t.value:SetText(text); t.text = text end
    local c = t.shown and D.WeaveColor(ds, t.shown) or WEAVE_QUIET
    t.value:SetColor(c[1], c[2], c[3], 1)
    t.accent:SetColor(c[1], c[2], c[3], 1)
end

-- Meter --------------------------------------------------------------------
-- A number tile (character stats, or any value): a caption above a big number, a coloured accent line on
-- the left, and -- for values with a cap -- a thin gauge along the bottom. Several entries sit side by side
-- (or stacked), one tile each. The number rolls to its new value (ease-out), like an odometer.
-- (Meterskull, 5.17.0: the stats it shows are all here; the look is DebuffTracker's own.)

Items.meter = {}
local GOLD = C.GOLD

function Items.meter.Create(display)
    local tile = WM:CreateControl(nil, display.content, CT_CONTROL)
    local it = { control = tile, type = "meter" }
    it.bg = Backdrop(tile, { 0, 0, 0, 0.8 }, NONE, 1, 1)
    it.bg:SetAnchorFill()
    -- the line on the left: a dim track, and the part that fills up toward the cap (or all of it)
    it.track = Backdrop(tile, NONE, NONE, 1, 2)
    it.fill = Backdrop(tile, GOLD, NONE, 1, 3)
    it.caption = Label(tile, 4, TEXT_ALIGN_LEFT)
    it.value = Label(tile, 4, TEXT_ALIGN_RIGHT)
    it.edge = Backdrop(tile, NONE, NONE, 1, 10)
    it.edge:SetAnchor(TOPLEFT, tile, TOPLEFT, -1, -1)
    it.edge:SetAnchor(BOTTOMRIGHT, tile, BOTTOMRIGHT, 1, 1)
    if DL_OVERLAY then it.edge:SetDrawLayer(DL_OVERLAY) end
    return it
end

-- the number: big and bold, right-aligned (digits line up across stacked tiles); a font set on the Text tab wins
local function MeterNumberFont(ds, h)
    local size = (ds.fontSize and ds.fontSize > 0) and ds.fontSize or U.Clamp(math.floor(h * 0.62 + 0.5), 12, 72)
    local face = ds.fontFace == "MEDIUM_FONT" and "BOLD_FONT" or ds.fontFace
    local effect = ds.fontEffect == "none" and "" or ("|" .. (ds.fontEffect or "soft-shadow-thick"))
    return string.format("$(%s)|%d%s", face, size, effect), size
end

function Items.meter.Configure(it, display)
    local ds, look = display.ds, display.look
    local w, h = ds.meterWidth, ds.meterHeight
    it.control:SetDimensions(w, h)
    local e = look.windowEdge
    it.bg:SetEdgeColor(e[1], e[2], e[3], e[4])
    local barW = ds.meterAccent and math.max(3, math.floor(h / 11)) or 0
    it.barW, it.barH = barW, h
    it.track:SetHidden(not ds.meterAccent)
    it.fill:SetHidden(not ds.meterAccent)
    it.track:ClearAnchors()
    it.track:SetAnchor(TOPLEFT, it.control, TOPLEFT, 0, 0)
    it.track:SetDimensions(barW, h)
    it.fill:ClearAnchors()
    it.fill:SetAnchor(BOTTOMLEFT, it.control, BOTTOMLEFT, 0, 0)
    it.fill:SetDimensions(barW, h)
    local padL = barW + math.max(5, math.floor(h / 8))
    -- the caption: a short tag in the top left corner. ~27 % of the height (13 px on a 48 px tile): at 20 % it
    -- was too small to read in game (Yarden, 5.17.3 screenshot)
    -- (5.17.5: a third of the height -- 16 px on a 48 px tile -- at 27 % it was still small; "Caption size" sets it)
    local capSize = (ds.meterCaptionSize or 0) > 0 and ds.meterCaptionSize or U.Clamp(math.floor(h * 0.33 + 0.5), 11, 26)
    it.caption:SetHidden(not ds.meterCaption)
    it.caption:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", capSize))
    it.caption:SetDimensions(w - padL - 4, math.ceil(capSize * 1.3))
    it.caption:ClearAnchors()
    it.caption:SetAnchor(TOPLEFT, it.control, TOPLEFT, padL, 1)
    local font, size = MeterNumberFont(ds, h)
    it.value:SetFont(font)
    local lineH = math.ceil(size * 1.25)
    it.value:SetDimensions(w - padL - 6, lineH)
    it.value:ClearAnchors()
    if ds.meterCaption then
        -- in the lower part, under the caption (the caption is on the left, the number on the right)
        it.value:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, -6, math.floor(size * 0.14))
    else
        it.value:SetAnchor(RIGHT, it.control, RIGHT, -6, Style.TextNudge(size))
    end
    it.animMs = C.METER_ANIM_MS[ds.meterAnim] or 0
    local b = math.max(1, ds.borderSize or 2)
    it.edge:ClearAnchors()
    it.edge:SetAnchor(TOPLEFT, it.control, TOPLEFT, -b, -b)
    it.edge:SetAnchor(BOTTOMRIGHT, it.control, BOTTOMRIGHT, b, b)
    it.edge:SetEdgeTexture(nil, 1, 1, b)
    it.lastValueText = nil
    it.configured = display.configVersion
end

-- Against your target, the cap tells you how you're doing (Skooma-Tools' penetration calculator colours the same
-- way: red under 18200, green up to 20000, blue above): red below the cap, green at it, blue more than 10 % over
-- (wasted). Only for "vs. my target" stats, with a target.
local CAP_LOW, CAP_OK, CAP_OVER = { 0.96, 0.42, 0.38, 1 }, { 0.40, 0.88, 0.48, 1 }, { 0.45, 0.72, 1, 1 }
D.METER_CAP_COLORS = { low = CAP_LOW, ok = CAP_OK, over = CAP_OVER }
local CAP_JUDGED = { penTarget = true, critTarget = true }
local function CapColor(ds, s)
    if not (ds.meterCapColors and s.max and s.max > 0 and s.value and CAP_JUDGED[s.stat] and s.vsTarget) then return nil end
    local raw = s.value / s.max
    if raw < 1 then return CAP_LOW end
    if raw > 1.1 then return CAP_OVER end
    return CAP_OK
end
D.MeterCapColor = CapColor

local function MeterNumber(ds, s, now)
    if s.value ~= nil and s.fmt then return s.value, s.fmt end
    return nil, nil
end

local function EaseOut(t) return t >= 1 and 1 or (1 - 2 ^ (-10 * t)) end

function Items.meter.Set(it, display, s, now)
    local ds = display.ds
    local look = s.look
    it.state = s
    it.caption:SetText(s.caption or s.name or "")
    Style.SetColor(it.caption, ds.meterCaptionColor)
    local cap = CapColor(ds, s)
    -- the line: a rule's Color, else the cap colour, else the stat's colour (gold; recoveries in their resource colour)
    local ac = (look and look.color) or cap or s.accent or GOLD
    local capped = ds.meterGauge and s.max ~= nil and s.max > 0 and s.value ~= nil
    if capped then
        -- fills up toward the cap (full at or over it), on a dim track
        local frac = math.max(0.04, math.min(1, s.value / s.max))
        it.fill:SetHeight(math.floor(frac * it.barH + 0.5))
        it.track:SetCenterColor(ac[1], ac[2], ac[3], 0.22)
    else
        it.fill:SetHeight(it.barH)
        it.track:SetCenterColor(0, 0, 0, 0)
    end
    it.fill:SetCenterColor(ac[1], ac[2], ac[3], ac[4] or 1)
    -- the tile's background: the window background colour (a rule's "Background color" wins)
    local bg = (look and look.background) or ds.background
    it.bg:SetCenterColor(bg[1], bg[2], bg[3], bg[4] or 1)
    -- the number's colour: a rule's text colour / colour (thresholds), else the cap colour, else the text colour
    local tc = (look and (look.textColor or look.color)) or cap or ds.textColor
    Style.SetColor(it.value, tc)
    -- target value of the roll
    local v, fmt = MeterNumber(ds, s, now)
    it.fmt = fmt
    if v ~= nil then
        if it.to == nil or it.animMs <= 0 then
            it.from, it.to, it.cur, it.t0 = v, v, v, nil
        elseif v ~= it.to then
            it.from, it.to, it.t0 = it.cur or v, v, GetFrameTimeMilliseconds()
        end
    else
        it.to, it.cur, it.t0 = nil, nil, nil
    end
    -- border: rule glow / "Border around every entry"
    if look and look.glow then
        it.edge:SetEdgeColor(look.glow[1], look.glow[2], look.glow[3], look.glow[4] or 1)
    elseif ds.rowBorder then
        local c = ds.borderColor
        it.edge:SetEdgeColor(c[1], c[2], c[3], c[4] or 1)
    else
        it.edge:SetEdgeColor(0, 0, 0, 0)
    end
    it.control:SetScale((look and look.scale) or 1)
end

function Items.meter.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    local text
    if it.to ~= nil then
        if it.t0 then
            local t = (nowMs - it.t0) / it.animMs
            if t >= 1 then it.cur, it.t0 = it.to, nil
            else it.cur = it.from + (it.to - it.from) * EaseOut(t) end
        end
        local v = it.cur
        text = string.format(it.fmt, it.fmt:find("d") and math.floor(v + 0.5) or v)
    elseif s.text then
        text = s.text
    elseif s.active and (s.expire or 0) > 0 and (s.duration or 0) > 0 then
        text = U.FormatTime(TimeLeft(ds, s, now), ds.timeFormat)
    elseif s.pct and s.max then
        text = string.format("%d%%", math.floor(s.pct + 0.5))
    else
        text = ""
    end
    if text ~= it.lastValueText then it.value:SetText(text); it.lastValueText = text end
    local alpha = ((s.active or s.ready or s.expired) and 1 or 0.65) * ((s.look and s.look.alpha) or 1)
    if (s.look and s.look.pulse) or Style.ShouldBlink(ds, s, now) then alpha = alpha * Style.PulseAlpha(nowMs, 0.35) end
    it.control:SetAlpha(alpha)
end

-- Text ---------------------------------------------------------------------

Items.text = {}

-- A text line's height: the row height, or the font's line height when that's taller (thin rows, 5.21.24)
function D.TextRowHeight(ds)
    return math.max(ds.height, math.ceil(Style.FontSize(ds, ds.height, 0.7, 11, 40) * 1.35))
end

function Items.text.Create(display)
    local l = Label(display.content, 4, TEXT_ALIGN_LEFT)
    return { control = l, type = "text", label = l }
end

function Items.text.Configure(it, display)
    local ds = display.ds
    it.label:SetFont(Style.Font(ds, ds.height, 0.7, 11, 40))
    -- a row lower than the text (row height down to 1 px, 5.21.24): the label keeps the font's line height
    it.label:SetDimensions(display.rowWidth, D.TextRowHeight(ds))
    it.label:SetHorizontalAlignment(ds.textCenter and TEXT_ALIGN_CENTER or (ds.grow == "left" and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT))
    it.configured = display.configVersion
end

function Items.text.Set(it, display, s, now)
    it.state = s
    it.nextText = 0
    local tc = (s.look and s.look.textColor) or (s.look and s.look.color) or display.ds.textColor
    if not s.active then tc = Style.INACTIVE end
    Style.SetColor(it.label, tc)
end

function Items.text.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    if now >= (it.nextText or 0) then
        it.nextText = now + 0.1
        it.label:SetText(U.FormatTemplate(ds.textFormat, s, now, ds.timeFormat))
    end
    local alpha = (s.look and s.look.alpha) or 1
    if (s.look and s.look.pulse) or Style.ShouldBlink(ds, s, now) then alpha = alpha * Style.PulseAlpha(nowMs, 0.35) end
    it.label:SetAlpha(alpha)
end

-- Big alert ----------------------------------------------------------------

Items.alert = {}

function Items.alert.Create(display)
    local box = WM:CreateControl(nil, display.content, CT_CONTROL)
    local it = { control = box, type = "alert" }
    it.icon = WM:CreateControl(nil, box, CT_TEXTURE)
    it.icon:SetDrawLevel(2)
    it.frame = Backdrop(box, NONE, { 0, 0, 0, 1 }, 2, 3)
    it.label = Label(box, 4, TEXT_ALIGN_CENTER)
    it.time = Label(box, 5, TEXT_ALIGN_CENTER)
    return it
end

function Items.alert.Configure(it, display)
    local ds = display.ds
    local sz = ds.iconSize * 1.5
    it.icon:ClearAnchors()
    it.icon:SetAnchor(TOP, it.control, TOP, 0, 0)
    it.icon:SetDimensions(sz, sz)
    it.frame:ClearAnchors()
    it.frame:SetAnchor(TOPLEFT, it.icon, TOPLEFT, -2, -2)
    it.frame:SetAnchor(BOTTOMRIGHT, it.icon, BOTTOMRIGHT, 2, 2)
    it.time:ClearAnchors()
    it.time:SetAnchor(CENTER, it.icon, CENTER, 0, 0)
    it.time:SetFont(Style.Font(ds, sz, 0.4, 14, 48))
    it.label:SetFont(Style.Font(ds, sz, 0.4, 16, 48))
    it.label:SetDimensions(math.max(sz * 4, 300), sz * 0.6)
    it.label:ClearAnchors()
    it.label:SetAnchor(TOP, it.icon, BOTTOM, 0, 6)
    it.control:SetDimensions(math.max(sz * 4, 300), sz + 8 + sz * 0.6)
    it.configured = display.configVersion
end

function Items.alert.Set(it, display, s, now)
    local ds = display.ds
    it.state = s
    it.icon:SetTexture(s.icon or C.DEFAULT_ICON)
    Style.SetColor(it.icon, display.ds.iconTint)       -- "Icon tint": darken / colour a too-bright icon
    it.icon:SetDesaturation((not s.active and ds.desaturateInactive) and 1 or 0)
    it.label:SetText(U.FormatTemplate(ds.alertFormat, s, now, ds.timeFormat))
    local tc = (s.look and s.look.textColor) or ds.textColor
    Style.SetColor(it.label, tc)
    local c = (s.look and (s.look.glow or s.look.color)) or BLACK
    it.frame:SetEdgeColor(c[1], c[2], c[3], c[4] or 1)
    it.lastTimeText = nil
    if not it.shownAt then it.shownAt = now end
end

function Items.alert.Animate(it, display, now, nowMs)
    local s, ds = it.state, display.ds
    if not s then return end
    if ds.showTimer then
        local text = ""
        if s.text then text = s.text
        elseif s.active and (s.expire or 0) > 0 and (s.duration or 0) > 0 then text = U.FormatTime(TimeLeft(ds, s, now), ds.timeFormat)
        elseif s.pct and s.max then text = string.format("%d%%", math.floor(s.pct + 0.5)) end
        if text ~= it.lastTimeText then it.time:SetText(text); it.lastTimeText = text end
    end
    -- Pop in, then pulse gently (strongly when a rule asks for it).
    local age = now - (it.shownAt or now)
    local scale = age < 0.15 and (1.25 - age / 0.15 * 0.25) or 1
    it.control:SetScale(scale * ((s.look and s.look.scale) or 1))
    local pulse = (s.look and s.look.pulse) or Style.ShouldBlink(ds, s, now)
    it.control:SetAlpha(pulse and Style.PulseAlpha(nowMs, 0.35) or Style.PulseAlpha(nowMs * 0.5, 0.8))
end

------------------------------------------------------------------------------
-- Display object
------------------------------------------------------------------------------

local function NewDisplay()
    counter = counter + 1
    local self = setmetatable({}, Display)
    local win = WM:CreateTopLevelWindow("DebuffTracker5_Display" .. counter)
    win:SetHidden(true)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    self.window = win
    self.baseTier = win.GetDrawTier and win:GetDrawTier() or DT_LOW
    self.fragment = ZO_HUDFadeSceneFragment:New(win)
    self.fragment:SetHiddenForReason("logic", true)
    HUD_SCENE:AddFragment(self.fragment)
    HUD_UI_SCENE:AddFragment(self.fragment)
    for _, scene in ipairs(D.extraScenes) do scene:AddFragment(self.fragment) end

    self.bg = Backdrop(win, { 0, 0, 0, 0.8 }, { 0, 0, 0, 1 }, 1, 0)
    self.bg:SetAnchorFill()

    self.header = WM:CreateControl(nil, win, CT_CONTROL)
    self.iconFrame = Backdrop(self.header, C.GOLD_BG, C.GOLD_DIM, 1, 1)
    self.icon = WM:CreateControl(nil, self.header, CT_TEXTURE)
    self.icon:SetDrawLevel(2)
    self.iconFrame:SetAnchor(TOPLEFT, self.icon, TOPLEFT, -2, -2)
    self.iconFrame:SetAnchor(BOTTOMRIGHT, self.icon, BOTTOMRIGHT, 2, 2)
    self.title = Label(self.header, 2, TEXT_ALIGN_LEFT)
    self.uptime = Label(self.header, 3, TEXT_ALIGN_RIGHT)
    self.uptime:SetColor(0.62, 0.88, 0.80, 1)
    self.uptimeBadge = Backdrop(self.header, { 0.114, 0.620, 0.459, 0.18 }, NONE, 1, 2)
    self.uptimeBadge:SetAnchor(TOPLEFT, self.uptime, TOPLEFT, -5, -1)
    self.uptimeBadge:SetAnchor(BOTTOMRIGHT, self.uptime, BOTTOMRIGHT, 5, 1)
    self.divider = Backdrop(win, { 0.23, 0.25, 0.28, 1 }, NONE, 1, 1)
    self.divider:SetHeight(1)

    self.content = WM:CreateControl(nil, win, CT_CONTROL)
    self.content:SetAnchorFill()

    -- Unlock-mode decoration: gold frame + name tag.
    self.unlockEdge = Backdrop(win, { 0.95, 0.82, 0.48, 0.08 }, C.GOLD, 1, 20)
    self.unlockEdge:SetAnchor(TOPLEFT, win, TOPLEFT, -2, -2)
    self.unlockEdge:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 2, 2)
    self.unlockTag = Label(win, 21, TEXT_ALIGN_LEFT)
    self.unlockTag:SetFont("$(BOLD_FONT)|12|soft-shadow-thick")
    self.unlockTag:SetColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
    self.unlockTag:SetAnchor(BOTTOMLEFT, win, TOPLEFT, 0, -3)
    self.unlockEdge:SetHidden(true)
    self.unlockTag:SetHidden(true)

    self.pools = { bars = {}, icons = {}, text = {}, alert = {}, heads = {}, meter = {}, frames = {}, onframes = {}, framebar = {}, weave = {} }
    self.active = {}
    self.order = {}
    self.configVersion = 0

    win:SetHandler("OnUpdate", function() self:Animate() end)
    win:SetHandler("OnMoveStop", function() self:OnMoved() end)
    -- With the editor open (windows not unlocked): click a tracker on screen to open it in the editor
    -- (Yarden); hovering shows the gold frame and its name, like move mode.
    win:SetHandler("OnMouseUp", function(_, button, upInside)
        if DT.unlocked or not self.tracker or not D.ClickToEdit() then return end
        if upInside ~= false and (button == nil or button == (MOUSE_BUTTON_INDEX_LEFT or 1)) then
            DT.UI.Edit(self.tracker.id)
        end
    end)
    win:SetHandler("OnMouseEnter", function()
        if DT.unlocked or not self.tracker or not D.ClickToEdit() then return end
        self.hover = true
        self.unlockTag:SetText(self.tracker.name)
        self.unlockEdge:SetHidden(false)
        self.unlockTag:SetHidden(false)
    end)
    win:SetHandler("OnMouseExit", function()
        if not self.hover then return end
        self.hover = false
        if not DT.unlocked then self.unlockEdge:SetHidden(true); self.unlockTag:SetHidden(true) end
    end)
    return self
end

function Display:Acquire(kind)
    local pool = self.pools[kind]
    local it = table.remove(pool)
    if not it then it = Items[kind].Create(self) end
    it.control:SetHidden(false)
    if it.configured ~= self.configVersion then Items[kind].Configure(it, self) end
    return it
end

function Display:ReleaseItem(it)
    it.control:SetHidden(true)
    it.placed = nil
    it.state = nil
    it.shownAt = nil
    table.insert(self.pools[it.type], it)
end

function Display:ReleaseAll()
    for key, it in pairs(self.active) do self:ReleaseItem(it) end
    self.active = {}
    self.order = {}
end

-- Apply a tracker's display settings (called on every rebuild / edit).
function Display:Configure(tracker)
    self.tracker = tracker
    local ds = tracker.display
    self.ds = ds
    self.look = Style.Look(ds)
    -- "On group frames" shown as a bar along each frame is its own kind of entry
    local kind = (ds.type == "onframes" and ds.frameShow == "bar") and "framebar" or ds.type
    if self.kind ~= kind then
        if self.kind == "onframes" or self.kind == "framebar" then DT.GroupFrames.SetActive(self, false) end
        if self.kind == "frames" then DT.GroupFrames.FramesGone(self) end
        self:ReleaseAll()
    end
    self.kind = kind
    self.configVersion = self.configVersion + 1
    local look = self.look
    self.rowWidth = ds.width - 2 * look.padX

    local bg = ds.background
    self.bg:SetCenterColor(bg[1], bg[2], bg[3], bg[4])
    local e = ds.windowEdge or look.windowEdge
    self.bg:SetEdgeColor(e[1], e[2], e[3], e[4])
    self.bg:SetEdgeTexture(nil, 1, 1, math.max(1, ds.windowEdgeSize or 0))
    local plain = ds.type == "alert" or ds.type == "text"
    -- above heads / on group frames: placed on other things, no window of their own
    local heads = ds.type == "heads" or ds.type == "onframes"
    -- meters are tiles with their own background: the window's only shows behind a header
    -- a fully transparent background: no box at all, its border included (HangryGinger: "just floating text")
    -- (a see-through box with a border of its own keeps the border: WeaveDelays' frame round an empty box)
    local edgeOnly = ds.windowEdge ~= nil and (ds.windowEdge[4] or 1) > 0.01
    self.bg:SetHidden(ds.type == "alert" or heads or (ds.type == "meter" and not ds.showHeader) or ((bg[4] or 1) <= 0.01 and not edgeOnly))
    self.window:SetAlpha(ds.alpha)
    self.window:SetScale(heads and 1 or ds.scale)
    self.window:SetDrawLevel(ds.drawLevel or 0)
    self:ApplyTier()

    -- Header
    local showHeader = ds.showHeader and ds.type ~= "alert" and not heads
    -- "Header text size" (Casual player Geldis: "i have like 25 text size and header text is small as it by default"):
    -- the title in the tracker's own font and outline, and the header as tall as that line needs
    local hfs = ds.headerFontSize or 0
    self.headerHeight = showHeader and math.max(math.floor(28 * look.headerScale + 0.5), hfs > 0 and math.ceil(hfs * 1.45) or 0) or 0
    self.header:SetHidden(not showHeader)
    self.divider:SetHidden(not (showHeader and look.divider and not plain))
    if showHeader then
        local hh = self.headerHeight
        local iconSize = math.max(12, hh - 8)
        self.icon:SetDimensions(iconSize, iconSize)
        self.icon:SetTexture(DT.Triggers.TrackerIcon(tracker))
        self.icon:ClearAnchors()
        self.icon:SetAnchor(LEFT, self.header, LEFT, look.iconFrame and 7 or 5, 0)
        self.iconFrame:SetHidden(not look.iconFrame)
        self.title:SetFont(hfs > 0 and Style.FontAt(ds, hfs) or look.titleFont)
        Style.SetColor(self.title, look.titleColor)
        self.titleRight = nil      -- anchored by HeaderText (it knows whether the uptime is showing)
        self.title:SetHeight(hh)
        self.uptime:SetFont(ds.style == "compact" and "$(MEDIUM_FONT)|11|soft-shadow-thin" or "$(MEDIUM_FONT)|12|soft-shadow-thin")
        self.uptime:ClearAnchors()
        self.uptime:SetAnchor(RIGHT, self.header, RIGHT, -9, 0)
    end
    for _, it in pairs(self.active) do Items[it.type].Configure(it, self) end
    self.layoutDirty = true
    self.lastCount = nil
end

-- The title runs up to the uptime badge when it shows, else to the window's edge. It always stopped 52 px short
-- (the badge's room), so with uptime off a narrow window cut its own name in half for nothing (Azu: "Major Cou...",
-- "Group: Po..." with empty space after them). Re-anchored only when that changes.
local TITLE_RIGHT_UPTIME, TITLE_RIGHT_PLAIN = 52, 8
local function AnchorTitle(self, right)
    if self.titleRight == right then return end
    self.titleRight = right
    self.title:ClearAnchors()
    self.title:SetAnchor(LEFT, self.icon, RIGHT, self.look.iconFrame and 8 or 5, 0)
    self.title:SetAnchor(RIGHT, self.header, RIGHT, -right, 0)
end

function Display:HeaderText(tracker, rt)
    local ds = self.ds
    local title = ds.title ~= "" and ds.title or tracker.name
    local up = ds.showUptime and rt and rt.uptime
    if self.kind == "weave" then
        -- (the average is the tile at the strip's end: no badge)
        local avg = nil
        self.uptime:SetHidden(not avg)
        self.uptimeBadge:SetHidden(not (avg and self.look.iconFrame))
        if avg then self.uptime:SetText(string.format("%.2f s", avg / 1000)) end
        AnchorTitle(self, avg and TITLE_RIGHT_UPTIME or TITLE_RIGHT_PLAIN)
        self.title:SetText(title)
        return
    end
    if self.look.uptimeInTitle then
        if up then title = string.format("%s - %d%%", title, math.floor(up + 0.5)) end
        self.uptime:SetHidden(true)
        self.uptimeBadge:SetHidden(true)
    else
        self.uptime:SetHidden(not up)
        self.uptimeBadge:SetHidden(not (up and self.look.iconFrame))
        if up then self.uptime:SetText(string.format("%d%%", math.floor(up + 0.5))) end
    end
    AnchorTitle(self, (up and not self.look.uptimeInTitle) and TITLE_RIGHT_UPTIME or TITLE_RIGHT_PLAIN)
    self.title:SetText(title)
end

-- Has the order of entries changed since the last layout? (compared key by key against the keys kept
-- from the last layout: no string is built every update)
local function OrderChanged(self, order)
    local last = self.lastOrderKeys
    if not last then last = {}; self.lastOrderKeys = last end
    local n = #order
    local changed = #last ~= n
    for i = 1, n do
        local it = order[i]
        local k = it.state and it.state.key
        if last[i] ~= k then changed = true; last[i] = k end
    end
    for i = #last, n + 1, -1 do last[i] = nil end
    return changed
end

-- Position entries and size the window.
function Display:Layout()
    local ds, look = self.ds, self.look
    if self.weaveTile and ds.type ~= "weave" then self.weaveTile.plate:SetHidden(true) end
    if ds.type == "heads" or ds.type == "onframes" then
        -- a full-screen layer; DT.World places the entries over each ally every frame
        self.header:SetHidden(true)
        self.divider:SetHidden(true)
        return
    end
    local order = self.order
    local n = #order
    local grow = ds.grow
    local hh = self.headerHeight
    -- the window's frame is as wide on every side (Tony: Classic / Clean "look a tad misshaped" -- Classic
    -- had 5 px at the sides but 2 at the top and bottom): below the entries and, without a header, above
    -- them too, the side padding is used
    local padBottom = math.max(look.padBottom, look.padX)
    local padTop = (hh > 0) and look.padTop or padBottom
    local width, height

    if ds.type == "alert" then
        local it = order[1]
        width = it and it.control:GetWidth() or 300
        height = it and it.control:GetHeight() or 80
        if it then
            it.control:ClearAnchors()
            it.control:SetAnchor(TOP, self.window, TOP, 0, 0)
        end
    elseif ds.type == "icons" then
        local sz, gap = ds.iconSize, ds.spacing
        local cols = math.max(1, ds.columns)
        local nameH = ds.iconLabelFormat ~= "" and 20 or 0
        local vertical = grow == "down" or grow == "up"
        local perLine = cols
        local lines = math.max(1, math.ceil(n / perLine))
        local used = math.min(n, perLine)
        local cellW, cellH = sz + gap, sz + nameH + gap
        if vertical then
            width = math.max(1, lines) * cellW - gap + 2 * look.padX
            height = math.max(1, used) * cellH - gap
        else
            width = math.max(1, used) * cellW - gap + 2 * look.padX
            height = lines * cellH - gap
        end
        if hh > 0 then width = math.max(width, 140) end
        height = hh + padTop + math.max(height, sz) + padBottom
        -- empty: just the header (no empty square below it); moving windows keeps a square to grab
        if n == 0 and hh > 0 and not DT.unlocked then height = hh end
        for i, it in ipairs(order) do
            local idx = i - 1
            local col, row
            if vertical then row, col = idx % perLine, math.floor(idx / perLine)
            else col, row = idx % perLine, math.floor(idx / perLine) end
            local x = look.padX + col * cellW
            local y = hh + padTop + row * cellH
            it.control:ClearAnchors()
            if grow == "left" then
                it.control:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -x, y)
            elseif grow == "up" then
                it.control:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, x, -(hh + padTop + row * cellH + nameH))
            else
                it.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, x, y)
            end
        end
    elseif ds.type == "weave" then
        -- columns in rows (slots per row, the newest at the end), the average tile after them
        local w = ds.iconSize
        local gap = math.max(1, ds.spacing)
        local perLine = math.max(1, ds.columns)
        local lines = math.max(1, math.ceil(n / perLine))
        local cellH = D.WeaveCellH(ds)
        local tileW = ds.weaveAverage and D.WeaveTileW(ds) or 0
        local gridW = perLine * (w + gap) - gap
        width = gridW + (tileW > 0 and (D.WEAVE_TILE_GAP + tileW) or 0) + 2 * look.padX
        if hh > 0 then width = math.max(width, 160) end
        local top = hh + padTop
        height = top + lines * (cellH + gap) - gap + padBottom
        for i, it in ipairs(order) do
            local idx = i - 1
            local col, row = idx % perLine, math.floor(idx / perLine)
            it.control:ClearAnchors()
            it.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, look.padX + col * (w + gap), top + row * (cellH + gap))
        end
        local t = WeaveTile(self)
        t.plate:SetHidden(tileW == 0)
        if tileW > 0 then
            -- beside the last row, as tall as an icon
            local y = top + (lines - 1) * (cellH + gap)
            t.plate:ClearAnchors()
            t.plate:SetAnchor(TOPLEFT, self.window, TOPLEFT, look.padX + gridW + D.WEAVE_TILE_GAP, y)
            t.plate:SetDimensions(tileW, w)
            t.accent:ClearAnchors()
            t.accent:SetAnchor(TOPLEFT, t.plate, TOPLEFT, 1, 1)
            t.accent:SetAnchor(BOTTOMLEFT, t.plate, BOTTOMLEFT, 1, -1)
            t.accent:SetWidth(3)
            local cap = math.max(10, math.floor(w * 0.26 + 0.5))
            local val = math.max(12, math.floor(w * 0.46 + 0.5))
            t.caption:SetFont(Style.FontAt(ds, cap))
            t.caption:SetText(DT.L("avg"))
            local cc = ds.meterCaptionColor or { 0.95, 0.87, 0.64, 1 }
            t.caption:SetColor(cc[1], cc[2], cc[3], cc[4] or 1)
            t.caption:ClearAnchors()
            t.caption:SetAnchor(TOPLEFT, t.plate, TOPLEFT, 9, math.floor(w * 0.06))
            t.caption:SetDimensions(tileW - 12, math.ceil(cap * 1.3))
            t.value:SetFont(Style.FontAt(ds, val))
            t.value:ClearAnchors()
            t.value:SetAnchor(BOTTOMLEFT, t.plate, BOTTOMLEFT, 9, -math.floor(w * 0.02))
            t.value:SetDimensions(tileW - 12, math.ceil(val * 1.3))
            t.text = nil
        end
    elseif ds.type == "meter" then
        -- rows of "Tiles per line", left to right; Grow says where the next row goes (down / up) or that
        -- tiles fill from the right (left)
        local tw, th, gap = ds.meterWidth, ds.meterHeight, ds.spacing
        local perLine = math.max(1, ds.columns)
        local lines = math.max(1, math.ceil(n / perLine))
        local used = math.max(1, math.min(n, perLine))
        local pad = hh > 0 and look.padX or 0
        width = used * (tw + gap) - gap + 2 * pad
        height = lines * (th + gap) - gap
        if hh > 0 then width = math.max(width, 140) end
        local top = hh > 0 and (hh + padTop) or 0
        height = top + height + (hh > 0 and padBottom or 0)
        for i, it in ipairs(order) do
            local idx = i - 1
            local col, row = idx % perLine, math.floor(idx / perLine)
            local x = pad + col * (tw + gap)
            local y = top + row * (th + gap)
            it.control:ClearAnchors()
            if grow == "left" then
                it.control:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -x, y)
            elseif grow == "up" then
                it.control:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, x, -y)
            else
                it.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, x, y)
            end
        end
    elseif ds.type == "bars" and ds.vertical then
        local colW, colH = ds.height, ds.width
        local step = colW + math.max(ds.spacing, 2)
        width = math.max(n, 1) * step - (step - colW) + 2 * look.padX
        if hh > 0 then width = math.max(width, 140) end
        height = hh + padTop + colH + padBottom
        for i, it in ipairs(order) do
            local x = look.padX + (i - 1) * step
            it.control:ClearAnchors()
            if grow == "left" then
                it.control:SetAnchor(TOPRIGHT, self.window, TOPRIGHT, -x, hh + padTop)
            elseif grow == "up" then
                it.control:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, x, -(hh + padTop))
            else
                it.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, x, hh + padTop)
            end
        end
    else
        local h = ds.type == "text" and D.TextRowHeight(ds) or ds.height
        -- a label above each bar takes a line of its own
        local above = (ds.type == "bars" and not ds.vertical and ds.showName and (ds.labelPos == "above" or ds.labelPos == "aboveCenter"))
            and math.ceil(Style.FontSize(ds, h) * 1.35) or 0
        local barLike = ds.type == "bars" or ds.type == "frames"
        local step = h + above + (barLike and math.max(ds.spacing, 0) or 2)
        -- "Bars per column" (BuffTheGroup's 6 x 2; group frames: "Frames per column"): a new column after that many
        local perCol = (barLike and (ds.barRows or 0) > 0) and ds.barRows or math.max(n, 1)
        local cols = math.max(1, math.ceil(n / perCol))
        local rows = math.min(n, perCol)
        local colStep = ds.width - 2 * look.padX + math.max(ds.spacing, 2)
        width = ds.width + (cols - 1) * colStep
        local body = rows > 0 and (rows * step - (step - h - above)) or 0
        height = hh + (n > 0 and (padTop + body + padBottom) or 0)
        for i, it in ipairs(order) do
            local col, row = math.floor((i - 1) / perCol), (i - 1) % perCol
            local x = look.padX + col * colStep
            local y = hh + padTop + row * step + (grow == "up" and 0 or above)
            it.control:ClearAnchors()
            if grow == "up" then
                it.control:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, x, -y)
            else
                it.control:SetAnchor(TOPLEFT, self.window, TOPLEFT, x, y)
            end
        end
    end

    -- Header sits at the far end from the growth direction.
    self.header:ClearAnchors()
    self.divider:ClearAnchors()
    if grow == "up" then
        self.header:SetAnchor(BOTTOMLEFT, self.window, BOTTOMLEFT, 0, 0)
        self.divider:SetAnchor(BOTTOMLEFT, self.header, TOPLEFT, 0, 0)
    else
        self.header:SetAnchor(TOPLEFT, self.window, TOPLEFT, 0, 0)
        self.divider:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 0)
    end
    self.header:SetDimensions(width, hh)
    self.divider:SetWidth(width)
    self.window:SetDimensions(width, math.max(height, 1))
end

function Display:Render(tracker, states, now, ctx, rt, test)
    if self.tracker ~= tracker then self:Configure(tracker) end
    local kind = self.kind
    -- the tables of the previous update are reused (two of each, swapped: Animate reads `order` between updates)
    local newActive, order, seen = self.spareActive or {}, self.spareOrder or {}, self.seen or {}
    for k in pairs(seen) do seen[k] = nil end
    for i = #order, 1, -1 do order[i] = nil end
    self.seen = seen
    local placed = kind == "heads" or kind == "onframes" or kind == "framebar"
    local keepSlots = tracker.display.keepSlots and not placed and kind ~= "alert" and kind ~= "frames" and kind ~= "weave"
    local drawn = 0
    for i, s in ipairs(states) do
        -- keys must be unique: a repeated key would orphan an item that then stays frozen on screen
        if seen[s.key] then s.key = tostring(s.key) .. "#" .. i end
        seen[s.key] = true
        local it = self.active[s.key]
        if it and it.type ~= kind then self:ReleaseItem(it); it = nil end
        if it then self.active[s.key] = nil else it = self:Acquire(kind) end
        newActive[s.key] = it
        order[i] = it
        Items[kind].Set(it, self, s, now)
        -- "Keep a gap for missing entries": a missing entry keeps its place, but nothing is drawn there
        local blank = keepSlots and s.active == false and not s.ready and not s.expired and not s.cooldown
        -- above heads, only DT.World shows an icon, once it has placed it over its person (5.21.25: this line showed
        -- every one again 10 times a second and the world pass hid it every frame -- an icon whose person couldn't be
        -- placed, e.g. after leaving a battleground, flickered at the last spot it was drawn at -- Yarden)
        if not placed then it.control:SetHidden(blank or s.weaveEmpty == true) end
        if not blank then drawn = drawn + 1 end
    end
    local oldActive, oldOrder = self.active, self.order
    for k, it in pairs(oldActive) do self:ReleaseItem(it); oldActive[k] = nil end
    self.active, self.order = newActive, order
    self.spareActive, self.spareOrder = oldActive, oldOrder

    local changed = OrderChanged(self, order)
    if self.layoutDirty or changed then
        self.layoutDirty = false
        self:Layout()
    end
    if not self.header:IsHidden() then self:HeaderText(tracker, rt) end

    if kind == "heads" then
        self.unlockEdge:SetHidden(true)
        self.unlockTag:SetHidden(true)
        self.window:SetMouseEnabled(false)
        self.window:SetMovable(false)
        if #states > 0 then self:Show() else self:Hide() end
        DT.World.SetActive(self, #states > 0)
        self:Animate(true)
        return
    end
    if kind == "onframes" or kind == "framebar" then
        -- placed on the group frames at the end of the update (DT.GroupFrames.Place), once every frame is drawn
        self.unlockEdge:SetHidden(true)
        self.unlockTag:SetHidden(true)
        self.window:SetMouseEnabled(false)
        self.window:SetMovable(false)
        if #states > 0 then self:Show() else self:Hide() end
        DT.GroupFrames.SetActive(self, #states > 0)
        self:Animate(true)
        return
    end
    DT.World.SetActive(self, false)
    local unlocked = DT.unlocked
    local clickable = not unlocked and D.ClickToEdit()
    if not clickable then self.hover = false end
    -- "Keep the window visible when empty" keeps the window's HEADER on screen between fights (so bars don't
    -- pop in and out). Without a header there is nothing to keep -- it was an empty dark square (Tony, Yarden).
    local keepEmpty = tracker.display.showEmpty and (self.headerHeight or 0) > 0
    local visible = drawn > 0 or keepEmpty or unlocked
    if unlocked or self.hover then
        self.unlockTag:SetText(tracker.name)
    end
    self.unlockEdge:SetHidden(not (unlocked or self.hover))
    self.unlockTag:SetHidden(not (unlocked or self.hover))
    self.window:SetMouseEnabled(unlocked or clickable)
    self.window:SetMovable(unlocked)
    if visible then self:Show() else self:Hide() end
    if kind == "frames" then DT.GroupFrames.FramesRendered(self, visible) end
    if kind == "weave" then
        self.weaveAvgValue = states[1] and states[1].weaveAvg
        if not self.header:IsHidden() then self:HeaderText(tracker, rt) end
    end
    self:Animate(true)
end

function Display:Animate(force)
    if not self.kind then return end
    local now = U.Now()
    local nowMs = GetFrameTimeMilliseconds()
    -- Settings > Performance, "Move bars and timers every frame" off: only as often as the trackers update
    local st = DT.Profiles.Settings()
    -- (each update still redraws: Render forces it)
    if st.smoothTimers == false then
        if not force and self.lastAnimMs and nowMs >= self.lastAnimMs and nowMs - self.lastAnimMs < DT.Engine.UpdateMs() then
            return
        end
        self.lastAnimMs = nowMs
    end
    local f = Items[self.kind].Animate
    for _, it in ipairs(self.order) do f(it, self, now, nowMs) end
    if self.kind == "weave" then self:WeaveTileUpdate(self.weaveAvgValue, now) end
end

-- Visibility goes ONLY through the fragment's hidden reason: the fragment shows the window when one
-- of its scenes (HUD, HUD UI, the editor) is showing and the reason is clear. Calling SetHidden(false)
-- directly would also show it on top of menus like the inventory.
function Display:Show()
    if self.hidden == false then return end
    self.hidden = false
    self.fragment:SetHiddenForReason("logic", false)
end

function Display:Hide()
    if self.kind == "heads" then DT.World.SetActive(self, false) end
    if self.kind == "onframes" or self.kind == "framebar" then DT.GroupFrames.SetActive(self, false) end
    if self.kind == "frames" then DT.GroupFrames.FramesHidden(self) end
    if self.hidden == true then return end
    self.hidden = true
    self.fragment:SetHiddenForReason("logic", true)
end

function Display:Release()
    DT.World.SetActive(self, false)
    DT.GroupFrames.SetActive(self, false)
    DT.GroupFrames.FramesGone(self)
    self:ReleaseAll()
    self:Hide()
    self.tracker, self.ds, self.kind = nil, nil, nil
end

-- Anchor point used for a tracker's saved position (so "grow up" really grows upward).
function D.GrowPoint(tracker)
    return GrowPoint(tracker.display.grow)
end

function Display:OnMoved()
    local t = self.tracker
    if not t then return end
    local point = GrowPoint(t.display.grow)
    local cx, cy = GuiRoot:GetWidth() / 2, GuiRoot:GetHeight() / 2
    local x = (point == TOPRIGHT) and self.window:GetRight() or self.window:GetLeft()
    local y = (point == BOTTOMLEFT) and self.window:GetBottom() or self.window:GetTop()
    local settings = DT.Profiles.Settings()
    local grid = settings.snapToGrid and settings.gridSize or 1
    t.position.x = U.Round(x - cx, grid)
    t.position.y = U.Round(y - cy, grid)
    t.position.anchorTo = ""
    D.ApplyPositions()
    if DT.UI.OnTrackerMoved then DT.UI.OnTrackerMoved(t) end
end

------------------------------------------------------------------------------
-- Collection
------------------------------------------------------------------------------

function D.Get(id)
    return displays[id]
end

function D.All()
    return displays
end

local function AnchorTarget(t, trackersById)
    local seen = { [t.id] = true }
    local cur = t
    for _ = 1, 30 do
        local nextId = cur.position.anchorTo
        if nextId == "" or not trackersById[nextId] then break end
        if seen[nextId] then return nil end       -- cycle: fall back to screen position
        seen[nextId] = true
        cur = trackersById[nextId]
    end
    local id = t.position.anchorTo
    -- an above-heads tracker has no window of its own to attach to
    if id ~= "" and trackersById[id] and not D.NO_WINDOW[trackersById[id].display.type] and displays[id] then return displays[id] end
    return nil
end

-- Attached windows: [side] = { [align] = { my point, the target's point } }. "start" lines up the left (top) edges
-- -- the only choice before 5.21.10 --, "center" the middles, "end" the right (bottom) edges.
local ATTACH = {
    below = { vertical = true, sign = 1, start = { TOPLEFT, BOTTOMLEFT }, center = { TOP, BOTTOM }, ["end"] = { TOPRIGHT, BOTTOMRIGHT } },
    above = { vertical = true, sign = -1, start = { BOTTOMLEFT, TOPLEFT }, center = { BOTTOM, TOP }, ["end"] = { BOTTOMRIGHT, TOPRIGHT } },
    right = { vertical = false, sign = 1, start = { TOPLEFT, TOPRIGHT }, center = { LEFT, RIGHT }, ["end"] = { BOTTOMLEFT, BOTTOMRIGHT } },
    left = { vertical = false, sign = -1, start = { TOPRIGHT, TOPLEFT }, center = { RIGHT, LEFT }, ["end"] = { BOTTOMRIGHT, BOTTOMLEFT } },
}

-- Move mode: the windows go above the editor (Casual player Geldis: "when i press Move windows my new tracker goes
-- under main window layer, so to move it i need to close main window" -- the editor and the trackers share the low
-- tier, and clicking the editor's button brought it to the front). Back to their own tier when locked.
function Display:ApplyTier()
    local tier = DT.unlocked and DT_MEDIUM or self.baseTier
    if tier and tier ~= self.tier then self.window:SetDrawTier(tier); self.tier = tier end
end
function D.ApplyTiers()
    for _, d in pairs(displays) do d:ApplyTier() end
end

function D.ApplyPositions()
    local byId = DT.Engine.byId
    for id, d in pairs(displays) do
        local t = byId[id]
        if t then
            local w = d.window
            local p = t.position
            w:ClearAnchors()
            local target = not D.NO_WINDOW[t.display.type] and AnchorTarget(t, byId)
            if D.NO_WINDOW[t.display.type] then
                w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
                w:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
            elseif target then
                local tw, gap, shift = target.window, p.gap, p.anchorShift or 0
                local a = ATTACH[p.anchorSide] or ATTACH.below
                local pts = a[p.anchorAlign] or a.start
                if a.vertical then
                    w:SetAnchor(pts[1], tw, pts[2], shift, a.sign * gap)
                else
                    w:SetAnchor(pts[1], tw, pts[2], a.sign * gap, shift)
                end
            else
                w:SetAnchor(GrowPoint(t.display.grow), GuiRoot, CENTER, p.x, p.y)
            end
        end
    end
end

function D.Sync(trackers)
    local keep = {}
    for _, t in ipairs(trackers) do
        keep[t.id] = true
        local d = displays[t.id]
        if not d then
            d = table.remove(spare) or NewDisplay()
            displays[t.id] = d
        end
        d:Configure(t)
    end
    for id, d in pairs(displays) do
        if not keep[id] then
            d:Release()
            spare[#spare + 1] = d
            displays[id] = nil
        end
    end
    D.ApplyPositions()
end

-- Make displays visible inside another scene too (the editor, for live WYSIWYG editing).
-- Is the editor on screen, so clicking a tracker window opens it there?
function D.ClickToEdit()
    local ui = DT.UI
    return ui ~= nil and ui.window ~= nil and not ui.window:IsHidden()
end

function D.AddScene(scene)
    D.extraScenes[#D.extraScenes + 1] = scene
    for _, d in pairs(displays) do scene:AddFragment(d.fragment) end
    for _, d in ipairs(spare) do scene:AddFragment(d.fragment) end
end

function D.HideAll()
    for _, d in pairs(displays) do d:Hide() end
end
