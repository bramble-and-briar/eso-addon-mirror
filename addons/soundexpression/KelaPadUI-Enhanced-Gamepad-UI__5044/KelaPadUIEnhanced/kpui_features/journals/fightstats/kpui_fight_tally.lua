-- KelaPadUI Fight Stats detail tally: what LibCombat's fight summary does not
-- carry, collected from its public events while a fight runs and boiled down
-- to a small table when the fight ends:
--
--   * skills: damage, hits, crits, damage over time and casts per ability;
--   * effects: how long each buff and debuff was up, in four lists (buffs and
--     debuffs on you, debuffs and buffs on enemies);
--   * stats: time-weighted average and maximum of penetration, critical,
--     power and maximum resources;
--   * resources: what was gained and spent per resource;
--   * group: who was in the group, each member's own DPS and HPS as they
--     share it through LibGroupCombatStats, the damage each member took, and
--     the group's damage per enemy as LibCombat totals it (the game does not
--     name the source of another player's hit, so nothing else per member);
--   * group buffs: how long each essential buff was up on each member, and
--     which gear sets their buffs are named after (a hint only);
--   * healing and damage taken per ability, for you;
--   * targets: the few enemies that took the most damage, with what each took
--     from you per skill, from the whole group, and which debuffs it carried.
--
-- Nothing is stored per event: every callback adds into a few counters, so no
-- combat log is kept. LibCombat tracks these events while anything listens to
-- them, which is why Start is only called where Fight Stats records (PvE and
-- battlegrounds, see kpui_fight_stats.lua) and Stop everywhere else.
--
-- Take(fight) is called from LibCombat's fight-summary callback and returns the
-- detail for that fight (or nil when nothing was running); Merge adds one
-- detail into another, which is how a battleground match is one entry.

local EVENT_NAMESPACE = "KelaPadUI_FightTally"

local MAX_SKILLS = 40
local MAX_EFFECTS = 40
local MIN_EFFECT_SECONDS = 0.5
-- Per-target and per-character detail is kept for the few that matter.
local MAX_TARGETS = 5
local MAX_TARGET_SKILLS = 15
local MAX_TARGET_EFFECTS = 25
local MAX_HEAL_SKILLS = 12
local MAX_MEMBER_EFFECTS = 25
local MAX_TRACKED_UNITS = 300
-- Effects are tracked per ability and unit: this keeps the two apart in one key.
local UNIT_KEY_SPAN = 16777216

local tally = nil
local active = false

local function NewTally()
	return
	{
		started = false,
		startMs = nil,
		firstMs = nil,
		skills = {},
		-- Your damage per enemy unit: [unitId] = { first, last, skills = { [abilityId] = counters } }.
		units = {},
		unitCount = 0,
		-- Your healing done and the damage you took, per ability.
		healSkills = {},
		takenSkills = {},
		effects = { inBuff = {}, inDebuff = {}, outBuff = {}, outDebuff = {} },
		stats = {},
		resources = {},
		-- Buffs on group members that matter (essential ones and set procs):
		-- [memberName] = { [abilityId] = { since, total } }.
		memberEffects = {},
		-- Offense per hit, as Combat Metrics measures it: [category] = sums.
		offense = {},
		critCap = 125,
		-- Time on each bar and what happened on it: [bar] = { ms, damage, skills, attacks, errors, weaveSum, weaveCount }.
		bars = {},
		bar = nil,
		barSince = nil,
		lastWasAttack = nil,
		-- Deaths and revives in the fight: { ms, state, unitId, ability }.
		deaths = {},
		-- Damage, healing and damage taken per ten seconds, and the boss health.
		timeline = { damage = {}, healing = {}, taken = {}, boss = {} },
		bossHp = {},
		-- Your healing by target unit, with overhealing.
		healTargets = {},
		-- The group's damage taken by ability (you included), yours by your
		-- name, and each other member's by unit id.
		groupTaken = {},
		takenBy = {},
		takenByUnit = {},
		-- Blocks, shields and dodges on the damage you took.
		mitigation = { hits = 0, damage = 0, blockedHits = 0, blockedDamage = 0, shielded = 0, dodges = 0 },
		playerDisplay = nil,
		-- Mundus stone, food and drink when combat began; potions used during it.
		prep = nil,
		potions = {},
		-- Time with nothing done (no hit, no cast) beyond a short grace.
		lastActionMs = nil,
		idleMs = 0,
		-- Damage per second, for the best ten seconds; ultimates cast.
		secondDamage = {},
		ultimateCasts = 0,
		-- Time magicka and stamina spent under a tenth of their maximum.
		resourceLast = {},
		resourceTime = {},
		-- Weave time: the gaps between one skill ending and the next starting.
		weaveSum = 0,
		weaveCount = 0,
		lastSkillEnd = nil,
	}
end

-- ---------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------

local function Touch(timems)
	if not tally.firstMs then
		tally.firstMs = timems
	end
end

local function NewCounters()
	return { damage = 0, dotDamage = 0, hits = 0, crits = 0, ticks = 0, casts = 0, overheal = 0 }
end

local function GetSkill(abilityId)
	local skill = tally.skills[abilityId]
	if not skill then
		skill = NewCounters()
		tally.skills[abilityId] = skill
	end
	return skill
end

local function GetCounters(map, abilityId)
	local counters = map[abilityId]
	if not counters then
		counters = NewCounters()
		map[abilityId] = counters
	end
	return counters
end

local function IsCritical(result)
	return result == ACTION_RESULT_CRITICAL_DAMAGE or result == ACTION_RESULT_DOT_TICK_CRITICAL
		or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_HOT_TICK_CRITICAL
end

local function IsTick(result)
	return result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL
		or result == ACTION_RESULT_HOT_TICK or result == ACTION_RESULT_HOT_TICK_CRITICAL
end

-- Adds one hit into a counters table. What a shield absorbed comes as its own
-- event for the same hit, so it adds damage but is not another hit.
local function AddHit(counters, result, amount)
	counters.damage = counters.damage + amount
	if result == ACTION_RESULT_DAMAGE_SHIELDED then
		return
	end
	counters.hits = counters.hits + 1
	if IsCritical(result) then
		counters.crits = counters.crits + 1
	end
	if IsTick(result) then
		counters.ticks = counters.ticks + 1
		counters.dotDamage = counters.dotDamage + amount
	end
end

local function GetUnitTally(unitId, timems)
	local unit = tally.units[unitId]
	if not unit then
		if tally.unitCount >= MAX_TRACKED_UNITS then
			return nil
		end
		tally.unitCount = tally.unitCount + 1
		unit = { first = timems, last = timems, skills = {} }
		tally.units[unitId] = unit
	end
	unit.last = timems
	return unit
end

-- ---------------------------------------------------------------------------
-- Offense: penetration, critical damage and friends, weighed by damage
-- ---------------------------------------------------------------------------
-- What a stat is worth is what it was when the hits landed, so each hit adds
-- the stat as it stood (your sheet value plus what the target's debuffs gave
-- on top of it) weighed by the damage. The game's own stat tooltips say how the
-- two kinds combine: weapon and spell damage and critical each count when they
-- are the higher of the two, for every ability, so those use the higher value.
-- Penetration follows the damage type: physical, bleed, disease and poison hits
-- meet the physical penetration, flame, frost, magic and shock hits the spell
-- penetration. The category of a hit is that second split.

local PENETRATION_CAP = 18200

local DAMAGE_CATEGORY =
{
	[DAMAGE_TYPE_MAGIC] = "spell", [DAMAGE_TYPE_FIRE] = "spell", [DAMAGE_TYPE_COLD] = "spell", [DAMAGE_TYPE_SHOCK] = "spell",
	[DAMAGE_TYPE_PHYSICAL] = "weapon", [DAMAGE_TYPE_POISON] = "weapon", [DAMAGE_TYPE_DISEASE] = "weapon", [DAMAGE_TYPE_BLEED] = "weapon",
}

local CATEGORY_STATS =
{
	spell =
	{
		power = LIBCOMBAT_STAT_SPELLPOWER, crit = LIBCOMBAT_STAT_SPELLCRIT,
		critBonus = LIBCOMBAT_STAT_SPELLCRITBONUS, penetration = LIBCOMBAT_STAT_SPELLPENETRATION,
	},
	weapon =
	{
		power = LIBCOMBAT_STAT_WEAPONPOWER, crit = LIBCOMBAT_STAT_WEAPONCRIT,
		critBonus = LIBCOMBAT_STAT_WEAPONCRITBONUS, penetration = LIBCOMBAT_STAT_WEAPONPENETRATION,
	},
}

local OFFENSE_SUMS =
{
	"damage", "hits", "powerSum", "powerDamage", "chanceSum", "chanceHits",
	"penDamage", "penSum", "penSumWrath", "penOver", "penOverWrath", "critDamage", "critSum",
}
local OFFENSE_MAXIMA = { "penMax", "penMaxWrath", "critMax" }

