local OBT = OffBalanceTracker

---------------------------------------------------------------------------
-- CALCULATE UPTIME COLOR
---------------------------------------------------------------------------
function OBT.GetPercentageColor(percentage)
    local p = math.max(0, math.min(100, percentage)) / 100
    local r, g = 0, 0

    if p >= 0.75 then
        r, g = (1 - p) / 0.25 * 0.5, 1.0
    elseif p >= 0.50 then
        r, g = 0.5 + (0.75 - p) / 0.25 * 0.5, 1.0
    elseif p >= 0.25 then
        r, g = 1.0, 0.5 + (p - 0.25) / 0.25 * 0.5
    else
        r, g = 1.0, p / 0.25 * 0.5
    end

    OBT.ColorCache[1] = r
    OBT.ColorCache[2] = g
    OBT.ColorCache[3] = 0
    OBT.ColorCache[4] = 1

    return OBT.ColorCache
end

---------------------------------------------------------------------------
-- PLAY SOUND WITH COOLDOWN
---------------------------------------------------------------------------
function OBT.PlaySound(volume)
    if not volume or volume <= 0 then return end

    local currentTime = GetGameTimeMilliseconds()
    if currentTime - OBT.lastSoundPlayedTime < 2000 then return end
    OBT.lastSoundPlayedTime = currentTime

    for i = 1, math.min(10, volume) do
        PlaySound(SOUNDS.DUEL_WON)
    end
end

---------------------------------------------------------------------------
-- SEND CHAT SUMMARY AFTER COMBAT
---------------------------------------------------------------------------
function OBT.SendChatSummary()
    if not OBT.SV.isEnabledChat then return end
    if OBT.timeFightStart == 0 then return end
    if not OBT.hasCombatBoss then return end

    local durationFightMs = GetGameTimeMilliseconds() - OBT.timeFightStart
    local durationFightSec = durationFightMs / 1000

    if durationFightSec < OBT.SV.minFightTime then return end
    local minutes = math.floor(durationFightSec / 60)
    local seconds = math.floor(durationFightSec % 60)
    local formattedTime = string.format("%d:%02dmin", minutes, seconds)

    local r, g, b = unpack(OBT.GetPercentageColor(OBT.uptimePercentage))
    local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)

    d(string.format("%s |cFFFFFFOff Balance Uptime -|r |c%s%.1f%%|r |cFFFFFF- Fight: %s|r", OBT.CHAT, hexColor, OBT.uptimePercentage, formattedTime))
end

---------------------------------------------------------------------------
-- UPDATE VISIBILITY
---------------------------------------------------------------------------
function OBT.UpdateVisibility()
    -- PREVIEW
    if OBT.isForceShow or OBT.isMenuPreview then
        OBT.PARENT:SetHidden(false)
        return
    end

    OBT.groupRole = GetGroupMemberSelectedRole("player")

    local RoleSettings = {
        [0] = OBT.SV.isEnabledSolo,
        [1] = OBT.SV.isEnabledDPS,
        [2] = OBT.SV.isEnabledTank,
        [4] = OBT.SV.isEnabledHeal
    }

    local roleEnabled = OBT.SV.enableAddon and (RoleSettings[OBT.groupRole] == true)
    local isHidden = not (SCENE_MANAGER:GetScene("hud"):IsShowing() or SCENE_MANAGER:GetScene("hudui"):IsShowing())
    local shouldHideCombat = OBT.SV.isOnlyCombat and not OBT.isCombat and not OBT.isHideDelayActive

    if isHidden or not roleEnabled or shouldHideCombat then
        OBT.PARENT:SetHidden(true)
    elseif OBT.SV.isOnlyBosses and not (OBT.isTrackingBoss or OBT.hasCombatBoss) then
        OBT.PARENT:SetHidden(true)
    else
        OBT.PARENT:SetHidden(false)
    end
end

