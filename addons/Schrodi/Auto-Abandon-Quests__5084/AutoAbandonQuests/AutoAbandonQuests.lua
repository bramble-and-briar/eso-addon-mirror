-- Auto Abandon Quests
-- Abandons unwanted repeatable quests the moment they land in the journal.
-- Based on Auto Abandon Contracts by @Furious_Sniper.

local ADDON = "AutoAbandonQuests"
local TITLE = "Auto Abandon Quests"

local DAY = 86400

local sv        -- account-wide settings
local charLog   -- per character: { done = { [questName] = timestamp } }

-- Every category is a multi-select of the quests to keep; the rest get abandoned.
-- Nothing selected (or everything selected) = keep all.
-- Daily categories: once every kept quest has been turned in on this character since
-- the last daily reset, the remaining ones are kept too. Kept quests are equal.
local CATEGORIES = {
    {
        key = "darkBrotherhood",
        title = "Dark Brotherhood Contracts",
        tooltip = "Contracts from the Marked for Death ledger in the Dark Brotherhood Sanctuary (Gold Coast).\n\n"
            .. "Select which kind of contract to keep, the other kind is abandoned. Contracts can be repeated "
            .. "right away, so there's no daily limit here.\n\n"
            .. "Story quests that are also called \"Contract: …\" (like Contract: Kvatch) are never abandoned.",
        choices = {
            { value = "normal", label = "Normal contracts", tooltip = "\"Contract: <zone>\": kill one marked target." },
            { value = "spree", label = "Killing Sprees", tooltip = "\"Contract: <zone> Spree\": kill several citizens of a city." },
        },
        default = { spree = true },
        Classify = function(questName)
            if not questName:find("^Contract: ") then return nil end
            return questName:find(" Spree$") and "spree" or "normal"
        end,
    },
    {
        key = "battlegrounds",
        title = "Daily Battleground Quests",
        daily = true,
        tooltip = "Daily challenges from Battlemaster Rivyn.\n\n"
            .. "Select the ones you want to do. Once all of them have been turned in on this character today, "
            .. "the rest are kept too and you get a note in chat.\n\n"
            .. "The one-time introduction quest For Glory is never touched.",
        choices = {
            { value = "Let the Games Begin", tooltip = "Play 5 Battleground matches, win or lose." },
            { value = "Test of Mettle", tooltip = "Earn 1000 medal points in a Battleground match." },
            { value = "To the Victor", tooltip = "Win 3 Battleground matches." },
        },
        default = { ["Test of Mettle"] = true, ["To the Victor"] = true },
    },
    {
        key = "bounty",
        title = "Cyrodiil Bounty Missions",
        daily = true,
        tooltip = "Daily quests from the Bounty Mission boards in Cyrodiil.\n\n"
            .. "Select the ones you want to do. Once all of them have been turned in on this character today, "
            .. "the rest are kept too and you get a note in chat.",
        choices = {
            { value = "Kill Enemy Players", tooltip = "Kill 20 enemy players of any class." },
            { value = "Kill Enemy Arcanists", tooltip = "Kill 20 enemy Arcanists." },
            { value = "Kill Enemy Dragonknights", tooltip = "Kill 20 enemy Dragonknights." },
            { value = "Kill Enemy Necromancers", tooltip = "Kill 20 enemy Necromancers." },
            { value = "Kill Enemy Nightblades", tooltip = "Kill 20 enemy Nightblades." },
            { value = "Kill Enemy Sorcerers", tooltip = "Kill 20 enemy Sorcerers." },
            { value = "Kill Enemy Templars", tooltip = "Kill 20 enemy Templars." },
            { value = "Kill Enemy Wardens", tooltip = "Kill 20 enemy Wardens." },
        },
        default = { ["Kill Enemy Players"] = true },
    },
    {
        key = "conquest",
        title = "Cyrodiil Conquest Missions",
        daily = true,
        tooltip = "Daily quests from the Conquest Missions boards in Cyrodiil.\n\n"
            .. "Select the ones you want to do. Once all of them have been turned in on this character today, "
            .. "the rest are kept too and you get a note in chat.",
        choices = {
            { value = "Capture All 3 Towns", tooltip = "Capture the three major towns: Bruma, Cropsford and Vlastarus." },
            { value = "Capture Any Nine Resources", tooltip = "Capture nine different resources (farms, mines, lumbermills)." },
            { value = "Capture Any Three Keeps", tooltip = "Capture any three keeps." },
            { value = "Kill 150 Enemy Players", tooltip = "Kill 150 enemy players. In a group only your killing blows count." },
        },
        default = { ["Capture Any Nine Resources"] = true, ["Capture Any Three Keeps"] = true },
    },
}

