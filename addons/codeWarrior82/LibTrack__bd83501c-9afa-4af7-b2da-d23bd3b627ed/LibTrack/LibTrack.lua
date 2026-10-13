local appName = "LibTrack"

LibTrack = {}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

local function isPlayerInCombat()
    return IsUnitInCombat("player")
end

--death related results
local function isDeathRelatedResult(result)
    return result == ACTION_RESULT_DIED
        or result == ACTION_RESULT_DIED_XP
        or result == ACTION_RESULT_DIED_COMPANION_XP
        or result == ACTION_RESULT_KILLING_BLOW--2260 ?
        or result == ACTION_RESULT_TARGET_DEAD
        or result == ACTION_RESULT_KILLED_BY_DAEDRIC_WEAPON
        or result == ACTION_RESULT_KILLED_BY_SUBZONE
end

--handle combat events
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    if isDeathRelatedResult(result) and isPlayerInCombat() then
        printMessage(string.format(
            "[NT] result=%s targetName=%s targetType=%s ability=%s abilityId=%s",
            tostring(result),
            tostring(targetName),
            tostring(targetType),
            tostring(abilityName),
            tostring(abilityId)
        ))
    end
end






--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    libTrackText:SetMovable(true)
    libTrackTextLabelMain:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")

    libTrackTextLabelMain:SetText( "Corpses: ")




    EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)