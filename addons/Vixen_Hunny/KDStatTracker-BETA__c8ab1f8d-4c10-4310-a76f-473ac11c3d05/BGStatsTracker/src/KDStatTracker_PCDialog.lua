-- KDStatTracker_PCDialog.lua
-- Keyboard/mouse stats window, styled after the base-game keyboard UI:
-- standard window backdrop, journal-style page list on the left, stat tiles,
-- a mouse-wheel scrolling list, ESO buttons and the regular tooltip.
-- ESC and cursor handling come from SCENE_MANAGER's top-level windows.

local KDST = KDStatTracker
local C = KDST.COLORS
local Views = KDST.Views
local WM = WINDOW_MANAGER

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local WIN_W, WIN_H = 900, 640
local HEADER_H     = 64
local FOOTER_H     = 56
local EDGE         = 22
local NAV_W        = 190
local GAP          = 18
local TILE_H       = 74
local TILE_GAP     = 10
local ROW_H        = 28
local SB_W         = 6
local NAV_ROW_H    = 34
local BTN_H        = 30

local CONTENT_X = EDGE + NAV_W + GAP
local CONTENT_W = WIN_W - CONTENT_X - EDGE
local BODY_TOP  = HEADER_H + 14
local LIST_TOP  = BODY_TOP + TILE_H + 16
local LIST_H    = WIN_H - FOOTER_H - 10 - LIST_TOP
local VISIBLE_ROWS = math.floor(LIST_H / ROW_H)

local FONT_TITLE    = "ZoFontWinH1"
local FONT_SUBTITLE = "ZoFontWinH4"
local FONT_NAV      = "ZoFontHeader2"
local FONT_NAV_HEAD = "ZoFontWinH5"
local FONT_SECTION  = "ZoFontWinH4"
local FONT_STAT     = "ZoFontGame"
local FONT_VALUE    = "ZoFontGameBold"
local FONT_TILE     = "ZoFontWinH1"
local FONT_TILE_SM  = "ZoFontWinH3"
local FONT_TILE_CAP = "ZoFontWinH5"
local FONT_HINT     = "ZoFontGameSmall"

local DIVIDER_TEXTURE = "EsoUI/Art/Miscellaneous/horizontalDivider.dds"

local function Col(def, r, g, b)
    if def and def.UnpackRGBA then
        local cr, cg, cb, ca = def:UnpackRGBA()
        return { cr, cg, cb, ca or 1 }
    end
    return { r, g, b, 1 }
end
local COL_NORMAL    = Col(ZO_NORMAL_TEXT,   0.773, 0.761, 0.620)
local COL_SELECTED  = Col(ZO_SELECTED_TEXT, 1, 1, 1)
local COL_HIGHLIGHT = Col(ZO_HIGHLIGHT_TEXT, 1, 1, 1)
local COL_DISABLED  = Col(ZO_DISABLED_TEXT, 0.38, 0.38, 0.38)
local COL_HEADER    = Col(ZO_SECOND_CONTRAST_TEXT, 0.933, 0.886, 0.722)
local COL_ROW_ALT   = { 0, 0, 0, 0.28 }
local COL_ROW_HOVER = { 1, 1, 1, 0.07 }
local COL_TILE_BG   = { 0, 0, 0, 0.42 }
local COL_NAV_SEL   = { 0.773, 0.761, 0.620, 0.16 }

local function SetColor(ctrl, col) ctrl:SetColor(col[1], col[2], col[3], col[4] or 1) end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local pc = { pageIndex = 1, offset = 0, rows = {} }
KDST.pcDialog = pc

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function ShowTooltip(owner, text)
    if not text or text == "" then return end
    InitializeTooltip(InformationTooltip, owner, LEFT, 12, 0, RIGHT)
    SetTooltipText(InformationTooltip, text)
end

