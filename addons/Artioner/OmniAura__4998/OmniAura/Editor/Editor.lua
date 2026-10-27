-- Editor gráfico: lista de auras a la izquierda y panel de propiedades a la derecha.
-- El formulario se genera a partir de esquemas (listas de campos), así que añadir
-- una opción nueva es añadir una línea a la tabla correspondiente.

local OA = OmniAura
local U = OA.Utils
local L = OA.L
local WM = WINDOW_MANAGER

local Ed = {
    pools = {}, active = {}, listRows = {},
    cursorY = 0, counter = 0,
    selectedId = nil, trigIndex = 1,
}
OA.Editor = Ed

local SCENE_NAME = "OmniAuraEditor"
local WIN_W, WIN_H = 820, 660
local LIST_W = 240
local ROW_H = 32
local HEADER_H = 40
local LABEL_W = 190
local WIDGET_W = 300
local GOLD = { 0.77, 0.69, 0.46, 1 }
local TRASH = {
    up = "EsoUI/Art/Inventory/inventory_tabIcon_trash_up.dds",
    over = "EsoUI/Art/Inventory/inventory_tabIcon_trash_over.dds",
    down = "EsoUI/Art/Inventory/inventory_tabIcon_trash_down.dds",
}
-- Plegar (flecha arriba) / desplegar (flecha abajo)
local ARROW_UP = {
    up = "EsoUI/Art/Buttons/scrollbox_upArrow_up.dds",
    over = "EsoUI/Art/Buttons/scrollbox_upArrow_over.dds",
    down = "EsoUI/Art/Buttons/scrollbox_upArrow_down.dds",
}
local ARROW_DOWN = {
    up = "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds",
    over = "EsoUI/Art/Buttons/scrollbox_downArrow_over.dds",
    down = "EsoUI/Art/Buttons/scrollbox_downArrow_down.dds",
}
local PLUS = {
    up = "EsoUI/Art/Buttons/plus_up.dds",
    over = "EsoUI/Art/Buttons/plus_over.dds",
    down = "EsoUI/Art/Buttons/plus_down.dds",
}
local GOLD_ICON = "EsoUI/Art/currency/currency_gold.dds"

ZO_CreateStringId("SI_BINDING_NAME_OMNIAURA_TOGGLE_EDITOR", L.BINDING_TOGGLE)

---------------------------------------------------------------------------
-- Esquemas de campos.  choices = { {valor, "texto"}, ... }
---------------------------------------------------------------------------
local UNIT_CHOICES = {
    { "player", L.UNIT_PLAYER }, { "reticleover", L.UNIT_TARGET },
    { "boss1", string.format(L.UNIT_BOSS, 1) }, { "boss2", string.format(L.UNIT_BOSS, 2) },
}
local TRIGGER_TYPES = {
    { "buff", L.TRIG_BUFF }, { "resource", L.TRIG_RESOURCE },
    { "proc", L.TRIG_PROC }, { "combat", L.TRIG_COMBAT },
}
local DISPLAY_TYPES = {
    { "icon", L.DISP_ICON }, { "icontext", L.DISP_ICON_TEXT }, { "bar", L.DISP_BAR }, { "text", L.DISP_TEXT },
}
local POWER_CHOICES = {
    { "health", L.POWER_HEALTH }, { "magicka", L.POWER_MAGICKA },
    { "stamina", L.POWER_STAMINA }, { "ultimate", L.POWER_ULTIMATE },
}
local OP_CHOICES = {
    { "<", L.OP_LT }, { "<=", L.OP_LE }, { ">", L.OP_GT }, { ">=", L.OP_GE },
}

-- Sonidos ofrecidos en el selector (solo se muestran los que existen en esta versión del juego).
local SOUND_KEYS = {
    "ABILITY_ULTIMATE_READY", "ABILITY_SYNERGY_READY", "ABILITY_COMPANION_ULTIMATE_READY",
    "NEW_NOTIFICATION", "GENERAL_ALERT_ERROR", "DUEL_START", "DUEL_WON", "LEVEL_UP",
    "CHAMPION_POINT_GAINED", "SKILL_GAINED", "QUEST_COMPLETED", "ACHIEVEMENT_AWARDED",
    "TELVAR_GAINED", "BOOK_ACQUIRED", "COLLECTIBLE_UNLOCKED", "OBJECTIVE_DISCOVERED",
    "ENLIGHTENED_STATE_GAINED", "LOCKPICKING_BREAK", "LOCKPICKING_SUCCESS_CELEBRATION",
    "RAID_TRIAL_COMPLETED", "RAID_TRIAL_FAILED", "MAP_PING", "POSITIVE_CLICK", "NEGATIVE_CLICK",
    "DEFAULT_CLICK", "COUNTDOWN_TICK",
}

local GENERAL_FIELDS = {
    { key = "name", label = L.F_NAME, kind = "text", required = true },
    { key = "enabled", label = L.F_ENABLED, kind = "bool", default = true },
    { key = "scope", label = L.F_SCOPE, kind = "choice", default = "account",
      choices = function()
          return {
              { "account", L.SCOPE_ACCOUNT },
              { "character", string.format(L.SCOPE_CHARACTER, zo_strformat("<<1>>", GetUnitName("player"))) },
          }
      end },
    { key = "load.combat", label = L.F_LOAD, kind = "choice", default = "any",
      choices = { { "any", L.LOAD_ANY }, { "in", L.LOAD_IN }, { "out", L.LOAD_OUT } } },
    { key = "sound", label = L.F_SOUND, kind = "sound" },
}
local LOGIC_FIELD = { key = "logic", label = L.F_LOGIC, kind = "choice", default = "all",
    choices = { { "all", L.LOGIC_ALL }, { "any", L.LOGIC_ANY } } }

local TRIGGER_TYPE_FIELD = { key = "type", label = L.F_TYPE, kind = "choice", choices = TRIGGER_TYPES, rerender = true }
-- Cada campo puede tener show(ctx): si devuelve false, no se muestra porque no aplica.
-- ctx.caps describe qué datos aportan los triggers del aura (ver Capabilities).
local function HasTimeOrValue(ctx) return ctx.caps.time or ctx.caps.value end
local function HasStacks(ctx) return ctx.caps.stacks end
local function HasProgress(ctx) return ctx.caps.progress end
local function HasMissing(ctx) return ctx.caps.missing end
local function BarShowsIcon(ctx) return ctx.d.showIcon ~= false end

