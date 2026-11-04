-- Catálogo de bufos de grupo y bufos añadidos a mano.
-- Un mismo bufo (p. ej. Major Courage) tiene muchos IDs según la habilidad o el set que
-- lo da, pero todos se llaman igual. Por eso los del catálogo se reconocen por el nombre,
-- sacado del primer ID en el idioma del cliente, además de por los IDs de la lista.
-- 'en' es solo de referencia: lo usa /vigilant check para avisar si un ID ya no corresponde.

local VG = Vigilant
local U = VG.Utils
local L = VG.L
local C = { iconCache = {} }
VG.Catalog = C

C.NO_ICON = "/esoui/art/icons/icon_missing.dds"

C.CATEGORIES = {
    { key = "offense", label = "CAT_OFFENSE" },
    { key = "defense", label = "CAT_DEFENSE" },
    { key = "resources", label = "CAT_RESOURCES" },
    { key = "sets", label = "CAT_SETS" },
}

-- on = activado por defecto
C.BUFFS = {
    -- Ofensivos
    { key = "majorCourage",    cat = "offense", ids = { 109966, 66902, 109994, 110020, 120015 }, en = "Major Courage", on = true },
    { key = "minorCourage",    cat = "offense", ids = { 147417, 121878 }, en = "Minor Courage", on = true },
    { key = "majorForce",      cat = "offense", ids = { 61747, 40225 }, en = "Major Force", on = true },
    { key = "minorForce",      cat = "offense", ids = { 61746 }, en = "Minor Force" },
    { key = "majorSlayer",     cat = "offense", ids = { 93109, 93120, 135923, 137986, 121871 }, en = "Major Slayer", on = true },
    { key = "minorSlayer",     cat = "offense", ids = { 76617, 147226 }, en = "Minor Slayer" },
    { key = "majorBerserk",    cat = "offense", ids = { 61745 }, en = "Major Berserk", on = true },
    { key = "minorBerserk",    cat = "offense", ids = { 61744 }, en = "Minor Berserk", on = true },
    { key = "majorBrutality",  cat = "offense", ids = { 61665, 76518 }, en = "Major Brutality" },
    { key = "minorBrutality",  cat = "offense", ids = { 61662 }, en = "Minor Brutality" },
    { key = "majorSorcery",    cat = "offense", ids = { 61687, 92503 }, en = "Major Sorcery" },
    { key = "minorSorcery",    cat = "offense", ids = { 61685 }, en = "Minor Sorcery" },
    { key = "majorProphecy",   cat = "offense", ids = { 61689 }, en = "Major Prophecy" },
    { key = "minorProphecy",   cat = "offense", ids = { 61691 }, en = "Minor Prophecy" },
    { key = "majorSavagery",   cat = "offense", ids = { 61667 }, en = "Major Savagery" },
    { key = "minorSavagery",   cat = "offense", ids = { 61666 }, en = "Minor Savagery" },
    { key = "empower",         cat = "offense", ids = { 61737 }, en = "Empower" },
    { key = "powerfulAssault", cat = "offense", ids = { 61771 }, en = "Powerful Assault", on = true },

    -- Defensivos
    { key = "majorResolve",    cat = "defense", ids = { 61694, 88758 }, en = "Major Resolve", on = true },
    { key = "minorResolve",    cat = "defense", ids = { 61693 }, en = "Minor Resolve" },
    { key = "majorProtection", cat = "defense", ids = { 61722 }, en = "Major Protection" },
    { key = "minorProtection", cat = "defense", ids = { 61721 }, en = "Minor Protection" },
    { key = "minorToughness",  cat = "defense", ids = { 88490 }, en = "Minor Toughness" },
    { key = "majorVitality",   cat = "defense", ids = { 61713 }, en = "Major Vitality" },
    { key = "minorVitality",   cat = "defense", ids = { 61549 }, en = "Minor Vitality" },
    { key = "majorMending",    cat = "defense", ids = { 61711 }, en = "Major Mending" },
    { key = "minorMending",    cat = "defense", ids = { 61710 }, en = "Minor Mending" },
    { key = "majorEvasion",    cat = "defense", ids = { 61716 }, en = "Major Evasion" },
    { key = "minorEvasion",    cat = "defense", ids = { 61715 }, en = "Minor Evasion" },
    { key = "majorAegis",      cat = "defense", ids = { 93123 }, en = "Major Aegis" },
    { key = "minorAegis",      cat = "defense", ids = { 147225 }, en = "Minor Aegis" },

    -- Recursos y movilidad
    { key = "majorIntellect",  cat = "resources", ids = { 61707 }, en = "Major Intellect" },
    { key = "minorIntellect",  cat = "resources", ids = { 61706 }, en = "Minor Intellect" },
    { key = "majorEndurance",  cat = "resources", ids = { 61705 }, en = "Major Endurance" },
    { key = "minorEndurance",  cat = "resources", ids = { 61704 }, en = "Minor Endurance" },
    { key = "majorFortitude",  cat = "resources", ids = { 61698 }, en = "Major Fortitude" },
    { key = "minorFortitude",  cat = "resources", ids = { 61697 }, en = "Minor Fortitude" },
    { key = "majorHeroism",    cat = "resources", ids = { 61709 }, en = "Major Heroism" },
    { key = "minorHeroism",    cat = "resources", ids = { 61708 }, en = "Minor Heroism" },
    { key = "majorExpedition", cat = "resources", ids = { 61736 }, en = "Major Expedition" },
    { key = "minorExpedition", cat = "resources", ids = { 61735 }, en = "Minor Expedition" },

    -- Sets y definitivas
    { key = "warHorn",         cat = "sets", ids = { 38564, 40224, 40221 }, en = "War Horn" },
    { key = "pearlescentWard", cat = "sets", ids = { 172621 }, en = "Pearlescent Ward" },
    { key = "jorvuld",         cat = "sets", ids = { 101978 }, en = "Jorvuld's Guidance" },
}

