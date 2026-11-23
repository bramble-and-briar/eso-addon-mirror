local AH = _G.MarkTrialHelper
local tomeName = GetString(_G.MARKTRIALHELPER_TOMESHELL):lower()
local lastStun = 0
local lastMapId = 0
local sourceIds = {}

local function onSelectorHiding()
    if (AH.Notice) then
        AH.Release("Notice")
    end

    if (AH.QuestReminder) then
        AH.Release("QuestReminder")
    end

    zo_callLater(
        function()
            AH.ShowingBuffs = false
            CALLBACK_MANAGER:FireCallbacks("MarkTrialHelperBuffSelectorClosing")
        end,
        1500
    )
end

local function encode(abilityId, count)
    return tonumber(string.format("%d%06d%d", AH.SHARE.ABILITY, abilityId, count))
end

local function onChoiceCommitted()
    if (AH.SelectedBuff) then
        local avatar = AH.IsAvatar(AH.SelectedBuff)

        if (avatar) then
            AH.Vars.AvatarVisionCount[avatar] = AH.Vars.AvatarVisionCount[avatar] + 1

            if (AH.Vars.AvatarVisionCount[avatar] == 4) then
                AH.Vars.AvatarVisionCount[avatar] = 0
            end
        end

        local selected = AH.SelectedBuff

        zo_callLater(
            function()
                local abilityInfo = AH.ABILITIES[selected]
                local abilityType = abilityInfo.type or AH.TYPES.VERSE
                local count

                if (avatar) then
                    count = AH.Vars.AvatarVisionCount[avatar] or 0
                else
                    local counts = ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(abilityType)
                    count = counts[selected] or 0
                end

                AH.GroupChat(encode(selected, count))
                AH.ShareData(AH.SHARE.ABILITY, selected, nil, count)
                CALLBACK_MANAGER:FireCallbacks("MarkTrialHelperBuffSelectionCommitted")
            end,
            500
        )

        AH.SelectedBuff = nil
    end
end

local function checkNotice()
    local message = nil
    local stageCounter, cycleCounter = ENDLESS_DUNGEON_MANAGER:GetProgression()
    local stageTarget, cycleTarget = 2, 5

    if (AH.IsInUnknown()) then
        stageTarget = 3
    end

    if (stageCounter == stageTarget and cycleCounter ~= cycleTarget) then
        message = AH.LC.Format(_G.MARKTRIALHELPER_CYCLE_BOSS)
    elseif (cycleCounter == cycleTarget and stageCounter == stageTarget) then
        message = AH.LC.Format(_G.MARKTRIALHELPER_ARC_BOSS)
    end

    if (message and AH.Vars.ShowNotice) then
        AH.ShowNotice(message)
    end

    AH.ShowQuestReminder()
end

local function onShowing()
    AH.OnBuffSelectorShowing()
    AH.ShowingBuffs = true
    checkNotice()
    CALLBACK_MANAGER:FireCallbacks("MarkTrialHelperBuffSelectorShowing")
end

local function onSelecting(_, buffControl)
    AH.SelectedBuff = GetEndlessDungeonBuffSelectorBucketTypeChoice(buffControl.bucketType)
end

local function onCompassUpdate()
    if (AH.InsideArchive and AH.Vars.CheckQuestItems and AH.InCombet) then
        if (AH.FoundQuestItem == false) then
            local numPins = COMPASS.container:GetNumCenterOveredPins()

            if (numPins > 0) then
                for pin = 1, numPins do
                    local pinType = COMPASS.container:GetCenterOveredPinType(pin)
                    if (pinType == _G.MAP_PIN_TYPE_QUEST_INTERACT) then
                        AH.FoundQuestItem = true
                    end
                end
            end
        end
    end
end

local tomesFound = 0
local tomesTotal = 0

