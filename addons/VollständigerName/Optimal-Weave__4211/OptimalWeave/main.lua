-- =============================================================================
-- === OptimalWeave Core Logic (main.lua)                                    ===
-- =============================================================================
--[[
    AddOn Name:         OptimalWeave
    Description:        Advanced GCD management system for perfect light attack weaving
    Version:            1.18.0
    Author:             Orollas & VollständigerName
    Dependencies:       LibAddonMenu-2.0
--]]

-- =============================================================================
-- == GLOBAL ADDON DEFINITION & VERSION CONTROL ================================
-- =============================================================================
--[[
    Purpose: Addon identity and version tracking
--]]
OptimalWeave = OptimalWeave or {}

-- Global namespace identifier 
OptimalWeave.name = "OptimalWeave"
-- Version (Major=breaking, Minor=features, Patch=fixes)
OptimalWeave.version = "1.17.0"

-- =============================================================================
-- == LOCALIZED ALIASES & RUNTIME REFERENCES ===================================
-- =============================================================================

local OW = OptimalWeave              -- Local namespace alias
local NAME = OW.name                 -- Immutable addon name
local EM = EVENT_MANAGER             -- Event system shortcut

-- =============================================================================
-- == LOCAL VARIABLES ==========================================================
-- =============================================================================
local LFG_ROLE_TANK = 2
local LFG_ROLE_HEAL = 4
-- local LFG_ROLE_DPS = 1 -- future use
local weaponTypeToKey = {
    [WEAPONTYPE_NONE] = "none",
    [WEAPONTYPE_AXE] = "axe",
    [WEAPONTYPE_HAMMER] = "hammer",
    [WEAPONTYPE_SWORD] = "sword",
    [WEAPONTYPE_TWO_HANDED_SWORD] = "twoHandedSword",
    [WEAPONTYPE_TWO_HANDED_AXE] = "twoHandedAxe",
    [WEAPONTYPE_TWO_HANDED_HAMMER] = "twoHandedHammer",
    [WEAPONTYPE_BOW] = "bow",
    [WEAPONTYPE_HEALING_STAFF] = "healingStaff",
    [WEAPONTYPE_RUNE] = "rune",
    [WEAPONTYPE_DAGGER] = "dagger",
    [WEAPONTYPE_FIRE_STAFF] = "fireStaff",
    [WEAPONTYPE_FROST_STAFF] = "frostStaff",
    [WEAPONTYPE_SHIELD] = "shield",
    [WEAPONTYPE_LIGHTNING_STAFF] = "lightningStaff"
}
local GCDOnBarShown = false

-- =============================================================================
-- == DEFAULT CONFIGURATION SETTINGS ===========================================
-- =============================================================================
--[[
    Purpose: Default saved variables
--]]

