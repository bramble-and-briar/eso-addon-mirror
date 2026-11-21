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

local setsByName, cachedZone, cachedName, cachedIds
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
    setsByName = {}
    local setId = GetNextItemSetCollectionId()
    while setId do
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
function H.SetsHere()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
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
    shapes[pieceId] = { group = group, label = I.ShortName(want), order = I.PieceOrder(want) }
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
    return table.concat(parts, " | "), missingCount, total
end

function H.PanelLines()
    local I = SH.internal
    if not I or not I.opts.showHere then return {} end
    local ok, name, ids = pcall(H.SetsHere)
    if not ok or not ids or #ids == 0 then return {} end
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
    return lines
end

function H.ResetForTest()
    setsByName, cachedZone, cachedName, cachedIds = nil, nil, nil, nil
    shapes = {}
end

function H.StatusText()
    local ok, name, ids = pcall(H.SetsHere)
    if not ok or not name then return "Location: unknown" end
    if #ids == 0 then return "Location: " .. name .. " (no Sticker Book sets matched)" end
    return "Location: " .. name .. " (" .. #ids .. (#ids == 1 and " set)" or " sets)")
end
