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
    if not str then return "" end--todo: add this to other add-ons
    return str:sub(1, -4)
end

---------------------------------start corpse creation
-----------------------------------------------------------------------------------------------------start bone armor
local boneArmorAbilityIds = {
    115206, -- Bone Armor
    118237, -- Beckoning Armor
    118244, -- Summoner's Armor
}

local boneArmorAbilities = {
    [115206] = true, -- Bone Armor
    [118237] = true, -- Beckoning Armor
    [118244] = true, -- Summoner's Armor
}

local BONE_ARMOR_COOLDOWN = 10000
local lastBoneArmorCorpseTime = nil

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

    -- Enforce the 10-second corpse-generation cooldown.
    if lastBoneArmorCorpseTime
        and now - lastBoneArmorCorpseTime < BONE_ARMOR_COOLDOWN then
        return
    end

    lastBoneArmorCorpseTime = now

    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end
-----------------------------------------------------------------------------------------------------end bone armor


-----------------------------------------------------------------------------------------------------start spirit mender
local spiritGuardianAbilityIds = {
    115710, -- Spirit Mender
    118912, -- Spirit Guardian
    118840, -- Intensive Mender
}

local spiritMenderAbilities = {
    [115710] = true, -- Spirit Mender
    [118912] = true, -- Spirit Guardian
    [118840] = true, -- Intensive Mender
}

local spiritMenderSummons = {}

local function addSpiritMenderCorpse()
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end

local function trackSpiritMender(changeType, effectSlot, abilityId)
    if not spiritMenderAbilities[abilityId] then
        return
    end

    local now = GetGameTimeMilliseconds()

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
            addSpiritMenderCorpse()
        end

        spiritMenderSummons[effectSlot] = nil
    end
end
-----------------------------------------------------------------------------------------------------end spirit mender


-----------------------------------------------------------------------------------------------------start skeletal mage
local skeletalMageAbilityIds = {
    114317, -- Skeletal Mage
    118726, -- Skeletal Arcanist
    118680, -- Skeletal Archer
}

local skeletalMageAbilities = {
    [114317] = true, -- Skeletal Mage
    [118726] = true, -- Skeletal Arcanist
    [118680] = true, -- Skeletal Archer
}

local SKELETAL_MAGE_MIN_DURATION = 8000

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
local sacrificialBonesAbilityIds = {
    114863, -- Sacrificial Bones
    117750, -- Grave Lord's Sacrifice
    117718, -- Blighted Blastbones travel effect
}

local sacrificialBonesAbilities = {
    [114863] = true, -- Sacrificial Bones
    [117750] = true, -- Grave Lord's Sacrifice
    [117718] = true, -- Blighted Blastbones travel effect
}

local function addSacrificialBonesCorpse()
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
end

local function trackSacrificialBones(changeType, abilityId)
    if not sacrificialBonesAbilities[abilityId] then
        return
    end

    -- Corpse is created when the explosion occurs or Blastbones hits.
    if changeType ~= 2 then
        return
    end

    if abilityId == 117718 then
        -- Delay only Blighted Blastbones to allow combat state to update.
        zo_callLater(function()
            if IsUnitInCombat("player") then
                addSacrificialBonesCorpse()
            end
        end, 200)
    else
        -- Other skills check combat immediately.
        if not IsUnitInCombat("player") then
            return
        end

        addSacrificialBonesCorpse()
    end
end
-----------------------------------------------------------------------------------------------------end sacrificial bones


-----------------------------------------------------------------------------------------------------start flame skull
local flameSkullAbilityIds = {
    114131, -- Flame Skull
    117625, -- Venom Skull
    117638, -- Ricochet Skull
}

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
                --    printMessage("Flame Skull corpse counted")
                --else
                --    printMessage("Flame Skull proc: still out of combat")
                end
            end, 1000)
        end
    end
end
-----------------------------------------------------------------------------------------------------end flame skull


-----------------------------------------------------------------------------------------------------start ghostly embrace
local function trackGhostlyEmbrace()
    trackingEmbrace = true
    corpsesAvailable = corpsesAvailable + 1
    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
    zo_callLater(function () trackingEmbrace = false end, 1000)
end
-----------------------------------------------------------------------------------------------------end ghostly embrace


-----------------------------------------------------------------------------------------------------start veil's forfeit
local function trackVeilsForfeit(changeType, unitTag)
    if changeType == 1 then
        corpsesAvailable = corpsesAvailable + 1
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
    end
end
-----------------------------------------------------------------------------------------------------end veil's forfeit
---------------------------------end corpse creation




---------------------------------start corpse consumption
-----------------------------------------------------------------------------------------------------start boneyard
local boneyardAbilityIds = {
    115252, -- Boneyard cast
    117089, -- Boneyard corpse consumed
    117850, -- Avid Boneyard 
    117805, -- Unnerving Boneyard
}

local boneyardCast = false
local boneyardCorpseConfirm = false
local boneyardCorpseCheck = false

