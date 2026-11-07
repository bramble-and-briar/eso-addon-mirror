local file = assert(io.open("LiveBuffUptime.addon", "r"))
local manifest = file:read("*a")
file:close()
local required = assert(manifest:match("## DependsOn:([^\r\n]+)"))
local names = {}
for name in required:gmatch("%S+") do names[name] = true end
assert(names.LibHarvensAddonSettings, "Settings must be mandatory")
local function dependencies(key)
    local value = assert(manifest:match("## " .. key .. ":([^\r\n]+)"))
    local result = {}
    for name in value:gmatch("%S+") do result[name] = true end
    return result
end
local optional = dependencies("OptionalDependsOn")
assert(optional.LibCombat, "Installed PC combat library must load before the addon")
assert(not manifest:match("## PCDependsOn:"), "PC combat backend must not be mandatory")
assert(names.LibCombat2, "Console release requires LibCombat2 and lists it under required extensions")
assert(not optional.LibCombat2, "LibCombat2 must not remain merely optional")
assert(not names.LibCombat, "v1 must not be mandatory for console")
assert(manifest:find("CombatBridge.lua", 1, true) < manifest:find("LiveBuffUptime.lua", 1, true), "Bridge must load before addon")
print("Console release dependencies: settings and LibCombat2 required; PC LibCombat remains optional")
