-- The remastered scoreboard panel. One window, two styles:
--   keyboard  mouse UI attached to the native scoreboard; click a row for details
--   gamepad   console / gamepad mode, shown in its own scene (UI/Gamepad.lua); a
--             selected row moves with the d-pad and A / Cross opens its details
local SBR = ScoreboardRemastered
local UI = {
    rows = {},
    headers = {},
    columns = {},
    sort = { key = "s:SCORE", desc = true },
    viewIndex = nil,     -- nil = live, number = history index
    pinned = false,      -- opened manually, stays open when the native scoreboard closes
    selectedKey = nil,   -- player key of the selected row
    detailsOpen = false,
    mode = "keyboard",
}
SBR.Window = UI

local WM = WINDOW_MANAGER
local STRIP_W = 4

local function Font(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if _G[name] ~= nil then return name end
    end
    return "ZoFontGame"
end

local STYLES = {
    keyboard = {
        pad = 14, topH = 84, headerH = 26, rowH = 24, footerH = 42, colScale = 1, detailsW = 340, detailsMaxH = 760,
        fontRow = Font("ZoFontGameMedium", "ZoFontGame"), fontHead = Font("ZoFontGameSmall", "ZoFontGameBold"),
        fontTitle = Font("ZoFontWinH1", "ZoFontWinH2"), fontSub = "ZoFontGameSmall", fontTeams = Font("ZoFontWinH3", "ZoFontWinH4"),
        fontDetails = "ZoFontGameSmall", fontDetailsTitle = Font("ZoFontWinH3", "ZoFontWinH4"), iconSize = 22,
    },
    gamepad = {
        pad = 20, topH = 104, headerH = 34, rowH = 34, footerH = 34, colScale = 1.35, detailsW = 470, detailsMaxH = 790,
        fontRow = Font("ZoFontGamepad22", "ZoFontGame"),
        fontHead = Font("ZoFontGamepadBold22", "ZoFontGamepad22", "ZoFontGameBold"),
        fontTitle = Font("ZoFontGamepadBold34", "ZoFontGamepad34", "ZoFontWinH2"),
        fontSub = Font("ZoFontGamepad22", "ZoFontGame"),
        fontTeams = Font("ZoFontGamepadBold27", "ZoFontGamepad27", "ZoFontWinH3"),
        fontDetails = Font("ZoFontGamepad22", "ZoFontGame"),
        fontDetailsTitle = Font("ZoFontGamepadBold27", "ZoFontGamepad27", "ZoFontWinH3"),
        iconSize = 28,
    },
}

-- ESO's own UI colors (ZO_ColorDef globals), with the stock values as fallback.
local function ZoColor(name, hex)
    local c = _G[name]
    if type(c) == "table" and type(c.UnpackRGB) == "function" then
        local ok, r, g, b = pcall(c.UnpackRGB, c)
        if ok and type(r) == "number" then return { r, g, b } end
    end
    return { SBR.HexToRGB(hex) }
end
local function Hex(rgb)
    return string.format("%02X%02X%02X", math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end
local COLORS
local function Colors()
    if not COLORS then
        COLORS = {
            normal = ZoColor("ZO_NORMAL_TEXT", "C5C29E"),     -- standard list text
            selected = ZoColor("ZO_SELECTED_TEXT", "FFFFFF"), -- selected / important values
            disabled = ZoColor("ZO_DISABLED_TEXT", "5C5C5C"), -- empty cells
            gpUnselected = { 0.70, 0.70, 0.70 },              -- gamepad lists dim unselected rows
            fight = { 0.91, 0.78, 0.45 },
            vs = { 0.60, 0.80, 0.93 },
            you = { 0.55, 0.78, 0.93 },
        }
        COLORS.normalHex, COLORS.selectedHex, COLORS.disabledHex = Hex(COLORS.normal), Hex(COLORS.selected), Hex(COLORS.disabled)
    end
    return COLORS
end
local function Paint(control, rgb, a) control:SetColor(rgb[1], rgb[2], rgb[3], a or 1) end

-- ESO's stock list textures. Each sits on top of a plain colour fill, so the
-- panel still reads correctly if a path ever changes.
local TEX = {
    divider = "EsoUI/Art/Miscellaneous/horizontalDivider.dds",
    rowHighlight = "EsoUI/Art/Miscellaneous/listItem_highlight.dds",
    rowSelected = "EsoUI/Art/Miscellaneous/listItem_selectedHighlight.dds",
    sortUp = "EsoUI/Art/Miscellaneous/list_sortHeader_icon_sortUp.dds",
    sortDown = "EsoUI/Art/Miscellaneous/list_sortHeader_icon_sortDown.dds",
}

local function Uppercase(label)
    if MODIFY_TEXT_TYPE_UPPERCASE and label.SetModifyTextType then label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
end

local nameCounter = 0
local function NextName(kind)
    nameCounter = nameCounter + 1
    return string.format("SBR_%s%d", kind, nameCounter)
end

local function CreateLabel(parent, font, align)
    local l = WM:CreateControl(NextName("Label"), parent, CT_LABEL)
    l:SetFont(font or "ZoFontGameSmall")
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    Paint(l, Colors().normal)
    return l
end

local function CreateTexture(parent, r, g, b, a)
    local t = WM:CreateControl(NextName("Tex"), parent, CT_TEXTURE)
    t:SetColor(r, g, b, a)
    return t
end

local function CreateButton(parent, text, width, onClick)
    local b = WM:CreateControlFromVirtual(NextName("Button"), parent, "ZO_DefaultButton")
    b:SetText(text)
    b:SetDimensions(width, 28)
    b:SetHandler("OnClicked", onClick)
    return b
end

local function CreateBackdrop(parent, virtualNames)
    for _, v in ipairs(virtualNames) do
        local ok, bd = pcall(WM.CreateControlFromVirtual, WM, NextName("BG"), parent, v)
        if ok and bd then
            bd:SetAnchorFill(parent)
            return bd
        end
    end
    local bd = CreateTexture(parent, 0.05, 0.05, 0.06, 0.92)
    bd:SetAnchorFill(parent)
    return bd
end

local function ShowTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function PlayerKey(p)
    return (p.displayName and p.displayName ~= "") and p.displayName or p.characterName
end

---------------------------------------------------------------------------
-- Columns
---------------------------------------------------------------------------
-- gp = shown in the gamepad table, kb = shown in the PC table. Everything else is in
-- the details pane, so the table fits ESO's 1920 px canvas with the pane beside it
-- (checked by rendering the add-on's layout at ESO's real font sizes).
local FIGHT_COLUMNS = {
    { key = "dps", label = "DPS", tip = "Damage per second in combat", gp = true, kb = true },
    { key = "hps", label = "HPS", tip = "Healing per second in combat", gp = true, kb = true },
    { key = "damageTaken", label = "Taken", tip = "Damage taken", gp = true, kb = true },
    { key = "healingTaken", label = "Healed", tip = "Healing received", kb = true },
    { key = "killingBlows", label = "KBs", tip = "Killing blows", gp = true, kb = true },
    { key = "interrupts", label = "Intr", tip = "Interrupts" },
    { key = "ccApplied", label = "CC", tip = "Crowd control applied", kb = true },
    { key = "damageShielded", label = "Shield", tip = "Damage absorbed by shields" },
    { key = "critRate", label = "Crit%", tip = "Critical hit rate", kb = true, fmt = function(v) return string.format("%.0f%%", v) end },
    { key = "maxHit", label = "Max hit", tip = "Biggest single hit" },
}

local VS_COLUMNS = {
    { key = "damageFromYou", label = "You>", tip = "Damage you dealt to this player" },
    { key = "damageToYou", label = ">You", tip = "Damage this player dealt to you" },
    { key = "healedByYou", label = "You heal", tip = "Healing you gave this player" },
    { key = "killedByYou", label = "Killed", tip = "Times you killed this player (kill feed)" },
    { key = "killedYou", label = "By", tip = "Times this player killed you (kill feed)" },
}

local FIGHT_TIP = "\nYou: LibFights. Teammates: combat log (group members).\nEnemies: combat log, only what they did to and took from your team."

local function AnyValue(players, getter)
    for _, p in pairs(players) do
        local v = getter(p)
        if v ~= nil and v ~= 0 then return true end
    end
    return false
end

function UI:BuildColumns(match)
    local cols = {}
    local players = match.players or {}
    local hideEmpty = SBR.sv.hideEmptyColumns
    local gamepad = self.mode == "gamepad"
    local st_ = self.style
    local scale = st_.colScale

    cols[#cols + 1] = {
        key = "class", label = "", width = st_.iconSize + 6, align = TEXT_ALIGN_CENTER, priority = 0,
        text = function(p) return p.classIcon and zo_iconFormat(p.classIcon, st_.iconSize, st_.iconSize) or "" end,
        sortValue = function(p) return p.className or "" end,
    }
    cols[#cols + 1] = {
        key = "name", label = "Player", width = math.floor(200 * scale), align = TEXT_ALIGN_LEFT, priority = 0,
        text = function(p)
            local name = p.characterName ~= "" and p.characterName or p.displayName or "?"
            if p.left then name = "|c888888" .. name .. " (left)|r" end
            return name
        end,
        sortValue = function(p) return (p.characterName or ""):lower() end,
    }

    for _, st in ipairs(SBR.Battleground.scoreTypes or {}) do
        local key = st.key
        local get = function(p) return p.scores and p.scores[key] end
        if (match.columnsSeen and match.columnsSeen[key]) and (not hideEmpty or AnyValue(players, get)) then
            cols[#cols + 1] = {
                key = "s:" .. key, label = st.label, width = math.floor(math.max(52, #st.label * 8) * scale), numeric = true,
                value = get, tip = st.label .. " (native scoreboard)", priority = ({ 1, 2, 5 })[st.priority or 3] or 5,
            }
        end
    end

    cols[#cols + 1] = {
        key = "medals", label = "Medals", width = math.floor(56 * scale), numeric = true,
        value = function(p) return p.medalCount end, tip = "Medals earned (open a row for the list)", priority = 2,
    }

    if SBR.sv.showFightColumns then
        for _, fc in ipairs(FIGHT_COLUMNS) do
            if (gamepad and fc.gp) or (not gamepad and fc.kb) then
                local key = fc.key
                local get = function(p) return p.fight and p.fight[key] end
                if AnyValue(players, get) then
                    cols[#cols + 1] = {
                        key = "f:" .. key, label = fc.label, width = math.floor(56 * scale), numeric = true, value = get,
                        fmt = fc.fmt, tip = fc.tip .. FIGHT_TIP, fight = true, priority = fc.gp and 3 or 4,
                    }
                end
            end
        end
    end

    if SBR.sv.showVsColumns and not gamepad then
        for _, vc in ipairs(VS_COLUMNS) do
            local key = vc.key
            local get = function(p) return p.vs and p.vs[key] end
            if AnyValue(players, get) then
                cols[#cols + 1] = {
                    key = "v:" .. key, label = vc.label, width = 56, numeric = true, value = get, tip = vc.tip, vs = true, priority = 6,
                }
            end
        end
    end

    for _, c in ipairs(cols) do
        c.align = c.align or (c.numeric and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
        if c.numeric and not c.text then
            local value, fmt = c.value, c.fmt
            c.text = function(p)
                local v = value(p)
                if v == nil then return "-" end
                return fmt and fmt(v) or SBR.FormatNumber(v)
            end
        end
        c.sortValue = c.sortValue or c.value
    end
    self:FitColumns(cols)
    self.columns = cols
    return cols
end

-- Room on screen. GuiRoot is ESO's UI canvas: its size depends on resolution and UI
-- scale (1920 x 1080 at 1080p and 100%, smaller at higher UI scales or on 1366 x 768).
local SCREEN_MARGIN = 20
local MIN_TABLE_WIDTH = 640

-- Gamepad mode: ESO's keybind strip covers the bottom 128 px of the screen.
local GAMEPAD_STRIP_H = 128
function UI:GetBottomReserve()
    return self.mode == "gamepad" and GAMEPAD_STRIP_H or 0
end

function UI:GetScreenSize()
    return (GuiRoot and GuiRoot:GetWidth() or 1920), (GuiRoot and GuiRoot:GetHeight() or 1080)
end

-- Widest the table can be: the screen minus margins and, when there's room, the
-- details pane beside it (otherwise the pane opens over the right of the panel).
function UI:GetMaxContentWidth()
    local s = self.style
    local w = self:GetScreenSize()
    local avail = w - SCREEN_MARGIN * 2 - s.pad * 2
    self.paneBeside = avail - (s.detailsW + 8) >= MIN_TABLE_WIDTH
    if self.paneBeside then avail = avail - (s.detailsW + 8) end
    return avail
end

-- Drops the least important columns until the table fits on screen. Nothing is
-- lost: every score and fight stat is still in the details pane.
function UI:FitColumns(cols)
    local maxWidth = self:GetMaxContentWidth()
    local function total()
        local x = STRIP_W + 4
        for _, c in ipairs(cols) do x = x + c.width + 6 end
        return x
    end
    self.droppedColumns = {}
    while total() > maxWidth do
        local worst
        for i, c in ipairs(cols) do
            if (c.priority or 0) > 0 and (not worst or c.priority >= cols[worst].priority) then worst = i end
        end
        if not worst then break end
        self.droppedColumns[cols[worst].key] = true
        table.remove(cols, worst)
    end
    -- still too wide (tiny canvas): narrow the name column, down to 120
    local over = total() - maxWidth
    if over > 0 then
        for _, c in ipairs(cols) do
            if c.key == "name" then c.width = math.max(120, c.width - over) end
        end
    end
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function UI:Create()
    if self.control then return end
    self.style = STYLES.keyboard
    -- dims the native scoreboard behind the panel in "over" mode
    local dim = WM:CreateTopLevelWindow("ScoreboardRemasteredDim")
    dim:SetAnchorFill(GuiRoot)
    dim:SetDrawLayer(DL_OVERLAY)
    dim:SetDrawTier(DT_MEDIUM)
    dim:SetHidden(true)
    local dimTex = CreateTexture(dim, 0, 0, 0, 0.62)
    dimTex:SetAnchorFill(dim)
    self.dim = dim

    local tlw = WM:CreateTopLevelWindow("ScoreboardRemasteredWindow")
    self.control = tlw
    tlw:SetHidden(true)
    tlw:SetMouseEnabled(true)
    tlw:SetClampedToScreen(true)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    tlw:SetDimensions(900, 400)
    tlw:SetHandler("OnMoveStop", function(control)
        SBR.sv.position = { left = control:GetLeft(), top = control:GetTop() }
        self:ApplyPosition()
    end)

    self.bgKeyboard = CreateBackdrop(tlw, { "ZO_DefaultBackdrop" })
    self.bgGamepad = CreateBackdrop(tlw, { "ZO_DefaultBackdrop_Gamepad", "ZO_DefaultBackdrop" })

    self.closeButton = WM:CreateControlFromVirtual(NextName("Close"), tlw, "ZO_CloseButton")
    self.closeButton:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -6, 6)
    self.closeButton:SetHandler("OnClicked", function() self:Hide(true) end)

    self.title = CreateLabel(tlw)
    self.subtitle = CreateLabel(tlw)
    Uppercase(self.title)
    Paint(self.title, Colors().selected)
    self.teamLabel = CreateLabel(tlw, nil, TEXT_ALIGN_RIGHT)
    self.sourceLabel = CreateLabel(tlw, nil, TEXT_ALIGN_RIGHT)
    Paint(self.sourceLabel, Colors().normal, 0.7)
    self.divider = CreateTexture(tlw, 1, 1, 1, 0.12)
    self.divider:SetHeight(1)
    self.dividerTex = CreateTexture(tlw, 1, 1, 1, 1)
    self.dividerTex:SetTexture(TEX.divider)
    self.dividerTex:SetHeight(4)

    self.headerRow = WM:CreateControl(NextName("Header"), tlw, CT_CONTROL)
    self.list = WM:CreateControl(NextName("List"), tlw, CT_CONTROL)
    self.list:SetMouseEnabled(true)
    self.list:SetHandler("OnMouseWheel", function(_, delta) self:Scroll(delta > 0 and -3 or 3) end)

    self.emptyLabel = CreateLabel(self.list, "ZoFontGame", TEXT_ALIGN_CENTER)
    self.emptyLabel:SetAnchor(TOPLEFT, self.list, TOPLEFT, 0, 10)
    Paint(self.emptyLabel, Colors().normal, 0.8)

    -- footer (keyboard buttons; in gamepad mode the keybind strip replaces them)
    local footer = WM:CreateControl(NextName("Footer"), tlw, CT_CONTROL)
    footer:SetHeight(30)
    self.footer = footer

    self.buttons = {}
    local function button(text, width, fn)
        local b = CreateButton(footer, text, width, fn)
        self.buttons[#self.buttons + 1] = b
        return b
    end
    self.prevButton = button("<", 40, function() self:Step(-1) end)
    self.prevButton:SetAnchor(LEFT, footer, LEFT, 0, 0)
    self.liveButton = button("Live", 70, function() self:SetView(nil) end)
    self.liveButton:SetAnchor(LEFT, self.prevButton, RIGHT, 4, 0)
    self.nextButton = button(">", 40, function() self:Step(1) end)
    self.nextButton:SetAnchor(LEFT, self.liveButton, RIGHT, 4, 0)
    self.exportButton = button("Export", 90, function() SBR.Export:Show(self:GetViewedMatch()) end)
    self.exportButton:SetAnchor(RIGHT, footer, RIGHT, 0, 0)
    self.killsButton = button("Kill feed", 100, function() SBR.Export:ShowKillFeed(self:GetViewedMatch()) end)
    self.killsButton:SetAnchor(RIGHT, self.exportButton, LEFT, -4, 0)
    self.groupButton = button("", 120, function() self:ToggleGroupByTeam() end)
    self.groupButton:SetAnchor(RIGHT, self.killsButton, LEFT, -4, 0)

    self.viewLabel = CreateLabel(footer)
    self.viewLabel:SetDimensions(260, 28)
    Paint(self.viewLabel, Colors().normal, 0.8)

    self:CreateDetails()
    self:ApplyStyle("keyboard")
end

-- Details pane: what used to be the hover tooltip. Opens beside the panel.
function UI:CreateDetails()
    local pane = WM:CreateControl(NextName("Details"), self.control, CT_CONTROL)
    pane:SetHidden(true)
    pane:SetMouseEnabled(true)
    pane:SetDrawLevel(10) -- above the rows when it has to open over the panel
    pane:SetHandler("OnMouseWheel", function(_, delta) self:ScrollDetails(delta > 0 and -3 or 3) end)
    self.details = pane
    -- solid fill, shown only when the pane has to open over the panel
    self.detailsFill = CreateTexture(pane, 0, 0, 0, 0.9)
    self.detailsFill:SetAnchorFill(pane)
    self.detailsFill:SetHidden(true)
    self.detailsBgKeyboard = CreateBackdrop(pane, { "ZO_DefaultBackdrop" })
    self.detailsBgGamepad = CreateBackdrop(pane, { "ZO_DefaultBackdrop_Gamepad", "ZO_DefaultBackdrop" })

    self.detailsClose = WM:CreateControlFromVirtual(NextName("DetailsClose"), pane, "ZO_CloseButton")
    self.detailsClose:SetAnchor(TOPRIGHT, pane, TOPRIGHT, -6, 6)
    self.detailsClose:SetHandler("OnClicked", function() self:CloseDetails() end)

    self.detailsTitle = CreateLabel(pane)
    Uppercase(self.detailsTitle)
    self.detailsBody = CreateLabel(pane)
    Paint(self.detailsBody, Colors().selected)
    self.detailsBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.detailsBody:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
end

function UI:ApplyStyle(mode)
    self.mode = mode
    local s = STYLES[mode]
    self.style = s
    local tlw = self.control
    local gamepad = mode == "gamepad"

    self.bgKeyboard:SetHidden(gamepad)
    self.bgGamepad:SetHidden(not gamepad)
    self.detailsBgKeyboard:SetHidden(gamepad)
    self.detailsBgGamepad:SetHidden(not gamepad)
    self.closeButton:SetHidden(gamepad)
    self.detailsClose:SetHidden(gamepad)
    for _, b in ipairs(self.buttons) do b:SetHidden(gamepad) end
    tlw:SetMovable(not gamepad)
    tlw:SetScale(gamepad and 1 or (SBR.sv.scale or 1))

    self.title:SetFont(s.fontTitle)
    self.title:ClearAnchors()
    self.title:SetAnchor(TOPLEFT, tlw, TOPLEFT, s.pad, s.pad - 2)
    self.title:SetDimensions(600, s.topH * 0.4)
    self.subtitle:SetFont(s.fontSub)
    self.subtitle:ClearAnchors()
    self.subtitle:SetAnchor(TOPLEFT, self.title, BOTTOMLEFT, 0, 0)
    self.subtitle:SetDimensions(600, s.topH * 0.3)
    self.teamLabel:SetFont(s.fontTeams)
    self.teamLabel:ClearAnchors()
    self.teamLabel:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, gamepad and -s.pad or -40, s.pad)
    self.teamLabel:SetDimensions(520, s.topH * 0.35)
    self.sourceLabel:SetFont(s.fontSub)
    self.sourceLabel:ClearAnchors()
    self.sourceLabel:SetAnchor(TOPRIGHT, self.teamLabel, BOTTOMRIGHT, 0, 0)
    self.sourceLabel:SetDimensions(620, s.topH * 0.3)

    self.divider:ClearAnchors()
    self.divider:SetAnchor(TOPLEFT, tlw, TOPLEFT, s.pad, s.topH - 4)
    self.divider:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -s.pad, s.topH - 4)
    self.dividerTex:ClearAnchors()
    self.dividerTex:SetAnchor(LEFT, self.divider, LEFT, -s.pad, 0)
    self.dividerTex:SetAnchor(RIGHT, self.divider, RIGHT, s.pad, 0)
    self.headerRow:ClearAnchors()
    self.headerRow:SetAnchor(TOPLEFT, tlw, TOPLEFT, s.pad, s.topH)
    self.headerRow:SetHeight(s.headerH)
    self.list:ClearAnchors()
    self.list:SetAnchor(TOPLEFT, self.headerRow, BOTTOMLEFT, 0, 2)
    self.emptyLabel:SetFont(s.fontSub)
    self.emptyLabel:SetText(gamepad
        and "No battleground data yet. Join a battleground, or use the bumpers to browse past matches."
        or "No battleground data yet. Join a battleground, or browse history with < >.")

    self.footer:ClearAnchors()
    self.footer:SetAnchor(BOTTOMLEFT, tlw, BOTTOMLEFT, s.pad, -s.pad + 4)
    self.footer:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -s.pad, -s.pad + 4)
    self.viewLabel:SetFont(s.fontSub)
    self.viewLabel:ClearAnchors()
    if gamepad then
        self.viewLabel:SetAnchor(LEFT, self.footer, LEFT, 0, 0)
    else
        self.viewLabel:SetAnchor(LEFT, self.nextButton, RIGHT, 10, 0)
    end

    self.detailsTitle:SetFont(s.fontDetailsTitle)
    self.detailsBody:SetFont(s.fontDetails)
    self.details:SetWidth(s.detailsW)
    self.detailsTitle:ClearAnchors()
    self.detailsTitle:SetAnchor(TOPLEFT, self.details, TOPLEFT, s.pad, s.pad - 2)
    self.detailsTitle:SetDimensions(s.detailsW - s.pad * 2 - (gamepad and 0 or 24), s.rowH + 4)
    self.detailsBody:ClearAnchors()
    self.detailsBody:SetAnchor(TOPLEFT, self.detailsTitle, BOTTOMLEFT, 0, 4)
    self.detailsBody:SetWidth(s.detailsW - s.pad * 2)

    -- existing pooled controls pick up the new metrics in Refresh
    for _, h in ipairs(self.headers) do
        h:SetFont(s.fontHead)
        h:SetHeight(s.headerH)
    end
    for i, row in ipairs(self.rows) do
        self:StyleRow(row, i)
        -- new metrics: forget what FillRow cached so everything is laid out again
        row.slot, row.width = nil, nil
        for _, cell in ipairs(row.cells) do cell.colKey, cell.colX = nil, nil end
    end
    self.columnSig = nil
    self.detailsBodyText = nil
    self:ApplyPosition()
end

function UI:ApplyPosition()
    local c = self.control
    if not c then return end
    c:ClearAnchors()
    if self.mode == "gamepad" then
        -- centred above the keybind strip, leaving room for the details pane when it fits
        local r = self:GetPanelRect()
        c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, r.left, r.top)
        return
    end
    local pos = SBR.sv.position
    if pos and pos.left then
        -- a saved spot from an earlier, larger canvas (UI scale or resolution change)
        -- is pulled back on screen
        local r = self:GetPanelRect()
        c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, r.left, r.top)
        return
    end
    local native = SBR.Hook and SBR.Hook:GetAnchorControl()
    local mode = SBR.sv.attach or "over"
    if self.dim then self.dim:SetHidden(true) end
    if mode == "over" then
        -- centred, a little left so the details pane fits on the right; a dim layer
        -- behind the panel keeps the native board from showing through
        local r = self:GetPanelRect()
        c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, r.left, r.top)
        if self.dim and native then self.dim:SetHidden(false) end
        return
    end
    if native and mode ~= "free" then
        if mode == "left" then
            c:SetAnchor(TOPRIGHT, native, TOPLEFT, -8, 0)
        elseif mode == "below" then
            c:SetAnchor(TOP, native, BOTTOM, 0, 8)
        else
            c:SetAnchor(TOPLEFT, native, TOPRIGHT, 8, 0)
        end
    else
        c:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
