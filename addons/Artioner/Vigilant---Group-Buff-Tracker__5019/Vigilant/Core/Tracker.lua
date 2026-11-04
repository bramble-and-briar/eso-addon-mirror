-- Estado de los bufos de cada miembro del grupo.
-- Se escucha EVENT_EFFECT_CHANGED con filtro por unidad (el juego descarta en C los
-- efectos de enemigos, mascotas, etc. antes de llegar a Lua) y solo mientras el panel
-- está visible. El evento trae el ID, el nombre y la ranura (effectSlot) del efecto, así
-- que el estado se actualiza directamente, sin preguntar al juego: cada aplicación de un
-- bufo es una ranura, y el bufo sigue activo mientras le quede alguna (dos jugadores
-- dando Major Courage, por ejemplo). La unidad entera solo se relee con GetUnitBuffInfo
-- al mostrar el panel, al cambiar el grupo o al volver a estar cerca.

local VG = Vigilant
local U = VG.Utils
local T = {
    units = {},       -- miembros en orden de pantalla: { tag, name, account, role, isPlayer, reachable }
    unitByTag = {},
    columns = {},     -- bufos seguidos (ver Catalog.GetColumns)
    colByKey = {},
    -- [unitTag][clave del bufo] = { slots = { [ranura] = fin }, max = fin más lejano }
    -- (fin en segundos de GetFrameTimeSeconds)
    state = {},
    dirty = {},       -- [unitTag] = true: releer sus bufos en el próximo tick del panel
    allDirty = true,
    unitsDirty = true,
}
VG.Tracker = T

local EM = EVENT_MANAGER
local EVT_GROUP = VG.name .. "_EffectsGroup"
local EVT_PLAYER = VG.name .. "_EffectsPlayer"
local EVT_UNITS = VG.name .. "_Units"

-- Bufos sin duración (auras, pasivas): activos hasta que el juego diga que se fueron.
local INFINITE = math.huge
T.INFINITE = INFINITE

local byId, byName = {}, {}

local function Match(abilityId, name)
    return byId[abilityId] or byName[U.NormName(name)]
end

local function EndOf(beginTime, endTime)
    if endTime <= beginTime then return INFINITE end
    return endTime
end

local function UpdateMax(entry)
    local max
    for _, e in pairs(entry.slots) do
        if not max or e > max then max = e end
    end
    entry.max = max
end

local function SetSlot(tag, key, slot, endTime)
    local s = T.state[tag]
    if not s then
        s = {}
        T.state[tag] = s
    end
    local entry = s[key]
    if not entry then
        entry = { slots = {} }
        s[key] = entry
    end
    entry.slots[slot] = endTime
    UpdateMax(entry)
end

-- Devuelve false si esa ranura no estaba apuntada (entonces conviene releer la unidad).
local function ClearSlot(tag, key, slot)
    local s = T.state[tag]
    local entry = s and s[key]
    if not entry or not entry.slots[slot] then return false end
    entry.slots[slot] = nil
    UpdateMax(entry)
    return true
end

local function LearnIcon(key, icon)
    local col = T.colByKey[key]
    if col.custom and VG.Catalog.LearnIcon(key, icon) then
        col.icon = icon
        VG.Panel.layoutDirty = true
    end
end

---------------------------------------------------------------------------
-- Columnas
---------------------------------------------------------------------------
function T.RebuildColumns()
    T.columns = VG.Catalog.GetColumns()
    ZO_ClearTable(T.colByKey)
    ZO_ClearTable(byId)
    ZO_ClearTable(byName)
    -- Si dos columnas comparten ID o nombre, se queda con la primera.
    for _, col in ipairs(T.columns) do
        T.colByKey[col.key] = col
        for _, id in ipairs(col.ids) do
            if byId[id] == nil then byId[id] = col.key end
        end
        if not col.exact then
            for name in pairs(col.names) do
                if byName[name] == nil then byName[name] = col.key end
            end
        end
    end
    T.allDirty = true
end

---------------------------------------------------------------------------
-- Miembros
---------------------------------------------------------------------------
local ROLE_ORDER = {
    [LFG_ROLE_TANK] = 1,
    [LFG_ROLE_HEAL] = 2,
    [LFG_ROLE_DPS] = 3,
}

local function UnitRole(tag)
    if IsUnitGrouped("player") then
        return GetGroupMemberSelectedRole(tag)
    end
    return GetSelectedLFGRole()
end

local function CompareUnits(a, b)
    local ra, rb = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
    if ra ~= rb then return ra < rb end
    return a.name < b.name
end

