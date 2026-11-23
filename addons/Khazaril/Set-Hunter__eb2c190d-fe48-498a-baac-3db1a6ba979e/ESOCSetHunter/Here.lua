-- Set Hunter "Needed here": the Sticker Book pieces you're missing from the zone, dungeon or trial you're in.
-- The game has no link from a zone to its sets, so this matches your location to the Sticker Book's category names.

local SH = ESOC_SetHunter
local H = {}
SH.Here = H

local MAX_SETS = 10
local GROUP_ORDER = { "Light", "Medium", "Heavy", "Armor", "Weapons", "Jewelry" }
local WEIGHT_GROUP = {}
if ARMORTYPE_LIGHT then WEIGHT_GROUP[ARMORTYPE_LIGHT] = "Light" end
if ARMORTYPE_MEDIUM then WEIGHT_GROUP[ARMORTYPE_MEDIUM] = "Medium" end
if ARMORTYPE_HEAVY then WEIGHT_GROUP[ARMORTYPE_HEAVY] = "Heavy" end

-- Zones whose sets the Sticker Book may list under their chapter or DLC name.
local CHAPTER_NAMES = {
    ["vvardenfell"] = { "morrowind" },
    ["wrothgar"] = { "orsinium" },
    ["hews bane"] = { "thieves guild" },
    ["gold coast"] = { "dark brotherhood" },
    ["northern elsweyr"] = { "elsweyr" },
    ["southern elsweyr"] = { "dragonhold" },
    ["western skyrim"] = { "greymoor" },
    ["blackreach greymoor caverns"] = { "greymoor" },
    ["reach"] = { "markarth" },
    ["blackreach arkthzand cavern"] = { "markarth" },
    ["telvanni peninsula"] = { "necrom" },
    ["apocrypha"] = { "necrom" },
    ["west weald"] = { "gold road" },
    ["galen"] = { "firesong" },
    ["amenos"] = { "high isle" },
}

-- The Infinite Archive's class sets (UESP, Online:Infinite Archive), so it works whatever its Sticker Book category is called.
local ARCHIVE_SET_NAMES = {
    "Aerie's Cry", "Aetheric Lancer", "Basalt-Blooded Warrior", "Beacon of Oblivion", "Corpseburster",
    "Gardener of Seasons", "Monolith of Storms", "Nobility in Decay", "Pyrebrand", "Reawakened Hierophant",
    "Soulcleaver", "Spattering Disjunction", "Umbral Edge", "Wrathsun",
}
local ARCHIVE_CATEGORIES = { "infinite archive", "endless archive" }

local setsByName, cachedZone, cachedName, cachedIds
local archiveNames, archiveSetIds
local shapes = {}

-- "The Banished Cells II" and "Banished Cells" both become "banished cells".
local function norm(name)
    local key = string.lower(zo_strformat("<<1>>", name or ""))
    key = string.gsub(key, "[^%a%d ]", "")
    key = string.gsub(key, "%s+", " ")
    key = string.gsub(key, "^%s*(.-)%s*$", "%1")
    key = string.gsub(key, "^the ", "")
    key = string.gsub(key, " ii$", "")
    key = string.gsub(key, " i$", "")
    return key
end

