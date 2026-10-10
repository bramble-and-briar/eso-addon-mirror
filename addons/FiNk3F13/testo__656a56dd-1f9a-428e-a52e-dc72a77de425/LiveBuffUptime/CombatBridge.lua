LiveBuffUptimeCombatBridge = {}
local Bridge = LiveBuffUptimeCombatBridge

-- LibCombat2 uses dot-call registration and unified logs, unlike the PC v1 API.
function Bridge.Create(lib)
    if not lib or type(lib.RegisterForCombatEvent) ~= "function"
        or type(lib.GetUnitById) ~= "function" or type(lib.GetPlayerUnitId) ~= "function" then return nil, "LibCombat2 oder benoetigte API-Funktionen fehlen" end
    local required = { "LOG_EVENT_COMBATSTATE", "LOG_EVENT_DAMAGE", "LOG_EVENT_HEAL", "LOG_EVENT_EFFECT",
        "EVENT_FIGHTSUMMARY", "MESSAGE_COMBATSTART" }
    for _, name in ipairs(required) do if not _G["LIBCOMBAT_" .. name] then return nil, "Konstante fehlt: LIBCOMBAT_" .. name end end
    local api, callbacks, registrations = {}, {}, {}
    local status = { state = 0, damage = 0, heal = 0, effect = 0, summary = 0, dispatched = 0,
        unclassified = 0, errors = 0, registered = 0, registrationFailures = 0,
        rawEffects = 0, duplicateEffects = 0, rawUnitsOmitted = 0 }
    function api.GetStatus() return status end
    local events = { "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF",
        "EVENT_HEAL_OUT", "EVENT_HEAL_IN", "EVENT_HEAL_SELF", "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT",
        "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
    for _, name in ipairs(events) do api[name] = name end
    api.MESSAGE_COMBATSTART = LIBCOMBAT_MESSAGE_COMBATSTART
    api.name = "LibCombat2"
    local first, last
    local rawUnits, rawUnitCount = {}, 0
    local recent, recentRing, recentIndex = {}, {}, 0
    local closed = false
    function api.GetUnitType(id)
        if not id then return end
        if rawUnits[id] and rawUnits[id].unitType then return rawUnits[id].unitType end
        local unit = lib.GetUnitById(id)
        return unit and unit:GetUnitType()
    end
    api.GetPlayerUnitId = lib.GetPlayerUnitId
    if lib.GetUnitIdByTag then
        function api.GetTargetUnitId() return lib.GetUnitIdByTag("reticleover") end
    end
    local function emit(name, ...)
        if callbacks[name] then status.dispatched = status.dispatched + 1; callbacks[name](name, ...) end
    end
    local function own(id)
        local kind = api.GetUnitType(id)
        return id ~= nil and (id == lib.GetPlayerUnitId() or kind == COMBAT_UNIT_TYPE_PLAYER
            or (COMBAT_UNIT_TYPE_PLAYER_PET ~= nil and kind == COMBAT_UNIT_TYPE_PLAYER_PET))
    end
    local function action(prefix, time, result, source, target, ability, value, damageType, overflow)
        local sourceOwn, targetOwn = own(source), own(target)
        local event = sourceOwn and targetOwn and prefix .. "_SELF"
            or sourceOwn and prefix .. "_OUT" or targetOwn and prefix .. "_IN"
        if not event then status.unclassified = status.unclassified + 1; return end
        if event == "EVENT_DAMAGE_OUT" or event == "EVENT_HEAL_OUT" or event == "EVENT_HEAL_SELF" then
            first, last = math.min(first or time, time), math.max(last or time, time)
        end
        emit(event, time, result, source, target, ability, value, damageType, overflow)
    end
    local function effect(time, id, ability, change, effectType, stacks, sourceType, slot)
        if not id or not ability or not slot then return end
        -- Library and raw ESO callbacks can describe the same notification.
        -- Keep only a bounded recent window, not a growing combat log.
        local key = tostring(id) .. ":" .. tostring(ability) .. ":" .. tostring(slot)
        local previous = recent[key]
        if previous and math.abs(time - previous.time) <= 5 and previous.change == change
            and previous.stacks == stacks and previous.source == sourceType then
            status.duplicateEffects = status.duplicateEffects + 1
            return
        end
        if not previous then
            recentIndex = recentIndex % 256 + 1
            local oldKey = recentRing[recentIndex]
            if oldKey then recent[oldKey] = nil end
            recentRing[recentIndex] = key
        end
        recent[key] = { time = time, change = change, stacks = stacks, source = sourceType }
        local kind = api.GetUnitType(id)
        local event = id == lib.GetPlayerUnitId() and "EVENT_EFFECTS_IN"
            or kind == COMBAT_UNIT_TYPE_GROUP and "EVENT_GROUPEFFECTS_IN" or "EVENT_EFFECTS_OUT"
        emit(event, time, id, ability, change, effectType, stacks, sourceType, slot)
    end
    function api.RawEffect(time, id, ability, change, effectType, stacks, sourceType, slot, kind, name)
        status.rawEffects = status.rawEffects + 1
        if id and id == lib.GetPlayerUnitId() then kind = COMBAT_UNIT_TYPE_PLAYER end
        if not closed and id and kind then
            if rawUnits[id] or rawUnitCount < 256 then
                if not rawUnits[id] then rawUnitCount = rawUnitCount + 1 end
                rawUnits[id] = { unitType = kind, name = name }
            else status.rawUnitsOmitted = status.rawUnitsOmitted + 1 end
        end
        local ok, err = pcall(effect, time, id, ability, change, effectType, stacks, sourceType, slot)
        if not ok then status.errors = status.errors + 1; status.lastError = string.sub(tostring(err), 1, 400) end
    end
    local handlers = {
        LOG_EVENT_COMBATSTATE = function(_, time, message, value)
            status.state = status.state + 1
            if message == LIBCOMBAT_MESSAGE_COMBATSTART then
                first, last, closed = nil, nil, false
                rawUnits, rawUnitCount, recent, recentRing, recentIndex = {}, 0, {}, {}, 0
            end
            emit("EVENT_MESSAGES", time, message, value)
            if message == LIBCOMBAT_MESSAGE_COMBATSTART and GetNumBuffs and GetUnitBuffInfo then
                local seen = {}
                local function seed(tag, id, kind)
                    if not id or seen[id] then return end
                    seen[id] = true
                    for index = 1, GetNumBuffs(tag) do
                        local _, _, _, slot, stacks, _, _, effectType, _, _, ability, _, ownBuff = GetUnitBuffInfo(tag, index)
                        api.RawEffect(time, id, ability, EFFECT_RESULT_GAINED, effectType, math.max(1, stacks or 1),
                            ownBuff and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE, slot, kind,
                            GetUnitName and GetUnitName(tag))
                    end
                end
                seed("player", lib.GetPlayerUnitId(), COMBAT_UNIT_TYPE_PLAYER)
                if lib.GetUnitIdByTag then
                    for index = 1, math.min(GetGroupSize and GetGroupSize() or 0, 24) do
                        local tag = "group" .. index
                        seed(tag, lib.GetUnitIdByTag(tag), COMBAT_UNIT_TYPE_GROUP)
                    end
                    local target = lib.GetUnitIdByTag("reticleover")
                    seed("reticleover", target, api.GetUnitType(target))
                end
            end
        end,
        LOG_EVENT_DAMAGE = function(_, ...) status.damage = status.damage + 1; action("EVENT_DAMAGE", ...) end,
        LOG_EVENT_HEAL = function(_, ...) status.heal = status.heal + 1; action("EVENT_HEAL", ...) end,
        LOG_EVENT_EFFECT = function(_, time, id, ability, change, effectType, stacks, sourceType, slot)
            status.effect = status.effect + 1
            effect(time, id, ability, change, effectType, stacks, sourceType, slot)
        end,
        EVENT_FIGHTSUMMARY = function(_, fight)
            status.summary = status.summary + 1
            if not fight then return end
            local units = {}
            for id, unit in pairs(fight.units or {}) do
                units[id] = { unitType = unit.unitType, name = unit.name, displayname = unit.displayName }
            end
            -- v2 may omit units whose effects only arrived through the raw path.
            for id, unit in pairs(rawUnits) do
                if not units[id] then units[id] = unit end
                if unit.unitType then units[id].unitType = unit.unitType end
            end
            -- v2 info.combatStart/combatEnd are combat-state times, not active times.
            local starts, ends = first, last
            local playerId = fight.unitIds and fight.unitIds.player or lib.GetPlayerUnitId()
            local function span(data)
                if not data or not data.startTime or not data.endTime then return 0 end
                starts = math.min(starts or data.startTime, data.startTime)
                ends = math.max(ends or data.endTime, data.endTime)
                return math.max(0, data.endTime - data.startTime) / 1000
            end
            local dps = span(fight.damageDone and fight.damageDone[playerId])
            local hps = span(fight.healingDone and fight.healingDone[playerId])
            closed = true
            emit("EVENT_FIGHTSUMMARY", { starttime = starts, endtime = ends, units = units, playerid = playerId,
                dpstime = dps, hpstime = hps, activetime = starts and ends and (ends - starts) / 1000 or 0 })
        end,
    }
    function api:RegisterForCombatEvent(name, event, callback)
        callbacks[event] = callback
        local key = event == "EVENT_MESSAGES" and "LOG_EVENT_COMBATSTATE"
            or event == "EVENT_FIGHTSUMMARY" and "EVENT_FIGHTSUMMARY"
            or string.find(event, "DAMAGE") and "LOG_EVENT_DAMAGE"
            or string.find(event, "HEAL") and "LOG_EVENT_HEAL" or "LOG_EVENT_EFFECT"
        if not registrations[key] then
            local function guarded(...)
                local ok, err = pcall(handlers[key], ...)
                if not ok then status.errors = status.errors + 1; status.lastError = string.sub(tostring(err), 1, 400) end
            end
            local ok, registered = pcall(lib.RegisterForCombatEvent, name, _G["LIBCOMBAT_" .. key], guarded)
            if ok and registered ~= false then
                registrations[key] = true
                status.registered = status.registered + 1
            else
                status.registrationFailures = status.registrationFailures + 1
                status.lastError = string.sub(ok and ("Registrierung abgelehnt: " .. key) or tostring(registered), 1, 400)
            end
        end
    end
    return api
end
