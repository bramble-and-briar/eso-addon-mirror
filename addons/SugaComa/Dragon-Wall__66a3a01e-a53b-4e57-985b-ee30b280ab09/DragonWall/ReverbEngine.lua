DragonWallReverb = DragonWallReverb or {}
local LIB = DragonWallReverb

LIB.name = "DragonWallReverb"
LIB.version = "0.2.1"
LIB.apiVersion = 1
LIB.modules = LIB.modules or {}
LIB.host = LIB.host or nil

LIB.PRESENTATION_GAME = "game"
LIB.PRESENTATION_LORE = "lore"
LIB.PRESENTATION_DIAGNOSTIC = "diagnostic"

local VALID_TYPES = {
    [LIB.PRESENTATION_GAME] = true,
    [LIB.PRESENTATION_LORE] = true,
    [LIB.PRESENTATION_DIAGNOSTIC] = true,
}

local function CopyArray(source)
    local result = {}
    for i, value in ipairs(source or {}) do result[i] = value end
    return result
end

local function SortedModules(registry)
    local result = {}
    for _, module in pairs(registry) do result[#result + 1] = module end
    table.sort(result, function(a, b)
        local an = string.lower(tostring(a.name or a.id or ""))
        local bn = string.lower(tostring(b.name or b.id or ""))
        if an == bn then return tostring(a.id or "") < tostring(b.id or "") end
        return an < bn
    end)
    return result
end

local function NotifyHost(method, ...)
    local host = LIB.host
    if host and type(host[method]) == "function" then
        pcall(host[method], host, ...)
    end
end

function LIB:RegisterHost(host)
    if type(host) ~= "table" or type(host.id) ~= "string" then return false, "invalid host" end
    if tonumber(host.apiVersion) ~= LIB.apiVersion then return false, "unsupported host API version" end
    LIB.host = host
    NotifyHost("OnModulesChanged")
    return true
end

function LIB:GetHost() return LIB.host end
function LIB:IsHostAvailable() return LIB.host ~= nil end

function LIB:RegisterModule(module)
    if type(module) ~= "table" then return false, "module must be a table" end
    if type(module.id) ~= "string" or module.id == "" then return false, "module.id is required" end
    if type(module.name) ~= "string" or module.name == "" then return false, "module.name is required" end
    if tonumber(module.apiVersion) ~= LIB.apiVersion then return false, "unsupported Dragon Wall Reverb API version" end
    if not VALID_TYPES[module.presentationType] then return false, "unsupported presentationType" end
    if type(module.GetPresentationData) ~= "function" then return false, "module.GetPresentationData is required" end

    local existing = LIB.modules[module.id]
    if existing and existing ~= module then return false, "duplicate module id: " .. module.id end
    LIB.modules[module.id] = module
    NotifyHost("OnModulesChanged")
    return true
end

function LIB:UnregisterModule(moduleId)
    if type(moduleId) ~= "string" or LIB.modules[moduleId] == nil then return false end
    LIB.modules[moduleId] = nil
    NotifyHost("OnModulesChanged")
    return true
end

function LIB:GetModule(moduleId)
    return LIB.modules[moduleId]
end

-- ==========================================================
-- OPTIONAL MODULE ACTIONS
-- ==========================================================
local VALID_ACTION_SLOTS = {
    primary = true,
    secondary = true,
    tertiary = true,
    utility = true,
}

function LIB:GetModuleActions(moduleId)
    local module = LIB.modules[moduleId]
    if not module or type(module.GetActions) ~= "function" then return {} end

    local ok, actions = pcall(module.GetActions, module)
    if not ok or type(actions) ~= "table" then return {} end

    local result = {}
    for slot, action in pairs(actions) do
        if VALID_ACTION_SLOTS[slot]
            and type(action) == "table"
            and type(action.callback) == "function" then
            result[slot] = action
        end
    end
    return result
end

function LIB:InvokeModuleAction(moduleId, slot)
    if not VALID_ACTION_SLOTS[slot] then return false, "invalid action slot" end
    local module = LIB.modules[moduleId]
    if not module then return false, "module not found" end

    local actions = self:GetModuleActions(moduleId)
    local action = actions[slot]
    if not action then return false, "action unavailable" end

    if type(action.visible) == "function" then
        local ok, visible = pcall(action.visible, module)
        if not ok or visible == false then return false, "action hidden" end
    end
    if type(action.enabled) == "function" then
        local ok, enabled = pcall(action.enabled, module)
        if not ok or enabled == false then return false, "action disabled" end
    end

    local ok, result = pcall(action.callback, module)
    if not ok then return false, tostring(result) end
    self:NotifyDataChanged(moduleId)
    return result ~= false
end

function LIB:GetModules() return SortedModules(LIB.modules) end
function LIB:GetModuleCount()
    local count = 0
    for _ in pairs(LIB.modules) do count = count + 1 end
    return count
end

function LIB:GetModulesByType(presentationType)
    local result = {}
    if not VALID_TYPES[presentationType] then return result end
    for _, module in ipairs(SortedModules(LIB.modules)) do
        if module.presentationType == presentationType then result[#result + 1] = module end
    end
    return result
end


function LIB:IsValidPresentationType(presentationType)
    return VALID_TYPES[presentationType] == true
end

-- Optional nested-navigation contract.
-- Dragon Wall cycles Echoes with L1/R1. An Echo may expose multiple
-- internal entries (letters, books, collections, records) using these methods.
function LIB:GetModuleEntryCount(moduleId)
    local module = LIB.modules[moduleId]
    if not module then return 0 end
    if type(module.GetEntryCount) == "function" then
        local ok, count = pcall(module.GetEntryCount, module)
        if ok then return math.max(0, tonumber(count) or 0) end
    end
    return 1
end

function LIB:ChangeModuleEntry(moduleId, delta)
    local module = LIB.modules[moduleId]
    if not module or type(module.ChangeEntry) ~= "function" then return false end
    local ok, changed = pcall(module.ChangeEntry, module, tonumber(delta) or 0)
    if ok and changed ~= false then
        LIB:NotifyDataChanged(moduleId)
        return true
    end
    return false
end

function LIB:SetModuleActive(moduleId, enabled)
    local host = LIB.host
    if not host or type(host.SetModuleActive) ~= "function" then return false, "Dragon Wall host is not available" end
    return host:SetModuleActive(moduleId, enabled == true)
end

function LIB:GetActiveModuleIds()
    local host = LIB.host
    if not host or type(host.GetActiveModuleIds) ~= "function" then return {} end
    local ok, ids = pcall(host.GetActiveModuleIds, host)
    if not ok or type(ids) ~= "table" then return {} end
    return CopyArray(ids)
end

function LIB:NotifyDataChanged(moduleId)
    NotifyHost("OnModuleDataChanged", moduleId)
end
