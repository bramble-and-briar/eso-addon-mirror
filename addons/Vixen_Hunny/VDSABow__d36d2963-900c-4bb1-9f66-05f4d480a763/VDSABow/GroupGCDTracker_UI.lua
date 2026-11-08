-- =============================================================================
-- GroupGCDTracker_UI.lua  v2.0  —  HUD
-- =============================================================================
--   ┌──────────────────────────────────────────────┐
--   │ Group GCD Tracker                       4/12 │  title (optional)
--   │▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀│  trans-pride stripe
--   │ MEMBER              GCD          DET         │  column headers (optional)
--   │ ◆ Name            [██ 0.6 ░░░]  [████ 5.2 ░] │  one row per member
--   └──────────────────────────────────────────────┘
-- All sizes are derived from the font-size settings, so text never overflows.
-- Timer text sits on top of its bar.  Rows armed with a detonation get a pink
-- tint, and a detonation flashes "DET!" for a moment when it goes off.
--
-- Slash: /ggcdui [lock | unlock | reset | help]
-- =============================================================================

local T  = GroupGCDTracker
local WM = WINDOW_MANAGER

local MAX_ROWS   = T.MAX_GROUP
local UPDATE_MS  = 50
local GCD_LOW_AT = 0.30   -- GCD bar starts blending to "ending" colour
local DET_LOW_AT = 0.40   -- DET bar starts blending to "imminent" colour
local BOOM_MS    = 1500   -- how long "DET!" stays up after a detonation

local FILL_TEX  = "/esoui/art/miscellaneous/progressbar_genericfill.dds"
local FONT_BOLD = "EsoUI/Common/Fonts/Univers67.otf"
local FONT_REG  = "EsoUI/Common/Fonts/Univers57.otf"

local BLUE  = { 0.357, 0.812, 0.980, 1 }
local PINK  = { 0.961, 0.663, 0.722, 1 }
local WHITE = { 1, 1, 1, 1 }

local THEME = {
    BG        = { 0.035, 0.070, 0.120, 0.90 },
    BORDER    = { 0.357, 0.812, 0.980, 0.45 },
    TRACK     = { 0.000, 0.000, 0.000, 0.50 },
    ROW_ALT   = { 1.000, 1.000, 1.000, 0.035 },
    ROW_NONE  = { 0, 0, 0, 0 },
    ROW_ARMED = { 0.961, 0.663, 0.722, 0.18 },
    SUBTLE    = { 0.620, 0.660, 0.720, 0.90 },
    IDLE_TEXT = { 0.620, 0.660, 0.720, 0.70 },
    OFFLINE   = { 0.450, 0.450, 0.480, 0.80 },
    STRIPE    = { BLUE, PINK, WHITE, PINK, BLUE },
}

local ROLE_SORT = {}
local ROLE_ICON_FALLBACK = {}
if LFG_ROLE_TANK then
    ROLE_SORT[LFG_ROLE_TANK] = 1
    ROLE_SORT[LFG_ROLE_HEAL] = 2
    ROLE_SORT[LFG_ROLE_DPS]  = 3
    ROLE_ICON_FALLBACK[LFG_ROLE_TANK] = "/esoui/art/lfg/lfg_icon_tank.dds"
    ROLE_ICON_FALLBACK[LFG_ROLE_HEAL] = "/esoui/art/lfg/lfg_icon_healer.dds"
    ROLE_ICON_FALLBACK[LFG_ROLE_DPS]  = "/esoui/art/lfg/lfg_icon_dps.dds"
end

-- ─── State ────────────────────────────────────────────────────────────────────
local frame, fragment, fragmentAdded
local chrome = {}          -- background, border, stripe, header controls
local rows   = {}          -- pool of MAX_ROWS rows
local L      = {}          -- current computed layout
local roster, prevRoster = {}, {}
local boomUntil = {}       -- [stateTag] = ms when the "DET!" flash ends

-- ─── Small helpers ────────────────────────────────────────────────────────────

local function Font(face, size, shadow) return string.format("%s|%d|%s", face, size, shadow) end

