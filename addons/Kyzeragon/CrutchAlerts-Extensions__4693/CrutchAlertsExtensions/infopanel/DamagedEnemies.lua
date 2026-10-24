local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
-- Data
---------------------------------------------------------------------
local ABILITY_BLACKLIST = {
    [17895] = true, -- Fiery Weapon
    [17897] = true, -- Frozen Weapon
    [17899] = true, -- Charged Weapon
    [17902] = true, -- Poisoned Weapon
    [17904] = true, -- Befouled Weapon
    [46743] = true, -- Absorb Magicka
    [46746] = true, -- Absorb Stamina

    [148797] = true, -- Overcharged
    [148800] = true, -- Sundered
    [215779] = true, -- Diseased
    [21481] = true, -- Chill
    [21487] = true, -- Concussion
    [21925] = true, -- Diseased
}

local PET_ABILITIES = {
    [33219] = "esoui/art/icons/ability_nightblade_001.dds", -- Corrosive Strike
    [108936] = "esoui/art/icons/ability_nightblade_001_a.dds", -- Corrosive Drain
    [51556] = "esoui/art/icons/ability_nightblade_001_b.dds", -- Corrosive Arrow

    [27850] = "esoui/art/icons/ability_sorcerer_unstable_fimiliar_summoned.dds", -- Entropic Touch
    [117255] = "esoui/art/icons/ability_sorcerer_speedy_familiar_summoned.dds", -- Entropic Touch (volatile)
    [29528] = "esoui/art/icons/ability_sorcerer_unstable_clannfear_summoned.dds", -- Unstable Clannfear
    [29529] = "esoui/art/icons/ability_sorcerer_unstable_clannfear_summoned.dds", -- Unstable Clannfear (tail swipe thing)

    -- has 2 different, they're all zaps, but 1 is the kick animation (with zap)
    [28027] = "esoui/art/icons/ability_sorcerer_lightning_prey_summoned.dds", -- Summon Winged Twilight
    [24617] = "esoui/art/icons/ability_sorcerer_lightning_prey_summoned.dds", -- Summon Winged Twilight
    [117273] = "esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds", -- Summon Twilight Tormentor
    [117274] = "esoui/art/icons/ability_sorcerer_lightning_matriarch_summoned.dds", -- Summon Twilight Tormentor
    [117320] = "esoui/art/icons/ability_sorcerer_storm_prey_summoned.dds", -- Summon Twilight Matriarch
    [117321] = "esoui/art/icons/ability_sorcerer_storm_prey_summoned.dds", -- Summon Twilight Matriarch
}

local RESULTS = {
    [ACTION_RESULT_DAMAGE] = "DAMAGE",
    [ACTION_RESULT_CRITICAL_DAMAGE] = "CRITICAL_DAMAGE",
    [ACTION_RESULT_DAMAGE_SHIELDED] = "|cFF0000DAMAGE_SHIELDED|r",
    [ACTION_RESULT_BLOCKED_DAMAGE] = "|cFF0000BLOCKED_DAMAGE|r",
}


---------------------------------------------------------------------
-- Display
---------------------------------------------------------------------
local BOSS_COLOR = "DD0000"
local OTHER_COLOR = "22CCFF"
local CUSTOM_COLORS = {
    ["Enraged Fragment"] = "ff6600",
}

local function GetColor(name, isBoss)
    local color = CUSTOM_COLORS[name]
    if (not color) then
        color = isBoss and BOSS_COLOR or OTHER_COLOR
    end
    return color
end

local function GetIcon(abilityId)
    return PET_ABILITIES[abilityId] or GetAbilityIcon(abilityId)
end


---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local PANEL_HIT_BOSS_INDEX = 100
local PANEL_HIT_OTHER_INDEX = 110

local ALLOWED_TIME = 2000
local LINE_SCALE = 0.7
local LINE_ALPHA = 0.8

--[[
{
    [targetUnitId] = {
        targetName = "asdf",
        bossNum = 2,
        events = {
            [abilityId] = timestamp,
        },
    }
}
]]
local recentDamage = {}

local activeLines = {} -- {[index] = true}
local function OnUpdate()
    -- Clear current. TODO: maybe only hide if needed?
    for index, _ in pairs(activeLines) do
        Crutch.InfoPanel.RemoveLine(index)
        activeLines[index] = nil
    end

    local currTime = GetGameTimeMilliseconds()
    local numActiveLines = 0
    local otherOffset = 1
    -- TODO: does it need to be sorted?
    for targetUnitId, targetData in pairs(recentDamage) do
        local iconSuffix = ""

        -- Collect entries or clear any that are too old
        for abilityId, timestamp in pairs(targetData.events) do
            if (currTime - timestamp > ALLOWED_TIME) then
                targetData[abilityId] = nil -- just remove
            else
                iconSuffix = string.format("%s |t100%%:100%%:%s|t", iconSuffix, GetIcon(abilityId))
            end
        end

        if (iconSuffix ~= "") then
            local customColor = GetColor(targetData.targetName, targetData.bossNum ~= nil)
            local lineText = zo_strformat("|c<<1>><<2>><<3>>|r", customColor, targetData.targetName, iconSuffix)

            local index
            if (targetData.bossNum) then
                index = PANEL_HIT_BOSS_INDEX + targetData.bossNum
            else
                index = PANEL_HIT_OTHER_INDEX + otherOffset
                otherOffset = otherOffset + 1
            end
            Crutch.InfoPanel.SetLine(index, lineText, LINE_SCALE, LINE_ALPHA)
            activeLines[index] = true
            numActiveLines = numActiveLines + 1
        end
    end

    if (numActiveLines > 0) then
        Crutch.InfoPanel.SetLine(PANEL_HIT_BOSS_INDEX, "|cCCCCCCRecent enemies hit:|r", 0.5, LINE_ALPHA)
    else
        Crutch.InfoPanel.RemoveLine(PANEL_HIT_BOSS_INDEX)
    end
