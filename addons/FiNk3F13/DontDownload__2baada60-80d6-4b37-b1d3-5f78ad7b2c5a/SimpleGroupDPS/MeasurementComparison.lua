-- Diagnostic only. Native BattleScrolls values never enter the meter, HUD or bridge.
local comparison = {}
SimpleGroupDPS_MeasurementComparison = comparison
local latest, lastCheck

function comparison:Capture(force)
    local now = GetGameTimeMilliseconds()
    if not force and lastCheck and now - lastCheck < 1000 then return false end
    lastCheck = now
    local bs = BattleScrolls
    if not bs or not bs.state or not bs.state.initialized or not bs.arithmancer
        or type(bs.arithmancer.Make) ~= 'function' then return false end
    local own = SimpleGroupDPS_DamageMeter:GetComparisonSnapshot()
    if not own then return false end
    local ok, result = pcall(function()
        -- Same unfiltered live calculator as BattleScrolls combat/ticker.lua.
        local calc = bs.arithmancer:Make(bs.state)
        local native = {
            total = calc:personalTotalDamage(), durationMS = calc:getDurationS() * 1000,
            dps = calc:personalDPS(), groupTotal = calc:groupTotalDamage(),
            rawHPS = calc:personalRawHPSOut(), effectiveHPS = calc:personalEffectiveHPSOut(),
            startMS = bs.state.fightStartTimeMs, endMS = bs.state.lastDamageDoneMs,
            recoveryRaw = bs.healthRecovery and bs.healthRecovery.appliedRaw,
            recoveryEffective = bs.healthRecovery and bs.healthRecovery.appliedEffective,
        }
        if type(bs.arithmancer.ForBosses) == 'function' then
            local bossCalc = bs.arithmancer:ForBosses(bs.state)
            if bossCalc then
                native.bossTotal, native.groupBossTotal = bossCalc:personalTotalDamage(), bossCalc:groupTotalDamage()
            end
        end
        local targets = {}
        for _, byTarget in pairs(bs.state.damageByUnitId or {}) do
            for id, damage in pairs(byTarget) do
                -- Live state has precomputed effective totals, not raw/overkill.
                targets[id] = (targets[id] or 0) + (damage.total or 0)
            end
        end
        local differences, ids = {}, {}
        for id in pairs(targets) do ids[id] = true end
        for id in pairs(own.targets) do ids[id] = true end
        for id in pairs(ids) do
            local entry = own.targets[id]
            local ours, theirs = entry and entry.total or 0, targets[id] or 0
            if math.abs(ours - theirs) > 0.01 then
                differences[#differences + 1] = {id = id, own = ours, native = theirs,
                    difference = ours - theirs,
                    name = (entry and entry.name) or (bs.state.unitIdToName or {})[id] or '?'}
            end
        end
        table.sort(differences, function(a,b) return math.abs(a.difference) > math.abs(b.difference) end)
        return {atMS = now, own = own, native = native, differences = differences}
    end)
    if not ok then return false end
    latest = result
    return true
end

function comparison:GetLatest() return latest end

function comparison:Print()
    self:Capture(true)
    if not latest then
        d('[SimpleGroupDPS] Vergleich: Beide Addons muessen denselben Kampf selbst messen. Noch keine gemeinsame Messung vorhanden.')
        return
    end
    local a, b = latest.own, latest.native
    local stats = a.stats
    d(string.format('[SGD2 Vergleich] Eigene Messung / BattleScrolls | Aufnahme vor %.1f s',
        math.max(0, GetGameTimeMilliseconds() - latest.atMS) / 1000))
    d(string.format('Zeit: %.3f / %.3f s | DPS: %.2f / %.2f', stats.durationMS / 1000, b.durationMS / 1000, stats.dps, b.dps))
    d(string.format('Eigener Schaden: %.0f / %.0f | Gruppenschaden: %.0f / %.0f', stats.total, b.total, stats.groupTotal or 0, b.groupTotal))
    d(string.format('Start-ms: %.0f / %.0f | Letzter Schaden-ms: %.0f / %.0f', a.startMS, b.startMS or 0, a.endMS, b.endMS or 0))
    d(string.format('HPS effektiv: %.2f / %.2f | HPS gesamt: %.2f / %.2f', stats.effectiveHPS or 0, b.effectiveHPS, stats.rawHPS or 0, b.rawHPS))
    if b.bossTotal ~= nil then
        d(string.format('Boss-Schaden selbst: %.0f / %.0f | Boss-Schaden Gruppe: %.0f / %.0f',
            stats.bossTotal or 0, b.bossTotal, stats.groupBossTotal or 0, b.groupBossTotal))
    end
    if b.recoveryRaw ~= nil then
        d(string.format('Lebensregeneration effektiv: %.0f / %.0f | gesamt: %.0f / %.0f',
            stats.recoveryEffective or 0, b.recoveryEffective or 0, stats.recoveryRaw or 0, b.recoveryRaw))
    end
    for i = 1, math.min(3, #latest.differences) do
        local target = latest.differences[i]
        d(string.format('Ziel %s [%s]: %.0f / %.0f Schaden', target.name, tostring(target.id), target.own, target.native))
    end
    if #latest.differences == 0 then d('Ziel-Schadenssummen stimmen im Vergleich ueberein.') end
end
