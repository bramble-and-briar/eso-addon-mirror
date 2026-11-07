-- ConsoleMetrics_Dialog.lua
-- Gamepad/console fight dialog (LibConsoleDialogs + LibHarvensAddonSettings) and
-- the platform-neutral open/close/refresh entry points used by the rest of the addon.
--
-- Each panel is rendered by one function that receives a render context:
--   ctx.self, ctx.dialog, ctx.snapshot, ctx.isLive, ctx.viewingText
--   ctx:AddSection(label, tooltip)      section header
--   ctx:AddStat(text, tooltip)          read-only row
--   ctx:AddButton(label, tooltip, action, disableFn)
--   ctx:AddBackButton() / ctx:AddCloseButton()
--   ctx:GetBehavior()                   memoized behavior model for the viewed fight

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local BuildDefaultFightSaveName = Util.BuildDefaultFightSaveName
local COMBAT_COLOR_HEX = Util.COMBAT_COLOR_HEX
local Clamp = Util.Clamp
local ColorShort = Util.ColorShort
local ColorText = Util.ColorText
local EFFECTS_PANEL_LIMIT = Util.EFFECTS_PANEL_LIMIT
local FormatAbilityIdentity = Util.FormatAbilityIdentity
local GetResourcePowerTypes = Util.GetResourcePowerTypes
local LinearSlope = Util.LinearSlope
local Mean = Util.Mean
local Median = Util.Median
local NumberText = Util.NumberText
local PING_DIP_DELTA_MS = Util.PING_DIP_DELTA_MS
local PING_HIGH_DELAY_MS = Util.PING_HIGH_DELAY_MS
local PING_SPIKE_DELTA_MS = Util.PING_SPIKE_DELTA_MS
local RESISTANCE_CAP = Util.RESISTANCE_CAP
local RESISTANCE_SCALE = Util.RESISTANCE_SCALE
local RESOURCE_SAMPLE_INTERVAL_MS = Util.RESOURCE_SAMPLE_INTERVAL_MS
local SafeGetCurrentPowerFromList = Util.SafeGetCurrentPowerFromList
local SafeGetMaxPowerFromList = Util.SafeGetMaxPowerFromList
local ShortNumber = Util.ShortNumber
local StdDev = Util.StdDev
local TOP_MOMENTS_LIMIT = Util.TOP_MOMENTS_LIMIT
local TrimText = Util.TrimText

local Build = ConsoleMetrics.Build
local BuildActionBarSnapshot = Build.BuildActionBarSnapshot
local BuildActiveBoonSnapshot = Build.BuildActiveBoonSnapshot
local BuildEquipmentSnapshot = Build.BuildEquipmentSnapshot
local BuildEquippedSetSummary = Build.BuildEquippedSetSummary
local BuildWeaponEffectSnapshot = Build.BuildWeaponEffectSnapshot
local GetSelectedRoleComparisonProfile = Build.GetSelectedRoleComparisonProfile

local Champion = ConsoleMetrics.Champion
local BuildChampionSnapshot = Champion.BuildChampionSnapshot

local Fight = ConsoleMetrics.Fight
local BuildProtectionSummary = Fight.BuildProtectionSummary
local InferProtectionFromDr = Fight.InferProtectionFromDr


---------------------------------------------------------------------------
-- Render context
---------------------------------------------------------------------------
local RenderContext = {}
RenderContext.__index = RenderContext

local function NewRenderContext(addon, dialog, snapshot, isLive)
    local viewingText = isLive and "Live" or string.format("Fight %d/%d", addon.viewFightIndex or 0, #(addon.fightHistory or {}))
    if not isLive and type(snapshot.savedLabel) == "string" and snapshot.savedLabel ~= "" then
        viewingText = snapshot.savedLabel
    end

    return setmetatable({
        self = addon,
        dialog = dialog,
        snapshot = snapshot,
        isLive = isLive,
        viewingText = viewingText,
        behavior = nil,
        closed = false,
    }, RenderContext)
end

function RenderContext:GetBehavior()
    if not self.behavior then
        self.behavior = self.self:GetBehaviorModel(self.isLive and self.snapshot or nil)
    end
    return self.behavior
end

function RenderContext:AddSection(label, tooltip)
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = label,
        tooltip = tooltip,
    })
end

-- Read-only rows are buttons with a no-op handler so they stay scrollable/selectable.
function RenderContext:AddStat(text, tooltip)
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = text,
        tooltip = tooltip or text,
        clickHandler = function() end,
    })
end

function RenderContext:Refresh()
    if self.closed then
        return
    end
    local addon = self.self
    addon:PopulateFightViewDialog(self.dialog)
    self.dialog:Show()
    addon:ArmDialogAutoHide()
end

function RenderContext:AddButton(label, tooltip, action, disable)
    local ctx = self
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = label,
        tooltip = tooltip,
        clickHandler = function()
            action()
            if not ctx.closed then
                ctx:Refresh()
            end
        end,
        disable = disable,
    })
end

function RenderContext:AddBackButton()
    local addon = self.self
    self:AddButton("Back", "Return to the main panel", function()
        addon.dialogPanel = "main"
    end)
end

function RenderContext:AddCloseButton()
    local ctx = self
    self.dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Close",
        tooltip = "Close fight data dialog",
        clickHandler = function()
            ctx.closed = true
            ctx.self:CloseFightViewDialog(false, "button")
        end,
    })
end

---------------------------------------------------------------------------
-- Shared row builders
---------------------------------------------------------------------------
local function FormatMs(ms)
    return string.format("%.1fs", (ms or 0) / 1000)
end

local function AddFightNavButtons(ctx)
    local addon = ctx.self
    local function NoHistory()
        return #(addon.fightHistory or {}) == 0
    end
    ctx:AddButton("Previous Fight", "Cycle to previous fight in history", function()
        addon:StepFightView(-1)
    end, NoHistory)
    ctx:AddButton("Next Fight", "Cycle to next fight in history", function()
        addon:StepFightView(1)
    end, NoHistory)
    ctx:AddButton("View Live Fight", "Return to current live fight view", function()
        addon.viewFightIndex = 0
    end)
end

-- Rows of the form "N) name [id:X] - value (crit%)" for a per-ability stat list.
local function AddStatRows(ctx, list, limit, valueKey, colorHex, tooltipFn, emptyText, emptyTooltip)
    if not list or #list == 0 then
        ctx:AddStat(emptyText, emptyTooltip)
        return
    end

    for i = 1, math.min(limit, #list) do
        local entry = list[i]
        local hits = entry.hits or 0
        local critPct = hits > 0 and (((entry.crits or 0) / hits) * 100) or 0
        ctx:AddStat(
            string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, entry.name or "Unknown", entry.abilityId or 0, ColorShort(entry[valueKey] or 0, colorHex), critPct),
            tooltipFn(entry)
        )
    end
end

