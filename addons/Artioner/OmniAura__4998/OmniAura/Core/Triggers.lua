-- Tipos de trigger. Cada tipo implementa:
--   Prepare(trig, rt)          precalcula datos de runtime (rt) a partir de la config guardada (trig)
--   Register(trig, rt, ns)     opcional: registra eventos usando el namespace ns
--   Unregister(rt)             opcional: deshace Register
--   Check(trig, rt, ctx)       devuelve active, state
-- "state" es lo que consume el display: name, icon, expires, duration, stacks, value, max, percent, progress, missing.

local OA = OmniAura
local U = OA.Utils
local T = { types = {} }
OA.Triggers = T

local DEFAULT_ICON = "/esoui/art/icons/icon_missing.dds"

---------------------------------------------------------------------------
-- Contexto por tick: cachea el escaneo de buffs de cada unidad.
---------------------------------------------------------------------------
local Context = {}
Context.__index = Context

function T.NewContext(now)
    return setmetatable({ now = now, buffs = {} }, Context)
end

function Context:GetBuffs(unit)
    local list = self.buffs[unit]
    if list then return list end
    list = {}
    if DoesUnitExist(unit) then
        for i = 1, GetNumBuffs(unit) do
            local name, started, ending, _, stacks, icon, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unit, i)
            if name then
                local fname = U.FormatName(name)
                list[#list + 1] = {
                    name = fname,
                    lname = zo_strlower(fname),
                    started = started or 0,
                    ending = ending or 0,
                    stacks = stacks or 0,
                    icon = U.NonEmpty(icon),
                    abilityId = abilityId,
                    mine = castByPlayer,
                }
            end
        end
    end
    self.buffs[unit] = list
    return list
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- spells puede mezclar IDs (número) y nombres (texto, sin distinguir mayúsculas).
local function BuildMatcher(spells, rt, spellIcons)
    rt.ids, rt.names = {}, {}
    if type(spells) ~= "table" then spells = { spells } end
    for _, s in ipairs(spells) do
        if type(s) == "number" then
            rt.ids[s] = true
            rt.icon = rt.icon or U.AbilityIcon(s)
            rt.label = rt.label or U.AbilityName(s)
        elseif type(s) == "string" and s ~= "" then
            local lname = zo_strlower(s)
            rt.names[lname] = true
            rt.icon = rt.icon or (spellIcons and spellIcons[lname])
            rt.label = rt.label or s
        end
    end
    rt.icon = rt.icon or DEFAULT_ICON
    rt.label = rt.label or "?"
end

local COMPARE = {
    ["<"] = function(a, b) return a < b end,
    ["<="] = function(a, b) return a <= b end,
    [">"] = function(a, b) return a > b end,
    [">="] = function(a, b) return a >= b end,
    ["="] = function(a, b) return a == b end,
    ["~="] = function(a, b) return a ~= b end,
}
T.COMPARE = COMPARE

---------------------------------------------------------------------------
-- buff: buff/debuff presente (o ausente) en una unidad
--   unit = "player" | "reticleover" | "boss1"...   spells = {id|nombre, ...}
--   onlyMine = bool   show = "active" | "missing"   minStacks = n
---------------------------------------------------------------------------
T.types.buff = {
    Prepare = function(trig, rt)
        BuildMatcher(trig.spells, rt, trig.spellIcons)
    end,

    Check = function(trig, rt, ctx)
        local unit = trig.unit or "player"
        if unit ~= "player" and not DoesUnitExist(unit) then return false end

        local best
        for _, b in ipairs(ctx:GetBuffs(unit)) do
            if (rt.ids[b.abilityId] or rt.names[b.lname]) and (not trig.onlyMine or b.mine) then
                if not best or b.ending > best.ending then best = b end
            end
        end
        if best and trig.minStacks and best.stacks < trig.minStacks then best = nil end

        if trig.show == "missing" then
            if best then return false end
            return true, { name = rt.label, icon = rt.icon, missing = true }
        end

        if not best then return false end
        local state = { name = best.name, icon = best.icon or rt.icon, stacks = best.stacks }
        local duration = best.ending - best.started
        if duration > 0 then
            state.expires = best.ending
            state.duration = duration
        end
        return true, state
    end,
}

---------------------------------------------------------------------------
-- slot: acumulaciones y tiempo que el juego muestra sobre una habilidad de tus
-- barras (p. ej. Latigazo ardiente → Azote poderoso). No siempre hay un buff
-- visible con esas acumulaciones, así que se leen del propio hueco.
--   spells = {id|nombre, ...}   minStacks = n
---------------------------------------------------------------------------
local SLOT_BARS = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }

local function SlotMatches(rt, id, bar)
    if rt.ids[id] or rt.names[zo_strlower(U.AbilityName(id))] then return true end
    -- La habilidad puede transformarse en el hueco (Latigazo ardiente → Azote poderoso).
    local eff = GetEffectiveAbilityIdForAbilityOnHotbar(id, bar)
    if eff ~= id and eff > 0 then
        return rt.ids[eff] or rt.names[zo_strlower(U.AbilityName(eff))]
    end
    return false
end

