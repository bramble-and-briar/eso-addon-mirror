-- Registro de combate: tu daño y tu sanación por habilidad, inicio y fin de cada
-- combate, historial y run (todos los combates desde que entras en una zona).
-- Los datos de los demás miembros del grupo los añade Core/Group.lua.

local NM = NirnhonedMetrics
local U = NM.Utils
local F = {
    history = {},   -- combates, el más reciente primero (history[1] puede estar en curso)
    active = nil,   -- combate en curso (es history[1]) o nil
    run = nil,      -- run en curso (solo con "Contar: Toda la run") o nil
}
NM.Fight = F

local EM = EVENT_MANAGER
local Now = GetGameTimeMilliseconds

local TICK_MS = 500
local TICK_UPDATE = "NirnhonedMetrics_FightTick"
local END_UPDATE = "NirnhonedMetrics_FightEnd"
F.CHANGED = "NirnhonedMetrics_FightChanged"

-- Resultados que cuentan como daño hecho (los que no existan en esta versión del juego se ignoran).
local DAMAGE_RESULTS, CRIT_RESULTS = {}, {}
for _, name in ipairs({
    "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE",
    "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL",
    "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
    "ACTION_RESULT_PRECISE_DAMAGE", "ACTION_RESULT_WRECKING_DAMAGE",
}) do
    local id = _G[name]
    if id then DAMAGE_RESULTS[id] = true end
end
-- Resultados que cuentan como sanación hecha.
local HEAL_RESULTS = {}
for _, name in ipairs({
    "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL",
    "ACTION_RESULT_HOT_TICK", "ACTION_RESULT_HOT_TICK_CRITICAL",
}) do
    local id = _G[name]
    if id then HEAL_RESULTS[id] = true end
end
for _, name in ipairs({
    "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK_CRITICAL",
    "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK_CRITICAL",
}) do
    local id = _G[name]
    if id then CRIT_RESULTS[id] = true end
end

-- El daño a ti mismo, a tus mascotas o a tu grupo no cuenta.
local IGNORED_TARGETS = {
    [COMBAT_UNIT_TYPE_PLAYER] = true,
    [COMBAT_UNIT_TYPE_PLAYER_PET] = true,
    [COMBAT_UNIT_TYPE_GROUP] = true,
}

local function Changed()
    CALLBACK_MANAGER:FireCallbacks(F.CHANGED)
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------
function F.Get(index)
    return F.history[index or 1]
end

-- Duración del combate en segundos (mínimo 1). En la run, el tiempo en combate.
function F.Duration(fight)
    if fight.isRun then return math.max(1, fight.time) end
    local stop = fight.endTime or Now()
    return math.max(1, (stop - fight.start) / 1000)
end

-- Tiempo desde tu primer golpe (o curación) hasta el último, o hasta ahora si sigue
-- el combate: es lo que se usa para tu DPS/HPS. metric = "damage" | "healing".
-- En la run, la suma de ese tiempo en cada combate.
function F.ActiveTime(fight, metric)
    local stat = fight[metric or "damage"]
    if fight.isRun then return math.max(1, stat.time) end
    if not stat.first then return 1 end
    local stop = fight.ended and stat.last or Now()
    return math.max(1, (stop - stat.first) / 1000)
end

-- Nombre del combate: el jefe o, si no hay, el objetivo que más daño recibió.
function F.Label(fight)
    if fight.boss then return fight.boss end
    local best, bestDamage = nil, 0
    for name, damage in pairs(fight.targets) do
        if damage > bestDamage then best, bestDamage = name, damage end
    end
    return best
end

---------------------------------------------------------------------------
-- Run: suma de todos los combates desde que entras en una zona. Solo cuenta el
-- tiempo en combate (el de ir de un grupo de enemigos al siguiente no). Se suma
-- al cerrar cada combate; el combate en curso solo se añade al mostrarla (F.RunView).
---------------------------------------------------------------------------
local METRICS = { "damage", "healing" }