local byKey = {}

function C.Get(key)
    return byKey[key]
end

-- Nombre e icono en el idioma del cliente, y el conjunto de nombres de todos sus IDs.
local function Resolve(b)
    b.names = {}
    for _, id in ipairs(b.ids) do
        local name = U.AbilityName(id)
        if name then
            b.name = b.name or name
            b.names[U.NormName(name)] = true
            if not b.icon then
                local icon = GetAbilityIcon(id)
                if icon ~= "" then b.icon = icon end
            end
        end
    end
    b.name = b.name or b.en
    b.icon = b.icon or C.NO_ICON
end

function C.IsTracked(key)
    local v = VG.sv.tracked[key]
    if v == nil then return byKey[key].on == true end
    return v
end

function C.SetTracked(key, value)
    VG.sv.tracked[key] = value
    C.Changed()
end

-- Vuelve a los bufos activados por defecto (value = nil) o los desactiva todos (false).
function C.SetAll(value)
    for _, b in ipairs(C.BUFFS) do VG.sv.tracked[b.key] = value end
    C.Changed()
end


---------------------------------------------------------------------------
-- Bufos añadidos a mano (desde el catálogo de todos los efectos o con /vigilant add)
---------------------------------------------------------------------------
local function CustomKey(entry)
    if entry.id then return "id:" .. entry.id end
    return "name:" .. U.NormName(entry.name)
end

-- Columna para un bufo añadido a mano. Por nombre (lo normal, desde el catálogo) cuenta
-- cualquier variante; por ID (solo con /vigilant add <id>) únicamente ese efecto exacto,
-- para distinguir p. ej. el Major Slayer de un set concreto.
-- entry.icon es el ID de habilidad del que se saca el icono.
local function CustomColumn(entry)
    local key = CustomKey(entry)
    local col = { key = key, custom = true }
    if entry.id then
        col.ids = { entry.id }
        col.exact = true
        col.name = U.AbilityName(entry.id) or ("#" .. entry.id)
        col.icon = GetAbilityIcon(entry.id)
    else
        col.ids = {}
        col.names = { [U.NormName(entry.name)] = true }
        col.name = entry.name
        -- Sin icono guardado se usa el primero que se vea en el juego.
        col.icon = entry.icon and GetAbilityIcon(entry.icon) or C.iconCache[key] or C.NO_ICON
    end
    return col
end

function C.CustomLabel(entry)
    if entry.id then
        return string.format("%s (%d)", U.AbilityName(entry.id) or "?", entry.id)
    end
    return entry.name
end

local function FindCustom(key)
    for i, entry in ipairs(VG.sv.custom) do
        if CustomKey(entry) == key then return i end
    end
end

local function CatalogBuffByName(norm)
    for _, b in ipairs(C.BUFFS) do
        if b.names[norm] then return b end
    end
end

-- ¿Se sigue ya un efecto con este nombre (de la lista de comunes o añadido a mano)?
function C.IsNameTracked(name)
    local norm = U.NormName(name)
    local b = CatalogBuffByName(norm)
    if b then return C.IsTracked(b.key) end
    return FindCustom("name:" .. norm) ~= nil
end

