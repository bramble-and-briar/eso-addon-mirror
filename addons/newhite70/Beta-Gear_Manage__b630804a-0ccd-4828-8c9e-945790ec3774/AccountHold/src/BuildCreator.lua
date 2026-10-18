-- Quartermaster/src/BuildCreator.lua
-- Epic 0002 — Armory build creator, MODEL LAYER ONLY (Contract E).
--
-- A "build" is a named set of gear slots, each optionally assigned a set id.
-- The model answers the one question the client UI cannot: *which pieces of
-- this build do I not yet own, and what do I have to go do to get them?*
--
-- Deliberately NOT here, per the epic's non-goals (docs/backlog/0002):
--   * No in-game Armory integration IN THIS MODULE. Equipping, auto-equip and
--     saving into an Armory slot live in src/BuildEquip.lua, which stores its
--     data on the same records (`loadout`, `auto`) without changing this
--     module's fields. (The one Armory symbol touched here is the read-only
--     global MAX_NUM_ARMORY_BUILDS, used only to size our own cap.)
--   * No drop rates, no gold / trader valuation.
--   * No UI, no events, no timers, no protected calls. This module is inert
--     until something calls it, so a disabled `buildCreator` feature gate
--     costs nothing at runtime.
--
-- The activity rollup is NOT reimplemented here. BuildPlan delegates to
-- AccountHold.SetSources:RollupActivities (Contract B) so epics 0002 and 0005
-- can never drift into two different de-duplication rules.

AccountHold = AccountHold or {}
AccountHold.BuildCreator = AccountHold.BuildCreator or {}

local BuildCreator = AccountHold.BuildCreator
local addon

-- ---------------------------------------------------------------------------
-- Small guarded helpers
-- ---------------------------------------------------------------------------

-- Localized string with a fallback. This module must not edit
-- localization/en.lua (single shared file, concurrent edits collide), so every
-- id is declared here with English text and registered centrally later. Until
-- then the fallback renders, never a raw "SI_..." token.
local function L(id, fallback)
    local fn = AccountHold and AccountHold.L
    if type(fn) == "function" then
        local ok, value = pcall(fn, id, fallback)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    return fallback
end

