local AH = _G.EASArchiveHelper
local lastMapId = 0
local tomesFound, tomesTotal = 0, 0
local terrainList
local playerName = ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName("player"))

local function encodeAbility(abilityId,count)
    return tonumber(string.format("%d%06d%d",AH.SHARE.ABILITY,abilityId,count or 0))
end

local function onSelectorHiding()
    if AH.Notice then AH.Release("Notice") end
    if AH.QuestReminder then AH.Release("QuestReminder") end
    zo_callLater(function()
        AH.ShowingBuffs=false
        AH.LastChoiceSignature029748=nil
        CALLBACK_MANAGER:FireCallbacks("ArchiveHelperBuffSelectorClosing")
    end,500)
end

local function onChoiceCommitted()
    local selected=AH.SelectedBuff
    if not selected then return end
    local avatar=AH.IsAvatar(selected)
    if avatar then
        AH.Vars.AvatarVisionCount[avatar]=(AH.Vars.AvatarVisionCount[avatar] or 0)+1
        if AH.Vars.AvatarVisionCount[avatar]>=4 then AH.Vars.AvatarVisionCount[avatar]=0 end
    end
    zo_callLater(function()
        local abilityInfo=AH.ABILITIES[selected]
        if not abilityInfo then return end
        local abilityType=abilityInfo.type or AH.TYPES.VERSE
        local count
        if avatar then count=AH.Vars.AvatarVisionCount[avatar] or 0 else local counts=ENDLESS_DUNGEON_MANAGER:GetAbilityStackCountTable(abilityType) count=counts[selected] or 0 end
        local encoded=encodeAbility(selected,count)
        AH.GroupChat(encoded)
        AH.ShareData(AH.SHARE.ABILITY,selected,nil,count)
        CALLBACK_MANAGER:FireCallbacks("ArchiveHelperBuffSelectionCommitted")
    end,300)
    AH.SelectedBuff=nil
end

local function checkNotice()
    local stage,cycle=ENDLESS_DUNGEON_MANAGER:GetProgression()
    local stageTarget=AH.IsInUnknown() and 3 or 2
    if stage==stageTarget then
        if cycle==5 then AH.ShowNotice(AH.LC.Format(_G.ARCHIVEHELPER_ARC_BOSS)) else AH.ShowNotice(AH.LC.Format(_G.ARCHIVEHELPER_CYCLE_BOSS)) end
    end
    AH.ShowQuestReminder()
end