local function AddMomentRows(ctx, list, emptyText, emptyTooltip)
    if not list or #list == 0 then
        ctx:AddStat(emptyText, emptyTooltip)
        return
    end
    for i = 1, math.min(TOP_MOMENTS_LIMIT, #list) do
        local moment = list[i]
        ctx:AddStat(string.format("%d) %s", i, moment.label or "?"), moment.tooltip)
    end
end

local function AddMomentSections(ctx, snapshot)
    ctx:AddSection(string.format("Top Healing Moments (%d)", TOP_MOMENTS_LIMIT))
    AddMomentRows(ctx, snapshot.topHealingMoments, "No healing moments yet.", "No healing events in this fight")
    ctx:AddSection(string.format("Top Mitigation Moments (%d)", TOP_MOMENTS_LIMIT))
    AddMomentRows(ctx, snapshot.topMitigationMoments, "No mitigation moments yet.", "No blocked or shielded moments in this fight")
end

---------------------------------------------------------------------------
-- Runtime FPS text (main panel)
---------------------------------------------------------------------------
function ConsoleMetrics:GetRuntimeFpsText()
    local getFramerate = type(_G) == "table" and _G.GetFramerate or nil
    local currentText = "n/a"
    if type(getFramerate) == "function" then
        local fps = tonumber(getFramerate())
        if fps then
            currentText = string.format("%.1f", fps)
        end
    end

    local stats = self.fpsRuntime
    if type(stats) ~= "table" or (stats.samples or 0) <= 0 then
        return string.format("%s (avg n/a / min n/a / 1%% low n/a)", currentText)
    end

    local avg = (stats.total or 0) / math.max(stats.samples or 1, 1)
    local minFps = stats.min
    local low1 = nil
    if type(stats.bins) == "table" then
        local worstCount = math.max(1, math.floor((stats.samples or 0) * 0.01 + 0.5))
        local remaining = worstCount
        local total = 0
        for bucket = 0, 120 do
            local count = tonumber(stats.bins[bucket + 1]) or 0
            if count > 0 then
                local take = math.min(count, remaining)
                total = total + (bucket * take)
                remaining = remaining - take
                if remaining <= 0 then
                    break
                end
            end
        end
        if worstCount > 0 then
            low1 = total / worstCount
        end
    end

    local low1Text = type(low1) == "number" and string.format("%.1f", low1) or "n/a"
    if type(minFps) ~= "number" then
        return string.format("%s (avg %.1f / min n/a / 1%% low %s)", currentText, avg, low1Text)
    end

    return string.format("%s (avg %.1f / min %.1f / 1%% low %s)", currentText, avg, minFps, low1Text)
end

---------------------------------------------------------------------------
-- Panel renderers
---------------------------------------------------------------------------
local function RenderMain(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local viewingText = ctx.viewingText

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Console Metrics Main (%s)", viewingText),
        tooltip = "Choose a panel for detailed breakdowns",
    })

    ctx:AddStat(string.format("Duration: %.1fs", snapshot.duration or 0), "Current viewed fight duration")
    ctx:AddStat(string.format("FPS: %s", self:GetRuntimeFpsText()), "Current client framerate. Low FPS can indicate UI/combat load.")
    ctx:AddStat(string.format("DPS: %s", ShortNumber(snapshot.dps)), "Current viewed fight DPS")
    ctx:AddStat(string.format("HPS: %s", ShortNumber(snapshot.hps)), "Current viewed fight HPS")
    local behaviorSummary = ctx:GetBehavior()
    ctx:AddStat(string.format("Predicted Resistance: %s", NumberText(behaviorSummary.predictedResistance or 0)), "ML-lite resistance estimate")
    ctx:AddStat(string.format("All Effects Tracked: %d", #(snapshot.allEffectList or {})), "Unique effects seen in combat state changes")
    ctx:AddStat(string.format("Major/Minor Effects Tracked: %d", #(snapshot.majorMinorList or {})), "Unique Major and Minor effects seen this fight")
    ctx:AddStat(string.format("Popular Sets Tracked: %d", #(snapshot.setProcList or {})), "Unique popular PvE/PvP sets seen this fight")
    ctx:AddButton("Open Build Snapshot Panel", "Current front/back bars, equipped loadout, and boon snapshot", function()
        self.dialogPanel = "build"
    end)
    ctx:AddButton("Open Save Fight Panel", "Name the current fight and save it into a persistent slot", function()
        if TrimText(self.saved.saveFightDraftName or "") == "" then
            self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #self:GetSavedFights() + 1)
        end
        self.dialogPanel = "save"
    end)
    ctx:AddButton("Open Saved Fights Panel", string.format("Save and load fights across sessions (%d saved)", #self:GetSavedFights()), function()
        self.dialogPanel = "saves"
    end)
    AddFightNavButtons(ctx)

    ctx:AddButton("Open Overview Panel", "General fight totals and timeline controls", function()
        self.dialogPanel = "overview"
    end)
    ctx:AddButton("Open Resource Panel", "Fight resource averages, medians, and sustain profile", function()
        self.dialogPanel = "resources"
    end)
    ctx:AddButton("Open Mitigation/Healing Panel", "Mitigation totals and top moments", function()
        self.dialogPanel = "mitigation"
    end)
    ctx:AddButton("Open Resistance/DR Panel", "Resistance, DR, and inferred protections", function()
        self.dialogPanel = "resistance"
    end)
    ctx:AddButton("Open Buff Uptime Panel", "All Major/Minor uptimes plus popular PvE/PvP set procs", function()
        self.dialogPanel = "buffs"
    end)
    ctx:AddButton("Open Skills Panel", "Top damage and healing moments", function()
        self.dialogPanel = "skills"
    end)
    ctx:AddButton("Open ML Model Panel", "Prediction model outputs and confidence", function()
        self.dialogPanel = "behavior"
    end)
    if self.LibFightsBridge.IsAvailable() then
        ctx:AddButton("Open LibFights Panel", "Fight metrics and predictions from the LibFights library", function()
            self.dialogPanel = "libfights"
        end)
    end
    ctx:AddButton("Open Formula Panel", "ESO stat math reference and addon equations", function()
        self.dialogPanel = "formulas"
    end)
    ctx:AddButton("Open Options Panel", "Toggles, clear, and help explanations", function()
        self.dialogPanel = "options"
    end)
    ctx:AddButton("Open Share Panel", "Send fight stats or build to chat", function()
        self.dialogPanel = "share"
    end)

    ctx:AddCloseButton()
end

local function RenderOverview(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local viewingText = ctx.viewingText

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Overview Panel (%s)", viewingText),
        tooltip = "Overall fight statistics and timeline",
    })

    local burstStats = snapshot.burstWindowStats or {}
    local healingStats = snapshot.healingWindowStats or {}

    local function IntervalText(stats)
        local intervalMs = tonumber(stats.intervalMs) or 1000
        return string.format("%d ms", intervalMs)
    end

    local function WindowPointText(stats, keyPrefix)
        local value = NumberText(tonumber(stats[keyPrefix .. "Value"]) or 0)
        local rel = tostring(stats[keyPrefix .. "WindowTime"] or "n/a")
        local dt = tostring(stats[keyPrefix .. "WindowDateTime"] or "n/a")
        return string.format("%s at %s (%s)", value, rel, dt)
    end

    local overviewLines = {
        string.format("Duration: %.1fs", snapshot.duration or 0),
        string.format("DPS: %s", ShortNumber(snapshot.dps)),
        string.format("HPS: %s", ShortNumber(snapshot.hps)),
        string.format("Damage Done: %s", NumberText(snapshot.totalDamage)),
        string.format("Healing Done: %s", NumberText(snapshot.totalHeal)),
        string.format("Damage Taken: %s", NumberText(snapshot.totalTaken)),
        string.format("Crit Rate: %.1f%%", snapshot.critPct or 0),
        string.format("Hit Value Range: %s - %s", NumberText(snapshot.minHitValue or 0), NumberText(snapshot.maxHitValue or 0)),
        string.format("Peak DPS: %s", ShortNumber(snapshot.peakDps or 0)),
        string.format("Peak HPS: %s", ShortNumber(snapshot.peakHps or 0)),
        string.format("Burst Window Interval: %s", IntervalText(burstStats)),
        string.format("Peak Burst Window: %s", WindowPointText(burstStats, "peak")),
        string.format("Lowest Burst Window: %s", WindowPointText(burstStats, "lowest")),
        string.format("Healing Window Interval: %s", IntervalText(healingStats)),
        string.format("Peak Healing Window: %s", WindowPointText(healingStats, "peak")),
        string.format("Lowest Healing Window: %s", WindowPointText(healingStats, "lowest")),
    }
    for i = 1, #overviewLines do
        ctx:AddStat(overviewLines[i], "Overview statistic")
    end

    AddFightNavButtons(ctx)

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderSave(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local viewingText = ctx.viewingText

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Save Fight Panel (%s)", viewingText),
        tooltip = "Give the current viewed fight a custom name, then persist it across sessions.",
    })

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_EDIT,
        label = "Fight Save Name",
        tooltip = "Enter any name you want for this saved fight.",
        getFunction = function()
            return self.saved.saveFightDraftName or ""
        end,
        setFunction = function(value)
            self.saved.saveFightDraftName = TrimText(value)
        end,
        maxChars = 80,
    })

    ctx:AddStat(string.format("Preview Duration: %.1fs", snapshot.duration or 0), "Current viewed fight duration.")
    ctx:AddStat(string.format("Preview DPS/HPS: %s / %s", ShortNumber(snapshot.dps or 0), ShortNumber(snapshot.hps or 0)), "Current viewed fight throughput preview.")
    ctx:AddStat(string.format("Preview Totals: %s dmg / %s heal / %s taken", ShortNumber(snapshot.totalDamage or 0), ShortNumber(snapshot.totalHeal or 0), ShortNumber(snapshot.totalTaken or 0)), "What will be stored into the saved slot.")

    ctx:AddButton("Use Auto Name", "Generate the default slot label from this fight's summary.", function()
        self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #self:GetSavedFights() + 1)
    end)
    ctx:AddButton("Clear Draft Name", "Clear the custom fight name and fall back to auto-name on save.", function()
        self.saved.saveFightDraftName = ""
    end)
    ctx:AddButton("Save Viewed Fight", "Persist this fight using the current draft name or auto-name if blank.", function()
        local ok, msg = self:SaveViewedFight()
        self:Print(msg)
        if ok then
            self.dialogPanel = "saves"
        end
    end)

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderResources(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local viewingText = ctx.viewingText

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Resource Panel (%s)", viewingText),
        tooltip = "Fight-duration average and median resource values with sustain profile",
    })

    local resourceSummary = snapshot.resourceSummary or {}
    local hpStats = resourceSummary.health or {}
    local magStats = resourceSummary.magicka or {}
    local stamStats = resourceSummary.stamina or {}
    local sustainStats = resourceSummary.sustain or {}
    local sampleCount = resourceSummary.sampleCount or 0

    ctx:AddStat(
        string.format("Samples: %d", sampleCount),
        string.format("Resource samples are recorded every %.1fs during combat.", RESOURCE_SAMPLE_INTERVAL_MS / 1000)
    )

    local rpt = GetResourcePowerTypes()
    local hpMax = SafeGetMaxPowerFromList(rpt.health) or 0
    local magMax = SafeGetMaxPowerFromList(rpt.magicka) or 0
    local stamMax = SafeGetMaxPowerFromList(rpt.stamina) or 0

    local function AddResourceSustainLine(label, stats, maxValue, colorHex)
        if not stats.hasData then
            ctx:AddStat(
                string.format("%s Avg/Median: n/a", label),
                "No fight-duration samples available for this resource yet."
            )
            return
        end

        local avgPctText = ColorText(string.format("%.1f%%", stats.averagePct or 0), colorHex)
        local medPctText = ColorText(string.format("%.1f%%", stats.medianPct or 0), colorHex)
        if maxValue and maxValue > 0 then
            local avgValue = (stats.averagePct or 0) * maxValue / 100
            local medValue = (stats.medianPct or 0) * maxValue / 100
            ctx:AddStat(
                string.format("%s Avg/Median: %s/%s (%s/%s)", label, NumberText(avgValue), NumberText(medValue), avgPctText, medPctText),
                string.format("Fight sustain trend for %s based on %d total samples.", label, sampleCount)
            )
            return
        end

        ctx:AddStat(
            string.format("%s Avg/Median: %s/%s", label, avgPctText, medPctText),
            string.format("Fight sustain trend for %s based on %d total samples.", label, sampleCount)
        )
    end

    AddResourceSustainLine("Health", hpStats, hpMax, COMBAT_COLOR_HEX.heal)
    AddResourceSustainLine("Magicka", magStats, magMax, COMBAT_COLOR_HEX.summary)
    AddResourceSustainLine("Stamina", stamStats, stamMax, COMBAT_COLOR_HEX.damage)

    if sustainStats.hasData then
        local sustainHex = COMBAT_COLOR_HEX.heal
        if sustainStats.label == "Pressured" then
            sustainHex = COMBAT_COLOR_HEX.summary
        elseif sustainStats.label == "Critical" then
            sustainHex = COMBAT_COLOR_HEX.taken
        elseif sustainStats.label == "Strong" then
            sustainHex = COMBAT_COLOR_HEX.healCrit
        end

        ctx:AddStat(
            string.format(
                "Sustain Avg/Median: %s/%s (%s)",
                ColorText(string.format("%.1f%%", sustainStats.averagePct or 0), sustainHex),
                ColorText(string.format("%.1f%%", sustainStats.medianPct or 0), sustainHex),
                ColorText(sustainStats.label or "Stable", sustainHex)
            ),
            "Sustain score uses average Magicka/Stamina fight percentages across sampled combat time."
        )
    else
        ctx:AddStat(
            "Sustain Avg/Median: n/a",
            "No Magicka/Stamina sampling data yet. Enter combat to build sustain history."
        )
    end

    -- Regen / Drain / Ultimate Gen section
    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Regen / Drain / Ultimate Gen",
        tooltip = "Cumulative resource gains (regen) and spends (drain) sampled each second during combat.",
    })

    local fightDuration = snapshot.duration or 0
    local rsm = resourceSummary

    local function AddRegenDrainLine(label, totalRegen, totalDrain, colorRegen, colorDrain)
        local regenPs = fightDuration > 0 and (totalRegen / fightDuration) or 0
        local drainPs = fightDuration > 0 and (totalDrain / fightDuration) or 0
        ctx:AddStat(
            string.format("%s Regen/Drain: %s/%s (%s/%s)",
                label,
                ColorText(NumberText(math.floor(totalRegen)), colorRegen),
                ColorText(NumberText(math.floor(totalDrain)), colorDrain),
                ColorText(string.format("%.1f/s", regenPs), colorRegen),
                ColorText(string.format("%.1f/s", drainPs), colorDrain)
            ),
            string.format("%s: +%s total regen | -%s total drain over %.1fs (%.1f/s regen, %.1f/s drain).",
                label, NumberText(math.floor(totalRegen)), NumberText(math.floor(totalDrain)), fightDuration, regenPs, drainPs)
        )
    end

    local hpR,  hpD  = rsm.totalHealthRegen  or 0, rsm.totalHealthDrain  or 0
    local magR, magD = rsm.totalMagickaRegen or 0, rsm.totalMagickaDrain or 0
    local stR,  stD  = rsm.totalStaminaRegen or 0, rsm.totalStaminaDrain or 0
    local ultG, ultD = rsm.totalUltimateGen  or 0, rsm.totalUltimateDrain or 0

    if hpR > 0 or hpD > 0 then
        AddRegenDrainLine("Health",   hpR,  hpD,  COMBAT_COLOR_HEX.heal,    COMBAT_COLOR_HEX.taken)
    else
        ctx:AddStat("Health Regen/Drain: n/a", "No health regen/drain data yet.")
    end
    if magR > 0 or magD > 0 then
        AddRegenDrainLine("Magicka", magR, magD, COMBAT_COLOR_HEX.summary, COMBAT_COLOR_HEX.taken)
    else
        ctx:AddStat("Magicka Regen/Drain: n/a", "No magicka regen/drain data yet.")
    end
    if stR > 0 or stD > 0 then
        AddRegenDrainLine("Stamina", stR,  stD,  COMBAT_COLOR_HEX.damage,  COMBAT_COLOR_HEX.taken)
    else
        ctx:AddStat("Stamina Regen/Drain: n/a", "No stamina regen/drain data yet.")
    end

    local ultGenPs = fightDuration > 0 and (ultG / fightDuration) or 0
    if ultG > 0 or ultD > 0 then
        ctx:AddStat(
            string.format("Ultimate Gen/Spend: %s/%s (%s)",
                ColorText(NumberText(math.floor(ultG)), COMBAT_COLOR_HEX.summary),
                ColorText(NumberText(math.floor(ultD)), COMBAT_COLOR_HEX.taken),
                ColorText(string.format("%.2f/s", ultGenPs), COMBAT_COLOR_HEX.summary)
            ),
            string.format("Ultimate: +%s generated | -%s spent over %.1fs (%.2f gen/s).",
                NumberText(math.floor(ultG)), NumberText(math.floor(ultD)), fightDuration, ultGenPs)
        )
    else
        ctx:AddStat("Ultimate Gen/Spend: n/a", "No ultimate generation data yet.")
    end

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Delay / Ping",
        tooltip = "Latency sampled each second during combat. Tracks dips, spikes, and high-delay windows.",
    })

    local pingStats = resourceSummary.ping or {}
    if pingStats.hasData then
        local function PingMsText(value)
            return NumberText(math.floor((value or 0) + 0.5))
        end

        local sampleTotal = pingStats.samples or 0
        local highDelay = pingStats.highDelaySamples or 0
        local highDelayPct = sampleTotal > 0 and ((highDelay / sampleTotal) * 100) or 0

        ctx:AddStat(
            string.format("Ping Avg/Median: %s/%s ms",
                ColorText(PingMsText(pingStats.averageMs), COMBAT_COLOR_HEX.summary),
                ColorText(PingMsText(pingStats.medianMs), COMBAT_COLOR_HEX.summary)
            ),
            "Average and median ping sampled during this fight."
        )

        ctx:AddStat(
            string.format("Ping Min/Max: %s/%s ms",
                ColorText(PingMsText(pingStats.minMs), COMBAT_COLOR_HEX.heal),
                ColorText(PingMsText(pingStats.maxMs), COMBAT_COLOR_HEX.taken)
            ),
            "Lowest and highest ping observed in combat samples."
        )

        ctx:AddStat(
            string.format("Ping Dips/Spikes: %s/%s",
                ColorText(NumberText(pingStats.dips or 0), COMBAT_COLOR_HEX.heal),
                ColorText(NumberText(pingStats.spikes or 0), COMBAT_COLOR_HEX.taken)
            ),
            string.format("Dip: ping dropped by >= %dms between samples. Spike: ping rose by >= %dms.", PING_DIP_DELTA_MS, PING_SPIKE_DELTA_MS)
        )

        ctx:AddStat(
            string.format("High Delay Samples: %s/%s (%.1f%% >= %dms)",
                ColorText(NumberText(highDelay), COMBAT_COLOR_HEX.taken),
                NumberText(sampleTotal),
                highDelayPct,
                pingStats.highDelayThresholdMs or PING_HIGH_DELAY_MS
            ),
            "How often ping exceeded the configured high-delay threshold in this fight."
        )
    else
        ctx:AddStat("Ping Avg/Median: n/a", "Latency API unavailable in this context or no ping samples yet.")
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderMitigation(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Mitigation / Healing Panel",
        tooltip = "Incoming/outgoing mitigation with top moments",
    })

    local outgoingMitigated = (snapshot.totalBlockedDamage or 0) + (snapshot.totalShieldedDamage or 0)
    local incomingMitigated = (snapshot.totalIncomingBlockedDamage or 0) + (snapshot.totalIncomingShieldedDamage or 0)
    local mitigationLines = {
        string.format("Outgoing Mitigated: %s", NumberText(outgoingMitigated)),
        string.format("Incoming Mitigated: %s", NumberText(incomingMitigated)),
        string.format("Outgoing Blocked: %s", NumberText(snapshot.totalBlockedDamage or 0)),
        string.format("Outgoing Shielded: %s", NumberText(snapshot.totalShieldedDamage or 0)),
        string.format("Incoming Blocked: %s", NumberText(snapshot.totalIncomingBlockedDamage or 0)),
        string.format("Incoming Shielded: %s", NumberText(snapshot.totalIncomingShieldedDamage or 0)),
        string.format("Overflow Damage: %s", NumberText(snapshot.totalOverflowDamage or 0)),
        string.format("Overflow Healing: %s", NumberText(snapshot.totalOverflowHeal or 0)),
    }
    for i = 1, #mitigationLines do
        ctx:AddStat(mitigationLines[i], "Mitigation/healing statistic")
    end

    ctx:AddSection("Skills That Damaged You")
    AddStatRows(ctx, snapshot.incomingSkillList, 20, "damage", COMBAT_COLOR_HEX.taken, function(skill)
        return string.format("Source: %s | Hits: %d | Crits: %d", skill.source or "Unknown", skill.hits or 0, skill.crits or 0)
    end, "No incoming skill damage yet.", "No enemy damage events recorded against you in this fight")

    ctx:AddSection("Set Procs That Damaged You")
    if not snapshot.incomingSetDamageList or #snapshot.incomingSetDamageList == 0 then
        ctx:AddStat("No incoming set proc damage yet.", "No incoming skills matched your tracked popular set catalog")
    else
        for i = 1, math.min(20, #snapshot.incomingSetDamageList) do
            local setProc = snapshot.incomingSetDamageList[i]
            local setCritPct = (setProc.hits or 0) > 0 and (((setProc.crits or 0) / setProc.hits) * 100) or 0
            ctx:AddStat(
                string.format("%d) [%s] %s - %s (%.0f%% crit)", i, setProc.scene or "Set", setProc.name, ColorShort(setProc.damage, COMBAT_COLOR_HEX.taken), setCritPct),
                string.format("Proc ability: %s | Source: %s | Hits: %d", FormatAbilityIdentity(setProc.effectName or setProc.name, setProc.abilityId), setProc.source or "Unknown", setProc.hits or 0)
            )
        end
    end

    ctx:AddSection("Likely Set Procs (Heuristic)")
    AddStatRows(ctx, snapshot.incomingLikelySetProcList, 20, "damage", COMBAT_COLOR_HEX.summary, function(proc)
        return string.format("Heuristic score: %.1f | Signals: %s | Source: %s", proc.heuristicScore or 0, proc.heuristicReason or "n/a", proc.source or "Unknown")
    end, "No likely set procs detected.", "Heuristic mode found no additional likely set-proc ability names")

    AddMomentSections(ctx, snapshot)

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderBuild(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    local frontBarCategory = type(HOTBAR_CATEGORY_PRIMARY) == "number" and HOTBAR_CATEGORY_PRIMARY or nil
    local backBarCategory = type(HOTBAR_CATEGORY_BACKUP) == "number" and HOTBAR_CATEGORY_BACKUP or nil
    local frontBar = BuildActionBarSnapshot(frontBarCategory)
    local backBar = BuildActionBarSnapshot(backBarCategory)
    local championSnapshot = BuildChampionSnapshot()
    local equipment = BuildEquipmentSnapshot()
    local equippedSets = BuildEquippedSetSummary()
    local weaponEffects = BuildWeaponEffectSnapshot()
    local procTimers = self:BuildProcTimerSnapshot()
    local boons = BuildActiveBoonSnapshot()

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Build Snapshot Panel",
        tooltip = "Console-style build snapshot: player stats, equipped gear, bars, and active boon-style buffs.",
    })

    -- Player Stats Section
    local function SafeGetPlayerStat(statType)
        if type(GetPlayerStat) ~= "function" or type(statType) ~= "number" then
            return nil
        end
        local applyBonus = type(STAT_BONUS_OPTION_APPLY_BONUS) == "number" and STAT_BONUS_OPTION_APPLY_BONUS or nil
        local applySoftCap = type(STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP) == "number" and STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP or nil
        local a, b, c, d = GetPlayerStat(statType, applyBonus, applySoftCap)
        for i = 1, 4 do
            local val = tonumber(select(i, a, b, c, d))
            if val and val > 0 then return val end
        end
        a, b, c, d = GetPlayerStat(statType)
        for i = 1, 4 do
            local val = tonumber(select(i, a, b, c, d))
            if val and val > 0 then return val end
        end
        return nil
    end

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Player Stats",
        tooltip = "Current character stats.",
    })

    local hpMax = SafeGetPlayerStat(type(STAT_HEALTH_MAX) == "number" and STAT_HEALTH_MAX or nil)
    local stamMax = SafeGetPlayerStat(type(STAT_STAMINA_MAX) == "number" and STAT_STAMINA_MAX or nil)
    local magMax = SafeGetPlayerStat(type(STAT_MAGICKA_MAX) == "number" and STAT_MAGICKA_MAX or nil)
    local physRes = SafeGetPlayerStat(type(STAT_PHYSICAL_RESISTANCE) == "number" and STAT_PHYSICAL_RESISTANCE or nil)
    local spellRes = SafeGetPlayerStat(type(STAT_SPELL_RESISTANCE) == "number" and STAT_SPELL_RESISTANCE or nil)
    local critRes = SafeGetPlayerStat(type(STAT_CRITICAL_RESISTANCE) == "number" and STAT_CRITICAL_RESISTANCE or nil)
    local weaponDmg = SafeGetPlayerStat(type(STAT_WEAPON_DAMAGE) == "number" and STAT_WEAPON_DAMAGE or nil)
    local spellDmg = SafeGetPlayerStat(type(STAT_SPELL_DAMAGE) == "number" and STAT_SPELL_DAMAGE or nil)
    local armorPen = SafeGetPlayerStat(type(STAT_ARMOR_PENETRATION) == "number" and STAT_ARMOR_PENETRATION or nil)
    local spellPen = SafeGetPlayerStat(type(STAT_SPELL_PENETRATION) == "number" and STAT_SPELL_PENETRATION or nil)
    local critChance = SafeGetPlayerStat(type(STAT_CRITICAL_STRIKE) == "number" and STAT_CRITICAL_STRIKE or nil)
    local critDamage = SafeGetPlayerStat(type(STAT_CRITICAL_DAMAGE) == "number" and STAT_CRITICAL_DAMAGE or nil)

    local function SafeFormatCritChance(value)
        if not value then
            return nil
        end
        if type(GetCriticalStrikeChance) == "function" then
            local ok, pct = pcall(GetCriticalStrikeChance, value)
            if ok and type(pct) == "number" then
                return pct
            end
        end
        return tonumber(value)
    end

    if hpMax then
        ctx:AddStat(string.format("Max HP: %s", NumberText(math.floor(hpMax))), "Maximum Health")
    end
    if stamMax then
        ctx:AddStat(string.format("Max Stamina: %s", NumberText(math.floor(stamMax))), "Maximum Stamina")
    end
    if magMax then
        ctx:AddStat(string.format("Max Magicka: %s", NumberText(math.floor(magMax))), "Maximum Magicka")
    end
    if physRes then
        ctx:AddStat(string.format("Phys Resist: %s", NumberText(math.floor(physRes))), "Physical Resistance")
    end
    if spellRes then
        ctx:AddStat(string.format("Spell Resist: %s", NumberText(math.floor(spellRes))), "Spell Resistance")
    end
    if critRes then
        ctx:AddStat(string.format("Crit Resist: %s", NumberText(math.floor(critRes))), "Critical Resistance")
    end
    if weaponDmg then
        ctx:AddStat(string.format("Weapon Dmg: %s", NumberText(math.floor(weaponDmg))), "Weapon Damage")
    end
    if spellDmg then
        ctx:AddStat(string.format("Spell Dmg: %s", NumberText(math.floor(spellDmg))), "Spell Damage")
    end
    if armorPen then
        ctx:AddStat(string.format("Armor Pen: %s", NumberText(math.floor(armorPen))), "Armor Penetration")
    end
    if spellPen then
        ctx:AddStat(string.format("Spell Pen: %s", NumberText(math.floor(spellPen))), "Spell Penetration")
    end
    if critChance then
        local critChancePct = SafeFormatCritChance(critChance)
        if critChancePct then
            ctx:AddStat(
                string.format("Crit Chance: %.1f%%", critChancePct),
                "Critical Strike Chance"
            )
        end
    end
    if critDamage then
        ctx:AddStat(string.format("Crit Dmg: %.1f%%", critDamage), "Critical Damage Bonus")
    end

    ctx:AddSection("Equipped Armor")
    if #equipment == 0 then
        ctx:AddStat("No equipment data available.", "Equipment API unavailable in this context.")
    else
        for i = 1, #equipment do
            local item = equipment[i]
            ctx:AddStat(
                string.format("%s: %s", item.label, item.text),
                string.format("Equipped in %s slot.", item.label)
            )
        end
    end

    if championSnapshot.totalPoints then
        ctx:AddStat(
            string.format("Champion Points: %s", NumberText(championSnapshot.totalPoints)),
            "Current earned Champion Point total."
        )
    end

    ctx:AddSection("Front Bar")
    for i = 1, #frontBar do
        local entry = frontBar[i]
        ctx:AddStat(
            string.format("%s: %s", entry.slotLabel, entry.abilityName),
            string.format("Ability ID: %d", entry.abilityId or 0)
        )
    end

    ctx:AddSection("Back Bar")
    for i = 1, #backBar do
        local entry = backBar[i]
        ctx:AddStat(
            string.format("%s: %s", entry.slotLabel, entry.abilityName),
            string.format("Ability ID: %d", entry.abilityId or 0)
        )
    end

    ctx:AddSection("Champion Snapshot")
    local function AddChampionBucket(label, entries)
        if #entries == 0 then
            ctx:AddStat(string.format("%s: unavailable", label), string.format("No %s champion data exposed in this context.", string.lower(label)))
            return
        end

        for i = 1, #entries do
            local entry = entries[i]
            local starText = #entry.stars > 0 and table.concat(entry.stars, ", ") or "No slotted stars detected"
            ctx:AddStat(
                string.format("%s: %s pts", entry.name, NumberText(entry.points or 0)),
                string.format("%s stars: %s", label, starText)
            )
        end
    end

    if championSnapshot.available then
        AddChampionBucket("Warfare", championSnapshot.warfare)
        AddChampionBucket("Fitness", championSnapshot.fitness)
        AddChampionBucket("Craft", championSnapshot.craft)
    else
        ctx:AddStat("Champion data unavailable.", "Champion discipline APIs did not expose data in this build/context.")
    end

    ctx:AddSection("Equipped Sets")
    if #equippedSets == 0 then
        ctx:AddStat("No equipped set data available.", "Set API unavailable or no set items are equipped.")
    else
        for i = 1, #equippedSets do
            local setInfo = equippedSets[i]
            ctx:AddStat(
                string.format("%s (%d/%d)", setInfo.setName, setInfo.numEquipped or 0, setInfo.maxEquipped or 0),
                string.format("Equipped on: %s", table.concat(setInfo.slots or {}, ", "))
            )
        end
    end

    ctx:AddSection("Weapon Enchants / Poisons")
    if #weaponEffects == 0 then
        ctx:AddStat("No weapon detail data available.", "Weapon detail API unavailable in this context.")
    else
        for i = 1, #weaponEffects do
            local entry = weaponEffects[i]
            ctx:AddStat(
                string.format("%s: %s", entry.label, entry.itemText),
                string.format("Enchant: %s | Poison: %s", entry.enchantText, entry.poisonText)
            )
        end
    end

    ctx:AddSection("Proc Timers / Ready")
    if #procTimers == 0 then
        ctx:AddStat("No tracked proc timers available.", "Import PvPCooldownTracker rules or equip tracked sets to populate this section.")
    else
        for i = 1, #procTimers do
            local entry = procTimers[i]
            local sourceBits = {}
            if entry.fromPCT then
                sourceBits[#sourceBits + 1] = "PCT"
            end
            if entry.fromCustomRule then
                sourceBits[#sourceBits + 1] = "CM"
            end
            local sourceText = #sourceBits > 0 and table.concat(sourceBits, "/") or "tracked"
            ctx:AddStat(
                string.format("%s: %s", entry.label, entry.stateText),
                string.format("Cooldown: %.1fs | Equipped: %d/%d | Source: %s", (entry.cooldownMs or 0) / 1000, entry.numEquipped or 0, entry.maxEquipped or 0, sourceText)
            )
        end
    end

    ctx:AddSection("Boon / Mundus")
    if #boons == 0 then
        ctx:AddStat("No boon-style buff detected.", "If ESO exposes the current boon through buffs here, it will show up in this list.")
    else
        for i = 1, #boons do
            ctx:AddStat(boons[i], "Active boon or mundus-style buff detected on the player.")
        end
    end

    ctx:AddButton("Print Build Debug", "Print the current Build Snapshot panel data to chat.", function()
        self:PrintBuildSnapshotDebug("build-panel")
    end)

    ctx:AddButton("Link Build in Chat", "Pre-fill chat input with a compact build summary you can send to group/zone.", function()
        self:LinkBuildToChat()
    end)

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderResistance(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    local behaviorSummary = ctx:GetBehavior()
    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Resistance / DR Panel",
        tooltip = "Machine learning inference for target resistance and protections",
    })

    if not snapshot.targetList or #snapshot.targetList == 0 then
        ctx:AddStat("No target data yet.", "No resistance samples available")
    else
        for i = 1, math.min(5, #snapshot.targetList) do
            local target = snapshot.targetList[i]
            local drPct = Clamp(((target.estimatedResistance or 0) / RESISTANCE_SCALE) * 100, 0, 50)
            local label, _, confidence = InferProtectionFromDr(drPct, true)
            ctx:AddStat(
                string.format("%d) %s - %s res (DR %.1f%%)", i, target.name, NumberText(target.estimatedResistance), drPct),
                "Estimated resistance and inferred DR"
            )
            ctx:AddStat(
                string.format("   %s (confidence %.0f%%)", label, confidence * 100),
                "Inferred protection state"
            )
        end
    end

    ctx:AddStat(string.format("Predicted Resistance: %s", NumberText(behaviorSummary.predictedResistance or 0)), "ML-lite predicted resistance")
    ctx:AddStat(string.format("Predicted DR: %.1f%%", behaviorSummary.predictedDrPct or 0), "Predicted DR from resistance model")
    ctx:AddStat(string.format("Predicted Protections: %s", behaviorSummary.predictedProtectionLabel or "No mitigation data"), "Protection state inferred from predicted DR")

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderBuffs(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    local ps = snapshot.protectionSummary or BuildProtectionSummary(nil, 0)
    local allEffectList = snapshot.allEffectList or {}
    local majorMinorList = snapshot.majorMinorList or {}
    local setProcList = snapshot.setProcList or {}

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Buff Uptime Panel (Inferred)",
        tooltip = "Protection uptime, every Major/Minor effect, and popular set coverage",
    })

    -- First section keeps the inferred protection model summary visible at the top.
    ctx:AddStat(string.format("Tracked Time: %s", FormatMs(ps.totalMs)), "Total time with inference samples")
    ctx:AddStat(string.format("Any Protection Uptime: %.1f%% (%s)", ps.anyProtectionPct or 0, FormatMs(ps.anyProtectionMs)), "Major/Minor/Combined inferred uptime")
    ctx:AddStat(string.format("Any Protection Downtime: %.1f%% (%s)", 100 - (ps.anyProtectionPct or 0), FormatMs((ps.noneMs or 0) + (ps.unknownMs or 0))), "No protection or unknown time")

    ctx:AddStat(string.format("Major Uptime: %.1f%% (%s)", ps.majorPct or 0, FormatMs(ps.majorMs)), "Inferred major protection uptime")
    ctx:AddStat(string.format("Major Downtime: %.1f%%", 100 - (ps.majorPct or 0)), "Time without inferred major protection")

    ctx:AddStat(string.format("Minor Uptime: %.1f%% (%s)", ps.minorPct or 0, FormatMs(ps.minorMs)), "Inferred minor protection uptime")
    ctx:AddStat(string.format("Minor Downtime: %.1f%%", 100 - (ps.minorPct or 0)), "Time without inferred minor protection")

    ctx:AddStat(string.format("Major+Minor Uptime: %.1f%% (%s)", ps.majorMinorPct or 0, FormatMs(ps.majorMinorMs)), "Inferred simultaneous major+minor protection")
    ctx:AddStat(string.format("Unknown Inference Time: %.1f%% (%s)", ps.unknownPct or 0, FormatMs(ps.unknownMs)), "No mitigation signal available")

    -- Full effect list gives a direct answer to "what was active and for how long".
    ctx:AddSection("All Effects and Uptime")
    if #allEffectList == 0 then
        ctx:AddStat("No effects tracked yet.", "Effect rows appear when effect gained/faded events are seen")
    else
        for i = 1, math.min(EFFECTS_PANEL_LIMIT, #allEffectList) do
            local effect = allEffectList[i]
            ctx:AddStat(
                string.format(
                    "%d) %s [id:%d] - %.1f%% (%s)",
                    i,
                    effect.name,
                    effect.abilityId or 0,
                    effect.uptimePct or 0,
                    FormatMs(effect.uptimeMs)
                ),
                string.format("Effect: %s | Activations: %d | Fades: %d", effect.effectName or effect.name or "Unknown", effect.activations or 0, effect.fades or 0)
            )
        end
        if #allEffectList > EFFECTS_PANEL_LIMIT then
            ctx:AddStat(
                string.format("Showing top %d of %d effects", EFFECTS_PANEL_LIMIT, #allEffectList),
                "Panel limits rows for gamepad readability"
            )
        end
    end

    -- Major/Minor subset is preserved separately for quick combat readability.
    ctx:AddSection("All Major/Minor Effects")
    if #majorMinorList == 0 then
        ctx:AddStat("No Major/Minor effects tracked yet.", "Major/Minor uptime appears after matching combat events")
    else
        for i = 1, #majorMinorList do
            local effect = majorMinorList[i]
            ctx:AddStat(
                string.format(
                    "%d) [%s] %s [id:%d] - %.1f%% (%s) procs:%d",
                    i,
                    effect.category or "Effect",
                    effect.name,
                    effect.abilityId or 0,
                    effect.uptimePct or 0,
                    FormatMs(effect.uptimeMs),
                    effect.procs or 0
                ),
                string.format("Effect: %s | Activations: %d | Fades: %d | Total value: %s", effect.effectName or effect.name or "Unknown", effect.activations or 0, effect.fades or 0, NumberText(effect.totalValue or 0))
            )
        end
    end

    -- Popular sets section highlights common meta sets without losing full-effect visibility above.
    ctx:AddSection("Popular PvE/PvP Set Procs")
    if #setProcList == 0 then
        ctx:AddStat("No popular set procs tracked yet.", "Set coverage appears when abilities match the tracked catalog")
    else
        for i = 1, #setProcList do
            local setInfo = setProcList[i]
            ctx:AddStat(
                string.format(
                    "%d) [%s] %s [id:%d] - %.1f%% (%s) procs:%d",
                    i,
                    setInfo.category or "Set",
                    setInfo.name,
                    setInfo.abilityId or 0,
                    setInfo.uptimePct or 0,
                    FormatMs(setInfo.uptimeMs),
                    setInfo.procs or 0
                ),
                string.format("Effect: %s | Activations: %d | Fades: %d | Total value: %s", setInfo.effectName or setInfo.name or "Unknown", setInfo.activations or 0, setInfo.fades or 0, NumberText(setInfo.totalValue or 0))
            )
        end
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderSkills(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Skills Panel (Damage)",
        tooltip = "Top 20 skills by total damage output this fight",
    })

    AddStatRows(ctx, snapshot.skillList, 20, "damage", COMBAT_COLOR_HEX.damage, function(skill)
        return string.format("Ability: %s | Hits: %d | Crits: %d", FormatAbilityIdentity(skill.name, skill.abilityId), skill.hits or 0, skill.crits or 0)
    end, "No skill data yet.", "No damage skills recorded in this fight")

    ctx:AddSection("Skills (Overall Healing)")
    AddStatRows(ctx, snapshot.healSkillList, 20, "heal", COMBAT_COLOR_HEX.heal, function(skill)
        return string.format("Ability: %s | Hits: %d | Crits: %d | Damage dealt: %s", FormatAbilityIdentity(skill.name, skill.abilityId), skill.hits or 0, skill.crits or 0, NumberText(skill.damage or 0))
    end, "No healing skill data yet.", "No healing skills recorded in this fight")

    ctx:AddSection("Top DoT Ticks (Damage over Time)")
    AddStatRows(ctx, snapshot.dotList, 20, "damage", COMBAT_COLOR_HEX.dot, function(dot)
        return string.format("DoT: %s | Total ticks: %d | Crit ticks: %d", FormatAbilityIdentity(dot.name, dot.abilityId), dot.hits or 0, dot.crits or 0)
    end, "No DoT data yet.", "No damage-over-time ticks recorded in this fight")

    ctx:AddSection("Top HoT Ticks (Heal over Time)")
    AddStatRows(ctx, snapshot.hotList, 20, "heal", COMBAT_COLOR_HEX.hot, function(hot)
        return string.format("HoT: %s | Total ticks: %d | Crit ticks: %d", FormatAbilityIdentity(hot.name, hot.abilityId), hot.hits or 0, hot.crits or 0)
    end, "No HoT data yet.", "No heal-over-time ticks recorded in this fight")

    AddMomentSections(ctx, snapshot)

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderBehavior(ctx)
    local dialog = ctx.dialog

    local behaviorSummary = ctx:GetBehavior()
    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Behavior Model Panel (ML-lite)",
        tooltip = "Model predictions built from fight history using EMA + trend extrapolation",
    })

    local behaviorRows = {
        {
            label = string.format("Samples: %d", behaviorSummary.samples or 0),
            tooltip = "Total fight summaries used by the model (history plus live fight when non-empty)",
        },
        {
            label = string.format("Predicted Next DPS: %s", ShortNumber(behaviorSummary.predictedDps or 0)),
            tooltip = "Forecasted DPS using exponential moving average (alpha 0.35) plus linear slope",
        },
        {
            label = string.format("Predicted Next HPS: %s", ShortNumber(behaviorSummary.predictedHps or 0)),
            tooltip = "Forecasted HPS using exponential moving average (alpha 0.35) plus linear slope",
        },
        {
            label = string.format("Predicted Next Taken: %s", ShortNumber(behaviorSummary.predictedTaken or 0)),
            tooltip = "Forecasted incoming damage trend from previous fights and current combat",
        },
        {
            label = string.format("Predicted Resistance: %s", NumberText(behaviorSummary.predictedResistance or 0)),
            tooltip = "Estimated target resistance from observed mitigation samples, clamped to 0-33,000",
        },
        {
            label = string.format("Predicted DR: %.1f%%", behaviorSummary.predictedDrPct or 0),
            tooltip = "Damage reduction estimate from resistance using DR = resistance / 66,000 (max 50%)",
        },
        {
            label = string.format("Predicted Protections: %s", behaviorSummary.predictedProtectionLabel or "No mitigation data"),
            tooltip = "Inferred state (Major/Minor/None) from predicted DR threshold matching",
        },
        {
            label = string.format("Prediction Confidence: %.0f%%", (behaviorSummary.predictedProtectionConfidence or 0) * 100),
            tooltip = "Confidence score based on proximity to DR bands and number of resistance samples",
        },
        {
            label = string.format("Resistance Samples: %d", behaviorSummary.resistanceSamples or 0),
            tooltip = "Number of target resistance observations that fed the resistance model",
        },
        {
            label = string.format("Volatility: %.1f%%", behaviorSummary.volatilityPct or 0),
            tooltip = "Fight variance measured as DPS stddev / mean DPS",
        },
        {
            label = behaviorSummary.pressureProfile or "No pressure profile yet",
            tooltip = "Pressure profile compares predicted incoming damage versus predicted DPS",
        },
        {
            label = behaviorSummary.rhythmProfile or "No rhythm profile yet",
            tooltip = "Rhythm profile uses volatility threshold (over 35% = bursty, otherwise stable)",
        },
    }

    for i = 1, #behaviorRows do
        ctx:AddStat(behaviorRows[i].label, behaviorRows[i].tooltip)
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderFormulas(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Formula Panel (ESO + ConsoleMetrics)",
        tooltip = "Core ESO stat equations plus exact formulas used by this addon",
    })

    ctx:AddStat(
        "Coverage Notes",
        "This panel includes core published ESO equations and all formulas used by ConsoleMetrics. Some internal server formulas are undisclosed and can change by patch."
    )

    local function AddFormulaRow(title, equation, note)
        ctx:AddStat(title, string.format("%s | %s", equation, note))
    end

    local function AddFormulaSection(label)
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = label,
            tooltip = "Formula reference",
        })
    end

    AddFormulaSection("Core Throughput")
    AddFormulaRow("DPS", "DPS = TotalDamage / max(DurationSeconds, 0.001)", "Primary outgoing damage rate.")
    AddFormulaRow("HPS", "HPS = TotalHeal / max(DurationSeconds, 0.001)", "Primary outgoing healing rate.")
    AddFormulaRow("Crit Rate", "CritRatePct = (CritHits / max(Hits, 1)) * 100", "Critical hit percentage.")
    AddFormulaRow("Peak DPS", "PeakDps = max(PeakDps, CurrentDps)", "Highest observed DPS in fight.")
    AddFormulaRow("Peak HPS", "PeakHps = max(PeakHps, CurrentHps)", "Highest observed HPS in fight.")
    AddFormulaRow("Effect Uptime", "UptimePct = Clamp((UptimeMs / max(DurationMs, 1)) * 100, 0, 100)", "Used for all effect uptime rows.")
    AddFormulaRow("Any Protection Uptime", "AnyProtectionPct = (AnyProtectionMs / max(TotalMs, 1)) * 100", "Major + Minor + MajorMinor inferred states.")
    AddFormulaRow("Downtime", "DowntimePct = 100 - AnyProtectionPct", "No/unknown protection time.")

    AddFormulaSection("Resistance and DR")
    AddFormulaRow("Observed Mitigation", "MitigationRatio = Clamp((Blocked + Shielded) / (Effective + Overflow + Blocked + Shielded), 0, 0.5)", "Observed mitigation proxy from combat events.")
    AddFormulaRow("Estimated Resistance", "Resistance = Clamp(MitigationRatio * 66000, 0, 33000)", "Addon target resistance estimate.")
    AddFormulaRow("DR from Resistance", "DRPct = Clamp((Resistance / 66000) * 100, 0, 50)", "ESO linear DR approximation used by addon.")
    AddFormulaRow("After Penetration", "PostPenRes = max(TargetResistance - Penetration, 0)", "Effective resistance after pen.")
    AddFormulaRow("Post-Pen DR", "PostPenDRPct = Clamp((PostPenRes / 66000) * 100, 0, 50)", "Damage reduction after penetration.")
    AddFormulaRow("Outgoing Mitigated", "OutgoingMitigated = OutgoingBlocked + OutgoingShielded", "Displayed in mitigation panel.")
    AddFormulaRow("Incoming Mitigated", "IncomingMitigated = IncomingBlocked + IncomingShielded", "Displayed in mitigation panel.")
    AddFormulaRow("Approx Damage Taken", "DamageTakenApprox = RawDamage * (1 - PostPenDR)", "Useful sanity estimate when pen is known.")
    AddFormulaRow("Resistance Cap", "EffectiveResistCap = 33000", "Current cap used in addon constants.")

    AddFormulaSection("Crit, Scaling, Sustain")
    AddFormulaRow("Crit Chance (rating)", "CritChancePct approx = (CritRating / 21912) * 100", "Level-50 CP160 style conversion; patch dependent.")
    AddFormulaRow("Critical Hit", "CritHit = BaseHit * (1 + CritDamageBonus)", "Final crit before target-side mitigation.")
    AddFormulaRow("Crit Damage Cap", "CritDamageBonus <= 1.25 (125%)", "Common ESO cap reference.")
    AddFormulaRow("Power Approximation", "EffectivePower approx = WeaponOrSpellDamage + (MaxResource / 10.5)", "Common ESO coefficient approximation.")
    AddFormulaRow("Overheal", "Overheal = max(HealAmount - MissingHealth, 0)", "Non-effective healing.")
    AddFormulaRow("Effective Healing", "EffectiveHeal = HealAmount - Overheal", "Healing that actually restored HP.")
    AddFormulaRow("Shield Absorb", "ShieldAbsorbed = min(IncomingDamage, ActiveShield)", "Shielded portion of incoming hit.")
    AddFormulaRow("Recovery Tick", "RecoveryPerSecond = RecoveryStat / 2", "ESO recovery shown per 2s tick.")

    AddFormulaSection("Protection Inference (Exact Addon Logic)")
    AddFormulaRow("Major+Minor Threshold", "If DRPct >= (MajorPct + MinorPct - 1.0), state = majorMinor", "With current constants: DR >= 14%.")
    AddFormulaRow("Major Threshold", "Else if DRPct >= (MajorPct - 1.0), state = major", "With current constants: DR >= 9%.")
    AddFormulaRow("Minor Threshold", "Else if DRPct >= (MinorPct - 1.0), state = minor", "With current constants: DR >= 4%.")
    AddFormulaRow("No Protection", "Else state = none", "Below minor threshold.")
    AddFormulaRow("Major+Minor Confidence", "Clamp(0.65 + ((DRPct - (MajorPct + MinorPct)) / 20), 0.45, 0.98)", "Exact formula in InferProtectionFromDr.")
    AddFormulaRow("Major Confidence", "Clamp(0.60 + ((DRPct - MajorPct) / 18), 0.40, 0.95)", "Exact formula in InferProtectionFromDr.")
    AddFormulaRow("Minor Confidence", "Clamp(0.55 + ((DRPct - MinorPct) / 15), 0.35, 0.90)", "Exact formula in InferProtectionFromDr.")
    AddFormulaRow("None Confidence", "Clamp(0.50 + ((MinorPct - DRPct) / 15), 0.30, 0.90)", "Exact formula in InferProtectionFromDr.")

    AddFormulaSection("Behavior Model (Exact Addon Logic)")
    AddFormulaRow("Prediction Core", "Predicted = max(0, EMA(values, 0.35) + LinearSlope(values))", "Applied to DPS, HPS, and Taken.")
    AddFormulaRow("EMA", "EMA_t = alpha * x_t + (1 - alpha) * EMA_{t-1}", "alpha = 0.35 in this addon.")
    AddFormulaRow("Linear Slope", "Slope = ((n*sum(xy)) - (sumx*sumy)) / ((n*sum(xx)) - (sumx^2))", "Least-squares slope on ordered samples.")
    AddFormulaRow("Mean", "Mean = sum(values) / n", "Arithmetic mean for model aggregates.")
    AddFormulaRow("StdDev", "StdDev = sqrt(sum((x - mean)^2) / (n - 1))", "Sample standard deviation.")
    AddFormulaRow("Volatility", "VolatilityPct = (StdDev(DPS) / max(Mean(DPS), epsilon)) * 100", "High volatility indicates bursty output.")
    AddFormulaRow("Pressure Profile", "High if PredTaken > 0.8*PredDps; Low if PredTaken < 0.25*PredDps; else Balanced", "Exact branch logic used in model panel.")
    AddFormulaRow("Rhythm Profile", "Bursty if Volatility > 35; else Stable", "Exact branch logic used in model panel.")

    AddFormulaSection("UESP Build Editor Formulas (Special:EsoBuildEditor)")
    AddFormulaRow("Source Modules", "ext.EsoBuildData.editor.scripts + ext.EsoBuildData.viewer.scripts", "Formulas below are extracted from UESP Build Editor runtime code.")

    AddFormulaSection("UESP Core Conversions")
    AddFormulaRow("Flat Crit -> Percent", "CritPct = round1(FlatCrit / (2 * EffectiveLevel * (100 + EffectiveLevel)) * 100)", "From ConvertEsoFlatCritToPercent().")
    AddFormulaRow("Percent Crit -> Flat", "FlatCrit = round(CritPct * 2 * EffectiveLevel * (100 + EffectiveLevel))", "From ConvertEsoPercentCritToFlat().")
    AddFormulaRow("Flat Resist -> Percent", "ResistPct = round(max(0, (clamp(FlatResist, 0, 33000) - 100) / (EffectiveLevel * 10)))", "From ConvertEsoFlatResistToPercent().")
    AddFormulaRow("Element Resist -> Percent", "ElementResistPct = round(max(0, clamp(FlatResist, 0, 33000) / (EffectiveLevel * 10)))", "From ConvertEsoElementResistToPercent().")
    AddFormulaRow("Crit Resist -> Percent", "CritResistPct = round(FlatCritResist / EffectiveLevel)", "From ConvertEsoCritResistToPercent().")

    AddFormulaSection("UESP Damage, Crit, and Mitigation Pipeline")
    AddFormulaRow("Base Damage Pipeline", "Damage = floor((floor(Base * SkillDamageMod * AllDamageMod) + ExtraDamage) * CritFactor * Mitigation)", "Order used by EsoBuildCombatApplyDamage().")
    AddFormulaRow("Critical Factor", "CritFactor = (1 + CritDamageBonus) when random <= CritRate, else 1", "Crit roll and multiplier in EsoBuildCombatApplyDamage().")
    AddFormulaRow("Crit Resist Reduction", "CritDamageBonus = max(0, CritDamageBonus - round2(CritResist * (0.035 / 250)))", "From EsoBuildCombatGetCritDataForSkill().")
    AddFormulaRow("Target Mitigation", "Mitigation = ResistDamageTaken * (1 + TargetDamageTaken)", "From EsoBuildCombatGetTargetMitigation().")
    AddFormulaRow("Resist Damage Taken", "ResistDamageTaken = 1 - clamp(Resist, 0, ESO_RESIST_CAP) / 66000", "From resistDamageTaken calculation.")
    AddFormulaRow("Oblivion Exception", "If DamageType == Oblivion then ResistDamageTaken = 1", "Oblivion bypasses resistance in UESP combat simulation.")

    AddFormulaSection("UESP Skill/Set Runtime Equations")
    AddFormulaRow("Venomous Claw Tick", "TickDamage = floor(BaseTick * (1 + floor(TickCount / 2) * StepPct / 100))", "From Venomous Claw getDotTickDamage().")
    AddFormulaRow("Hurricane Tick", "TickDamage = floor(BaseTick * (1 + TickCount * MaxPct / 100 / TickInterval * Duration))", "From Hurricane getDotTickDamage().")
    AddFormulaRow("Eviscerate Execute", "DamageMod = 1 + ((100 - CurrentHealthPct) / 100) * ExecutePct / 100", "From Eviscerate getDamageMod().")
    AddFormulaRow("Onslaught Ignored Resist", "IgnoredResist = floor(CurrentResist * IgnorePct / 100)", "Stored for follow-up penetration effect.")
    AddFormulaRow("Onslaught Follow-up Pen", "FlatResistMod = -IgnoredResist (direct, non-DOT only while active)", "From Onslaught getFlatResistMod().")
    AddFormulaRow("Knight Slayer", "BonusDamage = min(floor(TargetMaxHealth * HealthPct / 100), MaxOblivionDamage)", "From Knight Slayer onHeavyAttack().")
    AddFormulaRow("Sload's Semblance", "ProcDamage = min(floor(TargetMaxHealth * HealthPct / 100), MaxOblivionDamage)", "From Sload's Semblance onAnyDamage().")
    AddFormulaRow("Roaring Opportunist Duration", "Duration = clamp(HeavyAttackDamage / DamagePerSecond, MinDuration, MaxDuration)", "From Roaring Opportunist onHeavyAttack().")
    AddFormulaRow("Balorgh (2x variant)", "WeaponSpellDamageBonus = 2 * UltimateConsumed", "From Balorgh set rule variant 1.")
    AddFormulaRow("Balorgh (hybrid variant)", "WeaponSpellDamageBonus = UltimateConsumed; PenBonus = PenMultiplier * UltimateConsumed", "From Balorgh set rule variant 2.")

    AddFormulaSection("UESP Dynamic Set Tooltip Formulas")
    AddFormulaRow("Three-Piece Scaling", "CurrentWeaponSpellDamage = BaseDamage * ThreeSetCount; CurrentArmor = BaseArmor * ThreeSetCount", "From UpdateEsoBuildSetOther().")
    AddFormulaRow("Bahsei Current Value", "CurrentPct = Set.BahseiMania * 100", "From UESP tooltip recompute for Bahsei.")
    AddFormulaRow("Coral Riptide Current Value", "CurrentWeaponSpellDamage = Set.CoralRiptide", "From UESP tooltip recompute for Coral Riptide.")
    AddFormulaRow("Mora's Whispers Crit", "CurrentCrit = round(Set.MorasWhispers)", "From UESP tooltip recompute for Mora's Whispers.")
    AddFormulaRow("Mora's Whispers XP/Skill", "CurrentInspirationPct = round(Set.MorasWhispers / MaxCrit * MaxInspirationPct)", "From UESP tooltip recompute for Mora's Whispers.")
    AddFormulaRow("Mora's Whispers Kill XP", "CurrentMonsterKillPct = round(Set.MorasWhispers / MaxCrit * MaxMonsterKillPct)", "From UESP tooltip recompute for Mora's Whispers.")
    AddFormulaRow("Pearlescent Ward Damage", "CurrentWeaponSpellDamage = round(Set.PearlescentWard / 12 * MaxDamage)", "From UESP tooltip recompute for Pearlescent Ward.")
    AddFormulaRow("Pearlescent Ward Reduction", "CurrentReductionPct = round(Set.PearlescentWard / 12 * MaxReductionPct)", "From UESP tooltip recompute for Pearlescent Ward.")
    AddFormulaRow("Mark of the Pariah", "CurrentResistValue = round(Set.MarkPariah)", "From UESP tooltip recompute for Mark of the Pariah.")

    AddFormulaSection("UESP Proc Template Equations")
    AddFormulaRow("Proc Chance Gate", "Trigger if random <= ChancePct/100 and cooldown is ready", "Core condition used by many UESP set/skill procs.")
    AddFormulaRow("DOT From Total", "PerTick = TotalDamage / DurationSeconds", "Used repeatedly when constructing periodic effects.")
    AddFormulaRow("Generic Bonus Window", "Apply bonus for DurationSeconds, then expire when CurrentTime >= EndTime", "Shared toggle/buff timing behavior in UESP combat engine.")

    AddFormulaSection("Live Player Stat Comparison")
    local roleKey, roleProfile, roleSource = GetSelectedRoleComparisonProfile()

    ctx:AddStat(
        string.format("Comparison Profile: %s", roleProfile.label),
        string.format(
            "%s Using GetPlayerStat-derived max stats. Health %s-%s | Primary %s-%s | Secondary %s-%s | Crit %.0f%%-%.0f%%.",
            roleSource,
            NumberText(roleProfile.health[1]),
            NumberText(roleProfile.health[2]),
            NumberText(roleProfile.primary[1]),
            NumberText(roleProfile.primary[2]),
            NumberText(roleProfile.secondary[1]),
            NumberText(roleProfile.secondary[2]),
            roleProfile.crit[1],
            roleProfile.crit[2]
        )
    )
    ctx:AddStat(
        "Role Detection",
        string.format("Detected profile key: %s", roleKey)
    )

    local function FirstPositiveNumber(...)
        local count = select("#", ...)
        for i = count, 1, -1 do
            local value = tonumber(select(i, ...))
            if value and value > 0 then
                return value
            end
        end
        return nil
    end

    local function SafeGetDerivedPlayerStat(statType)
        if type(GetPlayerStat) ~= "function" or type(statType) ~= "number" then
            return nil
        end

        local applyBonus = type(STAT_BONUS_OPTION_APPLY_BONUS) == "number" and STAT_BONUS_OPTION_APPLY_BONUS or nil
        local applySoftCap = type(STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP) == "number" and STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP or nil

        local a, b, c, d = GetPlayerStat(statType, applyBonus, applySoftCap)
        local derivedValue = FirstPositiveNumber(a, b, c, d)
        if derivedValue then
            return derivedValue
        end

        a, b, c, d = GetPlayerStat(statType)
        return FirstPositiveNumber(a, b, c, d)
    end

    local function SafeGetCurrentPower(powerType)
        if type(powerType) ~= "table" then
            return nil
        end

        return SafeGetCurrentPowerFromList(powerType)
    end

    local function CompareRange(value, low, high)
        if value > high then
            return "TOO HIGH"
        end
        if value < low then
            return "LOW"
        end
        return "OK"
    end

    local function AddComparisonRow(label, value, low, high, note)
        local status = CompareRange(value, low, high)
        ctx:AddStat(
            string.format("%s: %s [%s]", label, NumberText(value), status),
            string.format("Target range: %s-%s | %s", NumberText(low), NumberText(high), note)
        )
    end
    
    local hpMax = SafeGetDerivedPlayerStat(STAT_HEALTH_MAX)
    local magMax = SafeGetDerivedPlayerStat(STAT_MAGICKA_MAX)
    local stamMax = SafeGetDerivedPlayerStat(STAT_STAMINA_MAX)
    
    local rpt = GetResourcePowerTypes()
    local hpCurrent = SafeGetCurrentPower(rpt.health)
    local magCurrent = SafeGetCurrentPower(rpt.magicka)
    local stamCurrent = SafeGetCurrentPower(rpt.stamina)

    if hpMax and magMax and stamMax then
        local primaryType = magMax >= stamMax and "Magicka" or "Stamina"
        local primaryMax = math.max(magMax, stamMax)
        local secondaryMax = math.min(magMax, stamMax)

        AddComparisonRow(
            "Max Health",
            hpMax,
            roleProfile.health[1],
            roleProfile.health[2],
            roleProfile.healthNote
        )
        AddComparisonRow(
            string.format("Primary Resource (%s)", primaryType),
            primaryMax,
            roleProfile.primary[1],
            roleProfile.primary[2],
            roleProfile.primaryNote
        )
        AddComparisonRow(
            "Secondary Resource",
            secondaryMax,
            roleProfile.secondary[1],
            roleProfile.secondary[2],
            roleProfile.secondaryNote
        )

        local resourceSummary = snapshot.resourceSummary or {}
        local hpStats = resourceSummary.health
        local magStats = resourceSummary.magicka
        local stamStats = resourceSummary.stamina
        local hasFightResourceSamples = (hpStats and hpStats.hasData)
            or (magStats and magStats.hasData)
            or (stamStats and stamStats.hasData)

        if hasFightResourceSamples then
            local sampleCount = resourceSummary.sampleCount or 0

            local function AddResourceAvgMedianRow(label, stats, maxValue)
                if not stats or not stats.hasData or not maxValue or maxValue <= 0 then
                    ctx:AddStat(
                        string.format("%s Fight Avg/Median: n/a", label),
                        "No fight-duration resource samples available for this stat."
                    )
                    return
                end

                local avgValue = maxValue * (stats.averagePct / 100)
                local medianValue = maxValue * (stats.medianPct / 100)
                ctx:AddStat(
                    string.format(
                        "%s Fight Avg/Median: %s/%s (%.0f%%/%.0f%%)",
                        label,
                        NumberText(avgValue),
                        NumberText(medianValue),
                        stats.averagePct,
                        stats.medianPct
                    ),
                    string.format(
                        "Sampled every %.1fs while in combat (%d samples across this fight).",
                        RESOURCE_SAMPLE_INTERVAL_MS / 1000,
                        sampleCount
                    )
                )
            end

            AddResourceAvgMedianRow("HP", hpStats, hpMax)
            AddResourceAvgMedianRow("MAG", magStats, magMax)
            AddResourceAvgMedianRow("STAM", stamStats, stamMax)
        else
            hpCurrent = hpCurrent or hpMax
            magCurrent = magCurrent or magMax
            stamCurrent = stamCurrent or stamMax

            local hpPct = (hpCurrent / hpMax) * 100
            local magPct = (magCurrent / magMax) * 100
            local stamPct = (stamCurrent / stamMax) * 100
            ctx:AddStat(
                string.format("Current Resource State: HP %.0f%% | MAG %.0f%% | STAM %.0f%%", hpPct, magPct, stamPct),
                "Fallback snapshot when fight-duration resource samples are not available yet."
            )
        end
    else
        ctx:AddStat(
            "Player Power Stats Unavailable",
            "Could not read GetPlayerStat-derived max pools in this context; comparison rows skipped."
        )
    end

    local critStatus = CompareRange(snapshot.critPct or 0, roleProfile.crit[1], roleProfile.crit[2])
    ctx:AddStat(
        string.format("Combat Crit Rate: %.1f%% [%s]", snapshot.critPct or 0, critStatus),
        string.format(
            "%s target range: %.0f%%-%.0f%%. %s",
            roleProfile.label,
            roleProfile.crit[1],
            roleProfile.crit[2],
            roleProfile.critNote
        )
    )

    local incomingDps = 0
    if snapshot.duration and snapshot.duration > 0 then
        incomingDps = (snapshot.totalTaken or 0) / snapshot.duration
    end
    ctx:AddStat(
        string.format("Incoming DPS Pressure: %s", ShortNumber(incomingDps)),
        "Use with health/resist checks: if pressure is low and survivability stats are high, those stats may be overbuilt."
    )

    AddFormulaSection("Diminishing Returns + Stop Points")

    local behaviorSummary = ctx:GetBehavior()
    local liveRes = Clamp(behaviorSummary.predictedResistance or 0, 0, RESISTANCE_CAP)
    local liveDr = Clamp((liveRes / RESISTANCE_SCALE) * 100, 0, 50)

    local statStep = 1000
    local nextRes = Clamp(liveRes + statStep, 0, RESISTANCE_CAP)
    local nextDr = Clamp((nextRes / RESISTANCE_SCALE) * 100, 0, 50)
    local drGainPct = math.max(0, nextDr - liveDr)

    local ehpNow = 1
    local ehpNext = 1
    if liveDr < 99.9 then
        ehpNow = 1 / (1 - (liveDr / 100))
    end
    if nextDr < 99.9 then
        ehpNext = 1 / (1 - (nextDr / 100))
    end
    local ehpGainPct = ((ehpNext / math.max(ehpNow, 0.0001)) - 1) * 100

    local penDrDropPct = (math.min(statStep, liveRes) / RESISTANCE_SCALE) * 100
    local afterPenRes = math.max(0, liveRes - statStep)
    local dmgMultNow = 1 - (liveRes / RESISTANCE_SCALE)
    local dmgMultAfterPen = 1 - (afterPenRes / RESISTANCE_SCALE)
    local penRelativeGainPct = 0
    if dmgMultNow > 0 then
        penRelativeGainPct = ((dmgMultAfterPen / dmgMultNow) - 1) * 100
    end

    AddFormulaRow(
        "Resistance DR Value (+1,000 Resist)",
        string.format("Live @%s res: +1000 -> +%.2f%% DR, +%.2f%% EHP", NumberText(liveRes), drGainPct, ehpGainPct),
        "DR gain is linear, but effective health gain accelerates as DR rises; practical stop near 30k-33k resist."
    )
    AddFormulaRow(
        "Penetration Value (+1,000 Pen)",
        string.format("Live @%s target res: -%.2f%% DR, +%.2f%% dmg mult", NumberText(liveRes), penDrDropPct, penRelativeGainPct),
        "Best stop: when total effective pen reaches target resist (about 18,200 PvE boss baseline; up to 33,000 PvP targets)."
    )
    AddFormulaRow(
        "Crit Chance DR Value",
        "DeltaDamagePer1PctCrit = CritDamageBonusPct / 100",
        "No hard DR curve; practical stop is when buffed crit chance is already high and another stat gives better DPS gain."
    )
    AddFormulaRow(
        "Crit Chance Practical Stop",
        string.format("TargetRange: %.0f%%-%.0f%% buffed for %s setups", roleProfile.crit[1], roleProfile.crit[2], roleProfile.label),
        roleProfile.critNote
    )
    AddFormulaRow(
        "Crit Damage DR Value",
        "DeltaDamagePer1PctCritDamage = CritChancePct / 100",
        "Hard stop at total crit damage cap (125%)."
    )
    AddFormulaRow(
        "Crit Damage Practical Stop",
        "Stop when TotalCritDamageBonus >= 125%",
        "After cap, invest in crit chance, penetration, raw damage, or sustain."
    )
    AddFormulaRow(
        "Weapon/Spell Damage DR Value",
        "PowerScaleApprox: 1 WSD approx 10.5 MaxResource",
        "No true DR; stop adding WSD when sustain or survivability costs outweigh equivalent DPS gain."
    )
    AddFormulaRow(
        "Max Resource DR Value",
        "PowerScaleApprox: +10.5 MaxResource approx +1 WSD",
        "No hard DR; stop when resource stacking gives less damage per slot than WSD or crit stats."
    )
    AddFormulaRow(
        "Recovery DR Value",
        "EffectiveSurplus = RecoveryIncome - RotationCost",
        "Stop when sustained surplus is consistently positive and deaths/rotational pressure come from damage, not sustain."
    )
    AddFormulaRow(
        "Healing Done DR Value",
        "HealedOutput = EffectiveHeal / CastTime",
        "No hard cap, but practical stop is when overheal is consistently high and mitigation/damage provides better team value."
    )
    AddFormulaRow(
        "Health DR Value",
        "EHP = Health / (1 - DR)",
        "Stop adding health when one-shot survivability is met and extra points reduce pressure output too much."
    )
    AddFormulaRow(
        "Summary Rule",
        "Stop adding a stat when marginal gain from +1 unit is lower than the best alternative stat",
        "Use marginal gain comparison per slot/trait/set bonus, not just raw character sheet values."
    )

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderOptions(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Options Panel",
        tooltip = "Settings, control buttons, and command reference",
    })

    ctx:AddButton(self.saved.dialogAutoHide and "Dialog Auto Hide: ON" or "Dialog Auto Hide: OFF", "Toggle automatic dialog close when out of combat", function()
        self:SetDialogAutoHide(not self.saved.dialogAutoHide)
    end)

    ctx:AddButton(self.saved.autoClearOnNextFight and "Auto Clear: ON" or "Auto Clear: OFF", "Toggle auto clear when next combat starts", function()
        self.saved.autoClearOnNextFight = not self.saved.autoClearOnNextFight
    end)

    ctx:AddButton("Clear Fight Data", "Clear current and historical fight data", function()
        self:ResetFightData(false)
    end)

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Options Explained",
        tooltip = "Descriptions of all available commands and toggles",
    })

    local optionHelpLines = {
        "Previous/Next Fight: Navigate stored fight history.",
        "View Live Fight: Return to current active combat data.",
        "Formula Panel: ESO stat equations and addon formulas.",
        "Build Snapshot Panel: Current bars, gear, and boon-style snapshot.",
        "Resource Panel Delay/Ping: Tracks latency averages, dips, spikes, and high-delay samples.",
        "Print Build Debug: Dumps build-panel data to chat for API verification.",
        "Save Fight Panel: Type a custom save name before persisting.",
        "Saved Fights Panel: Persist fights across sessions.",
        "Load Saved Fight By Name: Type a saved label and load that one fight.",
        "Dialog Auto Hide: Auto closes the dialog after combat.",
        "Auto Clear: Switch back to the live fight view when a new fight starts.",
        "Clear Fight Data: Wipes current fight and full history.",
        "Print Debug Snapshot: Dumps only current-fight data to chat.",
        "Slash /cm savefight [name]: Save viewed fight to saved slots.",
        "Slash /cm loadfight <name>: Load one saved fight by name.",
        "Slash /cm loadfightexact <name>: Load one saved fight by exact name only.",
        "Slash /cm loadsaves: Load all saved fights into history.",
        "Slash /cm dumpcpslottables: Dump confirmed Champion slottable IDs.",
        "Slash /cm linkbuild: Pre-fill chat input with a compact build summary.",
    }
    for i = 1, #optionHelpLines do
        ctx:AddStat(optionHelpLines[i], "Option explanation")
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderShare(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local isLive = ctx.isLive

    local viewLabel = isLive and "Live" or string.format("Fight %d", self.viewFightIndex or 0)

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Share Panel (%s)", viewLabel),
        tooltip = "Pre-fill the chat virtual keyboard with stats or your build. Choose a channel and confirm to send.",
    })

    ctx:AddButton(
        "Share Front Bar Links to Chat",
        "Pre-fills chat with clickable ability links for every skill on your front bar.",
        function()
            self:ShareFrontBarLinksToChat()
        end
    )

    ctx:AddButton(
        "Share Back Bar Links to Chat",
        "Pre-fills chat with clickable ability links for every skill on your back bar.",
        function()
            self:ShareBackBarLinksToChat()
        end
    )

    ctx:AddButton(
        "Share Armor Links to Chat",
        "Pre-fills chat with clickable item links for your 7 armor pieces. Recipients can hover for full tooltips.",
        function()
            self:ShareArmorLinksToChat()
        end
    )

    ctx:AddButton(
        "Share Jewelry Links to Chat",
        "Pre-fills chat with clickable item links for neck and both rings.",
        function()
            self:ShareJewelryLinksToChat()
        end
    )

    ctx:AddButton(
        "Share Weapon Links to Chat",
        "Pre-fills chat with clickable item links for your front and back weapon slots.",
        function()
            self:ShareWeaponLinksToChat()
        end
    )

    ctx:AddSection("Stats")

    ctx:AddButton(
        "Share Fight Stats to Chat",
        string.format("Pre-fills chat with: duration, DPS, HPS, damage, healing, taken, crit rate for %s.", viewLabel),
        function()
            self:ShareFightToChat(viewLabel)
        end
    )

    ctx:AddButton(
        "Share Top Skills to Chat",
        "Pre-fills chat with your top 5 damage skills as ability links with totals.",
        function()
            self:ShareTopSkillsToChat()
        end
    )

    ctx:AddButton(
        "Share Sustain / Resources to Chat",
        "Pre-fills chat with average HP, Magicka, and Stamina percentages.",
        function()
            self:ShareResourceToChat()
        end
    )

    ctx:AddButton(
        "Share Build Summary to Chat",
        "Sends a text summary line (CP, sets, boon, bars) and prints linked bars to your chat log.",
        function()
            self:ShareBuildToChat()
        end
    )

    ctx:AddButton(
        "Share Full Snapshot to Chat",
        "Combines fight stats and build summary into one pre-filled message.",
        function()
            self:ShareFullSnapshotToChat()
        end
    )

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "How It Works",
        tooltip = "On Xbox the virtual keyboard opens pre-filled with the text. Choose a channel (Say, Party, Zone, etc.) and press Confirm to post it.",
    })
    ctx:AddStat(
        "1. Press a Share button above",
        "The virtual keyboard will open with the text already filled in."
    )
    ctx:AddStat(
        "2. Choose your chat channel",
        "Press LB/RB to switch channels in the chat input box."
    )
    ctx:AddStat(
        "3. Press Confirm / A to send",
        "Your stats or build will be posted to chat."
    )

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderSaves(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local isLive = ctx.isLive

    local saves = self:GetSavedFights()
    local maxSaves = tonumber(self.saved.maxSavedFights) or self.defaults.maxSavedFights
    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = string.format("Saved Fights (%d/%d)", #saves, maxSaves),
        tooltip = "Fights saved here persist across sessions. Load a slot to browse it in history.",
    })

    ctx:AddButton(
        string.format("Open Save Fight Panel (%s)", isLive and "Live" or string.format("Fight %d", self.viewFightIndex)),
        "Open the separate naming panel before persisting this fight.",
        function()
            if TrimText(self.saved.saveFightDraftName or "") == "" then
                self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #saves + 1)
            end
            self.dialogPanel = "save"
        end
    )

    dialog:AddSetting({
        type = LibHarvensAddonSettings.ST_EDIT,
        label = "Load Saved Fight Name",
        tooltip = "Type the saved fight label to load that fight directly into history.",
        getFunction = function()
            return self.saved.loadFightDraftName or ""
        end,
        setFunction = function(value)
            self.saved.loadFightDraftName = TrimText(value)
        end,
        maxChars = 120,
    })

    ctx:AddButton(
        "Load Saved Fight By Name",
        "Load one saved fight by typed name (exact match, then partial match fallback).",
        function()
            local ok, msg = self:LoadSavedFightIntoHistoryByName(self.saved.loadFightDraftName or "")
            self:Print(msg)
            if ok then
                self.dialogPanel = "main"
            end
        end
    )

    if #saves == 0 then
        ctx:AddStat("No saved fights yet. View a fight and press Save above.", "Save fights to access them across sessions and reloads.")
    else
        for i = 1, #saves do
            local entry = saves[i]
            if entry and entry.snapshot then
                local snap = entry.snapshot
                local topTarget = snap.targetList and snap.targetList[1]
                local targetDesc = topTarget and (" vs " .. (topTarget.name or "?")) or ""
                ctx:AddStat(
                    string.format("%s%s  |  %s dmg / %s heal / %s taken",
                        entry.label or string.format("Slot %d", i),
                        targetDesc,
                        ShortNumber(snap.totalDamage or 0),
                        ShortNumber(snap.totalHeal or 0),
                        ShortNumber(snap.totalTaken or 0)
                    ),
                    string.format("Duration: %.1fs | Crit: %.1f%% | Peak DPS: %s",
                        snap.duration or 0, snap.critPct or 0, ShortNumber(snap.peakDps or 0))
                )
                local slotIndex = i
                ctx:AddButton(
                    string.format("Load Slot %d Into History", slotIndex),
                    string.format("Add saved slot %d to fight history so you can browse it with Prev/Next.", slotIndex),
                    function()
                        local ok, msg = self:LoadSavedFightIntoHistory(slotIndex)
                        self:Print(msg)
                        self.dialogPanel = "main"
                    end
                )
                ctx:AddButton(
                    string.format("Delete Slot %d", slotIndex),
                    string.format("Permanently delete saved slot %d.", slotIndex),
                    function()
                        local ok, msg = self:DeleteSavedFight(slotIndex)
                        self:Print(msg)
                    end
                )
            end
        end
    end

    if #saves > 0 then
        ctx:AddButton("Clear All Saves", "Delete all saved fight slots permanently.", function()
            self:ClearSavedFights()
            self:Print("All saved fights cleared.")
        end)
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