local function trackBoneyard(abilityId)

    --boneyard cast
    if (abilityId == 115252 or abilityId == 117850 or abilityId == 117805) and not boneyardCast then
        boneyardCorpseCheck = true
        boneyardCast = true

        zo_callLater(function()
            if not boneyardCorpseCheck then
                if corpsesAvailable > 0 then
                    corpsesAvailable = corpsesAvailable - 1
                    libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
                end
            end
            zo_callLater(function() boneyardCast = false boneyardCorpseConfirm = false end, 300)
        end, 400)

    --corpse consumption confirmed
    elseif abilityId == 117089 and not boneyardCorpseConfirm then
        boneyardCorpseCheck = false
        boneyardCorpseConfirm = true
    end
end
-----------------------------------------------------------------------------------------------------end boneyard


-----------------------------------------------------------------------------------------------------start shocking siphon
local shockingSiphonAbilityIds = {
    116445, -- Shocking Siphon
    118764, -- Detonating Siphon
    118009, -- Mystic Siphon
}

local shockingSiphonAbilities = {
    [116445] = true, -- Shocking Siphon
    [118764] = true, -- Detonating Siphon
    [118009] = true, -- Mystic Siphon
}

local checkingSiphon = false

local function trackShockingSiphon(changeType, abilityId)
    if checkingSiphon then
        return
    end

    if not shockingSiphonAbilities[abilityId] then
        return
    end

    if changeType ~= 1 then
        return
    end

    if corpsesAvailable > 0 then
        corpsesAvailable = corpsesAvailable - 1
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
    end

    checkingSiphon = true

    zo_callLater(function()
        checkingSiphon = false
    end, 500)
end
-----------------------------------------------------------------------------------------------------end shocking siphon


-----------------------------------------------------------------------------------------------------start restoring tether
local restoringTetherAbilityIds = {
    116450, -- Restoring Tether
    118071, -- Braided Tether
    118123, -- Mortal Coil
}

local restoringTetherAbilities = {
    [116450] = true, -- Restoring Tether
    [118071] = true, -- Braided Tether
    [118123] = true, -- Mortal Coil
}

local checkingTether = false

local function trackRestoringTether(changeType, abilityId)
    if checkingTether then
        return
    end

    if not restoringTetherAbilities[abilityId] then
        return
    end

    if changeType ~= 1 then
        return
    end

    if corpsesAvailable > 0 then
        corpsesAvailable = corpsesAvailable - 1
        libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
    end

    checkingTether = true

    zo_callLater(function()
        checkingTether = false
    end, 500)
end
-----------------------------------------------------------------------------------------------------end restoring tether


-----------------------------------------------------------------------------------------------------start blood sacrifice
local bloodSacrificeAbilityIds = {
    117888, --blood sacrifice
    117891, --blood sacrifice corpse consumed
}

local bloodSacrificeCast = false
local bloodSacrificeCorpseConsumed = false

local function trackBloodSacrifice(abilityId)

    --blood sacrifice cast
    if abilityId == 117888 then
        bloodSacrificeCast = true
        bloodSacrificeCorpseConsumed = false

        zo_callLater(function()
            bloodSacrificeCast = false
            bloodSacrificeCorpseConsumed = false
        end, 500)

    --blood sacrifice corpse consumed
    elseif abilityId == 117891 and bloodSacrificeCast and not bloodSacrificeCorpseConsumed then
        bloodSacrificeCorpseConsumed = true

        if corpsesAvailable > 0 then
            corpsesAvailable = corpsesAvailable - 1
            libTrackTextLabelMain:SetText("Corpses: " .. corpsesAvailable)
        end
    end
end
-----------------------------------------------------------------------------------------------------end blood sacrifice











---------------------------------end corpse consumption

