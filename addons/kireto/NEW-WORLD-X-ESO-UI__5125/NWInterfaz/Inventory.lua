-- Paneles de inventario estilo New World con diseño plano:
-- mochila, banco personal / almacén de casa y banco de gremio.
local NWUI = NWInterfaz
local INV = {}
NWUI.Inventory = INV

local WM = WINDOW_MANAGER
local C, F = NWUI.C, NWUI.F

local PAD, COLGAP, SEC_H, FOOTER_H, SB_W = 14, 20, 32, 70, 8
local PRICE_H = 15
local TOP_MARGIN, BOTTOM_MARGIN = 100, 120
local function GAP() return NWUI.sv.inv.iconGap or 7 end
local SORT_FONT = "$(BOLD_FONT)|15|soft-shadow-thin"
INV.TOP_MARGIN = TOP_MARGIN

-- =====================================================================
-- Categorías (orden de aparición)
-- =====================================================================
local CATS = {
    { key = "weapons" },
    { key = "armor_light" },
    { key = "armor_medium" },
    { key = "armor_heavy" },
    { key = "armor" },
    { key = "jewelry" },
    { key = "consumables" },
    { key = "glyphs" },
    { key = "containers" },
    { key = "blacksmith" },
    { key = "clothier" },
    { key = "wood" },
    { key = "jewelcraft" },
    { key = "enchanting" },
    { key = "alchemy" },
    { key = "provisioning" },
    { key = "style" },
    { key = "furnishing" },
    { key = "recipes" },
    { key = "misc" },
    { key = "junk" },
}
-- nombres traducidos al vuelo (idioma del juego)
for _, c in ipairs(CATS) do
    setmetatable(c, { __index = function(t, k) if k == "name" then return NWUI.T("cat_" .. t.key) end end })
end

local TYPE_CAT = {}
local function map(key, ...)
    for _, n in ipairs({ ... }) do
        local v = _G[n]
        if v ~= nil then TYPE_CAT[v] = key end
    end
end
map("weapons", "ITEMTYPE_WEAPON")
map("armor", "ITEMTYPE_ARMOR", "ITEMTYPE_DISGUISE", "ITEMTYPE_COSTUME")
map("consumables", "ITEMTYPE_POTION", "ITEMTYPE_POISON", "ITEMTYPE_FOOD", "ITEMTYPE_DRINK", "ITEMTYPE_SOUL_GEM",
    "ITEMTYPE_TOOL", "ITEMTYPE_CROWN_REPAIR", "ITEMTYPE_AVA_REPAIR", "ITEMTYPE_SIEGE", "ITEMTYPE_CROWN_ITEM",
    "ITEMTYPE_RECALL_STONE", "ITEMTYPE_GROUP_REPAIR")
map("glyphs", "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY")
map("containers", "ITEMTYPE_CONTAINER", "ITEMTYPE_CONTAINER_CURRENCY", "ITEMTYPE_TREASURE", "ITEMTYPE_TROPHY",
    "ITEMTYPE_COLLECTIBLE", "ITEMTYPE_MASTER_WRIT")
map("blacksmith", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER")
map("clothier", "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER")
map("wood", "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER")
map("jewelcraft", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRY_RAW_TRAIT",
    "ITEMTYPE_JEWELRY_TRAIT")
map("enchanting", "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE",
    "ITEMTYPE_ENCHANTING_RUNE_POTENCY", "ITEMTYPE_ENCHANTMENT_BOOSTER")
map("alchemy", "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE", "ITEMTYPE_REAGENT")
map("provisioning", "ITEMTYPE_INGREDIENT", "ITEMTYPE_SPICE", "ITEMTYPE_FLAVORING", "ITEMTYPE_ADDITIVE")
map("style", "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT",
    "ITEMTYPE_ARMOR_BOOSTER", "ITEMTYPE_WEAPON_BOOSTER")
map("furnishing", "ITEMTYPE_FURNISHING", "ITEMTYPE_FURNISHING_MATERIAL")
map("recipes", "ITEMTYPE_RECIPE", "ITEMTYPE_RACIAL_STYLE_MOTIF")

local function CategoryOf(d)
    if d.junk then return "junk" end
    if d.itemType == ITEMTYPE_ARMOR and (d.equipType == EQUIP_TYPE_NECK or d.equipType == EQUIP_TYPE_RING) then
        return "jewelry"
    end
    if d.itemType == ITEMTYPE_ARMOR then
        if ARMORTYPE_LIGHT and d.armorType == ARMORTYPE_LIGHT then return "armor_light" end
        if ARMORTYPE_MEDIUM and d.armorType == ARMORTYPE_MEDIUM then return "armor_medium" end
        if ARMORTYPE_HEAVY and d.armorType == ARMORTYPE_HEAVY then return "armor_heavy" end
    end
    return TYPE_CAT[d.itemType] or "misc"
end

local SORTS = {
    quality = function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        return a.slotIndex < b.slotIndex
    end,
    name = function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.slotIndex < b.slotIndex
    end,
    value = function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        if a.name ~= b.name then return a.name < b.name end
        return a.slotIndex < b.slotIndex
    end,
}

-- =====================================================================
-- Lectura de bolsas
-- =====================================================================
local function BagSlots(bag)
    if BAG_VIRTUAL and bag == BAG_VIRTUAL then
        local id
        return function()
            if not GetNextVirtualBagSlotId then return nil end
            id = GetNextVirtualBagSlotId(id)
            return id
        end
    end
    if bag == BAG_GUILDBANK then
        local id
        return function()
            id = GetNextGuildBankSlotId(id)
            return id
        end
    end
    local size = GetBagSize(bag) or 0
    local i = -1
    return function()
        i = i + 1
        if i < size then return i end
    end
end

-- Objetos nuevos: el juego los marca al recogerlos (SHARED_INVENTORY) y
-- quita la marca al pasar el ratón por encima.
-- Respaldo propio: el aviso del juego llega con "es nuevo" en el evento; se
-- guarda por si la marca del juego todavía no está lista al redibujar.
local ownNew = {}
local function NewKey(bag, slot) return tostring(bag) .. ":" .. tostring(slot) end
function INV.MarkNew(bag, slot)
    ownNew[NewKey(bag, slot)] = { bag = bag, slot = slot, t = GetFrameTimeSeconds() }
end
function INV.ForgetNew(bag, slot) ownNew[NewKey(bag, slot)] = nil end

local function NewInfo(bag, slot)
    local own = ownNew[NewKey(bag, slot)]
    own = own and own.t
    if not SHARED_INVENTORY:IsItemNew(bag, slot) then
        if own then return true, own end
        return false, 0
    end
    local sd = SHARED_INVENTORY:GenerateSingleSlotData(bag, slot)
    return true, (sd and sd.age) or 0
end
INV.NewInfo = NewInfo

-- Los nuevos van primero (el más reciente arriba) dentro de su sección
local function NewFirst(cmp)
    return function(a, b)
        local an, bn = a.isNew == true, b.isNew == true
        if an ~= bn then return an end
        if an and a.age ~= b.age then return (a.age or 0) > (b.age or 0) end
        return cmp(a, b)
    end
end

local function ReadItem(bag, slot, kind)
    local icon, stack, sellPrice, meets, locked, equipType, _, quality = GetItemInfo(bag, slot)
    if not stack or stack <= 0 then return nil end
    quality = GetItemDisplayQuality(bag, slot)
    local d = {
        kind = kind, bagId = bag, slotIndex = slot, hasItem = true,
        icon = icon, stack = stack, value = (sellPrice or 0) * stack, meets = meets,
        equipType = equipType, quality = quality or 1,
        itemType = GetItemType(bag, slot),
        junk = IsItemJunk(bag, slot),
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bag, slot)),
        tooltipSide = "left",
    }
    if d.itemType == ITEMTYPE_ARMOR and GetItemArmorType then d.armorType = GetItemArmorType(bag, slot) end
    d.locked = (IsItemPlayerLocked(bag, slot)) or locked
    d.equippable = equipType ~= nil and equipType ~= 0 and equipType ~= EQUIP_TYPE_INVALID
    d.usable = (IsItemUsable(bag, slot)) or false
    if d.equippable and DoesItemHaveDurability(bag, slot) then
        d.condition = GetItemCondition(bag, slot)
    end
    if kind == "craft" then
        d.slotType = SLOT_TYPE_CRAFT_BAG_ITEM
    elseif kind == "guild" then
        d.slotType = SLOT_TYPE_GUILD_BANK_ITEM
    elseif kind == "bank" then
        d.slotType = SLOT_TYPE_BANK_ITEM
    else
        d.slotType = SLOT_TYPE_ITEM
    end
    d.searchName = zo_strlower(d.name)
    if kind ~= "guild" then d.isNew, d.age = NewInfo(bag, slot) end
    return d
end

-- =====================================================================
-- Monedas
-- =====================================================================
local FALLBACK_ICON = {}
FALLBACK_ICON[CURT_MONEY] = "EsoUI/Art/currency/currency_gold.dds"
FALLBACK_ICON[CURT_ALLIANCE_POINTS] = "EsoUI/Art/currency/alliancePoints.dds"
FALLBACK_ICON[CURT_TELVAR_STONES] = "EsoUI/Art/currency/currency_telvar.dds"
FALLBACK_ICON[CURT_WRIT_VOUCHERS] = "EsoUI/Art/currency/currency_writvoucher.dds"

local function CurrencyText(ct, loc, iconSize)
    if ct == nil then return nil end
    loc = loc or GetCurrencyPlayerStoredLocation(ct)
    local amt = GetCurrencyAmount(ct, loc)
    local icon = ""
    local i = ZO_Currency_GetKeyboardFormattedCurrencyIcon(ct, iconSize or 22)
    if type(i) == "string" then icon = i end
    if icon == "" and FALLBACK_ICON[ct] then icon = zo_iconFormat(FALLBACK_ICON[ct], iconSize or 22, iconSize or 22) end
    return icon .. " " .. ZO_CommaDelimitNumber(amt)
end

-- =====================================================================
-- Panel
-- =====================================================================
local ARROW_OPEN   = "EsoUI/Art/Buttons/tree_open_up.dds"
local ARROW_CLOSED = "EsoUI/Art/Buttons/tree_closed_up.dds"
local ARROW_W = 18

local function CreateSection(parent)
    local s = WM:CreateControl(NWUI.UID("NWUI_Sec"), parent, CT_CONTROL)
    s:SetHeight(SEC_H - 6)
    -- Flecha para plegar / desplegar (dos texturas que se funden entre sí)
    s.arrowOpen = NWUI.Tex(s, nil, 3)
    s.arrowOpen:SetTexture(ARROW_OPEN)
    s.arrowOpen:SetDimensions(ARROW_W, ARROW_W)
    s.arrowOpen:SetAnchor(BOTTOMLEFT, s, BOTTOMLEFT, -3, -5)
    s.arrowClosed = NWUI.Tex(s, nil, 3)
    s.arrowClosed:SetTexture(ARROW_CLOSED)
    s.arrowClosed:SetDimensions(ARROW_W, ARROW_W)
    s.arrowClosed:SetAnchor(BOTTOMLEFT, s, BOTTOMLEFT, -3, -5)
    s.arrowState = 1   -- 1 = abierto, 0 = plegado
    s.name = NWUI.Label(s, F.section, C.text, "")
    s.name:SetAnchor(BOTTOMLEFT, s, BOTTOMLEFT, ARROW_W, -3)
    s.hl = NWUI.Tex(s, {1, 1, 1, 0.05}, 0)
    s.hl:SetAnchorFill(s)
    s.hl:SetHidden(true)
    s:SetMouseEnabled(true)
    s:SetHandler("OnMouseEnter", function(self) if self.key then self.hl:SetHidden(false) end end)
    s:SetHandler("OnMouseExit", function(self) self.hl:SetHidden(true) end)
    s:SetHandler("OnMouseUp", function(self, button, inside)
        if inside and button == MOUSE_BUTTON_INDEX_LEFT and self.key and self.panel then
            self.panel:ToggleGroup(self.key)
        end
    end)
    s:SetHandler("OnMouseWheel", function(self, delta)
        if self.panel then self.panel:ScrollBy(-delta * 90) end
    end)
    s:SetHandler("OnReceiveDrag", function(self)
        if self.panel then self.panel:ReceiveDrop() end
    end)
    s.count = NWUI.Label(s, F.small, C.textDim, "")
    s.count:SetAnchor(BOTTOMRIGHT, s, BOTTOMRIGHT, 0, -4)
    -- pista en su propia línea, debajo del título (no se encima con él)
    s.hint = NWUI.Label(s, "$(BOLD_FONT)|14|soft-shadow-thick", C.gold, "")
    s.hint:SetAnchor(TOPLEFT, s, BOTTOMLEFT, 0, 4)
    s.hint:SetAnchor(TOPRIGHT, s, BOTTOMRIGHT, 0, 4)   -- ancho de la sección: el texto largo baja de línea
    -- la letra de los títulos es ancha: el nombre se recorta antes del número
    s.name:SetAnchor(BOTTOMRIGHT, s, BOTTOMRIGHT, -30, -3)
    if s.name.SetMaxLineCount then s.name:SetMaxLineCount(1) end
    if s.name.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then s.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    s.line = NWUI.Tex(s, C.sectionLine, 1)
    s.line:SetAnchor(BOTTOMLEFT, s, BOTTOMLEFT, 0, 0)
    s.line:SetAnchor(BOTTOMRIGHT, s, BOTTOMRIGHT, 0, 0)
    s.line:SetHeight(1)
    return s
