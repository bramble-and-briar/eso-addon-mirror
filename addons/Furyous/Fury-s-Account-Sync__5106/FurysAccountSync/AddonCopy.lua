-- Fury's Account Sync - addon settings and the base game's window layout
-- An addon's saved data is one file per PC with a section for every account, and the game loads the
-- whole file. So while you're logged in on one account, the main account's settings for every
-- running addon are already in memory. Copying them is a table copy. A UI reload afterwards makes
-- each addon read its new settings and writes them to disk.

local AS = FurysAccountSync

local WIDE = "$AccountWide"
local UNDO_DAYS = 30

-- The parts of the base game's per-character saved data that hold where its windows sit.
local LAYOUT_PARTS = {
    { key = "Chat",                  name = "chat window" },
    { key = "PerformanceMeters",     name = "frame rate and ping meter" },
    { key = "ZO_HUDTracker_Manager", name = "quest tracker" },
    -- Where the HUD windows sit after you move them in the game's own HUD editor. The game keeps
    -- this once per account, not per character.
    { key = "ZO_HUDManager",         name = "HUD positions", wide = true },
}

local function Copy(value, depth)
    if type(value) ~= "table" then return value end
    depth = depth or 0
    local out = {}
    if depth > 60 then return out end
    for k, v in pairs(value) do out[k] = Copy(v, depth + 1) end
    return out
end

local function Same(a, b, depth)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    depth = depth or 0
    if depth > 60 then return true end
    for k, v in pairs(a) do
        if not Same(v, b[k], depth + 1) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

-- How many top-level parts of the main's settings differ from this account's, leaving out the
-- parts that are kept.
local function DiffParts(mainWide, myWide, keep)
    local n = 0
    for k, v in pairs(mainWide) do
        if not keep[k] and (myWide == nil or not Same(v, myWide[k])) then n = n + 1 end
    end
    if myWide then
        for k in pairs(myWide) do
            if not keep[k] and mainWide[k] == nil then n = n + 1 end
        end
    end
    return n
end

local function WideOf(profile, account)
    local node = profile[account]
    if type(node) ~= "table" then return nil end
    local wide = node[WIDE]
    if type(wide) ~= "table" then return nil end
    return wide
end

------------------------------------------------------------------------------
-- HarvestMap
------------------------------------------------------------------------------
-- HarvestMap doesn't use the usual layout. Its settings sit in Harvest_SavedVars.account under the
-- account name without the "@", and it only uses them when its own "account-wide settings" option
-- is on. Otherwise every character has its own, and there is nothing to copy for the account.
local function IsHarvest(name)
    local rule = AS.RULES[name]
    return type(rule) == "table" and rule.layout == "harvest"
end

local function BareName(account)
    if account:sub(1, 1) == "@" then return account:sub(2) end
    return account
end

-- The table that holds one settings table per account, the main's settings (only when the main
-- uses account-wide settings) and this account's.
local function HarvestNodes(name, main, me)
    local root = _G[name]
    local accounts = type(root) == "table" and root.account
    if type(accounts) ~= "table" then return nil end
    local mainNode = accounts[BareName(main)]
    if type(mainNode) ~= "table" or mainNode.accountWideSettings ~= true then mainNode = nil end
    local myNode = accounts[BareName(me)]
    if type(myNode) ~= "table" then myNode = nil end
    return accounts, mainNode, myNode
end

