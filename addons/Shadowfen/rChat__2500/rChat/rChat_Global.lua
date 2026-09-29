-- This is always the first source file loaded so that
-- it can create the addon table/namespace.

-- It also loads strings for the proper language.


local SF = LibSFUtils

rChat = {
    name = "rChat",
    version = SF.colors.gold("2.0.6"),
    settingName = "rChat",
    settingDisplayName = SF.colors.gold("rChat"),
    author =  SF.colors.purple("Shadowfen"),
    savedvar = "RCHAT_OPTS",
    sv_version = 2,
    evtmgr = SF.EvtMgr:New("rChat"),
    hookmgr = SF.HookManager:New("rChat"),
}

-- Create the delayed instantiation logger functor and utility functions for AutoCategory.
rChat_Logger, rChat.logDebug, rChat.logWouldDebug = 
            SF.InitSafeLogger(rChat, "logger", "rChat")

--[[ The following SetDebug() call is commented out because it severely slows down 
    addon operation. Turning it on does however provide lots and lots of debug logging.
    Never leave this uncommented when releasing!!
--]]
--rChat_Logger():SetDebug(true)

SF.LoadLanguage(rChat_localization_strings, "en")

rChat.data = {
    cachedMessages = {}, -- This must be init before OnAddonLoaded because it will receive data before this event.
}