end

-- Where the panel is, worked out from its size rather than read back from the control
-- (GetLeft / GetRight lag a frame behind a resize). Centred "over" placement sits a
-- little left so the details pane fits beside it, a little high, and inside the screen.
function UI:GetPanelRect()
    local screenW, screenH = self:GetScreenSize()
    local w = self.panelW or (self.control and self.control:GetWidth()) or 900
    local h = self.panelH or (self.control and self.control:GetHeight()) or 400
    local pos = self.mode ~= "gamepad" and SBR.sv.position or nil
    local bottomReserve = self:GetBottomReserve()
    local usableH = screenH - bottomReserve
    local left, top
    if pos and pos.left then
        left, top = pos.left, pos.top
    else
        local shift = self.paneBeside and math.floor((self.style.detailsW + 8) / 2) or 0
        left = math.floor((screenW - w) / 2) - shift
        top = math.floor((usableH - h) / 2) - (self.mode == "gamepad" and 0 or 30)
    end
    left = zo_clamp(left, 0, math.max(0, screenW - w))
    top = zo_clamp(top, 0, math.max(0, usableH - h))
    return { left = left, top = top, right = left + w, bottom = top + h }
end

function UI:ResetPosition()
    SBR.sv.position = nil
    self:ApplyPosition()
end

