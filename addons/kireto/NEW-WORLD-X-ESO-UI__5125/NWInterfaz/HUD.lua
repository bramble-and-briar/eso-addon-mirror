-- HUD: barras apiladas (magia / aguante / salud), nivel o Campeón,
-- habilidades (botones nativos, más chicos y sin marcos) y consumibles.
-- No toca la brújula, el menú superior ni el rastreador de misiones.
local NWUI = NWUI
local HUD = {}
NWUI.HUD = HUD

local WM = WINDOW_MANAGER
local C, F = NWUI.C, NWUI.F

local P_HEALTH  = COMBAT_MECHANIC_FLAGS_HEALTH  or POWERTYPE_HEALTH
local P_MAGICKA = COMBAT_MECHANIC_FLAGS_MAGICKA or POWERTYPE_MAGICKA
local P_STAMINA = COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA

-- La rueda de objetos rápidos usa las casillas 1–8 de su propia categoría.
-- Mismo orden que Bandits UI, para que tus atajos sigan coincidiendo.
local QS_CAT   = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
local QS_MAP   = { 4, 3, 2, 1, 8, 7, 6, 5 }
local QS_MAX   = 8
local BTN_BASE = 50 -- tamaño base de un botón de acción (modo teclado)
local KEY_ROOM = 22 -- espacio bajo los botones para la tecla
local CHAMPION_ICON = "EsoUI/Art/Champion/champion_icon_32.dds"

local FILL = {
    health      = {0.72, 0.13, 0.12, 1},
    magicka     = {0.16, 0.38, 0.82, 1},
    stamina_nw  = {0.86, 0.68, 0.14, 1},
    stamina_eso = {0.30, 0.62, 0.20, 1},
}

local bars, animating = {}, {}
local lastT

local function QSlot(i) return QS_MAP[i] or i end

-- =====================================================================
-- Barras
-- =====================================================================
local function CreateBar(parent, key)
    local c = WM:CreateControl("NWUI_Bar_" .. key, parent, CT_CONTROL)
    c.key = key
    c.border, c.bg = NWUI.FlatBox(c, {0.05, 0.05, 0.06, 0.88}, C.black, 1)
    c.fill = NWUI.Tex(c, FILL.health, 2)
    c.fill:SetAnchor(TOPLEFT, c, TOPLEFT, 1, 1)
    c.fill:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 1, -1)
    c.fill:SetWidth(0)
    c.shield = NWUI.Tex(c, {0.93, 0.93, 1, 0.45}, 3)
    c.shield:SetAnchor(TOPLEFT, c, TOPLEFT, 1, 1)
    c.shield:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 1, -1)
    c.shield:SetHidden(true)
    c.label = NWUI.Label(c, F.barSmall, C.text, "")
    c.label:SetAnchor(CENTER, c, CENTER, 0, 0)
    c.cur, c.max, c.shown, c.target = 0, 1, 0, 0
    return c
end

local function RenderBar(b)
    b.fill:SetWidth(math.max(0, (b:GetWidth() - 2) * b.shown))
end

local function SetBarValue(b, cur, max)
    b.cur = cur or 0
    b.max = (max and max > 0) and max or 1
    b.target = zo_clamp(b.cur / b.max, 0, 1)
    if NWUI.sv.hud.showBarText then
        if b.key == "health" then
            b.label:SetText(ZO_CommaDelimitNumber(b.cur) .. " / " .. ZO_CommaDelimitNumber(b.max))
        else
            b.label:SetText(ZO_CommaDelimitNumber(b.cur))
        end
    else
        b.label:SetText("")
    end
    animating[b] = true
end

local function OnUpdate(_, t)
    local dt = lastT and (t - lastT) or 0.016
    lastT = t
    local k = math.min(1, dt * 14)
    for b in pairs(animating) do
        b.shown = b.shown + (b.target - b.shown) * k
        if math.abs(b.target - b.shown) < 0.002 then
            b.shown = b.target
            animating[b] = nil
        end
        RenderBar(b)
    end
end

local function UpdateShield()
    local h = bars[P_HEALTH]
    if not h then return end
    local val = 0
    if GetUnitAttributeVisualizerEffectInfo and ATTRIBUTE_VISUAL_POWER_SHIELDING then
        local ok, v = pcall(GetUnitAttributeVisualizerEffectInfo, "player",
            ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, P_HEALTH)
        if ok and type(v) == "number" then val = v end
    end
    if val > 0 then
        h.shield:SetWidth((h:GetWidth() - 2) * zo_clamp(val / (h.max or 1), 0, 1))
        h.shield:SetHidden(false)
    else
        h.shield:SetHidden(true)
    end
end

local function RefreshPowers()
    for ptype, b in pairs(bars) do
        local cur, max, eff = GetUnitPower("player", ptype)
        SetBarValue(b, cur, eff or max)
        b.shown = b.target
        RenderBar(b)
    end
    UpdateShield()
end

-- =====================================================================
-- Nivel / Campeón (número grande) dentro del marco de imagen
-- =====================================================================
-- Marco del nivel: imagen propia (textures/nivel_marco.dds, 885x132 dentro
-- de una textura de 1024x256) y, detrás, el fondo negro translúcido en
-- degradado recortado con la forma del hexágono (textures/nivel_fondo.dds).
local LEVEL_FRAME = "NWInterfaz/textures/nivel_marco.dds"
local LEVEL_BG    = "NWInterfaz/textures/nivel_fondo.dds"
local IMG_W, IMG_H, TEX_W, TEX_H = 885, 132, 1024, 256
local HEX_H, HEX_CY = 109, 54          -- alto del hexágono y su centro (px de la imagen)

function HUD.UpdateLevel()
    local lv = HUD.level
    if not lv then return end
    local s = NWUI.sv.hud
    lv:SetHidden(not s.showLevel)
    local size = s.levelSize or 26
    lv.label:SetFont("$(BOLD_FONT)|" .. size .. "|soft-shadow-thick")
    -- escala: marco compacto, el hexágono apenas más alto que el número
    local k = (size + 16) / HEX_H
    -- icono de Campeón grande: ~78 % del alto del hexágono (como el ejemplo)
    local iconSize = math.floor(HEX_H * k * 0.78 + 0.5)
    lv.icon:SetDimensions(iconSize, iconSize)
    local W, H = math.floor(IMG_W * k + 0.5), math.floor(IMG_H * k + 0.5)
    lv:SetDimensions(W, H)
    -- offset vertical del centro del hexágono respecto al centro del control
    local dy = (HEX_CY - IMG_H / 2) * k

    local level = GetUnitLevel("player") or 1
    local isCP = level >= 50
    if IsUnitChampion then isCP = IsUnitChampion("player") or isCP end
    lv.icon:ClearAnchors()
    lv.label:ClearAnchors()
    if isCP then
        local cp = 0
        if GetPlayerChampionPointsEarned then
            cp = GetPlayerChampionPointsEarned()
        elseif GetUnitChampionPoints then
            cp = GetUnitChampionPoints("player")
        end
        lv.label:SetText(ZO_CommaDelimitNumber(cp or 0))
        lv.icon:SetHidden(false)
        local tw = lv.label:GetTextWidth() or 0
        local contentW = iconSize + 4 + tw
        lv.icon:SetAnchor(LEFT, lv, CENTER, -contentW / 2, dy)
        lv.label:SetAnchor(LEFT, lv.icon, RIGHT, 4, 0)
    else
        lv.label:SetText(tostring(level))
        lv.icon:SetHidden(true)
        lv.label:SetAnchor(CENTER, lv, CENTER, 0, dy)
    end
end

