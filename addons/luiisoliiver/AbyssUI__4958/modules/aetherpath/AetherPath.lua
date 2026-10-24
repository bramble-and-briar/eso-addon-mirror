--[[
    AetherPath - Original ESO Addon (embedded in AbyssUI)
    Quest tracker + wayshrine travel helper
    Minimalist dark UI | Multi-language | No external textures
    All code written from scratch - no third-party addon code used
]]

AetherPath = AetherPath or {}
local AP = AetherPath

-- Also expose under NAGA_UI for consistency with host
NAGA_UI = NAGA_UI or {}
NAGA_UI.AetherPath = AP

AP.name    = "AetherPath"
AP.version = "1.0.0"
AP.author  = "Independent"
AP.hostAddon = "AbyssUI"

-- Defaults (clean, minimal)
AP.defaults = {
    language          = "auto",
    showTracker       = true,
    trackerLocked     = false,
    trackerScale      = 1.0,
    trackerAlpha      = 0.94,
    contrast          = 1.0,

    titleFont         = "ZoFontWinH4",
    stepFont          = "ZoFontGameSmall",
    titleColor        = {0.40, 0.60, 0.90, 1},
    stepColor         = {0.72, 0.48, 0.30, 1},

    maxVisibleQuests  = 8,
    showObjectives    = true,
    showTomes         = true,
    showDescription   = true,
    showZoneHeader    = true,
    confirmTravel     = true,
    groupByZone       = true,
    showUnavailable   = false,
    freeViaFriends    = true,
    freeViaGuild      = true,
    mapPinsEnabled    = true,
    favoriteNodes     = {},
    customNames       = {},
    position          = { point = TOPLEFT, relPoint = TOPLEFT, x = 40, y = 120 },
}

AP.sv          = nil
AP.atWayshrine = false
AP.currentNode = nil


-- Hook native focused-quest cycle so the default T key still switches quests
-- while our panel is the one showing the text.
function AP.HookNativeCycle()
    if AP._cycleHooked then return end
    local tracker = rawget(_G, "FOCUSED_QUEST_TRACKER")
    if tracker and type(tracker.AssistNext) == "function" then
        local original = tracker.AssistNext
        tracker.AssistNext = function(self, ...)
            local result = original(self, ...)
            if AP.Tracker then
                zo_callLater(function()
                    AP.Tracker:ResolveFocused()
                    if AP.UI then AP.UI:RebuildQuestList() end
                end, 50)
            end
            return result
        end
        AP._cycleHooked = true
    end
    -- Some clients expose AssistPrevious
    if tracker and type(tracker.AssistPrevious) == "function" then
        local original = tracker.AssistPrevious
        tracker.AssistPrevious = function(self, ...)
            local result = original(self, ...)
            if AP.Tracker then
                zo_callLater(function()
                    AP.Tracker:ResolveFocused()
                    if AP.UI then AP.UI:RebuildQuestList() end
                end, 50)
            end
            return result
        end
    end
end

function AP.RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_PLAYER_ACTIVATED, AP.OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_QUEST_ADDED,      AP.OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_QUEST_REMOVED,    AP.OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_QUEST_ADVANCED,   AP.OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_QUEST_COMPLETE,   AP.OnQuestChanged)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_START_FAST_TRAVEL_INTERACTION, AP.OnWayshrineEnter)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_END_FAST_TRAVEL_INTERACTION,   AP.OnWayshrineExit)
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_PLAYER_DEACTIVATED, function()
        if AP.UI and AP.UI.SavePosition then AP.UI:SavePosition() end
    end)
    -- When the game changes which quest is assisted (native T or other)
    if EVENT_QUEST_CONDITION_COUNTER_CHANGED then
        EVENT_MANAGER:RegisterForEvent(AP.name .. "_Cond", EVENT_QUEST_CONDITION_COUNTER_CHANGED, AP.OnQuestChanged)
    end
end

function AP.Initialize()
    AP.sv = ZO_SavedVars:NewAccountWide("AetherPath_SavedVars", 1, nil, AP.defaults)

    AP.LoadLanguage()
    if AP.ApplyContrast then AP.ApplyContrast(AP.sv.contrast or 1) end

    if AP.Core and AP.Core.Initialize then AP.Core:Initialize() end
    if AP.Tracker and AP.Tracker.Initialize then AP.Tracker:Initialize() end
    if AP.Travel and AP.Travel.Initialize then AP.Travel:Initialize() end
    if AP.MapPins and AP.MapPins.Initialize then AP.MapPins:Initialize() end
    if AP.Settings and AP.Settings.Initialize then AP.Settings:Initialize() end
    if AP.UI and AP.UI.Initialize then AP.UI:Initialize() end

    AP.RegisterEvents()
    AP.HookNativeCycle()
    if AP.UI and AP.UI.RefreshAll then AP.UI:RefreshAll() end
end

function AP.OnPlayerActivated()
    if AP.UI then
        if AP.UI.ApplyPosition then AP.UI:ApplyPosition() end
        if AP.UI.RefreshAll then AP.UI:RefreshAll() end
    end
end

function AP.OnQuestChanged()
    if AP.Tracker and AP.Tracker.Refresh then
        AP.Tracker:Refresh()
    end
end

function AP.OnWayshrineEnter(_, nodeIndex)
    AP.atWayshrine = true
    AP.currentNode = nodeIndex
end

function AP.OnWayshrineExit()
    AP.atWayshrine = false
    AP.currentNode = nil
end

SLASH_COMMANDS["/aether"] = function(args)
    local cmd = string.lower(args or "")
    if cmd == "next" or cmd == "cycle" then
        if AP.Tracker then AP.Tracker:CycleNext() end
    elseif cmd == "tomesdump" then
        if AP.Tomes then AP.Tomes:Dump() end
    elseif cmd == "lock" then
        AP.sv.trackerLocked = not AP.sv.trackerLocked
        if AP.UI then AP.UI:ApplyLock() end
        d("|c88AAFFAetherPath|r tracker " .. (AP.sv.trackerLocked and "locked" or "unlocked"))
    elseif cmd == "reset" then
        AP.sv.position = ZO_DeepTableCopy(AP.defaults.position)
        if AP.UI then AP.UI:ApplyPosition() end
        d("|c88AAFFAetherPath|r position reset")
    else
        if AP.UI then AP.UI:ToggleTracker() end
    end
end

-- Embedded mode: wait for AbyssUI bootstrap
if NAGA_UI and NAGA_UI.OnAddonLoaded then
    NAGA_UI.OnAddonLoaded(function()
        AP.Initialize()
    end)
else
    -- Standalone fallback
    EVENT_MANAGER:RegisterForEvent(AP.name, EVENT_ADD_ON_LOADED, function(_, addonName)
        if addonName ~= "AbyssUI" and addonName ~= AP.name then return end
        EVENT_MANAGER:UnregisterForEvent(AP.name, EVENT_ADD_ON_LOADED)
        AP.Initialize()
    end)
end
