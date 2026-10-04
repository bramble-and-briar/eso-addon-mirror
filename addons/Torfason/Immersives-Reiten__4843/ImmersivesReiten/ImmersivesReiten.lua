--[[
Immersives Reiten
Version 2.0.0

Torfason × Atlas Releasefassung nach ESOUI Standard 2.1.
Die bewährte Kameralogik aus Version 1.2.3 bleibt unverändert.

Funktionen:
  * übernimmt die Perspektive beim Aufsteigen
  * normale ESO-Perspektiv-Taste wechselt auch auf dem Reittier
  * Reit-Ego verwendet Kameradistanz 0
  * Reit-Third-Person stellt die gemerkte Distanz wieder her
  * beim Absteigen bleibt die zuletzt verwendete Perspektive erhalten

Bewusst nicht enthalten:
  * keine Hooks auf ToggleMount
  * kein dauerhafter OnUpdate-Loop
  * keine Waffen-/Kampf-Hooks
--]]

local ADDON_NAME = "ImmersivesReiten"
local DISPLAY_NAME = GetString(SI_IMMERSIVES_REITEN_NAME)
local VERSION = "2.0.0"

local SAVED_VARIABLES_NAME = "ImmersivesReitenSavedVariables"
local SAVED_VARIABLES_VERSION = 1

local savedVariables = nil
local savedDefaults = {
    footWantsFirstPerson = false,
}

local FIRST_PERSON_EPSILON = 0.05
local FIRST_PERSON_DISTANCE = "0.00000000"
local APPLY_DELAY_MS = 80
local RESTORE_DELAY_MS = 120
local CAMERA_CHECK_DELAY_MS = 20

local state = {
    mounted = false,
    footWantsFirstPerson = false,
    mountedFirstPerson = false,
    thirdPersonDistance = nil,
}

local function Print(message)
    d(string.format("|c7FC7FF%s|r: %s", DISPLAY_NAME, tostring(message)))
end

local function YesNo(value)
    return GetString(value and SI_IMMERSIVES_REITEN_YES or SI_IMMERSIVES_REITEN_NO)
end

local function GetCameraDistance()
    return tonumber(GetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE))
end

local function IsDistanceFirstPerson(distance)
    return distance ~= nil and distance <= FIRST_PERSON_EPSILON
end

local function IsValidThirdPersonDistance(distance)
    return distance ~= nil and distance > FIRST_PERSON_EPSILON
end

local function SavePersistentCameraState()
    if not savedVariables then
        return
    end

    savedVariables.footWantsFirstPerson = state.footWantsFirstPerson == true

    if IsValidThirdPersonDistance(state.thirdPersonDistance) then
        savedVariables.thirdPersonDistance = state.thirdPersonDistance
    end
end

local function RememberThirdPersonDistance()
    local distance = GetCameraDistance()
    if IsValidThirdPersonDistance(distance) then
        state.thirdPersonDistance = distance
        SavePersistentCameraState()
    end
end

local function SetCameraToRememberedThirdPerson()
    if not IsValidThirdPersonDistance(state.thirdPersonDistance) then
        return false
    end

    SetSetting(
        SETTING_TYPE_CAMERA,
        CAMERA_SETTING_DISTANCE,
        string.format("%.8f", state.thirdPersonDistance)
    )

    return true
end

local function RestoreThirdPersonDistance()
    if state.mounted then
        return
    end

    SetCameraToRememberedThirdPerson()
end

local function SetFootFirstPersonIntent(value)
    if state.mounted then
        return
    end

    state.footWantsFirstPerson = value == true
    SavePersistentCameraState()
end

local function ObserveZoomInAfterGame()
    local distance = GetCameraDistance()

    if state.mounted then
        -- Mounted wheel zoom normally remains in TP (ESO minimum ~2), but if
        -- distance 0 is still active we keep our state synchronized.
        if IsDistanceFirstPerson(distance) then
            state.mountedFirstPerson = true
            state.footWantsFirstPerson = true
            SavePersistentCameraState()
        else
            state.mountedFirstPerson = false
            state.footWantsFirstPerson = false
            RememberThirdPersonDistance()
            SavePersistentCameraState()
        end
        return
    end

    if IsDistanceFirstPerson(distance) then
        SetFootFirstPersonIntent(true)
    else
        RememberThirdPersonDistance()
    end
end

