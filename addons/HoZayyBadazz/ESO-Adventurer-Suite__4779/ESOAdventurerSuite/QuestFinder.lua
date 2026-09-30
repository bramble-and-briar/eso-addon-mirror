-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

local EPC = ESOProgressionCoach
EPC.QuestFinder = EPC.QuestFinder or {}
local Q = EPC.QuestFinder

Q.PAGE_SIZE = 10
Q.SCAN_MAX_ID = 15000
Q.SCAN_CHUNK = 30
Q.SCAN_DELAY_MS = 60
Q.ENTRIES_CACHE_MS = 5000
Q.ACTIVE_CACHE_MS = 1000

local function lower(v) return string.lower(tostring(v or "")) end
local function trim(v)
    v = tostring(v or "")
    if zo_strtrim then return zo_strtrim(v) end
    return (v:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

-- Convert an instance/sub-zone quest zone into its stable overland parent zone.
-- ESO quest records can point at an interior such as "Castle of the Worm";
-- the Quest Finder must display and route by the overland zone that owns it.
local function getOverlandZoneId(zoneId)
    local current = tonumber(zoneId) or 0
    if current <= 0 or type(GetParentZoneId) ~= "function" then return current end
    local seen = {}
    for _ = 1, 8 do
        if seen[current] then break end
        seen[current] = true
        local ok, parent = pcall(GetParentZoneId, current)
        parent = ok and (tonumber(parent) or 0) or 0
        if parent <= 0 or parent == current then break end
        current = parent
    end
    return current
end

local function getOverlandZone(zoneId)
    local rawZoneId = tonumber(zoneId) or 0
    local overlandZoneId = getOverlandZoneId(rawZoneId)
    if overlandZoneId <= 0 then overlandZoneId = rawZoneId end
    local zoneName = overlandZoneId > 0 and trim(safe(GetZoneNameById, "", overlandZoneId)) or ""
    return overlandZoneId, zoneName, rawZoneId
end

-- Active journal quests can report an interior/instance as GetQuestZoneId().
-- Prefer ESO's journal-level overland metadata when available. Zone Story is
-- the strongest association; starting zone is the safe fallback for Main Story
-- and other quests whose live objective is inside a private instance.

local function getMainStoryHarborageZone(journalQuestIndex)
    local qIndex = tonumber(journalQuestIndex) or 0
    if qIndex <= 0 then return 0, "" end

    -- If ESO explicitly reports The Harborage as this journal quest's location,
    -- the alliance is enough to determine the real overland host zone. Do not
    -- gate this on quest type; some Main Story journal records do not expose the
    -- expected quest-type value consistently.
    local alliance = 0
    if type(GetUnitAlliance) == "function" then
        alliance = tonumber(safe(GetUnitAlliance, 0, "player")) or 0
    end

    local zoneName = ""
    local dc = (ALLIANCE_DAGGERFALL_COVENANT ~= nil and alliance == ALLIANCE_DAGGERFALL_COVENANT) or alliance == 3
    local ad = (ALLIANCE_ALDMERI_DOMINION ~= nil and alliance == ALLIANCE_ALDMERI_DOMINION) or alliance == 1
    local ep = (ALLIANCE_EBONHEART_PACT ~= nil and alliance == ALLIANCE_EBONHEART_PACT) or alliance == 2
    if dc then
        zoneName = "Glenumbra"
    elseif ad then
        zoneName = "Auridon"
    elseif ep then
        zoneName = "Stonefalls"
    end
    if zoneName == "" or type(GetNumZones) ~= "function" or type(GetZoneNameByIndex) ~= "function" or type(GetZoneId) ~= "function" then
        return 0, zoneName
    end

    local count = tonumber(safe(GetNumZones, 0)) or 0
    for zoneIndex = 1, count do
        local name = trim(safe(GetZoneNameByIndex, "", zoneIndex))
        if lower(name) == lower(zoneName) then
            local zoneId = tonumber(safe(GetZoneId, 0, zoneIndex)) or 0
            return zoneId, zoneName
        end
    end
    return 0, zoneName
end

local function isHarborageLocation(value)
    local text = lower(trim(value or ""))
    -- ESO location strings may contain formatting/localization artifacts even when
    -- the UI renders a clean "The Harborage" label. A normalized substring match
    -- is safer than exact equality here.
    return text ~= "" and string.find(text, "harborage", 1, true) ~= nil
end

local function getJournalOverlandZone(journalQuestIndex, questId, fallbackRawZoneId)
    local qIndex = tonumber(journalQuestIndex) or 0

    -- Main Story quests can legitimately report The Harborage as their zone.
    -- The Harborage is physically located in a different overland zone for each alliance,
    -- so translate only that special location to its alliance host zone.
    if qIndex > 0 and type(GetJournalQuestLocationInfo) == "function" then
        local locationName, objectiveName, locationZoneIndex = safe(GetJournalQuestLocationInfo, "", qIndex)
        locationName = trim(locationName or "")
        objectiveName = trim(objectiveName or "")
        locationZoneIndex = tonumber(locationZoneIndex) or 0

        -- Some Main Story stages expose the private mission name (for example
        -- Castle of the Worm) as BOTH the journal zone and objective instead of
        -- the overland host. Detect that self-referential location before trusting
        -- its zone index. The alliance Harborage host is the correct overland entry
        -- point for these stages.
        local journalQuestName = trim(safe(GetJournalQuestName, "", qIndex) or "")
        local selfReferential = journalQuestName ~= "" and (
            lower(locationName) == lower(journalQuestName) or lower(objectiveName) == lower(journalQuestName)
        )
        local isMainStory = false
        if type(GetJournalQuestType) == "function" then
            local qt = tonumber(safe(GetJournalQuestType, -1, qIndex)) or -1
            isMainStory = (QUEST_TYPE_MAIN_STORY ~= nil and qt == QUEST_TYPE_MAIN_STORY)
        end
        if isHarborageLocation(locationName) or (selfReferential and isMainStory) then
            local harborageZoneId, harborageZoneName = getMainStoryHarborageZone(qIndex)
            if harborageZoneName ~= "" then
                return harborageZoneId, harborageZoneName, harborageZoneId, "main-story-overland-entry"
            end
        end

        -- Prefer the real zone index ESO attaches to the journal location only
        -- after rejecting self-referential Main Story mission zones.
        -- point at the overland host even when the rendered label says The Harborage.
        if locationZoneIndex > 0 and type(GetZoneId) == "function" then
            local locationZoneId = tonumber(safe(GetZoneId, 0, locationZoneIndex)) or 0
            if locationZoneId > 0 then
                local zid, name = getOverlandZone(locationZoneId)
                if zid > 0 and name ~= "" and not isHarborageLocation(name) then
                    return zid, name, locationZoneId, "journal-location-zone-index"
                end
            end
        end

        if isHarborageLocation(locationName) then
            local harborageZoneId, harborageZoneName = getMainStoryHarborageZone(qIndex)
            if harborageZoneName ~= "" then
                return harborageZoneId, harborageZoneName, harborageZoneId, "main-story-harborage"
            end
        end
    end

    if qIndex > 0 and type(GetJournalQuestZoneStoryZoneId) == "function" then
        local zoneStoryId = tonumber(safe(GetJournalQuestZoneStoryZoneId, 0, qIndex)) or 0
        if zoneStoryId > 0 then
            local zid, name = getOverlandZone(zoneStoryId)
            if zid > 0 and name ~= "" then return zid, name, zoneStoryId, "zone-story" end
        end
    end

    if qIndex > 0 and type(GetJournalQuestStartingZone) == "function" then
        local startZoneIndex = tonumber(safe(GetJournalQuestStartingZone, 0, qIndex)) or 0
        if startZoneIndex > 0 and type(GetZoneId) == "function" then
            local startZoneId = tonumber(safe(GetZoneId, 0, startZoneIndex)) or 0
            if startZoneId > 0 then
                local zid, name = getOverlandZone(startZoneId)
                if zid > 0 and name ~= "" then return zid, name, startZoneId, "starting-zone" end
            end
        end
    end

    local rawZoneId = tonumber(fallbackRawZoneId) or 0
    if rawZoneId <= 0 and tonumber(questId or 0) > 0 and type(GetQuestZoneId) == "function" then
        rawZoneId = tonumber(safe(GetQuestZoneId, 0, tonumber(questId))) or 0
    end
    local zid, name = getOverlandZone(rawZoneId)
    return zid, name, rawZoneId, "quest-record"
end

-- A small hint table remains for well-known quest starters. The actual browser is
-- built from ESO's quest records at runtime instead of being capped to this list.
-- v0.27.37: canonical Prophet/Main Story progression used by the Quest Finder
-- MAIN QUEST view. ESO exposes quest identity/completion, but not a single API
-- that returns the full story chain in progression order, so the Suite keeps the
-- known base-game Main Story order and resolves each entry against ESO quest IDs.
Q.MAIN_QUEST_CHAIN_2737 = {
    "Soul Shriven in Coldharbour",
    "The Harborage",
    "Daughter of Giants",
    "Chasing Shadows",
    "Castle of the Worm",
    "The Tharn Speaks",
    "Halls of Torment",
    "Valley of Blades",
    "Shadow of Sancre Tor",
    "Council of the Five Companions",
    "Messages Across Tamriel",
    "The Weight of Three Crowns",
    -- Coldharbour story bridge. Several of these are reported by ESO as
    -- zone-story quests even though they are required to reach the final
    -- Main Story assault, so they belong in the Suite's Main Quest path.
    "The Hollow City",
    "The Army of Meridia",
    "Into the Woods",
    "Light from the Darkness",
    "Vanus Unleashed",
    "Breaking the Shackle",
    "Crossing the Chasm",
    "The Harvest Heart",
    "The Citadel Must Fall",
    "The Final Assault",
    "God of Schemes",
}


-- v0.27.42: curated pre-acceptance information for Main Story steps where ESO
-- does not expose an unaccepted quest pin through the API. These hints are used
-- only until the quest is accepted; live journal objectives take over after that.
-- v0.27.62: Cadwell's Almanac - Aldmeri Dominion objective path.
-- Cadwell's Silver/Gold is an umbrella quest; progression is earned by completing
-- the required Almanac objectives inside the opposing alliance zones. Keep the
-- objective locations grouped exactly as the player sees the journey: Auridon,
-- Grahtwood, Greenshade, Malabal Tor, then Reaper's March.
Q.CADWELL_AD_ALMANAC_2762 = {
    {zone="Auridon", area="Vulkhel Guard", quests={"Ensuring Security","A Hostile Situation"}},
    {zone="Auridon", area="Tanzelwil", quests={"In the Name of the Queen","Rites of the Queen"}},
    {zone="Auridon", area="Mathiisen", quests={"Putting the Pieces Together","The Unveiling"}},
    {zone="Auridon", area="Skywatch", quests={"Lifting the Veil","Wearing the Veil","The Veil Falls"}},
    {zone="Auridon", area="Firsthold", quests={"Breaking the Barrier","Sever All Ties"}},

    {zone="Grahtwood", area="Southpoint", quests={"The Grip of Madness"}},
    {zone="Grahtwood", area="Reliquary of Stars", quests={"Lost in Study","Heart of the Matter"}},
    {zone="Grahtwood", area="Falinesti Winter Site", quests={"A Lasting Winter"}},
    {zone="Grahtwood", area="Elden Root", quests={"The Honor of the Queen","Fit to Rule","The Orrery of Elden Root"}},

    {zone="Greenshade", area="Bramblebreach", quests={"Frighten the Fearsome","Audience with the Wilderking"}},
    {zone="Greenshade", area="Greenheart", quests={"Throne of the Wilderking","The Staff of Magnus"}},
    {zone="Greenshade", area="Woodhearth", quests={"Veil of Illusion","Double Jeopardy"}},
    {zone="Greenshade", area="Seaside Sanctuary", quests={"A Storm Upon the Shore","Pelidil's End"}},
    {zone="Greenshade", area="Dread Vullain", quests={"Right of Theft"}},
    {zone="Greenshade", area="Verrant Morass", quests={"The Blight of the Bosmer"}},
    {zone="Greenshade", area="Driladan Pass", quests={"Retaking the Pass"}},
    {zone="Greenshade", area="Hectahame", quests={"Striking at the Heart"}},

    {zone="Malabal Tor", area="Velyn Harbor", quests={"House and Home","One Fell Swoop","The Drublog of Dra'bul"}},
    {zone="Malabal Tor", area="Dra'bul", quests={"Reap What Is Sown"}},
    {zone="Malabal Tor", area="Jathsogur", quests={"The Prisoner of Jathsogur"}},
    {zone="Malabal Tor", area="Silvenar", quests={"Restore the Silvenar"}},

    {zone="Reaper's March", area="Fort Grimwatch", quests={"Grim Situation","Grimmer Still"}},
    {zone="Reaper's March", area="Arenthia", quests={"The Colovian Occupation","Stonefire Machinations","A Door Into Moonlight"}},
    {zone="Reaper's March", area="Rawl'kha", quests={"The First Step"}},
    {zone="Reaper's March", area="Moonmont", quests={"Motes in the Moonlight"}},
    {zone="Reaper's March", area="Dune", quests={"The Fires of Dune"}},
    {zone="Reaper's March", area="Two Moons Path", quests={"The Moonlit Path","The Den of Lorkhaj"}},
}

Q.MAIN_QUEST_START_HINTS_2742 = {
    [lower("Soul Shriven in Coldharbour")] = {
        giver = "The Hooded Figure",
        acceptAt = "Your alliance starter city",
        prerequisite = "Begin the base-game Main Story",
    },
    [lower("The Harborage")] = {
        giver = "The Prophet",
        acceptAt = "The Harborage",
    },
    [lower("The Citadel Must Fall")] = {
        giver = "King Laloriaran Dynar",
        acceptAt = "Reaver Citadel, Coldharbour",
        prerequisite = "Complete the preceding northern Coldharbour story step",
        routeNote = "Travel toward Reaver Citadel in northern Coldharbour. Once accepted, the Suite switches to its live journal objectives instead of routing to the starter.",
    },
    [lower("The Final Assault")] = {
        giver = "Vanus Galerion",
        acceptAt = "The Endless Stair, Coldharbour",
        prerequisite = "Complete The Citadel Must Fall",
        routeNote = "Travel into northern Coldharbour and approach The Endless Stair. Vanus Galerion starts the quest there.",
    },
    [lower("God of Schemes")] = {
        giver = "The Prophet",
        acceptAt = "The Harborage",
        prerequisite = "Complete The Final Assault",
        routeNote = "After The Final Assault, return to The Harborage. The Prophet starts God of Schemes.",
    },
}

Q.curatedHints = {
    [lower("Soul Shriven in Coldharbour")] = {starter="The Hooded Figure / alliance starter city", access="BASE GAME", type="Main Story"},
    [lower("The Harborage")] = {starter="The Prophet", access="BASE GAME", type="Main Story"},
    [lower("The Demon Weapon")] = {starter="Abnur Tharn", access="BASE-GAME PROLOGUE", type="Prologue"},
    [lower("The Coven Conspiracy")] = {starter="Skald-King's Agent / Crown Store starter", access="BASE-GAME PROLOGUE", type="Prologue"},
    [lower("Orsinium")] = {starter="Stuga / Wrothgar introduction", access="ORSINIUM", type="Zone Story"},
    [lower("Divine Conundrum")] = {starter="Vvardenfell story introduction", access="MORROWIND", type="Zone Story"},
    [lower("The Queen's Decree")] = {starter="Razum-dar / Summerset introduction", access="SUMMERSET", type="Zone Story"},
    [lower("A Rage of Dragons")] = {starter="Northern Elsweyr story introduction", access="ELSWEYR", type="Zone Story"},
    [lower("The Gathering Storm")] = {starter="Western Skyrim story introduction", access="GREYMOOR", type="Zone Story"},
    [lower("A Mortal's Touch")] = {starter="Blackwood story introduction", access="BLACKWOOD", type="Zone Story"},
    [lower("No Regrets")] = {starter="High Isle story introduction", access="HIGH ISLE", type="Zone Story"},
    [lower("Fate's Proxy")] = {starter="Necrom story introduction", access="NECROM", type="Zone Story"},
    [lower("The Untraveled Road")] = {starter="Gold Road story introduction", access="GOLD ROAD", type="Zone Story"},
}

local function likelyInternalQuest(name)
    local s = lower(trim(name))
    if s == "" then return true end
    if string.find(s, "_outofdate", 1, true) then return true end
    if string.find(s, "debug quest", 1, true) then return true end
    if string.find(s, "dummy quest", 1, true) then return true end
    if string.find(s, "placeholder quest", 1, true) then return true end
    if string.find(s, "do not use", 1, true) then return true end
    if string.find(s, "bug check", 1, true) then return true end
    if s == "simple kill quest" then return true end
    if string.match(s, "^tm%d+") then return true end
    return false
end

local function questTypeText(questId)
    local questType = safe(GetQuestType, nil, questId)
    if questType ~= nil and type(GetString) == "function" then
        local ok, text = pcall(GetString, "SI_QUESTTYPE", questType)
        if ok and text and text ~= "" then return text end
    end
    return "Quest"
end

function Q:Initialize()
    self.searchText = ""
    self.filter = "NOT_STARTED"
    self.offset = 0
    self.selectedKey = nil
    self.lastView = nil
    self.index = {}
    self.indexByKey = {}
    self.scanNextId = 1
    self.scanDone = false
    self.scanStarted = false
    self.mainQuestSelectedKey2737 = nil
    -- Quest Finder can contain thousands of NOT STARTED records. Keep short-lived
    -- caches so mouse movement / UI refreshes do not rebuild the full data set.
    self.entriesCache2973 = nil
    self.entriesCacheKey2973 = nil
    self.entriesCacheAt2973 = 0
    self.activeQuestCache2973 = nil
    self.activeQuestCacheAt2973 = 0
    self.entriesKeyMap2973 = nil

    -- Keep the expensive NOT STARTED list cached until quest state actually
    -- changes. Hovering and ordinary UI repainting must never invalidate it.
    if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForEvent) == "function" then
        local prefix = (EPC.name or "ESOAdventurerSuite") .. "_QuestFinderCache"
        local seen = {}
        local function register(eventId)
            if eventId and not seen[eventId] then
                seen[eventId] = true
                EPC.Runtime:RegisterEvent("QuestFinder", "Cache" .. tostring(eventId), eventId, function()
                    self:InvalidateRuntimeCaches2973()
                end)
            end
        end
        register(EVENT_QUEST_ADDED)
        register(EVENT_QUEST_REMOVED)
        register(EVENT_QUEST_COMPLETE)
        register(EVENT_PLAYER_ACTIVATED)
    end
