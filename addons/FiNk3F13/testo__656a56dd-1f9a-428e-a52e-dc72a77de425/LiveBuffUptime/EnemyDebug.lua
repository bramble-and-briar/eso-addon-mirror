local Debug = {}
LiveBuffUptimeEnemyDebug = Debug
local current, last
local MAX_ENEMIES, MAX_PAIRS, MAX_EVENTS = 48, 256, 12

function Debug.Begin(time, running)
    current = running ~= false and {started = time, enemies = {}, enemyCount = 0, effects = {}, pairs = 0, dropped = 0} or nil
end

function Debug.Enemy(id, name, time)
    if not current or type(id) ~= "number" or id <= 0 then return end
    local enemy = current.enemies[id]
    if not enemy then
        if current.enemyCount >= MAX_ENEMIES then current.dropped = current.dropped + 1; return end
        enemy = {first = time, last = time}
        current.enemies[id] = enemy
        current.enemyCount = current.enemyCount + 1
    end
    enemy.name, enemy.last = name or enemy.name, time
end

function Debug.Effect(id, targetId, time, change, slot, ends, source, tag, accepted)
    if not current or not id or type(targetId) ~= "number" or targetId <= 0 then return end
    local effects = current.effects[id]
    if not effects then
        if current.pairs >= MAX_PAIRS then current.dropped = current.dropped + 1; return end
        effects = {}; current.effects[id] = effects
    end
    local effect = effects[targetId]
    if not effect then
        if current.pairs >= MAX_PAIRS then current.dropped = current.dropped + 1; return end
        effect = {sources = {}, events = {}, count = 0, first = time, last = time, accepted = 0, pending = 0}
        effects[targetId] = effect
        current.pairs = current.pairs + 1
    end
    source = source or "Unbekannt"
    local counts = effect.sources[source]
    if not counts then counts = {gained = 0, updated = 0, faded = 0}; effect.sources[source] = counts end
    if change == EFFECT_RESULT_GAINED then counts.gained = counts.gained + 1
    elseif change == EFFECT_RESULT_UPDATED then counts.updated = counts.updated + 1
    elseif change == EFFECT_RESULT_FADED then counts.faded = counts.faded + 1 end
    effect.first, effect.last = math.min(effect.first, time), math.max(effect.last, time)
    effect.count = effect.count + 1
    if accepted == true then effect.accepted = effect.accepted + 1 end
    if accepted == "pending" then effect.pending = effect.pending + 1 end
    if #effect.events == MAX_EVENTS then table.remove(effect.events, 1) end
    effect.events[#effect.events + 1] = {time = time, change = change, slot = slot, ends = ends,
        source = source, tag = tag, accepted = accepted == true, pending = accepted == "pending"}
end

function Debug.Finish(starts, ends)
    if not current then return end
    current.started, current.ended = starts, ends
    last, current = current, nil
end

function Debug.Report(id, targetId)
    local fight = current or last
    if not fight then d("LBU Debuff-Debug: Noch kein erfasster Kampf. Wird automatisch im Kampf aufgezeichnet."); return end
    d(string.format("LBU Debuff-Debug ID %d: %s | %d Gegner | Messfenster %.2fs", id,
        current and "Kampf laeuft" or "letzter abgeschlossener Kampf", fight.enemyCount,
        math.max(0, (fight.ended or (GetFrameTimeSeconds and GetFrameTimeSeconds()) or fight.started) - fight.started)))
    local ids = {}
    for enemyId in pairs(fight.enemies) do if not targetId or enemyId == targetId then ids[#ids + 1] = enemyId end end
    table.sort(ids)
    if #ids == 0 then d("Keine passende bestaetigte Gegner-ID in diesem Kampf.") end
    for _, enemyId in ipairs(ids) do
        local enemy = fight.enemies[enemyId]
        local effect = fight.effects[id] and fight.effects[id][enemyId]
        if not effect then
            d(string.format("[%s] %s: UNBEKANNT - keine Effektmeldung fuer diese ID.", tostring(enemyId), enemy.name or "Gegner"))
        else
            local sources = {}
            local gained, faded = 0, 0
            for source, counts in pairs(effect.sources) do
                sources[#sources + 1] = string.format("%s %d/%d/%d", source, counts.gained, counts.updated, counts.faded)
                gained, faded = gained + counts.gained, faded + counts.faded
            end
            table.sort(sources)
            local warning = gained == 0 and faded > 0 and " | WARN: Ende ohne Beginn" or ""
            if effect.accepted == 0 and effect.pending == 0 then warning = warning .. " | WARN: keine Meldung zugeordnet" end
            if effect.pending > 0 then warning = warning .. string.format(" | %d vorgemerkt, Gegner-ID bestaetigt", effect.pending) end
            d(string.format("[%s] %s: %s | erste %.2fs / letzte %.2fs%s", tostring(enemyId), enemy.name or "Gegner",
                table.concat(sources, "; "), effect.first - fight.started, effect.last - fight.started, warning))
            if targetId then
                d(string.format("Letzte %d von %d Meldungen:", #effect.events, effect.count))
                for _, event in ipairs(effect.events) do
                    local action = event.change == EFFECT_RESULT_GAINED and "erhalten" or event.change == EFFECT_RESULT_UPDATED and "erneuert"
                        or event.change == EFFECT_RESULT_FADED and "beendet" or tostring(event.change)
                    d(string.format("+%.3fs %s %s | Slot %s | Ende %s | Tag %s | %s", event.time - fight.started,
                        event.source, action, tostring(event.slot), event.ends and event.ends > 0 and string.format("%.3fs", event.ends - fight.started) or "nicht angegeben",
                        event.tag and event.tag ~= "" and event.tag or "ohne Tag", event.pending and "vorgemerkt"
                            or event.accepted and "zugeordnet" or "nicht zugeordnet"))
                end
            end
        end
    end
    if fight.dropped > 0 then d(string.format("WARN: Diagnose-Limit erreicht, %d Eintraege ausgelassen.", fight.dropped)) end
    d("Erhalten/erneuert/beendet zaehlen Meldungen je Quelle, keine Casts. Auch vorhandene Meldungen beweisen keine vollstaendige Erfassung.")
end
