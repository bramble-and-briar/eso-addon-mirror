-- ESO Fantasy v0.1.0 — manual scoring proof of concept.
-- Does not yet read Battleground stats automatically.
-- Healing milestone bonus: +1 ESOFP for every full 250,000 healing.
-- Applied to newly scored matches only; existing recorded scores remain intact.
local function healingMilestoneBonus(healing)
    return math.floor(math.max(0,tonumber(healing) or 0)/250000)
end

local function score(kills, assists, deaths, damage, healing, objectives, won, bonus90, bonus60)
    return kills + assists * 0.5 - deaths
        + damage / 200000 + healing / 100000 + healingMilestoneBonus(healing)
        + objectives * 0.1 + (won and 3 or 0)
        + (bonus90 and 1.5 or 0) + (bonus60 and 1 or 0)
end

local function message(s)
    if d then d("ESO Fantasy: " .. s) end
end

local function parseFlag(s)
    return s == "1" or s == "yes" or s == "true"
end


-- Safe, read-only discovery. Names are candidates, not a claim of API support.
local candidateFunctions = {
    "IsActiveWorldBattleground", "IsInBattleground", "GetCurrentBattlegroundId",
    "GetBattlegroundState", "GetBattlegroundGameType", "GetBattlegroundScore",
    "GetBattlegroundPlayerCount", "GetBattlegroundLeaderboardData",
    "GetBattlegroundScoreboardData", "GetBattlegroundScoreboardPlayerData",
    "GetBattlegroundPlayerScore", "GetBattlegroundPlayerStats",
    "GetPlayerBattlegroundScore", "GetPlayerBattlegroundStats",
    "GetCurrentBattlegroundState", "GetBattlegroundMatchInfo",
}
local candidateEvents = {
    "EVENT_BATTLEGROUND_STATE_CHANGED", "EVENT_BATTLEGROUND_SCORE_UPDATED",
    "EVENT_BATTLEGROUND_MATCH_INFO_UPDATED", "EVENT_BATTLEGROUND_KILL",
    "EVENT_BATTLEGROUND_MEDAL_AWARDED", "EVENT_BATTLEGROUND_SCOREBOARD_UPDATED",
    "EVENT_BATTLEGROUND_GAME_STARTED", "EVENT_BATTLEGROUND_GAME_ENDED",
}
local function diagnosticReport()
    message("v0.2 PS5 API diagnostic (read-only). Checking candidate globals...")
    local fCount, eCount = 0, 0
    for _, name in ipairs(candidateFunctions) do
        if type(_G[name]) == "function" then
            message("FUNCTION available: " .. name)
            fCount = fCount + 1
        end
    end
    for _, name in ipairs(candidateEvents) do
        if type(_G[name]) == "number" then
            message("EVENT available: " .. name)
            eCount = eCount + 1
        end
    end
    message(string.format("Diagnostic: %d/%d candidate functions, %d/%d candidate events found.",
        fCount, #candidateFunctions, eCount, #candidateEvents))
    message("No match data accessed; absent candidates do NOT prove the API is unavailable.")
end

-- v0.3: In-memory, read-only live event probe. No player stats are assumed.
local live = { active = false, counters = {}, last = {}, errors = {} }
local tracked = {
    {"state", "EVENT_BATTLEGROUND_STATE_CHANGED"},
    {"kill", "EVENT_BATTLEGROUND_KILL"},
    {"scoreboard", "EVENT_BATTLEGROUND_SCOREBOARD_UPDATED"},
}
local function safeText(v)
    local t = type(v)
    if t == "number" or t == "boolean" then return tostring(v) end
    if t == "string" then
        -- Don't echo names or chat/user content in diagnostics.
        return "string(len=" .. tostring(#v) .. ")"
    end
    return t
end
local function snapshot(...)
    local result = {}
    local args = {...}
    for i = 1, math.min(select("#", ...), 8) do
        result[#result + 1] = safeText(args[i])
    end
    return table.concat(result, ", ")
end
local function eventHandler(kind)
    return function(...)
        live.counters[kind] = (live.counters[kind] or 0) + 1
        live.last[kind] = snapshot(...)
        -- No chat output during combat; check /esof report after the match.
    end
end
local function stopProbe()
    for _, item in ipairs(tracked) do
        if type(_G[item[2]]) == "number" then
            EVENT_MANAGER:UnregisterForEvent("ESOFantasyProbe_" .. item[1], _G[item[2]])
        end
    end
    live.active = false
end
local function startProbe()
    if live.active then message("Live probe already running.") return end
    live.counters, live.last, live.errors = {}, {}, {}
    local registered = 0
    for _, item in ipairs(tracked) do
        local id = _G[item[2]]
        if type(id) == "number" then
            local ok, err = pcall(function()
                EVENT_MANAGER:RegisterForEvent("ESOFantasyProbe_" .. item[1], id, eventHandler(item[1]))
            end)
            if ok then registered = registered + 1
            else live.errors[#live.errors + 1] = item[1] .. ": " .. safeText(err) end
        else live.errors[#live.errors + 1] = item[1] .. ": missing event" end
    end
    live.active = registered > 0
    message("v0.4 probe started; " .. registered .. "/3 listeners registered. Play a Battleground, then /esof report.")
end
local function reportProbe()
    message("v0.4 probe " .. (live.active and "ACTIVE" or "STOPPED") .. "; counts since /esof start:")
    for _, item in ipairs(tracked) do
        local kind = item[1]
        message(kind .. ": " .. tostring(live.counters[kind] or 0) .. " events; last args: " .. (live.last[kind] or "none"))
    end
    local checks = {"IsActiveWorldBattleground", "GetCurrentBattlegroundId", "GetCurrentBattlegroundState"}
    for _, name in ipairs(checks) do
        if type(_G[name]) == "function" then
            local ok, result = pcall(_G[name])
            message(name .. ": " .. (ok and safeText(result) or "call failed (signature unknown)"))
        end
    end
    for _, err in ipairs(live.errors) do message("Listener issue: " .. err) end
    message("No scoreboard player stats are read in v0.4. Counts reset on logout/reload.")
end


-- v0.4: read-only scoreboard API discovery and console-friendly status panel.
-- Discovery lists function names only; it never calls unknown-signature functions.
local discovery = { names = {}, total = 0 }
-- Only check explicitly named APIs. NEVER iterate pairs(_G) on console:
-- doing so can touch private functions and taint the UI execution context.
local scoreboardCandidates = {
    "GetBattlegroundScoreboardData", "GetBattlegroundScoreboardPlayerData",
    "GetBattlegroundPlayerScore", "GetBattlegroundPlayerStats",
    "GetPlayerBattlegroundScore", "GetPlayerBattlegroundStats",
    "GetBattlegroundLeaderboardData", "GetBattlegroundScore",
    "GetBattlegroundPlayerCount", "GetBattlegroundMatchInfo",
    "GetBattlegroundScoreboardEntryData", "GetBattlegroundScoreboardEntryCount",
    "GetBattlegroundScoreboardPlayerCount", "GetBattlegroundScoreboardPlayerInfo",
    "GetBattlegroundScoreboardPlayerStats", "GetBattlegroundScoreboardPlayerScore",
    "GetBattlegroundScoreboardPlayerName", "GetBattlegroundScoreboardPlayerDataByIndex",
    "GetBattlegroundScoreboardTeamData", "GetBattlegroundScoreboardTeamScore",
    "GetCurrentBattlegroundId", "GetCurrentBattlegroundState",
    "GetBattlegroundGameType", "IsActiveWorldBattleground",
}
local function discoverScoreboard()
    local matches = {}
    local blocked = 0
    for _, name in ipairs(scoreboardCandidates) do
        -- pcall protects a single named lookup if a particular global is restricted.
        local ok, kind = pcall(function() return type(_G[name]) end)
        if ok and kind == "function" then
            matches[#matches + 1] = name
        elseif not ok then
            blocked = blocked + 1
        end
    end
    discovery.names, discovery.total = matches, #matches
    message("v0.4.1 safe discovery: " .. #matches .. " / " .. #scoreboardCandidates .. " candidate functions found.")
    for i, name in ipairs(matches) do message("API " .. i .. ": " .. name) end
    if blocked > 0 then message(blocked .. " candidate lookups were restricted; skipped safely.") end
    message("Names only; no player statistics accessed. Send screenshot of results.")
end


-- v0.5: Targeted scoreboard reader based on ESO's own Battleground UI.
-- This does not enumerate globals or access protected functions by name.
local scoreboardAPI = {
    "GetNumScoreboardEntries", "GetScoreboardPlayerEntryIndex",
    "GetScoreboardEntryInfo", "GetScoreboardEntryScoreByType",
    "GetNextScoreboardEntryMedalId", "GetScoreboardEntryNumEarnedMedalsById",
    "GetScoreboardEntryClassId", "GetBattlegroundCumulativeScoreForScoreboardEntryByType",
}
local function guardedCall(name, ...)
    local ok, fn = pcall(function() return _G[name] end)
    if not ok or type(fn) ~= "function" then return false, "not exposed" end
    local success, a, b, c, d = pcall(fn, ...)
    if not success then return false, "call failed (see UI notifications if any)" end
    return true, a, b, c, d
end
local function probeScoreboard()
    message("v0.5 targeted scoreboard probe; use during BG or on final scoreboard.")
    local found = 0
    for _, name in ipairs(scoreboardAPI) do
        local ok, kind = pcall(function() return type(_G[name]) end)
        if ok and kind == "function" then
            found = found + 1
            message("AVAILABLE: " .. name)
        else
            message("NOT EXPOSED: " .. name)
        end
    end
    message("Scoreboard APIs: " .. found .. "/" .. #scoreboardAPI)
    local okCount, count = guardedCall("GetNumScoreboardEntries")
    if not okCount or type(count) ~= "number" then
        message("Scoreboard entry count unavailable. Run on the final match scoreboard.")
        return
    end
    message("Scoreboard entries: " .. tostring(count))
    if count < 1 then message("No entries yet; run after a match before leaving.") return end
    local okIndex, index = guardedCall("GetScoreboardPlayerEntryIndex")
    if not okIndex or type(index) ~= "number" or index < 1 or index > count then
        message("Local player index unavailable; checking isLocalPlayer flags.")
        index = nil
        for i = 1, math.min(count, 24) do
            local okInfo, _, _, _, isLocal = guardedCall("GetScoreboardEntryInfo", i)
            if okInfo and isLocal == true then index = i break end
        end
    end
    if not index then message("Could not identify local player; no other player's data shown.") return end
    message("Local scoreboard entry: " .. tostring(index))
    local okInfo, characterName, _, _, isLocal = guardedCall("GetScoreboardEntryInfo", index)
    if okInfo then
        message("Player entry returned; local flag: " .. tostring(isLocal))
        -- No names displayed in diagnostics; usable by any player.
    end
    local statTypes = {
        {"damage", "SCORE_TRACKER_TYPE_DAMAGE_DONE"},
        {"healing", "SCORE_TRACKER_TYPE_HEALING_DONE"},
        {"kills", "SCORE_TRACKER_TYPE_KILL"},
        {"deaths", "SCORE_TRACKER_TYPE_DEATH"},
        {"assists", "SCORE_TRACKER_TYPE_ASSIST"},
    }
    for _, entry in ipairs(statTypes) do
        local name, constant = entry[1], entry[2]
        local okType, typeId = pcall(function() return _G[constant] end)
        if okType and type(typeId) == "number" then
            local okValue, value = guardedCall("GetScoreboardEntryScoreByType", index, typeId)
            message(name .. ": " .. (okValue and tostring(value) or "unavailable"))
        else
            message(name .. ": score-type constant not exposed")
        end
    end
    message("This is a diagnostic; no automatic fantasy score is claimed yet.")
end


local refreshPanel
local saved, lastManualScore = nil, nil
local match = {active=false, finalized=false, snapshots=0}
local teamRows = {}
local matchIdentity = 0
local archivedMatch = false
local lastMatchSnapshot = nil
local seenActiveBG = false
local finishedSeen = false
local scoreboardPage = 1
local historyPage = 1
local viewMode = "MATCH"
local historySort = "AVERAGE"
local lastSnapshotAt = 0
local function fmt(n) return tostring(math.floor(n or 0)) end
-- HUD-only abbreviated formatting. Never round stored scoring data.
local function compact(n)
    if type(n)~="number" then return "--" end
    local magnitude=math.abs(n)
    if magnitude>=1000000 then
        local v=n/1000000
        return string.format(v>=10 and "%.1fM" or "%.2fM",v)
    elseif magnitude>=1000 then
        local v=n/1000
        return string.format(v>=100 and "%.0fK" or v>=10 and "%.1fK" or "%.2fK",v)
    end
    return string.format("%.0f",n)
end
local function average()
    if not saved or (saved.games or 0) == 0 then return nil end
    return (saved.total or 0) / saved.games
end
local function saveCompletedScore(points)
    if not saved then message("Saved history unavailable.") return end
    if type(points) ~= "number" then return end
    saved.games = (saved.games or 0) + 1
    saved.total = (saved.total or 0) + points
    saved.best = math.max(saved.best or 0, points)
    message(string.format("Recorded %.1f FP | %d games | %.1f FP/game", points, saved.games, average()))
    if refreshPanel then refreshPanel() end
end
-- v0.6: Read-only local-player live snapshots. No round aggregation or victory claims.
local currentStats = nil
local function constant(name)
    local ok, value = pcall(function() return _G[name] end)
    return ok and type(value) == "number" and value or nil
end
local function scoreValue(index, name, cumulative, round)
    local id = constant(name)
    if not id then return nil end
    local api = cumulative and "GetBattlegroundCumulativeScoreForScoreboardEntryByType"
        or "GetScoreboardEntryScoreByType"
    local ok, value = guardedCall(api, index, id, round)
    if ok and type(value) == "number" then return value end
    return nil
end
local function isRounds()
    local ok, bg = guardedCall("GetCurrentBattlegroundId")
    if not ok then return false end
    local yes, result = guardedCall("DoesBattlegroundHaveRounds", bg)
    return yes and result == true
end
local function readMedals(index, cumulative, round)
    local medals, complete = 0, true
    if cumulative then
        local ok = guardedCall("GenerateCumulativeMedalInfoForScoreboardEntry", index, round)
        if not ok then return nil end
    end
    local last = nil
    for i=1,150 do
        local ok, id
        if cumulative then
            ok, id = guardedCall("GetNextBattlegroundCumulativeMedalId", last)
        else
            ok, id = guardedCall("GetNextScoreboardEntryMedalId", index, round, last)
        end
        if not ok then complete = false break end
        if id == nil then break end
        if id == last then complete = false break end
        local yes, name = guardedCall("GetMedalInfo", id)
        local counted, count
        if cumulative then
            counted, count = guardedCall("GetBattlegroundCumulativeNumEarnedMedalsById", id)
        else
            counted, count = guardedCall("GetScoreboardEntryNumEarnedMedalsById", index, id, round)
        end
        if not yes or not counted or type(count) ~= "number" then
            complete = false
            break
        end
        -- Only explicitly objective-related medals count; combat medals must not inflate FP.
        local label = tostring(name or ""):lower()
        if label:find("flag",1,true) or label:find("capture",1,true)
            or label:find("defend",1,true) or label:find("chaosball",1,true)
            or label:find("ball carrier",1,true) or label:find("relic",1,true)
            or label:find("objective",1,true) then
            medals = medals + count
        end
        last = id
    end
    return complete and medals or nil
end
-- Raw scoreboard medal score is a single component, not the entire fantasy score.
-- The ESO API constant varies by build; absent values remain unavailable, never zero.
local function cleanPlayerName(name)
    local value=tostring(name or "Player")
    value=value:gsub("|c%x%x%x%x%x%x",""):gsub("|r","")
    value=value:gsub("%^[MmFf][xX]","")
    return value
end

local function medalScore(index, cumulative, round)
    for _, name in ipairs({
        "SCORE_TRACKER_TYPE_MEDAL_SCORE",
        "SCORE_TRACKER_TYPE_MEDALS",
        "SCORE_TRACKER_TYPE_SCORE",
    }) do
        local value = scoreValue(index, name, cumulative, round)
        if value ~= nil then return value end
    end
    return nil
end
local MEDAL_SCORE_DIVISOR = 400 -- 100 medal-score units = 0.25 FP (tunable)
local function readLocalStats()
    local okCount, count = guardedCall("GetNumScoreboardEntries")
    if not okCount or type(count) ~= "number" or count < 1 then return nil end
    local index, team
    for i=1,math.min(count,48) do
        local ok, _, _, alliance, localPlayer = guardedCall("GetScoreboardEntryInfo",i)
        if ok and localPlayer == true then index,team=i,alliance break end
    end
    if not index then return nil end
    local cumulative = isRounds()
    -- ESO's cumulative functions take a round index. Use the current round when available.
    local round
    if cumulative then
        local yes, n = guardedCall("GetCurrentBattlegroundRoundIndex")
        if yes and type(n) == "number" then round=n end
        if not round then
            yes,n = guardedCall("GetCurrentBattlegroundRound")
            if yes and type(n) == "number" then round=n end
        end
    end
    local stats = {index=index,team=team,cumulative=cumulative,round=round}
    local fields = {
        kills="SCORE_TRACKER_TYPE_KILL", deaths="SCORE_TRACKER_TYPE_DEATH",
        damage="SCORE_TRACKER_TYPE_DAMAGE_DONE", healing="SCORE_TRACKER_TYPE_HEALING_DONE",
        assists="SCORE_TRACKER_TYPE_ASSISTS",
    }
    for key, name in pairs(fields) do
        stats[key] = scoreValue(index,name,cumulative,round)
    end
    if stats.assists == nil then
        stats.assists = scoreValue(index,"SCORE_TRACKER_TYPE_ASSIST",cumulative,round)
    end
    if stats.kills == nil or stats.deaths == nil or stats.damage == nil or stats.healing == nil then
        return nil
    end
    stats.medalScore = medalScore(index,cumulative,round)
    stats.carrySeconds = scoreValue(index,"SCORE_TRACKER_TYPE_FLAG_CARRIED_TIME",cumulative,round)
    stats.win = nil
    if team ~= nil then
        local ok,result = guardedCall("GetBattlegroundResultForTeam",team)
        local winConstant = constant("BATTLEGROUND_RESULT_WIN")
        if ok and winConstant and type(result)=="number" then
            stats.win = result == winConstant
        end
    end
    local chaos = false
    local okBg,bg = guardedCall("GetCurrentBattlegroundId")
    if okBg then
        local okMode,mode = guardedCall("GetBattlegroundGameType",bg)
        chaos = okMode and constant("BATTLEGROUND_GAME_TYPE_CHAOS_BALL") == mode
    end
    stats.chaos = chaos
    local carry = chaos and stats.carrySeconds or nil
    stats.partial = stats.kills - stats.deaths + stats.damage/200000 + stats.healing/100000 + healingMilestoneBonus(stats.healing)
        + (stats.assists or 0)*0.5 + (stats.medalScore or 0)/MEDAL_SCORE_DIVISOR
        + (stats.win and 3 or 0)
        + (carry and carry >= 90 and 1.5 or 0)
        + (carry and carry >= 60 and 1 or 0)
    stats.complete = stats.assists ~= nil and stats.medalScore ~= nil
        and stats.win ~= nil and (not cumulative or round ~= nil)
        and (not chaos or stats.carrySeconds ~= nil)
    return stats
end
local function performanceGrade(fp)
    if fp < 5 then return "BAD" end
    if fp < 10 then return "SUBPAR" end
    if fp < 15 then return "AVERAGE" end
    if fp < 20 then return "GOOD" end
    if fp < 25 then return "GREAT" end
    if fp < 35 then return "ELITE" end
    return "LEGENDARY"
end

-- Descriptive scouting identity: compare contribution shares rather than
-- requiring arbitrary achievements. No category is an unlock or rank.
local function playstyle(r)
    if not r then return "UNSCOUTED" end
    local k=math.max(0,tonumber(r.kills) or 0)
    local a=math.max(0,tonumber(r.assists) or 0)
    local d=math.max(0,tonumber(r.deaths) or 0)
    local dmg=math.max(0,tonumber(r.damage) or 0)/200000
    local heal=math.max(0,tonumber(r.healing) or 0)/100000
    local obj=math.max(0,tonumber(r.objectives) or 0)
    local activity=k+a*0.5+dmg+heal+obj
    if activity<=0 then return "UNSCOUTED" end
    local contributions={
        ["HEALER"]=heal,
        ["OBJECTIVE ACE"]=obj,
        ["SLAYER"]=k*(k/(k+a+0.5))*1.3,
        ["PLAYMAKER"]=a*0.5*(a/(k+a+0.5))*1.4,
        ["DAMAGE DEALER"]=dmg,
    }
    -- No reliable damage-taken or mitigation telemetry currently exists.
    -- FRONTLINER is retained as an available archetype but never inferred
    -- from deaths alone; enable it when defensive stats become available.
    local best,bestScore,secondScore="ALL-ROUNDER",0,0
    for role,value in pairs(contributions) do
        local share=value/activity
        if share>bestScore then secondScore=bestScore;bestScore=share;best=role
        elseif share>secondScore then secondScore=share end
    end
    -- A balanced profile has no dominant statistical identity.
    if bestScore<0.42 or (bestScore-secondScore)<0.09 then return "ALL-ROUNDER" end
    return best
end
local function careerPlaystyle(p)
    if not p then return "UNSCOUTED" end
    local t=p.totals or {}
    local g=p.extendedGames or 0
    if g<=0 then return "UNSCOUTED" end
    local role=playstyle({
        kills=t.kills,assists=t.assists,deaths=t.deaths,
        damage=t.damage,healing=t.healing,objectives=t.objectives
    })
    return role
end

-- TME Ranked: independent local rating. Existing ESOFP scoring is unchanged.
-- Rating is a model of this installation's observations, not ESO matchmaking MMR.
local function rankedAverage(p)
    if not p or (p.games or 0)<1 then return nil end
    return (p.total or 0)/p.games
end
local function rankedSeed(avg)
    return math.max(400,math.min(2600,math.floor(1200+35*(avg or 0)+0.5)))
end
local function rankedLossMultiplier(rating,games)
    local extra=0
    if rating>=2500 then extra=2.50
    elseif rating>=2200 then extra=1.75
    elseif rating>=1900 then extra=1.25
    elseif rating>=1600 then extra=0.85
    elseif rating>=1300 then extra=0.50
    elseif rating>=1000 then extra=0.25 end
    games=math.max(0,games or 0)
    if games>=150 then return 1 end
    return 1+extra*math.exp(-games/30)
end
local function rankedExpected(p, enemy, ally)
    local base=rankedAverage(p) or 0
    local enemyFP,allyFP=0,0
    local en,an=0,0
    for _,v in ipairs(enemy or {}) do if type(v)=="number" then enemyFP=enemyFP+v;en=en+1 end end
    for _,v in ipairs(ally or {}) do if type(v)=="number" then allyFP=allyFP+v;an=an+1 end end
    -- Unknown lobby members are not assigned artificial ratings.
    -- With no observations, own average remains the expectation.
    if en==0 and an==0 then return base end
    local adjustment=0
    if en>0 then adjustment=adjustment+0.30*(enemyFP/en-base) end
    if an>0 then adjustment=adjustment-0.15*(allyFP/an-base) end
    return math.max(0,base+adjustment)
end
local function rankedChange(fp,expected,won,enemyRating,ownRating,careerGames)
    local gap=(fp-expected)/math.max(8,math.abs(expected))
    local performance=math.max(-20,math.min(20,15*gap))
    local result=won==true and 14 or won==false and -14*rankedLossMultiplier(ownRating,careerGames) or 0
    local strength=enemyRating and math.max(-8,math.min(8,(enemyRating-ownRating)/90)) or 0
    local delta=result+performance+(won==true and strength or won==false and strength*0.6 or 0)
    delta=math.max(-70,math.min(35,delta))
    return delta>=0 and math.floor(delta+0.5) or math.ceil(delta-0.5)
end
local function rankedPrepareRows(rows)
    local baseline={}
    for _,r in ipairs(rows) do
        local name=tostring(r.name or "")
        local p=saved and saved.players and saved.players[name]
        baseline[name]={avg=rankedAverage(p),rating=p and p.ranked and p.ranked.rating or nil,player=p}
    end
    local updates={}
    for _,r in ipairs(rows) do
        local own=baseline[tostring(r.name or "")]
        local allies,enemies,enemyRatings={},{},{}
        for _,other in ipairs(rows) do
            if other~=r then
                local b=baseline[tostring(other.name or "")]
                if other.team==r.team then if b.avg then allies[#allies+1]=b.avg end
                else
                    if b.avg then enemies[#enemies+1]=b.avg end
                    if b.rating then enemyRatings[#enemyRatings+1]=b.rating end
                end
            end
        end
        -- Filter absent averages; Lua arrays cannot hold nil holes.
        local function known(t)
            local v={}
            for _,n in pairs(t) do if type(n)=="number" then v[#v+1]=n end end
            return v
        end
        local p=own.player
        local avg=own.avg or r.fp or 0
        local expected=rankedExpected(p or {games=1,total=avg},known(enemies),known(allies))
        local rating=own.rating or ((p and (p.games or 0)>0) and rankedSeed(avg) or 1500)
        local enemyRating=nil
        if #enemyRatings>0 then
            local sum=0
            for _,n in ipairs(enemyRatings) do sum=sum+n end
            enemyRating=sum/#enemyRatings
        end
        updates[tostring(r.name or "")]={expected=expected,before=rating,
            delta=rankedChange(r.fp,expected,r.won,enemyRating,rating,p and p.games or 0),
            lobby=enemyRating}
    end
    return updates
end
local function rankedBootstrap()
    if not saved or type(saved.players)~="table" then return end
    for _,p in pairs(saved.players) do
        if not p.ranked then
            local avg=rankedAverage(p)
            if avg then
                local seed=rankedSeed(avg)
                -- Legacy data includes every recorded season. Never invent missing lobby data.
                p.ranked={rating=seed,peak=seed,seed=seed,played=p.games or 0,
                    initializedFromHistory=true,historyBase=p.games or 0,
                    lastDelta=0}
            end
        end
    end
end
local function archivePlayers()
    if not saved or archivedMatch or #teamRows == 0 then return end
    -- Only called after a detected match finish. Archive one snapshot per player.
    saved.players = saved.players or {}
    saved.mvpCount = saved.mvpCount or 0
    local mvp, teamMVPs = nil, {}
    local allComplete = true
    for _, r in ipairs(teamRows) do if not r.complete then allComplete = false break end end
    for _, r in ipairs(teamRows) do
        if allComplete and (not mvp or r.fp > mvp.fp) then mvp = r end
        local t = tostring(r.team or "?")
        if allComplete and (not teamMVPs[t] or r.fp > teamMVPs[t].fp) then teamMVPs[t] = r end
    end
    rankedBootstrap()
    local rankedUpdates=rankedPrepareRows(teamRows)
    local encountered = {}
    for _, r in ipairs(teamRows) do
        -- One record per player per match, regardless of which side they played on.
        -- ESO's scoreboard name is our stable available key until account IDs are verified.
        local key = tostring(r.name or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
        if key ~= "" and not encountered[key] then
        encountered[key] = true
        local p = saved.players[key] or {games=0,total=0,best=nil,mvps=0,teamMvps=0}
        local ru=rankedUpdates[key]
        if ru then
            local rank=p.ranked or {rating=ru.before,peak=ru.before,seed=ru.before,
                played=p.games or 0,historyBase=p.games or 0}
            rank.rating=math.max(0,rank.rating+ru.delta)
            rank.peak=math.max(rank.peak or rank.rating,rank.rating)
            rank.lastDelta=ru.delta
            rank.lastExpected=ru.expected
            rank.lastLobbyRating=ru.lobby
            rank.played=(rank.played or 0)+1
            p.ranked=rank
        end
        -- Match-index based last-seen tracking, independent of wall-clock accuracy.
        p.lastSeenMatchId=saved.nextMatchId or 1
        p.lastSeenAt=type(GetTimeStamp)=="function" and GetTimeStamp() or nil
        p.games = p.games + 1
        p.total = p.total + r.fp
        p.best = math.max(p.best or r.fp, r.fp)
        p.last = r.fp
        p.lastComplete = r.complete == true
        p.completeGames = (p.completeGames or 0) + (r.complete and 1 or 0)
        p.medalScore = r.medalScore
        p.lastArchetype = playstyle(r)
        p.recent=p.recent or {}
        p.recent[#p.recent+1]={fp=r.fp,kills=r.kills,assists=r.assists,deaths=r.deaths,
            damage=r.damage,healing=r.healing,team=r.team,won=r.won,complete=r.complete == true}
        while #p.recent>20 do table.remove(p.recent,1) end
        -- v1.9.6: optional extended match history; legacy records remain valid.
        -- v2.1 permanent per-match box scores, independent of rolling recent form.
        -- Preserve all legacy career aggregates; no retroactive fabricated games.
        p.gameLog=p.gameLog or {}
        p.gameLog[#p.gameLog+1]={
            matchId=saved.nextMatchId or 1, timestamp=type(GetTimeStamp)=="function" and GetTimeStamp() or nil,
            fp=r.fp,kills=r.kills,assists=r.assists,deaths=r.deaths,
            damage=r.damage,healing=r.healing,medalScore=r.medalScore,
            objectives=r.objectives,team=r.team,won=r.won,complete=r.complete==true,
            archetype=playstyle(r),grade=r.grade,
            rankedDelta=ru and ru.delta or nil,
            rankedExpected=ru and ru.expected or nil,
            rankedLobby=ru and ru.lobby or nil,
        }
        p.lastStats = {
            fp=r.fp, kills=r.kills, assists=r.assists, deaths=r.deaths,
            damage=r.damage, healing=r.healing, medalScore=r.medalScore,
            complete=r.complete == true,
        }
        p.highs = p.highs or {}
        p.totals = p.totals or {}
        for _,field in ipairs({"kills","assists","deaths","damage","healing","medalScore","objectives"}) do
            local value=r[field]
            if type(value)=="number" then
                p.highs[field]=math.max(p.highs[field] or value,value)
                p.totals[field]=(p.totals[field] or 0)+value
            end
        end
        p.extendedGames=(p.extendedGames or 0)+1
        p.archetype=careerPlaystyle(p)
        p.mvps = p.mvps + ((mvp == r) and 1 or 0)
        p.provisionalGames = (p.provisionalGames or 0) + (r.complete and 0 or 1)
        p.teamMvps = p.teamMvps + ((teamMVPs[tostring(r.team or "?")] == r) and 1 or 0)
        saved.players[key] = p
        end
    end
    saved.nextMatchId=(saved.nextMatchId or 1)+1
    saved.matchReports=saved.matchReports or {}
    local report={mvp=mvp and mvp.name or nil,teamTotals={},players=#teamRows}
    for _,r in ipairs(teamRows) do
        local team=tostring(r.team or "?")
        report.teamTotals[team]=(report.teamTotals[team] or 0)+(r.fp or 0)
    end
    saved.matchReports[#saved.matchReports+1]=report
    while #saved.matchReports>25 do table.remove(saved.matchReports,1) end
    saved.lastMVP = mvp and mvp.name or nil
    saved.lastMVPProvisional = not allComplete
    saved.lastMVPScore = mvp and mvp.fp or nil
    saved.lastTeamMVPs = {}
    for team, r in pairs(teamMVPs) do saved.lastTeamMVPs[team] = r.name end
    archivedMatch = true
end

local function updateTeamRows()
    local ok, count = guardedCall("GetNumScoreboardEntries")
    if not ok or type(count) ~= "number" or count < 1 then return end
    local rows = {}
    local cumulative = isRounds()
    local round
    if cumulative then
        local yes, value = guardedCall("GetCurrentBattlegroundRoundIndex")
        if yes and type(value) == "number" then round = value end
    end
    local bgOK, bg = guardedCall("GetCurrentBattlegroundId")
    local modeOK, mode = false, nil
    if bgOK then modeOK, mode = guardedCall("GetBattlegroundGameType", bg) end
    local chaosType = constant("BATTLEGROUND_GAME_TYPE_CHAOS_BALL")
    local chaos = modeOK and chaosType ~= nil and mode == chaosType
    local winType = constant("BATTLEGROUND_RESULT_WIN")
    local lossType = constant("BATTLEGROUND_RESULT_LOSS")
    for i = 1, math.min(count, 48) do
        local yes, name, _, team, isLocal = guardedCall("GetScoreboardEntryInfo", i)
        if yes then
            local k = scoreValue(i, "SCORE_TRACKER_TYPE_KILL", cumulative, round)
            local d = scoreValue(i, "SCORE_TRACKER_TYPE_DEATH", cumulative, round)
            local dmg = scoreValue(i, "SCORE_TRACKER_TYPE_DAMAGE_DONE", cumulative, round)
            local heal = scoreValue(i, "SCORE_TRACKER_TYPE_HEALING_DONE", cumulative, round)
            local assists = scoreValue(i, "SCORE_TRACKER_TYPE_ASSISTS", cumulative, round)
            if assists == nil then assists = scoreValue(i, "SCORE_TRACKER_TYPE_ASSIST", cumulative, round) end
            if k ~= nil and d ~= nil and dmg ~= nil and heal ~= nil then
                local medals = medalScore(i, cumulative, round)
                local won = nil
                if team ~= nil and winType ~= nil then
                    local resultOK, result = guardedCall("GetBattlegroundResultForTeam", team)
                    if resultOK and type(result) == "number" then
                        if result == winType then won=true
                        elseif lossType ~= nil and result == lossType then won=false end
                    end
                end
                local carry = chaos and scoreValue(i, "SCORE_TRACKER_TYPE_FLAG_CARRIED_TIME", cumulative, round) or nil
                local bonus90 = carry ~= nil and carry >= 90
                local bonus60 = carry ~= nil and carry >= 60
                local fp = k-d+dmg/200000+heal/100000+healingMilestoneBonus(heal)+(assists or 0)*0.5
                    +(medals or 0)/MEDAL_SCORE_DIVISOR+(won and 3 or 0)
                    +(bonus90 and 1.5 or 0)+(bonus60 and 1 or 0)
                local complete = assists ~= nil and medals ~= nil and won ~= nil
                    and (not cumulative or round ~= nil) and (not chaos or carry ~= nil)
                rows[#rows+1] = {name=cleanPlayerName(name), team=team,
                    localPlayer=isLocal == true, fp=fp, complete=complete,
                    grade=complete and performanceGrade(fp) or "PROVISIONAL",
                    kills=k, deaths=d, assists=assists, damage=dmg, healing=heal,
                    medalScore=medals, objectives=medals and medals/MEDAL_SCORE_DIVISOR or nil, won=won, carrySeconds=carry}
            end
        end
    end
    table.sort(rows, function(a,b)
        if a.team ~= b.team then return tostring(a.team) < tostring(b.team) end
        return a.fp > b.fp
    end)
    if #rows > 0 and not archivedMatch then teamRows = rows end
end

local function updateLiveStats()
    -- Scoreboard event is the update trigger; do not scan global functions or chat-spam.
    local ok, stats = pcall(readLocalStats)
    if ok and stats then
        currentStats = stats
        lastMatchSnapshot = stats
        updateTeamRows()
        if match.active then match.snapshots = match.snapshots + 1 end
    end
    if refreshPanel then refreshPanel() end
end

local panel, panelText
-- v1.9 presentation only. Do not alter saved-variable schema or scoring math.
local function displayName(raw,limit)
    local name=cleanPlayerName(raw):gsub("\n"," "):gsub("\r"," ")
    if #name>limit then name=name:sub(1,limit-3).."..." end
    return name
end
local function sortedHistory()
    local peers={}
    if saved and type(saved.players)=="table" then
        for name,p in pairs(saved.players) do
            if type(p)=="table" and (p.games or 0)>0 then
                peers[#peers+1]={name=displayName(name,80),avg=(p.total or 0)/p.games,
                    games=p.games,mvps=p.mvps or 0,provisional=p.provisionalGames or 0}
            end
        end
    end
    table.sort(peers,function(a,b)
        if a.avg~=b.avg then return a.avg>b.avg end
        if a.games~=b.games then return a.games>b.games end
        return a.name:lower()<b.name:lower()
    end)
    return peers
end
-- v2.0 scouting views use stored observations, never fabricated match history.
local scoutingPage=1
local scoutingModes={"SCOUT","FORM","COMPARE","REPORT","TEAMS","RECORDS"}
local function playerAvg(p)
    return p and (p.games or 0)>0 and (p.total or 0)/p.games or 0
end
local function scoutingGrade(p)
    local g=p and (p.extendedGames or 0) or 0
    if g<3 then return "INSUFFICIENT DATA" end
    local peers=sortedHistory()
    local avg=playerAvg(p)
    local above=0
    for _,peer in ipairs(peers) do if avg>=peer.avg then above=above+1 end end
    local pct=#peers>0 and above/#peers or 0
    return pct>=0.90 and "A" or pct>=0.70 and "B" or pct>=0.40 and "C" or "D"
end
local function scoutLines()
    local lines={"TME INTELLIGENCE  /  "..viewMode,""}
    local peers=sortedHistory()
    local total=#peers
    if viewMode=="SCOUT" then
        local pages=math.max(1,math.ceil(total/7));scoutingPage=math.min(scoutingPage,pages)
        lines[#lines+1]=string.format("KNOWN PLAYERS %d   /   PAGE %d OF %d",total,scoutingPage,pages)
        lines[#lines+1]="FP/G   GAMES   GRADE   ARCHETYPE   PLAYER"
        for i=(scoutingPage-1)*7+1,math.min(total,scoutingPage*7) do
            local x=peers[i];local p=saved.players[x.name]
            lines[#lines+1]=string.format("%5.1f  %3d     %-5s  %-13s %s",x.avg,x.games,
                scoutingGrade(p),displayName(careerPlaystyle(p),13),displayName(x.name,18))
        end
        lines[#lines+1]="Grade: relative FP/G rank among observed players; 3 detailed games minimum"
    elseif viewMode=="FORM" then
        local p=(function() local ok,n=guardedCall("GetUnitName","player");return ok and saved.players and saved.players[cleanPlayerName(n)] end)()
        local recent=p and p.recent or {}
        lines[#lines+1]="YOUR RECENT MATCHES (NEW RECORDS ONLY)"
        local sum=0
        for i=math.max(1,#recent-9),#recent do
            local r=recent[i];sum=sum+(r.fp or 0)
            lines[#lines+1]=string.format("MATCH %d   %.1f FP    K %s  A %s  D %s",i,r.fp or 0,
                compact(r.kills),compact(r.assists),compact(r.deaths))
        end
        if #recent==0 then lines[#lines+1]="No detailed match history yet" end
        if #recent>0 then
            local count=math.min(#recent,10)
            lines[#lines+1]=string.format("LAST %d AVG  %.1f FP/G  /  CAREER %.1f",count,sum/count,playerAvg(p))
        end
    elseif viewMode=="COMPARE" then
        local me=(function() local ok,n=guardedCall("GetUnitName","player");return ok and saved.players and saved.players[cleanPlayerName(n)] end)()
        local mine=playerAvg(me)
        local pages=math.max(1,math.ceil(total/7));scoutingPage=math.min(scoutingPage,pages)
        lines[#lines+1]=string.format("YOUR FP/G %.1f   /   PAGE %d OF %d",mine,scoutingPage,pages)
        lines[#lines+1]="PLAYER                 FP/G    VS YOU   GAMES"
        for i=(scoutingPage-1)*7+1,math.min(total,scoutingPage*7) do
            local x=peers[i]
            lines[#lines+1]=string.format("%-22s %5.1f   %+5.1f   %d",displayName(x.name,22),x.avg,x.avg-mine,x.games)
        end
    elseif viewMode=="REPORT" then
        local reports=saved.matchReports or {}
        lines[#lines+1]="POSTGAME REPORT ARCHIVE"
        for i=#reports,math.max(1,#reports-6),-1 do
            local r=reports[i]
            local parts={}
            for team,fp in pairs(r.teamTotals or {}) do parts[#parts+1]=team.." "..string.format("%.1f",fp) end
            table.sort(parts)
            lines[#lines+1]=string.format("GAME %d   MVP %s",i,displayName(r.mvp or "UNCONFIRMED",23))
            lines[#lines+1]="   "..table.concat(parts,"  /  ")
        end
        if #reports==0 then lines[#lines+1]="Finish a match to generate the first report" end
    elseif viewMode=="TEAMS" then
        lines[#lines+1]="LIVE THREE-TEAM FANTASY TRACKER"
        local totals={};local counts={}
        for _,r in ipairs(teamRows) do
            local team=tostring(r.team or "?")
            totals[team]=(totals[team] or 0)+(r.fp or 0)
            counts[team]=(counts[team] or 0)+1
        end
        local teams={}
        for team,fp in pairs(totals) do teams[#teams+1]={name=team,fp=fp} end
        table.sort(teams,function(a,b)return a.fp>b.fp end)
        for i,t in ipairs(teams) do
            lines[#lines+1]=string.format("%d. TEAM %-12s %7.1f FP   %d PLAYERS",i,t.name,t.fp,counts[t.name])
        end
        if #teams==0 then lines[#lines+1]="Awaiting live Battleground scoreboard" end
        lines[#lines+1]="Fantasy totals are not objective-match scores"
    elseif viewMode=="RECORDS" then
        lines[#lines+1]="TME HALL OF FAME  /  OBSERVED RECORDS"
        local categories={{"BEST FP","best"},{"KILLS","kills"},{"DAMAGE","damage"},{"HEALING","healing"},{"ASSISTS","assists"}}
        for _,c in ipairs(categories) do
            local best,name=nil,nil
            for player,p in pairs(saved.players or {}) do
                local value=c[2]=="best" and p.best or p.highs and p.highs[c[2]]
                if type(value)=="number" and (not best or value>best) then best=value;name=player end
            end
            lines[#lines+1]=string.format("%-12s %-9s %s",c[1],best and (c[2]=="best" and string.format("%.1f",best) or compact(best)) or "--",displayName(name or "UNRECORDED",25))
        end
        lines[#lines+1]="Category records reflect available detailed matches"
    end
    lines[#lines+1]=""
    lines[#lines+1]="L1 PREV  /  R1 NEXT  /  RADIAL TO CHANGE VIEW"
    return table.concat(lines,"\n")
end
-- v2.1 gamepad player cards and permanent match logs.
local selectedPlayerIndex=1
local selectedPlayerName=nil
local selectedLogIndex=1
local profileTab=1 -- 1 career, 2 game log, 3 records
local function profilePlayer()
    return saved and saved.players and selectedPlayerName and saved.players[selectedPlayerName]
end
local function selectHistoryPlayer()
    local peers=sortedHistory()
    local entry=peers[selectedPlayerIndex]
    if not entry then return end
    selectedPlayerName=entry.name
    -- Exact saved key may include formatting; find normalized match.
    if not (saved.players and saved.players[selectedPlayerName]) then
        for key in pairs(saved.players or {}) do
            if cleanPlayerName(key)==cleanPlayerName(entry.name) then
                selectedPlayerName=key;break
            end
        end
    end
    selectedLogIndex=1;profileTab=1;viewMode="PLAYER"
end
local function profilePanelLines()
    local p=profilePlayer()
    if not p then return "PLAYER PROFILE\nNo saved player selected" end
    local g=p.games or 0
    local logs=p.gameLog or {}
    local lines={
        "TME PLAYER CARD   /   "..displayName(selectedPlayerName,45),
        string.format("%d GAMES     %.1f FP/G     BEST %.1f FP     %s",g,playerAvg(p),p.best or 0,p.archetype or "UNSCOUTED"),
        "L1 / R1: TABS    USE MENU: OPEN SELECTED / BACK",
        "--------------------------------------------------------------------",
    }
    if profileTab==1 then
        lines[#lines+1]="[ CAREER ]       GAME LOG       RECORDS"
        lines[#lines+1]=string.format("TOTAL FANTASY POINTS  %.1f      MVP AWARDS  %d",(p.total or 0),p.mvps or 0)
        local n=p.extendedGames or 0;local t=p.totals or {}
        if n>0 then
            lines[#lines+1]=string.format("AVERAGES / GAME   K %.1f   A %.1f   D %.1f",(t.kills or 0)/n,(t.assists or 0)/n,(t.deaths or 0)/n)
            lines[#lines+1]=string.format("DMG %s    HEAL %s",compact((t.damage or 0)/n),compact((t.healing or 0)/n))
        else lines[#lines+1]="Detailed averages unavailable for legacy matches" end
        lines[#lines+1]=""
        lines[#lines+1]=string.format("%d recorded detailed game logs; %d earlier career games may lack logs",#logs,math.max(0,g-#logs))
    elseif profileTab==2 then
        lines[#lines+1]="CAREER       [ GAME LOG ]       RECORDS"
        lines[#lines+1]="SELECT    GAME      K / A / D        DMG       HEAL       FP"
        lines[#lines+1]="--------------------------------------------------------------------"
        for i=math.max(1,selectedLogIndex-3),math.min(#logs,selectedLogIndex+4) do
            local r=logs[#logs-i+1]
            lines[#lines+1]=string.format("%s %3d       %s/%s/%s        %s      %s      %.1f",
                i==selectedLogIndex and ">" or " ",r.matchId or i,
                fmt(r.kills),r.assists and fmt(r.assists) or "--",fmt(r.deaths),
                compact(r.damage or 0),compact(r.healing or 0),r.fp or 0)
        end
        if #logs==0 then lines[#lines+1]="No individual game logs yet. Complete a new Battleground." end
        lines[#lines+1]="Use menu: Previous / Next Player or Game; Open Highlighted Player"
    else
        lines[#lines+1]="CAREER       GAME LOG       [ RECORDS ]"
        local h=p.highs or {}
        lines[#lines+1]=string.format("BEST FP   %.1f        MOST KILLS   %s",p.best or 0,h.kills and fmt(h.kills) or "--")
        lines[#lines+1]=string.format("MOST ASSISTS   %s        MOST DAMAGE   %s",h.assists and fmt(h.assists) or "--",h.damage and compact(h.damage) or "--")
        lines[#lines+1]=string.format("MOST HEALING   %s       MOST MEDALS   %s",h.healing and compact(h.healing) or "--",h.medalScore and compact(h.medalScore) or "--")
        lines[#lines+1]="Category records cover only matches with detailed telemetry"
    end
    return table.concat(lines,"\n")
end
local function gameDetailLines()
    local p=profilePlayer();local logs=p and p.gameLog or {}
    local r=logs[#logs-selectedLogIndex+1]
    if not r then return "No saved game available" end
    local lines={
        "TME Network   /   INDIVIDUAL GAME BOX SCORE",
        displayName(selectedPlayerName or "PLAYER",40),
        string.format("MATCH %d     %s     %s",r.matchId or selectedLogIndex,
            r.complete and "FINAL" or "PROVISIONAL",r.archetype or "UNSCOUTED"),
        "--------------------------------------------------------------------",
        string.format("FANTASY POINTS     %.1f FP",r.fp or 0),
        string.format("KILLS %s      ASSISTS %s      DEATHS %s",fmt(r.kills),r.assists and fmt(r.assists) or "--",fmt(r.deaths)),
        string.format("DAMAGE %s      HEALING %s",compact(r.damage or 0),compact(r.healing or 0)),
        string.format("MEDAL SCORE %s      OBJECTIVES %s",r.medalScore and fmt(r.medalScore) or "--",r.objectives and fmt(r.objectives) or "--"),
        string.format("TEAM %s      GRADE %s",tostring(r.team or "--"),tostring(r.grade or "--")),
        "BACK: GAME LOG    /    Legacy matches cannot be reconstructed",
    }
    return table.concat(lines,"\n")
end

-- Career Home v3.3. The first 18 lifetime games are Season 1, even when
-- legacy detailed logs are missing. Never invent historical results.
local careerSeasonPage=1
local function ownCareer()
    if not saved or type(saved.players)~="table" then return nil end
    local ok,name=guardedCall("GetUnitName","player")
    if ok and name then return saved.players[cleanPlayerName(name)] end
    return nil
end
local function seasonStats(p,n)
    local games=p and p.games or 0
    local start=(n-1)*18+1
    local finish=math.min(n*18,games)
    local count=math.max(0,finish-start+1)
    local logs=p and p.gameLog or {}
    local offset=math.max(0,games-#logs)
    local a={games=count,logged=0,wins=0,losses=0,unknown=0,fp=0,kills=0,assists=0,deaths=0,damage=0,healing=0,fpSeries={}}
    for i=start,finish do
        local r=logs[i-offset]
        if r then
            a.logged=a.logged+1
            a.fp=a.fp+(r.fp or 0)
            a.kills=a.kills+(r.kills or 0)
            a.assists=a.assists+(r.assists or 0)
            a.deaths=a.deaths+(r.deaths or 0)
            a.damage=a.damage+(r.damage or 0)
            a.healing=a.healing+(r.healing or 0)
            a.fpSeries[#a.fpSeries+1]=r.fp or 0
            if r.won==true then a.wins=a.wins+1
            elseif r.won==false then a.losses=a.losses+1
            else a.unknown=a.unknown+1 end
        else a.unknown=a.unknown+1 end
    end
    return a
end
local function observedTrend(p)
    local logs=p and p.gameLog or {}
    if #logs<4 then return "TREND: More detailed matches needed to establish form." end
    local count=math.min(5,math.floor(#logs/2))
    local recent,previous=0,0
    for i=#logs-count+1,#logs do recent=recent+(logs[i].fp or 0) end
    for i=#logs-2*count+1,#logs-count do previous=previous+(logs[i].fp or 0) end
    local change=(recent-previous)/count
    if change>2 then return string.format("FORM: Rising (+%.1f FP/G vs previous %d games).",change,count)
    elseif change< -2 then return string.format("FORM: Cooling (%.1f FP/G vs previous %d games).",change,count)
    else return "FORM: Steady fantasy production across recent matches." end
end
local function playstyleObservations(p)
    local t=p and p.totals or {}
    local g=p and p.extendedGames or 0
    if g<2 then return "SCOUTING: Record more matches to develop a reliable playstyle assessment." end
    local k=(t.kills or 0)/g
    local a=(t.assists or 0)/g
    local d=(t.deaths or 0)/g
    local dmg=(t.damage or 0)/g
    local heal=(t.healing or 0)/g
    local role=careerPlaystyle(p)
    local desc
    if heal>250000 and heal>dmg*0.7 then desc="Healing is a major part of your contribution; team sustain is your signature."
    elseif dmg>500000 and k>=6 then desc="High damage and finishing power define your offensive identity."
    elseif a>k then desc="You create value through assists and supporting teammates."
    else desc="Your production is spread across multiple combat categories." end
    local risk=d>=8 and "Deaths are a major cost to your fantasy efficiency."
        or d<=3 and "Low deaths help protect your fantasy floor."
        or "Your survival rate leaves room to improve consistency."
    return string.format("SCOUTING: %s. %s",role,desc).."\n"..risk
end
local function careerHomeLines()
    local p=ownCareer()
    if not p then return "CAREER HOME\n\nNo character history found under the current name.\nComplete a Battleground to begin your record." end
    local games=p.games or 0
    local total=p.total or 0
    local all={wins=0,losses=0,unknown=0}
    for i=1,math.max(1,math.ceil(games/18)) do
        local a=seasonStats(p,i)
        all.wins=all.wins+a.wins;all.losses=all.losses+a.losses;all.unknown=all.unknown+a.unknown
    end
    local current=math.max(1,math.ceil(math.max(1,games)/18))
    local a=seasonStats(p,current)
    local lines={
        "CAREER HOME","",
        string.format("BG RATING   %d    %s%d LAST    PEAK %d",
            (p.ranked or {}).rating or rankedSeed(games>0 and total/games or 0),
            ((p.ranked or {}).lastDelta or 0)>=0 and "+" or "",
            (p.ranked or {}).lastDelta or 0,
            (p.ranked or {}).peak or rankedSeed(games>0 and total/games or 0)),
        string.format("CAREER  %d GAMES     %.1f FP/G     %.1f TOTAL FP",games,games>0 and total/games or 0,total),
        string.format("BEST %.1f FP     MVP AWARDS %d     %s",p.best or 0,p.mvps or 0,careerPlaystyle(p)),
        string.format("BG RECORD  %d W  /  %d L",all.wins,all.losses),"",
        string.format("SEASON %d  /  GAME %d OF 18",current,((math.max(1,games)-1)%18)+1),
                string.format("SEASON W-L  %d-%d",a.wins,a.losses),
        a.logged>0 and string.format("SEASON FORM %.1f FP/G  |  %d K  %d A  %d D",a.fp/a.logged,a.kills,a.assists,a.deaths)
            or "","",
        observedTrend(p),playstyleObservations(p),"",
        "LIFETIME TOTALS",
        string.format("K %d   A %d   D %d   DAMAGE %s   HEALING %s",
            (p.totals or {}).kills or 0,(p.totals or {}).assists or 0,(p.totals or {}).deaths or 0,
            compact((p.totals or {}).damage or 0),compact((p.totals or {}).healing or 0)),
        
    }
    return table.concat(lines,"\n")
end
local function seasonReviewLines()
    local p=ownCareer()
    if not p then return "SEASONS\n\nNo recorded career yet." end
    local games=p.games or 0
    local maxSeason=math.max(1,math.ceil(math.max(1,games)/18))
    careerSeasonPage=math.min(math.max(1,careerSeasonPage),maxSeason)
    local a=seasonStats(p,careerSeasonPage)
    local lines={
        string.format("SEASON %d  /  %d   |   %d OF 18 GAMES",careerSeasonPage,maxSeason,a.games),"",
        string.format("BATTLEGROUND RECORD  %d W  -  %d L",a.wins,a.losses),
                a.logged>0 and string.format("SEASON FP %.1f   |   %.1f FP/G",a.fp,a.fp/a.logged) or "",
        a.logged>0 and string.format("K %d   A %d   D %d   DMG %s   HEAL %s",a.kills,a.assists,a.deaths,compact(a.damage),compact(a.healing)) or "",
        "",
        "THE SEASON STORY"
    }
    if a.logged==0 then
        lines[#lines+1]="Career season."
    else
        local early,late=0,0
        local half=math.floor(#a.fpSeries/2)
        for i=1,half do early=early+a.fpSeries[i] end
        for i=half+1,#a.fpSeries do late=late+a.fpSeries[i] end
        if half>0 and #a.fpSeries-half>0 then
            local delta=late/(#a.fpSeries-half)-early/half
            lines[#lines+1]=delta>2 and "Your fantasy production improved as this season progressed."
                or delta< -2 and "Your fantasy production declined in the later recorded games."
                or "Your fantasy production stayed relatively consistent."
        else lines[#lines+1]="The season's story is still taking shape." end
        lines[#lines+1]=a.games==18 and "18 games completed: season closed." or "Season in progress."
    end
    lines[#lines+1]=""
    return table.concat(lines,"\n")
end
local function panelLines()
    if viewMode=="CAREER" then return careerHomeLines() end
    if viewMode=="SEASONS" then return seasonReviewLines() end
    if viewMode=="PLAYER" then return profilePanelLines() end
    if viewMode=="GAME" then return gameDetailLines() end
    if viewMode~="MATCH" and viewMode~="HISTORY" then return scoutLines() end
    local s,avg=currentStats or lastMatchSnapshot,average()
    local mine=ownCareer()
    local myRating=mine and mine.ranked and mine.ranked.rating
    local lines={
        string.format("BG RATING   %s     %s",
            myRating and tostring(myRating) or "--",
            mine and mine.ranked and string.format("LAST %+d",mine.ranked.lastDelta or 0) or "NO HISTORY"),
        string.format("YOUR SCORE   %s FP        CAREER   %s FP/G        %d GAMES",
            s and string.format("%.1f",s.partial) or "--",
            avg and string.format("%.1f",avg) or "--",saved and saved.games or 0),
        s and string.format("K %d     A %s     D %d     DMG %s     HEAL %s",
            s.kills,s.assists and fmt(s.assists) or "?",s.deaths,fmt(s.damage),fmt(s.healing))
            or "Waiting for a Battleground", "",
    }
    if viewMode=="HISTORY" then
        local peers=sortedHistory()
        local perPage=9
        local pages=math.max(1,math.ceil(#peers/perPage))
        historyPage=math.min(math.max(1,historyPage),pages)
        lines[#lines+1]=string.format("SCOUTING REPORT  /  %d PLAYERS  /  PAGE %d OF %d",#peers,historyPage,pages)
        lines[#lines+1]="RANK   FP/G   GAMES   MVP    PLAYER"
        lines[#lines+1]="--------------------------------------------------------"
        lines[#lines+1]="L1 / R1 SELECT PLAYER     X OPEN PROFILE"
        for i=(historyPage-1)*perPage+1,math.min(historyPage*perPage,#peers) do
            local p=peers[i]
            lines[#lines+1]=string.format("%s%3d   %5.1f     %3d    %3d    %s%s",i==selectedPlayerIndex and ">" or " ",i,p.avg,p.games,p.mvps,
                displayName(p.name,25),p.provisional>0 and " *" or "")
        end
        if #peers==0 then lines[#lines+1]="No scouting records yet" end
        lines[#lines+1]=""
        lines[#lines+1]="* Some match components were provisional"
        lines[#lines+1]="Ranked by FP/G, then games played, then name"
    else
        local perPage=9
        local pages=math.max(1,math.ceil(#teamRows/perPage))
        scoreboardPage=math.min(math.max(1,scoreboardPage),pages)
        lines[#lines+1]=string.format("LIVE LEADERBOARD  /  PAGE %d OF %d",scoreboardPage,pages)
        lines[#lines+1]="RANK     FP     K/A/D       GRADE      PLAYER"
        lines[#lines+1]="--------------------------------------------------------"
        for i=(scoreboardPage-1)*perPage+1,math.min(scoreboardPage*perPage,#teamRows) do
            local r=teamRows[i]
            local name=displayName(r.name,23)
            local mark=r.localPlayer and ">" or " "
            lines[#lines+1]=string.format("%s%2d    %5.1f    %d/%s/%d    %-9s %s%s",mark,i,r.fp,r.kills,
                r.assists and fmt(r.assists) or "?",r.deaths,
                r.complete and r.grade or "PARTIAL",name,r.complete and "" or " *")
        end
        if #teamRows==0 then lines[#lines+1]="Waiting for live scoreboard data" end
        lines[#lines+1]=""
        lines[#lines+1]="Medal score included in FP when available"
        lines[#lines+1]="* Provisional where components are unavailable"
    end
    lines[#lines+1]=""
    lines[#lines+1]="L1 PREV   /   R1 NEXT (IF SUPPORTED)   /   RADIAL WHEEL"
    return table.concat(lines,"\n")
end

local panelArtwork
refreshPanel = function()
    if panelArtwork then
        local scout=(viewMode=="HISTORY" or viewMode=="PLAYER" or viewMode=="GAME" or viewMode=="CAREER" or viewMode=="SEASONS")
        panelArtwork.dashboard:SetHidden(scout)
        panelArtwork.scouting:SetHidden(not scout)
    end
    if panelText then panelText:SetText(panelLines()) end
end
local function makePanel()
    if panel then return true end
    if not WINDOW_MANAGER or type(WINDOW_MANAGER.CreateTopLevelWindow) ~= "function" then
        message("Dashboard unavailable; chat commands still work.")
        return false
    end
    local ok, err = pcall(function()
        local w = WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyStatusPanel")
        w:SetDimensions(1060, 760)
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        w:SetClampedToScreen(true)
        w:SetMouseEnabled(false)
        w:SetHidden(true)
        local bg = WINDOW_MANAGER:CreateControl("ESOFantasyStatusBackground", w, CT_BACKDROP)
        bg:SetAnchorFill(w)
        bg:SetCenterColor(0, 0, 0, 0)
        bg:SetEdgeColor(0, 0, 0, 0)
        -- v2.9: original blank art templates; live data is still drawn as native labels.
        local art=WINDOW_MANAGER:CreateControl("ESOFantasyDashboardArt",w,CT_TEXTURE)
        art:SetAnchorFill(w)
        art:SetTexture("ESOFantasy/textures/dashboard.dds")
        art:SetAlpha(1)
        art:SetDrawLayer(DL_BACKGROUND)
        art:SetDrawLevel(1)
        local scoutingArt=WINDOW_MANAGER:CreateControl("ESOFantasyScoutingArt",w,CT_TEXTURE)
        scoutingArt:SetAnchorFill(w)
        scoutingArt:SetTexture("ESOFantasy/textures/scouting.dds")
        scoutingArt:SetAlpha(1)
        scoutingArt:SetDrawLayer(DL_BACKGROUND)
        scoutingArt:SetDrawLevel(2)
        -- Mode-dependent graphic backgrounds share the same real leaderboard text.
        panelArtwork={dashboard=art,scouting=scoutingArt}
        -- Decorative native rules retained for contrast on consoles.

        local function stripe(id, anchor, offsetX, offsetY, width, height, r, g, b)
            local t=WINDOW_MANAGER:CreateControl(id,w,CT_TEXTURE)
            t:SetAnchor(anchor,w,anchor,offsetX,offsetY)
            t:SetDimensions(width,height)
            t:SetColor(r,g,b,1)
            return t
        end
        local function heading(id,text,x,y,width,height,font,r,g,b)
            local t=WINDOW_MANAGER:CreateControl(id,w,CT_LABEL)
            t:SetAnchor(TOPLEFT,w,TOPLEFT,x,y)
            t:SetDimensions(width,height)
            t:SetFont(font)
            t:SetColor(r,g,b,1)
            t:SetText(text)
            return t
        end
        heading("ESOFantasyTitle","FANTASY ESO",68,27,570,45,"$(BOLD_FONT)|33|soft-shadow-thick",0.98,0.80,0.36)
        heading("ESOFantasySubtitle","TME Network  /  EVERY BATTLEGROUND IS GAME DAY",68,68,800,26,"$(BOLD_FONT)|16|soft-shadow-thick",0.69,0.79,0.87)
        heading("ESOFantasyShield","[ TME ]",870,22,150,45,"$(BOLD_FONT)|27|soft-shadow-thick",0.98,0.80,0.36)
        -- No SetEdgeTexture: nil with 3px dimensions throws on PS5.
        local label = WINDOW_MANAGER:CreateControl("ESOFantasyStatusText", w, CT_LABEL)
        label:SetAnchor(TOPLEFT, w, TOPLEFT, 66, 128)
        label:SetDimensions(930, 575)
        label:SetFont("$(BOLD_FONT)|21|soft-shadow-thick")
        label:SetColor(0.97, 0.86, 0.62, 1)
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        panel, panelText = w, label
        refreshPanel()
    end)
    if not ok then
        panel, panelText = nil, nil
        message("Dashboard initialization failed: " .. tostring(err))
        return false
    end
    return true
end
-- Controller paging uses ESO's gamepad keybind strip when available.
-- Keep the settings buttons and radial actions as reliable alternatives.
local shoulderBindings
local shoulderActive=false
local function pageBy(delta)
    if not panel or panel:IsHidden() then return end
    if viewMode=="HISTORY" then
        local count=#sortedHistory()
        if count>0 then
            selectedPlayerIndex=math.max(1,math.min(count,selectedPlayerIndex+delta))
            historyPage=math.ceil(selectedPlayerIndex/9)
        end
        refreshPanel();return
    end
    if viewMode=="PLAYER" then
        if profileTab==2 then
            local p=profilePlayer();local n=p and #(p.gameLog or {}) or 0
            if n>0 then selectedLogIndex=math.max(1,math.min(n,selectedLogIndex+delta)) end
        else
            profileTab=math.max(1,math.min(3,profileTab+delta))
        end
        refreshPanel();return
    end
    if viewMode=="GAME" then return end
    if viewMode ~= "MATCH" and viewMode ~= "HISTORY" then
        local pages=math.max(1,math.ceil(#sortedHistory()/7))
        scoutingPage=math.max(1,math.min(pages,scoutingPage+delta))
    elseif viewMode == "HISTORY" then
        local pages=math.max(1,math.ceil(#sortedHistory()/9))
        historyPage=math.max(1,math.min(pages,historyPage+delta))
    else
        local pages=math.max(1,math.ceil(#teamRows/9))
        scoreboardPage=math.max(1,math.min(pages,scoreboardPage+delta))
    end
    refreshPanel()
    if shoulderActive and KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(shoulderBindings)
    end
end
local function canPage(delta)
    if not panel or panel:IsHidden() then return false end
    if viewMode=="PLAYER" then
        if profileTab==2 then
            local p=profilePlayer();local n=p and #(p.gameLog or {}) or 0
            return delta<0 and selectedLogIndex>1 or delta>0 and selectedLogIndex<n
        end
        return delta<0 and profileTab>1 or delta>0 and profileTab<3
    end
    if viewMode=="GAME" then return false end
    if viewMode ~= "MATCH" and viewMode ~= "HISTORY" then
        if viewMode~="SCOUT" and viewMode~="COMPARE" then return false end
        local pages=math.max(1,math.ceil(#sortedHistory()/7))
        return delta < 0 and scoutingPage > 1 or delta > 0 and scoutingPage < pages
    elseif viewMode == "HISTORY" then
        local count=#sortedHistory()
        return delta<0 and selectedPlayerIndex>1 or delta>0 and selectedPlayerIndex<count
    end
    local pages=math.max(1,math.ceil(#teamRows/9))
    return delta < 0 and scoreboardPage > 1 or delta > 0 and scoreboardPage < pages
end
local function navigateSelection(delta)
    if viewMode=="HISTORY" then
        local count=#sortedHistory()
        if count==0 then return end
        selectedPlayerIndex=math.max(1,math.min(count,selectedPlayerIndex+delta))
        historyPage=math.ceil(selectedPlayerIndex/9)
    elseif viewMode=="PLAYER" and profileTab==2 then
        local p=profilePlayer();local n=p and #(p.gameLog or {}) or 0
        selectedLogIndex=math.max(1,math.min(math.max(n,1),selectedLogIndex+delta))
    end
    refreshPanel()
end
local function confirmSelection()
    if viewMode=="HISTORY" then selectHistoryPlayer()
    elseif viewMode=="PLAYER" and profileTab==2 then
        local p=profilePlayer()
        if p and #(p.gameLog or {})>0 then viewMode="GAME" end
    end
    refreshPanel()
    if shoulderActive and KEYBIND_STRIP and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(shoulderBindings)
    end
end
local function backSelection()
    if viewMode=="GAME" then viewMode="PLAYER";profileTab=2
    elseif viewMode=="PLAYER" then viewMode="HISTORY"
    else
        -- At the top level, O / Back closes the Fantasy ESO dashboard.
        if panel then panel:SetHidden(true) end
        if KEYBIND_STRIP and shoulderBindings and shoulderActive then
            pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(shoulderBindings) end)
            shoulderActive=false
        end
        return
    end
    refreshPanel()
end
local function updateShoulderBindings(visible)
    if not KEYBIND_STRIP or type(KEYBIND_STRIP.AddKeybindButtonGroup)~="function" then return end
    if not shoulderBindings then
        -- ESO's own gamepad tab bars use these shoulder shortcuts as ethereal
        -- keybinds. These work in UI mode without a separate radial action.
        shoulderBindings={
            alignment=KEYBIND_STRIP_ALIGN_LEFT,
            {name="L1  Previous / Select", keybind="UI_SHORTCUT_LEFT_SHOULDER",
                ethereal=true, enabled=function() return canPage(-1) end,
                callback=function() pageBy(-1) end},
            {name="R1  Next / Select", keybind="UI_SHORTCUT_RIGHT_SHOULDER",
                ethereal=true, enabled=function() return canPage(1) end,
                callback=function() pageBy(1) end},

            -- Confirm must be non-ethereal so the focused LibAddonMenu control
            -- does not receive X before our selection handler.
            {name="Open Selected",keybind="UI_SHORTCUT_PRIMARY",ethereal=false,
                order=100,
                enabled=function() return panel and not panel:IsHidden() and
                    (viewMode=="HISTORY" or (viewMode=="PLAYER" and profileTab==2)) end,
                callback=confirmSelection},
            {name="Back",keybind="UI_SHORTCUT_NEGATIVE",ethereal=true,
                enabled=function() return panel and not panel:IsHidden() end,
                callback=backSelection},
        }
    end
    if visible and not shoulderActive then
        local ok=pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(shoulderBindings) end)
        shoulderActive=ok
    elseif not visible and shoulderActive then
        pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(shoulderBindings) end)
        shoulderActive=false
    elseif visible and shoulderActive and KEYBIND_STRIP.UpdateKeybindButtonGroup then
        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(shoulderBindings) end)
    end
end
local function openDashboard(mode)
    if mode then viewMode=mode end
    if not makePanel() then return end
    refreshPanel()
    panel:SetHidden(false)
    updateShoulderBindings(true)
end
local function togglePanel()
    if not makePanel() then return end
    local show = panel:IsHidden()
    refreshPanel()
    panel:SetHidden(not show)
    updateShoulderBindings(show)
end

-- Optional native Controls keybind. Never assigns or steals a controller button.
function ESOFantasy_ToggleDashboard()
    togglePanel()
end
if type(ZO_CreateStringId)=="function" then
    ZO_CreateStringId("SI_BINDING_NAME_ESOFANTASY_TOGGLE_DASHBOARD", "ESO Fantasy: Toggle Dashboard")
end



-- Optional LibRadialMenu integration (console quickslot wheel).
-- Registration is idempotent and never blocks addon startup when the library is absent.
local radialRegistered = false
local sendStudAlertDraft, previewStudAlert, prepareOppsReport, previewOppsReport
local preparePartyDraft, nextBroadcastLine
local openPartyChatDraft
local launchRadialDraft
local pendingPartyDraft
local showBroadcastPrompt, checkPregameBroadcasts
local function registerRadialMenu()
    if radialRegistered then return true end
    local lib = _G.LibRadialMenu
    if type(lib) ~= "table" or type(lib.RegisterAddon) ~= "function"
        or type(lib.RegisterEntry) ~= "function" then return false end
    local ok, err = pcall(function()
        lib:RegisterAddon("ESOFantasy", "ESO Fantasy")
        lib:RegisterEntry("ESOFantasy", "Open Fantasy Dashboard", "dashboard",
            "/esoui/art/icons/achievement_battlegrounds_001.dds",
            function() togglePanel() end,
            "Open or close ESO Fantasy's match leaderboard and player history.")
        lib:RegisterEntry("ESOFantasy", "Open Player History", "history",
            "/esoui/art/icons/achievement_battlegrounds_001.dds",
            function() openDashboard("HISTORY") end,
            "Open scouting history, ranked highest fantasy average first.")
        for _,mode in ipairs(scoutingModes) do
            local target=mode
            lib:RegisterEntry("ESOFantasy", "TME "..target, "scout_"..target,
                "/esoui/art/icons/achievement_battlegrounds_001.dds",
                function() openDashboard(target); scoutingPage=1;refreshPanel() end,
                "Open the "..target.." scouting report.")
        end
        lib:RegisterEntry("ESOFantasy", "Previous Fantasy Page", "previous",
            "/esoui/art/buttons/large_leftarrow_up.dds",
            function() openDashboard(); pageBy(-1) end,
            "Go to the previous page of the currently selected fantasy view.")
        lib:RegisterEntry("ESOFantasy", "Next Fantasy Page", "next",
            "/esoui/art/buttons/large_rightarrow_up.dds",
            function() openDashboard(); pageBy(1) end,
            "Go to the next page of the currently selected fantasy view.")
        lib:RegisterEntry("ESOFantasy", "STUD ALERT DRAFT", "chat_stud",
            "/esoui/art/icons/achievement_battlegrounds_001.dds",
            function()
                pendingPartyDraft=nil
                if sendStudAlertDraft then sendStudAlertDraft() end
                if pendingPartyDraft and launchRadialDraft then
                    launchRadialDraft(pendingPartyDraft.text,pendingPartyDraft.channel)
                end
            end,
            "Prepare the STUD ALERT in editable Party chat. You press Send.")
        lib:RegisterEntry("ESOFantasy", "OPPS REPORT DRAFT", "chat_opps",
            "/esoui/art/icons/achievement_battlegrounds_001.dds",
            function()
                pendingPartyDraft=nil
                if prepareOppsReport then prepareOppsReport() end
                if pendingPartyDraft and launchRadialDraft then
                    launchRadialDraft(pendingPartyDraft.text,pendingPartyDraft.channel)
                end
            end,
            "Prepare the OPPS REPORT in editable Party chat. You press Send.")
        lib:RegisterEntry("ESOFantasy", "NEXT REPORT DRAFT", "chat_next",
            "/esoui/art/icons/achievement_battlegrounds_001.dds",
            function()
                pendingPartyDraft=nil
                if nextBroadcastLine then nextBroadcastLine() end
                if pendingPartyDraft and launchRadialDraft then
                    launchRadialDraft(pendingPartyDraft.text,pendingPartyDraft.channel)
                end
            end,
            "Prepare the next report line in Party chat. Never sends.")
    end)
    if ok then
        radialRegistered = true
        message("LibRadialMenu entry registered: Open Fantasy Dashboard")
    else
        message("LibRadialMenu registration unavailable: " .. tostring(err))
    end
    return radialRegistered
end

-- v1.7: PS5-friendly compact HUD, configured with gamepad settings sliders.
-- Uses a separate window; the full dashboard and player history remain unchanged.
local hudPreviewPlacement=false
local hud, hudText, hudBackground
local hudSettings = {enabled=true, hideInCombat=false, x=70, y=120, scale=100}
local function isBattlegroundActive()
    local ok, value = guardedCall("IsActiveWorldBattleground")
    return ok and value == true
end
local function hudLines()
    local s=currentStats
    local avg=average()
    local lines={
        "|cF1C86A  TME Network|r    |c62D5EA LIVE|r",
        "|cA7B9CD  BATTLEGROUND FANTASY|r",
        " ",
        string.format("|cF8D878  %s FP|r  |cD6E0F0%s|r", s and string.format("%.1f",s.partial) or "--", s and performanceGrade(s.partial) or "WAITING"),
        "|c75889B  YOUR MATCH PERFORMANCE|r",
        " ",
        string.format("|cF2C15D K|r %s     |cF2C15D A|r %s     |cF2C15D D|r %s", s and fmt(s.kills) or "--", s and (s.assists ~= nil and fmt(s.assists) or "?") or "--", s and fmt(s.deaths) or "--"),
        string.format("|cAFC6DB DMG|r %s     |cAFC6DB HEAL|r %s",s and fmt(s.damage) or "--",s and fmt(s.healing) or "--"),
        " ",
        string.format("|cF1C86A CAREER|r   %s FP/G  |  %d G", avg and string.format("%.1f",avg) or "--", saved and saved.games or 0),
    }
    if #teamRows > 0 then
        lines[#lines+1]="|cF1C86A  TOP PLAYERS|r"
        for i=1,math.min(3,#teamRows) do
            local r=teamRows[i]
            local name=cleanPlayerName(r.name)
            if #name>19 then name=name:sub(1,16).."..." end
            local marker=i==1 and "|cF5D06F*|r" or "|c8BA1B6+|r"
            lines[#lines+1]=string.format("%s %d   |cF5D06F%5.1f|r FP  %s",marker,i,r.fp,name)
        end
    end
    return table.concat(lines,"\n")
end
local function positionHud()
    if not hud then return end
    local scale=math.max(60,math.min(150,hudSettings.scale or 100))/100
    -- Percent-of-available-screen positioning. 0 = left/top; 1000 = right/bottom.
    -- Keep the entire scaled HUD on screen at either extreme.
    local sw=GuiRoot and GuiRoot:GetWidth() or 1920
    local sh=GuiRoot and GuiRoot:GetHeight() or 1080
    local availableX=math.max(0,sw-530*scale)
    local availableY=math.max(0,sh-355*scale)
    local x=availableX*math.max(0,math.min(1000,hudSettings.x or 70))/1000
    local y=availableY*math.max(0,math.min(1000,hudSettings.y or 120))/1000
    hud:ClearAnchors()
    hud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
    hud:SetScale(scale)
end
local function makeHud()
    if hud then return true end
    if not WINDOW_MANAGER then return false end
    local ok,err=pcall(function()
        local w=WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyLiveHUD")
        w:SetDimensions(530,355)
        w:SetClampedToScreen(true)
        w:SetMouseEnabled(false)
        w:SetHidden(true)
        local bg=WINDOW_MANAGER:CreateControl("ESOFantasyLiveHUDBackdrop",w,CT_BACKDROP)
        bg:SetAnchorFill(w)
        bg:SetCenterColor(0.015,0.028,0.048,0.88)
        bg:SetEdgeColor(0.20,0.65,0.90,0.95)
        local gold=WINDOW_MANAGER:CreateControl("ESOFantasyHUDGoldAccent",w,CT_TEXTURE)
        gold:SetAnchor(TOPLEFT,w,TOPLEFT,0,0)
        gold:SetDimensions(530,6)
        gold:SetColor(0.88,0.65,0.22,1)
        local tag=WINDOW_MANAGER:CreateControl("ESOFantasyHUDNetworkTag",w,CT_LABEL)
        tag:SetAnchor(TOPRIGHT,w,TOPRIGHT,-12,13)
        tag:SetDimensions(130,28)
        tag:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
        tag:SetColor(0.45,0.80,0.94,1)
        tag:SetText("SEASON LIVE")
        local t=WINDOW_MANAGER:CreateControl("ESOFantasyLiveHUDText",w,CT_LABEL)
        t:SetAnchor(TOPLEFT,w,TOPLEFT,20,16)
        t:SetDimensions(495,330)
        t:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        t:SetColor(0.98,0.86,0.55,1)
        t:SetVerticalAlignment(TEXT_ALIGN_TOP)
        t:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        local side=WINDOW_MANAGER:CreateControl("ESOFantasyHUDSideAccent",w,CT_TEXTURE)
        side:SetAnchor(TOPLEFT,w,TOPLEFT,0,6)
        side:SetDimensions(4,349)
        side:SetColor(0.88,0.65,0.22,0.95)
        local divider=WINDOW_MANAGER:CreateControl("ESOFantasyHUDDivider",w,CT_TEXTURE)
        divider:SetAnchor(TOPLEFT,w,TOPLEFT,18,77)
        divider:SetDimensions(494,2)
        divider:SetColor(0.35,0.47,0.60,0.65)
        hud,hudText,hudBackground=w,t,bg
        positionHud()
    end)
    if not ok then message("HUD creation failed: "..tostring(err)) return false end
    return true
end
local function updateHud()
    local inCombat=false
    if hudSettings.hideInCombat and type(IsUnitInCombat)=="function" then
        local ok,result=pcall(IsUnitInCombat,"player")
        inCombat=ok and result==true
    end
    if hudPreviewPlacement then
        if makeHud() then
            hudText:SetText("|cF1C86A BG RATING  /  HUD PREVIEW|r\n|cFFFFFF LIVE MATCH STATS|r\n|cAFC6DB K 12   A 8   D 3|r\n|c62D5EA ESOFP  24.5|r")
            hud:SetHidden(false)
        end
        return
    end
    if not hudSettings.enabled or not isBattlegroundActive() or inCombat then
        if hud then hud:SetHidden(true) end
        return
    end
    if not makeHud() then return end
    hudText:SetText(hudLines())
    hud:SetHidden(false)
end
local function applyHudSetting(key,value)
    hudSettings[key]=value
    if saved then
        saved.hud=saved.hud or {}
        saved.hud[key]=value
    end
    positionHud()
    updateHud()
end

-- v1.9.5: Independent live team snapshot overlay. Uses existing scoreboard rows.
local teamHud, teamHudText
local teamHudSettings={enabled=true,x=70,y=500,scale=85}
local function teamHudLines()
    local mine
    for _,r in ipairs(teamRows) do if r.localPlayer then mine=r; break end end
    if not mine then
        return "|cF1C86A TME Network|r\n|c62D5EA TEAM SNAPSHOT  /  LIVE|r\n|cAFC6DB Awaiting team scoreboard...|r"
    end
    local members,fp,k,a,d={},0,0,0,0
    for _,r in ipairs(teamRows) do
        if r.team==mine.team then
            members[#members+1]=r
            fp=fp+(r.fp or 0); k=k+(r.kills or 0)
            a=a+(r.assists or 0); d=d+(r.deaths or 0)
        end
    end
    table.sort(members,function(x,y) return (x.fp or 0)>(y.fp or 0) end)
    local lines={
        "|cF1C86A TME Network|r",
        "|c62D5EA TEAM SNAPSHOT  /  LIVE|r",
        string.format("|cFFFFFF TEAM FP  %.1f|r   |cAFC6DB %d PLAYERS|r",fp,#members),
        string.format("|cD8E4F0 K %d     A %d     D %d|r",k,a,d),
        "|c8FA7BF ______________________________|r",
    }
    for i,r in ipairs(members) do
        local name=displayName(cleanPlayerName(r.name or "Unknown"),19)
        local color=r.localPlayer and "F1C86A" or "D6E0F0"
        lines[#lines+1]=string.format("|c%s%d. %s|r",color,i,name)
        lines[#lines+1]=string.format("|cAFC6DB    %.1f FP%s|r",r.fp or 0,r.localPlayer and "  /  YOU" or "")
    end
    if #members>0 then
        lines[#lines+1]="|c8FA7BF ______________________________|r"
        lines[#lines+1]=string.format("|cF1C86A MVP|r  %s",displayName(cleanPlayerName(members[1].name or ""),23))
        lines[#lines+1]=string.format("|cAFC6DB YOUR SHARE  %.1f%%|r",fp>0 and (mine.fp or 0)/fp*100 or 0)
    end
    return table.concat(lines,"\n")
end
local function positionTeamHud()
    if not teamHud then return end
    teamHud:ClearAnchors()
    teamHud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,math.max(0,math.min(1600,teamHudSettings.x)),math.max(0,math.min(900,teamHudSettings.y)))
    teamHud:SetScale(math.max(60,math.min(150,teamHudSettings.scale))/100)
end
local function makeTeamHud()
    if teamHud then return true end
    if not WINDOW_MANAGER then return false end
    local ok,err=pcall(function()
        local w=WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyTeamSnapshotHUD")
        w:SetDimensions(470,410); w:SetClampedToScreen(true); w:SetMouseEnabled(false); w:SetHidden(true)
        local bg=WINDOW_MANAGER:CreateControl("ESOFantasyTeamSnapshotBG",w,CT_BACKDROP)
        bg:SetAnchorFill(w); bg:SetCenterColor(0.015,0.028,0.048,0.9); bg:SetEdgeColor(0.20,0.65,0.90,0.95)
        local accent=WINDOW_MANAGER:CreateControl("ESOFantasyTeamSnapshotAccent",w,CT_TEXTURE)
        accent:SetAnchor(TOPLEFT,w,TOPLEFT,0,0); accent:SetDimensions(470,5); accent:SetColor(0.88,0.65,0.22,1)
        local t=WINDOW_MANAGER:CreateControl("ESOFantasyTeamSnapshotText",w,CT_LABEL)
        t:SetAnchor(TOPLEFT,w,TOPLEFT,18,16); t:SetDimensions(432,385)
        t:SetFont("$(BOLD_FONT)|17|soft-shadow-thick"); t:SetVerticalAlignment(TEXT_ALIGN_TOP)
        t:SetHorizontalAlignment(TEXT_ALIGN_LEFT); t:SetColor(1,1,1,1)
        teamHud=w; teamHudText=t; positionTeamHud()
    end)
    if not ok then message("Team HUD creation failed: "..tostring(err)); return false end
    return true
end
local function updateTeamHud()
    if hudPreviewPlacement then
        if makeTeamHud() then
            teamHudText:SetText("|cF1C86A BG RATING|r\n|c62D5EA TEAM SNAPSHOT  /  PREVIEW|r\n|cFFFFFF TEAM FP  82.5   4 PLAYERS|r\n|cD8E4F0 K 30     A 24     D 16|r\n|c8FA7BF ______________________________|r\n|cFFFFFF 1. YOU|r\n|cAFC6DB    24.5 FP|r\n|cFFFFFF 2. TEAMMATE|r\n|cAFC6DB    22.0 FP|r")
            teamHud:SetHidden(false)
        end
        return
    end
    if not teamHudSettings.enabled or not isBattlegroundActive() then
        if teamHud then teamHud:SetHidden(true) end
        return
    end
    if not makeTeamHud() then return end
    teamHudText:SetText(teamHudLines()); teamHud:SetHidden(false)
end
local function applyTeamHudSetting(key,value)
    teamHudSettings[key]=value
    if saved then
        saved.teamHud=saved.teamHud or {}
        saved.teamHud[key]=value
    end
    positionTeamHud(); updateTeamHud()
end

-- v1.9.6: Character fantasy profile, shown only outside Battlegrounds.
-- Old matches contain FP aggregates but not full box scores. Do not invent missing data.
local profileHud, profileHudText
local profileSettings={enabled=true,x=40,y=90,scale=90}
local archetypeDescriptions={
    ["HEALER"]="Sustains the squad with standout healing output.",
    ["OBJECTIVE ACE"]="Makes the objective the center of every match.",
    ["FRONTLINER"]="Defensive engagement and pressure absorption (pending telemetry).",
    ["SLAYER"]="Turns offensive pressure into eliminations.",
    ["PLAYMAKER"]="Creates scoring opportunities for teammates.",
    ["DAMAGE DEALER"]="Wins fights through sustained damage.",
    ["ALL-ROUNDER"]="Contributes across multiple fantasy categories.",
}
local function ownCharacterRecord()
    if not saved or type(saved.players)~="table" then return nil end
    local ok,name=guardedCall("GetUnitName","player")
    if not ok or type(name)~="string" then return nil end
    local target=cleanPlayerName(name)
    if saved.players[target] then return saved.players[target] end
    for key,p in pairs(saved.players) do
        if cleanPlayerName(key)==target then return p end
    end
    return nil
end
-- v1.9.9: full-width horizontal broadcast strip. Four dedicated text regions
-- prevent the long wrapped lines of the previous vertical profile panel.
local profileCells={}
local function profileContent()
    local ok,name=guardedCall("GetUnitName","player")
    name=ok and cleanPlayerName(name) or "YOUR CHARACTER"
    local p=ownCharacterRecord()
    local games=p and (p.games or 0) or 0
    local avg=games>0 and (p.total or 0)/games or nil
    local role=careerPlaystyle(p)
    local desc=archetypeDescriptions[role] or "Play more matches to reveal your style."
    local h=p and p.highs or {}
    local t=p and p.totals or {}
    local n=p and (p.extendedGames or 0) or 0
    local last=p and p.lastStats
    local lastFP=last and string.format("%.1f",last.fp or 0) or (p and p.last and string.format("%.1f",p.last) or "--")
    local lastKAD=last and string.format("%s / %s / %s",compact(last.kills),compact(last.assists),compact(last.deaths)) or "-- / -- / --"
    return {
        "|cF1C86A TME Network|r\n|cFFFFFF "..displayName(name,23).."|r\n|c62D5EA "..role.."|r\n|cAFC6DB "..desc.."|r",
        string.format("|cF1C86A CAREER|r\n|cFFFFFF %d G  |  %s FP/G|r\n|cD6E0F0 %s TOTAL FP|r\n|cD6E0F0 BEST %s  |  MVP %d|r",games,avg and string.format("%.1f",avg) or "--",p and string.format("%.1f",p.total or 0) or "--",p and p.best and string.format("%.1f",p.best) or "--",p and (p.mvps or 0) or 0),
        string.format("|cF1C86A ALL-TIME HIGHS|r\n|cFFFFFF K %s  A %s  D %s|r\n|cD6E0F0 DMG %s  HEAL %s|r\n|cAFC6DB AVG K %.1f A %.1f D %.1f|r",h.kills and compact(h.kills) or "--",h.assists and compact(h.assists) or "--",h.deaths and compact(h.deaths) or "--",h.damage and compact(h.damage) or "--",h.healing and compact(h.healing) or "--",n>0 and (t.kills or 0)/n or 0,n>0 and (t.assists or 0)/n or 0,n>0 and (t.deaths or 0)/n or 0),
        string.format("|cF1C86A LAST GAME|r\n|cFFFFFF %s FP  |  K/A/D %s|r\n|cD6E0F0 DMG %s  HEAL %s|r\n|cAFC6DB %s|r",lastFP,lastKAD,last and compact(last.damage) or "--",last and compact(last.healing) or "--",p and p.lastArchetype or "Style unavailable"),
    }
end
local function positionProfileHud()
    if not profileHud then return end
    local scale=math.max(60,math.min(150,profileSettings.scale))/100
    profileHud:SetScale(scale)
    -- Screen-relative placement. Never let the bar disappear off-screen.
    local screenW=GuiRoot:GetWidth()
    local screenH=GuiRoot:GetHeight()
    local maxX=math.max(0,screenW-profileHud:GetWidth()*scale)
    local maxY=math.max(0,screenH-profileHud:GetHeight()*scale)
    profileHud:ClearAnchors()
    profileHud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,
        math.max(0,math.min(maxX,profileSettings.x)),
        math.max(0,math.min(maxY,profileSettings.y)))
end
local function makeProfileHud()
    if profileHud then return true end
    if not WINDOW_MANAGER then return false end
    local ok,err=pcall(function()
        local w=WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyCharacterProfileHUD")
        w:SetDimensions(1260,158);w:SetClampedToScreen(true);w:SetMouseEnabled(false);w:SetHidden(true)
        local bg=WINDOW_MANAGER:CreateControl("ESOFantasyCharacterProfileBG",w,CT_BACKDROP)
        bg:SetAnchorFill(w);bg:SetCenterColor(0,0,0,0);bg:SetEdgeColor(0,0,0,0)
        local art=WINDOW_MANAGER:CreateControl("ESOFantasyCharacterProfileArtwork",w,CT_TEXTURE)
        art:SetAnchorFill(w)
        art:SetTexture("ESOFantasy/textures/career.dds")
        art:SetAlpha(1)
        art:SetDrawLayer(DL_BACKGROUND)
        art:SetDrawLevel(1)
        local accent=WINDOW_MANAGER:CreateControl("ESOFantasyCharacterProfileAccent",w,CT_TEXTURE)
        accent:SetAnchor(TOPLEFT,w,TOPLEFT,0,0);accent:SetDimensions(1260,5);accent:SetColor(0.88,0.65,0.22,0)
        local widths={345,225,325,310};local x=24
        for i=1,4 do
            local t=WINDOW_MANAGER:CreateControl("ESOFantasyCharacterProfileColumn"..i,w,CT_LABEL)
            t:SetAnchor(TOPLEFT,w,TOPLEFT,x+9,35);t:SetDimensions(widths[i]-24,108)
            t:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
            t:SetVerticalAlignment(TEXT_ALIGN_TOP);t:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            t:SetColor(1,1,1,1);profileCells[i]=t
            x=x+widths[i]
            if i<4 then
                local separator=WINDOW_MANAGER:CreateControl("ESOFantasyCharacterProfileDivider"..i,w,CT_TEXTURE)
                separator:SetAnchor(TOPLEFT,w,TOPLEFT,x-9,16)
                separator:SetDimensions(2,120);separator:SetColor(0.28,0.37,0.47,0)
            end
        end
        profileHud=w;positionProfileHud()
    end)
    if not ok then message("Profile HUD creation failed: "..tostring(err));return false end
    return true
end
local function updateProfileHud()
    if hudPreviewPlacement then
        if makeProfileHud() then
            local columns=profileContent()
            for i=1,4 do profileCells[i]:SetText(columns[i]) end
            profileHud:SetHidden(false)
        end
        return
    end
    if not profileSettings.enabled or not isBattlegroundActive() then
        if profileHud then profileHud:SetHidden(true) end
        return
    end
    if not makeProfileHud() then return end
    local columns=profileContent()
    for i=1,4 do profileCells[i]:SetText(columns[i]) end
    profileHud:SetHidden(false)
end
local function applyProfileSetting(key,value)
    profileSettings[key]=value
    if saved then
        saved.profileHud=saved.profileHud or {}
        saved.profileHud[key]=value
    end
    positionProfileHud(); updateProfileHud()
end

-- Reticle scouting: non-invasive visual mark. Native raid marker mutation is
-- intentionally not attempted without a verified PS5 API and permissions.
local reticleHud,reticleText
local function updateReticleScout()
    if not isBattlegroundActive() or not saved or not saved.scoutReticleEnabled then
        if reticleHud then reticleHud:SetHidden(true) end
        return
    end
    local ok,name=guardedCall("GetUnitName","reticleover")
    local p=ok and type(name)=="string" and saved.players and saved.players[cleanPlayerName(name)] or nil
    if not p or (p.games or 0)<2 then
        if reticleHud then reticleHud:SetHidden(true) end
        return
    end
    if not reticleHud then
        local w=WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyReticleScout")
        w:SetDimensions(440,90);w:SetAnchor(TOP,GuiRoot,TOP,0,120)
        w:SetMouseEnabled(false)
        local bg=WINDOW_MANAGER:CreateControl("ESOFantasyReticleBG",w,CT_BACKDROP)
        bg:SetAnchorFill(w);bg:SetCenterColor(0.02,0.04,0.07,0.87)
        bg:SetEdgeColor(0.20,0.65,0.90,0.95)
        local label=WINDOW_MANAGER:CreateControl("ESOFantasyReticleText",w,CT_LABEL)
        label:SetAnchorFill(w);label:SetFont("$(BOLD_FONT)|17|soft-shadow-thick")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        reticleHud=w;reticleText=label
    end
    local role=careerPlaystyle(p)
    local grade=scoutingGrade(p)
    reticleText:SetText(string.format("|cF1C86A TME SCOUT |r %s\n|c62D5EA %s |r / %s FP/G / %d G / GRADE %s",
        displayName(name,30),role,string.format("%.1f",playerAvg(p)),p.games,grade))
    reticleHud:SetHidden(false)
end
-- v2.2 STUD ALERT: explicit opt-in chat draft, never unsolicited chat.
-- Uses only observed historical scores; teammates are determined from the live BG scoreboard.
local studAlertUsedForMatch=false
local function studCandidates()
    if not saved or type(saved.players)~="table" then return {}, "No scouting history yet." end
    if not isBattlegroundActive() then return {}, "Enter a Battleground to scout teammates." end
    updateLiveStats()
    local myTeam
    for _,r in ipairs(teamRows) do if r.localPlayer then myTeam=r.team;break end end
    if myTeam==nil then return {}, "Your team is not identified in the live scoreboard yet." end
    local found,seen={},{}
    for _,r in ipairs(teamRows) do
        if r.team==myTeam and not r.localPlayer then
            local key=cleanPlayerName(r.name or "")
            if key~="" and not seen[key] then
                seen[key]=true
                local p=saved.players[key]
                if not p then
                    for known,record in pairs(saved.players) do
                        if cleanPlayerName(known)==key then p=record;break end
                    end
                end
                local qualifying=0
                local qualifyingTotal=0
                -- Use all recorded games only if every game is known to be complete.
                -- Legacy aggregate records may include provisional games.
                if p and (p.games or 0)>0 and (p.provisionalGames or 0)==0 then
                    qualifying=p.games
                    qualifyingTotal=p.total or 0
                elseif p and type(p.gameLog)=="table" then
                    for _,g in ipairs(p.gameLog) do
                        if g.complete==true and type(g.fp)=="number" then
                            qualifying=qualifying+1;qualifyingTotal=qualifyingTotal+g.fp
                        end
                    end
                end
                if qualifying>=1 and qualifyingTotal/qualifying>=10 then
                    local n=type(p.extendedGames)=="number" and p.extendedGames or 0
                    local totals=p.totals or {}
                    found[#found+1]={name=key,games=qualifying,avg=qualifyingTotal/qualifying,
                        archetype=p.archetype or "UNSCOUTED",
                        kills=n>0 and type(totals.kills)=="number" and totals.kills/n or nil,
                        assists=n>0 and type(totals.assists)=="number" and totals.assists/n or nil,
                        deaths=n>0 and type(totals.deaths)=="number" and totals.deaths/n or nil,
                        damage=n>0 and type(totals.damage)=="number" and totals.damage/n or nil,
                        healing=n>0 and type(totals.healing)=="number" and totals.healing/n or nil}
                end
            end
        end
    end
    table.sort(found,function(a,b) return a.avg>b.avg end)
    return found,nil
end
-- Short, conversational pregame scouting. All figures are per recorded game.
local function friendlyStatSentence(r, fp)
    local parts={}
    if r.healing then parts[#parts+1]=compact(r.healing).." healing" end
    if r.damage then parts[#parts+1]=compact(r.damage).." damage" end
    if r.kills and r.assists and r.deaths then
        local kda=(r.kills+r.assists)/math.max(1,r.deaths)
        parts[#parts+1]=string.format("%.1f KDA",kda)
    end
    parts[#parts+1]=string.format("%.1f ESOFP",fp)
    return table.concat(parts,", ")
end
local function studAlertDraft()
    local studs,err=studCandidates()
    if err then return nil,err end
    if #studs==0 then return nil,"No known teammates currently qualify (1+ complete game, 10+ ESOFP/G)." end
    local lines={}
    for _,r in ipairs(studs) do
        lines[#lines+1]=string.format("BG Rating - STUD ALERT: %s is a STUD! Across %d recorded games, they average %s per game.",
            displayName(r.name,32),r.games,friendlyStatSentence(r,r.avg))
    end
    return lines,nil
end
-- PS5-safe editable chat draft. The fourth argument bypasses a protected
-- console settings call; sending remains entirely the player's action.
-- Console chat: prepare the draft only; the player must press Send.
-- The console HUD chat API prepares an editable draft; no external chat addon is required.
pendingPartyDraft=nil
local function reportStatus(text)
    if LibChatMessage and type(LibChatMessage.Create)=="function" then
        local ok=pcall(function()
            if not ESOFantasyChatLogger then
                ESOFantasyChatLogger=LibChatMessage.Create("Fantasy ESO", "FESO")
            end
            ESOFantasyChatLogger:Print(text)
        end)
        if ok then return end
    end
    message(text)
end
openPartyChatDraft=function(text, channel)
    if type(text)~="string" or text=="" then return false,"Empty report" end
    local chatSystem=type(ZO_GetChatSystem)=="function" and ZO_GetChatSystem() or nil
    if not chatSystem or type(chatSystem.StartTextEntry)~="function" then
        return false,"Console chat input is unavailable"
    end
    -- The fourth argument is the console-compatible bypass documented by
    -- Predefined Chat Messages' PS5 developer. Never send automatically.
    local ok,err=pcall(function()
        chatSystem:StartTextEntry(text, channel, nil, true)
    end)
    if not ok then return false,tostring(err) end
    return true
end

-- Single attempt after the radial wheel releases input. No scene changes or retries.
local radialDraftBusy=false
launchRadialDraft=function(text, channel)
    if radialDraftBusy then return end
    if type(text)~="string" or text=="" or channel==nil then
        message("CHAT DRAFT: no message or channel available.")
        return
    end
    radialDraftBusy=true
    local function attempt()
        radialDraftBusy=false
        local ok,err=openPartyChatDraft(text,channel)
        if not ok then message("CHAT DRAFT ERROR: "..tostring(err)) end
    end
    if zo_callLater then
        zo_callLater(attempt,200)
    else
        radialDraftBusy=false
        message("CHAT DRAFT: delayed callback unavailable; no input change attempted.")
    end
end

-- Store report drafts for user-initiated radial chat actions.
preparePartyDraft=function(text, channel)
    if type(text)~="string" or text=="" then return false,"Empty report" end
    if channel==nil then return false,"Chat channel unavailable" end
    pendingPartyDraft={text=text,channel=channel}
    reportStatus("Report prepared. Use the radial chat action to open the draft.")
    return true
end

sendStudAlertDraft=function()
    if studAlertUsedForMatch then message("STUD ALERT already prepared this match; use /esof studs to preview.") return end
    local lines,err=studAlertDraft()
    if not lines then message(err);return end
    -- Explicitly user-initiated: prefill a single message in party chat for review.
    -- StartChatInput opens an editable draft, NOT an automatic broadcast.
    local chatChannel=constant("CHAT_CHANNEL_PARTY")
    local draft=lines[1]
    if false and showBroadcastPrompt and showBroadcastPrompt("STUD ALERT",lines) then
        studAlertUsedForMatch=true;return
    end
    local ok,why=preparePartyDraft(draft,chatChannel)
    if ok then
        studAlertUsedForMatch=true
        -- Draft opens on the gameplay HUD; the player presses Send.
        if #lines>1 then message("More studs qualify; preview them with /esof studs.") end
    else message("Could not open party chat draft: "..tostring(why)) end
end
previewStudAlert=function()
    local lines,err=studAlertDraft()
    if not lines then message(err);return end
    for _,line in ipairs(lines) do message(line) end
    message("Use PREPARE STUD ALERT in settings to open a Party chat draft.")
end

-- v2.3 OPPS REPORT: historical, opponent-only, manual party-chat draft.
-- Reports are descriptive estimates, not live enemy telemetry or claims of certainty.
local oppsReportPreparedForMatch=false
local function opponentScouting()
    if not saved or type(saved.players)~="table" then return nil,"No saved scouting database." end
    if not isBattlegroundActive() then return nil,"Enter a Battleground to scout opponents." end
    updateLiveStats()
    local myTeam
    for _,r in ipairs(teamRows) do if r.localPlayer then myTeam=r.team;break end end
    if myTeam==nil then return nil,"Your team is not identified yet." end
    local opponents,seen={},{}
    for _,r in ipairs(teamRows) do
        if r.team~=nil and r.team~=myTeam then
            local key=cleanPlayerName(r.name or "")
            if key~="" and not seen[key] then
                seen[key]=true
                local p=saved.players[key]
                if not p then
                    for known,record in pairs(saved.players) do
                        if cleanPlayerName(known)==key then p=record;break end
                    end
                end
                if p then
                    local n,total=0,0
                    -- Prefer explicit completed match logs; old aggregates can be partial.
                    for _,g in ipairs(p.gameLog or {}) do
                        if g.complete==true and type(g.fp)=="number" then
                            n=n+1;total=total+g.fp
                        end
                    end
                    if n==0 and (p.games or 0)>0 and (p.completeGames or 0)==p.games then
                        n=p.games;total=p.total or 0
                    end
                    if n>0 then
                        local e=p.extendedGames or 0
                        local t=p.totals or {}
                        local dmg=e>0 and type(t.damage)=="number" and t.damage/e or nil
                        local heal=e>0 and type(t.healing)=="number" and t.healing/e or nil
                        local kills=e>0 and type(t.kills)=="number" and t.kills/e or nil
                        local deaths=e>0 and type(t.deaths)=="number" and t.deaths/e or nil
                        local role=careerPlaystyle(p)
                        local avg=total/n
                        local tag
                        if role=="HEALER" and heal and heal>=300000 then
                            tag="HEALER - PRIORITY SUPPORT"
                        elseif (role=="SLAYER" or role=="DAMAGE DEALER") and avg>=15 then
                            tag="HIGH DAMAGE THREAT"
                        elseif role=="OBJECTIVE ACE" and avg>=10 then
                            tag="OBJECTIVE THREAT"
                        elseif avg>=20 then
                            tag="HIGH IMPACT"
                        elseif avg<5 and n>=3 and deaths and deaths>=5 then
                            tag="VULNERABLE - HIGH DEATH RATE"
                        elseif avg<10 and n>=3 then
                            tag="LOW HISTORICAL FP"
                        else
                            tag="SCOUTED"
                        end
                        opponents[#opponents+1]={name=key,fp=avg,games=n,role=role,
                            tag=tag,damage=dmg,healing=heal,kills=kills,deaths=deaths}
                    end
                end
            end
        end
    end
    table.sort(opponents,function(a,b)
        if a.fp~=b.fp then return a.fp>b.fp end
        return a.name<b.name
    end)
    return opponents,nil
end
-- v2.6: Passive scouting HUD. No dialogs, chat actions, or automatic popups.
local scoutingHud, scoutingHudText
local scoutingHudSettings={enabled=true,hideInCombat=false,x=650,y=160,scale=100}
local function scoutingHudLines()
    local lines={"|cF1C86AFANTASY ESO|r  |c62D5EAPREGAME SCOUTING|r",
        "|c8FA7BFTEAM STUDS  /  10+ ESOFP/G|r"}
    local studs,studError=studCandidates()
    if studs and #studs>0 then
        for _,r in ipairs(studs) do
            lines[#lines+1]=string.format("|cF1C86A%s|r  |cFFFFFF%.1f FP/G|r  |cAFC6DB%d GP|r",
                displayName(r.name,24),r.avg,r.games)
            lines[#lines+1]=string.format("|cAFC6DB  %s  K %s A %s D %s|r",
                r.archetype or "UNSCOUTED",
                r.kills and string.format("%.1f",r.kills) or "--",
                r.assists and string.format("%.1f",r.assists) or "--",
                r.deaths and string.format("%.1f",r.deaths) or "--")
            lines[#lines+1]=string.format("|cAFC6DB  DMG %s  HEAL %s|r",
                r.damage and compact(r.damage) or "--",
                r.healing and compact(r.healing) or "--")
        end
    else lines[#lines+1]="|cAFC6DBNo qualifying known teammates|r" end
    lines[#lines+1]="|c8FA7BF____________________________________|r"
    lines[#lines+1]="|cFF9D8EOPPS REPORT  /  HISTORICAL SCOUTING|r"
    local opps,oppError=opponentScouting()
    if opps and #opps>0 then
        for _,r in ipairs(opps) do
            local tagColor=(r.tag=="HIGH DAMAGE THREAT" or r.tag=="HEALER - PRIORITY SUPPORT") and "FF9D8E"
                or (r.tag=="VULNERABLE - HIGH DEATH RATE" and "F1C86A" or "AFC6DB")
            lines[#lines+1]=string.format("|cFFFFFF%s|r  |cF1C86A%.1f FP/G|r  |cAFC6DB%d GP|r",
                displayName(r.name,24),r.fp,r.games)
            lines[#lines+1]=string.format("|c%s  %s|r  |cAFC6DB%s%s|r",tagColor,r.tag,
                r.role or "UNSCOUTED",r.games<3 and " / SMALL SAMPLE" or "")
            lines[#lines+1]=string.format("|cAFC6DB  DMG %s  HEAL %s  K %s  D %s|r",
                r.damage and compact(r.damage) or "--",
                r.healing and compact(r.healing) or "--",
                r.kills and string.format("%.1f",r.kills) or "--",
                r.deaths and string.format("%.1f",r.deaths) or "--")
        end
    else lines[#lines+1]="|cAFC6DBNo previously scouted opponents|r" end
    if studError and oppError then
        lines[#lines+1]="|cAFC6DBWaiting for Battleground roster...|r"
    end
    return table.concat(lines,"\n"),#(studs or {})+#(opps or {})
end
local function positionScoutingHud()
    if not scoutingHud then return end
    local scale=math.max(65,math.min(160,scoutingHudSettings.scale))/100
    scoutingHud:SetScale(scale)
    local screenW,screenH=GuiRoot:GetDimensions()
    local hudW,hudH=scoutingHud:GetDimensions()
    local maxX=math.max(0,screenW-hudW*scale)
    local maxY=math.max(0,screenH-hudH*scale)
    local x=math.max(0,math.min(scoutingHudSettings.x,maxX))
    local y=math.max(0,math.min(scoutingHudSettings.y,maxY))
    scoutingHud:ClearAnchors()
    scoutingHud:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
end
local function makeScoutingHud()
    if scoutingHud then return true end
    if not WINDOW_MANAGER then return false end
    local ok,err=pcall(function()
        local w=WINDOW_MANAGER:CreateTopLevelWindow("ESOFantasyScoutingHUD")
        w:SetDimensions(530,260)
        w:SetClampedToScreen(true);w:SetMouseEnabled(false);w:SetHidden(true)
        local bg=WINDOW_MANAGER:CreateControl("ESOFantasyScoutingBG",w,CT_BACKDROP)
        bg:SetAnchorFill(w)
        bg:SetCenterColor(0.015,0.028,0.048,0.93)
        bg:SetEdgeColor(0.20,0.65,0.90,0.95)
        local accent=WINDOW_MANAGER:CreateControl("ESOFantasyScoutingAccent",w,CT_TEXTURE)
        accent:SetAnchor(TOPLEFT,w,TOPLEFT,0,0)
        accent:SetDimensions(530,5);accent:SetColor(0.88,0.65,0.22,1)
        local t=WINDOW_MANAGER:CreateControl("ESOFantasyScoutingText",w,CT_LABEL)
        t:SetAnchor(TOPLEFT,w,TOPLEFT,16,14)
        t:SetDimensions(498,230)
        t:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        t:SetVerticalAlignment(TEXT_ALIGN_TOP)
        t:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        t:SetColor(1,1,1,1)
        scoutingHud=w;scoutingHudText=t
        positionScoutingHud()
    end)
    if not ok then message("Scouting HUD unavailable: "..tostring(err));return false end
    return true
end
local function updateScoutingHud()
    local inCombat=false
    if scoutingHudSettings.hideInCombat and type(IsUnitInCombat)=="function" then
        local ok,result=pcall(IsUnitInCombat,"player")
        inCombat=ok and result==true
    end
    if hudPreviewPlacement then
        if makeScoutingHud() then
            scoutingHud:SetDimensions(530,180)
            scoutingHudText:SetDimensions(498,150)
            scoutingHudText:SetText("|cF1C86A BG RATING  /  SCOUT PREVIEW|r\n|c62D5EA STUD + OPPS INTELLIGENCE|r\n|cFFFFFF STUD  Sample Teammate|r\n|cAFC6DB  21.4 FP/G  /  18 GAMES|r\n|cFFFFFF OPPS  Sample Opponent|r\n|cAFC6DB  19.8 FP/G  /  12 GAMES|r")
            positionScoutingHud()
            scoutingHud:SetHidden(false)
        end
        return
    end
    if not scoutingHudSettings.enabled or not isBattlegroundActive() or inCombat then
        if scoutingHud then scoutingHud:SetHidden(true) end
        return
    end
    if not makeScoutingHud() then return end
    local content,count=scoutingHudLines()
    -- Expand vertically to fit every qualifying player; no scrolling or truncation.
    local rows=select(2,content:gsub("\n","\n"))+1
    local height=math.max(180,math.min(1600,rows*24+32))
    scoutingHud:SetDimensions(530,height)
    scoutingHudText:SetDimensions(498,height-30)
    positionScoutingHud()
    scoutingHudText:SetText(content)
    scoutingHud:SetHidden(false)
end
-- Placement preview works in town, before queueing, and on PS5.
-- It does not alter match data or HUD enabled preferences.
local function setHudPreviewPlacement(enabled)
    hudPreviewPlacement=enabled==true
    updateHud()
    updateTeamHud()
    updateProfileHud()
    updateScoutingHud()
    message("HUD placement preview "..(hudPreviewPlacement and "ON. Adjust positions in addon settings." or "OFF."))
end

local function applyScoutingHudSetting(key,value)
    scoutingHudSettings[key]=value
    if saved then
        saved.scoutingHud=saved.scoutingHud or {}
        saved.scoutingHud[key]=value
    end
    positionScoutingHud()
    updateScoutingHud()
end

local function oppsReportLines()
    local opponents,err=opponentScouting()
    if not opponents then return nil,err end
    if #opponents==0 then return nil,"No opponents with completed recorded games are known yet." end
    local lines={}
    for _,r in ipairs(opponents) do
        lines[#lines+1]=string.format("BG Rating - OPPS REPORT: Keep an eye on %s. Across %d recorded games, they average %s per game.",
            displayName(r.name,32),r.games,friendlyStatSentence(r,r.fp))
    end
    return lines,nil
end
-- Native gamepad-aware confirmation dialog. Accept broadcasts; cancel does nothing.
local broadcastDialogRegistered=false
local pendingBroadcast=nil
local queuedPregameKind=nil
local broadcastInProgress=false
local pendingChatLines=nil
local function transmitBroadcast(lines)
    if not lines or #lines==0 then return false end
    local channel=constant("CHAT_CHANNEL_PARTY")
    if channel==nil then message("Party chat is unavailable.");return false end
    -- SendChatMessage is a private ESO function: insecure addons MUST NOT call it.
    -- Offer one editable line at a time; player sends each through native chat.
    local ok,err=preparePartyDraft(lines[1],channel)
    if not ok then message("Unable to open chat input: "..tostring(err));return false end
    pendingChatLines={}
    for i=2,#lines do pendingChatLines[#pendingChatLines+1]=lines[i] end
    -- HUD transition opens the draft; Send remains manual.
    return true
end
nextBroadcastLine=function()
    if not pendingChatLines or #pendingChatLines==0 then message("No remaining report lines.");return end
    local channel=constant("CHAT_CHANNEL_PARTY")
    local ok,err=preparePartyDraft(pendingChatLines[1],channel)
    if ok then table.remove(pendingChatLines,1)
    else message("Chat draft unavailable: "..tostring(err)) end
end
local function showQueuedPregame()
    if not queuedPregameKind then return end
    local kind=queuedPregameKind
    queuedPregameKind=nil
    if kind=="OPPS REPORT" then
        local lines=oppsReportLines()
        if lines and #lines>0 then showBroadcastPrompt(kind,lines) end
    end
end
local function ensureBroadcastDialog()
    if broadcastDialogRegistered then return true end
    if type(ZO_Dialogs_RegisterCustomDialog)~="function" or type(ZO_Dialogs_ShowDialog)~="function" then return false end
    local ok=pcall(function()
        ZO_Dialogs_RegisterCustomDialog("ESOFANTASY_BROADCAST_CONFIRM",{
            title={text="Fantasy ESO"},
            mainText={font="ZoFontGamepad27",text=function()
                if not pendingBroadcast then return "Broadcast report?" end
                return pendingBroadcast.preview
            end},
            buttons={
                {text="Broadcast to Party Chat",keybind="DIALOG_PRIMARY",callback=function()
                    local report=pendingBroadcast
                    pendingBroadcast=nil
                    if report then transmitBroadcast(report.lines) end
                    if type(zo_callLater)=="function" then zo_callLater(showQueuedPregame,300) end
                end},
                {text="Close",keybind="DIALOG_NEGATIVE",callback=function()
                    pendingBroadcast=nil
                    if type(zo_callLater)=="function" then zo_callLater(showQueuedPregame,300) end
                end},
            },
        })
    end)
    broadcastDialogRegistered=ok
    return ok
end
showBroadcastPrompt=function(kind,lines)
    if not lines or #lines==0 then return false end
    if not ensureBroadcastDialog() then
        message(kind.." popup unavailable; use menu to preview.")
        return false
    end
    local preview={"BG Rating - "..kind, tostring(#lines).." eligible players"}
    for i=1,math.min(#lines,3) do
        local name=lines[i]:match("^BG Rating %- [^:]+:%s*([^|]+)") or ("Player "..i)
        local fp=lines[i]:match("([%d%.]+) ESOFP/G") or "?"
        preview[#preview+1]=name.."  -  "..fp.." FP/G"
    end
    if #lines>3 then preview[#preview+1]="+"..(#lines-3).." additional players" end
    preview[#preview+1]="X: Open party-chat draft    O: Close"
    pendingBroadcast={kind=kind,lines=lines,preview=table.concat(preview,"\n")}
    local ok=pcall(ZO_Dialogs_ShowDialog,"ESOFANTASY_BROADCAST_CONFIRM")
    if not ok then pendingBroadcast=nil;return false end
    return true
end

previewOppsReport=function()
    local lines,err=oppsReportLines()
    if not lines then message(err);return end
    message("BG Rating - OPPS REPORT (historical scouting):")
    for i=1,#lines do message(lines[i]) end
    message("Use PREPARE OPPS REPORT in settings to open a Party chat draft.")
end
prepareOppsReport=function()
    if oppsReportPreparedForMatch then
        message("OPPS REPORT already prepared this match. Preview is still available.")
        return
    end
    local lines,err=oppsReportLines()
    if not lines then message(err);return end
    local channel=constant("CHAT_CHANNEL_PARTY")
    -- One short, editable message; never send automatically or flood chat.
    local draft=lines[1]
    if #draft>300 then draft=draft:sub(1,297).."..." end
    if false and showBroadcastPrompt and showBroadcastPrompt("OPPS REPORT",lines) then
        oppsReportPreparedForMatch=true;return
    end
    local ok,why=preparePartyDraft(draft,channel)
    if ok then
        oppsReportPreparedForMatch=true
        -- Draft opens on the gameplay HUD; the player presses Send.
        if #lines>1 then message("Other opponents available in Preview OPPS REPORT.") end
    else message("Unable to open OPPS REPORT draft: "..tostring(why)) end
end

-- Manual scout database cleanup: never deletes match history or career totals.
local cleanupThreshold=100
local cleanupPending=nil
local function cleanupCandidates()
    local candidates={}
    if not saved or type(saved.players)~="table" then return candidates end
    local current=(saved.nextMatchId or 1)-1
    local ok,ownName=guardedCall("GetUnitName","player")
    local ownKey=ok and cleanPlayerName(ownName) or nil
    for key,p in pairs(saved.players) do
        if type(p)=="table" and (p.games or 0)==1
            and (not ownKey or cleanPlayerName(key)~=ownKey)
            and not p.favorite and not p.favorited and not p.bookmarked
            and not p.pinned and not p.protected then
            local last=p.lastSeenMatchId
            if type(last)~="number" and type(p.gameLog)=="table" then
                for _,g in ipairs(p.gameLog) do
                    if type(g.matchId)=="number" and (not last or g.matchId>last) then last=g.matchId end
                end
            end
            -- Legacy records with no trustworthy last-seen match are protected.
            if type(last)=="number" and current-last>=cleanupThreshold then
                candidates[#candidates+1]=key
            end
        end
    end
    table.sort(candidates)
    return candidates
end
local function previewScoutCleanup()
    local candidates=cleanupCandidates()
    cleanupPending={keys=candidates,threshold=cleanupThreshold,
        matchId=(saved and saved.nextMatchId or 1)-1}
    message(string.format("SCOUT CLEANUP: %d one-game profiles inactive for %d+ matches. Select CONFIRM CLEANUP to remove them; all other records remain.",#candidates,cleanupThreshold))
end
local function confirmScoutCleanup()
    local pending=cleanupPending
    cleanupPending=nil
    if not pending then message("Preview cleanup first. Nothing deleted.") return end
    if pending.threshold~=cleanupThreshold
        or pending.matchId~=(saved and saved.nextMatchId or 1)-1 then
        message("Database or threshold changed. Preview again before cleanup.") return
    end
    local eligible={}
    for _,key in ipairs(cleanupCandidates()) do eligible[key]=true end
    local removed=0
    for _,key in ipairs(pending.keys) do
        if eligible[key] and saved and saved.players[key] then
            saved.players[key]=nil
            removed=removed+1
        end
    end
    message(string.format("SCOUT CLEANUP COMPLETE: %d player profiles removed. Career and match history preserved.",removed))
    if selectedPlayerName and not (saved and saved.players[selectedPlayerName]) then
        selectedPlayerName=nil
    end
    refreshPanel()
end

local function handleCommand(input)
    local cmd = input and input:match("^%s*(%S+)") or ""
    if cmd == "menu" then togglePanel() return end
    if cmd == "close" or cmd == "hide" then
        if panel then panel:SetHidden(true) end
        updateShoulderBindings(false)
        return
    end
    if cmd == "career" then openDashboard("CAREER") return end
    if cmd == "seasons" then openDashboard("SEASONS") return end
    if cmd == "seasonnext" then careerSeasonPage=careerSeasonPage+1;openDashboard("SEASONS");return end
    if cmd == "seasonprev" then careerSeasonPage=math.max(1,careerSeasonPage-1);openDashboard("SEASONS");return end
    if cmd == "studs" then previewStudAlert() return end
    if cmd == "studdraft" then sendStudAlertDraft() return end
    if cmd == "oppsdraft" then prepareOppsReport() return end

    if cmd == "opps" then previewOppsReport() return end

    if cmd == "reportnext" then nextBroadcastLine() return end
    for _,mode in ipairs(scoutingModes) do
        if cmd==mode:lower() then openDashboard(mode);scoutingPage=1;refreshPanel();return end
    end

    if cmd == "preview" or cmd == "placement" then setHudPreviewPlacement(not hudPreviewPlacement);return end
    if cmd == "hud" then applyHudSetting("enabled",not hudSettings.enabled); message("Live HUD "..(hudSettings.enabled and "ON" or "OFF")) return end
    if cmd == "next" or cmd == "prev" then
        if viewMode=="HISTORY" then historyPage=math.max(1,historyPage+(cmd=="next" and 1 or -1))
        else scoreboardPage=math.max(1,scoreboardPage+(cmd=="next" and 1 or -1)) end
        refreshPanel() return
    end
    if cmd=="select" then confirmSelection() return end
    if cmd=="back" then backSelection() return end
    if cmd=="up" then navigateSelection(-1) return end
    if cmd=="down" then navigateSelection(1) return end
    if cmd=="profile" then
        local ok,n=guardedCall("GetUnitName","player")
        if ok and n then selectedPlayerName=cleanPlayerName(n);viewMode="PLAYER";profileTab=1;openDashboard("PLAYER") end
        return
    end
    if cmd == "cleanup" then previewScoutCleanup() return end
    if cmd == "cleanupconfirm" then confirmScoutCleanup() return end
    if cmd == "players" then viewMode="HISTORY" refreshPanel() return end
    if cmd == "sort" then historySort = historySort == "AVERAGE" and "GAMES" or "AVERAGE"; historyPage=1; viewMode="HISTORY"; refreshPanel() return end
    if cmd == "match" then viewMode="MATCH" refreshPanel() return end
    if cmd == "history" then
        message(string.format("Career: %d recorded games | %s FP/game | best %.1f FP", saved and saved.games or 0, average() and string.format("%.1f", average()) or "--", saved and saved.best or 0))
        return
    end
    if cmd == "discover" then discoverScoreboard() refreshPanel() return end
    if cmd == "scoreboard" then probeScoreboard() updateLiveStats() return end
    if cmd == "live" then
        updateLiveStats()
        if currentStats then
            message(string.format("Live K/D %d/%d | damage %d | healing %d | PARTIAL fantasy %.1f (no assists/objectives/win)", currentStats.kills, currentStats.deaths, currentStats.damage, currentStats.healing, currentStats.partial))
        else message("No local scoreboard snapshot available yet. Try during a Battleground.") end
        return
    end
    if cmd == "start" then startProbe() return end
    if cmd == "report" then reportProbe() return end
    if cmd == "stop" then stopProbe() message("Live probe stopped.") return end
    if input and input:match("^%s*diag%s*$") then
        diagnosticReport()
        return
    end
    if not input or input:match("^%s*$") then
        message("Use /esof start before BG, /esof report after BG, /esof stop to end probe")
        message("Use /esof diag for API checks, /esof discover for scoreboard function names")
        message("Use /esof menu for dashboard, /esof history for average; no manual recording")
        message("Use /esof scoreboard for diagnostics, /esof live for a partial score snapshot")
        message("Use /esof audit after a completed Battleground to inspect API support")
        message("Order: kills assists deaths damage healing objective-medals win 90s-carry 60s-carry")
        message("Flags: 1=yes, 0=no. Objective-medal coefficient currently applies to Chaosball only.")
        return
    end
    if cmd == "audit" then
        local function available(name) return type(_G[name]) == "function" or type(_G[name]) == "number" end
        for _, name in ipairs({"SCORE_TRACKER_TYPE_ASSISTS", "SCORE_TRACKER_TYPE_CAPTURE_DEFENSE_POINTS", "SCORE_TRACKER_TYPE_FLAG_CAPTURED", "SCORE_TRACKER_TYPE_FLAG_CARRIED_TIME", "BATTLEGROUND_STATE_FINISHED", "GetBattlegroundCumulativeScoreForScoreboardEntryByType", "GetCurrentBattlegroundState", "GetCurrentBattlegroundId", "DoesBattlegroundHaveRounds", "GetBattlegroundWinner", "GetWinningBattlegroundTeam", "GetBattlegroundWinningTeam"}) do
            message(name .. ": " .. (available(name) and "YES" or "NO"))
        end
        message("State: " .. tostring(select(2, guardedCall("GetCurrentBattlegroundState"))))
        message("Live stats: " .. (currentStats and string.format("K%d A%s D%d", currentStats.kills, tostring(currentStats.assists), currentStats.deaths) or "none"))
        return
    end
    message("Unknown command. Try /esof menu, /esof live, /esof audit or /esof history")
end

-- Optional settings-menu integration. LibAddonMenu provides the panel;
-- gamepad adapters such as LibGamepad expose LAM panels in console menus.
-- No direct modification of ESO's protected gamepad main-menu internals.
local settingsRegistered = false
local function registerSettingsMenu()
    if settingsRegistered then return true end
    local lam = LibAddonMenu2
    if not lam or type(lam.RegisterAddonPanel) ~= "function" or type(lam.RegisterOptionControls) ~= "function" then
        -- Quiet retry: library may not yet have loaded.
        return false
    end
    local ok, err = pcall(function()
        lam:RegisterAddonPanel("ESOFantasySettings", {
            type = "panel", name = "Battle Ground Rating", displayName = "Battle Ground Rating",
            author = "Trash Man Enterprises", version = "4.0.2",
            registerForRefresh = true,
        })
        lam:RegisterOptionControls("ESOFantasySettings", {
            {type="description",text="EVERY BATTLEGROUND IS GAME DAY"},
            {type="header",name="YOUR FANTASY ESO"},
            {type="button",name="CLOSE FANTASY ESO DASHBOARD",tooltip="Immediately hides the fantasy dashboard overlay.",
                func=function()
                    if panel then panel:SetHidden(true) end
                    updateShoulderBindings(false)
                end,width="full"},
            {type="header",name="PARTY CHAT REPORTS"},
            {type="description",text="To Use Stud Alert / Opps Report, first prepare the report, then press the Playstation button + Start, and then hit send - You can also bind the 'prepare report' to RadialMenu if you'd like!"},
            {type="button",name="PREPARE STUD ALERT",tooltip="Prepare the report. Use the matching LibRadialMenu action to open an editable Party chat draft.",func=function() sendStudAlertDraft() end,width="full"},
            {type="button",name="PREPARE OPPS REPORT",tooltip="Prepare the report. Use the matching LibRadialMenu action to open an editable Party chat draft.",func=function() prepareOppsReport() end,width="full"},
            {type="button",name="NEXT REPORT LINE",tooltip="Prepare the next player report. Use the NEXT REPORT DRAFT radial action to open chat.",func=function() nextBroadcastLine() end,width="full"},
            {type="button",name="CAREER HOME",tooltip="Your character's career, scouting identity, trends and BG record.",
                func=function() openDashboard("CAREER") end,width="full"},
            {type="button",name="SEASONS",tooltip="18-game seasons, available match logs and season stories.",
                func=function() careerSeasonPage=math.max(1,math.ceil(math.max(1,(ownCareer() or {}).games or 0)/18));openDashboard("SEASONS") end,width="full"},
            {type="button",name="BATTLEGROUNDS / LIVE SCOREBOARD",
                func=function() openDashboard("MATCH") end,width="full"},
            {type="button",name="SCOUTING / PLAYER HISTORY",
                func=function() historyPage=1;openDashboard("HISTORY") end,width="full"},
            {type="button",name="OPEN SELECTED PLAYER PROFILE",
                tooltip="Use after highlighting a player in the Scouting list.",
                func=function() confirmSelection() end,width="full"},
            {type="submenu",name="CAREER & PLAYER NAVIGATION",controls={
                {type="button",name="Previous season",func=function()careerSeasonPage=math.max(1,careerSeasonPage-1);openDashboard("SEASONS")end,width="half"},
                {type="button",name="Next season",func=function()careerSeasonPage=careerSeasonPage+1;openDashboard("SEASONS")end,width="half"},
                {type="button",name="Previous player / game",func=function()navigateSelection(-1)end,width="half"},
                {type="button",name="Next player / game",func=function()navigateSelection(1)end,width="half"},
                {type="button",name="Previous profile tab",func=function()if viewMode=="PLAYER" then profileTab=math.max(1,profileTab-1);refreshPanel()end end,width="half"},
                {type="button",name="Next profile tab",func=function()if viewMode=="PLAYER" then profileTab=math.min(3,profileTab+1);refreshPanel()end end,width="half"},
                {type="button",name="Back to player list",func=function()backSelection()end,width="full"},
                {type="button",name="Previous list page",func=function()if viewMode=="HISTORY" then historyPage=math.max(1,historyPage-1)else scoreboardPage=math.max(1,scoreboardPage-1)end;refreshPanel()end,width="half"},
                {type="button",name="Next list page",func=function()if viewMode=="HISTORY" then historyPage=historyPage+1 else scoreboardPage=scoreboardPage+1 end;refreshPanel()end,width="half"},
            }},
            {type="button",name="Preview HUD placement (all four HUDs)",func=function()setHudPreviewPlacement(not hudPreviewPlacement)end,width="full"},
            {type="submenu",name="SCOUT DATABASE CLEANUP",controls={
                {type="description",text="Manual cleanup of one-game player profiles. Unknown last-seen records and your own character are protected."},
                {type="slider",name="Inactive for this many Battlegrounds",min=1,max=100,step=1,
                    getFunc=function()return cleanupThreshold end,
                    setFunc=function(v)cleanupThreshold=v;cleanupPending=nil end},
                {type="button",name="PREVIEW ELIGIBLE PROFILES",
                    func=function()previewScoutCleanup()end,width="full"},
                {type="button",name="CONFIRM CLEANUP (DELETE PREVIEWED PROFILES)",
                    func=function()confirmScoutCleanup()end,width="full"},
            }},
            {type="submenu",name="SCOUTING SETTINGS",controls={
                {type="checkbox",name="Show STUD + OPPS scouting HUD",getFunc=function()return scoutingHudSettings.enabled end,setFunc=function(v)applyScoutingHudSetting("enabled",v)end},
                {type="checkbox",name="Auto-hide scouting HUD in combat",getFunc=function()return scoutingHudSettings.hideInCombat end,setFunc=function(v)applyScoutingHudSetting("hideInCombat",v)end},
                {type="slider",name="Scouting HUD horizontal",min=0,max=4000,step=10,getFunc=function()return scoutingHudSettings.x end,setFunc=function(v)applyScoutingHudSetting("x",v)end},
                {type="slider",name="Scouting HUD vertical",min=0,max=2500,step=10,getFunc=function()return scoutingHudSettings.y end,setFunc=function(v)applyScoutingHudSetting("y",v)end},
                {type="slider",name="Scouting HUD scale",min=65,max=160,step=5,getFunc=function()return scoutingHudSettings.scale end,setFunc=function(v)applyScoutingHudSetting("scale",v)end},
                {type="checkbox",name="Known-player reticle card",getFunc=function()return saved and saved.scoutReticleEnabled end,setFunc=function(v)if saved then saved.scoutReticleEnabled=v end end},
                {type="button",name="Advanced scouting intelligence",func=function()openDashboard("SCOUT")end,width="full"},
            }},
            {type="submenu",name="LIVE HUD SETTINGS",controls={
                {type="button",name="Toggle placement preview",func=function()setHudPreviewPlacement(not hudPreviewPlacement)end,width="full"},
                {type="checkbox",name="Show Live HUD",getFunc=function()return hudSettings.enabled end,setFunc=function(v)applyHudSetting("enabled",v)end},
                {type="checkbox",name="Auto-hide Live HUD in combat",getFunc=function()return hudSettings.hideInCombat end,setFunc=function(v)applyHudSetting("hideInCombat",v)end},
                {type="slider",name="Live HUD horizontal",min=0,max=1000,step=10,getFunc=function()return hudSettings.x end,setFunc=function(v)applyHudSetting("x",v)end},
                {type="slider",name="Live HUD vertical",min=0,max=1000,step=10,getFunc=function()return hudSettings.y end,setFunc=function(v)applyHudSetting("y",v)end},
                {type="slider",name="Live HUD scale",min=60,max=150,step=5,getFunc=function()return hudSettings.scale end,setFunc=function(v)applyHudSetting("scale",v)end},
                {type="checkbox",name="Show Team Snapshot HUD",getFunc=function()return teamHudSettings.enabled end,setFunc=function(v)applyTeamHudSetting("enabled",v)end},
                {type="slider",name="Team Snapshot horizontal",min=0,max=1600,step=10,getFunc=function()return teamHudSettings.x end,setFunc=function(v)applyTeamHudSetting("x",v)end},
                {type="slider",name="Team Snapshot vertical",min=0,max=900,step=10,getFunc=function()return teamHudSettings.y end,setFunc=function(v)applyTeamHudSetting("y",v)end},
                {type="slider",name="Team Snapshot scale",min=60,max=150,step=5,getFunc=function()return teamHudSettings.scale end,setFunc=function(v)applyTeamHudSetting("scale",v)end},
            }},
            {type="submenu",name="CHARACTER STRIP SETTINGS",controls={
                {type="checkbox",name="Show Career Strip outside BGs",getFunc=function()return profileSettings.enabled end,setFunc=function(v)applyProfileSetting("enabled",v)end},
                {type="slider",name="Career Strip horizontal",min=0,max=4000,step=10,getFunc=function()return profileSettings.x end,setFunc=function(v)applyProfileSetting("x",v)end},
                {type="slider",name="Career Strip vertical",min=0,max=2500,step=10,getFunc=function()return profileSettings.y end,setFunc=function(v)applyProfileSetting("y",v)end},
                {type="slider",name="Career Strip scale",min=60,max=150,step=5,getFunc=function()return profileSettings.scale end,setFunc=function(v)applyProfileSetting("scale",v)end},
            }},
            {type="button",name="Refresh live statistics",func=function()updateLiveStats();refreshPanel()end,width="full"},
        })
    end)
    if ok then
        settingsRegistered = true
        message("ESO Fantasy settings registered. Gamepad menu visibility requires a compatible settings-menu adapter.")
    else
        message("Settings menu registration failed; /esof menu still works: " .. tostring(err))
    end
    return settingsRegistered
end


local function finalizeMatch(reason)
    if match.finalized or not match.active then return end
    -- Preserve last valid snapshot: scoreboard APIs may disappear on match exit.
    updateLiveStats()
    currentStats = currentStats or lastMatchSnapshot
    if not currentStats or type(currentStats.partial)~="number" then return end
    match.finalized = true
    archivePlayers()
    saveCompletedScore(currentStats.partial)
    if saved then
        saved.partialGames=(saved.partialGames or 0)+(currentStats.complete and 0 or 1)
    end
    message("Match archived automatically ("..reason..").")
    if refreshPanel then refreshPanel() end
end

local broadcastPregamePrompted=false
local function beginMatch()
    if match.active then return end
    match={active=true,finalized=false,snapshots=0}
    archivedMatch=false
    finishedSeen=false
    lastMatchSnapshot=nil
    currentStats=nil
    teamRows={}
    studAlertUsedForMatch=false
    oppsReportPreparedForMatch=false
    broadcastPregamePrompted=false
    queuedPregameKind=nil
end

local function onBattlegroundStateChanged(_, previousState, newState)
    -- ESO's state-changed event can deliver both old and new states.
    local state=newState or previousState
    local finished=constant("BATTLEGROUND_STATE_FINISHED")
    local running=constant("BATTLEGROUND_STATE_RUNNING")
    local starting=constant("BATTLEGROUND_STATE_STARTING")
    if (running and state==running) or (starting and state==starting) then
        beginMatch()
        seenActiveBG=true
        -- Broadcast popups disabled in v2.6; passive HUD replaces them.
    elseif finished and state==finished then
        finishedSeen=true
        finalizeMatch("finished state")
    end
    if refreshPanel then refreshPanel() end
end

checkPregameBroadcasts=function()
    if broadcastPregamePrompted or not match.active then return end
    -- State constants are not consistent across console BG transitions.
    -- Wait until live scoreboard contains a local player and opponents.
    if not isBattlegroundActive() then return end
    updateLiveStats()
    local myTeam=nil
    local enemySeen=false
    for _,r in ipairs(teamRows) do
        if r.localPlayer then myTeam=r.team end
    end
    if myTeam==nil then return end
    for _,r in ipairs(teamRows) do
        if r.team~=nil and r.team~=myTeam then enemySeen=true;break end
    end
    if not enemySeen then return end
    local studs=studAlertDraft()
    local opps=oppsReportLines()
    if studs and #studs>0 then
        if showBroadcastPrompt("STUD ALERT",studs) then
            broadcastPregamePrompted=true;studAlertUsedForMatch=true
            if opps and #opps>0 then queuedPregameKind="OPPS REPORT" end
        end
    elseif opps and #opps>0 then
        if showBroadcastPrompt("OPPS REPORT",opps) then
            broadcastPregamePrompted=true;oppsReportPreparedForMatch=true
        end
    end
end
local function pollBattleground()
    local ok,active=guardedCall("IsActiveWorldBattleground")
    if not ok then return end
    if active==true then
        if not seenActiveBG then beginMatch() end
        seenActiveBG=true
        -- Broadcast popups disabled in v2.6; passive HUD replaces them.
    elseif seenActiveBG then
        -- Fallback when finished event was missed. This may include early exits;
        -- such scores remain provisional until explicit result confirmation.
        if match.active and not match.finalized and lastMatchSnapshot then
            currentStats=lastMatchSnapshot
            finalizeMatch("BG exit fallback; result may be provisional")
        end
        seenActiveBG=false
        match.active=false
    end
end

local function installScoreboardSceneHooks()
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetScene) ~= "function" then return end
    for _, sceneName in ipairs({"battleground_scoreboard", "battlegroundScoreboard", "battleground_scoreboard_gamepad", "gamepad_battleground_scoreboard"}) do
        local ok, scene = pcall(function() return SCENE_MANAGER:GetScene(sceneName) end)
        if ok and scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function(_, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    updateLiveStats()
                    if makePanel() then panel:SetHidden(false) end
                elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                    if panel then panel:SetHidden(true) end
                end
            end)
            message("Fantasy scoreboard overlay connected: " .. sceneName)
            return
        end
    end
    message("Native scoreboard scene not identified; dashboard remains accessible through addon menu.")
end


-- Native PS5 Battleground Finder scene: identifiers verified in ESO UI source.
-- Only a presentation overlay; never modifies queue controls or chat input.
local bgQueueOverlay, bgQueueLabel, bgQueueSub, bgQueueDivision
local bgQueueScene
local function bgRatingTier(rating)
    if rating>=2500 then return "GRANDMASTER"
    elseif rating>=2200 then return "MASTER"
    elseif rating>=1900 then return "DIAMOND"
    elseif rating>=1600 then return "PLATINUM"
    elseif rating>=1300 then return "GOLD"
    elseif rating>=1000 then return "SILVER"
    end
    return "BRONZE"
end
local function bgQueueRefresh()
    if not bgQueueOverlay then return end
    local p=ownCareer()
    local avg=p and rankedAverage(p)
    local rating=p and p.ranked and p.ranked.rating or (avg and rankedSeed(avg)) or 1500
    bgQueueLabel:SetText(rating and string.format("BG Rating  %d",rating) or "BG Rating  Unranked")
    local wins,losses=0,0
    if p then
        for i=1,math.max(1,math.ceil((p.games or 0)/18)) do
            local season=seasonStats(p,i)
            wins=wins+(season.wins or 0)
            losses=losses+(season.losses or 0)
        end
    end
    bgQueueSub:SetText(string.format("W: %d L: %d",wins,losses))
    if bgQueueDivision then
        local tier=rating and bgRatingTier(rating) or "UNRANKED"
        bgQueueDivision:SetText(tier)
        local colors={
            BRONZE={0.74,0.48,0.28},SILVER={0.73,0.79,0.86},
            GOLD={0.95,0.75,0.34},PLATINUM={0.55,0.85,0.91},
            DIAMOND={0.56,0.69,1.0},MASTER={0.79,0.58,0.98},
            GRANDMASTER={1.0,0.64,0.72},UNRANKED={0.7,0.7,0.7},
        }
        local c=colors[tier] or colors.UNRANKED
        bgQueueDivision:SetColor(c[1],c[2],c[3],1)
    end
end
local function bgQueueMake()
    if bgQueueOverlay then return true end
    local finder=BATTLEGROUND_FINDER_GAMEPAD
    if not finder or not finder.control or not finder.singularSection then return false end
    local ok=pcall(function()
        -- Parent to native BG Finder screen; anchor relative to its information panel.
        local root=finder.control
        local panel=finder.singularSection
        local overlay=WINDOW_MANAGER:CreateControl("ESOFantasyBGQueueRating",root,CT_CONTROL)
        overlay:SetMouseEnabled(false)
        overlay:SetAnchor(TOPLEFT,panel,TOPLEFT,25,1175)
        overlay:SetDimensions(550,170)
        overlay:SetDrawLayer(DL_OVERLAY)
        overlay:SetHidden(true)
        -- Restrained panel with a thin, native-style border and subtle background.
        local backdrop=WINDOW_MANAGER:CreateControl("ESOFantasyBGQueueRatingBackdrop",overlay,CT_BACKDROP)
        backdrop:SetAnchorFill(overlay)
        backdrop:SetCenterColor(0.025,0.035,0.055,0.80)
        backdrop:SetEdgeColor(0.20,0.65,0.90,0.95)
        backdrop:SetMouseEnabled(false)
        -- Console-safe border: four native texture strips rather than SetEdgeTexture.
        local function borderLine(name,anchor1,anchor2,x,y,w,h)
            local t=WINDOW_MANAGER:CreateControl(name,overlay,CT_TEXTURE)
            t:SetAnchor(anchor1,overlay,anchor2,x,y)
            t:SetDimensions(w,h)
            t:SetColor(0.20,0.65,0.90,0.95)
            t:SetMouseEnabled(false)
        end
        borderLine("ESOFantasyBGFrameTop",TOPLEFT,TOPLEFT,0,0,550,3)
        borderLine("ESOFantasyBGFrameBottom",BOTTOMLEFT,BOTTOMLEFT,0,0,550,3)
        borderLine("ESOFantasyBGFrameLeft",TOPLEFT,TOPLEFT,0,0,3,170)
        borderLine("ESOFantasyBGFrameRight",TOPRIGHT,TOPRIGHT,0,0,3,170)
        local accent=WINDOW_MANAGER:CreateControl("ESOFantasyBGFrameAccent",overlay,CT_TEXTURE)
        accent:SetAnchor(TOPLEFT,overlay,TOPLEFT,18,45)
        accent:SetDimensions(510,2)
        accent:SetColor(0.62,0.49,0.26,0.85)
        accent:SetMouseEnabled(false)
        local division=WINDOW_MANAGER:CreateControl("ESOFantasyBGQueueDivision",overlay,CT_LABEL)
        division:SetAnchor(TOPLEFT,overlay,TOPLEFT,22,12)
        division:SetDimensions(490,26)
        division:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
        division:SetMouseEnabled(false)
        local label=WINDOW_MANAGER:CreateControl("ESOFantasyBGQueueRatingValue",overlay,CT_LABEL)
        label:SetAnchor(TOPLEFT,division,BOTTOMLEFT,0,19)
        label:SetDimensions(490,44)
        label:SetFont("$(BOLD_FONT)|27|soft-shadow-thick")
        label:SetColor(0.97,0.95,0.87,1)
        label:SetMouseEnabled(false)
        local sub=WINDOW_MANAGER:CreateControl("ESOFantasyBGQueueRatingSub",overlay,CT_LABEL)
        sub:SetAnchor(TOPLEFT,label,BOTTOMLEFT,0,5)
        sub:SetDimensions(490,35)
        sub:SetFont("$(MEDIUM_FONT)|18|soft-shadow-thick")
        sub:SetColor(0.74,0.80,0.87,1)
        sub:SetMouseEnabled(false)
        bgQueueOverlay,bgQueueLabel,bgQueueSub,bgQueueDivision=overlay,label,sub,division
    end)
    return ok and bgQueueOverlay~=nil
end
local function installBGQueueOverlay()
    -- No polling, no guessed names: ESO declares this exact scene globally.
    bgQueueScene=GAMEPAD_BATTLEGROUND_FINDER_SCENE
        or (SCENE_MANAGER and SCENE_MANAGER:GetScene("gamepadBattlegroundFinder"))
    if not bgQueueScene then return end
    bgQueueScene:RegisterCallback("StateChange",function(_,newState)
        if newState==SCENE_SHOWING or newState==SCENE_SHOWN then
            if bgQueueMake() then
                bgQueueRefresh()
                bgQueueOverlay:SetHidden(false)
            end
        elseif newState==SCENE_HIDING or newState==SCENE_HIDDEN then
            if bgQueueOverlay then bgQueueOverlay:SetHidden(true) end
        end
    end)
end

-- Startup order deliberately matches the previously verified v0.6.1 build:
-- register the slash command and settings panel before any optional subsystems.
local function onLoaded(eventCode, addonName)
    if addonName ~= "ESOFantasy" then return end
    EVENT_MANAGER:UnregisterForEvent("ESOFantasy", EVENT_ADD_ON_LOADED)
    SLASH_COMMANDS["/esof"] = handleCommand
    message("Fantasy ESO v2.6 scouting HUD loaded. Use /esof menu.")
    local function safeInit(label, fn)
        local ok, err = pcall(fn)
        if not ok then message(label .. " unavailable: " .. tostring(err)) end
    end
    safeInit("Settings menu", function() registerSettingsMenu() end)
    safeInit("LibRadialMenu", function()
        if registerRadialMenu() then return end
        local attempts = 0
        EVENT_MANAGER:RegisterForUpdate("ESOFantasyRadialRetry", 3000, function()
            attempts = attempts + 1
            if registerRadialMenu() or attempts >= 10 then
                EVENT_MANAGER:UnregisterForUpdate("ESOFantasyRadialRetry")
            end
        end)
    end)
    safeInit("Saved history", function()
        if ZO_SavedVars and type(ZO_SavedVars.NewAccountWide) == "function" then
            saved = ZO_SavedVars:NewAccountWide("ESOFantasySaved", 2, nil, {games=0,total=0,best=0})
            rankedBootstrap()
            if type(saved.profileHud)=="table" then
                for _,key in ipairs({"enabled","hideInCombat","x","y","scale"}) do
                    if saved.profileHud[key] ~= nil then profileSettings[key]=saved.profileHud[key] end
                end
            end
            if type(saved.scoutingHud)=="table" then
                for _,key in ipairs({"enabled","x","y","scale"}) do
                    if saved.scoutingHud[key]~=nil then scoutingHudSettings[key]=saved.scoutingHud[key] end
                end
            end
            if type(saved.teamHud)=="table" then
                for _,key in ipairs({"enabled","x","y","scale"}) do
                    if saved.teamHud[key] ~= nil then teamHudSettings[key]=saved.teamHud[key] end
                end
            end
            if type(saved.hud)=="table" then
                for _,key in ipairs({"enabled","x","y","scale"}) do
                    if saved.hud[key] ~= nil then hudSettings[key]=saved.hud[key] end
                end
            end
        end
    end)
    safeInit("BG queue rating overlay", installBGQueueOverlay)
    safeInit("Native scoreboard overlay", installScoreboardSceneHooks)
    safeInit("Scoreboard updates", function()
        if type(EVENT_BATTLEGROUND_SCOREBOARD_UPDATED)=="number" then
            EVENT_MANAGER:RegisterForEvent("ESOFantasyLiveScoreboard", EVENT_BATTLEGROUND_SCOREBOARD_UPDATED, updateLiveStats)
        end
    end)
    safeInit("Match state", function()
        if type(EVENT_BATTLEGROUND_STATE_CHANGED)=="number" then
            EVENT_MANAGER:RegisterForEvent("ESOFantasyMatchState", EVENT_BATTLEGROUND_STATE_CHANGED, onBattlegroundStateChanged)
        end
    end)
    safeInit("Exit tracking", function()
        EVENT_MANAGER:RegisterForUpdate("ESOFantasyBGExitCheck", 2000, pollBattleground)
    end)
    if saved and saved.scoutReticleEnabled==nil then saved.scoutReticleEnabled=true end
    safeInit("Compact HUD", function()
        EVENT_MANAGER:RegisterForUpdate("ESOFantasyHUDTick", 1500, function()
            if isBattlegroundActive() then
                updateLiveStats()
            end
            updateHud()
            updateTeamHud()
            updateScoutingHud()
            updateProfileHud()
            updateReticleScout()
        end)
    end)
    safeInit("Deferred menu", function()
        EVENT_MANAGER:RegisterForUpdate("ESOFantasyMenuRetry", 5000, function()
            if settingsRegistered then
                EVENT_MANAGER:UnregisterForUpdate("ESOFantasyMenuRetry")
            else
                registerSettingsMenu()
            end
        end)
    end)
end

EVENT_MANAGER:RegisterForEvent("ESOFantasy", EVENT_ADD_ON_LOADED, onLoaded)
