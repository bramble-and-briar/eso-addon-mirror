local QTI = QuestTrackerImproved

function QTI.ApplyAchievementStyle()
    local tracker = ACHIEVEMENT_TRACKER

    local header = tracker.headerLabel
    header:SetFont(QTI.GetFont(QTI.SV.achievementHeaderFont, QTI.SV.achievementHeaderSize, QTI.SV.achievementHeaderStyle))
    QTI.ApplyControlColor(header, QTI.SV.achievementHeaderColor)
    header:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    header:SetWidth(QTI.SV.achievementWidth)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, tracker.container, TOPLEFT, 0, 0)

    local sub = tracker.subLabel
    sub:SetFont(QTI.GetFont(QTI.SV.achievementSubLabelFont, QTI.SV.achievementSubLabelSize, QTI.SV.achievementSubLabelStyle))
    QTI.ApplyControlColor(sub, QTI.SV.achievementSubLabelColor)
    sub:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    sub:SetWidth(QTI.SV.achievementWidth)
    sub:ClearAnchors()
    sub:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 5)

    local icon = tracker.headerIcon
    icon:ClearAnchors()
    icon:SetAnchor(RIGHT, header, LEFT, -2, 0)

    for _, label in tracker.criteriaLabelPool:ActiveAndFreeObjectIterator() do
        label:SetFont(QTI.GetFont(QTI.SV.achievementCriteriaFont, QTI.SV.achievementCriteriaSize, QTI.SV.achievementCriteriaStyle))
        QTI.ApplyControlColor(label, QTI.SV.achievementCriteriaColor)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetWidth(QTI.SV.achievementWidth)
    end

    for _, progressBar in tracker.criteriaProgressPool:ActiveAndFreeObjectIterator() do
        progressBar:SetWidth(QTI.SV.achievementWidth)
    end

    tracker.assistedKeybindButton:ClearAnchors()
    tracker.assistedKeybindButton:SetAnchor(LEFT, header, RIGHT, 5, 0)

    QTI.ResizeAchievementPanel()
end

function QTI.ResizeAchievementPanel()
    ACHIEVEMENT_TRACKER.container:SetWidth(QTI.SV.achievementWidth)
end

function QTI.ApplyAchievementIcon()
    local achievementId = GetTrackedAchievement()
    if achievementId <= 0 then return end

    local name, _, _, icon = GetAchievementInfo(achievementId)
    local size = QTI.SV.achievementIconSize
    ACHIEVEMENT_TRACKER:SetSubLabelText(string.format("|t%d:%d:%s|t %s", size, size, icon, name))
end

function QTI.HookAchievementTracker()
    ZO_PreHook(ZO_AchievementTracker, "AddCriteria", function(self, text, addBullet)
        local label = self.criteriaLabelPool:AcquireObject()
        if addBullet then
            zo_bulletFormat(label, text)
        else
            label:SetText(text)
        end
        label:SetFont(QTI.GetFont(QTI.SV.achievementCriteriaFont, QTI.SV.achievementCriteriaSize, QTI.SV.achievementCriteriaStyle))
        QTI.ApplyControlColor(label, QTI.SV.achievementCriteriaColor)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetWidth(QTI.SV.achievementWidth)
        label:SetAnchor(TOPLEFT, self.nextCriteriaAnchorRelativeTo, BOTTOMLEFT, 0, self.currentStyle.CRITERIA_LABEL_PADDING)
        self.nextCriteriaAnchorRelativeTo = label
        return true
    end)

    ZO_PreHook(ZO_AchievementTracker, "AddBulletedDescription", function(self, description)
        self:AddCriteria(description, true)
        return true
    end)

    ZO_PreHook(ZO_AchievementTracker, "AddProgressBar", function(self, numCompleted, numRequired, description)
        self:AddBulletedDescription(description)

        local progressBar = self.criteriaProgressPool:AcquireObject()
        progressBar:SetMinMax(0, numRequired)
        progressBar:SetValue(numCompleted)

        local USE_LOWERCASE_NUMBER_SUFFIXES = false
        local ROUND_TO_ZERO = true
        local numCompletedAbbreviated = ZO_AbbreviateAndLocalizeNumber(numCompleted, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES, ROUND_TO_ZERO)
        local numRequiredAbbreviated = ZO_AbbreviateAndLocalizeNumber(numRequired, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES, ROUND_TO_ZERO)

        progressBar.progressBarLabel:SetText(zo_strformat(SI_CURRENT_AND_MAX_VALUES_FORMATTER, numCompletedAbbreviated, numRequiredAbbreviated))
        progressBar:SetWidth(QTI.SV.achievementWidth)
        progressBar:SetAnchor(TOPLEFT, self.nextCriteriaAnchorRelativeTo, BOTTOMLEFT, 0, self.currentStyle.CRITERIA_LABEL_PADDING)

        self.nextCriteriaAnchorRelativeTo = progressBar
        return true
    end)

    ZO_PostHook(ZO_AchievementTracker, "Update", function(self)
        QTI.ApplyAchievementIcon()
        QTI.ApplyAchievementStyle()
    end)

    ZO_PostHook(ZO_AchievementTracker, "ApplyPlatformStyle", QTI.ApplyAchievementStyle)
end