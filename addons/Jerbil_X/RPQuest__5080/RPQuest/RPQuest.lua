-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.name = Addon.Constants.METADATA.NAME

-- Inicializar las cadenas de Keybindings en el momento de carga para que Bindings.xml las resuelva
Addon.Locale:Initialize()

function Addon:Initialize()
    local defaults = Addon.QuestRepository:GetDefaults()
    local svName = Addon.Constants.SAVED_VARS.NAME
    local svVersion = Addon.Constants.SAVED_VARS.VERSION
    local savedVars = ZO_SavedVars:NewCharacterIdSettings(svName, svVersion, nil, defaults)
    self.savedVars = savedVars

    Addon.QuestRepository:Initialize(savedVars)
    Addon.CombatTracker:Initialize()
    Addon.DiscoveryTracker:Initialize()
    Addon.DialogueInjector:Initialize()
    Addon.WorldMapArea:Initialize()
    if Addon.MailTransport then
        Addon.MailTransport:Initialize()
    end
    Addon.JournalTab:Initialize()

    SLASH_COMMANDS["/rpquest"] = function(args)
        self:HandleSlashCommand(args)
    end
end

function Addon:OnCaptureTargetKeybind()
    return Addon.TargetCapture:CaptureFromReticle()
end

function Addon:OnCaptureDiscoveryKeybind()
    return Addon.TargetCapture:CaptureDiscoveryPoint()
end

function Addon:OnToggleJournalKeybind()
    Addon.JournalTab:ToggleTab()
end

function Addon:HandleSlashCommand(args)
    local cmd = (type(args) == "string" and args:gsub("^%s+", ""):gsub("%s+$", ""):lower()) or ""
    if cmd == "capture" or cmd == "target" then
        self:OnCaptureTargetKeybind()
    elseif cmd == "discovery" or cmd == "point" then
        self:OnCaptureDiscoveryKeybind()
    elseif cmd == "map" then
        Addon.WorldMapArea:ShowQuestOnMap()
    else
        self:OnToggleJournalKeybind()
    end
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= Addon.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(Addon.name, EVENT_ADD_ON_LOADED)
    Addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(Addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