---------------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------------
function OBT.PlayAnimation()
    if OBT.isAnimationActive then return end
    OBT.isAnimationActive = true

    local animationDuration = 500
    local durationGrow = math.floor(animationDuration / 3)
    local durationShrink = animationDuration - durationGrow

    -- CREATE TIMELINE AND ANIMATION IF NOT YET CREATED
    if not OBT.TIMELINE then
        OBT.TIMELINE = ANIMATION_MANAGER:CreateTimeline()

        OBT.ANIMATION_SCALEUP = OBT.TIMELINE:InsertAnimation(ANIMATION_SCALE, OBT.DURATION, 0)
        OBT.ANIMATION_SCALEUP:SetEasingFunction(ZO_EaseInQuadratic)

        OBT.ANIMATION_SCALEDOWN = OBT.TIMELINE:InsertAnimation(ANIMATION_SCALE, OBT.DURATION, 0)
        OBT.ANIMATION_SCALEDOWN:SetEasingFunction(ZO_EaseOutQuadratic)

        -- RESET
        OBT.TIMELINE:SetHandler('OnStop', function()
            OBT.DURATION:SetScale(1.0)
            OBT.isAnimationActive = false
        end)
    end

    -- IF ANIMATION RUNS STOP IT.. PREVENTS CRASHES
    if OBT.TIMELINE:IsPlaying() then OBT.TIMELINE:Stop() end

    -- SET NEW VALS
    OBT.ANIMATION_SCALEUP:SetScaleValues(1.0, 2.0)
    OBT.ANIMATION_SCALEUP:SetDuration(durationGrow)

    OBT.ANIMATION_SCALEDOWN:SetScaleValues(2.0, 1.0)
    OBT.ANIMATION_SCALEDOWN:SetDuration(durationShrink)
    OBT.TIMELINE:SetAnimationOffset(OBT.ANIMATION_SCALEDOWN, durationGrow)

    OBT.TIMELINE:PlayFromStart()
end

---------------------------------------------------------------------------
-- TARGET IS BOSS OR DUMMY?
---------------------------------------------------------------------------
function OBT.IsTargetBossOrDummy(unitTag, unitName)
    if unitTag and string.sub(unitTag, 1, 4) == "boss" then return true end

    local checkTag = unitTag or "reticleover"
    if DoesUnitExist(checkTag) then
        for i = 1, 6 do
            if DoesUnitExist(OBT.BOSS_TAGS[i]) and AreUnitsEqual(checkTag, OBT.BOSS_TAGS[i]) then
                return true
            end
        end
    end

    if DoesUnitExist("reticleover") and IsUnitAttackable("reticleover") then
        local reticleName = GetUnitName("reticleover")
        local maxHealth = select(2, GetUnitPower("reticleover", POWERTYPE_HEALTH))
        local cleanEventName = unitName and string.gsub(unitName, "%^.*", "") or ""
        local cleanReticleName = reticleName and string.gsub(reticleName, "%^.*", "") or ""

        if not unitName or cleanReticleName == cleanEventName then
            if maxHealth and maxHealth >= 20500000 and maxHealth <= 21500000 then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- EFFECT CHANGED
---------------------------------------------------------------------------
function OBT.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceUnitType)
    if effectName ~= OBT.debuffName and effectName ~= OBT.cleanDebuffName and effectName ~= OBT.immuneName and effectName ~= OBT.cleanImmuneName then
        return
    end

    local isOB = (effectName == OBT.debuffName or effectName == OBT.cleanDebuffName)

    -- UPTIME
    if isOB then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            OBT.ActiveOffBalance[unitId] = endTime * 1000
        elseif changeType == EFFECT_RESULT_FADED then
            OBT.ActiveOffBalance[unitId] = nil
        end
    end

    -- BOSS TRACKING
    local isBossEvent = false
    if OBT.KnownBosses[unitId] then
        isBossEvent = true
    elseif OBT.IsTargetBossOrDummy(unitTag, unitName) then
        isBossEvent = true
        OBT.KnownBosses[unitId] = true
    end

    if isBossEvent then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            -- SET STATE
            local state = isOB and 1 or 2
            if not OBT.BossTimers[unitId] then OBT.BossTimers[unitId] = {} end
            OBT.BossTimers[unitId].state = state
            OBT.BossTimers[unitId].endTime = endTime * 1000
        end
    end
end

