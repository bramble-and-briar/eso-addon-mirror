local TP = TheProfit

-- The list of group deals, shown next to ESO's group window. It appears only when
-- sharing is on and the player turned the window on; both are off by default.
local WINDOW_NAME = "TheProfitGroupDeals"
local SCENE_NAME = "groupMenuKeyboard"
local VISIBLE_ROWS = 10
local ROW_HEIGHT = 26
local TITLE_HEIGHT = 30
local HEADER_HEIGHT = 22
local PADDING = 10
local ICON_SIZE = 22
-- Kiosk names with their zone are long, so the place column gets most of the width.
local COLUMN_ITEM = 260
local COLUMN_PRICE = 120
local COLUMN_PLACE = 460
local COLUMN_WHEN = 90
local WIDTH = PADDING * 2 + COLUMN_ITEM + COLUMN_PRICE + COLUMN_PLACE + COLUMN_WHEN
local HEIGHT = TITLE_HEIGHT + HEADER_HEIGHT + ROW_HEIGHT * VISIBLE_ROWS + PADDING
local DEFAULT_RIGHT = -40
local DEFAULT_TOP = 140
local REFRESH_MS = 30 * 1000
local DIMMED_ALPHA = 0.45
local TEXT_COLOR = { 0.91, 0.91, 0.93 }
local MUTED_COLOR = { 0.65, 0.66, 0.7 }

local strings = {
    en = {
        show = "Show group deals window",
        showTooltip = "Shows the list of deals reported by group members next to the group window. Needs sharing with the group.",
        title = "Group deals",
        headerItem = "ITEM",
        headerPrice = "PRICE",
        headerPlace = "PLACE",
        headerWhen = "WHEN",
        empty = "No deals reported yet.",
        visited = "visited",
    },
    ru = {
        show = "Показывать окно сделок группы",
        showTooltip = "Показывает рядом с окном группы список сделок, о которых сообщили участники группы. Нужен обмен с группой.",
        title = "Сделки группы",
        headerItem = "ПРЕДМЕТ",
        headerPrice = "ЦЕНА",
        headerPlace = "МЕСТО",
        headerWhen = "КОГДА",
        empty = "Пока нет сообщений о сделках.",
        visited = "пройден",
    },
}

local function L(key)
    local language = string.lower(GetCVar("language.2") or "en") == "ru" and "ru" or "en"
    return strings[language][key] or strings.en[key] or key
end

local window = { offset = 0, attached = false }

local function GetStore()
    if not TP.SV then return nil end
    TP.SV.groupDeals = TP.SV.groupDeals or {}
    return TP.SV.groupDeals
end

local function GetSetting(key)
    local store = GetStore()
    return store and store[key]
end

local function SetSetting(key, value)
    local store = GetStore()
    if store then store[key] = value end
end

local function IsSharingEnabled()
    return TP.GroupComm ~= nil and TP.GroupComm.IsEnabled()
end

local function Refresh()
    if not window.container then return end

    local deals = TP.GetGroupDeals()
    window.offset = zo_clamp(window.offset, 0, math.max(0, #deals - VISIBLE_ROWS))
    window.empty:SetHidden(#deals > 0)

    for index, row in ipairs(window.rows) do
        local deal = deals[window.offset + index]
        row:SetHidden(deal == nil)
        if deal then
            local item = TP.GetWantedItem(deal.itemKey)
            local alpha = deal.visitedAt and DIMMED_ALPHA or 1
            local name = item and item.name or "?"
            if deal.visitedAt then name = name .. " |c9B9FA9(" .. L("visited") .. ")|r" end

            local icon = item and item.icon
            row.icon:SetHidden(not icon)
            if icon then row.icon:SetTexture(icon) end
            row.icon:SetAlpha(alpha)

            local r, g, b = TP.GetGroupItemColor(item and item.link)
            row.name:SetText(name)
            row.name:SetColor(r, g, b, alpha)
            row.price:SetText(TP.FormatQuantityAtPrice(deal.quantity, deal.unitPrice))
            row.price:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], alpha)
            row.place:SetText(TP.GetGroupPlaceText(deal.guildId, deal.place))
            row.place:SetColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], alpha)
            row.when:SetText((TP.FormatAge(deal.receivedAt):gsub("%.$", "")))
            row.when:SetColor(MUTED_COLOR[1], MUTED_COLOR[2], MUTED_COLOR[3], alpha)
        end
    end
