-- Dungeons.lua – DungeonFinderPlus
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus

DFP.Dungeons = { series = {} }

-- ───────────────── Helper ─────────────────
local function aZoneIsDLC(zoneId)
    if not (zoneId and zoneId ~= 0 and GetZoneIndex and GetCollectibleIdForZone and GetCollectibleInfo) then 
        return false 
    end
    local zi = GetZoneIndex(zoneId)
    if not zi or zi == 0 then return false end
    
    local cid = GetCollectibleIdForZone(zi)
    if not cid or cid == 0 then return false end
    
    local nm = select(1, GetCollectibleInfo(cid))
    return (type(nm) == "string" and nm ~= "")
end

local function cleanActivityName(name)
    if not name or name == "" then return "" end

    local s = zo_strformat("<<C:1>>", name)
    s = s:gsub("^%s*|t.-|t%s*", "")
    s = s:gsub("^[Vv]eteran[%s%-]+", "")
    s = s:gsub("^[Vv]étéran[%s%-]+", "")
    s = s:gsub("^[Vv]eterano[%s%-]+", "")
    s = s:gsub("^[Vv]eteranen?[%s%-]+", "")
    return zo_strtrim(s)
end

-- ───────────────── Rebuild ─────────────────
function DFP.Dungeons:Rebuild()
    local zones = {}

    local function scanType(actType, isVet)
        if type(GetNumActivitiesByType) ~= "function" or type(GetActivityIdByTypeAndIndex) ~= "function" then
            return
        end

        local count = GetNumActivitiesByType(actType)
        for i = 1, count do
            local actId = GetActivityIdByTypeAndIndex(actType, i)
            if actId and actId > 0 then
                -- Nur 4-Spieler-Dungeons (keine Arenen / Prüfungen)
                local _, _, _, _, _, _, minGroupSize = GetActivityInfo(actId)
                if minGroupSize == 4 then
                    local zoneId = GetActivityZoneId(actId)
                    local rawName = GetActivityName(actId)

                    if zoneId and zoneId > 0 and rawName and rawName ~= "" then
                        local entry = zones[zoneId]
                        if not entry then
                            entry = {
                                zoneId   = zoneId,
                                pretty   = cleanActivityName(rawName),
                                normalId = nil,
                                vetId    = nil,
                            }
                            zones[zoneId] = entry
                        end

                        if isVet then
                            entry.vetId = actId
                        else
                            entry.normalId = actId
                            
                            entry.pretty = cleanActivityName(rawName)
                        end
                    end
                end
            end
        end
    end

    
    scanType(LFG_ACTIVITY_DUNGEON, false)
    scanType(LFG_ACTIVITY_MASTER_DUNGEON, true)

    
    local OUT = {}
    for zoneId, e in pairs(zones) do
       
        local key = e.pretty
        if not key or key == "" then
            key = "zone_" .. tostring(zoneId)
        end

        OUT[key] = {
            key      = key,
            pretty   = e.pretty,
            normalId = e.normalId,
            vetId    = e.vetId,
            zoneId   = zoneId,
            isDLC    = aZoneIsDLC(zoneId),
        }
    end

    self.series = OUT
end

-- ───────────────── Iterator ─────────────────
function DFP.Dungeons:Iter()
    local t = {}
    for key, e in pairs(self.series) do
        t[#t + 1] = e
    end
    
    table.sort(t, function(a, b) 
        return (a.pretty or a.key) < (b.pretty or b.key) 
    end)

    local i = 0
    return function()
        i = i + 1
        local r = t[i]
        if not r then return nil end
        return r.key, r
    end
end