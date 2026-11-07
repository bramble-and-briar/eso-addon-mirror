-- ConsoleMetrics_PCDialog.lua
-- Keyboard/mouse window for ConsoleMetrics on PC, styled after the base-game
-- keyboard UI: the standard window backdrop, gold-on-dark fonts, divider
-- art, a journal-style category list on the left, ESO buttons / edit boxes,
-- the regular mouse-over tooltip, and ESC / cursor handling through the
-- scene manager's top-level windows.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local BuildDefaultFightSaveName = Util.BuildDefaultFightSaveName
local Clamp = Util.Clamp
local EFFECTS_PANEL_LIMIT = Util.EFFECTS_PANEL_LIMIT
local Median = Util.Median
local NumberText = Util.NumberText
local RESISTANCE_SCALE = Util.RESISTANCE_SCALE
local ShortNumber = Util.ShortNumber
local TrimText = Util.TrimText

local Build = ConsoleMetrics.Build
local BuildActionBarSnapshot = Build.BuildActionBarSnapshot
local BuildActiveBoonSnapshot = Build.BuildActiveBoonSnapshot
local BuildEquipmentSnapshot = Build.BuildEquipmentSnapshot
local BuildEquippedSetSummary = Build.BuildEquippedSetSummary

local Champion = ConsoleMetrics.Champion
local BuildChampionSnapshot = Champion.BuildChampionSnapshot

local Fight = ConsoleMetrics.Fight
local InferProtectionFromDr = Fight.InferProtectionFromDr


local WM = WINDOW_MANAGER

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local WIN_W        = 980
local WIN_H        = 760
local HEADER_H     = 64          -- title row
local FOOTER_H     = 58          -- fight navigation row
local EDGE         = 22          -- inner margin from the window edge
local NAV_W        = 210         -- left category column
local GAP          = 18          -- space between nav and content
local SB_W         = 10          -- scrollbar width
local PADDING      = 8
local CONTENT_W    = WIN_W - EDGE * 2 - NAV_W - GAP - SB_W - 8
local SECTION_H    = 42
local STAT_H       = 28
local BTN_W        = 300
local BTN_H        = 30
local BTN_PAD      = 6
local TILE_H       = 70
local NAV_ROW_H    = 30
local NAV_HEADER_H = 32

local FONT_TITLE     = "ZoFontWinH1"
local FONT_SUBTITLE  = "ZoFontWinH4"
local FONT_PANEL     = "ZoFontWinH2"
local FONT_SECTION   = "ZoFontWinH3"
local FONT_NAV       = "ZoFontHeader2"
local FONT_NAV_HEAD  = "ZoFontWinH5"
local FONT_STAT      = "ZoFontGame"
local FONT_VALUE     = "ZoFontGameBold"
local FONT_TILE      = "ZoFontWinH2"
local FONT_TILE_CAP  = "ZoFontWinH5"

local DIVIDER_TEXTURE = "EsoUI/Art/Miscellaneous/horizontalDivider.dds"

-- Base-game text colors (with fallbacks in case a global is missing).
local function Color(def, r, g, b)
    if def and def.UnpackRGBA then
        local cr, cg, cb, ca = def:UnpackRGBA()
        return { cr, cg, cb, ca or 1 }
    end
    return { r, g, b, 1 }
end
local COL_NORMAL    = Color(ZO_NORMAL_TEXT,    0.773, 0.761, 0.620)   -- gold/beige labels
local COL_SELECTED  = Color(ZO_SELECTED_TEXT,  1.000, 1.000, 1.000)   -- values, selected entries
local COL_HIGHLIGHT = Color(ZO_HIGHLIGHT_TEXT, 1.000, 1.000, 1.000)
local COL_DISABLED  = Color(ZO_DISABLED_TEXT,  0.380, 0.380, 0.380)
local COL_HEADER    = Color(ZO_SECOND_CONTRAST_TEXT, 0.933, 0.886, 0.722)
local COL_ROW_ALT   = { 0, 0, 0, 0.28 }
local COL_ROW_HOVER = { 1, 1, 1, 0.07 }
local COL_TILE_BG   = { 0, 0, 0, 0.40 }
local COL_NAV_SEL   = { 0.773, 0.761, 0.620, 0.16 }

local function SetColor(ctrl, col)
    ctrl:SetColor(col[1], col[2], col[3], col[4] or 1)
end

-------------------------------------------------------------------------------
-- Category list (left column)
-------------------------------------------------------------------------------
local NAV_GROUPS = {
    { header = "Fight", entries = {
        { key = "main",       label = "Summary" },
        { key = "overview",   label = "Overview" },
        { key = "skills",     label = "Abilities" },
        { key = "buffs",      label = "Buffs & Sets" },
        { key = "debuffs",    label = "Debuffs" },
        { key = "mitigation", label = "Mitigation" },
        { key = "resistance", label = "Resistance" },
        { key = "resources",  label = "Resources" },
    } },
    { header = "Character", entries = {
        { key = "build",      label = "Build" },
        { key = "behavior",   label = "Behavior Model" },
        { key = "formulas",   label = "Formulas" },
    } },
    { header = "Tools", entries = {
        { key = "share",      label = "Share to Chat" },
        { key = "saves",      label = "Saved Fights", also = { save = true } },
        { key = "libfights",  label = "LibFights" },
        { key = "options",    label = "Options" },
    } },
}

-------------------------------------------------------------------------------
-- Internals
-------------------------------------------------------------------------------
local pcDlg = {}          -- module state for the PC window
ConsoleMetrics.pcDlg = pcDlg

local contentHeight    = 0
local currentScrollPos = 0     -- manual scroll offset in pixels
local lastRenderedPanel = nil  -- detect panel changes to reset scroll
local rowIndex         = 0     -- alternating row shading
local ScrollContent            -- forward declaration; defined below CreatePCDialog

-- Interaction tracking. The live refresh rebuilds every control in the
-- content area, so it must not run while the player is clicking (the click
-- would land on a control that was just recycled) or scrolling, and
-- auto-hide must not close the window while the player is using it.
local INTERACTION_HOLD_MS = 1500   -- no rebuild for this long after a click / scroll
local lastInteractionMs = 0
local mouseButtonDown = false

local function NoteInteraction()
    lastInteractionMs = GetFrameTimeMilliseconds()
    -- Any use of the window restarts the auto-hide countdown.
    if ConsoleMetrics.dialogAutoHideAtMs then
        ConsoleMetrics:ArmDialogAutoHide()
    end
