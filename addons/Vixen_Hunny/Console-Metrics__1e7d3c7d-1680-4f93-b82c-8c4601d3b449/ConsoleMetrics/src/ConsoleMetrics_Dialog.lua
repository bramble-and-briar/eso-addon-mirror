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

-- Row types for panel rows (same values as LibHarvensAddonSettings, which the
-- gamepad viewer no longer needs; see ConsoleMetrics_GamepadScreen.lua).
local ST = {
    ST_CHECKBOX = 1, ST_SLIDER = 2, ST_EDIT = 3, ST_DROPDOWN = 4, ST_COLOR = 5,
    ST_BUTTON = 6, ST_LABEL = 7, ST_SECTION = 8, ST_ICONPICKER = 9,
}


---------------------------------------------------------------------------
-- Look and feel
---------------------------------------------------------------------------
-- The console dialog is a LibHarvensAddonSettings page (one gamepad list).
-- Styling rules used by every panel:
--   * the gamepad header shows the panel name plus Viewing / DPS / HPS / Time,
--   * read-only stats are label rows (no "Select" prompt), values in white,
--     details in the left tooltip panel,
--   * actions are buttons whose keybind text says what they do ("Open", ...),
--   * Back (B) goes to Main / closes, so pages carry no Back / Close rows,
--   * Previous / Next / Live fight sit on the keybind strip when available.
local VALUE_HEX = "FFFFFF"
local MUTED_HEX = "9A9A9A"

local PANEL_TITLES = {
    main = "Console Metrics",
    overview = "Overview",
    save = "Save Fight",
    resources = "Resources",
    mitigation = "Mitigation & Healing",
    build = "Build",
    resistance = "Resistance",
    buffs = "Buffs & Sets",
    skills = "Abilities",
    behavior = "Behavior Model",
    formulas = "Formulas",
    options = "Options",
    share = "Share to Chat",
    saves = "Saved Fights",
    libfights = "LibFights",
}

local function EscapePattern(text)
    return (tostring(text or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- "Label: value" -> label in the row color, value in white. Text that already
-- carries color markup is left alone.
local function StyleStatText(text)
    text = tostring(text or "")
    if string.find(text, "|c", 1, true) then
        return text
    end
    local label, value = string.match(text, "^([^:]+):%s+(.+)$")
    if label and #label <= 40 then
        return string.format("%s  |c%s%s|r", label, VALUE_HEX, value)
    end
    return text
end

-- Section titles: drop the "... Panel (Live)" noise; the header shows both.
local function CleanSectionLabel(label, viewingText)
    label = tostring(label or "")
    if viewingText and viewingText ~= "" then
        label = label:gsub("%s*%(" .. EscapePattern(viewingText) .. "%)%s*$", "")
    end
    label = label:gsub("%s+Panel%s*%(.-%)%s*$", "")
    label = label:gsub("%s+Panel%s*$", "")
    return label
end

-- Applied to every row a panel adds (including rows added straight through
-- dialog:AddSetting), so all panels share one style.
local function StyleSetting(params, viewingText)
    local types = ST
    if params.type == types.ST_SECTION then
        params.label = CleanSectionLabel(params.label, viewingText)
    elseif params.type == types.ST_BUTTON and type(params.label) == "string" and not params.buttonText then
        local inner = params.label:match("^Open (.+) Panel$") or params.label:match("^Open (.+)$")
        if inner then
            params.label = inner
            params.buttonText = "Open"
        end
    end
    return params
end

local function Muted(text)
    return string.format("|c%s%s|r", MUTED_HEX, tostring(text or ""))
end

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
        type = ST.ST_SECTION,
        label = label,
        tooltip = tooltip,
    })
end

-- Read-only row. Always selectable so the list can scroll through it; the
-- tooltip (if any) shows in the left panel.
function RenderContext:AddStat(text, tooltip)
    if tooltip == text then
        tooltip = nil
    end
    self.dialog:AddSetting({
        type = ST.ST_LABEL,
        label = StyleStatText(text),
        tooltip = tooltip,
        canSelect = true,
    })
end

