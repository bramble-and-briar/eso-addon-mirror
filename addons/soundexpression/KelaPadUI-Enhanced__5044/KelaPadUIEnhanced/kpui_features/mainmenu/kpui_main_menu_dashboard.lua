-- KelaPadUI main-menu daily dashboard
-- Passive information panel shown beside the gamepad main menu.
-- Text uses the same off-white/white palette as the additional companion
-- information tooltip so the dashboard matches the existing KelaPadUI style.

local colors = kpuiConst.Colors
local DASHBOARD_COLOR_TITLE = colors.COLOR_WHITE
local DASHBOARD_COLOR_SECTION = colors.COLOR_GOLD -- colors.COLOR_OFF_WHITE
local DASHBOARD_COLOR_LABEL = colors.GENERAL_COLOR_NORMAL
local DASHBOARD_COLOR_VALUE = colors.COLOR_WHITE

local DASHBOARD_SETTING = KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD
local DASHBOARD_UPDATE_NAME = "KelaPadUI_MainMenuDashboard"
-- A light poll watches the panel's visibility: the dashboard is filled every
-- time the gamepad main menu is pulled up, so nothing is fetched while it is
-- hidden.
local DASHBOARD_VISIBILITY_POLL_INTERVAL = 1000
-- One 32px row of extra breathing room plus the previous 10px gap.
local DASHBOARD_SECTION_GAP = 42
-- The reset countdown only needs minute precision; refresh it about once a
-- minute while the panel stays open instead of rescanning the journal.
local DASHBOARD_RESET_UPDATE_POLLS = 60
local DASHBOARD_CONTENT_OFFSET_Y = 124
local MAX_PVP_RANK = 50
local MAX_CHAMPION_POINTS = 3600

local dashboardRows = {}
local dashboardSections = {}
local eventRows = {}
local visibleEventCount = 0
local built = false
local dashboardWasVisible = false
local fragment = nil
local unavailableText = ""
local titleControl = nil
-- Rows whose value carries a countdown.  Re-rendered by the per-minute tick so
-- the times keep ticking while the panel stays open.
local countdownRows = {}
local skillPointsRow = nil
-- Values the rows compute but do not display yet, kept so a later change can
-- render them without re-deriving anything.  Live data only, never persisted.
--   tomes:     { tier, totalTiers, pointsToNextTier }
--   veterancy: { rank, numRanks, rankPoints, rankPointsTotal, percent }
local eventDetail = {}

-- The controls in kpui_main_menu_dashboard.xml all bind a color through the
-- `color="INTERFACE_COLOR_TYPE_TEXT_COLORS:..."` XML attribute.  A bound color is
-- re-applied by the client, which overrides any SetColor the add-on calls, so
-- every colored string is driven through inline markup instead.  A ZO_ColorDef
-- already knows how to produce that markup.
local function Colorize(color, text)
    if not color or not text then
        return text
    end
    return "|c" .. color:ToHex() .. tostring(text) .. "|r"
end

