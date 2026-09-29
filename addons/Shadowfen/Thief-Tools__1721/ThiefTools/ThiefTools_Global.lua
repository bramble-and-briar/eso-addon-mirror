local SF = LibSFUtils
 
ThiefTools = {
    name = "ThiefTools",
    version = "3.4.4",
	author = "Shadowfen",
    displayName = "Thief Tools",
}

ThiefTools.displayName = SF.colors.gold(ThiefTools.displayName)
ThiefTools.version = SF.colors.gold(ThiefTools.version)
ThiefTools.author = SF.colors.purple(ThiefTools.author)

SF.LoadLanguage(ThiefTools_localization_strings, "en")

-- Create the delayed instantiation logger functor and utility functions for ThiefTools.
ThiefTools_Logger, ThiefTools.logDebug, ThiefTools.logWouldDebug = 
            SF.InitSafeLogger(ThiefTools, "logger", "ThiefTools")

--[[ The following SetDebug() call is commented out because it severely slows down 
    addon operation. Turning it on does however provide lots and lots of debug logging.
    Never leave this uncommented when releasing!!
--]]
ThiefTools_Logger():SetDebug(true)