end

local Panel = ZO_Object:Subclass()

function Panel:New(...)
    local o = ZO_Object.New(self)
    o:Initialize(...)
    return o
end

function Panel:Initialize(id, title, family)
    self.id, self.title, self.family = id, title, family
    self.search = ""
    self.scroll = 0
    self.contentH = 0

    local tlw = WM:CreateTopLevelWindow("NWUI_Panel_" .. id)
    self.tlw = tlw
    tlw:SetHidden(true)
    tlw:SetClampedToScreen(true)
    -- Fondo negro translúcido (como el cuadro de la montura) con borde fino
    self.panelBgTex = NWUI.EdgeBox(tlw, {0, 0, 0, (NWUI.sv.inv.panelAlpha or 62) / 100}, C.panelBorder)

    -- ---------------- Cabecera ----------------
    local hdr = WM:CreateControl(NWUI.UID("NWUI_Hdr"), tlw, CT_CONTROL)
    self.header = hdr
    hdr:SetAnchor(TOPLEFT, tlw, TOPLEFT, 1, 1)
    hdr:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -1, 1)
    local hbg = NWUI.Tex(hdr, C.headerBg, 1)
    hbg:SetAnchorFill(hdr)
    local hline = NWUI.Tex(hdr, C.headerLine, 2)
    hline:SetAnchor(BOTTOMLEFT, hdr, BOTTOMLEFT, 0, 0)
    hline:SetAnchor(BOTTOMRIGHT, hdr, BOTTOMRIGHT, 0, 0)
    hline:SetHeight(2)

    -- contenedor del título (las letras se colocan dentro, ver NWUI.SetTitle)
    self.titleLabel = WM:CreateControl(NWUI.UID("NWUI_Title"), hdr, CT_CONTROL)
    self.titleLabel.SetText = function() end   -- compatibilidad: el texto va en las letras
    self.titleLabel:SetAnchor(TOPLEFT, hdr, TOPLEFT, PAD + 4, 10)
    self.capLabel = NWUI.Label(hdr, F.cap, C.text, "")
    self.capLabel:SetAnchor(TOPRIGHT, hdr, TOPRIGHT, -PAD, 12)
    self:BuildLock(hdr)
    NWUI.SetTitle(self.titleLabel, title)

    local y = 50
    if family ~= "backpack" then
        self.subLabel = NWUI.Label(hdr, F.small, C.textDim, "")
        if family == "guild" then
            local prevA = NWUI.Label(hdr, F.body, C.gold, "«")
            prevA:SetAnchor(TOPLEFT, hdr, TOPLEFT, PAD + 4, 46)
            prevA:SetMouseEnabled(true)
            prevA:SetHandler("OnMouseUp", function(_, b, inside) if inside then self:CycleGuild(-1) end end)
            self.subLabel:SetAnchor(LEFT, prevA, RIGHT, 10, 0)
            local nextA = NWUI.Label(hdr, F.body, C.gold, "»")
            nextA:SetAnchor(LEFT, self.subLabel, RIGHT, 10, 0)
            nextA:SetMouseEnabled(true)
            nextA:SetHandler("OnMouseUp", function(_, b, inside) if inside then self:CycleGuild(1) end end)
        else
            self.subLabel:SetAnchor(TOPLEFT, hdr, TOPLEFT, PAD + 4, 48)
        end
        y = 76
    end

    -- Barra de capacidad (plana)
    self.capTrack = NWUI.Tex(hdr, C.trackBg, 2)
    self.capTrack:SetAnchor(TOPLEFT, hdr, TOPLEFT, PAD, y)
    self.capTrack:SetAnchor(TOPRIGHT, hdr, TOPRIGHT, -PAD, y)
    self.capTrack:SetHeight(6)
    self.capFill = NWUI.Tex(hdr, C.capFill, 3)
    self.capFill:SetAnchor(TOPLEFT, self.capTrack, TOPLEFT, 0, 0)
    self.capFill:SetAnchor(BOTTOMLEFT, self.capTrack, BOTTOMLEFT, 0, 0)
    self.capFill:SetWidth(0)
    y = y + 16

    -- Búsqueda
    local sbox = WM:CreateControl(NWUI.UID("NWUI_SBox"), hdr, CT_CONTROL)
    sbox:SetAnchor(TOPLEFT, hdr, TOPLEFT, PAD, y)
    sbox:SetDimensions(185, 28)
    self.searchEdge = NWUI.FlatBox(sbox, {0.04, 0.07, 0.12, 1}, {0.25, 0.33, 0.45, 1}, 1)
    local edit = WM:CreateControl(NWUI.UID("NWUI_Search"), sbox, CT_EDITBOX)
    edit:SetFont(F.body)
    NWUI.SetColor(edit, C.text)
    edit:SetAnchor(TOPLEFT, sbox, TOPLEFT, 8, 4)
    edit:SetAnchor(BOTTOMRIGHT, sbox, BOTTOMRIGHT, -8, -2)
    edit:SetMaxInputChars(40)
    edit:SetMouseEnabled(true)
    if edit.SetEditEnabled then edit:SetEditEnabled(true) end
    edit:SetDrawLevel(5)
    local ph = NWUI.Label(sbox, F.body, C.textDim, NWUI.T("search"))
    ph:SetAnchor(LEFT, sbox, LEFT, 10, 0)
    edit:SetHandler("OnTextChanged", function(e)
        local t = e:GetText() or ""
        ph:SetHidden(t ~= "")
        self.search = zo_strlower(t)
        self.scroll = 0
        NWUI.Throttle("NWUI_Search_" .. id, 180, function() self:Refresh() end)
    end)
    -- Un cuadro de texto creado por código no toma el foco solo al hacer clic
    -- (las plantillas del juego lo hacen con TakeFocus en OnMouseDown).
    edit:SetHandler("OnMouseDown", function(e) e:TakeFocus() end)
    -- Clic en cualquier parte del recuadro (incluido "Buscar…") también enfoca.
    sbox:SetMouseEnabled(true)
    sbox:SetHandler("OnMouseDown", function() edit:TakeFocus() end)
    edit:SetHandler("OnFocusGained", function()
        NWUI.SetColor(self.searchEdge, {0.89, 0.74, 0.40, 1})
        PlaySound(SOUNDS.EDIT_CLICK)
    end)
    edit:SetHandler("OnFocusLost", function()
        NWUI.SetColor(self.searchEdge, {0.25, 0.33, 0.45, 1})
    end)
    -- Esc: primero borra la búsqueda; si ya está vacía, suelta el foco.
    edit:SetHandler("OnEscape", function(e)
        if (e:GetText() or "") ~= "" then e:SetText("") else e:LoseFocus() end
    end)
    edit:SetHandler("OnEnter", function(e) e:LoseFocus() end)
    -- Clic derecho en el recuadro: borrar la búsqueda.
    sbox:SetHandler("OnMouseUp", function(_, button, inside)
        if inside and button == MOUSE_BUTTON_INDEX_RIGHT then edit:SetText("") end
    end)
    self.edit = edit

    -- Orden
    local sorts = { { "quality", NWUI.T("sort_quality") }, { "name", NWUI.T("sort_name") }, { "value", NWUI.T("sort_value") } }
    self.sortLabels = {}
    local prev
    for i = #sorts, 1, -1 do
        local key, text = sorts[i][1], sorts[i][2]
        local l = NWUI.Label(hdr, SORT_FONT, C.textDim, text)
        if prev then
            l:SetAnchor(RIGHT, prev, LEFT, -18, 0)
        else
            l:SetAnchor(RIGHT, hdr, TOPRIGHT, -PAD, y + 14)
        end
        l:SetMouseEnabled(true)
        l:SetHandler("OnMouseUp", function(_, b, inside)
            if inside then
                NWUI.sv.inv.sort = key
                INV.RefreshAll()
            end
        end)
        local u = NWUI.Tex(l, C.gold, 9)
        u:SetAnchor(TOPLEFT, l, BOTTOMLEFT, 0, 2)
        u:SetAnchor(TOPRIGHT, l, BOTTOMRIGHT, 0, 2)
        u:SetHeight(2)
        l.underline = u
        l.key = key
        self.sortLabels[#self.sortLabels + 1] = l
        prev = l
    end
    local ord = NWUI.Label(hdr, SORT_FONT, C.textDim, NWUI.T("sort"))
    ord:SetAnchor(RIGHT, prev, LEFT, -14, 0)

    hdr:SetHeight(y + 28 + 12)

    -- ---------------- Pie ----------------
    local foot = WM:CreateControl(NWUI.UID("NWUI_Foot"), tlw, CT_CONTROL)
    foot:SetAnchor(BOTTOMLEFT, tlw, BOTTOMLEFT, 1, -1)
    foot:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -1, -1)
    foot:SetHeight(FOOTER_H)
    local fl = NWUI.Tex(foot, C.sectionLine, 2)
    fl:SetAnchor(TOPLEFT, foot, TOPLEFT, 0, 0)
    fl:SetAnchor(TOPRIGHT, foot, TOPRIGHT, 0, 0)
    fl:SetHeight(1)
    self.footLabel = NWUI.Label(foot, "$(MEDIUM_FONT)|18|soft-shadow-thin", C.text, "")
    self.footLabel:SetAnchor(TOPLEFT, foot, TOPLEFT, PAD, 8)
    self.footRight = NWUI.Label(foot, F.hint, {1, 1, 1, 1}, "")
    self.footRight:SetAnchor(TOPRIGHT, foot, TOPRIGHT, -PAD, 8)
    self:BuildFundsButton(foot)
    -- Fila de respaldo (espacio + oro) por si la barra original no está disponible
    self.infoRow = WM:CreateControl(NWUI.UID("NWUI_InfoRow"), foot, CT_CONTROL)
    self.infoRow:SetAnchor(BOTTOMLEFT, foot, BOTTOMLEFT, PAD, -6)
    self.infoRow:SetAnchor(BOTTOMRIGHT, foot, BOTTOMRIGHT, -PAD, -6)
    self.infoRow:SetHeight(26)
    self.foot = foot
    self.spaceLabel = NWUI.Label(self.infoRow, "$(MEDIUM_FONT)|18|soft-shadow-thin", C.text, "")
    self.spaceLabel:SetAnchor(LEFT, self.infoRow, LEFT, 0, 0)
    self.goldLabel = NWUI.Label(self.infoRow, F.gold, C.text, "")
    self.goldLabel:SetAnchor(RIGHT, self.infoRow, RIGHT, 0, 0)

    -- ---------------- Lista con desplazamiento ----------------
    local area = WM:CreateControl(NWUI.UID("NWUI_Area"), tlw, CT_SCROLL)
    area:SetAnchor(TOPLEFT, hdr, BOTTOMLEFT, PAD - 1, 10)
    area:SetAnchor(BOTTOMRIGHT, foot, TOPRIGHT, -(PAD + SB_W + 6), -6)
    area:SetMouseEnabled(true)
    area:SetHandler("OnMouseWheel", function(_, delta) self:ScrollBy(-delta * 90) end)
    area:SetHandler("OnReceiveDrag", function() self:ReceiveDrop() end)
    area:SetHandler("OnMouseUp", function(_, b, inside)
        if inside and b == MOUSE_BUTTON_INDEX_LEFT and GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then
            self:ReceiveDrop()
        end
    end)
    local content = WM:CreateControl(NWUI.UID("NWUI_Content"), area, CT_CONTROL)
    content:SetAnchor(TOPLEFT, area, TOPLEFT, 0, 0)
    self.area, self.content = area, content

    -- Riel y barra: controles con ratón propio; al arrastrarlos la ventana
    -- NO se mueve (se desactiva el movimiento mientras dura el arrastre).
    self.track = WM:CreateControl(NWUI.UID("NWUI_Track"), tlw, CT_CONTROL)
    self.track:SetAnchor(TOPLEFT, area, TOPRIGHT, 3, 0)
    self.track:SetAnchor(BOTTOMLEFT, area, BOTTOMRIGHT, 3, 0)
    self.track:SetWidth(SB_W + 6)
    local trackBg = NWUI.Tex(self.track, C.trackBg, 1)
    trackBg:SetAnchor(TOP, self.track, TOP, 0, 0)
    trackBg:SetAnchor(BOTTOM, self.track, BOTTOM, 0, 0)
    trackBg:SetWidth(SB_W)
    self.track:SetMouseEnabled(true)
    self.track:SetHandler("OnMouseDown", function(_, b)
        if b ~= MOUSE_BUTTON_INDEX_LEFT then return end
        -- clic en el riel: salta una página hacia ese lado
        local _, my = GetUIMousePosition()
        local page = self.area:GetHeight() * 0.9
        if my < self.thumb:GetTop() then self:ScrollBy(-page) elseif my > self.thumb:GetBottom() then self:ScrollBy(page) end
    end)
    self.track:SetHandler("OnMouseWheel", function(_, delta) self:ScrollBy(-delta * 90) end)

    self.thumb = WM:CreateControl(NWUI.UID("NWUI_Thumb"), tlw, CT_CONTROL)
    self.thumb:SetWidth(SB_W + 6)
    self.thumb:SetDrawLevel(5)
    local thumbFill = NWUI.Tex(self.thumb, C.scrollThumb, 1)
    thumbFill:SetAnchor(TOP, self.thumb, TOP, 0, 0)
    thumbFill:SetAnchor(BOTTOM, self.thumb, BOTTOM, 0, 0)
    thumbFill:SetWidth(SB_W)
    self.thumb:SetMouseEnabled(true)
    self.thumb:SetHandler("OnMouseDown", function(_, b)
        if b == MOUSE_BUTTON_INDEX_LEFT then
            local _, my = GetUIMousePosition()
            self.drag = { y = my, s = self.scroll }
            self.tlw:SetMovable(false)
        end
    end)
    self.thumb:SetHandler("OnMouseUp", function()
        self.drag = nil
        self:ApplyLock()
    end)
    self.thumb:SetHandler("OnMouseWheel", function(_, delta) self:ScrollBy(-delta * 90) end)
    tlw:SetHandler("OnUpdate", function()
        if self.drag then
            local _, my = GetUIMousePosition()
            local trackH, th = self.track:GetHeight(), self.thumb:GetHeight()
            local maxS = math.max(0, self.contentH - self.area:GetHeight())
            local ratio = maxS / math.max(1, trackH - th)
            self:SetScroll(self.drag.s + (my - self.drag.y) * ratio)
        end
    end)

    self.emptyLabel = NWUI.Label(tlw, F.body, C.textDim, "")
    self.emptyLabel:SetAnchor(TOP, area, TOP, 0, 40)

    -- Pools
    self.slotPool = ZO_ObjectPool:New(function()
        local s = NWUI.Slot.Create(content)
        s.panel = self
        return s
    end, function(s)
        s:SetHidden(true)
        s:ClearAnchors()
        s:SetAlpha(1)
    end)
    self.secPool = ZO_ObjectPool:New(function()
        local sec = CreateSection(content)
        sec.panel = self
        return sec
    end, function(s)
        s:SetHidden(true)
        s:ClearAnchors()
        s.key = nil
        s.hl:SetHidden(true)
        s.hint:SetText("")
    end)

    self.cardPool = ZO_ObjectPool:New(function() return INV.CreateCard(content) end, function(c)
        c:SetHidden(true)
        c:ClearAnchors()
    end)
    self.view = "items"

    -- Fragmento de escena
    self.fragment = NWUI.SafeFragment(tlw, 120)
    self.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            self:OnShowing()
        elseif newState == SCENE_FRAGMENT_HIDDEN then
            self.drag = nil
            if self.edit then self.edit:LoseFocus() end
        end
    end)

    self.movable = NWUI.RegisterMovable(tlw, "panel_" .. id, function(c)
        c:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -48, TOP_MARGIN)
    end, title, true, function(delta, shift)
        local s = NWUI.sv.inv
        if shift then
            s.iconGap = zo_clamp((s.iconGap or 7) + delta, 2, 20)
        else
            s.iconSize = zo_clamp(s.iconSize + delta * 2, 36, 80)
        end
        INV.ResizeAll()
    end)
    self:ApplyLock()