local defaults = {
    modeSelection = "accountwide",   -- "accountwide" or "character"  
    mode = 1,                        -- Weave mode
    autoLag = true,                  -- Dynamic latency detection toggle
    inputLag = 50,                   -- Manual latency override (ms)
    block = true,                    -- Global input blocking enabled
    combat = true,                   -- Only activate in combat
    blockGroundAbilities = true,     -- Ground AOE double cast protection
    checkTarget = true,              -- Target requirement for weave
    neverBlockedAbilityIDs = {},     -- TODO: Abilities that should never be blocked under any circumstances

    -- =========================================================================
    -- == NIGHTBLADE CLASS SETTINGS ============================================
    -- =========================================================================
    -- Grim Focus ability tracking and configuration
    grimFocusSkillIds = {
        [61919] = false, -- Merciless
        [61927] = false, -- Relentless
        [61902] = false  -- Grim
    },

    -- Buff IDs that indicate Grim Focus stacks are active
    grimFocusStackIds = {
        [122586] = true, -- Merciless
        [122585] = true, -- Grim
        [122587] = true  -- Relentless
    },

    useGrimFocusStacks = false, -- Enable stack-based blocking: Block ability when reaching certain stack count
    grimFocusStacks = 10,       -- How many grim focus stacks

    -- -- TODO: Death Stroke ability configuration
    -- deathStrokeMorphs = {
    --                      -- Death Stroke
    --     [36514] = false  -- Soul Harvest
    --                      -- Incapacitating Strike
    -- },
    -- -- TODO:
    -- incapacitatingStrikeStacks = 120, -- Stack threshold for Incapacitating Strike morph

    -- =========================================================================
    -- == ARCANIST CLASS SETTINGS ==============================================
    -- =========================================================================
    -- Fatecarver beam ability configurations (both magicka and stamina morphs)
    arcaBeamSkillIds = {
        [185805] = false, -- Base Mag
        [183122] = false, -- Exhausting Fatecarver Mag
        [186366] = false, -- Pragmatic Fatecarver Mag
        [193397] = false, -- Base Stam
        [193398] = false, -- Exhausting Fatecarver Stam
        [193331] = false  -- Pragmatic Fatecarver Stam

    },

    -- Tentacular Dread ability configuration
    tentacularDread = {
        [185823] = false -- Tentacular Dread (that one that consumes Crux)
    },

    -- Cephaliarch's Flail ability configuration
    cephaliarchsFlail = {
        [183006] = false -- Cephaliarch's Flail 
    },
    useCruxStacksCephaliarch = false,  -- Cephaliarch's Flail Crux Check

    deactivateArcaBeamBlockAtHpUnder = 20, -- limit value of HP
    checkHpForArcaBeam = true, -- Check HP before beam

    deactivateArcaBeamBlockAtStamUnder = 20, -- limit value of Stam
    checkStamForArcaBeam = true, -- Check Stam before beam

    cruxId = 184220,        -- Crux buff ID
    useCruxStacks = false,  -- Enable Crux-based blocking for Fatecarver abilities
    cruxStacks = 3,         -- Crux stack threshold for Fatecarver blocking
    usecruxStacksTentacular = false, -- Enable Crux-based blocking for Tentacular Dread
    cruxStacksTentacular = 3, -- Crux stack threshold for Tentacular Dread blocking

    -- =========================================================================
    -- == DRAGONKNIGHT CLASS SETTINGS ==========================================
    -- =========================================================================
    MoltenWhip = {
        [20805] = false -- Molten Whip
    },

    -- =========================================================================
    -- == GUILD SETTINGS =======================================================
    -- =========================================================================
    -- Mages guild
    lightMorphs = {
        [30920] = true, -- Magelight
        [40478] = true, -- Inner light
        [40483] = true  -- Radiant Magelight
    },

    -- Fighters guild
    hunterMorphs = {
        [35762] = true, -- Expert Hunter
        [40195] = true, -- Camouflaged Hunter
        [40194] = true  -- Evil Hunter
    },

    -- TODO: Fighters Guild
    dawnbreakerMorphs = {
        [35713] = false, -- Dawnbreaker
        [40161] = false, -- Flawless Dawnbreaker
        [40158] = false  -- Dawnbreaker of Smiting
    },

    -- =========================================================================
    -- == EXECUTE SYSTEM SETTINGS ==============================================
    -- =========================================================================
    useExecuteCheck = false, -- Execute Check Master Toggle: Enable/disable all execute functionality
    executeThreshold = 30,   -- Health Percentage Threshold: Target HP% below which execute abilities are allowed

    executeCheckSpells = {
        [63029] = false, -- Radiant Destruction
        [63044] = false, -- Radiant Glory
        [63046] = false, -- Radiant Oppression
        [34851] = false, -- Impale
        [34843] = false, -- Killer's Blade
        [33386] = false, -- Assassin's Blade
        [19123] = false, -- Mages' Wrath
        [18718] = false, -- Mages' Fury
        [19109] = false, -- Endless Fury
        [28302] = false, -- Reverse Slash
        [38823] = false, -- Reverse Slice
        [38819] = false, -- Executioner
    },

    -- =========================================================================
    -- == GCD SETTINGS =========================================================
    -- =========================================================================
    channelBufferNormal = 50,       -- Standard ability buffer: Extra time (ms) added to non-channeled cast times, Default: 50ms
    channelBufferChanneled = 200,   -- Channeled ability buffer: Extra time (ms) added to channeled abilities, Default: 200ms
    gcdTrackingSlot = 3,            -- Default GCD tracking slot: Action bar slot (3-8) used to monitor GCD state, Default: Slot 3
    autoGcdTrackingSlot = false,    -- Automatic slot selection: Dynamically find active ability slot for GCD tracking
    minGcdThreshold = 10,           -- Minimum GCD detection: Smallest cooldown (ms) recognized as a GCD, Default: 10ms
    baseQueueTime = 950,            -- Base ability queue window: Time window (ms) for queuing next ability, Default: 1050ms

    -- =========================================================================
    -- == ROLE-BASED DEACTIVATION SETTINGS =====================================
    -- =========================================================================
    disableTank = true, -- Tank role deactivation: Automatically disable addon when in tank role
    disableHeal = true, -- Healer role deactivation: Automatically disable addon when in healer role
    originalMode = 0,   -- Original mode storage

    -- =========================================================================
    -- == RESET BEHAVIOR SETTINGS ==============================================
    -- =========================================================================
    resetOnDodge = true,     -- Reset on dodge: Clear GCD state when player dodges
    resetOnBarswap = false,  -- Reset on bar swap: Clear GCD state when swapping bars
    resetAfterSeconds = 25,  -- Inactivity reset timer: Seconds of inactivity before GCD state resets

    -- =========================================================================
    -- == IN COMBAT MENU BLOCKING ==============================================
    -- =========================================================================
    blockLastMenu = true,      -- Block the Last Menu (ALT) during combat
    blockCharMenu = true,      -- Block the character menu (c) during combat

    -- =========================================================================
    -- == WEAPON DEACTIVATION SETTINGS =========================================
    -- =========================================================================
    -- Backbar deactivation settings
    deactivateOnBackbar = {
        features = false,   -- Deactivating other features on Backbar
        weaveAssist = false -- Deactivate weave Assist on Backbar
    },

    deactivateOnWeaponType = {
        none = false,           -- No weapon equipped, Int. = 0
        axe = false,            -- One-handed axe,     Int. = 1
        hammer = false,         -- One-handed hammer,  Int. = 2
        sword = false,          -- One-handed sword,   Int. = 3
        twoHandedSword = false, -- Two-handed sword,   Int. = 4
        twoHandedAxe = false,   -- Two-handed axe,     Int. = 5
        twoHandedHammer = false,-- Two-handed hammer,  Int. = 6
        reservedWeapon = false, -- Reserved weapon,    Int. = 7
        bow = false,            -- Bow,                Int. = 8
        healingStaff = false,   -- Restoration staff,  Int. = 9
        rune = false,           -- Rune (unused),      Int. = 10
        dagger = false,         -- Dagger,             Int. = 11
        fireStaff = false,      -- Inferno staff,      Int. = 12
        frostStaff = false,     -- Frost staff,        Int. = 13
        shield = false,         -- Shield,             Int. = 14
        lightningStaff = false  -- Lightning staff,    Int. = 15
    },

    -- Weapon-based deactivation toggles
    deactivateOnWeapon = {
        features = false,   -- Deactivating other features 
        weaveAssist = false -- Deactivate weave Assist
    },

    -- PvP area deactivation settings
    deactivateInPvP = {
        features = false,   -- Deactivating other features in PvP areas
        weaveAssist = false -- Deactivate weave Assist in PvP areas
    },

    autoEquipWeapons = false,           -- Automatic weapon equipping: Auto-unsheathe weapons in combat/dungeon situations
    deactivateHunterLightInPvP = true,  -- PvP deactivation: Disable Hunter/Light morph blocking in PvP areas

    -- =========================================================================
    -- == CUSTOM BLOCK LIST SETTINGS ===========================================
    -- =========================================================================
    useCustomBlockList = false,                     -- Master toggle for user-defined block list
    useCustomRecastBlockList = false,               -- Master toggle for user-defined recast block list
    useCustomBlockListHealthCheck = false,          -- Enable health-based exceptions for custom block list
    useCustomRecastBlockListHealthCheck = false,    -- Enable health-based exceptions for custom recast block list
    useCustomBlockListHealthPercent = 20,           -- Health threshold (%) for custom block list exceptions
    useCustomRecastBlockListHealthPercent = 20,     -- Health threshold (%) for custom recast block list exceptions
    recastBlockTime = 3,                            -- Time window (seconds) for recast blocking
    
    -- =========================================================================
    -- == RESOURCE-BASED BLOCK LIST SETTINGS ===================================
    -- =========================================================================
    activateResourceBasedBlockingMenu = true, -- Toggle menu visibility 
    useCustomResourceBlockList = false,
    useCustomResourceRecastBlockList = false,
    useCustomBlockListResourceCheck = false,
    useCustomRecastBlockListResourceCheck = false,
    useCustomBlockListResourcePercent = 20,
    useCustomRecastBlockListResourcePercent = 20,
    recastResourceBlockTime = 3, -- In seconds


    -- =========================================================================
    -- == USER-CONFIGURABLE BLOCK LISTS ========================================
    -- =========================================================================
    -- Immediate blocking list: Blocks abilities as soon as pressed
    customBlockList = { -- Example: [12345] = false/true  -> [SpellID] = bool if active in block list
    -- Example: [12345] = true  -- Blocks ability ID 12345 immediately
    },

    -- Recast blocking list: Blocks abilities if recast within time window
    customRecastBlockList = { -- Example: [12345] = false/true  -> [SpellID] = bool if active in block list
    -- Example: [12345] = true  -- Blocks ability ID 12345 if recast too soon
    },

    -- Resource-based blocking list
    customResourceBlockList = { 
    -- Example: [12345] = {
    --     blocked = false,           -- Complete blocked
    --     magickaCheck = false,      -- If Magicka check is used
    --     magickaBlock = false,      -- Check if the spell is Blocked or usable depending on the Magicka Percentage
    --     magickaPercent = 0,        -- Percentage how many Magicka
    --     staminaCheck = false,      -- If Stamina check is used
    --     staminaBlock = false,      -- Check if the spell is Blocked or usable depending on the Stamina Percentage
    --     staminaPercent = 0,        -- Percentage how many Stamina
    -- }
    },

    -- -- Resource-based blocking list
    -- customBlockListNewStyle = { 
    -- -- Example: [12345] = {
    -- --     blocked = false,           -- Complete blocked
    -- --     magickaCheck = false,      -- If Magicka check is used
    -- --     magickaBlock = false,      -- Check if the spell is Blocked or usable depending on the Magicka Percentage
    -- --     magickaPercent = 0,        -- Percentage how many Magicka
    -- --     staminaCheck = false,      -- If Stamina check is used
    -- --     staminaBlock = false,      -- Check if the spell is Blocked or usable depending on the Stamina Percentage
    -- --     staminaPercent = 0,        -- Percentage how many Stamina
    -- --     HealthCheck = false,       -- If Health check is used
    -- --     HealthBlock = false,       -- Check if the spell is Blocked or usable depending on the Health Percentage
    -- --     HealthPercent = 0,         -- Percentage how many Health
    -- --     useRecastBlock = false, 
    -- -- }
    -- },

    -- =========================================================================
    -- == EXPERIMENTAL SETTINGS ================================================
    -- =========================================================================
    blockAoEIfNoTarget = false, -- Experimental: Block ground AoEs when no target is selected
    showGCD = false,            -- Shows the internal GCD monitor 
    -- useNewStyleBlocklist = true,
    blockListsCombatOnly = false,                   -- Blocklists only active while in combat
}

-- =========================================================================
-- == IN COMBAT MENU BLOCKING ==============================================
-- =========================================================================
local inCombatMenuBlockActive = false

local function OnPlayerCombatState(_, inCombat)
    inCombatMenuBlockActive = inCombat
end

-- =============================================================================
-- == DEBUG SYSTEM =============================================================
-- =============================================================================
--[[
    Debug Modes:
    - "block": GCD blocking decisions
    - "condition": Ability condition checks  
    - "info": General state information
    Param:
    - mode: Debug category ("block", "condition", "info")
    - Messages to print
--]]

local DEBUG_MODES = {
    block = false,      -- GCD blocking decisions
    condition = false,  -- Ability condition checks
    info = false       -- General state information
}

local function DebugPrint(mode, ...)
    if DEBUG_MODES[mode] then
        d(...)
    end
end

-- =============================================================================
-- == SLASH COMMANDS ===========================================================
-- =============================================================================
SLASH_COMMANDS["/_ow_debug_block"] = function()
    DEBUG_MODES.block = not DEBUG_MODES.block
    local stateColor = DEBUG_MODES.block and "|c00FF00ON|r" or "|cFF0000OFF|r"
    d("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r DEBUG block ".. stateColor)
end

SLASH_COMMANDS["/_ow_debug_condition"] = function()
    DEBUG_MODES.condition = not DEBUG_MODES.condition
    local stateColor = DEBUG_MODES.condition and "|c00FF00ON|r" or "|cFF0000OFF|r"
    d("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r DEBUG condition ".. stateColor)
