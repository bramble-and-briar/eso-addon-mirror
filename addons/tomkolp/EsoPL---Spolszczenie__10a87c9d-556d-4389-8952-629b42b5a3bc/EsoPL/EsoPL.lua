local ADDON_NAME = "EsoPL"
EsoPL = EsoPL or {}
EsoPL.Version = "1.0.23"

local defaultSettings = {
    lastLang = "en",
    abilitiesMode = "pl",
    championMode = "pl",
}

local savedVars

------------------------------------------------------------
-- Zmiana języka
------------------------------------------------------------

function EsoPL.ChangeLanguage(lang)
    SetCVar("IgnorePatcherLanguageSetting", "1") 
    SetCVar("language.2", lang)
    SetCVar("LastPlatformLanguage", lang)
    
    -- Aktualizacja savedVars
    if savedVars then 
        savedVars.lastLang = lang 
    end
    
    d("Język zmieniony na " .. lang .. ". Przeładowywanie interfejsu...")
end

-- Zwraca aktualny język (proste sprawdzenie)
function EsoPL.GetLanguage()
    return GetCVar("language.2") == "pl" and "pl" or "en"
end

------------------------------------------------------------
-- Pozostałe funkcje (Skille, CP)
------------------------------------------------------------

function EsoPL.GetAbilitiesMode()
    if not savedVars or not savedVars.abilitiesMode then return "pl" end
    return savedVars.abilitiesMode
end

function EsoPL.SetAbilitiesMode(mode)
    if not savedVars then return end
    savedVars.abilitiesMode = mode
end

function EsoPL.GetChampionMode()
    if not savedVars or not savedVars.championMode then return "pl" end
    return savedVars.championMode
end

function EsoPL.SetChampionMode(mode)
    if not savedVars then return end
    savedVars.championMode = mode
end

------------------------------------------------------------
-- Event ładowania dodatku (Inicjalizacja)
------------------------------------------------------------
local function OnAddOnLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    savedVars = ZO_SavedVars:NewAccountWide("EsoPL_SavedVars", 1, nil, defaultSettings)
    
    -- Inicjalizacja Menu
    if EsoPL.BuildMenu then EsoPL.BuildMenu() end
    -- Inicjalizacja Funkcji (Skille, CP, Czcionki)
    if EsoPL.InitAbilities then EsoPL.InitAbilities() end
    if EsoPL.InitChampion then EsoPL.InitChampion() end
    
    -- Inicjalizacja Poprawek Czcionek (Książki i Mapa)
    if EsoPL.InitBookFonts then EsoPL.InitBookFonts() end
    if EsoPL.InitMapFonts then EsoPL.InitMapFonts() end
end

------------------------------------------------------------
-- Event Aktywacji Gracza (Komunikaty na czacie)
------------------------------------------------------------
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    
    -- Opóźnienie 1 sekundę (1000ms), aby upewnić się, że gracz widzi świat i czat jest gotowy
    zo_callLater(function()
        local lang = EsoPL.GetLanguage()
        local prefix = "|ce6db5f[EsoPL]|r "

        if lang == "en" then
            -- Gdy język jest ANGIELSKI: Wyświetlaj zawsze
            d(prefix .. "Gra jest w języku angielskim.")
            d(prefix .. "Wpisz |c00FF00/pl|r na czacie, aby zmienić na polski.")
        else
            -- Gdy język jest POLSKI: Wyświetlaj informację
            d(prefix .. "Gra jest w języku polskim.")
            d(prefix .. "Wpisz |cFFFF00/en|r na czacie, aby zmienić na angielski.")
        end
    end, 1000)
end

-- Rejestracja eventów
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-- Komendy Slash
SLASH_COMMANDS["/pl"] = function() EsoPL.ChangeLanguage("pl") end
SLASH_COMMANDS["/en"] = function() EsoPL.ChangeLanguage("en") end