-- =====================================================================
-- Botones nativos: localizar y aplanar (sin marcos)
-- =====================================================================
local function SlotObj(n)
    if ZO_ActionBar_GetButton then
        local ok, b = pcall(ZO_ActionBar_GetButton, n)
        if ok and b and b.slot then return b end
    end
end

local function SlotCtrl(n)
    local b = SlotObj(n)
    if b then return b.slot end
    return _G["ActionButton" .. n]
end

local function QuickslotCtrl()
    if QuickslotButton then return QuickslotButton end
    local n = (ACTION_BAR_FIRST_UTILITY_BAR_SLOT or 8) + 1
    return _G["ActionButton" .. n]
end
HUD.QuickslotCtrl = QuickslotCtrl

-- Marco plano (línea gris oscura) alrededor de un botón, dibujado en la capa
-- del HUD y ANCLADO a sus bordes: si cambias el tamaño, el marco lo sigue.
local ICON_BORDER = {0.30, 0.30, 0.32, 1}
local frames = {}

local function FrameFor(target, inset)
    if not (target and HUD.tlw) then return end
    inset = inset or 0
    local f = frames[target]
    if not f then
        f = WM:CreateControl(NWUI.UID("NWUI_IconFrame"), HUD.tlw, CT_CONTROL)
        f.edges = {}
        for i = 1, 4 do f.edges[i] = NWUI.Tex(f, ICON_BORDER, 1) end
        frames[target] = f
    end
    local t = NWUI.sv.hud.iconBorder or 2
    local e = f.edges
    f:ClearAnchors()
    f:SetAnchor(TOPLEFT, target, TOPLEFT, inset - t, inset - t)
    f:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, t - inset, t - inset)
    for _, edge in ipairs(e) do edge:ClearAnchors(); NWUI.SetColor(edge, ICON_BORDER) end
    e[1]:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0);       e[1]:SetAnchor(TOPRIGHT, f, TOPRIGHT, 0, 0);       e[1]:SetHeight(t)
    e[2]:SetAnchor(BOTTOMLEFT, f, BOTTOMLEFT, 0, 0); e[2]:SetAnchor(BOTTOMRIGHT, f, BOTTOMRIGHT, 0, 0); e[2]:SetHeight(t)
    e[3]:SetAnchor(TOPLEFT, f, TOPLEFT, 0, 0);       e[3]:SetAnchor(BOTTOMLEFT, f, BOTTOMLEFT, 0, 0);   e[3]:SetWidth(t)
    e[4]:SetAnchor(TOPRIGHT, f, TOPRIGHT, 0, 0);     e[4]:SetAnchor(BOTTOMRIGHT, f, BOTTOMRIGHT, 0, 0); e[4]:SetWidth(t)
    f:SetHidden(t <= 0)
    return f
end
HUD.FrameFor = FrameFor

-- Quita los marcos del juego y de Bandits UI que se veían desfasados al agrandar
local function Flatten(c, obj)
    if not (c and NWUI.sv.hud.flatAbilities) then return end
    local btn = (obj and obj.button) or (c.GetNamedChild and c:GetNamedChild("Button"))
    if btn then
        if btn.SetNormalTexture then pcall(btn.SetNormalTexture, btn, "") end
        if btn.SetPressedTexture then pcall(btn.SetPressedTexture, btn, "") end
    end
    if c.GetNamedChild then
        for _, suffix in ipairs({ "Frame", "Border", "Edge" }) do
            local f = c:GetNamedChild(suffix)
            if f and f.SetAlpha then f:SetAlpha(0) end
        end
        local ic = c:GetNamedChild("IconControl") -- marco de Bandits UI
        if ic then
            if ic.SetEdgeColor then ic:SetEdgeColor(0, 0, 0, 0) end
            if ic.SetCenterColor then ic:SetCenterColor(0, 0, 0, 0) end
        end
    end
    -- antiguos bordes internos (versión 1.1): se ocultan
    if type(c.nwuiEdges) == "table" then
        for _, e in ipairs(c.nwuiEdges) do e:SetHidden(true) end
    end
end

-- Icono real del botón (el botón tiene margen alrededor del icono: el marco
-- se dibuja pegado al icono para que el cuadro sea más chico)
local function IconOf(c, b)
    local ic = b and b.icon
    if (not ic or type(ic) == "function") and c and c.GetNamedChild then ic = c:GetNamedChild("Icon") end
    if ic and type(ic) ~= "function" and ic ~= c and ic.GetParent then return ic end
    return c
end
HUD.IconOf = IconOf

-- Margen entre el borde del botón y su icono, como fracción del tamaño.
-- Se mide una vez (fuera del giro de cambio de barra, que encoge el icono)
-- y se recuerda; 0 si todavía no se puede medir.
local insetCache = setmetatable({}, { __mode = "k" })
local function IconInset(c, b)
    if not c then return 0 end
    if insetCache[c] then return insetCache[c] end
    local ic = IconOf(c, b)
    if ic == c or not (c.GetWidth and ic.GetWidth and ic.GetHeight) then return 0 end
    local ok1, cw = pcall(c.GetWidth, c)
    local ok2, iw = pcall(ic.GetWidth, ic)
    local ok3, ih = pcall(ic.GetHeight, ic)
    if not (ok1 and ok2 and ok3 and type(cw) == "number" and type(iw) == "number" and type(ih) == "number") then return 0 end
    if cw <= 0 or iw <= 0 or iw > cw or math.abs(iw - ih) > 1 then return 0 end -- icono girando: no medir
    local r = (cw - iw) / (2 * cw)
    if r > 0.2 then return 0 end
    if not (HUD.swap and HUD.swap.t0) then insetCache[c] = r end
    return r
end
HUD.IconInset = IconInset

function HUD.FlattenAll()
    for n = 3, 8 do
        local b = SlotObj(n)
        local c = b and b.slot or _G["ActionButton" .. n]
        Flatten(c, b)
        if NWUI.sv.hud.moveActionBar and not IsInGamepadPreferredMode() and c then
            local size = (n == 8) and NWUI.sv.hud.ultSize or NWUI.sv.hud.abilitySize
            FrameFor(c, IconInset(c, b) * size)
        end
    end
    local q = QuickslotCtrl()
    Flatten(q)
    if NWUI.sv.hud.moveActionBar and not IsInGamepadPreferredMode() then FrameFor(q) end
end

-- =====================================================================
-- Icono del tipo de arma (texturas del propio juego, no se añade ninguna)
-- =====================================================================
local TH = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_"
local INVT = "EsoUI/Art/Inventory/inventory_tabIcon_"
local WEAPON_ICON = {}
local function MapIcon(constName, path)
    local v = rawget(_G, constName)
    if type(v) == "number" then WEAPON_ICON[v] = path end
end
MapIcon("WEAPONTYPE_AXE",               TH .. "1h_Axe_Down.dds")
MapIcon("WEAPONTYPE_HAMMER",            TH .. "1h_Mace_Down.dds")
MapIcon("WEAPONTYPE_SWORD",             TH .. "1h_Sword_Down.dds")
MapIcon("WEAPONTYPE_DAGGER",            TH .. "1h_Dagger_Down.dds")
MapIcon("WEAPONTYPE_TWO_HANDED_AXE",    TH .. "2h_Axe_Down.dds")
MapIcon("WEAPONTYPE_TWO_HANDED_HAMMER", TH .. "2h_Mace_Down.dds")
MapIcon("WEAPONTYPE_TWO_HANDED_SWORD",  TH .. "2h_Sword_Down.dds")
MapIcon("WEAPONTYPE_BOW",               INVT .. "bow_down.dds")
MapIcon("WEAPONTYPE_FIRE_STAFF",        INVT .. "damageStaff_down.dds")
MapIcon("WEAPONTYPE_FROST_STAFF",       INVT .. "damageStaff_down.dds")
MapIcon("WEAPONTYPE_LIGHTNING_STAFF",   INVT .. "damageStaff_down.dds")
MapIcon("WEAPONTYPE_HEALING_STAFF",     INVT .. "damageStaff_down.dds")
MapIcon("WEAPONTYPE_SHIELD",            INVT .. "shield_down.dds")
HUD.WEAPON_ICON = WEAPON_ICON