end

SLASH_COMMANDS["/_ow_debug_info"] = function()
    DEBUG_MODES.info = not DEBUG_MODES.info
    local stateColor = DEBUG_MODES.info and "|c00FF00ON|r" or "|cFF0000OFF|r"
    d("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r DEBUG info ".. stateColor)
end

SLASH_COMMANDS["/owgcd"] = function()
    OW.sv.showGCD = not OW.sv.showGCD
    local stateColor = OW.sv.showGCD and "|c00FF00ON|r" or "|cFF0000OFF|r"
    d("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r GCD ".. stateColor)
end

 if GetDisplayName() == "@VollständigerName" then
   SLASH_COMMANDS['/console'] = function()  local newVal = IsConsoleUI()and "0" or "1" SetCVar("ForceConsoleFlow.2",newVal) end
 end
   
-- =============================================================================
-- == KEYBIND FUNCTIONS ========================================================
-- =============================================================================
local modeNames = {[1] = "Strict", [2] = "Intelligent", [3] = "Disabled", [4] = "Sequential"}
local function ToggleMode()
    if not OW.sv then return end
    
    -- Cycle through modes: 1->2->3->4->1
    local currentMode = OW.sv.mode or 1
    local newMode = currentMode + 1
    if newMode > 4 then
        newMode = 1
    end
    
    OW.sv.mode = newMode
    --OW.sv.originalMode = 0
    
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Mode set to |cFFD700%s|r", modeNames[newMode]))
end

local function ToggleCustomBlockList()
    if not OW.sv then return end
    
    OW.sv.useCustomBlockList = not OW.sv.useCustomBlockList
    local status = OW.sv.useCustomBlockList and "|c00FF00enabled|r" or "|cFF0000disabled|r"
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Custom Block List %s", status))
end

local function ToggleCustomRecastBlockList()
    if not OW.sv then return end
    
    OW.sv.useCustomRecastBlockList = not OW.sv.useCustomRecastBlockList
    local status = OW.sv.useCustomRecastBlockList and "|c00FF00enabled|r" or "|cFF0000disabled|r"
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Custom Recast Block List %s", status))
end

local function ToggleBackbarFeatures()
    if not OW.sv then return end
    
    OW.sv.deactivateOnBackbar.features = not OW.sv.deactivateOnBackbar.features
    local status = OW.sv.deactivateOnBackbar.features and "|c00FF00enabled|r" or "|cFF0000disabled|r"
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Backbar Features deactivation %s", status))
end

local function ToggleBackbarWeaveAssist()
    if not OW.sv then return end
    
    OW.sv.deactivateOnBackbar.weaveAssist = not OW.sv.deactivateOnBackbar.weaveAssist
    local status = OW.sv.deactivateOnBackbar.weaveAssist and "|c00FF00enabled|r" or "|cFF0000disabled|r"
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Backbar Weave Assist deactivation %s", status))
end

local function ToggleExecuteCheck()
    if not OW.sv then return end
    
    OW.sv.useExecuteCheck = not OW.sv.useExecuteCheck
    local status = OW.sv.useExecuteCheck and "|c00FF00enabled|r" or "|cFF0000disabled|r"
    d(string.format("|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r: Execute Check %s", status))
end

-- =============================================================================
-- === TO GLOBAL FOR KEYBIND FUNCTIONS =========================================
-- =============================================================================

OptimalWeave.ToggleMode = ToggleMode
OptimalWeave.ToggleCustomBlockList = ToggleCustomBlockList
OptimalWeave.ToggleCustomRecastBlockList = ToggleCustomRecastBlockList
OptimalWeave.ToggleBackbarFeatures = ToggleBackbarFeatures
OptimalWeave.ToggleBackbarWeaveAssist = ToggleBackbarWeaveAssist
OptimalWeave.ToggleExecuteCheck = ToggleExecuteCheck

-- =============================================================================
-- == AUTOMATIC GCD TRACKING SLOT SELECTION ====================================
-- =============================================================================
--[[
    Purpose:
      Automatically selects the best GCD tracking slot by checking slots 3-8
      for active cooldowns. Cycles through slots until one with valid cooldown
      data is found.
--]]

local function AutoSelectGcdTrackingSlot()

    local currentSlot = OW.sv.gcdTrackingSlot
    local newSlot = nil
    
    -- Go through all slots from 3 to 8, starting with the next slot.
    for i = 1, 6 do  -- 6 Slot: 3 to 8
        local testSlot = (currentSlot - 3 + i) % 6 + 3
        local cd, duration, global, globalSlotType = GetSlotCooldownInfo(testSlot)
        
        DebugPrint("info", string.format("Testing slot %d: cd=%s, duration=%s", testSlot, tostring(cd), tostring(duration)))
        
        -- Check whether the slot has valid cooldown data
        if cd and cd > 0 and duration and duration > 0 then
            newSlot = testSlot
            DebugPrint("info", string.format("Selected slot %d for GCD tracking", newSlot))
            break
        end
    end
    
    -- Fallback to slot 3 if no valid slot was found
    if not newSlot then
        newSlot = 3
        DebugPrint("info", "No valid slot found, defaulting to slot 3")
    end
    
    OW.sv.gcdTrackingSlot = newSlot
end

local function UpdateGcdTrackingSlot()
    if OW.sv.autoGcdTrackingSlot then
        AutoSelectGcdTrackingSlot()
    end
end

-- =============================================================================
-- == GET UNIT PLAYER POWERTYPE ================================================
-- =============================================================================
--[[
    Purpose: Returns the player's power types as a percentage
    Returns: percentHealth, percentStamina, percentMagicka
--]]

local function GetUnitPlayerPowertype()
    local currentHealth, maxHealth, effHealth = GetUnitPower('player', POWERTYPE_HEALTH)
    local percentHealth = (effHealth > 0) and (currentHealth / effHealth * 100) or 0
    DebugPrint("info", string.format("HP: current: %d / max.: %d / eff. max. %d / Percent %d ", currentHealth, maxHealth, effHealth, percentHealth))

    local currentStamina, maxStamina, effStamina = GetUnitPower('player', POWERTYPE_STAMINA)
    local percentStamina   = (effStamina > 0) and (currentStamina  / effStamina   * 100) or 0
    DebugPrint("info", string.format("Stamina: current: %d / max.: %d / eff. max. %d / Percent %d ", currentStamina, maxStamina, effStamina, percentStamina))

    local currentMagicka, maxMagicka, effMagicka = GetUnitPower('player', POWERTYPE_MAGICKA)
    local percentMagicka   = (effMagicka > 0) and (currentMagicka   / effMagicka   * 100) or 0
    DebugPrint("info", string.format("Magicka: current: %d / max.: %d / eff. max. %d / Percent %d ", currentMagicka, maxMagicka, effMagicka, percentMagicka))

    return percentHealth, percentStamina, percentMagicka
end

-- =============================================================================
-- == AUTOMATIC WEAPON EQUIPPING ===============================================
-- =============================================================================
--[[
    Purpose: Automatically unsheathe weapons when leaving various UI states
--]]

local function EquipWeaponsStateChange()
    if not OW.sv.autoEquipWeapons then return end
    
    if ArePlayerWeaponsSheathed() and (IsPlayerInRaid() or IsUnitInDungeon('player') or IsUnitInCombat('player'))  then
        DebugPrint("info", "Draw weapon")
        TogglePlayerWield()
    end
end

-- =============================================================================
-- == DEACTIVATE BASED ON WEAPON ===============================================
-- =============================================================================
--[[
    Purpose: Weapon-Based Deactivation Check
    return: Boolean indicating if features should be deactivated for current weapons      
--]]

local function deactivateBasedOnWeapon()
    local ActiveWeaponPair, _ = GetActiveWeaponPairInfo()
    local slots
    
    if ActiveWeaponPair == 1 then
        -- Main Hand
        slots = {EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND}
    else
        -- Backbar
        slots = {EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF}
    end
    
    for _, slot in ipairs(slots) do
        local weaponType = GetItemWeaponType(BAG_WORN, slot)
        local key = weaponTypeToKey[weaponType]
        if key and OW.sv.deactivateOnWeaponType[key] then
            return true
        end
    end
    
    return false
end

