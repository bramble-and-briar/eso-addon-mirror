-- ESO Adventurer Suite
-- PvP Command Center
-- Role-neutral, event-driven PvP awareness and session tracking.
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.PvP = EPC.PvP or {}
local P = EPC.PvP

-- Defaults are injected before EVENT_ADD_ON_LOADED finishes creating SavedVariables.
-- Keeping them here avoids scattering PvP settings across unrelated Core.lua sections.
local defaults = EPC.defaults or {}
local pvpDefaults = {
    pvpEnabled029753 = true,
    pvpOnlyInPvP029753 = true,
    pvpAutoProfile029753 = true,
    pvpPreset029753 = "CUSTOM",

    pvpStatusHud029753 = true,
    pvpStatusHudScale029753 = 1.0,
    pvpStatusHudAlpha029753 = 0.94,
    pvpStatusHudLeft029753 = -1,
    pvpStatusHudTop029753 = -1,

    pvpCombatAlerts029753 = true,
    pvpAlertIncomingHeavy029753 = true,
    pvpAlertCrowdControl029753 = true,
    pvpAlertExecute029753 = true,
    pvpAlertSiege029753 = true,
    pvpAlertUltimate029753 = true,
    pvpAlertPurge029753 = true,
    pvpAlertLowHealth029753 = true,
    pvpAlertLowResources029753 = true,
    pvpAlertSound029753 = true,
    pvpAlertScreenFlash029753 = false,
    pvpAlertScale029753 = 1.0,
    pvpAlertDuration029753 = 1800,

    pvpPlayerAwareness029753 = true,
    pvpEnemyCount029753 = true,
    pvpRecentAttackers029753 = true,
    pvpEnemyClassAlliance029753 = true,
    pvpTargetIntelligence029753 = true,
    pvpWatchList029753 = true,

    pvpGroupAwareness029753 = true,
    pvpGroupHealthPressure029753 = true,
    pvpGroupDeaths029753 = true,
    pvpGroupResurrection029753 = true,
    pvpGroupRange029753 = true,
    pvpGroupUltimate029753 = true,
    pvpGroupBuffs029753 = true,
    pvpGroupCrown029753 = true,

    pvpKillFeed029753 = true,
    pvpKillFeedSelf029753 = true,
    pvpKillFeedGroup029753 = true,
    pvpKillFeedEveryone029753 = false,
    pvpKillFeedAbility029753 = true,
    pvpKillFeedAP029753 = true,
    pvpKillFeedScale029753 = 1.0,
    pvpKillFeedDuration029753 = 6500,
    pvpKillFeedLeft029753 = -1,
    pvpKillFeedTop029753 = -1,
    pvpStreaks029753 = true,
    pvpMultiKills029753 = true,
    pvpBombTracker029753 = true,

    pvpCyrodiil029753 = true,
    pvpCyrodiilCampaign029753 = true,
    pvpCyrodiilKeeps029753 = true,
    pvpCyrodiilResources029753 = true,
    pvpCyrodiilScrolls029753 = true,
    pvpCyrodiilEmperor029753 = true,
    pvpCyrodiilCapture029753 = true,
    pvpCyrodiilCamps029753 = true,
    pvpCyrodiilSiege029753 = true,
    pvpCyrodiilTicks029753 = true,

    pvpImperialCity029753 = true,
    pvpTelVarHud029753 = true,
    pvpTelVarRisk029753 = true,
    pvpTelVarSession029753 = true,
    pvpICDistricts029753 = true,

    pvpBattlegrounds029753 = true,
    pvpBGHud029753 = true,
    pvpBGScore029753 = true,
    pvpBGKDA029753 = true,
    pvpBGMedals029753 = true,
    pvpBGObjectives029753 = true,
    pvpBGHistory029753 = true,
    pvpBGAnalytics029753 = true,

    pvpVengeance029753 = true,
    pvpVengeanceHud029753 = true,
    pvpVengeanceProgress029753 = true,

    pvpDuels029753 = true,
    pvpDuelHistory029753 = true,
    pvpDuelOpponent029753 = true,

    pvpAPVeterancy029753 = true,
    pvpAPSession029753 = true,
    pvpAPPerHour029753 = true,
    pvpAllianceRankProgress029753 = true,
    pvpVeterancyProgress029753 = true,

    pvpStatistics029753 = true,
    pvpSessionSummary029753 = true,
    pvpLifetimeKDA029753 = true,
    pvpClassBreakdown029753 = true,
    pvpDeathRecap029753 = true,
    pvpBuildSnapshot029753 = true,
    pvpPersonalRecords029753 = true,

    pvp3DMarkers029753 = true,
    pvp3DObjectives029753 = true,
    pvp3DGroupCrown029753 = true,
    pvp3DCamps029753 = true,
    pvp3DRally029753 = true,
    pvp3DScrolls029753 = true,
    pvp3DDistance029753 = 450,
    pvp3DMaxVisible029753 = 24,

    pvpMap029753 = true,
    pvpMapObjectives029753 = true,
    pvpMapGroup029753 = true,
    pvpMapCamps029753 = true,
    pvpMapScrolls029753 = true,
    pvpMapDanger029753 = true,

    pvpNotifications029753 = true,
    pvpNotifyObjective029753 = true,
    pvpNotifyKeep029753 = true,
    pvpNotifyWatch029753 = true,
    pvpNotifyRecord029753 = true,

    pvpPerformance029753 = true,
    pvpLargeBattleMode029753 = true,
    pvpAdaptiveRefresh029753 = true,
    pvpReduceAnimations029753 = false,
    pvpMaxTrackedPlayers029753 = 64,
    pvpHistoryLimit029753 = 250,

    pvpWatchPlayers029753 = {},
    pvpEncounterPlayers029753 = {},
    pvpSessionHistory029753 = {},
    pvpLifetime029753 = { kills = 0, deaths = 0, assists = 0, ap = 0, telVarGained = 0, telVarLost = 0, bestStreak = 0, bestMultiKill = 0 },
    pvpBGHistoryData029753 = {},
    pvpDuelHistoryData029753 = {},
}
for key, value in pairs(pvpDefaults) do
    if defaults[key] == nil then defaults[key] = value end