local function Const(name) local v = rawget(_G, name); return type(v) == "number" and v or nil end

local function PairSlots(pair)
    if pair == Const("ACTIVE_WEAPON_PAIR_BACKUP") then
        return Const("EQUIP_SLOT_BACKUP_MAIN"), Const("EQUIP_SLOT_BACKUP_OFF")
    end
    return Const("EQUIP_SLOT_MAIN_HAND"), Const("EQUIP_SLOT_OFF_HAND")
end

local function WeaponTypeAt(slot)
    if not (slot and GetItemWeaponType) then return nil end
    local ok, t = pcall(GetItemWeaponType, BAG_WORN, slot)
    if ok and type(t) == "number" and t ~= Const("WEAPONTYPE_NONE") and t ~= 0 then return t end
end

-- Devuelve icono principal y (si hay dos armas de una mano) el icono que se
-- dibuja en espejo encima para formar la X.
local function ComputeIcons(mt, ot)
    if ot and ot == Const("WEAPONTYPE_SHIELD") then return WEAPON_ICON[ot] end
    if mt and ot and WEAPON_ICON[mt] and WEAPON_ICON[ot] then return WEAPON_ICON[mt], WEAPON_ICON[ot] end
    local t = mt or ot
    return t and WEAPON_ICON[t] or nil
end

local function HasWorn(slot)
    if not (slot and HasItemInSlot) then return nil end
    local ok, v = pcall(HasItemInSlot, BAG_WORN, slot)
    if ok then return v and true or false end
    return nil
end

-- Mientras el juego cambia de armas puede informar "sin arma" un instante;
-- se guarda el último icono bueno de cada par y solo se quita si de verdad
-- no hay nada equipado en esas manos.
local iconCache = {}
HUD.iconCache = iconCache
function HUD.WeaponIcons(pair)
    local mainSlot, offSlot = PairSlots(pair)
    local a, b = ComputeIcons(WeaponTypeAt(mainSlot), WeaponTypeAt(offSlot))
    if a then
        iconCache[pair] = { a, b }
        return a, b
    end
    local hm, ho = HasWorn(mainSlot), HasWorn(offSlot)
    if hm == false and ho == false then
        iconCache[pair] = nil
        return nil
    end
    local c = iconCache[pair]
    if c then return c[1], c[2] end
    return nil
end

local function ActivePair()
    if GetActiveWeaponPairInfo then
        local ok, p = pcall(GetActiveWeaponPairInfo)
        if ok and type(p) == "number" then return p end
    end
    return Const("ACTIVE_WEAPON_PAIR_MAIN") or 1
end

local function OtherPair(p)
    local main, back = Const("ACTIVE_WEAPON_PAIR_MAIN") or 1, Const("ACTIVE_WEAPON_PAIR_BACKUP") or 2
    return p == back and main or back
end

-- Categoría de la barra inactiva (la del otro par de armas)
local function InactiveCategory()
    local prim, back = Const("HOTBAR_CATEGORY_PRIMARY") or 0, Const("HOTBAR_CATEGORY_BACKUP") or 1
    local act = GetActiveHotbarCategory and GetActiveHotbarCategory()
    if act == prim then return back end
    if act == back then return prim end
    -- hombre lobo / sobrecarga: se muestra la barra del par de armas actual
    return ActivePair() == (Const("ACTIVE_WEAPON_PAIR_BACKUP") or 2) and back or prim
end

local function WeaponBox(parent, name)
    local c = WM:CreateControl(name, parent, CT_CONTROL)
    c.bg = NWUI.Tex(c, {0.03, 0.03, 0.03, 0.82}, 0)
    c.bg:SetAnchorFill(c)
    c.edges = select(2, NWUI.EdgeBox(c, {0, 0, 0, 0}, ICON_BORDER, NWUI.LinePx(1)))
    c.icon = NWUI.Tex(c, {0.92, 0.90, 0.86, 1}, 3)
    c.icon2 = NWUI.Tex(c, {0.92, 0.90, 0.86, 1}, 4)
    c.icon2:SetTextureCoords(1, 0, 0, 1) -- espejo horizontal
    return c
end

local function SetWeaponBox(c, pair)
    if not c then return end
    local a, b = HUD.WeaponIcons(pair)
    local w = c:GetWidth()
    local pad = math.floor(w * 0.10 + 0.5)
    for _, t in ipairs({ c.icon, c.icon2 }) do
        t:ClearAnchors()
        t:SetAnchor(TOPLEFT, c, TOPLEFT, pad, pad)
        t:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -pad, -pad)
    end
    if not a then
        -- sin dato ahora mismo: se conserva lo que ya se mostraba, salvo que
        -- de verdad no haya armas equipadas en ese par
        local m, o = PairSlots(pair)
        if c.lastIcon and not (HasWorn(m) == false and HasWorn(o) == false) then
            a, b = c.lastIcon, c.lastIcon2
        end
    end
    c.lastIcon, c.lastIcon2 = a, b
    -- estado propio: IsHidden() del juego también dice "oculto" cuando la
    -- ventana padre lo está (al abrir el inventario), y no sirve para decidir
    c.hasIcon = a ~= nil
    c.icon:SetHidden(not a)
    if a then c.icon:SetTexture(a) end
    c.icon2:SetHidden(not b)
    if b then c.icon2:SetTexture(b) end
end

-- Solo el icono del arma activa (rápido y aislado: si otra parte falla, este
-- se sigue actualizando)
function HUD.RefreshWeaponBox()
    local wb = HUD.weaponBox
    if not wb then return end
    local s = NWUI.sv.hud
    SetWeaponBox(wb, ActivePair())
    local ours = s.moveActionBar and not IsInGamepadPreferredMode()
    wb:SetHidden(not (ours and s.weaponIcon ~= false and wb.hasIcon))
    if not (HUD.swap and HUD.swap.t0) then wb:SetScale(1); wb:SetAlpha(1) end
end

-- =====================================================================
-- Barra inactiva (arriba, más chica) — solo dibujo, no se puede pulsar
-- =====================================================================
local BACK_SCALE = 0.62
local BACK_GAP   = 6     -- separación vertical entre barra inactiva y activa

local function CreateBackSlot(parent, i)
    local c = WM:CreateControl("NWUI_BackSlot" .. i, parent, CT_CONTROL)
    c.bg = NWUI.Tex(c, {0.03, 0.03, 0.03, 0.82}, 0)
    c.bg:SetAnchorFill(c)
    c.icon = NWUI.Tex(c, nil, 2)
    c.edges = select(2, NWUI.EdgeBox(c, {0, 0, 0, 0}, ICON_BORDER, NWUI.LinePx(1)))
    return c
end

local function NewSweep(parent)
    if not CT_COOLDOWN then return nil end
    local ok, cd = pcall(WM.CreateControl, WM, NWUI.UID("NWUI_Sweep"), parent, CT_COOLDOWN)
    if not ok or not cd then return nil end
    if cd.SetFillColor then cd:SetFillColor(0, 0, 0, 0.78) end
    cd:SetDrawLevel(9)
    cd:SetHidden(true)
    return cd
end

local UpdateBackBarRaw
function HUD.UpdateBackBar()
    local ok, err = pcall(UpdateBackBarRaw)
    HUD.lastBackT = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if not ok then
        HUD.lastBackErr = tostring(err)
        pcall(HUD.RefreshWeaponBox)
    end
end

