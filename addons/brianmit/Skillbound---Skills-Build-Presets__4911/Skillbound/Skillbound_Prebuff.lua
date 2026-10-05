-- Skillbound_Prebuff.lua : prebuffs (2026-10-03), per build.
-- A build can hold up to 5 buff skills (b.prebuff.skills[3..7], b.prebuff.auto).
-- The game doesn't let addons cast skills, so a prebuff:
--   1 puts the build's buff skills into their slots on the bar you're using,
--   2 you press them (a short message says how many),
--   3 as soon as each one was used, your own skills come back by themselves (also after
--     sv.prebuff.restoreAfter seconds, when a fight starts, or with the keybind again).
-- Details:
--   * "if needed": skills whose buff is still running (more than 15 s left) are skipped; the
--     buffs a skill gives are learned the first time you cast it in a prebuff
--     (sv.prebuffBuffs[ability id] = { buff ability ids })
--   * no fixed delay: it waits until every slotted buff skill was really used
--   * Auto (per build): right after you wear the build and after loading screens
--   * the whole set is part of the build: shared in share codes, copied with the build
--   Prebuff.Start(build?) (keybind SKILLBOUND_PREBUFF, /sb prebuff, the "Now" button)

local B = Skillbound
local L = B.L
local Capture = B.Capture
local Prebuff = {}
B.Prebuff = Prebuff

Prebuff.FIRST, Prebuff.LAST = 3, 7
local STILL_UP_S = 15            -- a buff with more than this left doesn't need casting again
local LEARN_S = 1.5              -- buffs gained this soon after a cast belong to that skill
local BACK_DELAY_MS = 900        -- after the last cast: let it go off before the bar changes back

local active      -- { cat, orig = { [slot] = entry|false }, pending = { [slot] = ability id }, endsAt }
local learn       -- { id, untilT }

function Prebuff.Has(b)
    return b and b.prebuff and b.prebuff.skills and next(b.prebuff.skills) ~= nil
end

function Prebuff.IsActive() return active ~= nil end

local function Now() return GetFrameTimeSeconds() end

