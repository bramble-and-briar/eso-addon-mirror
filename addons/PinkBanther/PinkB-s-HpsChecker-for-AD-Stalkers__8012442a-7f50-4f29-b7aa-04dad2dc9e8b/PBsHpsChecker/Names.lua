PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- Names: the PSN ID behind a character name
--
-- A heal event names its target by CHARACTER NAME ("Alice^F") and by nothing else, so the name the
-- game shows next to a player (the PSN ID on a PS5 -- the nameplate and the kill feed use it) has to
-- come from somewhere else. Three places give both a character name and that name:
--
--   * the members of the player's group: for a unit tag, GetUnitPlatformDisplayName(tag) -- the PSN
--     online ID, an empty string for somebody who has none -- and, when that is empty,
--     GetUnitDisplayName(tag), which is what the client's own UI falls back to
--     (ZO_TryGetPlatformDisplayNameForUnitTag);
--   * whoever the reticle is on ("reticleover"), the same way;
--   * the kill feed: EVENT_PVP_KILL_FEED_DEATH carries the killer's and the victim's display name
--     and character name, and the client's own kill feed prints that display name as it comes
--     (chathandlers.lua passes ZO_GetPrimaryPlayerName no platform name), which is why the feed
--     shows PSN IDs. Every kill the player can see in Cyrodiil names two players.
--
-- The add-on learns character name -> that name from these, keeps the table in the saved variables
-- (sv.psn), and the rankings show it wherever one is known and the character name everywhere else:
-- a player who has never been in the group, under the reticle or in a kill feed line stays a character
-- name. A leading @ is dropped, as the console UI does not show one. Nothing here is on the heal path:
-- it runs on a group, reticle or kill feed event, at a loading screen, and about every GROUP_SCAN_MS
-- while a fight is on (a group changes without always saying so).
--
-- One player can have several characters under one PSN ID. The tallies are per character name, so each
-- character is its own row, and once two character names are known under one PSN ID the rows read
-- "PSN ID(character name)" so that they can be told apart.
--
-- The tallies stay keyed by character name; the PSN ID is only what is shown. A name learned late
-- therefore turns the whole past of that player into their PSN ID at once, and never splits an entry
-- in two. The price is that two players with the same character name are one entry.
---------------------------------------------------------------------------------------------------

local psn = { learned = { group = 0, reticle = 0, killfeed = 0 }, empty = 0 }
ADDON.psn = psn

local GROUP_SCAN_MS = 20000
-- Names kept. A kill feed names hundreds of players in an evening; the table is cut back to the names the
-- records still have at every start-up, and in a session it stops taking new names at this many.
local MAX_KNOWN = 2000
psn.MAX_KNOWN = MAX_KNOWN

local map = {}
local size = 0
-- How many character names each shown name has: a player with two characters has two names under one
-- PSN ID, and the ranking cannot then tell the characters apart by the PSN ID alone.
local characters = {}
local lastScanMs

-- "Name^Mx" (the raw form, with its gender mark) and "Name" are the same player.
local function Plain(name)
    return (tostring(name or ""):gsub("%^.*$", ""))
end

local FULLWIDTH_AT = "＠"