-- Por nombre, con el ID del que sacar el icono (el catálogo de efectos lo sabe).
-- Si es uno de los bufos comunes, se activa ese en vez de duplicarlo.
function C.AddByName(name, iconId)
    local norm = U.NormName(name)
    local b = CatalogBuffByName(norm)
    if b then
        C.SetTracked(b.key, true)
        return
    end
    if FindCustom("name:" .. norm) then return end
    table.insert(VG.sv.custom, { name = name, icon = iconId })
    C.Changed()
end

function C.RemoveByName(name)
    local norm = U.NormName(name)
    local b = CatalogBuffByName(norm)
    if b then
        C.SetTracked(b.key, false)
        return
    end
    local index = FindCustom("name:" .. norm)
    if index then
        table.remove(VG.sv.custom, index)
        C.Changed()
    end
end

-- /vigilant add: "12345" o el nombre del bufo.
function C.AddCustom(text)
    text = U.Trim(text)
    local id = tonumber(text)
    if not id then
        local wasTracked = C.IsNameTracked(text)
        C.AddByName(text)
        VG.Print(wasTracked and L.CUSTOM_EXISTS or L.CUSTOM_ADDED, text)
        return
    end
    if not U.AbilityName(id) then
        VG.Print(L.CUSTOM_BAD_ID, id)
        return
    end
    local entry = { id = id }
    if FindCustom(CustomKey(entry)) then
        VG.Print(L.CUSTOM_EXISTS, C.CustomLabel(entry))
        return
    end
    table.insert(VG.sv.custom, entry)
    VG.Print(L.CUSTOM_ADDED, C.CustomLabel(entry))
    C.Changed()
end

-- Por clave interna ("id:123", "name:..."), por número de la lista, por ID o por nombre.
function C.RemoveCustom(what)
    local custom = VG.sv.custom
    local index = FindCustom(what)
    if not index then
        local n = tonumber(what)
        if n and custom[n] then
            index = n
        elseif n then
            index = FindCustom("id:" .. n)
        else
            index = FindCustom("name:" .. U.NormName(U.Trim(what)))
        end
    end
    if not index then
        VG.Print(L.CUSTOM_NOT_FOUND, tostring(what))
        return
    end
    local entry = table.remove(custom, index)
    VG.Print(L.CUSTOM_REMOVED, C.CustomLabel(entry))
    C.Changed()
end

-- Clave interna de cada bufo añadido a mano, en el orden de la lista (para Ajustes).
function C.CustomKeys()
    local keys = {}
    for i, entry in ipairs(VG.sv.custom) do keys[i] = CustomKey(entry) end
    return keys
end

-- Icono visto en el juego para un bufo añadido por nombre sin icono guardado.
function C.LearnIcon(key, icon)
    if C.iconCache[key] or icon == "" then return false end
    C.iconCache[key] = icon
    return true
end

---------------------------------------------------------------------------
-- Columnas: bufos activados, en el orden que elija el jugador (VG.sv.order, lista de
-- claves). Los que no están en esa lista van detrás: primero los comunes en el orden
-- del catálogo y luego los añadidos a mano.
---------------------------------------------------------------------------
function C.GetColumns()
    local cols = {}
    for _, b in ipairs(C.BUFFS) do
        if C.IsTracked(b.key) then cols[#cols + 1] = b end
    end
    for _, entry in ipairs(VG.sv.custom) do
        cols[#cols + 1] = CustomColumn(entry)
    end

    local pos = {}
    for i, key in ipairs(VG.sv.order) do pos[key] = i end
    local fallback = {}
    for i, col in ipairs(cols) do fallback[col.key] = #VG.sv.order + i end
    table.sort(cols, function(a, b)
        return (pos[a.key] or fallback[a.key]) < (pos[b.key] or fallback[b.key])
    end)
    return cols
end

-- Sube (delta = -1) o baja (+1) un bufo seguido. Guarda el orden de todos los seguidos.
function C.Move(key, delta)
    local keys = {}
    local index
    for i, col in ipairs(VG.Tracker.columns) do
        keys[i] = col.key
        if col.key == key then index = i end
    end
    local target = index and index + delta
    if not target or target < 1 or target > #keys then return end
    keys[index], keys[target] = keys[target], keys[index]
    VG.sv.order = keys
    C.Changed()
end

function C.Changed()
    VG.Tracker.RebuildColumns()
    VG.Panel.Refresh()
    VG.Settings.RefreshCustomList()
    VG.Browser.OnTrackedChanged()
end

function C.Init()
    for _, b in ipairs(C.BUFFS) do
        byKey[b.key] = b
        Resolve(b)
    end
end
