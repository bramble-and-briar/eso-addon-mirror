-- Build-time configuration for stable/beta flavors
-- Defaults for Stable
EOTU_Config  = EOTU_Config or {}
local C      = EOTU_Config

-- These can be replaced during packaging for beta builds
C.ADDON_NAME = C.ADDON_NAME or "EyesOfTheUndaunted"
C.DISPLAY_NAME = C.DISPLAY_NAME or "Eyes Of The Undaunted"
C.NAME_SHORT = C.NAME_SHORT or "EOTU"
C.NAMESPACE  = C.NAMESPACE or "EOTU" -- global table name
C.SAVEDVARS  = C.SAVEDVARS or "EOTU_SavedVars"
C.PIN_TYPE   = C.PIN_TYPE or "EOTU_Pin"
C.SLASH      = C.SLASH or "/eotu_debug"
C.VERSION    = C.VERSION or "1.51.01"

return EOTU_Config;
