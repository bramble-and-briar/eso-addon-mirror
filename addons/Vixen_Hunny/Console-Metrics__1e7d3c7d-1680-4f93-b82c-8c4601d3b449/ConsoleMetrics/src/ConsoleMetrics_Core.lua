ADDON_NAME = "ConsoleMetrics"

ConsoleMetrics = {
    name = ADDON_NAME,
    version = "0.1.0",
    defaults = {
        x = 220,
        y = 180,
        scale = 1,
        locked = false,
        showOutOfCombat = true,
        scrollSize = 8,
        autoClearOnNextFight = true,
        maxFightHistory = 25,
        performanceMode = false,
        lowMemoryMode = true,
        uiPanelEnabled = false,
        dialogAutoHide = true,
        dialogAutoHideSeconds = 12,
        closeOnMove = false,
        debugEnabled = false,
        debugIntervalSeconds = 5,
        drSampleAlpha = 0.35,
        ioTraceEnabled = false,
        ioTraceMode = "summary",
        ioTraceTargetMode = "off",
        ioTraceTargetName = "",
        ioTraceTargetOnlyProcessing = false,
        ioTraceSkipResourceSampling = false,
        ioTraceTargetGraceMs = 1500,
        ioTraceMaxLinesPerSecond = 40,
        ioTraceMinValue = 0,
        ioTraceSummarySeconds = 1,
        behaviorModelEnabled = false,
        behaviorModelRefreshMs = 1500,
        customSetRules = {},
        customSetDraftLabel = "",
        customSetDraftScene = "PvP",
        customSetDraftAbilityId = "",
        customSetDraftAbilityName = "",
        saveFightDraftName = "",
        loadFightDraftName = "",
        savedFights = {},
        maxSavedFights = 10,
    },
    ui = {},
    scrollEntries = {},
    inCombat = false,
    hideAtMs = nil,
    dialogAutoHideAtMs = nil,
    dialogRefreshAtMs = nil,
    lastDebugPrintAtMs = nil,
    fight = nil,
    fightHistory = {},
    viewFightIndex = 0,
    dialogPanel = "main",
    lastMetricsUpdateMs = 0,
    lastScrollUpdateMs = 0,
    lastProtectionUpdateMs = 0,
    lastSortedSkillList = {},
    lastSortedHealList = {},
    lastSkillMapSize = 0,
    trackedSetMatchById = {},
    trackedSetMatchByName = {},
    lastScrollLineAtMs = 0,
    lastEffectStateEventMs = 0,
    lastTraceTargetMatchMs = nil,
    ioTraceState = nil,
    behaviorModelCache = nil,
    skillListDirty = true,
}

local POST_COMBAT_VISIBLE_MS = 10000
local DIALOG_LIVE_REFRESH_MS = 500
local METRICS_UPDATE_THROTTLE_MS = 250
local SCROLL_UPDATE_THROTTLE_MS = 200
local PROTECTION_UPDATE_THROTTLE_MS = 500
local COMBAT_SCROLL_EVENT_THROTTLE_MS = 75
local EFFECT_STATE_EVENT_THROTTLE_MS = 25
local RESISTANCE_CAP = 33000
local RESISTANCE_SCALE = 66000
local TOP_MOMENTS_LIMIT = 30
local MAJOR_PROTECTION_DR_PCT = 10
local MINOR_PROTECTION_DR_PCT = 5
local EFFECTS_PANEL_LIMIT = 30
local THROUGHPUT_WINDOW_INTERVAL_MS = 1000
local RESOURCE_SAMPLE_INTERVAL_MS = 1000
local RESOURCE_SAMPLE_MAX_POINTS = 1200
local OBSERVED_ABILITY_LOG_MAX = 2048
local MAX_FIGHT_HISTORY_HARD_CAP = 40
local LOW_MEMORY_LIST_LIMIT = 20
local LOW_MEMORY_MOMENTS_LIMIT = 12
local LOW_MEMORY_EFFECT_LIMIT = 20
local PING_DIP_DELTA_MS = 25
local PING_SPIKE_DELTA_MS = 40
local PING_HIGH_DELAY_MS = 140

-- Lazily resolved at first sample so all game constants are guaranteed bound.
-- Console uses COMBAT_MECHANIC_FLAGS_* (health=1, magicka=2, stamina=4).
local RESOURCE_POWER_TYPES_CACHE = nil
local UNIT_NAME_CACHE = {}
local UNIT_NAME_CACHE_SIZE = 0
local UNIT_NAME_CACHE_MAX = 512
local LIKELY_SET_PROC_CACHE = {}
local LIKELY_SET_PROC_CACHE_SIZE = 0
local LIKELY_SET_PROC_CACHE_MAX = 512

local function GetResourcePowerTypes()
    if RESOURCE_POWER_TYPES_CACHE then
        return RESOURCE_POWER_TYPES_CACHE
    end

    local g = type(_G) == "table" and _G or nil

    local function Resolve(consoleKey, consoleDefault)
        local consVal = g and tonumber(g[consoleKey]) or nil
        if consVal then
            return { consVal }
        end
        -- Hardcoded console fallback in case the constant resolves late.
        return { consoleDefault }
    end

    RESOURCE_POWER_TYPES_CACHE = {
        health   = Resolve("COMBAT_MECHANIC_FLAGS_HEALTH",   1),
        magicka  = Resolve("COMBAT_MECHANIC_FLAGS_MAGICKA",  2),
        stamina  = Resolve("COMBAT_MECHANIC_FLAGS_STAMINA",  4),
        ultimate = Resolve("COMBAT_MECHANIC_FLAGS_ULTIMATE", 8),
    }

    return RESOURCE_POWER_TYPES_CACHE
end

local ROLE_COMPARISON_PROFILES = {
    dps = {
        label = "DPS",
        health = { 18000, 36000 },
        primary = { 28000, 42000 },
        secondary = { 12000, 24000 },
        crit = { 55, 70 },
        healthNote = "Above range is usually too defensive for a standard DPS profile.",
        primaryNote = "Above range can indicate overinvestment versus damage/crit/pen.",
        secondaryNote = "Very high secondary pools often have weak marginal return for DPS.",
        critNote = "Above this, crit damage/pen or raw power may be better value.",
    },
    healer = {
        label = "Healer",
        health = { 22000, 40000 },
        primary = { 30000, 50000 },
        secondary = { 12000, 28000 },
        crit = { 35, 60 },
        healthNote = "Too much health can reduce healing throughput or sustain efficiency.",
        primaryNote = "Primary pool is typically Magicka for healer throughput and sustain.",
        secondaryNote = "Secondary pool supports utility, blocking, and break free management.",
        critNote = "Healer crit goals vary by set and content; treat this as a practical band.",
    },
    tank = {
        label = "Tank",
        health = { 32000, 55000 },
        primary = { 22000, 38000 },
        secondary = { 16000, 32000 },
        crit = { 10, 35 },
        healthNote = "High health is expected, but extreme values can overtrade group utility.",
        primaryNote = "Primary pool should support taunt uptime, blocking, and core skill loops.",
        secondaryNote = "Secondary pool helps with swap pressure and emergency sustain windows.",
        critNote = "Tank crit is usually lower priority than resist, sustain, and utility.",
    },
}

local function MapRoleValueToProfileKey(roleValue)
    if type(roleValue) == "string" then
        local lower = string.lower(roleValue)
        if string.find(lower, "tank", 1, true) ~= nil then
            return "tank"
        end
        if string.find(lower, "heal", 1, true) ~= nil then
            return "healer"
        end
        if string.find(lower, "dps", 1, true) ~= nil or string.find(lower, "damage", 1, true) ~= nil then
            return "dps"
        end
        return nil
    end

    if type(roleValue) ~= "number" then
        return nil
    end

    if type(LFG_ROLE_TANK) == "number" and roleValue == LFG_ROLE_TANK then
        return "tank"
    end
    if type(LFG_ROLE_HEAL) == "number" and roleValue == LFG_ROLE_HEAL then
        return "healer"
    end
    if type(LFG_ROLE_DPS) == "number" and roleValue == LFG_ROLE_DPS then
        return "dps"
    end

    if roleValue == 1 then
        return "tank"
    end
    if roleValue == 2 then
        return "healer"
    end
    if roleValue == 3 then
        return "dps"
    end

    return nil
end

local function GetSelectedRoleComparisonProfile()
    local probes = {
        {
            source = "group selected role",
            getValue = function()
                if type(GetGroupMemberSelectedRole) == "function" then
                    return GetGroupMemberSelectedRole("player")
                end
                return nil
            end,
        },
        {
            source = "LFG selected role",
            getValue = function()
                if type(GetSelectedLFGRole) == "function" then
                    return GetSelectedLFGRole()
                end
                return nil
            end,
        },
        {
            source = "unit group role",
            getValue = function()
                if type(GetUnitGroupRole) == "function" then
                    return GetUnitGroupRole("player")
                end
                return nil
            end,
        },
    }

    for i = 1, #probes do
        local roleValue = probes[i].getValue()
        local roleKey = MapRoleValueToProfileKey(roleValue)
        if roleKey and ROLE_COMPARISON_PROFILES[roleKey] then
            return roleKey, ROLE_COMPARISON_PROFILES[roleKey], string.format("Using %s.", probes[i].source)
        end
    end

    return "dps", ROLE_COMPARISON_PROFILES.dps, "Selected role unavailable; using DPS defaults."
end

local function ColorFromHex(hex)
    local clean = (hex or "FFFFFF"):gsub("#", "")
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    return { r / 255, g / 255, b / 255 }
end

local function SafeAbilityId(abilityId)
    return math.floor(tonumber(abilityId) or 0)
end

local function FormatAbilityIdentity(abilityName, abilityId)
    return string.format("%s [id:%d]", abilityName or "Unknown", SafeAbilityId(abilityId))
end

local COMBAT_TEXT_COLORS = {
    start = ColorFromHex("#FF7314"),
    summary = ColorFromHex("#FFB04D"),
    damage = ColorFromHex("#FF7D29"),
    damageCrit = ColorFromHex("#FFCC61"),
    heal = ColorFromHex("#3DE378"),
    healCrit = ColorFromHex("#73FF8C"),
    taken = ColorFromHex("#FF4242"),
}