end

P.session = P.session or {}
P.feedLines = P.feedLines or {}
P.recentAttackers = P.recentAttackers or {}
P.lastContext = P.lastContext or "PVE"
P._initialized029753 = P._initialized029753 or false

local function nowMs()
    if type(GetGameTimeMilliseconds) == "function" then return GetGameTimeMilliseconds() end
    return math.floor((GetFrameTimeSeconds and GetFrameTimeSeconds() or 0) * 1000)
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f
end

local function saved()
    return EPC.saved or defaults
end

local function fmtNumber(value)
    local n = math.floor(tonumber(value) or 0)
    local sign = n < 0 and "-" or ""
    local s = tostring(math.abs(n))
    while true do
        local replaced
        s, replaced = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if replaced == 0 then break end
    end
    return sign .. s
end

local function trimHistory(list, limit)
    limit = math.max(25, tonumber(limit) or 250)
    while #list > limit do table.remove(list, 1) end
end

function P:IsEnabled()
    local sv = saved()
    return sv.pvpEnabled029753 ~= false
end

function P:IsBattleground()
    if type(IsActiveWorldBattleground) == "function" and safeCall(IsActiveWorldBattleground, false) then return true end
    if type(IsUnitInBattleground) == "function" and safeCall(IsUnitInBattleground, false, "player") then return true end
    return false
end

function P:IsImperialCity()
    if type(IsInImperialCity) == "function" then return safeCall(IsInImperialCity, false) == true end
    local zone = string.lower(tostring(safeCall(GetUnitZone, "", "player") or ""))
    return zone:find("imperial city", 1, true) ~= nil
end

function P:IsPvPContext()
    if self:IsBattleground() or self:IsImperialCity() then return true end
    if type(IsInAvAZone) == "function" and safeCall(IsInAvAZone, false) == true then return true end
    if type(IsUnitPvPFlagged) == "function" and safeCall(IsUnitPvPFlagged, false, "player") == true then return true end
    return false
end

function P:GetContext()
    if self:IsBattleground() then return "BATTLEGROUND" end
    if self:IsImperialCity() then return "IMPERIAL_CITY" end
    if type(IsInAvAZone) == "function" and safeCall(IsInAvAZone, false) == true then return "CYRODIIL" end
    return self:IsPvPContext() and "PVP" or "PVE"
end

function P:ShouldDisplay()
    if not self:IsEnabled() then return false end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then return false end
    local sv = saved()
    if sv.pvpOnlyInPvP029753 ~= false and not self:IsPvPContext() then return false end
    return true
end

