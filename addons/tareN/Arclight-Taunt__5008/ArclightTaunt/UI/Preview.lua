-- Arclight Taunt | Combat preview simulation
-- Synthetic display samples share the live row contract; no ESO event tracking.
local A = ArclightTaunt
local T, Now = A.T, A.Now
local EXPIRED_LINGER = A.EXPIRED_LINGER

-- Display samples only, never a boss-detection list. Sources: docs/VORSCHAU_2026-11-02.md.
local DEMO_BOSSES = {"Rakkhat", "Nahviintaas", "Yolnahkriin", "Grundwulf", "Maarselok", "Balorgh"}
local DEMO_ENEMIES = {
    "Dro-m'Athra Hulk", "Dro-m'Athra Shadowguard", "Void Caller", "Alkosh's Roar",
    "Iron Servant", "Sea Behemoth", "Hulking Werewolf", "Flame Atronach",
    "Frost Atronach", "Storm Atronach", "Daedroth", "Ogrim", "Gargoyle", "Bone Colossus",
}
local MAX_DEMO_ENEMIES, DEMO_TAUNT_SECONDS = 24, 15
local DEMO_COMBAT_SECONDS = 60
local demoRoster, demoPoolSize
local function DemoNow(now)
    return A.demo and A.demoPausedAt or now
end
local function PoolSize()
    return math.min(MAX_DEMO_ENEMIES, math.max(14, A.saved.limit * A.saved.columns + 4))