UpdateBackBarRaw = function()
    local r = HUD.backRow
    if not r then return end
    local s = NWUI.sv.hud
    local cat = InactiveCategory()
    local any = false
    for i, c in ipairs(r.slots) do
        local n = i + 2
        local tex = GetSlotTexture and GetSlotTexture(n, cat)
        if type(tex) == "string" and tex ~= "" then
            c.icon:SetTexture(tex)
            c.icon:SetHidden(false)
            any = true
        else
            c.icon:SetHidden(true)
        end
    end
    SetWeaponBox(r.weapon, OtherPair(ActivePair()))
    if not any and r.weapon.hasIcon then any = true end
    local ours = s.moveActionBar and not IsInGamepadPreferredMode()
    r:SetHidden(not (ours and s.backBar ~= false and any))
    if not (HUD.swap and HUD.swap.t0) then r:SetScale(1); r:SetAlpha(1) end
    HUD.RefreshWeaponBox()
end

function HUD.LayoutBackBar()
    local s = NWUI.sv.hud
    local r, h = HUD.backRow, HUD.abilities
    if not (r and h) then return end
    local sz, usz, gap = s.abilitySize, s.ultSize, s.abilityGap
    local bsz = math.floor(sz * BACK_SCALE + 0.5)
    local busz = math.floor(usz * BACK_SCALE + 0.5)
    local bgap = math.max(2, math.floor(gap * BACK_SCALE + 0.5))
    local W = bsz * 6 + bgap * 6 + bgap + busz
    r:SetDimensions(W, math.max(bsz, busz))
    r.baseX = HUD.rowCenterX or 0
    r:ClearAnchors()
    r:SetAnchor(BOTTOM, h, TOP, r.baseX, -BACK_GAP)
    -- caja del arma inactiva, luego 5 habilidades y la definitiva
    r.weapon:SetDimensions(bsz, bsz)
    r.weapon:ClearAnchors()
    r.weapon:SetAnchor(BOTTOMLEFT, r, BOTTOMLEFT, 0, 0)
    local prev = r.weapon
    for i, c in ipairs(r.slots) do
        local d = (i == 6) and busz or bsz
        c:SetDimensions(d, d)
        c:ClearAnchors()
        c:SetAnchor(BOTTOMLEFT, prev, BOTTOMRIGHT, (i == 6) and bgap * 2 or bgap, 0)
        c.icon:ClearAnchors()
        c.icon:SetAnchor(TOPLEFT, c, TOPLEFT, 1, 1)
        c.icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -1, -1)
        prev = c
    end
    -- icono del arma activa, a la izquierda de la primera habilidad
    local wb, first = HUD.weaponBox, SlotCtrl(3)
    if wb then
        local t = s.iconBorder or 2
        local inPx = (first and IconInset(first, SlotObj(3)) or 0) * sz
        local isz = math.floor(sz - 2 * inPx + 0.5)
        wb:SetDimensions(isz, isz)
        -- anclado a NUESTRO contenedor (no al botón del juego, que el juego
        -- recoloca al abrir y cerrar ventanas)
        HUD.wbX, HUD.wbY = inPx - (gap + 2 * t), -KEY_ROOM - inPx
        HUD.AnchorWeaponBox()
        -- mismo marco que las habilidades (por fuera, mismo grosor), hijo del
        -- propio cuadro para que nunca quede un marco suelto
        local e = wb.edges or {}
        if #e == 4 then
            for _, edge in ipairs(e) do edge:ClearAnchors(); edge:SetHidden(t <= 0) end
            e[1]:SetAnchor(BOTTOMLEFT, wb, TOPLEFT, -t, 0);     e[1]:SetAnchor(BOTTOMRIGHT, wb, TOPRIGHT, t, 0);   e[1]:SetHeight(t)
            e[2]:SetAnchor(TOPLEFT, wb, BOTTOMLEFT, -t, 0);     e[2]:SetAnchor(TOPRIGHT, wb, BOTTOMRIGHT, t, 0);   e[2]:SetHeight(t)
            e[3]:SetAnchor(TOPRIGHT, wb, TOPLEFT, 0, 0);        e[3]:SetAnchor(BOTTOMRIGHT, wb, BOTTOMLEFT, 0, 0); e[3]:SetWidth(t)
            e[4]:SetAnchor(TOPLEFT, wb, TOPRIGHT, 0, 0);        e[4]:SetAnchor(BOTTOMLEFT, wb, BOTTOMRIGHT, 0, 0); e[4]:SetWidth(t)
        end
    end
    HUD.UpdateBackBar()
end

function HUD.AnchorWeaponBox()
    local wb, h = HUD.weaponBox, HUD.abilities
    if not (wb and h) then return end
    local dy = (HUD.swap and HUD.swap.dy) or 0
    wb:ClearAnchors()
    wb:SetAnchor(BOTTOMRIGHT, h, BOTTOMLEFT, HUD.wbX or 0, (HUD.wbY or -KEY_ROOM) + dy)
end

