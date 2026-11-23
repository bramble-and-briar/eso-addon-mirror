-- Lethal PVP Insights - General helpers: hand in finished quests automatically when you talk to the
-- quest giver, and remind you when you have no food / drink buff
local PDI = PVPDataInsight
local Q = {}
PDI.Quests = Q

local function mode() return PDI.sv.settings.autoQuest or "off" end

local function allowedHere()
    local m = mode()
    if m == "all" then return true end
    if m == "pvp" then return IsPlayerInAvAWorld() or IsActiveWorldBattleground() end
    return false
end

local COMPLETE = {}
for _, k in ipairs({ "CHATTER_COMPLETE_QUEST", "CHATTER_START_COMPLETE_QUEST" }) do
    if _G[k] then COMPLETE[_G[k]] = true end
end

-- choose the "hand in" line of the conversation
local function onChatter(_, optionCount)
    if not allowedHere() or IsShiftKeyDown() then return end
    for i = 1, optionCount or GetChatterOptionCount() do
        local _, optType = GetChatterOption(i)
        if COMPLETE[optType] then SelectChatterOption(i); return end
    end
end

-- the reward screen: finish the quest unless it asks you to choose a reward
local function onComplete(_, journalIndex)
    if not allowedHere() or IsShiftKeyDown() then return end
    if journalIndex and GetJournalQuestNumRewards then
        for r = 1, GetJournalQuestNumRewards(journalIndex) do
            local ok, _, _, _, _, _, _, isChoice = pcall(GetJournalQuestRewardInfo, journalIndex, r)
            if ok and isChoice then return end
        end
    end
    CompleteQuest()
end

-- ---------------------------------------------------------------- food / drink reminder
-- food and drink buff ability ids (the list LibFoodDrinkBuff uses)
local FOOD_IDS = {
    [17407]=1, [17577]=1, [17581]=1, [17608]=1, [17614]=1, [61218]=1, [61255]=1, [61257]=1, [61259]=1, [61260]=1,
    [61261]=1, [61294]=1, [61322]=1, [61325]=1, [61328]=1, [61335]=1, [61340]=1, [61345]=1, [61350]=1, [66125]=1,
    [66128]=1, [66130]=1, [66132]=1, [66137]=1, [66141]=1, [66551]=1, [66568]=1, [66576]=1, [66586]=1, [66590]=1,
    [66594]=1, [68411]=1, [68416]=1, [72816]=1, [72819]=1, [72822]=1, [72824]=1, [72956]=1, [72959]=1, [72961]=1,
    [72965]=1, [72968]=1, [72971]=1, [84678]=1, [84681]=1, [84700]=1, [84704]=1, [84709]=1, [84720]=1, [84725]=1,
    [84731]=1, [84732]=1, [84733]=1, [84735]=1, [84736]=1, [85484]=1, [85497]=1, [86559]=1, [86560]=1, [86673]=1,
    [86674]=1, [86677]=1, [86678]=1, [86746]=1, [86747]=1, [86749]=1, [86787]=1, [86789]=1, [86791]=1, [89955]=1,
    [89957]=1, [89971]=1, [92433]=1, [92435]=1, [92437]=1, [92474]=1, [92476]=1, [92477]=1, [100488]=1, [100498]=1,
    [100502]=1, [107748]=1, [107789]=1, [127531]=1, [127537]=1, [127572]=1, [127578]=1, [127596]=1, [127619]=1, [127736]=1,
    [148633]=1,
}
local FOOD_MIN_SECONDS = 20 * 60          -- food and drink last 30 min - 2 h; potions and procs much less
local NOT_FOOD = { "experience", "scroll", "ambrosia", "skill gain", "vampir", "lycanthropy", "boon" }
local FOOD_WORDS = { "^increase", "recovery", "max ", "health", "magicka", "stamina", "stats" }

-- known food / drink first; otherwise a long buff that sounds like food (new foods not in the list yet)
local function isFood(name, started, ending, id)
    if id and FOOD_IDS[id] then return true end
    if not (ending and started) or ending - started < FOOD_MIN_SECONDS then return false end
    local n = zo_strlower(name or "")
    for _, w in ipairs(NOT_FOOD) do if n:find(w, 1, true) then return false end end
    for _, w in ipairs(FOOD_WORDS) do if n:find(w) then return true end end
    return false
