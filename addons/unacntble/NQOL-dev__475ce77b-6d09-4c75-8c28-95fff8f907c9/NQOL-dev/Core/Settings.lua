NQOL = NQOL or {}

local Settings = {}

Settings.SAVED_VARIABLES_NAME = "NQOLSavedVariablesDev"
Settings.savedVariableScopes = {}

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, childValue in pairs(value) do
        copy[key] = CopyValue(childValue)
    end

    return copy
end

local function IsEmptyTable(value)
    if type(value) ~= "table" then
        return false
    end

    return next(value) == nil
end

local function MergeValue(target, defaults)
    if type(defaults) ~= "table" then
        return CopyValue(defaults)
    end

    if IsEmptyTable(defaults) then
        return {}
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        target[key] = MergeValue(target[key], value)
    end

    return target
end

local function HasDefaultPath(root, path)
    local current = root
    for index = 1, #path do
        if type(current) ~= "table" then
            return false
        end

        -- Empty default tables own their dynamic children too (for example
        -- per-panel scroll positions). Unrelated feature scopes do not.
        if next(current) == nil then return true end
        current = current[path[index]]
    end

    return current ~= nil
end

local function SetPath(root, path, value)
    if #path == 0 then
        return
    end

    local parent = root
    for index = 1, #path - 1 do
        local key = path[index]
        if type(parent[key]) ~= "table" then
            parent[key] = {}
        end

        parent = parent[key]
    end

    local key = path[#path]
    parent[key] = MergeValue(parent[key], value)
end

local function RemovePath(root, path)
    if type(root) ~= "table" or #path == 0 then
        return false
    end

    local parent = root
    for index = 1, #path - 1 do
        parent = parent[path[index]]
        if type(parent) ~= "table" then
            return false
        end
    end

    local key = path[#path]
    if parent[key] == nil then
        return false
    end

    parent[key] = nil
    return true
end

function Settings.NewAccountWide(defaults, namespace)
    local savedVariables = ZO_SavedVars:NewAccountWide(Settings.SAVED_VARIABLES_NAME, 1, nil, defaults, nil, namespace)

    Settings.savedVariableScopes[#Settings.savedVariableScopes + 1] = {
        savedVariables = savedVariables,
        defaults = defaults,
        namespace = namespace,
    }

    return savedVariables
end

function Settings.GetSection(savedVariables, defaults, sectionName)
    if not savedVariables then
        return defaults[sectionName]
    end

    if type(savedVariables[sectionName]) ~= "table" then
        savedVariables[sectionName] = {}
    end

    return savedVariables[sectionName]
end

function Settings.GetPath(root, path)
    local current = root
    for index = 1, #path do
        if type(current) ~= "table" then
            return nil
        end

        current = current[path[index]]
    end

    return current
end

function Settings.ResetPath(path)
    if type(path) ~= "table" then
        return false
    end

    local reset = false
    for _, scope in ipairs(Settings.savedVariableScopes) do
        local defaultValue = Settings.GetPath(scope.defaults, path)
        if HasDefaultPath(scope.defaults, path) then
            SetPath(scope.savedVariables, path, defaultValue)
            reset = true
        end
    end

    return reset
end

function Settings.RemovePath(path)
    if type(path) ~= "table" then
        return false
    end

    local removed = false
    for _, scope in ipairs(Settings.savedVariableScopes) do
        if RemovePath(scope.savedVariables, path) then
            removed = true
        end
    end

    return removed
end

function Settings.ResetAllOptions()
    for _, scope in ipairs(Settings.savedVariableScopes) do
        if scope.defaults and not scope.defaults.firstRun then
            for key, value in pairs(scope.defaults) do
                if key ~= "whatsNew" then
                    SetPath(scope.savedVariables, { key }, value)
                end
            end
        end
    end
end

function Settings.EnsurePath(root, path)
    local current = root
    for index = 1, #path do
        local key = path[index]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end

        current = current[key]
    end

    return current
end

function Settings.Default(settings, defaults, key)
    if settings[key] == nil then
        settings[key] = defaults[key]
    end

    return settings[key]
end

function Settings.DefaultFrom(settings, key, value)
    if settings[key] == nil then
        settings[key] = value
    end

    return settings[key]
end

function Settings.EnsureTable(settings, key)
    if type(settings[key]) ~= "table" then
        settings[key] = {}
    end

    return settings[key]
end

function Settings.Boolean(settings, defaults, key)
    Settings.Default(settings, defaults, key)
    settings[key] = settings[key] == true
    return settings[key]
end

function Settings.ClampedNumber(settings, defaults, key, minValue, maxValue, shouldRound)
    Settings.Default(settings, defaults, key)

    local value = settings[key]
    if shouldRound then
        value = NQOL.Util.Round(value)
    end

    settings[key] = NQOL.Util.Clamp(value, minValue, maxValue)
    return settings[key]
end

function Settings.Choice(settings, defaults, key, validValues)
    if not validValues[settings[key]] then
        settings[key] = defaults[key]
    end

    return settings[key]
end

NQOL.Settings = Settings
