local appName = "necroTracker"

--skills covered, 
--sacrificial bones and morphs, flame skull and morphs, boneyard and morphs, shocking siphon and morphs, skeletal mage and morphs, 
--blood embrace, banner bearer with necro class flourish

local isLoaded = false
local BlastbonesSkillId = 117691
local nothingWastedSkillId = 263461
local blastBonesTravelId = 117718
local isMenuOpen = false
local colourStartupText
local colourStartupNumber
local colourSetText
local colourSetNumber
local blastbonesCastTime = nil
local trackBlast = false
--start corpse tracking here
local corpsesAvailable = 0
local trackedCorpses = {}
local nextCorpseId = 0
local lastZoneId = GetZoneId(GetCurrentMapZoneIndex())
--skeletal mage
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
--blastbones
local sacrificialBonesAbilityIds = {
    114863, -- Sacrificial Bones
    117750, -- Grave Lord's Sacrifice
    117691, -- Blighted Blastbones travel effect 117691
}
local sacrificialBonesAbilities = {
    [114863] = true, -- Sacrificial Bones
    [117750] = true, -- Grave Lord's Sacrifice
    [117691] = true, -- Blighted Blastbones travel effect
}
local sacrificialBonesCorpseTracked = false
--flame skull
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
--boneyard
local boneyardAbilityIds = {
    115252, -- Boneyard cast 
    117089, -- Boneyard corpse consumed
    117850, -- Avid Boneyard 
    117853, -- Avid Boneyard corpse consumed
    117805, -- Unnerving Boneyard
    117808, -- Unnerving Boneyard corpse consumed
}
local boneyardCast = false
local boneyardCorpseConfirm = false
local boneyardCorpseCheck = false
--shocking siphon
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
--blood sacrifice
local bloodSacrificeAbilityIds = {
    117888, --blood sacrifice
    117891, --blood sacrifice corpse consumed
}
local bloodSacrificeCast = false
local bloodSacrificeCorpseConsumed = false

--namespace
necroTracker = {}
necroTracker.defaults = {
    trackNecro = true,
    yAxisText = 600,
    xAxisText = 400,
    textColor = { 0.247, 0.129, 1, 1 },--{ 0, 1, 0, 1 } red
    numberColor = { 1, 0.573, 0, 1 }--{ 1, 0, 0, 1 } green
}

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

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    necroText:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if necroTracker.savedVariables.trackNecro then
        necroText:SetHidden(false)
    end
end

--handle UI change when hud opens
local function onSceneStateChange(scene, oldState, newState)
    if isLoaded then
        local sceneName = SCENE_MANAGER:GetCurrentScene():GetName()

        if sceneName == "hud" then
            if  newState == SCENE_HIDING then onMenuOpened()
            elseif  newState == SCENE_HIDDEN then onMenuClosed()
            end
        end
    end
end

--change anchor to move around the screen at app start
local function setAnchorStartup(x, y)  
    necroText:ClearAnchors()
    necroText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchor(x, y)  
    necroText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then necroText:SetHidden(true) end end, 2000)
    necroText:ClearAnchors()
    necroText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--track blastbones timer
local function startBlastbonesTimer()
    blastbonesCastTime = GetGameTimeSeconds()

    EVENT_MANAGER:UnregisterForUpdate("NecroTracker_Blastbones_Update")

    if trackBlast then
        EVENT_MANAGER:RegisterForUpdate("NecroTracker_Blastbones_Update", 100,
            function()
                if not blastbonesCastTime then
                    EVENT_MANAGER:UnregisterForUpdate("NecroTracker_Blastbones_Update")
                    return
                end

                local elapsed = GetGameTimeSeconds() - blastbonesCastTime

                necroTextBlastNum:SetText(string.format("%.1f", elapsed))
            end
        )
    else
        necroTextBlastNum:SetText("Ready")
    end
end

local function stopBlastbonesTimer()
    blastbonesCastTime = nil
    EVENT_MANAGER:UnregisterForUpdate("NecroTracker_Blastbones_Update")
    necroTextBlastNum:SetText("Ready")