-- Hex strings (no# prefix) for |cHHHHHH...|r ESO color markup in panel labels.
local COMBAT_COLOR_HEX = {
    start      = "FF7314",  -- amber: combat start
    summary    = "FFB04D",  -- gold: summaries
    damage     = "FF7D29",  -- orange: direct damage
    damageCrit = "FFCC61",  -- yellow: critical damage
    dot        = "FF982A",  -- deep orange: damage-over-time ticks
    heal       = "3DE378",  -- green: direct healing
    healCrit   = "73FF8C",  -- bright green: critical healing
    hot        = "52EAA8",  -- teal: heal-over-time ticks
    taken      = "FF4242",  -- red: incoming damage
    shield     = "7BB2FF",  -- blue: absorb/shield
    overflow   = "FF6060",  -- light red: overflow damage/heal
    mitigation = "A0C8FF",  -- sky blue: blocked/shielded mitigation
}

local METRIC_ROW_COLORS = {
    dps = COMBAT_TEXT_COLORS.damage,
    hps = COMBAT_TEXT_COLORS.heal,
    damage = COMBAT_TEXT_COLORS.damage,
    heal = COMBAT_TEXT_COLORS.heal,
    taken = COMBAT_TEXT_COLORS.taken,
    crit = COMBAT_TEXT_COLORS.damageCrit,
}

-- Curated set aliases used to classify common PvE/PvP proc names in combat events.
local POPULAR_SET_CATALOG = {
    { label = "Pillar of Nirn", scene = "PvE", aliases = { "pillar of nirn", "nirn" } },
    { label = "Whorl of the Depths", scene = "PvE", aliases = { "whorl of the depths", "whorl" } },
    { label = "Arms of Relequen", scene = "PvE", aliases = { "arms of relequen", "relequen" } },
    { label = "Aegis Caller", scene = "PvE", aliases = { "aegis caller", "aegis" } },
    { label = "Mantle of Siroria", scene = "PvE", aliases = { "mantle of siroria", "siroria" } },
    { label = "Zaan", scene = "PvE", aliases = { "zaan" } },
    { label = "Coral Riptide", scene = "PvE", aliases = { "coral riptide", "riptide" } },
    { label = "Kinras's Wrath", scene = "PvE", aliases = { "kinras", "kinras's wrath" } },
    { label = "Bahsei's Mania", scene = "PvE", aliases = { "bahsei", "bahsei's mania" } },
    { label = "Azureblight Reaper", scene = "PvE", aliases = { "azureblight", "azureblight reaper" } },
    { label = "Rallying Cry", scene = "PvP", aliases = { "rallying cry", "rallying" } },
    { label = "Mara's Balm", scene = "PvP", aliases = { "mara's balm", "maras balm" } },
    { label = "Daedric Trickery", scene = "PvP", aliases = { "daedric trickery", "trickery" } },
    { label = "Plaguebreak", scene = "PvP", aliases = { "plaguebreak" } },
    { label = "Vicious Death", scene = "PvP", aliases = { "vicious death" } },
    { label = "Dark Convergence", scene = "PvP", aliases = { "dark convergence", "convergence" } },
    { label = "Wretched Vitality", scene = "PvP", aliases = { "wretched vitality", "wretched" } },
    { label = "Mark of the Pariah", scene = "PvP", aliases = { "pariah", "mark of the pariah" } },
    { label = "Hrothgar's Chill", scene = "PvP", aliases = { "hrothgar", "hrothgar's chill" } },
    { label = "Balorgh", scene = "PvP", aliases = { "balorgh" } },
}

-- Heuristic keywords to surface likely set procs beyond the curated catalog.
local LIKELY_SET_PROC_KEYWORDS = {
    "set",
    "proc",
    "nirn",
    "relequen",
    "siroria",
    "balorgh",
    "pariah",
    "hrothgar",
    "trickery",
    "vitality",
    "convergence",
    "plague",
    "semblance",
    "opportunist",
    "slayer",
    "whisper",
    "ward",
}

local function NumberText(value)
    return ZO_CommaDelimitNumber(math.floor(value + 0.5))
end

local function ShortNumber(value)
    if value >= 1000000 then
        return string.format("%.2fm", value / 1000000)
    end
    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

-- Wrap a formatted number in ESO color markup: |cHHHHHH<number>|r
local function ColorNum(value, colorHex)
    return string.format("|c%s%s|r", colorHex or "FFFFFF", NumberText(value))
end

local function ColorShort(value, colorHex)
    return string.format("|c%s%s|r", colorHex or "FFFFFF", ShortNumber(value))
end

local function ColorText(text, colorHex)
    return string.format("|c%s%s|r", colorHex or "FFFFFF", tostring(text or ""))
end

local function TrimText(text)
    local value = tostring(text or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function BuildDefaultFightSaveName(snapshot, slotIndex)
    local topTarget = snapshot and snapshot.targetList and snapshot.targetList[1] or nil
    local targetTag = topTarget and topTarget.name and topTarget.name ~= "" and (" vs " .. topTarget.name) or ""
    return string.format("Slot %d: %.1fs / %s DPS%s", slotIndex or 1, snapshot and snapshot.duration or 0, ShortNumber((snapshot and snapshot.dps) or 0), targetTag)
end

local function GetActionBarSlotBounds()
    -- Console client confirmed layout: skills occupy slots 3-7 and ultimate is slot 8.
    return 3, 8
end

local function SafeGetActionBarSlotName(slotIndex, hotbarCategory)
    local slotName = nil
    if type(GetSlotName) == "function" then
        local ok = pcall(function()
            if hotbarCategory ~= nil then
                slotName = GetSlotName(slotIndex, hotbarCategory)
            else
                slotName = GetSlotName(slotIndex)
            end
        end)
        if ok and type(slotName) == "string" and slotName ~= "" then
            -- Filter out non-skill action slots using pattern matching
            local lowerName = string.lower(slotName)
            if string.match(lowerName, "heavy%s*attack")
            or string.match(lowerName, "light%s*attack")
            or string.match(lowerName, "^dodge")
            or lowerName == "block"
            or lowerName == "bash" then
                return nil, nil
            end
            return slotName
        end
    end

    if type(GetSlotBoundId) == "function" and type(GetAbilityName) == "function" then
        local abilityId = nil
        local ok = pcall(function()
            if hotbarCategory ~= nil then
                abilityId = GetSlotBoundId(slotIndex, hotbarCategory)
            else
                abilityId = GetSlotBoundId(slotIndex)
            end
        end)
        if ok and type(abilityId) == "number" and abilityId > 0 then
            local okName, abilityName = pcall(GetAbilityName, abilityId)
            if okName and type(abilityName) == "string" and abilityName ~= "" then
                return abilityName, abilityId
            end
            return string.format("Ability %d", abilityId), abilityId
        end
    end

    return nil, nil
end

local function BuildActionBarSnapshot(hotbarCategory)
    local entries = {}
    local firstSlot, ultimateSlot = GetActionBarSlotBounds()
    local skillCount = 0
    for slotIndex = firstSlot, ultimateSlot do
        local abilityName, abilityId = SafeGetActionBarSlotName(slotIndex, hotbarCategory)
        if abilityName then  -- Skip filtered slots (Heavy Attack, Dodge)
            local slotLabel = slotIndex == ultimateSlot and "Ultimate" or string.format("Skill %d", skillCount + 1)
            entries[#entries + 1] = {
                slotLabel = slotLabel,
                abilityName = abilityName or "Empty",
                abilityId = abilityId or 0,
            }
            if slotIndex ~= ultimateSlot then
                skillCount = skillCount + 1
            end
        end
    end
    return entries
end

local function BuildEquipmentSlotDefinitions()
    local slots = {}
    local function Add(label, slotValue)
        if type(slotValue) == "number" then
            slots[#slots + 1] = { label = label, slot = slotValue }
        end
    end

    Add("Head", EQUIP_SLOT_HEAD)
    Add("Shoulders", EQUIP_SLOT_SHOULDERS)
    Add("Chest", EQUIP_SLOT_CHEST)
    Add("Hands", EQUIP_SLOT_HAND)
    Add("Waist", EQUIP_SLOT_WAIST)
    Add("Legs", EQUIP_SLOT_LEGS)
    Add("Feet", EQUIP_SLOT_FEET)
    Add("Neck", EQUIP_SLOT_NECK)
    Add("Ring 1", EQUIP_SLOT_RING1)
    Add("Ring 2", EQUIP_SLOT_RING2)
    Add("Main Hand", EQUIP_SLOT_MAIN_HAND)
    Add("Off Hand", EQUIP_SLOT_OFF_HAND)
    Add("Backup Main", EQUIP_SLOT_BACKUP_MAIN)
    Add("Backup Off", EQUIP_SLOT_BACKUP_OFF)

    return slots
end

local function SafeGetEquippedItemText(slotIndex)
    if type(BAG_WORN) ~= "number" then
        return "Unavailable"
    end

    local itemLink = nil
    local itemName = nil
    if type(GetItemLink) == "function" then
        local ok = pcall(function()
            local linkStyle = type(LINK_STYLE_BRACKETS) == "number" and LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT
            itemLink = GetItemLink(BAG_WORN, slotIndex, linkStyle)
        end)
        if not ok then
            itemLink = nil
        end
    end
    if type(GetItemName) == "function" then
        local ok = pcall(function()
            itemName = GetItemName(BAG_WORN, slotIndex)
        end)
        if not ok then
            itemName = nil
        end
    end

    if type(itemLink) == "string" and itemLink ~= "" and itemLink ~= "|H0:item:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" then
        return itemLink
    end
    if type(itemName) == "string" and itemName ~= "" then
        return itemName
    end
    return "Empty"
end

local function BuildEquipmentSnapshot()
    local entries = {}
    local slots = BuildEquipmentSlotDefinitions()
    for i = 1, #slots do
        entries[#entries + 1] = {
            label = slots[i].label,
            text = SafeGetEquippedItemText(slots[i].slot),
        }
    end
    return entries
end

local function BuildActiveBoonSnapshot()
    local boons = {}
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return boons
    end

    local ok, buffCount = pcall(GetNumBuffs, "player")
    if not ok or type(buffCount) ~= "number" then
        return boons
    end

    for buffIndex = 1, buffCount do
        local buffName = nil
        local okBuff = pcall(function()
            buffName = GetUnitBuffInfo("player", buffIndex)
        end)
        if okBuff and type(buffName) == "string" and buffName ~= "" then
            local lowerName = string.lower(buffName)
            if string.find(lowerName, "boon", 1, true) ~= nil or string.find(lowerName, "mundus", 1, true) ~= nil then
                boons[#boons + 1] = buffName
            end
        end
    end

    return boons
end

local function SafeCallResults(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local results = nil
    local ok = pcall(function(...)
        results = { func(...) }
    end, ...)

    if not ok then
        return nil
    end

    return results
end

local function FindFirstNonEmptyString(results, skipValues)
    if type(results) ~= "table" then
        return nil
    end

    for i = 1, #results do
        local value = results[i]
        if type(value) == "string" and value ~= "" then
            if not skipValues or not skipValues[value] then
                return value
            end
        end
    end

    return nil
end

local function BuildEquippedSetSummary()
    local results = {}
    local seen = {}
    local slots = BuildEquipmentSlotDefinitions()

    if type(GetItemLink) ~= "function" or type(GetItemLinkSetInfo) ~= "function" or type(BAG_WORN) ~= "number" then
        return results
    end

    for i = 1, #slots do
        local slotInfo = slots[i]
        local itemLink = nil
        local okLink = pcall(function()
            local linkStyle = type(LINK_STYLE_BRACKETS) == "number" and LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT
            itemLink = GetItemLink(BAG_WORN, slotInfo.slot, linkStyle)
        end)

        if okLink and type(itemLink) == "string" and itemLink ~= "" then
            local setResults = SafeCallResults(GetItemLinkSetInfo, itemLink)
            local hasSet = setResults and setResults[1]
            local setName = setResults and setResults[2]
            local numEquipped = tonumber(setResults and setResults[4]) or 0
            local maxEquipped = tonumber(setResults and setResults[5]) or 0

            if hasSet and type(setName) == "string" and setName ~= "" then
                local lowerName = string.lower(setName)
                local entry = seen[lowerName]
                if not entry then
                    entry = {
                        setName = setName,
                        numEquipped = numEquipped,
                        maxEquipped = maxEquipped,
                        slots = {},
                    }
                    seen[lowerName] = entry
                    results[#results + 1] = entry
                end

                entry.slots[#entry.slots + 1] = slotInfo.label
                entry.numEquipped = math.max(entry.numEquipped or 0, numEquipped)
                entry.maxEquipped = math.max(entry.maxEquipped or 0, maxEquipped)
            end
        end
    end

    table.sort(results, function(a, b)
        if (a.numEquipped or 0) == (b.numEquipped or 0) then
            return tostring(a.setName) < tostring(b.setName)
        end
        return (a.numEquipped or 0) > (b.numEquipped or 0)
    end)

    return results
end

local function BuildWeaponEffectSnapshot()
    local weaponSlots = {
        { label = "Main Hand", slot = type(EQUIP_SLOT_MAIN_HAND) == "number" and EQUIP_SLOT_MAIN_HAND or nil },
        { label = "Off Hand", slot = type(EQUIP_SLOT_OFF_HAND) == "number" and EQUIP_SLOT_OFF_HAND or nil },
        { label = "Backup Main", slot = type(EQUIP_SLOT_BACKUP_MAIN) == "number" and EQUIP_SLOT_BACKUP_MAIN or nil },
        { label = "Backup Off", slot = type(EQUIP_SLOT_BACKUP_OFF) == "number" and EQUIP_SLOT_BACKUP_OFF or nil },
    }

    local entries = {}
    for i = 1, #weaponSlots do
        local slotInfo = weaponSlots[i]
        if type(slotInfo.slot) == "number" then
            local itemText = SafeGetEquippedItemText(slotInfo.slot)
            local enchantText = nil
            local poisonText = nil
            local itemLink = nil

            if type(GetItemLink) == "function" and type(BAG_WORN) == "number" then
                local okLink = pcall(function()
                    local linkStyle = type(LINK_STYLE_BRACKETS) == "number" and LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT
                    itemLink = GetItemLink(BAG_WORN, slotInfo.slot, linkStyle)
                end)
                if not okLink then
                    itemLink = nil
                end
            end

            if type(itemLink) == "string" and itemLink ~= "" then
                local skipValues = {}
                skipValues[itemText] = true
                local enchantResults = SafeCallResults(GetItemLinkWeaponEnchantInfo, itemLink)
                enchantText = FindFirstNonEmptyString(enchantResults, skipValues)
                if not enchantText then
                    enchantResults = SafeCallResults(GetItemLinkEnchantInfo, itemLink)
                    enchantText = FindFirstNonEmptyString(enchantResults, skipValues)
                end

                local poisonResults = SafeCallResults(GetItemPoisonInfo, BAG_WORN, slotInfo.slot)
                poisonText = FindFirstNonEmptyString(poisonResults, skipValues)
                if not poisonText then
                    poisonResults = SafeCallResults(GetItemLinkOnUseAbilityInfo, itemLink)
                    poisonText = FindFirstNonEmptyString(poisonResults, skipValues)
                end
            end

            entries[#entries + 1] = {
                label = slotInfo.label,
                itemText = itemText,
                enchantText = enchantText or "Unavailable",
                poisonText = poisonText or "None",
            }
        end
    end

    return entries
end

local function ClassifyChampionDisciplineBucket(disciplineName, disciplineType)
    local lowerName = string.lower(tostring(disciplineName or ""))
    if string.find(lowerName, "war", 1, true) ~= nil then
        return "warfare"
    end
    if string.find(lowerName, "fit", 1, true) ~= nil then
        return "fitness"
    end
    if string.find(lowerName, "craft", 1, true) ~= nil then
        return "craft"
    end

    local combatType = type(CHAMPION_DISCIPLINE_TYPE_COMBAT) == "number" and CHAMPION_DISCIPLINE_TYPE_COMBAT or nil
    local conditioningType = type(CHAMPION_DISCIPLINE_TYPE_CONDITIONING) == "number" and CHAMPION_DISCIPLINE_TYPE_CONDITIONING or nil
    local worldType = type(CHAMPION_DISCIPLINE_TYPE_WORLD) == "number" and CHAMPION_DISCIPLINE_TYPE_WORLD or nil

    if type(disciplineType) == "number" then
        if combatType and disciplineType == combatType then
            return "warfare"
        end
        if conditioningType and disciplineType == conditioningType then
            return "fitness"
        end
        if worldType and disciplineType == worldType then
            return "craft"
        end

        -- Console PTS mapping seen on this client can be rotated compared to legacy assumptions.
        if disciplineType == 1 then
            return "fitness"
        end
        if disciplineType == 2 then
            return "craft"
        end
        if disciplineType == 3 then
            return "warfare"
        end
    end
    return nil
end

local function RemapChampionBucket(bucketKey)
    -- Use current game discipline mapping directly.
    return bucketKey
end

local championUnpack = table.unpack or unpack

local function ChampionFirstNumber(results)
    if type(results) ~= "table" then
        return nil
    end

    for i = 1, #results do
        local value = tonumber(results[i])
        if value ~= nil then
            return value
        end
    end

    return nil
end

local function ChampionFirstPositiveNumber(results)
    if type(results) ~= "table" then
        return nil
    end

    for i = 1, #results do
        local value = tonumber(results[i])
        if value and value > 0 then
            return value
        end
    end

    return nil
end

local function ChampionReadNumberFromFunctionNames(fnNames, ...)
    local g = type(_G) == "table" and _G or nil
    for i = 1, #fnNames do
        local fn = g and g[fnNames[i]]
        if type(fn) == "function" then
            local value = ChampionFirstNumber(SafeCallResults(fn, ...))
            if value ~= nil then
                return value
            end
        end
    end
    return nil
end

local function GetChampionSkillIdSafe(disciplineId, disciplineIndex, disciplineType, skillIndex)
    if skillIndex == nil then
        return nil
    end

    local g = type(_G) == "table" and _G or nil
    local fnNames = {
        "GetChampionSkillId",
        "GetChampionDisciplineSkillId",
        "GetChampionSkillIdByIndex",
        "GetChampionDisciplineSkillIdByIndex",
    }
    local argLists = {
        { disciplineId, skillIndex },
        { disciplineIndex, skillIndex },
    }
    if disciplineType ~= nil then
        argLists[#argLists + 1] = { disciplineType, skillIndex }
    end

    for i = 1, #fnNames do
        local fn = g and g[fnNames[i]]
        if type(fn) == "function" then
            for j = 1, #argLists do
                local skillId = ChampionFirstPositiveNumber(SafeCallResults(fn, championUnpack(argLists[j])))
                if skillId then
                    return skillId
                end
            end
        end
    end

    return nil
end

local function GetChampionAbilityIdSafe(skillId, disciplineId, disciplineIndex, disciplineType, skillIndex)
    if not skillId then
        return nil
    end

    local fnNames = {
        "GetChampionSkillAbilityId",
        "GetAbilityIdForChampionSkill",
        "GetChampionSkillProgressionAbilityId",
    }

    local abilityId = ChampionReadNumberFromFunctionNames(fnNames, skillId)
    if abilityId and abilityId > 0 then
        return abilityId
    end

    local argLists = {
        { disciplineId, skillIndex },
        { disciplineIndex, skillIndex },
    }
    if disciplineType ~= nil then
        argLists[#argLists + 1] = { disciplineType, skillIndex }
    end

    for i = 1, #argLists do
        abilityId = ChampionReadNumberFromFunctionNames(fnNames, championUnpack(argLists[i]))
        if abilityId and abilityId > 0 then
            return abilityId
        end
    end

    return nil
end

local function CollectObservedChampionSlotIds()
    local g = type(_G) == "table" and _G or nil
    local observedIds = {}
    local slotContentFns = {
        "GetChampionSkillSlotSkillId",
        "GetChampionSkillSlotAbilityId",
        "GetChampionSkillSlotId",
        "GetChampionSlottedSkillId",
        "GetChampionSkillInSlot",
        "GetChampionSkillIdInSlot",
        "GetSlottedChampionSkillId",
    }
    local numSlots = ChampionFirstNumber(SafeCallResults(GetNumChampionSkillSlots)) or 12
    if numSlots <= 0 then
        numSlots = 12
    end
    local slotProbeMax = math.max(numSlots, 64)

    for i = 1, #slotContentFns do
        local fn = g and g[slotContentFns[i]]
        if type(fn) == "function" then
            for slotIndex = 1, slotProbeMax do
                local slotId = ChampionFirstPositiveNumber(SafeCallResults(fn, slotIndex))
                if slotId then
                    observedIds[slotId] = true
                end
            end
            for slotIndex = 0, slotProbeMax do
                local slotId = ChampionFirstPositiveNumber(SafeCallResults(fn, slotIndex))
                if slotId then
                    observedIds[slotId] = true
                end
            end
        end
    end

    return observedIds
end

local function IsChampionSkillSlottableSafe(skillId, disciplineId, disciplineIndex, disciplineType, skillIndex, abilityId, observedSlotIds)
    if not skillId then
        return nil
    end

    local g = type(_G) == "table" and _G or nil
    if type(observedSlotIds) == "table" then
        if observedSlotIds[skillId] or (abilityId and observedSlotIds[abilityId]) then
            return true
        end
    end

    local argLists = {
        { skillId },
        { disciplineId, skillIndex },
        { disciplineIndex, skillIndex },
    }
    if disciplineType ~= nil then
        argLists[#argLists + 1] = { disciplineType, skillIndex }
    end
    if abilityId and abilityId > 0 then
        argLists[#argLists + 1] = { abilityId }
    end

    local booleanFns = {
        "IsChampionSkillSlottable",
    }
    local sawBoolean = false
    for i = 1, #booleanFns do
        local fn = g and g[booleanFns[i]]
        if type(fn) == "function" then
            for j = 1, #argLists do
                local results = SafeCallResults(fn, championUnpack(argLists[j]))
                if type(results) == "table" and type(results[1]) == "boolean" then
                    sawBoolean = true
                    if results[1] == true then
                        return true
                    end
                end
            end
        end
    end

    local slottableTypeValues = {}
    local slottableTypeNames = {
        "CHAMPION_SKILL_TYPE_SLOTTABLE",
        "CHAMPION_CONSTELLATION_SKILL_TYPE_SLOTTABLE",
    }
    for i = 1, #slottableTypeNames do
        local typeValue = g and tonumber(g[slottableTypeNames[i]]) or nil
        if typeValue ~= nil then
            slottableTypeValues[typeValue] = true
        end
    end

    if next(slottableTypeValues) ~= nil then
        local sawSkillType = false
        local skillTypeFns = {
            "GetChampionSkillType",
        }
        for i = 1, #skillTypeFns do
            local fn = g and g[skillTypeFns[i]]
            if type(fn) == "function" then
                for j = 1, #argLists do
                    local skillType = ChampionFirstNumber(SafeCallResults(fn, championUnpack(argLists[j])))
                    if skillType ~= nil then
                        sawSkillType = true
                        if slottableTypeValues[skillType] then
                            return true
                        end
                    end
                end
            end
        end
        if sawSkillType then
            return false
        end
    end

    if sawBoolean then
        return false
    end

    return nil
end

function ConsoleMetrics:BuildChampionSlottablesById()
    local cache = {}
    local meta = {
        disciplineCount = 0,
        skillCount = 0,
        slottableCount = 0,
        unknownCount = 0,
    }

    local allSkillStates = {}
    local slotsById = {}

    local g = type(_G) == "table" and _G or nil
    local cdm = g and g.CHAMPION_DATA_MANAGER or nil
    local hotbarCat = g and g.HOTBAR_CATEGORY_CHAMPION or nil

    if cdm == nil or type(cdm.disciplineDatas) ~= "table" then
        self.championSlottablesById = cache
        self.championSlottablesMeta = meta
        self.championAllSkillStates = allSkillStates
        self.championObservedSlotIds = slotsById
        return cache, meta
    end

    if type(GetSlotBoundId) == "function" and hotbarCat ~= nil then
        for slotIndex = 1, 12 do
            local ok, starId = pcall(GetSlotBoundId, slotIndex, hotbarCat)
            if ok and type(starId) == "number" and starId > 0 then
                slotsById[starId] = true
            end
        end
    end

    for _, discipline in pairs(cdm.disciplineDatas) do
        meta.disciplineCount = meta.disciplineCount + 1
        local disciplineId = discipline.disciplineId
        local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
        local disciplineName = (disciplineNameResults and disciplineNameResults[1])
            or string.format("Discipline %d", disciplineId)
        local disciplineType = ChampionFirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
        local bucketKey = RemapChampionBucket(ClassifyChampionDisciplineBucket(disciplineName, disciplineType))

        for _, star in pairs(discipline.championSkillDatas or {}) do
            local starId = star.championSkillId
            if starId then
                meta.skillCount = meta.skillCount + 1

                local starName = string.format("Star %d", starId)
                if type(GetChampionSkillName) == "function" then
                    local ok, name = pcall(GetChampionSkillName, starId)
                    if ok and type(name) == "string" and name ~= "" then
                        starName = name
                    end
                end

                local isSlottable = false
                if type(star.IsTypeSlottable) == "function" then
                    local ok, result = pcall(star.IsTypeSlottable, star)
                    isSlottable = ok and result == true
                end

                local skillState = {
                    skillId = starId,
                    name = starName,
                    disciplineId = disciplineId,
                    disciplineName = disciplineName,
                    bucketKey = bucketKey,
                    disciplineType = disciplineType,
                    abilityId = nil,
                    isSlottable = isSlottable,
                }
                allSkillStates[starId] = skillState

                if isSlottable then
                    cache[starId] = skillState
                    meta.slottableCount = meta.slottableCount + 1
                else
                    meta.unknownCount = meta.unknownCount + 1
                end
            end
        end
    end

    self.championSlottablesById = cache
    self.championSlottablesMeta = meta
    self.championAllSkillStates = allSkillStates
    self.championObservedSlotIds = slotsById
    return cache, meta
end

function ConsoleMetrics:RefreshChampionSlottableCache()
    return self:BuildChampionSlottablesById()
end

function ConsoleMetrics:DumpChampionSlottables()
    local cache, meta = self:RefreshChampionSlottableCache()
    local entries = {}
    for _, entry in pairs(cache or {}) do
        entries[#entries + 1] = entry
    end

    local bucketOrder = {
        warfare = 1,
        fitness = 2,
        craft = 3,
    }

    table.sort(entries, function(a, b)
        local bucketA = bucketOrder[a.bucketKey or ""] or 99
        local bucketB = bucketOrder[b.bucketKey or ""] or 99
        if bucketA ~= bucketB then
            return bucketA < bucketB
        end
        if tostring(a.disciplineName or "") ~= tostring(b.disciplineName or "") then
            return tostring(a.disciplineName or "") < tostring(b.disciplineName or "")
        end
        if tostring(a.name or "") ~= tostring(b.name or "") then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return (a.skillId or 0) < (b.skillId or 0)
    end)

    self:Print(string.format(
        "Champion slottables: %d of %d skills scanned across %d disciplines (unknown=%d).",
        meta.slottableCount or 0,
        meta.skillCount or 0,
        meta.disciplineCount or 0,
        meta.unknownCount or 0
    ))

    local printer = type(d) == "function" and d or function(message)
        self:Print(message)
    end

    local function PrintEntry(entry, tag)
        printer(string.format(
            "|cFF6A00[CM-CP]|r [%s] id=%d abilityId=%s bucket=%s discipline=%s name=%s ability=%s",
            tag,
            entry.skillId or 0,
            tostring(entry.abilityId or 0),
            tostring(entry.bucketKey or "unknown"),
            tostring(entry.disciplineName or "Unknown"),
            tostring(entry.name or string.format("Skill %d", entry.skillId or 0)),
            tostring(entry.abilityName or "n/a")
        ))
    end

    if #entries > 0 then
        for i = 1, #entries do
            PrintEntry(entries[i], "slottable")
        end
        return
    end

    -- No confirmed slottables: emit raw observed slot IDs then all unknown skill states.
    local observedList = {}
    for slotId, _ in pairs(self.championObservedSlotIds or {}) do
        observedList[#observedList + 1] = tostring(slotId)
    end
    table.sort(observedList)
    if #observedList > 0 then
        self:Print("Observed (currently slotted) IDs: " .. table.concat(observedList, ", "))
    else
        self:Print("Slot probing found no IDs. Run /cm debugbuild to check slot API availability.")
    end

    local unknownEntries = {}
    for _, skillState in pairs(self.championAllSkillStates or {}) do
        unknownEntries[#unknownEntries + 1] = skillState
    end

    if #unknownEntries == 0 then
        self:Print("No skill states collected; Champion API may be unavailable.")
        return
    end

    table.sort(unknownEntries, function(a, b)
        local bucketA = bucketOrder[a.bucketKey or ""] or 99
        local bucketB = bucketOrder[b.bucketKey or ""] or 99
        if bucketA ~= bucketB then
            return bucketA < bucketB
        end
        if tostring(a.disciplineName or "") ~= tostring(b.disciplineName or "") then
            return tostring(a.disciplineName or "") < tostring(b.disciplineName or "")
        end
        if tostring(a.name or "") ~= tostring(b.name or "") then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return (a.skillId or 0) < (b.skillId or 0)
    end)

    self:Print(string.format("Dumping all %d unknown skills (slottable API unavailable):", #unknownEntries))
    for i = 1, #unknownEntries do
        PrintEntry(unknownEntries[i], "?")
    end
end

local function BuildChampionSnapshot()
    local snapshot = {
        totalPoints = nil,
        warfare = {},
        fitness = {},
        craft = {},
        available = false,
    }

    local totalResults = SafeCallResults(GetPlayerChampionPointsEarned)
    snapshot.totalPoints = tonumber(totalResults and totalResults[1]) or nil

    local g = type(_G) == "table" and _G or nil
    local cdm = g and g.CHAMPION_DATA_MANAGER or nil
    local hotbarCat = g and g.HOTBAR_CATEGORY_CHAMPION or nil

    -- Fast path: CHAMPION_DATA_MANAGER is the accurate console PTS source (same as LibCombat).
    if cdm ~= nil and type(cdm.disciplineDatas) == "table" then
        local slotsById = {}
        if type(GetSlotBoundId) == "function" and hotbarCat ~= nil then
            for slotIndex = 1, 12 do
                local ok, starId = pcall(GetSlotBoundId, slotIndex, hotbarCat)
                if ok and type(starId) == "number" and starId > 0 then
                    slotsById[starId] = true
                end
            end
        end

        local slotDebugInfo = {
            method = "CHAMPION_DATA_MANAGER",
            foundIds = slotsById,
            probes = {},
        }

        local disciplineCount = 0
        for _, discipline in pairs(cdm.disciplineDatas) do
            disciplineCount = disciplineCount + 1
            local disciplineId = discipline.disciplineId

            local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
            local disciplineName = (disciplineNameResults and disciplineNameResults[1])
                or string.format("Discipline %d", disciplineId)
            local disciplineType = ChampionFirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
            local bucketKey = RemapChampionBucket(ClassifyChampionDisciplineBucket(disciplineName, disciplineType))

            local totalPoints = 0
            if type(discipline.GetNumSavedSpentPoints) == "function" then
                local ok, pts = pcall(discipline.GetNumSavedSpentPoints, discipline)
                totalPoints = (ok and tonumber(pts)) or 0
            end

            local entry = {
                name = disciplineName,
                points = totalPoints,
                stars = {},
                slottedStars = {},
                debug = {
                    disciplineId = disciplineId,
                    disciplineType = disciplineType,
                    method = "CHAMPION_DATA_MANAGER",
                    skillPointProbes = {},
                },
            }

            local summedPoints = 0
            for _, star in pairs(discipline.championSkillDatas or {}) do
                local starId = star.championSkillId
                if starId then
                    local savedPoints = 0
                    if type(star.GetNumSavedPoints) == "function" then
                        local ok, pts = pcall(star.GetNumSavedPoints, star)
                        savedPoints = (ok and tonumber(pts)) or 0
                    end
                    if savedPoints > 0 then
                        summedPoints = summedPoints + savedPoints
                    end

                    if slotsById[starId] then
                        local starName = string.format("Star %d", starId)
                        if type(GetChampionSkillName) == "function" then
                            local ok, name = pcall(GetChampionSkillName, starId)
                            if ok and type(name) == "string" and name ~= "" then
                                starName = name
                            end
                        end
                        entry.stars[#entry.stars + 1] = starName
                        entry.slottedStars[#entry.slottedStars + 1] = { name = starName, skillId = starId }
                    end
                end
            end

            if summedPoints > 0 then
                entry.points = summedPoints
            end

            if bucketKey then
                snapshot[bucketKey][#snapshot[bucketKey] + 1] = entry
            end
        end

        snapshot.available = disciplineCount > 0
        snapshot._slotDebugInfo = slotDebugInfo
        return snapshot
    end

    -- Fallback: probe-based approach when CHAMPION_DATA_MANAGER is unavailable.
    local slottedIds = {}
    local slottedNames = {}

    local function NormalizeName(name)
        if type(name) ~= "string" then
            return nil
        end
        local normalized = string.lower(name)
        normalized = string.gsub(normalized, "|c%x%x%x%x%x%x", "")
        normalized = string.gsub(normalized, "|r", "")
        normalized = string.gsub(normalized, "[^%w%s]", " ")
        normalized = string.gsub(normalized, "%s+", " ")
        normalized = string.gsub(normalized, "^%s+", "")
        normalized = string.gsub(normalized, "%s+$", "")
        return normalized ~= "" and normalized or nil
    end

    local function AddSlottedName(name)
        local normalized = NormalizeName(name)
        if normalized then
            slottedNames[normalized] = true
        end
    end

    local function AddSlottedId(skillId)
        local sid = tonumber(skillId)
        if not sid or sid <= 0 then
            return
        end
        slottedIds[sid] = true
        if type(GetChampionSkillName) == "function" then
            local ok, name = pcall(GetChampionSkillName, sid)
            if ok then
                AddSlottedName(name)
            end
        end
        if type(GetAbilityName) == "function" then
            local ok, name = pcall(GetAbilityName, sid)
            if ok then
                AddSlottedName(name)
            end
        end
    end

    local function FirstNumber(results)
        if type(results) ~= "table" then
            return nil
        end
        for i = 1, #results do
            local value = tonumber(results[i])
            if value ~= nil then
                return value
            end
        end
        return nil
    end

    local function FirstPositiveNumber(results)
        if type(results) ~= "table" then
            return nil
        end
        for i = 1, #results do
            local value = tonumber(results[i])
            if value and value > 0 then
                return value
            end
        end
        return nil
    end

    local function ReadNumberFromFunctionNames(fnNames, ...)
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                local results = SafeCallResults(fn, ...)
                local value = FirstNumber(results)
                if value ~= nil then
                    return value
                end
            end
        end
        return nil
    end

    local unpackFn = table.unpack or unpack

    local function ReadMaxNumberFromFunctionNamesWithArgLists(fnNames, argLists)
        local best = nil
        for i = 1, #argLists do
            local value = ReadNumberFromFunctionNames(fnNames, unpackFn(argLists[i]))
            if value ~= nil and (best == nil or value > best) then
                best = value
            end
        end
        return best
    end

    local function CollectNumberProbeValues(fnNames, argLists)
        local values = {}
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                for j = 1, #argLists do
                    local value = FirstNumber(SafeCallResults(fn, unpackFn(argLists[j])))
                    if value ~= nil then
                        values[#values + 1] = string.format("%s(%s)=%s", fnNames[i], table.concat(argLists[j], ""), tostring(value))
                    end
                end
            end
        end
        return values
    end

    local function ReadBooleanFromFunctionNames(fnNames, ...)
        for i = 1, #fnNames do
            local fn = g and g[fnNames[i]]
            if type(fn) == "function" then
                local results = SafeCallResults(fn, ...)
                if type(results) == "table" and type(results[1]) == "boolean" then
                    return results[1]
                end
            end
        end
        return nil
    end

    local slotContentFns = {
        "GetChampionSkillSlotSkillId",
        "GetChampionSkillSlotAbilityId",
        "GetChampionSkillSlotId",
        "GetChampionSlottedSkillId",
        "GetChampionSkillInSlot",
        "GetChampionSkillIdInSlot",
        "GetSlottedChampionSkillId",
    }

    local numSlotsResults = SafeCallResults(GetNumChampionSkillSlots)
    local numSlots = tonumber(numSlotsResults and numSlotsResults[1]) or 12
    if numSlots <= 0 then
        numSlots = 12
    end
    local slotProbeMax = math.max(numSlots, 64)

    local slotDebugInfo = {
        numSlotsFunction = "GetNumChampionSkillSlots",
        numSlotsResult = FirstNumber(numSlotsResults),
        resolvedNumSlots = numSlots,
        probeMax = slotProbeMax,
        probes = {},
        foundIds = {},
    }

    for _, fnName in ipairs(slotContentFns) do
        local fn = g and g[fnName]
        if type(fn) == "function" then
            for slotIdx = 1, slotProbeMax do
                local result = FirstPositiveNumber(SafeCallResults(fn, slotIdx))
                if result then
                    slotDebugInfo.probes[#slotDebugInfo.probes + 1] = string.format("%s(%d)=%d", fnName, slotIdx, result)
                    slotDebugInfo.foundIds[result] = true
                    AddSlottedId(result)
                end
            end
            for slotIdx = 0, slotProbeMax do
                local result = FirstPositiveNumber(SafeCallResults(fn, slotIdx))
                if result then
                    slotDebugInfo.probes[#slotDebugInfo.probes + 1] = string.format("%s(%d)=%d", fnName, slotIdx, result)
                    slotDebugInfo.foundIds[result] = true
                    AddSlottedId(result)
                end
            end
        end
    end

    local abilityIdFns = {
        "GetChampionSkillAbilityId",
        "GetAbilityIdForChampionSkill",
        "GetChampionSkillProgressionAbilityId",
    }

    local function ResolveAbilityIdForSkill(skillId, disciplineArg, skillIndexArg)
        if not skillId then
            return nil
        end
        local abilityId = ReadNumberFromFunctionNames(abilityIdFns, skillId)
        if abilityId and abilityId > 0 then
            return abilityId
        end
        if disciplineArg ~= nil and skillIndexArg ~= nil then
            abilityId = ReadNumberFromFunctionNames(abilityIdFns, disciplineArg, skillIndexArg)
            if abilityId and abilityId > 0 then
                return abilityId
            end
        end
        return nil
    end

    local function IsSkillSlottedById(skillId, disciplineArg, skillIndexArg)
        if slottedIds[skillId] then
            return true
        end

        local mappedAbilityId = ResolveAbilityIdForSkill(skillId, disciplineArg, skillIndexArg)
        if mappedAbilityId and slottedIds[mappedAbilityId] then
            return true
        end

        local slottedCheckFns = {
            "IsChampionSkillSlotted",
            "IsSlottedChampionSkill",
            "IsChampionAbilitySlotted",
        }
        local isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, skillId)
        if isSlotted == true then
            return true
        end
        if disciplineArg ~= nil and skillIndexArg ~= nil then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, disciplineArg, skillIndexArg)
            if isSlotted == true then
                return true
            end
        end
        if skillIndexArg ~= nil then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, skillIndexArg)
            if isSlotted == true then
                return true
            end
        end
        if mappedAbilityId then
            isSlotted = ReadBooleanFromFunctionNames(slottedCheckFns, mappedAbilityId)
            if isSlotted == true then
                return true
            end
        end

        local normalized = nil
        if type(GetChampionSkillName) == "function" then
            local ok, skillName = pcall(GetChampionSkillName, skillId)
            normalized = ok and NormalizeName(skillName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        if mappedAbilityId and type(GetAbilityName) == "function" then
            local ok, abilityName = pcall(GetAbilityName, mappedAbilityId)
            normalized = ok and NormalizeName(abilityName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        if type(GetAbilityName) == "function" then
            local ok, abilityName = pcall(GetAbilityName, skillId)
            normalized = ok and NormalizeName(abilityName) or nil
            if normalized and slottedNames[normalized] then
                return true
            end
        end

        return false
    end

    local disciplineCountResults = SafeCallResults(GetNumChampionDisciplines)
    local disciplineCount = FirstNumber(disciplineCountResults) or 0
    if disciplineCount <= 0 then
        return snapshot
    end
    snapshot.available = true

    local disciplineIndices = {}
    for index = 1, disciplineCount do
        disciplineIndices[#disciplineIndices + 1] = index
    end
    for index = 0, math.max(0, disciplineCount - 1) do
        disciplineIndices[#disciplineIndices + 1] = index
    end

    local seenDisciplineIds = {}
    for _, index in ipairs(disciplineIndices) do
        local disciplineIdResults = SafeCallResults(GetChampionDisciplineId, index)
        local disciplineId = FirstPositiveNumber(disciplineIdResults)
        if not disciplineId and type(index) == "number" and index > 0 then
            disciplineId = index
        end
        if disciplineId and not seenDisciplineIds[disciplineId] then
            seenDisciplineIds[disciplineId] = true
            local disciplineNameResults = SafeCallResults(GetChampionDisciplineName, disciplineId)
            local disciplineName = disciplineNameResults and disciplineNameResults[1] or string.format("Discipline %d", disciplineId)
            local disciplineType = FirstNumber(SafeCallResults(GetChampionDisciplineType, disciplineId))
                or FirstNumber(SafeCallResults(GetChampionDisciplineType, index))
            local bucketKey = RemapChampionBucket(ClassifyChampionDisciplineBucket(disciplineName, disciplineType))

            local pointsFnNames = {
                "GetNumPointsSpentOnChampionDiscipline",
                "GetNumPointsSpentInChampionDiscipline",
                "GetNumSpentPointsOnChampionDiscipline",
                "GetNumSpentChampionPointsOnDiscipline",
            }
            local pointsArgs = {
                { disciplineId },
                { index },
            }
            if disciplineType ~= nil then
                pointsArgs[#pointsArgs + 1] = { disciplineType }
            end
            local entry = {
                name = disciplineName,
                points = ReadMaxNumberFromFunctionNamesWithArgLists(pointsFnNames, pointsArgs) or 0,
                stars = {},
                slottedStars = {},
                debug = {
                    disciplineId = disciplineId,
                    disciplineIndex = index,
                    disciplineType = disciplineType,
                    pointsProbes = CollectNumberProbeValues(pointsFnNames, pointsArgs),
                    skillPointProbes = {},
                },
            }

            local skillCount = 0
            local skillCountArgs = {
                { disciplineId },
                { index },
            }
            if disciplineType ~= nil then
                skillCountArgs[#skillCountArgs + 1] = { disciplineType }
            end
            for i = 1, #skillCountArgs do
                local count = FirstNumber(SafeCallResults(GetNumChampionDisciplineSkills, unpackFn(skillCountArgs[i])))
                if count and count > skillCount then
                    skillCount = count
                end
            end

            local skillIdFnNames = {
                "GetChampionSkillId",
                "GetChampionDisciplineSkillId",
                "GetChampionSkillIdByIndex",
                "GetChampionDisciplineSkillIdByIndex",
            }

            local function ResolveSkillId(skillIndex)
                local argLists = {
                    { disciplineId, skillIndex },
                    { index, skillIndex },
                }
                if disciplineType ~= nil then
                    argLists[#argLists + 1] = { disciplineType, skillIndex }
                end

                for i = 1, #skillIdFnNames do
                    local fn = g and g[skillIdFnNames[i]]
                    if type(fn) == "function" then
                        for j = 1, #argLists do
                            local skillId = FirstPositiveNumber(SafeCallResults(fn, unpackFn(argLists[j])))
                            if skillId then
                                return skillId
                            end
                        end
                    end
                end

                return nil
            end

            local seenSkillIds = {}
            local summedSkillPoints = 0
            local skillPointsFnNames = {
                "GetNumPointsSpentOnChampionSkill",
                "GetNumPointsSpentInChampionSkill",
                "GetNumSpentPointsOnChampionSkill",
                "GetNumSpentChampionPointsOnSkill",
                "GetChampionSkillCurrentPoints",
                "GetChampionSkillNumPoints",
            }
            local seenSkillProbeLogs = {}
            local function CollectSkill(skillId, skillIndex)
                if not skillId then
                    return
                end

                local skillState = seenSkillIds[skillId]
                if not skillState then
                    local skillNameResults = SafeCallResults(GetChampionSkillName, skillId)
                    skillState = {
                        name = skillNameResults and skillNameResults[1] or string.format("Skill %d", skillId),
                        points = 0,
                        slotted = false,
                    }
                    seenSkillIds[skillId] = skillState
                end

                local skillName = skillState.name

                local skillPointArgs = {
                    { skillId },
                    { disciplineId, skillId },
                    { index, skillId },
                }
                if skillIndex ~= nil then
                    skillPointArgs[#skillPointArgs + 1] = { disciplineId, skillIndex }
                    skillPointArgs[#skillPointArgs + 1] = { index, skillIndex }
                end
                if disciplineType ~= nil then
                    skillPointArgs[#skillPointArgs + 1] = { disciplineType, skillId }
                    if skillIndex ~= nil then
                        skillPointArgs[#skillPointArgs + 1] = { disciplineType, skillIndex }
                    end
                end

                local skillPoints = ReadMaxNumberFromFunctionNamesWithArgLists(skillPointsFnNames, skillPointArgs) or 0
                if skillPoints > skillState.points then
                    summedSkillPoints = summedSkillPoints - skillState.points + skillPoints
                    skillState.points = skillPoints
                end

                if entry.points <= 0 then
                    for i = 1, #skillPointsFnNames do
                        local fn = g and g[skillPointsFnNames[i]]
                        if type(fn) == "function" then
                            for j = 1, #skillPointArgs do
                                local value = FirstNumber(SafeCallResults(fn, unpackFn(skillPointArgs[j])))
                                if value ~= nil then
                                    local probeText = string.format(
                                        "%s(skill=%s:%s,args=%s)=%s",
                                        skillPointsFnNames[i],
                                        tostring(skillId),
                                        tostring(skillName),
                                        table.concat(skillPointArgs[j], ""),
                                        tostring(value)
                                    )
                                    if not seenSkillProbeLogs[probeText] then
                                        seenSkillProbeLogs[probeText] = true
                                        entry.debug.skillPointProbes[#entry.debug.skillPointProbes + 1] = probeText
                                    end
                                end
                            end
                        end
                    end
                end

                if not skillState.slotted and (IsSkillSlottedById(skillId, disciplineId, skillIndex) or IsSkillSlottedById(skillId, disciplineType, skillIndex)) then
                    skillState.slotted = true
                    entry.stars[#entry.stars + 1] = skillName
                    entry.slottedStars[#entry.slottedStars + 1] = { name = skillName, skillId = skillId }
                end
            end

            local skillProbeMax = math.max(skillCount + 8, 96)

            for skillIndex = 1, skillProbeMax do
                local skillId = ResolveSkillId(skillIndex)
                CollectSkill(skillId, skillIndex)
            end

            for skillIndex = 0, skillProbeMax do
                local skillId = ResolveSkillId(skillIndex)
                CollectSkill(skillId, skillIndex)
            end

            if summedSkillPoints > 0 then
                entry.points = summedSkillPoints
            end

            if bucketKey then
                snapshot[bucketKey][#snapshot[bucketKey] + 1] = entry
            end
        end
    end

    snapshot._slotDebugInfo = slotDebugInfo

    return snapshot
end

local function UnitName(rawName)
    if not rawName or rawName == "" then
        return "Unknown"
    end

    local cached = UNIT_NAME_CACHE[rawName]
    if cached then
        return cached
    end

    local formatted = rawName
    if type(zo_strformat) == "function" then
        formatted = zo_strformat(SI_UNIT_NAME, rawName)
    end

    UNIT_NAME_CACHE[rawName] = formatted
    UNIT_NAME_CACHE_SIZE = UNIT_NAME_CACHE_SIZE + 1
    if UNIT_NAME_CACHE_SIZE > UNIT_NAME_CACHE_MAX then
        UNIT_NAME_CACHE = {}
        UNIT_NAME_CACHE_SIZE = 0
    end

    return formatted
end

local function IsDamageResult(result)
    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_DOT_TICK
        or result == ACTION_RESULT_DOT_TICK_CRITICAL
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DAMAGE_SHIELDED
        or result == ACTION_RESULT_BLOCKED_DAMAGE
end

local function IsHealResult(result)
    return result == ACTION_RESULT_HEAL
        or result == ACTION_RESULT_HOT_TICK
        or result == ACTION_RESULT_HOT_TICK_CRITICAL
        or result == ACTION_RESULT_CRITICAL_HEAL
end

local function IsCriticalResult(result)
    return result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_CRITICAL_HEAL
end

local function IsEffectGainedResult(result)
    return result == ACTION_RESULT_EFFECT_GAINED
        or result == ACTION_RESULT_EFFECT_GAINED_DURATION
        or result == ACTION_RESULT_EFFECT_REFRESH
        or result == ACTION_RESULT_EFFECT_REAPPLIED
end

local function IsEffectFadedResult(result)
    return result == ACTION_RESULT_EFFECT_FADED
        or result == ACTION_RESULT_EFFECT_FADED_DURATION
end

local function Clamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

-- Module-level comparators: avoids allocating a new closure on every sort call (GC win on console).
local function _SkillByDamageDesc(a, b) return a.damage > b.damage end
local function _SkillByHealDesc(a, b) return (a.heal or 0) > (b.heal or 0) end
local function _TopMomentByValueDesc(a, b) return (a.value or 0) > (b.value or 0) end

local function SortSkillEntries(skillMap)
    local list = {}
    for _, info in pairs(skillMap) do
        list[#list + 1] = info
    end
    table.sort(list, _SkillByDamageDesc)
    return list
end

local function SortSkillEntriesByHeal(skillMap)
    local list = {}
    for _, info in pairs(skillMap) do
        if (info.heal or 0) > 0 then
            list[#list + 1] = info
        end
    end
    table.sort(list, _SkillByHealDesc)
    return list
end

local function AddTopMoment(momentList, moment)
    local count = #momentList
    -- Skip sort entirely when the list is full and this moment won't rank.
    if count >= TOP_MOMENTS_LIMIT and (momentList[count].value or 0) >= (moment.value or 0) then
        return
    end
    momentList[count + 1] = moment
    table.sort(momentList, _TopMomentByValueDesc)
    if #momentList > TOP_MOMENTS_LIMIT then
        table.remove(momentList, #momentList)
    end
end

local function CloneMoments(momentList)
    local clone = {}
    for i = 1, #momentList do
        local moment = momentList[i]
        clone[i] = {
            value = moment.value,
            label = moment.label,
            tooltip = moment.tooltip,
            abilityId = moment.abilityId,
            abilityName = moment.abilityName,
            effectName = moment.effectName,
        }
    end
    return clone
end

local function NewThroughputWindowTracker(intervalMs)
    return {
        intervalMs = math.max(1, math.floor(tonumber(intervalMs) or 1000)),
        currentWindowIndex = 0,
        currentWindowValue = 0,
        finalizedWindowCount = 0,
        finalizedPeakValue = nil,
        finalizedPeakIndex = nil,
        finalizedLowestValue = nil,
        finalizedLowestIndex = nil,
        finalizedLowestNonZeroValue = nil,
        finalizedLowestNonZeroIndex = nil,
    }
end

local function CloneThroughputWindowTracker(tracker)
    local source = tracker or NewThroughputWindowTracker(1000)
    return {
        intervalMs = source.intervalMs,
        currentWindowIndex = source.currentWindowIndex,
        currentWindowValue = source.currentWindowValue,
        finalizedWindowCount = source.finalizedWindowCount,
        finalizedPeakValue = source.finalizedPeakValue,
        finalizedPeakIndex = source.finalizedPeakIndex,
        finalizedLowestValue = source.finalizedLowestValue,
        finalizedLowestIndex = source.finalizedLowestIndex,
        finalizedLowestNonZeroValue = source.finalizedLowestNonZeroValue,
        finalizedLowestNonZeroIndex = source.finalizedLowestNonZeroIndex,
    }
end

local function FinalizeThroughputWindow(tracker, windowIndex, value)
    tracker.finalizedWindowCount = (tonumber(tracker.finalizedWindowCount) or 0) + 1

    local peakValue = tonumber(tracker.finalizedPeakValue)
    if peakValue == nil or value > peakValue then
        tracker.finalizedPeakValue = value
        tracker.finalizedPeakIndex = windowIndex
    end

    local lowValue = tonumber(tracker.finalizedLowestValue)
    if lowValue == nil or value < lowValue then
        tracker.finalizedLowestValue = value
        tracker.finalizedLowestIndex = windowIndex
    end

    if value > 0 then
        local lowNonZero = tonumber(tracker.finalizedLowestNonZeroValue)
        if lowNonZero == nil or value < lowNonZero then
            tracker.finalizedLowestNonZeroValue = value
            tracker.finalizedLowestNonZeroIndex = windowIndex
        end
    end
end

local function AdvanceThroughputWindowTracker(tracker, targetWindowIndex)
    if type(tracker) ~= "table" then
        return
    end

    local targetIndex = math.max(0, math.floor(tonumber(targetWindowIndex) or 0))
    local currentIndex = math.max(0, math.floor(tonumber(tracker.currentWindowIndex) or 0))
    if targetIndex <= currentIndex then
        return
    end

    local currentValue = tonumber(tracker.currentWindowValue) or 0
    FinalizeThroughputWindow(tracker, currentIndex, currentValue)

    if targetIndex > (currentIndex + 1) then
        local firstGapIndex = currentIndex + 1
        local gapCount = targetIndex - currentIndex - 1
        tracker.finalizedWindowCount = (tonumber(tracker.finalizedWindowCount) or 0) + gapCount

        local peakValue = tonumber(tracker.finalizedPeakValue)
        if peakValue == nil or 0 > peakValue then
            tracker.finalizedPeakValue = 0
            tracker.finalizedPeakIndex = firstGapIndex
        end

        local lowValue = tonumber(tracker.finalizedLowestValue)
        if lowValue == nil or 0 < lowValue then
            tracker.finalizedLowestValue = 0
            tracker.finalizedLowestIndex = firstGapIndex
        end
    end

    tracker.currentWindowIndex = targetIndex
    tracker.currentWindowValue = 0
end

local function AddThroughputWindowValueByTime(tracker, startMs, nowMs, value)
    if type(tracker) ~= "table" then
        return
    end

    local amount = tonumber(value) or 0
    if amount <= 0 then
        return
    end

    local intervalMs = math.max(1, math.floor(tonumber(tracker.intervalMs) or 1000))
    local baseMs = tonumber(startMs) or tonumber(nowMs) or 0
    local stampMs = tonumber(nowMs) or baseMs
    local elapsedMs = math.max(0, stampMs - baseMs)
    local targetIndex = math.floor(elapsedMs / intervalMs)

    AdvanceThroughputWindowTracker(tracker, targetIndex)
    tracker.currentWindowValue = (tonumber(tracker.currentWindowValue) or 0) + amount
end

local function NewFight(nowMs)
    local startTimestampSec = nil
    if type(GetTimeStamp) == "function" then
        startTimestampSec = tonumber(GetTimeStamp())
    end

    return {
        startMs = nowMs,
        startTimestampSec = startTimestampSec,
        endMs = nil,
        snapshotRev = 0,
        totalDamage = 0,
        totalOverflowDamage = 0,
        totalBlockedDamage = 0,
        totalShieldedDamage = 0,
        totalHeal = 0,
        totalOverflowHeal = 0,
        totalTaken = 0,
        totalIncomingOverflowDamage = 0,
        totalIncomingBlockedDamage = 0,
        totalIncomingShieldedDamage = 0,
        hits = 0,
        crits = 0,
        minHitValue = nil,
        maxHitValue = nil,
        peakDps = 0,
        peakHps = 0,
        damageWindowTracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS),
        healWindowTracker = NewThroughputWindowTracker(THROUGHPUT_WINDOW_INTERVAL_MS),
        skillMap = {},
        incomingSkillMap = {},
        incomingSetDamageMap = {},
        incomingLikelySetProcMap = {},
        dotMap = {},
        hotMap = {},
        targetMap = {},
        topHealingMoments = {},
        topMitigationMoments = {},
        -- Tracks every effect seen via ACTION_RESULT_EFFECT_GAINED/FADED style events.
        allEffects = {},
        -- Tracks major/minor subsets for fast console-friendly filtering.
        majorMinorEffects = {},
        -- Tracks popular PvE/PvP set procs by alias.
        setEffects = {},
        -- Separated tracking: buffs = effects whose target is the player,
        -- debuffs = effects the player applies to non-player targets.
        buffEffects   = {},
        debuffEffects = {},
        -- Resource snapshots sampled during combat for avg/median display.
        resourceSamples = {
            lastSampleMs = nil,
            healthPct = {},
            magickaPct = {},
            staminaPct = {},
            pingMs = {},
            -- Absolute value tracking for per-fight regen/drain/ultimate gen.
            lastAbsHealth = nil,
            lastAbsMagicka = nil,
            lastAbsStamina = nil,
            lastAbsUltimate = nil,
            lastPingMs = nil,
            minPingMs = nil,
            maxPingMs = nil,
            pingDipCount = 0,
            pingSpikeCount = 0,
            highDelaySamples = 0,
            totalHealthRegen = 0,
            totalHealthDrain = 0,
            totalMagickaRegen = 0,
            totalMagickaDrain = 0,
            totalStaminaRegen = 0,
            totalStaminaDrain = 0,
            totalUltimateGen = 0,
            totalUltimateDrain = 0,
        },
        protectionInfo = {
            currentState = "unknown",
            currentLabel = "No mitigation data",
            currentResistance = 0,
            currentDrPct = 0,
            confidence = 0,
            samples = 0,
            lastSampleMs = nowMs,
            drEma = 0,
            stateMs = {
                majorMinor = 0,
                major = 0,
                minor = 0,
                none = 0,
                unknown = 0,
            },
        },
    }
end

function ConsoleMetrics:IsFightViewDialogShowing()
    if not IsConsoleUI() and not (type(IsGamepadPreferred) == "function" and IsGamepadPreferred()) then
        return self:IsFightViewDialogShowingPC()
    end
    return self.ui.fightViewDialog ~= nil
        and self.ui.fightViewDialog.selected == true
        and LibHarvensAddonSettings ~= nil
        and LibHarvensAddonSettings.scene ~= nil
        and LibHarvensAddonSettings.scene:IsShowing()
end

function ConsoleMetrics:ArmDialogAutoHide()
    if not self.saved.dialogAutoHide then
        self.dialogAutoHideAtMs = nil
        return
    end

    local seconds = tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds
    seconds = Clamp(seconds, 3, 120)
    self.dialogAutoHideAtMs = GetFrameTimeMilliseconds() + (seconds * 1000)
end

function ConsoleMetrics:CloseFightViewDialog(silent, reason)
    -- PC path: close the native window
    if not IsConsoleUI() and not IsInGamepadPreferredMode() then
        self:ClosePCDialog()
        self.dialogPanel      = "main"
        self.dialogAutoHideAtMs  = nil
        self.dialogRefreshAtMs   = nil
        self.lastDialogRefreshKey = nil
        self.wasFightViewDialogShowing = false
        return
    end

    -- Treat any close/cancel as "return to main panel, then exit".
    self.dialogPanel = "main"
    self.dialogAutoHideAtMs = nil
    self.dialogRefreshAtMs = nil
    self.lastDialogRefreshKey = nil
    self.isClosingFightViewDialog = true

    if self.ui.fightViewDialog then
        -- Clear selection state first so OnUpdate won't treat this as an active panel.
        self.ui.fightViewDialog.selected = false
        if self.ui.fightViewDialog.Hide then
            self.ui.fightViewDialog:Hide()
        end
    end

    if LibHarvensAddonSettings and LibHarvensAddonSettings.scene and LibHarvensAddonSettings.scene.Hide then
        LibHarvensAddonSettings.scene:Hide()
    end

    if LibConsoleDialogs then
        LibConsoleDialogs:Close()
    end

    -- Force a fresh instance next open to avoid stale scene/selection state.
    self.ui.fightViewDialog = nil
    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false

    if not silent then
        local source = reason or "manual"
        self:Print(string.format("Fight data dialog closed (%s)", source))
    end
end

local function GetFightDurationSeconds(fight, nowMs)
    if not fight or not fight.startMs then
        return 0
    end

    local endMs = fight.endMs or nowMs
    return math.max((endMs - fight.startMs) / 1000, 0)
end

local function EstimateTargetResistance(target)
    if not target then
        return 0, 0
    end

    local mitigatedLike = (target.blocked or 0) + (target.shielded or 0)
    local totalObserved = (target.effective or 0) + (target.overflow or 0) + mitigatedLike
    if totalObserved <= 0 then
        return 0, 0
    end

    local mitigationRatio = Clamp(mitigatedLike / totalObserved, 0, 0.5)
    local resistance = Clamp(mitigationRatio * RESISTANCE_SCALE, 0, RESISTANCE_CAP)
    return resistance, mitigationRatio * 100
end

local function InferProtectionFromDr(drPct, hasData)
    if not hasData then
        return "No mitigation data", "unknown", 0
    end

    if drPct >= (MAJOR_PROTECTION_DR_PCT + MINOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.65 + ((drPct - (MAJOR_PROTECTION_DR_PCT + MINOR_PROTECTION_DR_PCT)) / 20), 0.45, 0.98)
        return "Major + Minor Protection (inferred)", "majorMinor", confidence
    end

    if drPct >= (MAJOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.60 + ((drPct - MAJOR_PROTECTION_DR_PCT) / 18), 0.40, 0.95)
        return "Major Protection (inferred)", "major", confidence
    end

    if drPct >= (MINOR_PROTECTION_DR_PCT - 1.0) then
        local confidence = Clamp(0.55 + ((drPct - MINOR_PROTECTION_DR_PCT) / 15), 0.35, 0.90)
        return "Minor Protection (inferred)", "minor", confidence
    end

    local confidence = Clamp(0.50 + ((MINOR_PROTECTION_DR_PCT - drPct) / 15), 0.30, 0.90)
    return "No Protection inferred", "none", confidence
end

local function IsMajorMinorEffectName(effectName)
    if not effectName then return false end
    -- Fast reject: almost all ability names don't start with 'm'/'M'.
    local b = string.byte(effectName, 1)
    if b ~= 109 and b ~= 77 then return false end  -- 'm' or 'M'
    local prefix = string.lower(string.sub(effectName, 1, 6))
    return prefix == "major " or prefix == "minor "
end

local function MatchPopularSet(abilityName)
    if not abilityName or abilityName == "" then
        return nil
    end

    local lower = string.lower(abilityName)
    for i = 1, #POPULAR_SET_CATALOG do
        local entry = POPULAR_SET_CATALOG[i]
        for j = 1, #entry.aliases do
            local alias = entry.aliases[j]
            if string.find(lower, alias, 1, true) ~= nil then
                return entry
            end
        end
    end

    return nil
end

local function NormalizeCustomSetScene(scene)
    local lower = string.lower(TrimText(scene))
    if lower == "" then
        return "PvP"
    end
    if lower == "pve" then
        return "PvE"
    end
    if lower == "pvp" then
        return "PvP"
    end
    return "Custom"
end

local function BuildCustomAliasList(abilityName)
    local aliases = {}
    local base = string.lower(TrimText(abilityName))
    if base == "" then
        return aliases
    end

    aliases[#aliases + 1] = base
    for token in string.gmatch(base, "[^,%|;]+") do
        local clean = TrimText(token)
        if clean ~= "" then
            local exists = false
            for i = 1, #aliases do
                if aliases[i] == clean then
                    exists = true
                    break
                end
            end
            if not exists then
                aliases[#aliases + 1] = clean
            end
        end
    end

    return aliases
end

local function ClassifyLikelySetProc(abilityName)
    if not abilityName or abilityName == "" then
        return false, nil, 0
    end

    local lower = string.lower(abilityName)
    local cached = LIKELY_SET_PROC_CACHE[lower]
    if cached then
        return cached.matched, cached.reason, cached.score
    end

    local function CacheResult(matched, reason, score)
        LIKELY_SET_PROC_CACHE[lower] = {
            matched = matched,
            reason = reason,
            score = score,
        }
        LIKELY_SET_PROC_CACHE_SIZE = LIKELY_SET_PROC_CACHE_SIZE + 1
        if LIKELY_SET_PROC_CACHE_SIZE > LIKELY_SET_PROC_CACHE_MAX then
            LIKELY_SET_PROC_CACHE = {}
            LIKELY_SET_PROC_CACHE_SIZE = 0
        end
        return matched, reason, score
    end

    -- Keep curated matching authoritative and separate from heuristic rows.
    if MatchPopularSet(abilityName) then
        return CacheResult(false, nil, 0)
    end

    local score = 0
    local reasons = {}

    for i = 1, #LIKELY_SET_PROC_KEYWORDS do
        local keyword = LIKELY_SET_PROC_KEYWORDS[i]
        if string.find(lower, keyword, 1, true) ~= nil then
            score = score + 1
            reasons[#reasons + 1] = keyword
        end
    end

    if string.find(lower, "'s ", 1, true) ~= nil then
        score = score + 1
        reasons[#reasons + 1] = "possessive"
    end

    if string.find(lower, " of ", 1, true) ~= nil then
        score = score + 0.5
        reasons[#reasons + 1] = "name pattern"
    end

    if score < 1.5 then
        return CacheResult(false, nil, score)
    end

    return CacheResult(true, table.concat(reasons, ", "), score)
end

local function BuildProtectionSummary(protectionInfo, nowMs)
    local stateMs = {
        majorMinor = 0,
        major = 0,
        minor = 0,
        none = 0,
        unknown = 0,
    }

    if protectionInfo and protectionInfo.stateMs then
        stateMs.majorMinor = protectionInfo.stateMs.majorMinor or 0
        stateMs.major = protectionInfo.stateMs.major or 0
        stateMs.minor = protectionInfo.stateMs.minor or 0
        stateMs.none = protectionInfo.stateMs.none or 0
        stateMs.unknown = protectionInfo.stateMs.unknown or 0

        if protectionInfo.lastSampleMs and protectionInfo.currentState and nowMs > protectionInfo.lastSampleMs then
            local elapsed = nowMs - protectionInfo.lastSampleMs
            local key = protectionInfo.currentState
            stateMs[key] = (stateMs[key] or 0) + elapsed
        end
    end

    local totalMs = stateMs.majorMinor + stateMs.major + stateMs.minor + stateMs.none + stateMs.unknown
    local trackedKnownMs = stateMs.majorMinor + stateMs.major + stateMs.minor + stateMs.none
    local anyProtectionMs = stateMs.majorMinor + stateMs.major + stateMs.minor

    local function Ratio(ms)
        if totalMs <= 0 then
            return 0
        end
        return (ms / totalMs) * 100
    end

    return {
        totalMs = totalMs,
        trackedKnownMs = trackedKnownMs,
        majorMinorMs = stateMs.majorMinor,
        majorMs = stateMs.major,
        minorMs = stateMs.minor,
        noneMs = stateMs.none,
        unknownMs = stateMs.unknown,
        anyProtectionMs = anyProtectionMs,
        majorMinorPct = Ratio(stateMs.majorMinor),
        majorPct = Ratio(stateMs.major),
        minorPct = Ratio(stateMs.minor),
        nonePct = Ratio(stateMs.none),
        unknownPct = Ratio(stateMs.unknown),
        anyProtectionPct = Ratio(anyProtectionMs),
    }
end

local function AcquireTrackedEffect(effectMap, key, name, category, abilityId, effectName)
    local track = effectMap[key]
    if not track then
        track = {
            key = key,
            name = name,
            category = category,
            abilityId = SafeAbilityId(abilityId),
            effectName = effectName or name,
            uptimeMs = 0,
            activeSinceMs = nil,
            activations = 0,
            fades = 0,
            procs = 0,
            totalValue = 0,
        }
        effectMap[key] = track
    else
        if (track.name == nil or track.name == "") and name and name ~= "" then
            track.name = name
        end
        if (track.effectName == nil or track.effectName == "") and effectName and effectName ~= "" then
            track.effectName = effectName
        end
        if (track.abilityId == nil or track.abilityId == 0) and SafeAbilityId(abilityId) > 0 then
            track.abilityId = SafeAbilityId(abilityId)
        end
    end

    return track
end

local function StartTrackedEffect(track, nowMs)
    if track.activeSinceMs == nil then
        track.activeSinceMs = nowMs
        track.activations = (track.activations or 0) + 1
    end
end

local function StopTrackedEffect(track, nowMs)
    if track.activeSinceMs ~= nil and nowMs >= track.activeSinceMs then
        track.uptimeMs = (track.uptimeMs or 0) + (nowMs - track.activeSinceMs)
        track.activeSinceMs = nil
        track.fades = (track.fades or 0) + 1
    end
end

-- Convert internal per-effect runtime state into sorted, render-ready summary rows.
local function _EffectByUptimeThenProcsDesc(a, b)
    if a.uptimePct == b.uptimePct then
        return (a.procs or 0) > (b.procs or 0)
    end
    return a.uptimePct > b.uptimePct
end

local function BuildTrackedEffectList(effectMap, durationSeconds, nowMs)
    local list = {}
    local durationMs = math.max((durationSeconds or 0) * 1000, 0)

    for _, track in pairs(effectMap or {}) do
        local uptimeMs = track.uptimeMs or 0
        if track.activeSinceMs and nowMs > track.activeSinceMs then
            uptimeMs = uptimeMs + (nowMs - track.activeSinceMs)
        end

        local uptimePct = 0
        if durationMs > 0 then
            uptimePct = Clamp((uptimeMs / durationMs) * 100, 0, 100)
        end

        list[#list + 1] = {
            name = track.name,
            category = track.category,
            abilityId = SafeAbilityId(track.abilityId),
            effectName = track.effectName or track.name,
            uptimeMs = uptimeMs,
            uptimePct = uptimePct,
            activations = track.activations or 0,
            fades = track.fades or 0,
            procs = track.procs or 0,
            totalValue = track.totalValue or 0,
        }
    end

    table.sort(list, _EffectByUptimeThenProcsDesc)

    return list
end

local function Mean(values)
    if #values == 0 then
        return 0
    end

    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end

    return sum / #values
end

local function Median(values)
    local count = #values
    if count == 0 then
        return 0
    end

    local sorted = {}
    for i = 1, count do
        sorted[i] = values[i]
    end
    table.sort(sorted)

    local midpoint = math.floor(count / 2)
    if (count % 2) == 1 then
        return sorted[midpoint + 1]
    end

    return (sorted[midpoint] + sorted[midpoint + 1]) / 2
end

local function SafeGetCurrentPowerFromList(powerTypeList)
    if type(GetUnitPower) ~= "function" or type(powerTypeList) ~= "table" then
        return nil
    end

    for i = 1, #powerTypeList do
        local powerType = powerTypeList[i]
        if type(powerType) == "number" then
            local current = GetUnitPower("player", powerType)
            if current and current >= 0 then
                return current
            end
        end
    end

    return nil
end

local function SafeGetMaxPowerFromList(powerTypeList)
    if type(GetUnitPower) ~= "function" or type(powerTypeList) ~= "table" then
        return nil
    end

    for i = 1, #powerTypeList do
        local powerType = powerTypeList[i]
        if type(powerType) == "number" then
            local _, maximum = GetUnitPower("player", powerType)
            if maximum and maximum > 0 then
                return maximum
            end
        end
    end

    return nil
end

local function SafeGetPowerPctFromList(powerTypeList)
    local current = SafeGetCurrentPowerFromList(powerTypeList)
    local maximum = SafeGetMaxPowerFromList(powerTypeList)
    if not current or not maximum or maximum <= 0 then
        return nil
    end

    return Clamp((current / maximum) * 100, 0, 100)
end

local function BuildResourceSampleSummary(values)
    local startIndex = tonumber(values and values._cmStart) or 1
    local count = values and ((#values - startIndex) + 1) or 0
    if count <= 0 then
        return {
            samples = 0,
            averagePct = 0,
            medianPct = 0,
            minPct = 0,
            maxPct = 0,
            hasData = false,
        }
    end

    local normalized = {}
    local minPct, maxPct = math.huge, -math.huge
    for i = startIndex, #values do
        local v = tonumber(values[i]) or 0
        normalized[#normalized + 1] = v
        if v < minPct then minPct = v end
        if v > maxPct then maxPct = v end
    end

    return {
        samples = #normalized,
        averagePct = Mean(normalized),
        medianPct = Median(normalized),
        minPct = minPct,
        maxPct = maxPct,
        hasData = true,
    }
end

local function BuildNumericSampleSummary(values)
    local startIndex = tonumber(values and values._cmStart) or 1
    local count = values and ((#values - startIndex) + 1) or 0
    if count <= 0 then
        return {
            samples = 0,
            average = 0,
            median = 0,
            min = 0,
            max = 0,
            hasData = false,
        }
    end

    local normalized = {}
    local sum = 0
    local minValue = nil
    local maxValue = nil

    for i = startIndex, #values do
        local value = tonumber(values[i]) or 0
        normalized[#normalized + 1] = value
        sum = sum + value
        if minValue == nil or value < minValue then
            minValue = value
        end
        if maxValue == nil or value > maxValue then
            maxValue = value
        end
    end

    return {
        samples = #normalized,
        average = sum / #normalized,
        median = Median(normalized),
        min = minValue or 0,
        max = maxValue or 0,
        hasData = true,
    }
end

local function SafeGetLatencyMs()
    if type(GetLatency) ~= "function" then
        return nil
    end

    local latency = nil
    local ok = pcall(function()
        latency = GetLatency()
    end)
    if not ok then
        return nil
    end

    latency = tonumber(latency)
    if latency == nil or latency < 0 then
        return nil
    end

    -- Some API layers may expose latency in seconds; normalize to milliseconds.
    if latency > 0 and latency < 5 then
        latency = latency * 1000
    end

    return math.floor(latency + 0.5)
end

local function BuildSustainPerformanceSummary(magickaStats, staminaStats)
    local avgInputs = {}
    local medianInputs = {}

    if magickaStats and magickaStats.hasData then
        avgInputs[#avgInputs + 1] = magickaStats.averagePct or 0
        medianInputs[#medianInputs + 1] = magickaStats.medianPct or 0
    end
    if staminaStats and staminaStats.hasData then
        avgInputs[#avgInputs + 1] = staminaStats.averagePct or 0
        medianInputs[#medianInputs + 1] = staminaStats.medianPct or 0
    end

    if #avgInputs == 0 then
        return {
            hasData = false,
            averagePct = 0,
            medianPct = 0,
            label = "No sustain data",
            sourceCount = 0,
        }
    end

    local averagePct = Mean(avgInputs)
    local medianPct = Mean(medianInputs)
    local label = "Stable"
    if averagePct >= 75 then
        label = "Strong"
    elseif averagePct >= 50 then
        label = "Stable"
    elseif averagePct >= 30 then
        label = "Pressured"
    else
        label = "Critical"
    end

    return {
        hasData = true,
        averagePct = averagePct,
        medianPct = medianPct,
        label = label,
        sourceCount = #avgInputs,
    }
end

local function StdDev(values, mean)
    if #values <= 1 then
        return 0
    end

    local variance = 0
    for i = 1, #values do
        local diff = values[i] - mean
        variance = variance + (diff * diff)
    end

    variance = variance / (#values - 1)
    return math.sqrt(variance)
end

local function LinearSlope(values)
    local n = #values
    if n <= 1 then
        return 0
    end

    local sumX = 0
    local sumY = 0
    local sumXY = 0
    local sumXX = 0

    for i = 1, n do
        local x = i
        local y = values[i]
        sumX = sumX + x
        sumY = sumY + y
        sumXY = sumXY + (x * y)
        sumXX = sumXX + (x * x)
    end

    local denom = (n * sumXX) - (sumX * sumX)
    if denom == 0 then
        return 0
    end

    return ((n * sumXY) - (sumX * sumY)) / denom
end

local function ExponentialAverage(values, alpha)
    if #values == 0 then
        return 0
    end

    local ema = values[1]
    for i = 2, #values do
        ema = alpha * values[i] + (1 - alpha) * ema
    end
    return ema
end

-- Export shared constants and helpers so subsequent addon files can reuse them.
local shared = {
    POST_COMBAT_VISIBLE_MS = POST_COMBAT_VISIBLE_MS,
    DIALOG_LIVE_REFRESH_MS = DIALOG_LIVE_REFRESH_MS,
    METRICS_UPDATE_THROTTLE_MS = METRICS_UPDATE_THROTTLE_MS,
    SCROLL_UPDATE_THROTTLE_MS = SCROLL_UPDATE_THROTTLE_MS,
    PROTECTION_UPDATE_THROTTLE_MS = PROTECTION_UPDATE_THROTTLE_MS,
    COMBAT_SCROLL_EVENT_THROTTLE_MS = COMBAT_SCROLL_EVENT_THROTTLE_MS,
    EFFECT_STATE_EVENT_THROTTLE_MS = EFFECT_STATE_EVENT_THROTTLE_MS,
    RESISTANCE_CAP = RESISTANCE_CAP,
    RESISTANCE_SCALE = RESISTANCE_SCALE,
    TOP_MOMENTS_LIMIT = TOP_MOMENTS_LIMIT,
    MAJOR_PROTECTION_DR_PCT = MAJOR_PROTECTION_DR_PCT,
    MINOR_PROTECTION_DR_PCT = MINOR_PROTECTION_DR_PCT,
    EFFECTS_PANEL_LIMIT = EFFECTS_PANEL_LIMIT,
    THROUGHPUT_WINDOW_INTERVAL_MS = THROUGHPUT_WINDOW_INTERVAL_MS,
    RESOURCE_SAMPLE_INTERVAL_MS = RESOURCE_SAMPLE_INTERVAL_MS,
    RESOURCE_SAMPLE_MAX_POINTS = RESOURCE_SAMPLE_MAX_POINTS,
    OBSERVED_ABILITY_LOG_MAX = OBSERVED_ABILITY_LOG_MAX,
    MAX_FIGHT_HISTORY_HARD_CAP = MAX_FIGHT_HISTORY_HARD_CAP,
    LOW_MEMORY_LIST_LIMIT = LOW_MEMORY_LIST_LIMIT,
    LOW_MEMORY_MOMENTS_LIMIT = LOW_MEMORY_MOMENTS_LIMIT,
    LOW_MEMORY_EFFECT_LIMIT = LOW_MEMORY_EFFECT_LIMIT,
    PING_DIP_DELTA_MS = PING_DIP_DELTA_MS,
    PING_SPIKE_DELTA_MS = PING_SPIKE_DELTA_MS,
    PING_HIGH_DELAY_MS = PING_HIGH_DELAY_MS,
    COMBAT_TEXT_COLORS = COMBAT_TEXT_COLORS,
    COMBAT_COLOR_HEX = COMBAT_COLOR_HEX,
    METRIC_ROW_COLORS = METRIC_ROW_COLORS,
    POPULAR_SET_CATALOG = POPULAR_SET_CATALOG,
    UnitName = UnitName,
    GetResourcePowerTypes = GetResourcePowerTypes,
    MapRoleValueToProfileKey = MapRoleValueToProfileKey,
    GetSelectedRoleComparisonProfile = GetSelectedRoleComparisonProfile,
    ColorFromHex = ColorFromHex,
    SafeAbilityId = SafeAbilityId,
    FormatAbilityIdentity = FormatAbilityIdentity,
    NumberText = NumberText,
    ShortNumber = ShortNumber,
    ColorNum = ColorNum,
    ColorShort = ColorShort,
    ColorText = ColorText,
    TrimText = TrimText,
    BuildDefaultFightSaveName = BuildDefaultFightSaveName,
    GetActionBarSlotBounds = GetActionBarSlotBounds,
    SafeGetActionBarSlotName = SafeGetActionBarSlotName,
    BuildActionBarSnapshot = BuildActionBarSnapshot,
    BuildEquipmentSlotDefinitions = BuildEquipmentSlotDefinitions,
    SafeGetEquippedItemText = SafeGetEquippedItemText,
    BuildEquipmentSnapshot = BuildEquipmentSnapshot,
    BuildActiveBoonSnapshot = BuildActiveBoonSnapshot,
    SafeCallResults = SafeCallResults,
    FindFirstNonEmptyString = FindFirstNonEmptyString,
    BuildEquippedSetSummary = BuildEquippedSetSummary,
    BuildWeaponEffectSnapshot = BuildWeaponEffectSnapshot,
    ClassifyChampionDisciplineBucket = ClassifyChampionDisciplineBucket,
    RemapChampionBucket = RemapChampionBucket,
    ChampionFirstNumber = ChampionFirstNumber,
    ChampionFirstPositiveNumber = ChampionFirstPositiveNumber,
    ChampionReadNumberFromFunctionNames = ChampionReadNumberFromFunctionNames,
    GetChampionSkillIdSafe = GetChampionSkillIdSafe,
    GetChampionAbilityIdSafe = GetChampionAbilityIdSafe,
    CollectObservedChampionSlotIds = CollectObservedChampionSlotIds,
    IsChampionSkillSlottableSafe = IsChampionSkillSlottableSafe,
    BuildChampionSnapshot = BuildChampionSnapshot,
    IsDamageResult = IsDamageResult,
    IsHealResult = IsHealResult,
    IsCriticalResult = IsCriticalResult,
    IsEffectGainedResult = IsEffectGainedResult,
    IsEffectFadedResult = IsEffectFadedResult,
    Clamp = Clamp,
    SortSkillEntries = SortSkillEntries,
    SortSkillEntriesByHeal = SortSkillEntriesByHeal,
    AddTopMoment = AddTopMoment,
    CloneMoments = CloneMoments,
    NewThroughputWindowTracker = NewThroughputWindowTracker,
    CloneThroughputWindowTracker = CloneThroughputWindowTracker,
    AdvanceThroughputWindowTracker = AdvanceThroughputWindowTracker,
    AddThroughputWindowValueByTime = AddThroughputWindowValueByTime,
    NewFight = NewFight,
    GetFightDurationSeconds = GetFightDurationSeconds,
    EstimateTargetResistance = EstimateTargetResistance,
    InferProtectionFromDr = InferProtectionFromDr,
    IsMajorMinorEffectName = IsMajorMinorEffectName,
    MatchPopularSet = MatchPopularSet,
    NormalizeCustomSetScene = NormalizeCustomSetScene,
    BuildCustomAliasList = BuildCustomAliasList,
    ClassifyLikelySetProc = ClassifyLikelySetProc,
    BuildProtectionSummary = BuildProtectionSummary,
    AcquireTrackedEffect = AcquireTrackedEffect,
    StartTrackedEffect = StartTrackedEffect,
    StopTrackedEffect = StopTrackedEffect,
    BuildTrackedEffectList = BuildTrackedEffectList,
    Mean = Mean,
    Median = Median,
    SafeGetCurrentPowerFromList = SafeGetCurrentPowerFromList,
    SafeGetMaxPowerFromList = SafeGetMaxPowerFromList,
    SafeGetPowerPctFromList = SafeGetPowerPctFromList,
    BuildResourceSampleSummary = BuildResourceSampleSummary,
    BuildNumericSampleSummary = BuildNumericSampleSummary,
    SafeGetLatencyMs = SafeGetLatencyMs,
    BuildSustainPerformanceSummary = BuildSustainPerformanceSummary,
    StdDev = StdDev,
    LinearSlope = LinearSlope,
    ExponentialAverage = ExponentialAverage,
}

ConsoleMetrics._shared = shared
for name, value in pairs(shared) do
    if _G[name] == nil then
        _G[name] = value
    end
end

