dofile("Uptime.lua")
dofile("GroupUptime.lua")
local Group = LiveBuffUptimeGroup
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " != " .. tostring(expected))
end
local group = Group.New(0)
local members = {
    { key = "a", eligible = true, effect = { starts = 0, ends = 10 } },
    { key = "b", eligible = true },
}
Group.Update(group, members, 0, true)
Group.Update(group, members, 2, true)
near(group.percent, 50)
members[1].eligible = false
members[2].effect = { starts = 2, ends = 10 }
Group.Update(group, members, 2, true)
Group.Update(group, members, 4, true)
near(group.duration, 6)
near(group.percent, 100 * 4 / 6)
members[1].eligible = true
members[1].effect = nil
Group.Update(group, members, 4, true)
Group.Update(group, members, 6, true)
near(group.percent, 60)
Group.Update(group, members, 6, false)
Group.Update(group, members, 20, false)
near(group.percent, 60)
Group.Update(group, members, 21, true)
near(group.percent, 0)

-- Stable identities prevent a replacement in the same group slot inheriting data.
group = Group.New(0)
Group.Update(group, { { key = "old", eligible = true, effect = { starts = 0, ends = 5 } } }, 0, true)
Group.Update(group, { { key = "new", eligible = true } }, 2, true)
Group.Update(group, { { key = "new", eligible = true } }, 4, true)
near(group.percent, 50)

-- Joining/returning members cannot backfill time before they became eligible.
group = Group.New(0)
Group.Update(group, { { key = "a", eligible = true }, { key = "b", eligible = false } }, 0, true)
local returning = { { key = "a", eligible = true }, { key = "b", eligible = true, effect = { starts = 0, ends = 10 } } }
Group.Update(group, returning, 2, true)
Group.Update(group, returning, 4, true)
near(group.duration, 6)
near(group.percent, 100 * 2 / 6)
local earliest = Group.Update(group, {
    { key = "a", eligible = true, effect = { starts = 4, ends = 7 } },
    { key = "b", eligible = true, effect = { starts = 0, ends = 10 } },
}, 4, true)
assert(earliest.ends == 7)
print("Group: weighted uptime, death, resurrection, roster replacement, freezing and earliest timer passed")
