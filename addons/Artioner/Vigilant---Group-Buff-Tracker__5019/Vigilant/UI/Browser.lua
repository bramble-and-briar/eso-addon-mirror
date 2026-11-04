-- Catálogo de efectos: ventana para buscar cualquier bufo o proc del juego por nombre y
-- categoría, y seguirlo o dejar de seguirlo con un clic. No hace falta saber IDs: todas
-- las variantes con el mismo nombre cuentan como el mismo bufo.
-- La lista es virtual: solo existen las filas visibles y se rellenan según el desplazamiento.

local VG = Vigilant
local L = VG.L
local WM = WINDOW_MANAGER

local B = { category = "active", offset = 0, results = {}, rows = {}, catRows = {} }
VG.Browser = B

local W, H = 780, 600
local SIDE_W = 200
local ROW_H = 34
local CAT_ROW_H = 22
local LIST_TOP = 104
local LIST_BOTTOM = 44
local SCROLL_STEP = 3
local GOLD = { 0.77, 0.69, 0.46, 1 }
local GREEN = { 0.4, 0.9, 0.4, 1 }
local GREY = { 0.55, 0.55, 0.55, 1 }
local TEX_ADD = {
    up = "EsoUI/Art/Buttons/plus_up.dds",
    over = "EsoUI/Art/Buttons/plus_over.dds",
    down = "EsoUI/Art/Buttons/plus_down.dds",
}
local TEX_UP = {
    up = "EsoUI/Art/Buttons/ScrollBox_UpArrow_Up.dds",
    over = "EsoUI/Art/Buttons/ScrollBox_UpArrow_Over.dds",
    down = "EsoUI/Art/Buttons/ScrollBox_UpArrow_Down.dds",
}
local TEX_DOWN = {
    up = "EsoUI/Art/Buttons/ScrollBox_DownArrow_Up.dds",
    over = "EsoUI/Art/Buttons/ScrollBox_DownArrow_Over.dds",
    down = "EsoUI/Art/Buttons/ScrollBox_DownArrow_Down.dds",
}
local TEX_REMOVE = {
    up = "EsoUI/Art/Buttons/decline_up.dds",
    over = "EsoUI/Art/Buttons/decline_over.dds",
    down = "EsoUI/Art/Buttons/decline_down.dds",
}

local function ClassLabel(classId)
    return zo_strformat(SI_CLASS_NAME, GetClassName(GENDER_MALE, classId))
end

-- cats: categorías del índice (ver AbilityIndex) que entran en cada entrada; nil = todas.
-- "active" y "tracked" no usan el índice: se ven al instante, sin esperar a que se cree.
local CATEGORIES = {
    { header = L.CAT_GROUP_QUICK },
    { key = "active", label = L.CAT_ACTIVE },
    { key = "tracked", label = L.CAT_TRACKED },
    { header = L.CAT_GROUP_GENERAL },
    { key = "all", label = L.CAT_ALL },
    { key = "buff", label = L.CAT_MAJOR_MINOR, cats = { buff = true } },
    { key = "gear", label = L.CAT_GEAR, cats = { gear = true } },
    { key = "consumable", label = L.CAT_CONSUMABLE, cats = { consumable = true } },
    { header = L.CAT_GROUP_CLASSES },
    { key = "dk", label = ClassLabel(1), cats = { dk = true } },
    { key = "sorc", label = ClassLabel(2), cats = { sorc = true } },
    { key = "nb", label = ClassLabel(3), cats = { nb = true } },
    { key = "templar", label = ClassLabel(6), cats = { templar = true } },
    { key = "warden", label = ClassLabel(4), cats = { warden = true } },
    { key = "necro", label = ClassLabel(5), cats = { necro = true } },
    { key = "arcanist", label = ClassLabel(117), cats = { arcanist = true } },
    { header = L.CAT_GROUP_OTHER },
    { key = "weapon", label = L.CAT_WEAPON, cats = { weapon = true } },
    { key = "armor", label = L.CAT_ARMOR, cats = { armor = true } },
    { key = "guild", label = L.CAT_GUILD, cats = { guild = true } },
    { key = "world", label = L.CAT_WORLD, cats = { world = true, ava = true } },
    { key = "misc", label = L.CAT_MISC, cats = { racial = true, mundus = true, companion = true, debuff = true, other = true } },
}
local CATEGORY_BY_KEY = {}
for _, c in ipairs(CATEGORIES) do
    if c.key then CATEGORY_BY_KEY[c.key] = c end