-- =============================================================================
-- == EXECUTE CHECK SYSTEM =====================================================
-- =============================================================================
--[[

    Purpose:
      Evaluates the current target health to determine whether
      an ability should remain active or be blocked.

    return: Boolean indicating if ability should be allowed      
--]]
local function checkExecuteReady() -- id)
    local active = false  -- Default: block the ability
    
    -- Check if target exists and is not dead
    if not DoesUnitExist('reticleover') or IsUnitDead('reticleover') then
        DebugPrint("condition", "Execute Check: Target does not exist or is dead")
        return active
    end
    
    -- Get current and maximum health values of target
    local currentHealth, maxHealth = GetUnitPower('reticleover', POWERTYPE_HEALTH)
    DebugPrint("condition", string.format("Execute Check: Target Health - Current: %d, Maximum: %d", currentHealth, maxHealth))
    
    -- Validate health values to avoid division by zero
    if currentHealth == 0 or maxHealth == 0 then
        DebugPrint("condition", "Execute Check: Invalid health values")
        return active
    end
    
    -- Calculate health percentage
    local percentHealth = (currentHealth / maxHealth) * 100
    DebugPrint("condition", string.format("Execute Check: Health Percentage: %.1f%%, Threshold: %.1f%%", percentHealth, OW.sv.executeThreshold))
    
    -- Check if health is below execute threshold
    if percentHealth <= OW.sv.executeThreshold then
        active = true  -- Allow ability in execute phase
        DebugPrint("condition", "Execute Check: EXECUTE PHASE ACTIVE - Ability allowed")
    else
        DebugPrint("condition", "Execute Check: Target not in execute phase - Ability blocked")
    end
    
    return active
end

-- =============================================================================
-- == ABILITY VALIDATION SUBSYSTEM =============================================
-- =============================================================================
--[[
    Purpose: Check against if in never block list
    return: Boolean blocking status
--]]

local function IsBlockedNeverAbilityID(id)
    return OW.sv.neverBlockedAbilityIDs and OW.sv.neverBlockedAbilityIDs[id] or false
end

-- =============================================================================
-- == ROLE VALIDATION SUBSYSTEM ================================================
-- =============================================================================
--[[
    Purpose:
      Manages automatic mode switching based on the player's selected role.
      Disables the addon for Tank and Healer roles when configured, while
      preserving the original mode for DPS roles.
--]]

local function CheckRoleOverride()
    local role = GetSelectedLFGRole()

    if (role == LFG_ROLE_TANK and OW.sv.disableTank) or
       (role == LFG_ROLE_HEAL and OW.sv.disableHeal) then
        -- Just note when we were in DD and not yet saved
        if OW.sv.mode ~= 3 and OW.sv.originalMode == 0 then
            OW.sv.originalMode = OW.sv.mode
        end
        -- Tank or Healer on Mode set to None
        OW.sv.mode = 3

    else
        -- DD or disabled restriction -> restore saved mode
        if OW.sv.originalMode ~= 0 then
            OW.sv.mode = OW.sv.originalMode
        end
    end
end

OW.CheckRoleOverride = CheckRoleOverride

-- =============================================================================
-- == CHECK IF GRIM FOCUS STATUS ===============================================
-- =============================================================================
--[[
    Purpose:
      Determines whether an ability should be blocked based on the current Grim Focus
      stacks.

    Param: Ability Id     
    return: Boolean input permission
--]]

local function checkGrimFocus(id)
    local active = false -- Initialization of default for block of grim focus
    local stackLimit = OW.sv.grimFocusStacks

    if not OW.sv.useGrimFocusStacks then
        stackLimit = 10
    end

    for buffIndex = 1, GetNumBuffs('player') do
        local _, _, timeEnding, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', buffIndex)
        if 61927 == id and OW.sv.grimFocusStackIds[abilityId] then
           if OW.sv.useGrimFocusStacks and stackCount >= stackLimit and not OW.sv.grimFocusSkillIds[61927] then
                active = false
                break
            else 
                active = true
                break
            end

        elseif OW.sv.grimFocusStackIds[abilityId] then
            if (OW.sv.useGrimFocusStacks or OW.sv.grimFocusSkillIds[id]) and stackCount >= stackLimit then
                active = false
                break
            else 
                active = true
                break
            end
        end
    end
    return active
end

-- =============================================================================
-- == CHECK CRUX STACK STATUS ==================================================
-- =============================================================================
--[[
Function: checkCruxStacks
    Purpose:
      Evaluates the current Crux buff status on the player to determine whether
      an ability should remain active or be blocked. 

    Param: Health and stanina in percent
    return: Boolean input permission
--]]

local function checkCruxStacks(percentHealth, percentStamina)
    local active = true 
    DebugPrint("condition", "Check Crux stacks block in checkCruxStacks(")
    DebugPrint("condition", "OW.sv.cruxId ".. tostring(OW.sv.cruxId))

    if (OW.sv.checkHpForArcaBeam and percentHealth <= OW.sv.deactivateArcaBeamBlockAtHpUnder) or (OW.sv.checkStamForArcaBeam and percentStamina <= OW.sv.deactivateArcaBeamBlockAtStamUnder) then
        active = false
        DebugPrint("condition", "active = false")
    else    
        for buffIndex = 1, GetNumBuffs('player') do
            local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', buffIndex)
            DebugPrint("condition", "Buff"..abilityId)
            if OW.sv.cruxId == abilityId then
                DebugPrint("condition", "Check Crux stacks block in OW.sv.cruxId == abilityId")
                if stackCount >= OW.sv.cruxStacks then
                    active = false
                    DebugPrint("condition", "active = false")
                    break
                else 
                    active = true
                    DebugPrint("condition", "active = true")
                    break
                end
            end
        end    
    end
    return active
end

-- =============================================================================
-- == CHECK CRUX STACK STATUS FOR CEPHALIARCH'S FLAIL ==========================
-- =============================================================================
--[[
    Purpose:
      Evaluates the current Crux buff status on the player to determine whether
      Cephaliarch's Flail should be allowed or blocked. 

    return: Boolean indicating if ability should be allowed
--]]

local function checkCruxStacksCephaliarch()
    local active = false 
    DebugPrint("condition", "Check Crux stacks block in checkCruxStacksCephaliarch")
    DebugPrint("condition", "OW.sv.cruxId ".. tostring(OW.sv.cruxId))
    
    for buffIndex = 1, GetNumBuffs('player') do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', buffIndex)
        DebugPrint("condition", "Buff "..abilityId)
        if OW.sv.cruxId == abilityId then
            DebugPrint("condition", "Check Crux stacks block in OW.sv.cruxId == abilityId")
            if stackCount >= 3 then  -- Always block at 3 stacks
                active = true
                DebugPrint("condition", "active = true due to 3+ Crux stacks")
                break
            else 
                active = false
                DebugPrint("condition", "active = false - less than 3 Crux stacks")
                break
            end
        end
    end    
    return active
end

-- =============================================================================
-- == CHECK CRUX STACK STATUS FOR TENTACULAR DREAD =============================
-- =============================================================================
--[[
    Purpose:
      Evaluates the current Crux buff status on the player to determine whether
      an ability should remain active or be blocked.
    return: Boolean input permission
--]]
local function checkCruxStacksTentacular()
    local active = true 
    DebugPrint("condition", "Check Crux stacks block in checkcruxStacksTentacular")
    DebugPrint("condition", "OW.sv.cruxId ".. tostring(OW.sv.cruxId))
    
    for buffIndex = 1, GetNumBuffs('player') do
        local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', buffIndex)
        DebugPrint("condition", "Buff"..abilityId)
        if OW.sv.cruxId == abilityId then
            DebugPrint("condition", "Check Crux stacks block in OW.sv.cruxId == abilityId")
            if stackCount >= OW.sv.cruxStacksTentacular then
                active = false
                DebugPrint("condition", "active = false")
                break
            else 
                active = true
                DebugPrint("condition", "active = true")
                break
            end
        end    
    end
    return active
end


-- =============================================================================
-- == GROUND ABILITY DETECTION SYSTEM ==========================================
-- =============================================================================
--[[
    Purpose: Identify ground-targeted abilities with caching
    Param: AbilityID
    return: Boolean ground-target status
--]]

-- Cache localized ground target description
local groundString = GetString(SI_ABILITY_TOOLTIP_TARGET_TYPE_GROUND)
local groundAbilities = {}  -- Cach
local GROUND_CACHE_LIMIT = 50 -- 50 is my best guess

local function CheckGroundAbility(id)
    -- Cache miss handling
    if groundAbilities[id] == nil then
         if #groundAbilities > GROUND_CACHE_LIMIT then
            groundAbilities = {}
        end
        -- Execute string comparison once per ability
        groundAbilities[id] = (GetAbilityTargetDescription(id) == groundString)
    end
    return groundAbilities[id]  -- Return cached value
