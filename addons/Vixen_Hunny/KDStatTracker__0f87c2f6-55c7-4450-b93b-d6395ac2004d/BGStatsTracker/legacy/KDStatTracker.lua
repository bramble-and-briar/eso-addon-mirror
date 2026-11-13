KDStatTracker = {}
KDStatTracker.name = "KDStatTracker"
KDStatTracker.version = "2.0"
KDStatTrackerUI = {}
KDStatTracker.isLoaded = true
local wm = WINDOW_MANAGER
-- Tables that were missing and causing the crash
KDStatTracker.KillStreak = {
    count = 0,
    lastKillTime = 0,
    timeout = 10,
    banner = nil,
    label = nil
}
KDStatTracker.MultiKill = {
    count = 0,
    lastKillTime = 0,
    window = 5,
}
KDStatTracker.KDAVars = {
    kills = 0,
    deaths = 0,
}

KDStatTracker.defaults = {
    totalKills = 0,
    totalDeaths = 0,
    perCharKDA = {},
    matchHistory = {},
    matchCounter = 0,
    duels = {
        totalDuels = 0,
        wins = 0,
        losses = 0,
        perCharStats = {},
    },
    deathSources = {},
    killSources = {},
    -- Moved settings into defaults so they persist
}
KDStatTracker.default_settings = {
        showKD = true,
        x = 500,
        y = 500,
        scale = 1.0,
        fontSize = 18,
        fontColor = "FFFFFF"
    }

-- Constant Data
KDStatTracker.matchTypes = {
    [1] = "Deathmatch", [2] = "Domination", [3] = "Chaosball",
    [4] = "Capture the Relic", [5] = "King of the Hill",
    [6] = "Murderball", [7] = "Crazy King",
}

KDStatTracker.Streaks = {
    [2]  = { name = "Double Kill", color = {0.4, 1, 0.4, 1} },
    [3]  = { name = "Triple Kill", color = {0.3, 0.9, 1, 1} },
    [4]  = { name = "Mega Kill",   color = {0.8, 0.4, 1, 1} },
    [5]  = { name = "Ultra Kill",  color = {1, 0.6, 0.2, 1} },
    [10] = { name = "Godlike",     color = {1, 0.1, 0.8, 1} },
}

KDStatTracker.MultiKillNames = {
    [2] = "Double Kill",
    [3] = "Triple Kill",
    [4] = "Quadra Kill",
    [5] = "Penta Kill",
}
-- Safe KD ratio helper
function KDStatTrackerUI.ShowMultiKillBanner(count)
    local banner = WINDOW_MANAGER:GetControlByName("KDStatTracker_KillStreakBanner") or WINDOW_MANAGER:CreateTopLevelWindow("KDStatTracker_KillStreakBanner")
    banner:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
    banner:SetDimensions(500, 60)
    banner:SetHidden(true)

    local label = WINDOW_MANAGER:GetControlByName("KDStatTracker_KillStreakBannnerLabel") or WINDOW_MANAGER:CreateControl("KDStatTracker_KillStreakBannnerLabel", banner, CT_LABEL)
    label:SetAnchor(CENTER, banner, CENTER)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    KDStatTracker.KillStreak.label = label
    KDStatTracker.KillStreak.banner = banner
    local text = KDStatTracker.MultiKillNames[count]
    if not text then return end

    KDStatTracker.KillStreak.label:SetText(text)
    KDStatTracker.KillStreak.label:SetColor(1, 0.85, 0.2, 1)
    banner:SetAlpha(1)
    banner:SetHidden(false)

    if banner.timeline then
        banner.timeline:Stop()
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, banner, 1500)
    fade:SetAlphaValues(1, 0)

    timeline:SetHandler("OnStop", function()
        banner:SetHidden(true)
    end)

    timeline:PlayFromStart()
    banner.timeline = timeline
end
function KDStatTrackerUI.ResetMultiKill()
    KDStatTracker.MultiKill.count = 0
    KDStatTracker.MultiKill.lastKillTime = 0
