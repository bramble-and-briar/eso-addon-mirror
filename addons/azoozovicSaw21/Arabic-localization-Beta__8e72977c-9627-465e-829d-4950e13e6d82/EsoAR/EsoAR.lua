local function switchLanguage(code)
    if GetCVar("language.2") == code then
        d(code == "ar" and "Arabic is already selected." or "English is already selected.")
        return
    end
    SetCVar("IgnorePatcherLanguageSetting", "1")
    SetCVar("LastPlatformLanguage", code)
    SetCVar("language.2", code)
    d(code == "ar" and "Arabic selected. Reloading the interface..." or "English selected. Reloading the interface...")
    zo_callLater(ReloadUI, 100)
end
SLASH_COMMANDS["/ar"] = function() switchLanguage("ar") end
SLASH_COMMANDS["/en"] = function() switchLanguage("en") end