end

-- =============================================================================
-- == COMBAT STATE MANAGEMENT ==================================================
-- =============================================================================
--[[
    State Machine Definition:
    0 = Inactive: No GCD restrictions
    1 = Locked: GCD active, no inputs
    2 = QueueWindow: Valid LA window
    3 = LAQueued: Light Attack pending
    4 = SkillQueued: Ability queued
--]]

local GCD_STAGE = 0  -- Current state machine position
local CHANNEL = 0    -- Channel expiration timestamp
--local LAST_ABILITY = 0  -- Last used ability ID tracker. Not currently in used, maybe needed for the blocking feature from Kalitva
local timeSinceLastCast = 0  -- Time of last cast in milliseconds

-- =============================================================================
-- == RESET GCD ================================================================
-- =============================================================================
--[[
    Purpose: Reset states 
--]]

local function ResetGCD(reason)
    GCD_STAGE = 0
    CHANNEL = 0
    -- LAST_ABILITY = 0
    timeSinceLastCast = 0
    DebugPrint("block", "Reset: " .. (reason or "unknown"))
end

local function ResetGCDOnDodge()
    if OW.sv.resetOnDodge then ResetGCD("Dodge") end
end

local function ResetGCDOnBarswap()
    if OW.sv.resetOnBarswap then ResetGCD("Barswap") end
end

local function OnPlayerStunned()
    ResetGCD("Stunned/Silenced etc.")
end

local function CastCanceled()
    if IsBlockActive() then ResetGCD("Canceled") end
end    

-- TODO:
-- local function BarswapSound()
--     PlaySound(SOUNDS.EMPEROR_CORONATION_IMPERIAL)
-- end

-- =============================================================================
-- == PVP WORLD CHECK ==========================================================
-- =============================================================================
--[[
    Purpose: Sets IsInPvpWorld on true if player is in pvp
--]]

local IsInPvpWorld = false

local function PvpWorldCheck()
    IsInPvpWorld = IsPlayerInAvAWorld() or IsActiveWorldBattleground() 
end

-- =============================================================================
-- == RESOURCE-BASED BLOCK LIST CHECK ==========================================
-- =============================================================================
--[[
    Purpose:
      Evaluates all conditions for a spell in the customResourceBlockList
      and determines if it should be blocked.
    
    Structure of spellData:
      spellData = {
          blocked = false,           -- Complete blocked
          magickaCheck = false,      -- If Magicka check is used
          magickaBlock = false,      -- Check if the spell is Blocked or usable depending on the Magicka Percentage
          magickaPercent = 0,        -- Percentage how many Magicka
          staminaCheck = false,      -- If Stamina check is used
          staminaBlock = false,      -- Check if the spell is Blocked or usable depending on the Stamina Percentage
          staminaPercent = 0,        -- Percentage how many Stamina
          recastBlock = false,       -- Recast Block is used
          recastTime = 0             -- Recast Block time in seconds
      }
--]]

local function CheckResourceBlockList(spellId, percentStamina, percentMagicka)
    
    -- Get spell data
    local spellData = OW.sv.customResourceBlockList[spellId]
    if not spellData then
        return false  -- Spell not in resource block list
    end
    
    DebugPrint("condition", string.format("Checking resource block for spell ID %d", spellId))
    
    -- 1. Check if spell block is active
    if not spellData.blocked then
        DebugPrint("condition", "Resource Block: Spell is active")
        return false
    end
    
    -- 2. Magicka check
    if spellData.magickaCheck then
        
        DebugPrint("condition", string.format("Magicka Check: Current: %.1f%%, Threshold: %.1f%%, Mode: %s", 
        percentMagicka, spellData.magickaPercent, 
        spellData.magickaBlock and "Block when below" or "Allow only when below"))
        
        if spellData.magickaBlock then
            -- Block when magicka is below threshold
            if percentMagicka <= spellData.magickaPercent then
                DebugPrint("condition", "Resource Block: Magicka below threshold - Blocking")
                return true
            end
        else
            -- Allow only when magicka is below threshold (block when above)
            if percentMagicka > spellData.magickaPercent then
                DebugPrint("condition", "Resource Block: Magicka above threshold - Blocking")
                return true
            end
        end
    end
    
    -- 3. Stamina check
    if spellData.staminaCheck then
        
        DebugPrint("condition", string.format("Stamina Check: Current: %.1f%%, Threshold: %.1f%%, Mode: %s", 
        percentStamina, spellData.staminaPercent, 
        spellData.staminaBlock and "Block when below" or "Allow only when below"))
        
        if spellData.staminaBlock then
            -- Block when stamina is below threshold
            if percentStamina <= spellData.staminaPercent then
                DebugPrint("condition", "Resource Block: Stamina below threshold - Blocking")
                return true
            end
        else
            -- Allow only when stamina is below threshold (block when above)
            if percentStamina > spellData.staminaPercent then
                DebugPrint("condition", "Resource Block: Stamina above threshold - Blocking")
                return true
            end
        end
    end
        
    DebugPrint("condition", "Resource Block: No blocking conditions met")
    return false
end


-- =============================================================================
-- == ACTION SLOT PROCESSING ===================================================
-- =============================================================================
--[[
    Purpose: Extract slot from debug stack
    return: Action slot number (0-8)
--]]

local function GetActionSlot()
    -- Extract slot from trace, TODO: cleaner way
    --d('ActionButton Traceback'..debug.traceback():match('keybind = \".*ACTION_BUTTON_(%d)'))
    return tonumber(debug.traceback():match('keybind = \".*ACTION_BUTTON_(%d)')) or 0
end

-- =============================================================================
-- == CORE INPUT VALIDATION LOGIC ==============================================
-- =============================================================================
--[[
    Purpose: Main decision gatekeeper
    Param: Actionslot
    return: Boolean input permission
--]]

