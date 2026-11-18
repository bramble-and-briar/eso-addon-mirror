-- Optional, session-only inspection of this addon's private LibCombat callbacks.
-- Never modifies library fights, DPS, external addons or saved combat data.
local analysis = {enabled = false, page = 0}
SimpleGroupDPS_CombatAnalysis = analysis
local LC = SimpleGroupDPSCombat
local NAME = "SimpleGroupDPSAnalysis"
local report, callbacks = nil, {}
local MAX_EFFECTS, PAGE_SIZE = 2000, 8
local labels = {
    [0] = "Zielmeldungen", "Messwerte", "Kampfberichte", "Gruppen-Messwerte",
    "Schaden ausgehend", "Schaden eingehend", "Eigenschaden",
    "Heilung ausgehend", "Heilung eingehend", "Selbstheilung",
    "Effekte eingehend", "Effekte ausgehend", "Gruppeneffekte eingehend", "Gruppeneffekte ausgehend",
    "Charakterwerte", "Ressourcen", "Kampfmeldungen", "Todesmeldungen",
    "Erweiterte Charakterwerte", "Fertigkeitszeiten", "Boss-Leben", "Leistung",
    "Todesrueckblick", "Schnellzugriff", "Synergien",
}
local scopes = {[10] = "auf dir", [11] = "auf Ziel", [12] = "Gruppe eingehend", [13] = "Gruppe ausgehend"}
local function now() return GetGameTimeMilliseconds() end
local function emit(text) d("[SGD Analyse] " .. text) end
local function endpoint(fight, fallback)
    if LC.data.inCombat == false and (fight.combatend or 0) > 0 then return fight.combatend end
    return fallback or now()
end
local function captureFight(fight)
    if not fight or (fight.combatstart or -1) < 0 then return nil end
    if report and report.fight == fight then return not report.finished and report or nil end
    report = {fight = fight, startMS = math.max(fight.combatstart, analysis.enabledAt or 0),
        partial = (analysis.enabledAt or 0) > fight.combatstart, counts = {}, effects = {}, effectCount = 0,
        dropped = 0, finished = false}
    analysis.page = 0
    return report
end
local function getEffect(r, event, timeMS, unitId, abilityId, change, effectType, stacks, sourceType, slot)
    if type(unitId) ~= "number" or type(abilityId) ~= "number" or type(timeMS) ~= "number" then return end
    if change ~= EFFECT_RESULT_GAINED and change ~= EFFECT_RESULT_UPDATED and change ~= EFFECT_RESULT_FADED then return end
    local key = table.concat({event, unitId, abilityId, effectType or 0}, ":")
    local effect = r.effects[key]
    if not effect then
        if r.effectCount >= MAX_EFFECTS then r.dropped = r.dropped + 1; return end
        effect = {event = event, unitId = unitId, abilityId = abilityId, effectType = effectType,
            instances = {}, activeCount = 0, durationMS = 0, gains = 0, maxStacks = 0,
            partial = change ~= EFFECT_RESULT_GAINED}
        r.effects[key] = effect
        r.effectCount = r.effectCount + 1
    end
    local time = math.max(r.startMS, math.min(timeMS, endpoint(r.fight, timeMS)))
    -- Separate effect slots/sources prevent a fade from ending another source's buff.
    local instance = tostring(slot or 0) .. ":" .. tostring(sourceType or 0)
    if change == EFFECT_RESULT_FADED then
        if effect.instances[instance] then
            effect.instances[instance] = nil
            effect.activeCount = effect.activeCount - 1
            if effect.activeCount == 0 then
                effect.durationMS = effect.durationMS + math.max(0, time - effect.activeSince)
                effect.activeSince = nil
            end
        else
            effect.partial = true -- no invented uptime for an unobserved start
        end
    else
        effect.maxStacks = math.max(effect.maxStacks, tonumber(stacks) or 1)
        if not effect.instances[instance] then
            if effect.activeCount == 0 then effect.activeSince = time end
            effect.instances[instance] = true
            effect.activeCount = effect.activeCount + 1
            effect.gains = effect.gains + 1
        end
    end