T.types.slot = {
    Prepare = function(trig, rt)
        BuildMatcher(trig.spells, rt, trig.spellIcons)
    end,

    Check = function(trig, rt, ctx)
        local best
        for _, bar in ipairs(SLOT_BARS) do
            for slot = 3, 8 do
                local id = GetSlotBoundId(slot, bar)
                if id and id > 0 and SlotMatches(rt, id, bar) then
                    local stacks = GetActionSlotEffectStackCount(slot, bar) or 0
                    local remaining = (GetActionSlotEffectTimeRemaining(slot, bar) or 0) / 1000
                    if stacks > 0 or remaining > 0 then
                        if not best or stacks > best.stacks or (stacks == best.stacks and remaining > best.remaining) then
                            best = { slot = slot, bar = bar, stacks = stacks, remaining = remaining }
                        end
                    end
                end
            end
        end
        if not best then return false end
        if trig.minStacks and best.stacks < trig.minStacks then return false end

        local state = {
            name = U.NonEmpty(U.FormatName(GetSlotName(best.slot, best.bar))) or rt.label,
            icon = U.NonEmpty(GetSlotTexture(best.slot, best.bar)) or rt.icon,
            stacks = best.stacks,
        }
        local duration = (GetActionSlotEffectDuration(best.slot, best.bar) or 0) / 1000
        if best.remaining > 0 and duration > 0 then
            state.expires = ctx.now + best.remaining
            state.duration = duration
        end
        return true, state
    end,
}

---------------------------------------------------------------------------
-- resource: salud/magia/aguante/definitiva comparada con un umbral
--   unit, power = "health"|"magicka"|"stamina"|"ultimate", op = "<"|">"..., value = n, percent = bool
---------------------------------------------------------------------------
local POWER = {
    health = COMBAT_MECHANIC_FLAGS_HEALTH,
    magicka = COMBAT_MECHANIC_FLAGS_MAGICKA,
    stamina = COMBAT_MECHANIC_FLAGS_STAMINA,
    ultimate = COMBAT_MECHANIC_FLAGS_ULTIMATE,
}
local L = OA.L
local POWER_LABEL = { health = L.POWER_HEALTH, magicka = L.POWER_MAGICKA, stamina = L.POWER_STAMINA, ultimate = L.POWER_ULTIMATE }
T.POWER_LABEL = POWER_LABEL
T.POWER = POWER

T.types.resource = {
    Prepare = function(trig, rt)
        local power = trig.power or "health"
        rt.ptype = POWER[power]
        rt.label = POWER_LABEL[power] or power
        rt.icon = DEFAULT_ICON
        rt.compare = COMPARE[trig.op or "<"]
    end,

    Check = function(trig, rt, ctx)
        local unit = trig.unit or "player"
        if not rt.ptype or not rt.compare or not DoesUnitExist(unit) then return false end
        local cur, max = GetUnitPower(unit, rt.ptype)
        if not cur or not max or max <= 0 then return false end
        local pct = cur / max
        local lhs = trig.percent and (pct * 100) or cur
        if not rt.compare(lhs, tonumber(trig.value) or 0) then return false end
        return true, { name = rt.label, icon = rt.icon, value = cur, max = max, percent = pct, progress = pct }
    end,
}

---------------------------------------------------------------------------
-- combat: dentro / fuera de combate.  state = "in" | "out"
---------------------------------------------------------------------------
T.types.combat = {
    Check = function(trig, rt, ctx)
        local wantOut = trig.state == "out"
        local inCombat = IsUnitInCombat("player")
        if inCombat == wantOut then return false end
        return true, { name = wantOut and OA.L.OUT_OF_COMBAT or OA.L.IN_COMBAT }
    end,
}

---------------------------------------------------------------------------
-- proc: un evento de combate con cierta habilidad muestra el aura N segundos.
-- Útil para procs de sets y cooldowns internos que no dejan buff visible.
--   spells = {abilityId, ...}  duration = segundos  source = "player"|"any"  refresh = bool
---------------------------------------------------------------------------
T.types.proc = {
    Prepare = function(trig, rt)
        BuildMatcher(trig.spells, rt, trig.spellIcons)
    end,

    Register = function(trig, rt, ns)
        rt.namespaces = {}
        local duration = tonumber(trig.duration) or 10

        local function OnCombatEvent(_, result, isError, abilityName, abilityGraphic, actionSlotType,
                                     sourceName, sourceType, targetName, targetType, hitValue, powerType,
                                     damageType, log, sourceUnitId, targetUnitId, abilityId)
            local now = GetFrameTimeSeconds()
            if rt.expires and rt.expires > now and not trig.refresh then return end
            rt.expires = now + duration
            rt.duration = duration
            rt.procName = U.NonEmpty(U.FormatName(abilityName))
        end

        for abilityId in pairs(rt.ids) do
            local name = ns .. "_" .. abilityId
            EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnCombatEvent)
            if trig.source == "any" then
                EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_ABILITY_ID, abilityId,
                    REGISTER_FILTER_IS_ERROR, false)
            else
                EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
                    REGISTER_FILTER_ABILITY_ID, abilityId,
                    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                    REGISTER_FILTER_IS_ERROR, false)
            end
            rt.namespaces[#rt.namespaces + 1] = name
        end
    end,

    Unregister = function(rt)
        for _, name in ipairs(rt.namespaces or {}) do
            EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        end
        rt.namespaces = nil
    end,

    Check = function(trig, rt, ctx)
        if not rt.expires or rt.expires <= ctx.now then return false end
        return true, { name = rt.procName or rt.label, icon = rt.icon, expires = rt.expires, duration = rt.duration }
    end,
}
