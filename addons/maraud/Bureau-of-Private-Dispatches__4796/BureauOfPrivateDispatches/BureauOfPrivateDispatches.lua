-- Addon namespace and release identity
local ADDON_NAME = "BureauOfPrivateDispatches"
local SAVED_VARIABLES_NAME = "BureauOfPrivateDispatchesSavedVariables"
-- Deliberately still 1. SanitizePosition migrates older left/top keys in place.
-- Raising this number would make ZO_SavedVars discard the previous profile and
-- throw away panel placement and unanswered-whisper restore.
local SAVED_VARIABLES_VERSION = 1

-- The manifest is the only other place that carries the release number because
-- ESO exposes no API for reading `## Version` at runtime. Keep the two values in
-- step when preparing a release.
BureauOfPrivateDispatches =
{
	name = ADDON_NAME,
	savedVariablesName = SAVED_VARIABLES_NAME,
	savedVariablesVersion = SAVED_VARIABLES_VERSION,
	version = "1.1.012551",
	private = {},
	isInitialized = false,
}