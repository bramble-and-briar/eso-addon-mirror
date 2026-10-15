local TP = TheProfit

-- Floating three-line message for deals reported by group members. Self-contained:
-- it needs TP.SV, TP.FormatQuantityAtPrice and the plain entry tables handed to
-- TP.ShowGroupHudMessage { name, r, g, b, quantity, unitPrice, guildId }.
local WINDOW_NAME = "TheProfitGroupHud"
local MENU_SCENE_NAME = "gameMenuInGame"
local DISPLAY_MS = 10 * 1000
local WINDOW_WIDTH = 640
local LINE_COUNT = 3
local LINE_PADDING = 6
local FONT_SIZE_MIN = 12
local FONT_SIZE_MAX = 40
local FONT_SIZE_DEFAULT = 22
local DEFAULT_LEFT = 40
local DEFAULT_TOP = 40
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULTS = {
    locked = false,
    fontSize = FONT_SIZE_DEFAULT,
    color = DEFAULT_COLOR,
    hasPosition = false,
    left = 0,
    top = 0,
}

local strings = {
    en = {
        header = "Group",
        lock = "Lock group alert",
        lockTooltip = "Locks the group alert in place. Unlock it to drag it with the mouse.",
        preview = "Preview alert",
        previewTooltip = "Keeps a sample alert on screen so you can drag it to the place you want.",
        color = "Alert text color",
        colorTooltip = "Color and opacity of the price and place lines. The item name keeps its quality color.",
        fontSize = "Alert text size",
        fontSizeTooltip = "Size of the alert text.",
        resetPosition = "Reset group window positions",
        resetPositionTooltip = "Moves the group alert and the group deals window back to their default places.",
        sampleItem = "Sample item",
        samplePlace = "Trader name, City",
    },
    ru = {
        header = "Группа",
        lock = "Закрепить групповое оповещение",
        lockTooltip = "Закрепляет групповое оповещение на месте. Снимите галочку, чтобы перетаскивать его мышью.",
        preview = "Показать пример оповещения",
        previewTooltip = "Держит на экране пример оповещения, чтобы вы перетащили его на нужное место.",
        color = "Цвет текста оповещения",
        colorTooltip = "Цвет и прозрачность строк с ценой и местом. Название предмета сохраняет цвет качества.",
        fontSize = "Размер текста оповещения",
        fontSizeTooltip = "Размер текста оповещения.",
        resetPosition = "Сбросить положение окон группы",
        resetPositionTooltip = "Возвращает групповое оповещение и окно сделок группы на положение по умолчанию.",
        sampleItem = "Пример предмета",
        samplePlace = "Имя торговца, Город",
    },
}

local function L(key)
    local language = string.lower(GetCVar("language.2") or "en") == "ru" and "ru" or "en"
    return strings[language][key] or strings.en[key] or key
end

-- Settings live in their own table so the main defaults stay untouched.
local function GetStore()
    if not TP.SV then return nil end
    TP.SV.groupHud = TP.SV.groupHud or {}
    return TP.SV.groupHud
end