end

local function CreateLabel(name, parent, font, color, horizontalAlignment)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(color[1], color[2], color[3], 1)
    label:SetHorizontalAlignment(horizontalAlignment or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMaxLineCount(1)
    -- A cut text ends in "...", so it is clear that something is missing.
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function RestorePosition()
    window.container:ClearAnchors()
    if GetSetting("hasPosition") then
        window.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GetSetting("left"), GetSetting("top"))
    else
        window.container:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, DEFAULT_RIGHT, DEFAULT_TOP)
    end
end

local function SavePosition()
    local left = window.container:GetLeft()
    local top = window.container:GetTop()
    if left and top then
        SetSetting("left", math.floor(left + 0.5))
        SetSetting("top", math.floor(top + 0.5))
        SetSetting("hasPosition", true)
    end
end

-- Adds the window to the group scene only while sharing, display and deal data
-- all say there is something useful to show.
local function Apply()
    if not window.container or not window.scene then return end

    local shouldShow = IsSharingEnabled() and GetSetting("enabled") == true and #TP.GetGroupDeals() > 0
    if shouldShow and not window.attached then
        window.scene:AddFragment(window.fragment)
        window.attached = true
        Refresh()
    elseif not shouldShow and window.attached then
        window.scene:RemoveFragment(window.fragment)
        window.attached = false
    end
end

local function CreateRow(index)
    local container = window.container
    local row = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Row" .. index, container, CT_CONTROL)
    row:SetDimensions(WIDTH - PADDING * 2, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, container, TOPLEFT, PADDING, TITLE_HEIGHT + HEADER_HEIGHT + (index - 1) * ROW_HEIGHT)

    local icon = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Row" .. index .. "Icon", row, CT_TEXTURE)
    icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    icon:SetAnchor(LEFT, row, LEFT, 0, 0)

    local name = CreateLabel(WINDOW_NAME .. "Row" .. index .. "Name", row, "ZoFontGame", TEXT_COLOR)
    name:SetDimensions(COLUMN_ITEM - ICON_SIZE - 6, ROW_HEIGHT)
    name:SetAnchor(LEFT, row, LEFT, ICON_SIZE + 6, 0)

    local price = CreateLabel(WINDOW_NAME .. "Row" .. index .. "Price", row, "ZoFontGame", TEXT_COLOR)
    price:SetDimensions(COLUMN_PRICE, ROW_HEIGHT)
    price:SetAnchor(LEFT, row, LEFT, COLUMN_ITEM, 0)

    local place = CreateLabel(WINDOW_NAME .. "Row" .. index .. "Place", row, "ZoFontGame", TEXT_COLOR)
    place:SetDimensions(COLUMN_PLACE - 8, ROW_HEIGHT)
    place:SetAnchor(LEFT, row, LEFT, COLUMN_ITEM + COLUMN_PRICE, 0)

    local when = CreateLabel(WINDOW_NAME .. "Row" .. index .. "When", row, "ZoFontGame", MUTED_COLOR)
    when:SetDimensions(COLUMN_WHEN, ROW_HEIGHT)
    when:SetAnchor(LEFT, row, LEFT, COLUMN_ITEM + COLUMN_PRICE + COLUMN_PLACE, 0)

    row.icon, row.name, row.price, row.place, row.when = icon, name, price, place, when
    return row
end

