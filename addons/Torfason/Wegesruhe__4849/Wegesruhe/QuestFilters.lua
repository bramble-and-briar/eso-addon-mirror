local WR = Wegesruhe

WR.questTypeDefinitions = {
    { key = "none",             constant = "QUEST_TYPE_NONE",              label = "QUEST_TYPE_NONE" },
    { key = "mainStory",        constant = "QUEST_TYPE_MAIN_STORY",        label = "QUEST_TYPE_MAIN_STORY" },
    { key = "guild",            constant = "QUEST_TYPE_GUILD",             label = "QUEST_TYPE_GUILD" },
    { key = "class",            constant = "QUEST_TYPE_CLASS",             label = "QUEST_TYPE_CLASS" },
    { key = "companion",        constant = "QUEST_TYPE_COMPANION",         label = "QUEST_TYPE_COMPANION" },
    { key = "crafting",         constant = "QUEST_TYPE_CRAFTING",          label = "QUEST_TYPE_CRAFTING" },
    { key = "dungeon",          constant = "QUEST_TYPE_DUNGEON",           label = "QUEST_TYPE_DUNGEON" },
    { key = "group",            constant = "QUEST_TYPE_GROUP",             label = "QUEST_TYPE_GROUP" },
    { key = "raid",             constant = "QUEST_TYPE_RAID",              label = "QUEST_TYPE_RAID" },
    { key = "undauntedPledge",  constant = "QUEST_TYPE_UNDAUNTED_PLEDGE",  label = "QUEST_TYPE_UNDAUNTED_PLEDGE" },
    { key = "prologue",         constant = "QUEST_TYPE_PROLOGUE",          label = "QUEST_TYPE_PROLOGUE" },
    { key = "holidayEvent",     constant = "QUEST_TYPE_HOLIDAY_EVENT",     label = "QUEST_TYPE_HOLIDAY_EVENT" },
    { key = "tribute",          constant = "QUEST_TYPE_TRIBUTE",           label = "QUEST_TYPE_TRIBUTE" },
    { key = "scribing",         constant = "QUEST_TYPE_SCRIBING",          label = "QUEST_TYPE_SCRIBING" },
    { key = "tamrielTale",      constant = "QUEST_TYPE_TAMRIEL_TALE",      label = "QUEST_TYPE_TAMRIEL_TALE" },
    { key = "favor",            constant = "QUEST_TYPE_FAVOR",             label = "QUEST_TYPE_FAVOR" },
    { key = "ava",              constant = "QUEST_TYPE_AVA",               label = "QUEST_TYPE_AVA" },
    { key = "avaGrand",         constant = "QUEST_TYPE_AVA_GRAND",         label = "QUEST_TYPE_AVA_GRAND" },
    { key = "avaGroup",         constant = "QUEST_TYPE_AVA_GROUP",         label = "QUEST_TYPE_AVA_GROUP" },
    { key = "battleground",     constant = "QUEST_TYPE_BATTLEGROUND",      label = "QUEST_TYPE_BATTLEGROUND" },
}

WR.repeatTypeDefinitions = {
    { key = "notRepeatable", constant = "QUEST_REPEAT_NOT_REPEATABLE",       label = "REPEAT_NOT_REPEATABLE" },
    { key = "daily",         constant = "QUEST_REPEAT_DAILY",                label = "REPEAT_DAILY" },
    { key = "weekly",        constant = "QUEST_REPEAT_WEEKLY",               label = "REPEAT_WEEKLY" },
    { key = "monthly",       constant = "QUEST_REPEAT_MONTHLY",              label = "REPEAT_MONTHLY" },
    { key = "repeatable",    constant = "QUEST_REPEAT_REPEATABLE",           label = "REPEAT_REPEATABLE" },
    { key = "eventReset",    constant = "QUEST_REPEAT_EVENT_RESET",          label = "REPEAT_EVENT_RESET" },
    { key = "perDuration",   constant = "QUEST_REPEAT_REPEATABLE_PER_DURATION", label = "REPEAT_PER_DURATION" },
}

