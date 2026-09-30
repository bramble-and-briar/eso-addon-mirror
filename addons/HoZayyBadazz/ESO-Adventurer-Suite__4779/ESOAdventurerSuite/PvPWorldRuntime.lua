-- ESO Adventurer Suite
-- PvP World Runtime
-- Cyrodiil, Imperial City, Battlegrounds, Vengeance/Veterancy, map intelligence, and session snapshots.
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.

local EPC = ESOProgressionCoach
if not EPC or not EPC.PvP then return end
local P = EPC.PvP

if P._worldRuntimeLoaded029754 then return end
P._worldRuntimeLoaded029754 = true

local defaults = EPC.defaults or {}
local extraDefaults = {
    pvpBattlefieldHud029754 = true,
    pvpBattlefieldLeft029754 = -1,
    pvpBattlefieldTop029754 = -1,
    pvpBattlefieldScale029754 = 1.0,
    pvpBattlefieldAlpha029754 = 0.94,
    pvpMapActiveBattles029754 = true,
    pvpCampaignUnderAttackOnly029754 = false,
    pvpBGSaveBuildSnapshot029754 = true,
    pvpSessionBuildSnapshots029754 = {},
}
for k, v in pairs(extraDefaults) do
    if defaults[k] == nil then defaults[k] = v end
end

P._bgLastSavedMatch029754 = P._bgLastSavedMatch029754 or nil
P._lastKeepOwners029754 = P._lastKeepOwners029754 or {}
P._lastObjectiveRefresh029754 = P._lastObjectiveRefresh029754 or 0
P._lastMapPinRefresh029754 = P._lastMapPinRefresh029754 or 0

local PIN_TYPE_STRING = "EAS_PVP_BATTLE_PIN_TYPE_029754"
local BATTLE_TEXTURE = "/esoui/art/ava/ava_rankicon_general_01.dds"

local function sv()
    return EPC.saved or defaults
end

local function nowMs()
    if type(GetGameTimeMilliseconds) == "function" then return GetGameTimeMilliseconds() end
    if type(GetFrameTimeMilliseconds) == "function" then return GetFrameTimeMilliseconds() end
    return 0
end