local function NewRun(zoneId, zoneName)
    return {
        isRun = true,
        zoneId = zoneId,
        zoneName = zoneName,
        fights = 0,      -- combates sumados
        time = 0,        -- segundos en combate (suma de la duración de cada combate)
        -- Como en un combate; time: suma del tiempo activo (F.ActiveTime) de cada combate.
        damage = { total = 0, time = 0, abilities = {} },
        healing = { total = 0, overheal = 0, time = 0, abilities = {} },
        -- [nombre del personaje] = sumas de cada miembro; damageTime y healingTime son
        -- la duración de los combates en los que aparece, para su DPS/HPS.
        group = {},
        rest = 0,        -- daño estimado del resto del grupo (suma de cada combate de jefe)
        restTime = 0,    -- duración de esos combates
    }
end

local function AddAbilities(dest, src)
    for name, a in pairs(src) do
        local d = dest[name]
        if not d then
            d = {
                name = a.name, icon = a.icon, damageType = a.damageType, pet = a.pet,
                amount = 0, hits = 0, crits = 0, max = 0, overheal = 0,
            }
            dest[name] = d
        end
        d.amount = d.amount + a.amount
        d.hits = d.hits + a.hits
        d.crits = d.crits + a.crits
        d.overheal = d.overheal + a.overheal
        if a.max > d.max then d.max = a.max end
    end
end

-- Suma el daño o la sanación de un combate (o de otra run) y su tiempo activo.
local function AddStat(dest, src, time)
    dest.total = dest.total + src.total
    if dest.overheal then dest.overheal = dest.overheal + src.overheal end
    dest.time = dest.time + time
    AddAbilities(dest.abilities, src.abilities)
end

local function AddMember(run, key, src, damage, bossDamage, damageTime, healing, overheal, healingTime)
    local m = run.group[key]
    if not m then
        m = {
            name = src.name, account = src.account,
            damage = 0, bossDamage = 0, damageTime = 0,
            healing = 0, overheal = 0, healingTime = 0,
        }
        run.group[key] = m
    end
    m.classId = src.classId or m.classId
    m.damage = m.damage + damage
    m.bossDamage = m.bossDamage + bossDamage
    m.damageTime = m.damageTime + damageTime
    m.healing = m.healing + healing
    m.overheal = m.overheal + overheal
    m.healingTime = m.healingTime + healingTime
end

-- Suma un combate a la run. Los datos de cada miembro ya son solo los de ese combate
-- (ver G.Update), así que se pueden sumar sin contar nada dos veces.
local function AddFight(run, fight)
    local duration = F.Duration(fight)
    run.fights = run.fights + 1
    run.time = run.time + duration
    for _, metric in ipairs(METRICS) do
        local stat = fight[metric]
        AddStat(run[metric], stat, stat.first and F.ActiveTime(fight, metric) or 0)
    end
    for key, member in pairs(fight.group) do
        local damageTime = (member.damage or 0) > 0 and duration or 0
        local healingTime = (member.healing or 0) > 0 and duration or 0
        AddMember(run, key, member, member.damage or 0, member.bossDamage or 0, damageTime,
            member.healing or 0, (member.overhealPerSecond or 0) * healingTime, healingTime)
    end
    local rest = NM.Group.EstimateRest(fight)
    if rest then
        run.rest = run.rest + rest
        run.restTime = run.restTime + duration
    end
    run.grouped = run.grouped or fight.grouped
end

local function AddRun(dest, src)
    dest.fights = dest.fights + src.fights
    dest.time = dest.time + src.time
    for _, metric in ipairs(METRICS) do AddStat(dest[metric], src[metric], src[metric].time) end
    for key, m in pairs(src.group) do
        AddMember(dest, key, m, m.damage, m.bossDamage, m.damageTime, m.healing, m.overheal, m.healingTime)
    end
    dest.rest = dest.rest + src.rest
    dest.restTime = dest.restTime + src.restTime
    dest.grouped = dest.grouped or src.grouped