end

-- ---------------- Candado (fijar la posición del panel) ----------------
local LOCK_GOLD = {0.89, 0.74, 0.40, 1}
local LOCK_DIM  = {0.55, 0.55, 0.57, 1}

function Panel:IsLocked()
    local locks = NWUI.sv.inv.panelLocks
    return locks and locks[self.id] == true
end

function Panel:BuildLock(hdr)
    local b = WM:CreateControl(NWUI.UID("NWUI_Lock"), hdr, CT_CONTROL)
    b:SetDimensions(24, 26)
    b:SetAnchor(RIGHT, self.capLabel, LEFT, -9, 0)
    b:SetMouseEnabled(true)
    -- candado plano dibujado con rectángulos (cuerpo + arco)
    local body = NWUI.Tex(b, LOCK_GOLD, 3)
    body:SetDimensions(16, 11)
    body:SetAnchor(BOTTOM, b, BOTTOM, 0, -3)
    local hole = NWUI.Tex(b, {0.05, 0.08, 0.13, 1}, 4)
    hole:SetDimensions(2, 4)
    hole:SetAnchor(CENTER, body, CENTER, 0, 0)
    local left = NWUI.Tex(b, LOCK_GOLD, 3)
    left:SetWidth(2)
    local right = NWUI.Tex(b, LOCK_GOLD, 3)
    right:SetWidth(2)
    local top = NWUI.Tex(b, LOCK_GOLD, 3)
    top:SetDimensions(12, 2)
    b.body, b.left, b.right, b.top = body, left, right, top
    b:SetHandler("OnMouseEnter", function(ctrl)
        InitializeTooltip(InformationTooltip, ctrl, BOTTOM, 0, -6, TOP)
        SetTooltipText(InformationTooltip, self:IsLocked()
            and NWUI.T("lock_on")
            or NWUI.T("lock_off"))
    end)
    b:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    b:SetHandler("OnMouseUp", function(ctrl, button, inside)
        if not (inside and button == MOUSE_BUTTON_INDEX_LEFT) then return end
        local s = NWUI.sv.inv
        s.panelLocks = s.panelLocks or {}
        s.panelLocks[self.id] = not self:IsLocked()
        PlaySound(s.panelLocks[self.id] and SOUNDS.LOCKPICKING_SUCCESS_CELEBRATION or SOUNDS.DEFAULT_CLICK)
        self:ApplyLock()
        ctrl:GetHandler("OnMouseEnter")(ctrl)
    end)
    self.lockBtn = b
end

function Panel:ApplyLock()
    local locked = self:IsLocked()
    self.tlw:SetMovable((not locked) or NWUI.unlocked)
    local b = self.lockBtn
    if not b then return end
    local col = locked and LOCK_GOLD or LOCK_DIM
    for _, t in ipairs({ b.body, b.left, b.right, b.top }) do NWUI.SetColor(t, col) end
    -- arco: cerrado (pegado al cuerpo) o abierto (levantado y sin el lado derecho)
    local lift = locked and 0 or 4
    b.left:ClearAnchors()
    b.left:SetAnchor(BOTTOMLEFT, b.body, TOPLEFT, 2, 0)
    b.left:SetHeight(7 + lift)
    b.right:ClearAnchors()
    b.right:SetAnchor(BOTTOMRIGHT, b.body, TOPRIGHT, -2, -lift)
    b.right:SetHeight(7)
    b.right:SetHidden(not locked and false)
    b.top:ClearAnchors()
    b.top:SetAnchor(BOTTOMLEFT, b.left, TOPLEFT, 0, 0)
    b.top:SetWidth(12)
    if not locked then
        b.right:ClearAnchors()
        b.right:SetAnchor(TOPRIGHT, b.top, TOPRIGHT, 0, 0)
        b.right:SetHeight(4)
    end
end

function INV.ApplyLocks()
    if not INV.panels then return end
    for _, p in ipairs(INV.panels) do p:ApplyLock() end
end

function Panel:GetBags()
    if self.family == "backpack" then
        if self.view == "craftbag" and BAG_VIRTUAL then return { BAG_VIRTUAL } end
        return { BAG_BACKPACK }
    end
    if self.family == "bank" then return NWUI.BankTargets() end
    return { BAG_GUILDBANK }
end

function Panel:ItemKind()
    if self.family == "backpack" then return (self.view == "craftbag") and "craft" or "item" end
    if self.family == "bank" then return "bank" end
    return "guild"
end

function Panel:ReceiveDrop()
    NWUI.DropOnto(self.family)
end

-- ---------------- Tamaño y posición ----------------
function Panel:ApplySize()
    local s = NWUI.sv.inv
    local colW = s.iconsPerRow * s.iconSize + (s.iconsPerRow - 1) * GAP()
    self.colW = colW
    local w = PAD * 2 + colW * 2 + COLGAP + SB_W + 8
    local h = math.max(420, GuiRoot:GetHeight() - TOP_MARGIN - BOTTOM_MARGIN)
    self.tlw:SetDimensions(w, h)
    self.content:SetWidth(colW * 2 + COLGAP)
end

function INV.DefaultLayout(panel, mode)
    if panel.id == "backpack" and mode ~= "inventory" then
        local other = (mode == "guildbank") and INV.guild or INV.bank
        return function(c) c:SetAnchor(TOPRIGHT, other.tlw, TOPLEFT, -14, 0) end
    end
    if panel.id == "backpack" then
        return function(c) c:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -48, TOP_MARGIN) end
    end
    return function(c) c:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -28, TOP_MARGIN) end
end

function Panel:ApplyLayout(mode)
    local key = (mode == "housebank") and "bank" or mode
    self.movable.key = "panel_" .. self.id .. "_" .. key
    self.movable.default = INV.DefaultLayout(self, mode)
    NWUI.ApplyPosition(self.movable)
end

function Panel:OnShowing()
    local mode = NWUI.Scenes and NWUI.Scenes.CurrentMode() or "inventory"
    self.mode = mode
    self:ApplySize()
    self:ApplyLayout(mode)
    if self.family == "bank" then
        local house = GetBankingBag() ~= BAG_BANK
        NWUI.SetTitle(self.titleLabel, house and NWUI.T("title_house") or NWUI.T("title_bank"))
    end
    local hint = ""
    if mode ~= "inventory" then
        hint = (self.family == "backpack") and NWUI.T("hint_deposit") or NWUI.T("hint_withdraw")
    end
    self.footRight:SetText(hint)
    self:SetFundsAction(mode)
    self:Refresh(true)
    zo_callLater(function() self:UpdateFooter() end, 300)
end

-- ---------------- Desplazamiento ----------------
function Panel:ScrollBy(dy)
    self:SetScroll((self.scroll or 0) + dy)
end

function Panel:SetScroll(y)
    local viewH = self.area:GetHeight()
    local maxS = math.max(0, (self.contentH or 0) - viewH)
    y = zo_clamp(y or 0, 0, maxS)
    -- Desplazamiento en píxeles enteros: si no, los bordes de 1 px de las
    -- casillas se cortan al bajar la barra.
    y = math.min(NWUI.PixelSnap(y), maxS)
    self.scroll = y
    self.content:ClearAnchors()
    self.content:SetAnchor(TOPLEFT, self.area, TOPLEFT, 0, -y)
    local trackH = self.track:GetHeight()
    if maxS <= 0 then
        self.thumb:SetHidden(true)
    else
        local th = math.max(30, trackH * viewH / self.contentH)
        self.thumb:SetHidden(false)
        self.thumb:SetHeight(th)
        self.thumb:ClearAnchors()
        self.thumb:SetAnchor(TOP, self.track, TOP, 0, (trackH - th) * (y / maxS))
    end
end

-- ---------------- Botón de fondos (depositar / retirar oro y monedas) ----------------
local FUNDS_ARROW = "EsoUI/Art/Buttons/tree_closed_up.dds"

