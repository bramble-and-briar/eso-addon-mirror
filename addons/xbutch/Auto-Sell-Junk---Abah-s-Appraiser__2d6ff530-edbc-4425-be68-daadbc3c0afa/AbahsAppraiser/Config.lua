-- Build-time configuration for stable/beta flavors
-- Defaults for Stable
ASJ = ASJ or {}
ASJ.Config = ASJ.Config or {}
local C = ASJ.Config

-- These can be replaced during packaging for beta builds
C.ADDON_NAME = C.ADDON_NAME or "AbahsAppraiser"
C.NAME_SHORT = C.NAME_SHORT or "ASJ"
C.NAMESPACE  = C.NAMESPACE or "ASJ" -- global table name
C.SAVEDVARS  = C.SAVEDVARS or "ASJ_SavedVars"
C.SLASH      = C.SLASH or "/asj_debug"

return ASJ.Config;