local function Lerp(t, a, b)
    return a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2]),
           a[3] + t * (b[3] - a[3]), a[4] + t * (b[4] - a[4])
end

local function Place(ctrl, x, y, w, h)
    ctrl:ClearAnchors()
    ctrl:SetAnchor(TOPLEFT, frame, TOPLEFT, x, y)
    ctrl:SetDimensions(w, h)
end

-- Controls are created visible with real dimensions, then hidden if needed.
-- (xb1cert/console quirk: controls born hidden may never render later.)
local function Tex(color)
    local c = WM:CreateControl(nil, frame, CT_TEXTURE)
    c:SetColor(unpack(color))
    c:SetDimensions(1, 1)
    c:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    c:SetHidden(false)
    return c
end

local function Label(align)
    local c = WM:CreateControl(nil, frame, CT_LABEL)
    c:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c:SetMaxLineCount(1)
    c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    c:SetDimensions(10, 10)
    c:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    c:SetText("")
    c:SetHidden(false)
    return c
end

local function Bar()
    local c = WM:CreateControl(nil, frame, CT_STATUSBAR)
    c:SetTexture(FILL_TEX)
    c:SetMinMax(0, 1)
    c:SetValue(1)
    c:SetDimensions(10, 10)
    c:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    c:SetHidden(false)
    return c
end

local function SetBarColor(bar, r, g, b, a)
    if bar.SetGradientColors then
        bar:SetGradientColors(r * 0.55, g * 0.55, b * 0.55, a, r, g, b, a)
    else
        bar:SetColor(r, g, b, a)
    end
end

--- SetText / SetColor only when the value actually changed.
local function SetText(lbl, text)
    if lbl._text ~= text then lbl._text = text; lbl:SetText(text) end
end

local function SetColor(ctrl, c)
    if ctrl._color ~= c then ctrl._color = c; ctrl:SetColor(unpack(c)) end
end

-- ─── Roles ────────────────────────────────────────────────────────────────────

local function GetRole(tag)
    local role = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag) or 0
    if (not role or role == 0) and AreUnitsEqual(tag, "player") and GetSelectedLFGRole then
        role = GetSelectedLFGRole()
    end
    return role or 0
end

local roleIconCache = {}
local function RoleIcon(role)
    if roleIconCache[role] == nil then
        local path
        for _, fnName in ipairs({ "ZO_GetRoleIcon", "GetRoleIcon" }) do
            local fn = _G[fnName]
            if type(fn) == "function" then
                local ok, p = pcall(fn, role)
                if ok and type(p) == "string" and p ~= "" then path = p; break end
            end
        end
        roleIconCache[role] = path or ROLE_ICON_FALLBACK[role] or false
    end
    return roleIconCache[role] or nil
end

-- ─── Layout ───────────────────────────────────────────────────────────────────

local function ComputeLayout()
    local S = T.settings
    L.pad     = 8
    L.gap     = 6
    L.nameFS  = S.fontSizeName
    L.timerFS = S.fontSizeTimer
    L.hdrFS   = S.fontSizeHeader
    L.colFS   = math.max(10, zo_round(L.hdrFS * 0.62))

    L.barH   = L.timerFS + 6
    L.rowH   = math.max(L.nameFS + 6, L.barH + 6)
    L.rowGap = 2

    L.icons   = S.showRoleIcons
    L.iconSz  = L.icons and (L.nameFS + 2) or 0
    L.iconGap = L.icons and 4 or 0
    L.nameW   = zo_round(L.nameFS * 6)

    local barW = zo_round(L.timerFS * 5.5)
    L.showGCD = not S.hideGCD
    L.gcdW    = L.showGCD and barW or 0
    L.detW    = L.showGCD and barW or (barW * 2 + L.gap)

    L.iconX = L.pad
    L.nameX = L.iconX + L.iconSz + L.iconGap
    L.gcdX  = L.nameX + L.nameW + L.gap
    L.detX  = L.showGCD and (L.gcdX + L.gcdW + L.gap) or L.gcdX
    L.width = L.detX + L.detW + L.pad

    L.header  = S.showHeader
    L.stripeH = 3
    if L.header then
        L.titleH  = L.hdrFS + 10
        L.stripeY = L.titleH
        L.colHdrY = L.stripeY + L.stripeH + 3
        L.colHdrH = L.colFS + 4
        L.rowsY   = L.colHdrY + L.colHdrH + 2
    else
        L.titleH  = 0
        L.stripeY = 0
        L.rowsY   = L.stripeH + 5
    end
