PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- Players by PSN-ID (or the platform's account name) instead of the character name
--
-- Combat events name their targets by character name only, and so do the records. A character name
-- can be turned into the account only while a unit tag points at that player: the player, the group
-- members (group1..N) and whoever is under the reticle. So the add-on notes "character -> account"
-- whenever such a tag is there (start of a fight, group changes, a reticle change in a fight, a
-- member's reading arriving) and a record keeps the pairs for the names it holds; the screen and the
-- HUD pick one or the other by the setting at draw time, so switching works on old fights too.
-- A player never seen through a tag (an ally outside the group healed by an area heal, an enemy
-- player never targeted) stays a character name.
--
-- The account: GetUnitPlatformDisplayName (the PSN-ID / Gamertag with crossplay), else the
-- account name without its "@" (what the client shows on console, ZO_FormatUserFacingDisplayName).
---------------------------------------------------------------------------------------------------

local names = { ids = {}, count = 0, noted = 0 }
ADDON.names = names

-- The session's notes are emptied when they grow past this (a fresh fight notes its group again).
local MAX_NOTES = 120

local Plain = ADDON.Plain

local function Undecorated(account)
    if type(UndecorateDisplayName) == "function" then
        local ok, plain = pcall(UndecorateDisplayName, account)
        if ok and type(plain) == "string" and plain ~= "" then
            return plain
        end
    end
    -- byte-wise: only a leading ASCII "@" is taken off
    if account:sub(1, 1) == "@" then
        return account:sub(2)
    end
    return account
end

-- The account shown for a unit tag; "" when there is none.
function names.IdOf(tag)
    local id = type(GetUnitPlatformDisplayName) == "function" and GetUnitPlatformDisplayName(tag) or ""
    if type(id) == "string" and id ~= "" then
        return id
    end
    local account = type(GetUnitDisplayName) == "function" and GetUnitDisplayName(tag) or ""
    if type(account) ~= "string" or account == "" then
        return ""
    end
    return Undecorated(account)
end

-- Notes the player behind a unit tag. Players only: a monster has no account.
function names:Note(tag)
    if type(GetUnitName) ~= "function" then
        return
    end
    if tag ~= "player" and type(IsUnitPlayer) == "function" and not IsUnitPlayer(tag) then
        return
    end
    local name = Plain(GetUnitName(tag) or "")
    if name == "" or self.ids[name] then
        return
    end
    local id = names.IdOf(tag)
    if id == "" then
        return
    end
    if self.count >= MAX_NOTES then
        self.ids, self.count = {}, 0
    end
    self.ids[name] = id
    self.count = self.count + 1
    self.noted = self.noted + 1
end

-- The player and every group member.
function names:NoteGroup()
    self:Note("player")
    local size = type(GetGroupSize) == "function" and GetGroupSize() or 0
    for index = 1, size do
        local tag = GetGroupUnitTagByIndex(index)
        if tag then
            self:Note(tag)
        end
    end
end

-- The pairs a record needs: the names in its target lists and its group rows.
function names.FoldInto(record)
    local ids, any = {}, false
    local function Add(list)
        for _, row in ipairs(list or {}) do
            local id = names.ids[row.name]
            if id then
                ids[row.name] = id
                any = true
            end
        end
    end
    Add(record.dmgTgt)
    Add(record.healTgt)
    Add(record.group)
    record.ids = any and ids or nil
end

-- The name to show: the account when the setting asks for it and it is known, else the character.
-- ids: the record's pairs (nil = the session's notes, for what is live on the HUD).
function names.Shown(name, ids)
    local sv = ADDON.sv
    if not sv or not sv.showIds or not name then
        return name
    end
    local id = (ids or names.ids)[name]
    return id or name
end
