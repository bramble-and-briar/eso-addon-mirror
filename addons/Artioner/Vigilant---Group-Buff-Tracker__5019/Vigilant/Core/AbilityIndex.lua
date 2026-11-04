-- Índice de todas las habilidades/efectos del juego (salvo pasivas) para buscarlos por
-- nombre en el catálogo, sin tener que saber su ID. El juego no ofrece una lista, así
-- que se recorren los IDs una vez (repartido entre fotogramas para no congelar el
-- juego) y se agrupan por nombre: todas las variantes de un bufo quedan juntas.
-- Se construye solo la primera vez que se abre el catálogo.

local VG = Vigilant
local U = VG.Utils

local A = { state = "idle", groups = {}, counts = {}, onProgress = {}, onDone = {} }
VG.AbilityIndex = A

local UPDATE_NAME = VG.name .. "_AbilityIndex"
local MAX_ID = 400000
local CHUNK = 2500             -- IDs por fotograma
local FINALIZE_CHUNK = 1500    -- grupos por fotograma al preparar nombres, iconos y categorías
local STOP_AFTER_EMPTY = 40000 -- tras este hueco sin habilidades (pasado MIN_ID) se da por terminado
local MIN_ID = 200000
local ICON_PROBES = 3
local PASSIVE_PROBES = 12

---------------------------------------------------------------------------
-- Categorías: se deducen del nombre del archivo del icono, que el juego
-- nombra por línea de habilidad (ability_dragonknight_..., ability_buff_major_...).
---------------------------------------------------------------------------
local CATEGORY_BY_TOKEN = {
    dragonknight = "dk", sorcerer = "sorc", nightblade = "nb", warden = "warden",
    necromancer = "necro", templar = "templar", arcanist = "arcanist",
    ["2handed"] = "weapon", ["1handed"] = "weapon", dualwield = "weapon", bow = "weapon",
    destructionstaff = "weapon", restorationstaff = "weapon",
    armor = "armor",
    fightersguild = "guild", mageguild = "guild", magesguild = "guild", undaunted = "guild",
    psijic = "guild", thievesguild = "guild", darkbrotherhood = "guild",
    vampire = "world", werewolf = "world", legerdemain = "world", soulmagic = "world", scrying = "world",
    ava = "ava",
    buff = "buff", debuff = "debuff",
    racial = "racial",
    mundusstones = "mundus", mundus = "mundus",
    companion = "companion",
}
local CATEGORY_BY_PREFIX = { gear = "gear", consumable = "consumable", food = "consumable", drink = "consumable" }

local function Categorize(icon)
    if not icon then return "other" end
    local file = zo_strlower(icon):match("([^/]+)%.dds$")
    if not file then return "other" end
    local prefix, rest = file:match("^(%a+)_(.*)$")
    if prefix == "ability" and rest then
        return CATEGORY_BY_TOKEN[rest:match("^([%a%d]+)") or ""] or "other"
    end
    return CATEGORY_BY_PREFIX[prefix or ""] or "other"
end

-- Las pasivas solo modifican estadísticas: nunca aparecen como efecto en una unidad,
-- así que no se ofrecen. Cualquier cosa con duración se conserva aunque el juego la
-- marque como pasiva (p. ej. el efecto temporal que pone una pasiva al activarse).
local function IsPassive(abilityId)
    return IsAbilityPassive(abilityId) and GetAbilityDuration(abilityId) <= 0
end