---------------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------------
function OBT.OnUpdateHandler()
    -- PREVIEW
    if OBT.isForceShow or OBT.isMenuPreview then return end

    local currentTime = GetGameTimeMilliseconds()
    local timeDelta = currentTime - OBT.timeFightUpdate
    OBT.timeFightUpdate = currentTime

    local reticleActive = false
    local reticleState, reticleEndTime, reticleIsBoss = 0, 0, false

    if DoesUnitExist("reticleover") and IsUnitAttackable("reticleover") then
        reticleActive = true
        reticleIsBoss = OBT.IsTargetBossOrDummy("reticleover", nil)

        for i = 1, GetNumBuffs("reticleover") do
            -- GRAB BUFF NAME.. SO NO ID
            local buffName, timeStarted, timeEnding = GetUnitBuffInfo("reticleover", i)

            if buffName == OBT.debuffName or buffName == OBT.cleanDebuffName then
                reticleState = 1; reticleEndTime = timeEnding * 1000; break
            elseif buffName == OBT.immuneName or buffName == OBT.cleanImmuneName then
                reticleState = 2; reticleEndTime = timeEnding * 1000; break
            end
        end
    end

    local memoryIsActiveBoss = (OBT.SV.isBossFocus and OBT.Memory.isBoss)
    OBT.stateCount = OBT.stateCount + 1

    if reticleActive then
        if memoryIsActiveBoss and not reticleIsBoss then
            if OBT.Memory.state == 1 and currentTime >= OBT.Memory.endTime then
                OBT.Memory.state = 2
                OBT.Memory.endTime = OBT.Memory.endTime + 15000
            elseif OBT.Memory.state == 2 and currentTime >= OBT.Memory.endTime then
                OBT.Memory.state = 0
            end
        else
            OBT.Memory.state = reticleState
            OBT.Memory.endTime = reticleEndTime
            OBT.Memory.isBoss = reticleIsBoss
        end
    else
        if OBT.Memory.state == 1 and currentTime >= OBT.Memory.endTime then
            OBT.Memory.state = 2
            OBT.Memory.endTime = OBT.Memory.endTime + 15000
        elseif OBT.Memory.state == 2 and currentTime >= OBT.Memory.endTime then
            OBT.Memory.state = 0
        end
    end

    local activeBossState, activeBossEndTime = 0, 0
    local lockedBossExists = false

    if OBT.SV.isBossFocus then
        for unitId, data in pairs(OBT.BossTimers) do
            lockedBossExists = true

            if currentTime >= data.endTime then
                if data.state == 1 then
                    OBT.BossTimers[unitId].state = 2
                    OBT.BossTimers[unitId].endTime = data.endTime + 15000

                    if activeBossState < 2 then
                        activeBossState = 2
                        activeBossEndTime = OBT.BossTimers[unitId].endTime
                    end
                elseif data.state == 2 then
                    OBT.BossTimers[unitId].state = 0
                end
            else
                if data.state == 1 then
                    activeBossState = 1
                    activeBossEndTime = data.endTime
                elseif data.state == 2 and activeBossState ~= 1 then
                    activeBossState = 2
                    activeBossEndTime = data.endTime
                end
            end
        end
    end

    local dataState, dataEndTime, dataIsBoss = 0, 0, false

    if OBT.SV.isBossFocus then
        if reticleActive and reticleIsBoss then
            dataState = reticleState
            dataEndTime = reticleEndTime
            dataIsBoss = true
        elseif lockedBossExists then
            dataState = activeBossState
            dataEndTime = activeBossEndTime
            dataIsBoss = true
        elseif memoryIsActiveBoss then
            dataState = OBT.Memory.state
            dataEndTime = OBT.Memory.endTime
            dataIsBoss = true
        else
            dataState = OBT.Memory.state
            dataEndTime = OBT.Memory.endTime
            dataIsBoss = OBT.Memory.isBoss
        end
    else
        dataState = OBT.Memory.state
        dataEndTime = OBT.Memory.endTime
        dataIsBoss = OBT.Memory.isBoss
    end

    if currentTime > dataEndTime then
        dataState = 0
        dataEndTime = 0
    end

    if OBT.SV.isOnlyBosses and not dataIsBoss then
        dataState = 0
        dataEndTime = 0
    end

    local remainingTime = math.max(0, dataEndTime - currentTime)

    if dataIsBoss then
        OBT.hasCombatBoss = true
    end

    -- AUDIO NOTIFICATION LOGIC
    local SoundRoleSettings = {
        [0] = OBT.SV.isSoundEnabledSolo,
        [1] = OBT.SV.isSoundEnabledDPS,
        [2] = OBT.SV.isSoundEnabledTank,
        [4] = OBT.SV.isSoundEnabledHeal
    }
    local canPlaySound = SoundRoleSettings[GetGroupMemberSelectedRole("player")] == true

    -- ON OFF BALANCE PROC
    if dataState == 1 and remainingTime > 6500 and remainingTime <= 7000 then
        if OBT.lastAnimatedataEndTime ~= dataEndTime then
            OBT.PlayAnimation()
            OBT.lastAnimatedataEndTime = dataEndTime

            if canPlaySound and OBT.SV.soundTriggerMode == 1 and OBT.SV.volumeSound > 0 then
                OBT.PlaySound(OBT.SV.volumeSound)
            end
        end
    end

    -- ON IMMUNITY FADE
    if dataState == 2 and remainingTime <= 250 and remainingTime > 0 then
        if OBT.lastSoundEndTime ~= dataEndTime then
            OBT.lastSoundEndTime = dataEndTime

            if canPlaySound and OBT.SV.soundTriggerMode == 2 and OBT.SV.volumeSound > 0 then
                OBT.PlaySound(OBT.SV.volumeSound)
            end
        end
    end

    -- START 22SEC TIMER WHEN OB
    if dataState == 1 and OBT.lastDataState ~= 1 then
        OBT.cooldownEndTime = currentTime + 22000
        if OBT.stateCount >= OBT.targetCount then
            OBT.targetCountEndTime = currentTime + 2200
            OBT.targetCount = math.random(2200)
            OBT.stateCount = 0
        end
    end
    OBT.lastDataState = dataState

    -- UPTIME
    if OBT.isCombat then
        local hasGlobalOB = false
        for unitId, expireTime in pairs(OBT.ActiveOffBalance) do
            if currentTime < expireTime then
                hasGlobalOB = true
                break
            else
                OBT.ActiveOffBalance[unitId] = nil -- CLEANUP EXPIRED
            end
        end

        if hasGlobalOB or dataState == 1 then
            OBT.timeState1 = OBT.timeState1 + timeDelta
        end

        local duration = currentTime - OBT.timeFightStart
        if duration > 0 then
            OBT.uptimePercentage = (OBT.timeState1 / duration) * 100
        else
            OBT.uptimePercentage = 0
        end
    end

    OBT.isTrackingBoss = dataIsBoss
    OBT.UpdateVisibility()
    OBT.UpdateVisuals(dataState, remainingTime, dataIsBoss)