local function GetTimeText(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end

    if ZO_FormatTimeLargestTwo then
        return ZO_FormatTimeLargestTwo(seconds, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL)
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%d:%02d", hours, minutes)
    end
    return string.format("%d min", minutes)
end

-- Events and research rows read "level / total - time left".  The count keeps
-- the dashboard's usual completion color and the countdown is always gold.  A
-- nil color leaves the inline markup alone; the caller passes that through.
local function FormatProgressWithCountdown(countText, countColor, seconds)
    local text = Colorize(countColor, countText)
    local timeText = GetTimeText(seconds)
    if timeText then
        text = text .. " - " .. Colorize(colors.COLOR_GOLD, timeText)
    end
    return text
end

-- Single place that turns a row's value provider into the value label's text,
-- shared by the full refresh and the per-minute tick.
local function SetRowValueControl(row)
    -- `row.getValue and row.getValue()` would truncate the color away: an `and`
    -- expression only keeps the first result of the call.
    local value, color
    if row.getValue then
        value, color = row.getValue()
    end
    row.valueControl:SetText(Colorize(color, value) or unavailableText)
end

-- The activity finder manager only tracks queue and desertion cooldowns, so the
-- daily reward state has to come from the cooldown API itself: a remaining time
-- means today's reward was already granted.
local function GetRewardCooldownText(cooldownType)
    if not cooldownType or not GetLFGCooldownTimeRemainingSeconds then
        return nil
    end

    local remaining = GetLFGCooldownTimeRemainingSeconds(cooldownType)
    if remaining and remaining > 0 then
        return GetString(KELA_DASHBOARD_VALUE_COMPLETE), colors.COLOR_LIGHT_GREEN
    end

    return GetString(KELA_DASHBOARD_VALUE_READY), DASHBOARD_COLOR_VALUE
end

-- Daily quest state.  The journal only reports quests that are still held, and
-- a turned-in daily quest moves into the permanent completed-quest archive,
-- which has no completion date.  Counting that archive made the writ, archive,
-- and pledge rows saturate.  Instead, remember the quests turned in today per
-- character and clear them when the daily reset rolls over.
local WRIT_TOTAL = 7
local ARCHIVE_TOTAL = 2
local PLEDGE_TOTAL = 3
local ARCHIVE_ZONE_ID = 1436
local DAILY_WRITS_SAVED_KEY = "dailyWrits"
local DAILY_ARCHIVE_SAVED_KEY = "dailyArchive"
local DAILY_PLEDGES_SAVED_KEY = "dailyPledges"
local DAILY_RESET_OFFSET_SAVED_KEY = "dailyResetOffset"
-- Snap a computed boundary to the nearest five minutes.  The login-reward timer
-- and GetTimeStamp() are truncated independently, so their sum can wobble by a
-- second across calls for the same real boundary; snapping absorbs that before
-- it can ever look like a different day.  Real reset boundaries are whole hours.
local DAILY_RESET_SNAP = 300
-- A fresh boundary this much earlier than the stored one is a genuine source
-- disagreement (wrong hour, or a stale fallback), not clock jitter: adopt it and
-- keep today's set.  Smaller differences are treated as jitter and ignored.
local DAILY_RESET_ADOPT_MARGIN = 1800
-- A stored boundary further ahead than this is corrupt; never hold a row open.
local DAILY_RESET_MAX_AHEAD = 172800
-- Last-resort hour (UTC) for NA.  Only used until a real source has been read
-- once and learned the region's actual reset time-of-day.
local DAILY_RESET_FALLBACK_HOUR_UTC = 10
local PLEDGE_LABEL_INDENT = "    "

local dailyJournal = { writs = 0, writIds = {}, archive = 0, archiveIds = {}, pledges = {} }
local todaysPledges = {}
local dailyWritState = nil
local dailyArchiveState = nil
local dailyPledgeState = nil
local dailyResetKey = nil
local dailyResetSeconds = nil
local dailyResetValueControl = nil
local dashboardPollCount = 0

local function GetPledgeDungeon(questName)
    return string.match(questName or "", "^Pledge: (.+)$")
end

-- The daily reset boundary.  GetTimedActivityTypeResetTimeS returns 0 on some
-- realms, so the daily-login-reward timer is the primary source: a remaining
-- time means today's reward is still claimable and the boundary is the next
-- line-hour boundary at that same time of day.  A positive reading is learned
-- once into `dailyResetOffset` (seconds since 00:00 UTC, snapped), which keeps
-- the boundary correct on every later call even when the timer reads 0.  The
-- hardcoded hour is only a last resort before anything has been learned.
local function SnapResetBoundary(seconds)
    return math.floor(seconds / DAILY_RESET_SNAP + 0.5) * DAILY_RESET_SNAP
end

local function GetLearnedResetOffset()
    if type(kpuiSavedVariables) ~= "table" then
        return nil
    end
    local offset = kpuiSavedVariables[DAILY_RESET_OFFSET_SAVED_KEY]
    if type(offset) == "number" and offset >= 0 and offset < 86400 then
        return offset
    end
    return nil
end

-- Learn the reset time-of-day from the first valid positive reading so the
-- boundary stays correct on realms where the fallback hour is wrong.
local function RememberResetOffset(boundary)
    if type(kpuiSavedVariables) ~= "table" then
        return
    end
    local offset = SnapResetBoundary(boundary % 86400)
    if offset == 86400 then
        offset = 0
    end
    if offset ~= kpuiSavedVariables[DAILY_RESET_OFFSET_SAVED_KEY] then
        kpuiSavedVariables[DAILY_RESET_OFFSET_SAVED_KEY] = offset
    end
end

local function NextBoundaryFromOffset(now, offset)
    return (math.floor((now - offset) / 86400) + 1) * 86400 + offset
end

-- Returns the freshly computed boundary (absolute seconds), the raw source
-- values for diagnostics, and the seconds remaining.
local function ComputeResetBoundary(now)
    if not now or now <= 0 then
        now = GetTimeStamp and GetTimeStamp() or 0
    end

    local timedReset = 0
    if GetTimedActivityTypeResetTimeS and TIMED_ACTIVITY_TYPE_DAILY then
        local ok, resetTime = pcall(GetTimedActivityTypeResetTimeS, TIMED_ACTIVITY_TYPE_DAILY)
        if ok and type(resetTime) == "number" then
            timedReset = resetTime
        end
    end

    local loginRemaining = 0
    if GetTimeUntilNextDailyLoginRewardClaimS then
        local ok, remaining = pcall(GetTimeUntilNextDailyLoginRewardClaimS)
        if ok and type(remaining) == "number" then
            loginRemaining = remaining
        end
    end

    local learned = GetLearnedResetOffset()
    local boundary = nil
    if loginRemaining > 0 then
        boundary = SnapResetBoundary(now + loginRemaining)
        RememberResetOffset(boundary)
    elseif timedReset > now then
        boundary = SnapResetBoundary(timedReset)
        RememberResetOffset(boundary)
    elseif learned then
        boundary = NextBoundaryFromOffset(now, learned)
    else
        boundary = NextBoundaryFromOffset(now, DAILY_RESET_FALLBACK_HOUR_UTC * 3600)
    end

    return boundary, now, timedReset, loginRemaining, learned
end

-- The stored boundary is authoritative: today's set is cleared only once that
-- boundary has actually passed.  Recomputing one of the sources can shave a
-- minute off across calls, so a stored boundary is never discarded just because
-- a fresh reading disagrees with it.  A much earlier fresh boundary - a real
-- disagreement, such as a fallback hour for the wrong region - is adopted
-- without dropping the set.
local function ResolveDailyBoundary(storedBoundary, freshBoundary, now)
    if type(storedBoundary) ~= "number" or storedBoundary <= now
        or storedBoundary > now + DAILY_RESET_MAX_AHEAD then
        return freshBoundary, true
    end
    if freshBoundary and freshBoundary > now
        and freshBoundary < storedBoundary - DAILY_RESET_ADOPT_MARGIN then
        return freshBoundary, false
    end
    return storedBoundary, false
end

local function GetCurrentDailyPeriod()
    local now = GetTimeStamp and GetTimeStamp() or 0
    local boundary = ComputeResetBoundary(now)
    local resolved = ResolveDailyBoundary(dailyResetKey, boundary, now)
    dailyResetKey = resolved
    return resolved, now, boundary
end

-- Every per-character lookup needs the same stable key.  The populate pass can
-- run before a character is fully loaded, so a missing id returns nil rather
-- than a junk entry.
local function GetCharacterKey()
    local characterId = (GetCurrentCharacterId and GetCurrentCharacterId())
        or (GetUnitName and GetUnitName("player"))
        or nil
    if not characterId or characterId == "" or characterId == 0 then
        return nil
    end
    return characterId
end

local function GetDailyState(savedKey, now, freshBoundary)
    if type(kpuiSavedVariables) ~= "table" then
        return nil
    end

    local characterId = GetCharacterKey()
    -- The populate pass can run before a character is fully loaded; never write a
    -- junk per-character entry for a missing id.
    if not characterId then
        return nil
    end
    if not now then
        local boundary, freshNow = GetCurrentDailyPeriod()
        now = freshNow
        freshBoundary = freshBoundary or boundary
    end
    if not freshBoundary then
        freshBoundary = ComputeResetBoundary(now)
    end

    local allCharacters = kpuiSavedVariables[savedKey]
    if type(allCharacters) ~= "table" then
        allCharacters = {}
        kpuiSavedVariables[savedKey] = allCharacters
    end

    local state = allCharacters[characterId]
    local stored = type(state) == "table" and state.resetAt or nil
    local resolved, stale = ResolveDailyBoundary(stored, freshBoundary, now)
    if type(state) ~= "table" or stale or type(state.ids) ~= "table" then
        state = { resetAt = resolved, ids = {} }
        allCharacters[characterId] = state
    elseif state.resetAt ~= resolved then
        state.resetAt = resolved
    end
    return state
end

local function IsDailyQuest(questId)
    if not questId or questId == 0 or not GetQuestRepeatableType then
        return false
    end
    return GetQuestRepeatableType(questId) == QUEST_REPEAT_DAILY
end

local function IsDailyCraftingWritQuest(questId)
    if not IsDailyQuest(questId) then
        return false
    end

    local questType = GetQuestType and GetQuestType(questId)
    if questType == QUEST_TYPE_CRAFTING then
        return true
    end

    -- The quest has just left the journal when EVENT_QUEST_REMOVED fires.  If
    -- the live type is not readable yet, the completed archive has the same
    -- quest type.
    if GetCompletedQuestInfo then
        local ok, _, completedType = pcall(GetCompletedQuestInfo, questId)
        return ok and completedType == QUEST_TYPE_CRAFTING
    end
    return false
end

local function IsDailyUndauntedPledgeQuest(questId)
    if not IsDailyQuest(questId) then
        return false
    end

    local questType = GetQuestType and GetQuestType(questId)
    if questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
        return true
    end

    if GetCompletedQuestInfo then
        local ok, _, completedType = pcall(GetCompletedQuestInfo, questId)
        return ok and completedType == QUEST_TYPE_UNDAUNTED_PLEDGE
    end
    return false
end

local function IsDailyArchiveQuest(questId)
    if not IsDailyQuest(questId) then
        return false
    end
    return GetQuestZoneId and GetQuestZoneId(questId) == ARCHIVE_ZONE_ID
end

-- One journal pass collects all three rows.  GetJournalQuestInfo already
-- carries the quest type, completion flag, and pledge tracker override, so the
-- dashboard only asks for repeat/zone/id on the quests that need them.
local function ScanJournalDailyQuests()
    local data = { writs = 0, writIds = {}, archive = 0, archiveIds = {}, pledges = {} }
    for i = 1, GetNumJournalQuests() do
        local name, _, _, _, activeStepTrackerOverrideText, completed, _, _, _, questType = GetJournalQuestInfo(i)
        if questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
            local dungeon = GetPledgeDungeon(name)
            if dungeon then
                if activeStepTrackerOverrideText and activeStepTrackerOverrideText ~= "" then
                    data.pledges[dungeon] = "turnin"
                elseif not data.pledges[dungeon] then
                    data.pledges[dungeon] = "active"
                end
            end
        elseif completed then
            if questType == QUEST_TYPE_CRAFTING then
                if GetJournalQuestRepeatType(i) == QUEST_REPEAT_DAILY then
                    local questId = GetJournalQuestId and GetJournalQuestId(i)
                    if questId and questId ~= 0 then
                        data.writIds[questId] = true
                    end
                    data.writs = data.writs + 1
                end
            elseif GetJournalQuestRepeatType(i) == QUEST_REPEAT_DAILY
                and GetJournalQuestZoneStoryZoneId(i) == ARCHIVE_ZONE_ID then
                local questId = GetJournalQuestId and GetJournalQuestId(i)
                if questId and questId ~= 0 then
                    data.archiveIds[questId] = true
                end
                data.archive = data.archive + 1
            end
        end
    end
    return data
end

local function GetTodayPledges(journal)
    local pledges = KelaGetPledgeReport and KelaGetPledgeReport(true) or {}
    for _, pledge in ipairs(pledges) do
        pledge.state = journal.pledges[pledge.dungeon]
    end
    return pledges
end

local function RefreshDailyQuestData()
    -- One clock reading and one freshly computed boundary for all three rows,
    -- so writs, archive and pledges can never land in different periods.
    local boundary, now = GetCurrentDailyPeriod()
    dailyResetKey = boundary
    dailyResetSeconds = math.max(0, boundary - now)
    dailyWritState = GetDailyState(DAILY_WRITS_SAVED_KEY, now, boundary)
    dailyArchiveState = GetDailyState(DAILY_ARCHIVE_SAVED_KEY, now, boundary)
    dailyPledgeState = GetDailyState(DAILY_PLEDGES_SAVED_KEY, now, boundary)
    dailyJournal = ScanJournalDailyQuests()
    todaysPledges = GetTodayPledges(dailyJournal)
end

local function GetCraftingWritText()
    -- Union the writs still waiting in the journal with the IDs already handed
    -- in today.  A handed-in writ is no longer in the journal, so the union
    -- only guards against the removal event racing the journal update.
    local ids = {}
    for questId in pairs(dailyJournal.writIds) do
        ids[questId] = true
    end
    if dailyWritState then
        for questId in pairs(dailyWritState.ids) do
            ids[questId] = true
        end
    end

    local complete = 0
    for _ in pairs(ids) do
        complete = complete + 1
    end
    if complete == 0 then
        complete = dailyJournal.writs
    end
    complete = math.min(complete, WRIT_TOTAL)

    local text = string.format("%d / %d", complete, WRIT_TOTAL)
    if complete >= WRIT_TOTAL then
        text = Colorize(colors.COLOR_LIGHT_GREEN, text)
    end
    return text
end

local function GetArchiveText()
    -- Same union as the writ row: quests still waiting in the journal plus the
    -- IDs handed in today.  A handed-in quest leaves the journal immediately,
    -- so the union only guards against the removal event racing the scan.
    local ids = {}
    for questId in pairs(dailyJournal.archiveIds) do
        ids[questId] = true
    end
    if dailyArchiveState then
        for questId in pairs(dailyArchiveState.ids) do
            ids[questId] = true
        end
    end

    local complete = 0
    for _ in pairs(ids) do
        complete = complete + 1
    end
    if complete == 0 then
        complete = dailyJournal.archive
    end
    complete = math.min(complete, ARCHIVE_TOTAL)

    local text = string.format("%d / %d", complete, ARCHIVE_TOTAL)
    if complete >= ARCHIVE_TOTAL then
        text = Colorize(colors.COLOR_LIGHT_GREEN, text)
    end
    return text
end

local function GetUndauntedText()
    -- Only handed-in pledges count.  A pledge that is active or ready to turn
    -- in still has to be completed, so it stays out of the X / 3 total.
    local complete = 0
    if dailyPledgeState then
        for _, pledge in ipairs(todaysPledges) do
            if dailyPledgeState.ids[pledge.dungeon] then
                complete = complete + 1
            end
        end
    end
    complete = math.min(complete, PLEDGE_TOTAL)

    local text = string.format("%d / %d", complete, PLEDGE_TOTAL)
    if complete >= PLEDGE_TOTAL then
        text = Colorize(colors.COLOR_LIGHT_GREEN, text)
    end
    return text
end

local function GetPledgeLabel(index)
    local pledge = todaysPledges[index]
    if not pledge then
        return PLEDGE_LABEL_INDENT .. "--"
    end
    return PLEDGE_LABEL_INDENT .. pledge.giver .. " - " .. pledge.dungeon
end

local function GetPledgeStatusText(index)
    local pledge = todaysPledges[index]
    if not pledge then
        return nil
    end

    if dailyPledgeState and dailyPledgeState.ids[pledge.dungeon] then
        return GetString(KELA_DASHBOARD_VALUE_COMPLETE), colors.COLOR_LIGHT_GREEN
    end
    if pledge.state == "turnin" then
        return GetString(KELA_DASHBOARD_VALUE_TURN_IN), colors.COLOR_TEAL
    end
    if pledge.state == "active" then
        return GetString(KELA_DASHBOARD_VALUE_ACTIVE), colors.COLOR_LIGHT_BLUE
    end

    return GetString(KELA_DASHBOARD_VALUE_READY), colors.COLOR_WHITE
end

local function GetDailyResetText()
    local seconds = dailyResetSeconds
    if not seconds then
        -- Live countdown without re-resolving the stored period.
        local boundary = ComputeResetBoundary()
        local now = GetTimeStamp and GetTimeStamp() or 0
        seconds = math.max(0, boundary - now)
    end

    local text = GetTimeText(seconds)
    if text then
        return text .. " " .. GetString(KELA_DASHBOARD_VALUE_LEFT)
    end
    return GetString(KELA_DASHBOARD_VALUE_READY), colors.COLOR_LIGHT_GREEN
end

local function HasPromotionalEventAPI()
    local manager = PROMOTIONAL_EVENT_MANAGER
    return manager ~= nil and manager.GetNumActiveCampaigns ~= nil and manager.GetCampaignDataByIndex ~= nil
end

local function GetGoldenPursuitText()
    if not HasPromotionalEventAPI() then
        return nil
    end

    local manager = PROMOTIONAL_EVENT_MANAGER
    local count = manager:GetNumActiveCampaigns()
    if not count or count <= 0 then
        return GetString(KELA_DASHBOARD_VALUE_NONE_ACTIVE)
    end

    local campaign = manager:GetCampaignDataByIndex(1)
    if not campaign then
        return nil
    end

    if not (campaign.GetNumActivitiesCompleted and campaign.GetCapstoneRewardThreshold) then
        return nil
    end

    local completed = campaign:GetNumActivitiesCompleted()
    local threshold = campaign:GetCapstoneRewardThreshold()
    if not completed or not threshold or threshold <= 0 then
        return nil
    end

    local countText = string.format("%d / %d", completed, threshold)
    local countColor = completed >= threshold and colors.COLOR_LIGHT_GREEN or nil

    local secondsRemaining
    if type(GetSecondsRemainingInPromotionalEventCampaign) == "function" and campaign.GetSecondsRemaining then
        secondsRemaining = campaign:GetSecondsRemaining()
    end

    return FormatProgressWithCountdown(countText, countColor, secondsRemaining)
end

local function HasTamrielTomesAPI()
    local manager = TAMRIEL_TOMES_MANAGER
    local dataClass = ZO_TamrielTomeData
    return manager ~= nil and manager.GetActiveTomeId ~= nil and dataClass ~= nil and dataClass.New ~= nil
end

local function GetTomeData()
    if not HasTamrielTomesAPI() then
        return nil
    end

    local tomeId = TAMRIEL_TOMES_MANAGER:GetActiveTomeId()
    if not tomeId or tomeId == 0 then
        return nil
    end

    local ok, tome = pcall(ZO_TamrielTomeData.New, ZO_TamrielTomeData, tomeId)
    if not ok or not tome then
        return nil
    end
    return tome
end

local function GetTamrielTomesText()
    if not HasTamrielTomesAPI() then
        eventDetail.tomes = nil
        return nil
    end

    local tome = GetTomeData()
    if not tome then
        eventDetail.tomes = nil
        return GetString(KELA_DASHBOARD_VALUE_NONE)
    end

    local tier = tome.GetCurrentTier and tome:GetCurrentTier() or 0
    local total = tome.GetNumTotalTiers and tome:GetNumTotalTiers() or 0
    if total <= 0 then
        eventDetail.tomes = nil
        return GetString(KELA_DASHBOARD_VALUE_NONE)
    end

    -- Collected, not displayed: the points needed for the next tier.
    local pointsToNextTier
    if tier < total and tome.GetCostToProgressToTier then
        local ok, remaining = pcall(tome.GetCostToProgressToTier, tome, tier + 1)
        if ok and type(remaining) == "number" then
            pointsToNextTier = remaining
        end
    end
    eventDetail.tomes = { tier = tier, totalTiers = total, pointsToNextTier = pointsToNextTier }

    local countText = string.format("%d / %d", tier, total)
    local countColor = tier >= total and colors.COLOR_LIGHT_GREEN or nil

    local secondsRemaining
    if type(GetActiveTamrielTomeSeasonEndTimeS) == "function" then
        local endTimeS = GetActiveTamrielTomeSeasonEndTimeS()
        if type(endTimeS) == "number" and endTimeS > 0 then
            local now = GetTimeStamp and GetTimeStamp() or 0
            secondsRemaining = math.max(0, endTimeS - now)
        end
    end

    return FormatProgressWithCountdown(countText, countColor, secondsRemaining)
end

-- The public promotional-campaign API is the only event source add-ons can
-- read.  Golden Pursuit is the primary campaign and has its own progress row,
-- so the dynamic rows list any additional visible campaigns.  If the API is not
-- available, those rows stay hidden.
local function HasPromotionalEventCampaignAPI()
    return type(GetNumActivePromotionalEventCampaigns) == "function"
        and type(GetActivePromotionalEventCampaignKey) == "function"
        and type(GetPromotionalEventCampaignInfo) == "function"
        and type(GetPromotionalEventCampaignDisplayName) == "function"
        and type(GetSecondsRemainingInPromotionalEventCampaign) == "function"
end

-- Returning-player and low-level campaigns are account-specific offers, not
-- shared events, so they do not belong in the event list.
local function IsPersonalEventCampaign(campaignKey)
    if type(IsReturningPlayerPromotionalEventsCampaign) == "function"
        and IsReturningPlayerPromotionalEventsCampaign(campaignKey) then
        return true
    end
    if type(IsLowLevelPlayerPromotionalEventsCampaign) == "function"
        and IsLowLevelPlayerPromotionalEventsCampaign(campaignKey) then
        return true
    end
    return false
end

local function GetActiveEventCampaigns()
    if not HasPromotionalEventCampaignAPI() then
        return nil
    end

    local events = {}
    -- When the Golden Pursuit row is available it already covers campaign 1.
    local skipPrimary = HasPromotionalEventAPI()
        and (PROMOTIONAL_EVENT_MANAGER:GetNumActiveCampaigns() or 0) > 0
    local count = GetNumActivePromotionalEventCampaigns() or 0
    for i = 1, count do
        if not (skipPrimary and i == 1) then
            local campaignKey = GetActivePromotionalEventCampaignKey(i)
            if campaignKey and not IsPersonalEventCampaign(campaignKey) then
                local campaignId = GetPromotionalEventCampaignInfo(campaignKey)
                local name = campaignId and GetPromotionalEventCampaignDisplayName(campaignId)
                if name and name ~= "" then
                    table.insert(events, {
                        name = name,
                        remaining = GetSecondsRemainingInPromotionalEventCampaign(campaignKey),
                    })
                end
            end
        end
    end

    table.sort(events, function(a, b)
        return (a.remaining or math.huge) < (b.remaining or math.huge)
    end)
    return events
end

-- The event rows render the additional active campaigns; the Golden Pursuit
-- row keeps its own progress value.
local function RefreshEvents(events)
    visibleEventCount = 0

    if #eventRows == 0 then
        return
    end

    if not events or #events == 0 then
        for _, row in ipairs(eventRows) do
            row.control:SetHidden(true)
        end
        return
    end

    visibleEventCount = math.min(#events, #eventRows)
    for i, row in ipairs(eventRows) do
        local event = events[i]
        if event then
            local label = event.name
            if i == #eventRows and #events > #eventRows then
                label = string.format("%s +%d", event.name, #events - #eventRows)
            end
            row.labelControl:SetText(Colorize(DASHBOARD_COLOR_LABEL, label))

            local timeText = GetTimeText(event.remaining)
            if not timeText then
                if event.remaining then
                    timeText = GetString(KELA_DASHBOARD_VALUE_ENDING)
                else
                    timeText = GetString(KELA_DASHBOARD_VALUE_ACTIVE)
                end
            end
            row.valueControl:SetText(Colorize(DASHBOARD_COLOR_VALUE, timeText))
            row.control:SetHidden(false)
        else
            row.control:SetHidden(true)
        end
    end
end

local function GetESOPlusText()
    if not IsESOPlusSubscriber then
        return nil
    end

    local active = IsESOPlusSubscriber() and true or false
    return GetString(active and SI_YES or SI_NO), active and colors.COLOR_LIGHT_GREEN or nil
end

local function GetLevelText()
    if not GetUnitLevel then
        return nil
    end

    local level = GetUnitLevel("player") or 0
    local maxLevel = GetMaxLevel and GetMaxLevel() or nil
    if maxLevel and maxLevel > 0 and level >= maxLevel then
        return tostring(level), colors.COLOR_LIGHT_GREEN
    end
    return tostring(level)
end

local function GetChampionPointText()
    if not GetUnitChampionPoints then
        return nil
    end

    local points = GetUnitChampionPoints("player") or 0
    local color = points >= MAX_CHAMPION_POINTS and colors.COLOR_LIGHT_GREEN or nil
    return string.format("%d / %d", points, MAX_CHAMPION_POINTS), color
end

local function GetPvPRankText()
    if not GetUnitAvARank then
        return nil
    end

    local rank = GetUnitAvARank("player") or 0
    local name = nil
    if GetAvARankName then
        local gender = 1
        if GetUnitGender then
            gender = GetUnitGender("player") or gender
        end
        name = GetAvARankName(gender, rank)
    end

    local color = rank >= MAX_PVP_RANK and colors.COLOR_LIGHT_GREEN or nil
    if name and name ~= "" then
        return zo_strformat("<<1>> (<<2>> / <<3>>)", name, rank, MAX_PVP_RANK), color
    end
    return tostring(rank), color
end

-- USPF calculates its skyshard counts once during add-on loading.  Zone data may
-- not be ready then, and USPF does not recalculate those counts on activation.
-- Keep its definition of the maximum but count its tracked zones using live game
-- data.  Do not mutate USPF's tables or invoke its UI refresh.
local function GetLiveUSPFMaximum()
    local totals = USPF and USPF.ptsTots
    local data = USPF and USPF.data
    local zoneIds = data and data.ZId and data.ZId.ZN
    if not totals or type(totals.Tot) ~= "number" or type(totals.SSTot) ~= "number"
        or not data or type(data.zones) ~= "table" or type(zoneIds) ~= "table"
        or type(GetNumSkyshardsInZone) ~= "function" or type(GetNumSkyshards) ~= "function"
        or (GetNumSkyshards() or 0) <= 0 then
        return nil
    end

    local skyshards = 0
    for _, zone in ipairs(data.zones) do
        local zoneId = zoneIds[zone.key]
        if not zoneId then
            return nil
        end
        local count = GetNumSkyshardsInZone(zoneId)
        if type(count) ~= "number" or count < 0 then
            return nil
        end
        skyshards = skyshards + count
    end
    if skyshards <= 0 then
        return nil
    end
    return totals.Tot - totals.SSTot + math.floor(skyshards / 3)
end

-- Match USPF's own skill-point accounting: available points plus allocations in
-- active skill lines, excluding class-mastery points.  This avoids its stale
-- startup snapshot while keeping the result tied to the current character.
local function GetLiveEarnedSkillPoints()
    local skills = SKILLS_DATA_MANAGER
    local allocation = SKILL_POINT_ALLOCATION_MANAGER
    if not skills or not skills.IsDataReady or not skills:IsDataReady() or not skills.SkillTypeIterator
        or not allocation or not allocation.GetAvailableSkillPoints or not allocation.GetNumPointsAllocatedInSkillLine then
        return nil
    end
    local earned = allocation:GetAvailableSkillPoints()
    if type(earned) ~= "number" then
        return nil
    end
    for _, skillTypeData in skills:SkillTypeIterator() do
        if type(skillTypeData.orderedSkillLines) ~= "table" then
            return nil
        end
        for _, skillLine in ipairs(skillTypeData.orderedSkillLines) do
            if not skillLine.IsClassMastery then
                return nil
            end
            if not skillLine:IsClassMastery() then
                local points = allocation:GetNumPointsAllocatedInSkillLine(skillLine)
                if type(points) ~= "number" then
                    return nil
                end
                earned = earned + points
            end
        end
    end
    return earned
end

-- Without initialized USPF metadata or ready game data, show N/A and retry while
-- the dashboard is visible instead of displaying a partial startup total.
local function GetSkillPointText()
    local maxPoints = GetLiveUSPFMaximum()
    if type(maxPoints) ~= "number" or maxPoints <= 0 then
        return GetString(KELA_DASHBOARD_VALUE_NA)
    end
    local earned = GetLiveEarnedSkillPoints()
    if type(earned) ~= "number" then
        return GetString(KELA_DASHBOARD_VALUE_NA)
    end

    local color = earned >= maxPoints and colors.COLOR_LIGHT_GREEN or nil
    return string.format("%d / %d", earned, maxPoints), color
end

-- Skyshards are read straight from the game: GetNumSkyshards() is the total and
-- each shard's discovery status says whether it was acquired.  This replaced
-- USPF's totals, which were snapshotted at EVENT_ADD_ON_LOADED before the zone
-- map data existed and so reported 0 or 1 until a /reloadui.  A character who
-- has collected every shard never needs the loop again; that one case is kept in
-- memory for the session only, so a new total (content update) re-arms it and
-- nothing stale can survive a reload.
local skyShardComplete = {}

local function CountAcquiredSkyShards(total)
    local collected = 0
    for i = 1, total do
        local skyshardId = GetSkyshardId(i)
        if skyshardId and GetSkyshardDiscoveryStatus(skyshardId) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
            collected = collected + 1
        end
    end
    return collected
end

local function GetSkyshardText()
    if not GetNumSkyshards or not GetSkyshardId or not GetSkyshardDiscoveryStatus then
        return nil
    end

    local total = GetNumSkyshards() or 0
    if total <= 0 then
        return nil
    end

    local characterKey = GetCharacterKey()
    local memo = characterKey and skyShardComplete[characterKey]
    local collected
    if memo and memo.total == total and memo.collected >= total then
        collected = memo.collected
    else
        collected = CountAcquiredSkyShards(total)
        if characterKey and collected >= total then
            skyShardComplete[characterKey] = { collected = collected, total = total }
        end
    end

    local color = collected >= total and colors.COLOR_LIGHT_GREEN or nil
    return string.format("%d / %d", collected, total), color
end

local function GetBagText(bagId)
    if not GetNumBagUsedSlots or not GetBagSize then
        return nil
    end

    local used = GetNumBagUsedSlots(bagId) or 0
    local size = GetBagSize(bagId) or 0
    if size <= 0 then
        return string.format("%d / %d", used, size)
    end

    local color = nil
    if used >= size then
        color = colors.COLOR_LIGHT_RED
    elseif used >= size * 0.95 then
        color = colors.COLOR_LIGHT_ORANGE
    end
    return string.format("%d / %d", used, size), color
end

local function GetTransmuteMax()
    if IsESOPlusSubscriber and IsESOPlusSubscriber() then
        return 3000
    end
    return 1500
end

local function GetTransmuteText()
    if not GetCurrencyAmount or not CURT_TRANSMUTE_CRYSTALS or not CURRENCY_LOCATION_ACCOUNT then
        return nil
    end

    local amount = GetCurrencyAmount(CURT_TRANSMUTE_CRYSTALS, CURRENCY_LOCATION_ACCOUNT) or 0
    local maxAmount = GetTransmuteMax()
    if not maxAmount then
        return tostring(amount)
    end

    local color = nil
    if amount >= maxAmount then
        color = colors.COLOR_LIGHT_RED
    elseif amount >= maxAmount * 0.95 then
        color = colors.COLOR_LIGHT_ORANGE
    end
    return string.format("%d / %d", amount, maxAmount), color
end

-- Research progress for the logged-in character.  Counted over the same crafts,
-- lines and traits the Trait Research panel walks, so both show the same total.
local RESEARCH_CRAFTS =
{
    CRAFTING_TYPE_BLACKSMITHING,
    CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING,
}

-- { researched, total, nextCompletionAt }.  Rebuilt on every full dashboard
-- refresh, then reused by the per-minute tick, which only needs the clock.
local researchSummary = nil

local function RefreshResearchSummary()
    local now = GetTimeStamp and GetTimeStamp() or 0
    local researched, total = 0, 0
    local nextCompletionAt

    for _, craftingSkillType in ipairs(RESEARCH_CRAFTS) do
        if GetNumSmithingResearchLines(craftingSkillType) > 0 then
            for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
                local numTraits = select(3, GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex))
                for traitIndex = 1, numTraits do
                    total = total + 1
                    if select(3, GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex)) then
                        researched = researched + 1
                    else
                        local remaining = select(2, GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex))
                        if remaining and remaining > 0 then
                            local completionAt = now + remaining
                            if not nextCompletionAt or completionAt < nextCompletionAt then
                                nextCompletionAt = completionAt
                            end
                        end
                    end
                end
            end
        end
    end

    researchSummary = { researched = researched, total = total, nextCompletionAt = nextCompletionAt }