end

function ConsoleMetrics:IsPCDialogBusy()
    if not pcDlg.window or pcDlg.window:IsHidden() then
        return false
    end
    local nowMs = GetFrameTimeMilliseconds()
    if mouseButtonDown and nowMs > lastInteractionMs + 5000 then
        -- The release happened outside the control; don't stay stuck.
        mouseButtonDown = false
    end
    if mouseButtonDown or pcDlg.sbDragging then
        return true
    end
    return nowMs < lastInteractionMs + INTERACTION_HOLD_MS
end

function ConsoleMetrics:IsPCDialogInUse()
    if not pcDlg.window or pcDlg.window:IsHidden() then
        return false
    end
    if self:IsPCDialogBusy() or self:IsPCDialogEditing() then
        return true
    end
    -- Cursor over the window. Only counts while the mouse cursor is shown:
    -- with the cursor hidden it sits at screen center, where the window opens.
    if type(IsGameCameraUIModeActive) == "function" and not IsGameCameraUIModeActive() then
        return false
    end
    local ok, over = pcall(MouseIsOver, pcDlg.window)
    return ok and over == true
end

-------------------------------------------------------------------------------
-- Tooltips (the base-game information tooltip)
-------------------------------------------------------------------------------
local function ShowCMTooltip(owner, text)
    if not text or text == "" or not InformationTooltip then return end
    InitializeTooltip(InformationTooltip, owner, LEFT, 12, 0, RIGHT)
    SetTooltipText(InformationTooltip, text)
end

local function HideCMTooltip()
    if InformationTooltip then
        ClearTooltip(InformationTooltip)
    end
end

-------------------------------------------------------------------------------
-- Small control helpers
-------------------------------------------------------------------------------
local function MakeLabel(name, parent, font, col, text)
    local lbl = WM:CreateControl(name, parent, CT_LABEL)
    lbl:SetFont(font)
    SetColor(lbl, col)
    lbl:SetText(text or "")
    return lbl
end

local function MakeDivider(name, parent)
    local tex = WM:CreateControl(name, parent, CT_TEXTURE)
    tex:SetTexture(DIVIDER_TEXTURE)
    tex:SetTextureCoords(0.181640625, 0.818359375, 0, 1)
    tex:SetHeight(4)
    return tex
end