local function HideTooltip() ClearTooltip(InformationTooltip) end

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
    btn:SetDimensions(width or 150, BTN_H)
    btn:SetText(text)
    btn:SetHandler("OnClicked", onClick)
    return btn
end

local function MakeBackdrop(name, parent, col)
    local bd = WM:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(col[1], col[2], col[3], col[4])
    bd:SetEdgeTexture("", 1, 1, 1, 0)
    bd:SetEdgeColor(C.accent.r, C.accent.g, C.accent.b, 0.18)
    return bd
end

-------------------------------------------------------------------------------
-- Construction
-------------------------------------------------------------------------------
local function CreateNav(win)
    local nav = WM:CreateControl("$(parent)Nav", win, CT_CONTROL)
    nav:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE, BODY_TOP)
    nav:SetDimensions(NAV_W, LIST_TOP + LIST_H - BODY_TOP)

    local head = MakeLabel("$(parent)Head", nav, FONT_NAV_HEAD, COL_HEADER, "STATISTICS")
    head:SetAnchor(TOPLEFT, nav, TOPLEFT, 4, 4)

    pc.navRows = {}
    for i, def in ipairs(Views.PAGES) do
        local row = WM:CreateControl("$(parent)Row" .. i, nav, CT_CONTROL)
        row:SetAnchor(TOPLEFT, nav, TOPLEFT, 0, 28 + (i - 1) * NAV_ROW_H)
        row:SetDimensions(NAV_W, NAV_ROW_H)
        row:SetMouseEnabled(true)

        local highlight = WM:CreateControl("$(parent)Highlight", row, CT_TEXTURE)
        highlight:SetAnchorFill(row)
        SetColor(highlight, COL_NAV_SEL)
        highlight:SetHidden(true)

        local marker = WM:CreateControl("$(parent)Marker", row, CT_TEXTURE)
        marker:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 4)
        marker:SetDimensions(3, NAV_ROW_H - 8)
        marker:SetColor(C.accent:UnpackRGBA())
        marker:SetHidden(true)

        local label = MakeLabel("$(parent)Label", row, FONT_NAV, COL_NORMAL, def.title)
        label:SetAnchor(LEFT, row, LEFT, 14, 0)

        row:SetHandler("OnMouseEnter", function()
            if not row.selected then SetColor(label, COL_HIGHLIGHT) end
        end)
        row:SetHandler("OnMouseExit", function()
            if not row.selected then SetColor(label, COL_NORMAL) end
        end)
        row:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                pc:SelectPage(i)
            end
        end)

        pc.navRows[i] = { control = row, highlight = highlight, marker = marker, label = label }
    end
end

local function CreateTiles(win)
    pc.tiles = {}
    local tileW = (CONTENT_W - TILE_GAP * 3) / 4
    for i = 1, 4 do
        local tile = MakeBackdrop("$(parent)Tile" .. i, win, COL_TILE_BG)
        tile:SetAnchor(TOPLEFT, win, TOPLEFT, CONTENT_X + (i - 1) * (tileW + TILE_GAP), BODY_TOP)
        tile:SetDimensions(tileW, TILE_H)

        local stripe = WM:CreateControl("$(parent)Stripe", tile, CT_TEXTURE)
        stripe:SetAnchor(TOPLEFT, tile, TOPLEFT, 1, 1)
        stripe:SetAnchor(TOPRIGHT, tile, TOPRIGHT, -1, 1)
        stripe:SetHeight(2)

        local value = MakeLabel("$(parent)Value", tile, FONT_TILE, COL_SELECTED, "")
        value:SetAnchor(TOP, tile, TOP, 0, 8)
        value:SetDimensions(tileW - 16, 34)
        value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        value:SetMaxLineCount(1)
        value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        local caption = MakeLabel("$(parent)Caption", tile, FONT_TILE_CAP, COL_NORMAL, "")
        caption:SetAnchor(BOTTOM, tile, BOTTOM, 0, -8)

        tile:SetMouseEnabled(true)
        tile:SetHandler("OnMouseEnter", function() ShowTooltip(tile, tile.tooltip) end)
        tile:SetHandler("OnMouseExit", HideTooltip)

        pc.tiles[i] = { control = tile, stripe = stripe, value = value, caption = caption }
    end
