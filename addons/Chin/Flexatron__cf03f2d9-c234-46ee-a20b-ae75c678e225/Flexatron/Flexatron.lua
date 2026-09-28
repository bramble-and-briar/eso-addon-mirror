-- Flexatron core: startup and saved settings.
Flexatron = Flexatron or {}
local FT = Flexatron

FT.name = "Flexatron"
FT.version = "0.8.2"

-- Account-wide settings and their defaults (see the spec's settings table).
FT.defaults = {
    rotate = true,        -- rotate through the titles in the list
    titles = {},          -- the rotation, stored by title name
    holdTime = 8,         -- seconds each title stays, 3-30
    autoMode = true,      -- wear the best title earned in the trial, dungeon or arena you're in
    celebrate = true,     -- wear a newly earned title right away, for a few minutes
    emoteId = 0,          -- the auto emote; 0 = none
    emoteEvery = 60,      -- seconds between emotes: with title changes while they rotate, on its own
                          -- otherwise; 0 = every title change, -1 = only new titles
    titleEnvy = true,     -- say when someone you aim at wears a title you don't have
    quickPick = "",       -- the quick pick pressed last: it keeps the check when two picks match
}

local announced = false

-- Fires after every loading screen; only the first one counts. The settings panel waits for it,
-- because its title list needs the character's titles.
local function OnPlayerActivated()
    if announced then return end
    announced = true
    FT.Settings.Init()
    FT.TitleIndex.Warm()
    CHAT_ROUTER:AddSystemMessage(FT.L.LOADED)
end

-- 0.3.0's dropdowns saved the whole picked entry ({ name, data }) instead of its data.
local function Unwrap(value)
    if type(value) == "table" then
        return value.data
    end
    return value
end

-- Settings from 0.3.x: one rotation list instead of a world and a PvP list, and the emote folded
-- into one choice. Anything else from 0.3.x and 0.4.x (like the animations) goes.
local OLD_KEYS = { "enabled", "swapAnimation", "rotateInCombat", "worldRotation", "worldTitles", "pvpRotation",
    "pvpTitles", "banner", "animationStyle", "bannerPosition", "animateTargetBar", "flexEmote", "flexEmoteId",
    "flexEmoteCooldown", "celebrateMinutes", "speedTest", "animations" }

local function Migrate(sv)
    if sv.worldTitles ~= nil or sv.pvpTitles ~= nil then
        local names, seen = {}, {}
        for _, key in ipairs({ "worldTitles", "pvpTitles" }) do
            for _, name in ipairs(type(sv[key]) == "table" and sv[key] or {}) do
                name = Unwrap(name)
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
        sv.titles = names
        sv.rotate = sv.worldRotation ~= false
        local emoteId = Unwrap(sv.flexEmoteId)
        sv.emoteId = sv.flexEmote and type(emoteId) == "number" and emoteId or 0
    end
    for _, key in ipairs(OLD_KEYS) do
        sv[key] = nil
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= FT.name then return end
    EVENT_MANAGER:UnregisterForEvent(FT.name, EVENT_ADD_ON_LOADED)

    -- The 1 is the saved settings' version: the game erases settings saved under a lower one, so
    -- raising it would reset every player's settings. New settings don't need it: the game adds
    -- any missing one with its default and leaves the rest as they were.
    FT.sv = ZO_SavedVars:NewAccountWide("Flexatron_SavedVariables", 1, nil, FT.defaults)
    Migrate(FT.sv)

    FT.Swap.Init()
    FT.Emote.Init()
    FT.Rotation.Init()
    FT.Celebrate.Init()
    FT.Envy.Init()

    EVENT_MANAGER:RegisterForEvent(FT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(FT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