end

local function GetResearchText()
    if not researchSummary then
        RefreshResearchSummary()
    end
    if not researchSummary or researchSummary.total <= 0 then
        return nil
    end

    local countText = string.format("%d / %d", researchSummary.researched, researchSummary.total)
    local countColor = researchSummary.researched >= researchSummary.total and colors.COLOR_LIGHT_GREEN or nil

    local secondsRemaining
    if researchSummary.nextCompletionAt then
        local now = GetTimeStamp and GetTimeStamp() or 0
        secondsRemaining = math.max(0, researchSummary.nextCompletionAt - now)
    end

    return FormatProgressWithCountdown(countText, countColor, secondsRemaining)
end

-- PvP Veterancy: a seasonal AvA reward track.  The season has to be running and
-- the manager has to have built its rank data before the row can be read.
local function HasVeterancyAPI()
    local manager = ZO_VETERANCY_MANAGER
    return manager ~= nil
        and type(IsVeterancySeasonActive) == "function"
        and type(GetCurrentVeterancySeasonTimeRemainingS) == "function"
        and manager.GetNumRanks ~= nil
        and manager.GetCurrentRank ~= nil
end

local function GetVeterancyText()
    if not HasVeterancyAPI() then
        eventDetail.veterancy = nil
        return nil
    end

    if not IsVeterancySeasonActive() then
        eventDetail.veterancy = nil
        return GetString(KELA_DASHBOARD_VALUE_NONE_ACTIVE)
    end

    local manager = ZO_VETERANCY_MANAGER
    local numRanks = manager:GetNumRanks() or 0
    if numRanks <= 0 then
        -- The manager has not refreshed its reward-track data yet.
        return nil
    end

    local rank = manager:GetCurrentRank() or 0

    -- Collected, not displayed: the rank points and the tier completion.
    local rankPoints, rankPointsTotal, percent
    if manager.GetCurrentTierProgress then
        rankPoints = manager:GetCurrentTierProgress()
    end
    if manager.GetCurrentTierTotal then
        rankPointsTotal = manager:GetCurrentTierTotal()
    end
    local rankData = manager.GetCurrentRankData and manager:GetCurrentRankData()
    if rankData and rankData.GetProgressPercent then
        percent = rankData:GetProgressPercent()
    end
    eventDetail.veterancy =
    {
        rank = rank,
        numRanks = numRanks,
        rankPoints = rankPoints,
        rankPointsTotal = rankPointsTotal,
        percent = percent,
    }

    local countText = string.format("%d / %d", rank, numRanks)
    local countColor = manager.IsOnMaxRank and manager:IsOnMaxRank() and colors.COLOR_LIGHT_GREEN or nil

    return FormatProgressWithCountdown(countText, countColor, GetCurrentVeterancySeasonTimeRemainingS())
