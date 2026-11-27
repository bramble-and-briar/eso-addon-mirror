-- Independent implementation. Ability IDs and nominal debuff values were
-- cross-checked against the user's local Meterskull 1.6.1 reference.
IsoStats2 = { name = "IsoStats2", version = "2.3.3" }
local S = IsoStats2

-- Same-family effects do not stack, including trial-dummy equivalents.
local penetrationEffects = {
    [61742] = { "minorBreach", 2974 },
    [61743] = { "majorBreach", 5948 },
    -- Meterskull compatibility: nominal Infused value for both detected IDs.
    [120007] = { "crusher", 2108 }, [17906] = { "crusher", 2108 },
    [120018] = { "alkosh", 6000 }, [76667] = { "alkosh", 6000 },
    [159288] = { "crimson", 3541 }, [143808] = { "crystal", 1000 },
    [187742] = { "runic", 2200 },
}
local criticalEffects = {
    [142610] = { "fire", 5 }, [142652] = { "frost", 5 },
    [142653] = { "shock", 5 }, [181606] = { "catalystDummy", 15 },
    [145975] = { "minorBrittle", 10 }, [145977] = { "majorBrittle", 20 },
}
S.criticalEffectTypes=criticalEffects
-- Actual status-effect IDs, also used by the event-based collector.
S.statusEffectTypes = {
    [18084] = "burning", [21929] = "poisoned", [148801] = "hemorrhaging",
    [178118] = "overcharged", [95136] = "chilled", [95134] = "concussed",
    [178123] = "sundered", [178127] = "diseased",
}

function S.ReadChampionPoints()
    local equipped = {}
    for slot = 1, 12 do
        equipped[GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) or 0] = true
    end
    local naturePoints = equipped[276] and GetNumPointsSpentOnChampionSkill(276) or 0
    local backstabberPoints=equipped[31] and (GetNumPointsSpentOnChampionSkill(31) or 0) or 0
    -- Like CMX: actual purchased stages, while still assuming flanking.
    return (naturePoints or 0) >= 50, math.min(5,math.floor(backstabberPoints/10))*2
end
local function sum(values)
    local total = 0
    for _, value in pairs(values) do total = total + value end
    return total
end

function S.ReadTarget()
    local pen, crit, statuses, penSources, statusSources,critSources = {}, {}, {}, {}, {}, {}
    local natureEquipped, backstabberBonus = S.ReadChampionPoints()
    local cp = { forceOfNaturePenetration = 0, backstabberCriticalDamage = backstabberBonus,
        statusEffectCount = 0, forceOfNatureEstimated = false,
        penetrationSources = penSources, statusSources = statusSources,
        trackedTargetId = nil,criticalSources=critSources }
    if not DoesUnitExist("reticleover") or IsUnitPlayer("reticleover")
        or not IsUnitAttackable("reticleover") or IsUnitDead("reticleover") then
        return 0, 0, nil, cp
    end
    for index = 1, GetNumBuffs("reticleover") do
        local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("reticleover", index)
        local p, c = penetrationEffects[id], criticalEffects[id]
        if p and (not pen[p[1]] or p[2]>pen[p[1]]) then
            pen[p[1]] = p[2]
            penSources[p[1]]={id=id,value=p[2],name=GetAbilityName and GetAbilityName(id) or tostring(id),assumed=p[1]=='crusher' or p[1]=='alkosh'}
        end
        if c and (not crit[c[1]] or c[2]>crit[c[1]]) then
            crit[c[1]]=c[2]
            critSources[c[1]]={id=id,value=c[2],origin='visible',name=GetAbilityName and GetAbilityName(id) or tostring(id)}
        end
        local status = S.statusEffectTypes[id]
        if natureEquipped and status then
            statuses[status]=true
            statusSources[status]={id=id,estimated=false,origin='visible',name=GetAbilityName and GetAbilityName(id) or tostring(id)}
        end
    end
    local tracked,unitId=S.GetTargetStatusEffects()
    cp.trackedTargetId=unitId
    for kind,entry in pairs(S.GetTargetCriticalEffects()) do
        local info=criticalEffects[entry.id]
        if info and (not crit[kind] or info[2]>crit[kind]) then
            crit[kind]=info[2]
            critSources[kind]={id=entry.id,value=info[2],origin=entry.origin,name=GetAbilityName and GetAbilityName(entry.id) or tostring(entry.id)}
        end
    end
    if natureEquipped then
        for status,entry in pairs(tracked) do
            if not statuses[status] then
                statuses[status]=true
                statusSources[status]={id=entry.id,estimated=false,origin=entry.origin,expires=entry.expires,
                    name=GetAbilityName and GetAbilityName(entry.id) or tostring(entry.id)}
            end
        end
    end
    for _ in pairs(statuses) do
        cp.statusEffectCount = cp.statusEffectCount + 1
    end
    cp.forceOfNaturePenetration = math.min(8, cp.statusEffectCount) * 660
    -- Dummy catalyst replaces its three elemental components.
    local catalyst = math.max(crit.catalystDummy or 0,
        (crit.fire or 0) + (crit.frost or 0) + (crit.shock or 0))
    if (crit.catalystDummy or 0)>=(crit.fire or 0)+(crit.frost or 0)+(crit.shock or 0) then
        critSources.fire,critSources.frost,critSources.shock=nil,nil,nil
    else critSources.catalystDummy=nil end
    crit.fire, crit.frost, crit.shock, crit.catalystDummy = nil, nil, nil, nil
    return sum(pen) + cp.forceOfNaturePenetration,
        sum(crit) + catalyst, GetUnitName("reticleover"), cp