-- A row with a dimmed note (empty states, hints).
function RenderContext:AddNote(text, tooltip)
    self.dialog:AddSetting({
        type = ST.ST_LABEL,
        label = Muted(text),
        tooltip = tooltip,
        canSelect = true,
    })
end

-- keepSelection: stay on the same row (same panel); otherwise go to the top.
function RenderContext:Refresh(keepSelection)
    if self.closed then
        return
    end
    local addon = self.self
    addon:NoteConsoleDialogInteraction()
    -- Rebuild the rows in place. Calling Show() again would re-select the
    -- dialog, reset the cursor and push the dialog onto its own back stack.
    if not addon:RebuildConsoleDialog(keepSelection) then
        addon:PopulateFightViewDialog(self.dialog)
        self.dialog:Show()
        addon:RefreshConsoleDialogHeader()
    end
    addon:ArmDialogAutoHide()
end

-- keyText: what the A / Cross keybind says for this row (default "Select").
function RenderContext:AddButton(label, tooltip, action, disable, keyText)
    local ctx = self
    self.dialog:AddSetting({
        type = ST.ST_BUTTON,
        label = label,
        tooltip = tooltip,
        buttonText = keyText,
        clickHandler = function()
            local addon = ctx.self
            local panelBefore = addon.dialogPanel
            addon:NoteConsoleDialogInteraction()
            action()
            if not ctx.closed then
                ctx:Refresh(addon.dialogPanel == panelBefore)
            end
        end,
        disable = disable,
    })
end

-- Panel link on the hub.
function RenderContext:AddPanelLink(label, panel, tooltip)
    local addon = self.self
    self:AddButton(label, tooltip, function()
        addon.dialogPanel = panel
    end, nil, "Open")
end

-- Real gamepad checkbox bound to a saved option.
function RenderContext:AddToggle(label, tooltip, getter, setter)
    local ctx = self
    self.dialog:AddSetting({
        type = ST.ST_CHECKBOX,
        label = label,
        tooltip = tooltip,
        getFunction = getter,
        setFunction = function(value)
            ctx.self:NoteConsoleDialogInteraction()
            setter(value)
        end,
        default = getter(),
    })
end

-- Real gamepad slider bound to a saved option.
function RenderContext:AddSlider(label, tooltip, minValue, maxValue, step, getter, setter, unit, disable)
    local ctx = self
    self.dialog:AddSetting({
        type = ST.ST_SLIDER,
        label = label,
        tooltip = tooltip,
        min = minValue,
        max = maxValue,
        step = step or 1,
        unit = unit,
        format = "%d",
        getFunction = getter,
        setFunction = function(value)
            ctx.self:NoteConsoleDialogInteraction()
            setter(value)
        end,
        default = getter(),
        disable = disable,
    })
end

-- B already goes back to Main (and closes from Main), so pages no longer
-- add Back / Close rows. Kept as no-ops for the panel renderers.
function RenderContext:AddBackButton()
end

function RenderContext:AddCloseButton()
end

---------------------------------------------------------------------------
-- Shared row builders
---------------------------------------------------------------------------
local function FormatMs(ms)
    return string.format("%.1fs", (ms or 0) / 1000)
end

-- Fight history navigation. When the keybind strip carries Previous / Next /
-- Live (see RegisterConsoleFightKeybinds) the rows are not needed.
local function AddFightNavButtons(ctx, force)
    local addon = ctx.self
    if addon.consoleFightKeybindsRegistered and not force then
        return
    end
    local function NoHistory()
        return #(addon.fightHistory or {}) == 0
    end
    ctx:AddSection("Fight History")
    ctx:AddButton("Previous Fight", "Step back one fight in history", function()
        addon:StepFightView(-1)
    end, NoHistory, "Previous")
    ctx:AddButton("Next Fight", "Step forward one fight in history", function()
        addon:StepFightView(1)
    end, NoHistory, "Next")
    ctx:AddButton("Live Fight", "Return to the current live fight", function()
        addon.viewFightIndex = 0
    end, function() return (addon.viewFightIndex or 0) == 0 end, "View")
end

