-- Entrada en Ajustes > Add-Ons (solo si LibAddonMenu-2.0 está instalada),
-- donaciones y ventana de bienvenida/novedades.

local NM = NirnhonedMetrics
local U = NM.Utils
local L = NM.L
local S = {}
NM.Settings = S

local DONATION_DEFAULT = 10000

-- Desde otro megaservidor el correo no llegaría al autor.
function S.CanDonate()
    return GetWorldName() == NM.authorServer
end

-- Abre el correo con el autor, el asunto y el oro ya rellenados; el jugador
-- revisa la cantidad y decide si lo envía.
function S.ComposeDonation()
    if IsUnitInCombat("player") then
        NM.Print(L.DONATE_COMBAT)
        return
    end
    local subject = string.format(L.DONATE_SUBJECT, NM.version)

    if IsInGamepadPreferredMode() then
        MAIL_MANAGER_GAMEPAD:GetSend():ComposeMailTo(NM.author, subject)
        return
    end

    SCENE_MANAGER:Show("mailSend")
    zo_callLater(function()
        ZO_MailSendToField:SetText(NM.author)
        ZO_MailSendSubjectField:SetText(subject)
        QueueMoneyAttachment(DONATION_DEFAULT)
        ZO_MailSendSendCurrency:OnBeginInput()
    end, 250)
end

---------------------------------------------------------------------------
-- Ventana de bienvenida (primera instalación) o de novedades (nueva versión)
---------------------------------------------------------------------------
local WELCOME_DIALOG = "NIRNHONEDMETRICS_WELCOME"

local function RegisterWelcomeDialog()
    ZO_Dialogs_RegisterCustomDialog(WELCOME_DIALOG, {
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons = {
            { text = L.SETTINGS, callback = function() S.Open() end },
            { text = GetString(SI_DIALOG_CLOSE) },
        },
    })
end

-- Se llama al entrar al mundo. Solo muestra algo si es la primera vez o si cambió la versión.
function S.ShowWelcomeIfNeeded()
    local sv = NM.sv
    local last = sv.lastVersion
    if last == NM.version then return end
    sv.lastVersion = NM.version

    local title, text
    if last == nil then
        title, text = L.WELCOME_TITLE, L.WELCOME_TEXT
    else
        title, text = string.format(L.UPDATE_TITLE, NM.version), L.CHANGELOG
    end
    ZO_Dialogs_ShowDialog(WELCOME_DIALOG, nil, { titleParams = { title }, mainTextParams = { text } })
end

local function CommandsText()
    return type(L.HELP) == "table" and table.concat(L.HELP, "\n") or ""
end

-- Botón de engranaje de la ventana.
function S.Open()
    LibAddonMenu2:OpenToPanel(S.panel)
end

---------------------------------------------------------------------------
-- Panel de LibAddonMenu
---------------------------------------------------------------------------
local function Refresh()
    NM.Meter.ApplySettings()
end

-- Casilla enlazada a NM.sv[key].
local function Checkbox(key, name, tooltip, extra)
    local option = {
        type = "checkbox",
        name = name,
        tooltip = tooltip,
        getFunc = function() return NM.sv[key] end,
        setFunc = function(v) NM.sv[key] = v; Refresh() end,
        default = NM.defaults[key],
    }
    for k, v in pairs(extra or {}) do option[k] = v end
    return option
end

local function Slider(key, name, min, max, step, tooltip)
    return {
        type = "slider",
        name = name,
        tooltip = tooltip,
        min = min, max = max, step = step or 1,
        getFunc = function() return NM.sv[key] end,
        setFunc = function(v) NM.sv[key] = v; Refresh() end,
        default = NM.defaults[key],
    }
end

-- Opacidad guardada como 0..1 y mostrada como 0..100.
local function AlphaSlider(key, name, min)
    return {
        type = "slider",
        name = name,
        min = min or 0, max = 100, step = 5,
        getFunc = function() return zo_round(NM.sv[key] * 100) end,
        setFunc = function(v) NM.sv[key] = v / 100; Refresh() end,
        default = zo_round(NM.defaults[key] * 100),
    }
