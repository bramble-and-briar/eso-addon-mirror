-- High Achiever: start-up, saved options and shared helpers.

ESOC_HighAchiever = ESOC_HighAchiever or {}
local HA = ESOC_HighAchiever

HA.NAME = "ESOCHighAchiever"
HA.TITLE = "High Achiever"

local DEFAULTS = {
    options = {
        showPanel = true,
        panelSeconds = 15,
        autoPin = false,
    },
}

-- Calls a game function without letting an error stop the add-on.
function HA.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    return unpack(result, 2)
end

-- Removes the game's grammar codes ("^n", "^F") from names. Only for text that is shown.
function HA.Clean(text)
    if text == nil or text == "" then return "" end
    local ok, cleaned = pcall(zo_strformat, "<<1>>", text)
    return ok and cleaned or tostring(text)
end

-- Lower case with plain apostrophes and single spaces, for matching.
-- Kept cheap (no zo_strformat): it runs on thousands of achievement names.
function HA.Lower(text)
    if text == nil then return "" end
    local key = string.lower(tostring(text))
    local caret = string.find(key, "^", 1, true)
    if caret then key = string.sub(key, 1, caret - 1) end
    key = string.gsub(key, "\226\128\153", "'")
    key = string.gsub(key, "%s+", " ")
    key = string.gsub(key, "^ ", "")
    key = string.gsub(key, " $", "")
    return key
end

-- True when the name appears in the text as whole words:
-- "spindleclutch i" is in "spindleclutch i vanquisher" but not in "spindleclutch ii vanquisher".
function HA.HasName(text, name)
    if text == "" or name == "" then return false end
    local start = 1
    while true do
        local first, last = string.find(text, name, start, true)
        if not first then return false end
        local before = first == 1 or not string.find(string.sub(text, first - 1, first - 1), "%w")
        local after = last == #text or not string.find(string.sub(text, last + 1, last + 1), "%w")
        if before and after then return true end
        start = first + 1
    end
end

-- Whether an achievement is earned, the way the game's own Achievements screen decides it.
-- For character achievements this is the character you're playing.
function HA.Earned(achievementId)
    if not achievementId or achievementId == 0 then return false end
    local ok, _, _, _, _, completed = pcall(GetAchievementInfo, achievementId)
    return ok and completed == true
end

function HA.Colour(hex, text)
    return "|c" .. hex .. text .. "|r"
end
HA.GREEN, HA.RED, HA.YELLOW, HA.GREY, HA.GOLD = "60d060", "ff7070", "ffd060", "a0a0a0", "f2cc66"

function HA.Alert(text)
    pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, HA.TITLE .. ": " .. text)
end

-- The zone a delve, town or public dungeon belongs to.
function HA.RootZone(zoneId)
    if not zoneId or zoneId == 0 then return 0 end
    local story = HA.Safe(GetZoneStoryZoneIdForZoneId, zoneId)
    if story and story ~= 0 then return story end
    local parent = HA.Safe(GetParentZoneId, zoneId)
    if parent and parent ~= 0 then return parent end
    return zoneId
end

function HA.PlayerZoneId()
    local index = HA.Safe(GetUnitZoneIndex, "player")
    return index and HA.Safe(GetZoneId, index) or 0
end

-- Pins an achievement to the game's own on-screen tracker (0 unpins).
function HA.Pin(achievementId)
    local ok = pcall(SetTrackedAchievement, achievementId or 0)
    if ok and achievementId and achievementId ~= 0 then
        pcall(function() HUD_TRACKER_MANAGER:SetAssistedAspiration(ZO_HUD_TRACKER_ASPIRATION.ACHIEVEMENT) end)
    end
    return ok
end

function HA.Pinned()
    local id = HA.Safe(GetTrackedAchievement)
    if id and id ~= 0 then return id end
    return nil
end

local function onLoaded(_, addonName)
    if addonName ~= HA.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(HA.NAME, EVENT_ADD_ON_LOADED)
    HA.sv = ZO_SavedVars:NewAccountWide("ESOCHighAchiever_SV", 1, nil, DEFAULTS)

    HA.Settings.Install()
    local function changed()
        HA.Place.MarkDirty()
        if HA.Screen.IsShowing() then HA.Screen.Refresh() end
    end
    EVENT_MANAGER:RegisterForEvent(HA.NAME, EVENT_PLAYER_ACTIVATED, function()
        HA.Place.MarkDirty()
        HA.Index.Start()
        HA.Panel.OnZone()
    end)
    EVENT_MANAGER:RegisterForEvent(HA.NAME, EVENT_ACHIEVEMENT_AWARDED, changed)
    EVENT_MANAGER:RegisterForEvent(HA.NAME, EVENT_ACHIEVEMENT_UPDATED, changed)
    EVENT_MANAGER:RegisterForEvent(HA.NAME, EVENT_ACHIEVEMENTS_UPDATED, changed)
end

EVENT_MANAGER:RegisterForEvent(HA.NAME, EVENT_ADD_ON_LOADED, onLoaded)