function Panel:BuildFundsButton(foot)
    local b = WM:CreateControl(NWUI.UID("NWUI_Funds"), foot, CT_CONTROL)
    b:SetAnchor(TOPRIGHT, foot, TOPRIGHT, -PAD, 4)
    b:SetHeight(24)
    NWUI.EdgeBox(b, {0.06, 0.06, 0.07, 0.85}, {0.71, 0.58, 0.33, 0.9})
    b.arrow = NWUI.Tex(b, C.gold, 3)
    b.arrow:SetTexture(FUNDS_ARROW)
    b.arrow:SetDimensions(16, 16)
    b.arrow:SetAnchor(LEFT, b, LEFT, 6, 0)
    b.label = NWUI.Label(b, "$(BOLD_FONT)|15|soft-shadow-thick", C.gold, "")
    b.label:SetAnchor(LEFT, b.arrow, RIGHT, 4, 0)
    b.hl = NWUI.Tex(b, {1, 1, 1, 0.08}, 4)
    b.hl:SetAnchorFill(b)
    b.hl:SetHidden(true)
    b:SetMouseEnabled(true)
    b:SetHandler("OnMouseEnter", function() b.hl:SetHidden(false) end)
    b:SetHandler("OnMouseExit", function() b.hl:SetHidden(true) end)
    b:SetHandler("OnMouseUp", function(_, button, inside)
        if inside and button == MOUSE_BUTTON_INDEX_LEFT then self:OpenFundsDialog() end
    end)
    b:SetHidden(true)
    self.fundsBtn = b
end

-- Qué hace el botón según la escena: en el banco, el inventario deposita y
-- el banco retira; en el banco del gremio igual (si tienes permiso).
function Panel:SetFundsAction(mode)
    local action, dialog
    local houseBank = GetBankingBag() ~= BAG_BANK
    if mode == "bank" and not houseBank then
        if self.family == "backpack" then action, dialog = "deposit", "BANK_DEPOSIT_GOLD"
        elseif self.family == "bank" then action, dialog = "withdraw", "BANK_WITHDRAW_GOLD" end
    elseif mode == "guildbank" then
        local gid = GetSelectedGuildBankId()
        local function can(perm)
            return gid ~= nil and DoesPlayerHaveGuildPermission(gid, perm)
        end
        if self.family == "backpack" and can(GUILD_PERMISSION_BANK_DEPOSIT) then
            action, dialog = "deposit", "GUILD_BANK_DEPOSIT_GOLD"
        elseif self.family == "guild" and can(GUILD_PERMISSION_BANK_WITHDRAW_GOLD) then
            action, dialog = "withdraw", "GUILD_BANK_WITHDRAW_GOLD"
        end
    end
    self.fundsAction, self.fundsDialog = action, dialog
    local b = self.fundsBtn
    if not b then return end
    if action then
        b.label:SetText(NWUI.T(action == "deposit" and "funds_deposit" or "funds_withdraw"))
        local w = b.label.GetTextWidth and b.label:GetTextWidth()
        if type(w) ~= "number" or w <= 0 then w = 140 end
        b:SetWidth(6 + 16 + 4 + w + 10)
    end
    b:SetHidden(not action)
end

function Panel:OpenFundsDialog()
    if not self.fundsDialog then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ZO_Dialogs_ShowDialog(self.fundsDialog)
end

-- ---------------- Cabecera y pie ----------------
-- Ancho disponible para el título: hasta el candado, con margen
function Panel:TitleMaxW()
    local hdrW = self.header and self.header:GetWidth() or 0
    if type(hdrW) ~= "number" or hdrW <= 0 then hdrW = self.tlw:GetWidth() or 0 end
    local capW = self.capLabel.GetTextWidth and self.capLabel:GetTextWidth()
    if type(capW) ~= "number" or capW <= 0 then capW = 80 end
    capW = math.max(capW, 80)     -- reserva para "999 / 999"
    return hdrW - (PAD + 4) - PAD - capW - 9 - 24 - 16
end