local function RenderLibFights(ctx)
    local self = ctx.self
    local bridge = self.LibFightsBridge
    local rows = self:BuildLibFightsRows()
    for i = 1, #rows do
        local row = rows[i]
        if row.section then
            ctx:AddSection(row.section, row.tooltip)
        elseif row.value ~= nil and row.value ~= "" then
            ctx:AddStat(string.format("%s: %s", row.label, row.value), row.tooltip)
        else
            ctx:AddStat(row.label, row.tooltip)
        end
    end

    if bridge.IsAvailable() then
        ctx:AddSection("LibFights Controls", "Logging and fight browsing")
        if bridge.IsLogging() then
            ctx:AddButton("Stop LibFights Logging", "Stop_Logging(): end the current fight and unregister LibFights events", function()
                self:StopLibFightsLogging()
            end)
        else
            ctx:AddButton("Start LibFights Logging", "Start_Logging(): LibFights records nothing until this is called", function()
                local ok, reason = self:StartLibFightsLogging()
                if not ok then
                    self:Print("LibFights: " .. tostring(reason))
                end
            end)
        end
        ctx:AddButton("Previous LibFights Fight", "Show the LibFights fight before this one", function()
            self:StepLibFightsView(-1)
        end)
        ctx:AddButton("Next LibFights Fight", "Show the next LibFights fight (towards the live one)", function()
            self:StepLibFightsView(1)
        end)
        ctx:AddButton("Print LibFights Report", "Print the full LibFights report for this fight to chat", function()
            self:PrintLibFightsLines("all")
        end)
    end

    ctx:AddBackButton()
    ctx:AddCloseButton()
