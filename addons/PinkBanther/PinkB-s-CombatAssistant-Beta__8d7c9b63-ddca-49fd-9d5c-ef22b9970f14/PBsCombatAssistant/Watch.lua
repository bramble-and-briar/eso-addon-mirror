-- What is going on in the game: the player's Resolve buffs and health, and when they are worth a word from Ember.
-- It only decides; Ember.lua (A:Raise / A:Settle / A:Withdraw) does the showing.
--
-- ---------------------------------------------------------------------------------------
-- RESOLVE AND BRUTALITY
-- ---------------------------------------------------------------------------------------
--
-- Every effect on the player is seen through EVENT_EFFECT_CHANGED (filtered to the player). The ones whose name
-- says Major or Minor Resolve, or Major Brutality (A.BuffKind) are kept with their end time: gained and refreshed set it, faded
-- removes it. A scan of GetUnitBuffInfo("player", i) at the start of a fight and after a loading screen picks
-- up what is already there. Effects with no end (end time not after the start) are permanent and never
-- "about to run out".
--
-- A kind is ARMED at first. When its remaining time falls to the set number of seconds (and it is still
-- running), Ember is told once and the kind is disarmed, so one running-out gives one alert. It is armed again
-- when the buff is longer than that plus a margin (it was refreshed) or is gone. If the buff ends while she
-- is talking about it she says it ran out; if it is refreshed she is relieved.
--
-- ---------------------------------------------------------------------------------------
-- HEALTH
-- ---------------------------------------------------------------------------------------
--
-- The share of health is value / effective maximum, from EVENT_POWER_UPDATE and GetUnitPower. Below the first
-- level (default 70 %) she worries; below the second (default 35 %) she panics, and that replaces the first.
-- Each is armed again once health is HP_MARGIN points above its level, so health hovering around a level does
-- not make her appear and leave over and over. Dead, nothing is said.
--
-- ---------------------------------------------------------------------------------------
-- WHEN
-- ---------------------------------------------------------------------------------------
--
-- With "only while in combat" the check runs every CHECK_MS ms from the start of a fight to its end (the
-- end also clears everything and arms everything again). Without it the check runs always.
-- The effect and health events themselves are cheap and are always followed, so the state is current when a
-- fight begins.

local A = PBS_COMBAT_ASSISTANT
local em = EVENT_MANAGER

local BUFF_KINDS = { "major", "minor", "brutal" } -- the effects followed; each has a switch of the same name
local CHECK_MS = 250
local REARM_MARGIN_S = 0.8 -- seconds above the limit before a refreshed buff is armed again
local HP_MARGIN = 10 -- points above a level before it is armed again
local CACHE_MAX = 300 -- names remembered at most; every effect the player ever gets is a new id, so it is emptied when full
local NS_EFFECT = A.name .. "Effect"
local NS_POWER = A.name .. "Power"
local NS_STATE = A.name .. "State"
local NS_CHECK = A.name .. "Check"

local watch = {
	inCombat = false,
	dead = false,
	buffs = {}, -- abilityId -> { kind, name, begin, finish }
	armed = { major = true, minor = true, brutal = true, hp = true, danger = true },
	hp = nil, -- share of health, 0..100
	checking = false,
	cache = {}, -- abilityId -> kind or false: the answer of A.BuffKind for that effect's name
	cacheSize = 0,
	cacheResets = 0,
	said = { major = {}, minor = {}, brutal = {}, hp = {}, danger = {} }, -- kind -> the data table handed to A:Raise, filled again each time
	-- counted for /pbca status
	effects = 0,
	recognised = 0,
	fired = { major = 0, minor = 0, brutal = 0, hp = 0, danger = 0 },
	lastName = {}, -- kind -> the name it was recognised under
}
A.watch = watch

local function Kind(abilityId, name)
	local cached = watch.cache[abilityId]
	if cached ~= nil then
		return cached or nil
	end
	local kind = A.BuffKind(name)
	if abilityId ~= nil then
		if watch.cacheSize >= CACHE_MAX then
			watch.cache = {}
			watch.cacheSize = 0
			watch.cacheResets = watch.cacheResets + 1
		end
		watch.cache[abilityId] = kind or false
		watch.cacheSize = watch.cacheSize + 1
	end
	return kind