local function tomeCheck(...)
    local result = select(2, ...)
    local sourceName, _, targetName = select(7, ...)

    if (result == _G.ACTION_RESULT_DIED or result == _G.ACTION_RESULT_DIED_XP) then
        targetName = AH.LC.Format(targetName):lower()
        sourceName = AH.LC.Format(sourceName):lower()

        if (targetName:find(tomeName, 1, true) or sourceName:find(tomeName, 1, true)) then
            tomesFound = tomesFound + 1
            tomesTotal = tomesTotal + 1
            AH.PlayAlarm(AH.Sounds.Tomeshell)

            if (AH.TomeGroupType ~= _G.ENDLESS_DUNGEON_GROUP_TYPE_SOLO) then
                AH.ShareData(AH.SHARE.TOME, tomesFound, true)
            end

            local tomesLeft = AH.MaxTomes - tomesTotal

            tomesLeft = (tomesLeft < 0) and 0 or tomesLeft

            local message = ZO_CachedStrFormat(_G.MARKTRIALHELPER_TOMESHELL_COUNT, tomesLeft)

            if (AH.TomeCount) then
                AH.TomeCount:SetText(message)
            end
            CALLBACK_MANAGER:FireCallbacks("MarkTrialHelperTomeshellKilled")
        end
    end
end

local function getMaxTomes()
    -- for the purposes of this check, players with companions count as solo
    AH.TomeGroupType = AH.GetActualGroupType()
    if (AH.TomeGroupType == _G.ENDLESS_DUNGEON_GROUP_TYPE_SOLO) then
        return AH.Tomeshells.Solo
    else
        return AH.Tomeshells.Duo
    end
end

local function startTomeCheck()
    AH.MaxTomes = getMaxTomes()

    local message = ZO_CachedStrFormat(_G.MARKTRIALHELPER_TOMESHELL_COUNT, AH.MaxTomes)

    AH.ShowTomeshellCount()
    AH.TomeCount:SetText(message)

    EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Tome", _G.EVENT_COMBAT_EVENT, tomeCheck)
end

local function stopTomeCheck()
    if (AH.TomeCount) then
        AH.TomeCount:SetHidden(true)
        AH.Release("TomeCount")
    end

    EVENT_MANAGER:UnregisterForEvent(AH.Name .. "_Tome", _G.EVENT_COMBAT_EVENT)
end

local function checkSharing()
    AH.ShareData(AH.SHARE.SHARING, 1)
end

local function zoneCheck()
    local mapId = GetCurrentMapId()

    if (mapId == AH.MAPS.ECHOING_DEN.id) then
        checkSharing()
        AH.IsInEchoingDen = true
        AH.DenStarted = true
        AH.ShowTimer()
    elseif (mapId == AH.MAPS.TREACHEROUS_CROSSING.id) then
        checkSharing()
        AH.IsInCrossing = true

        if (AH.Vars.ShowHelper) then
            AH.ShowCrossingHelper()
        end
    elseif (mapId == AH.MAPS.THEATRE_OF_WAR.id) then
        AH.IsInTheatre = true

        if (AH.Vars.Theatre) then
            AH.SetTheatreWarning(true)
        end
    else
        AH.IsInEchoingDen = false
        AH.DenStarted = false
        AH.IsInCrossing = false
        AH.IsInTheatre = false

        if (AH.Timer) then
            AH.HideTimer()
        end

        if (AH.CrossingHelperFrame) then
            AH.HideCrossingHelper()
        end
    end
end

local function onPlayerActivated()
    local mapId = GetCurrentMapId()

    if (lastMapId ~= mapId) then
        lastMapId = mapId

        if (AH.Vars.ShowTimer or AH.Vars.ShowHelper) then
            zoneCheck()
        end

        if (AH.Vars.CountTomes and mapId == AH.MAPS.FILERS_WING.id) then
            AH.IsInFilersWing = true
        else
            AH.IsInFilersWing = false

            if (AH.TomeCount) then
                stopTomeCheck()
            end
        end
    end

    AH.GetActualGroupType()
end

