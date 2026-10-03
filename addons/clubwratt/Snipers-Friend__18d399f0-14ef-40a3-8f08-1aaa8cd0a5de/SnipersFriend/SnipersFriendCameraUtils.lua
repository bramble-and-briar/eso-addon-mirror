-- SnipersFriendCameraUtils.lua: Pure helpers for camera settings (no side effects)
--
-- On console SetCVar/SetSetting are PRIVATE (James hit "Attempt to access a private
-- function from insecure code" from SetCVar, 2026-10-02). The only working lever is
-- the one MOR Camera Sensitivity uses: edit the min/max of the entries in
-- ZO_SharedOptions_SettingsData so the game's own Settings > Camera sliders - which
-- call SetSetting from secure ZOS code - reach further. The engine also has camera
-- settings for zoom distance that no native panel exposes; we inject rows for them.

local CameraUtils = {}

-- CVars (PC capture in env/reference/cvars/UserSettings.txt). Only used where the
-- engine lets us call Set/GetCVar (PC). Kept for the direct path + /sf status.
CameraUtils.CVARS = {
    sensitivityX = "GamepadSensitivityThirdPersonX",
    sensitivityY = "GamepadSensitivityThirdPersonY",
    sensitivityFirstPersonX = "GamepadSensitivityFirstPersonX",
    sensitivityFirstPersonY = "GamepadSensitivityFirstPersonY",
    distance = "WeaponsOutCameraZoomDistance",
    distanceSheathed = "WeaponsSheathedCameraZoomDistance",
    distanceSiege = "SiegeCameraZoomDistance",
    syncDistances = "CameraZoomDistancesSynced",
}

-- Native slider ranges (from esoui optionspanel_camera_shared.lua) for reference/reset.
CameraUtils.NATIVE = {
    sensitivity = { min = 0.65, max = 1.05 },
    height = { min = -0.3, max = 0.5 },
    horizontalOffset = { min = -1.0, max = 1.0 },
    fov = { min = 35, max = 65 },
    distance = { min = 0.5, max = 2.5 }, -- stick zoom range, approximate
}

-- How far our "limit" sliders let the user push each native slider's bounds.
CameraUtils.LIMIT_RANGES = {
    sensitivityMax = { min = 1.05, max = 5.00, step = 0.05 },
    distanceMax = { min = 2.50, max = 25.00, step = 0.50 },
    heightMin = { min = -3.00, max = -0.30, step = 0.10 },
    heightMax = { min = 0.50, max = 4.00, step = 0.10 },
    offsetMax = { min = 1.00, max = 5.00, step = 0.25 },
    fovMin = { min = 10, max = 35, step = 1 },
    fovMax = { min = 65, max = 150, step = 1 },
}

-- Ranges for the direct-value sliders (only shown when SetCVar/SetSetting are callable).
CameraUtils.RANGES = {
    sensitivity = { min = 0.10, max = 5.00, step = 0.05, default = 0.85 },
    sensitivityFirstPerson = { min = 0.10, max = 5.00, step = 0.05, default = 0.72 },
    distance = { min = 0.50, max = 25.00, step = 0.25, default = 2.5 },
    distanceSiege = { min = 1.00, max = 30.00, step = 0.50, default = 6.0 },
    height = { min = -3.00, max = 4.00, step = 0.05, default = 0 },
    horizontalOffset = { min = -5.00, max = 5.00, step = 0.10, default = 0 },
    fov = { min = 10, max = 150, step = 1, default = 50 },
}

-- Engine functions this addon may call. Calling a private one raises an
-- uncatchable error, so every call site checks IsCallable first.
CameraUtils.API_NAMES = {
    "SetCVar", "GetCVar", "SetSetting", "GetSetting",
    "IsGameCameraUnitHighlightedAttackable",
}

---Console lesson (2026-10-02): merely INDEXING a private function - _G["SetSetting"],
---type(SetSetting), rawget(_G, ...) - raises "Attempt to access a private function
---from insecure code" and that error is not catchable. So: ask IsPrivateFunction
---FIRST (it takes a string, never touches the function), and only then look it up.
---@param name string
---@return boolean
function CameraUtils.IsCallable(name)
    if type(IsPrivateFunction) == "function" and IsPrivateFunction(name) then return false end
    return type(_G[name]) == "function"
end

---@param name string
---@return boolean
function CameraUtils.IsProtected(name)
    return type(IsProtectedFunction) == "function" and IsProtectedFunction(name) == true
end

---@return boolean
function CameraUtils.CanSetSetting()
    return CameraUtils.IsCallable("SetSetting")
end

---@return boolean
function CameraUtils.CanSetCVar()
    return CameraUtils.IsCallable("SetCVar")
end

---@return boolean
function CameraUtils.SetSettingIsProtected()
    return CameraUtils.IsProtected("SetSetting")
end

---@param v number
---@return string
function CameraUtils.FormatCVar(v)
    return string.format("%.4f", v)
end

---@param name string
---@return number|nil
function CameraUtils.ReadCVarNumber(name)
    if not CameraUtils.IsCallable("GetCVar") then return nil end
    local ok, raw = pcall(GetCVar, name)
    if not ok or raw == nil then return nil end
    return tonumber(raw)
end

---@param v number
---@param lo number
---@param hi number
---@return number
function CameraUtils.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---@param system number
---@param settingId number
---@return string
function CameraUtils.NativeSliderKey(system, settingId)
    return string.format("%d:%d", system, settingId)
end

---Build the list of native slider overrides from the user's limits.
---@param limits SnipersFriendCameraLimits
---@return {system: number, settingId: number, min: number, max: number}[]
function CameraUtils.BuildSliderOverrides(limits)
    local N = CameraUtils.NATIVE
    return {
        { system = SETTING_TYPE_GAMEPAD, settingId = GAMEPAD_SETTING_CAMERA_SENSITIVITY_X, min = N.sensitivity.min, max = limits.sensitivityMax },
        { system = SETTING_TYPE_GAMEPAD, settingId = GAMEPAD_SETTING_CAMERA_SENSITIVITY_Y, min = N.sensitivity.min, max = limits.sensitivityMax },
        { system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET, min = limits.heightMin, max = limits.heightMax },
        { system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET, min = -limits.offsetMax, max = limits.offsetMax },
        { system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW, min = limits.fovMin, max = limits.fovMax },
        -- our injected rows
        { system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_DISTANCE, min = N.distance.min, max = limits.distanceMax },
        { system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_DISTANCE_UNSHEATHED, min = N.distance.min, max = limits.distanceMax },
    }
end

---Settings-data entries for the hidden engine camera settings we surface in the
---native Camera panel. Same shape as esoui's ZO_OptionsPanel_Camera_ControlData.
---@param limits SnipersFriendCameraLimits
---@return table<number, table>
function CameraUtils.BuildInjectedCameraEntries(limits)
    local N = CameraUtils.NATIVE
    local function slider(settingId, text, tooltip)
        return {
            controlType = OPTIONS_SLIDER,
            system = SETTING_TYPE_CAMERA,
            settingId = settingId,
            panel = SETTING_PANEL_CAMERA,
            text = text,
            tooltipText = tooltip,
            minValue = N.distance.min,
            maxValue = limits.distanceMax,
            valueFormat = "%.2f",
            showValue = true,
            showValueFunc = function(v) return string.format("%.2f", tonumber(v) or 0) end,
            defaultMarker = 2.5,
        }
    end
    return {
        [CAMERA_SETTING_DISTANCE] = slider(CAMERA_SETTING_DISTANCE, "Camera Distance (weapons out)",
            "Snipers Friend: third person zoom distance while weapons are drawn. Right-stick zoom also changes this."),
        [CAMERA_SETTING_DISTANCE_UNSHEATHED] = slider(CAMERA_SETTING_DISTANCE_UNSHEATHED, "Camera Distance (sheathed)",
            "Snipers Friend: third person zoom distance while weapons are sheathed."),
        [CAMERA_SETTING_DISTANCE_SYNCED] = {
            controlType = OPTIONS_CHECKBOX,
            system = SETTING_TYPE_CAMERA,
            settingId = CAMERA_SETTING_DISTANCE_SYNCED,
            panel = SETTING_PANEL_CAMERA,
            text = "Sync Camera Distances",
            tooltipText = "Snipers Friend: use one zoom distance for drawn and sheathed weapons.",
        },
    }
end

---Gamepad panel rows (GAMEPAD_SETTINGS_DATA[SETTING_PANEL_CAMERA] entries).
---@return {panel: number, system: number, settingId: number}[]
function CameraUtils.BuildInjectedGamepadRows()
    return {
        { panel = SETTING_PANEL_CAMERA, system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_DISTANCE },
        { panel = SETTING_PANEL_CAMERA, system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_DISTANCE_UNSHEATHED },
        { panel = SETTING_PANEL_CAMERA, system = SETTING_TYPE_CAMERA, settingId = CAMERA_SETTING_DISTANCE_SYNCED },
    }
end

---Report private/protected status of every engine function we touch.
---Private names are never indexed (see IsCallable).
---@return string[]
function CameraUtils.ProbeApi()
    local lines = {}
    for _, name in ipairs(CameraUtils.API_NAMES) do
        local kind
        if type(IsPrivateFunction) == "function" and IsPrivateFunction(name) then
            kind = "PRIVATE"
        elseif type(_G[name]) ~= "function" then
            kind = "missing"
        elseif CameraUtils.IsProtected(name) then
            kind = "protected"
        else
            kind = "ok"
        end
        lines[#lines + 1] = string.format("%s: %s", name, kind)
    end
    return lines
end

SnipersFriend.CameraUtils = CameraUtils
