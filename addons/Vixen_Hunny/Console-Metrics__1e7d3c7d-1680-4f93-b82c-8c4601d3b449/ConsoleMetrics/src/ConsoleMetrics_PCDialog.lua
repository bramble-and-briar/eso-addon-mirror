-- ConsoleMetrics_PCDialog.lua
-- Full keyboard/mouse dialog for ConsoleMetrics on PC.
-- Replaces the LibConsoleDialogs / LibHarvensAddonSettings gamepad flow with
-- a native ESO top-level scrollable window that works with mouse & keyboard.

local WM = WINDOW_MANAGER

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local WIN_W        = 800
local WIN_H        = 860
local TITLE_H      = 56
local NAV_H        = 48
local TOOLTIP_H    = 70          -- bottom info bar
local PADDING      = 14
local SB_W         = 16          -- scrollbar width
local CONTENT_W    = WIN_W - PADDING * 2 - SB_W - 4
local SECTION_H    = 38
local STAT_H       = 32
local BTN_H        = 40
local BTN_PAD      = 6
local FONT_TITLE   = "ZoFontGamepad34"
local FONT_SECTION = "ZoFontGamepad27"
local FONT_STAT    = "ZoFontGamepad22"
local FONT_BTN     = "ZoFontGamepad22"
local COL_BG       = { 0.05, 0.05, 0.08, 0.96 }
local COL_TITLE_BG = { 0.10, 0.10, 0.16, 1.00 }
local COL_SECTION  = { 0.18, 0.18, 0.28, 1.00 }
local COL_EDGE     = { 0.30, 0.30, 0.50, 0.80 }
local COL_STAT_TXT = { 0.90, 0.90, 0.90, 1.00 }
local COL_BTN_NORM = { 0.20, 0.26, 0.38, 1.00 }
local COL_BTN_HOVR = { 0.30, 0.38, 0.54, 1.00 }
local COL_BTN_PRES = { 0.14, 0.18, 0.26, 1.00 }
local COL_BTN_TXT  = { 0.95, 0.95, 1.00, 1.00 }

-------------------------------------------------------------------------------
-- Internals
-------------------------------------------------------------------------------
local pcDlg = {}          -- module table (not exposed globally)
ConsoleMetrics.pcDlg = pcDlg

-- Tracks controls that need to be destroyed when clearing the panel.
local dynamicControls = {}
local contentHeight   = 0
local currentPanel    = "main"
local currentScrollPos = 0    -- manual scroll offset in pixels
local lastRenderedPanel = nil  -- detect panel changes to reset scroll
local ScrollContent  -- forward declaration; defined below CreatePCDialog

-------------------------------------------------------------------------------
-- Helper: make a backdrop control
-------------------------------------------------------------------------------
local function MakeBD(name, parent, r, g, b, a, er, eg, eb, ea)
    local bd = WM:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(r, g, b, a)
    bd:SetEdgeColor(er or COL_EDGE[1], eg or COL_EDGE[2], eb or COL_EDGE[3], ea or COL_EDGE[4])
    bd:SetEdgeTexture(nil, 1, 1, 0, 0)
    return bd
end

