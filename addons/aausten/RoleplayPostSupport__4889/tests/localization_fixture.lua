-- Test-only ESO string registry. Install separately from loading so bootstrap
-- tests can exercise the manifest's actual deferred-localization order.
local F = {}

function F.install()
    local stale = {}
    for name in pairs(_G) do
        if type(name) == "string" and name:match("^RPS_") then stale[#stale + 1] = name end
    end
    for _, name in ipairs(stale) do _G[name] = nil end
    local registry = { ids = {}, strings = {}, versions = {}, creates = {}, versionCalls = {}, reads = {} }
    local nextId = 10000
    ZO_CreateStringId = function(name, text)
        assert(type(name) == "string" and type(text) == "string")
        registry.creates[#registry.creates + 1] = { name = name, text = text }
        nextId = nextId + 1
        registry.ids[name] = nextId
        registry.strings[nextId], registry.versions[nextId] = text, 0
        _G[name] = nextId
    end
    SafeAddVersion = function(id, version)
        assert(registry.strings[id], "version for unregistered string ID")
        assert(type(version) == "number")
        registry.versionCalls[#registry.versionCalls + 1] = { id = id, version = version }
        registry.versions[id] = version
    end
    SafeAddString = function(id, text, version)
        assert(registry.strings[id], "override for unregistered string ID")
        assert(type(text) == "string" and type(version) == "number")
        if version >= registry.versions[id] then
            -- Translation versions are compared to the registered baseline,
            -- not to the version of the last accepted translation.
            registry.strings[id] = text
        end
    end
    GetString = function(id)
        assert(type(id) == "number" and registry.strings[id], "GetString needs a registered numeric ID")
        registry.reads[#registry.reads + 1] = id
        return registry.strings[id]
    end
    function registry:override(values, version)
        for key, text in pairs(values or {}) do
            SafeAddString(assert(self.ids["RPS_" .. key], "unknown override key: " .. key), text, version or 1)
        end
    end
    -- Emulate ESO's optional language slot without creating translation files or
    -- trying to execute the literal manifest substitution token.
    function registry:loadLanguage(language, translations)
        local values = translations and translations[language]
        if not values then return false end
        self:override(values)
        return true
    end
    return registry
end

function F.load(overrides)
    assert(type(RoleplayPostSupport) == "table", "reset addon namespace before localization")
    local registry = F.install()
    dofile("lang/default.lua")
    registry:override(overrides)
    dofile("RoleplayPostSupport_Localization.lua")
    return registry
end

return F
