local CAE = CrutchAlertsExtensions


---------------------------------------------------------------------
local function PrintUsage()
    CAE.msg([[Usage:
|cAAAAAA/cae settings - opens the settings
|cAAAAAA/cae utils - opens the utils settings
|cAAAAAA/cae printskills - prints your currently equipped skill IDs
|cAAAAAA/cae printsets - prints your currently equipped set IDs
|cAAAAAA/cae freeze - temporarily freezes shapes in their current spots
|cAAAAAA/cae unfreeze - restores shapes to follow your character
|cAAAAAA/cae stalwart - toggles chat debug for vMoS Stalwart Sisterhood achievement
|cAAAAAA/cae]])
end

---------------------------------------------------------------------
SLASH_COMMANDS["/cae"] = function(argString)
    local args = {}
    for word in string.gmatch(argString, "%S+") do
        table.insert(args, word)
    end

    if (#args == 0) then
        PrintUsage()
        return
    end
    local cmd = string.lower(args[1])

    ------------
    if (args[1] == "settings") then
        LibAddonMenu2:OpenToPanel(CrutchAlertsExtensionsOptions)

    elseif (args[1] == "utils") then
        LibAddonMenu2:OpenToPanel(CrutchAlertsExtensionsUtils)

    elseif (args[1] == "printskills") then
        SLASH_COMMANDS["/crutch"]("printskills") -- just an alias for crutch

    elseif (args[1] == "printeffects" or args[1] == "printbuffs") then
        SLASH_COMMANDS["/crutch"]("printeffects") -- just an alias for crutch

    elseif (args[1] == "printsets") then
        CAE.msg("Equipped complete set IDs:" .. CAE.GetEquippedSetsString())

    elseif (args[1] == "freeze") then
        CAE.msg("Shapes are now frozen in place; undo via /cae unfreeze.")
        CAE.freeze = true

    elseif (args[1] == "unfreeze") then
        CAE.msg("Shapes unfrozen.")
        CAE.freeze = false

    elseif (args[1] == "stalwart") then
        CAE.AchievementDebug.StalwartSisterhood()

    else
        PrintUsage()
    end
end