local function MakeButton(name, parent, text, width, onClick)
    local btn = WM:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    btn:SetDimensions(width or 140, BTN_H)
    btn:SetText(text)
    btn:SetHandler("OnClicked", function()
        NoteInteraction()
        onClick()
    end)
    return btn
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
    -- Dragging the window counts as using it.
    win:SetHandler("OnMoveStart", function() mouseButtonDown = true; NoteInteraction() end)
    win:SetHandler("OnMoveStop", function() mouseButtonDown = false; NoteInteraction() end)
    win:SetHandler("OnMouseEnter", function() NoteInteraction() end)

    -- Standard keyboard window backdrop.
    local bg = WM:CreateControlFromVirtual("$(parent)BG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    -- Header: title, what is being viewed, close button.
    local title = MakeLabel("$(parent)Title", win, FONT_TITLE, COL_NORMAL, zo_strupper and zo_strupper("Console Metrics") or "CONSOLE METRICS")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE, 14)
    pcDlg.titleLabel = title

    local subtitle = MakeLabel("$(parent)Subtitle", win, FONT_SUBTITLE, COL_SELECTED, "")
    subtitle:SetAnchor(BOTTOMLEFT, title, BOTTOMRIGHT, 16, -3)
    pcDlg.subtitle = subtitle

    local closeBtn = WM:CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
    closeBtn:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE + 4, 18)
    closeBtn:SetHandler("OnClicked", function()
        ConsoleMetrics:CloseFightViewDialog(true, "button")
    end)

    local topDivider = MakeDivider("$(parent)TopDivider", win)
    topDivider:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE - 6, HEADER_H)
    topDivider:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE + 6, HEADER_H)

    local bottomDivider = MakeDivider("$(parent)BottomDivider", win)
    bottomDivider:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, EDGE - 6, -FOOTER_H)
    bottomDivider:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -EDGE + 6, -FOOTER_H)

    local bodyTop = HEADER_H + 14
    local bodyBottom = FOOTER_H + 10

    -- Left category list (journal style).
    local nav = WM:CreateControl("$(parent)Nav", win, CT_CONTROL)
    nav:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE, bodyTop)
    nav:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, EDGE, -bodyBottom)
    nav:SetWidth(NAV_W)
    pcDlg.navEntries = {}

    local navY = 0
    for g = 1, #NAV_GROUPS do
        local group = NAV_GROUPS[g]
        local head = MakeLabel("$(parent)Head" .. g, nav, FONT_NAV_HEAD, COL_HEADER, zo_strupper and zo_strupper(group.header) or string.upper(group.header))
        head:SetAnchor(TOPLEFT, nav, TOPLEFT, 4, navY + 6)
        navY = navY + NAV_HEADER_H

        for e = 1, #group.entries do
            local entry = group.entries[e]
            local row = WM:CreateControl("$(parent)Row" .. g .. "_" .. e, nav, CT_CONTROL)
            row:SetAnchor(TOPLEFT, nav, TOPLEFT, 0, navY)
            row:SetDimensions(NAV_W, NAV_ROW_H)
            row:SetMouseEnabled(true)

            local highlight = WM:CreateControl("$(parent)Highlight", row, CT_TEXTURE)
            highlight:SetAnchorFill(row)
            highlight:SetColor(COL_NAV_SEL[1], COL_NAV_SEL[2], COL_NAV_SEL[3], COL_NAV_SEL[4])
            highlight:SetHidden(true)

            local marker = WM:CreateControl("$(parent)Marker", row, CT_TEXTURE)
            marker:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 3)
            marker:SetDimensions(3, NAV_ROW_H - 6)
            SetColor(marker, COL_NORMAL)
            marker:SetHidden(true)

            local label = MakeLabel("$(parent)Label", row, FONT_NAV, COL_NORMAL, entry.label)
            label:SetAnchor(LEFT, row, LEFT, 16, 0)

            row:SetHandler("OnMouseEnter", function()
                if not row.selected then SetColor(label, COL_HIGHLIGHT) end
            end)
            row:SetHandler("OnMouseExit", function()
                if not row.selected then SetColor(label, COL_NORMAL) end
            end)
            row:SetHandler("OnMouseUp", function(_, button, upInside)
                if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then return end
                NoteInteraction()
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
                ConsoleMetrics.dialogPanel = entry.key
                ConsoleMetrics:RefreshPCDialog()
            end)

            row.entry = entry
            row.label = label
            row.highlight = highlight
            row.marker = marker
            pcDlg.navEntries[#pcDlg.navEntries + 1] = row
            navY = navY + NAV_ROW_H
        end
        navY = navY + 8
    end

    -- Thin vertical rule between the category list and the content.
    local rule = WM:CreateControl("$(parent)Rule", win, CT_TEXTURE)
    rule:SetAnchor(TOPLEFT, nav, TOPRIGHT, GAP / 2, 0)
    rule:SetAnchor(BOTTOMLEFT, nav, BOTTOMRIGHT, GAP / 2, 0)
    rule:SetWidth(1)
    rule:SetColor(COL_NORMAL[1], COL_NORMAL[2], COL_NORMAL[3], 0.25)

    -- Panel heading above the scroll area.
    local contentLeft = EDGE + NAV_W + GAP
    local panelTitle = MakeLabel("$(parent)PanelTitle", win, FONT_PANEL, COL_SELECTED, "")
    panelTitle:SetAnchor(TOPLEFT, win, TOPLEFT, contentLeft + 2, bodyTop - 4)
    pcDlg.breadcrumb = panelTitle

    -- Viewport: plain CT_CONTROL that clips its children.
    local scrollTop = bodyTop + 40
    local scrollFrame = WM:CreateControl("$(parent)Scroll", win, CT_CONTROL)
    scrollFrame:SetAnchor(TOPLEFT,     win, TOPLEFT,     contentLeft, scrollTop)
    scrollFrame:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(EDGE + SB_W + 8), -bodyBottom)
    scrollFrame:SetMouseEnabled(true)
    scrollFrame:SetHandler("OnMouseWheel", function(_, delta) ScrollContent(delta) end)
    pcall(function() scrollFrame:SetClipChildren(true) end)
    pcDlg.scrollFrame = scrollFrame

    -- Slim scrollbar in the base-game colors.
    local sbTrack = WM:CreateControl("$(parent)SBTrack", win, CT_TEXTURE)
    sbTrack:SetWidth(SB_W)
    sbTrack:SetAnchor(TOPRIGHT,    win, TOPRIGHT,    -EDGE, scrollTop)
    sbTrack:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -EDGE, -bodyBottom)
    sbTrack:SetColor(0, 0, 0, 0.45)
    sbTrack:SetMouseEnabled(true)
    pcDlg.sbTrack = sbTrack

    local sbThumb = WM:CreateControl("$(parent)SBThumb", win, CT_TEXTURE)
    sbThumb:SetWidth(SB_W)
    sbThumb:SetHeight(60)
    sbThumb:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE, scrollTop)
    sbThumb:SetColor(COL_NORMAL[1], COL_NORMAL[2], COL_NORMAL[3], 0.55)
    sbThumb:SetMouseEnabled(true)
    pcDlg.sbThumb = sbThumb
    pcDlg.sbDragging = false
    pcDlg.sbDragStartY = 0
    pcDlg.sbDragStartScroll = 0

    sbThumb:SetHandler("OnMouseEnter", function() sbThumb:SetColor(COL_NORMAL[1], COL_NORMAL[2], COL_NORMAL[3], 0.85) end)
    sbThumb:SetHandler("OnMouseExit", function() sbThumb:SetColor(COL_NORMAL[1], COL_NORMAL[2], COL_NORMAL[3], 0.55) end)
    sbThumb:SetHandler("OnMouseDown", function(_, btn)
        if btn ~= MOUSE_BUTTON_INDEX_LEFT then return end
        pcDlg.sbDragging = true
        pcDlg.sbDragStartY = select(2, GetUIMousePosition())
        pcDlg.sbDragStartScroll = currentScrollPos
        NoteInteraction()
    end)
    sbThumb:SetHandler("OnMouseUp", function()
        pcDlg.sbDragging = false
        NoteInteraction()
    end)
    sbThumb:SetHandler("OnUpdate", function()
        if not pcDlg.sbDragging then return end
        local _, curY = GetUIMousePosition()
        local deltaY  = curY - pcDlg.sbDragStartY
        local trackH  = sbTrack:GetHeight()
        local thumbH  = sbThumb:GetHeight()
        local visH    = scrollFrame:GetHeight()
        local totalH  = pcDlg.content:GetHeight()
        local maxScroll = math.max(0, totalH - visH)
        if trackH <= thumbH then return end
        ConsoleMetrics:SetScrollPos(pcDlg.sbDragStartScroll + deltaY * maxScroll / (trackH - thumbH))
    end)

    sbTrack:SetHandler("OnMouseDown", function(_, btn)
        if btn ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local _, curY    = GetUIMousePosition()
        local trackY     = sbTrack:GetTop()
        local trackH     = sbTrack:GetHeight()
        local visH       = scrollFrame:GetHeight()
        local totalH     = pcDlg.content:GetHeight()
        local maxScroll  = math.max(0, totalH - visH)
        local frac       = math.max(0, math.min(1, (curY - trackY) / trackH))
        ConsoleMetrics:SetScrollPos(frac * maxScroll)
        NoteInteraction()
    end)

    -- Wheel anywhere in the window scrolls the content.
    win:SetHandler("OnMouseWheel", function(_, delta)
        ScrollContent(delta)
    end)

    -- Close on movement when the option is enabled.
    win:SetHandler("OnUpdate", function()
        if not pcDlg.window or pcDlg.window:IsHidden() then return end
        if ConsoleMetrics.saved and ConsoleMetrics.saved.closeOnMove then
            if type(IsPlayerMoving) == "function" and IsPlayerMoving() then
                ConsoleMetrics:CloseFightViewDialog(true, "movement")
            end
        end
    end)

    local content = WM:CreateControl("$(parent)Content", scrollFrame, CT_CONTROL)
    content:SetWidth(CONTENT_W)
    content:SetHeight(100)
    content:SetAnchor(TOPLEFT, scrollFrame, TOPLEFT, 0, 0)
    pcDlg.content = content

    -- Footer: fight history navigation (like a keybind strip).
    local footerY = -(FOOTER_H / 2) + 2
    local prevBtn = MakeButton("$(parent)Prev", win, "Previous", 130, function()
        ConsoleMetrics:StepFightView(-1)
        ConsoleMetrics:RefreshPCDialog()
    end)
    prevBtn:SetAnchor(LEFT, win, BOTTOMLEFT, EDGE, footerY)
    pcDlg.prevBtn = prevBtn

    local nextBtn = MakeButton("$(parent)Next", win, "Next", 130, function()
        ConsoleMetrics:StepFightView(1)
        ConsoleMetrics:RefreshPCDialog()
    end)
    nextBtn:SetAnchor(LEFT, prevBtn, RIGHT, 8, 0)
    pcDlg.nextBtn = nextBtn

    local liveBtn = MakeButton("$(parent)Live", win, "Live", 110, function()
        ConsoleMetrics.viewFightIndex = 0
        ConsoleMetrics:RefreshPCDialog()
    end)
    liveBtn:SetAnchor(LEFT, nextBtn, RIGHT, 8, 0)
    pcDlg.liveBtn = liveBtn

    local fightLabel = MakeLabel("$(parent)FightLabel", win, FONT_STAT, COL_NORMAL, "")
    fightLabel:SetAnchor(LEFT, liveBtn, RIGHT, 18, 0)
    fightLabel:SetDimensions(WIN_W - EDGE * 2 - 3 * 130 - 180, 24)
    fightLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    pcDlg.fightLabel = fightLabel

    local saveBtn = MakeButton("$(parent)Save", win, "Save Fight", 150, function()
        local snap = ConsoleMetrics:GetViewedFightSnapshot() or {}
        ConsoleMetrics.saved.saveFightDraftName = BuildDefaultFightSaveName(snap, #ConsoleMetrics:GetSavedFights() + 1)
        ConsoleMetrics.dialogPanel = "save"
        ConsoleMetrics:RefreshPCDialog()
    end)
    saveBtn:SetAnchor(RIGHT, win, BOTTOMRIGHT, -EDGE, footerY)
    pcDlg.saveBtn = saveBtn

    -- ESC closes the window and opening it shows the mouse cursor, like any
    -- base-game window. Falls back to plain show/hide if unavailable.
    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterTopLevel) == "function" then
        local ok = pcall(SCENE_MANAGER.RegisterTopLevel, SCENE_MANAGER, win, false)
        pcDlg.isTopLevel = ok
    end