local function getChoiceSignature029748()
    if not AH.ShowingBuffs then return "" end
    local parts={}
    for bucketType = ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_BEGIN, ENDLESS_DUNGEON_BUFF_BUCKET_TYPE_ITERATION_END do
        local id=tonumber(GetEndlessDungeonBuffSelectorBucketTypeChoice(bucketType)) or 0
        parts[#parts+1]=tostring(id)
    end
    return table.concat(parts,":")
end

local function refreshSelectorDecorations029748(force)
    if not AH.ShowingBuffs then return false end
    local signature=getChoiceSignature029748()
    if not force and signature==AH.LastChoiceSignature029748 then return false end
    AH.LastChoiceSignature029748=signature

    -- Release all old avatar/achievement/favourite/avoid icons before rebuilding.
    -- A Fortune re-roll changes the native choices in-place without reopening the
    -- selector, so OnShowing alone is not enough.
    if AH.OnBuffSelectorShowing then pcall(AH.OnBuffSelectorShowing) end

    -- Re-run the Suite advisor immediately as well so BEST/banner always follows
    -- the newly rolled choices in the same frame.
    local EPC=_G.ESOProgressionCoach
    local IA=EPC and EPC.InfiniteArchiveOverlay
    if IA and type(IA.UpdateArchiveChoiceAdvisor029171)=="function" then
        pcall(IA.UpdateArchiveChoiceAdvisor029171,IA)
    end

    CALLBACK_MANAGER:FireCallbacks("ArchiveHelperBuffChoicesRefreshed029748",signature)
    return true
end

local function onShowing()
    AH.ShowingBuffs=true
    AH.LastChoiceSignature029748=nil
    refreshSelectorDecorations029748(true)
    checkNotice()
    CALLBACK_MANAGER:FireCallbacks("ArchiveHelperBuffSelectorShowing")
end

local function onSelecting(_,buffControl)
    if buffControl and buffControl.bucketType then AH.SelectedBuff=GetEndlessDungeonBuffSelectorBucketTypeChoice(buffControl.bucketType) end
end

local function getMaxTomes()
    return AH.GetActualGroupType()==ENDLESS_DUNGEON_GROUP_TYPE_SOLO and AH.Tomeshells.Solo or AH.Tomeshells.Duo
end

local function stopTomeCheck()
    if AH.TomeCount then AH.Release("TomeCount") end
    EVENT_MANAGER:UnregisterForEvent(AH.Name.."_Tome",EVENT_COMBAT_EVENT)
end

local function tomeCheck(...)
    local result=select(2,...)
    if result~=ACTION_RESULT_DIED and result~=ACTION_RESULT_DIED_XP then return end
    local sourceName=AH.LC.Format(select(7,...)):lower()
    local targetName=AH.LC.Format(select(9,...)):lower()
    local tomeName=AH.LC.Format(_G.ARCHIVEHELPER_TOMESHELL):lower()
    if sourceName:find(tomeName,1,true) or targetName:find(tomeName,1,true) then
        tomesFound=tomesFound+1 tomesTotal=tomesTotal+1
        AH.PlayAlarm(AH.Sounds.Tomeshell)
        if AH.GetActualGroupType()~=ENDLESS_DUNGEON_GROUP_TYPE_SOLO then AH.ShareData(AH.SHARE.TOME,tomesFound,true) end
        AH.MaxTomes=AH.MaxTomes or getMaxTomes()
        if AH.TomeCount then AH.TomeCount:SetText(ZO_CachedStrFormat(_G.ARCHIVEHELPER_TOMESHELL_COUNT,math.max(0,AH.MaxTomes-tomesTotal))) end
        CALLBACK_MANAGER:FireCallbacks("ArchiveHelperTomeshellKilled")
    end
end

local function startTomeCheck()
    AH.MaxTomes=getMaxTomes() AH.ShowTomeshellCount()
    if AH.TomeCount then AH.TomeCount:SetText(ZO_CachedStrFormat(_G.ARCHIVEHELPER_TOMESHELL_COUNT,AH.MaxTomes)) end
    EVENT_MANAGER:UnregisterForEvent(AH.Name.."_Tome",EVENT_COMBAT_EVENT)
    EVENT_MANAGER:RegisterForEvent(AH.Name.."_Tome",EVENT_COMBAT_EVENT,tomeCheck)
end

local function zoneCheck()
    local mapId=GetCurrentMapId()
    AH.IsInEchoingDen=(mapId==AH.MAPS.ECHOING_DEN.id)
    AH.IsInCrossing=(mapId==AH.MAPS.TREACHEROUS_CROSSING.id)
    AH.IsInTheatre=(mapId==AH.MAPS.THEATRE_OF_WAR.id)
    AH.IsInFilersWing=(mapId==AH.MAPS.FILERS_WING.id)
    if AH.IsInEchoingDen and AH.Vars.ShowTimer then AH.ShowTimer() elseif AH.Timer then AH.HideTimer() end
    if AH.IsInCrossing and AH.Vars.ShowHelper then AH.ShowCrossingHelper() elseif AH.CrossingHelperFrame then AH.HideCrossingHelper() end
    if AH.IsInFilersWing and AH.Vars.CountTomes then startTomeCheck() else stopTomeCheck() end
end

local function onPlayerActivated()
    local mapId=GetCurrentMapId()
    AH.InsideArchive=IsInstanceEndlessDungeon() and mapId~=AH.ArchiveIndex
    if mapId~=lastMapId then lastMapId=mapId zoneCheck() end
    AH.GetActualGroupType()
end

local function auditorCheck()
    if not IsInstanceEndlessDungeon() or not AH.Vars.Auditor or IsUnitInCombat("player") or AH.IsInUnknown() then return end
    if IsCollectibleUsable(AH.AUDITOR,GAMEPLAY_ACTOR_CATEGORY_PLAYER) and not AH.IsAuditorActive() then
        local cooldown=GetCollectibleCooldownAndDuration(AH.AUDITOR)
        if cooldown==0 then UseCollectible(AH.AUDITOR,GAMEPLAY_ACTOR_CATEGORY_PLAYER) end
    end
end

local function onCenterMessage(_,messageParams)
    if not messageParams or not IsInstanceEndlessDungeon() then return end
    if AH.IsInEchoingDen then
        local main=AH.LC.Format(messageParams:GetMainText() or ""):lower()
        local secondary=AH.LC.Format(messageParams:GetSecondaryText() or ""):lower()
        local start=AH.LC.Format(_G.ARCHIVEHELPER_HERD):lower()
        local fail=AH.LC.Format(_G.ARCHIVEHELPER_HERD_FAIL):lower()
        local success=AH.LC.Format(_G.ARCHIVEHELPER_HERD_SUCCESS):lower()
        if main:find(start,1,true) then AH.StartTimer()
        elseif main:find(fail,1,true) or main:find(success,1,true) or secondary:find(fail,1,true) or secondary:find(success,1,true) then AH.StopTimer() end
    end
    auditorCheck()
end

local function onQuestCounterChanged()
    if not AH.Vars.CheckQuestItems then return end
    local indexes=AH.GetArchiveQuestIndexes(true)
    AH.FoundQuestItem=#indexes>0 and AH.FoundQuestItem or false
end

local function warnTerrain(abilityId)
    AH.Detected=GetAbilityName(abilityId,"player")
    if not AH.Detected or AH.Detected=="" then return end
    local p=CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_MAJOR_TEXT)
    p:SetText(AH.LC.Red:Colorize(ZO_CachedStrFormat("<<C:1>>",AH.Detected).."!"))
    p:SetSound(AH.Sounds.Terrain.sound) p:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_SYSTEM_BROADCAST) p:MarkShowImmediately()
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(p)
end

