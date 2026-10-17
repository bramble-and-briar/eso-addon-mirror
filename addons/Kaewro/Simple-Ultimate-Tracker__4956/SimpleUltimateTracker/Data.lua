-------------------------------------------------------------------------------
-- SimpleUltimateTracker - Data
--
-- Which effect to time for each ultimate (ultimate ability id -> effect id).
-- For many ultimates the game reports no duration for the ultimate itself;
-- the timer then follows the buff/debuff it applies.
--
-- Ultimates that are not listed here are learned automatically the first
-- time they are cast (see the timer code in SimpleUltimateTracker.lua).
-- Effect ids taken from Fancy Action Bar+ (abilityConfig), used with
-- permission from its authors (Anthonysc, DakJaniels). With thanks.
-------------------------------------------------------------------------------
-- The addon's one global table (shared between its files)
SimpleUltimateTracker = SimpleUltimateTracker or {}
local SUT = SimpleUltimateTracker

SUT.ultEffects = {
    -- Two Handed
    [83216]  = 83217,   -- Berserker Strike
    [83229]  = 83230,   -- Onslaught
    [83238]  = 83239,   -- Berserker Rage
    -- Dual Wield
    [83600]  = 85156,   -- Lacerate
    [85187]  = 85192,   -- Rend
    [85179]  = 85182,   -- Thrive in Chaos
    -- Bow
    [83465]  = 55131,   -- Rapid Fire
    [85257]  = 55131,   -- Toxic Barrage
    [85451]  = 85458,   -- Ballista
    -- Werewolf
    [39075]  = 32455,   -- Pack Leader
    [39076]  = 32455,   -- Werewolf Berserker
    -- Fighters Guild
    [35713]  = 62305,   -- Dawnbreaker
    [40158]  = 62314,   -- Dawnbreaker of Smiting
    [40161]  = 126312,  -- Flawless Dawnbreaker
    -- Mages Guild
    [16536]  = 63430,   -- Meteor
    [40489]  = 63456,   -- Ice Comet
    [40493]  = 63473,   -- Shooting Star
    -- Psijic Order
    [103488] = 104050,  -- Time Stop
    [104059] = 104078,  -- Borrowed Time
    -- Alliance War
    [38563]  = 38564,   -- War Horn
    [40220]  = 40221,   -- Sturdy Horn
    [40223]  = 40224,   -- Aggressive Horn
    -- Sorcerer
    [23634]  = 80459,   -- Summon Storm Atronach
    [23492]  = 80463,   -- Greater Storm Atronach
    [23495]  = 23668,   -- Summon Charged Atronach
    -- Templar
    [21752]  = 21576,   -- Nova
    [21755]  = 22003,   -- Solar Prison
    [21758]  = 22001,   -- Solar Disturbance
    -- Warden
    [86113]  = 132429,  -- Northern Storm
    -- Nightblade
    [33398]  = 61389,   -- Death Stroke
    [36508]  = 61393,   -- Incapacitating Strike
    [113105] = 113107,  -- Incapacitating Strike (120 ultimate)
    [36514]  = 61400,   -- Soul Harvest
    -- Necromancer
    [122174] = 106754,  -- Frozen Colossus
    [122388] = 106754,  -- Glacial Colossus
    [122391] = 106754,  -- Pestilent Colossus
    -- Arcanist
    [189791] = 189792,  -- The Unblinking Eye
    [189837] = 189838,  -- The Tide King's Gaze
}
