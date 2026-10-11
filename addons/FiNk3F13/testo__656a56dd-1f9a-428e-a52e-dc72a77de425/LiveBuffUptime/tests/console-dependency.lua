local file = assert(io.open("LiveBuffUptime.addon", "r"))
local manifest = file:read("*a")
file:close()
local required = assert(manifest:match("## DependsOn:([^\r\n]+)"))
local names = {}
for name in required:gmatch("%S+") do names[name] = true end
assert(names.LibHarvensAddonSettings, "Settings must be mandatory")
local optional = assert(manifest:match("## OptionalDependsOn:([^\r\n]+)"))
assert(optional:find("LibCombat2", 1, true) and optional:find("LibCombat", 1, true), "Both platform backends must load before the addon")
assert(not names.LibCombat2, "PC must load without the console library")
assert(not names.LibCombat, "v1 must not be mandatory for console")
assert(manifest:find("CombatBridge.lua", 1, true) < manifest:find("LiveBuffUptime.lua", 1, true), "Bridge must load before addon")
print("Platform dependencies: settings required, both combat backends optional, bridge load order passed")
