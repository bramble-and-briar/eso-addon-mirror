local Hermes = _G["Hermes"]

local ROW_HEIGHT = 24
local SECTION_GAP = 10

local GUIDE_SECTIONS = {
    { key = "START", entries = { "INTRO", "COMMANDS", "KEYBINDS", "UPDATES" } },
    { key = "TOMES", entries = { "WINDOW", "TRACK", "CLAIM", "ICON", "CHAT" } },
    { key = "CHAT", entries = { "CONTEXT", "RESIZE" } },
}

local rows = {}
local activeKey
local firstKey

local function localize(suffix)
    return Hermes.GetDefaultLocaleString("GUIDE_" .. suffix)
end

local function refreshRows()
    for _, row in ipairs(rows) do
        if row.key then
            local isActive = row.key == activeKey

            row.label:SetColor(isActive and 1 or 0.62, isActive and 0.85 or 0.62,
                    isActive and 0.4 or 0.62, 1)
        end
    end
end

function Hermes:OnGuideRowHover(button, over)
    local row = rows[button.rowIndex]

    if not row.key or row.key == activeKey then
        return
    end

    row.label:SetColor(over and 0.9 or 0.62, over and 0.9 or 0.62, over and 0.9 or 0.62, 1)
end

function Hermes:ShowGuideEntry(key)
    activeKey = key
    refreshRows()

    Hermes_Guide_EntryTitle:SetText(localize(key .. "_TITLE"))

    local text = Hermes_Guide_Text
    text:SetText(localize(key .. "_BODY"))

    local _, height = text:GetTextDimensions()
    Hermes_Guide_ContainerScrollChild:SetHeight(height + 24)

    ZO_Scroll_ResetToTop(Hermes_Guide_Container)
end

local function layoutRows()
    local list = Hermes_Guide_TopicsScrollChild
    local offsetY = 6

    for index, row in ipairs(rows) do
        if not row.key and index > 1 then
            offsetY = offsetY + SECTION_GAP
        end

        row.control:ClearAnchors()
        row.control:SetAnchor(TOPLEFT, list, TOPLEFT, 0, offsetY)
        offsetY = offsetY + ROW_HEIGHT
    end

    list:SetHeight(offsetY + 6)
end

function Hermes:ToggleGuide(show)
    if show == nil then
        show = Hermes_Guide:IsHidden()
    end

    if show then
        self:ShowGuideEntry(activeKey)
    end

    Hermes_Guide:SetHidden(not show)
end

function Hermes:SetupGuideHelp(help, key, tooltipText)
    help:SetHandler("OnMouseEnter", function()
        help:SetColor(1, 1, 1, 1)
        InitializeTooltip(InformationTooltip, help, TOP, 0, 4, BOTTOM)
        SetTooltipText(InformationTooltip, tooltipText)
    end)

    help:SetHandler("OnMouseExit", function()
        help:SetColor(0.54, 0.54, 0.54, 1)
        ClearTooltip(InformationTooltip)
    end)

    help:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then
            ClearTooltip(InformationTooltip)
            self:OpenGuideEntry(key)
        end
    end)
end

function Hermes:CreateGuideHelp(parent, rightOf, key)
    local help = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    help:SetFont("ZoFontWinH3")
    help:SetText("?")
    help:SetColor(0.54, 0.54, 0.54, 1)
    help:SetDimensions(18, 24)
    help:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    help:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    help:SetMouseEnabled(true)
    help:SetAnchor(RIGHT, rightOf, LEFT, -4, 0)

    self:SetupGuideHelp(help, key, localize("HELP_TOOLTIP"))

    return help
end

function Hermes:OpenGuideEntry(key)
    self:ToggleGuide(true)
    self:ShowGuideEntry(key)

    for _, row in ipairs(rows) do
        if row.key == key then
            ZO_Scroll_ScrollControlIntoCentralView(Hermes_Guide_Topics, row.control, true)
            return
        end
    end
end

local function createRow(parent, index, isSection)
    local control = CreateControlFromVirtual("$(parent)Row", parent,
            "Hermes_GuideRow", index)
    control.rowIndex = index

    local label = control:GetNamedChild("Text")

    if isSection then
        control:SetMouseEnabled(false)
        label:SetFont("ZoFontWinH4")
        label:SetColor(0.95, 0.9, 0.75, 1)
    end

    return control, label
end

function Hermes:InitializeGuide()
    Hermes_Guide_Title:SetText(localize("WINDOW_TITLE"))

    Hermes_Guide:SetHandler("OnMoveStop", function()
        self.db.guideX = zo_floor(Hermes_Guide:GetLeft())
        self.db.guideY = zo_floor(Hermes_Guide:GetTop())
    end)

    if self.db.guideX ~= nil and self.db.guideY ~= nil then
        Hermes_Guide:ClearAnchors()
        Hermes_Guide:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.guideX, self.db.guideY)
    end

    Hermes_Guide_Close:SetHandler("OnClicked", function()
        self:ToggleGuide(false)
    end)

    local list = Hermes_Guide_TopicsScrollChild
    local index = 0

    for _, section in ipairs(GUIDE_SECTIONS) do
        index = index + 1
        local control, label = createRow(list, index, true)
        label:SetText(localize(section.key .. "_TITLE") .. ":")
        rows[index] = { control = control, label = label }

        for _, entry in ipairs(section.entries) do
            local key = section.key .. "_" .. entry

            index = index + 1
            local entryControl, entryLabel = createRow(list, index, false)
            entryLabel:SetText(localize(key .. "_TITLE"))
            entryControl:SetHandler("OnClicked", function()
                self:ShowGuideEntry(key)
            end)

            rows[index] = { control = entryControl, label = entryLabel, key = key }

            if not firstKey then
                firstKey = key
            end
        end
    end

    activeKey = firstKey
    layoutRows()

    local settings = Hermes_Guide_Settings
    settings:SetText(localize("OPEN_SETTINGS"))
    settings:SetHandler("OnClicked", function()
        self:ToggleGuide(false)
        LibAddonMenu2:OpenToPanel(self.panel)
    end)

    refreshRows()
end