-------------------------------------------------------------------------------
-- Build the persistent window skeleton (called once)
-------------------------------------------------------------------------------
function ConsoleMetrics:CreatePCDialog()
    if pcDlg.window then return end

    local win = WM:CreateTopLevelWindow("ConsoleMetricsPCWin")
    win:SetDimensions(WIN_W, WIN_H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    pcDlg.window = win

    -- background
    local bg = MakeBD("$(parent)BG", win, COL_BG[1], COL_BG[2], COL_BG[3], COL_BG[4])
    bg:SetAnchorFill(win)

    -- title bar
    local titleBG = MakeBD("$(parent)TitleBG", win,
        COL_TITLE_BG[1], COL_TITLE_BG[2], COL_TITLE_BG[3], COL_TITLE_BG[4])
    titleBG:SetAnchor(TOPLEFT,     win, TOPLEFT,     0, 0)
    titleBG:SetAnchor(TOPRIGHT,    win, TOPRIGHT,    0, 0)
    titleBG:SetHeight(TITLE_H)

    local titleLabel = WM:CreateControl("$(parent)Title", titleBG, CT_LABEL)
    titleLabel:SetFont(FONT_TITLE)
    titleLabel:SetColor(1, 1, 1, 1)
    titleLabel:SetText("Console Metrics")
    titleLabel:SetAnchor(LEFT, titleBG, LEFT, PADDING, 0)
    pcDlg.titleLabel = titleLabel

    -- close button  [X]
    local closeBtn = WM:CreateControl("$(parent)Close", win, CT_BUTTON)
    closeBtn:SetDimensions(28, 28)
    closeBtn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -4, 4)
    closeBtn:SetText("X")
    closeBtn:SetFont(FONT_SECTION)
    closeBtn:SetNormalFontColor(1, 0.4, 0.4, 1)
    closeBtn:SetHandler("OnClicked", function()
        ConsoleMetrics:ClosePCDialog()
    end)

    -- nav bar (Back + breadcrumb)
    local navBG = MakeBD("$(parent)NavBG", win,
        COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], COL_SECTION[4])
    navBG:SetAnchor(TOPLEFT,  win, TOPLEFT,  0,      TITLE_H)
    navBG:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0,      TITLE_H)
    navBG:SetHeight(NAV_H)

    local backBtn = WM:CreateControl("$(parent)Back", navBG, CT_BUTTON)
    backBtn:SetDimensions(60, NAV_H - 6)
    backBtn:SetText("< Back")
    backBtn:SetFont(FONT_STAT)
    backBtn:SetNormalFontColor(0.8, 0.9, 1, 1)
    backBtn:SetAnchor(LEFT, navBG, LEFT, PADDING, 0)
    backBtn:SetHandler("OnClicked", function()
        ConsoleMetrics.dialogPanel = "main"
        ConsoleMetrics:RefreshPCDialog()
    end)
    pcDlg.backBtn = backBtn

    local breadcrumb = WM:CreateControl("$(parent)Breadcrumb", navBG, CT_LABEL)
    breadcrumb:SetFont(FONT_SECTION)
    breadcrumb:SetColor(0.85, 0.85, 1, 1)
    breadcrumb:SetAnchor(LEFT, backBtn, RIGHT, 8, 0)
    pcDlg.breadcrumb = breadcrumb

    -- viewport: plain CT_CONTROL that clips overflow children naturally
    local scrollTop = TITLE_H + NAV_H + PADDING

    local scrollFrame = WM:CreateControl("$(parent)Scroll", win, CT_CONTROL)
    scrollFrame:SetAnchor(TOPLEFT,     win, TOPLEFT,  PADDING,           scrollTop)
    scrollFrame:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(PADDING + SB_W + 4), TOOLTIP_H + PADDING)
    scrollFrame:SetMouseEnabled(true)
    scrollFrame:SetHandler("OnMouseWheel", function(_, delta) ScrollContent(delta) end)
    -- Clip children to the visible viewport so content above/below the frame is hidden
    pcall(function() scrollFrame:SetClipChildren(true) end)
    pcDlg.scrollFrame = scrollFrame

    -- scrollbar track (also stops above tooltip bar)
    local sbTrack = MakeBD("$(parent)SBTrack", win, 0.10, 0.10, 0.16, 0.95,
        0.25, 0.25, 0.40, 0.80)
    sbTrack:SetWidth(SB_W)
    sbTrack:SetAnchor(TOPRIGHT,    win, TOPRIGHT, -PADDING, scrollTop)
    sbTrack:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PADDING, TOOLTIP_H + PADDING)
    sbTrack:SetMouseEnabled(true)
    pcDlg.sbTrack = sbTrack

    -- scrollbar thumb
    local sbThumb = MakeBD("$(parent)SBThumb", win, 0.45, 0.50, 0.75, 0.95,
        0.60, 0.65, 0.90, 1.00)
    sbThumb:SetWidth(SB_W)
    sbThumb:SetHeight(60)
    sbThumb:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PADDING, scrollTop)
    sbThumb:SetMouseEnabled(true)
    pcDlg.sbThumb = sbThumb
    pcDlg.sbDragging = false
    pcDlg.sbDragStartY = 0
    pcDlg.sbDragStartScroll = 0

    -- thumb drag handlers
    sbThumb:SetHandler("OnMouseDown", function(ctrl, btn)
        if btn ~= 1 then return end
        pcDlg.sbDragging = true
        pcDlg.sbDragStartY = select(2, GetCursorPosition())
        pcDlg.sbDragStartScroll = currentScrollPos
    end)
    sbThumb:SetHandler("OnMouseUp", function()
        pcDlg.sbDragging = false
    end)
    sbThumb:SetHandler("OnUpdate", function()
        if not pcDlg.sbDragging then return end
        local _, curY = GetCursorPosition()
        local deltaY  = pcDlg.sbDragStartY - curY
        local trackH  = sbTrack:GetHeight()
        local thumbH  = sbThumb:GetHeight()
        local visH    = scrollFrame:GetHeight()
        local totalH  = pcDlg.content:GetHeight()
        local maxScroll = math.max(0, totalH - visH)
        if trackH <= thumbH then return end
        local scrollDelta = deltaY * maxScroll / (trackH - thumbH)
        local newScroll = math.max(0, math.min(maxScroll,
            pcDlg.sbDragStartScroll + scrollDelta))
        ConsoleMetrics:SetScrollPos(newScroll)
    end)

    -- track click: jump to position
    sbTrack:SetHandler("OnMouseDown", function(ctrl, btn)
        if btn ~= 1 then return end
        local _, curY    = GetCursorPosition()
        local _, trackY  = sbTrack:GetScreenRect()
        local trackH     = sbTrack:GetHeight()
        local visH       = scrollFrame:GetHeight()
        local totalH     = pcDlg.content:GetHeight()
        local maxScroll  = math.max(0, totalH - visH)
        local frac       = math.max(0, math.min(1, (curY - trackY) / trackH))
        ConsoleMetrics:SetScrollPos(frac * maxScroll)
    end)

    -- mousewheel (also handled by children via Track → ScrollContent)
    scrollFrame:SetHandler("OnMouseWheel", function(_, delta)
        ScrollContent(delta)
    end)

    -- window-level catch-all so the wheel works even when hovering the title / nav bar
    win:SetHandler("OnMouseWheel", function(_, delta)
        ScrollContent(delta)
    end)

    -- Close dialog on controller / keyboard movement when the option is enabled.
    win:SetHandler("OnUpdate", function()
        if not pcDlg.window or pcDlg.window:IsHidden() then return end
        if ConsoleMetrics.saved and ConsoleMetrics.saved.closeOnMove then
            if type(IsPlayerMoving) == "function" and IsPlayerMoving() then
                ConsoleMetrics:ClosePCDialog()
            end
        end
    end)

    -- content container inside scroll
    local content = WM:CreateControl("$(parent)Content", scrollFrame, CT_CONTROL)
    content:SetWidth(CONTENT_W)
    content:SetHeight(100)
    content:SetAnchor(TOPLEFT, scrollFrame, TOPLEFT, 0, 0)
    pcDlg.content = content

    -- tooltip / info bar at the bottom of the window
    local ttBG = MakeBD("$(parent)TTBar", win, 0.08, 0.08, 0.14, 0.97,
        0.30, 0.35, 0.55, 0.90)
    ttBG:SetAnchor(BOTTOMLEFT,  win, BOTTOMLEFT,  0, 0)
    ttBG:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, 0, 0)
    ttBG:SetHeight(TOOLTIP_H)

    local ttLabel = WM:CreateControl("$(parent)TTText", ttBG, CT_LABEL)
    ttLabel:SetFont(FONT_STAT)
    ttLabel:SetColor(1, 1, 0.80, 1)
    ttLabel:SetAnchor(TOPLEFT,     ttBG, TOPLEFT,     PADDING, 6)
    ttLabel:SetAnchor(BOTTOMRIGHT, ttBG, BOTTOMRIGHT, -PADDING, -6)
    ttLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    ttLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    ttLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    ttLabel:SetText("")
    pcDlg.ttLabel = ttLabel
end

-------------------------------------------------------------------------------
-- Open / close
-------------------------------------------------------------------------------
function ConsoleMetrics:OpenPCDialog(forceLive)
    self:CreatePCDialog()
    if forceLive then
        self.viewFightIndex = 0
        self.dialogPanel    = "main"
    elseif not self.dialogPanel then
        self.dialogPanel = "main"
    end
    pcDlg.window:SetHidden(false)
    pcDlg.window:BringWindowToTop()
    lastRenderedPanel = nil  -- force scroll-to-top on first render
    self:RefreshPCDialog()
    self.wasFightViewDialogShowing = true
    self.dialogRefreshAtMs   = 0
    self.lastDialogRefreshKey = nil
    self:ArmDialogAutoHide()
end

function ConsoleMetrics:ClosePCDialog()
    if pcDlg.window then
        pcDlg.window:SetHidden(true)
    end
    self.wasFightViewDialogShowing = false
end

function ConsoleMetrics:IsFightViewDialogShowingPC()
    return pcDlg.window ~= nil and not pcDlg.window:IsHidden()
end

-------------------------------------------------------------------------------
-- Tooltip helpers (update the bottom info bar)
-------------------------------------------------------------------------------
local function ShowCMTooltip(text)
    if pcDlg.ttLabel then
        pcDlg.ttLabel:SetText(text or "")
    end
end

local function HideCMTooltip()
    if pcDlg.ttLabel then
        pcDlg.ttLabel:SetText("")
    end
end

-------------------------------------------------------------------------------
-- Shared scroll helper
-------------------------------------------------------------------------------
ScrollContent = function(delta)
    local sf = pcDlg.scrollFrame
    if not sf then return end
    local visH      = sf:GetHeight()
    local totalH    = pcDlg.content and pcDlg.content:GetHeight() or 0
    local maxScroll = math.max(0, totalH - visH)
    ConsoleMetrics:SetScrollPos(currentScrollPos - delta * 60)
end

-------------------------------------------------------------------------------
-- SetScrollPos: move the content container by anchor offset
-------------------------------------------------------------------------------
function ConsoleMetrics:SetScrollPos(pos)
    local sf = pcDlg.scrollFrame
    if not sf or not pcDlg.content then return end
    local visH      = sf:GetHeight()
    local totalH    = pcDlg.content:GetHeight()
    local maxScroll = math.max(0, totalH - visH)
    currentScrollPos = math.max(0, math.min(maxScroll, pos))
    pcDlg.content:ClearAnchors()
    pcDlg.content:SetAnchor(TOPLEFT, sf, TOPLEFT, 0, -currentScrollPos)
    self:UpdateScrollThumb()