local function ObserveZoomOutAfterGame()
    local distance = GetCameraDistance()

    if state.mounted then
        if IsValidThirdPersonDistance(distance) then
            state.mountedFirstPerson = false
            state.footWantsFirstPerson = false
            RememberThirdPersonDistance()
            SavePersistentCameraState()
        else
            state.mountedFirstPerson = true
            state.footWantsFirstPerson = true
            SavePersistentCameraState()
        end
        return
    end

    if IsValidThirdPersonDistance(distance) then
        SetFootFirstPersonIntent(false)
        RememberThirdPersonDistance()
    end
end

local function ApplyMountedFirstPerson()
    if not state.mounted or not state.mountedFirstPerson then
        return
    end

    SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, FIRST_PERSON_DISTANCE)
end

local function ApplyMountedThirdPerson()
    if not state.mounted or state.mountedFirstPerson then
        return
    end

    SetCameraToRememberedThirdPerson()
end

local function ToggleMountedPerspective()
    if not state.mounted then
        return false
    end

    if state.mountedFirstPerson then
        state.mountedFirstPerson = false
        state.footWantsFirstPerson = false
        SavePersistentCameraState()
        ApplyMountedThirdPerson()
    else
        -- Preserve the current mounted TP distance before temporarily
        -- replacing it with 0 for first person.
        RememberThirdPersonDistance()
        state.mountedFirstPerson = true
        state.footWantsFirstPerson = true
        SavePersistentCameraState()
        ApplyMountedFirstPerson()
    end

    return true
end

local function OnMountedStateChanged(eventCode, mounted)
    state.mounted = mounted == true

    if state.mounted then
        state.mountedFirstPerson = state.footWantsFirstPerson
        SavePersistentCameraState()

        if state.mountedFirstPerson then
            -- ESO can still expose the stored TP distance here (e.g. 4),
            -- so save it before we temporarily overwrite the setting with 0.
            RememberThirdPersonDistance()
            zo_callLater(ApplyMountedFirstPerson, APPLY_DELAY_MS)
        else
            RememberThirdPersonDistance()
        end
    else
        -- Carry the last mounted view back to the on-foot state.
        state.footWantsFirstPerson = state.mountedFirstPerson
        SavePersistentCameraState()

        if state.footWantsFirstPerson then
            -- Restore only the stored TP distance. We intentionally do NOT
            -- toggle the visible camera mode. This preserves visible FP after
            -- dismount while giving ESO a positive TP distance to return to.
            zo_callLater(RestoreThirdPersonDistance, RESTORE_DELAY_MS)
        else
            RememberThirdPersonDistance()
        end

        state.mountedFirstPerson = false
    end
end

local function OnPlayerActivated()
    state.mounted = IsMounted()

    if state.mounted then
        state.mountedFirstPerson = IsDistanceFirstPerson(GetCameraDistance())
        state.footWantsFirstPerson = state.mountedFirstPerson
        SavePersistentCameraState()
    else
        -- If the persisted state says we are in first person, do not treat
        -- ESO's current CAMERA_SETTING_DISTANCE as a reliable TP distance.
        -- ESO can expose a positive value here even while first person is visible.
        if not state.footWantsFirstPerson then
            RememberThirdPersonDistance()
        end
    end
end

local function InstallCameraObservationHooks()
    -- This exact hook form is retained from the tested 1.1.3 build.
    SecurePostHook(_G, "ToggleGameCameraFirstPerson", function()
        if state.mounted then
            ToggleMountedPerspective()
            return
        end

        local enteringFirstPerson = not state.footWantsFirstPerson

        if enteringFirstPerson then
            RememberThirdPersonDistance()
            SetFootFirstPersonIntent(true)
        else
            SetFootFirstPersonIntent(false)
            zo_callLater(RememberThirdPersonDistance, CAMERA_CHECK_DELAY_MS)
        end
    end)

    SecurePostHook(_G, "CameraZoomIn", function()
        zo_callLater(ObserveZoomInAfterGame, CAMERA_CHECK_DELAY_MS)
    end)

    SecurePostHook(_G, "CameraZoomOut", function()
        zo_callLater(ObserveZoomOutAfterGame, CAMERA_CHECK_DELAY_MS)
    end)
end

