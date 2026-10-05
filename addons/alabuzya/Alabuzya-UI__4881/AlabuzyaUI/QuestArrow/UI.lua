local A = QuestArrow
local U = {}
A.UI = U
local WIDTH = 420
local GOLD = { 0.95, 0.75, 0.38, 1 }
local CYAN = { 0.36, 0.85, 0.88, 1 }

local function label(parent, name, width, height, font)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    c:SetDimensions(width, height)
    c:SetFont(font or "ZoFontGame")
    c:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c:SetMaxLineCount(0)
    c:SetMouseEnabled(false)
    return c
end

function U:Create()
    local root = WINDOW_MANAGER:CreateTopLevelWindow("QuestArrowHUD")
    self.root = root
    root:SetDimensions(WIDTH, 250)
    root:SetClampedToScreen(true)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetHidden(true)
    local bg = WINDOW_MANAGER:CreateControl("QuestArrowBackground", root, CT_BACKDROP)
    self.background = bg
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.025, 0.035, 0.055, 0.8)
    bg:SetEdgeColor(0.55, 0.7, 0.9, 0.8)
    bg:SetMouseEnabled(false)
    self.quest = label(root, "QuestArrowQuest", WIDTH - 20, 0)
    self.quest:SetColor(0.92, 0.88, 0.77, 1)
    self.status = label(root, "QuestArrowStatus", WIDTH - 20, 0, "ZoFontGameSmall")
    self.status:SetColor(0.79, 0.76, 0.68, 1)
    self.destination = label(root, "QuestArrowDestination", WIDTH - 20, 0, "ZoFontGameBold")
    self.destination:SetColor(1, 0.95, 0.84, 1)
    self.detail = label(root, "QuestArrowDetail", WIDTH - 20, 0, "ZoFontGameSmall")
    self.detail:SetColor(0.83, 0.83, 0.79, 1)
    self.dial = WINDOW_MANAGER:CreateControl("QuestArrowDial", root, CT_CONTROL)
    self.dial:SetDimensions(90, 90)
    self.dial:SetMouseEnabled(false)
    self:CreateCompass()
    root:SetHandler("OnMoveStop", function()
        -- Save proportions so changing resolution does not strand the control.
        local x, y = root:GetCenter()
        A.saved.x = x / GuiRoot:GetWidth()
        A.saved.y = y / GuiRoot:GetHeight()
    end)
    self:ApplySettings()
    self:Layout()
end

-- Auto-height labels retain full names. A separate destination label means the
-- route caption cannot consume the space intended for a wayshrine's name.
function U:Layout()
    local y = 6
    local function place(c, gap)
        c:ClearAnchors()
        c:SetAnchor(TOP, self.root, TOP, 0, y)
        c:SetHeight(0)
        local height = c:GetText() ~= "" and math.max(18, c:GetTextHeight()) or 0
        c:SetHeight(height)
        c:SetHidden(height == 0)
        if height > 0 then y = y + height + gap end
    end
    place(self.quest, 5)
    self.dial:ClearAnchors()
    self.dial:SetAnchor(TOP, self.root, TOP, 0, y)
    y = y + 96
    place(self.status, 2)
    place(self.destination, 8)
    place(self.detail, 0)
    self.root:SetHeight(y + 8)
end

function U:SetQuest(text)
    text = text or ""
    if self.quest:GetText() ~= text then self.quest:SetText(text) self:Layout() end
end

local function polygon(name, parent, points, color, border)
    local c = WINDOW_MANAGER:CreateControl(name, parent, CT_POLYGON)
    c:SetAnchorFill(parent)
    c:SetMouseEnabled(false)
    c:SetSmoothingEnabled(true)
    c:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
    c:SetCenterColor(unpack(color))
    c:SetBorderColor(0.06, 0.07, 0.08, 0.95)
    c:SetBorderThickness(border or 0, border or 0, 1)
    for _, p in ipairs(points) do c:AddPoint(0.5 + p[1] / 90, 0.5 + p[2] / 90) end
    return c
end