local function ShouldBlockSlot(slot)

    local percentHealth, percentStamina, percentMagicka = GetUnitPlayerPowertype()
    -- check for inactivity
    if timeSinceLastCast > 0 and (timeSinceLastCast + (OW.sv.resetAfterSeconds * 1000)) < GetGameTimeMilliseconds() then
        ResetGCD()
        DebugPrint("block", "Reset due to inactivity after " .. OW.sv.resetAfterSeconds .. " seconds")
    end

    -- Global block conditions
    local shouldBlock = (OW.sv.block and IsBlockActive()) or 
                (OW.sv.combat and not IsUnitInCombat('player')) or 
                (OW.sv.checkTarget and not IsUnitAttackable('reticleover'))
    
    -- Extract action details
    local id = GetSlotBoundId(slot)
    local isGround = CheckGroundAbility(id)
    -- local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo('player', buffIndex)
    
    -- DebugPrint("info", "Buff"..abilityId)
    DebugPrint("info", "id "..id)

    -- Hard block exit
    if shouldBlock and not OW.sv.blockGroundAbilities then
        return false
    end

    -- TODO:
    -- if OW.sv.blockAoEIfNoTarget and isGround and not DoesUnitExist('reticleover') then -- Dosen´t work!, will fix it later (Wish from kalitva) =================================================== 
    --     DebugPrint("condition", "Target check for AoE, Block AoE") 
    --     return true -- Block
    -- end

    local blockListsActive = not OW.sv.blockListsCombatOnly or (OW.sv.blockListsCombatOnly and IsUnitInCombat('player'))

    -- Resource-Based Block List Check
    if blockListsActive and OW.sv.useCustomResourceBlockList and CheckResourceBlockList(id, percentStamina, percentMagicka) then
        DebugPrint("condition", "Spell blocked by resource block list")
        return true
    end

    -- Custom Block List Check
    if blockListsActive and OW.sv.useCustomBlockList and OW.sv.customBlockList[id] then
        DebugPrint("condition", "Custom Block List: Spell found in custom block list")
        
        -- Health check for Custom Block List
        if OW.sv.useCustomBlockListHealthCheck then
            DebugPrint("condition", string.format("Custom Block List Health Check: HP Percent = %.1f%%, Threshold = %d%%", percentHealth, OW.sv.useCustomBlockListHealthPercent))
            
            if percentHealth <= OW.sv.useCustomBlockListHealthPercent then
                DebugPrint("condition", "Custom Block List: Health below threshold, NOT blocking")
                return false
            end
        end
        
        DebugPrint("condition", "Custom Block List: Spell blocked by custom block list")
        return true
    end


    -- Custom Recast Block List Check
    if blockListsActive and OW.sv.useCustomRecastBlockList and OW.sv.customRecastBlockList[id] then
        DebugPrint("condition", "Custom Recast Block List: Spell found in custom recast block list")
        
        -- Health check for Custom Recast Block List
        if OW.sv.useCustomRecastBlockListHealthCheck then
            DebugPrint("condition", string.format("Custom Recast Block List Health Check: HP Percent = %.1f%%, Threshold = %d%%", percentHealth, OW.sv.useCustomRecastBlockListHealthPercent))
            
            if percentHealth <= OW.sv.useCustomRecastBlockListHealthPercent then
                DebugPrint("condition", "Custom Recast Block List: Health below threshold, NOT blocking")
                return false
            end
        end
        
        local timeRemainingMS = GetActionSlotEffectTimeRemaining(slot)
        DebugPrint("condition", string.format("Custom Recast Block: timeRemainingMS = %d, threshold = %d", timeRemainingMS, OW.sv.recastBlockTime * 1000))
        if timeRemainingMS > (OW.sv.recastBlockTime * 1000) then
            DebugPrint("condition", "Custom Recast Block: Spell blocked by custom recast block list")
            return true
        end
    end

    -- PvP Deactivation Check
    if OW.sv.deactivateInPvP.features and IsInPvpWorld then
        DebugPrint("block", "disable features in PvP")
        return false
    end

    -- disable on backbar
    local ActiveWeaponPair, _ = GetActiveWeaponPairInfo()
    if (OW.sv.deactivateOnBackbar.features  and (ActiveWeaponPair == 2)) or (OW.sv.deactivateOnWeapon.features  and deactivateBasedOnWeapon()) then
        DebugPrint("block", "disable features")
        return false
    end

    -- Grim Focus block
    if (OW.sv.grimFocusSkillIds[id] or OW.sv.useGrimFocusStacks) and checkGrimFocus(id) then
        DebugPrint("condition", "Grim Focus block in ShouldBlockSlot")
        return true
    end 

    -- Arca Beam
    -- d(OW.sv.arcaBeamSkillIds[id] )
    -- Check Crux stacks
    if OW.sv.arcaBeamSkillIds[id] and OW.sv.useCruxStacks and checkCruxStacks(percentHealth, percentStamina) then
        DebugPrint("condition", "Check Crux stacks block in ShouldBlockSlot")
        return true
    end 

    -- Cephaliarch's Flail
    if OW.sv.cephaliarchsFlail[id] and OW.sv.useCruxStacksCephaliarch and checkCruxStacksCephaliarch() then
        DebugPrint("condition", "Cephaliarch's Flail block in ShouldBlockSlot")
        return true
    end

    -- Tentacular Dread
    if OW.sv.tentacularDread[id] and OW.sv.usecruxStacksTentacular and checkCruxStacksTentacular() then
        DebugPrint("condition", "Check Crux stacks block in ShouldBlockSlot")
        return true
    end 

    -- Execute Check: Block spell until execute phase is reached
    if OW.sv.useExecuteCheck and OW.sv.executeCheckSpells[id] then
        DebugPrint("condition", string.format("Execute Check: Checking spell ID %d", id))
        if checkExecuteReady() then
            DebugPrint("condition", "Execute Check: Spell blocked by Execute Check")
            return false
        else
            DebugPrint("condition", "Execute Check: Spell permitted by Execute Check")
            return true
        end
    end

    -- Light Morphs & Hunter Morphs block in non-PvP areas
    if not (OW.sv.deactivateHunterLightInPvP and IsInPvpWorld) then
        -- Mages Guild Light morphs block
        if OW.sv.lightMorphs[id] or OW.sv.hunterMorphs[id] then
            DebugPrint("condition", "Light/Hunter block")
            -- ResetGCD()
            return true
        end
    end

    if OW.sv.MoltenWhip[id] then
        DebugPrint("condition", "MoltenWhip block")
        return true
    end

    -- Special case blocking 
    if (shouldBlock and not isGround) or IsBlockedNeverAbilityID(id) then
        return false
    end

    if OW.sv.mode == 4 and GCD_STAGE > 0 and GCD_STAGE ~= 3 and slot >= 3 and slot <= 8 then
        DebugPrint("condition", "GCD_STAGE block")
        return true
    end    

    -- Latency calculations
    local cd, duration, global, globalSlotType = GetSlotCooldownInfo(OW.sv.gcdTrackingSlot)
    DebugPrint("info", string.format(" remain %i , duration %i , global %s , globalSlotType %s", cd, duration, tostring(global), globalSlotType))
    local inputLag = OW.sv.autoLag and zo_min(GetLatency() / 2 - 1, 300) or OW.sv.inputLag
    local currentTime = GetGameTimeMilliseconds()

    -- State machine transitions
    if cd <= inputLag and currentTime > CHANNEL - inputLag then
        GCD_STAGE = (cd < 1 or GCD_STAGE < 4) and 0 or GCD_STAGE
    elseif cd > 0 and GCD_STAGE == 0 then
        GCD_STAGE = 1
    end
        
    -- Final decision matrix
    local allow = GCD_STAGE > 0 and 
                slot >= 3 and slot <= 8 and 
                (isGround or (not IsBlockedNeverAbilityID(id))) and 
                (GCD_STAGE >= 3 or OW.sv.mode == 1 or isGround)
    
    -- Hard mode queuing
    if not allow and cd > 0 and (OW.sv.mode == 1 or OW.sv.mode == 4) then
        GCD_STAGE = 4
    end

    return allow
end

-- =============================================================================
-- == SHOW GLOBAL COOLDOWN ON BAR ==============================================
-- =============================================================================
--[[
    Function: ShowGcdOnBar
    Purpose: Visual toggle for GCD (Builtin ESO function)
--]]

local function ShowGcdOnBar()
    if OW.sv.showGCD and not GCDOnBarShown then
        ZO_ActionButtons_ToggleShowGlobalCooldown()
        GCDOnBarShown = true
    end    
    if not OW.sv.showGCD and GCDOnBarShown then
        ZO_ActionButtons_ToggleShowGlobalCooldown()
        GCDOnBarShown = false
    end    
end


-- =============================================================================
-- == ABILITY USAGE HANDLER ====================================================
-- =============================================================================
--[[
    Purpose: Track ability activations
    param slot: Activated action slot
--]]
local function AbilityUsed(_, slot)
    ShowGcdOnBar()
    if OW.sv.mode == 3 then 
        return
    end

    -- PvP Deactivation Check
    if OW.sv.deactivateInPvP.weaveAssist and IsInPvpWorld then
        DebugPrint("block", "disable Weave Assist in PvP")
        return
    end

    local ActiveWeaponPair, _ = GetActiveWeaponPairInfo()
    if (OW.sv.deactivateOnBackbar.weaveAssist and (ActiveWeaponPair == 2)) or (OW.sv.deactivateOnWeapon.weaveAssist and deactivateBasedOnWeapon()) then
        DebugPrint("block", "disable Weave Assist")
        return
    end

    -- Light Attack handling
    if slot == 1 then
        GCD_STAGE = 3  -- Set LA queued state
    -- Skill slot handling (3-8)
    elseif slot >= 3 and slot <= 8 then
        --local cd = GetSlotCooldownInfo(OW.sv.gcdTrackingSlot)
        local cd, duration, global, globalSlotType = GetSlotCooldownInfo(OW.sv.gcdTrackingSlot)
        DebugPrint("info", string.format(" remain %i , duration %i , global %s , globalSlotType %s", cd, duration, tostring(global), globalSlotType))
        GCD_STAGE = (cd < (OW.sv.minGcdThreshold)) and 2 or 1
        
        local id = GetSlotBoundId(slot)
        local isChanneled, castTime = GetAbilityCastInfo(id)
        
        -- Channel time calculation
        if isChanneled or castTime > 0 then
            local buffer = isChanneled and OW.sv.channelBufferChanneled 
                          or OW.sv.channelBufferNormal
            CHANNEL = GetGameTimeMilliseconds() + 
                     zo_max(OW.sv.baseQueueTime, castTime + buffer)
        else
            CHANNEL = 0  -- No channel time
        end
        
        --LAST_ABILITY = id  -- Update ability memory
    end
    timeSinceLastCast = GetGameTimeMilliseconds()
end

