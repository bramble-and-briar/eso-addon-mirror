DragonWallBuiltInDiagnostics = DragonWallBuiltInDiagnostics or {}
local DIAG = DragonWallBuiltInDiagnostics

local module = {
    id = "echoverse_core_diagnostics",
    name = "Dragon Wall Core Diagnostics",
    version = "0.2.1",
    apiVersion = 1,
    presentationType = "diagnostic",
    description = "Built-in Dragon Wall diagnostic Echo.",
    defaultActive = true,
}

function module:GetPresentationData()
    local engine = rawget(_G, "DragonWallReverb")
    local count = engine and engine.GetModuleCount and engine:GetModuleCount() or 0
    local host = engine and engine.GetHost and engine:GetHost() or nil
    return {
        title = "DRAGON WALL DIAGNOSTICS",
        subtitle = "CORE / REVERB",
        lines = {
            "Reverb Engine: " .. (engine and "detected" or "not detected"),
            "Dragon Wall host: " .. (host and tostring(host.id or "detected") or "not registered"),
            "Registered Echoes: " .. tostring(count),
            "",
            "This diagnostic Echo is bundled with Dragon Wall.",
            "It may be hidden in settings but is not a separate install.",
            "Core diagnostic Echo ready.",
        },
    }
end

function DIAG:Register()
    local engine = rawget(_G, "DragonWallReverb")
    if not engine or type(engine.RegisterModule) ~= "function" then return false end
    return engine:RegisterModule(module)
end

DIAG:Register()
