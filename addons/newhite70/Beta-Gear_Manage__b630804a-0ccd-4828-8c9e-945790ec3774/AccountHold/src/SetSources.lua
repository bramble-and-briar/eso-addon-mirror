-- AccountHold/src/SetSources.lua
-- Accessor + shared activity rollup over data/setSources.lua (contract B).
--
-- This module is the ONLY thing that reads the bundled set-source database, and
-- RollupActivities is the ONLY de-duplication implementation in the add-on.
-- Epic 0002 (Armory build creator) and epic 0005 (Priorities) both call it, so
-- the two can never drift into two different answers to "what should I go do?".
--
-- Pure and side-effect free by contract: no SavedVariables, no events, no UI,
-- no Initialize. It reads one global table and returns new tables. That is what
-- makes it safe to call from a gamepad list refresh.
--
-- It also deliberately calls NO ZOS API except through AccountHold.L, so there
-- is nothing here to guard with type(x) == "function" and nothing that can be
-- missing on console.

AccountHold = AccountHold or {}
AccountHold.SetSources = AccountHold.SetSources or {}

local SetSources = AccountHold.SetSources

-- Synthetic activity for sets we have no data for. Frozen by contract B and
-- already relied on by src/Travel.lua (it refuses to look up a wayshrine for
-- activityKey == "unknown"), so it is exported rather than retyped by callers.
local UNKNOWN_KEY  = "unknown"
local TYPE_OTHER   = "other"
SetSources.UNKNOWN_KEY = UNKNOWN_KEY

-- The frozen activityType enum (contract A). Held as a lookup so the rollup can
-- guarantee callers only ever see one of these values: a UI that switches on
-- activityType for an icon should not have to defend against a typo in a
-- hand-maintained data file.
local ACTIVITY_TYPES = {
    dungeon  = true,
    trial    = true,
    arena    = true,
    overland = true,
    crafted  = true,
    pvp      = true,
    other    = true,
}
SetSources.ACTIVITY_TYPES = ACTIVITY_TYPES

-- Strings are registered centrally by the coordinator; feature agents must not
-- edit localization/en.lua (concurrent edits to one shared file collide). This
-- resolves through AccountHold.L when it exists and renders the English literal
-- otherwise, so the module is correct either way.
local function L(id, fallback)
    if AccountHold and type(AccountHold.L) == "function" then
        return AccountHold.L(id, fallback)
    end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Reading the database
-- ---------------------------------------------------------------------------

-- A record is usable only if it has an activityKey: that string is the
-- de-duplication key, so a record without one cannot be grouped and would show
-- up as a nameless row. Dropping it makes the set read as "source unknown",
-- which is the honest outcome for malformed data.
local function isRecord(rec)
    return type(rec) == "table"
       and type(rec.activityKey) == "string"
       and rec.activityKey ~= ""
end