-- Un nombre se descarta solo si todas sus variantes comprobadas son pasivas.
local function IsPassiveGroup(ids)
    for k = 1, math.min(#ids, PASSIVE_PROBES) do
        if not IsPassive(ids[k]) then return false end
    end
    return true
end

local function IsRealIcon(icon)
    return icon ~= "" and not icon:find("icon_missing", 1, true)
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
function A.IsReady()
    return A.state == "ready"
end

local function Notify(list, ...)
    for _, fn in ipairs(list) do fn(...) end
end

local function Finish()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)

    -- Descarta nombres vacíos, pasivas y efectos sin icono (un bufo siempre tiene icono),
    -- ordena alfabéticamente y cuenta por categoría.
    local kept, counts = {}, { all = 0 }
    for _, g in ipairs(A.groups) do
        if g.display ~= "" and not g.passive and g.icon then
            kept[#kept + 1] = g
            counts[g.cat] = (counts[g.cat] or 0) + 1
            counts.all = counts.all + 1
        end
    end
    table.sort(kept, function(a, b) return a.lname < b.lname end)
    A.groups, A.counts, A.byName = kept, counts, nil

    A.state = "ready"
    local done = A.onDone
    A.onProgress, A.onDone = {}, {}
    Notify(done)
end

local function FinalizeStep()
    local groups = A.groups
    local last = math.min(A.finalizeIndex + FINALIZE_CHUNK - 1, #groups)
    for i = A.finalizeIndex, last do
        local g = groups[i]
        g.display = U.FormatAbility(g.raw)
        g.lname = zo_strlower(g.display)
        g.raw = nil
        g.passive = IsPassiveGroup(g.ids)
        for k = 1, math.min(#g.ids, ICON_PROBES) do
            local icon = GetAbilityIcon(g.ids[k])
            if IsRealIcon(icon) then
                g.icon, g.iconId = icon, g.ids[k]
                break
            end
        end
        g.cat = Categorize(g.icon)
    end
    A.finalizeIndex = last + 1
    Notify(A.onProgress, 0.8 + 0.2 * (last / math.max(1, #groups)))
    if last >= #groups then Finish() end
end

local function ScanStep()
    local first = A.nextId
    local last = math.min(first + CHUNK - 1, MAX_ID)
    local byName, groups = A.byName, A.groups
    for id = first, last do
        local raw = GetAbilityName(id)
        if raw ~= "" then
            local g = byName[raw]
            if not g then
                g = { raw = raw, ids = {} }
                byName[raw] = g
                groups[#groups + 1] = g
            end
            g.ids[#g.ids + 1] = id
            A.lastFound = id
        end
    end
    A.nextId = last + 1

    local done = last >= MAX_ID or (last > MIN_ID and last - A.lastFound > STOP_AFTER_EMPTY)
    Notify(A.onProgress, 0.8 * math.min(1, last / (A.lastFound + STOP_AFTER_EMPTY)))
    if done then
        A.finalizeIndex = 1
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, FinalizeStep)
    end
end

-- onProgress(fracción 0..1) y onDone() pueden ser nil; varios llamantes pueden esperar a la vez.
function A.Build(onProgress, onDone)
    if A.state == "ready" then
        if onDone then onDone() end
        return
    end
    if onProgress then table.insert(A.onProgress, onProgress) end
    if onDone then table.insert(A.onDone, onDone) end
    if A.state == "building" then return end

    A.state = "building"
    A.groups, A.byName = {}, {}
    A.nextId, A.lastFound = 1, 0
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, ScanStep)
end

-- El índice ocupa bastante memoria (decenas de miles de nombres): el catálogo lo suelta
-- cuando lleva un rato cerrado y se vuelve a crear si se abre otra vez.
function A.Release()
    if A.state ~= "ready" then return end
    A.state, A.groups, A.counts = "idle", {}, {}
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------

-- Categoría ("all" = todas) y texto a buscar.
function A.Filter(category, query)
    local q = zo_strlower(U.Trim(query))
    local out = {}
    for _, g in ipairs(A.groups) do
        if (category == "all" or g.cat == category) and (q == "" or g.lname:find(q, 1, true)) then
            out[#out + 1] = g
        end
    end
    return out
end

-- Efectos que tienen ahora tú y los miembros del grupo, agrupados por nombre como los
-- del índice. Sirve para añadir un proc justo después de verlo, sin buscarlo.
function A.Active(query)
    local q = zo_strlower(U.Trim(query))
    local byName, out = {}, {}
    local T = VG.Tracker
    if T.unitsDirty then T.RebuildUnits() end
    for _, u in ipairs(T.units) do
        for i = 1, GetNumBuffs(u.tag) do
            local name, _, _, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo(u.tag, i)
            local display = U.FormatAbility(name)
            local g = byName[display]
            if not g then
                g = { display = display, lname = zo_strlower(display), ids = {}, icon = icon, iconId = abilityId }
                byName[display] = g
                if display ~= "" and (q == "" or g.lname:find(q, 1, true)) then out[#out + 1] = g end
            end
            g.ids[#g.ids + 1] = abilityId
        end
    end
    table.sort(out, function(a, b) return a.lname < b.lname end)
    return out
end
