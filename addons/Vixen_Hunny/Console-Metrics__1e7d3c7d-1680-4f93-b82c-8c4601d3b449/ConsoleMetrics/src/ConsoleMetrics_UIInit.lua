local function CreateLabeledRow(parent, labelText, yOffset, color)
    local wm = WINDOW_MANAGER

    local row = wm:CreateControl(nil, parent, CT_CONTROL)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, yOffset)
    row:SetDimensions(400, 40)

    local label = wm:CreateControl(nil, row, CT_LABEL)
    label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    label:SetFont("ZoFontGamepad20")
    label:SetColor(color[1], color[2], color[3], 1)
    label:SetText(labelText)

    local value = wm:CreateControl(nil, row, CT_LABEL)
    value:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    value:SetFont("ZoFontGamepad20")
    value:SetColor(color[1], color[2], color[3], 1)
    value:SetText("0")

    local track = wm:CreateControl(nil, row, CT_BACKDROP)
    track:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 24)
    track:SetDimensions(400, 12)
    track:SetCenterColor(0.12, 0.06, 0.03, 0.95)
    track:SetEdgeColor(0.36, 0.20, 0.10, 1)
    track:SetEdgeTexture(nil, 1, 1, 0, 0)

    local bar = wm:CreateControl(nil, track, CT_STATUSBAR)
    bar:SetAnchor(TOPLEFT, track, TOPLEFT, 1, 1)
    bar:SetDimensions(398, 10)
    bar:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericfill.dds")
    bar:SetColor(color[1], color[2], color[3], 1)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)

    return {
        value = value,
        bar = bar,
    }
end

function ConsoleMetrics:CreateUI()
    local wm = WINDOW_MANAGER

    local root = wm:CreateTopLevelWindow("ConsoleMetricsRoot")
    root:SetDimensions(760, 430)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.x, self.saved.y)
    root:SetMovable(not self.saved.locked)
    root:SetMouseEnabled(true)
    root:SetClampedToScreen(true)
    root:SetScale(self.saved.scale)

    root:SetHandler("OnMoveStop", function(control)
        self.saved.x = control:GetLeft()
        self.saved.y = control:GetTop()
    end)

    local frame = wm:CreateControl(nil, root, CT_BACKDROP)
    frame:SetAnchorFill(root)
    frame:SetCenterColor(0.08, 0.04, 0.02, 0.84)
    frame:SetEdgeColor(1, 0.42, 0.15, 0.92)
    frame:SetEdgeTexture(nil, 2, 2, 0, 0)

    local titleBg = wm:CreateControl(nil, root, CT_BACKDROP)
    titleBg:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    titleBg:SetDimensions(760, 62)
    titleBg:SetCenterColor(0.25, 0.08, 0.02, 0.95)
    titleBg:SetEdgeColor(1, 0.54, 0.20, 0.95)
    titleBg:SetEdgeTexture(nil, 1, 1, 0, 0)

    local title = wm:CreateControl(nil, root, CT_LABEL)
    title:SetAnchor(LEFT, titleBg, LEFT, 20, 0)
    title:SetFont("ZoFontGamepad34")
    title:SetColor(1, 0.74, 0.42, 1)
    title:SetText("CONSOLE METRICS")

    local subtitle = wm:CreateControl(nil, root, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, -6)
    subtitle:SetFont("ZoFontGamepad16")
    subtitle:SetColor(0.96, 0.84, 0.71, 1)
    subtitle:SetText("Combat snapshot tuned for gamepad UI")

    local durationLabel = wm:CreateControl(nil, root, CT_LABEL)
    durationLabel:SetAnchor(RIGHT, titleBg, RIGHT, -22, 0)
    durationLabel:SetFont("ZoFontGamepad20")
    durationLabel:SetColor(1, 0.83, 0.67, 1)
    durationLabel:SetText("Encounter 0.0s")

    local statsPane = wm:CreateControl(nil, root, CT_BACKDROP)
    statsPane:SetAnchor(TOPLEFT, root, TOPLEFT, 16, 74)
    statsPane:SetDimensions(420, 340)
    statsPane:SetCenterColor(0.10, 0.05, 0.03, 0.65)
    statsPane:SetEdgeColor(0.45, 0.24, 0.12, 0.85)
    statsPane:SetEdgeTexture(nil, 1, 1, 0, 0)

    local feedPane = wm:CreateControl(nil, root, CT_BACKDROP)
    feedPane:SetAnchor(TOPRIGHT, root, TOPRIGHT, -16, 74)
    feedPane:SetDimensions(300, 340)
    feedPane:SetCenterColor(0.09, 0.04, 0.03, 0.67)
    feedPane:SetEdgeColor(0.45, 0.24, 0.12, 0.85)
    feedPane:SetEdgeTexture(nil, 1, 1, 0, 0)

    local feedTitle = wm:CreateControl(nil, feedPane, CT_LABEL)
    feedTitle:SetAnchor(TOPLEFT, feedPane, TOPLEFT, 12, 10)
    feedTitle:SetFont("ZoFontGamepad20")
    feedTitle:SetColor(1, 0.70, 0.47, 1)
    feedTitle:SetText("BATTLE FEED")

    local rows = {
        dps = CreateLabeledRow(statsPane, "DPS", 12, METRIC_ROW_COLORS.dps),
        hps = CreateLabeledRow(statsPane, "HPS", 58, METRIC_ROW_COLORS.hps),
        damage = CreateLabeledRow(statsPane, "Damage Done", 104, METRIC_ROW_COLORS.damage),
        heal = CreateLabeledRow(statsPane, "Healing Done", 150, METRIC_ROW_COLORS.heal),
        taken = CreateLabeledRow(statsPane, "Damage Taken", 196, METRIC_ROW_COLORS.taken),
        crit = CreateLabeledRow(statsPane, "Crit Rate", 242, METRIC_ROW_COLORS.crit),
    }

    local skillTitle = wm:CreateControl(nil, statsPane, CT_LABEL)
    skillTitle:SetAnchor(TOPLEFT, statsPane, TOPLEFT, 0, 292)
    skillTitle:SetFont("ZoFontGamepad20")
    skillTitle:SetColor(1, 0.70, 0.47, 1)
    skillTitle:SetText("Top Damage Skills")

    local skillLabels = {}
    for i = 1, 3 do
        local skillLabel = wm:CreateControl(nil, statsPane, CT_LABEL)
        skillLabel:SetAnchor(TOPLEFT, statsPane, TOPLEFT, 0, 292 + (i * 24))
        skillLabel:SetFont("ZoFontGamepad20")
        skillLabel:SetColor(0.95, 0.86, 0.76, 1)
        skillLabel:SetText(string.format("%d. -", i))
        skillLabels[i] = skillLabel
    end

    local healTitle = wm:CreateControl(nil, feedPane, CT_LABEL)
    healTitle:SetAnchor(TOPLEFT, feedPane, TOPLEFT, 12, 280)
    healTitle:SetFont("ZoFontGamepad20")
    healTitle:SetColor(1, 0.70, 0.47, 1)
    healTitle:SetText("TOP HEALING")

    local healLabels = {}
    for i = 1, 3 do
        local healLabel = wm:CreateControl(nil, feedPane, CT_LABEL)
        healLabel:SetAnchor(TOPLEFT, feedPane, TOPLEFT, 12, 280 + (i * 24))
        healLabel:SetFont("ZoFontGamepad16")
        healLabel:SetColor(0.45, 1, 0.55, 1)
        healLabel:SetText(string.format("%d. -", i))
        healLabels[i] = healLabel
    end

    local scrollLabels = {}
    for i = 1, self.saved.scrollSize do
        local line = wm:CreateControl(nil, feedPane, CT_LABEL)
        line:SetAnchor(TOPLEFT, feedPane, TOPLEFT, 12, 28 + ((i - 1) * 36))
        line:SetDimensions(280, 34)
        line:SetFont("ZoFontGamepad20")
        line:SetColor(1, 0.68, 0.46, 1)
        line:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        line:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        line:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        line:SetHidden(true)
        scrollLabels[i] = line
    end

    self.ui.root = root
    self.ui.rows = rows
    self.ui.durationLabel = durationLabel
    self.ui.scrollLabels = scrollLabels
    self.ui.skillLabels = skillLabels
    self.ui.healLabels = healLabels

    if not self.saved.showOutOfCombat then
        root:SetHidden(true)
    end