local defaults = {
    keep = {},           -- [category key] = { [choice value] = bool }, every choice stored explicitly
    elderScrolls = false,
    autoAccept = false,
    showAccepted = true,
    skipCyrodiil = false,
    skipImperialCity = false,
}

-- Explicit true/false for every choice: ZO_SavedVars fills missing keys from the defaults on
-- every load, so an "unselected" choice must be stored as false, not left out.
local questCategory = {} -- quest name -> category (daily categories only; DB uses Classify)
for _, category in ipairs(CATEGORIES) do
    local keep = {}
    for _, choice in ipairs(category.choices) do
        keep[choice.value] = category.default[choice.value] == true
        if category.daily then questCategory[choice.value] = category end
    end
    defaults.keep[category.key] = keep
end

-- Never abandoned, whatever the settings say.
local WHITELIST = {
    ["Contract: Kvatch"] = true, -- Dark Brotherhood story: first contract from Elam Drals
}

-- Quest givers (GetUnitName("interact")) whose quests are accepted automatically.
-- Names as recorded by LibQuestData. "scroll": only Elder Scroll missions, and only
-- while that option is on (the Grand Warlords hand out other quests too).
local GIVERS = {
    ["Marked for Death"] = true,
    ["Battlemaster Rivyn"] = true,
    ["Bounty Mission Board"] = true,
    ["Conquest Missions Board"] = true,
    ["Grand Warlord Sorcalin"] = "scroll",
    ["Grand Warlord Dortene"] = "scroll",
    ["Grand Warlord Zimmeron"] = "scroll",
}

local SCROLL_QUEST_PATTERN = "^The Elder Scroll of (.+)$"
local settingsPanel -- LAM panel control, for /aaq
local MAX_AUTO_ACCEPTS = 10 -- per conversation, in case the giver keeps re-offering

