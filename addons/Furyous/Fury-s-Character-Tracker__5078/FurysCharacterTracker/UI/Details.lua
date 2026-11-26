-- The details window: everything saved for one character (click a character on the board), and
-- the Start here page. What it says is put together in Core/Pages.lua; this file lays it out.
local CT = FurysCharacterTracker
local Pages = CT.Pages
local Details = {}
CT.Details = Details

local T = CT.Theme                    -- Fury Night colors and fonts (UI/Theme.lua)
local VIOLET = T.RGB.VIOLET           -- done / maxed
local TEXT = T.RGB.TEXT
local MUTED = T.RGB.SUB
local DIM = T.RGB.MUTED

local COLUMNS, COL_W, COL_GAP, KEY_W, VALUE_W, LINE_H = 3, 300, 20, 196, 100, 22
local WIDTH = COLUMNS * COL_W + (COLUMNS - 1) * COL_GAP

function Details:Build()
    if self.content then return end
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Details, false)
    self.content = FurysCharacterTracker_DetailsScrollScrollChild
    self.labels = {}
    local pos = CT.sv.detailsWindow
    if pos then
        FurysCharacterTracker_Details:ClearAnchors()
        FurysCharacterTracker_Details:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
    end
end

function Details.SavePosition()
    CT.sv.detailsWindow = { x = FurysCharacterTracker_Details:GetLeft(), y = FurysCharacterTracker_Details:GetTop() }
end

-- Labels are reused between pages; the ones not needed this time are hidden.
-- `wrap`: the text may run over several lines (the label then grows to fit). Returns the label.
function Details:Put(index, text, font, rgb, x, y, width, align, wrap)
    local label = self.labels[index]
    if not label then
        label = WINDOW_MANAGER:CreateControl("FurysCharacterTracker_DetailsText" .. index, self.content, CT_LABEL)
        self.labels[index] = label
    end
    label:SetHidden(false)
    label:ClearAnchors()
    label:SetMouseEnabled(false)
    label:SetHandler("OnMouseUp", nil)
    label:SetFont(font)
    label:SetColor(rgb[1], rgb[2], rgb[3], 1)
    label:SetWrapMode(wrap and TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS)
    label:SetDimensions(width, wrap and 0 or LINE_H)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetAnchor(TOPLEFT, self.content, TOPLEFT, x, y)
    label:SetText(text)
    return label
end

-- What a click on a line does, if anything.
local function ClickOf(line)
    if line.switch then
        return function()
            CT.SetSwitch(line.switch, not Pages.SwitchOn(line.switch))
            Details:ShowStart(true)
        end
    elseif line.url then
        return function() RequestOpenUnsafeURL(CT.toolsUrl) end
    elseif line.more then
        return function() RequestOpenUnsafeURL(line.more) end
    end
end

-- Lays a page out in the window and shows it.
function Details:Fill(title, subtitle, sections, keepScroll)
    self:Build()
    FurysCharacterTracker_DetailsTitle:SetText(title)
    FurysCharacterTracker_DetailsSubtitle:SetText(subtitle)
    local n, y = 0, 0
    for _, section in ipairs(sections) do
        n = n + 1
        self:Put(n, section.title, "ZoFontGameBold", T.RGB.BLUE, 0, y, WIDTH)
        y = y + LINE_H + 4
        local items = section.items or {}
        for i, item in ipairs(items) do
            local col = (i - 1) % COLUMNS
            local x = col * (COL_W + COL_GAP)
            n = n + 1
            self:Put(n, item[1], "ZoFontGame", MUTED, x, y, KEY_W)
            n = n + 1
            self:Put(n, item[2], item.done and "ZoFontGameBold" or "ZoFontGame", item.done and VIOLET or (item.dim and DIM or TEXT),
                     x + COL_W - VALUE_W, y, VALUE_W, TEXT_ALIGN_RIGHT)
            if col == COLUMNS - 1 or i == #items then y = y + LINE_H end
        end
        for _, line in ipairs(section.lines or {}) do
            if type(line) ~= "table" then line = { line } end
            local click = ClickOf(line)
            n = n + 1
            local label = self:Put(n, line[1], line.bold and "ZoFontGameBold" or "ZoFontGame",
                                   click and T.RGB.BLUE or (line.gold and VIOLET or (line.bold and TEXT or MUTED)), 0, y, WIDTH, nil, true)
            if click then
                label:SetMouseEnabled(true)
                label:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then click() end end)
            end
            -- A long line wraps: give the label the height its text needs.
            local height = math.max(LINE_H, label:GetTextHeight())
            label:SetHeight(height)
            y = y + height
        end
        y = y + 12
    end
    for i = n + 1, #self.labels do self.labels[i]:SetHidden(true) end
    if not keepScroll then ZO_Scroll_ResetToTop(FurysCharacterTracker_DetailsScroll) end
    SCENE_MANAGER:ShowTopLevel(FurysCharacterTracker_Details)
    CT.Raise(FurysCharacterTracker_Details)
end

function Details:Show(id)
    local e = CT.Roster:Entry(id)
    if not e then return end
    local title, subtitle = Pages.DetailsHeader(e)
    self:Fill(title, subtitle, Pages.Details(e))
end

-- The one-page guide (button on the board, /fct start). It opens by itself with the board the
-- first time on a new install. `keepScroll`: redraw after a switch was clicked, without jumping
-- back to the top.
function Details:ShowStart(keepScroll)
    local title, subtitle = Pages.StartHeader()
    self:Fill(title, subtitle, Pages.Start(), keepScroll)
end

function Details:Hide()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Details)
end
