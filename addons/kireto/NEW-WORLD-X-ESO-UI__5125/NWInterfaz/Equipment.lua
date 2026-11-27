-- Vista del equipo equipado alrededor del personaje (como en New World):
-- armadura agrupada por peso, armas por barra, joyería y estadísticas
-- completas del juego con su descripción al pasar el ratón, y Mundus.
local NWUI = NWUI
local EQ = {}
NWUI.Equipment = EQ

local WM = WINDOW_MANAGER
local C, F = NWUI.C, NWUI.F
local GAP = 5
local TITLE_H = 26
local function SIZE() return NWUI.sv.inv.eqSize or 60 end
local function S(name) return _G[name] end

-- { constante, nombre al pasar el ratón, textura vacía de respaldo }
local ARMOR = {
    { "EQUIP_SLOT_HEAD",      "slot_head",   "gearSlot_head" },
    { "EQUIP_SLOT_SHOULDERS", "slot_shoulders",  "gearSlot_shoulders" },
    { "EQUIP_SLOT_CHEST",     "slot_chest",    "gearSlot_chest" },
    { "EQUIP_SLOT_HAND",      "slot_hands",    "gearSlot_hands" },
    { "EQUIP_SLOT_WAIST",     "slot_waist",  "gearSlot_belt" },
    { "EQUIP_SLOT_LEGS",      "slot_legs",  "gearSlot_legs" },
    { "EQUIP_SLOT_FEET",      "slot_feet",     "gearSlot_feet" },
}
local BAR1 = {
    { "EQUIP_SLOT_MAIN_HAND", "slot_main1",   "gearSlot_mainHand" },
    { "EQUIP_SLOT_OFF_HAND",  "slot_off1",  "gearSlot_offHand" },
    { "EQUIP_SLOT_POISON",    "slot_poison1",           "gearSlot_poison" },
}
local BAR2 = {
    { "EQUIP_SLOT_BACKUP_MAIN",   "slot_main2",  "gearSlot_mainHand" },
    { "EQUIP_SLOT_BACKUP_OFF",    "slot_off2", "gearSlot_offHand" },
    { "EQUIP_SLOT_BACKUP_POISON", "slot_poison2",          "gearSlot_poison" },
}
local JEWEL = {
    { "EQUIP_SLOT_NECK",    "slot_neck",   "gearSlot_neck" },
    { "EQUIP_SLOT_RING1",   "slot_ring1", "gearSlot_ring" },
    { "EQUIP_SLOT_RING2",   "slot_ring2", "gearSlot_ring" },
    { "EQUIP_SLOT_COSTUME", "slot_costume",  "gearSlot_costume" },
}

-- Estadísticas en el mismo orden y grupos que la hoja original del juego.
-- Nombre y descripción del juego cuando existen; si no, los de respaldo.
local STATS = {
    { "STAT_MAGICKA_MAX",         "st_mag",
      "st_mag_d" },
    { "STAT_MAGICKA_REGEN_COMBAT", "st_magr",
      "st_magr_d" },
    { "STAT_HEALTH_MAX",          "st_hp",
      "st_hp_d" },
    { "STAT_HEALTH_REGEN_COMBAT", "st_hpr",
      "st_hpr_d" },
    { "STAT_STAMINA_MAX",         "st_sta",
      "st_sta_d" },
    { "STAT_STAMINA_REGEN_COMBAT", "st_star",
      "st_star_d" },
    "sep",
    { "STAT_SPELL_POWER",         "st_sp",
      "st_sp_d" },
    { "STAT_SPELL_CRITICAL",      "st_scrit",
      "st_scrit_d", "crit" },
    { "STAT_SPELL_PENETRATION",   "st_spen",
      "st_spen_d" },
    { "STAT_POWER",               "st_wp",
      "st_wp_d" },
    { "STAT_CRITICAL_STRIKE",     "st_wcrit",
      "st_wcrit_d", "crit" },
    { "STAT_PHYSICAL_PENETRATION", "st_ppen",
      "st_ppen_d" },
    "sep",
    { "STAT_SPELL_RESIST",        "st_sres",
      "st_sres_d" },
    { "STAT_PHYSICAL_RESIST",     "st_pres",
      "st_pres_d" },
    { "STAT_CRITICAL_RESISTANCE", "st_cres",
      "st_cres_d" },
}

