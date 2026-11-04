-- Panel en pantalla, con el mismo estilo de ventana que Nirnhoned Metrics: cabecera
-- oscura con el título y los botones, contenido sobre fondo translúcido y pie oscuro.
-- Dos vistas:
--   grid:    una fila por miembro y una columna por bufo (icono encendido, tiempo restante).
--   summary: una fila por bufo con cuántos miembros lo tienen (6/8).
-- El pie muestra la duración del combate y el uptime de cada bufo (se puede ocultar).
-- Mientras está visible se actualiza cada TICK_MS; oculto no hace nada (ni escucha efectos).

local VG = Vigilant
local U = VG.Utils
local L = VG.L
local WM = WINDOW_MANAGER
local P = { rows = {}, sumRows = {}, footers = {}, layoutDirty = true }
VG.Panel = P

local T  -- VG.Tracker, se asigna en Init

local TICK = VG.name .. "_Tick"
local TICK_MS = 200
local PAD = 4
local GAP = 2
local HEADER_H = 28
local FOOTER_H = 24
local BUTTON_SIZE = 22
local TITLE_FONT_SIZE = 18
local FOOTER_FONT_SIZE = 14
local MIN_W, MAX_W = 200, 1400
local MIN_H, MAX_H = HEADER_H + FOOTER_H + 40, 1000
local DEFAULT_X, DEFAULT_Y = 60, 300
P.ICON_MIN, P.ICON_MAX = 16, 56
P.NAME_MIN, P.NAME_MAX = 40, 240

local TEX_CLOSE = {
    up = "EsoUI/Art/Buttons/closebutton_up.dds",
    over = "EsoUI/Art/Buttons/closebutton_mouseover.dds",
    down = "EsoUI/Art/Buttons/closebutton_down.dds",
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
local TEX_SETTINGS = {
    up = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_up.dds",
    over = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_over.dds",
    down = "EsoUI/Art/SkillsAdvisor/advisor_tabIcon_settings_down.dds",
}
-- Botón de vista: muestra la vista a la que se cambia (miembros o lista de bufos).
local TEX_GRID = {
    up = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds",
    over = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds",
    down = "EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds",
}
local TEX_SUMMARY = {
    up = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    over = "EsoUI/Art/MainMenu/menuBar_skills_over.dds",
    down = "EsoUI/Art/MainMenu/menuBar_skills_down.dds",
}
local TEX_CLOCK = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds"
-- Modo del uptime: espada (pestaña de armas del inventario) = cada combate;
-- puerta del buscador de mazmorras = toda la run.
local TEX_FIGHT = {
    up = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_up.dds",
    over = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_over.dds",
    down = "EsoUI/Art/Inventory/inventory_tabIcon_weapons_down.dds",
}
local TEX_RUN = {
    up = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds",
    over = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_over.dds",
    down = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_down.dds",
}
-- Flecha circular del botón "Actualizar" del buscador de grupos del juego.
local TEX_RESET = {
    up = "EsoUI/Art/LFG/LFG_groupFinder_refreshSearch_up.dds",
    over = "EsoUI/Art/LFG/LFG_groupFinder_refreshSearch_over.dds",
    down = "EsoUI/Art/LFG/LFG_groupFinder_refreshSearch_down.dds",
}

local COLOR_NAME = { 0.85, 0.85, 0.85, 1 }
local COLOR_SELF = { 0.95, 0.70, 0.24, 1 }
local COLOR_FAR = { 0.5, 0.5, 0.5, 1 }
local COLOR_TIMER = { 1, 1, 1, 1 }
local COLOR_WARN = { 1, 0.55, 0.1, 1 }
local COLOR_ALL = { 0.35, 0.9, 0.35, 1 }
local COLOR_SOME = { 1, 0.8, 0.2, 1 }
local COLOR_NONE = { 1, 0.3, 0.3, 1 }
local FAR_ALPHA = 0.6
local MISSING_ALPHA = 0.6     -- apagado: en gris, pero que se distinga bien el icono
local UPTIME_GOOD, UPTIME_FAIR = 0.9, 0.5   -- verde desde el 90 %, amarillo desde el 50 %

---------------------------------------------------------------------------
-- Controles
---------------------------------------------------------------------------
local function Font(size)
    return string.format("$(BOLD_FONT)|%d|soft-shadow-thick", zo_round(size))
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
    label:SetMaxLineCount(1)
    return label
end

-- Evita redibujar texto y color si no cambian (se llama 5 veces por segundo por celda).
local function SetText(label, text)
    if label.vgText ~= text then
        label.vgText = text
        label:SetText(text)
    end
end

local function SetColor(label, c)
    if label.vgColor ~= c then
        label.vgColor = c
        label:SetColor(U.Color(c))
    end
end

-- Al recolocar: fuente nueva (si se da) y texto vacío, y se olvida lo que mostraba para
-- que el siguiente tick lo vuelva a escribir. El juego no redibuja una etiqueta con la
-- fuente nueva si el texto no cambia (igual que en Nirnhoned Metrics).
local function ResetLabel(label, font)
    if font then label:SetFont(font) end
    label:SetText("")
    label.vgText, label.vgColor, label.vgVersion, label.vgPct = "", nil, nil, nil
end

local function ShowTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function Tooltip(control, textFn)
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function()
        local text = textFn(control)
        if text then ShowTooltip(control, text) end
    end)
    control:SetHandler("OnMouseExit", HideTooltip)
