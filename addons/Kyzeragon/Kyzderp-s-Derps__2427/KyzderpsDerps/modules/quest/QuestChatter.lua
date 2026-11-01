local KD = KyzderpsDerps
KD.Quests = {
    Chatter = {},
}
local Quests = KD.Quests
local Chatter = Quests.Chatter

---------------------------------------------------------------------
-- Dialogue that should be handled, by title first
---------------------------------------------------------------------
-- Dialogue options to advance (only first option is checked; are there any options that aren't first?)
local optionsToAdvance = {
    ["-Armorer Reistaff-"] = {
        ["What can I do to help?"] = true,
    },
    -- ["-Breda-"] = {
    --     ["What's another way people celebrate the New Life Festival?"] = true,
    -- },
}

-- Quest options for which we should accept the quest
local questOptionToAccept = {
    ["-Armorer Reistaff-"] = {
        ["How many do you need?"] = true,
        ["All right. I'll make three restoration staves."] = true,
        
        ["How many shields do you need?"] = true,
        ["All right. I'll make two shields."] = true,

        ["How many bows will we need?"] = true,
        ["All right. I'll make three bows."] = true,

        ["What kind of armor do you need?"] = true,
        ["All right. I'll craft two cuirasses."] = true,

        ["What do you need from me?"] = true,
        ["All right. I'll craft two helms."] = true,

        ["What kind of weapons do you need?"] = true,
        ["All right. I'll craft three axes."] = true,

        ["Why won't your friends replace their damaged armor?"] = true,
        ["All right. I'll make two epaulets."] = true,

        ["What do you need?"] = true,
        ["All right. I'll make two arm cops."] = true,

        ["How many jacks do you need?"] = true,
        ["All right. I'll make two jacks."] = true,
    },
    -- ["-Breda-"] = {
    --     ["All right, I'll head to Rawl'kha."] = true,
    -- },
    ["-Tip Board-"] = {
        ["<Read the contract.>"] = true,
        ["<Make a note of the requested items.>"] = true,
    },
}

-- Quest options for which we should reset the dialogue
local questOptionToReset = {
    ["-Armorer Reistaff-"] = {
        ["How many potions do you need?"] = true,
        ["What kind of enchantments are you looking for?"] = true,
        ["What kind of provisions do you need me to make?"] = true,
    },
    -- ["-Breda-"] = {
    --     ["How would I do that?"] = true,
    --     ["What sort of pin?"] = true,
    --     ["All right, I'll head to Bergama."] = true,
    --     ["What sort of performances?"] = true,
    --     ["Who is this year's target?"] = true,
    --     ["All right, I'll celebrate the Stonetooth Bash."] = true,
    --     ["All right, I'll walk the War Orphan's Sojourn."] = true,
    --     ["That sounds simple enough. What would I do?"] = true,
    -- },
    ["-Tip Board-"] = {
        ["<Keep reading.>"] = true,
        ["<Make a note of the request.>"] = true,
    },
}

-- Dialogue titles for which to turn in dialogue
local questTurnIns = {
    ["-Armorer Reistaff-"] = true,
    ["-Kari-"] = true,
}

-- Quest options to prioritize, will continue rerolling until one of these is met
-- TODO: this currently doesn't advance the next step of quest, leaving user to
-- accept it manually
local priorityQuestOptions = {
    ["-Armorer Reistaff-"] = {
        ["How many potions do you need?"] = true,
        ["What kind of enchantments are you looking for?"] = true,
        ["What kind of provisions do you need me to make?"] = true,
    },
}


---------------------------------------------------------------------
local function GetTitleAndBody()
    if (IsInGamepadPreferredMode()) then
        return "-" .. ZO_InteractWindow_GamepadTitle:GetText() .. "-", ZO_InteractWindow_GamepadContainerText:GetText()
    else
        return ZO_InteractWindowTargetAreaTitle:GetText(), ZO_InteractWindowTargetAreaBodyText:GetText()
    end
end

---------------------------------------------------------------------
-- Quest offered handler, called immediately after advancing dialogue
-- Can be called multiple times because the quest could have multiple
-- dialogues before actually being accepted
---------------------------------------------------------------------
local MAX_RETRIES = 20
local numRetries = 0

local function OnQuestOffered()
    local title = GetTitleAndBody()

    local dialogue, response = GetOfferedQuestInfo()

    -- If priority quest has not been done, only accept priority quests
    -- TODO: reset automatically per day
    if (KD.savedOptions.chatter.usePriority and not KD.savedOptions.chatter.priorityDoneToday and priorityQuestOptions[title]) then
        -- TODO: refactor
        if (priorityQuestOptions[title][response]) then
            KD:msg("Accepting PRIORITY quest: " .. response)
            AcceptOfferedQuest()
            KD.savedOptions.chatter.priorityDoneToday = true
            -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
        else
            -- Always reset if not priority quest
            if (numRetries > MAX_RETRIES) then
                KD:msg("Stopping rerolling because exceeded max tries")
                -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
                return
            end
            KD:msg("Rerolling dialogue because not PRIORITY: " .. response)
            numRetries = numRetries + 1
            ResetChatter()
            -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
        end
        return
    end

    -- Accept based on option text
    if (questOptionToAccept[title] and questOptionToAccept[title][response]) then
        KD:msg("Accepting quest: " .. response)
        AcceptOfferedQuest()
        -- Don't unregister quest offered yet; it could have more steps before actually accepting
        -- Instead, just listen for quest added, and if so end the interaction, which unregisters
        -- TODO: could have issues with other addons that auto accept quests while we're in dialogue?
        EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterQuestAdded", EVENT_QUEST_ADDED, function()
            EndInteraction(INTERACTION_CONVERSATION)
            KD:msg("Chatter ended.")
        end)

    -- Reset based on option text
    elseif (questOptionToReset[title] and questOptionToReset[title][response]) then
        if (numRetries > MAX_RETRIES) then
            KD:msg("Stopping rerolling because exceeded max tries")
            -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
            return
        end
        -- zo_callLater(function()
            KD:msg("Rerolling dialogue because: " .. response)
            numRetries = numRetries + 1
            ResetChatter()
            -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
        -- end, 2000)

    -- Unregister handler if nothing matches: user gets to deal with it
    else
        -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
    end
