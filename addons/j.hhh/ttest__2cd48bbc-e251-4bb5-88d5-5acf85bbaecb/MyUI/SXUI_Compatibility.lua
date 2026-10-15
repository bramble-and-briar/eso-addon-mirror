-- Satuve Xbox UI compatibility layer
-- Maintainer: Satuve
-- Original interface foundation: Bandits User Interface by secretrob and Hoft.

SatuveXboxUI = SatuveXboxUI or {}
SatuveXboxUI.name = "MyUI"
SatuveXboxUI.displayName = "My UI"
SatuveXboxUI.version = "1.9.26"
SatuveXboxUI.actionBarGap = 35

-- Compatibility aliases for clients that no longer expose the legacy
-- POWERTYPE_* constants. GetUnitPower now uses CombatMechanicFlags.
POWERTYPE_HEALTH        = POWERTYPE_HEALTH        or COMBAT_MECHANIC_FLAGS_HEALTH        or 1
POWERTYPE_MAGICKA       = POWERTYPE_MAGICKA       or COMBAT_MECHANIC_FLAGS_MAGICKA       or 2
POWERTYPE_STAMINA       = POWERTYPE_STAMINA       or COMBAT_MECHANIC_FLAGS_STAMINA       or 4
POWERTYPE_ULTIMATE      = POWERTYPE_ULTIMATE      or COMBAT_MECHANIC_FLAGS_ULTIMATE      or 8
POWERTYPE_WEREWOLF      = POWERTYPE_WEREWOLF      or COMBAT_MECHANIC_FLAGS_WEREWOLF      or 16
POWERTYPE_MOUNT_STAMINA = POWERTYPE_MOUNT_STAMINA or COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA or 32

-- Some Xbox-PC builds do not expose the legacy IsWerewolf helper.
-- Detect the state from the werewolf resource instead.
if type(IsWerewolf) ~= "function" then
    function IsWerewolf()
        if type(GetUnitPower) ~= "function" then return false end
        local current, maximum, effectiveMax = GetUnitPower("player", POWERTYPE_WEREWOLF)
        local maxValue = tonumber(effectiveMax) or tonumber(maximum) or 0
        return maxValue > 0 and (tonumber(current) or 0) > 0
    end
end


-- Some Xbox-PC builds do not expose the old GetClassIcon helper.
-- Use the shared class icon lookup when available and fall back to a neutral icon.
if type(GetClassIcon) ~= "function" then
    function GetClassIcon(classId)
        if GetClassIconKeyboard then
            local icon=GetClassIconKeyboard(classId)
            if icon and icon ~= "" then return icon end
        end
        if ZO_GetPlatformClassIcon then
            local icon=ZO_GetPlatformClassIcon(classId)
            if icon and icon ~= "" then return icon end
        end
        return "/esoui/art/icons/icon_missing.dds"
    end
end

-- The Xbox-server PC client is used with mouse and keyboard. Keep keyboard UI
-- preferred and expose a small status command without changing combat logic.
function SatuveXboxUI.IsKeyboardClient()
    return not IsInGamepadPreferredMode()
end

local function PrintStatus()
    local mode = SatuveXboxUI.IsKeyboardClient() and "Maus/Tastatur" or "Gamepad"
    d(string.format("|c4B8BFE%s|r %s – Eingabemodus: %s", SatuveXboxUI.displayName, SatuveXboxUI.version, mode))
end

SLASH_COMMANDS["/sxui"] = PrintStatus
SLASH_COMMANDS["/satuveui"] = PrintStatus
