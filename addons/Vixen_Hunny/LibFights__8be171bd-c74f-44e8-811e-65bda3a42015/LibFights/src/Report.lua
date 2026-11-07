--[[
    LibFights - Report
    Turns fight / build / model / ability / set data into readable text lines (with icon
    markup) for chat, the settings panel and the HUD, plus a compact export string.
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local Report = {}
LF.Report = Report

local N, P, C = Util.FormatNumber, Util.FormatPct, Util.CommaNumber
local fmt = string.format

local function Icon(path, size)
    local m = Util.IconMarkup(path, size or 18)
    return m ~= "" and (m .. " ") or ""
end

function Report.FightSummaryLines(f)
    if not f then return { "No fight data yet. Call Start_Logging() and fight something." } end
    local s = f:GetSummary()
    return {
        fmt("|cFFD700Fight #%d: %s|r  (%s)  %s%s", s.id, s.title, s.zone or "", Util.FormatDuration(s.durationMs), s.isActive and " |c00FF00[live]|r" or ""),
        fmt("Damage %s | DPS %s | DPM %s | active DPS %s | boss DPS %s", N(s.damage), N(s.dps), N(s.dpm), N(s.activeDPS), N(s.bossDPS)),
        fmt("Healing %s | HPS %s | HPM %s | raw HPS %s | overheal %s", N(s.healing), N(s.hps), N(s.hpm), N(s.rawHPS), P(s.overhealPct)),
        fmt("Taken %s | DTPS %s | DTPM %s | healing taken %s (HTPS %s)", N(s.damageTaken), N(s.dtps), N(s.dtpm), N(s.healingTaken), N(s.htps)),
        fmt("Mitigated %s | MPS %s | MPM %s | shield %s, block~%s, armor~%s, avoid~%s", N(s.mitigated), N(s.mps), N(s.mpm), N(s.mitigatedShield), N(s.mitigatedBlockEst), N(s.mitigatedArmorEst), N(s.mitigatedAvoidEst)),
        fmt("Shield %s | SPS %s | SPM %s | %s of incoming | applied %s (%d) | peak %s | expired %s%s",
            N(s.shield), N(s.sps), N(s.spm), P(s.shieldPctOfIncoming), N(s.shieldGained), s.shieldApplications,
            N(s.shieldPeak), N(s.shieldExpired),
            s.groupShield > 0 and fmt(" | group shield %s (%s/s)", N(s.groupShield), N(s.groupSPS)) or ""),
        fmt("Crit %s (%d/%d) | avg hit %s | max hit %s (%s) | DoT share %s", P(s.critRate), s.crits, s.hits, N(s.avgHit), N(s.maxHit), s.maxHitAbility or "-", P(s.dotShare)),
        fmt("Casts %d | APM %.1f | LA %d HA %d | weaves %d (%s) | swaps %d | front %s / back %s", s.casts, s.apm, s.lightAttacks, s.heavyAttacks, s.weaves, P(s.weaveRatio), s.barSwaps, P(s.frontBarPct), P(s.backBarPct)),
        fmt("Deaths %d | KBs %d | interrupts %d | CC out %d / in %d | procs %d | targets %d", s.deaths, s.killingBlows, s.interruptsOut, s.ccOut, s.ccIn, s.procActivations, s.numTargets),
    }
end

function Report.ShortLiveText(f)
    if not f then return "No fight." end
    local s = f:GetSummary()
    return fmt("%s %s\nDPS %s  HPS %s\nDTPS %s  MPS %s\nSPS %s  Crit %s  APM %.0f",
        s.isActive and "|c00FF00LIVE|r" or "|cAAAAAALAST|r", Util.FormatDuration(s.durationMs),
        N(s.dps), N(s.hps), N(s.dtps), N(s.mps), N(s.sps), P(s.critRate, 0), s.apm)
end

function Report.AbilityLines(f, kind, limit)
    if not f then return { "No fight." } end
    kind = kind or "damageOut"
    local lines = { fmt("|cFFD700%s breakdown|r", kind) }
    for i, r in ipairs(f:GetAbilityBreakdown(kind, "total", limit or 10)) do
        lines[#lines + 1] = fmt("%d. %s%s [%d] %s (%s) | %s/s | hits %d | crit %s | avg %s | max %s",
            i, Icon(r.icon), r.name, r.id, N(r.total), P(r.pct), N(r.dps), r.hits, P(r.critRate, 0), N(r.avg), N(r.max))
    end
    if #lines == 1 then lines[2] = "(none)" end
    return lines
end

function Report.TargetLines(f, limit)
    if not f then return { "No fight." } end
    local lines = { "|cFFD700Targets|r" }
    for i, t in ipairs(f:GetTargets(limit or 8)) do
        lines[#lines + 1] = fmt("%d. %s%s %s (%s) DPS %s%s", i, t.name ~= "" and t.name or "?", t.isBoss and " |cFF6060[boss]|r" or "", N(t.damage), P(t.pct), N(t.dps), t.killed and " [killed]" or "")
    end
    return lines
end

function Report.EffectLines(f, scope, limit)
    if not f then return { "No fight." } end
    local lines = { fmt("|cFFD700Effect uptimes (%s)|r", scope or "player") }
    local rows = f:GetEffectUptimes(scope or "player", scope == "target")
    for i = 1, math.min(#rows, limit or 15) do
        local e = rows[i]
        lines[#lines + 1] = fmt("%s%s [%d] %s | gains %d | stacks %d%s", Icon(e.icon), e.name, e.id, P(e.uptimePct), e.gains, e.maxStacks, e.castByPlayer and "" or " (external)")
    end
    return lines
end

function Report.ProcLines(f, limit)
    if not f then return { "No fight." } end
    local lines = { "|cFFD700Procs|r" }
    local rows = f:GetProcs()
    for i = 1, math.min(#rows, limit or 15) do
        local p = rows[i]
        lines[#lines + 1] = fmt("%s%s [%d]%s | %d procs (%.1f/min) | dmg %s heal %s | min gap %s | uptime %s",
            Icon(p.icon), p.name, p.id, p.setName and (" |c80C0FF<" .. p.setName .. ">|r") or "",
            p.activations, p.perMinute or 0, N(p.damage), N(p.healing),
            p.minGapMs and fmt("%.1fs", p.minGapMs / 1000) or "-", p.uptimePct and P(p.uptimePct) or "-")
    end
    if #lines == 1 then lines[2] = "(none)" end
    return lines
end

function Report.SetLines(f)
    if not f then return { "No fight." } end
    local lines = { "|cFFD700Sets in fight|r" }
    for _, s in ipairs(f:GetSets()) do
        lines[#lines + 1] = fmt("%s [%d] %d/%d%s | dmg %s (%s) | heal %s | procs %d | uptime %s",
            s.name, s.setId, s.equipped or 0, s.maxEquipped or 0, s.equippedInFight and "" or " (not worn)",
            N(s.damage), P(s.damageSharePct), N(s.healing), s.activations, P(s.uptimePct))
    end
    if #lines == 1 then lines[2] = "(none)" end
    return lines
end

function Report.StatLines(f)
    local st = f and f.stats
    local lines = { "|cFFD700Stats|r" }
    if not st then
        local snap = LF.Stats.GetSnapshot()
        for _, key in ipairs(Util.SortedKeys(snap)) do
            if type(snap[key]) == "number" and key ~= "timestampMs" then
                lines[#lines + 1] = fmt("%s: %s", LF.Stats.GetStatLabel(key), C(snap[key]))
            end
        end
        return lines
    end
    for _, def in ipairs(Const.STATS) do
        local k = def.key
        if st.avg and st.avg[k] then
            lines[#lines + 1] = fmt("%s: avg %s (min %s / max %s)", def.label, C(st.avg[k]), C(st.min[k]), C(st.max[k]))
        end
    end
    return lines
end

function Report.PowerLines(f)
    local lines = { "|cFFD700Resources|r" }
    if not f then return lines end
    for pt, p in pairs(f.power) do
        lines[#lines + 1] = fmt("%s: min %s max %s avg %s | gained %s spent %s | at zero %.1fs", p.name, C(p.min or 0), C(p.max or 0), C(Util.SafeDiv(p.sum, p.n)), C(p.gained), C(p.spent), (p.timeAtZeroMs or 0) / 1000)
    end
    return lines
end

function Report.DeathLines(f)
    local lines = { "|cFFD700Deaths|r" }
    if not f then return lines end
    for _, d in ipairs(f.deaths) do
        lines[#lines + 1] = fmt("%s died at %.1fs", d.name, d.tMs / 1000)
        if d.recap then
            for i = math.max(1, #d.recap - 4), #d.recap do
                local r = d.recap[i]
                lines[#lines + 1] = fmt("   %.1fs %s %s %s from %s", r.tMs / 1000, r.resultName, r.abilityName, C(r.hit), r.source)
            end
        end
    end
    return lines
end

function Report.BuildLines(b)
    b = b or LF.Build.Read()
    local c = b.character
    local lines = {
        fmt("|cFFD700%s|r  %s %s  L%d CP%d  (%s)", c.name, c.raceName, c.className, c.level or 0, c.championPoints or 0, c.allianceName or ""),
        fmt("Attributes H/M/S: %d / %d / %d", b.attributes.health, b.attributes.magicka, b.attributes.stamina),
        fmt("Max H/M/S: %s / %s / %s", C(b.stats.maxHealth), C(b.stats.maxMagicka), C(b.stats.maxStamina)),
        fmt("Weapon/Spell dmg: %s / %s | Crit: %.1f%% / %.1f%% | Pen: %s / %s", C(b.stats.weaponPower), C(b.stats.spellPower), b.stats.weaponCritPct or 0, b.stats.spellCritPct or 0, C(b.stats.physicalPenetration), C(b.stats.spellPenetration)),
        fmt("Resist phys/spell: %s (%.1f%%) / %s (%.1f%%) | armor L/M/H %d/%d/%d", C(b.stats.physicalResist), b.stats.physicalResistPct or 0, C(b.stats.spellResist), b.stats.spellResistPct or 0, b.armorCounts.light, b.armorCounts.medium, b.armorCounts.heavy),
    }
    lines[#lines + 1] = "|cFFD700Sets|r"
    for _, s in pairs(b.sets) do
        lines[#lines + 1] = fmt("  %s [%d] %d/%d%s", s.name, s.setId, s.equipped, s.maxEquipped, (s.perfected or 0) > 0 and fmt(" (perfected %d)", s.perfected) or "")
    end
    for _, barName in ipairs({ "front", "back" }) do
        local parts = {}
        for slot = Const.FIRST_SKILL_SLOT, Const.ULTIMATE_SLOT do
            local a = b.bars[barName][slot]
            parts[#parts + 1] = a and (Icon(a.icon, 20) .. a.name .. fmt(" [%d]", a.abilityId)) or "-"
        end
        lines[#lines + 1] = fmt("|cFFD700%s bar|r: %s", barName, table.concat(parts, ", "))
    end
    local cps = {}
    for _, cp in ipairs(b.champion.slotted) do cps[#cps + 1] = fmt("%s(%d)", cp.name, cp.points) end
    lines[#lines + 1] = "CP: " .. (#cps > 0 and table.concat(cps, ", ") or "-")
    local mundus = {}
    for _, m in ipairs(b.mundus) do mundus[#mundus + 1] = m.name end
    lines[#lines + 1] = "Mundus: " .. (#mundus > 0 and table.concat(mundus, ", ") or "-")
    lines[#lines + 1] = "|cFFD700Gear|r"
    for _, slot in ipairs(Const.EQUIP_SLOTS) do
        local it = b.gear[slot.id]
        if it then
            lines[#lines + 1] = fmt("  %s: %s%s | %s | %s", slot.name, Icon(it.icon), it.link, it.traitName ~= "" and it.traitName or "-", it.setName or "no set")
        end
    end
    return lines
end

function Report.ModelLines(report)
    report = report or LF.Models.GetReport()
    local lines = { "|cFFD700Model predictions|r" }
    local cr = report.crit
    lines[#lines + 1] = fmt("Crit chance (observed): %s +/- %s over %d hits | crit damage: %s",
        P(cr.critChance or 0), P(cr.critChanceStd or 0), cr.samples or 0, cr.critDamagePct and fmt("+%.1f%%", cr.critDamagePct) or "need more data")
    local inc = report.incoming
    lines[#lines + 1] = fmt("Your DR: armor %.1f%% + other %.1f%% = %.1f%% total (%d samples)", inc.armorMitigationPct, inc.otherDRPct, inc.totalDRPct, inc.samples)
    lines[#lines + 1] = fmt("Reference training: %d abilities, %d hits (targets matching '%s')", report.referenceAbilitiesTrained, report.referenceSamples, LF.GetSettings().referenceTargetPatterns or "")
    for i = 1, math.min(#report.targets, 6) do
        local t = report.targets[i]
        if t.samples > 0 then
            lines[#lines + 1] = fmt("  %s: resist ~%s (+/-%s) | DR ~%.1f%% | missing pen %s | %s (%d samples)",
                t.name, C(t.predictedResistance or 0), C(t.predictedResistanceStd or 0), t.predictedDRPct or 0, C(t.missingPenetration or 0), t.status or "", t.samples)
        elseif t.relativeSamples > 0 then
            lines[#lines + 1] = fmt("  %s: takes %s of average damage (relative, %d samples; hit a dummy to calibrate)", t.name, P(t.relativeDamageTaken or 1), t.relativeSamples)
        end
    end
    for _, k in ipairs(report.ttk) do
        if k.secondsRemaining then
            lines[#lines + 1] = fmt("  TTK %s (%s): %.0fs at %s hp", k.name or "?", k.unitTag, k.secondsRemaining, P(k.healthFraction or 0))
        end
    end
    if report.dpsForecast then lines[#lines + 1] = fmt("DPS forecast (5s): %s", N(report.dpsForecast)) end
    return lines
end

function Report.AbilityInfoLines(abilityId)
    local info = LF.Abilities.GetInfo(abilityId)
    if not info then return { fmt("Ability %s does not exist.", tostring(abilityId)) } end
    local lines = {
        fmt("%s |cFFD700%s|r [%d]", Util.IconMarkup(info.icon, 40), info.name, info.id),
        fmt("Icon: %s", info.icon),
        fmt("Duration %.1fs | cast %.1fs | channel %.1fs%s | range %.0f-%.0fm | radius %.0fm | cost %s",
            info.durationMs / 1000, info.castTimeMs / 1000, info.channelTimeMs / 1000, info.isChanneled and " (channeled)" or "",
            info.minRange / 100, info.maxRange / 100, info.radius / 100, C(info.cost)),
        fmt("Passive: %s | Permanent: %s | Target: %s", tostring(info.isPassive), tostring(info.isPermanent), info.targetDescription),
    }
    if info.description ~= "" then lines[#lines + 1] = info.description end
    local setId = LF.Sets.GetSetForAbility(info.id, info.name)
    if setId then lines[#lines + 1] = fmt("Linked set: %s [%d]", LF.Sets.GetSetName(setId), setId) end
    local pred = LF.Models.PredictHit(info.id)
    if pred then lines[#lines + 1] = fmt("Predicted hit now: %s (crit %s, avg %s)", N(pred.nonCrit), N(pred.crit), N(pred.average)) end
    return lines
end

function Report.SetInfoLines(setId)
    local info = LF.Sets.GetSetInfo(setId)
    if not info then return { fmt("Set %s not found.", tostring(setId)) } end
    local lines = { fmt("|cFFD700%s|r [%d] type %s | max %s pieces", info.name, info.setId, info.setTypeName, tostring(info.maxEquipped or "?")) }
    if info.sampleLink then lines[#lines + 1] = info.sampleLink end
    for _, b in ipairs(info.bonuses) do
        lines[#lines + 1] = fmt("(%d)%s %s", b.numRequired or 0, b.isPerfected and " [perfected]" or "", b.description)
    end
    local abilities = LF.Sets.GetRegisteredAbilities(info.setId)
    if #abilities > 0 then lines[#lines + 1] = "Registered abilities: " .. table.concat(abilities, ", ") end
    lines[#lines + 1] = "Logged: " .. tostring(LF.Sets.IsSetLogged(info.setId))
    return lines
end

-- Compact single-line export:
-- "LF1|id|title|durSec|dmg|dps|heal|hps|taken|mitigated|crit|top abilities|shield|sps"
-- (shield fields are appended last so readers of the first 12 fields keep working)
function Report.Export(f)
    if not f then return "" end
    local s = f:GetSummary()
    local top = {}
    for _, r in ipairs(f:GetAbilityBreakdown("damageOut", "total", 10)) do
        top[#top + 1] = fmt("%d:%d", r.id, math.floor(r.total))
    end
    return table.concat({
        "LF1", tostring(s.id), (string.gsub(s.title or "", "|", "/")), fmt("%.1f", s.durationSec), fmt("%.0f", s.damage), fmt("%.0f", s.dps),
        fmt("%.0f", s.healing), fmt("%.0f", s.hps), fmt("%.0f", s.damageTaken), fmt("%.0f", s.mitigated), fmt("%.3f", s.critRate),
        table.concat(top, ";"), fmt("%.0f", s.shield), fmt("%.0f", s.sps),
    }, "|")
end

function Report.AllFightLines(f)
    local lines = {}
    local function add(t) for _, l in ipairs(t) do lines[#lines + 1] = l end end
    add(Report.FightSummaryLines(f))
    add(Report.AbilityLines(f, "damageOut", 10))
    add(Report.AbilityLines(f, "healOut", 5))
    add(Report.AbilityLines(f, "damageIn", 5))
    add(Report.AbilityLines(f, "shieldIn", 5))
    add(Report.TargetLines(f, 5))
    add(Report.ProcLines(f, 10))
    add(Report.SetLines(f))
    add(Report.EffectLines(f, "player", 10))
    add(Report.EffectLines(f, "target", 10))
    add(Report.PowerLines(f))
    add(Report.DeathLines(f))
    return lines
end