end

function Chatter.ResetPriority()
    KD.savedOptions.chatter.priorityDoneToday = false
    KD:msg("Priority rerolling reset")
end


---------------------------------------------------------------------
-- Quest turn-in, should be the final step of it
---------------------------------------------------------------------
local function OnQuestCompleteDialog(_, journalIndex)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestCompleting", EVENT_QUEST_COMPLETE_DIALOG)
    KD:msg("Completing quest, was journalIndex: " .. tostring(journalIndex))
    CompleteQuest()
end

---------------------------------------------------------------------
-- Chatter start handler. This is just for "normal" chatter, and
-- doesn't include the starting of quests
---------------------------------------------------------------------
local function OnChatter()
    local optionCount = GetChatterOptionCount()
    if (optionCount == 0) then return end

    -- Checking only first option should be fine?
    local optionString, optionType = GetChatterOption(1)

    local title, body = GetTitleAndBody()

    -- Accept based on option text
    if (optionsToAdvance[title] and optionsToAdvance[title][optionString]) then
        KD:msg("Advancing dialogue: " .. optionString)
        SelectChatterOption(1)
        -- if (optionType == CHATTER_START_NEW_QUEST_BESTOWAL) then
        --     EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED, OnQuestOffered)
        -- end

    -- Quest turn-in (start)
    elseif (questTurnIns[title] and (optionType == CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS or optionType == CHATTER_START_COMPLETE_QUEST)) then
        KD:msg("Advancing quest turn-in: " .. optionString)
        SelectChatterOption(1)
        EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterQuestCompleting", EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    end