end

function ConsoleMetrics:DumpGameSets()
    -- Part 1: Enumerate all item sets via ESO item set API.
    local gameSetCount = 0
    if type(GetNumItemSets) == "function" then
        local numSets = 0
        local ok = pcall(function()
            numSets = GetNumItemSets()
        end)
        if ok and type(numSets) == "number" and numSets > 0 then
            gameSetCount = numSets
            self:Print(string.format("Enumerating %d item sets via GetNumItemSets...", numSets))
            for i = 1, numSets do
                local setName, numBonuses, numEquipped, maxEquipped, setId, isCrafted
                local ok2 = pcall(function()
                    setName, numBonuses, numEquipped, maxEquipped, setId, isCrafted = GetItemSetInfo(i)
                end)
                if ok2 and setName and setName ~= "" then
                    d(string.format(
                        "|cFF6A00[CM-Set]|r [%d] setId=%s name=%s bonuses=%d crafted=%s",
                        i,
                        tostring(setId or "?"),
                        setName,
                        tonumber(numBonuses) or 0,
                        tostring(isCrafted or false)
                    ))
                end
            end
        else
            self:Print("GetNumItemSets returned 0 or is unavailable in this context.")
        end
    else
        self:Print("GetNumItemSets not found in this ESO build.")
    end

    -- Part 2: Session-observed ability IDs accumulated from all combat events this session.
    local abilityCount = tonumber(self.observedAbilityCount) or 0
    if abilityCount <= 0 then
        for _ in pairs(self.observedAbilityLog or {}) do
            abilityCount = abilityCount + 1
        end
        self.observedAbilityCount = abilityCount
    end

    if abilityCount > 0 then
        self:Print(string.format("Session-observed unique abilities: %d", abilityCount))
        for abilityId, name in pairs(self.observedAbilityLog) do
            d(string.format("|cFF6A00[CM-Ability]|r id=%d name=%s", abilityId, name))
        end
    else
        self:Print("No abilities observed this session. Enter combat to populate ability ID log.")
    end

    if gameSetCount == 0 and abilityCount == 0 then
        self:Print("dumpsets: no data yet. Check ESO API availability or enter combat first.")
    end
end

function ConsoleMetrics:ApplyConsolePerformancePreset()
    if not self.saved then
        return
    end

    self.saved.lowMemoryMode = true
    self.saved.behaviorModelEnabled = false
    self.behaviorModelCache = nil
    self.saved.ioTraceEnabled = false
    self.saved.ioTraceMode = "summary"
    self.saved.ioTraceTargetOnlyProcessing = true
    self.saved.ioTraceSkipResourceSampling = true
    self.saved.ioTraceMaxLinesPerSecond = math.max(1, math.min(400, math.min(tonumber(self.saved.ioTraceMaxLinesPerSecond) or 40, 20)))
    self.saved.ioTraceSummarySeconds = math.max(1, math.min(10, tonumber(self.saved.ioTraceSummarySeconds) or 1))

    if self.fightHistory and #self.fightHistory > 0 then
        self:ApplyLowMemoryModeToHistory()
    end
    self:EnforceFightHistoryLimit()
end