local function GetSetting(key)
    local store = GetStore()
    local value = store and store[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

local function SetSetting(key, value)
    local store = GetStore()
    if store then store[key] = value end
end

local function GetColor()
    local color = GetSetting("color")
    if type(color) ~= "table" then color = DEFAULT_COLOR end
    return zo_clamp(tonumber(color.r) or 1, 0, 1),
        zo_clamp(tonumber(color.g) or 1, 0, 1),
        zo_clamp(tonumber(color.b) or 1, 0, 1),
        zo_clamp(tonumber(color.a) or 1, 0, 1)
end

local function GetFontSize()
    return zo_round(zo_clamp(tonumber(GetSetting("fontSize")) or FONT_SIZE_DEFAULT, FONT_SIZE_MIN, FONT_SIZE_MAX))
end

local hud = { generation = 0, preview = false, visible = false }

-- Uses the flag kept in SetVisible instead of asking the control: while the scene
-- keeps the window hidden, IsHidden() is true even for a message that is switched on.
local function RefreshInteractivity()
    if not hud.container then return end
    local locked = GetSetting("locked") == true
    hud.container:SetMovable(not locked)
    hud.container:SetMouseEnabled(hud.visible and not locked)
end

local function SetVisible(visible)
    if not hud.content then return end
    hud.visible = visible == true
    hud.content:SetHidden(not hud.visible)
    RefreshInteractivity()
end

local function ApplyStyle()
    if not hud.container then return end
    local size = GetFontSize()
    local font = string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size)
    local lineHeight = size + LINE_PADDING
    local r, g, b, a = GetColor()

    hud.container:SetDimensions(WINDOW_WIDTH, lineHeight * LINE_COUNT)
    for index, line in ipairs(hud.lines) do
        line:SetFont(font)
        line:SetDimensions(WINDOW_WIDTH, lineHeight)
        line:ClearAnchors()
        line:SetAnchor(TOPLEFT, hud.content, TOPLEFT, 0, (index - 1) * lineHeight)
        -- The first line takes the item's quality color when a message is rendered.
        if index > 1 then line:SetColor(r, g, b, a) end
    end
end

local function GetPlaceText(entry)
    if entry.place then return entry.place end
    local guildId = tonumber(entry.guildId)
    if guildId and guildId > 0 then
        local info = GetGuildOwnedKioskInfo(guildId)
        if info and info ~= "" then return zo_strformat("<<1>>", info) end
        local guildName = GetGuildName(guildId)
        if guildName and guildName ~= "" then return zo_strformat("<<1>>", guildName) end
    end
    return "—"
end

local function Render(entry)
    local _, _, _, alpha = GetColor()
    hud.lines[1]:SetText(entry.name or "")
    hud.lines[1]:SetColor(entry.r or 1, entry.g or 1, entry.b or 1, alpha)
    hud.lines[2]:SetText(TP.FormatQuantityAtPrice(entry.quantity, entry.unitPrice))
    hud.lines[3]:SetText(GetPlaceText(entry))
end

local function GetSampleEntry()
    local r, g, b = GetItemQualityColor(ITEM_QUALITY_ARTIFACT):UnpackRGBA()
    return {
        name = L("sampleItem"),
        r = r, g = g, b = b,
        quantity = 5,
        unitPrice = 1234,
        place = L("samplePlace"),
    }
end

local function SavePosition()
    local left = hud.container:GetLeft()
    local top = hud.container:GetTop()
    if left and top then
        SetSetting("left", math.floor(left + 0.5))
        SetSetting("top", math.floor(top + 0.5))
        SetSetting("hasPosition", true)
    end
end

local function RestorePosition()
    hud.container:ClearAnchors()
    if GetSetting("hasPosition") then
        hud.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GetSetting("left"), GetSetting("top"))
    else
        hud.container:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DEFAULT_LEFT, DEFAULT_TOP)
    end
end

local function ResetPosition()
    SetSetting("hasPosition", false)
    if hud.container then RestorePosition() end
    TP.callbacks:FireCallbacks("GroupPositionsReset")
end

-- The place line is shared with the group deals window.
function TP.GetGroupPlaceText(guildId, place)
    return GetPlaceText({ guildId = guildId, place = place })
end

-- Shows the newest message and drops the previous one. It disappears after ten
-- seconds unless the sample preview is on.
function TP.ShowGroupHudMessage(entry)
    if not hud.container or type(entry) ~= "table" then return end
    hud.generation = hud.generation + 1
    local generation = hud.generation
    hud.entry = entry
    Render(entry)
    SetVisible(true)
    zo_callLater(function()
        if generation == hud.generation and not hud.preview then SetVisible(false) end
    end, DISPLAY_MS)
end

-- Drops the message on screen when it is about the given tracked item.
function TP.HideGroupHudMessageForItem(itemKey)
    if not hud.container or hud.preview or not hud.entry or hud.entry.itemKey ~= itemKey then return end
    hud.generation = hud.generation + 1
    hud.entry = nil
    SetVisible(false)
