-- ESO Adventurer Suite - Architecture lifecycle registry
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach

EPC.Architecture = EPC.Architecture or {}
local A = EPC.Architecture
A.modules = A.modules or {}
A.order = A.order or {}
A.version = 1

local function call(module, method, ...)
    local fn = module and module[method]
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, module, ...)
    if not ok then
        module.state = "ERROR"
        module.lastError = tostring(err)
        if EPC.Compatibility and type(EPC.Compatibility.RecordRuntimeError) == "function" then
            pcall(EPC.Compatibility.RecordRuntimeError, EPC.Compatibility, module.name or "ARCHITECTURE", err)
        end
    end
    return ok, err
end

function A:RegisterModule(name, module, options)
    assert(type(name) == "string" and name ~= "", "module name required")
    assert(type(module) == "table", "module table required")
    if self.modules[name] and self.modules[name] ~= module then
        error("duplicate module owner: " .. name)
    end
    if not self.modules[name] then self.order[#self.order + 1] = name end
    module.name = name
    module.options = options or module.options or {}
    module.state = module.state or "REGISTERED"
    self.modules[name] = module
    return module
end

function A:GetModule(name) return self.modules[name] end

function A:InitializeModule(name)
    local m = self.modules[name]
    if not m or m.state == "INITIALIZED" or m.state == "ENABLED" then return m ~= nil end
    local ok = call(m, "Initialize")
    if ok then m.state = "INITIALIZED" end
    return ok
end

function A:EnableModule(name)
    local m = self.modules[name]
    if not m then return false end
    if m.state == "REGISTERED" then self:InitializeModule(name) end
    if m.state == "ERROR" then return false end
    local ok = call(m, "Enable")
    if ok then m.state = "ENABLED" end
    return ok
end

function A:DisableModule(name)
    local m = self.modules[name]
    if not m then return false end
    local ok = call(m, "Disable")
    if ok then m.state = "DISABLED" end
    return ok
end

function A:ShutdownModule(name)
    local m = self.modules[name]
    if not m then return false end
    call(m, "Disable")
    local ok = call(m, "Shutdown")
    if ok then m.state = "SHUTDOWN" end
    return ok
end

function A:GetDiagnostics()
    local rows = {}
    for _, name in ipairs(self.order) do
        local m = self.modules[name]
        rows[#rows + 1] = { name=name, state=m.state or "UNKNOWN", error=m.lastError }
    end
    return rows
end