end

local function CreateList(win)
    local list = WM:CreateControl("$(parent)List", win, CT_CONTROL)
    list:SetAnchor(TOPLEFT, win, TOPLEFT, CONTENT_X, LIST_TOP)
    list:SetDimensions(CONTENT_W, LIST_H)
    list:SetMouseEnabled(true)
    list:SetHandler("OnMouseWheel", function(_, delta) pc:Scroll(-delta * 3) end)
    pc.list = list

    local rowW = CONTENT_W - SB_W - 8
    pc.rowControls = {}
    for i = 1, VISIBLE_ROWS do
        local row = WM:CreateControl("$(parent)Row" .. i, list, CT_CONTROL)
        row:SetAnchor(TOPLEFT, list, TOPLEFT, 0, (i - 1) * ROW_H)
        row:SetDimensions(rowW, ROW_H)
        row:SetMouseEnabled(true)

        local bg = WM:CreateControl("$(parent)BG", row, CT_TEXTURE)
        bg:SetAnchorFill(row)

        local value = MakeLabel("$(parent)Value", row, FONT_VALUE, COL_SELECTED, "")
        value:SetAnchor(RIGHT, row, RIGHT, -10, 0)
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        local label = MakeLabel("$(parent)Label", row, FONT_STAT, COL_NORMAL, "")
        label:SetAnchor(LEFT, row, LEFT, 10, 0)
        label:SetAnchor(RIGHT, value, LEFT, -16, 0)
        label:SetMaxLineCount(1)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        local underline = WM:CreateControl("$(parent)Underline", row, CT_TEXTURE)
        underline:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
        underline:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
        underline:SetHeight(1)
        underline:SetColor(C.accent.r, C.accent.g, C.accent.b, 0.35)

        local entry = { control = row, bg = bg, label = label, value = value, underline = underline }
        row:SetHandler("OnMouseWheel", function(_, delta) pc:Scroll(-delta * 3) end)
        row:SetHandler("OnMouseEnter", function()
            if entry.data and entry.data.kind == "row" then
                SetColor(bg, COL_ROW_HOVER)
                ShowTooltip(row, entry.data.tooltip)
            end
        end)
        row:SetHandler("OnMouseExit", function()
            HideTooltip()
            pc:StyleRow(entry)
        end)
        pc.rowControls[i] = entry
    end

    local track = WM:CreateControl("$(parent)Track", list, CT_TEXTURE)
    track:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, 0)
    track:SetDimensions(SB_W, LIST_H)
    track:SetColor(0, 0, 0, 0.35)
    local thumb = WM:CreateControl("$(parent)Thumb", track, CT_TEXTURE)
    thumb:SetWidth(SB_W)
    thumb:SetColor(C.accent.r, C.accent.g, C.accent.b, 0.7)
    pc.track, pc.thumb = track, thumb
end

local function CreateFooter(win)
    local footerY = -FOOTER_H / 2
    local hint = MakeLabel("$(parent)Hint", win, FONT_HINT, COL_DISABLED, "")
    hint:SetAnchor(LEFT, win, BOTTOMLEFT, EDGE, footerY)
    pc.hint = hint

    local resetChar = MakeButton("$(parent)ResetChar", win, "Reset Character", 170, function()
        KDST.ShowResetDialog("character")
    end)
    resetChar:SetAnchor(RIGHT, win, BOTTOMRIGHT, -EDGE, footerY)

    local resetSession = MakeButton("$(parent)ResetSession", win, "Reset Session", 150, function()
        KDST.ShowResetDialog("session")
    end)
    resetSession:SetAnchor(RIGHT, resetChar, LEFT, -8, 0)

    local hudToggle = MakeButton("$(parent)HUDToggle", win, "Toggle HUD", 130, function()
        KDST.ToggleHUD()
    end)
    hudToggle:SetAnchor(RIGHT, resetSession, LEFT, -8, 0)