-- Rows of the form "N) name [id:X] - value (crit%)" for a per-ability stat list.
local function AddStatRows(ctx, list, limit, valueKey, colorHex, tooltipFn, emptyText, emptyTooltip)
    if not list or #list == 0 then
        ctx:AddNote(emptyText, emptyTooltip)
        return
    end

    for i = 1, math.min(limit, #list) do
        local entry = list[i]
        local hits = entry.hits or 0
        local critPct = hits > 0 and (((entry.crits or 0) / hits) * 100) or 0
        local details = tooltipFn(entry)
        local idLine = string.format("Ability ID: %d", entry.abilityId or 0)
        ctx:AddStat(
            string.format("%d.  %s   %s  %s", i, entry.name or "Unknown", ColorShort(entry[valueKey] or 0, colorHex), Muted(string.format("%.0f%% crit", critPct))),
            details and (details .. "\n" .. idLine) or idLine
        )
    end
end

local function AddMomentRows(ctx, list, emptyText, emptyTooltip)
    if not list or #list == 0 then
        ctx:AddNote(emptyText, emptyTooltip)
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
    local snapshot = ctx.snapshot
    local duration = snapshot.duration or 0
    local topDamage = (snapshot.skillList or {})[1]
    local topHeal = (snapshot.healSkillList or {})[1]

    ctx:AddSection("Fight Summary")
    ctx:AddStat(
        string.format("Damage  %s  %s", ColorText(ShortNumber(snapshot.dps or 0) .. " DPS", COMBAT_COLOR_HEX.damage),
            Muted(NumberText(snapshot.totalDamage or 0) .. " total")),
        topDamage and string.format("Top ability: %s\n%s damage, %d hits\nPeak DPS: %s",
            topDamage.name or "?", NumberText(topDamage.damage or 0), topDamage.hits or 0, ShortNumber(snapshot.peakDps or 0))
            or "No damage recorded yet")
    ctx:AddStat(
        string.format("Healing  %s  %s", ColorText(ShortNumber(snapshot.hps or 0) .. " HPS", COMBAT_COLOR_HEX.heal),
            Muted(NumberText(snapshot.totalHeal or 0) .. " total")),
        topHeal and string.format("Top ability: %s\n%s healing\nPeak HPS: %s",
            topHeal.name or "?", NumberText(topHeal.heal or 0), ShortNumber(snapshot.peakHps or 0))
            or "No healing recorded yet")
    ctx:AddStat(
        string.format("Taken  %s  %s", ColorText(NumberText(snapshot.totalTaken or 0), COMBAT_COLOR_HEX.taken),
            Muted(string.format("%s blocked / %s shielded",
                ShortNumber(snapshot.totalIncomingBlockedDamage or 0), ShortNumber(snapshot.totalIncomingShieldedDamage or 0)))),
        string.format("Incoming damage\nOverflow: %s\nBlocked: %s\nShielded: %s",
            NumberText(snapshot.totalIncomingOverflowDamage or 0),
            NumberText(snapshot.totalIncomingBlockedDamage or 0),
            NumberText(snapshot.totalIncomingShieldedDamage or 0)))
    ctx:AddStat(string.format("Critical: %.1f%%   Duration: %.1fs", snapshot.critPct or 0, duration),
        string.format("Hit range: %s - %s", NumberText(snapshot.minHitValue or 0), NumberText(snapshot.maxHitValue or 0)))
    ctx:AddStat(string.format("FPS: %s", self:GetRuntimeFpsText()), "Client framerate this session (average / minimum / 1% low)")

    ctx:AddSection("Combat Metrics Report")
    ctx:AddPanelLink("Full Fight Report", "cmx_hub",
        "Combat Metrics style report from LibFights: damage and healing done / received by unit and ability, buffs, resources by source, stats, graph, combat log, casts, deaths, posting to chat and the fight list")

    ctx:AddSection("Fight Breakdown")
    ctx:AddPanelLink("Overview", "overview", "Totals, peaks and burst windows")
    ctx:AddPanelLink("Abilities", "skills", "Damage and healing by ability")
    ctx:AddPanelLink("Buffs & Sets", "buffs", "Major / Minor uptimes and set procs")
    ctx:AddPanelLink("Mitigation & Healing", "mitigation", "Blocked and shielded damage, top moments")
    ctx:AddPanelLink("Resistance", "resistance", "Resistance, damage reduction and protections")
    ctx:AddPanelLink("Resources", "resources", "Health / Magicka / Stamina, sustain and ping")

    ctx:AddSection("Character")
    ctx:AddPanelLink("Build", "build", "Bars, gear, sets, mundus and champion points")
    ctx:AddPanelLink("Behavior Model", "behavior", "Predictions and confidence across your fights")
    if self.LibFightsBridge and self.LibFightsBridge.IsAvailable() then
        ctx:AddPanelLink("LibFights", "libfights", "Fight metrics and predictions from LibFights")
    end
    ctx:AddPanelLink("Formulas", "formulas", "ESO stat math reference")

    ctx:AddSection(string.format("Saved Fights  (%d)", #self:GetSavedFights()))
    ctx:AddButton("Save This Fight", "Name this fight and keep it across sessions", function()
        if TrimText(self.saved.saveFightDraftName or "") == "" then
            self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #self:GetSavedFights() + 1)
        end
        self.dialogPanel = "save"
    end, nil, "Save")
    ctx:AddPanelLink("Saved Fights", "saves", string.format("Load or delete saved fights (%d saved)", #self:GetSavedFights()))

    AddFightNavButtons(ctx)

    ctx:AddSection("Tools")
    ctx:AddPanelLink("Share to Chat", "share", "Send fight stats or your build to chat")
    ctx:AddPanelLink("Options", "options", "Toggles, clear data and command help")
end

local function RenderOverview(ctx)
    local dialog = ctx.dialog
    local snapshot = ctx.snapshot
    local viewingText = ctx.viewingText

    dialog:AddSetting({
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
        label = string.format("Save Fight Panel (%s)", viewingText),
        tooltip = "Give the current viewed fight a custom name, then persist it across sessions.",
    })

    dialog:AddSetting({
        type = ST.ST_EDIT,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
            type = ST.ST_SECTION,
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
    local saved = self.saved

    ctx:AddSection("Dialog")
    ctx:AddToggle("Auto Hide After Combat", "Close this dialog a few seconds after combat ends (waits while you are using it)",
        function() return saved.dialogAutoHide == true end,
        function(value) self:SetDialogAutoHide(value) end)
    ctx:AddSlider("Auto Hide Delay", "Seconds without input before the dialog closes", 3, 120, 1,
        function() return tonumber(saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds end,
        function(value) saved.dialogAutoHideSeconds = math.max(3, math.min(120, math.floor(value + 0.5))) end,
        "s",
        function() return not saved.dialogAutoHide end)
    ctx:AddToggle("Jump To Live On New Fight", "Switch back to the live view when a new fight starts",
        function() return saved.autoClearOnNextFight == true end,
        function(value) saved.autoClearOnNextFight = value end)

    ctx:AddSection("Data")
    ctx:AddButton("Clear Fight Data", "Clear the current fight and all fight history (saved fights are kept)", function()
        self:ResetFightData(false)
        self:Print("Fight data cleared.")
    end, nil, "Clear")

    ctx:AddSection("Help")
    local helpRows = {
        { "Back (B / Circle)", "On a page: return to Main. On Main: close the dialog." },
        { "Previous / Next / Live", "Step through stored fights, or return to the live fight." },
        { "Save This Fight", "Name the viewed fight and keep it across sessions." },
        { "Saved Fights", "Load a saved fight into history, or delete it." },
        { "Resources", "Health / Magicka / Stamina averages, regen and drain, ping dips and spikes." },
        { "/cm savefight [name]", "Save the viewed fight from chat." },
        { "/cm loadfight <name>", "Load one saved fight by name." },
        { "/cm loadsaves", "Load all saved fights into history." },
        { "/cm linkbuild", "Pre-fill chat with a compact build summary." },
        { "/cm help", "Print every chat command." },
    }
    for i = 1, #helpRows do
        ctx:AddStat(helpRows[i][1], helpRows[i][2])
    end
end

local function RenderShare(ctx)
    local self = ctx.self
    local dialog = ctx.dialog
    local isLive = ctx.isLive

    local viewLabel = isLive and "Live" or string.format("Fight %d", self.viewFightIndex or 0)

    dialog:AddSetting({
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_SECTION,
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
        type = ST.ST_EDIT,
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
    local ctx = NewRenderContext(self, dialog, snapshot, isLive)

    -- Gamepad header: panel name + what is being viewed and its key numbers.
    local duration = snapshot.duration or 0
    dialog.headerData = {
        titleText = PANEL_TITLES[self.dialogPanel or "main"] or "Console Metrics",
        data1HeaderText = "Viewing",
        data1Text = ctx.viewingText .. ((isLive and self.inCombat) and "  (in combat)" or ""),
        data2HeaderText = "DPS",
        data2Text = ShortNumber(snapshot.dps or 0),
        data3HeaderText = "HPS",
        data3Text = ShortNumber(snapshot.hps or 0),
        data4HeaderText = "Time",
        data4Text = string.format("%d:%02d", math.floor(duration / 60), math.floor(duration % 60)),
    }

    -- Every row goes through the shared style (section titles, "Open" keys).
    local addSetting = dialog.AddSetting
    dialog.AddSetting = function(d, params)
        return addSetting(d, StyleSetting(params, ctx.viewingText))
    end
    dialog.AddSetting = nil   -- the Back / Close rows skip the page styling

    -- Back row at the top of every page (Close on Main) and again at the
    -- bottom, so long pages can be left from either end.
    local addon = self
    local backLabel = self:GetConsoleBackLabel()
    local function AddNavRow()
        if backLabel then
            dialog:AddSetting({
                type = ST.ST_BUTTON,
                label = "< " .. backLabel,
                tooltip = "Go back one page (same as the Back button)",
                buttonText = "Back",
                clickHandler = function()
                    if not addon:ConsoleGoBack() then
                        addon:CloseFightViewDialog(true, "back")
                    end
                end,
            })
            -- Deeper pages also get a direct way home.
            if backLabel ~= "Back to Main Menu" and (addon.dialogPanel or "main") ~= "main" then
                dialog:AddSetting({
                    type = ST.ST_BUTTON,
                    label = "<< Main Menu",
                    tooltip = "Go straight to the Main Menu (same as the Main Menu keybind)",
                    buttonText = "Main Menu",
                    clickHandler = function()
                        if addon.ConsoleGoMain and addon:ConsoleGoMain() then
                            return
                        end
                        addon.dialogPanel = "main"
                    end,
                })
            end
        else
            dialog:AddSetting({
                type = ST.ST_BUTTON,
                label = "Close",
                tooltip = "Close Console Metrics",
                buttonText = "Close",
                clickHandler = function()
                    addon:CloseFightViewDialog(true, "button")
                end,
            })
        end
    end

    if backLabel then
        AddNavRow()
    end
    dialog.AddSetting = function(d, params)
        return addSetting(d, StyleSetting(params, ctx.viewingText))
    end
    local ok, err = pcall(renderer, ctx)
    dialog.AddSetting = nil   -- fall back to the class method again
    if not ok then
        dialog:AddSetting({ type = ST.ST_LABEL, label = "This page failed to build.", tooltip = tostring(err), canSelect = true })
        self:DebugPrint("Console dialog render error: " .. tostring(err))
    end
    AddNavRow()
    -- A page may describe a different fight (the Combat Metrics pages use the
    -- LibFights fight); it then supplies its own header values.
    if type(ctx.header) == "table" then
        for key, value in pairs(ctx.header) do
            dialog.headerData[key] = value
        end
    end
end

-- Lets other files add console pages (see ConsoleMetrics_DialogCMX.lua).
ConsoleMetrics.ConsolePanels = PANEL_RENDERERS
ConsoleMetrics.ConsolePanelTitles = PANEL_TITLES
ConsoleMetrics.ConsoleDialogHelpers = {
    Muted = Muted,
    StyleStatText = StyleStatText,
}

-- Combat Metrics style pages browse LibFights fights instead of the
-- ConsoleMetrics history.
function ConsoleMetrics:IsCmxPanel()
    return type(self.dialogPanel) == "string" and string.sub(self.dialogPanel, 1, 4) == "cmx_"
end

-- Pushes dialog.headerData into the gamepad header.
function ConsoleMetrics:RefreshConsoleDialogHeader()
    local dialog = self.ui.fightViewDialog
    local lhas = LibHarvensAddonSettings
    if not dialog or not dialog.headerData or not lhas or not lhas.scrollList or not lhas.scrollList.header then
        return
    end
    if type(ZO_GamepadGenericHeader_RefreshData) == "function" then
        pcall(ZO_GamepadGenericHeader_RefreshData, lhas.scrollList.header, dialog.headerData)
    end
end

-- Previous / Next / Live on the keybind strip of the settings scene. Only
-- visible while this dialog is the page on screen.
function ConsoleMetrics:RegisterConsoleFightKeybinds()
    if self.consoleFightKeybindsRegistered then
        return
    end
    local lhas = LibHarvensAddonSettings
    if not (LibConsoleDialogs and type(LibConsoleDialogs.RegisterKeybind) == "function" and lhas and lhas.scene) then
        return
    end
    local addon = self
    local function OurPage()
        local dialog = addon.ui.fightViewDialog
        return dialog ~= nil and dialog.selected == true
    end
    local function HasHistory()
        if addon:IsCmxPanel() then
            local _, _, count = addon:GetLibFightsViewedFight()
            return (count or 0) > 1 or addon.cmxFightOverride ~= nil
        end
        return #(addon.fightHistory or {}) > 0
    end
    local function IsViewingLive()
        if addon:IsCmxPanel() then
            return addon.cmxFightOverride == nil and (addon.libFightsViewOffset or 0) == 0
        end
        return (addon.viewFightIndex or 0) == 0
    end
    -- step -1 = older fight, +1 = newer fight
    local function StepFight(step)
        if addon:IsCmxPanel() then
            addon.cmxFightOverride = nil
            addon.cmxLogPage = 1
            addon:StepLibFightsView(step)
        else
            addon:StepFightView(step)
        end
    end
    local function GoLive()
        if addon:IsCmxPanel() then
            addon.cmxFightOverride = nil
            addon.cmxLogPage = 1
            addon.libFightsViewOffset = 0
            addon.libFightsRev = (addon.libFightsRev or 0) + 1
        else
            addon.viewFightIndex = 0
        end
    end
    local function Step(apply)
        apply()
        addon:NoteConsoleDialogInteraction()
        addon:RebuildConsoleDialog(true)
        if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
            pcall(KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups, KEYBIND_STRIP)
        end
    end
    local ok = pcall(function()
        LibConsoleDialogs:RegisterKeybind(lhas.scene, {
            name = "Previous Fight",
            order = 100,
            visible = OurPage,
            enabled = HasHistory,
            callback = function() Step(function() StepFight(-1) end) end,
        })
        LibConsoleDialogs:RegisterKeybind(lhas.scene, {
            name = "Next Fight",
            order = 101,
            visible = OurPage,
            enabled = HasHistory,
            callback = function() Step(function() StepFight(1) end) end,
        })
        LibConsoleDialogs:RegisterKeybind(lhas.scene, {
            name = "Live",
            order = 102,
            visible = function() return OurPage() and not IsViewingLive() end,
            enabled = function() return true end,
            callback = function() Step(GoLive) end,
        })
    end)
    self.consoleFightKeybindsRegistered = ok
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

    -- Set up the settings scene first so the fight keybinds exist before the
    -- first page is built (pages then skip their Previous/Next rows).
    if LibHarvensAddonSettings and type(LibHarvensAddonSettings.Initialize) == "function" then
        pcall(LibHarvensAddonSettings.Initialize, LibHarvensAddonSettings)
    end
    self:RegisterConsoleFightKeybinds()
    self:HookConsoleBackButton()

    -- Already on screen (opened twice): rebuild in place instead of Show(),
    -- which would stack the dialog on its own back history.
    if not self:RebuildConsoleDialog(false) then
        self:PopulateFightViewDialog(self.ui.fightViewDialog)
        self.ui.fightViewDialog:Show()
        self:RefreshConsoleDialogHeader()
    end
    self:NoteConsoleDialogInteraction()
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
    return self:IsPCDialogInUse() or self:IsConsoleDialogBusy()
end

-- True during a click / scrollbar drag / just after one, when a rebuild
-- would swallow the click.
function ConsoleMetrics:IsFightViewDialogBusy()
    return self:IsPCDialogBusy() or self:IsConsoleDialogBusy()
end

---------------------------------------------------------------------------
-- Console dialog: in-place rebuild and input tracking
---------------------------------------------------------------------------
-- Live refreshes pause for this long after the player moves the cursor or
-- presses a button, so a press always lands on the row it was aimed at.
local CONSOLE_INPUT_HOLD_MS = 2000

local function ConsoleList()
    local lhas = LibHarvensAddonSettings
    return lhas and lhas.list or nil
end

local function IsConsoleDialogOnScreen(dialog)
    local lhas = LibHarvensAddonSettings
    return dialog ~= nil
        and dialog.selected == true
        and lhas ~= nil
        and lhas.scene ~= nil
        and lhas.scene:IsShowing()
end

function ConsoleMetrics:NoteConsoleDialogInteraction()
    self.consoleLastInputMs = GetFrameTimeMilliseconds()
    if self.dialogAutoHideAtMs then
        -- Browsing the dialog restarts the auto-hide countdown.
        self:ArmDialogAutoHide()
    end
end

-- Called from the update loop: a moved cursor counts as input.
function ConsoleMetrics:TrackConsoleDialogInput()
    local dialog = self.ui.fightViewDialog
    if not IsConsoleDialogOnScreen(dialog) then
        self.consoleLastSelectedIndex = nil
        return
    end
    local list = ConsoleList()
    if not list then
        return
    end
    local ok, index = pcall(list.GetSelectedIndex, list)
    if not ok then
        return
    end
    if self.consoleLastSelectedIndex ~= nil and index ~= self.consoleLastSelectedIndex then
        self:NoteConsoleDialogInteraction()
    end
    self.consoleLastSelectedIndex = index
end

function ConsoleMetrics:IsConsoleDialogBusy()
    if not IsConsoleDialogOnScreen(self.ui.fightViewDialog) then
        return false
    end
    return GetFrameTimeMilliseconds() < (self.consoleLastInputMs or 0) + CONSOLE_INPUT_HOLD_MS
end

-- Rebuilds the console dialog's rows while it stays on screen. Returns false
-- (doing nothing visible) when the dialog is not currently shown, so callers
-- can fall back to Show().
function ConsoleMetrics:RebuildConsoleDialog(keepSelection)
    local dialog = self.ui.fightViewDialog
    if not IsConsoleDialogOnScreen(dialog) then
        return false
    end
    local list = ConsoleList()
    local oldIndex = nil
    if keepSelection and list then
        local ok, index = pcall(list.GetSelectedIndex, list)
        oldIndex = ok and index or nil
    end

    self:PopulateFightViewDialog(dialog)
    -- Clear() inside Populate drops the selected flag; the dialog never left
    -- the screen, so restore it (the update loop reads it to detect "Back").
    dialog.selected = true
    dialog:CreateControls()

    if list then
        local target = nil
        local okCount, count = pcall(list.GetNumItems, list)
        if oldIndex and okCount and count and count > 0 then
            target = math.max(1, math.min(oldIndex, count))
        end
        if not target then
            local okFirst, first = pcall(list.CalculateFirstSelectableIndex, list)
            target = okFirst and first or nil
        end
        if target then
            pcall(list.SetSelectedIndexWithoutAnimation, list, target, true, false)
        end
        local ok, index = pcall(list.GetSelectedIndex, list)
        self.consoleLastSelectedIndex = ok and index or nil
    end

    -- The primary keybind label ("Select" / button text) follows the selected row.
    local lhas = LibHarvensAddonSettings
    if KEYBIND_STRIP and lhas.scrollList and lhas.scrollList.keybindStripDescriptor then
        pcall(KEYBIND_STRIP.UpdateKeybindButtonGroup, KEYBIND_STRIP, lhas.scrollList.keybindStripDescriptor)
    end
    self:RefreshConsoleDialogHeader()
    return true
end

-- Re-renders whichever dialog is currently open.
function ConsoleMetrics:RefreshFightViewDialog()
    if self:IsFightViewDialogShowingPC() then
        self:RefreshPCDialog()
    elseif self.ui.fightViewDialog then
        if not self:RebuildConsoleDialog(true) then
            -- Not on screen: only refresh the data for the next Show().
            self:PopulateFightViewDialog(self.ui.fightViewDialog)
        end
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
        -- Only close the settings screen when this dialog is the page on it
        -- (never another add-on's page), and not when it already closed itself.
        local onScreen = IsConsoleDialogOnScreen(dialog)
        -- Clear selection state first so OnUpdate won't treat this as an active panel.
        dialog.selected = false
        -- Drop any copies of this dialog from LibConsoleDialogs' back stack so
        -- "Back" in another dialog never reopens this one.
        local stack = LibConsoleDialogs and LibConsoleDialogs.dialogCallStack
        if type(stack) == "table" then
            for i = #stack, 1, -1 do
                if stack[i] == dialog then
                    table.remove(stack, i)
                end
            end
        end
        if onScreen and reason ~= "cancel" and SCENE_MANAGER then
            local scene = LibHarvensAddonSettings.scene
            if SCENE_MANAGER:GetCurrentScene() == scene then
                SCENE_MANAGER:HideCurrentScene()
            else
                pcall(SCENE_MANAGER.Hide, SCENE_MANAGER, scene:GetName())
            end
        end
        -- The dialog object is kept and reused: creating a new one on every
        -- open registered another library callback each time.
    end

    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false

    if not silent then
        self:Print(string.format("Fight data dialog closed (%s)", reason or "manual"))
    end
end

---------------------------------------------------------------------------
-- Console dialog: Back navigation
---------------------------------------------------------------------------
-- Back (the B / Circle button and the Back rows) moves one page up inside
-- the dialog without hiding the settings screen. Hiding and re-showing the
-- screen is what used to scramble the view.
local PARENT_PANEL = {
    save = "main",
    saves = "main",
}

function ConsoleMetrics:GetConsoleParentPanel(panel)
    panel = panel or self.dialogPanel or "main"
    if panel == "main" then
        return nil
    end
    if PARENT_PANEL[panel] then
        return PARENT_PANEL[panel]
    end
    if string.sub(panel, 1, 4) == "cmx_" and panel ~= "cmx_hub" then
        return "cmx_hub"
    end
    return "main"
end

local PANEL_BACK_LABEL = {
    main = "Back to Main",
    cmx_hub = "Back to Fight Report",
}

function ConsoleMetrics:GetConsoleBackLabel()
    local parent = self:GetConsoleParentPanel()
    return parent and (PANEL_BACK_LABEL[parent] or "Back") or nil
end

function ConsoleMetrics:IsConsoleDialogOnScreen()
    return IsConsoleDialogOnScreen(self.ui.fightViewDialog)
end

-- One step back. On Main this closes the dialog. Returns true when handled.
function ConsoleMetrics:ConsoleGoBack()
    if not self:IsConsoleDialogOnScreen() then
        return false
    end
    local parent = self:GetConsoleParentPanel()
    if not parent then
        self:CloseFightViewDialog(true, "back")
        return true
    end
    self.dialogPanel = parent
    self:NoteConsoleDialogInteraction()
    if not self:RebuildConsoleDialog(false) then
        self:PopulateFightViewDialog(self.ui.fightViewDialog)
        self.ui.fightViewDialog:Show()
    end
    self.lastDialogRefreshKey = nil
    return true
end

-- The settings screen's Back keybind calls LibHarvensAddonSettings:GoBack()
-- (wrapped by LibConsoleDialogs). While this dialog is on screen, Back is
-- handled here; otherwise the original behaviour runs unchanged.
function ConsoleMetrics:HookConsoleBackButton()
    if self.consoleBackHooked or not LibHarvensAddonSettings then
        return
    end
    local lhas = LibHarvensAddonSettings
    local original = lhas.GoBack
    if type(original) ~= "function" then
        return
    end
    local addon = self
    lhas.GoBack = function(lib, ...)
        if addon:IsConsoleDialogOnScreen() then
            local ok, handled = pcall(addon.ConsoleGoBack, addon)
            if ok and handled then
                return
            end
        end
        return original(lib, ...)
    end
    self.consoleBackHooked = true
end