local function call(name, fallback, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then return fallback end
    if a == nil then return fallback end
    return a, b, c, d, e, f, g, h, i, j
end

local function clean(value)
    value = tostring(value or "")
    if value ~= "" and type(zo_strformat) == "function" then
        local ok, v = pcall(zo_strformat, "<<C:1>>", value)
        if ok and v and v ~= "" then value = v end
    end
    return value
end

local function number(value, fallback)
    local n = tonumber(value)
    if n == nil then return tonumber(fallback) or 0 end
    return n
end

local function fmt(value)
    local n = math.floor(number(value, 0))
    local sign = n < 0 and "-" or ""
    local s = tostring(math.abs(n))
    while true do
        local count
        s, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if count == 0 then break end
    end
    return sign .. s
end

local function boundedPush(list, item, limit)
    list[#list + 1] = item
    limit = math.max(10, number(limit, 250))
    while #list > limit do table.remove(list, 1) end
end

local function allianceShort(alliance)
    alliance = number(alliance, 0)
    if alliance == rawget(_G, "ALLIANCE_ALDMERI_DOMINION") then return "AD" end
    if alliance == rawget(_G, "ALLIANCE_DAGGERFALL_COVENANT") then return "DC" end
    if alliance == rawget(_G, "ALLIANCE_EBONHEART_PACT") then return "EP" end
    return "—"
end

local function teamShort(team)
    local name = clean(call("GetString", "", "SI_BATTLEGROUNDTEAM", number(team, 0)))
    if name ~= "" then return name end
    return "Team " .. tostring(team)
end

local function getBGContext()
    local fn = rawget(_G, "ZO_WorldMap_GetBattlegroundQueryType")
    if type(fn) == "function" then
        local ok, v = pcall(fn)
        if ok and v ~= nil then return v end
    end
    return rawget(_G, "BGQUERY_LOCAL") or rawget(_G, "BGQUERY_ASSIGNED_CAMPAIGN") or 1
end

function P:IsVengeance029754()
    return call("IsCurrentCampaignVengeanceRuleset", false) == true
end

function P:GetVeterancy029754()
    local manager = rawget(_G, "ZO_VETERANCY_MANAGER")
    if not manager then return nil end
    local function method(name, fallback)
        local fn = manager[name]
        if type(fn) ~= "function" then return fallback end
        local ok, a = pcall(fn, manager)
        if not ok or a == nil then return fallback end
        return a
    end
    local rank = number(method("GetCurrentRank", 0), 0)
    local name = clean(method("GetCurrentRankName", ""))
    local progress = number(method("GetCurrentTierProgress", 0), 0)
    local total = number(method("GetCurrentTierTotal", 0), 0)
    return { rank = rank, name = name, progress = progress, total = total, maxed = method("IsOnMaxRank", false) == true }
end

function P:GetVengeanceSummary029754()
    if not self:IsVengeance029754() or sv().pvpVengeance029753 == false then return nil end
    local lines = {}
    local manager = rawget(_G, "ZO_VENGEANCE_MANAGER")
    if manager and type(manager.GetEquippedLoadoutData) == "function" then
        local ok, loadout = pcall(manager.GetEquippedLoadoutData, manager)
        if ok and loadout then
            local name = type(loadout.GetName) == "function" and select(2, pcall(loadout.GetName, loadout)) or nil
            if name and name ~= "" then lines[#lines + 1] = "Loadout: " .. clean(name) end
            if sv().pvpVengeanceProgress029753 ~= false then
                local perks = {}
                for _, slotName in ipairs({ "VENGEANCE_PERK_SLOT_RED", "VENGEANCE_PERK_SLOT_YELLOW", "VENGEANCE_PERK_SLOT_BLUE" }) do
                    local slot = rawget(_G, slotName)
                    if slot and type(loadout.GetPerkNameBySlot) == "function" then
                        local okPerk, perkName = pcall(loadout.GetPerkNameBySlot, loadout, slot)
                        if okPerk and perkName and perkName ~= "" then perks[#perks + 1] = clean(perkName) end
                    end
                end
                if #perks > 0 then lines[#lines + 1] = "Perks: " .. table.concat(perks, " • ") end
            end
        end
    end
    local vet = self:GetVeterancy029754()
    if vet and sv().pvpVeterancyProgress029753 ~= false then
        local progress = vet.total > 0 and (fmt(vet.progress) .. "/" .. fmt(vet.total)) or "Max"
        lines[#lines + 1] = "Veterancy " .. tostring(vet.rank) .. (vet.name ~= "" and (" • " .. vet.name) or "") .. " • " .. progress
    end
    return table.concat(lines, "\n")
end

function P:GetCampaignId029754()
    local id = number(call("GetCurrentCampaignId", 0), 0)
    if id > 0 then return id end
    id = number(call("GetAssignedCampaignId", 0), 0)
    return id
end

function P:GetCampaignSummary029754()
    local s = sv()
    if s.pvpCyrodiil029753 == false or self:GetContext() ~= "CYRODIIL" then return nil end
    local campaignId = self:GetCampaignId029754()
    if campaignId <= 0 then return "Campaign data pending…" end

    local lines = {}
    if s.pvpCyrodiilCampaign029753 ~= false then
        local scores = {}
        for alliance = 1, 3 do
            local score = number(call("GetCampaignAllianceScore", 0, campaignId, alliance), 0)
            scores[#scores + 1] = allianceShort(alliance) .. " " .. fmt(score)
        end
        lines[#lines + 1] = table.concat(scores, "  •  ")
    end

    if s.pvpCyrodiilKeeps029753 ~= false or s.pvpCyrodiilResources029753 ~= false or s.pvpCyrodiilScrolls029753 ~= false then
        local holds = {}
        for alliance = 1, 3 do
            local bits = {}
            if s.pvpCyrodiilKeeps029753 ~= false and rawget(_G, "HOLDINGTYPE_KEEP") then
                bits[#bits + 1] = "K" .. tostring(number(call("GetTotalCampaignHoldings", 0, campaignId, HOLDINGTYPE_KEEP, alliance), 0))
            end
            if s.pvpCyrodiilResources029753 ~= false and rawget(_G, "HOLDINGTYPE_RESOURCE") then
                bits[#bits + 1] = "R" .. tostring(number(call("GetTotalCampaignHoldings", 0, campaignId, HOLDINGTYPE_RESOURCE, alliance), 0))
            end
            if s.pvpCyrodiilScrolls029753 ~= false then
                local scrolls = 0
                if rawget(_G, "HOLDINGTYPE_DEFENSIVE_ARTIFACT") then scrolls = scrolls + number(call("GetTotalCampaignHoldings", 0, campaignId, HOLDINGTYPE_DEFENSIVE_ARTIFACT, alliance), 0) end
                if rawget(_G, "HOLDINGTYPE_OFFENSIVE_ARTIFACT") then scrolls = scrolls + number(call("GetTotalCampaignHoldings", 0, campaignId, HOLDINGTYPE_OFFENSIVE_ARTIFACT, alliance), 0) end
                bits[#bits + 1] = "S" .. tostring(scrolls)
            end
            holds[#holds + 1] = allianceShort(alliance) .. "[" .. table.concat(bits, " ") .. "]"
        end
        lines[#lines + 1] = table.concat(holds, "  ")
    end

    if s.pvpCyrodiilEmperor029753 ~= false and call("DoesCampaignHaveEmperor", false, campaignId) == true then
        local alliance, characterName, displayName = call("GetCampaignEmperorInfo", 0, campaignId)
        characterName = clean(characterName)
        displayName = tostring(displayName or "")
        lines[#lines + 1] = "Emperor: " .. allianceShort(alliance) .. " " .. (characterName ~= "" and characterName or displayName)
    end

    local underAttack = self:GetUnderAttackKeeps029754(5)
    if #underAttack > 0 then
        lines[#lines + 1] = "|cFF8C55UNDER ATTACK|r  " .. table.concat(underAttack, " • ")
    end

    if s.pvpCyrodiilCamps029753 ~= false then
        local bg = getBGContext()
        local campCount = number(call("GetNumForwardCamps", 0, bg), 0)
        local usable = 0
        for i = 1, math.min(campCount, 20) do
            local _, _, _, _, canUse = call("GetForwardCampPinInfo", nil, bg, i)
            if canUse ~= false then usable = usable + 1 end
        end
        if campCount > 0 then lines[#lines + 1] = "Forward Camps: " .. tostring(usable) .. " usable / " .. tostring(campCount) .. " visible" end
    end

    if type(GetPlayerCampaignRewardTierInfo) == "function" then
        local tier, progress, total = call("GetPlayerCampaignRewardTierInfo", 0, campaignId)
        tier, progress, total = number(tier, 0), number(progress, 0), number(total, 0)
        if total > 0 then lines[#lines + 1] = string.format("Reward Tier %d • %s/%s", tier, fmt(progress), fmt(total)) end
    end

    return table.concat(lines, "\n")
end

function P:GetUnderAttackKeeps029754(maxCount)
    local results = {}
    local num = number(call("GetNumKeeps", 0), 0)
    local bg = getBGContext()
    maxCount = math.max(1, number(maxCount, 5))
    for index = 1, num do
        local keepId = call("GetKeepKeysByIndex", nil, index)
        keepId = number(keepId, 0)
        if keepId > 0 then
            local attacked = call("GetKeepUnderAttack", false, keepId, bg) == true
            if not attacked then attacked = call("GetKeepInCombat", false, keepId, bg) == true end
            if attacked then
                local name = clean(call("GetKeepName", "Keep " .. tostring(keepId), keepId))
                local owner = number(call("GetKeepAlliance", 0, keepId, bg), 0)
                local siege = 0
                if sv().pvpCyrodiilSiege029753 ~= false then
                    for alliance = 1, 3 do siege = siege + number(call("GetNumSieges", 0, keepId, bg, alliance), 0) end
                end
                results[#results + 1] = allianceShort(owner) .. " " .. name .. (siege > 0 and (" (" .. tostring(siege) .. " siege)") or "")
                if #results >= maxCount then break end
            end
        end
    end
    return results
end

function P:GetImperialCitySummary029754()
    local s = sv()
    if s.pvpImperialCity029753 == false or not self:IsImperialCity() then return nil end
    local lines = {}
    if s.pvpTelVarHud029753 ~= false then
        local current = self:GetTelVar()
        local risk = s.pvpTelVarRisk029753 ~= false and (" • " .. self:GetTelVarRiskLabel()) or ""
        lines[#lines + 1] = "Tel Var: " .. fmt(current) .. risk
    end
    if s.pvpTelVarSession029753 ~= false then
        lines[#lines + 1] = "Session: +" .. fmt(self.session.telVarGained or 0) .. " / -" .. fmt(self.session.telVarLost or 0)
    end
    if s.pvpICDistricts029753 ~= false then
        local attacked = self:GetUnderAttackKeeps029754(4)
        if #attacked > 0 then lines[#lines + 1] = "Active districts: " .. table.concat(attacked, " • ") end
    end
    return table.concat(lines, "\n")
end

function P:GetBGPlayerStats029754(roundIndex)
    local entryIndex = number(call("GetScoreboardLocalPlayerEntryIndex", 0), 0)
    if entryIndex <= 0 then return nil end
    roundIndex = number(roundIndex, number(call("GetCurrentBattlegroundRoundIndex", 1), 1))
    local characterName, displayName, team, isLocal = call("GetScoreboardEntryInfo", "", entryIndex, roundIndex)
    local function score(globalType)
        local scoreType = rawget(_G, globalType)
        if scoreType == nil then return 0 end
        return number(call("GetScoreboardEntryScoreByType", 0, entryIndex, scoreType, roundIndex), 0)
    end
    return {
        entryIndex = entryIndex,
        characterName = clean(characterName),
        displayName = tostring(displayName or ""),
        team = number(team, 0),
        kills = score("SCORE_TRACKER_TYPE_KILL"),
        deaths = score("SCORE_TRACKER_TYPE_DEATH"),
        assists = score("SCORE_TRACKER_TYPE_ASSISTS"),
        score = score("SCORE_TRACKER_TYPE_SCORE"),
        classId = number(call("GetScoreboardEntryClassId", 0, entryIndex, roundIndex), 0),
    }
end

function P:GetBGMedalCount029754(entryIndex, roundIndex)
    if not entryIndex or entryIndex <= 0 then return 0 end
    local count, medalId = 0, nil
    for _ = 1, 100 do
        medalId = call("GetNextScoreboardEntryMedalId", nil, entryIndex, medalId, roundIndex)
        if medalId == nil or number(medalId, 0) <= 0 then break end
        count = count + number(call("GetScoreboardEntryNumEarnedMedalsById", 0, entryIndex, medalId, roundIndex), 0)
    end
    return count
end

function P:GetBattlegroundSummary029754()
    local s = sv()
    if s.pvpBattlegrounds029753 == false or not self:IsBattleground() then return nil end
    local bgId = number(call("GetCurrentBattlegroundId", 0), 0)
    local round = number(call("GetCurrentBattlegroundRoundIndex", 1), 1)
    local lines = {}

    local gameType = number(call("GetCurrentBattlegroundGameType", 0), 0)
    if gameType == 0 and bgId > 0 then gameType = number(call("GetBattlegroundGameType", 0, bgId, round), 0) end
    if s.pvpBGObjectives029753 ~= false then
        local gameName = clean(call("GetString", "", "SI_BATTLEGROUNDGAMETYPE", gameType))
        if gameName ~= "" then lines[#lines + 1] = "Objective: " .. gameName end
    end

    if s.pvpBGScore029753 ~= false and bgId > 0 then
        local teamScores = {}
        local numTeams = number(call("GetBattlegroundNumTeams", 0, bgId), 0)
        for i = 1, math.min(numTeams, 8) do
            local team = number(call("GetBattlegroundTeamByIndex", i, bgId, i), i)
            local score = number(call("GetCurrentBattlegroundScore", 0, round, team), 0)
            teamScores[#teamScores + 1] = teamShort(team) .. " " .. fmt(score)
        end
        if #teamScores > 0 then lines[#lines + 1] = table.concat(teamScores, "  •  ") end
    end

    local stats = self:GetBGPlayerStats029754(round)
    if stats and s.pvpBGKDA029753 ~= false then
        lines[#lines + 1] = string.format("You: %d K / %d D / %d A • %s pts", stats.kills, stats.deaths, stats.assists, fmt(stats.score))
        if s.pvpBGMedals029753 ~= false then
            local medals = self:GetBGMedalCount029754(stats.entryIndex, round)
            if medals > 0 then lines[#lines + 1] = "Medals: " .. tostring(medals) end
        end
    end

    local remainingMs = number(call("GetCurrentBattlegroundStateTimeRemaining", 0), 0)
    if remainingMs > 0 and type(ZO_FormatTimeMilliseconds) == "function" then
        local ok, formatted = pcall(ZO_FormatTimeMilliseconds, remainingMs, rawget(_G, "TIME_FORMAT_STYLE_COLONS") or 1, rawget(_G, "TIME_FORMAT_PRECISION_SECONDS") or 0)
        if ok and formatted then lines[#lines + 1] = "Time: " .. tostring(formatted) end
    end
    return table.concat(lines, "\n")
end

function P:CaptureBuildSnapshot029754(reason)
    if sv().pvpBuildSnapshot029753 == false then return nil end
    local snapshot = {
        at = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        reason = tostring(reason or "pvp"),
        context = self:GetContext(),
        character = clean(call("GetUnitName", "", "player")),
        classId = number(call("GetUnitClassId", 0, "player"), 0),
        alliance = number(call("GetUnitAlliance", 0, "player"), 0),
        activeWeaponPair = number(call("GetActiveWeaponPairInfo", 0), 0),
        gear = {},
        skills = {},
    }
    local slots = {
        rawget(_G, "EQUIP_SLOT_HEAD"), rawget(_G, "EQUIP_SLOT_CHEST"), rawget(_G, "EQUIP_SLOT_SHOULDERS"),
        rawget(_G, "EQUIP_SLOT_HAND"), rawget(_G, "EQUIP_SLOT_WAIST"), rawget(_G, "EQUIP_SLOT_LEGS"),
        rawget(_G, "EQUIP_SLOT_FEET"), rawget(_G, "EQUIP_SLOT_NECK"), rawget(_G, "EQUIP_SLOT_RING1"),
        rawget(_G, "EQUIP_SLOT_RING2"), rawget(_G, "EQUIP_SLOT_MAIN_HAND"), rawget(_G, "EQUIP_SLOT_OFF_HAND"),
        rawget(_G, "EQUIP_SLOT_BACKUP_MAIN"), rawget(_G, "EQUIP_SLOT_BACKUP_OFF"),
    }
    for _, slot in ipairs(slots) do
        if slot ~= nil then
            local link = tostring(call("GetItemLink", "", rawget(_G, "BAG_WORN") or 0, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
            if link ~= "" then snapshot.gear[tostring(slot)] = link end
        end
    end
    for _, bar in ipairs({ rawget(_G, "HOTBAR_CATEGORY_PRIMARY"), rawget(_G, "HOTBAR_CATEGORY_BACKUP") }) do
        if bar ~= nil then
            snapshot.skills[tostring(bar)] = {}
            for slotIndex = 3, 8 do
                local abilityId = number(call("GetSlotBoundId", 0, slotIndex, bar), 0)
                if abilityId > 0 then snapshot.skills[tostring(bar)][slotIndex] = abilityId end
            end
        end
    end
    local store = sv().pvpSessionBuildSnapshots029754
    if type(store) ~= "table" then store = {}; sv().pvpSessionBuildSnapshots029754 = store end
    boundedPush(store, snapshot, math.min(50, number(sv().pvpHistoryLimit029753, 250)))
    return snapshot
end

function P:SaveBattlegroundMatch029754()
    local s = sv()
    if s.pvpBGHistory029753 == false or not self:IsBattleground() then return end
    local state = number(call("GetCurrentBattlegroundState", 0), 0)
    local finished = rawget(_G, "BATTLEGROUND_STATE_FINISHED")
    if finished == nil or state ~= finished then return end

    local bgId = number(call("GetCurrentBattlegroundId", 0), 0)
    local round = number(call("GetCurrentBattlegroundRoundIndex", 1), 1)
    local stats = self:GetBGPlayerStats029754(round)
    if not stats then return end
    local key = tostring(bgId) .. ":" .. tostring(round) .. ":" .. tostring(stats.kills) .. ":" .. tostring(stats.deaths) .. ":" .. tostring(stats.assists) .. ":" .. tostring(stats.score)
    if self._bgLastSavedMatch029754 == key then return end
    self._bgLastSavedMatch029754 = key

    local result = stats.team > 0 and number(call("GetBattlegroundResultForTeam", 0, stats.team), 0) or 0
    local history = s.pvpBGHistoryData029753
    if type(history) ~= "table" then history = {}; s.pvpBGHistoryData029753 = history end
    local entry = {
        at = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        battlegroundId = bgId,
        round = round,
        gameType = number(call("GetCurrentBattlegroundGameType", 0), 0),
        team = stats.team,
        result = result,
        kills = stats.kills,
        deaths = stats.deaths,
        assists = stats.assists,
        score = stats.score,
        medals = self:GetBGMedalCount029754(stats.entryIndex, round),
        classId = stats.classId,
    }
    boundedPush(history, entry, s.pvpHistoryLimit029753)
    if s.pvpBGSaveBuildSnapshot029754 ~= false then self:CaptureBuildSnapshot029754("battleground-finished") end

    if s.pvpBGAnalytics029753 ~= false then
        local count, kills, deaths, assists, score = #history, 0, 0, 0, 0
        for _, m in ipairs(history) do
            kills = kills + number(m.kills, 0)
            deaths = deaths + number(m.deaths, 0)
            assists = assists + number(m.assists, 0)
            score = score + number(m.score, 0)
        end
        self.bgAnalytics029754 = {
            matches = count,
            avgKills = count > 0 and kills / count or 0,
            avgDeaths = count > 0 and deaths / count or 0,
            avgAssists = count > 0 and assists / count or 0,
            avgScore = count > 0 and score / count or 0,
        }
    end
end

function P:GetAPVeterancySummary029754()
    if sv().pvpAPVeterancy029753 == false then return nil end
    local lines = {}
    if sv().pvpAllianceRankProgress029753 ~= false then
        local rank = number(call("GetUnitAvARank", 0, "player"), 0)
        local points = number(call("GetUnitAvARankPoints", 0, "player"), 0)
        lines[#lines + 1] = "Alliance Rank " .. tostring(rank) .. " • " .. fmt(points) .. " AP"
    end
    if sv().pvpVeterancyProgress029753 ~= false then
        local vet = self:GetVeterancy029754()
        if vet then
            local progress = vet.total > 0 and (fmt(vet.progress) .. "/" .. fmt(vet.total)) or "Max"
            lines[#lines + 1] = "Veterancy " .. tostring(vet.rank) .. (vet.name ~= "" and (" • " .. vet.name) or "") .. " • " .. progress
        end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function P:EnsureBattlefieldHud029754()
    if self.battlefieldHud029754 or not WINDOW_MANAGER or not GuiRoot then return end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("EAS_PvPBattlefieldHud029754")
    root:SetDimensions(560, 220)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(true)
    root:SetMovable(true)

    local bg = WINDOW_MANAGER:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.012, 0.018, 0.028, 0.92)
    bg:SetEdgeColor(0.72, 0.52, 0.12, 0.94)

    local body = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    body:SetAnchor(TOPLEFT, root, TOPLEFT, 12, 10)
    body:SetAnchor(TOPRIGHT, root, TOPRIGHT, -12, 10)
    body:SetFont("ZoFontGameLarge")
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)

    root:SetHandler("OnMouseDown", function(c, button) if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode then c:StartMoving() end end)
    root:SetHandler("OnMouseUp", function(c, button) if button == MOUSE_BUTTON_INDEX_LEFT and EPC.unitFramesMoveMode and type(c.StopMovingOrResizing) == "function" then c:StopMovingOrResizing() end end)
    root:SetHandler("OnMoveStop", function(c)
        if EPC.saved then EPC.saved.pvpBattlefieldLeft029754, EPC.saved.pvpBattlefieldTop029754 = c:GetLeft(), c:GetTop() end
    end)

    self.battlefieldHud029754, self.battlefieldBody029754 = root, body
    self:RestoreBattlefieldPosition029754()
end

function P:RestoreBattlefieldPosition029754()
    local root = self.battlefieldHud029754
    if not root then return end
    root:ClearAnchors()
    local x, y = number(sv().pvpBattlefieldLeft029754, -1), number(sv().pvpBattlefieldTop029754, -1)
    if x >= 0 and y >= 0 then root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    else root:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -28, 170) end
end

function P:RefreshBattlefieldHud029754()
    self:EnsureBattlefieldHud029754()
    local root = self.battlefieldHud029754
    if not root then return end

    -- HUD Layout is a frozen positioning preview. Never let normal PvP
    -- visibility/data refresh hide or repaint this window while it is being moved.
    if EPC and EPC.unitFramesMoveMode then
        root:SetHidden(false)
        return
    end

    local s = sv()
    if not self:ShouldDisplay() or s.pvpBattlefieldHud029754 == false then
        root:SetHidden(true)
        return
    end

    local blocks = {}
    if self:IsBattleground() then
        if s.pvpBGHud029753 ~= false then blocks[#blocks + 1] = self:GetBattlegroundSummary029754() end
    elseif self:IsImperialCity() then
        blocks[#blocks + 1] = self:GetImperialCitySummary029754()
    elseif self:GetContext() == "CYRODIIL" then
        blocks[#blocks + 1] = self:GetCampaignSummary029754()
    end
    if self:IsVengeance029754() and s.pvpVengeanceHud029753 ~= false then blocks[#blocks + 1] = self:GetVengeanceSummary029754() end
    local progression = self:GetAPVeterancySummary029754()
    if progression then blocks[#blocks + 1] = progression end

    local final = {}
    for _, block in ipairs(blocks) do if block and block ~= "" then final[#final + 1] = block end end
    if #final == 0 then root:SetHidden(true) return end

    root:SetScale(number(s.pvpBattlefieldScale029754, 1.0))
    root:SetAlpha(number(s.pvpBattlefieldAlpha029754, 0.94))
    local text = table.concat(final, "\n")
    if self._battlefieldText029776 ~= text then
        self._battlefieldText029776 = text
        self.battlefieldBody029754:SetText(text)
        local textHeight = type(self.battlefieldBody029754.GetTextHeight) == "function"
            and tonumber((self.battlefieldBody029754:GetTextHeight())) or 120
        root:SetHeight(math.max(64, math.min(430, (textHeight or 120) + 20)))
    end
    root:SetHidden(false)
end

function P:GetBattleMapPins029754()
    local pins = {}
    local s = sv()
    if s.pvpMap029753 == false then return pins end
    local cap = math.max(4, number(s.pvp3DMaxVisible029753, 24))
    local bg = getBGContext()

    local function add(kind, x, y, text)
        x, y = tonumber(x), tonumber(y)
        if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return end
        pins[#pins + 1] = { kind = kind, x = x, y = y, text = text or kind }
    end

    if s.pvpMapActiveBattles029754 ~= false or s.pvpMapDanger029753 ~= false then
        local count = number(call("GetNumKillLocations", 0), 0)
        for index = 1, math.min(count, cap) do
            local _, x, y = call("GetKillLocationPinInfo", nil, index)
            local totals = {}
            for alliance = 1, 3 do
                local kills = number(call("GetNumKillLocationAllianceKills", 0, index, alliance), 0)
                if kills > 0 then totals[#totals + 1] = allianceShort(alliance) .. " " .. tostring(kills) end
            end
            add("BATTLE", x, y, #totals > 0 and table.concat(totals, " • ") or "Active battle")
        end
    end

    if s.pvpMapCamps029753 ~= false then
        local camps = number(call("GetNumForwardCamps", 0, bg), 0)
        for i = 1, math.min(camps, 12) do
            local _, x, y, _, usable = call("GetForwardCampPinInfo", nil, bg, i)
            if usable ~= false then add("CAMP", x, y, "Forward Camp") end
        end
    end

    if s.pvpMapGroup029753 ~= false then
        local groupSize = number(call("GetGroupSize", 0), 0)
        for i = 1, math.min(groupSize, 12) do
            local tag = "group" .. tostring(i)
            if call("DoesUnitExist", false, tag) == true then
                local x, y = call("GetMapPlayerPosition", nil, tag)
                local name = clean(call("GetUnitName", "Group", tag))
                add(call("IsUnitGroupLeader", false, tag) == true and "CROWN" or "GROUP", x, y, name)
            end
        end
    end

    if s.pvpMapObjectives029753 ~= false and (self:GetContext() == "CYRODIIL" or self:IsImperialCity()) then
        local keeps = number(call("GetNumKeeps", 0), 0)
        for i = 1, math.min(keeps, 160) do
            local keepId = number(call("GetKeepKeysByIndex", 0, i), 0)
            if keepId > 0 then
                local attacked = call("GetKeepUnderAttack", false, keepId, bg) == true
                if not attacked then attacked = call("GetKeepInCombat", false, keepId, bg) == true end
                if attacked then
                    local _, x, y = call("GetKeepPinInfo", nil, keepId, bg)
                    add("OBJECTIVE", x, y, clean(call("GetKeepName", "Objective", keepId)) .. " • UNDER ATTACK")
                end
            end
        end
    end

    if s.pvpMapScrolls029753 ~= false and self:GetContext() == "CYRODIIL" and rawget(_G, "KEEPTYPE_ARTIFACT_KEEP") then
        local keeps = number(call("GetNumKeeps", 0), 0)
        for i = 1, math.min(keeps, 160) do
            local keepId = number(call("GetKeepKeysByIndex", 0, i), 0)
            if keepId > 0 and call("GetKeepType", 0, keepId) == KEEPTYPE_ARTIFACT_KEEP then
                local objectiveId = number(call("GetKeepArtifactObjectiveId", 0, keepId), 0)
                if objectiveId > 0 then
                    local name, _, state = call("GetObjectiveInfo", "", keepId, objectiveId, bg)
                    if state ~= rawget(_G, "OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE") then
                        local _, x, y = call("GetKeepPinInfo", nil, keepId, bg)
                        add("SCROLL", x, y, clean(name) ~= "" and clean(name) or "Elder Scroll")
                    end
                end
            end
        end
    end

    while #pins > cap * 3 do table.remove(pins) end
    return pins
end
function P:EnsureBattleMapPins029754()
    if self._mapPinsReady029754 then return true end
    if type(ZO_WorldMap_GetPinManager) ~= "function" then return false end
    local manager = ZO_WorldMap_GetPinManager()
    if not manager or type(manager.AddCustomPin) ~= "function" then return false end
    local tint = type(ZO_ColorDef) == "table" and ZO_ColorDef.New and ZO_ColorDef:New(1.0, 0.30, 0.12) or nil
    local layout = { texture = BATTLE_TEXTURE, level = 70, size = 38, tint = tint }
    local tooltipData
    if rawget(_G, "ZO_MAP_TOOLTIP_MODE") and rawget(_G, "ZO_WorldMap_GetTooltipForMode") then
        tooltipData = {
            creator = function(pin)
                local tip = ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)
                if tip and tip.AddLine then
                    tip:AddLine("PVP BATTLE ACTIVITY", "ZoFontWinH4", 1, 0.72, 0.28)
                    local tag = pin and pin.GetTag and pin:GetTag() or nil
                    if type(tag) == "table" then tip:AddLine(tostring(tag.text or "Active battle"), "ZoFontGame", 1, 1, 1) end
                end
            end,
            tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        }
    end
    local ok = pcall(manager.AddCustomPin, manager, PIN_TYPE_STRING,
        function(mgr)
            local pinType = rawget(_G, PIN_TYPE_STRING)
            if not pinType or not mgr or type(mgr.CreatePin) ~= "function" then return end
            for _, entry in ipairs(P:GetBattleMapPins029754()) do
                pcall(mgr.CreatePin, mgr, pinType, entry, entry.x, entry.y)
            end
        end, nil, layout, tooltipData)
    if not ok then return false end
    self._mapPinType029754 = rawget(_G, PIN_TYPE_STRING)
    if self._mapPinType029754 and type(manager.SetCustomPinEnabled) == "function" then
        pcall(manager.SetCustomPinEnabled, manager, self._mapPinType029754, true)
    end
    self._mapPinsReady029754 = self._mapPinType029754 ~= nil
    return self._mapPinsReady029754
end

function P:RefreshBattleMapPins029754()
    if not self:IsPvPContext() then return end
    if not self:EnsureBattleMapPins029754() then return end
    local manager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
    if manager and type(manager.RefreshCustomPins) == "function" and self._mapPinType029754 then
        pcall(manager.RefreshCustomPins, manager, self._mapPinType029754)
    end
end

function P:CheckKeepChanges029754()
    if self:GetContext() ~= "CYRODIIL" and not self:IsImperialCity() then return end
    local s = sv()
    local num = number(call("GetNumKeeps", 0), 0)
    local bg = getBGContext()
    local cap = math.min(num, 160)
    for index = 1, cap do
        local keepId = number(call("GetKeepKeysByIndex", 0, index), 0)
        if keepId > 0 then
            local owner = number(call("GetKeepAlliance", 0, keepId, bg), 0)
            local previous = self._lastKeepOwners029754[keepId]
            self._lastKeepOwners029754[keepId] = owner
            if previous ~= nil and previous ~= owner and s.pvpNotifications029753 ~= false and s.pvpNotifyKeep029753 ~= false then
                local name = clean(call("GetKeepName", "Objective", keepId))
                self:Alert(name .. " • " .. allianceShort(owner) .. " captured", false)
            end
        end
    end
end

function P:RefreshWorldRuntime029754()
    if EPC and EPC.unitFramesMoveMode then
        self:EnsureBattlefieldHud029754()
        if self.battlefieldHud029754 then self.battlefieldHud029754:SetHidden(false) end
        return
    end
    if not self:IsEnabled() then
        if self.battlefieldHud029754 then self.battlefieldHud029754:SetHidden(true) end
        return
    end
    if not self:IsPvPContext() then
        if self.battlefieldHud029754 then self.battlefieldHud029754:SetHidden(true) end
        return
    end
    self:RefreshBattlefieldHud029754()
    self:SaveBattlegroundMatch029754()
    self:CheckKeepChanges029754()

    local t = nowMs()
    if t - (self._lastMapPinRefresh029754 or 0) >= 2500 then
        self._lastMapPinRefresh029754 = t
        self:RefreshBattleMapPins029754()
    end
end

function P:InstallWorldRuntime029754()
    if self._worldRuntimeInstalled029754 then return end
    self._worldRuntimeInstalled029754 = true
    self:EnsureBattlefieldHud029754()

    self:RegisterEvent("EVENT_BATTLEGROUND_SCOREBOARD_UPDATED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_BATTLEGROUND_RULESET_CHANGED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_CAMPAIGN_SCORE_DATA_CHANGED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_CAMPAIGN_EMPEROR_CHANGED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_KEEP_ALLIANCE_OWNER_CHANGED", function()
        P:CheckKeepChanges029754()
        P:RefreshBattlefieldHud029754()
        P:RefreshBattleMapPins029754()
    end)
    self:RegisterEvent("EVENT_OBJECTIVES_UPDATED", function()
        if sv().pvpCyrodiilCapture029753 ~= false then
            P._lastObjectiveRefresh029754 = nowMs()
            if sv().pvpNotifications029753 ~= false and sv().pvpNotifyObjective029753 ~= false then
                local t = nowMs()
                if t - (P._lastObjectiveAlert029754 or 0) > 5000 then
                    P._lastObjectiveAlert029754 = t
                    P:Alert("PVP OBJECTIVE STATE UPDATED", false)
                end
            end
        end
        P:RefreshBattlefieldHud029754()
        P:RefreshBattleMapPins029754()
    end)
    self:RegisterEvent("EVENT_REWARD_TRACK_PROGRESS_GAINED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_VENGEANCE_LOADOUT_ROLE_UPDATED", function() P:RefreshBattlefieldHud029754() end)
    self:RegisterEvent("EVENT_VENGEANCE_PERKS_UPDATED", function() P:RefreshBattlefieldHud029754() end)

    local originalRefreshContext = self.RefreshContext
    if type(originalRefreshContext) == "function" and not self._contextWorldWrapped029754 then
        self._contextWorldWrapped029754 = true
        self.RefreshContext = function(selfObj, ...)
            local old = selfObj.lastContext
            local result = originalRefreshContext(selfObj, ...)
            local new = selfObj.lastContext
            if old ~= new and new ~= "PVE" and sv().pvpBuildSnapshot029753 ~= false then
                selfObj:CaptureBuildSnapshot029754("entered-" .. tostring(new))
            end
            return result
        end
    end

    local key = EPC.name .. "_PvPWorldRuntime029754"
    EPC.Runtime:UnregisterUpdate("PvPWorldRuntime", key)
    EPC.Runtime:RegisterUpdate("PvPWorldRuntime", key, 1000, function() P:RefreshWorldRuntime029754() end)

    if not self._layoutWorldWrapped029754 and type(EPC.RaiseLayoutOverlays) == "function" then
        self._layoutWorldWrapped029754 = true
        local original = EPC.RaiseLayoutOverlays
        EPC.RaiseLayoutOverlays = function(core, ...)
            local result = original(core, ...)
            if P.battlefieldHud029754 and core.unitFramesMoveMode then
                -- Shared HUD Layout handles draw tier/z-order once per session.
                -- Reapplying it every 250 ms caused Battlefield Intelligence flicker.
                P.battlefieldHud029754:SetHidden(false)
                if core.EnsureSingleClickLayoutDrag029763 then
                    core:EnsureSingleClickLayoutDrag029763(P.battlefieldHud029754)
                end
            end
            return result
        end
    end
end

local baseInitialize = P.Initialize
function P:Initialize(...)
    local result
    if type(baseInitialize) == "function" then result = baseInitialize(self, ...) end
    self:InstallWorldRuntime029754()
    return result
end
