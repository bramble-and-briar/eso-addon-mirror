-- SnipersFriendCameraActions.lua: Push camera values / widen native sliders.
--
-- Console: SetCVar and SetSetting are private, so the ONLY effective path is
-- widening the native Settings > Camera sliders (ApplySliderLimits) and injecting
-- rows for the engine's hidden zoom-distance settings (InjectDistanceSettings).
-- Direct writes (ApplySensitivity/Distance/Height/...) run only where callable (PC).

local SnipersFriend = SnipersFriend
local Utils = SnipersFriend.CameraUtils
local CVARS = Utils.CVARS

local CameraActions = {}

local LOCK_UPDATE_NAME = "SnipersFriendDistanceLock"
local LOCK_INTERVAL_MS = 1000

---@return SnipersFriendCameraSettings
local function Settings()
    return SnipersFriend.state.savedVars.camera
end

---@return SnipersFriendCameraLimits
local function Limits()
    return SnipersFriend.state.savedVars.camera.limits
end

---@param fmt string
---@param ... any
local function Debug(fmt, ...)
    SnipersFriend.SlashUtils.Debug(fmt, ...)
end

-- ---------------------------------------------------------------- direct writes (PC)

---@param name string
---@param value number
---@return boolean
local function PushCVar(name, value)
    if not Utils.CanSetCVar() then return false end
    local str = Utils.FormatCVar(value)
    if Utils.IsProtected("SetCVar") then
        return CallSecureProtected("SetCVar", name, str) == true
    end
    local ok, err = pcall(SetCVar, name, str)
    if not ok then Debug("SetCVar(%s) failed: %s", name, tostring(err)) end
    return ok
end

---@param settingId number
---@param value number
---@return boolean
local function PushCameraSetting(settingId, value)
    if not Utils.CanSetSetting() then return false end
    local str = Utils.FormatCVar(value)
    if Utils.SetSettingIsProtected() then
        return CallSecureProtected("SetSetting", SETTING_TYPE_CAMERA, settingId, str) == true
    end
    local ok, err = pcall(SetSetting, SETTING_TYPE_CAMERA, settingId, str)
    if not ok then Debug("SetSetting(%d) failed: %s", settingId, tostring(err)) end
    return ok
end

---@return boolean
function CameraActions.ApplySensitivity()
    local s = Settings()
    local ok = PushCVar(CVARS.sensitivityX, s.sensitivityX)
    PushCVar(CVARS.sensitivityY, s.sensitivityY)
    if s.syncFirstPerson then
        PushCVar(CVARS.sensitivityFirstPersonX, s.sensitivityX)
        PushCVar(CVARS.sensitivityFirstPersonY, s.sensitivityY)
    else
        PushCVar(CVARS.sensitivityFirstPersonX, s.sensitivityFirstPersonX)
        PushCVar(CVARS.sensitivityFirstPersonY, s.sensitivityFirstPersonY)
    end
    return ok
end

---@return boolean
function CameraActions.ApplyDistance()
    local s = Settings()
    local sheathed = s.syncDistances and s.distance or s.distanceSheathed
    local ok = PushCVar(CVARS.syncDistances, s.syncDistances and 1 or 0)
    PushCVar(CVARS.distance, s.distance)
    PushCVar(CVARS.distanceSheathed, sheathed)
    PushCVar(CVARS.distanceSiege, s.distanceSiege)
    return ok
end

---@return boolean
function CameraActions.ApplyHeight()
    return PushCameraSetting(CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET, Settings().height)
end

---@return boolean
function CameraActions.ApplyHorizontalOffset()
    return PushCameraSetting(CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET, Settings().horizontalOffset)
end

---@return boolean
function CameraActions.ApplyFov()
    return PushCameraSetting(CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW, Settings().fov)
end

---Re-push zoom distance on a timer (PC only; no-op when SetCVar is private).
function CameraActions.UpdateDistanceLock()
    local state = SnipersFriend.state
    local want = Settings().lockDistance == true and Utils.CanSetCVar()
    if want and not state.lockTimerRegistered then
        EVENT_MANAGER:RegisterForUpdate(LOCK_UPDATE_NAME, LOCK_INTERVAL_MS, function()
            CameraActions.ApplyDistance()
        end)
        state.lockTimerRegistered = true
    elseif not want and state.lockTimerRegistered then
        EVENT_MANAGER:UnregisterForUpdate(LOCK_UPDATE_NAME)
        state.lockTimerRegistered = false
    end
