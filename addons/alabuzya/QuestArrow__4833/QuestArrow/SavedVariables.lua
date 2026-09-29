-- Server profiles isolate EU, NA and PTS; legacy Default is retained for rollback.
local A = QuestArrow
A.SavedVariables = {}
local S = A.SavedVariables
local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
local function Open(character, namespace, defaults)
    local profile = GetWorldName()
    assert(type(profile) == 'string' and profile ~= '', 'Missing ESO server name')
    local name = 'QuestArrowSavedVariables'
    local raw = _G[name]
    local account = GetDisplayName()
    local key = character and GetCurrentCharacterId() or '$AccountWide'
    -- Read raw tables, never a ZO_SavedVars proxy (which includes metatables).
    local legacy = raw and raw.Default and raw.Default[account] and raw.Default[account][key]
    if namespace then legacy = legacy and legacy[namespace] end
    if type(legacy) == 'table' then
        raw[profile] = raw[profile] or {}
        raw[profile][account] = raw[profile][account] or {}
        local parent = raw[profile][account]
        local entry = key
        if namespace then
            parent[key] = parent[key] or {}
            parent = parent[key]
            entry = namespace
        end
        -- An existing server-specific entry always wins, including false/zero values.
        if parent[entry] == nil then parent[entry] = Copy(legacy) end
    end
    if character then
        return ZO_SavedVars:NewCharacterIdSettings(name, 1, namespace, defaults, profile)
    end
    return ZO_SavedVars:NewAccountWide(name, 1, namespace, defaults, profile)
end
function S.Account(namespace, defaults) return Open(false, namespace, defaults) end
function S.Character(namespace, defaults) return Open(true, namespace, defaults) end