end
function analysis:FinishFight(fight, timeMS, reason)
    if not report or report.fight ~= fight or report.finished then return end
    report.endMS = math.max(report.startMS, endpoint(fight, timeMS))
    report.finished, report.reason = true, reason or "Kampfende"
end
local function onEvent(event, a, ...)
    if not analysis.enabled or analysis.paused then return end
    local fight = event == SGD_LIBCOMBAT_EVENT_FIGHTSUMMARY and a or LC:GetMeterFight()
    if event == SGD_LIBCOMBAT_EVENT_FIGHTSUMMARY and report and report.fight == fight and report.finished then
        report.counts[event] = (report.counts[event] or 0) + 1
        return
    end
    local r = captureFight(fight)
    if not r then return end
    r.counts[event] = (r.counts[event] or 0) + 1
    if scopes[event] then getEffect(r, event, a, ...) end
    if event == SGD_LIBCOMBAT_EVENT_FIGHTSUMMARY then analysis:FinishFight(fight, now()) end
end
local function setCallbacks(enabled)
    for event, registered in pairs(callbacks) do
        if registered then LC:UnregisterForCombatEvent(NAME, event) end
    end
    callbacks = {}
    if enabled then
        for event = SGD_LIBCOMBAT_EVENT_MIN, SGD_LIBCOMBAT_EVENT_MAX do
            callbacks[event] = LC:RegisterForCombatEvent(NAME, event, onEvent) == true
        end
    end
end
function analysis:SetPaused(paused)
    self.paused = paused == true
    setCallbacks(self.enabled and not self.paused)
