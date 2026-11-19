-- Optional, session-only timing observation. Never supplies combat calculations.
local diagnostic = { enabled = false }
SimpleGroupDPS_TimingDiagnostics = diagnostic
local record, previous
local LIMIT = 8
local HIT_LIMIT, PAGE_SIZE = 2000, 8
local function output(text)
    if d then d("[SimpleGroupDPS Zeit] " .. text) end
end
local function offset(time, base)
    return type(time) == "number" and string.format("%+.0f ms", time - base) or "nicht empfangen"
end
function diagnostic:BeginFight(fight, partial)
    if not self.enabled then return end
    if record and record.first then previous = record end
    record = { fight = fight, partial = partial == true, targets = {}, order = {}, omitted = 0,
        hits = {}, hitCount = 0, hitTotal = 0 }
end
function diagnostic:ObserveDamage(fight, timeMS, targetId, result, sourceId, abilityId, value, overflow)
    if not self.enabled then return end
    if not record or record.fight ~= fight then self:BeginFight(fight, true) end
    if record.finished then return end
    record.first = record.first or timeMS
    local gap = record.last and timeMS - record.last or 0
    record.last = timeMS
    record.hitCount = record.hitCount + 1
    value, overflow = value or 0, overflow or 0
    record.hitTotal = record.hitTotal + value + overflow
    if #record.hits < HIT_LIMIT then
        local unit = fight.units and fight.units[targetId]
        local source = fight.units and fight.units[sourceId]
        record.hits[#record.hits + 1] = { time = timeMS, gap = gap, target = unit and unit.name or tostring(targetId),
            pet = source and source.unitType == COMBAT_UNIT_TYPE_PLAYER_PET,
            ability = abilityId, value = value, shield = overflow, result = result }
    end
    if not targetId then return end
    local target = record.targets[targetId]
    if not target then
        if #record.order >= LIMIT then record.omitted = record.omitted + 1; return end
        local unit = fight.units and fight.units[targetId]
        target = { name = unit and unit.name or tostring(targetId), first = timeMS, hits = 0 }
        record.targets[targetId] = target
        record.order[#record.order + 1] = targetId
    end
    target.last, target.hits = timeMS, target.hits + 1
end
function diagnostic:FinishFight(fight)
    if not self.enabled or not record or record.fight ~= fight or record.finished then return end
    record.finished = GetGameTimeMilliseconds()
    record.combatEnd = fight.combatend and fight.combatend > 0 and fight.combatend or nil
    record.nativeFirst, record.nativeLast = fight.dpsstart, fight.dpsend
    record.total, record.dps = fight.damageOutTotal, fight.DPSOut
    record.duration = fight.dpstime
end
local function observeDeath(_, result, _, _, _, _, _, _, _, _, _, _, _, _, _, targetId)
    if not diagnostic.enabled or not record then return end
    local target = record.targets[targetId]
    if not target then return end -- Only targets actually hit in this recorded fight.
    local timeMS = GetGameTimeMilliseconds()
    if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP then
        target.death = target.death or timeMS
    elseif result == ACTION_RESULT_KILLING_BLOW then
        target.killingBlow = target.killingBlow or timeMS
    end
end
function diagnostic:SetEnabled(enabled)
    enabled = enabled == true
    if enabled == self.enabled then return end
    self.enabled = enabled
    if enabled then record, previous = nil, nil end
    for index, result in pairs({ Died = ACTION_RESULT_DIED, DiedXP = ACTION_RESULT_DIED_XP,
        KillingBlow = ACTION_RESULT_KILLING_BLOW }) do
        local name = "SimpleGroupDPSTiming" .. index
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_COMBAT_EVENT)
        if enabled then
            EVENT_MANAGER:RegisterForEvent(name, EVENT_COMBAT_EVENT, observeDeath)
            EVENT_MANAGER:AddFilterForEvent(name, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
        end
    end
end
function diagnostic:Print()
    if not record or not record.first then
        output("Noch keine Aufnahme. Vor dem Kampf /sgdzeit an eingeben.")
        return
    end
    local base = record.first
    output((record.partial and "Teilaufnahme" or "Aufnahme ab Kampfstart") .. "; alle Zeiten relativ zum ersten eigenen Schaden (0 ms).")
    output("Letzter Schaden: " .. offset(record.last, base) .. "; Kampfende: " .. offset(record.combatEnd, base)
        .. "; Messabschluss: " .. offset(record.finished, base))
    if record.finished then
        output(string.format("Schaden: %.0f; DPS: %.0f; native DPS-Zeit: %.3f s; native Grenzen: %s / %s",
            record.total or 0, record.dps or 0, record.duration or 0,
            offset(record.nativeFirst, base), offset(record.nativeLast, base)))
    else output("Messung noch nicht abgeschlossen.") end
    for _, id in ipairs(record.order) do
        local target = record.targets[id]
        output(string.format("%s: %d Treffer; erster/letzter: %s / %s; Tod: %s; toedlicher Treffer: %s",
            target.name, target.hits, offset(target.first, base), offset(target.last, base),
            offset(target.death, base), offset(target.killingBlow, base)))
    end
    if record.omitted > 0 then output("Weitere Ziele nicht einzeln erfasst (Grenze: 8 Ziele).") end
    output("Lokale Empfangszeiten; keine Serverzeit und keine Aenderung der DPS. Bericht nur im Sitzungsspeicher.")
    output("Einzeltreffer: /sgdtreffer 1; letzte Seite: /sgdtreffer ende; vorheriger Kampf: /sgdtreffer vorher 1.")
end
function diagnostic:PrintHits(text)
    text = string.lower((text or ""):match("^%s*(.-)%s*$"))
    local usePrevious = text:match("^vorher%s*") ~= nil
    if usePrevious then text = text:gsub("^vorher%s*", "") end
    local selected = usePrevious and previous or record
    if usePrevious and not previous then selected = nil end
    if not selected or not selected.first then
        output("Keine Trefferaufnahme fuer diesen Kampf. Vor dem Test /sgdzeit an eingeben.")
        return
    end
    local pages = math.max(1, math.ceil(#selected.hits / PAGE_SIZE))
    local page = text == "ende" and pages or tonumber(text == "" and "1" or text)
    if not page or page ~= math.floor(page) or page < 1 or page > pages then
        output("Seite 1 bis " .. pages .. ": /sgdtreffer [vorher] <Seite|ende>")
        return
    end
    output(string.format("%s%s: Seite %d/%d; %d Treffer; Summe %.0f; Zeiten ab erstem Schaden.",
        usePrevious and "Vorheriger Kampf" or "Letzter/aktueller Kampf", selected.partial and " (Teilaufnahme)" or "",
        page, pages, selected.hitCount, selected.hitTotal))
    for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #selected.hits) do
        local hit = selected.hits[index]
        local critical = hit.result == ACTION_RESULT_CRITICAL_DAMAGE or hit.result == ACTION_RESULT_DOT_TICK_CRITICAL
        local dot = hit.result == ACTION_RESULT_DOT_TICK or hit.result == ACTION_RESULT_DOT_TICK_CRITICAL
        local ability = hit.ability and GetAbilityName(hit.ability) or ""
        if not ability or ability == "" then ability = "Faehigkeit" end
        output(string.format("#%d %s (Abstand %d ms): %s [%s]; %.0f Schaden%s; %s%s%s -> %s",
            index, offset(hit.time, selected.first), hit.gap, ability, tostring(hit.ability or "?"), hit.value,
            hit.shield > 0 and string.format(" + %.0f Schild", hit.shield) or "",
            critical and "kritisch" or "normal", dot and "/DoT" or "", hit.pet and "/Pet" or "", hit.target))
    end
    if selected.hitCount > #selected.hits then
        output("Aufnahmelimit: nur die ersten " .. HIT_LIMIT .. " Treffer gespeichert; Anzahl und Summe enthalten alle Treffer.")
    end
    output("Nur Empfangszeiten. Der naechste Kampf ersetzt die vorherige Aufnahme; /reloadui loescht beide.")
end
function diagnostic:Command(text)
    text = string.lower((text or ""):match("^%s*(.-)%s*$"))
    if text == "an" or text == "on" then
        self:SetEnabled(true)
        output("Aufnahme an. Jetzt kaempfen, danach /sgdzeit eingeben.")
    elseif text == "aus" or text == "off" then
        self:SetEnabled(false)
        output("Aufnahme aus. Letzter Bericht bleibt bis /reloadui erhalten.")
    else self:Print() end
end
