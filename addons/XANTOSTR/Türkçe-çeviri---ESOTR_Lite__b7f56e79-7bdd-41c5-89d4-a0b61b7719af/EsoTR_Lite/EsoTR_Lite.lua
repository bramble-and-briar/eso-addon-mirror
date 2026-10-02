-- ==================================================
--  XANTOS-TR TARAFINDAN YAZILMIŞTIR
-- ==================================================
--  Bu kod, sıradan bir script değildir.
--  Bu kod; düzeni, kaliteyi ve Türkçe'nin onurunu
--  korumak için XANTOS-TR tarafından üretilmiştir.
--
--  Yazar:
--   XANTOS-TR
--
--  Ünvanlar:
--   • Kod Mimarı
--   • Metin Cerrahı
--   • Dil Dosyası Ustası
--   • Mantık ve Düzen Muhafızı
--
--  Felsefe:
--   "Bozuk metin kalmasın,
--    satır yapısı bozulmasın,
--    emek çöpe gitmesin."
--
--  Bu projeyi kullanıyorsan:
--   ✔ Disiplinli kod kullanıyorsun
--   ✔ Kaosa karşı duruyorsun
--   ✔ XANTOS-TR ekolünü destekliyorsun
--
--  Topluluk & Destek:
--   🔵 Discord: https://discord.gg/z2uRerq7FP
--
--  Not:
--   Bu kodu düzenleyebilirsin,
--   geliştirebilirsin,
--   ama XANTOS-TR imzası burada kalır. 😎
--
-- ==================================================

local ADDON_NAME = "EsoTR_Lite"
EsoTR_Lite = {}
EsoTR_Lite.Version = "1.0.4a"

-- Session bazlı mesaj kontrol bayrakları
local sessionLanguageMessageShown = false
local sessionUpdateMessageShown   = false
local sessionInfoMessageShown     = false

-- ------------------------------------------------------------
-- VARSAYILAN AYARLAR
-- ------------------------------------------------------------
local defaultSettings = {
    persistLanguage = false,
    lastLang = "en",
    bookFontScale = 0,
    lastSeenVersion = "",
}

local savedVars

-- ------------------------------------------------------------
-- CHAT MESAJ SİSTEMİ MERKEZİ (PC + Konsol uyumlu, gecikmeli)
-- ------------------------------------------------------------
local ESOTR_Lite_PREFIX = "|c00FF00[ESOTR_Lite]|r"

local function ESOTR_Lite_Message(msg, delay)
    delay = delay or 1000 -- Varsayılan gecikme 1 saniye
    zo_callLater(function()
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage and not IsConsoleUI() then
            CHAT_SYSTEM:AddMessage(ESOTR_Lite_PREFIX .. " " .. msg)
        else
            d(ESOTR_Lite_PREFIX .. " " .. msg)
        end
    end, delay)
end

-- ------------------------------------------------------------
-- DİL DEĞİŞTİRME
-- ------------------------------------------------------------
local function EsoTR_Lite_Change(lang)
    if GetCVar("language.2") ~= lang then
        SetCVar("IgnorePatcherLanguageSetting", "1")
        SetCVar("language.2", lang)
        SetCVar("LastPlatformLanguage", lang)
        savedVars.lastLang = lang
    end
end

local function EsoTR_Lite_GetLanguage()
    local lang = GetCVar("language.2")
    return lang == "tr" and "tr" or "en"
end

local function OnLanguageChange(value)
    local selectedLang = value and "tr" or "en"
    if selectedLang ~= EsoTR_Lite_GetLanguage() then
        EsoTR_Lite_Change(selectedLang)
    end
end

-- ------------------------------------------------------------
-- AYAR PANELİ
-- ------------------------------------------------------------
local function CreateSettingsPanel()
    local LAM = LibAddonMenu2 or (LibStub and LibStub:GetLibrary("LibAddonMenu-2.0", true))
    if not LAM then return end

    local panelName = "EsoTR_Lite_SettingsPanel"

    local optionsTable = {

        {
            type = "header",
            name = "Genel Ayarlar",
        },

        {
            type = "checkbox",
            name = "Türkçeye değiştir",
            tooltip = "Varsayılan dil ile Türkçe arasında geçiş yap.",
            getFunc = function() return EsoTR_Lite_GetLanguage() == "tr" end,
            setFunc = OnLanguageChange,
            default = false,
        },

        {
            type = "checkbox",
            name = "Bir sonraki başlatmada dili koru",
            tooltip = "Oyun bir sonraki açılışta seçilen dili korur.",
            getFunc = function()
                return GetCVar("IgnorePatcherLanguageSetting") == "1"
            end,
            setFunc = function(value)
                SetCVar("IgnorePatcherLanguageSetting", value and "1" or "0")
            end,
            default = false,
        },

        {
            type = "header",
            name = "Yazı Ayarları",
        },

        {
            type = "slider",
            name = "Kitap & Not Yazı Boyutu",
            tooltip =
                "Kitap, not ve benzeri okunabilir metinlerin yazı boyutunu ayarlar.\n\n" ..
                "• Açık kitapta anında uygulanır.\n" ..
                "• Konsol (PS5) için optimize.\n" ..
                "• Konsol (XBOX) için optimize.",
            min = 0,
            max = 12,
            step = 1,
            getFunc = function()
                return savedVars.bookFontScale or 0
            end,
            setFunc = function(value)
                savedVars.bookFontScale = value
                if SCENE_MANAGER and SCENE_MANAGER:IsShowing("book") then
                    HideBook()
                    zo_callLater(function()
                        ShowBook()
                    end, 50)
                end
            end,
            default = 0,
        },

        {
            type = "description",
            text = " ",
        },

        {
            type = "button",
            name = "UI’yi yeniden başlat",
            tooltip = "Değişiklikleri uygulamak için kullanıcı arayüzünü yeniden başlatır.",
            func = function()
                zo_callLater(function()
                    ReloadUI()
                end, 100)
            end,
            width = "full",
        },
    }

    local panelData = {
        type = "panel",
        name = "EsoTR_Lite_Ayar",
        displayName = "ESO Türkçe (Lite - Kitapsız)",
        author = "XANTOS-TR & BALGAMOV",
        version = EsoTR_Lite.Version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsTable)
