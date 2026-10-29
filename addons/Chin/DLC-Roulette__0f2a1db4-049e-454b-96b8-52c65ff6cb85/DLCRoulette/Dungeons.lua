-- DLC Roulette. Copyright (c) 2026 -Chin. All rights reserved: no copying, sharing, changes or reuse.
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

-- Whether the buttons show at all. Not being the group leader doesn't hide them: pressing one then says so,
-- which is clearer than a button that quietly isn't there.
function Dungeons.CanShow()
    return not IsCurrentlySearchingForGroup() and not ZO_GroupFinder_IsGroupFinderInUse()
end

-- Ticks every DLC dungeon of one difficulty the player has left in and can enter, exactly as ticking them by
-- hand would. Dungeons they can't enter (DLC not owned, level, the game's own lockout) are locked by the game
-- and left out. Returns how many were ticked, and how many were skipped only for being on our cooldown.
local function Select(activityType)
    local count, onCooldown = 0, 0
    for _, location in ipairs(finder:GetLocationsData(activityType) or {}) do
        if IsDLC(location) and IsIncluded(location) and location:IsActive() and not location:IsLocked() then
            if DR.Cooldown.IsOn(activityType, GetActivityZoneId(location:GetId())) then
                onCooldown = onCooldown + 1
            else
                finder:SetLocationSelected(location, true)
                count = count + 1
            end
        end
    end
    return count, onCooldown
end

-- Selects the dungeons and joins the queue, the same as pressing Join Queue would.
function Dungeons.Queue(activityType)
    if IsCurrentlySearchingForGroup() then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, L.ALREADY_QUEUED)
        return
    end
    if finder:IsLockedByNotLeader() then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, L.NOT_LEADER)
        return
    end
    -- A keybind can be pressed at any time, unlike the buttons, so check this here too rather than clearing
    -- the player's ticks and letting the game refuse the queue afterwards.
    if ZO_GroupFinder_IsGroupFinderInUse() then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, L.IN_GROUP_FINDER)
        return
    end
    finder:ClearAndUpdate()
    local count, onCooldown = Select(activityType)
    -- Been in all of them: the hold has run its course, so it starts over rather than leaving nothing to queue.
    if count == 0 and onCooldown > 0 then
        DR.Cooldown.Clear(activityType)
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, L.COOLDOWNS_RESET)
        count = Select(activityType)
    end
    if count == 0 then
        local none = activityType == LFG_ACTIVITY_MASTER_DUNGEON and L.NONE_VET or L.NONE_NORMAL
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, none)
        return
    end
    -- the game reports a refused queue itself
    finder:StartSearch()
    DR.Cooldown.Listen(activityType)
    PlaySound(SOUNDS.DIALOG_ACCEPT)
end