local function NewOffense()
	local offense = {}
	for _, field in ipairs(OFFENSE_SUMS) do
		offense[field] = 0
	end
	for _, field in ipairs(OFFENSE_MAXIMA) do
		offense[field] = 0
	end
	return offense
end

local function GetOffense(container, category)
	local offense = container[category]
	if not offense then
		offense = NewOffense()
		container[category] = offense
	end
	return offense
end

-- Adds `from` into `into`; both are { spell = sums, weapon = sums } or nil.
local function MergeOffense(into, from)
	for category, sums in pairs(from or {}) do
		local target = GetOffense(into, category)
		for _, field in ipairs(OFFENSE_SUMS) do
			target[field] = target[field] + (sums[field] or 0)
		end
		for _, field in ipairs(OFFENSE_MAXIMA) do
			target[field] = zo_max(target[field], sums[field] or 0)
		end
	end
	return into
end

-- The higher of the weapon and spell value of one stat, or nil without either.
local function GetHigherStat(stats, weaponStatId, spellStatId)
	local weapon, spell = stats[weaponStatId], stats[spellStatId]
	if weapon and spell then
		return zo_max(weapon.value, spell.value)
	end
	local only = weapon or spell
	return only and only.value or nil
end

local function AddOffenseHit(offense, category, result, amount, penetrationBonus, wrathBonus, critBonus)
	local ids = CATEGORY_STATS[category]
	local stats = tally.stats
	offense.damage = offense.damage + amount
	offense.hits = offense.hits + 1
	local power = GetHigherStat(stats, LIBCOMBAT_STAT_WEAPONPOWER, LIBCOMBAT_STAT_SPELLPOWER)
	if power then
		offense.powerSum = offense.powerSum + power * amount
		offense.powerDamage = offense.powerDamage + amount
	end
	local chance = GetHigherStat(stats, LIBCOMBAT_STAT_WEAPONCRIT, LIBCOMBAT_STAT_SPELLCRIT)
	if chance then
		offense.chanceSum = offense.chanceSum + chance
		offense.chanceHits = offense.chanceHits + 1
	end
	local penetration = stats[ids.penetration]
	if penetration then
		local total = penetration.value + penetrationBonus
		local withWrath = total + wrathBonus
		offense.penDamage = offense.penDamage + amount
		offense.penSum = offense.penSum + zo_min(total, PENETRATION_CAP) * amount
		offense.penSumWrath = offense.penSumWrath + zo_min(withWrath, PENETRATION_CAP) * amount
		if total > PENETRATION_CAP then
			offense.penOver = offense.penOver + amount
		end
		if withWrath > PENETRATION_CAP then
			offense.penOverWrath = offense.penOverWrath + amount
		end
		offense.penMax = zo_max(offense.penMax, total)
		offense.penMaxWrath = zo_max(offense.penMaxWrath, withWrath)
	end
	if IsCritical(result) then
		local bonus = GetHigherStat(stats, LIBCOMBAT_STAT_WEAPONCRITBONUS, LIBCOMBAT_STAT_SPELLCRITBONUS)
		if bonus then
			local total = bonus + critBonus
			offense.critDamage = offense.critDamage + amount
			offense.critSum = offense.critSum + zo_min(total, tally.critCap) * amount
			offense.critMax = zo_max(offense.critMax, total)
		end
	end
end

-- Debuffs that change what a hit on the target is worth. `provider(abilityId)`
-- returns a key shared by every source of the same effect (one Major Breach
-- counts once, whoever applied it), the penetration and critical damage it
-- takes off the target, and whether it is a status effect (those only count
-- with the Wrath of Nature champion star).
local debuffProvider = nil
local debuffCache = {}

local function GetDebuffValue(abilityId)
	local value = debuffCache[abilityId]
	if value == nil then
		value = false
		if debuffProvider then
			local key, penetration, crit, isStatus = debuffProvider(abilityId)
			if key then
				value = { key = key, penetration = penetration or 0, crit = crit or 0, status = isStatus == true }
			end
		end
		debuffCache[abilityId] = value
	end
	return value or nil
end

local function UpdateDebuffValue(unitId, abilityId, timems, active)
	local value = GetDebuffValue(abilityId)
	if not value then
		return
	end
	local unit = GetUnitTally(unitId, timems)
	if not unit then
		return
	end
	unit.on = unit.on or {}
	unit.keyCount = unit.keyCount or {}
	if (unit.on[abilityId] == true) == active then
		return
	end
	unit.on[abilityId] = active or nil
	local count = unit.keyCount[value.key] or 0
	local sign
	if active then
		unit.keyCount[value.key] = count + 1
		sign = count == 0 and 1 or 0
	else
		unit.keyCount[value.key] = zo_max(count - 1, 0)
		sign = count == 1 and -1 or 0
	end
	if sign ~= 0 then
		if value.status then
			unit.penWrath = (unit.penWrath or 0) + sign * value.penetration
		else
			unit.penBonus = (unit.penBonus or 0) + sign * value.penetration
		end
		unit.critBonus = (unit.critBonus or 0) + sign * value.crit
	end
end

-- ---------------------------------------------------------------------------
-- Bars, timeline, healing and what the group took
-- ---------------------------------------------------------------------------

local TIMELINE_STEP = 10
local MAX_TIMELINE_BUCKETS = 360
local MAX_DEATHS = 60

local function GetBucket(timems)
	local startMs = tally.startMs
	if not startMs then
		return nil
	end
	local index = zo_max(zo_floor((timems - startMs) / (TIMELINE_STEP * 1000)) + 1, 1)
	return index <= MAX_TIMELINE_BUCKETS and index or nil
end

local function AddTimeline(series, timems, amount)
	local index = GetBucket(timems)
	if index then
		series[index] = (series[index] or 0) + amount
	end
end

local function GetBarStats(bar)
	local stats = tally.bars[bar]
	if not stats then
		stats = { ms = 0, damage = 0, skills = 0, attacks = 0, errors = 0, weaveSum = 0, weaveCount = 0 }
		tally.bars[bar] = stats
	end
	return stats
end

-- Time on a bar counts from the moment the bar is known to the swap away.
local function SetBar(bar, timems)
	if type(bar) ~= "number" or bar < 1 or tally.bar == bar then
		return
	end
	if tally.bar and tally.barSince then
		local stats = GetBarStats(tally.bar)
		stats.ms = stats.ms + (timems - tally.barSince)
	end
	tally.bar = bar
	tally.barSince = timems
end

-- Time with no hit and no cast counts as idle once it passes two seconds.
local IDLE_GRACE_MS = 2000
local MAX_SECOND_BUCKETS = 3600

local function NoteAction(timems)
	if not tally.started then
		return
	end
	local last = tally.lastActionMs or tally.startMs
	if last and timems > last then
		local gap = timems - last
		if gap > IDLE_GRACE_MS then
			tally.idleMs = tally.idleMs + gap - IDLE_GRACE_MS
		end
		tally.lastActionMs = timems
	elseif not tally.lastActionMs then
		tally.lastActionMs = timems
	end
end

local function AddSecondDamage(timems, amount)
	local startMs = tally.startMs
	if startMs then
		local index = zo_max(zo_floor((timems - startMs) / 1000) + 1, 1)
		if index <= MAX_SECOND_BUCKETS then
			tally.secondDamage[index] = (tally.secondDamage[index] or 0) + amount
		end
	end
end

local function AddGroupTaken(name, abilityId, amount, result)
	tally.takenBy[name] = (tally.takenBy[name] or 0) + amount
	if abilityId then
		AddHit(GetCounters(tally.groupTaken, abilityId), result, amount)
	end
end

local function OnDamageOut(_, timems, result, _, targetUnitId, abilityId, hitValue, damageType, overflow)
	if not tally then
		return
	end
	Touch(timems)
	local skill = GetSkill(abilityId)
	local amount = (hitValue or 0) + (overflow or 0)
	AddHit(skill, result, amount)
	skill.damageType = skill.damageType or damageType
	local unit = targetUnitId and GetUnitTally(targetUnitId, timems)
	if unit then
		AddHit(GetCounters(unit.skills, abilityId), result, amount)
	end
	if tally.started then
		if tally.bar then
			local stats = GetBarStats(tally.bar)
			stats.damage = stats.damage + amount
		end
		AddTimeline(tally.timeline.damage, timems, amount)
		AddSecondDamage(timems, amount)
		NoteAction(timems)
	end
	local category = tally.started and DAMAGE_CATEGORY[damageType]
	if category then
		local penetrationBonus, wrathBonus, critBonus = 0, 0, 0
		if unit then
			penetrationBonus, wrathBonus, critBonus = unit.penBonus or 0, unit.penWrath or 0, unit.critBonus or 0
		end
		AddOffenseHit(GetOffense(tally.offense, category), category, result, amount, penetrationBonus, wrathBonus, critBonus)
		if unit then
			unit.offense = unit.offense or {}
			AddOffenseHit(GetOffense(unit.offense, category), category, result, amount, penetrationBonus, wrathBonus, critBonus)
		end
	end