function TP.SetupGroupDealsWindow()
    if window.container then return end

    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(SCENE_NAME)
    if not scene then return end
    window.scene = scene

    local container = WINDOW_MANAGER:CreateTopLevelWindow(WINDOW_NAME)
    container:SetDimensions(WIDTH, HEIGHT)
    container:SetClampedToScreen(true)
    container:SetMouseEnabled(true)
    container:SetMovable(true)
    container:SetHidden(true)
    container:SetHandler("OnMoveStop", SavePosition)
    -- The age column is refreshed only while the window is on screen.
    container:SetHandler("OnShow", function()
        Refresh()
        EVENT_MANAGER:RegisterForUpdate(WINDOW_NAME .. "Refresh", REFRESH_MS, Refresh)
    end)
    container:SetHandler("OnHide", function()
        EVENT_MANAGER:UnregisterForUpdate(WINDOW_NAME .. "Refresh")
    end)
    container:SetHandler("OnMouseWheel", function(_, delta)
        window.offset = window.offset - delta
        Refresh()
    end)
    window.container = container

    local background = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Background", container, CT_BACKDROP)
    background:SetAnchorFill(container)
    background:SetCenterColor(0.045, 0.049, 0.059, 0.92)
    background:SetEdgeColor(0, 0, 0, 0)

    local title = CreateLabel(WINDOW_NAME .. "Title", container, "ZoFontGameBold", { 0.91, 0.77, 0.42 })
    title:SetDimensions(WIDTH - PADDING * 2, TITLE_HEIGHT)
    title:SetAnchor(TOPLEFT, container, TOPLEFT, PADDING, 0)
    title:SetText(L("title"))

    local headers = {
        { "headerItem", ICON_SIZE + 6, COLUMN_ITEM },
        { "headerPrice", COLUMN_ITEM, COLUMN_PRICE },
        { "headerPlace", COLUMN_ITEM + COLUMN_PRICE, COLUMN_PLACE },
        { "headerWhen", COLUMN_ITEM + COLUMN_PRICE + COLUMN_PLACE, COLUMN_WHEN },
    }
    for _, header in ipairs(headers) do
        local label = CreateLabel(WINDOW_NAME .. header[1], container, "ZoFontGameSmall", MUTED_COLOR)
        label:SetDimensions(header[3], HEADER_HEIGHT)
        label:SetAnchor(TOPLEFT, container, TOPLEFT, PADDING + header[2], TITLE_HEIGHT)
        label:SetText(L(header[1]))
    end

    local empty = CreateLabel(WINDOW_NAME .. "Empty", container, "ZoFontGame", MUTED_COLOR, TEXT_ALIGN_CENTER)
    empty:SetDimensions(WIDTH - PADDING * 2, ROW_HEIGHT * 2)
    empty:SetAnchor(TOPLEFT, container, TOPLEFT, PADDING, TITLE_HEIGHT + HEADER_HEIGHT + ROW_HEIGHT)
    empty:SetText(L("empty"))
    window.empty = empty

    window.rows = {}
    for index = 1, VISIBLE_ROWS do window.rows[index] = CreateRow(index) end

    window.fragment = ZO_SimpleSceneFragment:New(container)
    RestorePosition()

    TP.callbacks:RegisterCallback("GroupDealsChanged", function()
        Apply()
        if window.attached and not container:IsHidden() then Refresh() end
    end)
    TP.callbacks:RegisterCallback("GroupSharingChanged", Apply)
    TP.callbacks:RegisterCallback("GroupPositionsReset", function()
        SetSetting("hasPosition", false)
        RestorePosition()
    end)

    Apply()
end

local getBaseControls = TP.GetGroupOptionControls
function TP.GetGroupOptionControls()
    local controls = getBaseControls and getBaseControls() or {}
    table.insert(controls, 3, {
        type = "checkbox",
        name = L("show"),
        tooltip = L("showTooltip"),
        getFunc = function() return GetSetting("enabled") == true end,
        setFunc = function(value)
            SetSetting("enabled", value)
            Apply()
        end,
        disabled = function() return not IsSharingEnabled() end,
        default = false,
    })
    return controls
end
