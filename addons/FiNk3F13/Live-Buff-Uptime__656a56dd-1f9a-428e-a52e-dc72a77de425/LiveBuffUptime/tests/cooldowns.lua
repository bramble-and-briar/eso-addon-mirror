dofile("Uptime.lua")
dofile("GroupUptime.lua")
dofile("Cooldowns.lua")
local C, M, G = LiveBuffUptimeCooldowns, LiveBuffUptimeMeter, LiveBuffUptimeGroup
local nunatak = C.profiles[3]
assert(C.IsProc(nunatak, 167682) and not C.IsProc(nunatak, 172992))
assert(not C.IsProc(nunatak, 167681))
assert(C.Profile({ id = 172992, unit = "reticleover" }, 172992) == nunatak)
assert(not C.Profile({ id = 172992, unit = "reticleover", cooldownProfile = "none" }, 172992))
assert(C.TrackedId({ id = 172992, unit = "reticleover" }) == 145977)
for _, profile in ipairs(C.profiles) do
    local config = { cooldownProfile = profile.key, unit = profile.unit or "player" }
    assert(C.Profile(config, profile.effect) == profile)
    assert(not C.Profile(config, 123))
    assert(C.Start(profile, "me", 0))
    assert(C.Get(profile, "me", 1).ends == profile.seconds)
    assert(not C.Start(profile, "me", 2), "Duplicate proc must not extend cooldown")
    assert(not C.Get(profile, "other", 2), "Recipients must have independent cooldowns")
    assert(not C.Get(profile, "me", profile.seconds))
    assert(C.Start(profile, "me", profile.seconds))
end
local group = G.New(0)
local observations = {
    { key = "a", eligible = true, effect = { starts = 0, ends = 12 }, excluded = { starts = 0, ends = 22 } },
    { key = "b", eligible = true },
}
G.Update(group, observations, 0, true)
G.Update(group, observations, 12, true)
observations[1].effect = nil
G.Update(group, observations, 20, true)
assert(math.abs(group.percent - 30) < 0.001)
assert(math.abs(group.adjustedPercent - 37.5) < 0.001, "Exclude only the recipient's ineligible cooldown time")
observations[2].eligible = false
G.Update(group, observations, 22, true)
assert(group.eligibleMembers == 1)
local frozen = group.adjustedPercent
G.Update(group, observations, 22, false)
G.Update(group, observations, 30, false)
assert(group.adjustedPercent == frozen)
local scope = M.NewScope()
M.ScopeEvent(scope, "buff", 0, true)
M.ScopeEvent(scope, "buff", 12, false)
local excluded = M.New(0)
excluded.intervals = { { 0, 20 } }
assert(M.ScopePercentExcluding(scope, excluded, 0, 20) == 100)
print("Cooldowns: all profiles, duplicate protection, per-recipient grouping, exclusions and library scopes passed")
