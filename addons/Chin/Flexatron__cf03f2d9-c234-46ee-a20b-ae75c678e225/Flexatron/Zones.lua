-- Where the player is, and what drives the title there: the best title earned in this trial,
-- dungeon or arena, or else the rotation.
local FT = Flexatron
local Titles = FT.Titles
local Zones = {}
FT.Zones = Zones

-- Trials, dungeons and arenas (delves and public dungeons count too, but rarely grant titles).
function Zones.InContent()
    return IsPlayerInRaid() or IsUnitInDungeon("player")
end

function Zones.Current()
    return GetZoneId(GetUnitZoneIndex("player")), GetUnitZone("player")
end

-- True if the text names the zone as a whole name, so "Fungal Grotto I" doesn't match
-- "Fungal Grotto II".
local function Mentions(text, name)
    if not text or not name or name == "" then
        return false
    end
    local haystack, needle = string.lower(text), string.lower(name)
    local start = 1
    while true do
        local i, j = string.find(haystack, needle, start, true)
        if not i then
            return false
        end
        local before = i > 1 and haystack:sub(i - 1, i - 1) or " "
        local after = haystack:sub(j + 1, j + 1)
        if not before:find("%w") and not after:find("%w") then
            return true
        end
        start = i + 1
    end
end

-- Title achievements for this zone, best first. Data/ZoneTitles.lua wins when it lists the zone;
-- otherwise every title achievement whose name or description names the zone, ranked by points
-- (trifectas and hard modes are worth the most), then by the longer description.
function Zones.Candidates()
    local zoneId, zoneName = Zones.Current()
    local found = {}
    local listed = FT.ZoneTitles and FT.ZoneTitles[zoneId]
    if listed then
        for _, id in ipairs(listed) do
            local hasTitle, title = GetAchievementRewardTitle(id)
            if hasTitle then
                found[#found + 1] = { id = id, title = title, points = select(3, GetAchievementInfo(id)) or 0 }
            end
        end
        return found, zoneId, zoneName
    end
    for _, entry in ipairs(FT.TitleIndex.Entries()) do
        local name, description, points = GetAchievementInfo(entry.id)
        if Mentions(name, zoneName) or Mentions(description, zoneName) then
            found[#found + 1] = { id = entry.id, title = entry.title, points = points or 0, length = #(description or "") }
        end
    end
    table.sort(found, function(a, b)
        if a.points ~= b.points then
            return a.points > b.points
        end
        if a.length ~= b.length then
            return a.length > b.length
        end
        return a.id < b.id
    end)
    return found, zoneId, zoneName
end

-- Index of the best title the player has earned here, or nil.
function Zones.BestTitle()
    for _, candidate in ipairs((Zones.Candidates())) do
        if IsAchievementComplete(candidate.id) then
            local index = Titles.IndexOf(candidate.title)
            if index then
                return index
            end
        end
    end
    return nil
end

-- What should drive the title here: { kind = "hold", index }, { kind = "rotate", names }, or nil
-- to leave the title alone.
function Zones.Plan()
    local sv = FT.sv
    if sv.autoMode and Zones.InContent() then
        local index = Zones.BestTitle()
        if index then
            return { kind = "hold", index = index }
        end
    end
    if sv.rotate and #sv.titles > 0 then
        return { kind = "rotate", names = sv.titles }
    end
    return nil
end