end

local function FrameHeight(n)
    n = math.max(1, n)
    return L.rowsY + n * L.rowH + (n - 1) * L.rowGap + L.pad - 2
end

local function RowY(i) return L.rowsY + (i - 1) * (L.rowH + L.rowGap) end

-- ─── Rows ─────────────────────────────────────────────────────────────────────

local Row = {}
Row.__index = Row

local function CreateRow()
    local r = setmetatable({}, Row)
    r.bg      = Tex(THEME.ROW_NONE)
    r.icon    = Tex(WHITE)
    r.name    = Label(TEXT_ALIGN_LEFT)
    r.gcdBg   = Tex(THEME.TRACK)
    r.gcdBar  = Bar()
    r.gcdText = Label(TEXT_ALIGN_CENTER)
    r.detBg   = Tex(THEME.TRACK)
    r.detBar  = Bar()
    r.detText = Label(TEXT_ALIGN_CENTER)
    -- Keep text above bars, bars above tracks.
    r.bg:SetDrawLevel(1)
    r.gcdBg:SetDrawLevel(2);  r.detBg:SetDrawLevel(2)
    r.gcdBar:SetDrawLevel(3); r.detBar:SetDrawLevel(3)
    r.icon:SetDrawLevel(4);   r.name:SetDrawLevel(4)
    r.gcdText:SetDrawLevel(4); r.detText:SetDrawLevel(4)
    return r
end

function Row:ApplyFonts()
    self.name:SetFont(Font(FONT_BOLD, L.nameFS, "soft-shadow-thick"))
    local tf = Font(FONT_BOLD, L.timerFS, "soft-shadow-thin")
    self.gcdText:SetFont(tf)
    self.detText:SetFont(tf)
end

function Row:Place(i)
    local y    = RowY(i)
    local barY = y + zo_round((L.rowH - L.barH) / 2)
    Place(self.bg,      L.pad / 2, y, L.width - L.pad, L.rowH)
    Place(self.icon,    L.iconX, y + zo_round((L.rowH - L.iconSz) / 2), math.max(1, L.iconSz), math.max(1, L.iconSz))
    Place(self.name,    L.nameX, y, L.nameW, L.rowH)
    Place(self.gcdBg,   L.gcdX, barY, math.max(1, L.gcdW), L.barH)
    Place(self.gcdBar,  L.gcdX, barY, math.max(1, L.gcdW), L.barH)
    Place(self.gcdText, L.gcdX, barY, math.max(1, L.gcdW), L.barH)
    Place(self.detBg,   L.detX, barY, L.detW, L.barH)
    Place(self.detBar,  L.detX, barY, L.detW, L.barH)
    Place(self.detText, L.detX, barY, L.detW, L.barH)
    self.altTint = (i % 2 == 0) and THEME.ROW_ALT or THEME.ROW_NONE
end

function Row:SetVisible(visible)
    local hide = not visible
    if hide then self.gcdBar:SetValue(0); self.detBar:SetValue(0) end
    self.bg:SetHidden(hide)
    self.name:SetHidden(hide)
    self.detBg:SetHidden(hide)
    self.detBar:SetHidden(hide)
    self.detText:SetHidden(hide)
    local hideGcd = hide or not L.showGCD
    self.gcdBg:SetHidden(hideGcd)
    self.gcdBar:SetHidden(hideGcd)
    self.gcdText:SetHidden(hideGcd)
    self.icon:SetHidden(hide or not L.icons or self._iconPath == nil)
end

