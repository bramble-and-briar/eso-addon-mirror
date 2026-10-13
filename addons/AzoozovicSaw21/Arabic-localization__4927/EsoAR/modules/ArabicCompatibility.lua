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

local lootStrings = {
    Gold = "ذهب", Experience = "نقاط خبرة", AlliancePoints = "نقاط التحالف",
    VeterancyPoints = "نقاط المخضرمين", TelvarStones = "أحجار تل فار",
    WritVouchers = "قسائم التكليفات", UndauntedKeys = "مفاتيح الشجعان",
    TransmuteCrystals = "بلورات التحويل", EventTickets = "تذاكر الفعاليات",
    Endeavor = "أختام المساعي", Endless = "الثروات الأرشيفية", Fragment = "الشظايا الإمبراطورية",
    TomePoints = "نقاط المجلد", TomePointCaches = "صناديق نقاط المجلد",
    TomeTokens = "رموز المجلد المميزة", TradeBars = "سبائك التجارة",
    CompanionXP = "خبرة الرفيق", CompanionRapport = "الألفة مع الرفيق", Rapport = "الألفة",
    LevelPsijic = "المستوى", CAchievement = "اكتمل!", AProgress = "التقدم:",
    Loot = "الغنائم", Achievements = "الإنجازات", SkillDisplay = "المهارات",
    Everything = "جميع المكاسب غير العينية", SelectPreview = "اختر وضع المعاينة",
    ValueNone = " (لا توجد بيانات)", Companions = "الرفاق", Currencies = "العملات",
    CraftXP = "خبرة الحرف", FenceXP = "خبرة تصريف المسروقات", GuildReputation = "سمعة النقابة",
}
local lootOriginals = setmetatable({}, {__mode = "k"})
local function installLootDrop()
    if not LootDrop_Strings or type(LootDrop_Strings.GetLanguage) ~= "function" then return end
    -- LootDrop retains this table locally. Update its values, never replace it
    -- or modify its files/SavedVariables. Both popup and chat read these keys.
    local strings = LootDrop_Strings:GetLanguage()
    if type(strings) ~= "table" then return end
    local originals = lootOriginals[strings]
    if not originals then
        originals = {}; lootOriginals[strings] = originals
        for key in pairs(lootStrings) do originals[key] = strings[key] end
    end
    for key, value in pairs(lootStrings) do
        if originals[key] then
            strings[key] = R.IsActive() and R.Compose(R.ShapeLogical(value)) or originals[key]
        end
    end
    -- Never wrap native control creation: XML interaction handlers must retain
    -- their secure origin. Arabic label discovery handles LootDrop labels.

end
R.InstallLootDropArabic = installLootDrop
EVENT_MANAGER:RegisterForEvent("ESOArabicLootDrop", EVENT_ADD_ON_LOADED, function(_, name)
    if name == "LootDrop" then installLootDrop() end
end)
EVENT_MANAGER:RegisterForEvent("ESOArabicLootDropReady", EVENT_PLAYER_ACTIVATED, installLootDrop)
installLootDrop()

-- AwesomeGuildStore keyboard result rows have two separate one-line labels.
-- Keep this adapter local to AGS; never change its saved searches or prices.
do
    local strings = {
        ["Sort By"] = "ترتيب حسب", ["Unit Price"] = "سعر الوحدة",
        ["Price Range"] = "نطاق السعر", ["Level Range"] = "نطاق المستوى",
        ["Quality Range"] = "نطاق الجودة", ["Text Search"] = "البحث بالنص",
        ["Unit Price Range"] = "نطاق سعر الوحدة", ["Recipe Knowledge"] = "معرفة الوصفة",
        ["Recipe Type"] = "نوع الوصفة", ["Seller Name"] = "اسم البائع",
        ["Seller:|cffffff <<1>>"] = "البائع: |cffffff<<1>>|r",
    }
    local function label(control, width, size, autoWidth)
        if not control then return end
        local refresh = R.BindLabel(control, {single = true, flow = false,
            width = width, size = size, minimum = 14, height = 24,
            autoWidth = autoWidth, reflowVisual = true})
        control:SetMaxLineCount(1)
        if refresh then refresh() end
    end
    local function rowLayout(row)
        if not R.IsActive() then return end
        label(row:GetNamedChild("Name"), 310, 20, false)
        local seller = row.sellerName
        if seller then
            seller:SetWidth(300)
            label(seller, 300, 16, false)
        end
        label(row:GetNamedChild("TimeRemaining"), 65, 18, false)
    end
    local function resultList(self)
        if not self.list or not self.list.list then return end
        for _, id in ipairs({1, 3}) do
            local dataType = ZO_ScrollList_GetDataTypeTable(self.list.list, id)
            if dataType and not dataType.esoArabicAGS5 then
                dataType.esoArabicAGS5 = true
                local original = dataType.setupCallback
                dataType.setupCallback = function(row, data, ...)
                    original(row, data, ...)
                    rowLayout(row)
                end
            end
        end
    end
    local function headers(self, wrapper)
        if not R.IsActive() then return end
        local container = wrapper.tradingHouse.searchSortHeaders.headerContainer
        for key, text in pairs({Price = "الإجمالي", PricePerUnit = "للوحدة", TimeRemaining = "المدة"}) do
            local header = container:GetNamedChild(key)
            local name = header and header:GetNamedChild("Name")
            if name then
                label(name, nil, 18, true)
                name:SetText(R.Compose(R.ShapeLogical(text)))
            end
        end
    end
    function R.InstallGuildStoreRows()
        local ags = AwesomeGuildStore
        if not ags or not ags.class then return end
        -- Captured gettext closures still call this dictionary method. Gate it
        -- on Arabic activation rather than overwriting the third-party dictionary.
        if LibGetText then
            local dictionary = LibGetText("AwesomeGuildStore")
            if not dictionary.esoArabicAGS5 then
                dictionary.esoArabicAGS5 = true
                local original = dictionary.GetText
                dictionary.GetText = function(self, text, ...)
                    if R.IsActive() and strings[text] then
                        local translated = R.Compose(R.ShapeLogical(strings[text]))
                        if select("#", ...) > 0 then return zo_strformat(translated, ...) end
                        return translated
                    end
                    return original(self, text, ...)
                end
            end
        end
        local class = ags.class.SearchResultListWrapper
        if class and not class.esoArabicAGS5 then
            class.esoArabicAGS5 = true
            SecurePostHook(class, "InitializeResultList", resultList)
            SecurePostHook(class, "InitializeSortHeaders", headers)
        end
        local fragment = ags.class.FilterFragment
        if fragment and not fragment.esoArabicAGS5 then
            fragment.esoArabicAGS5 = true
            SecurePostHook(fragment, "SetLabelText", function(self)
                if R.IsActive() then label(self.label, 300, 20, false) end
            end)
        end
        local wrapper = ags.internal and ags.internal.tradingHouse
        local existing = wrapper and wrapper.searchTab and wrapper.searchTab.searchResultList
        if existing then resultList(existing); headers(existing, wrapper) end
    end
    EVENT_MANAGER:RegisterForEvent("ESOArabicGuildStoreRows", EVENT_PLAYER_ACTIVATED, R.InstallGuildStoreRows)
end
