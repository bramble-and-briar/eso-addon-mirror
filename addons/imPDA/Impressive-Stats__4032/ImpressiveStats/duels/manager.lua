local IMP_STATS_SHARED = IMP_STATS_SHARED

local addon = {}
addon.name = 'IMP_STATS_Duels_MANAGER'

addon.playerData = nil

local Log = IMP_STATS_Logger('DUELS_MANAGER')

local function Close(timems1, timems2, diff)
    if timems1 == nil or timems2 == nil then return error('Time cant be nil') end

    diff = diff or 1000
    Log('Diff: %d, max: %d', math.abs(timems1 - timems2), diff)
    if math.abs(timems1 - timems2) < diff then return true end
end

local function IfFightBelongsToDuel(fight, duel)
    return Close(fight.combatstart, duel.duelStart, 6000)  -- Close(lastDuel.duelEnd, fight.combatend)
end

--#region IMP STATS DUEL
local Duel = {}

function Duel:New(o)
    o = o or {}

    o.timestamp = GetTimeStamp()
    o.duelStart = GetGameTimeMilliseconds()

    setmetatable(o, self)
    self.__index = self

    return o
end

function Duel:AddFightData(fight)
    self.damageDone = fight.damageOutTotal
    self.damageTaken = fight.damageInTotal
    self.healingTaken = fight.healingInTotal
    self.damageShilded = fight.damageInShielded
    self.DPSOut = fight.DPSOut
    self.DPSIn = fight.DPSIn
    self.HPSIn = fight.HPSIn
    self.duration = fight.combattime
end

function Duel:AddResult(duelResult, wasLocalPlayersResult)
    self.duelEnd = GetGameTimeMilliseconds()
    self.result = duelResult
    self.wasLocalPlayersResult = wasLocalPlayersResult
end

function Duel:AddOpponentData(opponentData)
    self.opponent = opponentData
end

function Duel:AddPlayerData(playerData, saveBuild)
    self.player = ZO_ShallowTableCopy(playerData)

    if saveBuild then
        Log('Adding build')

        local success, result = pcall(LibDataPacker.Extra.Build.GetPackedLocalPlayerShortBuild)
        if success then
            self.player.build = result
        else
            local message = ('%s Build for duel was not saved!'):format(os.date("!%Y-%m-%d %H:%M:%SZ"))
            IMP_STATS_SHARED.Errors:AddError('DuelManager', message, result)
        end
    end
end
--#endregion

--#region IMP STATS DUELS
function addon:TryToSaveCurrentDuel()
    Log('Trying to save current duel, result added: %s, fightDataAdded: %s', tostring(self.resultAdded), tostring(self.fightDataAdded))
    if self.resultAdded and self.fightDataAdded then
        self.duels[#self.duels+1] = self.currentDuel
        self.currentDuel = nil
        self.resultAdded = nil
        self.fightDataAdded = nil
        Log('Duel data saved #%d', #self.duels)

        IMP_STATS_Duels_UI:Update()
    end
end

function addon:OnFightSummary(fight)
    Log('Fight summary available')

    if IfFightBelongsToDuel(fight, self.currentDuel) then
        LibCombat:UnregisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, _, addon.name)
        self.currentDuel:AddFightData(fight)
        self.fightDataAdded = true
        Log('Fight data added')
        self:TryToSaveCurrentDuel()
    else
        Log('Fight does not belong to duel, big diference in start times')

        local message = ('%s Big difference between start times'):format(os.date("!%Y-%m-%d %H:%M:%SZ"))
        IMP_STATS_SHARED.Errors:AddError('DuelManager', message)
    end
end

function addon:OnDuelStarted()
    Log('Duel started at %.6f', GetGameTimeSeconds())

    if self.current then
        LibCombat:UnregisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, _, addon.name)
        self.resultAdded = nil
        self.fightDataAdded = nil

        local message = ('%s Looks like previous duel was not saved!'):format(os.date("!%Y-%m-%d %H:%M:%SZ"))
        IMP_STATS_SHARED.Errors:AddError('DuelManager', message)
    end

    self.currentDuel = Duel:New()
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTSUMMARY, function(_, ...) self:OnFightSummary(...) end, addon.name)
end

function addon:OnDuelFinished(duelResult, wasLocalPlayersResult, opponentCharacterName, opponentDisplayName, opponentAlliance, opponentGender, opponentClassId, opponentRaceId)
    Log('Duel finished, saving build enabled: %s', tostring(self.sv.saveBuilds))

    self.currentDuel:AddPlayerData(self.playerData, self.sv.saveBuilds)
    Log('Player data added')

    self.currentDuel:AddOpponentData({
        characterName = opponentCharacterName,
        displayName = opponentDisplayName,
        alliance = opponentAlliance,
        gender = opponentGender,
        classId = opponentClassId,
        raceId = opponentRaceId,
    })
    Log('Opponent data added')

    self.currentDuel:AddResult(duelResult, wasLocalPlayersResult)
    self.resultAdded = true
    Log('Result added')

    self:TryToSaveCurrentDuel()
end

function addon:PlayerActivated(initial)
    local function OnDuelStarted(_)
        self:OnDuelStarted()
    end

    local function OnDuelFinished(_, ...)
        self:OnDuelFinished(...)
    end

    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_DUEL_STARTED, OnDuelStarted)
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_DUEL_FINISHED, OnDuelFinished)

    IMP_STATS_Duels_UI:Update()
end
--#endregion

local function OnPlayerActivated(_, initial)
    addon:PlayerActivated(initial)
end

function IMP_STATS_InitializeDuelsManager(settings, characterSettings)
    IMP_STATS_Duels_MANAGER = addon

    local server = string.sub(GetWorldName(), 1, 2)
    IMP_STATS_Duels_MANAGER.playerData = {
        characterName = GetRawUnitName('player'),
        displayName = GetDisplayName(),
        characterId = GetCurrentCharacterId(),
        alliance = GetUnitAlliance('player'),
        gender = GetUnitGender('player'),
        classId = GetUnitClassId('player'),
        raceId = GetUnitRaceId('player'),
    }

    ImpressiveStatsDuelsData = ImpressiveStatsDuelsData or {}
    ImpressiveStatsDuelsData[server] = ImpressiveStatsDuelsData[server] or {}

    IMP_STATS_Duels_MANAGER.duels = ImpressiveStatsDuelsData[server]
    Log('There are %d duels saved', #addon.duels)

    IMP_STATS_Duels_MANAGER.sv = settings

    EVENT_MANAGER:RegisterForEvent(IMP_STATS_Duels_MANAGER.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    IMP_STATS_Duels_UI:Initialize(settings.namingMode, characterSettings.selectedCharacters, settings.debugging)
end