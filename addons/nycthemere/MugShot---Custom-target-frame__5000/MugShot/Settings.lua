-- =========================================================
-- MugShot - Settings  (Settings.lua)
-- Loads, validates, and persists SavedVariables.
-- Provides a simple key-value Get/Set interface so the rest
-- of the codebase never touches MugShotSV directly.
-- =========================================================

local MugShot = MugShot

local Settings = {}
Settings.__index = Settings

-- ── Constructor ───────────────────────────────────────────
function Settings.New()
    return setmetatable({
        _data = nil,  -- populated by Load()
    }, Settings)
end

-- ── Load ──────────────────────────────────────────────────
-- Must be called from EVENT_ADD_ON_LOADED (after ESO has
-- populated SavedVariables globals).
function Settings:Load()
    -- MugShotSV is the global table name declared in the manifest.
    -- ESO creates it (or leaves an existing one) before firing ADD_ON_LOADED.
    MugShotSV = MugShotSV or {}

    local sv       = MugShotSV
    local defaults = MugShot.Defaults

    -- ── Schema migration ──────────────────────────────────
    -- If the saved schema version is older than current, reset to defaults
    -- so stale keys don't cause issues.
    if (sv.schemaVersion or 0) < defaults.schemaVersion then
        MugShot.logger:Info("Settings: schema upgrade %d → %d, resetting to defaults",
            sv.schemaVersion or 0, defaults.schemaVersion)
        MugShotSV = {}
        sv = MugShotSV
    end

    -- ── Merge defaults for any missing keys ───────────────
    for k, v in pairs(defaults) do
        if sv[k] == nil then
            sv[k] = v
        end
    end

    -- Deep-merge position sub-table
    if type(defaults.position) == "table" then
        sv.position = sv.position or {}
        for k, v in pairs(defaults.position) do
            if sv.position[k] == nil then
                sv.position[k] = v
            end
        end
    end

    -- Deep-merge quadrants sub-table
    if type(defaults.quadrants) == "table" then
        sv.quadrants = sv.quadrants or {}
        for k, v in pairs(defaults.quadrants) do
            if sv.quadrants[k] == nil then
                sv.quadrants[k] = v
            end
        end
    end

    -- Deep-merge quadrantsEnemy sub-table
    if type(defaults.quadrantsEnemy) == "table" then
        sv.quadrantsEnemy = sv.quadrantsEnemy or {}
        for k, v in pairs(defaults.quadrantsEnemy) do
            if sv.quadrantsEnemy[k] == nil then
                sv.quadrantsEnemy[k] = v
            end
        end
    end

    -- Deep-merge quadrantsNeutral sub-table
    if type(defaults.quadrantsNeutral) == "table" then
        sv.quadrantsNeutral = sv.quadrantsNeutral or {}
        for k, v in pairs(defaults.quadrantsNeutral) do
            if sv.quadrantsNeutral[k] == nil then
                sv.quadrantsNeutral[k] = v
            end
        end
    end

    -- Deep-merge lines sub-table
    if type(defaults.lines) == "table" then
        sv.lines = sv.lines or {}
        for k, v in pairs(defaults.lines) do
            if sv.lines[k] == nil then
                sv.lines[k] = v
            end
        end
    end

    self._data = sv
    MugShot.logger:Info("Settings: loaded (schemaVersion=%d, enabled=%s)",
        self._data.schemaVersion, tostring(self._data.enabled))
end

-- ── Get ───────────────────────────────────────────────────
-- Returns the live settings table (direct reference — callers
-- should treat it as read-only and use Set() to mutate).
function Settings:Get()
    return self._data
end

-- ── Set ───────────────────────────────────────────────────
-- Persist a single top-level key.
-- @param  key    string
-- @param  value  any
function Settings:Set(key, value)
    if self._data == nil then
        MugShot.logger:Warn("Settings:Set called before Load()")
        return
    end
    self._data[key] = value
    -- MugShotSV IS self._data (same table reference), so ESO will
    -- persist the change automatically on logout/reloadui.
    MugShot.logger:Debug("Settings:Set %s = %s", tostring(key), tostring(value))
end

-- ── Save ──────────────────────────────────────────────────
-- ESO persists SavedVariables automatically, but this method
-- is provided for explicit flush points (e.g., slash commands).
-- It is a no-op in normal operation.
function Settings:Save()
    -- Nothing to do; MugShotSV is the live table and ESO saves it on exit.
    MugShot.logger:Debug("Settings:Save (no-op; ESO auto-saves SV)")
end

MugShot.Settings = Settings
MugShot.logger:Info("=== Settings loaded ===")