-- Every source record for a set, ALWAYS an array (possibly empty).
--
-- The database is read through the global on every call rather than captured at
-- load time. Load order is a manifest detail that has bitten this add-on
-- before, and it lets the harness swap in a fixture table without reloading the
-- module.
--
-- Contract A allows a single record OR an array of records; callers should
-- never have to care which, so both are normalized here.
--
-- The returned ARRAY is fresh, but the records inside it are the shared tables
-- from data/setSources.lua -- see the read-only note in that file. Copying them
-- per call would be worse, not better: a caller's edit would then silently
-- vanish on the next call instead of being visibly wrong.
function SetSources:GetSources(setId)
    local out = {}

    local id = tonumber(setId)
    if not id then return out end

    local data = AccountHold and AccountHold.SetSourcesData
    if type(data) == "table" then
        local entry = data[id]
        if type(entry) == "table" then
            if isRecord(entry) then
                out[1] = entry
                return out
            end
            for i = 1, #entry do
                local rec = entry[i]
                if isRecord(rec) then
                    out[#out + 1] = rec
                end
            end
            if #out > 0 then return out end
        end
    end

    -- Nothing curated for this set. Ask the GAME.
    --
    -- The Item Sets Book already groups every set under the activity it drops
    -- from -- that grouping is what the player sees in Collections -> Item
    -- Sets -- so the client can answer "where does this set come from?" for
    -- EVERY set, not just the handful in data/setSources.lua.
    --
    -- The curated table still wins when present: it carries zone names and
    -- multi-activity sets that the single category id cannot express. This is a
    -- fallback that closes the long tail, not a replacement.
    local rec = SetSources:GetLiveSource(id)
    if rec then out[#out + 1] = rec end
    return out
end

-- Resolve a set's source from the live client, or nil.
--
-- Verified chain (ESOUIDocumentation.txt, esoui/esoui @ master -- none of these
-- carry the *protected* marker):
--   GetItemSetCollectionCategoryId(itemSetId)      -> categoryId
--   GetItemSetCollectionCategoryName(categoryId)   -> e.g. "Fungal Grotto I"
--   GetItemSetCollectionCategoryParentId(categoryId) -> e.g. the "Dungeons" node
--
-- The category tree is exactly the one rendered in the Item Sets Book
-- (itemsetsbook_shared.lua:306-308 iterates a category's collections), so the
-- name we get back is the name the player already associates with that set.
--
-- Returns a record in the same shape as data/setSources.lua so every downstream
-- consumer -- RollupActivities, the Priorities plan, Travel:FindNodeForActivity,
-- DungeonQueue -- works unchanged.
function SetSources:GetLiveSource(setId)
    local id = tonumber(setId)
    if not id then return nil end

    if type(GetItemSetCollectionCategoryId) ~= "function"
       or type(GetItemSetCollectionCategoryName) ~= "function" then
        return nil
    end

    local okCat, categoryId = pcall(GetItemSetCollectionCategoryId, id)
    if not okCat or type(categoryId) ~= "number" or categoryId == 0 then return nil end

    local okName, name = pcall(GetItemSetCollectionCategoryName, categoryId)
    if not okName or type(name) ~= "string" or name == "" then return nil end

    -- The PARENT category is the activity class ("Dungeons", "Trials",
    -- "Overland"...). It gives us both the activityType and the zone context
    -- that Travel:FindNodeForActivity falls back to.
    local parentName
    if type(GetItemSetCollectionCategoryParentId) == "function" then
        local okParent, parentId = pcall(GetItemSetCollectionCategoryParentId, categoryId)
        if okParent and type(parentId) == "number" and parentId ~= 0 then
            local okPName, pName = pcall(GetItemSetCollectionCategoryName, parentId)
            if okPName and type(pName) == "string" and pName ~= "" then
                parentName = pName
            end
        end
    end

    return {
        -- Namespaced so a live-derived key can never collide with a curated
        -- one, and stable across sessions because categoryId is stable.
        activityKey  = "collection:" .. tostring(categoryId),
        activityName = name,
        activityType = SetSources.ClassifyActivityType(parentName),
        zoneName     = nil,
        _live        = true,
    }
end

-- Map the Item Sets Book's parent category name onto our frozen activityType
-- enum. Pure and case-insensitive so it is testable and tolerant of wording.
--
-- Unrecognised parents fall back to "other" rather than guessing: a wrong
-- activityType would send Travel and DungeonQueue looking for the wrong kind of
-- destination.
function SetSources.ClassifyActivityType(parentName)
    if type(parentName) ~= "string" or parentName == "" then return "other" end
    local p = string.lower(parentName)
    if string.find(p, "dungeon", 1, true) then return "dungeon" end
    if string.find(p, "trial",   1, true) then return "trial"   end
    if string.find(p, "arena",   1, true) then return "arena"   end
    if string.find(p, "overland", 1, true) then return "overland" end
    if string.find(p, "zone",    1, true) then return "overland" end
    return "other"
end

-- True when we have no usable data for this set (absent, malformed, or an empty
-- array all collapse to the same answer). Callers MUST surface this as an
-- explicit "source unknown" row: silently omitting the set would make the
-- add-on look like it had decided the player needs nothing.
function SetSources:IsUnknown(setId)
    return #SetSources:GetSources(setId) == 0
end

-- ---------------------------------------------------------------------------
-- Shared activity rollup
-- ---------------------------------------------------------------------------
--
-- wanted:  { { setId = n, outstanding = k }, ... }
-- returns: { { activityKey, activityName, activityType, zoneName,
--              outstanding = <sum>, setIds = { n, ... } }, ... }
--
-- Semantics, all of them deliberate:
--
-- * DE-DUPLICATION is by activityKey, never by display name. Two dungeons could
--   legitimately share a name across a rename; the key is the identity.
--
-- * MULTI-ACTIVITY SETS get the FULL outstanding count credited to EACH of
--   their activities, not a split share. The records say "this set drops here
--   AND here", so a player who needs 3 pieces needs 3 pieces whichever one they
--   run -- that is the number the row has to show, and it is what makes the two
--   activities rank as equally good options. Splitting (1.5 each) would rank a
--   two-source set BELOW a one-source set with the same need, which is exactly
--   backwards. Do not "fix" this into a split without re-reading this comment.
--
-- * A set contributes to a given activity AT MOST ONCE, even if it appears in
--   `wanted` twice or its record array lists the same activityKey twice.
--   `outstanding` is a property of the set ("pieces still missing"), not of the
--   row, so adding duplicates would inflate the ordering and mis-rank the plan.
--   First qualifying row wins.
--
-- * ROWS WITH outstanding <= 0 ARE SKIPPED ENTIRELY -- they contribute no count
--   and are not listed in setIds. An activity that survives therefore always
--   has real work behind it, which is what 0005 requires ("an activity with no
--   outstanding pieces disappears from the list"), and a fully-owned set never
--   appears in a row's setIds claiming to be covered.
--
-- * SETS WITH NO SOURCE all collapse into ONE synthetic entry
--   (activityKey = "unknown", activityType = "other"), with every unknown set
--   id collected on it. One honest row beats N rows that each say nothing.
--
-- * The SORT is outstanding DESC, then activityName ASC, then activityKey ASC.
--   The final tiebreaker is not decoration: table.sort is NOT stable, so
--   without a total order two equal-ranked activities could swap places between
--   repaints and the plan would look like it was shuffling itself. This add-on
--   has already been bitten by exactly that in its item sorting. activityKey is
--   unique per row here, so the comparator is a strict total order.
function SetSources:RollupActivities(wanted)
    local out = {}
    if type(wanted) ~= "table" then return out end

    -- Resolved once per call, not at load: the string table may be registered
    -- after this file loads, and the result must be consistent within one plan.
    local unknownName = L("SI_ACCOUNTHOLD_SOURCE_UNKNOWN", "Source unknown")

    local byKey = {}

    -- First-seen wins for the display fields. A key that appears with two
    -- different names/zones means the data file disagrees with itself; picking
    -- deterministically keeps the plan stable while the data is corrected.
    local function bucketFor(key, name, activityType, zoneName)
        local bucket = byKey[key]
        if not bucket then
            bucket = {
                activityKey  = key,
                activityName = name,
                activityType = activityType,
                zoneName     = zoneName,
                outstanding  = 0,
                setIds       = {},
                credited     = {},
            }
            byKey[key] = bucket
            out[#out + 1] = bucket
        end
        return bucket
    end

    local function credit(bucket, setId, count)
        if bucket.credited[setId] then return end
        bucket.credited[setId] = true
        bucket.outstanding = bucket.outstanding + count
        bucket.setIds[#bucket.setIds + 1] = setId
    end

    for i = 1, #wanted do
        local row = wanted[i]
        if type(row) == "table" then
            local setId = tonumber(row.setId)
            local count = tonumber(row.outstanding) or 0
            if setId and count > 0 then
                local sources = SetSources:GetSources(setId)
                if #sources == 0 then
                    credit(bucketFor(UNKNOWN_KEY, unknownName, TYPE_OTHER, nil), setId, count)
                else
                    for j = 1, #sources do
                        local rec = sources[j]
                        local activityType = ACTIVITY_TYPES[rec.activityType] and rec.activityType or TYPE_OTHER
                        local name = rec.activityName
                        if type(name) ~= "string" or name == "" then
                            -- Better a key than a blank row; the row still
                            -- identifies where to go.
                            name = rec.activityKey
                        end
                        local zoneName = rec.zoneName
                        if type(zoneName) ~= "string" or zoneName == "" then
                            zoneName = nil
                        end
                        credit(bucketFor(rec.activityKey, name, activityType, zoneName), setId, count)
                    end
                end
            end
        end
    end

    for i = 1, #out do
        local bucket = out[i]
        -- Internal bookkeeping, not part of the contract's row shape.
        bucket.credited = nil
        -- Ascending ids so a row renders identically every repaint regardless
        -- of the order the caller happened to build `wanted` in.
        table.sort(bucket.setIds)
    end

    table.sort(out, function(a, b)
        if a.outstanding ~= b.outstanding then
            return a.outstanding > b.outstanding
        end
        if a.activityName ~= b.activityName then
            return a.activityName < b.activityName
        end
        return a.activityKey < b.activityKey
    end)

    return out
end
