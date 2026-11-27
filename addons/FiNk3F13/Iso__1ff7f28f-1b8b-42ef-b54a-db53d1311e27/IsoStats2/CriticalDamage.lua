local S=IsoStats2
local masteryCache={untilTime=0,active=false,known=false}

function S.InvalidateCriticalCache() masteryCache.untilTime=0 end
local function masteryState()
    local now=GetGameTimeMilliseconds()
    if now<masteryCache.untilTime then return masteryCache.active,masteryCache.known end
    local active,known=false,false
    if GetNumSkillLines and GetNumSkillAbilities and GetSkillAbilityId and IsSkillAbilityPurchased and GetSkillLineDynamicInfo and SKILL_TYPE_CLASS then
        known=true
        for line=1,GetNumSkillLines(SKILL_TYPE_CLASS) do
            local _,_,lineActive=GetSkillLineDynamicInfo(SKILL_TYPE_CLASS,line)
            if lineActive then
                for skill=1,GetNumSkillAbilities(SKILL_TYPE_CLASS,line) do
                    if GetSkillAbilityId(SKILL_TYPE_CLASS,line,skill,false)==263605 and IsSkillAbilityPurchased(SKILL_TYPE_CLASS,line,skill) then
                        active=true
                    end
                end
            end
        end
    end
    masteryCache={untilTime=now+5000,active=active,known=known}
    return active,known
end

local function percent(text)
    if type(text)~='string' then return nil end
    local clean=text:gsub('|c%x%x%x%x%x%x',''):gsub('|r','')
    local value=clean:match('(%d+[.,]?%d*)%s*%%')
    return value and tonumber((value:gsub(',','.'))) or nil
end

function S.ReadShadowCorrection()
    local info={active=false,known=false,expected=0,reported=0,difference=0,applied=0}
    local slot
    for index=1,GetNumBuffs('player') do
        local _,_,_,buffSlot,_,_,_,_,_,_,id=GetUnitBuffInfo('player',index)
        if id==13984 then slot=buffSlot; info.active=true; break end
    end
    if not info.active then return info end
    if not (GetAbilityEffectDescription and GetItemLink and GetItemLinkTraitInfo and ITEM_TRAIT_TYPE_ARMOR_DIVINES and BAG_WORN and LINK_STYLE_DEFAULT) then return info end
    local reported=percent(GetAbilityEffectDescription(slot))
    if not reported then return info end
    local slots={EQUIP_SLOT_HEAD,EQUIP_SLOT_SHOULDERS,EQUIP_SLOT_CHEST,EQUIP_SLOT_HAND,EQUIP_SLOT_WAIST,EQUIP_SLOT_LEGS,EQUIP_SLOT_FEET}
    if #slots~=7 then return info end
    local bonus=0
    for _,equipSlot in ipairs(slots) do
        local link=GetItemLink(BAG_WORN,equipSlot,LINK_STYLE_DEFAULT)
        if link and link~='' then
            local trait,description=GetItemLinkTraitInfo(link)
            if trait==ITEM_TRAIT_TYPE_ARMOR_DIVINES then
                local value=percent(description)
                if not value then return info end
                bonus=bonus+value
            end
        end
    end
    info.known=true
    info.expected=math.floor(11*(1+bonus/100)+0.000001)
    info.reported=reported
    info.difference=info.expected-info.reported
    -- This is LibCombat's historical correction, not independently measured
    -- extra damage. It stays opt-in to avoid double counting a fixed game bug.
    if S.applyShadowCorrection then info.applied=info.difference end
    return info
end

