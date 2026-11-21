-- ============================================================================
-- Bloom HPS - Data
-- The only file that talks to LibFights. Everything else asks this module for
-- the numbers, so a LibFights API change only needs fixing here.
--
-- Numbers are built in two steps:
--   Snapshot(fight)  -> "sums": raw totals of one fight (plain numbers only,
--                       so they can be added up and kept in SavedVariables)
--   FromSums(sums)   -> the stats table the UI, commands and history use
-- A battleground's totals are the sums of its fights added together.
-- ============================================================================

local M = HPSMeterUI
local Data = {}
M.Data = Data

local max = math.max

-- every field of a sums table; all are plain numbers that add up
Data.SUM_FIELDS = {
    "duration", "fights",
    "heal", "overheal", "selfHeal", "critHeal", "healHits", "healCrits",
    "shield", "groupShield", "mitigated", "damageIn",
}

function Data.NewSums()
    local sums = {}
    for _, key in ipairs(Data.SUM_FIELDS) do sums[key] = 0 end
    return sums
end

-- Adds `from` into `into` (both sums tables). Returns `into`.
function Data.AddSums(into, from)
    for _, key in ipairs(Data.SUM_FIELDS) do
        into[key] = (into[key] or 0) + (from[key] or 0)
    end
    return into
end

function Data.Snapshot(fight)
    local t = fight.totals
    return {
        duration    = fight:GetDurationSec(),
        fights      = 1,
        heal        = t.healOut or 0,
        overheal    = t.overheal or 0,
        selfHeal    = t.selfHeal or 0,
        critHeal    = t.healOutCrit or 0,
        healHits    = t.healHitsOut or 0,
        healCrits   = t.healCritsOut or 0,
        shield      = fight:GetTotalShield(),
        groupShield = fight:GetGroupShieldTotal(),
        mitigated   = fight:GetTotalMitigated(),
        damageIn    = t.damageIn or 0,
    }
end

local ZERO = {
    hps = 0, rawHps = 0, hpm = 0, healTotal = 0, healPersonal = 0, healGroup = 0,
    critHeal = 0, critHps = 0, critHealPct = 0, critHealRate = 0,
    sps = 0, spm = 0, shieldTotal = 0, shieldPersonal = 0, shieldGroup = 0,
    mitigated = 0, mps = 0, mpm = 0, mitigatedPct = 0,
    duration = 0, fights = 0,
    groupMode = false, active = false, hasFight = false, scope = "fight",
}
Data.ZERO = ZERO

-- Returns a table with:
--   hps / hpm        effective healing you did (overheal excluded), per second / minute
--   rawHps           healing per second including overheal
--   healTotal        all effective healing you did
--   healPersonal     your healing on yourself
--   healGroup        your healing on everyone else
--   critHeal         effective healing from critical heals / HoT crits
--   critHps          critHeal per second
--   critHealPct      0..100, share of your healing that came from crits
--   critHealRate     0..100, share of your heal hits that critted
--   sps / spm        damage absorbed by shields on you, per second / minute
--   shieldTotal      = shieldPersonal: damage absorbed by shields on you
--   shieldGroup      damage absorbed by shields on other group members (group mode)
--   mitigated        damage mitigated (shields exact; block, armor, avoid estimated)
--   mps / mpm        mitigated per second / minute
--   mitigatedPct     0..100, mitigated / (mitigated + damage taken)
--   duration, fights seconds in combat and number of fights the numbers cover
--   groupMode, active, hasFight, scope ("fight" or "bg")
function Data.FromSums(sums)
    local secs = max(1, sums.duration or 0)
    local heal = sums.heal or 0
    local hps = heal / secs
    local critHeal = sums.critHeal or 0
    local critShare = heal > 0 and critHeal / heal or 0
    local healHits = sums.healHits or 0
    local shield = sums.shield or 0
    local mitigated = sums.mitigated or 0
    local mitigatedAndTaken = mitigated + (sums.damageIn or 0)
    local selfHeal = sums.selfHeal or 0

    return {
        hps = hps,
        rawHps = (heal + (sums.overheal or 0)) / secs,
        hpm = hps * 60,
        healTotal = heal,
        healPersonal = selfHeal,
        healGroup = max(0, heal - selfHeal),

        critHeal = critHeal,
        critHps = hps * critShare,
        critHealPct = critShare * 100,
        critHealRate = healHits > 0 and (sums.healCrits or 0) / healHits * 100 or 0,

        sps = shield / secs,
        spm = shield / secs * 60,
        shieldTotal = shield,
        shieldPersonal = shield,
        shieldGroup = sums.groupShield or 0,

        mitigated = mitigated,
        mps = mitigated / secs,
        mpm = mitigated / secs * 60,
        mitigatedPct = mitigatedAndTaken > 0 and mitigated / mitigatedAndTaken * 100 or 0,

        duration = sums.duration or 0,
        fights = sums.fights or 0,
        groupMode = Data.IsGroupMode(),
        active = false,
        hasFight = true,
        scope = "fight",
    }
end

-- The running fight, or the last finished one so the meter keeps showing the
-- result after combat ends.
function Data.GetFight()
    return LibFights.GetLastFight()
end

function Data.GetCurrentFight()
    return LibFights.GetCurrentFight()
end

-- LibFights only records shields on other group members in group mode.
function Data.IsGroupMode()
    for _, namespace in ipairs(LibFights.Logger.GetRegisteredEvents()) do
        if namespace == "LibFights_LogCombatAll" then return true end
    end
    return false
end

-- After a battleground finishes the meter is cleared: the fight that was
-- showing at that moment no longer counts until a new one starts.
local clearedFight

function Data.ClearDisplay()
    clearedFight = Data.GetFight() or false
end

-- Stats for one fight.
function Data.GetFightStats(fight)
    if not fight then return ZERO end
    local stats = Data.FromSums(Data.Snapshot(fight))
    stats.active = fight:IsActive()
    return stats
end

-- What the meter shows: the running battleground's totals while in one (see
-- History), otherwise the current or last fight.
function Data.GetStats()
    local bgStats = M.History and M.History.GetBattlegroundStats()
    if bgStats then return bgStats end

    local fight = Data.GetFight()
    if not fight or fight == clearedFight then return ZERO end
    return Data.GetFightStats(fight)
end

-- Asks LibFights to start logging (it records nothing until this is called).
-- If another add-on already started it, its options (e.g. group mode) stay.
function Data.StartLogging(groupMode)
    if LibFights.IsLogging() then return true end
    return LibFights.Start_Logging({ groupMode = groupMode and true or false })
end