-- Online y lo bastante cerca para que el juego envíe sus efectos. Se pregunta al juego
-- una vez por tick (ver RefreshReachable), no en cada celda.
local function Reachable(u)
    return u.isPlayer or (IsUnitOnline(u.tag) and IsUnitInGroupSupportRange(u.tag))
end

function T.RefreshReachable()
    for _, u in ipairs(T.units) do u.reachable = Reachable(u) end
end

function T.IsReachable(u)
    return u.reachable
end

function T.RebuildUnits()
    T.unitsDirty = false
    local units = {}
    if IsUnitGrouped("player") then
        for i = 1, GetGroupSize() do
            local tag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(tag) then units[#units + 1] = { tag = tag } end
        end
    end
    -- Solo, o justo al cambiar de zona cuando el grupo aún no está cargado.
    if #units == 0 then units[1] = { tag = "player" } end

    T.playerTag = "player"
    ZO_ClearTable(T.unitByTag)
    for _, u in ipairs(units) do
        u.isPlayer = AreUnitsEqual(u.tag, "player")
        u.name = U.UnitName(u.tag)
        u.account = GetUnitDisplayName(u.tag)
        u.role = UnitRole(u.tag)
        u.reachable = Reachable(u)
        if u.isPlayer then T.playerTag = u.tag end
        T.unitByTag[u.tag] = u
    end
    if VG.sv.sortByRole then table.sort(units, CompareUnits) end
    T.units = units

    -- Las etiquetas (group1, group2...) se reasignan al cambiar el grupo: se relee todo.
    for tag in pairs(T.state) do
        if not T.unitByTag[tag] then T.state[tag] = nil end
    end
    T.allDirty = true
end

---------------------------------------------------------------------------
-- Efectos
---------------------------------------------------------------------------
local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, _, iconName, _, _, _, _, _, _, abilityId)
    local key = Match(abilityId, effectName)
    if not key then return end
    -- Los efectos propios llegan como "player"; en grupo se guardan con tu etiqueta groupN.
    if unitTag == "player" then unitTag = T.playerTag end
    -- El filtro "group" también deja pasar a los compañeros (groupcompanionN) y no hay
    -- filtro que los excluya: se descartan aquí, junto con las etiquetas ya caducadas.
    if not T.unitByTag[unitTag] then return end

    if changeType == EFFECT_RESULT_FADED then
        -- Por seguridad: si no se conocía esa ranura, se relee la unidad en el próximo tick.
        if not ClearSlot(unitTag, key, effectSlot) then T.dirty[unitTag] = true end
    else
        SetSlot(unitTag, key, effectSlot, EndOf(beginTime, endTime))
        LearnIcon(key, iconName)
    end
end

local function Rescan(tag)
    local s = T.state[tag]
    if s then ZO_ClearTable(s) end
    if not DoesUnitExist(tag) then return end
    for i = 1, GetNumBuffs(tag) do
        local name, beginTime, endTime, buffSlot, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo(tag, i)
        local key = Match(abilityId, name)
        if key then
            SetSlot(tag, key, buffSlot, EndOf(beginTime, endTime))
            LearnIcon(key, icon)
        end
    end
end

-- Lo llama el panel en cada tick: relee las unidades marcadas (normalmente ninguna).
function T.ProcessDirty()
    if T.allDirty then
        T.allDirty = false
        for _, u in ipairs(T.units) do T.dirty[u.tag] = true end
    end
    for tag in pairs(T.dirty) do
        T.dirty[tag] = nil
        Rescan(tag)
    end
end

-- Segundos restantes (INFINITE si no tiene duración) o nil si no lo tiene.
function T.Remaining(tag, key, now)
    local s = T.state[tag]
    local entry = s and s[key]
    local e = entry and entry.max
    if not e then return nil end
    if e == INFINITE then return INFINITE end
    local rem = e - now
    if rem <= 0 then return nil end
    return rem
end

