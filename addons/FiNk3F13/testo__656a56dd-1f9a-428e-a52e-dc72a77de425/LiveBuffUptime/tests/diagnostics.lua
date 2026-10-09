dofile("Diagnostics.lua")
local Audit = LiveBuffUptimeDiagnostics
local lines = {}
local audit = Audit.New(function(line) lines[#lines + 1] = line end)
local function job(percent)
    return { label = "Test", starts = 0, ends = 10, duration = 10, percent = percent or 50,
        members = { { intervals = { { 0, 5, 5 } } } } }
end
Audit.Queue(audit, job())
assert(#audit.jobs == 0, "Disabled diagnostic must retain no measurements")
Audit.SetEnabled(audit, true)
Audit.RecordTime(audit, 2)
Audit.RecordTime(audit, 7)
local function drain()
    for _ = 1, 1000 do
        if #audit.jobs == 0 then return end
        Audit.Tick(audit)
    end
    error("Diagnostic never completed")
end
Audit.Queue(audit, job())
drain()
assert(audit.last[1]:find("OK intern", 1, true))
assert(lines[#lines]:find("1 ab 5ms", 1, true))
Audit.Queue(audit, job(70))
drain()
assert(audit.last[#audit.last]:find("Anzeige und Nachrechnung", 1, true))
local invalid = job()
invalid.members[1].intervals = { { 0, 6, 99 }, { 4, 8 } }
Audit.Queue(audit, invalid)
drain()
assert(audit.last[#audit.last]:find("Zwischensumme", 1, true))
assert(audit.last[#audit.last]:find("ueberlappende", 1, true))
invalid = job()
invalid.members[1].intervals = { { 8, 4 } }
Audit.Queue(audit, invalid)
drain()
assert(audit.last[#audit.last]:find("ungueltiger Zeitabschnitt", 1, true))
local group = job(50)
group.group = true
group.members = {
    { intervals = { { 0, 5 } }, eligibility = { { 0, 10 } } },
    { intervals = { { 0, 5 } }, eligibility = { { 0, 10 } } },
}
Audit.Queue(audit, group)
drain()
assert(audit.last[#audit.last]:find("OK intern", 1, true))
local adjusted = job(100)
adjusted.members[1].excluded = { { 0, 10 } }
Audit.Queue(audit, adjusted)
drain()
assert(audit.last[#audit.last]:find("OK intern", 1, true), "Active time must not be excluded")

-- Work and memory are bounded, even for a pathological combat history.
local huge = job()
huge.ends, huge.duration = 50000, 50000
huge.members[1].intervals = {}
for index = 1, 17000 do huge.members[1].intervals[index] = { index * 2, index * 2 + 1 } end
Audit.Queue(audit, huge)
Audit.Tick(audit)
assert(#audit.jobs == 1 and coroutine.status(audit.jobs[1].worker) == "suspended", "Large reports must yield")
drain()
assert(audit.last[#audit.last]:find("Prueflimit erreicht", 1, true))
for _ = 1, 20 do Audit.Queue(audit, job()) end
assert(#audit.jobs == 12 and audit.dropped == 8)
Audit.SetEnabled(audit, false)
assert(#audit.jobs == 0 and #audit.last == 0)
Audit.SetEnabled(audit, true)
audit.output = function() error("broken chat hook") end
invalid = job()
invalid.members = { false }
Audit.Queue(audit, invalid)
assert(pcall(drain), "Diagnostic data and output errors must not escape")
assert(audit.last[1]:find("WARN", 1, true))
print("Diagnostics: independent totals, warnings, exclusions, group time, bounded slices/queue and error isolation passed")