end

--handle combat notifications
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(sourceName) then
        return
    end

    if abilityId == BlastbonesSkillId and result == 2240 then
        trackBlast = true
        startBlastbonesTimer()
    end
end

--handle effect changes nothing wasted
local function effectReportNW(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    if abilityID == nothingWastedSkillId then
        if changeType == 1 then
            --display stacks, gained effect
            necroTextWasteNum:SetText(tostring(stackCount))
        elseif changeType == 2 then
            --stop tracking clear timer, lost effect
            necroTextWasteNum:SetText("0")
        elseif changeType == 3 then
            --display stacks, effect updated
            necroTextWasteNum:SetText(tostring(stackCount))
        end
    end
end

--handle effect changes blastbones
local function effectReportBB(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    if abilityID == blastBonesTravelId then
            if changeType == 1 then
                --blastbones is running
            elseif changeType == 2 then
                --blastbones has hit and is ready to use
                trackBlast = false
                stopBlastbonesTimer()
            end
    end
end

--register for notifications 
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("effectReport1", EVENT_EFFECT_CHANGED, effectReportNW)
    EVENT_MANAGER:AddFilterForEvent("effectReport1", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, nothingWastedSkillId)

    EVENT_MANAGER:RegisterForEvent("effectReport2", EVENT_EFFECT_CHANGED, effectReportBB)
    EVENT_MANAGER:AddFilterForEvent("effectReport2", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, blastBonesTravelId)

    EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, BlastbonesSkillId)
end

--unregister for notifications
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("effectReport", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("effectReport2", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("combatReport", EVENT_COMBAT_EVENT)
end

--corpse tracking
local function updateCorpseCount()
    necroTextCorpseNum:SetText(tostring(corpsesAvailable))
end

local function removeTrackedCorpse(corpseId, reason)
    local corpse = trackedCorpses[corpseId]
    if not corpse then return false end

    trackedCorpses[corpseId] = nil
    corpsesAvailable = math.max(0, corpsesAvailable - 1)
    updateCorpseCount()

    if reason == "expired" then
        --printMessage("corpse expired: " .. corpse.source .. " -1")
    else
        --printMessage("remove " .. reason .. " -1 (" .. corpse.source .. ")")
    end

    return true
end

local function addTrackedCorpse(lifetime, source)
    nextCorpseId = nextCorpseId + 1
    local corpseId = nextCorpseId

    trackedCorpses[corpseId] = {
        source = source,
        expiresAt = GetGameTimeMilliseconds() + lifetime,
    }

    corpsesAvailable = corpsesAvailable + 1
    updateCorpseCount()
    --printMessage("corpse created: " .. source .. " +1")

    zo_callLater(function()
        removeTrackedCorpse(corpseId, "expired")
    end, lifetime)
end

local function removeSoonestExpiringCorpse(reason)
    local now = GetGameTimeMilliseconds()
    local expiredIds = {}

    for corpseId, corpse in pairs(trackedCorpses) do
        if corpse.expiresAt <= now then
            expiredIds[#expiredIds + 1] = corpseId
        end
    end

    for _, corpseId in ipairs(expiredIds) do
        removeTrackedCorpse(corpseId, "expired")
    end

    local soonestCorpseId
    local soonestExpiration

    for corpseId, corpse in pairs(trackedCorpses) do
        if not soonestExpiration or corpse.expiresAt < soonestExpiration then
            soonestCorpseId = corpseId
            soonestExpiration = corpse.expiresAt
        end
    end

    if soonestCorpseId then
        return removeTrackedCorpse(soonestCorpseId, reason)
    end

    return false
end

--skeletal mage
local function addSkeletalMageCorpse(abilityId)
    local sources = {
        [114317] = "skeletal mage",
        [118726] = "skeletal arcanist",
        [118680] = "skeletal archer",
    }

    addTrackedCorpse(10000, sources[abilityId] or "skeletal mage")
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
                addSkeletalMageCorpse(abilityId)
            end

            skeletalMageSummons[effectSlot] = nil
        end
    end
end

--blastbones
local function addSacrificialBonesCorpse(abilityId)
    local sources = {
        [114863] = "sacrificial bones",
        [117750] = "grave lord's sacrifice",
        [117691] = "blighted blastbones",
    }

    addTrackedCorpse(5000, sources[abilityId] or "sacrificial bones")
end
local function trackSacrificialBones(changeType, abilityId)
    if not sacrificialBonesAbilities[abilityId] then
        return
    end

    if changeType ~= 2 or sacrificialBonesCorpseTracked then
        return
    end

    sacrificialBonesCorpseTracked = true

    zo_callLater(function()
        sacrificialBonesCorpseTracked = false
    end, 300)

    if abilityId == 117691 then
        zo_callLater(function()
            if IsUnitInCombat("player") then
                addSacrificialBonesCorpse(abilityId)
            end
        end, 200)
    else
        if not IsUnitInCombat("player") then
            return
        end

        addSacrificialBonesCorpse(abilityId)
    end
end

--flame skull
local function addFlameSkullCorpse(abilityId)
    local sources = {
        [114131] = "flame skull",
        [117625] = "venom skull",
        [117638] = "ricochet skull",
    }

    addTrackedCorpse(5000, sources[abilityId] or "flame skull")
end
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
            --zo_callLater(function()
                --if IsUnitInCombat("player") then --todo: may be causing a timing issue
                    addFlameSkullCorpse(abilityId)
                --end
            --end, 1000)
        end
    end
end

--banner bearer
local function trackBannerBearer(result, abilityID)
    if result ~= 2240 then return end

    --local timestamp = GetGameTimeMilliseconds()

    if abilityID == 227114 then
        addTrackedCorpse(5000, "banner bearer")
    else
        return
    end
end

--boneyard
local function removeBoneyardCorpse()
    removeSoonestExpiringCorpse("boneyard")
end
local function trackBoneyard(abilityId)
    --boneyard cast
    if (abilityId == 115252 or abilityId == 117850 or abilityId == 117805) and not boneyardCast then
        boneyardCorpseCheck = true
        boneyardCast = true

        zo_callLater(function()
            if not boneyardCorpseCheck then
                if corpsesAvailable > 0 then
                    removeBoneyardCorpse()
                end
            end
            zo_callLater(function() boneyardCast = false boneyardCorpseConfirm = false end, 300)
        end, 400)

    --corpse consumption confirmed
    elseif (abilityId == 117089 or abilityId == 117853 or abilityId == 117808) and not boneyardCorpseConfirm then
        boneyardCorpseCheck = false
        boneyardCorpseConfirm = true
    end
end

--shocking siphon
local function removeShockingSiphonCorpse()
    removeSoonestExpiringCorpse("shocking siphon")
end
local function trackShockingSiphon(result, abilityId)
    
    if checkingSiphon then
        return
    end

    if not shockingSiphonAbilities[abilityId] then
        return
    end

    if result ~= 2240 then
        return
    end

    if corpsesAvailable > 0 then
        removeShockingSiphonCorpse()
    end

    checkingSiphon = true

    zo_callLater(function()
        checkingSiphon = false
    end, 500)
end

--blood sacrifice
local function removeBloodSacrifice()
    removeSoonestExpiringCorpse("blood sacrifice")
end

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
            removeBloodSacrifice()
        end
    end
end

--handle effect events for corpses
local function effectReport2(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType,
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    --if not cast by player, return
    local nameTmp = GetUnitName("player")
    if nameTmp ~= cleanName(unitName) then
        return
    end

    --skeltal mage and morphs
    if abilityID == 114317 or abilityID == 118726 or abilityID == 118680 then
        trackSkeletalMage(changeType, effectSlot, abilityID)
    --sacrificial bones and morphs    
    elseif abilityID == 114863 or abilityID == 117750 or abilityID == 117691 then
        trackSacrificialBones(changeType, abilityID)
    --flame skull and morphs
    elseif abilityID == 114131 or abilityID == 117625 or abilityID == 117638 then
        trackFlameSkull(changeType, abilityID, stackCount)
    end
end

--handle combat events for corpses
local function combatReport2(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityID, overflow)

    --if error return
    if isError then
        return
    end

    --if not player cast skill return
    local nameTmp = GetUnitName("player")
    if nameTmp ~= cleanName(sourceName) then
        return
    end

    --boneyard, morphs and corpse consumption
    if abilityID == 115252 or abilityID == 117850 or abilityID == 117805 or abilityID == 117089  or abilityID == 117853 or abilityID == 117808 then
        trackBoneyard(abilityID)
    --shocking siphon and morphs  
    elseif abilityID == 116445 or abilityID == 118764 or abilityID == 118009 then
        trackShockingSiphon(result, abilityID)
    --track banner bearer corpse creation and consumption
    elseif abilityID == 227114 then
        trackBannerBearer(result, abilityID)
    --blood scarifice
    elseif abilityID == 117888 or abilityID == 117891 then
        trackBloodSacrifice(abilityID)
    end
end

--reset corpse count
local function resetCorpseCount()
    for corpseId in pairs(trackedCorpses) do
        trackedCorpses[corpseId] = nil
    end

    corpsesAvailable = 0
    updateCorpseCount()
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
    if not inCombat then
        resetCorpseCount()--add loop here to constantly check for 0 corpses
    end
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Necro Tracker",
        displayName = "Necro Tracker",
        author = "codewarrior82",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            title = "Add-On Settings",
            width = "full",
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Track Buffs",
            tooltip = "Displays a tracker for Blighted Blastbones, Nothing Wasted and how many Corpses are available.",
            getFunc = function()
                return necroTracker.savedVariables.trackNecro
            end,
            setFunc = function(value)
                necroTracker.savedVariables.trackNecro = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = necroTracker.defaults.trackNecro,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen text.",
            min = 0, max = 2200, step = 10,
            getFunc = function()
                return necroTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                necroTracker.savedVariables.xAxisText = value
                setAnchor(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)
            end,
            default = necroTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen text.",
            min = 0, max = 1200, step = 10,
            getFunc = function()
                return necroTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                necroTracker.savedVariables.yAxisText = value
                setAnchor(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)
            end,
            default = necroTracker.defaults.yAxisText,
        },
        {
            type = "colorpicker",
            name = "Text colour",
            tooltip = "Change the colour of the notification text.",
            default = ZO_ColorDef:New(unpack(necroTracker.defaults.textColor)),
            getFunc = function ()
                return unpack(necroTracker.savedVariables.textColor)
            end,
            setFunc = function (r, g, b, a)
                necroTracker.savedVariables.textColor = { r, g, b, a }
                colourSetText = ZO_ColorDef:New(unpack(necroTracker.savedVariables.textColor))
                necroTextBlast:SetColor(colourSetText:UnpackRGBA())
                necroTextWaste:SetColor(colourSetText:UnpackRGBA())
                necroTextCorpse:SetColor(colourSetText:UnpackRGBA())
                --printMessage("text colour: " .. colourSetText:ToHex())
                --printMessage("text colour: { " .. r .. ", " .. g .. ", " .. b .. ", " .. a .. " }")
            end,
        },
        {
            type = "colorpicker",
            name = "Number colour",
            tooltip = "Change the colour of the notification numbers.",
            default = ZO_ColorDef:New(unpack(necroTracker.defaults.numberColor)),
            getFunc = function ()
                return unpack(necroTracker.savedVariables.numberColor)
            end,
            setFunc = function (r, g, b, a)
                necroTracker.savedVariables.numberColor = { r, g, b, a }
                colourSetNumber = ZO_ColorDef:New(unpack(necroTracker.savedVariables.numberColor))
                necroTextBlastNum:SetColor(colourSetNumber:UnpackRGBA())
                necroTextWasteNum:SetColor(colourSetNumber:UnpackRGBA())
                necroTextCorpseNum:SetColor(colourSetNumber:UnpackRGBA())
                --printMessage("num colour: " .. colourSetNumber:ToHex())
                --printMessage("num colour: { " .. r .. ", " .. g .. ", " .. b .. ", " .. a .. " }")
            end,
        },
        {
            type = "button",
            name = "Test Colour",
            tooltip = "Show a short notification with the new colour you have set.",
            func = function()
                necroText:SetHidden(false)
                zo_callLater(function () if isMenuOpen == true then necroText:SetHidden(true) end end, 2000)
             end,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Necro Tracker", panelData)
    LAM:RegisterOptionControls("Necro Tracker", optionsData)
end

--add-on loaded
local function libLoaded(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then return end
    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    necroTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("necroTrackerSaveVars", 1, "Settings", necroTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    colourStartupText = ZO_ColorDef:New(unpack(necroTracker.savedVariables.textColor))
    colourStartupNumber = ZO_ColorDef:New(unpack(necroTracker.savedVariables.numberColor))

    --setup text fields
    necroText:SetMovable(true)

    necroTextBlast:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextBlast:SetText("Blastbones: ")
    necroTextBlast:SetColor(colourStartupText:UnpackRGBA())

    necroTextWaste:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextWaste:SetText("Nothing Wasted: ")
    necroTextWaste:SetColor(colourStartupText:UnpackRGBA())

    necroTextCorpse:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextCorpse:SetText("Corpses: ")
    necroTextCorpse:SetColor(colourStartupText:UnpackRGBA())

    necroTextBlastNum:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextBlastNum:SetText("Ready")
    necroTextBlastNum:SetColor(colourStartupNumber:UnpackRGBA())

    necroTextWasteNum:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextWasteNum:SetText("0")
    necroTextWasteNum:SetColor(colourStartupNumber:UnpackRGBA())

    necroTextCorpseNum:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    necroTextCorpseNum:SetText("0")
    necroTextCorpseNum:SetColor(colourStartupNumber:UnpackRGBA())

    setAnchorStartup(necroTracker.savedVariables.xAxisText, necroTracker.savedVariables.yAxisText)

    if necroTracker.savedVariables.trackNecro then
        zo_callLater(function() printMessage("add-on loaded") end, 400)
        necroText:SetHidden(false)
        registerAlerts()
    else
        necroText:SetHidden(true)
    end

    --register for skeletal mage and morphs effect events
    for _, abilityId in ipairs(skeletalMageAbilityIds) do
        local eventName = "NecroTrackerSkeletalMage" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for sacrificial bones and morphs effect events
    for _, abilityId in ipairs(sacrificialBonesAbilityIds) do
        local eventName = "NecroTrackerSacrificialBones" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for flame skull and morphs effect events
    for _, abilityId in ipairs(flameSkullAbilityIds) do
        local eventName = "NecroTrackerFlameSkull" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, effectReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for boneyard, morphs and corpse consumption combat events
    for _, abilityId in ipairs(boneyardAbilityIds) do
        local eventName = "NecroTrackerBoneyard" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, combatReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for shocking siphon and morphs effect events
    for _, abilityId in ipairs(shockingSiphonAbilityIds) do
        local eventName = "NecroTrackerShockingSiphon" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, combatReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for blood sacrifice combat events
    for _, abilityId in ipairs(bloodSacrificeAbilityIds) do
        local eventName = "NecroTrackerBloodSacrifice" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, combatReport2)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    --register for banner bearer notifications 
    EVENT_MANAGER:RegisterForEvent("NecroTrackerBannerBearer227114", EVENT_COMBAT_EVENT, combatReport2)
    EVENT_MANAGER:AddFilterForEvent("NecroTrackerBannerBearer227114", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 227114)--banner bearer corpse creation event, abilityId

    --register for in/out combat notifications
    EVENT_MANAGER:RegisterForEvent( "NecroTrackerCombatReset", EVENT_PLAYER_COMBAT_STATE, onCombatStateChanged)

    --register for player loading in notifications
    EVENT_MANAGER:RegisterForEvent("NecroTrackerResetOnActivation", EVENT_PLAYER_ACTIVATED, onPlayerActivated)

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, libLoaded)