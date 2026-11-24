-- Quickslot Profiles: profiles of the quickslot wheel, loaded by zone type.
--
-- A profile is a name and the 8 wheel slots. Zone types are assigned to profiles: each zone
-- type belongs to at most one profile, and "Everything else" catches the zone types no
-- profile has. The profile that is on the wheel right now is the "active" one. A loading
-- screen puts the zone's profile on the wheel. Profiles only change when saved in the
-- editor (Editor.lua).
--
-- Zone type assignments are kept per Armory build. Until the character restores or saves
-- a build at the Armory there is one set, "Default". The first restore or save turns it
-- into that build's set, and every other build starts with a copy of it.

QuickslotProfiles = QuickslotProfiles or {}
local QSP = QuickslotProfiles

QSP.NAME = "QuickslotProfiles"
QSP.TITLE = "Quickslot Profiles"
QSP.VERSION = "1.4.1"

local CATEGORY = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
local NUM_SLOTS = ACTION_BAR_UTILITY_BAR_SIZE or 8
QSP.NUM_SLOTS = NUM_SLOTS
QSP.CATEGORY = CATEGORY

local LOAD_RETRY_MS = 2000
local RETRY_KEY = QSP.NAME .. "LoadRetry"

-- 1: first version. 2: Battlegrounds profile, every profile has slots. 3: zone types are
-- assigned per Armory build (cs.assign) instead of on the profiles.
local SCHEMA = 3
local DEFAULT_LAYER = "default"

local charDefaults =
{
    profiles = {}, -- id -> { name, slots = { [slot] = entry or false } }
    assign = {}, -- "default" or "b<build index>" -> { [zoneKey] = profile id }
    armory = { unlocked = false, current = nil }, -- current: index of the build in use
    order = {}, -- profile ids in display order
    nextId = 1,
    active = nil, -- id of the profile on the wheel
    initialized = false,
    schema = 0,
}
local accountDefaults =
{
    chatOnLoad = true,
    clearEmpty = true,
    saveOnLeave = false,
}

local cs -- per character
local as -- account-wide

--------------------------------------------------------------------------------
-- Chat
--------------------------------------------------------------------------------

local PREFIX = "|cFFD24D[QSP]|r "

function QSP.Msg(text)
    CHAT_ROUTER:AddSystemMessage(PREFIX .. text)
end

function QSP.Cmd(text) return "|cFFD24D" .. text .. "|r" end
function QSP.Hi(text) return "|cFFFFFF" .. text .. "|r" end

-- User input echoed back: "|" would start a markup code.
function QSP.Escape(text) return (tostring(text):gsub("|", "||")) end

--------------------------------------------------------------------------------
-- Profiles
--------------------------------------------------------------------------------

function QSP.GetProfile(id) return id and cs.profiles[id] end
function QSP.GetOrder() return cs.order end
function QSP.GetActiveId() return cs.active end
function QSP.SetActive(id) cs.active = id end
function QSP.IsChatOnLoadOn() return as.chatOnLoad end
function QSP.SetChatOnLoad(on) as.chatOnLoad = on end
function QSP.IsClearEmptyOn() return as.clearEmpty end
function QSP.SetClearEmpty(on)
    as.clearEmpty = on
    if QSP.Editor then QSP.Editor.RefreshSettingsInfo() end
end
function QSP.IsSaveOnLeaveOn() return as.saveOnLeave end
function QSP.SetSaveOnLeave(on)
    as.saveOnLeave = on
    if QSP.Editor then QSP.Editor.RefreshSettingsInfo() end
end

function QSP.ProfileName(id)
    local profile = QSP.GetProfile(id)
    return profile and profile.name or "?"
end