-- ESO never publishes a constant's numeric value and it can change between API
-- versions, so always resolve by NAME at call time and treat absence as
-- "unavailable" rather than erroring. Same doctrine as src/Index.lua.
local function numericConst(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "number" then return v end
    return nil
end

local function fn(name)
    local f = (type(_G) == "table") and _G[name] or nil
    if type(f) == "function" then return f end
    return nil
end

local function diag(level, fmt, ...)
    if addon and type(addon.Diagnostic) == "function" then
        addon:Diagnostic(level, fmt, ...)
    end
end

-- ---------------------------------------------------------------------------
-- Canonical slot keys
-- ---------------------------------------------------------------------------
-- A build slot key is a STRING, never an EQUIP_TYPE_* number, because it is
-- persisted in SavedVariables: a stored numeric constant would silently
-- re-point at a different slot the day ZOS renumbers the enum, and a console
-- player cannot hand-repair SavedVariables.
--
-- The 14 keys below are exactly the gear slots an ESO character wears that can
-- carry a set bonus. Costume / poison / backup-poison are excluded (they carry
-- no set), as are the vestigial EQUIP_SLOT_WRIST / _RANGED / _CLASS1..3.
--
-- `equipTypes` lists the EquipType constant NAMES that may fill the slot, most
-- specific FIRST (that ordering is the allocation preference — see
-- pickCandidate). Evidence for the enum membership: ESOUIDocumentation.txt
-- h5. EquipType, :4957-:4973 — CHEST, COSTUME, FEET, HAND, HEAD, INVALID,
-- LEGS, MAIN_HAND, NECK, OFF_HAND, ONE_HAND, POISON, RING, SHOULDERS,
-- TWO_HAND, WAIST. Note there is no separate "hands"/"gloves" member: gloves
-- are EQUIP_TYPE_HAND (mirrors the EQUIP_TYPE_HAND -> EQUIP_SLOT_HAND pair
-- already used by src/Notify.lua's auto-equip map).
local SLOT_ORDER = {
    "head", "shoulders", "chest", "hands", "waist", "legs", "feet",
    "neck", "ring1", "ring2",
    "mainHand", "offHand", "backupMain", "backupOff",
}

local WEAPON_MAIN_TYPES = { "EQUIP_TYPE_TWO_HAND", "EQUIP_TYPE_MAIN_HAND", "EQUIP_TYPE_ONE_HAND" }
local WEAPON_OFF_TYPES  = { "EQUIP_TYPE_OFF_HAND", "EQUIP_TYPE_ONE_HAND" }

local SLOT_DEFS = {
    head       = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_HEAD",        fallback = "Head",              equipTypes = { "EQUIP_TYPE_HEAD" } },
    shoulders  = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_SHOULDERS",   fallback = "Shoulders",         equipTypes = { "EQUIP_TYPE_SHOULDERS" } },
    chest      = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_CHEST",       fallback = "Chest",             equipTypes = { "EQUIP_TYPE_CHEST" } },
    hands      = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_HANDS",       fallback = "Hands",             equipTypes = { "EQUIP_TYPE_HAND" } },
    waist      = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_WAIST",       fallback = "Waist",             equipTypes = { "EQUIP_TYPE_WAIST" } },
    legs       = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_LEGS",        fallback = "Legs",              equipTypes = { "EQUIP_TYPE_LEGS" } },
    feet       = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_FEET",        fallback = "Feet",              equipTypes = { "EQUIP_TYPE_FEET" } },
    -- Jewelry. ESO has NO ITEMTYPE_JEWELRY: necklaces and rings are
    -- ITEMTYPE_ARMOR told apart ONLY by equipType. Proof: ApplyJewelryToSearch
    -- in esoui/ingame/tradinghouse/tradinghousecategories_shared.lua filters on
    -- ITEMTYPE_ARMOR + EQUIP_TYPE_NECK/EQUIP_TYPE_RING, and its
    -- SetContainsItemCallback tests only GetItemLinkEquipType. src/Index.lua's
    -- entryIsJewelry documents the same finding (and the vestigial ZOS literal
    -- that misleadingly implies ITEMTYPE_JEWELRY exists). Matching jewelry by
    -- itemType here would silently re-open that bug.
    neck       = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_NECK",        fallback = "Necklace",          equipTypes = { "EQUIP_TYPE_NECK" }, isJewelry = true },
    ring1      = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_RING1",       fallback = "Ring 1",            equipTypes = { "EQUIP_TYPE_RING" }, isJewelry = true },
    ring2      = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_RING2",       fallback = "Ring 2",            equipTypes = { "EQUIP_TYPE_RING" }, isJewelry = true },
    -- Weapon bars. A one-handed weapon can fill either hand, so ONE_HAND is
    -- listed for both and consumed by whichever slot claims it first (slots are
    -- walked in SLOT_ORDER). Listing the exclusive type first means a shield
    -- (OFF_HAND) is preferred for the off hand before a one-hander is taken
    -- away from the main hand.
    mainHand   = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_MAIN_HAND",   fallback = "Main Hand",         equipTypes = WEAPON_MAIN_TYPES, isWeapon = true },
    offHand    = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_OFF_HAND",    fallback = "Off Hand",          equipTypes = WEAPON_OFF_TYPES,  isWeapon = true },
    backupMain = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_BACKUP_MAIN", fallback = "Backup Main Hand",  equipTypes = WEAPON_MAIN_TYPES, isWeapon = true },
    backupOff  = { stringId = "SI_ACCOUNTHOLD_BUILD_SLOT_BACKUP_OFF",  fallback = "Backup Off Hand",   equipTypes = WEAPON_OFF_TYPES,  isWeapon = true },
}

BuildCreator.SLOT_ORDER = SLOT_ORDER

-- Resolved lazily: constants absent on this client are skipped, exactly like
-- Index.lua's resolveTypeSet, so the addon still loads on a build that renamed
-- or dropped one of them.
local RESOLVED_EQUIP_TYPES
local function slotEquipTypes(slotKey)
    if not RESOLVED_EQUIP_TYPES then
        RESOLVED_EQUIP_TYPES = {}
        for key, def in pairs(SLOT_DEFS) do
            local list = {}
            for _, name in ipairs(def.equipTypes) do
                local v = numericConst(name)
                if v ~= nil then list[#list + 1] = v end
            end
            RESOLVED_EQUIP_TYPES[key] = list
        end
    end
    return RESOLVED_EQUIP_TYPES[slotKey] or {}
end

function BuildCreator:GetSlotLabel(slotKey)
    local def = SLOT_DEFS[slotKey]
    if not def then return tostring(slotKey) end
    return L(def.stringId, def.fallback)
end

-- Ordered slot descriptors for a filter-first / list-driven picker. `resolved`
-- is false when this client exposes none of the slot's EquipType constants —
-- the UI may still offer the slot (the assignment round-trips through
-- SavedVariables) but ownership for it degrades to set-level; see GetPieces.
function BuildCreator:GetSlots()
    local out = {}
    for _, key in ipairs(SLOT_ORDER) do
        local def = SLOT_DEFS[key]
        out[#out + 1] = {
            key       = key,
            label     = self:GetSlotLabel(key),
            isJewelry = def.isJewelry and true or false,
            isWeapon  = def.isWeapon and true or false,
            resolved  = #slotEquipTypes(key) > 0,
        }
    end
    return out
end

function BuildCreator:IsSlot(slotKey)
    return SLOT_DEFS[slotKey] ~= nil
end

-- ---------------------------------------------------------------------------
-- Piece states
-- ---------------------------------------------------------------------------
-- Three states, not two. A piece the player can RECONSTRUCT at a Transmute
-- Station is not owned (they still have to go get it), but farming it would be
-- wasted effort — reconstruction is instant and repeatable. Collapsing it into
-- either "owned" or "missing" gives the player a materially wrong plan, so it
-- is its own state: it stays in GetMissingPieces (Contract E defines that as
-- `owned == false`) but is excluded from BuildPlan's farming rollup.
local STATE_OWNED           = "owned"
local STATE_RECONSTRUCTABLE = "reconstructable"
local STATE_MISSING         = "missing"

BuildCreator.STATE_OWNED           = STATE_OWNED
BuildCreator.STATE_RECONSTRUCTABLE = STATE_RECONSTRUCTABLE
BuildCreator.STATE_MISSING         = STATE_MISSING

-- ---------------------------------------------------------------------------
-- Limits
-- ---------------------------------------------------------------------------
-- Console SavedVariables are a shared, size-sensitive budget the player cannot
-- prune by hand, so both the build count and the name length are capped.
--
-- Count: mirror the game's own loadout cap, MAX_NUM_ARMORY_BUILDS
-- (ESOUIDocumentation.txt :8178, "h5. Globals" under the Armory block), so the
-- player's mental model matches the Armory station. Read-only; no Armory data
-- is read or written (epic non-goal). Clamped to a sane band so an unexpected
-- value can never blow up the SV file, and defaulted to 20 when absent.
local DEFAULT_MAX_BUILDS = 20
local MIN_MAX_BUILDS, MAX_MAX_BUILDS = 4, 40

local function maxBuilds()
    local n = numericConst("MAX_NUM_ARMORY_BUILDS")
    if n and n >= MIN_MAX_BUILDS and n <= MAX_MAX_BUILDS then return n end
    return DEFAULT_MAX_BUILDS
end
BuildCreator.GetMaxBuilds = function() return maxBuilds() end

-- 32 bytes. Long enough for every preset below plus a disambiguating suffix,
-- short enough to render in one gamepad parametric-list row without ellipsis.
local MAX_NAME_LENGTH = 32
BuildCreator.MAX_NAME_LENGTH = MAX_NAME_LENGTH

-- ---------------------------------------------------------------------------
-- Name handling (console-safe)
-- ---------------------------------------------------------------------------
-- Platform.SupportsFreeTextSearch() is false on console, so the model never
-- assumes the name was typed. It accepts whatever string the caller supplies
-- and the UI decides how it was obtained: a keyboard edit box on PC, or a
-- selectable preset from GetSuggestedNames() on Xbox/PS5.

local NAME_PRESETS = {
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_DPS",     fallback = "Damage Dealer" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_TANK",    fallback = "Tank" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_HEALER",  fallback = "Healer" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_PVP",     fallback = "PvP" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_TRIAL",   fallback = "Trials" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_DUNGEON", fallback = "Dungeons" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_SOLO",    fallback = "Solo / Overland" },
    { stringId = "SI_ACCOUNTHOLD_BUILD_PRESET_CRAFT",   fallback = "Crafting" },
}

function BuildCreator:GetSuggestedNames()
    local out = {}
    for _, p in ipairs(NAME_PRESETS) do
        out[#out + 1] = L(p.stringId, p.fallback)
    end
    return out
end

-- Byte-safe truncation. Lua 5.1 has no utf8 library and ESO strings are UTF-8,
-- so a blind :sub() can cut a multi-byte character in half and leave a broken
-- glyph in a name the player can no longer read or retype. Back off over
-- continuation bytes (10xxxxxx == 128..191) until the cut lands on a character
-- boundary.
local function trimToBytes(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 0 do
        local b = s:byte(cut + 1)
        if b == nil or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return s:sub(1, cut)
end

-- Returns a storable name, or nil when nothing usable is left.
local function sanitizeName(name)
    if type(name) ~= "string" then return nil end
    -- Drop the pipe outright. "|c00FF00" colour escapes and "|H...|h" links are
    -- interpreted by every ESO label, so a pipe inside a persisted name would
    -- recolour or corrupt any row that renders it — and could be used to forge
    -- UI text. Names are display data; they never need markup.
    name = name:gsub("|", "")
    name = name:gsub("%c", " ")
    name = name:gsub("%s+", " ")
    name = name:gsub("^ ", ""):gsub(" $", "")
    if name == "" then return nil end
    return trimToBytes(name, MAX_NAME_LENGTH)
end

-- ---------------------------------------------------------------------------
-- SavedVariables access
-- ---------------------------------------------------------------------------
-- sv.builds is seeded by the coordinator's dataVersion migration, but this
-- module must never assume it ran: reads degrade to empty, and only a write
-- creates the table. Same contract as sv.nextBuildId.

local EMPTY = {}

local function buildsRead()
    if addon and type(addon.sv) == "table" and type(addon.sv.builds) == "table" then
        return addon.sv.builds
    end
    return EMPTY
end

local function buildsWrite()
    if not addon or type(addon.sv) ~= "table" then return nil end
    if type(addon.sv.builds) ~= "table" then addon.sv.builds = {} end
    return addon.sv.builds
end

-- Mirrors Holds.lua's nextHoldId: a monotonic counter in SV so ids are stable
-- across sessions and never reused after a delete.
local function nextBuildId()
    if not addon or type(addon.sv) ~= "table" then return nil end
    local id = addon.sv.nextBuildId
    if type(id) ~= "number" or id < 1 then
        -- Recover a sane counter if the migration never ran or SV was mangled.
        id = 1
        for key in pairs(buildsRead()) do
            local n = tonumber(key)
            if n and n >= id then id = n + 1 end
        end
    end
    addon.sv.nextBuildId = id + 1
    return id
end

local function countBuilds()
    local n = 0
    for _ in pairs(buildsRead()) do n = n + 1 end
    return n
end
BuildCreator.CountBuilds = function() return countBuilds() end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function BuildCreator:Initialize(addonRef)
    addon = addonRef
    -- No events, no timers, no scans: the model is inert until the UI (a later
    -- agent) or a test calls it. One cheap normalization pass so a record
    -- written by a different build version can't crash a list refresh.
    local builds = buildsRead()
    if builds == EMPTY then return end
    for key, record in pairs(builds) do
        if type(record) ~= "table" then
            builds[key] = nil
        else
            record.id    = record.id or tonumber(key) or key
            record.name  = sanitizeName(record.name) or L("SI_ACCOUNTHOLD_BUILD_UNNAMED", "Unnamed Build")
            if type(record.slots) ~= "table" then record.slots = {} end
            record.createdAt = tonumber(record.createdAt) or 0
            record.updatedAt = tonumber(record.updatedAt) or record.createdAt
        end
    end
end

-- Advisory only. The model deliberately does NOT self-gate: it has no runtime
-- footprint when nobody calls it, and refusing here would make the gate look
-- like data loss. The UI checks this before exposing any build surface.
function BuildCreator:IsEnabled()
    local features = addon and addon.Features
    if features and type(features.IsEnabled) == "function" then
        local ok, enabled = pcall(features.IsEnabled, features, "buildCreator")
        if ok then return enabled and true or false end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- CRUD
-- ---------------------------------------------------------------------------

local function timestamp()
    local f = fn("GetTimeStamp")
    if f then
        local ok, ts = pcall(f)
        if ok and type(ts) == "number" then return ts end
    end
    return 0
end

-- Case-insensitive comparator, same reasoning as Index.lua's labelLess: a raw
-- `a < b` is a byte compare, so every capitalized name would sort ahead of
-- every lowercase one. Second term keeps the order deterministic.
local function nameLess(a, b)
    a, b = a or "", b or ""
    local la, lb = string.lower(a), string.lower(b)
    if la ~= lb then return la < lb end
    return a < b
end

-- Duplicate names are DISAMBIGUATED, not rejected. On console the player picks
-- from a preset list, so collisions are the normal case, not user error — and
-- a create that silently fails is far worse on a platform with no error log.
-- `excludeId` skips one record, so renaming a build to a different casing of
-- its own name doesn't collide with itself and come back as "tank (2)".
local function uniqueName(base, excludeId)
    local taken = {}
    for key, record in pairs(buildsRead()) do
        if type(record) == "table" and type(record.name) == "string"
           and (excludeId == nil or (record.id or key) ~= excludeId) then
            taken[string.lower(record.name)] = true
        end
    end
    if not taken[string.lower(base)] then return base end
    for n = 2, MAX_MAX_BUILDS + 1 do
        local suffix    = string.format(" (%d)", n)
        local candidate = trimToBytes(base, MAX_NAME_LENGTH - #suffix) .. suffix
        if not taken[string.lower(candidate)] then return candidate end
    end
    return base
end

-- Returns the new buildId, or nil when the name is unusable or the cap is hit.
function BuildCreator:CreateBuild(name)
    local builds = buildsWrite()
    if not builds then
        diag("warn", "BuildCreator:CreateBuild called before SavedVariables were wired")
        return nil
    end
    local clean = sanitizeName(name)
    if not clean then
        clean = L("SI_ACCOUNTHOLD_BUILD_UNNAMED", "Unnamed Build")
    end
    local cap = maxBuilds()
    if countBuilds() >= cap then
        diag("warn", "BuildCreator: build limit reached (%d); not creating %q", cap, clean)
        return nil
    end
    local id = nextBuildId()
    if not id then return nil end
    local now = timestamp()
    builds[id] = {
        id        = id,
        name      = uniqueName(clean),
        slots     = {},
        -- Auto-equip is OFF for every new build; src/BuildEquip.lua owns it.
        auto      = { enabled = false, rules = {} },
        createdAt = now,
        updatedAt = now,
    }
    return id
end

function BuildCreator:DeleteBuild(buildId)
    local builds = buildsRead()
    if builds == EMPTY then return false end
    local key = (builds[buildId] ~= nil) and buildId or tonumber(buildId)
    if key == nil or builds[key] == nil then return false end
    builds[key] = nil
    return true
end

-- SavedVariables round-tripping can hand a numeric key back as a string, so
-- accept either form rather than silently reporting "no such build".
function BuildCreator:GetBuild(buildId)
    local builds = buildsRead()
    local record = builds[buildId]
    if record == nil then
        local n = tonumber(buildId)
        if n ~= nil then record = builds[n] end
    end
    if type(record) ~= "table" then return nil end
    return record
end

function BuildCreator:ListBuilds()
    local out = {}
    for key, record in pairs(buildsRead()) do
        if type(record) == "table" then
            out[#out + 1] = {
                id        = record.id or tonumber(key) or key,
                name      = record.name or "",
                updatedAt = record.updatedAt or 0,
            }
        end
    end
    -- Name ASC per Contract E; id breaks ties so pairs() order can never make
    -- the list shuffle between refreshes.
    table.sort(out, function(a, b)
        if a.name ~= b.name then return nameLess(a.name, b.name) end
        return tostring(a.id) < tostring(b.id)
    end)
    return out
end

function BuildCreator:RenameBuild(buildId, name)
    local record = self:GetBuild(buildId)
    if not record then return false end
    local clean = sanitizeName(name)
    if not clean then return false end
    if clean ~= record.name then
        record.name      = uniqueName(clean, record.id)
        record.updatedAt = timestamp()
    end
    return true
end

-- setId nil clears the slot. setId 0 is rejected: GetItemLinkSetInfo
-- (ESOUIDocumentation.txt :21655) returns setId 0 for a non-set item, so 0
-- means "no set" and must never be stored as an assignment.
function BuildCreator:SetSlot(buildId, slot, setId)
    local record = self:GetBuild(buildId)
    if not record then return false end
    if not SLOT_DEFS[slot] then
        diag("warn", "BuildCreator:SetSlot unknown slot %q", tostring(slot))
        return false
    end
    if setId ~= nil then
        setId = tonumber(setId)
        if type(setId) ~= "number" or setId <= 0 then return false end
    end
    if type(record.slots) ~= "table" then record.slots = {} end
    if record.slots[slot] ~= setId then
        record.slots[slot] = setId
        record.updatedAt   = timestamp()
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Ownership
-- ---------------------------------------------------------------------------

-- equipType for an index entry: prefer the value Scanner cached, else resolve
-- from the stored item link. Self-contained copy of Index.lua's entryEquipType
-- (that one is a file-local) so entries written by an older build — which have
-- no cached equipType — still classify without forcing a rescan.
-- GetItemLinkEquipType returns exactly ONE value (ESOUIDocumentation.txt
-- :21709-:21710), so a single-result capture is correct here.
local function entryEquipType(entry)
    if not entry then return nil end
    if type(entry.equipType) == "number" then return entry.equipType end
    local f    = fn("GetItemLinkEquipType")
    local link = entry.itemLink or entry.link or entry.itemSignature
    if not f or type(link) ~= "string" or link == "" then return nil end
    local ok, value = pcall(f, link)
    if ok and type(value) == "number" then return value end
    return nil
end

-- Companion gear carries byte-identical ITEMTYPE_*/EQUIP_TYPE_* values to the
-- player's own kit and is separable ONLY by GameplayActorCategory (see
-- Index.lua's entryActorCategory and esoui/ingame/inventory/sharedinventory.lua
-- `slot.actorCategory = GetItemActorCategory(bagId, slotIndex)`). A companion
-- ring must never satisfy the player's ring slot. When the actor-category API
-- is absent we cannot tell, so we do NOT exclude — hiding real gear is worse
-- than the vanishingly rare false positive.
local function isCompanionGear(entry)
    local companion = numericConst("GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    if companion == nil then return false end
    if type(entry.actorCategory) == "number" then return entry.actorCategory == companion end
    local f    = fn("GetItemLinkActorCategory")
    local link = entry.itemLink or entry.link or entry.itemSignature
    if not f or type(link) ~= "string" or link == "" then return false end
    local ok, value = pcall(f, link)
    return ok and value == companion
end

-- Rows are produced by pairs() over SavedVariables tables, so their order is
-- undefined. Sort candidates before allocating them to slots or the same
-- account state could report a different location (or, for one-handers, a
-- different slot) on every refresh.
local function candidateLess(a, b)
    local ka, kb = tostring(a.locationKey or ""), tostring(b.locationKey or "")
    if ka ~= kb then return ka < kb end
    local ba, bb = tonumber(a.bagId) or -1, tonumber(b.bagId) or -1
    if ba ~= bb then return ba < bb end
    return (tonumber(a.slotIndex) or -1) < (tonumber(b.slotIndex) or -1)
end

-- Every account-owned piece of a set, one candidate per physical copy.
--
-- Uses Index:Query (not QueryGear) on purpose: QueryGear's isGearEntry drops
-- any entry whose cached itemType is missing, which would under-report
-- ownership for items scanned by an older build. equipType is the field that
-- actually decides slot fit, and it is resolvable from the item link.
local function candidatesForSet(setId)
    local out = {}
    local index = addon and addon.Index
    if not index or type(index.Query) ~= "function" then return out end
    local ok, rows = pcall(index.Query, index, { setId = setId })
    if not ok or type(rows) ~= "table" then return out end
    for _, row in ipairs(rows) do
        local entry = row.entry
        if type(entry) == "table" and not isCompanionGear(entry) then
            out[#out + 1] = {
                row           = row,
                equipType     = entryEquipType(entry),
                locationKey   = row.locationKey,
                locationLabel = row.locationLabel,
                bagId         = row.bagId,
                slotIndex     = row.slotIndex,
            }
        end
    end
    table.sort(out, candidateLess)
    return out
end

-- Claim one unused candidate for a slot. `preference` is the slot's resolved
-- EquipType list, most specific first, so a shield is taken for the off hand
-- before a one-hander is stolen from the main hand.
local function pickCandidate(cands, used, preference)
    for _, wanted in ipairs(preference) do
        for i, cand in ipairs(cands) do
            if not used[i] and cand.equipType == wanted then return i end
        end
    end
    -- Degraded path: this client exposes none of the slot's EquipType
    -- constants, so slot fit cannot be verified. Fall back to set-level
    -- ownership (any unclaimed piece of the set) rather than declaring a piece
    -- the player owns "missing" and sending them to farm it.
    if #preference == 0 then
        for i in ipairs(cands) do
            if not used[i] then return i end
        end
    end
    return nil
end

-- Which equip types of a set the player can RECONSTRUCT.
--
-- Resolved per PIECE, never from Index:GetKnownSets().reconstructable: that is
-- GetNumItemSetCollectionSlotsUnlocked (ESOUIDocumentation.txt :19944), an
-- aggregate COUNT for the whole set. A count cannot say *which* slot is
-- unlocked, so using it per-slot would tell a player they can reconstruct a
-- ring when what they actually unlocked was the hat.
--
-- The precise walk (all guarded; returns nil = "unknown" when any part is
-- absent, and unknown is treated as missing so we never under-plan):
--   GetNumItemSetCollectionPieces(setId)              :19938
--   GetItemSetCollectionPieceInfo(setId, index)       :19941  -> pieceId, slot
--   GetItemSetCollectionPieceItemLink(pieceId, ...)   :19982  -> itemLink
--   GetItemLinkEquipType(itemLink)                    :21709  -> equipType
--   IsItemSetCollectionPieceUnlocked(pieceId)         :23767  -> bool
--
-- MULTI-RETURN HAZARD: GetItemSetCollectionPieceInfo returns a PAIR
-- (pieceId, slot). Capturing only the first through a one-result pcall wrapper
-- is the exact bug class that cost this addon its furnishing sub-filters, so
-- both returns are captured explicitly below. The `slot` return is an id64
-- ItemSetCollectionSlot with no documented ITEM_SET_COLLECTION_SLOT_* constant
-- names to compare against, which is precisely why we go through the piece's
-- item link to get an EquipType we CAN reason about.
local function reconstructableEquipTypes(setId)
    local numPieces   = fn("GetNumItemSetCollectionPieces")
    local pieceInfo   = fn("GetItemSetCollectionPieceInfo")
    local pieceLink   = fn("GetItemSetCollectionPieceItemLink")
    local pieceUnlock = fn("IsItemSetCollectionPieceUnlocked")
    local equipTypeOf = fn("GetItemLinkEquipType")
    local linkStyle   = numericConst("LINK_STYLE_DEFAULT")
    local traitNone   = numericConst("ITEM_TRAIT_TYPE_NONE")
    if not (numPieces and pieceInfo and pieceLink and pieceUnlock and equipTypeOf)
       or linkStyle == nil or traitNone == nil then
        return nil
    end

    local okCount, count = pcall(numPieces, setId)
    if not okCount or type(count) ~= "number" or count <= 0 then return nil end

    local byEquipType, any = {}, false
    for i = 1, count do
        local okInfo, pieceId = pcall(pieceInfo, setId, i)
        if okInfo and type(pieceId) == "number" then
            local okUnlocked, unlocked = pcall(pieceUnlock, pieceId)
            if okUnlocked and unlocked then
                local okLink, link = pcall(pieceLink, pieceId, linkStyle, traitNone)
                if okLink and type(link) == "string" and link ~= "" then
                    local okType, et = pcall(equipTypeOf, link)
                    if okType and type(et) == "number" then
                        byEquipType[et] = true
                        any = true
                    end
                end
            end
        end
    end
    byEquipType.any = any
    return byEquipType
end

-- Display name for a set. Owned pieces carry it; for a set the account owns
-- nothing of, GetItemSetName (ESOUIDocumentation.txt :19929) still resolves it,
-- which is exactly the "I planned a set I don't have yet" case.
local function resolveSetName(setId, cands)
    for _, cand in ipairs(cands) do
        local name = cand.row and cand.row.entry and cand.row.entry.setName
        if type(name) == "string" and name ~= "" then return name end
    end
    local f = fn("GetItemSetName")
    if f then
        local ok, name = pcall(f, setId)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    local index = addon and addon.Index
    if index and type(index.GetKnownSets) == "function" then
        local ok, sets = pcall(index.GetKnownSets, index)
        if ok and type(sets) == "table" then
            for _, s in ipairs(sets) do
                if s.setId == setId and type(s.name) == "string" and s.name ~= "" then
                    return s.name
                end
            end
        end
    end
    return string.format(L("SI_ACCOUNTHOLD_BUILD_SET_UNKNOWN", "Set #%d"), setId)
end

local function sourcesModule()
    local ss = AccountHold and AccountHold.SetSources
    if type(ss) == "table" then return ss end
    return nil
end

-- Every assigned slot of a build, in canonical slot order.
--
-- Contract E fields: { slot, setId, setName, owned }. The extra fields are a
-- superset the UI needs (the epic asks to show WHERE an owned piece is) and are
-- safe for any caller that ignores them.
function BuildCreator:GetPieces(buildId)
    local record = self:GetBuild(buildId)
    if not record then return {} end
    local slots = record.slots
    if type(slots) ~= "table" then return {} end

    -- Per-call caches: one Index query and one collection walk per distinct
    -- set, shared by every slot naming it. Not module-level — unlock state and
    -- inventory both change mid-session and this module registers no events to
    -- learn about it, so a persistent cache would go stale and lie.
    local cands, used, recon, names = {}, {}, {}, {}
    local ss = sourcesModule()

    local out = {}
    for _, slotKey in ipairs(SLOT_ORDER) do
        local setId = tonumber(slots[slotKey])
        if setId and setId > 0 then
            if cands[setId] == nil then
                cands[setId] = candidatesForSet(setId)
                used[setId]  = {}
                recon[setId] = reconstructableEquipTypes(setId)
                names[setId] = resolveSetName(setId, cands[setId])
            end

            local preference = slotEquipTypes(slotKey)
            local pick       = pickCandidate(cands[setId], used[setId], preference)
            local state, cand

            if pick then
                used[setId][pick] = true
                cand  = cands[setId][pick]
                state = STATE_OWNED
            else
                -- Reconstruction is repeatable and per collection slot, so it is
                -- never "consumed": one unlocked ring piece covers ring1 AND
                -- ring2. That asymmetry with owned pieces is deliberate.
                local r = recon[setId]
                state = STATE_MISSING
                if r then
                    if #preference == 0 then
                        if r.any then state = STATE_RECONSTRUCTABLE end
                    else
                        for _, et in ipairs(preference) do
                            if r[et] then state = STATE_RECONSTRUCTABLE break end
                        end
                    end
                end
            end

            local entry = {
                slot            = slotKey,
                slotLabel       = self:GetSlotLabel(slotKey),
                setId           = setId,
                setName         = names[setId],
                owned           = (state == STATE_OWNED),
                state           = state,
                reconstructable = (state == STATE_RECONSTRUCTABLE),
            }
            if cand then
                entry.locationLabel = cand.locationLabel
                entry.locationKey   = cand.locationKey
                entry.characterId   = cand.row and cand.row.characterId
                entry.bagId         = cand.bagId
                entry.slotIndex     = cand.slotIndex
            elseif ss and type(ss.IsUnknown) == "function" then
                -- Contract B: a set with no source data must be surfaced as an
                -- explicit "source unknown" row, never silently omitted.
                local ok, unknown = pcall(ss.IsUnknown, ss, setId)
                entry.sourceUnknown = (ok and unknown) and true or false
            end
            out[#out + 1] = entry
        end
    end
    return out
end

-- Contract E: everything with owned == false, which by design INCLUDES
-- reconstructable pieces — the player does not have them yet, so the checklist
-- must still show them. Filter on `state` to separate the two.
function BuildCreator:GetMissingPieces(buildId)
    local out = {}
    for _, entry in ipairs(self:GetPieces(buildId)) do
        if not entry.owned then out[#out + 1] = entry end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Activity plan
-- ---------------------------------------------------------------------------

-- De-duplicated activity list for everything the player must actually go FARM.
--
-- Reconstructable pieces are excluded: a Transmute Station purchase is not an
-- activity to plan a play session around, and including it would send the
-- player to a dungeon they have no reason to run.
--
-- The rollup itself is Contract B's — SetSources:RollupActivities is the single
-- de-duplication implementation shared with epic 0005. Missing pieces are first
-- aggregated per set so a build wanting three pieces of one set produces one
-- `wanted` row with outstanding = 3, never three ambiguous rows.
function BuildCreator:BuildPlan(buildId)
    local counts, order = {}, {}
    for _, entry in ipairs(self:GetPieces(buildId)) do
        if entry.state == STATE_MISSING then
            if counts[entry.setId] == nil then
                counts[entry.setId] = 0
                order[#order + 1]   = entry.setId
            end
            counts[entry.setId] = counts[entry.setId] + 1
        end
    end
    if #order == 0 then return {} end

    local ss = sourcesModule()
    if not ss or type(ss.RollupActivities) ~= "function" then
        diag("warn", "BuildCreator:BuildPlan — SetSources unavailable; no activity plan")
        return {}
    end

    local wanted = {}
    for _, setId in ipairs(order) do
        wanted[#wanted + 1] = { setId = setId, outstanding = counts[setId] }
    end

    local ok, activities = pcall(ss.RollupActivities, ss, wanted)
    if not ok then
        diag("error", "BuildCreator:BuildPlan — RollupActivities failed: %s", tostring(activities))
        return {}
    end
    if type(activities) ~= "table" then return {} end
    return activities
end
