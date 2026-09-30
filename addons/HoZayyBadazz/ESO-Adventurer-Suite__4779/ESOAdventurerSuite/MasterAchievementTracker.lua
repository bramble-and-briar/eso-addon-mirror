-- ESO Adventurer Suite
-- v0.29.743 - deduped arenas + visible Infinite Archive + readable arena trifectas
-- Tracks every dungeon exposed by ESO's Activity Finder and maps the live
-- achievement API into Veteran / Hard Mode / Speed Run / No Death status.
-- One top-level window, child rows only. No polling while hidden.

local EPC = ESOProgressionCoach
if not EPC or not EVENT_MANAGER or not WINDOW_MANAGER then return end

EPC.MasterAchievementTracker = EPC.MasterAchievementTracker or {}
local T = EPC.MasterAchievementTracker
local EM, WM = EVENT_MANAGER, WINDOW_MANAGER

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_MasterAchievementTracker029713"
local ROW_COUNT = 14
local WINDOW_W, WINDOW_H = 1180, 790
local FILTERS = { "ALL", "INCOMPLETE", "BASE", "DLC" }
local FILTER_LABELS = { ALL="ALL DUNGEONS", INCOMPLETE="INCOMPLETE", BASE="BASE GAME", DLC="DLC" }
local STATUS_KEYS = { "VET", "HM", "SP", "ND" }
local STATUS_LABELS = { VET="VET", HM="HM", SP="SP", ND="ND" }
local STATUS_LONG = { VET="Veteran", HM="Hard Mode", SP="Speed Run", ND="No Death" }

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

local function lower(value)
    return string.lower(clean(value))
end

local function words(value)
    value = lower(value)
    value = value:gsub("['’]", "")
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function compact(value)
    return words(value):gsub("%s+", "")
end

local function containsPlain(haystack, needle)
    if haystack == "" or needle == "" then return false end
    return string.find(haystack, needle, 1, true) ~= nil
end

local function boundedContains(haystackWords, needleWords)
    if haystackWords == "" or needleWords == "" then return false end
    return containsPlain(" " .. haystackWords .. " ", " " .. needleWords .. " ")
end

local function printMsg(text)
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(text)
    elseif type(d) == "function" then
        d("[ESO Adventurer Suite] " .. tostring(text))
    end
end

local function setButtonText(button, text)
    if button and type(button.SetText) == "function" then button:SetText(tostring(text or "")) end
end

local function makeBackdrop(parent, name, center, edge)
    local c = WM:CreateControl(name, parent, CT_BACKDROP)
    c:SetCenterColor(center[1], center[2], center[3], center[4] or 1)
    c:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
    return c
end

local function makeLabel(parent, name, text, font, color)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetText(text or "")
    l:SetFont(font or "ZoFontGame")
    color = color or {1,1,1,1}
    l:SetColor(color[1], color[2], color[3], color[4] or 1)
    return l
end

local function makeButton(parent, name, text, callback)
    local b = WM:CreateControl(name, parent, CT_BUTTON)
    b:SetFont("ZoFontGameBold")
    b:SetText(text or "")
    b:SetNormalFontColor(0.90,0.92,0.96,1)
    b:SetMouseOverFontColor(1.00,0.82,0.24,1)
    b:SetPressedFontColor(1.00,0.70,0.15,1)
    if callback then b:SetHandler("OnClicked", callback) end
    return b
end

function T:GetSV()
    if not EPC.saved then return nil end
    EPC.saved.masterAchievementTracker029713 = EPC.saved.masterAchievementTracker029713 or {}
    local s = EPC.saved.masterAchievementTracker029713
    if s.left == nil then s.left = -1 end
    if s.top == nil then s.top = -1 end
    if s.filter == nil then s.filter = "ALL" end
    if s.page == nil then s.page = 1 end
    return s
end