-- Todos los títulos posibles de las cabeceras, para elegir un tamaño común
function INV.AllTitles()
    local t = {}
    for _, v in ipairs(INV.VIEWS) do t[#t + 1] = v.title end
    t[#t + 1] = NWUI.T("title_bank"); t[#t + 1] = NWUI.T("title_house"); t[#t + 1] = NWUI.T("title_guild")
    return t
end

function INV.FitTitles()
    local minW
    for _, p in ipairs(INV.panels or {}) do
        local w = p:TitleMaxW()
        if w > 0 and (not minW or w < minW) then minW = w end
    end
    if not minW then return end
    local size = NWUI.titleSize
    if not INV.lastFitW or math.abs(INV.lastFitW - minW) > 0.5 then
        size = NWUI.FitTitleSize(INV.AllTitles(), minW)
        INV.lastFitW = minW
    end
    local changed = size ~= NWUI.titleSize
    NWUI.titleSize = size
    for _, p in ipairs(INV.panels or {}) do
        local w = p:TitleMaxW()
        local cur = p.titleLabel.nwMaxW
        if changed or type(cur) ~= "number" or math.abs(w - cur) > 0.5 then
            NWUI.SetTitle(p.titleLabel, p.titleLabel.nwTitle, w)
        end
    end
end

function Panel:FitTitle() INV.FitTitles() end

function Panel:UpdateHeader()
    local used, total = self:UsedTotal()
    self.capLabel:SetText(string.format("%d / %d", used, total))
    self:FitTitle()
    local pct = (total > 0) and zo_clamp(used / total, 0, 1) or 0
    self.capFill:SetWidth(self.capTrack:GetWidth() * pct)
    NWUI.SetColor(self.capFill, pct >= 0.9 and C.danger or C.capFill)
    NWUI.SetColor(self.capLabel, pct >= 0.9 and C.danger or C.text)
    for _, l in ipairs(self.sortLabels) do
        local active = (l.key == NWUI.sv.inv.sort)
        l.underline:SetHidden(not active)
        NWUI.SetColor(l, active and C.text or C.textDim)
    end
end

function Panel:UpdateSub()
    if not self.subLabel then return end
    if self.family == "bank" then
        local house = GetBankingBag() ~= BAG_BANK
        local zone = zo_strformat("<<C:1>>", GetPlayerActiveZoneName() or "")
        if house then
            self.subLabel:SetText(NWUI.T("house_storage"))
        else
            self.subLabel:SetText(NWUI.T("location", zone))
        end
    elseif self.family == "guild" then
        local gid = GetSelectedGuildBankId()
        local name = (gid and gid ~= 0) and GetGuildName(gid) or NWUI.T("no_guild")
        if self.loading then name = name .. "  |c888888" .. NWUI.T("loading") .. "|r" end
        self.subLabel:SetText(name)
    end
end

function Panel:UsedTotal()
    local used, total = 0, 0
    if self.family == "backpack" then
        return GetNumBagUsedSlots(BAG_BACKPACK) or 0,
            (GetBagUseableSize(BAG_BACKPACK)) or GetBagSize(BAG_BACKPACK) or 0
    elseif self.family == "guild" then
        used = GetNumBagUsedSlots(BAG_GUILDBANK) or 0
        total = GetBagSize(BAG_GUILDBANK) or 0
    else
        for _, bag in ipairs(self:GetBags()) do
            used = used + (GetNumBagUsedSlots(bag) or 0)
            total = total + ((GetBagUseableSize(bag)) or GetBagSize(bag) or 0)
        end
    end
    return used, total
end

-- La barra original del juego (espacio + mejorar bolsa + oro) se coloca debajo
-- del panel desde Scenes.lua. Si no está visible, se muestra la fila propia.
function Panel:NativeInfoVisible()
    -- La barra original queda detrás del panel y no se ve: siempre se usa la fila propia.
    return false
end

-- Lingotes comerciales
local function TradeBarsType()
    return CURT_TRADE_BARS
end
INV.TradeBarsType = TradeBarsType

local FOOT_SEP = "   "
local FOOT_FONTS = { "$(MEDIUM_FONT)|17|soft-shadow-thin", "$(MEDIUM_FONT)|15|soft-shadow-thin", "$(MEDIUM_FONT)|13|soft-shadow-thin" }

function Panel:UpdateFooter()
    local parts = {}
    local function add(t) if t then parts[#parts + 1] = t end end
    local goldLoc, goldText
    if self.family == "backpack" then
        -- orden: lingotes comerciales, sellos, AP, Tel Var, vales y llaves de los Intrépidos
        add(CurrencyText(TradeBarsType(), nil, 19))
        add(CurrencyText(CURT_SEALS, nil, 19))
        add(CurrencyText(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER, 19))
        add(CurrencyText(CURT_TELVAR_STONES, CURRENCY_LOCATION_CHARACTER, 19))
        add(CurrencyText(CURT_WRIT_VOUCHERS, nil, 19))
        add(CurrencyText(CURT_UNDAUNTED_KEYS, nil, 19))
        goldLoc = CURRENCY_LOCATION_CHARACTER
    elseif self.family == "bank" then
        add(CurrencyText(CURT_TELVAR_STONES, CURRENCY_LOCATION_BANK))
        goldLoc = CURRENCY_LOCATION_BANK
    else
        goldLoc = CURRENCY_LOCATION_GUILD_BANK
    end
    -- La pista "Doble clic: ..." va en su propia línea arriba, para dejar
    -- toda la anchura a las monedas.
    local hint = (self.footRight:GetText() or "") ~= ""
    local top = hint and 30 or 8
    self.foot:SetHeight(FOOTER_H + (hint and 22 or 0))
    self.footLabel:ClearAnchors()
    self.footLabel:SetAnchor(TOPLEFT, self.foot, TOPLEFT, PAD, top)
    self.footRight:ClearAnchors()
    if self.fundsAction then
        -- pista a la izquierda y botón de fondos a la derecha
        self.footRight:SetAnchor(TOPLEFT, self.foot, TOPLEFT, PAD, 7)
    else
        self.footRight:SetAnchor(TOPRIGHT, self.foot, TOPRIGHT, -PAD, 7)
    end
    self.fundsBtn:SetHidden(not self.fundsAction)
    local text = table.concat(parts, FOOT_SEP)
    self.footLabel:SetText(text)
    -- si no caben, letra más pequeña
    local avail = (self.foot:GetWidth() or 0) - 2 * PAD
    for _, f in ipairs(FOOT_FONTS) do
        self.footLabel:SetFont(f)
        local w = self.footLabel.GetTextWidth and self.footLabel:GetTextWidth() or 0
        if avail <= 0 or type(w) ~= "number" or w <= avail then break end
    end

    local used, total = self:UsedTotal()
    local label = (self.family == "backpack") and NWUI.T("space_inv") or NWUI.T("space")
    self.spaceLabel:SetText(label .. "|cE3BD66" .. used .. "/" .. total .. "|r")
    goldText = CurrencyText(CURT_MONEY, goldLoc)
    if goldText then
        -- número primero y moneda después, como en la barra original
        local amt = GetCurrencyAmount(CURT_MONEY, goldLoc)
        goldText = ZO_CommaDelimitNumber(amt) .. " " .. zo_iconFormat(FALLBACK_ICON[CURT_MONEY], 20, 20)
    end
    self.goldLabel:SetText(goldText or "")
    self.infoRow:SetHidden(self:NativeInfoVisible())
end

function Panel:CycleGuild(dir)
    local n = GetNumGuilds()
    if n == 0 then return end
    local cur = GetSelectedGuildBankId()
    local idx = 1
    for i = 1, n do
        if GetGuildId(i) == cur then idx = i end
    end
    idx = ((idx - 1 + dir) % n) + 1
    self.loading = true
    self:UpdateSub()
    NWUI.Call("SelectGuildBank", GetGuildId(idx))
end

-- ---------------- Contenido ----------------
-- soft = viene de un evento general del juego: se ignora si el panel se
-- acaba de dibujar (evita el doble refresco al abrir el banco).
local function Now() return GetFrameTimeMilliseconds() or 0 end

function Panel:QueueRefresh(soft)
    if soft and self.lastRefresh and (Now() - self.lastRefresh) < 800 then return end
    NWUI.Throttle("NWUI_Refresh_" .. self.id, 90, function() self:Refresh() end)
end

-- =====================================================================
-- Vistas de la mochila (pestañas): objetos, arcón de artesanía, moneda,
-- objetos de misión y asignación de teclas (rueda de objetos rápidos)
-- =====================================================================
local QS_CAT = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
local QS_MAP = { 4, 3, 2, 1, 8, 7, 6, 5 }

INV.VIEWS = {
    { key = "items",     
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_items_up.dds" },
    { key = "craftbag",  
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_up.dds" },
    { key = "currency",  
      icon = "EsoUI/Art/Bank/bank_tabIcon_gold_up.dds" },
    { key = "quest",     
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_quest_up.dds" },
    { key = "quickslot", 
      icon = "EsoUI/Art/Inventory/inventory_tabIcon_quickslot_up.dds" },
}
for _, v in ipairs(INV.VIEWS) do
    setmetatable(v, { __index = function(t, k)
        if k == "title" then return NWUI.T("title_" .. t.key) elseif k == "tip" then return NWUI.T("tip_" .. t.key) end
    end })
end

local CURRENCIES = {
    { "CURT_MONEY", "Oro" },
    { "TRADE_BARS", "trade_bars" },
    { "CURT_ALLIANCE_POINTS", "Puntos de Alianza" },
    { "CURT_TELVAR_STONES", "Piedras Tel Var" },
    { "CURT_WRIT_VOUCHERS", "Vales de encargo" },
    { "CURT_TRANSMUTE_CRYSTALS", "Cristales de transmutación" },
    { "CURT_UNDAUNTED_KEYS", "Llaves de los Intrépidos" },
    { "CURT_SEALS", "Sellos de empeño" },
    { "CURT_ARCHIVAL_FORTUNES", "Fortunas archivadas" },
    { "CURT_IMPERIAL_FRAGMENTS", "Fragmentos imperiales" },
    { "CURT_STYLE_STONES", "Piedras de estilo" },
    { "CURT_CROWN_GEMS", "Gemas de la Corona" },
    { "CURT_CROWNS", "Coronas" },
}

local function CurrencyIcon(ct, size)
    local i = ZO_Currency_GetKeyboardFormattedCurrencyIcon(ct, size)
    if type(i) == "string" and i ~= "" then return i end
    if FALLBACK_ICON[ct] then return zo_iconFormat(FALLBACK_ICON[ct], size, size) end
    return ""
end

-- Tarjeta plana para monedas
function INV.CreateCard(parent)
    local c = WM:CreateControl(NWUI.UID("NWUI_Card"), parent, CT_CONTROL)
    NWUI.FlatBox(c, {0.10, 0.10, 0.11, 1}, C.slotBorder, 1)
    c.name = NWUI.Label(c, F.body, C.text, "")
    c.name:SetAnchor(TOPLEFT, c, TOPLEFT, 10, 6)
    c.amount = NWUI.Label(c, "$(BOLD_FONT)|18|soft-shadow-thin", C.gold, "")
    c.amount:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -10, -5)
    -- cantidad en el banco: dorada y en negrita, pero más pequeña y tenue que la principal
    c.sub = NWUI.Label(c, "$(BOLD_FONT)|14|soft-shadow-thin", C.gold, "")
    c.sub:SetAlpha(0.72)
    c.sub:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 10, -6)
    return c
end

-- Objetos de misión agrupados por misión
local function QuestGroups(q)
    local groups, order = {}, {}
    local function add(questIndex, d)
        local key = questIndex or 0
        if not groups[key] then
            local name = (questIndex and GetJournalQuestName) and GetJournalQuestName(questIndex) or NWUI.T("quest")
            groups[key] = { name = zo_strformat("<<1>>", name), items = {} }
            order[#order + 1] = key
        end
        if q == "" or zo_strlower(d.name):find(q, 1, true) then
            table.insert(groups[key].items, d)
        end
    end
    for questIndex, list in pairs(SHARED_INVENTORY:GenerateFullQuestCache()) do
        for _, it in pairs(list) do
            add(it.questIndex or questIndex, {
                kind = "quest", hasItem = true, quality = 1, meets = true,
                icon = it.iconFile, stack = it.stackCount or 1,
                name = zo_strformat("<<1>>", it.name),
                questIndex = it.questIndex or questIndex, toolIndex = it.toolIndex,
                stepIndex = it.stepIndex, conditionIndex = it.conditionIndex,
                slotIndex = 0, value = 0, tooltipSide = "left",
            })
        end
    end
    local list = {}
    for _, key in ipairs(order) do
        local g = groups[key]
        if #g.items > 0 then list[#list + 1] = { key = "quest" .. tostring(key), name = zo_strupper(g.name), items = g.items } end
    end
    return list
end

function Panel:CollectGroups()
    local s = NWUI.sv.inv
    local q = self.search
    if self.view == "quest" and self.family == "backpack" then
        return QuestGroups(q)
    end
    local kind = self:ItemKind()
    local groups = {}
    for _, bag in ipairs(self:GetBags()) do
        for slot in BagSlots(bag) do
            local d = ReadItem(bag, slot, kind)
            if d and (q == "" or d.searchName:find(q, 1, true)) then
                local k = CategoryOf(d)
                groups[k] = groups[k] or {}
                table.insert(groups[k], d)
            end
        end
    end
    local cmp = NewFirst(SORTS[s.sort] or SORTS.quality)
    local list = {}
    for _, cat in ipairs(CATS) do
        local g = groups[cat.key]
        if g and #g > 0 then
            table.sort(g, cmp)
            list[#list + 1] = { key = cat.key, name = cat.name, items = g }
        end
    end
    return list
end

-- Dibuja primero lo que se ve en pantalla y el resto en los siguientes cuadros
-- (40 casillas por cuadro), así el panel aparece al instante.
local CHUNK = 40

-- ---------------- Secciones plegables ----------------
local ANIM_MS = 170     -- deslizamiento de las secciones
local FADE_MS = 90      -- desvanecer los objetos al plegar

local function EaseOut(t) t = 1 - t; return 1 - t * t * t end

function Panel:CollapseKey(key)
    return self.family .. "|" .. tostring(self.view) .. "|" .. tostring(key)
end

function Panel:IsCollapsed(key)
    if self.search ~= "" then return false end   -- al buscar se ve todo
    local c = NWUI.sv.inv.collapsed
    return c and c[self:CollapseKey(key)] == true
end

local function SetArrow(sec, v)
    sec.arrowState = v
    sec.arrowOpen:SetAlpha(v)
    sec.arrowClosed:SetAlpha(1 - v)
end

function Panel:StopAnim(finish)
    EVENT_MANAGER:UnregisterForUpdate("NWUI_Anim_" .. self.id)
    local a = self.anim
    self.anim = nil
    if a and finish then a.step(1) end
end

-- Plegar / desplegar con una sola animación por panel. Si llega otro clic
-- a mitad de animación, se parte de las posiciones actuales: nunca salta.
function Panel:ToggleGroup(key)
    local s = NWUI.sv.inv
    s.collapsed = s.collapsed or {}
    local ck = self:CollapseKey(key)
    local collapsing = not self:IsCollapsed(key)
    if self.search ~= "" then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)

    -- una animación anterior se termina al instante en su posición actual
    if self.anim and self.anim.fading then self:StopAnim(true) end
    if collapsing then
        s.collapsed[ck] = true
        -- 1) desvanecer los objetos de la sección; 2) recolocar deslizando
        local slots = (self.groupSlots and self.groupSlots[key]) or {}
        local sec = self.secByKey and self.secByKey[key]
        local t0 = Now()
        self:StopAnim(false)
        self.anim = { fading = true }
        self.anim.step = function(e)
            for _, c in ipairs(slots) do c:SetAlpha(1 - e) end
            if sec then SetArrow(sec, 1 - e) end
            if e >= 1 then
                self.anim = nil
                EVENT_MANAGER:UnregisterForUpdate("NWUI_Anim_" .. self.id)
                self:Relayout(true)
            end
        end
        EVENT_MANAGER:RegisterForUpdate("NWUI_Anim_" .. self.id, 0, function()
            local e = math.min(1, (Now() - t0) / FADE_MS)
            if self.anim then self.anim.step(e) end
        end)
    else
        s.collapsed[ck] = nil
        self:Relayout(true, key)
    end
end

-- Vuelve a dibujar el panel y desliza las secciones desde donde estaban.
function Panel:Relayout(animate, expandedKey)
    self.animFrom = animate and self.secCur or nil
    self.animExpand = expandedKey
    self:Refresh()
    self.animFrom, self.animExpand = nil, nil
end

function Panel:RenderGroups(list)
    self:StopAnim(false)
    local s = NWUI.sv.inv
    local size, perRow = s.iconSize, s.iconsPerRow
    local ICON_GAP = GAP()
    local prices = NWUI.Price and NWUI.Price.Enabled() and self.view ~= "quest"
    local rowH = size + ICON_GAP + (prices and PRICE_H or 0)
    local colW = self.colW or (perRow * size + (perRow - 1) * ICON_GAP)
    local colX = { 0, colW + COLGAP }
    local colY = { 0, 0 }
    local entries = {}
    local secs = {}
    local from = self.animFrom
    self.secByKey, self.groupSlots, self.secCur = {}, {}, {}
    for gi, grp in ipairs(list) do
        local key = grp.key or ("g" .. gi)
        local folded = self:IsCollapsed(key)
        local col = (colY[1] <= colY[2]) and 1 or 2
        local x, y = colX[col], colY[col]
        local sec = self.secPool:AcquireObject()
        sec.key = key
        sec:SetHidden(false)
        sec:SetWidth(colW)
        sec.name:SetText(grp.name)
        NWUI.FitLabel(sec.name, colW - ARROW_W - 32)
        sec.count:SetText(tostring(#grp.items))
        SetArrow(sec, folded and 0 or 1)
        self.secByKey[key] = sec
        self.groupSlots[key] = {}
        local start = (from and from[key]) or { x = x, y = y }
        secs[#secs + 1] = { sec = sec, key = key, tx = x, ty = y, sx = start.x, sy = start.y }
        self.secCur[key] = { x = x, y = y }
        y = y + SEC_H
        if folded then
            y = y + 4
        else
            for i, d in ipairs(grp.items) do
                local r = math.floor((i - 1) / perRow)
                local cc = (i - 1) % perRow
                entries[#entries + 1] = { key = key, rx = cc * (size + ICON_GAP), ry = SEC_H + r * rowH,
                    x = x + cc * (size + ICON_GAP), y = y + r * rowH, d = d }
            end
            y = y + math.ceil(#grp.items / perRow) * rowH + 18
        end
        colY[col] = y
    end

    -- posición actual de cada sección (durante la animación se interpola)
    local cur = {}
    local function posSec(sd, e)
        local px = sd.sx + (sd.tx - sd.sx) * e
        local py = sd.sy + (sd.ty - sd.sy) * e
        cur[sd.key] = { x = px, y = py }
        self.secCur[sd.key] = cur[sd.key]
        sd.sec:ClearAnchors()
        sd.sec:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(px), NWUI.PixelSnap(py))
    end
    local animating = false
    for _, sd in ipairs(secs) do
        if sd.sx ~= sd.tx or sd.sy ~= sd.ty then animating = true end
        posSec(sd, 0)
    end
    local expandKey = self.animExpand
    if expandKey then animating = true end

    local placed = {}
    local function posSlot(c, e)
        local p = cur[c.secKey]
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(p.x + c.rx), NWUI.PixelSnap(p.y + c.ry))
        if c.secKey == expandKey then c:SetAlpha(e * e) end
    end
    local function place(e)
        local c = self.slotPool:AcquireObject()
        c:SetDimensions(NWUI.PixelSnap(size), NWUI.PixelSnap(size))
        c.secKey, c.rx, c.ry = e.key, e.rx, e.ry
        c:SetAlpha(1)
        posSlot(c, self.anim and self.anim.e or 1)
        c:SetHidden(false)
        NWUI.Slot.Setup(c, e.d)
        placed[#placed + 1] = c
        local gs = self.groupSlots[e.key]
        if gs then gs[#gs + 1] = c end
    end

    -- visible ahora; el resto, después
    local top = (self.scroll or 0) - rowH
    local bottom = (self.scroll or 0) + self.area:GetHeight() + rowH * 2
    local rest = {}
    if animating then
        self.anim = { e = 0 }
        if expandKey and self.secByKey[expandKey] then SetArrow(self.secByKey[expandKey], 0) end
    end
    for _, e in ipairs(entries) do
        if e.y < bottom and e.y + size > top then place(e) else rest[#rest + 1] = e end
    end

    -- Animación: un único bucle por panel
    if animating then
        local t0 = Now()
        local a = self.anim
        a.step = function(e)
            a.e = e
            for _, sd in ipairs(secs) do posSec(sd, e) end
            for _, c in ipairs(placed) do posSlot(c, e) end
            if expandKey and self.secByKey[expandKey] then SetArrow(self.secByKey[expandKey], e) end
            if e >= 1 then
                self.anim = nil
                EVENT_MANAGER:UnregisterForUpdate("NWUI_Anim_" .. self.id)
            end
        end
        a.step(0)
        EVENT_MANAGER:RegisterForUpdate("NWUI_Anim_" .. self.id, 0, function()
            local t = math.min(1, (Now() - t0) / ANIM_MS)
            if self.anim == a then a.step(EaseOut(t)) else
                EVENT_MANAGER:UnregisterForUpdate("NWUI_Anim_" .. self.id)
            end
        end)
    end

    self.renderGen = (self.renderGen or 0) + 1
    local gen = self.renderGen
    local key = "NWUI_Render_" .. self.id
    EVENT_MANAGER:UnregisterForUpdate(key)
    if #rest > 0 then
        local idx = 1
        EVENT_MANAGER:RegisterForUpdate(key, 0, function()
            if self.renderGen ~= gen or self.tlw:IsHidden() then
                EVENT_MANAGER:UnregisterForUpdate(key)
                return
            end
            local n = 0
            while idx <= #rest and n < CHUNK do
                place(rest[idx])
                idx = idx + 1
                n = n + 1
            end
            if idx > #rest then EVENT_MANAGER:UnregisterForUpdate(key) end
        end)
    end
    local nItems = 0
    for _, grp in ipairs(list) do nItems = nItems + #grp.items end
    -- secciones plegadas cuentan como objetos: no se muestra "Vacío"
    return math.max(colY[1], colY[2]), nItems
end

function Panel:RenderCurrency()
    local colW = self.colW
    local h, gap = 52, 8
    local y = 0
    local sec = self.secPool:AcquireObject()
    sec:SetHidden(false)
    sec:SetWidth(colW * 2 + COLGAP)
    sec:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(0), NWUI.PixelSnap(0))
    sec.name:SetText(NWUI.T("currencies"))
    sec.count:SetText("")
    sec.arrowOpen:SetAlpha(0); sec.arrowClosed:SetAlpha(0)
    y = SEC_H
    local i = 0
    for _, def in ipairs(CURRENCIES) do
        local ct
        if def[1] == "TRADE_BARS" then ct = TradeBarsType() else ct = _G[def[1]] end
        if ct then
            local loc = GetCurrencyPlayerStoredLocation(ct)
            local amt = GetCurrencyAmount(ct, loc)
            do
                local name = (def[1] == "TRADE_BARS") and NWUI.T("trade_bars") or def[2]
                local n = GetCurrencyName(ct, false, false)
                if n ~= "" then name = zo_strformat("<<C:1>>", n) end
                local c = self.cardPool:AcquireObject()
                local col = i % 2
                local row = math.floor(i / 2)
                c:SetDimensions(colW, h)
                c:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(col * (colW + COLGAP)), NWUI.PixelSnap(y + row * (h + gap)))
                c:SetHidden(false)
                c.name:SetText(CurrencyIcon(ct, 22) .. "  " .. name)
                c.amount:SetText(ZO_CommaDelimitNumber(amt))
                local sub = ""
                -- toda moneda que se pueda guardar en el banco y que tengas allí
                if loc ~= CURRENCY_LOCATION_BANK and CanCurrencyBeStoredInLocation(ct, CURRENCY_LOCATION_BANK) then
                    local bank = GetCurrencyAmount(ct, CURRENCY_LOCATION_BANK)
                    if bank > 0 then
                        sub = NWUI.T("bank_amount", ZO_CommaDelimitNumber(bank))
                    end
                end
                c.sub:SetText(sub)
                i = i + 1
            end
        end
    end
    return y + math.ceil(i / 2) * (h + gap), i
end

-- Asignación de teclas: la rueda arriba y los objetos asignables abajo
function INV.AssignQuickslot(bag, slot, wheelSlot)
    if not (bag and slot and wheelSlot) then return end
    if NWUI.Call("SelectSlotItem", bag, slot, wheelSlot, QS_CAT) then return end
    -- respaldo: levantar el objeto y que el juego lo coloque en la casilla
    if GetCursorContentType() == MOUSE_CONTENT_EMPTY then NWUI.Call("PickupInventoryItem", bag, slot) end
    if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then
        NWUI.Call("PlaceInActionBar", wheelSlot, QS_CAT)
        if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then ClearCursor() end
    end
end

function INV.ClearQuickslot(wheelSlot)
    NWUI.Call("ClearSlot", wheelSlot, QS_CAT)
end

function Panel:RenderQuickslots()
    local s = NWUI.sv.inv
    local size = math.max(s.iconSize, 54)
    local gap = GAP()
    local current = GetCurrentQuickslot()
    self.qsTarget = self.qsTarget or current or QS_MAP[1]
    local fullW = self.colW * 2 + COLGAP

    local sec = self.secPool:AcquireObject()
    sec:SetHidden(false)
    sec:SetWidth(fullW)
    sec:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(0), NWUI.PixelSnap(0))
    sec.name:SetText(NWUI.T("wheel"))
    sec.arrowOpen:SetAlpha(0); sec.arrowClosed:SetAlpha(0)
    sec.count:SetText("")
    local key = (NWUI.HUD and NWUI.HUD.QuickslotKey and NWUI.HUD.QuickslotKey()) or "Q"
    local native = INV.NativeWheelAvailable()
    if native then
        sec.hint:SetText(NWUI.T("wheel_open", key) .. "\n|cBFBFBF" .. NWUI.T("wheel_drag") .. "|r")
        -- la rueda está en el centro de la pantalla (la del juego)
        local hh = sec.hint.GetTextHeight and sec.hint:GetTextHeight()
        if type(hh) ~= "number" or hh <= 0 then hh = 54 end
        return self:RenderAssignables(SEC_H + hh + 12, size, gap, fullW)
    end
    sec.hint:SetText(NWUI.T("wheel_open", key) .. "\n|cBFBFBF" .. NWUI.T("wheel_hint") .. "|r")
    local HINT_H = 40
    local y = SEC_H + HINT_H

    -- Rueda: 8 casillas en círculo, en el mismo orden que la rueda del juego
    -- (arriba y en el sentido de las agujas del reloj)
    local R = size + 30
    local cx = math.floor(fullW / 2)
    local cy = y + R + size / 2
    for i, wheelSlot in ipairs(QS_MAP) do
        local c = self.slotPool:AcquireObject()
        local ang = math.rad(-90 + (i - 1) * 45)
        local px = cx + R * math.cos(ang) - size / 2
        local py = cy + R * math.sin(ang) - size / 2
        c:SetDimensions(NWUI.PixelSnap(size), NWUI.PixelSnap(size))
        c:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(px), NWUI.PixelSnap(py))
        c:SetHidden(false)
        local tex = GetSlotTexture(wheelSlot, QS_CAT)
        local count = GetSlotItemCount(wheelSlot, QS_CAT)
        local has = tex ~= ""
        NWUI.Slot.Setup(c, {
            kind = "wheel", wheelSlot = wheelSlot, hasItem = has, icon = has and tex or nil,
            stack = count or 0, quality = 1, meets = true, panel = self,
            emptyName = NWUI.T("wheel_empty"), tooltipSide = "left",
        })
        if wheelSlot == self.qsTarget then NWUI.SetColor(c.border, C.gold) end
    end
    -- centro de la rueda: la tecla
    local hub = self.wheelHub
    if not hub then
        hub = WM:CreateControl(NWUI.UID("NWUI_WheelHub"), self.content, CT_CONTROL)
        hub:SetDimensions(46, 46)
        NWUI.EdgeBox(hub, {0, 0, 0, 0.55}, {0.71, 0.58, 0.33, 0.9})
        hub.label = NWUI.Label(hub, "$(BOLD_FONT)|24|soft-shadow-thick", C.gold, "")
        hub.label:SetAnchor(CENTER, hub, CENTER, 0, 0)
        self.wheelHub = hub
    end
    hub:ClearAnchors()
    hub:SetAnchor(CENTER, self.content, TOPLEFT, NWUI.PixelSnap(cx), NWUI.PixelSnap(cy))
    hub.label:SetText(key)
    hub:SetHidden(false)
    y = cy + R + size / 2 + 18
    return self:RenderAssignables(y, size, gap, fullW, 8)
end

function Panel:RenderAssignables(y, size, gap, fullW, extra)
    local s = NWUI.sv.inv
    -- objetos asignables (consumibles de la mochila)
    local list = {}
    for slot in BagSlots(BAG_BACKPACK) do
        local d = ReadItem(BAG_BACKPACK, slot, "item")
        if d and CategoryOf(d) == "consumables" and (self.search == "" or d.searchName:find(self.search, 1, true)) then
            d.assignMode = true
            list[#list + 1] = d
        end
    end
    table.sort(list, NewFirst(SORTS.name))
    local sec2 = self.secPool:AcquireObject()
    sec2:SetHidden(false)
    sec2:SetWidth(self.colW * 2 + COLGAP)
    sec2:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(0), NWUI.PixelSnap(y))
    sec2.name:SetText(NWUI.T("assignable"))
    sec2.arrowOpen:SetAlpha(0); sec2.arrowClosed:SetAlpha(0)
    sec2.count:SetText("")
    sec2.hint:SetText(NWUI.T("assignable_hint"))
    y = y + SEC_H + 22
    local isz = s.iconSize
    local per = math.max(1, math.floor((fullW + gap) / (isz + gap)))
    for i, d in ipairs(list) do
        local c = self.slotPool:AcquireObject()
        local r, col = math.floor((i - 1) / per), (i - 1) % per
        c:SetDimensions(NWUI.PixelSnap(isz), NWUI.PixelSnap(isz))
        c:SetAnchor(TOPLEFT, self.content, TOPLEFT, NWUI.PixelSnap(col * (isz + gap)), NWUI.PixelSnap(y + r * (isz + gap)))
        c:SetHidden(false)
        NWUI.Slot.Setup(c, d)
    end
    y = y + math.ceil(#list / per) * (isz + gap)
    return y, (extra or 0) + #list
end

function Panel:Refresh(force)
    if self.family == "backpack" and INV.QueueTabNew then INV.QueueTabNew() end
    if not force and self.tlw:IsHidden() then return end
    self.lastRefresh = Now()
    self.slotPool:ReleaseAllObjects()
    self.secPool:ReleaseAllObjects()
    self.cardPool:ReleaseAllObjects()
    if self.wheelHub then self.wheelHub:SetHidden(true) end
    self:UpdateHeader()
    self:UpdateSub()
    self:UpdateFooter()

    if self.family == "guild" and self.loading then
        self.emptyLabel:SetText(NWUI.T("loading_guild"))
        self.contentH = 0
        self.content:SetHeight(0)
        self:SetScroll(0)
        return
    end

    local height, total
    if self.view == "currency" and self.family == "backpack" then
        height, total = self:RenderCurrency()
    elseif self.view == "quickslot" and self.family == "backpack" then
        height, total = self:RenderQuickslots()
    else
        if self.view == "craftbag" and HasCraftBagAccess and not HasCraftBagAccess() then
            self.emptyLabel:SetText(NWUI.T("craftbag_plus"))
            self.contentH = 0
            self.content:SetHeight(1)
            self:SetScroll(0)
            return
        end
        height, total = self:RenderGroups(self:CollectGroups())
    end

    if total == 0 then
        self.emptyLabel:SetText(self.search ~= "" and NWUI.T("no_results") or NWUI.T("empty"))
    else
        self.emptyLabel:SetText("")
    end
    self.contentH = height
    self.content:SetHeight(math.max(1, height))
    self:SetScroll(self.scroll)
end

-- ---------------- Rueda original del juego (objetos rápidos) ----------------
-- La pestaña OBJETOS RÁPIDOS y la tecla Q (la del juego) muestran la rueda
-- original en el centro; los objetos asignables se arrastran a ella.
-- esoui/ingame/inventory/inventorymenubar.lua y quickslot/keyboard/quickslot_keyboard.lua
local function NativeBar()
    return INVENTORY_MENU_BAR.modeBar
end

local function NativeWheelShowing()
    return KEYBOARD_QUICKSLOT_CIRCLE_FRAGMENT:IsShowing()
end

INV.NativeWheelShowing = function() return NativeWheelShowing() end

function INV.NativeWheelAvailable()
    return not IsInGamepadPreferredMode()
end

function INV.ShowNativeWheel(on)
    local bar = NativeBar()
    if not SCENE_MANAGER:IsShowing("inventory") then return end
    if on == NativeWheelShowing() then return end
    INV.syncingWheel = true
    bar:SelectFragment(on and SI_INVENTORY_MODE_QUICKSLOTS or SI_INVENTORY_MODE_ITEMS)
    INV.syncingWheel = false
end

function INV.SyncNativeWheel()
    local bp = INV.backpack
    if bp then INV.ShowNativeWheel(bp.view == "quickslot") end
end

-- La ventana original de objetos rápidos (lista, filtros, búsqueda) se muestra
-- junto con la rueda y, aunque esté apartada, puede capturar el ratón encima
-- de nuestro panel. Se dejan visibles solo la rueda y se desactiva el ratón
-- del resto mientras la rueda está abierta.
local isolated = {}
function INV.IsolateNativeWheel(on)
    local tl = ZO_QuickSlot_Keyboard_TopLevel
    local wheel = QUICKSLOT_KEYBOARD.wheelControl
    if on then
        tl:SetMouseEnabled(false)
        for i = 1, tl:GetNumChildren() do
            local ch = tl:GetChild(i)
            if ch and ch ~= wheel and not ch:IsHidden() then
                ch:SetHidden(true)
                isolated[#isolated + 1] = ch
            end
        end
    else
        for _, ch in ipairs(isolated) do ch:SetHidden(false) end
        isolated = {}
        tl:SetMouseEnabled(true)
    end
end

-- Con la rueda del juego abierta, sus ventanas pasan por delante de las
-- nuestras (aunque no se vean) y se quedan con el ratón: se suben nuestros
-- paneles a una capa superior mientras la rueda está abierta.
function INV.RaisePanels(on)
    local tier = on and (DT_MEDIUM or 1) or (DT_LOW or 0)
    for _, p in ipairs(INV.panels or {}) do
        if p.tlw and p.tlw.SetDrawTier then p.tlw:SetDrawTier(tier) end
    end
end

function INV.HookNativeWheel()
    if INV.wheelHooked then return end
    INV.wheelHooked = true
    KEYBOARD_QUICKSLOT_CIRCLE_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN then
            INV.IsolateNativeWheel(true)
            INV.RaisePanels(true)
        elseif newState == SCENE_FRAGMENT_HIDDEN then
            INV.IsolateNativeWheel(false)
            INV.RaisePanels(false)
        end
        if INV.syncingWheel then return end
        local bp = INV.backpack
        if not bp or (NWUI.Scenes and NWUI.Scenes.CurrentMode() ~= "inventory") then return end
        if newState == SCENE_FRAGMENT_SHOWING and bp.view ~= "quickslot" then
            bp:SetView("quickslot")          -- Q: abre la rueda y muestra los asignables
        elseif newState == SCENE_FRAGMENT_HIDING and bp.view == "quickslot" then
            bp:SetView("items")
        end
    end)
end

function Panel:SetView(view)
    if self.view == view then return end
    self.view = view
    if self.family == "backpack" and not INV.syncingWheel then
        INV.ShowNativeWheel(view == "quickslot")
    end
    self.scroll = 0
    self.qsTarget = nil
    for _, v in ipairs(INV.VIEWS) do
        if v.key == view and self.family == "backpack" then
            NWUI.SetTitle(self.titleLabel, v.title)
        end
    end
    if INV.tabs then INV.UpdateTabs() end
    self:Refresh()
end

-- Barra de pestañas propia (sustituye al menú "Objetos" del juego)
function INV.UpdateTabs()
    local t = INV.tabs
    if not t then return end
    local view = INV.backpack.view
    for _, b in ipairs(t.buttons) do
        local active = b.view.key == view
        b.icon:SetAlpha(active and 1 or 0.55)
        b.underline:SetHidden(not active)
        if active then
            local tip = b.view.key == "items" and NWUI.T("tabs_items") or b.view.tip
            t.label:SetText(zo_strupper and zo_strupper(tip) or tip)
            NWUI.FitLabel(t.label, t.bar:GetWidth())
        end
    end
end

function INV.SetTabIcons(paths)
    if not (INV.tabs and paths) then return end
    for i, b in ipairs(INV.tabs.buttons) do
        if paths[i] then b.icon:SetTexture(paths[i]) end
    end
end

function INV.CreateTabs()
    local p = INV.backpack
    local bar = WM:CreateControl("NWUI_Tabs", p.tlw, CT_CONTROL)
    local size, gap = 34, 10
    local TITLE_H = 26                -- igual que ARMAS / MONTURA
    local LABEL_H = TITLE_H + 6
    local barW = #INV.VIEWS * (size + gap) - gap
    bar:SetDimensions(barW, LABEL_H + size + 6)
    local t = { bar = bar, buttons = {} }
    -- Nombre de la pestaña activa: a la izquierda, con la línea dorada debajo,
    -- con el mismo estilo y separación que ARMAS y MONTURA
    t.label = NWUI.Label(bar, F.section, C.text, "")
    t.label:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    t.line = NWUI.Tex(bar, {0.71, 0.58, 0.33, 0.55}, 2)
    t.line:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, TITLE_H - 3)
    t.line:SetAnchor(TOPRIGHT, bar, TOPRIGHT, 0, TITLE_H - 3)
    t.line:SetHeight(1)
    for i, v in ipairs(INV.VIEWS) do
        local b = WM:CreateControl(NWUI.UID("NWUI_Tab"), bar, CT_CONTROL)
        b:SetDimensions(size, size)
        b:SetAnchor(TOPLEFT, bar, TOPLEFT, (i - 1) * (size + gap), LABEL_H)
        b.icon = NWUI.Tex(b, nil, 3)
        b.icon:SetTexture(v.icon)
        b.icon:SetAnchorFill(b)
        b.hl = NWUI.Tex(b, {1, 1, 1, 0.10}, 2)
        b.hl:SetAnchorFill(b)
        b.hl:SetHidden(true)
        b.underline = NWUI.Tex(b, C.gold, 4)
        b.underline:SetAnchor(TOPLEFT, b, BOTTOMLEFT, 2, 3)
        b.underline:SetAnchor(TOPRIGHT, b, BOTTOMRIGHT, -2, 3)
        b.underline:SetHeight(2)
        b.newBadge = NWUI.Tex(b, nil, 6)
        b.newBadge:SetTexture("NWInterfaz/textures/nuevo.dds")
        b.newBadge:SetDimensions(15, 15)
        b.newBadge:SetAnchor(CENTER, b, TOPRIGHT, -2, 2)
        b.newBadge:SetHidden(true)
        b.view = v
        b:SetMouseEnabled(true)
        b:SetHandler("OnMouseEnter", function(self)
            self.hl:SetHidden(false)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, v.tip)
        end)
        b:SetHandler("OnMouseExit", function(self)
            self.hl:SetHidden(true)
            ClearTooltip(InformationTooltip)
        end)
        b:SetHandler("OnMouseUp", function(_, button, inside)
            if inside and button == MOUSE_BUTTON_INDEX_LEFT then
                PlaySound(SOUNDS.MENU_BAR_CLICK)
                p:SetView(v.key)
            end
        end)
        t.buttons[i] = b
    end
    INV.tabs = t
    INV.CreateMountBox(bar, barW)
    INV.UpdateTabs()
    INV.QueueTabNew()
end

-- ¿Hay objetos nuevos en esta bolsa? (opcional: que cumplan 'pred')
local function AnyNew(bag, pred)
    if bag == nil then return false end
    local cache = SHARED_INVENTORY:GetBagCache(bag)
    if cache then
        for slot, sd in pairs(cache) do
            if sd.brandNew and (not pred or pred(bag, slot)) then return true end
        end
    end
    for _, e in pairs(ownNew) do
        if e.bag == bag and (not pred or pred(e.bag, e.slot)) then return true end
    end
    return false
end
INV.AnyNew = AnyNew

local function IsAssignableNew(bag, slot)
    local d = ReadItem(bag, slot, "item")
    return d ~= nil and CategoryOf(d) == "consumables"
end

-- Marca "!" en las pestañas OBJETOS, ARCÓN DE ARTESANÍA y OBJETOS RÁPIDOS
function INV.UpdateTabNew()
    local t = INV.tabs
    if not t then return end
    local flags = {
        items = AnyNew(BAG_BACKPACK),
        craftbag = BAG_VIRTUAL and AnyNew(BAG_VIRTUAL) or false,
        quickslot = AnyNew(BAG_BACKPACK, IsAssignableNew),
    }
    for _, b in ipairs(t.buttons) do
        if b.newBadge then
            local on = flags[b.view.key] == true
            b.newBadge:SetHidden(not on)
            NWUI.Pulse(b.newBadge, on)
        end
    end
end

function INV.QueueTabNew()
    NWUI.Throttle("NWUI_TabNew", 200, INV.UpdateTabNew)
end

function INV.ApplyPanelAlpha()
    for _, p in ipairs(INV.panels or {}) do
        if p.panelBgTex then p.panelBgTex:SetAlpha(1); p.panelBgTex:SetColor(0, 0, 0, (NWUI.sv.inv.panelAlpha or 62) / 100) end
    end
end

-- =====================================================================
-- Montura equipada (cuadro gris bajo las pestañas)
-- =====================================================================
local ACTOR_PLAYER = GAMEPLAY_ACTOR_CATEGORY_PLAYER or 0
local MOUNT_CAT = COLLECTIBLE_CATEGORY_TYPE_MOUNT
local RANDOM_ICONS = {}
RANDOM_ICONS[RANDOM_MOUNT_TYPE_FAVORITE] = "EsoUI/Art/Collections/Random_FavoriteMount.dds"
RANDOM_ICONS[RANDOM_MOUNT_TYPE_ANY] = "EsoUI/Art/Collections/Random_AnyMount.dds"

local function CleanName(n)
    if not n or n == "" then return "" end
    n = zo_strformat("<<1>>", n)
    -- quita los sufijos gramaticales del juego (^m, ^f, ^n...)
    return (n:gsub("%^.*$", ""))
end

-- Devuelve: nombre, icono, id de coleccionable (o nil), descripción
function INV.GetMountInfo()
    local id = (MOUNT_CAT and GetActiveCollectibleByType) and GetActiveCollectibleByType(MOUNT_CAT, ACTOR_PLAYER) or 0
    local rtype = GetRandomMountType(ACTOR_PLAYER)
    if rtype and RANDOM_MOUNT_TYPE_NONE and rtype ~= RANDOM_MOUNT_TYPE_NONE then
        local name = GetString("SI_RANDOMMOUNTTYPE", rtype)
        if not name or name == "" then name = NWUI.T("mount_random_name") end
        local desc = GetString("SI_RANDOMMOUNTTYPE_DESCRIPTION", rtype) or ""
        local sub = (id and id > 0) and CleanName(GetCollectibleName(id)) or nil
        return CleanName(name), RANDOM_ICONS[rtype] or (id and id > 0 and GetCollectibleIcon(id)) or "", nil, desc, sub
    end
    if id and id > 0 then
        return CleanName(GetCollectibleName(id)), GetCollectibleIcon(id) or "", id,
            (GetCollectibleDescription(id)) or ""
    end
    return nil
end

local MOUNT_BOX  = 112   -- cuadro cuadrado, solo la montura
local MOUNT_ICON = 96
local MOUNT_TITLE_H = 26

function INV.CreateMountBox(parent, w)
    -- Bloque: título "MONTURA" (como ARMAS / JOYERÍA), cuadro y entrenamiento
    local block = WM:CreateControl("NWUI_MountBlock", parent, CT_CONTROL)
    block:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, 0, 18)
    block:SetAnchor(TOPRIGHT, parent, BOTTOMRIGHT, 0, 18)
    local title = NWUI.Label(block, F.section, C.text, NWUI.T("mount"))
    title:SetAnchor(TOPLEFT, block, TOPLEFT, 0, 0)
    local tline = NWUI.Tex(block, {0.71, 0.58, 0.33, 0.55}, 2)
    tline:SetAnchor(TOPLEFT, block, TOPLEFT, 0, MOUNT_TITLE_H - 3)
    tline:SetAnchor(TOPRIGHT, block, TOPRIGHT, 0, MOUNT_TITLE_H - 3)
    tline:SetHeight(1)

    local box = WM:CreateControl("NWUI_MountBox", block, CT_CONTROL)
    box:SetDimensions(MOUNT_BOX, MOUNT_BOX)
    box:SetAnchor(TOP, block, TOP, 0, MOUNT_TITLE_H + 6)
    box.block, box.title = block, title
    -- fondo negro translúcido con bordes finos (sin relleno detrás del icono)
    local bg = NWUI.Tex(box, {0, 0, 0, 0.55}, 0)
    bg:SetAnchorFill(box)
    local lw = NWUI.LinePx(1)
    local edges = {}
    for i = 1, 4 do edges[i] = NWUI.Tex(box, {0.28, 0.28, 0.30, 0.9}, 1) end
    edges[1]:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0);       edges[1]:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, 0);       edges[1]:SetHeight(lw)
    edges[2]:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0); edges[2]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, 0, 0); edges[2]:SetHeight(lw)
    edges[3]:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0);       edges[3]:SetAnchor(BOTTOMLEFT, box, BOTTOMLEFT, 0, 0);   edges[3]:SetWidth(lw)
    edges[4]:SetAnchor(TOPRIGHT, box, TOPRIGHT, 0, 0);     edges[4]:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, 0, 0); edges[4]:SetWidth(lw)

    -- Icono recortado: sin marco ni fondo detrás, solo la montura
    box.icon = NWUI.Tex(box, nil, 3)
    box.icon:SetDimensions(MOUNT_ICON, MOUNT_ICON)
    box.icon:SetAnchor(CENTER, box, CENTER, 0, 0)
    -- Nombre centrado (hasta 2 líneas)
    box.name = NWUI.Label(box, "$(BOLD_FONT)|16|soft-shadow-thick", C.gold, "")
    box.name:SetAnchor(TOP, box.icon, BOTTOM, 0, 2)
    box.name:SetHidden(true)   -- solo la montura; el nombre sale al pasar el ratón
    box.name:SetWidth(MOUNT_BOX - 12)
    box.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    if box.name.SetMaxLineCount then box.name:SetMaxLineCount(2) end
    if box.name.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then box.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    box.hl = NWUI.Tex(box, {1, 1, 1, 0.05}, 5)
    box.hl:SetAnchorFill(box)
    box.hl:SetHidden(true)

    -- Entrenamiento: debajo del cuadro, sin fondo, en negrita
    local FONT = "$(BOLD_FONT)|17|soft-shadow-thin"
    box.statRows = {}
    local y0 = MOUNT_TITLE_H + 6 + MOUNT_BOX + 10
    for i, key in ipairs({ NWUI.T("mount_speed"), NWUI.T("mount_stamina"), NWUI.T("mount_capacity") }) do
        local row = WM:CreateControl(NWUI.UID("NWUI_MountStat"), block, CT_CONTROL)
        row:SetHeight(22)
        row:SetAnchor(TOPLEFT, block, TOPLEFT, 0, y0 + (i - 1) * 22)
        row:SetAnchor(TOPRIGHT, block, TOPRIGHT, 0, y0 + (i - 1) * 22)
        row.name = NWUI.Label(row, FONT, C.text, key)
        row.name:SetAnchor(LEFT, row, LEFT, 2, 0)
        row.value = NWUI.Label(row, FONT, C.gold, "")
        row.value:SetAnchor(RIGHT, row, RIGHT, -2, 0)
        box.statRows[i] = row
    end
    block:SetHeight(y0 + 3 * 22)

    box:SetMouseEnabled(true)
    box:SetHandler("OnMouseEnter", function(self)
        self.hl:SetHidden(false)
        local name, _, id, desc, sub = INV.GetMountInfo()
        if id then
            InitializeTooltip(ItemTooltip, self, RIGHT, -8, 0, LEFT)
            ItemTooltip:SetCollectible(id, true, false, false)
            return
        end
        InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0, LEFT)
        local text = name or NWUI.T("no_mount")
        if sub then text = text .. "\n|cE3BD66" .. sub .. "|r" end
        if desc and desc ~= "" then text = text .. "\n\n" .. desc end
        if not name then text = text .. "\n\n" .. NWUI.T("mount_hint") end
        SetTooltipText(InformationTooltip, text)
    end)
    box:SetHandler("OnMouseExit", function(self)
        self.hl:SetHidden(true)
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
    end)
    INV.mountBox = box

    local function update() INV.UpdateMount() end
    for _, ev in ipairs({ "EVENT_ACTIVE_MOUNT_CHANGED", "EVENT_MOUNT_INFO_UPDATED",
                          "EVENT_COLLECTIBLE_UPDATED", "EVENT_COLLECTIBLES_UPDATED",
                          "EVENT_RIDING_SKILL_IMPROVEMENT", "EVENT_PLAYER_ACTIVATED" }) do
        NWUI.On("NWUI_Mount_" .. ev, ev, function() NWUI.Throttle("NWUI_MountUpd", 150, update) end)
    end
    INV.UpdateMount()
