-- Questbound_Dungeon.lua : quests that take place in a group dungeon (pledges,
-- dungeon quests). Their objectives only count inside, so instead of just
-- walking to the entrance Questbound offers to queue for the dungeon in the
-- Group Finder (same calls as Set Hunter's queue, confirmed in-game).

local W = Questbound
local L = W.L
local D = {}
W.Dungeon = D

local DIALOG = "QUESTBOUND_QUEUE"
D.ICON = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds"

local cache = {}   -- [questIndex] = info or false (journal indexes change: cleared on quest updates)

local function Alert(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
end

local function Squash(text)
    text = zo_strlower(zo_strformat("<<1>>", text or ""))
    text = text:gsub("^the%s+", "")
    return (text:gsub("[^%w]", ""))
end

local function ActivityName(activityId)
    if GetActivityName then return GetActivityName(activityId) end
    return (GetActivityInfo(activityId))
end

-- Group Finder activity of a dungeon zone (nil if it has none).
local function FindActivity(zoneId, zoneName, veteran)
    local activityType = veteran and LFG_ACTIVITY_MASTER_DUNGEON or LFG_ACTIVITY_DUNGEON
    if not activityType then return nil end
    local wanted = Squash(zoneName)
    for i = 1, GetNumActivitiesByType(activityType) do
        local activityId = GetActivityIdByTypeAndIndex(activityType, i)
        if GetActivityZoneId and GetActivityZoneId(activityId) == zoneId then return activityId end
        local name = Squash(ActivityName(activityId)):gsub("^veteran", "")
        if wanted ~= "" and name == wanted then return activityId end
    end
end

-- All normal dungeons of the Group Finder: { id, key = squashed name, name }.
local dungeonList
local function Dungeons()
    if not dungeonList then
        dungeonList = {}
        if LFG_ACTIVITY_DUNGEON then
            for i = 1, GetNumActivitiesByType(LFG_ACTIVITY_DUNGEON) do
                local id = GetActivityIdByTypeAndIndex(LFG_ACTIVITY_DUNGEON, i)
                local name = zo_strformat("<<1>>", ActivityName(id))
                dungeonList[#dungeonList + 1] = { id = id, key = Squash(name), name = name }
            end
        end
    end
    return dungeonList
end

-- Dungeon named in a text ("Pledge: Crypt of Hearts II" -> Crypt of Hearts II).
-- The longest name wins, so "Crypt of Hearts II" beats "Crypt of Hearts I".
local function DungeonInText(texts)
    local best
    for _, text in ipairs(texts) do
        local key = Squash(text)
        if key ~= "" then
            for _, d in ipairs(Dungeons()) do
                if d.key ~= "" and key:find(d.key, 1, true) and (not best or #d.key > #best.key) then best = d end
            end
        end
    end
    return best
end

-- Texts that may name the quest's dungeon: its name, and for quests the game marks
-- as dungeon quests also the current step and objectives.
local function QuestTexts(qi)
    local name, _, stepText, _, _, _, _, _, _, _, instanceDisplayType = GetJournalQuestInfo(qi)
    local texts = { name }
    if INSTANCE_DISPLAY_TYPE_DUNGEON and instanceDisplayType == INSTANCE_DISPLAY_TYPE_DUNGEON then
        texts[#texts + 1] = stepText
        local _, _, _, _, numConditions = GetJournalQuestStepInfo(qi, 1)
        for cond = 1, numConditions or 0 do
            texts[#texts + 1] = (GetJournalQuestConditionInfo(qi, 1, cond))
        end
    end
    return texts
end

-- Dungeon info for a quest, or nil when it isn't a group dungeon quest.
-- info.inside = you're in that dungeon now.
function D.Info(qi)
    if not qi or not IsValidQuestIndex(qi) then return nil end
    local info = cache[qi]
    if info == nil then
        info = false
        -- 1) the journal places the quest in a dungeon
        local zoneName, _, zoneIndex = GetJournalQuestLocationInfo(qi)
        if zoneIndex and zoneIndex > 0 then
            local zoneId = GetZoneId(zoneIndex)
            local normal = FindActivity(zoneId, zoneName, false)
            if normal then
                info = {
                    zoneId = zoneId, name = zo_strformat("<<1>>", zoneName),
                    normal = normal, veteran = FindActivity(zoneId, zoneName, true),
                }
            end
        end
        -- 2) the quest names a dungeon (pledges are placed where you got them);
        -- 3) or the journal's place for it does: story quests of a dungeon ("The Plan")
        --    sit in the overland zone with the place "Dungeon: The Banished Cells II"
        if not info then
            local texts = QuestTexts(qi)
            local _, place, placeZone, poiIndex = GetJournalQuestLocationInfo(qi)
            if place and place ~= "" then texts[#texts + 1] = place end
            if placeZone and poiIndex and poiIndex > 0 then texts[#texts + 1] = (GetPOIInfo(placeZone, poiIndex)) end
            local d = DungeonInText(texts)
            if d then
                local zoneId = GetActivityZoneId and GetActivityZoneId(d.id) or 0
                info = {
                    zoneId = zoneId, name = d.name,
                    normal = d.id, veteran = FindActivity(zoneId, d.name, true),
                }
            end
        end
        cache[qi] = info
    end
    if not info then return nil end
    local here = GetUnitZoneIndex("player")
    info.inside = (info.zoneId ~= 0 and GetZoneId(here) == info.zoneId)
        or Squash(GetZoneNameByIndex(here)) == Squash(info.name)
    return info
end

-- PvP zones (Cyrodiil, Imperial City and its sewers): you get there through the
-- Alliance War campaigns, not by wayshrine.
local PVP_ZONES = { [181] = true, [584] = true, [643] = true }

function D.IsPvPQuest(qi)
    if not qi or not IsValidQuestIndex(qi) then return false end
    local _, _, zoneIndex = GetJournalQuestLocationInfo(qi)
    return zoneIndex ~= nil and zoneIndex > 0 and PVP_ZONES[GetZoneId(zoneIndex)] == true
end

-- The Alliance War window (campaign browser), to pick a campaign by hand.
D.PVP_ICON = "EsoUI/Art/MainMenu/menuBar_ava_up.dds"
local function OpenAllianceWar()
    local ok = MAIN_MENU_KEYBOARD and pcall(function() MAIN_MENU_KEYBOARD:ShowScene("campaignBrowser") end)
    if not ok then pcall(function() SCENE_MANAGER:Show("campaignBrowser") end) end
end

-- Name of your home Cyrodiil campaign ("" when you have none).
function D.HomeCampaignName()
    local id = GetAssignedCampaignId and GetAssignedCampaignId() or 0
    if id == 0 then return "" end
    return zo_strformat("<<1>>", GetCampaignName(id))
end

-- PvP quest: join your home Cyrodiil campaign through the game's own queue flow
-- (CAMPAIGN_BROWSER_MANAGER, which asks alone / with group and warns about alliance
-- locks, like the Alliance War window). No home campaign, can't queue now (already
-- queued, in a battleground...) or Imperial City: open the Alliance War window.
function D.JoinPvP(qi)
    if not qi or not IsValidQuestIndex(qi) then return end
    local _, _, zoneIndex = GetJournalQuestLocationInfo(qi)
    local zoneId = zoneIndex and zoneIndex > 0 and GetZoneId(zoneIndex)
    local mgr = CAMPAIGN_BROWSER_MANAGER
    if zoneId == 181 and mgr and D.HomeCampaignName() ~= "" then
        local ok, data = pcall(mgr.GetMasterHomeData, mgr)
        if ok and data then
            local okCan, canQueue = pcall(mgr.CanQueueForCampaign, mgr, data)
            if okCan and canQueue and pcall(mgr.DoQueueForCampaign, mgr, data) then return end
        end
    end
    OpenAllianceWar()
end

-- Quest in a dungeon you're not in = time to queue.
function D.NeedsQueue(qi)
    local info = D.Info(qi)
    return info ~= nil and not info.inside, info
end

local function MeetsRequirement(activityId)
    local _, levelMin, _, cpMin = GetActivityInfo(activityId)
    return GetUnitLevel("player") >= (levelMin or 0)
        and ((cpMin or 0) == 0 or GetUnitChampionPoints("player") >= cpMin)
end

local function MissingDLC(activityId)
    if not GetRequiredActivityCollectibleId then return nil end
    local id = GetRequiredActivityCollectibleId(activityId)
    if id and id ~= 0 and not IsCollectibleUnlocked(id) then
        return zo_strformat("<<1>>", GetCollectibleName(id))
    end
end

-- Veteran when the game is set to veteran and you can do it, else normal.
local function PickDifficulty(info)
    local vet = IsUnitUsingVeteranDifficulty and IsUnitUsingVeteranDifficulty("player")
    if vet and info.veteran and MeetsRequirement(info.veteran) then return true, info.veteran end
    return false, info.normal
end

local function RoleName()
    local role = GetSelectedLFGRole and GetSelectedLFGRole() or LFG_ROLE_DPS
    return GetString("SI_LFGROLE", role)
end

function D.Queue(info, veteran, activityId)
    if IsCurrentlySearchingForGroup and IsCurrentlySearchingForGroup() then
        Alert(L("QUEUE_ALREADY"))
        return
    end
    if IsUnitGrouped("player") and not IsUnitGroupLeader("player") then
        Alert(L("QUEUE_LEADER"))
        return
    end
    local ok = pcall(function()
        ClearActivityFinderSearch()
        AddActivityFinderSpecificSearchEntry(activityId)
        StartActivityFinderSearch()
    end)
    if ok then
        W.Print(L("QUEUED", info.name, L(veteran and "VETERAN" or "NORMAL")))
    else
        Alert(L("QUEUE_FAIL"))
    end
end

-- "This quest counts inside <dungeon>: queue for it?"
function D.Offer(qi)
    local needs, info = D.NeedsQueue(qi)
    if not needs then return false end
    local veteran, activityId = PickDifficulty(info)
    local dlc = MissingDLC(activityId)
    if dlc then
        Alert(L("QUEUE_DLC", info.name, dlc))
        return true
    end
    ZO_Dialogs_ShowDialog(DIALOG, { info = info, veteran = veteran, activityId = activityId }, {
        titleParams = { info.name },
        mainTextParams = { L("QUEUE_TEXT", info.name, L(veteran and "VETERAN" or "NORMAL"), RoleName()) },
    })
    return true
end

function D.Init()
    local function Clear() ZO_ClearTable(cache) end
    W.callbacks:RegisterCallback("QuestsChanged", Clear)
    W.callbacks:RegisterCallback("MapChanged", Clear)
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        buttons = {
            {
                text = L("QUEUE_GO"),
                callback = function(dialog)
                    local data = dialog.data
                    if data then D.Queue(data.info, data.veteran, data.activityId) end
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    })
end