function ConsoleMetrics:HandleSlash(rawInput)
    local input = string.lower(zo_strtrim(rawInput or ""))
    local rawText = rawInput or ""

    if input == "" or input == "help" or input == "options" then
        self:PrintHelp()
        return
    end

    if input == "inject" or input == "journal" then
        self:RefreshJournalIntegration(true)
        return
    end

    if input == "view" or input == "menu" then
        self.dialogPanel = "main"
        self:OpenFightViewDialog()
        return
    end

    if input == "close" then
        self:CloseFightViewDialog(false, "slash")
        return
    end

    if input == "next" then
        if self:StepFightView(1) then
            self:OpenFightViewDialog(false)
        else
            self:Print("No fight history available yet.")
        end
        return
    end

    if input == "prev" then
        if self:StepFightView(-1) then
            self:OpenFightViewDialog(false)
        else
            self:Print("No fight history available yet.")
        end
        return
    end

    if input == "clear" then
        self:ResetFightData(false)
        self:Print("Fight history and live fight data cleared")
        return
    end

    local autoClearMode = string.match(input, "^autoclear%s+(%S+)$")
    if autoClearMode == "on" then
        self.saved.autoClearOnNextFight = true
        self:Print("Auto clear on next fight enabled")
        return
    end

    if autoClearMode == "off" then
        self.saved.autoClearOnNextFight = false
        self:Print("Auto clear on next fight disabled")
        return
    end

    local autoHideMode = string.match(input, "^autohide%s+(%S+)$")
    if autoHideMode == "on" then
        self.saved.dialogAutoHide = true
        self:ArmDialogAutoHide()
        self:Print("Dialog auto hide enabled")
        return
    end

    if autoHideMode == "off" then
        self.saved.dialogAutoHide = false
        self.dialogAutoHideAtMs = nil
        self:Print("Dialog auto hide disabled")
        return
    end

    local perfMode = string.match(input, "^perf%s+(%S+)$")
    if perfMode == "on" then
        self.saved.performanceMode = true
        self:ApplyConsolePerformancePreset()
        self:Print("Performance Mode enabled (Series S preset applied).")
        return
    end
    if perfMode == "off" then
        self.saved.performanceMode = false
        self:Print("Performance Mode disabled.")
        return
    end
    if input == "perf" or input == "perf status" then
        self:Print(string.format(
            "Performance Mode: %s | lowMemory=%s | behaviorModel=%s | trace=%s",
            tostring(self.saved.performanceMode == true),
            tostring(self.saved.lowMemoryMode == true),
            tostring(self.saved.behaviorModelEnabled == true),
            tostring(self.saved.ioTraceEnabled == true)
        ))
        return
    end

    if input == "dumpsets" or input == "logsets" then
        self:DumpGameSets()
        return
    end

    if input == "debugbuild" or input == "builddebug" then
        self:PrintBuildSnapshotDebug("slash")
        return
    end

    local function PrintTraceDangerWarning()
        self:Print("WARNING: Live trace output is heavy and can degrade console performance/stability. Use only for short debugging windows.")
    end

    local traceTarget = string.match(rawText, "^%s*[Tt][Rr][Aa][Cc][Ee]%s+[Tt][Aa][Rr][Gg][Ee][Tt]%s+(.+)$")
    if traceTarget then
        local choice = TrimText(traceTarget)
        local lowerChoice = string.lower(choice)
        if lowerChoice == "off" or lowerChoice == "none" or lowerChoice == "clear" then
            self.saved.ioTraceTargetMode = "off"
            self.saved.ioTraceTargetName = ""
            self:Print("Trace target filter disabled.")
            return
        end
        if lowerChoice == "reticle" or lowerChoice == "current" then
            self.saved.ioTraceTargetMode = "reticle"
            self.saved.ioTraceTargetName = ""
            self:Print("Trace target filter set to reticle target.")
            if self.saved.ioTraceEnabled then
                PrintTraceDangerWarning()
            end
            return
        end

        self.saved.ioTraceTargetMode = "name"
        self.saved.ioTraceTargetName = choice
        self:Print(string.format("Trace target filter set to '%s'.", choice))
        if self.saved.ioTraceEnabled then
            PrintTraceDangerWarning()
        end
        return
    end

    local traceToggle = string.match(input, "^trace%s+(%S+)$")
    if traceToggle == "on" then
        self.saved.ioTraceEnabled = true
        self:ResetIoTraceState(GetFrameTimeMilliseconds())
        self:Print("Live trace enabled. Use '/cm trace mode all' for full event lines.")
        PrintTraceDangerWarning()
        return
    end

    if traceToggle == "off" then
        self.saved.ioTraceEnabled = false
        self:Print("Live trace disabled.")
        return
    end

    local traceMode = string.match(input, "^trace%s+mode%s+(%S+)$")
    if traceMode then
        self.saved.ioTraceMode = self:NormalizeIoTraceMode(traceMode)
        self:Print(string.format("Trace mode set to '%s'.", self.saved.ioTraceMode))
        if self.saved.ioTraceEnabled then
            PrintTraceDangerWarning()
        end
        return
    end

    local traceMin = string.match(input, "^trace%s+min%s+(%S+)$")
    if traceMin then
        local value = tonumber(traceMin)
        if value then
            self.saved.ioTraceMinValue = math.max(0, math.floor(value + 0.5))
            self:Print(string.format("Trace minimum value set to %d.", self.saved.ioTraceMinValue))
        else
            self:Print("Trace min expects a number. Example: /cm trace min 500")
        end
        return
    end

    local traceCap = string.match(input, "^trace%s+cap%s+(%S+)$")
    if traceCap then
        local value = tonumber(traceCap)
        if value then
            self.saved.ioTraceMaxLinesPerSecond = math.max(1, math.min(400, math.floor(value + 0.5)))
            self:Print(string.format("Trace line cap set to %d lines/sec.", self.saved.ioTraceMaxLinesPerSecond))
        else
            self:Print("Trace cap expects a number. Example: /cm trace cap 60")
        end
        return
    end

    local traceSummary = string.match(input, "^trace%s+summary%s+(%S+)$")
    if traceSummary then
        local value = tonumber(traceSummary)
        if value then
            self.saved.ioTraceSummarySeconds = math.max(1, math.min(10, math.floor(value + 0.5)))
            self:Print(string.format("Trace summary period set to %d second(s).", self.saved.ioTraceSummarySeconds))
        else
            self:Print("Trace summary expects a number. Example: /cm trace summary 1")
        end
        return
    end

    local traceFocus = string.match(input, "^trace%s+focus%s+(%S+)$")
    if traceFocus == "on" then
        self.saved.ioTraceTargetOnlyProcessing = true
        self:Print("Trace focus processing enabled (non-target combat events are skipped).")
        if self.saved.ioTraceEnabled then
            PrintTraceDangerWarning()
        end
        return
    end
    if traceFocus == "off" then
        self.saved.ioTraceTargetOnlyProcessing = false
        self:Print("Trace focus processing disabled.")
        return
    end

    local traceSamples = string.match(input, "^trace%s+samples%s+(%S+)$")
    if traceSamples == "off" then
        self.saved.ioTraceSkipResourceSampling = true
        self:Print("Trace focus sampling reduction enabled (non-target windows skip samples).")
        if self.saved.ioTraceEnabled then
            PrintTraceDangerWarning()
        end
        return
    end
    if traceSamples == "on" then
        self.saved.ioTraceSkipResourceSampling = false
        self:Print("Trace focus sampling reduction disabled.")
        return
    end

    if input == "trace" or input == "trace status" then
        local targetMode = tostring(self.saved.ioTraceTargetMode or "off")
        local targetText = "off"
        if targetMode == "reticle" then
            local reticleName = type(GetUnitName) == "function" and UnitName(GetUnitName("reticleover")) or ""
            targetText = (reticleName and reticleName ~= "") and ("reticle:" .. reticleName) or "reticle:(none)"
        elseif targetMode == "name" then
            local name = tostring(self.saved.ioTraceTargetName or "")
            targetText = (name ~= "") and ("name:" .. name) or "name:(empty)"
        end

        self:Print(string.format(
            "Trace status: enabled=%s mode=%s target=%s focus=%s sampleSkip=%s min=%d cap=%d/s summary=%ds hit[min=%s max=%s n=%d]",
            tostring(self.saved.ioTraceEnabled == true),
            tostring(self.saved.ioTraceMode),
            targetText,
            tostring(self.saved.ioTraceTargetOnlyProcessing == true),
            tostring(self.saved.ioTraceSkipResourceSampling == true),
            tonumber(self.saved.ioTraceMinValue) or 0,
            tonumber(self.saved.ioTraceMaxLinesPerSecond) or 40,
            tonumber(self.saved.ioTraceSummarySeconds) or 1,
            NumberText(self.ioTraceState and self.ioTraceState.minHitValue or 0),
            NumberText(self.ioTraceState and self.ioTraceState.maxHitValue or 0),
            self.ioTraceState and self.ioTraceState.hitValueSamples or 0
        ))
        if self.saved.ioTraceEnabled then
            PrintTraceDangerWarning()
        end
        return
    end

    if input == "linkbuild" or input == "buildlink" or input == "chatbuild" or input == "share build" then
        self:ShareBuildToChat()
        return
    end

    if input == "share" or input == "share fight" or input == "sharefight" then
        self:ShareFightToChat()
        return
    end

    if input == "share skills" or input == "topskills" then
        self:ShareTopSkillsToChat()
        return
    end

    if input == "share sustain" or input == "sharesustain" or input == "shareresources" then
        self:ShareResourceToChat()
        return
    end

    if input == "share all" or input == "shareall" or input == "snapshot" then
        self:ShareFullSnapshotToChat()
        return
    end

    if input == "dumpcpslottables" or input == "dumpcpstars" or input == "logcpslottables" then
        self:DumpChampionSlottables()
        return
    end

    if input == "importpct" or input == "syncpct" then
        local _, message = self:ImportSetsFromPvPCooldownTracker()
        self:Print(message)
        return
    end

    local savefightName = string.match(rawText, "^%s*[Ss][Aa][Vv][Ee][Ff][Ii][Gg][Hh][Tt]%s+(.+)$")
    if savefightName then
        self.saved.saveFightDraftName = TrimText(savefightName)
        local ok, message = self:SaveViewedFight()
        self:Print(message)
        return
    end

    if input == "savefight" then
        local ok, message = self:SaveViewedFight()
        self:Print(message)
        return
    end

    local loadfightExactName = string.match(rawText, "^%s*[Ll][Oo][Aa][Dd][Ff][Ii][Gg][Hh][Tt][Ee][Xx][Aa][Cc][Tt]%s+(.+)$")
    if loadfightExactName then
        self.saved.loadFightDraftName = TrimText(loadfightExactName)
        local ok, message = self:LoadSavedFightIntoHistoryByExactName(self.saved.loadFightDraftName)
        self:Print(message)
        if ok then
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        end
        return
    end

    local loadfightStrictName = string.match(rawText, "^%s*[Ll][Oo][Aa][Dd][Ff][Ii][Gg][Hh][Tt][Ss][Tt][Rr][Ii][Cc][Tt]%s+(.+)$")
    if loadfightStrictName then
        self.saved.loadFightDraftName = TrimText(loadfightStrictName)
        local ok, message = self:LoadSavedFightIntoHistoryByExactName(self.saved.loadFightDraftName)
        self:Print(message)
        if ok then
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        end
        return
    end

    local loadfightName = string.match(rawText, "^%s*[Ll][Oo][Aa][Dd][Ff][Ii][Gg][Hh][Tt]%s+(.+)$")
    if loadfightName then
        self.saved.loadFightDraftName = TrimText(loadfightName)
        local ok, message = self:LoadSavedFightIntoHistoryByName(self.saved.loadFightDraftName)
        self:Print(message)
        if ok then
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        end
        return
    end

    if input == "loadfight" then
        local ok, message = self:LoadSavedFightIntoHistoryByName(self.saved.loadFightDraftName or "")
        self:Print(message)
        if ok then
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        end
        return
    end

    if input == "loadfightexact" or input == "loadfightstrict" then
        local ok, message = self:LoadSavedFightIntoHistoryByExactName(self.saved.loadFightDraftName or "")
        self:Print(message)
        if ok then
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        end
        return
    end

    if input == "loadsaves" then
        local loaded = 0
        for i = 1, #(self.saved.savedFights or {}) do
            local ok = self:LoadSavedFightIntoHistory(i)
            if ok then
                loaded = loaded + 1
            end
        end
        if loaded > 0 then
            self:Print(string.format("Loaded %d saved fight(s) into history (showing latest %d max). Use /cm view to browse.", loaded, self.saved.maxFightHistory or self.defaults.maxFightHistory))
            self.dialogPanel = "main"
            self:OpenFightViewDialog(false)
        else
            self:Print("No saved fights to load, or all are already in history.")
        end
        return
    end

    local addsetPayload = string.match(rawText, "^%s*[Aa][Dd][Dd][Ss][Ee][Tt]%s+(.+)$")
    if addsetPayload then
        local label, scene, abilityIdText, abilityName = string.match(addsetPayload, "([^|]*)|([^|]*)|([^|]*)|?(.*)")
        local abilityId = tonumber(TrimText(abilityIdText))
        local _, message = self:AddCustomSetRule(label, scene, abilityId, abilityName)
        self:Print(message)
        return
    end

    if input == "toggle" or input == "lock" or input == "unlock" then
        self:Print("On-screen panel is disabled. Use /cm view for the console dialog.")
        return
    end

    if input == "reset" then
        self.saved.x = self.defaults.x
        self.saved.y = self.defaults.y
        self.saved.scale = self.defaults.scale
        self.saved.autoClearOnNextFight = self.defaults.autoClearOnNextFight
        self.saved.maxFightHistory = self.defaults.maxFightHistory
        self.saved.performanceMode = self.defaults.performanceMode
        self:EnforceFightHistoryLimit()
        self.saved.dialogAutoHide = self.defaults.dialogAutoHide
        self.saved.dialogAutoHideSeconds = self.defaults.dialogAutoHideSeconds
        self.saved.debugEnabled = self.defaults.debugEnabled
        self.saved.debugIntervalSeconds = self.defaults.debugIntervalSeconds
        self.saved.drSampleAlpha = self.defaults.drSampleAlpha
        self.saved.ioTraceEnabled = self.defaults.ioTraceEnabled
        self.saved.ioTraceMode = self.defaults.ioTraceMode
        self.saved.ioTraceTargetMode = self.defaults.ioTraceTargetMode
        self.saved.ioTraceTargetName = self.defaults.ioTraceTargetName
        self.saved.ioTraceTargetOnlyProcessing = self.defaults.ioTraceTargetOnlyProcessing
        self.saved.ioTraceSkipResourceSampling = self.defaults.ioTraceSkipResourceSampling
        self.saved.ioTraceTargetGraceMs = self.defaults.ioTraceTargetGraceMs
        self.saved.ioTraceMaxLinesPerSecond = self.defaults.ioTraceMaxLinesPerSecond
        self.saved.ioTraceMinValue = self.defaults.ioTraceMinValue
        self.saved.ioTraceSummarySeconds = self.defaults.ioTraceSummarySeconds
        self.saved.behaviorModelEnabled = self.defaults.behaviorModelEnabled
        self.saved.behaviorModelRefreshMs = self.defaults.behaviorModelRefreshMs
        self.saved.customSetRules = {}
        self:InvalidateTrackedSetMatchCache()
        LIKELY_SET_PROC_CACHE = {}
        LIKELY_SET_PROC_CACHE_SIZE = 0
        self.saved.customSetDraftLabel = self.defaults.customSetDraftLabel
        self.saved.customSetDraftScene = self.defaults.customSetDraftScene
        self.saved.customSetDraftAbilityId = self.defaults.customSetDraftAbilityId
        self.saved.customSetDraftAbilityName = self.defaults.customSetDraftAbilityName
        self.saved.saveFightDraftName = self.defaults.saveFightDraftName
        self.saved.loadFightDraftName = self.defaults.loadFightDraftName
        self.saved.uiPanelEnabled = self.defaults.uiPanelEnabled
        self.dialogPanel = "main"
        self.dialogAutoHideAtMs = nil
        self.lastDialogRefreshKey = nil
        self.lastDebugPrintAtMs = nil
        self.ioTraceState = nil
        self.observedAbilityLog = {}
        self.observedAbilityCount = 0
        self.fpsRuntime = { fpsSamples = 0, fpsTotal = 0, fpsMin = nil, fpsBins = {} }
        if self.ui.root then
            self.ui.root:SetHidden(true)
        end
        self:Print("Dialog options reset")
        return
    end

    self:Print("Unknown command. Use /cm help")