end

-- ---------------------------------------------------------------- native panel (console path)

---@return table|nil
local function CameraPanelData()
    local data = _G["ZO_SharedOptions_SettingsData"]
    return data and data[SETTING_PANEL_CAMERA] or nil
end

---Add hidden engine distance settings to the Camera panel data + gamepad row list.
---Idempotent. Returns how many rows were added this call.
---@return number
function CameraActions.InjectDistanceSettings()
    local panel = CameraPanelData()
    if not panel then return 0 end
    if type(CAMERA_SETTING_DISTANCE) ~= "number" then return 0 end

    panel[SETTING_TYPE_CAMERA] = panel[SETTING_TYPE_CAMERA] or {}
    local cam = panel[SETTING_TYPE_CAMERA]
    local added = 0
    for settingId, entry in pairs(Utils.BuildInjectedCameraEntries(Limits())) do
        if not cam[settingId] then
            cam[settingId] = entry
            added = added + 1
        end
    end

    local rows = _G["GAMEPAD_SETTINGS_DATA"]
    rows = rows and rows[SETTING_PANEL_CAMERA]
    if rows then
        local present = {}
        for _, row in ipairs(rows) do
            if row.system == SETTING_TYPE_CAMERA then present[row.settingId] = true end
        end
        -- insert after the FOV row so the camera preview context is adjacent
        local insertAt = #rows + 1
        for i, row in ipairs(rows) do
            if row.system == SETTING_TYPE_CAMERA and row.settingId == CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW then
                insertAt = i + 1
                break
            end
        end
        for _, row in ipairs(Utils.BuildInjectedGamepadRows()) do
            if not present[row.settingId] then
                table.insert(rows, insertAt, row)
                insertAt = insertAt + 1
            end
        end
    end
    SnipersFriend.state.distanceInjected = true
    return added
end

---Widen (or restore) the native Camera slider bounds from the user's limits.
function CameraActions.ApplySliderLimits()
    local panel = CameraPanelData()
    if not panel then return end
    local state = SnipersFriend.state
    for _, o in ipairs(Utils.BuildSliderOverrides(Limits())) do
        local entry = panel[o.system] and panel[o.system][o.settingId]
        if entry then
            local key = Utils.NativeSliderKey(o.system, o.settingId)
            if not state.nativeRanges[key] then
                state.nativeRanges[key] = { min = entry.minValue, max = entry.maxValue }
            end
            entry.minValue = o.min
            entry.maxValue = o.max
        end
    end
end

---Put the native sliders back to stock bounds (keeps injected distance rows).
function CameraActions.RestoreNativeSliders()
    local panel = CameraPanelData()
    if not panel then return end
    local state = SnipersFriend.state
    for key, saved in pairs(state.nativeRanges) do
        local system, settingId = key:match("^(%d+):(%d+)$")
        local entry = panel[tonumber(system)] and panel[tonumber(system)][tonumber(settingId)]
        if entry then
            entry.minValue = saved.min
            entry.maxValue = saved.max
        end
    end
end

-- Back-compat name used by older callers.
CameraActions.UnlockNativeSliders = CameraActions.ApplySliderLimits

-- ---------------------------------------------------------------- engine <-> savedvars sync
--
-- The player can change the same values through the game's own (widened) Camera
-- sliders or the right stick. If we pushed savedvars blindly on every zone load we
-- would clobber those (0.2.x bug: "distance and sensitivity reset on every load").
-- So: snapshot engine -> savedvars before the world unloads and whenever the
-- options menu closes; re-apply savedvars -> engine after the world loads.

local REAPPLY_DELAYS_MS = { 1500, 4000 }

---Copy the engine's current camera values into savedvars (only what we can read).
---@return boolean changed
function CameraActions.SnapshotFromEngine()
    local s = Settings()
    local changed = false
    if Utils.IsCallable("GetCVar") then
        for key, cvar in pairs(CVARS) do
            local v = Utils.ReadCVarNumber(cvar)
            if v ~= nil then
                if key == "syncDistances" then
                    local b = v ~= 0
                    if s.syncDistances ~= b then s.syncDistances = b; changed = true end
                elseif s[key] ~= v then
                    s[key] = v
                    changed = true
                end
            end
        end
    end
    if Utils.IsCallable("GetSetting") then
        local map = {
            height = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET,
            horizontalOffset = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET,
            fov = CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW,
        }
        for key, id in pairs(map) do
            local ok, raw = pcall(GetSetting, SETTING_TYPE_CAMERA, id)
            local v = ok and tonumber(raw) or nil
            if v ~= nil and s[key] ~= v then
                s[key] = v
                changed = true
            end
        end
    end
    if changed then Debug("snapshot: engine camera values saved") end
    return changed