end

-- The HUD scenes have no mouse cursor, so the sample could not be dragged from there.
-- While the preview is on it is also shown in the game menu, where the settings panel
-- is open and the cursor is active.
local function UpdateMenuFragment()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(MENU_SCENE_NAME)
    if not scene or not hud.fragment then return end

    if hud.preview and not hud.menuAttached then
        scene:AddFragment(hud.fragment)
        hud.menuAttached = true
    elseif not hud.preview and hud.menuAttached then
        scene:RemoveFragment(hud.fragment)
        hud.menuAttached = false
    end
end

function TP.SetGroupHudPreview(enabled)
    if not hud.container then return end
    hud.preview = enabled == true
    UpdateMenuFragment()
    -- The menu scene is already showing, so the fragment's own show/hide may not run.
    hud.container:SetHidden(not hud.preview)
    hud.generation = hud.generation + 1
    if hud.preview then
        Render(GetSampleEntry())
        SetVisible(true)
    else
        SetVisible(false)
    end
end

function TP.GetGroupOptionControls()
    return {
        {
            type = "header",
            name = L("header"),
        },
        {
            type = "checkbox",
            name = L("lock"),
            tooltip = L("lockTooltip"),
            getFunc = function() return GetSetting("locked") == true end,
            setFunc = function(value)
                SetSetting("locked", value)
                RefreshInteractivity()
            end,
            default = DEFAULTS.locked,
        },
        {
            type = "checkbox",
            name = L("preview"),
            tooltip = L("previewTooltip"),
            getFunc = function() return hud.preview end,
            setFunc = function(value) TP.SetGroupHudPreview(value) end,
            default = false,
        },
        {
            type = "colorpicker",
            name = L("color"),
            tooltip = L("colorTooltip"),
            getFunc = function() return GetColor() end,
            setFunc = function(r, g, b, a)
                SetSetting("color", { r = r, g = g, b = b, a = tonumber(a) or 1 })
                ApplyStyle()
            end,
            showAlpha = true,
            default = DEFAULT_COLOR,
        },
        {
            type = "slider",
            name = L("fontSize"),
            tooltip = L("fontSizeTooltip"),
            min = FONT_SIZE_MIN,
            max = FONT_SIZE_MAX,
            step = 1,
            decimals = 0,
            clampInput = true,
            getFunc = GetFontSize,
            setFunc = function(value)
                SetSetting("fontSize", zo_round(value))
                ApplyStyle()
            end,
            default = FONT_SIZE_DEFAULT,
        },
        {
            type = "button",
            name = L("resetPosition"),
            tooltip = L("resetPositionTooltip"),
            func = ResetPosition,
        },
    }
end

function TP.SetupGroupHud()
    if hud.container then return end

    local container = WINDOW_MANAGER:CreateTopLevelWindow(WINDOW_NAME)
    container:SetClampedToScreen(true)
    container:SetDrawTier(DT_HIGH)
    container:SetDrawLayer(DL_OVERLAY)
    container:SetHandler("OnMoveStop", SavePosition)
    -- A scene showing the window again must not leave the mouse switched off.
    container:SetHandler("OnShow", RefreshInteractivity)
    hud.container = container

    local content = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Content", container, CT_CONTROL)
    content:SetAnchorFill(container)
    content:SetHidden(true)
    hud.content = content

    hud.lines = {}
    for index = 1, LINE_COUNT do
        local line = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Line" .. index, content, CT_LABEL)
        line:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        line:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        line:SetMaxLineCount(1)
        hud.lines[index] = line
    end

    ApplyStyle()
    RestorePosition()
    RefreshInteractivity()

    hud.fragment = ZO_SimpleSceneFragment:New(container)
    HUD_SCENE:AddFragment(hud.fragment)
    HUD_UI_SCENE:AddFragment(hud.fragment)
end