function P:ResetSession(reason)
    local telVar = self:GetTelVar()
    self.session = {
        startedAt = GetTimeStamp and GetTimeStamp() or 0,
        startedMs = nowMs(),
        reason = reason or "start",
        kills = 0,
        deaths = 0,
        assists = 0,
        ap = 0,
        telVarStart = telVar,
        telVarCurrent = telVar,
        telVarGained = 0,
        telVarLost = 0,
        streak = 0,
        bestStreak = 0,
        bestMultiKill = 0,
        lastKillMs = 0,
        multiKill = 0,
        context = self:GetContext(),
    }
end

function P:GetTelVar()
    if type(GetCurrencyAmount) ~= "function" or CURT_TELVAR_STONES == nil then return 0 end
    local location = CURRENCY_LOCATION_CHARACTER or 0
    return tonumber((safeCall(GetCurrencyAmount, 0, CURT_TELVAR_STONES, location))) or 0
end

function P:GetAP()
    if type(GetAlliancePoints) == "function" then return tonumber((safeCall(GetAlliancePoints, 0))) or 0 end
    return 0
end

function P:GetSessionSeconds()
    if not self.session.startedMs then return 0 end
    return math.max(0, (nowMs() - self.session.startedMs) / 1000)
end

function P:GetAPPerHour()
    local seconds = self:GetSessionSeconds()
    if seconds < 1 then return 0 end
    return math.floor(((tonumber(self.session.ap) or 0) / seconds) * 3600)
end

function P:UpdateTelVar()
    if not self.session.startedMs then self:ResetSession("telvar") end
    local current = self:GetTelVar()
    local old = tonumber(self.session.telVarCurrent) or current
    local diff = current - old
    if diff > 0 then
        self.session.telVarGained = (self.session.telVarGained or 0) + diff
    elseif diff < 0 then
        self.session.telVarLost = (self.session.telVarLost or 0) + math.abs(diff)
    end
    self.session.telVarCurrent = current
end

