-- DLC Roulette. Copyright (c) 2026 -Chin. All rights reserved: no copying, sharing, changes or reuse.
-- English text.
DLCRoulette = DLCRoulette or {}
DLCRoulette.L = {
    BUTTON_VET = "DLC Roulette Vet",
    BUTTON_NORMAL = "DLC Roulette Normal",

    NONE_VET = "No DLC dungeons available (Veteran)",
    NONE_NORMAL = "No DLC dungeons available (Normal)",
    ALREADY_QUEUED = "Already queued",
    NOT_LEADER = "Leader only",
    IN_GROUP_FINDER = "Group Finder in use",
    COOLDOWNS_RESET = "Cooldowns cleared",

    NO_SETTINGS_LIB = "DLC Roulette: LibHarvensAddonSettings missing",

    LIST_SECTION = "Dungeon list",
    ALL_LABEL = "Select all",
    ALL_BUTTON = "All",
    NONE_LABEL = "Deselect all",
    NONE_BUTTON = "None",

    COOLDOWN_SECTION = "Cooldown",
    COOLDOWN_HOURS = "Hours",
    COOLDOWN_HOURS_TIP = "0 turns cooldowns off.",
    COOLDOWN_NORMAL = "Normal cooldowns",
    COOLDOWN_VET = "Veteran cooldowns",
    COOLDOWN_NONE = "No dungeons on cooldown.",
    COOLDOWN_CLEAR_LABEL = "Clear cooldowns",
    COOLDOWN_CLEAR_BUTTON = "Clear",
}

-- The two keybinds in Bindings.xml. The game looks their names up as SI_BINDING_NAME_<action> and hides any
-- action it can't find a name for, so these have to be registered before Controls, Keybindings is opened.
ZO_CreateStringId("SI_BINDING_NAME_DLC_ROULETTE_VETERAN", "DLC Roulette Veteran")
ZO_CreateStringId("SI_BINDING_NAME_DLC_ROULETTE_NORMAL", "DLC Roulette Normal")