end

function KDStatTrackerUI.ProcessMultiKill()
    local now = GetGameTimeSeconds()
    local mk = KDStatTracker.MultiKill

    if now - mk.lastKillTime <= mk.window then
        mk.count = mk.count + 1
    else
        mk.count = 1
    end

    mk.lastKillTime = now
    KDStatTrackerUI.ShowMultiKillBanner(mk.count)
end
function safeKD(kills, deaths)
    if deaths == 0 then return "N/A" end
    return string.format("%.2f", kills / deaths)
end
-- Duel tracking
function isDuelingStateChanged(eventCode, duelResult, wasResultofPlayer, opponentCharName, opponentDisplayName, _, _, _, _)
    local charName = GetUnitName("player")
    local duels = KDStatTracker.savedVars.duels
    duels.perCharStats[charName] = duels.perCharStats[charName] or { duels = 0, wins = 0, losses = 0, charactersFaced = {} }
    local charData = duels.perCharStats[charName]
    charData.charactersFaced[opponentDisplayName] = charData.charactersFaced[opponentDisplayName] or {wins = 0, losses = 0}

    -- Winning / losing logic
    if duelResult == DUEL_RESULT_WON then
        if wasResultofPlayer then
            duels.totalDuels = duels.totalDuels + 1
            duels.wins = duels.wins + 1
            charData.duels = charData.duels + 1
            charData.wins = charData.wins + 1
            local faced = charData.charactersFaced[opponentDisplayName]
            faced.wins = (faced.wins or 0) + 1
        else
            duels.totalDuels = duels.totalDuels + 1
            duels.losses = duels.losses + 1
            charData.duels = charData.duels + 1
            charData.losses = charData.losses + 1
            local faced = charData.charactersFaced[opponentDisplayName]
            faced.losses = (faced.losses or 0) + 1
        end
    elseif duelResult == DUEL_RESULT_FORFEIT then
        duels.totalDuels = duels.totalDuels + 1
        local faced = charData.charactersFaced[opponentDisplayName]
        if wasResultofPlayer then
            duels.losses = duels.losses + 1
            charData.duels = charData.duels + 1
            charData.losses = charData.losses + 1
            faced.losses = (faced.losses or 0) + 1
        else
            duels.wins = duels.wins + 1
            charData.duels = charData.duels + 1
            charData.wins = charData.wins + 1
            faced.wins = (faced.wins or 0) + 1
        end
    end
end
function KDStatTrackerUI.UpdateUI()
    local self = KDStatTracker
    if not KDStatTrackerUI.kdDisplayLabel then return end

    local charName = GetUnitName("player") or "Unknown"

    -- Ensure perCharKDA exists
    KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
    local kda = KDStatTracker.perCharKDA[charName]
    local ratio = string.format("%.2f", (KDStatTracker.KDAVars.kills / KDStatTracker.KDAVars.deaths))
    if ratio == inf then
        ratio = "1.00"
    end

    -- Ensure savedVars exist
    KDStatTracker.savedVars = KDStatTracker.savedVars or {}
    KDStatTracker.savedVars.killSources = KDStatTracker.savedVars.killSources or {}
    KDStatTracker.savedVars.deathSources = KDStatTracker.savedVars.deathSources or {}

    local killsources = KDStatTracker.savedVars.killSources[charName] or {}
    local deathsources = KDStatTracker.savedVars.deathSources[charName] or {}

    -- Find most kills
    local topKill, topKillCount, lastVictim = "N/A", 0, "N/A"
    for _, info in pairs(killsources) do
        if info and info.count and info.count > topKillCount then
            topKill = info.abilityName or "Unknown"
            topKillCount = info.count
            lastVictim = info.lastVictim or "N/A"
        end
    end

    -- Find most deaths
    local topDeath, topDeathCount, lastKiller = "N/A", 0, "N/A"
    for _, info in pairs(deathsources) do
        if info and info.count and info.count > topDeathCount then
            topDeath = info.abilityName or "Unknown"
            topDeathCount = info.count
            lastKiller = info.lastKiller or "N/A"
        end
    end

    -- Font color fallback
    local fontColor = (KDStatTracker.SettingsVars and KDStatTracker.SettingsVars.fontColor) or "FFFFFF"

    -- Set label text safely
    KDStatTrackerUI.kdDisplayLabel:SetText(string.format(
        "|c%sK: %d  D: %d  K/D: %s\nMost died to: %s - %d times (Last: %s)\nMost kills with: %s - %d times (Last: %s)|r",
        fontColor,
        KDStatTracker.KDAVars.kills,
        KDStatTracker.KDAVars.deaths,
        ratio,
        topDeath,
        topDeathCount or 0,
        lastKiller,
        topKill,
        topKillCount or 0,
        lastVictim
    ))