end

local DASHBOARD_LAYOUT =
{
    {
        title = KELA_DASHBOARD_SECTION_DAILY,
        rows =
        {
            { label = KELA_DASHBOARD_DAILY_RESET, value = GetDailyResetText, dailyReset = true },
            { label = KELA_DASHBOARD_CRAFTING_WRITS, value = GetCraftingWritText },
            { label = KELA_DASHBOARD_DUNGEON_REWARD, value = function() return GetRewardCooldownText(LFG_COOLDOWN_DUNGEON_REWARD_GRANTED) end },
            { label = KELA_DASHBOARD_BATTLEGROUND_REWARD, value = function() return GetRewardCooldownText(LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED) end },
            { label = KELA_DASHBOARD_INFINITE_ARCHIVE, value = GetArchiveText },
            { label = KELA_DASHBOARD_UNDAUNTED, value = GetUndauntedText },
            { wideLabel = true, getLabel = function() return GetPledgeLabel(1) end, value = function() return GetPledgeStatusText(1) end },
            { wideLabel = true, getLabel = function() return GetPledgeLabel(2) end, value = function() return GetPledgeStatusText(2) end },
            { wideLabel = true, getLabel = function() return GetPledgeLabel(3) end, value = function() return GetPledgeStatusText(3) end },
        },
    },
    {
        title = KELA_DASHBOARD_SECTION_EVENTS,
        available = function()
            if HasPromotionalEventAPI() or HasTamrielTomesAPI() or HasVeterancyAPI() then
                return true
            end
            return HasPromotionalEventCampaignAPI() and (GetNumActivePromotionalEventCampaigns() or 0) > 0
        end,
        rows =
        {
            { label = KELA_DASHBOARD_GOLDEN_PURSUIT, value = GetGoldenPursuitText, available = HasPromotionalEventAPI, countdown = true },
            { label = KELA_DASHBOARD_TAMRIEL_TOMES, value = GetTamrielTomesText, available = HasTamrielTomesAPI, countdown = true },
            { label = KELA_DASHBOARD_VETERANCY, value = GetVeterancyText, available = HasVeterancyAPI, countdown = true },
            { eventIndex = 1 },
            { eventIndex = 2 },
        },
    },
    {
        title = KELA_DASHBOARD_SECTION_CHARACTER,
        rows =
        {
            { label = KELA_DASHBOARD_ESO_PLUS, value = GetESOPlusText },
            { label = KELA_DASHBOARD_LEVEL, value = GetLevelText },
            { label = KELA_DASHBOARD_CHAMPION_POINTS, value = GetChampionPointText },
            { label = KELA_DASHBOARD_PVP_RANK, value = GetPvPRankText },
            { label = KELA_DASHBOARD_RESEARCH, value = GetResearchText, countdown = true },
            { label = KELA_DASHBOARD_SKYSHARDS, value = GetSkyshardText },
            { label = KELA_DASHBOARD_SKILL_POINTS, value = GetSkillPointText },
        },
    },
    {
        title = KELA_DASHBOARD_SECTION_CAPACITY,
        rows =
        {
            { label = KELA_DASHBOARD_BACKPACK, value = function() return GetBagText(BAG_BACKPACK) end },
            { label = KELA_DASHBOARD_BANK, value = function() return GetBagText(BAG_BANK) end },
            { label = KELA_DASHBOARD_TRANSMUTE_CRYSTALS, value = GetTransmuteText },
        },
    },
}

