-- Catálogo de habilidades: ventana para explorar todas las habilidades/efectos del juego
-- por categorías, filtrar por nombre y añadirlas al trigger que se está editando.
-- La lista es virtual: solo existen las filas visibles y se rellenan según el desplazamiento.

local OA = OmniAura
local U = OA.Utils
local L = OA.L
local WM = WINDOW_MANAGER

local Cat = { category = "all", onlyIcons = true, offset = 0, results = {}, rows = {}, catRows = {} }
OA.Catalog = Cat

local W, H = 860, 640
local SIDE_W = 210
local ROW_H = 34
local CAT_ROW_H = 24
local LIST_TOP = 104
local LIST_BOTTOM = 44
local SCROLL_STEP = 3
local GOLD = { 0.77, 0.69, 0.46, 1 }
local PLUS = {
    up = "EsoUI/Art/Buttons/plus_up.dds",
    over = "EsoUI/Art/Buttons/plus_over.dds",
    down = "EsoUI/Art/Buttons/plus_down.dds",
}

-- Nombre de clase traducido por el propio juego (con alternativa en inglés).
local function ClassLabel(classId, fallback)
    local name = GetClassName and GetClassName(GENDER_MALE, classId)
    if name and name ~= "" then return U.FormatName(name) end
    return fallback
end

local CATEGORIES = {
    { header = L.CAT_GROUP_GENERAL },
    { key = "all", label = L.CAT_ALL },
    { key = "buff", label = L.CAT_BUFF },
    { key = "debuff", label = L.CAT_DEBUFF },
    { header = L.CAT_GROUP_CLASSES },
    { key = "dk", label = ClassLabel(1, "Dragonknight") },
    { key = "sorc", label = ClassLabel(2, "Sorcerer") },
    { key = "nb", label = ClassLabel(3, "Nightblade") },
    { key = "templar", label = ClassLabel(6, "Templar") },
    { key = "warden", label = ClassLabel(4, "Warden") },
    { key = "necro", label = ClassLabel(5, "Necromancer") },
    { key = "arcanist", label = ClassLabel(117, "Arcanist") },
    { header = L.CAT_GROUP_WEAPONS },
    { key = "2h", label = L.CAT_2H },
    { key = "1h", label = L.CAT_1H },
    { key = "dw", label = L.CAT_DW },
    { key = "bow", label = L.CAT_BOW },
    { key = "destro", label = L.CAT_DESTRO },
    { key = "resto", label = L.CAT_RESTO },
    { header = L.CAT_GROUP_OTHER },
    { key = "armor", label = L.CAT_ARMOR },
    { key = "guild", label = L.CAT_GUILD },
    { key = "world", label = L.CAT_WORLD },
    { key = "ava", label = L.CAT_AVA },
    { key = "racial", label = L.CAT_RACIAL },
    { key = "mundus", label = L.CAT_MUNDUS },
    { key = "companion", label = L.CAT_COMPANION },
    { key = "gear", label = L.CAT_GEAR },
    { key = "consumable", label = L.CAT_CONSUMABLE },
    { key = "other", label = L.CAT_OTHER },
}

