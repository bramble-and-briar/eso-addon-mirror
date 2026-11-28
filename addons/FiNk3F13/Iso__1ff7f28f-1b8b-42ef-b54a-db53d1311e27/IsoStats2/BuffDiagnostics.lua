local S=IsoStats2
local lastTarget
local families={fire='Elementarkatalysator: Feuer',frost='Elementarkatalysator: Frost',
    shock='Elementarkatalysator: Blitz',catalystDummy='Elementarkatalysator: Puppenversion',
    minorBrittle='Kleinere Bruechigkeit',majorBrittle='Groessere Bruechigkeit'}
local origins={visible='direkt am Ziel sichtbar',effect='Effektereignis',combat='Kampfereignis'}

local function visible(tag)
    local entries={}
    for index=1,GetNumBuffs(tag) do
        local name,_,ends,_,stacks,_,_,_,_,_,id=GetUnitBuffInfo(tag,index)
        entries[#entries+1]={id=id or 0,name=name or '',stacks=stacks or 0,ends=ends or 0}
    end
    table.sort(entries,function(a,b) return a.id<b.id end)
    return entries
end

function S.CaptureCriticalBuffs(v)
    v.playerBuffDiagnostics=visible('player')
    v.targetBuffDiagnostics=v.targetName and visible('reticleover') or {}
    if v.targetName then lastTarget=v end
end
function S.ResetCriticalBuffDiagnostics() lastTarget=nil end

local function details(v,lines,title,all)
    lines[#lines+1]=title..' | Ziel: '..(v.targetName or 'keines')
    lines[#lines+1]=string.format('50.0%% Basis + %.1f%% Charakter + %.1f%% Hinterhalt + %.1f%% Schatten = %.1f%% OHNE Ziel',
        v.criticalAdvanced,v.backstabberCriticalDamage,v.shadowMundus.applied,v.criticalDamage)
    lines[#lines+1]='Charakterwert: Zusatzbonus OHNE die 50% Basis; Spielerbuffs sind darin enthalten und werden nicht erneut addiert.'
    local keys={}
    for key in pairs(v.criticalSources) do keys[#keys+1]=key end
    table.sort(keys)
    local total=0
    for _,key in ipairs(keys) do
        local entry=v.criticalSources[key]
        total=total+entry.value
        lines[#lines+1]=string.format('ZIEL +%.1f%% | %s | %s | ID %d | %s%s',entry.value,
            families[key] or key,entry.name or '?',entry.id,origins[entry.origin] or tostring(entry.origin),
            v.targetBonusesEnabled and '' or ' | NICHT addiert: Zielboni ausgeschaltet')
    end
    if #keys==0 then lines[#lines+1]='Keine unterstuetzten Ziel-Kritboni erkannt.' end
    lines[#lines+1]=string.format('ZIEL-SUMME %.1f%% erkannt, %.1f%% eingerechnet | %.1f%% + %.1f%% = %.1f%%',
        total,v.targetBonusesEnabled and total or 0,v.criticalDamage,v.targetBonusesEnabled and total or 0,v.rawCriticalDamage)
    lines[#lines+1]=string.format('HUD %.1f%% | ROH %.1f%% | AM CAP %.1f%% | CAP %.1f%% | UEBERSCHUSS %.1f%%',
        v.displayCriticalDamage,v.rawCriticalDamage,v.effectiveCriticalDamage,v.criticalDamageCap,v.criticalDamageOvercap)
    lines[#lines+1]='Cap-Grund: '..v.criticalCapSource
    lines[#lines+1]='HUD-Rohwertanzeige: maximal 200%; ROH bleibt vollstaendig. Spiel-Cap und Ueberschuss stehen separat.'
    if v.backstabberCriticalDamage>0 then lines[#lines+1]='Hinterhalt: Flanke nur ANGENOMMEN, nicht gemessen.' end
    if v.targetName and not v.trackedTargetId then
        lines[#lines+1]='Ziel-ID noch nicht sicher zugeordnet: Ereignisboni koennen fehlen; direkt sichtbare Effekte werden ausgewertet.'
    end
    if all then
        for _,group in ipairs({{'SPIELER',v.playerBuffDiagnostics},{'ZIEL',v.targetBuffDiagnostics}}) do
            lines[#lines+1]=group[1]..': sichtbare Effekte (Rohliste, keine zusaetzliche Addition)'
            for _,entry in ipairs(group[2] or {}) do
                local remaining=entry.ends>0 and string.format('%.1fs',math.max(0,entry.ends-v.sampleTime/1000)) or 'dauerhaft/unbekannt'
                lines[#lines+1]=string.format('%s | ID %d | Stapel %d | Rest %s',entry.name,entry.id,entry.stacks,remaining)
            end
            if #(group[2] or {})==0 then lines[#lines+1]='Keine sichtbaren Effekte.' end
        end
    end
end

function S.GetCriticalBuffReport(mode,all)
    local live=S.ReadStats()
    local lines={'IsoStats2 '..S.version..' | Krit-Buffdiagnose'}
    if mode=='last' then
        if lastTarget then
            details(lastTarget,lines,string.format('LETZTES ANVISIERTES ZIEL - GESPEICHERT, NICHT LIVE (vor %.1fs)',
                math.max(0,(GetGameTimeMilliseconds()-lastTarget.sampleTime)/1000)),all)
        else lines[#lines+1]='Noch kein Ziel gespeichert. Puppe kurz anvisieren.' end
    else
        details(live,lines,'LIVE',all)
        if mode~='live' and not live.targetName then
            if lastTarget then
                details(lastTarget,lines,string.format('LETZTES ANVISIERTES ZIEL - GESPEICHERT, NICHT LIVE (vor %.1fs)',
                    math.max(0,(GetGameTimeMilliseconds()-lastTarget.sampleTime)/1000)),all)
            else lines[#lines+1]='Puppe kurz anvisieren; danach bleibt die Ziel-Diagnose beim Oeffnen des Chats erhalten.' end
        end
    end
    lines[#lines+1]='Lucent Echoes und andere Spielerbuffs werden hier nicht einzeln numerisch zerlegt: Charakterwert kommt aus ESO. Rohliste: /isostats2 buffs all'
    return lines
end