local function auditorCheck()
    if (not IsInstanceEndlessDungeon()) then
        return
    end

    if (AH.Vars.Auditor and IsCollectibleUsable(AH.AUDITOR, GAMEPLAY_ACTOR_CATEGORY_PLAYER) and (not IsUnitInCombat("player")) and not AH.IsInUnknown()) then
        if (not AH.IsAuditorActive()) then
            local cooldown = GetCollectibleCooldownAndDuration(AH.AUDITOR)

            if (cooldown == 0) then
                UseCollectible(AH.AUDITOR, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
            end
        end
    end
end

local function checkMessage(messageParams)
    if (not IsInstanceEndlessDungeon()) then
        return
    end

    if (not AH.DenStarted) then
        onPlayerActivated()
    end

    -- Herd the Ghost Lights
    if (AH.IsInEchoingDen) then
        local message = AH.LC.Format(messageParams:GetMainText()):lower()
        local secondaryMessage = AH.LC.Format(messageParams:GetSecondaryText() or ""):lower()
        local start = AH.LC.Format(_G.MARKTRIALHELPER_HERD):lower()
        local fail = AH.LC.Format(_G.MARKTRIALHELPER_HERD_FAIL):lower()
        local success = AH.LC.Format(_G.MARKTRIALHELPER_HERD_SUCCESS):lower()

        if (message:find(start, 1, true)) then
            AH.DenDone = false
            AH.StartTimer()
        elseif
            (message:find(fail, 1, true) or message:find(success, 1, true) or secondaryMessage:find(fail, 1, true) or
                secondaryMessage:find(success, 1, true))
        then
            AH.StopTimer()
            AH.DenDone = true
        end
    end

    -- Treacherous Crossing
    if (AH.IsInCrossing) then
        local message = AH.LC.Format(messageParams:GetMainText()):lower()
        local secondaryMessage = AH.LC.Format(messageParams:GetSecondaryText() or ""):lower()
        local fail = AH.LC.Format(_G.MARKTRIALHELPER_CROSSING_FAIL):lower()
        local success = AH.LC.Format(_G.MARKTRIALHELPER_CROSSING_SUCCESS):lower()

        if
            (message:find(fail, 1, true) or message:find(success, 1, true) or secondaryMessage:find(fail, 1, true) or
                secondaryMessage:find(success, 1, true))
        then
            AH.HideCrossingHelper()
        end
    end

    -- check for loyal auditor
    auditorCheck()
end

local function onMessage(_, messageParams)
    if (not messageParams) then
        return
    end

    if (AH.Vars.ShowTimer) then
        checkMessage(messageParams)
    end

    return false
end

local function resetValues()
    ZO_ClearNumericallyIndexedTable(AH.bosses)
    ZO_ClearNumericallyIndexedTable(sourceIds)
    AH.FoundQuestItem = false
    AH.InsideArchive = IsInstanceEndlessDungeon() and (GetCurrentMapId() ~= AH.ArchiveIndex)
    ZO_ClearNumericallyIndexedTable(AH.Shards)
    tomesFound = 0
    tomesTotal = 0

    for _, info in pairs(AH.MARKERS) do
        info.manual = false
    end

    if (AH.InsideArchive) then
        AH.SetTerrainWarnings(AH.Vars.TerrainWarnings)
    end
end

-- minimise false zone change detections
local function onStunned(_, stunned)
    if (stunned and not IsUnitInCombat("player")) then
        local now = GetTimeStamp()

        if ((now - lastStun) > 2) then
            zo_callLater(
                function()
                    if (not AH.ShowingBuffs) then
                        resetValues()
                    end
                end,
                1000
            )
            lastStun = now
        end
    end
end

local function onReincarnated()
    auditorCheck()
end

local function onResurrected(_, _, result, displayName)
    if (displayName == GetUnitDisplayName("player")) then
        if (result == RESURRECT_RESULT_SUCCESS) then
            auditorCheck()
        end
    end
end

local function onDungeonInitialised()
    local visionCount = ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(ENDLESS_DUNGEON_BUFF_TYPE_VISION)

    AH.Vars.AvatarVisionCount = { ICE = 0, WOLF = 0, IRON = 0, UNDEAD = 0 }

    if (visionCount) then
        for avatar, data in pairs(AH.AVATAR) do
            for _, abilityId in ipairs(data.abilityIds) do
                if (abilityId ~= data.transform) then
                    local count = visionCount[abilityId] or 0

                    AH.Vars.AvatarVisionCount[avatar] = AH.Vars.AvatarVisionCount[avatar] + count
                end
            end
        end
    end
end

local function onQuestCounterChanged(_, journalIndex)
    local indexes = AH.GetArchiveQuestIndexes(true)

    if (ZO_IsElementInNumericallyIndexedTable(indexes, journalIndex)) then
        AH.FoundQuestItem = false
    end
end

local function onHotBarChange(_, changed, shouldUpdate, category)
    if (AH.IsInFilersWing) then
        if ((category == HOTBAR_CATEGORY_TEMPORARY) and shouldUpdate and changed) then
            checkSharing()
            startTomeCheck()
        end

        if ((category == HOTBAR_CATEGORY_PRIMARY) and changed and not shouldUpdate) then
            stopTomeCheck()
        end
    end
end

local player = GetUnitName("player")

local function getOtherPlayer()
    local groupSize = GetGroupSize()

    if (groupSize == 0) then
        return
    end

    for unit = 1, groupSize do
        local unitTag = string.format("group%d", unit)

        if (IsUnitOnline(unitTag)) then
            local name = GetUnitName(unitTag)

            if (name ~= player) then
                return name, unitTag
            end
        end
    end
end

local function onCrossingChange(selections)
    if (AH.CrossingHelperFrame) then
        if (not AH.IsLeader) then
            local values = {}

            -- convert the text to an array
            selections:gsub(
                ".",
                function(c)
                    table.insert(values, c)
                end
            )

            local box1, box2, box3 = tonumber(values[1]), tonumber(values[2]), tonumber(values[3])

            AH.CrossingHelperFrame.box1.SetSelected(box1 == 0 and 7 or box1)
            AH.CrossingHelperFrame.box2.SetSelected(box2 == 0 and 7 or box2)
            AH.CrossingHelperFrame.box3.SetSelected(box3 == 0 and 7 or box3)
            AH.selectedBox[1] = box1
            AH.selectedBox[2] = box2
            AH.CrossingUpdate(3, box3, true)
        end
    end
end

local function onLeaderUpdate()
    if (AH.CrossingHelperFrame) then
        if (not AH.CrossingHelperFrame:IsHidden()) then
            AH.SetDisableCombos()
        end
    end
end

local function onSingleSlotUpdate(_, _, previousSlotData)
    if (previousSlotData) then
        local icon = previousSlotData.iconFile

        for _, iconname in pairs(AH.MYSTERY) do
            if (icon:find(iconname)) then
                AH.MysteryVerse = true
                return
            end
        end

        AH.MysteryVerse = false
    end
end

local function onBuffStackCountChanged(_, abilityId)
    zo_callLater(
        function()
            if (AH.MysteryVerse) then
                AH.GroupChat(encode(abilityId, 999))
                AH.ShareData(AH.SHARE.ABILITY, abilityId, nil, 999)
                CALLBACK_MANAGER:FireCallbacks("MarkTrialHelperMysteryVerse")
                AH.MysteryVerse = false
            end
        end,
        1000
    )
end

AH.Detected = nil
AH.Triggered = false

local function warnNow(abilityId, message)
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_MAJOR_TEXT)
    local colour = AH.LC.White

    if (not message) then
        colour = (abilityId > 200000) and AH.LC.Cyan or AH.LC.Red
        messageParams:SetText(colour:Colorize(ZO_CachedStrFormat("<<C:1>>", AH.Detected) .. "!"))
    else
        messageParams:SetText(colour:Colorize(ZO_CachedStrFormat("<<C:1>>", GetAbilityName(abilityId, "player")) .. "!"))
    end

    messageParams:SetSound(AH.Sounds.Terrain.sound)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST)
    messageParams:MarkShowImmediately()

    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local arcane, seeking