end

local function Dropdown(key, name, choices, values, tooltip)
    return {
        type = "dropdown",
        name = name,
        tooltip = tooltip,
        choices = choices,
        choicesValues = values,
        getFunc = function() return NM.sv[key] end,
        setFunc = function(v) NM.sv[key] = v; Refresh() end,
        default = NM.defaults[key],
    }
end

local function ColorPicker(getTable, name, default, disabled)
    return {
        type = "colorpicker",
        name = name,
        getFunc = function() return U.Color(getTable()) end,
        setFunc = function(r, g, b, a)
            local c = getTable()
            c[1], c[2], c[3], c[4] = r, g, b, a
            Refresh()
        end,
        default = { r = default[1], g = default[2], b = default[3], a = default[4] },
        disabled = disabled,
    }
end

local function WindowSize(key, name, min, max)
    return {
        type = "slider",
        name = name,
        min = min, max = max, step = 5,
        getFunc = function() return NM.sv.window[key] end,
        setFunc = function(v)
            NM.sv.window[key] = v
            NM.Meter.ApplyPosition()
            Refresh()
        end,
        default = NM.defaults.window[key],
    }
end

local function ClassColorOptions()
    local controls = {}
    local notByClass = function() return NM.sv.colorMode ~= "class" end
    for _, classId in ipairs(NM.CLASS_IDS) do
        controls[#controls + 1] = ColorPicker(
            function()
                NM.sv.classColors[classId] = NM.sv.classColors[classId] or ZO_ShallowTableCopy(NM.defaults.classColors[classId])
                return NM.sv.classColors[classId]
            end,
            U.ClassName(classId), NM.defaults.classColors[classId], notByClass)
    end
    return controls
end