end


---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
function Chatter.Initialize()
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterBegin", EVENT_CHATTER_BEGIN)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterEnd", EVENT_CHATTER_END)
    EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)

    -- TODO: extend this to other dialogues? what else is there that could save some time?
    if (KD.savedOptions.chatter.rerollReistaff) then
        EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterBegin", EVENT_CHATTER_BEGIN, OnChatter)
        EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterEnd", EVENT_CHATTER_END, function()
            -- EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED)
            EVENT_MANAGER:UnregisterForEvent(KD.name .. "ChatterQuestAdded", EVENT_QUEST_ADDED)
            numRetries = 0
        end)
        EVENT_MANAGER:RegisterForEvent(KD.name .. "ChatterQuestOffered", EVENT_QUEST_OFFERED, OnQuestOffered)
    end
end

function Quests.GetSettings()
    return {
        {
            type = "checkbox",
            name = "Reroll for Covetous Countess",
            tooltip = "When you interact with the Thieves Guild tip board, automatically accepts or rerolls the quest until you get Covetous Countess, and turns in quests. English client only.\n\nYou can adjust this or add different languages in KyzderpsDerps/modules/questchatter/QuestChatter.lua",
            default = false,
            getFunc = function() return KD.savedOptions.chatter.rerollReistaff end,
            setFunc = function(value)
                    KD.savedOptions.chatter.rerollReistaff = value
                    Chatter.Initialize()
                end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Warn master writ experience",
            tooltip = "When you accept a master writ quest, warns you in chat if you do not have the Apprentice Mundus and/or an XP scroll active",
            default = false,
            getFunc = function() return KD.savedOptions.writs.warnMasterWritXP end,
            setFunc = function(value)
                    KD.savedOptions.writs.warnMasterWritXP = value
                    Quests.Writs.Initialize()
                end,
            width = "full",
        },
        {
            type = "description",
            title = "|c08BD1DAlchemy Writs|r",
            text = "Stop accidentally wasting Columbine on daily alchemy writs.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Warn multi-effect Essences of Health",
            tooltip = "When you pick up the daily writ quest that requires Essence of Health (quest ID 6101), displays a message in chat if you have Essences of Health in your inventory that have a certain number of effects, specified below. This is to help avoid wasting tri-stat pots on writ turn-ins",
            default = false,
            getFunc = function() return KD.savedOptions.writs.warnEssenceOfHealth end,
            setFunc = function(value)
                    KD.savedOptions.writs.warnEssenceOfHealth = value
                    Quests.Writs.Initialize()
                end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Deposit multi-effect Essences of Health",
            tooltip = "When you have a daily writ quest that requires Essence of Health (quest ID 6101) and you interact with a bank, deposits the Essences of Health in your inventory that have a certain number of effects, specified below. This is to help avoid wasting tri-stat pots on writ turn-ins",
            default = false,
            getFunc = function() return KD.savedOptions.writs.depositEssenceOfHealth end,
            setFunc = function(value)
                    KD.savedOptions.writs.depositEssenceOfHealth = value
                    Quests.Writs.Initialize()
                end,
            width = "full",
        },
        {
            type = "slider",
            name = "Number of effects",
            tooltip = "The minimum number of effects an Essence of Health should have to be considered expensive. For example, if this setting is set to 2, then Essences of Health that have 2 or 3 effects will show warnings or be deposited in your bank",
            min = 1,
            max = 3,
            step = 1,
            default = 2,
            width = "full",
            getFunc = function() return KD.savedOptions.writs.numEssenceOfHealthEffects end,
            setFunc = function(value)
                KD.savedOptions.writs.numEssenceOfHealthEffects = value
            end,
            disabled = function() return not KD.savedOptions.writs.warnEssenceOfHealth and not KD.savedOptions.writs.depositEssenceOfHealth end,
        },
    }
end
