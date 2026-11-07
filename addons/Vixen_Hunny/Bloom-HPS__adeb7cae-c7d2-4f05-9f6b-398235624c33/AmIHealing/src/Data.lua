-- ============================================================================
-- Bloom HPS - Data
-- The only file that talks to LibFights. Everything else asks this module for
-- the numbers, so a LibFights API change only needs fixing here.
-- ============================================================================

local M = HPSMeterUI
local Data = {}
M.Data = Data

local max = math.max

local ZERO = {
    hps = 0, hpm = 0, healPersonal = 0, healGroup = 0,
    sps = 0, spm = 0, shieldTotal = 0, shieldPersonal = 0, shieldGroup = 0,
    mitigated = 0, mps = 0, mpm = 0, mitigatedPct = 0,
    groupMode = false, active = false, hasFight = false,
}

-- The running fight, or the last finished one so the meter keeps showing the
-- result after combat ends.
function Data.GetFight()
    return LibFights.GetLastFight()
end

-- LibFights only records shields on other group members in group mode.
function Data.IsGroupMode()
    for _, namespace in ipairs(LibFights.Logger.GetRegisteredEvents()) do
        if namespace == "LibFights_LogCombatAll" then return true end
    end
    return false
end

-- Returns a table with:
--   hps / hpm        effective healing you did (overheal excluded), per second / minute
--   healPersonal     your healing on yourself
--   healGroup        your healing on everyone else
--   sps / spm        damage absorbed by shields on you, per second / minute
--   shieldTotal      = shieldPersonal: damage absorbed by shields on you
--   shieldGroup      damage absorbed by shields on other group members (group mode)
--   mitigated        damage mitigated (shields exact; block, armor, avoid estimated)
--   mps / mpm        mitigated per second / minute
--   mitigatedPct     0..100, mitigated / (mitigated + damage taken)
--   groupMode, active, hasFight
function Data.GetStats()
    local fight = Data.GetFight()
    if not fight then return ZERO end

    local totals = fight.totals
    local healTotal = totals.healOut or 0
    local healPersonal = totals.selfHeal or 0
    local shieldTotal = fight:GetTotalShield()
    local mitigated = fight:GetTotalMitigated()
    local mitigatedAndTaken = mitigated + (totals.damageIn or 0)

    return {
        hps = fight:GetHPS(),
        hpm = fight:GetHPM(),
        healPersonal = healPersonal,
        healGroup = max(0, healTotal - healPersonal),

        sps = fight:GetSPS(),
        spm = fight:GetSPM(),
        shieldTotal = shieldTotal,
        shieldPersonal = shieldTotal,
        shieldGroup = fight:GetGroupShieldTotal(),

        mitigated = mitigated,
        mps = fight:GetMPS(),
        mpm = fight:GetMPM(),
        mitigatedPct = mitigatedAndTaken > 0 and mitigated / mitigatedAndTaken * 100 or 0,

        groupMode = Data.IsGroupMode(),
        active = fight:IsActive(),
        hasFight = true,
    }
end

-- Asks LibFights to start logging (it records nothing until this is called).
-- If another add-on already started it, its options (e.g. group mode) stay.
function Data.StartLogging(groupMode)
    if LibFights.IsLogging() then return true end
    return LibFights.Start_Logging({ groupMode = groupMode and true or false })
end
