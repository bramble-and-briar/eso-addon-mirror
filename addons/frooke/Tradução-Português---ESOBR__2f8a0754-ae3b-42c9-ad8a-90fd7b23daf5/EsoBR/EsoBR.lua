local ADDON_NAME = "EsoBR"
EsoBR = {}
EsoBR.Version = "1.3.0"

local defaultSettings = {
    persistLanguage = false,
    lastLang = "en"
}

local savedVars

-- Troca de idioma
local function ESOBR_Change(lang)
    if GetCVar("language.2") ~= lang then
        SetCVar("IgnorePatcherLanguageSetting", "1")
        SetCVar("language.2", lang)
        SetCVar("LastPlatformLanguage", lang)
        savedVars.lastLang = lang
    end
end

-- Retorna idioma atual
local function ESOBR_GetLanguage()
    local lang = GetCVar("language.2")
    return lang == "br" and "br" or "en"
end

-- Handler do menu
local function OnLanguageChange(value)
    local selectedLang = value and "br" or "en"
    if selectedLang ~= ESOBR_GetLanguage() then
        ESOBR_Change(selectedLang)
    end
end

local function OnPersistChange(value)
    savedVars.persistLanguage = value
    if value then
        SetCVar("IgnorePatcherLanguageSetting", "1")
    else
        SetCVar("IgnorePatcherLanguageSetting", "0")
    end
end

-- Criação do painel de configuração
local function CreateSettingsPanel()
    local LAM = LibAddonMenu2
    local panelName = "EsoBR_SettingsPanel"

    if not LAM then
        d("[EsoBR] LibAddonMenu-2.0 não encontrado.")
        return
    end

    local optionsTable = {
        {
            type = "checkbox",
            name = "Alterar para Português",
            tooltip = "Alterna entre o idioma padrão e o idioma português brasileiro.",
            getFunc = function() return ESOBR_GetLanguage() == "br" end,
            setFunc = OnLanguageChange,
            default = false,
        },
        {
            type = "checkbox",
            name = "Manter linguagem na próxima inicialização",
            tooltip = "Quando essa opção estiver ativada, o jogo será iniciado no idioma selecionado durante o jogo anterior.",
            getFunc = function()
                return GetCVar("IgnorePatcherLanguageSetting") == "1"
            end,
            setFunc = function(value)
                SetCVar("IgnorePatcherLanguageSetting", value and "1" or "0")
            end,
            default = false,
        },
        {
            type = "button",
            name = "Reiniciar UI",
            tooltip = "Clique aqui para aplicar o idioma selecionado (necessário após a troca).",
            func = function()
                if ReloadUI then
                    zo_callLater(function()
                        ReloadUI()
                    end, 100)
                else
                    d("[EsoBR] A função ReloadUI não está disponível.")
                end
            end,
            width = "full",
        },
    }

    local panelData = {
        type = "panel",
        name = "EsoBR",
        displayName = "Tradução Brasileira não-oficial do ESO.",
        author = "Mestre Frooke",
        version = EsoBR.Version,
        website = "http://www.universoeso.com.br",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, optionsTable)



--if LibVotans then
--    LibVotans:AddAddon(ADDON_NAME, {
--        author = "Mestre Frooke",
--        version = EsoBR.Version,
--        settings = optionsTable,
--    })
--end
end

-- Evento de carregamento
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide("EsoBR_SavedVars", 1, nil, defaultSettings)

    if savedVars.persistLanguage and savedVars.lastLang then
        ESOBR_Change(savedVars.lastLang)
    end

    CreateSettingsPanel()
end


EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