function P:AddAP(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    self.session.ap = (self.session.ap or 0) + amount
    local life = saved().pvpLifetime029753 or {}
    life.ap = (tonumber(life.ap) or 0) + amount
    saved().pvpLifetime029753 = life

    local sv = saved()
    if sv.pvpKillFeed029753 ~= false and sv.pvpKillFeedAP029753 ~= false then
        local t = nowMs()
        if t - (tonumber(self.session.lastKillMs) or 0) <= 4000 then
            self:AddFeed("|c77FF77AP +" .. tostring(math.floor(amount)) .. "|r")
        elseif sv.pvpCyrodiilTicks029753 ~= false and self:GetContext() == "CYRODIIL" and amount >= 100 then
            self:AddFeed("|cE8B347AP TICK +" .. tostring(math.floor(amount)) .. "|r")
        end
    end
end

function P:AddFeed(text)
    if not text or text == "" then return end
    local sv = saved()
    self.feedLines[#self.feedLines + 1] = { text = tostring(text), expires = nowMs() + (tonumber(sv.pvpKillFeedDuration029753) or 6500) }
    while #self.feedLines > 8 do table.remove(self.feedLines, 1) end
    self:RefreshKillFeed()
end

function P:Alert(text, important)
    if not self:ShouldDisplay() or saved().pvpNotifications029753 == false then return end
    self:EnsureAlert()
    if not self.alertLabel then return end
    self.alertLabel:SetText(tostring(text or ""))
    self.alert:SetScale(tonumber(saved().pvpAlertScale029753) or 1.0)
    self.alert:SetHidden(false)
    self.alert:SetAlpha(1)
    local duration = math.max(600, tonumber(saved().pvpAlertDuration029753) or 1800)
    local key = EPC.name .. "_PvPAlertHide029753"
    EPC.Runtime:UnregisterUpdate("PvP", key)
    EPC.Runtime:RegisterUpdate("PvP", key, duration, function()
        EPC.Runtime:UnregisterUpdate("PvP", key)
        if P.alert then P.alert:SetHidden(true) end
    end)
    if important and saved().pvpAlertSound029753 ~= false and SOUNDS and SOUNDS.DUEL_START then
        PlaySound(SOUNDS.DUEL_START)
    end
end

function P:RecordKill(killerDisplay, killerCharacter, victimDisplay, victimCharacter, abilityName)
    local myDisplay = tostring(safeCall(GetDisplayName, "") or "")
    local myCharacter = tostring(safeCall(GetUnitName, "", "player") or "")
    local killerIsMe = (killerDisplay ~= "" and killerDisplay == myDisplay) or (killerCharacter ~= "" and killerCharacter == myCharacter)
    local victimIsMe = (victimDisplay ~= "" and victimDisplay == myDisplay) or (victimCharacter ~= "" and victimCharacter == myCharacter)
    local life = saved().pvpLifetime029753 or {}

    if killerIsMe and not victimIsMe then
        self.session.kills = (self.session.kills or 0) + 1
        self.session.streak = (self.session.streak or 0) + 1
        self.session.bestStreak = math.max(self.session.bestStreak or 0, self.session.streak)
        life.kills = (tonumber(life.kills) or 0) + 1
        life.bestStreak = math.max(tonumber(life.bestStreak) or 0, self.session.bestStreak)

        local t = nowMs()
        if t - (self.session.lastKillMs or 0) <= 5500 then
            self.session.multiKill = (self.session.multiKill or 0) + 1
        else
            self.session.multiKill = 1
        end
        self.session.lastKillMs = t
        self.session.bestMultiKill = math.max(self.session.bestMultiKill or 0, self.session.multiKill)
        life.bestMultiKill = math.max(tonumber(life.bestMultiKill) or 0, self.session.bestMultiKill)

        if saved().pvpKillFeed029753 ~= false and saved().pvpKillFeedSelf029753 ~= false then
            local victim = victimCharacter ~= "" and victimCharacter or victimDisplay
            local suffix = (saved().pvpKillFeedAbility029753 ~= false and abilityName and abilityName ~= "") and (" • " .. abilityName) or ""
            self:AddFeed("|c77FF77KILL|r  " .. tostring(victim) .. suffix)
        end

        if saved().pvpStreaks029753 ~= false and self.session.streak > 0 and self.session.streak % 5 == 0 then
            self:Alert("KILL STREAK • " .. tostring(self.session.streak), true)
        elseif saved().pvpMultiKills029753 ~= false and self.session.multiKill >= 2 then
            local labels = { [2] = "DOUBLE KILL", [3] = "TRIPLE KILL", [4] = "QUAD KILL", [5] = "PENTA KILL" }
            self:Alert(labels[self.session.multiKill] or ("MULTI KILL x" .. tostring(self.session.multiKill)), true)
        end
    elseif victimIsMe then
        self.session.deaths = (self.session.deaths or 0) + 1
        self.session.streak = 0
        self.session.multiKill = 0
        life.deaths = (tonumber(life.deaths) or 0) + 1
        if saved().pvpKillFeed029753 ~= false and saved().pvpKillFeedSelf029753 ~= false then
            local killer = killerCharacter ~= "" and killerCharacter or killerDisplay
            self:AddFeed("|cFF7777DEATH|r  " .. tostring(killer))
        end
    elseif saved().pvpKillFeed029753 ~= false and saved().pvpKillFeedEveryone029753 == true then
        self:AddFeed(tostring(killerCharacter ~= "" and killerCharacter or killerDisplay) .. "  >  " .. tostring(victimCharacter ~= "" and victimCharacter or victimDisplay))
    end

    saved().pvpLifetime029753 = life
    self:RefreshAll()
end

function P:OnPvPKillFeed(...)
    local args = { ... }
    -- ESO's PvP kill-feed event has changed shape between API revisions. Resolve
    -- names defensively: first collect string arguments, then prefer @display names
    -- and character-name slots. This keeps the tracker functional across revisions.
    local strings = {}
    for i = 1, #args do
        if type(args[i]) == "string" and args[i] ~= "" then strings[#strings + 1] = args[i] end
    end
    local killerDisplay, killerCharacter, victimDisplay, victimCharacter, abilityName = "", "", "", "", ""
    for _, value in ipairs(strings) do
        if value:sub(1, 1) == "@" then
            if killerDisplay == "" then killerDisplay = value elseif victimDisplay == "" then victimDisplay = value end
        else
            if killerCharacter == "" then killerCharacter = value
            elseif victimCharacter == "" then victimCharacter = value
            elseif abilityName == "" then abilityName = value end
        end
    end
    self:RecordKill(killerDisplay, killerCharacter, victimDisplay, victimCharacter, abilityName)
end

function P:OnDeathStateChanged(unitTag, isDead)
    if unitTag ~= "player" or not isDead or not self:IsPvPContext() then return end
    -- Kill-feed events normally account for the death. This fallback only records
    -- if no PvP death was seen during the same short window.
    local t = nowMs()
    if t - (self._lastDeathRecorded029753 or 0) < 2000 then return end
    self._lastDeathRecorded029753 = t
end

function P:OnCombatEvent(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if not self:IsEnabled() or saved().pvpCombatAlerts029753 == false or not self:IsPvPContext() then return end
    local playerName = tostring(safeCall(GetUnitName, "", "player") or "")
    if targetName ~= playerName or sourceName == playerName then return end

    local cc = {
        [ACTION_RESULT_STUNNED or -1001] = "STUN",
        [ACTION_RESULT_KNOCKBACK or -1002] = "KNOCKBACK",
        [ACTION_RESULT_FEARED or -1003] = "FEAR",
        [ACTION_RESULT_SILENCED or -1004] = "SILENCE",
        [ACTION_RESULT_DISORIENTED or -1005] = "DISORIENT",
        [ACTION_RESULT_ROOTED or -1006] = "ROOT",
    }
    if saved().pvpAlertCrowdControl029753 ~= false and cc[result] then
        self:Alert(cc[result] .. (abilityName and abilityName ~= "" and (" • " .. abilityName) or ""), true)
        self.recentAttackers[tostring(sourceName or "?")] = nowMs()
    end
end

function P:GetTelVarRiskLabel()
    local amount = self:GetTelVar()
    if amount >= 10000 then return "EXTREME" end
    if amount >= 5000 then return "HIGH" end
    if amount >= 1000 then return "ELEVATED" end
    return "LOW"
end

function P:BuildStatusText()
    local sv = saved()
    local parts = {}
    if sv.pvpStatistics029753 ~= false then
        parts[#parts + 1] = string.format("K/D/A  |c77FF77%d|r / |cFF7777%d|r / %d", self.session.kills or 0, self.session.deaths or 0, self.session.assists or 0)
    end
    if sv.pvpAPVeterancy029753 ~= false and sv.pvpAPSession029753 ~= false then
        local apText = "AP  " .. fmtNumber(self.session.ap or 0)
        if sv.pvpAPPerHour029753 ~= false then apText = apText .. "  •  " .. fmtNumber(self:GetAPPerHour()) .. "/hr" end
        parts[#parts + 1] = apText
    end
    if self:IsImperialCity() and sv.pvpImperialCity029753 ~= false and sv.pvpTelVarHud029753 ~= false then
        local tel = "Tel Var  " .. fmtNumber(self:GetTelVar())
        if sv.pvpTelVarRisk029753 ~= false then tel = tel .. "  •  " .. self:GetTelVarRiskLabel() end
        parts[#parts + 1] = tel
    end
    if sv.pvpCombatStats029754 ~= false then
        if sv.pvpCombatStatsDamage029754 ~= false then
            parts[#parts + 1] = string.format("DMG %s / IN %s",
                tostring(math.floor(tonumber(self.session.damageDone) or 0)),
                tostring(math.floor(tonumber(self.session.damageTaken) or 0)))
        end
        if sv.pvpCombatStatsHealing029754 ~= false and (tonumber(self.session.healingDone) or 0) > 0 then
            parts[#parts + 1] = "HEAL " .. tostring(math.floor(tonumber(self.session.healingDone) or 0))
        end
        if sv.pvpCombatStatsCrowdControl029754 ~= false then
            local applied = tonumber(self.session.ccApplied) or 0
            local received = tonumber(self.session.ccReceived) or 0
            if applied > 0 or received > 0 then
                parts[#parts + 1] = "CC " .. tostring(applied) .. "/" .. tostring(received)
            end
        end
    end
    if sv.pvpStreaks029753 ~= false and (self.session.streak or 0) > 0 then
        parts[#parts + 1] = "Streak " .. tostring(self.session.streak)
    end
    return table.concat(parts, "   •   ")
end

local function makeBackdrop(control)
    local bg = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    bg:SetAnchorFill(control)
    bg:SetCenterColor(0.015, 0.02, 0.03, 0.90)
    bg:SetEdgeColor(0.73, 0.53, 0.12, 0.95)
    return bg
end

function P:RestorePosition(control, xKey, yKey, defaultAnchor, defaultX, defaultY)
    control:ClearAnchors()
    local sv = saved()
    local x, y = tonumber(sv[xKey]) or -1, tonumber(sv[yKey]) or -1
    if x >= 0 and y >= 0 then control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else control:SetAnchor(defaultAnchor or TOP, GuiRoot, defaultAnchor or TOP, defaultX or 0, defaultY or 120) end
end

function P:MakeMovable(control, xKey, yKey)
    control:SetMouseEnabled(true)
    control:SetMovable(true)
    control:SetClampedToScreen(true)
    control:SetHandler("OnMouseDown", function(c, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode then c:StartMoving() end
    end)
    control:SetHandler("OnMouseUp", function(c, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode and type(c.StopMovingOrResizing) == "function" then c:StopMovingOrResizing() end
    end)
    control:SetHandler("OnMoveStop", function(c)
        if EPC.saved then EPC.saved[xKey], EPC.saved[yKey] = c:GetLeft(), c:GetTop() end
    end)
end

function P:EnsureStatusHud()
    if self.statusHud or not WINDOW_MANAGER or not GuiRoot then return end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_PvPStatusHud029753")
    root:SetDimensions(1024, 48)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    makeBackdrop(root)
    self:MakeMovable(root, "pvpStatusHudLeft029753", "pvpStatusHudTop029753")
    self:RestorePosition(root, "pvpStatusHudLeft029753", "pvpStatusHudTop029753", TOP, 0, 145)

    local columns = {
        { key = "kda", width = 150 },
        { key = "ap", width = 105 },
        { key = "rate", width = 115 },
        { key = "damage", width = 165 },
        { key = "heal", width = 120 },
        { key = "cc", width = 95 },
        { key = "telvar", width = 150 },
        { key = "streak", width = 100 },
    }

    self.statusColumns = {}
    local previous = nil
    for _, info in ipairs(columns) do
        local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
        label:SetDimensions(info.width, 48)
        if previous then
            label:SetAnchor(LEFT, previous, RIGHT, 0, 0)
        else
            label:SetAnchor(LEFT, root, LEFT, 12, 0)
        end
        label:SetFont("ZoFontGame")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        label:SetText("")
        self.statusColumns[info.key] = label
        previous = label
    end

    -- Kept as an alias for older runtime hooks. All live drawing now uses fixed columns.
    self.statusBody = self.statusColumns.kda
    self.statusHud = root
end

function P:RefreshStatusColumns029760()
    self:EnsureStatusHud()
    if not self.statusHud or not self.statusColumns then return end

    local s = saved()
    local cols = self.statusColumns

    local kills = tonumber(self.session.kills) or 0
    local deaths = tonumber(self.session.deaths) or 0
    local assists = tonumber(self.session.assists) or 0
    cols.kda:SetText(s.pvpStatistics029753 ~= false
        and string.format("K/D/A |c77FF77%d|r/|cFF7777%d|r/%d", kills, deaths, assists) or "")

    local showAP = s.pvpAPVeterancy029753 ~= false and s.pvpAPSession029753 ~= false
    cols.ap:SetText(showAP and ("AP " .. fmtNumber(self.session.ap or 0)) or "")
    cols.rate:SetText(showAP and s.pvpAPPerHour029753 ~= false
        and (fmtNumber(self:GetAPPerHour()) .. "/hr") or "")

    local showCombat = s.pvpCombatStats029754 ~= false
    cols.damage:SetText(showCombat and s.pvpCombatStatsDamage029754 ~= false
        and string.format("DMG %d / IN %d",
            math.floor(tonumber(self.session.damageDone) or 0),
            math.floor(tonumber(self.session.damageTaken) or 0)) or "")

    cols.heal:SetText(showCombat and s.pvpCombatStatsHealing029754 ~= false
        and ("HEAL " .. tostring(math.floor(tonumber(self.session.healingDone) or 0))) or "")

    local applied = tonumber(self.session.ccApplied) or 0
    local received = tonumber(self.session.ccReceived) or 0
    cols.cc:SetText(showCombat and s.pvpCombatStatsCrowdControl029754 ~= false
        and ("CC " .. tostring(applied) .. "/" .. tostring(received)) or "")

    if self:IsImperialCity() and s.pvpImperialCity029753 ~= false and s.pvpTelVarHud029753 ~= false then
        local tel = "TV " .. fmtNumber(self:GetTelVar())
        if s.pvpTelVarRisk029753 ~= false then tel = tel .. " " .. self:GetTelVarRiskLabel() end
        cols.telvar:SetText(tel)
    else
        cols.telvar:SetText("")
    end

    cols.streak:SetText(s.pvpStreaks029753 ~= false
        and ("STREAK " .. tostring(tonumber(self.session.streak) or 0)) or "")
end

function P:EnsureKillFeed()
    if self.killFeed or not WINDOW_MANAGER or not GuiRoot then return end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_PvPKillFeed029753")
    root:SetDimensions(430, 190)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    self:MakeMovable(root, "pvpKillFeedLeft029753", "pvpKillFeedTop029753")
    self:RestorePosition(root, "pvpKillFeedLeft029753", "pvpKillFeedTop029753", TOPRIGHT, -90, 210)
    local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    label:SetAnchorFill(root)
    label:SetFont("ZoFontGame")
    label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.killFeed, self.killFeedLabel = root, label
end

function P:EnsureAlert()
    if self.alert or not WINDOW_MANAGER or not GuiRoot then return end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_PvPAlert029753")
    root:SetDimensions(650, 64)
    root:SetAnchor(CENTER, GuiRoot, CENTER, 0, -185)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    label:SetAnchorFill(root)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.alert, self.alertLabel = root, label
end

function P:RefreshKillFeed()
    self:EnsureKillFeed()
    if not self.killFeed then return end
    local sv = saved()
    if not self:ShouldDisplay() or sv.pvpKillFeed029753 == false then
        self.killFeed:SetHidden(true)
        return
    end
    local t = nowMs()
    local text = {}
    for i = #self.feedLines, 1, -1 do
        if (self.feedLines[i].expires or 0) <= t then
            table.remove(self.feedLines, i)
        else
            table.insert(text, 1, self.feedLines[i].text)
        end
    end
    self.killFeed:SetScale(tonumber(sv.pvpKillFeedScale029753) or 1)
    self.killFeedLabel:SetText(table.concat(text, "\n"))
    self.killFeed:SetHidden(#text == 0)
end

function P:RefreshStatusHud()
    self:EnsureStatusHud()
    if not self.statusHud then return end
    local sv = saved()
    if not self:ShouldDisplay() or sv.pvpStatusHud029753 == false then
        self.statusHud:SetHidden(true)
        return
    end
    self.statusHud:SetScale(tonumber(sv.pvpStatusHudScale029753) or 1)
    self.statusHud:SetAlpha(tonumber(sv.pvpStatusHudAlpha029753) or 0.94)
    self.statusHud:SetDimensions(1024, 48)
    self:RefreshStatusColumns029760()
    self.statusHud:SetHidden(false)
end

function P:RefreshAll()
    self:UpdateTelVar()
    self:RefreshStatusHud()
    self:RefreshKillFeed()
end

function P:SaveSession(reason)
    if not self.session.startedMs then return end
    local sv = saved()
    if sv.pvpSessionSummary029753 == false then return end
    local history = sv.pvpSessionHistory029753 or {}
    history[#history + 1] = {
        startedAt = self.session.startedAt or 0,
        endedAt = GetTimeStamp and GetTimeStamp() or 0,
        context = self.session.context or self:GetContext(),
        kills = self.session.kills or 0,
        deaths = self.session.deaths or 0,
        assists = self.session.assists or 0,
        ap = self.session.ap or 0,
        telVarGained = self.session.telVarGained or 0,
        telVarLost = self.session.telVarLost or 0,
        bestStreak = self.session.bestStreak or 0,
        bestMultiKill = self.session.bestMultiKill or 0,
        reason = reason or "context-change",
    }
    trimHistory(history, sv.pvpHistoryLimit029753)
    sv.pvpSessionHistory029753 = history
end

function P:ApplyPreset(name)
    local sv = saved()
    name = tostring(name or "CUSTOM")
    sv.pvpPreset029753 = name
    if name == "MINIMAL" then
        sv.pvpCombatAlerts029753 = true
        sv.pvpPlayerAwareness029753 = false
        sv.pvpGroupAwareness029753 = false
        sv.pvpKillFeed029753 = true
        sv.pvp3DMarkers029753 = false
        sv.pvpMap029753 = true
        sv.pvpStatistics029753 = true
    elseif name == "SOLO" then
        sv.pvpCombatAlerts029753 = true
        sv.pvpPlayerAwareness029753 = true
        sv.pvpGroupAwareness029753 = false
        sv.pvpKillFeed029753 = true
        sv.pvp3DMarkers029753 = true
        sv.pvpMap029753 = true
    elseif name == "SMALL_GROUP" then
        sv.pvpCombatAlerts029753 = true
        sv.pvpPlayerAwareness029753 = true
        sv.pvpGroupAwareness029753 = true
        sv.pvpKillFeed029753 = true
        sv.pvp3DMarkers029753 = true
    elseif name == "LARGE_GROUP" then
        sv.pvpCombatAlerts029753 = true
        sv.pvpGroupAwareness029753 = true
        sv.pvpKillFeedEveryone029753 = false
        sv.pvpLargeBattleMode029753 = true
        sv.pvp3DMaxVisible029753 = math.min(18, tonumber(sv.pvp3DMaxVisible029753) or 18)
    elseif name == "BATTLEGROUNDS" then
        sv.pvpBattlegrounds029753 = true
        sv.pvpBGHud029753 = true
        sv.pvpCyrodiil029753 = false
        sv.pvpImperialCity029753 = false
    elseif name == "STREAMER" then
        sv.pvpStatusHud029753 = true
        sv.pvpKillFeed029753 = true
        sv.pvpCombatAlerts029753 = true
        sv.pvpKillFeedEveryone029753 = false
        sv.pvpReduceAnimations029753 = false
    end
    self:RefreshAll()
end

function P:RefreshContext()
    if not self:IsEnabled() then
        if self.statusHud then self.statusHud:SetHidden(true) end
        if self.killFeed then self.killFeed:SetHidden(true) end
        if self.alert then self.alert:SetHidden(true) end
        return
    end
    local context = self:GetContext()
    if context ~= self.lastContext then
        if self.lastContext ~= "PVE" and self.session.startedMs then self:SaveSession("left-" .. self.lastContext) end
        self.lastContext = context
        if context ~= "PVE" then self:ResetSession("entered-" .. context) end
    end
    self:RefreshAll()
end

function P:RegisterEvent(name, callback)
    local eventId = rawget(_G, name)
    if not EVENT_MANAGER or not eventId then return end
    EPC.Runtime:RegisterEvent("PvP", name, eventId, callback)
end

function P:Initialize()
    if self._initialized029753 then return end
    self._initialized029753 = true
    self:ResetSession("initialize")
    self:EnsureStatusHud()
    self:EnsureKillFeed()
    self:EnsureAlert()

    self:RegisterEvent("EVENT_PVP_KILL_FEED_DEATH", function(_, ...) P:OnPvPKillFeed(...) end)
    self:RegisterEvent("EVENT_UNIT_DEATH_STATE_CHANGED", function(_, unitTag, isDead) P:OnDeathStateChanged(unitTag, isDead) end)
    self:RegisterEvent("EVENT_COMBAT_EVENT", function(...) P:OnCombatEvent(...) end)
    self:RegisterEvent("EVENT_ALLIANCE_POINT_UPDATE", function(_, alliancePoints, playSound, difference)
        local diff = tonumber(difference) or 0
        if diff > 0 and P:IsPvPContext() then P:AddAP(diff) P:RefreshAll() end
    end)
    self:RegisterEvent("EVENT_CURRENCY_UPDATE", function() if P:IsPvPContext() then P:UpdateTelVar() P:RefreshAll() end end)
    self:RegisterEvent("EVENT_BATTLEGROUND_STATE_CHANGED", function() P:RefreshContext() end)
    self:RegisterEvent("EVENT_PLAYER_ACTIVATED", function() P:RefreshContext() end)
    self:RegisterEvent("EVENT_ZONE_CHANGED", function() P:RefreshContext() end)

    local key = EPC.name .. "_PvPRefresh029753"
    EPC.Runtime:UnregisterUpdate("PvP", key)
    EPC.Runtime:RegisterUpdate("PvP", "Refresh", 1000, function()
        local sv = saved()
        local interval = 1000
        if P:IsPvPContext() and sv.pvpPerformance029753 ~= false and sv.pvpAdaptiveRefresh029753 ~= false then
            interval = 750
        end
        P:RefreshContext()
    end)

    -- Integrate PvP windows into the Suite's existing HUD Layout Mode without
    -- changing Core.lua's mature layout code.
    if not self._layoutWrapped029753 and type(EPC.RaiseLayoutOverlays) == "function" then
        self._layoutWrapped029753 = true
        local original = EPC.RaiseLayoutOverlays
        EPC.RaiseLayoutOverlays = function(core, ...)
            local result = original(core, ...)
            if core.unitFramesMoveMode then
                for _, control in ipairs({ P.statusHud, P.killFeed, P.alert }) do
                    if control then
                        pcall(function()
                            control:SetTopLevel(true)
                            control:SetDrawTier(DT_HIGH)
                            control:SetDrawLevel(950)
                            control:SetHidden(false)
                        end)
                    end
                end
            else
                P:RefreshAll()
            end
            return result
        end
    end
end

-- Core creates SavedVariables during add-on load. Initialize on the next tick so
-- every Suite module and EPC.saved are available regardless of handler order.
-- Core owns add-on bootstrap; initialize on the next tick after this module loads.
if type(zo_callLater) == "function" then zo_callLater(function() P:Initialize() end, 0) else P:Initialize() end
