-- Global cooldown (Trigger "Global cooldown"): the 1 s lock after a skill, a cast / channel, a heavy attack, a roll
-- dodge, a synergy / item / companion... -- one bar that tells you when your next input lands, with your ping as the
-- window to queue it in.
--
-- Built from Combat Metronome 1.7.7 / 1.7.8 beta (DariansUtilities Ability.Tracker + CMProgressbar + CMFunctions),
-- GCD Bar 2.6 and Global Cooldown Monitor 2.01, read line by line. Their model, and how this follows it:
--
-- THE GCD. GetSlotCooldownInfo(slot, hotbar) on skill slots 3-8 -> remain, duration (ms), isGlobal: the first global
--   slot is the GCD (Metronome GCDCheck; esoui actionbutton.lua). Read on EVENT_ACTION_UPDATE_COOLDOWNS and every
--   frame while something runs (Metronome: 30 Hz tracker + 60 Hz bar; GCD Bar: 20 ms; GCD Monitor: the event).
-- WHICH SKILL. EVENT_ACTION_SLOT_ABILITY_USED(slot 3-8) queues it (a toggle being switched off -- IsSlotToggled --
--   isn't a cast; a scribed slot -> GetAbilityIdForCraftedAbilityId). It becomes the running event when its GCD
--   starts, start = now + remain - duration, by whichever comes first (Metronome's four triggers):
--     "direct"      the cooldown update came first in the same frame, GCD at 100 %;
--     "CD updated"  a cooldown update while the GCD is no older than your ping;
--     "late"        the GCD is past 90 % (fresh) and no update came;
--     "CombatEvent" your BEGIN / EFFECT_GAINED of that ability.
--   Only once the previous event has reached its end (without adjust -- Metronome's `ending`), except over a heavy
--   attack, and not during a roll dodge. The queue is dropped on block, roll dodge, bar swap, death, its target
--   already dead, a new press, or when older than max(previous end, press) + max(its delay, 1 s).
-- LENGTH. GetAbilityCastInfo(id) -> channeled, ms ("delay"). Bar = max(GCD, delay) + adjust (instant: "GCD adjust";
--   cast / channel: "ability adjust"; + per-skill adjust); heavy = delay + "heavy adjust". Exhausting Fatecarver
--   + 338 ms per Crux (buff 184220); Meditate = 1 s. An instant or a cast of at most 1 s ends with the game's GCD.
--   GCD Monitor: channels over 1 s = channel + "channel time delay"; everything else = the GCD ("casts for their
--   length" off). GCD Bar: just the GCD.
-- HEAVY ATTACKS. Your EVENT_COMBAT_EVENT, slot type ACTION_SLOT_TYPE_HEAVY_ATTACK, BEGIN / BEGIN_CHANNEL, the ability
--   on slot 2 of the active bar. Ended by a new GCD, its slot released (not global, remain == duration), bar swap,
--   block, dodge. A heavy attack ends a cast / channel in progress (GCD Monitor: slot 2 during a channel).
-- ENDED EARLY. Block turning on while a cast / channel / heavy is within its delay; roll dodge (28549 gained); bar
--   swap during a heavy or anything over 1 s; weapon lock released during a cast; death; for the running ability:
--   its effect faded (from you; or on you when over 1 s), Radiant Destruction's beam ending, "on cooldown" error
--   within 100 ms of the press, no location, silenced, and on enemy-target abilities immune / staggered / target
--   dead / its target died. With "cooldowns without a skill" (Metronome "Track all GCDs") what's left of the GCD
--   shows under the reason (Blocked, Error, Effect faded, Invalid location, Silenced, Stagger, Target dead,
--   Target immune -- Metronome's reasonToGCDMapping); otherwise the bar ends there.
--   Crowd control on you also ends a cast / channel. Metronome means to, but its test `not sType == PLAYER` is
--   always false (`not` binds first) so it never does; this one does (no reason shown, as there).
-- COOLDOWNS WITHOUT A SKILL ("Track all GCDs"): named after a roll dodge, breaking free (16565), a synergy
--   (EVENT_SYNERGY_ABILITY_CHANGED, then your combat event of that name), an item (EVENT_INVENTORY_ITEM_USED, then
--   the backpack slot that lost one), an assistant / companion (EVENT_COLLECTIBLE_UPDATED), mounting / dismounting
--   (36432 gained / 37059 begin) and festival throwables (242982, 84330, 87474) -- these two only out of combat
--   with nothing running; else "Global cooldown".
-- PING. GetLatency(), capped (150 ms), as the end of the bar -- on heavies and skill-less GCDs only if wanted.
-- METRONOME SOUNDS (Metronome's tick / tock, for skills, casts, channels, heavies -- not skill-less GCDs):
--   tick at the start + offset, the middle + offset, or N ms before the end; tock at the ability's end (delay, at
--   least 1 s, no adjust) + offset -- still played during the next event when that started first ("force"), else
--   dropped; with no event running only once the GCD is over (or a negative offset). An event that ends before its
--   tick plays it then if the GCD hasn't passed the tick's point ("force"). Repeated <volume> times; only in combat
--   unless allowed; optionally not on heavies / abilities over 1 s.
--
-- Pay for what you use: nothing is registered unless a tracker uses this trigger; the per-ability listener, the
-- synergy-name listener and the per-frame check exist only while they have something to do.

local DT = DebuffTracker
local G = {}
DT.GlobalCooldown = G
local U = DT.Util
local L = DT.L

local NS = "DebuffTracker5_GCD"
G.ROLL_DODGE, G.BREAK_FREE, G.CRUX = 28549, 16565, 184220
G.FATECARVER = { [183122] = true, [193397] = true }
G.MEDITATE = { [103665] = true, [103492] = true, [103652] = true }
G.MEND_WOUNDS = { [107579] = true, [107583] = true, [107629] = true, [107630] = true, [107636] = true, [107637] = true,
    [107638] = true, [114990] = true, [114991] = true, [114992] = true, [118617] = true, [118638] = true, [118645] = true }
G.BEAM = { [63029] = true, [63044] = true, [63046] = true }
G.FESTIVAL = { [242982] = "/art/fx/texture/snowball.dds", [84330] = "/esoui/art/icons/quest_mudball.dds",
    [87474] = "/esoui/art/icons/event_jestersfestival_2016_cherry_blossom_branch.dds" }
G.MOUNT, G.DISMOUNT = 36432, 37059
G.MAX_PING = 150
local REASONS = {           -- Metronome's reasonToGCDMapping: text, icon
    Blocked = { "Blocked", "/esoui/art/icons/u42_weaponskill_onehandshield25.dds" },
    Error = { "Error", "/esoui/art/icons/icon_missing.dds" },
    Faded = { "Effect faded", "/esoui/art/icons/servicemappins/servicepin_transmute.dds" },
    Location = { "Invalid location", "/esoui/art/icons/icon_missing.dds" },
    Silenced = { "Silenced", "/esoui/art/icons/ability_debuff_silence.dds" },
    Stagger = { "Stagger", "/esoui/art/icons/ability_debuff_stagger.dds" },
    Dead = { "Target dead", "/esoui/art/targetmarkers/gamepad/target_white_skull.dds" },
    Immune = { "Target immune", "/esoui/art/icons/death_recap_void_dot_heavy.dds" },
}
G.REASONS = REASONS
local GENERIC_ICON = "/esoui/art/icons/ability_mage_065.dds"
local DODGE_ICON = "/esoui/art/icons/ability_rogue_035.dds"
local BREAK_ICON = "/esoui/art/icons/ability_rogue_050.dds"

local watching = false
local o = {}                -- options (the first Global cooldown tracker's trigger): see G.SetWatched
local queued                -- the pressed skill: { id, name, icon, at, delay, kind, enemy, checkDead, expires }
local cur                   -- the running event
local serial = 0
local lastGcdStart, lastEnding = -100, -100
local dodgeUntil, blockWas = -100, false
local pending = {}          -- what names a skill-less GCD: { source, id, name, icon, at }
local synergy               -- { name, icon } while a synergy is offered
local itemCache
local mountName, mountIcon = "", nil
local inCombat = false
local sound = { tick = nil, tickEvent = nil, tocks = {} }

local function Num(v) return tonumber(v) or 0 end
local function Now() return U.Now() end
local function ActiveBar() return type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or 0 end
local function Changed() if DT.Engine and DT.Engine.RequestUpdate then DT.Engine.RequestUpdate() end end
local function Clean(s) return (U.CleanName and U.CleanName(s or "")) or s or "" end
local function Is(result, name) local r = rawget(_G, name); return r ~= nil and result == r end

-- the game's GCD right now: remaining, duration (s); 0, 0 when none
function G.Read()
    if type(GetSlotCooldownInfo) ~= "function" then return 0, 0 end
    local bar = ActiveBar()
    for slot = 3, 8 do
        local remain, duration, global = GetSlotCooldownInfo(slot, bar)
        if global then return Num(remain) / 1000, Num(duration) / 1000 end
    end
    return 0, 0
end

function G.Ping()
    if type(GetLatency) ~= "function" then return 0 end
    return Num(GetLatency())
end

local function AbilityOnSlot(slot, bar)
    local id = GetSlotBoundId(slot, bar)
    if ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotType) == "function" and GetSlotType(slot, bar) == ACTION_TYPE_CRAFTED_ABILITY
        and type(GetAbilityIdForCraftedAbilityId) == "function" then
        id = GetAbilityIdForCraftedAbilityId(id)
    end
    return Num(id)
end

local function Crux()
    if type(GetNumBuffs) ~= "function" then return 0 end
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, stacks, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if abilityId == G.CRUX then return Num(stacks) end
    end
    return 0
end

-- what Metronome's Ability:ForId knows about a skill
local function AbilityInfo(id)
    local channeled, ms = false, 0
    if type(GetAbilityCastInfo) == "function" then
        local c, d = GetAbilityCastInfo(id)
        channeled, ms = c == true, Num(d)
    end
    if G.MEDITATE[id] then ms = 1000 end
    if G.FATECARVER[id] then ms = ms + 338 * Crux() end
    local kind = ms > 0 and (channeled and "channel" or "cast") or "skill"
    local target = type(GetAbilityTargetDescription) == "function" and GetAbilityTargetDescription(id) or ""
    local enemy = type(GetString) == "function" and SI_TARGETTYPE0 and target == GetString(SI_TARGETTYPE0) or false
    local ally = type(GetString) == "function" and SI_TARGETTYPE1 and target == GetString(SI_TARGETTYPE1) or false
    return {
        kind = kind, delay = ms, channeled = channeled, enemy = enemy,
        checkDead = ((enemy or ally) and ms > 1000) or G.MEND_WOUNDS[id] == true,
    }
end

local function Describe(id) return Clean(GetAbilityName(id) or ""), GetAbilityIcon(id) end

local function PerSkill(id)
    for _, a in ipairs(o.perAbility or {}) do if Num(a.id) == id then return Num(a.ms) end end
    return 0
end

------------------------------------------------------------------------------
-- Per-frame check (only while something runs, is queued or is due)
------------------------------------------------------------------------------

local Frame
local frameOn = false
local function WatchFrame()
    local want = watching and (cur ~= nil or queued ~= nil or sound.tick ~= nil or #sound.tocks > 0)
    if want == frameOn then return end
    frameOn = want
    if want then EVENT_MANAGER:RegisterForUpdate(NS .. "_Frame", 0, function() Frame() end)
    else EVENT_MANAGER:UnregisterForUpdate(NS .. "_Frame") end
end
G.WatchFrame = WatchFrame
function G.FrameWatched() return frameOn end

------------------------------------------------------------------------------
-- Metronome sounds
------------------------------------------------------------------------------

local function SoundsAllowed() return inCombat or o.soundOOC end
local function Play(name)
    if not name or name == "" or not SoundsAllowed() then return end
    local v = (SOUNDS and SOUNDS[name]) or name
    for _ = 1, math.max(1, math.min(Num(o.volume), 30)) do PlaySound(v) end
end
G.Play = Play

local function ScheduleSounds(e)
    if not (o.tick or o.tock) then return end
    if e.kind == "heavy" and not o.soundHeavy then return end
    if e.delay > 1000 and not o.soundLong then return end
    if o.tick then
        local len = e.finish - e.start
        if o.tickAt == "end" then sound.tick = e.finish - o.tickBeforeEnd / 1000
        elseif o.tickAt == "mid" then sound.tick = e.start + len / 2 + o.tickOffset / 1000
        else sound.tick = e.start + o.tickOffset / 1000 end
        sound.tickEvent = e.serial
    end
    if o.tock then
        if not o.tockForce then sound.tocks = {} end      -- an older one not yet played: dropped
        sound.tocks[#sound.tocks + 1] = e.start + e.base + o.tockOffset / 1000
    end
end

-- the event ended before its tick: play it now if the GCD hasn't passed the tick's point (Metronome's forced tick)
local function ForcedTick()
    if not sound.tick then return end
    sound.tick, sound.tickEvent = nil, nil
    if not o.tockForce then return end
    local remain, duration = G.Read()
    local ok
    if o.tickAt == "end" then ok = remain >= (o.tickBeforeEnd - o.tickOffset) / 1000
    elseif o.tickAt == "mid" then ok = remain >= (500 - o.tickOffset) / 1000
    else ok = remain >= duration - o.tickOffset / 1000 end
    if ok and remain > 0 then Play(o.tickSound) end
end

local function SoundFrame(now)
    if sound.tick and now >= sound.tick then
        sound.tick, sound.tickEvent = nil, nil
        Play(o.tickSound)
    end
    if #sound.tocks > 0 and now >= sound.tocks[1] then
        -- during the next event (forced): now; with nothing running: once the GCD is over (or a negative offset)
        local remain = G.Read()
        if cur or remain <= 0 or o.tockOffset < 0 then
            table.remove(sound.tocks, 1)
            Play(o.tockSound)
        end
    end
end

------------------------------------------------------------------------------
-- Events: starting, ending
------------------------------------------------------------------------------

local Listen

local function Begin(kind, id, name, icon, start, len, extra)
    extra = extra or {}
    serial = serial + 1
    cur = { kind = kind, id = id, name = name, icon = icon, start = start, finish = start + len, delay = extra.delay or 0,
        serial = serial, source = extra.source, recorded = extra.recorded or start, enemy = extra.enemy, checkDead = extra.checkDead }
    -- Metronome's `ending` (no adjust): when the next skill may take a GCD; the tock's base
    cur.base = kind == "heavy" and cur.delay / 1000 or math.max(cur.delay / 1000, 1)
    cur.ending = start + (kind == "heavy" and cur.delay / 1000 or math.max(cur.delay / 1000, 1, extra.gcdRemain or 0))
    if kind == "heavy" or kind == "cast" or kind == "channel" then cur.castEnd = start + cur.delay / 1000 end
    lastEnding = cur.ending
    Listen(cur)
    if kind ~= "other" and kind ~= "dodge" then ScheduleSounds(cur) end
    WatchFrame()
    Changed()
end

local function Clear()
    cur = nil
    Listen(nil)
    WatchFrame()
    Changed()
end

-- ended early: the rest of the GCD under the reason ("cooldowns without a skill" and a reason Metronome names),
-- else the bar ends
local function Cancel(reasonKey)
    if not cur or cur.cancelled then return end
    local now = Now()
    if sound.tick and sound.tickEvent == cur.serial then ForcedTick() end
    local remain = G.Read()
    local r = REASONS[reasonKey]
    lastEnding = now
    if remain > 0 and o.other and r then
        cur.cancelled, cur.kind, cur.source, cur.id = true, "other", "reason", 0
        cur.name, cur.icon = L(r[1]), r[2]
        cur.finish, cur.ending, cur.castEnd = now + remain, now, nil
        Listen(nil)
        Changed()
    else
        Clear()
    end
end
G.Cancel = Cancel

-- the pressed skill becomes the running event at `start`
local function Fire(q, start, gcdLen, gcdRemain)
    queued = nil
    local kind, delay = q.kind, q.delay
    if (kind == "channel" and not o.channels) or (kind == "cast" and not o.casts) then kind = "skill" end
    local len = gcdLen
    if kind == "channel" then
        local ch = delay / 1000
        if o.channelExtra > 0 and delay > 1000 then ch = ch + o.channelExtra / 1000 end     -- GCD Monitor
        len = math.max(gcdLen, ch)
    elseif kind == "cast" then
        len = math.max(gcdLen, delay / 1000)
    end
    local adjust = PerSkill(q.id) + (q.kind == "skill" and o.adjust or o.castAdjust)
    if kind == "skill" then delay = q.kind == "skill" and 0 or delay end
    Begin(kind, q.id, q.name, q.icon, start, len + adjust / 1000, { delay = (kind == "skill") and 0 or delay, recorded = q.at,
        enemy = q.enemy, checkDead = q.checkDead, gcdRemain = gcdRemain })
end

local function SkillLess(now, start, gcdLen)
    local p = pending
    pending = {}
    if p.at and now - p.at <= 0.6 then
        Begin(p.source == "dodge" and "dodge" or "other", p.id or 0, p.name, p.icon or GENERIC_ICON, start, gcdLen, { source = p.source })
    else
        Begin("other", 0, L("Global cooldown"), GENERIC_ICON, start, gcdLen, {})
    end
end

-- may the pressed skill take a GCD now? (Metronome's CanAbilityFire)
local function CanFire(now)
    if not cur then return now >= lastEnding - 0.001 end
    if cur.kind == "heavy" then return true end
    if cur.kind == "other" and cur.source == nil then return true end     -- an unnamed GCD that is the skill's own
    return now >= cur.ending - 0.001
end

local function TakeOver()       -- what a skill's GCD replaces: a heavy attack, an unnamed GCD
    if cur and (cur.kind == "heavy" or (cur.kind == "other" and cur.source == nil)) then
        if sound.tick and sound.tickEvent == cur.serial then ForcedTick() end
        cur = nil
        Listen(nil)
    end
end

function G.Sync(now)
    if not watching then return end
    now = now or Now()
    local remain, duration = G.Read()
    -- block: drops the pressed skill; ends a cast / channel / heavy still within its delay
    local blocking = type(IsBlockActive) == "function" and IsBlockActive() == true
    if blocking and not blockWas then
        queued = nil
        if cur and not cur.cancelled and cur.castEnd and now < cur.castEnd then Cancel("Blocked") end
    end
    blockWas = blocking
    if queued and now > queued.expires then queued = nil end
    if remain > 0 and duration > 0 then
        local start = now + remain - duration
        if start > lastGcdStart + 0.05 then
            local fresh = remain / duration > 0.9 or now - start <= math.max(0.05, G.Ping() / 1000)
            if queued and now >= dodgeUntil and fresh and CanFire(now) then
                lastGcdStart = start
                TakeOver()
                Fire(queued, start, duration, remain)
            elseif not (queued and now >= dodgeUntil and fresh) then
                -- not the pressed skill's (or none pressed): a skill-less GCD, unless an event still runs
                lastGcdStart = start
                if not cur or cur.kind == "heavy" or now >= cur.ending - 0.001 then
                    if cur and cur.kind == "heavy" then Clear() end
                    if not cur then SkillLess(now, start, duration) end
                end
            end
            -- (else: the pressed skill waits for the running event to reach its end -- "late")
        end
    end
    if cur then
        local short = cur.kind == "skill" or cur.kind == "other" or cur.kind == "dodge" or (cur.kind == "cast" and cur.delay <= 1000)
        if (short and remain <= 0 and now > cur.start + 0.05) or now >= cur.finish then
            lastEnding = math.min(lastEnding, now)
            if sound.tick and sound.tickEvent == cur.serial and now < sound.tick then ForcedTick() end
            Clear()
        end
    end
    WatchFrame()
end

function Frame()
    local now = Now()
    G.Sync(now)
    SoundFrame(now)
    WatchFrame()
end
G.Frame = Frame

-- the running event (nil when nothing runs)
function G.Current(now)
    G.Sync(now)
    return cur
end
function G.InCombat() return inCombat end

------------------------------------------------------------------------------
-- Game events (only while watched)
------------------------------------------------------------------------------

local function OnSlotUsed(_, slot)
    slot = Num(slot)
    if slot < 3 or slot > 8 then return end
    local bar = ActiveBar()
    if type(IsSlotToggled) == "function" and IsSlotToggled(slot, bar) then return end     -- a toggle switched off
    local id = AbilityOnSlot(slot, bar)
    if id == 0 then return end
    local now = Now()
    local info = AbilityInfo(id)
    local name, icon = Describe(id)
    queued = { id = id, name = name, icon = icon, at = now, delay = info.delay, kind = info.kind, enemy = info.enemy,
        checkDead = info.checkDead }
    queued.expires = math.max(lastEnding, now) + math.max(info.delay, 1000) / 1000
    -- "direct": the cooldown update came first this frame (an unnamed GCD that started just now is this skill's)
    local remain, duration = G.Read()
    if remain > 0 and duration > 0 and now >= dodgeUntil and remain >= duration - 0.0005 then
        local start = now + remain - duration
        if cur and cur.kind == "other" and cur.source == nil and math.abs(cur.start - start) < 0.05 then
            TakeOver()
            lastGcdStart = start
            Fire(queued, start, duration, remain)
            return
        end
    end
    G.Sync(now)
end

local function OnCooldowns()
    -- a heavy attack's own slot: released (Metronome: not global and remain == duration)
    if cur and cur.kind == "heavy" and not cur.cancelled and type(GetSlotCooldownInfo) == "function" then
        local remain = G.Read()
        if remain <= 0 then
            local hR, hD, global = GetSlotCooldownInfo(2, ActiveBar())
            if not global and Num(hR) == Num(hD) then Clear() end
        end
    end
    G.Sync(Now())
end

-- your BEGIN / BEGIN_CHANNEL / EFFECT_GAINED / TARGET_DEAD (filtered by result), break free, mount, festival (by id)
local function OnOutgoing(_, result, isError, abilityName, _, slotType, _, sourceType, _, targetType, _, _, _, _, _, targetUnitId, abilityId)
    local now = Now()
    if abilityId == G.ROLL_DODGE and Is(result, "ACTION_RESULT_EFFECT_GAINED") then
        local remain = G.Read()
        dodgeUntil = now + remain
        queued = nil
        if cur and not cur.cancelled and cur.kind ~= "other" and cur.kind ~= "dodge" then Cancel("Dodge") end
        local name = Describe(G.ROLL_DODGE)
        pending = { source = "dodge", id = G.ROLL_DODGE, name = name, icon = DODGE_ICON, at = now }
        -- the dodge's GCD may already have started (its update first): name it now
        if cur and cur.kind == "other" and cur.source == nil and now - cur.start < 0.3 then
            cur.kind, cur.source, cur.id, cur.name, cur.icon = "dodge", "dodge", G.ROLL_DODGE, name, DODGE_ICON
            pending = {}
            Changed()
        end
        G.Sync(now)
        return
    end
    if isError then return end
    -- the pressed skill's target is already dead
    if queued and queued.id == abilityId and queued.enemy and Is(result, "ACTION_RESULT_TARGET_DEAD") then queued = nil; return end
    if abilityId == G.BREAK_FREE then
        pending = { source = "breakfree", id = G.BREAK_FREE, name = Describe(G.BREAK_FREE), icon = BREAK_ICON, at = now }
        return
    end
    if G.FESTIVAL[abilityId] or ((abilityId == G.MOUNT and Is(result, "ACTION_RESULT_EFFECT_GAINED")) or (abilityId == G.DISMOUNT and Is(result, "ACTION_RESULT_BEGIN"))) then
        if inCombat or cur then return end          -- (Metronome: only out of combat, nothing running)
        if G.FESTIVAL[abilityId] then
            pending = { source = "festival", id = abilityId, name = Clean(abilityName), icon = G.FESTIVAL[abilityId], at = now }
        else
            local label = Clean(abilityName)
            if o.mountName and mountName ~= "" then label = string.format("%s (%s)", label, mountName) end
            pending = { source = "mount", name = label, icon = mountIcon or GENERIC_ICON, at = now }
        end
        return
    end
    -- the pressed skill's own BEGIN / EFFECT_GAINED ("CombatEvent" trigger)
    if queued and queued.id == abilityId and (Is(result, "ACTION_RESULT_BEGIN") or Is(result, "ACTION_RESULT_EFFECT_GAINED")) then
        local remain, duration = G.Read()
        if remain > 0 and duration > 0 and now >= dodgeUntil and CanFire(now) then
            local start = now + remain - duration
            lastGcdStart = start
            TakeOver()
            Fire(queued, start, duration, remain)
            return
        end
    end
    if slotType == rawget(_G, "ACTION_SLOT_TYPE_HEAVY_ATTACK") and (Is(result, "ACTION_RESULT_BEGIN") or Is(result, "ACTION_RESULT_BEGIN_CHANNEL")) then
        if abilityId ~= AbilityOnSlot(2, ActiveBar()) then return end
        if cur and cur.kind == "heavy" and cur.id == abilityId and not cur.cancelled then return end
        -- a heavy attack ends a cast / channel in progress
        if cur and not cur.cancelled and cur.castEnd and now < cur.castEnd and cur.kind ~= "heavy" then
            if sound.tick and sound.tickEvent == cur.serial then ForcedTick() end
            Clear()
        end
        if not o.heavy then return end
        local info = AbilityInfo(abilityId)
        if info.delay <= 0 then return end
        local name, icon = Describe(abilityId)
        queued = nil
        Begin("heavy", abilityId, name, icon, now, (info.delay + o.heavyAdjust + PerSkill(abilityId)) / 1000, { delay = info.delay })
    end
end

-- synergies: matched by name while one is offered (only then is this unfiltered listener on)
local function OnSynergyEvent(_, result, isError, abilityName)
    if isError or not synergy then return end
    if Clean(abilityName) == synergy.name then
        pending = { source = "synergy", name = synergy.name, icon = synergy.icon, at = Now() }
    end
end
local synergyOn = false
local function WatchSynergyNames(on)
    if on == synergyOn then return end
    synergyOn = on
    local ns = NS .. "_SynergyUse"
    if on then
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnSynergyEvent)
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    else
        EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
    end
end
local function OnSynergyChanged()
    if type(GetCurrentSynergyInfo) ~= "function" then return end
    local has, name, icon = GetCurrentSynergyInfo()
    if has then synergy = { name = Clean(name), icon = icon } end
    -- (kept a moment after it's gone: the synergy's own event comes as it's used up)
    WatchSynergyNames(has == true or (synergy ~= nil))
    if not has and synergy then
        local s = synergy
        zo_callLater(function() if synergy == s then synergy = nil; WatchSynergyNames(false) end end, 1000)
    end
end

local function OnItemUsed()
    if not (BAG_BACKPACK and type(GetBagSize) == "function") then return end
    itemCache = { names = {}, icons = {} }
    for i = 0, GetBagSize(BAG_BACKPACK) do
        local n = GetItemName(BAG_BACKPACK, i)
        if n and n ~= "" then itemCache.names[i] = Clean(n); itemCache.icons[i] = GetItemInfo(BAG_BACKPACK, i) end
    end
end
local function OnSlotUpdate(_, bagId, slotId, _, _, _, stackCountChange)
    if not itemCache or bagId ~= BAG_BACKPACK or stackCountChange ~= -1 then return end
    if itemCache.names[slotId] then
        pending = { source = "item", name = itemCache.names[slotId], icon = itemCache.icons[slotId], at = Now() }
    end
    itemCache = nil
end

local function OnCollectible(_, id)
    if type(GetCollectibleInfo) ~= "function" then return end
    local name, _, icon, _, _, _, _, cat = GetCollectibleInfo(id)
    if cat == rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_MOUNT") then
        mountName = type(GetCollectibleNickname) == "function" and Clean(GetCollectibleNickname(id)) or ""
        mountIcon = icon
    elseif cat == rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_ASSISTANT") or cat == rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_COMPANION") then
        pending = { source = "collectible", name = Clean(name), icon = icon, at = Now() }
    end
end

local function OnCC(_, result, isError, _, _, _, _, sourceType)
    if isError or sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
    queued = nil
    if cur and not cur.cancelled and cur.castEnd and Now() < cur.castEnd then Cancel("CC") end
end

local function OnBarSwap(_, didChange)
    if didChange == false then return end
    queued = nil
    if cur and not cur.cancelled and (cur.kind == "heavy" or cur.delay > 1000) then Cancel("Barswap") end
end

local function OnWeaponLock(_, locked)
    local now = Now()
    if not locked and cur and not cur.cancelled and cur.kind == "cast" and cur.castEnd and now < cur.castEnd and now > cur.start then
        Cancel("WeaponLock")
    end
end

-- the running ability's own events (Metronome's outgoing / incoming handlers), listened to by its ID
local listenId
local function OnAbilityEvent(_, result, isError, _, _, _, _, sourceType, _, targetType, _, _, _, _, _, targetUnitId, abilityId)
    if not cur or cur.cancelled or abilityId ~= cur.id then return end
    local now = Now()
    if isError then
        if Is(result, "ACTION_RESULT_ABILITY_ON_COOLDOWN") and now - cur.recorded < 0.1 then Cancel("Error") end
        return
    end
    local mine, onMe = sourceType == COMBAT_UNIT_TYPE_PLAYER, targetType == COMBAT_UNIT_TYPE_PLAYER
    if Is(result, "ACTION_RESULT_EFFECT_FADED") then
        if now - cur.start < 0.3 then return end         -- an earlier cast's effect fading as this one starts
        if (mine and cur.castEnd) or (onMe and cur.delay > 1000) then Cancel("Faded") end
        return
    end
    if mine and cur.checkDead and not cur.target then cur.target = targetUnitId end
    if onMe and mine and Is(result, "ACTION_RESULT_SILENCED") then Cancel("Silenced"); return end
    if Is(result, "ACTION_RESULT_NO_LOCATION_FOUND") then Cancel("Location"); return end
    if cur.enemy and mine then
        if Is(result, "ACTION_RESULT_IMMUNE") then Cancel("Immune"); return end
        if Is(result, "ACTION_RESULT_STAGGERED") then Cancel("Stagger"); return end
        if Is(result, "ACTION_RESULT_TARGET_DEAD") then Cancel("Dead"); return end
    end
    if (Is(result, "ACTION_RESULT_DIED") or Is(result, "ACTION_RESULT_DIED_XP")) and cur.checkDead and cur.target == targetUnitId then
        Cancel("Dead")
    end
end
local function OnBeamFaded(_, change, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if change == EFFECT_RESULT_FADED and cur and not cur.cancelled and cur.id == abilityId and Now() - cur.start >= 0.3 then
        Cancel("Faded")
    end
end
function Listen(e)
    local EM = EVENT_MANAGER
    local id = e and not e.cancelled and e.kind ~= "other" and e.kind ~= "dodge" and e.id ~= 0 and e.id or nil
    if id == listenId then return end
    if listenId then
        EM:UnregisterForEvent(NS .. "_Ability", EVENT_COMBAT_EVENT)
        if EVENT_EFFECT_CHANGED then EM:UnregisterForEvent(NS .. "_Beam", EVENT_EFFECT_CHANGED) end
    end
    listenId = id
    if not id then return end
    EM:RegisterForEvent(NS .. "_Ability", EVENT_COMBAT_EVENT, OnAbilityEvent)
    EM:AddFilterForEvent(NS .. "_Ability", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
    if G.BEAM[id] and EVENT_EFFECT_CHANGED then
        EM:RegisterForEvent(NS .. "_Beam", EVENT_EFFECT_CHANGED, OnBeamFaded)
        EM:AddFilterForEvent(NS .. "_Beam", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

local REGS = {}
local function Reg(name, ev, f, ...)
    if not ev then return end
    EVENT_MANAGER:RegisterForEvent(name, ev, f)
    if select("#", ...) > 0 then EVENT_MANAGER:AddFilterForEvent(name, ev, ...) end
    REGS[#REGS + 1] = { name, ev }
end

local CC_RESULTS = { "ACTION_RESULT_KNOCKBACK", "ACTION_RESULT_PACIFIED", "ACTION_RESULT_STAGGERED", "ACTION_RESULT_STUNNED",
    "ACTION_RESULT_INTERRUPT", "ACTION_RESULT_FEARED", "ACTION_RESULT_LEVITATED" }

local function Register()
    Reg(NS .. "_Used", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    Reg(NS .. "_Cooldowns", EVENT_ACTION_UPDATE_COOLDOWNS, OnCooldowns)
    Reg(NS .. "_Swap", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnBarSwap)
    Reg(NS .. "_Lock", rawget(_G, "EVENT_WEAPON_PAIR_LOCK_CHANGED"), OnWeaponLock)
    Reg(NS .. "_Dead", EVENT_PLAYER_DEAD, function() queued = nil; Clear() end)
    Reg(NS .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function(_, c) inCombat = c == true end)
    -- yours, filtered by result (a fight sends hundreds of your events)
    for i, r in ipairs({ "ACTION_RESULT_BEGIN", "ACTION_RESULT_BEGIN_CHANNEL", "ACTION_RESULT_EFFECT_GAINED", "ACTION_RESULT_TARGET_DEAD" }) do
        local v = rawget(_G, r)
        if v then Reg(NS .. "_Out" .. i, EVENT_COMBAT_EVENT, OnOutgoing, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_COMBAT_RESULT, v) end
    end
    for i, name in ipairs(CC_RESULTS) do
        local r = rawget(_G, name)
        if r then Reg(NS .. "_CC" .. i, EVENT_COMBAT_EVENT, OnCC, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_COMBAT_RESULT, r) end
    end
    -- what names a skill-less GCD (only with "cooldowns without a skill")
    if o.other then
        Reg(NS .. "_BreakFree", EVENT_COMBAT_EVENT, OnOutgoing, REGISTER_FILTER_ABILITY_ID, G.BREAK_FREE,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        for id in pairs(G.FESTIVAL) do
            Reg(NS .. "_Festival" .. id, EVENT_COMBAT_EVENT, OnOutgoing, REGISTER_FILTER_ABILITY_ID, id,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
        Reg(NS .. "_Synergy", rawget(_G, "EVENT_SYNERGY_ABILITY_CHANGED"), OnSynergyChanged)
        Reg(NS .. "_Item", rawget(_G, "EVENT_INVENTORY_ITEM_USED"), OnItemUsed)
        Reg(NS .. "_ItemSlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
        Reg(NS .. "_Collectible", rawget(_G, "EVENT_COLLECTIBLE_UPDATED"), OnCollectible)
    end
    inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
    -- the mount you have out (its nickname for "Mounting (Nick)")
    if type(GetActiveCollectibleByType) == "function" and rawget(_G, "COLLECTIBLE_CATEGORY_TYPE_MOUNT") and rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_PLAYER") then
        local id = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if id and id ~= 0 then
            mountName = type(GetCollectibleNickname) == "function" and Clean(GetCollectibleNickname(id)) or ""
            mountIcon = type(GetCollectibleIcon) == "function" and GetCollectibleIcon(id) or nil
        end
    end
end

local function Unregister()
    for _, r in ipairs(REGS) do EVENT_MANAGER:UnregisterForEvent(r[1], r[2]) end
    REGS = {}
    WatchSynergyNames(false)
    Listen(nil)
end

-- t = nil (no Global cooldown tracker) or the first one's trigger (Core/Schema.lua gcd* fields)
function G.SetWatched(t)
    local on = t ~= nil
    local before = o.other
    if t then
        o = {
            heavy = t.gcdHeavy ~= false, casts = t.gcdCasts ~= false, channels = t.gcdChannels ~= false,
            adjust = Num(t.gcdAdjust), castAdjust = Num(t.gcdCastAdjust), heavyAdjust = Num(t.gcdHeavyAdjust),
            channelExtra = Num(t.gcdChannelExtra), perAbility = t.gcdAbilityAdjust or {}, other = t.gcdOther ~= false,
            mountName = t.gcdMountName == true,
            tick = t.gcdTick == true, tickSound = t.gcdTickSound, tickAt = t.gcdTickAt or "start", tickOffset = Num(t.gcdTickOffset),
            tickBeforeEnd = Num(t.gcdTickBeforeEnd), tock = t.gcdTock == true, tockSound = t.gcdTockSound,
            tockOffset = Num(t.gcdTockOffset), tockForce = t.gcdTockForce ~= false, soundHeavy = t.gcdSoundHeavy ~= false,
            soundLong = t.gcdSoundLong ~= false, soundOOC = t.gcdSoundOOC == true, volume = Num(t.gcdVolume),
        }
    end
    if on == watching and not (on and before ~= o.other) then return end
    if watching then Unregister() end
    watching = on
    queued, cur, lastGcdStart, lastEnding, pending = nil, nil, -100, -100, {}
    sound.tick, sound.tickEvent, sound.tocks = nil, nil, {}
    if on then Register() end
    WatchFrame()
end

function G.IsWatched() return watching end

-- A skill's cast / channel length in ms (0 = instant), as the bar above uses it (Meditate, Fatecarver's Crux included):
-- the weaving tracker (Core/Weave.lua) counts a skill's end from it.
function G.CastMs(id)
    return AbilityInfo(id).delay
end

-- The ability on an action bar slot (scribed skills: their real ability), as above.
function G.SlotAbility(slot, bar)
    return AbilityOnSlot(slot, bar or ActiveBar())
end
