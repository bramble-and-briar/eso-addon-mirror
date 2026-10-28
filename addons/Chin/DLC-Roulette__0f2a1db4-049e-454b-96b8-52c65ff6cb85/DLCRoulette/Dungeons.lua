-- DLC Roulette. Copyright (c) 2026 -chin. All rights reserved: no copying, sharing, changes or reuse.
-- Dungeons: which dungeons are DLC, and the queue. Everything is read from the game's own Dungeon Finder data
-- each time, so dungeons from new DLC show up without an update.
local DR = DLCRoulette
local L = DR.L
local Dungeons = {}
DR.Dungeons = Dungeons

local finder = ZO_ACTIVITY_FINDER_ROOT_MANAGER

-- A DLC dungeon needs a collectible (its DLC pack) to enter. Base game dungeons need none.
local function IsDLC(location)
    return location:GetEntryType() == ZO_ACTIVITY_FINDER_LOCATION_ENTRY_TYPE.SPECIFIC
        and GetRequiredActivityCollectibleId(location:GetId()) ~= 0
end

local function IsIncluded(location)
    return not DR.sv.excluded[GetActivityZoneId(location:GetId())]
end

-- Every DLC dungeon once, by its Normal entry, sorted by name: { zoneId, name } for the settings list.
function Dungeons.List()
    local list = {}
    for _, location in ipairs(finder:GetLocationsData(LFG_ACTIVITY_DUNGEON) or {}) do
        if IsDLC(location) then
            list[#list + 1] = { zoneId = GetActivityZoneId(location:GetId()), name = location:GetNameGamepad() }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- The same check the game's own Join Queue button makes.
function Dungeons.CanQueue()
    return not IsCurrentlySearchingForGroup() and not finder:IsLockedByNotLeader() and not ZO_GroupFinder_IsGroupFinderInUse()
end

-- Selects every ticked DLC dungeon of one difficulty (LFG_ACTIVITY_DUNGEON or LFG_ACTIVITY_MASTER_DUNGEON)
-- and joins the queue, exactly as ticking them by hand and pressing Join Queue would. Dungeons the player
-- can't enter (DLC not owned, level, cooldown) are locked by the game and left out.
function Dungeons.Queue(activityType)
    if IsCurrentlySearchingForGroup() then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, L.ALREADY_QUEUED)
        return
    end
    if finder:IsLockedByNotLeader() then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, L.NOT_LEADER)
        return
    end
    finder:ClearAndUpdate()
    local count = 0
    for _, location in ipairs(finder:GetLocationsData(activityType) or {}) do
        if IsDLC(location) and IsIncluded(location) and location:IsActive() and not location:IsLocked() then
            finder:SetLocationSelected(location, true)
            count = count + 1
        end
    end
    if count == 0 then
        local none = activityType == LFG_ACTIVITY_MASTER_DUNGEON and L.NONE_VET or L.NONE_NORMAL
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, none)
        return
    end
    -- the game reports a refused queue itself
    finder:StartSearch()
    PlaySound(SOUNDS.DIALOG_ACCEPT)
end