local function GameString(prefix, id)
    if not (prefix and id and GetString) then return nil end
    local ok, s = pcall(GetString, prefix, id)
    if ok and type(s) == "string" and s ~= "" then return s end
end

local function StatName(def, st)
    return GameString("SI_DERIVEDSTATS", st) or NWUI.T(def[2])
end

local function StatDescription(def, st)
    for _, prefix in ipairs({ "SI_STAT_TOOLTIP_DESCRIPTION", "SI_STATTOOLTIPDESCRIPTION", "SI_STAT_DESCRIPTION" }) do
        local s = GameString(prefix, st)
        if s then return s end
    end
    return NWUI.T(def[3])
end

local function EmptyTexture(slot, fallback)
    if ZO_Character_GetEmptyEquipSlotTexture then
        local ok, t = pcall(ZO_Character_GetEmptyEquipSlotTexture, slot)
        if ok and type(t) == "string" and t ~= "" then return t end
    end
    return "EsoUI/Art/CharacterWindow/" .. fallback .. ".dds"
end

local function WornData(def, side)
    local slot = S(def[1])
    if HasItemInSlot(BAG_WORN, slot) then
        local icon, stack, _, _, locked, equipType, _, quality = GetItemInfo(BAG_WORN, slot)
        if GetItemDisplayQuality then quality = GetItemDisplayQuality(BAG_WORN, slot) end
        local d = {
            kind = "worn", hasItem = true, bagId = BAG_WORN, slotIndex = slot, icon = icon,
            stack = (equipType == EQUIP_TYPE_POISON) and stack or 1, quality = quality or 1,
            meets = true, locked = locked, equipType = equipType,
            slotType = SLOT_TYPE_EQUIPMENT, tooltipSide = side,
            name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(BAG_WORN, slot)),
        }
        -- candado blanco si la pieza equipada está bloqueada (como en el inventario)
        if IsItemPlayerLocked then d.locked = IsItemPlayerLocked(BAG_WORN, slot) or locked end
        if DoesItemHaveDurability and DoesItemHaveDurability(BAG_WORN, slot) then
            d.condition = GetItemCondition(BAG_WORN, slot)
        end
        return d
    end
    return {
        kind = "worn", hasItem = false, bagId = BAG_WORN, slotIndex = slot,
        emptyIcon = EmptyTexture(slot, def[3]), emptyName = NWUI.T(def[2]),
        slotType = SLOT_TYPE_EQUIPMENT, tooltipSide = side,
    }
end

local function Title(parent, text)
    local l = NWUI.Label(parent, F.section, C.text, text)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    local line = NWUI.Tex(parent, {0.71, 0.58, 0.33, 0.55}, 2)
    line:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, TITLE_H - 3)
    line:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, TITLE_H - 3)
    line:SetHeight(1)
    return l
end

