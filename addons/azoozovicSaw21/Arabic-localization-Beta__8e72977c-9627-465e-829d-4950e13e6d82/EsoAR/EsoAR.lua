-- Console-safe language toggle: keep ESO's client language on a supported setting.
local saved = ESOArabicSavedVariables
if type(saved) ~= "table" then
    saved = {}
    ESOArabicSavedVariables = saved
end

local function getCVar(name)
    if type(GetCVar) ~= "function" then return "" end
    return string.lower(tostring(GetCVar(name) or ""))
end

local function setCVar(name, value)
    if type(SetCVar) == "function" then pcall(SetCVar, name, value) end
end

local function hasLegacyArabicClientLanguage()
    return getCVar("language.2") == "ar" or getCVar("LastPlatformLanguage") == "ar"
end

local function needsEnglishRestore()
    return getCVar("language.2") ~= "en"
        or getCVar("LastPlatformLanguage") == "ar"
        or getCVar("IgnorePatcherLanguageSetting") == "1"
end

local function restoreEnglishClientLanguage()
    setCVar("IgnorePatcherLanguageSetting", "0")
    setCVar("LastPlatformLanguage", "en")
    setCVar("language.2", "en")
end

saved.clientStringVersion = tonumber(saved.clientStringVersion) or 100
if saved.arabicMode == nil then
    -- Migrate the state left behind by the old /ar command.
    saved.arabicMode = hasLegacyArabicClientLanguage()
end

local function arabicModeEnabled()
    return saved.arabicMode == true
end
ESO_ARABIC_IS_ACTIVE = arabicModeEnabled

-- Repair the unsupported global Arabic client language used by the previous build.
if hasLegacyArabicClientLanguage() then
    restoreEnglishClientLanguage()
    if getCVar("language.2") == "en" and not saved.legacyArabicLanguageRecovered then
        saved.legacyArabicLanguageRecovered = true
        saved.legacyArabicStringRecoveryPending = true
        zo_callLater(function()
            saved.legacyArabicStringRecoveryPending = false
            ReloadUI()
        end, 100)
    else
        saved.legacyArabicStringRecoveryPending = false
    end
else
    saved.legacyArabicStringRecoveryPending = false
end

local function applyMode(enabled)
    local wasEnabled = arabicModeEnabled()
    local legacyLanguage = hasLegacyArabicClientLanguage()
    local clientNeedsRestore = (not enabled and needsEnglishRestore()) or (enabled and legacyLanguage)

    if not enabled or legacyLanguage then restoreEnglishClientLanguage() end
    saved.arabicMode = enabled
    if wasEnabled ~= enabled then saved.clientStringVersion = saved.clientStringVersion + 3 end

    if wasEnabled == enabled and not clientNeedsRestore then
        d(enabled and "ESO Arabic mode is already enabled." or "ESO Arabic mode is already disabled.")
        return
    end

    d(enabled and "ESO Arabic mode enabled. Client language unchanged. Reloading UI..."
        or "ESO Arabic mode disabled. Client language set to English. Reloading UI...")
    zo_callLater(ReloadUI, 100)
end

SLASH_COMMANDS["/ar"] = function() applyMode(true) end
SLASH_COMMANDS["/en"] = function() applyMode(false) end
SLASH_COMMANDS["/arstatus"] = function()
    d("ESO Arabic 2.2.6 | mode=" .. (arabicModeEnabled() and "AR" or "EN")
        .. " | client-language=" .. tostring(GetCVar("language.2") or "unknown")
        .. " | string-entries=" .. tostring(saved.clientStringEntries or 0))
end