local OS = OneSettings
OS.Presets = {}
local Presets = OS.Presets

function Presets:Name(value)
    if type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    if value == "" or value:find("[\r\n|]") then return nil end
    return value
end

function Presets:Save(name)
    name = self:Name(name)
    if not name then return false, "invalidName" end
    OS.modules.addons:FlushChanges()
    OS.account.presets[name] = OS.modules.addons:Capture()
    return true
end

function Presets:Rename(oldName, name)
    name = self:Name(name)
    if not name then return false, "invalidName" end
    if not OS.account.presets[oldName] then return false, "missingPreset" end
    if oldName ~= name and OS.account.presets[name] then return false, "duplicateName" end
    if oldName ~= name then
        OS.account.presets[name] = OS.account.presets[oldName]
        OS.account.presets[oldName] = nil
    end
    return true
end

function Presets:Delete(name)
    OS.account.presets[name] = nil
end

function Presets:List()
    local names = {}
    for name in pairs(OS.account.presets) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function Presets:Load(name)
    local saved = OS.account.presets[name]
    if not saved then return false, "missingPreset" end
    OS.modules.addons:FlushChanges()
    local addons = OS.modules.addons
    local requested, missing = addons:Capture(), {}
    for addon, enabled in pairs(saved.states) do
        if addons.catalog[addon] then requested.states[addon] = enabled
        else missing[#missing + 1] = addon end
    end
    requested.enabled = saved.enabled
    local normalized, issues = addons:Normalize(requested)
    local seen = {}
    for _, addon in ipairs(missing) do seen[addon] = true end
    for _, addon in ipairs(issues) do
        if not seen[addon] then missing[#missing + 1] = addon; seen[addon] = true end
    end
    if OS:Enabled("addons") then
        -- Keep absent components in both the preset and the shared configuration.
        local shared = OS.Copy(saved)
        for addon, enabled in pairs(normalized.states) do shared.states[addon] = enabled end
        addons:MergeShared(shared)
    end
    local changed = addons:Write(normalized, addons.filter)
    local needsReload = changed or not OS.Equal(normalized, addons.loadedStates)
    if OS:Enabled("addons") then addons:PrepareOthers(OS.account.shared.addons) end
    addons:RefreshUI()
    if #missing > 0 then
        table.sort(missing)
        if needsReload then OS.character.missingComponents = missing
        else OS:Warn("missingComponents", table.concat(missing, ", ")) end
    end
    if needsReload then OS:RequestReload() end
    return true
end
