-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0012-savedvars-account-wide-y-migracion-por-personaje.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.name = Addon.Constants.METADATA.NAME

-- Inicializar las cadenas de Keybindings en el momento de carga para que Bindings.xml las resuelva
Addon.Locale:Initialize()

function Addon:Initialize()
    local defaults = Addon.QuestRepository:GetDefaults()
    local svName = Addon.Constants.SAVED_VARS.NAME
    local svVersion = Addon.Constants.SAVED_VARS.VERSION
    local savedVars = ZO_SavedVars:NewAccountWide(svName, svVersion, nil, defaults)
    self.savedVars = savedVars
    Addon.QuestRepository:MigrateCharacterSavedVars(_G[svName], GetDisplayName(), savedVars, GetCurrentCharacterId())

    Addon.QuestRepository:Initialize(savedVars)
    Addon.CombatTracker:Initialize()
    Addon.DiscoveryTracker:Initialize()
    Addon.DialogueInjector:Initialize()
    Addon.WorldMapArea:Initialize()
    Addon.CompassAreaGlow:Initialize()
    if Addon.MailTransport then
        Addon.MailTransport:Initialize()
    end
    Addon.JournalTab:Initialize()
end

function Addon:OnCaptureTargetKeybind()
    return Addon.TargetCapture:CaptureFromReticle()
end

function Addon:OnToggleJournalKeybind()
    Addon.JournalTab:ToggleTab()
end

local function OnAddOnLoaded(_eventCode, addOnName)
    if addOnName ~= Addon.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(Addon.name, EVENT_ADD_ON_LOADED)
    Addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(Addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