end

---------------------------------------------------------------------------
-- Panel dispatch
---------------------------------------------------------------------------
local PANEL_RENDERERS = {
    libfights = RenderLibFights,
    main = RenderMain,
    overview = RenderOverview,
    save = RenderSave,
    resources = RenderResources,
    mitigation = RenderMitigation,
    build = RenderBuild,
    resistance = RenderResistance,
    buffs = RenderBuffs,
    skills = RenderSkills,
    behavior = RenderBehavior,
    formulas = RenderFormulas,
    options = RenderOptions,
    share = RenderShare,
    saves = RenderSaves,
}

function ConsoleMetrics:PopulateFightViewDialog(dialog)
    local snapshot, isLive = self:GetViewedFightSnapshot()
    local renderer = PANEL_RENDERERS[self.dialogPanel or "main"]
    if not renderer then
        self.dialogPanel = "main"
        renderer = RenderMain
    end

    dialog:Clear()
    renderer(NewRenderContext(self, dialog, snapshot, isLive))
end

---------------------------------------------------------------------------
-- Open / close / refresh (both platforms)
---------------------------------------------------------------------------
-- The console dialog needs both libraries; PC falls back to the native window.
local function UseConsoleDialog()
    return ConsoleMetrics.IsGamepadUI() and LibConsoleDialogs ~= nil and LibHarvensAddonSettings ~= nil
