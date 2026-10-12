local Chronos = _G['Chronos']

local ROW_HEIGHT = 24
local SECTION_GAP = 10

local GUIDE_SECTIONS = {
    { key = "START", entries = { "INTRO", "COMMANDS", "UPDATES" } },
    { key = "CLOCK", entries = { "SHOW", "TIMEZONE", "DST", "UTC", "DESIGN" } },
}

local rows = {}
local activeKey

local function localize(suffix)
    return Chronos.GetDefaultLocaleString("GUIDE_" .. suffix)
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

function Chronos:OnGuideRowHover(button, over)
    local row = rows[button.rowIndex]

    if not row.key or row.key == activeKey then
        return
    end

    row.label:SetColor(over and 0.9 or 0.62, over and 0.9 or 0.62, over and 0.9 or 0.62, 1)
end

function Chronos:ShowGuideEntry(key)
    activeKey = key
    refreshRows()

    Chronos_Guide_EntryTitle:SetText(localize(key .. "_TITLE"))

    local text = Chronos_Guide_Text
    text:SetText(localize(key .. "_BODY"))

    local _, height = text:GetTextDimensions()
    Chronos_Guide_ContainerScrollChild:SetHeight(height + 24)

    ZO_Scroll_ResetToTop(Chronos_Guide_Container)
end

function Chronos:ToggleGuide(show)
    if show == nil then
        show = Chronos_Guide:IsHidden()
    end

    if show then
        self:ShowGuideEntry(activeKey)
    end

    Chronos_Guide:SetHidden(not show)
end

function Chronos:SetupGuideHelp(help, key, tooltipText)
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

function Chronos:CreateGuideHelp(parent, rightOf, key)
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

function Chronos:OpenGuideEntry(key)
    activeKey = key
    self:ToggleGuide(true)

    for _, row in ipairs(rows) do
        if row.key == key then
            ZO_Scroll_ScrollControlIntoCentralView(Chronos_Guide_Topics, row.control, true)
            return
        end
    end
end

local function createRow(parent, index, isSection)
    local control = CreateControlFromVirtual("$(parent)Row", parent, "Chronos_GuideRow", index)
    control.rowIndex = index

    local label = control:GetNamedChild("Text")

    if isSection then
        control:SetMouseEnabled(false)
        label:SetFont("ZoFontWinH4")
        label:SetColor(0.95, 0.9, 0.75, 1)
    end

    return control, label
end

local function layoutRows()
    local list = Chronos_Guide_TopicsScrollChild
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

function Chronos:InitGuide()
    Chronos_Guide_Title:SetText(localize("WINDOW_TITLE"))

    Chronos_Guide:SetHandler("OnMoveStop", function()
        self.db.guideX = zo_floor(Chronos_Guide:GetLeft())
        self.db.guideY = zo_floor(Chronos_Guide:GetTop())
    end)

    if self.db.guideX ~= nil and self.db.guideY ~= nil then
        Chronos_Guide:ClearAnchors()
        Chronos_Guide:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.db.guideX, self.db.guideY)
    end

    Chronos_Guide_Close:SetHandler("OnClicked", function()
        self:ToggleGuide(false)
    end)

    local list = Chronos_Guide_TopicsScrollChild
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

            if not activeKey then
                activeKey = key
            end
        end
    end

    layoutRows()

    local settings = Chronos_Guide_Settings
    settings:SetText(localize("OPEN_SETTINGS"))
    settings:SetHandler("OnClicked", function()
        self:ToggleGuide(false)
        LibAddonMenu2:OpenToPanel(self.panel)
    end)

    refreshRows()
end