end

-- Battleground kill
function OnBattlegroundKill(eventCode, _, killerUnitTag, _, _, victimUnitTag, _, killType, abilityId)
    local playerName = GetUnitDisplayName("player") or ""
    if victimUnitTag ~= playerName then return end
    if killType == BATTLEGROUND_KILL_TYPE_KILLING_BLOW then
        local charName = GetUnitName("player")
        KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
        KDStatTracker.perCharKDA[charName] = KDStatTracker.perCharKDA[charName] or { kills = 0, deaths = 0 }
        KDStatTracker.currentMatchKills = (KDStatTracker.currentMatchKills or 0) + 1
        KDStatTracker.savedVars.totalKills = KDStatTracker.savedVars.totalKills + 1
        KDStatTracker.perCharKDA[charName].kills = KDStatTracker.perCharKDA[charName].kills + 1
        d("KDStatTracker. Kill recorded for " .. charName .. " (Killing Blow: " .. tostring(GetAbilityName(abilityId, "player")) .. ")")
    end
end

-- Player death
--function OnUnitDeathStateChanged(eventCode, unitTag, isDead)
--    if unitTag ~= "player" then return end
--    local playerName = GetUnitName("player")
--    KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
--    KDStatTracker.perCharKDA[playerName] = KDStatTracker.perCharKDA[playerName] or { kills = 0, deaths = 0 }
--   KDStatTracker.currentMatchDeaths = (KDStatTracker.currentMatchDeaths or 0) + 1
--    KDStatTracker.savedVars.totalDeaths = KDStatTracker.savedVars.totalDeaths + 1
--    KDStatTracker.perCharKDA[playerName].deaths = KDStatTracker.perCharKDA[playerName].deaths + 1
--    KDStatTrackerUI.ResetKillStreak()
--    d("KDStatTracker. Death recorded for " .. playerName)
--end

-- Activity finder
function OnActivityFinderStatusUpdate(eventCode, status, currentStatus)
    if not KDStatTracker.savedVars then return end
    if status == BATTLEGROUND_STATE_PREGAME and currentStatus == BATTLEGROUND_STATE_STARTING then
        if not KDStatTracker.currentMatchId then
            KDStatTracker.savedVars.matchCounter = (KDStatTracker.savedVars.matchCounter or 0) + 1
            KDStatTracker.currentMatchId = GetCurrentBattlegroundId()
            KDStatTracker.currentMatchKills = 0
            KDStatTracker.currentMatchDeaths = 0
            KDStatTracker.currentMatchType = GetBattlegroundGameType(KDStatTracker.currentMatchId)
            KDStatTracker.currentCharacterName = GetUnitName("player")
            KDStatTracker.ResetKillStreak()
            d("KDStatTracker. Match " .. KDStatTracker.currentMatchId .. " started")
        end
    elseif currentStatus == BATTLEGROUND_STATE_FINISHED or currentStatus == BATTLEGROUND_STATE_POSTGAME then
        local matchData = {
            matchId = KDStatTracker.currentMatchId or 0,
            kills = KDStatTracker.currentMatchKills or 0,
            deaths = KDStatTracker.currentMatchDeaths or 0,
            matchType = KDStatTracker.currentMatchType or 0,
            characterName = GetUnitName("player")
        }
        KDStatTracker.savedVars.matchHistory = KDStatTracker.savedVars.matchHistory or {}
        table.insert(KDStatTracker.savedVars.matchHistory, matchData)
        if #KDStatTracker.savedVars.matchHistory > 20 then
            table.remove(KDStatTracker.savedVars.matchHistory, 1)
        end
        local kdRatio = safeKD(matchData.kills, matchData.deaths)
        d(("KDStatTracker. Match %d ended. K/D: %d/%d Ratio: %s"):format(matchData.matchId, matchData.kills, matchData.deaths, kdRatio))
        KDStatTracker.currentMatchId = nil
    end
