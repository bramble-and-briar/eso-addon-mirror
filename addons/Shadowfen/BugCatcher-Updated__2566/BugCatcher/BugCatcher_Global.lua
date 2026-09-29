local SF = LibSFUtils
local SF_Color = SF.SF_Color

BugCatcher = {
    name = "BugCatcher",
    version = "043",
	author = "Werewolf Finds Dragon, Shadowfen",
    displayName = "Bug Catcher - Updated",
    evtmgr = SF.EvtMgr:New("BugCatcher"),

    colors = {
        red     = SF_Color:New("e74c3c"),
        blue    = SF_Color:New("aaaaff"),
        yellow  = SF_Color:New("f1c40f"),
        cyan    = SF_Color:New("aaffff"),
        grey    = SF_Color:New("b2babb"),
        white   = SF_Color:New("ffffff"),
    }
}

BugCatcher.displayName = SF.str(SF.colors.ltskyblue(BugCatcher.displayName)," - ",SF.colors.goldenrod("Bug Log"))
BugCatcher.version = SF.colors.gold(BugCatcher.version)
BugCatcher.author = SF.colors.epic(BugCatcher.author)

-- Returns a function to return a logger object when it is called (creating one if necessary first)
BugC_Logger = SF.SafeLoggerFunction(BugCatcher, "logger", "BugCatcher")

--[[
    The following SetDebug() call is commented out because it severely slows down 
    addon operation. Turning it on does however provide lots and lots of debug logging.
    Never leave this uncommented when releasing!!
--]]
--BugC_Logger():SetDebug(true)



SF.LoadLanguage(BugCatcher_localization_strings, "en")
