PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The fight recorder
--
-- WHEN A FIGHT IS
--   It starts with the first damage the player or a pet deals to anything but the player, or with
--   the first heal while the player is in combat. It ends when the player has been out of combat
--   for `endSec` seconds after the last event, or when nothing has happened for `idleSec` seconds
--   (in PvP the game can keep a player "in combat" for a long time), or at a loading screen.
--   Its length is the ACTIVE time, first event to last event, as other meters count it; a fight
--   shorter than `minSecs` is not kept.
--
-- WHAT IS COUNTED
--   damage   EVENT_COMBAT_EVENT, source the player or a pet: direct hits, crits, damage over time
--            ticks, damage that hit a block or a shield. Per ability (total, hits, crits, biggest)
--            and per target.
--   healing  the same events' heal results. hitValue is taken as the heal that landed and overflow
--            as the overheal (unmeasured on console; /pbbs debug shows the raw numbers).
--   casts    EVENT_ACTION_SLOT_ABILITY_USED for slots 3..8 (the skills and the ultimate), with the
--            ability bound there at the moment; light and heavy attacks from the hits' slot type.
--   buffs    EVENT_EFFECT_CHANGED on the player: every TIMED buff (it has an end, of at most
--            MAX_EFFECT_SECONDS: food, mundus and passives would be 100% and are left out), whoever
--            cast it. A buff the player already had when the fight began is read with
--            GetUnitBuffInfo then.
--   debuffs  EVENT_EFFECT_CHANGED for effects the player applied to others: the time ANY enemy
--            carried it. Whether the console sends these for enemies with no unit tag is
--            unmeasured (/pbbs status counts them).
--   procs    a buff, debuff or hit whose name is the name of a set the player wears, or holds it,
--            is marked as the set's (the first tier of PB's Proc Set Timer's matching).
--
-- UPTIME
--   Per effect the time at least one unit carried it, clipped to the fight. An effect whose fade
--   event never comes ends at its own end time (checked every tick).
---------------------------------------------------------------------------------------------------

local fights = {
    live = nil, -- the fight going on
    lastClosed = nil, -- the record of the last fight that ended (kept or not), and when
    closedAt = 0,
    inCombat = false,
    preCasts = {}, -- presses just before a fight starts (the opener is pressed before it lands)
    setNames = nil, -- names of the worn sets, nil when they must be read again
}
ADDON.fights = fights

local MAX_HISTORY = 10
fights.MAX_HISTORY = MAX_HISTORY
local MAX_EFFECT_SECONDS = 180
local PRECAST_SECONDS = 2
local FRESH_SECONDS = 0.75
local CAP_ABILITIES = 40
local CAP_TARGETS = 12
local CAP_EFFECTS = 60
local CAP_CASTS = 24
local MIN_SET_NAME_BYTES = 4

local Plain = ADDON.Plain

local function Now()
    return GetFrameTimeSeconds()
end
fights.Now = Now

local counters = { dmg = 0, heal = 0, fxSelf = 0, fxOut = 0, fxTracked = 0, casts = 0, opened = 0, kept = 0, dropped = 0 }
fights.counters = counters

---------------------------------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------------------------------

-- result -> { crit, tick }. Built on first use: the constants exist by then in the game and the tests.
local DAMAGE, HEAL
local function Results()
    if DAMAGE then
        return
    end
    DAMAGE, HEAL = {}, {}
    local function add(list, name, crit, tick, shield)
        local value = _G["ACTION_RESULT_" .. name]
        if value then
            list[value] = { crit = crit, tick = tick, shield = shield }
        end
    end
    add(DAMAGE, "DAMAGE", false, false)
    add(DAMAGE, "CRITICAL_DAMAGE", true, false)
    add(DAMAGE, "DOT_TICK", false, true)
    add(DAMAGE, "DOT_TICK_CRITICAL", true, true)
    add(DAMAGE, "BLOCKED_DAMAGE", false, false)
    -- a damage shield took it: damage done, but it never reached the target's health (Boss.lua)
    add(DAMAGE, "DAMAGE_SHIELDED", false, false, true)
    add(DAMAGE, "PRECISE_DAMAGE", false, false)
    add(DAMAGE, "WRECKING_DAMAGE", false, false)
    add(HEAL, "HEAL", false, false)
    add(HEAL, "CRITICAL_HEAL", true, false)
    add(HEAL, "HOT_TICK", false, true)
    add(HEAL, "HOT_TICK_CRITICAL", true, true)
end

function fights.DamageResult(result)
    Results()
    return DAMAGE[result]
end

function fights.HealResult(result)
    Results()
    return HEAL[result]