function S.AddCriticalDamageData(result,advanced,sources)
    local mastery,known=masteryState()
    local cap,capSource
    if S.criticalCapAutomatic~=false then
        cap=mastery and 155 or 125
        capSource=mastery and 'Above and Beyond aktiv (ID 263605)' or known and 'Standard, keine aktive erlernte Meisterschaft' or 'Standard; Meisterschaft-API nicht verfuegbar'
    else
        cap=math.max(125,math.min(155,tonumber(S.manualCriticalCap) or 125))
        capSource='manuell eingestellt'
    end
    local shadow=S.ReadShadowCorrection()
    result.criticalBase=50
    result.criticalAdvanced=advanced
    result.shadowMundus=shadow
    result.criticalDamage=50+advanced+result.backstabberCriticalDamage+shadow.applied
    result.criticalSources=sources
    result.criticalDamageCap=cap
    result.criticalCapSource=capSource
    result.criticalCapKnown=known or S.criticalCapAutomatic==false
    result.rawCriticalDamage=result.criticalDamage+(result.targetBonusesEnabled and result.targetCriticalDamage or 0)
    result.effectiveCriticalDamage=math.min(result.rawCriticalDamage,cap)
    result.criticalDamageOvercap=math.max(0,result.rawCriticalDamage-cap)
    result.displayCriticalDamage=S.criticalShowEffective~=false and result.effectiveCriticalDamage or result.rawCriticalDamage
end

local function describe(v,title)
    local age=math.max(0,(GetGameTimeMilliseconds()-v.sampleTime)/1000)
    local lines={string.format('%s | Messung #%d | vor %.1f s | Ziel: %s',title,v.sampleNumber or 0,age,v.targetName or 'keines')}
    lines[#lines+1]=string.format('Basis %.1f%% + Charakterbonus %.1f%% + Backstabber %.1f%% + Schatten-Korrektur %.1f%%',v.criticalBase,v.criticalAdvanced,v.backstabberCriticalDamage,v.shadowMundus.applied)
    if v.backstabberCriticalDamage>0 then lines[#lines+1]='Backstabber: CP-Stufen erkannt; FLANKE ANGENOMMEN, nicht automatisch erkannt.' end
    lines[#lines+1]='Charakterbonus enthaelt bereits Ausruestung, eigene Buffs und weitere Spielboni; diese werden nicht erneut addiert.'
    local keys={}
    for key in pairs(v.criticalSources) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local source=v.criticalSources[key]
        lines[#lines+1]=string.format('Ziel +%.1f%%: %s (ID %d, %s)%s',source.value,source.name,source.id,source.origin,v.targetBonusesEnabled and '' or ' [nicht eingerechnet]')
    end
    lines[#lines+1]=string.format('RECHNERISCH %.1f%% | NUTZBAR %.1f%% | CAP %.1f%% | DARUEBER %.1f%%',v.rawCriticalDamage,v.effectiveCriticalDamage,v.criticalDamageCap,v.criticalDamageOvercap)
    lines[#lines+1]='Cap: '..v.criticalCapSource
    lines[#lines+1]='Nutzbar = rechnerischer Bonus am Cap begrenzt, kein aus Treffern gemessener Multiplikator.'
    local shadow=v.shadowMundus
    if shadow.active then
        lines[#lines+1]=shadow.known and string.format('Schatten/Goettlich: berechnet %.1f%%, Effekttext %.1f%%, Differenz %.1f%%; angewendet %.1f%%',shadow.expected,shadow.reported,shadow.difference,shadow.applied)
            or 'Schatten aktiv, Werte nicht vollstaendig lesbar: keine Korrektur.'
    end
    return lines
end
function S.GetCriticalDamageReport(mode)
    local live=S.ReadStats()
    local recorded,test,active=S.GetRecordedCriticalSample()
    local lines={string.format('IsoStats2 %s | CD-Diagnose | Test #%d',S.version,test)}
    local function append(values) for _,line in ipairs(values) do lines[#lines+1]=line end end
    if mode~='last' then append(describe(live,'AKTUELL')) end
    if mode~='live' then
        if recorded then append(describe(recorded,active and 'HOECHSTER BEOBACHTETER KAMPFWERT - gespeichert, nicht live' or 'LETZTER TEST: HOECHSTER BEOBACHTETER WERT - gespeichert, nicht live'))
        else lines[#lines+1]='Noch keine CD-Testmessung gespeichert. Erneut angreifen.' end
    end
    return lines
end

function S.InitializeCriticalDamage()
    S.InvalidateCriticalCache()
    for _,event in pairs({EVENT_SKILL_POINTS_CHANGED,EVENT_PLAYER_ACTIVATED}) do
        EVENT_MANAGER:RegisterForEvent(S.name..'CriticalCache'..tostring(event),event,S.InvalidateCriticalCache)
    end
end