end

-- Live-refresh key: only rebuild the dialog when panel, combat state, snapshot revision, or fight index changes.
local function BuildLiveDialogRefreshKey(self)
    local fight = self.fight or {}
    return string.format(
        "%s|%d|%d|%d",
        tostring(self.dialogPanel or "main"),
        self.inCombat and 1 or 0,
        math.floor(tonumber(fight.snapshotRev) or 0),
        self.viewFightIndex or 0
    )
end

function ConsoleMetrics:OnUpdate()
    local nowMs = GetFrameTimeMilliseconds()
    local dialogShowing = self:IsFightViewDialogShowing()

    -- Refresh the PC dialog on a timer while it is visible
    if not IsConsoleUI() and not (type(IsGamepadPreferred) == "function" and IsGamepadPreferred()) and dialogShowing then
        if not self.dialogRefreshAtMs or nowMs >= self.dialogRefreshAtMs then
            self:RefreshPCDialog()
            self.dialogRefreshAtMs = nowMs + DIALOG_LIVE_REFRESH_MS
        end
    end
    local getFramerate = type(_G) == "table" and _G.GetFramerate or nil
    if type(getFramerate) == "function" then
        local fps = tonumber(getFramerate())
        if fps and fps > 0 then
            self.fpsRuntime = self.fpsRuntime or { fpsSamples = 0, fpsTotal = 0, fpsMin = nil, fpsBins = {} }
            local rt = self.fpsRuntime
            rt.fpsSamples = (rt.fpsSamples or 0) + 1
            rt.fpsTotal = (rt.fpsTotal or 0) + fps
            if rt.fpsMin == nil or fps < rt.fpsMin then
                rt.fpsMin = fps
            end
            local bins = rt.fpsBins or {}
            rt.fpsBins = bins
            local bucket = math.max(0, math.min(120, math.floor(fps + 0.5)))
            local key = bucket + 1
            bins[key] = (bins[key] or 0) + 1
        end
    end

    -- Two-step gamepad cancel behavior:
    -- 1) If cancel hides a subpanel, reopen at Main.
    -- 2) If cancel hides Main, perform full close cleanup.
    if self.wasFightViewDialogShowing and not dialogShowing and self.ui.fightViewDialog and not self.isClosingFightViewDialog then
        if (self.dialogPanel or "main") ~= "main" then
            self.dialogPanel = "main"
            self:PopulateFightViewDialog(self.ui.fightViewDialog)
            self.ui.fightViewDialog:Show()
            self:ArmDialogAutoHide()
            self.dialogRefreshAtMs = 0
            dialogShowing = self:IsFightViewDialogShowing()
        else
            self:CloseFightViewDialog(true, "cancel")
            dialogShowing = false
        end
    end

    if self.dialogAutoHideAtMs and self.saved.dialogAutoHide and not self.inCombat and nowMs >= self.dialogAutoHideAtMs then
        self:CloseFightViewDialog(true, "autohide")
        dialogShowing = false
    end

    if self.inCombat then
        local performanceMode = self.saved and self.saved.performanceMode == true
        local protectionThrottleMs = performanceMode and math.max(PROTECTION_UPDATE_THROTTLE_MS, 750) or PROTECTION_UPDATE_THROTTLE_MS
        local metricsThrottleMs = performanceMode and math.max(METRICS_UPDATE_THROTTLE_MS, 400) or METRICS_UPDATE_THROTTLE_MS
        self:SampleFightResources(nowMs, false)
        -- Throttle protection inference to reduce per-frame GetFightSnapshot calls
        if nowMs >= (self.lastProtectionUpdateMs or 0) + protectionThrottleMs then
            self:UpdateProtectionInference(nowMs)
            self.lastProtectionUpdateMs = nowMs
        end
        
        -- Throttle metrics updates to reduce per-frame work during combat
        if nowMs >= (self.lastMetricsUpdateMs or 0) + metricsThrottleMs then
            self:UpdateMetrics()
            self.lastMetricsUpdateMs = nowMs
        end
    elseif self.hideAtMs and self.ui.root and not self.saved.showOutOfCombat then
        if nowMs >= self.hideAtMs then
            self.hideAtMs = nil
            self.ui.root:SetHidden(true)
        end
    end

    if dialogShowing and self.viewFightIndex == 0 then
        if not self.dialogRefreshAtMs or nowMs >= self.dialogRefreshAtMs then
            local refreshKey = BuildLiveDialogRefreshKey(self)
            if self.ui.fightViewDialog and self.lastDialogRefreshKey ~= refreshKey then
                self:PopulateFightViewDialog(self.ui.fightViewDialog)
                self.lastDialogRefreshKey = refreshKey
            end
            local panelName = tostring(self.dialogPanel or "main")
            local refreshIntervalMs = DIALOG_LIVE_REFRESH_MS
            if self.saved and self.saved.performanceMode then
                if panelName == "main" then
                    refreshIntervalMs = math.max(DIALOG_LIVE_REFRESH_MS, 750)
                elseif panelName == "overview" or panelName == "resources" or panelName == "mitigation" or panelName == "resistance" then
                    refreshIntervalMs = math.max(DIALOG_LIVE_REFRESH_MS, 1500)
                else
                    refreshIntervalMs = math.max(DIALOG_LIVE_REFRESH_MS, 2000)
                end
            elseif panelName ~= "main" then
                if panelName == "overview" or panelName == "resources" or panelName == "mitigation" or panelName == "resistance" then
                    refreshIntervalMs = math.max(DIALOG_LIVE_REFRESH_MS, 1000)
                else
                    refreshIntervalMs = math.max(DIALOG_LIVE_REFRESH_MS, 1500)
                end
            end
            self.dialogRefreshAtMs = nowMs + refreshIntervalMs
        end
    else
        self.dialogRefreshAtMs = nil
        self.lastDialogRefreshKey = nil
    end

    -- Throttle scroll updates to prevent excessive per-frame UI updates
    local scrollThrottleMs = (self.saved and self.saved.performanceMode) and math.max(SCROLL_UPDATE_THROTTLE_MS, 300) or SCROLL_UPDATE_THROTTLE_MS
    if nowMs >= (self.lastScrollUpdateMs or 0) + scrollThrottleMs then
        self:RefreshScroll()
        self.lastScrollUpdateMs = nowMs
    end

    self.wasFightViewDialogShowing = dialogShowing
    self:EmitIoTraceHeartbeat(nowMs)