end
function analysis:SetEnabled(enabled)
    enabled = enabled == true
    if enabled == self.enabled then return end
    if enabled then
        self.enabledAt = now()
        -- Each diagnostic recording gets its own observation window, even mid-fight.
        report, self.page, self.enabled = nil, 0, true
        local dead = (IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player"))
            or (IsUnitDead and IsUnitDead("player"))
        self:SetPaused(not IsUnitGrouped("player") and dead)
        if not self.paused then captureFight(LC:GetMeterFight()) end
    else
        if report and not report.finished then
            self:FinishFight(report.fight, now(), "Analyse ausgeschaltet")
            report.partial = true
        end
        self.enabled = false
        setCallbacks(false)
    end
end
function analysis:GetReport()
    if self.enabled and not self.paused then captureFight(LC:GetMeterFight()) end
    if not report then return nil end
    local endMS = report.endMS or endpoint(report.fight)
    local durationMS = math.max(0, endMS - report.startMS)
    local result = {counts = {}, rows = {}, durationMS = durationMS, partial = report.partial,
        dropped = report.dropped, finished = report.finished, reason = report.reason}
    for key, count in pairs(report.counts) do result.counts[key] = count end
    for _, effect in pairs(report.effects) do
        local duration = effect.durationMS
        if effect.activeSince then duration = duration + math.max(0, endMS - effect.activeSince) end
        duration = math.min(durationMS, math.max(0, duration))
        local unit = (report.fight.units or {})[effect.unitId]
        local target = unit and unit.name or (effect.unitId == LC.data.playerid and "Spieler") or ("Einheit " .. tostring(effect.unitId))
        local name = GetAbilityName(effect.abilityId)
        if type(name) ~= "string" or name == "" then name = "Faehigkeit " .. tostring(effect.abilityId) end
        result.rows[#result.rows + 1] = {name = name, target = target, abilityId = effect.abilityId,
            unitId = effect.unitId, scope = scopes[effect.event], effectType = effect.effectType,
            durationMS = duration, uptime = durationMS > 0 and duration / durationMS * 100 or 0,
            maxStacks = effect.maxStacks, gains = effect.gains, partial = effect.partial}
    end
    table.sort(result.rows, function(a,b)
        if a.durationMS ~= b.durationMS then return a.durationMS > b.durationMS end
        if a.abilityId ~= b.abilityId then return a.abilityId < b.abilityId end
        if a.unitId ~= b.unitId then return a.unitId < b.unitId end
        return a.scope < b.scope
    end)
    return result
end
function analysis:PrintOverview()
    local r = self:GetReport()
    emit("LibCombat " .. tostring(LC.version) .. " | Analyse " .. (self.enabled and "AN" or "AUS") .. (self.paused and " | Solo-Tod: pausiert" or ""))
    if not r then emit("Noch kein Kampf aufgezeichnet. Vor dem Test /sgdanalyse an eingeben."); return end
    emit(string.format("%s | Beobachtungszeit %.1f s%s", r.finished and (r.reason or "Beendet") or "Laufend",
        r.durationMS / 1000, r.partial and " | Teilaufnahme" or ""))
    for event = SGD_LIBCOMBAT_EVENT_MIN, SGD_LIBCOMBAT_EVENT_MAX do
        emit((labels[event] or tostring(event)) .. ": " .. tostring(r.counts[event] or 0))
    end
    emit("Zaehler zeigen gelieferte Meldungen, keine garantierte Vollstaendigkeit. 0 kann bedeuten: kein passendes Ereignis.")
    emit("Erweiterte Charakterwerte sind im Original LibCombat 89 intern deaktiviert; dort sind 0 Meldungen zu erwarten.")
    if r.dropped > 0 then emit("Effektgrenze erreicht: " .. tostring(r.dropped) .. " weitere Effektmeldungen nicht ausgewertet.") end
    emit("Buffs/Debuffs: /sgdbuffs 1 (weitere Seiten: 2, 3, ...).")
end
function analysis:PrintEffects(page)
    local r = self:GetReport()
    if not r then emit("Noch keine Aufnahme. /sgdanalyse an vor dem Testkampf."); return end
    local pages = math.max(1, math.ceil(#r.rows / PAGE_SIZE))
    page = math.max(1, math.min(pages, math.floor(tonumber(page) or 1)))
    self.page = page
    emit(string.format("Buffs/Debuffs %d/%d | %d Effekte | Beobachtungszeit %.1f s%s", page, pages,
        #r.rows, r.durationMS / 1000, r.partial and " | Teilaufnahme" or ""))
    for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #r.rows) do
        local row = r.rows[index]
        local kind = row.effectType == BUFF_EFFECT_TYPE_BUFF and "Buff"
            or row.effectType == BUFF_EFFECT_TYPE_DEBUFF and "Debuff" or "Effekt"
        emit(string.format("%s: %s [%d] | %s (%s) | %.1f s / %.1f%% | max. %dx%s",
            kind, row.name, row.abilityId, row.target, row.scope, row.durationMS / 1000, row.uptime,
            row.maxStacks, row.partial and " | Beginn unbekannt" or ""))
    end
    if #r.rows == 0 then emit("Keine Effektmeldungen im beobachteten Kampf empfangen.") end
    if r.dropped > 0 then emit("Effektgrenze erreicht; Bericht unvollstaendig.") end
    emit("Wirkzeit = beobachtete Zeit je Ziel, ohne Doppelzaehlung ueberlappender Quellen. Keine globale Gruppen-Buffabdeckung.")
end
function analysis:NextEffectsPage()
    local r = self:GetReport()
    local pages = r and math.max(1, math.ceil(#r.rows / PAGE_SIZE)) or 1
    self:PrintEffects(((self.page or 0) % pages) + 1)
end
function analysis:Command(text)
    text = string.lower(tostring(text or "")):match("^%s*(.-)%s*$")
    if text == "an" or text == "on" then
        self:SetEnabled(true); emit("AN. Vor Kampfstart einschalten; Aufnahme bleibt nur bis /reloadui bzw. zum naechsten Kampf erhalten.")
    elseif text == "aus" or text == "off" then
        self:SetEnabled(false); emit("AUS. Letzter Bericht bleibt in dieser Sitzung abrufbar.")
    elseif text:match("^buffs") then self:PrintEffects(text:match("(%d+)$"))
    else self:PrintOverview() end
end