end

-- Centra el cuadro cuadrado bajo la casilla de en medio de las armas.
function INV.AlignMountIcon()
    local box = INV.mountBox
    if not box then return end
    local block = box.block
    local EQ = NWUI.Equipment
    local mid = EQ and EQ.w1 and EQ.w1[2]
    local dx = 0
    if mid then
        local cx = mid:GetCenter()
        local left = block:GetLeft()
        if cx > 0 then
            local w = block:GetWidth()
            local room = math.max(0, w / 2 - MOUNT_BOX / 2)
            dx = zo_clamp((cx - left) - w / 2, -room, room)
        end
    end
    box:ClearAnchors()
    box:SetAnchor(TOP, block, TOP, NWUI.PixelSnap(dx), MOUNT_TITLE_H + 6)
end

function INV.UpdateMount()
    local box = INV.mountBox
    if not box then return end
    local name, icon, _, _, sub = INV.GetMountInfo()
    box.title:SetText(sub and NWUI.T("mount_random") or NWUI.T("mount"))
    if name then
        box.name:SetText(sub or name)
        NWUI.SetColor(box.name, C.gold)
        if icon and icon ~= "" then
            box.icon:SetTexture(icon)
            box.icon:SetHidden(false)
            box.icon:SetAlpha(1)
        else
            box.icon:SetHidden(true)
        end
    else
        box.name:SetText(NWUI.T("no_mount"))
        NWUI.SetColor(box.name, C.textDim)
        box.icon:SetTexture("EsoUI/Art/Collections/Random_AnyMount.dds")
        box.icon:SetHidden(false)
        box.icon:SetAlpha(0.3)
    end
    -- Entrenamiento del establo
    local vals = { "—", "—", "—" }
    local inv, invMax, sta, staMax, spd, spdMax = GetRidingStats()
    vals[1] = string.format("%d%% / %d%%", spd, spdMax)
    vals[2] = string.format("%d / %d", sta, staMax)
    vals[3] = string.format("%d / %d", inv, invMax)
    for i, row in ipairs(box.statRows) do row.value:SetText(vals[i]) end
    INV.AlignMountIcon()
