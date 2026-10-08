-- =============================================================================
-- Under Pressure -- PlagueTracker.lua (0.4.0)
-- =============================================================================
-- Tracks whether the local player is carrying a Plaguebreak plague, and when
-- that plague is REMOVED EARLY (cleansed), assembles a report of who removed
-- it, what they removed it with, and every explosion hit this client saw.
--
-- THE SET, as it reads at API 101051 (UESP skill data, 2026-10-06):
--   "Dealing direct damage causes player enemies to become a Plague Carrier,
--    dealing 1000 Disease Damage over 10 seconds and applying the Diseased
--    status effect. If the plague is removed early it explodes and deals 735
--    Disease Damage to all enemies within 8 meters of the carrier, increasing
--    by 50% per enemy hit. Once every 20 seconds per target."
--
-- ABILITY IDS (from the set passive's tooltip references in UESP's data):
--   159603  Plaguebreak        the set passive on the WEARER (never on us)
--   159612  Plague Carrier     the debuff / DoT on the VICTIM -- what we track
--   159623  Plaguebreak        the explosion, one AoE hit per enemy in 8 m
--   159666  (50% per enemy)    the stacking amplifier, 200 ms, internal
--   177058  (20 s cooldown)    per-target cooldown marker, internal
-- IDs drift across patches, so every ID test has a NAME fallback, and Init()
-- checks at runtime that 159612 still resolves to a name containing "plague"
-- (see UP.Plague.VerifyIds, reported by the API audit button under Settings >
-- Debug).
--
-- WHAT "REMOVED EARLY" MEANS HERE. EVENT_EFFECT_CHANGED gives us FADED with
-- no reason attached. We call it early when the FADED arrives with more than
-- EARLY_FADE_MS of the debuff's own endTime still to run, and the player is not
-- dead (death also drops the debuff, without an explosion). The explosion
-- damage itself is the confirming signal and is collected either way.
--
-- WHO REMOVED IT -- KNOWN CLEANSES ONLY, NEVER A GUESS. ESOUIDocumentation.txt
-- at 101051 lists no effect-applied / effect-removed combat result, and ZOS's
-- own Lua never references one -- but the documentation is incomplete here:
-- ACTION_RESULT_EFFECT_GAINED (2240), ACTION_RESULT_EFFECT_GAINED_DURATION
-- (2245) and ACTION_RESULT_EFFECT_FADED (2250) are live globals that LibCombat
-- 89 uses bare, and its source quotes a real event in that shape:
--   "R: 2245, Overcharged (178118) ... Solinur^Mx (31967, 1) -> The Precursor"
-- i.e. WHO applied WHAT to WHOM. Same situation as ACTION_RESULT_BEGIN, which
-- EasyMark relies on (see Docs/EasyMark-ConsoleResearch.md). Their presence on
-- console is unverified, so every use below is type()-guarded and the API audit
-- reports whether they exist (UP.Plague.EffectResultsAvailable).
--
-- What that gives us, all already delivered by the target=player registration:
--   * our own ability presses (EVENT_ACTION_SLOT_ABILITY_USED -> slot -> name),
--     ability slots 3..8 only -- the light/heavy attack slots are dropped at
--     the source, see EventIngest.onActionSlotUsed
--   * effects APPLIED to us by anyone, with the applier's name, IF the
--     undocumented results exist and the cleanse applies an effect to its
--     targets when it fires (an ally's Purge may; whether it does is what the
--     field will tell us -- see UP.Debug.LogPlagueEvidence)
--   * friendly combat events that land on us (HEAL / HOT_TICK / POWER_ENERGIZE)
--     with the caster's name: Cleanse heals per effect removed, Purify heals
--     its activator, Renewing Undeath heals the area it cleanses, Curse Eater
--     returns magicka to the target it cleansed
--   * buffs gained on us (EVENT_EFFECT_CHANGED, effectType BUFF), source TYPE
--     only
-- Attribute() names a remover ONLY when one of those matches a cleanse in
-- UP.Plague.CLEANSES by display name, AND the evidence kind is one that
-- cleanse can actually produce (an ally's Extended Ritual ticking on you, or
-- its HoT effect being applied to you, is not evidence they cleansed you -- the
-- Ritual cleanses its caster; you would have had to press Purify, which heals
-- you under its own name). Anything else, including an ability you pressed at
-- the same instant, is not mentioned: the first field report (2026-10-07)
-- blamed a heavy attack, which cannot cleanse, and a wrong name is worse than
-- "unknown".
--
-- READOUT ONLY. Nothing here feeds the pressure model. The plague debuff
-- reaches the engine through the normal classifier path (DISEASE status ->
-- DOT risk, and 159612 is in the classifier's ID table) exactly like any other
-- debuff; this module adds the tint and the report and nothing else.
-- =============================================================================

UP = UP or {}
UP.Plague = {}

local EFFECT_FADED  = (type(EFFECT_RESULT_FADED)  == "number") and EFFECT_RESULT_FADED  or 2
local UNIT_PLAYER   = (type(COMBAT_UNIT_TYPE_PLAYER) == "number") and COMBAT_UNIT_TYPE_PLAYER or 1
local UNIT_GROUP    = (type(COMBAT_UNIT_TYPE_GROUP)  == "number") and COMBAT_UNIT_TYPE_GROUP  or nil
local BUFF_TYPE     = (type(BUFF_EFFECT_TYPE_BUFF)   == "number") and BUFF_EFFECT_TYPE_BUFF   or 1

-- Tunables. Plain locals rather than UP.Defaults entries: none of these is a
-- model parameter a user would tune, and keeping them here keeps the
-- settings panel out of it.
local EARLY_FADE_MS   = 750    -- FADED this far before endTime counts as removed early
local REPORT_DELAY_MS = 1200   -- how long after fade/first hit to wait for the rest of the hits
local ATTRIB_WINDOW_MS = 1500  -- how far back to look for the cleanse
local RECENT_MAX      = 16     -- friendly-event ring size while a plague is active

-- ---------------------------------------------------------------------------
-- Identification
-- ---------------------------------------------------------------------------
UP.Plague.PLAGUE_ABILITY_IDS    = { [159612] = true }
UP.Plague.EXPLOSION_ABILITY_IDS = { [159623] = true }
UP.Plague.SET_PASSIVE_ID        = 159603

local PLAGUE_NAMES    = { ["plague carrier"] = true }
local EXPLOSION_NAMES = { ["plaguebreak"] = true }

-- Known cleanses, lower-cased display names, from UESP skill data 2026-10-06.
-- Each entry says which EVIDENCE KINDS can legitimately name it:
--   cast    = you pressed it (EVENT_ACTION_SLOT_ABILITY_USED) and it cleanses you
--   applied = an effect under this name being APPLIED to you by its caster
--             (ACTION_RESULT_EFFECT_GAINED / _GAINED_DURATION, undocumented but
--             live per LibCombat) is the cleanse reaching you; names the caster
--   heal    = a heal / HoT tick / resource return under this name landing on
--             you IS the cleanse reaching you (so an ally's can be named)
--   buff    = an effect GAINED on you under this name (EVENT_EFFECT_CHANGED,
--             source type only) is the cleanse firing
-- Whether an ally's Purge produces an `applied` event depends on whether the
-- ability applies an effect to its targets when it fires; the flag says only
-- that IF such an event arrives under that name, it is a cleanse of you.
UP.Plague.CLEANSES = {
    -- Alliance War > Support. Your own press cleanses you. The Cleanse morph
    -- also heals every target it cleansed, so an ally's Cleanse shows up as a
    -- heal under that name. An ally's Purge / Efficient Purge can only show up
    -- as an effect applied to you, if the undocumented results carry it.
    ["purge"]                 = { cast = true,  applied = true,  heal = false, buff = true },
    ["efficient purge"]       = { cast = true,  applied = true,  heal = false, buff = true },
    ["cleanse"]               = { cast = true,  applied = true,  heal = true,  buff = true },
    -- Templar Restoring Light. The Ritual cleanses its CASTER; allies cleanse
    -- themselves through the Purify synergy, which heals the activator under
    -- its own name. So the Ritual morphs count only as your own press; an
    -- ally's Ritual HoT ticking on you, or being applied to you, is explicitly
    -- not evidence.
    ["cleansing ritual"]      = { cast = true,  applied = false, heal = false, buff = false },
    ["extended ritual"]       = { cast = true,  applied = false, heal = false, buff = false },
    ["ritual of retribution"] = { cast = true,  applied = false, heal = false, buff = false },
    ["purify"]                = { cast = false, applied = true,  heal = true,  buff = true },
    -- Necromancer Living Death. Expunge morphs are self-only; Expunge and
    -- Modify also returns resources to you under its own name. Renewing
    -- Undeath heals the area it cleanses, so an ally's can be named.
    ["expunge"]               = { cast = true,  applied = true,  heal = false, buff = true },
    ["expunge and modify"]    = { cast = true,  applied = true,  heal = true,  buff = true },
    ["hexproof"]              = { cast = true,  applied = true,  heal = false, buff = true },
    ["renewing undeath"]      = { cast = true,  applied = true,  heal = true,  buff = true },
    -- Warden netch: removes one negative effect every 5 s while active. Only
    -- the cast is visible, so this can only be named if the cast itself fell
    -- inside the window -- weak, but it is a real cleanse and not a guess. The
    -- netch buff being applied at cast time is not the cleanse moment.
    ["betty netch"]           = { cast = true,  applied = false, heal = false, buff = false },
    ["blue betty"]            = { cast = true,  applied = false, heal = false, buff = false },
    ["bull netch"]            = { cast = true,  applied = false, heal = false, buff = false },
    -- Sets. Curse Eater returns magicka to the target it cleansed and Mara's
    -- Balm heals its wearer, both under the set's name. Stendarr's Embrace and
    -- Wyrd Tree's Blessing produce no heal or resource event of their own --
    -- the heal that triggers Stendarr's is an ordinary heal under the HEALER'S
    -- ability name -- so only their per-target cooldown effect, applied to you
    -- under the set's name by the wearer, could ever name them.
    ["curse eater"]           = { cast = false, applied = true,  heal = true,  buff = true },
    ["mara's balm"]           = { cast = false, applied = true,  heal = true,  buff = true },
    ["stendarr's embrace"]    = { cast = false, applied = true,  heal = false, buff = true },
    ["wyrd tree's blessing"]  = { cast = false, applied = true,  heal = false, buff = true },
}

-- Strip ESO's grammar suffixes ("Name^Mx") and lower-case for table lookups.
-- zo_strformat with SI_ABILITY_NAME / SI_UNIT_NAME is the ZOS idiom and is
-- used when present; the gsub is the offline fallback and does the same job
-- for English names.
local function fmtName(raw, stringId)
    if type(raw) ~= "string" or raw == "" then return "" end
    if type(zo_strformat) == "function" and type(stringId) == "number" then
        local ok, s = pcall(zo_strformat, stringId, raw)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return (raw:gsub("%^.*$", ""))
end

local function abilityDisplay(raw) return fmtName(raw, SI_ABILITY_NAME) end
local function unitDisplay(raw)    return fmtName(raw, SI_UNIT_NAME) end
local function lowerKey(raw)       return abilityDisplay(raw):lower() end

local function isPlagueEffect(abilityId, name)
    if UP.Plague.PLAGUE_ABILITY_IDS[abilityId] then return true end
    return PLAGUE_NAMES[lowerKey(name)] == true
end

-- Explosion by NAME is only accepted for direct-damage results, never DoT
-- ticks: if the IDs ever drift, the plague's own ticks might also be named
-- "Plaguebreak", and a tick must not be mistaken for the burst.
local DIRECT_DAMAGE = {}
for _, v in ipairs({ ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE,
                     ACTION_RESULT_BLOCKED_DAMAGE, ACTION_RESULT_DAMAGE_SHIELDED,
                     ACTION_RESULT_PRECISE_DAMAGE, ACTION_RESULT_WRECKING_DAMAGE }) do
    if type(v) == "number" then DIRECT_DAMAGE[v] = true end
end
local DOT_RESULTS = {}
for _, v in ipairs({ ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL }) do
    if type(v) == "number" then DOT_RESULTS[v] = true end
end
-- Effect APPLIED to a target, carrying the applier's name. Undocumented but
-- live (LibCombat 89 uses them bare); nil-safe so the set is simply empty on
-- a build that lacks them, and EffectResultsAvailable() says which.
local EFFECT_APPLIED_RESULTS = {}
for _, v in ipairs({ ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_EFFECT_GAINED_DURATION }) do
    if type(v) == "number" then EFFECT_APPLIED_RESULTS[v] = true end
end
function UP.Plague.EffectResultsAvailable()
    return type(ACTION_RESULT_EFFECT_GAINED) == "number"
        or type(ACTION_RESULT_EFFECT_GAINED_DURATION) == "number"
end

-- Friendly things that land on us and carry a caster name.
local FRIENDLY_RESULTS = {}
for _, v in ipairs({ ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL,
                     ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL,
                     ACTION_RESULT_POWER_ENERGIZE }) do
    if type(v) == "number" then FRIENDLY_RESULTS[v] = true end
end

local function isExplosion(abilityId, name, result)
    if UP.Plague.EXPLOSION_ABILITY_IDS[abilityId] then return true end
    if DIRECT_DAMAGE[result] and EXPLOSION_NAMES[lowerKey(name)] then return true end
    return false
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
-- The plague currently on us, or nil.
local active = nil
-- Friendly events seen while a plague was active, newest last. Only recorded
-- while `active` is set, so the per-event cost in normal play is one boolean.
local recent = {}
-- An explosion being assembled for report, or nil. Survives Clear() on death
-- so a burst that kills the carrier is still reported.
local pending = nil
-- Applier details that arrived (DoT tick) before the GAINED effect event.
local staged = nil
local isDead = false
local boomChannel = false   -- true when the ability-id-filtered registration is live

local function pushRecent(entry)
    recent[#recent + 1] = entry
    if #recent > RECENT_MAX then table.remove(recent, 1) end
end

local function publish()
    if UP.PlagueTint and UP.PlagueTint.SetActive then
        UP.PlagueTint.SetActive(active ~= nil)
    end
end

function UP.Plague.IsActive() return active ~= nil end

function UP.Plague.RemainingMs(nowMs)
    if not active or not active.endMs or active.endMs <= 0 then return 0 end
    local r = active.endMs - nowMs
    return r > 0 and r or 0
end

-- Debug overlay / tests.
function UP.Plague.Snapshot()
    return {
        active   = active ~= nil,
        endMs    = active and active.endMs or 0,
        applier  = active and active.applierName or nil,
        pending  = pending ~= nil,
        recent   = #recent,
    }
end

-- ---------------------------------------------------------------------------
-- Report assembly (pure; exercised by Tools/tests/underpressure_plague.lua)
-- ---------------------------------------------------------------------------
local function commas(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function secs(ms)
    return ("%.1fs"):format((ms or 0) / 1000)
end

-- Returns: description string, confidence ("known" | "likely" | "unknown").
function UP.Plague.Attribute(p)
    local fadeT = p.fadedMs or p.startedMs
    local lo, hi = fadeT - ATTRIB_WINDOW_MS, fadeT + 150
    local best, bestRank = nil, 99

    for i = #p.recent, 1, -1 do
        local e = p.recent[i]
        if e.t >= lo and e.t <= hi then
            local known = UP.Plague.CLEANSES[lowerKey(e.ability)]
            local rank
            if known then
                if e.kind == "cast" and known.cast then rank = 1
                elseif e.kind == "applied" and known.applied then rank = 2
                elseif e.kind == "heal" and known.heal then rank = 2
                elseif e.kind == "buff" and known.buff then rank = 3
                end
            end
            -- No further rungs. Unknown abilities are never named, however
            -- close to the fade they landed.
            if rank and rank < bestRank then best, bestRank = e, rank end
        end
    end

    if not best then
        return "unknown. Nothing that can cleanse you left a trace this client can see "
            .. "(an ally's Purge or Efficient Purge, and most set passives, never do).",
            "unknown"
    end

    local before = fadeT - best.t
    local when = before >= 0 and (secs(before) .. " before it vanished") or (secs(-before) .. " after")
    local who
    if best.kind == "cast" or best.whoType == UNIT_PLAYER then
        who = "you"
    elseif best.who and best.who ~= "" then
        who = unitDisplay(best.who)
        if UNIT_GROUP and best.whoType == UNIT_GROUP then who = who .. " (group)" end
    else
        who = (UNIT_GROUP and best.whoType == UNIT_GROUP) and "a groupmate" or "someone"
    end
    local ability = abilityDisplay(best.ability)
    return ("%s with %s (%s)"):format(who, ability, when), "known"
end

function UP.Plague.BuildReport(p, nowMs)
    local lines = {}
    local plague = p.plague or {}

    local head = "|c7FBF5F[Under Pressure] Plaguebreak exploded on you|r"
    local detail = {}
    if p.remainingMs then
        detail[#detail + 1] = ("plague removed with %s left"):format(secs(p.remainingMs))
    else
        detail[#detail + 1] = "plague removal not seen as an effect change"
    end
    if plague.gainedMs and p.fadedMs then
        detail[#detail + 1] = ("applied %s earlier"):format(secs(p.fadedMs - plague.gainedMs))
    end
    if plague.applierName then
        detail[#detail + 1] = ("by %s"):format(unitDisplay(plague.applierName))
    end
    lines[#lines + 1] = head .. " -- " .. table.concat(detail, ", ") .. "."

    local who, conf = UP.Plague.Attribute(p)
    lines[#lines + 1] = ("  Removed by: %s"):format(who)

    if p.hitCount > 0 then
        -- Order targets: you first, then by damage.
        local order = {}
        for name, rec in pairs(p.hits) do order[#order + 1] = { name = name, rec = rec } end
        table.sort(order, function(a, b)
            if a.rec.isYou ~= b.rec.isYou then return a.rec.isYou end
            if a.rec.total ~= b.rec.total then return a.rec.total > b.rec.total end
            return tostring(a.rec.name) < tostring(b.rec.name)
        end)
        local parts = {}
        for _, o in ipairs(order) do
            -- o.name is the dedupe KEY (unit id when present); the display name
            -- lives on the record.
            local shown = o.rec.isYou and "you" or unitDisplay(o.rec.name or o.name)
            if shown == "" then shown = "unknown target" end
            parts[#parts + 1] = ("%s %s"):format(shown, commas(o.rec.total))
        end
        local src = p.explosionSource and (" (dealt by %s)"):format(unitDisplay(p.explosionSource)) or ""
        lines[#lines + 1] = ("  Explosion damage seen: %s over %d hit%s: %s%s"):format(
            commas(p.total), p.hitCount, p.hitCount == 1 and "" or "s", table.concat(parts, ", "), src)
        lines[#lines + 1] = "  Only hits this client received are counted; allies out of view are missed."
    else
        lines[#lines + 1] = "  Explosion damage seen: none reached this client."
    end
    return lines
end

function UP.Plague.Emit(lines)
    local sv = UP.sv or {}
    if sv.plague_report == false then return end
    if type(d) ~= "function" then return end
    for _, l in ipairs(lines) do d(l) end
end

-- ---------------------------------------------------------------------------
-- Pending explosion
-- ---------------------------------------------------------------------------
local function snapshotActive()
    if not active then return nil end
    return {
        abilityId   = active.abilityId,
        name        = active.name,
        gainedMs    = active.gainedMs,
        endMs       = active.endMs,
        applierName = active.applierName,
        applierUnitId = active.applierUnitId,
    }
end

local function finalize()
    local p = pending
    if not p then return end
    pending = nil
    local lines = UP.Plague.BuildReport(p, GetGameTimeMilliseconds())
    if UP.Debug and UP.Debug.Log then UP.Debug.Log("PLAGUE " .. (lines[1] or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")) end
    UP.Plague.Emit(lines)
end

local function startPending(nowMs)
    if pending then return pending end
    pending = {
        startedMs = nowMs,
        fadedMs   = nil,
        remainingMs = nil,
        plague    = snapshotActive() or UP.Plague.lastPlague,
        recent    = {},
        hits      = {},
        hitCount  = 0,
        total     = 0,
        explosionSource = nil,
    }
    -- Copy the ring now: Clear() on death must not take the evidence with it.
    for i, e in ipairs(recent) do pending.recent[i] = e end
    if type(zo_callLater) == "function" then
        zo_callLater(finalize, REPORT_DELAY_MS)
    else
        finalize()
    end
    return pending
end

-- ---------------------------------------------------------------------------
-- Ingest: effects (from EventIngest.onEffectChanged, player unit only)
-- ---------------------------------------------------------------------------
-- Called for EVERY player effect event, so the non-plague path must stay
-- cheap: one ID lookup, one lower-cased name lookup, then a boolean.
function UP.Plague.OnEffect(changeType, abilityId, effectName, endTimeMs, nowMs, effectType, sourceType)
    if isPlagueEffect(abilityId, effectName) then
        if changeType == EFFECT_FADED then
            if not active then return end
            local remaining = (active.endMs and active.endMs > 0) and (active.endMs - nowMs) or 0
            UP.Plague.lastPlague = snapshotActive()
            local early = (remaining > EARLY_FADE_MS) and not isDead
            active = nil
            if early or pending then
                local p = startPending(nowMs)
                p.fadedMs = nowMs
                p.remainingMs = remaining > 0 and remaining or 0
                -- Ring entries that arrived before the pending copy was taken
                -- are already in it; anything after this point is appended by
                -- the recorders below while p is live.
            end
            -- The friendly ring is only meaningful relative to a live plague.
            if not pending then recent = {} end
            publish()
            return
        end

        -- GAINED / UPDATED / FULL_REFRESH: (re)arm.
        local wasActive = active ~= nil
        active = active or {}
        active.abilityId = abilityId
        active.name      = effectName
        active.gainedMs  = wasActive and active.gainedMs or nowMs
        active.endMs     = (type(endTimeMs) == "number" and endTimeMs > 0) and endTimeMs or 0
        if staged then
            active.applierName   = active.applierName or staged.name
            active.applierUnitId = active.applierUnitId or staged.unitId
            staged = nil
        end
        if not wasActive then recent = {} end
        publish()
        return
    end

    -- Not the plague. While one is active, note buffs gained on us: they are
    -- one of the three attribution signals (see header).
    if active and changeType ~= EFFECT_FADED and effectType == BUFF_TYPE then
        pushRecent({ t = nowMs, kind = "buff", who = nil, whoType = sourceType,
                     ability = effectName, abilityId = abilityId })
        if pending then pending.recent[#pending.recent + 1] = recent[#recent] end
    end
end

-- ---------------------------------------------------------------------------
-- Ingest: combat events
-- ---------------------------------------------------------------------------
-- `channel` is "main" (the target=player registration in EventIngest) or
-- "boom" (the ability-id-filtered registration that sees hits on anyone).
-- When the boom channel is live, explosion hits on the player arrive on BOTH,
-- so the main channel ignores them to avoid double counting.
function UP.Plague.SetBoomChannel(on) boomChannel = on == true end

function UP.Plague.OnCombat(channel, result, abilityName, sourceName, sourceType,
                            targetName, targetType, hitValue, sourceUnitId, targetUnitId,
                            abilityId, nowMs)
    -- Fast exit for the overwhelming majority of events.
    if not active and not pending
       and not UP.Plague.PLAGUE_ABILITY_IDS[abilityId]
       and not UP.Plague.EXPLOSION_ABILITY_IDS[abilityId] then
        return
    end

    -- Explosion hit (on anyone).
    if isExplosion(abilityId, abilityName, result) then
        if channel == "main" and boomChannel then return end
        if not DIRECT_DAMAGE[result] then return end
        local p = startPending(nowMs)
        local isYou = (targetType == UNIT_PLAYER)
        local key = isYou and "\0you" or ((type(targetUnitId) == "number" and targetUnitId > 0) and ("u" .. targetUnitId) or (targetName or "?"))
        local rec = p.hits[key]
        if not rec then
            rec = { total = 0, count = 0, isYou = isYou, name = targetName }
            p.hits[key] = rec
        end
        local amount = tonumber(hitValue) or 0
        rec.total = rec.total + amount
        rec.count = rec.count + 1
        p.total = p.total + amount
        p.hitCount = p.hitCount + 1
        if not p.explosionSource and type(sourceName) == "string" and sourceName ~= "" then
            p.explosionSource = sourceName
        end
        return
    end

    -- Plague DoT tick on us: learn who applied it.
    if DOT_RESULTS[result] and targetType == UNIT_PLAYER and isPlagueEffect(abilityId, abilityName) then
        if active then
            if not active.applierName and type(sourceName) == "string" and sourceName ~= "" then
                active.applierName   = sourceName
                active.applierUnitId = sourceUnitId
            end
        else
            staged = { name = sourceName, unitId = sourceUnitId, t = nowMs }
        end
        return
    end

    -- Evidence while plagued, both on the main (target=player) channel:
    -- an effect applied to us by someone, or a friendly event landing on us.
    if active and channel == "main" and targetType == UNIT_PLAYER then
        local kind = nil
        if EFFECT_APPLIED_RESULTS[result] then kind = "applied"
        elseif FRIENDLY_RESULTS[result] then kind = "heal" end
        if kind then
            pushRecent({ t = nowMs, kind = kind, who = sourceName, whoType = sourceType,
                         ability = abilityName, abilityId = abilityId })
            if pending then pending.recent[#pending.recent + 1] = recent[#recent] end
            -- Only while the overlay is up; this is how the field answers
            -- "what does an ally's Purge look like to the victim?"
            if UP.Debug and UP.Debug.LogPlagueEvidence then
                UP.Debug.LogPlagueEvidence(kind, sourceName, sourceType, abilityName, abilityId)
            end
        end
    end
end

-- Our own ability press. Resolved to a name here so the recorder needs no
-- game API; the caller passes what it could read from the action bar.
function UP.Plague.OnOwnCast(abilityId, abilityName, nowMs)
    if not active then return end
    pushRecent({ t = nowMs, kind = "cast", who = nil, whoType = UNIT_PLAYER,
                 ability = abilityName, abilityId = abilityId })
    if pending then pending.recent[#pending.recent + 1] = recent[#recent] end
end

-- ---------------------------------------------------------------------------
-- Death, resync, teardown
-- ---------------------------------------------------------------------------
function UP.Plague.SetDead(dead)
    isDead = dead == true
end

-- Death drops the debuff without an explosion. Clears the live plague but
-- deliberately NOT a pending report -- a burst that kills us is the one we
-- most want to read about.
function UP.Plague.Clear()
    if active then UP.Plague.lastPlague = snapshotActive() end
    active = nil
    staged = nil
    if not pending then recent = {} end
    publish()
end

-- Seed from the current buff list (startup, EVENT_EFFECTS_FULL_UPDATE), the
-- same way SilenceTracker does: per-effect events do not replay for effects
-- already active. timeEnding is SECONDS; converted here.
function UP.Plague.Resync()
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return end
    local ok, n = pcall(GetNumBuffs, "player")
    if not ok or type(n) ~= "number" then return end
    local found = nil
    for i = 1, n do
        local ok2, buffName, _, timeEnding, _, _, _, _, _, _, _, abilityId = pcall(GetUnitBuffInfo, "player", i)
        if ok2 and isPlagueEffect(abilityId, buffName) then
            found = { abilityId = abilityId, name = buffName,
                      endMs = (type(timeEnding) == "number" and timeEnding > 0) and timeEnding * 1000 or 0 }
            break
        end
    end
    if found then
        if not active then
            active = { abilityId = found.abilityId, name = found.name,
                       gainedMs = GetGameTimeMilliseconds(), endMs = found.endMs }
            recent = {}
        else
            active.endMs = found.endMs
        end
    else
        active = nil
        if not pending then recent = {} end
    end
    publish()
end

-- Runtime check that the hard-coded IDs still mean what this file says.
-- Returns ok, detail. Reported by the API audit and recorded as a startup note
-- when it fails, because a renumbered ID would otherwise fail silently into
-- the name fallback.
function UP.Plague.VerifyIds()
    if type(GetAbilityName) ~= "function" then return nil, "GetAbilityName unavailable" end
    local okA, nameA = pcall(GetAbilityName, 159612)
    local okB, nameB = pcall(GetAbilityName, 159623)
    local a = okA and abilityDisplay(nameA) or "?"
    local b = okB and abilityDisplay(nameB) or "?"
    local good = a:lower():find("plague", 1, true) ~= nil and b:lower():find("plague", 1, true) ~= nil
    return good, ("159612=%q 159623=%q"):format(a, b)
end

function UP.Plague.Init()
    active, pending, staged = nil, nil, nil
    recent = {}
    local ok, detail = UP.Plague.VerifyIds()
    if ok == false then
        UP.Note("Plaguebreak ability IDs no longer resolve to plague names (" .. tostring(detail)
                .. "); relying on name matching.")
    end
end

-- Test hook: lets the harness drive time-based finalisation without zo_callLater.
function UP.Plague._FinalizeNow() finalize() end
