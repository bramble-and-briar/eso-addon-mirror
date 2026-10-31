-- PrismaticEmotes 1.0.2
-- A local, lightweight chat formatter for roleplay emotes.

---@alias PrismaticEmotesColorMode "author"|"body"|"both"

---@class PrismaticEmotesCharacter
---@field name? string
---@field color string
---@field automatic? string

---@class PrismaticEmotesSavedVariables
---@field enabled boolean
---@field mode PrismaticEmotesColorMode
---@field highlightMentions boolean
---@field characters table<string, PrismaticEmotesCharacter>

PrismaticEmotes = {
    name = "PrismaticEmotes",
    version = "1.0.2",
    ---@type PrismaticEmotesSavedVariables|nil
    saved = nil,
}

local PE = PrismaticEmotes

---@type PrismaticEmotesSavedVariables
PE.defaults = {
    enabled = true,
    mode = "both",            -- "author", "body", or "both"
    highlightMentions = true, -- known character names in the body
    characters = {},          -- account-wide character -> color registry for this server
}

function PE.Print(message)
    if type(d) == "function" then
        d("|cBCA2FF[PrismaticEmotes]|r " .. tostring(message))
    end
end

local function accountWideData(storage, profile, displayName)
    local profiles = type(storage) == "table" and rawget(storage, profile)
    local account = type(profiles) == "table" and rawget(profiles, displayName)
    local settings = type(account) == "table" and rawget(account, "$AccountWide")
    return type(settings) == "table" and settings or nil
end

local function copySavedTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and copySavedTable(value) or value
    end
    return copy
end

local function loadSavedVariables()
    local world = GetWorldName()
    local displayName = GetDisplayName()
    local storage = rawget(_G, "PrismaticEmotesSavedVariables")
    local existing = accountWideData(storage, world, displayName)
    local legacy = accountWideData(storage, "Default", displayName)
    local saved = ZO_SavedVars:NewAccountWide("PrismaticEmotesSavedVariables", 1, nil, PE.defaults, world)

    -- Shared data has no server provenance. Claim it only for the first world
    -- visited after upgrading, keeping any existing world profile and the backup.
    if legacy and legacy.version == 1 and legacy._migratedToServer == nil then
        if not existing then
            if type(legacy.enabled) == "boolean" then saved.enabled = legacy.enabled end
            if type(legacy.highlightMentions) == "boolean" then
                saved.highlightMentions = legacy.highlightMentions
            end
            if legacy.mode == "author" or legacy.mode == "body" or legacy.mode == "both" then
                saved.mode = legacy.mode
            end
            if type(legacy.characters) == "table" then
                saved.characters = copySavedTable(legacy.characters)
            end
        end
        legacy._migratedToServer = world
    end
    return saved
end

local function OnPlayerActivated()
    -- pChat registers its own channel formatter on PLAYER_ACTIVATED.
    -- Deferring our wrapper ensures we capture whichever formatter won.
    EVENT_MANAGER:UnregisterForEvent(PE.name .. "Activated", EVENT_PLAYER_ACTIVATED)
        zo_callLater(function()
            if not PE.Chat.Install() then
                PE.Print("Chat formatter unavailable. Try /pe rehook after login.")
            end
        end, 1000)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= PE.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(PE.name, EVENT_ADD_ON_LOADED)
    PE.saved = loadSavedVariables()

    -- Defensive migration if an older/incomplete SavedVariables table exists.
    if type(PE.saved.characters) ~= "table" then
        PE.saved.characters = {}
    end
    if PE.saved.mode ~= "author" and PE.saved.mode ~= "body" and PE.saved.mode ~= "both" then
        PE.saved.mode = "both"
    end

    PE.Palette.MigrateSavedNames()
    PE.Commands.Register()
    EVENT_MANAGER:RegisterForEvent(PE.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

if EVENT_MANAGER then
    EVENT_MANAGER:RegisterForEvent(PE.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end