end

-------------------------------------------------------------------------------
-- Chrome updates (title, nav selection, footer)
-------------------------------------------------------------------------------
local function UpdateChrome(self, panel)
    local snap, isLive = self:GetViewedFightSnapshot()
    snap = snap or {}
    local viewing
    if isLive then
        viewing = self.inCombat and "Live  -  in combat" or "Live"
    elseif type(snap.savedLabel) == "string" and snap.savedLabel ~= "" then
        viewing = snap.savedLabel
    else
        viewing = string.format("Fight %d of %d", self.viewFightIndex or 0, #self.fightHistory)
    end
    pcDlg.subtitle:SetText(viewing)

    local fightText = string.format("%s   |   %.1fs   |   %s DPS",
        (snap.title and snap.title ~= "") and snap.title or (isLive and "No fight yet" or "Fight"),
        snap.duration or 0, ShortNumber(snap.dps or 0))
    pcDlg.fightLabel:SetText(fightText)

    local hasHistory = #self.fightHistory > 0
    pcDlg.prevBtn:SetEnabled(hasHistory)
    pcDlg.nextBtn:SetEnabled(hasHistory)
    pcDlg.liveBtn:SetEnabled(not isLive)

    for i = 1, #pcDlg.navEntries do
        local row = pcDlg.navEntries[i]
        local selected = row.entry.key == panel or (row.entry.also and row.entry.also[panel]) or false
        row.selected = selected
        row.highlight:SetHidden(not selected)
        row.marker:SetHidden(not selected)
        SetColor(row.label, selected and COL_SELECTED or COL_NORMAL)
    end
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
    if pcDlg.isTopLevel then
        SCENE_MANAGER:ShowTopLevel(pcDlg.window)
    else
        pcDlg.window:SetHidden(false)
    end
    pcDlg.window:BringWindowToTop()
    lastRenderedPanel = nil  -- force scroll-to-top on first render
    self:RefreshPCDialog()
    self.wasFightViewDialogShowing = true
    self.dialogRefreshAtMs   = nil
    self.lastDialogRefreshKey = nil
    self:ArmDialogAutoHide()
end

function ConsoleMetrics:ClosePCDialog()
    if pcDlg.window then
        HideCMTooltip()
        if pcDlg.isTopLevel then
            SCENE_MANAGER:HideTopLevel(pcDlg.window)
        else
            pcDlg.window:SetHidden(true)
        end
    end
    self.wasFightViewDialogShowing = false
end

function ConsoleMetrics:IsFightViewDialogShowingPC()
    return pcDlg.window ~= nil and not pcDlg.window:IsHidden()
end

-------------------------------------------------------------------------------
-- Scrolling
-------------------------------------------------------------------------------
ScrollContent = function(delta)
    if not pcDlg.scrollFrame then return end
    NoteInteraction()
    ConsoleMetrics:SetScrollPos(currentScrollPos - delta * 60)
end

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

function ConsoleMetrics:UpdateScrollThumb()
    local thumb, track, sf = pcDlg.sbThumb, pcDlg.sbTrack, pcDlg.scrollFrame
    if not thumb or not track or not sf then return end

    local visH   = sf:GetHeight()
    local totalH = pcDlg.content:GetHeight()
    if totalH <= visH then
        thumb:SetHidden(true)
        track:SetHidden(true)
        return
    end
    thumb:SetHidden(false)
    track:SetHidden(false)

    local trackH    = track:GetHeight()
    local thumbH    = math.max(30, math.floor(trackH * visH / totalH))
    local maxScroll = totalH - visH
    local offset    = math.floor((Clamp(currentScrollPos, 0, maxScroll) / maxScroll) * (trackH - thumbH))
    thumb:SetHeight(thumbH)
    thumb:ClearAnchors()
    thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, offset)
end

-------------------------------------------------------------------------------
-- Dynamic control pool
-------------------------------------------------------------------------------
-- ESO cannot destroy controls and the panel is rebuilt on every refresh, so
-- controls are pooled per kind and reused.
local HANDLERS_TO_RESET = {
    "OnMouseEnter", "OnMouseExit", "OnClicked", "OnMouseDown", "OnMouseUp",
    "OnTextChanged", "OnFocusLost", "OnFocusGained",
}

