PBsKillLog = PBsKillLog or {}
local ADDON = PBsKillLog
local L = ADDON.L

---------------------------------------------------------------------------------------------------
-- The ranking window
--
-- Four top-ten lists in a window of their own, over a period -- one day, one month, or all time:
--
--   the skills that killed the player      the skills the player killed with
--   the players who killed the player      the players the player killed
--
-- It takes no input -- on console a control that wants input takes every gamepad button from the
-- game while it is up -- so it is opened and closed from the settings panel or /pbkl ranking.
-- Like the preview frame it is built from controls of its own, laid out the way PB's
-- LuaMemoryMonitor lays out its window (a colour texture, gamepad fonts the console UI already
-- has, one label per row).
--
-- Where it shows: on the HUD, through a fragment on HUD_SCENE and HUD_UI_SCENE (attached only
-- while it is wanted, like LuaMemoryMonitor's); and over the settings panel while the panel is
-- open, which is not a HUD scene, so the panel tells it (see Preview.lua).
---------------------------------------------------------------------------------------------------

local ranking = {
    labels = {},
    -- The period shown: "all", "today", "thismonth", a day number or "m<year><month>" (see Records.lua).
    scope = "all",
}
ADDON.ranking = ranking

local NAME = "PBsKillLogRanking"
local ROWS = 10
local COLUMN_WIDTH = 560
local PADDING = 20
local HEADER_GAP = 12
local BLOCK_GAP = 24
local CHECK_INTERVAL_MS = 250

-- Added to the height a font draws a line at, to make a row.
local LINE_PADDING = 4
-- Kept clear above and below the window.
local SCREEN_MARGIN = 20

local WINDOW_WIDTH = PADDING * 3 + COLUMN_WIDTH * 2

-- The right-hand side of the screen: the settings panel is on the left.
local MARGIN_RIGHT = 40

-- The text is as large as will fit. These are named fonts the console UI already has loaded, so no
-- face is built; the biggest tier whose ten rows (and everything else) fit on the screen is used.
-- The client draws them smaller on a Japanese client than the number in the name says (GP_34 is 34
-- on a Western client and 28 on the Japanese one), which is why the layout is worked out from the
-- height the client reports for each font and not from the number.
local TITLE_FONT = "ZoFontGamepadBold34"
local FONT_TIERS = {
    { row = "ZoFontGamepad34", heading = "ZoFontGamepadBold34" },
    { row = "ZoFontGamepad27", heading = "ZoFontGamepadBold27" },
    { row = "ZoFontGamepad25", heading = "ZoFontGamepadBold25" },
    { row = "ZoFontGamepad22", heading = "ZoFontGamepadBold22" },
    { row = "ZoFontGamepad20", heading = "ZoFontGamepadBold20" },
}

-- PB's pink, the same colour as the add-on's name.
local PINK = { 1, 0.41, 0.71 }

-- In the order the lists are laid out: left to right, top to bottom.
ranking.LISTS = {
    { kind = "diedTo", titleKey = "RANKING_DIED_TO_SKILL", column = 0, row = 0 },
    { kind = "killedWith", titleKey = "RANKING_KILLED_WITH_SKILL", column = 1, row = 0 },
    { kind = "diedToPlayers", titleKey = "RANKING_DIED_TO_PLAYER", column = 0, row = 1 },
    { kind = "killedPlayers", titleKey = "RANKING_KILLED_PLAYER", column = 1, row = 1 },
}

local function Label(parent, suffix, font)
    local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
    label:SetFont(font)
    return label
end

-- The height the client draws one line of a font at, which is what a row has to hold.
function ranking:MeasureFont(font)
    local probe = self.probe
    if not probe then
        probe = WINDOW_MANAGER:CreateControl(NAME .. "Probe", GuiRoot, CT_LABEL)
        probe:SetHidden(true)
        self.probe = probe
    end
    probe:SetFont(font)
    local height = type(probe.GetFontHeight) == "function" and probe:GetFontHeight() or 0
    if type(height) ~= "number" or height <= 0 then
        -- No answer: the number in the font's name, which a Western client draws it at, and a
        -- line is a little taller than that.
        height = math.ceil((tonumber(font:match("(%d+)$")) or 20) * 1.3)
    end
    return height
end

-- The biggest font tier whose layout is no taller than maxHeight. When even the smallest does not
-- fit (a very small screen), the smallest is what is used.
function ranking:ChooseLayout(maxHeight)
    local titleHeight = self:MeasureFont(TITLE_FONT) + LINE_PADDING
    local headerHeight = PADDING + titleHeight + HEADER_GAP
    local layout
    for _, tier in ipairs(FONT_TIERS) do
        local rowHeight = self:MeasureFont(tier.row) + LINE_PADDING
        local headingHeight = self:MeasureFont(tier.heading) + LINE_PADDING
        local blockHeight = headingHeight + ROWS * rowHeight
        layout = {
            rowFont = tier.row,
            headingFont = tier.heading,
            titleHeight = titleHeight,
            headerHeight = headerHeight,
            headingHeight = headingHeight,
            rowHeight = rowHeight,
            blockHeight = blockHeight,
            width = WINDOW_WIDTH,
            height = headerHeight + blockHeight * 2 + BLOCK_GAP + PADDING,
        }
        if layout.height <= maxHeight then
            break
        end
    end
    return layout
end

function ranking:Create()
    if self.control then
        return self.control
    end
    if not WINDOW_MANAGER or not GuiRoot then
        return nil
    end

    local layout = self:ChooseLayout(GuiRoot:GetHeight() - SCREEN_MARGIN * 2)
    self.layout = layout

    local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    top:SetHidden(true)
    top:SetMouseEnabled(false)
    top:SetDimensions(layout.width, layout.height)
    top:SetAnchor(RIGHT, GuiRoot, RIGHT, -MARGIN_RIGHT, 0)
    -- Above the settings panel, which it is drawn over.
    top:SetDrawLayer(DL_OVERLAY)
    top:SetDrawTier(DT_HIGH)
    self.control = top

    local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
    fill:SetColor(0, 0, 0, 0.78)
    fill:SetAnchorFill(top)

    local title = Label(top, "Title", TITLE_FONT)
    title:SetColor(PINK[1], PINK[2], PINK[3], 1)
    title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    title:SetMaxLineCount(1)
    title:SetDimensions(layout.width - PADDING * 2, layout.titleHeight)
    title:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, PADDING)
    self.title = title

    for listIndex, list in ipairs(self.LISTS) do
        local x = PADDING + list.column * (COLUMN_WIDTH + PADDING)
        local y = layout.headerHeight + list.row * (layout.blockHeight + BLOCK_GAP)

        local heading = Label(top, "Heading" .. listIndex, layout.headingFont)
        heading:SetColor(PINK[1], PINK[2], PINK[3], 1)
        heading:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        heading:SetMaxLineCount(1)
        heading:SetDimensions(COLUMN_WIDTH, layout.headingHeight)
        heading:SetAnchor(TOPLEFT, top, TOPLEFT, x, y)
        heading:SetText(L(list.titleKey))

        -- One label per row, so a long name ends in "..." instead of wrapping into the next row.
        list.rows = {}
        for row = 1, ROWS do
            local label = Label(top, "List" .. listIndex .. "Row" .. row, layout.rowFont)
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            label:SetMaxLineCount(1)
            label:SetDimensions(COLUMN_WIDTH, layout.rowHeight)
            label:SetAnchor(TOPLEFT, top, TOPLEFT, x, y + layout.headingHeight + (row - 1) * layout.rowHeight)
            list.rows[row] = label
        end
    end

    self.fragment = ZO_SimpleSceneFragment:New(top)

    -- While it is drawn over the settings panel (a scene no fragment of ours belongs to), it goes
    -- away by itself when that scene is left, whichever way the player leaves it.
    local nextCheck = 0
    top:SetHandler("OnUpdate", function()
        if not self.overPanel then
            return
        end
        local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if now < nextCheck then
            return
        end
        nextCheck = now + CHECK_INTERVAL_MS
        local current = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
        if current ~= self.scene then
            self:HideOverPanel()
        end
    end)

    return top
