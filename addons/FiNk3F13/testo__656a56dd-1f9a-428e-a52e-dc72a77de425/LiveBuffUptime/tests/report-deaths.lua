local env = dofile("tests/addon.lua")
local reports = LiveBuffUptimeReports
LFG_ROLE_DPS, LFG_ROLE_HEAL = 1, 4
local saved = { uptimeHistory = {} }
reports.Init(saved)
local function roster(healerAvailable, healerDead)
    return { { key = "@self", tag = "player", available = true, dead = false },
        { key = "@healer", tag = "group2", available = healerAvailable, dead = healerDead } }
end
reports.BeginEncounter(0, true, "@self")
reports.ObserveDeathRoster(roster(true, false), 0, "@self", false)
reports.ObserveDeath("@self", 5, true)
reports.ObserveDeath("@self", 6, true)
reports.ObserveDeath("@self", 9, false)
reports.ObserveDeath("@healer", 10, true)
reports.ObserveDeathRoster(roster(false, true), 12, "@self", false)
reports.ObserveDeath("@self", 16, true)
reports.ObserveDeathRoster(roster(true, true), 18, "@self", true)
local tracker = { config = { unit = "group", groupRole = "damage", id = 123, key = 1 }, displayPercent = 50,
    group = { firstDamageAt = 0, lastDamageAt = 20, members = {
        ["@self"] = { role = LFG_ROLE_DPS, meter = { intervals = { { 0, 10 } } }, eligibility = { intervals = { { 0, 20 } } } },
        ["@healer"] = { role = LFG_ROLE_HEAL, meter = { intervals = {} }, eligibility = { intervals = {} } },
    } } }
reports.CaptureFallback({tracker}, 0, 20, nil, false, function() return "Buff" end, roster(true, true), function() return false end)
local buff = saved.lastUptimeReport.buffs[1]
local self, healer
for _, member in ipairs(buff.members) do
    if member.account == "@self" then self = member else healer = member end
end
assert(self.deaths == 2 and self.deadTime == 8, "Repeated dead events must not double count, and an open death must clip at fight end")
assert(healer.deaths == 1 and healer.deadTime == 4, "Unavailable time must not be guessed as death time")
assert(healer.counted == false, "Excluded supports must still receive death diagnostics")
assert(buff.covered == 10 and buff.duration == 20 and buff.percent == 50, "Death diagnostics must not change uptime data")
reports.ObserveDeath("@self", 30, false)
assert(self.deadTime == 8, "Post-fight observations must not mutate a frozen report")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
reports.Open()
assert(env.controls.LiveBuffUptimeReportDeaths1.text == "1 Tode / 4,0 s tot")
assert(env.controls.LiveBuffUptimeReportDeaths2.text == "2 Tode / 8,0 s tot")
assert(env.controls.LiveBuffUptimeReportPercent1.text == "-")
reports.Close()
-- Starting already dead is not a newly observed death.
reports.BeginEncounter(30, true, "@self")
reports.ObserveDeath("@self", 30, true)
reports.ObserveDeath("@self", 35, false)
reports.CaptureFallback({tracker}, 30, 40, nil, false, function() return "Buff" end, {}, function() return false end)
for _, member in ipairs(saved.lastUptimeReport.buffs[1].members) do
    if member.account == "@self" then assert(member.deaths == 0 and member.deadTime == 5) end
end
assert(self.deaths == 2 and self.deadTime == 8, "The next encounter must reset diagnostics, not old snapshots")
print("Death reports: transitions, revive, open-death clipping, offline gaps, excluded supports, initial death, frozen data and unchanged uptime passed")
