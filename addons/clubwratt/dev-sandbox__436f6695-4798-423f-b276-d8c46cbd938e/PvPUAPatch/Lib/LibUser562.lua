PvPUAPatchLib = PvPUAPatchLib or {}
local L = PvPUAPatchLib

L.name = "PvPUAPatchLib"
L.version = 1

--------------------------------------------------
-- Platform
--------------------------------------------------
local supported

function L.IsSupported()
    if supported ~= nil then return supported end
    supported = false
    if type(IsConsoleUI) == "function" and IsConsoleUI() then
        supported = true
    elseif type(IsGameCoreUI) == "function" and IsGameCoreUI() then
        supported = true
    elseif type(IsGamepadUISupported) == "function" and type(IsKeyboardUISupported) == "function" then
        supported = IsGamepadUISupported() and not IsKeyboardUISupported()
    end
    return supported
end