end

-- ---------------------------------------------------------------------------------------
-- Buffs
-- ---------------------------------------------------------------------------------------

local function Remember(kind, abilityId, name, begin, finish)
	if abilityId == nil then
		return
	end
	local buff = watch.buffs[abilityId]
	if not buff then
		buff = {}
		watch.buffs[abilityId] = buff
	end
	buff.kind, buff.name, buff.begin, buff.finish = kind, name, begin, finish
	watch.lastName[kind] = name
end

-- What a reason says, in the kind's own table (a check four times a second makes no new one).
local function Said(kind, name, endTime, pct)
	local data = watch.said[kind]
	data.name, data.endTime, data.pct = name, endTime, pct
	return data
end

-- Reads everything the player has now.
function A:ScanBuffs()
	watch.buffs = {}
	if not (GetNumBuffs and GetUnitBuffInfo) then
		return 0
	end
	local count = 0
	for index = 1, GetNumBuffs("player") do
		local name, started, finish, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)
		local kind = Kind(abilityId, name)
		if kind then
			Remember(kind, abilityId, name, started, finish)
			count = count + 1
		end
	end
	return count
end

-- (eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType,
--  effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
local function OnEffectChanged(_, changeType, _, effectName, _, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
	watch.effects = watch.effects + 1
	local kind = Kind(abilityId, effectName)
	if not kind then
		return
	end
	watch.recognised = watch.recognised + 1
	if changeType == EFFECT_RESULT_FADED then
		watch.buffs[abilityId] = nil
		A:WatchBuffGone(kind)
		return
	end
	Remember(kind, abilityId, effectName, beginTime, endTime)
end

-- The latest end time of the effects of a kind, or nil when none is running.
local function EndOf(kind, now)
	local best
	for _, buff in pairs(watch.buffs) do
		if buff.kind == kind then
			local finish = buff.finish
			-- no end (not after the start) = permanent: it never runs out
			if finish and buff.begin and finish > buff.begin and (not best or finish > best) then
				best = finish
			end
		end
	end
	return best
end

-- Seconds the buff of a kind has left: nil when none is running, math.huge when one has no end (the tiles).
function A:BuffLeft(kind, now)
	local best
	for _, buff in pairs(watch.buffs) do
		if buff.kind == kind then
			local finish = buff.finish
			if not (finish and buff.begin and finish > buff.begin) then
				return math.huge
			end
			if not best or finish > best then
				best = finish
			end
		end
	end
	return best and (best - now) or nil
end

local function NameOfKind(kind)
	return watch.lastName[kind]
end

-- A buff of this kind is gone (faded): if she was talking about it, it ran out.
function A:WatchBuffGone(kind)
	for _, other in pairs(watch.buffs) do
		if other.kind == kind then
			return -- another effect of the same kind is still running
		end
	end
	if self:ReasonState(kind) == "active" then
		self:Settle(kind, "lost")
	end
	watch.armed[kind] = true
end

-- the setting holding each buff's "about to run out" seconds (a fixed table: no string built per check)
local SECONDS_KEY = { major = "majorSeconds", minor = "minorSeconds", brutal = "brutalSeconds" }

local function CheckResolve(kind, now)
	local sv = A.sv
	local enabled = sv[kind] -- the switches are named like the kinds
	if not enabled then
		if A:ReasonState(kind) == "active" then
			A:Withdraw(kind)
		end
		return
	end
	local finish = EndOf(kind, now)
	if not finish then
		return
	end
	local left = finish - now
	local limit = sv[SECONDS_KEY[kind]] or 3
	if left <= 0 then
		-- it has run out and the fade has not arrived yet: the same as a fade
		if A:ReasonState(kind) == "active" then
			A:Settle(kind, "lost")
		end
		return
	end
	if left <= limit then
		if watch.armed[kind] then
			watch.armed[kind] = false
			watch.fired[kind] = watch.fired[kind] + 1
			A:Raise(kind, Said(kind, NameOfKind(kind), finish))
		elseif A:ReasonState(kind) == "active" then
			A:Raise(kind, Said(kind, NameOfKind(kind), finish))
		end
	elseif left > limit + REARM_MARGIN_S then
		-- refreshed
		if A:ReasonState(kind) == "active" then
			A:Settle(kind, "relief")
		end
		watch.armed[kind] = true
	end
end

-- ---------------------------------------------------------------------------------------
-- Health
-- ---------------------------------------------------------------------------------------

local function ReadHealth()
	if not (GetUnitPower and COMBAT_MECHANIC_FLAGS_HEALTH) then
		return nil
	end
	local value, max, effective = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
	local top = (type(effective) == "number" and effective > 0) and effective or max
	if type(value) ~= "number" or type(top) ~= "number" or top <= 0 then
		return nil
	end
	return 100 * value / top
end

local function CheckHealth()
	local sv = A.sv
	local pct = watch.hp
	if not pct then
		return
	end
	if not sv.hp or watch.dead then
		return
	end
	local shown = math.floor(pct + 0.5)
	local danger = sv.hpDanger
	-- the more urgent level
	if danger > 0 then
		if pct < danger and watch.armed.danger then
			watch.armed.danger = false
			watch.armed.hp = false
			watch.fired.danger = watch.fired.danger + 1
			A:Withdraw("hp")
			A:Raise("danger", Said("danger", nil, nil, shown))
		elseif A:ReasonState("danger") == "active" then
			if pct >= danger + HP_MARGIN then
				A:Settle("danger", "relief")
				watch.armed.danger = true
			else
				A:Raise("danger", Said("danger", nil, nil, shown))
			end
		elseif pct >= danger + HP_MARGIN then
			watch.armed.danger = true
		end
	end
	-- the first level
	if pct < sv.hpWarn and watch.armed.hp and A:ReasonState("danger") ~= "active" then
		watch.armed.hp = false
		watch.fired.hp = watch.fired.hp + 1
		A:Raise("hp", Said("hp", nil, nil, shown))
	elseif A:ReasonState("hp") == "active" then
		if pct >= sv.hpWarn + HP_MARGIN then
			A:Settle("hp", "relief")
			watch.armed.hp = true
		elseif A:ReasonState("danger") ~= "active" then
			A:Raise("hp", Said("hp", nil, nil, shown))
		end
	elseif pct >= sv.hpWarn + HP_MARGIN then
		watch.armed.hp = true
	end
end

-- (eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
local function OnPower(_, _, _, _, value, max, effective)
	local top = (type(effective) == "number" and effective > 0) and effective or max
	if type(value) == "number" and type(top) == "number" and top > 0 then
		watch.hp = 100 * value / top
		if A.sv and A.sv.enabled and (watch.inCombat or not A.sv.combatOnly) then
			CheckHealth()
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- The check
-- ---------------------------------------------------------------------------------------

function A:WatchCheck()
	local sv = self.sv
	if not sv.enabled or watch.dead then
		return
	end
	if sv.combatOnly and not watch.inCombat then
		return
	end
	local now = A.Now()
	for _, kind in ipairs(BUFF_KINDS) do
		CheckResolve(kind, now)
	end
	CheckHealth()
end

local function SafeCheck()
	local ok, err = pcall(A.WatchCheck, A)
	if not ok then
		A.errors = A.errors + 1
		A.lastError = "check: " .. tostring(err)
	end
end

-- The periodic check runs in a fight, or always when "only in combat" is off.
function A:WatchUpdateState()
	local want = self.sv and self.sv.enabled and (watch.inCombat or not self.sv.combatOnly)
	if want and not watch.checking then
		watch.checking = true
		em:RegisterForUpdate(NS_CHECK, CHECK_MS, SafeCheck)
	elseif not want and watch.checking then
		watch.checking = false
		em:UnregisterForUpdate(NS_CHECK)
	end
end

local function Rearm()
	for key in pairs(watch.armed) do
		watch.armed[key] = true
	end
end

local function OnCombatState(_, inCombat)
	watch.inCombat = inCombat and true or false
	if watch.inCombat then
		Rearm()
		A:ScanBuffs()
		watch.hp = ReadHealth() or watch.hp
	else
		-- the fight is over: she leaves (unless she is allowed outside fights), and everything is armed again
		if A.sv.combatOnly then
			A:ClearReasons()
		end
		Rearm()
	end
	A:WatchUpdateState()
	A:TilesUpdateState()
end

local function OnDead()
	watch.dead = true
	A:ClearReasons()
	A:TilesUpdateState()
end

local function OnAlive()
	watch.dead = false
	Rearm()
	watch.hp = ReadHealth() or watch.hp
	A:TilesUpdateState()
end

-- After a loading screen: read everything again.
function A:WatchSync()
	watch.inCombat = IsUnitInCombat and IsUnitInCombat("player") and true or false
	watch.dead = IsUnitDead and IsUnitDead("player") and true or false
	self:ScanBuffs()
	watch.hp = ReadHealth()
	Rearm()
	self:WatchUpdateState()
	self:TilesUpdateState()
end

-- ---------------------------------------------------------------------------------------
-- Starting and stopping
-- ---------------------------------------------------------------------------------------

function A:InitWatch()
	em:RegisterForEvent(NS_EFFECT, EVENT_EFFECT_CHANGED, A.Guard(OnEffectChanged))
	em:AddFilterForEvent(NS_EFFECT, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
	em:RegisterForEvent(NS_POWER, EVENT_POWER_UPDATE, A.Guard(OnPower))
	em:AddFilterForEvent(NS_POWER, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH, REGISTER_FILTER_UNIT_TAG, "player")
	em:RegisterForEvent(NS_STATE, EVENT_PLAYER_COMBAT_STATE, A.Guard(OnCombatState))
	em:RegisterForEvent(NS_STATE .. "Dead", EVENT_PLAYER_DEAD, A.Guard(OnDead))
	em:RegisterForEvent(NS_STATE .. "Alive", EVENT_PLAYER_ALIVE, A.Guard(OnAlive))
	self:WatchSync()
end

-- ---------------------------------------------------------------------------------------
-- What the player has now, and how each was recognised (/pbca buffs)
-- ---------------------------------------------------------------------------------------

-- The game's own buff type of an effect, asked only here (it is documented but nothing in the client calls it, so
-- it is measured by this command before anything relies on it). Skipped when the game says the function is private.
local function BuffTypeOf(abilityId)
	if not GetAbilityBuffType then
		return "n/a"
	end
	if IsPrivateFunction then
		local ok, private = pcall(IsPrivateFunction, "GetAbilityBuffType")
		if not ok or private then
			return "skipped"
		end
	end
	local ok, value = pcall(GetAbilityBuffType, abilityId, "player")
	if not ok then
		return "error"
	end
	return tostring(value)
end

function A:BuffLines()
	local lines = {}
	local total = GetNumBuffs and GetNumBuffs("player") or 0
	lines[#lines + 1] = string.format(PBS_COMBAT_ASSISTANT_STRINGS.buffsHeader, total)
	if total == 0 then
		lines[#lines + 1] = PBS_COMBAT_ASSISTANT_STRINGS.buffsNone
		return lines
	end
	local now = A.Now()
	for index = 1, total do
		local name, started, finish, _, stacks, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)
		local left = (finish and started and finish > started) and string.format("%.1fs", finish - now) or "no end"
		local kind = A.BuffKind(name)
		lines[#lines + 1] = string.format("%2d  id %s  \"%s\"  %s  x%s  -> %s  (game buff type %s)", index, tostring(abilityId), tostring(name), left,
			tostring(stacks), kind or "-", BuffTypeOf(abilityId))
	end
	return lines
end

PBS_COMBAT_ASSISTANT_MARK("Watch")
