-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @kabs12[NA], @DECMVS[EU]
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
-- JHSetTrackers.Data.Sets (table):
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
--												  what kind of tracking it is. Duhhhhh.
--
-- * event (number):				What kind of action identifies the proc happened.
--												  Generally this is EVENT_COMBAT_EVENT or 131102, but
--												  some other values do exist (Wyrd Tree, others).
--
-- * description (string):  Cosmetic. Adds a description to the tooltip.
--
-- * settingsColor (string):    Color in hex. Used to be used for the colors
--												      for each set in the settings menu, but since
--												      the menu was updated they aren't used. Will
--												      probably clean them up at some point.
--
-- * id (number | array):   The ID that identifies the proc condition.
--												  This can also be an array of numbers for proc
--												  conditions that span multiple IDs (Perfected/Non,
--												  synergies, stupid Pirate Skelly, and more).
--
-- * enabled (bool):				Used to identify if tracking and display are enabled.
--												  This is different from if the set is enabled in the
--												  settings. That's a different value stored in savedvars.
--												  This value is pointless here and will probably be
--												  removed in the future.
--
-- * result (number):       The result of the proc. These are numeric, defined
--												  in the table using their constants. When debugging,
--												  the number will appear instead of the constant name,
--												  so refer to the constants section below to match.
--
-- * cooldownDurationMs (number):   Number in milliseconds for the cooldown.
--																  e.g. 30 seconds is 30000
--
-- * onCooldown (bool):     If the set is on cooldown.
--												  This is also pointless here and will
--												  probably be removed in the future.
--
-- * timeOfProc (number):   Time that the proc happened, used in maths to
--												  provide the countdown and cooldown time remaining.
--												  Pointless here, will be removed in the future.
--
-- * texture (string):      The path to the texture to use for the cooldown
--												  display. You can find textures with the TextureIt
--												  addon (though what's there is largely out of date)
--												  or via the method `GetAbilityIcon([abilityId])`.
--												  I just generally use any icon that doesn't
--												  look like ass. A lot look like ass.
--
-- * showFrame (bool):      Enables or disables showing the frame around
--												  the icon. Not used for monster helm icons.
--												  But most monster helm icons look like ass.
--
-- Constants:
--
-- Reference this section to make sense of what result and event numbers in
-- debug messages mean.
--
-- Results:
-- ACTION_RESULT_DAMAGE								  = 1
-- ACTION_RESULT_POWER_DRAIN  				  = 64
-- ACTION_RESULT_POWER_ENERGIZE				  = 128
-- ACTION_RESULT_HEAL								    = 16
-- ACTION_RESULT_EFFECT_GAINED				  = 2240 - The most common
-- ACTION_RESULT_EFFECT_GAINED_DURATION = 2245 - Use 2240 if both show up
-- ACTION_RESULT_ABILITY_ON_COOLDOWN    = 2080

-- Events:
-- EVENT_ABILITY_COOLDOWN_UPDATED       = 131181
-- EVENT_COMBAT_EVENT								    = 131102
-- EVENT_EFFECT_CHANGED								  = 131150
--
-- -----------------------------------------------------------------------------

JHSetTrackers.Data = {}

-- Detect Perfect versions
-- Note: Trailing space!
JHSetTrackers.Data.PerfectString = {
    "Perfected ",
    "Perfect ",
}

JHSetTrackers.Data.Sets = {
  ["Mechanical Acuity"] = {
    procType = "stackSet",
    event = EVENT_EFFECT_CHANGED, --EVENT_COMBAT_EVENT,
    description = "oblivion soul magic goes brrr",
    id = 99204, -- cooldown trigger = 164087
    enabled = false,
    cooldownTrigger = { event = EVENT_COMBAT_EVENT, id = 164087, result = ACTION_RESULT_EFFECT_GAINED_DURATION },
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 25000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_debuff_levitate.dds",
    showFrame = true,
    durationms = 4000,
    stacks = 0,
    endTime = 0,
    cdStart = 0,
    cdEnd   = 0,
  },
  ["Ansuul's Torment"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "go interrupt",
    id = 194105,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_warrior_028.dds",
    showFrame = true,
    durationms = 30000,
    stacks = nil,
  },
  ["Berserking Warrior"] = {
    procType = "stackSet",
    event = EVENT_EFFECT_CHANGED, --EVENT_COMBAT_EVENT,
    description = "Displays the duration and number of stacks.",
    id = 50978,
    enabled = false,
    cooldownTrigger = nil,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/TrackersByJH/SetTrackers/icons/berserking_warrior.dds",
    showFrame = true,
    durationms = 5000,
    stacks = 0,
    endTime = 0,
    cdStart = 0,
    cdEnd   = 0,
  },
  ["Slivers of the Null Arca"] = {
    procType = "stackSet",
    event = EVENT_EFFECT_CHANGED, --EVENT_COMBAT_EVENT,
    description = "Displays the duration and number of stacks.",
    id = 220790,
    enabled = false,
    cooldownTrigger = nil,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 5000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/justice_stolen_unique_ideal_masters_shard.dds",
    showFrame = false,
    durationms = 10000,
    stacks = 0,
    endTime = 0,
    cdStart = 0,
    cdEnd   = 0,
  },
  ["Sul-Xan's Torment"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "30 sec. duration of 9.8% weapon crit chance and 12% crit damage.",
    id = 154737, --154737 buff --157738 soul
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/u30_trial_soulrip.dds",
    showFrame = true,
    durationms = 30000, --30000 buff --6000 soul
    stacks = nil,
  },
  ["Arkasis's Genius"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "ulti boi",
    id = 142660,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 30000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/consumable_potion_012_type_002.dds",
    showFrame = false,
    durationms = 0,
    stacks = nil,
  },
  ["Aegis Caller"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "Displays when proc is available.",
    id = 133493,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 12000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/achievement_u25_dun2_flavor_boss_3b.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
  ["Mara's Balm"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "Displays when the Mara's Balm is available.",
    id = 176923,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 30000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_ava_005.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
["Balorgh"] = {
    procType = "monsterSet",
    event = EVENT_COMBAT_EVENT,
    description = "Displays the duration of the buff.",
    id = 111505,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/gear_undaunted_werewolfbehemoth_head_a.dds",
    showFrame = false,
    durationms = 12000,
    stacks = nil,
  },
["Bloodspawn"] = {
    procType = "monsterSet",
    event = EVENT_COMBAT_EVENT,
    description = "Displays when the Bloodspawn proc is ready or when it will be available.",
    id = 59517,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 5000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/gear_undauntedgargoyle_head_a.dds",
    showFrame = false,
    durationms = 0,
    stacks = nil,
  },
["Death Dealer's Fete"] = {
    procType = "artifact",
    event = EVENT_EFFECT_CHANGED,
    description = "Stacks only. Hidden at 0 stacks.",
    id = 155176,
    enabled = false,
    cooldownTrigger = nil,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/antiquities_u30_mythic_ring02.dds",
    showFrame = false,
    durationms = 0,
    stacks = 0,
    endTime = 0,
  },
["Dark Convergence"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "AoE go brrr!",
    id = 159388,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 25000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/death_recap_magic_aoe.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
["Maarselok"] = {
    procType = "monsterSet",
    event = EVENT_COMBAT_EVENT,
    description = "Displays Maarselok's 4 second proc duration and 10 second cooldown.",
    id = 126941,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 10000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/death_recap_disease_melee.dds",
    showFrame = true,
    durationms = 4000,
    stacks = nil,
  },
["Meritorious Service"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "Meritorious Service (ability ID 61922; set ID 181).",
    id = 61922,
    setId = 181,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 0,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_healer_019.dds",
    showFrame = true,
    durationms = 20000,
    stacks = nil,
  },
["Rallying Cry"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "15 sec. CD",
    id = 166731,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 15000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_healer_005.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
["Rush of Agony"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "8 sec. CD",
    id = 159279,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 8000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_dragonknight_005_b.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
["Whorl of the Depths"] = {
    procType = "set",
    event = EVENT_COMBAT_EVENT,
    description = "LA Goes brr",
    id = 172671,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 18000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/death_recap_cold_aoe.dds",
    showFrame = true,
    durationms = 8000,
    stacks = nil,
  },
["Wrath of Elements"] = {
    procType = "monsterSet",
    event = EVENT_COMBAT_EVENT,
    description = "Vateshran Hollows Destruction Staff",
    id = 147843,
    enabled = false,
    result = ACTION_RESULT_EFFECT_GAINED,
    cooldownDurationMs = 10000,
    onCooldown = false,
    timeOfProc = 0,
    texture = "/esoui/art/icons/ability_mage_041.dds",
    showFrame = true,
    durationms = 0,
    stacks = nil,
  },
}

JHSetTrackers.Data.ReleaseTriggers = {
  ["Turning Tide"] = {
    id = 167062,
    event = EVENT_COMBAT_EVENT,
    result = ACTION_RESULT_DAMAGE,
  },
}

-- These two tables work together
-- to map item slot constants to
-- human-readable names.
-- Why two tables? Good question.
JHSetTrackers.Data.ITEM_SLOTS = {
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

JHSetTrackers.Data.ITEM_SLOT_NAMES = {
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

--[[ Daedric Trickery:
Major Expedition  (92771) with result 2240, hit value 1
Major Protection  (92773) with result 2240, hit value 1
Major Mending     (92774) with result 2240, hit value 1
Major Heroism     (92775) with result 2240, hit value 1
Major Vitality    (92776) with result 2240, hit value 1
]]

-- For later

-- "/esoui/art/icons/ability_warrior_027.dds",
-- "/esoui/art/icons/ability_mage_005.dds",
-- "/esoui/art/icons/ability_mage_009.dds",
-- "/esoui/art/icons/ability_mage_016.dds",
-- "/esoui/art/icons/ability_mage_027.dds",
-- "/esoui/art/icons/ability_mage_030.dds",
-- "/esoui/art/icons/ability_mage_049.dds",
-- "/esoui/art/icons/ability_mage_055.dds",
--
-- "/esoui/art/icons/quest_wraith_ectoplasm.dds", -- no frame