-- Los eventos de efectos solo se escuchan mientras el panel está visible. Al volver a
-- mostrarlo se relee todo, porque lo ocurrido mientras tanto no se ha visto.
function T.Enable(enabled)
    if enabled == T.enabled then return end
    T.enabled = enabled
    if enabled then
        EM:RegisterForEvent(EVT_GROUP, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EM:AddFilterForEvent(EVT_GROUP, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
        EM:RegisterForEvent(EVT_PLAYER, EVENT_EFFECT_CHANGED, OnEffectChanged)
        EM:AddFilterForEvent(EVT_PLAYER, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        T.allDirty = true
    else
        EM:UnregisterForEvent(EVT_GROUP, EVENT_EFFECT_CHANGED)
        EM:UnregisterForEvent(EVT_PLAYER, EVENT_EFFECT_CHANGED)
    end
end

---------------------------------------------------------------------------
-- Uptime: qué parte del combate ha tenido cada miembro cada bufo. Solo cuenta mientras
-- estás en combate y el miembro está cerca (lejos no se sabe si lo tiene).
-- Según VG.sv.uptimeScope:
--   "fight": se pone a cero al empezar cada combate; fuera de combate se ve el del último.
--   "run":   se suman todos los combates (p. ej. una mazmorra entera) hasta cambiar de
--            zona o ponerlo a cero a mano.
-- uptime.members[nombre] = { present = segundos, active = { [clave] = segundos } }
---------------------------------------------------------------------------
local MAX_STEP = 2   -- huecos mayores (pantallas de carga, tirones) no cuentan

-- version sube cada vez que cambian los datos: el panel solo rehace los textos entonces.
T.uptime = { members = {}, duration = 0, version = 0 }

function T.ResetUptime()
    local up = T.uptime
    ZO_ClearTable(up.members)
    up.duration, up.last = 0, nil
    up.version = up.version + 1
end

function T.UpdateUptime(now)
    local up = T.uptime
    if not IsUnitInCombat("player") then
        up.inCombat, up.last = false, nil
        return
    end
    if not up.inCombat then
        up.inCombat = true
        if VG.sv.uptimeScope == "fight" then T.ResetUptime() end
    end
    local last = up.last
    up.last = now
    if not last then return end
    local dt = now - last
    if dt <= 0 or dt > MAX_STEP then return end
    up.duration = up.duration + dt
    up.version = up.version + 1

    for _, u in ipairs(T.units) do
        if T.IsReachable(u) then
            local m = up.members[u.name]
            if not m then
                m = { present = 0, active = {} }
                up.members[u.name] = m
            end
            m.present = m.present + dt
            for _, col in ipairs(T.columns) do
                if T.Remaining(u.tag, col.key, now) then
                    m.active[col.key] = (m.active[col.key] or 0) + dt
                end
            end
        end
    end
end

-- 0..1 de todo el grupo (tiempo con el bufo / tiempo cerca, sumando miembros), o nil
-- si todavía no ha habido combate.
function T.GroupUptime(key)
    local active, present = 0, 0
    for _, m in pairs(T.uptime.members) do
        active = active + (m.active[key] or 0)
        present = present + m.present
    end
    if present <= 0 then return nil end
    return active / present
end

-- 0..1 de un miembro, o nil si no ha estado cerca en el combate.
function T.MemberUptime(name, key)
    local m = T.uptime.members[name]
    if not m or m.present <= 0 then return nil end
    return (m.active[key] or 0) / m.present
end

---------------------------------------------------------------------------
-- Cambios de grupo
---------------------------------------------------------------------------
local function OnGroupChanged()
    T.unitsDirty = true
    VG.Panel.UpdateVisibility()
end

-- Al volver a estar cerca se relee: lo que pasó lejos no ha llegado.
local function OnSupportRange(_, unitTag, inRange)
    if inRange and T.unitByTag[unitTag] then T.dirty[unitTag] = true end
end

-- Con el uptime por "run", cambiar de zona (salir de la mazmorra, ir a otra) empieza
-- otra. Las pantallas de carga dentro de la misma zona no cuentan.
local function OnPlayerActivated()
    local zoneId = GetUnitWorldPosition("player")
    if T.zoneId and zoneId ~= T.zoneId and VG.sv.uptimeScope == "run" then T.ResetUptime() end
    T.zoneId = zoneId
end

function T.Init()
    T.RebuildColumns()
    EM:RegisterForEvent(VG.name .. "_Zone", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    for _, event in ipairs({
        EVENT_GROUP_MEMBER_JOINED,
        EVENT_GROUP_MEMBER_LEFT,
        EVENT_GROUP_UPDATE,
        EVENT_GROUP_MEMBER_ROLE_CHANGED,
        EVENT_GROUP_MEMBER_CONNECTED_STATUS,
        EVENT_PLAYER_ACTIVATED,
    }) do
        EM:RegisterForEvent(EVT_UNITS, event, OnGroupChanged)
    end
    for _, event in ipairs({ EVENT_UNIT_CREATED, EVENT_UNIT_DESTROYED }) do
        EM:RegisterForEvent(EVT_UNITS, event, OnGroupChanged)
        EM:AddFilterForEvent(EVT_UNITS, event, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    end
    EM:RegisterForEvent(EVT_UNITS, EVENT_GROUP_SUPPORT_RANGE_UPDATE, OnSupportRange)
    EM:AddFilterForEvent(EVT_UNITS, EVENT_GROUP_SUPPORT_RANGE_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
end