end

-------------------------------------------------------------------------------
-- Content builder helpers
-------------------------------------------------------------------------------
local function ClearDynamic()
    for i = 1, #dynamicControls do
        local ctrl = dynamicControls[i]
        ctrl:SetHidden(true)
        -- Clear anchors BEFORE unparenting so the layout engine no longer
        -- traces these controls when resolving content's anchor dependencies.
        -- Without this, orphaned controls accumulate anchor references to
        -- content across refreshes and eventually trigger "too many anchors".
        pcall(function() ctrl:ClearAnchors() end)
        ctrl:SetParent(nil)
    end
    dynamicControls = {}
    contentHeight   = 0
end

local ctrlIdx = 0
local function NextName()
    ctrlIdx = ctrlIdx + 1
    return "CMPCCtrl" .. ctrlIdx
end

local function Track(ctrl)
    dynamicControls[#dynamicControls + 1] = ctrl
    -- Forward wheel events from every child so they always reach the scroll logic
    pcall(function()
        ctrl:SetHandler("OnMouseWheel", function(_, delta) ScrollContent(delta) end)
    end)
    return ctrl
end

local function AdvanceCursor(h, extra)
    contentHeight = contentHeight + h + (extra or 0)
end

local function ContentY()
    return contentHeight   -- top edge for next item
end

-- Section header
local function AddSection(content, text)
    local y = ContentY()
    local bd = MakeBD(NextName(), content,
        COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 0.85)
    bd:SetAnchor(TOPLEFT,  content, TOPLEFT,  0,         y)
    bd:SetAnchor(TOPRIGHT, content, TOPRIGHT, 0,         y)
    bd:SetHeight(SECTION_H)
    Track(bd)

    local lbl = WM:CreateControl(NextName(), bd, CT_LABEL)
    lbl:SetFont(FONT_SECTION)
    lbl:SetColor(1, 0.88, 0.55, 1)
    lbl:SetText(text)
    lbl:SetAnchor(LEFT, bd, LEFT, PADDING, 0)
    Track(lbl)

    AdvanceCursor(SECTION_H, 4)
end

-- Stat line (left label, optional right value)
local function AddStat(content, leftText, rightText, tooltip)
    local y = ContentY()
    local lbl = WM:CreateControl(NextName(), content, CT_LABEL)
    lbl:SetFont(FONT_STAT)
    lbl:SetColor(COL_STAT_TXT[1], COL_STAT_TXT[2], COL_STAT_TXT[3], COL_STAT_TXT[4])
    lbl:SetText(leftText or "")
    lbl:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, y + 2)
    lbl:SetWidth(rightText and (CONTENT_W * 0.65) or (CONTENT_W - PADDING * 2))
    lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    Track(lbl)

    if rightText then
        local rbl = WM:CreateControl(NextName(), content, CT_LABEL)
        rbl:SetFont(FONT_STAT)
        rbl:SetColor(0.70, 0.90, 0.70, 1)
        rbl:SetText(tostring(rightText))
        rbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        rbl:SetAnchor(TOPRIGHT, content, TOPRIGHT, -PADDING, y + 2)
        rbl:SetWidth(CONTENT_W * 0.30)
        Track(rbl)
    end

    if tooltip then
        lbl:SetMouseEnabled(true)
        lbl:SetHandler("OnMouseEnter", function() ShowCMTooltip(tooltip) end)
        lbl:SetHandler("OnMouseExit",  function() HideCMTooltip() end)
    end

    AdvanceCursor(STAT_H, 2)
end

-- Clickable action button
local function AddButton(content, labelText, tooltip, callback, disabled)
    local y = ContentY()
    local btn = WM:CreateControl(NextName(), content, CT_BUTTON)
    btn:SetDimensions(CONTENT_W - PADDING * 2, BTN_H)
    btn:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, y)
    btn:SetText(labelText)
    btn:SetFont(FONT_STAT)
    btn:SetNormalFontColor(COL_BTN_TXT[1], COL_BTN_TXT[2], COL_BTN_TXT[3], COL_BTN_TXT[4])
    btn:SetMouseEnabled(not disabled)
    if disabled then
        btn:SetNormalFontColor(0.5, 0.5, 0.5, 1)
    end
    Track(btn)

    if tooltip then
        btn:SetHandler("OnMouseEnter", function() ShowCMTooltip(tooltip) end)
        btn:SetHandler("OnMouseExit",  function() HideCMTooltip() end)
    end

    if callback then
        btn:SetHandler("OnClicked", function()
            callback()
            ConsoleMetrics:RefreshPCDialog()
        end)
    end

    AdvanceCursor(BTN_H, BTN_PAD)
end

-- Text edit field (for save-name inputs etc.)
local function AddEditBox(content, labelText, getter, setter, maxChars)
    local y = ContentY()

    local lbl = WM:CreateControl(NextName(), content, CT_LABEL)
    lbl:SetFont(FONT_STAT)
    lbl:SetColor(COL_STAT_TXT[1], COL_STAT_TXT[2], COL_STAT_TXT[3], 1)
    lbl:SetText(labelText or "")
    lbl:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, y + 2)
    Track(lbl)
    AdvanceCursor(STAT_H, 2)

    local editH = STAT_H + 8   -- tall enough for ZoFontGamepad22
    local editBG = MakeBD(NextName(), content, 0.10, 0.10, 0.10, 1, 0.5, 0.5, 0.7, 1)
    editBG:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, ContentY())
    editBG:SetDimensions(CONTENT_W - PADDING * 2, editH)
    editBG:SetMouseEnabled(false)   -- let clicks pass through to the edit control
    Track(editBG)

    local edit = WM:CreateControl(NextName(), editBG, CT_EDITBOX)
    edit:SetFont(FONT_STAT)
    edit:SetAnchorFill(editBG)
    edit:SetMaxInputChars(maxChars or 80)
    edit:SetText(getter and getter() or "")
    edit:SetAllowMarkupType(ALLOW_MARKUP_TYPE_NONE)
    edit:SetMultiLine(false)
    edit:SetMouseEnabled(true)
    -- Click or gamepad confirm focuses the box
    edit:SetHandler("OnMouseDown", function(self)
        self:TakeFocus()
    end)
    edit:SetHandler("OnTextChanged", function(self)
        if setter then setter(self:GetText()) end
    end)
    edit:SetHandler("OnFocusLost", function(self)
        -- commit final value when focus leaves
        if setter then setter(self:GetText()) end
    end)
    Track(edit)

    AdvanceCursor(editH, BTN_PAD)
    return edit
end

-- Horizontal divider
local function AddDivider(content)
    local y = ContentY()
    local line = WM:CreateControl(NextName(), content, CT_TEXTURE)
    line:SetAnchor(TOPLEFT,  content, TOPLEFT,  PADDING, y + 4)
    line:SetAnchor(TOPRIGHT, content, TOPRIGHT, -PADDING, y + 4)
    line:SetHeight(1)
    line:SetColor(0.35, 0.35, 0.50, 0.60)
    Track(line)
    AdvanceCursor(9, 0)