-- Trimmed, and without the @ of an account name.
local function Clean(id)
    id = tostring(id or ""):match("^%s*(.-)%s*$")
    if id:sub(1, #FULLWIDTH_AT) == FULLWIDTH_AT then
        id = id:sub(#FULLWIDTH_AT + 1)
    elseif id:sub(1, 1) == "@" then
        id = id:sub(2)
    end
    return id
end

-- The saved table, or an empty one before start-up. Pruned at start-up to the names the records still
-- have, so that it cannot grow for ever.
function psn:Initialize(savedVars)
    if type(savedVars.psn) ~= "table" then
        savedVars.psn = {}
    end
    map = savedVars.psn
    characters = {}
    for key, id in pairs(map) do
        if type(key) ~= "string" or type(id) ~= "string" or id == "" then
            map[key] = nil
        end
    end
    local used = ADDON.records:TargetNames()
    for key in pairs(map) do
        if not used[key] then
            map[key] = nil
        end
    end
    size = 0
    for _, id in pairs(map) do
        size = size + 1
        characters[id] = (characters[id] or 0) + 1
    end

    -- What the rankings call a player, and what happens to the table when the records are cleared.
    ADDON.records.DisplayName = function(name)
        return psn:Display(name)
    end
    ADDON.records.onClear = function()
        for key in pairs(map) do
            map[key] = nil
        end
        size = 0
        for id in pairs(characters) do
            characters[id] = nil
        end
    end
end

-- Remembers that this character name is shown as this id. Returns true if it is news. A player with
-- no name to show (an empty answer) is not remembered: their character name stays what is shown.
function psn:Learn(characterName, id, source)
    local key = Plain(characterName)
    id = Clean(id)
    if key == "" or id == "" then
        self.empty = self.empty + 1
        return false
    end
    local known = map[key]
    if known == id then
        return false
    end
    if known == nil then
        if size >= MAX_KNOWN then
            return false
        end
        size = size + 1
    else
        -- the name is shown under another id now: it is no longer one of the old id's characters
        characters[known] = characters[known] - 1
        if characters[known] <= 0 then
            characters[known] = nil
        end
    end
    characters[id] = (characters[id] or 0) + 1
    map[key] = id
    self.learned[source] = (self.learned[source] or 0) + 1
    return true
end

-- The name the game shows for a unit: the platform name (the PSN online ID), else the display name.
local function UnitId(unitTag)
    local platform = GetUnitPlatformDisplayName and GetUnitPlatformDisplayName(unitTag) or ""
    if platform ~= "" then
        return platform
    end
    return GetUnitDisplayName and GetUnitDisplayName(unitTag) or ""
end

function psn:LearnUnit(unitTag, source)
    if not unitTag or unitTag == "" or not DoesUnitExist(unitTag) or not IsUnitPlayer(unitTag) then
        return false
    end
    return self:Learn(GetUnitName(unitTag), UnitId(unitTag), source)
end

function psn:LearnGroup(nowMs)
    lastScanMs = nowMs or GetFrameTimeMilliseconds()
    for index = 1, GetGroupSize() do
        self:LearnUnit(GetGroupUnitTagByIndex(index), "group")
    end
end

function psn:LearnReticle()
    self:LearnUnit("reticleover", "reticle")
end

-- A kill feed line: two players, each with the display name the feed shows and a character name.
function psn:LearnKillFeed(killerDisplayName, killerCharacterName, victimDisplayName, victimCharacterName)
    self:Learn(killerCharacterName, killerDisplayName, "killfeed")
    self:Learn(victimCharacterName, victimDisplayName, "killfeed")
end

-- About once a second. A group changes without always saying so, so while the player is healing the
-- group is looked at again now and then.
function psn:Tick(nowMs)
    if ADDON.records.fight and (not lastScanMs or nowMs - lastScanMs >= GROUP_SCAN_MS) then
        self:LearnGroup(nowMs)
    end
end

function psn:Lookup(characterName)
    return map[Plain(characterName)]
end

-- What a ranking shows for a player: the PSN ID if it is known (and showing it is on), else the
-- character name as it was. When more than one character name is known under that PSN ID, the
-- character is named as well, "PSN ID(character name)", so that the player's characters can be told
-- apart; with one, the PSN ID alone.
function psn:Display(characterName)
    local sv = ADDON.sv
    if sv and sv.showPsn == false then
        return characterName
    end
    local key = Plain(characterName)
    local id = map[key]
    if not id then
        return characterName
    end
    if (characters[id] or 0) > 1 then
        return string.format("%s(%s)", id, key)
    end
    return id
end

function psn:Count()
    return size
end