end

---Push savedvars -> engine (direct writes only; no-ops where private).
function CameraActions.PushValues()
    CameraActions.ApplySensitivity()
    CameraActions.ApplyDistance()
    CameraActions.ApplyHeight()
    CameraActions.ApplyHorizontalOffset()
    CameraActions.ApplyFov()
end

---Called on EVENT_PLAYER_ACTIVATED. First run after install adopts the engine's
---values instead of overwriting them; later runs restore, then re-push a couple
---of times because the engine can reset the camera shortly after activation.
function CameraActions.OnPlayerActivated()
    local s = Settings()
    if not s.synced then
        CameraActions.SnapshotFromEngine()
        s.synced = true
        Debug("first load: adopted engine camera values")
    end
    CameraActions.ApplyAll()
    if not s.applyOnLoad then return end
    for _, ms in ipairs(REAPPLY_DELAYS_MS) do
        zo_callLater(function() CameraActions.PushValues() end, ms)
    end
end

---Called on EVENT_PLAYER_DEACTIVATED (zone change, transitus, logout).
function CameraActions.OnPlayerDeactivated()
    CameraActions.SnapshotFromEngine()
end

---Called when the gamepad options scene closes: adopt native-slider changes.
function CameraActions.OnOptionsClosed()
    CameraActions.SnapshotFromEngine()
end

function CameraActions.ApplyAll()
    local s = Settings()
    CameraActions.InjectDistanceSettings()
    if s.unlockNativeSliders then
        CameraActions.ApplySliderLimits()
    else
        CameraActions.RestoreNativeSliders()
    end
    if s.applyOnLoad and (Utils.CanSetCVar() or Utils.CanSetSetting()) then
        CameraActions.PushValues()
    end
    CameraActions.UpdateDistanceLock()
end

---@param settingId number
---@return string
local function ReadCameraSetting(settingId)
    if not Utils.IsCallable("GetSetting") then return "? (GetSetting private)" end
    local ok, v = pcall(GetSetting, SETTING_TYPE_CAMERA, settingId)
    return ok and tostring(v) or "n/a"
end

---Read what the engine actually holds, for /sf status. Never calls a private function.
---@return string[]
function CameraActions.ReadBackStatus()
    local lines = {}
    local L = Limits()
    lines[#lines + 1] = string.format("SetCVar: %s | SetSetting: %s",
        Utils.CanSetCVar() and "ok" or "PRIVATE", Utils.CanSetSetting() and "ok" or "PRIVATE")
    lines[#lines + 1] = string.format("native slider limits: sens max %.2f | dist max %.2f | height %.2f..%.2f | offset +/-%.2f | fov %d..%d%s",
        L.sensitivityMax, L.distanceMax, L.heightMin, L.heightMax, L.offsetMax, L.fovMin, L.fovMax,
        Settings().unlockNativeSliders and "" or " (DISABLED)")
    lines[#lines + 1] = "distance rows injected into Settings > Camera: " .. tostring(SnipersFriend.state.distanceInjected == true)
    if Utils.IsCallable("GetCVar") then
        local keys = {}
        for key in pairs(CVARS) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local v = Utils.ReadCVarNumber(CVARS[key])
            lines[#lines + 1] = string.format("%s = %s", key, v and string.format("%.2f", v) or "n/a")
        end
    end
    lines[#lines + 1] = "height (engine) = " .. ReadCameraSetting(CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET)
    lines[#lines + 1] = "distance (engine) = " .. ReadCameraSetting(CAMERA_SETTING_DISTANCE)
    local s = Settings()
    lines[#lines + 1] = string.format("saved (re-applied on load%s): sens %.2f/%.2f, dist %.2f/%.2f, siege %.2f, height %.2f, fov %d",
        s.applyOnLoad and "" or " - OFF", s.sensitivityX, s.sensitivityY, s.distance, s.distanceSheathed, s.distanceSiege, s.height, s.fov)
    return lines
end

SnipersFriend.CameraActions = CameraActions
