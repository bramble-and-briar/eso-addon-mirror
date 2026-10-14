local appName = "LibTrack"
local corpsesAvailable = 0

LibTrack = {}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end


-----------------------------------------------------------------------------------------------------start bone armor
local boneArmorAbilityIds = { 115206, 118237, 118244 }

local boneArmorAbilities = {
    [115206] = true, -- Bone Armor
    [118237] = true, -- Beckoning Armor
    [118244] = true, -- Summoner's Armor
}

local BONE_ARMOR_COOLDOWN = 10000
local BONE_ARMOR_CORPSE_LIFETIME = 10000

local lastBoneArmorCorpseTime = nil
local boneArmorCorpses = {}

local function expireBoneArmorCorpses(now)
    for i = #boneArmorCorpses, 1, -1 do
        if now - boneArmorCorpses[i] >= BONE_ARMOR_CORPSE_LIFETIME then
            table.remove(boneArmorCorpses, i)
            corpsesAvailable = math.max(0, corpsesAvailable - 1)
            --printMessage("Bone Armor corpse expired")
        end
    end
end

local function trackBoneArmor(changeType, abilityId)
    if not boneArmorAbilities[abilityId] then
        return
    end

    -- Only process the initial gained event.
    if changeType ~= EFFECT_RESULT_GAINED then
        return
    end

    -- Must be in combat when the skill is cast.
    if not IsUnitInCombat("player") then
        return
    end

    local now = GetGameTimeMilliseconds()

    expireBoneArmorCorpses(now)

    -- Enforce the 10-second corpse-generation cooldown.
    if lastBoneArmorCorpseTime
        and now - lastBoneArmorCorpseTime < BONE_ARMOR_COOLDOWN then
        return
    end

    lastBoneArmorCorpseTime = now
    table.insert(boneArmorCorpses, now)

    corpsesAvailable = corpsesAvailable + 1

    --printMessage("Bone Armor corpse counted")
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end
-----------------------------------------------------------------------------------------------------end bone armor


-----------------------------------------------------------------------------------------------------start spirit mender
local spiritGuardianAbilityIds = { 115710, 118912, 118840 }

local spiritMenderAbilities = {
    [115710] = true, -- Spirit Mender
    [118912] = true, -- Spirit Guardian
    [118840] = true, -- Intensive Mender
}

local spiritMenderSummons = {}
local spiritMenderCorpses = {}

local SPIRIT_MENDER_CORPSE_LIFETIME = 10000
local SPIRIT_MENDER_MAX_CORPSES = 2

local function expireSpiritMenderCorpses(now)
    for i = #spiritMenderCorpses, 1, -1 do
        if now - spiritMenderCorpses[i] >= SPIRIT_MENDER_CORPSE_LIFETIME then
            table.remove(spiritMenderCorpses, i)

            corpsesAvailable = math.max(0, corpsesAvailable - 1)
            --printMessage("Spirit Mender corpse expired")
            libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        end
    end
end

local function addSpiritMenderCorpse(now)
    expireSpiritMenderCorpses(now)

    if #spiritMenderCorpses >= SPIRIT_MENDER_MAX_CORPSES then
        --printMessage("Spirit Mender corpse limit reached")
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        return
    end

    table.insert(spiritMenderCorpses, now)
    corpsesAvailable = corpsesAvailable + 1
    --printMessage("Spirit Mender corpse counted")
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end

local function trackSpiritMender(changeType, effectSlot, abilityId)
    if not spiritMenderAbilities[abilityId] then
        return
    end

    local now = GetGameTimeMilliseconds()
    expireSpiritMenderCorpses(now)

    if changeType == EFFECT_RESULT_GAINED then
        local threshold = 8000

        if abilityId == 118840 then
            threshold = 4000
        end

        spiritMenderSummons[effectSlot] = {
            spawnTime = now,
            threshold = threshold,
        }

    elseif changeType == EFFECT_RESULT_FADED then
        local summon = spiritMenderSummons[effectSlot]

        if not summon then
            return
        end

        local elapsed = now - summon.spawnTime

        if elapsed >= summon.threshold then
            addSpiritMenderCorpse(now)
        else
            --printMessage("Spirit Mender ended before corpse threshold")
            libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        end

        spiritMenderSummons[effectSlot] = nil
    end
end
-----------------------------------------------------------------------------------------------------end spirit mender


-----------------------------------------------------------------------------------------------------start skeletal mage
local skeletalMageAbilityIds = { 114317, 118726, 118680 }

local skeletalMageAbilities = {
    [114317] = true, -- Skeletal Mage
    [118726] = true, -- Skeletal Arcanist
    [118680] = true, -- Skeletal Archer
}

local SKELETAL_MAGE_MIN_DURATION = 10000
local SKELETAL_MAGE_CORPSE_LIFETIME = 10000

local skeletalMageSummons = {}
local skeletalMageCorpses = {}

local function expireSkeletalMageCorpses(now)
    for i = #skeletalMageCorpses, 1, -1 do
        if now - skeletalMageCorpses[i] >= SKELETAL_MAGE_CORPSE_LIFETIME then
            table.remove(skeletalMageCorpses, i)
            corpsesAvailable = math.max(0, corpsesAvailable - 1)
        end
    end
end