-- seconds left on the longest buff this skill is known to give (nil = not known / not running)
local function BuffLeft(abilityId)
    local known = B.sv.prebuffBuffs and B.sv.prebuffBuffs[abilityId]
    local want = {}
    for _, id in ipairs(known or {}) do want[id] = true end
    want[abilityId] = true   -- many buffs carry the skill's own id
    local best
    for i = 1, GetNumBuffs("player") do
        local _, _, timeEnding, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if want[id] then
            local left = (timeEnding or 0) - Now()
            if timeEnding == 0 then left = 9999 end   -- (no end: a toggle that's on)
            if not best or left > best then best = left end
        end
    end
    return best
end

local function Hotbar(cat)
    return ACTION_BAR_ASSIGNMENT_MANAGER and ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(cat)
end

local function CurrentBar()
    local cat = ACTION_BAR_ASSIGNMENT_MANAGER and ACTION_BAR_ASSIGNMENT_MANAGER.GetCurrentHotbarCategory
        and ACTION_BAR_ASSIGNMENT_MANAGER:GetCurrentHotbarCategory()
    if cat == HOTBAR_CATEGORY_PRIMARY or cat == HOTBAR_CATEGORY_BACKUP then return cat end
    return nil
end

-- puts entry (or nothing) into a slot; returns true, or false + why
local function Put(cat, slot, entry)
    local hotbar = Hotbar(cat)
    if not hotbar then return false, "?" end
    if not entry then
        local ok = pcall(hotbar.ClearSlot, hotbar, slot)
        return ok
    end
    local skillData, _, problem = B.Apply.FindSkill(entry)
    if not skillData or problem == "missing" or problem == "notLearned" then
        return false, B.Apply.SkillProblemText(entry, problem or "missing")
    end
    local result = hotbar:GetExpectedSkillSlotResult(slot, skillData)
    if result ~= HOT_BAR_RESULT_SUCCESS then
        local why = GetString("SI_HOTBARRESULT", result)
        return false, (why ~= "" and why or tostring(result))
    end
    hotbar:AssignSkillToSlot(slot, skillData)
    return true
end

local function StopWatching()
    B.EM:UnregisterForUpdate("Skillbound_PrebuffTick")
end

-- your own skills back (tries again every half second while the game refuses, up to a minute)
function Prebuff.Restore()
    if not active then return end
    local a = active
    a.restoring = true
    a.pending = {}
    local tries = 0
    local function Try()
        tries = tries + 1
        local left, failed = 0, nil
        for slot, entry in pairs(a.orig) do
            local ok = Put(a.cat, slot, entry or nil)
            if ok then a.orig[slot] = nil else left = left + 1 failed = entry and entry.name or "?" end
        end
        if left == 0 or tries > 120 then
            B.EM:UnregisterForUpdate("Skillbound_PrebuffBack")
            active = nil
            StopWatching()
            if left > 0 then B.Print(L("PRE_RESTORE_FAIL", failed)) end
            B.callbacks:FireCallbacks("PrebuffChanged")
        end
    end
    B.EM:UnregisterForUpdate("Skillbound_PrebuffBack")
    Try()
    if active then B.EM:RegisterForUpdate("Skillbound_PrebuffBack", 500, Try) end
end

local function Tick()
    local a = active
    if not a or a.restoring then return end
    if Now() >= a.endsAt or next(a.pending) == nil then Prebuff.Restore() end
end

-- quiet = an automatic start (no message when there's nothing to do)
function Prebuff.Start(build, quiet)
    if active then
        Prebuff.Restore()   -- pressed again: back to your skills
        return
    end
    build = build or B.WornBuild()
    if not Prebuff.Has(build) then
        if not quiet then B.Print(L("PRE_NONE")) end
        return
    end
    local cat = CurrentBar()
    if not cat then
        if not quiet then B.Print(L("PRE_BAR")) end
        return
    end
    -- only what isn't running (or isn't known to be running)
    local want = {}
    for slot = Prebuff.FIRST, Prebuff.LAST do
        local e = build.prebuff.skills[slot]
        if e and e.id then
            local left = BuffLeft(e.id)
            if not left or left <= STILL_UP_S then want[slot] = e end
        end
    end
    if next(want) == nil then
        if not quiet then B.Print(L("PRE_ALL_UP")) end
        return
    end
    local a = { cat = cat, orig = {}, pending = {}, endsAt = Now() + (B.sv.prebuff.restoreAfter or 12) }
    local n = 0
    -- a buff skill that's on this bar already (in any slot) stays where it is: just wait for its
    -- cast there (slotting it again would move it and leave a hole)
    local onBar = {}
    for s = Prebuff.FIRST, Prebuff.LAST do
        local cur = Capture.SlotSkill(cat, s)
        if cur then onBar[cur.id] = s end
    end
    for slot, e in pairs(want) do
        if onBar[e.id] then
            want[slot] = nil
            a.pending[onBar[e.id]] = e.id
            n = n + 1
        end
    end
    for slot, e in pairs(want) do
        local before = Capture.SlotSkill(cat, slot)
        if not (before and before.id == e.id) then
            local ok, why = Put(cat, slot, e)
            if ok then
                a.orig[slot] = before or false
                a.pending[slot] = e.id
                n = n + 1
            else
                B.Print(L("PRE_CANT", e.name or "?", why or "?"))
            end
        else
            a.pending[slot] = e.id   -- (it's on the bar already: just wait for the cast)
            n = n + 1
        end
    end
    if n == 0 then return end
    active = a
    B.Announce(L("PRE_CAST", n))
    B.EM:RegisterForUpdate("Skillbound_PrebuffTick", 200, Tick)
    B.callbacks:FireCallbacks("PrebuffChanged")
end

-- a slot was used: that buff is done (and the buffs it gives are learned)
local function OnSlotUsed(_, slot)
    local a = active
    if not a or a.restoring or not a.pending[slot] then return end
    if ACTION_BAR_ASSIGNMENT_MANAGER:GetCurrentHotbarCategory() ~= a.cat then return end
    learn = { id = a.pending[slot], untilT = Now() + LEARN_S }
    a.pending[slot] = nil
    if next(a.pending) == nil then
        -- the last one: give it a moment to go off, then back
        a.endsAt = math.min(a.endsAt, Now() + BACK_DELAY_MS / 1000)
    end
end

local function OnEffect(_, changeType, _, _, unitTag, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
    if not learn or unitTag ~= "player" or changeType ~= EFFECT_RESULT_GAINED then return end
    if Now() > learn.untilT then
        learn = nil
        return
    end
    if not endTime or not beginTime or endTime - beginTime < 5 then return end
    B.sv.prebuffBuffs = B.sv.prebuffBuffs or {}
    local list = B.sv.prebuffBuffs[learn.id] or {}
    for _, id in ipairs(list) do if id == abilityId then return end end
    if #list < 6 then list[#list + 1] = abilityId end
    B.sv.prebuffBuffs[learn.id] = list
end

-- Auto: right after wearing a build with Auto on, and after a loading screen while wearing it
local function AutoStart(delay, build)
    B.Later(function()
        local b = build or B.WornBuild()
        if b and b.prebuff and b.prebuff.auto and Prebuff.Has(b) and not IsUnitInCombat("player")
            and not B.Apply.IsRunning() and not active then
            Prebuff.Start(b, true)
        end
    end, delay)
end

function Prebuff.Init()
    if EVENT_ACTION_SLOT_ABILITY_USED then
        B.EM:RegisterForEvent("Skillbound_PrebuffUsed", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    end
    B.EM:RegisterForEvent("Skillbound_PrebuffEffect", EVENT_EFFECT_CHANGED, OnEffect)
    B.EM:AddFilterForEvent("Skillbound_PrebuffEffect", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    -- a fight starts: your own skills right back
    B.EM:RegisterForEvent("Skillbound_PrebuffCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if inCombat and active and not active.restoring then Prebuff.Restore() end
    end)
    B.EM:RegisterForEvent("Skillbound_PrebuffZone", EVENT_PLAYER_ACTIVATED, function()
        if active then Prebuff.Restore() end
        AutoStart(3000)
    end)
    B.callbacks:RegisterCallback("Worn", function(b)
        if b and b.prebuff and b.prebuff.auto then AutoStart(900, b) end
    end)
end