end

-------------------------------------------------------------------------------
-- Scrollbar thumb update
-------------------------------------------------------------------------------
function ConsoleMetrics:UpdateScrollThumb()
    local thumb   = pcDlg.sbThumb
    local track   = pcDlg.sbTrack
    local sf      = pcDlg.scrollFrame
    if not thumb or not track or not sf then return end

    local visH    = sf:GetHeight()
    local totalH  = pcDlg.content:GetHeight()

    if totalH <= visH then
        thumb:SetHidden(true)
        return
    end
    thumb:SetHidden(false)

    local trackH  = track:GetHeight()
    local thumbH  = math.max(30, math.floor(trackH * visH / totalH))
    thumb:SetHeight(thumbH)

    local maxScroll  = totalH - visH
    local scrollPos  = math.max(0, math.min(maxScroll, currentScrollPos))
    local offset     = math.floor((scrollPos / maxScroll) * (trackH - thumbH))

    local _, trackScreenY = track:GetScreenRect()
    local _, winScreenY   = pcDlg.window:GetScreenRect()
    local trackTopInWin   = trackScreenY - winScreenY

    thumb:ClearAnchors()
    thumb:SetAnchor(TOPRIGHT, pcDlg.window, TOPRIGHT, -PADDING, trackTopInWin + offset)
end

-------------------------------------------------------------------------------
-- Commit / scroll-range update
-------------------------------------------------------------------------------
local function CommitContent(resetScroll)
    local total = contentHeight + PADDING
    pcDlg.content:SetHeight(math.max(total, 100))
    if resetScroll then
        currentScrollPos = 0
        pcDlg.content:ClearAnchors()
        pcDlg.content:SetAnchor(TOPLEFT, pcDlg.scrollFrame, TOPLEFT, 0, 0)
    else
        -- same panel refresh: clamp position to new content height then re-apply
        ConsoleMetrics:SetScrollPos(currentScrollPos)
    end
    ConsoleMetrics:UpdateScrollThumb()
end

-------------------------------------------------------------------------------
-- Panel rendering helpers (mirror what PopulateFightViewDialog did)
-------------------------------------------------------------------------------
local function FormatMs(ms) return string.format("%.1fs", (ms or 0) / 1000) end

