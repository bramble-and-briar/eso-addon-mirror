-- =========================================================
-- MugShot - Defaults
-- Default values used to initialise SavedVariables on
-- first login and to fill in missing keys after upgrades.
-- =========================================================

MugShot = MugShot or {}
local MugShot = MugShot

-- NOTE: TOPLEFT and other anchor constants are ESO globals defined at runtime.
-- They are referenced here by name; Lua evaluates them when this table is
-- constructed, which happens after ESO globals are available (Defaults.lua
-- is loaded by the addon, not by a standalone Lua interpreter).
MugShot.Defaults = {
    schemaVersion       = 1,
    enabled             = true,
    locked              = false,
    useHodorIcons       = true,
    onlyHostileInTrials = false,
    position = {
        point         = TOPLEFT,   -- ESO constant: evaluated at runtime
        relativePoint = TOPLEFT,   -- ESO constant: evaluated at runtime
        offsetX       = 100,
        offsetY       = 200,
    },
}
