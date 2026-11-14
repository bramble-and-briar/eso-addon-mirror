-- Both input modes can fall back to the PC library when LibCombat2 is absent.
local setup = assert(io.open("tests/pc-backend.lua","r"))
local source = setup:read("*a"); setup:close()
local controller = source:gsub("function IsConsoleUI%(%) return false end",
    "function IsConsoleUI() return true end\nfunction IsInGamepadPreferredMode() return true end")
assert(controller ~= source)
assert(loadstring(controller,"PC LibCombat with console-style UI"))()
print("PC controller layout: LibCombat fallback works without LibCombat2")