local function GetSectionLastRow(section)
    if section.dynamicRows and #section.dynamicRows > 0 then
        if visibleEventCount > 0 then
            return section.dynamicRows[math.min(visibleEventCount, #section.dynamicRows)]
        end
        return section.staticLastRow or section.control
    end
    return section.rows[#section.rows] or section.control
end

-- Sections are anchored from the content in one pass.  This has to run
-- whenever the dashboard is built or refreshed, because the visible event
-- rows move the section boundaries.
local function LayoutDashboardSections()
    if #dashboardSections == 0 then
        return
    end

    local previous = nil
    for _, section in ipairs(dashboardSections) do
        local parent = section.control:GetParent()
        section.control:ClearAnchors()
        if previous then
            section.control:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, DASHBOARD_SECTION_GAP)
            section.control:SetAnchor(TOPRIGHT, previous, BOTTOMRIGHT, 0, DASHBOARD_SECTION_GAP)
        else
            section.control:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
            section.control:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
        end
        previous = GetSectionLastRow(section)
    end
end

local function RefreshDashboard(ignoreHidden)
    if not built then
        return
    end

    -- Early out if dashboard is hidden (e.g., main menu not showing).  The
    -- one-time populate pass at player activation bypasses this.
    if not ignoreHidden and Kela_MainMenuDashboard and Kela_MainMenuDashboard:IsHidden() then
        return
    end

    RefreshDailyQuestData()
    -- The research counts and the next completion are re-read on every full
    -- refresh; the per-minute tick only re-reads the clock from the cache.
    researchSummary = nil

    -- Colors are carried by inline markup, because the XML color attributes bind
    -- the labels and labels/values must not fight a bound color with SetColor.
    titleControl:SetText(Colorize(DASHBOARD_COLOR_TITLE, GetString(KELA_DASHBOARD_TITLE)))
    for _, section in ipairs(dashboardSections) do
        if section.title then
            section.labelControl:SetText(Colorize(DASHBOARD_COLOR_SECTION, GetString(section.title)))
        end
    end

    for _, row in ipairs(dashboardRows) do
        local label = row.getLabel and row.getLabel()
        if not label and row.label then
            label = GetString(row.label)
        end
        row.labelControl:SetText(Colorize(row.labelColor, label))
        SetRowValueControl(row)
    end

    RefreshEvents(GetActiveEventCampaigns())
    LayoutDashboardSections()
end

-- Turn-in is the only per-day signal the game gives for daily quests: the quest
-- is removed from the journal and added to the undated completed archive.
-- Record what was handed in so the rows keep their credit after the turn-in and
-- across /reloadui, then let the daily reset clear it.
local function OnDailyQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
    if not isCompleted or not questID or questID == 0 then
        return
    end

    local now = GetTimeStamp and GetTimeStamp() or 0
    local boundary = ComputeResetBoundary(now)

    local changed = false
    if IsDailyCraftingWritQuest(questID) then
        local state = GetDailyState(DAILY_WRITS_SAVED_KEY, now, boundary)
        if state then
            state.ids[questID] = true
            dailyWritState = state
            changed = true
        end
    elseif IsDailyArchiveQuest(questID) then
        local state = GetDailyState(DAILY_ARCHIVE_SAVED_KEY, now, boundary)
        if state then
            state.ids[questID] = true
            dailyArchiveState = state
            changed = true
        end
    elseif IsDailyUndauntedPledgeQuest(questID) then
        local dungeon = GetPledgeDungeon(questName)
        if dungeon then
            local state = GetDailyState(DAILY_PLEDGES_SAVED_KEY, now, boundary)
            if state then
                state.ids[dungeon] = true
                dailyPledgeState = state
                changed = true
            end
        end
    end

    if changed and built and Kela_MainMenuDashboard and not Kela_MainMenuDashboard:IsHidden() then
        RefreshDashboard()
    end
end

local function UpdateDailyResetRow()
    local now = GetTimeStamp and GetTimeStamp() or 0
    local boundary = ComputeResetBoundary(now)
    local resolved, stale = ResolveDailyBoundary(dailyResetKey, boundary, now)
    if stale or resolved ~= dailyResetKey then
        -- The daily reset rolled over while the panel stayed open.
        RefreshDashboard()
        return
    end

    dailyResetSeconds = math.max(0, resolved - now)
    if dailyResetValueControl then
        local value, color = GetDailyResetText()
        dailyResetValueControl:SetText(Colorize(color, value) or unavailableText)
    end
end

local function UpdateCountdownRows()
    for _, row in ipairs(countdownRows) do
        SetRowValueControl(row)
    end
end

-- Per-minute update for the visible rows.  A research completion changes the
-- researched count, not just the clock, so that case rebuilds every row.
local function UpdateCountdowns()
    local now = GetTimeStamp and GetTimeStamp() or 0
    if researchSummary and researchSummary.nextCompletionAt and researchSummary.nextCompletionAt <= now then
        RefreshDashboard()
        return
    end

    UpdateDailyResetRow()
    UpdateCountdownRows()
end

-- Refresh whenever the panel becomes visible (every time the gamepad main menu
-- is pulled up) and never while it is hidden.
local function OnDashboardUpdate()
    local dashboard = Kela_MainMenuDashboard
    if not dashboard then
        EVENT_MANAGER:UnregisterForUpdate(DASHBOARD_UPDATE_NAME)
        return
    end

    local visible = not dashboard:IsHidden()
    if visible and not dashboardWasVisible then
        RefreshDashboard()
        dashboardPollCount = 0
    end
    if visible then
        -- USPF and the game can become ready after the first menu refresh.  Only
        -- update this row, rather than rebuilding the entire dashboard.
        if skillPointsRow then
            SetRowValueControl(skillPointsRow)
        end
        dashboardPollCount = dashboardPollCount + 1
        if dashboardPollCount >= DASHBOARD_RESET_UPDATE_POLLS then
            dashboardPollCount = 0
            UpdateCountdowns()
        end
    end
    dashboardWasVisible = visible
end

local function UpdateHelperPanelVisibility()
    local dashboard = Kela_MainMenuDashboard
    local manager = MAIN_MENU_GAMEPAD
    local scene = MAIN_MENU_GAMEPAD_SCENE
    if not dashboard or not manager then
        return
    end

    if scene and not scene:IsShowing() then
        return
    end

    dashboard:SetHidden(manager.activeHelperPanel ~= nil)
end

local function InstallHelperPanelHooks()
    local manager = MAIN_MENU_GAMEPAD
    if not manager or manager.__kelaDashboardHooksInstalled then
        return
    end
    manager.__kelaDashboardHooksInstalled = true

    -- SecurePostHook keeps the addon callback out of the scene-transition
    -- callstack that ESO uses for private core calls.  A normal method wrapper
    -- here tainted the main-menu hide path and broke Tamriel Tomes.
    SecurePostHook(manager, "ActivateHelperPanel", function()
        if Kela_MainMenuDashboard then
            Kela_MainMenuDashboard:SetHidden(true)
        end
    end)

    SecurePostHook(manager, "DeactivateHelperPanel", function()
        UpdateHelperPanelVisibility()
    end)
end

local function BuildDashboard()
    if built then
        return
    end

    local dashboard = Kela_MainMenuDashboard
    if not dashboard then
        return
    end

    -- Passive scroll container: the right stick scrolls the panel whenever the
    -- rows are taller than the visible area, with no focus or keybind needed.
    local scroll = CreateControlFromVirtual("KelaDashboardScroll", dashboard, "ZO_ScrollContainer_Gamepad")
    scroll:SetAnchor(TOPLEFT, dashboard, TOPLEFT, ZO_GAMEPAD_CONTENT_INSET_X, DASHBOARD_CONTENT_OFFSET_Y)
    scroll:SetAnchor(BOTTOMRIGHT, dashboard, BOTTOMRIGHT, -ZO_GAMEPAD_CONTENT_INSET_X, 0)
    ZO_Scroll_Initialize_Gamepad(scroll)
    ZO_Scroll_Gamepad_SetScrollIndicatorSide(scroll:GetNamedChild("ScrollIndicator"), dashboard:GetNamedChild("Background"), RIGHT)

    -- Rows go in a holder that takes its width from the scroll area and its
    -- height from the rows, which is what the scroll extents are measured from.
    local scrollArea = scroll:GetNamedChild("Scroll")
    local content = CreateControl("KelaDashboardScrollHolder", scrollArea, CT_CONTROL)
    content:SetAnchor(TOPLEFT)
    content:SetAnchor(TOPRIGHT, scrollArea, TOPRIGHT)
    content:SetResizeToFitDescendents(true)
    built = true

    titleControl = dashboard:GetNamedChild("Title")
    titleControl:SetText(GetString(KELA_DASHBOARD_TITLE))

    local controlIndex = 0

    for _, section in ipairs(DASHBOARD_LAYOUT) do
        if not section.available or section.available() then
            local rows = {}
            for _, row in ipairs(section.rows) do
                if not row.available or row.available() then
                    table.insert(rows, row)
                end
            end

            if #rows > 0 then
                controlIndex = controlIndex + 1
                local sectionControl = CreateControlFromVirtual("KelaDashboardSection" .. controlIndex, content, "KelaDashboardSectionTemplate")
                local sectionLabel = sectionControl:GetNamedChild("Label")
                sectionLabel:SetText(GetString(section.title))

                local sectionData = { control = sectionControl, title = section.title, labelControl = sectionLabel, rows = {}, dynamicRows = {} }

                local lastRow = sectionControl
                for _, row in ipairs(rows) do
                    controlIndex = controlIndex + 1
                    local rowTemplate = (row.eventIndex or row.wideLabel) and "KelaDashboardEventRowTemplate" or "KelaDashboardRowTemplate"
                    local rowControl = CreateControlFromVirtual("KelaDashboardRow" .. controlIndex, content, rowTemplate)
                    rowControl:SetAnchor(TOPLEFT, lastRow, BOTTOMLEFT, 0, 0)
                    rowControl:SetAnchor(TOPRIGHT, lastRow, BOTTOMRIGHT, 0, 0)

                    local labelControl = rowControl:GetNamedChild("Label")
                    local valueControl = rowControl:GetNamedChild("Value")

                    if row.eventIndex then
                        rowControl:SetHidden(true)
                        eventRows[row.eventIndex] =
                        {
                            control = rowControl,
                            labelControl = labelControl,
                            valueControl = valueControl,
                        }
                        table.insert(sectionData.dynamicRows, rowControl)
                    else
                        local rowData =
                        {
                            labelControl = labelControl,
                            valueControl = valueControl,
                            label = row.label,
                            labelColor = DASHBOARD_COLOR_LABEL,
                            getLabel = row.getLabel,
                            getValue = row.value,
                        }
                        table.insert(dashboardRows, rowData)
                        if row.label == KELA_DASHBOARD_SKILL_POINTS then
                            skillPointsRow = rowData
                        end
                        if row.countdown then
                            table.insert(countdownRows, rowData)
                        end
                        if row.dailyReset then
                            dailyResetValueControl = valueControl
                        end
                        sectionData.staticLastRow = rowControl
                    end

                    table.insert(sectionData.rows, rowControl)
                    lastRow = rowControl
                end

                table.insert(dashboardSections, sectionData)
            end
        end
    end

    LayoutDashboardSections()
end

local function AddDashboardFragment()
    if fragment or not MAIN_MENU_GAMEPAD_SCENE or not Kela_MainMenuDashboard then
        return
    end

    -- Use a simple fragment and a periodic refresh instead of a fragment
    -- StateChange callback.  A callback (or a secure post-hook wrapper) on
    -- SetState remains in the main-menu hide callstack and taints Tamriel
    -- Tomes' private catalog request.  The simple fragment only toggles the
    -- control, so the scene transition stays core-only.
    fragment = ZO_SimpleSceneFragment:New(Kela_MainMenuDashboard)
    MAIN_MENU_GAMEPAD_SCENE:AddFragment(fragment)
end

-- Fill the panel once the character is actually in the world, while the panel is
-- still hidden.  Journal, currency, bag and level data do not exist at
-- EVENT_ADD_ON_LOADED, so the first time the main menu shows the panel its rows
-- are already populated and only the normal full refresh runs.
local function OnPlayerActivatedPopulate()
    EVENT_MANAGER:UnregisterForEvent("KelaPadUI_DashboardPopulate", EVENT_PLAYER_ACTIVATED)
    if built then
        pcall(RefreshDashboard, true)
    end
end

function KelaSetupMainMenuDashboard()
    if built then
        return
    end

    if not KelaGetSetting_Bool(SETTING_TYPE_KELA, DASHBOARD_SETTING) then
        return
    end

    unavailableText = GetString(KELA_DASHBOARD_VALUE_UNAVAILABLE)
    BuildDashboard()
    AddDashboardFragment()
    InstallHelperPanelHooks()
    UpdateHelperPanelVisibility()
    dashboardWasVisible = false
    EVENT_MANAGER:UnregisterForUpdate(DASHBOARD_UPDATE_NAME)
    EVENT_MANAGER:RegisterForUpdate(DASHBOARD_UPDATE_NAME, DASHBOARD_VISIBILITY_POLL_INTERVAL, OnDashboardUpdate)
    EVENT_MANAGER:RegisterForEvent("KelaPadUI_DailyQuests", EVENT_QUEST_REMOVED, OnDailyQuestRemoved)
    EVENT_MANAGER:RegisterForEvent("KelaPadUI_DashboardPopulate", EVENT_PLAYER_ACTIVATED, OnPlayerActivatedPopulate)
end
