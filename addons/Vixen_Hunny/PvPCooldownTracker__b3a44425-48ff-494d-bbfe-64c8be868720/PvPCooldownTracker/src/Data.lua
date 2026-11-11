-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  g4rr3t
-- Created: Oct 12, 2018
--
-- Data.lua
-- -----------------------------------------------------------------------------
--
-- To all you helpful individuals who romp in here to add things
-- on your own, thank you.
--
-- I'm sorry my updates overwrite your changes and you have to constantly
-- backup this file or ignore updates in order to keep your version working.
--
PvPCooldownTracker = PvPCooldownTracker or {}

-- If you'd like to submit a pull request on GitHub, I'd happily take a look.
--
--      https://github.com/inimicus/cooldowns
--
-- Here is some information that might be helpful:
--
-- Debugging/Finding IDs:
-- When finding information about new sets, you can get chat log spammed with
-- information about every EVENT_COMBAT_EVENT by typing in game chat:
--
--      /cool all on
--
-- You'll get spammed with all the abilities in chat. There might even be
-- a similar debug for effects commented somewhere else in the code, too.
--
-- Proc your set/synergy/whatever, then look for it in the chat. You'll get
-- the name, the ID, and the result. Take note of these values and then add
-- them to the Sets table below along with any other values needed.
--
-- Turn off chat spam with:
--
--      /cool all off
--
-- Easy as that.
--
-- PvPCooldownTracker.Data.Sets (table):
-- This table contains all the set, synergy, and passive information that
-- the addon uses. But you probably already knew that.
--
-- Each entry is stored in a table with its key being the string name
-- of the set to track. Because of this, non-English clients don't work.
--
-- There are plans to implement better tracking that doesn't use the set name
-- and there is already a new branch on GitHub to track efforts there. But it
-- is quite a bit out of date, unfortunately.
--
-- Big thanks to Baertram for helping out on multi-language support.
--
-- Configuration Options:
--
-- * procType (string):     One of "set", "synergy", or "passive" to indicate
--                          what kind of tracking it is. Duhhhhh.
--
-- * event (number):        What kind of action identifies the proc happened.
--                          Generally this is EVENT_COMBAT_EVENT or 131102, but
--                          some other values do exist (Wyrd Tree, others).
--
-- * description (string):  Cosmetic. Adds a description to the tooltip.
--
-- * settingsColor (string):    Color in hex. Used to be used for the colors
--                              for each set in the settings menu, but since
--                              the menu was updated they aren't used. Will
--                              probably clean them up at some point.
--
-- * id (number | array):   The ID that identifies the proc condition.
--                          This can also be an array of numbers for proc
--                          conditions that span multiple IDs (Perfected/Non,
--                          synergies, stupid Pirate Skelly, and more).
--
-- * enabled (bool):        Used to identify if tracking and display are enabled.
--                          This is different from if the set is enabled in the
--                          settings. That's a different value stored in savedvars.
--                          This value is pointless here and will probably be
--                          removed in the future.
--
-- * result (number):       The result of the proc. These are numeric, defined
--                          in the table using their constants. When debugging,
--                          the number will appear instead of the constant name,
--                          so refer to the constants section below to match.
--
-- * cooldownDurationMs (number):   Number in milliseconds for the cooldown.
--                                  e.g. 30 seconds is 30000
--
-- * onCooldown (bool):     If the set is on cooldown.
--                          This is also pointless here and will
--                          probably be removed in the future.
--
-- * timeOfProc (number):   Time that the proc happened, used in maths to
--                          provide the countdown and cooldown time remaining.
--                          Pointless here, will be removed in the future.
--
-- * texture (string):      The path to the texture to use for the cooldown
--                          display. You can find textures with the TextureIt
--                          addon (though what's there is largely out of date)
--                          or via the method `GetAbilityIcon([abilityId])`.
--                          I just generally use any icon that doesn't
--                          look like ass. A lot look like ass.
--
-- * showFrame (bool):      Enables or disables showing the frame around
--                          the icon. Not used for monster helm icons.
--                          But most monster helm icons look like ass.
--
-- Constants:
--
-- Reference this section to make sense of what result and event numbers in
-- debug messages mean.
--
-- Results:
-- ACTION_RESULT_DAMAGE                 = 1
-- ACTION_RESULT_POWER_ENERGIZE         = 128
-- ACTION_RESULT_HEAL                   = 16
-- ACTION_RESULT_EFFECT_GAINED          = 2240 - The most common
-- ACTION_RESULT_EFFECT_GAINED_DURATION = 2245 - Use 2240 if both show up
-- ACTION_RESULT_ABILITY_ON_COOLDOWN    = 2080

-- Events:
-- EVENT_ABILITY_COOLDOWN_UPDATED       = 131181
-- EVENT_COMBAT_EVENT                   = 131102
-- EVENT_EFFECT_CHANGED                 = 131150
--
-- -----------------------------------------------------------------------------

PvPCooldownTracker.Data = {}

-- Detect Perfect versions
-- Note: Trailing space!
PvPCooldownTracker.Data.PerfectString = {
    "Perfected ",
    "Perfect ",
}

PvPCooldownTracker.Data.Sets = {
    ["Roaring Opportunist"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays the Roaring Opportunist Proc",
        settingsColor = "3A97CF",
        id = 135923,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 22000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(135923),
        showFrame = true
    },
    ["Meridia's Blessed Armor"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays the Meridia's Blessed Armor Proc",
        settingsColor = "3A97CF",
        id = 34711,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 25000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(34711),
        showFrame = true
    },
    ["The Juggernaut"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays the Juggernaut Proc Proc",
        settingsColor = "3A97CF",
        id = 142401,
        enabled = false,
        cooldownDurationMs = 60000,
        onCooldown = false,
        timeOfProc = 0,
        result = ACTION_RESULT_EFFECT_GAINED,
        texture = GetAbilityIcon(142401),
        showFrame = true
    },
    ["Orpheon the Tactician"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays the Orpheon Proc Proc",
        settingsColor = "3A97CF",
        id = 236654,
        enabled = false,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        result = ACTION_RESULT_EFFECT_GAINED,
        texture = GetAbilityIcon(236654),
        showFrame = true
    },
    ["Sul-Xan's Torment"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays the Sul-Xan Proc Proc",
        settingsColor = "3A97CF",
        id = 154720,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 30000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(154720),
        showFrame = true
    },
    ["Slivers of the Null Arca"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays cooldown of Null Arca",
        settingsColor = "3A97CF",
        id = 220863,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 4000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(220863),
        showFrame = true
    },
    ["Archdruid Devyric"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Display Archdruid",
        settingsColor = "3A97CF",
        id = 176813,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 15000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(176813),
        showFrame = true,
    },
    ["Nazaray"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays Nazaray cooldown",
        settingsColor = "3A97CF",
        id = 167065,
        result = ACTION_RESULT_EFFECT_GAINED,
        texture = GetAbilityIcon(167065),
        cooldownDurationMs = 30000,
        onCooldown = false,
        timeOfProc = 0,
        enabled = false,
        showFrame = true
    },
        ["Dark Convergence"] = {
            procType = "set",
            event = EVENT_COMBAT_EVENT,
            description = "Cooldowns for Dark Convergence",
            settingsColor = "3A97CF",
            id = 159388,
            enabled = false,
            timeOfProc = 0,
            cooldownDurationMs = 25000,
            result = 2240,
            onCooldown = false,
            texture = GetAbilityIcon(159388),
            showFrame = true,
        },

    ["Magicka Furnace"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Magicka Furnace proc is available or cooldown until it is ready again.",
        settingsColor = "3A97CF",
        id = 34813,
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 30000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(34813),
        showFrame = true,
    },
    ["Wyrd Tree's Blessing"] = {
        procType = "set",
        event = EVENT_ABILITY_COOLDOWN_UPDATED,
        description = "Displays when the Wyrd Tree proc is available or cooldown until it is ready again.",
        settingsColor = "FCFCCB",
        id = 34871,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 15000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(34871),
        showFrame = true,
    },
    ["Vestments of the Warlock"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Magicka Flood proc is available or cooldown until it is ready again.",
        settingsColor = "3A97CF",
        id = 57163,
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 45000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(57163),
        showFrame = true,
    },
    ["Trappings of Invigoration"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the stamina return proc is available or cooldown until it is ready again.",
        settingsColor = "92C843",
        id = 101970,
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 45000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(101970),
        showFrame = true,
    },
    ["Powerful Assault"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays powerful assault timer",
        settingsColor = "3A97CF",
        id = 61771,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 15000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(61771),
        showFrame = true
    },
    ["Shroud of the Lich"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the magicka recovery proc is ready or when it will be available, but not the duration of increased magicka recovery.",
        settingsColor = "3A97CF",
        id = 57164,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 60000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(57164),
        showFrame = true,
    },
    ["Gryphon's Ferocity"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Gryphon's Ferocity",
        settingsColor = "3A97CF",
        id = {61746, 61735},
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(61746),
        showFrame = true,
    },
    ["Earthgore"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the heal proc is ready or when it will be available, but not the duration of the heal over time.",
        settingsColor = "CD5031",
        id = 97855,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 35000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(97855),
        showFrame = true,
    },
    ["Vestment of Olorime"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Major Courage area of effect is able to be placed, but does not indicate the duration of Major Courage.",
        settingsColor = "FCFCCB",
        id = {107141, 109084},
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(107141),
        showFrame = true,
    },
    ["Vykosa"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Major Maim debuff is able to be applied.",
        settingsColor = "CD5031",
        id = 111354, -- Major Maim
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 15000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(111354),
        --texture = "/esoui/art/icons/gear_undvykosa_helmet_a.dds",
        showFrame = true,
    },
    ["Steadfast Hero"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Major Protection buff is available through cleansing a negative effect on yourself or an ally.",
        settingsColor = "FCFCCB",
        id = 113509, -- Major Protection
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(113509),
        showFrame = true,
    },
    ["Zaan"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the cheese beam of fiery death is ready to ruin someone's day.",
        settingsColor = "3A97CF",
        id = 110997,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 18000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(110997),
        showFrame = true,
    },
    ["Caluurion's Legacy"] = {
        procType = "set",
        -- Caluurion Duration = 102060
        -- Disease  = 102033
        -- Fire     = 102027
        -- Shock    = 102034
        -- Ice      = 102032
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the fire, shock, ice, or disease ball proc is ready or when it will be available.",
        settingsColor = "3A97CF",
        id = 102060,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(102060),
        showFrame = true,
    },
    ["Mechanical Acuity"] = {
        -- Wheels does it better
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Mechanical Acuity proc is ready or when it will be available, but not the duration of the crit bonus.",
        settingsColor = "CD5031",
        id = 99204,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 25000,
        onCooldown = false,
        timeOfProc = 0,
        -- texture = "/esoui/art/icons/gear_clockwork_medium_head_a.dds",
        -- texture = "/esoui/art/icons/ability_buff_major_sorcery.dds",
        texture = GetAbilityIcon(99204),
        showFrame = true,
    },
    ["Bloodspawn"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Blood Spawn ultimate generation and resistance buffs are ready or when they will be available, but not their duration.",
        settingsColor = "CD5031",
        id = 59517,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 6000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(59517),
        showFrame = true,
    },
    ["Stonekeeper"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Stonekeeper can generate Charge stacks or until it can generate stacks again. Does not show current Charge stacks.",
        settingsColor = "CD5031",
        id = 116877,
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 14000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(116877),
        --texture = "/esoui/art/champion/champion_points_health_icon-hud.dds",
        showFrame = true,
    },
    ["Symphony of Blades"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when Meridia's Favor is ready or when it will become available to be applied to an ally.",
        settingsColor = "CD5031",
        id = 117111,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 18000,
        onCooldown = false,
        timeOfProc = 0,
        --texture = "/esoui/art/icons/gear_undnarlimor_head_a.dds",
        texture = GetAbilityIcon(117111),
        showFrame = true,
    },
    ["Crest of Cyrodiil"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the heal on block from Crest of Cyrodiil is ready or when it will become available.",
        settingsColor = "92C843",
        id = 111575,
        enabled = false,
        result = ACTION_RESULT_HEAL,
        cooldownDurationMs = 5000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(111575),
        showFrame = true,
    },
    ["Ravager"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when The Ravager weapon damage buff proc is ready or when it will become available.",
        settingsColor = "92C843",
        id = 34872,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(34872),
        --texture = "/LuiExtended/media/icons/abilities/ability_set_the_ravager.dds",
        showFrame = true,
    },
    ["Curse Eater"] = {
        procType = "set",
        event = EVENT_ABILITY_COOLDOWN_UPDATED,
        description = "Displays when the Curse Eater removal of negative effects is ready or when it will become available.",
        settingsColor = "FCFCCB",
        --id = 117359, -- Event
        id = 117360, -- Cooldown
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 8000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(117360),
        showFrame = true,
    },
    ["Icy Conjuror"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Ice Wraith proc after applying a minor debuff is ready or when it will become available.",
        settingsColor = "3A97CF",
        id = 117666,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 12000,
        onCooldown = false,
        timeOfProc = 0,
        -- LuiExtended/media/icons/abilities/ability_set_icy_conjuror.dds
        texture = GetAbilityIcon(117666),
        showFrame = true,
    },
    ["Hide of the Werewolf"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the ultimate generation from this set is ready or when it will become available.",
        settingsColor = "92C843",
        id = 34508, -- Cooldown
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 5000,
        onCooldown = false,
        timeOfProc = 0,
        -- LuiExtended/media/icons/abilities/ability_set_werewolf_hide.dds
        texture = GetAbilityIcon(34508),
        showFrame = true,
    },
    ["Essence Thief"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the essence pool is ready to be drawn from the enemy or when it will become available.",
        settingsColor = "92C843",
        id = 67324,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(67334),
        showFrame = true,
    },
    ["Rush Of Agony"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Rush of Agony proc is ready or when it will become available.",
        settingsColor = "92C843",
        id = 160184,
        enabled = false,
        result = 2240,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(159275),
        showFrame = true
    },
    ["Twice-Fanged Serpent"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays Twice-Fanged serpent's duration on reset",
        settingsColor = "92C843",
        id = 51176,
        enabled = true,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 5000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(51176),
        showFrame = true
    },
    ["Two-Fanged Snake"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays Twice-Fanged serpent's duration on reset",
        settingsColor = "92C843",
        id = 51176,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 5000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(51176),
        showFrame = true
    },
    ["Rallying Cry"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays Rallying Cry proc",
        settingsColor = "92C843",
        id = 166731,
        enabled = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(166731),
        cooldownDurationMs = 15000,
        onCooldown = false,
        result = ACTION_RESULT_EFFECT_GAINED_DURATION,
        showFrame = true
    },
    ["Wretched Vitality"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays wretched vitality proc",
        settingsColor = "92C843",
        id = 163102,
        enabled = false,
        timeOfProc = 15000,
        onCooldown = true,
        texture = GetAbilityIcon(163102),
        cooldownDurationMs = 15000,
        result = 2240,
        showFrame = true
    },
    ["Armor of Truth"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when you are able to gain weapon damage by setting an enemy Off Balance or when it will become available.",
        settingsColor = "92C843",
        id = 86070,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(86070),
        showFrame = true,
    },
    ["Claw of Yolnahkriin"] = {
        -- Thanks to Troodon80 for providing code and suggestion for this!
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Minor Courage effect is able to be applied, but does not indicate the duration of Minor Courage.",
        settingsColor = "FCFCCB",
        id = 121878,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 8000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(121878),
        showFrame = true,
    },
    ["Pirate Skeleton"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Major Protection/Minor Defile effect from the Pirate Skeleton set can be proc, but does not indicate the duration of these buffs/debuffs.",
        settingsColor = "CD5031",
        -- This is fucked, why different based on class?
        id = {
            --80501, -- Equipped?
            81675, -- Necro
            83288, -- ?
            83287, -- ?
            98419, -- Templar
            98420, -- ?
            98421, -- Sorcerer?
        },
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 15000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(81675),
        showFrame = true,
        -- Helm icon Looks like ass
        -- texture = "/esoui/art/icons/gear_undauntedpirateskeleton_head_a.dds",
        -- showFrame = true,
    },
    ["Maarselok"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when you can spew a cone of corruption, much like your mum did when you were born.",
        settingsColor = "FCFCCB",
        id = 126941,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        -- Helm texture looks like ass
        -- texture = "/esoui/art/icons/gear_undmaarselok_helmet_a.dds",
        texture = GetAbilityIcon(126941),
        showFrame = true,
    },
    ["Aetheric Lancer"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Aetheric Lancer proc is ready or when it will become available, but not the duration of the increased damage.",
        settingsColor = "CD5031",
        id = 226381,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 3000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(26804),
        showFrame = true,
    },
    ["Seventh Legion Brute"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the added weapon damage and health recovery effect can proc.",
        settingsColor = "FCFCCB",
        id = 127271,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        texture = GetAbilityIcon(127271),
        showFrame = true,
    },
    ["Mara's Balm"] = {
        procType = "set",
        event = EVENT_COMBAT_EVENT,
        description = "Displays when the Cleanse effect is able to be applied..",
        settingsColor = "FCFCCB",
        id = 184634,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 30000,
        onCooldown = false,
        timeOfProc = 0,
        texture = "/esoui/art/icons/ability_healer_031.dds",
        showFrame = true,
    },
    -- Placeholder templates. Replace id/result/cooldownDurationMs after
    -- capturing the proc with /cool all on in game.
    ["Kjalnar's Nightmare"] = {
         procType = "set",
         event = EVENT_COMBAT_EVENT,
        description = "Displays Kjalnar's Nightmare proc.",
        settingsColor = "CD5031",
        id = 135088,
        enabled = false,
         result = ACTION_RESULT_DAMAGE,
         cooldownDurationMs = 3000,
        onCooldown = false,
         timeOfProc = 0,
         texture = GetAbilityIcon(135088),
         showFrame = true,
     },
     ["Yandir's Might"] = {
         procType = "set",
         event = EVENT_COMBAT_EVENT,
         description = "Displays Yandir's Might proc.",
         settingsColor = "FCFCCB",
         id = 135950,
         enabled = false,
         result = ACTION_RESULT_EFFECT_GAINED,
         cooldownDurationMs = 500,
         onCooldown = false,
         timeOfProc = 500,
         texture = GetAbilityIcon(135950),
         showFrame = true,
     },

}

-- These two tables work together
-- to map item slot constants to
-- human-readable names.
-- Why two tables? Good question.
PvPCooldownTracker.Data.ITEM_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

PvPCooldownTracker.Data.ITEM_SLOT_NAMES = {
    "Head",
    "Neck",
    "Chest",
    "Shoulders",
    "Main-Hand Weapon",
    "Off-Hand Weapon",
    "Waist",
    "Legs",
    "Feet",
    "Ring 1",
    "Ring 2",
    "Hands",
    "Backup Main-Hand Weapon",
    "Backup Off-Hand Weapon",
}

for _, set in pairs(PvPCooldownTracker.Data.Sets) do
    if set.result == nil then
        set.result = ACTION_RESULT_EFFECT_GAINED
    end
    if set.onCooldown == nil then
        set.onCooldown = false
    end
    if set.timeOfProc == nil then
        set.timeOfProc = 0
    end
    if set.showFrame == nil then
        set.showFrame = true
    end

    if set.texture == nil then
        if type(set.id) == "table" and set.id[1] then
            set.texture = GetAbilityIcon(set.id[1])
        elseif type(set.id) == "number" then
            set.texture = GetAbilityIcon(set.id)
        end
    end
end

