local appName = "LibTrack"
local corpsesAvailable = 0
local lastZoneId = GetZoneId(GetCurrentMapZoneIndex())
local trackingEmbrace = false

LibTrack = {}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--clean player names
local function cleanName(str)
    if not str then return "" end
    return str:sub(1, -4)
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
    if changeType ~= 1 then
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
            libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        end
    end
end

local function addSpiritMenderCorpse(now)
    expireSpiritMenderCorpses(now)

    if #spiritMenderCorpses >= SPIRIT_MENDER_MAX_CORPSES then
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        return
    end

    table.insert(spiritMenderCorpses, now)
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end

local function trackSpiritMender(changeType, effectSlot, abilityId)
    if not spiritMenderAbilities[abilityId] then
        return
    end

    local now = GetGameTimeMilliseconds()
    expireSpiritMenderCorpses(now)

    if changeType == 1 then
        local threshold = 8000

        if abilityId == 118840 then
            threshold = 4000
        end

        spiritMenderSummons[effectSlot] = {
            spawnTime = now,
            threshold = threshold,
        }

    elseif changeType == 2 then
        local summon = spiritMenderSummons[effectSlot]

        if not summon then
            return
        end

        local elapsed = now - summon.spawnTime

        if elapsed >= summon.threshold then
            addSpiritMenderCorpse(now)
        else
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

local skeletalMageSummons = {}

local function addSkeletalMageCorpse()
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end

local function trackSkeletalMage(changeType, effectSlot, abilityId)
    if not skeletalMageAbilities[abilityId] then return end

    local now = GetGameTimeMilliseconds()

    if changeType == 1 then
        skeletalMageSummons[effectSlot] = {
            abilityId = abilityId,
            startTime = now,
        }

    elseif changeType == 2 then
        local summon = skeletalMageSummons[effectSlot]

        if summon then
            local duration = now - summon.startTime

            if duration >= SKELETAL_MAGE_MIN_DURATION
                and IsUnitInCombat("player") then
                addSkeletalMageCorpse()
            end

            skeletalMageSummons[effectSlot] = nil
        end
    end
end
-----------------------------------------------------------------------------------------------------end skeletal mage


-----------------------------------------------------------------------------------------------------start sacrificial bones
local sacrificialBonesAbilityIds = { 114863, 117750, 117718 }

local sacrificialBonesAbilities = {
    [114863] = true, -- Sacrificial Bones
    [117750] = true, -- Grave Lord's Sacrifice
    [117718] = true, -- Blighted Blastbones travel effect
}

local sacrificialBonesCorpseAvailable = false

local function trackSacrificialBones(changeType, abilityId)
    if not sacrificialBonesAbilities[abilityId] then
        return
    end

    -- Corpse is created when the explosion occurs or Blastbones hits.
    if changeType ~= 2 then
        return
    end

    -- Only count corpses created in combat.
    if not IsUnitInCombat("player") then
        return
    end

    -- A new corpse replaces this group's previous corpse.
    if sacrificialBonesCorpseAvailable then
        return
    end

    sacrificialBonesCorpseAvailable = true
    corpsesAvailable = corpsesAvailable + 1

    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end
-----------------------------------------------------------------------------------------------------end sacrificial bones


-----------------------------------------------------------------------------------------------------start flame skull
local flameSkullAbilityIds = { 114131, 117625, 117638 }

local flameSkullAbilities = {
    [114131] = true, -- Flame Skull
    [117625] = true, -- Venom Skull
    [117638] = true, -- Ricochet Skull
}

local flameSkullCastCount = 0
local venomSkullIgnoreNextChangeType3 = false

local function trackFlameSkull(changeType, abilityId, stackCount)
    if not flameSkullAbilities[abilityId] then return end

    if changeType == 1 then
        flameSkullCastCount = 1
        venomSkullIgnoreNextChangeType3 = false
        return
    end

    if abilityId == 117625 and changeType == 3 then
        if venomSkullIgnoreNextChangeType3 then
            venomSkullIgnoreNextChangeType3 = false
        else
            flameSkullCastCount = flameSkullCastCount + 1
            venomSkullIgnoreNextChangeType3 = true
        end

        if stackCount == 2 then
            flameSkullCastCount = 2
        elseif stackCount == 3 then
            flameSkullCastCount = 3
        end

        return
    end

    if (abilityId == 114131 or abilityId == 117638)
        and changeType == 3 then
        flameSkullCastCount = flameSkullCastCount + 1

        if stackCount == 2 then
            flameSkullCastCount = 2
        end

        return
    end

    if changeType == 2 then
        local thirdCast = false

        if abilityId == 117625 then
            thirdCast =
                (flameSkullCastCount == 3 and stackCount == 3)
                or stackCount == 2
        else
            thirdCast =
                flameSkullCastCount == 2 and stackCount == 2
        end

        flameSkullCastCount = 0
        venomSkullIgnoreNextChangeType3 = false

        if thirdCast then
            zo_callLater(function()
                if IsUnitInCombat("player") then
                    corpsesAvailable = corpsesAvailable + 1
                    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
                    printMessage("Flame Skull corpse counted")
                else
                    printMessage("Flame Skull proc: still out of combat")
                end
            end, 1200)
        end
    end
end
-----------------------------------------------------------------------------------------------------end flame skull


-----------------------------------------------------------------------------------------------------start veil's forfeit
-- Veil's Forfeit
local function trackVeilsForfeit(changeType, unitTag)
    if changeType == 1 and unitTag == "player" then
        corpsesAvailable = corpsesAvailable + 1
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        printMessage("Veil's Forfeit corpse counted")
    end
end
-----------------------------------------------------------------------------------------------------stop veil's forfeit