local function addSkeletalMageCorpse(now)
    table.insert(skeletalMageCorpses, now)
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
    printMessage("Skeletal Mage corpse counted")
end

local function trackSkeletalMage(changeType, effectSlot, abilityId)
    if not skeletalMageAbilities[abilityId] then return end

    local now = GetGameTimeMilliseconds()
    expireSkeletalMageCorpses(now)

    if changeType == EFFECT_RESULT_GAINED then
        skeletalMageSummons[effectSlot] = {
            abilityId = abilityId,
            startTime = now,
        }

    elseif changeType == EFFECT_RESULT_FADED then
        local summon = skeletalMageSummons[effectSlot]

        if summon then
            local duration = now - summon.startTime

            if duration >= SKELETAL_MAGE_MIN_DURATION
                and IsUnitInCombat("player") then
                addSkeletalMageCorpse(now)
            end

            skeletalMageSummons[effectSlot] = nil
        end
    end
end


-----------------------------------------------------------------------------------------------------end skeletal mage























--handle effect events
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    --spirit mender and morphs
    if abilityID == 115710 or abilityID == 118912 or abilityID == 118840 then
        trackSpiritMender(changeType, effectSlot, abilityID)
    --bone armor and morphs
    elseif abilityID == 115206 or abilityID == 118237 or abilityID == 118244 then
        trackBoneArmor(changeType, abilityID)
    --skeltal mage and morphs
    elseif abilityID == 114317 or abilityID == 118726 or abilityID == 118680 then
        trackSkeletalMage(changeType, effectSlot, abilityID)
    end

--[[
    printMessage(string.format(
       "effectReportBB | changeType=%s | effectSlot=%s | effectName=%s | unitTag=%s | beginTime=%s | endTime=%s | stackCount=%s | buffType=%s | effectType=%s | abilityType=%s | statusEffectType=%s | unitName=%s | unitID=%s",
        tostring(changeType), tostring(effectSlot), tostring(effectName), tostring(unitTag), tostring(beginTime),
        tostring(endTime), tostring(stackCount), tostring(buffType),tostring(effectType),
        tostring(abilityType), tostring(statusEffectType), tostring(unitName), tostring(unitID)))

    if changeType == 1 then
        printMessage("Spirit Mender spawned")
    elseif changeType == 2 then
        printMessage("Spirit Mender faded")
    elseif changeType == 3 then
        printMessage("Spirit Mender updated")
    else
        printMessage("changeType unknown")
    end
]]
end






--handle combat events
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    local msg = string.format(
        "combatReport | Event: %s | Result: %s | Ability: %s | AbilityID: %s | Source: %s | Target: %s | HitValue: %s | PowerType: %s | DamageType: %s | SourceID: %s | TargetID: %s",
        tostring(eventCode), tostring(result), tostring(abilityName), tostring(abilityId), tostring(sourceName), tostring(targetName),
        tostring(hitValue), tostring(powerType), tostring(damageType), tostring(sourceUnitId), tostring(targetUnitId))

    printMessage(msg)

end

--reset corpse count
local function resetCorpseCount()
    corpsesAvailable = 0
    libTrackTextLabelMain:SetText("Corpses: 0")
end

--reset corpse tracking
local function resetCorpseTracking()
    --clear Skeletal Mage tracking
    skeletalMageSummons = {}
    skeletalMageCorpses = {}

    --clear Spirit Mender tracking
    spiritMenderSummons = {}
    spiritMenderCorpses = {}

    --clear Bone Armor tracking
    boneArmorCorpses = {}
    lastBoneArmorCorpseTime = nil

    printMessage("Corpse tracking reset")
end

--reset corpse tracking after login, /reloadui, or zone loading
local function onPlayerActivated(eventCode, initial)
    resetCorpseCount()
    resetCorpseTracking()
end

--reset corpse tracking when combat ends
local function onCombatStateChanged(eventCode, inCombat)
    if not inCombat then
        resetCorpseCount()
        resetCorpseTracking()
    end
end

--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    libTrackText:SetMovable(true)
    libTrackTextLabelMain:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")

    libTrackTextLabelMain:SetText("Corpses: 0")

    --register for spirit guardian and morphs effect events
    for _, abilityId in ipairs(spiritGuardianAbilityIds) do
        local eventName = "NecroTrackerSpiritGuardian" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for spirit guardian and morphs effect events
    for _, abilityId in ipairs(boneArmorAbilityIds) do
        local eventName = "NecroTrackerBoneArmor" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for skeletal mage and morphs effect events
    for _, abilityId in ipairs(skeletalMageAbilityIds) do
        local eventName = "NecroTrackerSkeletalMage" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for in / out combat notifications
    EVENT_MANAGER:RegisterForEvent( "NecroTrackerCombatReset", EVENT_PLAYER_COMBAT_STATE, onCombatStateChanged)

    --register for player loading in notifications
    EVENT_MANAGER:RegisterForEvent("NecroTrackerResetOnActivation", EVENT_PLAYER_ACTIVATED, onPlayerActivated)

    --EVENT_MANAGER:RegisterForEvent("effectReport2", EVENT_EFFECT_CHANGED, effectReport)
    --EVENT_MANAGER:AddFilterForEvent("effectReport2", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 114317)
    --EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    --EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 114317)

end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)