end

-- Combat Event
function OnCombatEvent(eventCode, ...)
    local result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceUnitId, targetUnitId, abilityId = ...
    local player = zo_strformat("<<1>>", GetUnitName("player") or "")
    local src = zo_strformat("<<1>>", sourceName or "")
    local tgt = zo_strformat("<<1>>", targetName or "")
    if sourceType ~= 5 and targetType ~= 5 then
        return
    end
    if sourceType ~= 0 and targetType ~= 0 then
        return
    end
    if sourceType ~= 1 and targetType ~= 1 then
        return
    end
    if (sourceType ~= 2 and targetType ~= 1) or (sourceType ~= 1 or targetType ~= 2) then
        return
    end
    if result ~= 2265 and result ~= ACTION_RESULT_TARGET_DEAD and result ~= ACTION_RESULT_KILLING_BLOW and result ~= ACTION_RESULT_DIED and result ~= ACTION_RESULT_DIED_XP  then
        return
    end
    if src == player and tgt ~= player then
        KDStatTrackerUI.ProcessMultiKill()
        KDStatTrackerUI.IncrementKillStreak()
        if abilityId == 0 then
            return
        end
        KDStatTrackerUI.RecordKill(abilityId or 0, abilityName or "Unknown", tgt)
    elseif tgt == player and src ~= player then
        KDStatTrackerUI.ResetKillStreak()
        KDStatTrackerUI.ResetMultiKill()
        KDStatTrackerUI.RecordDeath(abilityId or 0, abilityName or "Unknown", src)
    end
end

-- Kill / death recording
-- ========================
-- Safe Kill / Death Recording
-- ========================
local function DBG(step)
    d("|cff00cc[KD DEBUG]|r " .. step)
end
function KDStatTrackerUI.CreateUI()
    -- Safely get settings or use defaults if savedVars isn't ready
    local vars = (KDStatTracker.SettingsVars and KDStatTracker.SettingsVars) or KDStatTracker.defaults.settings
    KDStatTrackerUI.kdDisplay = wm:GetControlByName("KDStatTracker_KDDisplay")
    if not KDStatTrackerUI.kdDisplay then
        KDStatTrackerUI.kdDisplay = wm:CreateTopLevelWindow("KDStatTracker_KDDisplay")
    end

    -- 2. Configure Main Window
    KDStatTrackerUI.kdDisplay:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, vars.x, vars.y)
    KDStatTrackerUI.kdDisplay:SetDimensions(350, 80)
    KDStatTrackerUI.kdDisplay:SetMovable(true)
    KDStatTrackerUI.kdDisplay:SetMouseEnabled(true)
    KDStatTrackerUI.kdDisplay:SetClampedToScreen(true)
    
    -- Save position when the user stops dragging
    KDStatTrackerUI.kdDisplay:SetHandler("OnMoveStop", function(control)
        if KDStatTracker.savedVars and KDStatTracker.savedVars.settings then
            KDStatTracker.savedVars.settings.x = control:GetLeft()
            KDStatTracker.savedVars.settings.y = control:GetTop()
        end
    end)

    -- 3. Create or Get Label
    KDStatTrackerUI.kdDisplayLabel = wm:GetControlByName("KDStatTracker_KDDisplayKDLabel")
    if not KDStatTrackerUI.kdDisplayLabel then
        KDStatTrackerUI.kdDisplayLabel = wm:CreateControl("KDStatTracker_KDDisplayKDLabel", KDStatTrackerUI.kdDisplay, CT_LABEL)
    end

    -- 4. Configure Label
    local fontPath = string.format("/esoui/common/fonts/univers67.otf|%d|soft-shadow-thick", vars.fontSize or 18)
    KDStatTrackerUI.kdDisplayLabel:SetFont(fontPath)
    KDStatTrackerUI.kdDisplayLabel:SetAnchor(CENTER, KDStatTrackerUI.kdDisplay, CENTER, 0, 0)
    KDStatTrackerUI.kdDisplayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    KDStatTrackerUI.kdDisplayLabel:SetColor(1, 1, 1, 1)

    KDStatTrackerUI.kdDisplay:SetHidden(not vars.showKD)
    KDStatTrackerUI.UpdateUI()