--handle effect events
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    --add if not player stipulation to not track other players necro skills
    --printMessage("abilityID: " .. tostring(abilityID))
    --printMessage("changeType: " .. tostring(changeType))
    --printMessage("stackCount: " .. tostring(stackCount))

    --spirit mender and morphs
    if abilityID == 115710 or abilityID == 118912 or abilityID == 118840 then
        trackSpiritMender(changeType, effectSlot, abilityID)
    --bone armor and morphs
    elseif abilityID == 115206 or abilityID == 118237 or abilityID == 118244 then
        trackBoneArmor(changeType, abilityID)
    --skeltal mage and morphs
    elseif abilityID == 114317 or abilityID == 118726 or abilityID == 118680 then
        trackSkeletalMage(changeType, effectSlot, abilityID)
    --sacrificial bones and morphs    
    elseif abilityID == 114863 or abilityID == 117750 or abilityID == 117718 then
        trackSacrificialBones(changeType, abilityID)
    --flame skull and morphs
    elseif abilityID == 114131 or abilityID == 117625 or abilityID == 117638 then
        trackFlameSkull(changeType, abilityID, stackCount)
    --veil's forfeit
    elseif abilityID == 263555 then
        trackVeilsForfeit(changeType, unitTag)
    end


--[[
    printMessage(string.format(
       "effectReport | changeType=%s | effectName=%s | unitTag=%s | stackCount=%s | buffType=%s | effectType=%s | abilityID=%s | abilityType=%s | statusEffectType=%s | unitName=%s | unitID=%s",
        tostring(changeType), tostring(effectName), tostring(unitTag), tostring(stackCount), tostring(buffType),tostring(effectType),tostring(abilityID),
        tostring(abilityType), tostring(statusEffectType), tostring(unitName), tostring(unitID)))


]]
end

--handle combat events
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    --if error return
    if isError then
        return
    end

    --if not player cast skill return
    local nameTmp = GetUnitName("player")
    if nameTmp ~= cleanName(sourceName) then
        return
    end

    --if abilityId is ghostly embrace 3rd hit
    if abilityId == 143946 and not trackingEmbrace then
        trackingEmbrace = true
        corpsesAvailable = corpsesAvailable + 1
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        zo_callLater(function () trackingEmbrace = false end, 1000)
    end


--[[

    local msg = string.format(
        "combatReport | Event: %s | Result: %s | Ability: %s | AbilityId: %s | Source: %s | Target: %s | HitValue: %s | PowerType: %s | DamageType: %s | SourceID: %s | TargetID: %s",
        tostring(eventCode), tostring(result), tostring(abilityName), tostring(abilityId), tostring(sourceName), tostring(targetName),
        tostring(hitValue), tostring(powerType), tostring(damageType), tostring(sourceUnitId), tostring(targetUnitId))
    printMessage(msg)

]]
end

--reset corpse count
local function resetCorpseCount()
    corpsesAvailable = 0
    libTrackTextLabelMain:SetText("Corpses: 0")
end

--reset flame,venom and ricochet skull tracking
local function resetFlameSkullTracking()
    flameSkullCastCount = 0
    venomSkullIgnoreNextChangeType3 = false
end

--reset corpse tracking
local function resetCorpseTracking()

    --clear Sacrificial Bones tracking
    sacrificialBonesCorpseAvailable = false

    --clear Skeletal Mage tracking
    skeletalMageSummons = {}

    --clear Spirit Mender tracking
    spiritMenderSummons = {}
    spiritMenderCorpses = {}

    --clear Bone Armor tracking
    boneArmorCorpses = {}
    lastBoneArmorCorpseTime = nil

    --printMessage(tostring(sacrificialBonesCorpseAvailable))
    --printMessage("Corpse tracking reset")
end

--reset corpse tracking after login, /reloadui, or zone loading
local function onPlayerActivated(eventCode, initial)

    --reset counters
    resetCorpseCount()
    resetCorpseTracking()

    --reset flame skull if zone change
    local currentZoneId = GetZoneId(GetCurrentMapZoneIndex())
    if currentZoneId ~= lastZoneId then
        resetFlameSkullTracking()
        lastZoneId = currentZoneId
    end
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

    --register for sacrificial bones and morphs effect events
    for _, abilityId in ipairs(sacrificialBonesAbilityIds) do
        local eventName = "NecroTrackerSacrificialBones" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for flame skull and morphs effect events
    for _, abilityId in ipairs(flameSkullAbilityIds) do
        local eventName = "NecroTrackerFlameSkull" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for ghostly embrace notifications
    EVENT_MANAGER:RegisterForEvent("NecroTrackerGhostlyEmbrace143946", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("NecroTrackerGhostlyEmbrace143946", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 143946)--ghostly embrace, abilityId of 3rd area if it hits target

    --register for veil's forfeit notifications 
    EVENT_MANAGER:RegisterForEvent("NecroTrackerVeilsForfeit263555", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("NecroTrackerVeilsForfeit263555", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 263555)--veil's forfeit, abilityId

    --register for in / out combat notifications
    EVENT_MANAGER:RegisterForEvent( "NecroTrackerCombatReset", EVENT_PLAYER_COMBAT_STATE, onCombatStateChanged)

    --register for player loading in notifications
    EVENT_MANAGER:RegisterForEvent("NecroTrackerResetOnActivation", EVENT_PLAYER_ACTIVATED, onPlayerActivated)





    --EVENT_MANAGER:RegisterForEvent("effectReport2", EVENT_EFFECT_CHANGED, effectReport)
    --EVENT_MANAGER:AddFilterForEvent("effectReport2", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 263555)
    --EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    --EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 143946)

end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)