end

---------------------------------------------------------------------------------------------------
-- Worn sets
---------------------------------------------------------------------------------------------------

function fights:WornSetsChanged()
    self.setNames = nil
end

function fights:ReadWornSets()
    local names = {}
    if type(GetBagSize) == "function" and type(GetItemLinkSetInfo) == "function" then
        for slot = 0, GetBagSize(BAG_WORN) - 1 do
            local link = GetItemLink(BAG_WORN, slot)
            if link and link ~= "" then
                local hasSet, setName = GetItemLinkSetInfo(link, true)
                local plain = hasSet and Plain(setName) or ""
                if #plain >= MIN_SET_NAME_BYTES then
                    names[plain] = true
                end
            end
        end
    end
    self.setNames = names
    return names
end

-- Whether a name is a worn set's: the same, or one holds the other. Byte-exact (find with plain).
local function IsSetName(fight, name)
    local verdict = fight.setVerdict[name]
    if verdict ~= nil then
        return verdict
    end
    verdict = false
    if #name >= MIN_SET_NAME_BYTES then
        for setName in pairs(fight.setNames) do
            if name == setName or name:find(setName, 1, true) or setName:find(name, 1, true) then
                verdict = true
                break
            end
        end
    end
    fight.setVerdict[name] = verdict
    return verdict
end

---------------------------------------------------------------------------------------------------
-- Effects and their uptime
---------------------------------------------------------------------------------------------------

-- kind: "own" (a buff the player cast on themself), "ext" (a buff from someone else),
-- "debuff" (a debuff the player put on others).
local function Effect(fight, key, abilityId, name, kind)
    local fx = fight.fx[key]
    if not fx then
        name = Plain(name)
        if name == "" then
            name = ADDON.AbilityName(abilityId)
        end
        fx = {
            id = abilityId, name = name, kind = kind, set = IsSetName(fight, name),
            units = {}, count = 0, since = nil, endAt = 0, up = 0, lastClose = 0, lastLen = 0,
            gains = 0, stacks = 0,
        }
        fight.fx[key] = fx
        counters.fxTracked = counters.fxTracked + 1
    elseif kind == "own" and fx.kind == "ext" then
        fx.kind = "own"
    end
    return fx
end

local function OpenUnit(fight, fx, unit, finish, t)
    if not fx.units[unit] then
        fx.count = fx.count + 1
    end
    fx.units[unit] = finish
    if not fx.since then
        fx.since = math.max(t, fight.startT)
        fx.endAt = 0
    end
end

-- Takes a unit off an effect at time t. The effect's interval ends when the last unit goes, at the
-- latest time any of them went.
local function CloseUnit(fx, unit, t)
    if not fx.units[unit] then
        return
    end
    fx.units[unit] = nil
    fx.count = fx.count - 1
    if t > fx.endAt then
        fx.endAt = t
    end
    if fx.count <= 0 then
        fx.count = 0
        if fx.since then
            local length = math.max(0, fx.endAt - fx.since)
            fx.up = fx.up + length
            fx.lastClose = fx.endAt
            fx.lastLen = length
            fx.since = nil
        end
    end
end

fights._CloseUnit = CloseUnit -- for the tests

local function Timed(beginTime, endTime)
    return beginTime and endTime and endTime > beginTime and endTime - beginTime <= MAX_EFFECT_SECONDS
end

-- unitKey: "p" for the player, else the unit id. kind as in Effect.
function fights:EffectChanged(changeType, effectName, beginTime, endTime, stackCount, abilityId, unitKey, kind)
    local fight = self.live
    if not fight then
        return
    end
    local now = Now()
    local key = (kind == "debuff" and "d" or "b") .. tostring(abilityId)
    if changeType == EFFECT_RESULT_FADED then
        local fx = fight.fx[key]
        if fx then
            CloseUnit(fx, unitKey, now)
        end
        return
    end
    if not Timed(beginTime, endTime) then
        return
    end
    local fx = Effect(fight, key, abilityId, effectName, kind)
    local had = fx.units[unitKey] ~= nil
    if changeType == EFFECT_RESULT_GAINED or not had or (beginTime > 0 and now - beginTime <= FRESH_SECONDS) then
        fx.gains = fx.gains + 1
    end
    if (stackCount or 0) > fx.stacks then
        fx.stacks = stackCount
    end
    OpenUnit(fight, fx, unitKey, endTime, now)
end