end
-- Update visibility of the UI based on settings
function KDStatTrackerUI.UpdateVisibility()
    if KDStatTrackerUI.kdDisplay then
        
        KDStatTrackerUI.kdDisplay:SetHidden(not KDStatTracker.SettingsVars.showKD)
    end
end
-- Show stats and UI functions remain the same, but all nil checks are applied
-- ... (same as original code, but safeKD and nil checks used)
-- ========================
-- Slash Commands
-- ========================
SLASH_COMMANDS = SLASH_COMMANDS or {}

function formatKD(kills, deaths)
    kills = kills or 0
    deaths = deaths or 0
    local kd = deaths == 0 and "N/A" or string.format("%.2f", kills / deaths)
    return string.format("%d/%d (K/D: %s)", kills, deaths, kd)
end

-- /kd - Shows current character K/D
function CreateSlashCommands()

    SLASH_COMMANDS["/kd"] = function()
    local charName = GetUnitName("player")
    KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
    local kda = KDStatTracker.perCharKDA[charName] or { kills = 0, deaths = 0 }
    if kda.kills == 0 then
        
    end
    d(("KDStatTracker. %s — %s"):format(charName, formatKD(kda.kills, kda.deaths)))
end

-- /bgstats - Shows last 10 battleground matches
SLASH_COMMANDS["/bgstats"] = function()
    local history = KDStatTracker.savedVars.matchHistory or {}
    if #history == 0 then
        d("KDStatTracker. No battleground matches recorded.")
        return
    end
    d("KDStatTracker. Last BG Matches:")
    for i = math.max(1, #history - 9), #history do
        local m = history[i]
        local typeName = KDStatTracker.matchTypes[m.matchType] or "Unknown"
        d(("Match %d [%s]: %s"):format(m.matchId or i, typeName, formatKD(m.kills, m.deaths)))
    end
end

-- /duelstats - Shows duel stats for current character
SLASH_COMMANDS["/duelstats"] = function()
    local charName = GetUnitName("player")
    local duels = KDStatTracker.savedVars.duels or {}
    local charData = (duels.perCharStats or {})[charName] or { duels = 0, wins = 0, losses = 0 }
    d(("KDStatTracker. Duels for %s — Total: %d, Wins: %d, Losses: %d"):format(
        charName,
        charData.duels or 0,
        charData.wins or 0,
        charData.losses or 0
    ))
end

-- /killstats - Shows kills per ability
SLASH_COMMANDS["/killstats"] = function()
    local charName = GetUnitName("player")
    local kills = (KDStatTracker.savedVars.killSources or {})[charName] or {}
    if next(kills) == nil then
        d("KDStatTracker. No kills recorded for " .. charName)
        return
    end
    d("KDStatTracker. Kill Stats for " .. charName)
    for abilityId, info in pairs(kills) do
        d(("%s — %d kills (last victim: %s)"):format(info.abilityName or "Unknown", info.count or 0, info.lastVictim or "N/A"))
    end
end

-- /deathstats - Shows deaths per ability
SLASH_COMMANDS["/deathstats"] = function()
    local charName = GetUnitName("player")
    local deaths = (KDStatTracker.savedVars.deathSources or {})[charName] or {}
    if next(deaths) == nil then
        d("KDStatTracker. No deaths recorded for " .. charName)
        return
    end
    d("KDStatTracker. Death Stats for " .. charName)
    for abilityId, info in pairs(deaths) do
        d(("%s — %d deaths (last killer: %s)"):format(info.abilityName or "Unknown", info.count or 0, info.lastKiller or "N/A"))
    end
end
SLASH_COMMANDS["/mostkills"] = function()
    local charName = GetUnitName("player")
    local kills = KDStatTracker.savedVars.killSources[charName] or {}
    if next(kills) == nil then 
        d("KDStatTracker. No kills recorded for " .. charName) 
        return 
    end

    local topAbility, topCount, lastVictim = "N/A", 0, "N/A"
    for _, info in pairs(kills) do
        if info.count > topCount then
            topAbility = info.abilityName or "Unknown"
            topCount = info.count
            lastVictim = info.lastVictim or "N/A"
        end
    end
    d(("KDStatTracker. Most kills with %s — %d kills (Last victim: %s)"):format(topAbility, topCount, lastVictim))
end
SLASH_COMMANDS["/duels"] = function(displayName) 
    local charName = GetUnitName("player")
    local charData = KDStatTracker.savedVars.duels.perCharStats[charName]
    if not charData then
        d("KDStatTracker: No duel data for character " .. charName)
        return
    end
    if displayName  == "" then
        displayName = nil
        kdRatio = string.format("%.2f", (charData.wins / (charData.losses > 0 and charData.losses or 1)) or "N/A")
        d("KDStatTracker: Showing overall duel stats for " .. charName .. " (no specific opponent)" .. " - Total Duels: " .. charData.duels .. ", |c00ff00Wins: " .. charData.wins .. "|r, |cff0000Losses: " .. charData.losses .. "|r, |cff00ffW/L Ratio: " .. kdRatio .. "|r")
    end
    if displayName and charData.charactersFaced and charData.charactersFaced[displayName] then
        if not string.find(displayName, "@", 1, true) then
            d("KDStatTracker: Please provide a valid display name with @, e.g., /duels @OpponentUsername")
            return
        end
        local facedData = charData.charactersFaced[displayName]
        local kdRatio = string.format("%.2f", (facedData.wins / (facedData.losses > 0 and facedData.losses or 1)) or "N/A")
        d("KDStatTracker: Duel Stats Against " .. displayName .. " - |c00ff00 Wins: " .. facedData.wins .. "|r, |cff0000Losses: " .. facedData.losses .. "|r, |cff00ffW/L Ratio: " .. kdRatio .. "|r")
    elseif displayName then
        d("|cff0000KDStatTracker: No duel data against " .. displayName .. ".|r")
    end
end
-- Most deaths by ability
SLASH_COMMANDS["/mostdeaths"] = function()
    local charName = GetUnitName("player")
    local deaths = KDStatTracker.savedVars.deathSources[charName] or {}
    if next(deaths) == nil then 
        d("KDStatTracker. No deaths recorded for " .. charName) 
        return 
    end

    local topAbility, topCount, lastKiller = "N/A", 0, "N/A"
    for _, info in pairs(deaths) do
        if info.count > topCount then
            topAbility = info.abilityName or "Unknown"
            topCount = info.count
            lastKiller = info.lastKiller or "N/A"
        end
    end
    d(("KDStatTracker. Most deaths from %s — %d deaths (Last killer: %s)"):format(topAbility, topCount, lastKiller))
end
SLASH_COMMANDS["/kdhelp"] = function()
    d("|ccf00cfKDStatTracker Commands:|r")
    d("/kd - Show current character K/D stats")
    d("/bgstats - Show last battleground matches")
    d("/duelstats - Show duel stats for current character")
    d("/killstats - Show kills per ability")
    d("/deathstats - Show deaths per ability")
    d("/mostkills - Show most used kill abilities")
    d("/mostdeaths - Show most frequent death abilities")
    d("/duels @DisplayName - Allows for fetching personal duels with someone")
    end
end

-- Initialize addon
-- ========================
-- Addon Initialization
-- ========================
-- Initialize addon safely
function KDStatTrackerUI.ShowKillStreakBanner(count)
    local banner = WINDOW_MANAGER:GetControlByName("KDStatTracker_KillStreakBanner") or WINDOW_MANAGER:CreateTopLevelWindow("KDStatTracker_KillStreakBanner")
    banner:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
    banner:SetDimensions(500, 60)
    banner:SetHidden(true)

    local label = WINDOW_MANAGER:GetControlByName("KDStatTracker_KillStreakBannnerLabel") or WINDOW_MANAGER:CreateControl("KDStatTracker_KillStreakBannnerLabel", banner, CT_LABEL)
    label:SetAnchor(CENTER, banner, CENTER)
    label:SetFont("ZoFontWinH1")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local data = KDStatTracker.Streaks[count]
    if not data then return end

    KDStatTracker.KillStreak.label:SetText(data.name)
    KDStatTracker.KillStreak.label:SetColor(unpack(data.color))
    banner:SetAlpha(1)
    banner:SetHidden(false)

    if banner.timeline then
        banner.timeline:Stop()
    end

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, banner, 1800)
    fade:SetAlphaValues(1, 0)

    timeline:SetHandler("OnStop", function()
        banner:SetHidden(true)
    end)

    timeline:PlayFromStart()
    banner.timeline = timeline
