-- One encounter clock for all-target, boss and non-boss DPS.
-- Live and finalized DPS use the same window ending at the last damage event.
-- UI refreshes continue between hits without inventing extra damage time.
-- Damage uses effective hitValue; overkill is not added to the total.
local meter = {}
SimpleGroupDPS_DamageMeter = meter
local state
local last = { total = 0, dps = 0, durationMS = 0 }
local pending = {}
local results = {}
for _, name in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE",
    "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL",
    "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
    "ACTION_RESULT_PRECISE_DAMAGE", "ACTION_RESULT_WRECKING_DAMAGE" }) do
    if _G[name] ~= nil then results[_G[name]] = true end
end

local function isType(value, name)
    return _G[name] ~= nil and value == _G[name]
end

local function isPersonal(value)
    return isType(value, "COMBAT_UNIT_TYPE_PLAYER") or isType(value, "COMBAT_UNIT_TYPE_PLAYER_PET")
        or isType(value, "COMBAT_UNIT_TYPE_PLAYER_COMPANION")
end

local function isFriendly(value)
    return isPersonal(value) or isType(value, "COMBAT_UNIT_TYPE_GROUP")
        or isType(value, "COMBAT_UNIT_TYPE_GROUP_PET")
end

local function normalizeName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if zo_strformat then name = zo_strformat(_G.SI_UNIT_NAME or "<<1>>", name) end
    name = zo_strlower and zo_strlower(name) or string.lower(name)
    return name:match("^%s*(.-)%s*$")
end

local function isBossTarget(target)
    return state.bossIds[target.id] or (state.bossNames[target.name] and not state.confirmedNames[target.name])
end

function meter:RefreshBosses()
    if not state then return end
    for i = 1, (_G.MAX_BOSSES or _G.BOSS_RANK_ITERATION_END or 12) do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = normalizeName(GetRawUnitName and GetRawUnitName(tag) or GetUnitName(tag))
            if name and name ~= "" then state.bossNames[name] = true end
        end
    end
end

function meter:CorrelateBoss(tag, id, name)
    if not state or type(tag) ~= "string" or not tag:match("^boss%d+$") or not id or id == 0 then return end
    state.bossIds[id] = true
    name = normalizeName(name)
    if name and name ~= "" then
        state.bossNames[name] = true
        state.confirmedNames[name] = true
    end
end

local function accumulate(event)
    local key = event.id and event.id ~= 0 and event.id or ("name:" .. (event.name or ""))
    if event.outgoing then state.observedTargets[key] = { id = event.id, name = event.name } end
    if not event.personal then return end
    local target = state.targets[key]
    if not target then
        target = { id = event.id, name = event.name, total = 0 }
        state.targets[key] = target
    end
    target.total = target.total + event.value
    state.total = state.total + event.value
end

function meter:Start(timeMS)
    if state then return end
    state = { startMS = timeMS, endMS = timeMS, total = 0, targets = {},
        observedTargets = {}, bossIds = {}, bossNames = {}, confirmedNames = {} }
    self:RefreshBosses()
    for _, event in ipairs(pending) do
        if event.time >= timeMS - 1000 then accumulate(event) end
    end
    pending = {}
    if SimpleGroupDPS_BattleScrolls then SimpleGroupDPS_BattleScrolls:Clear() end
end

function meter:IsActive() return state ~= nil end

function meter:GetStats(finalizing)
    if not state then return last end
    local endMS = state.endMS
    local durationMS = math.max(0, endMS - state.startMS)
    local bossTotal
    local hasBoss = false
    for _, target in pairs(state.observedTargets) do
        if isBossTarget(target) then hasBoss = true; break end
    end
    if hasBoss then
        bossTotal = 0
        for _, target in pairs(state.targets) do
            if isBossTarget(target) then
                bossTotal = bossTotal + target.total
            end
        end
    end
    local scale = durationMS >= 1 and 1000 / durationMS or 0
    return {
        total = state.total, dps = state.total * scale, durationMS = durationMS,
        bossTotal = bossTotal, bossDPS = bossTotal and bossTotal * scale,
        addsDPS = bossTotal and math.max(0, state.total - bossTotal) * scale,
    }
end

function meter:Finish()
    if not state then return end
    last = self:GetStats(true)
    state = nil
    if self.onFinished then self.onFinished(last) end
end

function meter:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId)
    hitValue = tonumber(hitValue)
    if isError or not results[result] or not hitValue or hitValue <= 0
        or hitValue ~= hitValue or hitValue == math.huge then return end
    if isFriendly(sourceType) and isFriendly(targetType) then return end
    local timeMS = GetGameTimeMilliseconds()
    local event = { time = timeMS, name = normalizeName(targetName), id = targetId, value = hitValue,
        outgoing = isFriendly(sourceType) and not isFriendly(targetType),
        personal = isPersonal(sourceType) and not isFriendly(targetType) }
    if not state then
        if IsUnitInCombat("player") then
            self:Start(timeMS)
        else
            local recent = {}
            for _, previous in ipairs(pending) do
                if previous.time >= timeMS - 1000 then recent[#recent + 1] = previous end
            end
            if event.personal then recent[#recent + 1] = event end
            pending = recent
            return
        end
    end
    state.endMS = math.max(state.endMS, timeMS)
    accumulate(event)
end

function meter:Initialize(saved)
    if type(saved) == "table" then
        last = { total = tonumber(saved.damageTotal) or 0, dps = tonumber(saved.dps) or 0,
            bossTotal = tonumber(saved.bossDamageTotal), bossDPS = tonumber(saved.bossDPS),
            addsDPS = tonumber(saved.addsDPS), durationMS = tonumber(saved.damageDurationMS or saved.durationMS) or 0 }
    end
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamage", EVENT_COMBAT_EVENT,
        function(_, result, isError, _, _, _, _, sourceType, targetName, targetType, hitValue, _, _, _, _, targetId)
            self:OnDamage(result, isError, sourceType, targetName, targetType, hitValue, targetId)
        end)
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if inCombat then self:Start(GetGameTimeMilliseconds()) else self:Finish() end
    end)
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageBosses", EVENT_BOSSES_CHANGED, function() self:RefreshBosses() end)
    EVENT_MANAGER:RegisterForEvent("SimpleGroupDPSDamageEffects", EVENT_EFFECT_CHANGED,
        function(_, changeType, _, _, tag, _, _, _, _, _, _, _, _, name, id)
            if changeType ~= _G.EFFECT_RESULT_FADED then self:CorrelateBoss(tag, id, name) end
        end)
end