end

function S.ReadStats()
    local function stat(id) return GetPlayerStat(id, STAT_BONUS_OPTION_APPLY_BONUS) end
    local _, _, bonus = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)
    local pen, crit, target, cp = S.ReadTarget()
    local result = {
        weaponDamage = stat(STAT_POWER), spellDamage = stat(STAT_SPELL_POWER),
        physicalPenetration = stat(STAT_PHYSICAL_PENETRATION),
        spellPenetration = stat(STAT_SPELL_PENETRATION),
        physicalResistance = stat(STAT_DAMAGE_RESIST_PHYSICAL),
        spellResistance = stat(STAT_DAMAGE_RESIST_MAGIC),
        criticalResistance = stat(STAT_CRITICAL_RESISTANCE),
        weaponCritical = GetCriticalStrikeChance(stat(STAT_CRITICAL_STRIKE)),
        spellCritical = GetCriticalStrikeChance(stat(STAT_SPELL_CRITICAL)),
        criticalDamage = 50 + (bonus or 0) + cp.backstabberCriticalDamage,
        targetPenetration = pen, targetCriticalDamage = crit, targetName = target,
        forceOfNaturePenetration = cp.forceOfNaturePenetration,
        backstabberCriticalDamage = cp.backstabberCriticalDamage,
        statusEffectCount = cp.statusEffectCount,
        forceOfNatureEstimated = cp.forceOfNatureEstimated,
        penetrationSources = cp.penetrationSources, statusSources = cp.statusSources,
        trackedTargetId = cp.trackedTargetId,
        sampleTime = GetGameTimeMilliseconds(),
    }
    result.penetration = math.max(result.physicalPenetration, result.spellPenetration)
    result.power = math.max(result.weaponDamage, result.spellDamage)
    result.criticalChance = math.max(result.weaponCritical, result.spellCritical)
    result.targetBonusesEnabled=S.includeTargetBonuses~=false
    result.displayPenetration=result.penetration+(result.targetBonusesEnabled and result.targetPenetration or 0)
    S.AddCriticalDamageData(result,bonus or 0,cp.criticalSources)
    S.current = result
    if target then S.lastTargetSample=result end
    if S.RecordPenDiagnosticSample then S.RecordPenDiagnosticSample(result) end
    return result
end

local diagnostic={test=1,sequence=0,samples=0,active=false}
function S.ResetPenDiagnosticHistory()
    diagnostic={test=diagnostic.test+1,sequence=diagnostic.sequence,samples=0,active=diagnostic.active}
end
function S.BeginPenDiagnosticTest()
    S.ResetPenDiagnosticHistory()
    diagnostic.active=true