local TRIGGER_FIELDS = {
    buff = {
        { key = "unit", label = L.F_UNIT, kind = "choice", choices = UNIT_CHOICES, default = "player", rerender = true },
        { key = "spells", kind = "spells", mode = "buff" },
        { key = "onlyMine", label = L.F_ONLY_MINE, kind = "bool", default = false, options = true },
        { key = "show", label = L.F_SHOW, kind = "choice", default = "active", rerender = true, options = true,
          choices = { { "active", L.SHOW_ACTIVE }, { "missing", L.SHOW_MISSING } } },
        { key = "minStacks", label = L.F_MIN_STACKS, kind = "number", options = true,
          show = function(ctx) return ctx.trig.show ~= "missing" end },
    },
    resource = {
        { key = "unit", label = L.F_UNIT, kind = "choice", choices = UNIT_CHOICES, default = "player" },
        { key = "power", label = L.F_POWER, kind = "choice", choices = POWER_CHOICES, default = "health" },
        { key = "op", label = L.F_OP, kind = "choice", choices = OP_CHOICES, default = "<" },
        { key = "value", label = L.F_VALUE, kind = "number", default = 0 },
        { key = "percent", label = L.F_PERCENT, kind = "bool", default = false },
    },
    proc = {
        { key = "spells", kind = "spells", mode = "proc" },
        { key = "duration", label = L.F_DURATION, kind = "number", default = 10, options = true },
        { key = "source", label = L.F_SOURCE, kind = "choice", default = "player", options = true,
          choices = { { "player", L.SOURCE_PLAYER }, { "any", L.SOURCE_ANY } } },
        { key = "refresh", label = L.F_REFRESH, kind = "bool", default = false, options = true },
    },
    combat = {
        { key = "state", label = L.F_STATE, kind = "choice", default = "in",
          choices = { { "in", L.IN_COMBAT }, { "out", L.OUT_OF_COMBAT } } },
    },
}

local DISPLAY_TYPE_FIELD = { key = "type", label = L.F_TYPE, kind = "choice", choices = DISPLAY_TYPES, default = "icon", rerender = true }
local DISPLAY_FIELDS = {
    icon = {
        { key = "text", label = L.F_TEXT_CENTER, kind = "text", default = "{time}", show = HasTimeOrValue },
        { key = "text2", label = L.F_TEXT_CORNER, kind = "text", default = "{stacks}", show = HasStacks },
        { key = "color", label = L.F_ICON_COLOR, kind = "color", default = { 1, 1, 1, 1 } },
        { key = "textColor", label = L.F_TEXT_COLOR, kind = "color", default = { 1, 1, 1, 1 },
          show = function(ctx) return ctx.d.type == "icontext" or HasTimeOrValue(ctx) or HasStacks(ctx) end },
        { key = "desaturate", label = L.F_DESATURATE, kind = "bool", default = true, show = HasMissing },
        { key = "shade", label = L.F_SHADE, kind = "bool", default = true, show = HasProgress },
        { key = "border", label = L.F_BORDER, kind = "bool", default = true },
    },
    icontext = {
        { key = "textTop", label = L.F_TEXT_TOP, kind = "text", default = "{name}" },
    },
    bar = {
        { key = "showIcon", label = L.F_SHOW_ICON, kind = "bool", default = true, rerender = true },
        { key = "desaturate", label = L.F_DESATURATE, kind = "bool", default = true,
          show = function(ctx) return HasMissing(ctx) and BarShowsIcon(ctx) end },
        { key = "text", label = L.F_TEXT_LEFT, kind = "text", default = "{name}" },
        { key = "text2", label = L.F_TEXT_RIGHT, kind = "text", default = "{time}", show = HasTimeOrValue },
        { key = "color", label = L.F_BAR_COLOR, kind = "color", default = { 0.2, 0.6, 1, 0.9 } },
        { key = "bgColor", label = L.F_BG_COLOR, kind = "color", default = { 0, 0, 0, 0.6 } },
        { key = "textColor", label = L.F_TEXT_COLOR, kind = "color", default = { 1, 1, 1, 1 } },
    },
    text = {
        { key = "text", label = L.F_TEXT, kind = "text", default = "{name} {time}" },
        { key = "textColor", label = L.F_TEXT_COLOR, kind = "color", default = { 1, 1, 1, 1 } },
    },
}

-- Icono + texto = los campos del icono más el texto de encima.
for _, f in ipairs(DISPLAY_FIELDS.icon) do table.insert(DISPLAY_FIELDS.icontext, f) end

-- Plantillas del desplegable "+ Nueva aura..."
local TEMPLATES = {
    { L.TPL_BUFF, function()
        return L.NAME_NEW_BUFF, { { type = "buff", unit = "player", spells = {} } }, { type = "icon" }
    end },
    { L.TPL_DEBUFF, function()
        return L.NAME_NEW_DEBUFF, { { type = "buff", unit = "reticleover", onlyMine = true, spells = {} } }, { type = "icon" }
    end },
    { L.TPL_MISSING, function()
        return L.NAME_MISSING, { { type = "buff", unit = "player", show = "missing", spells = {} } }, { type = "icon" }
    end },
    { L.TPL_RESOURCE, function()
        return L.NAME_LOW_HEALTH, { { type = "resource", unit = "player", power = "health", op = "<", value = 50, percent = true } },
            { type = "bar", width = 200, height = 20, showIcon = false, text = "{name}", text2 = "{percent}%" }
    end },
    { L.TPL_PROC, function()
        return L.NAME_NEW_PROC, { { type = "proc", spells = {}, duration = 10, source = "player" } }, { type = "icon" }
    end },
    { L.TPL_COMBAT, function()
        return L.IN_COMBAT, { { type = "combat", state = "in" } },
            { type = "text", size = 26, text = "{name}", textColor = { 1, 0.3, 0.3, 1 } }
    end },
}

local function ChoiceLabel(choices, value)
    for _, c in ipairs(choices) do
        if c[1] == value then return c[2] end
    end
    return tostring(value or "")
end

-- "ABILITY_ULTIMATE_READY" -> "Ability ultimate ready"
local function PrettyKey(key)
    local s = zo_strlower(key):gsub("_", " ")
    return s:sub(1, 1):upper() .. s:sub(2)
end

local function IconText(icon, text)
    if icon then return zo_iconFormat(icon, 22, 22) .. " " .. text end
    return text
end

