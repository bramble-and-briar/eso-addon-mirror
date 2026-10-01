--[[
    Settings.lua for Immersive Rumors
    Integration with LibAddonMenu-2.0
]]

ImmersiveRumors = ImmersiveRumors or {}
local IR = ImmersiveRumors
-- Alias
RumorsNoBlueHints = ImmersiveRumors
local RNBH = ImmersiveRumors

function IR.InitSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local isGerman = (GetCVar("language.2") == "de")

    local panelData = {
        type = "panel",
        name = "Immersive Rumors",
        displayName = "|c4E9BFFImmersive Rumors|r",
        author = IR.author,
        version = IR.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = "header",
            name = isGerman and "|cEBE8C4Haupteinstellungen|r" or "|cEBE8C4General Settings|r",
        },
        {
            type = "description",
            text = isGerman and
                "Dieses Addon entfernt die blauen Texthervorhebungen aus den Hinweis- und Hinweistexten des Gerüchte-Systems (Rumors, Update 51), sodass man den gesamten Text aufmerksam lesen muss, um Rätsel und Hinweise zu lösen."
                or "This addon removes blue text highlights from Rumors clues and hints (Update 51), requiring you to read the full clue texts attentively to solve mysteries.",
        },
        {
            type = "checkbox",
            name = isGerman and "Addon Aktiviert" or "Enable Addon",
            tooltip = isGerman and
                "Schaltet das Neutralisieren der blauen Texthervorhebungen ein oder aus."
                or "Toggles neutralizing blue text highlights on or off.",
            getFunc = function() return IR.settings.enabled end,
            setFunc = function(value)
                IR.settings.enabled = value
                if value then
                    IR.ScanAndSanitizeAll()
                end
            end,
            default = IR.defaults.enabled,
        },
        {
            type = "checkbox",
            name = isGerman and "Quest-Tagebuch & Gerüchte bereinigen" or "Clean Quest Journal & Rumors",
            tooltip = isGerman and
                "Entfernt blaue Texthervorhebungen aus dem Gerüchte-Tagebuch und den Hinweiskarten."
                or "Removes blue text highlights from the Rumors journal entries and clue lists.",
            getFunc = function() return IR.settings.cleanJournal end,
            setFunc = function(value)
                IR.settings.cleanJournal = value
                if value then
                    IR.ScanAndSanitizeAll()
                end
            end,
            disabled = function() return not IR.settings.enabled end,
            default = IR.defaults.cleanJournal,
        },
        {
            type = "header",
            name = isGerman and "|cEBE8C4Diagnose|r" or "|cEBE8C4Diagnostics|r",
        },
        {
            type = "checkbox",
            name = isGerman and "Debug-Modus im Chat" or "Chat Debug Mode",
            tooltip = isGerman and
                "Gibt Informationen über gefundene und bereinigte Textstellen im Chat-Fenster aus."
                or "Outputs info about detected and sanitized text strings to the chat window.",
            getFunc = function() return IR.settings.debug end,
            setFunc = function(value)
                IR.settings.debug = value
            end,
            default = IR.defaults.debug,
        },
    }

    LAM:RegisterAddonPanel("ImmersiveRumorsSettingsPanel", panelData)
    LAM:RegisterOptionControls("ImmersiveRumorsSettingsPanel", optionsTable)
end