end

function ConsoleMetrics:OpenFightViewDialog(forceLive)
    if not UseConsoleDialog() then
        if type(IsConsoleUI) == "function" and IsConsoleUI() then
            self:Print("LibConsoleDialogs and LibHarvensAddonSettings are required for /cm view on console. Install/enable them in this game folder.")
            return
        end
        self:OpenPCDialog(forceLive)
        return
    end

    if forceLive then
        self.viewFightIndex = 0
        self.dialogPanel = "main"
    elseif not self.dialogPanel then
        self.dialogPanel = "main"
    end

    if not self.ui.fightViewDialog then
        self.ui.fightViewDialog = LibConsoleDialogs:Create("Console Metrics")
    end

    self:PopulateFightViewDialog(self.ui.fightViewDialog)
    self.ui.fightViewDialog:Show()
    self:ArmDialogAutoHide()
    self.dialogRefreshAtMs = 0
    self.lastDialogRefreshKey = nil
    self.wasFightViewDialogShowing = true
end

function ConsoleMetrics:IsFightViewDialogShowing()
    if self:IsFightViewDialogShowingPC() then
        return true
    end

    local dialog = self.ui.fightViewDialog
    return dialog ~= nil
        and dialog.selected == true
        and LibHarvensAddonSettings ~= nil
        and LibHarvensAddonSettings.scene ~= nil
        and LibHarvensAddonSettings.scene:IsShowing()