end
function KDStatTrackerUI.ResetKillStreak()
    KDStatTracker.KillStreak.count = 0
    KDStatTracker.KillStreak.lastKillTime = 0
end
function KDStatTrackerUI.IncrementKillStreak()
    local now = GetGameTimeSeconds()
    local streak = KDStatTracker.KillStreak

    if now - streak.lastKillTime > streak.timeout then
        streak.count = 0
    end

    streak.count = streak.count + 1
    streak.lastKillTime = now

    KDStatTrackerUI.ShowKillStreakBanner(streak.count)
end
function KDStatTrackerUI.Initialize()
    KDStatTracker.savedVars = ZO_SavedVars:NewAccountWide(
        "KDStatTrackerVars", 1, nil, KDStatTracker.defaults
    )
    KDStatTracker.KDAVars = ZO_SavedVars:NewAccountWide(
        "KDStatTrackerKDA", 1, nil, KDStatTracker.KDAVars
    )
    KDStatTracker.SettingsVars = ZO_SavedVars:NewAccountWide(
        "KDStatTrackerSettings", 1, nil, KDStatTracker.default_settings
    )
    KDStatTracker.savedVars.perCharKDA = KDStatTracker.savedVars.perCharKDA or {}

    KDStatTrackerUI.CreateUI()

    EVENT_MANAGER:RegisterForEvent(
        KDStatTracker.name .. "_CombatEvent",
        EVENT_COMBAT_EVENT,
        OnCombatEvent
    )
    EVENT_MANAGER:RegisterForEvent(
        KDStatTracker.name .. "_ActivityFinderStatusUpdate",
        EVENT_BATTLEGROUND_STATE_CHANGED,
        OnActivityFinderStatusUpdate
    )
    EVENT_MANAGER:RegisterForEvent(
        KDStatTracker.name .. "_DuelStateChanged",
        EVENT_DUEL_FINISHED,
        isDuelingStateChanged
    )
    CreateSlashCommands()