function Row:Update(now)
    local S   = T.settings
    local tag = self.tag
    local st  = T:GetStateTag(tag)

    -- Name (re-formatted only when the raw name changes)
    local raw = GetUnitName(tag)
    if raw ~= self._rawName then
        self._rawName = raw
        SetText(self.name, T.CleanName(raw))
    end
    SetColor(self.name, IsUnitOnline(tag) and S.colorNameLive or THEME.OFFLINE)

    -- Role icon
    if L.icons then
        local path = RoleIcon(GetRole(tag))
        if path ~= self._iconPath then
            self._iconPath = path
            if path then self.icon:SetTexture(path) end
            self.icon:SetHidden(path == nil)
        end
    end

    -- GCD
    if L.showGCD then
        local gs = T._gcdState[st]
        if gs and gs.onGCD and gs.endTime > now then
            local rem = gs.endTime - now
            local pct = rem / math.max(1, gs.endTime - gs.startTime)
            self.gcdBar:SetValue(pct)
            if pct > GCD_LOW_AT then
                SetBarColor(self.gcdBar, unpack(S.colorGcdFull))
            else
                SetBarColor(self.gcdBar, Lerp(pct / GCD_LOW_AT, S.colorGcdLow, S.colorGcdFull))
            end
            SetText(self.gcdText, string.format("%.1f", rem / 1000))
            SetColor(self.gcdText, S.colorBarText)
        else
            self.gcdBar:SetValue(0)
            SetText(self.gcdText, gs and gs.abilityName or "")
            SetColor(self.gcdText, THEME.IDLE_TEXT)
        end
    end

    -- Detonation
    local pd    = T._proxState[st]
    local armed = pd and pd.armed
    if armed then
        local dur = math.max(1, pd.durationMs)
        local rem = math.max(0, pd.endMs - now)
        local pct = rem / dur
        self.detBar:SetValue(pct)
        if pct > DET_LOW_AT then
            SetBarColor(self.detBar, unpack(S.colorDetFull))
        else
            SetBarColor(self.detBar, Lerp(pct / DET_LOW_AT, S.colorDetHigh, S.colorDetFull))
        end
        SetText(self.detText, string.format("%.1fs", rem / 1000))
        SetColor(self.detText, S.colorBarText)
    elseif boomUntil[st] and now < boomUntil[st] then
        local t = (boomUntil[st] - now) / BOOM_MS
        self.detBar:SetValue(1)
        SetBarColor(self.detBar, PINK[1], PINK[2], PINK[3], t)
        SetText(self.detText, "DET!")
        SetColor(self.detText, WHITE)
    else
        boomUntil[st] = nil
        self.detBar:SetValue(0)
        SetText(self.detText, "")
    end

    SetColor(self.bg, armed and THEME.ROW_ARMED or self.altTint)
end

-- ─── Chrome (background, border, stripe, header) ──────────────────────────────

local function BuildChrome()
    chrome.bg      = Tex(THEME.BG)
    chrome.border  = { Tex(THEME.BORDER), Tex(THEME.BORDER), Tex(THEME.BORDER), Tex(THEME.BORDER) }
    chrome.stripe  = {}
    for i, c in ipairs(THEME.STRIPE) do chrome.stripe[i] = Tex(c) end
    chrome.title   = Label(TEXT_ALIGN_LEFT)
    chrome.count   = Label(TEXT_ALIGN_RIGHT)
    chrome.hMember = Label(TEXT_ALIGN_LEFT)
    chrome.hGcd    = Label(TEXT_ALIGN_CENTER)
    chrome.hDet    = Label(TEXT_ALIGN_CENTER)

    chrome.bg:SetDrawLevel(0)
    chrome.title:SetText(string.format("|c%sGroup|r |c%sGCD|r |c%sTracker|r", T.HEX.BLUE, T.HEX.PINK, T.HEX.WHITE))
    chrome.count:SetColor(unpack(THEME.SUBTLE))
    chrome.hMember:SetText("MEMBER");  chrome.hMember:SetColor(unpack(THEME.SUBTLE))
    chrome.hGcd:SetText("GCD");        chrome.hGcd:SetColor(unpack(BLUE))
    chrome.hDet:SetText("DET");        chrome.hDet:SetColor(unpack(PINK))
end