end
function S.EndPenDiagnosticTest()
    S.ReadStats()
    diagnostic.active=false
    diagnostic.ended=GetGameTimeMilliseconds()
end
function S.RecordPenDiagnosticSample(v)
    diagnostic.sequence=diagnostic.sequence+1
    v.sampleNumber=diagnostic.sequence
    if (diagnostic.active or (not diagnostic.ended and v.targetName)) and
        (not diagnostic.criticalPeak or v.rawCriticalDamage>=diagnostic.criticalPeak.rawCriticalDamage) then
        diagnostic.criticalPeak=v
    end
    if not v.targetName or (not diagnostic.active and diagnostic.ended) then return end
    diagnostic.samples=diagnostic.samples+1
    diagnostic.latest=v
    -- Capture BOTH calculations now, while these effects are still active.
    -- Looking up a report after combat must not reconstruct the past from
    -- today's reticle buffs. Prefer the highest new total, then the old total.
    local total=v.penetration+v.targetPenetration
    local previous=diagnostic.comparisonPeak
    if diagnostic.active and (not previous or total>=previous.total) then
        local lines,oldTotal=S.CreatePenetrationComparison(v)
        if not previous or total>previous.total or oldTotal>=previous.oldTotal then
            diagnostic.comparisonPeak={sample=v,total=total,oldTotal=oldTotal,lines=lines}
        end
    end
    -- Baseline scans after a test must never erase an observed buffed sample.
    if v.targetPenetration>0 and (not diagnostic.peak or v.displayPenetration>=diagnostic.peak.displayPenetration) then
        diagnostic.peak=v
    end
end

function S.GetRecordedCriticalSample()
    return diagnostic.criticalPeak,diagnostic.test,diagnostic.active
end
function S.InitializePenDiagnostics()
    EVENT_MANAGER:RegisterForEvent(S.name..'PenDiagnosticCombat',EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
        if inCombat and not diagnostic.active then S.BeginPenDiagnosticTest()
        elseif not inCombat and diagnostic.active then S.EndPenDiagnosticTest() end
    end)
end