---------------------------------------------------------------------------
-- Filas del formulario (se reutilizan desde un pool por tipo)
---------------------------------------------------------------------------
local function NewRowBase()
    Ed.counter = Ed.counter + 1
    local name = "OmniAuraEditorRow" .. Ed.counter
    local row = WM:CreateControl(name, Ed.formChild, CT_CONTROL)
    row:SetDimensions(LABEL_W + WIDGET_W, ROW_H)

    local label = WM:CreateControl(name .. "Label", row, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(0.85, 0.85, 0.85, 1)
    label:SetDimensions(LABEL_W - 10, ROW_H)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    row.label = label
    return row, name
end

-- Botón con icono del juego (normal / ratón encima / pulsado).
local function IconButton(name, parent, size, icons, onClick)
    local b = WM:CreateControl(name, parent, CT_BUTTON)
    b:SetDimensions(size, size)
    b.SetIcons = function(self, set)
        self:SetNormalTexture(set.up)
        self:SetMouseOverTexture(set.over)
        self:SetPressedTexture(set.down)
    end
    if icons then b:SetIcons(icons) end
    b:SetHandler("OnClicked", function() if onClick then onClick() end end)
    return b
end

local factories = {}

function factories.header()
    local row = NewRowBase()
    row.height = HEADER_H
    row:SetHeight(HEADER_H)
    row.label:SetFont("ZoFontWinH4")
    row.label:SetColor(unpack(GOLD))
    row.label:SetDimensions(LABEL_W + WIDGET_W, HEADER_H)
    row.label:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    return row
end

function factories.subheader()
    local row = NewRowBase()
    row.height = 36
    row:SetHeight(36)
    row.label:SetFont("ZoFontWinH5")
    row.label:SetColor(0.9, 0.85, 0.7, 1)
    row.label:SetDimensions(LABEL_W + WIDGET_W, 36)
    row.label:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    return row
end

function factories.note()
    local row = NewRowBase()
    row.label:SetFont("ZoFontGameSmall")
    row.label:SetColor(0.6, 0.6, 0.6, 1)
    row.label:SetDimensions(LABEL_W + WIDGET_W, ROW_H)
    return row
end

function factories.edit()
    local row, name = NewRowBase()
    local bg = WM:CreateControlFromVirtual(name .. "Bg", row, "ZO_EditBackdrop")
    bg:SetDimensions(WIDGET_W, 26)
    bg:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    local edit = WM:CreateControlFromVirtual(name .. "Edit", bg, "ZO_DefaultEditForBackdrop")
    edit:SetMaxInputChars(500)
    edit:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    edit:SetHandler("OnFocusLost", function(self)
        if row.onCommit then row.onCommit(self:GetText()) end
    end)
    row.edit = edit
    return row
end

function factories.choice()
    local row, name = NewRowBase()
    local container = WM:CreateControlFromVirtual(name .. "Combo", row, "ZO_ComboBox")
    container:SetDimensions(WIDGET_W, 28)
    container:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    row.combo = ZO_ComboBox_ObjectFromContainer(container)
    row.combo:SetSortsItems(false)
    return row
end

function factories.bool()
    local row, name = NewRowBase()
    local check = WM:CreateControlFromVirtual(name .. "Check", row, "ZO_CheckButton")
    check:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    ZO_CheckButton_SetToggleFunction(check, function(_, checked)
        if row.onCommit then row.onCommit(checked) end
    end)
    row.check = check
    return row
end

function factories.color()
    local row, name = NewRowBase()
    local border = OA.Display.Solid(name .. "SwatchBorder", row, 0, 0, 0, 1)
    border:SetDimensions(48, 24)
    border:SetAnchor(LEFT, row, LEFT, LABEL_W, 0)
    -- Toda la fila abre el selector (el botón "Por defecto" tiene su propio clic).
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and row.onClick then row.onClick() end
    end)
    local swatch = OA.Display.Solid(name .. "Swatch", border, 1, 1, 1, 1)
    swatch:SetAnchor(TOPLEFT, border, TOPLEFT, 2, 2)
    swatch:SetAnchor(BOTTOMRIGHT, border, BOTTOMRIGHT, -2, -2)
    row.swatch = swatch

    local reset = WM:CreateControlFromVirtual(name .. "Reset", row, "ZO_DefaultButton")
    reset:SetDimensions(140, 28)
    reset:SetText(L.COLOR_DEFAULT)
    reset:SetAnchor(LEFT, border, RIGHT, 12, 0)
    reset:SetHandler("OnClicked", function()
        if row.onReset then row.onReset() end
    end)
    return row
end

-- Un efecto: icono + nombre + botón a la derecha (papelera para quitar, + para añadir).
function factories.spell()
    local row, name = NewRowBase()
    row.icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(26, 26)
    row.icon:SetAnchor(LEFT, row, LEFT, 10, 0)

    row.label:ClearAnchors()
    row.label:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)
    row.label:SetDimensions(LABEL_W + WIDGET_W - 90, ROW_H)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.label:SetColor(1, 1, 1, 1)

    row.action = IconButton(name .. "Action", row, 30, nil, function()
        if row.onClick then row.onClick() end
    end)
    row.action:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    return row
end

function factories.buttons()
    local row, name = NewRowBase()
    row.height = ROW_H + 8
    row:SetHeight(row.height)
    row.buttons = {}
    for i = 1, 3 do
        local b = WM:CreateControlFromVirtual(name .. "B" .. i, row, "ZO_DefaultButton")
        b:SetDimensions(160, 30)
        b:SetAnchor(LEFT, row, LEFT, (i - 1) * 165, 4)
        b:SetHandler("OnClicked", function()
            if b.onClick then b.onClick(b) end
        end)
        row.buttons[i] = b
    end
    return row
end