-- Theatre of War
-- interrupt - SI_BINDING_NAME_SPECIAL_MOVE_INTERRUPT
-- local function theatreWarnings(...)
--     local source = select(7, ...)
--     local powerType = select(12, ...)
--     local abilityId = select(17, ...)

--     if (arcane[abilityId]) then
--         -- shard of chaos
--         d("shard!: " .. abilityId)
--     elseif (seeking[abilityId]) then
--         -- Aramril's sustained attack
--         d("Aramril!: " .. abilityId)
--     elseif (powerType == POWERTYPE_HEALTH and GetUnitName("boss1") == source) then
--         local health = GetUnitHealth("boss1")

--         d("boss health: " .. health)

--         if (health % 25 == 0) then
--             d("teleport: " .. health)
--         end
--     end
-- end

function AH.SetTheatreWarning(enable)
    --     if (not arcane) then
    --         arcane = AH.LC.BuildList(AH.ARCANE_BARRAGE)
    --         seeking = AH.LC.BuildList(AH.SEEKING_RUNESCRAWL)
    --     end

    --     if (enable) then
    --         EVENT_MANAGER:RegisterForEvent(
    --             AH.Name .. "theatre",
    --             EVENT_COMBAT_EVENT,
    --             function(...)
    --                 if (AH.IsInTheatre) then
    --                     theatreWarnings(...)
    --                 end
    --             end
    --         )
    --     end
