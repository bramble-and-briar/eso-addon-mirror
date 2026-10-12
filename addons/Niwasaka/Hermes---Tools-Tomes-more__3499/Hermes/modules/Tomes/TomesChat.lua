local Hermes = _G["Hermes"]

local res = HermesMediaRes

local pendingClaims = {}

function Hermes.GetTomeRewards(index)
    local reward = ""

    for rewardIndex = 1, GetNumTimedActivityRewards(index) do
        local rewardId, quantity = GetTimedActivityRewardInfo(index, rewardIndex)
        local rewardType = GetRewardType(rewardId)

        if rewardType == REWARD_ENTRY_TYPE_ADD_CURRENCY then
            local currencyType = GetAddCurrencyRewardInfo(rewardId)
            local currencyIcon = GetCurrencyLootKeyboardIcon(currencyType)
            reward = string.format("%s+%s |t15:15:%s|t", reward, quantity, currencyIcon)
        end
    end

    return reward
end

local function getTomeRunText(index)
    local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)
    if totalNumTimesClaimable <= 1 then
        return ""
    end

    local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)
    if numTimesClaimed > totalNumTimesClaimable then
        numTimesClaimed = totalNumTimesClaimable
    end

    return string.format(" - %d/%d", numTimesClaimed, totalNumTimesClaimable)
end

local function printTomeProgress(index, currentProgress)
    local activityType = GetTimedActivityType(index)
    if activityType ~= TIMED_ACTIVITY_TYPE_WEEKLY and activityType ~= TIMED_ACTIVITY_TYPE_SEASONAL then
        return
    end

    local name = GetTimedActivityName(index)
    local maxProgress = GetTimedActivityMaxProgress(index)
    local reward = Hermes.GetTomeRewards(index)
    local runText = getTomeRunText(index)
    local messageComplete = ""
    local message
    local color
    local progressText

    if currentProgress >= maxProgress then
        progressText = res.IconCheck
    else
        progressText = string.format("%d/%d", currentProgress, maxProgress)
    end

    if activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
        color = Hermes.db.tomeColorSeasonal
    else
        color = Hermes.db.tomeColorWeekly
    end

    if currentProgress >= maxProgress then
        if Hermes.db.showTomeReward == false then
            if reward ~= "" then
                messageComplete = " " .. reward
            end
        else
            if reward ~= "" then
                messageComplete = " " .. res.Ccolor1 .. "[" .. reward .. "]"
            end
        end
    end

    message = color .. " " .. name .. " [" .. progressText .. runText .. "]" .. messageComplete .. "|r"

    if Hermes.db.locationTomeAlert == 0 then
        CHAT_ROUTER:AddSystemMessage(message)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, message)
    end
end

local function tryClaimAvailableTomeRewards()
    if not IsTimedActivitySystemAvailable() or not Hermes.db.enableTomeAutoClaim then
        return
    end

    local now = GetGameTimeMilliseconds()
    local numTimedActivities = GetNumTimedActivities()

    for index = 1, numTimedActivities do
        local activityType = GetTimedActivityType(index)

        if activityType == TIMED_ACTIVITY_TYPE_WEEKLY or activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
            local currencyType = GetTimedActivityCurrencyRewardInfo(index)

            if currencyType == CURT_TOME_POINTS then
                local progress = GetTimedActivityProgress(index)
                local maxProgress = GetTimedActivityMaxProgress(index)
                local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)
                local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)

                local canClaim = maxProgress > 0
                        and progress >= maxProgress
                        and totalNumTimesClaimable > 0
                        and numTimesClaimed < totalNumTimesClaimable

                if canClaim then
                    local lastTry = pendingClaims[index] and pendingClaims[index].startedAt or 0

                    if now - lastTry > 1500 then
                        pendingClaims[index] = {
                            startedAt = now,
                            numTimesClaimed = numTimesClaimed,
                        }

                        ClaimTimedActivityReward(index)
                    end
                end
            end
        end
    end
end

function Hermes.TomeProgressUpdate(_, index, previousProgress, currentProgress)
    local activityType = GetTimedActivityType(index)
    if activityType ~= TIMED_ACTIVITY_TYPE_WEEKLY and activityType ~= TIMED_ACTIVITY_TYPE_SEASONAL then
        return
    end

    local maxProgress = GetTimedActivityMaxProgress(index)

    if activityType == TIMED_ACTIVITY_TYPE_SEASONAL and not Hermes.db.showSeasonalTomeProgress then
        if currentProgress < maxProgress then
            return
        end
    end

    if currentProgress >= maxProgress then
        if Hermes.db.enableTomeAutoClaim then
            Hermes.Debounce("HermesTomeAutoClaim", 300, function()
                tryClaimAvailableTomeRewards()
            end)
        elseif Hermes.db.enableTomeAlert then
            printTomeProgress(index, currentProgress)
        end
        return
    end

    if not Hermes.db.enableTomeAlert then
        return
    end

    if previousProgress and previousProgress >= maxProgress and currentProgress == 0 then
        return
    end

    if currentProgress <= 0 then
        return
    end

    Hermes.Debounce("HermesTomeProgressUpdate" .. index, 500, function()
        printTomeProgress(index, currentProgress)
    end)
end

function Hermes.TomeCurrencyUpdate(_, currencyType, currencyLocation)
    if currencyLocation ~= CURRENCY_LOCATION_ACCOUNT then
        return
    end

    if currencyType ~= CURT_TOME_POINTS then
        return
    end

    if next(pendingClaims) == nil then
        return
    end

    local now = GetGameTimeMilliseconds()

    for index, claimData in pairs(pendingClaims) do
        if now - claimData.startedAt > 4000 then
            pendingClaims[index] = nil
        else
            local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)

            if numTimesClaimed > claimData.numTimesClaimed then
                if Hermes.db.enableTomeAlert then
                    local maxProgress = GetTimedActivityMaxProgress(index)
                    printTomeProgress(index, maxProgress)
                end

                pendingClaims[index] = nil
            end
        end
    end
end

function Hermes.TomePlayerActivated()
    if not Hermes.db.enableTomeAutoClaim then
        return
    end

    Hermes.Debounce("HermesTomePlayerActivated", 1500, function()
        tryClaimAvailableTomeRewards()
    end)
end

function Hermes:InitializeTomeAlerts()
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, self.TomeProgressUpdate)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomeCurrency", EVENT_CURRENCY_UPDATE, self.TomeCurrencyUpdate)
    EVENT_MANAGER:RegisterForEvent(self.name .. "TomePlayerActivated", EVENT_PLAYER_ACTIVATED, self.TomePlayerActivated)
end