function WR:BuildQuestFilterCatalog()
    self.questTypeKeyByValue = {}
    self.repeatTypeKeyByValue = {}

    for _, definition in ipairs(self.questTypeDefinitions) do
        local value = _G[definition.constant]
        if type(value) == "number" then
            self.questTypeKeyByValue[value] = definition.key
        end
    end

    for _, definition in ipairs(self.repeatTypeDefinitions) do
        local value = _G[definition.constant]
        if type(value) == "number" then
            self.repeatTypeKeyByValue[value] = definition.key
        end
    end
end

function WR:IsQuestIndexAllowed(journalIndex, surface)
    if type(journalIndex) ~= "number" or journalIndex < 1 or not IsValidQuestIndex(journalIndex) then
        return true
    end

    local profile = self:GetActiveProfile()
    if not profile then
        return true
    end

    -- Default to map filters for legacy/internal callers.
    local questTypes = surface == "compass" and profile.compassQuestTypes or profile.questTypes
    local repeatTypes = surface == "compass" and profile.compassRepeatTypes or profile.repeatTypes

    local questType = GetJournalQuestType(journalIndex)
    local questTypeKey = self.questTypeKeyByValue and self.questTypeKeyByValue[questType]
    if questTypeKey and questTypes and questTypes[questTypeKey] == false then
        return false
    end

    local repeatType = GetJournalQuestRepeatType(journalIndex)
    local repeatTypeKey = self.repeatTypeKeyByValue and self.repeatTypeKeyByValue[repeatType]
    if repeatTypeKey and repeatTypes and repeatTypes[repeatTypeKey] == false then
        return false
    end

    return true
end

