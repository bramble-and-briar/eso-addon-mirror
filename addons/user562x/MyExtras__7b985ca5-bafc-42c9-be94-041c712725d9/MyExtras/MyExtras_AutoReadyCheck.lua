local ME = MyExtras
local QoL = ME.QualityOfLife
local ARC = {}
ME.AutoReadyCheck = ARC

--------------------------------------------------
-- Config
--------------------------------------------------
local EVENT_NAME = ME.name .. "_AutoReadyCheck"

local DEFAULTS = {
    arcBattlegrounds  = false,
    arcArchive        = false,
    arcDungeon        = false,
    arcVetDungeon     = false,
    arcArena          = false,
    arcTrial          = false,
    arcTributeCasual  = false,
    arcTributeRanked  = false,
    arcHomeShow       = false,
    arcCampaign       = false,
    arcGroup          = false,
}
QoL:AddDefaults(DEFAULTS)

ARC.activityChoices = {
    { name = "Battlegrounds",               value = "arcBattlegrounds" },
    { name = "Infinite Archive",            value = "arcArchive"       },
    { name = "Normal Dungeons",             value = "arcDungeon"       },
    { name = "Veteran Dungeons",            value = "arcVetDungeon"    },
    { name = "Arenas",                      value = "arcArena"         },
    { name = "Trials",                      value = "arcTrial"         },
    { name = "Tales of Tribute (Casual)",   value = "arcTributeCasual" },
    { name = "Tales of Tribute (Ranked)",   value = "arcTributeRanked" },
    { name = "Home Show",                   value = "arcHomeShow"      },
}

local ACTIVITY_KEYS = {
    { "LFG_ACTIVITY_BATTLE_GROUND_CHAMPION",     "arcBattlegrounds" },
    { "LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION", "arcBattlegrounds" },
    { "LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL",    "arcBattlegrounds" },
    { "LFG_ACTIVITY_ENDLESS_DUNGEON",            "arcArchive"       },
    { "LFG_ACTIVITY_DUNGEON",                    "arcDungeon"       },
    { "LFG_ACTIVITY_MASTER_DUNGEON",             "arcVetDungeon"    },
    { "LFG_ACTIVITY_ARENA",                      "arcArena"         },
    { "LFG_ACTIVITY_TRIAL",                      "arcTrial"         },
    { "LFG_ACTIVITY_TRIBUTE_CASUAL",             "arcTributeCasual" },
    { "LFG_ACTIVITY_TRIBUTE_COMPETITIVE",        "arcTributeRanked" },
    { "LFG_ACTIVITY_HOME_SHOW",                  "arcHomeShow"      },
}

local activityToKey

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return QoL:Settings()
end

local function ActivityMap()
    if activityToKey then return activityToKey end
    activityToKey = {}
    for i = 1, #ACTIVITY_KEYS do
        local activity = rawget(_G, ACTIVITY_KEYS[i][1])
        if activity ~= nil then activityToKey[activity] = ACTIVITY_KEYS[i][2] end
    end
    return activityToKey
end

local function AnyActivity()
    local sv = SV()
    for i = 1, #ARC.activityChoices do
        if sv[ARC.activityChoices[i].value] then return true end
    end
    return false
end

local function ReadyCheckDescriptor()
    local descriptors = rawget(_G, "ZO_GROUP_ELECTION_DESCRIPTORS")
    return descriptors and descriptors.READY_CHECK or "[ZO_READY_CHECK]"
end

--------------------------------------------------
-- Activity Finder
--------------------------------------------------
local function OnFinderStatus(_, status)
    if status ~= ACTIVITY_FINDER_STATUS_READY_CHECK then return end
    if not AnyActivity() then return end
    local ok, activity = pcall(GetLFGReadyCheckActivityType)
    if not ok then return end
    local key = ActivityMap()[activity]
    if key and SV()[key] then
        AcceptLFGReadyCheckNotification()
    end
end

--------------------------------------------------
-- Campaigns
--------------------------------------------------
local function OnCampaignQueue(_, campaignId, isGroup, state)
    if state ~= CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then return end
    if not SV().arcCampaign then return end
    ConfirmCampaignEntry(campaignId, isGroup, true)
end

--------------------------------------------------
-- Group Ready Checks
--------------------------------------------------
local function OnElectionAdded()
    if not SV().arcGroup then return end
    if not HasPendingGroupElectionVote() then return end
    local _, _, descriptor = GetGroupElectionInfo()
    if descriptor ~= ReadyCheckDescriptor() then return end
    CastGroupVote(GROUP_VOTE_CHOICE_FOR)
end

--------------------------------------------------
-- Apply
--------------------------------------------------
local function Watch(name, event, handler, on)
    if on then
        EVENT_MANAGER:RegisterForEvent(name, event, handler)
    else
        EVENT_MANAGER:UnregisterForEvent(name, event)
    end
end

function ARC:Refresh()
    local sv = SV()
    Watch(EVENT_NAME .. "_Finder", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, OnFinderStatus, AnyActivity())
    Watch(EVENT_NAME .. "_Campaign", EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, OnCampaignQueue, sv.arcCampaign == true)
    Watch(EVENT_NAME .. "_Group", EVENT_GROUP_ELECTION_NOTIFICATION_ADDED, OnElectionAdded, sv.arcGroup == true)
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function ARC:SubmenuOption()
    return {
        type    = "submenu",
        name    = "Auto Ready Check",
        tooltip = "Accepts queues and ready checks for you.",
        options = {
            {
                type    = "checklist",
                name    = "Activity Finder",
                choices = self.activityChoices,
                default = {},
                tooltip = "Accepts the ready check for these when your queue pops.",
                getFunc = function()
                    local sv = SV()
                    local values = {}
                    for i = 1, #ARC.activityChoices do
                        local key = ARC.activityChoices[i].value
                        if sv[key] then values[#values + 1] = key end
                    end
                    return values
                end,
                setFunc = function(values)
                    local sv = SV()
                    local set = {}
                    if type(values) == "table" then
                        for i = 1, #values do set[values[i]] = true end
                    end
                    for i = 1, #ARC.activityChoices do
                        local key = ARC.activityChoices[i].value
                        sv[key] = set[key] == true
                    end
                    ARC:Refresh()
                end,
            },
            {
                type    = "toggle",
                name    = "AvA Campaigns",
                preset  = "YES_NO",
                default = DEFAULTS.arcCampaign,
                tooltip = "Enters your campaign for you when your Alliance War queue pops.",
                getFunc = function() return SV().arcCampaign end,
                setFunc = function(val)
                    SV().arcCampaign = val
                    ARC:Refresh()
                end,
            },
            {
                type    = "toggle",
                name    = "Group Ready Checks",
                preset  = "YES_NO",
                default = DEFAULTS.arcGroup,
                tooltip = "Says you're ready when someone in your group starts a ready check. "
                       .. "Other group votes, like kicks or a new leader, are left for you.",
                getFunc = function() return SV().arcGroup end,
                setFunc = function(val)
                    SV().arcGroup = val
                    ARC:Refresh()
                end,
            },
        },
    }
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function ARC:Init()
    self:Refresh()
end

function ARC:OnPlayerActivated()
    self:Refresh()
end

function ARC:OnReset()
    self:Refresh()
end

ME:RegisterFeature(ARC)
