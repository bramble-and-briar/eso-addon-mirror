-- ESO Adventurer Suite
-- v0.29.742 - correct skill-point totals / separate wayshrines
-- Current-character skill-point source tracker plus missing wayshrine discovery.
-- One top-level window, cached on demand, no permanent update loop.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER or not WINDOW_MANAGER then return end

EPC.SkillPointFinder = EPC.SkillPointFinder or {}
local F = EPC.SkillPointFinder
local DATA = EPC.SkillPointFinderData or {}
local EM, WM = EVENT_MANAGER, WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_SkillPointFinder029714"

local ROWS_PER_PAGE = 12
local W, H = 1220, 790
local TABS = {
    {"OVERVIEW", "OVERVIEW"},
    {"MISSING", "MISSING POINTS"},
    {"QUESTS", "QUESTS"},
    {"SKYSHARDS", "SKYSHARDS"},
    {"DUNGEONS", "DUNGEONS"},
    {"PUBLIC", "PUBLIC DUNGEONS"},
    {"WAYSHRINES", "TRAVEL NODES"},
}
local TAB_VALID = {}
for _, spec in ipairs(TABS) do TAB_VALID[spec[1]] = true end

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h,i,j = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a,b,c,d,e,f,g,h,i,j
end

local function clean(value)
    value = tostring(value or "")
    value = value:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    if value ~= "" and type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<C:1>>", value)
        if ok and formatted and formatted ~= "" then value = formatted end
    end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value) return string.lower(clean(value)) end
local function n(value, fallback) value=tonumber(value); if value==nil then return fallback or 0 end return value end

local function printMsg(text)
    if EPC and type(EPC.Print) == "function" then EPC:Print(text)
    elseif type(d) == "function" then d("[ESO Adventurer Suite] " .. tostring(text)) end
end

local function zoneName(zoneId)
    zoneId = n(zoneId, 0)
    if zoneId <= 0 then return "Unknown zone" end
    local name = clean(safe(GetZoneNameById, "", zoneId))
    return name ~= "" and name or ("Zone " .. tostring(zoneId))
end

local function parentZoneId(zoneId)
    local current = n(zoneId, 0)
    if current <= 0 or type(GetParentZoneId) ~= "function" then return current end
    local seen = {}
    for _ = 1, 8 do
        if seen[current] then break end
        seen[current] = true
        local p = n(safe(GetParentZoneId, 0, current), 0)
        if p <= 0 or p == current then break end
        current = p
    end
    return current
end

local function questDone(questId)
    questId = n(questId, 0)
    if questId <= 0 then return false end
    if type(HasCompletedQuest) == "function" then
        local ok, value = pcall(HasCompletedQuest, questId)
        if ok then return value == true end
    end
    if type(GetCompletedQuestInfo) == "function" then
        local ok, value = pcall(GetCompletedQuestInfo, questId)
        if ok then return value ~= nil and value ~= "" end
    end
    return false
end

local function questName(questId)
    local name = clean(safe(GetQuestName, "", n(questId, 0)))
    return name ~= "" and name or ("Quest " .. tostring(questId))
end

local function questZoneId(questId, fallback)
    local zid = n(safe(GetQuestZoneId, 0, n(questId,0)), 0)
    if zid <= 0 then zid = n(fallback, 0) end
    return parentZoneId(zid)
end

local function achievementName(achievementId)
    local name = clean(safe(GetAchievementInfo, "", n(achievementId, 0)))
    return name ~= "" and name or ("Achievement " .. tostring(achievementId))
end

local function createBackdrop(parent, name, r,g,b,a, er,eg,eb,ea)
    local c = WM:CreateControl(name, parent, CT_BACKDROP)
    c:SetCenterColor(r,g,b,a)
    c:SetEdgeColor(er,eg,eb,ea)
    return c
end

local function label(parent, name, text, font, color)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetText(text or "")
    l:SetFont(font or "ZoFontGame")
    color = color or {1,1,1,1}
    l:SetColor(color[1],color[2],color[3],color[4] or 1)
    return l
end

local function button(parent, name, text, callback)
    local b = WM:CreateControl(name, parent, CT_BUTTON)
    b:SetFont("ZoFontGameBold")
    b:SetText(text or "")
    b:SetNormalFontColor(.84,.87,.93,1)
    b:SetMouseOverFontColor(1,.80,.20,1)
    b:SetPressedFontColor(1,.68,.12,1)
    if callback then b:SetHandler("OnClicked", callback) end
    return b
end

function F:GetSV()
    if not EPC.saved then return nil end
    EPC.saved.skillPointFinder029714 = EPC.saved.skillPointFinder029714 or {}
    local s = EPC.saved.skillPointFinder029714
    if not TAB_VALID[s.tab] then s.tab = "OVERVIEW" end
    if s.page == nil then s.page = 1 end
    if s.missingOnly == nil then s.missingOnly = true end
    return s
end

function F:YieldDeferredWork029715(weight)
    if not self.deferredSnapshotRunning029715 then return end

    self.deferredProbeUnits029716 = (tonumber(self.deferredProbeUnits029716) or 0) + (tonumber(weight) or 1)
    if self.deferredProbeUnits029716 < 8 then return end
    self.deferredProbeUnits029716 = 0

    local clock = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds or GetGameTimeMilliseconds
    if type(clock) ~= "function" then return end
    local now = clock()
    local started = tonumber(self.deferredSliceStarted029716) or now
    local inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
    local budgetMS = inCombat and 1 or 3

    if now - started >= budgetMS then
        coroutine.yield()
        self.deferredSliceStarted029716 = clock()
    end
end

function F:GetTotalOwnedSkillPoints()
    local total = n(safe(GetAvailableSkillPoints, 0), 0)
    if SKILL_POINT_ALLOCATION_MANAGER and SKILLS_DATA_MANAGER
        and type(SKILLS_DATA_MANAGER.SkillTypeIterator) == "function"
        and type(SKILL_POINT_ALLOCATION_MANAGER.GetNumPointsAllocatedInSkillLine) == "function" then
        local ok = pcall(function()
            for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
                for _, skillLineData in ipairs(skillTypeData.orderedSkillLines or {}) do
                    total = total + n(SKILL_POINT_ALLOCATION_MANAGER:GetNumPointsAllocatedInSkillLine(skillLineData), 0)
                end
            end
        end)
        if not ok then return n(safe(GetAvailableSkillPoints, 0), 0), false end
        return total, true
    end
    return total, false
end

function F:BuildActiveSkillPointQuestRows(seenQuestIds)
    local rows = {}
    if type(GetJournalQuestNumRewards) ~= "function" or type(GetJournalQuestRewardInfo) ~= "function" then return rows end
    local expected = n(safe(GetNumJournalQuests, 0), 0)
    local maxSlots = math.max(25, expected, n(rawget(_G,"MAX_JOURNAL_QUESTS"),0))
    maxSlots = math.min(math.max(maxSlots, 100), 200)
    for questIndex = 1, maxSlots do
        self:YieldDeferredWork029715(1)
        local qName = clean(safe(GetJournalQuestName, "", questIndex))
        if qName ~= "" then
            local questId = n(safe(GetJournalQuestId, 0, questIndex), 0)
            local rewards = n(safe(GetJournalQuestNumRewards, 0, questIndex), 0)
            local partial = 0
            for rewardIndex = 1, rewards do
                local rewardType, _, amount = safe(GetJournalQuestRewardInfo, nil, questIndex, rewardIndex)
                if rewardType ~= nil and REWARD_TYPE_PARTIAL_SKILL_POINTS ~= nil and rewardType == REWARD_TYPE_PARTIAL_SKILL_POINTS then
                    partial = partial + n(amount, 0)
                end
            end
            if partial > 0 and not seenQuestIds[questId] then
                local zid = questZoneId(questId, 0)
                if zid <= 0 and type(GetJournalQuestZoneStoryZoneId) == "function" then
                    zid = parentZoneId(n(safe(GetJournalQuestZoneStoryZoneId, 0, questIndex), 0))
                end
                local divisor = math.max(1, n(rawget(_G,"NUM_PARTIAL_SKILL_POINTS_FOR_FULL"), 1))
                rows[#rows+1] = {
                    kind="QUEST", category="ACTIVE SKILL QUEST", name=qName, zoneId=zid, zone=zoneName(zid),
                    done=false, progress="ACTIVE", points=partial/divisor, pointText=partial >= divisor and tostring(math.floor(partial/divisor)).." SP" or tostring(partial).."/"..tostring(divisor).." SP",
                    questId=questId, questIndex=questIndex, active=true, actionText="ROUTE",
                }
                if questId > 0 then seenQuestIds[questId] = true end
            end
        end
    end
    return rows