local function MakeSlots(parent, defs, side)
    local list = {}
    for _, def in ipairs(defs) do
        if S(def[1]) ~= nil then
            local c = NWUI.Slot.Create(parent)
            c.def = def
            c.side = side
            list[#list + 1] = c
        end
    end
    return list
end

-- ---------------------------------------------------------------------
-- Información emergente de estadísticas y Mundus
-- ---------------------------------------------------------------------
local function ShowInfo(control, title, body)
    InitializeTooltip(InformationTooltip, control, LEFT, 12, 0, RIGHT)
    local ok = pcall(function()
        InformationTooltip:AddLine(title, "ZoFontHeader2", 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
        if body and body ~= "" then
            ZO_Tooltip_AddDivider(InformationTooltip)
            InformationTooltip:AddLine(body, "ZoFontGame", 0.89, 0.80, 0.55, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
        end
    end)
    if not ok then
        SetTooltipText(InformationTooltip, title .. ((body and body ~= "") and ("\n" .. body) or ""))
    end
end

local function HideInfo() ClearTooltip(InformationTooltip) end

local function GetMundus()
    local out = {}
    local indices = {}
    if GetUnitActiveMundusStoneBuffIndices then
        local r = { pcall(GetUnitActiveMundusStoneBuffIndices, "player") }
        if r[1] then
            for i = 2, #r do
                if type(r[i]) == "number" then indices[#indices + 1] = r[i] end
            end
        end
    end
    local function add(bi)
        local name, _, _, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", bi)
        if name and name ~= "" then
            local n = zo_strformat("<<1>>", name):gsub("^%l", string.upper)
            out[#out + 1] = { name = n, icon = icon, id = abilityId }
        end
    end
    if #indices > 0 then
        for _, bi in ipairs(indices) do add(bi) end
    elseif GetNumBuffs then
        for bi = 1, GetNumBuffs("player") do
            local name = GetUnitBuffInfo("player", bi)
            if name and (name:find("^Don") or name:find("^Boon")) then add(bi) end
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Refresco
-- ---------------------------------------------------------------------
local ARMOR_GROUPS = {
    { key = "light",  title = "grp_light" },
    { key = "medium", title = "grp_medium" },
    { key = "heavy",  title = "grp_heavy" },
    { key = "other",  title = "grp_other" },
    { key = "empty",  title = "grp_empty" },
}

local function LayoutArmor()
    local size = SIZE()
    local perRow = 2
    local groups = { light = {}, medium = {}, heavy = {}, other = {}, empty = {} }
    for _, c in ipairs(EQ.armorSlots) do
        local slot = S(c.def[1])
        local key = "empty"
        if HasItemInSlot(BAG_WORN, slot) then
            local at = GetItemArmorType(BAG_WORN, slot)
            if at == ARMORTYPE_LIGHT then key = "light"
            elseif at == ARMORTYPE_MEDIUM then key = "medium"
            elseif at == ARMORTYPE_HEAVY then key = "heavy"
            else key = "other" end
        end
        table.insert(groups[key], c)
    end
    local order = {}
    for _, g in ipairs(ARMOR_GROUPS) do order[#order + 1] = g end
    table.sort(order, function(a, b)
        if a.key == "empty" then return false end
        if b.key == "empty" then return true end
        local na, nb = #groups[a.key], #groups[b.key]
        if na ~= nb then return na > nb end
        return a.title < b.title
    end)

    local y = TITLE_H + 2
    local used = 0
    for _, g in ipairs(order) do
        local list = groups[g.key]
        if #list > 0 then
            used = used + 1
            local h = EQ.groupHeaders[used]
            h:SetHidden(false)
            h:ClearAnchors()
            h:SetAnchor(TOPLEFT, EQ.armor, TOPLEFT, 0, y)
            h.name:SetText(NWUI.T(g.title))
            h.count:SetText(tostring(#list))
            NWUI.SetColor(h.name, g.key == "empty" and C.textDim or C.gold)
            y = y + 25
            for i, c in ipairs(list) do
                local r, col = math.floor((i - 1) / perRow), (i - 1) % perRow
                c:SetDimensions(size, size)
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, EQ.armor, TOPLEFT, col * (size + GAP), y + r * (size + GAP))
            end
            y = y + math.ceil(#list / perRow) * (size + GAP) + 6
        end
    end
    for i = used + 1, #EQ.groupHeaders do EQ.groupHeaders[i]:SetHidden(true) end
    EQ.armor:SetDimensions(perRow * (size + GAP) - GAP, y)
end

local function LayoutStatic()
    local size = SIZE()
    -- armas
    for r, list in ipairs({ EQ.w1, EQ.w2 }) do
        for i, c in ipairs(list) do
            c:SetDimensions(size, size)
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, EQ.weapons, TOPLEFT, 22 + (i - 1) * (size + GAP), TITLE_H + 2 + (r - 1) * (size + GAP + 10))
        end
    end
    EQ.barLabel1:ClearAnchors()
    EQ.barLabel1:SetAnchor(LEFT, EQ.weapons, TOPLEFT, 2, TITLE_H + 2 + size / 2)
    EQ.barLabel2:ClearAnchors()
    EQ.barLabel2:SetAnchor(LEFT, EQ.weapons, TOPLEFT, 2, TITLE_H + 2 + size + GAP + 10 + size / 2)
    EQ.weapons:SetDimensions(22 + 3 * (size + GAP) - GAP, TITLE_H + 2 + 2 * size + GAP + 10)
    -- joyería
    for i, c in ipairs(EQ.jslots) do
        local r, col = math.floor((i - 1) / 2), (i - 1) % 2
        c:SetDimensions(size, size)
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT, EQ.jewel, TOPLEFT, col * (size + GAP), TITLE_H + 2 + r * (size + GAP))
    end
    EQ.jewel:SetDimensions(math.max(2 * size + GAP, 120), TITLE_H + 2 + 2 * (size + GAP))
    for i, m in ipairs(EQ.mundusSlots) do
        m:SetDimensions(size, size)
        m:ClearAnchors()
        m:SetAnchor(TOPLEFT, EQ.mundus, TOPLEFT, 0, TITLE_H + 2 + (i - 1) * (size + GAP))
    end
    local shown = (EQ.mundusSlots[2] and not EQ.mundusSlots[2]:IsHidden()) and 2 or 1
    EQ.mundus:SetDimensions(math.max(2 * size + GAP, size + 170), TITLE_H + 2 + shown * (size + GAP))
end

function EQ.Refresh()
    if not EQ.tlw then return end
    for _, c in ipairs(EQ.allSlots) do
        NWUI.Slot.Setup(c, WornData(c.def, c.side))
    end
    LayoutArmor()
    LayoutStatic()

    if NWUI.Inventory and NWUI.Inventory.AlignMountIcon then pcall(NWUI.Inventory.AlignMountIcon) end

    -- Barra de armas activa
    local active = 1
    if GetActiveWeaponPairInfo then
        local pair = GetActiveWeaponPairInfo()
        if ACTIVE_WEAPON_PAIR_BACKUP and pair == ACTIVE_WEAPON_PAIR_BACKUP then active = 2 end
    end
    NWUI.SetColor(EQ.barLabel1, active == 1 and C.gold or C.textDim)
    NWUI.SetColor(EQ.barLabel2, active == 2 and C.gold or C.textDim)

    -- Estadísticas
    for _, row in ipairs(EQ.statRows) do
        local st = S(row.def[1])
        local text
        if st then
            local ok, v = pcall(GetPlayerStat, st, STAT_BONUS_OPTION_APPLY_BONUS)
            if ok and type(v) == "number" then
                text = ZO_CommaDelimitNumber(v)
                if row.def[4] == "crit" and GetCriticalStrikeChance then
                    local ok2, pct = pcall(GetCriticalStrikeChance, v, true)
                    if ok2 and type(pct) == "number" then text = string.format("%.1f %%", pct) end
                end
            end
            row.name:SetText(StatName(row.def, st))
        end
        row.value:SetText(text or "—")
    end

    -- Mundus (icono junto a la joyería)
    local mundus = GetMundus()
    for i, m in ipairs(EQ.mundusSlots) do
        local data = mundus[i]
        m.data = data
        m.name:SetText(data and data.name or (i == 1 and "|c888888" .. NWUI.T("no_mundus") .. "|r" or ""))
        m.name:SetHidden(not data and i ~= 1)
        if data then
            m:SetHidden(false)
            if data.icon and data.icon ~= "" then
                m.icon:SetTexture(data.icon)
                m.icon:SetHidden(false)
                m.icon:SetAlpha(1)
            else
                m.icon:SetHidden(true)
            end
        elseif i == 1 then
            m:SetHidden(false)
            m.icon:SetTexture("EsoUI/Art/Icons/ability_mundusstones_013.dds")
            m.icon:SetHidden(false)
            m.icon:SetAlpha(0.25)
        else
            m:SetHidden(true)
        end
    end
end

function EQ.QueueRefresh()
    if not EQ.tlw or EQ.tlw:IsHidden() then return end
    NWUI.Throttle("NWUI_EQ_Refresh", 120, EQ.Refresh)
end

function EQ.SetUnlocked(state)
    if not EQ.allSlots then return end
    for _, c in ipairs(EQ.allSlots) do c:SetMouseEnabled(not state) end
end

local function Wheel(delta)
    local s = NWUI.sv.inv
    s.eqSize = zo_clamp((s.eqSize or 60) + delta * 2, 32, 90)
    EQ.Refresh()
end

-- ---------------------------------------------------------------------
-- Atributos (barras estrechas junto al inventario, como en New World)
-- ---------------------------------------------------------------------
local V_HEALTH  = COMBAT_MECHANIC_FLAGS_HEALTH  or POWERTYPE_HEALTH
local V_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA
local V_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA
local VITALS_W = 230
local VFILL = {
    health      = {0.72, 0.13, 0.12, 1},
    magicka     = {0.16, 0.38, 0.82, 1},
    stamina_nw  = {0.86, 0.68, 0.14, 1},
    stamina_eso = {0.30, 0.62, 0.20, 1},
}

local function VitalBar(parent, key, h)
    local b = WM:CreateControl(NWUI.UID("NWUI_Vital"), parent, CT_CONTROL)
    b.key = key
    b:SetDimensions(VITALS_W, h)
    b.border, b.bg = NWUI.FlatBox(b, {0.05, 0.05, 0.06, 0.88}, {0.32, 0.32, 0.34, 1}, 1)
    b.fill = NWUI.Tex(b, VFILL.health, 2)
    b.fill:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    b.fill:SetAnchor(BOTTOMLEFT, b, BOTTOMLEFT, 1, -1)
    b.fill:SetWidth(0)
    b.label = NWUI.Label(b, "$(BOLD_FONT)|" .. (h >= 20 and 15 or 13) .. "|soft-shadow-thick", C.text, "")
    b.label:SetAnchor(CENTER, b, CENTER, 0, 0)
    return b
end

local function BuildVitals(tlw)
    local v = WM:CreateControl("NWUI_EQ_Vitals", tlw, CT_CONTROL)
    v:SetDimensions(VITALS_W, 22 + 16 + 16 + 6)
    -- mismo orden que en el HUD: magia, aguante y vida
    v.bars = {
        [V_MAGICKA] = VitalBar(v, "magicka", 16),
        [V_STAMINA] = VitalBar(v, "stamina", 16),
        [V_HEALTH]  = VitalBar(v, "health", 22),
    }
    v.bars[V_MAGICKA]:SetAnchor(TOPLEFT, v, TOPLEFT, 0, 0)
    v.bars[V_STAMINA]:SetAnchor(TOPLEFT, v.bars[V_MAGICKA], BOTTOMLEFT, 0, 3)
    v.bars[V_HEALTH]:SetAnchor(TOPLEFT, v.bars[V_STAMINA], BOTTOMLEFT, 0, 3)
    return v
end

function EQ.RefreshVitals()
    local v = EQ.vitals
    if not v then return end
    local hs = NWUI.sv.hud or {}
    local edge = (hs.barBorder == "gold") and C.headerLine or {0.32, 0.32, 0.34, 1}
    for ptype, b in pairs(v.bars) do
        local col = VFILL[b.key] or (hs.staminaColor == "eso" and VFILL.stamina_eso or VFILL.stamina_nw)
        NWUI.SetColor(b.fill, col)
        NWUI.SetColor(b.border, edge)
        local cur, max, eff = GetUnitPower("player", ptype)
        cur = cur or 0
        max = eff or max
        if not max or max <= 0 then max = 1 end
        b.fill:SetWidth(math.max(0, (b:GetWidth() - 2) * zo_clamp(cur / max, 0, 1)))
        if b.key == "health" then
            b.label:SetText(ZO_CommaDelimitNumber(cur) .. " / " .. ZO_CommaDelimitNumber(max))
        else
            b.label:SetText(ZO_CommaDelimitNumber(cur))
        end
    end
end

-- ---------------------------------------------------------------------
-- Construcción
-- ---------------------------------------------------------------------
-- Columnas de la tabla de estadísticas (horizontal, 2 columnas)
local COL_A = { 1, 2, 3, 4, 5, 6 }          -- recursos
local COL_B = { 8, 9, 10, 11, 12, 13 }      -- daño, crítico y penetración
local COL_RES = { 15, 16, 17 }              -- resistencias (fila inferior)

local function MakeStatRow(parent, def)
    local row = WM:CreateControl(NWUI.UID("NWUI_StatRow"), parent, CT_CONTROL)
    row:SetHeight(20)
    local hl = NWUI.Tex(row, {1, 1, 1, 0.07}, 1)
    hl:SetAnchorFill(row)
    hl:SetHidden(true)
    local name = NWUI.Label(row, F.small, C.text, NWUI.T(def[2]))
    name:SetAnchor(LEFT, row, LEFT, 6, 0)
    local value = NWUI.Label(row, F.small, C.gold, "")
    value:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row:SetMouseEnabled(true)
    row:SetHandler("OnMouseEnter", function(self)
        hl:SetHidden(false)
        local st = S(def[1])
        ShowInfo(self, StatName(def, st), StatDescription(def, st))
    end)
    row:SetHandler("OnMouseExit", function()
        hl:SetHidden(true)
        HideInfo()
    end)
    EQ.statRows[#EQ.statRows + 1] = { def = def, name = name, value = value }
    return row
end

local function BuildStats(tlw)
    local stats = WM:CreateControl("NWUI_EQ_Stats", tlw, CT_CONTROL)
    local W, PADX, ROWH, HEAD = 276, 10, 21, 32

    -- Fondo negro muy translúcido (apenas se nota), sin cabecera azul
    -- Fondo NEGRO translúcido; el borde es solo una línea fina (no un relleno)
    local bg = NWUI.Tex(stats, nil, 0)
    bg:SetAnchorFill(stats)
    NWUI.Gradient(bg, {0, 0, 0, 0.55}, {0, 0, 0, 0.45})
    local EDGE = {0.25, 0.25, 0.26, 0.9}
    local e = {}
    for i = 1, 4 do e[i] = NWUI.Tex(stats, EDGE, 1) end
    e[1]:SetAnchor(TOPLEFT, stats, TOPLEFT, 0, 0);       e[1]:SetAnchor(TOPRIGHT, stats, TOPRIGHT, 0, 0);       e[1]:SetHeight(1)
    e[2]:SetAnchor(BOTTOMLEFT, stats, BOTTOMLEFT, 0, 0); e[2]:SetAnchor(BOTTOMRIGHT, stats, BOTTOMRIGHT, 0, 0); e[2]:SetHeight(1)
    e[3]:SetAnchor(TOPLEFT, stats, TOPLEFT, 0, 0);       e[3]:SetAnchor(BOTTOMLEFT, stats, BOTTOMLEFT, 0, 0);   e[3]:SetWidth(1)
    e[4]:SetAnchor(TOPRIGHT, stats, TOPRIGHT, 0, 0);     e[4]:SetAnchor(BOTTOMRIGHT, stats, BOTTOMRIGHT, 0, 0); e[4]:SetWidth(1)

    local title = NWUI.Label(stats, F.section, C.text, NWUI.T("stats"))
    title:SetAnchor(TOPLEFT, stats, TOPLEFT, PADX + 2, 7)
    local hl = NWUI.Tex(stats, {0.71, 0.58, 0.33, 0.55}, 3)
    hl:SetAnchor(TOPLEFT, stats, TOPLEFT, PADX, HEAD - 3)
    hl:SetAnchor(TOPRIGHT, stats, TOPRIGHT, -PADX, HEAD - 3)
    hl:SetHeight(1)

    EQ.statRows = {}
    local y = HEAD + 10
    local zebra = 0
    for _, def in ipairs(STATS) do
        if def == "sep" then
            local line = NWUI.Tex(stats, C.sectionLine, 2)
            line:SetAnchor(TOPLEFT, stats, TOPLEFT, PADX, y + 5)
            line:SetAnchor(TOPRIGHT, stats, TOPRIGHT, -PADX, y + 5)
            line:SetHeight(1)
            y = y + 12
            zebra = 0
        else
            local row = MakeStatRow(stats, def)
            row:SetAnchor(TOPLEFT, stats, TOPLEFT, PADX - 4, y)
            row:SetWidth(W - (PADX - 4) * 2)
            row:SetHeight(ROWH)
            zebra = zebra + 1
            if zebra % 2 == 0 then
                local z = NWUI.Tex(row, {1, 1, 1, 0.025}, 0)
                z:SetAnchorFill(row)
            end
            y = y + ROWH
        end
    end
    stats:SetDimensions(W, y + 10)
    return stats
end

-- Mundus como un icono más, a la derecha de la joyería
local function CreateMundusSlot(parent)
    local c = WM:CreateControl(NWUI.UID("NWUI_Mundus"), parent, CT_CONTROL)
    c.border, c.bg = NWUI.FlatBox(c, {0.10, 0.12, 0.16, 1}, {0.45, 0.55, 0.70, 1}, 1)
    c.icon = NWUI.Tex(c, nil, 3)
    c.icon:SetAnchor(TOPLEFT, c, TOPLEFT, 3, 3)
    c.icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, -3)
    c.hl = NWUI.Tex(c, {1, 1, 1, 0.10}, 6)
    c.hl:SetAnchorFill(c)
    c.hl:SetHidden(true)
    c.name = NWUI.Label(parent, F.mundus, C.gold, "")
    c.name:SetAnchor(LEFT, c, RIGHT, 10, 0)
    c:SetMouseEnabled(true)
    c:SetHandler("OnMouseEnter", function(self)
        self.hl:SetHidden(false)
        if self.data then
            local desc = (self.data.id and GetAbilityDescription) and GetAbilityDescription(self.data.id) or ""
            ShowInfo(self, self.data.name, desc)
        else
            ShowInfo(self, "Mundus", NWUI.T("no_mundus_tip"))
        end
    end)
    c:SetHandler("OnMouseExit", function(self)
        self.hl:SetHidden(true)
        HideInfo()
    end)
    return c
end

function EQ.Init()
    local s = NWUI.sv.inv
    if not (s.enabled and s.equipment) then return end

    local tlw = WM:CreateTopLevelWindow("NWUI_Equipment")
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetMouseEnabled(false)
    tlw:SetHidden(true)
    EQ.tlw = tlw
    EQ.allSlots = {}
    local function addAll(list) for _, c in ipairs(list) do EQ.allSlots[#EQ.allSlots + 1] = c end end

    -- Armadura (agrupada por peso)
    local armor = WM:CreateControl("NWUI_EQ_Armor", tlw, CT_CONTROL)
    EQ.armor = armor
    Title(armor, NWUI.T("armor"))
    EQ.armorSlots = MakeSlots(armor, ARMOR, "right")
    addAll(EQ.armorSlots)
    EQ.groupHeaders = {}
    for i = 1, #ARMOR_GROUPS do
        local h = WM:CreateControl(NWUI.UID("NWUI_ArmorGrp"), armor, CT_CONTROL)
        h:SetDimensions(200, 22)
        h.name = NWUI.Label(h, F.groupHdr, C.gold, "")
        h.name:SetAnchor(LEFT, h, LEFT, 0, 0)
        h.count = NWUI.Label(h, F.groupHdr, C.text, "")
        h.count:SetAnchor(LEFT, h.name, RIGHT, 8, 0)
        h:SetHidden(true)
        EQ.groupHeaders[i] = h
    end

    -- Armas
    local weapons = WM:CreateControl("NWUI_EQ_Weapons", tlw, CT_CONTROL)
    EQ.weapons = weapons
    Title(weapons, NWUI.T("weapons"))
    EQ.w1 = MakeSlots(weapons, BAR1, "left")
    EQ.w2 = MakeSlots(weapons, BAR2, "left")
    addAll(EQ.w1)
    addAll(EQ.w2)
    EQ.barLabel1 = NWUI.Label(weapons, F.level, C.gold, "1")
    EQ.barLabel2 = NWUI.Label(weapons, F.level, C.textDim, "2")

    -- Joyería y disfraz
    local jewel = WM:CreateControl("NWUI_EQ_Jewelry", tlw, CT_CONTROL)
    EQ.jewel = jewel
    Title(jewel, NWUI.T("jewelry"))
    EQ.jslots = MakeSlots(jewel, JEWEL, "right")
    addAll(EQ.jslots)
    -- Mundus (bloque propio con título)
    local mundus = WM:CreateControl("NWUI_EQ_Mundus", tlw, CT_CONTROL)
    EQ.mundus = mundus
    Title(mundus, NWUI.T("mundus"))
    EQ.mundusSlots = { CreateMundusSlot(mundus), CreateMundusSlot(mundus) }

    -- Estadísticas
    local stats = BuildStats(tlw)
    EQ.stats = stats
    -- Barras de atributos
    EQ.vitals = BuildVitals(tlw)

    LayoutStatic()
    LayoutArmor()

    NWUI.RegisterMovable(armor, "eq_armor", function(c)
        c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 28, 110)
    end, NWUI.T("armor"), false, Wheel)
    NWUI.RegisterMovable(weapons, "eq_weapons", function(c)
        local inv = NWUI.Inventory and NWUI.Inventory.backpack
        if inv then
            c:SetAnchor(TOPRIGHT, inv.tlw, TOPLEFT, -26, 0)
        else
            c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, math.floor(GuiRoot:GetWidth() * 0.45), 110)
        end
    end, NWUI.T("weapons"), false, Wheel)
    NWUI.RegisterMovable(jewel, "eq_jewelry", function(c)
        c:SetAnchor(TOPLEFT, armor, BOTTOMLEFT, 0, 16)
    end, NWUI.T("jewelry"), false, Wheel)
    NWUI.RegisterMovable(mundus, "eq_mundus", function(c)
        c:SetAnchor(TOPLEFT, jewel, BOTTOMLEFT, 0, 14)
    end, NWUI.T("mundus"), false, Wheel)
    EQ.statsMovable = NWUI.RegisterMovable(stats, "eq_stats", function(c)
        c:SetAnchor(TOPLEFT, armor, TOPRIGHT, 26, 0)
    end, NWUI.T("stats"), false)
    NWUI.RegisterMovable(EQ.vitals, "eq_vitals", function(c)
        local inv = NWUI.Inventory and NWUI.Inventory.backpack
        if inv then
            c:SetAnchor(BOTTOMRIGHT, inv.tlw, BOTTOMLEFT, -26, -14)
        else
            c:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 28, -120)
        end
    end, NWUI.T("mv_vitals"), false)

    EQ.fragment = ZO_FadeSceneFragment:New(tlw)
    EQ.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            -- Las estadísticas siempre visibles al abrir el inventario
            if EQ.stats then
                EQ.stats:SetHidden(false)
                if EQ.statsMovable then NWUI.ApplyPosition(EQ.statsMovable) end
            end
            pcall(EQ.RefreshVitals)
            local ok, err = pcall(EQ.Refresh)
            if not ok then d("|cFF6666[NW Interfaz]|r " .. NWUI.T("eq_error", tostring(err))) end
        end
    end)

    NWUI.On("NWUI_EQ_Worn", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", EQ.QueueRefresh, REGISTER_FILTER_BAG_ID, BAG_WORN)
    NWUI.On("NWUI_EQ_Stats", "EVENT_STATS_UPDATED", EQ.QueueRefresh)
    NWUI.On("NWUI_EQ_Power", "EVENT_POWER_UPDATE", function(_, unitTag)
        if unitTag == "player" and EQ.tlw and not EQ.tlw:IsHidden() then EQ.RefreshVitals() end
    end)
    NWUI.On("NWUI_EQ_Pair", "EVENT_ACTIVE_WEAPON_PAIR_CHANGED", EQ.QueueRefresh)
    NWUI.On("NWUI_EQ_Level", "EVENT_LEVEL_UPDATE", EQ.QueueRefresh)
    NWUI.On("NWUI_EQ_Effect", "EVENT_EFFECT_CHANGED", EQ.QueueRefresh, REGISTER_FILTER_UNIT_TAG, "player")
end
