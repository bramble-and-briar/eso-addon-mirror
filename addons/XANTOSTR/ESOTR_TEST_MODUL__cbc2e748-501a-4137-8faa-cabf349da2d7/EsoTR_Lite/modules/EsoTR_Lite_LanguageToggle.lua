-- ================================================ --
--  XANTOS-TR TARAFINDAN YAZILMIŞTIR                --
-- ================================================ --
-- ESOTR_Lite Language Toggle PC                    --
-- Konsolda (PS/XBOX) desteklenmez                  --
-- Dil değişimi (mesaj sadece komut sonrası)        --
-- Author: Ramazan USLU (XANTOS-TR)                 --
-- ================================================ --

local ADDON_NAME = "EsoTR_Lite_LanguageToggle"
local PREFIX = "|c00FF00[ESOTR_Lite]|r"

-- EsoTR_Lite ana addonundan gelen SavedVars kullanılır
EsoTR_Lite_SavedVars = EsoTR_Lite_SavedVars or {}

-- ---------------------------------------------------------
-- PLAYER AKTİF → SADECE FLAG VARSA MESAJ
-- ---------------------------------------------------------
local function OnPlayerActivated()
    if not EsoTR_Lite_SavedVars.runtimeLangMessage then return end
    if not CHAT_SYSTEM or not CHAT_SYSTEM.AddMessage then return end

    local lang = GetCVar("language.2")

    if lang == "en" then
        CHAT_SYSTEM:AddMessage(PREFIX .. " → [Language: English]")
    else
        CHAT_SYSTEM:AddMessage(PREFIX .. " → [Dil: Türkçe]")
    end

    -- 🔒 Mesaj tek seferlik
    EsoTR_Lite_SavedVars.runtimeLangMessage = nil
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_PLAYER_ACTIVATED,
    OnPlayerActivated
)

-- ---------------------------------------------------------
-- /en Konsol kontrolü (PS5/XBOX)
-- ---------------------------------------------------------
SLASH_COMMANDS["/en"] = function()
    if IsInGamepadPreferredMode() and IsConsoleUI() then
        d(PREFIX .. " → /en komutu konsol sürümünde desteklenmez.")
        return
    end

    -- /en durum bilgisi
    if GetCVar("language.2") == "en" then
        CHAT_SYSTEM:AddMessage(PREFIX .. " → [Language Already: English]")
        return
    end

    -- Mesajı reload sonrası basmak için flag
    EsoTR_Lite_SavedVars.runtimeLangMessage = true

    SetCVar("IgnorePatcherLanguageSetting", "1")
    SetCVar("language.2", "en")
end

-- ---------------------------------------------------------
-- /tr Konsol kontrolü (PS5/XBOX)
-- ---------------------------------------------------------
SLASH_COMMANDS["/tr"] = function()
    if IsInGamepadPreferredMode() and IsConsoleUI() then
        d(PREFIX .. " → /tr komutu konsol sürümünde desteklenmez.")
        return
    end

    -- /tr durum bilgisi
    if GetCVar("language.2") == "tr" then
        CHAT_SYSTEM:AddMessage(PREFIX .. " → [Dil Zaten: Türkçe]")
        return
    end

    -- Mesajı reload sonrası basmak için flag
    EsoTR_Lite_SavedVars.runtimeLangMessage = true

    SetCVar("IgnorePatcherLanguageSetting", "1")
    SetCVar("language.2", "tr")
end

-- ================================================================================================================== --
-- Bu addon, /en ve /tr komutları aracılığıyla oyun dilini İngilizce veya Türkçe olarak değiştirmenizi sağlar.        --
-- ================================================================================================================== --