local function LayoutChrome(h)
    local w = L.width
    Place(chrome.bg, 0, 0, w, h)
    local b = chrome.border
    Place(b[1], 0, 0, w, 1)
    Place(b[2], 0, h - 1, w, 1)
    Place(b[3], 0, 0, 1, h)
    Place(b[4], w - 1, 0, 1, h)

    local segW = (w - 2) / #chrome.stripe
    for i, s in ipairs(chrome.stripe) do
        Place(s, 1 + zo_round((i - 1) * segW), L.stripeY, zo_round(segW) + 1, L.stripeH)
    end

    local hdr = L.header
    for _, c in ipairs({ chrome.title, chrome.count, chrome.hMember, chrome.hGcd, chrome.hDet }) do
        c:SetHidden(not hdr)
    end
    if not hdr then return end

    chrome.title:SetFont(Font(FONT_BOLD, L.hdrFS, "soft-shadow-thick"))
    chrome.count:SetFont(Font(FONT_REG, L.colFS + 2, "soft-shadow-thin"))
    local cf = Font(FONT_BOLD, L.colFS, "soft-shadow-thin")
    chrome.hMember:SetFont(cf); chrome.hGcd:SetFont(cf); chrome.hDet:SetFont(cf)

    Place(chrome.title, L.pad, 0, w - L.pad * 2 - 50, L.titleH)
    Place(chrome.count, w - L.pad - 50, 0, 50, L.titleH)
    Place(chrome.hMember, L.iconX, L.colHdrY, L.nameW + L.iconSz + L.iconGap, L.colHdrH)
    Place(chrome.hGcd, L.gcdX, L.colHdrY, math.max(1, L.gcdW), L.colHdrH)
    Place(chrome.hDet, L.detX, L.colHdrY, L.detW, L.colHdrH)
    chrome.hGcd:SetHidden(not L.showGCD)
end

-- ─── Roster ───────────────────────────────────────────────────────────────────

local sortRole, sortIndex = {}, {}
local function RosterCompare(a, b)
    if sortRole[a] ~= sortRole[b] then return sortRole[a] < sortRole[b] end
    return sortIndex[a] < sortIndex[b]
end

local function BuildRoster()
    local n = 0
    for i = 1, math.min(GetGroupSize(), MAX_ROWS) do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and DoesUnitExist(tag) then
            n = n + 1
            roster[n] = tag
            sortIndex[tag] = i
            sortRole[tag]  = ROLE_SORT[GetRole(tag)] or 4
        end
    end
    if n == 0 then roster[1] = "player"; n = 1 end
    for i = n + 1, #roster do roster[i] = nil end
    if n > 1 and T.settings.sortByRole then table.sort(roster, RosterCompare) end
    return n
end

local function ScaleToFit()
    local fit = math.min(GuiRoot:GetWidth() / frame:GetWidth(), GuiRoot:GetHeight() / frame:GetHeight()) * 0.97
    frame:SetScale(math.min(T.settings.uiScale, fit))
end

local function ApplyRoster(n)
    for i = 1, MAX_ROWS do
        local r = rows[i]
        if i <= n then
            r.tag = roster[i]
            r._rawName = nil
            r:SetVisible(true)
        else
            r.tag = nil
            r:SetVisible(false)
        end
        prevRoster[i] = roster[i]
    end
    local h = FrameHeight(n)
    frame:SetDimensions(L.width, h)
    LayoutChrome(h)
    ScaleToFit()
    local size = GetGroupSize()
    SetText(chrome.count, size > 0 and string.format("%d/%d", size, MAX_ROWS) or "solo")
end

local function RosterChanged()
    for i = 1, MAX_ROWS do
        if prevRoster[i] ~= roster[i] then return true end
    end
    return false
end

local function Tick()
    if not frame or frame:IsHidden() then return end
    local n = BuildRoster()
    if RosterChanged() then ApplyRoster(n) end
    local now = GetGameTimeMilliseconds()
    for i = 1, n do rows[i]:Update(now) end
end

-- ─── Visibility & position ────────────────────────────────────────────────────