local pools = { label = {}, texture = {}, button = {}, edit = {} }
local activeControls = {}   -- { kind = ..., ctrl = ... } in use by the current render
local controlCounter = 0

local function CreatePooled(kind, parent)
    controlCounter = controlCounter + 1
    local name = "ConsoleMetricsPC_" .. kind .. controlCounter
    if kind == "label" then
        return WM:CreateControl(name, parent, CT_LABEL)
    elseif kind == "texture" then
        return WM:CreateControl(name, parent, CT_TEXTURE)
    elseif kind == "button" then
        return WM:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    elseif kind == "edit" then
        local backdrop = WM:CreateControlFromVirtual(name, parent, "ZO_EditBackdrop")
        backdrop.edit = WM:CreateControlFromVirtual(name .. "Box", backdrop, "ZO_DefaultEditForBackdrop")
        return backdrop
    end
end

local function ResetHandlers(ctrl)
    for i = 1, #HANDLERS_TO_RESET do
        pcall(ctrl.SetHandler, ctrl, HANDLERS_TO_RESET[i], nil)
    end
    -- Forward wheel events so scrolling works over every row.
    pcall(ctrl.SetHandler, ctrl, "OnMouseWheel", function(_, delta) ScrollContent(delta) end)
end

local function Acquire(kind, parent)
    local ctrl = table.remove(pools[kind])
    if not ctrl then
        ctrl = CreatePooled(kind, parent)
    else
        ctrl:SetParent(parent)
    end

    ctrl:ClearAnchors()
    ctrl:SetHidden(false)
    ctrl:SetMouseEnabled(kind == "button" or kind == "edit")
    ResetHandlers(ctrl)

    if kind == "label" then
        ctrl:SetDimensions(0, 0)   -- auto-size; builders set widths where needed
        ctrl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        ctrl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        ctrl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    elseif kind == "texture" then
        ctrl:SetTexture("")
        ctrl:SetTextureCoords(0, 1, 0, 1)
        ctrl:SetColor(1, 1, 1, 1)
    elseif kind == "button" then
        ctrl:SetEnabled(true)
    elseif kind == "edit" then
        ResetHandlers(ctrl.edit)
        ctrl.edit:SetMouseEnabled(true)
    end

    activeControls[#activeControls + 1] = { kind = kind, ctrl = ctrl }
    return ctrl
end

local function ReleaseAll()
    for i = 1, #activeControls do
        local entry = activeControls[i]
        if entry.kind == "edit" then
            pcall(entry.ctrl.edit.LoseFocus, entry.ctrl.edit)
        end
        entry.ctrl:SetHidden(true)
        entry.ctrl:ClearAnchors()
        local pool = pools[entry.kind]
        pool[#pool + 1] = entry.ctrl
    end
    activeControls = {}
    contentHeight = 0
    rowIndex = 0
    HideCMTooltip()
end

-- True while any edit box in the current render has keyboard focus.
function ConsoleMetrics:IsPCDialogEditing()
    if not pcDlg.window or pcDlg.window:IsHidden() then
        return false
    end
    for i = 1, #activeControls do
        local entry = activeControls[i]
        if entry.kind == "edit" then
            local ok, focused = pcall(entry.ctrl.edit.HasFocus, entry.ctrl.edit)
            if ok and focused then
                return true
            end
        end
    end
    return false
end

-------------------------------------------------------------------------------
-- Content builder helpers
-------------------------------------------------------------------------------
local function AdvanceCursor(h, extra)
    contentHeight = contentHeight + h + (extra or 0)
end

local function ContentY()
    return contentHeight
end

-- Section header: gold caps text over the divider art.
local function AddSection(content, text)
    if contentHeight > 0 then
        AdvanceCursor(10)
    end
    local y = ContentY()
    local lbl = Acquire("label", content)
    lbl:SetFont(FONT_SECTION)
    SetColor(lbl, COL_NORMAL)
    lbl:SetText(zo_strupper and zo_strupper(text or "") or string.upper(text or ""))
    lbl:SetAnchor(TOPLEFT, content, TOPLEFT, 2, y + 6)
    lbl:SetDimensions(CONTENT_W - 4, 26)

    local line = Acquire("texture", content)
    line:SetTexture(DIVIDER_TEXTURE)
    line:SetTextureCoords(0.181640625, 0.818359375, 0, 1)
    line:SetAnchor(TOPLEFT,  content, TOPLEFT,  -6, y + 34)
    line:SetAnchor(TOPRIGHT, content, TOPRIGHT,  6, y + 34)
    line:SetHeight(4)

    rowIndex = 0
    AdvanceCursor(SECTION_H)
end

-- Stat row: gold label on the left, white value on the right, alternating
-- shading, hover highlight and a tooltip when one is given.
local function AddStat(content, leftText, rightText, tooltip)
    local y = ContentY()
    rowIndex = rowIndex + 1

    local bg = Acquire("texture", content)
    bg:SetAnchor(TOPLEFT,  content, TOPLEFT,  0, y)
    bg:SetAnchor(TOPRIGHT, content, TOPRIGHT, 0, y)
    bg:SetHeight(STAT_H)
    local base = (rowIndex % 2 == 0) and COL_ROW_ALT or { 0, 0, 0, 0 }
    bg:SetColor(base[1], base[2], base[3], base[4])

    local lbl = Acquire("label", bg)
    lbl:SetFont(FONT_STAT)
    SetColor(lbl, rightText and COL_NORMAL or COL_SELECTED)
    lbl:SetText(leftText or "")
    lbl:SetAnchor(LEFT, bg, LEFT, PADDING, 0)
    lbl:SetDimensions(rightText and (CONTENT_W * 0.58) or (CONTENT_W - PADDING * 2), STAT_H)

    if rightText then
        local rbl = Acquire("label", bg)
        rbl:SetFont(FONT_VALUE)
        SetColor(rbl, COL_SELECTED)
        rbl:SetText(tostring(rightText))
        rbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        rbl:SetAnchor(RIGHT, bg, RIGHT, -PADDING, 0)
        rbl:SetDimensions(CONTENT_W * 0.40, STAT_H)
    end

    if tooltip then
        bg:SetMouseEnabled(true)
        bg:SetHandler("OnMouseEnter", function(ctrl)
            ctrl:SetColor(COL_ROW_HOVER[1], COL_ROW_HOVER[2], COL_ROW_HOVER[3], COL_ROW_HOVER[4])
            ShowCMTooltip(ctrl, tooltip)
        end)
        bg:SetHandler("OnMouseExit", function(ctrl)
            ctrl:SetColor(base[1], base[2], base[3], base[4])
            HideCMTooltip()
        end)
    end

    AdvanceCursor(STAT_H)
end

-- Row of big number tiles for the summary page.
-- tiles: array of { label, value, tooltip }
local function AddTiles(content, tiles, perRow)
    perRow = perRow or 4
    local gap = 8
    local tileW = math.floor((CONTENT_W - gap * (perRow - 1)) / perRow)
    for i = 1, #tiles do
        local col = (i - 1) % perRow
        if col == 0 and i > 1 then
            AdvanceCursor(TILE_H, gap)
        end
        local y = ContentY()
        local tile = Acquire("texture", content)
        tile:SetAnchor(TOPLEFT, content, TOPLEFT, col * (tileW + gap), y)
        tile:SetDimensions(tileW, TILE_H)
        tile:SetColor(COL_TILE_BG[1], COL_TILE_BG[2], COL_TILE_BG[3], COL_TILE_BG[4])

        local value = Acquire("label", tile)
        value:SetFont(FONT_TILE)
        SetColor(value, COL_SELECTED)
        value:SetText(tostring(tiles[i].value or ""))
        value:SetAnchor(TOPLEFT, tile, TOPLEFT, 12, 8)
        value:SetDimensions(tileW - 24, 34)

        local caption = Acquire("label", tile)
        caption:SetFont(FONT_TILE_CAP)
        SetColor(caption, COL_NORMAL)
        caption:SetText(zo_strupper and zo_strupper(tiles[i].label or "") or string.upper(tiles[i].label or ""))
        caption:SetAnchor(BOTTOMLEFT, tile, BOTTOMLEFT, 12, -8)
        caption:SetDimensions(tileW - 24, 20)

        if tiles[i].tooltip then
            local tip = tiles[i].tooltip
            tile:SetMouseEnabled(true)
            tile:SetHandler("OnMouseEnter", function(ctrl)
                ctrl:SetColor(0, 0, 0, 0.6)
                ShowCMTooltip(ctrl, tip)
            end)
            tile:SetHandler("OnMouseExit", function(ctrl)
                ctrl:SetColor(COL_TILE_BG[1], COL_TILE_BG[2], COL_TILE_BG[3], COL_TILE_BG[4])
                HideCMTooltip()
            end)
        end
    end
    if #tiles > 0 then
        AdvanceCursor(TILE_H, 4)
    end
end

-- Standard ESO button.
local function AddButton(content, labelText, tooltip, callback, disabled)
    AdvanceCursor(BTN_PAD / 2)
    local y = ContentY()
    local btn = Acquire("button", content)
    btn:SetDimensions(BTN_W, BTN_H)
    btn:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, y)
    btn:SetText(labelText)
    btn:SetEnabled(not disabled)

    btn:SetHandler("OnMouseEnter", function(ctrl) ShowCMTooltip(ctrl, tooltip) end)
    btn:SetHandler("OnMouseExit",  function() HideCMTooltip() end)
    -- Hold off live rebuilds between press and release so the click is not lost.
    btn:SetHandler("OnMouseDown", function() mouseButtonDown = true; NoteInteraction() end)
    btn:SetHandler("OnMouseUp", function() mouseButtonDown = false; NoteInteraction() end)

    if callback and not disabled then
        btn:SetHandler("OnClicked", function()
            mouseButtonDown = false
            NoteInteraction()
            callback()
            -- A callback may have closed the window; RefreshPCDialog checks that.
            ConsoleMetrics:RefreshPCDialog()
        end)
    end

    AdvanceCursor(BTN_H, BTN_PAD / 2)
end

-- Text field (save-name inputs etc.) using the base-game edit box.
local function AddEditBox(content, labelText, getter, setter, maxChars)
    local y = ContentY()
    local lbl = Acquire("label", content)
    lbl:SetFont(FONT_STAT)
    SetColor(lbl, COL_NORMAL)
    lbl:SetText(labelText or "")
    lbl:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, y)
    lbl:SetDimensions(CONTENT_W - PADDING * 2, STAT_H)
    AdvanceCursor(STAT_H)

    local holder = Acquire("edit", content)
    holder:SetAnchor(TOPLEFT, content, TOPLEFT, PADDING, ContentY())
    holder:SetDimensions(CONTENT_W - PADDING * 2, 30)

    local edit = holder.edit
    edit:SetMaxInputChars(maxChars or 80)
    edit:SetText(getter and getter() or "")
    edit:SetHandler("OnMouseDown", function(ctrl) ctrl:TakeFocus() end)
    edit:SetHandler("OnTextChanged", function(ctrl)
        NoteInteraction()
        if setter then setter(ctrl:GetText()) end
    end)
    edit:SetHandler("OnFocusLost", function(ctrl)
        if setter then setter(ctrl:GetText()) end
    end)
    pcall(edit.SetHandler, edit, "OnEnter", function(ctrl) ctrl:LoseFocus() end)
    pcall(edit.SetHandler, edit, "OnEscape", function(ctrl) ctrl:LoseFocus() end)

    AdvanceCursor(30, BTN_PAD)
    return edit