-- Selected values of a category in choice order, or nil when the category keeps everything.
local function GetKept(category)
    local keep = sv.keep[category.key]
    local kept = {}
    for _, choice in ipairs(category.choices) do
        if keep[choice.value] then kept[#kept + 1] = choice.value end
    end
    if #kept == 0 or #kept == #category.choices then return nil end
    return kept
end

local function GetLabel(category, value)
    for _, choice in ipairs(category.choices) do
        if choice.value == value then return choice.label or choice.value end
    end
    return value
end

local function Print(message)
    CHAT_ROUTER:AddSystemMessage("|c88CCFF[AAQ]|r " .. message)
end

local function Quest(name)
    return "|cFFCC44" .. name .. "|r"
end

local function QuestList(names)
    local out = {}
    for i, name in ipairs(names) do out[i] = Quest(name) end
    return table.concat(out, " / ")
end

-- ─── Daily reset ──────────────────────────────────────────────────────────────

-- Timestamp (UTC) of the most recent daily reset. Daily quests reset together with
-- daily Endeavors, so the Endeavor timer gives the exact moment. If it's not
-- available, fall back to the known times: 03:00 UTC on EU, 10:00 UTC on NA.
local function GetLastDailyReset()
    local now = GetTimeStamp()
    if IsTimedActivitySystemAvailable() then
        for i = 1, GetNumTimedActivities() do
            if GetTimedActivityType(i) == TIMED_ACTIVITY_TYPE_DAILY then
                local remaining = GetTimedActivityTimeRemainingSeconds(i)
                if remaining and remaining > 0 and remaining <= DAY then
                    return now + remaining - DAY
                end
            end
        end
    end
    local resetHourUtc = GetWorldName():find("^NA") and 10 or 3
    local offset = resetHourUtc * 3600
    return now - (now - offset) % DAY
end

local function IsDoneToday(questName, lastReset)
    local t = charLog.done[questName]
    return t ~= nil and t >= lastReset
end

-- Kept quests that can still be done today.
local function GetKeptLeft(kept)
    local lastReset = GetLastDailyReset()
    local left = {}
    for _, name in ipairs(kept) do
        if not IsDoneToday(name, lastReset) then left[#left + 1] = name end
    end
    return left
end

-- ─── Core logic ───────────────────────────────────────────────────────────────

local function Abandon(journalIndex, questName, reason)
    -- Another addon may have removed it already; never abandon whatever sits there now.
    if GetJournalQuestName(journalIndex) ~= questName then return end
    AbandonQuest(journalIndex)
    Print("|cFF5555Abandoned|r " .. Quest(questName) .. (reason and (" - " .. reason) or ""))
end

-- A wanted quest is announced only with "Show accepted quests" on. An unwanted one that
-- was kept anyway (reason given) is always announced, so it's clear why it stayed.
local function Accepted(questName, reason, isException)
    if not isException and not sv.showAccepted then return end
    Print("|c55DD55Accepted|r " .. Quest(questName) .. (reason and (" - " .. reason) or ""))
end

-- ─── Elder Scrolls ────────────────────────────────────────────────────────────

-- Renamed from GetObjectiveIdsForIndex in newer APIs.
local GetObjectiveKeys = GetAvAObjectiveKeysByIndex or GetObjectiveIdsForIndex

-- Scrolls in the current campaign that a player of your alliance is carrying right now:
-- { [scroll name, e.g. "Chim"] = holder character name }
local function GetScrollsCarriedByAlliance()
    local carried = {}
    local myAlliance = GetUnitAlliance("player")
    for i = 1, GetNumObjectives() do
        local keepId, objectiveId, bgContext = GetObjectiveKeys(i)
        if IsLocalBattlegroundContext(bgContext) then
            local name, objectiveType, state = GetObjectiveInfo(keepId, objectiveId, bgContext)
            if (objectiveType == OBJECTIVE_ARTIFACT_OFFENSIVE or objectiveType == OBJECTIVE_ARTIFACT_DEFENSIVE)
                and state == OBJECTIVE_CONTROL_STATE_FLAG_HELD
                and GetCarryableObjectiveHoldingAllianceInfo(keepId, objectiveId, bgContext) == myAlliance then
                local scroll = zo_strformat("<<1>>", name):match("Elder Scroll of (.+)$")
                if scroll then
                    local holder = GetCarryableObjectiveHoldingCharacterInfo(keepId, objectiveId, bgContext)
                    carried[scroll] = (holder and holder ~= "") and zo_strformat("<<1>>", holder) or "someone"
                end
            end
        end
    end
    return carried
end

local function HandleElderScroll(journalIndex, questName, scroll)
    local carried = GetScrollsCarriedByAlliance()
    -- A scroll whose mission was already turned in today can't be offered again.
    local lastReset = GetLastDailyReset()
    for name in pairs(carried) do
        if IsDoneToday("The Elder Scroll of " .. name, lastReset) then carried[name] = nil end
    end

    if carried[scroll] then
        Accepted(questName, carried[scroll] .. " is carrying it.")
        return
    end
    if next(carried) == nil then
        Accepted(questName, "nobody from your alliance is carrying an Elder Scroll right now.", true)
        return
    end
    local wanted = {}
    for name, holder in pairs(carried) do
        wanted[#wanted + 1] = Quest("The Elder Scroll of " .. name) .. " (" .. holder .. ")"
    end
    table.sort(wanted)
    Abandon(journalIndex, questName, "waiting for " .. table.concat(wanted, " / ") .. ".")
end

local function OnQuestAdded(_, journalIndex, questName)
    questName = questName or GetJournalQuestName(journalIndex)
    if not questName or questName == "" or WHITELIST[questName] then return end

    local scroll = questName:match(SCROLL_QUEST_PATTERN)
    if scroll then
        if not sv.elderScrolls then return end
        if GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_NOT_REPEATABLE then return end
        if IsShiftKeyDown() then
            Accepted(questName, "Shift held.", true)
            return
        end
        HandleElderScroll(journalIndex, questName, scroll)
        return
    end

    local category, value = questCategory[questName], questName
    if not category then
        category = CATEGORIES[1]
        value = category.Classify(questName)
        if not value then return end
    end

    local kept = GetKept(category)
    if not kept then return end
    -- Story quests can share names with repeatable ones ("Contract: …").
    if GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_NOT_REPEATABLE then return end
    if sv.keep[category.key][value] then
        Accepted(questName)
        return
    end

    if IsShiftKeyDown() then
        Accepted(questName, "Shift held.", true)
        return
    end

    if not category.daily then
        local labels = {}
        for i, v in ipairs(kept) do labels[i] = GetLabel(category, v) end
        Abandon(journalIndex, questName, "keeping only " .. table.concat(labels, " / ") .. ".")
        return
    end

    local left = GetKeptLeft(kept)
    if #left == 0 then
        Accepted(questName, QuestList(kept) .. (#kept > 1 and " are" or " is")
            .. " already done today on this character.", true)
        return
    end
    Abandon(journalIndex, questName, "waiting for " .. QuestList(left) .. ".")
end

-- ─── Auto accept / skip dialogue ──────────────────────────────────────────────

local autoAccepts = 0
local pickedOptions = {} -- chatter option texts already picked in this conversation

-- Skip dialogue is on for the zone you're in (Imperial City is checked first, it's part of Cyrodiil).
local function IsSkipDialogueZone()
    if IsInImperialCity() then return sv.skipImperialCity end
    if IsInCyrodiil() then return sv.skipCyrodiil end
    return false
end

-- How quest offers from the current giver are handled: nil = leave to the player,
-- true = accept, "scroll" = accept only Elder Scroll missions.
local function GetAutoAcceptMode()
    if IsShiftKeyDown() or autoAccepts >= MAX_AUTO_ACCEPTS then return nil end
    if IsSkipDialogueZone() then return true end
    if not sv.autoAccept then return nil end
    local kind = GIVERS[GetUnitName("interact")]
    if kind == "scroll" and not sv.elderScrolls then return nil end
    return kind
end

local function PickOption(i, optionText)
    pickedOptions[optionText] = true
    SelectChatterOption(i)
end

-- NPCs show a chatter menu first. Turn in a finished quest if there is one (skip dialogue
-- zones only), otherwise ask for a new quest. Each option is picked once per conversation,
-- so a dialog the player has to answer (or backed out of) never loops.
local function HandleChatterOptions(optionCount)
    local mode = GetAutoAcceptMode()
    local skipZone = not IsShiftKeyDown() and IsSkipDialogueZone()
    if not mode and not skipZone then return end

    local bestowal, bestowalText
    for i = 1, optionCount do
        local optionText, optionType = GetChatterOption(i)
        if not pickedOptions[optionText] then
            if skipZone and optionType == CHATTER_START_COMPLETE_QUEST then
                PickOption(i, optionText)
                return
            elseif mode and optionType == CHATTER_START_NEW_QUEST_BESTOWAL and not bestowal then
                bestowal, bestowalText = i, optionText
            end
        end
    end
    if bestowal then PickOption(bestowal, bestowalText) end
end

local function OnChatterBegin(_, optionCount)
    HandleChatterOptions(optionCount)
end

local function OnConversationUpdated(_, _, optionCount)
    HandleChatterOptions(optionCount)
end

-- Boards go straight to the quest offer; NPCs get here after the chatter option above.
local function OnQuestOffered()
    local mode = GetAutoAcceptMode()
    if not mode then return end
    -- Grand Warlords: leave anything that isn't an Elder Scroll mission to the player.
    if mode == "scroll" and not (GetOfferedQuestInfo() or ""):find("Elder Scroll") then return end
    autoAccepts = autoAccepts + 1
    AcceptOfferedQuest()
end

-- Same check the game does before turning a quest in: a reward over the currency cap
-- (Tel Var, AP, gold...) would be lost, so that one is left for the player to confirm.
local function WouldRewardExceedCap(journalIndex)
    for i = 1, GetJournalQuestNumRewards(journalIndex) do
        local rewardType, _, amount = GetJournalQuestRewardInfo(journalIndex, i)
        if ZO_SharedInteraction:WouldCurrencyExceedMax(rewardType, amount) then return true end
    end
    return false
end

-- Turn-in window: finish repeatable quests (dailies) right away in skip dialogue zones.
local function OnQuestCompleteDialog(_, journalIndex)
    if IsShiftKeyDown() or not IsSkipDialogueZone() then return end
    if GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_NOT_REPEATABLE then return end
    if WouldRewardExceedCap(journalIndex) then
        Print("Not turning in " .. Quest(GetJournalQuestName(journalIndex)) .. " automatically - a reward would go over your currency cap.")
        return
    end
    CompleteQuest()
end

local function OnChatterEnd()
    autoAccepts = 0
    pickedOptions = {}
end

local function OnQuestComplete(_, questName)
    if questName and (questCategory[questName] or questName:find(SCROLL_QUEST_PATTERN)) then
        charLog.done[questName] = GetTimeStamp()
    end
end

-- ─── Status command ───────────────────────────────────────────────────────────

local function PrintStatus()
    local lastReset = GetLastDailyReset()
    local untilReset = lastReset + DAY - GetTimeStamp()
    Print(string.format("Next daily reset in %dh %02dm.", zo_floor(untilReset / 3600), zo_floor(untilReset % 3600 / 60)))
    for _, category in ipairs(CATEGORIES) do
        if category.daily then
            local done = {}
            for _, choice in ipairs(category.choices) do
                if IsDoneToday(choice.value, lastReset) then done[#done + 1] = choice.value end
            end
            local kept = GetKept(category)
            Print(category.title .. " [" .. (kept and ("keeping " .. QuestList(kept)) or "keeping all")
                .. "] done today: " .. (#done > 0 and QuestList(done) or "none"))
        end
    end
    local carried = {}
    for name, holder in pairs(GetScrollsCarriedByAlliance()) do
        carried[#carried + 1] = Quest(name) .. " (" .. holder .. ")"
    end
    table.sort(carried)
    Print("Elder Scrolls [" .. (sv.elderScrolls and "ON" or "OFF") .. "] carried by your alliance: "
        .. (#carried > 0 and table.concat(carried, ", ") or "none"))
end

-- ─── Settings panel ───────────────────────────────────────────────────────────

local function BuildSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then return end

    settingsPanel = LAM:RegisterAddonPanel(ADDON .. "Options", {
        type = "panel",
        name = TITLE,
        displayName = TITLE,
        author = "Schrodi",
        version = "1.5",
        registerForRefresh = true,
    })

    local options = {
        {
            type = "description",
            text = "Abandons unwanted repeatable quests the moment you accept them, so you can talk to the "
                .. "quest giver again for a different one.\n\n"
                .. "Hold |cFFCC44Shift|r while accepting a quest to keep it anyway.\n"
                .. "|cFFCC44/aaq|r opens this page, |cFFCC44/aaq info|r shows which daily quests this character has already turned in today.\n\n"
                .. "Quest names are matched in English, so this only works with the English game client.",
        },
        -- one multi-select per category, inserted below
        {
            type = "checkbox",
            name = "Elder Scroll Missions",
            tooltip = "Missions from your alliance's Grand Warlord to capture (or recapture) an Elder Scroll.\n\n"
                .. "When someone from your alliance is carrying a scroll in your campaign right now, missions for "
                .. "other scrolls are abandoned, so you end up with the one that's already on its way to a keep.\n\n"
                .. "If nobody is carrying a scroll, or only scrolls you've already done today, any mission is kept.",
            default = defaults.elderScrolls,
            getFunc = function() return sv.elderScrolls end,
            setFunc = function(value) sv.elderScrolls = value end,
        },
        {
            type = "checkbox",
            name = "Accept quests automatically",
            tooltip = "Accepts the quest as soon as you open the Marked for Death ledger, talk to Battlemaster "
                .. "Rivyn, or use the Bounty / Conquest Missions board, so you only press the interact key. "
                .. "With Elder Scroll Missions on, the same goes for Elder Scroll missions from your Grand Warlord "
                .. "(his other quests are left to you).\n\n"
                .. "Unwanted quests are still abandoned right after; interact again to get another one. "
                .. "Hold |cFFCC44Shift|r while interacting to read the offer and decide yourself.",
            default = defaults.autoAccept,
            getFunc = function() return sv.autoAccept end,
            setFunc = function(value) sv.autoAccept = value end,
        },
        {
            type = "checkbox",
            name = "Skip dialogue in Cyrodiil",
            tooltip = "In Cyrodiil (outside the Imperial City), talking to a quest giver or using a mission board "
                .. "goes straight through: a finished repeatable quest is turned in, and a new quest offer is "
                .. "accepted, without clicking through the dialogue. Unwanted quests are still abandoned.\n\n"
                .. "The game doesn't say whether an offered quest is a daily before you accept it, so every quest "
                .. "offer in the zone is accepted. Turn-ins only happen for repeatable quests; story quests "
                .. "show their ending as usual.\n\n"
                .. "A turn-in whose reward would go over a currency cap is left to you. "
                .. "Hold |cFFCC44Shift|r while interacting to go through the dialogue yourself.",
            default = defaults.skipCyrodiil,
            getFunc = function() return sv.skipCyrodiil end,
            setFunc = function(value) sv.skipCyrodiil = value end,
        },
        {
            type = "checkbox",
            name = "Skip dialogue in Imperial City",
            tooltip = "Same as above, for the Imperial City and its sewers: repeatable quests are turned in and new "
                .. "quest offers are accepted without clicking through the dialogue.\n\n"
                .. "A turn-in whose reward would go over a currency cap (Tel Var stones!) is left to you. "
                .. "Hold |cFFCC44Shift|r while interacting to go through the dialogue yourself.",
            default = defaults.skipImperialCity,
            getFunc = function() return sv.skipImperialCity end,
            setFunc = function(value) sv.skipImperialCity = value end,
        },
        {
            type = "checkbox",
            name = "Show accepted quests",
            tooltip = "Writes |c55DD55Accepted|r <quest> in chat when a quest you want lands in your journal. "
                .. "|cFF5555Abandoned|r messages are always shown.\n\n"
                .. "Notes about an unwanted quest that was kept anyway (everything you want is already done "
                .. "today, Shift held, nobody carrying an Elder Scroll) are always shown too.",
            default = defaults.showAccepted,
            getFunc = function() return sv.showAccepted end,
            setFunc = function(value) sv.showAccepted = value end,
        },
        {
            type = "description",
            text = "|c888888About \"today\": daily quests reset at 03:00 UTC on EU and 10:00 UTC on NA; the addon "
                .. "reads the exact time from the daily Endeavors timer. It only knows about quests turned in "
                .. "while it was enabled, so on the first day you may need Shift to keep a quest.|r",
        },
    }

    for i, category in ipairs(CATEGORIES) do
        local choices, choicesValues, choicesTooltips = {}, {}, {}
        for j, choice in ipairs(category.choices) do
            choices[j] = choice.label or choice.value
            choicesValues[j] = choice.value
            choicesTooltips[j] = choice.tooltip
        end
        local defaultList = {}
        for _, choice in ipairs(category.choices) do
            if category.default[choice.value] then defaultList[#defaultList + 1] = choice.value end
        end
        table.insert(options, 1 + i, {
            type = "dropdown",
            name = category.title,
            tooltip = category.tooltip .. "\n\n|c888888Nothing selected (or everything) = keep every quest. "
                .. "Right-click the box to select all or clear.|r",
            multiSelect = true,
            multiSelectTextFormatter = "Keep <<1>> of " .. #choices,
            multiSelectNoSelectionText = "Keep all",
            choices = choices,
            choicesValues = choicesValues,
            choicesTooltips = choicesTooltips,
            default = defaultList, -- setFunc copies the values, never keeps this table
            getFunc = function()
                local list = {}
                for _, choice in ipairs(category.choices) do
                    if sv.keep[category.key][choice.value] then list[#list + 1] = choice.value end
                end
                return list
            end,
            setFunc = function(values)
                local keep = sv.keep[category.key]
                for _, choice in ipairs(category.choices) do keep[choice.value] = false end
                for _, value in ipairs(values or {}) do keep[value] = true end
            end,
        })
    end

    LAM:RegisterOptionControls(ADDON .. "Options", options)
end

-- ─── Initialisation ───────────────────────────────────────────────────────────

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED)
    if AutoAbandonContractsSavedVars ~= nil then
        Print("|cFF6666Auto Abandon Contracts is also enabled.|r It abandons Dark Brotherhood contracts on its own; "
            .. "disable it, this addon covers the same thing.")
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("AutoAbandonQuests_SV", 1, nil, defaults)
    -- 1.0 on/off settings, replaced by the multi-selects
    sv.darkBrotherhood, sv.battlegrounds, sv.bounty, sv.conquest = nil, nil, nil, nil
    charLog = ZO_SavedVars:NewCharacterIdSettings("AutoAbandonQuests_SV", 1, "Completed", { done = {} })

    BuildSettingsPanel()

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_ADDED, OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_COMPLETE, OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CHATTER_BEGIN, OnChatterBegin)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CHATTER_END, OnChatterEnd)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_OFFERED, OnQuestOffered)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_CONVERSATION_UPDATED, OnConversationUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    SLASH_COMMANDS["/aaq"] = function(args)
        if zo_strlower(zo_strtrim(args or "")) == "info" then
            PrintStatus()
        elseif settingsPanel then
            LibAddonMenu2:OpenToPanel(settingsPanel)
        else
            Print("Settings need LibAddonMenu-2.0. Use |cFFCC44/aaq info|r for the status.")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddonLoaded)
