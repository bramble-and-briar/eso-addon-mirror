-- Zone types a profile can be loaded in, and which one the player is in right now.

QuickslotProfiles = QuickslotProfiles or {}
local QSP = QuickslotProfiles

-- In the order they are checked (the first match wins) and shown in the settings.
QSP.ZONE_TYPES =
{
    { key = "battleground", name = "Battlegrounds" },
    { key = "imperialCity", name = "Imperial City", tooltip = "The Imperial City and its sewers." },
    { key = "cyrodiil", name = "Cyrodiil", tooltip = "Including Cyrodiil's delves." },
    { key = "infiniteArchive", name = "Infinite Archive" },
    { key = "arena", name = "Arenas", tooltip = "Maelstrom Arena, Dragonstar Arena, Blackrose Prison, Vateshran Hollows." },
    { key = "trial", name = "Trials" },
    { key = "dungeon", name = "Group dungeons" },
    { key = "house", name = "Houses" },
    { key = "delve", name = "Delves and public dungeons", tooltip = "Outside Cyrodiil." },
    { key = "other", name = "Everything else", tooltip = "Overland, and every zone type that no profile has." },
}

QSP.ZONE_TYPE_NAMES = {}
for _, zoneType in ipairs(QSP.ZONE_TYPES) do
    QSP.ZONE_TYPE_NAMES[zoneType.key] = zoneType.name
end

local ARENA_ZONES =
{
    [635] = true, -- Dragonstar Arena
    [677] = true, -- Maelstrom Arena
    [1082] = true, -- Blackrose Prison
    [1227] = true, -- Vateshran Hollows
}

-- Trials are also recognized by IsPlayerInRaid(); the list covers the moments that is
-- false (e.g. right after the loading screen).
local TRIAL_ZONES =
{
    [636] = true, [638] = true, [639] = true, [725] = true, [975] = true, [1000] = true,
    [1051] = true, [1121] = true, [1196] = true, [1263] = true, [1344] = true, [1427] = true,
    [1478] = true, [1548] = true,
}

local CYRODIIL_ZONE_ID = 181

local function GetPlayerZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and GetZoneId(zoneIndex) or 0
end

function QSP.GetZoneType()
    if GetCurrentBattlegroundId() ~= 0 then return "battleground" end
    if IsInImperialCity() then return "imperialCity" end
    local zoneId = GetPlayerZoneId()
    -- Cyrodiil's delves are zones of their own; their parent zone is Cyrodiil.
    if IsInCyrodiil() or GetParentZoneId(zoneId) == CYRODIIL_ZONE_ID then return "cyrodiil" end
    if IsInstanceEndlessDungeon() then return "infiniteArchive" end
    if ARENA_ZONES[zoneId] then return "arena" end
    if TRIAL_ZONES[zoneId] or IsPlayerInRaid() then return "trial" end
    if GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE then return "dungeon" end
    if GetCurrentZoneHouseId() ~= 0 then return "house" end
    if IsUnitInDungeon("player") then return "delve" end
    return "other"
end
