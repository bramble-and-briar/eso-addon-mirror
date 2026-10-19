function ConsoleMetrics:PopulateFightViewDialog(dialog)
    local snapshot, isLive = self:GetViewedFightSnapshot()
    local behavior = nil
    local dialogWasClosed = false
    local panel = self.dialogPanel or "main"
    dialog:Clear()

    local function GetBehavior()
        if not behavior then
            behavior = self:GetBehaviorModel(isLive and snapshot or nil)
        end
        return behavior
    end

    local function AddScrollableStatLine(text, tooltip)
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_BUTTON,
            label = text,
            tooltip = tooltip or text,
            clickHandler = function()
            end,
        })
    end

    local function RefreshDialog()
        if dialogWasClosed then
            return
        end
        self:PopulateFightViewDialog(dialog)
        dialog:Show()
        self:ArmDialogAutoHide()
    end

    local function AddActionButton(label, tooltip, action, disable)
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_BUTTON,
            label = label,
            tooltip = tooltip,
            clickHandler = function()
                action()
                if dialogWasClosed then
                    return
                end
                RefreshDialog()
            end,
            disable = disable,
        })
    end

    local function AddBackButton()
        AddActionButton(
            "Back",
            "Return to the main panel",
            function()
                self.dialogPanel = "main"
            end
        )
    end

    local function AddCloseButton()
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_BUTTON,
            label = "Close",
            tooltip = "Close fight data dialog",
            clickHandler = function()
                dialogWasClosed = true
                self:CloseFightViewDialog(false, "button")
            end,
        })
    end

    local function AddFightNavButtons()
        AddActionButton("Previous Fight", "Cycle to previous fight in history", function()
            self:StepFightView(-1)
        end, function()
            return #self.fightHistory == 0
        end)
        AddActionButton("Next Fight", "Cycle to next fight in history", function()
            self:StepFightView(1)
        end, function()
            return #self.fightHistory == 0
        end)
        AddActionButton("View Live Fight", "Return to current live fight view", function()
            self.viewFightIndex = 0
        end)
    end

    local function AddMomentSection(label, moments, maxCount, emptyText, emptyTooltip)
        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = label })
        if not moments or #moments == 0 then
            AddScrollableStatLine(emptyText, emptyTooltip)
            return
        end
        for i = 1, math.min(maxCount, #moments) do
            local moment = moments[i]
            AddScrollableStatLine(string.format("%d) %s", i, moment.label), moment.tooltip)
        end
    end

    local function AddHealingAndMitigationMoments(snapshot, mitigationEmptyTooltip)
        AddMomentSection("Top Healing Moments (30)", snapshot.topHealingMoments, 30,
            "No healing moments yet.", "No healing events in this fight")
        AddMomentSection("Top Mitigation Moments (30)", snapshot.topMitigationMoments, 30,
            "No mitigation moments yet.", mitigationEmptyTooltip)
    end

    local function FormatMs(ms)
        return string.format("%.1fs", (ms or 0) / 1000)
    end

    local function GetFpsText()
        local getFramerate = type(_G) == "table" and _G.GetFramerate or nil
        local currentText = "n/a"
        if type(getFramerate) == "function" then
            local fps = tonumber(getFramerate())
            if fps then
                currentText = string.format("%.1f", fps)
            end
        end

        local stats = self.fpsRuntime
        if type(stats) ~= "table" or (stats.fpsSamples or 0) <= 0 then
            return string.format("%s (avg n/a / min n/a / 1%% low n/a)", currentText)
        end

        -- Shared 1% low helper (same bins/samples shape as trace state).
        local avg = (stats.fpsTotal or 0) / math.max(stats.fpsSamples, 1)
        local minFps = stats.fpsMin
        local low1 = self:GetTraceOnePercentLow(stats)
        local low1Text = type(low1) == "number" and string.format("%.1f", low1) or "n/a"
        if type(minFps) ~= "number" then
            return string.format("%s (avg %.1f / min n/a / 1%% low %s)", currentText, avg, low1Text)
        end

        return string.format("%s (avg %.1f / min %.1f / 1%% low %s)", currentText, avg, minFps, low1Text)
    end

    local viewingText = isLive and "Live" or string.format("Fight %d/%d", self.viewFightIndex, #self.fightHistory)
    if not isLive and type(snapshot.savedLabel) == "string" and snapshot.savedLabel ~= "" then
        viewingText = snapshot.savedLabel
    end

    if panel == "main" then
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = string.format("Console Metrics Main (%s)", viewingText),
            tooltip = "Choose a panel for detailed breakdowns",
        })

        AddScrollableStatLine(string.format("Duration: %.1fs", snapshot.duration), "Current viewed fight duration")
        AddScrollableStatLine(string.format("FPS: %s", GetFpsText()), "Current client framerate. Low FPS can indicate UI/combat load.")
        AddScrollableStatLine(string.format("DPS: %s", ShortNumber(snapshot.dps)), "Current viewed fight DPS")
        AddScrollableStatLine(string.format("HPS: %s", ShortNumber(snapshot.hps)), "Current viewed fight HPS")
        local behaviorSummary = GetBehavior()
        AddScrollableStatLine(string.format("Predicted Resistance: %s", NumberText(behaviorSummary.predictedResistance or 0)), "ML-lite resistance estimate")
        AddScrollableStatLine(string.format("All Effects Tracked: %d", #(snapshot.allEffectList or {})), "Unique effects seen in combat state changes")
        AddScrollableStatLine(string.format("Major/Minor Effects Tracked: %d", #(snapshot.majorMinorList or {})), "Unique Major and Minor effects seen this fight")
        AddScrollableStatLine(string.format("Popular Sets Tracked: %d", #(snapshot.setProcList or {})), "Unique popular PvE/PvP sets seen this fight")
        AddActionButton("Open Build Snapshot Panel", "Current front/back bars, equipped loadout, and boon snapshot", function()
            self.dialogPanel = "build"
        end)
        AddActionButton("Open Save Fight Panel", "Name the current fight and save it into a persistent slot", function()
            if TrimText(self.saved.saveFightDraftName or "") == "" then
                self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #self.saved.savedFights + 1)
            end
            self.dialogPanel = "save"
        end)
        AddActionButton("Open Saved Fights Panel", string.format("Save and load fights across sessions (%d saved)", #self.saved.savedFights), function()
            self.dialogPanel = "saves"
        end)
        AddFightNavButtons()

        AddActionButton("Open Overview Panel", "General fight totals and timeline controls", function()
            self.dialogPanel = "overview"
        end)
        AddActionButton("Open Resource Panel", "Fight resource averages, medians, and sustain profile", function()
            self.dialogPanel = "resources"
        end)
        AddActionButton("Open Mitigation/Healing Panel", "Mitigation totals and top moments", function()
            self.dialogPanel = "mitigation"
        end)
        AddActionButton("Open Resistance/DR Panel", "Resistance, DR, and inferred protections", function()
            self.dialogPanel = "resistance"
        end)
        AddActionButton("Open Buff Uptime Panel", "All Major/Minor uptimes plus popular PvE/PvP set procs", function()
            self.dialogPanel = "buffs"
        end)
        AddActionButton("Open Skills Panel", "Top damage and healing moments", function()
            self.dialogPanel = "skills"
        end)
        AddActionButton("Open ML Model Panel", "Prediction model outputs and confidence", function()
            self.dialogPanel = "behavior"
        end)
        AddActionButton("Open Formula Panel", "ESO stat math reference and addon equations", function()
            self.dialogPanel = "formulas"
        end)
        AddActionButton("Open Options Panel", "Toggles, clear, and help explanations", function()
            self.dialogPanel = "options"
        end)
        AddActionButton("Open Share Panel", "Send fight stats or build to chat", function()
            self.dialogPanel = "share"
        end)

        AddCloseButton()
        return
    end

    if panel == "overview" then
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
            string.format("Duration: %.1fs", snapshot.duration),
            string.format("DPS: %s", ShortNumber(snapshot.dps)),
            string.format("HPS: %s", ShortNumber(snapshot.hps)),
            string.format("Damage Done: %s", NumberText(snapshot.totalDamage)),
            string.format("Healing Done: %s", NumberText(snapshot.totalHeal)),
            string.format("Damage Taken: %s", NumberText(snapshot.totalTaken)),
            string.format("Crit Rate: %.1f%%", snapshot.critPct),
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
            AddScrollableStatLine(overviewLines[i], "Overview statistic")
        end

        AddFightNavButtons()

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "save" then
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

        AddScrollableStatLine(string.format("Preview Duration: %.1fs", snapshot.duration or 0), "Current viewed fight duration.")
        AddScrollableStatLine(string.format("Preview DPS/HPS: %s / %s", ShortNumber(snapshot.dps or 0), ShortNumber(snapshot.hps or 0)), "Current viewed fight throughput preview.")
        AddScrollableStatLine(string.format("Preview Totals: %s dmg / %s heal / %s taken", ShortNumber(snapshot.totalDamage or 0), ShortNumber(snapshot.totalHeal or 0), ShortNumber(snapshot.totalTaken or 0)), "What will be stored into the saved slot.")

        AddActionButton("Use Auto Name", "Generate the default slot label from this fight's summary.", function()
            self.saved.saveFightDraftName = BuildDefaultFightSaveName(snapshot, #self.saved.savedFights + 1)
        end)
        AddActionButton("Clear Draft Name", "Clear the custom fight name and fall back to auto-name on save.", function()
            self.saved.saveFightDraftName = ""
        end)
        AddActionButton("Save Viewed Fight", "Persist this fight using the current draft name or auto-name if blank.", function()
            local ok, msg = self:SaveViewedFight()
            self:Print(msg)
            if ok then
                self.dialogPanel = "saves"
            end
        end)

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "resources" then
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

        AddScrollableStatLine(
            string.format("Samples: %d", sampleCount),
            string.format("Resource samples are recorded every %.1fs during combat.", RESOURCE_SAMPLE_INTERVAL_MS / 1000)
        )

        local rpt = GetResourcePowerTypes()
        local hpMax = SafeGetMaxPowerFromList(rpt.health) or 0
        local magMax = SafeGetMaxPowerFromList(rpt.magicka) or 0
        local stamMax = SafeGetMaxPowerFromList(rpt.stamina) or 0

        local function AddResourceSustainLine(label, stats, maxValue, colorHex)
            if not stats.hasData then
                AddScrollableStatLine(
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
                AddScrollableStatLine(
                    string.format("%s Avg/Median: %s/%s (%s/%s)", label, NumberText(avgValue), NumberText(medValue), avgPctText, medPctText),
                    string.format("Fight sustain trend for %s based on %d total samples.", label, sampleCount)
                )
                return
            end

            AddScrollableStatLine(
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

            AddScrollableStatLine(
                string.format(
                    "Sustain Avg/Median: %s/%s (%s)",
                    ColorText(string.format("%.1f%%", sustainStats.averagePct or 0), sustainHex),
                    ColorText(string.format("%.1f%%", sustainStats.medianPct or 0), sustainHex),
                    ColorText(sustainStats.label or "Stable", sustainHex)
                ),
                "Sustain score uses average Magicka/Stamina fight percentages across sampled combat time."
            )
        else
            AddScrollableStatLine(
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
            AddScrollableStatLine(
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
            AddScrollableStatLine("Health Regen/Drain: n/a", "No health regen/drain data yet.")
        end
        if magR > 0 or magD > 0 then
            AddRegenDrainLine("Magicka", magR, magD, COMBAT_COLOR_HEX.summary, COMBAT_COLOR_HEX.taken)
        else
            AddScrollableStatLine("Magicka Regen/Drain: n/a", "No magicka regen/drain data yet.")
        end
        if stR > 0 or stD > 0 then
            AddRegenDrainLine("Stamina", stR,  stD,  COMBAT_COLOR_HEX.damage,  COMBAT_COLOR_HEX.taken)
        else
            AddScrollableStatLine("Stamina Regen/Drain: n/a", "No stamina regen/drain data yet.")
        end

        local ultGenPs = fightDuration > 0 and (ultG / fightDuration) or 0
        if ultG > 0 or ultD > 0 then
            AddScrollableStatLine(
                string.format("Ultimate Gen/Spend: %s/%s (%s)",
                    ColorText(NumberText(math.floor(ultG)), COMBAT_COLOR_HEX.summary),
                    ColorText(NumberText(math.floor(ultD)), COMBAT_COLOR_HEX.taken),
                    ColorText(string.format("%.2f/s", ultGenPs), COMBAT_COLOR_HEX.summary)
                ),
                string.format("Ultimate: +%s generated | -%s spent over %.1fs (%.2f gen/s).",
                    NumberText(math.floor(ultG)), NumberText(math.floor(ultD)), fightDuration, ultGenPs)
            )
        else
            AddScrollableStatLine("Ultimate Gen/Spend: n/a", "No ultimate generation data yet.")
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

            AddScrollableStatLine(
                string.format("Ping Avg/Median: %s/%s ms",
                    ColorText(PingMsText(pingStats.averageMs), COMBAT_COLOR_HEX.summary),
                    ColorText(PingMsText(pingStats.medianMs), COMBAT_COLOR_HEX.summary)
                ),
                "Average and median ping sampled during this fight."
            )

            AddScrollableStatLine(
                string.format("Ping Min/Max: %s/%s ms",
                    ColorText(PingMsText(pingStats.minMs), COMBAT_COLOR_HEX.heal),
                    ColorText(PingMsText(pingStats.maxMs), COMBAT_COLOR_HEX.taken)
                ),
                "Lowest and highest ping observed in combat samples."
            )

            AddScrollableStatLine(
                string.format("Ping Dips/Spikes: %s/%s",
                    ColorText(NumberText(pingStats.dips or 0), COMBAT_COLOR_HEX.heal),
                    ColorText(NumberText(pingStats.spikes or 0), COMBAT_COLOR_HEX.taken)
                ),
                string.format("Dip: ping dropped by >= %dms between samples. Spike: ping rose by >= %dms.", PING_DIP_DELTA_MS, PING_SPIKE_DELTA_MS)
            )

            AddScrollableStatLine(
                string.format("High Delay Samples: %s/%s (%.1f%% >= %dms)",
                    ColorText(NumberText(highDelay), COMBAT_COLOR_HEX.taken),
                    NumberText(sampleTotal),
                    highDelayPct,
                    pingStats.highDelayThresholdMs or PING_HIGH_DELAY_MS
                ),
                "How often ping exceeded the configured high-delay threshold in this fight."
            )
        else
            AddScrollableStatLine("Ping Avg/Median: n/a", "Latency API unavailable in this context or no ping samples yet.")
        end

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "mitigation" then
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
            AddScrollableStatLine(mitigationLines[i], "Mitigation/healing statistic")
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Skills That Damaged You" })
        if not snapshot.incomingSkillList or #snapshot.incomingSkillList == 0 then
            AddScrollableStatLine("No incoming skill damage yet.", "No enemy damage events recorded against you in this fight")
        else
            for i = 1, math.min(20, #snapshot.incomingSkillList) do
                local skill = snapshot.incomingSkillList[i]
                local skillCritPct = skill.hits > 0 and ((skill.crits / skill.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, skill.name, skill.abilityId or 0, ColorShort(skill.damage, COMBAT_COLOR_HEX.taken), skillCritPct),
                    string.format("Source: %s | Hits: %d | Crits: %d", skill.source or "Unknown", skill.hits or 0, skill.crits or 0)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Set Procs That Damaged You" })
        if not snapshot.incomingSetDamageList or #snapshot.incomingSetDamageList == 0 then
            AddScrollableStatLine("No incoming set proc damage yet.", "No incoming skills matched your tracked popular set catalog")
        else
            for i = 1, math.min(20, #snapshot.incomingSetDamageList) do
                local setProc = snapshot.incomingSetDamageList[i]
                local setCritPct = setProc.hits > 0 and ((setProc.crits / setProc.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) [%s] %s - %s (%.0f%% crit)", i, setProc.scene or "Set", setProc.name, ColorShort(setProc.damage, COMBAT_COLOR_HEX.taken), setCritPct),
                    string.format("Proc ability: %s | Source: %s | Hits: %d", FormatAbilityIdentity(setProc.effectName or setProc.name, setProc.abilityId), setProc.source or "Unknown", setProc.hits or 0)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Likely Set Procs (Heuristic)" })
        if not snapshot.incomingLikelySetProcList or #snapshot.incomingLikelySetProcList == 0 then
            AddScrollableStatLine("No likely set procs detected.", "Heuristic mode found no additional likely set-proc ability names")
        else
            for i = 1, math.min(20, #snapshot.incomingLikelySetProcList) do
                local proc = snapshot.incomingLikelySetProcList[i]
                local procCritPct = proc.hits > 0 and ((proc.crits / proc.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, proc.name, proc.abilityId or 0, ColorShort(proc.damage, COMBAT_COLOR_HEX.summary), procCritPct),
                    string.format("Heuristic score: %.1f | Signals: %s | Source: %s", proc.heuristicScore or 0, proc.heuristicReason or "n/a", proc.source or "Unknown")
                )
            end
        end

        AddHealingAndMitigationMoments(snapshot, "No blocked or shielded moments in this fight")

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "build" then
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
            AddScrollableStatLine(string.format("Max HP: %s", NumberText(math.floor(hpMax))), "Maximum Health")
        end
        if stamMax then
            AddScrollableStatLine(string.format("Max Stamina: %s", NumberText(math.floor(stamMax))), "Maximum Stamina")
        end
        if magMax then
            AddScrollableStatLine(string.format("Max Magicka: %s", NumberText(math.floor(magMax))), "Maximum Magicka")
        end
        if physRes then
            AddScrollableStatLine(string.format("Phys Resist: %s", NumberText(math.floor(physRes))), "Physical Resistance")
        end
        if spellRes then
            AddScrollableStatLine(string.format("Spell Resist: %s", NumberText(math.floor(spellRes))), "Spell Resistance")
        end
        if critRes then
            AddScrollableStatLine(string.format("Crit Resist: %s", NumberText(math.floor(critRes))), "Critical Resistance")
        end
        if weaponDmg then
            AddScrollableStatLine(string.format("Weapon Dmg: %s", NumberText(math.floor(weaponDmg))), "Weapon Damage")
        end
        if spellDmg then
            AddScrollableStatLine(string.format("Spell Dmg: %s", NumberText(math.floor(spellDmg))), "Spell Damage")
        end
        if armorPen then
            AddScrollableStatLine(string.format("Armor Pen: %s", NumberText(math.floor(armorPen))), "Armor Penetration")
        end
        if spellPen then
            AddScrollableStatLine(string.format("Spell Pen: %s", NumberText(math.floor(spellPen))), "Spell Penetration")
        end
        if critChance then
            local critChancePct = SafeFormatCritChance(critChance)
            if critChancePct then
                AddScrollableStatLine(
                    string.format("Crit Chance: %.1f%%", critChancePct),
                    "Critical Strike Chance"
                )
            end
        end
        if critDamage then
            AddScrollableStatLine(string.format("Crit Dmg: %.1f%%", critDamage), "Critical Damage Bonus")
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Equipped Armor" })
        if #equipment == 0 then
            AddScrollableStatLine("No equipment data available.", "Equipment API unavailable in this context.")
        else
            for i = 1, #equipment do
                local item = equipment[i]
                AddScrollableStatLine(
                    string.format("%s: %s", item.label, item.text),
                    string.format("Equipped in %s slot.", item.label)
                )
            end
        end

        if championSnapshot.totalPoints then
            AddScrollableStatLine(
                string.format("Champion Points: %s", NumberText(championSnapshot.totalPoints)),
                "Current earned Champion Point total."
            )
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Front Bar" })
        for i = 1, #frontBar do
            local entry = frontBar[i]
            AddScrollableStatLine(
                string.format("%s: %s", entry.slotLabel, entry.abilityName),
                string.format("Ability ID: %d", entry.abilityId or 0)
            )
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Back Bar" })
        for i = 1, #backBar do
            local entry = backBar[i]
            AddScrollableStatLine(
                string.format("%s: %s", entry.slotLabel, entry.abilityName),
                string.format("Ability ID: %d", entry.abilityId or 0)
            )
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Champion Snapshot" })
        local function AddChampionBucket(label, entries)
            if #entries == 0 then
                AddScrollableStatLine(string.format("%s: unavailable", label), string.format("No %s champion data exposed in this context.", string.lower(label)))
                return
            end

            for i = 1, #entries do
                local entry = entries[i]
                local starText = #entry.stars > 0 and table.concat(entry.stars, ", ") or "No slotted stars detected"
                AddScrollableStatLine(
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
            AddScrollableStatLine("Champion data unavailable.", "Champion discipline APIs did not expose data in this build/context.")
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Equipped Sets" })
        if #equippedSets == 0 then
            AddScrollableStatLine("No equipped set data available.", "Set API unavailable or no set items are equipped.")
        else
            for i = 1, #equippedSets do
                local setInfo = equippedSets[i]
                AddScrollableStatLine(
                    string.format("%s (%d/%d)", setInfo.setName, setInfo.numEquipped or 0, setInfo.maxEquipped or 0),
                    string.format("Equipped on: %s", table.concat(setInfo.slots or {}, ", "))
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Weapon Enchants / Poisons" })
        if #weaponEffects == 0 then
            AddScrollableStatLine("No weapon detail data available.", "Weapon detail API unavailable in this context.")
        else
            for i = 1, #weaponEffects do
                local entry = weaponEffects[i]
                AddScrollableStatLine(
                    string.format("%s: %s", entry.label, entry.itemText),
                    string.format("Enchant: %s | Poison: %s", entry.enchantText, entry.poisonText)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Proc Timers / Ready" })
        if #procTimers == 0 then
            AddScrollableStatLine("No tracked proc timers available.", "Import PvPCooldownTracker rules or equip tracked sets to populate this section.")
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
                AddScrollableStatLine(
                    string.format("%s: %s", entry.label, entry.stateText),
                    string.format("Cooldown: %.1fs | Equipped: %d/%d | Source: %s", (entry.cooldownMs or 0) / 1000, entry.numEquipped or 0, entry.maxEquipped or 0, sourceText)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Boon / Mundus" })
        if #boons == 0 then
            AddScrollableStatLine("No boon-style buff detected.", "If ESO exposes the current boon through buffs here, it will show up in this list.")
        else
            for i = 1, #boons do
                AddScrollableStatLine(boons[i], "Active boon or mundus-style buff detected on the player.")
            end
        end

        AddActionButton("Print Build Debug", "Print the current Build Snapshot panel data to chat.", function()
            self:PrintBuildSnapshotDebug("build-panel")
        end)

        AddActionButton("Link Build in Chat", "Pre-fill chat input with a compact build summary you can send to group/zone.", function()
            self:LinkBuildToChat()
        end)

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "resistance" then
        local behaviorSummary = GetBehavior()
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "Resistance / DR Panel",
            tooltip = "Machine learning inference for target resistance and protections",
        })

        if not snapshot.targetList or #snapshot.targetList == 0 then
            AddScrollableStatLine("No target data yet.", "No resistance samples available")
        else
            for i = 1, math.min(5, #snapshot.targetList) do
                local target = snapshot.targetList[i]
                local drPct = Clamp((target.estimatedResistance / RESISTANCE_SCALE) * 100, 0, 50)
                local label, _, confidence = InferProtectionFromDr(drPct, true)
                AddScrollableStatLine(
                    string.format("%d) %s - %s res (DR %.1f%%)", i, target.name, NumberText(target.estimatedResistance), drPct),
                    "Estimated resistance and inferred DR"
                )
                AddScrollableStatLine(
                    string.format("   %s (confidence %.0f%%)", label, confidence * 100),
                    "Inferred protection state"
                )
            end
        end

        AddScrollableStatLine(string.format("Predicted Resistance: %s", NumberText(behaviorSummary.predictedResistance or 0)), "ML-lite predicted resistance")
        AddScrollableStatLine(string.format("Predicted DR: %.1f%%", behaviorSummary.predictedDrPct or 0), "Predicted DR from resistance model")
        AddScrollableStatLine(string.format("Predicted Protections: %s", behaviorSummary.predictedProtectionLabel or "No mitigation data"), "Protection state inferred from predicted DR")

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "buffs" then
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
        AddScrollableStatLine(string.format("Tracked Time: %s", FormatMs(ps.totalMs)), "Total time with inference samples")
        AddScrollableStatLine(string.format("Any Protection Uptime: %.1f%% (%s)", ps.anyProtectionPct or 0, FormatMs(ps.anyProtectionMs)), "Major/Minor/Combined inferred uptime")
        AddScrollableStatLine(string.format("Any Protection Downtime: %.1f%% (%s)", 100 - (ps.anyProtectionPct or 0), FormatMs((ps.noneMs or 0) + (ps.unknownMs or 0))), "No protection or unknown time")

        AddScrollableStatLine(string.format("Major Uptime: %.1f%% (%s)", ps.majorPct or 0, FormatMs(ps.majorMs)), "Inferred major protection uptime")
        AddScrollableStatLine(string.format("Major Downtime: %.1f%%", 100 - (ps.majorPct or 0)), "Time without inferred major protection")

        AddScrollableStatLine(string.format("Minor Uptime: %.1f%% (%s)", ps.minorPct or 0, FormatMs(ps.minorMs)), "Inferred minor protection uptime")
        AddScrollableStatLine(string.format("Minor Downtime: %.1f%%", 100 - (ps.minorPct or 0)), "Time without inferred minor protection")

        AddScrollableStatLine(string.format("Major+Minor Uptime: %.1f%% (%s)", ps.majorMinorPct or 0, FormatMs(ps.majorMinorMs)), "Inferred simultaneous major+minor protection")
        AddScrollableStatLine(string.format("Unknown Inference Time: %.1f%% (%s)", ps.unknownPct or 0, FormatMs(ps.unknownMs)), "No mitigation signal available")

        -- Full effect list gives a direct answer to "what was active and for how long".
        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "All Effects and Uptime" })
        if #allEffectList == 0 then
            AddScrollableStatLine("No effects tracked yet.", "Effect rows appear when effect gained/faded events are seen")
        else
            for i = 1, math.min(EFFECTS_PANEL_LIMIT, #allEffectList) do
                local effect = allEffectList[i]
                AddScrollableStatLine(
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
                AddScrollableStatLine(
                    string.format("Showing top %d of %d effects", EFFECTS_PANEL_LIMIT, #allEffectList),
                    "Panel limits rows for gamepad readability"
                )
            end
        end

        -- Major/Minor subset is preserved separately for quick combat readability.
        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "All Major/Minor Effects" })
        if #majorMinorList == 0 then
            AddScrollableStatLine("No Major/Minor effects tracked yet.", "Major/Minor uptime appears after matching combat events")
        else
            for i = 1, #majorMinorList do
                local effect = majorMinorList[i]
                AddScrollableStatLine(
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
        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Popular PvE/PvP Set Procs" })
        if #setProcList == 0 then
            AddScrollableStatLine("No popular set procs tracked yet.", "Set coverage appears when abilities match the tracked catalog")
        else
            for i = 1, #setProcList do
                local setInfo = setProcList[i]
                AddScrollableStatLine(
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

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "skills" then
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "Skills Panel (Damage)",
            tooltip = "Top 20 skills by total damage output this fight",
        })

        if #snapshot.skillList == 0 then
            AddScrollableStatLine("No skill data yet.", "No damage skills recorded in this fight")
        else
            for i = 1, math.min(20, #snapshot.skillList) do
                local skill = snapshot.skillList[i]
                local skillCritPct = skill.hits > 0 and ((skill.crits / skill.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, skill.name, skill.abilityId or 0, ColorShort(skill.damage, COMBAT_COLOR_HEX.damage), skillCritPct),
                    string.format("Ability: %s | Hits: %d | Crits: %d", FormatAbilityIdentity(skill.name, skill.abilityId), skill.hits or 0, skill.crits or 0)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Skills (Overall Healing)" })
        if not snapshot.healSkillList or #snapshot.healSkillList == 0 then
            AddScrollableStatLine("No healing skill data yet.", "No healing skills recorded in this fight")
        else
            for i = 1, math.min(20, #snapshot.healSkillList) do
                local skill = snapshot.healSkillList[i]
                local skillCritPct = skill.hits > 0 and ((skill.crits / skill.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, skill.name, skill.abilityId or 0, ColorShort(skill.heal, COMBAT_COLOR_HEX.heal), skillCritPct),
                    string.format("Ability: %s | Hits: %d | Crits: %d | Damage dealt: %s", FormatAbilityIdentity(skill.name, skill.abilityId), skill.hits or 0, skill.crits or 0, NumberText(skill.damage or 0))
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Top DoT Ticks (Damage over Time)" })
        if not snapshot.dotList or #snapshot.dotList == 0 then
            AddScrollableStatLine("No DoT data yet.", "No damage-over-time ticks recorded in this fight")
        else
            for i = 1, math.min(20, #snapshot.dotList) do
                local dot = snapshot.dotList[i]
                local dotCritPct = dot.hits > 0 and ((dot.crits / dot.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, dot.name, dot.abilityId or 0, ColorShort(dot.damage, COMBAT_COLOR_HEX.dot), dotCritPct),
                    string.format("DoT: %s | Total ticks: %d | Crit ticks: %d", FormatAbilityIdentity(dot.name, dot.abilityId), dot.hits or 0, dot.crits or 0)
                )
            end
        end

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Top HoT Ticks (Heal over Time)" })
        if not snapshot.hotList or #snapshot.hotList == 0 then
            AddScrollableStatLine("No HoT data yet.", "No heal-over-time ticks recorded in this fight")
        else
            for i = 1, math.min(20, #snapshot.hotList) do
                local hot = snapshot.hotList[i]
                local hotCritPct = hot.hits > 0 and ((hot.crits / hot.hits) * 100) or 0
                AddScrollableStatLine(
                    string.format("%d) %s [id:%d] - %s (%.0f%% crit)", i, hot.name, hot.abilityId or 0, ColorShort(hot.heal, COMBAT_COLOR_HEX.hot), hotCritPct),
                    string.format("HoT: %s | Total ticks: %d | Crit ticks: %d", FormatAbilityIdentity(hot.name, hot.abilityId), hot.hits or 0, hot.crits or 0)
                )
            end
        end

        AddHealingAndMitigationMoments(snapshot, "No mitigation events in this fight")

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "behavior" then
        local behaviorSummary = GetBehavior()
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
            AddScrollableStatLine(behaviorRows[i].label, behaviorRows[i].tooltip)
        end

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "formulas" then
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "Formula Panel (ESO + ConsoleMetrics)",
            tooltip = "Core ESO stat equations plus exact formulas used by this addon",
        })

        AddScrollableStatLine(
            "Coverage Notes",
            "This panel includes core published ESO equations and all formulas used by ConsoleMetrics. Some internal server formulas are undisclosed and can change by patch."
        )

        local function AddFormulaRow(title, equation, note)
            AddScrollableStatLine(title, string.format("%s | %s", equation, note))
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

        AddScrollableStatLine(
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
        AddScrollableStatLine(
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
            AddScrollableStatLine(
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
                        AddScrollableStatLine(
                            string.format("%s Fight Avg/Median: n/a", label),
                            "No fight-duration resource samples available for this stat."
                        )
                        return
                    end

                    local avgValue = maxValue * (stats.averagePct / 100)
                    local medianValue = maxValue * (stats.medianPct / 100)
                    AddScrollableStatLine(
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
                AddScrollableStatLine(
                    string.format("Current Resource State: HP %.0f%% | MAG %.0f%% | STAM %.0f%%", hpPct, magPct, stamPct),
                    "Fallback snapshot when fight-duration resource samples are not available yet."
                )
            end
        else
            AddScrollableStatLine(
                "Player Power Stats Unavailable",
                "Could not read GetPlayerStat-derived max pools in this context; comparison rows skipped."
            )
        end

        local critStatus = CompareRange(snapshot.critPct or 0, roleProfile.crit[1], roleProfile.crit[2])
        AddScrollableStatLine(
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
        AddScrollableStatLine(
            string.format("Incoming DPS Pressure: %s", ShortNumber(incomingDps)),
            "Use with health/resist checks: if pressure is low and survivability stats are high, those stats may be overbuilt."
        )

        AddFormulaSection("Diminishing Returns + Stop Points")

        local behaviorSummary = GetBehavior()
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

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "options" then
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = "Options Panel",
            tooltip = "Settings, control buttons, and command reference",
        })

        AddActionButton(self.saved.dialogAutoHide and "Dialog Auto Hide: ON" or "Dialog Auto Hide: OFF", "Toggle automatic dialog close when out of combat", function()
            self.saved.dialogAutoHide = not self.saved.dialogAutoHide
        end)

        AddActionButton(self.saved.autoClearOnNextFight and "Auto Clear: ON" or "Auto Clear: OFF", "Toggle auto clear when next combat starts", function()
            self.saved.autoClearOnNextFight = not self.saved.autoClearOnNextFight
        end)

        AddActionButton("Clear Fight Data", "Clear current and historical fight data", function()
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
            "Auto Clear: Clears scroll/live panel data on next fight.",
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
            AddScrollableStatLine(optionHelpLines[i], "Option explanation")
        end

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "share" then
        local snap, isLive = self:GetViewedFightSnapshot()
        local viewLabel = isLive and "Live" or string.format("Fight %d", self.viewFightIndex or 0)

        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = string.format("Share Panel (%s)", viewLabel),
            tooltip = "Pre-fill the chat virtual keyboard with stats or your build. Choose a channel and confirm to send.",
        })

        AddActionButton(
            "Share Front Bar Links to Chat",
            "Pre-fills chat with clickable ability links for every skill on your front bar.",
            function()
                self:ShareFrontBarLinksToChat()
            end
        )

        AddActionButton(
            "Share Back Bar Links to Chat",
            "Pre-fills chat with clickable ability links for every skill on your back bar.",
            function()
                self:ShareBackBarLinksToChat()
            end
        )

        AddActionButton(
            "Share Armor Links to Chat",
            "Pre-fills chat with clickable item links for your 7 armor pieces. Recipients can hover for full tooltips.",
            function()
                self:ShareArmorLinksToChat()
            end
        )

        AddActionButton(
            "Share Jewelry Links to Chat",
            "Pre-fills chat with clickable item links for neck and both rings.",
            function()
                self:ShareJewelryLinksToChat()
            end
        )

        AddActionButton(
            "Share Weapon Links to Chat",
            "Pre-fills chat with clickable item links for your front and back weapon slots.",
            function()
                self:ShareWeaponLinksToChat()
            end
        )

        dialog:AddSetting({ type = LibHarvensAddonSettings.ST_SECTION, label = "Stats" })

        AddActionButton(
            "Share Fight Stats to Chat",
            string.format("Pre-fills chat with: duration, DPS, HPS, damage, healing, taken, crit rate for %s.", viewLabel),
            function()
                self:ShareFightToChat(viewLabel)
            end
        )

        AddActionButton(
            "Share Top Skills to Chat",
            "Pre-fills chat with your top 5 damage skills as ability links with totals.",
            function()
                self:ShareTopSkillsToChat()
            end
        )

        AddActionButton(
            "Share Sustain / Resources to Chat",
            "Pre-fills chat with average HP, Magicka, and Stamina percentages.",
            function()
                self:ShareResourceToChat()
            end
        )

        AddActionButton(
            "Share Build Summary to Chat",
            "Sends a text summary line (CP, sets, boon, bars) and prints linked bars to your chat log.",
            function()
                self:ShareBuildToChat()
            end
        )

        AddActionButton(
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
        AddScrollableStatLine(
            "1. Press a Share button above",
            "The virtual keyboard will open with the text already filled in."
        )
        AddScrollableStatLine(
            "2. Choose your chat channel",
            "Press LB/RB to switch channels in the chat input box."
        )
        AddScrollableStatLine(
            "3. Press Confirm / A to send",
            "Your stats or build will be posted to chat."
        )

        AddBackButton()
        AddCloseButton()
        return
    end

    if panel == "saves" then
        local saves = self.saved.savedFights or {}
        local maxSaves = tonumber(self.saved.maxSavedFights) or self.defaults.maxSavedFights
        dialog:AddSetting({
            type = LibHarvensAddonSettings.ST_SECTION,
            label = string.format("Saved Fights (%d/%d)", #saves, maxSaves),
            tooltip = "Fights saved here persist across sessions. Load a slot to browse it in history.",
        })

        AddActionButton(
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

        AddActionButton(
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
            AddScrollableStatLine("No saved fights yet. View a fight and press Save above.", "Save fights to access them across sessions and reloads.")
        else
            for i = 1, #saves do
                local entry = saves[i]
                if entry and entry.snapshot then
                    local snap = entry.snapshot
                    local topTarget = snap.targetList and snap.targetList[1]
                    local targetDesc = topTarget and (" vs " .. (topTarget.name or "?")) or ""
                    AddScrollableStatLine(
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
                    AddActionButton(
                        string.format("Load Slot %d Into History", slotIndex),
                        string.format("Add saved slot %d to fight history so you can browse it with Prev/Next.", slotIndex),
                        function()
                            local ok, msg = self:LoadSavedFightIntoHistory(slotIndex)
                            self:Print(msg)
                            self.dialogPanel = "main"
                        end
                    )
                    AddActionButton(
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
            AddActionButton("Clear All Saves", "Delete all saved fight slots permanently.", function()
                self.saved.savedFights = {}
                self:Print("All saved fights cleared.")
            end)
        end

        AddBackButton()
        AddCloseButton()
        return
    end

    self.dialogPanel = "main"
    RefreshDialog()
end

