-- shared
-- Where the skill points still to earn are: skyshards (three make a point), public dungeons
-- (each one's group event gives a point) and Alliance War rank (a point per rank).
--   c.shards, c.shardsTotal          skyshards collected, and how many exist
--   c.shardsMissing                  "Glenumbra 13/16;Stormhaven 15/16": zones with some left
--   c.pubDungeons, c.pubDungeonsTotal, c.pubDungeonsMissing ("Group event;Group event")
--   c.avaRank                        Alliance War rank, 0 to 50
-- A public dungeon counts once its group event achievement is earned: that achievement is what
-- gives the skill point. The zone guide is no use here, it goes by the dungeon's quests.
local CT = FurysCharacterTracker
local U = CT.Util

local NOT_READ = "Not read yet: log in on this character once."
local LIST_MAX = 24   -- zones named in one hover text

-- The group event achievement of every public dungeon, in the order the zones came out.
local GROUP_EVENTS = { 468, 470, 445, 460, 469, 380, 714, 713, 707, 708, 379, 388, 372, 381, 371, 874,
                       1855, 1846, 1238, 1235, 2096, 2095, 2444, 2445, 2714, 2715, 2994, 2995, 3281, 3283,
                       3658, 3657, 4000, 4002, 4264, 4471 }

local function ZoneList(text, title)
    local zones = U.Split(text or "", ";")
    if #zones == 0 or zones[1] == "" then return nil end
    local lines = { title }
    for index, zone in ipairs(zones) do
        if index > LIST_MAX then
            lines[#lines + 1] = string.format("  and %d more", #zones - LIST_MAX)
            break
        end
        lines[#lines + 1] = "  " .. zone
    end
    return table.concat(lines, "\n")
end

CT.Track({
    id = "skillPoints",
    read = function(c)
        -- Every skyshard in the game, then zone by zone for the list of where the missing ones are.
        local total, have = GetNumSkyshards(), 0
        if total > 0 then
            for index = 1, total do
                if GetSkyshardDiscoveryStatus(GetSkyshardId(index)) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then have = have + 1 end
            end
            local missing = {}
            local zoneId = GetNextZoneStoryZoneId()
            while zoneId do
                local zoneName = U.Clean(U.Plain(GetZoneNameById(zoneId)))
                local inZone, got = GetNumSkyshardsInZone(zoneId), 0
                for index = 1, inZone do
                    if GetSkyshardDiscoveryStatus(GetZoneSkyshardId(zoneId, index)) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then got = got + 1 end
                end
                if got < inZone then missing[#missing + 1] = string.format("%s %d/%d", zoneName, got, inZone) end
                zoneId = GetNextZoneStoryZoneId(zoneId)
            end
            table.sort(missing)
            c.shards, c.shardsTotal, c.shardsMissing = have, total, table.concat(missing, ";")
        end
        local done, left = 0, {}
        for _, achievementId in ipairs(GROUP_EVENTS) do
            if IsAchievementComplete(achievementId) then
                done = done + 1
            else
                left[#left + 1] = U.Clean(U.Plain((GetAchievementInfo(achievementId))))
            end
        end
        c.pubDungeons, c.pubDungeonsTotal, c.pubDungeonsMissing = done, #GROUP_EVENTS, table.concat(left, ";")
        c.avaRank = GetUnitAvARank("player")
    end,
    events = { EVENT_SKYSHARDS_UPDATED, EVENT_ACHIEVEMENT_AWARDED },
    start = function(queue)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "AvaRank", EVENT_RANK_POINT_UPDATE, queue)
        EVENT_MANAGER:AddFilterForEvent(CT.name .. "AvaRank", EVENT_RANK_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end,
    columns = {
        { key = "shards", title = "Skyshards", width = 100, max = function(e) return e.c.shardsTotal end,
          head = "Skyshards collected, out of every skyshard in the game. Three skyshards make one skill point.\nHover a cell for the zones that still have some.",
          value = function(e) return e.c.shards or 0 end,
          display = function(v, e) return e.c.shardsTotal and U.Of(v, e.c.shardsTotal) or "-" end,
          dim = function(_, e) return not e.c.shardsTotal end,
          tip = function(e)
              local c = e.c
              if not c.shardsTotal then return NOT_READ end
              local left = c.shardsTotal - c.shards
              if left <= 0 then return "Every skyshard collected." end
              local text = string.format("Skyshards: %d of %d\n%d left, worth %s.", c.shards, c.shardsTotal, left,
                                         U.Count(math.floor((c.shards % 3 + left) / 3), "skill point"))
              local zones = ZoneList(c.shardsMissing, "\nZones with skyshards left")
              return zones and (text .. "\n" .. zones) or text
          end },
        { key = "shardPoints", title = "Shard pts left", width = 108,
          head = "Skill points this character can still earn from skyshards.",
          value = function(e)
              local c = e.c
              if not c.shardsTotal then return -1 end
              return math.floor((c.shards % 3 + (c.shardsTotal - c.shards)) / 3)
          end,
          display = function(v) return v < 0 and "-" or (v == 0 and "Done" or U.Whole(v)) end,
          dim = function(v) return v < 0 end, gold = function(v) return v == 0 end,
          tip = function(e)
              if not e.c.shardsTotal then return NOT_READ end
              return "Skill points still to earn from skyshards. The Skyshards column lists the zones." end },
        { key = "pubDungeons", title = "Public dungeons", width = 124, max = function(e) return e.c.pubDungeonsTotal end,
          head = "Public dungeons where this character has done the group event. Each group event gives one skill point.\nHover a cell for the ones still to do.",
          value = function(e) return e.c.pubDungeons or 0 end,
          display = function(v, e) return e.c.pubDungeonsTotal and U.Of(v, e.c.pubDungeonsTotal) or "-" end,
          dim = function(_, e) return not e.c.pubDungeonsTotal end,
          tip = function(e)
              local c = e.c
              if not c.pubDungeonsTotal then return NOT_READ end
              if c.pubDungeons >= c.pubDungeonsTotal then return "Every public dungeon group event done." end
              local text = string.format("Public dungeon group events done: %d of %d\n%s still to earn here.", c.pubDungeons, c.pubDungeonsTotal,
                                         U.Count(c.pubDungeonsTotal - c.pubDungeons, "skill point"))
              local zones = ZoneList(c.pubDungeonsMissing, "\nStill to do")
              return zones and (text .. "\n" .. zones) or text
          end },
        { key = "avaRank", title = "AvA rank", width = 88, max = CT.AVA_RANK_MAX,
          head = "Alliance War rank, out of " .. CT.AVA_RANK_MAX .. ". Every rank gives one skill point.",
          value = function(e) return e.c.avaRank or 0 end,
          dim = function(_, e) return not e.c.avaRank end,
          tip = function(e)
              if not e.c.avaRank then return NOT_READ end
              return string.format("Alliance War rank %d of %d\n%s still to earn here.", e.c.avaRank, CT.AVA_RANK_MAX,
                                   U.Count(CT.AVA_RANK_MAX - e.c.avaRank, "skill point"))
          end },
    },
    sections = function(e)
        local c = e.c
        if not c.shardsTotal then return nil end
        local P = CT.Trackers.Progress
        local section = { title = "Skill points still to earn", items = {
            P("Skyshards", c.shards, c.shardsTotal), P("Public dungeons", c.pubDungeons or 0, c.pubDungeonsTotal or #GROUP_EVENTS),
            P("Alliance War rank", c.avaRank, CT.AVA_RANK_MAX) }, lines = {} }
        if c.shardsMissing and c.shardsMissing ~= "" then
            section.lines[#section.lines + 1] = "Skyshards left in: " .. (c.shardsMissing:gsub(";", ", "))
        end
        if c.pubDungeonsMissing and c.pubDungeonsMissing ~= "" then
            section.lines[#section.lines + 1] = "Group events left: " .. (c.pubDungeonsMissing:gsub(";", ", "))
        end
        return { section }
    end,
    export = {
        { "Skyshards", function(e) return e.c.shards end }, { "Skyshards total", function(e) return e.c.shardsTotal end },
        { "Public dungeons", function(e) return e.c.pubDungeons end }, { "Alliance War rank", function(e) return e.c.avaRank end },
    },
})