end

-- ------------------------------------------------------------
-- ADDON YÜKLEME
-- ------------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide(
        "EsoTR_Lite_SavedVars",
        1,
        nil,
        defaultSettings
    )

    if savedVars.persistLanguage and savedVars.lastLang then
        EsoTR_Lite_Change(savedVars.lastLang)
    end

    CreateSettingsPanel()
	
   -- CHAT UYARI MANTIĞI (KÜTÜPHANE DURUMU)
    if not LibAddonMenu2 then
        if LibHarvensAddonSettings then
            ESOTR_Lite_Message("|cFFAA00Ayarlara ulaşmak için LibAddonMenu-2.0 kurulması gereklidir.|r")
        else
            ESOTR_Lite_Message("|cFF0000Gerekli kütüphaneler bulunamadı, lütfen kontrol edin!|r", 1000)
			ESOTR_Lite_Message("|cFFAA00LibAddonMenu-2.0 ve LibHarvensAddonSettings kurulu değil.|r", 1250)
            ESOTR_Lite_Message("|cFFAA00Ayar penceresi bu nedenle görüntülenmeyecektir.|r", 1500)
        end
    end
	
    -- SÜRÜM GÜNCELLEME MESAJI (YEŞİL)
    if savedVars.lastSeenVersion ~= EsoTR_Lite.Version and not sessionUpdateMessageShown then
        ESOTR_Lite_Message("|c00FF00Güncellendi! Yeni sürüm: v" .. EsoTR_Lite.Version .. "|r")
        sessionUpdateMessageShown = true
        savedVars.lastSeenVersion = EsoTR_Lite.Version
    end
	
    -- KİTAP İÇERİKLERİ KALDIRILDI (MOR)
    if not sessionInfoMessageShown then
        ESOTR_Lite_Message("|cAAAAFFBu sürümde okunabilir içerikler bulunmaz.|r")
        sessionInfoMessageShown = true
    end
	
    -- Türkçe kapalıyken session bazlı bilgi mesajı (SARI)
    if EsoTR_Lite_GetLanguage() ~= "tr" and not sessionLanguageMessageShown then
        ESOTR_Lite_Message("|cFFCC00Türkçe için ADD-ONS → EsoTR_Lite_Ayar menüsünden etkinleştirin.|r")
        sessionLanguageMessageShown = true
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- ================================================================= --
-- V2.1 /kitap Komutu - ESOTR_Lite
-- PC’de ve erişilebilirlik modunda kitap fontunu değiştirir.
-- Konsolda (PS5/XBOX) desteklenmez.
-- Bu sistem kendi içinde çalışmaktadır ANA ADDON bağlı değildir.
-- ================================================================= --

local PREFIX = "|c00FF00[ESOTR_Lite]|r"

SLASH_COMMANDS["/kitap"] = function(input)

    -- Konsol kontrolü (PS5/XBOX)
    if IsConsoleUI and IsConsoleUI() then
        d(PREFIX .. " → /kitap komutu konsol sürümünde desteklenmez.")
        return
    end
	
    local num = tonumber(input)

    -- Sayı geçerli mi kontrol
    if num == nil or num < 0 or num > 12 then
        d(PREFIX .. " → Lütfen 0–12 arası bir sayı girin.")
        return
    end

    -- PC veya erişilebilirlik modunda uygulama
    if savedVars then
        savedVars.bookFontScale = num
    end
    d(PREFIX .. " → Kitap yazı boyutu " .. num .. " olarak ayarlandı.")

    if SCENE_MANAGER and SCENE_MANAGER:IsShowing("book") then
        HideBook()
        zo_callLater(function()
            ShowBook()
        end, 50)
    end
end
-- ================================================================= --