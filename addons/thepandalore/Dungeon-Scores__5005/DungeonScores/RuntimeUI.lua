DungeonScores = DungeonScores or {}

-- Runtime HUD and final-score notification.

local DS = DungeonScores
local WM = WINDOW_MANAGER
local Scoring = DS.Scoring
local Data = DS.Data

local NormalizeName = DS.Util.NormalizeName
local FormatDurationMs = DS.Util.FormatDurationMs
local FormatString = DS.Util.FormatString
local HUD_MIN_WIDTH = 410
local HUD_MAX_WIDTH = 720
local HUD_MIN_HEIGHT = 138
local HUD_SCREEN_MARGIN = 80

local function GetCurrentZoneDisplayName(run)
    local zoneId = run and tonumber(run.zoneId) or nil
    local localizedName = zoneId and GetZoneNameById and GetZoneNameById(zoneId) or nil
    if localizedName and localizedName ~= "" then
        return NormalizeName(localizedName)
    end
    return NormalizeName(run and run.zoneName)
end

function DS:GetActiveHMCount()
    if not self.run then
        return 0
    end
    local count = 0
    for _, boss in pairs(self.run.activeBosses) do
        if boss.hmActive then
            count = count + 1
        end
    end
    return count
end

function DS:GetRunningEventScore()
    if not self.run then
        return 0
    end
    return (self.run.killScore or 0) + (self.run.hmScore or 0)
end

function DS:CreateHud()
    if self.hud then
        return
    end

    local hud = WM:CreateTopLevelWindow("DungeonScoresHUD")
    hud:SetDimensions(HUD_MIN_WIDTH, HUD_MIN_HEIGHT)
    hud:SetClampedToScreen(true)
    hud:SetMouseEnabled(true)
    hud:SetMovable(true)

    if self.saved.hud.left and self.saved.hud.top then
        hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.hud.left, self.saved.hud.top)
    else
        hud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 190)
    end

    local backdrop = WM:CreateControl(nil, hud, CT_BACKDROP)
    backdrop:SetAnchorFill(hud)
    backdrop:SetCenterColor(0, 0, 0, 0.72)
    backdrop:SetEdgeColor(0.3, 0.3, 0.3, 0.9)

    local label = WM:CreateControl(nil, hud, CT_LABEL)
    label:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, 8)
    label:SetAnchor(BOTTOMRIGHT, hud, BOTTOMRIGHT, -10, -8)
    label:SetFont("ZoFontGameSmall")
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    hud:SetHandler("OnMoveStop", function(control)
        self.saved.hud.left = control:GetLeft()
        self.saved.hud.top = control:GetTop()
    end)

    self.hud = hud
    self.hudLabel = label
end

function DS:ResizeHudForLocalizedText(screenWidth)
    if not self.hud or not self.hudLabel then
        return
    end

    screenWidth = screenWidth or (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or HUD_MAX_WIDTH
    local availableWidth = math.max(HUD_MIN_WIDTH, math.min(HUD_MAX_WIDTH, screenWidth - HUD_SCREEN_MARGIN))

    -- Measure at the maximum supported width first, then shrink to the longest
    -- rendered line when the active locale is compact. If a translation needs
    -- the full width, the label is allowed to wrap and the HUD grows vertically.
    self.hud:SetWidth(availableWidth)
    local measuredWidth = tonumber(self.hudLabel:GetTextWidth()) or HUD_MIN_WIDTH
    local finalWidth = math.max(HUD_MIN_WIDTH, math.min(availableWidth, zo_ceil(measuredWidth) + 20))
    self.hud:SetWidth(finalWidth)
    local measuredHeight = tonumber(self.hudLabel:GetTextHeight()) or (HUD_MIN_HEIGHT - 16)
    self.hud:SetHeight(math.max(HUD_MIN_HEIGHT, zo_ceil(measuredHeight) + 16))
end

function DS:ResetHudPosition()
    if not self.hud then
        return
    end

    self.saved.hud.left = nil
    self.saved.hud.top = nil
    self.hud:ClearAnchors()
    self.hud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 190)
    self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_HUD_RESET))
