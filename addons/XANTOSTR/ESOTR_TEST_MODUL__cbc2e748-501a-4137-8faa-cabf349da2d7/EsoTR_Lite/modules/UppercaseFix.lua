
-- =========================================================
-- ESOTR - TURKISH LABEL CASE FIX
-- VERSION: 2.0.2
--
-- CENTRAL LABEL METATABLE HOOK
--
-- Hedef:
-- ESO'nun ortak Label SetText metodunu yakalamak.
-- Yalnızca UPPERCASE modundaki Label metinlerini düzeltmek.
--
-- Skill / Quest / Inventory gibi ayrı bölüm hook'ları YOK.
-- ESO'nun normal büyük harf davranışı korunur.
-- =========================================================

EsoTR = EsoTR or {}
EsoTR.TurkishCaseFix = EsoTR.TurkishCaseFix or {}

local M = EsoTR.TurkishCaseFix

M.version = "2.0.2"

M.intercepted = M.intercepted or 0
M.converted = M.converted or 0
M.hooked = M.hooked or false

-- ---------------------------------------------------------
-- TÜRKÇE BÜYÜK HARF DÖNÜŞÜMÜ
-- Yalnızca Türkçe küçük harfleri dönüştürür.
-- Diğer karakterlere dokunmaz.
-- ---------------------------------------------------------

local function TurkishUpper(text)
    if type(text) ~= "string" then
        return text
    end

    text = text:gsub("i", "İ")
    text = text:gsub("ı", "I")
    text = text:gsub("ç", "Ç")
    text = text:gsub("ğ", "Ğ")
    text = text:gsub("ö", "Ö")
    text = text:gsub("ş", "Ş")
    text = text:gsub("ü", "Ü")

    return text
end

M.TurkishUpper = TurkishUpper

-- ---------------------------------------------------------
-- LABEL BÜYÜK HARF MODU KONTROLÜ
--
-- Normal metinleri değiştirmemek için SetModifyTextType
-- tarafından belirlenen mevcut modu kontrol eder.
-- ---------------------------------------------------------

local function IsUppercaseLabel(self)
    if MODIFY_TEXT_TYPE_UPPERCASE == nil then
        return false
    end

    if not self or type(self.GetModifyTextType) ~= "function" then
        return false
    end

    local success, textType = pcall(self.GetModifyTextType, self)

    if not success then
        return false
    end

    return textType == MODIFY_TEXT_TYPE_UPPERCASE
end

-- ---------------------------------------------------------
-- ORTAK LABEL SETTEXT METODUNU BUL
--
-- DummyLabel ve standart Label aynı native metatable
-- yapısını kullandığı için ortak metodu buradan buluyoruz.
-- ---------------------------------------------------------

local function FindSetTextOwner(meta)
    if type(meta) ~= "table" then
        return nil
    end

    if type(meta.SetText) == "function" then
        return meta
    end

    local index = meta.__index

    if type(index) == "table" and type(index.SetText) == "function" then
        return index
    end

    return nil
end

-- ---------------------------------------------------------
-- ORTAK SETTEXT HOOK
-- ---------------------------------------------------------

local function InstallLabelHook()
    if M.hooked then
        return true
    end

    if not ZO_LABEL_TEMPLATE_DUMMY_LABEL then
        return false
    end

    local success, meta = pcall(
        getmetatable,
        ZO_LABEL_TEMPLATE_DUMMY_LABEL
    )

    if not success or type(meta) ~= "table" then
        return false
    end

    local owner = FindSetTextOwner(meta)

    if not owner then
        return false
    end

    local originalSetText = owner.SetText

    if type(originalSetText) ~= "function" then
        return false
    end

    -- Aynı metoda ikinci kez hook kurulmasını engelle.
    if M.originalSetText then
        return false
    end

    M.originalSetText = originalSetText
    M.setTextOwner = owner

    owner.SetText = function(self, text, ...)
        M.intercepted = M.intercepted + 1

        -- Sadece ESO'nun büyük harf uyguladığı Label'lar.
        if type(text) == "string" and IsUppercaseLabel(self) then
            local correctedText = TurkishUpper(text)

            if correctedText ~= text then
                text = correctedText
                M.converted = M.converted + 1
            end
        end

        -- ESO'nun orijinal SetText davranışını koru.
        return originalSetText(self, text, ...)
    end

    M.hooked = true

    return true
end

-- ---------------------------------------------------------
-- BAŞLATMA VE GÜVENLİ TEKRAR DENEME
-- ---------------------------------------------------------

local function Initialize()
    if InstallLabelHook() then
        return
    end

    -- Label metatable henüz hazır değilse oyuncu
    -- dünyaya girdiğinde bir kez daha dene.
    if EVENT_MANAGER then
        EVENT_MANAGER:RegisterForEvent(
            "ESOTR_TurkishCaseFix_Retry",
            EVENT_PLAYER_ACTIVATED,
            function()
                EVENT_MANAGER:UnregisterForEvent(
                    "ESOTR_TurkishCaseFix_Retry",
                    EVENT_PLAYER_ACTIVATED
                )

                InstallLabelHook()
            end
        )
    end
end

-- ---------------------------------------------------------
-- TANILAMA KOMUTU
-- /esotrcasev2
-- ---------------------------------------------------------

SLASH_COMMANDS = SLASH_COMMANDS or {}

SLASH_COMMANDS["/esotrcasev2"] = function()
    d("|cFFD700ESOTR Türkçe Karakter Sistemi|r")
    d("Sürüm: " .. M.version)

    if M.hooked then
        d("|c00FF00Ortak Label SetText hook: AKTİF|r")
    else
        d("|cFF0000Ortak Label SetText hook: PASİF|r")
    end

    d("Yakalanan SetText çağrısı: " .. tostring(M.intercepted))
    d("Türkçe dönüşüm yapılan çağrı: " .. tostring(M.converted))

    d("Büyük harf modu: " ..
        tostring(MODIFY_TEXT_TYPE_UPPERCASE))

    d("Türkçe karakter örneği: " ..
        TurkishUpper("i ı ç ğ ö ş ü"))

    d("|cAAAAAANormal metinler değiştirilmez.|r")
end

-- ---------------------------------------------------------
-- ADDON BAŞLAT
-- ---------------------------------------------------------

Initialize()