end

-- DPS y HPS de cada miembro: lo que hizo entre la duración de sus combates.
local function FinishRun(run)
    for _, m in pairs(run.group) do
        m.dps = m.damageTime > 0 and m.damage / m.damageTime or 0
        m.hps = m.healingTime > 0 and m.healing / m.healingTime or 0
        m.overhealPerSecond = m.healingTime > 0 and m.overheal / m.healingTime or 0
    end
end

-- La run tal como se ve: la acumulada más el combate en curso, si lo hay.
function F.RunView()
    local run, fight = F.run, F.active
    if not run or not fight then return run end
    local view = NewRun(run.zoneId, run.zoneName)
    AddRun(view, run)
    AddFight(view, fight)
    FinishRun(view)
    return view
end

-- Empieza una run vacía en la zona actual, o ninguna si se cuenta cada combate.
function F.ResetRun()
    F.run = nil
    if NM.sv.countMode ~= "run" then return end
    local zoneId = GetUnitWorldPosition("player")
    F.run = NewRun(zoneId, zo_strformat(SI_ZONE_NAME, GetZoneNameById(zoneId)))
end

-- "fight" (cada combate) | "run" (toda la run). Al cambiar, la run empieza de cero.
-- La ventana se actualiza en NM.Meter.SetCountMode.
function F.SetCountMode(mode)
    NM.sv.countMode = mode
    F.ResetRun()
end

---------------------------------------------------------------------------
-- Inicio y fin
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Jefes: nombre del combate y vida que pierden (para estimar el daño del resto
-- del grupo que no comparte sus datos).
---------------------------------------------------------------------------
local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
local bossHealth = {}   -- [unitTag] = { value, max } última vida vista

local function CheckBoss(fight)
    for i = 1, MAX_BOSSES or 12 do
        local tag = "boss" .. i
        if DoesUnitExist(tag) then
            local name = U.FormatName(GetUnitName(tag))
            fight.boss = fight.boss or name
            fight.bossNames[name] = true
            if not bossHealth[tag] then
                local value, max = GetUnitPower(tag, HEALTH)
                bossHealth[tag] = { value = value, max = max }
            end
        end
    end
end

-- Solo cuentan las bajadas de vida; las subidas (curaciones, cambio de fase) no.
-- Una bajada fuera de combate no actualiza la última vida vista: el primer golpe
-- llega antes de que empiece el combate y así se cuenta en cuanto empieza.
local function OnBossHealth(_, unitTag, _, _, value, max)
    local fight = F.active
    local last = bossHealth[unitTag]
    if last and last.max == max and value < last.value then
        if not fight then return end
        fight.bossHealthLost = fight.bossHealthLost + (last.value - value)
    end
    bossHealth[unitTag] = { value = value, max = max }
end

local function OnBossesChanged()
    bossHealth = {}
    if F.active then CheckBoss(F.active) end
end

local function Tick()
    local fight = F.active
    if not fight then return end
    CheckBoss(fight)
    NM.Group.Update(fight)
    Changed()
end

local function StartFight()
    local t = Now()
    local fight = {
        start = t,
        inCombat = IsUnitInCombat("player"),  -- si llegaste a entrar en combate
        -- Tu daño y tu sanación. abilities: [nombre] = { name, icon, amount, hits, crits,
        -- max, overheal, damageType, pet }; first/last: primer y último evento.
        damage = { total = 0, abilities = {} },
        healing = { total = 0, overheal = 0, abilities = {} },
        targets = {},    -- [nombre del objetivo] = daño
        group = {},      -- [nombre del personaje] = datos de LibGroupCombatStats
        bossNames = {},  -- [nombre] = true
        bossHealthLost = 0,  -- vida perdida por los jefes (daño de todos)
        myBossDamage = 0,    -- tu parte de ese daño
    }
    F.active = fight
    table.insert(F.history, 1, fight)
    local limit = math.max(1, NM.sv.historySize or 10)
    for i = #F.history, limit + 1, -1 do F.history[i] = nil end

    CheckBoss(fight)
    EM:RegisterForUpdate(TICK_UPDATE, TICK_MS, Tick)
    CALLBACK_MANAGER:FireCallbacks(F.CHANGED, "start")