--handle effect events
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")
    if nameTmp ~= cleanName(unitName) then
        return
    end

    --spirit mender and morphs
    if abilityID == 115710 or abilityID == 118912 or abilityID == 118840 then
        trackSpiritMender(changeType, effectSlot, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --bone armor and morphs
    elseif abilityID == 115206 or abilityID == 118237 or abilityID == 118244 then
        trackBoneArmor(changeType, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --skeltal mage and morphs
    elseif abilityID == 114317 or abilityID == 118726 or abilityID == 118680 then
        trackSkeletalMage(changeType, effectSlot, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --sacrificial bones and morphs    
    elseif abilityID == 114863 or abilityID == 117750 or abilityID == 117718 then
        trackSacrificialBones(changeType, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --flame skull and morphs
    elseif abilityID == 114131 or abilityID == 117625 or abilityID == 117638 then
        trackFlameSkull(changeType, abilityID, stackCount) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --veil's forfeit
    elseif abilityID == 263555 then
        trackVeilsForfeit(changeType) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --shocking Siphon and morphs
    elseif abilityID == 116445 or abilityID == 118764 or abilityID == 118009 then
        trackShockingSiphon(changeType, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    --restoring Tether and morphs
    elseif abilityID == 116450 or abilityID == 118071 or abilityID == 118123 then
        trackRestoringTether(changeType, abilityID) printMessage("unitName: " .. tostring(unitName) .. "unitTag: " .. tostring(unitTag) .. "effectName: " .. tostring(effectName))
    end


    --printMessage("effectReport")
    --printMessage("abilityID: " .. tostring(abilityID) .. " effectName: " .. tostring(effectName))


--[[
    --EVENT_EFFECT_CHANGED: changeType, effectName, unitTag, and abilityID
    if tostring(effectName) == "Detonating Siphon" or tostring(effectName) == "Mystic Siphon" 
    or tostring(effectName) == "Braided Tether" or tostring(effectName) == "Mortal Coil" then
    printMessage("effectReport")
    printMessage("abilityID: " .. tostring(abilityID) .. " effectName: " .. tostring(effectName) .. " changeType: " .. tostring(changeType))
    end
]]


    --if tostring(effectName) == "Skeletal Mage" or tostring(effectName) == "Skeletal Mage Summon" then
        --printMessage("effectReport")
        --printMessage("abilityID: " .. tostring(abilityID) .. " effectName: " .. tostring(effectName))
    --end

--[[
    if tostring(effectName) == "Skeletal Mage Summon" then
        printMessage(string.format(
        "effectReport | changeType=%s | effectName=%s | unitTag=%s | stackCount=%s | buffType=%s | effectType=%s | abilityID=%s | abilityType=%s | statusEffectType=%s | unitName=%s | unitID=%s",
            tostring(changeType), tostring(effectName), tostring(unitTag), tostring(stackCount), tostring(buffType),tostring(effectType),tostring(abilityID),
            tostring(abilityType), tostring(statusEffectType), tostring(unitName), tostring(unitID)))
        printMessage("")
    end
]]

end

--handle combat events
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityID, overflow)

    --if error return
    if isError then
        return
    end

    --if tostring(abilityName) == "Blood Sacrifice" then
    --printMessage("combatReport")
    --printMessage("abilityID: " .. tostring(abilityID) .. " abilityName: " .. tostring(abilityName) .. " sourceName: " .. tostring(sourceName))
    --end

    --if not player cast skill return
    local nameTmp = GetUnitName("player")
    if nameTmp ~= cleanName(sourceName) then
        return
    end

    --ghostly embrace 3rd hit
    if abilityID == 143946 and not trackingEmbrace then
        trackGhostlyEmbrace()
    --boneyard, morphs and corpse consumption
    elseif abilityID == 115252 or abilityID == 117850 or abilityID == 117805 or abilityID == 117089 then
        trackBoneyard(abilityID)
    --blood scarifice
    elseif abilityID == 117888 or abilityID == 117891 then
        trackBloodSacrifice(abilityID)
    end



    --if tostring(abilityName) == "Skeletal Mage" or tostring(abilityName) == "Skeletal Mage Summon" then
        --printMessage("combatReport")
        --printMessage("abilityID: " .. tostring(abilityID) .. " abilityName: " .. tostring(abilityName))
    --end


    --[[
    if abilityID == 117089 then
        local msg = string.format(
            "combatReport | Event: %s | Result: %s | Ability: %s | AbilityID: %s | Source: %s | Target: %s | HitValue: %s | PowerType: %s | DamageType: %s | SourceID: %s | TargetID: %s",
            tostring(eventCode), tostring(result), tostring(abilityName), tostring(abilityID), tostring(sourceName), tostring(targetName),
            tostring(hitValue), tostring(powerType), tostring(damageType), tostring(sourceUnitId), tostring(targetUnitId))
        printMessage(msg)
        printMessage("")
    end

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

--reset corpse tracking after login, /reloadui, or zone loading
local function onPlayerActivated(eventCode, initial)

    --reset counters
    resetCorpseCount()

    --reset flame skull if zone change
    local currentZoneId = GetZoneId(GetCurrentMapZoneIndex())
    if currentZoneId ~= lastZoneId then
        resetFlameSkullTracking()
        lastZoneId = currentZoneId
    end
end

--reset corpse tracking when combat ends
local function onCombatStateChanged(eventCode, inCombat)
    if not inCombat then--todo: sometimes corpse count will not reset if corpse is created outside of combat ?
        resetCorpseCount()
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

    --register for boneyard, morphs and corpse consumption combat events
    for _, abilityId in ipairs(boneyardAbilityIds) do
        local eventName = "NecroTrackerBoneyard" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, combatReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for shocking siphon and morphs effect events
    for _, abilityId in ipairs(shockingSiphonAbilityIds) do
        local eventName = "NecroTrackerShockingSiphon" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for restoring tether and morphs effect events
    for _, abilityId in ipairs(restoringTetherAbilityIds) do
        local eventName = "NecroTrackerRestoringTether" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for blood sacrifice combat events
    for _, abilityId in ipairs(bloodSacrificeAbilityIds) do
        local eventName = "NecroTrackerBloodSacrifice" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, combatReport)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
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
    --EVENT_MANAGER:AddFilterForEvent("effectReport2", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 115924)
    --EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    --EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 114322)

end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)