-- Optional integrations. No third-party addon files or global language values
-- are changed. Localized guild trader names get a separate cache per language.
local R = ESO_ARABIC_TEXT

function R.SelectGuildStoreLanguage(data, language)
    if type(data) ~= "table" then return false end
    local current = data.guildStoreList
    if type(current) ~= "table" or not current.language or current.language == language then return false end
    local bank = data.esoArabicGuildStoreLanguages
    if language ~= "ar" and current.language ~= "ar" and not bank then return false end
    bank = bank or {}
    data.esoArabicGuildStoreLanguages = bank
    -- Remove the active entry from the bank: ESO serializes tables by value,
    -- so retaining it in both places would duplicate potentially large caches.
    bank[current.language] = current
    data.guildStoreList = bank[language]
    bank[language] = nil
    return true
end

local function installGuildStore()
    local ags = AwesomeGuildStore
    local api = ags and ags.internal
    if not api or type(api.InitializeGuildStoreList) ~= "function" or api.esoArabic131 then return end
    api.esoArabic131 = true
    local initialize = api.InitializeGuildStoreList
    api.InitializeGuildStoreList = function(data, ...)
        R.SelectGuildStoreLanguage(data, GetCVar("Language.2"))
        return initialize(data, ...)
    end
end

function R.RecoverGuildStore()
    installGuildStore()
    local ags = AwesomeGuildStore
    local api = ags and ags.internal
    if not api or api.storeList or api.esoArabicRecoveryAttempted or not AwesomeGuildStore_Data then return end
    local key = GetWorldName() .. GetDisplayName()
    local data = AwesomeGuildStore_Data[key]
    local current = data and data.guildStoreList
    local language = GetCVar("Language.2")
    if not data or not data.guildTraderListEnabled or not current or not current.language or current.language == language then return end
    if language ~= "ar" and current.language ~= "ar" and not data.esoArabicGuildStoreLanguages then return end
    api.esoArabicRecoveryAttempted = true
    -- AGS can have loaded first and stopped at its language mismatch guard.
    -- Retry only this failed component once, after all addons have loaded.
    local ok, err = pcall(api.InitializeGuildStoreList, data)
    if not ok then
        R.lastError = tostring(err)
        d("ESO Arabic: AwesomeGuildStore recovery: " .. tostring(err))
    end
end

local encounterStrings = {
    PANEL_TITLE = "اللقاءات الديناميكية",
    STATUS_LIVE = "نشط الآن",
    STATUS_LIVE_FOR = "نشط منذ <<1>>",
    STATUS_EXPECTED = "متوقع بعد <<1>> تقريبًا",
    STATUS_OVERDUE = "متوقع في أي لحظة",
    STATUS_COOLDOWN = "انتهى قبل <<1>>",
    STATUS_UNKNOWN = "لا توجد بيانات؛ زر المنطقة",
    STATUS_STALE = "آخر ظهور قبل <<1>>",
    STEP_TIME_LEFT = "المتبقي: <<1>>",
    CONFIDENCE = "تقدير من <<1>> دورات",
    CONFIDENCE_LEARNING = "جار جمع البيانات",
    ARRIVE_EARLY = "احضر قبل الموعد بدقائق",
    YOU_ARE_HERE = "(أنت هنا)",
    ALERT_LIVE = "بدأ لقاء ديناميكي!",
    ALERT_LIVE_SUB = "بدأ <<1>> في <<2>>",
    ALERT_SOON = "لقاء ديناميكي متوقع قريبًا",
    ALERT_SOON_SUB = "<<1>> في <<2>> (تقديري)",
    CHAT_LIVE = "<<1>> نشط الآن في <<2>>!",
    CHAT_ENDED = "انتهى <<1>> في <<2>>. الموعد التالي متوقع بعد <<3>> تقريبًا.",
    CHAT_SOON = "<<1>> في <<2>> متوقع بعد <<3>> تقريبًا.",
    DISCLAIMER = "المواعيد تقديرية، وليست مؤقتات رسمية.",
}
local function installEncounters()
    local addon = DynamicEncounters
    if not addon or type(addon.GetString) ~= "function" or addon.esoArabic131 then return end
    addon.esoArabic131 = true
    local original = addon.GetString
    local prepared = {}
    addon.GetString = function(key, ...)
        if R.IsActive() and encounterStrings[key] then
            prepared[key] = prepared[key] or R.ShapeLogical(encounterStrings[key])
            if select("#", ...) > 0 then return zo_strformat(prepared[key], ...) end
            return prepared[key]
        end
        return original(key, ...)
    end
end

function R.InstallCompatibility()
    installGuildStore()
    installEncounters()
end
EVENT_MANAGER:RegisterForEvent("ESOArabicCompatibility", EVENT_PLAYER_ACTIVATED, function()
    R.InstallCompatibility()
    R.RecoverGuildStore()
end)