-- =============================================================================
-- == ABILITY ADDITION TO BLOCK LISTS FUNCTIONS ================================
-- =============================================================================
--[[
    Purpose: Add Ability to the Block Lists
    Param abilityId: The ID of the ability to add
    param abilityName: The name of the ability 
--]]
local OWColoredName = '|c6D6D6DOp|r|c8A8A8Atim|r|cA7A7A7al |r|cC4C4C4Wea|r|c6D6D6Dve|r'
local function AddToBlockList(abilityId, abilityName)
    if not OW.sv then return end

    if OW.sv.customBlockList[abilityId] ~= nil then
        -- d(string.format(
        --     OWColoredName .. ' |cFFFFFFSpell already in Block List: |c00FF00%d|r|cFFFFFF - %s|r', 
        --     abilityId, 
        --     abilityName
        -- ))
        ZO_Dialogs_ShowDialog("OW_ID_IS_IN_SV_DIALOG")
        return
    end
    
    OW.sv.customBlockList[abilityId] = true
    -- d(string.format(
    --     OWColoredName .. ' |cFFFFFFAdded to Block List: |c00FF00%d|r|cFFFFFF - %s ("/reloadui" is required)|r', 
    --     abilityId, 
    --     abilityName
    -- ))
    ZO_Dialogs_ShowDialog("OW_RELOAD_DIALOG")
end

local function AddToRecastBlockList(abilityId, abilityName)
    if not OW.sv then return end

    if OW.sv.customRecastBlockList[abilityId] ~= nil then
        -- d(string.format(
        --     OWColoredName .. ' |cFFFFFFSpell already in Recast Block List: |c00FF00%d|r|cFFFFFF - %s|r', 
        --     abilityId, 
        --     abilityName
        -- ))
        ZO_Dialogs_ShowDialog("OW_ID_IS_IN_SV_DIALOG")
        return
    end
    
    OW.sv.customRecastBlockList[abilityId] = true
    -- d(string.format(
    --     OWColoredName .. ' |cFFFFFFAdded to Recast Block List: |c00FF00%d|r|cFFFFFF - %s ("/reloadui" is required)|r', 
    --     abilityId, 
    --     abilityName
    -- ))
    ZO_Dialogs_ShowDialog("OW_RELOAD_DIALOG")
end

local function AddToResourceBlockList(abilityId, abilityName)
    if not OW.sv then return end
    
    -- Check if spell already exists in resource block list
    if OW.sv.customResourceBlockList[abilityId] ~= nil then
        -- d(string.format(
        --     OWColoredName .. ' |cFFFFFFSpell already in Resource Block List: |c00FF00%d|r|cFFFFFF - %s|r', 
        --     abilityId, 
        --     abilityName
        -- ))
        ZO_Dialogs_ShowDialog("OW_ID_IS_IN_SV_DIALOG")
        return
    end
    
    -- Add Spell to resource block list with default structure
    OW.sv.customResourceBlockList[abilityId] = {
        blocked = false,           -- Complete blocked
        magickaCheck = false,      -- If Magicka check is used
        magickaBlock = false,      -- Block when magicka below threshold (true=block, false=allow only)
        magickaPercent = 0,        -- Magicka percentage threshold
        staminaCheck = false,      -- If Stamina check is used
        staminaBlock = false,      -- Block when stamina below threshold (true=block, false=allow only)
        staminaPercent = 0,        -- Stamina percentage threshold
    }
    
    -- d(string.format(
    --     OWColoredName .. ' |cFFFFFFAdded to Resource Block List: |c00FF00%d|r|cFFFFFF - %s (configure resource checks in settings then "/reloadui")|r', 
    --     abilityId, 
    --     abilityName
    -- ))
    ZO_Dialogs_ShowDialog("OW_RELOAD_DIALOG")
end

-- =============================================================================
-- == ABILITY ID DISPLAY HOOKS =================================================
-- =============================================================================
--[[
    Lib only for PC, LibCustomMenu doesnt exist official for console 
    Purpose:  Provides right-click context menu on action bar and assignable skill
              slots to display the underlying ability ID for debugging and configuration.
--]]
local function OnShowMenu(control)
    if control and control._customMenuData then
        local data = control._customMenuData
        control._customMenuData = nil 

        local abilityId = data.abilityId
        local abilityName = data.abilityName

        -- Submenu items
        local entries = {
            {
                label = "Show Ability ID",
                callback = function()
                    d(string.format(
                        OWColoredName .. ' |cFFFFFFAbility ID: |c00FF00%d|r|cFFFFFF - %s|r',
                        abilityId,
                        abilityName
                    ))
                end
            },
            {
                label = "Add to Block List",
                callback = function()
                    AddToBlockList(abilityId, abilityName)
                end
            },
            {
                label = "Add to Recast Block List",
                callback = function()
                    AddToRecastBlockList(abilityId, abilityName)
                end
            },
            {
                label = "Add to Resource Block List",
                callback = function()
                    AddToResourceBlockList(abilityId, abilityName)
                end
            }
        }

        AddCustomSubMenuItem(OWColoredName, entries)
    end
end

ZO_PreHook("ShowMenu", OnShowMenu)


local function HookActionBarRightClick()
    ZO_PreHook("ZO_AbilitySlot_OnSlotClicked", function(abilitySlot, buttonId)
        if buttonId == MOUSE_BUTTON_INDEX_RIGHT then
            local button = ZO_ActionBar_GetButton(abilitySlot.slotNum)
            if button then
                local slotNum = button:GetSlot()
                if GetSlotType(slotNum) == ACTION_TYPE_ABILITY and
                   IsSlotUsed(slotNum) and
                   not IsSlotLocked(slotNum) then

                    local abilityId = GetSlotBoundId(slotNum)
                    local abilityName = zo_strformat("<<1>>", GetAbilityName(abilityId))

                    --  Set the flag for the ShowMenu hook
                    abilitySlot._customMenuData = {
                        abilityId = abilityId,
                        abilityName = abilityName
                    }
                end
            end
        end
        return false
    end)
end


local function HookAssignableSkillsMenu()
    ZO_PreHook(ZO_KeyboardAssignableActionBarButton, "ShowActionMenu", function(self)
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetCurrentHotbar()
        local slotData = hotbar:GetSlotData(self.slotId)

        if slotData and not slotData:IsEmpty() then
            local abilityId = GetSlotBoundId(self.slotId)
            local abilityName = zo_strformat("<<1>>", GetAbilityName(abilityId))

            -- Set the flag for the ShowMenu hook
            self.button._customMenuData = {
                abilityId = abilityId,
                abilityName = abilityName
            }
        end
        return false
    end)
end

-- =============================================================================
-- == SKILLS WINDOW (KEY K) RIGHT-CLICK HOOK ===================================
-- =============================================================================
--[[
    Purpose: Allows you to right-click on any skill in the Skills window
             to display the same context menu as in the action bar.
--]]

local function HookSkillsWindow()
    local function HookAbilitySlotMouseUp(abilityControl)
        local slotControl = abilityControl:GetNamedChild("Slot")
        if not slotControl or slotControl._owSkillsHooked then
            return
        end
        slotControl._owSkillsHooked = true

        ZO_PreHookHandler(slotControl, "OnMouseUp", function(control, button, upInside)
            if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
                local abilityId = control.abilityId
                    or (abilityControl.skillProgressionData and abilityControl.skillProgressionData:GetAbilityId())

                if abilityId and abilityId ~= 0 then
                    local abilityName = zo_strformat("<<1>>", GetAbilityName(abilityId))
                    control._customMenuData = {
                        abilityId = abilityId,
                        abilityName = abilityName,
                    }
                end
            end
            return false
        end)
    end

    ZO_PreHook("ZO_Skills_AbilityEntry_Setup", function(abilityControl, skillData)
        HookAbilitySlotMouseUp(abilityControl)
        return false
    end)
end


local function SetupAbilityIDHooks()
    HookActionBarRightClick()
    HookAssignableSkillsMenu()
    HookSkillsWindow()
end