end

local terrainList

local playerName = ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName("player"))

local function terrainWarnings(...)
    local targetName = ZO_CachedStrFormat(SI_UNIT_NAME, select(9, ...))
    local abilityId = select(17, ...)

    if (not AH.InsideArchive) then
        AH.InsideArchive = IsInstanceEndlessDungeon() and (GetCurrentMapId() ~= AH.ArchiveIndex)
    end

    if (AH.InsideArchive and (not AH.Triggered)) then
        if (targetName == playerName) then
            if (terrainList[abilityId]) then
                AH.Detected = GetAbilityName(abilityId, "player")
            else
                AH.Detected = nil
            end

            if (AH.Detected and (not AH.Triggered)) then
                AH.Triggered = true
                warnNow(abilityId)
                zo_callLater(
                    function()
                        AH.Triggered = false
                        AH.Detected = nil
                    end,
                    1000
                )
            end
        end
    end
end

function AH.SetTerrainWarnings(enable)
    if (enable) then
        EVENT_MANAGER:RegisterForEvent(
            AH.Name .. "terrain",
            EVENT_COMBAT_EVENT,
            function(...)
                if (AH.InsideArchive) then
                    terrainWarnings(...)
                end
            end
        )
        EVENT_MANAGER:AddFilterForEvent(
            AH.Name .. "terrain",
            EVENT_COMBAT_EVENT,
            REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,
            COMBAT_UNIT_TYPE_PLAYER
        )

        if (not terrainList) then
            terrainList = AH.LC.BuildList(AH.TERRAIN)
        end
    else
        EVENT_MANAGER:UnregisterForEvent(AH.Name .. "terrain", EVENT_COMBAT_EVENT)
    end
end

function AH.ShareData(shareType, value, instant, stackCount)
    if ((not AH.Share) and (not AH.DEBUG)) then
        return
    end

    local encoded

    if (stackCount) then
        encoded = encode(value, stackCount)
    else
        encoded = string.format("%s%s", shareType, value)
    end

    encoded = tonumber(encoded)

    if (AH.Share) then
        if (instant) then
            AH.Share:SendData(encoded)
        else
            AH.Share:QueueData(encoded)
        end
    end

    AH.Debug("Shared: " .. encoded)
end

function AH.HandleDataShare(_, info)
    local shareType = tonumber(tostring(info):sub(1, 1))
    local shareData = tonumber(tostring(info):sub(2))

    if (not AH.TomeCount) then
        AH.ShowTomeshellCount()
    end

    if (not AH.MaxTomes) then
        AH.MaxTomes = getMaxTomes()
    end

    if (shareType == AH.SHARE.TOME) then
        tomesTotal = (tomesFound or 0) + (shareData or 0)

        local tomesLeft = AH.MaxTomes - tomesTotal

        tomesLeft = (tomesLeft < 0) and 0 or tomesLeft

        local message = ZO_CachedStrFormat(_G.MARKTRIALHELPER_TOMESHELL_COUNT, tomesLeft)

        if (AH.TomeCount) then
            AH.TomeCount:SetText(message)
            AH.PlayAlarm(AH.Sounds.Tomeshell)
            AH.Debug("Received tome data: " .. shareData)
        end
    elseif (shareType == AH.SHARE.MARK) then
        if (shareData and (shareData > 0) and (shareData < 8)) then
            AH.MARKERS[shareData].used = true
            AH.MARKERS[shareData].manual = true
            AH.Debug("Received mark data: " .. shareData)
        end
    elseif (shareType == AH.SHARE.UNMARK) then
        if (shareData and (shareData > 0) and (shareData < 8)) then
            AH.MARKERS[shareData].manual = false
            AH.Debug("Received unmark data: " .. shareData)
        end
    elseif (shareType == AH.SHARE.GW) then
        if (shareData and (shareData > 0) and (not AH.FOUND_GW)) then
            if (AH.Vars.GwPlay) then
                AH.PlayAlarm(AH.Sounds.Gw)
            end
            AH.FOUND_GW = true
            AH.Debug("Received Gw detection")
        end
    elseif (shareType == AH.SHARE.ABILITY) then
        if (shareData) then
            local data = tostring(info)

            if (data:len() > 7) then
                local name, unitTag = getOtherPlayer()

                AH.GroupChat(data, name, unitTag)
            end

            AH.Debug("Received ability data: " .. shareData)
        end
    elseif (shareType == AH.SHARE.CROSSING) then
        onCrossingChange(tostring(info):sub(2))
        AH.Debug("Received crossing data: " .. tostring(info):sub(2))
    elseif (shareType == AH.SHARE.SHARING) then
        AH.AH_SHARING = true
        AH.Debug("Received sharing notification")
    end