function UI:GetHeader(i)
    local h = self.headers[i]
    if h then return h end
    h = CreateLabel(self.headerRow, self.style.fontHead)
    h:SetHeight(self.style.headerH)
    Uppercase(h)
    h.sortIcon = CreateTexture(self.headerRow, 1, 1, 1, 1)
    h.sortIcon:SetDimensions(16, 16)
    h.sortIcon:SetHidden(true)
    h:SetMouseEnabled(true)
    h:SetHandler("OnMouseUp", function(control, button, upInside)
        if upInside and control.column then self:SortBy(control.column.key) end
    end)
    h:SetHandler("OnMouseEnter", function(control)
        if self.mode == "keyboard" and control.column and control.column.tip then ShowTooltip(control, control.column.tip) end
    end)
    h:SetHandler("OnMouseExit", HideTooltip)
    self.headers[i] = h
    return h
end

function UI:StyleRow(row, i)
    local s = self.style
    row:SetHeight(s.rowH)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, self.list, TOPLEFT, 0, (i - 1) * s.rowH)
    row.strip:SetDimensions(STRIP_W, s.rowH - 2)
    for _, cell in ipairs(row.cells) do
        cell:SetFont(s.fontRow)
        cell:SetHeight(s.rowH)
    end
end

-- Mouse wheel over the table when it has more players than fit on screen.
function UI:Scroll(rows)
    local n = self.sortedPlayers and #self.sortedPlayers or 0
    local maxOffset = math.max(0, n - (self.maxVisibleRows or n))
    local offset = zo_clamp((self.scrollOffset or 0) + rows, 0, maxOffset)
    if offset ~= (self.scrollOffset or 0) then
        self.scrollOffset = offset
        self:Refresh()
    end