local function UpdateVisibility()
    local S    = T.settings
    local want = S.showUI and S.enabled
    if fragment and S.hideInMenus and want then
        if not fragmentAdded then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
            fragmentAdded = true
        end
        if HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing() then frame:SetHidden(false) end
    else
        if fragmentAdded then
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
            fragmentAdded = false
        end
        frame:SetHidden(not want)
    end
end

local function AnchorFromSettings()
    local S = T.settings
    frame:ClearAnchors()
    if S.uiX and S.uiY then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S.uiX, S.uiY)
    else
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

-- ─── Build ────────────────────────────────────────────────────────────────────

local function BuildFrame()
    frame = WM:CreateTopLevelWindow("GroupGCDTrackerFrame")
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(true)
    frame:SetHandler("OnMoveStop", function(ctrl)
        T.settings.uiX, T.settings.uiY = ctrl:GetLeft(), ctrl:GetTop()
        AnchorFromSettings()
    end)

    ComputeLayout()
    frame:SetDimensions(L.width, FrameHeight(1))
    BuildChrome()
    for i = 1, MAX_ROWS do
        rows[i] = CreateRow()
        rows[i]:ApplyFonts()
        rows[i]:Place(i)
        rows[i]:SetVisible(false)   -- prime: created visible, hidden same tick
    end
    AnchorFromSettings()

    if ZO_SimpleSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        fragment = ZO_SimpleSceneFragment:New(frame)
    end

    T:RegisterCallback("PROX_DET_TRIGGERED", function(tag)
        boomUntil[tag] = GetGameTimeMilliseconds() + BOOM_MS
    end)

    -- Ticker lives on EVENT_MANAGER so it survives the frame being hidden.
    EVENT_MANAGER:UnregisterForUpdate(T.NAME .. "_UI")
    EVENT_MANAGER:RegisterForUpdate(T.NAME .. "_UI", UPDATE_MS, Tick)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Re-apply every setting (fonts, layout, colours, opacity, scale, visibility).
function T:RefreshUI()
    if not frame then return end
    local S = self.settings
    ComputeLayout()
    for i = 1, MAX_ROWS do
        local r = rows[i]
        r:ApplyFonts()
        r:Place(i)
        r._iconPath = false   -- force icon refresh
        r.name._color, r.gcdText._color, r.detText._color, r.bg._color = nil, nil, nil, nil
    end
    for i = 1, MAX_ROWS do prevRoster[i] = nil end   -- force roster re-apply
    local n = BuildRoster()
    ApplyRoster(n)
    frame:SetAlpha(S.uiOpacity)
    frame:SetMovable(not S.lockPosition)
    UpdateVisibility()
end

function T:SetUIVisible(visible)
    self.settings.showUI = visible
    if frame then UpdateVisibility() end
end

function T:ToggleUI() self:SetUIVisible(not self.settings.showUI) end

function T:SetUIOpacity(alpha)
    self.settings.uiOpacity = alpha
    if frame then frame:SetAlpha(alpha) end
end

function T:SetUIScale(scale)
    self.settings.uiScale = scale
    if frame then ScaleToFit() end
end

function T:MoveUITo(x, y)
    self.settings.uiX, self.settings.uiY = x, y
    if frame then AnchorFromSettings() end
end

function T:ResetUIPosition()
    self.settings.uiX, self.settings.uiY = nil, nil
    if frame then AnchorFromSettings() end
end

-- Backwards-compatible alias for older callers.
function T:RefreshFonts() self:RefreshUI() end

local function SlashCommand(arg)
    arg = zo_strlower(zo_strtrim(arg or ""))
    local S = T.settings
    if arg == "lock" or arg == "unlock" then
        S.lockPosition = (arg == "lock")
        T:RefreshUI()
        T.Print("HUD %s.", arg == "lock" and "locked" or "unlocked")
    elseif arg == "reset" then
        T:ResetUIPosition()
        T.Print("HUD position reset.")
    elseif arg == "help" then
        T.Print("/ggcdui — toggle HUD · lock · unlock · reset  |  /ggcdt — settings")
    else
        T:ToggleUI()
    end
end

function T:InitUI()
    BuildFrame()
    self:RefreshUI()
    SLASH_COMMANDS["/ggcdui"] = SlashCommand
end
