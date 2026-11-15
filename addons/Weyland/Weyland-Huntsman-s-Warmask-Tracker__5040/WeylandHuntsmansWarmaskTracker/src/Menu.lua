--[[
    Settings menu (LibAddonMenu-2.0): icon gallery, live preview and options.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local T = HMK.T
local ICONS, FONTS, OUTLINES, DEFAULTS = HMK.ICONS, HMK.FONTS, HMK.OUTLINES, HMK.DEFAULTS
local ICON_U_LEFT, ICON_U_RIGHT = HMK.ICON_U_LEFT, HMK.ICON_U_RIGHT
local ICON_V_TOP, ICON_V_BOTTOM = HMK.ICON_V_TOP, HMK.ICON_V_BOTTOM
local FindById, AvailableSounds, PlayWarnSound = HMK.FindById, HMK.AvailableSounds, HMK.PlayWarnSound
local CreateMarkView, ApplyViewStyle, ApplyViewColors = HMK.CreateMarkView, HMK.ApplyViewStyle, HMK.ApplyViewColors
local ApplyMarkStyle = HMK.ApplyMarkStyle

local function FontChoices()
    local names, values = {}, {}
    for _, f in ipairs(FONTS) do names[#names + 1] = f.label; values[#values + 1] = f.id end
    return names, values
end

local function OutlineChoices()
    local names, values = {}, {}
    for _, o in ipairs(OUTLINES) do names[#names + 1] = o.label; values[#values + 1] = o.id end
    return names, values
end

---------------------------------------------------------------------------
-- Settings widgets: icon gallery + live preview (custom LAM controls)
---------------------------------------------------------------------------
local panelUI = {}   -- filled when LAM creates the controls (first time the panel is opened)

local GALLERY_THUMB, GALLERY_GAP, GALLERY_COLS = 92, 24, 4
local GALLERY_ROW_H = GALLERY_THUMB + 32
local GALLERY_ROWS = math.ceil(#ICONS / GALLERY_COLS)
local GALLERY_HEIGHT = 6 + GALLERY_ROWS * GALLERY_ROW_H
local PREVIEW_HEIGHT = 200
local PREVIEW_ICON_MAX = 100   -- the preview shrinks big icons so they fit the panel

local function HexColor(c)
    return string.format("%02X%02X%02X", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255))
end

local function RefreshPanelWidgets()
    local cfg = HMK.sv and HMK.sv.mark
    if not cfg then return end
    local c = cfg.color

    local g = panelUI.gallery
    if g then
        for _, cell in ipairs(g.cells) do
            local selected = (cell.iconId == cfg.icon)
            if selected then
                cell.border:SetColor(1, 0.82, 0.3, 1)
                cell.label:SetColor(1, 0.82, 0.3, 1)
            elseif cell.hover then
                cell.border:SetColor(0.7, 0.7, 0.75, 1)
                cell.label:SetColor(0.9, 0.9, 0.9, 1)
            else
                cell.border:SetColor(0.3, 0.3, 0.35, 1)
                cell.label:SetColor(0.65, 0.65, 0.65, 1)
            end
            cell.art:SetColor(c.r, c.g, c.b, c.a)   -- every thumbnail shows the colour you picked
        end
    end

    local p = panelUI.preview
    if p then
        local scale = math.min(1, PREVIEW_ICON_MAX / cfg.size)
        local px = zo_round(cfg.size * scale)
        p.host:SetDimensions(px, px)
        ApplyViewStyle(p.view, cfg, scale)
        ApplyViewColors(p.view, cfg, false)
        p.timer:SetText("59")
        p.timer:SetHidden(cfg.timerMode == "hidden")

        local scaled = scale < 1 and string.format(T("PREVIEW_SCALE"), zo_round(scale * 100)) or ""
        p.info:SetText(string.format(T("PREVIEW_INFO"),
            FindById(ICONS, cfg.icon).label, cfg.size, scaled, HexColor(c), HexColor(c)))
    end
end
HMK.RefreshPanelWidgets = RefreshPanelWidgets

local function SelectIcon(id)
    HMK.sv.mark.icon = id
    ApplyMarkStyle()   -- also refreshes the widgets
end

local function CreateGallery(ctl)
    local wm = WINDOW_MANAGER
    local totalW = GALLERY_COLS * GALLERY_THUMB + (GALLERY_COLS - 1) * GALLERY_GAP
    local g = { cells = {} }

    for i, ic in ipairs(ICONS) do
        local cell = wm:CreateControl(nil, ctl, CT_CONTROL)
        cell:SetDimensions(GALLERY_THUMB, GALLERY_THUMB + 26)
        local col, row = (i - 1) % GALLERY_COLS, math.floor((i - 1) / GALLERY_COLS)
        cell:SetAnchor(TOPLEFT, ctl, TOP, -totalW / 2 + col * (GALLERY_THUMB + GALLERY_GAP), 6 + row * GALLERY_ROW_H)
        cell:SetMouseEnabled(true)
        cell.iconId = ic.id
        cell.hover = false

        -- no texture file = solid colour: a border square with a darker square inside it
        local border = wm:CreateControl(nil, cell, CT_TEXTURE)
        border:SetDimensions(GALLERY_THUMB, GALLERY_THUMB)
        border:SetAnchor(TOPLEFT, cell, TOPLEFT, 0, 0)
        local inner = wm:CreateControl(nil, cell, CT_TEXTURE)
        inner:SetAnchor(TOPLEFT, border, TOPLEFT, 2, 2)
        inner:SetAnchor(BOTTOMRIGHT, border, BOTTOMRIGHT, -2, -2)
        inner:SetColor(0.04, 0.04, 0.06, 1)

        local art = wm:CreateControl(nil, cell, CT_TEXTURE)
        art:SetDimensions(GALLERY_THUMB - 10, GALLERY_THUMB - 10)
        art:SetAnchor(CENTER, border, CENTER, 0, 0)
        art:SetTexture(ic.path)
        art:SetTextureCoords(ICON_U_LEFT, ICON_U_RIGHT, ICON_V_TOP, ICON_V_BOTTOM)

        local label = wm:CreateControl(nil, cell, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(TOP, border, BOTTOM, 0, 4)
        label:SetText(ic.label)

        cell.border, cell.art, cell.label = border, art, label

        cell:SetHandler("OnMouseUp", function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SelectIcon(ic.id) end
        end)
        cell:SetHandler("OnMouseEnter", function() cell.hover = true; RefreshPanelWidgets() end)
        cell:SetHandler("OnMouseExit", function() cell.hover = false; RefreshPanelWidgets() end)

        g.cells[i] = cell
    end

    panelUI.gallery = g
    RefreshPanelWidgets()
end

-- The settings preview uses the same icon/timer view and render helpers as the HUD.
local function CreatePreview(ctl)
    local wm = WINDOW_MANAGER
    local p = {}

    local bg = wm:CreateControl(nil, ctl, CT_TEXTURE)
    bg:SetAnchorFill(ctl)
    bg:SetColor(0.34, 0.35, 0.40, 1)

    p.info = wm:CreateControl(nil, ctl, CT_LABEL)
    p.info:SetFont("ZoFontGame")
    p.info:SetColor(0.8, 0.8, 0.8, 1)
    p.info:SetAnchor(TOP, ctl, TOP, 0, 8)

    p.host = wm:CreateControl(nil, ctl, CT_CONTROL)
    p.host:SetAnchor(CENTER, ctl, TOP, 0, 112)
    p.view = CreateMarkView(p.host)
    p.icon = p.view.icon
    p.timer = p.view.timer

    panelUI.preview = p
    RefreshPanelWidgets()
end

local function BuildMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = ADDON .. "Panel"
    HMK.panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "Weyland Huntsman's Warmask Tracker",
        displayName = "Weyland Huntsman's Warmask Tracker",
        author = "Weyland",
        version = HMK.version,
        slashCommand = "/hmarkmenu",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
        if panel == HMK.panel then RefreshPanelWidgets() end
    end)
    local m = HMK.sv.mark
    local dm = DEFAULTS.mark
    local fontNames, fontValues = FontChoices()
    local outNames, outValues = OutlineChoices()

    local function color(name, tbl, key, def, apply, disabled, tooltip)
        return {
            type = "colorpicker", name = name, tooltip = tooltip, width = "full",
            getFunc = function() local c = tbl[key]; return c.r, c.g, c.b, c.a end,
            setFunc = function(rr, gg, bb, aa) tbl[key] = { r = rr, g = gg, b = bb, a = aa }; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function slider(name, tbl, key, def, mn, mx, step, apply, disabled)
        return {
            type = "slider", name = name, min = mn, max = mx, step = step, width = "full",
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function check(name, tbl, key, def, apply, tooltip, disabled)
        return {
            type = "checkbox", name = name, tooltip = tooltip, width = "full",
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end
    local function dropdown(name, tbl, key, def, names, values, apply, tooltip, disabled)
        return {
            type = "dropdown", name = name, tooltip = tooltip, width = "full",
            choices = names, choicesValues = values,
            getFunc = function() return tbl[key] end,
            setFunc = function(v) tbl[key] = v; apply() end,
            default = def, disabled = disabled,
        }
    end

    local function applyMark() ApplyMarkStyle() end

    local timerHidden = function() return m.timerMode == "hidden" end
    local warnOff = function() return not m.warnEnabled end
    local warnColorOff = function() return not m.warnEnabled or (not m.warnIcon and not m.warnTimer) end
    local availableSounds = AvailableSounds()
    local noSounds = #availableSounds == 0
    local soundOff = function() return not m.soundEnabled or noSounds end
    local soundNames, soundValues = {}, {}
    for _, snd in ipairs(availableSounds) do soundNames[#soundNames + 1] = snd.label; soundValues[#soundValues + 1] = snd.id end
    if noSounds then soundNames, soundValues = { T("NO_SOUNDS_AVAILABLE") }, { m.sound } end

    LAM:RegisterOptionControls(panelName, {
        { type = "description", title = nil, width = "full",
          text = T("MENU_DESCRIPTION") },
        { type = "description", title = T("REPOSITION_HEADER"), width = "full",
          text = T("REPOSITION_DESCRIPTION") },
        {
            type = "button", name = T("BUTTON_MOVE"), width = "full",
            tooltip = T("TOOLTIP_MOVE"),
            func = function() HMK.SetMoveMode(not HMK.unlocked) end,
        },

        { type = "header", name = T("HEADER_MARK_ICON") },
        {   -- click a picture to choose it; every thumbnail is drawn in the colour you picked
            type = "custom", reference = ADDON .. "_Gallery", width = "full",
            minHeight = function() return GALLERY_HEIGHT end,
            maxHeight = function() return GALLERY_HEIGHT end,
            createFunc = CreateGallery,
            refreshFunc = RefreshPanelWidgets,
        },
        {   -- live preview: icon, size, colour and timer exactly as they look on screen
            type = "custom", reference = ADDON .. "_Preview", width = "full",
            minHeight = function() return PREVIEW_HEIGHT end,
            maxHeight = function() return PREVIEW_HEIGHT end,
            createFunc = CreatePreview,
            refreshFunc = RefreshPanelWidgets,
        },
        slider(T("LABEL_ICON_SIZE"), m, "size", dm.size, 32, 120, 1, applyMark),
        color(T("LABEL_ICON_COLOR"), m, "color", dm.color, applyMark, nil,
            T("TIP_ICON_COLOR")),

        { type = "header", name = T("HEADER_TIMER") },
        dropdown(T("LABEL_TIMER_POSITION"), m, "timerMode", dm.timerMode,
            { T("CHOICE_TIMER_CENTRE"), T("CHOICE_TIMER_EDGE"), T("CHOICE_HIDDEN") },
            { "inside", "edge", "hidden" }, applyMark,
            T("TIP_TIMER_EDGE")),
        slider(T("LABEL_TIMER_OFFSET"), m, "timerOffsetY", dm.timerOffsetY, -60, 60, 1, applyMark, timerHidden),
        slider(T("LABEL_TIMER_FONT_SIZE"), m, "fontSize", dm.fontSize, 10, 80, 1, applyMark, timerHidden),
        color(T("LABEL_TIMER_COLOR"), m, "timerColor", dm.timerColor, applyMark, timerHidden),
        dropdown(T("LABEL_TIMER_FONT"), m, "font", dm.font, fontNames, fontValues, applyMark, nil, timerHidden),
        dropdown(T("LABEL_TIMER_OUTLINE"), m, "outline", dm.outline, outNames, outValues, applyMark, nil, timerHidden),
        check(T("LABEL_TIMER_TENTHS"), m, "tenths", dm.tenths, applyMark, nil, timerHidden),

        { type = "header", name = T("HEADER_WARNING") },
        check(T("LABEL_WARN_ENABLED"), m, "warnEnabled", dm.warnEnabled, applyMark),
        slider(T("LABEL_WARN_SECONDS"), m, "warnSeconds", dm.warnSeconds, 1, 60, 1, applyMark, warnOff),
        color(T("LABEL_WARN_COLOR"), m, "warnColor", dm.warnColor, applyMark, warnColorOff,
            T("TIP_WARN_COLOR")),
        check(T("LABEL_WARN_ICON"), m, "warnIcon", dm.warnIcon, applyMark, nil, warnOff),
        check(T("LABEL_WARN_TIMER"), m, "warnTimer", dm.warnTimer, applyMark, nil, warnOff),

        { type = "header", name = T("HEADER_SOUND") },
        check(T("LABEL_SOUND_ENABLED"), m, "soundEnabled", dm.soundEnabled, applyMark,
            T("TIP_SOUND_ENABLED")),
        {
            type = "dropdown", name = T("LABEL_SOUND_REPEAT"), width = "full",
            choices = { T("CHOICE_ONCE"), T("CHOICE_EVERY_1"), T("CHOICE_EVERY_2") },
            choicesValues = { 0, 1, 2 },
            getFunc = function() return m.soundInterval end,
            setFunc = function(v) m.soundInterval = v; applyMark() end,
            default = dm.soundInterval, disabled = soundOff,
            tooltip = T("TIP_SOUND_REPEAT"),
        },
        {
            type = "dropdown", name = T("LABEL_SOUND"), width = "full",
            choices = soundNames, choicesValues = soundValues,
            getFunc = function() return m.sound end,
            setFunc = function(v) m.sound = v; PlayWarnSound(v) end,   -- plays a sample when you pick it
            default = dm.sound, disabled = soundOff,
            tooltip = T("TIP_SOUND_ONLY_GAME"),
        },
        {
            type = "button", name = T("BUTTON_TEST_SOUND"), width = "full",
            func = function() PlayWarnSound(m.sound) end, disabled = soundOff,
        },

        { type = "header", name = T("HEADER_SUPPORT") },
        { type = "description", text = T("TEXT_SUPPORT") },

    })
end

HMK.BuildMenu = BuildMenu
