-- Tables: zones, pois, wayshrines, activities, classes, races, maps, skyshards.

local E = LibESQL
local Try, Clean, Tick, EnumShort = E.Try, E.CleanName, E.Tick, E.EnumShort
local FUNCS = E.SQL.FUNCS

local function bool(v) return v and true or false end
local function nonEmpty(s) if s ~= nil and s ~= "" then return s end end

E.RegisterTable({
    name = "zones",
    desc = "Every zone: name, parent zone, description, POI and skyshard counts",
    key = "id",
    columns = {
        { "id", "int", "Zone id" },
        { "zone_index", "int", "Zone index" },
        { "name", "text", "Zone name" },
        { "parent_zone_id", "int", "Parent zone id" },
        { "parent_zone", "text", "Parent zone name" },
        { "num_pois", "int", "Points of interest" },
        { "num_skyshards", "int", "Skyshards", function(r) return Try(GetNumSkyshardsInZone, r.id) end },
        { "collectible_id", "int", "DLC collectible that unlocks it", function(r)
            local v = Try(GetCollectibleIdForZone, r.zone_index); if v and v > 0 then return v end end },
        { "story_zone_id", "int", "Zone story zone id", function(r) return Try(GetZoneStoryZoneIdForZoneId, r.id) end },
        { "description", "text", "Description", function(r) return nonEmpty(Try(GetZoneDescriptionById, r.id)) end },
    },
    build = function(rows)
        for i = 1, (Try(GetNumZones) or 0) do
            Tick()
            local id = Try(GetZoneId, i)
            if id and id > 0 then
                local name = Clean(Try(GetZoneNameByIndex, i))
                if name and name ~= "" then
                    local parent = Try(GetParentZoneId, id)
                    rows[#rows + 1] = {
                        id = id, zone_index = i, name = name,
                        parent_zone_id = parent,
                        parent_zone = parent and parent > 0 and parent ~= id and Clean(Try(GetZoneNameById, parent)) or nil,
                        num_pois = Try(GetNumPOIs, i),
                    }
                end
            end
        end
    end,
})

FUNCS.ZONE_NAME = function(id) id = tonumber(id); return id and Clean(Try(GetZoneNameById, id)) end

E.RegisterTable({
    name = "pois",
    desc = "Points of interest in every zone (wayshrines, dungeons, delves, skyshards...)",
    columns = {
        { "zone_id", "int", "Zone id" },
        { "zone", "text", "Zone name" },
        { "zone_index", "int", "Zone index" },
        { "poi_index", "int", "POI index in the zone" },
        { "name", "text", "Name" },
        { "type", "text", "PointOfInterestType" },
        { "instance_type", "text", "InstanceType", function(r)
            local v = Try(GetPOIInstanceType, r.zone_index, r.poi_index); return v and EnumShort("INSTANCE_TYPE_", v) end },
        { "skyshard_id", "int", "Skyshard id", function(r)
            local v = Try(GetPOISkyshardId, r.zone_index, r.poi_index); if v and v > 0 then return v end end },
        { "level", "int", "Objective level" },
        { "start_text", "text", "Start description" },
        { "finished_text", "text", "Finished description" },
    },
    build = function(rows)
        for _, z in ipairs(E.GetRows(E.GetTable("zones"))) do
            for p = 1, (z.num_pois or 0) do
                Tick()
                local name, level, startText, finishedText = Try(GetPOIInfo, z.zone_index, p)
                if name and name ~= "" then
                    local t = Try(GetPOIType, z.zone_index, p)
                    rows[#rows + 1] = {
                        zone_id = z.id, zone = z.name, zone_index = z.zone_index, poi_index = p,
                        name = Clean(name), level = level, start_text = nonEmpty(startText), finished_text = nonEmpty(finishedText),
                        type = t and EnumShort("POI_TYPE_", t),
                    }
                end
            end
        end
    end,
})