end

-- Horizontal divider.
local function AddDivider(content)
    local y = ContentY()
    local line = Acquire("texture", content)
    line:SetTexture(DIVIDER_TEXTURE)
    line:SetTextureCoords(0.181640625, 0.818359375, 0, 1)
    line:SetAnchor(TOPLEFT,  content, TOPLEFT,  0, y + 6)
    line:SetAnchor(TOPRIGHT, content, TOPRIGHT, 0, y + 6)
    line:SetHeight(4)
    AdvanceCursor(16)
end

-------------------------------------------------------------------------------
-- Commit / scroll-range update
-------------------------------------------------------------------------------
local function CommitContent(resetScroll)
    pcDlg.content:SetHeight(math.max(contentHeight + PADDING * 2, 100))
    if resetScroll then
        currentScrollPos = 0
    end
    ConsoleMetrics:SetScrollPos(currentScrollPos)
end

-------------------------------------------------------------------------------
-- Panel rendering helpers
-------------------------------------------------------------------------------
-- Fight navigation and "back" now live in the window chrome (footer and
-- category list); panels keep calling these so the renderers stay simple.
local function AddFightNavButtons() end
local function AddBackButton() end

-------------------------------------------------------------------------------
-- Summary panel
-------------------------------------------------------------------------------
local function RenderMain(content, self)
    local snap = self:GetViewedFightSnapshot() or {}
    pcDlg.breadcrumb:SetText("Summary")

    local bs = snap.burstWindowStats or {}
    local hs = snap.healingWindowStats or {}
    local topDmgSkill  = (snap.skillList or {})[1]
    local topHealSkill = (snap.healSkillList or {})[1]
    local duration = snap.duration or 0
    local perSec = function(total) return duration > 0 and (total or 0) / duration or 0 end

    AddTiles(content, {
        { label = "Damage / s", value = ShortNumber(snap.dps or 0),
          tooltip = "Damage per second (total damage / duration)" },
        { label = "Healing / s", value = ShortNumber(snap.hps or 0),
          tooltip = "Healing per second (total healing / duration)" },
        { label = "Taken / s", value = ShortNumber(perSec(snap.totalTaken)),
          tooltip = "Damage taken per second" },
        { label = "Duration", value = string.format("%.1fs", duration),
          tooltip = "Total fight time" },
        { label = "Critical", value = string.format("%.1f%%", snap.critPct or 0),
          tooltip = "Share of your outgoing hits that were critical" },
        { label = "Peak DPS", value = ShortNumber(snap.peakDps or 0),
          tooltip = bs.peakWindowTime and ("Highest burst-window DPS, at " .. bs.peakWindowTime) or "Highest burst-window DPS" },
        { label = "Peak HPS", value = ShortNumber(snap.peakHps or 0),
          tooltip = hs.peakWindowTime and ("Highest burst-window HPS, at " .. hs.peakWindowTime) or "Highest burst-window HPS" },
        { label = "Shielded", value = ShortNumber(snap.totalIncomingShieldedDamage or 0),
          tooltip = "Incoming damage absorbed by shields on you" },
    }, 4)

    AddSection(content, "Totals")
    AddStat(content, "Damage Done",  NumberText(snap.totalDamage or 0),
        topDmgSkill
            and string.format("Total outgoing damage\nTop ability: %s  -  %s  (%d hits)",
                topDmgSkill.name or "?", NumberText(topDmgSkill.damage or 0), topDmgSkill.hits or 0)
            or  "Total outgoing damage dealt this fight")
    AddStat(content, "Healing Done", NumberText(snap.totalHeal or 0),
        topHealSkill
            and string.format("Total outgoing healing\nTop ability: %s  -  %s",
                topHealSkill.name or "?", NumberText(topHealSkill.heal or 0))
            or  "Total outgoing healing this fight")
    AddStat(content, "Damage Taken", NumberText(snap.totalTaken or 0),
        string.format("Incoming damage\nOverflow: %s\nBlocked: %s\nShielded: %s",
            NumberText(snap.totalIncomingOverflowDamage or 0),
            NumberText(snap.totalIncomingBlockedDamage or 0),
            NumberText(snap.totalIncomingShieldedDamage or 0)))
    AddStat(content, "Hit Range",
        string.format("%s - %s", NumberText(snap.minHitValue or 0), NumberText(snap.maxHitValue or 0)),
        "Smallest and largest hit this fight")
    AddStat(content, "Peak DPS (5s)", ShortNumber(snap.peakDps or 0),
        bs.peakWindowTime and ("Best one-second damage at " .. bs.peakWindowTime) or nil)
    AddStat(content, "Peak HPS (5s)", ShortNumber(snap.peakHps or 0),
        hs.peakWindowTime and ("Best one-second healing at " .. hs.peakWindowTime) or nil)

    local skills = snap.skillList or {}
    if #skills > 0 then
        AddSection(content, "Top Abilities")
        local total = math.max(1, snap.totalDamage or 0)
        for i = 1, math.min(5, #skills) do
            local s = skills[i]
            AddStat(content, string.format("%d.  %s", i, s.name or "?"),
                string.format("%s  (%.0f%%)", ShortNumber(s.damage or 0), (s.damage or 0) / total * 100),
                string.format("%d hits  |  max %s", s.hits or 0, NumberText(s.maxHit or 0)))
        end
    end

    AddSection(content, string.format("History  (%d stored, %d saved)", #self.fightHistory, #self:GetSavedFights()))
    AddButton(content, "Save This Fight...", "Name and keep this fight across sessions",
        function()
            self.saved.saveFightDraftName = BuildDefaultFightSaveName(snap, #self:GetSavedFights() + 1)
            self.dialogPanel = "save"
        end)
    AddButton(content, "Saved Fights", string.format("Browse %d saved fights", #self:GetSavedFights()),
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
    AddStat(content, "Blocked Taken",   NumberText(snap.totalIncomingBlockedDamage  or 0))
    AddStat(content, "Shielded Taken",  NumberText(snap.totalIncomingShieldedDamage or 0))
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
                string.format("avg %.1f%%  med %.1f%%  (%d samples)",
                    tbl.averagePct or 0, tbl.medianPct or 0, tbl.samples or 0),
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
            AddStat(content, string.format("%d. %s", i, m.label or m.abilityName or "?"), nil, m.tooltip)
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
    local model = self:GetBehaviorModel(isLive and snap or nil) or {}
    local prot = snap.protectionSummary or {}

    AddSection(content, "Resistance & Damage Reduction (ML-lite)")
    AddStat(content, "Predicted Resistance", NumberText(model.predictedResistance or 0),
        "Estimated target resistance from observed mitigation samples, clamped to 0-33,000")
    AddStat(content, "Predicted DR %",       string.format("%.1f%%", model.predictedDrPct or 0),
        "Damage reduction estimate: DR = resistance / 66,000 (max 50%)")
    AddStat(content, "Predicted Protections", model.predictedProtectionLabel or "No mitigation data",
        "Protection state inferred from predicted DR")
    AddStat(content, "Confidence",           string.format("%.0f%%", (model.predictedProtectionConfidence or 0) * 100))
    AddStat(content, "Resistance Samples",   tostring(model.resistanceSamples or 0))

    AddSection(content, "Inferred Protection Uptime (this fight)")
    AddStat(content, "Any Protection", string.format("%.1f%%", prot.anyProtectionPct or 0),
        "Share of fight time with inferred Major and/or Minor Protection")
    AddStat(content, "Major",          string.format("%.1f%%", prot.majorPct or 0))
    AddStat(content, "Minor",          string.format("%.1f%%", prot.minorPct or 0))
    AddStat(content, "Major + Minor",  string.format("%.1f%%", prot.majorMinorPct or 0))
    AddStat(content, "Unknown",        string.format("%.1f%%", prot.unknownPct or 0), "Time without any mitigation signal")

    local targets = snap.targetList or {}
    if #targets > 0 then
        AddSection(content, "Per-Target Estimates")
        for i = 1, math.min(10, #targets) do
            local t = targets[i]
            if t then
                local drPct = Clamp(((t.estimatedResistance or 0) / RESISTANCE_SCALE) * 100, 0, 50)
                local label, _, confidence = InferProtectionFromDr(drPct, true)
                AddStat(content, t.name or "?",
                    string.format("~%s resistance  (%.1f%% DR)", NumberText(t.estimatedResistance or 0), drPct),
                    string.format("%s  |  %d hits dealt  |  %s total damage  |  %s (confidence %.0f%%)",
                        t.name or "?", t.hits or 0, NumberText(t.damage or 0), label, confidence * 100))
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

    local function OnOff(flag)
        return flag and "ON" or "OFF"
    end

    AddSection(content, "Toggles")
    AddButton(content, "Dialog Auto-Hide: " .. OnOff(sv.dialogAutoHide),
        "Auto-close this dialog after combat ends",
        function() self:SetDialogAutoHide(not sv.dialogAutoHide) end)
    AddButton(content, "Close on Movement: " .. OnOff(sv.closeOnMove),
        "Close this dialog automatically when controller stick or movement key is pressed",
        function() sv.closeOnMove = not sv.closeOnMove end)
    AddButton(content, "Auto-Clear on Next Fight: " .. OnOff(sv.autoClearOnNextFight),
        "Switch back to the live fight view when a new fight starts",
        function() sv.autoClearOnNextFight = not sv.autoClearOnNextFight end)
    AddButton(content, "Low Memory Mode: " .. OnOff(sv.lowMemoryMode),
        "Compact fight snapshots to reduce memory use",
        function() self:SetLowMemoryMode(not sv.lowMemoryMode) end)
    AddButton(content, "Performance Mode: " .. OnOff(sv.performanceMode),
        "Apply the lightweight performance preset",
        function() self:SetPerformanceMode(not sv.performanceMode) end)
    AddButton(content, "Behavior Model: " .. OnOff(sv.behaviorModelEnabled),
        "Enable the ML-lite resistance/behavior predictor",
        function() self:SetBehaviorModelEnabled(not sv.behaviorModelEnabled) end)
    AddButton(content, "Debug Output: " .. OnOff(sv.debugEnabled),
        "Print fight start/end and other diagnostic lines to chat",
        function() sv.debugEnabled = not sv.debugEnabled end)

    AddSection(content, "Fight History & Data")
    AddStat(content, string.format("History:  %d fights stored  (max %d)",
        #self.fightHistory, sv.maxFightHistory or self.defaults.maxFightHistory), nil)
    AddButton(content, "Clear All Fight Data",
        "Wipe current fight and all stored history",
        function() self:ResetFightData(false) ; self:Print("Fight data cleared.") end)
    AddButton(content, "Import PvPCooldownTracker Set Rules",
        "Scans PvPCooldownTracker tables and imports ability-based set rules",
        function() local _, message = self:ImportSetsFromPvPCooldownTracker() ; self:Print(message) end)
    AddButton(content, string.format("Clear Custom Set Rules (%d)", #(sv.customSetRules or {})),
        "Removes all custom set rules added through commands or import",
        function() self:ClearCustomSetRules() ; self:Print("Cleared all custom set rules.") end)

    AddSection(content, "Slash Commands Reference")
    local help = {
        "/cm view        - open this dialog",
        "/cm next/prev   - step through fight history",
        "/cm clear       - clear fight data",
        "/cm share       - share fight stats to chat",
        "/cm share build - share build to chat",
        "/cm linkbuild   - same as share build",
        "/cm reset       - reset options to defaults (keeps saves and set rules)",
        "/cm help        - full command reference",
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
                BuildDefaultFightSaveName(snap, #self:GetSavedFights() + 1)
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
    local saves = self:GetSavedFights()
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
                self:ClearSavedFights()
                self:Print("All saved fights cleared.")
            end)
    end
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- LibFights panel
-------------------------------------------------------------------------------
local function RenderLibFights(content, self)
    local bridge = self.LibFightsBridge
    pcDlg.breadcrumb:SetText("LibFights")

    local rows = self:BuildLibFightsRows()
    for i = 1, #rows do
        local row = rows[i]
        if row.section then
            AddSection(content, row.section)
        else
            AddStat(content, row.label, row.value or "", row.tooltip)
        end
    end

    if bridge.IsAvailable() then
        AddSection(content, "LibFights Controls")
        if bridge.IsLogging() then
            AddButton(content, "Stop LibFights Logging", "Stop_Logging(): end the current fight and unregister LibFights events",
                function() self:StopLibFightsLogging() end)
        else
            AddButton(content, "Start LibFights Logging", "Start_Logging(): LibFights records nothing until this is called",
                function()
                    local ok, reason = self:StartLibFightsLogging()
                    if not ok then
                        self:Print("LibFights: " .. tostring(reason))
                    end
                end)
        end
        AddButton(content, "Previous LibFights Fight", "Show the LibFights fight before this one",
            function() self:StepLibFightsView(-1) end)
        AddButton(content, "Next LibFights Fight", "Show the next LibFights fight (towards the live one)",
            function() self:StepLibFightsView(1) end)
        AddButton(content, "Print LibFights Report", "Print the full LibFights report for this fight to chat",
            function() self:PrintLibFightsLines("all") end)
    end
    AddBackButton(content, self)
end

-------------------------------------------------------------------------------
-- Router: pick and render the correct panel
-------------------------------------------------------------------------------
local PANELS = {
    libfights   = RenderLibFights,
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
    ReleaseAll()

    local panel = self.dialogPanel or "main"
    if not PANELS[panel] then
        panel = "main"
        self.dialogPanel = panel
    end
    local panelChanged = (panel ~= lastRenderedPanel)
    lastRenderedPanel = panel

    UpdateChrome(self, panel)
    PANELS[panel](pcDlg.content, self)
    CommitContent(panelChanged)
end