end

function F:BuildQuestRows()
    local rows, seen = {}, {}
    local function addQuest(category, questId, fallbackZoneId, points)
        self:YieldDeferredWork029715(1)
        questId = n(questId,0)
        if questId <= 0 or seen[questId] then return end
        seen[questId] = true
        local zid = questZoneId(questId, fallbackZoneId)
        rows[#rows+1] = {
            kind="QUEST", category=category, questId=questId, zoneId=zid, zone=zoneName(zid),
            name=questName(questId), done=questDone(questId), progress=questDone(questId) and "COMPLETE" or "MISSING",
            points=points or 1, pointText=(points or 1) == 1 and "1 SP" or tostring(points or 1).." SP",
            actionText="ROUTE",
        }
    end

    for _, id in ipairs(DATA.mainQuestIds or {}) do addQuest("MAIN QUEST", id, 0, 1) end
    for _, z in ipairs(DATA.zoneSkillPointQuests or {}) do
        for _, id in ipairs(z.questIds or {}) do addQuest("STORY QUEST", id, z.zoneId, 1) end
    end
    for _, id in ipairs(DATA.infiniteArchiveQuestIds or {}) do addQuest("INFINITE ARCHIVE", id, 0, 1) end

    local tutorialDone = false
    for _, id in ipairs(DATA.tutorialQuestIds or {}) do if questDone(id) then tutorialDone=true break end end
    rows[#rows+1] = {
        kind="QUEST", category="TUTORIAL", name="Tutorial Skill Point", zone="Tutorial", zoneId=0,
        done=tutorialDone, progress=tutorialDone and "COMPLETE" or "MISSING", points=1, pointText="1 SP",
        tutorialQuestIds=DATA.tutorialQuestIds, actionText="INFO",
    }

    for _, row in ipairs(self:BuildActiveSkillPointQuestRows(seen)) do rows[#rows+1]=row end
    table.sort(rows, function(a,b)
        if a.done ~= b.done then return a.done == false end
        if lower(a.zone) ~= lower(b.zone) then return lower(a.zone) < lower(b.zone) end
        return lower(a.name) < lower(b.name)
    end)
    return rows
end

function F:BuildSkyshardRows()
    local rows = {}
    local acquired, total = 0, 0
    if type(GetNumSkyshardsInZone) ~= "function" or type(GetZoneSkyshardId) ~= "function" then
        return rows, acquired, total
    end

    -- Build the zone set from live fast-travel nodes plus the current reference
    -- tables. This keeps new overland zones visible without depending on a
    -- particular client exposing a global GetNumZones iterator.
    local zoneIds = {}
    local function addZoneId(zid)
        zid = parentZoneId(n(zid,0))
        if zid > 0 then zoneIds[zid] = true end
    end
    for _, z in ipairs(DATA.zoneSkillPointQuests or {}) do addZoneId(z.zoneId) end
    for _, d in ipairs(DATA.groupDungeonQuests or {}) do addZoneId(d.parentZoneId) end
    for _, d in ipairs(DATA.publicDungeonEvents or {}) do addZoneId(d.parentZoneId) end

    if type(GetUnitZoneIndex)=="function" and type(GetZoneId)=="function" then
        local zi=n(safe(GetUnitZoneIndex,0,"player"),0)
        if zi>0 then addZoneId(safe(GetZoneId,0,zi)) end
    end

    local poiIndexFn=GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    if type(GetNumFastTravelNodes)=="function" and type(poiIndexFn)=="function" and type(GetZoneId)=="function" then
        local nodes=n(safe(GetNumFastTravelNodes,0),0)
        for nodeIndex=1,nodes do
            self:YieldDeferredWork029715(1)
            local zi=n(safe(poiIndexFn,0,nodeIndex),0)
            if zi>0 then addZoneId(safe(GetZoneId,0,zi)) end
        end
    end

    -- Compatibility supplement for clients that expose a zone-count iterator.
    if type(GetNumZones)=="function" and type(GetZoneId)=="function" then
        local count=n(safe(GetNumZones,0),0)
        for zoneIndex=1,count do
            self:YieldDeferredWork029715(1)
            addZoneId(safe(GetZoneId,0,zoneIndex))
        end
    end

    local ordered={}
    for zid in pairs(zoneIds) do ordered[#ordered+1]=zid end
    table.sort(ordered,function(a,b) return lower(zoneName(a))<lower(zoneName(b)) end)

    for _, zid in ipairs(ordered) do
        self:YieldDeferredWork029715(2)
        local num = n(safe(GetNumSkyshardsInZone, 0, zid), 0)
        if num > 0 then
            local zname=zoneName(zid)
            for shardIndex = 1, num do
                self:YieldDeferredWork029715(1)
                local shardId = n(safe(GetZoneSkyshardId, 0, zid, shardIndex), 0)
                if shardId > 0 then
                    total = total + 1
                    local status = safe(GetSkyshardDiscoveryStatus, nil, shardId)
                    local done = SKYSHARD_DISCOVERY_STATUS_ACQUIRED ~= nil and status == SKYSHARD_DISCOVERY_STATUS_ACQUIRED
                    -- ESO can award the Wailing Prison shard through the skipped-intro path
                    -- without marking the shard acquired. Treat the completed first Main Quest
                    -- as authoritative for that one legacy case.
                    if not done and zid == 809 and DATA.mainQuestIds and DATA.mainQuestIds[1]
                        and questDone(DATA.mainQuestIds[1]) then
                        done = true
                    end
                    if done then acquired=acquired+1 end
                    local hint = clean(safe(GetSkyshardHint, "", shardId))
                    if hint == "" then hint = "Skyshard " .. tostring(shardIndex) end
                    rows[#rows+1] = {
                        kind="SKYSHARD", category="SKYSHARD", name=hint, zoneId=zid,
                        zone=zname, done=done, progress=done and "ACQUIRED" or "MISSING",
                        points=1/3, pointText="1/3 SP", skyshardId=shardId, actionText="ROUTE",
                    }
                end
            end
        end
    end
    table.sort(rows, function(a,b)
        if a.done ~= b.done then return a.done == false end
        if lower(a.zone) ~= lower(b.zone) then return lower(a.zone)<lower(b.zone) end
        return lower(a.name)<lower(b.name)
    end)
    return rows, acquired, total
end

function F:BuildDungeonRows()
    local rows = {}
    for _, ref in ipairs(DATA.groupDungeonQuests or {}) do
        self:YieldDeferredWork029715(1)
        local qid = n(ref.questId,0)
        local dzid = n(ref.dungeonZoneId,0)
        local pzid = parentZoneId(n(ref.parentZoneId,0))
        local done = questDone(qid)
        rows[#rows+1] = {
            kind="DUNGEON", category="GROUP DUNGEON QUEST", name=zoneName(dzid),
            detail=questName(qid), questId=qid, dungeonZoneId=dzid, zoneId=pzid, zone=zoneName(pzid),
            done=done, progress=done and "COMPLETE" or "MISSING", points=1, pointText="1 SP", actionText="TP / ROUTE",
        }
    end
    table.sort(rows,function(a,b)
        if a.done~=b.done then return a.done==false end
        return lower(a.name)<lower(b.name)
    end)
    return rows
end

function F:BuildPublicDungeonRows()
    local rows = {}
    for _, ref in ipairs(DATA.publicDungeonEvents or {}) do
        self:YieldDeferredWork029715(1)
        local aid = n(ref.achievementId,0)
        local dzid = n(ref.publicDungeonZoneId,0)
        local pzid = parentZoneId(n(ref.parentZoneId,0))
        local done = aid>0 and safe(IsAchievementComplete,false,aid)==true
        rows[#rows+1] = {
            kind="PUBLIC", category="PUBLIC DUNGEON GROUP EVENT", name=zoneName(dzid),
            detail=achievementName(aid), achievementId=aid, publicDungeonZoneId=dzid,
            zoneId=pzid, zone=zoneName(pzid), done=done, progress=done and "COMPLETE" or "MISSING",
            points=1, pointText="1 SP", actionText="ROUTE",
        }
    end
    table.sort(rows,function(a,b)
        if a.done~=b.done then return a.done==false end
        return lower(a.name)<lower(b.name)
    end)
    return rows
end

function F:BuildWayshrineRows()
    local rows, knownCount, totalCount = {}, 0, 0
    if type(GetNumFastTravelNodes) ~= "function" or type(GetFastTravelNodeInfo) ~= "function" then
        return rows, knownCount, totalCount
    end
    local count = n(safe(GetNumFastTravelNodes,0),0)
    local poiIndexFn = GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    for nodeIndex=1,count do
        self:YieldDeferredWork029715(1)
        local known,name,_,_,_,_,poiType,_,locked = safe(GetFastTravelNodeInfo,false,nodeIndex)
        local isWayshrine = POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE
        if isWayshrine and locked ~= true then
            totalCount=totalCount+1
            if known == true then
                knownCount=knownCount+1
            else
                local zi=0
                if type(poiIndexFn)=="function" then zi=n(safe(poiIndexFn,0,nodeIndex),0) end
                local zid=zi>0 and n(safe(GetZoneId,0,zi),0) or 0
                zid=parentZoneId(zid)
                local zname=zi>0 and clean(safe(GetZoneNameByIndex,"",zi)) or ""
                if zname=="" then zname=zoneName(zid) end
                local shrine=clean(name)
                if shrine=="" then shrine="Undiscovered Wayshrine #"..tostring(nodeIndex) end
                rows[#rows+1]={
                    kind="WAYSHRINE", category="TRAVEL / EXPLORATION", name=shrine,
                    zoneId=zid, zone=zname, nodeIndex=nodeIndex, done=false, progress="UNDISCOVERED",
                    points=0, pointText="TRAVEL", actionText="DISCOVER",
                    note="Wayshrines do not award skill points; they are included so missing exploration/travel access is visible.",
                }
            end
        end
    end
    table.sort(rows,function(a,b)
        if lower(a.zone)~=lower(b.zone) then return lower(a.zone)<lower(b.zone) end
        return lower(a.name)<lower(b.name)
    end)
    return rows, knownCount, totalCount
end

function F:BuildGeneralMissingRows(snapshot)
    local rows = {}
    local level = n(safe(GetUnitLevel, 1, "player"), 1)
    local levelPoints = math.floor(level / 5) + math.floor(level / 10) + math.max(0, level - 1)
    if level > 50 then levelPoints = 64 end
    if levelPoints < 64 then
        rows[#rows+1] = {
            kind="GENERAL", category="CHARACTER LEVEL", zone="", name="Character Level Skill Points",
            done=false, progress=tostring(levelPoints).."/64", points=64-levelPoints,
            pointText=tostring(64-levelPoints).." LEFT", actionText="INFO",
            note="Continue leveling the character. Leveling awards up to 64 skill points."
        }
    end

    local pvp = n(safe(GetUnitAvARank, 0, "player"), 0)
    if pvp < 50 then
        rows[#rows+1] = {
            kind="GENERAL", category="ALLIANCE WAR", zone="Cyrodiil / Battlegrounds", name="Alliance War Rank Skill Points",
            done=false, progress=tostring(pvp).."/50", points=50-pvp,
            pointText=tostring(50-pvp).." LEFT", actionText="INFO",
            note="Increase Alliance War rank. Each rank through 50 contributes a skill point."
        }
    end

    local mael = DATA.maelstromAchievementId and safe(IsAchievementComplete, false, DATA.maelstromAchievementId) == true
    if not mael then
        rows[#rows+1] = {
            kind="GENERAL", category="ARENA", zone="Wrothgar", name="Maelstrom Arena",
            done=false, progress="MISSING", points=1, pointText="1 SP", actionText="ROUTE",
            zoneId=684, note="Complete Maelstrom Arena for its skill point."
        }
    end

    local actual, reliable = self:GetTotalOwnedSkillPoints()
    local mainDone = 0
    for _, id in ipairs(DATA.mainQuestIds or {}) do if questDone(id) then mainDone = mainDone + 1 end end
    local tutorialDone = false
    for _, id in ipairs(DATA.tutorialQuestIds or {}) do if questDone(id) then tutorialDone = true break end end
    local iaDone = false
    for _, id in ipairs(DATA.infiniteArchiveQuestIds or {}) do if questDone(id) then iaDone = true break end end
    local known = levelPoints + mainDone + (tutorialDone and 1 or 0) + pvp + (mael and 1 or 0) + (iaDone and 1 or 0)
        + n(snapshot.storyQuestDone,0) + n(snapshot.dungeonDone,0) + n(snapshot.publicDone,0)
        + math.floor(n(snapshot.skyAcquired,0) / 3)
    local gateDone = questDone(DATA.foliumGateQuestId)
    local folium = gateDone and reliable and (actual - known) >= 2
    snapshot.foliumInferred = folium
    snapshot.foliumReliable = reliable
    if not folium then
        rows[#rows+1] = {
            kind="GENERAL", category="MAGES GUILD", zone="Coldharbour", name="Folium Discognitum",
            done=false, progress=(gateDone and reliable) and "0/2" or "?/2", points=2, pointText="2 SP", actionText="INFO",
            note=gateDone and "The Mad God's Bargain is complete. Folium ownership is inferred from the character's live skill-point total."
                or "Complete The Mad God's Bargain. The Folium Discognitum can grant two skill points; ESO does not expose a direct ownership flag."
        }
    end
    return rows
end

function F:BuildOverviewRows(snapshot)
    local rows={}
    local function add(name,progress,done,points,note)
        rows[#rows+1]={kind="OVERVIEW",category="GENERAL",zone="",name=name,progress=progress,done=done,points=points or 0,pointText="",note=note or "",actionText=""}
    end
    local level=n(safe(GetUnitLevel,1,"player"),1)
    local levelPoints=math.floor(level/5)+math.floor(level/10)+math.max(0,level-1)
    if level>50 then levelPoints=64 end
    add("Character Level",tostring(levelPoints).."/64",levelPoints>=64,levelPoints,"Skill points earned from character leveling.")

    local mainDone=0
    for _,id in ipairs(DATA.mainQuestIds or {}) do if questDone(id) then mainDone=mainDone+1 end end
    add("Main Quest",tostring(mainDone).."/"..tostring(#(DATA.mainQuestIds or {})),mainDone>=#(DATA.mainQuestIds or {}),mainDone,"Main Story quests that award skill points.")

    local tutorialDone=false
    for _,id in ipairs(DATA.tutorialQuestIds or {}) do if questDone(id) then tutorialDone=true break end end
    add("Tutorial",tutorialDone and "1/1" or "0/1",tutorialDone,tutorialDone and 1 or 0,"One tutorial skill point.")
    local folium = snapshot.foliumInferred == true
    local foliumProgress = snapshot.foliumReliable and (folium and "2/2 (inferred)" or "0/2 (inferred)") or "?/2"
    add("Folium Discognitum",foliumProgress,folium,folium and 2 or 0,"ESO exposes no direct Folium ownership flag; this is inferred after The Mad God's Bargain from the live character skill-point total.")

    local pvp=n(safe(GetUnitAvARank,0,"player"),0)
    add("Alliance War Rank",tostring(pvp).."/50",pvp>=50,pvp,"One skill point per Alliance War rank through rank 50.")

    local mael=DATA.maelstromAchievementId and safe(IsAchievementComplete,false,DATA.maelstromAchievementId)==true
    add("Maelstrom Arena",mael and "1/1" or "0/1",mael,mael and 1 or 0,"Maelstrom Arena completion skill point.")

    local iaDone=false
    for _,id in ipairs(DATA.infiniteArchiveQuestIds or {}) do if questDone(id) then iaDone=true break end end
    add("Infinite Archive",iaDone and "1/1" or "0/1",iaDone,iaDone and 1 or 0,"Infinite Archive skill-point quest.")

    add("Storyline Skill-Point Quests",tostring(snapshot.storyQuestDone).."/"..tostring(snapshot.storyQuestTotal),snapshot.storyQuestDone>=snapshot.storyQuestTotal,snapshot.storyQuestDone)
    add("Group Dungeon Quests",tostring(snapshot.dungeonDone).."/"..tostring(snapshot.dungeonTotal),snapshot.dungeonDone>=snapshot.dungeonTotal,snapshot.dungeonDone)
    add("Public Dungeon Group Events",tostring(snapshot.publicDone).."/"..tostring(snapshot.publicTotal),snapshot.publicDone>=snapshot.publicTotal,snapshot.publicDone)
    add("Skyshards",tostring(snapshot.skyAcquired).."/"..tostring(snapshot.skyTotal).."  ("..tostring(math.floor(snapshot.skyAcquired/3)).." SP)",snapshot.skyAcquired>=snapshot.skyTotal,math.floor(snapshot.skyAcquired/3))
    add("Wayshrines",tostring(snapshot.waysKnown).."/"..tostring(snapshot.waysTotal),snapshot.waysKnown>=snapshot.waysTotal,0,"Exploration/travel only — wayshrines do not award skill points.")

    local actual, reliable=snapshot.actualOwned, snapshot.actualOwnedReliable
    actual=n(actual,0)
    local maxPoints=n(snapshot.acquirableMax029742,579)
    local totalText=reliable and (tostring(actual).." owned / "..tostring(maxPoints).." acquirable") or (tostring(actual).." available")
    add("Current Character Skill Points",totalText,true,actual,"Live current-character total from ESO's skill allocation system. Wayshrines are travel/exploration only and are excluded from the skill-point maximum.")

    return rows
end

function F:RefreshSnapshot()
    self.deferredSnapshotPhase029715="Quests"
    self.deferredSnapshotProgress029715=8
    local questRows=self:BuildQuestRows()

    self.deferredSnapshotPhase029715="Skyshards"
    self.deferredSnapshotProgress029715=28
    local skyRows,skyAcquired,skyTotal=self:BuildSkyshardRows()

    self.deferredSnapshotPhase029715="Dungeon skill points"
    self.deferredSnapshotProgress029715=62
    local dungeonRows=self:BuildDungeonRows()

    self.deferredSnapshotPhase029715="Public dungeon skill points"
    self.deferredSnapshotProgress029715=73
    local publicRows=self:BuildPublicDungeonRows()

    self.deferredSnapshotPhase029715="Wayshrines"
    self.deferredSnapshotProgress029715=82
    local waysRows,waysKnown,waysTotal=self:BuildWayshrineRows()
    self.deferredSnapshotProgress029715=94

    local storyDone,storyTotal=0,0
    for _,r in ipairs(questRows) do
        if r.category=="STORY QUEST" then storyTotal=storyTotal+1; if r.done then storyDone=storyDone+1 end end
    end
    local dungeonDone=0; for _,r in ipairs(dungeonRows) do if r.done then dungeonDone=dungeonDone+1 end end
    local publicDone=0; for _,r in ipairs(publicRows) do if r.done then publicDone=publicDone+1 end end

    local snapshot={
        questRows=questRows,skyRows=skyRows,dungeonRows=dungeonRows,publicRows=publicRows,waysRows=waysRows,
        skyAcquired=skyAcquired,skyTotal=skyTotal,waysKnown=waysKnown,waysTotal=waysTotal,
        storyQuestDone=storyDone,storyQuestTotal=storyTotal,dungeonDone=dungeonDone,dungeonTotal=#dungeonRows,
        publicDone=publicDone,publicTotal=#publicRows,
    }
    -- Keep the internally enumerated catalog total for diagnostics, but do not
    -- present it as the game's maximum. Some source families are discovered
    -- dynamically and wayshrines are not skill-point sources at all.
    snapshot.catalogTrackedMax029742 = 64 + #(DATA.mainQuestIds or {}) + 2 + 1 + 50 + 1
        + #(DATA.infiniteArchiveQuestIds or {}) + storyTotal + #dungeonRows + #publicRows + math.floor(skyTotal / 3)
    snapshot.acquirableMax029742 = n(DATA.acquirableSkillPointMax029742, 579)
    snapshot.trackedMax = snapshot.acquirableMax029742
    snapshot.actualOwned, snapshot.actualOwnedReliable = self:GetTotalOwnedSkillPoints()
    snapshot.generalMissingRows=self:BuildGeneralMissingRows(snapshot)
    snapshot.overviewRows=self:BuildOverviewRows(snapshot)

    local missing={}
    for _,collection in ipairs({snapshot.generalMissingRows,questRows,skyRows,dungeonRows,publicRows}) do
        for _,r in ipairs(collection) do if not r.done then missing[#missing+1]=r end end
    end
    table.sort(missing,function(a,b)
        if lower(a.category)~=lower(b.category) then return lower(a.category)<lower(b.category) end
        if lower(a.zone)~=lower(b.zone) then return lower(a.zone)<lower(b.zone) end
        return lower(a.name)<lower(b.name)
    end)
    snapshot.missingRows=missing

    -- A displayed source row is not the same thing as one skill point:
    -- three Skyshards equal one point, while some general rows represent
    -- multiple points. Wayshrines are not in this collection and are worth 0.
    snapshot.missingObjectiveRows029742 = #missing
    if snapshot.actualOwnedReliable then
        snapshot.missingSkillPoints029742 = math.max(0, n(snapshot.acquirableMax029742,579) - n(snapshot.actualOwned,0))
    else
        local estimated = 0
        local missingSky = 0
        for _,r in ipairs(missing) do
            if r.kind == "SKYSHARD" then
                missingSky = missingSky + 1
            else
                estimated = estimated + math.max(0,n(r.points,0))
            end
        end
        estimated = estimated + math.ceil(missingSky / 3)
        snapshot.missingSkillPoints029742 = estimated
    end
    -- Legacy field retained for compatibility; it now reports point deficit,
    -- not the number of source rows.
    snapshot.missingPointSources = snapshot.missingSkillPoints029742
    self.snapshot=snapshot
    return snapshot
end

function F:GetRowsForTab()
    local s=self:GetSV()
    local snapshot=self.snapshot
    if not snapshot then return {} end
    local rows
    if s.tab=="OVERVIEW" then rows=snapshot.overviewRows
    elseif s.tab=="MISSING" then rows=snapshot.missingRows
    elseif s.tab=="QUESTS" then rows=snapshot.questRows
    elseif s.tab=="SKYSHARDS" then rows=snapshot.skyRows
    elseif s.tab=="DUNGEONS" then rows=snapshot.dungeonRows
    elseif s.tab=="PUBLIC" then rows=snapshot.publicRows
    elseif s.tab=="WAYSHRINES" then rows=snapshot.waysRows
    else rows={} end

    if s.missingOnly and s.tab~="OVERVIEW" and s.tab~="MISSING" and s.tab~="WAYSHRINES" then
        local filtered={}
        for _,r in ipairs(rows) do if not r.done then filtered[#filtered+1]=r end end
        rows=filtered
    end
    return rows
end

function F:FindKnownWayshrineForZone(targetZoneId)
    targetZoneId=parentZoneId(n(targetZoneId,0))
    if targetZoneId<=0 or type(GetNumFastTravelNodes)~="function" or type(GetFastTravelNodeInfo)~="function" then return nil end
    local poiIndexFn=GetFastTravelNodePOIIndicies or GetFastTravelNodePOIIndices
    local count=n(safe(GetNumFastTravelNodes,0),0)
    local fallback=nil
    for nodeIndex=1,count do
        local known,name,_,_,_,_,poiType,_,locked=safe(GetFastTravelNodeInfo,false,nodeIndex)
        local isWayshrine=POI_TYPE_WAYSHRINE==nil or poiType==POI_TYPE_WAYSHRINE
        if known==true and isWayshrine and locked~=true then
            local zi=0
            if type(poiIndexFn)=="function" then zi=n(safe(poiIndexFn,0,nodeIndex),0) end
            local zid=zi>0 and parentZoneId(n(safe(GetZoneId,0,zi),0)) or 0
            if zid==targetZoneId then return {nodeIndex=nodeIndex,name=clean(name),zoneId=zid} end
            if not fallback and zid>0 and parentZoneId(zid)==targetZoneId then fallback={nodeIndex=nodeIndex,name=clean(name),zoneId=zid} end
        end
    end
    return fallback
end

function F:RouteToZone(zoneId, targetName)
    zoneId=parentZoneId(n(zoneId,0))
    if zoneId<=0 then printMsg("ESO did not expose a usable zone for "..clean(targetName,"that skill-point source")..".") return false end
    local shrine=self:FindKnownWayshrineForZone(zoneId)
    if shrine then
        printMsg("Routing toward "..clean(targetName,"skill-point source").." via "..clean(shrine.name,"a discovered wayshrine")..".")
        if EPC.Travel and type(EPC.Travel.TravelToWayshrineNode)=="function" then
            return EPC.Travel:TravelToWayshrineNode(shrine.nodeIndex,shrine.name)
        elseif type(FastTravelToNode)=="function" then
            return pcall(FastTravelToNode,shrine.nodeIndex)
        end
    end
    printMsg("No discovered wayshrine is available in "..zoneName(zoneId)..". Use the WAYSHRINES tab and DISCOVER to unlock travel access.")
    return false
end

function F:RouteDungeon(row)
    if EPC.MasterAchievementTracker then
        local M=EPC.MasterAchievementTracker
        if type(M.BuildDungeonCatalog)=="function" then M:BuildDungeonCatalog(false) end
        for _,dungeon in ipairs(M.dungeons or {}) do
            if n(dungeon.zoneId,0)==n(row.dungeonZoneId,0) and type(M.TeleportToDungeon)=="function" then
                return M:TeleportToDungeon(dungeon)
            end
        end
    end
    return self:RouteToZone(row.zoneId,row.name)
end

function F:TryTravelInstance(row)
    if EPC.Travel and type(EPC.Travel.GetMapTeleporterInstanceEntries)=="function"
        and type(EPC.Travel.TravelMapTeleporterEntry)=="function" then
        local target=n(row.publicDungeonZoneId or row.dungeonZoneId,0)
        for _,entry in ipairs(EPC.Travel:GetMapTeleporterInstanceEntries() or {}) do
            if n(entry.zoneId,0)==target or n(entry.parentZoneId,0)==target then
                if entry.canTravel~=false then return EPC.Travel:TravelMapTeleporterEntry(entry) end
            end
        end
    end
    return self:RouteToZone(row.zoneId,row.name)
end

function F:FindJournalQuestIndex(questId)
    questId=n(questId,0)
    if questId<=0 or type(GetJournalQuestId)~="function" then return nil end
    local maxSlots=math.max(100,n(rawget(_G,"MAX_JOURNAL_QUESTS"),0))
    for i=1,maxSlots do
        if n(safe(GetJournalQuestId,0,i),0)==questId then return i end
    end
    return nil
end

function F:RouteQuest(row)
    if not row then return false end
    local questIndex=n(row.questIndex,0)
    if questIndex<=0 then questIndex=n(self:FindJournalQuestIndex(row.questId),0) end
    if questIndex>0 and EPC.QuestFinder and type(EPC.QuestFinder.AssistAcceptedQuest2511)=="function" then
        local entry={
            questIndex=questIndex,questId=n(row.questId,0),name=clean(row.name),
            zone=clean(row.zone),zoneId=n(row.zoneId,0),rawZoneId=n(row.zoneId,0),
            starter="Already accepted",access="ACTIVE JOURNAL",
        }
        EPC.QuestFinder:AssistAcceptedQuest2511(entry,true)
        printMsg("Assisting skill-point quest: "..clean(row.name))
        return true
    end
    if EPC.Travel and type(EPC.Travel.TravelToNearestQuestStarterWayshrine)=="function" then
        local entry={
            questId=n(row.questId,0),name=clean(row.name),zone=clean(row.zone),
            zoneId=n(row.zoneId,0),rawZoneId=n(row.zoneId,0),
            starter="Skill Point Finder target",access="NOT STARTED",
        }
        local ok=EPC.Travel:TravelToNearestQuestStarterWayshrine(entry)
        if ok then return true end
    end
    return self:RouteToZone(row.zoneId,row.name)
end

function F:RouteRow(row)
    if not row then return false end
    if row.kind=="QUEST" and row.category~="TUTORIAL" then return self:RouteQuest(row) end
    if row.kind=="GENERAL" then
        if n(row.zoneId,0)>0 and row.actionText=="ROUTE" then return self:RouteToZone(row.zoneId,row.name) end
        printMsg(clean(row.note,row.name))
        return true
    end
    if row.kind=="DUNGEON" then return self:RouteDungeon(row) end
    if row.kind=="PUBLIC" then return self:TryTravelInstance(row) end
    if row.kind=="WAYSHRINE" then
        local routed=self:RouteToZone(row.zoneId,row.name)
        if routed then return true end
        if EPC.Travel and type(EPC.Travel.StartMapTeleporterAutoDiscovery)=="function" then
            EPC.Travel:StartMapTeleporterAutoDiscovery()
            return true
        end
        return false
    end
    if row.kind=="QUEST" and row.category=="TUTORIAL" then
        printMsg("Tutorial skill point is earned from completing one of ESO's tutorial introductions.")
        return true
    end
    return self:RouteToZone(row.zoneId,row.name)
end

function F:StartWayshrineDiscovery()
    if EPC.Travel and type(EPC.Travel.StartMapTeleporterAutoDiscovery)=="function" then
        EPC.Travel:StartMapTeleporterAutoDiscovery()
        return true
    end
    printMsg("Suite wayshrine discovery routing is unavailable.")
    return false
end

function F:CreateDetailPopup029731()
    if self.detailPopup029731 then return self.detailPopup029731 end

    local popup=WM:CreateTopLevelWindow("EAS_SkillPointFinderDetails029731")
    popup:SetDimensions(660,430)
    popup:SetClampedToScreen(true)
    popup:SetMouseEnabled(false)
    popup:SetHidden(true)
    popup:SetDrawLayer(DL_OVERLAY)
    if popup.SetDrawTier and DT_HIGH then popup:SetDrawTier(DT_HIGH) end
    if popup.SetTopLevel then popup:SetTopLevel(true) end
    if popup.SetDrawLevel then popup:SetDrawLevel(920) end

    local bg=createBackdrop(popup,nil,.008,.012,.020,.995,.82,.66,.22,1)
    bg:SetAnchorFill(popup)
    bg:SetMouseEnabled(false)

    local category=label(popup,nil,"","ZoFontGameBold",{1,.82,.24,1})
    category:SetAnchor(TOPLEFT,popup,TOPLEFT,18,14)
    category:SetDimensions(500,24)

    local reward=label(popup,nil,"","ZoFontGameBold",{.35,1,.45,1})
    reward:SetAnchor(TOPRIGHT,popup,TOPRIGHT,-18,14)
    reward:SetDimensions(130,24)
    reward:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local title=label(popup,nil,"","ZoFontWinH3",{.96,.97,1,1})
    title:SetAnchor(TOPLEFT,category,BOTTOMLEFT,0,4)
    title:SetDimensions(620,48)
    title:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local zone=label(popup,nil,"","ZoFontGameBold",{.72,.80,1,1})
    zone:SetAnchor(TOPLEFT,title,BOTTOMLEFT,0,4)
    zone:SetDimensions(620,26)

    local divider=WM:CreateControl(nil,popup,CT_BACKDROP)
    divider:SetAnchor(TOPLEFT,zone,BOTTOMLEFT,0,4)
    divider:SetDimensions(620,1)
    divider:SetCenterColor(.28,.31,.38,.9)
    divider:SetEdgeColor(0,0,0,0)

    local body=label(popup,nil,"","ZoFontGame",{.88,.90,.94,1})
    body:SetAnchor(TOPLEFT,divider,BOTTOMLEFT,0,10)
    body:SetDimensions(620,240)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)
    body:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local footer=label(popup,nil,"","ZoFontGameSmall",{.66,.70,.78,1})
    footer:SetAnchor(BOTTOMLEFT,popup,BOTTOMLEFT,18,-12)
    footer:SetDimensions(620,26)
    footer:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.detailPopup029731=popup
    self.detailCategory029731=category
    self.detailReward029731=reward
    self.detailTitle029731=title
    self.detailZone029731=zone
    self.detailBody029731=body
    self.detailFooter029731=footer
    return popup
end

function F:HideRowTooltip029731()
    if self.detailPopup029731 then self.detailPopup029731:SetHidden(true) end
end

function F:ShowRowTooltip(owner,row)
    if not owner or not row then return end
    local popup=self:CreateDetailPopup029731()

    self.detailCategory029731:SetText(clean(row.category or row.kind))
    self.detailTitle029731:SetText(clean(row.name))
    self.detailZone029731:SetText(clean(row.zone)~="" and ("Zone: "..clean(row.zone)) or "")

    if row.kind=="WAYSHRINE" then
        self.detailReward029731:SetText("TRAVEL")
    elseif row.pointText and clean(row.pointText)~="" then
        self.detailReward029731:SetText(clean(row.pointText))
    else
        self.detailReward029731:SetText("")
    end

    local lines={}
    if clean(row.detail)~="" then lines[#lines+1]=clean(row.detail) end
    if clean(row.note)~="" then lines[#lines+1]=clean(row.note) end
    if row.kind=="WAYSHRINE" then
        lines[#lines+1]="This is a missing travel node, not a skill-point reward."
    elseif row.pointText and clean(row.pointText)~="" then
        lines[#lines+1]="Reward: "..clean(row.pointText)
    end
    if #lines==0 then lines[1]="No additional source description is available." end

    self.detailBody029731:SetText(table.concat(lines,"\n\n"))
    self.detailFooter029731:SetText("Click the row or ROUTE button to navigate toward this source.")

    local rootH=(GuiRoot and GuiRoot.GetHeight and tonumber(GuiRoot:GetHeight())) or 1080
    local maxPopupH=math.max(360,rootH-90)
    local bodyH=150
    if self.detailBody029731.GetTextHeight then
        local ok,value=pcall(self.detailBody029731.GetTextHeight,self.detailBody029731)
        if ok and tonumber(value) then bodyH=math.max(120,math.min(maxPopupH-160,tonumber(value)+16)) end
    end
    self.detailBody029731:SetHeight(bodyH)
    popup:SetHeight(math.max(310,math.min(maxPopupH,165+bodyH)))

    -- Keep the row visible: dock the popup to the opposite screen side and
    -- vertically center it so lower rows never cause ESO clamping/compression.
    popup:ClearAnchors()
    local rootW=(GuiRoot and GuiRoot.GetWidth and tonumber(GuiRoot:GetWidth())) or 1920
    local left=(owner.GetLeft and tonumber(owner:GetLeft())) or 0
    local right=(owner.GetRight and tonumber(owner:GetRight())) or left
    if ((left+right)*.5) >= rootW*.5 then
        popup:SetAnchor(LEFT,GuiRoot,LEFT,24,0)
    else
        popup:SetAnchor(RIGHT,GuiRoot,RIGHT,-24,0)
    end

    popup:SetHidden(false)
    if popup.BringWindowToTop then popup:BringWindowToTop() end
end

function F:CreateWindow()
    if self.window then return self.window end
    local s=self:GetSV()
    local root=WM:CreateTopLevelWindow("EAS_SkillPointFinder029714")
    root:SetDimensions(W,H); root:SetMouseEnabled(true); root:SetMovable(true); root:SetClampedToScreen(true)
    root:SetDrawLayer(DL_OVERLAY); if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    root:SetDrawLevel(710); root:SetHidden(true)
    if s and n(s.left,-1)>=0 and n(s.top,-1)>=0 then root:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,n(s.left,0),n(s.top,0))
    else root:SetAnchor(CENTER,GuiRoot,CENTER,0,0) end
    root:SetHandler("OnMoveStop",function(c) local sv=F:GetSV(); if sv then sv.left,sv.top=c:GetLeft(),c:GetTop() end end)

    local bg=createBackdrop(root,nil,.010,.016,.026,.99,.62,.47,.14,.96); bg:SetAnchorFill(root)
    local header=createBackdrop(root,nil,.018,.026,.040,.995,0,0,0,0)
    header:SetAnchor(TOPLEFT,root,TOPLEFT,2,2); header:SetAnchor(TOPRIGHT,root,TOPRIGHT,-2,2); header:SetHeight(72)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then root:StartMoving() end end)
    header:SetHandler("OnMouseUp",function(_,b) if b==MOUSE_BUTTON_INDEX_LEFT then root:StopMovingOrResizing() end end)
    local title=label(header,nil,"SKILL POINT FINDER","ZoFontWinH1",{1,.82,.22,1}); title:SetAnchor(TOPLEFT,header,TOPLEFT,20,9); title:SetDimensions(500,34)
    self.characterLabel=label(header,nil,"","ZoFontGame",{.72,.78,.88,1}); self.characterLabel:SetAnchor(TOPLEFT,title,BOTTOMLEFT,0,-1); self.characterLabel:SetDimensions(850,24)
    local close=button(header,nil,"X",function() F:Hide() end); close:SetDimensions(44,44); close:SetAnchor(TOPRIGHT,header,TOPRIGHT,-12,13); close:SetFont("ZoFontWinH2")

    local tabs=WM:CreateControl(nil,root,CT_CONTROL); tabs:SetAnchor(TOPLEFT,header,BOTTOMLEFT,12,8); tabs:SetAnchor(TOPRIGHT,header,BOTTOMRIGHT,-12,8); tabs:SetHeight(38)
    self.tabButtons={}
    local tabW=160
    for i,spec in ipairs(TABS) do
        local b=button(tabs,nil,spec[2],function() local sv=F:GetSV(); sv.tab=spec[1]; sv.page=1; F:Refresh(false) end)
        b:SetDimensions(tabW,32); b:SetAnchor(LEFT,tabs,LEFT,(i-1)*(tabW+6),0); self.tabButtons[spec[1]]=b
    end

    local summary=createBackdrop(root,nil,.020,.030,.046,.98,.14,.18,.25,.75)
    summary:SetAnchor(TOPLEFT,tabs,BOTTOMLEFT,0,5); summary:SetAnchor(TOPRIGHT,tabs,BOTTOMRIGHT,0,5); summary:SetHeight(66)
    self.summary1=label(summary,nil,"","ZoFontGameBold",{.92,.94,.98,1}); self.summary1:SetAnchor(TOPLEFT,summary,TOPLEFT,14,8); self.summary1:SetDimensions(850,22)
    self.summary2=label(summary,nil,"","ZoFontGameSmall",{.68,.74,.82,1}); self.summary2:SetAnchor(TOPLEFT,self.summary1,BOTTOMLEFT,0,3); self.summary2:SetDimensions(820,22)
    self.missingToggle=button(summary,nil,"SHOW: MISSING",function()
        local sv=F:GetSV(); sv.missingOnly=not sv.missingOnly; sv.page=1; F:Refresh(false)
    end); self.missingToggle:SetDimensions(150,34); self.missingToggle:SetAnchor(RIGHT,summary,RIGHT,-150,0)
    self.discoverButton=button(summary,nil,"DISCOVER WAYS",function() F:StartWayshrineDiscovery() end)
    self.discoverButton:SetDimensions(140,34); self.discoverButton:SetAnchor(RIGHT,summary,RIGHT,-4,0)

    local head=createBackdrop(root,nil,.030,.041,.060,.98,.18,.22,.30,.8)
    head:SetAnchor(TOPLEFT,summary,BOTTOMLEFT,0,7); head:SetAnchor(TOPRIGHT,summary,BOTTOMRIGHT,0,7); head:SetHeight(34)
    local function h(text,x,wid,align)
        local l=label(head,nil,text,"ZoFontGameBold",{.84,.88,.94,1}); l:SetAnchor(LEFT,head,LEFT,x,0); l:SetDimensions(wid,32)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER); l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT); return l
    end
    h("TYPE",12,170); h("ZONE",188,210); h("SOURCE / LOCATION",405,460); h("STATUS",872,126,TEXT_ALIGN_CENTER); h("VALUE",1004,80,TEXT_ALIGN_CENTER); h("ACTION",1090,106,TEXT_ALIGN_CENTER)

    self.rows={}
    for i=1,ROWS_PER_PAGE do
        local row=WM:CreateControl(nil,root,CT_CONTROL)
        row:SetAnchor(TOPLEFT,head,BOTTOMLEFT,0,4+(i-1)*40); row:SetAnchor(TOPRIGHT,head,BOTTOMRIGHT,0,4+(i-1)*40); row:SetHeight(38); row:SetMouseEnabled(true)
        local rbg=createBackdrop(row,nil,(i%2==0) and .022 or .017,(i%2==0) and .030 or .024,(i%2==0) and .044 or .036,.95,.12,.15,.20,.55); rbg:SetAnchorFill(row)
        local typeL=label(row,nil,"","ZoFontGameSmall",{.68,.76,.90,1}); typeL:SetAnchor(LEFT,row,LEFT,12,0); typeL:SetDimensions(170,38); typeL:SetVerticalAlignment(TEXT_ALIGN_CENTER); if typeL.SetMaxLineCount then pcall(typeL.SetMaxLineCount,typeL,2) end
        local zoneL=label(row,nil,"","ZoFontGameSmall",{.86,.88,.92,1}); zoneL:SetAnchor(LEFT,row,LEFT,188,0); zoneL:SetDimensions(210,38); zoneL:SetVerticalAlignment(TEXT_ALIGN_CENTER); if zoneL.SetMaxLineCount then pcall(zoneL.SetMaxLineCount,zoneL,2) end
        local source=button(row,nil,"",function(c) if c.data then F:RouteRow(c.data) end end); source:SetAnchor(LEFT,row,LEFT,405,0); source:SetDimensions(460,38); source:SetText("")
        local sourceL=label(row,nil,"","ZoFontGameSmall",{.88,.90,.94,1}); sourceL:SetAnchor(LEFT,row,LEFT,405,0); sourceL:SetDimensions(452,38); sourceL:SetVerticalAlignment(TEXT_ALIGN_CENTER); sourceL:SetHorizontalAlignment(TEXT_ALIGN_LEFT); if sourceL.SetMaxLineCount then pcall(sourceL.SetMaxLineCount,sourceL,2) end
        local status=label(row,nil,"","ZoFontGame",{1,.42,.24,1}); status:SetAnchor(LEFT,row,LEFT,872,0); status:SetDimensions(126,34); status:SetHorizontalAlignment(TEXT_ALIGN_CENTER); status:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local value=label(row,nil,"","ZoFontGameBold",{.44,1,.54,1}); value:SetAnchor(LEFT,row,LEFT,1004,0); value:SetDimensions(80,34); value:SetHorizontalAlignment(TEXT_ALIGN_CENTER); value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local action=button(row,nil,"ROUTE",function(c) if c.data then F:RouteRow(c.data) end end); action:SetAnchor(LEFT,row,LEFT,1090,0); action:SetDimensions(106,34)
        row:SetHandler("OnMouseEnter",function(c) if c.data then c.bg:SetCenterColor(.060,.080,.115,.98); F:ShowRowTooltip(c,c.data) end end)
        row:SetHandler("OnMouseExit",function(c) c.bg:SetCenterColor(c.base[1],c.base[2],c.base[3],c.base[4]); F:HideRowTooltip029731() end)
        row.bg=rbg; row.base={(i%2==0) and .022 or .017,(i%2==0) and .030 or .024,(i%2==0) and .044 or .036,.95}
        row.typeL=typeL; row.zoneL=zoneL; row.source=source; row.sourceL=sourceL; row.status=status; row.value=value; row.action=action
        row:SetHidden(true); self.rows[i]=row
    end

    local footer=WM:CreateControl(nil,root,CT_CONTROL); footer:SetAnchor(BOTTOMLEFT,root,BOTTOMLEFT,14,-10); footer:SetAnchor(BOTTOMRIGHT,root,BOTTOMRIGHT,-14,-10); footer:SetHeight(48)
    self.prev=button(footer,nil,"< PREV",function() local sv=F:GetSV(); sv.page=math.max(1,n(sv.page,1)-1); F:Refresh(false) end); self.prev:SetDimensions(100,34); self.prev:SetAnchor(LEFT,footer,LEFT,0,0)
    self.pageLabel=label(footer,nil,"PAGE 1 / 1","ZoFontGameBold",{.76,.80,.86,1}); self.pageLabel:SetAnchor(LEFT,self.prev,RIGHT,12,0); self.pageLabel:SetDimensions(250,34); self.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER); self.pageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.next=button(footer,nil,"NEXT >",function() local sv=F:GetSV(); sv.page=n(sv.page,1)+1; F:Refresh(false) end); self.next:SetDimensions(100,34); self.next:SetAnchor(LEFT,self.pageLabel,RIGHT,12,0)
    self.footerNote=label(footer,nil,"Wayshrines are travel/exploration only; they do not grant skill points.","ZoFontGameSmall",{.64,.68,.75,1}); self.footerNote:SetAnchor(LEFT,self.next,RIGHT,24,0); self.footerNote:SetDimensions(630,34); self.footerNote:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.window=root
    return root
end

function F:CancelDeferredSnapshot029715()
    EM:UnregisterForUpdate(NAME .. "_DeferredSnapshot029715")
    self.deferredSnapshotCoroutine029715=nil
    self.deferredSnapshotRunning029715=false
    self.deferredWorkUnits029715=0
end

function F:StartDeferredSnapshot029715(force)
    if self.snapshot and not force then return end
    if self.deferredSnapshotRunning029715 then
        if force then self.deferredSnapshotRerun029715=true end
        return
    end

    self.deferredSnapshotRunning029715=true
    self.deferredSnapshotRerun029715=false
    self.deferredWorkUnits029715=0
    self.deferredProbeUnits029716=0
    local clock = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds or GetGameTimeMilliseconds
    self.deferredSliceStarted029716 = type(clock) == "function" and clock() or 0
    self.deferredSnapshotPhase029715="Preparing"
    self.deferredSnapshotProgress029715=1

    local co=coroutine.create(function()
        F:RefreshSnapshot()
        F.deferredSnapshotProgress029715=100
        F.deferredSnapshotPhase029715="Ready"
    end)
    self.deferredSnapshotCoroutine029715=co

    EM:RegisterForUpdate(NAME .. "_DeferredSnapshot029715",0,function()
        local thread=F.deferredSnapshotCoroutine029715
        if not thread then
            F:CancelDeferredSnapshot029715()
            return
        end

        local ok,err=coroutine.resume(thread)
        if not ok then
            F:CancelDeferredSnapshot029715()
            F.deferredSnapshotPhase029715="Build error"
            printMsg("Skill Point Finder deferred scan stopped: "..tostring(err))
            F:Render029715()
            return
        end

        if coroutine.status(thread)=="dead" then
            local rerun=F.deferredSnapshotRerun029715==true
            F:CancelDeferredSnapshot029715()
            F:Render029715()
            if rerun and F.window and not F.window:IsHidden() and type(zo_callLater)=="function" then
                zo_callLater(function() F:StartDeferredSnapshot029715(true) end,120)
            end
        elseif F.window and not F.window:IsHidden() then
            F.deferredUiTick029715=(tonumber(F.deferredUiTick029715) or 0)+1
            if F.deferredUiTick029715>=8 then
                F.deferredUiTick029715=0
                F:Render029715()
            end
        end
    end)
end

function F:Render029715()
    self:CreateWindow()
    local sv=self:GetSV()
    local char=clean(safe(GetUnitName,"Adventurer","player"))
    local available=n(safe(GetAvailableSkillPoints,0),0)
    self.characterLabel:SetText((char~="" and char or "Current Character").."  •  "..tostring(available).." unassigned skill point"..(available==1 and "" or "s"))

    for key,b in pairs(self.tabButtons or {}) do
        local active=sv.tab==key
        b:SetNormalFontColor(active and 1 or .76,active and .82 or .79,active and .20 or .86,1)
    end

    if not self.snapshot then
        local phase=tostring(self.deferredSnapshotPhase029715 or "Preparing")
        local progress=n(self.deferredSnapshotProgress029715,0)
        self.summary1:SetText("Scanning ESO skill-point data • "..phase.." • "..tostring(progress).."%")
        self.summary2:SetText("Adaptive loader is using a small frame-time budget so this finishes quickly without a game freeze.")
        self.missingToggle:SetHidden(true)
        for _,row in ipairs(self.rows or {}) do row:SetHidden(true) end
        self.pageLabel:SetText("LOADING…")
        self.prev:SetEnabled(false)
        self.next:SetEnabled(false)
        return
    end

    local rows=self:GetRowsForTab()
    local pages=math.max(1,math.ceil(#rows/ROWS_PER_PAGE))
    sv.page=math.max(1,math.min(pages,n(sv.page,1)))
    local first=((sv.page-1)*ROWS_PER_PAGE)+1

    local snap=self.snapshot
    self.summary1:SetText(string.format("%d skill points remaining  •  Skyshards %d/%d  •  Travel nodes %d/%d",
        n(snap.missingSkillPoints029742,0),n(snap.skyAcquired,0),n(snap.skyTotal,0),n(snap.waysKnown,0),n(snap.waysTotal,0)))
    local ownedText=snap.actualOwnedReliable
        and (tostring(n(snap.actualOwned,0)).." owned / "..tostring(n(snap.acquirableMax029742,579)).." acquirable")
        or (tostring(available).." currently unassigned")
    self.summary2:SetText(ownedText.."  •  "..tostring(n(snap.missingObjectiveRows029742,0)).." missing point objectives  •  Wayshrines are travel only and do not count as skill points.")
    self.missingToggle:SetText(sv.missingOnly and "SHOW: MISSING" or "SHOW: ALL")
    self.missingToggle:SetHidden(sv.tab=="OVERVIEW" or sv.tab=="MISSING" or sv.tab=="WAYSHRINES")

    for i,row in ipairs(self.rows or {}) do
        local data=rows[first+i-1]
        if data then
            row:SetHidden(false); row.data=data; row.source.data=data; row.action.data=data
            row.typeL:SetText(clean(data.category or data.kind))
            row.zoneL:SetText(clean(data.zone))
            local sourceText=clean(data.name)
            if data.detail and clean(data.detail)~="" then sourceText=sourceText.."  •  "..clean(data.detail) end
            row.source:SetText("")
            row.sourceL:SetText(sourceText)
            row.status:SetText(clean(data.progress))
            if data.done then row.status:SetColor(.30,.95,.40,1)
            elseif data.kind=="WAYSHRINE" then row.status:SetColor(1,.72,.20,1)
            else row.status:SetColor(1,.38,.22,1) end
            row.value:SetText(clean(data.pointText))
            row.action:SetText(clean(data.actionText or "ROUTE"))
            row.action:SetHidden(clean(data.actionText)=="")
        else
            row:SetHidden(true); row.data=nil; row.source.data=nil; row.action.data=nil
        end
    end

    self.pageLabel:SetText(string.format("PAGE %d / %d  •  %d RESULT%s",sv.page,pages,#rows,#rows==1 and "" or "S"))
    self.prev:SetEnabled(sv.page>1); self.next:SetEnabled(sv.page<pages)
end

function F:Refresh(rebuild)
    self:CreateWindow()
    if rebuild or not self.snapshot then self:StartDeferredSnapshot029715(rebuild==true) end
    self:Render029715()
end

function F:ScheduleVisibleRefresh()
    if self.refreshQueued then return end
    self.refreshQueued=true
    local function run()
        F.refreshQueued=false
        if F.window and not F.window:IsHidden() then F:Refresh(true) else F.snapshot=nil end
    end
    if type(zo_callLater)=="function" then zo_callLater(run,120) else run() end
end

function F:Show()
    self:CreateWindow()
    if EPC and type(EPC.AcquireSuiteCursor029733) == "function" then
        EPC:AcquireSuiteCursor029733("SkillPointFinder")
    end
    self.window:SetHidden(false)
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end

    -- Render instantly, then scan heavy quest/skyshard/wayshrine data in chunks.
    self:Render029715()
    self:StartDeferredSnapshot029715(false)
end

function F:Hide()
    if self.window then self.window:SetHidden(true) end
    if self.deferredSnapshotRunning029715 then self:CancelDeferredSnapshot029715() end
    self:HideRowTooltip029731()
    if EPC and type(EPC.ReleaseSuiteCursor029733) == "function" then
        EPC:ReleaseSuiteCursor029733("SkillPointFinder")
    end
end

function F:Toggle()
    self:CreateWindow()
    if self.window:IsHidden() then self:Show() else self:Hide() end
end

function F:Initialize()
    self:GetSV()
    local events={
        rawget(_G,"EVENT_SKYSHARDS_UPDATED"),
        rawget(_G,"EVENT_FAST_TRAVEL_NETWORK_UPDATED"),
        rawget(_G,"EVENT_QUEST_COMPLETE"),
        rawget(_G,"EVENT_QUEST_ADDED"),
        rawget(_G,"EVENT_QUEST_REMOVED"),
        rawget(_G,"EVENT_ACHIEVEMENT_AWARDED"),
        rawget(_G,"EVENT_PLAYER_ACTIVATED"),
    }
    local used={}
    for i,eventId in ipairs(events) do
        if eventId~=nil and not used[eventId] then
            used[eventId]=true
            EM:RegisterForEvent(NAME.."_Event"..tostring(i),eventId,function() F:ScheduleVisibleRefresh() end)
        end
    end

    SLASH_COMMANDS=SLASH_COMMANDS or {}
    SLASH_COMMANDS["/skillpoints"]=function() F:Toggle() end
    SLASH_COMMANDS["/eassp"]=function() F:Toggle() end
end

function ESOAdventurerSuite_ToggleSkillPointFinder()
    if EPC.SkillPointFinder then EPC.SkillPointFinder:Toggle() end
end

if type(ZO_CreateStringId)=="function" then
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_SKILL_POINT_FINDER","Skill Point Finder")
end
