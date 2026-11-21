KyzderpsDerps = KyzderpsDerps or {}
KyzderpsDerps.Tomes = {}
local Tomes = KyzderpsDerps.Tomes


---------------------------------------------------------------------
local ACTIVITY_TYPE = {
    [TIMED_ACTIVITY_TYPE_DAILY] = "DAILY",
    [TIMED_ACTIVITY_TYPE_SEASONAL] = "SEASONAL",
    [TIMED_ACTIVITY_TYPE_WEEKLY] = "WEEKLY",
}

local DIFFICULTY = {
    [TIMED_ACTIVITY_DIFFICULTY_EASY] = "EASY",
    [TIMED_ACTIVITY_DIFFICULTY_HARD] = "HARD",
    [TIMED_ACTIVITY_DIFFICULTY_MEDIUM] = "MEDIUM",
    [TIMED_ACTIVITY_DIFFICULTY_VERY_EASY] = "VERY_EASY",
    [TIMED_ACTIVITY_DIFFICULTY_VERY_HARD] = "VERY_HARD",
}


---------------------------------------------------------------------
local function RefreshLabels()
    if (TIMED_ACTIVITIES_KEYBOARD:GetCurrentActivityType() ~= TIMED_ACTIVITY_TYPE_WEEKLY) then
        for i = 1, ZO_TimedActivities_KeyboardTLContentListContainerListContents:GetNumChildren() do
            local control = ZO_TimedActivities_KeyboardTLContentListContainerListContents:GetNamedChild("1Control" .. i)
            if (control) then
                local label = control:GetNamedChild("KDDLabel")
                if (label) then
                    label:SetHidden(true)
                end
            end
        end
        local totalLabel = ZO_TimedActivities_KeyboardTLContentListContainer:GetNamedChild("KDDLabel")
        if (totalLabel) then
            totalLabel:SetHidden(true)
        end
        return
    end

    KyzderpsDerps:dbg("Refreshing weekly challenge labels")
    local totalClaimable = 0
    for i = 1, GetNumTimedActivities() do
        -- KyzderpsDerps:dbg(GetTimedActivityName(i) .. ACTIVITY_TYPE[GetTimedActivityType(i)] .. DIFFICULTY[GetTimedActivityDifficulty(i)])
        if (GetTimedActivityType(i) == TIMED_ACTIVITY_TYPE_WEEKLY) then
            local control = ZO_TimedActivities_KeyboardTLContentListContainerListContents:GetNamedChild("1Control" .. i)
            if (control) then
                local label = control:GetNamedChild("KDDLabel")
                if (not label) then
                    label = WINDOW_MANAGER:CreateControl("$(parent)KDDLabel", control, CT_LABEL)
                    label:SetFont("ZoFontGameBold")
                    label:SetAnchor(TOPRIGHT, control, TOPRIGHT, -4, 4)
                    label:SetHorizontalAlignment(RIGHT)
                end

                local timesClaimed = GetTimedActivityNumTimesClaimed(i)
                local timesClaimable = GetTimedActivityTotalNumTimesClaimable(i)
                local currencyType, quantity = GetTimedActivityCurrencyRewardInfo(i)
                local currencyIcon = GetCurrencyKeyboardIcon(currencyType)

                local claimableCurrency = (timesClaimable - timesClaimed) * quantity
                if (currencyType == CURT_TOME_POINTS) then
                    totalClaimable = totalClaimable + claimableCurrency
                end
                local totalCurrency = timesClaimable * quantity
                local color = "00FF00"
                if (totalCurrency <= 400) then
                    color = "FF0000"
                elseif (totalCurrency < 450) then
                    color = "FF9900"
                elseif (totalCurrency < 500) then
                    color = "FFFF00"
                end


                -- label:SetText(string.format("Total: |c%s%d |t100%%:100%%:%s|t|r",
                --     color,
                --     totalCurrency,
                --     currencyIcon))
                label:SetText(string.format("Remaining: %d |t100%%:100%%:%s|t / |c%s%d |t100%%:100%%:%s|t|r",
                    (timesClaimable - timesClaimed) * quantity,
                    currencyIcon,
                    color,
                    totalCurrency,
                    currencyIcon))
                label:SetHidden(false)
            end
        end
    end

    local frame = ZO_TimedActivities_KeyboardTLContentListContainer
    local label = frame:GetNamedChild("KDDLabel")
    if (not label) then
        label = WINDOW_MANAGER:CreateControl("$(parent)KDDLabel", frame, CT_LABEL)
        label:SetFont("ZoFontGameBold")
        label:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -4, -4)
        label:SetHorizontalAlignment(RIGHT)
    end
    local currencyIcon = GetCurrencyKeyboardIcon(CURT_TOME_POINTS)
    label:SetText(string.format("Remaining claimable: %d |t100%%:100%%:%s|t", totalClaimable, currencyIcon))
    label:SetHidden(false)
end

local hooked = false
function Tomes.Initialize()
    if (hooked) then return end
    ZO_PostHook(TIMED_ACTIVITIES_KEYBOARD, "RefreshList", RefreshLabels)
    hooked = true
end

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
function Tomes.GetSettings()
    return {
        type = "checkbox",
        name = "Show Tome weekly challenge totals",
        tooltip = "Shows color-coded numbers for how many total tome points a weekly challenge awards, the remaining you can obtain, and the total for all weekly challenges. NOTE: Requires a reload to turn OFF!",
        default = false,
        getFunc = function() return KyzderpsDerps.savedOptions.tomes.enableTotals end,
        setFunc = function(value)
            KyzderpsDerps.savedOptions.tomes.enableTotals = value
            if (value) then
                Tomes.Initialize()
            end
        end,
        width = "full",
    }
end
