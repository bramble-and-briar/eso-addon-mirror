-- ConsoleMetrics_DialogCMX.lua
-- Combat Metrics style fight report for the console dialog.
--
-- Mirrors what the Combat Metrics (CMX) fight report shows:
--   Damage Done, Damage Received, Healing Done, Healing Received (totals,
--   per-unit and per-ability tables with Total / % / DPS / Hits / Crit /
--   Avg / Avg Normal / Avg Crit / Max / Min), Buffs In and Debuffs Out,
--   Resources (gains / drains per source), Stats and Performance, a timeline
--   graph, the combat log with filters and pages, skill casts / weaving,
--   deaths, posting DPS / HPS to chat, and a fight list (recent and saved).
--
-- All numbers come from the fight LibFights recorded, so these pages need
-- LibFights logging (they offer to start it). Pages are registered into the
-- console dialog's panel table; keys start with "cmx_" so the keybind strip
-- Previous / Next / Live step through LibFights fights while on them.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local COMBAT_COLOR_HEX = Util.COMBAT_COLOR_HEX
local ColorText = Util.ColorText
local NumberText = Util.NumberText
local ShortNumber = Util.ShortNumber

local Helpers = ConsoleMetrics.ConsoleDialogHelpers
local Muted = Helpers.Muted
local PANELS = ConsoleMetrics.ConsolePanels
local TITLES = ConsoleMetrics.ConsolePanelTitles

local ABILITY_ROWS = 30
local UNIT_ROWS = 12
local EFFECT_ROWS = 40
local LOG_PAGE_SIZE = 25
local GRAPH_BUCKETS = 24
local GRAPH_BAR_WIDTH = 24

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function Pct(fraction, decimals)
    return string.format("%." .. tostring(decimals or 1) .. "f%%", (tonumber(fraction) or 0) * 100)
end