end

---------------------------------------------------------------------------
-- COMBAT STATE
---------------------------------------------------------------------------
function OBT.OnCombatState()
    OBT.isCombat = IsUnitInCombat("player")

    if OBT.isForceShow or OBT.isMenuPreview then
        OBT.isForceShow = false
        OBT.isMenuPreview = false
        OBT.uptimePercentage = 0
        if OBT.PARENT then
            OBT.PARENT:SetMovable(not OBT.SV.isLocked)
            OBT.PARENT:SetMouseEnabled(not OBT.SV.isLocked)
        end
    end

    if OBT.isCombat then
        OBT.combatEndId = (OBT.combatEndId or 0) + 1
        OBT.isHideDelayActive = false

        local currentTime = GetGameTimeMilliseconds()
        OBT.timeFightStart = currentTime
        OBT.timeFightUpdate = currentTime
        OBT.timeState1 = 0
        OBT.timeState0 = 0
        OBT.uptimePercentage = 0

        ZO_ClearTable(OBT.ActiveOffBalance)

        OBT.hasCombatBoss = false
        OBT.targetCount = math.random(2200)
        OBT.stateCount = 0

        EVENT_MANAGER:RegisterForUpdate(OBT.NAME .. "Update", OBT.TIME_UPDATE, OBT.OnUpdateHandler)
        OBT.UpdateVisibility()
    else
        OBT.SendChatSummary()
        EVENT_MANAGER:UnregisterForUpdate(OBT.NAME .. "Update")

        local function ResetTrackerState()
            ZO_ClearTable(OBT.BossTimers)
            ZO_ClearTable(OBT.KnownBosses)
            ZO_ClearTable(OBT.ActiveOffBalance)

            OBT.Memory = { state = 0, endTime = 0, isBoss = false }
            OBT.isTrackingBoss = false
            OBT.hasCombatBoss = false
            OBT.targetCountEndTime = 0
            OBT.UpdateVisuals(0, 0, false)
            OBT.UpdateVisibility()
        end

        if OBT.SV.isOnlyCombat and (OBT.SV.combatHideDelay or 0) > 0 then
            OBT.isHideDelayActive = true
            OBT.combatEndId = (OBT.combatEndId or 0) + 1
            local currentEndId = OBT.combatEndId
            OBT.UpdateVisibility()

            zo_callLater(function()
                if currentEndId == OBT.combatEndId and not OBT.isForceShow and not OBT.isMenuPreview then
                    OBT.isHideDelayActive = false
                    ResetTrackerState()
                end
            end, OBT.SV.combatHideDelay * 1000)
        else
            OBT.isHideDelayActive = false
            ResetTrackerState()
        end
    end