end

local function EndFight()
    EM:UnregisterForUpdate(END_UPDATE)
    EM:UnregisterForUpdate(TICK_UPDATE)
    local fight = F.active
    if not fight then return end

    NM.Group.Update(fight)
    NM.Group.Close(fight)
    fight.ended = true
    fight.endTime = fight.combatEnd or Now()
    F.active = nil
    F.lastEnd = Now()

    -- No se guarda un combate en el que nadie hizo daño ni curó (p. ej. te atacaron y
    -- huiste) ni uno en el que nunca llegaste a entrar en combate. Los que se guardan
    -- se suman a la run, una sola vez, ya cerrados.
    local empty = fight.damage.total == 0 and fight.healing.total == 0 and next(fight.group) == nil
    if empty or not fight.inCombat then
        if F.history[1] == fight then table.remove(F.history, 1) end
    elseif F.run then
        AddFight(F.run, fight)
        FinishRun(F.run)
    end
    CALLBACK_MANAGER:FireCallbacks(F.CHANGED, "end")
end

-- ¿Algún miembro del grupo cercano sigue en combate?
local function GroupInCombat()
    if not IsUnitGrouped("player") then return false end
    for i = 1, GetGroupSize() do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and IsUnitOnline(tag) and IsUnitInCombat(tag) and not AreUnitsEqual(tag, "player") then
            return true
        end
    end
    return false
end

-- Se cierra el combate unos segundos después de salir de combate. Si estás muerto
-- y tu grupo sigue luchando, se espera a que termine.
local function CheckEnd()
    if IsUnitInCombat("player") then
        EM:UnregisterForUpdate(END_UPDATE)
        if F.active then
            F.active.inCombat = true
            F.active.combatEnd = nil
        end
        return
    end
    if IsUnitDead("player") and GroupInCombat() then return end
    EndFight()
end

-- Cierra el combate tras la espera configurada si no vuelves a entrar en combate.
local function ScheduleEnd(fight)
    fight.combatEnd = Now()
    local delay = math.max(0, NM.sv.combatEndDelay or 3) * 1000
    EM:RegisterForUpdate(END_UPDATE, math.max(100, delay), CheckEnd)
end

local function OnCombatState(_, inCombat)
    if inCombat then
        EM:UnregisterForUpdate(END_UPDATE)
        if not F.active then StartFight() end
        F.active.combatEnd = nil
        F.active.inCombat = true
    elseif F.active then
        ScheduleEnd(F.active)
    end
end

---------------------------------------------------------------------------
-- Eventos de combate
---------------------------------------------------------------------------
local function Record(stat, result, abilityName, abilityId, hitValue, damageType, isPet)
    local t = Now()
    if hitValue > 0 then
        stat.first = stat.first or t
        stat.last = t
    end
    stat.total = stat.total + hitValue

    local name = U.AbilityName(abilityName ~= "" and abilityName or GetAbilityName(abilityId))
    if name == "" then name = tostring(abilityId) end
    local ability = stat.abilities[name]
    if not ability then
        ability = {
            name = name,
            icon = GetAbilityIcon(abilityId),
            amount = 0, hits = 0, crits = 0, max = 0, overheal = 0,
            damageType = damageType,
            pet = isPet,
        }
        stat.abilities[name] = ability
    end
    ability.amount = ability.amount + hitValue
    ability.hits = ability.hits + 1
    if CRIT_RESULTS[result] then ability.crits = ability.crits + 1 end
    if hitValue > ability.max then ability.max = hitValue end
    return ability
