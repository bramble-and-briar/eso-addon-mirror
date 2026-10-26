PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- The statistics window
--
-- Four blocks in a window of their own, over a period (today, this month, all, one day, one month):
--
--   the summary: amount, HPS, fights, best, crit, overheal, and who it went to (party / others / self)
--   the players healed, most first            the skills healed with, most first
--   the latest fights, with their HPS
--
-- It takes no input -- on console a control that wants input takes every gamepad button from the
-- game while it is up -- so it is opened and closed from the settings panel or /hps stats. The
-- layout is PB's KillLog's ranking window, which is measured on PS5: a colour texture, gamepad
-- fonts the console UI already has, one label per row.
--
-- Where it shows: on the HUD, through a fragment on HUD_SCENE and HUD_UI_SCENE (attached only while
-- it is wanted); and over the settings panel while the panel is open, which is not a HUD scene, so
-- the panel tells it (see Settings.lua).
---------------------------------------------------------------------------------------------------

local window = {
    -- The period shown: "today", "thismonth", "all", a day number or "m<year><month>".
    scope = "today",
}
ADDON.window = window

local records = ADDON.records

local NAME = "PBsHpsCheckerWindow"
local ROWS = ADDON.RANKING_ROWS or 10
local COLUMN_WIDTH = 560
local PADDING = 20
local HEADER_GAP = 12
local BLOCK_GAP = 24
local CHECK_INTERVAL_MS = 250
local REFRESH_INTERVAL_MS = 2000
local LINE_PADDING = 4
local SCREEN_MARGIN = 20
local MARGIN_RIGHT = 40
local WINDOW_WIDTH = PADDING * 3 + COLUMN_WIDTH * 2

-- Named fonts the console UI already has loaded, so no face is built; the biggest tier whose layout
-- fits the screen is used. The client draws them smaller on a Japanese client than the number says,
-- which is why the layout is worked out from the height the client reports for each font.
--
-- The rows here are long ("To party  62.3%  765,432  14 players") and a row is cut short from the
-- right when it does not fit its column, so a tier is only used if the client says the longest
-- rows there can be (Records:WorstCaseLines) fit the column in it, as well as the height. KillLog's
-- ranking can go by height alone because its rows are a name and a number.
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

local function L(id)
    return GetString(id)
end

-- In the order the blocks are laid out: left to right, top to bottom.
window.BLOCKS = {
    { titleId = SI_PBSHPS_BLOCK_SUMMARY, column = 0, row = 0,
      lines = function(scope) return records:SummaryLines(scope) end },
    { titleId = SI_PBSHPS_BLOCK_TARGETS, column = 1, row = 0,
      lines = function(scope) return records:TopLines("targets", scope, ROWS) end },
    { titleId = SI_PBSHPS_BLOCK_SKILLS, column = 0, row = 1,
      lines = function(scope) return records:TopLines("skills", scope, ROWS) end },
    { titleId = SI_PBSHPS_BLOCK_FIGHTS, column = 1, row = 1,
      lines = function() return records:FightLines(ROWS) end },
}

local function Label(parent, suffix, font)
    local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
    label:SetFont(font)
    return label
end

-- Whether every row there can be, and every heading, fits its column in a font tier. A client that
-- does not say how wide a text is gives no answer, which counts as fitting: height decides then.
function window:FitsWidth(tier)
    for _, line in ipairs(records:WorstCaseLines()) do
        local width = ADDON.MeasureText(tier.row, line)
        if width and width > COLUMN_WIDTH then
            return false
        end
    end
    for _, block in ipairs(self.BLOCKS) do
        local width = ADDON.MeasureText(tier.heading, L(block.titleId))
        if width and width > COLUMN_WIDTH then
            return false
        end
    end
    return true
end

-- The biggest font tier whose layout is no taller than maxHeight and whose rows fit their column.
-- When even the smallest does not fit (a very small screen), the smallest is what is used.
function window:ChooseLayout(maxHeight)
    local titleHeight = ADDON.MeasureFont(TITLE_FONT) + LINE_PADDING
    local headerHeight = PADDING + titleHeight + HEADER_GAP
    local layout
    for _, tier in ipairs(FONT_TIERS) do
        local rowHeight = ADDON.MeasureFont(tier.row) + LINE_PADDING
        local headingHeight = ADDON.MeasureFont(tier.heading) + LINE_PADDING
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
        if layout.height <= maxHeight and self:FitsWidth(tier) then
            break
        end
    end
    return layout
end

function window:Create()
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

    for index, block in ipairs(self.BLOCKS) do
        local x = PADDING + block.column * (COLUMN_WIDTH + PADDING)
        local y = layout.headerHeight + block.row * (layout.blockHeight + BLOCK_GAP)

        local heading = Label(top, "Heading" .. index, layout.headingFont)
        heading:SetColor(PINK[1], PINK[2], PINK[3], 1)
        heading:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        heading:SetMaxLineCount(1)
        heading:SetDimensions(COLUMN_WIDTH, layout.headingHeight)
        heading:SetAnchor(TOPLEFT, top, TOPLEFT, x, y)
        heading:SetText(L(block.titleId))

        -- One label per row, so a long name ends in "..." instead of wrapping into the next row.
        block.rows = {}
        for row = 1, ROWS do
            local label = Label(top, "Block" .. index .. "Row" .. row, layout.rowFont)
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            label:SetMaxLineCount(1)
            label:SetDimensions(COLUMN_WIDTH, layout.rowHeight)
            label:SetAnchor(TOPLEFT, top, TOPLEFT, x, y + layout.headingHeight + (row - 1) * layout.rowHeight)
            block.rows[row] = label
        end
    end

    self.fragment = ZO_SimpleSceneFragment:New(top)

    -- While it is drawn over the settings panel (a scene no fragment of ours belongs to), it goes away
    -- by itself when that scene is left, whichever way the player leaves it. While it is up, the
    -- numbers are refreshed every couple of seconds, so a fight can be watched.
    local nextCheck, nextRefresh = 0, 0
    top:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if now >= nextRefresh then
            nextRefresh = now + REFRESH_INTERVAL_MS
            self:Refresh()
        end
        if not self.overPanel or now < nextCheck then
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

function window:IsShown()
    return self.control ~= nil and not self.control:IsHidden()
end

-- Fills the blocks from the records.
function window:Refresh()
    if not self.control then
        return
    end
    self.title:SetText(string.format(L(SI_PBSHPS_WINDOW_TITLE), records:ScopeText(self.scope)))
    for _, block in ipairs(self.BLOCKS) do
        local lines = block.lines(self.scope)
        for row = 1, ROWS do
            local text = lines[row]
            block.rows[row]:SetText(text or "")
            block.rows[row]:SetHidden(text == nil)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------------------------------

local function FragmentShowing(self)
    return self.fragment ~= nil and self.fragment:IsShowing()
end

function window:ShowOverPanel()
    if not self:Create() then
        return
    end
    self.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene() or nil
    self.overPanel = true
    self:Refresh()
    self.control:SetHidden(false)
end

function window:HideOverPanel()
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
function window:OnPanelOpen(open)
    if open then
        if self.wanted then
            self:ShowOverPanel()
        end
    else
        self:HideOverPanel()
    end
end

-- Asked for (true) or put away (false). Asked for, it shows on the HUD, and over the settings panel
-- if that is where the player is.
function window:SetWanted(wanted)
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

function window:Toggle()
    return self:SetWanted(not self.wanted)
end

-- Which period the blocks are taken over.
function window:SetScope(scope)
    self.scope = scope or "today"
    self:Refresh()
end
