local PE = PrismaticEmotes
PE.Palette = {}
local Palette = PE.Palette

-- Brighter-than-default hues selected for readability on ESO's dark chat background.
-- They are not guaranteed perceptually distinct for all forms of color vision.
Palette.colors = {
    "E9A3FF", "76DCEB", "FFBB78", "A5E786", "FF90B3", "A6A9FF",
    "F5D96A", "79DAB9", "E69BBD", "91C5FF", "D5BB7B", "BDA1F3",
    "78E0CE", "FF9F81", "C5E58A", "F7A6DD", "7EC9E6", "EFC47F",
    "9CDAA4", "FFAB9D", "C4B1FF", "F0D692", "82DED8", "DD9EE8",
    "B7DE7D", "FD9DC4", "8EC9FA", "DAC48D", "9AE2B1", "E7A9A2",
    "A9BDF5", "EEB6DF", "BCE4A1", "FFBE9B", "90D9F0", "CEC0FF",
}

local cachedEntries = nil

local function invalidateCache()
    cachedEntries = nil
end

function Palette.CleanName(name)
    if type(name) ~= "string" then
        return nil
    end
    local cleaned = name:match("^%s*(.-)%s*$")
    if type(zo_strformat) == "function" then
        cleaned = zo_strformat("<<1>>", cleaned)
    end
    -- Also handle offline tests and lowercased grammar tags in old saved keys.
    cleaned = cleaned:gsub("%^[mMfFnN][xX]?$", ""):match("^%s*(.-)%s*$")
    if cleaned == "" then
        return nil
    end
    return cleaned
end

function Palette.NormalizeName(name)
    local cleaned = Palette.CleanName(name)
    return cleaned and string.lower(cleaned)
end

local function isManual(entry)
    return type(entry) == "table" and entry.automatic ~= nil
        and entry.color ~= entry.automatic
end

function Palette.MigrateSavedNames()
    if not PE.saved or type(PE.saved.characters) ~= "table" then
        return
    end
    local characters = PE.saved.characters
    local keys = {}
    for key, entry in pairs(characters) do
        if type(key) == "string" and type(entry) == "table" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)

    for _, oldKey in ipairs(keys) do
        local entry = characters[oldKey]
        local key = Palette.NormalizeName(oldKey)
        if key then
            entry.name = Palette.CleanName(entry.name) or Palette.CleanName(oldKey)
            if key ~= oldKey then
                local existing = characters[key]
                -- Keep manual overrides; the canonical entry wins ties.
                if type(existing) ~= "table" or
                    (isManual(entry) and not isManual(existing)) then
                    characters[key] = entry
                end
                characters[oldKey] = nil
            end
        end
    end
    invalidateCache()
end

local function hashName(name)
    local hash = 5381
    for i = 1, #name do
        hash = (hash * 33 + name:byte(i)) % 2147483647
    end
    return hash
end

local function usedColors()
    local used = {}
    for _, entry in pairs(PE.saved.characters) do
        if type(entry) == "table" and type(entry.color) == "string" then
            used[entry.color] = true
        end
    end
    return used
end

local function hsvToHex(hue, saturation, value)
    local sector = math.floor(hue * 6)
    local fraction = hue * 6 - sector
    local p = value * (1 - saturation)
    local q = value * (1 - fraction * saturation)
    local t = value * (1 - (1 - fraction) * saturation)
    local r, g, b
    local h = sector % 6
    if h == 0 then r, g, b = value, t, p
    elseif h == 1 then r, g, b = q, value, p
    elseif h == 2 then r, g, b = p, value, t
    elseif h == 3 then r, g, b = p, q, value
    elseif h == 4 then r, g, b = t, p, value
    else r, g, b = value, p, q end
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function selectColor(key)
    local used = usedColors()
    local hash = hashName(key)
    local start = hash % #Palette.colors

    for offset = 0, #Palette.colors - 1 do
        local color = Palette.colors[((start + offset) % #Palette.colors) + 1]
        if not used[color] then
            return color
        end
    end

    -- After the curated palette is exhausted, generate additional pastel colors.
    -- Collision avoidance is exact (RGB), not guaranteed visually distinct.
    for offset = 0, 8191 do
        local hue = ((hash * 0.0000001 + offset * 0.618033988749895) % 1)
        local color = hsvToHex(hue, 0.40 + ((hash + offset) % 4) * 0.06, 0.96)
        if not used[color] then
            return color
        end
    end
    return Palette.colors[start + 1]
end

function Palette.GetOrAssign(name)
    local key = Palette.NormalizeName(name)
    if not key or not PE.saved then
        return nil
    end

    local existing = PE.saved.characters[key]
    if type(existing) == "table" and type(existing.color) == "string"
        and existing.color:match("^%x%x%x%x%x%x$") then
        return existing.color
    end

    local color = selectColor(key)
    PE.saved.characters[key] = { name = Palette.CleanName(name), color = color, automatic = color }
    invalidateCache()
    return color
end

function Palette.SetOverride(name, color)
    local key = Palette.NormalizeName(name)
    if not key or type(color) ~= "string" then
        return false
    end
    color = color:gsub("^#", ""):upper()
    if not color:match("^%x%x%x%x%x%x$") then
        return false
    end
    Palette.GetOrAssign(name)
    local entry = PE.saved.characters[key]
    entry.automatic = entry.automatic or entry.color
    entry.color = color
    invalidateCache()
    return true
end

function Palette.ClearOverride(name)
    local key = Palette.NormalizeName(name)
    local entry = key and PE.saved.characters[key]
    if not entry then
        return false
    end
    entry.color = entry.automatic or entry.color
    invalidateCache()
    return true
end

function Palette.Forget(name)
    local key = Palette.NormalizeName(name)
    if not key or PE.saved.characters[key] == nil then
        return false
    end
    PE.saved.characters[key] = nil
    invalidateCache()
    return true
end

function Palette.ForgetAll()
    PE.saved.characters = {}
    invalidateCache()
end

function Palette.List()
    local rows = {}
    for key, entry in pairs(PE.saved.characters) do
        if type(entry) == "table" and type(entry.color) == "string" then
            rows[#rows + 1] = { key = key, name = entry.name or key, color = entry.color,
                manual = isManual(entry) }
        end
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rows
end

function Palette.MentionEntries()
    if cachedEntries then
        return cachedEntries
    end
    local entries, fullNames, firstNames = {}, {}, {}
    for key, entry in pairs(PE.saved.characters) do
        if type(key) == "string" and type(entry) == "table" and type(entry.color) == "string" then
            fullNames[key] = true
            if #key >= 3 then
                entries[#entries + 1] = { key = key, color = entry.color }
            end
            local firstName = key:match("^([^ ]+) +[^ ]")
            if firstName then
                if firstNames[firstName] == nil then
                    firstNames[firstName] = entry.color
                else
                    -- false marks a shared first name, even when colors happen to match.
                    firstNames[firstName] = false
                end
            end
        end
    end
    for firstName, hex in pairs(firstNames) do
        if hex and not fullNames[firstName] then
            entries[#entries + 1] = { key = firstName, color = hex, firstName = true }
        end
    end
    table.sort(entries, function(a, b)
        if #a.key ~= #b.key then
            return #a.key > #b.key
        end
        return a.key < b.key
    end)
    cachedEntries = entries
    return entries
end
