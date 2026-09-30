-- ESO Adventurer Suite - Resource 3D Pins
-- Automatically learns resource-node locations when the player gathers them and
-- renders remembered locations as Suite-owned 3D world markers.
--
-- ESO does not expose a live list of resource-node world positions. A node is
-- therefore learned from the player's raw world position at interaction range,
-- with a small camera-heading offset toward the object.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach

EPC.ResourcePins = EPC.ResourcePins or {}
local R = EPC.ResourcePins
local wm = WINDOW_MANAGER
local GPS = rawget(_G, "LibGPS3") or rawget(_G, "LibGPS")

local INTERACTION_UPDATE_MS = 900
local RENDER_UPDATE_MS = 900
local MOVEMENT_HEAVY_REFRESH_MS_029312 = 5000
local STATIONARY_SAFETY_REFRESH_MS_029312 = 5000
local MOVEMENT_MARKER_CAP_029312 = 8
local MOVEMENT_SAMPLE_CM_029312 = 140
local MOVEMENT_GRACE_MS_029312 = 900
local DEFAULT_VISIBLE_MARKERS = 72
local MIN_VISIBLE_MARKERS = 24
local MAX_VISIBLE_MARKERS = 120
local DEDUPE_DISTANCE_CM = 375
local FISHING_DEDUPE_DISTANCE_CM = 1200
local INTERACT_FORWARD_OFFSET_CM = 145
local GLOW_VERTICAL_OFFSET_CM = 65
local RESOURCE_WINDOW_MS = 5000
local FISHING_RESOURCE_WINDOW_MS = 120000
local CHEST_RESOURCE_WINDOW_MS = 120000
local DEPLETED_PROBE_DISTANCE_M = 4.00
local DEPLETED_PROBE_HOLD_MS = 650
local DEPLETED_AUTO_LOCK_MS = 900
local POST_HARVEST_PROBE_GUARD_MS = 2200
local DEPLETED_PROBE_MOVE_CM = 450
local LIVE_COMMUNITY_VANISH_MS = 450
local LIVE_COMMUNITY_MEMORY_MS = 4500
local LIVE_COMMUNITY_FACING_DOT = 0.90
local MISSING_PIN_FACING_DOT = 0.72
local MISSING_PIN_MATCH_CM = 90
local DEPLETED_CELL_CM = 350
local DEPLETED_MATCH_CM = 475
local FISHING_DEPLETED_CLUSTER_CM = 1000
local FISHING_COMMUNITY_CLUSTER_SCAN_CM = 2200
local FISHING_COMMUNITY_CLUSTER_VERTICAL_CM = 650
local BASE_GLOW_WIDTH_M = 1.15
local BASE_GLOW_HEIGHT_M = 1.15
local GLOW_TEXTURE = "EsoUI/Art/Miscellaneous/lensflare_star_256.dds"
local GLOW_U1, GLOW_U2, GLOW_V1, GLOW_V2 = 0.22, 0.78, 0.22, 0.78

-- v0.29.237: Potion Maker missing-material hunt.
local MISSING_ALCHEMY_PIN_TYPE_STRING = "EAS_MISSING_ALCHEMY_MATERIAL_PIN"
local MISSING_ALCHEMY_PER_MATERIAL = 6
local MISSING_ALCHEMY_MAX_MAP_PINS = 30
local MISSING_ALCHEMY_3D_RANGE_M = 800

local WORLD_GLOW_HIDE_SCENES = {
    "gameMenuInGame", "inventory", "character", "skills", "championPerks",
    "journal", "collectionsBook", "groupMenu", "contacts", "guildHome",
    "mailInbox", "bank", "store", "tradingHouse", "crafting", "settings",
    "worldMap",
}

local COLORS = {
    ORE = { 1.00, 0.68, 0.18 },
    WOOD = { 0.82, 0.56, 0.30 },
    CLOTH = { 0.55, 0.78, 1.00 },
    ALCHEMY = { 0.42, 1.00, 0.46 },
    MUSHROOM = { 0.50, 0.90, 0.48 },
    FLOWER = { 0.48, 1.00, 0.58 },
    WATERPLANT = { 0.32, 0.92, 0.68 },
    RUNE = { 0.78, 0.48, 1.00 },
    PROVISIONING = { 1.00, 0.74, 0.26 },
    WATER = { 0.32, 0.84, 1.00 },
    FISHING = { 0.25, 0.94, 0.87 },
    CHEST = { 0.30, 0.92, 0.92 },
    HEAVYSACK = { 0.62, 0.92, 0.52 },
    CLAM = { 0.62, 0.92, 0.52 },
    TROVE = { 0.72, 0.48, 1.00 },
    JUSTICE = { 0.94, 0.46, 0.94 },
    STASH = { 0.94, 0.46, 0.94 },
    RESOURCE = { 1.00, 0.92, 0.45 },
    SKYSHARD = { 1.00, 0.82, 0.20 },
}

local TYPE_LABELS = {
    ORE = "Ore / Jewelry Seam",
    WOOD = "Wood",
    CLOTH = "Cloth",
    ALCHEMY = "Alchemy",
    MUSHROOM = "Mushroom",
    FLOWER = "Flower / Herb",
    WATERPLANT = "Water Plant",
    RUNE = "Runestone",
    PROVISIONING = "Provisioning Source",
    WATER = "Water / Solvent",
    FISHING = "Fishing Hole",
    CHEST = "Chest",
    HEAVYSACK = "Heavy Sack",
    CLAM = "Giant Clam",
    TROVE = "Thieves Trove",
    JUSTICE = "Justice Container",
    STASH = "Hidden Stash",
    RESOURCE = "Resource",
    SKYSHARD = "Skyshard",
}


local GLOW_TIERS = {
    -- Rarity changes color/intensity, not icon footprint. Keeping the halo size
    -- stable prevents higher tiers from looking physically larger in-world.
    COMMON = { color = { 0.95, 0.95, 0.95 }, alpha = 0.34, size = 1.00 },
    UNCOMMON = { color = { 0.28, 0.86, 1.00 }, alpha = 0.46, size = 1.00 },
    RARE = { color = { 0.82, 0.40, 1.00 }, alpha = 0.58, size = 1.00 },
    EPIC = { color = { 1.00, 0.78, 0.22 }, alpha = 0.70, size = 1.00 },
}

local ICON_TEXTURES = {
    SUITE_GLOW = GLOW_TEXTURE,
    WORLD = EPC:AssetPath("Art/ResourcePins/world_marker.dds"),
    MINING = EPC:AssetPath("Art/ResourcePins/mining.dds"),
    WOOD = EPC:AssetPath("Art/ResourcePins/wood.dds"),
    CLOTHING = EPC:AssetPath("Art/ResourcePins/clothing.dds"),
    ALCHEMY = EPC:AssetPath("Art/ResourcePins/alchemy.dds"),
    ENCHANTING = EPC:AssetPath("Art/ResourcePins/enchanting.dds"),
    MUSHROOM = EPC:AssetPath("Art/ResourcePins/mushroom.dds"),
    FLOWER = EPC:AssetPath("Art/ResourcePins/flower.dds"),
    WATERPLANT = EPC:AssetPath("Art/ResourcePins/waterplant.dds"),
    SOLVENT = EPC:AssetPath("Art/ResourcePins/solvent.dds"),
    FISH = EPC:AssetPath("Art/ResourcePins/fish.dds"),
    CHEST = EPC:AssetPath("Art/ResourcePins/chest.dds"),
    HEAVYSACK = EPC:AssetPath("Art/ResourcePins/heavysack.dds"),
    CLAM = EPC:AssetPath("Art/ResourcePins/clam.dds"),
    TROVE = EPC:AssetPath("Art/ResourcePins/trove.dds"),
    JUSTICE = EPC:AssetPath("Art/ResourcePins/justice.dds"),
    STASH = EPC:AssetPath("Art/ResourcePins/stash.dds"),
    SKYSHARD = "EsoUI/Art/MapPins/skyshard_seen.dds",
}


local NATIVE_ICON_TEXTURES = {
    -- Resource-style ESO textures. Avoid master-writ/Zone Story artwork here:
    -- those read visually as books/pages when used as 3D world markers.
    WORLD = "/esoui/art/icons/poi/poi_crafting_complete.dds",
    MINING = "/esoui/art/crafting/smithing_tabicon_refine_down.dds",
    WOOD = "/esoui/art/icons/mapkey/mapkey_lumbermill.dds",
    CLOTHING = "/esoui/art/icons/servicemappins/servicepin_clothier.dds",
    ALCHEMY = "/esoui/art/crafting/alchemy_tabicon_reagent_down.dds",
    ENCHANTING = "/esoui/art/crafting/enchantment_tabicon_essence_down.dds",
    MUSHROOM = "/esoui/art/crafting/alchemy_tabicon_reagent_down.dds",
    FLOWER = "/esoui/art/crafting/alchemy_tabicon_reagent_down.dds",
    WATERPLANT = "/esoui/art/crafting/alchemy_tabicon_solvent_up.dds",
    SOLVENT = "/esoui/art/crafting/alchemy_tabicon_solvent_up.dds",
    FISH = "/esoui/art/icons/crafting_fishing_perch.dds",
    CHEST = "/esoui/art/icons/mapkey/mapkey_areaofinterest.dds",
    HEAVYSACK = "/esoui/art/treeicons/store_indexicon_consumables_down.dds",
    CLAM = "/esoui/art/icons/crafting_fishing_perch.dds",
    TROVE = "/esoui/art/icons/mapkey/mapkey_areaofinterest.dds",
    JUSTICE = "/esoui/art/icons/servicemappins/servicepin_fence.dds",
    STASH = "/esoui/art/icons/servicemappins/servicepin_fence.dds",
    SKYSHARD = "EsoUI/Art/MapPins/skyshard_seen.dds",
}

local NATIVE_ICON_SCALE = {
    WORLD = 0.78,
    MINING = 0.82,
    WOOD = 0.86,
    CLOTHING = 0.80,
    ALCHEMY = 1.18,
    ENCHANTING = 0.66,
    MUSHROOM = 1.18,
    FLOWER = 1.18,
    WATERPLANT = 1.08,
    SOLVENT = 1.08,
    FISH = 0.88,
    CHEST = 0.82,
    HEAVYSACK = 0.84,
    CLAM = 0.88,
    TROVE = 0.82,
    JUSTICE = 0.82,
    STASH = 0.82,
    SKYSHARD = 0.96,
}

local AUTO_ICON = {
    ORE = "MINING", WOOD = "WOOD", CLOTH = "CLOTHING", ALCHEMY = "ALCHEMY",
    MUSHROOM = "MUSHROOM", FLOWER = "FLOWER", WATERPLANT = "WATERPLANT",
    RUNE = "ENCHANTING", PROVISIONING = "HEAVYSACK", WATER = "SOLVENT", FISHING = "FISH", CHEST = "CHEST",
    HEAVYSACK = "HEAVYSACK", CLAM = "CLAM", TROVE = "TROVE", JUSTICE = "JUSTICE",
    STASH = "STASH", RESOURCE = "WORLD", SKYSHARD = "SKYSHARD",
}

local CUSTOM_ICON_SETTING = {
    ORE = "resourcePinsIconOre", WOOD = "resourcePinsIconWood", CLOTH = "resourcePinsIconCloth",
    ALCHEMY = "resourcePinsIconAlchemy", MUSHROOM = "resourcePinsIconAlchemy", FLOWER = "resourcePinsIconAlchemy",
    WATERPLANT = "resourcePinsIconAlchemy", RUNE = "resourcePinsIconRunes", PROVISIONING = "resourcePinsIconSpecial", WATER = "resourcePinsIconWater",
    FISHING = "resourcePinsIconFishing", CHEST = "resourcePinsIconSpecial", HEAVYSACK = "resourcePinsIconSpecial",
    CLAM = "resourcePinsIconSpecial", TROVE = "resourcePinsIconSpecial", JUSTICE = "resourcePinsIconSpecial",
    STASH = "resourcePinsIconSpecial", RESOURCE = "resourcePinsIconOther", SKYSHARD = "resourcePinsIconOther",
}

-- Bundled Suite Community Resource Data. The supplied database stores coordinates
-- in 0.2 meter increments using horizontal X/Y and vertical Z. ESO raw world
-- positions use centimeters and X/Y(vertical)/Z(horizontal), so the decoder
-- remaps axes while converting to centimeters.
local COMMUNITY_GRID_CM = 5000
local COMMUNITY_DEDUPE_CM = DEDUPE_DISTANCE_CM

local function dedupeDistanceForKind(kind)
    return tostring(kind or "") == "FISHING" and FISHING_DEDUPE_DISTANCE_CM or DEDUPE_DISTANCE_CM
end
local COMMUNITY_DATASET_RECORDS = 124625
local COMMUNITY_MODULES = { "AD", "DC", "DLC", "EP", "NF" }
local COMMUNITY_KIND_BY_PIN = {
    [1] = "ORE", [17] = "ORE",
    [2] = "CLOTH",
    [3] = "RUNE", [16] = "RUNE",
    [4] = "MUSHROOM",
    [5] = "WOOD",
    [6] = "CHEST",
    [7] = "WATER",
    [8] = "FISHING",
    [9] = "HEAVYSACK",
    [10] = "TROVE",
    [11] = "JUSTICE",
    [12] = "STASH",
    [13] = "FLOWER",
    [14] = "WATERPLANT",
    [15] = "CLAM",
    [18] = "RESOURCE",
    [19] = "FLOWER",
    [20] = "ALCHEMY",
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f, g, h
end

local function lower(value)
    value = tostring(value or "")
    if type(zo_strlower) == "function" then
        local ok, result = pcall(zo_strlower, value)
        if ok and type(result) == "string" then return result end
    end
    return string.lower(value)
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then return tonumber(GetFrameTimeMilliseconds()) or 0 end
    return 0
end

local function currentSceneName()
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetCurrentScene) ~= "function" then return "" end
    local scene = safe(function() return SCENE_MANAGER:GetCurrentScene() end, nil)
    if scene and type(scene.GetName) == "function" then
        return string.lower(tostring(safe(function() return scene:GetName() end, "") or ""))
    end
    return ""
end

local function diggingGameActive()
    return type(IsDiggingGameActive) == "function" and safe(IsDiggingGameActive, false) == true
end

local function nowStamp()
    if type(GetTimeStamp) == "function" then return tonumber(GetTimeStamp()) or 0 end
    return 0
end

local function distance2Dcm(ax, az, bx, bz)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dz = (tonumber(az) or 0) - (tonumber(bz) or 0)
    return math.sqrt((dx * dx) + (dz * dz))
end

