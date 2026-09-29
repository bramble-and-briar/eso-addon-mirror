-- This is always the first source file loaded so that
-- it can create the addon table/namespace.

-- It also loads strings for the proper language.


local SF = LibSFUtils
local LL = LibLanguage

DefaultGuildBank = {
	name = "DefaultGuildBank",
	displayname = "Shadowfen's Default Guild Bank",
	version = "1.24",
	author = "Shadowfen",

	evtmgr = SF.EvtMgr:New("DefaultGuildBank")
}
local SGB = DefaultGuildBank
SGB.version = SF.colors.gold(SGB.version)
SGB.author = SF.colors.purple(SGB.author)
SGB.displayName = SF.colors.gold(SGB.name)

LL.LoadLanguage(DefaultGuildBank_localization_strings, "en")

DefaultGuildBank_Logger, SGB.logDebug, SGB.wouldLogDebug = SF.InitSafeLogger(DefaultGuildBank, "logger", "DefaultGuildBank")
--DefaultGuildBank_Logger():SetDebug(true)