-- /nwui arma: estado del icono del arma (para encontrar por qué no se ve)
function HUD.DiagWeapon()
    local out, wb = {}, HUD.weaponBox
    local function add(k, v) out[#out + 1] = k .. "=" .. tostring(v) end
    if not wb then return { "sin icono de arma" } end
    add("par", ActivePair())
    local a, b = HUD.WeaponIcons(ActivePair())
    add("icono", a and a:match("([^/]+)%.dds$")); add("cruzado", b ~= nil)
    local function own(c) if c.IsControlHidden then return c:IsControlHidden() end return c:IsHidden() end
    add("oculto", own(wb)); add("conIcono", wb.hasIcon)
    add("alfa", wb:GetAlpha()); add("escala", wb.GetScale and wb:GetScale())
    add("x", wb.GetLeft and math.floor(wb:GetLeft())); add("y", wb.GetTop and math.floor(wb:GetTop()))
    add("tam", wb:GetWidth()); add("hudOculto", HUD.tlw and HUD.tlw:IsHidden())
    add("animando", HUD.swap and HUD.swap.t0 ~= nil)
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    add("tick", HUD.lastTickT and (now - HUD.lastTickT) or "nunca")
    add("refresco", HUD.lastBackT and (now - HUD.lastBackT) or "nunca")
    local m, o = PairSlots(ActivePair())
    add("tipos", tostring((WeaponTypeAt(m))) .. "/" .. tostring((WeaponTypeAt(o))))
    add("equipado", tostring((HasWorn(m))) .. "/" .. tostring((HasWorn(o))))
    local lines = { table.concat(out, "  ") }
    if HUD.lastBackErr then lines[#lines + 1] = "error: " .. HUD.lastBackErr end
    local ok, err = pcall(HUD.RefreshWeaponBox)
    lines[#lines + 1] = "refrescado: " .. (ok and ("oculto=" .. tostring((own(wb)))) or tostring(err))
    return lines
end

-- La flecha del juego que indicaba la barra activa se oculta (la sustituye el
-- icono del arma). Se usa alfa 0 porque el juego la vuelve a mostrar sola.
local function HideSwapArrow()
    local ws = rawget(_G, "ZO_ActionBar1WeaponSwap")
    if ws and type(ws) ~= "function" and ws.SetAlpha then ws:SetAlpha(0) end
    local wsl = rawget(_G, "ZO_ActionBar1WeaponSwapLock")
    if wsl and type(wsl) ~= "function" and wsl.SetAlpha then wsl:SetAlpha(0) end
end
HUD.HideSwapArrow = HideSwapArrow

-- =====================================================================
-- Animación al cambiar de barra/arma
--   - la barra que queda inactiva sube y se encoge hasta su sitio
--   - la nueva barra activa baja un poco y aparece
--   - el icono del arma hace un pequeño "pop"
--   - (versión con barrido) todas las casillas se oscurecen y se van
--     iluminando con un barrido circular en el sentido del reloj
-- =====================================================================
local SWAP_MS = 220
local swap = { t0 = nil, dy = 0 }
HUD.swap = swap

local function EaseOut(x) x = 1 - x; return 1 - x * x * x end

local function ApplyActiveOffset()
    local s = NWUI.sv.hud
    if not s.moveActionBar or IsInGamepadPreferredMode() then return end
    local first, h = SlotCtrl(3), HUD.abilities
    if first and h then
        first:ClearAnchors()
        first:SetAnchor(BOTTOMLEFT, h, BOTTOMLEFT, 0, -KEY_ROOM + (swap.dy or 0))
    end
    HUD.AnchorWeaponBox()
end

local function SetActiveAlpha(a)
    for n = 3, 8 do
        local c = SlotCtrl(n)
        if c and c.SetAlpha then c:SetAlpha(a) end
    end
end

local function SwapStep()
    local r = HUD.backRow
    if not (swap.t0 and r) then return end
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    local p = math.min(1, math.max(0, (now - swap.t0) / SWAP_MS))
    local e = EaseOut(p)
    -- barra inactiva: parte de la posición/tamaño de la activa
    local k = swap.fromScale + (1 - swap.fromScale) * e
    r:SetScale(k)
    r:ClearAnchors()
    r:SetAnchor(BOTTOM, HUD.abilities, TOP, r.baseX or 0, -BACK_GAP + swap.fromDY * (1 - e))
    r:SetAlpha(0.55 + 0.45 * e)
    -- barra activa: baja desde un poco más arriba y aparece
    swap.dy = -swap.rise * (1 - e)
    ApplyActiveOffset()
    SetActiveAlpha(0.35 + 0.65 * e)
    -- icono del arma
    local wb = HUD.weaponBox
    if wb then
        wb:SetScale(1 + 0.30 * (1 - e))
        wb:SetAlpha(0.2 + 0.8 * e)
    end
    if p >= 1 then
        swap.t0, swap.dy = nil, 0
        r:SetScale(1); r:SetAlpha(1)
        ApplyActiveOffset()
        SetActiveAlpha(1)
        if wb then wb:SetScale(1); wb:SetAlpha(1) end
        EVENT_MANAGER:UnregisterForUpdate("NWUI_HUD_Swap")
    end
end

function HUD.SweepEnabled()
    return NWUI.BUILD_SWEEP == true and NWUI.sv.hud.swapSweep ~= false
end

local function StartSweeps()
    if not HUD.SweepEnabled() then return end
    local ms = NWUI.sv.hud.swapSweepMs or 1000
    local list = {}
    for n = 3, 8 do
        local c = SlotCtrl(n)
        if c then
            -- el barrido va dentro del propio botón para quedar encima del icono
            local cd = HUD.activeSweeps[c]
            if not cd then
                cd = NewSweep(c)
                if cd then
                    cd:SetDrawLevel(20)
                    local icon = c.GetNamedChild and c:GetNamedChild("Icon")
                    local target = (icon and icon ~= c and type(icon) ~= "function") and icon or c
                    cd:SetAnchorFill(target)
                end
                HUD.activeSweeps[c] = cd
            end
            if cd then list[#list + 1] = cd end
        end
    end
    for _, c in ipairs(HUD.backRow.slots) do
        if c.sweep then list[#list + 1] = c.sweep end
    end
    for _, cd in ipairs(list) do
        cd:SetHidden(false)
        pcall(cd.StartCooldown, cd, ms, ms, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
    end
    zo_callLater(function()
        for _, cd in ipairs(list) do cd:SetHidden(true) end
    end, ms + 30)
end

function HUD.PlaySwap()
    local s = NWUI.sv.hud
    local r = HUD.backRow
    if not (r and HUD.abilities) then return end
    HUD.UpdateBackBar()
    if s.swapAnim ~= false and s.moveActionBar and not IsInGamepadPreferredMode() then
        local sz = s.abilitySize
        local bsz = math.floor(sz * BACK_SCALE + 0.5)
        swap.fromScale = sz / math.max(1, bsz)
        swap.fromDY = BACK_GAP + KEY_ROOM + sz - bsz -- desde la fila activa
        swap.rise = math.floor(sz * 0.35 + 0.5)
        swap.t0 = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        EVENT_MANAGER:RegisterForUpdate("NWUI_HUD_Swap", 0, SwapStep)
        SwapStep()
    end
    StartSweeps()
end

-- =====================================================================
-- Habilidades (solo tamaño y posición)
-- =====================================================================
function HUD.LayoutAbilities()
    local s = NWUI.sv.hud
    local h = HUD.abilities
    if not h then return end
    local sz, usz, gap = s.abilitySize, s.ultSize, s.abilityGap
    h:SetDimensions(5 * sz + 6 * gap + usz, math.max(sz, usz) + KEY_ROOM)
    HUD.LayoutBackBar()
    if not s.moveActionBar or IsInGamepadPreferredMode() then return end

    -- La separación es el hueco VISIBLE entre los marcos (que van pegados al
    -- icono): se descuenta el margen interno del botón y el grosor del marco.
    local t = s.iconBorder or 2
    local prev, prevIn, firstIn
    local x = 0 -- borde derecho del último botón, medido desde la izquierda del contenedor
    for n = 3, 7 do
        local c = SlotCtrl(n)
        if c then
            c:SetScale(sz / BTN_BASE)
            c:ClearAnchors()
            local inPx = IconInset(c, SlotObj(n)) * sz
            if prev then
                local off = gap + 2 * t - prevIn - inPx
                c:SetAnchor(BOTTOMLEFT, prev, BOTTOMRIGHT, off, 0)
                x = x + off + sz
            else
                c:SetAnchor(BOTTOMLEFT, h, BOTTOMLEFT, 0, -KEY_ROOM + (swap.dy or 0))
                x, firstIn = sz, inPx
            end
            prev, prevIn = c, inPx
        end
    end
    local ult = SlotCtrl(8)
    local lastIn = prevIn or 0
    if ult and prev then
        ult:SetScale(usz / BTN_BASE)
        ult:ClearAnchors()
        local inPx = IconInset(ult, SlotObj(8)) * usz
        local off = gap * 2 + 2 * t - prevIn - inPx
        ult:SetAnchor(BOTTOMLEFT, prev, BOTTOMRIGHT, off, 0)
        x, lastIn = x + off + usz, inPx
    end
    -- ancho real de la fila y su centro visual (de marco a marco)
    if x > 0 then
        h:SetWidth(x)
        local vl, vr = (firstIn or 0) - t, x - lastIn + t
        HUD.rowCenterX = (vl + vr) / 2 - x / 2
    end
    HideSwapArrow()
    if ZO_ActionBar1KeybindBG then ZO_ActionBar1KeybindBG:SetHidden(true) end
    HUD.FlattenAll()
    HUD.LayoutBackBar()
end

-- =====================================================================
-- Consumibles: 4 recuadros, el activo arriba al centro y la tecla debajo
-- =====================================================================
function NWUI.SelectQuickslot(i)
    NWUI.Call("SetCurrentQuickslot", QSlot(i))
end

local function CreateQS(parent, i)
    local c = WM:CreateControl("NWUI_QS" .. i, parent, CT_CONTROL)
    c.border, c.bg = NWUI.FlatBox(c, C.slotEmpty, ICON_BORDER, 2)
    c.icon = NWUI.Tex(c, nil, 3)
    c.icon:SetAnchor(TOPLEFT, c, TOPLEFT, 3, 3)
    c.icon:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, -3)
    c.count = NWUI.Label(c, F.count, C.text, "")
    c.count:SetAnchor(BOTTOMRIGHT, c, BOTTOMRIGHT, -3, 0)
    c.index = i
    c:SetMouseEnabled(true)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then NWUI.SelectQuickslot(self.index) end
    end)
    c:SetHandler("OnMouseEnter", function(self)
        local slot = QSlot(self.index)
        local link = GetSlotItemLink and GetSlotItemLink(slot, QS_CAT)
        if link and link ~= "" then
            InitializeTooltip(ItemTooltip, self, BOTTOM, 0, -6, TOP)
            pcall(ItemTooltip.SetLink, ItemTooltip, link)
        else
            local ok, name = pcall(GetSlotName, slot, QS_CAT)
            if ok and name and name ~= "" then
                InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
                SetTooltipText(InformationTooltip, zo_strformat("<<1>>", name))
            end
        end
    end)
    c:SetHandler("OnMouseExit", function()
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
    end)
    return c
end

function HUD.UpdateConsumables()
    if not HUD.qsSlots then return end
    local current = GetCurrentQuickslot and GetCurrentQuickslot()
    for i, c in ipairs(HUD.qsSlots) do
        local slot = QSlot(i)
        local ok, tex = pcall(GetSlotTexture, slot, QS_CAT)
        if ok and tex and tex ~= "" then
            c.icon:SetTexture(tex)
            c.icon:SetHidden(false)
            local okc, count = pcall(GetSlotItemCount, slot, QS_CAT)
            if not okc then count = nil end
            if count and count > 0 then
                c.count:SetText(tostring(count))
            elseif count == 0 then
                c.count:SetText("0")
            else
                c.count:SetText("")
            end
            c.icon:SetDesaturation(count == 0 and 1 or 0)
        else
            c.icon:SetHidden(true)
            c.count:SetText("")
        end
        NWUI.SetColor(c.border, (current == slot) and C.gold or ICON_BORDER)
    end
    -- Respaldo del recuadro del objeto activo (si no se encontró el botón nativo)
    if HUD.qsCurrent and not HUD.qsCurrent:IsHidden() then
        local ok, tex = pcall(GetSlotTexture, current or 0, QS_CAT)
        if ok and tex and tex ~= "" then
            HUD.qsCurrent.icon:SetTexture(tex)
            HUD.qsCurrent.icon:SetHidden(false)
            local okc, count = pcall(GetSlotItemCount, current, QS_CAT)
            HUD.qsCurrent.count:SetText((okc and count) and tostring(count) or "")
        else
            HUD.qsCurrent.icon:SetHidden(true)
            HUD.qsCurrent.count:SetText("")
        end
    end
end

-- Texto de la tecla del objeto rápido, tomado del botón nativo (y se oculta ahí)
-- Oculta SIEMPRE las letras de tecla (Q, Y, etc.) dibujadas sobre los botones
-- de arriba (objeto activo y compañero). Se busca en todo el botón y se vuelve
-- a aplicar periódicamente, porque el juego las redibuja.
local keyCache = {}

local function IsKeyText(t)
    return type(t) == "string" and t ~= "" and not t:find("^%s*[%d,%.]+%s*$") and #t <= 14
end

local keyLabels = {}   -- etiquetas ya identificadas como "letra de tecla"

local function HideKeyLabels(btn)
    if not (btn and btn.GetNumChildren) then return end
    local function walk(c, depth)
        if depth > 4 then return end
        local okn, n = pcall(c.GetNumChildren, c)
        for i = 1, (okn and n or 0) do
            local okc, ch = pcall(c.GetChild, c, i)
            if okc and ch then
                if ch.GetText and ch.SetText then
                    local okt, t = pcall(ch.GetText, ch)
                    if okt and IsKeyText(t) then
                        keyCache[btn] = t
                        keyLabels[ch] = true
                        pcall(ch.SetText, ch, "")
                    end
                    if keyLabels[ch] then pcall(ch.SetAlpha, ch, 0) end
                end
                walk(ch, depth + 1)
            end
        end
    end
    pcall(walk, btn, 0)
end
HUD.HideKeyLabels = HideKeyLabels

local function QuickslotKeyText(q)
    if q then HideKeyLabels(q) end
    return (q and keyCache[q]) or "Q"
end
-- Tecla asignada a los objetos rápidos (para mostrarla en el inventario)
function HUD.QuickslotKey()
    local q = _G.QuickslotButton
    local ok, t = pcall(QuickslotKeyText, q)
    return (ok and type(t) == "string" and t ~= "") and t or "Q"
end

-- Botón de la definitiva del compañero (solo existe con un compañero invocado)
local function CompanionCtrl()
    if not (HOTBAR_CATEGORY_COMPANION and ZO_ActionBar_GetButton) then
        return _G.CompanionUltimateButton
    end
    local ok, b = pcall(ZO_ActionBar_GetButton, (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1, HOTBAR_CATEGORY_COMPANION)
    if ok and b and b.slot and b.slot ~= SlotCtrl(8) then return b.slot end
    return _G.CompanionUltimateButton
end

local function CompanionActive()
    if HasActiveCompanion then
        local ok, v = pcall(HasActiveCompanion)
        if ok then return v end
    end
    return false
end

function HUD.LayoutConsumables()
    local s = NWUI.sv.hud
    local h = HUD.consumables
    if not h then return end
    local n = s.consumablesEnabled and s.consumableCount or 0
    local sz, gap, cur = s.consumableSize, 6, s.quickslotSize
    local rowW = math.max(1, n * (sz + gap) - gap)
    local W = math.max(rowW, cur)
    h:SetDimensions(W, cur + 6 + sz + 4 + KEY_ROOM)

    local row = HUD.qsRow
    row:ClearAnchors()
    row:SetDimensions(rowW, sz)
    row:SetAnchor(BOTTOM, h, BOTTOM, 0, -KEY_ROOM)
    for i = 1, QS_MAX do
        local c = HUD.qsSlots[i]
        if i <= n then
            c:SetHidden(false)
            c:SetDimensions(sz, sz)
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, row, TOPLEFT, (i - 1) * (sz + gap), 0)
        else
            c:SetHidden(true)
        end
    end

    local q = QuickslotCtrl()
    local useNative = q and s.moveActionBar and not IsInGamepadPreferredMode()
    local comp = CompanionCtrl()
    local withComp = useNative and comp and CompanionActive()
    if useNative then
        q:SetScale(cur / BTN_BASE)
        q:ClearAnchors()
        if withComp then
            -- objeto activo a la izquierda y compañero a la derecha, centrados
            q:SetAnchor(BOTTOMRIGHT, row, TOP, -5, -6)
            comp:SetScale(cur / BTN_BASE)
            comp:ClearAnchors()
            comp:SetAnchor(BOTTOMLEFT, row, TOP, 5, -6)
            Flatten(comp)
        else
            q:SetAnchor(BOTTOM, row, TOP, 0, -6)
        end
        Flatten(q)
        FrameFor(q)
        HUD.qsCurrent:SetHidden(true)
    else
        HUD.qsCurrent:SetHidden(false)
        HUD.qsCurrent:SetDimensions(cur, cur)
        HUD.qsCurrent:ClearAnchors()
        HUD.qsCurrent:SetAnchor(BOTTOM, row, TOP, 0, -6)
    end
    if comp then
        HideKeyLabels(comp)
        local f = withComp and FrameFor(comp) or nil
        if not withComp and HUD.compFrame then HUD.compFrame:SetHidden(true) end
        HUD.compFrame = f or HUD.compFrame
    end
    HUD.qsKey.label:SetText(QuickslotKeyText(useNative and q or nil))
    HUD.qsKey:SetWidth(math.max(20, HUD.qsKey.label:GetTextWidth() + 10))
    HUD.qsKey:ClearAnchors()
    HUD.qsKey:SetAnchor(TOP, row, BOTTOM, 0, 4)
    HUD.UpdateConsumables()
end

-- =====================================================================
-- Disposición general
-- =====================================================================
function HUD.LayoutBars()
    local s = NWUI.sv.hud
    local g = HUD.barsGroup
    local w, hh, rh, gap = s.barWidth, s.healthHeight, s.resourceHeight, 3
    g:SetDimensions(w, rh * 2 + hh + gap * 2)
    local mag, sta, hp = bars[P_MAGICKA], bars[P_STAMINA], bars[P_HEALTH]
    mag:ClearAnchors()
    mag:SetAnchor(TOPLEFT, g, TOPLEFT, 0, 0)
    mag:SetAnchor(TOPRIGHT, g, TOPRIGHT, 0, 0)
    mag:SetHeight(rh)
    sta:ClearAnchors()
    sta:SetAnchor(TOPLEFT, mag, BOTTOMLEFT, 0, gap)
    sta:SetAnchor(TOPRIGHT, mag, BOTTOMRIGHT, 0, gap)
    sta:SetHeight(rh)
    hp:ClearAnchors()
    hp:SetAnchor(TOPLEFT, sta, BOTTOMLEFT, 0, gap)
    hp:SetAnchor(TOPRIGHT, sta, BOTTOMRIGHT, 0, gap)
    hp:SetHeight(hh)

    hp.label:SetFont((hh >= 26 and "$(BOLD_FONT)|17|soft-shadow-thick") or (hh >= 18 and F.barBig) or F.barSmall)
    local small = (rh >= 15 and "$(BOLD_FONT)|13|soft-shadow-thick")
        or (rh >= 11 and F.barSmall) or "$(BOLD_FONT)|9|soft-shadow-thin"
    mag.label:SetFont(small)
    sta.label:SetFont(small)

    -- separación entre barras: fondo oscuro detrás + borde fino en cada barra
    local border = (s.barBorder == "gold") and C.headerLine or {0.32, 0.32, 0.34, 1}
    for _, b in pairs(bars) do NWUI.SetColor(b.border, border) end
    g.back:ClearAnchors()
    g.back:SetAnchor(TOPLEFT, g, TOPLEFT, -2, -2)
    g.back:SetAnchor(BOTTOMRIGHT, g, BOTTOMRIGHT, 2, 2)

    NWUI.SetColor(hp.fill, FILL.health)
    NWUI.SetColor(mag.fill, FILL.magicka)
    NWUI.SetColor(sta.fill, s.staminaColor == "eso" and FILL.stamina_eso or FILL.stamina_nw)
    for _, b in pairs(bars) do RenderBar(b) end
end

function HUD.LayoutAll()
    if not HUD.tlw then return end
    HUD.LayoutBars()
    HUD.LayoutAbilities()
    HUD.LayoutConsumables()
    HUD.UpdateLevel()
    for _, m in ipairs(NWUI.movables) do
        if m.isHUD then NWUI.ApplyPosition(m) end
    end
    RefreshPowers()
end

function HUD.SetUnlocked(state)
    if not HUD.tlw then return end
    HUD.tlw:SetDrawTier(state and DT_HIGH or HUD.baseTier)
    if HUD.qsSlots then
        for _, c in ipairs(HUD.qsSlots) do c:SetMouseEnabled(not state) end
    end
end

local function HideDefaultBars()
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        for _, scene in ipairs({ HUD_SCENE, HUD_UI_SCENE }) do
            if scene then pcall(scene.RemoveFragment, scene, PLAYER_ATTRIBUTE_BARS_FRAGMENT) end
        end
    end
    if ZO_PlayerAttribute then ZO_PlayerAttribute:SetHidden(true) end
end

local function Resize(key, delta, min, max, step)
    local s = NWUI.sv.hud
    s[key] = zo_clamp((s[key] or min) + delta * (step or 2), min, max)
end

-- =====================================================================
-- Inicio
-- =====================================================================
function HUD.Init()
    local s = NWUI.sv.hud
    if not s.enabled then return end

    local tlw = WM:CreateTopLevelWindow("NWUI_HUD")
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetMouseEnabled(false)
    HUD.tlw = tlw
    HUD.baseTier = tlw:GetDrawTier()

    -- Barras apiladas
    local g = WM:CreateControl("NWUI_HUD_Bars", tlw, CT_CONTROL)
    HUD.barsGroup = g
    g.back = NWUI.Tex(g, {0, 0, 0, 0.72}, 0)
    bars[P_MAGICKA] = CreateBar(g, "magicka")
    bars[P_STAMINA] = CreateBar(g, "stamina")
    bars[P_HEALTH]  = CreateBar(g, "health")

    -- Nivel (plano, número grande)
    local lv = WM:CreateControl("NWUI_HUD_Level", g, CT_CONTROL)
    lv:SetAnchor(TOP, g, BOTTOM, 0, 7)
    -- fondo negro translúcido en degradado (forma del hexágono) y marco dorado encima
    lv.bg = NWUI.Tex(lv, nil, 0)
    lv.bg:SetTexture(LEVEL_BG)
    lv.bg:SetTextureCoords(0, IMG_W / TEX_W, 0, IMG_H / TEX_H)
    lv.bg:SetAnchorFill(lv)
    NWUI.Gradient(lv.bg, {0, 0, 0, 0.66}, {0, 0, 0, 0.40})
    lv.frame = NWUI.Tex(lv, nil, 1)
    lv.frame:SetTexture(LEVEL_FRAME)
    lv.frame:SetTextureCoords(0, IMG_W / TEX_W, 0, IMG_H / TEX_H)
    lv.frame:SetAnchorFill(lv)
    lv.icon = NWUI.Tex(lv, nil, 3)
    lv.icon:SetTexture(CHAMPION_ICON)
    lv.label = NWUI.Label(lv, F.level, {0.93, 0.82, 0.58, 1}, "")
    HUD.level = lv

    -- Habilidades
    HUD.abilities = WM:CreateControl("NWUI_HUD_Abilities", tlw, CT_CONTROL)
    -- barra inactiva (arriba) e icono del arma activa (a la izquierda)
    local back = WM:CreateControl("NWUI_HUD_BackBar", tlw, CT_CONTROL)
    back.weapon = WeaponBox(back, "NWUI_HUD_BackWeapon")
    back.slots = {}
    for i = 1, 6 do
        local c = CreateBackSlot(back, i)
        c.sweep = NewSweep(c)
        if c.sweep then c.sweep:SetAnchorFill(c) end
        back.slots[i] = c
    end
    HUD.backRow = back
    HUD.weaponBox = WeaponBox(tlw, "NWUI_HUD_Weapon")
    HUD.activeSweeps = {}

    -- Consumibles
    local cons = WM:CreateControl("NWUI_HUD_Consumables", tlw, CT_CONTROL)
    HUD.consumables = cons
    HUD.qsRow = WM:CreateControl("NWUI_HUD_QSRow", cons, CT_CONTROL)
    HUD.qsSlots = {}
    for i = 1, QS_MAX do HUD.qsSlots[i] = CreateQS(HUD.qsRow, i) end
    local key = WM:CreateControl("NWUI_HUD_QSKey", cons, CT_CONTROL)
    key:SetHeight(18)
    NWUI.FlatBox(key, {0.03, 0.03, 0.03, 0.92}, {0.38, 0.38, 0.38, 1}, 1)
    key.label = NWUI.Label(key, F.key, C.text, "Q")
    key.label:SetAnchor(CENTER, key, CENTER, 0, 0)
    HUD.qsKey = key
    local curBox = WM:CreateControl("NWUI_HUD_QSCurrent", cons, CT_CONTROL)
    NWUI.FlatBox(curBox, C.slotEmpty, ICON_BORDER, 2)
    curBox.icon = NWUI.Tex(curBox, nil, 3)
    curBox.icon:SetAnchor(TOPLEFT, curBox, TOPLEFT, 3, 3)
    curBox.icon:SetAnchor(BOTTOMRIGHT, curBox, BOTTOMRIGHT, -3, -3)
    curBox.count = NWUI.Label(curBox, F.count, C.text, "")
    curBox.count:SetAnchor(BOTTOMRIGHT, curBox, BOTTOMRIGHT, -3, 0)
    curBox:SetHidden(true)
    HUD.qsCurrent = curBox

    HUD.LayoutBars()
    HUD.LayoutAbilities()
    HUD.LayoutConsumables()

    local m1 = NWUI.RegisterMovable(g, "hud_bars", function(c)
        c:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -70)
    end, NWUI.T("mv_bars"), false, function(delta, shift)
        if shift then Resize("healthHeight", delta, 12, 48, 1) else Resize("barWidth", delta, 200, 800, 10) end
        HUD.LayoutAll()
    end)
    local m2 = NWUI.RegisterMovable(HUD.abilities, "hud_abilities", function(c)
        c:SetAnchor(BOTTOMLEFT, HUD.barsGroup, BOTTOMRIGHT, 62, KEY_ROOM)
    end, NWUI.T("h_abil"), false, function(delta)
        Resize("abilitySize", delta, 30, 96, 2)
        NWUI.sv.hud.ultSize = NWUI.sv.hud.abilitySize + 6
        HUD.LayoutAll()
    end)
    local m3 = NWUI.RegisterMovable(cons, "hud_consumables", function(c)
        c:SetAnchor(BOTTOMRIGHT, HUD.barsGroup, BOTTOMLEFT, -30, KEY_ROOM)
    end, NWUI.T("h_cons"), false, function(delta, shift)
        if shift then Resize("quickslotSize", delta, 30, 90, 2) else Resize("consumableSize", delta, 26, 80, 2) end
        HUD.LayoutAll()
    end)
    m1.isHUD, m2.isHUD, m3.isHUD = true, true, true

    tlw:SetHandler("OnUpdate", OnUpdate)

    -- vuelve a ocultar las letras Q / Y si el juego las redibuja
    EVENT_MANAGER:RegisterForUpdate("NWUI_HUD_KeyHide", 1000, function()
        HUD.lastTickT = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if not NWUI.sv.hud.moveActionBar or IsInGamepadPreferredMode() then return end
        if not (HUD.swap and HUD.swap.t0) then
            pcall(HUD.RefreshWeaponBox)
            HUD.UpdateBackBar()
        end
        pcall(HideSwapArrow)
        HideKeyLabels(QuickslotCtrl())
        local c = CompanionCtrl and CompanionCtrl()
        if c then HideKeyLabels(c) end
    end)

    -- capa de dibujo por encima de las ventanas del juego del HUD, para que la
    -- barra del juego no tape el icono del arma al volver de un menú
    if DL_CONTROLS and tlw.SetDrawLayer then tlw:SetDrawLayer(DL_CONTROLS) end
    HUD.fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD.fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWN or newState == SCENE_FRAGMENT_SHOWING then
            HUD.LayoutBackBar()
            zo_callLater(function() HUD.LayoutBackBar() end, 250)
        end
    end)
    if HUD_SCENE then HUD_SCENE:AddFragment(HUD.fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(HUD.fragment) end

    if s.hideDefaultBars then HideDefaultBars() end

    -- Eventos
    NWUI.On("NWUI_Power", "EVENT_POWER_UPDATE", function(_, unitTag, _, powerType, value, max, effMax)
        local b = bars[powerType]
        if b then
            SetBarValue(b, value, effMax or max)
            if powerType == P_HEALTH then UpdateShield() end
        end
    end, REGISTER_FILTER_UNIT_TAG, "player")
    for _, ev in ipairs({ "EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED", "EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED", "EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED" }) do
        NWUI.On("NWUI_Shield_" .. ev, ev, UpdateShield, REGISTER_FILTER_UNIT_TAG, "player")
    end
    NWUI.On("NWUI_Level", "EVENT_LEVEL_UPDATE", HUD.UpdateLevel, REGISTER_FILTER_UNIT_TAG, "player")
    NWUI.On("NWUI_CPGain", "EVENT_CHAMPION_POINT_GAINED", HUD.UpdateLevel)
    NWUI.On("NWUI_CPUpd", "EVENT_CHAMPION_POINT_UPDATE", HUD.UpdateLevel)

    local function Relayout() NWUI.Throttle("NWUI_HUD_Relayout", 60, HUD.LayoutAll) end
    NWUI.On("NWUI_HUD_Act", "EVENT_PLAYER_ACTIVATED", function()
        HUD.LayoutAll()
        zo_callLater(Relayout, 800)
    end)
    NWUI.On("NWUI_HUD_Pad", "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED", Relayout)
    NWUI.On("NWUI_HUD_AllBars", "EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED", function()
        Relayout()
        HUD.UpdateConsumables()
    end)
    for _, ev in ipairs({ "EVENT_ACTIVE_COMPANION_STATE_CHANGED", "EVENT_COMPANION_ACTIVATED", "EVENT_COMPANION_DEACTIVATED" }) do
        NWUI.On("NWUI_HUD_" .. ev, ev, function() NWUI.Throttle("NWUI_HUD_Comp", 200, HUD.LayoutAll) end)
    end
    NWUI.On("NWUI_HUD_Pair", "EVENT_ACTIVE_WEAPON_PAIR_CHANGED", function()
        NWUI.Throttle("NWUI_HUD_Flat", 50, HUD.FlattenAll)
        if HUD.ready then HUD.PlaySwap() else HUD.UpdateBackBar() end
        zo_callLater(HUD.UpdateBackBar, 120)
    end)
    local function Back() NWUI.Throttle("NWUI_HUD_Back", 80, HUD.UpdateBackBar) end
    NWUI.On("NWUI_HUD_ActiveBar", "EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED", Back)
    NWUI.On("NWUI_HUD_SlotUpd", "EVENT_ACTION_SLOT_UPDATED", Back)
    NWUI.On("NWUI_HUD_HotbarUpd", "EVENT_HOTBAR_SLOT_UPDATED", Back)
    NWUI.On("NWUI_HUD_Worn", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", Back, REGISTER_FILTER_BAG_ID, BAG_WORN)
    NWUI.On("NWUI_HUD_Ready", "EVENT_PLAYER_ACTIVATED", function()
        HUD.ready = false
        zo_callLater(function() HUD.ready = true; HUD.UpdateBackBar() end, 1500)
    end)

    local function QS() NWUI.Throttle("NWUI_HUD_QS", 100, HUD.UpdateConsumables) end
    NWUI.On("NWUI_QS_Active", "EVENT_ACTIVE_QUICKSLOT_CHANGED", QS)
    NWUI.On("NWUI_QS_Slot", "EVENT_ACTION_SLOT_UPDATED", QS)
    NWUI.On("NWUI_QS_Inv", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", QS, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)

    -- Si el juego vuelve a colocar o redibujar los botones, los recolocamos y aplanamos
    if ActionButton and SecurePostHook then
        if ActionButton.ApplyAnchor then SecurePostHook(ActionButton, "ApplyAnchor", Relayout) end
        if ActionButton.HandleSlotChanged then
            SecurePostHook(ActionButton, "HandleSlotChanged", function(self)
                if self and self.slot then Flatten(self.slot, self) end
            end)
        end
        if ActionButton.ApplyStyle then SecurePostHook(ActionButton, "ApplyStyle", Relayout) end
    end
end