end

function ranking:IsShown()
    return self.control ~= nil and not self.control:IsHidden()
end

-- Fills the lists from the records. Done whether or not the window is up, so it is never stale
-- when it appears.
function ranking:Refresh()
    if not self.control then
        return
    end
    self.title:SetText(string.format(L("RANKING_TITLE"), ADDON.records:ScopeText(self.scope)))
    for _, list in ipairs(self.LISTS) do
        local lines = ADDON.records:RankingLines(list.kind, ROWS, self.scope)
        for row = 1, ROWS do
            local text = lines[row]
            if not text and row == 1 then
                text = L("NONE_ROW")
            end
            list.rows[row]:SetText(text or "")
            list.rows[row]:SetHidden(text == nil)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------------------------------

local function FragmentShowing(self)
    return self.fragment ~= nil and self.fragment:IsShowing()
end

function ranking:ShowOverPanel()
    if not self:Create() then
        return
    end
    self.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
    self.overPanel = true
    self:Refresh()
    self.control:SetHidden(false)
end

function ranking:HideOverPanel()
    if not self.overPanel then
        return
    end
    self.overPanel = false
    if self.control then
        -- Back on the HUD the fragment shows it again; anywhere else it stays away.
        self.control:SetHidden(not FragmentShowing(self))
    end
end

-- The settings panel was opened (true) or closed (false).
function ranking:OnPanelOpen(open)
    if open then
        if self.wanted then
            self:ShowOverPanel()
        end
    else
        self:HideOverPanel()
    end
end

-- Asked for (true) or put away (false). Asked for, it shows on the HUD, and over the settings
-- panel if that is where the player is.
function ranking:SetWanted(wanted)
    self.wanted = wanted and true or false
    if not self:Create() then
        return false
    end
    for _, scene in ipairs({ HUD_SCENE, HUD_UI_SCENE }) do
        if scene then
            if self.wanted then
                scene:AddFragment(self.fragment)
            else
                scene:RemoveFragment(self.fragment)
            end
        end
    end
    if self.wanted then
        self:Refresh()
        if ADDON.panelOpen then
            self:ShowOverPanel()
        end
    else
        self.overPanel = false
        self.control:SetHidden(true)
    end
    return self.wanted
end

function ranking:Toggle()
    return self:SetWanted(not self.wanted)
end

-- Which period the lists are taken over.
function ranking:SetScope(scope)
    self.scope = scope or "all"
    self:Refresh()
end