end

function DS:RefreshHud()
    if not self.hud then
        return
    end

    local show = self.saved.settings.showHud and self:IsArmed()
    if self.lastHudVisible ~= show then
        self.hud:SetHidden(not show)
        self.lastHudVisible = show
    end
    if not show then
        self.lastHudRenderedText = nil
        self.lastHudRenderedScreenWidth = nil
        return
    end

    local run = self.run
    if not run then
        local noRunText = GetString(SI_DUNGEON_SCORES_HUD_NO_RUN)
        local screenWidth = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or HUD_MAX_WIDTH
        if noRunText ~= self.lastHudRenderedText
            or screenWidth ~= self.lastHudRenderedScreenWidth then
            self.hudLabel:SetText(noRunText)
            self:ResizeHudForLocalizedText(screenWidth)
            self.lastHudRenderedText = noRunText
            self.lastHudRenderedScreenWidth = screenWidth
        end
        return
    end

    local endMs = run.completedAtMs or GetGameTimeMilliseconds()
    local elapsed = run.startedAtMs and math.max(0, endMs - run.startedAtMs) or nil
    local zoneConfig = Scoring:GetZoneConfig(run.zoneId) or {}
    local threshold = zoneConfig.speedThresholdMs
    local srText = GetString(SI_DUNGEON_SCORES_HUD_UNKNOWN)
    if threshold and elapsed then
        srText = elapsed <= threshold and GetString(SI_DUNGEON_SCORES_YES)
            or GetString(SI_DUNGEON_SCORES_NO)
    end

    local timerText = FormatDurationMs(elapsed)
    if threshold then
        timerText = string.format("%s / %s", timerText, FormatDurationMs(threshold))
    end

    local stateText = run.finalized
        and FormatString(
            SI_DUNGEON_SCORES_HUD_FINAL,
            run.settlement and run.settlement.finalScore or 0)
        or (run.completionAchieved and GetString(SI_DUNGEON_SCORES_HUD_COMPLETED_OPEN)
            or (run.completionCandidateAtMs and GetString(SI_DUNGEON_SCORES_HUD_PENDING)
                or (run.startedAtMs and GetString(SI_DUNGEON_SCORES_HUD_RUNNING)
                    or GetString(SI_DUNGEON_SCORES_HUD_ARMED))))

    -- ESO's localized formatter does not reliably retain a long substitution
    -- list. Format each HUD row independently so later fields cannot disappear
    -- when an earlier row exhausts the formatter's argument surface.
    local hmSupported = type(Scoring.IsTrifectaSupported) == "function"
        and Scoring:IsTrifectaSupported(run.zoneId) == true
    local bossRow = hmSupported
        and FormatString(
            SI_DUNGEON_SCORES_HUD_BOSSES,
            tonumber(run.bossKills) or 0,
            tonumber(run.bossEncountersObserved) or 0,
            tonumber(run.hmBossKills) or 0,
            self:GetActiveHMCount())
        or FormatString(
            SI_DUNGEON_SCORES_HUD_BOSSES_NO_HM,
            tonumber(run.bossKills) or 0,
            tonumber(run.bossEncountersObserved) or 0)
    local rows = {
        FormatString(
            SI_DUNGEON_SCORES_HUD,
            GetCurrentZoneDisplayName(run)),
        FormatString(
            SI_DUNGEON_SCORES_HUD_EVENT,
            self:GetRunningEventScore(),
            tonumber(run.xpKills) or 0,
            tonumber(run.noXpDeaths) or 0),
        bossRow,
    }
    if not hmSupported and type(Scoring.GetCurrentSpeedBonusTarget) == "function" then
        local targetMs, availablePoints = Scoring:GetCurrentSpeedBonusTarget(zoneConfig, elapsed)
        rows[#rows + 1] = targetMs
            and FormatString(
                SI_DUNGEON_SCORES_HUD_SPEED_TARGET,
                ZO_CommaDelimitNumber(tonumber(availablePoints) or 0),
                FormatDurationMs(targetMs))
            or GetString(SI_DUNGEON_SCORES_HUD_SPEED_TARGET_EXPIRED)
    end
    rows[#rows + 1] = FormatString(
        SI_DUNGEON_SCORES_HUD_STATUS,
        tonumber(run.deaths) or 0,
        Scoring:GetVitalityScore(tonumber(run.deaths) or 0),
        srText)
    rows[#rows + 1] = FormatString(
        SI_DUNGEON_SCORES_HUD_TIMER,
        timerText,
        stateText)
    local text = table.concat(rows, "\n")
    local screenWidth = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or HUD_MAX_WIDTH
    if text == self.lastHudRenderedText and screenWidth == self.lastHudRenderedScreenWidth then
        return
    end
    self.hudLabel:SetText(text)
    self:ResizeHudForLocalizedText(screenWidth)
    self.lastHudRenderedText = text
    self.lastHudRenderedScreenWidth = screenWidth
end

function DS:ShowFinalScoreNotification(settlement)
    if not settlement or not self.saved or not self.saved.settings
        or self.saved.settings.showFinalScoreNotification == false then
        return false
    end

    local announce = CENTER_SCREEN_ANNOUNCE
    if not announce or not announce.CreateMessageParams or not CSA_CATEGORY_LARGE_TEXT then
        return false
    end

    local params = announce:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, nil)
    if not params or not params.SetText then
        return false
    end

    local scoreText = ZO_CommaDelimitNumber(tonumber(settlement.finalScore) or 0)
    local vitalityScoreText = ZO_CommaDelimitNumber(tonumber(settlement.vitalityScore) or 0)
    local startingVitality = tonumber(Data.SCORING and Data.SCORING.vitalityStartingLives) or 16
    local remainingVitality = math.max(0, startingVitality - (tonumber(settlement.deaths) or 0))
    local dungeonName = GetCurrentZoneDisplayName(settlement)
    if dungeonName == "" then
        dungeonName = GetString(SI_DUNGEON_SCORES_DUNGEON_FALLBACK)
    end
    dungeonName = zo_strupper and zo_strupper(dungeonName) or string.upper(dungeonName)
    local difficultyText = settlement.isVeteran
        and GetString(SI_DUNGEON_SCORES_VETERAN_SUFFIX) or ""
    local headlineId = (settlement.runOutcome == "abandoned" or settlement.abandoned == true)
        and SI_DUNGEON_SCORES_ABANDONED_HEADLINE
        or SI_DUNGEON_SCORES_COMPLETED_HEADLINE
    local headline = FormatString(
        headlineId,
        dungeonName,
        difficultyText)
    local summary = FormatString(
        SI_DUNGEON_SCORES_COMPLETED_SUMMARY,
        scoreText,
        FormatDurationMs(settlement.elapsedMs),
        vitalityScoreText,
        remainingVitality
    )
    if params.SetCSAType and CENTER_SCREEN_ANNOUNCE_TYPE_RAID_TRIAL then
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_RAID_TRIAL)
    end
    params:SetText(headline, summary)
    if params.SetLifespanMS then
        params:SetLifespanMS(7000)
    end
    if params.MarkSuppressIconFrame then
        params:MarkSuppressIconFrame()
    end

    -- Queue rather than force-display so a Dungeon Scores result does not stomp
    -- a higher-priority encounter/system announcement that is already on screen.
    if announce.QueueMessage then
        announce:QueueMessage(params)
    elseif announce.AddMessageWithParams then
        announce:AddMessageWithParams(params)
    else
        return false
    end
    return true
end
