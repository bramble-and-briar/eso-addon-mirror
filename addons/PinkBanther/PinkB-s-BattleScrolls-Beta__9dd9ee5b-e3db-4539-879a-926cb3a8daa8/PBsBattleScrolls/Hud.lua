PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The HUD box
--
--     DPS 45,210   boss 18%             the fight's damage per second (active time), and in a boss
--                                        fight the player's share of the damage the bosses took
--     HPS 3,120   1:23                   healing per second and the fight's length
--     Group          DPS    %    HPS    %     members running this add-on (Group.lua), and the
--     1 Alice     52,100  38%   1,200  10%    player, by DPS, with each one's share of the
--     2 You       45,210  33%   3,120  27%    group's DPS and HPS
--
-- Up while a fight goes on and for `hudHoldSec` seconds after it (grey then), or while a member's
-- reading is current. Drawn only while the HUD (or the HUD with the cursor free) is the scene, through
-- "StateChange" callbacks registered beside the client's own; nothing of the client's is hooked. While
-- the settings panel is open it shows sample numbers, so it can be placed. It takes no input. Redrawn
-- at most every UPDATE_MS, and a label is only written when its text changes.
---------------------------------------------------------------------------------------------------

local hud = { visible = false, sceneShown = false, preview = false, nextUpdate = 0, texts = {}, shownRows = -1 }
ADDON.hud = hud

local NAME = "PBsBattleScrollsHud"
local PADDING = 10
local LINE_PADDING = 2
local UPDATE_MS = 250
local MIN_WIDTH = 220
local COL_GAP = 12
local GROUP_GAP = 6
local MAX_GROUP_ROWS = 12
hud.MAX_GROUP_ROWS = MAX_GROUP_ROWS

-- Named gamepad fonts the console UI already has loaded (no face is built on use).
local SIZES = {
    { big = "ZoFontGamepadBold22", row = "ZoFontGamepad18" },
    { big = "ZoFontGamepadBold25", row = "ZoFontGamepad20" },
    { big = "ZoFontGamepadBold27", row = "ZoFontGamepad22" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad25" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad27" },
}
hud.NUM_SIZES = #SIZES

local LIVE = { 1, 0.75, 0.3 }
local GREY = { 0.7, 0.7, 0.7 }
local WHITE = { 0.95, 0.95, 0.95 }
local HEAD = { 0.62, 0.65, 0.69 }

-- The group columns: name, DPS, its share, HPS, its share. `sample` is the widest each gets.
local COLUMNS = {
    { sample = "12 Abcdefghijklmno" },
    { sample = "9,999,999", right = true },
    { sample = "100%", right = true },
    { sample = "999,999", right = true },
    { sample = "100%", right = true },
}

local SAMPLE_GROUP = {
    { name = "Alice", dps = 52100, hps = 1200, dpsShare = 0.38, hpsShare = 0.10 },
    { name = "You", dps = 45210, hps = 3120, dpsShare = 0.33, hpsShare = 0.27, self = true },
    { name = "Bob", dps = 39800, hps = 7300, dpsShare = 0.29, hpsShare = 0.63 },
}

local L = ADDON.L

local function Now()
    return GetFrameTimeMilliseconds()
end

local function Label(parent, suffix, right)
    local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    if right then
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    return label
end

