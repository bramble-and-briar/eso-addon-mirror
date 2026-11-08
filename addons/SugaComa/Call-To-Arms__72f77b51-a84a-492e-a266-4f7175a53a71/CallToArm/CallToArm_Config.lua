-- CallToArm_Config.lua
-- Create or reuse the global namespace table (safe if reloaded)
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm
CallToArm.Config = CallToArm.Config or {}

CallToArm.Config.SCHEMA_VERSION = 1

CallToArm.Config.Defaults = {
    schemaVersion = CallToArm.Config.SCHEMA_VERSION,

    selectedGuildId = 0,

    guild = {
        defaultName = "CallToArm",
        alliance = 0, -- cached via GetGuildAlliance(selectedGuildId)
    },

    cta = {
        representedGuildId = 0,
        representLockedUntil = 0,
    },

    byGuild = {},

    ui = {
        highlightGuildies = true,
        guildLeaderboardEnabled = true,
    },

    debug = false,
    debugSafeMode = false,
}