end

function pc:Create()
    if self.window then return end

    local win = WM:CreateTopLevelWindow("KDStatTracker_PCDialog")
    win:SetDimensions(WIN_W, WIN_H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    self.window = win

    local bg = WM:CreateControlFromVirtual("$(parent)BG", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local title = MakeLabel("$(parent)Title", win, FONT_TITLE, COL_NORMAL, zo_strupper(KDST.displayName))
    title:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE, 14)

    local subtitle = MakeLabel("$(parent)Subtitle", win, FONT_SUBTITLE, COL_SELECTED, "")
    subtitle:SetAnchor(BOTTOMLEFT, title, BOTTOMRIGHT, 16, -3)
    self.subtitle = subtitle

    local close = WM:CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE + 4, 18)
    close:SetHandler("OnClicked", function() KDST.CloseStatsDialog() end)

    local top = MakeDivider("$(parent)TopDivider", win)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, EDGE - 6, HEADER_H)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -EDGE + 6, HEADER_H)

    local bottom = MakeDivider("$(parent)BottomDivider", win)
    bottom:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, EDGE - 6, -FOOTER_H)
    bottom:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -EDGE + 6, -FOOTER_H)

    CreateNav(win)
    CreateTiles(win)
    CreateList(win)
    CreateFooter(win)

    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterTopLevel) == "function" then
        self.isTopLevel = pcall(SCENE_MANAGER.RegisterTopLevel, SCENE_MANAGER, win, false)
    end

    KDST.callbacks:RegisterCallback("StatsChanged", function()
        if self:IsShowing() then self:Refresh() end
    end)
end