end
local function ShuffledSamples(source)
    local result = {}
    for i, name in ipairs(source) do result[i] = name end
    -- Use the client's random generator without reseeding shared addon state.
    for i = #result, 2, -1 do
        local j = math.random(i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end
local function DemoRoster(count)
    local bosses, enemies = ShuffledSamples(DEMO_BOSSES), ShuffledSamples(DEMO_ENEMIES)
    local bossCount = count >= 17 and 3 or (count >= 9 and 2 or 1)
    -- Once per new roster, not once per tick or countdown loop.
    if math.random(10) == 1 then bosses[math.random(bossCount)] = "Lord Okyl" end
    local roster, bossIndex, enemyIndex = {}, 1, 1
    for i = 1, count do
        local boss = i == (count < 3 and 1 or 3) or i == 9 or i == 17
        local name
        if boss then
            name, bossIndex = bosses[bossIndex], bossIndex + 1
        else
            name = enemies[(enemyIndex - 1) % #enemies + 1]
            enemyIndex = enemyIndex + 1
        end
        roster[i] = {name = T(name), isBoss = boss}
    end
    return roster
end

local function CreateDemo(count, keepRoster, startedAt)
    local now = startedAt or DemoNow(Now())
    demoPoolSize = PoolSize()
    count = math.floor(A.Clamp(count or demoPoolSize, 1, MAX_DEMO_ENEMIES))
    if not keepRoster or not demoRoster or #demoRoster ~= count then demoRoster = DemoRoster(count) end
    -- Join an encounter already in progress. Stagger old applications and later
    -- single arrivals; random values are drawn only when a cycle is created.
    local initialCount = math.min(count, 4 + math.random(3))
    local nextArrival, lastEnd = 0, now
    local entries = {}
    for i = 1, count do
        local sample = demoRoster[i]
        local startTime
        if i <= initialCount then
            local age = 0.5 + (i - 1) * 11.5 / math.max(1,initialCount - 1) + math.random(1000) / 1250
            startTime = now - age
        else
            nextArrival = nextArrival + 0.55 + math.random(1550) / 1000
            startTime = now + nextArrival
        end
        local starts = {startTime}
        -- Prepare a bounded minute of irregular re-taunts once, not per tick.
        -- Some refresh before expiry; others leave a brief lapse in coverage.
        local nextStart = math.max(now + 0.8 + math.random(2000) / 1000,
            startTime + 11 + math.random(10000) / 1000)
        while nextStart < now + DEMO_COMBAT_SECONDS do
            starts[#starts + 1] = nextStart
            nextStart = nextStart + 11 + math.random(10000) / 1000
        end
        entries[#entries + 1] = {
            name = sample.name, unitId = "demo" .. i,
            startTime = startTime, endTime = startTime + DEMO_TAUNT_SECONDS,
            order = i, isBoss = sample.isBoss,
            -- Synthetic examples only; no game marker is placed or read.
            targetMarkerTexture = A.GetTargetMarkerTexture((i == 2 and TARGET_MARKER_TYPE_TWO)
                or (i == 4 and TARGET_MARKER_TYPE_ONE) or nil),
            demoStarts = starts, demoApplication = 1,
        }
        lastEnd = math.max(lastEnd, starts[#starts] + DEMO_TAUNT_SECONDS)
    end
    A.demoAt = now
    A.demoFocusId, A.demoFocusUntil = nil, nil
    A.demoCycleLength = lastEnd - now + EXPIRED_LINGER + 1 + math.random(1000) / 1000
    return entries
end

local function SetDemoPaused(paused)
    if A.moving and not paused then return end
    if not A.demo then A.demoPausedAt = nil; return end
    local now = Now()
    if paused then
        A.demoPausedAt = A.demoPausedAt or now
    elseif A.demoPausedAt then
        local delta = now - A.demoPausedAt
        for _, t in ipairs(A.demoEntries or {}) do
            t.startTime, t.endTime = t.startTime + delta, t.endTime + delta
            for i, start in ipairs(t.demoStarts or {}) do t.demoStarts[i] = start + delta end
            if t.expiredAt then t.expiredAt = t.expiredAt + delta end
        end
        if A.demoAt then A.demoAt = A.demoAt + delta end
        if A.demoFocusUntil then A.demoFocusUntil = A.demoFocusUntil + delta end
        if A.focusAcquiredAt then A.focusAcquiredAt = A.focusAcquiredAt + delta end
        if A.gloss and A.gloss.owner then A.gloss.at = A.gloss.at + delta end
        for target, at in pairs(A.rowEntryStarts or {}) do A.rowEntryStarts[target] = at + delta end
        for _, row in ipairs(A.rows or {}) do
            if row.stripeAt then row.stripeAt = row.stripeAt + delta end
            if row.placementAt then row.placementAt = row.placementAt + delta end
            if row.revealAt then row.revealAt = row.revealAt + delta end
        end
        A.demoPausedAt = nil
    end
end
local function SetDemoEnabled(enabled)
    if A.moving then return end
    if A.StopGloss then A.StopGloss() end
    A.lastVisibleItems = nil
    A.listPeakRows, A.listPeakFooter = nil, nil
    A.demoPausedAt = nil
    A.demoFocusId, A.demoFocusUntil = nil, nil
    A.demo = enabled == true
    if A.demo then
        A.demoEntries = CreateDemo()
    else
        A.demoEntries, demoRoster, demoPoolSize = nil, nil, nil
    end
end

-- Advance synthetic taunts only when the list preview is active.
-- Sorting and live target expiry stay in Tracking.lua.
local function GatherDemo(now, bossOnly)
    now = DemoNow(now)
    local active, lost = {}, {}
    if not A.demoEntries then
        A.demoEntries = CreateDemo()
    elseif demoPoolSize and demoPoolSize ~= PoolSize() then
        -- Capacity changes rebuild once using the same (possibly paused) clock.
        -- Keep a still-existing preview focus instead of restarting its lifetime.
        local focusId, focusUntil = A.demoFocusId, A.demoFocusUntil
        A.demoEntries = CreateDemo(nil, false, now)
        for _, target in ipairs(A.demoEntries) do
            if target.unitId == focusId then
                A.demoFocusId, A.demoFocusUntil = focusId, focusUntil
                break
            end
        end
    elseif now - A.demoAt >= A.demoCycleLength then
        A.demoEntries = CreateDemo(nil, false, now)
    end
    for _, t in ipairs(A.demoEntries) do
        local starts, application = t.demoStarts, t.demoApplication or 1
        if starts then
            while starts[application + 1] and starts[application + 1] <= now do
                application = application + 1
            end
            if application ~= t.demoApplication then
                t.demoApplication = application
                t.startTime = starts[application]
                t.endTime = t.startTime + DEMO_TAUNT_SECONDS
                t.expiredAt = nil
            end
        end
        if t.startTime <= now then
            if t.endTime <= now and not t.expiredAt then t.expiredAt = t.endTime end
            if not A.IsLost(t, now) then
                if not bossOnly or A.BossVisible(t) then active[#active + 1] = t end
            elseif A.saved.showExpired or now - t.expiredAt < EXPIRED_LINGER then
                if not bossOnly or A.BossVisible(t) then lost[#lost + 1] = t end
            end
        end
    end
    return active, lost
end

-- Public entry points used by placement, settings and the shared HUD clock.
A.CreateDemo = CreateDemo
A.DemoNow = DemoNow
A.SetDemoPaused = SetDemoPaused
A.SetDemoEnabled = SetDemoEnabled
A.GatherDemo = GatherDemo