-- The buffs the player already has when a fight starts.
local function SeedPlayerBuffs(fight, now)
    if type(GetNumBuffs) ~= "function" then
        return
    end
    for index = 1, GetNumBuffs("player") do
        local name, started, ending, _, stacks, _, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", index)
        if effectType == BUFF_EFFECT_TYPE_BUFF and Timed(started, ending) and ending > now and abilityId then
            local fx = Effect(fight, "b" .. tostring(abilityId), abilityId, name, castByPlayer and "own" or "ext")
            -- applied before the fight: one application
            fx.gains = 1
            if (stacks or 0) > fx.stacks then
                fx.stacks = stacks
            end
            OpenUnit(fight, fx, "p", ending, now)
        end
    end
end

-- Effects whose fade never came end at their own end time.
local function ExpireEffects(fight, now)
    for _, fx in pairs(fight.fx) do
        if fx.count > 0 then
            for unit, finish in pairs(fx.units) do
                if finish < now then
                    CloseUnit(fx, unit, finish)
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Opening, closing
---------------------------------------------------------------------------------------------------

function fights:Open(now)
    local fight = {
        startT = now, lastT = now,
        stamp = type(GetTimeStamp) == "function" and GetTimeStamp() or 0,
        clock = type(GetSecondsSinceMidnight) == "function" and GetSecondsSinceMidnight() or 0,
        zone = type(GetPlayerActiveZoneName) == "function" and Plain(GetPlayerActiveZoneName() or "") or "",
        dmg = 0, dmgHits = 0, dmgCrits = 0,
        heal = 0, over = 0, healHits = 0, healCrits = 0,
        la = 0, ha = 0, castN = 0,
        dmgAb = {}, healAb = {}, dmgTgt = {}, healTgt = {}, casts = {}, fx = {},
        setNames = self.setNames or self:ReadWornSets(),
        setVerdict = {},
        -- what other members sent during this fight (Group.lua), by display name
        group = {},
        -- bosses by unit tag and every boss seen (Boss.lua); damage that reached health, by target
        bosses = {}, bossEntries = {}, hpDmg = {},
        serial = (self.serial or 0) % 256 + 1,
    }
    self.serial = fight.serial
    self.live = fight
    counters.opened = counters.opened + 1
    SeedPlayerBuffs(fight, now)
    if ADDON.bosses then
        ADDON.bosses:Scan(fight)
    end
    -- The opener was pressed before its hit landed.
    for _, press in ipairs(self.preCasts) do
        if now - press.t <= PRECAST_SECONDS then
            self:AddCast(fight, press.id)
        end
    end
    self.preCasts = {}
    if ADDON.OnFightOpened then
        ADDON.OnFightOpened(fight)
    end
    return fight
end

function fights:Close(now)
    local fight = self.live
    if not fight then
        return nil
    end
    self.live = nil
    local record = self:Fold(fight)
    self.lastClosed = record
    self.closedAt = now or Now()
    local sv = ADDON.sv
    if record.secs >= (sv and sv.minSecs or 0) and (record.dmg > 0 or record.heal > 0) then
        local history = ADDON.history
        table.insert(history, 1, record)
        while #history > MAX_HISTORY do
            table.remove(history)
        end
        counters.kept = counters.kept + 1
        record.kept = true
    else
        counters.dropped = counters.dropped + 1
    end
    if ADDON.OnFightClosed then
        ADDON.OnFightClosed(record)
    end
    return record
end

function fights:Tick(now)
    local fight = self.live
    if not fight then
        return
    end
    ExpireEffects(fight, now)
    local sv = ADDON.sv
    local idle = now - fight.lastT
    if (not self.inCombat and idle >= sv.endSec) or idle >= sv.idleSec then
        self:Close(now)
    elseif ADDON.group then
        ADDON.group:OnFightTick(fight, now)
    end
end

function fights:SetCombat(inCombat)
    self.inCombat = inCombat and true or false
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------

-- Target names arrive with the client's suffix ("Name^Mx") on every event; the cut copy is kept so
-- an event costs a table lookup and not a new string. Emptied when it grows past TARGET_CACHE.
local TARGET_CACHE = 200
local targetNames, targetCount = {}, 0
local function TargetName(raw)
    local name = targetNames[raw or ""]
    if not name then
        if targetCount >= TARGET_CACHE then
            targetNames, targetCount = {}, 0
        end
        name = Plain(raw)
        targetNames[raw or ""] = name
        targetCount = targetCount + 1
    end
    return name
end

local function Ability(list, fight, abilityId, name)
    local entry = list[abilityId]
    if not entry then
        name = Plain(name)
        if name == "" then
            name = ADDON.AbilityName(abilityId)
        end
        entry = { id = abilityId, name = name, total = 0, over = 0, hits = 0, crits = 0, ticks = 0, max = 0 }
        entry.set = IsSetName(fight, name)
        list[abilityId] = entry
    end
    return entry