local function Clock(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function ClockMs(ms)
    local seconds = math.max(0, (tonumber(ms) or 0) / 1000)
    return string.format("%d:%04.1f", math.floor(seconds / 60), seconds % 60)
end

local function Value(text, hex)
    return ColorText(tostring(text), hex or "FFFFFF")
end

local function LF()
    return LibFights
end

local function AbilityName(id)
    local lib = LF()
    local name = lib and lib.Abilities and lib.Abilities.GetName(id) or ""
    if name == nil or name == "" then
        return string.format("Ability %s", tostring(id))
    end
    return name
end

---------------------------------------------------------------------------
-- Fight selection
---------------------------------------------------------------------------
-- The viewed fight: a saved fight picked in the fight list, else the
-- LibFights fight the bridge points at (0 = running / most recent).
local function ViewedFight(self)
    if self.cmxFightOverride then
        return self.cmxFightOverride, nil, nil, true
    end
    return self:GetLibFightsViewedFight()
end

local function FightTitle(fight)
    local ok, title = pcall(fight.GetTitle, fight)
    return ok and title or "Fight"
end

-- Header for the CMX pages (the viewed LibFights fight).
local function SetHeader(ctx, fight, index, count, isSaved)
    local s = fight:GetSummary()
    local viewing
    if isSaved then
        viewing = "Saved: " .. FightTitle(fight)
    elseif fight:IsActive() then
        viewing = "Live (in combat)"
    else
        viewing = string.format("%s  (%d/%d)", FightTitle(fight), index or 0, count or 0)
    end
    ctx.header = {
        data1HeaderText = "Fight",
        data1Text = viewing,
        data2HeaderText = "DPS",
        data2Text = ShortNumber(s.dps or 0),
        data3HeaderText = "HPS",
        data3Text = ShortNumber(s.hps or 0),
        data4HeaderText = "Time",
        data4Text = Clock(s.durationSec or 0),
    }
end

-- Shows why there is nothing to show (and how to fix it). Returns the fight
-- and its summary when there is one.
local function RequireFight(ctx)
    local self = ctx.self
    local bridge = self.LibFightsBridge
    if not (bridge and bridge.IsAvailable()) then
        ctx:AddSection("Needs LibFights")
        ctx:AddNote("Install and enable LibFights to see the full fight report.",
            "These pages read the fight LibFights records: per-target and per-source tables, healing received, resources by source, stats, combat log and casts.")
        return nil
    end
    if not bridge.IsLogging() and not self.cmxFightOverride then
        ctx:AddSection("LibFights is not logging")
        ctx:AddButton("Start LibFights Logging", "LibFights records nothing until logging is started. Tip: turn on auto start in Options.", function()
            local ok, reason = self:StartLibFightsLogging()
            if not ok then
                self:Print("LibFights: " .. tostring(reason))
            end
        end, nil, "Start")
    end
    local fight, index, count, isSaved = ViewedFight(self)
    if not fight then
        ctx:AddSection("No Fight Yet")
        ctx:AddNote("Fight something: the report fills in as soon as LibFights records a fight.")
        return nil
    end
    SetHeader(ctx, fight, index, count, isSaved)
    return fight, fight:GetSummary(), index, count, isSaved
end

---------------------------------------------------------------------------
-- Shared tables
---------------------------------------------------------------------------
-- One ability row, CMX columns in the tooltip.
local function AbilityRows(ctx, fight, kind, valueHex, perSecLabel, emptyText)
    local rows = fight:GetAbilityBreakdown(kind, "total", ABILITY_ROWS)
    if #rows == 0 then
        ctx:AddNote(emptyText)
        return
    end
    local isHeal = kind == "healOut" or kind == "healIn"
    for i = 1, #rows do
        local r = rows[i]
        local hits = r.hits or 0
        local normalHits = hits - (r.crits or 0)
        local lines = {
            string.format("Total: %s  (%s)", NumberText(r.total or 0), Pct(r.pct)),
            string.format("%s: %s", perSecLabel, NumberText(r.dps or 0)),
            string.format("Hits: %d   Crits: %d  (%s)", hits, r.crits or 0, Pct(r.critRate)),
            string.format("Avg: %s   Avg Normal: %s   Avg Crit: %s", NumberText(r.avg or 0), NumberText(normalHits > 0 and r.avgNormal or 0), NumberText(r.avgCrit or 0)),
            string.format("Max: %s   Min: %s", NumberText(r.max or 0), NumberText(r.min or 0)),
        }
        if (r.ticks or 0) > 0 then
            lines[#lines + 1] = string.format("Ticks: %d  (%s)   Direct: %d  (%s)", r.ticks or 0, NumberText(r.tickTotal or 0), r.directHits or 0, NumberText(r.directTotal or 0))
        end
        if (r.overflow or 0) > 0 then
            lines[#lines + 1] = string.format("%s: %s", isHeal and "Overheal" or "Overkill", NumberText(r.overflow))
        end
        if r.damageType and not isHeal then
            local lib = LF()
            lines[#lines + 1] = "Damage type: " .. tostring(lib.Const.GetDamageTypeName(r.damageType))
        end
        lines[#lines + 1] = string.format("Ability ID: %d", r.id or 0)
        ctx:AddStat(
            string.format("%d.  %s   %s  %s", i, r.name or AbilityName(r.id),
                Value(ShortNumber(r.total or 0), valueHex),
                Muted(string.format("%s  |  %s/s  |  %s crit", Pct(r.pct), ShortNumber(r.dps or 0), Pct(r.critRate, 0)))),
            table.concat(lines, "\n"))
    end
end

-- Units from a unitId -> amount map (heal targets, healers).
local function UnitAmountRows(ctx, fight, map, total, valueHex, emptyText)
    local list = {}
    for unitId, amount in pairs(map or {}) do
        list[#list + 1] = { name = fight:GetUnitName(unitId), amount = amount }
    end
    table.sort(list, function(a, b) return a.amount > b.amount end)
    if #list == 0 then
        ctx:AddNote(emptyText)
        return
    end
    local duration = fight:GetDurationSec()
    for i = 1, math.min(UNIT_ROWS, #list) do
        local u = list[i]
        local share = total > 0 and u.amount / total or 0
        ctx:AddStat(string.format("%s   %s  %s", u.name ~= "" and u.name or "Unknown",
            Value(ShortNumber(u.amount), valueHex), Muted(string.format("%s  |  %s/s", Pct(share), ShortNumber(u.amount / duration)))),
            string.format("Total: %s\nShare: %s\nPer second: %s", NumberText(u.amount), Pct(share), NumberText(u.amount / duration)))
    end
end

local function DamageTypeRows(ctx, fight, incoming)
    local rows = fight:GetDamageTypes(incoming)
    if #rows == 0 then
        return
    end
    ctx:AddSection(incoming and "Damage Types Taken" or "Damage Types")
    for i = 1, #rows do
        local r = rows[i]
        ctx:AddStat(string.format("%s   %s  %s", tostring(r.name), Value(ShortNumber(r.total)), Muted(Pct(r.pct))),
            string.format("%s damage: %s (%s)", tostring(r.name), NumberText(r.total), Pct(r.pct)))
    end
end

---------------------------------------------------------------------------
-- Hub
---------------------------------------------------------------------------
local function RenderHub(ctx)
    local self = ctx.self
    local fight, s = RequireFight(ctx)

    if fight then
        ctx:AddSection("Fight")
        ctx:AddStat(string.format("%s  %s", FightTitle(fight), Muted(fight.zoneName or "")),
            string.format("Duration: %s (active %.1fs)\nTargets: %d", Clock(s.durationSec), s.activeSec or 0, s.numTargets or 0))
        ctx:AddStat(string.format("Damage  %s  %s", Value(ShortNumber(s.dps) .. " DPS", COMBAT_COLOR_HEX.damage), Muted(NumberText(s.damage) .. " total")),
            string.format("Boss DPS: %s\nActive DPS: %s", NumberText(s.bossDPS), NumberText(s.activeDPS)))
        ctx:AddStat(string.format("Healing  %s  %s", Value(ShortNumber(s.hps) .. " HPS", COMBAT_COLOR_HEX.heal), Muted(Pct(s.overhealPct, 0) .. " overheal")),
            string.format("HPS + overheal: %s", NumberText(s.rawHPS)))
        ctx:AddStat(string.format("Taken  %s  %s", Value(ShortNumber(s.dtps) .. "/s", COMBAT_COLOR_HEX.taken), Muted(NumberText(s.damageTaken) .. " total")),
            string.format("Healing received: %s (%s/s)", NumberText(s.healingTaken), NumberText(s.htps)))
    end

    ctx:AddSection("Report")
    ctx:AddPanelLink("Damage Done", "cmx_damage", "Targets, abilities and damage types")
    ctx:AddPanelLink("Damage Received", "cmx_taken", "Attackers, abilities, blocks, shields and avoidance")
    ctx:AddPanelLink("Healing Done", "cmx_heal", "Heal targets and abilities, overheal")
    ctx:AddPanelLink("Healing Received", "cmx_healin", "Healers and heals on you, shields gained")
    ctx:AddPanelLink("Buffs & Debuffs", "cmx_buffs", "Buffs on you and debuffs you applied, with uptime and stacks")
    ctx:AddPanelLink("Resources", "cmx_resources", "Magicka / Stamina / Health / Ultimate gained and spent, by source")
    ctx:AddPanelLink("Stats & Performance", "cmx_stats", "Spell / weapon stats, penetration, resistances, FPS and ping")
    ctx:AddPanelLink("Graph", "cmx_graph", "Damage, healing or damage taken over the fight")
    ctx:AddPanelLink("Combat Log", "cmx_log", "Every recorded event, filtered and paged")
    ctx:AddPanelLink("Skills & Casts", "cmx_casts", "Casts per ability, APM, light-attack weaving, bar time")
    ctx:AddPanelLink("Deaths", "cmx_deaths", "Deaths with the hits that caused them")
    ctx:AddPanelLink("Post to Chat", "cmx_post", "Post DPS / HPS / buff uptime to chat")
    ctx:AddPanelLink("Fight List", "cmx_fights", "Recent and saved LibFights fights")
end

---------------------------------------------------------------------------
-- Damage Done
---------------------------------------------------------------------------
local function RenderDamage(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end
    local T = fight.totals

    ctx:AddSection("Damage Caused")
    ctx:AddStat(string.format("Total: %s", NumberText(s.damage)),
        string.format("Normal: %s\nCritical: %s\nDoT: %s (%s)\nDirect: %s",
            NumberText(T.damageOutNormal), NumberText(T.damageOutCrit), NumberText(s.dotDamage), Pct(s.dotShare), NumberText(s.directDamage)))
    ctx:AddStat(string.format("DPS: %s", NumberText(s.dps)), "Damage over the whole fight time")
    ctx:AddStat(string.format("Active DPS: %s", NumberText(s.activeDPS)), string.format("Damage over your active time (%.1fs, first to last hit)", s.activeSec or 0))
    ctx:AddStat(string.format("Boss DPS: %s", NumberText(s.bossDPS)), string.format("Damage to bosses: %s", NumberText(s.bossDamage)))
    ctx:AddStat(string.format("Critical: %s  (%d / %d hits)", Pct(s.critRate), s.crits or 0, s.hits or 0),
        string.format("Average hit: %s\nMax hit: %s (%s)", NumberText(s.avgHit), NumberText(s.maxHit), tostring(s.maxHitAbility or "?")))
    ctx:AddStat(string.format("In Combat: %s   Active: %.1fs", Clock(s.durationSec), s.activeSec or 0))
    ctx:AddStat(string.format("Blocked: %s   Shielded: %s", ShortNumber(T.damageOutBlocked), ShortNumber(s.damageShielded)),
        "Your damage the enemy blocked, and damage absorbed by enemy shields")
    ctx:AddStat(string.format("Overkill: %s", NumberText(s.overkill)), "Damage beyond what was needed to kill")

    ctx:AddSection(string.format("Targets  (%d)", s.numTargets or 0))
    local targets = fight:GetTargets(UNIT_ROWS)
    if #targets == 0 then
        ctx:AddNote("No targets yet.")
    end
    for i = 1, #targets do
        local t = targets[i]
        local tag = t.isBoss and "  [Boss]" or ""
        ctx:AddStat(string.format("%s%s   %s  %s", t.name ~= "" and t.name or "Unknown", tag, Value(ShortNumber(t.damage), COMBAT_COLOR_HEX.damage),
            Muted(string.format("%s  |  %s DPS", Pct(t.pct), ShortNumber(t.dps)))),
            string.format("Damage: %s (%s)\nDPS: %s\nHits: %d   Crit: %s\nActive: %.1fs%s", NumberText(t.damage), Pct(t.pct), NumberText(t.dps),
                t.hits or 0, Pct(t.critRate), t.activeSec or 0, t.killed and "\nKilled" or ""))
    end

    ctx:AddSection("Abilities")
    AbilityRows(ctx, fight, "damageOut", COMBAT_COLOR_HEX.damage, "DPS", "No damage yet.")
    DamageTypeRows(ctx, fight, false)
end

---------------------------------------------------------------------------
-- Damage Received
---------------------------------------------------------------------------
local function RenderTaken(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end
    local T = fight.totals

    ctx:AddSection("Damage Received")
    ctx:AddStat(string.format("Total: %s", NumberText(s.damageTaken)), string.format("Hits: %d   Critical: %s", s.incomingHits or 0, Pct(s.incomingCritRate)))
    ctx:AddStat(string.format("Incoming DPS: %s", NumberText(s.dtps)))
    ctx:AddStat(string.format("Blocked: %s  (%d hits)", ShortNumber(T.blockedDamageIn), s.blockedHits or 0), "Damage that still got through while blocking")
    ctx:AddStat(string.format("Shielded: %s  (%s of incoming)", ShortNumber(s.shield), Pct(s.shieldPctOfIncoming, 0)),
        string.format("Shield absorbed per second: %s\nShield hits: %d", NumberText(s.sps), s.shieldHits or 0))
    ctx:AddStat(string.format("Mitigated: %s  (%s)", ShortNumber(s.mitigated), Pct(s.mitigationPct, 0)),
        string.format("Shield (exact): %s\nBlock (est.): %s\nArmor (est.): %s\nAvoidance (est.): %s",
            NumberText(s.mitigatedShield), NumberText(s.mitigatedBlockEst), NumberText(s.mitigatedArmorEst), NumberText(s.mitigatedAvoidEst)))
    ctx:AddStat(string.format("Dodged: %d   Missed: %d   Immune: %d", s.dodges or 0, s.misses or 0, s.immune or 0))

    ctx:AddSection("Attackers")
    local sources = fight:GetSources(UNIT_ROWS)
    if #sources == 0 then
        ctx:AddNote("Nothing has hit you.")
    end
    for i = 1, #sources do
        local src = sources[i]
        ctx:AddStat(string.format("%s   %s  %s", src.name ~= "" and src.name or "Unknown", Value(ShortNumber(src.damage), COMBAT_COLOR_HEX.taken),
            Muted(string.format("%s  |  %d hits", Pct(src.pct), src.hits or 0))),
            string.format("Damage: %s (%s)\nHits: %d   Crits: %d", NumberText(src.damage), Pct(src.pct), src.hits or 0, src.crits or 0))
    end

    ctx:AddSection("Abilities")
    AbilityRows(ctx, fight, "damageIn", COMBAT_COLOR_HEX.taken, "Damage per second", "No damage taken.")
    DamageTypeRows(ctx, fight, true)
end

---------------------------------------------------------------------------
-- Healing Done / Received
---------------------------------------------------------------------------
local function RenderHeal(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end
    local T = fight.totals

    ctx:AddSection("Healing Done")
    ctx:AddStat(string.format("Total: %s", NumberText(s.healing)),
        string.format("Normal: %s\nCritical: %s\nSelf healing: %s", NumberText(T.healOutNormal), NumberText(T.healOutCrit), NumberText(s.selfHealing)))
    ctx:AddStat(string.format("HPS: %s", NumberText(s.hps)))
    ctx:AddStat(string.format("HPS + Overheal: %s", NumberText(s.rawHPS)), string.format("Raw healing: %s", NumberText(s.rawHealing)))
    ctx:AddStat(string.format("Overheal: %s  (%s)", ShortNumber(s.overheal), Pct(s.overhealPct, 0)))
    ctx:AddStat(string.format("Critical: %s", Pct(s.healCritRate)), string.format("Max heal: %s (%s)", NumberText(s.maxHeal), tostring(s.maxHealAbility or "?")))

    ctx:AddSection("Targets")
    UnitAmountRows(ctx, fight, fight.healTargets, s.healing or 0, COMBAT_COLOR_HEX.heal, "No healing yet.")

    ctx:AddSection("Abilities")
    AbilityRows(ctx, fight, "healOut", COMBAT_COLOR_HEX.heal, "HPS", "No healing yet.")
end

local function RenderHealIn(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end

    ctx:AddSection("Healing Received")
    ctx:AddStat(string.format("Total: %s", NumberText(s.healingTaken)))
    ctx:AddStat(string.format("Incoming HPS: %s", NumberText(s.htps)))
    ctx:AddStat(string.format("Shield Gained: %s  (%d shields)", ShortNumber(s.shieldGained), s.shieldApplications or 0),
        string.format("Shield applied per second: %s\nLargest shield: %s\nExpired unused: %s\nEfficiency: %s",
            NumberText(s.shieldGainedPS), NumberText(s.shieldPeak), NumberText(s.shieldExpired), Pct(s.shieldEfficiency, 0)))

    ctx:AddSection("Healers")
    UnitAmountRows(ctx, fight, fight.healers, s.healingTaken or 0, COMBAT_COLOR_HEX.heal, "No healing received.")

    ctx:AddSection("Abilities")
    AbilityRows(ctx, fight, "healIn", COMBAT_COLOR_HEX.heal, "HPS", "No healing received.")
end

---------------------------------------------------------------------------
-- Buffs & Debuffs
---------------------------------------------------------------------------
local function EffectRows(ctx, rows, emptyText, showUnit)
    if #rows == 0 then
        ctx:AddNote(emptyText)
        return
    end
    for i = 1, math.min(EFFECT_ROWS, #rows) do
        local e = rows[i]
        local stacks = (e.maxStacks or 0) > 1 and string.format("  x%d", e.maxStacks) or ""
        local mine = e.castByPlayer and "" or Muted("  (others)")
        ctx:AddStat(string.format("%s%s   %s  %s%s", e.name or "?", stacks, Value(Pct(e.uptimePct, 0)),
            Muted(string.format("%d gained", e.gains or 0)), mine),
            string.format("Uptime: %s (%.1fs)\nGained: %d   Refreshed: %d   Faded: %d\nMax stacks: %d%s\nAbility ID: %d",
                Pct(e.uptimePct), (e.uptimeMs or 0) / 1000, e.gains or 0, e.refreshes or 0, e.fades or 0, e.maxStacks or 0,
                (showUnit and e.unitName and e.unitName ~= "") and ("\nOn: " .. e.unitName) or "", e.id or 0))
    end
end

local function RenderBuffs(ctx)
    local fight = RequireFight(ctx)
    if not fight then return end
    ctx:AddSection("Buffs In")
    EffectRows(ctx, fight:GetEffectUptimes("player"), "No buffs recorded.", false)
    ctx:AddSection("Debuffs Out")
    EffectRows(ctx, fight:GetEffectUptimes("target", true), "No debuffs applied (or target effects are off in Performance Mode).", true)

    local procs = fight:GetProcs()
    if #procs > 0 then
        ctx:AddSection("Procs")
        for i = 1, math.min(20, #procs) do
            local p = procs[i]
            ctx:AddStat(string.format("%s   %s  %s", p.setName or p.name or "?", Value(string.format("%d procs", p.activations or 0)),
                Muted(p.perMinute and string.format("%.1f/min", p.perMinute) or "")),
                string.format("%s\nDamage: %s   Healing: %s\nEstimated cooldown: %s",
                    tostring(p.name or "?"), NumberText(p.damage or 0), NumberText(p.healing or 0),
                    p.estimatedCooldownMs and string.format("%.1fs", p.estimatedCooldownMs / 1000) or "n/a"))
        end
    end
end

---------------------------------------------------------------------------
-- Resources
---------------------------------------------------------------------------
local POWER_ORDER = { "POWER_MAGICKA", "POWER_STAMINA", "POWER_HEALTH", "POWER_ULTIMATE" }
local POWER_HEX = { POWER_MAGICKA = "5EBDE7", POWER_STAMINA = "A6D852", POWER_HEALTH = "DE6531", POWER_ULTIMATE = "FFE785" }

local function RenderResources(ctx)
    local fight = RequireFight(ctx)
    if not fight then return end
    local lib = LF()
    local duration = fight:GetDurationSec()
    local power = fight:GetPower() or {}
    local any = false

    for _, key in ipairs(POWER_ORDER) do
        local powerType = lib.Const[key]
        local p = powerType and power[powerType]
        if p then
            any = true
            local hex = POWER_HEX[key]
            ctx:AddSection(lib.Const.GetPowerName(powerType))
            local avgPct = 0
            local samples = p.samples or {}
            if #samples > 0 then
                local sum, n = 0, 0
                for i = 1, #samples do
                    local maxValue = tonumber(samples[i][3]) or p.maxValue or 0
                    if maxValue > 0 then
                        sum = sum + (samples[i][2] or 0) / maxValue
                        n = n + 1
                    end
                end
                avgPct = n > 0 and sum / n or 0
            end
            ctx:AddStat(string.format("Gained  %s  %s", Value("+" .. ShortNumber(p.gained or 0), hex), Muted(string.format("%s/s", ShortNumber((p.gained or 0) / duration)))),
                "Restored by abilities, sets and potions (energize events)")
            ctx:AddStat(string.format("Spent  %s  %s", Value("-" .. ShortNumber(p.spent or 0), hex), Muted(string.format("%s/s", ShortNumber((p.spent or 0) / duration)))),
                "Total decreases seen on the resource bar")
            ctx:AddStat(string.format("Average: %s   Min: %s   Max: %s", Pct(avgPct, 0), ShortNumber(p.min or 0), ShortNumber(p.max or 0)),
                string.format("Maximum pool: %s\nTime at zero: %.1fs", NumberText(p.maxValue or 0), (p.timeAtZeroMs or 0) / 1000))

            local sources = {}
            for abilityId, amount in pairs(p.gainedBy or {}) do
                sources[#sources + 1] = { id = abilityId, amount = amount }
            end
            table.sort(sources, function(a, b) return a.amount > b.amount end)
            for i = 1, math.min(6, #sources) do
                local src = sources[i]
                local share = (p.gained or 0) > 0 and src.amount / p.gained or 0
                ctx:AddStat(string.format("    %s   %s  %s", AbilityName(src.id), Value("+" .. ShortNumber(src.amount), hex), Muted(Pct(share, 0))),
                    string.format("Restored: %s (%s of gains)\nAbility ID: %d", NumberText(src.amount), Pct(share), src.id))
            end
        end
    end
    if not any then
        ctx:AddNote("No resource data (power tracking may be off in LibFights settings).")
    end
end

---------------------------------------------------------------------------
-- Stats & Performance
---------------------------------------------------------------------------
local function StatPair(stats, key)
    if not stats then return nil, nil end
    local avg = stats.avg and stats.avg[key]
    if avg == nil and stats.sum and stats.sum[key] and (stats.n or 0) > 0 then
        avg = stats.sum[key] / stats.n
    end
    local maxValue = stats.max and stats.max[key]
    return avg, maxValue
end

local function StatRow(ctx, stats, key, label, isPct, tooltip)
    local avg, maxValue = StatPair(stats, key)
    if avg == nil and maxValue == nil then
        local current = LF().Stats.GetStat(key)
        if current == nil then return end
        avg, maxValue = current, current
    end
    local fmt = isPct and function(v) return string.format("%.1f%%", v or 0) end or function(v) return NumberText(v or 0) end
    ctx:AddStat(string.format("%s: %s  %s", label, fmt(avg), Muted("max " .. fmt(maxValue))),
        tooltip or "Average and highest value during the fight")
end

local function RenderStats(ctx)
    local self = ctx.self
    local fight = RequireFight(ctx)
    if not fight then return end
    local lib = LF()
    local stats = fight:GetStats()
    local crit = lib.Models.GetCritEstimate() or {}
    local estimates = lib.Models.GetAllTargetEstimates() or {}
    local target = estimates[1]

    ctx:AddSection("Magicka")
    StatRow(ctx, stats, "maxMagicka", "Max Magicka")
    StatRow(ctx, stats, "spellPower", "Spell Damage")
    StatRow(ctx, stats, "spellCritPct", "Spell Critical", true)
    StatRow(ctx, stats, "spellPenetration", "Spell Penetration")

    ctx:AddSection("Stamina")
    StatRow(ctx, stats, "maxStamina", "Max Stamina")
    StatRow(ctx, stats, "weaponPower", "Weapon Damage")
    StatRow(ctx, stats, "weaponCritPct", "Weapon Critical", true)
    StatRow(ctx, stats, "physicalPenetration", "Physical Penetration")

    ctx:AddSection("Critical Damage & Penetration")
    ctx:AddStat(string.format("Critical Damage: %s", crit.critDamagePct and string.format("+%.0f%%", crit.critDamagePct) or "n/a"),
        "Measured from your crits vs normal hits on the same target (needs 3+ of each)")
    ctx:AddStat(string.format("Observed Crit Chance: %s", crit.critChance and Pct(crit.critChance) or "n/a"),
        crit.samples and string.format("From %d hits", crit.samples) or nil)
    if target then
        if target.predictedResistance then
            local over = (target.penetrationToCap or 0) < 0 and -(target.penetrationToCap or 0) or 0
            ctx:AddStat(string.format("Target Resistance: %s", NumberText(target.predictedResistance)),
                string.format("%s\nConfidence: %s\nStatus: %s", tostring(target.name or "?"), Pct(target.confidence, 0), tostring(target.status or "")))
            ctx:AddStat(string.format("Missing Penetration: %s", NumberText(math.max(0, target.missingPenetration or 0))),
                "Resistance left after your highest penetration (0 = capped)")
            ctx:AddStat(string.format("Overpenetration: %s  (%s of hits)", NumberText(over), Pct(target.overPenetratedPct, 0)),
                "Penetration beyond the target's resistance is wasted")
        elseif target.relativeToughnessPct then
            ctx:AddStat(string.format("Target Toughness: %.0f%%", target.relativeToughnessPct),
                "Relative to your average target. Hit a target dummy once to calibrate real resistance values.")
        end
    end

    ctx:AddSection("Health")
    StatRow(ctx, stats, "maxHealth", "Max Health")
    StatRow(ctx, stats, "physicalResist", "Physical Resistance")
    StatRow(ctx, stats, "spellResist", "Spell Resistance")
    StatRow(ctx, stats, "criticalResistance", "Critical Resistance")

    ctx:AddSection("Performance")
    ctx:AddStat(string.format("FPS: %s", self:GetRuntimeFpsText()), "Current (average / minimum / 1% low) this session")
    local snapshot = self:GetViewedFightSnapshot() or {}
    local ping = snapshot.resourceSummary and snapshot.resourceSummary.ping or {}
    if ping.hasData then
        ctx:AddStat(string.format("Ping: %.0f ms  %s", ping.averageMs or 0, Muted(string.format("%.0f-%.0f ms", ping.minMs or 0, ping.maxMs or 0))),
            string.format("Median: %.0f ms\nDips: %d   Spikes: %d", ping.medianMs or 0, ping.dips or 0, ping.spikes or 0))
    else
        ctx:AddNote("Ping: no samples for this fight.")
    end
end

---------------------------------------------------------------------------
-- Graph
---------------------------------------------------------------------------
local GRAPH_FIELDS = {
    { field = "dOut", label = "Damage Done", hex = COMBAT_COLOR_HEX.damage, unit = "DPS" },
    { field = "hOut", label = "Healing Done", hex = COMBAT_COLOR_HEX.heal, unit = "HPS" },
    { field = "dIn", label = "Damage Taken", hex = COMBAT_COLOR_HEX.taken, unit = "DTPS" },
    { field = "sIn", label = "Shield Absorbed", hex = COMBAT_COLOR_HEX.shield, unit = "/s" },
}

local function RenderGraph(ctx)
    local self = ctx.self
    local fight = RequireFight(ctx)
    if not fight then return end

    local choice = GRAPH_FIELDS[self.cmxGraphField or 1] or GRAPH_FIELDS[1]
    ctx:AddSection("Show")
    for i = 1, #GRAPH_FIELDS do
        local option = GRAPH_FIELDS[i]
        ctx:AddButton((option == choice and "> " or "") .. option.label, "Graph this value over the fight", function()
            self.cmxGraphField = i
        end, function() return option == choice end, "Show")
    end

    local timeline = fight:GetTimeline(choice.field)
    local seconds = #timeline
    local bucket = math.max(1, math.ceil(seconds / GRAPH_BUCKETS))
    local values, peak = {}, 0
    for start = 1, seconds, bucket do
        local sum = 0
        local last = math.min(seconds, start + bucket - 1)
        for i = start, last do
            sum = sum + (timeline[i] or 0)
        end
        local rate = sum / (last - start + 1)
        values[#values + 1] = { from = start - 1, to = last, rate = rate, sum = sum }
        if rate > peak then peak = rate end
    end

    ctx:AddSection(string.format("%s  (%ds per row)", choice.label, bucket))
    if peak <= 0 then
        ctx:AddNote("Nothing recorded for this value yet.")
        return
    end
    for i = 1, #values do
        local v = values[i]
        local width = math.floor((v.rate / peak) * GRAPH_BAR_WIDTH + 0.5)
        local bar = string.rep("|", width)
        ctx:AddStat(string.format("%s  %s  %s", Muted(Clock(v.from)), ColorText(bar ~= "" and bar or ".", choice.hex), Value(ShortNumber(v.rate))),
            string.format("%s - %s\n%s %s\nTotal: %s", Clock(v.from), Clock(v.to), NumberText(v.rate), choice.unit, NumberText(v.sum)))
    end

    local lib = LF()
    local ttk = lib.Models.GetAllTTK and lib.Models.GetAllTTK() or {}
    if #ttk > 0 then
        ctx:AddSection("Boss Health")
        for i = 1, #ttk do
            local b = ttk[i]
            ctx:AddStat(string.format("%s: %s  %s", tostring(b.name or b.unitTag), Pct(b.healthFraction, 0),
                Muted(b.secondsRemaining and ("~" .. Clock(b.secondsRemaining) .. " left") or "")),
                "Time to kill estimate from the boss's health trend")
        end
    end
end

---------------------------------------------------------------------------
-- Combat Log
---------------------------------------------------------------------------
local LOG_FILTERS = {
    { key = "dOut", label = "Your Damage" },
    { key = "hOut", label = "Your Healing" },
    { key = "dIn",  label = "Damage Taken" },
    { key = "hIn",  label = "Healing Received" },
    { key = "other", label = "Other (shields, avoids, CC)" },
}

local function EventKind(direction, category)
    if category == "damage" then
        return (direction == 2) and "dIn" or "dOut"
    elseif category == "heal" then
        return (direction == 2) and "hIn" or "hOut"
    end
    return "other"
end

local function LogFilters(self)
    if type(self.cmxLogFilters) ~= "table" then
        self.cmxLogFilters = { dOut = true, hOut = true, dIn = true, hIn = true, other = false }
    end
    return self.cmxLogFilters
end

local function RenderLog(ctx)
    local self = ctx.self
    local fight = RequireFight(ctx)
    if not fight then return end
    local lib = LF()
    local F = lib.EVENT_FIELDS
    local events = fight.events
    local count = 0
    if type(events) == "table" then
        count = events.count or #events
    end

    local filters = LogFilters(self)
    ctx:AddSection("Filters")
    for i = 1, #LOG_FILTERS do
        local f = LOG_FILTERS[i]
        ctx:AddToggle(f.label, "Show these events in the log", function() return filters[f.key] == true end,
            function(value)
                filters[f.key] = value
                self.cmxLogPage = 1
                -- Rebuild after the checkbox handler has finished.
                if type(zo_callLater) == "function" then
                    zo_callLater(function() self:RebuildConsoleDialog(true) end, 50)
                end
            end)
    end

    if count == 0 then
        ctx:AddSection("Combat Log")
        ctx:AddNote("No events recorded.", "LibFights raw events are off (they are disabled in Performance Mode), or the fight has no events yet.")
        return
    end

    local function Get(i)
        if events.Get then return events:Get(i) end
        return events[i]
    end

    -- Index the matching events cheaply (no decoding), then decode one page.
    local matches = {}
    for i = 1, count do
        local ev = Get(i)
        if ev then
            local kind = EventKind(ev[F.DIR], lib.Const.GetResultCategory(ev[F.RESULT]))
            if filters[kind] then
                matches[#matches + 1] = i
            end
        end
    end
    local pages = math.max(1, math.ceil(#matches / LOG_PAGE_SIZE))
    local page = math.max(1, math.min(pages, self.cmxLogPage or 1))
    self.cmxLogPage = page

    ctx:AddSection(string.format("Combat Log  (page %d/%d, %d events)", page, pages, #matches))
    ctx:AddButton("Previous Page", "Earlier events", function() self.cmxLogPage = page - 1 end, function() return page <= 1 end, "Previous")
    ctx:AddButton("Next Page", "Later events", function() self.cmxLogPage = page + 1 end, function() return page >= pages end, "Next")
    ctx:AddButton("Last Page", "Most recent events", function() self.cmxLogPage = pages end, function() return page >= pages end, "Go")

    local kindHex = { dOut = COMBAT_COLOR_HEX.damage, hOut = COMBAT_COLOR_HEX.heal, dIn = COMBAT_COLOR_HEX.taken, hIn = COMBAT_COLOR_HEX.hot, other = COMBAT_COLOR_HEX.shield }
    local first = (page - 1) * LOG_PAGE_SIZE + 1
    for m = first, math.min(#matches, first + LOG_PAGE_SIZE - 1) do
        local raw = Get(matches[m])
        local kind = EventKind(raw[F.DIR], lib.Const.GetResultCategory(raw[F.RESULT]))
        local e = fight:DecodeEvent(raw)
        local arrow = (kind == "dIn" or kind == "hIn") and (e.source ~= "" and e.source or "?") or (e.target ~= "" and e.target or "?")
        local amount = (e.hit or 0) > 0 and ShortNumber(e.hit) or tostring(e.resultName or "")
        ctx:AddStat(string.format("%s  %s  %s  %s%s", Muted(ClockMs(e.tMs)), e.abilityName ~= "" and e.abilityName or "?",
            ColorText(amount, kindHex[kind] or "FFFFFF"), Muted(((kind == "dIn" or kind == "hIn") and "from " or "on ") .. arrow),
            e.isCrit and ColorText("  crit", COMBAT_COLOR_HEX.damageCrit) or ""),
            string.format("%s\nResult: %s\nFrom: %s\nTo: %s\nAmount: %s   Overflow: %s\nDamage type: %s\nAbility ID: %d",
                ClockMs(e.tMs), tostring(e.resultName), tostring(e.source), tostring(e.target), NumberText(e.hit or 0),
                NumberText(e.overflow or 0), tostring(e.damageTypeName), e.abilityId or 0))
    end
end

---------------------------------------------------------------------------
-- Skills & Casts
---------------------------------------------------------------------------
local function RenderCasts(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end

    ctx:AddSection("Actions")
    ctx:AddStat(string.format("Casts: %d   APM: %.1f", s.casts or 0, s.apm or 0),
        string.format("Skills: %d\nUltimates: %d\nLight attacks: %d\nHeavy attacks: %d\nSkills per minute: %.1f",
            s.skillCasts or 0, s.ultimates or 0, s.lightAttacks or 0, s.heavyAttacks or 0, s.skillsPerMinute or 0))
    ctx:AddStat(string.format("Light Attack Weaving: %s  (%d weaves)", Pct(s.weaveRatio, 0), s.weaves or 0),
        "Share of skills and ultimates that followed a light attack")
    ctx:AddStat(string.format("Avg Time Between Skills: %.2fs", (s.avgSkillGapMs or 0) / 1000),
        "Lower is better; around 1.0s is the global cooldown")
    ctx:AddStat(string.format("Bar Swaps: %d   Front: %s   Back: %s", s.barSwaps or 0, Pct(s.frontBarPct, 0), Pct(s.backBarPct, 0)))

    local _, rows = fight:GetCasts()
    ctx:AddSection("Casts per Ability")
    if not rows or #rows == 0 then
        ctx:AddNote("No casts recorded (cast tracking may be off in LibFights settings).")
    else
        local duration = fight:GetDurationSec()
        for i = 1, math.min(ABILITY_ROWS, #rows) do
            local c = rows[i]
            ctx:AddStat(string.format("%s   %s  %s", c.name ~= "" and c.name or AbilityName(c.id), Value(string.format("x%d", c.count or 0)),
                Muted(string.format("%s  |  every %.1fs", tostring(c.kind or ""), duration / math.max(1, c.count or 1)))),
                string.format("Casts: %d\nFirst: %s   Last: %s\nAbility ID: %d", c.count or 0,
                    ClockMs((c.firstMs or fight.startMs) - fight.startMs), ClockMs((c.lastMs or fight.startMs) - fight.startMs), c.id or 0))
        end
    end

    local build = fight:GetBuild()
    if build and build.bars then
        for _, barKey in ipairs({ "front", "back" }) do
            local bar = build.bars[barKey] or {}
            local names = {}
            for slot = 3, 8 do
                if bar[slot] then
                    names[#names + 1] = bar[slot].name or "?"
                end
            end
            if #names > 0 then
                ctx:AddSection(barKey == "front" and "Front Bar (at fight start)" or "Back Bar (at fight start)")
                for i = 1, #names do
                    ctx:AddStat(names[i])
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Deaths
---------------------------------------------------------------------------
local function RenderDeaths(ctx)
    local fight, s = RequireFight(ctx)
    if not fight then return end
    local deaths = fight:GetDeaths() or {}
    ctx:AddSection(string.format("Deaths  (%d)   Killing Blows  (%d)", #deaths, s.killingBlows or 0))
    if #deaths == 0 then
        ctx:AddNote("Nobody died in this fight.")
        return
    end
    for i = 1, #deaths do
        local d = deaths[i]
        local lines = { string.format("%s died at %s", tostring(d.name or d.unitTag or "?"), ClockMs(d.tMs)) }
        local recap = d.recap or {}
        for j = math.max(1, #recap - 4), #recap do
            local h = recap[j]
            lines[#lines + 1] = string.format("%s  %s  %s from %s", ClockMs(h.tMs), tostring(h.abilityName or "?"), NumberText(h.hit or 0), tostring(h.source or "?"))
        end
        ctx:AddStat(string.format("%s  %s", Muted(ClockMs(d.tMs)), tostring(d.name or d.unitTag or "?")), table.concat(lines, "\n"))
    end
end

---------------------------------------------------------------------------
-- Post to Chat
---------------------------------------------------------------------------
local function RenderPost(ctx)
    local self = ctx.self
    local fight, s = RequireFight(ctx)
    if not fight then return end
    local title = FightTitle(fight)
    local timeText = Clock(s.durationSec)
    local targets = fight:GetTargets()
    local top = targets[1]

    local function Post(text)
        self:SendToChat(text)
    end

    ctx:AddSection("DPS")
    if top then
        local single = string.format("%s - DPS: %s (%s in %s)", top.name, NumberText(top.dps), NumberText(top.damage), timeText)
        ctx:AddButton("Single Target DPS", single, function() Post(single) end, nil, "Post")
    end
    if (s.bossDamage or 0) > 0 then
        local boss = string.format("%s - Boss DPS: %s (%s in %s)", title, NumberText(s.bossDPS), NumberText(s.bossDamage), timeText)
        ctx:AddButton("Boss DPS", boss, function() Post(boss) end, nil, "Post")
    end
    local extra = math.max(0, #targets - 1)
    local total = string.format("%s (+%d) - DPS: %s (%s in %s)", title, extra, NumberText(s.dps), NumberText(s.damage), timeText)
    ctx:AddButton("Total DPS", total, function() Post(total) end, nil, "Post")
    if top and extra > 0 then
        local both = string.format("%s - Total DPS (+%d): %s (%s in %s) | %s: %s", title, extra, NumberText(s.dps), NumberText(s.damage), timeText, top.name, NumberText(top.dps))
        ctx:AddButton("Single + Total DPS", both, function() Post(both) end, nil, "Post")
    end

    ctx:AddSection("HPS")
    local hps = string.format("%s - HPS: %s (%s in %s)", title, NumberText(s.hps), NumberText(s.healing), timeText)
    ctx:AddButton("HPS", hps, function() Post(hps) end, nil, "Post")

    local buffs = fight:GetEffectUptimes("player")
    if #buffs > 0 then
        ctx:AddSection("Buff Uptime")
        for i = 1, math.min(8, #buffs) do
            local b = buffs[i]
            local line = string.format("%s - Uptime: %s (%.1fs of %s)", b.name or "?", Pct(b.uptimePct, 0), (b.uptimeMs or 0) / 1000, timeText)
            ctx:AddButton(b.name or "?", line, function() Post(line) end, nil, "Post")
        end
    end
end

---------------------------------------------------------------------------
-- Fight List
---------------------------------------------------------------------------
local function FightLine(fight)
    local ok, s = pcall(fight.GetSummary, fight)
    if not ok or not s then
        return "Fight", ""
    end
    return string.format("%s   %s  %s", tostring(s.title or "Fight"), Value(ShortNumber(s.dps) .. " DPS"), Muted(Clock(s.durationSec))),
        string.format("%s\nZone: %s\nCharacter: %s\nDuration: %s\nDPS: %s   HPS: %s",
            tostring(s.title), tostring(s.zone or "?"), tostring(s.character or "?"), Clock(s.durationSec), NumberText(s.dps), NumberText(s.hps))
end

local function RenderFights(ctx)
    local self = ctx.self
    local bridge = self.LibFightsBridge
    if not (bridge and bridge.IsAvailable()) then
        RequireFight(ctx)
        return
    end
    local lib = LF()
    local viewed, _, _, isSaved = ViewedFight(self)
    if viewed then
        SetHeader(ctx, viewed, nil, nil, isSaved)
    end

    local recent = lib.Logger.GetFights() or {}
    local current = lib.Logger.GetCurrentFight()
    local list = {}
    if current then list[#list + 1] = current end
    for i = #recent, 1, -1 do list[#list + 1] = recent[i] end

    ctx:AddSection(string.format("Recent Fights  (%d)", #list))
    if #list == 0 then
        ctx:AddNote("No fights yet this session.")
    end
    for offset = 0, #list - 1 do
        local fight = list[offset + 1]
        local label, tip = FightLine(fight)
        local selected = (not self.cmxFightOverride) and (self.libFightsViewOffset or 0) == offset
        ctx:AddButton((selected and "> " or "") .. label, tip, function()
            self.cmxFightOverride = nil
            self.cmxLogPage = 1
            self.libFightsViewOffset = offset
            self.libFightsRev = (self.libFightsRev or 0) + 1
            self.dialogPanel = "cmx_hub"
        end, nil, "View")
    end
    if viewed and not isSaved and not viewed:IsActive() then
        ctx:AddButton("Save Viewed Fight", "Keep the viewed fight in LibFights saved fights (across sessions)", function()
            local ok = lib.Storage.SaveFight(viewed)
            self:Print(ok and "Fight saved to LibFights." or "LibFights saved data is not loaded yet.")
        end, nil, "Save")
    end

    local saved = lib.Storage.GetSavedFights() or {}
    ctx:AddSection(string.format("Saved Fights  (%d)", #saved))
    if #saved == 0 then
        ctx:AddNote("No saved LibFights fights.")
    end
    for i = #saved, 1, -1 do
        local fight = saved[i]
        local label, tip = FightLine(fight)
        local selected = self.cmxFightOverride == fight
        ctx:AddButton((selected and "> " or "") .. label, tip, function()
            self.cmxFightOverride = fight
            self.cmxLogPage = 1
            self.dialogPanel = "cmx_hub"
        end, nil, "View")
        ctx:AddButton("    Delete", "Permanently delete this saved fight", function()
            if self.cmxFightOverride == fight then
                self.cmxFightOverride = nil
            end
            lib.Storage.DeleteSavedFight(fight.id)
        end, nil, "Delete")
    end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
local PAGES = {
    { key = "cmx_hub",       title = "Combat Metrics",       render = RenderHub },
    { key = "cmx_damage",    title = "Damage Done",          render = RenderDamage },
    { key = "cmx_taken",     title = "Damage Received",      render = RenderTaken },
    { key = "cmx_heal",      title = "Healing Done",         render = RenderHeal },
    { key = "cmx_healin",    title = "Healing Received",     render = RenderHealIn },
    { key = "cmx_buffs",     title = "Buffs & Debuffs",      render = RenderBuffs },
    { key = "cmx_resources", title = "Resources",            render = RenderResources },
    { key = "cmx_stats",     title = "Stats & Performance",  render = RenderStats },
    { key = "cmx_graph",     title = "Graph",                render = RenderGraph },
    { key = "cmx_log",       title = "Combat Log",           render = RenderLog },
    { key = "cmx_casts",     title = "Skills & Casts",       render = RenderCasts },
    { key = "cmx_deaths",    title = "Deaths",               render = RenderDeaths },
    { key = "cmx_post",      title = "Post to Chat",         render = RenderPost },
    { key = "cmx_fights",    title = "Fight List",           render = RenderFights },
}

for i = 1, #PAGES do
    PANELS[PAGES[i].key] = PAGES[i].render
    TITLES[PAGES[i].key] = PAGES[i].title
end