function T:DungeonAliases(dungeon)
    local aliases = {}
    local base = words(dungeon and dungeon.name or "")
    if base ~= "" then aliases[#aliases+1] = base end
    if base:sub(1,4) == "the " then aliases[#aliases+1] = base:sub(5) end
    return aliases
end

function T:TextMatchesDungeon(text, dungeon)
    local hay = words(text)
    if hay == "" then return false end
    for _, alias in ipairs(self:DungeonAliases(dungeon)) do
        if boundedContains(hay, alias) then return true end
    end
    return false
end

function T:LabelMatchesAnyDungeon(text)
    local hay = words(text)
    if hay == "" then return false end
    for _, dungeon in ipairs(self.dungeons or {}) do
        for _, alias in ipairs(self:DungeonAliases(dungeon)) do
            if boundedContains(hay, alias) then return true end
        end
    end
    return false
end

function T:BuildDungeonCatalog(force)
    if self.dungeons and not force then return self.dungeons end

    local byKey, list = {}, {}
    local activityTypes = {
        rawget(_G, "LFG_ACTIVITY_DUNGEON"),
        rawget(_G, "LFG_ACTIVITY_MASTER_DUNGEON"),
    }

    for _, activityType in ipairs(activityTypes) do
        if activityType ~= nil and type(GetNumActivitiesByType) == "function"
            and type(GetActivityIdByTypeAndIndex) == "function" then
            local count = tonumber(safe(GetNumActivitiesByType, 0, activityType)) or 0
            for index = 1, count do
                local activityId = tonumber(safe(GetActivityIdByTypeAndIndex, 0, activityType, index)) or 0
                if activityId > 0 then
                    local rawName, _, _, _, _, _, _, _, sortOrder = safe(GetActivityInfo, "", activityId)
                    local zoneId = tonumber(safe(GetActivityZoneId, 0, activityId)) or 0
                    local name = clean(rawName)
                    if name ~= "" and zoneId > 0 then
                        local key = "z:" .. tostring(zoneId)
                        local row = byKey[key]
                        if not row then
                            row = {
                                name = name,
                                zoneId = zoneId,
                                sortOrder = tonumber(sortOrder) or 99999,
                                normalActivityId = 0,
                                veteranActivityId = 0,
                                requiredCollectibleId = 0,
                                achievement = {},
                            }
                            byKey[key] = row
                            list[#list+1] = row
                        elseif #name < #row.name then
                            row.name = name
                        end

                        local requiredCollectible = tonumber(safe(GetRequiredActivityCollectibleId, 0, activityId)) or 0
                        if requiredCollectible > 0 then row.requiredCollectibleId = requiredCollectible end

                        if activityType == rawget(_G, "LFG_ACTIVITY_MASTER_DUNGEON") then
                            row.veteranActivityId = activityId
                        else
                            row.normalActivityId = activityId
                        end
                    end
                end
            end
        end
    end

    for _, row in ipairs(list) do
        row.isDLC = (tonumber(row.requiredCollectibleId) or 0) > 0
        if row.veteranActivityId == 0 then row.veteranActivityId = row.normalActivityId end
    end

    table.sort(list, function(a, b)
        local as, bs = tonumber(a.sortOrder) or 99999, tonumber(b.sortOrder) or 99999
        if as ~= bs then return as < bs end
        return lower(a.name) < lower(b.name)
    end)

    self.dungeons = list
    self.achievementIndex = nil
    self.achievementMappingBuilt = false
    self.travelNodeCache = nil
    return list
end

local function getAchievementText(achievementId, categoryName, subcategoryName)
    local name, description = safe(GetAchievementInfo, "", achievementId)
    name, description = clean(name), clean(description)
    local criteria = {}
    local count = tonumber(safe(GetAchievementNumCriteria, 0, achievementId)) or 0
    for i = 1, count do
        local criterion, completed, required = safe(GetAchievementCriterion, "", achievementId, i)
        criterion = clean(criterion)
        if criterion ~= "" then
            criteria[#criteria+1] = {
                text = criterion,
                completed = tonumber(completed) or 0,
                required = tonumber(required) or 0,
            }
        end
    end

    local parts = { categoryName or "", subcategoryName or "", name, description }
    for _, criterion in ipairs(criteria) do parts[#parts+1] = criterion.text end

    return {
        id = achievementId,
        name = name,
        description = description,
        category = clean(categoryName),
        subcategory = clean(subcategoryName),
        criteria = criteria,
        text = words(table.concat(parts, " ")),
        titleText = words(name),
        completed = safe(IsAchievementComplete, false, achievementId) == true,
    }
end


-- v0.29.727: deterministic core achievement IDs.
-- Runtime exact-subcategory discovery remains the fallback for newer content.
local EXPLICIT_DUNGEONS029727 = {
    {"Fungal Grotto I",1556,1561,1559,1560}, {"Fungal Grotto II",343,342,340,1563},
    {"Spindleclutch I",1565,1570,1568,1569}, {"Spindleclutch II",421,448,446,1572},
    {"The Banished Cells I",1549,1554,1552,1553}, {"The Banished Cells II",545,451,449,1564},
    {"Elden Hollow I",1573,1578,1576,1577}, {"Elden Hollow II",459,463,461,1580},
    {"Wayrest Sewers I",1589,1594,1592,1593}, {"Wayrest Sewers II",678,681,679,1596},
    {"Arx Corinium",1604,1609,1607,1608}, {"City of Ash I",1597,1602,1600,1601},
    {"City of Ash II",878,1114,1108,1107}, {"Crypt of Hearts I",1610,1615,1613,1614},
    {"Crypt of Hearts II",876,1084,941,942}, {"Direfrost Keep",1623,1628,1626,1627},
    {"Tempest Island",1617,1622,1620,1621}, {"Volenfell",1629,1634,1632,1633},
    {"Darkshade Caverns I",1581,1586,1584,1585}, {"Darkshade Caverns II",464,467,465,1588},
    {"Blackheart Haven",1647,1652,1650,1651}, {"Blessed Crucible",1641,1646,1644,1645},
    {"Selene's Web",1635,1640,1638,1639}, {"Vaults of Madness",1653,1658,1656,1657},
    {"Imperial City Prison",880,1303,1128,1129}, {"White-Gold Tower",1120,1279,1275,1276},
    {"Ruins of Mazzatun",1505,1506,1507,1508}, {"Cradle of Shadows",1523,1524,1525,1526},
    {"Falkreath Hold",1699,1704,1702,1703}, {"Bloodroot Forge",1691,1696,1694,1695},
    {"Fang Lair",1960,1965,1963,1964,2102}, {"Scalecaller Peak",1976,1981,1979,1980,1983},
    {"Moon Hunter Keep",2153,2154,2155,2156,2159}, {"March of Sacrifices",2163,2164,2165,2166,2168},
    {"Frostvault",2261,2262,2263,2264,2267}, {"Depths of Malatar",2271,2272,2273,2274,2276},
    {"Lair of Maarselok",2426,2427,2428,2429,2431}, {"Moongrave Fane",2416,2417,2418,2419,2422},
    {"Icereach",2540,2541,2542,2543,2546}, {"Unhallowed Grave",2550,2551,2552,2553,2555},
    {"Stone Garden",2695,2755,2697,2698,2701}, {"Castle Thorn",2705,2706,2707,2708,2710},
    {"Black Drake Villa",2832,2833,2834,2835,2838}, {"The Cauldron",2842,2843,2844,2845,2847},
    {"Red Petal Bastion",3017,3018,3019,3020,3023}, {"The Dread Cellar",3027,3028,3029,3030,3032},
    {"Coral Aerie",3105,3153,3107,3108,3111}, {"Shipwright's Regret",3115,3154,3117,3118,3120},
    {"Earthen Root Enclave",3376,3377,3378,3379,3381}, {"Graven Deep",3395,3396,3397,3398,3400},
    {"Bal Sunnar",3469,3470,3471,3472,3474}, {"Scrivener's Hall",3530,3531,3532,3533,3535},
    {"Oathsworn Pit",3811,3812,3813,3814,3816}, {"Bedlam Veil",3852,3853,3854,3855,3857},
    {"Exiled Redoubt",4110,4111,4112,4113,4115}, {"Lep Seclusa",4129,4130,4131,4132,4134},
    {"Naj-Caldeesh",4312,4313,4314,4315,4317}, {"Black Gem Foundry",4335,4336,4337,4338,4340},
}
local EXPLICIT_TRIALS029727 = {
    {"Aetherian Archive",1503,1137}, {"Hel Ra Citadel",1474,1136},
    {"Sanctum Ophidia",1462,1138}, {"Maw of Lorkhaj",1368,1344},
    {"Halls of Fabrication",1810,1829,nil,nil,1838}, {"Asylum Sanctorium",2077,2079,nil,nil,2087},
    {"Cloudrest",2133,2136,nil,nil,2139}, {"Sunspire",2435,2466,nil,nil,2467},
    {"Kyne's Aegis",2734,2739,nil,nil,2740}, {"Rockgrove",2987,3007,nil,nil,3003},
    {"Dreadsail Reef",3244,3252,nil,nil,3248}, {"Sanity's Edge",3560,3568,nil,nil,3564},
    {"Lucent Citadel",4015,4023,nil,nil,4019}, {"Ossein Cage",4268,4276,nil,nil,4272},
}
local EXPLICIT_ARENAS029727 = {
    {"Dragonstar Arena",1140}, {"Maelstrom Arena",1305,nil,nil,1330},
    {"Blackrose Prison",2363,2364,2366,2365,2368},
    {"Vateshran Hollows",2908,nil,2910,2909,2912},
}

local function contentKey029727(value)
    return words(value):gsub("^the%s+","")
end
local function compileExplicit029727(rows)
    local out={}
    for _,row in ipairs(rows or {}) do
        out[contentKey029727(row[1])] = {
            vetId=tonumber(row[2]), hmId=tonumber(row[3]), spId=tonumber(row[4]),
            ndId=tonumber(row[5]), triId=tonumber(row[6]),
        }
    end
    return out
end
local DUNGEON_IDS029727=compileExplicit029727(EXPLICIT_DUNGEONS029727)
local TRIAL_IDS029727=compileExplicit029727(EXPLICIT_TRIALS029727)
local ARENA_IDS029727=compileExplicit029727(EXPLICIT_ARENAS029727)

local function explicitFor029727(map,name)
    return map and map[contentKey029727(name)] or nil
end
local function recordById029727(id)
    id=tonumber(id)
    if not id or id<=0 then return nil end
    local r=getAchievementText(id,"","")
    if not r or clean(r.name)=="" then return nil end
    r.explicit029727=true
    return r
end
local function preferExactCandidates029727(candidates,contentName)
    local key=contentKey029727(contentName)
    local exact={}
    for _,r in ipairs(candidates or {}) do
        if contentKey029727(r.subcategory)==key then exact[#exact+1]=r end
    end
    return #exact>0 and exact or (candidates or {})
end
local function applyExplicitDungeonCore029727(dungeon)
    if not dungeon then return end
    local known=explicitFor029727(DUNGEON_IDS029727,dungeon.name)
    if not known then return end
    dungeon.achievement=dungeon.achievement or {}
    local ids={VET=known.vetId,HM=known.hmId,SP=known.spId,ND=known.ndId}
    for key,id in pairs(ids) do
        local r=recordById029727(id)
        if r then dungeon.achievement[key]=r end
    end
end

function T:GetRecordCompletion029727(record)
    if not record then return false end
    if record.notApplicable029727 then return false end
    if record.records029727 then
        local done=0
        for _,child in ipairs(record.records029727) do
            child.completed=safe(IsAchievementComplete,false,child.id)==true
            if child.completed then done=done+1 end
        end
        record.completedCount029727=done
        record.completed=#record.records029727>0 and done==#record.records029727
        record.name=string.format("%d/%d %s",done,#record.records029727,record.groupLabel029727 or "Achievements")
        return record.completed
    end
    if not record.id then return false end
    record.completed=safe(IsAchievementComplete,false,record.id)==true
    return record.completed
end

function T:BuildAchievementIndex(force)
    if self.achievementIndex and not force then return self.achievementIndex end
    self:BuildDungeonCatalog(false)

    local records = {}
    if type(GetNumAchievementCategories) ~= "function"
        or type(GetAchievementCategoryInfo) ~= "function"
        or type(GetAchievementId) ~= "function" then
        self.achievementIndex = records
        return records
    end

    local function addAchievement(topIndex, subIndex, achievementIndex, categoryName, subName)
        local id = tonumber(safe(GetAchievementId, 0, topIndex, subIndex, achievementIndex)) or 0
        if id <= 0 then return end
        records[#records+1] = getAchievementText(id, categoryName, subName)
    end

    local topCount = tonumber(safe(GetNumAchievementCategories, 0)) or 0
    for top = 1, topCount do
        local categoryName, numSub, numAchievements = safe(GetAchievementCategoryInfo, "", top)
        categoryName = clean(categoryName)
        numSub = tonumber(numSub) or 0
        numAchievements = tonumber(numAchievements) or 0

        local categoryWords = words(categoryName)
        local categoryRelevant = containsPlain(categoryWords, "dungeon") or self:LabelMatchesAnyDungeon(categoryName)
        if categoryRelevant then
            for i = 1, numAchievements do addAchievement(top, nil, i, categoryName, "") end
        end

        for sub = 1, numSub do
            local subName, subAchievements = safe(GetAchievementSubCategoryInfo, "", top, sub)
            subName = clean(subName)
            subAchievements = tonumber(subAchievements) or 0
            local subWords = words(subName)
            local relevant = categoryRelevant
                or containsPlain(subWords, "dungeon")
                or self:LabelMatchesAnyDungeon(subName)
            if relevant then
                for i = 1, subAchievements do addAchievement(top, sub, i, categoryName, subName) end
            end
        end
    end

    self.achievementIndex = records
    return records
end

local function signalCount(text)
    local c = 0
    if containsPlain(text, "hard mode") or containsPlain(text, "hardmode") or containsPlain(text, "challenge banner") then c = c + 1 end
    if containsPlain(text, "speed run") or (containsPlain(text, "within") and containsPlain(text, "minute")) then c = c + 1 end
    if containsPlain(text, "no death") or containsPlain(text, "without dying") or containsPlain(text, "group member death") or containsPlain(text, "without suffering") then c = c + 1 end
    return c
end

function T:ScoreAchievement(record, key)
    local text = record.text or ""
    local title = record.titleText or ""
    local score = 0
    local signals = signalCount(text)
    local isMeta = containsPlain(title, "challenger") or containsPlain(title, "conqueror of")
    if signals >= 2 and containsPlain(text, "complete") then isMeta = true end

    if key == "SP" then
        if containsPlain(text, "speed run") then score = score + 150 end
        if containsPlain(title, "speed") then score = score + 120 end
        if containsPlain(text, "within") and containsPlain(text, "minute") then score = score + 110 end
        if containsPlain(text, "time limit") then score = score + 55 end
        if containsPlain(text, "timer") then score = score + 35 end
        if isMeta then score = score - 150 end
    elseif key == "ND" then
        if containsPlain(text, "no death") then score = score + 160 end
        if containsPlain(title, "no death") then score = score + 160 end
        if containsPlain(text, "without dying") then score = score + 150 end
        if containsPlain(text, "without suffering") then score = score + 115 end
        if containsPlain(text, "group member death") then score = score + 130 end
        if containsPlain(text, "without any group member") then score = score + 110 end
        if containsPlain(text, "without a group member") then score = score + 110 end
        if containsPlain(text, "no group member dies") then score = score + 140 end
        if isMeta then score = score - 150 end
    elseif key == "HM" then
        if containsPlain(text, "hard mode") or containsPlain(text, "hardmode") then score = score + 180 end
        if containsPlain(text, "challenge banner") then score = score + 145 end
        if containsPlain(text, "scroll of glorious battle") then score = score + 145 end
        if containsPlain(text, "scroll of glorious") then score = score + 120 end
        if containsPlain(text, "after activating") and containsPlain(text, "banner") then score = score + 110 end
        if containsPlain(text, "veteran") then score = score + 20 end
        if containsPlain(text, "within") and containsPlain(text, "minute") then score = score - 100 end
        if containsPlain(text, "without dying") or containsPlain(text, "no death") or containsPlain(text, "group member death") then score = score - 100 end
        if isMeta then score = score - 160 end
    elseif key == "VET" then
        if title:sub(1,8) == "veteran " then score = score + 180 end
        if containsPlain(text, "veteran difficulty") then score = score + 95 end
        if containsPlain(text, "veteran") then score = score + 55 end
        if containsPlain(title, "veteran") then score = score + 45 end
        if containsPlain(title, "conqueror") then score = score + 30 end
        if containsPlain(text, "hard mode") or containsPlain(text, "challenge banner") or containsPlain(text, "scroll of glorious") then score = score - 90 end
        if containsPlain(text, "within") and containsPlain(text, "minute") then score = score - 100 end
        if containsPlain(text, "without dying") or containsPlain(text, "no death") or containsPlain(text, "group member death") then score = score - 100 end
        if isMeta then score = score - 90 end
    end

    return score
end

function T:MapAchievements(force)
    if self.achievementMappingBuilt and not force then return end
    self:BuildDungeonCatalog(false)
    local records = self:BuildAchievementIndex(force)

    for _, dungeon in ipairs(self.dungeons or {}) do
        dungeon.achievement = {}
        local candidates = {}
        for _, record in ipairs(records) do
            if self:TextMatchesDungeon(record.text, dungeon)
                or self:TextMatchesDungeon(record.subcategory, dungeon)
                or self:TextMatchesDungeon(record.category, dungeon) then
                candidates[#candidates+1] = record
            end
        end

        for _, key in ipairs(STATUS_KEYS) do
            local best, bestScore = nil, -99999
            for _, record in ipairs(candidates) do
                local score = self:ScoreAchievement(record, key)
                if score > bestScore then best, bestScore = record, score end
            end

            local threshold = key == "VET" and 35 or 50
            if best and bestScore >= threshold then
                dungeon.achievement[key] = {
                    id = best.id,
                    name = best.name,
                    description = best.description,
                    category = best.category,
                    subcategory = best.subcategory,
                    criteria = best.criteria,
                    completed = safe(IsAchievementComplete, false, best.id) == true,
                    score = bestScore,
                }
            end
        end
    end

    self.achievementMappingBuilt = true
end

function T:RefreshCompletionState()
    -- Never build the full map from an event/refresh callback. v0.29.715
    -- spreads that work across frames so opening the menu cannot stall ESO.
    if not self.achievementMappingBuilt then return end
    for _, dungeon in ipairs(self.dungeons or {}) do
        for _, key in ipairs(STATUS_KEYS) do
            local a = dungeon.achievement and dungeon.achievement[key]
            if a and a.id then a.completed = safe(IsAchievementComplete, false, a.id) == true end
        end
    end
end

function T:GetMissing(dungeon)
    local out = {}
    for _, key in ipairs(STATUS_KEYS) do
        local a = dungeon.achievement and dungeon.achievement[key]
        if a and not a.completed then out[#out+1] = STATUS_LONG[key] end
    end
    return out
end

function T:IsDungeonComplete(dungeon)
    local mapped = 0
    for _, key in ipairs(STATUS_KEYS) do
        local a = dungeon.achievement and dungeon.achievement[key]
        if a then
            mapped = mapped + 1
            if not a.completed then return false end
        end
    end
    return mapped > 0
end

function T:GetFilteredDungeons()
    local s = self:GetSV()
    local filter = s and tostring(s.filter or "ALL") or "ALL"
    local out = {}
    for _, dungeon in ipairs(self.dungeons or {}) do
        local include = filter == "ALL"
            or (filter == "INCOMPLETE" and not self:IsDungeonComplete(dungeon))
            or (filter == "BASE" and not dungeon.isDLC)
            or (filter == "DLC" and dungeon.isDLC)
        if include then out[#out+1] = dungeon end
    end
    return out
end

function T:CreateDetailPopup029725()
    if self.detailPopup029725 then return self.detailPopup029725 end

    local popup = WM:CreateTopLevelWindow("EAS_MasterAchievementTrackerDetails029725")
    popup:SetDimensions(860, 420)
    popup:SetClampedToScreen(true)
    popup:SetMouseEnabled(false)
    popup:SetHidden(true)
    popup:SetDrawLayer(DL_OVERLAY)
    if popup.SetDrawTier and DT_HIGH then popup:SetDrawTier(DT_HIGH) end
    if popup.SetTopLevel then popup:SetTopLevel(true) end
    if popup.SetDrawLevel then
        local menuLevel = tonumber(rawget(_G, "ZO_HIGH_TIER_KEYBOARD_COMBO_BOX_DROPDOWN")) or 140
        popup:SetDrawLevel(menuLevel + 3200)
    end

    local bg = makeBackdrop(popup, nil, {0.008,0.012,0.020,0.995}, {0.82,0.66,0.22,1})
    bg:SetAnchorFill(popup)
    bg:SetMouseEnabled(false)

    local context = makeLabel(popup, nil, "", "ZoFontGameBold", {1,0.82,0.24,1})
    context:SetAnchor(TOPLEFT, popup, TOPLEFT, 18, 14)
    context:SetDimensions(690, 24)

    local status = makeLabel(popup, nil, "", "ZoFontGameBold", {1,1,1,1})
    status:SetAnchor(TOPRIGHT, popup, TOPRIGHT, -18, 14)
    status:SetDimensions(130, 24)
    status:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local title = makeLabel(popup, nil, "", "ZoFontWinH3", {0.96,0.97,1,1})
    title:SetAnchor(TOPLEFT, context, BOTTOMLEFT, 0, 4)
    title:SetDimensions(820, 34)

    local divider = WM:CreateControl(nil, popup, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 3)
    divider:SetDimensions(820, 1)
    divider:SetCenterColor(0.28,0.31,0.38,0.9)
    divider:SetEdgeColor(0,0,0,0)

    local body = makeLabel(popup, nil, "", "ZoFontGame", {0.88,0.90,0.94,1})
    body:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 10)
    body:SetDimensions(820, 240)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local hint = makeLabel(popup, nil, "", "ZoFontGameSmall", {0.62,0.66,0.74,1})
    hint:SetAnchor(BOTTOMLEFT, popup, BOTTOMLEFT, 18, -12)
    hint:SetDimensions(820, 22)

    local groupLeft = WM:CreateControl(nil, popup, CT_CONTROL)
    groupLeft:SetDimensions(392, 420)
    groupLeft:SetHidden(true)

    local groupRight = WM:CreateControl(nil, popup, CT_CONTROL)
    groupRight:SetDimensions(392, 420)
    groupRight:SetHidden(true)

    local function createExtraRow029730(parent)
        local row = WM:CreateControl(nil, parent, CT_CONTROL)
        row:SetDimensions(392, 44)

        local check = WM:CreateControl(nil, row, CT_TEXTURE)
        check:SetTexture("EsoUI/Art/Miscellaneous/check_icon_32.dds")
        check:SetDimensions(16,16)
        check:SetAnchor(TOPLEFT,row,TOPLEFT,2,6)
        check:SetColor(0.28,0.95,0.35,1)
        check:SetHidden(true)

        local box = WM:CreateControl(nil, row, CT_BACKDROP)
        box:SetDimensions(14,14)
        box:SetAnchor(TOPLEFT,row,TOPLEFT,3,7)
        box:SetCenterColor(0,0,0,0)
        box:SetEdgeColor(0.78,0.48,0.16,0.92)
        box:SetEdgeTexture(nil,1,1,1)
        box:SetHidden(true)

        local label = makeLabel(row,nil,"","ZoFontGame",{0.88,0.90,0.94,1})
        label:SetAnchor(TOPLEFT,row,TOPLEFT,24,0)
        label:SetDimensions(360,44)
        label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        if label.SetMaxLineCount then pcall(label.SetMaxLineCount,label,2) end
        if label.SetWrapMode and rawget(_G,"TEXT_WRAP_MODE_ELLIPSIS") ~= nil then
            pcall(label.SetWrapMode,label,TEXT_WRAP_MODE_ELLIPSIS)
        end

        row.check029730 = check
        row.box029730 = box
        row.label029730 = label
        return row
    end

    local leftRows,rightRows = {},{}
    for i=1,20 do
        local l=createExtraRow029730(groupLeft)
        l:SetAnchor(TOPLEFT,groupLeft,TOPLEFT,0,(i-1)*44)
        l:SetHidden(true)
        leftRows[i]=l

        local r=createExtraRow029730(groupRight)
        r:SetAnchor(TOPLEFT,groupRight,TOPLEFT,0,(i-1)*44)
        r:SetHidden(true)
        rightRows[i]=r
    end

    self.detailPopup029725 = popup
    self.detailContext029725 = context
    self.detailStatus029725 = status
    self.detailTitle029725 = title
    self.detailBody029725 = body
    self.detailHint029725 = hint
    self.detailGroupLeft029729 = groupLeft
    self.detailGroupRight029729 = groupRight
    self.detailExtraLeftRows029730 = leftRows
    self.detailExtraRightRows029730 = rightRows
    return popup
end

function T:HideDetailPopup029725()
    if self.detailPopup029725 then self.detailPopup029725:SetHidden(true) end
end

function T:ShowDetailPopup029725(owner, record, contextText, missingText, hintText)
    if not owner then return end
    local popup = self:CreateDetailPopup029725()
    local context = clean(contextText or "Achievement")
    local name = record and clean(record.name) or "N/A"
    local description = record and clean(record.description) or clean(missingText or "No applicable achievement exists for this slot.")

    local bodyLines = {}
    local isGroup = record and record.records029727 ~= nil
    local leftRecords, rightRecords = {}, {}

    if description ~= "" then bodyLines[#bodyLines + 1] = description end

    if isGroup then
        T:GetRecordCompletion029727(record)
        local total = #record.records029727
        local split = math.ceil(total / 2)
        for index,child in ipairs(record.records029727) do
            if index <= split then
                leftRecords[#leftRecords + 1] = child
            else
                rightRecords[#rightRecords + 1] = child
            end
        end
    elseif record then
        for _, criterion in ipairs(record.criteria or {}) do
            local progress = ""
            if (tonumber(criterion.required) or 0) > 1 then
                progress = string.format("  %d/%d", tonumber(criterion.completed) or 0, tonumber(criterion.required) or 0)
            end
            local criterionText = clean(criterion.text)
            if criterionText ~= "" then bodyLines[#bodyLines + 1] = "• " .. criterionText .. progress end
        end
    end
    if #bodyLines == 0 then bodyLines[1] = "No additional description is exposed by ESO for this achievement." end

    local complete = record and T:GetRecordCompletion029727(record) == true
    if record and record.id then record.completed = complete end
    if record and record.records029727 then name=clean(record.name) end

    self.detailContext029725:SetText(context)
    self.detailTitle029725:SetText(name)

    self.detailBody029725:SetHidden(false)
    self.detailGroupLeft029729:SetHidden(true)
    self.detailGroupRight029729:SetHidden(true)

    local function clearExtraRows029730(rows)
        for _,row in ipairs(rows or {}) do
            row:SetHidden(true)
            row.check029730:SetHidden(true)
            row.box029730:SetHidden(true)
            row.label029730:SetText("")
        end
    end
    clearExtraRows029730(self.detailExtraLeftRows029730)
    clearExtraRows029730(self.detailExtraRightRows029730)

    local function fillExtraRows029730(rows, records)
        for i,child in ipairs(records or {}) do
            local row=rows and rows[i]
            if row then
                local done=safe(IsAchievementComplete,false,child.id)==true
                row.check029730:SetHidden(not done)
                row.box029730:SetHidden(done)
                row.label029730:SetText(clean(child.name))
                row:SetHidden(false)
            end
        end
    end

    if isGroup then
        self.detailBody029725:SetText(table.concat(bodyLines, "\n\n"))
        fillExtraRows029730(self.detailExtraLeftRows029730,leftRecords)
        fillExtraRows029730(self.detailExtraRightRows029730,rightRecords)
        self.detailGroupLeft029729:SetHidden(false)
        self.detailGroupRight029729:SetHidden(false)
    else
        self.detailBody029725:SetText(table.concat(bodyLines, "\n\n"))
    end

    self.detailStatus029725:SetText(
        record and (record.notApplicable029727 and "N/A" or (complete and "COMPLETE" or "MISSING")) or "N/A"
    )
    if record and record.notApplicable029727 then
        self.detailStatus029725:SetColor(0.62,0.65,0.72,1)
    elseif record and complete then
        self.detailStatus029725:SetColor(0.30,0.95,0.40,1)
    elseif record then
        self.detailStatus029725:SetColor(1.00,0.52,0.28,1)
    else
        self.detailStatus029725:SetColor(0.65,0.68,0.74,1)
    end
    if record and record.notApplicable029727 then
        self.detailHint029725:SetText("")
    else
        self.detailHint029725:SetText(hintText or (record and "Click the achievement cell to link it in chat." or ""))
    end

    local rootH = (GuiRoot and GuiRoot.GetHeight and tonumber(GuiRoot:GetHeight())) or 1080
    local maxPopupH = math.max(520, rootH - 80)
    local bodyH = 120

    if isGroup then
        local descriptionH = 42
        if self.detailBody029725.GetTextHeight then
            local ok,value = pcall(self.detailBody029725.GetTextHeight,self.detailBody029725)
            if ok and tonumber(value) then descriptionH = math.max(28, math.min(90, tonumber(value) + 8)) end
        end
        self.detailBody029725:SetHeight(descriptionH)

        self.detailGroupLeft029729:ClearAnchors()
        self.detailGroupRight029729:ClearAnchors()
        self.detailGroupLeft029729:SetAnchor(TOPLEFT,self.detailBody029725,BOTTOMLEFT,0,12)
        self.detailGroupRight029729:SetAnchor(TOPLEFT,self.detailBody029725,BOTTOMLEFT,414,12)

        local rowsNeeded = math.max(#leftRecords,#rightRecords,1)
        local groupH = rowsNeeded * 44
        local availableGroupH = math.max(220, maxPopupH - 148 - descriptionH)
        groupH = math.min(groupH,availableGroupH)
        self.detailGroupLeft029729:SetHeight(groupH)
        self.detailGroupRight029729:SetHeight(groupH)
        popup:SetHeight(math.min(maxPopupH,148 + descriptionH + groupH))
    else
        local maxBodyH = math.max(280, maxPopupH - 122)
        if self.detailBody029725.GetTextHeight then
            local ok,value = pcall(self.detailBody029725.GetTextHeight,self.detailBody029725)
            if ok and tonumber(value) then bodyH = math.max(100, math.min(maxBodyH, tonumber(value) + 12)) end
        end
        self.detailBody029725:SetHeight(bodyH)
        popup:SetHeight(math.max(245, math.min(maxPopupH, 122 + bodyH)))
    end

    -- Keep vertical geometry stable, but put the details card on the opposite
    -- side of the screen from the hovered cell so the row being inspected stays visible.
    popup:ClearAnchors()
    local rootW=(GuiRoot and GuiRoot.GetWidth and tonumber(GuiRoot:GetWidth())) or 1920
    local ownerLeft=(owner.GetLeft and tonumber(owner:GetLeft())) or 0
    local ownerRight=(owner.GetRight and tonumber(owner:GetRight())) or ownerLeft
    local ownerMid=(ownerLeft+ownerRight)*0.5
    if ownerMid >= rootW*0.5 then
        popup:SetAnchor(LEFT,GuiRoot,LEFT,28,0)
    else
        popup:SetAnchor(RIGHT,GuiRoot,RIGHT,-28,0)
    end

    popup:SetHidden(false)
    if popup.BringWindowToTop then popup:BringWindowToTop() end
end

function T:ShowAchievementTooltip(owner, dungeon, key)
    if not owner or not dungeon then return end
    local a = dungeon.achievement and dungeon.achievement[key]
    self:ShowDetailPopup029725(
        owner,
        a,
        dungeon.name .. " — " .. STATUS_LONG[key],
        "No separate ESO achievement applies to this slot.",
        a and "Left-click: link achievement in chat. Right-click: create a Group Finder listing." or ""
    )
end

function T:LinkAchievement(dungeon, key)
    local a = dungeon and dungeon.achievement and dungeon.achievement[key]
    if not a or not a.id then
        printMsg("No matched ESO achievement is available for " .. STATUS_LONG[key] .. " in " .. tostring(dungeon and dungeon.name or "this dungeon") .. ".")
        return false
    end

    local link = nil
    if type(ZO_LinkHandler_CreateLink) == "function" then
        local ok, value = pcall(ZO_LinkHandler_CreateLink, a.name or STATUS_LONG[key], "FFFFFF", rawget(_G,"ACHIEVEMENT_LINK_TYPE") or "achievement", a.id)
        if ok then link = value end
    end
    if link and link ~= "" and type(StartChatInput) == "function" then
        StartChatInput(link)
        return true
    end

    printMsg((a.name or STATUS_LONG[key]) .. " — Achievement ID " .. tostring(a.id))
    return false
end

function T:BuildTravelNodeCache(force)
    if self.travelNodeCache and not force then return self.travelNodeCache end
    local nodes = {}
    if type(GetNumFastTravelNodes) ~= "function" or type(GetFastTravelNodeInfo) ~= "function" then
        self.travelNodeCache = nodes
        return nodes
    end

    local count = tonumber(safe(GetNumFastTravelNodes, 0)) or 0
    for nodeIndex = 1, count do
        local known, name, x, y, _, _, poiType, _, linkedCollectibleLocked = safe(GetFastTravelNodeInfo, false, nodeIndex)
        name = clean(name)
        if known == true and name ~= "" and linkedCollectibleLocked ~= true then
            local zoneId = 0
            if type(GetFastTravelNodePOIIndicies) == "function" and type(GetZoneId) == "function" then
                local zoneIndex = tonumber(safe(GetFastTravelNodePOIIndicies, 0, nodeIndex)) or 0
                if zoneIndex > 0 then zoneId = tonumber(safe(GetZoneId, 0, zoneIndex)) or 0 end
            end
            nodes[#nodes+1] = {
                nodeIndex=nodeIndex, name=name, zoneId=zoneId,
                normalizedX=tonumber(x), normalizedY=tonumber(y), poiType=poiType,
            }
        end
    end
    self.travelNodeCache = nodes
    return nodes
end

function T:FindDungeonTravelNode(dungeon)
    local best, bestScore = nil, -1
    local targetWords, targetCompact = words(dungeon.name), compact(dungeon.name)
    for _, node in ipairs(self:BuildTravelNodeCache(false)) do
        local nodeWords, nodeCompact = words(node.name), compact(node.name)
        local score = 0
        if node.zoneId > 0 and node.zoneId == dungeon.zoneId then score = score + 100 end
        if nodeCompact == targetCompact then score = score + 160
        elseif boundedContains(nodeWords, targetWords) or boundedContains(targetWords, nodeWords) then score = score + 100
        elseif containsPlain(nodeCompact, targetCompact) or containsPlain(targetCompact, nodeCompact) then score = score + 65 end
        if score > bestScore then best, bestScore = node, score end
    end
    if bestScore >= 90 then return best end
    return nil
end

function T:TeleportToDungeon(dungeon)
    if not dungeon then return false end
    local node = self:FindDungeonTravelNode(dungeon)
    if not node then
        self:BuildTravelNodeCache(true)
        node = self:FindDungeonTravelNode(dungeon)
    end
    if not node then
        printMsg("No discovered fast-travel node was found for " .. dungeon.name .. ". Open its map/wayshrine once or use Dungeon Finder.")
        return false
    end

    if EPC.Travel and type(EPC.Travel.TravelMapTeleporterEntry) == "function" then
        return EPC.Travel:TravelMapTeleporterEntry({
            kind="INSTANCE",
            nodeIndex=node.nodeIndex,
            name=dungeon.name,
            zoneName=dungeon.name,
            zoneId=dungeon.zoneId,
            instanceCategory="DUNGEON",
            normalizedX=node.normalizedX,
            normalizedY=node.normalizedY,
            canTravel=true,
        })
    end

    if type(FastTravelToNode) == "function" then
        printMsg("Traveling to " .. dungeon.name .. ".")
        local ok = pcall(FastTravelToNode, node.nodeIndex)
        return ok
    end
    return false
end

function T:FindGroupFinderOptionIndex(userType, dungeon)
    local count = tonumber(safe(GetGroupFinderUserTypeGroupListingNumSecondaryOptions, 0, userType)) or 0
    local target = words(dungeon.name)
    local targetCompact = compact(dungeon.name)
    local best, bestScore = nil, -1
    for i = 1, count do
        local optionName = safe(GetGroupFinderUserTypeGroupListingSecondaryOptionByIndex, "", userType, i)
        optionName = clean(optionName)
        local ow, oc = words(optionName), compact(optionName)
        local score = 0
        if oc == targetCompact then score = 200
        elseif boundedContains(ow, target) or boundedContains(target, ow) then score = 140
        elseif containsPlain(oc, targetCompact) or containsPlain(targetCompact, oc) then score = 80 end
        if score > bestScore then best, bestScore = i, score end
    end
    if bestScore >= 80 then return best end
    return nil
end

function T:FindVeteranPrimaryIndex(userType)
    local count = tonumber(safe(GetGroupFinderUserTypeGroupListingNumPrimaryOptions, 0, userType)) or 0
    for i = 1, count do
        local optionName = lower(safe(GetGroupFinderUserTypeGroupListingPrimaryOptionByIndex, "", userType, i))
        if containsPlain(optionName, "veteran") then return i end
    end
    if DUNGEON_DIFFICULTY_VETERAN ~= nil then
        local n = tonumber(DUNGEON_DIFFICULTY_VETERAN)
        if n and n >= 1 and n <= count then return n end
    end
    return count >= 2 and 2 or (count >= 1 and 1 or nil)
end

function T:CreateGroupFinder(dungeon, focusKey)
    if not dungeon then return false end
    local createdType = rawget(_G, "GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING")
    if createdType ~= nil and safe(HasGroupListingForUserType, false, createdType) == true then
        printMsg("You already have an active Group Finder listing.")
        return false
    end

    if type(GetGroupFinderStatusReason) == "function" then
        local reason = safe(GetGroupFinderStatusReason, rawget(_G,"GROUP_FINDER_ACTION_RESULT_SUCCESS"))
        local success = rawget(_G, "GROUP_FINDER_ACTION_RESULT_SUCCESS")
        local accountBlock = rawget(_G, "GROUP_FINDER_ACTION_RESULT_FAILED_ACCOUNT_TYPE_BLOCKS_CREATION")
        if success ~= nil and reason ~= success and reason ~= accountBlock then
            local text = type(GetString) == "function" and clean(safe(GetString, "", "SI_GROUPFINDERACTIONRESULT", reason)) or ""
            printMsg(text ~= "" and text or "Group Finder is currently unavailable.")
            return false
        end
    end

    local userType = rawget(_G, "GROUP_FINDER_GROUP_LISTING_USER_TYPE_GROUP_LISTING_DRAFT")
    local category = rawget(_G, "GROUP_FINDER_CATEGORY_DUNGEON")
    if userType == nil or category == nil then
        printMsg("ESO's Group Finder draft API is unavailable.")
        return false
    end

    if type(SetGroupFinderUserTypeGroupListingCategory) ~= "function"
        or type(UpdateGroupFinderUserTypeGroupListingOptions) ~= "function"
        or type(RequestCreateGroupListing) ~= "function" then
        printMsg("ESO's Group Finder creation API is unavailable.")
        return false
    end

    pcall(SetGroupFinderUserTypeGroupListingCategory, userType, category)
    pcall(UpdateGroupFinderUserTypeGroupListingOptions, userType)

    local primaryIndex = self:FindVeteranPrimaryIndex(userType)
    if primaryIndex and type(SetGroupFinderUserTypeGroupListingPrimaryOption) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingPrimaryOption, userType, primaryIndex)
        if type(SetVeteranDifficulty) == "function" then pcall(SetVeteranDifficulty, true) end
        pcall(UpdateGroupFinderUserTypeGroupListingOptions, userType)
    end

    if type(SetGroupFinderUserTypeGroupListingSecondaryOptionDefault) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingSecondaryOptionDefault, userType)
    end
    local secondaryIndex = self:FindGroupFinderOptionIndex(userType, dungeon)
    if not secondaryIndex then
        printMsg("ESO did not expose a matching Group Finder dungeon option for " .. dungeon.name .. ".")
        return false
    end
    if type(SetGroupFinderUserTypeGroupListingSecondaryOption) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingSecondaryOption, userType, secondaryIndex)
    end

    local missing = self:GetMissing(dungeon)
    local description
    if focusKey and STATUS_LONG[focusKey] then
        description = STATUS_LONG[focusKey] .. " achievement run — " .. dungeon.name
    else
        description = #missing > 0
            and ("Achievement run — need: " .. table.concat(missing, " / "))
            or "Achievement run — helping with Veteran dungeon achievements."
    end

    if type(SetGroupFinderUserTypeGroupListingTitle) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingTitle, userType, dungeon.name)
    end
    if type(SetGroupFinderUserTypeGroupListingDescription) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingDescription, userType, description)
    end
    if type(SetGroupFinderUserTypeGroupListingGroupSize) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingGroupSize, userType, 4)
    end
    if type(SetGroupFinderUserTypeGroupListingAutoAcceptRequests) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingAutoAcceptRequests, userType, true)
    end
    if type(SetGroupFinderUserTypeGroupListingEnforceRoles) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingEnforceRoles, userType, false)
    end
    if type(SetGroupFinderUserTypeGroupListingRequiresChampion) == "function" then
        pcall(SetGroupFinderUserTypeGroupListingRequiresChampion, userType, false)
    end

    local ok = pcall(RequestCreateGroupListing)
    if ok then
        printMsg("Creating Veteran Group Finder listing for " .. dungeon.name .. ".")
        return true
    end
    printMsg("ESO rejected the Group Finder creation request for " .. dungeon.name .. ".")
    return false
end

function T:ShowDungeonContextMenu(dungeon, owner)
    if not dungeon or type(ClearMenu) ~= "function" or type(AddMenuItem) ~= "function" or type(ShowMenu) ~= "function" then return end
    ClearMenu()
    AddMenuItem("Teleport to " .. dungeon.name, function() T:TeleportToDungeon(dungeon) end)
    AddMenuItem("Create Veteran Group Finder Listing", function() T:CreateGroupFinder(dungeon, nil) end)
    for _, key in ipairs(STATUS_KEYS) do
        local a = dungeon.achievement and dungeon.achievement[key]
        if a then
            AddMenuItem("Link " .. STATUS_LONG[key] .. ": " .. clean(a.name), function() T:LinkAchievement(dungeon, key) end)
        end
    end
    ShowMenu(owner)

    -- ShowMenu already raises ZO_Menus, but explicitly bring the native menu
    -- owner window forward after the Suite menu is populated. This is additive
    -- and does not replace or reparent ESO's context menu.
    local menus = rawget(_G, "ZO_Menus")
    if menus and type(menus.BringWindowToTop) == "function" then
        pcall(menus.BringWindowToTop, menus)
    end
end

local CreateWindowImplArch

function T:CreateWindow(...)

    return CreateWindowImplArch(self, ...)

end

CreateWindowImplArch = function(self)
    if self.window then return self.window end
    local s = self:GetSV()

    local w = WM:CreateTopLevelWindow("EAS_MasterAchievementTracker029713")
    w:SetDimensions(WINDOW_W, WINDOW_H)
    w:SetClampedToScreen(true)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetDrawLayer(DL_OVERLAY)
    if w.SetDrawTier and DT_HIGH then w:SetDrawTier(DT_HIGH) end
    -- ESO keyboard context menus live on HIGH tier at
    -- ZO_HIGH_TIER_KEYBOARD_COMBO_BOX_DROPDOWN. Keep this window immediately
    -- below that native menu layer so ShowMenu() can never render behind it.
    local nativeMenuLevel = tonumber(rawget(_G, "ZO_HIGH_TIER_KEYBOARD_COMBO_BOX_DROPDOWN")) or 140
    w:SetDrawLevel(math.max(1, nativeMenuLevel - 1))
    w:SetHidden(true)

    if s and tonumber(s.left) and tonumber(s.left) >= 0 and tonumber(s.top) and tonumber(s.top) >= 0 then
        w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tonumber(s.left), tonumber(s.top))
    else
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    w:SetHandler("OnMoveStop", function(control)
        local sv = T:GetSV()
        if sv then sv.left, sv.top = control:GetLeft(), control:GetTop() end
    end)

    local bg = makeBackdrop(w, "EAS_MasterAchievementTrackerBG029713", {0.012,0.017,0.026,0.985}, {0.64,0.47,0.12,0.95})
    bg:SetAnchorFill(w)
    bg:SetMouseEnabled(false)

    local header = makeBackdrop(w, "EAS_MasterAchievementTrackerHeader029713", {0.018,0.025,0.038,0.99}, {0,0,0,0})
    header:SetAnchor(TOPLEFT, w, TOPLEFT, 2, 2)
    header:SetAnchor(TOPRIGHT, w, TOPRIGHT, -2, 2)
    header:SetHeight(72)
    header:SetMouseEnabled(true)
    header:SetHandler("OnMouseDown", function(_, button) if button == MOUSE_BUTTON_INDEX_LEFT then w:StartMoving() end end)
    header:SetHandler("OnMouseUp", function(_, button) if button == MOUSE_BUTTON_INDEX_LEFT then w:StopMovingOrResizing() end end)

    local title = makeLabel(header, "EAS_MasterAchievementTrackerTitle029713", "MASTER DUNGEON ACHIEVEMENT TRACKER", "ZoFontWinH1", {1,0.82,0.24,1})
    title:SetAnchor(TOPLEFT, header, TOPLEFT, 20, 9)
    title:SetDimensions(760, 34)

    local sub = makeLabel(header, "EAS_MasterAchievementTrackerSub029713", "Every ESO dungeon • Veteran • Hard Mode • Speed Run • No Death", "ZoFontGame", {0.72,0.76,0.84,1})
    sub:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, -1)
    sub:SetDimensions(900, 24)

    local close = makeButton(header, "EAS_MasterAchievementTrackerClose029713", "X", function() T:Hide() end)
    close:SetDimensions(44,44)
    close:SetAnchor(TOPRIGHT, header, TOPRIGHT, -12, 13)
    close:SetFont("ZoFontWinH2")
    self.close = close

    local toolbar = WM:CreateControl("EAS_MasterAchievementTrackerToolbar029713", w, CT_CONTROL)
    toolbar:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 16, 10)
    toolbar:SetAnchor(TOPRIGHT, header, BOTTOMRIGHT, -16, 10)
    toolbar:SetHeight(42)

    self.filterButtons = {}
    for i, key in ipairs(FILTERS) do
        local button = makeButton(toolbar, "EAS_MasterAchievementTrackerFilter029713_"..key, FILTER_LABELS[key], function()
            local sv = T:GetSV()
            if sv then sv.filter, sv.page = key, 1 end
            T:Refresh()
        end)
        button:SetDimensions(150,34)
        if i == 1 then button:SetAnchor(LEFT, toolbar, LEFT, 0, 0)
        else button:SetAnchor(LEFT, self.filterButtons[i-1], RIGHT, 8, 0) end
        self.filterButtons[i] = button
    end

    local refresh = makeButton(toolbar, "EAS_MasterAchievementTrackerRefresh029713", "REFRESH", function()
        T:StartDeferredBuild029715(true)
        T:Render029715()
    end)
    refresh:SetDimensions(120,34)
    refresh:SetAnchor(RIGHT, toolbar, RIGHT, 0, 0)
    self.refreshButton = refresh

    local head = makeBackdrop(w, "EAS_MasterAchievementTrackerTableHead029713", {0.030,0.040,0.056,0.98}, {0.18,0.22,0.30,0.8})
    head:SetAnchor(TOPLEFT, toolbar, BOTTOMLEFT, 0, 6)
    head:SetAnchor(TOPRIGHT, toolbar, BOTTOMRIGHT, 0, 6)
    head:SetHeight(34)

    local function hlabel(text, x, width, align)
        local l = makeLabel(head, nil, text, "ZoFontGameBold", {0.85,0.88,0.94,1})
        l:SetAnchor(LEFT, head, LEFT, x, 0)
        l:SetDimensions(width, 30)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if align then l:SetHorizontalAlignment(align) end
        return l
    end
    hlabel("DUNGEON", 12, 520, TEXT_ALIGN_LEFT)
    hlabel("VET", 540, 56, TEXT_ALIGN_CENTER)
    hlabel("HM", 602, 56, TEXT_ALIGN_CENTER)
    hlabel("SP", 664, 56, TEXT_ALIGN_CENTER)
    hlabel("ND", 726, 56, TEXT_ALIGN_CENTER)
    hlabel("TRAVEL", 802, 130, TEXT_ALIGN_CENTER)
    hlabel("GROUP FINDER", 946, 194, TEXT_ALIGN_CENTER)

    self.rows = {}
    for i = 1, ROW_COUNT do
        local row = WM:CreateControl("EAS_MasterAchievementTrackerRow029713_"..i, w, CT_CONTROL)
        row:SetAnchor(TOPLEFT, head, BOTTOMLEFT, 0, 4 + ((i-1)*38))
        row:SetAnchor(TOPRIGHT, head, BOTTOMRIGHT, 0, 4 + ((i-1)*38))
        row:SetHeight(34)
        row:SetMouseEnabled(true)

        local rowBg = makeBackdrop(row, nil, (i%2==0) and {0.022,0.029,0.041,0.94} or {0.017,0.024,0.035,0.94}, {0.12,0.15,0.20,0.55})
        rowBg:SetAnchorFill(row)
        rowBg:SetMouseEnabled(false)

        local dungeonButton = makeButton(row, nil, "", function(control)
            if control.dungeon then T:ShowDungeonContextMenu(control.dungeon, control) end
        end)
        dungeonButton:SetAnchor(LEFT, row, LEFT, 10, 0)
        dungeonButton:SetDimensions(520, 32)
        dungeonButton:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        dungeonButton:SetNormalFontColor(0.62,0.72,1.00,1)
        dungeonButton:SetMouseOverFontColor(1.00,0.84,0.28,1)

        local statuses = {}
        local xs = {540,602,664,726}
        for kIndex, key in ipairs(STATUS_KEYS) do
            local statusButton = makeButton(row, nil, "—", function(control)
                if control.dungeon then T:LinkAchievement(control.dungeon, control.statusKey) end
            end)
            statusButton.statusKey = key
            statusButton:SetAnchor(LEFT, row, LEFT, xs[kIndex], 0)
            statusButton:SetDimensions(56,32)
            statusButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

            -- The keyboard font used by this compact button does not reliably
            -- contain the Unicode ✓ glyph on every client/font build. ESO then
            -- renders a green rectangle/tofu box. Use ESO's native check texture
            -- instead so a completed achievement is always an actual checkmark.
            local completedCheck = WM:CreateControl(nil, statusButton, CT_TEXTURE)
            completedCheck:SetTexture("EsoUI/Art/Miscellaneous/check_icon_32.dds")
            completedCheck:SetDimensions(18, 18)
            completedCheck:SetAnchor(CENTER, statusButton, CENTER, 0, 0)
            completedCheck:SetColor(0.28, 0.95, 0.35, 1)
            completedCheck:SetHidden(true)
            statusButton._easCompletedCheck029721 = completedCheck

            statusButton:SetHandler("OnMouseEnter", function(control)
                if control.dungeon then T:ShowAchievementTooltip(control, control.dungeon, control.statusKey) end
            end)
            statusButton:SetHandler("OnMouseExit", function() T:HideDetailPopup029725() end)
            statusButton:SetHandler("OnMouseUp", function(control, button, upInside)
                if upInside == false or button ~= MOUSE_BUTTON_INDEX_RIGHT or not control.dungeon then return end
                T:CreateGroupFinder(control.dungeon, control.statusKey)
            end)
            statuses[key] = statusButton
        end

        local tp = makeButton(row, nil, "TP", function(control)
            if control.dungeon then T:TeleportToDungeon(control.dungeon) end
        end)
        tp:SetAnchor(LEFT, row, LEFT, 812, 0)
        tp:SetDimensions(110,32)

        local group = makeButton(row, nil, "CREATE", function(control)
            if control.dungeon then T:CreateGroupFinder(control.dungeon, nil) end
        end)
        group:SetAnchor(LEFT, row, LEFT, 954, 0)
        group:SetDimensions(176,32)

        self.rows[i] = {
            control=row, bg=rowBg, dungeon=dungeonButton,
            statuses=statuses, tp=tp, group=group,
        }
    end

    local footer = WM:CreateControl("EAS_MasterAchievementTrackerFooter029713", w, CT_CONTROL)
    footer:SetAnchor(BOTTOMLEFT, w, BOTTOMLEFT, 16, -12)
    footer:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -16, -12)
    footer:SetHeight(54)

    self.prev = makeButton(footer, nil, "< PREV", function()
        local sv=T:GetSV(); if sv then sv.page=math.max(1,(tonumber(sv.page) or 1)-1) end; T:Refresh()
    end)
    self.prev:SetDimensions(110,34); self.prev:SetAnchor(LEFT,footer,LEFT,0,0)

    self.pageLabel = makeLabel(footer, nil, "PAGE 1 / 1", "ZoFontGameBold", {0.78,0.80,0.86,1})
    self.pageLabel:SetAnchor(LEFT,self.prev,RIGHT,12,0); self.pageLabel:SetDimensions(190,34)
    self.pageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER); self.pageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.next = makeButton(footer, nil, "NEXT >", function()
        local sv=T:GetSV(); if sv then sv.page=(tonumber(sv.page) or 1)+1 end; T:Refresh()
    end)
    self.next:SetDimensions(110,34); self.next:SetAnchor(LEFT,self.pageLabel,RIGHT,12,0)

    self.summary = makeLabel(footer, nil, "", "ZoFontGameSmall", {0.68,0.72,0.80,1})
    self.summary:SetAnchor(LEFT,self.next,RIGHT,24,0); self.summary:SetDimensions(600,34)
    self.summary:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    self.window = w
    return w
end

function T:CancelDeferredBuild029715()
    EM:UnregisterForUpdate(NAME .. "_DeferredBuild029715")
    self.deferredBuildCoroutine029715 = nil
    self.deferredBuildRunning029715 = false
end

function T:StartDeferredBuild029715(force)
    if self.achievementMappingBuilt and not force then return end
    if self.deferredBuildRunning029715 and not force then return end

    self:CancelDeferredBuild029715()
    if force then
        self:BuildDungeonCatalog(true)
        self.achievementIndex = nil
        self.achievementMappingBuilt = false
    else
        self:BuildDungeonCatalog(false)
    end

    local dungeons = self.dungeons or {}
    local aliases = {}
    for index, dungeon in ipairs(dungeons) do
        aliases[index] = self:DungeonAliases(dungeon)
        dungeon.achievement = {}
    end

    self.deferredBuildRunning029715 = true
    self.deferredBuildProgress029715 = 0
    self.deferredBuildPhase029715 = "Scanning ESO achievements"

    local co = coroutine.create(function()
        local records = {}
        local clock = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds or GetGameTimeMilliseconds
        local sliceStartedMS = type(clock) == "function" and clock() or 0
        local probeUnits = 0

        -- v0.29.716: spend a small TIME budget per rendered frame instead of
        -- yielding after a tiny fixed number of records. On fast PCs this does
        -- far more useful work per frame while still capping the hitch cost.
        local function yieldForBudget(weight)
            probeUnits = probeUnits + (tonumber(weight) or 1)
            if probeUnits < 8 then return end
            probeUnits = 0
            if type(clock) ~= "function" then return end

            local now = clock()
            local inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
            local budgetMS = inCombat and 0.35 or 0.80
            if now - sliceStartedMS >= budgetMS then
                coroutine.yield()
                sliceStartedMS = clock()
            end
        end

        local function yieldScan()
            yieldForBudget(1)
        end
        local function labelMatchesDungeon(text)
            local hay = words(text)
            if hay == "" then return false end
            for _, aliasList in ipairs(aliases) do
                for _, alias in ipairs(aliasList) do
                    if boundedContains(hay, alias) then return true end
                end
            end
            return false
        end
        local function addAchievement(topIndex, subIndex, achievementIndex, categoryName, subName)
            local id = tonumber(safe(GetAchievementId, 0, topIndex, subIndex, achievementIndex)) or 0
            if id > 0 then
                records[#records + 1] = getAchievementText(id, categoryName, subName)
            end
            yieldScan()
        end

        if type(GetNumAchievementCategories) == "function"
            and type(GetAchievementCategoryInfo) == "function"
            and type(GetAchievementId) == "function" then
            local topCount = tonumber(safe(GetNumAchievementCategories, 0)) or 0
            for top = 1, topCount do
                local categoryName, numSub, numAchievements = safe(GetAchievementCategoryInfo, "", top)
                categoryName = clean(categoryName)
                numSub = tonumber(numSub) or 0
                numAchievements = tonumber(numAchievements) or 0
                local categoryWords = words(categoryName)
                local categoryRelevant = containsPlain(categoryWords, "dungeon") or labelMatchesDungeon(categoryName)

                if categoryRelevant then
                    for achievementIndex = 1, numAchievements do
                        addAchievement(top, nil, achievementIndex, categoryName, "")
                    end
                end

                for sub = 1, numSub do
                    local subName, subAchievements = safe(GetAchievementSubCategoryInfo, "", top, sub)
                    subName = clean(subName)
                    subAchievements = tonumber(subAchievements) or 0
                    local subWords = words(subName)
                    local relevant = categoryRelevant
                        or containsPlain(subWords, "dungeon")
                        or labelMatchesDungeon(subName)
                    if relevant then
                        for achievementIndex = 1, subAchievements do
                            addAchievement(top, sub, achievementIndex, categoryName, subName)
                        end
                    end
                    yieldScan()
                end

                T.deferredBuildProgress029715 = topCount > 0 and math.floor((top / topCount) * 55) or 55
                yieldScan()
            end
        end

        T.achievementIndex = records
        T.deferredBuildPhase029715 = "Matching dungeon achievements"

        local function yieldMap(weight)
            yieldForBudget(weight or 1)
        end

        for dungeonIndex, dungeon in ipairs(dungeons) do
            local candidates = {}
            local dungeonAliases = aliases[dungeonIndex] or {}
            for _, record in ipairs(records) do
                local matched = false
                local recordText = record.text or ""
                for _, alias in ipairs(dungeonAliases) do
                    if boundedContains(recordText, alias) then
                        matched = true
                        break
                    end
                end
                if matched then candidates[#candidates + 1] = record end
                yieldMap()
            end

            candidates = preferExactCandidates029727(candidates, dungeon.name)

            for _, key in ipairs(STATUS_KEYS) do
                local best, bestScore = nil, -99999
                for _, record in ipairs(candidates) do
                    local score = T:ScoreAchievement(record, key)
                    if score > bestScore then best, bestScore = record, score end
                end
                local threshold = key == "VET" and 35 or 50
                if best and bestScore >= threshold then
                    dungeon.achievement[key] = {
                        id = best.id,
                        name = best.name,
                        description = best.description,
                        category = best.category,
                        subcategory = best.subcategory,
                        criteria = best.criteria,
                        completed = safe(IsAchievementComplete, false, best.id) == true,
                        score = bestScore,
                    }
                end
            end

            applyExplicitDungeonCore029727(dungeon)

            -- Reuse the candidate set we already paid to build. This prevents a
            -- second full dungeon x achievement scan when Trifecta/Extra columns
            -- are first rendered.
            if type(T.MapDungeonExtendedFromCandidates029725) == "function" then
                T:MapDungeonExtendedFromCandidates029725(dungeon, candidates)
            end

            T.deferredBuildProgress029715 = 55 + (#dungeons > 0 and math.floor((dungeonIndex / #dungeons) * 45) or 45)
            yieldMap(8)
        end

        T.achievementMappingBuilt = true
        T.dungeonExtendedBuilt029722 = true
        T.deferredBuildProgress029715 = 100
        T.deferredBuildPhase029715 = "Ready"
    end)

    self.deferredBuildCoroutine029715 = co
    EM:RegisterForUpdate(NAME .. "_DeferredBuild029715", 25, function()
        local thread = T.deferredBuildCoroutine029715
        if not thread then
            T:CancelDeferredBuild029715()
            return
        end

        local ok, err = coroutine.resume(thread)
        if not ok then
            T:CancelDeferredBuild029715()
            T.deferredBuildPhase029715 = "Build error"
            printMsg("Master Achievement Tracker deferred scan stopped: " .. tostring(err))
            T:Render029715()
            return
        end

        if coroutine.status(thread) == "dead" then
            T:CancelDeferredBuild029715()
            T:RefreshCompletionState()
            T:Render029715()
        elseif T.window and not T.window:IsHidden() then
            T.deferredUiTick029715 = (tonumber(T.deferredUiTick029715) or 0) + 1
            if T.deferredUiTick029715 >= 8 then
                T.deferredUiTick029715 = 0
                T:Render029715()
            end
        end
    end)
end

local Render029715ImplArch

function T:Render029715(...)

    return Render029715ImplArch(self, ...)

end

Render029715ImplArch = function(self)
    self:CreateWindow()
    self:BuildDungeonCatalog(false)

    local s = self:GetSV()
    if not s then return end
    local filtered = self:GetFilteredDungeons()
    local pages = math.max(1, math.ceil(#filtered / ROW_COUNT))
    s.page = math.max(1, math.min(pages, tonumber(s.page) or 1))
    local first = ((s.page - 1) * ROW_COUNT) + 1

    for i, row in ipairs(self.rows or {}) do
        local dungeon = filtered[first + i - 1]
        if dungeon then
            row.control:SetHidden(false)
            row.dungeon.dungeon = dungeon
            row.tp.dungeon = dungeon
            row.group.dungeon = dungeon
            row.dungeon:SetText(dungeon.name .. (dungeon.isDLC and "  |cB080FF[DLC]|r" or ""))

            for _, key in ipairs(STATUS_KEYS) do
                local statusButton = row.statuses[key]
                local a = dungeon.achievement and dungeon.achievement[key]
                local completedCheck = statusButton._easCompletedCheck029721
                statusButton.dungeon = dungeon
                if completedCheck then completedCheck:SetHidden(true) end

                if not self.achievementMappingBuilt then
                    statusButton:SetText("…")
                    statusButton:SetNormalFontColor(0.72,0.74,0.78,1)
                elseif not a then
                    statusButton:SetText("—")
                    statusButton:SetNormalFontColor(0.42,0.44,0.48,1)
                elseif a.completed then
                    statusButton:SetText("")
                    if completedCheck then completedCheck:SetHidden(false) end
                else
                    statusButton:SetText("□")
                    statusButton:SetNormalFontColor(0.88,0.40,0.25,1)
                end
            end

            if self.achievementMappingBuilt then
                local missing = self:GetMissing(dungeon)
                row.group:SetText(#missing > 0 and "CREATE • "..tostring(#missing).." NEED" or "CREATE GROUP")
            else
                row.group:SetText("LOADING…")
            end
        else
            row.control:SetHidden(true)
            row.dungeon.dungeon, row.tp.dungeon, row.group.dungeon = nil, nil, nil
            for _, key in ipairs(STATUS_KEYS) do row.statuses[key].dungeon = nil end
        end
    end

    for i,key in ipairs(FILTERS) do
        local b=self.filterButtons[i]
        if b then
            local active = s.filter == key
            b:SetNormalFontColor(active and 1 or 0.78, active and 0.82 or 0.80, active and 0.24 or 0.86, 1)
        end
    end

    self.pageLabel:SetText(string.format("PAGE %d / %d", s.page, pages))
    self.prev:SetEnabled(s.page > 1)
    self.next:SetEnabled(s.page < pages)

    if not self.achievementMappingBuilt then
        local phase = tostring(self.deferredBuildPhase029715 or "Preparing")
        local progress = tonumber(self.deferredBuildProgress029715) or 0
        self.summary:SetText(string.format("%d dungeons • %s • %d%% • adaptive fast load", #(self.dungeons or {}), phase, progress))
        return
    end

    local complete, mappedCells, completeCells = 0,0,0
    for _, dungeon in ipairs(self.dungeons or {}) do
        if self:IsDungeonComplete(dungeon) then complete = complete + 1 end
        for _, key in ipairs(STATUS_KEYS) do
            local a=dungeon.achievement and dungeon.achievement[key]
            if a then mappedCells=mappedCells+1; if a.completed then completeCells=completeCells+1 end end
        end
    end
    self.summary:SetText(string.format("%d dungeons • %d complete sets • %d/%d mapped achievements complete", #(self.dungeons or {}), complete, completeCells, mappedCells))
end

local RefreshImplArch

function T:Refresh(...)

    return RefreshImplArch(self, ...)

end

RefreshImplArch = function(self)
    if self.achievementMappingBuilt then
        self:RefreshCompletionState()
    else
        self:StartDeferredBuild029715(false)
    end
    self:Render029715()
end

local ShowImplArch

function T:Show(...)

    return ShowImplArch(self, ...)

end

ShowImplArch = function(self)
    self:CreateWindow()
    self.window:SetHidden(false)
    if self.window.BringWindowToTop then self.window:BringWindowToTop() end

    -- Draw immediately; scan ESO's achievement database incrementally afterward.
    self:Render029715()
    self:StartDeferredBuild029715(false)
end

local HideImplArch

function T:Hide(...)

    return HideImplArch(self, ...)

end

HideImplArch = function(self)
    if self.window then self.window:SetHidden(true) end
    if self.deferredBuildRunning029715 then self:CancelDeferredBuild029715() end
    T:HideDetailPopup029725()
end

local ToggleImplArch

function T:Toggle(...)

    return ToggleImplArch(self, ...)

end

ToggleImplArch = function(self)
    self:CreateWindow()
    if self.window:IsHidden() then self:Show() else self:Hide() end
end

local InitializeImplArch

function T:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self:GetSV()
    self:BuildDungeonCatalog(false)

    if EVENT_ACHIEVEMENT_AWARDED ~= nil then
        EM:RegisterForEvent(NAME .. "_Achievement", EVENT_ACHIEVEMENT_AWARDED, function()
            T:RefreshCompletionState()
            if T.window and not T.window:IsHidden() then T:Refresh() end
        end)
    end
    if EVENT_PLAYER_ACTIVATED ~= nil then
        EM:RegisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            T.travelNodeCache = nil
            if T.window and not T.window:IsHidden() then T:Refresh() end
        end)
    end

    SLASH_COMMANDS = SLASH_COMMANDS or {}
    SLASH_COMMANDS["/mat"] = function() T:Toggle() end
    SLASH_COMMANDS["/easmat"] = function() T:Toggle() end
end

function ESOAdventurerSuite_ToggleMasterAchievementTracker()
    if EPC.MasterAchievementTracker then EPC.MasterAchievementTracker:Toggle() end
end

if type(ZO_CreateStringId) == "function" then
    ZO_CreateStringId("SI_BINDING_NAME_ESO_ADVENTURER_SUITE_MASTER_ACHIEVEMENT_TRACKER", "Master Dungeon Achievement Tracker")
end

-- === v0.29.722 MASTER ACHIEVEMENT TRACKER EXPANSION =========================
-- Adds the four-page Scores/Trials/4-Man/Starter layout requested for the
-- Master Achievement Tracker while keeping the existing deferred dungeon scan,
-- travel actions, Group Finder actions, and native achievement links.

do
    local EXP_NAME = NAME .. "_Expanded029722"
    local PAGE_ORDER = { "OVERVIEW", "TRIALS", "TRIFECTAS", "STARTER" }
    local PAGE_LABELS = {
        OVERVIEW = "All Scores and Tris",
        TRIALS = "Trials",
        TRIFECTAS = "4 Man Trifectas",
        STARTER = "Starter Dungeons",
    }

    local RAID_KEYS = { "VET", "PART1", "PART2", "HM", "TRI", "EXTRA" }
    local raidCategoryTrial = rawget(_G, "RAID_CATEGORY_TRIAL")
    local raidCategoryChallenge = rawget(_G, "RAID_CATEGORY_CHALLENGE")

    local baseGetSV = T.GetSV
    local baseInitialize = InitializeImplArch

    local function expGetSV(self)
        local s = baseGetSV(self)
        if not s then return nil end
        if s.expView == nil then s.expView = "OVERVIEW" end
        if s.expTriPage == nil then s.expTriPage = 1 end
        if s.expOverviewTriPage == nil then s.expOverviewTriPage = 1 end
        if s.expStarterPage == nil then s.expStarterPage = 1 end
        return s
    end
    T.GetSV = expGetSV

    local function fmtScore(value)
        value = tonumber(value) or 0
        if type(ZO_CommaDelimitNumber) == "function" then
            local ok, text = pcall(ZO_CommaDelimitNumber, value)
            if ok and text then return tostring(text) end
        end
        local s = tostring(math.floor(value))
        while true do
            local changed
            s, changed = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
            if changed == 0 then break end
        end
        return s
    end

    local function completion(record)
        return T:GetRecordCompletion029727(record)
    end
    local function naRecord029727(label,description)
        return {notApplicable029727=true,name=label or "N/A",description=description or "No separate ESO achievement applies to this slot.",criteria={},completed=false}
    end
    local function groupRecord029727(label,records,description)
        local list,seen={},{}
        for _,r in ipairs(records or {}) do
            if r and r.id and not seen[r.id] then seen[r.id]=true; list[#list+1]=r end
        end
        if #list==0 then return naRecord029727("N/A",description) end
        table.sort(list,function(a,b)return (tonumber(a.id) or 0)<(tonumber(b.id) or 0) end)
        local g={records029727=list,groupLabel029727=label,description=description or ("All "..tostring(label).." tied to this activity."),criteria={}}
        completion(g)
        return g
    end
    local function splitPartialGroups029727(records)
        if #records==0 then
            return naRecord029727("N/A","No separate partial-hard-mode achievement applies."),
                   naRecord029727("N/A","No second partial-hard-mode achievement applies.")
        elseif #records==1 then
            return records[1],naRecord029727("N/A","This trial has only one separate partial-hard-mode achievement.")
        elseif #records==2 then
            return records[1],records[2]
        end
        local left,right={},{}
        local cut=math.ceil(#records/2)
        for i,r in ipairs(records) do if i<=cut then left[#left+1]=r else right[#right+1]=r end end
        return groupRecord029727("Partial HMs",left),groupRecord029727("Partial HMs",right)
    end

    local function recordSignals(record)
        local text = words((record and record.text) or "")
        local title = words((record and record.name) or "")
        local hm = containsPlain(text, "hard mode")
            or containsPlain(text, "hardmode")
            or containsPlain(text, "challenge banner")
            or containsPlain(text, "scroll of glorious")
            or containsPlain(text, "banner of challenge")
        local sp = containsPlain(text, "speed run")
            or (containsPlain(text, "within") and containsPlain(text, "minute"))
            or containsPlain(text, "time limit")
        local nd = containsPlain(text, "no death")
            or containsPlain(text, "without dying")
            or containsPlain(text, "without suffering")
            or containsPlain(text, "group member death")
            or containsPlain(text, "without any group member")
            or containsPlain(text, "without a group member")
            or containsPlain(text, "no group member dies")
        local vet = containsPlain(text, "veteran") or containsPlain(title, "veteran")
        return hm, sp, nd, vet
    end

    local function trifectaScore(record)
        local hm, sp, nd = recordSignals(record)
        local score = (hm and 130 or 0) + (sp and 130 or 0) + (nd and 130 or 0)
        local title = words((record and record.name) or "")
        local text = words((record and record.text) or "")
        if containsPlain(title, "challenger") then score = score + 45 end
        if containsPlain(title, "trifecta") then score = score + 80 end
        if containsPlain(text, "same run") or containsPlain(text, "single run") then score = score + 40 end
        if containsPlain(text, "veteran") then score = score + 50 end
        return score
    end

    local function extraScore(record)
        local score = 0
        local text = words((record and record.text) or "")
        local title = words((record and record.name) or "")
        local hm, sp, nd, vet = recordSignals(record)
        if not hm and not sp and not nd and not vet then score = score + 80 end
        if record and record.criteria and #record.criteria > 0 then score = score + 25 end
        if containsPlain(text, "veteran") then score = score + 5 end
        if containsPlain(title, "slayer") or containsPlain(title, "destroyer") or containsPlain(title, "breaker") then score = score + 20 end
        return score
    end

    function T:LinkAnyAchievement(record)
        if not record or record.notApplicable029727 then return false end
        if record.records029727 then
            local target=nil
            for _,child in ipairs(record.records029727) do
                if safe(IsAchievementComplete,false,child.id)~=true then target=child; break end
            end
            record=target or record.records029727[1]
        end
        if not record or not record.id then return false end
        local link
        if type(ZO_LinkHandler_CreateLink) == "function" then
            local ok, value = pcall(ZO_LinkHandler_CreateLink,
                clean(record.name or "Achievement"), "FFFFFF",
                rawget(_G, "ACHIEVEMENT_LINK_TYPE") or "achievement", record.id)
            if ok then link = value end
        end
        if link and link ~= "" and type(StartChatInput) == "function" then
            StartChatInput(link)
            return true
        end
        printMsg(clean(record.name or "Achievement") .. " — Achievement ID " .. tostring(record.id))
        return false
    end

    function T:ShowAnyAchievementTooltip(owner, record, context)
        if not owner then return end
        if record then completion(record) end
        T:ShowDetailPopup029725(
            owner,
            record,
            clean(context or "Achievement"),
            "No separate ESO achievement applies to this slot.",
            record and "Click the achievement cell to link it in chat." or ""
        )
    end

    function T:GetCandidatesForDungeon029722(dungeon)
        local out = {}
        for _, record in ipairs(self.achievementIndex or {}) do
            if self:TextMatchesDungeon(record.text, dungeon)
                or self:TextMatchesDungeon(record.subcategory, dungeon)
                or self:TextMatchesDungeon(record.category, dungeon) then
                out[#out + 1] = record
            end
        end
        return preferExactCandidates029727(out,dungeon and dungeon.name or "")
    end

    function T:MapDungeonExtendedFromCandidates029725(dungeon,candidates)
        if not dungeon then return end
        candidates=preferExactCandidates029727(candidates or {},dungeon.name)
        applyExplicitDungeonCore029727(dungeon)
        local known=explicitFor029727(DUNGEON_IDS029727,dungeon.name)
        local used={}
        for _,key in ipairs(STATUS_KEYS) do
            local a=dungeon.achievement and dungeon.achievement[key]
            if a and a.id then used[a.id]=true end
        end
        local tri=nil
        if known then
            tri=known.triId and recordById029727(known.triId) or naRecord029727("N/A","This dungeon has no separate trifecta achievement.")
        else
            local bestScore=-1
            for _,r in ipairs(candidates) do local score=trifectaScore(r); if score>bestScore then tri,bestScore=r,score end end
            if bestScore<300 then tri=naRecord029727("N/A","No separate trifecta achievement applies to this dungeon.") end
        end
        if tri and tri.id then used[tri.id]=true end
        local extras={}
        for _,r in ipairs(candidates) do
            local title=words(r.name or "")
            if not used[r.id] and not containsPlain(title,"vanquisher") and not containsPlain(title,"style master") then extras[#extras+1]=r end
        end
        dungeon.extAchievement029722={
            TRI=tri,
            EXTRA=groupRecord029727("Extras",extras,"Other achievements tied to "..clean(dungeon.name).."."),
        }
    end
    function T:BuildDungeonExtendedAchievements029722(force)
        if not self.achievementMappingBuilt then return false end
        if self.dungeonExtendedBuilt029722 and not force then
            for _, dungeon in ipairs(self.dungeons or {}) do
                for _, record in pairs(dungeon.extAchievement029722 or {}) do completion(record) end
            end
            return true
        end

        for _, dungeon in ipairs(self.dungeons or {}) do
            local candidates = self:GetCandidatesForDungeon029722(dungeon)
            self:MapDungeonExtendedFromCandidates029725(dungeon, candidates)
        end
        self.dungeonExtendedBuilt029722 = true
        return true
    end

    local function buildRaidCategory(category, kind)
        local out = {}
        if category == nil then return out end
        if type(GetNextRaidLeaderboardId) == "function" then
            local last, guard = nil, 0
            while guard < 100 do
                guard = guard + 1
                local raidId = safe(GetNextRaidLeaderboardId, nil, category, last)
                raidId = tonumber(raidId)
                if not raidId or raidId <= 0 then break end
                local name = clean(safe(GetRaidLeaderboardName, "", raidId))
                if name == "" then name = clean(safe(GetRaidName, "", raidId)) end
                local sortIndex = tonumber(safe(GetRaidLeaderboardUISortIndex, 99999, category, raidId)) or 99999
                if name ~= "" then
                    out[#out + 1] = {
                        name = name, raidId = raidId, category = category,
                        sortIndex = sortIndex, kind = kind, achievement = {},
                    }
                end
                if last == raidId then break end
                last = raidId
            end
        elseif type(GetNumRaidLeaderboards) == "function" and type(GetRaidLeaderboardInfo) == "function" then
            local count = tonumber(safe(GetNumRaidLeaderboards, 0, category)) or 0
            for i = 1, count do
                local ok, name, raidId = pcall(GetRaidLeaderboardInfo, category, i)
                if ok and tonumber(raidId) and clean(name) ~= "" then
                    out[#out + 1] = { name=clean(name), raidId=tonumber(raidId), category=category, sortIndex=i, kind=kind, achievement={} }
                end
            end
        end
        table.sort(out, function(a,b)
            if a.sortIndex ~= b.sortIndex then return a.sortIndex < b.sortIndex end
            return lower(a.name) < lower(b.name)
        end)
        return out
    end

    local function arenaCanonicalKey029743(name)
        local value = lower(clean(name))
        value = value:gsub("%s*%(%s*veteran%s*%)%s*$","")
        value = value:gsub("%s+veteran%s*$","")
        value = value:gsub("%s+"," ")
        value = value:gsub("^%s+",""):gsub("%s+$","")
        return contentKey029727(value)
    end

    local function canonicalArenaDisplayName029743(name)
        local value = clean(name)
        value = value:gsub("%s*%(%s*[Vv]eteran%s*%)%s*$","")
        value = value:gsub("%s+[Vv]eteran%s*$","")
        return clean(value)
    end

    function T:BuildRaidCatalog029722(force)
        if self.raidCatalogBuilt029722 and not force then return end
        self.trials029722 = buildRaidCategory(raidCategoryTrial, "TRIAL")

        local rawArenas029743 = buildRaidCategory(raidCategoryChallenge, "ARENA")
        local mergedArenas029743 = {}
        local byKey029743 = {}

        -- ESO can expose multiple leaderboard variants of one arena, including
        -- names ending in "(Veteran)". All Scores tracks the activity once.
        for _,entry in ipairs(rawArenas029743 or {}) do
            local key = arenaCanonicalKey029743(entry.name)
            if key ~= "" then
                local existing = byKey029743[key]
                if not existing then
                    entry.name = canonicalArenaDisplayName029743(entry.name)
                    entry.arenaCanonicalKey029743 = key
                    byKey029743[key] = entry
                    mergedArenas029743[#mergedArenas029743+1] = entry
                elseif existing.raidId == nil and entry.raidId ~= nil then
                    existing.raidId = entry.raidId
                    existing.category = entry.category
                    existing.sortIndex = entry.sortIndex
                end
            end
        end

        -- Merge verified arenas that ESO's leaderboard enumeration omits.
        local nextSort029743 = #mergedArenas029743 + 1
        for _,row in ipairs(EXPLICIT_ARENAS029727 or {}) do
            local name = canonicalArenaDisplayName029743(row[1])
            local key = arenaCanonicalKey029743(name)
            if name ~= "" and key ~= "" and not byKey029743[key] then
                local entry = {
                    name=name,
                    raidId=nil,
                    category=raidCategoryChallenge,
                    sortIndex=nextSort029743,
                    kind="ARENA",
                    achievement={},
                    syntheticArena029740=true,
                    arenaCanonicalKey029743=key,
                }
                nextSort029743 = nextSort029743 + 1
                byKey029743[key] = entry
                mergedArenas029743[#mergedArenas029743+1] = entry
            end
        end

        table.sort(mergedArenas029743,function(a,b)
            local ai=tonumber(a.sortIndex) or 99999
            local bi=tonumber(b.sortIndex) or 99999
            if ai~=bi then return ai<bi end
            return lower(a.name)<lower(b.name)
        end)
        self.arenas029722 = mergedArenas029743

        self.raidCatalogBuilt029722 = true
        self.raidAchievementBuilt029722 = false
        self.raidAchievementRecords029722 = nil
    end
    local function raidAliases(entry)
        local base = words(entry and entry.name or "")
        local out = {}
        if base ~= "" then out[#out + 1] = base end
        if base:sub(1,4) == "the " then out[#out + 1] = base:sub(5) end
        return out
    end

    local function recordMatchesRaid(record, entry)
        local text = words(((record and record.category) or "") .. " " .. ((record and record.subcategory) or "") .. " " .. ((record and record.text) or ""))
        for _, alias in ipairs(raidAliases(entry)) do
            if boundedContains(text, alias) then return true end
        end
        return false
    end

    local function chooseBestByScore(candidates, key, excluded)
        local best, bestScore = nil, -99999
        for _, record in ipairs(candidates) do
            if not excluded[record.id] then
                local score = T:ScoreAchievement(record, key)
                if score > bestScore then best, bestScore = record, score end
            end
        end
        local threshold = key == "VET" and 35 or 50
        if best and bestScore >= threshold then return best end
        return nil
    end

    function T:MapRaidAchievements029722(yieldFn)
        local records=self.raidAchievementRecords029722 or {}
        local all={}
        for _,item in ipairs(self.trials029722 or {}) do all[#all+1]=item end
        for _,item in ipairs(self.arenas029722 or {}) do all[#all+1]=item end
        for _,entry in ipairs(all) do
            local candidates={}
            for _,r in ipairs(records) do
                if recordMatchesRaid(r,entry) then candidates[#candidates+1]=r end
                if yieldFn then yieldFn(1) end
            end
            candidates=preferExactCandidates029727(candidates,entry.name)
            local knownMap=entry.kind=="ARENA" and ARENA_IDS029727 or TRIAL_IDS029727
            local known=explicitFor029727(knownMap,entry.name)
            local used={}
            local function take(id)
                local r=recordById029727(id)
                if r and r.id then used[r.id]=true end
                return r
            end

            local vet=known and take(known.vetId) or chooseBestByScore(candidates,"VET",used)
            if vet and vet.id then used[vet.id]=true end
            local hm=(known and known.hmId) and take(known.hmId) or chooseBestByScore(candidates,"HM",used)
            if not hm then hm=naRecord029727("N/A","This activity has no separate hard-mode achievement.") end
            if hm and hm.id then used[hm.id]=true end

            local tri=nil
            if known and known.triId then
                tri=take(known.triId)
            else
                local bestScore=-1
                for _,r in ipairs(candidates) do
                    local score=trifectaScore(r)
                    if score>bestScore then tri,bestScore=r,score end
                    if yieldFn then yieldFn(1) end
                end
                if bestScore<300 then tri=naRecord029727("N/A","No separate trifecta achievement applies to this activity.") end
            end
            if tri and tri.id then used[tri.id]=true end

            local partials={}
            if entry.kind=="TRIAL" then
                local entryKey=contentKey029727(entry.name)
                for _,r in ipairs(candidates) do
                    if not used[r.id] then
                        local rhm,rsp,rnd=recordSignals(r)
                        local txt=words(r.text or "")
                        local title=words(r.name or "")
                        local specialPartial =
                            (entryKey=="asylum sanctorium" and
                                (containsPlain(title,"executioners judgment") or containsPlain(title,"righteous condemnation")))
                            or (entryKey=="cloudrest" and
                                (containsPlain(title,"a sload and her shadow") or containsPlain(title,"threes deadly company")))
                        if specialPartial or (rhm and not rsp and not rnd and
                            (containsPlain(txt,"challenge banner") or containsPlain(txt,"hard mode"))) then
                            partials[#partials+1]=r
                        end
                    end
                    if yieldFn then yieldFn(1) end
                end
            end
            table.sort(partials,function(a,b)return (tonumber(a.id) or 0)<(tonumber(b.id) or 0) end)
            local p1,p2=splitPartialGroups029727(partials)
            for _,r in ipairs(partials) do if r.id then used[r.id]=true end end

            local extras={}
            for _,r in ipairs(candidates) do
                local title=words(r.name or "")
                if not used[r.id] and not containsPlain(title,"vanquisher") and not containsPlain(title,"style master") then extras[#extras+1]=r end
                if yieldFn then yieldFn(1) end
            end
            entry.achievement={
                VET=vet or naRecord029727("N/A","No separate veteran achievement applies."),
                PART1=p1,PART2=p2,
                HM=hm or naRecord029727("N/A","No separate hard-mode achievement applies."),
                TRI=tri,
                EXTRA=groupRecord029727("Extras",extras,"Other achievements tied to "..clean(entry.name).."."),
            }
            if yieldFn then yieldFn(4) end
        end
    end
    function T:CancelRaidAchievementBuild029722()
        EM:UnregisterForUpdate(EXP_NAME .. "_RaidAchievements")
        self.raidAchievementCoroutine029722 = nil
        self.raidAchievementRunning029722 = false
    end

    function T:StartRaidAchievementBuild029722(force)
        if self.raidAchievementBuilt029722 and not force then return end
        if self.raidAchievementRunning029722 and not force then return end
        if self.deferredBuildRunning029715 then return end
        self:BuildRaidCatalog029722(false)
        self:CancelRaidAchievementBuild029722()
        if force then
            self.raidAchievementBuilt029722 = false
            self.raidAchievementRecords029722 = nil
        end

        local allEntries = {}
        for _, v in ipairs(self.trials029722 or {}) do allEntries[#allEntries+1] = v end
        for _, v in ipairs(self.arenas029722 or {}) do allEntries[#allEntries+1] = v end
        local aliases = {}
        for _, entry in ipairs(allEntries) do
            for _, alias in ipairs(raidAliases(entry)) do aliases[#aliases+1] = alias end
        end

        self.raidAchievementRunning029722 = true
        self.raidAchievementProgress029722 = 0
        self.raidAchievementPhase029722 = "Scanning trial and arena achievements"

        local co = coroutine.create(function()
            local records = {}
            local clock = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds or GetGameTimeMilliseconds
            local slice = type(clock) == "function" and clock() or 0
            local probes = 0
            local function yieldBudget(weight)
                probes = probes + (weight or 1)
                if probes < 10 then return end
                probes = 0
                if type(clock) ~= "function" then return end
                local now = clock()
                local budget = (type(IsUnitInCombat) == "function" and IsUnitInCombat("player")) and 0.35 or 0.80
                if now - slice >= budget then coroutine.yield(); slice = clock() end
            end
            local function matchesAlias(text)
                local w = words(text)
                for _, alias in ipairs(aliases) do if boundedContains(w, alias) then return true end end
                return false
            end
            local function add(top, sub, index, cat, subName)
                local id = tonumber(safe(GetAchievementId, 0, top, sub, index)) or 0
                if id > 0 then records[#records+1] = getAchievementText(id, cat, subName) end
                yieldBudget(1)
            end

            if type(GetNumAchievementCategories) == "function" and type(GetAchievementCategoryInfo) == "function" then
                local topCount = tonumber(safe(GetNumAchievementCategories, 0)) or 0
                for top = 1, topCount do
                    local cat, numSub, numAch = safe(GetAchievementCategoryInfo, "", top)
                    cat = clean(cat); numSub = tonumber(numSub) or 0; numAch = tonumber(numAch) or 0
                    local cw = words(cat)
                    local catRelevant = containsPlain(cw, "trial") or containsPlain(cw, "arena") or containsPlain(cw, "raid") or matchesAlias(cat)
                    if catRelevant then for i=1,numAch do add(top,nil,i,cat,"") end end
                    for sub=1,numSub do
                        local subName, subCount = safe(GetAchievementSubCategoryInfo, "", top, sub)
                        subName = clean(subName); subCount = tonumber(subCount) or 0
                        local sw = words(subName)
                        local relevant = catRelevant or containsPlain(sw,"trial") or containsPlain(sw,"arena") or matchesAlias(subName)
                        if relevant then for i=1,subCount do add(top,sub,i,cat,subName) end end
                        yieldBudget(1)
                    end
                    T.raidAchievementProgress029722 = topCount > 0 and math.floor((top/topCount)*80) or 80
                    yieldBudget(2)
                end
            end
            T.raidAchievementRecords029722 = records
            T.raidAchievementPhase029722 = "Matching trial and arena achievements"
            T:MapRaidAchievements029722(yieldBudget)
            T.raidAchievementProgress029722 = 100
            T.raidAchievementPhase029722 = "Ready"
            T.raidAchievementBuilt029722 = true
        end)

        self.raidAchievementCoroutine029722 = co
        EM:RegisterForUpdate(EXP_NAME .. "_RaidAchievements", 25, function()
            local thread = T.raidAchievementCoroutine029722
            if not thread then T:CancelRaidAchievementBuild029722(); return end
            local ok, err = coroutine.resume(thread)
            if not ok then
                T:CancelRaidAchievementBuild029722()
                T.raidAchievementPhase029722 = "Build error"
                printMsg("Master Achievement Tracker trial scan stopped: " .. tostring(err))
                T:Render029715()
                return
            end
            if coroutine.status(thread) == "dead" then
                T:CancelRaidAchievementBuild029722()
                T:Render029715()
            elseif T.window and not T.window:IsHidden() then
                T.raidUiTick029722 = (tonumber(T.raidUiTick029722) or 0) + 1
                if T.raidUiTick029722 >= 10 then T.raidUiTick029722 = 0; T:Render029715() end
            end
        end)
    end

    function T:UpdateScoreCache029722()
        self.scoreCache029722 = self.scoreCache029722 or {}
        for _, entry in ipairs(self.trials029722 or {}) do
            local _, best = safe(GetRaidLeaderboardLocalPlayerInfo, 0, entry.raidId)
            self.scoreCache029722["raid:"..entry.raidId] = tonumber(best) or 0
        end
        for _, entry in ipairs(self.arenas029722 or {}) do
            if entry.raidId ~= nil then
                local _, best = safe(GetRaidLeaderboardLocalPlayerInfo, 0, entry.raidId)
                self.scoreCache029722["raid:"..entry.raidId] = tonumber(best) or 0
            end
        end
        local edId = tonumber(rawget(_G, "DEFAULT_ENDLESS_DUNGEON_ID")) or 1
        local solo = rawget(_G, "ENDLESS_DUNGEON_GROUP_TYPE_SOLO")
        local duo = rawget(_G, "ENDLESS_DUNGEON_GROUP_TYPE_DUO")
        if solo ~= nil and type(GetEndlessDungeonLeaderboardLocalPlayerInfo) == "function" then
            local _, score = safe(GetEndlessDungeonLeaderboardLocalPlayerInfo, 0, solo, edId)
            self.scoreCache029722["ia:solo"] = tonumber(score) or 0
        end
        if duo ~= nil and type(GetEndlessDungeonLeaderboardLocalPlayerInfo) == "function" then
            local _, score = safe(GetEndlessDungeonLeaderboardLocalPlayerInfo, 0, duo, edId)
            self.scoreCache029722["ia:duo"] = tonumber(score) or 0
        end
    end

    function T:CancelScoreQuery029722()
        EM:UnregisterForUpdate(EXP_NAME .. "_ScoreQuery")
        self.scoreQueue029722 = nil
        self.scoreQueueIndex029722 = nil
    end

    function T:StartScoreQuery029722(force)
        self:BuildRaidCatalog029722(false)
        if self.scoreQueryComplete029725 and not force then return end
        if self.scoreQueue029722 and not force then return end
        self:CancelScoreQuery029722()
        if force then self.scoreQueryComplete029725 = false end
        self.scoreCache029722 = self.scoreCache029722 or {}
        local queue = {}
        for _, entry in ipairs(self.trials029722 or {}) do queue[#queue+1] = {type="raid", entry=entry} end
        for _, entry in ipairs(self.arenas029722 or {}) do
            if entry.raidId ~= nil then queue[#queue+1] = {type="raid", entry=entry} end
        end
        queue[#queue+1] = {type="ia", groupType=rawget(_G,"ENDLESS_DUNGEON_GROUP_TYPE_SOLO"), key="ia:solo"}
        queue[#queue+1] = {type="ia", groupType=rawget(_G,"ENDLESS_DUNGEON_GROUP_TYPE_DUO"), key="ia:duo"}
        self.scoreQueue029722, self.scoreQueueIndex029722 = queue, 1

        EM:RegisterForUpdate(EXP_NAME .. "_ScoreQuery", 300, function()
            local index = tonumber(T.scoreQueueIndex029722) or 1
            local item = T.scoreQueue029722 and T.scoreQueue029722[index]
            if not item then
                T:CancelScoreQuery029722()
                T.scoreQueryComplete029725 = true
                T:UpdateScoreCache029722()
                if T.window and not T.window:IsHidden() then T:Render029715() end
                return
            end
            if item.type == "raid" and item.entry then
                local entry = item.entry
                local classId = 0
                if entry.category == raidCategoryChallenge and type(GetUnitClassId) == "function" then classId = tonumber(safe(GetUnitClassId, 0, "player")) or 0 end
                if type(QueryRaidLeaderboardData) == "function" then pcall(QueryRaidLeaderboardData, entry.category, entry.raidId, classId) end
                local _, best = safe(GetRaidLeaderboardLocalPlayerInfo, 0, entry.raidId)
                T.scoreCache029722["raid:"..entry.raidId] = tonumber(best) or 0
            elseif item.type == "ia" and item.groupType ~= nil then
                local edId = tonumber(rawget(_G, "DEFAULT_ENDLESS_DUNGEON_ID")) or 1
                local classId = 0
                if item.groupType == rawget(_G,"ENDLESS_DUNGEON_GROUP_TYPE_SOLO") and type(GetUnitClassId) == "function" then
                    classId = tonumber(safe(GetUnitClassId, 0, "player")) or 0
                end
                if type(QueryEndlessDungeonLeaderboardData) == "function" then pcall(QueryEndlessDungeonLeaderboardData, item.groupType, edId, classId) end
                if type(GetEndlessDungeonLeaderboardLocalPlayerInfo) == "function" then
                    local _, best = safe(GetEndlessDungeonLeaderboardLocalPlayerInfo, 0, item.groupType, edId)
                    T.scoreCache029722[item.key] = tonumber(best) or 0
                end
            end
            T.scoreQueueIndex029722 = index + 1
        end)
    end

    local function makeStateCell(parent, width)
        local c = WM:CreateControl(nil, parent, CT_CONTROL)
        c:SetDimensions(width, 30)
        c.textWidth029723 = tonumber(width) or 80

        -- Keep the clickable button textless. ESO button labels can render past
        -- their button bounds, which is what caused the overlapping columns.
        local b = makeButton(c, nil, "", function(control)
            local cell = control._cell029722
            if cell and cell.record then T:LinkAnyAchievement(cell.record) end
        end)
        b:SetAnchorFill(c)
        b._cell029722 = c

        local state = WM:CreateControl(nil, c, CT_BACKDROP)
        state:SetDimensions(14,14)
        state:SetAnchor(LEFT,c,LEFT,5,0)
        state:SetCenterColor(0,0,0,0)
        state:SetEdgeColor(0.78,0.48,0.16,0.92)
        state:SetEdgeTexture(nil,1,1,1)
        state:SetHidden(true)

        local check = WM:CreateControl(nil, c, CT_TEXTURE)
        check:SetTexture("EsoUI/Art/Miscellaneous/check_icon_32.dds")
        check:SetDimensions(16,16)
        check:SetAnchor(LEFT,c,LEFT,4,0)
        check:SetColor(0.28,0.95,0.35,1)
        check:SetHidden(true)

        local label = makeLabel(c, nil, "", "ZoFontGameSmall", {0.78,0.80,0.84,1})
        label:SetAnchor(LEFT,c,LEFT,23,0)
        label:SetDimensions(math.max(20,(tonumber(width) or 80)-28),30)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if label.SetMaxLineCount then pcall(label.SetMaxLineCount,label,2) end
        if label.SetWrapMode and rawget(_G,"TEXT_WRAP_MODE_ELLIPSIS") ~= nil then
            pcall(label.SetWrapMode,label,TEXT_WRAP_MODE_ELLIPSIS)
        end

        c.button, c.check, c.state, c.label = b, check, state, label
        b:SetHandler("OnMouseEnter", function(control)
            local cell = control._cell029722
            if cell then T:ShowAnyAchievementTooltip(control, cell.record, cell.context or "Achievement") end
        end)
        b:SetHandler("OnMouseExit", function() T:HideDetailPopup029725() end)
        return c
    end

    local function setStateCell(cell, record, context, showName)
        if not cell then return end
        cell.record, cell.context = record, context

        cell.check:SetHidden(true)
        cell.state:SetHidden(true)
        cell.check:SetAlpha(1)
        cell.state:SetAlpha(1)
        cell.check:SetDimensions(16,16)
        cell.state:SetDimensions(14,14)

        cell.label:ClearAnchors()
        local labelInset029743 = cell.allowWrap029743 and 20 or 23
        cell.label:SetAnchor(LEFT,cell,LEFT,labelInset029743,0)
        local cellH029741 = math.max(20,tonumber(cell:GetHeight()) or 30)
        cell.label:SetDimensions(math.max(20,(tonumber(cell.textWidth029723) or 80)-labelInset029743-4),cellH029741)
        cell.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        if cell.label.SetMaxLineCount then
            pcall(cell.label.SetMaxLineCount,cell.label,cell.allowWrap029743 and 2 or 1)
        end
        cell.label:SetText("")

        local function showNA029728(text)
            cell.check:SetHidden(true)
            cell.state:SetHidden(true)
            cell.check:SetAlpha(0)
            cell.state:SetAlpha(0)
            cell.check:SetDimensions(1,1)
            cell.state:SetDimensions(1,1)
            cell.label:ClearAnchors()
            cell.label:SetAnchorFill(cell)
            cell.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            cell.label:SetText(clean(text or "N/A"))
            cell.label:SetColor(0.56,0.58,0.64,1)
        end

        if not record then
            showNA029728("N/A")
            return
        end
        if record.notApplicable029727 then
            showNA029728(record.name or "N/A")
            return
        end

        local done = completion(record)
        local label = showName and clean(record.name) or ""
        if not cell.allowWrap029743 then
            local maxChars = math.max(6, math.floor(((tonumber(cell.textWidth029723) or 80) - 26) / 6.2))
            if #label > maxChars then
                label = label:sub(1, math.max(3, maxChars - 3)) .. "..."
            end
        end

        cell.check:ClearAnchors()
        cell.state:ClearAnchors()
        if label == "" then
            cell.check:SetAnchor(CENTER,cell,CENTER,0,0)
            cell.state:SetAnchor(CENTER,cell,CENTER,0,0)
        else
            cell.check:SetAnchor(LEFT,cell,LEFT,4,0)
            cell.state:SetAnchor(LEFT,cell,LEFT,5,0)
        end

        if done then
            cell.check:SetHidden(false)
            cell.label:SetColor(0.66,0.92,0.70,1)
        else
            cell.state:SetHidden(false)
            cell.label:SetColor(0.82,0.82,0.84,1)
        end
        cell.label:SetText(label)
    end

    local function createHeaderLabel(parent, text, x, width, align, y)
        local l = makeLabel(parent, nil, text, "ZoFontGameBold", {0.84,0.86,0.92,1})
        l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y or 0); l:SetDimensions(width,28)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER); l:SetHorizontalAlignment(align or TEXT_ALIGN_CENTER)
        return l
    end

    local function setVisible(view, visible)
        if view and view.root then view.root:SetHidden(not visible) end
    end

    function T:CreateExpandedViews029722(content, wanted)
        self.expViews029722 = self.expViews029722 or {}
        wanted = wanted or ((self:GetSV() and self:GetSV().expView) or "OVERVIEW")
        if self.expViews029722[wanted] then return end

        if wanted == "OVERVIEW" then
        local ov = { root=WM:CreateControl(nil, content, CT_CONTROL), leftRows={}, rightRows={} }
        ov.root:SetAnchorFill(content)
        local left = makeBackdrop(ov.root,nil,{0.012,0.017,0.026,0.90},{0.14,0.17,0.23,0.8})
        left:SetAnchor(TOPLEFT,ov.root,TOPLEFT,0,0); left:SetDimensions(560,716)
        local right = makeBackdrop(ov.root,nil,{0.012,0.017,0.026,0.90},{0.14,0.17,0.23,0.8})
        right:SetAnchor(TOPRIGHT,ov.root,TOPRIGHT,0,0); right:SetDimensions(620,716)
        local lh = makeLabel(left,nil,"TRIALS / ARENAS / INFINITE ARCHIVE","ZoFontGameBold",{0.86,0.88,0.94,1})
        lh:SetAnchor(TOPLEFT,left,TOPLEFT,12,6); lh:SetDimensions(530,26); lh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        createHeaderLabel(left,"ACTIVITY",8,246,TEXT_ALIGN_CENTER,34)
        createHeaderLabel(left,"BEST SCORE",258,88,TEXT_ALIGN_CENTER,34)
        createHeaderLabel(left,"TRIFECTA",350,194,TEXT_ALIGN_CENTER,34)
        -- 24 compact rows fit the complete current All Scores catalog:
        -- 16 Trials + ARENAS header + 4 Arenas + INFINITE ARCHIVE header + Solo/Duo.
        -- The previous 18-row pool is why only Dragonstar Arena was visible.
        for i=1,24 do
            local row=WM:CreateControl(nil,left,CT_CONTROL); row:SetAnchor(TOPLEFT,left,TOPLEFT,8,62+(i-1)*27); row:SetDimensions(544,27)
            local name=makeButton(row,nil,"",function(control)
                if control.dungeon then T:ShowDungeonContextMenu(control.dungeon,control) end
            end)
            name:SetAnchor(LEFT,row,LEFT,0,0); name:SetDimensions(246,27); name:SetHorizontalAlignment(TEXT_ALIGN_CENTER); name:SetFont("ZoFontGameSmall"); name:SetNormalFontColor(0.48,0.60,1,1)
            local score=makeLabel(row,nil,"","ZoFontGameSmall",{0.88,0.88,0.90,1}); score:SetAnchor(LEFT,row,LEFT,250,0); score:SetDimensions(88,27); score:SetHorizontalAlignment(TEXT_ALIGN_CENTER); score:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            local tri=makeStateCell(row,198); tri:SetDimensions(198,27); tri:SetAnchor(LEFT,row,LEFT,342,0); tri.allowWrap029743=true
            ov.leftRows[i]={control=row,name=name,score=score,tri=tri}
        end
        local rh=makeLabel(right,nil,"4-MAN TRIFECTAS","ZoFontGameBold",{0.86,0.88,0.94,1}); rh:SetAnchor(TOPLEFT,right,TOPLEFT,12,6); rh:SetDimensions(590,26); rh:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        createHeaderLabel(right,"DUNGEON",8,280,TEXT_ALIGN_CENTER,34)
        createHeaderLabel(right,"TRIFECTA",292,312,TEXT_ALIGN_CENTER,34)
        for i=1,18 do
            local row=WM:CreateControl(nil,right,CT_CONTROL); row:SetAnchor(TOPLEFT,right,TOPLEFT,8,62+(i-1)*31); row:SetDimensions(604,30)
            local name=makeButton(row,nil,"",function(control) if control.dungeon then T:ShowDungeonContextMenu(control.dungeon,control) end end)
            name:SetAnchor(LEFT,row,LEFT,0,0); name:SetDimensions(280,30); name:SetHorizontalAlignment(TEXT_ALIGN_CENTER); name:SetFont("ZoFontGameSmall"); name:SetNormalFontColor(0.48,0.60,1,1)
            local tri=makeStateCell(row,312); tri:SetAnchor(LEFT,row,LEFT,284,0)
            ov.rightRows[i]={control=row,name=name,tri=tri}
        end
        self.expViews029722.OVERVIEW=ov

        elseif wanted == "TRIALS" then
        local tv={root=WM:CreateControl(nil,content,CT_CONTROL),rows={}}; tv.root:SetAnchorFill(content); tv.root:SetHidden(true)
        local th=makeBackdrop(tv.root,nil,{0.030,0.040,0.056,0.98},{0.18,0.22,0.30,0.8}); th:SetAnchor(TOPLEFT,tv.root,TOPLEFT,0,0); th:SetAnchor(TOPRIGHT,tv.root,TOPRIGHT,0,0); th:SetHeight(34)
        local cols={{"TRIAL",8,206,TEXT_ALIGN_CENTER},{"BEST SCORE",218,96,TEXT_ALIGN_CENTER},{"VET",318,50,TEXT_ALIGN_CENTER},{"PARTIAL HM",372,136,TEXT_ALIGN_CENTER},{"PARTIAL HM",512,136,TEXT_ALIGN_CENTER},{"HARDMODE",652,142,TEXT_ALIGN_CENTER},{"TRIFECTA",798,180,TEXT_ALIGN_CENTER},{"EXTRA",982,218,TEXT_ALIGN_CENTER}}
        for _,c in ipairs(cols) do createHeaderLabel(th,c[1],c[2],c[3],c[4]) end
        for i=1,20 do
            local row=WM:CreateControl(nil,tv.root,CT_CONTROL); row:SetAnchor(TOPLEFT,th,BOTTOMLEFT,0,4+(i-1)*33); row:SetAnchor(TOPRIGHT,th,BOTTOMRIGHT,0,4+(i-1)*33); row:SetHeight(31)
            local name=makeLabel(row,nil,"","ZoFontGameSmall",{0.48,0.60,1,1}); name:SetAnchor(LEFT,row,LEFT,8,0); name:SetDimensions(206,30); name:SetVerticalAlignment(TEXT_ALIGN_CENTER); name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            local score=makeLabel(row,nil,"","ZoFontGameSmall",{0.88,0.88,0.90,1}); score:SetAnchor(LEFT,row,LEFT,218,0); score:SetDimensions(96,30); score:SetHorizontalAlignment(TEXT_ALIGN_CENTER); score:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            local cells={}
            local defs={{"VET",318,50,false},{"PART1",372,136,true},{"PART2",512,136,true},{"HM",652,142,true},{"TRI",798,180,true},{"EXTRA",982,218,true}}
            for _,d in ipairs(defs) do local c=makeStateCell(row,d[3]); c:SetAnchor(LEFT,row,LEFT,d[2],0); cells[d[1]]=c end
            tv.rows[i]={control=row,name=name,score=score,cells=cells}
        end
        self.expViews029722.TRIALS=tv

        elseif wanted == "TRIFECTAS" then
        local fv={root=WM:CreateControl(nil,content,CT_CONTROL),rows={}}; fv.root:SetAnchorFill(content); fv.root:SetHidden(true)
        local fh=makeBackdrop(fv.root,nil,{0.030,0.040,0.056,0.98},{0.18,0.22,0.30,0.8}); fh:SetAnchor(TOPLEFT,fv.root,TOPLEFT,0,0); fh:SetAnchor(TOPRIGHT,fv.root,TOPRIGHT,0,0); fh:SetHeight(34)
        local fcols={{"TRIFECTA DUNGEONS",8,300,TEXT_ALIGN_CENTER},{"VET",312,48,TEXT_ALIGN_CENTER},{"HM",364,48,TEXT_ALIGN_CENTER},{"SR",416,48,TEXT_ALIGN_CENTER},{"ND",468,48,TEXT_ALIGN_CENTER},{"CHALLENGER & TRIFECTA",520,390,TEXT_ALIGN_CENTER},{"EXTRAS",914,286,TEXT_ALIGN_CENTER}}
        for _,c in ipairs(fcols) do createHeaderLabel(fh,c[1],c[2],c[3],c[4]) end
        for i=1,20 do
            local row=WM:CreateControl(nil,fv.root,CT_CONTROL); row:SetAnchor(TOPLEFT,fh,BOTTOMLEFT,0,4+(i-1)*33); row:SetAnchor(TOPRIGHT,fh,BOTTOMRIGHT,0,4+(i-1)*33); row:SetHeight(31)
            local name=makeButton(row,nil,"",function(control) if control.dungeon then T:ShowDungeonContextMenu(control.dungeon,control) end end)
            name:SetAnchor(LEFT,row,LEFT,8,0); name:SetDimensions(300,30); name:SetHorizontalAlignment(TEXT_ALIGN_CENTER); name:SetFont("ZoFontGameSmall"); name:SetNormalFontColor(0.48,0.60,1,1)
            local cells={}
            for idx,key in ipairs({"VET","HM","SP","ND"}) do local c=makeStateCell(row,48); c:SetAnchor(LEFT,row,LEFT,310+((idx-1)*52),0); cells[key]=c end
            local tri=makeStateCell(row,390); tri:SetAnchor(LEFT,row,LEFT,518,0); cells.TRI=tri
            local extra=makeStateCell(row,286); extra:SetAnchor(LEFT,row,LEFT,912,0); cells.EXTRA=extra
            fv.rows[i]={control=row,name=name,cells=cells}
        end
        self.expViews029722.TRIFECTAS=fv

        elseif wanted == "STARTER" then
        local sv={root=WM:CreateControl(nil,content,CT_CONTROL),leftRows={},rightRows={}}; sv.root:SetAnchorFill(content); sv.root:SetHidden(true)
        local function starterPanel(parent,x,title)
            local p=makeBackdrop(parent,nil,{0.012,0.017,0.026,0.90},{0.14,0.17,0.23,0.8}); p:SetAnchor(TOPLEFT,parent,TOPLEFT,x,0); p:SetDimensions(592,716)
            local tt=makeLabel(p,nil,title,"ZoFontGameBold",{0.86,0.88,0.94,1}); tt:SetAnchor(TOPLEFT,p,TOPLEFT,12,6); tt:SetDimensions(568,26); tt:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            local heads={{"VET",376},{"HM",424},{"SR",472},{"ND",520}}
            for _,h in ipairs(heads) do createHeaderLabel(p,h[1],h[2],44,TEXT_ALIGN_CENTER,34) end
            createHeaderLabel(p,"DUNGEONS",8,360,TEXT_ALIGN_CENTER,34)
            return p
        end
        local lp=starterPanel(sv.root,0,"Dungeons with I/II")
        local rp=starterPanel(sv.root,604,"Dungeons / Base Game")
        local function makeStarterRows(panel,target)
            for i=1,20 do
                local row=WM:CreateControl(nil,panel,CT_CONTROL); row:SetAnchor(TOPLEFT,panel,TOPLEFT,8,62+(i-1)*31); row:SetDimensions(576,30)
                local name=makeButton(row,nil,"",function(control) if control.dungeon then T:ShowDungeonContextMenu(control.dungeon,control) end end)
                name:SetAnchor(LEFT,row,LEFT,0,0); name:SetDimensions(360,30); name:SetHorizontalAlignment(TEXT_ALIGN_CENTER); name:SetFont("ZoFontGameSmall"); name:SetNormalFontColor(0.48,0.60,1,1)
                local cells={}
                for idx,key in ipairs({"VET","HM","SP","ND"}) do local c=makeStateCell(row,44); c:SetAnchor(LEFT,row,LEFT,368+((idx-1)*48),0); cells[key]=c end
                target[i]={control=row,name=name,cells=cells}
            end
        end
        makeStarterRows(lp,sv.leftRows); makeStarterRows(rp,sv.rightRows)
        self.expViews029722.STARTER=sv
        end
    end

    CreateWindowImplArch = function(self)
        if self.window then return self.window end
        local s=self:GetSV()
        local w=WM:CreateTopLevelWindow("EAS_MasterAchievementTracker029722")
        w:SetDimensions(1320,880); w:SetClampedToScreen(true); w:SetMouseEnabled(true); w:SetMovable(true); w:SetDrawLayer(DL_OVERLAY)
        if w.SetDrawTier and DT_HIGH then w:SetDrawTier(DT_HIGH) end
        if w.SetTopLevel then w:SetTopLevel(true) end
        local nativeMenuLevel=tonumber(rawget(_G,"ZO_HIGH_TIER_KEYBOARD_COMBO_BOX_DROPDOWN")) or 140
        w:SetDrawLevel(nativeMenuLevel + 3000)
        w:SetHidden(true)
        if s and tonumber(s.left) and tonumber(s.left)>=0 and tonumber(s.top) and tonumber(s.top)>=0 then w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,tonumber(s.left),tonumber(s.top)) else w:SetAnchor(CENTER,GuiRoot,CENTER,0,0) end
        w:SetHandler("OnMoveStop",function(control) local sv=T:GetSV(); if sv then sv.left,sv.top=control:GetLeft(),control:GetTop() end end)
        local bg=makeBackdrop(w,nil,{0.008,0.012,0.020,0.985},{0.64,0.47,0.12,0.95}); bg:SetAnchorFill(w); bg:SetMouseEnabled(false)

        local nav=makeBackdrop(w,nil,{0.012,0.017,0.026,0.99},{0.28,0.24,0.13,0.95}); nav:SetAnchor(TOPLEFT,w,TOPLEFT,0,0); nav:SetDimensions(78,880)
        self.expNavButtons029722={}
        local navShort={OVERVIEW="ALL",TRIALS="TRIAL",TRIFECTAS="4 MAN",STARTER="START"}
        for i,key in ipairs(PAGE_ORDER) do
            local b=makeButton(nav,nil,navShort[key],function() local sv=T:GetSV(); if sv then sv.expView=key end; T:Render029715() end)
            b:SetDimensions(70,72); b:SetAnchor(TOPLEFT,nav,TOPLEFT,4,18+((i-1)*78)); b:SetFont("ZoFontGameBold")
            self.expNavButtons029722[key]=b
        end

        local header=makeBackdrop(w,nil,{0.018,0.025,0.038,0.99},{0,0,0,0}); header:SetAnchor(TOPLEFT,w,TOPLEFT,78,0); header:SetAnchor(TOPRIGHT,w,TOPRIGHT,0,0); header:SetHeight(70); header:SetMouseEnabled(true)
        header:SetHandler("OnMouseDown",function(_,button) if button==MOUSE_BUTTON_INDEX_LEFT then w:StartMoving() end end); header:SetHandler("OnMouseUp",function(_,button) if button==MOUSE_BUTTON_INDEX_LEFT then w:StopMovingOrResizing() end end)
        self.expTitle029722=makeLabel(header,nil,"Master Achievement Tracker","ZoFontWinH1",{1,1,1,1}); self.expTitle029722:SetAnchor(TOPLEFT,header,TOPLEFT,20,9); self.expTitle029722:SetDimensions(1010,34); self.expTitle029722:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        self.expSub029722=makeLabel(header,nil,"Live ESO achievements + leaderboard best scores","ZoFontGame",{0.70,0.74,0.82,1}); self.expSub029722:SetAnchor(TOPLEFT,header,TOPLEFT,20,41); self.expSub029722:SetDimensions(1010,24); self.expSub029722:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        local close=makeButton(header,nil,"X",function() T:Hide() end); close:SetDimensions(44,44); close:SetAnchor(TOPRIGHT,header,TOPRIGHT,-12,13); close:SetFont("ZoFontWinH2")
        local refresh=makeButton(header,nil,"REFRESH",function() T:CancelRaidAchievementBuild029722(); T:StartDeferredBuild029715(true); T.raidAchievementBuilt029722=false; T:StartScoreQuery029722(true); T:Render029715() end); refresh:SetDimensions(110,34); refresh:SetAnchor(RIGHT,close,LEFT,-8,0)

        local content=WM:CreateControl(nil,w,CT_CONTROL); content:SetAnchor(TOPLEFT,header,BOTTOMLEFT,14,10); content:SetAnchor(BOTTOMRIGHT,w,BOTTOMRIGHT,-14,-72)
        self.expContent029722=content
        self:CreateExpandedViews029722(content, (s and s.expView) or "OVERVIEW")

        local footer=WM:CreateControl(nil,w,CT_CONTROL); footer:SetAnchor(BOTTOMLEFT,w,BOTTOMLEFT,92,-12); footer:SetAnchor(BOTTOMRIGHT,w,BOTTOMRIGHT,-14,-12); footer:SetHeight(48)
        self.expPrev029722=makeButton(footer,nil,"< PREV",function() T:PageExpanded029722(-1) end); self.expPrev029722:SetDimensions(110,34); self.expPrev029722:SetAnchor(LEFT,footer,LEFT,0,0)
        self.expPage029722=makeLabel(footer,nil,"","ZoFontGameBold",{0.78,0.80,0.86,1}); self.expPage029722:SetAnchor(LEFT,self.expPrev029722,RIGHT,10,0); self.expPage029722:SetDimensions(150,34); self.expPage029722:SetHorizontalAlignment(TEXT_ALIGN_CENTER); self.expPage029722:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.expNext029722=makeButton(footer,nil,"NEXT >",function() T:PageExpanded029722(1) end); self.expNext029722:SetDimensions(110,34); self.expNext029722:SetAnchor(LEFT,self.expPage029722,RIGHT,10,0)
        self.summary=makeLabel(footer,nil,"","ZoFontGameSmall",{0.68,0.72,0.80,1}); self.summary:SetAnchor(LEFT,self.expNext029722,RIGHT,20,0); self.summary:SetDimensions(780,34); self.summary:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        self.window=w
        return w
    end

    function T:GetTrifectaDungeons029722()
        local out={}
        for _,d in ipairs(self.dungeons or {}) do
            local tri=d.extAchievement029722 and d.extAchievement029722.TRI
            if tri then out[#out+1]=d end
        end
        table.sort(out,function(a,b)
            if a.isDLC ~= b.isDLC then return a.isDLC and not b.isDLC end
            return lower(a.name)<lower(b.name)
        end)
        return out
    end

    function T:GetStarterDungeons029722()
        local out={}
        for _,d in ipairs(self.dungeons or {}) do if not d.isDLC then out[#out+1]=d end end
        table.sort(out,function(a,b)return lower(a.name)<lower(b.name) end)
        return out
    end

    function T:PageExpanded029722(delta)
        local s=self:GetSV(); if not s then return end
        local view=s.expView or "OVERVIEW"
        if view=="OVERVIEW" then s.expOverviewTriPage=math.max(1,(tonumber(s.expOverviewTriPage) or 1)+delta)
        elseif view=="TRIFECTAS" then s.expTriPage=math.max(1,(tonumber(s.expTriPage) or 1)+delta)
        elseif view=="STARTER" then s.expStarterPage=math.max(1,(tonumber(s.expStarterPage) or 1)+delta) end
        self:Render029715()
    end

    function T:RenderOverview029722(view)
        local scoreCache=self.scoreCache029722 or {}
        local leftItems={}
        for _,e in ipairs(self.trials029722 or {}) do leftItems[#leftItems+1]={kind="ENTRY",entry=e} end
        leftItems[#leftItems+1]={kind="HEADER",name="ARENAS"}
        for _,e in ipairs(self.arenas029722 or {}) do leftItems[#leftItems+1]={kind="ENTRY",entry=e} end
        leftItems[#leftItems+1]={kind="HEADER",name="INFINITE ARCHIVE"}
        leftItems[#leftItems+1]={kind="IA",name="Solo",key="ia:solo"}; leftItems[#leftItems+1]={kind="IA",name="Duo",key="ia:duo"}
        for i,row in ipairs(view.leftRows) do
            local item=leftItems[i]
            if not item then row.control:SetHidden(true)
            else
                row.control:SetHidden(false); row.name.dungeon=nil; row.tri.record=nil
                if item.kind=="HEADER" then
                    row.name:SetText("|cFFD26A"..item.name.."|r")
                    row.score:SetText("")
                    row.tri.record=nil
                    row.tri.check:SetHidden(true); row.tri.state:SetHidden(true); row.tri.label:SetText("")
                elseif item.kind=="IA" then
                    row.name:SetText(item.name)
                    row.score:SetText(fmtScore(scoreCache[item.key] or 0))
                    row.tri.record=nil
                    row.tri.check:SetHidden(true); row.tri.state:SetHidden(true); row.tri.label:SetText("")
                else
                    local e=item.entry
                    row.name:SetText(e.kind=="ARENA" and canonicalArenaDisplayName029743(e.name) or e.name)
                    local scoreKey=e.raidId and ("raid:"..tostring(e.raidId)) or nil
                    row.score:SetText(fmtScore(scoreKey and scoreCache[scoreKey] or 0))
                    setStateCell(row.tri,e.achievement and e.achievement.TRI,e.name.." Trifecta",true)
                end
            end
        end

        local tris=self:GetTrifectaDungeons029722(); local s=self:GetSV(); local per=#view.rightRows; local pages=math.max(1,math.ceil(#tris/per)); s.expOverviewTriPage=math.max(1,math.min(pages,tonumber(s.expOverviewTriPage) or 1)); local first=((s.expOverviewTriPage-1)*per)+1
        for i,row in ipairs(view.rightRows) do local d=tris[first+i-1]; if not d then row.control:SetHidden(true) else row.control:SetHidden(false); row.name.dungeon=d; row.name:SetText(d.name); setStateCell(row.tri,d.extAchievement029722 and d.extAchievement029722.TRI,d.name.." Trifecta",true) end end
        self.expPage029722:SetText(string.format("4-MAN %d / %d",s.expOverviewTriPage,pages)); self.expPrev029722:SetEnabled(s.expOverviewTriPage>1); self.expNext029722:SetEnabled(s.expOverviewTriPage<pages)
    end

    function T:RenderTrials029722(view)
        local scores=self.scoreCache029722 or {}
        for i,row in ipairs(view.rows) do local e=(self.trials029722 or {})[i]; if not e then row.control:SetHidden(true) else row.control:SetHidden(false); row.name:SetText(e.name); row.score:SetText(fmtScore(scores["raid:"..e.raidId] or 0)); for _,key in ipairs(RAID_KEYS) do setStateCell(row.cells[key],e.achievement and e.achievement[key],e.name.." "..key,key~="VET") end end end
        self.expPage029722:SetText(string.format("%d TRIALS",#(self.trials029722 or {}))); self.expPrev029722:SetEnabled(false); self.expNext029722:SetEnabled(false)
    end

    function T:RenderTrifectas029722(view)
        local list=self:GetTrifectaDungeons029722(); local s=self:GetSV(); local per=#view.rows; local pages=math.max(1,math.ceil(#list/per)); s.expTriPage=math.max(1,math.min(pages,tonumber(s.expTriPage) or 1)); local first=((s.expTriPage-1)*per)+1
        for i,row in ipairs(view.rows) do local d=list[first+i-1]; if not d then row.control:SetHidden(true) else row.control:SetHidden(false); row.name.dungeon=d; row.name:SetText(d.name); for _,key in ipairs({"VET","HM","SP","ND"}) do setStateCell(row.cells[key],d.achievement and d.achievement[key],d.name.." "..STATUS_LONG[key],false) end; setStateCell(row.cells.TRI,d.extAchievement029722 and d.extAchievement029722.TRI,d.name.." Trifecta",true); setStateCell(row.cells.EXTRA,d.extAchievement029722 and d.extAchievement029722.EXTRA,d.name.." Extra",true) end end
        self.expPage029722:SetText(string.format("PAGE %d / %d",s.expTriPage,pages)); self.expPrev029722:SetEnabled(s.expTriPage>1); self.expNext029722:SetEnabled(s.expTriPage<pages)
    end

    function T:RenderStarter029722(view)
        local list=self:GetStarterDungeons029722(); local s=self:GetSV(); local perSide=#view.leftRows; local perPage=perSide*2; local pages=math.max(1,math.ceil(#list/perPage)); s.expStarterPage=math.max(1,math.min(pages,tonumber(s.expStarterPage) or 1)); local first=((s.expStarterPage-1)*perPage)+1
        local function fill(rows,offset) for i,row in ipairs(rows) do local d=list[first+offset+i-1]; if not d then row.control:SetHidden(true) else row.control:SetHidden(false); row.name.dungeon=d; row.name:SetText(d.name); for _,key in ipairs({"VET","HM","SP","ND"}) do setStateCell(row.cells[key],d.achievement and d.achievement[key],d.name.." "..STATUS_LONG[key],false) end end end end
        fill(view.leftRows,0); fill(view.rightRows,perSide)
        self.expPage029722:SetText(string.format("PAGE %d / %d",s.expStarterPage,pages)); self.expPrev029722:SetEnabled(s.expStarterPage>1); self.expNext029722:SetEnabled(s.expStarterPage<pages)
    end

    Render029715ImplArch = function(self)
        self:CreateWindow(); self:BuildDungeonCatalog(false); self:BuildRaidCatalog029722(false)
        local s=self:GetSV(); if not s then return end
        if self.achievementMappingBuilt then self:RefreshCompletionState(); self:BuildDungeonExtendedAchievements029722(false) end
        if self.achievementMappingBuilt and not self.raidAchievementBuilt029722 and not self.raidAchievementRunning029722 then self:StartRaidAchievementBuild029722(false) end
        if self.raidAchievementBuilt029722 then
            for _,entry in ipairs(self.trials029722 or {}) do for _,r in pairs(entry.achievement or {}) do completion(r) end end
            for _,entry in ipairs(self.arenas029722 or {}) do for _,r in pairs(entry.achievement or {}) do completion(r) end end
        end
        local view=s.expView or "OVERVIEW"
        self:CreateExpandedViews029722(self.expContent029722, view)
        if not self.expViews029722[view] then
            view="OVERVIEW"
            s.expView=view
            self:CreateExpandedViews029722(self.expContent029722, view)
        end
        for key,v in pairs(self.expViews029722 or {}) do setVisible(v,key==view) end
        for key,b in pairs(self.expNavButtons029722 or {}) do local active=key==view; b:SetNormalFontColor(active and 1 or 0.68,active and 0.82 or 0.72,active and 0.24 or 0.80,1) end
        self.expTitle029722:SetText("Master Achievement Tracker  |c566DFF"..PAGE_LABELS[view].."|r")
        if view=="OVERVIEW" then self:RenderOverview029722(self.expViews029722.OVERVIEW)
        elseif view=="TRIALS" then self:RenderTrials029722(self.expViews029722.TRIALS)
        elseif view=="TRIFECTAS" then self:RenderTrifectas029722(self.expViews029722.TRIFECTAS)
        else self:RenderStarter029722(self.expViews029722.STARTER) end
        if not self.achievementMappingBuilt then local p=tonumber(self.deferredBuildProgress029715) or 0; self.summary:SetText(string.format("Loading dungeon achievements • %d%% • %s",p,tostring(self.deferredBuildPhase029715 or "Preparing")))
        elseif not self.raidAchievementBuilt029722 then local p=tonumber(self.raidAchievementProgress029722) or 0; self.summary:SetText(string.format("Dungeon achievements ready • Trial/Arena scan %d%% • %s",p,tostring(self.raidAchievementPhase029722 or "Preparing")))
        else self.summary:SetText(string.format("%d trials • %d arenas • %d 4-man trifectas • live ESO achievement state + available leaderboard scores",#(self.trials029722 or {}),#(self.arenas029722 or {}),#self:GetTrifectaDungeons029722())) end
    end

    RefreshImplArch = function(self)
        if self.achievementMappingBuilt then self:RefreshCompletionState(); self:BuildDungeonExtendedAchievements029722(false) else self:StartDeferredBuild029715(false) end
        if self.achievementMappingBuilt then self:StartRaidAchievementBuild029722(false) end
        self:UpdateScoreCache029722(); self:Render029715()
    end

    function T:IsMenuSceneSuppressed029724()
        return EPC and type(EPC.IsGameplayHudSuppressed) == "function"
            and EPC:IsGameplayHudSuppressed() == true
    end

    function T:PauseHiddenWork029724()
        if self.deferredBuildRunning029715 then self:CancelDeferredBuild029715() end
        if self.raidAchievementRunning029722 then self:CancelRaidAchievementBuild029722() end
        self:CancelScoreQuery029722()
        T:HideDetailPopup029725()
    end

    function T:ApplySceneVisibility029724()
        self:CreateWindow()
        local suppressed = self:IsMenuSceneSuppressed029724()
        if suppressed then
            if self.window and not self.window:IsHidden() then
                self.window:SetHidden(true)
            end
            self.sceneSuspended029724 = self.desiredVisible029724 == true
            self:PauseHiddenWork029724()
            return
        end

        if self.desiredVisible029724 == true then
            self.sceneSuspended029724 = false
            self.window:SetHidden(false)
            if self.window.SetDrawLayer and DL_OVERLAY then self.window:SetDrawLayer(DL_OVERLAY) end
            if self.window.SetDrawTier and DT_HIGH then self.window:SetDrawTier(DT_HIGH) end
            if self.window.SetTopLevel then self.window:SetTopLevel(true) end
            if self.window.SetDrawLevel then
                local menuLevel029746=tonumber(rawget(_G,"ZO_HIGH_TIER_KEYBOARD_COMBO_BOX_DROPDOWN")) or 140
                self.window:SetDrawLevel(menuLevel029746 + 3000)
            end
            if self.window.BringWindowToTop then self.window:BringWindowToTop() end
            self:Render029715()

            local function stillVisible029725()
                return T and T.desiredVisible029724 == true
                    and T.window and not T.window:IsHidden()
                    and not T:IsMenuSceneSuppressed029724()
            end

            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if stillVisible029725() then T:StartDeferredBuild029715(false) end
                end, 120)
                zo_callLater(function()
                    if stillVisible029725() then T:StartScoreQuery029722(false) end
                end, 500)
            else
                self:StartDeferredBuild029715(false)
                self:StartScoreQuery029722(false)
            end
        else
            self.sceneSuspended029724 = false
            self.window:SetHidden(true)
        end
    end

    ShowImplArch = function(self)
        self.desiredVisible029724 = true
        self:CreateWindow()
        if EPC and type(EPC.AcquireSuiteCursor029733) == "function" then
            EPC:AcquireSuiteCursor029733("MasterAchievementTracker")
        end
        self:ApplySceneVisibility029724()
    end

    HideImplArch = function(self)
        self.desiredVisible029724 = false
        self.sceneSuspended029724 = false
        if self.window then self.window:SetHidden(true) end
        self:PauseHiddenWork029724()
        if EPC and type(EPC.ReleaseSuiteCursor029733) == "function" then
            EPC:ReleaseSuiteCursor029733("MasterAchievementTracker")
        end
    end

    ToggleImplArch = function(self)
        self:CreateWindow()
        if self.desiredVisible029724 == true then self:Hide() else self:Show() end
    end

    InitializeImplArch = function(self)
        baseInitialize(self)
        self.desiredVisible029724 = false
        self.sceneSuspended029724 = false
        self:BuildRaidCatalog029722(false)
        if rawget(_G,"EVENT_RAID_LEADERBOARD_DATA_CHANGED") ~= nil then
            EM:RegisterForEvent(EXP_NAME.."_RaidScores",EVENT_RAID_LEADERBOARD_DATA_CHANGED,function() T:UpdateScoreCache029722(); if T.window and not T.window:IsHidden() then T:Render029715() end end)
        end
        if rawget(_G,"EVENT_ENDLESS_DUNGEON_LEADERBOARD_DATA_CHANGED") ~= nil then
            EM:RegisterForEvent(EXP_NAME.."_IAScores",EVENT_ENDLESS_DUNGEON_LEADERBOARD_DATA_CHANGED,function() T:UpdateScoreCache029722(); if T.window and not T.window:IsHidden() then T:Render029715() end end)
        end
        if rawget(_G,"EVENT_RAID_TRIAL_NEW_BEST_SCORE") ~= nil then
            EM:RegisterForEvent(EXP_NAME.."_NewBest",EVENT_RAID_TRIAL_NEW_BEST_SCORE,function() T:StartScoreQuery029722(true) end)
        end

        -- The tracker is an interactive Suite window, not part of ESO's native
        -- Inventory/Character/Bank/etc. scenes. Temporarily hide it while any
        -- real menu scene is active, then restore it only if the user had it open.
        if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function"
            and not self.sceneVisibilityHook029724 then
            self.sceneVisibilityHook029724 = true
            SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
                if not T or T.desiredVisible029724 ~= true then return end
                T:ApplySceneVisibility029724()
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if T and T.desiredVisible029724 == true then T:ApplySceneVisibility029724() end
                    end, 60)
                end
            end)
        end

        if rawget(_G,"EVENT_PLAYER_ACTIVATED") ~= nil then
            EM:RegisterForEvent(EXP_NAME.."_SceneActivated029724",EVENT_PLAYER_ACTIVATED,function()
                if T and T.desiredVisible029724 == true then T:ApplySceneVisibility029724() end
            end)
        end
    end
end