end

-- ============================================
-- ОБРАБОТЧИК МЕХАНИК (КАК В IAHelper)
-- ============================================
local function MechanicsEventHandler(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    -- Pillars of Nirn
    if abilityId == 202632 then
        AH.ShowPillarsOfNirn()
    -- Soul Cage
    elseif abilityId == 222919 then
        AH.ShowSoulCage()
    -- Meteor
    elseif abilityId == 211976 then
        AH.ShowMeteor()
    -- Abyss
    elseif abilityId == 223135 then
        AH.ShowAbyss()
    -- Totem (Mage Totem)
    elseif abilityId == 210599 or abilityId == 210561 then
        AH.ShowTotem()
    -- Scamp (Gw the Pilferer)
    elseif abilityId == 200060 then
        AH.ShowScamp()
    -- Scamp Escape
    elseif abilityId == 200067 then
        AH.ShowScampEscape()
    -- Negate
    elseif abilityId == 196806 then
        AH.ShowNegate()
    -- Inferno
    elseif abilityId == 210483 then
        AH.ShowInferno()
    end
end

function AH.SetupHooks()
    SecurePostHook(_G[AH.SELECTOR], "OnHiding", onSelectorHiding)
    SecurePostHook(_G[AH.SELECTOR], "CommitChoice", onChoiceCommitted)
    SecurePostHook(_G[AH.SELECTOR], "OnShowing", onShowing)
    SecurePostHook(_G[AH.SELECTOR], "SelectBuff", onSelecting)
    SecurePostHook(COMPASS, "OnUpdate", onCompassUpdate)
    SecurePostHook(CENTER_SCREEN_ANNOUNCE, "AddMessageWithParams", onMessage)
    ZO_PreHook(BOSS_BAR, "AddBoss", AH.OnNewBoss)
end

function AH.SetupEvents()
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ACHIEVEMENT_UPDATED, AH.FindMissingAbilityIds)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ACHIEVEMENT_AWARDED, AH.FindMissingAbilityIds)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ENDLESS_DUNGEON_INITIALIZED, onDungeonInitialised)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, onQuestCounterChanged)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_PLAYER_STUNNED_STATE_CHANGED, onStunned)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, onHotBarChange)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_LEADER_UPDATE, onLeaderUpdate)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_PLAYER_REINCARNATED, onReincarnated)
    EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_RESURRECT_RESULT, onResurrected)
    
    -- Опасные атаки (таймеры)
    EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Danger", EVENT_COMBAT_EVENT, AH.DangerCombatEventHandler)
    
    -- Механики (Pillars, Soul Cage, Meteor, Abyss, Totem, Scamp, Negate, Inferno)
    EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Mechanics", EVENT_COMBAT_EVENT, MechanicsEventHandler)
    
    -- Ослабление
    EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Weakening", EVENT_EFFECT_CHANGED, AH.OnWeakeningEffect)
    EVENT_MANAGER:AddFilterForEvent(AH.Name .. "_Weakening", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 17945)
    
    -- Спавн врагов
    EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Spawn", EVENT_EFFECT_CHANGED, AH.OnSpawn)
    EVENT_MANAGER:AddFilterForEvent(AH.Name .. "_Spawn", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 211130)

    if (AH.Vars.FabledCheck and AH.CompatibilityCheck()) then
        EVENT_MANAGER:RegisterForEvent(AH.Name .. "_Fabled", EVENT_PLAYER_COMBAT_STATE, AH.CombatCheck)
    end

    if (AH.Vars.AutoCheck) then
        AH.UpdateSlottedSkills()
        EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, AH.UpdateSlottedSkills)
    end

    if (AH.Vars.TerrainWarnings) then
        AH.SetTerrainWarnings(true)
    end

    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", onSingleSlotUpdate)
    ENDLESS_DUNGEON_MANAGER:RegisterCallback("BuffStackCountChanged", onBuffStackCountChanged)
end