------------------------------------------------------------------------------
-- Addon settings
------------------------------------------------------------------------------
-- Every listed addon that is running here and whose settings differ from the main's:
-- { name = saved variable, profile = profile key, parts = how many parts differ, added = no settings here yet }
function AS.AddonPlan()
    local list = {}
    local main, me = AS.SV().main, GetDisplayName()
    if not main or main == me then return list end
    for _, name in ipairs(AS.CopiedNames()) do
        local copied, keep = AS.CopyRule(name)
        copied = copied and AS.IsPicked(name)
        local root = copied and _G[name]
        if copied and IsHarvest(name) then
            local _, mainNode, myNode = HarvestNodes(name, main, me)
            if mainNode then
                local parts = DiffParts(mainNode, myNode, keep)
                if parts > 0 then
                    list[#list + 1] = { name = name, profile = "account", parts = parts, added = (myNode == nil) }
                end
            end
        elseif type(root) == "table" then
            for profileKey, profile in pairs(root) do
                if type(profile) == "table" then
                    local mainWide = WideOf(profile, main)
                    if mainWide then
                        local myWide = WideOf(profile, me)
                        local parts = DiffParts(mainWide, myWide, keep)
                        if parts > 0 then
                            list[#list + 1] = { name = name, profile = profileKey, parts = parts, added = (myWide == nil) }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return tostring(a.profile) < tostring(b.profile)
    end)
    return list
end

-- The record of what copying replaced on this account: for each addon, the settings the account
-- had before the FIRST copy. Later copies don't overwrite that, so undo goes back to the account's
-- own settings and not just to the previous copy. Filled by the two copy functions below and stored
-- with AS.KeepUndo.
function AS.UndoRecord()
    local undo = AS.SV().undo[GetDisplayName()]
    if type(undo) ~= "table" then
        undo = { time = GetTimeStamp(), from = AS.SV().main, items = {}, layouts = {} }
    end
    if not undo.items then undo.items = {} end
    if not undo.layouts then undo.layouts = {} end
    return undo
end

function AS.KeepUndo(undo)
    if #undo.items > 0 or next(undo.layouts) ~= nil then AS.SV().undo[GetDisplayName()] = undo end
end

-- Copies the main's settings for everything in the list. What this account had goes into the undo
-- record. Returns how many were copied.
function AS.CopyAddons(list, undo)
    local sv = AS.SV()
    local main, me = sv.main, GetDisplayName()
    local copied = 0
    local have = {}
    for _, item in ipairs(undo.items) do have[item.name .. "/" .. tostring(item.profile)] = true end
    for _, e in ipairs(list) do
        local root = _G[e.name]
        local profile = type(root) == "table" and root[e.profile]
        local mainWide = not IsHarvest(e.name) and type(profile) == "table" and WideOf(profile, main)
        if IsHarvest(e.name) then
            local accounts, mainNode, myNode = HarvestNodes(e.name, main, me)
            if mainNode then
                -- a new table, for the same reason as below
                accounts[BareName(me)] = Copy(mainNode)
                if not have[e.name .. "/" .. tostring(e.profile)] then
                    undo.items[#undo.items + 1] = { name = e.name, profile = e.profile, old = myNode or false, harvest = true }
                end
                copied = copied + 1
            end
        elseif mainWide then
            local _, keep = AS.CopyRule(e.name)
            local mine = profile[me]
            local madeNode = false
            if type(mine) ~= "table" then
                mine = {}
                profile[me] = mine
                madeNode = true
            end
            local old = mine[WIDE]
            local hadOld = type(old) == "table"
            -- the main's settings, minus the parts every account keeps for itself
            local new = {}
            for k, v in pairs(mainWide) do
                if not keep[k] then new[k] = Copy(v) end
            end
            local stash = false
            if hadOld then
                stash = {}
                for k, v in pairs(old) do
                    if keep[k] then new[k] = v else stash[k] = v end
                end
            end
            -- A new table, not a change to the old one: the running addon keeps writing to the old
            -- one until the reload, and that must not land on top of the copy.
            mine[WIDE] = new
            if not have[e.name .. "/" .. tostring(e.profile)] then
                undo.items[#undo.items + 1] = { name = e.name, profile = e.profile, old = stash, madeNode = madeNode or nil }
            end
            copied = copied + 1
        end
    end
    return copied
end

------------------------------------------------------------------------------
-- Base game window layout (kept per character in the game's own saved data)
------------------------------------------------------------------------------
local function CharacterNode(account, character)
    local root = ZO_Ingame_SavedVariables
    if type(root) ~= "table" then return nil end
    local profile = root["Default"]
    if type(profile) ~= "table" then return nil end
    local acct = profile[account]
    if type(acct) ~= "table" then return nil end
    local node = acct[character]
    if type(node) ~= "table" then return nil end
    return node
end

-- Where a layout part sits: the character's own node, or the account-wide node for a "wide" part.
-- Returns the main's node, this account's node and the undo key ("$AccountWide" or the character).
local function LayoutNodes(part)
    local sv = AS.SV()
    local snap = sv.snapshot
    if not snap or not snap.char or not sv.main or sv.main == GetDisplayName() then return nil end
    if part.wide then
        return CharacterNode(sv.main, WIDE), CharacterNode(GetDisplayName(), WIDE), WIDE
    end
    local character = GetUnitName("player")
    return CharacterNode(sv.main, snap.char), CharacterNode(GetDisplayName(), character), character
end

-- The layout parts of the main that differ here: { key, name }.
function AS.LayoutPlan()
    local list = {}
    for _, part in ipairs(LAYOUT_PARTS) do
        local from, to = LayoutNodes(part)
        if from and to and type(from[part.key]) == "table" and not Same(from[part.key], to[part.key]) then
            list[#list + 1] = part
        end
    end
    return list
end

-- Returns how many parts were copied. The old ones go into the undo record.
function AS.CopyLayout(list, undo)
    local n = 0
    for _, part in ipairs(list) do
        local from, to, undoKey = LayoutNodes(part)
        if from and to and type(from[part.key]) == "table" then
            local old = undo.layouts[undoKey]
            if not old then
                old = {}
                undo.layouts[undoKey] = old
            end
            if old[part.key] == nil then old[part.key] = to[part.key] or false end
            to[part.key] = Copy(from[part.key])
            n = n + 1
        end
    end
    return n
end

------------------------------------------------------------------------------
-- Undo
------------------------------------------------------------------------------
function AS.UndoInfo()
    return AS.SV().undo[GetDisplayName()]
end

-- Puts one addon's settings back from its undo item. Returns true when it was put back.
local function RestoreItem(item, me)
    local root = _G[item.name]
    if item.harvest then
        local accounts = type(root) == "table" and root.account
        if type(accounts) ~= "table" then return false end
        if type(item.old) == "table" then accounts[BareName(me)] = item.old else accounts[BareName(me)] = nil end
        return true
    end
    local profile = type(root) == "table" and root[item.profile]
    local mine = type(profile) == "table" and profile[me]
    if type(mine) ~= "table" then return false end
    local _, keep = AS.CopyRule(item.name)
    local current = mine[WIDE]
    local restored = nil
    if type(item.old) == "table" then restored = item.old end
    -- the kept parts (stats, logs) never left, so they stay as they are now
    if type(current) == "table" then
        for k in pairs(keep) do
            if current[k] ~= nil then
                if not restored then restored = {} end
                restored[k] = current[k]
            end
        end
    end
    mine[WIDE] = restored
    if item.madeNode and next(mine) == nil then profile[me] = nil end
    return true
end

-- The names of the addons this account can undo, sorted.
function AS.UndoNames()
    local undo = AS.SV().undo[GetDisplayName()]
    local seen, names = {}, {}
    for _, item in ipairs(undo and undo.items or {}) do
        if not seen[item.name] then
            seen[item.name] = true
            names[#names + 1] = item.name
        end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

-- The undo name that matches what was typed, whatever its capitals.
function AS.FindUndoName(typed)
    typed = zo_strlower(zo_strtrim(typed or ""))
    for _, name in ipairs(AS.UndoNames()) do
        if zo_strlower(name) == typed then return name end
    end
    return nil
end

-- Puts back one addon's settings and unticks it, so the next Apply leaves it alone. The rest of
-- the undo record stays. Returns how many of its profiles were put back. The caller reloads the UI.
function AS.UndoOneAddon(name)
    local sv = AS.SV()
    local me = GetDisplayName()
    local undo = sv.undo[me]
    if not undo then return 0 end
    local n, rest = 0, {}
    for _, item in ipairs(undo.items or {}) do
        if item.name == name then
            if RestoreItem(item, me) then n = n + 1 end
        else
            rest[#rest + 1] = item
        end
    end
    undo.items = rest
    if #rest == 0 and next(undo.layouts or {}) == nil then sv.undo[me] = nil end
    AS.SetPicked(name, false)
    return n
end

-- Puts back the addon settings and window layout this account had before copying replaced them.
-- Returns how many things were put back. The caller reloads the UI.
function AS.UndoAddons()
    local sv = AS.SV()
    local me = GetDisplayName()
    local undo = sv.undo[me]
    if not undo then return 0 end
    local n = 0
    for _, item in ipairs(undo.items or {}) do
        if RestoreItem(item, me) then n = n + 1 end
    end
    for character, parts in pairs(undo.layouts or {}) do
        local to = CharacterNode(me, character)
        if to then
            for key, old in pairs(parts) do
                if old == false then to[key] = nil else to[key] = old end
                n = n + 1
            end
        end
    end
    sv.undo[me] = nil
    return n
end

-- Undo data is kept for a month from an account's first copy, so the saved file doesn't grow for good.
function AS.PruneUndo()
    local sv = AS.SV()
    local cutoff = GetTimeStamp() - UNDO_DAYS * 86400
    for account, undo in pairs(sv.undo) do
        if type(undo) ~= "table" or (undo.time or 0) < cutoff then sv.undo[account] = nil end
    end
end