local function terrainWarnings(...)
    if not AH.InsideArchive then return end
    local targetName=ZO_CachedStrFormat(SI_UNIT_NAME,select(9,...))
    if targetName~=playerName then return end
    local abilityId=select(17,...)
    if terrainList and terrainList[abilityId] and not AH.Triggered then
        AH.Triggered=true warnTerrain(abilityId) zo_callLater(function() AH.Triggered=false end,1000)
    end
end

function AH.SetTerrainWarnings(enable)
    EVENT_MANAGER:UnregisterForEvent(AH.Name.."terrain",EVENT_COMBAT_EVENT)
    if enable then
        terrainList=terrainList or AH.LC.BuildList(AH.TERRAIN)
        EVENT_MANAGER:RegisterForEvent(AH.Name.."terrain",EVENT_COMBAT_EVENT,terrainWarnings)
        EVENT_MANAGER:AddFilterForEvent(AH.Name.."terrain",EVENT_COMBAT_EVENT,REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
    end
end

function AH.ShareData(shareType,value,instant,stackCount)
    if not AH.Share then return end
    local encoded=stackCount and tonumber(string.format("%s%06d%d",shareType,value,stackCount)) or tonumber(string.format("%s%s",shareType,value))
    if not encoded then return end
    if instant then AH.Share:SendData(encoded) else AH.Share:QueueData(encoded) end
end

function AH.HandleDataShare(_,info)
    local data=tostring(info or "") local shareType=tonumber(data:sub(1,1)) local shareData=tonumber(data:sub(2))
    if shareType==AH.SHARE.TOME then
        AH.MaxTomes=AH.MaxTomes or getMaxTomes() tomesTotal=(tomesFound or 0)+(shareData or 0)
        AH.ShowTomeshellCount() if AH.TomeCount then AH.TomeCount:SetText(ZO_CachedStrFormat(_G.ARCHIVEHELPER_TOMESHELL_COUNT,math.max(0,AH.MaxTomes-tomesTotal))) end
    elseif shareType==AH.SHARE.GW then
        if AH.Vars.GwPlay and not AH.FOUND_GW then AH.PlayAlarm(AH.Sounds.Gw) end AH.FOUND_GW=true
    elseif shareType==AH.SHARE.ABILITY then
        if #data>7 then AH.GroupChat(data) end
    elseif shareType==AH.SHARE.SHARING then AH.AH_SHARING=true end
end

local function onCombatState(_,inCombat)
    AH.CombatCheck(nil,inCombat)
end

function AH.SetupHooks()
    local selector=_G[AH.SELECTOR]
    if not selector then error("Infinite Archive selector not ready") end
    SecurePostHook(selector,"OnHiding",onSelectorHiding)
    SecurePostHook(selector,"CommitChoice",onChoiceCommitted)
    SecurePostHook(selector,"OnShowing",onShowing)
    SecurePostHook(selector,"SelectBuff",onSelecting)
    if CENTER_SCREEN_ANNOUNCE then SecurePostHook(CENTER_SCREEN_ANNOUNCE,"AddMessageWithParams",onCenterMessage) end
    if BOSS_BAR then ZO_PreHook(BOSS_BAR,"AddBoss",AH.OnNewBoss) end
end

function AH.SetupEvents()
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_ACHIEVEMENT_UPDATED,AH.FindMissingAbilityIds)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_ACHIEVEMENT_AWARDED,AH.FindMissingAbilityIds)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_PLAYER_ACTIVATED,onPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_ENDLESS_DUNGEON_INITIALIZED,function()
        AH.InsideArchive=true
        AH.GetActualGroupType()
        zoneCheck()
    end)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_QUEST_CONDITION_COUNTER_CHANGED,onQuestCounterChanged)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_PLAYER_COMBAT_STATE,onCombatState)
    EVENT_MANAGER:RegisterForEvent(AH.Name,EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,AH.UpdateSlottedSkills)

    -- Fortune Vision re-rolls update the choices while the selector remains on
    -- screen. Refresh every helper decoration when ESO says new choices arrived.
    if rawget(_G,"EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_CHOICES_RECEIVED") then
        EVENT_MANAGER:RegisterForEvent(AH.Name.."_Choices029748",EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_CHOICES_RECEIVED,function()
            zo_callLater(function() refreshSelectorDecorations029748(true) end,60)
        end)
    end

    -- Safety poll only runs while the selector is visible. It catches clients
    -- where a Fortune re-roll does not emit the choices-received event.
    EVENT_MANAGER:RegisterForUpdate(AH.Name.."_ChoiceWatch029748",150,function()
        if AH.ShowingBuffs then refreshSelectorDecorations029748(false) end
    end)

    -- Duo can change on reconnect/rejoin without leaving the Archive. Keep group
    -- type, sharing and Duo-specific counters synchronized.
    local function refreshGroup029748()
        local prior=AH.IsDuoMode029748
        AH.GetActualGroupType()
        if AH.IsDuoMode029748 and not prior then
            AH.CheckDataShareLib()
        end
        if AH.ShowingBuffs then refreshSelectorDecorations029748(true) end
    end
    if rawget(_G,"EVENT_GROUP_MEMBER_JOINED") then EVENT_MANAGER:RegisterForEvent(AH.Name.."_GroupJoin029748",EVENT_GROUP_MEMBER_JOINED,refreshGroup029748) end
    if rawget(_G,"EVENT_GROUP_MEMBER_LEFT") then EVENT_MANAGER:RegisterForEvent(AH.Name.."_GroupLeft029748",EVENT_GROUP_MEMBER_LEFT,refreshGroup029748) end
    if rawget(_G,"EVENT_GROUP_UPDATE") then EVENT_MANAGER:RegisterForEvent(AH.Name.."_GroupUpdate029748",EVENT_GROUP_UPDATE,refreshGroup029748) end

    if AH.Vars.TerrainWarnings then AH.SetTerrainWarnings(true) end
    if ENDLESS_DUNGEON_MANAGER then
        ENDLESS_DUNGEON_MANAGER:RegisterCallback("BuffStackCountChanged",function()
            if AH.ShowingBuffs then refreshSelectorDecorations029748(true) end
        end)
    end
    onPlayerActivated()
end
