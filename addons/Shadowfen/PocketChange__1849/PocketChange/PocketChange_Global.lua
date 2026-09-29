local SF = LibSFUtils
local LL = LibLanguage

PocketChange = {
	name = "PocketChange",
	displayname = "PocketChange",

	author = "Shadowfen",
	version = "1.38",
	savedVarVersion = "1",
}
PocketChange.displayName = SF.colors.gold(PocketChange.displayName)
PocketChange.author = SF.colors.purple(PocketChange.author)
PocketChange.version = SF.colors.gold(PocketChange.version)

PocketChange.evtmgr = SF.EvtMgr:New(PocketChange.name)

--LL.LoadLanguage(PocketChange_localization_strings, "en")

PocketChange_Logger, PocketChange.logDebug, PocketChange.wouldLogDebug = SF.InitSafeLogger(PocketChange, "logger", "PocketChange")
--PocketChange_Logger():SetDebug(true)
