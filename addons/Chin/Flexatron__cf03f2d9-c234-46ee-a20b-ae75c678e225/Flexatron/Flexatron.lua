-- Flexatron core: startup and saved settings.
Flexatron = Flexatron or {}
local FT = Flexatron

FT.name = "Flexatron"
FT.version = "0.8.6"

-- Each character's settings and their defaults (see the spec's settings table). A new character
-- gets these; one that had the settings shared by every character (up to 0.8.4) keeps those (see
-- OnAddOnLoaded).
FT.defaults = {
    active = false,       -- Flexatron on or off: off on a new character, as it was after an update
    rotate = true,        -- rotate through the titles in the list
    titles = {},          -- the rotation, stored by title name
    holdTime = 8,         -- seconds each title stays, 3-30
    autoMode = true,      -- wear the best title earned in the trial, dungeon or arena you're in
    celebrate = true,     -- wear a newly earned title right away, for a few minutes
    emoteOn = false,      -- the auto emote on or off: off on a new character; after an update, on
                          -- if an emote was picked
    emoteId = 0,          -- the auto emote; 0 = not picked yet (the first flex owned is used)
    emoteEvery = 60,      -- seconds between emotes: with title changes while they rotate, on its own
                          -- otherwise; 0 = every title change, -1 = only new titles
    titleEnvy = true,     -- say when someone you aim at wears a title you don't have
    quickPick = "",       -- the quick pick pressed last: it keeps the check when two picks match
}

local announced = false

-- Fires after every loading screen; only the first one counts. The settings panel waits for it,
-- because its title list needs the character's titles. At every login, chat says whether it's on;
-- while it's off on this character, also where to turn it on.
local function OnPlayerActivated()
    if announced then return end
    announced = true
    FT.Settings.Init()
    FT.TitleIndex.Warm()
    if FT.sv.active then
        CHAT_ROUTER:AddSystemMessage(FT.L.LOADED)
    else
        CHAT_ROUTER:AddSystemMessage(FT.L.TURN_ON)
    end
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

-- The saved settings' version: the game erases settings saved under a lower one, so raising it
-- would reset every player's settings. New settings don't need it: the game adds any missing one
-- with its default and leaves the rest as they were.
local SAVED_VERSION = 1

-- Where 0.8.2 to 0.8.4 kept one set of settings for every character on the account.
local SHARED = "$AccountWide"

-- This account's saved settings, read before the game adds any defaults: the game keeps them
-- under the profile ("Default") and the account name, then "$AccountWide" or a character's id.
local function SavedAccount()
    local saved = Flexatron_SavedVariables
    local profile = type(saved) == "table" and saved.Default
    local account = type(profile) == "table" and profile[GetDisplayName()]
    return type(account) == "table" and account or nil
end

-- These settings if the game would keep them (saved under the current version) and there's at
-- least one setting in them; otherwise nil.
local function Kept(settings)
    if type(settings) ~= "table" or type(settings.version) ~= "number" or settings.version < SAVED_VERSION then
        return nil
    end
    for key in pairs(settings) do
        if key ~= "version" and key ~= "$LastCharacterName" then
            return settings
        end
    end
    return nil
end

-- The account's characters by id, or false if the game can't list them.
local function Characters()
    local ids, count = {}, GetNumCharacters() or 0
    for i = 1, count do
        local id = select(7, GetCharacterInfo(i))
        if id then
            ids[tostring(id)] = true
        end
    end
    return count > 0 and ids
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = Copy(inner)
    end
    return copy
end

-- Settings are per character. A character without its own takes the settings shared by every
-- character up to 0.8.4 if it existed when they were first split (the list of characters is taken
-- then, so a character made later starts with the defaults: off). Returns the settings it took,
-- placed where the game reads this character's settings, or nil.
local function TakeShared(account, characterId)
    local shared = account and Kept(account[SHARED])
    if not shared or Kept(account[characterId]) then
        return nil
    end
    if shared.characters == nil then
        shared.characters = Characters()
    end
    if shared.characters and not shared.characters[characterId] then
        return nil
    end
    local settings = Copy(shared)
    settings.characters = nil
    account[characterId] = settings
    return settings
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= FT.name then return end
    EVENT_MANAGER:UnregisterForEvent(FT.name, EVENT_ADD_ON_LOADED)

    local taken = TakeShared(SavedAccount(), GetCurrentCharacterId())
    -- Settings from a version without the on/off switches (0.8.2 and earlier) were on (0.4 to 0.8.2
    -- always); 0.3.x had a switch of its own, "enabled", which Migrate removes. Read both before the
    -- game adds the defaults.
    local updating = taken ~= nil and taken.active == nil
    local wasOff = taken ~= nil and taken.enabled == false
    FT.sv = ZO_SavedVars:NewCharacterIdSettings("Flexatron_SavedVariables", SAVED_VERSION, nil, FT.defaults)
    Migrate(FT.sv)
    if updating then
        -- An update stays on, and so does its emote if one was picked.
        FT.sv.active = not wasOff
        FT.sv.emoteOn = FT.sv.emoteId ~= 0
    end

    FT.Swap.Init()
    FT.Emote.Init()
    FT.Rotation.Init()
    FT.Celebrate.Init()
    FT.Envy.Init()

    EVENT_MANAGER:RegisterForEvent(FT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(FT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
