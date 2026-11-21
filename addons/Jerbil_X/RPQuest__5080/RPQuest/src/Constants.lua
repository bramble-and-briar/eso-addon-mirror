-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Constants = {
    METADATA = {
        NAME = "RPQuest",
        TITLE = "RPQuest",
        VERSION = "1.0.0",
        AUTHOR = "JerbilX",
    },
    SAVED_VARS = {
        NAME = "RPQuest_SavedVariables",
        VERSION = 1,
    },
    SHARE_CODEC = {
        PREFIX = "RPQ2",
        LEGACY_PREFIX = "RPQ1",
        COMPLETION_PREFIX = "RPQC1",
        VERSION = 2,
    },
    DIALOGUE = {
        MAX_NPCS = 3,
    },
    QUEST_ROLE = {
        PREPARED = "prepared",
        RECEIVED = "received",
    },
    AREA_RADIUS = {
        SMALL = 0.045,
        MEDIUM = 0.075,
        LARGE = 0.115,
    },
    AREA_OFFSET = {
        MIN_RATIO = 0.25,
        MAX_RATIO = 0.65,
    },
    DISCOVERY_RADIUS = {
        SMALL = 800,
        MEDIUM = 1500,
        LARGE = 3000,
    },
    DISCOVERY_POLL_INTERVAL_MS = 750,
    UI = {
        CHAT_PREFIX = "|cE8D5A0[RPQuest]|r ",
        TAB_DESCRIPTOR = "rpquest_custom_quests",
        PIN_TYPE_STRING = "RPQUEST_SEARCH_AREA_PIN",
        ICON_TAB_UP = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_up.dds",
        ICON_TAB_DOWN = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_down.dds",
        ICON_TAB_OVER = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_over.dds",
        ICON_TAB_DISABLED = "EsoUI/Art/Journal/journal_quests_tabIcon_disabled.dds",
        ICON_QUEST = "EsoUI/Art/Compass/quest_icon_assisted.dds",
        DIVIDER_TEXTURE = "EsoUI/Art/Quest/questJournal_divider.dds",
    },
}