end

function fights:Damage(abilityId, name, hit, kind, targetName, fromPet, slotType)
    counters.dmg = counters.dmg + 1
    local now = Now()
    local fight = self.live or self:Open(now)
    fight.lastT = now
    fight.dmg = fight.dmg + hit
    fight.dmgHits = fight.dmgHits + 1
    local entry = Ability(fight.dmgAb, fight, abilityId, name)
    entry.total = entry.total + hit
    entry.hits = entry.hits + 1
    if kind.crit then
        entry.crits = entry.crits + 1
        fight.dmgCrits = fight.dmgCrits + 1
    end
    if kind.tick then
        entry.ticks = entry.ticks + 1
    end
    if hit > entry.max then
        entry.max = hit
    end
    if fromPet then
        entry.pet = true
    end
    local target = TargetName(targetName)
    fight.dmgTgt[target] = (fight.dmgTgt[target] or 0) + hit
    if not kind.shield then
        fight.hpDmg[target] = (fight.hpDmg[target] or 0) + hit
    end
    if not fromPet then
        if slotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
            fight.la = fight.la + 1
        elseif slotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
            fight.ha = fight.ha + 1
        end
    end
end

-- targetKind: "self", "group" or "other".
function fights:Heal(abilityId, name, hit, over, kind, targetName, targetKind, fromPet)
    counters.heal = counters.heal + 1
    local now = Now()
    local fight = self.live
    if not fight then
        -- A heal-over-time ticking after the fight is not a fight.
        if not self.inCombat or hit <= 0 then
            return
        end
        fight = self:Open(now)
    end
    -- Only a heal in combat keeps the fight going; out of combat it is counted but does not stretch it.
    if self.inCombat then
        fight.lastT = now
    end
    fight.heal = fight.heal + hit
    fight.over = fight.over + over
    fight.healHits = fight.healHits + 1
    local entry = Ability(fight.healAb, fight, abilityId, name)
    entry.total = entry.total + hit
    entry.over = entry.over + over
    entry.hits = entry.hits + 1
    if kind.crit then
        entry.crits = entry.crits + 1
        fight.healCrits = fight.healCrits + 1
    end
    if kind.tick then
        entry.ticks = entry.ticks + 1
    end
    if hit > entry.max then
        entry.max = hit
    end
    if fromPet then
        entry.pet = true
    end
    local target = TargetName(targetName)
    local row = fight.healTgt[target]
    if not row then
        row = { total = 0, over = 0, kind = targetKind }
        fight.healTgt[target] = row
    end
    row.total = row.total + hit
    row.over = row.over + over
end

function fights:AddCast(fight, abilityId)
    fight.casts[abilityId] = (fight.casts[abilityId] or 0) + 1
    fight.castN = fight.castN + 1
end