end

-- True while the user is typing into a dialog edit box (refreshes would steal focus).
function ConsoleMetrics:IsFightViewDialogEditing()
    return self:IsPCDialogEditing()
end

-- True while the player is actively using the PC window (cursor over it,
-- typing, or interacted recently). Auto-hide waits while this is true.
function ConsoleMetrics:IsFightViewDialogInUse()
    return self:IsPCDialogInUse()
end

-- True during a click / scrollbar drag / just after one, when a rebuild
-- would swallow the click.
function ConsoleMetrics:IsFightViewDialogBusy()
    return self:IsPCDialogBusy()
end

-- Re-renders whichever dialog is currently open.
function ConsoleMetrics:RefreshFightViewDialog()
    if self:IsFightViewDialogShowingPC() then
        self:RefreshPCDialog()
    elseif self.ui.fightViewDialog then
        self:PopulateFightViewDialog(self.ui.fightViewDialog)
    end
end

function ConsoleMetrics:ArmDialogAutoHide()
    if not self.saved or not self.saved.dialogAutoHide then
        self.dialogAutoHideAtMs = nil
        return
    end

    local seconds = tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds
    seconds = Clamp(seconds, 3, 120)
    self.dialogAutoHideAtMs = GetFrameTimeMilliseconds() + (seconds * 1000)