local function AcquireRow(kind)
    local pool = Ed.pools[kind]
    if not pool then
        pool = {}
        Ed.pools[kind] = pool
    end
    local row = table.remove(pool) or factories[kind]()
    row.kind = kind
    row.onCommit, row.onClick, row.onReset = nil, nil, nil
    row:SetHidden(false)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, Ed.formChild, TOPLEFT, 0, Ed.cursorY)
    Ed.cursorY = Ed.cursorY + (row.height or ROW_H)
    Ed.active[#Ed.active + 1] = row
    return row
end

local function ReleaseRows()
    for _, row in ipairs(Ed.active) do
        -- Si un campo tenía el foco, se guarda antes de reciclar la fila.
        if row.edit and row.edit:HasFocus() then row.edit:LoseFocus() end
        row.onCommit, row.onClick, row.onReset = nil, nil, nil
        row:SetHidden(true)
        table.insert(Ed.pools[row.kind], row)
    end
    Ed.active = {}
    Ed.cursorY = 0
    Ed.renderToken = (Ed.renderToken or 0) + 1
end

---------------------------------------------------------------------------
-- Guardado de cambios
---------------------------------------------------------------------------
local function Changed(rerender)
    OA.Engine.Rebuild()
    Ed.RefreshList()
    if rerender then Ed.RequestRender() end
end

local function Commit(aura, path, value, rerender)
    if path == "scope" then
        OA.Engine.SetScope(aura, value)
    else
        U.SetPath(aura, path, value)
    end
    if path == "name" then aura.autoName = nil end
    Changed(rerender)
end

local function FieldValue(aura, path, f)
    local v = U.GetPath(aura, path)
    if v == nil then v = f.default end
    return v
end

---------------------------------------------------------------------------
-- Constructores de filas
---------------------------------------------------------------------------
local function SubHeader(text)
    local row = AcquireRow("subheader")
    row.label:SetText(text)
end

local function Header(text)
    local row = AcquireRow("header")
    row.label:SetText(text)
end

local function Note(text)
    local row = AcquireRow("note")
    row.label:SetText(text)
end

local function ChoiceRow(label, choices, current, onSelect, placeholder)
    local row = AcquireRow("choice")
    row.label:SetText(label)
    local combo = row.combo
    combo:ClearItems()
    local selected = placeholder
    for _, c in ipairs(choices) do
        local value, text = c[1], c[2]
        if value == current then selected = text end
        combo:AddItem(combo:CreateItemEntry(text, function() onSelect(value) end))
    end
    combo:SetSelectedItem(selected or tostring(current or ""))
    return row
end

local function ButtonRow(defs)
    local row = AcquireRow("buttons")
    row.label:SetText("")
    for i, b in ipairs(row.buttons) do
        local def = defs[i]
        b:SetHidden(def == nil)
        b.onClick = nil
        if def then
            b:SetText(def[1])
            b.onClick = def[2]
        end
    end
end

---------------------------------------------------------------------------
-- Selector de efectos/habilidades
---------------------------------------------------------------------------
local function SlottedAbilities()
    local out, seen = {}, {}
    for _, bar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for slot = 3, 8 do
            local id = GetSlotBoundId(slot, bar)
            if id and id > 0 and not seen[id] then
                seen[id] = true
                out[#out + 1] = { id = id, name = U.AbilityName(id), icon = U.AbilityIcon(id), slotted = true }
            end
        end
    end
    return out
end

local function CurrentEffects(unit)
    local out = {}
    for _, b in ipairs(OA.Triggers.NewContext(GetFrameTimeSeconds()):GetBuffs(unit)) do
        if b.abilityId then
            out[#out + 1] = { id = b.abilityId, name = b.name, icon = b.icon }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local MAX_PROC_IDS = 20
local MAX_RESULTS = 25

-- entry = { name, id, icon, slotted?, ids? }  (ids: todas las variantes con ese nombre)
-- Nombre en minúsculas de una entrada de spells (ID o nombre).
local function SpellLName(s)
    if type(s) == "number" then return zo_strlower(U.AbilityName(s)) end
    return zo_strlower(tostring(s))
end

local function AddSpell(aura, trig, entry, mode)
    if type(trig.spells) ~= "table" then trig.spells = {} end
    local spells = trig.spells
    local lname = zo_strlower(entry.name or "")

    local function Has(v)
        for _, s in ipairs(spells) do
            if s == v then return true end
        end
        return false
    end
    local function Add(v)
        if not Has(v) then table.insert(spells, v) end
    end

    if mode == "proc" and entry.ids then
        -- Los eventos de combate se filtran por ID: se añaden las variantes.
        for i = 1, math.min(#entry.ids, MAX_PROC_IDS) do Add(entry.ids[i]) end
    elseif mode == "buff" and (entry.slotted or (entry.ids and #entry.ids > 1)) then
        -- Por nombre: cubre todas las variantes (el buff que deja una habilidad suele
        -- tener otro ID pero el mismo nombre). Los IDs sueltos con ese nombre sobran.
        for i = #spells, 1, -1 do
            if type(spells[i]) == "number" and SpellLName(spells[i]) == lname then table.remove(spells, i) end
        end
        Add(entry.name)
        if entry.icon then
            trig.spellIcons = trig.spellIcons or {}
            trig.spellIcons[lname] = entry.icon
        end
    elseif mode == "buff" and Has(entry.name) then
        -- Ya se vigila por nombre, que incluye este ID.
    else
        Add(entry.id)
    end

    if aura.autoName then aura.name = entry.name end
    Changed(true)
end

Ed.AddSpell = AddSpell

local function SpellRow(icon, text, buttonIcons, onClick)
    local row = AcquireRow("spell")
    row.icon:SetTexture(icon or OA.Display.DEFAULT_ICON)
    row.label:SetText(text)
    row.action:SetIcons(buttonIcons)
    row.onClick = onClick
end

local function EntryText(e)
    if e.ids and #e.ids > 1 then
        return string.format("%s |c888888(%s)|r", e.name, string.format(L.VARIANTS, #e.ids))
    end
    return string.format("%s |c888888(%d)|r", e.name, e.id)
end

---------------------------------------------------------------------------
-- Búsqueda en todas las habilidades del juego
---------------------------------------------------------------------------
Ed.search = {}

function Ed.RunSearch()
    local s = Ed.search
    local index = OA.AbilityIndex
    local function ShowResults()
        s.status = nil
        s.results, s.truncated = index.Search(s.query, MAX_RESULTS)
        if Ed.IsShown() then Ed.RequestRender() end
    end
    if index.IsReady() then
        ShowResults()
        return
    end
    s.status = string.format(L.SEARCH_INDEXING, 0)
    Ed.RequestRender()
    index.Build(function(progress)
        s.status = string.format(L.SEARCH_INDEXING, math.floor(progress * 100))
        if s.statusLabel and s.statusToken == Ed.renderToken then s.statusLabel:SetText(s.status) end
    end, function()
        if s == Ed.search and s.query and s.query ~= "" then ShowResults() end
    end)
end

local function SearchSection(aura, trig, mode, pick)
    local s = Ed.search
    local row = AcquireRow("edit")
    row.label:SetText(L.SEARCH_LABEL)
    row.edit:SetText(s.query or "")
    row.onCommit = function(text)
        text = U.Trim(text)
        if text == (s.query or "") then return end
        s.query, s.results, s.truncated = text, nil, false
        if text == "" then
            s.status = nil
            Ed.RequestRender()
        else
            Ed.RunSearch()
        end
    end

    if s.status then
        local note = AcquireRow("note")
        note.label:SetText(s.status)
        s.statusLabel, s.statusToken = note.label, Ed.renderToken
    elseif not s.results then
        Note(L.SEARCH_HINT)
    elseif #s.results == 0 then
        Note(string.format(L.SEARCH_NONE, s.query))
    else
        Note(s.truncated and string.format(L.SEARCH_MORE, MAX_RESULTS) or string.format(L.SEARCH_RESULTS, #s.results))
        for _, e in ipairs(s.results) do
            SpellRow(e.icon, EntryText(e), PLUS, function() pick(e) end)
        end
    end
end

local function PickerRow(label, entries, emptyText, onPick)
    local choices = {}
    for _, e in ipairs(entries) do
        choices[#choices + 1] = { e, IconText(e.icon, EntryText(e)) }
    end
    if #choices == 0 then choices[1] = { false, emptyText } end
    ChoiceRow(label, choices, nil, function(entry)
        if entry then onPick(entry) end
    end, L.PICK_PLACEHOLDER)
end

local function SpellsEditor(aura, trig, path, mode)
    local spells = type(trig.spells) == "table" and trig.spells or {}

    -- Iconos conocidos por nombre, para mostrar algo útil en las entradas por nombre.
    local iconByName = {}
    for lname, icon in pairs(trig.spellIcons or {}) do iconByName[lname] = icon end
    for _, s in ipairs(spells) do
        if type(s) == "number" then iconByName[zo_strlower(U.AbilityName(s))] = U.AbilityIcon(s) end
    end

    SubHeader(L.F_SPELLS_LIST)
    if #spells == 0 then Note(L.SPELLS_EMPTY) end
    if #spells > 1 then Note(L.SPELLS_ANY_HINT) end
    for index, s in ipairs(spells) do
        local icon, text
        if type(s) == "number" then
            icon = U.AbilityIcon(s)
            text = string.format("%s |c888888(%d)|r", U.AbilityName(s), s)
        else
            icon = iconByName[zo_strlower(tostring(s))]
            text = string.format("%s |c888888(%s)|r", tostring(s), L.BY_NAME)
        end
        SpellRow(icon, text, TRASH, function()
            table.remove(spells, index)
            Changed(true)
        end)
    end

    local function Pick(entry) AddSpell(aura, trig, entry, mode) end
    SubHeader(L.SUB_ADD_EFFECT)
    SearchSection(aura, trig, mode, Pick)
    ButtonRow({ { L.OPEN_CATALOG, function() OA.Catalog.Open(aura, trig, mode) end } })
    if mode == "buff" then
        local unit = trig.unit or "player"
        PickerRow(L.PICK_CURRENT, CurrentEffects(unit),
            unit == "player" and L.NO_EFFECTS_PLAYER or L.NO_EFFECTS_TARGET, Pick)
    end
    PickerRow(L.PICK_SLOTTED, SlottedAbilities(), L.NO_SLOTTED, Pick)
    PickerRow(L.PICK_RECENT, OA.Recent.Get(), L.NO_RECENT, Pick)
end

---------------------------------------------------------------------------
-- Campos genéricos
---------------------------------------------------------------------------
local function Field(aura, f, path)
    local kind = f.kind

    if kind == "text" or kind == "number" or kind == "list" then
        local row = AcquireRow("edit")
        row.label:SetText(f.label)
        local v = FieldValue(aura, path, f)
        local shown = v == nil and "" or U.ValueToString(v)
        row.edit:SetText(shown)
        row.onCommit = function(newText)
            newText = U.Trim(newText)
            if newText == shown then return end
            local value
            if newText ~= "" then
                if kind == "number" then
                    value = tonumber(newText)
                    if not value then row.edit:SetText(shown) return end
                elseif kind == "list" then
                    value = U.CommaList(newText)
                else
                    value = newText
                end
            elseif f.required then
                row.edit:SetText(shown)
                return
            end
            shown = newText
            Commit(aura, path, value, f.rerender)
        end

    elseif kind == "choice" then
        local choices = type(f.choices) == "function" and f.choices() or f.choices
        ChoiceRow(f.label, choices, FieldValue(aura, path, f), function(value)
            if value ~= FieldValue(aura, path, f) then Commit(aura, path, value, f.rerender) end
        end)

    elseif kind == "sound" then
        local choices = { { false, L.SOUND_NONE } }
        for _, key in ipairs(SOUND_KEYS) do
            if SOUNDS[key] then choices[#choices + 1] = { key, PrettyKey(key) } end
        end
        ChoiceRow(f.label, choices, U.GetPath(aura, path) or false, function(value)
            Commit(aura, path, value or nil, false)
            if value then PlaySound(SOUNDS[value]) end
        end)

    elseif kind == "spells" then
        local trig = U.GetPath(aura, path:match("^(.*)%.[^%.]+$"))
        SpellsEditor(aura, trig, path, f.mode)

    elseif kind == "bool" then
        local row = AcquireRow("bool")
        row.label:SetText(f.label)
        ZO_CheckButton_SetCheckState(row.check, FieldValue(aura, path, f) == true)
        row.onCommit = function(checked) Commit(aura, path, checked, f.rerender) end

    elseif kind == "color" then
        local row = AcquireRow("color")
        row.label:SetText(f.label)
        local token = Ed.renderToken
        local function Paint()
            if Ed.renderToken == token then
                row.swatch:SetCenterColor(U.Color(U.GetPath(aura, path), f.default))
            end
        end
        Paint()
        row.onClick = function()
            local r, g, b, a = U.Color(U.GetPath(aura, path), f.default)
            COLOR_PICKER:Show(function(nr, ng, nb, na)
                Commit(aura, path, { nr, ng, nb, na or 1 }, false)
                Paint()
            end, r, g, b, a, f.label)
        end
        row.onReset = function()
            Commit(aura, path, nil, false)
            Paint()
        end
    end
end

local function TriggerSelector(aura)
    local choices = {}
    for i, trig in ipairs(aura.triggers) do
        choices[#choices + 1] = { i, string.format(L.TRIGGER_N, i, ChoiceLabel(TRIGGER_TYPES, trig.type)) }
    end
    choices[#choices + 1] = { "add", L.ADD_TRIGGER }
    ChoiceRow(L.EDITING, choices, Ed.trigIndex, function(value)
        if value == "add" then
            table.insert(aura.triggers, { type = "combat", state = "in" })
            Ed.trigIndex = #aura.triggers
            Changed(true)
        elseif value ~= Ed.trigIndex then
            OA.Catalog.Hide()
            Ed.trigIndex = value
            Ed.RequestRender()
        end
    end)
end

---------------------------------------------------------------------------
-- Formulario
---------------------------------------------------------------------------
-- Qué datos pueden aportar los triggers del aura (unión de todos, porque con
-- "se cumple ALGUNO" cualquiera de ellos puede ser el que se muestre).
local function Capabilities(aura)
    local caps = {}
    for _, t in ipairs(aura.triggers or {}) do
        if t.type == "buff" then
            if t.show == "missing" then
                caps.missing = true
            else
                caps.time, caps.stacks = true, true
            end
        elseif t.type == "proc" then
            caps.time = true
        elseif t.type == "resource" then
            caps.value = true
        end
    end
    caps.progress = caps.time or caps.value
    return caps
end

local function Visible(f, ctx)
    return not f.show or f.show(ctx)
end

function Ed.Render()
    if not Ed.win then return end
    ReleaseRows()

    local aura = Ed.selectedId and OA.sv.auras[Ed.selectedId]
    Ed.emptyLabel:SetHidden(aura ~= nil)
    if not aura then return end

    aura.triggers = aura.triggers or {}
    aura.display = aura.display or {}
    if #aura.triggers == 0 then aura.triggers[1] = { type = "buff", unit = "player", spells = {} } end
    if not aura.triggers[Ed.trigIndex] then Ed.trigIndex = 1 end

    Header(L.H_GENERAL)
    for _, f in ipairs(GENERAL_FIELDS) do Field(aura, f, f.key) end

    Header(L.H_WHEN)
    TriggerSelector(aura)
    if #aura.triggers > 1 then Field(aura, LOGIC_FIELD, "logic") end
    local i = Ed.trigIndex
    local trig = aura.triggers[i]
    local base = "triggers." .. i .. "."
    Field(aura, TRIGGER_TYPE_FIELD, base .. "type")
    local caps = Capabilities(aura)
    local trigCtx = { caps = caps, aura = aura, trig = trig, d = aura.display }
    local optionsShown = false
    for _, f in ipairs(TRIGGER_FIELDS[trig.type] or {}) do
        if Visible(f, trigCtx) then
            if f.options and not optionsShown then
                SubHeader(L.SUB_OPTIONS)
                optionsShown = true
            end
            Field(aura, f, base .. f.key)
        end
    end
    if #aura.triggers > 1 then
        ButtonRow({ { L.REMOVE_TRIGGER, function()
            table.remove(aura.triggers, i)
            Ed.trigIndex = 1
            Changed(true)
        end } })
    end

    Header(L.H_LOOK)
    Field(aura, DISPLAY_TYPE_FIELD, "display.type")
    local dtype = aura.display.type
    local displayCtx = { caps = caps, aura = aura, d = aura.display }
    local anyText = false
    for _, f in ipairs(DISPLAY_FIELDS[dtype] or DISPLAY_FIELDS.icon) do
        if Visible(f, displayCtx) then
            Field(aura, f, "display." .. f.key)
            anyText = anyText or f.kind == "text" and f.key ~= "icon"
        end
    end
    if anyText then Note(L.TEXT_HELP) end
    ButtonRow({ { L.PLACE_THIS, function() Ed.StartMoveMode(aura.id) end } })

    Header(L.H_ACTIONS)
    ButtonRow({
        { L.DUPLICATE, function()
            local copy = OA.Engine.DuplicateAura(aura.id)
            if copy then Ed.Select(copy.id) end
        end },
        { L.DELETE, function() Ed.ConfirmDelete(aura.id) end },
    })
end

function Ed.RequestRender()
    if Ed.renderPending then return end
    Ed.renderPending = true
    -- Diferido: así no reciclamos un desplegable mientras está ejecutando su callback.
    zo_callLater(function()
        Ed.renderPending = false
        Ed.Render()
    end, 1)
end

---------------------------------------------------------------------------
-- Lista de auras
---------------------------------------------------------------------------
local function AuraIcon(aura)
    local d = aura.display or {}
    if d.icon then return d.icon end
    local trig = aura.triggers and aura.triggers[1]
    if trig and type(trig.spells) == "table" then
        for _, s in ipairs(trig.spells) do
            local icon
            if type(s) == "number" then
                icon = U.AbilityIcon(s)
            elseif trig.spellIcons then
                icon = trig.spellIcons[zo_strlower(tostring(s))]
            end
            if icon then return icon end
        end
    end
    return OA.Display.DEFAULT_ICON
end

local function CreateListRow(i)
    local name = "OmniAuraEditorListRow" .. i
    local row = WM:CreateControl(name, Ed.listChild, CT_CONTROL)
    row:SetDimensions(LIST_W - 24, 34)
    row:SetAnchor(TOPLEFT, Ed.listChild, TOPLEFT, 0, (i - 1) * 36)
    row:SetMouseEnabled(true)

    row.selected = OA.Display.Solid(name .. "Sel", row, 0.25, 0.45, 0.75, 0.45)
    row.selected:SetAnchorFill(row)
    row.hover = OA.Display.Solid(name .. "Hover", row, 1, 1, 1, 0.08)
    row.hover:SetAnchorFill(row)
    row.hover:SetHidden(true)

    row.icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(30, 30)
    row.icon:SetAnchor(LEFT, row, LEFT, 2, 0)

    row.label = WM:CreateControl(name .. "Label", row, CT_LABEL)
    row.label:SetFont("ZoFontGame")
    row.label:SetDimensions(LIST_W - 100, 34)
    row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.label:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)

    row:SetHandler("OnMouseEnter", function() row.hover:SetHidden(false) end)
    row:SetHandler("OnMouseExit", function() row.hover:SetHidden(true) end)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and row.auraId then Ed.Select(row.auraId) end
    end)

    -- Papelera para borrar directamente desde la lista (pide confirmación).
    local delete = IconButton(name .. "Delete", row, 30, TRASH, function()
        if row.auraId then Ed.ConfirmDelete(row.auraId) end
    end)
    delete:SetAnchor(RIGHT, row, RIGHT, -2, 0)
    delete:SetHandler("OnMouseEnter", function() row.hover:SetHidden(false) end)
    delete:SetHandler("OnMouseExit", function() row.hover:SetHidden(true) end)

    Ed.listRows[i] = row
    return row
end

function Ed.RefreshList()
    if not Ed.win then return end
    local ids = OA.Engine.SortedIds()
    for i, id in ipairs(ids) do
        local aura = OA.sv.auras[id]
        local row = Ed.listRows[i] or CreateListRow(i)
        row.auraId = id
        row:SetHidden(false)
        row.icon:SetTexture(AuraIcon(aura))
        local enabled = aura.enabled ~= false
        row.icon:SetDesaturation(enabled and 0 or 1)
        row.label:SetText(aura.name or "?")
        if enabled then row.label:SetColor(1, 1, 1, 1) else row.label:SetColor(0.5, 0.5, 0.5, 1) end
        row.selected:SetHidden(id ~= Ed.selectedId)
    end
    for i = #ids + 1, #Ed.listRows do
        Ed.listRows[i]:SetHidden(true)
        Ed.listRows[i].auraId = nil
    end
    Ed.countLabel:SetText(string.format(#ids == 1 and L.COUNT_ONE or L.COUNT_MANY, #ids))
end

function Ed.Select(id)
    if id ~= Ed.selectedId then
        Ed.search = {}
        OA.Catalog.Hide()
    end
    Ed.selectedId = id
    Ed.trigIndex = 1
    Ed.SetPlacing(false)
    Ed.RefreshList()
    Ed.RequestRender()
end

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------
local function Build()
    local win = WM:CreateTopLevelWindow("OmniAuraEditor")
    win:SetDimensions(WIN_W, WIN_H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    -- Por debajo de los diálogos del juego (selector de color, confirmaciones).
    win:SetDrawTier(DT_LOW)
    win:SetHidden(true)
    Ed.win = win

    local bg = WM:CreateControlFromVirtual("OmniAuraEditorBg", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    -- Barra de título: es lo único que mueve la ventana.
    local titleBar = WM:CreateControl("OmniAuraEditorTitleBar", win, CT_CONTROL)
    titleBar:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    titleBar:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
    titleBar:SetHeight(48)
    OA.Display.MakeDraggable(win, titleBar)

    local title = WM:CreateControl("OmniAuraEditorTitle", win, CT_LABEL)
    title:SetFont("ZoFontWinH2")
    title:SetText("|c00C8FFOmni|rAura")
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 12)

    local credits = WM:CreateControl("OmniAuraEditorCredits", win, CT_LABEL)
    credits:SetFont("ZoFontGameSmall")
    credits:SetColor(0.6, 0.6, 0.6, 1)
    credits:SetText(string.format(L.EDITOR_CREDITS, OA.version, OA.author))
    credits:SetAnchor(BOTTOMLEFT, title, BOTTOMRIGHT, 12, -4)

    local close = WM:CreateControlFromVirtual("OmniAuraEditorClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    close:SetHandler("OnClicked", function() Ed.Hide() end)

    -- Plegar/desplegar: deja solo la barra de título para ver las auras de detrás.
    local collapse = IconButton("OmniAuraEditorCollapse", win, 28, ARROW_UP, function()
        Ed.SetCollapsed(not Ed.collapsed)
    end)
    collapse:SetAnchor(RIGHT, close, LEFT, -10, 0)
    collapse:SetHandler("OnMouseEnter", function()
        InitializeTooltip(InformationTooltip, collapse, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, Ed.collapsed and L.EXPAND or L.COLLAPSE)
    end)
    collapse:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    Ed.collapseBtn = collapse

    -- Ayuda: abre la sección de OmniAura en Ajustes (o una ventana si no hay LibAddonMenu).
    local help = WM:CreateControl("OmniAuraEditorHelp", win, CT_BUTTON)
    help:SetDimensions(28, 28)
    help:SetFont("ZoFontWinH3")
    help:SetNormalFontColor(0.8, 0.8, 0.8, 1)
    help:SetMouseOverFontColor(1, 1, 1, 1)
    help:SetText("?")
    help:SetAnchor(RIGHT, collapse, LEFT, -6, 0)
    help:SetHandler("OnClicked", function()
        ClearTooltip(InformationTooltip)
        OA.Settings.OpenHelp()
    end)
    help:SetHandler("OnMouseEnter", function()
        InitializeTooltip(InformationTooltip, help, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, L.HELP_BUTTON)
    end)
    help:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    -- Enlace para donar (solo en el megaservidor del autor).
    if OA.Settings and OA.Settings.CanDonate() then
        local donate = WM:CreateControl("OmniAuraEditorDonate", win, CT_BUTTON)
        donate:SetDimensions(130, 24)
        donate:SetFont("ZoFontGameSmall")
        donate:SetNormalFontColor(unpack(GOLD))
        donate:SetMouseOverFontColor(1, 0.9, 0.6, 1)
        donate:SetText(zo_iconFormat(GOLD_ICON, 16, 16) .. " " .. L.DONATE_BUTTON)
        donate:SetAnchor(RIGHT, help, LEFT, -8, 0)
        donate:SetHandler("OnClicked", function() OA.Settings.ComposeDonation() end)
    end

    local body = WM:CreateControl("OmniAuraEditorBody", win, CT_CONTROL)
    body:SetAnchorFill(win)
    Ed.body = body

    -- Desplegable de plantillas para crear auras
    local newContainer = WM:CreateControlFromVirtual("OmniAuraEditorNew", body, "ZO_ComboBox")
    newContainer:SetDimensions(LIST_W, 28)
    newContainer:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 56)
    local newCombo = ZO_ComboBox_ObjectFromContainer(newContainer)
    newCombo:SetSortsItems(false)
    for _, tpl in ipairs(TEMPLATES) do
        newCombo:AddItem(newCombo:CreateItemEntry(tpl[1], function()
            local name, triggers, display = tpl[2]()
            local aura = OA.Engine.CreateAura(name, triggers, display)
            aura.autoName = true
            Ed.Select(aura.id)
            zo_callLater(function() newCombo:SetSelectedItem(L.EDITOR_NEW) end, 1)
        end))
    end
    newCombo:SetSelectedItem(L.EDITOR_NEW)

    Ed.countLabel = WM:CreateControl("OmniAuraEditorCount", body, CT_LABEL)
    Ed.countLabel:SetFont("ZoFontGameSmall")
    Ed.countLabel:SetColor(0.6, 0.6, 0.6, 1)
    Ed.countLabel:SetAnchor(TOPLEFT, newContainer, BOTTOMLEFT, 2, 6)

    local list = WM:CreateControlFromVirtual("OmniAuraEditorList", body, "ZO_ScrollContainer")
    list:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 112)
    list:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 16, -64)
    list:SetWidth(LIST_W)
    Ed.listChild = GetControl(list, "ScrollChild")

    local move = WM:CreateControlFromVirtual("OmniAuraEditorMove", body, "ZO_DefaultButton")
    move:SetDimensions(LIST_W, 30)
    move:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 16, -20)
    move:SetText(L.MOVE)
    move:SetHandler("OnClicked", function() Ed.StartMoveMode() end)

    local divider = OA.Display.Solid("OmniAuraEditorDivider", body, 0.77, 0.69, 0.46, 0.3)
    divider:SetWidth(1)
    divider:SetAnchor(TOPLEFT, win, TOPLEFT, LIST_W + 28, 56)
    divider:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, LIST_W + 28, -20)

    local form = WM:CreateControlFromVirtual("OmniAuraEditorForm", body, "ZO_ScrollContainer")
    form:SetAnchor(TOPLEFT, win, TOPLEFT, LIST_W + 44, 50)
    form:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -20)
    Ed.formChild = GetControl(form, "ScrollChild")

    Ed.emptyLabel = WM:CreateControl("OmniAuraEditorEmpty", body, CT_LABEL)
    Ed.emptyLabel:SetFont("ZoFontGameLarge")
    Ed.emptyLabel:SetColor(0.7, 0.7, 0.7, 1)
    Ed.emptyLabel:SetDimensions(LABEL_W + WIDGET_W, 200)
    Ed.emptyLabel:SetText(string.format(L.EDITOR_EMPTY, L.EDITOR_NEW))
    Ed.emptyLabel:SetAnchor(TOPLEFT, form, TOPLEFT, 10, 20)

    -- Escena propia: muestra el cursor, se cierra con Esc y mantiene visibles las auras.
    local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    scene:AddFragment(ZO_SimpleSceneFragment:New(win))
    if FRAGMENT_GROUP and FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW then
        scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    end
    scene:AddFragment(OA.Display.fragment)
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            Ed.OnShow()
        elseif newState == SCENE_HIDDEN then
            Ed.OnHide()
        end
    end)
end

function Ed.OnShow()
    OA.editorOpen = true
    if not (Ed.selectedId and OA.sv.auras[Ed.selectedId]) then
        Ed.selectedId = OA.Engine.SortedIds()[1]
        Ed.trigIndex = 1
    end
    Ed.SetPlacing(false)
    Ed.RefreshList()
    Ed.Render()
end

function Ed.OnHide()
    OA.editorOpen = false
    OA.Catalog.Hide()
    ReleaseRows()
    Ed.placing = false
    if not Ed.moveMode then
        OA.previewId = nil
        Ed.ShowMoveBar(false)
    end
    if OA.unlocked and not Ed.moveMode then Ed.SetUnlocked(false) else OA.Display.RefreshUnlocked() end
end

---------------------------------------------------------------------------
-- API pública
---------------------------------------------------------------------------
-- Botón "Ubicar en pantalla": muestra solo el aura seleccionada
-- en modo edición (fondo azul, arrastrar para mover, esquina para el tamaño).
function Ed.SetPlacing(on)
    Ed.placing = on and Ed.selectedId ~= nil
    OA.previewId = Ed.placing and Ed.selectedId or nil
    OA.Display.RefreshUnlocked()
    if not Ed.moveMode then Ed.ShowMoveBar(Ed.placing, L.LOOK_HINT) end
end

function Ed.IsShown()
    return SCENE_MANAGER:IsShowing(SCENE_NAME)
end

function Ed.Show() SCENE_MANAGER:Show(SCENE_NAME) end
function Ed.Hide() SCENE_MANAGER:Hide(SCENE_NAME) end
function Ed.Toggle() SCENE_MANAGER:Toggle(SCENE_NAME) end

function Ed.RefreshIfShown()
    if Ed.IsShown() then
        if not OA.sv.auras[Ed.selectedId or 0] then
            Ed.selectedId = OA.Engine.SortedIds()[1]
            Ed.SetPlacing(false)
        end
        Ed.RefreshList()
        Ed.RequestRender()
    end
end

function Ed.SetUnlocked(on)
    OA.Display.SetUnlocked(on)
end

---------------------------------------------------------------------------
-- Borrado con ventana de confirmación
---------------------------------------------------------------------------
local DELETE_DIALOG = "OMNIAURA_DELETE_AURA"

local function RegisterDialogs()
    ZO_Dialogs_RegisterCustomDialog(DELETE_DIALOG, {
        title = { text = L.DELETE_TITLE },
        mainText = { text = L.DELETE_TEXT },
        buttons = {
            {
                text = L.DELETE,
                callback = function(dialog) Ed.DeleteAura(dialog.data.id) end,
            },
            { text = GetString(SI_DIALOG_CANCEL) },
        },
    })
end

function Ed.ConfirmDelete(id)
    local aura = OA.sv.auras[id]
    if not aura then return end
    ZO_Dialogs_ShowDialog(DELETE_DIALOG, { id = id }, { mainTextParams = { aura.name or "?" } })
end

function Ed.DeleteAura(id)
    if not OA.Engine.DeleteAura(id) then return end
    if Ed.selectedId == id then
        Ed.Select(OA.Engine.SortedIds()[1])
    else
        Ed.RefreshList()
    end
end

local COLLAPSED_H = 52

function Ed.SetCollapsed(collapsed)
    Ed.collapsed = collapsed
    local win = Ed.win
    -- Se fija la esquina superior para que la barra de título no salte al plegar.
    local left, top = win:GetLeft(), win:GetTop()
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    win:SetHeight(collapsed and COLLAPSED_H or WIN_H)
    Ed.body:SetHidden(collapsed)
    Ed.collapseBtn:SetIcons(collapsed and ARROW_DOWN or ARROW_UP)
    ClearTooltip(InformationTooltip)
end

---------------------------------------------------------------------------
-- Modo ubicar ("Ubicar auras" o el botón "Ubicar en pantalla" de un aura): oculta el
-- editor y muestra el HUD normal con cursor
-- (escena "hudui", la misma que al pulsar la tecla del cursor jugando) para
-- colocar las auras viendo la interfaz real.
---------------------------------------------------------------------------
local function BuildMoveBar()
    local bar = WM:CreateTopLevelWindow("OmniAuraMoveBar")
    bar:SetDimensions(700, 50)
    bar:SetAnchor(TOP, GuiRoot, TOP, 0, 70)
    bar:SetDrawTier(DT_HIGH)
    bar:SetMouseEnabled(true)
    bar:SetHidden(true)

    local bg = WM:CreateControlFromVirtual("OmniAuraMoveBarBg", bar, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(bar)

    local hint = WM:CreateControl("OmniAuraMoveBarHint", bar, CT_LABEL)
    hint:SetFont("ZoFontGame")
    hint:SetColor(0.9, 0.9, 0.9, 1)
    hint:SetText(L.MOVE_HINT)
    Ed.moveHint = hint
    hint:SetAnchor(LEFT, bar, LEFT, 16, 0)

    local done = WM:CreateControlFromVirtual("OmniAuraMoveBarDone", bar, "ZO_DefaultButton")
    done:SetDimensions(120, 30)
    done:SetText(L.MOVE_DONE)
    done:SetAnchor(RIGHT, bar, RIGHT, -12, 0)
    done:SetHandler("OnClicked", function()
        if Ed.moveMode then
            Ed.EndMoveMode(true)
        else
            Ed.SetPlacing(false)
            Ed.RequestRender()
        end
    end)

    Ed.moveBar = bar
end

function Ed.ShowMoveBar(show, hint)
    if not Ed.moveBar then return end
    if hint then Ed.moveHint:SetText(hint) end
    Ed.moveBar:SetHidden(not show)
end

-- auraId: ubicar solo esa aura; sin él, todas.
function Ed.StartMoveMode(auraId)
    if Ed.moveMode then return end
    Ed.SetPlacing(false)
    Ed.moveMode = auraId and "single" or "all"
    SCENE_MANAGER:Show("hudui")
    if auraId then
        OA.previewId = auraId
        OA.Display.RefreshUnlocked()
        Ed.ShowMoveBar(true, L.LOOK_HINT)
    else
        OA.Display.SetUnlocked(true)
        Ed.ShowMoveBar(true, L.MOVE_HINT)
    end
end

-- reopenEditor: volver al editor al terminar (botón "Listo").
function Ed.EndMoveMode(reopenEditor)
    if not Ed.moveMode then return end
    Ed.moveMode = nil
    Ed.ShowMoveBar(false)
    OA.previewId = nil
    OA.Display.SetUnlocked(false)
    if reopenEditor then Ed.Show() end
end

function Ed.Init()
    Build()
    BuildMoveBar()
    -- Salir con Esc o abriendo otro menú también termina el modo mover.
    HUD_UI_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDDEN and Ed.moveMode then Ed.EndMoveMode(false) end
    end)
    RegisterDialogs()
end

-- Usado por Bindings.xml
function OmniAura_ToggleEditor()
    Ed.Toggle()
end
