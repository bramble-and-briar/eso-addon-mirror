-- Daño y sanación de los demás miembros del grupo.
-- ESO solo informa a cada jugador de lo que hace él, así que cada miembro mide lo
-- suyo y lo comparte mediante LibGroupCombatStats. La librería envía el DPS y el HPS
-- en miles (y el daño en decenas de miles), así que las cifras de los demás son
-- aproximadas; las tuyas son exactas. La sanación total no se comparte: se estima
-- con el HPS y la duración del combate.
-- En combates de jefe, la vida que pierde el jefe menos lo que ya se conoce da una
-- estimación del daño de los miembros que no comparten sus datos ("resto del grupo").

local NM = NirnhonedMetrics
local U = NM.Utils
local G = {}
NM.Group = G

local lgcs   -- objeto devuelto por LibGroupCombatStats.RegisterAddon

-- Si el resto estimado es menor que esta parte de la vida perdida por los jefes, no
-- se muestra (lo normal es que sean redondeos y escudos, no otro jugador).
local REST_MIN_SHARE = 0.03

-- Devuelve daño total, DPS y daño a jefes de un miembro.
local function MemberValues(dps, fight)
    local lib = LibGroupCombatStats
    if dps.dmgType == lib.DAMAGE_TOTAL then
        local damage = dps.dmg * 10000
        return damage, dps.dps * 1000, damage
    elseif dps.dmgType == lib.DAMAGE_BOSS then
        -- En combates de jefe la librería comparte el DPS total (dps, en miles) y el
        -- DPS al jefe (dmg, en centenas), pero no el daño: se estima con la duración.
        local duration = NM.Fight.Duration(fight)
        local overall = dps.dps * 1000
        return overall * duration, overall, dps.dmg * 100 * duration
    end
end

local function GetMember(fight, tag, stats)
    local member = fight.group[stats.name]
    if not member then
        member = {
            name = U.FormatName(stats.name),
            account = stats.displayName,
        }
        fight.group[stats.name] = member
    end
    if tag and DoesUnitExist(tag) then member.classId = GetUnitClassId(tag) end
    return member
end

-- Solo se usan los datos que cambiaron después de empezar el combate (los anteriores
-- son del combate previo).
local function IsFresh(data, fight)
    return data and (data._lastChanged or 0) >= fight.start
end

-- Copia en el combate los últimos datos recibidos de cada miembro.
function G.Update(fight)
    if not lgcs or not fight or not IsUnitGrouped("player") then return end
    for tag, stats in lgcs:Iterate() do
        if not stats.isPlayer and stats.name then
            if IsFresh(stats.dps, fight) then
                local damage, dps, bossDamage = MemberValues(stats.dps, fight)
                if damage and damage > 0 then
                    local member = GetMember(fight, tag, stats)
                    member.damage = damage
                    member.dps = dps
                    member.bossDamage = bossDamage
                end
            end
            local hps = stats.hps
            if IsFresh(hps, fight) and (hps.hps or 0) > 0 then
                local member = GetMember(fight, tag, stats)
                member.hps = hps.hps * 1000
                member.healing = member.hps * NM.Fight.Duration(fight)
                member.overhealPerSecond = (hps.overheal or 0) * 1000
            end
        end
    end
    fight.grouped = true
end

-- Daño estimado de los miembros que no comparten sus datos, o nil si no hay.
function G.RestOfGroup(fight)
    if not NM.sv.showRest or not fight.grouped or fight.bossHealthLost <= 0 then return nil end
    local known = fight.myBossDamage
    for _, member in pairs(fight.group) do
        known = known + (member.bossDamage or 0)
    end
    local rest = fight.bossHealthLost - known
    if rest < fight.bossHealthLost * REST_MIN_SHARE then return nil end
    return rest
end

function G.Init()
    -- Pedir "DPS" y "HPS" hace que la librería comparta los tuyos con el grupo; sin
    -- pedirlos se siguen recibiendo los de los demás.
    lgcs = LibGroupCombatStats.RegisterAddon(NM.name, NM.sv.shareDps and { "DPS", "HPS" } or {})
end