-------------------------------------------------------------------------------
-- Rendering
-------------------------------------------------------------------------------
local function Flatten(page)
    local rows = {}
    for _, section in ipairs(page.sections or {}) do
        rows[#rows + 1] = { kind = "section", label = section.title }
        if #section.rows == 0 then
            rows[#rows + 1] = { kind = "empty", label = section.empty or "Nothing here yet." }
        else
            for _, r in ipairs(section.rows) do
                rows[#rows + 1] = { kind = "row", label = r.label, value = r.value, color = r.color, tooltip = r.tooltip }
            end
        end
    end
    return rows
end

function pc:StyleRow(entry)
    local data = entry.data
    if not data then
        entry.bg:SetColor(0, 0, 0, 0)
        return
    end
    if data.kind == "row" and entry.index % 2 == 0 then
        SetColor(entry.bg, COL_ROW_ALT)
    else
        entry.bg:SetColor(0, 0, 0, 0)
    end
end

function pc:RenderRows()
    local rows = self.rows
    local altIndex = 0
    for i, entry in ipairs(self.rowControls) do
        local data = rows[self.offset + i]
        entry.data = data
        entry.control:SetHidden(data == nil)
        if data then
            if data.kind == "section" then
                altIndex = 0
                entry.label:SetFont(FONT_SECTION)
                SetColor(entry.label, COL_HEADER)
                entry.label:SetText(zo_strupper(data.label))
                entry.value:SetText("")
                entry.underline:SetHidden(false)
            elseif data.kind == "empty" then
                entry.label:SetFont(FONT_STAT)
                SetColor(entry.label, COL_DISABLED)
                entry.label:SetText(data.label)
                entry.value:SetText("")
                entry.underline:SetHidden(true)
            else
                altIndex = altIndex + 1
                entry.label:SetFont(FONT_STAT)
                if data.color then entry.label:SetColor(data.color:UnpackRGBA()) else SetColor(entry.label, COL_NORMAL) end
                entry.label:SetText(data.label)
                entry.value:SetText(data.value or "")
                entry.underline:SetHidden(true)
            end
            entry.index = altIndex
        end
        self:StyleRow(entry)
    end

    -- Scrollbar
    local total = #rows
    local scrollable = total > VISIBLE_ROWS
    self.track:SetHidden(not scrollable)
    if scrollable then
        local thumbH = math.max(24, LIST_H * VISIBLE_ROWS / total)
        local maxOffset = total - VISIBLE_ROWS
        local y = (LIST_H - thumbH) * (self.offset / maxOffset)
        self.thumb:ClearAnchors()
        self.thumb:SetAnchor(TOPLEFT, self.track, TOPLEFT, 0, y)
        self.thumb:SetHeight(thumbH)
    end

    if scrollable then
        self.hint:SetText(string.format("Rows %d-%d of %d  |  mouse wheel to scroll  |  /kdhelp for commands",
            self.offset + 1, math.min(total, self.offset + VISIBLE_ROWS), total))
    else
        self.hint:SetText("/kdhelp for commands  |  click the HUD to open this window")
    end
end

function pc:RenderTiles(page)
    for i, tile in ipairs(self.tiles) do
        local card = page.cards and page.cards[i]
        tile.control:SetHidden(card == nil)
        if card then
            tile.value:SetFont(card.small and FONT_TILE_SM or FONT_TILE)
            tile.value:SetText(card.value)
            tile.value:SetColor((card.color or C.text):UnpackRGBA())
            tile.caption:SetText(zo_strupper(card.label))
            local col = card.color or C.accent
            tile.stripe:SetColor(col.r, col.g, col.b, 0.85)
            tile.control.tooltip = card.small and card.value or nil
        end
    end
end

function pc:Refresh()
    if not self.window then return end
    local page = Views.Build(self.pageIndex)

    local subtitle = zo_strformat("<<1>>", KDST.charName)
    if KDST.match then
        subtitle = subtitle .. "  |  " .. KDST.Color(C.gold, "In Match")
    elseif KDST.IsInPvPArea() then
        subtitle = subtitle .. "  |  " .. KDST.Color(C.kill, "PvP Area")
    end
    self.subtitle:SetText(subtitle)

    for i, nav in ipairs(self.navRows) do
        local selected = i == self.pageIndex
        nav.control.selected = selected
        nav.highlight:SetHidden(not selected)
        nav.marker:SetHidden(not selected)
        SetColor(nav.label, selected and COL_SELECTED or COL_NORMAL)
    end

    self:RenderTiles(page)
    self.rows = Flatten(page)
    self.offset = zo_clamp(self.offset, 0, math.max(0, #self.rows - VISIBLE_ROWS))
    self:RenderRows()
end

function pc:Scroll(delta)
    local maxOffset = math.max(0, #self.rows - VISIBLE_ROWS)
    local newOffset = zo_clamp(self.offset + delta, 0, maxOffset)
    if newOffset ~= self.offset then
        self.offset = newOffset
        self:RenderRows()
    end
end

function pc:SelectPage(index)
    self.pageIndex = Views.Wrap(index)
    self.offset = 0
    self:Refresh()
end

-------------------------------------------------------------------------------
-- Open / close
-------------------------------------------------------------------------------
function pc:IsShowing()
    return self.window ~= nil and not self.window:IsHidden()
end

function pc:Open(pageIndex)
    self:Create()
    if pageIndex then
        self.pageIndex = Views.Wrap(pageIndex)
        self.offset = 0
    end
    if self.isTopLevel then
        SCENE_MANAGER:ShowTopLevel(self.window)
    else
        self.window:SetHidden(false)
    end
    self.window:BringWindowToTop()
    self:Refresh()
end

function pc:Close()
    if not self.window then return end
    HideTooltip()
    if self.isTopLevel then
        SCENE_MANAGER:HideTopLevel(self.window)
    else
        self.window:SetHidden(true)
    end
end
