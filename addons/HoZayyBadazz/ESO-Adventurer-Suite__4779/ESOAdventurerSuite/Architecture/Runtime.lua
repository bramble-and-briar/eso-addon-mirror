-- ESO Adventurer Suite - Shared runtime ownership
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.Runtime = EPC.Runtime or {}
local R = EPC.Runtime
R.events = R.events or {}
R.updates = R.updates or {}
R.stats = R.stats or { eventRegistrations=0, updateRegistrations=0, replacements=0, releases=0 }

local EM = EVENT_MANAGER
local PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_Runtime_"

local function key(owner, name)
    return tostring(owner or "Unknown") .. ":" .. tostring(name or "Default")
end

function R:RegisterEvent(owner, name, eventId, callback, filters)
    if not EM or not eventId or type(callback) ~= "function" then return false end
    local k = key(owner, name)
    self:UnregisterEvent(owner, name)
    local registration = PREFIX .. "E_" .. k
    EM:RegisterForEvent(registration, eventId, callback)
    if type(filters) == "table" and type(EM.AddFilterForEvent) == "function" then
        for _, filter in ipairs(filters) do
            if type(filter) == "table" and filter[1] ~= nil then
                local args = {}
                for i = 2, #filter do args[#args + 1] = filter[i] end
                EM:AddFilterForEvent(registration, eventId, filter[1], unpack(args))
            end
        end
    end
    self.stats.eventRegistrations = (self.stats.eventRegistrations or 0) + 1
    self.events[k] = { registration=registration, eventId=eventId, owner=owner, filters=filters }
    return true
end

function R:UnregisterEvent(owner, name)
    local k = key(owner, name)
    local item = self.events[k]
    if item and EM then EM:UnregisterForEvent(item.registration, item.eventId) end
    self.events[k] = nil
end

function R:RegisterUpdate(owner, name, intervalMs, callback)
    if not EM or type(callback) ~= "function" then return false end
    local k = key(owner, name)
    self:UnregisterUpdate(owner, name)
    local registration = PREFIX .. "U_" .. k
    EM:RegisterForUpdate(registration, math.max(1, tonumber(intervalMs) or 1000), callback)
    self.stats.updateRegistrations = (self.stats.updateRegistrations or 0) + 1
    self.updates[k] = { registration=registration, owner=owner, interval=intervalMs }
    return true
end

function R:UnregisterUpdate(owner, name)
    local k = key(owner, name)
    local item = self.updates[k]
    if item and EM then EM:UnregisterForUpdate(item.registration) end
    self.updates[k] = nil
end

-- Exact-name ownership is for consolidation modules that must replace an
-- existing ESO/Suite registration without changing the registration string.
function R:RegisterNamedEvent(owner, registration, eventId, callback, filters)
    if not EM or type(registration) ~= "string" or registration == "" or not eventId or type(callback) ~= "function" then return false end
    local k = key(owner, "named-event:" .. registration)
    local old = self.events[k]
    if old then EM:UnregisterForEvent(old.registration, old.eventId) end
    EM:UnregisterForEvent(registration, eventId)
    EM:RegisterForEvent(registration, eventId, callback)
    if type(filters) == "table" and type(EM.AddFilterForEvent) == "function" then
        for _, filter in ipairs(filters) do
            if type(filter) == "table" and filter[1] ~= nil then
                local args = {}
                for i = 2, #filter do args[#args + 1] = filter[i] end
                EM:AddFilterForEvent(registration, eventId, filter[1], unpack(args))
            end
        end
    end
    self.stats.eventRegistrations = (self.stats.eventRegistrations or 0) + 1
    self.events[k] = { registration=registration, eventId=eventId, owner=owner, filters=filters, exactName=true }
    return true
end

function R:UnregisterNamedEvent(owner, registration, eventId)
    local k = key(owner, "named-event:" .. tostring(registration or ""))
    local item = self.events[k]
    local resolvedEvent = eventId or (item and item.eventId)
    if EM and registration and resolvedEvent then EM:UnregisterForEvent(registration, resolvedEvent) end
    self.events[k] = nil
end

function R:RegisterNamedUpdate(owner, registration, intervalMs, callback)
    if not EM or type(registration) ~= "string" or registration == "" or type(callback) ~= "function" then return false end
    local k = key(owner, "named-update:" .. registration)
    local old = self.updates[k]
    if old then EM:UnregisterForUpdate(old.registration) end
    EM:UnregisterForUpdate(registration)
    EM:RegisterForUpdate(registration, math.max(1, tonumber(intervalMs) or 1000), callback)
    self.stats.updateRegistrations = (self.stats.updateRegistrations or 0) + 1
    self.updates[k] = { registration=registration, owner=owner, interval=intervalMs, exactName=true }
    return true
end

function R:UnregisterNamedUpdate(owner, registration)
    local k = key(owner, "named-update:" .. tostring(registration or ""))
    if EM and registration then EM:UnregisterForUpdate(registration) end
    self.updates[k] = nil
end

function R:ReleaseOwner(owner)
    self.stats.releases = (self.stats.releases or 0) + 1
    local eventKeys, updateKeys = {}, {}
    for k,v in pairs(self.events) do if v.owner == owner then eventKeys[#eventKeys+1] = k end end
    for k,v in pairs(self.updates) do if v.owner == owner then updateKeys[#updateKeys+1] = k end end
    for _,k in ipairs(eventKeys) do
        local v=self.events[k]; if v and EM then EM:UnregisterForEvent(v.registration,v.eventId) end; self.events[k]=nil
    end
    for _,k in ipairs(updateKeys) do
        local v=self.updates[k]; if v and EM then EM:UnregisterForUpdate(v.registration) end; self.updates[k]=nil
    end
end

function R:GetDiagnostics()
    local owners, eventCount, updateCount = {}, 0, 0
    for _,v in pairs(self.events) do
        eventCount = eventCount + 1
        local o=tostring(v.owner or "Unknown")
        owners[o]=owners[o] or {events=0,updates=0}
        owners[o].events=owners[o].events+1
    end
    for _,v in pairs(self.updates) do
        updateCount = updateCount + 1
        local o=tostring(v.owner or "Unknown")
        owners[o]=owners[o] or {events=0,updates=0}
        owners[o].updates=owners[o].updates+1
    end
    return {events=eventCount,updates=updateCount,owners=owners,stats=self.stats}
end

-- Compatibility bridge for legacy modules during architecture migration.
-- It preserves ESO's existing registration semantics while recording ownership.
function R:AdoptLegacyOwner(owner)
    owner = tostring(owner or "Legacy")
    self.legacyOwners = self.legacyOwners or {}
    self.legacyOwners[owner] = true
end

function R:GetLegacyOwnerCount()
    local n=0
    for _ in pairs(self.legacyOwners or {}) do n=n+1 end
    return n
end