-- =============================================================================
-- == ADDON INITIALIZATION =====================================================
-- =============================================================================
--[[
    Purpose: Addon initialize
--]]
local function Initialize()

    -- Load persistent settings
    if OptimalWeaveSV and (OptimalWeaveSV["Default"]) then -- For Beartram: Yeah, yeah, I'll build a proper migration sooner or later,
    --but just for now it works for new user. But I didn't want to make a hard cut for people who already have the addon installed
    -- And no, I didn't start out by memorizing best practices, at first, I just copied what I saw in other addons
    -- And I was hoping they'd get it right. Well, I guess not, but you learn from your mistakes, and in my other addons,
    -- it's already implemented the way it should be, just not here yet. :)
    -- Learned by doing even white mistakes. But thanks for the reviewing :D
        OW.accSV = ZO_SavedVars:NewAccountWide("OptimalWeaveSV", 1, nil, defaults)
    else
        OW.accSV = ZO_SavedVars:NewAccountWide("OptimalWeaveSV", 1, nil, defaults, GetWorldName())
    end

    OW.charSV = ZO_SavedVars:NewCharacterIdSettings("OptimalWeaveSV", 1, nil, defaults, GetWorldName())

    -- Read mode from SV
    local mode = OW.accSV.modeSelection  -- "accountwide" or "character"

    -- Identify active containers
    OW.sv = (mode == "accountwide") and OW.accSV or OW.charSV

    OW.TEMP_SPELL_ID = OW.TEMP_SPELL_ID or ""
    OW.TEMP_RECAST_SPELL_ID = OW.TEMP_RECAST_SPELL_ID or ""
    OW.TEMP_RESOURCE_SPELL_ID = OW.TEMP_RESOURCE_SPELL_ID or ""

    SetupAbilityIDHooks()

    -- =============================================================================
    -- == EVENT MANAGER INITIALIZATION =============================================
    -- =============================================================================
    -- Reset tracking
	EM:RegisterForEvent(NAME.."_BARSWAP", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ResetGCDOnBarswap) 
    EM:AddFilterForEvent(NAME .. "_BARSWAP", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME.."_SWIMMING", EVENT_PLAYER_SWIMMING, ResetGCD)
    EM:RegisterForEvent(NAME.."_DEAD", EVENT_PLAYER_DEAD, ResetGCD)

    EM:RegisterForEvent(NAME .."_BLOCK", EVENT_COMBAT_EVENT, CastCanceled)
    EM:AddFilterForEvent(NAME .. "_BLOCK", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME.."_DODGE", EVENT_COMBAT_EVENT, ResetGCDOnDodge)
    EM:AddFilterForEvent(NAME.. "_DODGE", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EM:AddFilterForEvent(NAME.. "_DODGE", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 28549) -- https://esoitem.uesp.net/viewSkillCoef.php

    -- Combat state tracking
    EM:RegisterForEvent(NAME .. "_INTERRUPT", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_INTERRUPT", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_INTERRUPT)
    EM:AddFilterForEvent(NAME .. "_INTERRUPT", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_STUNNED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_STUNNED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_STUNNED)
    EM:AddFilterForEvent(NAME .. "_STUNNED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_FEARED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_FEARED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_FEARED)
    EM:AddFilterForEvent(NAME .. "_FEARED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_SILENCED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_SILENCED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_SILENCED)
    EM:AddFilterForEvent(NAME .. "_SILENCED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_KNOCKBACK", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_KNOCKBACK", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KNOCKBACK)
    EM:AddFilterForEvent(NAME .. "_KNOCKBACK", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_OFFBALANCE", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_OFFBALANCE", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_OFFBALANCE)
    EM:AddFilterForEvent(NAME .. "_OFFBALANCE", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_CHARMED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_CHARMED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_CHARMED)
    EM:AddFilterForEvent(NAME .. "_CHARMED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_DISORIENTED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_DISORIENTED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DISORIENTED)
    EM:AddFilterForEvent(NAME .. "_DISORIENTED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_STAGGERED", EVENT_COMBAT_EVENT, OnPlayerStunned)
    EM:AddFilterForEvent(NAME .. "_STAGGERED", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_STAGGERED)
    EM:AddFilterForEvent(NAME .. "_STAGGERED", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EM:RegisterForEvent(NAME .. "_SPRINTING", EVENT_COMBAT_EVENT, ResetGCD)
    EM:AddFilterForEvent(NAME .. "_SPRINTING", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_SPRINTING)
    EM:AddFilterForEvent(NAME .. "_SPRINTING", EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    
    EM:RegisterForEvent(NAME.."_SLOTUPDATE", EVENT_ACTION_SLOTS_FULL_UPDATE, UpdateGcdTrackingSlot)

    EM:RegisterForEvent(NAME.."_CHECKROLE", EVENT_PLAYER_ACTIVATED, CheckRoleOverride)

    EM:RegisterForEvent(NAME.."_ZONECHANGE", EVENT_PLAYER_ACTIVATED, PvpWorldCheck) -- for whatever reason, EVENT_ZONE_UPDATE does not change immediately

    if OW.sv.blockLastMenu or OW.sv.blockCharMenu then
        EM:RegisterForEvent(NAME.."_COMBATMENUBLOCK", EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)
    end
        
    if OW.sv.autoEquipWeapons then
        EM:RegisterForEvent(NAME .. "_EquipCombat", EVENT_PLAYER_COMBAT_STATE, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipBook", EVENT_HIDE_BOOK, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipCrafting", EVENT_END_CRAFTING_STATION_INTERACT, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipChat", EVENT_CHATTER_END, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipStore", EVENT_CLOSE_STORE, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipAlive", EVENT_PLAYER_ALIVE, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipLoot", EVENT_LOOT_CLOSED, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipActivated", EVENT_PLAYER_ACTIVATED, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipSwimming", EVENT_PLAYER_NOT_SWIMMING, EquipWeaponsStateChange)
        EM:RegisterForEvent(NAME .. "_EquipInteraction", EVENT_INTERACTION_ENDED, EquipWeaponsStateChange)
    end    

-- local function test(eventCode, result, isError, abilityName, abilityGraphic,
--                     abilityActionSlotType, sourceName, sourceType, targetName,
--                     targetType, hitValue, powerType, damageType, log,
--                     sourceUnitId, targetUnitId, abilityId, overflow)

--     if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then
--         return
--     end

--     local slotTypeNames = {
--         [ACTION_SLOT_TYPE_NORMAL_ABILITY] = "NORMAL_ABILITY",
--         [ACTION_SLOT_TYPE_WEAPON_ATTACK]  = "WEAPON_ATTACK",
--         [ACTION_SLOT_TYPE_ULTIMATE]       = "ULTIMATE",
--         [ACTION_SLOT_TYPE_OTHER]          = "OTHER",
--         [ACTION_SLOT_TYPE_BLOCK]          = "BLOCK",
--         [ACTION_SLOT_TYPE_LIGHT_ATTACK]   = "LIGHT_ATTACK",
--         [ACTION_SLOT_TYPE_HEAVY_ATTACK]   = "HEAVY_ATTACK",
--     }

--     local typeName = slotTypeNames[abilityActionSlotType] or "UNKNOWN"
--     d(string.format("ActionSlotType: %d (%s) | Ability: %s (ID: %d)",
--         abilityActionSlotType, typeName, abilityName or "?", abilityId or 0))
-- end
    -- Action system integration
    EM:RegisterForEvent(NAME, EVENT_ACTION_SLOT_ABILITY_USED, AbilityUsed)
    EM:AddFilterForEvent(NAME, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    -- EM:RegisterForEvent(NAME .. "Test", EVENT_COMBAT_EVENT, test)
    -- EM:AddFilterForEvent(NAME .. "Test", EVENT_COMBAT_EVENT,
    -- REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    
    -- =============================================================================
    -- == PRE HOOKS INITIALIZATION =================================================
    -- =============================================================================
    -- PreHook for ActionSlot
    ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
        local slot = GetActionSlot() 
        return ShouldBlockSlot(slot)
    end)

    if OW.sv.blockLastMenu then
        -- PreHook for the Last menu (ALT)
        ZO_PreHook(MAIN_MENU_KEYBOARD, "ShowLastCategory", function()
            if inCombatMenuBlockActive and OW.sv.blockLastMenu then
                SCENE_MANAGER:ShowBaseScene() 
                return true 
            end
        end)
    end    

    if OW.sv.blockCharMenu then
        -- PreHook for the Character menu block (c)
        ZO_PreHook(MAIN_MENU_KEYBOARD, "ToggleCategory", function(_, category)
            if inCombatMenuBlockActive and OW.sv.blockCharMenu and category == MENU_CATEGORY_CHARACTER then
                SCENE_MANAGER:ShowBaseScene()
                return true
            end
        end)
    end

    -- Menu system initialization
    OW.BuildMenu(OW.sv, defaults)
end

-- =============================================================================
-- == EVENT REGISTRATION =======================================================
-- =============================================================================
EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == NAME then
        EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end)

-- =============================================================================
-- === END OF OPTIMALWEAVE CORE ================================================
-- =============================================================================