end

function ConsoleMetrics:CloseFightViewDialog(silent, reason)
    -- The PC window remembers its panel so reopening continues where the
    -- player was; the console dialog always restarts at Main.
    if not self:IsFightViewDialogShowingPC() then
        self.dialogPanel = "main"
    end
    self.dialogAutoHideAtMs = nil
    self.dialogRefreshAtMs = nil
    self.lastDialogRefreshKey = nil
    self.isClosingFightViewDialog = true

    if self:IsFightViewDialogShowingPC() then
        self:ClosePCDialog()
    end

    local dialog = self.ui.fightViewDialog
    if dialog then
        -- Clear selection state first so OnUpdate won't treat this as an active panel.
        dialog.selected = false
        if dialog.Hide then
            dialog:Hide()
        end
        if LibHarvensAddonSettings and LibHarvensAddonSettings.scene and LibHarvensAddonSettings.scene.Hide then
            LibHarvensAddonSettings.scene:Hide()
        end
        if LibConsoleDialogs and type(LibConsoleDialogs.Close) == "function" then
            LibConsoleDialogs:Close()
        end
        -- Force a fresh instance next open to avoid stale scene/selection state.
        self.ui.fightViewDialog = nil
    end

    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false

    if not silent then
        self:Print(string.format("Fight data dialog closed (%s)", reason or "manual"))
    end
end