end

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------
-- Bufos seguidos ahora mismo, con el mismo formato que los grupos del índice.
local function TrackedEntries(query)
    local q = zo_strlower(VG.Utils.Trim(query))
    local out = {}
    for _, col in ipairs(VG.Tracker.columns) do
        local lname = zo_strlower(col.name)
        if q == "" or lname:find(q, 1, true) then
            out[#out + 1] = { display = col.name, lname = lname, icon = col.icon, ids = col.ids, iconId = col.ids[1], key = col.key }
        end
    end
    return out
end

local function IsTracked(g)
    return g.key ~= nil or VG.Catalog.IsNameTracked(g.display)
end

local function Toggle(g)
    local C = VG.Catalog
    if g.key then
        -- Desde "Seguidos": puede ser un bufo común o uno añadido por ID.
        if C.Get(g.key) then C.SetTracked(g.key, false) else C.RemoveCustom(g.key) end
    elseif IsTracked(g) then
        C.RemoveByName(g.display)
        B.status:SetText(string.format(L.BROWSER_REMOVED, g.display))
    else
        C.AddByName(g.display, g.iconId or g.ids[1])
        B.status:SetText(string.format(L.BROWSER_ADDED, g.display))
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

local function Move(g, delta)
    VG.Catalog.Move(g.key, delta)
    PlaySound(SOUNDS.DEFAULT_CLICK)
end

---------------------------------------------------------------------------
-- Lista virtual
---------------------------------------------------------------------------
local function MaxOffset()
    return math.max(0, #B.results - B.visible)
end

local function UpdateScrollbar()
    local maxOffset = MaxOffset()
    B.slider:SetHidden(maxOffset == 0)
    B.updatingSlider = true
    B.slider:SetMinMax(0, math.max(1, maxOffset))
    B.slider:SetValue(B.offset)
    B.updatingSlider = false
end

local function SetButtonTextures(b, textures)
    b:SetNormalTexture(textures.up)
    b:SetMouseOverTexture(textures.over)
    b:SetPressedTexture(textures.down)
end

function B.RefreshRows()
    -- En "Seguidos" cada fila tiene flechas para cambiar el orden de las columnas.
    local ordering = B.category == "tracked"
    for i, row in ipairs(B.rows) do
        local g = B.results[B.offset + i]
        row.group = g
        row:SetHidden(g == nil)
        if g then
            local tracked = IsTracked(g)
            local index = B.offset + i
            row.up:SetHidden(not ordering)
            row.down:SetHidden(not ordering)
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #B.results)
            row.info:ClearAnchors()
            row.info:SetAnchor(RIGHT, ordering and row.up or row.toggle, LEFT, -12, 0)
            row.icon:SetTexture(g.icon)
            row.name:SetText(g.display)
            if tracked then
                row.info:SetText(L.BROWSER_TRACKED)
                row.info:SetColor(unpack(GREEN))
            else
                row.info:SetText(#g.ids > 1 and string.format(L.BROWSER_VARIANTS, #g.ids) or "")
                row.info:SetColor(unpack(GREY))
            end
            SetButtonTextures(row.toggle, tracked and TEX_REMOVE or TEX_ADD)
        end
    end
    UpdateScrollbar()
end

function B.SetOffset(offset)
    B.offset = zo_clamp(math.floor(offset), 0, MaxOffset())
    B.RefreshRows()
end

local function Scroll(delta)
    B.SetOffset(B.offset - delta * SCROLL_STEP)
end

local function RefreshCategories()
    local counts = VG.AbilityIndex.counts
    local ready = VG.AbilityIndex.IsReady()
    for _, row in ipairs(B.catRows) do
        local c = row.category
        local n
        if not ready then
            n = nil
        elseif c.cats then
            n = 0
            for cat in pairs(c.cats) do n = n + (counts[cat] or 0) end
        elseif c.key == "all" then
            n = counts.all
        end
        row.label:SetText(n and string.format("%s |c888888(%s)|r", c.label, ZO_CommaDelimitNumber(n)) or c.label)
        row.selected:SetHidden(c.key ~= B.category)
    end
end

local function ShowProgress(text)
    B.progress:SetHidden(text == nil)
    if text then B.progress:SetText(text) end
end

-- La primera vez que se pide una categoría del índice se crea el de todo el juego
-- (unos segundos); mientras tanto se muestra el progreso.
local function BuildIndex()
    if B.indexing then return end
    B.indexing = true
    ShowProgress(string.format(L.BROWSER_LOADING, 0))
    VG.AbilityIndex.Build(function(progress)
        ShowProgress(string.format(L.BROWSER_LOADING, math.floor(progress * 100)))
    end, function()
        B.indexing = false
        RefreshCategories()
        B.Refilter()
    end)
end

function B.Refilter()
    local c = CATEGORY_BY_KEY[B.category]
    local query = B.search:GetText()
    local index = VG.AbilityIndex
    local waiting = false
    if c.key == "active" then
        B.results = index.Active(query)
    elseif c.key == "tracked" then
        B.results = TrackedEntries(query)
    elseif not index.IsReady() then
        B.results = {}
        waiting = true
        BuildIndex()
    else
        local out = {}
        for _, g in ipairs(index.Filter("all", query)) do
            if not c.cats or c.cats[g.cat] then out[#out + 1] = g end
        end
        B.results = out
    end
    if not waiting then
        if #B.results > 0 then
            ShowProgress(nil)
        else
            ShowProgress(c.key == "active" and L.BROWSER_NO_ACTIVE or L.BROWSER_EMPTY)
        end
    end
    B.count:SetText(string.format(L.BROWSER_COUNT, ZO_CommaDelimitNumber(#B.results)))
    B.SetOffset(0)
end

-- La llama el catálogo de bufos al cambiar la lista de seguidos o su orden. En
-- "Seguidos" se rehace la lista conservando el desplazamiento, para poder seguir
-- moviendo el mismo bufo con las flechas.
function B.OnTrackedChanged()
    if not B.win or B.win:IsHidden() then return end   -- la ventana se crea al abrirla
    if B.category == "tracked" then
        B.results = TrackedEntries(B.search:GetText())
        B.count:SetText(string.format(L.BROWSER_COUNT, ZO_CommaDelimitNumber(#B.results)))
        ShowProgress(#B.results == 0 and L.BROWSER_EMPTY or nil)
        B.SetOffset(B.offset)
    else
        B.RefreshRows()
    end
end

---------------------------------------------------------------------------
-- Construcción de la ventana
---------------------------------------------------------------------------
local function Label(name, parent, font, color)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontGame")
    label:SetColor(unpack(color or { 1, 1, 1, 1 }))
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function Solid(name, parent, r, g, b, a)
    local bd = WM:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(r, g, b, a)
    bd:SetEdgeColor(0, 0, 0, 0)
    return bd
end

local function ShowAbilityTooltip(row)
    local g = row.group
    InitializeTooltip(AbilityTooltip, B.win, TOPLEFT, 8, 0, TOPRIGHT)
    AbilityTooltip:SetAbilityId(g.iconId or g.ids[1])
end

local function HideAbilityTooltip()
    ClearTooltip(AbilityTooltip)
end

local function CreateRow(i, listW)
    local name = "VigilantBrowserRow" .. i
    local row = WM:CreateControl(name, B.listArea, CT_CONTROL)
    row:SetDimensions(listW, ROW_H)
    row:SetAnchor(TOPLEFT, B.listArea, TOPLEFT, 0, (i - 1) * ROW_H)
    row:SetMouseEnabled(true)

    row.hover = Solid(name .. "Hover", row, 1, 1, 1, 0.08)
    row.hover:SetAnchorFill(row)
    row.hover:SetHidden(true)

    row.icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(30, 30)
    row.icon:SetAnchor(LEFT, row, LEFT, 4, 0)

    row.toggle = WM:CreateControl(name .. "Toggle", row, CT_BUTTON)
    row.toggle:SetDimensions(28, 28)
    row.toggle:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.toggle:SetHandler("OnClicked", function() Toggle(row.group) end)

    -- Flechas de orden (solo en "Seguidos").
    row.down = WM:CreateControl(name .. "Down", row, CT_BUTTON)
    row.down:SetDimensions(22, 22)
    row.down:SetAnchor(RIGHT, row.toggle, LEFT, -8, 0)
    SetButtonTextures(row.down, TEX_DOWN)
    row.down:SetHandler("OnClicked", function() Move(row.group, 1) end)

    row.up = WM:CreateControl(name .. "Up", row, CT_BUTTON)
    row.up:SetDimensions(22, 22)
    row.up:SetAnchor(RIGHT, row.down, LEFT, -2, 0)
    SetButtonTextures(row.up, TEX_UP)
    row.up:SetHandler("OnClicked", function() Move(row.group, -1) end)

    row.info = Label(name .. "Info", row, "ZoFontGameSmall", GREY)
    row.info:SetAnchor(RIGHT, row.toggle, LEFT, -12, 0)

    row.name = Label(name .. "Name", row)
    row.name:SetDimensions(listW - 200, ROW_H)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetAnchor(LEFT, row.icon, RIGHT, 10, 0)

    local function Enter()
        row.hover:SetHidden(false)
        ShowAbilityTooltip(row)
    end
    local function Exit()
        row.hover:SetHidden(true)
        HideAbilityTooltip()
    end
    row:SetHandler("OnMouseEnter", Enter)
    row:SetHandler("OnMouseExit", Exit)
    row.toggle:SetHandler("OnMouseEnter", Enter)
    row.toggle:SetHandler("OnMouseExit", Exit)
    row:SetHandler("OnMouseDoubleClick", function() Toggle(row.group) end)
    row:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    return row
end

local function CreateCategoryRow(i, c)
    local name = "VigilantBrowserCat" .. i
    local row = WM:CreateControl(name, B.win, CT_CONTROL)
    row:SetDimensions(SIDE_W, CAT_ROW_H)
    row:SetAnchor(TOPLEFT, B.win, TOPLEFT, 16, 60 + (i - 1) * CAT_ROW_H)
    row.label = Label(name .. "Label", row, c.header and "ZoFontWinH5" or "ZoFontGame")
    row.label:SetAnchor(LEFT, row, LEFT, c.header and 2 or 12, 0)
    row.label:SetText(c.header or c.label)
    if c.header then
        row.label:SetColor(unpack(GOLD))
        return
    end

    row.category = c
    row.selected = Solid(name .. "Sel", row, 0.25, 0.45, 0.75, 0.45)
    row.selected:SetAnchorFill(row)
    row.selected:SetHidden(true)
    row.hover = Solid(name .. "Hover", row, 1, 1, 1, 0.08)
    row.hover:SetAnchorFill(row)
    row.hover:SetHidden(true)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseEnter", function() row.hover:SetHidden(false) end)
    row:SetHandler("OnMouseExit", function() row.hover:SetHidden(true) end)
    row:SetHandler("OnMouseUp", function(_, _, upInside)
        if not upInside then return end
        B.category = c.key
        B.status:SetText(c.key == "tracked" and L.BROWSER_ORDER_HINT or L.BROWSER_HINT)
        RefreshCategories()
        B.Refilter()
    end)
    B.catRows[#B.catRows + 1] = row
end

local function Build()
    local win = WM:CreateTopLevelWindow("VigilantBrowser")
    win:SetDimensions(W, H)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)
    B.win = win

    local bg = WM:CreateControlFromVirtual("VigilantBrowserBg", win, "ZO_DefaultBackdrop")
    bg:SetAnchorFill(win)

    local title = Label("VigilantBrowserTitle", win, "ZoFontWinH2")
    title:SetText(VG.title .. " - " .. L.BROWSER_TITLE)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 12)

    local close = WM:CreateControlFromVirtual("VigilantBrowserClose", win, "ZO_CloseButton")
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    close:SetHandler("OnClicked", function() B.Hide() end)

    for i, c in ipairs(CATEGORIES) do CreateCategoryRow(i, c) end

    local divider = Solid("VigilantBrowserDivider", win, 0.77, 0.69, 0.46, 0.3)
    divider:SetWidth(1)
    divider:SetAnchor(TOPLEFT, win, TOPLEFT, SIDE_W + 28, 60)
    divider:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, SIDE_W + 28, -LIST_BOTTOM)

    -- Búsqueda
    local left = SIDE_W + 44
    local searchLabel = Label("VigilantBrowserSearchLabel", win)
    searchLabel:SetText(L.BROWSER_SEARCH)
    searchLabel:SetAnchor(TOPLEFT, win, TOPLEFT, left, 66)

    local searchBg = WM:CreateControlFromVirtual("VigilantBrowserSearchBg", win, "ZO_EditBackdrop")
    searchBg:SetDimensions(280, 28)
    searchBg:SetAnchor(LEFT, searchLabel, RIGHT, 10, 0)
    local search = WM:CreateControlFromVirtual("VigilantBrowserSearch", searchBg, "ZO_DefaultEditForBackdrop")
    search:SetMaxInputChars(100)
    search:SetHandler("OnTextChanged", function()
        -- Espera a que el jugador deje de escribir antes de filtrar.
        B.filterToken = (B.filterToken or 0) + 1
        local token = B.filterToken
        zo_callLater(function()
            if token == B.filterToken then B.Refilter() end
        end, 250)
    end)
    search:SetHandler("OnEnter", function(self) self:LoseFocus() end)
    B.search = search

    B.count = Label("VigilantBrowserCount", win, "ZoFontGameSmall", GREY)
    B.count:SetAnchor(TOPRIGHT, win, TOPRIGHT, -24, 70)

    -- Lista
    local listW = W - left - 40
    local listArea = WM:CreateControl("VigilantBrowserList", win, CT_CONTROL)
    listArea:SetAnchor(TOPLEFT, win, TOPLEFT, left, LIST_TOP)
    listArea:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -40, -LIST_BOTTOM)
    listArea:SetMouseEnabled(true)
    listArea:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    B.listArea = listArea

    B.visible = math.floor((H - LIST_TOP - LIST_BOTTOM) / ROW_H)
    for i = 1, B.visible do B.rows[i] = CreateRow(i, listW) end

    -- Barra de desplazamiento (control deslizante del juego, el mismo que usa LibAddonMenu)
    local sliderBg = Solid("VigilantBrowserSliderBg", win, 0, 0, 0, 0.5)
    sliderBg:SetWidth(14)
    sliderBg:SetAnchor(TOPLEFT, listArea, TOPRIGHT, 10, 0)
    sliderBg:SetAnchor(BOTTOMLEFT, listArea, BOTTOMRIGHT, 10, 0)

    local slider = WM:CreateControl("VigilantBrowserSlider", win, CT_SLIDER)
    slider:SetAnchor(TOPLEFT, sliderBg, TOPLEFT, 1, 0)
    slider:SetAnchor(BOTTOMRIGHT, sliderBg, BOTTOMRIGHT, -1, 0)
    slider:SetOrientation(ORIENTATION_VERTICAL)
    slider:SetThumbTexture("EsoUI/Art/Miscellaneous/scrollbox_elevator.dds",
        "EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds", nil, 12, 40)
    slider:SetMouseEnabled(true)
    slider:SetValueStep(1)
    slider:SetMinMax(0, 1)
    slider:SetHandler("OnValueChanged", function(_, value)
        if B.updatingSlider then return end
        B.offset = zo_clamp(zo_round(value), 0, MaxOffset())
        B.RefreshRows()
    end)
    slider:SetHandler("OnMouseWheel", function(_, delta) Scroll(delta) end)
    B.slider = slider

    B.progress = Label("VigilantBrowserProgress", listArea, "ZoFontGameLarge", { 0.8, 0.8, 0.8, 1 })
    B.progress:SetAnchor(CENTER, listArea, CENTER, 0, 0)
    B.progress:SetHidden(true)

    B.status = Label("VigilantBrowserStatus", win, "ZoFontGameSmall", { 0.7, 0.7, 0.7, 1 })
    B.status:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, left, -14)

    -- Se cierra con la escena desde la que se abrió (Ajustes o el modo cursor), para no
    -- quedarse abierta sin ratón.
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, newState)
        if scene == B.scene and newState == SCENE_HIDDEN then B.Hide() end
    end)
end

---------------------------------------------------------------------------
-- API pública
---------------------------------------------------------------------------
-- category: categoría con la que se abre (p. ej. "tracked" para ordenar); nil = la última.
function B.Open(category)
    if not B.win then Build() end
    B.hideToken = (B.hideToken or 0) + 1   -- cancela la liberación pendiente del índice
    if category then B.category = category end
    if not SCENE_MANAGER:IsInUIMode() then SCENE_MANAGER:SetInUIMode(true) end
    B.scene = SCENE_MANAGER:GetCurrentScene()
    B.status:SetText(B.category == "tracked" and L.BROWSER_ORDER_HINT or L.BROWSER_HINT)
    B.win:SetHidden(false)
    RefreshCategories()
    B.Refilter()
end

-- Si sigue cerrado tras RELEASE_MS se suelta el índice (ver AbilityIndex.Release).
local RELEASE_MS = 5 * 60 * 1000

function B.Hide()
    HideAbilityTooltip()
    B.win:SetHidden(true)
    B.scene = nil
    B.hideToken = (B.hideToken or 0) + 1
    local token = B.hideToken
    zo_callLater(function()
        if token ~= B.hideToken or not B.win:IsHidden() then return end
        B.results = {}
        VG.AbilityIndex.Release()
    end, RELEASE_MS)
end