end

local function UnitLabel(u)
    if VG.sv.nameFormat == "account" and u.account ~= "" then
        return ZO_FormatUserFacingDisplayName(u.account)
    end
    return u.name
end

-- Uptime (0..1 o nil si aún no ha habido combate) como texto y color. Sin datos, vacío.
local function UptimeText(v)
    if not v then return "" end
    return string.format("%d%%", zo_round(v * 100))
end

local function UptimeColor(v)
    if not v then return COLOR_FAR end
    if v >= UPTIME_GOOD then return COLOR_ALL end
    if v >= UPTIME_FAIR then return COLOR_SOME end
    return COLOR_NONE
end

local function DurationText(sec)
    sec = math.floor(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local function CellTooltip(cell)
    local col, u = cell.col, cell.unit
    local lines = { col.name, UnitLabel(u) }
    local rem = T.Remaining(u.tag, col.key, GetFrameTimeSeconds())
    if not T.IsReachable(u) then
        lines[#lines + 1] = L.OUT_OF_RANGE
    elseif not rem then
        lines[#lines + 1] = L.MISSING
    elseif rem ~= T.INFINITE then
        lines[#lines + 1] = string.format(L.REMAINING, U.FormatTime(rem))
    end
    return table.concat(lines, "\n")
end

-- Vista resumen: quién no lo tiene.
local function SummaryTooltip(row)
    local col = row.col
    local now = GetFrameTimeSeconds()
    local missing, far = {}, {}
    for _, u in ipairs(T.units) do
        if not T.IsReachable(u) then
            far[#far + 1] = UnitLabel(u)
        elseif not T.Remaining(u.tag, col.key, now) then
            missing[#missing + 1] = UnitLabel(u)
        end
    end
    local lines = { col.name }
    if #missing > 0 then lines[#lines + 1] = L.MISSING_ON .. " " .. table.concat(missing, ", ") end
    if #far > 0 then lines[#lines + 1] = L.OUT_OF_RANGE .. ": " .. table.concat(far, ", ") end
    local uptime = VG.sv.showUptime and T.GroupUptime(col.key)
    if uptime then lines[#lines + 1] = L.UPTIME_TITLE .. ": " .. UptimeText(uptime) end
    return table.concat(lines, "\n")
end

-- Pie: el uptime de cada miembro.
local function FooterTooltip(f)
    local col = f.col
    local lines = { col.name, L.UPTIME_TITLE }
    for _, u in ipairs(T.units) do
        local v = T.MemberUptime(u.name, col.key)
        if v then lines[#lines + 1] = string.format("%s: %s", UnitLabel(u), UptimeText(v)) end
    end
    if #lines == 2 then lines[#lines + 1] = L.UPTIME_NONE end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Piezas reutilizables (se crean al necesitarlas y luego solo se ocultan)
---------------------------------------------------------------------------
local function CreateCell(name, parent)
    local cell = WM:CreateControl(name, parent, CT_CONTROL)
    cell.bg = Solid(name .. "Bg", cell, 0.75, 0.08, 0.08, 0.55)
    cell.bg:SetAnchorFill(cell)
    cell.icon = WM:CreateControl(name .. "Icon", cell, CT_TEXTURE)
    cell.icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 1, 1)
    cell.icon:SetAnchor(BOTTOMRIGHT, cell, BOTTOMRIGHT, -1, -1)
    cell.timer = Label(name .. "Timer", cell, TEXT_ALIGN_CENTER)
    cell.timer:SetAnchorFill(cell)
    Tooltip(cell, CellTooltip)
    return cell
end

local function GetRow(i)
    local row = P.rows[i]
    if not row then
        local name = "VigilantRow" .. i
        row = WM:CreateControl(name, P.frame, CT_CONTROL)
        row.role = WM:CreateControl(name .. "Role", row, CT_TEXTURE)
        row.name = Label(name .. "Name", row)
        row.cells = {}
        P.rows[i] = row
    end
    return row
end

local function GetCell(row, c)
    local cell = row.cells[c]
    if not cell then
        cell = CreateCell(row:GetName() .. "Cell" .. c, row)
        row.cells[c] = cell
    end
    return cell
end

local function GetSumRow(i)
    local row = P.sumRows[i]
    if not row then
        local name = "VigilantSummary" .. i
        row = WM:CreateControl(name, P.frame, CT_CONTROL)
        row.icon = WM:CreateControl(name .. "Icon", row, CT_TEXTURE)
        row.name = Label(name .. "Name", row)
        row.count = Label(name .. "Count", row, TEXT_ALIGN_RIGHT)
        row.uptime = Label(name .. "Uptime", row, TEXT_ALIGN_RIGHT)
        Tooltip(row, SummaryTooltip)
        P.sumRows[i] = row
    end
    return row
end

local function GetFooter(c)
    local f = P.footers[c]
    if not f then
        f = Label("VigilantFooter" .. c, P.footer, TEXT_ALIGN_CENTER)
        f:SetFont(Font(FOOTER_FONT_SIZE))
        Tooltip(f, FooterTooltip)
        P.footers[c] = f
    end
    return f
end

local function HideFrom(list, first)
    for i = first, #list do list[i]:SetHidden(true) end
end

---------------------------------------------------------------------------
-- Colocación
-- El tamaño de la ventana lo elige el jugador arrastrando sus bordes (como en Nirnhoned
-- Metrics) y los iconos se ajustan para que todo quepa dentro.
---------------------------------------------------------------------------
local function Fonts(size)
    return Font(math.max(10, size * 0.5)), Font(math.max(12, size * 0.55))
end

local function FitIcon(size)
    return zo_clamp(math.floor(size), P.ICON_MIN, P.ICON_MAX)
end

-- Ancho por fila: [rol] nombre columnas...  Alto: una fila por miembro. No hay fila de
-- iconos encima: cada celda ya muestra el icono de su bufo (apagado si falta).
local function GridIconSize(availW, availH)
    local sv = VG.sv
    local k = #T.columns + (sv.showRoles and 1 or 0)
    local byW = (availW - sv.nameWidth) / k - GAP
    local byH = (availH + GAP) / #T.units - GAP
    return FitIcon(math.min(byW, byH))
end

-- Devuelve el ancho y alto que necesita el contenido (si no cabe, la ventana crece).
local function LayoutGrid(top, availW, availH, bottomSpace)
    local sv = VG.sv
    local size = GridIconSize(availW, availH)
    local cols, units = T.columns, T.units
    local timerFont, nameFont = Fonts(size)
    local roleW = sv.showRoles and (size + GAP) or 0
    local left = roleW + sv.nameWidth + GAP
    local step = size + GAP
    local rowW = left + #cols * step - GAP
    -- Desbloqueada, las celdas no capturan el ratón para poder arrastrar el panel desde ellas.
    local mouse = sv.window.locked
    local rowsTop = top

    for i, u in ipairs(units) do
        local row = GetRow(i)
        row.unit = u
        row:SetDimensions(rowW, size)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, P.frame, TOPLEFT, PAD, rowsTop + (i - 1) * step)
        row:SetHidden(false)

        local roleIcon = sv.showRoles and u.role ~= LFG_ROLE_INVALID and ZO_GetRoleIcon(u.role)
        row.vgReachable = nil
        row.role:SetHidden(not roleIcon)
        if roleIcon then
            row.role:SetTexture(roleIcon)
            row.role:SetDimensions(size * 0.8, size * 0.8)
            row.role:ClearAnchors()
            row.role:SetAnchor(LEFT, row, LEFT, size * 0.1, 0)
        end

        ResetLabel(row.name, nameFont)
        row.name:SetDimensions(sv.nameWidth, size)
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row, LEFT, roleW, 0)
        SetText(row.name, UnitLabel(u))

        for c, col in ipairs(cols) do
            local cell = GetCell(row, c)
            cell.col, cell.unit = col, u
            cell:SetDimensions(size, size)
            cell:ClearAnchors()
            cell:SetAnchor(TOPLEFT, row, TOPLEFT, left + (c - 1) * step, 0)
            cell:SetMouseEnabled(mouse)
            cell:SetHidden(false)
            cell.icon:SetTexture(col.icon)
            ResetLabel(cell.timer, timerFont)
            cell.vgState, cell.vgTimer = nil, nil
        end
        HideFrom(row.cells, #cols + 1)
    end
    HideFrom(P.rows, #units + 1)
    HideFrom(P.sumRows, 1)

    -- Uptime de cada bufo en el pie, debajo de su columna.
    if VG.sv.showUptime then
        for c, col in ipairs(cols) do
            local f = GetFooter(c)
            f.col = col
            -- Algo más ancho que el icono para que quepa "100%" con iconos pequeños.
            f:SetDimensions(step + 8, FOOTER_H)
            f:ClearAnchors()
            f:SetAnchor(CENTER, P.footer, LEFT, PAD + left + (c - 1) * step + size / 2, 0)
            f:SetMouseEnabled(mouse)
            f:SetHidden(false)
            ResetLabel(f)
        end
        HideFrom(P.footers, #cols + 1)
    else
        HideFrom(P.footers, 1)
    end

    return PAD + rowW + PAD, rowsTop + #units * step - GAP + bottomSpace
end

-- Una fila por bufo: el alto decide el icono y el nombre ocupa el ancho que sobra.
local function LayoutSummary(top, availW, availH, bottomSpace)
    local cols = T.columns
    local size = FitIcon(math.min((availH + GAP) / #cols - GAP, availW / 5))
    local countFont, nameFont = Fonts(size)
    local countW = math.max(44, size * 1.6)
    local showUptime = VG.sv.showUptime
    local uptimeW = showUptime and math.max(44, size * 1.6) or 0
    local nameW = math.max(P.NAME_MIN, availW - size - GAP * 3 - countW - uptimeW)
    local rowW = size + GAP * 3 + nameW + countW + uptimeW
    local step = size + GAP
    local mouse = VG.sv.window.locked

    for i, col in ipairs(cols) do
        local row = GetSumRow(i)
        row.col = col
        row:SetDimensions(rowW, size)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, P.frame, TOPLEFT, PAD, top + (i - 1) * step)
        row:SetMouseEnabled(mouse)
        row:SetHidden(false)

        row.icon:SetTexture(col.icon)
        row.icon:SetDimensions(size, size)
        row.icon:ClearAnchors()
        row.icon:SetAnchor(LEFT, row, LEFT, 0, 0)

        ResetLabel(row.name, nameFont)
        row.name:SetDimensions(nameW, size)
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row.icon, RIGHT, GAP * 2, 0)
        SetText(row.name, col.name)

        ResetLabel(row.count, countFont)
        row.count:SetDimensions(countW, size)
        row.count:ClearAnchors()
        row.count:SetAnchor(RIGHT, row, RIGHT, -uptimeW, 0)
        row.vgCount = nil

        row.uptime:SetHidden(not showUptime)
        ResetLabel(row.uptime, countFont)
        row.uptime:SetDimensions(uptimeW, size)
        row.uptime:ClearAnchors()
        row.uptime:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    end
    HideFrom(P.sumRows, #cols + 1)
    HideFrom(P.rows, 1)
    HideFrom(P.footers, 1)

    return PAD + rowW + PAD, top + #cols * step - GAP + bottomSpace
end

function P.Layout()
    P.layoutDirty = false
    local sv = VG.sv
    P.UpdateButtons()

    -- El pie solo se ve con el uptime activado.
    P.footer:SetHidden(not sv.showUptime)
    local top = HEADER_H + PAD
    local bottomSpace = PAD + (sv.showUptime and FOOTER_H or 0)
    local width = zo_clamp(sv.window.width, MIN_W, MAX_W)
    local height = zo_clamp(sv.window.height, MIN_H, MAX_H)
    local availW, availH = width - PAD * 2, height - top - bottomSpace

    -- Si ni con los iconos más pequeños cabe todo, la ventana crece lo justo.
    local w, h = 0, 0
    if #T.columns == 0 then
        HideFrom(P.rows, 1)
        HideFrom(P.sumRows, 1)
        HideFrom(P.footers, 1)
        P.empty:SetHidden(false)
    else
        P.empty:SetHidden(true)
        if sv.layout == "summary" then
            w, h = LayoutSummary(top, availW, availH, bottomSpace)
        else
            w, h = LayoutGrid(top, availW, availH, bottomSpace)
        end
    end

    P.frame:SetDimensions(math.max(width, w), math.max(height, h))
    P.bg:SetCenterColor(0, 0, 0, sv.bgOpacity)
end

---------------------------------------------------------------------------
-- Actualización (cada tick)
---------------------------------------------------------------------------
-- Cada tick solo se llama al juego (SetAlpha, SetText...) para lo que ha cambiado desde
-- el tick anterior: el estado mostrado se guarda en cada control (vg*). Layout lo borra.

-- Estado de una celda: "on" (lo tiene), "off" (le falta), "red" (le falta, sobre rojo).
local function SetCellState(cell, state)
    if cell.vgState == state then return end
    cell.vgState = state
    local on = state == "on"
    cell.icon:SetAlpha(on and 1 or MISSING_ALPHA)
    cell.icon:SetDesaturation(on and 0 or 1)
    cell.bg:SetHidden(state ~= "red")
end

-- Tiempo restante: el texto solo se rehace cuando cambia el número que se ve.
local function SetCellTimer(cell, rem, warn)
    local shown = rem and (rem >= 60 and -math.floor(rem / 60) or math.ceil(rem))
    if cell.vgTimer == shown and cell.vgWarn == warn then return end
    cell.vgTimer, cell.vgWarn = shown, warn
    SetText(cell.timer, shown and U.FormatTime(rem) or "")
    SetColor(cell.timer, warn and COLOR_WARN or COLOR_TIMER)
end

-- Uptime en un texto: solo se rehace si hay datos nuevos (versión) y cambia el % entero.
local function SetUptime(label, key)
    local version = T.uptime.version
    if label.vgVersion == version then return end
    label.vgVersion = version
    local v = T.GroupUptime(key)
    local pct = v and zo_round(v * 100)
    if label.vgPct == pct and label.vgText ~= nil then return end
    label.vgPct = pct
    SetText(label, UptimeText(v))
    SetColor(label, UptimeColor(v))
end

local function UpdateGrid(now)
    local sv = VG.sv
    local red = sv.missingStyle == "red"
    local timers, warnSeconds = sv.showTimers, sv.warnSeconds
    for i, u in ipairs(T.units) do
        local row = P.rows[i]
        local reachable = u.reachable
        if row.vgReachable ~= reachable then
            row.vgReachable = reachable
            row:SetAlpha(reachable and 1 or FAR_ALPHA)
        end
        SetColor(row.name, not reachable and COLOR_FAR or (u.isPlayer and COLOR_SELF or COLOR_NAME))

        for c, col in ipairs(T.columns) do
            local cell = row.cells[c]
            local rem = reachable and T.Remaining(u.tag, col.key, now)
            if rem then
                SetCellState(cell, "on")
                local timed = timers and rem ~= T.INFINITE
                SetCellTimer(cell, timed and rem, timed and rem <= warnSeconds)
            else
                -- Lejos no se sabe si lo tiene: no se marca en rojo.
                SetCellState(cell, (red and reachable) and "red" or "off")
                SetCellTimer(cell, nil, false)
            end
        end
    end

    if sv.showUptime then
        for c, col in ipairs(T.columns) do SetUptime(P.footers[c], col.key) end
    end
end

local function UpdateSummary(now)
    local showUptime = VG.sv.showUptime
    for i, col in ipairs(T.columns) do
        local row = P.sumRows[i]
        local active, total = 0, 0
        for _, u in ipairs(T.units) do
            if u.reachable then
                total = total + 1
                if T.Remaining(u.tag, col.key, now) then active = active + 1 end
            end
        end
        local count = active * 100 + total
        if row.vgCount ~= count then
            row.vgCount = count
            SetText(row.count, string.format("%d/%d", active, total))
            SetColor(row.count, active == 0 and COLOR_NONE or (active == total and COLOR_ALL or COLOR_SOME))
            row.icon:SetAlpha(active == 0 and MISSING_ALPHA or 1)
            row.icon:SetDesaturation(active == 0 and 1 or 0)
        end
        if showUptime then SetUptime(row.uptime, col.key) end
    end
end

local function Tick()
    if T.unitsDirty then
        T.RebuildUnits()
        P.layoutDirty = true
    end
    local now = GetFrameTimeSeconds()
    local showUptime = VG.sv.showUptime
    T.RefreshReachable()
    T.ProcessDirty()
    if showUptime then T.UpdateUptime(now) end

    -- En menús (inventario, mapa...) el panel no se ve: no hace falta dibujarlo.
    if P.tlw:IsHidden() then return end

    if P.layoutDirty then P.Layout() end

    if showUptime then
        local sec = math.floor(T.uptime.duration)
        if P.vgDuration ~= sec then
            P.vgDuration = sec
            SetText(P.duration, DurationText(sec))
        end
    end
    if #T.columns == 0 then return end

    if VG.sv.layout == "summary" then
        UpdateSummary(now)
    else
        UpdateGrid(now)
    end
end

---------------------------------------------------------------------------
-- Visibilidad
---------------------------------------------------------------------------
function P.ShouldShow()
    local sv = VG.sv
    if not sv.window.shown then return false end
    -- Desbloqueado se ve siempre, para poder colocarlo.
    if not sv.window.locked then return true end
    if #T.columns == 0 then return false end
    if sv.onlyInGroup and not IsUnitGrouped("player") then return false end
    if sv.onlyInCombat and not IsUnitInCombat("player") then return false end
    return true
end

function P.UpdateVisibility()
    local show = P.ShouldShow()
    if show == P.visible then return end
    P.visible = show
    P.frame:SetHidden(not show)
    T.Enable(show)
    if show then
        P.layoutDirty = true
        Tick()
        EVENT_MANAGER:RegisterForUpdate(TICK, TICK_MS, Tick)
    else
        EVENT_MANAGER:UnregisterForUpdate(TICK)
    end
end

-- Tras cambiar ajustes o la lista de bufos.
function P.Refresh()
    P.layoutDirty = true
    P.UpdateVisibility()
    if P.visible then Tick() end
end

function P.SetShown(shown)
    VG.sv.window.shown = shown
    P.Refresh()
end

function P.SetLocked(locked)
    VG.sv.window.locked = locked
    if not locked then VG.sv.window.shown = true end
    P.Refresh()
end

function P.SetLayout(layout)
    VG.sv.layout = layout
    P.Refresh()
end

function P.ToggleLayout()
    P.SetLayout(VG.sv.layout == "summary" and "grid" or "summary")
end

-- Atajos de teclado (Bindings.xml).
function VG.Toggle()
    P.SetShown(not VG.sv.window.shown)
end

function VG.ToggleLock()
    P.SetLocked(not VG.sv.window.locked)
end

---------------------------------------------------------------------------
-- Cabecera: título y botones (vista, ajustes | candado, cerrar)
---------------------------------------------------------------------------
local function SetButtonTextures(b, textures)
    b:SetNormalTexture(textures.up)
    b:SetMouseOverTexture(textures.over)
    b:SetPressedTexture(textures.down)
end

-- "tooltip" es una función: el texto depende del estado (bloqueado, vista actual).
local function IconButton(name, parent, size, tooltip, onClick)
    local b = WM:CreateControl(name, parent, CT_BUTTON)
    b:SetDimensions(size, size)
    b:SetHandler("OnClicked", function()
        HideTooltip()
        onClick()
    end)
    b:SetHandler("OnMouseEnter", function() ShowTooltip(b, tooltip()) end)
    b:SetHandler("OnMouseExit", HideTooltip)
    return b
end

-- Línea vertical entre grupos de botones, como en Nirnhoned Metrics.
local function Separator(name, parent)
    local line = Solid(name, parent, 1, 1, 1, 0.25)
    line:SetDimensions(1, BUTTON_SIZE - 6)
    return line
end

function P.UpdateButtons()
    local sv = VG.sv
    SetButtonTextures(P.lockBtn, sv.window.locked and TEX_LOCKED or TEX_UNLOCKED)
    SetButtonTextures(P.layoutBtn, sv.layout == "summary" and TEX_GRID or TEX_SUMMARY)
    SetButtonTextures(P.scopeBtn, sv.uptimeScope == "run" and TEX_RUN or TEX_FIGHT)
    for _, handle in ipairs(P.resizeHandles) do handle:SetHidden(sv.window.locked) end
end

local function BuildHeader(frame)
    local header = Solid("VigilantHeaderBar", frame, 0.05, 0.05, 0.07, 0.9)
    header:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, 0)
    header:SetHeight(HEADER_H)

    P.closeBtn = IconButton("VigilantClose", header, 16,
        function() return L.CLOSE_TIP end,
        function()
            P.SetShown(false)
            VG.Print(L.HIDDEN)
        end)
    SetButtonTextures(P.closeBtn, TEX_CLOSE)
    P.closeBtn:SetAnchor(RIGHT, header, RIGHT, -6, 0)

    P.lockBtn = IconButton("VigilantLock", header, 18,
        function() return VG.sv.window.locked and L.UNLOCK_TIP or L.LOCK_TIP_BUTTON end,
        VG.ToggleLock)
    P.lockBtn:SetAnchor(RIGHT, P.closeBtn, LEFT, -4, 0)

    local separator = Separator("VigilantHeaderSeparator", header)
    separator:SetAnchor(RIGHT, P.lockBtn, LEFT, -4, 0)

    P.settingsBtn = IconButton("VigilantSettings", header, BUTTON_SIZE,
        function() return L.SETTINGS_TIP end,
        function() VG.Settings.Open() end)
    SetButtonTextures(P.settingsBtn, TEX_SETTINGS)
    P.settingsBtn:SetAnchor(RIGHT, separator, LEFT, -4, 0)

    P.layoutBtn = IconButton("VigilantLayout", header, BUTTON_SIZE,
        function()
            return string.format(L.SWITCH_TO, VG.sv.layout == "summary" and L.LAYOUT_GRID or L.LAYOUT_SUMMARY)
        end,
        P.ToggleLayout)
    P.layoutBtn:SetAnchor(RIGHT, P.settingsBtn, LEFT, -2, 0)

    P.title = Label("VigilantTitle", header)
    P.title:SetFont(Font(TITLE_FONT_SIZE))
    P.title:SetAnchor(LEFT, header, LEFT, 6, 0)
    P.title:SetAnchor(RIGHT, P.layoutBtn, LEFT, -6, 0)
    P.title:SetText(VG.title)
end

-- Pie: reloj con la duración del combate y, en la cuadrícula, el uptime de cada columna.
local function BuildFooter(frame)
    local footer = Solid("VigilantFooterBar", frame, 0.05, 0.05, 0.07, 0.9)
    footer:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    footer:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    footer:SetHeight(FOOTER_H)
    P.footer = footer

    local function UptimeTip()
        return VG.sv.uptimeScope == "run" and L.UPTIME_TIP_RUN or L.UPTIME_TIP_FIGHT
    end

    -- Reloj y duración; después, el botón de modo (cada combate / toda la run) y el de
    -- reinicio.
    local clock = WM:CreateControl("VigilantClock", footer, CT_TEXTURE)
    clock:SetTexture(TEX_CLOCK)
    clock:SetDimensions(FOOTER_H - 4, FOOTER_H - 4)
    clock:SetAnchor(LEFT, footer, LEFT, 4, 0)
    Tooltip(clock, UptimeTip)

    P.duration = Label("VigilantDuration", footer)
    P.duration:SetFont(Font(FOOTER_FONT_SIZE))
    P.duration:SetAnchor(LEFT, clock, RIGHT, 3, 0)
    P.duration:SetDimensions(44, FOOTER_H)   -- fijo, para que los botones no salten al cambiar de 9:59 a 10:00

    -- El icono muestra el modo actual (ver P.UpdateButtons); clic para cambiarlo.
    P.scopeBtn = IconButton("VigilantUptimeScope", footer, FOOTER_H - 4,
        function()
            local run = VG.sv.uptimeScope == "run"
            return UptimeTip() .. "\n\n"
                .. string.format(L.UPTIME_SWITCH, run and L.UPTIME_SCOPE_FIGHT or L.UPTIME_SCOPE_RUN)
        end,
        function() VG.SetUptimeScope(VG.sv.uptimeScope == "run" and "fight" or "run") end)
    P.scopeBtn:SetAnchor(LEFT, P.duration, RIGHT, 6, 0)

    local reset = IconButton("VigilantUptimeReset", footer, FOOTER_H - 6,
        function() return L.UPTIME_RESET end, VG.ResetUptime)
    SetButtonTextures(reset, TEX_RESET)
    reset:SetAnchor(LEFT, P.scopeBtn, RIGHT, 2, 0)
end

-- Pone el uptime a cero (botón del pie, ajustes y /vigilant reset).
function VG.ResetUptime()
    T.ResetUptime()
    if P.visible then Tick() end
end

-- "fight" | "run" (botón del reloj del pie y ajustes). Al cambiar de modo se empieza de
-- cero: mezclar los dos no tendría sentido.
function VG.SetUptimeScope(scope)
    VG.sv.uptimeScope = scope
    T.ResetUptime()
    P.Refresh()
end

---------------------------------------------------------------------------
-- Redimensionar, como en Nirnhoned Metrics: la esquina cambia ancho y alto; los bordes
-- derecho e inferior, solo uno. Solo con el panel desbloqueado.
-- Van en un nivel de dibujo superior (DT_HIGH) para que nada del panel les quite el clic.
---------------------------------------------------------------------------
local RESIZE = VG.name .. "_Resize"
local MOVE = VG.name .. "_Move"
local RESIZE_EDGE = 5     -- grosor de los bordes que redimensionan
local RESIZE_CORNER = 14
local GRIP_STEP = 2

-- paint(handle, hovered) dibuja el asa en reposo o con el ratón encima.
local function ResizeHandle(name, resizeW, resizeH, cursor, paint)
    local handle = Solid(name, P.frame, 1, 1, 1, 0)
    handle:SetDrawTier(DT_HIGH)
    handle:SetMouseEnabled(true)
    handle:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        HideTooltip()
        local mx, my = GetUIMousePosition()
        local w, h = P.frame:GetDimensions()
        EVENT_MANAGER:RegisterForUpdate(RESIZE, 0, function()
            local x, y = GetUIMousePosition()
            local window = VG.sv.window
            if resizeW then window.width = zo_clamp(w + x - mx, MIN_W, MAX_W) end
            if resizeH then window.height = zo_clamp(h + y - my, MIN_H, MAX_H) end
            P.Refresh()
        end)
    end)
    handle:SetHandler("OnMouseUp", function()
        EVENT_MANAGER:UnregisterForUpdate(RESIZE)
        P.Refresh()
    end)
    handle:SetHandler("OnMouseEnter", function()
        paint(handle, true)
        WM:SetMouseCursor(cursor)
    end)
    handle:SetHandler("OnMouseExit", function()
        paint(handle, false)
        WM:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
    end)
    return handle
end

-- Los bordes son invisibles y se iluminan con el ratón encima.
local function PaintEdge(handle, hovered)
    handle:SetCenterColor(1, 1, 1, hovered and 0.35 or 0)
end

-- La esquina es un triángulo hecho con franjas de 2 px, cada una más ancha que la
-- anterior y alineadas a la derecha.
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

local function BuildResizeHandles(frame)
    local corner = ResizeHandle("VigilantGrip", true, true, MOUSE_CURSOR_RESIZE_NWSE, PaintCorner)
    corner:SetDimensions(RESIZE_CORNER, RESIZE_CORNER)
    corner:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    BuildTriangle(corner, RESIZE_CORNER)

    local right = ResizeHandle("VigilantGripRight", true, false, MOUSE_CURSOR_RESIZE_EW, PaintEdge)
    right:SetWidth(RESIZE_EDGE)
    right:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 0, HEADER_H)
    right:SetAnchor(BOTTOMRIGHT, corner, TOPRIGHT, 0, 0)

    local bottom = ResizeHandle("VigilantGripBottom", false, true, MOUSE_CURSOR_RESIZE_NS, PaintEdge)
    bottom:SetHeight(RESIZE_EDGE)
    bottom:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 0, 0)
    bottom:SetAnchor(BOTTOMRIGHT, corner, BOTTOMLEFT, 0, 0)

    P.resizeHandles = { corner, right, bottom }
end

---------------------------------------------------------------------------
-- Mover: a mano (no con SetMovable), para que arrastrar un borde no mueva el panel.
---------------------------------------------------------------------------
local function SavePosition()
    VG.sv.window.x = P.frame:GetLeft()
    VG.sv.window.y = P.frame:GetTop()
end

local function StartMove()
    local mx, my = GetUIMousePosition()
    local left, top = P.frame:GetLeft(), P.frame:GetTop()
    EVENT_MANAGER:RegisterForUpdate(MOVE, 0, function()
        local x, y = GetUIMousePosition()
        P.frame:ClearAnchors()
        P.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left + x - mx, top + y - my)
    end)
    P.moving = true
end

local function StopMove()
    if not P.moving then return end
    P.moving = false
    EVENT_MANAGER:UnregisterForUpdate(MOVE)
    SavePosition()
end

function P.ResetPosition()
    VG.sv.window.x, VG.sv.window.y = nil, nil
    P.frame:ClearAnchors()
    P.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DEFAULT_X, DEFAULT_Y)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
local function Build()
    local tlw = WM:CreateTopLevelWindow("Vigilant_TLW")
    P.tlw = tlw
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetMouseEnabled(false)
    tlw:SetDrawTier(DT_MEDIUM)

    -- Solo se ve con la interfaz de juego (también con el cursor activo) y no en menús.
    local fragment = ZO_HUDFadeSceneFragment:New(tlw)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    local frame = WM:CreateControl("VigilantFrame", tlw, CT_CONTROL)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(true)
    frame:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and not VG.sv.window.locked then StartMove() end
    end)
    frame:SetHandler("OnMouseUp", StopMove)
    frame:SetHidden(true)
    P.frame = frame

    local w = VG.sv.window
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, w.x or DEFAULT_X, w.y or DEFAULT_Y)

    P.bg = Solid("VigilantBg", frame, 0, 0, 0, VG.sv.bgOpacity)
    P.bg:SetAnchorFill(frame)

    BuildHeader(frame)
    BuildFooter(frame)
    BuildResizeHandles(frame)

    P.empty = Label("VigilantEmpty", frame, TEXT_ALIGN_CENTER)
    P.empty:SetFont("ZoFontGameSmall")
    P.empty:SetColor(0.7, 0.7, 0.7, 1)
    P.empty:SetAnchor(TOPLEFT, frame, TOPLEFT, PAD, HEADER_H + PAD)
    P.empty:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -PAD, HEADER_H + PAD)
    P.empty:SetHeight(28)
    P.empty:SetText(L.NO_BUFFS)
end

function P.Init()
    T = VG.Tracker
    Build()
    EVENT_MANAGER:RegisterForEvent(VG.name .. "_Combat", EVENT_PLAYER_COMBAT_STATE, P.UpdateVisibility)
    P.UpdateVisibility()
end