local function distance3Dcm(ax, ay, az, bx, by, bz)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dy = (tonumber(ay) or 0) - (tonumber(by) or 0)
    local dz = (tonumber(az) or 0) - (tonumber(bz) or 0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function gridKey(x, z, cellSize)
    cellSize = tonumber(cellSize) or COMMUNITY_GRID_CM
    local gx = math.floor((tonumber(x) or 0) / cellSize)
    local gz = math.floor((tonumber(z) or 0) / cellSize)
    return tostring(gx) .. ":" .. tostring(gz), gx, gz
end

local function addType(map, globalName, kind)
    local value = rawget(_G, globalName)
    if value ~= nil then map[value] = kind end
end

local ITEM_KIND = {}
addType(ITEM_KIND, "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ORE")
addType(ITEM_KIND, "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ORE")
addType(ITEM_KIND, "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "WOOD")
addType(ITEM_KIND, "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "CLOTH")
addType(ITEM_KIND, "ITEMTYPE_REAGENT", "ALCHEMY")
addType(ITEM_KIND, "ITEMTYPE_INGREDIENT", "PROVISIONING")
addType(ITEM_KIND, "ITEMTYPE_ADDITIVE", "PROVISIONING")
addType(ITEM_KIND, "ITEMTYPE_SPICE", "PROVISIONING")
addType(ITEM_KIND, "ITEMTYPE_FLAVORING", "PROVISIONING")
addType(ITEM_KIND, "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "RUNE")
addType(ITEM_KIND, "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "RUNE")
addType(ITEM_KIND, "ITEMTYPE_ENCHANTING_RUNE_POTENCY", "RUNE")
addType(ITEM_KIND, "ITEMTYPE_POTION_BASE", "WATER")
addType(ITEM_KIND, "ITEMTYPE_POISON_BASE", "WATER")


local ITEM_ID_KIND = {
    [30148]="MUSHROOM", [30149]="MUSHROOM", [30151]="MUSHROOM", [30152]="MUSHROOM",
    [30153]="MUSHROOM", [30154]="MUSHROOM", [30155]="MUSHROOM", [30156]="MUSHROOM",
    [30157]="FLOWER", [30158]="FLOWER", [30159]="FLOWER", [30160]="FLOWER",
    [30161]="FLOWER", [30162]="FLOWER", [30163]="FLOWER", [30164]="FLOWER",
    [30165]="WATERPLANT", [30166]="WATERPLANT", [77590]="FLOWER",
}

local SPECIAL_NAME_KIND = {
    ["heavy sack"]="HEAVYSACK", ["heavy crate"]="HEAVYSACK", ["thieves trove"]="TROVE",
    ["loose panel"]="STASH", ["loose tile"]="STASH", ["loose stone"]="STASH",
    ["giant clam"]="CLAM", ["herbalist's satchel"]="ALCHEMY", ["psijic portal"]="RUNE",
}

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

function R:GetGlowTierForKind(kind)
    kind = tostring(kind or "RESOURCE")
    if kind == "CHEST" or kind == "TROVE" then return "EPIC" end
    if kind == "HEAVYSACK" or kind == "CLAM" or kind == "JUSTICE" or kind == "STASH" then return "RARE" end
    if kind == "SKYSHARD" then return "EPIC" end
    if kind == "RUNE" or kind == "PROVISIONING" or kind == "ALCHEMY" or kind == "MUSHROOM" or kind == "FLOWER" or kind == "WATERPLANT" or kind == "FISHING" then return "UNCOMMON" end
    return "COMMON"
end

local GetGlowVisualForEntryImplArch

function R:GetGlowVisualForEntry(...)

    return GetGlowVisualForEntryImplArch(self, ...)

end

GetGlowVisualForEntryImplArch = function(self, entry, alphaBase)
    local saved = EPC.saved or {}
    local strength = clamp01((tonumber(saved.resourcePinsGlowStrength) or 78) / 100)
    local tierName = (saved.resourcePinsValueGlow == false) and "COMMON" or self:GetGlowTierForKind(entry and entry.kind)
    local tier = GLOW_TIERS[tierName] or GLOW_TIERS.COMMON
    local color = tier.color or { 1, 1, 1 }
    local alpha = math.max(0.20, math.min(0.95, (tonumber(alphaBase) or 0.72) * (tonumber(tier.alpha) or 0.42) * (0.55 + (strength * 0.75))))
    -- Keep the halo footprint tight so every icon gets the same rune-like glow ring.
    local size = 0.98 + (0.08 * strength)
    return color, alpha, size, tierName
end

function R:GetDepletedCooldownSeconds()
    local saved = EPC.saved or {}
    local minutes = math.max(1, math.min(30, tonumber(saved.resourcePinsDepletedCooldownMinutes) or 5))
    return math.floor(minutes * 60)
end

function R:GetDepletedCellKey(x, z)
    local gx = math.floor(((tonumber(x) or 0) / DEPLETED_CELL_CM) + 0.5)
    local gz = math.floor(((tonumber(z) or 0) / DEPLETED_CELL_CM) + 0.5)
    return tostring(gx) .. ":" .. tostring(gz), gx, gz
end

function R:GetDepletedZoneBucket(zoneId, create)
    if not EPC.saved then return nil end
    EPC.saved.resourcePinsDepleted = EPC.saved.resourcePinsDepleted or {}
    zoneId = tostring(tonumber(zoneId) or zoneId or "0")
    local bucket = EPC.saved.resourcePinsDepleted[zoneId]
    if type(bucket) ~= "table" and create then
        bucket = {}
        EPC.saved.resourcePinsDepleted[zoneId] = bucket
    end
    return bucket
end

function R:PruneDepleted(zoneId)
    local bucket = self:GetDepletedZoneBucket(zoneId, false)
    if type(bucket) ~= "table" then return 0 end
    local now = nowStamp()
    local count = 0
    for key, record in pairs(bucket) do
        local untilStamp = type(record) == "table" and tonumber(record.untilStamp) or tonumber(record)
        if not untilStamp or untilStamp <= now then
            bucket[key] = nil
        else
            count = count + 1
        end
    end
    return count
end

function R:IsPositionDepleted(zoneId, x, z, kind)
    if not EPC.saved or EPC.saved.resourcePinsHideDepleted == false then return false end
    local bucket = self:GetDepletedZoneBucket(zoneId, false)
    if type(bucket) ~= "table" then return false end

    local now = nowStamp()
    local entryKind = tostring(kind or "")
    x, z = tonumber(x), tonumber(z)
    if not x or not z then return false end

    -- Depleted records are intentionally scanned directly. The active depleted
    -- list is small and short-lived, while direct scanning lets exact-pin records
    -- use unique coordinate keys instead of colliding in the 3.5m grid cell.
    for key, record in pairs(bucket) do
        local untilStamp = type(record) == "table" and tonumber(record.untilStamp) or tonumber(record)
        if not untilStamp or untilStamp <= now then
            bucket[key] = nil
        else
            local rx = type(record) == "table" and tonumber(record.x) or nil
            local rz = type(record) == "table" and tonumber(record.z) or nil
            if rx and rz then
                local recordKind = type(record) == "table" and tostring(record.kind or "") or ""
                local sameKindOnly = type(record) == "table" and record.sameKindOnly == true
                local exactPinOnly = type(record) == "table" and record.exactPinOnly == true
                local radiusCm = type(record) == "table" and tonumber(record.radiusCm) or DEPLETED_MATCH_CM
                if exactPinOnly then
                    radiusCm = math.max(75, radiusCm or MISSING_PIN_MATCH_CM)
                else
                    radiusCm = math.max(DEPLETED_MATCH_CM, radiusCm or DEPLETED_MATCH_CM)
                end
                local kindMatches = not sameKindOnly or entryKind == "" or recordKind == "" or entryKind == recordKind
                if kindMatches and distance2Dcm(x, z, rx, rz) <= radiusCm then return true end
            end
        end
    end
    return false
end

function R:MarkPositionDepleted(zoneId, x, z, reason, kind, radiusCm, sameKindOnly, exactPinOnly)
    if not EPC.saved or EPC.saved.resourcePinsHideDepleted == false then return false end
    zoneId, x, z = tonumber(zoneId), tonumber(x), tonumber(z)
    if not zoneId or not x or not z then return false end
    local bucket = self:GetDepletedZoneBucket(zoneId, true)
    if not bucket then return false end

    local kindText = tostring(kind or "RESOURCE")
    local key
    if exactPinOnly == true then
        -- Exact empty-pin records need their own identity. Using only the broad
        -- depletion grid cell caused adjacent pins in the same cell to overwrite
        -- each other, which could leave the intended marker visible.
        key = string.format("pin:%d:%d:%s", math.floor(x + 0.5), math.floor(z + 0.5), kindText)
    else
        key = self:GetDepletedCellKey(x, z)
    end

    bucket[key] = {
        x = x, z = z,
        untilStamp = nowStamp() + self:GetDepletedCooldownSeconds(),
        reason = tostring(reason or "depleted"),
        kind = kindText,
        radiusCm = exactPinOnly == true and math.max(75, tonumber(radiusCm) or MISSING_PIN_MATCH_CM) or math.max(DEPLETED_MATCH_CM, tonumber(radiusCm) or DEPLETED_MATCH_CM),
        sameKindOnly = sameKindOnly == true,
        exactPinOnly = exactPinOnly == true,
    }
    self.lastDepletedReason = tostring(reason or "depleted")
    self.lastDepletedKind = kindText
    self.lastDepletedAt = nowStamp()
    return true
end

function R:MarkFishingCommunityClusterDepleted(zoneId, x, y, z)
    zoneId, x, y, z = tonumber(zoneId), tonumber(x), tonumber(y), tonumber(z)
    if not zoneId or not x or not z then return 0 end

    local cache = self:BuildCommunityZoneCache(zoneId)
    if type(cache) ~= "table" or type(cache.cells) ~= "table" then
        self:MarkPositionDepleted(zoneId, x, z, "fishing catch", "FISHING", FISHING_DEPLETED_CLUSTER_CM, true)
        return 1
    end

    local marked = 0
    local seen = {}
    local _, gx, gz = gridKey(x, z, COMMUNITY_GRID_CM)
    local cellRange = math.max(1, math.ceil(FISHING_COMMUNITY_CLUSTER_SCAN_CM / COMMUNITY_GRID_CM))
    for dx = -cellRange, cellRange do
        for dz = -cellRange, cellRange do
            local cell = tostring(gx + dx) .. ":" .. tostring(gz + dz)
            local entries = cache.cells[cell]
            if type(entries) == "table" then
                for i = 1, #entries do
                    local entry = entries[i]
                    if type(entry) == "table" and tostring(entry.kind or "") == "FISHING" then
                        local ex, ey, ez = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
                        local horizontal = ex and ez and distance2Dcm(x, z, ex, ez) or nil
                        local verticalOk = not y or not ey or math.abs(ey - y) <= FISHING_COMMUNITY_CLUSTER_VERTICAL_CM
                        if horizontal and horizontal <= FISHING_COMMUNITY_CLUSTER_SCAN_CM and verticalOk then
                            local exactKey = tostring(math.floor((ex or 0) + 0.5)) .. ":" .. tostring(math.floor((ez or 0) + 0.5))
                            if not seen[exactKey] then
                                seen[exactKey] = true
                                if self:MarkPositionDepleted(zoneId, ex, ez, "fishing cluster", "FISHING", DEPLETED_MATCH_CM, true) then
                                    marked = marked + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Always cover the actual interaction point too, including learned-only holes.
    if self:MarkPositionDepleted(zoneId, x, z, "fishing catch", "FISHING", FISHING_DEPLETED_CLUSTER_CM, true) then
        marked = marked + 1
    end
    self.lastFishingClusterMarked = marked
    return marked
end

function R:ClearDepletedLocations()
    if EPC.saved then EPC.saved.resourcePinsDepleted = {} end
    self.depletionProbeKey = nil
    self.depletionProbeSince = 0
    self.depletionProbePlayerX = nil
    self.depletionProbePlayerZ = nil
    self.lastDepletedReason = nil
    self.lastDepletedKind = nil
    self.lastDepletionProbeDistanceM = nil
    self.lastDepletionProbeState = "idle"
    self:RefreshMarkers()
end

function R:IsSupportedResourceInteraction(interactionType, targetName)
    if INTERACTION_HARVEST ~= nil and interactionType == INTERACTION_HARVEST then return true end
    if INTERACTION_FISH ~= nil and interactionType == INTERACTION_FISH then return true end
    local specialKind = SPECIAL_NAME_KIND[lower(targetName)]
    if specialKind ~= nil then return true end
    return self:ClassifyByName(targetName) == "CHEST"
end

function R:IsFacingWorldPosition(x, z, minDot)
    local _, px, _, pz = self:GetPlayerRawPosition()
    px, pz, x, z = tonumber(px), tonumber(pz), tonumber(x), tonumber(z)
    if not px or not pz or not x or not z then return false end
    local dx, dz = x - px, z - pz
    local len = math.sqrt((dx * dx) + (dz * dz))
    if len < 1 then return true end
    dx, dz = dx / len, dz / len
    local heading = tonumber(safe(GetPlayerCameraHeading, 0)) or 0
    local fx, fz = math.sin(heading), math.cos(heading)
    return ((fx * dx) + (fz * dz)) >= (tonumber(minDot) or LIVE_COMMUNITY_FACING_DOT)
end

function R:UpdateNearbyDepletedProbe(interactionType, targetName)
    if not EPC.saved or EPC.saved.resourcePinsHideDepleted == false then
        self.liveCommunityNode = nil
        self.liveCommunityVanishedAt = 0
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.lastDepletionProbeState = "disabled"
        return
    end

    local now = nowMs()
    targetName = tostring(targetName or "")
    local candidate = self.nearestDepletionCandidate
    local probeDistanceM = type(candidate) == "table" and (tonumber(candidate.horizontalDistanceM) or tonumber(candidate.distanceM)) or nil
    self.lastDepletionProbeDistanceM = probeDistanceM

    -- After the player successfully collects a node, ESO briefly drops the
    -- interaction prompt. Do not let the proximity fallback interpret a
    -- neighboring, still-live resource as missing during that transition.
    local lastOwnCollectionAt = tonumber(self.lastOwnCollectionAt) or 0
    if lastOwnCollectionAt > 0 and (now - lastOwnCollectionAt) < POST_HARVEST_PROBE_GUARD_MS then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.depletionProbePlayerX = nil
        self.depletionProbePlayerZ = nil
        self.liveCommunityNode = nil
        self.liveCommunityVanishedAt = 0
        self.lastDepletionProbeState = "post-harvest protection"
        return
    end

    -- Any real resource interaction cancels the proximity fallback immediately.
    if self:IsSupportedResourceInteraction(interactionType, targetName) then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.depletionProbePlayerX = nil
        self.depletionProbePlayerZ = nil

        -- Keep the positive-evidence path too: if a community node was visibly
        -- harvestable and then vanishes, another player's collection can still
        -- deplete it without relying on the proximity fallback.
        if type(candidate) == "table" and candidate.debug ~= true and probeDistanceM and probeDistanceM <= 5.0 then
            local entry = candidate.entry
            local zoneId = select(1, self:GetPlayerRawPosition())
            if type(entry) == "table" and zoneId then
                self.liveCommunityNode = {
                    zoneId = zoneId,
                    x = tonumber(entry.x), z = tonumber(entry.z),
                    kind = tostring(entry.kind or "RESOURCE"),
                    name = targetName,
                    seenAt = now,
                }
                self.liveCommunityVanishedAt = 0
                self.lastDepletionProbeState = "community node confirmed live"
            end
        else
            self.lastDepletionProbeState = "live resource detected"
        end
        return
    end

    if self.pendingResource and self.pendingResource.ownInteraction == true then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.lastDepletionProbeState = "your harvest pending"
        return
    end

    -- First preserve the safer positive-evidence path for a node that was
    -- actually seen alive and then disappeared while still nearby/facing it.
    local live = self.liveCommunityNode
    if type(live) == "table" then
        if (now - (tonumber(live.seenAt) or 0)) > LIVE_COMMUNITY_MEMORY_MS then
            self.liveCommunityNode = nil
            self.liveCommunityVanishedAt = 0
        else
            local zoneId, px, _, pz = self:GetPlayerRawPosition()
            if zoneId and tonumber(zoneId) == tonumber(live.zoneId) then
                local liveDistanceM = distance2Dcm(px, pz, live.x, live.z) / 100
                if liveDistanceM <= 5.0 and self:IsFacingWorldPosition(live.x, live.z) and targetName == "" then
                    if (tonumber(self.liveCommunityVanishedAt) or 0) <= 0 then
                        self.liveCommunityVanishedAt = now
                    elseif (now - (tonumber(self.liveCommunityVanishedAt) or now)) >= LIVE_COMMUNITY_VANISH_MS then
                        if self:MarkPositionDepleted(live.zoneId, live.x, live.z, "other player harvested", live.kind, DEPLETED_MATCH_CM, true) then
                            self.lastDepletionProbeState = "other-player harvest confirmed"
                            self.liveCommunityNode = nil
                            self.liveCommunityVanishedAt = 0
                            self:RefreshMarkers()
                            return
                        end
                    end
                else
                    self.liveCommunityVanishedAt = 0
                end
            end
        end
    end

    -- User-requested fallback: when the player walks right up to the nearest
    -- resource icon and ESO still exposes no interaction, treat the spot as
    -- probably already depleted after a short confirmation hold. This applies
    -- to both bundled community pins and learned pins; learned pins can shadow
    -- the bundled record after a previous gather and must not remain forever.
    if type(candidate) ~= "table" or candidate.debug == true
        or not probeDistanceM or probeDistanceM > DEPLETED_PROBE_DISTANCE_M then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.depletionProbePlayerX = nil
        self.depletionProbePlayerZ = nil
        self.lastDepletionProbeState = "proximity idle"
        return
    end

    -- A harmless world/interactable name can remain under the reticle even when
    -- the resource itself is absent. Do not let that block an exact-pin check
    -- when the player is already very close. Farther than 2.25m, keep the guard
    -- to avoid timing out a resource while intentionally looking at something else.
    if targetName ~= "" and probeDistanceM > 2.25 then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.depletionProbePlayerX = nil
        self.depletionProbePlayerZ = nil
        self.lastDepletionProbeState = "other target under reticle"
        return
    end

    local entry = candidate.entry
    local zoneId, px, _, pz = self:GetPlayerRawPosition()
    if type(entry) ~= "table" or not zoneId or not px or not pz then return end

    if probeDistanceM > 1.75 and not self:IsFacingWorldPosition(entry.x, entry.z, MISSING_PIN_FACING_DOT) then
        self.depletionProbeKey = nil
        self.depletionProbeSince = 0
        self.depletionProbePlayerX = nil
        self.depletionProbePlayerZ = nil
        self.lastDepletionProbeState = "near pin; not approaching it"
        return
    end

    local key = tostring(zoneId) .. ":" .. self:GetDepletedCellKey(entry.x, entry.z)
    if self.depletionProbeKey ~= key then
        self.depletionProbeKey = key
        self.depletionProbeSince = now
        self.depletionProbePlayerX = px
        self.depletionProbePlayerZ = pz
        self.lastDepletionProbeState = "checking nearby resource pin"
        return
    end

    -- Keep the timer running while the player approaches the same pin. The
    -- candidate key, facing check, interaction check, and 4m range are the
    -- safeguards; forcing a stationary hold made players stand inside the icon.
    self.depletionProbePlayerX = px
    self.depletionProbePlayerZ = pz

    local heldMs = now - (tonumber(self.depletionProbeSince) or now)
    self.lastDepletionProbeState = string.format("checking nearby resource pin %.1fs", math.max(0, heldMs) / 1000)
    if heldMs >= DEPLETED_PROBE_HOLD_MS then
        if self:MarkPositionDepleted(zoneId, entry.x, entry.z, "no interaction nearby", entry.kind, MISSING_PIN_MATCH_CM, true, true) then
            self.depletionAutoLockUntil = now + DEPLETED_AUTO_LOCK_MS
            self.lastDepletionProbeState = "nearby resource pin depleted"
            self.depletionProbeKey = nil
            self.depletionProbeSince = 0
            self:RefreshMarkers()
        end
    end
end

function R:GetPlayerRawPosition()
    if type(GetUnitRawWorldPosition) ~= "function" then return nil end
    local zoneId, x, y, z = safe(GetUnitRawWorldPosition, nil, "player")
    zoneId, x, y, z = tonumber(zoneId), tonumber(x), tonumber(y), tonumber(z)
    if not zoneId or not x or not y or not z then return nil end
    if x == 0 and y == 0 and z == 0 then return nil end
    return zoneId, x, y, z
end

function R:GetApproximateInteractablePosition()
    local zoneId, x, y, z = self:GetPlayerRawPosition()
    if not zoneId then return nil end
    local heading = tonumber(safe(GetPlayerCameraHeading, nil))
    if heading then
        x = x + (math.sin(heading) * INTERACT_FORWARD_OFFSET_CM)
        z = z + (math.cos(heading) * INTERACT_FORWARD_OFFSET_CM)
    end
    return zoneId, x, y, z
end

function R:IsNormalWorldSceneActive()
    if diggingGameActive() then return false end
    local name = currentSceneName()
    if name == "hud" or name == "hudui" or name == "loot" then return true end
    -- Some UI versions suffix/prefix the normal HUD scene names. Accept only
    -- names that clearly identify HUD gameplay, never arbitrary menus.
    if string.find(name, "hud", 1, true) and not string.find(name, "menu", 1, true) then return true end
    return false
end

function R:RecoverWorldRenderer(reason)
    if diggingGameActive() or not self:IsNormalWorldSceneActive() then return false end
    self:EnsureWindow()
    if self.window and type(self.window.SetHidden) == "function" then self.window:SetHidden(false) end
    self.worldRenderOriginReady = false
    self:UpdateWorldRenderOrigin()
    self.lastRendererRecoveryAt = nowMs()
    self.lastRendererRecoveryReason = tostring(reason or "automatic recovery")
    return true
end

local RecoverSuite3DWorldPinsImplArch

function R:RecoverSuite3DWorldPins(...)

    return RecoverSuite3DWorldPinsImplArch(self, ...)

end

RecoverSuite3DWorldPinsImplArch = function(self, reason)
    local tag = tostring(reason or "3D recovery")
    self:RecoverWorldRenderer(tag)

    -- Antiquity shovel pins use their own 3D root. Restore that root too so
    -- leaving the excavation minigame cannot strand either marker system.
    if EPC.AntiquityAssistant and type(EPC.AntiquityAssistant.RecoverWorldRenderer) == "function" then
        pcall(EPC.AntiquityAssistant.RecoverWorldRenderer, EPC.AntiquityAssistant, tag)
    end

    -- Integrated LoreBooks uses the same HUD-fragment pattern. The scene can
    -- occasionally leave its root hidden after Antiquity digging, so re-show
    -- and refresh it only after normal HUD gameplay is active again.
    if EASLL_WorldPins and type(EASLL_WorldPins.SetHidden) == "function" then
        pcall(EASLL_WorldPins.SetHidden, EASLL_WorldPins, false)
    end
    if EASLoreLibrary and EASLoreLibrary.worldPins then
        local lore = EASLoreLibrary.worldPins
        if type(WorldPositionToGuiRender3DPosition) == "function" and EASLL_WorldPins then
            local gx, gz, gy = safe(WorldPositionToGuiRender3DPosition, nil, 0, 0, 0)
            if gx and gz and gy and type(EASLL_WorldPins.Set3DRenderSpaceOrigin) == "function" then
                lore.renderOriginX, lore.renderOriginZ, lore.renderOriginY = gx, gz, gy
                pcall(EASLL_WorldPins.Set3DRenderSpaceOrigin, EASLL_WorldPins, gx, gz, gy)
            end
        end
        if type(lore.RefreshPins) == "function" then pcall(lore.RefreshPins, lore) end
    end

    -- These Suite 3D systems do not use the HUD fragment, but their render
    -- spaces can also be invalidated by the excavation scene transition.
    if EPC.TeamVisibility and type(EPC.TeamVisibility.ResetRenderSpaces) == "function" then
        pcall(EPC.TeamVisibility.ResetRenderSpaces, EPC.TeamVisibility)
        if type(EPC.TeamVisibility.RefreshParticles) == "function" then pcall(EPC.TeamVisibility.RefreshParticles, EPC.TeamVisibility) end
    end
    if EPC.DungeonChestFinder and type(EPC.DungeonChestFinder.ResetRenderSpace) == "function" then
        pcall(EPC.DungeonChestFinder.ResetRenderSpace, EPC.DungeonChestFinder)
        if type(EPC.DungeonChestFinder.RefreshMarkers) == "function" then pcall(EPC.DungeonChestFinder.RefreshMarkers, EPC.DungeonChestFinder) end
    end
    return true
end

function R:IsWorldGlowSuppressed()
    if EPC.saved and EPC.saved.hudHideInMenus == false then return false end

    -- The 3D marker root is attached to the HUD/HUD UI/Loot scenes through a
    -- ZO_SimpleSceneFragment. Let that fragment decide whether world markers
    -- are currently allowed to render. SCENE_MANAGER:IsShowing(name) can remain
    -- true for parent/menu scenes after returning to gameplay, which previously
    -- left every resource pin permanently stuck in the queued/menu state.
    if self.worldFragment and type(self.worldFragment.IsHidden) == "function" then
        local ok, hidden = pcall(self.worldFragment.IsHidden, self.worldFragment)
        if ok then return hidden == true end
    end

    -- If fragment state is unavailable, fail open rather than hiding all pins.
    -- The fragment itself still controls the visibility of the 3D root.
    return false
end


function R:IsOwnedByDungeonChestFinder(kind)
    kind = tostring(kind or "")
    if kind ~= "CHEST" and kind ~= "HEAVYSACK" then return false end
    if not EPC.saved or EPC.saved.dungeonChestFinderEnabled == false then return false end
    local now = nowMs()
    if self.dungeonChestOwnershipCheckedAt and (now - self.dungeonChestOwnershipCheckedAt) < 750 then
        return self.dungeonChestOwnershipActive == true
    end
    local finder = EPC.DungeonChestFinder
    if not finder or type(finder.IsSupportedInstance) ~= "function" then return false end
    local ok, active = pcall(finder.IsSupportedInstance, finder)
    self.dungeonChestOwnershipCheckedAt = now
    self.dungeonChestOwnershipActive = ok and active == true
    return self.dungeonChestOwnershipActive == true
end

function R:CompactLearnedLocationData()
    if not EPC.saved or type(EPC.saved.resourcePinLocations) ~= "table" then return 0 end
    local removed = 0
    for zoneKey, bucket in pairs(EPC.saved.resourcePinLocations) do
        if type(bucket) == "table" then
            local compact, grid = {}, {}
            for i = 1, #bucket do
                local entry = bucket[i]
                local x = type(entry) == "table" and tonumber(entry.x) or nil
                local y = type(entry) == "table" and tonumber(entry.y) or nil
                local z = type(entry) == "table" and tonumber(entry.z) or nil
                if x and y and z then
                    local kind = tostring(entry.kind or "RESOURCE")
                    local dedupeCm = dedupeDistanceForKind(kind)
                    local _, gx, gz = gridKey(x, z, dedupeCm)
                    local duplicate = nil
                    for dx = -1, 1 do
                        for dz = -1, 1 do
                            local nearby = grid[tostring(gx + dx) .. ":" .. tostring(gz + dz)]
                            if nearby then
                                for j = 1, #nearby do
                                    local other = nearby[j]
                                    local otherKind = tostring(other.kind or "RESOURCE")
                                    local compatibleKind = otherKind == kind or otherKind == "RESOURCE" or kind == "RESOURCE"
                                    if compatibleKind
                                        and math.abs((tonumber(other.y) or 0) - y) <= 600
                                        and distance2Dcm(other.x, other.z, x, z) <= math.max(dedupeCm, dedupeDistanceForKind(otherKind)) then
                                        duplicate = other
                                        break
                                    end
                                end
                            end
                            if duplicate then break end
                        end
                        if duplicate then break end
                    end
                    if duplicate then
                        if tostring(duplicate.kind or "RESOURCE") == "RESOURCE" and kind ~= "RESOURCE" then duplicate.kind = kind end
                        if (not duplicate.name or duplicate.name == "") and entry.name and entry.name ~= "" then duplicate.name = entry.name end
                        duplicate.lastSeenAt = math.max(tonumber(duplicate.lastSeenAt) or 0, tonumber(entry.lastSeenAt) or 0)
                        removed = removed + 1
                    else
                        compact[#compact + 1] = entry
                        local key = tostring(gx) .. ":" .. tostring(gz)
                        grid[key] = grid[key] or {}
                        grid[key][#grid[key] + 1] = entry
                    end
                else
                    removed = removed + 1
                end
            end
            EPC.saved.resourcePinLocations[zoneKey] = compact
        end
    end
    self.lastLearnedCompactionRemoved = removed
    return removed
end

local DeduplicateVisibleCandidatesImplArch

function R:DeduplicateVisibleCandidates(...)

    return DeduplicateVisibleCandidatesImplArch(self, ...)

end

DeduplicateVisibleCandidatesImplArch = function(self, visible)
    if type(visible) ~= "table" or #visible < 2 then return visible, 0 end
    table.sort(visible, function(a, b)
        if a.debug ~= b.debug then return a.debug == true end
        if a.focusedMissing ~= b.focusedMissing then return a.focusedMissing == true end
        -- A zone only has a small number of nearby uncollected skyshards. Give
        -- them priority inside the bounded pool so dense resource areas cannot
        -- push every Skyshard out of the moving-player marker cap.
        if a.skyshard ~= b.skyshard then return a.skyshard == true end
        if a.learned ~= b.learned then return a.learned == true end
        return (tonumber(a.distanceM) or 999999) < (tonumber(b.distanceM) or 999999)
    end)
    local out, grid, removed = {}, {}, 0
    for i = 1, #visible do
        local candidate = visible[i]
        local entry = candidate and candidate.entry
        if candidate.debug == true or type(entry) ~= "table" then
            out[#out + 1] = candidate
        else
            local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
            local kind = tostring(entry.kind or "RESOURCE")
            local duplicate = false
            if x and y and z then
                local dedupeCm = dedupeDistanceForKind(kind)
                local _, gx, gz = gridKey(x, z, dedupeCm)
                local gridPrefix = tostring(dedupeCm) .. ":"
                for dx = -1, 1 do
                    for dz = -1, 1 do
                        local nearby = grid[gridPrefix .. tostring(gx + dx) .. ":" .. tostring(gz + dz)]
                        if nearby then
                            for j = 1, #nearby do
                                local other = nearby[j]
                                local otherKind = tostring(other.kind or "RESOURCE")
                                local compatibleKind = otherKind == kind or otherKind == "RESOURCE" or kind == "RESOURCE"
                                if compatibleKind
                                    and math.abs((tonumber(other.y) or 0) - y) <= 600
                                    and distance2Dcm(other.x, other.z, x, z) <= math.max(dedupeCm, dedupeDistanceForKind(otherKind)) then
                                    duplicate = true
                                    break
                                end
                            end
                        end
                        if duplicate then break end
                    end
                    if duplicate then break end
                end
                if not duplicate then
                    local key = gridPrefix .. tostring(gx) .. ":" .. tostring(gz)
                    grid[key] = grid[key] or {}
                    grid[key][#grid[key] + 1] = entry
                end
            end
            if duplicate then removed = removed + 1 else out[#out + 1] = candidate end
        end
    end
    self.lastVisibleDuplicatesRemoved = removed
    return out, removed
end

function R:GetZoneBucket(zoneId, create)
    if not EPC.saved then return nil end
    EPC.saved.resourcePinLocations = EPC.saved.resourcePinLocations or {}
    local key = tostring(tonumber(zoneId) or zoneId or "")
    if key == "" then return nil end
    local bucket = EPC.saved.resourcePinLocations[key]
    if create and type(bucket) ~= "table" then
        bucket = {}
        EPC.saved.resourcePinLocations[key] = bucket
    end
    return bucket, key
end

function R:EntryKey(zoneId, index)
    return tostring(zoneId or "") .. ":" .. tostring(index or 0)
end


function R:AddCommunityNode(cache, dedupe, kind, x, y, z)
    if type(cache) ~= "table" or type(dedupe) ~= "table" then return false end
    if not kind then return false end

    -- Mirror the Suite's learned-node merge radius so aliased community records
    -- (for example ore/jewelry and rune/portal records) do not create double pins.
    local communityDedupeCm = tostring(kind) == "FISHING" and FISHING_DEDUPE_DISTANCE_CM or COMMUNITY_DEDUPE_CM
    local _, gx, gz = gridKey(x, z, communityDedupeCm)
    for dx = -1, 1 do
        for dz = -1, 1 do
            local key = tostring(kind) .. ":" .. tostring(communityDedupeCm) .. ":" .. tostring(gx + dx) .. ":" .. tostring(gz + dz)
            local nearby = dedupe[key]
            if type(nearby) == "table" then
                for i = 1, #nearby do
                    local other = nearby[i]
                    if type(other) == "table"
                        and math.abs((tonumber(other.y) or 0) - (tonumber(y) or 0)) <= 600
                        and distance2Dcm(other.x, other.z, x, z) <= communityDedupeCm then
                        return false
                    end
                end
            end
        end
    end

    local entry = {
        kind = tostring(kind),
        name = TYPE_LABELS[kind] or "Community Resource",
        x = tonumber(x), y = tonumber(y), z = tonumber(z),
        source = "community",
    }
    if not entry.x or not entry.y or not entry.z then return false end

    local cell = gridKey(entry.x, entry.z, COMMUNITY_GRID_CM)
    cache.cells[cell] = cache.cells[cell] or {}
    cache.cells[cell][#cache.cells[cell] + 1] = entry
    cache.count = (tonumber(cache.count) or 0) + 1
    cache.byKind[kind] = (tonumber(cache.byKind[kind]) or 0) + 1

    local ownKey = tostring(kind) .. ":" .. tostring(communityDedupeCm) .. ":" .. tostring(gx) .. ":" .. tostring(gz)
    dedupe[ownKey] = dedupe[ownKey] or {}
    dedupe[ownKey][#dedupe[ownKey] + 1] = entry
    return true
end

function R:DecodeCommunityPacked(cache, dedupe, kind, packed)
    if type(packed) ~= "string" or packed == "" then return 0 end
    if (#packed % 8) ~= 0 then
        cache.corruptRecords = (tonumber(cache.corruptRecords) or 0) + 1
        return 0
    end

    local added = 0
    cache.rawCount = (tonumber(cache.rawCount) or 0) + (#packed / 8)
    for offset = 1, #packed, 8 do
        local x1, x2, h1, h2, v1, v2 = string.byte(packed, offset, offset + 5)
        if x1 and x2 and h1 and h2 and v1 and v2 then
            -- Database X/Y are horizontal meters; database Z is vertical meters.
            -- Each unsigned 16-bit value is stored in 0.2m units. Convert directly
            -- to raw-world centimeters (0.2m == 20cm) and remap to ESO X/Y/Z.
            local x = ((x1 * 256) + x2) * 20
            local z = ((h1 * 256) + h2) * 20
            local y = ((v1 * 256) + v2) * 20
            if self:AddCommunityNode(cache, dedupe, kind, x, y, z) then added = added + 1 end
        end
    end
    return added
end

local BuildCommunityZoneCacheImplArch

function R:BuildCommunityZoneCache(...)

    return BuildCommunityZoneCacheImplArch(self, ...)

end

BuildCommunityZoneCacheImplArch = function(self, zoneId, forceForExplicitHunt)
    -- v0.29.238: an explicit Potion Maker hunt is allowed to use the bundled
    -- resource database even when the user's normal community-pin display is
    -- disabled. Clicking MAP + 3D MISSING is an explicit one-off request.
    if not EPC.saved then return nil end
    if EPC.saved.resourcePinsCommunityEnabled == false and forceForExplicitHunt ~= true then return nil end
    zoneId = tonumber(zoneId)
    if not zoneId then return nil end
    if self.communityZoneId == zoneId and type(self.communityZoneCache) == "table" then
        return self.communityZoneCache
    end

    local root = EPC.CommunityResourceData
    if type(root) ~= "table" then
        self.lastCommunityError = "Suite Community Resource Data is not loaded"
        return nil
    end

    -- Keep only one decoded zone at a time. The packed 124k-node dataset stays
    -- compact in memory while the current zone gets a fast 50m spatial index.
    local cache = { zoneId = zoneId, cells = {}, count = 0, rawCount = 0, byKind = {}, corruptRecords = 0 }
    local dedupe = {}
    for m = 1, #COMMUNITY_MODULES do
        local module = root[COMMUNITY_MODULES[m]]
        local zoneData = type(module) == "table" and module[zoneId] or nil
        if type(zoneData) == "table" then
            for _, mapData in pairs(zoneData) do
                if type(mapData) == "table" then
                    for pinTypeId, packed in pairs(mapData) do
                        local kind = COMMUNITY_KIND_BY_PIN[tonumber(pinTypeId)]
                        if kind and type(packed) == "string" then
                            self:DecodeCommunityPacked(cache, dedupe, kind, packed)
                        end
                    end
                end
            end
        end
    end

    self.communityZoneId = zoneId
    self.communityZoneCache = cache
    self.lastCommunityZoneCount = cache.count
    self.lastCommunityRawZoneCount = cache.rawCount
    self.lastCommunityError = nil
    return cache
end

function R:BuildLearnedShadowGrid(bucket)
    local shadow = {}
    if type(bucket) ~= "table" then return shadow end
    for i = 1, #bucket do
        local entry = bucket[i]
        if type(entry) == "table" and tonumber(entry.x) and tonumber(entry.z) then
            local key = gridKey(entry.x, entry.z, DEDUPE_DISTANCE_CM)
            shadow[key] = shadow[key] or {}
            shadow[key][#shadow[key] + 1] = entry
        end
    end
    return shadow
end

local IsCommunityShadowedImplArch

function R:IsCommunityShadowed(...)

    return IsCommunityShadowedImplArch(self, ...)

end

IsCommunityShadowedImplArch = function(self, entry, shadow)
    if type(entry) ~= "table" or type(shadow) ~= "table" then return false end
    local _, gx, gz = gridKey(entry.x, entry.z, DEDUPE_DISTANCE_CM)
    for dx = -1, 1 do
        for dz = -1, 1 do
            local key = tostring(gx + dx) .. ":" .. tostring(gz + dz)
            local nearby = shadow[key]
            if type(nearby) == "table" then
                for i = 1, #nearby do
                    local learned = nearby[i]
                    if math.abs((tonumber(learned.y) or 0) - (tonumber(entry.y) or 0)) <= 600
                        and distance2Dcm(learned.x, learned.z, entry.x, entry.z) <= DEDUPE_DISTANCE_CM then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function R:AppendAllCommunity(zoneId, px, py, pz, visible, learnedShadow)
    if not EPC.saved or EPC.saved.resourcePinsCommunityEnabled == false then
        self.lastCommunityZoneCount = 0
        return 0
    end
    local cache = self:BuildCommunityZoneCache(zoneId)
    if type(cache) ~= "table" then return 0 end

    local added = 0
    for _, list in pairs(cache.cells or {}) do
        if type(list) == "table" then
            for i = 1, #list do
                local entry = list[i]
                if type(entry) == "table" and self:IsKindEnabled(entry.kind)
                    and not self:IsPositionDepleted(zoneId, entry.x, entry.z, entry.kind)
                    and not self:IsCommunityShadowed(entry, learnedShadow) then
                    local distanceM = distance3Dcm(px, py, pz, entry.x, entry.y, entry.z) / 100
                    visible[#visible + 1] = { entry = entry, distanceM = distanceM, community = true }
                    added = added + 1
                end
            end
        end
    end
    return added
end

function R:AppendNearbyCommunity(zoneId, px, py, pz, maxDistanceM, visible, learnedShadow)
    if not EPC.saved or EPC.saved.resourcePinsCommunityEnabled == false then
        self.lastCommunityZoneCount = 0
        return 0
    end
    local cache = self:BuildCommunityZoneCache(zoneId)
    if type(cache) ~= "table" then return 0 end

    local maxDistanceCm = (tonumber(maxDistanceM) or 125) * 100
    local _, centerX, centerZ = gridKey(px, pz, COMMUNITY_GRID_CM)
    local radius = math.max(1, math.ceil(maxDistanceCm / COMMUNITY_GRID_CM))
    local added = 0
    for gx = centerX - radius, centerX + radius do
        for gz = centerZ - radius, centerZ + radius do
            local list = cache.cells[tostring(gx) .. ":" .. tostring(gz)]
            if type(list) == "table" then
                for i = 1, #list do
                    local entry = list[i]
                    if type(entry) == "table" and self:IsKindEnabled(entry.kind)
                        and not self:IsPositionDepleted(zoneId, entry.x, entry.z, entry.kind)
                        and not self:IsCommunityShadowed(entry, learnedShadow) then
                        local distanceM = distance3Dcm(px, py, pz, entry.x, entry.y, entry.z) / 100
                        local horizontalDistanceM = distance2Dcm(px, pz, entry.x, entry.z) / 100
                        if distanceM <= maxDistanceM then
                            visible[#visible + 1] = { entry = entry, distanceM = distanceM, horizontalDistanceM = horizontalDistanceM, community = true }
                            added = added + 1
                        end
                    end
                end
            end
        end
    end
    return added
end

local function normalizeMissingMaterialName(value)
    local s = lower(value)
    s = s:gsub("[’`]", "'")
    s = s:gsub("[^%w']+", " ")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

function R:GetMissingAlchemyKinds(material)
    local kind = type(material) == "table" and tostring(material.kind or "") or ""
    if kind == "" then return {} end
    if kind == "FLOWER" or kind == "MUSHROOM" or kind == "WATERPLANT" then
        return { [kind] = true, ALCHEMY = true }
    elseif kind == "PROVISIONING" then
        -- Provisioning ingredients commonly come from containers rather than
        -- deterministic harvest nodes. Learned provisioning containers are the
        -- strongest source, while Heavy Sacks are a known possible source.
        return { PROVISIONING = true, HEAVYSACK = true }
    elseif kind == "ENCHANTING" then
        return { RUNE = true }
    end
    return { [kind] = true }
end

function R:EnsureMissingAlchemyMapPins()
    if self.missingAlchemyPinType then return true end
    if type(ZO_WorldMap_GetPinManager) ~= "function" then return false end
    local pinManager = ZO_WorldMap_GetPinManager()
    if not pinManager or type(pinManager.AddCustomPin) ~= "function" then return false end

    local tint = type(ZO_ColorDef) == "table" and ZO_ColorDef.New and ZO_ColorDef:New(1.00, 0.78, 0.18) or nil
    local layout = {
        texture = NATIVE_ICON_TEXTURES.ALCHEMY,
        level = 50,
        size = 42,
        tint = tint,
    }
    local tooltipData = nil
    if rawget(_G, "ZO_MAP_TOOLTIP_MODE") and rawget(_G, "ZO_WorldMap_GetTooltipForMode") then
        tooltipData = {
            creator = function(pin)
                local tooltip = ZO_WorldMap_GetTooltipForMode(ZO_MAP_TOOLTIP_MODE.INFORMATION)
                local focus = self.missingAlchemyFocus
                local title = focus and focus.summary or "Missing Alchemy Material"
                if tooltip and tooltip.AddLine then
                    local huntName = focus and focus.craftLabel and (tostring(focus.craftLabel):upper() .. " MATERIAL HUNT") or "CRAFTING MATERIAL HUNT"
                    tooltip:AddLine(huntName, "ZoFontWinH4", 1, 0.82, 0.24)
                    tooltip:AddLine(tostring(title), "ZoFontGame", 1, 1, 1)
                    tooltip:AddLine("Approach this area to see the bright 3D hunt pin.", "ZoFontGameSmall", 0.72, 0.84, 0.95)
                end
            end,
            tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
        }
    end

    local ok = pcall(pinManager.AddCustomPin, pinManager, MISSING_ALCHEMY_PIN_TYPE_STRING,
        function(mgr) self:AddMissingAlchemyMapPins(mgr) end,
        nil, layout, tooltipData)
    if not ok then return false end
    self.missingAlchemyPinType = rawget(_G, MISSING_ALCHEMY_PIN_TYPE_STRING)
    if self.missingAlchemyPinType and type(pinManager.SetCustomPinEnabled) == "function" then
        pcall(pinManager.SetCustomPinEnabled, pinManager, self.missingAlchemyPinType, true)
    end
    return self.missingAlchemyPinType ~= nil
end

function R:AddMissingAlchemyMapPins(pinManager)
    if not self.missingAlchemyPinType or not pinManager or type(pinManager.CreatePin) ~= "function" then return end
    local focus = self.missingAlchemyFocus
    local locations = focus and focus.locations or nil
    if type(locations) ~= "table" then return end
    for i = 1, #locations do
        local loc = locations[i]
        if type(loc) == "table" and tonumber(loc.zoneId) and tonumber(loc.x) and tonumber(loc.y) and tonumber(loc.z)
            and type(GetNormalizedWorldPosition) == "function" then
            local nx, ny = safe(GetNormalizedWorldPosition, nil, loc.zoneId, loc.x, loc.z, loc.y)
            nx, ny = tonumber(nx), tonumber(ny)
            if nx and ny and nx >= -0.01 and nx <= 1.01 and ny >= -0.01 and ny <= 1.01 then
                pcall(pinManager.CreatePin, pinManager, self.missingAlchemyPinType, loc, nx, ny)
            end
        end
    end
end

function R:RefreshMissingAlchemyMapPins()
    if not self:EnsureMissingAlchemyMapPins() then return end
    local pinManager = ZO_WorldMap_GetPinManager and ZO_WorldMap_GetPinManager() or nil
    if pinManager and self.missingAlchemyPinType and type(pinManager.RefreshCustomPins) == "function" then
        pcall(pinManager.RefreshCustomPins, pinManager, self.missingAlchemyPinType)
    end
end

function R:ClearMissingAlchemyFocus()
    self.missingAlchemyFocus = nil
    self:RefreshMissingAlchemyMapPins()
    self:RefreshMarkers()
end

function R:BuildMissingAlchemyFocusForCurrentZone()
    local focus = self.missingAlchemyFocus
    if type(focus) ~= "table" or type(focus.materials) ~= "table" or #focus.materials == 0 then return 0, {} end
    local zoneId, px, py, pz = self:GetPlayerRawPosition()
    if not zoneId then return 0, {} end

    local learned = self:GetZoneBucket(zoneId, false)
    if type(learned) ~= "table" then learned = {} end
    local community = self:BuildCommunityZoneCache(zoneId, true)
    local final, finalByKey, unsupported = {}, {}, {}

    local function distanceFor(entry)
        return distance2Dcm(px, pz, tonumber(entry.x) or px, tonumber(entry.z) or pz) / 100
    end

    local function locationKey(entry)
        return string.format("%d:%d:%s", math.floor((tonumber(entry.x) or 0) + 0.5), math.floor((tonumber(entry.z) or 0) + 0.5), tostring(entry.kind or "RESOURCE"))
    end

    for _, material in ipairs(focus.materials) do
        local targetName = tostring(material.name or "Missing material")
        local targetKey = normalizeMissingMaterialName(material.key or targetName)
        local kinds = self:GetMissingAlchemyKinds(material)
        local candidates = {}

        local function consider(entry, sourceRank)
            if type(entry) ~= "table" then return end
            local ex, ey, ez = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
            if not ex or not ey or not ez then return end
            if self:IsPositionDepleted(zoneId, ex, ez, entry.kind) then return end
            local entryKey = normalizeMissingMaterialName(entry.name or "")
            local exact = targetKey ~= "" and entryKey ~= "" and entryKey == targetKey
            if not exact and targetKey ~= "" and type(entry.provisionLoot) == "table" then
                exact = entry.provisionLoot[targetKey] == true
            end
            local kindMatch = kinds[tostring(entry.kind or "")] == true
            if not exact and not kindMatch then return end
            candidates[#candidates + 1] = {
                entry = entry,
                exact = exact,
                score = exact and 0 or (sourceRank or 2),
                distanceM = distanceFor(entry),
            }
        end

        for i = 1, #learned do consider(learned[i], 1) end
        if type(community) == "table" and type(community.cells) == "table" and next(kinds) ~= nil then
            for _, cellEntries in pairs(community.cells) do
                if type(cellEntries) == "table" then
                    for i = 1, #cellEntries do consider(cellEntries[i], 2) end
                end
            end
        end

        table.sort(candidates, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            return (a.distanceM or 999999) < (b.distanceM or 999999)
        end)

        local taken = 0
        for i = 1, #candidates do
            if taken >= MISSING_ALCHEMY_PER_MATERIAL or #final >= MISSING_ALCHEMY_MAX_MAP_PINS then break end
            local source = candidates[i].entry
            local key = locationKey(source)
            local loc = finalByKey[key]
            if not loc then
                loc = {
                    zoneId = zoneId,
                    x = tonumber(source.x), y = tonumber(source.y), z = tonumber(source.z),
                    kind = tostring(source.kind or material.kind or "ALCHEMY"),
                    name = tostring(source.name or targetName),
                    source = tostring(source.source or "community"),
                    focusMissing = true,
                    focusMaterial = targetName,
                    focusExact = candidates[i].exact == true,
                }
                final[#final + 1] = loc
                finalByKey[key] = loc
            elseif not string.find("|" .. tostring(loc.focusMaterial) .. "|", "|" .. targetName .. "|", 1, true) then
                loc.focusMaterial = tostring(loc.focusMaterial) .. " / " .. targetName
            end
            taken = taken + 1
        end

        if taken == 0 then
            local hint = tostring(material.dynamicHint or "")
            unsupported[#unsupported + 1] = hint ~= "" and (targetName .. " (" .. hint .. ")") or targetName
        end
    end

    focus.zoneId = zoneId
    focus.locations = final
    focus.unsupported = unsupported
    local names = {}
    for _, material in ipairs(focus.materials) do names[#names + 1] = tostring(material.name or "material") end
    focus.summary = table.concat(names, ", ")
    self.missingAlchemyFocus = focus
    self:RefreshMissingAlchemyMapPins()
    self:RefreshMarkers()
    return #final, unsupported
end

local function missingAlchemyZoneName(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId > 0 and type(GetZoneNameById) == "function" then
        local ok, name = pcall(GetZoneNameById, zoneId)
        if ok and tostring(name or "") ~= "" then return zo_strformat("<<C:1>>", name) end
    end
    return zoneId > 0 and ("Zone " .. tostring(zoneId)) or "Unknown zone"
end

local function decodeFirstCommunityPoint(packed)
    if type(packed) ~= "string" or #packed < 8 then return nil end
    local x1, x2, h1, h2, v1, v2 = string.byte(packed, 1, 6)
    if not x1 or not x2 or not h1 or not h2 or not v1 or not v2 then return nil end
    return {
        x = ((x1 * 256) + x2) * 20,
        z = ((h1 * 256) + h2) * 20,
        y = ((v1 * 256) + v2) * 20,
    }
end

function R:GetMissingAlchemyDestinationSignature(materials)
    local parts = {}
    for _, material in ipairs(materials or {}) do
        local name = normalizeMissingMaterialName(type(material) == "table" and (material.key or material.name) or material)
        local kind = type(material) == "table" and tostring(material.kind or "") or ""
        parts[#parts + 1] = name .. ":" .. kind
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function R:GetDiscoveredWayshrineZonesForAlchemy()
    local zones = {}
    local travel = EPC and EPC.Travel
    if not travel or type(travel.GetWayshrineNodeEntry) ~= "function" or type(GetNumFastTravelNodes) ~= "function" then return zones end
    local ok, total = pcall(GetNumFastTravelNodes)
    total = ok and tonumber(total) or 0
    for nodeIndex = 1, total do
        local entry = travel:GetWayshrineNodeEntry(nodeIndex)
        if entry then
            local zid = tonumber(entry.zoneId) or 0
            local pid = tonumber(entry.parentZoneId) or 0
            if zid > 0 then zones[zid] = true end
            if pid > 0 then zones[pid] = true end
        end
    end
    return zones
end

function R:ResolveMissingAlchemyWayshrine(destination)
    if type(destination) ~= "table" or not tonumber(destination.zoneId) then return destination end
    local travel = EPC and EPC.Travel
    if not travel or type(travel.GetWayshrineNodeEntry) ~= "function" then return destination end

    local zoneId = tonumber(destination.zoneId)
    local mapId = 0
    if type(GetMapIdByZoneId) == "function" then
        local ok, value = pcall(GetMapIdByZoneId, zoneId)
        if ok then mapId = tonumber(value) or 0 end
    end
    destination.mapId = mapId

    local originalMapId = 0
    if type(GetCurrentMapId) == "function" then
        local ok, value = pcall(GetCurrentMapId)
        if ok then originalMapId = tonumber(value) or 0 end
    end
    local switched = false
    if mapId > 0 and type(SetMapToMapId) == "function" and originalMapId ~= mapId then
        local ok = pcall(SetMapToMapId, mapId)
        switched = ok == true
    end

    local targetX, targetY = nil, nil
    if type(GetNormalizedWorldPosition) == "function" then
        local ok, nx, ny = pcall(GetNormalizedWorldPosition, zoneId, destination.x, destination.z, destination.y)
        if ok then
            nx, ny = tonumber(nx), tonumber(ny)
            if nx and ny and nx >= -0.01 and nx <= 1.01 and ny >= -0.01 and ny <= 1.01 then
                targetX, targetY = nx, ny
                destination.mapX, destination.mapY = nx, ny
            end
        end
    end

    local best, bestDistance, fallback = nil, nil, nil
    if type(GetNumFastTravelNodes) == "function" then
        local ok, total = pcall(GetNumFastTravelNodes)
        total = ok and tonumber(total) or 0
        for nodeIndex = 1, total do
            local entry = travel:GetWayshrineNodeEntry(nodeIndex)
            if entry then
                local sameZone = tonumber(entry.zoneId) == zoneId or tonumber(entry.parentZoneId) == zoneId
                if sameZone and not fallback then fallback = entry end
                if targetX and targetY and entry.isShownInCurrentMap and tonumber(entry.normalizedX) and tonumber(entry.normalizedY) then
                    local dx = tonumber(entry.normalizedX) - targetX
                    local dy = tonumber(entry.normalizedY) - targetY
                    local d2 = dx * dx + dy * dy
                    if bestDistance == nil or d2 < bestDistance then
                        best, bestDistance = entry, d2
                    end
                end
            end
        end
    end

    if switched and originalMapId > 0 and type(SetMapToMapId) == "function" then
        pcall(SetMapToMapId, originalMapId)
    elseif switched and type(SetMapToPlayerLocation) == "function" then
        pcall(SetMapToPlayerLocation)
    end

    best = best or fallback
    if best then
        destination.wayshrineNodeIndex = best.nodeIndex
        destination.wayshrineName = tostring(best.name or "Wayshrine")
    end
    return destination
end

function R:FindMissingAlchemyDestination(materials)
    if type(materials) ~= "table" or #materials == 0 then return nil end
    self.missingAlchemyDestinationCache = self.missingAlchemyDestinationCache or {}
    local signature = self:GetMissingAlchemyDestinationSignature(materials)
    if signature ~= "" and type(self.missingAlchemyDestinationCache[signature]) == "table" then
        return self.missingAlchemyDestinationCache[signature]
    end

    local wantedKinds, wantedNames = {}, {}
    local firstStaticMaterialName = nil
    for _, material in ipairs(materials) do
        if type(material) == "table" and tostring(material.dynamicHint or "") == "" then
            if not firstStaticMaterialName then firstStaticMaterialName = tostring(material.name or "Alchemy material") end
            local kinds = self:GetMissingAlchemyKinds(material)
            for kind in pairs(kinds) do wantedKinds[kind] = true end
            local key = normalizeMissingMaterialName(material.key or material.name)
            if key ~= "" then wantedNames[key] = tostring(material.name or key) end
        end
    end
    if next(wantedKinds) == nil then return nil end

    local playerZoneId = select(1, self:GetPlayerRawPosition())
    playerZoneId = tonumber(playerZoneId) or 0
    local shrineZones = self:GetDiscoveredWayshrineZonesForAlchemy()
    local candidates = {}

    local function getCandidate(zoneId)
        zoneId = tonumber(zoneId) or 0
        if zoneId <= 0 then return nil end
        local c = candidates[zoneId]
        if not c then
            c = { zoneId = zoneId, nodeCount = 0, kindCoverage = {}, exact = false }
            candidates[zoneId] = c
        end
        return c
    end

    -- Prefer the player's own learned resource positions when available.
    local learnedRoot = EPC.saved and EPC.saved.resourcePinLocations
    if type(learnedRoot) == "table" then
        for zoneKey, entries in pairs(learnedRoot) do
            local c = getCandidate(zoneKey)
            if c and type(entries) == "table" then
                for _, entry in ipairs(entries) do
                    if type(entry) == "table" then
                        local kind = tostring(entry.kind or "")
                        local entryName = normalizeMissingMaterialName(entry.name or "")
                        local exact = wantedNames[entryName] ~= nil
                        if exact or wantedKinds[kind] then
                            c.nodeCount = c.nodeCount + 1
                            c.kindCoverage[kind] = true
                            if exact then c.exact = true end
                            if not c.point or exact then
                                c.point = { x=tonumber(entry.x), y=tonumber(entry.y), z=tonumber(entry.z), kind=kind, name=tostring(entry.name or "Alchemy resource"), source="learned" }
                            end
                        end
                    end
                end
            end
        end
    end

    -- Scan the packed community index without decoding whole zones. String
    -- lengths give a cheap node count; only one representative point is decoded.
    local root = EPC.CommunityResourceData
    if type(root) == "table" then
        for m = 1, #COMMUNITY_MODULES do
            local module = root[COMMUNITY_MODULES[m]]
            if type(module) == "table" then
                for zoneId, zoneData in pairs(module) do
                    local c = getCandidate(zoneId)
                    if c and type(zoneData) == "table" then
                        for _, mapData in pairs(zoneData) do
                            if type(mapData) == "table" then
                                for pinTypeId, packed in pairs(mapData) do
                                    local kind = COMMUNITY_KIND_BY_PIN[tonumber(pinTypeId)]
                                    if kind and wantedKinds[kind] and type(packed) == "string" and #packed >= 8 then
                                        c.nodeCount = c.nodeCount + math.floor(#packed / 8)
                                        c.kindCoverage[kind] = true
                                        if not c.point then
                                            local point = decodeFirstCommunityPoint(packed)
                                            if point then
                                                point.kind, point.name, point.source = kind, TYPE_LABELS[kind] or "Alchemy resource", "community"
                                                c.point = point
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local best, bestScore = nil, nil
    for zoneId, c in pairs(candidates) do
        if c.point and c.nodeCount > 0 then
            local coverage = 0
            for _ in pairs(c.kindCoverage) do coverage = coverage + 1 end
            local score = math.min(c.nodeCount, 5000) + coverage * 10000
            if c.exact then score = score + 50000 end
            if shrineZones[zoneId] then score = score + 100000 end
            if zoneId == playerZoneId then score = score + 1000000 end
            if bestScore == nil or score > bestScore then best, bestScore = c, score end
        end
    end
    if not best then return nil end

    local destination = {
        zoneId = tonumber(best.zoneId),
        zoneName = missingAlchemyZoneName(best.zoneId),
        x = tonumber(best.point.x), y = tonumber(best.point.y), z = tonumber(best.point.z),
        kind = tostring(best.point.kind or "ALCHEMY"),
        resourceName = best.exact and tostring(best.point.name or firstStaticMaterialName or "Alchemy resource")
            or string.format("%s spawn area", tostring(firstStaticMaterialName or TYPE_LABELS[best.point.kind] or "Alchemy material")),
        source = tostring(best.point.source or "community"),
        nodeCount = tonumber(best.nodeCount) or 0,
    }
    self:ResolveMissingAlchemyWayshrine(destination)
    if destination.mapX and destination.mapY then
        destination.locationText = string.format("%.1f, %.1f", destination.mapX * 100, destination.mapY * 100)
    else
        destination.locationText = "known resource area"
    end
    if signature ~= "" then self.missingAlchemyDestinationCache[signature] = destination end
    return destination
end

function R:GetMissingAlchemyRoute(materials)
    local destination = self:FindMissingAlchemyDestination(materials)
    if not destination then return nil end
    return destination
end

function R:TravelToMissingAlchemyMaterials(materials)
    if type(materials) ~= "table" or #materials == 0 then return false end
    local destination = self:FindMissingAlchemyDestination(materials)
    if not destination then
        if EPC and EPC.Print then EPC:Print("No fixed resource zone could be resolved for those missing Alchemy materials.") end
        return false
    end
    self.missingAlchemyFocus = self.missingAlchemyFocus or { materials = materials, locations = {}, summary = "Missing Alchemy Materials" }
    self.missingAlchemyFocus.materials = materials
    self.missingAlchemyFocus.travelDestination = destination
    self.missingAlchemyFocus.zoneId = destination.zoneId
    self.missingAlchemyFocus.locations = {{
        zoneId=destination.zoneId, x=destination.x, y=destination.y, z=destination.z,
        kind=destination.kind, name=destination.resourceName, source=destination.source,
        focusMissing=true, focusMaterial=self.missingAlchemyFocus.summary or "Alchemy material",
    }}

    local shrine = destination.wayshrineName or "No discovered wayshrine"
    if EPC and EPC.Print then
        EPC:Print(string.format("Alchemy material route: %s at %s in %s. Closest discovered wayshrine: %s.", destination.resourceName, destination.locationText or "known resource area", destination.zoneName or "Unknown zone", shrine))
    end
    if not destination.wayshrineNodeIndex then
        if EPC and EPC.Print then EPC:Print("You have no discovered wayshrine resolved for that resource zone. Use the map pin or social travel to enter the zone first.") end
        return false
    end
    local travel = EPC and EPC.Travel
    if travel and type(travel.TravelToWayshrineNode) == "function" then
        return travel:TravelToWayshrineNode(destination.wayshrineNodeIndex, destination.wayshrineName)
    end
    return false
end

function R:TrackMissingAlchemyMaterials(materials)
    if type(materials) ~= "table" or #materials == 0 then return 0, {}, nil end
    self.missingAlchemyFocus = { materials = materials, locations = {}, summary = "Missing Alchemy Materials" }
    self:EnsureMissingAlchemyMapPins()
    local tracked, unsupported = self:BuildMissingAlchemyFocusForCurrentZone()
    local destination = self:FindMissingAlchemyDestination(materials)
    if destination then
        self.missingAlchemyFocus.travelDestination = destination
        -- BuildMissingAlchemyFocusForCurrentZone reports static materials as
        -- unsupported when they simply are not in the CURRENT zone. Once a
        -- cross-zone route exists, only true dynamic-drop materials belong in
        -- the unsupported list.
        local dynamicUnsupported = {}
        for _, material in ipairs(materials) do
            if type(material) == "table" and tostring(material.dynamicHint or "") ~= "" then
                dynamicUnsupported[#dynamicUnsupported + 1] = tostring(material.name or "material") .. " (" .. tostring(material.dynamicHint) .. ")"
            end
        end
        unsupported = dynamicUnsupported
    end

    -- If the current zone has no matching static spawn, point the map at the
    -- selected resource zone now. The 3D pin will rebuild automatically after travel.
    if tracked <= 0 and destination then
        self.missingAlchemyFocus.zoneId = destination.zoneId
        self.missingAlchemyFocus.locations = {{
            zoneId=destination.zoneId, x=destination.x, y=destination.y, z=destination.z,
            kind=destination.kind, name=destination.resourceName, source=destination.source,
            focusMissing=true, focusMaterial=self.missingAlchemyFocus.summary,
        }}
        tracked = 1
        self:RefreshMissingAlchemyMapPins()
    end
    return tracked, unsupported, destination
end

function R:ShowMissingAlchemyMap()
    local focus = self.missingAlchemyFocus
    if type(focus) ~= "table" or type(focus.locations) ~= "table" or #focus.locations == 0 then return false end

    local destination = focus.travelDestination
    local playerZoneId = select(1, self:GetPlayerRawPosition())
    if type(destination) == "table" and tonumber(destination.zoneId) ~= tonumber(playerZoneId)
        and tonumber(destination.mapId) and tonumber(destination.mapId) > 0 and type(SetMapToMapId) == "function" then
        pcall(SetMapToMapId, destination.mapId)
    elseif type(SetMapToPlayerLocation) == "function" then
        pcall(SetMapToPlayerLocation)
    end

    if type(ZO_WorldMap_ShowWorldMap) == "function" then
        pcall(ZO_WorldMap_ShowWorldMap)
    elseif SCENE_MANAGER and type(SCENE_MANAGER.Show) == "function" then
        pcall(SCENE_MANAGER.Show, SCENE_MANAGER, "worldMap")
    end
    if type(zo_callLater) == "function" then
        zo_callLater(function() if EPC and EPC.ResourcePins then EPC.ResourcePins:RefreshMissingAlchemyMapPins() end end, 120)
    else
        self:RefreshMissingAlchemyMapPins()
    end
    return true
end

function R:ClassifyByName(name)
    local value = lower(name)
    if value == "" then return nil end
    if SPECIAL_NAME_KIND[value] then return SPECIAL_NAME_KIND[value] end
    local checks = {
        { "mushroom", "MUSHROOM" }, { "fungus", "MUSHROOM" },
        { "flower", "FLOWER" }, { "herb", "FLOWER" },
        { "water hyacinth", "WATERPLANT" }, { "nirnroot", "WATERPLANT" },
        { "runestone", "RUNE" }, { "rune stone", "RUNE" }, { "runenstein", "RUNE" },
        { "ore", "ORE" }, { "seam", "ORE" }, { "erz", "ORE" },
        { "wood", "WOOD" }, { "log", "WOOD" }, { "holz", "WOOD" },
        { "cloth", "CLOTH" }, { "silk", "CLOTH" }, { "fiber", "CLOTH" }, { "faser", "CLOTH" },
        { "water", "WATER" }, { "wasser", "WATER" },
        { "fishing", "FISHING" }, { "fish", "FISHING" },
        { "chest", "CHEST" }, { "safebox", "CHEST" }, { "safe box", "CHEST" },
    }
    for i = 1, #checks do
        if string.find(value, checks[i][1], 1, true) then return checks[i][2] end
    end
    return nil
end

function R:GetItemId(itemLink, fallbackItemId)
    local id = tonumber(fallbackItemId)
    if id and id > 0 then return id end
    if type(itemLink) == "string" and itemLink ~= "" and type(GetItemLinkItemId) == "function" then
        id = tonumber(safe(GetItemLinkItemId, 0, itemLink))
        if id and id > 0 then return id end
    end
    return nil
end

function R:ClassifyLoot(itemLink, pendingName, fallbackItemId, pendingKind)
    -- Generic loot containers must be classified by what they actually yielded.
    -- Preserve special resource interactions, but let CONTAINER resolve from the
    -- item type so provisioning containers can be learned accurately.
    if pendingKind and pendingKind ~= "RESOURCE" and pendingKind ~= "CONTAINER" then return pendingKind end
    local itemId = self:GetItemId(itemLink, fallbackItemId)
    if itemId and ITEM_ID_KIND[itemId] then return ITEM_ID_KIND[itemId] end
    if type(itemLink) == "string" and itemLink ~= "" and type(GetItemLinkItemType) == "function" then
        local itemType = safe(GetItemLinkItemType, nil, itemLink)
        if itemType ~= nil and ITEM_KIND[itemType] then return ITEM_KIND[itemType] end
    end
    return self:ClassifyByName(pendingName) or "RESOURCE"
end

function R:IsKindEnabled(kind)
    if not EPC.saved then return false end
    if self:IsOwnedByDungeonChestFinder(kind) then return false end

    -- Farm Focus deliberately uses its own target set. This lets the player
    -- switch back to the normal all-purpose filters without rebuilding them.
    if EPC.saved.resourcePinsFarmFocusEnabled == true then
        local farmKey = {
            ORE = "resourcePinsFarmOre", WOOD = "resourcePinsFarmWood", CLOTH = "resourcePinsFarmCloth",
            ALCHEMY = "resourcePinsFarmAlchemy", MUSHROOM = "resourcePinsFarmAlchemy", FLOWER = "resourcePinsFarmAlchemy",
            WATERPLANT = "resourcePinsFarmAlchemy", RUNE = "resourcePinsFarmRunes", WATER = "resourcePinsFarmWater",
            FISHING = "resourcePinsFarmFishing", CHEST = "resourcePinsFarmSpecial", HEAVYSACK = "resourcePinsFarmSpecial",
            CLAM = "resourcePinsFarmSpecial", TROVE = "resourcePinsFarmSpecial", JUSTICE = "resourcePinsFarmSpecial",
            STASH = "resourcePinsFarmSpecial", RESOURCE = "resourcePinsFarmOther", SKYSHARD = "resourcePinsShowSkyshards",
        }
        if kind == "SKYSHARD" then return false end
        local focusKey = farmKey[kind] or "resourcePinsFarmOther"
        return EPC.saved[focusKey] == true
    end

    local key = {
        ORE = "resourcePinsShowOre", WOOD = "resourcePinsShowWood", CLOTH = "resourcePinsShowCloth",
        ALCHEMY = "resourcePinsShowAlchemy", MUSHROOM = "resourcePinsShowAlchemy", FLOWER = "resourcePinsShowAlchemy",
        WATERPLANT = "resourcePinsShowAlchemy", RUNE = "resourcePinsShowRunes", PROVISIONING = "resourcePinsShowSpecial", WATER = "resourcePinsShowWater",
        FISHING = "resourcePinsShowFishing", CHEST = "resourcePinsShowSpecial", HEAVYSACK = "resourcePinsShowSpecial",
        CLAM = "resourcePinsShowSpecial", TROVE = "resourcePinsShowSpecial", JUSTICE = "resourcePinsShowSpecial",
        STASH = "resourcePinsShowSpecial", RESOURCE = "resourcePinsShowOther", SKYSHARD = "resourcePinsShowSkyshards",
    }
    local savedKey = key[kind] or "resourcePinsShowOther"
    return EPC.saved[savedKey] ~= false
end

function R:SetAllFarmTargets(enabled)
    if not EPC.saved then return end
    enabled = enabled == true
    EPC.saved.resourcePinsFarmOre = enabled
    EPC.saved.resourcePinsFarmWood = enabled
    EPC.saved.resourcePinsFarmCloth = enabled
    EPC.saved.resourcePinsFarmAlchemy = enabled
    EPC.saved.resourcePinsFarmRunes = enabled
    EPC.saved.resourcePinsFarmWater = enabled
    EPC.saved.resourcePinsFarmFishing = enabled
    EPC.saved.resourcePinsFarmSpecial = enabled
    EPC.saved.resourcePinsFarmOther = enabled
    self:RefreshSettings()
end

function R:GetFarmTargetSummary()
    if not EPC.saved or EPC.saved.resourcePinsFarmFocusEnabled ~= true then return "OFF" end
    local selected = {}
    local values = {
        {"resourcePinsFarmOre","Ore"}, {"resourcePinsFarmWood","Wood"}, {"resourcePinsFarmCloth","Cloth"},
        {"resourcePinsFarmAlchemy","Alchemy"}, {"resourcePinsFarmRunes","Runes"}, {"resourcePinsFarmWater","Water"},
        {"resourcePinsFarmFishing","Fishing"}, {"resourcePinsFarmSpecial","Special"}, {"resourcePinsFarmOther","Other"},
    }
    for _,v in ipairs(values) do if EPC.saved[v[1]] == true then selected[#selected+1] = v[2] end end
    return #selected > 0 and table.concat(selected, ", ") or "NONE SELECTED"
end
function R:FindNearbyEntry(zoneId, x, z, maxDistanceCm)
    local bucket = self:GetZoneBucket(zoneId, false)
    if type(bucket) ~= "table" then return nil end
    local bestIndex, bestDistance
    for i = 1, #bucket do
        local entry = bucket[i]
        if type(entry) == "table" then
            local d = distance2Dcm(x, z, entry.x, entry.z)
            if d <= (maxDistanceCm or DEDUPE_DISTANCE_CM) and (not bestDistance or d < bestDistance) then
                bestIndex, bestDistance = i, d
            end
        end
    end
    return bestIndex, bestDistance
end

function R:SaveNode(kind, name, zoneId, x, y, z, source)
    if not EPC.saved or EPC.saved.resourcePinsLearn == false then return nil end
    zoneId, x, y, z = tonumber(zoneId), tonumber(x), tonumber(y), tonumber(z)
    if not zoneId or not x or not y or not z then return nil end
    kind = tostring(kind or "RESOURCE")
    if self:IsOwnedByDungeonChestFinder(kind) then return nil end
    local bucket = self:GetZoneBucket(zoneId, true)
    if not bucket then return nil end

    local nearby = self:FindNearbyEntry(zoneId, x, z, dedupeDistanceForKind(kind))
    if nearby then
        local entry = bucket[nearby]
        if entry then
            if entry.kind == "RESOURCE" and kind ~= "RESOURCE" then entry.kind = kind end
            if (not entry.name or entry.name == "") and name and name ~= "" then entry.name = tostring(name) end
            entry.lastSeenAt = nowStamp()
            entry.source = entry.source or tostring(source or "player")
        end
        return nearby
    end

    bucket[#bucket + 1] = {
        kind = kind,
        name = tostring(name or TYPE_LABELS[kind] or "Resource"),
        x = x, y = y, z = z,
        learnedAt = nowStamp(),
        lastSeenAt = nowStamp(),
        source = tostring(source or "player"),
    }
    return #bucket
end

function R:GetInteractableName()
    if type(GetGameCameraInteractableActionInfo) ~= "function" then return "" end
    local _, name = safe(GetGameCameraInteractableActionInfo, nil)
    return tostring(name or "")
end

function R:GetPendingResourceWindowMs(pending)
    local kind = type(pending) == "table" and tostring(pending.kind or "RESOURCE") or "RESOURCE"
    if kind == "FISHING" then return FISHING_RESOURCE_WINDOW_MS end
    if kind == "CHEST" then return CHEST_RESOURCE_WINDOW_MS end
    return RESOURCE_WINDOW_MS
end

function R:CapturePendingSpecialTarget(targetName, kind, now, ownInteraction)
    if not kind then return false end
    local zoneId, x, y, z = self:GetApproximateInteractablePosition()
    if not zoneId then return false end
    self.pendingResource = {
        name = tostring(targetName or ""),
        kind = tostring(kind),
        zoneId = zoneId, x = x, y = y, z = z,
        capturedAt = tonumber(now) or nowMs(),
        ownInteraction = ownInteraction == true,
        ownInteractionAt = ownInteraction == true and (tonumber(now) or nowMs()) or nil,
    }
    self.lastResourceInteractionAt = tonumber(now) or nowMs()
    return true
end

function R:CaptureResourceInteraction()
    if not EPC.saved or EPC.saved.enabled == false or EPC.saved.resourcePinsEnabled == false then return end
    if type(GetInteractionType) ~= "function" then return end

    local interactionType = safe(GetInteractionType, nil)
    local now = nowMs()
    local targetName = self:GetInteractableName()
    local targetKind = self:ClassifyByName(targetName)
    if targetName ~= "" then self.lastInteractableName = targetName end

    if INTERACTION_HARVEST ~= nil and interactionType == INTERACTION_HARVEST then
        if not self.pendingResource or (now - (tonumber(self.pendingResource.capturedAt) or 0)) > 800
            or (targetName ~= "" and targetName ~= tostring(self.pendingResource.name or "")) then
            local zoneId, x, y, z = self:GetApproximateInteractablePosition()
            if zoneId then
                self.pendingResource = { name = targetName, kind = targetKind, zoneId = zoneId, x = x, y = y, z = z, capturedAt = now }
            end
        end
        self.lastResourceInteractionAt = now
        self.lastInteractableName = targetName ~= "" and targetName or self.lastInteractableName

    elseif INTERACTION_LOOT ~= nil and interactionType == INTERACTION_LOOT and targetName ~= "" then
        -- Learn ordinary barrels/crates/sacks/cupboards only when the eventual
        -- loot proves useful. HandleLootReceived classifies the item type.
        local pending = self.pendingResource
        local stale = not pending or tostring(pending.kind or "") ~= "CONTAINER"
            or (now - (tonumber(pending.capturedAt) or 0)) > RESOURCE_WINDOW_MS
            or targetName ~= tostring(pending.name or "")
        if stale then
            self:CapturePendingSpecialTarget(targetName, "CONTAINER", now, false)
        else
            self.lastResourceInteractionAt = now
        end

    elseif INTERACTION_FISH ~= nil and interactionType == INTERACTION_FISH then
        -- Fishing can take far longer than a normal harvest animation. Keep the
        -- fishing-hole position alive until the eventual catch/loot event.
        local pending = self.pendingResource
        local stale = not pending or tostring(pending.kind or "") ~= "FISHING"
            or (now - (tonumber(pending.capturedAt) or 0)) > FISHING_RESOURCE_WINDOW_MS
            or (targetName ~= "" and tostring(pending.name or "") ~= "" and targetName ~= tostring(pending.name or ""))
        if stale then
            if self:CapturePendingSpecialTarget(targetName ~= "" and targetName or "Fishing Hole", "FISHING", now, false) then
                if EPC.saved.resourcePinsLearn ~= false then
                    local pnd = self.pendingResource
                    local index = self:SaveNode("FISHING", pnd.name ~= "" and pnd.name or "Fishing Hole", pnd.zoneId, pnd.x, pnd.y, pnd.z, "player")
                    if index then self.lastLearnedKind, self.lastLearnedName = "FISHING", pnd.name end
                end
            end
        else
            self.lastResourceInteractionAt = now
        end
        self.lastFishingSeenAt = now

    else
        -- Chests and several special containers can report INTERACTION_TYPE_NONE,
        -- so target-name detection must run even when interactionType is zero.
        local specialKind = SPECIAL_NAME_KIND[lower(targetName)] or targetKind
        if specialKind == "CHEST" or SPECIAL_NAME_KIND[lower(targetName)] ~= nil then
            local pending = self.pendingResource
            local stale = not pending or tostring(pending.kind or "") ~= tostring(specialKind)
                or (now - (tonumber(pending.capturedAt) or 0)) > 1200
                or (targetName ~= "" and targetName ~= tostring(pending.name or ""))
            if stale then
                self:CapturePendingSpecialTarget(targetName, specialKind, now, false)
            else
                self.lastResourceInteractionAt = now
            end
        end
    end

    self:UpdateNearbyDepletedProbe(interactionType, targetName)
end

function R:HandleInteractResult(result, targetName)
    if not EPC.saved or EPC.saved.resourcePinsEnabled == false then return end
    local now = nowMs()
    targetName = tostring(targetName or "")
    local targetKind = self:ClassifyByName(targetName)

    if not self.pendingResource and targetKind == "CHEST" then
        self:CapturePendingSpecialTarget(targetName, "CHEST", now, true)
    end

    if self.pendingResource then
        if targetName ~= "" then self.pendingResource.name = targetName end
        self.pendingResource.ownInteraction = true
        self.pendingResource.ownInteractionAt = now
        -- Refresh the timestamp when the player actually interacts. This is
        -- especially important before a long lockpick minigame or fishing wait.
        self.pendingResource.capturedAt = now
    end
    self.lastResourceInteractionAt = math.max(tonumber(self.lastResourceInteractionAt) or 0, now - 250)
end

function R:HandleLockpickSuccess()
    if not EPC.saved or EPC.saved.resourcePinsEnabled == false then return end
    local now = nowMs()
    local pending = self.pendingResource
    if pending and tostring(pending.kind or "") == "CHEST" then
        pending.ownInteraction = true
        pending.lockpickSucceeded = true
        pending.ownInteractionAt = now
        pending.capturedAt = now
        self.lastResourceInteractionAt = now
        return
    end

    -- Be conservative: lockpick success can also belong to doors. Only create a
    -- chest pending state when the last positively observed interactable was a chest.
    if self:ClassifyByName(self.lastInteractableName) == "CHEST" then
        if self:CapturePendingSpecialTarget(self.lastInteractableName, "CHEST", now, true) then
            self.pendingResource.lockpickSucceeded = true
        end
    end
end

function R:HandleLootReceived(receivedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
    if not EPC.saved or EPC.saved.resourcePinsEnabled == false then return end
    if lootedBySelf ~= true then return end

    local now = nowMs()
    local pending = self.pendingResource
    local resourceWindowMs = self:GetPendingResourceWindowMs(pending)
    if not pending or (now - (tonumber(pending.capturedAt) or 0)) > resourceWindowMs then return end
    if (now - (tonumber(self.lastResourceInteractionAt) or 0)) > resourceWindowMs then return end

    local kind = self:ClassifyLoot(itemLink, pending.name, itemId, pending.kind)
    local index = nil
    if EPC.saved.resourcePinsLearn ~= false then
        index = self:SaveNode(kind, pending.name, pending.zoneId, pending.x, pending.y, pending.z, "player")
        if kind == "PROVISIONING" and index then
            local bucket = self:GetZoneBucket(pending.zoneId, false)
            local entry = type(bucket) == "table" and bucket[index] or nil
            if type(entry) == "table" then
                local lootName = ""
                if type(GetItemLinkName) == "function" then
                    local okName, value = pcall(GetItemLinkName, itemLink)
                    if okName then lootName = tostring(value or "") end
                end
                if lootName == "" then lootName = tostring(itemLink or "") end
                local lootKey = normalizeMissingMaterialName(lootName)
                if lootKey ~= "" then
                    entry.provisionLoot = type(entry.provisionLoot) == "table" and entry.provisionLoot or {}
                    entry.provisionLoot[lootKey] = true
                    entry.lastProvisionLoot = lootName
                end
            end
        end
    end
    self.lastLearnedKind = kind
    self.lastLearnedName = tostring(pending.name or TYPE_LABELS[kind] or "Resource")
    self.lastLearnedAt = now
    local depletedReason = "harvested"
    local depletedKind = kind
    local depletedRadiusCm = nil
    local sameKindOnly = false
    if tostring(pending.kind or "") == "FISHING" then
        self:MarkFishingCommunityClusterDepleted(pending.zoneId, pending.x, pending.y, pending.z)
    else
        if tostring(pending.kind or "") == "CHEST" then
            depletedReason = "chest looted"
            depletedKind = "CHEST"
        end
        -- A depletion record must never hide a different resource type that
        -- happens to be beside the harvested node. The generous position radius
        -- is retained only to absorb community-coordinate drift for the SAME type.
        sameKindOnly = true
        self:MarkPositionDepleted(pending.zoneId, pending.x, pending.z, depletedReason, depletedKind, depletedRadiusCm, sameKindOnly)
    end
    self.lastOwnCollectionAt = now
    self.pendingResource = nil
    self.liveCommunityNode = nil
    self.liveCommunityVanishedAt = 0
    self:RefreshMarkers()
end

function R:EnsureWindow()
    if self.window then return end

    -- Resource Pins deliberately use the exact same world-pin control pattern
    -- as the Suite's working LoreBooks 3D pins: a top-level render-space root
    -- plus one pooled Texture control per marker. No child beam/icon render
    -- spaces are used here.
    local win = EAS_ResourceWorldPins
    if not win then
        win = wm:CreateTopLevelWindow("EAS_ResourceWorldPinsFallback")
    end
    self.window = win
    win:SetHidden(false)
    if type(win.SetMouseEnabled) == "function" then win:SetMouseEnabled(false) end
    if type(win.Create3DRenderSpace) == "function" then
        local hasSpace = type(win.Has3DRenderSpace) == "function" and win:Has3DRenderSpace()
        if not hasSpace then win:Create3DRenderSpace() end
    end

    if ZO_ControlPool then
        self.worldControlPool = ZO_ControlPool:New("EAS_ResourceWorldPin", win, "EAS_ResourceWorldPin")
    end

    if ZO_SimpleSceneFragment and type(ZO_SimpleSceneFragment.New) == "function" then
        local ok, fragment = pcall(ZO_SimpleSceneFragment.New, ZO_SimpleSceneFragment, win)
        if ok and fragment then
            self.worldFragment = fragment
            local scenes = { HUD_UI_SCENE, HUD_SCENE, LOOT_SCENE }
            for i = 1, #scenes do
                local scene = scenes[i]
                if scene and type(scene.AddFragment) == "function" then
                    pcall(scene.AddFragment, scene, fragment)
                end
            end
        end
    end

    self.worldRenderOriginReady = false
    self:UpdateWorldRenderOrigin()
end


function R:UpdateWorldRenderOrigin()
    if not self.window or type(WorldPositionToGuiRender3DPosition) ~= "function" then
        self.worldRenderOriginReady = false
        return false
    end

    -- The working resource-world renderer anchors the root at the GUI-space
    -- representation of raw world origin, then places each marker using normal
    -- world meters relative to that root. Do not convert each child a second
    -- time; doing so was the main difference between the working source
    -- renderer and the earlier Suite port.
    local gx, gz, gy = safe(WorldPositionToGuiRender3DPosition, nil, 0, 0, 0)
    gx, gz, gy = tonumber(gx), tonumber(gz), tonumber(gy)
    if not gx or not gz or not gy or type(self.window.Set3DRenderSpaceOrigin) ~= "function" then
        self.worldRenderOriginReady = false
        return false
    end

    self.renderOriginX, self.renderOriginZ, self.renderOriginY = gx, gz, gy
    self.window:Set3DRenderSpaceOrigin(gx, gz, gy)
    self.worldRenderOriginReady = true
    return true
end


function R:ResetRenderSpace()
    self:EnsureWindow()
    self:HideAll("render space refresh")
    -- Do not destroy/recreate pooled marker render spaces on zone changes.
    -- LoreBooks keeps the controls alive and only refreshes the root origin.
    self.worldRenderOriginReady = false
    self:UpdateWorldRenderOrigin()
end


function R:GetIconKeyForKind(kind)
    local saved = EPC.saved or {}
    local mode = tostring(saved.resourcePinsIconMode or "SUITE_GLOW")
    if mode == "SUITE_GLOW" then return "SUITE_GLOW" end
    -- World Marker mode must still use a distinct symbol per resource type.
    -- Color is secondary; shape identifies the node at a glance.
    if mode == "WORLD" then return AUTO_ICON[kind] or "WORLD" end
    if mode == "CATEGORY" then return AUTO_ICON[kind] or "WORLD" end
    if mode == "CUSTOM" then
        local settingKey = CUSTOM_ICON_SETTING[kind] or "resourcePinsIconOther"
        local selected = tostring(saved[settingKey] or "AUTO")
        if selected == "AUTO" then return AUTO_ICON[kind] or "WORLD" end
        if ICON_TEXTURES[selected] then return selected end
    end
    return "SUITE_GLOW"
end

function R:GetTextureForEntry(entry)
    local kind = type(entry) == "table" and tostring(entry.kind or "RESOURCE") or "RESOURCE"
    local key = self:GetIconKeyForKind(kind)
    return ICON_TEXTURES[key] or GLOW_TEXTURE, key
end

function R:ApplyTexture(tex, entry)
    if not tex then return nil end
    local source, key = self:GetTextureForEntry(entry)
    tex:SetTexture(source)
    tex.easTextureSource = source
    if type(tex.SetTextureCoords) == "function" then
        if key == "SUITE_GLOW" then
            tex:SetTextureCoords(GLOW_U1, GLOW_U2, GLOW_V1, GLOW_V2)
        else
            tex:SetTextureCoords(0, 1, 0, 1)
        end
    end
    return key
end

function R:EnsureMarker(index)
    self:EnsureWindow()
    self.markers = self.markers or {}
    if self.markers[index] then return self.markers[index] end

    -- Keep the proven parent world-position control, then render the native ESO
    -- Glow and the supplied resource artwork in independent child 3D spaces.
    -- This mirrors the original resource-pin control hierarchy while retaining
    -- the raw-axis/world-position path that is visibly working in 0.28.86.
    local pin
    if self.worldControlPool then
        pin = self.worldControlPool:AcquireObject(index)
    end
    if not pin then
        pin = wm:CreateControl(nil, self.window, CT_CONTROL)
        pin.beam = wm:CreateControl(nil, pin, CT_TEXTURE)
        pin.icon = wm:CreateControl(nil, pin, CT_TEXTURE)
    else
        pin.beam = pin:GetNamedChild("Beam")
        pin.icon = pin:GetNamedChild("Icon")
    end

    local beam, icon = pin.beam, pin.icon
    if not beam or not icon then return nil end

    pin:SetHidden(true)
    if type(pin.SetMouseEnabled) == "function" then pin:SetMouseEnabled(false) end

    local controls = { pin, beam, icon }
    for i = 1, #controls do
        local control = controls[i]
        if control and type(control.Create3DRenderSpace) == "function" then
            local hasSpace = type(control.Has3DRenderSpace) == "function" and control:Has3DRenderSpace()
            if not hasSpace then control:Create3DRenderSpace() end
        end
        if control and type(control.SetMouseEnabled) == "function" then control:SetMouseEnabled(false) end
    end

    beam:SetHidden(true)
    icon:SetHidden(true)
    self.markers[index] = pin
    return pin
end

function R:HideAll(reason)
    if self.markers then for _, tex in ipairs(self.markers) do if tex then tex:SetHidden(true) end end end
    self.lastVisibleCount = 0
    self.lastCandidateCount = 0
    self.lastPositionFailures = 0
    if reason then self.lastHiddenReason = tostring(reason) end
end

function R:PositionMarker(pin, entry, distanceM)
    if not pin or type(entry) ~= "table" then return false end
    local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
    if not x or not y or not z then return false end
    if not self.worldRenderOriginReady and not self:UpdateWorldRenderOrigin() then return false end
    if type(WorldPositionToGuiRender3DPosition) ~= "function" then return false end

    local beam = pin.beam or (type(pin.GetNamedChild) == "function" and pin:GetNamedChild("Beam"))
    local icon = pin.icon or (type(pin.GetNamedChild) == "function" and pin:GetNamedChild("Icon"))
    if not beam or not icon then return false end

    local guiX, guiZ, guiY = safe(WorldPositionToGuiRender3DPosition, nil, x, y, z)
    guiX, guiZ, guiY = tonumber(guiX), tonumber(guiZ), tonumber(guiY)
    if not guiX or not guiZ or not guiY then return false end
    guiX = guiX - (tonumber(self.renderOriginX) or 0)
    guiZ = guiZ - (tonumber(self.renderOriginZ) or 0)
    guiY = guiY - (tonumber(self.renderOriginY) or 0)

    local saved = EPC.saved or {}
    local scale = math.max(0.45, math.min(2.50, tonumber(saved.resourcePinsScale) or 1.0))
    local sharpIcons = saved.resourcePinsSharpIcons ~= false
    local iconSizeMult = math.max(0.70, math.min(1.80, (tonumber(saved.resourcePinsIconSize) or 100) / 100))
    local tintStrength = clamp01((tonumber(saved.resourcePinsIconTintStrength) or 85) / 100)
    local farScale = distanceM > 35 and math.min(sharpIcons and 1.12 or 1.28, 1 + ((distanceM - 35) / (sharpIcons and 420 or 260))) or 1
    local size = scale * farScale
    local alphaBase = math.max(0.15, math.min(1.0, tonumber(saved.resourcePinsOpacity) or 0.72))
    local useDepth = saved.resourcePinsThroughWalls == false
    local focusedMissing = entry.focusMissing == true
    if focusedMissing then
        -- Hunt targets must remain visible even when the known node is behind
        -- terrain/buildings; otherwise the player can easily think no pin exists.
        useDepth = false
    end
    local iconKey = self:GetIconKeyForKind(entry.kind)
    local baseColor = COLORS[entry.kind] or COLORS.RESOURCE
    local glowColor, glowAlpha, glowSize, glowTier = self:GetGlowVisualForEntry(entry, alphaBase)
    if focusedMissing then
        -- Tracked Potion Maker materials deliberately stand out from normal farm
        -- pins: oversized bright gold/green target, full opacity and a stronger
        -- additive halo so the target is unmistakable at long range.
        size = size * 2.10
        alphaBase = 1.0
        baseColor = { 1.00, 0.88, 0.10 }
        glowColor, glowAlpha, glowSize, glowTier = { 0.48, 1.00, 0.18 }, 1.00, 1.72, "MISSING"
    end

    pin:Set3DRenderSpaceOrigin(guiX, guiZ, guiY)
    pin:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    pin:Set3DRenderSpaceOrientation(0, tonumber(safe(GetPlayerCameraHeading, 0)) or 0, 0)
    beam:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    icon:Set3DRenderSpaceUsesDepthBuffer(useDepth)
    beam:SetHidden(true)
    icon:SetHidden(true)
    if type(beam.SetDrawLevel) == "function" then beam:SetDrawLevel(6) end
    if type(icon.SetDrawLevel) == "function" then icon:SetDrawLevel(5) end

    local requestedMode = focusedMissing and "CATEGORY" or tostring(saved.resourcePinsIconMode or "SUITE_GLOW")
    local source = GLOW_TEXTURE
    local usingNative = false
    local usingFallback = false

    if iconKey == "SUITE_GLOW" then
        source = GLOW_TEXTURE
        beam:SetTexture(source)
        if type(beam.SetTextureCoords) == "function" then beam:SetTextureCoords(GLOW_U1, GLOW_U2, GLOW_V1, GLOW_V2) end
        if type(beam.SetBlendMode) == "function" and TEX_BLEND_MODE_ADD ~= nil then beam:SetBlendMode(TEX_BLEND_MODE_ADD) end
        beam:Set3DRenderSpaceOrigin(0, GLOW_VERTICAL_OFFSET_CM / 100, 0)
        beam:Set3DLocalDimensions((BASE_GLOW_WIDTH_M * glowSize) * size, (BASE_GLOW_HEIGHT_M * glowSize) * size)
        beam:SetColor(baseColor[1], baseColor[2], baseColor[3], math.max(alphaBase, glowAlpha))
        beam:SetAlpha(math.max(alphaBase, glowAlpha))
        icon:SetHidden(true)
    else
        if requestedMode == "CATEGORY" then
            source = NATIVE_ICON_TEXTURES[iconKey] or NATIVE_ICON_TEXTURES.WORLD
            usingNative = true
        else
            source = ICON_TEXTURES[iconKey] or ICON_TEXTURES.WORLD
        end

        beam:SetTexture(source)
        if type(beam.SetTextureCoords) == "function" then beam:SetTextureCoords(0, 1, 0, 1) end
        if type(beam.SetBlendMode) == "function" and TEX_BLEND_MODE_ALPHA ~= nil then beam:SetBlendMode(TEX_BLEND_MODE_ALPHA) end

        if not usingNative and type(beam.IsTextureLoaded) == "function" then
            local ok, loaded = pcall(beam.IsTextureLoaded, beam)
            if ok and loaded == false then
                source = NATIVE_ICON_TEXTURES[iconKey] or NATIVE_ICON_TEXTURES.WORLD
                beam:SetTexture(source)
                usingNative = true
                usingFallback = true
            end
        end

        local iconBaseSize = sharpIcons and 1.72 or 1.52
        local normalize = usingNative and (NATIVE_ICON_SCALE[iconKey] or 0.82) or 0.86
        local finalIconSize = iconBaseSize * normalize * iconSizeMult
        local tintR = 1 + ((baseColor[1] or 1) - 1) * tintStrength
        local tintG = 1 + ((baseColor[2] or 1) - 1) * tintStrength
        local tintB = 1 + ((baseColor[3] or 1) - 1) * tintStrength
        beam:Set3DRenderSpaceOrigin(0, 1.05 * size, 0)
        beam:Set3DLocalDimensions(finalIconSize * size, finalIconSize * size)
        beam:SetColor(tintR, tintG, tintB, 1)
        beam:SetAlpha(1)

        icon:SetTexture(GLOW_TEXTURE)
        if type(icon.SetTextureCoords) == "function" then icon:SetTextureCoords(GLOW_U1, GLOW_U2, GLOW_V1, GLOW_V2) end
        if type(icon.SetBlendMode) == "function" and TEX_BLEND_MODE_ADD ~= nil then icon:SetBlendMode(TEX_BLEND_MODE_ADD) end
        icon:Set3DRenderSpaceOrigin(0, 1.03 * size, 0)
        icon:Set3DLocalDimensions((finalIconSize * 1.08 * glowSize) * size, (finalIconSize * 1.08 * glowSize) * size)
        icon:SetColor(glowColor[1], glowColor[2], glowColor[3], glowAlpha)
        icon:SetAlpha(glowAlpha)
        icon:SetHidden(false)
    end

    self.lastIconTexture = source
    self.lastIconUsedNative = usingNative
    self.lastIconFallback = usingFallback
    self.lastIconLoaded = nil
    self.lastIconWidth = nil
    self.lastIconHeight = nil
    self.lastGlowTier = glowTier
    self.lastSharpMode = sharpIcons and true or false
    self.lastIconNormalization = iconKey
    if type(beam.IsTextureLoaded) == "function" then
        local ok, loaded = pcall(beam.IsTextureLoaded, beam)
        if ok then self.lastIconLoaded = loaded and true or false end
    end
    if type(beam.GetTextureFileDimensions) == "function" then
        local ok, w, h = pcall(beam.GetTextureFileDimensions, beam)
        if ok then
            self.lastIconWidth = tonumber(w)
            self.lastIconHeight = tonumber(h)
        end
    end

    beam:SetHidden(false)

    if type(pin.SetDrawLevel) == "function" then pin:SetDrawLevel(5) end
    pin:SetHidden(false)
    return true
end

-- Native skyshard 3D source. This intentionally does NOT copy or persist any
-- SkyShards addon coordinate database. ESO supplies the current character's
-- skyshard IDs, discovery state and world position; the Suite only builds the
-- small in-range candidate list needed by the existing 3D renderer.
function R:AppendNativeSkyshards(zoneId, px, py, pz, maxDistanceM, visible)
    if not EPC.saved or EPC.saved.resourcePinsShowSkyshards == false then return 0 end
    if EPC.saved.resourcePinsFarmFocusEnabled == true then return 0 end
    if type(GetNumSkyshardsInZone) ~= "function" or type(GetZoneSkyshardId) ~= "function"
        or type(GetSkyshardDiscoveryStatus) ~= "function" then return 0 end

    local count = tonumber(safe(GetNumSkyshardsInZone, 0, zoneId)) or 0
    if count <= 0 then return 0 end

    local regularZone, regularX, regularY, regularZ
    if type(GetUnitWorldPosition) == "function" then
        regularZone, regularX, regularY, regularZ = safe(GetUnitWorldPosition, nil, "player")
    end
    regularZone = tonumber(regularZone)
    regularX, regularY, regularZ = tonumber(regularX), tonumber(regularY), tonumber(regularZ)
    local rawOffsetX, rawOffsetY, rawOffsetZ
    if regularZone == tonumber(zoneId) and regularX and regularY and regularZ then
        rawOffsetX, rawOffsetY, rawOffsetZ = px - regularX, py - regularY, pz - regularZ
    end

    local measurement
    if GPS and type(GPS.GetCurrentMapMeasurement) == "function" then
        measurement = safe(function() return GPS:GetCurrentMapMeasurement() end, nil)
    end

    local acquired = rawget(_G, "SKYSHARD_DISCOVERY_STATUS_ACQUIRED")
    local added, seen = 0, {}
    for i = 1, count do
        local shardId = tonumber(safe(GetZoneSkyshardId, 0, zoneId, i)) or 0
        if shardId > 0 and not seen[shardId] then
            seen[shardId] = true
            local status = safe(GetSkyshardDiscoveryStatus, acquired, shardId)
            if acquired == nil or status ~= acquired then
                local wx, wy, wz

                -- Preferred path: ESO's exact world position, transformed from
                -- regular world space into the raw render space used by this
                -- module. In normal zones this is normally a simple offset.
                if rawOffsetX and type(GetWorldPositionForSkyshardId) == "function" then
                    local sZone, sx, sy, sz = safe(GetWorldPositionForSkyshardId, nil, shardId)
                    sZone, sx, sy, sz = tonumber(sZone), tonumber(sx), tonumber(sy), tonumber(sz)
                    if sZone == tonumber(zoneId) and sx and sy and sz then
                        wx, wy, wz = sx + rawOffsetX, sy + rawOffsetY, sz + rawOffsetZ
                    end
                end

                -- Fallback for clients/maps where the exact world API is not
                -- exposed: project the native normalized shard location through
                -- LibGPS. Only accept shards actually represented by this map.
                if not wx and measurement and type(measurement.ToWorld) == "function"
                    and type(GetNormalizedPositionForSkyshardId) == "function" then
                    local nx, ny, isInMap = safe(GetNormalizedPositionForSkyshardId, nil, shardId)
                    nx, ny = tonumber(nx), tonumber(ny)
                    if nx and ny and isInMap ~= false then
                        local ok, mx, my, mz = pcall(measurement.ToWorld, measurement, nx, ny)
                        mx, my, mz = tonumber(mx), tonumber(my), tonumber(mz)
                        if ok and mx and my and mz then wx, wy, wz = mx, my, mz end
                    end
                end

                if wx and wy and wz then
                    local distanceM = distance3Dcm(px, py, pz, wx, wy, wz) / 100
                    if distanceM <= maxDistanceM then
                        local hint = type(GetSkyshardHint) == "function" and tostring(safe(GetSkyshardHint, "Skyshard", shardId) or "Skyshard") or "Skyshard"
                        local entry = {
                            kind = "SKYSHARD", name = hint ~= "" and hint or "Skyshard",
                            zoneId = zoneId, x = wx, y = wy, z = wz,
                            skyshardId = shardId, nativeSkyshard = true,
                        }
                        visible[#visible + 1] = {
                            entry = entry, distanceM = distanceM,
                            horizontalDistanceM = distance2Dcm(px, pz, wx, wz) / 100,
                            skyshard = true, noDepletionProbe = true,
                        }
                        added = added + 1
                    end
                end
            end
        end
    end
    self.lastSkyshardCandidateCount = added
    return added
end

function R:RefreshMarkers()
    local explicitAlchemyHunt = type(self.missingAlchemyFocus) == "table"
        and type(self.missingAlchemyFocus.materials) == "table"
        and #self.missingAlchemyFocus.materials > 0

    if not EPC.saved then
        self:HideAll("no saved settings")
        return
    end

    -- v0.29.238: MAP + 3D MISSING must work even when ordinary Resource Pins,
    -- community pins, or normal 3D pins are turned off. The explicit hunt only
    -- affects the temporary missing-material targets selected by the player.
    if not explicitAlchemyHunt and (EPC.saved.enabled == false or EPC.saved.resourcePinsEnabled == false or EPC.saved.resourcePinsShow3D == false) then
        self:HideAll("disabled")
        return
    end

    local now = nowMs()
    if self.debugEntry and now > (tonumber(self.debugUntil) or 0) then
        self.debugEntry = nil
        self.debugUntil = 0
    end

    local hudFragmentHidden = self:IsWorldGlowSuppressed()
    -- Excavation can occasionally leave the shared HUD fragment hidden after
    -- returning to gameplay. If the active scene is unquestionably the normal
    -- HUD, repair the parent 3D layer in-place instead of requiring /reloadui.
    if hudFragmentHidden and self:IsNormalWorldSceneActive()
        and (now - (tonumber(self.lastRendererRecoveryAt) or 0)) >= 1200 then
        self:RecoverWorldRenderer("HUD fragment stuck hidden")
    end
    if hudFragmentHidden and self.debugEntry then
        self.debugUntil = now + 10000
    end

    local zoneId, px, py, pz = self:GetPlayerRawPosition()
    if not zoneId then self:HideAll("no player position") return end
    local bucket = self:GetZoneBucket(zoneId, false)
    if type(bucket) ~= "table" then bucket = {} end

    -- Potion Maker hunt pins are independent of the normal resource category
    -- filters. They are a temporary explicit target chosen by the player.
    local missingFocusLocations = nil
    if type(self.missingAlchemyFocus) == "table" and tonumber(self.missingAlchemyFocus.zoneId) == tonumber(zoneId) then
        missingFocusLocations = self.missingAlchemyFocus.locations
    end

    if self.lastRenderZoneId ~= zoneId then
        self.lastRenderZoneId = zoneId
        self.lastAllZoneRefreshAt = 0
    end

    -- The full bundled database stays available for the current zone, but 3D
    -- controls are created only for a bounded nearest set. Creating thousands of
    -- 3D controls at once causes severe FPS loss even when a texture fails to draw.
    local maxDistanceM = math.max(15, math.min(500, tonumber(EPC.saved.resourcePinsDistance) or 200))
    local markerLimit = math.floor(math.max(MIN_VISIBLE_MARKERS, math.min(MAX_VISIBLE_MARKERS,
        tonumber(EPC.saved.resourcePinsMaxVisible) or DEFAULT_VISIBLE_MARKERS)))
    -- While the player is actively running, render a smaller nearest set. The
    -- complete configured set returns immediately after movement settles. This
    -- prevents 50-72 3D controls from being fully reconfigured in the same
    -- frame every time the nearby spatial query advances.
    if self.resourceMotionActive029312 == true and not explicitAlchemyHunt then
        markerLimit = math.min(markerLimit, MOVEMENT_MARKER_CAP_029312)
    end
    local visible = {}
    self:PruneDepleted(zoneId)

    if type(missingFocusLocations) == "table" then
        -- Explicit hunt targets are intentionally not clipped by the normal farm
        -- distance. If a known spawn is in the current zone, keep it eligible so
        -- the player can actually see which direction to travel from far away.
        for i = 1, #missingFocusLocations do
            local entry = missingFocusLocations[i]
            if type(entry) == "table" and not self:IsPositionDepleted(zoneId, entry.x, entry.z, entry.kind) then
                local distanceM = distance3Dcm(px, py, pz, entry.x, entry.y, entry.z) / 100
                local horizontalDistanceM = distance2Dcm(px, pz, entry.x, entry.z) / 100
                visible[#visible + 1] = { entry = entry, distanceM = distanceM, horizontalDistanceM = horizontalDistanceM, focusedMissing = true, learned = true }
            end
        end
    end

    local learnedShadow = self:BuildLearnedShadowGrid(bucket)
    for i = 1, #bucket do
        local entry = bucket[i]
        if type(entry) == "table" and self:IsKindEnabled(entry.kind)
            and not self:IsPositionDepleted(zoneId, entry.x, entry.z, entry.kind) then
            local distanceM = distance3Dcm(px, py, pz, entry.x, entry.y, entry.z) / 100
            local horizontalDistanceM = distance2Dcm(px, pz, entry.x, entry.z) / 100
            if distanceM <= maxDistanceM then
                visible[#visible + 1] = { entry = entry, distanceM = distanceM, horizontalDistanceM = horizontalDistanceM, learned = true }
            end
        end
    end

    -- Query the spatial index around the player instead of scanning/instantiating
    -- every record in a dense zone. Every bundled record is still available and
    -- becomes eligible automatically as the player moves into range.
    self:AppendNearbyCommunity(zoneId, px, py, pz, maxDistanceM, visible, learnedShadow)

    -- Skyshards share the same bounded 3D marker pool but come only from ESO's
    -- native API. They are never learned, persisted, or mixed into depletion.
    self:AppendNativeSkyshards(zoneId, px, py, pz, maxDistanceM, visible)

    if self.debugEntry and now <= (tonumber(self.debugUntil) or 0) then
        visible[#visible + 1] = { entry = self.debugEntry, distanceM = 4, horizontalDistanceM = 4, debug = true }
    elseif self.debugEntry then
        self.debugEntry = nil
        self.debugUntil = 0
    end

    visible = self:DeduplicateVisibleCandidates(visible)

    self.nearestDepletionCandidate = nil
    for i = 1, #visible do
        local candidate = visible[i]
        local candidateProbeDistance = tonumber(candidate.horizontalDistanceM) or tonumber(candidate.distanceM) or 999999
        local currentProbeDistance = self.nearestDepletionCandidate and (tonumber(self.nearestDepletionCandidate.horizontalDistanceM) or tonumber(self.nearestDepletionCandidate.distanceM) or 999999) or 999999
        if candidate.debug ~= true and candidate.noDepletionProbe ~= true and (not self.nearestDepletionCandidate or candidateProbeDistance < currentProbeDistance) then
            self.nearestDepletionCandidate = candidate
        end
    end

    if explicitAlchemyHunt and type(missingFocusLocations) == "table" then
        markerLimit = math.max(markerLimit, math.min(MISSING_ALCHEMY_MAX_MAP_PINS, #missingFocusLocations))
    end
    local candidateCount = math.min(#visible, markerLimit)
    self.lastRequestedVisibleCount = #visible
    self.lastTargetCount = candidateCount
    self.lastMarkerLimit = markerLimit
    self.lastAllZoneCapped = #visible > markerLimit
    self.allZoneBuildComplete = true

    local renderedCount = 0
    local failedCount = 0
    for i = 1, candidateCount do
        local tex = self:EnsureMarker(i)
        if self:PositionMarker(tex, visible[i].entry, visible[i].distanceM) then
            renderedCount = renderedCount + 1
        else
            tex:SetHidden(true)
            failedCount = failedCount + 1
        end
    end
    if self.markers then
        for i = candidateCount + 1, #self.markers do self.markers[i]:SetHidden(true) end
    end

    self.lastCandidateCount = candidateCount
    self.lastPositionFailures = failedCount
    self.lastVisibleCount = renderedCount
    local communityCount = tonumber(self.lastCommunityZoneCount) or 0
    if renderedCount > 0 then
        self.lastHiddenReason = hudFragmentHidden and "prepared; HUD fragment hidden" or "visible"
    else
        local skyCount = tonumber(self.lastSkyshardCandidateCount) or 0
        self.lastHiddenReason = (#bucket == 0 and communityCount == 0 and skyCount == 0) and "no resource nodes or skyshards here" or "no nodes passed range/filter"
    end
end

function R:ClearLearnedLocations()
    if EPC.saved then EPC.saved.resourcePinLocations = {} end
    self.pendingResource = nil
    self:HideAll("cleared")
end

function R:GetLearnedCount()
    local total = 0
    local all = EPC.saved and EPC.saved.resourcePinLocations
    if type(all) == "table" then
        for _, bucket in pairs(all) do if type(bucket) == "table" then total = total + #bucket end end
    end
    return total
end

function R:GetCurrentZoneCount()
    local zoneId = select(1, self:GetPlayerRawPosition())
    local bucket = zoneId and self:GetZoneBucket(zoneId, false)
    return type(bucket) == "table" and #bucket or 0
end

function R:GetCommunityCurrentZoneCount()
    if not EPC.saved or EPC.saved.resourcePinsCommunityEnabled == false then return 0 end
    local zoneId = select(1, self:GetPlayerRawPosition())
    local cache = zoneId and self:BuildCommunityZoneCache(zoneId) or nil
    return type(cache) == "table" and (tonumber(cache.count) or 0) or 0
end

function R:GetRenderFragmentState()
    if self.worldFragment and type(self.worldFragment.IsHidden) == "function" then
        local ok, hidden = pcall(self.worldFragment.IsHidden, self.worldFragment)
        if ok then return hidden and "HIDDEN" or "VISIBLE" end
    end
    return "UNKNOWN"
end

function R:GetStatusText()
    local last = self.lastLearnedName or "none"
    local kind = self.lastLearnedKind and (TYPE_LABELS[self.lastLearnedKind] or self.lastLearnedKind) or "none"
    local communityOn = EPC.saved and EPC.saved.resourcePinsCommunityEnabled ~= false
    local communityHere = communityOn and self:GetCommunityCurrentZoneCount() or 0
    local zoneId = select(1, self:GetPlayerRawPosition()) or 0
    local requestedMode = EPC.saved and tostring(EPC.saved.resourcePinsIconMode or "SUITE_GLOW") or "SUITE_GLOW"
    local sourceMode = requestedMode == "CATEGORY" and "native ESO / proven control" or (requestedMode == "SUITE_GLOW" and "native Glow / proven control" or "custom DDS / proven control")
    if self.lastIconFallback then sourceMode = sourceMode .. " -> native fallback" end
    local loadState = self.lastIconLoaded == nil and "unknown" or (self.lastIconLoaded and "loaded" or "NOT loaded")
    local dims = (self.lastIconWidth and self.lastIconHeight) and string.format(" %dx%d", self.lastIconWidth, self.lastIconHeight) or ""
    local sharpText = (self.lastSharpMode == false) and "soft" or "sharp"
    local tintText = tostring(math.floor(tonumber(EPC.saved and EPC.saved.resourcePinsIconTintStrength or 85) or 85)) .. "% tint"
    local sizeText = tostring(math.floor(tonumber(EPC.saved and EPC.saved.resourcePinsIconSize or 100) or 100)) .. "% size"
    local glowText = (EPC.saved and EPC.saved.resourcePinsValueGlow == false) and "single glow" or ("value glow " .. tostring(self.lastGlowTier or "COMMON"))
    local iconMode = requestedMode .. " (" .. sourceMode .. "; " .. loadState .. dims .. "; " .. sharpText .. "; " .. sizeText .. "; " .. tintText .. "; " .. glowText .. ")"
    local maxDistanceM = EPC.saved and tonumber(EPC.saved.resourcePinsDistance) or 200
    local capText = self.lastAllZoneCapped and string.format("; nearest %d shown", tonumber(self.lastMarkerLimit) or DEFAULT_VISIBLE_MARKERS) or ""
    local depletedCount = self:PruneDepleted(zoneId)
    local farmFocusText = self:GetFarmTargetSummary()
    local cooldownMinutes = EPC.saved and tonumber(EPC.saved.resourcePinsDepletedCooldownMinutes) or 5
    local probeDistanceText = self.lastDepletionProbeDistanceM and string.format("%.1fm", tonumber(self.lastDepletionProbeDistanceM) or 0) or "n/a"
    local probeState = tostring(self.lastDepletionProbeState or "idle")
    return string.format("Resource Pins: zone %s, %d learned total, %d learned here, %d community here, %d temporarily depleted, %d in range, %d candidates, %d rendered, %d render failures. Farm Focus: %s. Depletion mode: SAME-TYPE HARVESTED + MISSING COMMUNITY; cooldown %dm. Depletion probe: %s / %s. Community display: FULL DATA / DYNAMIC NEAREST%s; range %dm. Community data: %s (%d bundled records). Renderer: %s. HUD fragment: %s. Icon mode: %s. Last state: %s. Last learned: %s (%s).",
        tostring(zoneId), self:GetLearnedCount(), self:GetCurrentZoneCount(), communityHere, depletedCount,
        tonumber(self.lastRequestedVisibleCount) or 0, tonumber(self.lastCandidateCount) or 0, tonumber(self.lastVisibleCount) or 0, tonumber(self.lastPositionFailures) or 0,
        farmFocusText, math.floor(cooldownMinutes), probeDistanceText, probeState, capText, math.floor(maxDistanceM), communityOn and "ON" or "OFF", COMMUNITY_DATASET_RECORDS,
        self.worldRenderOriginReady and "READY" or "NOT READY", self:GetRenderFragmentState(), iconMode, tostring(self.lastHiddenReason or "unknown"),
        tostring(last), tostring(kind))
end

function R:StartDebugTestGlow()
    local zoneId, x, y, z = self:GetPlayerRawPosition()
    if not zoneId then return false end
    local heading = tonumber(safe(GetPlayerCameraHeading, 0)) or 0
    self.debugEntry = {
        kind = "ORE", name = "Resource Pin Test", x = x + (math.sin(heading) * 400), y = y, z = z + (math.cos(heading) * 400),
    }
    self.debugUntil = nowMs() + 10000
    self:RefreshMarkers()
    return true
end

function R:RefreshSettings()
    self.allZoneBuildComplete = true
    self.lastAllZoneRefreshAt = 0
    if EPC.saved and EPC.saved.resourcePinsCommunityEnabled == false then
        self.communityZoneId = nil
        self.communityZoneCache = nil
        self.lastCommunityZoneCount = 0
    end
    self:RefreshMarkers()
end

function R:HandleSlash(text)
    local arg = string.lower(tostring(text or ""))
    arg = string.match(arg, "^%s*(.-)%s*$") or ""
    if arg == "clear" then
        self:ClearLearnedLocations()
        if EPC.Print then EPC:Print("Resource Pins learned locations cleared.") end
    elseif arg == "resetdepleted" then
        self:ClearDepletedLocations()
        if EPC.Print then EPC:Print("Resource Pins temporary depleted states reset.") end
    elseif arg == "test" then
        if self:StartDebugTestGlow() then EPC:Print("Resource Pins: test pin queued about 4m ahead. Close Settings/menus to view it for 10 seconds.")
        else EPC:Print("Resource Pins: could not get your world position for the test glow.") end
    else
        if EPC.Print then EPC:Print(self:GetStatusText() .. " Commands: /easresources test, /easresources clear, /easresources resetdepleted") end
    end
end

-- v0.29.312: the resource database query/sort and full 3D-control styling are
-- deliberately separated from the cheap billboard rotation update. World-space
-- origins do not need to be rebuilt just because the player moved a few feet.
function R:QuickOrientMarkers029312()
    if not self.markers or #self.markers == 0 then return end
    local heading = tonumber(safe(GetPlayerCameraHeading, 0)) or 0
    local lastHeading = tonumber(self.lastQuickOrientHeading029315)
    if lastHeading then
        local delta = math.abs(heading - lastHeading)
        if delta > math.pi then delta = (math.pi * 2) - delta end
        if delta < 0.010 then return end
    end
    self.lastQuickOrientHeading029315 = heading
    local visibleCount = tonumber(self.lastCandidateCount) or #self.markers
    visibleCount = math.min(visibleCount, #self.markers)
    for i = 1, visibleCount do
        local pin = self.markers[i]
        if pin and not pin:IsHidden() and type(pin.Set3DRenderSpaceOrientation) == "function" then
            pin:Set3DRenderSpaceOrientation(0, heading, 0)
        end
    end
end

function R:MovementAwareRefreshMarkers029312()
    -- v0.29.341: a disabled 3D renderer should be truly dormant. The old timer
    -- still sampled raw player position and camera heading even when Resource
    -- Pins were disabled, which was unnecessary background movement work.
    if not EPC.saved or EPC.saved.enabled == false or EPC.saved.resourcePinsEnabled == false
        or (EPC.saved.resourcePinsShow3D == false and not self.missingAlchemyFocus) then
        return
    end
    local now = nowMs()
    local zoneId, x, _, z = self:GetPlayerRawPosition()
    if not zoneId then return end

    local changedZone = tonumber(self.motionZone029312) ~= tonumber(zoneId)
    if changedZone then
        self.motionZone029312 = zoneId
        self.motionX029312, self.motionZ029312 = x, z
        self.motionMovingUntil029312 = now + MOVEMENT_GRACE_MS_029312
    else
        local lx, lz = tonumber(self.motionX029312), tonumber(self.motionZ029312)
        if lx and lz then
            local dx, dz = x - lx, z - lz
            if (dx * dx) + (dz * dz) >= (MOVEMENT_SAMPLE_CM_029312 * MOVEMENT_SAMPLE_CM_029312) then
                self.motionMovingUntil029312 = now + MOVEMENT_GRACE_MS_029312
                self.motionX029312, self.motionZ029312 = x, z
            end
        else
            self.motionX029312, self.motionZ029312 = x, z
        end
    end

    local moving = now < (tonumber(self.motionMovingUntil029312) or 0)
    local wasMoving = self.resourceMotionActive029312 == true
    self.resourceMotionActive029312 = moving

    -- Camera-facing rotation is cheap and keeps icons visually correct between
    -- database refreshes. No spatial search, sort, texture setup, or origin
    -- conversion happens here.
    self:QuickOrientMarkers029312()

    local lastHeavy = tonumber(self.lastMotionHeavyRefresh029312) or 0
    local interval = moving and MOVEMENT_HEAVY_REFRESH_MS_029312 or STATIONARY_SAFETY_REFRESH_MS_029312
    local heavyDue = changedZone or lastHeavy == 0 or (now - lastHeavy) >= interval
    -- On the first stationary sample after running, restore the user's full
    -- marker count immediately rather than waiting for the safety interval.
    if wasMoving and not moving then heavyDue = true end

    if heavyDue then
        self.lastMotionHeavyRefresh029312 = now
        self:RefreshMarkers()
    end
end

local InitializeImplArch

function R:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.markers = {}
    self.pendingResource = nil
    self.depletionProbeKey = nil
    self.depletionProbeSince = 0
    self.depletionProbePlayerX = nil
    self.depletionProbePlayerZ = nil
    self.depletionAutoLockUntil = 0
    self.lastDepletionProbeDistanceM = nil
    self.lastDepletionProbeState = "idle"
    self.nearestDepletionCandidate = nil
    self.liveCommunityNode = nil
    self.liveCommunityVanishedAt = 0
    self.lastOwnCollectionAt = 0
    self.lastResourceInteractionAt = 0
    self.lastFishingSeenAt = 0
    self.lastVisibleCount = 0
    self.lastCandidateCount = 0
    self.lastPositionFailures = 0
    self.lastHiddenReason = "not rendered yet"
    self.worldRenderOriginReady = false
    self.communityZoneId = nil
    self.communityZoneCache = nil
    self.lastCommunityZoneCount = 0
    self.lastCommunityRawZoneCount = 0
    self.lastCommunityError = nil
    self.lastRenderZoneId = nil
    self.lastAllZoneRefreshAt = 0
    self.allZoneBuildComplete = false
    self.lastTargetCount = 0
    self.lastRequestedVisibleCount = 0
    self.motionZone029312 = nil
    self.motionX029312 = nil
    self.motionZ029312 = nil
    self.motionMovingUntil029312 = 0
    self.lastMotionHeavyRefresh029312 = 0
    self.resourceMotionActive029312 = false

    if EPC.saved then
        EPC.saved.resourcePinLocations = EPC.saved.resourcePinLocations or {}
        EPC.saved.resourcePinsDepleted = EPC.saved.resourcePinsDepleted or {}
        if (tonumber(EPC.saved.resourcePinsDataCompactionVersion) or 0) < 2 then
            -- v0.29.466: fishing holes use a wider merge radius than ordinary
            -- resource nodes, so compact old learned duplicates once on upgrade.
            self:CompactLearnedLocationData()
            EPC.saved.resourcePinsDataCompactionVersion = 2
        end

        -- 0.29.00 removed the Suite World Marker presentation option. Migrate
        -- old saved selections so users do not keep an invisible/invalid mode.
        if EPC.saved.resourcePinsIconMode == "WORLD" then
            EPC.saved.resourcePinsIconMode = "CATEGORY"
        end
        local removedWorldMarkerKeys = {
            "resourcePinsIconOre", "resourcePinsIconWood", "resourcePinsIconCloth",
            "resourcePinsIconAlchemy", "resourcePinsIconRunes", "resourcePinsIconWater",
            "resourcePinsIconFishing", "resourcePinsIconSpecial", "resourcePinsIconOther",
        }
        for i = 1, #removedWorldMarkerKeys do
            local key = removedWorldMarkerKeys[i]
            if EPC.saved[key] == "WORLD" then EPC.saved[key] = "AUTO" end
        end
        -- 0.28.85 renderer migration: keep the safe dynamic-nearest performance
        -- cap, but use the exact single-Texture 3D path proven by LoreBooks.
        if (tonumber(EPC.saved.resourcePinsPerformanceVersion) or 0) < 4 then
            EPC.saved.resourcePinsCommunityShowAll = true
            EPC.saved.resourcePinsMaxVisible = 72
            EPC.saved.resourcePinsSafeGlowFallback = false
            if not tonumber(EPC.saved.resourcePinsDistance) or tonumber(EPC.saved.resourcePinsDistance) < 200 then
                EPC.saved.resourcePinsDistance = 200
            end
            EPC.saved.resourcePinsPerformanceVersion = 4
        end
    end

    self:EnsureWindow()
    self:EnsureMissingAlchemyMapPins()
    local prefix = (EPC.name or "EAS") .. "_ResourcePins"
    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Interact", INTERACTION_UPDATE_MS, function() self:CaptureResourceInteraction() end)
    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Render", RENDER_UPDATE_MS, function() self:MovementAwareRefreshMarkers029312() end)

    if EVENT_LOOT_RECEIVED ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Loot", EVENT_LOOT_RECEIVED, function(_, receivedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
            self:HandleLootReceived(receivedBy, itemLink, quantity, itemSound, lootType, lootedBySelf, isPickpocketLoot, questItemIcon, itemId, isStolen)
        end)
    end
    if EVENT_CLIENT_INTERACT_RESULT ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_InteractResult", EVENT_CLIENT_INTERACT_RESULT, function(_, result, targetName)
            self:HandleInteractResult(result, targetName)
        end)
    end
    if EVENT_LOCKPICK_SUCCESS ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_LockpickSuccess", EVENT_LOCKPICK_SUCCESS, function()
            self:HandleLockpickSuccess()
        end)
    end
    -- v0.29.238: World Map uses a different UI/render state. When it closes,
    -- immediately rebuild the 3D render-space origin and show the active hunt
    -- instead of waiting for a later incidental refresh.
    if SCENE_MANAGER and not self.missingAlchemyWorldMapHooked then
        local worldMapScene = SCENE_MANAGER:GetScene("worldMap")
        if worldMapScene and type(worldMapScene.RegisterCallback) == "function" then
            self.missingAlchemyWorldMapHooked = true
            worldMapScene:RegisterCallback("StateChange", function(_, state)
                if (state == SCENE_HIDDEN or state == SCENE_HIDING) and self.missingAlchemyFocus then
                    zo_callLater(function()
                        if EPC and EPC.ResourcePins then
                            EPC.ResourcePins:ResetRenderSpace()
                            EPC.ResourcePins:RefreshMarkers()
                        end
                    end, 120)
                end
            end)
        end
    end

    if EVENT_PLAYER_ACTIVATED ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            self.pendingResource = nil
            self.lastOwnCollectionAt = 0
            self.depletionProbeKey = nil
            self.depletionProbeSince = 0
            self.depletionProbePlayerX = nil
            self.depletionProbePlayerZ = nil
            self.lastDepletionProbeDistanceM = nil
            self.lastDepletionProbeState = "zone change"
            self.liveCommunityNode = nil
            self.liveCommunityVanishedAt = 0
            self:HideAll("zone change")
            zo_callLater(function()
                self:ResetRenderSpace()
                if self.missingAlchemyFocus and type(self.BuildMissingAlchemyFocusForCurrentZone) == "function" then
                    self:BuildMissingAlchemyFocusForCurrentZone()
                else
                    self:RefreshMarkers()
                end
            end, 400)
        end)
    end

    if EVENT_ANTIQUITY_DIGGING_GAME_OVER ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_DiggingGameOver3DRecovery", EVENT_ANTIQUITY_DIGGING_GAME_OVER, function()
            -- ESO transitions through several short scene states when closing the
            -- excavation board. Retry after the HUD has had time to become active.
            for _, delay in ipairs({ 150, 500, 1200 }) do
                zo_callLater(function()
                    if self:IsNormalWorldSceneActive() then
                        self:RecoverSuite3DWorldPins("Antiquity excavation ended")
                        self:RefreshMarkers()
                    end
                end, delay)
            end
        end)
    end

    SLASH_COMMANDS["/easresources"] = function(text) self:HandleSlash(text) end
end


-- ============================================================================
-- v0.29.144 - Camera-transition 3D render-space recovery.
-- The resource renderer itself did not change during the Teleporter work, but
-- ESO can leave an existing 3D render space with stale camera/projection state
-- after World Map / top-level UI transitions. Rebuild the Suite resource-pin
-- spaces once gameplay camera mode has settled, then refresh the other Suite 3D
-- systems through their existing recovery paths.
-- ============================================================================
function R:HardResetResource3DRenderSpaces029144(reason)
    self:EnsureWindow()
    self:HideAll(reason or "camera transition")

    local function rebuild(control)
        if not control then return end
        if type(control.Destroy3DRenderSpace) == "function" then
            pcall(control.Destroy3DRenderSpace, control)
        end
        if type(control.Create3DRenderSpace) == "function" then
            pcall(control.Create3DRenderSpace, control)
        end
        if type(control.SetMouseEnabled) == "function" then
            pcall(control.SetMouseEnabled, control, false)
        end
    end

    rebuild(self.window)
    for _, pin in ipairs(self.markers or {}) do
        rebuild(pin)
        rebuild(pin and pin.beam)
        rebuild(pin and pin.icon)
    end

    self.worldRenderOriginReady = false
    self.renderOriginX, self.renderOriginZ, self.renderOriginY = nil, nil, nil
    self:UpdateWorldRenderOrigin()
    self.lastRendererRecoveryAt = nowMs()
    self.lastRendererRecoveryReason = tostring(reason or "camera transition")
    return true
end

local EAS_RecoverSuite3DWorldPinsBase029144 = RecoverSuite3DWorldPinsImplArch
RecoverSuite3DWorldPinsImplArch = function(self, reason)
    local tag = tostring(reason or "3D camera recovery")
    self:HardResetResource3DRenderSpaces029144(tag)
    local result = EAS_RecoverSuite3DWorldPinsBase029144(self, tag)
    self:RefreshMarkers()
    return result
end

function R:ScheduleSuite3DRecovery029144(reason, delayMs)
    local generationValue = tonumber(self.cameraRecoveryGeneration029144) or 0
    self.cameraRecoveryGeneration029144 = generationValue + 1
    local generation = self.cameraRecoveryGeneration029144
    local tag = tostring(reason or "camera transition")
    local delay = math.max(0, tonumber(delayMs) or 280)

    local function run()
        if not EPC or not EPC.ResourcePins then return end
        local pins = EPC.ResourcePins
        if pins.cameraRecoveryGeneration029144 ~= generation then return end
        if EPC and type(EPC.IsGameplayHudSuppressed) == "function" then
            local ok, suppressed = pcall(EPC.IsGameplayHudSuppressed, EPC)
            if ok and suppressed == true then return end
        end
        if pins.IsNormalWorldSceneActive and not pins:IsNormalWorldSceneActive() then return end
        pins:RecoverSuite3DWorldPins(tag)
    end

    if type(zo_callLater) == "function" then zo_callLater(run, delay) else run() end
end

function R:RegisterCameraRecovery029144()
    if self.cameraRecoveryRegistered029144 or not EVENT_MANAGER then return end
    self.cameraRecoveryRegistered029144 = true
    local prefix = (EPC.name or "EAS") .. "_3DCameraRecovery029144"

    if EVENT_GAME_CAMERA_UI_MODE_CHANGED ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_UIMode", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
            local active = false
            if type(IsGameCameraUIModeActive) == "function" then
                local ok, value = pcall(IsGameCameraUIModeActive)
                active = ok and value == true
            end
            if not active then self:ScheduleSuite3DRecovery029144("returned from UI/map", 280) end
        end)
    end

    if EVENT_PLAYER_ACTIVATED ~= nil then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            self:ScheduleSuite3DRecovery029144("player activated", 650)
        end)
    end
end

local EAS_ResourcePinsInitializeBase029144 = InitializeImplArch
InitializeImplArch = function(self, ...)
    local result = EAS_ResourcePinsInitializeBase029144(self, ...)
    self:RegisterCameraRecovery029144()
    return result
end


-- BEGIN ABSORBED: ResourcePins3DLocationFix.lua
-- ESO Adventurer Suite
-- v0.29.497 - 3D resource pin map-layer and duplicate-location hotfix.
-- Keep community records scoped to the player's active map when ESO exposes a
-- trustworthy current-map identity, and merge stale learned/community doubles.

local EPC = ESOProgressionCoach
if not EPC or not EPC.ResourcePins then return end
local R = EPC.ResourcePins

local ORIGINAL_BUILD_COMMUNITY_CACHE = BuildCommunityZoneCacheImplArch
local ORIGINAL_INITIALIZE = InitializeImplArch

local COMMUNITY_MODULES_029497 = { "AD", "DC", "DLC", "EP", "NF" }
local COMMUNITY_KIND_BY_PIN_029497 = {
    [1] = "ORE", [17] = "ORE",
    [2] = "CLOTH",
    [3] = "RUNE", [16] = "RUNE",
    [4] = "MUSHROOM",
    [5] = "WOOD",
    [6] = "CHEST",
    [7] = "WATER",
    [8] = "FISHING",
    [9] = "HEAVYSACK",
    [10] = "TROVE",
    [11] = "JUSTICE",
    [12] = "STASH",
    [13] = "FLOWER",
    [14] = "WATERPLANT",
    [15] = "CLAM",
    [18] = "RESOURCE",
    [19] = "FLOWER",
    [20] = "ALCHEMY",
}

local NORMAL_DEDUPE_CM_029497 = 500
local FISHING_DEDUPE_CM_029497 = 1400
local VERTICAL_DEDUPE_CM_029497 = 2500

local function SafeCall029497(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

local function Distance2D029497(ax, az, bx, bz)
    local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
    local dz = (tonumber(az) or 0) - (tonumber(bz) or 0)
    return math.sqrt((dx * dx) + (dz * dz))
end

local function DedupeRadius029497(kind)
    return tostring(kind or "") == "FISHING" and FISHING_DEDUPE_CM_029497 or NORMAL_DEDUPE_CM_029497
end

local function CompatibleKinds029497(a, b)
    a, b = tostring(a or "RESOURCE"), tostring(b or "RESOURCE")
    return a == b or a == "RESOURCE" or b == "RESOURCE"
end

local function NormalizeMapKey029497(value)
    local s = string.lower(tostring(value or ""))
    s = s:gsub("\\", "/")
    s = s:gsub("^/?esoui/art/maps/", "")
    s = s:gsub("^/?art/maps/", "")
    s = s:gsub("%.dds$", "")
    s = s:gsub("_[0-9]+$", "")
    s = s:gsub("^/+", ""):gsub("/+$", "")
    return s
end

local function CurrentTrustedMapKey029497()
    -- Do not force/set the map here. Only trust ESO's existing current map when
    -- its zone index agrees with the player's actual zone index.
    local playerZoneIndex = tonumber(SafeCall029497(GetUnitZoneIndex, "player"))
    local mapZoneIndex = type(GetCurrentMapZoneIndex) == "function" and tonumber(SafeCall029497(GetCurrentMapZoneIndex)) or nil
    if playerZoneIndex and mapZoneIndex and playerZoneIndex ~= mapZoneIndex then
        return nil
    end

    if type(GetCurrentMapId) ~= "function" or type(GetMapTileTextureForMapId) ~= "function" then
        return nil
    end
    local mapId = tonumber(SafeCall029497(GetCurrentMapId))
    if not mapId or mapId <= 0 then return nil end

    local texture = SafeCall029497(GetMapTileTextureForMapId, mapId, 1)
    if type(texture) ~= "string" or texture == "" then
        texture = SafeCall029497(GetMapTileTextureForMapId, mapId, 0)
    end
    local key = NormalizeMapKey029497(texture)
    return key ~= "" and key or nil
end

BuildCommunityZoneCacheImplArch = function(self, zoneId, forceForExplicitHunt)
    if not EPC.saved then return nil end
    if EPC.saved.resourcePinsCommunityEnabled == false and forceForExplicitHunt ~= true then return nil end
    zoneId = tonumber(zoneId)
    if not zoneId then return nil end

    local mapKey = CurrentTrustedMapKey029497()
    if self.communityZoneId == zoneId
        and self.communityZoneMapKey029497 == mapKey
        and type(self.communityZoneCache) == "table" then
        return self.communityZoneCache
    end

    local root = EPC.CommunityResourceData
    if type(root) ~= "table" then
        self.lastCommunityError = "Suite Community Resource Data is not loaded"
        return nil
    end

    -- If ESO cannot prove which map the player is on, retain the original safe
    -- behavior rather than guessing from a stale world-map state.
    if not mapKey then
        self.communityZoneMapKey029497 = nil
        self.communityZoneId = nil
        self.communityZoneCache = nil
        return ORIGINAL_BUILD_COMMUNITY_CACHE and ORIGINAL_BUILD_COMMUNITY_CACHE(self, zoneId, forceForExplicitHunt) or nil
    end

    local matchingMapData = {}
    for m = 1, #COMMUNITY_MODULES_029497 do
        local module = root[COMMUNITY_MODULES_029497[m]]
        local zoneData = type(module) == "table" and module[zoneId] or nil
        if type(zoneData) == "table" then
            for storedMapKey, mapData in pairs(zoneData) do
                if type(mapData) == "table" and NormalizeMapKey029497(storedMapKey) == mapKey then
                    matchingMapData[#matchingMapData + 1] = mapData
                end
            end
        end
    end

    -- A missing exact map key is safer as a fallback to the original decoder;
    -- do not silently make all community pins disappear on unusual maps.
    if #matchingMapData == 0 then
        self.communityZoneMapKey029497 = nil
        self.communityZoneId = nil
        self.communityZoneCache = nil
        return ORIGINAL_BUILD_COMMUNITY_CACHE and ORIGINAL_BUILD_COMMUNITY_CACHE(self, zoneId, forceForExplicitHunt) or nil
    end

    local cache = {
        zoneId = zoneId,
        mapKey = mapKey,
        cells = {}, count = 0, rawCount = 0, byKind = {}, corruptRecords = 0,
    }
    local dedupe = {}
    for i = 1, #matchingMapData do
        local mapData = matchingMapData[i]
        for pinTypeId, packed in pairs(mapData) do
            local kind = COMMUNITY_KIND_BY_PIN_029497[tonumber(pinTypeId)]
            if kind and type(packed) == "string" then
                self:DecodeCommunityPacked(cache, dedupe, kind, packed)
            end
        end
    end

    self.communityZoneId = zoneId
    self.communityZoneMapKey029497 = mapKey
    self.communityZoneCache = cache
    self.lastCommunityZoneCount = cache.count
    self.lastCommunityRawZoneCount = cache.rawCount
    self.lastCommunityMapKey029497 = mapKey
    self.lastCommunityError = nil
    return cache
end

IsCommunityShadowedImplArch = function(self, entry, shadow)
    if type(entry) ~= "table" or type(shadow) ~= "table" then return false end
    local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
    if not x or not y or not z then return false end

    local radius = DedupeRadius029497(entry.kind)
    local gx = math.floor(x / radius)
    local gz = math.floor(z / radius)
    -- BuildLearnedShadowGrid uses the older 3.75m cells, so direct scan the
    -- nearby shadow buckets and apply the wider final distance check.
    for _, nearby in pairs(shadow) do
        if type(nearby) == "table" then
            for i = 1, #nearby do
                local learned = nearby[i]
                if type(learned) == "table"
                    and CompatibleKinds029497(learned.kind, entry.kind)
                    and math.abs((tonumber(learned.y) or y) - y) <= VERTICAL_DEDUPE_CM_029497
                    and Distance2D029497(learned.x, learned.z, x, z) <= math.max(radius, DedupeRadius029497(learned.kind)) then
                    return true
                end
            end
        end
    end
    return false
end

DeduplicateVisibleCandidatesImplArch = function(self, visible)
    if type(visible) ~= "table" or #visible < 2 then return visible, 0 end

    table.sort(visible, function(a, b)
        if a.debug ~= b.debug then return a.debug == true end
        if a.focusedMissing ~= b.focusedMissing then return a.focusedMissing == true end
        if a.skyshard ~= b.skyshard then return a.skyshard == true end
        if a.learned ~= b.learned then return a.learned == true end
        return (tonumber(a.distanceM) or 999999) < (tonumber(b.distanceM) or 999999)
    end)

    local out, removed = {}, 0
    for i = 1, #visible do
        local candidate = visible[i]
        local entry = candidate and candidate.entry
        local duplicate = false
        if candidate.debug ~= true and candidate.skyshard ~= true and type(entry) == "table" then
            local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
            if x and y and z then
                for j = 1, #out do
                    local prior = out[j]
                    local other = prior and prior.entry
                    if prior.debug ~= true and prior.skyshard ~= true and type(other) == "table"
                        and CompatibleKinds029497(other.kind, entry.kind)
                        and math.abs((tonumber(other.y) or y) - y) <= VERTICAL_DEDUPE_CM_029497
                        and Distance2D029497(other.x, other.z, x, z) <= math.max(DedupeRadius029497(entry.kind), DedupeRadius029497(other.kind)) then
                        duplicate = true
                        break
                    end
                end
            end
        end
        if duplicate then
            removed = removed + 1
        else
            out[#out + 1] = candidate
        end
    end
    self.lastVisibleDuplicatesRemoved = removed
    return out, removed
end

function R:CompactLearnedLocationData029497()
    if not EPC.saved or type(EPC.saved.resourcePinLocations) ~= "table" then return 0 end
    local removed = 0
    for zoneKey, bucket in pairs(EPC.saved.resourcePinLocations) do
        if type(bucket) == "table" then
            local compact = {}
            for i = 1, #bucket do
                local entry = bucket[i]
                local duplicate = nil
                if type(entry) == "table" and tonumber(entry.x) and tonumber(entry.y) and tonumber(entry.z) then
                    for j = 1, #compact do
                        local other = compact[j]
                        if CompatibleKinds029497(other.kind, entry.kind)
                            and math.abs((tonumber(other.y) or 0) - (tonumber(entry.y) or 0)) <= VERTICAL_DEDUPE_CM_029497
                            and Distance2D029497(other.x, other.z, entry.x, entry.z) <= math.max(DedupeRadius029497(other.kind), DedupeRadius029497(entry.kind)) then
                            duplicate = other
                            break
                        end
                    end
                    if duplicate then
                        if tostring(duplicate.kind or "RESOURCE") == "RESOURCE" and tostring(entry.kind or "RESOURCE") ~= "RESOURCE" then
                            duplicate.kind = entry.kind
                        end
                        duplicate.lastSeenAt = math.max(tonumber(duplicate.lastSeenAt) or 0, tonumber(entry.lastSeenAt) or 0)
                        removed = removed + 1
                    else
                        compact[#compact + 1] = entry
                    end
                else
                    removed = removed + 1
                end
            end
            EPC.saved.resourcePinLocations[zoneKey] = compact
        end
    end
    self.lastLearnedCompactionRemoved029497 = removed
    return removed
end

if type(ORIGINAL_INITIALIZE) == "function" then
    InitializeImplArch = function(self, ...)
        ORIGINAL_INITIALIZE(self, ...)
        if EPC.saved and (tonumber(EPC.saved.resourcePinsDataCompactionVersion) or 0) < 3 then
            local removed = self:CompactLearnedLocationData029497()
            EPC.saved.resourcePinsDataCompactionVersion = 3
            self.lastLearnedCompactionRemoved029497 = removed
            self:RefreshMarkers()
        end
    end
end

-- END ABSORBED: ResourcePins3DLocationFix.lua


-- BEGIN ABSORBED: ResourcePinsFarmFocusAccuracyFix.lua
-- ESO Adventurer Suite
-- v0.29.666 - Farm Focus live-target validation and chest rarity glow.
-- Community/learned locations remain useful as navigation hints at range, but
-- close-range Farm Focus markers must agree with ESO's actual interactable.

local EPC = ESOProgressionCoach
local R = EPC and EPC.ResourcePins
if type(R) ~= "table" then return end
if R._easFarmFocusAccuracy029666 then return end
R._easFarmFocusAccuracy029666 = true

local CLOSE_VALIDATE_M = 3.25

local function lower(value)
    value = tostring(value or "")
    if type(zo_strlower) == "function" then
        local ok, text = pcall(zo_strlower, value)
        if ok and type(text) == "string" then return text end
    end
    return string.lower(value)
end

local function getLiveInteractable()
    if type(GetGameCameraInteractableActionInfo) ~= "function" then return nil end
    local ok, action, name, blocked, owned, additionalInfo, context, contextLink, criminal = pcall(GetGameCameraInteractableActionInfo)
    if not ok then return nil end

    name = tostring(name or "")
    local interactionType = nil
    if type(GetInteractionType) == "function" then
        local okType, value = pcall(GetInteractionType)
        if okType then interactionType = value end
    end

    local kind = type(R.ClassifyByName) == "function" and R:ClassifyByName(name) or nil
    local supported = type(R.IsSupportedResourceInteraction) == "function"
        and R:IsSupportedResourceInteraction(interactionType, name) == true

    return {
        name = name,
        kind = kind,
        supported = supported,
        interactionType = interactionType,
        additionalInfo = additionalInfo,
        context = context,
        contextLink = contextLink,
    }
end

local function sameFarmKind(candidateKind, liveKind)
    candidateKind = tostring(candidateKind or "RESOURCE")
    liveKind = tostring(liveKind or "RESOURCE")
    if candidateKind == liveKind then return true end
    if candidateKind == "RESOURCE" or liveKind == "RESOURCE" then return true end

    -- Alchemy subtypes are deliberately compatible with one another because a
    -- community point can be a generic reagent spawn while ESO exposes the
    -- specific plant/mushroom name currently occupying that spawn.
    local alchemy = {
        ALCHEMY = true, MUSHROOM = true, FLOWER = true, WATERPLANT = true,
    }
    if alchemy[candidateKind] and alchemy[liveKind] then return true end
    return false
end

local function chestTierFromContext(live)
    if type(live) ~= "table" or tostring(live.kind or "") ~= "CHEST" then return nil end
    if rawget(_G, "ADDITIONAL_INTERACT_INFO_LOCKED") ~= nil
        and live.additionalInfo ~= rawget(_G, "ADDITIONAL_INTERACT_INFO_LOCKED") then
        return nil
    end

    local context = live.context
    local comparisons = {
        { "LOCK_QUALITY_MASTER", "EPIC" },
        { "LOCK_QUALITY_ADVANCED", "RARE" },
        { "LOCK_QUALITY_INTERMEDIATE", "UNCOMMON" },
        { "LOCK_QUALITY_SIMPLE", "COMMON" },
        { "LOCK_QUALITY_PRACTICE", "COMMON" },
    }
    for i = 1, #comparisons do
        local value = rawget(_G, comparisons[i][1])
        if value ~= nil and context == value then return comparisons[i][2] end
    end

    -- ESO exposes the lock-quality text from the same context value used by the
    -- reticle. Keep a localized-string fallback for API builds where only part
    -- of the LockQuality enum is exported to insecure addon code.
    if context ~= nil and type(GetString) == "function" then
        local ok, text = pcall(GetString, "SI_LOCKQUALITY", context)
        text = ok and lower(text) or ""
        if string.find(text, "master", 1, true) then return "EPIC" end
        if string.find(text, "advanced", 1, true) then return "RARE" end
        if string.find(text, "intermediate", 1, true) then return "UNCOMMON" end
        if string.find(text, "simple", 1, true) or string.find(text, "practice", 1, true) then return "COMMON" end
    end
    return nil
end

local TIER_VISUALS = {
    COMMON = { color = { 0.95, 0.95, 0.95 }, alpha = 0.34 },
    UNCOMMON = { color = { 0.28, 0.86, 1.00 }, alpha = 0.50 },
    RARE = { color = { 0.82, 0.40, 1.00 }, alpha = 0.66 },
    EPIC = { color = { 1.00, 0.78, 0.22 }, alpha = 0.82 },
}

local baseGlow = GetGlowVisualForEntryImplArch
GetGlowVisualForEntryImplArch = function(self, entry, alphaBase)
    local forcedTier = type(entry) == "table" and tostring(entry.easFarmLiveTier029666 or "") or ""
    local visual = TIER_VISUALS[forcedTier]
    if visual then
        local saved = EPC.saved or {}
        local strength = math.max(0, math.min(1, (tonumber(saved.resourcePinsGlowStrength) or 78) / 100))
        local alpha = math.max(0.22, math.min(1.0, (tonumber(alphaBase) or 0.72) * visual.alpha * (0.70 + strength * 0.65)))
        local size = 0.98 + (0.08 * strength)
        return visual.color, alpha, size, forcedTier
    end
    if type(baseGlow) == "function" then return baseGlow(self, entry, alphaBase) end
    return { 1, 1, 1 }, tonumber(alphaBase) or 0.72, 1.0, "COMMON"
end

local baseDeduplicate = DeduplicateVisibleCandidatesImplArch
DeduplicateVisibleCandidatesImplArch = function(self, visible)
    if not EPC.saved or EPC.saved.resourcePinsFarmFocusEnabled ~= true or type(visible) ~= "table" then
        return type(baseDeduplicate) == "function" and baseDeduplicate(self, visible) or visible
    end

    local live = getLiveInteractable()
    local liveKind = live and live.supported and live.kind or nil
    local liveTier = chestTierFromContext(live)
    local filtered = {}

    for i = 1, #visible do
        local candidate = visible[i]
        local keep = type(candidate) == "table"
        if keep and candidate.debug ~= true and candidate.focusedMissing ~= true and candidate.skyshard ~= true then
            local distanceM = tonumber(candidate.horizontalDistanceM) or tonumber(candidate.distanceM) or 999999
            if distanceM <= CLOSE_VALIDATE_M then
                local entryKind = candidate.entry and tostring(candidate.entry.kind or "RESOURCE") or "RESOURCE"
                -- At interaction range, a database point is only trustworthy when
                -- ESO currently exposes a compatible live resource. Otherwise it
                -- is a stale/depleted/misaligned navigation hint and must vanish.
                keep = liveKind ~= nil and sameFarmKind(entryKind, liveKind)
                if keep and liveTier and type(candidate.entry) == "table" then
                    candidate.entry.easFarmLiveTier029666 = liveTier
                end
            end
        end
        if keep then filtered[#filtered + 1] = candidate end
    end

    -- Always add one marker for the resource ESO actually exposes under the
    -- reticle. This corrects stale community classifications (for example an
    -- Alchemy point occupying the same area as a live Heavy Sack) and gives a
    -- locked chest its real Simple/Intermediate/Advanced/Master glow.
    if liveKind and type(self.IsKindEnabled) == "function" and self:IsKindEnabled(liveKind)
        and type(self.GetApproximateInteractablePosition) == "function" then
        local zoneId, x, y, z = self:GetApproximateInteractablePosition()
        if zoneId and x and y and z then
            local entry = {
                kind = liveKind,
                name = live.name ~= "" and live.name or liveKind,
                x = x, y = y, z = z,
                source = "live",
                liveConfirmed029666 = true,
                easFarmLiveTier029666 = liveTier,
            }
            filtered[#filtered + 1] = {
                entry = entry,
                distanceM = 1.45,
                horizontalDistanceM = 1.45,
                learned = true,
                liveConfirmed029666 = true,
                noDepletionProbe = true,
            }
        end
    end

    if type(baseDeduplicate) == "function" then return baseDeduplicate(self, filtered) end
    return filtered
end

EPC.resourcePinsFarmFocusAccuracy029666 = true

-- END ABSORBED: ResourcePinsFarmFocusAccuracyFix.lua