end

function UI:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    row = WM:CreateControl(NextName("Row"), self.list, CT_CONTROL)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseWheel", function(_, delta) self:Scroll(delta > 0 and -3 or 3) end)
    row.bg = CreateTexture(row, 1, 1, 1, 0)
    row.bg:SetAnchorFill(row)
    row.highlight = CreateTexture(row, 1, 1, 1, 1)
    row.highlight:SetAnchorFill(row)
    row.highlight:SetHidden(true)
    row.strip = CreateTexture(row, 1, 1, 1, 1)
    row.strip:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 1)
    row.cells = {}
    row:SetHandler("OnMouseEnter", function(control)
        if self.mode == "keyboard" then
            control.hovered = true
            self:PaintRowBackground(control)
        end
    end)
    row:SetHandler("OnMouseExit", function(control)
        control.hovered = false
        self:PaintRowBackground(control)
    end)
    row:SetHandler("OnMouseUp", function(control, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and control.player then
            self:OnRowClicked(control.player)
        end
    end)
    self.rows[i] = row
    self:StyleRow(row, i)
    return row
end

-- ESO list look: faint alternating rows, the stock hover glow, the stock
-- selected bar (gold) and a cool tint on your own row. Text brightens on the
-- row in focus; in gamepad mode the other rows dim, like ESO's gamepad lists.
function UI:PaintRowBackground(row)
    local C = Colors()
    local gamepad = self.mode == "gamepad"
    local selected = row.player and self.selectedKey == PlayerKey(row.player) and (gamepad or self.detailsOpen)
    local isLocal = row.player and row.player.isLocal
    if selected then
        row.bg:SetColor(1, 0.82, 0.42, gamepad and 0.22 or 0.16)
    elseif isLocal then
        row.bg:SetColor(0.31, 0.62, 0.85, 0.16)
    elseif row.index and row.index % 2 == 0 then
        row.bg:SetColor(1, 1, 1, 0.035)
    else
        row.bg:SetColor(1, 1, 1, 0)
    end
    if selected then
        row.highlight:SetTexture(TEX.rowSelected)
        row.highlight:SetColor(1, 0.86, 0.5, 0.9)
        row.highlight:SetHidden(false)
    elseif row.hovered and not gamepad then
        row.highlight:SetTexture(TEX.rowHighlight)
        row.highlight:SetColor(1, 1, 1, 0.8)
        row.highlight:SetHidden(false)
    else
        row.highlight:SetHidden(true)
    end
    local text = (selected or isLocal or row.hovered) and C.selected or (gamepad and C.gpUnselected or C.normal)
    for _, cell in ipairs(row.cells or {}) do
        if cell.isEmpty then Paint(cell, C.disabled) else Paint(cell, text) end
    end
end

---------------------------------------------------------------------------
-- Selection and details
---------------------------------------------------------------------------
function UI:GetSelectedPlayer()
    local list = self.sortedPlayers or {}
    for i, p in ipairs(list) do
        if PlayerKey(p) == self.selectedKey then return p, i end
    end
    return nil
end

function UI:Select(p)
    local key = p and PlayerKey(p) or nil
    if key ~= self.selectedKey then self.detailsOffset = 0 end
    self.selectedKey = key
    for _, row in ipairs(self.rows) do
        if not row:IsHidden() then self:PaintRowBackground(row) end
    end
    if self.detailsOpen then self:RefreshDetails() end
end

function UI:MoveSelection(delta)
    local list = self.sortedPlayers or {}
    if #list == 0 then return end
    local _, idx = self:GetSelectedPlayer()
    local old = idx
    idx = idx and zo_clamp(idx + delta, 1, #list) or 1
    if idx == old then return end -- at the top / bottom: nothing to do, no sound
    self:Select(list[idx])
    -- scrolled past the visible rows: refresh so the selection stays in view
    local offset, rows = self.scrollOffset or 0, self.maxVisibleRows or #list
    if idx <= offset or idx > offset + rows then self:Refresh() end
    if SOUNDS and SOUNDS.GAMEPAD_MENU_DOWN then PlaySound(SOUNDS.GAMEPAD_MENU_DOWN) end
end

-- PC: click a row to open its details, click it again (or X) to close.
function UI:OnRowClicked(p)
    if self.detailsOpen and self.selectedKey == PlayerKey(p) then
        self:CloseDetails()
    else
        self:Select(p)
        self:OpenDetails()
    end
end

-- Gamepad: A / Cross toggles details for the selected row.
function UI:ToggleDetails()
    if self.detailsOpen then
        self:CloseDetails()
    else
        if not self:GetSelectedPlayer() then self:MoveSelection(0) end
        self:OpenDetails()
    end
end

-- Scroll the details pane by a number of lines (right stick / mouse wheel).
function UI:ScrollDetails(delta)
    if not self.detailsOpen or not self.detailsLineCount or self.detailsLineCount <= (self.detailsFit or 0) then return end
    local maxOffset = self.detailsLineCount - ((self.detailsFit or 1) - 1)
    local offset = zo_clamp((self.detailsOffset or 0) + delta, 0, math.max(0, maxOffset))
    if offset ~= (self.detailsOffset or 0) then
        self.detailsOffset = offset
        self:RefreshDetails()
    end
end

function UI:OpenDetails()
    if not self:GetSelectedPlayer() then return end
    self.detailsOpen = true
    self.detailsBodyText = nil
    self.details:SetHidden(false)
    self:RefreshDetails()
    for _, row in ipairs(self.rows) do self:PaintRowBackground(row) end
end

function UI:CloseDetails()
    self.detailsOpen = false
    if self.details then self.details:SetHidden(true) end
    for _, row in ipairs(self.rows) do self:PaintRowBackground(row) end
    if SBR.Gamepad then SBR.Gamepad:UpdateKeybinds() end
end

function UI:RefreshDetails()
    if not self.detailsOpen then return end
    local p = self:GetSelectedPlayer()
    if not p then
        self:CloseDetails()
        return
    end
    local s = self.style
    local title = p.characterName ~= "" and p.characterName or p.displayName or "?"
    if p.isLocal then title = title .. "  |c" .. Colors().normalHex .. "(you)|r" end
    local body = self:PlayerDetailsText(p)
    local offset = self.detailsOffset or 0
    if title == self.detailsTitleText and body == self.detailsBodyText and self.detailsPlacedFor == self.panelW
        and offset == self.detailsShownOffset then
        return -- same player, same numbers, same panel size: nothing to redraw
    end
    self.detailsTitleText, self.detailsBodyText, self.detailsPlacedFor = title, body, self.panelW
    self.detailsTitle:SetText(title)

    -- beside the panel on whichever side has room; if neither does, over the right
    -- of the panel (the canvas is too small for both side by side)
    local pane, tlw = self.details, self.control
    local screenW, screenH = self:GetScreenSize()
    pane:ClearAnchors()
    local rect = self:GetPanelRect()
    local need = s.detailsW + 8
    local top
    if rect.right + need <= screenW then
        pane:SetAnchor(TOPLEFT, tlw, TOPRIGHT, 8, 0)
        top = rect.top
    elseif rect.left - need >= 0 then
        pane:SetAnchor(TOPRIGHT, tlw, TOPLEFT, -8, 0)
        top = rect.top
    else
        pane:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -s.pad, s.topH)
        top = rect.top + s.topH
    end
    self.detailsFill:SetHidden(top == rect.top)

    -- never taller than the room below its top edge (above the gamepad keybind strip);
    -- what doesn't fit scrolls: right stick on a controller, mouse wheel on PC
    local chromeH = s.rowH + s.pad * 2 + 10
    local room = screenH - self:GetBottomReserve() - top - SCREEN_MARGIN
    local maxBodyH = math.max(60, math.min(s.detailsMaxH, room) - chromeH)
    local lines = {}
    for line in (body .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    local lineH = (self.detailsBody.GetFontHeight and self.detailsBody:GetFontHeight()) or s.rowH
    local fit = math.max(3, math.floor(maxBodyH / lineH))
    local shown
    if #lines <= fit then
        offset, shown = 0, body
    else
        local window = fit - 1 -- one line for the "more" hint
        offset = zo_clamp(offset, 0, #lines - window)
        local part = {}
        for i = offset + 1, math.min(#lines, offset + window) do part[#part + 1] = lines[i] end
        local hint = self.mode == "gamepad" and "right stick" or "mouse wheel"
        local above, below = offset, #lines - offset - window
        part[#part + 1] = string.format("|c%s%s%s  (%s)|r", Colors().normalHex,
            above > 0 and ("^ " .. above .. " more") or "", below > 0 and ((above > 0 and "   " or "") .. "v " .. below .. " more") or "",
            hint)
        shown = table.concat(part, "\n")
    end
    self.detailsOffset, self.detailsShownOffset, self.detailsLineCount, self.detailsFit = offset, offset, #lines, fit
    self.detailsBody:SetText(shown)
    local h = math.min(self.detailsBody:GetTextHeight(), maxBodyH) + chromeH
    h = math.max(120, h)
    self.details:SetHeight(h)
    self.detailsBody:SetHeight(h - chromeH)
    if SBR.Gamepad then SBR.Gamepad:UpdateKeybinds() end
end

---------------------------------------------------------------------------
-- Data -> UI
---------------------------------------------------------------------------
function UI:GetViewedMatch()
    if self.viewIndex then return SBR.MatchLog:GetHistory()[self.viewIndex] end
    return SBR.MatchLog:GetLive()
end

function UI:SetView(index)
    local history = SBR.MatchLog:GetHistory()
    if index and (index < 1 or index > #history) then index = nil end
    self.viewIndex = index
    self:Refresh()
end

function UI:Step(delta)
    local history = SBR.MatchLog:GetHistory()
    if #history == 0 then return end
    local idx = self.viewIndex
    if not idx then
        -- Live view of a finished match already shows history[#history].
        idx = SBR.MatchLog:GetCurrent() and (#history + 1) or #history
    end
    idx = zo_clamp(idx + delta, 1, #history)
    self:SetView(idx)
end

function UI:SortBy(key)
    if self.sort.key == key then
        self.sort.desc = not self.sort.desc
    else
        self.sort.key, self.sort.desc = key, key ~= "name" and key ~= "class"
    end
    self:Refresh()
end

function UI:ToggleSortOrder()
    self.sort.desc = not self.sort.desc
    self:Refresh()
end

-- Gamepad left/right: move the sort to the previous/next column.
function UI:CycleSort(delta)
    local cols = self.columns
    if #cols == 0 then return end
    local idx = 1
    for i, c in ipairs(cols) do
        if c.key == self.sort.key then idx = i break end
    end
    idx = ((idx - 1 + delta) % #cols) + 1
    if cols[idx].key == "class" then idx = ((idx - 1 + delta) % #cols) + 1 end
    self.sort.key = cols[idx].key
    self.sort.desc = cols[idx].numeric == true
    self:Refresh()
end

function UI:ToggleGroupByTeam()
    SBR.sv.groupByTeam = not SBR.sv.groupByTeam
    self:Refresh()
end

function UI:SortedPlayers(match)
    local list = {}
    for _, p in pairs(match.players or {}) do list[#list + 1] = p end
    local col
    for _, c in ipairs(self.columns) do
        if c.key == self.sort.key then col = c break end
    end
    if not col then
        for _, c in ipairs(self.columns) do
            if c.numeric then col = c break end
        end
    end
    local desc = self.sort.desc
    local group = SBR.sv.groupByTeam
    local localTeam = match.localTeam
    table.sort(list, function(a, b)
        if group and a.team ~= b.team then
            -- your team first, then by team id
            if a.team == localTeam then return true end
            if b.team == localTeam then return false end
            return (a.team or 99) < (b.team or 99)
        end
        if col then
            local va, vb = col.sortValue(a), col.sortValue(b)
            if va ~= vb then
                if va == nil then return false end
                if vb == nil then return true end
                if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
                if desc then return va > vb else return va < vb end
            end
        end
        return (a.characterName or "") < (b.characterName or "")
    end)
    return list
end

local function Section(title)
    return "|c" .. Colors().normalHex .. string.upper(title) .. "|r"
end

function UI:PlayerDetailsText(p)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local gamepad = self.mode == "gamepad"
    local iconSize = gamepad and 24 or 18
    add(string.format("%s%s", p.displayName or "", p.className and ("  |c999999" .. p.className .. "|r") or ""))
    if p.scores then
        local parts = {}
        for _, key in ipairs({ "SCORE", "KILL", "DEATH", "ASSISTS" }) do
            if p.scores[key] then parts[#parts + 1] = string.format("%s %s", SBR.Prettify(key), tostring(p.scores[key])) end
        end
        if #parts > 0 then add(table.concat(parts, "   ")) end
        -- score columns that didn't fit in the table on this screen
        local more = {}
        for _, st in ipairs(SBR.Battleground.scoreTypes or {}) do
            local v = p.scores[st.key]
            if v and v ~= 0 and self.droppedColumns and self.droppedColumns["s:" .. st.key] then
                more[#more + 1] = string.format("%s %s", st.label, SBR.FormatNumber(v))
            end
        end
        for i = 1, #more, 3 do add(table.concat(more, "   ", i, math.min(i + 2, #more))) end
    end
    if p.medals and #p.medals > 0 then
        add(" ")
        add(Section("Medals"))
        for _, m in ipairs(p.medals) do
            local icon = (m.icon and m.icon ~= "") and zo_iconFormat(m.icon, iconSize, iconSize) or ""
            add(string.format("  %s %s x%d", icon, m.name or "?", m.count or 1))
        end
    end
    if p.fight then
        local f = p.fight
        add(" ")
        add(Section("Fight data") .. (f.source and (" |c" .. Colors().normalHex .. "(" .. f.source .. ")|r") or ""))
        -- core stats always show; the rest only when non-zero, to keep the pane short on a TV
        local function stat(label, v, fmt, keepZero)
            if v ~= nil and (keepZero or v ~= 0) then
                add(string.format("  |c%s%s:|r %s", Colors().normalHex, label, fmt and fmt(v) or SBR.FormatNumber(v)))
            end
        end
        local pct = function(v) return string.format("%.1f%%", v) end
        stat("Damage", f.damageDone, nil, true)
        stat("Healing", f.healingDone, nil, true)
        stat("DPS / HPS", f.dps, function(v) return SBR.FormatNumber(v) .. " / " .. SBR.FormatNumber(f.hps) end, true)
        stat("Damage taken", f.damageTaken, nil, true)
        stat("Healing taken", f.healingTaken, nil, true)
        stat("Shielded", f.damageShielded)
        stat("Blocked", f.damageBlocked)
        stat("Killing blows", f.killingBlows)
        stat("Deaths", f.deaths)
        stat("Interrupts", f.interrupts)
        stat("Interrupted", f.interrupted)
        stat("CC applied", f.ccApplied)
        stat("CC taken", f.ccTaken)
        stat("Crit rate", f.critRate, pct)
        stat("Heal crit rate", f.healCritRate, pct)
        if f.maxHit then add(string.format("  Max hit: %s%s", SBR.FormatNumber(f.maxHit), f.maxHitAbility and (" (" .. f.maxHitAbility .. ")") or "")) end
        stat("Mitigated", f.mitigated)
        stat("Overheal", f.overheal)
        stat("Enemy shields soaked", f.enemyShieldAbsorbed)
        if f.lightAttacks or f.heavyAttacks or f.skillCasts then
            add(string.format("  LA/HA/skills/ults: %s/%s/%s/%s, weaves %s", tostring(f.lightAttacks or 0), tostring(f.heavyAttacks or 0),
                tostring(f.skillCasts or 0), tostring(f.ultimates or 0), tostring(f.weaves or 0)))
        end
        stat("Fights", f.fights)
        stat("Combat time", f.activeTime, SBR.FormatDuration)
        local function abilityList(title, list)
            if type(list) == "table" and #list > 0 then
                add("  " .. title .. ":")
                for _, a in ipairs(list) do
                    local icon = (a.icon and a.icon ~= "") and zo_iconFormat(a.icon, iconSize - 2, iconSize - 2) or ""
                    add(string.format("    %s %s  %s", icon, a.name or "?", SBR.FormatNumber(a.damage)))
                end
            end
        end
        abilityList("Top damage", f.topAbilities)
        abilityList("Top heals", f.topHeals)
        if f.source and f.source:find("vs your team", 1, true) then
            add("  |c999999Enemy: only what they did to and took from your team.|r")
        end
    end
    if p.vs then
        local v = p.vs
        add(" ")
        add(Section("You vs them"))
        add(string.format("  You dealt %s, took %s", SBR.FormatNumber(v.damageFromYou), SBR.FormatNumber(v.damageToYou)))
        if (v.killedByYou or 0) > 0 or (v.killedYou or 0) > 0 then
            add(string.format("  You killed them %d, they killed you %d", v.killedByYou or 0, v.killedYou or 0))
        end
        if (v.healedByYou or 0) > 0 then add("  You healed them " .. SBR.FormatNumber(v.healedByYou)) end
        if (v.healedYou or 0) > 0 then add("  They healed you " .. SBR.FormatNumber(v.healedYou)) end
    end
    if p.isLocal then
        local match = self:GetViewedMatch()
        local deaths = match and match.lf and match.lf.deaths
        if deaths and #deaths > 0 then
            add(" ")
            add(string.format("Deaths with recap: %d (see the kill feed)", #deaths))
        end
    end
    return table.concat(lines, "\n")
end

function UI:RefreshHeader(match)
    if not match then
        self.title:SetText(SBR.displayName)
        self.subtitle:SetText("")
        self.teamLabel:SetText("")
        self.sourceLabel:SetText("")
        return
    end
    self.title:SetText(match.name or match.zoneName or "Battleground")
    local parts = {}
    if match.gameTypeName then parts[#parts + 1] = match.gameTypeName end
    if match.teamSize then parts[#parts + 1] = string.format("%dv%d", match.teamSize, match.teamSize) end
    if match.endedAt then
        local res = ({ won = "|c66FF66Victory|r", lost = "|cFF6666Defeat|r", tie = "Tie", left = "|cAAAAAALeft early|r" })[match.result]
        parts[#parts + 1] = res or "Ended"
        parts[#parts + 1] = SBR.FormatDuration(match.duration)
        parts[#parts + 1] = SBR.FormatTimestamp(match.startedAt)
    else
        parts[#parts + 1] = match.stateName or "In progress"
        if match.runningSince then parts[#parts + 1] = SBR.FormatDuration(SBR.Now() - match.runningSince) end
        if match.numRounds and match.numRounds > 1 and match.roundIndex then
            parts[#parts + 1] = string.format("Round %d/%d", match.roundIndex, match.numRounds)
        end
    end
    self.subtitle:SetText(table.concat(parts, "  |c666666•|r  "))

    local teamTexts = {}
    local ids = {}
    for id, t in pairs(match.teams or {}) do
        local hasPlayers = false
        for _, p in pairs(match.players or {}) do
            if p.team == id then hasPlayers = true break end
        end
        if hasPlayers or t.score then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local t = match.teams[id]
        local marker = id == match.localTeam and "*" or ""
        teamTexts[#teamTexts + 1] = SBR.Colorize(t.color, string.format("%s%s %s", marker, t.name or id, t.score ~= nil and tostring(t.score) or "-"))
    end
    self.teamLabel:SetText(table.concat(teamTexts, "   "))

    local src
    local ledgerOn = match.ledger ~= nil or (match.endedAt and SBR.sv.trackCombat)
    if match.lf then
        local n = match.lf.fightList and #match.lf.fightList or 0
        if match.lf.fights then for _ in pairs(match.lf.fights) do n = n + 1 end end
        src = string.format("LibFights (you, %d fight%s)", n, n == 1 and "" or "s")
        if ledgerOn then src = src .. " + combat log (everyone)" end
    elseif ledgerOn then
        src = "combat log (everyone)"
    end
    if not match.endedAt then src = SBR.LibFights:StatusText() .. (src and ("  |  " .. src) or "") end
    self.sourceLabel:SetText("Fight data: " .. (src or "none"))
end

-- Header row for this set of columns (only when the columns or the sort change).
function UI:LayoutHeaders(cols)
    local C = Colors()
    for i, c in ipairs(cols) do
        local h = self:GetHeader(i)
        h.column = c
        h:SetHidden(false)
        h:ClearAnchors()
        h:SetAnchor(TOPLEFT, self.headerRow, TOPLEFT, c.x, 0)
        h:SetWidth(c.width)
        h:SetHorizontalAlignment(c.align)
        h:SetText(c.label)
        local sorted = self.sort.key == c.key
        if sorted then Paint(h, C.selected)
        elseif c.fight then Paint(h, C.fight)
        elseif c.vs then Paint(h, C.vs)
        else Paint(h, C.normal) end
        h.sortIcon:SetHidden(not sorted)
        if sorted then
            h.sortIcon:SetTexture(self.sort.desc and TEX.sortDown or TEX.sortUp)
            h.sortIcon:ClearAnchors()
            if c.align == TEXT_ALIGN_RIGHT then
                h.sortIcon:SetAnchor(RIGHT, h, LEFT, -1 + c.width - h:GetTextWidth() - 2, 0)
            else
                h.sortIcon:SetAnchor(LEFT, h, LEFT, h:GetTextWidth() + 2, 0)
            end
        end
    end
    for i = #cols + 1, #self.headers do self.headers[i]:SetHidden(true) end
end

-- One visible row. Controls are only touched when something about them changed,
-- so a refresh with new numbers costs a few SetText calls, not a rebuild.
function UI:FillRow(row, p, match, cols, contentWidth, slot, layoutChanged)
    local s = self.style
    if row:IsHidden() then row:SetHidden(false) end
    if row.slot ~= slot or row.width ~= contentWidth then
        row.slot, row.width = slot, contentWidth
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, self.list, TOPLEFT, 0, slot * s.rowH)
        row:SetWidth(contentWidth)
    end
    local team = match.teams and match.teams[p.team]
    local color = team and team.color or "FFFFFF"
    if row.stripColor ~= color then
        row.stripColor = color
        row.strip:SetColor(SBR.HexToRGB(color))
    end
    for ci, c in ipairs(cols) do
        local cell = row.cells[ci]
        if not cell then
            cell = CreateLabel(row, s.fontRow)
            cell:SetHeight(s.rowH)
            row.cells[ci] = cell
        end
        if cell:IsHidden() then cell:SetHidden(false) end
        if layoutChanged or cell.colKey ~= c.key or cell.colX ~= c.x then
            cell.colKey, cell.colX = c.key, c.x
            cell:ClearAnchors()
            cell:SetAnchor(TOPLEFT, row, TOPLEFT, c.x, 0)
            cell:SetWidth(c.width)
            cell:SetHorizontalAlignment(c.align)
        end
        local text = c.text(p)
        if cell.text ~= text then
            cell.text = text
            cell.isEmpty = text == "-"
            cell:SetText(text)
        end
    end
    for ci = #cols + 1, #row.cells do
        local cell = row.cells[ci]
        if not cell:IsHidden() then cell:SetHidden(true) end
    end
    self:PaintRowBackground(row)
end

-- Data updates arrive in bursts (scoreboard updates, kills, medals). They are
-- folded into one refresh on the next frame instead of one refresh each.
function UI:RequestRefresh()
    if self.refreshPending then return end
    self.refreshPending = true
    local ns = SBR.name .. "_WindowRefresh"
    EVENT_MANAGER:RegisterForUpdate(ns, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(ns)
        self.refreshPending = false
        self:Refresh()
    end)
end

function UI:Refresh()
    if not self.control or self.control:IsHidden() then return end
    local s = self.style
    local match = self:GetViewedMatch()
    self:RefreshHeader(match)

    local cols = match and self:BuildColumns(match) or {}
    local x = STRIP_W + 4
    for _, c in ipairs(cols) do
        c.x = x
        x = x + c.width + 6
    end
    local contentWidth = math.max(x, self.mode == "gamepad" and 900 or 640)

    -- Headers are only laid out again when the columns or the sort change.
    local sig = {}
    for _, c in ipairs(cols) do sig[#sig + 1] = c.key .. ":" .. c.width end
    sig = table.concat(sig, ",") .. "|" .. tostring(self.sort.key) .. tostring(self.sort.desc) .. "|" .. self.mode
    local layoutChanged = sig ~= self.columnSig
    self.columnSig = sig
    if layoutChanged then self:LayoutHeaders(cols) end

    local players = match and self:SortedPlayers(match) or {}
    self.sortedPlayers = players
    local selectedIndex
    if self.mode == "gamepad" then
        local _, idx = self:GetSelectedPlayer()
        if not idx and players[1] then
            -- keep a cursor on screen; start on your own row
            local start, startIdx = players[1], 1
            for i, p in ipairs(players) do
                if p.isLocal then start, startIdx = p, i break end
            end
            self.selectedKey = PlayerKey(start)
            idx = startIdx
        end
        selectedIndex = idx
    end

    -- as many rows as fit on screen; the rest scroll (mouse wheel, or the selection)
    local _, screenH = self:GetScreenSize()
    local chrome = s.topH + s.headerH + 2 + s.footerH + s.pad + SCREEN_MARGIN * 2 + self:GetBottomReserve()
    local maxRows = math.max(4, math.floor((screenH - chrome) / s.rowH))
    self.maxVisibleRows = maxRows
    local offset = self.scrollOffset or 0
    if selectedIndex then
        -- the selected row always stays in view
        if selectedIndex - 1 < offset then offset = selectedIndex - 1 end
        if selectedIndex > offset + maxRows then offset = selectedIndex - maxRows end
    end
    self.scrollOffset = zo_clamp(offset, 0, math.max(0, #players - maxRows))

    for i, p in ipairs(players) do
        local row = self:GetRow(i)
        local slot = i - 1 - self.scrollOffset
        local visible = slot >= 0 and slot < maxRows
        row.player, row.index = p, i
        if visible then
            self:FillRow(row, p, match, cols, contentWidth, slot, layoutChanged)
        elseif not row:IsHidden() then
            row:SetHidden(true)
        end
    end
    for i = #players + 1, #self.rows do
        self.rows[i]:SetHidden(true)
        self.rows[i].player = nil
    end

    self.emptyLabel:SetHidden(#players > 0)
    self.emptyLabel:SetWidth(contentWidth)

    local listH = math.max(math.min(#players, maxRows), 2) * s.rowH
    self.headerRow:SetWidth(contentWidth)
    self.list:SetDimensions(contentWidth, listH)
    self.panelW, self.panelH = contentWidth + s.pad * 2, s.topH + s.headerH + 2 + listH + s.footerH + s.pad
    self.control:SetDimensions(self.panelW, self.panelH)
    -- the centred position depends on whether the details pane fits beside the panel
    if not (SBR.sv.position and SBR.sv.position.left) then self:ApplyPosition() end

    -- footer state
    local history = SBR.MatchLog:GetHistory()
    if self.viewIndex then
        self.viewLabel:SetText(string.format("History %d / %d", self.viewIndex, #history))
    else
        self.viewLabel:SetText(SBR.MatchLog:GetCurrent() and "|c66FF66Live|r" or (#history > 0 and "Last match" or ""))
    end
    self.groupButton:SetText(SBR.sv.groupByTeam and "By team: on" or "By team: off")

    self:RefreshDetails()
    if SBR.Gamepad then SBR.Gamepad:UpdateKeybinds() end
end

function UI:OnDataChanged()
    if SBR.Console and SBR.Console.scoreboard then SBR.Console.scoreboard:OnDataChanged() end
    if self.viewIndex == nil and self:IsShown() then self:RequestRefresh() end
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------
function UI:Show(pinned)
    self:Create()
    if SBR.IsGamepad() then
        SBR.Gamepad:Open()
        return
    end
    if self.mode ~= "keyboard" then self:ApplyStyle("keyboard") end
    if pinned then self.pinned = true end
    self:ApplyPosition()
    self.control:SetHidden(false)
    if SBR.MatchLog:GetCurrent() then SBR.MatchLog:Snapshot() end
    self:Refresh()
end

-- Gamepad scene shown/hidden (UI/Gamepad.lua drives these).
function UI:OnGamepadShown()
    self:ApplyStyle("gamepad")
    if SBR.MatchLog:GetCurrent() then SBR.MatchLog:Snapshot() end
    self:Refresh()
end

-- covered: another screen was opened on top (kill feed, records); keep the
-- selection and details for when B returns to the table
function UI:OnGamepadHidden(covered)
    if covered then return end
    self:CloseDetails()
    self:ApplyStyle("keyboard")
end

function UI:Hide(force)
    if not self.control then return end
    if self.mode == "gamepad" then
        SBR.Gamepad:Close()
        return
    end
    if self.pinned and not force then return end
    self.pinned = false
    self:CloseDetails()
    self.control:SetHidden(true)
    if self.dim then self.dim:SetHidden(true) end
    HideTooltip()
end

function UI:Toggle()
    if self:IsShown() then
        self:Hide(true)
    else
        self:Show(true)
        -- keyboard: needs the cursor when opened outside the native scoreboard
        if self.mode == "keyboard" and not SCENE_MANAGER:IsInUIMode() then SCENE_MANAGER:SetInUIMode(true) end
    end
end

function UI:IsShown()
    return self.control ~= nil and not self.control:IsHidden()
end

-- Called by the hook when the native keyboard scoreboard opens / closes.
function UI:OnNativeShown()
    if not SBR.sv.autoShowWithScoreboard then return end
    self:Show(false)
end

function UI:OnNativeHidden()
    if self.mode ~= "keyboard" then return end
    self:Hide(false)
    self:ApplyPosition()
end