end
function KDStatTrackerUI.RecordKill(abilityId, abilityName, victim)
    local charName = GetUnitName("player") or "Unknown"

    -- Ensure savedVars and killSources exist
    KDStatTracker.savedVars = KDStatTracker.savedVars or {}
    KDStatTracker.savedVars.killSources = KDStatTracker.savedVars.killSources or {}
    KDStatTracker.savedVars.killSources[charName] = KDStatTracker.savedVars.killSources[charName] or {}

    local tbl = KDStatTracker.savedVars.killSources[charName]
    abilityId = abilityId or 0
    tbl[abilityId] = tbl[abilityId] or { count = 0, lastVictim = "N/A", abilityName = abilityName or "Unknown" }

    -- Update count and last victim
    tbl[abilityId].count = (tbl[abilityId].count or 0) + 1
    tbl[abilityId].lastVictim = victim or "N/A"
    tbl[abilityId].abilityName = abilityName or "Unknown"

    -- Update per-character K/D
    KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
    KDStatTracker.perCharKDA[charName] = KDStatTracker.perCharKDA[charName] or { kills = 0, deaths = 0 }
    KDStatTracker.perCharKDA[charName].kills = (KDStatTracker.perCharKDA[charName].kills or 0) + 1

    -- Update persistent total
    KDStatTracker.savedVars.totalKills = (KDStatTracker.savedVars.totalKills or 0) + 1
    KDStatTracker.KDAVars.kills = (KDStatTracker.KDAVars.kills or 0) + 1

    -- Refresh UI
    KDStatTrackerUI.UpdateUI()

    d("KD: Killed " .. (victim or "Unknown") .. " with " .. (abilityName or "Unknown"))