---------------------------------------------------------------------------
-- Lista virtual
---------------------------------------------------------------------------
local function MaxOffset()
    return math.max(0, #Cat.results - Cat.visible)
end

local function UpdateScrollbar()
    local maxOffset = MaxOffset()
    Cat.slider:SetHidden(maxOffset == 0)
    Cat.updatingSlider = true
    Cat.slider:SetMinMax(0, math.max(1, maxOffset))
    Cat.slider:SetValue(Cat.offset)
    Cat.updatingSlider = false
end

function Cat.RefreshRows()
    for i, row in ipairs(Cat.rows) do
        local g = Cat.results[Cat.offset + i]
        row.group = g
        row:SetHidden(g == nil)
        if g then
            row.icon:SetTexture(g.icon)
            row.name:SetText(g.display)
            if #g.ids > 1 then
                row.info:SetText(string.format(L.VARIANTS, #g.ids))
            else
                row.info:SetText(string.format("ID %d", g.ids[1]))
            end
        end
    end
    UpdateScrollbar()
end

function Cat.SetOffset(offset)
    Cat.offset = zo_clamp(math.floor(offset), 0, MaxOffset())
    Cat.RefreshRows()
end

local function Scroll(delta)
    Cat.SetOffset(Cat.offset - delta * SCROLL_STEP)
end

function Cat.Refilter()
    if not OA.AbilityIndex.IsReady() then return end
    Cat.results = OA.AbilityIndex.Filter(Cat.category, Cat.search:GetText(), Cat.onlyIcons)
    Cat.count:SetText(string.format(L.CATALOG_COUNT, ZO_CommaDelimitNumber(#Cat.results)))
    Cat.SetOffset(0)
end

local function RefreshCategories()
    local counts = OA.AbilityIndex.counts or {}
    for _, row in ipairs(Cat.catRows) do
        local c = row.category
        local n = counts[c.key]
        row.label:SetText(n and string.format("%s |c888888(%s)|r", c.label, ZO_CommaDelimitNumber(n)) or c.label)
        row.selected:SetHidden(c.key ~= Cat.category)
    end
end

---------------------------------------------------------------------------
-- Añadir al trigger que se está editando
---------------------------------------------------------------------------
function Cat.Add(g)
    local t = Cat.target
    if not g or not t then return end
    OA.Editor.AddSpell(t.aura, t.trig, OA.AbilityIndex.EntryFromGroup(g), t.mode)
    Cat.status:SetText(string.format(L.CATALOG_ADDED, g.display, t.aura.name or "?"))
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

---------------------------------------------------------------------------
-- Construcción de la ventana
---------------------------------------------------------------------------
local function Label(name, parent, font, r, g, b)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetColor(r or 1, g or 1, b or 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function ShowTooltip(row)
    local g = row.group
    if not g or not AbilityTooltip then return end
    InitializeTooltip(AbilityTooltip, Cat.win, TOPLEFT, 8, 0, TOPRIGHT)
    AbilityTooltip:SetAbilityId(g.iconId or g.ids[1])
end

local function HideTooltip()
    if AbilityTooltip then ClearTooltip(AbilityTooltip) end
end

local function CreateRow(i, listW)
    local name = "OmniAuraCatalogRow" .. i
    local row = WM:CreateControl(name, Cat.listArea, CT_CONTROL)
    row:SetDimensions(listW, ROW_H)
    row:SetAnchor(TOPLEFT, Cat.listArea, TOPLEFT, 0, (i - 1) * ROW_H)
    row:SetMouseEnabled(true)

    row.hover = OA.Display.Solid(name .. "Hover", row, 1, 1, 1, 0.08)
    row.hover:SetAnchorFill(row)
    row.hover:SetHidden(true)

    row.icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(30, 30)
    row.icon:SetAnchor(LEFT, row, LEFT, 4, 0)

    row.name = Label(name .. "Name", row)
    row.name:SetDimensions(listW - 190, ROW_H)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetAnchor(LEFT, row.icon, RIGHT, 10, 0)

    row.add = WM:CreateControl(name .. "Add", row, CT_BUTTON)
    row.add:SetDimensions(28, 28)
    row.add:SetNormalTexture(PLUS.up)
    row.add:SetMouseOverTexture(PLUS.over)
    row.add:SetPressedTexture(PLUS.down)
    row.add:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.add:SetHandler("OnClicked", function() Cat.Add(row.group) end)

    row.info = Label(name .. "Info", row, "ZoFontGameSmall", 0.55, 0.55, 0.55)
    row.info:SetAnchor(RIGHT, row.add, LEFT, -12, 0)

    local function Enter()
        row.hover:SetHidden(false)
        ShowTooltip(row)
    end
    local function Exit()
        row.hover:SetHidden(true)
        HideTooltip()
    end
    row:SetHandler("OnMouseEnter", Enter)
    row:SetHandler("OnMouseExit", Exit)
    row.add:SetHandler("OnMouseEnter", Enter)
    row.add:SetHandler("OnMouseExit", Exit)
    row:SetHandler("OnMouseDoubleClick", function() Cat.Add(row.group) end)
    row:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    return row
end

local function CreateCategoryRow(i, c, parent)
    local name = "OmniAuraCatalogCat" .. i
    local row = WM:CreateControl(name, parent, CT_CONTROL)
    row:SetDimensions(SIDE_W - 20, CAT_ROW_H)
    row.label = Label(name .. "Label", row, c.header and "ZoFontWinH5" or "ZoFontGame")
    row.label:SetAnchor(LEFT, row, LEFT, c.header and 2 or 12, 0)
    row.label:SetText(c.header or c.label)
    if c.header then
        row.label:SetColor(unpack(GOLD))
        return row
    end

    row.category = c
    row.selected = OA.Display.Solid(name .. "Sel", row, 0.25, 0.45, 0.75, 0.45)
    row.selected:SetAnchorFill(row)
    row.selected:SetHidden(true)
    row.hover = OA.Display.Solid(name .. "Hover", row, 1, 1, 1, 0.08)
    row.hover:SetAnchorFill(row)
    row.hover:SetHidden(true)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseEnter", function() row.hover:SetHidden(false) end)
    row:SetHandler("OnMouseExit", function() row.hover:SetHidden(true) end)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if not upInside then return end
        Cat.category = c.key
        RefreshCategories()
        Cat.Refilter()
    end)
    Cat.catRows[#Cat.catRows + 1] = row
    return row
end

local function Build()
    local win = WM:CreateTopLevelWindow("OmniAuraCatalog")
    win:SetDimensions(W, H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)
    Cat.win = win

    local bg = WM:CreateControlFromVirtual("OmniAuraCatalogBg", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local titleBar = WM:CreateControl("OmniAuraCatalogTitleBar", win, CT_CONTROL)
    titleBar:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    titleBar:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 0)
    titleBar:SetHeight(50)
    OA.Display.MakeDraggable(win, titleBar)

    local title = Label("OmniAuraCatalogTitle", win, "ZoFontWinH2")
    title:SetText(L.CATALOG_TITLE)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 12)

    Cat.targetLabel = Label("OmniAuraCatalogTarget", win, "ZoFontGameSmall", 0.6, 0.6, 0.6)
    Cat.targetLabel:SetAnchor(BOTTOMLEFT, title, BOTTOMRIGHT, 14, -4)

    local close = WM:CreateControlFromVirtual("OmniAuraCatalogClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    close:SetHandler("OnClicked", function() Cat.Hide() end)

    -- Barra lateral de categorías
    local side = WM:CreateControlFromVirtual("OmniAuraCatalogSide", win, "ZO_ScrollContainer")
    side:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 60)
    side:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 16, -LIST_BOTTOM)
    side:SetWidth(SIDE_W)
    local sideChild = GetControl(side, "ScrollChild")
    for i, c in ipairs(CATEGORIES) do
        local row = CreateCategoryRow(i, c, sideChild)
        row:SetAnchor(TOPLEFT, sideChild, TOPLEFT, 0, (i - 1) * CAT_ROW_H)
    end

    local divider = OA.Display.Solid("OmniAuraCatalogDivider", win, 0.77, 0.69, 0.46, 0.3)
    divider:SetWidth(1)
    divider:SetAnchor(TOPLEFT, win, TOPLEFT, SIDE_W + 28, 60)
    divider:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, SIDE_W + 28, -LIST_BOTTOM)

    -- Búsqueda y filtros
    local left = SIDE_W + 44
    local searchBg = WM:CreateControlFromVirtual("OmniAuraCatalogSearchBg", win, "ZO_EditBackdrop")
    searchBg:SetDimensions(300, 28)
    searchBg:SetAnchor(TOPLEFT, win, TOPLEFT, left, 62)
    local search = WM:CreateControlFromVirtual("OmniAuraCatalogSearch", searchBg, "ZO_DefaultEditForBackdrop")
    search:SetMaxInputChars(100)
    if ZO_EditDefaultText_Initialize then ZO_EditDefaultText_Initialize(search, L.CATALOG_FILTER) end
    search:SetHandler("OnTextChanged", function()
        -- Espera a que el jugador deje de escribir antes de filtrar.
        Cat.filterToken = (Cat.filterToken or 0) + 1
        local token = Cat.filterToken
        zo_callLater(function()
            if token == Cat.filterToken then Cat.Refilter() end
        end, 250)
    end)
    search:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    Cat.search = search

    local check = WM:CreateControlFromVirtual("OmniAuraCatalogOnlyIcons", win, "ZO_CheckButton")
    check:SetAnchor(LEFT, searchBg, RIGHT, 18, 0)
    ZO_CheckButton_SetCheckState(check, Cat.onlyIcons)
    ZO_CheckButton_SetToggleFunction(check, function(_, checked)
        Cat.onlyIcons = checked
        Cat.Refilter()
    end)
    local checkLabel = Label("OmniAuraCatalogOnlyIconsLabel", win)
    checkLabel:SetText(L.CATALOG_ONLY_ICONS)
    checkLabel:SetAnchor(LEFT, check, RIGHT, 6, 0)

    Cat.count = Label("OmniAuraCatalogCount", win, "ZoFontGameSmall", 0.6, 0.6, 0.6)
    Cat.count:SetAnchor(TOPRIGHT, win, TOPRIGHT, -24, 70)

    -- Lista
    local listW = W - left - 40
    local listArea = WM:CreateControl("OmniAuraCatalogList", win, CT_CONTROL)
    listArea:SetAnchor(TOPLEFT, win, TOPLEFT, left, LIST_TOP)
    listArea:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -40, -LIST_BOTTOM)
    listArea:SetMouseEnabled(true)
    listArea:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    Cat.listArea = listArea

    Cat.visible = math.floor((H - LIST_TOP - LIST_BOTTOM) / ROW_H)
    for i = 1, Cat.visible do Cat.rows[i] = CreateRow(i, listW) end

    -- Barra de desplazamiento (control deslizante del juego, el mismo que usa LibAddonMenu)
    local sliderBg = OA.Display.Solid("OmniAuraCatalogSliderBg", win, 0, 0, 0, 0.5)
    sliderBg:SetWidth(14)
    sliderBg:SetAnchor(TOPLEFT, listArea, TOPRIGHT, 10, 0)
    sliderBg:SetAnchor(BOTTOMLEFT, listArea, BOTTOMRIGHT, 10, 0)

    local slider = WM:CreateControl("OmniAuraCatalogSlider", win, CT_SLIDER)
    slider:SetAnchor(TOPLEFT, sliderBg, TOPLEFT, 1, 0)
    slider:SetAnchor(BOTTOMRIGHT, sliderBg, BOTTOMRIGHT, -1, 0)
    slider:SetOrientation(ORIENTATION_VERTICAL)
    slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds", nil, 12, 40)
    slider:SetMouseEnabled(true)
    slider:SetValueStep(1)
    slider:SetMinMax(0, 1)
    slider:SetHandler("OnValueChanged", function(_, value)
        if Cat.updatingSlider then return end
        Cat.offset = zo_clamp(zo_round(value), 0, MaxOffset())
        Cat.RefreshRows()
    end)
    slider:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    Cat.slider = slider

    Cat.progress = Label("OmniAuraCatalogProgress", listArea, "ZoFontGameLarge", 0.8, 0.8, 0.8)
    Cat.progress:SetAnchor(CENTER, listArea, CENTER, 0, 0)
    Cat.progress:SetHidden(true)

    Cat.status = Label("OmniAuraCatalogStatus", win, "ZoFontGameSmall", 0.7, 0.7, 0.7)
    Cat.status:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, left, -14)

    Cat.RefreshRows()
end

---------------------------------------------------------------------------
-- API pública
---------------------------------------------------------------------------

-- Abre el catálogo para añadir efectos al trigger indicado (mode = "buff" | "proc").
function Cat.Open(aura, trig, mode)
    if not Cat.win then Build() end
    Cat.target = { aura = aura, trig = trig, mode = mode }
    Cat.targetLabel:SetText(string.format(L.CATALOG_TARGET, aura.name or "?"))
    Cat.status:SetText(L.CATALOG_HINT)
    Cat.win:SetHidden(false)

    local index = OA.AbilityIndex
    if index.IsReady() then
        RefreshCategories()
        Cat.Refilter()
        return
    end
    Cat.progress:SetHidden(false)
    Cat.progress:SetText(string.format(L.CATALOG_LOADING, 0))
    index.Build(function(progress)
        Cat.progress:SetText(string.format(L.CATALOG_LOADING, math.floor(progress * 100)))
    end, function()
        Cat.progress:SetHidden(true)
        RefreshCategories()
        Cat.Refilter()
    end)
end

function Cat.Hide()
    if not Cat.win then return end
    HideTooltip()
    Cat.win:SetHidden(true)
    Cat.target = nil
end

function Cat.IsShown()
    return Cat.win ~= nil and not Cat.win:IsHidden()
end
