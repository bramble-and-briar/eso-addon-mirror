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
-- Uses ZO_SavedVars:NewAccountWide (Option B - Standard ESO).
-- Scopes settings per ESO account (@displayName) automatically.
function Settings:Load()
    local defaults      = MugShot.Defaults
    local schemaVersion = defaults.schemaVersion or 1

    self._data = ZO_SavedVars:NewAccountWide(
        MugShot.Constants.SAVED_VARS_NAME,
        schemaVersion,
        nil,
        defaults
    )

    MugShot.logger:Info("Settings: loaded (schemaVersion=%d, enabled=%s)",
        self._data.schemaVersion or schemaVersion, tostring(self._data.enabled))
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
    -- ZO_SavedVars routes this to the account-wide storage table,
    -- which ESO persists automatically on logout/reloadui.
    MugShot.logger:Debug("Settings:Set %s = %s", tostring(key), tostring(value))
end

-- ── Save ──────────────────────────────────────────────────
-- ESO persists SavedVariables automatically, but this method
-- is provided for explicit flush points (e.g., slash commands).
-- It is a no-op in normal operation.
function Settings:Save()
    -- Nothing to do; ZO_SavedVars persists automatically on logout/reloadui.
    MugShot.logger:Debug("Settings:Save (no-op; ESO auto-saves SV)")
end

MugShot.Settings = Settings
MugShot.logger:Info("=== Settings loaded ===")