end

function Q:HasFood()
    for i = 1, GetNumBuffs("player") do
        local name, started, ending, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if isFood(name, started, ending, id) then return true, name end
    end
    return false
end

-- manual = /lpi foodcheck (always answers)
function Q:FoodCheck(manual)
    local s = PDI.sv.settings
    local has, name = self:HasFood()
    if manual then
        PDI.Msg(has and ("Food buff: |c66DD66" .. zo_strformat("<<1>>", name) .. "|r") or "|cFF6655No food buff.|r")
        return
    end
    if not s.foodNotice or IsUnitDead("player") then return end
    if s.foodPvPOnly ~= false and not (IsPlayerInAvAWorld() or IsActiveWorldBattleground()) then return end
    if has then self.foodWarned = nil; return end
    local now = GetFrameTimeSeconds()
    if self.foodWarned and now - self.foodWarned < 300 then return end      -- at most every 5 minutes
    self.foodWarned = now
    -- on screen (the same big text as the Break Free alert) with a sound, and / or in chat
    local how = s.foodAlert or "both"
    if how ~= "chat" then
        local shown = LPI_PvPTools and LPI_PvPTools.ShowScreenAlert and
            pcall(LPI_PvPTools.ShowScreenAlert, "NO FOOD BUFF!", 1, 0.55, 0.1, 4)
        if not shown then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "No food buff!") end
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)
    end
    if how ~= "screen" then PDI.Msg("|cFF6655No food buff!|r Eat or drink something.") end
end

function Q:Init()
    EVENT_MANAGER:RegisterForEvent("LPIQuests", EVENT_CHATTER_BEGIN, onChatter)
    EVENT_MANAGER:RegisterForEvent("LPIQuests", EVENT_CONVERSATION_UPDATED, function(_, _, optionCount) onChatter(nil, optionCount) end)
    EVENT_MANAGER:RegisterForEvent("LPIQuests", EVENT_QUEST_COMPLETE_DIALOG, onComplete)
    EVENT_MANAGER:RegisterForUpdate("LPIFood", 30000, function() Q:FoodCheck(false) end)
    EVENT_MANAGER:RegisterForEvent("LPIFood", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function() Q:FoodCheck(false) end, 5000)
    end)
end

function Q:GetOptions()
    return {
        { type = "header", name = "Quests" },
        {
            type = "dropdown", name = "Auto hand-in quests",
            tooltip = "When you talk to the quest giver of a finished quest, hand it in and take the reward automatically. " ..
                "Quests where you choose a reward are left to you. Hold Shift while talking to skip it once.\n\n" ..
                "PvP areas only: Cyrodiil, Imperial City and Battlegrounds.",
            choices = { "Off", "PvP areas only", "Everywhere" },
            choicesValues = { "off", "pvp", "all" },
            getFunc = mode,
            setFunc = function(v) PDI.sv.settings.autoQuest = v end,
        },
        { type = "header", name = "Food Buff" },
        {
            type = "checkbox", name = "Remind me when I have no food buff",
            tooltip = "Shows an alert and a chat message when you have no food or drink buff (checked every 30 seconds, " ..
                "at most one reminder every 5 minutes). /lpi foodcheck shows what was found.",
            getFunc = function() return PDI.sv.settings.foodNotice == true end,
            setFunc = function(v) PDI.sv.settings.foodNotice = v; Q.foodWarned = nil end,
        },
        {
            type = "dropdown", name = "Show the reminder",
            choices = { "On screen", "In chat", "On screen and in chat" },
            choicesValues = { "screen", "chat", "both" },
            getFunc = function() return PDI.sv.settings.foodAlert or "both" end,
            setFunc = function(v) PDI.sv.settings.foodAlert = v end,
            disabled = function() return PDI.sv.settings.foodNotice ~= true end,
        },
        {
            type = "checkbox", name = "Only in PvP areas",
            tooltip = "Remind only in Cyrodiil, Imperial City and Battlegrounds.",
            getFunc = function() return PDI.sv.settings.foodPvPOnly ~= false end,
            setFunc = function(v) PDI.sv.settings.foodPvPOnly = v end,
            disabled = function() return PDI.sv.settings.foodNotice ~= true end,
        },
    }
end