end

---------------------------------------------------------------------------
-- HANDLE SCENE STATE CHANGES (HUD/HUDUI)
---------------------------------------------------------------------------
function OBT.OnStateChange(oldState, newState)
    if newState == SCENE_SHOWN then
        OBT.UpdateVisibility()
    elseif newState == SCENE_HIDING then
        if not OBT.isForceShow and not OBT.isMenuPreview then
            OBT.PARENT:SetHidden(true)
        end
    end
end

---------------------------------------------------------------------------
-- ENABLE
---------------------------------------------------------------------------
function OBT.Enable()
    SCENE_MANAGER:GetScene("hud"):RegisterCallback("StateChange", OBT.OnStateChange)
    SCENE_MANAGER:GetScene("hudui"):RegisterCallback("StateChange", OBT.OnStateChange)

    EVENT_MANAGER:RegisterForEvent(OBT.NAME, EVENT_PLAYER_COMBAT_STATE, OBT.OnCombatState)
    EVENT_MANAGER:RegisterForEvent(OBT.NAME, EVENT_EFFECT_CHANGED, OBT.OnEffectChanged)
    EVENT_MANAGER:RegisterForEvent(OBT.NAME, EVENT_GROUP_MEMBER_ROLE_CHANGED, OBT.UpdateVisibility)

    OBT.OnCombatState()
    OBT.UpdateVisibility()
    OBT.UpdateVisuals(0, 0, false)
    OBT.isLoaded = true
end

---------------------------------------------------------------------------
-- DISABLE
---------------------------------------------------------------------------
function OBT.Disable()
    SCENE_MANAGER:GetScene("hud"):UnregisterCallback("StateChange", OBT.OnStateChange)
    SCENE_MANAGER:GetScene("hudui"):UnregisterCallback("StateChange", OBT.OnStateChange)

    EVENT_MANAGER:UnregisterForEvent(OBT.NAME, EVENT_PLAYER_COMBAT_STATE)
    EVENT_MANAGER:UnregisterForEvent(OBT.NAME, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(OBT.NAME, EVENT_GROUP_MEMBER_ROLE_CHANGED)
    EVENT_MANAGER:UnregisterForUpdate(OBT.NAME .. "Update")

    -- CLEANUP
    OBT.PARENT:SetHidden(true)
    ZO_ClearTable(OBT.BossTimers)
    ZO_ClearTable(OBT.KnownBosses)
    ZO_ClearTable(OBT.ActiveOffBalance)
    OBT.targetCountEndTime = 0
    OBT.isLoaded = false
end