local function buildIndex()
    setsByName, archiveSetIds = {}, {}
    if not archiveNames then
        archiveNames = {}
        for _, name in ipairs(ARCHIVE_SET_NAMES) do archiveNames[norm(name)] = true end
    end
    local setId = GetNextItemSetCollectionId()
    while setId do
        if archiveNames[norm(GetItemSetName(setId))] then archiveSetIds[#archiveSetIds + 1] = setId end
        local categoryId = GetItemSetCollectionCategoryId(setId)
        if categoryId and categoryId ~= 0 then
            local key = norm(GetItemSetCollectionCategoryName(categoryId))
            if key ~= "" then
                setsByName[key] = setsByName[key] or {}
                table.insert(setsByName[key], setId)
            end
        end
        setId = GetNextItemSetCollectionId(setId)
    end
end

local function lookup(name)
    -- The Sticker Book may not be ready at login, so an empty index is built again next time
    if not setsByName or next(setsByName) == nil then buildIndex() end
    local key = norm(name)
    local ids, seen = {}, {}
    local function add(list)
        for _, setId in ipairs(list or {}) do
            if not seen[setId] then
                seen[setId] = true
                ids[#ids + 1] = setId
            end
        end
    end
    add(setsByName[key])
    for _, chapter in ipairs(CHAPTER_NAMES[key] or {}) do add(setsByName[chapter]) end
    return ids
end

-- Your zone's sets. In a delve or public dungeon, that's the surrounding zone.
-- A group dungeon or trial never falls back, so it can't show the overland zone outside it.
function H.InArchive()
    return IsInstanceEndlessDungeon ~= nil and IsInstanceEndlessDungeon() == true
end

function H.ArchiveIds()
    if not setsByName or next(setsByName) == nil then buildIndex() end
    local ids, seen = {}, {}
    local function add(list)
        for _, setId in ipairs(list or {}) do
            if not seen[setId] then
                seen[setId] = true
                ids[#ids + 1] = setId
            end
        end
    end
    add(archiveSetIds)
    for _, key in ipairs(ARCHIVE_CATEGORIES) do add(setsByName[key]) end
    table.sort(ids, function(a, b) return GetItemSetName(a) < GetItemSetName(b) end)
    return ids
end

-- Normal instances drop the normal version of a set, veteran ones the perfected version.
-- Sets with no perfected version always stay.
function H.ForDifficulty(ids)
    if not GetItemSetUnperfectedSetId then return ids end
    local difficulty = GetCurrentZoneDungeonDifficulty()
    -- In case a trial doesn't report its difficulty as a dungeon does
    if difficulty == DUNGEON_DIFFICULTY_NONE and IsPlayerInRaid and IsPlayerInRaid() then
        difficulty = IsUnitUsingVeteranDifficulty("player") and DUNGEON_DIFFICULTY_VETERAN or DUNGEON_DIFFICULTY_NORMAL
    end
    local veteran = difficulty == DUNGEON_DIFFICULTY_VETERAN
    if not veteran and difficulty ~= DUNGEON_DIFFICULTY_NORMAL then return ids end
    local hasPerfected = {}
    for _, setId in ipairs(ids) do
        local normalId = GetItemSetUnperfectedSetId(setId)
        if normalId and normalId > 0 then hasPerfected[normalId] = true end
    end
    local kept = {}
    for _, setId in ipairs(ids) do
        local normalId = GetItemSetUnperfectedSetId(setId)
        local isPerfected = normalId ~= nil and normalId > 0
        local keep
        if veteran then keep = not hasPerfected[setId] else keep = not isPerfected end
        if keep then kept[#kept + 1] = setId end
    end
    return kept
end

local function zoneSets()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    if H.InArchive() then
        local archiveName = zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
        return archiveName ~= "" and archiveName or "Infinite Archive", H.ArchiveIds()
    end
    if zoneId == cachedZone and cachedIds then return cachedName, cachedIds end
    local name = zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
    local ids = lookup(name)
    if #ids == 0 and GetCurrentZoneDungeonDifficulty() == DUNGEON_DIFFICULTY_NONE then
        local parentId = GetParentZoneId(zoneId)
        if parentId and parentId ~= 0 and parentId ~= zoneId then
            local parentIds = lookup(GetZoneNameById(parentId))
            if #parentIds > 0 then
                ids = parentIds
                name = zo_strformat("<<C:1>>", GetZoneNameById(parentId))
            end
        end
    end
    table.sort(ids, function(a, b) return GetItemSetName(a) < GetItemSetName(b) end)
    if next(setsByName) ~= nil then cachedZone, cachedName, cachedIds = zoneId, name, ids end
    return name, ids
end

function H.SetsHere()
    local name, ids = zoneSets()
    return name, H.ForDifficulty(ids)
end

local function shapeOf(pieceId)
    if shapes[pieceId] then return shapes[pieceId] end
    local I = SH.internal
    local link = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
    local equip, armor, weapon = I.LinkShape(link)
    local want = { equip = equip, armor = armor, weapon = weapon, name = zo_strformat("<<t:1>>", GetItemLinkName(link)) }
    local group
    if I.IsWeapon(want) then
        group = "Weapons"
    elseif equip == EQUIP_TYPE_NECK or equip == EQUIP_TYPE_RING then
        group = "Jewelry"
    else
        group = WEIGHT_GROUP[armor] or "Armor"
    end
    shapes[pieceId] = { group = group, label = I.ShortName(want), order = I.PieceOrder(want), want = want }
    return shapes[pieceId]
end

-- What's missing from one set, for example "Light: Head, Legs | Medium: all | Weapons: Sword".
function H.MissingText(setId)
    local groups, missingCount = {}, 0
    local total = GetNumItemSetCollectionPieces(setId)
    for index = 1, total do
        local pieceId = GetItemSetCollectionPieceInfo(setId, index)
        local shape = shapeOf(pieceId)
        local group = groups[shape.group] or { total = 0, missing = {} }
        groups[shape.group] = group
        group.total = group.total + 1
        if not IsItemSetCollectionPieceUnlocked(pieceId) then
            group.missing[#group.missing + 1] = shape
            missingCount = missingCount + 1
        end
    end
    if missingCount == 0 then return nil, 0, total end
    local parts = {}
    for _, name in ipairs(GROUP_ORDER) do
        local group = groups[name]
        if group and #group.missing > 0 then
            if #group.missing == group.total and group.total > 1 then
                parts[#parts + 1] = name .. ": all"
            else
                table.sort(group.missing, function(a, b) return a.order < b.order end)
                local labels = {}
                for _, shape in ipairs(group.missing) do labels[#labels + 1] = shape.label end
                parts[#parts + 1] = name .. ": " .. table.concat(labels, ", ")
            end
        end
    end
    return table.concat(parts, " | "), missingCount, total, groups
end

-- True in the open world and its delves and public dungeons. Not in houses, group instances or PvP.
function H.IsOpenWorld()
    if H.InArchive() or GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE then return false end
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then return false end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return false end
    if IsInImperialCity and IsInImperialCity() then return false end
    if IsInCyrodiil and IsInCyrodiil() then return false end
    return true
end

-- The full rules, for an overland zone whose Sticker Book sets couldn't be matched.
local function renderFarmLines(bySource, jewelryLabel)
    local I = SH.internal
    local function labelsFor(source)
        local labels = {}
        for label in pairs(bySource[source] or {}) do labels[#labels + 1] = label end
        table.sort(labels, function(a, b)
            local orderA, orderB = bySource[source][a], bySource[source][b]
            if orderA ~= orderB then return orderA < orderB end
            return a < b
        end)
        return table.concat(labels, ", ")
    end
    local lines = { I.Colour("66DD66", "Where to farm:") }
    for _, source in ipairs(I.DROP_SOURCES) do
        if bySource[source] then lines[#lines + 1] = I.Colour("AAAAAA", source .. ": " .. labelsFor(source)) end
    end
    if jewelryLabel ~= "Treasure chests" and bySource[jewelryLabel] then
        lines[#lines + 1] = I.Colour("AAAAAA", jewelryLabel .. ": " .. labelsFor(jewelryLabel))
    end
    local chests = "Treasure chests: any piece"
    if bySource["Treasure chests"] then chests = chests .. ", best for " .. labelsFor("Treasure chests") end
    lines[#lines + 1] = I.Colour("AAAAAA", chests)
    return lines
end

local function generalFarmLines(zoneName)
    local I = SH.internal
    local jewelryLabel = I.JewelrySource(zoneName)
    local bySource = {}
    local samples = {
        { equip = EQUIP_TYPE_HEAD }, { equip = EQUIP_TYPE_SHOULDERS }, { equip = EQUIP_TYPE_CHEST },
        { equip = EQUIP_TYPE_HAND }, { equip = EQUIP_TYPE_WAIST }, { equip = EQUIP_TYPE_LEGS },
        { equip = EQUIP_TYPE_FEET }, { equip = EQUIP_TYPE_NECK }, { equip = EQUIP_TYPE_RING },
        { equip = EQUIP_TYPE_ONE_HAND, weapon = WEAPONTYPE_SWORD },
    }
    for _, want in ipairs(samples) do
        local weapon = I.IsWeapon(want)
        local label = weapon and "Weapons" or I.ShortName(want)
        local order = weapon and 100 or I.PieceOrder(want)
        for _, source in ipairs(I.DropSources(want, jewelryLabel, zoneName)) do
            bySource[source] = bySource[source] or {}
            bySource[source][label] = order
        end
    end
    return renderFarmLines(bySource, jewelryLabel)
end

-- Overland only: where to farm everything still missing here, across all of the zone's sets.
function H.FarmLines(zoneName, ids)
    local I = SH.internal
    local jewelryLabel = I.JewelrySource(zoneName)
    local bySource = {}
    local anyMissing = false
    local openWorld = H.IsOpenWorld()
    for _, setId in ipairs(ids) do
        local _, isOverland = I.SetLocation(setId)
        if isOverland or openWorld then
            for index = 1, GetNumItemSetCollectionPieces(setId) do
                local pieceId = GetItemSetCollectionPieceInfo(setId, index)
                if not IsItemSetCollectionPieceUnlocked(pieceId) then
                    anyMissing = true
                    local shape = shapeOf(pieceId)
                    local label = shape.group == "Weapons" and "Weapons" or shape.label
                    local order = shape.group == "Weapons" and 100 or shape.order
                    for _, source in ipairs(I.DropSources(shape.want, jewelryLabel, zoneName)) do
                        bySource[source] = bySource[source] or {}
                        bySource[source][label] = order
                    end
                end
            end
        end
    end
    if not anyMissing then return {} end
    return renderFarmLines(bySource, jewelryLabel)
end

-- Which class a set is for. Uses the game's own wording, so it follows the game's language.
local function classOf(setId)
    local hasRestrictions, passes, names = GetItemSetClassRestrictions(setId)
    if not hasRestrictions then return nil, true end
    return zo_strformat("<<C:1>>", names), passes
end

function H.ArchiveItems()
    local items = { { name = "My class", data = "mine" } }
    local ok, ids = pcall(H.ArchiveIds)
    if ok then
        local names, seen = {}, {}
        for _, setId in ipairs(ids) do
            local className = classOf(setId)
            if className and not seen[className] then
                seen[className] = true
                names[#names + 1] = className
            end
        end
        table.sort(names)
        for _, className in ipairs(names) do items[#items + 1] = { name = className, data = className } end
    end
    items[#items + 1] = { name = "All classes", data = "all" }
    items[#items + 1] = { name = "Hide", data = "hide" }
    return items
end

function H.ArchiveChoiceName()
    local mode = SH.internal.opts.archiveClasses or "mine"
    if mode == "mine" then return "My class" end
    if mode == "all" then return "All classes" end
    if mode == "hide" then return "Hide" end
    return mode
end

-- Community-reported rule: odd arcs give body armor, even arcs give weapons and jewelry.
-- It applies to the Tho'at boss at the end of each arc and to Marauders.
function H.CurrentArc()
    if not GetEndlessDungeonCounterValue or not ENDLESS_DUNGEON_COUNTER_TYPE_ARC then return nil end
    local ok, arc = pcall(GetEndlessDungeonCounterValue, ENDLESS_DUNGEON_COUNTER_TYPE_ARC)
    if ok and arc and arc > 0 then return arc end
    return nil
end

local function needsFrom(groups, need)
    for groupName, group in pairs(groups or {}) do
        if #group.missing > 0 then
            if groupName == "Weapons" or groupName == "Jewelry" then need.gear = true else need.body = true end
        end
    end
end

local function archiveFarmLines(need)
    local I = SH.internal
    if not need.body and not need.gear then return {} end
    local grey = "AAAAAA"
    local lines = { I.Colour("66DD66", "Where to farm:") }
    local arc = H.CurrentArc()
    if arc then
        local odd = arc % 2 == 1
        local drops = odd and "body armor" or "weapons and jewelry"
        if (odd and need.body) or (not odd and need.gear) then
            lines[#lines + 1] = I.Colour("66DD66", "This arc (" .. arc .. ") drops " .. drops .. " you need")
        else
            lines[#lines + 1] = I.Colour("F0A040", "This arc (" .. arc .. ") drops " .. drops .. ", go one arc further")
        end
    end
    if need.body then lines[#lines + 1] = I.Colour(grey, "Odd arcs (1, 3, 5): body armor") end
    if need.gear then lines[#lines + 1] = I.Colour(grey, "Even arcs (2, 4, 6): weapons, jewelry") end
    lines[#lines + 1] = I.Colour(grey, "From: Tho'at arc boss and Marauders")
    return lines
end

function H.ArchiveLines(name, ids)
    local I = SH.internal
    local mode = I.opts.archiveClasses or "mine"
    if mode == "hide" or #ids == 0 then return {} end
    local suffix = mode == "mine" and " (your class)" or (mode == "all" and " (all classes)" or (" (" .. mode .. ")"))
    local lines = { I.Colour("66DD66", "Needed here: " .. name .. suffix) }
    local shown = 0
    local otherMissing, otherNames = {}, {}
    local need, otherNeed = {}, {}
    for _, setId in ipairs(ids) do
        local className, passes = classOf(setId)
        local chosen = mode == "all" or (mode == "mine" and passes) or className == mode
        local text, missing, total, groups = H.MissingText(setId)
        if chosen then needsFrom(groups, need) else needsFrom(groups, otherNeed) end
        if chosen and text then
            shown = shown + 1
            lines[#lines + 1] = I.Colour("D4B26A", zo_strformat("<<t:1>>", GetItemSetName(setId)))
                .. I.Colour("AAAAAA", "  " .. (total - missing) .. "/" .. total)
            lines[#lines + 1] = text
        elseif not chosen and text and className then
            if not otherMissing[className] then otherNames[#otherNames + 1] = className end
            otherMissing[className] = (otherMissing[className] or 0) + missing
        end
    end
    if shown == 0 then
        if mode == "mine" and #otherNames > 0 then
            -- Other classes' pieces start dropping once your own class is complete
            lines[#lines + 1] = I.Colour("66DD66", "Your class sets are complete")
            table.sort(otherNames)
            for _, className in ipairs(otherNames) do
                lines[#lines + 1] = I.Colour("AAAAAA", className .. ": " .. otherMissing[className] .. " missing")
            end
        else
            lines[#lines + 1] = I.Colour("66DD66", "All collected")
        end
    end
    local farmNeed = need
    if shown == 0 and mode == "mine" then farmNeed = otherNeed end
    for _, line in ipairs(archiveFarmLines(farmNeed)) do lines[#lines + 1] = line end
    return lines
end

function H.PanelLines()
    local I = SH.internal
    if not I or not I.opts.showHere then return {} end
    if H.InArchive() then
        local archiveOk, archiveName, archiveIds = pcall(H.SetsHere)
        if not archiveOk then return {} end
        local linesOk, archiveLines = pcall(H.ArchiveLines, archiveName, archiveIds)
        return linesOk and archiveLines or {}
    end
    local ok, name, ids = pcall(H.SetsHere)
    if not ok or not ids then return {} end
    if #ids == 0 then
        local openOk, open = pcall(H.IsOpenWorld)
        if openOk and open and name ~= "" then return generalFarmLines(name) end
        return {}
    end
    local lines = { I.Colour("66DD66", "Needed here: " .. name) }
    local shown, hidden = 0, 0
    for _, setId in ipairs(ids) do
        local textOk, text, missing, total = pcall(H.MissingText, setId)
        if textOk and text then
            if shown < MAX_SETS then
                shown = shown + 1
                lines[#lines + 1] = I.Colour("D4B26A", zo_strformat("<<t:1>>", GetItemSetName(setId)))
                    .. I.Colour("AAAAAA", "  " .. (total - missing) .. "/" .. total)
                lines[#lines + 1] = text
            else
                hidden = hidden + 1
            end
        end
    end
    if shown == 0 then lines[#lines + 1] = I.Colour("66DD66", "All collected") end
    if hidden > 0 then lines[#lines + 1] = I.Colour("AAAAAA", "+" .. hidden .. " more sets") end
    local farmOk, farmLines = pcall(H.FarmLines, name, ids)
    if farmOk then
        for _, line in ipairs(farmLines) do lines[#lines + 1] = line end
    end
    return lines
end

-- The farming guide sections of the one settings page, available wherever you are.
function H.GuideRows(LHAS)
    return {
        { type = LHAS.ST_SECTION, label = "Farming guide: overland gear" },
        { type = LHAS.ST_LABEL, label = "Head, Chest, Legs: World bosses" },
        { type = LHAS.ST_LABEL, label = "Shoulders, Hands: Public dungeon bosses and champions" },
        { type = LHAS.ST_LABEL, label = "Waist, Feet: Delve bosses" },
        { type = LHAS.ST_LABEL, label = "Weapons: World bosses, public dungeon bosses and champions" },
        { type = LHAS.ST_LABEL, label = "Necklace, Rings: World event chests, most often Dark Anchors" },
        { type = LHAS.ST_LABEL, label = "Any piece: Treasure chests in that zone" },
        { type = LHAS.ST_LABEL, label = "No world events, such as Wrothgar? Farm jewelry from treasure chests." },
        { type = LHAS.ST_SECTION, label = "Farming guide: zones with no public dungeons" },
        { type = LHAS.ST_LABEL, label = "Gold Coast, Hew's Bane: Shoulders from world bosses, hands from delve bosses" },
        { type = LHAS.ST_LABEL, label = "Gold Coast, Hew's Bane: World bosses can also drop jewelry" },
        { type = LHAS.ST_LABEL, label = "Clockwork City, Craglorn, Murkmire, Southern Elsweyr, The Reach, The Deadlands, Galen: Shoulders and hands from treasure chests" },
        { type = LHAS.ST_LABEL, label = "All of these zones: Weapons from world bosses" },
        { type = LHAS.ST_SECTION, label = "Farming guide: Infinite Archive" },
        { type = LHAS.ST_LABEL, label = "Odd arcs (1, 3, 5): Body armor" },
        { type = LHAS.ST_LABEL, label = "Even arcs (2, 4, 6): Weapons and jewelry" },
        { type = LHAS.ST_LABEL, label = "Class gear comes from the Tho'at boss at the end of each arc and from Marauders" },
        { type = LHAS.ST_LABEL, label = "Marauders follow the arc and first appear in arc 2" },
        { type = LHAS.ST_LABEL, label = "You get your own class first, then other classes" },
    }
end

function H.ResetForTest()
    setsByName, cachedZone, cachedName, cachedIds, archiveSetIds = nil, nil, nil, nil, nil
    shapes = {}
end

function H.StatusText()
    local ok, name, ids = pcall(H.SetsHere)
    if not ok or not name then return "Location: unknown" end
    if #ids == 0 then return "Location: " .. name .. " (no Sticker Book sets matched)" end
    return "Location: " .. name .. " (" .. #ids .. (#ids == 1 and " set)" or " sets)")
end