function U:CreateCompass()
    local circle = {}
    for i = 0, 63 do
        local angle = i * 2 * math.pi / 64
        circle[#circle + 1] = { 39 * math.cos(angle), 39 * math.sin(angle) }
    end
    self.ring = polygon("QuestArrowCompassRing", self.dial, circle, {0.035, 0.045, 0.055, 0.67}, 1)
    self.ring:SetBorderColor(0.65, 0.55, 0.37, 0.72)
    -- Fixed engraved ticks keep the movement easy to read without clutter.
    for i = 0, 7 do
        local angle = i * math.pi / 4
        local outer, inner = 36, i % 2 == 0 and 30 or 33
        local tick = WINDOW_MANAGER:CreateControl("QuestArrowCompassTick" .. i, self.dial, CT_LINE)
        tick:SetThickness(1)
        tick:SetColor(0.8, 0.7, 0.48, i % 2 == 0 and 0.65 or 0.35)
        tick:SetMouseEnabled(false)
        tick:SetAnchor(TOPLEFT, self.dial, TOPLEFT, 45 + inner * math.sin(angle), 45 - inner * math.cos(angle))
        tick:SetAnchor(BOTTOMRIGHT, self.dial, TOPLEFT, 45 + outer * math.sin(angle), 45 - outer * math.cos(angle))
    end
    -- Four convex facets form a filled spearhead and a dark counterweight.
    -- All geometry uses ESO controls: no external textures or dependencies.
    self.facets = {
        {{0, -32}, {0, 5}, {-13, 13}},
        {{0, -32}, {13, 13}, {0, 5}},
        {{0, 7}, {0, 29}, {-5, 17}},
        {{0, 7}, {5, 17}, {0, 29}},
    }
    self.needle = {}
    for i, points in ipairs(self.facets) do
        self.needle[i] = polygon("QuestArrowNeedle" .. i, self.dial, points, GOLD, 0.8)
    end
end

function U:ApplySettings()
    local s, root = A.saved, self.root
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, TOPLEFT, s.x * GuiRoot:GetWidth(), s.y * GuiRoot:GetHeight())
    root:SetScale(s.scale)
    root:SetAlpha(s.alpha)
    root:SetMovable(not s.locked)
    root:SetMouseEnabled(not s.locked)
    self.background:SetHidden(s.locked)
end

function U:Arrow(angle, visible, travel)
    local sin, cos = math.sin(angle or 0), math.cos(angle or 0)
    local color = travel and CYAN or GOLD
    self.ring:SetBorderColor(color[1], color[2], color[3], visible and 0.65 or 0.25)
    for i, facet in ipairs(self.facets) do
        local c = self.needle[i]
        c:SetHidden(not visible)
        if visible then
            for j, p in ipairs(facet) do
                c:SetPoint(j, 0.5 + (p[1] * cos - p[2] * sin) / 90, 0.5 + (p[1] * sin + p[2] * cos) / 90)
            end
            local shade = ({1, 0.62, 0.4, 0.25})[i]
            c:SetCenterColor(color[1] * shade, color[2] * shade, color[3] * shade, 1)
        end
    end
end

function U:Message(status, detail, destination)
    status, detail, destination = status or "", detail or "", destination or ""
    if self.status:GetText() == status and self.detail:GetText() == detail
        and self.destination:GetText() == destination then return end
    self.status:SetText(status or "")
    self.detail:SetText(detail or "")
    self.destination:SetText(destination)
    self:Layout()
end

function U:Journal()
    local journal = ZO_QUEST_JOURNAL_QUESTS_KEYBOARD or QUEST_JOURNAL_KEYBOARD
    if not journal or not journal.GetSelectedQuestIndex or not journal.control then return end
    if self.journalButton then return end
    self.journal = journal
    local button = WINDOW_MANAGER:CreateControlFromVirtual("QuestArrowJournalButton", journal.control, "ZO_DefaultButton")
    self.journalButton = button
    button:SetDimensions(240, 28)
    -- Beside the stock Show On Map row, below the left quest list.
    if journal.showOnMapKeybindButton then
        button:SetAnchor(BOTTOMLEFT, journal.showOnMapKeybindButton, TOPLEFT, 0, -8)
    else
        button:SetAnchor(BOTTOMLEFT, journal.control, BOTTOMLEFT, 12, -48)
    end
    button:SetHandler("OnClicked", function()
        local index = journal:GetSelectedQuestIndex()
        if index then A:ToggleQuest(index) end
    end)
    if journal.RegisterCallback then
        journal:RegisterCallback("QuestSelected", function() self:UpdateButton() end)
    end
    self:UpdateButton()
end

function U:UpdateButton()
    if not self.journalButton then return end
    local index = self.journal:GetSelectedQuestIndex()
    self.journalButton:SetEnabled(index ~= nil and IsValidQuestIndex(index))
    local selected = index and A.questId and GetJournalQuestId(index) == A.questId
    self.journalButton:SetText(selected and "Убрать стрелку" or "Показывать путь")
end
