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
local console = dependencies("ConsoleDependsOn")
assert(console.LibCombat2 and not console.LibCombat, "Console must require v2, not the PC backend")
assert(not names.LibCombat2, "PC must load without the console library")
assert(not names.LibCombat, "v1 must not be mandatory for console")
assert(manifest:find("CombatBridge.lua", 1, true) < manifest:find("LiveBuffUptime.lua", 1, true), "Bridge must load before addon")
print("Platform dependencies: settings required, console LibCombat2 required, PC LibCombat optional, bridge load order passed")