end

-- Coloca las pestañas (bajo las armas equipadas) y las muestra solo en el inventario
function INV.PlaceTabs(mode)
    local t = INV.tabs
    if not t then return end
    if mode ~= "inventory" then
        t.bar:SetHidden(true)
        INV.backpack.view = "items"
        NWUI.SetTitle(INV.backpack.titleLabel, NWUI.T("title_items"))
        return
    end
    t.bar:SetHidden(false)
    t.bar:ClearAnchors()
    local EQ = NWUI.Equipment
    if EQ and EQ.weapons then
        -- mismo ancho y borde izquierdo que el bloque de ARMAS
        t.bar:SetAnchor(TOPLEFT, EQ.weapons, BOTTOMLEFT, 0, 18)
        t.bar:SetAnchor(TOPRIGHT, EQ.weapons, BOTTOMRIGHT, 0, 18)
    else
        t.bar:SetAnchor(BOTTOMRIGHT, INV.backpack.tlw, TOPRIGHT, 0, -8)
    end
    INV.UpdateTabs()
    INV.UpdateMount()
    -- las armas se recolocan al abrirse; se vuelve a alinear el icono después
    zo_callLater(function() INV.AlignMountIcon() end, 60)
end

-- =====================================================================
-- Inicio
-- =====================================================================
function INV.ResizeAll()
    if not INV.panels then return end
    for _, p in ipairs(INV.panels) do
        if not p.tlw:IsHidden() then
            p:ApplySize()
            p:Refresh()
        end
    end
