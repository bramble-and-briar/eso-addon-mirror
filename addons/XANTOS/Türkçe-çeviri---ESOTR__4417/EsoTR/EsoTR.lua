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

local ADDON_NAME = "EsoTR"
EsoTR = {}
EsoTR.Version = "1.0.6a"

-- >>> EKLENDİ: Session bazlı mesaj kontrol bayrakları
local sessionLanguageMessageShown = false
local sessionUpdateMessageShown   = false
local sessionConflictMessageShown = false

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
local ESOTR_PREFIX = "|c00FF00[ESOTR]|r"

local function ESOTR_Message(msg, delay)
    delay = delay or 1000 -- Varsayılan gecikme 1 saniye
    zo_callLater(function()
        if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage and not IsConsoleUI() then
            CHAT_SYSTEM:AddMessage(ESOTR_PREFIX .. " " .. msg)
        else
            d(ESOTR_PREFIX .. " " .. msg)
        end
    end, delay)
end

-- ------------------------------------------------------------
-- DİL DEĞİŞTİRME
-- ------------------------------------------------------------
local function ESOTR_Change(lang)
    if GetCVar("language.2") ~= lang then
        SetCVar("IgnorePatcherLanguageSetting", "1")
        SetCVar("language.2", lang)
        SetCVar("LastPlatformLanguage", lang)
        savedVars.lastLang = lang
    end
end

local function ESOTR_GetLanguage()
    local lang = GetCVar("language.2")
    return lang == "tr" and "tr" or "en"
end

local function OnLanguageChange(value)
    local selectedLang = value and "tr" or "en"
    if selectedLang ~= ESOTR_GetLanguage() then
        ESOTR_Change(selectedLang)
    end
end

-- ------------------------------------------------------------
-- AYAR PANELİ (SADECE LAM İLE)
-- ------------------------------------------------------------
local function CreateSettingsPanel()
    local LAM = LibAddonMenu2 or (LibStub and LibStub:GetLibrary("LibAddonMenu-2.0", true))
    if not LAM then return end

    local panelName = "EsoTR_SettingsPanel"

    local optionsTable = {
        {
            type = "header",
            name = "Genel Ayarlar",
        },
        {
            type = "checkbox",
            name = "Türkçeye değiştir",
            tooltip = "Varsayılan dil ile Türkçe arasında geçiş yap.",
            getFunc = function() return ESOTR_GetLanguage() == "tr" end,
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
                "• Değişiklikler açık kitapta anında uygulanır.\n" ..
                "• Gamepad / PS5 modunda okunabilirlik otomatik olarak artırılır.\n" ..
                "• 10–12 arası değerler TV / Koltuk mesafesi için önerilir.",
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
        name = "ESoTR_Ayar",
        displayName = "ESO’nun resmi olmayan Türkçe çevirisi",
        author = "XANTOS-TR & BALGAMOV",
        version = EsoTR.Version,
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

    savedVars = ZO_SavedVars:NewAccountWide("EsoTR_SavedVars", 1, nil, defaultSettings)

    if savedVars.persistLanguage and savedVars.lastLang then
        ESOTR_Change(savedVars.lastLang)
    end

    CreateSettingsPanel()

    -- CHAT UYARI MANTIĞI (KÜTÜPHANE DURUMU)
    if not LibAddonMenu2 then
        if LibHarvensAddonSettings then
            ESOTR_Message("|cFFAA00Ayarlara ulaşmak için LibAddonMenu-2.0 kurulması gereklidir.|r")
        else
            ESOTR_Message("|cFF0000Gerekli kütüphaneler bulunamadı, lütfen kontrol edin!|r", 1000)
			ESOTR_Message("|cFFAA00LibAddonMenu-2.0 ve LibHarvensAddonSettings kurulu değil.|r", 1250)
            ESOTR_Message("|cFFAA00Ayar penceresi bu nedenle görüntülenmeyecektir.|r", 1500)
        end
    end

    -- SÜRÜM GÜNCELLEME MESAJI (YEŞİL)
    if savedVars.lastSeenVersion ~= EsoTR.Version and not sessionUpdateMessageShown then
        ESOTR_Message("|c00FF00Güncellendi! Yeni sürüm: v" .. EsoTR.Version .. "|r")
        sessionUpdateMessageShown = true
        savedVars.lastSeenVersion = EsoTR.Version
    end

    -- 🔴 EsoTR (Full) + EsoTR Lite aynı anda yüklüyse UYARI !
    if _G["EsoTR_Lite"] and not sessionConflictMessageShown then
    ESOTR_Message("|cFF0000Uyarı: ESO Türkçe (Full) ve ESO Türkçe (Lite) aynı anda yüklü!|r", 1000)
    ESOTR_Message("|cFFCC00Bu iki sürümün birlikte yüklü olması arayüz sorunlarına yol açacaktır.|r", 1250)
    ESOTR_Message("|cFFCC00Lütfen ADD-ONS menüsünden kullanmadığınız sürümü tamamen SİLİN.|r", 1500)

    sessionConflictMessageShown = true
end

    -- Türkçe kapalıyken session bazlı bilgi mesajı (SARI)
    if ESOTR_GetLanguage() ~= "tr" and not sessionLanguageMessageShown then
        ESOTR_Message("|cFFCC00Türkçe için ADD-ONS → ESOTR_Ayar menüsünden etkinleştirin.|r")
        sessionLanguageMessageShown = true
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- ================================================================= -- 
-- V2.1 /kitap Komutu - EsoTR
-- PC’de ve erişilebilirlik modunda kitap fontunu değiştirir.
-- Konsolda (PS5/XBOX) desteklenmez.
-- Bu sistem kendi içinde çalışmaktadır ANA ADDON bağlı değildir.
-- ================================================================= --

local PREFIX = "|c00FF00[ESOTR]|r"

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