local function HandleSlashCommand(text)
    text = zo_strtrim(string.lower(text or ""))

    if text == "toggle" or text == "umschalten" then
        if not state.mounted then
            Print(GetString(SI_IMMERSIVES_REITEN_MSG_TOGGLE_MOUNTED_ONLY))
            return
        end

        ToggleMountedPerspective()
        zo_callLater(function()
            Print(string.format(
                GetString(SI_IMMERSIVES_REITEN_MSG_TOGGLE_RESULT),
                YesNo(state.mountedFirstPerson),
                tostring(GetCameraDistance()),
                tostring(state.thirdPersonDistance)
            ))
        end, 100)
        return
    end

    if text == "force" or text == "erzwingen" then
        if not state.mounted then
            Print(GetString(SI_IMMERSIVES_REITEN_MSG_FORCE_MOUNTED_ONLY))
            return
        end

        RememberThirdPersonDistance()
        state.mountedFirstPerson = true
        state.footWantsFirstPerson = true
        SavePersistentCameraState()

        local before = GetCameraDistance()
        SetSetting(SETTING_TYPE_CAMERA, CAMERA_SETTING_DISTANCE, FIRST_PERSON_DISTANCE)

        zo_callLater(function()
            Print(string.format(
                GetString(SI_IMMERSIVES_REITEN_MSG_FORCE_RESULT),
                tostring(before),
                tostring(GetCameraDistance())
            ))
        end, 100)
        return
    end

    if text == "restore" or text == "wiederherstellen" then
        if state.mounted then
            Print(GetString(SI_IMMERSIVES_REITEN_MSG_RESTORE_FOOT_ONLY))
            return
        end

        local before = GetCameraDistance()
        RestoreThirdPersonDistance()

        zo_callLater(function()
            Print(string.format(
                GetString(SI_IMMERSIVES_REITEN_MSG_RESTORE_RESULT),
                tostring(before),
                tostring(state.thirdPersonDistance),
                tostring(GetCameraDistance())
            ))
        end, 100)
        return
    end

    if text == "third" or text == "dritte" then
        if state.mounted then
            state.mountedFirstPerson = false
            state.footWantsFirstPerson = false
            SavePersistentCameraState()
            ApplyMountedThirdPerson()
            Print(GetString(SI_IMMERSIVES_REITEN_MSG_MOUNT_THIRD))
            return
        end

        SetFootFirstPersonIntent(false)
        RememberThirdPersonDistance()
        Print(GetString(SI_IMMERSIVES_REITEN_MSG_FOOT_THIRD))
        return
    end

    if text == "ego" then
        if state.mounted then
            RememberThirdPersonDistance()
            state.mountedFirstPerson = true
            state.footWantsFirstPerson = true
            SavePersistentCameraState()
            ApplyMountedFirstPerson()
            Print(GetString(SI_IMMERSIVES_REITEN_MSG_MOUNT_FIRST))
            return
        end

        RememberThirdPersonDistance()
        SetFootFirstPersonIntent(true)
        Print(GetString(SI_IMMERSIVES_REITEN_MSG_FOOT_FIRST))
        return
    end

    Print(string.format(
        GetString(SI_IMMERSIVES_REITEN_MSG_STATUS),
        VERSION,
        YesNo(state.mounted),
        tostring(GetCameraDistance()),
        tostring(state.thirdPersonDistance),
        YesNo(state.footWantsFirstPerson),
        YesNo(state.mountedFirstPerson),
        savedVariables and GetString(savedVariables.footWantsFirstPerson and SI_IMMERSIVES_REITEN_PERSPECTIVE_FIRST or SI_IMMERSIVES_REITEN_PERSPECTIVE_THIRD) or GetString(SI_IMMERSIVES_REITEN_NOT_LOADED)
    ))
    Print(GetString(SI_IMMERSIVES_REITEN_MSG_HELP))
end

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVariables = ZO_SavedVars:NewCharacterIdSettings(
        SAVED_VARIABLES_NAME,
        SAVED_VARIABLES_VERSION,
        nil,
        savedDefaults,
        GetWorldName()
    )

    state.mounted = IsMounted()
    state.footWantsFirstPerson = savedVariables.footWantsFirstPerson == true
    state.mountedFirstPerson = false
    state.thirdPersonDistance = tonumber(savedVariables.thirdPersonDistance)

    if state.mounted then
        -- Mounted first person remains directly detectable because this addon
        -- uses camera distance 0 for it.
        state.mountedFirstPerson = IsDistanceFirstPerson(GetCameraDistance())
        state.footWantsFirstPerson = state.mountedFirstPerson
        SavePersistentCameraState()
    else
        -- When logging in/reloading in first person, trust the persisted
        -- perspective instead of trying to infer it from CAMERA_SETTING_DISTANCE.
        if not state.footWantsFirstPerson then
            RememberThirdPersonDistance()
        end
    end

    InstallCameraObservationHooks()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_MOUNTED_STATE_CHANGED, OnMountedStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    SLASH_COMMANDS["/reiten"] = HandleSlashCommand
    SLASH_COMMANDS["/ihrr"] = HandleSlashCommand
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
