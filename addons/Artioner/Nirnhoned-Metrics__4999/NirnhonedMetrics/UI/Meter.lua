-- Ventana del medidor: cabecera con botones, barras de colores, menú de combates,
-- mover arrastrando la cabecera y redimensionar con la esquina.
-- Los controles de ESO no se pueden destruir, así que las filas se reutilizan.

local NM = NirnhonedMetrics
local U = NM.Utils
local L = NM.L
local F = NM.Fight
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local M = {
    rows = {},       -- controles de fila creados
    viewIndex = 1,   -- combate que se ve (1 = el más reciente)
    scroll = 0,      -- primera fila visible - 1
}
NM.Meter = M

local BUTTON_SIZE = 22
local MIN_W = 200
local MAX_W, MAX_H = 900, 900
local DRAG_UPDATE = "NirnhonedMetrics_Drag"
local RESIZE_UPDATE = "NirnhonedMetrics_Resize"
local CLICK_TOLERANCE = 3
local SHOW_AFTER_COMBAT_MS = 10000   -- con "ocultar fuera de combate", tiempo que sigue visible

local SELF_TEXT = { 1, 0.9, 0.55, 1 }
local OTHER_TEXT = { 1, 1, 1, 1 }
local PET_TEXT = { 0.75, 0.85, 1, 1 }
local REST_TEXT = { 0.8, 0.8, 0.8, 1 }
local REST_COLOR = { 0.45, 0.45, 0.48, 1 }
local WHITE = { 1, 1, 1, 1 }
local HEAL_COLOR = { 0.35, 0.80, 0.40, 1 }   -- barras de habilidades de sanación

