-- Utilidades: parseo de texto, rutas en tablas, formato de tiempo y plantillas.

local OA = OmniAura
local U = {}
OA.Utils = U

local floor, ceil = math.floor, math.ceil

function U.Trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

function U.NonEmpty(s)
    if s == nil or s == "" then return nil end
    return s
end

-- "123" -> 123, "true" -> true, otro -> string
function U.ParseScalar(s)
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    if n then return n end
    return s
end

-- "a, 2, c" -> { "a", 2, "c" }
function U.CommaList(s)
    local out = {}
    for item in (s or ""):gmatch("[^,]+") do
        item = U.Trim(item)
        if item ~= "" then out[#out + 1] = U.ParseScalar(item) end
    end
    return out
end

-- Valor de un comando /omni set: "nil", lista con comas, "texto entre comillas" o escalar.
function U.ParseValue(s)
    s = U.Trim(s)
    if s == "" or s == "nil" then return nil end
    local quoted = s:match('^"(.*)"$')
    if quoted then return quoted end
    if s:find(",", 1, true) then return U.CommaList(s) end
    return U.ParseScalar(s)
end

local function PathKeys(path)
    local keys = {}
    for seg in (path or ""):gmatch("[^%.]+") do
        keys[#keys + 1] = tonumber(seg) or seg
    end
    return keys
end

function U.GetPath(tbl, path)
    local t = tbl
    for _, k in ipairs(PathKeys(path)) do
        if type(t) ~= "table" then return nil end
        t = t[k]
    end
    return t
end

-- SetPath(aura, "triggers.1.unit", "reticleover"), crea las tablas intermedias.
function U.SetPath(tbl, path, value)
    local keys = PathKeys(path)
    if #keys == 0 then return false end
    local t = tbl
    for i = 1, #keys - 1 do
        local k = keys[i]
        if t[k] == nil then t[k] = {} end
        if type(t[k]) ~= "table" then return false end
        t = t[k]
    end
    t[keys[#keys]] = value
    return true
end

function U.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = U.DeepCopy(v) end
    return out
end

local function IsScalarList(t)
    local n = #t
    if n == 0 then return false end
    local count = 0
    for _, v in pairs(t) do
        if type(v) == "table" then return false end
        count = count + 1
    end
    return count == n
end

function U.ValueToString(v)
    if type(v) == "table" then
        if next(v) == nil then return "" end
        if IsScalarList(v) then
            local parts = {}
            for i, item in ipairs(v) do parts[i] = tostring(item) end
            return table.concat(parts, ",")
        end
    end
    return tostring(v)
end

-- Convierte una tabla en líneas "ruta = valor" ordenadas.
function U.Flatten(tbl, prefix, out)
    out = out or {}
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = tbl[k]
        local p = prefix and (prefix .. "." .. tostring(k)) or tostring(k)
        if type(v) == "table" and not IsScalarList(v) then
            U.Flatten(v, p, out)
        else
            out[#out + 1] = p .. " = " .. U.ValueToString(v)
        end
    end
    return out
end

function U.FormatName(name)
    if not name or name == "" then return "" end
    return zo_strformat("<<1>>", name)
end

function U.AbilityName(abilityId)
    local name = GetAbilityName(abilityId)
    if name and name ~= "" then return U.FormatName(name) end
    return tostring(abilityId)
end

function U.AbilityIcon(abilityId)
    return U.NonEmpty(GetAbilityIcon(abilityId))
end

function U.FormatTime(sec)
    if not sec or sec <= 0 then return "" end
    if sec < 10 then return string.format("%.1f", sec) end
    if sec < 60 then return string.format("%d", ceil(sec)) end
    if sec < 3600 then return string.format("%d:%02d", floor(sec / 60), floor(sec % 60)) end
    return string.format("%dh", floor(sec / 3600))
end

function U.Remaining(state, now)
    if state.expires then return math.max(0, state.expires - now) end
    return nil
end

-- Progreso 0..1: explícito (recursos) o calculado a partir de la duración.
function U.Progress(state, now)
    if state.progress then return state.progress end
    if state.expires and state.duration and state.duration > 0 then
        return zo_clamp((state.expires - now) / state.duration, 0, 1)
    end
    return nil
end

function U.Color(c, default)
    c = c or default
    if type(c) ~= "table" then return 1, 1, 1, 1 end
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
end

-- Tokens disponibles en las plantillas de texto: {name} {aura} {time} {stacks} {value} {max} {percent}
local TOKENS = {
    name = function(s) return s.name end,
    aura = function(s) return s.auraName end,
    time = function(s, now) return U.FormatTime(U.Remaining(s, now)) end,
    stacks = function(s) return (s.stacks and s.stacks > 1) and tostring(s.stacks) or "" end,
    value = function(s) return s.value and tostring(floor(s.value)) end,
    max = function(s) return s.max and tostring(floor(s.max)) end,
    percent = function(s) return s.percent and string.format("%d", floor(s.percent * 100 + 0.5)) end,
}

function U.FormatTemplate(tpl, state, now)
    if not tpl or tpl == "" then return "" end
    return (tpl:gsub("{(%w+)}", function(key)
        local fn = TOKENS[key]
        if fn then return fn(state, now) or "" end
    end))
end