end

function KDStatTrackerUI.RecordDeath(abilityId, abilityName, killer)
    local charName = GetUnitName("player") or "Unknown"

    -- Ensure savedVars and deathSources exist
    KDStatTracker.savedVars = KDStatTracker.savedVars or {}
    KDStatTracker.savedVars.deathSources = KDStatTracker.savedVars.deathSources or {}
    KDStatTracker.savedVars.deathSources[charName] = KDStatTracker.savedVars.deathSources[charName] or {}

    local tbl = KDStatTracker.savedVars.deathSources[charName]
    abilityId = abilityId or 0
    tbl[abilityId] = tbl[abilityId] or { count = 0, lastKiller = "N/A", abilityName = abilityName or "Unknown" }

    -- Update count and last killer
    tbl[abilityId].count = (tbl[abilityId].count or 0) + 1
    tbl[abilityId].lastKiller = killer or "N/A"
    tbl[abilityId].abilityName = abilityName or "Unknown"

    -- Update per-character K/D
    KDStatTracker.perCharKDA = KDStatTracker.perCharKDA or {}
    KDStatTracker.perCharKDA[charName] = KDStatTracker.perCharKDA[charName] or { kills = 0, deaths = 0 }
    KDStatTracker.perCharKDA[charName].deaths = (KDStatTracker.perCharKDA[charName].deaths or 0) + 1

    -- Update persistent total
    KDStatTracker.savedVars.totalDeaths = (KDStatTracker.savedVars.totalDeaths or 0) + 1
    KDStatTracker.KDAVars.deaths = (KDStatTracker.KDAVars.deaths or 0) + 1

    -- Refresh UI
    KDStatTrackerUI.UpdateUI()

    d("KD: Died to " .. (abilityName or "Unknown") .. " from " .. (killer or "Unknown"))
end
-- ========================
-- UI Creation and Updates
-- ========================
-- ========================
-- UI Creation and Updates
-- ========================

-- Called when the addon loaded
function KDStatTracker.OnAddOnLoaded(event, addonName)
    if addonName ~= KDStatTracker.name then return end
        EVENT_MANAGER:UnregisterForEvent(KDStatTracker.name, EVENT_ADD_ON_LOADED)
        KDStatTracker.isLoaded = true
        d("KDStatTracker. Addon initialized.") -- Debug message to confirm initialization
        d("KDStatTracker. Welcome to KDStatTracker! Use |cff00ff/kdhelp|r for commands. Thank you for using my addon! |ccf00cf~@Vixen Hunny|r") -- Welcome message
        KDStatTrackerUI.Initialize()
end

EVENT_MANAGER:RegisterForEvent(KDStatTracker.name, 
EVENT_ADD_ON_LOADED, 
KDStatTracker.OnAddOnLoaded)