end

function Q:InvalidateRuntimeCaches2973()
    self.entriesCache2973 = nil
    self.entriesCacheKey2973 = nil
    self.entriesCacheAt2973 = 0
    self.entriesKeyMap2973 = nil
    self.activeQuestCache2973 = nil
    self.activeQuestCacheAt2973 = 0
    self.completedCache = nil
    self.completedCacheAt = 0
end

function Q:StartScan()
    if self.scanStarted then return end
    self.scanStarted = true
    local function kickoff() self:ScanChunk() end
    if type(zo_callLater) == "function" then zo_callLater(kickoff, 25) else kickoff() end
end

function Q:ScanChunk()
    if self.scanDone then return end
    if type(IsUnitInCombat) == "function" and safe(IsUnitInCombat, false, "player") == true then
        local function resume() self:ScanChunk() end
        if type(zo_callLater) == "function" then zo_callLater(resume, 250) end
        return
    end
    if type(GetQuestName) ~= "function" or type(GetQuestZoneId) ~= "function" then
        self.scanDone = true
        return
    end

    local firstId = self.scanNextId or 1
    local lastId = math.min(self.SCAN_MAX_ID, firstId + self.SCAN_CHUNK - 1)
    for questId = firstId, lastId do
        local name = trim(safe(GetQuestName, "", questId))
        if name ~= "" and not likelyInternalQuest(name) then
            local rawZoneId = tonumber(safe(GetQuestZoneId, 0, questId)) or 0
            local zoneId, zone = getOverlandZone(rawZoneId)
            -- zoneId 0 is commonly used by obsolete/internal records, so exclude it
            -- from the discovery index rather than presenting it as a real quest.
            if zoneId > 0 and zone ~= "" then
                local key = lower(name) .. "|" .. tostring(zoneId)
                if not self.indexByKey[key] then
                    local nameLower = lower(name)
                    local hint = self.curatedHints[nameLower]
                    local entryType = hint and hint.type or questTypeText(questId)
                    local access = hint and hint.access or "GAME QUEST INDEX"
                    local entry = {
                        key = "QUEST:" .. tostring(questId),
                        questId = questId,
                        name = name,
                        nameLower = nameLower,
                        zoneId = zoneId,
                        rawZoneId = rawZoneId,
                        zone = zone,
                        type = entryType,
                        starter = hint and hint.starter or "Exact unaccepted quest-giver position is not exposed; route to the zone and follow local quest markers.",
                        access = access,
                        dlc = hint and hint.access ~= "BASE GAME" or false,
                        searchHay2973 = lower(name .. " " .. zone .. " " .. entryType .. " " .. access .. " " .. tostring(questId)),
                    }
                    self.indexByKey[key] = entry
                    self.index[#self.index + 1] = entry
                end
            end
        end
    end

    self.scanNextId = lastId + 1
    if self.scanNextId > self.SCAN_MAX_ID then
        self.scanDone = true
        table.sort(self.index, function(a, b)
            local an, bn = lower(a.name), lower(b.name)
            if an == bn then return lower(a.zone) < lower(b.zone) end
            return an < bn
        end)
        self.entriesCache2973 = nil
        self.entriesCacheKey2973 = nil
        self.entriesCacheAt2973 = 0
        self.entriesKeyMap2973 = nil
        if EPC.RequestRefresh then EPC:RequestRefresh("quest-index-ready") end
        return
    end

    if (lastId % 1000) == 0 and EPC.RequestRefresh then EPC:RequestRefresh("quest-index-scan") end
    local function again() self:ScanChunk() end
    if type(zo_callLater) == "function" then zo_callLater(again, self.SCAN_DELAY_MS or 35) else again() end
end

-- v0.28.61: build one authoritative live-journal snapshot instead of assuming
-- every client stores accepted quests inside a fixed 1..25 slot range. current live ESO
-- exposes a live journal count, but long-running clients and compatibility
-- layers can still differ, so scan a small safe range and use both
-- journal-name APIs before deciding that a slot is empty.
function Q:GetLiveJournalEntries2861()
    local entries = {}
    local expected = tonumber(safe(GetNumJournalQuests, 0)) or 0
    local declaredMax = tonumber(rawget(_G, "MAX_JOURNAL_QUESTS")) or 0
    local scanMax = math.max(25, expected, declaredMax)
    -- A 100-slot scan is trivial on the Quest Finder page and protects against
    -- future journal-cap changes without hard failing accepted-quest detection.
    scanMax = math.min(math.max(scanMax, 100), 200)

    for i = 1, scanMax do
        -- Read the slot directly even when IsValidQuestIndex is unavailable or a
        -- compatibility layer reports a stale validity result. These calls are
        -- protected by safe(), so an invalid slot simply resolves to no name.
        local name = trim(safe(GetJournalQuestName, "", i))
        if name == "" then
            name = trim(safe(GetJournalQuestInfo, "", i))
        end

        if name ~= "" then
            local questId = tonumber(safe(GetJournalQuestId, 0, i)) or 0
            if questId <= 0 and type(GetQuestIdFromName) == "function" then
                questId = tonumber(safe(GetQuestIdFromName, 0, name)) or 0
            end
            entries[#entries + 1] = {
                questIndex = i,
                questId = questId,
                name = name,
            }
        end
    end
    return entries
end

function Q:GetActiveQuestMap()
    local now = tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
    local cached = self.activeQuestCache2973
    if cached and (now <= 0 or (now - (self.activeQuestCacheAt2973 or 0)) < (self.ACTIVE_CACHE_MS or 500)) then
        return cached.byId, cached.byName, cached.entries
    end

    local byId, byName = {}, {}
    local journalEntries = self:GetLiveJournalEntries2861()
    for _, entry in ipairs(journalEntries) do
        if (tonumber(entry.questId) or 0) > 0 then byId[entry.questId] = entry.questIndex end
        byName[lower(entry.name)] = entry.questIndex
    end
    self.activeQuestCache2973 = {byId = byId, byName = byName, entries = journalEntries}
    self.activeQuestCacheAt2973 = now
    return byId, byName, journalEntries
end

function Q:GetCompletedQuestSet()
    local now = tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
    if self.completedCache and (now <= 0 or (now - (self.completedCacheAt or 0)) < 30000) then
        return self.completedCache
    end
    local done = {}
    if type(GetNextCompletedQuestId) == "function" then
        local last, safety = nil, 0
        while safety < 20000 do
            local questId = safe(GetNextCompletedQuestId, nil, last)
            if questId == nil then break end
            done[questId] = true
            last = questId
            safety = safety + 1
        end
    end
    self.completedCache, self.completedCacheAt = done, now
    return done
end

function Q:BuildMainQuestEntries2737()
    local activeById, activeByName = self:GetActiveQuestMap()
    local completed = self:GetCompletedQuestSet()
    local byName = {}
    for i = 1, #self.index do
        local src = self.index[i]
        byName[lower(src.name)] = src
    end

    local rows = {}
    local firstIncomplete = nil
    for order, questName in ipairs(self.MAIN_QUEST_CHAIN_2737 or {}) do
        local src = byName[lower(questName)]
        local questId = src and tonumber(src.questId) or tonumber(safe(GetQuestIdFromName, 0, questName)) or 0
        local activeIndex = nil
        if questId > 0 then activeIndex = activeById[questId] end
        if not activeIndex then activeIndex = activeByName[lower(questName)] end
        local isCompleted = questId > 0 and completed[questId] == true or false
        if not isCompleted and not firstIncomplete then firstIncomplete = order end

        local rawZoneId = src and (src.rawZoneId or src.zoneId) or 0
        local zoneId, zone, resolvedRawZoneId = getJournalOverlandZone(activeIndex or 0, questId, rawZoneId)
        if (not zone or zone == "") and src then zone = src.zone end
        if not zone or zone == "" then zone = "Main Story" end

        local startHint = self.MAIN_QUEST_START_HINTS_2742 and self.MAIN_QUEST_START_HINTS_2742[lower(questName)] or nil
        rows[#rows + 1] = {
            key = src and src.key or ("MAIN:" .. tostring(order)),
            questId = questId,
            name = questName,
            zoneId = zoneId or (src and src.zoneId) or 0,
            rawZoneId = resolvedRawZoneId or rawZoneId,
            zone = zone,
            starter = src and src.starter or (startHint and startHint.giver) or "Follow the Main Story starter marker / Prophet objective.",
            questGiver = startHint and startHint.giver or nil,
            acceptAt = startHint and startHint.acceptAt or nil,
            prerequisite = startHint and startHint.prerequisite or nil,
            routeNote = startHint and startHint.routeNote or nil,
            type = "Main Story", access = "BASE GAME", dlc = false,
            questIndex = activeIndex, completed = isCompleted,
            mainQuest = true, chainOrder = order,
        }
    end

    -- Mark progression after the completion/current state is known.
    local hasCurrent = false
    for _, row in ipairs(rows) do if row.questIndex then hasCurrent = true break end end
    for _, row in ipairs(rows) do
        if row.completed then
            row.status = "COMPLETED"
        elseif row.questIndex then
            row.status = "CURRENT"
        elseif not hasCurrent and firstIncomplete and row.chainOrder == firstIncomplete then
            row.status = "NEXT"
        elseif firstIncomplete and row.chainOrder == firstIncomplete then
            row.status = "NEXT"
        else
            row.status = "LOCKED"
        end
    end

    local query = lower(trim(self.searchText))
    if query ~= "" then
        local filtered = {}
        for _, row in ipairs(rows) do
            local hay = lower(row.name .. " " .. row.zone .. " " .. row.status .. " main story")
            if string.find(hay, query, 1, true) then filtered[#filtered + 1] = row end
        end
        rows = filtered
    end
    return rows
end

function Q:BuildCadwellADEntries2762()
    local activeById, activeByName = self:GetActiveQuestMap()
    local completed = self:GetCompletedQuestSet()
    local byName = {}
    for i = 1, #self.index do
        local src = self.index[i]
        byName[lower(src.name)] = src
    end

    local rows, firstIncomplete = {}, nil
    for order, objective in ipairs(self.CADWELL_AD_ALMANAC_2762 or {}) do
        local total, doneCount, activeQuestIndex = #(objective.quests or {}), 0, nil
        local target = nil
        local questLines = {}
        for _, questName in ipairs(objective.quests or {}) do
            local src = byName[lower(questName)]
            local questId = src and tonumber(src.questId) or tonumber(safe(GetQuestIdFromName, 0, questName)) or 0
            local activeIndex = (questId > 0 and activeById[questId]) or activeByName[lower(questName)]
            local isDone = questId > 0 and completed[questId] == true or false
            if isDone then doneCount = doneCount + 1 end
            if not activeQuestIndex and activeIndex then activeQuestIndex = activeIndex end
            if not target and not isDone then
                target = {
                    questId=questId, name=questName, questIndex=activeIndex,
                    zoneId=src and src.zoneId or 0, rawZoneId=src and (src.rawZoneId or src.zoneId) or 0,
                    starter=src and src.starter or "Follow the Cadwell's Almanac objective marker in this area.",
                }
            end
            questLines[#questLines+1] = (isDone and "[DONE] " or (activeIndex and "[ACTIVE] " or "[ ] ")) .. questName
        end
        local complete = total > 0 and doneCount >= total
        if not complete and not firstIncomplete then firstIncomplete = order end
        target = target or {questId=0, name=objective.quests and objective.quests[1] or objective.area, zoneId=0, rawZoneId=0, starter="Objective complete"}
        local zoneId, zone, rawZoneId = getJournalOverlandZone(target.questIndex or 0, target.questId, target.rawZoneId)
        if zone == "" then zone = objective.zone end
        rows[#rows+1] = {
            key="CADWELL_AD:" .. tostring(order), name=objective.area, zone=objective.zone,
            zoneId=zoneId or target.zoneId or 0, rawZoneId=rawZoneId or target.rawZoneId or 0,
            questId=target.questId, questIndex=target.questIndex or activeQuestIndex,
            starter=target.starter, access="BASE GAME - CADWELL'S ALMANAC", type="Cadwell's Almanac",
            completed=complete, cadwell=true, chainOrder=order,
            objectiveProgress=string.format("%d/%d", doneCount, total),
            objectiveQuests=table.concat(questLines, "\n"),
            targetQuestName=target.name,
        }
    end
    for _, row in ipairs(rows) do
        if row.completed then row.status="COMPLETED"
        elseif row.questIndex then row.status="CURRENT"
        elseif row.chainOrder == firstIncomplete then row.status="NEXT"
        else row.status="LOCKED" end
    end
    local query=lower(trim(self.searchText))
    if query ~= "" then
        local filtered={}
        for _,row in ipairs(rows) do
            local hay=lower(row.name.." "..row.zone.." "..row.status.." "..(row.objectiveQuests or "").." cadwell silver almanac")
            if string.find(hay, query, 1, true) then filtered[#filtered+1]=row end
        end
        rows=filtered
    end
    return rows
end

function Q:BuildEntries()
    if self.filter == "MAIN_QUEST" then
        return self:BuildMainQuestEntries2737()
    elseif self.filter == "CADWELL" then
        return self:BuildCadwellADEntries2762()
    end
    local activeById, activeByName, liveJournal = self:GetActiveQuestMap()
    local completed = self:GetCompletedQuestSet()
    local entries, seenActive = {}, {}
    local query = lower(trim(self.searchText))

    for i = 1, #self.index do
        local src = self.index[i]
        local activeIndex = activeById[src.questId] or activeByName[src.nameLower or lower(src.name)]
        if activeIndex then seenActive[activeIndex] = true end
        local isCompleted = completed[src.questId] == true
        local status = activeIndex and "ACTIVE" or (isCompleted and "COMPLETED" or "NOT STARTED")
        local include = self.filter == "ALL"
            or (self.filter == "ACTIVE" and activeIndex ~= nil)
            or (self.filter == "NOT_STARTED" and activeIndex == nil and not isCompleted)
        if include then
            local hay = src.searchHay2973 or lower(src.name .. " " .. src.zone .. " " .. src.type .. " " .. src.access .. " " .. tostring(src.questId))
            if query == "" or string.find(hay, query, 1, true) then
                -- NOT STARTED is by far the largest Quest Finder view. During the
                -- initial index scan we already resolved every source quest to a stable
                -- overland zone. Re-running the journal/parent-zone resolver for every
                -- unaccepted row made simple UI refreshes very expensive. Only active
                -- journal quests need the live journal resolver.
                local resolvedZoneId, resolvedZone, resolvedRawZoneId
                if activeIndex then
                    resolvedZoneId, resolvedZone, resolvedRawZoneId = getJournalOverlandZone(
                        activeIndex, src.questId, src.rawZoneId or src.zoneId
                    )
                else
                    resolvedZoneId = tonumber(src.zoneId) or 0
                    resolvedRawZoneId = tonumber(src.rawZoneId) or resolvedZoneId
                    resolvedZone = tostring(src.zone or "")
                end
                entries[#entries + 1] = {
                    key = src.key, questId = src.questId, name = src.name,
                    zoneId = resolvedZoneId, rawZoneId = resolvedRawZoneId or src.rawZoneId or src.zoneId,
                    zone = resolvedZone ~= "" and resolvedZone or src.zone,
                    starter = src.starter, type = src.type, access = src.access, dlc = src.dlc,
                    status = status, questIndex = activeIndex, completed = isCompleted,
                }
            end
        end
    end

    -- Always include accepted journal quests even if their quest ID sits outside the
    -- scanned range or uses a record filtered from the discovery index.
    if self.filter == "ACTIVE" or self.filter == "ALL" then
        for _, journalEntry in ipairs(liveJournal or self:GetLiveJournalEntries2861()) do
            local i = tonumber(journalEntry.questIndex) or 0
            local name = trim(journalEntry.name)
            if i > 0 and name ~= "" and not seenActive[i] then
                local questId = tonumber(journalEntry.questId) or 0
                -- Do not use GetJournalQuestLocationInfo() as the zone label here.
                -- For instanced objectives it may return an objective/instance name
                -- (for example the quest title) rather than the overland zone.
                local rawZoneId = questId > 0 and (tonumber(safe(GetQuestZoneId, 0, questId)) or 0) or 0
                local zoneId, zone, resolvedRawZoneId = getJournalOverlandZone(i, questId, rawZoneId)
                rawZoneId = resolvedRawZoneId or rawZoneId
                if zone == "" then zone = "Accepted quest" end
                local hay = lower(name .. " " .. zone .. " " .. tostring(questId))
                if query == "" or string.find(hay, query, 1, true) then
                    entries[#entries + 1] = {
                        key = "JOURNAL:" .. tostring(i), questId = questId, name = name,
                        zoneId = zoneId, rawZoneId = rawZoneId, zone = zone,
                        starter = "Already accepted", type = "Journal Quest", access = "ACTIVE JOURNAL",
                        dlc = false, status = "ACTIVE", questIndex = i,
                    }
                end
            end
        end
    end

    if self.filter ~= "NOT_STARTED" or not self.scanDone then
        table.sort(entries, function(a, b)
            local an, bn = lower(a.name), lower(b.name)
            if an == bn then return lower(a.zone) < lower(b.zone) end
            return an < bn
        end)
    end
    return entries
end

function Q:BuildView()
    if not self.scanStarted then self:StartScan() end

    -- The Codex can ask for a refresh several times while the mouse is moving.
    -- Reuse the same filtered quest list for a fraction of a second rather than
    -- rebuilding/sorting thousands of NOT STARTED rows for each UI refresh.
    local now = tonumber(safe(GetFrameTimeMilliseconds, 0)) or 0
    local cacheKey = tostring(self.filter or "NOT_STARTED") .. "|" .. lower(trim(self.searchText))
    local entries = nil
    if self.entriesCache2973 and self.entriesCacheKey2973 == cacheKey and
       (now <= 0 or (now - (self.entriesCacheAt2973 or 0)) < (self.ENTRIES_CACHE_MS or 600)) then
        entries = self.entriesCache2973
    else
        entries = self:BuildEntries()
        self.entriesCache2973 = entries
        self.entriesCacheKey2973 = cacheKey
        self.entriesCacheAt2973 = now
        local keyMap = {}
        for i = 1, #entries do
            local entry = entries[i]
            if entry and entry.key then keyMap[entry.key] = entry end
        end
        self.entriesKeyMap2973 = keyMap
    end
    local maxOffset = math.max(0, #entries - self.PAGE_SIZE)
    self.offset = math.max(0, math.min(self.offset or 0, maxOffset))
    local rows = {}
    for i = 1, self.PAGE_SIZE do
        local e = entries[self.offset + i]
        if e then rows[#rows + 1] = e end
    end
    local selected = nil
    if self.selectedKey then
        selected = self.entriesKeyMap2973 and self.entriesKeyMap2973[self.selectedKey] or nil
        if not selected then
            for i = 1, #entries do
                if entries[i].key == self.selectedKey then selected = entries[i] break end
            end
        end
    end
    local progress = self.scanDone and "INDEX READY" or string.format("SCANNING %d/%d", math.min(self.scanNextId or 1, self.SCAN_MAX_ID), self.SCAN_MAX_ID)
    local pageSize = math.max(1, tonumber(self.PAGE_SIZE) or 8)
    local pageCount = math.max(1, math.ceil(#entries / pageSize))
    local page = 1
    if (tonumber(self.offset) or 0) > 0 then
        page = math.min(pageCount, math.floor(((tonumber(self.offset) or 0) - 1) / pageSize) + 2)
    end
    local mainView = self.filter == "MAIN_QUEST"
    local cadwellView = self.filter == "CADWELL"
    local view = {
        header = mainView and "MAIN QUEST" or (cadwellView and "CADWELL'S ALMANAC" or "QUEST JOURNAL"),
        title = mainView and "Main Story Progress" or (cadwellView and "Cadwell's Silver - Aldmeri Dominion" or "Find quests you have not started"),
        description = mainView and "Main Story quests in progression order. Completed, current, next, and later steps are shown together. Select the current/next step to track it in the MAIN QUEST overlay source and travel toward its nearest resolved wayshrine." or (cadwellView and "Cadwell's Silver is an umbrella quest. This view tracks the required Aldmeri Dominion Almanac objectives by area across Auridon, Grahtwood, Greenshade, Malabal Tor, and Reaper's March." or "Browse a runtime index of ESO quest records instead of a short curated list. Select a quest to route toward its zone. ESO does not expose one global 'currently obtainable quest' iterator, so retired/internal records are filtered on a best-effort basis."),
        filter = self.filter, searchText = self.searchText, rows = rows, total = #entries, offset = self.offset, page = page, pageCount = pageCount, pageSize = pageSize,
        selected = selected, scanDone = self.scanDone, scanProgress = progress, indexed = #self.index,
        stats = {
            {label="FILTER", value=self.filter == "NOT_STARTED" and "NOT STARTED" or (self.filter == "MAIN_QUEST" and "MAIN QUEST" or (self.filter == "CADWELL" and "CADWELL" or self.filter))},
            {label="MATCHES", value=tostring(#entries)},
            {label="INDEX", value=self.scanDone and tostring(#self.index) or progress},
            {label="SELECTED", value=selected and selected.status or "NONE"},
        },
    }
    self.lastView = view
    return view
end

function Q:SetFilter(filter)
    filter = string.upper(tostring(filter or "NOT_STARTED"))
    if filter == "NOT STARTED" then filter = "NOT_STARTED" end
    if filter == "MAIN QUEST" then filter = "MAIN_QUEST" end
    if filter == "CADWELL'S ALMANAC" or filter == "CADWELL SILVER" then filter = "CADWELL" end
    if filter ~= "NOT_STARTED" and filter ~= "ACTIVE" and filter ~= "MAIN_QUEST" and filter ~= "CADWELL" and filter ~= "ALL" then return false end
    self.filter, self.offset, self.selectedKey = filter, 0, nil
    self.entriesCache2973 = nil
    self.entriesCacheKey2973 = nil
    self.entriesCacheAt2973 = 0
    self.entriesKeyMap2973 = nil
    return true
end

function Q:SetSearch(text)
    self.searchText, self.offset, self.selectedKey = tostring(text or ""), 0, nil
    self.entriesCache2973 = nil
    self.entriesCacheKey2973 = nil
    self.entriesCacheAt2973 = 0
    self.entriesKeyMap2973 = nil
end

function Q:Scroll(delta)
    delta = tonumber(delta) or 0
    local view = self.lastView or self:BuildView()
    local maxOffset = math.max(0, (view.total or 0) - self.PAGE_SIZE)
    self.offset = math.max(0, math.min(maxOffset, (self.offset or 0) + delta))
    if EPC.UI and EPC.saved and EPC.saved.activeTab == "QUESTS" then EPC.UI:RenderQuest(self:BuildView()) end
end

-- AssistAcceptedQuest2511 is defined once below by the authoritative Suite quest-source policy.

function Q:SelectRow(index)
    local view = self.lastView or self:BuildView()
    local entry = view.rows and view.rows[index]
    if not entry then return end
    self.selectedKey = entry.key

    if entry.mainQuest then
        -- MAIN QUEST selections own the dedicated overlay source. Accepted
        -- Main Story quests can be fully assisted by ESO. A not-yet-started
        -- NEXT quest is remembered as a discovery target so the overlay and
        -- travel tools still show the user's intended next story step.
        if EPC.saved then
            EPC.saved.mainQuestDiscoveryTarget = nil
            EPC.saved.mainQuestFinderSelected = entry.questIndex ~= nil
            if entry.questIndex then
                EPC.saved.mainHudQuestIndex = entry.questIndex
                EPC.saved.mainHudQuestId = tonumber(entry.questId) or 0
                EPC.saved.mainHudQuestName = tostring(entry.name or "")
            elseif not entry.completed then
                EPC.saved.mainQuestDiscoveryTarget = {
                    key = entry.key, questId = entry.questId, name = entry.name,
                    zone = entry.zone, zoneId = entry.zoneId, rawZoneId = entry.rawZoneId,
                    starter = entry.starter, questGiver = entry.questGiver, acceptAt = entry.acceptAt,
                    prerequisite = entry.prerequisite, routeNote = entry.routeNote,
                    status = entry.status, chainOrder = entry.chainOrder,
                }
            end
        end
        if entry.questIndex and EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
            EPC.ActiveQuest:SetSelectedQuest2512(entry.questIndex, entry.questId, entry.name, "MAIN_QUEST")
        end
        if EPC.ActiveQuest and EPC.ActiveQuest.SetQuestTrackingSource2513 then
            EPC.ActiveQuest:SetQuestTrackingSource2513("MAIN_QUEST")
        elseif EPC.saved then
            EPC.saved.questTrackingSource = "MAIN_QUEST"
            if EPC.ActiveQuest and EPC.ActiveQuest.Refresh then EPC.ActiveQuest:Refresh() end
        end
    elseif entry.questIndex then
        self:AssistAcceptedQuest2511(entry, false)
    end

    if EPC.UI and EPC.saved and EPC.saved.activeTab == "QUESTS" then EPC.UI:RenderQuest(self:BuildView()) end
end

function Q:TravelNearestWayshrineSelected()
    local view = self.lastView or self:BuildView()
    local q = view.selected
    if not q then
        EPC:Print("Select a quest first.")
        return false
    end
    if not EPC.Travel or type(EPC.Travel.TravelToNearestQuestStarterWayshrine) ~= "function" then
        EPC:Print("Quest wayshrine travel is unavailable.")
        return false
    end
    return EPC.Travel:TravelToNearestQuestStarterWayshrine(q)
end

function Q:RouteSelected()
    local view = self.lastView or self:BuildView()
    local q = view.selected
    if not q then EPC:Print("Select a quest first.") return end

    if q.mainQuest then
        -- Keep the dedicated Main Quest HUD source authoritative whenever a
        -- Main Story row is selected/routed.
        if q.questIndex then
            if EPC.saved then EPC.saved.mainQuestFinderSelected = true end
            if EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
                EPC.ActiveQuest:SetSelectedQuest2512(q.questIndex, q.questId, q.name, "MAIN_QUEST")
            end
            if EPC.ActiveQuest and EPC.ActiveQuest.SetQuestTrackingSource2513 then
                EPC.ActiveQuest:SetQuestTrackingSource2513("MAIN_QUEST")
            end
            self:AssistAcceptedQuest2511(q, true)
            EPC:Print("Tracking Main Quest: " .. q.name)
            return
        end
        if q.completed then
            EPC:Print("Main Quest already completed: " .. q.name)
            return
        end
        if EPC.saved then
            EPC.saved.mainQuestDiscoveryTarget = {name=q.name, questId=q.questId, zone=q.zone, zoneId=q.zoneId, rawZoneId=q.rawZoneId, starter=q.starter, questGiver=q.questGiver, acceptAt=q.acceptAt, prerequisite=q.prerequisite, routeNote=q.routeNote, status=q.status, chainOrder=q.chainOrder}
            EPC.saved.questTrackingSource = "MAIN_QUEST"
        end
        if EPC.ActiveQuest and EPC.ActiveQuest.Refresh then EPC.ActiveQuest:Refresh() end
        EPC:Print(string.format("Next Main Quest: %s - %s. Use TRAVEL NEAREST SHRINE to get close to its start.", q.name, q.zone))
        return
    end

    if q.questIndex then
        self:AssistAcceptedQuest2511(q, true)
        EPC:Print("Assisting active quest: " .. q.name)
        return
    end

    EPC.saved.questDiscoveryTarget = {name=q.name, zone=q.zone, zoneId=q.zoneId, starter=q.starter, access=q.access}
    EPC.saved.activeTab = "MAP"
    EPC.saved.travelMode = "SHRINES"
    EPC.saved.travelPage = 1
    EPC.saved.travelBookPage = 1
    if EPC.Travel then EPC.Travel.selectedKey = nil end
    EPC:RefreshNow("quest-discovery-route")
    EPC:Print(string.format("Quest route: %s - %s. %s", q.name, q.zone, q.starter))
end

-- v0.25.16: Suite quest-source priority. Selecting an accepted quest remembers
-- it in the appropriate source slot, but only the source selected in Settings
-- is allowed to become ESO's assisted quest.
function Q:AssistAcceptedQuest2511(entry, setMapZone)
    if not entry or not entry.questIndex then return false end
    local questIndex = tonumber(entry.questIndex)
    if not questIndex then return false end

    if setMapZone and type(SetMapToQuestZone) == "function" then
        pcall(SetMapToQuestZone, questIndex)
    end

    if EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
        EPC.ActiveQuest:SetSelectedQuest2512(questIndex, entry.questId, entry.name, "QUEST_FINDER")
    end
    return true
end
-- v0.27.40: advance the dedicated Main Quest selection when a story quest
-- completes. This keeps the overlay on progression rather than leaving it on
-- the completed journal entry until the player manually reopens Quest Finder.
function Q:AdvanceMainQuestAfterCompletion2740(completedQuestName)
    if not EPC.saved then return false end
    local completedName = lower(trim(completedQuestName))
    if completedName == "" then return false end

    local completedOrder = nil
    for order, questName in ipairs(self.MAIN_QUEST_CHAIN_2737 or {}) do
        if lower(trim(questName)) == completedName then
            completedOrder = order
            break
        end
    end
    if not completedOrder then return false end

    -- Completion state can otherwise remain cached for up to five seconds.
    self.completedCache = nil
    self.completedCacheAt = nil

    local rows = self:BuildMainQuestEntries2737()
    local nextRow = nil
    for _, row in ipairs(rows or {}) do
        if tonumber(row.chainOrder) > completedOrder and row.completed ~= true then
            nextRow = row
            break
        end
    end

    EPC.saved.questTrackingSource = "MAIN_QUEST"
    EPC.saved.mainQuestFinderSelected = false
    EPC.saved.mainHudQuestIndex = nil
    EPC.saved.mainHudQuestId = nil
    EPC.saved.mainHudQuestName = nil

    if not nextRow then
        EPC.saved.mainQuestDiscoveryTarget = nil
        if EPC.ActiveQuest and EPC.ActiveQuest.Refresh then EPC.ActiveQuest:Refresh() end
        return true
    end

    self.selectedKey = nextRow.key
    self.mainQuestSelectedKey2737 = nextRow.key

    if nextRow.questIndex then
        EPC.saved.mainQuestFinderSelected = true
        EPC.saved.mainQuestDiscoveryTarget = nil
        EPC.saved.mainHudQuestIndex = nextRow.questIndex
        EPC.saved.mainHudQuestId = tonumber(nextRow.questId) or 0
        EPC.saved.mainHudQuestName = tostring(nextRow.name or "")
        if EPC.ActiveQuest and EPC.ActiveQuest.SetSelectedQuest2512 then
            EPC.ActiveQuest:SetSelectedQuest2512(nextRow.questIndex, nextRow.questId, nextRow.name, "MAIN_QUEST")
        end
    else
        EPC.saved.mainQuestDiscoveryTarget = {
            key = nextRow.key, questId = nextRow.questId, name = nextRow.name,
            zone = nextRow.zone, zoneId = nextRow.zoneId, rawZoneId = nextRow.rawZoneId,
            starter = nextRow.starter, questGiver = nextRow.questGiver, acceptAt = nextRow.acceptAt,
            prerequisite = nextRow.prerequisite, routeNote = nextRow.routeNote,
            status = "NEXT", chainOrder = nextRow.chainOrder,
        }
    end

    if EPC.ActiveQuest and EPC.ActiveQuest.SetQuestTrackingSource2513 then
        EPC.ActiveQuest:SetQuestTrackingSource2513("MAIN_QUEST")
    elseif EPC.ActiveQuest and EPC.ActiveQuest.Refresh then
        EPC.ActiveQuest:Refresh()
    end
    if EPC.Travel and EPC.Travel.InvalidateQuestPositionCache then
        EPC.Travel:InvalidateQuestPositionCache()
    end
    if EPC.RequestRefresh then EPC:RequestRefresh("main-quest-next") end
    if EPC.Print then EPC:Print("Next Main Quest: " .. tostring(nextRow.name or "Main Story")) end
    return true
end