end

-- overflow: en las curaciones, la parte que sobró (sobrecuración).
-- Los errores y los eventos de otras fuentes ya los descartan los filtros de F.Init.
local function OnCombatEvent(_, result, _, abilityName, _, _, _, sourceType, targetName, targetType,
                             hitValue, _, damageType, _, _, _, abilityId, overflow)
    local isDamage = DAMAGE_RESULTS[result]
    local isHeal = HEAL_RESULTS[result]
    if not isDamage and not isHeal then return end
    overflow = overflow or 0
    if isDamage and (hitValue <= 0 or IGNORED_TARGETS[targetType]) then return end
    if isHeal and hitValue <= 0 and overflow <= 0 then return end
    local isPet = sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
    if isPet and not NM.sv.includePets then return end

    local fight = F.active
    if not fight then
        -- Las curaciones fuera de combate (regeneración, HoT) no abren un combate.
        if isHeal and not IsUnitInCombat("player") then return end
        -- El primer golpe llega antes de que el juego te ponga en combate, así que el
        -- combate empieza aquí. Si no llegas a entrar en combate (un DoT que sigue tras
        -- terminar, una criatura neutral...), se cierra tras la espera y se descarta.
        StartFight()
        fight = F.active
        if not fight.inCombat then ScheduleEnd(fight) end
    end

    if isHeal then
        local ability = Record(fight.healing, result, abilityName, abilityId, hitValue, damageType, isPet)
        ability.overheal = ability.overheal + overflow
        fight.healing.overheal = fight.healing.overheal + overflow
        return
    end

    Record(fight.damage, result, abilityName, abilityId, hitValue, damageType, isPet)
    if targetName and targetName ~= "" then
        local target = U.FormatName(targetName)
        fight.targets[target] = (fight.targets[target] or 0) + hitValue
        if fight.bossNames[target] then fight.myBossDamage = fight.myBossDamage + hitValue end
    end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
-- Borra el historial y la run. Si estás en combate, empieza uno nuevo desde cero.
function F.Reset()
    local inFight = F.active ~= nil
    EM:UnregisterForUpdate(TICK_UPDATE)
    EM:UnregisterForUpdate(END_UPDATE)
    F.active = nil
    F.history = {}
    F.ResetRun()
    if inFight and IsUnitInCombat("player") then
        StartFight()
    else
        Changed()
    end
end

function F.Init()
    local name = NM.name .. "_Combat"
    EM:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)

    local petName = NM.name .. "_CombatPet"
    EM:RegisterForEvent(petName, EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:AddFilterForEvent(petName, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET)
    EM:AddFilterForEvent(petName, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)

    EM:RegisterForEvent(NM.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, OnCombatState)

    local bossName = NM.name .. "_BossHealth"
    EM:RegisterForEvent(bossName, EVENT_POWER_UPDATE, OnBossHealth)
    EM:AddFilterForEvent(bossName, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
    EM:AddFilterForEvent(bossName, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, HEALTH)
    EM:RegisterForEvent(NM.name .. "_Bosses", EVENT_BOSSES_CHANGED, OnBossesChanged)

    -- Al cambiar de zona se cierra el combate en curso y la run empieza de cero. Las
    -- pantallas de carga dentro de la misma zona (morir y reaparecer) no la reinician.
    EM:RegisterForEvent(NM.name .. "_FightZone", EVENT_PLAYER_ACTIVATED, function()
        if F.active and not IsUnitInCombat("player") then EndFight() end
        if NM.sv.countMode ~= "run" then return end
        local zoneId = GetUnitWorldPosition("player")
        if not F.run or F.run.zoneId ~= zoneId then
            F.ResetRun()
            CALLBACK_MANAGER:FireCallbacks(F.CHANGED, "run")
        end
    end)
end