end

function INV.SoftRefreshAll()
    if not INV.panels then return end
    for _, p in ipairs(INV.panels) do p:QueueRefresh(true) end
end

function INV.RefreshAll()
    if not INV.panels then return end
    for _, p in ipairs(INV.panels) do p:QueueRefresh() end
end

function INV.Init()
    if not NWUI.sv.inv.enabled then return end
    INV.backpack = Panel:New("backpack", NWUI.T("title_items"), "backpack")
    INV.bank     = Panel:New("bank", NWUI.T("title_bank"), "bank")
    INV.guild    = Panel:New("guild", NWUI.T("title_guild"), "guild")
    INV.panels   = { INV.backpack, INV.bank, INV.guild }
    INV.CreateTabs()
    INV.HookNativeWheel()
    NWUI.On("NWUI_Inv_WheelHook", "EVENT_PLAYER_ACTIVATED", function() INV.HookNativeWheel() end)

    NWUI.On("NWUI_Inv_Slot", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", function(_, bag, slot, isNewItem)
        if slot ~= nil then if isNewItem then INV.MarkNew(bag, slot) else INV.ForgetNew(bag, slot) end end
        INV.QueueTabNew()
        if bag == BAG_BACKPACK or bag == BAG_WORN then INV.backpack:QueueRefresh() end
        if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or (IsHouseBankBag(bag)) then
            INV.bank:QueueRefresh()
        end
        if bag == BAG_GUILDBANK then INV.guild:QueueRefresh() end
        if BAG_VIRTUAL and bag == BAG_VIRTUAL and INV.backpack.view == "craftbag" then INV.backpack:QueueRefresh() end
    end)
    local function ViewRefresh(view)
        return function() if INV.backpack.view == view then INV.backpack:QueueRefresh() end end
    end
    NWUI.On("NWUI_Inv_QS1", "EVENT_ACTION_SLOT_UPDATED", ViewRefresh("quickslot"))
    -- al levantar un objeto (arrastre del juego) se quita el tooltip para que
    -- no tape la rueda ni las casillas donde se va a soltar
    NWUI.On("NWUI_Inv_CursorPickup", "EVENT_CURSOR_PICKUP", function()
        if NWUI.Slot and NWUI.Slot.HideTooltip then NWUI.Slot.HideTooltip() end
    end)
    NWUI.On("NWUI_Inv_QS2", "EVENT_HOTBAR_SLOT_UPDATED", ViewRefresh("quickslot"))
    NWUI.On("NWUI_Inv_QS2", "EVENT_ACTIVE_QUICKSLOT_CHANGED", ViewRefresh("quickslot"))
    NWUI.On("NWUI_Inv_QS3", "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", ViewRefresh("quickslot"))
    for _, ev in ipairs({ "EVENT_QUEST_ADDED", "EVENT_QUEST_REMOVED", "EVENT_QUEST_TOOL_UPDATED", "EVENT_QUEST_CONDITION_COUNTER_CHANGED" }) do
        NWUI.On("NWUI_Inv_" .. ev, ev, ViewRefresh("quest"))
    end
    NWUI.On("NWUI_Inv_CurView", "EVENT_CURRENCY_UPDATE", ViewRefresh("currency"))
    NWUI.On("NWUI_Inv_Full", "EVENT_INVENTORY_FULL_UPDATE", INV.SoftRefreshAll)
    NWUI.On("NWUI_Inv_Cap", "EVENT_INVENTORY_BAG_CAPACITY_CHANGED", INV.SoftRefreshAll)
    NWUI.On("NWUI_Inv_BankCap", "EVENT_INVENTORY_BANK_CAPACITY_CHANGED", INV.SoftRefreshAll)

    local function Footers()
        for _, p in ipairs(INV.panels) do
            if not p.tlw:IsHidden() then p:UpdateFooter() end
        end
    end
    NWUI.On("NWUI_Inv_Money", "EVENT_MONEY_UPDATE", Footers)
    NWUI.On("NWUI_Inv_Curr", "EVENT_CURRENCY_UPDATE", Footers)

    NWUI.On("NWUI_GB_Sel", "EVENT_GUILD_BANK_SELECTED", function()
        INV.guild.loading = true
        INV.guild:Refresh()
    end)
    NWUI.On("NWUI_GB_Ready", "EVENT_GUILD_BANK_ITEMS_READY", function()
        INV.guild.loading = false
        INV.guild:QueueRefresh()
    end)
    NWUI.On("NWUI_GB_Add", "EVENT_GUILD_BANK_ITEM_ADDED", function() INV.guild:QueueRefresh() end)
    NWUI.On("NWUI_GB_Rem", "EVENT_GUILD_BANK_ITEM_REMOVED", function() INV.guild:QueueRefresh() end)
end
