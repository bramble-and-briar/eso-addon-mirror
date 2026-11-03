-- ConsoleMetrics_Build.lua
-- Snapshots of the player's current loadout: action bars, equipment, set
-- bonuses, mundus boons, weapon enchants/poisons and role comparison profiles.


---------------------------------------------------------------------------
-- Role comparison profiles
---------------------------------------------------------------------------
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

---------------------------------------------------------------------------
-- Action bars
---------------------------------------------------------------------------
local function GetActionBarSlotBounds()
    -- Console client confirmed layout: skills occupy slots 3-7 and ultimate is slot 8.
    return 3, 8
end

local NON_SKILL_SLOT_PATTERNS = { "heavy%s*attack", "light%s*attack", "^dodge", "^block$", "^bash$" }

local function IsNonSkillSlotName(slotName)
    local lowerName = string.lower(slotName)
    for i = 1, #NON_SKILL_SLOT_PATTERNS do
        if string.find(lowerName, NON_SKILL_SLOT_PATTERNS[i]) ~= nil then
            return true
        end
    end
    return false
end

-- Calls an action-bar API with or without the optional hotbar category.
local function CallSlotApi(fn, slotIndex, hotbarCategory)
    local ok, value
    if hotbarCategory ~= nil then
        ok, value = pcall(fn, slotIndex, hotbarCategory)
    else
        ok, value = pcall(fn, slotIndex)
    end
    if ok then
        return value
    end
    return nil
end

-- Returns abilityName, abilityId for an action bar slot, or nil, nil for empty
-- and non-skill slots (light/heavy attack, dodge, block, bash).
local function SafeGetActionBarSlotName(slotIndex, hotbarCategory)
    local abilityId = nil
    if type(GetSlotBoundId) == "function" then
        local id = CallSlotApi(GetSlotBoundId, slotIndex, hotbarCategory)
        if type(id) == "number" and id > 0 then
            abilityId = id
        end
    end

    local slotName = nil
    if type(GetSlotName) == "function" then
        local name = CallSlotApi(GetSlotName, slotIndex, hotbarCategory)
        if type(name) == "string" and name ~= "" then
            slotName = name
        end
    end
    if not slotName and abilityId and type(GetAbilityName) == "function" then
        local ok, name = pcall(GetAbilityName, abilityId)
        if ok and type(name) == "string" and name ~= "" then
            slotName = name
        end
    end

    if not slotName then
        if abilityId then
            return string.format("Ability %d", abilityId), abilityId
        end
        return nil, nil
    end
    if IsNonSkillSlotName(slotName) then
        return nil, nil
    end
    return slotName, abilityId or 0
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

---------------------------------------------------------------------------
-- Equipment, sets, boons, weapon effects
---------------------------------------------------------------------------
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

                local poisonResults = SafeCallResults(GetItemPairedPoisonInfo, slotInfo.slot)
                poisonText = FindFirstNonEmptyString(poisonResults, skipValues)
                if not poisonText then
                    poisonResults = SafeCallResults(GetItemPoisonInfo, BAG_WORN, slotInfo.slot)
                end
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

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

ConsoleMetrics.Build = {
    BuildActionBarSnapshot = BuildActionBarSnapshot,
    BuildActiveBoonSnapshot = BuildActiveBoonSnapshot,
    BuildEquipmentSlotDefinitions = BuildEquipmentSlotDefinitions,
    BuildEquipmentSnapshot = BuildEquipmentSnapshot,
    BuildEquippedSetSummary = BuildEquippedSetSummary,
    BuildWeaponEffectSnapshot = BuildWeaponEffectSnapshot,
    CallSlotApi = CallSlotApi,
    FindFirstNonEmptyString = FindFirstNonEmptyString,
    GetActionBarSlotBounds = GetActionBarSlotBounds,
    GetSelectedRoleComparisonProfile = GetSelectedRoleComparisonProfile,
    IsNonSkillSlotName = IsNonSkillSlotName,
    MapRoleValueToProfileKey = MapRoleValueToProfileKey,
    NON_SKILL_SLOT_PATTERNS = NON_SKILL_SLOT_PATTERNS,
    ROLE_COMPARISON_PROFILES = ROLE_COMPARISON_PROFILES,
    SafeCallResults = SafeCallResults,
    SafeGetActionBarSlotName = SafeGetActionBarSlotName,
    SafeGetEquippedItemText = SafeGetEquippedItemText,
}