local function AddFightNavButtons(content, self)
    AddDivider(content)
    AddButton(content, "Previous Fight", "Step back one fight in history",
        function() self:StepFightView(-1) end,
        #self.fightHistory == 0)
    AddButton(content, "Next Fight", "Step forward one fight in history",
        function() self:StepFightView(1) end,
        #self.fightHistory == 0)
    AddButton(content, "View Live Fight", "Return to current live combat view",
        function() self.viewFightIndex = 0 end)
end

local function AddBackButton(content, self)
    AddDivider(content)
    AddButton(content, "< Back to Main", "Return to the main panel",
        function() self.dialogPanel = "main" end)
end

-------------------------------------------------------------------------------
-- Main panel
-------------------------------------------------------------------------------
local function RenderMain(content, self)
    local snap, isLive = self:GetViewedFightSnapshot()
    snap = snap or {}
    local viewingText = isLive and "Live" or string.format("Fight %d/%d", self.viewFightIndex, #self.fightHistory)
    if not isLive and type(snap.savedLabel) == "string" and snap.savedLabel ~= "" then
        viewingText = snap.savedLabel
    end
    pcDlg.titleLabel:SetText("Console Metrics  —  " .. viewingText)
    pcDlg.breadcrumb:SetText("Main Panel")
    pcDlg.backBtn:SetHidden(true)

    -- Live stats summary
    local bs = snap.burstWindowStats or {}
    local hs = snap.healingWindowStats or {}
    local topDmgSkill  = (snap.skillList or {})[1]
    local topHealSkill = (snap.healSkillList or {})[1]
    AddSection(content, string.format("Fight Summary  (%s)", viewingText))
    AddStat(content, "Duration",     string.format("%.1fs", snap.duration or 0),
        "Total fight time in seconds")
    AddStat(content, "DPS",          ShortNumber(snap.dps or 0),
        string.format("Damage Per Second  (total damage ÷ duration)  |  Peak burst: %s", ShortNumber(snap.peakDps or 0)))
    AddStat(content, "HPS",          ShortNumber(snap.hps or 0),
        string.format("Healing Per Second  (total healing ÷ duration)  |  Peak burst: %s", ShortNumber(snap.peakHps or 0)))
    AddStat(content, "Damage Done",  NumberText(snap.totalDamage or 0),
        topDmgSkill
            and string.format("Total outgoing damage  |  Top skill: %s  →  %s  (%d hits)",
                topDmgSkill.name or "?", NumberText(topDmgSkill.damage or 0), topDmgSkill.hits or 0)
            or  "Total outgoing damage dealt this fight")
    AddStat(content, "Healing Done", NumberText(snap.totalHeal or 0),
        topHealSkill
            and string.format("Total outgoing healing  |  Top skill: %s  →  %s",
                topHealSkill.name or "?", NumberText(topHealSkill.heal or 0))
            or  "Total outgoing healing this fight")
    AddStat(content, "Damage Taken", NumberText(snap.totalTaken or 0),
        string.format("Incoming damage received  |  Overflow: %s  |  Blocked: %s  |  Shielded: %s",
            NumberText(snap.totalIncomingOverflowDamage or 0),
            NumberText(snap.totalBlockedDamage or 0),
            NumberText(snap.totalShieldedDamage or 0)))
    AddStat(content, "Crit Rate",    string.format("%.1f%%", snap.critPct or 0),
        "% of outgoing hits that were critical strikes")
    AddStat(content, "Hit Value Range",
        string.format("%s - %s", NumberText(snap.minHitValue or 0), NumberText(snap.maxHitValue or 0)),
        "Lowest and highest positive hit values recorded during this fight")
    AddStat(content, "Peak DPS",     ShortNumber(snap.peakDps or 0),
        bs.peakWindowTime
            and string.format("Highest burst-window DPS  |  Occurred at: %s", bs.peakWindowTime)
            or  "Highest single burst-window DPS recorded this fight")
    AddStat(content, "Peak HPS",     ShortNumber(snap.peakHps or 0),
        hs.peakWindowTime
            and string.format("Highest burst-window HPS  |  Occurred at: %s", hs.peakWindowTime)
            or  "Highest single burst-window HPS recorded this fight")

    -- Panel navigation
    AddSection(content, "Panels")
    AddButton(content, "Overview",    "Fight totals, burst windows, and timeline",         function() self.dialogPanel = "overview" end)
    AddButton(content, "Skills",      "Top damage and healing skill breakdown",             function() self.dialogPanel = "skills"   end)
    AddButton(content, "Resources",   "HP / Magicka / Stamina sustain profile",             function() self.dialogPanel = "resources"end)
    AddButton(content, "Buffs",       "Player buff uptime and set procs",                  function() self.dialogPanel = "buffs"    end)
    AddButton(content, "Debuffs",     "Debuffs applied by player to enemies",              function() self.dialogPanel = "debuffs"  end)
    AddButton(content, "Mitigation",  "Mitigation totals and top moments",                 function() self.dialogPanel = "mitigation"end)
    AddButton(content, "Resistance",  "Resistance, DR, and inferred protections",          function() self.dialogPanel = "resistance"end)
    AddButton(content, "Build",       "Action bars, gear, champion, and boon snapshot",    function() self.dialogPanel = "build"    end)
    AddButton(content, "Behavior",    "ML-lite model outputs and confidence",               function() self.dialogPanel = "behavior" end)
    AddButton(content, "Formulas",    "ESO stat math reference",                           function() self.dialogPanel = "formulas" end)
    AddButton(content, "Share",       "Send stats or build to chat",                       function() self.dialogPanel = "share"    end)
    AddButton(content, "Options",     "Toggles, clear fight data, and help",               function() self.dialogPanel = "options"  end)

    -- Fight navigation & history
    AddSection(content, "Fight History  (" .. #self.fightHistory .. " stored)")
    AddFightNavButtons(content, self)

    -- Save / manage
    AddButton(content, "Save This Fight…", "Name and persist this fight across sessions",
        function() self.saved.saveFightDraftName = BuildDefaultFightSaveName(snap, #self.saved.savedFights + 1)
            self.dialogPanel = "save" end)
    AddButton(content, "Saved Fights", string.format("Browse %d saved fights", #self.saved.savedFights),
        function() self.dialogPanel = "saves" end)
end

-------------------------------------------------------------------------------
-- Overview panel
-------------------------------------------------------------------------------
local function RenderOverview(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Overview")
    AddSection(content, "Overview")
    AddStat(content, "Duration",        string.format("%.1fs", snap.duration or 0))
    AddStat(content, "DPS",             ShortNumber(snap.dps  or 0))
    AddStat(content, "HPS",             ShortNumber(snap.hps  or 0))
    AddStat(content, "Damage Done",     NumberText(snap.totalDamage or 0))
    AddStat(content, "Healing Done",    NumberText(snap.totalHeal   or 0))
    AddStat(content, "Damage Taken",    NumberText(snap.totalTaken  or 0))
    AddStat(content, "Crit Rate",       string.format("%.1f%%", snap.critPct or 0))
    AddStat(content, "Min Hit Value",   NumberText(snap.minHitValue or 0))
    AddStat(content, "Max Hit Value",   NumberText(snap.maxHitValue or 0))
    AddStat(content, "Peak DPS",        ShortNumber(snap.peakDps or 0))
    AddStat(content, "Peak HPS",        ShortNumber(snap.peakHps or 0))
    AddStat(content, "Overflow Damage", NumberText(snap.totalOverflowDamage or 0))
    AddStat(content, "Blocked Taken",   NumberText(snap.totalBlockedDamage  or 0))
    AddStat(content, "Shielded Taken",  NumberText(snap.totalShieldedDamage or 0))
    local bs = snap.burstWindowStats or {}
    local hs = snap.healingWindowStats or {}
    AddSection(content, "Burst Windows")
    AddStat(content, "Peak DPS Window",  tostring(bs.peakValue  or "n/a"),
        bs.peakWindowTime and string.format("Highest burst-window DPS  |  Occurred at: %s", bs.peakWindowTime) or "Highest single burst-window DPS recorded")
    AddStat(content, "Low DPS Window",   tostring(bs.lowestValue or "n/a"),
        bs.lowestWindowTime and string.format("Lowest non-zero burst-window DPS  |  Occurred at: %s", bs.lowestWindowTime) or "Lowest burst-window DPS — indicates gaps in damage output")
    AddStat(content, "Peak HPS Window",  tostring(hs.peakValue  or "n/a"),
        hs.peakWindowTime and string.format("Highest burst-window HPS  |  Occurred at: %s", hs.peakWindowTime) or "Highest single burst-window HPS recorded")
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Skills panel
-------------------------------------------------------------------------------
local function RenderSkills(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Skills")
    local skills = snap.skillList or {}
    AddSection(content, string.format("Top Damage Skills  (%d tracked)", #skills))
    if #skills == 0 then
        AddStat(content, "No skill data yet — enter combat first.", nil)
    else
        for i = 1, math.min(30, #skills) do
            local s = skills[i]
            if s then
                local hitCount = s.hits or 0
                local critCount = s.crits or 0
                local critPct = hitCount > 0 and ((critCount / hitCount) * 100) or 0
                local avgHit  = hitCount > 0 and math.floor((s.damage or 0) / hitCount) or 0
                AddStat(content, string.format("%d. %s", i, s.name or "?"),
                    string.format("%s  (%d hits, %.0f%% crit)", NumberText(s.damage or 0), hitCount, critPct),
                    string.format("Avg hit: %s  |  Max hit: %s  |  Crits: %d / %d  (%.1f%%)  |  Total: %s",
                        NumberText(avgHit), NumberText(s.maxHit or 0), critCount, hitCount, critPct, NumberText(s.damage or 0)))
            end
        end
    end
    AddSection(content, "Top Healing Skills")
    local heals = snap.healSkillList or {}
    if #heals == 0 then
        AddStat(content, "No healing data.", nil)
    else
        for i = 1, math.min(15, #heals) do
            local s = heals[i]
            if s then
                local hitCount = s.hits or 0
                local avgHeal  = hitCount > 0 and math.floor((s.heal or 0) / hitCount) or 0
                AddStat(content, string.format("%d. %s", i, s.name or "?"),
                    NumberText(s.heal or 0),
                    string.format("Avg heal: %s  |  Max heal: %s  |  %d casts / ticks  |  Total: %s",
                        NumberText(avgHeal), NumberText(s.maxHeal or 0), hitCount, NumberText(s.heal or 0)))
            end
        end
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Resources panel
-------------------------------------------------------------------------------
local function RenderResources(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Resources")
    local res = snap.resourceSummary or {}
    local function Row(label, tbl, tip)
        if tbl and tbl.hasData then
            AddStat(content, label,
                string.format("avg %.1f%%  med %.1f%%  (min %.1f%% / max %.1f%%)",
                    tbl.averagePct or 0, tbl.medianPct or 0,
                    tbl.minPct or 0, tbl.maxPct or 0),
                tip)
        else
            AddStat(content, label, "no data", tip)
        end
    end
    AddSection(content, string.format("Resources  (%d samples)", res.sampleCount or 0))
    Row("Health",  res.health  or {}, "Health % sampled during combat. Low average = sustained incoming pressure")
    Row("Magicka", res.magicka or {}, "Magicka % sampled during combat. Low min = ran out mid-fight; low avg = sustain issues")
    Row("Stamina", res.stamina or {}, "Stamina % sampled during combat. Low avg = heavy blocking / dodging / stamina skill use")

    AddSection(content, "Sustain — Regen / Drain")
    AddStat(content, "Health Regen",   NumberText(res.totalHealthRegen   or 0), "Total health passively regenerated over fight duration")
    AddStat(content, "Health Drain",   NumberText(res.totalHealthDrain   or 0), "Total health lost over fight duration")
    AddStat(content, "Magicka Regen",  NumberText(res.totalMagickaRegen  or 0), "Total magicka regained (passive regen + recovery). Compare to drain to gauge net cost")
    AddStat(content, "Magicka Drain",  NumberText(res.totalMagickaDrain  or 0), "Total magicka spent on abilities and costs. High drain vs regen = net magicka loss")
    AddStat(content, "Stamina Regen",  NumberText(res.totalStaminaRegen  or 0), "Total stamina regained (passive regen + recovery)")
    AddStat(content, "Stamina Drain",  NumberText(res.totalStaminaDrain  or 0), "Total stamina spent on blocks, dodges, and stamina abilities")
    AddStat(content, "Ultimate Gen",   NumberText(res.totalUltimateGen   or 0), "Total ultimate generated over fight duration")
    AddStat(content, "Ultimate Drain", NumberText(res.totalUltimateDrain or 0), "Total ultimate spent (each ultimate cast consumes its full cost)")

    local ping = res.ping or {}
    AddSection(content, "Latency / Ping")
    if ping.hasData then
        AddStat(content, "Avg Ping",      string.format("%.0fms", ping.averageMs or 0), "Average round-trip latency. Above ~100ms may affect ability timing and animations")
        AddStat(content, "Median Ping",   string.format("%.0fms", ping.medianMs  or 0), "Middle-value latency; more stable than average and less skewed by outliers")
        AddStat(content, "Min / Max",     string.format("%.0fms / %.0fms", ping.minMs or 0, ping.maxMs or 0), "Best and worst recorded latency this fight")
        AddStat(content, "Dips / Spikes", string.format("%d / %d", ping.dips or 0, ping.spikes or 0), "Dips = sudden ping drops (reconnecting); Spikes = sudden jumps. Both can cause ability desync")
        if (ping.highDelaySamples or 0) > 0 then
            AddStat(content, string.format("High Delay (>%dms) Samples", ping.highDelayThresholdMs or 300),
                tostring(ping.highDelaySamples),
                string.format("%d samples exceeded %dms — noticeable input lag likely during those periods",
                    ping.highDelaySamples, ping.highDelayThresholdMs or 300))
        end
    else
        AddStat(content, "No latency data", nil)
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Buffs panel
-------------------------------------------------------------------------------
local function RenderBuffs(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Buffs")
    local buffs = snap.buffList   or {}
    local sets  = snap.setProcList or {}
    local limit = EFFECTS_PANEL_LIMIT or 40

    AddSection(content, string.format("Player Buffs  (%d tracked)", #buffs))
    if #buffs == 0 then
        AddStat(content, "No buff data yet — enter combat first.", nil)
    else
        for i = 1, math.min(limit, #buffs) do
            local e = buffs[i]
            if e then
                local durS = (e.uptimeMs or 0) / 1000
                AddStat(content, e.name or "?",
                    string.format("%.1f%%  (%.1fs up)", e.uptimePct or 0, durS),
                    string.format("Uptime: %.1f%%  |  Active: %.1fs  |  Gained: %d×  |  Faded: %d×",
                        e.uptimePct or 0, durS, e.activations or 0, e.fades or 0))
            end
        end
    end

    AddSection(content, string.format("Set Procs  (%d)", #sets))
    if #sets == 0 then
        AddStat(content, "No set procs observed.", nil)
    else
        for i = 1, math.min(20, #sets) do
            local e = sets[i]
            if e then
                AddStat(content, e.name or "?",
                    string.format("%.1f%%  (%d procs)", e.uptimePct or 0, e.procs or 0),
                    string.format("Set proc uptime: %.1f%%  |  Procs: %d  |  Total proc value: %s",
                        e.uptimePct or 0, e.procs or 0, NumberText(e.totalValue or 0)))
            end
        end
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Debuffs panel
-------------------------------------------------------------------------------
local function RenderDebuffs(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Debuffs")
    local debuffs = snap.debuffList or {}
    local limit   = EFFECTS_PANEL_LIMIT or 40

    AddSection(content, string.format("Player-Applied Debuffs  (%d tracked)", #debuffs))
    if #debuffs == 0 then
        AddStat(content, "No debuff data yet — enter combat first.", nil)
    else
        for i = 1, math.min(limit, #debuffs) do
            local e = debuffs[i]
            if e then
                AddStat(content, e.name or "?",
                    string.format("%.1f%%  (%.1fs up  |  %d apps)",
                        e.uptimePct or 0,
                        (e.uptimeMs or 0) / 1000,
                        e.activations or 0))
            end
        end
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Mitigation panel
-------------------------------------------------------------------------------
local function RenderMitigation(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Mitigation")
    AddSection(content, "Mitigation")
    AddStat(content, "Blocked",  NumberText(snap.totalBlockedDamage  or 0), "Damage negated by successful block attempts")
    AddStat(content, "Shielded", NumberText(snap.totalShieldedDamage or 0), "Damage absorbed by damage shields before reaching health")
    AddStat(content, "Inferred DR",       string.format("%.1f%%", snap.inferredDrPct or 0),       "Estimated damage reduction % from resistance. Hard cap is 50% at 33,000 resistance")
    AddStat(content, "Protection Label",  snap.inferredProtectionLabel or "n/a",                  "Inferred protection tier based on observed incoming damage patterns this fight")
    AddStat(content, "Confidence",        string.format("%.0f%%", (snap.inferredProtectionConfidence or 0) * 100), "Confidence in the protection inference — more combat samples = higher confidence")
    local moments = snap.topMitigationMoments or {}
    AddSection(content, string.format("Top Mitigation Moments  (%d)", #moments))
    for i = 1, math.min(10, #moments) do
        local m = moments[i]
        if m then
            AddStat(content, m.abilityName or "?",
                NumberText(m.value or 0),
                m.tooltip or string.format("Mitigated %s via %s", NumberText(m.value or 0), m.abilityName or "?"))
        end
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Resistance panel
-------------------------------------------------------------------------------
local function RenderResistance(content, self)
    local snap, isLive = self:GetViewedFightSnapshot()
    snap = snap or {}
    pcDlg.breadcrumb:SetText("Resistance / DR")
    -- Predicted values come from the behavior model; protectionSummary only holds uptime splits.
    local bm = self:GetBehaviorModel(isLive and snap or nil) or {}
    AddSection(content, "Resistance & Damage Reduction")
    AddStat(content, "Inferred Resistance",  NumberText(bm.predictedResistance or 0))
    AddStat(content, "Inferred DR %",        string.format("%.1f%%", bm.predictedDrPct or 0))
    AddStat(content, "Protection Profile",   bm.pressureProfile or "n/a")
    AddStat(content, "Samples",              tostring(bm.samples or 0))
    local targets = snap.targetList or {}
    if #targets > 0 then
        AddSection(content, "Per-Target Estimates")
        for i = 1, math.min(10, #targets) do
            local t = targets[i]
            if t then
                AddStat(content, t.name or "?",
                    string.format("~%s resistance  (%.0f%% mitigation)",
                        NumberText(t.estimatedResistance or 0), t.mitigationPct or 0),
                    string.format("%s  |  %d hits dealt  |  %s total damage  |  ~%s est. resistance  →  %.1f%% DR",
                        t.name or "?", t.hits or 0, NumberText(t.damage or 0),
                        NumberText(t.estimatedResistance or 0), t.mitigationPct or 0))
            end
        end
    end
    AddFightNavButtons(content, self)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Build panel
-------------------------------------------------------------------------------
local function RenderBuild(content, self)
    pcDlg.breadcrumb:SetText("Build Snapshot")
    local fCat = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local bCat = type(HOTBAR_CATEGORY_BACKUP)  == "number" and HOTBAR_CATEGORY_BACKUP  or nil
    local fBar = BuildActionBarSnapshot(fCat)
    local bBar = BuildActionBarSnapshot(bCat)
    local gear = BuildEquipmentSnapshot()
    local boons = BuildActiveBoonSnapshot()
    local champ = BuildChampionSnapshot()
    local sets  = BuildEquippedSetSummary()

    AddSection(content, "Action Bars")
    AddStat(content, "Front Bar", nil)
    for i = 1, #fBar do
        local e = fBar[i]
        AddStat(content, "  " .. (e.slotLabel or ""), e.abilityName or "Empty")
    end
    AddStat(content, "Back Bar", nil)
    for i = 1, #bBar do
        local e = bBar[i]
        AddStat(content, "  " .. (e.slotLabel or ""), e.abilityName or "Empty")
    end

    AddSection(content, "Gear")
    for i = 1, #gear do
        local g = gear[i]
        AddStat(content, g.label or "?", g.text or "Empty")
    end

    AddSection(content, "Sets  (" .. #sets .. " equipped)")
    if #sets == 0 then AddStat(content, "No sets detected", nil)
    else
        for i = 1, #sets do
            local s = sets[i]
            AddStat(content, s.setName or "?",
                string.format("%d / %d pieces", s.numEquipped or 0, s.maxEquipped or 0))
        end
    end

    AddSection(content, "Mundus / Boon")
    AddStat(content, #boons > 0 and boons[1] or "None detected", nil)

    AddSection(content, string.format("Champion  (%s CP)", champ.totalPoints and NumberText(champ.totalPoints) or "?"))
    local function Bucket(label, entries)
        if entries and #entries > 0 then
            AddStat(content, label, nil)
            for i = 1, #entries do
                local e = entries[i]
                AddStat(content, "  " .. (e.name or "?"), NumberText(e.points or 0))
                -- Show slotted stars (slottables) indented under their discipline.
                for _, star in ipairs(e.slottedStars or {}) do
                    AddStat(content, "    • " .. (star.name or "?"), nil,
                        string.format("Slotted CP star  |  Skill ID: %d  |  Discipline: %s",
                            star.skillId or 0, e.name or "?"))
                end
            end
        end
    end
    Bucket("Warfare",  champ.warfare)
    Bucket("Fitness",  champ.fitness)
    Bucket("Craft",    champ.craft)

    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Behavior / ML panel
-------------------------------------------------------------------------------
local function RenderBehavior(content, self)
    local snap, isLive = self:GetViewedFightSnapshot()
    pcDlg.breadcrumb:SetText("Behavior Model")
    local bm = self:GetBehaviorModel(isLive and snap or nil)
    bm = bm or {}
    AddSection(content, "ML-Lite Behavior Model")
    AddStat(content, "Predicted Resistance",   NumberText(bm.predictedResistance or 0))
    AddStat(content, "Predicted DR %",         string.format("%.1f%%", bm.predictedDrPct or 0))
    AddStat(content, "Predicted DPS",          ShortNumber(bm.predictedDps or 0))
    AddStat(content, "Predicted HPS",          ShortNumber(bm.predictedHps or 0))
    AddStat(content, "Protection Profile",     bm.pressureProfile  or "n/a")
    AddStat(content, "Rhythm Profile",         bm.rhythmProfile    or "n/a")
    AddStat(content, "Confidence",             string.format("%.0f%%", (bm.predictedProtectionConfidence or 0) * 100))
    AddStat(content, "Volatility",             string.format("%.1f%%", bm.volatilityPct or 0))
    AddStat(content, "Samples",                tostring(bm.samples or 0))
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Formulas panel
-------------------------------------------------------------------------------
local function RenderFormulas(content, self)
    pcDlg.breadcrumb:SetText("Formulas")
    AddSection(content, "Damage Reduction (Physical)")
    AddStat(content, "DR % = Resistance / 66000", nil)
    AddStat(content, "Resistance cap = 33000  (50% DR)", nil)
    AddSection(content, "DPS / HPS")
    AddStat(content, "DPS = Damage Done / Duration (s)", nil)
    AddStat(content, "HPS = Healing Done / Duration (s)", nil)
    AddSection(content, "Crit Rate")
    AddStat(content, "Crit Rate = Crits / Total Hits × 100", nil)
    AddSection(content, "Penetration")
    AddStat(content, "Effective Resist = Target Resist − Your Pen", nil)
    AddSection(content, "Major / Minor Protection")
    AddStat(content, "Major Protection = −10% damage taken", nil)
    AddStat(content, "Minor Protection = −5%  damage taken", nil)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Options panel
-------------------------------------------------------------------------------
local function RenderOptions(content, self)
    pcDlg.breadcrumb:SetText("Options")
    local sv = self.saved

    AddSection(content, "Toggles")
    AddButton(content,
        sv.dialogAutoHide and "Dialog Auto-Hide: ON" or "Dialog Auto-Hide: OFF",
        "Auto-close this dialog after combat ends",
        function() sv.dialogAutoHide = not sv.dialogAutoHide end)
    AddButton(content,
        sv.closeOnMove and "Close on Movement: ON" or "Close on Movement: OFF",
        "Close this dialog automatically when controller stick or movement key is pressed",
        function() sv.closeOnMove = not sv.closeOnMove end)
    AddButton(content,
        sv.autoClearOnNextFight and "Auto-Clear on Next Fight: ON" or "Auto-Clear on Next Fight: OFF",
        "Clear combat data when the next fight starts",
        function() sv.autoClearOnNextFight = not sv.autoClearOnNextFight end)
    AddButton(content,
        sv.lowMemoryMode and "Low Memory Mode: ON" or "Low Memory Mode: OFF",
        "Compact fight snapshots to reduce memory use",
        function() sv.lowMemoryMode = not sv.lowMemoryMode end)
    AddButton(content,
        sv.performanceMode and "Performance Mode: ON" or "Performance Mode: OFF",
        "Apply the lightweight performance preset",
        function()
            sv.performanceMode = not sv.performanceMode
            if sv.performanceMode then self:ApplyConsolePerformancePreset() end
        end)
    AddButton(content,
        sv.behaviorModelEnabled and "Behavior Model: ON" or "Behavior Model: OFF",
        "Enable the ML-lite resistance/behavior predictor",
        function()
            sv.behaviorModelEnabled = not sv.behaviorModelEnabled
            if not sv.behaviorModelEnabled then self.behaviorModelCache = nil end
        end)

    AddSection(content, "Fight History & Data")
    AddStat(content, string.format("History:  %d fights stored  (max %d)",
        #self.fightHistory, sv.maxFightHistory or self.defaults.maxFightHistory), nil)
    AddButton(content, "Clear All Fight Data",
        "Wipe current fight and all stored history",
        function() self:ResetFightData(false) ; self:Print("Fight data cleared.") end)

    AddSection(content, "Slash Commands Reference")
    local help = {
        "/cm view       — open this dialog",
        "/cm next/prev  — step through fight history",
        "/cm clear      — clear fight data",
        "/cm share      — share fight stats to chat",
        "/cm share build— share build to chat",
        "/cm linkbuild  — same as share build",
        "/cm reset      — reset all options to defaults",
        "/cm help       — full command reference",
    }
    for _, line in ipairs(help) do AddStat(content, line, nil) end

    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Share panel
-------------------------------------------------------------------------------
local function RenderShare(content, self)
    local snap, isLive = self:GetViewedFightSnapshot()
    local viewLabel = isLive and "Live" or string.format("Fight %d", self.viewFightIndex or 0)
    pcDlg.breadcrumb:SetText("Share to Chat")
    local lmbTag = type(LinkMyBars) == "function" and " [LMB]" or " [built-in]"

    AddSection(content, "Link My Build" .. lmbTag)
    AddButton(content, "Link Skill Bars" .. lmbTag,
        "Pre-fills chat with clickable ability links for both bars using LMB style.",
        function() self:LinkBuildSkillsLMB() end)
    AddButton(content, "Link CP + Mundus + Food" .. lmbTag,
        "Pre-fills chat with Champion Point slots, Mundus stone, food buff, and quickslot using LMB.",
        function() self:LinkChampAndMiscLMB() end)
    AddButton(content, "Link Gear Sets" .. lmbTag,
        "Pre-fills chat with all equipped gear set links using LMB (may open multiple chat inputs).",
        function() self:LinkGearSetsLMB() end)

    AddSection(content, "Champion Points")
    AddButton(content, "Link CP Slottables",
        "Sends all slotted CP stars as clickable ability links to chat",
        function() self:ShareCPSlottablesToChat() end)

    AddSection(content, "Full Build  (ability + item + CP links)")
    AddButton(content, "Share Build (All Links)",
        "Front bar, back bar, armor, jewelry, weapons, and CP slottables — all as clickable links",
        function() self:ShareFullBuildLinked() end)

    AddSection(content, "Gear Links  (item links, always available)")
    AddButton(content, "Share Armor Links",   "Sends 7 armor piece item links",                  function() self:ShareArmorLinksToChat()    end)
    AddButton(content, "Share Jewelry Links", "Sends neck + 2 ring item links",                  function() self:ShareJewelryLinksToChat()  end)
    AddButton(content, "Share Weapon Links",  "Sends front and back weapon item links",           function() self:ShareWeaponLinksToChat()   end)

    AddSection(content, "Fight Stats")
    AddStat(content, "Preview: " .. self:BuildFightShareLine(snap, viewLabel), nil)
    AddButton(content, "Share Fight Stats",   "DPS, HPS, damage, healing, crit, duration",       function() self:ShareFightToChat(viewLabel) end)
    AddButton(content, "Share Top Skills",    "Top 5 damage skills as links + totals",           function() self:ShareTopSkillsToChat()     end)
    AddButton(content, "Share Resources",     "HP / Mag / Stam averages",                        function() self:ShareResourceToChat()      end)
    AddButton(content, "Share Full Snapshot", "Fight stats + build in one line",                 function() self:ShareFullSnapshotToChat()  end)

    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Save-fight panel
-------------------------------------------------------------------------------
local function RenderSave(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Save Fight")
    AddSection(content, string.format("Save Fight  (%.1fs / %s DPS)",
        snap.duration or 0, ShortNumber(snap.dps or 0)))
    AddStat(content, "Damage: " .. NumberText(snap.totalDamage or 0), nil)
    AddStat(content, "Healing: " .. NumberText(snap.totalHeal  or 0), nil)
    AddDivider(content)
    AddEditBox(content, "Save Name:",
        function() return self.saved.saveFightDraftName or "" end,
        function(v) self.saved.saveFightDraftName = TrimText(v) end, 80)
    AddButton(content, "Auto-Fill Name", "Generate a default name from this fight",
        function()
            self.saved.saveFightDraftName =
                BuildDefaultFightSaveName(snap, #self.saved.savedFights + 1)
        end)
    AddButton(content, "Save Fight", "Persist this fight to saved slots",
        function()
            local ok, msg = self:SaveViewedFight()
            self:Print(msg)
            if ok then self.dialogPanel = "saves" end
        end)
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Saved-fights panel
-------------------------------------------------------------------------------
local function RenderSaves(content, self)
    local saves = self.saved.savedFights or {}
    pcDlg.breadcrumb:SetText("Saved Fights")
    AddSection(content, string.format("Saved Fights  (%d / %d)",
        #saves, self.saved.maxSavedFights or self.defaults.maxSavedFights))

    AddEditBox(content, "Load fight by name:",
        function() return self.saved.loadFightDraftName or "" end,
        function(v) self.saved.loadFightDraftName = TrimText(v) end, 120)
    AddButton(content, "Load By Name", "Find and load a saved fight into history",
        function()
            local ok, msg = self:LoadSavedFightIntoHistoryByName(self.saved.loadFightDraftName or "")
            self:Print(msg)
            if ok then self.dialogPanel = "main" end
        end)
    AddDivider(content)

    if #saves == 0 then
        AddStat(content, "No saved fights yet.", nil)
    else
        for i = 1, #saves do
            local entry = saves[i]
            if entry and entry.snapshot then
                local sn = entry.snapshot
                AddStat(content,
                    string.format("%d. %s", i, entry.label or ("Slot " .. i)),
                    string.format("%.1fs | %s DPS | %s dmg",
                        sn.duration or 0, ShortNumber(sn.dps or 0), ShortNumber(sn.totalDamage or 0)))
                local idx = i
                AddButton(content, string.format("   Load Slot %d", idx), "Add to fight history",
                    function()
                        local ok, msg = self:LoadSavedFightIntoHistory(idx)
                        self:Print(msg)
                        self.dialogPanel = "main"
                    end)
                AddButton(content, string.format("   Delete Slot %d", idx), "Permanently remove this saved fight",
                    function()
                        local ok, msg = self:DeleteSavedFight(idx)
                        self:Print(msg)
                    end)
            end
        end
        AddDivider(content)
        AddButton(content, "Clear All Saved Fights", "Delete every saved slot permanently",
            function()
                self.saved.savedFights = {}
                self:Print("All saved fights cleared.")
            end)
    end
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Router: pick and render the correct panel
-------------------------------------------------------------------------------
local PANELS = {
    main        = RenderMain,
    overview    = RenderOverview,
    skills      = RenderSkills,
    resources   = RenderResources,
    buffs       = RenderBuffs,
    debuffs     = RenderDebuffs,
    mitigation  = RenderMitigation,
    resistance  = RenderResistance,
    build       = RenderBuild,
    behavior    = RenderBehavior,
    formulas    = RenderFormulas,
    options     = RenderOptions,
    share       = RenderShare,
    save        = RenderSave,
    saves       = RenderSaves,
}

function ConsoleMetrics:RefreshPCDialog()
    if not pcDlg.window or pcDlg.window:IsHidden() then return end
    ClearDynamic()

    local panel = self.dialogPanel or "main"
    local panelChanged = (panel ~= lastRenderedPanel)
    lastRenderedPanel = panel

    pcDlg.backBtn:SetHidden(panel == "main")

    local renderer = PANELS[panel]
    if renderer then
        renderer(pcDlg.content, self)
    else
        AddSection(pcDlg.content, "Unknown panel: " .. tostring(panel))
        AddButton(pcDlg.content, "Back", nil, function() self.dialogPanel = "main" end)
    end

    CommitContent(panelChanged)
end