local function Font(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thick", zo_round(size))
end

-- La cabecera y las filas crecen si el texto no cabe en el alto configurado.
local function HeaderHeight()
    return math.max(24, NM.sv.titleFontSize + 10)
end

local function RowHeight()
    return math.max(NM.sv.rowHeight, NM.sv.fontSize + 6)
end

local function FooterHeight()
    return math.max(24, NM.sv.fontSize + 8)
end

local function MinHeight()
    return HeaderHeight() + FooterHeight() + 30
end

-- El juego no vuelve a dibujar el texto de una etiqueta al cambiarle la fuente si
-- el texto no cambia: se vacía para que el siguiente SetText lo dibuje con la nueva.
local function SetLabelFont(label, font)
    local text = label:GetText()
    label:SetFont(font)
    label:SetText("")
    label:SetText(text)
end

local function Solid(name, parent, r, g, b, a)
    local bd = WM:CreateControl(name, parent, CT_BACKDROP)
    bd:SetCenterColor(r, g, b, a)
    bd:SetEdgeColor(0, 0, 0, 0)
    return bd
end

local function Label(name, parent, align)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return label
end

local function Tooltip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

-- Botón con texturas normal/encima/pulsado. "tooltip" puede ser una función.
local function IconButton(name, parent, textures, tooltip, onClick)
    local b = WM:CreateControl(name, parent, CT_BUTTON)
    b:SetDimensions(BUTTON_SIZE, BUTTON_SIZE)
    b:SetNormalTexture(textures.up)
    b:SetMouseOverTexture(textures.over)
    b:SetPressedTexture(textures.down)
    b:SetHandler("OnClicked", function()
        HideTooltip()
        onClick()
    end)
    b:SetHandler("OnMouseEnter", function()
        Tooltip(b, type(tooltip) == "function" and tooltip() or tooltip)
    end)
    b:SetHandler("OnMouseExit", HideTooltip)
    return b
end

local TEX_CLOSE = {
    up = "EsoUI/Art/Buttons/closebutton_up.dds",
    over = "EsoUI/Art/Buttons/closebutton_mouseover.dds",
    down = "EsoUI/Art/Buttons/closebutton_down.dds",
}
local TEX_SETTINGS = {
    up = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_up.dds",
    over = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_over.dds",
    down = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_down.dds",
}
local TEX_RESET = {
    up = "EsoUI/Art/Inventory/inventory_tabIcon_trash_up.dds",
    over = "EsoUI/Art/Inventory/inventory_tabIcon_trash_over.dds",
    down = "EsoUI/Art/Inventory/inventory_tabIcon_trash_down.dds",
}
local TEX_LOCKED = {
    up = "EsoUI/art/miscellaneous/locked_up.dds",
    over = "EsoUI/art/miscellaneous/locked_over.dds",
    down = "EsoUI/art/miscellaneous/locked_down.dds",
}
local TEX_UNLOCKED = {
    up = "EsoUI/art/miscellaneous/unlocked_up.dds",
    over = "EsoUI/art/miscellaneous/unlocked_over.dds",
    down = "EsoUI/art/miscellaneous/unlocked_down.dds",
}
local TEX_DAMAGE = {
    up = "EsoUI/Art/LFG/LFG_dps_up.dds",
    over = "EsoUI/Art/LFG/LFG_dps_over.dds",
    down = "EsoUI/Art/LFG/LFG_dps_down.dds",
}
local TEX_HEALING = {
    up = "EsoUI/Art/LFG/LFG_healer_up.dds",
    over = "EsoUI/Art/LFG/LFG_healer_over.dds",
    down = "EsoUI/Art/LFG/LFG_healer_down.dds",
}
local TEX_GROUP = {
    up = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds",
    over = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds",
    down = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds",
}
local TEX_ABILITIES = {
    up = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    over = "EsoUI/Art/MainMenu/menuBar_skills_over.dds",
    down = "EsoUI/Art/MainMenu/menuBar_skills_down.dds",
}
local TEX_FIGHTS = {
    up = "EsoUI/Art/Guild/tabIcon_history_up.dds",
    over = "EsoUI/Art/Guild/tabIcon_history_over.dds",
    down = "EsoUI/Art/Guild/tabIcon_history_down.dds",
}
local TEX_CLOCK = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds"

---------------------------------------------------------------------------
-- Datos de las filas
---------------------------------------------------------------------------
local function PlayerName()
    if NM.sv.nameFormat == "account" then return UndecorateDisplayName(GetDisplayName()) end
    return U.FormatName(GetUnitName("player"))
end

local function MemberName(member)
    if NM.sv.nameFormat == "account" and member.account and member.account ~= "" then
        return UndecorateDisplayName(member.account)
    end
    return member.name
end

local function ClassColor(classId)
    local sv = NM.sv
    if sv.colorMode == "class" and classId and sv.classColors[classId] then
        return sv.classColors[classId]
    end
    return sv.barColor
end

-- Los iconos de clase son siluetas blancas: se tiñen con el color de la clase
-- (aunque las barras usen un solo color), aclarado para que resalte sobre el fondo.
local ICON_LIGHTEN = 0.25
local function ClassIconColor(classId)
    local c = classId and NM.sv.classColors[classId]
    if not c then return nil end
    local r, g, b = U.Color(c)
    return {
        r + (1 - r) * ICON_LIGHTEN,
        g + (1 - g) * ICON_LIGHTEN,
        b + (1 - b) * ICON_LIGHTEN,
        1,
    }
end

-- Filas del modo grupo: tú (exacto) + los miembros que comparten datos.
-- metric = "damage" | "healing". Cada fila tiene amount (total) y rate (por segundo).
local function GroupRows(fight, metric)
    local rows = {}
    local healing = metric == "healing"
    local mine = fight[metric]
    if mine.total > 0 then
        local classId = GetUnitClassId("player")
        rows[1] = {
            name = PlayerName(),
            account = GetDisplayName(),
            classId = classId,
            icon = U.ClassIcon(classId),
            iconColor = ClassIconColor(classId),
            color = ClassColor(classId),
            amount = mine.total,
            rate = mine.total / F.ActiveTime(fight, metric),
            overheal = mine.overheal,
            isSelf = true,
        }
    end
    for _, member in pairs(fight.group) do
        local amount = healing and member.healing or member.damage
        if amount and amount > 0 then
            rows[#rows + 1] = {
                name = MemberName(member),
                account = member.account,
                classId = member.classId,
                icon = U.ClassIcon(member.classId),
                iconColor = ClassIconColor(member.classId),
                color = ClassColor(member.classId),
                amount = amount,
                rate = healing and member.hps or member.dps,
                overhealPerSecond = healing and member.overhealPerSecond or nil,
                approx = true,
            }
        end
    end
    -- La estimación del resto del grupo solo existe para el daño (vida de los jefes).
    local rest = not healing and NM.Group.RestOfGroup(fight)
    if rest then
        rows[#rows + 1] = {
            name = L.REST_OF_GROUP,
            color = REST_COLOR,
            amount = rest,
            rate = rest / F.Duration(fight),
            isRest = true,
        }
    end
    return rows
end

-- Filas del modo habilidades: tus habilidades (y las de tus mascotas).
local function AbilityRows(fight, metric)
    local rows = {}
    local time = F.ActiveTime(fight, metric)
    local byType = NM.sv.abilityColorMode == "damageType"
    for _, ability in pairs(fight[metric].abilities) do
        -- Una curación que fue toda sobrecuración no aporta nada a la lista.
        if ability.amount > 0 then
            local color = NM.sv.barColor
            if byType then
                color = metric == "healing" and HEAL_COLOR or U.DamageTypeColor(ability.damageType)
            end
            rows[#rows + 1] = {
                name = ability.name,
                icon = ability.icon,
                color = color,
                amount = ability.amount,
                rate = ability.amount / time,
                overheal = metric == "healing" and ability.overheal or nil,
                ability = ability,
                isPet = ability.pet,
            }
        end
    end
    return rows
end

function M.BuildRows(fight)
    if not fight then return {} end
    local metric = NM.sv.metric
    local rows = NM.sv.mode == "abilities" and AbilityRows(fight, metric) or GroupRows(fight, metric)
    table.sort(rows, function(a, b) return a.amount > b.amount end)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.amount end
    for _, r in ipairs(rows) do r.percent = total > 0 and r.amount / total or 0 end
    return rows, total
end

local function ValuesText(r)
    local sv = NM.sv
    local extra = {}
    if sv.showDps then extra[#extra + 1] = U.FormatNumber(r.rate) end
    if sv.showPercent then extra[#extra + 1] = U.FormatPercent(r.percent) end
    local text = table.concat(extra, ", ")
    if sv.showTotal then
        local total = U.FormatNumber(r.amount)
        return text ~= "" and string.format("%s (%s)", total, text) or total
    end
    return text
end

local function Number(n)
    return ZO_CommaDelimitNumber(zo_round(n))
end

local function RowTooltip(r)
    local healing = NM.sv.metric == "healing"
    local lines = { "|cFFFFFF" .. r.name .. "|r" }
    if r.account and r.account ~= "" and NM.sv.nameFormat ~= "account" then
        lines[#lines + 1] = r.account
    end
    if r.classId then lines[#lines + 1] = U.ClassName(r.classId) end
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("%s: %s", healing and L.METRIC_HEALING or L.TOTAL, Number(r.amount))
    lines[#lines + 1] = string.format("%s: %s", healing and L.HPS or L.DPS, Number(r.rate))
    lines[#lines + 1] = string.format("%s: %s", L.SHARE, U.FormatPercent(r.percent))
    if r.overheal and r.overheal > 0 then
        local share = r.overheal / (r.amount + r.overheal)
        lines[#lines + 1] = string.format("%s: %s (%s)", L.OVERHEAL, Number(r.overheal), U.FormatPercent(share))
    elseif r.overhealPerSecond and r.overhealPerSecond > 0 then
        lines[#lines + 1] = string.format("%s: %s", L.OVERHEAL_PS, Number(r.overhealPerSecond))
    end
    local a = r.ability
    if a then
        lines[#lines + 1] = string.format("%s: %d", healing and L.HEALS or L.HITS, a.hits)
        lines[#lines + 1] = string.format("%s: %s", L.CRIT_RATE, U.FormatPercent(a.hits > 0 and a.crits / a.hits or 0))
        lines[#lines + 1] = string.format("%s: %s", healing and L.AVG_HEAL or L.AVG_HIT, Number(a.amount / math.max(1, a.hits)))
        lines[#lines + 1] = string.format("%s: %s", healing and L.MAX_HEAL or L.MAX_HIT, Number(a.max))
        if a.pet then lines[#lines + 1] = healing and L.PET_HEALING or L.PET_DAMAGE end
    end
    if r.approx or r.isRest then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|c999999" .. (r.isRest and L.REST_NOTE or L.APPROX_NOTE) .. "|r"
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Filas (controles)
---------------------------------------------------------------------------
local function CreateRow(i)
    local key = "NirnhonedMetricsRow" .. i
    local row = WM:CreateControl(key, M.content, CT_CONTROL)
    row:SetMouseEnabled(true)

    -- Capas de la barra, de abajo arriba: borde, carril (la parte vacía, del color de la
    -- barra pero apagado), relleno, sombra inferior, brillo superior y borde de avance.
    row.bg = Solid(key .. "Bg", row, 0, 0, 0, 0.85)
    row.bg:SetAnchorFill(row)

    row.track = Solid(key .. "Track", row, 0, 0, 0, 0)
    row.track:SetDrawLevel(1)

    row.bar = Solid(key .. "Bar", row, 1, 1, 1, 1)
    row.bar:SetDrawLevel(2)

    row.shade = Solid(key .. "Shade", row.bar, 0, 0, 0, 0.28)
    row.shade:SetAnchor(BOTTOMLEFT, row.bar, BOTTOMLEFT, 0, 0)
    row.shade:SetAnchor(BOTTOMRIGHT, row.bar, BOTTOMRIGHT, 0, 0)
    row.shade:SetDrawLevel(3)

    row.gloss = Solid(key .. "Gloss", row.bar, 1, 1, 1, 0.22)
    row.gloss:SetAnchor(TOPLEFT, row.bar, TOPLEFT, 0, 0)
    row.gloss:SetAnchor(TOPRIGHT, row.bar, TOPRIGHT, 0, 0)
    row.gloss:SetDrawLevel(3)

    row.edge = Solid(key .. "Edge", row.bar, 1, 1, 1, 0.75)
    row.edge:SetAnchor(TOPRIGHT, row.bar, TOPRIGHT, 0, 0)
    row.edge:SetAnchor(BOTTOMRIGHT, row.bar, BOTTOMRIGHT, 0, 0)
    row.edge:SetWidth(2)
    row.edge:SetDrawLevel(4)

    row.icon = WM:CreateControl(key .. "Icon", row, CT_TEXTURE)
    row.icon:SetDrawLevel(4)

    row.left = Label(key .. "Left", row, TEXT_ALIGN_LEFT)
    row.right = Label(key .. "Right", row, TEXT_ALIGN_RIGHT)
    row.left:SetDrawLevel(5)
    row.right:SetDrawLevel(5)
    row.right:SetAnchor(RIGHT, row, RIGHT, -4, 0)

    row:SetHandler("OnMouseEnter", function()
        if not row.data then return end
        InitializeTooltip(InformationTooltip, row, LEFT, 6, 0, RIGHT)
        SetTooltipText(InformationTooltip, RowTooltip(row.data))
    end)
    row:SetHandler("OnMouseExit", HideTooltip)
    M.MakeDraggable(row)
    return row
end

local function GetRow(i)
    local row = M.rows[i]
    if not row then
        row = CreateRow(i)
        M.rows[i] = row
    end
    return row
end

-- Estilo "progress": borde, carril, brillo y sombra. Estilo "flat": solo el relleno.
local function LayoutBar(row, c, barLeft, fillWidth, barMax, h)
    local sv = NM.sv
    local r, g, b = U.Color(c)
    local progress = sv.barStyle ~= "flat"
    local inset = progress and 1 or 0
    local innerH = h - inset * 2

    row.bg:SetCenterColor(0, 0, 0, progress and 0.85 or 0.35)
    row.track:SetHidden(not progress)
    row.shade:SetHidden(not progress)
    row.gloss:SetHidden(not progress)

    row.track:ClearAnchors()
    row.track:SetAnchor(TOPLEFT, row, TOPLEFT, barLeft + inset, inset)
    row.track:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -inset, -inset)
    row.track:SetCenterColor(r * 0.3, g * 0.3, b * 0.3, 0.6 * sv.barAlpha)

    local width = math.max(1, (barMax - inset * 2) * fillWidth)
    row.bar:ClearAnchors()
    row.bar:SetAnchor(TOPLEFT, row, TOPLEFT, barLeft + inset, inset)
    row.bar:SetDimensions(width, innerH)
    row.bar:SetCenterColor(r, g, b, sv.barAlpha)

    row.gloss:SetHeight(math.floor(innerH * 0.45))
    row.shade:SetHeight(math.floor(innerH * 0.3))
    -- El borde de avance solo tiene sentido si la barra no está llena ni vacía.
    row.edge:SetHidden(not progress or width < 4 or fillWidth >= 0.999)
end

local function LayoutRow(row, r, rank, maxAmount, width)
    local sv = NM.sv
    local h = RowHeight()
    row:SetDimensions(width, h)
    row.data = r

    local barLeft = 0
    if sv.showIcon and r.icon and r.icon ~= "" then
        local inset = sv.barStyle ~= "flat" and 1 or 0
        row.icon:SetTexture(r.icon)
        row.icon:SetColor(U.Color(r.iconColor, WHITE))
        row.icon:ClearAnchors()
        row.icon:SetAnchor(TOPLEFT, row, TOPLEFT, inset, inset)
        row.icon:SetDimensions(h - inset * 2, h - inset * 2)
        row.icon:SetHidden(false)
        barLeft = h
    else
        row.icon:SetHidden(true)
    end

    local fraction = maxAmount > 0 and r.amount / maxAmount or 0
    LayoutBar(row, r.color, barLeft, fraction, width - barLeft, h)

    -- Cambiar la fuente obliga a recolocar el texto: solo cuando cambia el tamaño.
    if row.fontSize ~= sv.fontSize then
        row.fontSize = sv.fontSize
        SetLabelFont(row.left, Font(sv.fontSize))
        SetLabelFont(row.right, Font(sv.fontSize))
    end
    local textColor = OTHER_TEXT
    if r.isSelf and sv.highlightSelf then
        textColor = SELF_TEXT
    elseif r.isPet then
        textColor = PET_TEXT
    elseif r.isRest then
        textColor = REST_TEXT
    end
    row.left:SetColor(U.Color(textColor))
    row.right:SetColor(U.Color(textColor))
    row.left:ClearAnchors()
    row.left:SetAnchor(LEFT, row, LEFT, barLeft + 4, 0)
    row.left:SetAnchor(RIGHT, row.right, LEFT, -6, 0)
    -- El resto del grupo no es un jugador: no lleva posición.
    local showRank = sv.showRank and not r.isRest
    row.left:SetText(showRank and string.format("%d. %s", rank, r.name) or r.name)
    row.right:SetText(ValuesText(r))
    row:SetHidden(false)
end

---------------------------------------------------------------------------
-- Refresco
---------------------------------------------------------------------------
-- Nombre del combate que se ve: actual, último o el del jefe/objetivo.
local function FightName(fight)
    if not fight or fight == F.active then return L.FIGHT_CURRENT end
    if M.viewIndex == 1 then return L.FIGHT_LAST end
    return F.Label(fight) or string.format(L.FIGHT_N, M.viewIndex)
end

local function TitleText(fight)
    local prefix = NM.sv.metric == "healing" and L.TITLE_HEALING or L.TITLE_DAMAGE
    if NM.sv.mode == "abilities" then prefix = prefix .. " · " .. L.TITLE_ABILITIES end
    return string.format("%s: %s", prefix, FightName(fight))
end

function M.Refresh()
    if not M.frame or M.frame:IsHidden() then return end
    local sv = NM.sv
    local fight = F.Get(M.viewIndex)
    if not fight then
        M.viewIndex = 1
        fight = F.Get(1)
    end

    M.footerTime:SetText(U.FormatDuration(fight and F.Duration(fight) or 0))
    M.footerFight:SetText(fight and FightName(fight) or "")

    local rows = M.BuildRows(fight)
    local width = M.frame:GetWidth() - 4
    local height = M.frame:GetHeight() - HeaderHeight() - FooterHeight() - 4
    local step = RowHeight() + sv.rowSpacing
    local visible = math.max(1, math.floor((height + sv.rowSpacing) / step))
    M.scroll = zo_clamp(M.scroll, 0, math.max(0, #rows - visible))

    local maxAmount = rows[1] and rows[1].amount or 0
    local shown = 0
    for i = 1, visible do
        local r = rows[i + M.scroll]
        if not r then break end
        local row = GetRow(i)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, M.content, TOPLEFT, 0, (i - 1) * step)
        LayoutRow(row, r, i + M.scroll, maxAmount, width)
        shown = i
    end
    for i = shown + 1, #M.rows do
        M.rows[i]:SetHidden(true)
        M.rows[i].data = nil
    end

    M.empty:SetHidden(#rows > 0)
    if #rows == 0 then
        if M.empty.fontSize ~= sv.fontSize then
            M.empty.fontSize = sv.fontSize
            SetLabelFont(M.empty, Font(sv.fontSize - 1))
        end
        M.empty:SetText(L.EMPTY)
    end
end

function M.Scroll(delta)
    M.scroll = M.scroll - delta
    M.Refresh()
end

---------------------------------------------------------------------------
-- Visibilidad, bloqueo y posición
---------------------------------------------------------------------------
-- Cyrodiil, Ciudad Imperial o campo de batalla.
local function InPvP()
    return (IsPlayerInAvAWorld and IsPlayerInAvAWorld())
        or (IsActiveWorldBattleground and IsActiveWorldBattleground())
end

function M.UpdateVisibility()
    if not M.frame then return end
    local sv = NM.sv
    local hidden = not sv.window.shown or (sv.hideInPvP and InPvP())
    if not hidden and sv.hideOutOfCombat and not F.active and not IsUnitInCombat("player") then
        local since = F.lastEnd and (GetGameTimeMilliseconds() - F.lastEnd) or math.huge
        if since >= SHOW_AFTER_COMBAT_MS then
            hidden = true
        else
            zo_callLater(M.UpdateVisibility, SHOW_AFTER_COMBAT_MS - since + 50)
        end
    end
    M.frame:SetHidden(hidden)
    if not hidden then M.Refresh() end
end

function M.Toggle()
    NM.sv.window.shown = not NM.sv.window.shown
    M.UpdateVisibility()
end

function M.SetShown(shown)
    NM.sv.window.shown = shown
    M.UpdateVisibility()
end

function M.SetLocked(locked)
    NM.sv.window.locked = locked
    if not M.frame then return end
    for _, handle in ipairs(M.resizeHandles) do handle:SetHidden(locked) end
    local tex = locked and TEX_LOCKED or TEX_UNLOCKED
    M.lockBtn:SetNormalTexture(tex.up)
    M.lockBtn:SetMouseOverTexture(tex.over)
    M.lockBtn:SetPressedTexture(tex.down)

    -- Bloqueada no se ven ajustes ni cerrar: el candado pasa a ser el último icono.
    M.settingsBtn:SetHidden(locked)
    M.closeBtn:SetHidden(locked)
    M.lockBtn:ClearAnchors()
    if locked then
        M.lockBtn:SetAnchor(RIGHT, M.header, RIGHT, -4, 0)
    else
        M.lockBtn:SetAnchor(RIGHT, M.settingsBtn, LEFT, 0, 0)
    end
end

function M.ApplyPosition()
    local w = NM.sv.window
    M.frame:ClearAnchors()
    if w.x and w.y then
        M.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, w.x, w.y)
    else
        M.frame:SetAnchor(LEFT, GuiRoot, LEFT, 40, -80)
    end
    M.frame:SetDimensions(zo_clamp(w.width, MIN_W, MAX_W), zo_clamp(w.height, MinHeight(), MAX_H))
end

function M.ResetPosition()
    local w = NM.sv.window
    w.x, w.y = nil, nil
    w.width, w.height = NM.defaults.window.width, NM.defaults.window.height
    M.ApplyPosition()
    M.Refresh()
end

local function SavePosition()
    local w = NM.sv.window
    w.x, w.y = zo_round(M.frame:GetLeft()), zo_round(M.frame:GetTop())
    w.width, w.height = zo_round(M.frame:GetWidth()), zo_round(M.frame:GetHeight())
    M.ApplyPosition()
end

-- Arrastrar desde cualquier parte de la ventana (cabecera, barras o fondo) la mueve
-- si no está bloqueada. Un clic izquierdo sin arrastrar llama a onClick; el clic
-- derecho abre el menú.
local function StartDrag()
    local mx, my = GetUIMousePosition()
    local left, top = M.frame:GetLeft(), M.frame:GetTop()
    M.drag = { moved = false }
    if NM.sv.window.locked then return end
    EM:RegisterForUpdate(DRAG_UPDATE, 0, function()
        local drag = M.drag
        if not drag then
            EM:UnregisterForUpdate(DRAG_UPDATE)
            return
        end
        local x, y = GetUIMousePosition()
        if not drag.moved and math.abs(x - mx) + math.abs(y - my) > CLICK_TOLERANCE then
            drag.moved = true
            HideTooltip()
        end
        if drag.moved then
            M.frame:ClearAnchors()
            M.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left + x - mx, top + y - my)
        end
    end)
end

-- Devuelve true si fue un clic (se soltó sin arrastrar).
local function StopDrag()
    EM:UnregisterForUpdate(DRAG_UPDATE)
    local drag = M.drag
    M.drag = nil
    if not drag then return false end
    if drag.moved then
        SavePosition()
        return false
    end
    return true
end

function M.MakeDraggable(control, onClick)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StartDrag() end
    end)
    control:SetHandler("OnMouseUp", function(_, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if upInside then M.ShowMenu(control) end
            return
        end
        if button == MOUSE_BUTTON_INDEX_LEFT and StopDrag() and upInside and onClick then
            onClick()
        end
    end)
    control:SetHandler("OnMouseWheel", function(_, delta) M.Scroll(delta) end)
end

-- Asa para redimensionar: la esquina cambia ancho y alto; los bordes, solo uno.
-- Van en un nivel de dibujo superior para que las barras (que también reciben el
-- ratón para arrastrar la ventana) no les quiten el clic.
-- paint(handle, hovered) dibuja el asa en reposo o con el ratón encima.
local function ResizeHandle(name, resizeW, resizeH, cursor, paint)
    local handle = Solid(name, M.frame, 1, 1, 1, 0)
    handle:SetDrawTier(DT_HIGH)
    handle:SetMouseEnabled(true)
    handle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        HideTooltip()
        local mx, my = GetUIMousePosition()
        local left, top = M.frame:GetLeft(), M.frame:GetTop()
        local w, h = M.frame:GetDimensions()
        -- Se fija la esquina superior izquierda para que solo crezca hacia abajo/derecha.
        M.frame:ClearAnchors()
        M.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
        EM:RegisterForUpdate(RESIZE_UPDATE, 0, function()
            local x, y = GetUIMousePosition()
            local newW = resizeW and zo_clamp(w + x - mx, MIN_W, MAX_W) or w
            local newH = resizeH and zo_clamp(h + y - my, MinHeight(), MAX_H) or h
            M.frame:SetDimensions(newW, newH)
            M.Refresh()
        end)
    end)
    handle:SetHandler("OnMouseUp", function()
        EM:UnregisterForUpdate(RESIZE_UPDATE)
        SavePosition()
        M.Refresh()
    end)
    handle:SetHandler("OnMouseEnter", function()
        paint(handle, true)
        if cursor then WM:SetMouseCursor(cursor) end
    end)
    handle:SetHandler("OnMouseExit", function()
        paint(handle, false)
        if MOUSE_CURSOR_DO_NOT_CARE then WM:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE) end
    end)
    return handle
end

-- Los bordes son invisibles y se iluminan con el ratón encima.
local function PaintEdge(handle, hovered)
    handle:SetCenterColor(1, 1, 1, hovered and 0.35 or 0)
end

-- La esquina es un triángulo hecho con franjas de 2 px, cada una más ancha que la
-- anterior y alineadas a la derecha.
local GRIP_STEP = 2
local function PaintCorner(handle, hovered)
    for _, strip in ipairs(handle.strips) do
        strip:SetCenterColor(1, 1, 1, hovered and 0.9 or 0.45)
    end
end

local function BuildTriangle(handle, size)
    handle.strips = {}
    for i = 1, size / GRIP_STEP do
        local strip = Solid(handle:GetName() .. "Strip" .. i, handle, 1, 1, 1, 0.45)
        strip:SetDrawTier(DT_HIGH)
        strip:SetDimensions(i * GRIP_STEP, GRIP_STEP)
        strip:SetAnchor(BOTTOMRIGHT, handle, BOTTOMRIGHT, 0, -(size - i * GRIP_STEP))
        handle.strips[i] = strip
    end
end

local RESIZE_EDGE = 5     -- grosor de los bordes que redimensionan
local RESIZE_CORNER = 14

local function BuildResizeHandles(frame)
    local corner = ResizeHandle("NirnhonedMetricsGrip", true, true, MOUSE_CURSOR_RESIZE_NWSE, PaintCorner)
    corner:SetDimensions(RESIZE_CORNER, RESIZE_CORNER)
    corner:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    BuildTriangle(corner, RESIZE_CORNER)

    local right = ResizeHandle("NirnhonedMetricsGripRight", true, false, MOUSE_CURSOR_RESIZE_EW, PaintEdge)
    right:SetWidth(RESIZE_EDGE)
    right:SetAnchor(TOPRIGHT, M.header, BOTTOMRIGHT, 0, 0)
    right:SetAnchor(BOTTOMRIGHT, corner, TOPRIGHT, 0, 0)

    local bottom = ResizeHandle("NirnhonedMetricsGripBottom", false, true, MOUSE_CURSOR_RESIZE_NS, PaintEdge)
    bottom:SetHeight(RESIZE_EDGE)
    bottom:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    bottom:SetAnchor(BOTTOMRIGHT, corner, BOTTOMLEFT, 0, 0)

    M.resizeHandles = { corner, right, bottom }
end

---------------------------------------------------------------------------
-- Menú (clic en el título o clic derecho)
---------------------------------------------------------------------------
local function Check(on, text)
    return (on and "|c" .. NM.COLOR .. "•|r " or "   ") .. text
end

-- El icono de la vista activa se ve encendido y el otro apagado.
local function SetActive(button, textures, active)
    button:SetNormalTexture(active and textures.down or textures.up)
    button:SetAlpha(active and 1 or 0.6)
end

local function UpdateModeButtons()
    if not M.groupBtn then return end
    local healing = NM.sv.metric == "healing"
    SetActive(M.damageBtn, TEX_DAMAGE, not healing)
    SetActive(M.healingBtn, TEX_HEALING, healing)
    local isGroup = NM.sv.mode ~= "abilities"
    SetActive(M.groupBtn, TEX_GROUP, isGroup)
    SetActive(M.abilitiesBtn, TEX_ABILITIES, not isGroup)
end
M.UpdateModeButtons = UpdateModeButtons

-- Vista: "group" (miembros del grupo) | "abilities" (tus habilidades).
function M.SetMode(mode)
    NM.sv.mode = mode
    M.scroll = 0
    UpdateModeButtons()
    M.Refresh()
end

-- Qué se mide: "damage" | "healing".
function M.SetMetric(metric)
    NM.sv.metric = metric
    M.scroll = 0
    UpdateModeButtons()
    M.Refresh()
end

function M.ShowView(index)
    M.viewIndex = index
    M.scroll = 0
    M.Refresh()
end

local function FightMenuLabel(fight, index)
    local name
    if fight == F.active then
        name = L.FIGHT_CURRENT
    else
        name = F.Label(fight) or string.format(L.FIGHT_N, index)
    end
    return string.format("%s  |c999999%s · %s|r", name, U.FormatDuration(F.Duration(fight)), U.FormatNumber(fight[NM.sv.metric].total))
end

-- Descripción del icono de combates: qué combate se está viendo.
local function FightsTooltip()
    local fight = F.Get(M.viewIndex)
    if not fight then return L.MENU_FIGHTS end
    return string.format("%s\n%s · %s", L.MENU_FIGHTS, TitleText(fight), U.FormatDuration(F.Duration(fight)))
end

-- Icono de combates: lista de combates para elegir cuál se ve.
function M.ShowFightsMenu(anchor)
    ClearMenu()
    if #F.history == 0 then
        AddMenuItem(L.NO_FIGHTS, nil, MENU_ADD_OPTION_LABEL)
    end
    for i, fight in ipairs(F.history) do
        AddMenuItem(Check(i == M.viewIndex, FightMenuLabel(fight, i)), function() M.ShowView(i) end)
    end
    ShowMenu(anchor)
end

function M.ShowMenu(anchor)
    ClearMenu()
    local sv = NM.sv
    AddMenuItem(L.MENU_METRIC, nil, MENU_ADD_OPTION_LABEL)
    AddMenuItem(Check(sv.metric ~= "healing", L.METRIC_DAMAGE), function() M.SetMetric("damage") end)
    AddMenuItem(Check(sv.metric == "healing", L.METRIC_HEALING), function() M.SetMetric("healing") end)

    AddMenuItem(L.MENU_VIEW, nil, MENU_ADD_OPTION_LABEL)
    AddMenuItem(Check(sv.mode == "group", L.MODE_GROUP), function() M.SetMode("group") end)
    AddMenuItem(Check(sv.mode == "abilities", L.MODE_ABILITIES), function() M.SetMode("abilities") end)

    if #F.history > 0 then
        AddMenuItem(L.MENU_FIGHTS, nil, MENU_ADD_OPTION_LABEL)
        for i, fight in ipairs(F.history) do
            AddMenuItem(Check(i == M.viewIndex, FightMenuLabel(fight, i)), function() M.ShowView(i) end)
        end
    end

    AddMenuItem(L.MENU_ACTIONS, nil, MENU_ADD_OPTION_LABEL)
    AddMenuItem("   " .. L.MENU_RESET, function() F.Reset() end)
    AddMenuItem("   " .. (sv.window.locked and L.UNLOCK or L.LOCK), function() M.SetLocked(not sv.window.locked) end)
    AddMenuItem("   " .. L.SETTINGS, function() NM.Settings.Open() end)
    ShowMenu(anchor)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
local function Build()
    local tlw = WM:CreateTopLevelWindow("NirnhonedMetrics_TLW")
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetMouseEnabled(false)
    -- Mismo nivel que los avisos de OmniAura: más abajo, otros controles del HUD que
    -- estén encima se quedan con el ratón y la ventana no se puede arrastrar.
    tlw:SetDrawTier(DT_MEDIUM)
    M.tlw = tlw

    -- Solo se ve con la interfaz de juego (también con el cursor activo) y no en menús.
    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    local frame = WM:CreateControl("NirnhonedMetricsFrame", tlw, CT_CONTROL)
    frame:SetClampedToScreen(true)
    M.frame = frame
    M.MakeDraggable(frame)

    M.bg = Solid("NirnhonedMetricsBg", frame, 0, 0, 0, NM.sv.bgAlpha)
    M.bg:SetAnchorFill(frame)

    local header = Solid("NirnhonedMetricsHeader", frame, 0.05, 0.05, 0.07, 0.9)
    header:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    M.MakeDraggable(header, function() M.ShowMenu(header) end)
    M.header = header

    -- Nombre del addon y, a la derecha, la fila de iconos (de derecha a izquierda:
    -- cerrar, ajustes, candado, reiniciar, combates, mis habilidades, grupo, sanación, daño).
    -- Con la ventana bloqueada, cerrar y ajustes se ocultan (ver M.SetLocked).
    local close = IconButton("NirnhonedMetricsClose", header, TEX_CLOSE, L.HIDE_WINDOW, function() M.SetShown(false) end)
    close:SetDimensions(16, 16)
    close:SetAnchor(RIGHT, header, RIGHT, -4, 0)
    M.closeBtn = close

    local settings = IconButton("NirnhonedMetricsSettings", header, TEX_SETTINGS, L.SETTINGS, function() NM.Settings.Open() end)
    settings:SetAnchor(RIGHT, close, LEFT, -2, 0)
    M.settingsBtn = settings

    M.lockBtn = IconButton("NirnhonedMetricsLock", header, TEX_LOCKED,
        function() return NM.sv.window.locked and L.UNLOCK or L.LOCK end,
        function() M.SetLocked(not NM.sv.window.locked) end)
    M.lockBtn:SetDimensions(18, 18)
    M.lockBtn:SetAnchor(RIGHT, settings, LEFT, 0, 0)

    local reset = IconButton("NirnhonedMetricsReset", header, TEX_RESET, L.MENU_RESET, function() F.Reset() end)
    reset:SetAnchor(RIGHT, M.lockBtn, LEFT, 0, 0)

    local fights
    fights = IconButton("NirnhonedMetricsFights", header, TEX_FIGHTS, FightsTooltip, function() M.ShowFightsMenu(fights) end)
    fights:SetAnchor(RIGHT, reset, LEFT, 0, 0)

    M.abilitiesBtn = IconButton("NirnhonedMetricsModeAbilities", header, TEX_ABILITIES, L.MODE_ABILITIES,
        function() M.SetMode("abilities") end)
    M.abilitiesBtn:SetAnchor(RIGHT, fights, LEFT, 0, 0)

    M.groupBtn = IconButton("NirnhonedMetricsModeGroup", header, TEX_GROUP, L.MODE_GROUP,
        function() M.SetMode("group") end)
    M.groupBtn:SetAnchor(RIGHT, M.abilitiesBtn, LEFT, 0, 0)

    M.healingBtn = IconButton("NirnhonedMetricsMetricHealing", header, TEX_HEALING, L.METRIC_HEALING,
        function() M.SetMetric("healing") end)
    M.healingBtn:SetAnchor(RIGHT, M.groupBtn, LEFT, -6, 0)

    M.damageBtn = IconButton("NirnhonedMetricsMetricDamage", header, TEX_DAMAGE, L.METRIC_DAMAGE,
        function() M.SetMetric("damage") end)
    M.damageBtn:SetAnchor(RIGHT, M.healingBtn, LEFT, 0, 0)

    M.title = Label("NirnhonedMetricsTitle", header, TEXT_ALIGN_LEFT)
    M.title:SetText(NM.title)
    M.title:SetAnchor(LEFT, header, LEFT, 6, 0)
    M.title:SetAnchor(RIGHT, M.damageBtn, LEFT, -6, 0)

    -- Pie: reloj con la duración del combate y, a la derecha, qué combate se ve.
    local footer = Solid("NirnhonedMetricsFooter", frame, 0.05, 0.05, 0.07, 0.9)
    footer:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    footer:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    M.footer = footer

    M.clock = WM:CreateControl("NirnhonedMetricsClock", footer, CT_TEXTURE)
    M.clock:SetTexture(TEX_CLOCK)
    M.clock:SetAnchor(LEFT, footer, LEFT, 4, 0)

    M.footerTime = Label("NirnhonedMetricsFooterTime", footer, TEXT_ALIGN_LEFT)
    M.footerTime:SetAnchor(LEFT, M.clock, RIGHT, 3, 0)

    -- Deja sitio a la esquina de redimensionar.
    M.footerFight = Label("NirnhonedMetricsFooterFight", footer, TEXT_ALIGN_RIGHT)
    M.footerFight:SetColor(0.65, 0.65, 0.65, 1)
    M.footerFight:SetAnchor(RIGHT, footer, RIGHT, -18, 0)
    M.footerFight:SetAnchor(LEFT, M.footerTime, RIGHT, 10, 0)

    local content = WM:CreateControl("NirnhonedMetricsContent", frame, CT_CONTROL)
    content:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 2, 2)
    content:SetAnchor(BOTTOMRIGHT, footer, TOPRIGHT, -2, -2)
    M.content = content

    M.empty = Label("NirnhonedMetricsEmpty", content, TEXT_ALIGN_CENTER)
    M.empty:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    M.empty:SetColor(0.7, 0.7, 0.7, 1)
    M.empty:SetAnchor(TOPLEFT, content, TOPLEFT, 8, 8)
    M.empty:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, -8, -8)

    BuildResizeHandles(frame)
end

-- Tamaños de texto de la cabecera y del pie; ambos crecen con su texto.
local function ApplyHeader()
    M.header:SetHeight(HeaderHeight())
    SetLabelFont(M.title, Font(NM.sv.titleFontSize))

    local footerH = FooterHeight()
    local footerFont = Font(NM.sv.fontSize)
    M.footer:SetHeight(footerH)
    M.clock:SetDimensions(footerH - 4, footerH - 4)
    SetLabelFont(M.footerTime, footerFont)
    SetLabelFont(M.footerFight, footerFont)
end

-- Aplica los ajustes visuales (se llama desde el panel de ajustes).
function M.ApplySettings()
    if not M.frame then return end
    M.bg:SetCenterColor(0, 0, 0, NM.sv.bgAlpha)
    ApplyHeader()
    UpdateModeButtons()
    M.ApplyPosition()
    M.UpdateVisibility()
    M.Refresh()
end

function M.Init()
    Build()
    ApplyHeader()
    UpdateModeButtons()
    M.ApplyPosition()
    M.SetLocked(NM.sv.window.locked)

    CALLBACK_MANAGER:RegisterCallback(F.CHANGED, function(what)
        -- Al empezar un combate se vuelve a mostrar el combate actual.
        if what == "start" then
            M.viewIndex = 1
            M.scroll = 0
        end
        if what then M.UpdateVisibility() else M.Refresh() end
    end)
    -- Al cambiar de zona puede entrar o salir de PvP.
    EM:RegisterForEvent(NM.name .. "_MeterZone", EVENT_PLAYER_ACTIVATED, M.UpdateVisibility)

    M.UpdateVisibility()
end