-- A skill or the ultimate was pressed (slots 3..8). The ability is what is bound there now, on the
-- bar in hand; a scribed skill is bound as its crafted id.
function fights:SlotUsed(slotIndex)
    if slotIndex < 3 or slotIndex > 8 then
        return
    end
    local hotbar = type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or nil
    local abilityId = GetSlotBoundId(slotIndex, hotbar)
    if not abilityId or abilityId == 0 then
        return
    end
    if ACTION_TYPE_CRAFTED_ABILITY and type(GetSlotType) == "function" and GetSlotType(slotIndex, hotbar) == ACTION_TYPE_CRAFTED_ABILITY
        and type(GetAbilityIdForCraftedAbilityId) == "function" then
        abilityId = GetAbilityIdForCraftedAbilityId(abilityId)
    end
    counters.casts = counters.casts + 1
    if self.live then
        self:AddCast(self.live, abilityId)
    else
        local list = self.preCasts
        list[#list + 1] = { t = Now(), id = abilityId }
        if #list > 4 then
            table.remove(list, 1)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Folding a fight into a record
---------------------------------------------------------------------------------------------------

local function ByTotal(a, b)
    if a.total ~= b.total then
        return a.total > b.total
    end
    return a.name < b.name
end

local function Capped(list, cap)
    while #list > cap do
        table.remove(list)
    end
    return list
end

local KIND_ORDER = { own = 1, ext = 2, debuff = 3 }

-- The record of a fight: plain sorted lists, small enough to keep ten of. endT defaults to the last
-- event (a live fight is folded the same way for the screen).
function fights:Fold(fight, endT)
    endT = endT or fight.lastT
    local secs = math.max(1, endT - fight.startT)
    local record = {
        stamp = fight.stamp, clock = fight.clock, zone = fight.zone, secs = secs,
        dmg = fight.dmg, dmgHits = fight.dmgHits, dmgCrits = fight.dmgCrits,
        heal = fight.heal, over = fight.over, healHits = fight.healHits, healCrits = fight.healCrits,
        la = fight.la, ha = fight.ha, castN = fight.castN, serial = fight.serial,
    }

    local list = {}
    for _, entry in pairs(fight.dmgAb) do
        list[#list + 1] = { id = entry.id, name = entry.name, total = entry.total, hits = entry.hits, crits = entry.crits,
            ticks = entry.ticks, max = entry.max, pet = entry.pet, set = entry.set }
    end
    table.sort(list, ByTotal)
    record.dmgAb = Capped(list, CAP_ABILITIES)

    list = {}
    for _, entry in pairs(fight.healAb) do
        list[#list + 1] = { id = entry.id, name = entry.name, total = entry.total, over = entry.over, hits = entry.hits,
            crits = entry.crits, ticks = entry.ticks, max = entry.max, pet = entry.pet, set = entry.set }
    end
    table.sort(list, ByTotal)
    record.healAb = Capped(list, CAP_ABILITIES)

    list = {}
    for name, total in pairs(fight.dmgTgt) do
        list[#list + 1] = { name = name, total = total }
    end
    table.sort(list, ByTotal)
    record.dmgTgt = Capped(list, CAP_TARGETS)
    record.target = list[1] and list[1].name or ""

    list = {}
    for name, row in pairs(fight.healTgt) do
        list[#list + 1] = { name = name, total = row.total, over = row.over, kind = row.kind }
    end
    table.sort(list, ByTotal)
    record.healTgt = Capped(list, CAP_TARGETS)
    if record.target == "" and list[1] then
        record.target = list[1].name
    end

    list = {}
    for abilityId, count in pairs(fight.casts) do
        list[#list + 1] = { id = abilityId, name = ADDON.AbilityName(abilityId), total = count }
    end
    table.sort(list, ByTotal)
    record.casts = Capped(list, CAP_CASTS)

    list = {}
    for _, fx in pairs(fight.fx) do
        local up = fx.up
        if fx.since then
            up = up + math.max(0, endT - fx.since)
        elseif fx.lastClose > endT then
            -- the last interval ran past the fight's end
            up = up - math.min(fx.lastLen, fx.lastClose - endT)
        end
        up = math.max(0, math.min(secs, up))
        if up > 0 then
            list[#list + 1] = { id = fx.id, name = fx.name, kind = fx.kind, set = fx.set or nil,
                up = up, gains = fx.gains, stacks = fx.stacks > 1 and fx.stacks or nil }
        end
    end
    -- Set procs first, then the player's own buffs, buffs from others, debuffs; longest first in each.
    table.sort(list, function(a, b)
        local ka = a.set and 0 or KIND_ORDER[a.kind] or 9
        local kb = b.set and 0 or KIND_ORDER[b.kind] or 9
        if ka ~= kb then
            return ka < kb
        end
        if a.up ~= b.up then
            return a.up > b.up
        end
        return a.name < b.name
    end)
    record.fx = Capped(list, CAP_EFFECTS)
    -- the group's readings and the player's share of them; the share of the bosses' health
    if ADDON.group then
        ADDON.group.FoldInto(fight, record)
    end
    if ADDON.bosses then
        ADDON.bosses.FoldInto(fight, record)
    end
    -- character -> PSN-ID for the players in it
    if ADDON.names then
        ADDON.names.FoldInto(record)
    end
    return record
end

-- The live fight as a record, for the screen; nil when there is none.
function fights:Snapshot()
    if not self.live then
        return nil
    end
    local record = self:Fold(self.live)
    record.live = true
    return record
end

-- What the HUD shows: dps, hps, secs, ended, boss share (nil without a boss) for the fight going on
-- or the last one, while it is held; nil when there is nothing to show.
function fights:HudNumbers(now, holdSec)
    local fight = self.live
    if fight then
        local secs = math.max(1, fight.lastT - fight.startT)
        return fight.dmg / secs, fight.heal / secs, secs, false, ADDON.bosses and ADDON.bosses.Share(fight)
    end
    local last = self.lastClosed
    if last and now - self.closedAt <= holdSec then
        return last.dmg / last.secs, last.heal / last.secs, last.secs, true, last.bossShare
    end
    return nil
end

function fights:Reset()
    self.live = nil
    self.lastClosed = nil
    self.closedAt = 0
    self.preCasts = {}
end