function QSP.FindProfileByName(name)
    name = zo_strlower(zo_strtrim(name or ""))
    if name == "" then return nil end
    local prefixMatch, prefixCount = nil, 0
    for _, id in ipairs(cs.order) do
        local profileName = zo_strlower(cs.profiles[id].name)
        if profileName == name then return id end
        if profileName:sub(1, #name) == name then
            prefixMatch, prefixCount = id, prefixCount + 1
        end
    end
    if prefixCount == 1 then return prefixMatch end
end

local function IsNameTaken(name, exceptId)
    local lower = zo_strlower(name)
    for _, id in ipairs(cs.order) do
        if id ~= exceptId and zo_strlower(cs.profiles[id].name) == lower then return true end
    end
    return false
end

local function CopySlots(slots)
    local copy = {}
    for slot = 1, NUM_SLOTS do
        local entry = slots and slots[slot]
        copy[slot] = entry and ZO_ShallowTableCopy(entry) or false
    end
    return copy
end

-- slots: the profile's slots; nil starts from what is on the wheel now.
function QSP.CreateProfile(name, slots)
    if not name or IsNameTaken(name) then
        local base = name or "Profile"
        local n = name and 2 or #cs.order + 1
        repeat
            name = base .. " " .. n
            n = n + 1
        until not IsNameTaken(name)
    end
    local id = "p" .. cs.nextId
    cs.nextId = cs.nextId + 1
    cs.profiles[id] = { name = name, slots = slots or QSP.CaptureWheel() }
    table.insert(cs.order, id)
    return id
end

-- Returns false and a reason if the name can't be used.
function QSP.RenameProfile(id, name)
    name = zo_strtrim(name or "")
    if name == "" then return false, "The name can't be empty." end
    if name:find("|", 1, true) then return false, "The name can't contain \"||\"." end
    if IsNameTaken(name, id) then return false, "There already is a profile called " .. QSP.Escape(name) .. "." end
    cs.profiles[id].name = name
    return true
end

function QSP.DeleteProfile(id)
    cs.profiles[id] = nil
    for i, orderId in ipairs(cs.order) do
        if orderId == id then
            table.remove(cs.order, i)
            break
        end
    end
    for _, assign in pairs(cs.assign) do
        for zoneKey, owner in pairs(assign) do
            if owner == id then assign[zoneKey] = nil end
        end
    end
    if cs.active == id then cs.active = nil end
end

--------------------------------------------------------------------------------
-- Armory builds and zone type assignments
--------------------------------------------------------------------------------

local function BuildLayer(buildIndex) return "b" .. buildIndex end
QSP.DEFAULT_LAYER = DEFAULT_LAYER

function QSP.LayerBuildIndex(layer) return layer and tonumber(layer:match("^b(%d+)$")) end
function QSP.IsArmoryUnlocked() return cs.armory.unlocked end
function QSP.GetCurrentBuild() return cs.armory.unlocked and cs.armory.current or nil end

-- The set of zone type assignments in use: the current build's, or "default".
function QSP.GetCurrentLayer()
    local build = QSP.GetCurrentBuild()
    return build and BuildLayer(build) or DEFAULT_LAYER
end

function QSP.GetNumBuilds() return GetNumUnlockedArmoryBuilds and GetNumUnlockedArmoryBuilds() or 0 end

function QSP.GetBuildLayers()
    local layers = {}
    for i = 1, QSP.GetNumBuilds() do layers[i] = BuildLayer(i) end
    return layers
end

local function GetBuildData(buildIndex)
    return ZO_ARMORY_MANAGER and ZO_ARMORY_MANAGER.GetBuildDataByIndex and ZO_ARMORY_MANAGER:GetBuildDataByIndex(buildIndex)
end

function QSP.GetBuildName(buildIndex)
    local data = GetBuildData(buildIndex)
    if data then return data:GetName() end
    local name = GetArmoryBuildName and GetArmoryBuildName(buildIndex) or ""
    return name ~= "" and name or ("Build " .. buildIndex)
end

function QSP.GetBuildIcon(buildIndex)
    local data = GetBuildData(buildIndex)
    return data and data:GetIcon() or nil
end

function QSP.LayerName(layer)
    local build = QSP.LayerBuildIndex(layer)
    return build and QSP.GetBuildName(build) or "Default"
end

-- A build seen for the first time starts with a copy of another set: the given one, the
-- current one, or whatever set exists.
local function GetAssign(layer, copyFrom)
    layer = layer or QSP.GetCurrentLayer()
    local assign = cs.assign[layer]
    if not assign then
        local source = cs.assign[copyFrom or QSP.GetCurrentLayer()] or cs.assign[DEFAULT_LAYER]
        if not source then
            local lowest
            for key, value in pairs(cs.assign) do
                local build = QSP.LayerBuildIndex(key)
                if build and (not lowest or build < lowest) then lowest, source = build, value end
            end
        end
        assign = source and ZO_ShallowTableCopy(source) or {}
        cs.assign[layer] = assign
    end
    return assign
end

-- Which profile has a zone type assigned directly (not through "Everything else").
function QSP.GetZoneTypeOwner(zoneKey, layer)
    local id = GetAssign(layer)[zoneKey]
    return cs.profiles[id] and id or nil
end

-- The profile a zone type loads, or nil if the wheel stays as it is there.
function QSP.GetProfileForZoneType(zoneKey, layer)
    return QSP.GetZoneTypeOwner(zoneKey, layer) or QSP.GetZoneTypeOwner("other", layer)
end

-- The zone types a profile has: { [zoneKey] = true }.
function QSP.GetProfileZones(id, layer)
    local zones = {}
    for zoneKey, owner in pairs(GetAssign(layer)) do
        if owner == id then zones[zoneKey] = true end
    end
    return zones
end

-- Sets the zone types of a profile. A zone type belongs to one profile only, so it is taken
-- away from any other profile; returns the list of { zone, from } that moved.
function QSP.SetProfileZones(id, zoneKeys, layer)
    local assign = GetAssign(layer)
    local moved = {}
    for zoneKey, owner in pairs(assign) do
        if owner == id then assign[zoneKey] = nil end
    end
    for _, zoneKey in ipairs(zoneKeys) do
        local owner = assign[zoneKey]
        if owner and owner ~= id and cs.profiles[owner] then
            moved[#moved + 1] = { zone = zoneKey, from = owner }
        end
        assign[zoneKey] = id
    end
    return moved
end

--------------------------------------------------------------------------------
-- Wheel slots
--------------------------------------------------------------------------------

local function GetSlotDisplayName(slotType, id, slot)
    if slotType == ACTION_TYPE_EMOTE then
        local info = PLAYER_EMOTE_MANAGER and PLAYER_EMOTE_MANAGER:GetEmoteItemInfo(id)
        return info and info.displayName
    elseif slotType == ACTION_TYPE_QUICK_CHAT then
        return QUICK_CHAT_MANAGER and QUICK_CHAT_MANAGER:HasQuickChat(id) and QUICK_CHAT_MANAGER:GetFormattedQuickChatName(id)
    end
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetSlotName(slot, CATEGORY))
end

-- What is in a wheel slot, as stored in a profile, or false for an empty slot.
function QSP.CaptureSlot(slot)
    local slotType = GetSlotType(slot, CATEGORY)
    if slotType == ACTION_TYPE_NOTHING then return false end
    local icon = GetSlotTexture(slot, CATEGORY)
    if not icon or icon == "" then return false end
    local entry = { type = slotType, icon = icon }
    if slotType == ACTION_TYPE_ITEM then
        entry.link = GetSlotItemLink(slot, CATEGORY)
        entry.id = GetItemLinkItemId(entry.link)
    else
        entry.id = GetSlotBoundId(slot, CATEGORY)
    end
    entry.name = GetSlotDisplayName(slotType, entry.id, slot)
    return entry
end

function QSP.CaptureWheel()
    local slots = {}
    for slot = 1, NUM_SLOTS do
        slots[slot] = QSP.CaptureSlot(slot)
    end
    return slots
end

-- What tells stacks of one item id apart: quality and level, and the last field of the link,
-- which holds the effects of crafted potions and poisons (they all share a few item ids and
-- often the name, e.g. "Essence of Health" with different effects). Fields that don't
-- change what the item does (crafted, bound, stolen...) are left out.
local function ItemKey(link, itemId)
    local data = link and link:match("|H%d:item:([^|]+)|h")
    if not data then return tostring(itemId) end
    local fields = {}
    for field in data:gmatch("[^:]+") do fields[#fields + 1] = field end
    return table.concat({ fields[1] or tostring(itemId), fields[2] or "", fields[3] or "", fields[#fields] or "" }, ":")
end
QSP.ItemKey = ItemKey

local function Signature(entry)
    if not entry then return "" end
    if entry.type == ACTION_TYPE_ITEM then
        return entry.type .. ":" .. ItemKey(entry.link, entry.id)
    end
    return entry.type .. ":" .. tostring(entry.id)
end
QSP.Signature = Signature

-- Text for chat or the settings: an item or collectible link where there is one.
function QSP.DescribeEntry(entry, withIcon)
    if not entry then return "|c888888empty|r" end
    local text
    if entry.type == ACTION_TYPE_ITEM and entry.link and entry.link ~= "" then
        text = entry.link
    elseif entry.type == ACTION_TYPE_COLLECTIBLE then
        text = GetCollectibleLink(entry.id, LINK_STYLE_BRACKETS)
    end
    if not text or text == "" then text = entry.name or "?" end
    if withIcon and entry.icon then
        text = zo_iconFormat(entry.icon, 24, 24) .. " " .. text
    end
    return text
end

-- A stack of exactly the saved item (same item id, quality, level and potion effects). Only
-- if the profile has no link to compare (very old entries) any stack with the item id will
-- do: a crafted potion with other effects isn't the same potion. Reads the bag directly: the
-- shared inventory cache isn't always up to date right after a loading screen.
local function FindInBackpack(entry, slot)
    local key = entry.link and entry.link ~= "" and ItemKey(entry.link, entry.id)
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slotIndex) == entry.id and IsValidItemForSlot(BAG_BACKPACK, slotIndex, slot, CATEGORY) then
            if not key or ItemKey(GetItemLink(BAG_BACKPACK, slotIndex), entry.id) == key then
                return slotIndex
            end
        end
    end
end

-- Puts an entry into a wheel slot. Every change is a message to the server, so slots that
-- already hold the entry are left alone, and an item replaces the old one directly (no
-- ClearSlot first, like the game's own wheel). Returns false if the entry can't be placed
-- here (the item isn't in the bag, the collectible isn't unlocked...).
local function ApplyEntry(slot, entry)
    if Signature(QSP.CaptureSlot(slot)) == Signature(entry) then return true end
    if not entry then
        return CallSecureProtected("ClearSlot", slot, CATEGORY)
    end
    local slotType = entry.type
    if slotType == ACTION_TYPE_ITEM then
        local slotIndex = FindInBackpack(entry, slot)
        if not slotIndex then return false end
        return CallSecureProtected("SelectSlotItem", BAG_BACKPACK, slotIndex, slot, CATEGORY)
    end
    if slotType == ACTION_TYPE_COLLECTIBLE and not IsCollectibleUnlocked(entry.id) then return false end
    if slotType == ACTION_TYPE_QUEST_ITEM and not IsValidQuestItemForSlot(entry.id, slot, CATEGORY) then return false end
    return CallSecureProtected("SelectSlotSimpleAction", slotType, entry.id, slot, CATEGORY)
end

--------------------------------------------------------------------------------
-- Loading and saving
--------------------------------------------------------------------------------

-- What the last load couldn't place. Those slots keep the profile's entry when the profile
-- is saved, as long as the wheel slot wasn't changed since.
local lastLoad = { id = nil, missing = {}, after = {} }
local pendingAfterCombat = nil

-- options: editor (the wheel shows the profile exactly: empty and missing slots are
-- cleared), retryMs (try missing slots again after a delay before reporting), quiet (no
-- "Loaded" line).
function QSP.Load(id, options)
    options = options or {}
    EVENT_MANAGER:UnregisterForUpdate(RETRY_KEY)
    local profile = QSP.GetProfile(id)
    if not profile then return end

    if IsUnitInCombat("player") then
        pendingAfterCombat = { id = id, options = options }
        QSP.Msg("Loading " .. QSP.Hi(profile.name) .. " after combat.")
        return
    end
    pendingAfterCombat = nil

    local clearEmpty = options.editor or QSP.IsClearEmptyOn()
    local missing = {}
    for slot = 1, NUM_SLOTS do
        local entry = profile.slots[slot] or false
        if entry or clearEmpty then
            if not ApplyEntry(slot, entry) then
                missing[#missing + 1] = slot
                if options.editor then CallSecureProtected("ClearSlot", slot, CATEGORY) end
            end
        end
    end

    if #missing > 0 and options.retryMs then
        EVENT_MANAGER:RegisterForUpdate(RETRY_KEY, options.retryMs, function()
            EVENT_MANAGER:UnregisterForUpdate(RETRY_KEY)
            if cs.active == id then
                QSP.Load(id, { quiet = options.quiet })
            end
        end)
        return
    end

    lastLoad.id = id
    ZO_ClearTable(lastLoad.missing)
    ZO_ClearTable(lastLoad.after)
    local missingText = {}
    for _, slot in ipairs(missing) do
        lastLoad.missing[slot] = true
        -- What the slot holds after this load. Slot changes reach the wheel only when the
        -- server confirms them, so a cleared slot is recorded as empty right away.
        lastLoad.after[slot] = options.editor and "" or Signature(QSP.CaptureSlot(slot))
        missingText[#missingText + 1] = QSP.DescribeEntry(profile.slots[slot])
    end

    if #missing > 0 then
        local where = options.editor and "slot left empty" or "slot left as it was"
        QSP.Msg("Loaded " .. QSP.Hi(profile.name) .. ". Not available, " .. where .. ": " .. table.concat(missingText, ", "))
    elseif not options.quiet and QSP.IsChatOnLoadOn() then
        QSP.Msg("Loaded " .. QSP.Hi(profile.name) .. ".")
    end
    if QSP.Editor then QSP.Editor.OnWheelChanged() end
end

-- The wheel slot is still what the last load of this profile left there, for a slot whose
-- item couldn't be placed.
local function IsUntouchedMissing(id, slot, current)
    return lastLoad.id == id and lastLoad.missing[slot] and Signature(current) == lastLoad.after[slot]
end

-- Saves the wheel into a profile exactly as it is, empty slots included. Slots the last load
-- couldn't fill keep their entry while unchanged. Returns true if the profile changed.
function QSP.Save(id)
    local profile = QSP.GetProfile(id)
    if not profile then return false end
    local changed = false
    local new = {}
    for slot = 1, NUM_SLOTS do
        local current = QSP.CaptureSlot(slot)
        local oldEntry = profile.slots[slot] or false
        if IsUntouchedMissing(id, slot, current) then
            new[slot] = oldEntry
        else
            new[slot] = current
            if lastLoad.id == id then lastLoad.missing[slot] = nil end
        end
        if Signature(new[slot]) ~= Signature(oldEntry) then changed = true end
    end
    profile.slots = new
    return changed
end

-- Whether the wheel differs from the profile (missing items that weren't replaced don't count).
function QSP.HasUnsavedChanges(id)
    local profile = QSP.GetProfile(id)
    if not profile then return false end
    for slot = 1, NUM_SLOTS do
        local current = QSP.CaptureSlot(slot)
        if not IsUntouchedMissing(id, slot, current) and Signature(current) ~= Signature(profile.slots[slot]) then
            return true
        end
    end
    return false
end

function QSP.SwitchTo(id, options)
    cs.active = id
    QSP.Load(id, options)
end

-- Puts the current zone's profile on the wheel if it isn't there already (force: load it
-- again anyway, e.g. after restocking).
function QSP.ApplyZoneProfile(force, options)
    local id = QSP.GetProfileForZoneType(QSP.GetZoneType())
    if not id then return end
    if force or id ~= cs.active then
        QSP.SwitchTo(id, options)
    end
end

--------------------------------------------------------------------------------
-- First start: import CyroQuickslots or create the default profiles
--------------------------------------------------------------------------------

local function ImportCyroQuickslotsEntry(slotData)
    if type(slotData) ~= "table" or not slotData.itemLink or slotData.itemLink == "" then return false end
    local collectibleId = GetCollectibleIdFromLink(slotData.itemLink)
    if collectibleId and collectibleId ~= 0 then
        return { type = ACTION_TYPE_COLLECTIBLE, id = collectibleId, icon = GetCollectibleIcon(collectibleId), name = GetCollectibleName(collectibleId) }
    end
    local itemId = slotData.itemID or GetItemLinkItemId(slotData.itemLink)
    return { type = ACTION_TYPE_ITEM, id = itemId, link = slotData.itemLink, icon = GetItemLinkIcon(slotData.itemLink), name = GetItemLinkName(slotData.itemLink) }
end

local function GetCyroQuickslotsData()
    local root = CQSCharVars and CQSCharVars.Default
    local account = root and root[GetDisplayName()]
    local character = account and account[GetCurrentCharacterId()]
    if type(character) == "table" and type(character.Profiles) == "table" then return character end
end

-- New profiles that have nothing of their own start as a copy of "Everything else".
local function GetBaseSlots()
    local base = QSP.GetProfile(QSP.GetZoneTypeOwner("other"))
    return CopySlots(base and base.slots or QSP.CaptureWheel())
end

local function InitializeProfiles()
    local cqs = GetCyroQuickslotsData()
    local defaults =
    {
        { key = "PvE", name = "PvE", zone = "other" },
        { key = "Cyrodiil", name = "Cyrodiil", zone = "cyrodiil" },
        { key = "ImperialCity", name = "Imperial City", zone = "imperialCity" },
        { key = "Battlegrounds", name = "Battlegrounds", zone = "battleground" },
    }
    local ids = {}
    for _, default in ipairs(defaults) do
        local imported = cqs and cqs.Profiles[default.key]
        local slots
        if type(imported) == "table" then
            slots = {}
            for slot = 1, NUM_SLOTS do
                slots[slot] = ImportCyroQuickslotsEntry(imported[slot])
            end
        else
            slots = GetBaseSlots()
        end
        local id = QSP.CreateProfile(default.name, slots)
        GetAssign(DEFAULT_LAYER)[default.zone] = id
        ids[default.key] = id
    end

    if cqs then
        cs.active = ids[cqs.ActiveProfile] or ids.PvE
        QSP.cqsWarned = true
        QSP.Msg("Imported this character's CyroQuickslots profiles. Disable CyroQuickslots, both would swap the quickslots.")
    else
        cs.active = QSP.GetProfileForZoneType(QSP.GetZoneType())
    end
    cs.initialized = true
    cs.schema = SCHEMA
end

local function MigrateProfiles()
    if cs.schema < 2 then
        -- Zone types were still kept on the profiles (profile.zones) here.
        local base, hasBattlegrounds
        for _, id in ipairs(cs.order) do
            local zones = cs.profiles[id].zones or {}
            if zones.other then base = cs.profiles[id] end
            if zones.battleground then hasBattlegrounds = true end
        end
        local baseSlots = function() return CopySlots(base and base.slots or QSP.CaptureWheel()) end
        for _, id in ipairs(cs.order) do
            local profile = cs.profiles[id]
            if not profile.slots then profile.slots = baseSlots() end
        end
        if not hasBattlegrounds then
            local id = QSP.CreateProfile("Battlegrounds", baseSlots())
            cs.profiles[id].zones = { battleground = true }
            QSP.Msg("Added a " .. QSP.Hi(QSP.ProfileName(id)) .. " profile (a copy of your Everything else profile). "
                .. "Edit it in the inventory's Quickslots tab.")
        end
    end
    if cs.schema < 3 then
        -- Zone types move from the profiles to the "Default" set. If two profiles had the
        -- same zone type, the first one in the list had it, as before.
        local assign = {}
        for _, id in ipairs(cs.order) do
            local profile = cs.profiles[id]
            for zoneKey in pairs(profile.zones or {}) do
                if assign[zoneKey] == nil then assign[zoneKey] = id end
            end
            profile.zones = nil
        end
        cs.assign = { [DEFAULT_LAYER] = assign }
    end
    cs.schema = SCHEMA
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local function OnPlayerActivated()
    if not cs.initialized then
        InitializeProfiles()
    else
        MigrateProfiles()
        if GetCyroQuickslotsData() and not QSP.cqsWarned then
            QSP.cqsWarned = true
            QSP.Msg("|cFF6666CyroQuickslots is enabled too.|r Disable it, both would swap the quickslots.")
        end
    end
    QSP.ApplyZoneProfile(false, { retryMs = LOAD_RETRY_MS })
end

-- A build restored or saved at the Armory is the one in use from now on. The first time,
-- "Default" becomes that build's set and the other builds start with a copy of it.
local function OnArmoryBuildUsed(buildIndex)
    if not buildIndex or buildIndex < 1 then return end
    local layer = BuildLayer(buildIndex)
    if not cs.armory.unlocked then
        local default = cs.assign[DEFAULT_LAYER] or {}
        cs.assign = { [layer] = default }
        for i = 1, QSP.GetNumBuilds() do
            if i ~= buildIndex then cs.assign[BuildLayer(i)] = ZO_ShallowTableCopy(default) end
        end
        cs.armory.unlocked = true
        cs.armory.current = buildIndex
        QSP.Msg("Zone types are now set per Armory build. " .. QSP.Hi(QSP.GetBuildName(buildIndex))
            .. " keeps them as they were, the other builds start with a copy.")
    else
        GetAssign(layer, QSP.GetCurrentLayer())
        cs.armory.current = buildIndex
    end
    if QSP.Editor then QSP.Editor.OnBuildChanged() end
    QSP.RefreshSettings()
    QSP.ApplyZoneProfile(false)
end

local function OnArmoryRestore(_, result, buildIndex)
    if result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS then OnArmoryBuildUsed(buildIndex) end
end

local function OnArmorySave(_, result, buildIndex)
    if result == ARMORY_BUILD_SAVE_RESULT_SUCCESS then OnArmoryBuildUsed(buildIndex) end
end

local function OnCombatState(_, inCombat)
    if not inCombat and pendingAfterCombat then
        local pending = pendingAfterCombat
        pendingAfterCombat = nil
        if pending.id == cs.active or (QSP.Editor and QSP.Editor.IsEditing(pending.id)) then
            QSP.Load(pending.id, pending.options)
        end
    end
end

--------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(QSP.NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= QSP.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(QSP.NAME, EVENT_ADD_ON_LOADED)

    cs = ZO_SavedVars:NewCharacterIdSettings("QuickslotProfiles_SV", 1, nil, charDefaults)
    as = ZO_SavedVars:NewAccountWide("QuickslotProfiles_SV", 1, "Settings", accountDefaults)
    as.autosave = nil -- 1.0 option, removed

    EVENT_MANAGER:RegisterForEvent(QSP.NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(QSP.NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(QSP.NAME, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, OnArmoryRestore)
    EVENT_MANAGER:RegisterForEvent(QSP.NAME, EVENT_ARMORY_BUILD_SAVE_RESPONSE, OnArmorySave)
    SLASH_COMMANDS["/qsp"] = function() QSP.OpenSettings() end

    QSP.Editor.Initialize()
    QSP.InitializeSettings()
end)
