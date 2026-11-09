-- =========================================================
-- MugShot - Defaults
-- Default values used to initialise SavedVariables on
-- first login and to fill in missing keys after upgrades.
-- =========================================================

local MugShot = MugShot
local C = MugShot.Constants
local Q = C.QUADRANTS
local V = C.VALUES

-- Default Quadrants for Enemy targets:
-- Line 1: Target Name
-- Line 2: Percentage & Health
-- Line 3: Privileged debuffs row
local DEFAULT_QUADRANTS_ENEMY = {
    [Q.LINE1_LEFT]   = V.NAME,
    [Q.LINE1_RIGHT]  = V.NONE,
    [Q.LINE2_LEFT]   = V.PERCENT,
    [Q.LINE2_RIGHT]  = V.HEALTH,
    [Q.LINE3_LEFT]   = V.PRIVILEGED,
    [Q.LINE3_RIGHT]  = V.NONE,
}

-- Default Quadrants for Neutral and Allied targets:
-- Line 1: Percentage & Health
-- Line 2: None (empty)
-- Line 3: Target Name
local DEFAULT_QUADRANTS_NEUTRAL = {
    [Q.LINE1_LEFT]   = V.PERCENT,
    [Q.LINE1_RIGHT]  = V.HEALTH,
    [Q.LINE2_LEFT]   = V.NONE,
    [Q.LINE2_RIGHT]  = V.NONE,
    [Q.LINE3_LEFT]   = V.NAME,
    [Q.LINE3_RIGHT]  = V.NONE,
}

-- NOTE: TOPLEFT and other anchor constants are ESO globals defined at runtime.
-- They are referenced here by name; Lua evaluates them when this table is
-- constructed, which happens after ESO globals are available.
MugShot.Defaults = {
    schemaVersion       = 1,
    enabled             = true,
    locked              = false,
    layout              = "classic",
    useHodorIcons       = true,
    onlyHostileInTrials = false,
    trackGroupDebuffs   = true,
    builderTemplate     = "tank",
    showRace            = true,
    showAlliance        = true,
    customTags          = {},
    lines = {
        [1] = "name",
        [2] = "health",
        [3] = "effects",
    },
    quadrants        = DEFAULT_QUADRANTS_ENEMY,
    quadrantsEnemy   = DEFAULT_QUADRANTS_ENEMY,
    quadrantsNeutral = DEFAULT_QUADRANTS_NEUTRAL,
    position = {
        point         = TOP,       -- Native ESO target frame anchor: centered at top
        relativePoint = TOP,       -- Native ESO target frame anchor: centered at top
        offsetX       = 0,
        offsetY       = 88,
    },
}