end


---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
-- Just to cache boss unit IDs
local bossIds = {}
local function OnEffect(_, _, _, _, unitTag, _, _, _, _, _, _, _, _, _, unitId)
    local bossNum = tonumber(string.sub(unitTag, 5))
    bossIds[unitId] = bossNum

    if (recentDamage[unitId]) then
        recentDamage[unitId].bossNum = bossNum
    end
end

local function OnDamaged(_, result, _, _, _, _, _, _, targetName, targetType, hitValue, _, _, _, _, targetUnitId, abilityId)
    if (targetType == COMBAT_UNIT_TYPE_PLAYER) then return end -- Self damage like carrion
    if (ABILITY_BLACKLIST[abilityId]) then return end

    -- Crutch.dbgSpam(string.format("[%s] %s (%d) -> %s (%d) for %d", RESULTS[result], GetAbilityName(abilityId), abilityId, targetName, targetUnitId, hitValue))

    if (not recentDamage[targetUnitId]) then
        recentDamage[targetUnitId] = {
            targetName = zo_strformat("<<1>>", targetName),
            bossNum = bossIds[targetUnitId],
            events = {},
        }
    end

    recentDamage[targetUnitId].events[abilityId] = GetGameTimeMilliseconds()

    OnUpdate()
end

local function CleanUp()
    ZO_ClearTable(bossIds)
    ZO_ClearTable(recentDamage)
    OnUpdate()
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
local function InitializeDamagedEnemies()
    if (not CAE.profiles[CAE.csvs.currentProfile].damagedEnemies) then return end

    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesDamage", OnDamaged, ACTION_RESULT_DAMAGE, nil, COMBAT_UNIT_TYPE_PLAYER)
    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesDamagePet", OnDamaged, ACTION_RESULT_DAMAGE, nil, COMBAT_UNIT_TYPE_PLAYER_PET)
    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesCritDamage", OnDamaged, ACTION_RESULT_CRITICAL_DAMAGE, nil, COMBAT_UNIT_TYPE_PLAYER)
    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesCritDamagePet", OnDamaged, ACTION_RESULT_CRITICAL_DAMAGE, nil, COMBAT_UNIT_TYPE_PLAYER_PET)
    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesShielded", OnDamaged, ACTION_RESULT_DAMAGE_SHIELDED, nil, COMBAT_UNIT_TYPE_PLAYER) -- TODO: ?
    Crutch.RegisterForCombatEvent("CAEDamagedEnemiesBlocked", OnDamaged, ACTION_RESULT_BLOCKED_DAMAGE, nil, COMBAT_UNIT_TYPE_PLAYER) -- TODO: ?
    Crutch.RegisterForEffectChanged("CAEDamagedEnemiesEffect", OnEffect, nil, "boss")

    Crutch.RegisterUpdateListener("CrutchAlertsExtensionsDamagedEnemies", OnUpdate)

    Crutch.RegisterExitedGroupCombatListener("CrutchAlertsExtensionsDamagedEnemies", CleanUp)
end
CAE.InitializeDamagedEnemies = InitializeDamagedEnemies

local function UnregisterDamagedEnemies()
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesDamage")
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesDamagePet")
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesCritDamage")
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesCritDamagePet")
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesShielded")
    Crutch.UnregisterForCombatEvent("CAEDamagedEnemiesBlocked")
    Crutch.UnregisterForEffectChanged("CAEDamagedEnemiesEffect")

    Crutch.UnregisterUpdateListener("CrutchAlertsExtensionsDamagedEnemies")

    Crutch.UnregisterExitedGroupCombatListener("CrutchAlertsExtensionsDamagedEnemies")
end


---------------------------------------------------------------------
function CAE.GetDamagedEnemiesSettings()
    return {
        {
            type = "description",
            title = "|c08BD1DDamaged Enemies|r",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show recently damaged enemies",
            tooltip = "Uses the Crutch info panel to show enemies you have damaged with direct damage abilities in the last 2 seconds and what you damaged them with (excluding weapon glyph procs). Also lets you easily see what your pets are attacking; pet attacks mostly use their pet icon instead of the ability's icon",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].damagedEnemies end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].damagedEnemies = value
                UnregisterDamagedEnemies()
                InitializeDamagedEnemies()
            end,
            width = "full",
        },
    }
end