local function sampleReport(v,includeTarget,title)
    local age=math.max(0,(GetGameTimeMilliseconds()-v.sampleTime)/1000)
    local lines={string.format('%s | Messung #%d | vor %.1f s | Ziel: %s',title,v.sampleNumber or 0,age,v.targetName or 'keines')}
    lines[#lines+1]=string.format('Eigene Pen: physisch %d / magisch %d -> verwendet %d',v.physicalPenetration,v.spellPenetration,v.penetration)
    local keys={}
    for key in pairs(v.penetrationSources) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local source=v.penetrationSources[key]
        lines[#lines+1]=string.format('+%d: %s (ID %d)%s',source.value,source.name,source.id,source.assumed and ' [fester Schaetzwert]' or '')
    end
    keys={}
    for key in pairs(v.statusSources) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local source=v.statusSources[key]
        lines[#lines+1]=string.format('+660 FoN: %s, ID %d [%s]',key,source.id,source.origin=='combat' and 'Kampfereignis' or source.origin=='effect' and 'Effektereignis' or 'sichtbare Status-ID')
    end
    lines[#lines+1]=v.trackedTargetId and ('Ziel-ID: '..tostring(v.trackedTargetId)) or 'Ziel-ID noch nicht zugeordnet: nur direkt sichtbare Status-IDs, keine Ersatz-Debuffs.'
    lines[#lines+1]=string.format('FoN: %d Typen = %d | Ziel-Zuschlaege insgesamt: %d',v.statusEffectCount,v.forceOfNaturePenetration,v.targetPenetration)
    lines[#lines+1]=string.format('HUD: %d + %d = %d (Ziel-Zuschlaege %s)',v.penetration,includeTarget and v.targetPenetration or 0,v.penetration+(includeTarget and v.targetPenetration or 0),includeTarget and 'AN' or 'AUS')
    return lines
end

function S.GetPenetrationReport(includeTarget,mode)
    local live=S.ReadStats()
    local lines={string.format('IsoStats2 %s | PEN-Diagnose | Test #%d | %d Zielmessungen',S.version,diagnostic.test,diagnostic.samples)}
    local function append(values) for _,line in ipairs(values) do lines[#lines+1]=line end end
    if mode~='last' then
        if mode=='live' or not diagnostic.peak then append(sampleReport(live,includeTarget,'AKTUELL'))
        else
            lines[#lines+1]=string.format('AKTUELL #%d: %d Pen | eigene %d + Ziel %d | Ziel: %s',live.sampleNumber,live.penetration+(includeTarget and live.targetPenetration or 0),live.penetration,includeTarget and live.targetPenetration or 0,live.targetName or 'keines')
        end
    end
    if mode~='live' then
        if diagnostic.peak then
            append(sampleReport(diagnostic.peak,diagnostic.peak.targetBonusesEnabled,
                diagnostic.active and 'HOECHSTER BEOBACHTETER KAMPFWERT - gespeichert, nicht live' or 'LETZTER TEST: HOECHSTER BEOBACHTETER WERT - gespeichert, nicht live'))
        else
            lines[#lines+1]='Noch keine Zielmessung mit Pen-Zuschlaegen in diesem Test erfasst. Ziel anvisieren und erneut angreifen.'
        end
    end
    if S.GetStatusTrackingDiagnostics then
        local info=S.GetStatusTrackingDiagnostics()
        lines[#lines+1]=string.format('Status-Ereignisse seit Zonenwechsel: Kampf %d / Effekte %d | aktuelle Ziel-ID: %s',info.combat,info.effects,tostring(info.targetId or 'unbekannt'))
        if not info.targetId and info.combat>0 then
            lines[#lines+1]='Status-Ereignisse empfangen, aber nicht sicher dem anvisierten Ziel zugeordnet. Deshalb keine fremden Effekte addiert.'
        end
        for index=math.max(1,#info.recent-(mode=='live' and 5 or 2)),#info.recent do
            local entry=info.recent[index]
            lines[#lines+1]=string.format('Ereignis: ID %d | Gegner-ID %s | %s | vor %.1f s',entry.id,tostring(entry.unitId),entry.kind,math.max(0,(GetGameTimeMilliseconds()-entry.time)/1000))
        end
    end
    return lines
end

-- Reproduce the local IsoStats 2.0.4 reference when its live API is private.
-- This is explicitly a calculation, never an observed original HUD value.
local function legacyPenetration(current)
    local proxies={
        [88401]='overcharged',[145875]='chilled',[145975]='chilled',
        [79717]='concussed',[61742]='sundered',[61726]='diseased',
    }
    local old={penetration=current.penetration,targetPenetration=0,
        targetName=current.targetName,statusSources={},forceOfNaturePenetration=0}
    if not current.targetName then return old end
    local natureEquipped=S.ReadChampionPoints()
    local pen={}
    for index=1,GetNumBuffs('reticleover') do
        local _,_,_,_,_,_,_,_,_,_,id=GetUnitBuffInfo('reticleover',index)
        local effect=penetrationEffects[id]
        if effect then pen[effect[1]]=math.max(pen[effect[1]] or 0,effect[2]) end
        local direct=S.statusEffectTypes[id]
        local kind=direct or proxies[id]
        if natureEquipped and kind and (not old.statusSources[kind] or direct) then
            old.statusSources[kind]={id=id,estimated=not direct}
        end
    end
    for _ in pairs(old.statusSources) do old.forceOfNaturePenetration=old.forceOfNaturePenetration+660 end
    old.targetPenetration=sum(pen)+old.forceOfNaturePenetration
    return old
end

-- Read the loaded original directly when available; no slash command required.
-- Both totals include target bonuses for a like-for-like comparison, even if
-- either HUD has target bonuses switched off in its private settings.
function S.CreatePenetrationComparison(current)
    local lines={}
    local original=_G.IsoStats
    local ok,old
    if type(original)=='table' and original~=S and type(original.ReadStats)=='function' then
        ok,old=pcall(original.ReadStats)
    end
    local oldLabel='IsoStats'
    if not ok or type(old)~='table' or type(old.penetration)~='number' or type(old.targetPenetration)~='number' then
        old=legacyPenetration(current)
        oldLabel='ALT-LOGIK'
        lines[#lines+1]='Original nicht direkt lesbar: Vergleichsrechnung nach lokaler IsoStats-2.0.4-Referenz, KEIN ausgelesener Originalwert.'
    else
        lines[#lines+1]='Geladenes Original: '..tostring(original.version or 'Version unbekannt')..' | direkt gelesen.'
    end
    lines[#lines+1]='Effekte dieser Messung, immer inklusive Zielboni.'
    lines[#lines+1]=string.format('%s: eigene %d + Ziel %d = %d | Ziel: %s',oldLabel,old.penetration,old.targetPenetration,old.penetration+old.targetPenetration,old.targetName or 'keines')
    lines[#lines+1]=string.format('IsoStats2: eigene %d + Ziel %d = %d | Ziel: %s',current.penetration,current.targetPenetration,current.penetration+current.targetPenetration,current.targetName or 'keines')
    lines[#lines+1]=string.format('Differenz %s minus IsoStats2: %+d PEN',oldLabel,old.penetration+old.targetPenetration-current.penetration-current.targetPenetration)
    lines[#lines+1]='HUD-Schalter fuer Zielboni koennen die sichtbaren HUD-Zahlen davon unterscheiden.'
    local oldSources=old.statusSources or {}
    local keys,seen={},{}
    for key in pairs(oldSources) do seen[key]=true end
    for key in pairs(current.statusSources) do seen[key]=true end
    for key in pairs(seen) do keys[#keys+1]=key end
    table.sort(keys)
    local function sourceText(source)
        if not source then return 'nicht erfasst' end
        return string.format('ID %s [%s]%s',tostring(source.id),source.estimated and 'ERSATZ-DEBUFF / SCHAETZUNG' or source.origin or 'Status-ID',GetAbilityName and (' '..GetAbilityName(source.id)) or '')
    end
    for _,key in ipairs(keys) do
        lines[#lines+1]=key..' (+660): ALT '..sourceText(oldSources[key])..' | NEU '..sourceText(current.statusSources[key])
    end
    lines[#lines+1]=string.format('FoN ALT: %d | NEU: %d',old.forceOfNaturePenetration or 0,current.forceOfNaturePenetration)
    if #keys==0 then lines[#lines+1]='Keine FoN-Statusquellen erfasst. Bei aktiven Effekten am Ziel erneut vergleichen.' end
    lines[#lines+1]='Nicht erfasst beweist nicht inaktiv. Ersatz-Debuffs beweisen keinen aktiven Statuseffekt.'
    return lines,old.penetration+old.targetPenetration
end

function S.GetPenetrationComparison(mode)
    local current
    if mode~='last' then current=S.ReadStats() end
    local lines={'IsoStats2 '..S.version..' | PEN-VERGLEICH | Test #'..diagnostic.test}
    local saved=diagnostic.comparisonPeak
    if mode~='live' and saved then
        local sample=saved.sample
        lines[#lines+1]=string.format('GESPEICHERTER KAMPFVERGLEICH - nicht live | Messung #%d | vor %.1f s | Ziel: %s',sample.sampleNumber,math.max(0,(GetGameTimeMilliseconds()-sample.sampleTime)/1000),sample.targetName or 'keines')
        lines[#lines+1]='Beide Rechnungen stammen vom selben Zeitpunkt beim hoechsten beobachteten IsoStats2-PEN-Wert, inklusive Zielboni.'
        for _,line in ipairs(saved.lines) do lines[#lines+1]=line end
    elseif mode=='last' then
        lines[#lines+1]='Noch kein Kampfvergleich gespeichert. Nach diesem Update erneut kaempfen.'
    else
        lines[#lines+1]='AKTUELL - live, kein gespeicherter Kampfwert.'
        for _,line in ipairs(S.CreatePenetrationComparison(current)) do lines[#lines+1]=line end
        if mode~='live' then lines[#lines+1]='Noch kein Kampfvergleich gespeichert. Nach diesem Update erneut kaempfen.' end
    end
    return lines
end