E.RegisterTable({
    name = "wayshrines",
    desc = "Fast-travel nodes (wayshrines, dungeons, trials, houses) and whether you know them",
    live = true,
    columns = {
        { "node_index", "int", "Fast travel node index" },
        { "name", "text", "Name" },
        { "known", "bool", "Discovered" },
        { "type", "text", "PointOfInterestType" },
        { "x", "num", "Normalized map x" },
        { "y", "num", "Normalized map y" },
        { "house_id", "int", "House id for houses", function(r)
            local v = Try(GetFastTravelNodeHouseId, r.node_index); if v and v > 0 then return v end end },
        { "zone_id", "int", "Zone id", function(r)
            local zi = Try(GetFastTravelNodePOIIndicies, r.node_index)
            return zi and Try(GetZoneId, zi) end },
        { "icon", "text", "Map icon" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumFastTravelNodes) or 0) do
            Tick()
            local known, name, x, y, icon, _, poiType = Try(GetFastTravelNodeInfo, i)
            if name and name ~= "" then
                rows[#rows + 1] = {
                    node_index = i, name = Clean(name), known = bool(known), x = x, y = y, icon = icon,
                    type = poiType and EnumShort("POI_TYPE_", poiType),
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "activities",
    desc = "Group finder activities: dungeons, trials, battlegrounds, arenas...",
    key = "id",
    columns = {
        { "id", "int", "Activity id" },
        { "name", "text", "Name" },
        { "type", "text", "LFGActivity: dungeon, master_dungeon, trial, battle_ground_*..." },
        { "min_level", "int", "Minimum level" },
        { "max_level", "int", "Maximum level" },
        { "min_cp", "int", "Minimum champion points" },
        { "max_cp", "int", "Maximum champion points" },
        { "group_type", "text", "LFGGroupType" },
        { "min_group_size", "int", "Minimum group size" },
        { "zone_id", "int", "Zone id", function(r) local v = Try(GetActivityZoneId, r.id); if v and v > 0 then return v end end },
        { "description", "text", "Description" },
    },
    build = function(rows)
        local lo, hi = E.EnumRange("LFG_ACTIVITY_", 0, 20)
        local seen = {}
        for t = lo or 0, hi or 20 do
            for i = 1, (Try(GetNumActivitiesByType, t) or 0) do
                Tick()
                local id = Try(GetActivityIdByTypeAndIndex, t, i)
                if id and not seen[id] then
                    seen[id] = true
                    local name, lmin, lmax, cmin, cmax, groupType, minSize, desc = Try(GetActivityInfo, id)
                    rows[#rows + 1] = {
                        id = id, name = Clean(name), type = EnumShort("LFG_ACTIVITY_", t),
                        min_level = lmin, max_level = lmax, min_cp = cmin, max_cp = cmax,
                        group_type = groupType and EnumShort("LFG_GROUP_TYPE_", groupType),
                        min_group_size = minSize, description = nonEmpty(desc),
                    }
                end
            end
        end
    end,
})

local function playerGender()
    return Try(GetUnitGender, "player") or GENDER_MALE or 2
end

E.RegisterTable({
    name = "classes",
    desc = "Playable classes and their skill lines",
    key = "id",
    columns = {
        { "id", "int", "Class id" },
        { "name", "text", "Class name" },
        { "selectable", "bool", "Selectable at character creation" },
        { "num_skill_lines", "int", "Class skill lines" },
        { "skill_lines", "text", "Skill line names" },
        { "collectible_id", "int", "Collectible that unlocks the class" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumClasses) or 0) do
            Tick()
            local id, _, _, _, _, selectable = Try(GetClassInfo, i)
            if id then
                local lines = {}
                local n = Try(GetNumSkillLinesForClass, id) or 0
                for k = 1, n do
                    local lineId = Try(GetSkillLineIdForClass, id, k)
                    if lineId then lines[#lines + 1] = Clean(Try(GetSkillLineNameById, lineId)) end
                end
                local coll = Try(GetClassAccessCollectibleId, id)
                rows[#rows + 1] = {
                    id = id, name = Clean(Try(GetClassName, playerGender(), id)), selectable = bool(selectable),
                    num_skill_lines = n, skill_lines = table.concat(lines, ", "),
                    collectible_id = coll and coll > 0 and coll or nil,
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "class_skill_lines",
    desc = "Skill lines of every class, including classes you don't play",
    key = "id",
    columns = {
        { "id", "int", "Skill line id" },
        { "name", "text", "Skill line name" },
        { "class_id", "int", "Class id" },
        { "class", "text", "Class name" },
        { "line_number", "int", "1-3 within the class" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumClasses) or 0) do
            local id = Try(GetClassInfo, i)
            if id then
                local className = Clean(Try(GetClassName, playerGender(), id))
                for k = 1, (Try(GetNumSkillLinesForClass, id) or 0) do
                    Tick()
                    local lineId = Try(GetSkillLineIdForClass, id, k)
                    if lineId then
                        rows[#rows + 1] = {
                            id = lineId, name = Clean(Try(GetSkillLineNameById, lineId)),
                            class_id = id, class = className, line_number = k,
                        }
                    end
                end
            end
        end
    end,
})

E.RegisterTable({
    name = "races",
    desc = "Playable races",
    key = "id",
    columns = { { "id", "int", "Race id" }, { "name", "text", "Race name" } },
    build = function(rows)
        for id = 1, 20 do
            Tick()
            local n = Try(GetRaceName, playerGender(), id)
            if n and n ~= "" then rows[#rows + 1] = { id = id, name = Clean(n) } end
        end
    end,
})

E.RegisterTable({
    name = "maps",
    desc = "World maps",
    key = "map_index",
    columns = {
        { "map_index", "int", "Map index" },
        { "name", "text", "Map name" },
        { "map_type", "text", "UIMapType" },
        { "content_type", "text", "MapContentType" },
        { "zone_index", "int", "Zone index" },
        { "zone_id", "int", "Zone id" },
        { "description", "text", "Description" },
    },
    build = function(rows)
        for i = 1, (Try(GetNumMaps) or 0) do
            Tick()
            local name, mapType, contentType, zoneIndex, desc = Try(GetMapInfoByIndex, i)
            if name and name ~= "" then
                rows[#rows + 1] = {
                    map_index = i, name = Clean(name),
                    map_type = mapType and EnumShort("MAPTYPE_", mapType),
                    content_type = contentType and EnumShort("MAP_CONTENT_", contentType),
                    zone_index = zoneIndex, zone_id = zoneIndex and Try(GetZoneId, zoneIndex),
                    description = nonEmpty(desc),
                }
            end
        end
    end,
})