end

-- Your healing (to others and to yourself, with what was wasted as overhealing)
-- and the damage dealt to you.
local function OnHealOut(_, timems, result, _, targetUnitId, abilityId, hitValue, _, overflow)
	if tally and tally.started and abilityId and hitValue then
		local counters = GetCounters(tally.healSkills, abilityId)
		AddHit(counters, result, hitValue)
		counters.overheal = (counters.overheal or 0) + (overflow or 0)
		AddTimeline(tally.timeline.healing, timems, hitValue)
		local key = targetUnitId or 0
		local target = tally.healTargets[key]
		if not target then
			target = { heal = 0, over = 0 }
			tally.healTargets[key] = target
		end
		target.heal = target.heal + hitValue
		target.over = target.over + (overflow or 0)
	end
end

local function OnDamageIn(_, timems, result, _, _, abilityId, hitValue, _, overflow)
	if tally and tally.started and abilityId and hitValue then
		local amount = hitValue + (overflow or 0)
		AddHit(GetCounters(tally.takenSkills, abilityId), result, amount)
		AddTimeline(tally.timeline.taken, timems, amount)
		local mitigation = tally.mitigation
		mitigation.hits = mitigation.hits + 1
		mitigation.damage = mitigation.damage + hitValue
		if result == ACTION_RESULT_BLOCKED_DAMAGE then
			mitigation.blockedHits = mitigation.blockedHits + 1
			mitigation.blockedDamage = mitigation.blockedDamage + hitValue
		end
		if overflow and overflow > 0 then
			mitigation.shielded = mitigation.shielded + overflow
		end
		AddGroupTaken(tally.playerDisplay or "", abilityId, amount, result)
	end
end

-- Deaths and revives, of you and of group members (names are looked up when
-- the fight ends).
local function OnDeathEvent(_, timems, state, unitId, abilityId)
	if tally and tally.started and unitId and #tally.deaths < MAX_DEATHS then
		tally.deaths[#tally.deaths + 1] = { ms = timems, state = state, unitId = unitId, ability = abilityId }
	end
end

local function OnQuickslot(_, _, itemLink)
	if tally and tally.started and type(itemLink) == "string" and itemLink ~= "" then
		tally.potions[itemLink] = (tally.potions[itemLink] or 0) + 1
	end
end

local function OnMessage(_, timems, message, value)
	if tally and message == LIBCOMBAT_MESSAGE_WEAPONSWAP then
		SetBar(value, timems)
	end
end

-- The boss health line: the share of all bosses' health that is left.
local function OnBossHp(_, timems, bossId, current, maximum)
	if not tally or not tally.started or not bossId or not maximum or maximum <= 0 then
		return
	end
	tally.bossHp[bossId] = { current = current or 0, maximum = maximum }
	local currentSum, maximumSum = 0, 0
	for _, hp in pairs(tally.bossHp) do
		currentSum = currentSum + hp.current
		maximumSum = maximumSum + hp.maximum
	end
	local index = GetBucket(timems)
	if index and maximumSum > 0 then
		tally.timeline.boss[index] = zo_floor(currentSum / maximumSum * 100 + 0.5)
	end
end

-- Vampire toggles do not use the global cooldown, so they never count as a weave.
local IGNORED_TIMING = { [132141] = true, [134160] = true, [135841] = true }
-- A skill occupies at least the global cooldown.
local GLOBAL_COOLDOWN_MS = 1000

-- One cast is counted when a skill begins: instantly, or as a duration or channel.
-- Weave time follows Combat Metrics: the gap from the end of one skill (at least
-- a second after it began) to the start of the next. Light and heavy attacks
-- (slots 1 and 2 of a bar) are what fills the gap, so they are not skills here.
local function OnSkillTiming(_, timems, reducedslot, abilityId, status, _, castTime)
	if not tally then
		return
	end
	if status == LIBCOMBAT_SKILLSTATUS_INSTANT or status == LIBCOMBAT_SKILLSTATUS_BEGIN_DURATION
		or status == LIBCOMBAT_SKILLSTATUS_BEGIN_CHANNEL then
		Touch(timems)
		local skill = GetSkill(abilityId)
		skill.casts = skill.casts + 1
		if not tally.started or IGNORED_TIMING[abilityId] or type(reducedslot) ~= "number" then
			return
		end
		local slot = reducedslot % 10
		local isAttack = slot == 1 or slot == 2
		NoteAction(timems)
		if slot == 8 then
			tally.ultimateCasts = tally.ultimateCasts + 1
		end
		-- The slot says which bar the cast came from.
		local bar = zo_floor(reducedslot / 10) + 1
		SetBar(bar, timems)
		local stats = GetBarStats(bar)
		if isAttack then
			stats.attacks = stats.attacks + 1
		else
			stats.skills = stats.skills + 1
		end
		-- Two skills or two attacks in a row, with nothing woven between, is an
		-- error (counted the way Combat Metrics counts it).
		if tally.lastWasAttack ~= nil and tally.lastWasAttack == isAttack then
			stats.errors = stats.errors + 1
		end
		tally.lastWasAttack = isAttack
		if not isAttack then
			if tally.lastSkillEnd then
				local gap = timems - tally.lastSkillEnd
				tally.weaveSum = tally.weaveSum + gap
				tally.weaveCount = tally.weaveCount + 1
				stats.weaveSum = stats.weaveSum + gap
				stats.weaveCount = stats.weaveCount + 1
			end
			local duration = type(castTime) == "number" and castTime or 0
			tally.lastSkillEnd = timems + zo_max(GLOBAL_COOLDOWN_MS, duration)
		end
	end
end

-- Effects on you (EFFECTS_IN) and the ones you and your group put on others
-- (EFFECTS_OUT, GROUPEFFECTS_OUT). The same effect can be on a unit from more
-- than one source at once (your Major Breach and the tank's), each in its own
-- effect slot, so an effect counts as up while any of its slots is.
local function OnEffect(eventType, timems, unitId, abilityId, changeType, effectType, _, _, effectSlot)
	if not tally or not unitId or not abilityId then
		return
	end
	local effects = tally.effects
	local isBuff = effectType == BUFF_EFFECT_TYPE_BUFF
	local list
	if eventType == LIBCOMBAT_EVENT_EFFECTS_IN then
		list = isBuff and effects.inBuff or effects.inDebuff
	else
		list = isBuff and effects.outBuff or effects.outDebuff
	end
	local key = abilityId * UNIT_KEY_SPAN + unitId
	local state = list[key]
	local wasUp = state ~= nil and state.since ~= nil
	local slot = effectSlot or 0
	if changeType == EFFECT_RESULT_FADED then
		if state then
			state.slots[slot] = nil
			-- A fade for a slot never seen (up before tracking began) ends it too.
			if state.since and next(state.slots) == nil then
				state.total = state.total + (timems - state.since)
				state.since = nil
			end
		end
	else
		if not state then
			state = { id = abilityId, unit = unitId, since = nil, total = 0, slots = {} }
			list[key] = state
		end
		state.slots[slot] = true
		state.since = state.since or timems
	end
	local isUp = state ~= nil and state.since ~= nil
	if list == effects.outDebuff and isUp ~= wasUp then
		UpdateDebuffValue(unitId, abilityId, timems, isUp)
	end
end

local function OnStat(_, timems, _, newValue, statId)
	if not tally or not newValue then
		return
	end
	local stat = tally.stats[statId]
	if not stat then
		tally.stats[statId] = { value = newValue, since = timems, sum = 0, max = newValue }
	else
		stat.sum = stat.sum + stat.value * (timems - stat.since)
		stat.value = newValue
		stat.since = timems
		stat.max = zo_max(stat.max, newValue)
	end
end

local RESOURCE_TYPES =
{
	[COMBAT_MECHANIC_FLAGS_HEALTH] = true,
	[COMBAT_MECHANIC_FLAGS_MAGICKA] = true,
	[COMBAT_MECHANIC_FLAGS_STAMINA] = true,
	[COMBAT_MECHANIC_FLAGS_ULTIMATE] = true,
}

local function OnResource(_, timems, _, change, powerType, powerValue)
	if not tally or not tally.started or not RESOURCE_TYPES[powerType] or not change then
		return
	end
	-- How long magicka and stamina sat under a tenth of their maximum.
	if (powerType == COMBAT_MECHANIC_FLAGS_MAGICKA or powerType == COMBAT_MECHANIC_FLAGS_STAMINA) and powerValue then
		local previous = tally.resourceLast[powerType]
		local maximum = tally.stats[powerType == COMBAT_MECHANIC_FLAGS_MAGICKA and LIBCOMBAT_STAT_MAXMAGICKA or LIBCOMBAT_STAT_MAXSTAMINA]
		if previous and maximum and maximum.value > 0 then
			local elapsed = timems - previous.ms
			-- Events come about every second; a long gap is not measured.
			if elapsed > 0 and elapsed < 5000 then
				local entry = tally.resourceTime[powerType]
				if not entry then
					entry = { low = 0, total = 0 }
					tally.resourceTime[powerType] = entry
				end
				entry.total = entry.total + elapsed
				if previous.value < maximum.value * 0.1 then
					entry.low = entry.low + elapsed
				end
			end
		end
		tally.resourceLast[powerType] = { ms = timems, value = powerValue }
	end
	local resource = tally.resources[powerType]
	if not resource then
		resource = { gain = 0, drain = 0 }
		tally.resources[powerType] = resource
	end
	if change > 0 then
		resource.gain = resource.gain + change
	else
		resource.drain = resource.drain - change
	end
end

-- ---------------------------------------------------------------------------
-- Group members' buffs
-- ---------------------------------------------------------------------------
-- The game does not say what another player wears or has slotted. What can be
-- seen is the buffs on them: the essential ones (decided by the screen through
-- SetEffectFilter) and the ones named after a gear set (a set's proc is usually
-- called what the set is called). Both only hint at the build, so what the
-- screen shows from them is marked as inferred.

local effectFilter = nil
-- Called when a fight begins; what it returns is the detail's `context`.
local contextProvider = nil
local setByName = nil
-- Building the index reads every set, so a failed build is tried again only
-- when recording starts again (Start), never once per buff.
local setIndexTried = false
local abilitySetCache = {}
local trackedCache = {}

-- [lowercased set name] = setId, or false when two sets share the name. Empty
-- (and so not kept) while LibSets has not loaded its sets yet.
local function GetSetByName()
	if setByName then
		return setByName
	end
	local index = {}
	if setIndexTried then
		return index
	end
	setIndexTried = true
	if type(LibSets) == "table" and type(LibSets.GetAllSetIds) == "function" and type(LibSets.GetSetName) == "function" then
		local ok, ids = pcall(LibSets.GetAllSetIds)
		if ok and type(ids) == "table" then
			local count = 0
			for setId in pairs(ids) do
				local okName, name = pcall(LibSets.GetSetName, setId)
				if okName and type(name) == "string" and name ~= "" then
					local key = zo_strlower(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))
					local known = index[key]
					if known == nil then
						index[key] = setId
						count = count + 1
					elseif known ~= setId then
						index[key] = false
					end
				end
			end
			if count > 0 then
				setByName = index
			end
		end
	end
	return index
end

local function IsEssentialEffect(abilityId)
	return effectFilter ~= nil and effectFilter(abilityId) == true
end

-- The set an ability is named after, or nil. Essential buffs never count: they
-- are given by many sources, whatever their name.
local function GetSetOfAbility(abilityId)
	local cached = abilitySetCache[abilityId]
	if cached == nil then
		local index = GetSetByName()
		if not setByName then
			return nil
		end
		cached = false
		local name = GetAbilityName(abilityId)
		if name ~= "" and not IsEssentialEffect(abilityId) then
			local setId = index[zo_strlower(zo_strformat(SI_ABILITY_NAME, name))]
			if type(setId) == "number" then
				cached = setId
			end
		end
		abilitySetCache[abilityId] = cached
	end
	return cached or nil
end

local function IsTrackedEffect(abilityId)
	local tracked = trackedCache[abilityId]
	if tracked == nil then
		tracked = IsEssentialEffect(abilityId) or GetSetOfAbility(abilityId) ~= nil
		-- Without the set names yet, an unknown buff may still turn out to count.
		if tracked or setByName then
			trackedCache[abilityId] = tracked
		end
	end
	return tracked
end

local function CloseEffect(state, timems)
	if state.since then
		state.total = state.total + (timems - state.since)
		state.since = nil
	end
end

local function GetMemberEffect(name, abilityId)
	local list = tally.memberEffects[name]
	if not list then
		list = {}
		tally.memberEffects[name] = list
	end
	local state = list[abilityId]
	if not state then
		state = { id = abilityId, unit = 0, since = nil, total = 0 }
		list[abilityId] = state
	end
	return state
end

-- EVENT_EFFECT_CHANGED on a group unit tag.
local function OnMemberEffect(_, changeType, _, _, unitTag, _, _, _, _, _, effectType, _, _, unitName, _, abilityId)
	if not tally or effectType ~= BUFF_EFFECT_TYPE_BUFF or not abilityId or not unitName or unitName == "" then
		return
	end
	if AreUnitsEqual(unitTag, "player") or not IsTrackedEffect(abilityId) then
		return
	end
	local state = GetMemberEffect(ZO_CachedStrFormat(SI_UNIT_NAME, unitName), abilityId)
	if changeType == EFFECT_RESULT_FADED then
		CloseEffect(state, GetGameTimeMilliseconds())
	else
		state.since = state.since or GetGameTimeMilliseconds()
	end
end

-- Buffs already up when the fight starts raise no event, so they are read once.
local function SeedMemberEffects(now)
	for index = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(index)
		if unitTag and not AreUnitsEqual(unitTag, "player") then
			local name = ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName(unitTag))
			for buffIndex = 1, GetNumBuffs(unitTag) do
				local _, _, _, _, _, _, _, effectType, _, _, abilityId = GetUnitBuffInfo(unitTag, buffIndex)
				if effectType == BUFF_EFFECT_TYPE_BUFF and abilityId and IsTrackedEffect(abilityId) then
					local state = GetMemberEffect(name, abilityId)
					state.since = state.since or now
				end
			end
		end
	end