end

function ConsoleMetrics:RegisterLAMSettings()
    if not LibHarvensAddonSettings then
        return
    end

    local panel = LibHarvensAddonSettings:AddAddon("Console Metrics")

    -- General
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "General",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Show HUD Out of Combat",
        tooltip = "Keep the metrics panel visible when not in combat.",
        getFunction = function() return self.saved.showOutOfCombat end,
        setFunction = function(v)
            self.saved.showOutOfCombat = v
            if self.ui.root then
                self.ui.root:SetHidden(not v and not self.inCombat)
            end
        end,
        default = self.defaults.showOutOfCombat,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Auto Clear on Next Fight",
        tooltip = "Wipe the live scroll panel when a new combat encounter begins.",
        getFunction = function() return self.saved.autoClearOnNextFight end,
        setFunction = function(v) self.saved.autoClearOnNextFight = v end,
        default = self.defaults.autoClearOnNextFight,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Max Fight History",
        tooltip = "How many past fights to keep in memory for browsing (5–40).",
        min = 5,
        max = 40,
        step = 1,
        format = "%d",
        getFunction = function() return tonumber(self.saved.maxFightHistory) or self.defaults.maxFightHistory end,
        setFunction = function(v)
            self.saved.maxFightHistory = math.max(5, math.min(40, math.floor(v + 0.5)))
            self:EnforceFightHistoryLimit()
        end,
        default = self.defaults.maxFightHistory,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Scroll Feed Lines",
        tooltip = "Number of combat feed lines shown in the HUD (requires /reloadui).",
        min = 1,
        max = 20,
        step = 1,
        format = "%d",
        getFunction = function() return tonumber(self.saved.scrollSize) or self.defaults.scrollSize end,
        setFunction = function(v)
            self.saved.scrollSize = math.max(1, math.min(20, math.floor(v + 0.5)))
        end,
        default = self.defaults.scrollSize,
    })

    -- Dialog
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Fight Dialog",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Dialog Auto Hide",
        tooltip = "Automatically close the fight view dialog after combat ends.",
        getFunction = function() return self.saved.dialogAutoHide end,
        setFunction = function(v)
            self.saved.dialogAutoHide = v
            if v then self:ArmDialogAutoHide() else self.dialogAutoHideAtMs = nil end
        end,
        default = self.defaults.dialogAutoHide,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Auto Hide Delay (seconds)",
        tooltip = "Seconds after combat to wait before auto-closing the dialog (3–120).",
        min = 3,
        max = 120,
        step = 1,
        format = "%d",
        getFunction = function() return tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds end,
        setFunction = function(v)
            self.saved.dialogAutoHideSeconds = math.max(3, math.min(120, math.floor(v + 0.5)))
        end,
        default = self.defaults.dialogAutoHideSeconds,
        disable = function() return not self.saved.dialogAutoHide end,
    })

    -- Performance
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Performance",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Performance Mode",
        tooltip = "Apply Series S / low-end console preset (enables low memory mode, disables ML model and trace).",
        getFunction = function() return self.saved.performanceMode end,
        setFunction = function(v)
            self.saved.performanceMode = v
            if v then self:ApplyConsolePerformancePreset() end
        end,
        default = self.defaults.performanceMode,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Low Memory Mode",
        tooltip = "Compact fight snapshots to reduce memory usage. Disables some detailed breakdowns.",
        getFunction = function() return self.saved.lowMemoryMode end,
        setFunction = function(v)
            self.saved.lowMemoryMode = v
            if v and self.fightHistory and #self.fightHistory > 0 then
                self:ApplyLowMemoryModeToHistory()
            end
        end,
        default = self.defaults.lowMemoryMode,
    })

    -- ML Model
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Behavior Model (ML)",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Enable Behavior Model",
        tooltip = "Run the ML-lite resistance and behavior prediction model during combat.",
        getFunction = function() return self.saved.behaviorModelEnabled end,
        setFunction = function(v)
            self.saved.behaviorModelEnabled = v
            if not v then self.behaviorModelCache = nil end
        end,
        default = self.defaults.behaviorModelEnabled,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Model Refresh (ms)",
        tooltip = "How often the behavior model recalculates during combat (250–5000 ms).",
        min = 250,
        max = 5000,
        step = 250,
        format = "%d",
        getFunction = function() return tonumber(self.saved.behaviorModelRefreshMs) or self.defaults.behaviorModelRefreshMs end,
        setFunction = function(v)
            self.saved.behaviorModelRefreshMs = math.max(250, math.min(5000, math.floor(v / 250 + 0.5) * 250))
        end,
        default = self.defaults.behaviorModelRefreshMs,
        disable = function() return not self.saved.behaviorModelEnabled end,
    })

    -- Actions
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Actions",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Apply Performance Preset",
        tooltip = "Apply the low-memory / high-performance preset (same as /cm perf on).",
        buttonText = "Apply",
        clickHandler = function()
            self.saved.performanceMode = true
            self:ApplyConsolePerformancePreset()
            self:Print("Performance preset applied.")
        end,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Clear All Fight Data",
        tooltip = "Wipe current fight and full fight history from memory.",
        buttonText = "Clear",
        clickHandler = function()
            self:ResetFightData(false)
            self:Print("Fight data cleared.")
        end,
    })
