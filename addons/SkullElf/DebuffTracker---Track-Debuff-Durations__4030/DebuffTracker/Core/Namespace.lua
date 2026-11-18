-- DebuffTracker 5 -- shared addon table. Loaded first (see DebuffTracker.txt).
--
-- Architecture (v5): every tracker is plain data (Core/Schema.lua). The Engine evaluates each
-- loaded tracker ~10x a second: Trigger -> states, Conditions -> per-state looks/actions,
-- Display -> on-screen rendering. Data sources (Effects, Combat, Resources) only keep caches up to
-- date from game events; they never touch the UI.

DebuffTracker = {
    name = "DebuffTracker",
    displayName = "DebuffTracker",
    version = "5.21.24",
    author = "SkullElf",

    Util = {},
    Const = {},
    Schema = {},
    Serializer = {},

    Units = {},
    Effects = {},
    Combat = {},
    Resources = {},
    Gear = {},
    Procs = {},

    Triggers = {},
    Conditions = {},
    Load = {},
    Engine = {},

    Style = {},
    Toggles = {},
    Stats = {},
    Displays = {},
    DisplayTypes = {},
    Announcer = {},
    World = {},
    Marker = {},
    Unlock = {},

    Profiles = {},
    Migration = {},
    Presets = {},
    Recorder = {},
    AbilitySearch = {},

    UI = {},

    debug = false,
    testMode = false,
    unlocked = false,
}