-- ESO draws compass quest-area glows independently of its usual compass pins.
-- Cache the effective filtering state so unrelated settings and the frequent
-- hold-to-show-help key do not continuously rebuild every quest area.
local function QuestAreaFilterSignature(self, profile)
    local parts = { (profile.compassPins == false or profile.compass.questAreas == false) and "0" or "1" }
    for _, definition in ipairs(self.questTypeDefinitions) do
        parts[#parts + 1] = profile.compassQuestTypes and profile.compassQuestTypes[definition.key] == false and "0" or "1"
    end
    for _, definition in ipairs(self.repeatTypeDefinitions) do
        parts[#parts + 1] = profile.compassRepeatTypes and profile.compassRepeatTypes[definition.key] == false and "0" or "1"
    end
    return table.concat(parts)
end

function WR:ApplyQuestAreaFilters()
    if not COMPASS or not COMPASS.StopAreaPinOutAnimation then
        return
    end

    local profile = self:GetActiveProfile()
    local signature = QuestAreaFilterSignature(self, profile)
    if signature == self.lastQuestAreaFilterSignature then
        return
    end
    self.lastQuestAreaFilterSignature = signature

    -- Remove glows already on screen for quests now excluded by the profile.
    -- ESO's StopAreaPinOutAnimation needs the area name and ZERO-based quest,
    -- step and condition indices; substituting StopAreaPinOutAnimation for
    -- PlayQuestAreaPinOutAnimation would pass incompatible arguments.
    local hideAll = profile.compassPins == false or profile.compass.questAreas == false
    for journalIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(journalIndex) and (hideAll or not self:IsQuestIndexAllowed(journalIndex, "compass")) then
            for stepIndex = QUEST_MAIN_STEP_INDEX, GetJournalQuestNumSteps(journalIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(journalIndex, stepIndex) do
                    COMPASS:StopAreaPinOutAnimation(
                        "areaQuestPins", journalIndex - 1, stepIndex - 1, conditionIndex - 1
                    )
                end
            end
        end
    end

    -- Recreate only eligible quest-area glows after a previously hidden group
    -- becomes visible. ESO itself decides whether the player is inside each area.
    if not hideAll and COMPASS.PerformFullAreaQuestUpdate then
        COMPASS:PerformFullAreaQuestUpdate()
    end
end

-- Compass icons expose their pin CATEGORY, not the journal quest index.
-- We can safely filter the selected (assisted) quest as a category and hide
-- secondary quest icons only when every eligible secondary quest is excluded.
-- In mixed sets we deliberately keep the category visible: hiding it would
-- also conceal allowed quests. Do not try to match translated pin labels.
function WR:RefreshQuestCompassEligibility()
    self.questCompassEligibility = nil -- fail open if an API is unavailable

    if type(IsValidQuestIndex) ~= "function"
        or type(GetTrackedIsAssisted) ~= "function"
        or type(MAX_JOURNAL_QUESTS) ~= "number"
        or type(TRACK_TYPE_QUEST) ~= "number" then
        return
    end

    local seenAssisted, allowedAssisted = false, false
    local seenSecondary, allowedSecondary = false, false

    for journalIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(journalIndex) then
            local isAllowed = self:IsQuestIndexAllowed(journalIndex, "compass")
            if GetTrackedIsAssisted(TRACK_TYPE_QUEST, journalIndex) then
                seenAssisted = true
                if isAllowed then
                    allowedAssisted = true
                end
            else
                seenSecondary = true
                if isAllowed then
                    allowedSecondary = true
                end
            end
        end
    end

    self.questCompassEligibility = {
        assistedObjectives = not seenAssisted or allowedAssisted,
        secondaryObjectives = not seenSecondary or allowedSecondary,
    }
end

-- Quest selection and journal membership can change without opening our
-- settings. Coalesce event bursts; do not poll the game or touch world markers.
function WR:ScheduleQuestCompassRefresh()
    if self.questCompassRefreshQueued then
        return
    end
    self.questCompassRefreshQueued = true

    local function Refresh()
        self.questCompassRefreshQueued = false
        if self.settings and self.RefreshCompass then
            self:RefreshCompass()
        end
    end

    if type(zo_callLater) == "function" then
        zo_callLater(Refresh, 100)
    else
        Refresh()
    end
end

function WR:InitializeQuestCompassEvents()
    if self.questCompassEventsHooked or not EVENT_MANAGER then
        return
    end
    self.questCompassEventsHooked = true

    local eventNames = {
        "EVENT_TRACKING_UPDATE",
        "EVENT_QUEST_ADDED",
        "EVENT_QUEST_REMOVED",
        "EVENT_QUEST_LIST_UPDATED",
    }
    for _, eventName in ipairs(eventNames) do
        local eventCode = _G[eventName]
        if type(eventCode) == "number" then
            EVENT_MANAGER:RegisterForEvent(self.name .. "Compass" .. eventName, eventCode, function()
                self:ScheduleQuestCompassRefresh()
            end)
        end
    end
end

function WR:InitializeQuestFilters()
    self:BuildQuestFilterCatalog()
    self:InitializeQuestCompassEvents()

    -- Quest-map pins contain a journal quest index, allowing a per-quest texture
    -- filter without altering quest tracking. Other compass icons are controlled
    -- by pin category; quest-area animations have their own hook below.
    if ZO_MapPin and ZO_MapPin.GetQuestIcon and not self.questIconHooked then
        self.questIconHooked = true
        self.originalGetQuestIcon = ZO_MapPin.GetQuestIcon
        local original = self.originalGetQuestIcon

        function ZO_MapPin:GetQuestIcon()
            local journalIndex = self:GetQuestIndex()
            if journalIndex and journalIndex > 0 and not WR:IsQuestIndexAllowed(journalIndex, "map") then
                return WR.blankTexture
            end
            return original(self)
        end
    end

    -- Quest-area animations on the compass are built through a separate path
    -- and do not ask ZO_MapPin:GetQuestIcon, so filter those explicitly too.
    if COMPASS and COMPASS.PlayQuestAreaPinOutAnimation and not self.questAreaHooked then
        self.questAreaHooked = true
        self.originalPlayQuestAreaPinOutAnimation = COMPASS.PlayQuestAreaPinOutAnimation
        local original = self.originalPlayQuestAreaPinOutAnimation

        function COMPASS:PlayQuestAreaPinOutAnimation(journalIndex, stepIndex, conditionIndex)
            local profile = WR:GetActiveProfile()
            if profile.compassPins == false or profile.compass.questAreas == false or not WR:IsQuestIndexAllowed(journalIndex, "compass") then
                return
            end
            return original(self, journalIndex, stepIndex, conditionIndex)
        end
    end
end