end

function ConsoleMetrics:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("ConsoleMetricsSavedVars", 1, nil, self.defaults)
    self.saved.maxFightHistory = tonumber(self.saved.maxFightHistory) or self.defaults.maxFightHistory
    local hardHistoryCap = tonumber(MAX_FIGHT_HISTORY_HARD_CAP) or 40
    self.saved.maxFightHistory = math.max(5, math.min(hardHistoryCap, self.saved.maxFightHistory))
    self.lastDialogRefreshKey = nil
    if self.saved.autoClearOnNextFight == nil then
        self.saved.autoClearOnNextFight = self.defaults.autoClearOnNextFight
    end
    if self.saved.dialogAutoHide == nil then
        self.saved.dialogAutoHide = self.defaults.dialogAutoHide
    end
    self.saved.dialogAutoHideSeconds = tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds
    self.saved.dialogAutoHideSeconds = Clamp(self.saved.dialogAutoHideSeconds, 3, 120)
    if self.saved.uiPanelEnabled == nil then
        self.saved.uiPanelEnabled = self.defaults.uiPanelEnabled
    end
    self.saved.uiPanelEnabled = false
    if self.saved.performanceMode == nil then
        self.saved.performanceMode = self.defaults.performanceMode
    end
    if self.saved.lowMemoryMode == nil then
        self.saved.lowMemoryMode = self.defaults.lowMemoryMode
    end
    if self.saved.debugEnabled == nil then
        self.saved.debugEnabled = self.defaults.debugEnabled
    end
    self.saved.debugIntervalSeconds = tonumber(self.saved.debugIntervalSeconds) or self.defaults.debugIntervalSeconds
    self.saved.debugIntervalSeconds = Clamp(self.saved.debugIntervalSeconds, 1, 30)
    if self.saved.ioTraceEnabled == nil then
        self.saved.ioTraceEnabled = self.defaults.ioTraceEnabled
    end
    self.saved.ioTraceMode = self:NormalizeIoTraceMode(self.saved.ioTraceMode or self.defaults.ioTraceMode)
    local savedTraceTargetMode = string.lower(tostring(self.saved.ioTraceTargetMode or self.defaults.ioTraceTargetMode))
    if savedTraceTargetMode ~= "off" and savedTraceTargetMode ~= "name" and savedTraceTargetMode ~= "reticle" then
        savedTraceTargetMode = self.defaults.ioTraceTargetMode
    end
    self.saved.ioTraceTargetMode = savedTraceTargetMode
    self.saved.ioTraceTargetName = tostring(self.saved.ioTraceTargetName or self.defaults.ioTraceTargetName)
    if self.saved.ioTraceTargetOnlyProcessing == nil then
        self.saved.ioTraceTargetOnlyProcessing = self.defaults.ioTraceTargetOnlyProcessing
    end
    if self.saved.ioTraceSkipResourceSampling == nil then
        self.saved.ioTraceSkipResourceSampling = self.defaults.ioTraceSkipResourceSampling
    end
    self.saved.ioTraceTargetGraceMs = tonumber(self.saved.ioTraceTargetGraceMs) or self.defaults.ioTraceTargetGraceMs
    self.saved.ioTraceTargetGraceMs = Clamp(self.saved.ioTraceTargetGraceMs, 250, 5000)
    self.saved.ioTraceMaxLinesPerSecond = tonumber(self.saved.ioTraceMaxLinesPerSecond) or self.defaults.ioTraceMaxLinesPerSecond
    self.saved.ioTraceMaxLinesPerSecond = Clamp(self.saved.ioTraceMaxLinesPerSecond, 1, 400)
    self.saved.ioTraceMinValue = tonumber(self.saved.ioTraceMinValue) or self.defaults.ioTraceMinValue
    self.saved.ioTraceMinValue = math.max(0, math.floor(self.saved.ioTraceMinValue + 0.5))
    self.saved.ioTraceSummarySeconds = tonumber(self.saved.ioTraceSummarySeconds) or self.defaults.ioTraceSummarySeconds
    self.saved.ioTraceSummarySeconds = Clamp(self.saved.ioTraceSummarySeconds, 1, 10)
    if self.saved.behaviorModelEnabled == nil then
        self.saved.behaviorModelEnabled = self.defaults.behaviorModelEnabled
    end
    self.saved.behaviorModelRefreshMs = tonumber(self.saved.behaviorModelRefreshMs) or self.defaults.behaviorModelRefreshMs
    self.saved.behaviorModelRefreshMs = Clamp(self.saved.behaviorModelRefreshMs, 250, 5000)
    self.saved.drSampleAlpha = tonumber(self.saved.drSampleAlpha) or self.defaults.drSampleAlpha
    self.saved.drSampleAlpha = Clamp(self.saved.drSampleAlpha, 0.05, 0.85)
    if self.saved.performanceMode then
        self:ApplyConsolePerformancePreset()
    end
    if type(self.saved.customSetRules) ~= "table" then
        self.saved.customSetRules = {}
    end
    self:InvalidateTrackedSetMatchCache()
    LIKELY_SET_PROC_CACHE = {}
    LIKELY_SET_PROC_CACHE_SIZE = 0
    if type(self.saved.customSetDraftLabel) ~= "string" then
        self.saved.customSetDraftLabel = self.defaults.customSetDraftLabel
    end
    self.saved.customSetDraftScene = NormalizeCustomSetScene(self.saved.customSetDraftScene or self.defaults.customSetDraftScene)
    if type(self.saved.customSetDraftAbilityId) ~= "string" then
        self.saved.customSetDraftAbilityId = self.defaults.customSetDraftAbilityId
    end
    if type(self.saved.customSetDraftAbilityName) ~= "string" then
        self.saved.customSetDraftAbilityName = self.defaults.customSetDraftAbilityName
    end
    if type(self.saved.saveFightDraftName) ~= "string" then
        self.saved.saveFightDraftName = self.defaults.saveFightDraftName
    end
    if type(self.saved.loadFightDraftName) ~= "string" then
        self.saved.loadFightDraftName = self.defaults.loadFightDraftName
    end
    if type(self.saved.savedFights) ~= "table" then
        self.saved.savedFights = {}
    end
    self.saved.maxSavedFights = tonumber(self.saved.maxSavedFights) or self.defaults.maxSavedFights
    self.saved.maxSavedFights = math.max(1, math.min(50, self.saved.maxSavedFights))

    self.playerName = UnitName(GetUnitName("player"))
    self.fightHistory = {}
    -- Restore persisted saved fights into session history so they're browsable immediately.
    for i = 1, #self.saved.savedFights do
        local entry = self.saved.savedFights[i]
        if entry and type(entry.snapshot) == "table" then
            if self.saved.lowMemoryMode then
                self:CompactFightSummaryForHistory(entry.snapshot)
            end
            self.fightHistory[#self.fightHistory + 1] = entry.snapshot
        end
    end
    self:EnforceFightHistoryLimit()
    self.viewFightIndex = #self.fightHistory > 0 and #self.fightHistory or 0
    self.dialogPanel = "main"
    self.dialogAutoHideAtMs = nil
    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false
    self.lastDebugPrintAtMs = nil
    self.ioTraceState = nil
    self.observedAbilityLog = {}
    self.observedAbilityCount = 0
    self.fpsRuntime = { fpsSamples = 0, fpsTotal = 0, fpsMin = nil, fpsBins = {} }

    if self.saved.uiPanelEnabled then
        self:CreateUI()
    end
    self.fight = NewFight(GetFrameTimeMilliseconds())

    self:RegisterLAMSettings()

    EVENT_MANAGER:RegisterForEvent(self.name .. "JournalMenuInject", EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(self.name .. "JournalMenuInject", EVENT_PLAYER_ACTIVATED)

        local initialMenuReady, initialSceneCount = self:RefreshJournalIntegration(false)
        if initialMenuReady then
            self:Print(string.format("Journal menu item ready (scene hooks: %d)", initialSceneCount))
            return
        end

        local retryName = self.name .. "JournalMenuRetry"
        local attempts = 0
        EVENT_MANAGER:RegisterForUpdate(retryName, 1500, function()
            attempts = attempts + 1
            local menuReady, hookedScenes = self:RefreshJournalIntegration(false)
            if menuReady then
                self:Print(string.format("Journal menu item ready (scene hooks: %d)", hookedScenes))
                EVENT_MANAGER:UnregisterForUpdate(retryName)
            elseif attempts >= 20 then
                self:Print("Journal menu item not ready yet. Open Main Menu, highlight Journal, then /reloadui.")
                EVENT_MANAGER:UnregisterForUpdate(retryName)
            end
        end)
    end)

    if MAIN_MENU_GAMEPAD_SCENE and MAIN_MENU_GAMEPAD_SCENE.RegisterCallback then
        MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                self:RefreshJournalIntegration(false)
            end
        end)
    end

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(...)
        self:OnCombatState(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)

    EVENT_MANAGER:RegisterForUpdate(self.name .. "Update", 200, function()
        self:OnUpdate()
    end)

    SLASH_COMMANDS["/cm"] = function(args)
        self:HandleSlash(args)
    end
    SLASH_COMMANDS["/consolemetrics"] = function(args)
        self:HandleSlash(args)
    end

    self:Print("Loaded. Console dialog mode active. Use /cm view")
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    ConsoleMetrics:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