end

-- The critical damage cap is higher with the class mastery passive (the same
-- check LibCombat makes at the end of a fight).
local function HasCritMastery()
	if not SKILLS_DATA_MANAGER then
		return false
	end
	local ok, purchased = pcall(function()
		local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(263605)
		return progression and progression.skillData and progression.skillData.isPurchased
	end)
	return ok and purchased == true
end

-- The mundus stone (from the game) and food and drink (LibFoodDrinkBuff knows
-- which buffs are one) the player has as combat begins, as ability ids.
local function GetPrep()
	local prep = { mundus = {}, food = {} }
	local ok = pcall(function()
		for _, index in ipairs({ GetUnitActiveMundusStoneBuffIndices("player") }) do
			local abilityId = select(11, GetUnitBuffInfo("player", index))
			if abilityId then
				prep.mundus[#prep.mundus + 1] = abilityId
			end
		end
		local library = LIB_FOOD_DRINK_BUFF or LibFoodDrinkBuff
		if type(library) == "table" and type(library.GetBuffTypeInfos) == "function" then
			-- Without the library "no food" cannot be told from "food not detected".
			prep.foodKnown = true
			for index = 1, GetNumBuffs("player") do
				local abilityId = select(11, GetUnitBuffInfo("player", index))
				local kind, isDrink = library:GetBuffTypeInfos(abilityId)
				if kind and kind ~= (LFDB_BUFF_TYPE_NONE or 0) then
					prep.food[#prep.food + 1] = { id = abilityId, drink = isDrink == true }
				end
			end
		end
	end)
	return ok and prep or nil
end

-- Effects, stats and resources from before the fight began are not part of it:
-- counting starts when the player enters combat, and what is already up (a
-- buff, a stat value) carries on from that moment.
local function OnCombatState(_, inCombat)
	if not tally or not inCombat or tally.started then
		return
	end
	local now = GetGameTimeMilliseconds()
	tally.started = true
	tally.startMs = now
	tally.playerName = GetUnitName("player")
	for _, list in pairs(tally.effects) do
		for _, state in pairs(list) do
			state.total = 0
			if state.since then
				state.since = now
			end
		end
	end
	for _, stat in pairs(tally.stats) do
		stat.sum = 0
		stat.since = now
		stat.max = stat.value
	end
	tally.resources = {}
	tally.weaveSum, tally.weaveCount, tally.lastSkillEnd = 0, 0, nil
	tally.offense = {}
	tally.prep = GetPrep()
	tally.lastActionMs = nil
	tally.idleMs = 0
	tally.secondDamage = {}
	tally.ultimateCasts = 0
	tally.resourceLast = {}
	tally.resourceTime = {}
	tally.bars = {}
	tally.barSince = tally.bar and now or nil
	tally.lastWasAttack = nil
	tally.playerDisplay = ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName("player"))
	tally.critCap = HasCritMastery() and 155 or 125
	-- Where the fight began; the summary can arrive after you have moved on.
	if contextProvider then
		local ok, context = pcall(contextProvider)
		tally.context = ok and context or nil
	end
	for _, unit in pairs(tally.units) do
		unit.offense = nil
	end
	for _, list in pairs(tally.memberEffects) do
		for _, state in pairs(list) do
			state.total = 0
			if state.since then
				state.since = now
			end
		end
	end
	SeedMemberEffects(now)
end

-- What the game tells about other group members. It names the source of a hit
-- only when you are the attacker or the target, so another player's damage and
-- healing arrive without a source: per-member damage cannot be counted here
-- (LibCombat totals the whole group's damage per target instead, and each
-- member's own figures come from LibGroupCombatStats, see ReadGroupStats). The
-- target of a hit on a group member is known, so their damage taken is.
-- Damage taken by group members (you are counted from your own damage events),
-- by unit id; names come from the fight's units when it ends. Blocked hits and
-- what shields absorbed count, as they do for you.
local function OnGroupTaken(_, result, _, _, _, _, _, _, targetName, _, hitValue, _, _, _, _, targetUnitId, abilityId)
	if not tally or not tally.started or not hitValue or hitValue <= 0 then
		return
	end
	local key = targetUnitId or 0
	local entry = tally.takenByUnit[key]
	if not entry then
		entry = { amount = 0, name = nil }
		tally.takenByUnit[key] = entry
	end
	entry.amount = entry.amount + hitValue
	if not entry.name and targetName and targetName ~= "" then
		entry.name = ZO_CachedStrFormat(SI_UNIT_NAME, targetName)
	end
	if abilityId then
		AddHit(GetCounters(tally.groupTaken, abilityId), result, hitValue)
	end
end

local function OnDodge()
	if tally and tally.started then
		tally.mitigation.dodges = tally.mitigation.dodges + 1
	end
end

-- The same results LibCombat counts as damage: blocked hits and damage a shield
-- absorbed included.
local GROUP_TAKEN_RESULTS =
{
	ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL,
	ACTION_RESULT_BLOCKED_DAMAGE, ACTION_RESULT_DAMAGE_SHIELDED,
}

local function RegisterGroupEvents(register)
	for index, result in ipairs(GROUP_TAKEN_RESULTS) do
		local namespace = EVENT_NAMESPACE .. "GroupTaken" .. index
		if register then
			EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnGroupTaken)
			-- All filters in one call: each call replaces the previous ones.
			EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT,
				REGISTER_FILTER_COMBAT_RESULT, result,
				REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP,
				REGISTER_FILTER_IS_ERROR, false)
		else
			EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_COMBAT_EVENT)
		end
	end
	local dodgeNamespace = EVENT_NAMESPACE .. "Dodge"
	if register then
		EVENT_MANAGER:RegisterForEvent(dodgeNamespace, EVENT_COMBAT_EVENT, OnDodge)
		EVENT_MANAGER:AddFilterForEvent(dodgeNamespace, EVENT_COMBAT_EVENT,
			REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DODGED,
			REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
			REGISTER_FILTER_IS_ERROR, false)
	else
		EVENT_MANAGER:UnregisterForEvent(dodgeNamespace, EVENT_COMBAT_EVENT)
	end
	local effectNamespace = EVENT_NAMESPACE .. "GroupEffects"
	if register then
		EVENT_MANAGER:RegisterForEvent(effectNamespace, EVENT_EFFECT_CHANGED, OnMemberEffect)
		EVENT_MANAGER:AddFilterForEvent(effectNamespace, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
	else
		EVENT_MANAGER:UnregisterForEvent(effectNamespace, EVENT_EFFECT_CHANGED)
	end
end

-- LibCombat totals the group's damage per enemy only while something listens
-- to its group recap; this listener only keeps that tracking on.
local function OnGroupRecap()
end

local CALLBACKS =
{
	{ LIBCOMBAT_EVENT_DAMAGE_OUT, OnDamageOut },
	{ LIBCOMBAT_EVENT_HEAL_OUT, OnHealOut },
	{ LIBCOMBAT_EVENT_HEAL_SELF, OnHealOut },
	{ LIBCOMBAT_EVENT_DAMAGE_IN, OnDamageIn },
	{ LIBCOMBAT_EVENT_SKILL_TIMINGS, OnSkillTiming },
	{ LIBCOMBAT_EVENT_EFFECTS_IN, OnEffect },
	{ LIBCOMBAT_EVENT_EFFECTS_OUT, OnEffect },
	-- Debuffs your group puts on enemies (the tank's Major Breach): they change
	-- what your hits are worth as much as your own do.
	{ LIBCOMBAT_EVENT_GROUPEFFECTS_OUT, OnEffect },
	{ LIBCOMBAT_EVENT_PLAYERSTATS, OnStat },
	{ LIBCOMBAT_EVENT_RESOURCES, OnResource },
	{ LIBCOMBAT_EVENT_DEATH, OnDeathEvent },
	{ LIBCOMBAT_EVENT_MESSAGES, OnMessage },
	{ LIBCOMBAT_EVENT_BOSSHP, OnBossHp },
	{ LIBCOMBAT_EVENT_QUICKSLOT, OnQuickslot },
	{ LIBCOMBAT_EVENT_GROUPRECAP, OnGroupRecap },
}

-- ---------------------------------------------------------------------------
-- Snapshot
-- ---------------------------------------------------------------------------

local function RoundSeconds(ms)
	return zo_floor(ms / 100 + 0.5) / 10
end

-- The longest any one unit had the effect, in seconds, for one effect list.
-- `keep(unitId)` decides which units count; `limit` caps how many effects stay.
local function CollapseEffects(list, startMs, endMs, keep, limit)
	local longest = {}
	for _, state in pairs(list) do
		if keep(state.unit) then
			local total = state.total
			if state.since then
				total = total + (endMs - zo_max(state.since, startMs))
			end
			total = zo_min(zo_max(total, 0), endMs - startMs)
			if total > (longest[state.id] or 0) then
				longest[state.id] = total
			end
		end
	end
	local result = {}
	local ranked = {}
	for id, ms in pairs(longest) do
		if ms >= MIN_EFFECT_SECONDS * 1000 then
			ranked[#ranked + 1] = { id = id, ms = ms }
		end
	end
	table.sort(ranked, function(a, b)
		if a.ms ~= b.ms then
			return a.ms > b.ms
		end
		return a.id < b.id
	end)
	for index = 1, zo_min(#ranked, limit or MAX_EFFECTS) do
		result[ranked[index].id] = RoundSeconds(ranked[index].ms)
	end
	return result
end

local function CopySkills(skills, limit)
	local ranked = {}
	for id, skill in pairs(skills) do
		if skill.damage > 0 or skill.casts > 0 then
			ranked[#ranked + 1] = { id = id, skill = skill }
		end
	end
	table.sort(ranked, function(a, b)
		if a.skill.damage ~= b.skill.damage then
			return a.skill.damage > b.skill.damage
		end
		if a.skill.casts ~= b.skill.casts then
			return a.skill.casts > b.skill.casts
		end
		return a.id < b.id
	end)
	local result = {}
	for index = 1, zo_min(#ranked, limit or MAX_SKILLS) do
		local skill = ranked[index].skill
		result[ranked[index].id] =
		{
			damage = skill.damage, dotDamage = skill.dotDamage, hits = skill.hits, crits = skill.crits,
			ticks = skill.ticks, casts = skill.casts, damageType = skill.damageType, overheal = skill.overheal,
		}
	end
	return result
end

local SKILL_FIELDS = { "damage", "dotDamage", "hits", "crits", "ticks", "casts", "overheal" }

local function AddNumbers(into, from, fields)
	for _, field in ipairs(fields) do
		into[field] = (into[field] or 0) + (from[field] or 0)
	end
end

-- Adds one table of skill counters into another.
local function AddSkillMap(into, from)
	for id, skill in pairs(from or {}) do
		local target = into[id]
		if not target then
			target = { damageType = skill.damageType }
			into[id] = target
		end
		AddNumbers(target, skill, SKILL_FIELDS)
	end
end

-- The enemies that took the most damage from you and your group, by name, with
-- what each took per skill and per group member and which debuffs it carried.
local function BuildTargets(t, units, startMs, endMs)
	local byName = {}
	local function Get(name)
		local target = byName[name]
		if not target then
			target = { name = name, you = 0, group = 0, skills = {}, unitIds = {} }
			byName[name] = target
		end
		return target
	end
	local function Span(target, first, last)
		target.first = target.first and zo_min(target.first, first) or first
		target.last = target.last and zo_max(target.last, last) or last
	end
	-- Your damage per enemy, by skill.
	for unitId, unit in pairs(t.units) do
		local info = units[unitId]
		if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			local target = Get(info.name)
			target.unitIds[unitId] = true
			Span(target, unit.first, unit.last)
			if unit.offense then
				target.offense = MergeOffense(target.offense or {}, unit.offense)
			end
			AddSkillMap(target.skills, unit.skills)
			for _, skill in pairs(unit.skills) do
				target.you = target.you + skill.damage
			end
		end
	end
	-- The whole group's damage per enemy, you included, as LibCombat totals it.
	for unitId, info in pairs(units) do
		local groupDamage = type(info) == "table" and tonumber(info.groupDamageOut) or 0
		if groupDamage > 0 and info.isFriendly == false and type(info.name) == "string" and info.name ~= "" then
			local target = Get(info.name)
			target.unitIds[unitId] = true
			target.group = target.group + groupDamage
		end
	end

	local ranked = {}
	for _, target in pairs(byName) do
		-- The group's total includes yours; without it, yours is all there is.
		target.damage = zo_max(target.group, target.you)
		if target.damage > 0 then
			ranked[#ranked + 1] = target
		end
	end
	table.sort(ranked, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.name < b.name
	end)

	local fightSeconds = zo_max((endMs - startMs) / 1000, 1)
	local result = {}
	for index = 1, zo_min(#ranked, MAX_TARGETS) do
		local target = ranked[index]
		local unitIds = target.unitIds
		result[index] =
		{
			name = target.name,
			damage = target.damage,
			you = target.you,
			group = target.group > 0 and target.group or nil,
			-- How long you attacked it, or the whole fight for a target only
			-- the group hit.
			seconds = target.first and zo_max((target.last - target.first) / 1000, 1) or fightSeconds,
			offense = target.offense,
			skills = CopySkills(target.skills, MAX_TARGET_SKILLS),
			debuffs = CollapseEffects(t.effects.outDebuff, startMs, endMs, function(unitId)
				return unitIds[unitId] == true
			end, MAX_TARGET_EFFECTS),
		}
	end
	return result
end

-- Group members share their class skill lines and their own DPS and HPS (from
-- their LibCombat) through LibGroupCombatStats, but only to add-ons that
-- registered for them, and only when the member runs an add-on that registers
-- too. Registering also shares yours with them, and lasts for the session.
local groupStatsSource = nil
local groupStatsRegistered = false

local function RegisterGroupStatsSource()
	if groupStatsRegistered then
		return
	end
	groupStatsRegistered = true
	if type(LibGroupCombatStats) == "table" and type(LibGroupCombatStats.RegisterAddon) == "function" then
		local ok, source = pcall(LibGroupCombatStats.RegisterAddon, EVENT_NAMESPACE, { "SKILLLINES", "DPS", "HPS" })
		if ok and type(source) == "table" then
			groupStatsSource = source
		end
	end
end

local function CallSource(method, unitTag)
	if not groupStatsSource or type(groupStatsSource[method]) ~= "function" then
		return nil
	end
	local ok, value = pcall(groupStatsSource[method], groupStatsSource, unitTag)
	return ok and type(value) == "table" and value or nil
end

-- The skill line ids a group member shares (up to three), or nil.
local function GetSharedSkillLines(unitTag)
	local lines = CallSource("GetUnitSkillLines", unitTag)
	if not lines then
		return nil
	end
	local ids = {}
	for _, key in ipairs({ "first", "second", "third" }) do
		local id = lines[key]
		if type(id) == "number" and id > 0 then
			ids[#ids + 1] = id
		end
	end
	return #ids > 0 and ids or nil
end

-- LibGroupCombatStats' damage kinds (its DAMAGE_TOTAL and DAMAGE_BOSS).
local SHARED_DAMAGE_TOTAL, SHARED_DAMAGE_BOSS = 1, 2

-- A member's own DPS and HPS as they share it, in whole numbers, or nil. The
-- library sends DPS and HPS in thousands, total damage in ten thousands and
-- boss DPS in hundreds (as HodorReflexes reads them).
local function GetSharedStats(unitTag)
	local dps = CallSource("GetUnitDPS", unitTag)
	local hps = CallSource("GetUnitHPS", unitTag)
	local stats = {}
	if dps and (tonumber(dps.dps) or 0) > 0 then
		stats.dps = dps.dps * 1000
		if dps.dmgType == SHARED_DAMAGE_BOSS then
			stats.bossDps = (tonumber(dps.dmg) or 0) * 100
		elseif dps.dmgType == SHARED_DAMAGE_TOTAL then
			stats.damage = (tonumber(dps.dmg) or 0) * 10000
		end
	end
	if hps and ((tonumber(hps.hps) or 0) > 0 or (tonumber(hps.overheal) or 0) > 0) then
		stats.hps = (tonumber(hps.hps) or 0) * 1000
		stats.rawHps = (tonumber(hps.overheal) or 0) * 1000
	end
	return next(stats) and stats or nil
end

-- Each group member's shared stats right now, by name. The screen reads this
-- again a few seconds after a fight, as members send their last figures late.
local function ReadGroupStats()
	local result = {}
	if not groupStatsSource then
		return result
	end
	for index = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(index)
		if unitTag and not AreUnitsEqual(unitTag, "player") then
			result[ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName(unitTag))] = GetSharedStats(unitTag)
		end
	end
	return result
end

local function BuildDetail(t, fight)
	local startMs = t.startMs or t.firstMs or fight.combatstart or 0
	local endMs = fight.combatend
	if type(endMs) ~= "number" or endMs <= startMs then
		endMs = GetGameTimeMilliseconds()
	end
	local units = type(fight.units) == "table" and fight.units or {}
	local function IsEnemy(unitId)
		local unit = units[unitId]
		return type(unit) ~= "table" or unit.isFriendly ~= true
	end
	local function IsAny()
		return true
	end

	local stats = {}
	for statId, stat in pairs(t.stats) do
		local sum = stat.sum + stat.value * (endMs - zo_max(stat.since, startMs))
		stats[statId] = { sum = sum / 1000, max = stat.max }
	end

	local resources = {}
	for powerType, resource in pairs(t.resources) do
		resources[powerType] = { gain = resource.gain, drain = resource.drain }
	end

	-- Who was in the group when the fight ended: what the game tells about
	-- another player (it does not reveal their gear or skills), plus what they
	-- share through LibGroupCombatStats: class skill lines, DPS and HPS.
	local fightSeconds = zo_max((endMs - startMs) / 1000, 0.1)
	local roster = {}
	for index = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(index)
		if unitTag and not AreUnitsEqual(unitTag, "player") then
			local name = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
			roster[name] =
			{
				classId = GetUnitClassId(unitTag), raceId = GetUnitRaceId(unitTag), gender = GetUnitGender(unitTag),
				roleId = GetGroupMemberSelectedRole(unitTag), level = GetUnitLevel(unitTag),
				championPoints = GetUnitChampionPoints(unitTag), account = GetUnitDisplayName(unitTag),
				skillLines = GetSharedSkillLines(unitTag),
				shared = GetSharedStats(unitTag),
				seconds = fightSeconds,
			}
		end
	end

	-- Buffs on group members, and the gear sets their buffs point to.
	local memberBuffs, memberSetIds = {}, {}
	local function AddSet(name, abilityId)
		local setId = GetSetOfAbility(abilityId)
		if setId then
			memberSetIds[name] = memberSetIds[name] or {}
			memberSetIds[name][setId] = true
		end
	end
	for name, list in pairs(t.memberEffects) do
		for abilityId in pairs(list) do
			AddSet(name, abilityId)
		end
		local buffs = CollapseEffects(list, startMs, endMs, IsAny, MAX_MEMBER_EFFECTS)
		if next(buffs) then
			memberBuffs[name] = buffs
		end
	end
	local memberSets = {}
	for name, ids in pairs(memberSetIds) do
		local list = {}
		for setId in pairs(ids) do
			list[#list + 1] = setId
		end
		table.sort(list)
		memberSets[name] = list
	end

	-- Time on each bar, with the one still running closed at the end.
	local bars = {}
	for bar, stats in pairs(t.bars) do
		local ms = stats.ms
		if t.bar == bar and t.barSince then
			ms = ms + zo_max(endMs - t.barSince, 0)
		end
		bars[bar] =
		{
			seconds = RoundSeconds(ms), damage = stats.damage, skills = stats.skills, attacks = stats.attacks,
			errors = stats.errors, weaveSum = stats.weaveSum, weaveCount = stats.weaveCount,
		}
	end

	local function GetFightUnitName(unitId)
		local info = units[unitId]
		if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			return ZO_CachedStrFormat(SI_UNIT_NAME, info.name)
		end
		return nil
	end

	local deaths = {}
	for _, death in ipairs(t.deaths) do
		local name = GetFightUnitName(death.unitId)
		if name then
			deaths[#deaths + 1] =
			{
				t = RoundSeconds(zo_max(death.ms - startMs, 0)), name = name, state = death.state, ability = death.ability,
			}
		end
	end

	-- Dense arrays per ten seconds; the boss line carries its last value forward.
	local buckets = 0
	for _, series in pairs(t.timeline) do
		for index in pairs(series) do
			buckets = zo_max(buckets, index)
		end
	end
	local timeline = { step = TIMELINE_STEP, n = buckets, damage = {}, healing = {}, taken = {}, boss = {} }
	local lastBoss
	for index = 1, buckets do
		timeline.damage[index] = zo_floor(t.timeline.damage[index] or 0)
		timeline.healing[index] = zo_floor(t.timeline.healing[index] or 0)
		timeline.taken[index] = zo_floor(t.timeline.taken[index] or 0)
		lastBoss = t.timeline.boss[index] or lastBoss
		timeline.boss[index] = lastBoss
	end

	-- Your healing by who received it (another player's healing has no source
	-- the game names, so only yours is known).
	local yourHealing = {}
	for unitId, entry in pairs(t.healTargets) do
		local name = GetFightUnitName(unitId)
		if name then
			local target = yourHealing[name] or { heal = 0, over = 0 }
			target.heal = target.heal + entry.heal
			target.over = target.over + entry.over
			yourHealing[name] = target
		end
	end

	-- Damage taken by name: yours, then each member's by their unit.
	local takenBy = {}
	for name, amount in pairs(t.takenBy) do
		takenBy[name] = amount
	end
	for unitId, entry in pairs(t.takenByUnit) do
		local name = GetFightUnitName(unitId) or entry.name
		if name then
			takenBy[name] = (takenBy[name] or 0) + entry.amount
		end
	end

	-- The best ten seconds of damage, from damage per second.
	local peakBurst, peakAt, window = 0, 0, 0
	local lastSecond = 0
	for index in pairs(t.secondDamage) do
		lastSecond = zo_max(lastSecond, index)
	end
	for index = 1, lastSecond do
		window = window + (t.secondDamage[index] or 0)
		if index > 10 then
			window = window - (t.secondDamage[index - 10] or 0)
		end
		if window > peakBurst then
			peakBurst, peakAt = window, index
		end
	end
	local resourceTime = {}
	for powerType, entry in pairs(t.resourceTime) do
		resourceTime[powerType] = { low = entry.low / 1000, total = entry.total / 1000 }
	end
	local potions = {}
	for link, count in pairs(t.potions) do
		potions[#potions + 1] = { link = link, count = count }
	end
	table.sort(potions, function(a, b)
		return a.link < b.link
	end)
	return
	{
		seconds = zo_max((endMs - startMs) / 1000, 0.1),
		context = t.context,
		prep = t.prep and { mundus = t.prep.mundus, food = t.prep.food, foodKnown = t.prep.foodKnown, potions = potions } or nil,
		idleSeconds = zo_min(t.idleMs / 1000, fightSeconds),
		peakBurst = peakBurst,
		peakAt = peakAt,
		ultimateCasts = t.ultimateCasts,
		resourceTime = resourceTime,
		bars = bars,
		deaths = deaths,
		timeline = timeline,
		yourHealing = yourHealing,
		groupTaken = CopySkills(t.groupTaken, MAX_HEAL_SKILLS),
		takenBy = takenBy,
		mitigation = t.mitigation,
		memberBuffs = memberBuffs,
		memberSets = memberSets,
		offense = t.offense,
		wrathCP = type(fight.CP) == "table" and type(fight.CP[1]) == "table" and type(fight.CP[1].slotted) == "table"
			and fight.CP[1].slotted[276] == true or nil,
		critMastery = type(fight.special) == "table" and fight.special.CritBonusMastery == true or nil,
		weaveSum = t.weaveSum,
		weaveCount = t.weaveCount,
		roster = roster,
		skills = CopySkills(t.skills),
		healSkills = CopySkills(t.healSkills, MAX_HEAL_SKILLS),
		takenSkills = CopySkills(t.takenSkills, MAX_HEAL_SKILLS),
		targets = BuildTargets(t, units, startMs, endMs),
		effects =
		{
			selfBuffs = CollapseEffects(t.effects.inBuff, startMs, endMs, IsAny),
			selfDebuffs = CollapseEffects(t.effects.inDebuff, startMs, endMs, IsAny),
			enemyDebuffs = CollapseEffects(t.effects.outDebuff, startMs, endMs, IsEnemy),
			enemyBuffs = CollapseEffects(t.effects.outBuff, startMs, endMs, function(unitId)
				-- A buff counts as an enemy's only when the unit is known to be hostile.
				local unit = units[unitId]
				return type(unit) == "table" and unit.isFriendly == false
			end),
		},
		stats = stats,
		resources = resources,
	}
end

-- ---------------------------------------------------------------------------
-- Public interface
-- ---------------------------------------------------------------------------

KPUI_FIGHT_TALLY = {}

-- `filter(abilityId)` says whether a buff is one the screen wants per member
-- (the essential buffs). Set before the first fight.
function KPUI_FIGHT_TALLY.SetEffectFilter(filter)
	effectFilter = filter
	trackedCache = {}
	abilitySetCache = {}
end

-- `provider(abilityId)` describes the debuffs that change what a hit on an
-- enemy is worth: key, penetration, critical damage, isStatusEffect.
function KPUI_FIGHT_TALLY.SetDebuffProvider(provider)
	debuffProvider = provider
	debuffCache = {}
end

-- `provider()` is asked when a fight begins; its value comes back as the
-- detail's `context` (the screen keeps the content type there).
function KPUI_FIGHT_TALLY.SetContextProvider(provider)
	contextProvider = provider
end

-- Each group member's stats as they share them through LibGroupCombatStats
-- right now, by name (see ReadGroupStats).
function KPUI_FIGHT_TALLY.ReadGroupStats()
	return ReadGroupStats()
end

-- Whether group members' own DPS and HPS can be read at all.
function KPUI_FIGHT_TALLY.HasGroupStats()
	return groupStatsSource ~= nil
end

-- The gear set an ability is named after, or nil (see GetSetOfAbility).
function KPUI_FIGHT_TALLY.GetSetOfAbility(abilityId)
	return GetSetOfAbility(abilityId)
end

local function CanTally()
	return type(LibCombat) == "table" and type(LibCombat.RegisterCallbackType) == "function"
		and LIBCOMBAT_EVENT_SKILL_TIMINGS ~= nil and LIBCOMBAT_EVENT_RESOURCES ~= nil
		and LIBCOMBAT_SKILLSTATUS_INSTANT ~= nil
		and LIBCOMBAT_EVENT_HEAL_OUT ~= nil and LIBCOMBAT_EVENT_HEAL_SELF ~= nil
		and LIBCOMBAT_EVENT_DAMAGE_IN ~= nil
		and LIBCOMBAT_EVENT_DEATH ~= nil and LIBCOMBAT_EVENT_MESSAGES ~= nil and LIBCOMBAT_EVENT_BOSSHP ~= nil
		and LIBCOMBAT_MESSAGE_WEAPONSWAP ~= nil and LIBCOMBAT_EVENT_QUICKSLOT ~= nil
		and LIBCOMBAT_EVENT_GROUPEFFECTS_OUT ~= nil and LIBCOMBAT_EVENT_GROUPRECAP ~= nil
end

-- Starts collecting for the next fight.
function KPUI_FIGHT_TALLY.Start()
	if active or not CanTally() then
		return
	end
	active = true
	tally = NewTally()
	RegisterGroupStatsSource()
	setIndexTried = false
	GetSetByName()
	for _, entry in ipairs(CALLBACKS) do
		LibCombat:RegisterCallbackType(entry[1], entry[2], EVENT_NAMESPACE)
	end
	EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
	RegisterGroupEvents(true)
	-- Already in combat when started: count from now.
	if IsUnitInCombat("player") then
		OnCombatState(nil, true)
	end
end

-- Stops collecting and drops whatever was counted.
function KPUI_FIGHT_TALLY.Stop()
	if not active then
		return
	end
	active = false
	tally = nil
	for _, entry in ipairs(CALLBACKS) do
		LibCombat:UnregisterCallbackType(entry[1], entry[2], EVENT_NAMESPACE)
	end
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE)
	RegisterGroupEvents(false)
end

-- The detail of the fight LibCombat just summarized, or nil. Counting starts
-- over for the next fight.
function KPUI_FIGHT_TALLY.Take(fight)
	local t = tally
	if not t then
		return nil
	end
	tally = NewTally()
	-- LibCombat can end a fight while you are still fighting (a reset at an
	-- encounter, or Combat Metrics' reset button). No "entered combat" follows,
	-- so the next fight starts counting now.
	if IsUnitInCombat("player") then
		OnCombatState(nil, true)
	end
	if type(fight) ~= "table" or (not t.started and not t.firstMs) then
		return nil
	end
	local ok, detail = pcall(BuildDetail, t, fight)
	if not ok then
		if KelaPadUI and KelaPadUI.log then
			KelaPadUI.log:Warn("Fight detail failed: %s", tostring(detail))
		end
		return nil
	end
	return detail
end

local function NewDetail()
	return
	{
		seconds = 0, weaveSum = 0, weaveCount = 0, skills = {}, healSkills = {}, takenSkills = {}, targets = {},
		memberBuffs = {}, memberSets = {},
		bars = {}, deaths = {}, yourHealing = {}, groupTaken = {}, takenBy = {},
		idleSeconds = 0, peakBurst = 0, peakAt = 0, ultimateCasts = 0, resourceTime = {},
		timeline = { step = 10, n = 0, damage = {}, healing = {}, taken = {}, boss = {} },
		mitigation = { hits = 0, damage = 0, blockedHits = 0, blockedDamage = 0, shielded = 0, dodges = 0 },
		effects = { selfBuffs = {}, selfDebuffs = {}, enemyDebuffs = {}, enemyBuffs = {} },
		stats = {}, resources = {}, roster = {},
	}
end

local function AddSeconds(into, from)
	for id, seconds in pairs(from or {}) do
		into[id] = (into[id] or 0) + seconds
	end
end

-- Two fights' shared member stats as one: rates weighed by each fight's
-- length, damage added up.
local function MergeShared(a, aSeconds, b, bSeconds)
	if not a then
		return b
	elseif not b then
		return a
	end
	local total = zo_max(aSeconds + bSeconds, 0.1)
	local merged = {}
	for _, field in ipairs({ "dps", "bossDps", "hps", "rawHps" }) do
		if a[field] or b[field] then
			merged[field] = ((a[field] or 0) * aSeconds + (b[field] or 0) * bSeconds) / total
		end
	end
	if a.damage or b.damage then
		merged.damage = (a.damage or 0) + (b.damage or 0)
	end
	return merged
end

-- Adds `from` into `into` (creating it when nil) and returns it: seconds, skill
-- counters, effect seconds, time-weighted stats, resources, targets and group
-- members all sum.
function KPUI_FIGHT_TALLY.Merge(into, from)
	if type(from) ~= "table" then
		return into
	end
	into = into or NewDetail()
	-- What happened when, in a later fight, is placed after the earlier ones.
	local offsetSeconds = into.seconds
	into.seconds = into.seconds + (from.seconds or 0)
	into.critMastery = into.critMastery or from.critMastery
	into.weaveSum = (into.weaveSum or 0) + (from.weaveSum or 0)
	into.weaveCount = (into.weaveCount or 0) + (from.weaveCount or 0)
	into.offense = MergeOffense(into.offense or {}, from.offense)
	if from.prep then
		-- The latest fight's preparation stands for the match, potions add up.
		local potions = {}
		for _, entry in ipairs(into.prep and into.prep.potions or {}) do
			potions[entry.link] = (potions[entry.link] or 0) + entry.count
		end
		for _, entry in ipairs(from.prep.potions or {}) do
			potions[entry.link] = (potions[entry.link] or 0) + entry.count
		end
		local list = {}
		for link, count in pairs(potions) do
			list[#list + 1] = { link = link, count = count }
		end
		table.sort(list, function(a, b)
			return a.link < b.link
		end)
		into.prep = { mundus = from.prep.mundus, food = from.prep.food, foodKnown = from.prep.foodKnown, potions = list }
	end
	into.idleSeconds = (into.idleSeconds or 0) + (from.idleSeconds or 0)
	into.ultimateCasts = (into.ultimateCasts or 0) + (from.ultimateCasts or 0)
	if (from.peakBurst or 0) > (into.peakBurst or 0) then
		into.peakBurst = from.peakBurst
		into.peakAt = (from.peakAt or 0) + offsetSeconds
	end
	into.resourceTime = into.resourceTime or {}
	for powerType, entry in pairs(from.resourceTime or {}) do
		local target = into.resourceTime[powerType] or { low = 0, total = 0 }
		target.low = target.low + entry.low
		target.total = target.total + entry.total
		into.resourceTime[powerType] = target
	end
	into.bars = into.bars or {}
	for bar, stats in pairs(from.bars or {}) do
		local target = into.bars[bar]
		if not target then
			target = { seconds = 0, damage = 0, skills = 0, attacks = 0, errors = 0, weaveSum = 0, weaveCount = 0 }
			into.bars[bar] = target
		end
		AddNumbers(target, stats, { "seconds", "damage", "skills", "attacks", "errors", "weaveSum", "weaveCount" })
	end
	into.deaths = into.deaths or {}
	for _, death in ipairs(from.deaths or {}) do
		if #into.deaths < MAX_DEATHS then
			into.deaths[#into.deaths + 1] = { t = death.t + offsetSeconds, name = death.name, state = death.state, ability = death.ability }
		end
	end
	into.timeline = into.timeline or { step = TIMELINE_STEP, n = 0, damage = {}, healing = {}, taken = {}, boss = {} }
	local before = into.timeline.n or 0
	for index = 1, zo_min(from.timeline and from.timeline.n or 0, MAX_TIMELINE_BUCKETS - before) do
		for _, key in ipairs({ "damage", "healing", "taken", "boss" }) do
			into.timeline[key][before + index] = from.timeline[key] and from.timeline[key][index] or nil
		end
		into.timeline.n = before + index
	end
	into.yourHealing = into.yourHealing or {}
	for name, entry in pairs(from.yourHealing or {}) do
		local target = into.yourHealing[name] or { heal = 0, over = 0 }
		target.heal = target.heal + entry.heal
		target.over = target.over + entry.over
		into.yourHealing[name] = target
	end
	into.groupTaken = into.groupTaken or {}
	AddSkillMap(into.groupTaken, from.groupTaken)
	into.takenBy = into.takenBy or {}
	for name, amount in pairs(from.takenBy or {}) do
		into.takenBy[name] = (into.takenBy[name] or 0) + amount
	end
	into.mitigation = into.mitigation or { hits = 0, damage = 0, blockedHits = 0, blockedDamage = 0, shielded = 0, dodges = 0 }
	for field, value in pairs(from.mitigation or {}) do
		into.mitigation[field] = (into.mitigation[field] or 0) + value
	end
	into.wrathCP = into.wrathCP or from.wrathCP
	into.memberBuffs = into.memberBuffs or {}
	for name, list in pairs(from.memberBuffs or {}) do
		into.memberBuffs[name] = into.memberBuffs[name] or {}
		AddSeconds(into.memberBuffs[name], list)
	end
	into.memberSets = into.memberSets or {}
	for name, ids in pairs(from.memberSets or {}) do
		local seen = {}
		local merged = into.memberSets[name] or {}
		for _, setId in ipairs(merged) do
			seen[setId] = true
		end
		for _, setId in ipairs(ids) do
			if not seen[setId] then
				seen[setId] = true
				merged[#merged + 1] = setId
			end
		end
		table.sort(merged)
		into.memberSets[name] = merged
	end
	AddSkillMap(into.skills, from.skills)
	into.healSkills = into.healSkills or {}
	into.takenSkills = into.takenSkills or {}
	into.targets = into.targets or {}
	AddSkillMap(into.healSkills, from.healSkills)
	AddSkillMap(into.takenSkills, from.takenSkills)
	for name, list in pairs(from.effects or {}) do
		local target = into.effects[name]
		if target then
			AddSeconds(target, list)
		end
	end
	for statId, stat in pairs(from.stats or {}) do
		local target = into.stats[statId]
		if not target then
			into.stats[statId] = { sum = stat.sum, max = stat.max }
		else
			target.sum = target.sum + stat.sum
			target.max = zo_max(target.max, stat.max)
		end
	end
	-- Targets are matched by name; only the best few stay.
	local byName = {}
	for _, target in ipairs(into.targets) do
		byName[target.name] = target
	end
	for _, entry in ipairs(from.targets or {}) do
		local target = byName[entry.name]
		if not target then
			target = { name = entry.name, damage = 0, you = 0, seconds = 0, skills = {}, debuffs = {}, offense = {} }
			byName[entry.name] = target
			into.targets[#into.targets + 1] = target
		end
		target.damage = target.damage + entry.damage
		target.you = target.you + entry.you
		target.seconds = target.seconds + entry.seconds
		if entry.group then
			target.group = (target.group or 0) + entry.group
		end
		AddSkillMap(target.skills, entry.skills)
		AddSeconds(target.debuffs, entry.debuffs)
		target.offense = MergeOffense(target.offense or {}, entry.offense)
	end
	table.sort(into.targets, function(a, b)
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.name < b.name
	end)
	for index = #into.targets, MAX_TARGETS + 1, -1 do
		into.targets[index] = nil
	end
	-- Everyone who was in the group for any fight of the match. The latest
	-- fight's details stand; shared stats and time add up.
	into.roster = into.roster or {}
	for name, info in pairs(from.roster or {}) do
		local before = into.roster[name]
		local merged = {}
		for key, value in pairs(info) do
			merged[key] = value
		end
		if before then
			merged.skillLines = info.skillLines or before.skillLines
			merged.shared = MergeShared(before.shared, before.seconds or 0, info.shared, info.seconds or 0)
			merged.seconds = (before.seconds or 0) + (info.seconds or 0)
		end
		into.roster[name] = merged
	end
	for powerType, resource in pairs(from.resources or {}) do
		local target = into.resources[powerType]
		if not target then
			into.resources[powerType] = { gain = resource.gain, drain = resource.drain }
		else
			target.gain = target.gain + resource.gain
			target.drain = target.drain + resource.drain
		end
	end
	return into
end