function S.Init()
    RegisterWelcomeDialog()

    local LAM = LibAddonMenu2
    local panelName = "NirnhonedMetricsOptions"
    S.panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Nirnhoned Metrics",
        displayName = NM.title,
        author = NM.author,
        version = NM.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local options = {
        { type = "description", text = L.SETTINGS_DESC },
    }

    local function Add(list)
        for _, option in ipairs(list) do options[#options + 1] = option end
    end

    Add({
        { type = "header", name = L.HEADER_WINDOW },
        {
            type = "checkbox",
            name = L.OPT_SHOWN,
            getFunc = function() return NM.sv.window.shown end,
            setFunc = function(v) NM.Meter.SetShown(v) end,
            default = true,
        },
        {
            type = "checkbox",
            name = L.OPT_LOCKED,
            tooltip = L.OPT_LOCKED_TT,
            getFunc = function() return NM.sv.window.locked end,
            setFunc = function(v) NM.Meter.SetLocked(v) end,
            default = false,
        },
        {
            type = "checkbox",
            name = L.OPT_COLLAPSED,
            tooltip = L.OPT_COLLAPSED_TT,
            getFunc = function() return NM.sv.window.collapsed end,
            setFunc = function(v) NM.Meter.SetCollapsed(v) end,
            default = false,
        },
        Dropdown("titleMode", L.OPT_TITLE, { L.TITLE_DEFAULT, L.TITLE_CUSTOM }, { "default", "custom" }),
        {
            type = "editbox",
            name = L.OPT_TITLE_TEXT,
            tooltip = L.OPT_TITLE_TEXT_TT,
            getFunc = function() return NM.sv.customTitle end,
            setFunc = function(v) NM.sv.customTitle = v; Refresh() end,
            default = NM.defaults.customTitle,
            disabled = function() return NM.sv.titleMode ~= "custom" end,
        },
        ColorPicker(function() return NM.sv.titleColor end, L.OPT_TITLE_COLOR, NM.defaults.titleColor,
            function() return NM.sv.titleMode ~= "custom" end),
        Checkbox("hideOutOfCombat", L.OPT_HIDE_OOC, L.OPT_HIDE_OOC_TT),
        Checkbox("hideInPvP", L.OPT_HIDE_PVP, L.OPT_HIDE_PVP_TT),
        WindowSize("width", L.OPT_WIDTH, 200, 900),
        WindowSize("height", L.OPT_HEIGHT, 54, 900),
        Slider("fontSize", L.OPT_FONT_SIZE, 10, 30),
        Slider("titleFontSize", L.OPT_TITLE_FONT_SIZE, 10, 28),
        Slider("rowHeight", L.OPT_ROW_HEIGHT, 14, 50, 1, L.OPT_ROW_HEIGHT_TT),
        Slider("rowSpacing", L.OPT_ROW_SPACING, 0, 6),
        AlphaSlider("bgAlpha", L.OPT_BG_ALPHA),
        AlphaSlider("barAlpha", L.OPT_BAR_ALPHA, 20),
        {
            type = "button",
            name = L.OPT_RESET_POSITION,
            width = "half",
            func = function() NM.Meter.ResetPosition() end,
        },

        { type = "header", name = L.HEADER_BARS },
        Dropdown("barStyle", L.OPT_BAR_STYLE,
            { L.STYLE_PROGRESS, L.STYLE_FLAT }, { "progress", "flat" }),
        Dropdown("colorMode", L.OPT_COLOR_MODE,
            { L.COLOR_CLASS, L.COLOR_SINGLE }, { "class", "single" }),
        ColorPicker(function() return NM.sv.barColor end, L.OPT_BAR_COLOR, NM.defaults.barColor),
        {
            type = "submenu",
            name = L.OPT_CLASS_COLORS,
            controls = ClassColorOptions(),
        },
        Dropdown("abilityColorMode", L.OPT_ABILITY_COLOR,
            { L.COLOR_DAMAGE_TYPE, L.COLOR_SINGLE }, { "damageType", "single" }),
        Checkbox("highlightSelf", L.OPT_HIGHLIGHT_SELF),

        { type = "header", name = L.HEADER_TEXT },
        Checkbox("showRank", L.OPT_SHOW_RANK),
        Checkbox("showIcon", L.OPT_SHOW_ICON),
        Checkbox("showTotal", L.OPT_SHOW_TOTAL),
        Checkbox("showDps", L.OPT_SHOW_DPS),
        Checkbox("showPercent", L.OPT_SHOW_PERCENT),
        Dropdown("nameFormat", L.OPT_NAME_FORMAT,
            { L.NAME_CHARACTER, L.NAME_ACCOUNT }, { "character", "account" }),

        { type = "header", name = L.HEADER_DATA },
        Dropdown("metric", L.OPT_METRIC, { L.METRIC_DAMAGE, L.METRIC_HEALING }, { "damage", "healing" }),
        Dropdown("mode", L.OPT_MODE, { L.MODE_GROUP, L.MODE_ABILITIES }, { "group", "abilities" }),
        Checkbox("includePets", L.OPT_PETS, L.OPT_PETS_TT),
        Slider("combatEndDelay", L.OPT_END_DELAY, 0, 10, 1, L.OPT_END_DELAY_TT),
        Slider("historySize", L.OPT_HISTORY, 1, 30),
        Checkbox("shareDps", L.OPT_SHARE, L.OPT_SHARE_TT, { requiresReload = true }),
        Checkbox("showRest", L.OPT_SHOW_REST, L.OPT_SHOW_REST_TT),

        { type = "header", name = L.HELP_USAGE_HEADER },
        { type = "description", text = L.HELP_USAGE },
        { type = "header", name = L.HELP_TIPS_HEADER },
        { type = "description", text = L.HELP_TIPS },
        { type = "header", name = L.HELP_COMMANDS_HEADER },
        { type = "description", text = CommandsText() },
    })

    -- Solo en el megaservidor del autor.
    if S.CanDonate() then
        Add({
            { type = "header", name = L.DONATE_HEADER },
            { type = "description", text = string.format(L.DONATE_DESC, NM.author) },
            {
                type = "button",
                name = L.DONATE_BUTTON,
                width = "half",
                func = S.ComposeDonation,
            },
        })
    end

    LAM:RegisterOptionControls(panelName, options)
end
