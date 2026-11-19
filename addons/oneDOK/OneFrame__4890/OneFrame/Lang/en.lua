local strings = {
    SI_ONEFRAME_DEBUG = "Debug",
    SI_ONEFRAME_DEBUG_OFF = "Disabled",
    SI_ONEFRAME_DEBUG_SMALL = "Small group",
    SI_ONEFRAME_DEBUG_LARGE = "Large group",
    SI_ONEFRAME_DISPLAY = "Display",
    SI_ONEFRAME_TANK_ROLE = "Tank",
    SI_ONEFRAME_HEALER_ROLE = "Healer",
    SI_ONEFRAME_DAMAGE_ROLE = "Damage Dealer",
    SI_ONEFRAME_SHOW_STATISTIC = "Show statistic",
    SI_ONEFRAME_NOTHING = "Nothing",
    SI_ONEFRAME_LEVEL_CP = "Level / Champion Points",
    SI_ONEFRAME_GROUP_DPS = "Group DPS",
    SI_ONEFRAME_HEALTH_THOUSANDS = "%.1fk",
    SI_ONEFRAME_GENERAL = "General",
    SI_ONEFRAME_SORT = "Sort group by role",
    SI_ONEFRAME_CLASS = "Show class icon",
    SI_ONEFRAME_DPS_LABEL = "DPS",
    SI_ONEFRAME_HPS_LABEL = "HPS",
    SI_ONEFRAME_UNAVAILABLE = "—",
    SI_ONEFRAME_KILO = "%.1fk",
    SI_ONEFRAME_MILLION = "%.2fm",
    SI_ONEFRAME_SHIELD_COLOR = "Shield color",
    SI_ONEFRAME_CONTEXT_MENU = "Right-click context menu",
    SI_ONEFRAME_WHISPER = "Whisper",
    SI_ONEFRAME_TRAVEL = "Travel to Player",
    SI_ONEFRAME_REMOVE = "Remove from Group",
    SI_ONEFRAME_UNSUPPORTED = "OneFrame: this ESO UI version is not verified; frame enhancements are disabled.",
    SI_ONEFRAME_MISSING = "OneFrame: vanilla frame support is unavailable; enhancements were not attached.",
}

for id, text in pairs(strings) do
    ZO_CreateStringId(id, text)
end
