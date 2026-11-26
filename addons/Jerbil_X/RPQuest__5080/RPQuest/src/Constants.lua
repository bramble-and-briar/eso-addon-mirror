-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0013-protocolo-versionado-de-esquema-y-migraciones-de-misiones.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md
-- Ref: docs/adr/0016-limites-texto-y-entidades-presupuesto-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.Constants = {
    METADATA = {
        NAME = "RPQuest",
        TITLE = "RPQuest",
        VERSION = "1.11.0",
        AUTHOR = "JerbilX",
    },
    QUEST_SCHEMA = {
        CURRENT_VERSION = 5,
    },
    STEALTH_MODE = {
        DISABLED = "disabled",
        OPTIONAL = "optional",
        REQUIRED = "required",
    },
    QUEST_ICONS = {
        {
            id = "black_hand",
            localeKey = "QUEST_ICON_BLACK_HAND",
            texture = "/esoui/art/floatingmarkers/darkbrotherhood_target.dds",
        },
        {
            id = "search",
            localeKey = "QUEST_ICON_SEARCH",
            texture = "/esoui/art/miscellaneous/gamepad/gp_icon_search_64.dds",
        },
        {
            id = "steal",
            localeKey = "QUEST_ICON_STEAL",
            texture = "/esoui/art/inventory/inventory_stolenitem_icon.dds",
        },
    },
    SAVED_VARS = {
        NAME = "RPQuest_SavedVariables",
        VERSION = 1,
    },
    SHARE_CODEC = {
        PREFIX = "RPQ3",
        COMPLETION_PREFIX = "RPQC1",
        VERSION = 3,
    },
    TARGET = {
        MAX_TARGETS = 4,
    },
    DISCOVERY = {
        MAX_POINTS = 10,
    },
    DIALOGUE = {
        MAX_NPCS = 4,
    },
    TEXT_LIMITS = {
        TITLE = 80,
        DESCRIPTION = 250,
        ACCOUNT_NAME = 64,
        CHARACTER_NAME = 64,
        SHORT_MESSAGE = 100,
        DIALOGUE_OPTION = 60,
        DIALOGUE_RESPONSE = 150,
        MAIL_ROLE_MESSAGE = 300,
    },
    QUEST_ROLE = {
        PREPARED = "prepared",
        RECEIVED = "received",
    },
    QUEST_STATUS = {
        OFFERED = "offered",
        ACTIVE = "active",
    },
    QUEST_LIFECYCLE = {
        DRAFT = "draft",
        SENT = "sent",
        RECEIVED = "received",
    },
    QUEST_RESOLUTION = {
        ACCEPTED = "accepted",
        REJECTED = "rejected",
        COMPLETED = "completed",
        FAILED = "failed",
    },
    AREA_RADIUS = {
        TINY = 0.008,
        SMALL = 0.0235,
        MEDIUM = 0.039,
        LARGE = 0.0545,
        HUGE = 0.070,
    },
    AREA_SUBZONE_MULTIPLIER = 1.6,
    AREA_OFFSET = {
        MIN_RATIO = 0.25,
        MAX_RATIO = 0.65,
    },
    DISCOVERY_RADIUS = {
        TINY = 800,
        SMALL = 2350,
        MEDIUM = 3900,
        LARGE = 5450,
        HUGE = 7000,
    },
    DISCOVERY_POLL_INTERVAL_MS = 750,
    UI = {
        CHAT_PREFIX = "|cE8D5A0[RPQuest]|r ",
        TAB_DESCRIPTOR = "rpquest_custom_quests",
        PIN_TYPE_STRING = "RPQUEST_SEARCH_AREA_PIN",
        SEARCH_AREA_COLOR = { r = 0.16, g = 0.78, b = 0.48, a = 0.65 },
        LOCATION_PIN_TYPE_STRING = "RPQUEST_TARGET_LOCATION_PIN",
        LOCATION_AREA_COLOR = { r = 1.0, g = 0.58, b = 0.18, a = 0.65 },
        DISCOVERY_PIN_TYPE_STRING = "RPQUEST_DISCOVERY_AREA_PIN",
        DISCOVERY_AREA_COLOR = { r = 0.68, g = 0.35, b = 0.95, a = 0.65 },
        ZOOM_OUT_PIN_TYPE_STRING = "RPQUEST_ZOOM_OUT_PIN",
        TARGET_PING_PIN_TYPE_STRING = "RPQUEST_TARGET_PING_PIN",
        TARGET_PING_TEXTURE = "EsoUI/Art/MapPins/QuestPing.dds",
        TARGET_PING_DURATION_MS = 4500,
        ICON_TAB_UP = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_up.dds",
        ICON_TAB_DOWN = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_down.dds",
        ICON_TAB_OVER = "EsoUI/Art/Journal/journal_tabIcon_loreLibrary_over.dds",
        ICON_TAB_DISABLED = "EsoUI/Art/Journal/journal_quests_tabIcon_disabled.dds",
        ICON_QUEST = "EsoUI/Art/Compass/quest_icon_assisted.dds",
        DIVIDER_TEXTURE = "EsoUI/Art/Quest/questJournal_divider.dds",
    },
}