function hud:Fonts()
    local size = math.floor(tonumber(ADDON.sv.hudSize) or 3)
    size = SIZES[math.max(1, math.min(#SIZES, size))]
    return size.big, size.row
end

local function Measure(font, text)
    return ADDON.MeasureText(font, text) or (#text * ADDON.MeasureFont(font) * 0.55)
end

function hud:Layout()
    local top = self.control
    local sv = ADDON.sv
    local bigFont, rowFont = self:Fonts()
    local bigHeight = ADDON.MeasureFont(bigFont) + LINE_PADDING
    local rowHeight = ADDON.MeasureFont(rowFont) + LINE_PADDING
    self.rowHeight = rowHeight

    -- The group columns' widths and places.
    local widths, xs, x = {}, {}, PADDING
    for index, column in ipairs(COLUMNS) do
        widths[index] = math.ceil(Measure(rowFont, column.sample)) + 4
        xs[index] = x
        x = x + widths[index] + COL_GAP
    end
    local groupWidth = x - COL_GAP - PADDING

    local widest = math.max(MIN_WIDTH - PADDING * 2,
        Measure(bigFont, string.format(L(SI_PBSBS_HUD_FMT_DPS), "999,999") .. string.format(L(SI_PBSBS_HUD_FMT_BOSS), "100%")),
        Measure(rowFont, string.format(L(SI_PBSBS_HUD_FMT_HPS), "999,999", "59:59")))
    if sv.hudGroup then
        widest = math.max(widest, groupWidth)
    end
    self.width = math.ceil(widest) + PADDING * 2
    self.topHeight = PADDING + bigHeight + (sv.hudHps and rowHeight or 0)
    self.fill:SetColor(0, 0, 0, (tonumber(sv.hudAlpha) or 50) / 100)

    self.big:SetFont(bigFont)
    self.big:SetDimensions(self.width - PADDING * 2, bigHeight)
    self.big:ClearAnchors()
    self.big:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, PADDING)
    self.row:SetFont(rowFont)
    self.row:SetDimensions(self.width - PADDING * 2, rowHeight)
    self.row:ClearAnchors()
    self.row:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, PADDING + bigHeight)
    self.row:SetHidden(not sv.hudHps)

    -- Header and rows of the group list, under the top lines.
    local y = self.topHeight + GROUP_GAP
    local lines = { self.head }
    for _, line in ipairs(self.lines) do
        lines[#lines + 1] = line
    end
    for _, line in ipairs(lines) do
        for index, label in ipairs(line) do
            label:SetFont(rowFont)
            label:SetDimensions(widths[index], rowHeight)
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, top, TOPLEFT, xs[index], y)
            label:SetHidden(true)
        end
        y = y + rowHeight
    end
    self.texts = {}
    self.shownRows = -1
end

function hud:Create()
    if self.control then
        return self.control
    end
    if not WINDOW_MANAGER or not GuiRoot then
        return nil
    end
    local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    top:SetHidden(true)
    top:SetMouseEnabled(false)
    top:SetMovable(false)
    top:SetDrawLayer(DL_OVERLAY)
    top:SetDrawTier(DT_MEDIUM)
    self.control = top

    -- The background first: siblings draw in the order they were made.
    self.fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
    self.fill:SetAnchorFill(top)
    self.big = Label(top, "Big")
    self.row = Label(top, "Row")
    local function Line(suffix)
        local line = {}
        for index, column in ipairs(COLUMNS) do
            line[index] = Label(top, suffix .. "C" .. index, column.right)
        end
        return line
    end
    self.head = Line("Head")
    self.lines = {}
    for r = 1, MAX_GROUP_ROWS do
        self.lines[r] = Line("G" .. r)
    end
    self:Layout()
    self:Place()

    top:SetHandler("OnUpdate", function()
        local now = Now()
        if now < self.nextUpdate then
            return
        end
        self.nextUpdate = now + UPDATE_MS
        self:Update(now)
    end)
    return top
end

function hud:Place()
    if not self.control then
        return
    end
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ADDON.sv.hudX, ADDON.sv.hudY)
end

-- The size, the background, the HPS line or the group list changed in the settings.
function hud:ApplyStyle()
    if self.control then
        self:Layout()
        self:Place()
        self:Refresh()
    end
end

local function SetText(self, label, key, text, color)
    local cache = self.texts
    if cache[key] == text and cache[key .. "c"] == color then
        return
    end
    cache[key] = text
    cache[key .. "c"] = color
    label:SetText(text)
    label:SetColor(color[1], color[2], color[3], 1)
end

local function Pct(share)
    return string.format("%d%%", math.floor((share or 0) * 100 + 0.5))
end

-- Shows `count` group rows (0 hides the header too) and sizes the box to them.
function hud:ShowRows(count)
    if count == self.shownRows then
        return
    end
    self.shownRows = count
    for _, label in ipairs(self.head) do
        label:SetHidden(count == 0)
    end
    for r, line in ipairs(self.lines) do
        for _, label in ipairs(line) do
            label:SetHidden(r > count)
        end
    end
    local height = self.topHeight + PADDING
    if count > 0 then
        height = self.topHeight + GROUP_GAP + self.rowHeight * (count + 1) + PADDING
    end
    self.control:SetDimensions(self.width, height)
end

function hud:Draw(mine, rows)
    if mine then
        local text = string.format(L(SI_PBSBS_HUD_FMT_DPS), ADDON.Commas(mine.dps))
        if mine.boss then
            -- the share of the bosses' health: everybody's damage counted, add-on or not
            text = text .. string.format(L(SI_PBSBS_HUD_FMT_BOSS), Pct(mine.boss))
        end
        SetText(self, self.big, "big", text, mine.ended and GREY or LIVE)
        if ADDON.sv.hudHps then
            SetText(self, self.row, "row", string.format(L(SI_PBSBS_HUD_FMT_HPS), ADDON.Commas(mine.hps), ADDON.Duration(mine.secs)), mine.ended and GREY or WHITE)
        end
    else
        SetText(self, self.big, "big", string.format(L(SI_PBSBS_HUD_FMT_DPS), "-"), GREY)
        if ADDON.sv.hudHps then
            SetText(self, self.row, "row", string.format(L(SI_PBSBS_HUD_FMT_HPS), "-", "-"), GREY)
        end
    end

    local count = 0
    if ADDON.sv.hudGroup then
        count = math.min(#rows, MAX_GROUP_ROWS, math.max(1, math.floor(tonumber(ADDON.sv.hudGroupRows) or 6)))
        -- the player stays on the list even when the list is cut short
        local selfIndex
        for index, row in ipairs(rows) do
            if row.self then
                selfIndex = index
            end
        end
        local shown = {}
        for index = 1, count do
            shown[index] = rows[index]
        end
        if selfIndex and selfIndex > count and count > 0 then
            shown[count] = rows[selfIndex]
        end
        if count > 0 then
            local headTexts = { L(SI_PBSBS_HUD_GROUP), "DPS", "%", "HPS", "%" }
            for index, label in ipairs(self.head) do
                SetText(self, label, "h" .. index, headTexts[index], HEAD)
            end
        end
        for r = 1, count do
            local row = shown[r]
            local rank = row == rows[selfIndex] and selfIndex or r
            local color = row.self and LIVE or (row.ended and GREY or WHITE)
            local cells = { rank .. " " .. ADDON.names.Shown(row.name), ADDON.Commas(row.dps), Pct(row.dpsShare), ADDON.Commas(row.hps), Pct(row.hpsShare) }
            for index, label in ipairs(self.lines[r]) do
                SetText(self, label, r .. ":" .. index, cells[index], color)
            end
        end
    end
    self:ShowRows(count)
end

-- The player's numbers (nil when there is no fight to show) and the group's rows.
function hud:State(nowMs)
    local now = nowMs / 1000
    local holdSec = tonumber(ADDON.sv.hudHoldSec) or 10
    local dps, hps, secs, ended, boss = ADDON.fights:HudNumbers(now, holdSec)
    local mine = dps and { dps = dps, hps = hps, secs = secs, ended = ended, boss = boss } or nil
    local rows = {}
    if ADDON.sv.hudGroup and ADDON.group then
        rows = ADDON.group:HudRows(now, holdSec, mine)
    end
    return mine, rows
end

-- Whether the box is wanted, with the state it would draw (worked out once per update).
function hud:Wanted(nowMs)
    local sv = ADDON.sv
    if not sv.enabled or not sv.hud then
        return false
    end
    if not self.preview and not self.sceneShown then
        return false
    end
    local mine, rows = self:State(nowMs)
    return self.preview or mine ~= nil or #rows > 0, mine, rows
end

function hud:SetVisible(visible)
    self.visible = visible
    if self.control then
        self.control:SetHidden(not visible)
    end
end

function hud:Update(nowMs)
    local wanted, mine, rows = self:Wanted(nowMs)
    if not wanted then
        self:SetVisible(false)
        return
    end
    if self.preview and not mine and #rows == 0 then
        self:Draw({ dps = 45210, hps = 3120, secs = 83 }, ADDON.sv.hudGroup and SAMPLE_GROUP or {})
    else
        self:Draw(mine, rows)
    end
end

function hud:Refresh()
    local nowMs = Now()
    if self:Wanted(nowMs) then
        if not self:Create() then
            return
        end
        self:Update(nowMs)
        self:SetVisible(true)
    elseif self.visible then
        self:SetVisible(false)
    end
end

-- A fight started, or a member's reading came in: the box comes up.
function hud:Poke()
    if not self.visible then
        self:Refresh()
    end
end

function hud:OnPanelOpen(open)
    self.preview = open and true or false
    self:Refresh()
end

local function OnSceneStateChange()
    hud.sceneShown = (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing()) or false
    hud:Refresh()
end

function hud:Initialize()
    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    end
    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    end
    OnSceneStateChange()
end
