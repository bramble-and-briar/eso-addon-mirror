-- WhatDropsHere.lua
-- Main logic of the addon (recording, categories, debug output)
--
-- Flow of a loot session:
--   1. EVENT_LOOT_UPDATED (first)   -> remember the source (GetLootTargetInfo), read the list
--   2. EVENT_LOOT_UPDATED (further) -> only add new lootIds
--      (auto-loot addons take items, the list gets shorter, the event fires again)
--   3. EVENT_LOOT_CLOSED            -> write the session to SV
--   4. EVENT_LOOT_RECEIVED          -> leads (antiquities), pickpocketing and
--                                      loot without a loot window (see below)
--
-- Loot without a loot window: critters (butterflies, jellyfish, moths ...) and single
-- items go straight into the inventory with "Take". The source is remembered
-- when the interact key is pressed (hook on INTERACTIVE_WHEEL_MANAGER:StartInteraction,
-- which keyboard and gamepad call before GameCameraInteractStart according to bindings.xml).
-- All items arriving shortly afterwards form one session.
--
-- What gets recorded is what the source OFFERED, not what was taken.
-- This way the filters of auto-loot addons (MSAL, Smarter AutoLoot) do not skew the statistics.
--
-- Exception leads: the loot window has no antiquity ID for leads.
-- It only comes with EVENT_LOOT_RECEIVED (itemId = antiquityId). Leads are therefore
-- skipped in the loot window and assigned to the running or last session on receipt.
--
-- Data model (per server and account):
--   WhatDropsHere_Saved[GetWorldName()][GetDisplayName()] = SV
--   SV.zones[zoneId][key] = source
--     zoneId 0      = containers from the inventory (same everywhere)
--     key           = lower-case name, "#aoe" for collective (AoE) loot,
--                     "pickpocket:" for pickpocketing
--   source = { name, kind, loots, gold, targetType, last, type, collective, digs, sets = {}, items = {}, cats = {} }
--     collective = collective record (stolen loose items of the zone, key LOOSE_THEFT_KEY)
--     digs       = { [antiquityId] = count } for dig sites (the antiquity itself is not counted as loot)
--     items[itemId] = Stat + cat (every find; "lead:<antiquityId>" or "n:<name>" for non-items)
--     cats[key]     = Stat (category key from WDH_Categories.lua, all finds of the category)
--     sets[setId]   = Stat + slots[slot] = count (set gear, additionally per set)
--   Whether something is shown by name or as category is decided by the display only.
--   Stat = { n = total count, hits = loots with a hit, min, max, q = { [quality] = count } }

local ADDON_NAME         = "WhatDropsHere"
local SAVED_VERSION      = 3  -- 2: every find with item ID, threshold only for the display
                              -- 3: items lying around are no longer sources of their own
local LOOSE_THEFT_KEY    = "#loose#theft"  -- collective record per zone for stolen loose items without a loot window
local RECEIVED_GRACE_MS  = 2000  -- ms after LOOT_CLOSED in which LOOT_RECEIVED still belongs to the session
local SESSION_TIMEOUT_MS = 5000  -- ms without LOOT_UPDATED after which a session without LOOT_CLOSED is saved
local INTERACT_VALID_MS  = 3000  -- ms after the interaction in which loot without a loot window is assigned to it
local DIRECT_COMMIT_MS   = 1000  -- ms after the last item after which a session without a loot window is saved
local INTERACT_POLL_MS   = 100   -- poll interval for the interaction type after pressing E

-- -----------------------------------------------------------------------------
-- Addon object
-- -----------------------------------------------------------------------------
-- WhatDropsHere is the addon's only global variable (created in lang/en.lua)
local WDH = WhatDropsHere
WDH.VERSION = "0.4.0-beta"  -- same as "## Version" in the manifest
local CAT = WDH.Categories
local WDH_STRINGS, WDH_SLOT_NAMES, WDH_CAT_NAMES = WDH.L, WDH.SLOT_NAMES, WDH.CAT_NAMES

-- Threshold per source type: display off for this type
local SHOW_OFF = -1

-- Account-wide settings
local DEFAULT_ACCOUNT = {
    debug         = false,                        -- debug output in chat (/wdh_debug, menu)
}

-- Display settings, stored per character (everything is always recorded)
local DEFAULT_DISPLAY = {
    hud           = true,                         -- crosshair display
    hudUnits      = true,                         -- also for living targets (enemies, animals, NPCs)
    nameQuality   = ITEM_DISPLAY_QUALITY_ARCANE,  -- at the crosshair by name from blue up, below that as category
    hudMaxLines   = 6,                            -- entries at the crosshair, the rest as "+N more"
    -- display threshold per source type (quality or SHOW_OFF); from white = trash hidden
    showEnemy     = ITEM_DISPLAY_QUALITY_NORMAL,  -- enemies: corpses and living targets
    showContainer = ITEM_DISPLAY_QUALITY_NORMAL,  -- chests and containers
    showResource  = ITEM_DISPLAY_QUALITY_NORMAL,  -- resource nodes
    showOther     = ITEM_DISPLAY_QUALITY_NORMAL,  -- critters, loose items, other
    showTheft     = ITEM_DISPLAY_QUALITY_NORMAL,  -- theft from someone else's property
    showExcavation = ITEM_DISPLAY_QUALITY_NORMAL, -- dig sites (bonus loot)
}

-- All thresholds per type (for /wdh_show)
local TYPE_THRESHOLDS = { "showEnemy", "showContainer", "showResource", "showOther", "showTheft", "showExcavation" }

-- Up to 0.2: one switch per type + one shared threshold (account-wide)
local LEGACY_TYPE_SWITCH = {
    showEnemy     = "hudEnemies",
    showContainer = "hudContainers",
    showResource  = "hudResources",
    showOther     = "hudOther",
    showTheft     = "hudTheft",
}

local function FillDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
    end
end

local function CopyDisplay(source)
    local copy = {}
    for k in pairs(DEFAULT_DISPLAY) do copy[k] = source[k] end
    FillDefaults(copy, DEFAULT_DISPLAY)
    return copy
end

-- -----------------------------------------------------------------------------
-- Internal state
-- -----------------------------------------------------------------------------

-- Saved data of this account on this server (part of WhatDropsHere_Saved, see OpenSaved)
local SV = nil

-- Running loot session (nil if no loot window is open)
local WDH_Session = nil

-- Finished loot window that was already empty when we could read it:
-- an auto-loot addon (e.g. Much Smarter AutoLoot) was faster, took everything and closed the
-- window. The loot still arrives afterwards through LOOT_RECEIVED or CURRENCY_UPDATE
-- and is collected here before the session is saved.
local WDH_Pending = nil

-- Last saved source, for late leads and /wdh without an argument
local WDH_Last = {
    zoneId   = nil,
    key      = nil,
    closedAt = 0,
    itemIds  = {},  -- item IDs of the last loot list, to match a later LOOT_RECEIVED
    lootKey  = nil, -- key and lootIds of the last session, to detect the same source being
    lootSeen = nil, -- reopened (leftovers an auto-loot addon leaves behind)
}

-- Last interaction (E key / gamepad), source for loot without a loot window,
-- plus what tells the source type (see DetermineSourceType)
local WDH_Interact = {
    name    = nil,
    action  = nil,
    at      = 0,
    monster = false,  -- IsGameCameraInteractableUnitMonster(): corpse of a creature/NPC
    owned   = false,  -- belongs to someone (theft), from GetGameCameraInteractableActionInfo()
    itype   = nil,    -- first GetInteractionType() after the interaction (e.g. INTERACTION_HARVEST)
}

-- Running session without a loot window (critters, loose items)
local WDH_Direct = nil

local WDH_Initialized = false

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function dbg(msg)
    if not SV or not SV.settings.debug then return end
    d(WDH_STRINGS.DEBUG_PREFIX .. msg)
end

local function Now()
    return GetGameTimeMilliseconds()
end

local function CurrentZoneId()
    return GetZoneId(GetUnitZoneIndex("player"))
end

local function ZoneName(zoneId)
    if zoneId == 0 then return WDH_STRINGS.ZONE_ANYWHERE end
    return zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
end

-- Format the source name as in the loot window (removes e.g. gender suffixes like ^n)
local function FormatTargetName(name, targetType)
    if name == nil or name == "" then return "" end
    if targetType == INTERACT_TARGET_TYPE_ITEM then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
    elseif targetType == INTERACT_TARGET_TYPE_OBJECT then
        return zo_strformat(SI_LOOT_OBJECT_NAME, name)
    elseif targetType == INTERACT_TARGET_TYPE_FIXTURE then
        return zo_strformat(SI_TOOLTIP_FIXTURE_INSTANCE, name)
    end
    return zo_strformat("<<C:1>>", name)
end

local function MakeKey(name)
    return zo_strlower(name)
end

-- Whether the loot window combines several corpses (AoE loot).
-- INTERACT_TARGET_TYPE_AOE_LOOT is an assumption; if the constant does not exist,
-- the result stays false. The debug output shows targetType for checking in game.
local function IsAoeTarget(targetType)
    return INTERACT_TARGET_TYPE_AOE_LOOT ~= nil and targetType == INTERACT_TARGET_TYPE_AOE_LOOT
end

local function IsAoeSettingOn()
    return GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AOE_LOOT) == "1"
end

local function QualityName(quality)
    return GetString("SI_ITEMDISPLAYQUALITY", quality)
end

local function ColorByQuality(quality, text)
    return GetItemQualityColor(quality):Colorize(text)
end

local function CatName(key)
    return WDH_CAT_NAMES[key] or key
end

local function SetName(setId)
    local name = GetItemSetName and GetItemSetName(setId) or ""
    if name == "" then return string.format(WDH_STRINGS.SET_UNKNOWN, setId) end
    return zo_strformat("<<C:1>>", name)
end

-- Display name for an items key (item ID, "lead:<id>" or "n:<name>")
local function ItemLinkFromId(itemId)
    return string.format("|H1:item:%d:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

local function ItemName(id)
    if type(id) == "number" then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(ItemLinkFromId(id)))
    end
    local leadId = id:match("^lead:(%d+)$")
    if leadId then
        -- Mark as lead: the name is the antiquity's, which still has to be excavated
        return string.format(WDH_STRINGS.LEAD_NAME,
            zo_strformat(SI_TOOLTIP_ITEM_NAME, GetAntiquityName(tonumber(leadId))))
    end
    return (id:gsub("^n:", ""))
end

-- -----------------------------------------------------------------------------
-- Statistics building blocks
-- -----------------------------------------------------------------------------

-- Adds a quantity to a session statistic. cat = category (items only)
local function AddStat(t, id, quantity, quality, cat)
    local s = t[id]
    if not s then
        s = { n = 0, q = {}, cat = cat }
        t[id] = s
    end
    s.n = s.n + quantity
    s.q[quality] = (s.q[quality] or 0) + quantity
    return s
end

-- Merges a session statistic into the stored statistic
local function MergeStat(dst, id, src)
    local s = dst[id]
    if not s then
        s = { n = 0, hits = 0, max = 0, q = {} }
        dst[id] = s
    end
    s.n    = s.n + src.n
    s.hits = s.hits + 1
    s.cat  = src.cat or s.cat
    s.min  = s.min and math.min(s.min, src.n) or src.n
    s.max  = math.max(s.max, src.n)
    for quality, count in pairs(src.q) do
        s.q[quality] = (s.q[quality] or 0) + count
    end
    if src.slots then
        s.slots = s.slots or {}
        for slot, count in pairs(src.slots) do
            s.slots[slot] = (s.slots[slot] or 0) + count
        end
    end
end

-- -----------------------------------------------------------------------------
-- Storage
-- -----------------------------------------------------------------------------

-- Display name of a source; collective records in the client language
local function RecordName(rec)
    if rec.collective then return WDH_STRINGS.RECORD_LOOSE end
    return rec.name
end

local function GetRecord(zoneId, key, name, kind)
    local zones = SV.zones
    zones[zoneId] = zones[zoneId] or {}
    local rec = zones[zoneId][key]
    if not rec then
        rec = { name = name, kind = kind, loots = 0, gold = 0, sets = {}, items = {}, cats = {} }
        zones[zoneId][key] = rec
    end
    return rec
end

local function FindRecord(zoneId, key)
    local zone = SV.zones[zoneId]
    return zone and zone[key]
end

-- -----------------------------------------------------------------------------
-- Source type (only for the display filters, everything is always recorded)
-- -----------------------------------------------------------------------------
--   enemy     -> corpse of a creature/NPC (IsGameCameraInteractableUnitMonster, like ZO_PlayLootWindowSound)
--   resource  -> resource node (GetInteractionType() == INTERACTION_HARVEST shortly after the interaction,
--                like HarvestMap)
--   container -> chests, sacks, barrels, crates, backpacks ... (all other loot windows)
--   theft     -> theft from someone else's property (isOwned): containers, safeboxes, loose items
--   other     -> pickpocketing and "Take" without a loot window (critters, loose items)
--   excavation -> dig sites (bonus loot of the excavation, without the antiquity itself)

local function IsRecentInteraction(name)
    return WDH_Interact.name == name and Now() - WDH_Interact.at <= INTERACT_VALID_MS
end

local function DetermineSourceType(name, kind)
    if kind == "dig" then return "excavation" end
    local recent = IsRecentInteraction(name)
    if recent and WDH_Interact.itype == INTERACTION_HARVEST then return "resource" end
    if kind == "pickpocket" then return "other" end
    if kind == "theft" then return "theft" end
    -- With loot windows the corpse is still the camera target (the game uses this for the loot sound too)
    if (kind == "loot" and IsGameCameraInteractableUnitMonster()) or (recent and WDH_Interact.monster) then
        return "enemy"
    end
    if kind == "take" then return "other" end
    return "container"
end

-- -----------------------------------------------------------------------------
-- Session
-- -----------------------------------------------------------------------------

-- Key of a source: lower-case name, theft from someone else's property kept separate.
-- Also used by the display (target at the crosshair with isOwned).
local function RecordKey(name, isOwned)
    local key = MakeKey(name)
    if isOwned then key = key .. "#theft" end
    return key
end

-- kind: "loot" (loot window), "take" ("Take" without a window), "pickpocket", "dig" (excavation)
-- isOwned: source belongs to someone (theft) -> separate record
local function NewSession(name, targetType, kind, isOwned)
    local fromWindow = kind == "loot"
    if isOwned and kind ~= "pickpocket" then kind = "theft" end
    local sourceType = DetermineSourceType(name, kind)
    local zoneId = (targetType == INTERACT_TARGET_TYPE_ITEM) and 0 or CurrentZoneId()
    local aoe    = IsAoeTarget(targetType)
    local key    = RecordKey(name, kind == "theft")
    if kind == "pickpocket" then
        key = "pickpocket:" .. key
    elseif aoe then
        kind = "aoe"
        key  = key .. "#aoe"
    end
    return {
        name       = name,
        key        = key,
        kind       = kind,
        fromWindow = fromWindow,
        sourceType = sourceType,
        zoneId     = zoneId,
        targetType = targetType,
        aoe        = aoe,
        startedAt  = Now(),
        gold       = 0,
        seen       = {},
        itemIds    = {},  -- offered item IDs (to match LOOT_RECEIVED)
        sets       = {},
        items      = {},
        cats       = {},
        lines      = {},  -- debug lines, printed when the session is finished
    }
end

-- Adds an item to the session. The item (item ID) and its category are always
-- stored, for set gear also the set.
-- Which of it is shown by name is decided by the display only.
local function AddItem(session, itemLink, quantity)
    local entry = CAT.Classify(itemLink)
    local quality = entry.quality
    session.itemIds[entry.itemId] = true

    AddStat(session.items, entry.itemId, quantity, quality, entry.key)
    AddStat(session.cats, entry.key, quantity, quality)
    if entry.setId then
        local s = AddStat(session.sets, entry.setId, quantity, quality)
        s.slots = s.slots or {}
        s.slots[entry.slot] = (s.slots[entry.slot] or 0) + quantity
    end

    session.lines[#session.lines + 1] = string.format(WDH_STRINGS.DEBUG_ITEM,
        itemLink, quantity, CatName(entry.key))
end

-- Entry without an item ID (lead, collectible): id = "lead:<id>" or "n:<name>"
local function AddNonItem(session, id, quantity, quality, cat)
    AddStat(session.items, id, quantity, quality, cat)
    AddStat(session.cats, cat, quantity, quality)
    session.lines[#session.lines + 1] = string.format(WDH_STRINGS.DEBUG_ITEM,
        ItemName(id), quantity, CatName(cat))
end

local function AddLead(session, antiquityId)
    AddNonItem(session, "lead:" .. antiquityId, 1, GetAntiquityQuality(antiquityId), "LEAD")
end

-- Gold in the loot window, own and stolen together.
-- Same source as Much Smarter AutoLoot (LOOT_SHARED), GetLootCurrency only as fallback.
local function ReadLootGold()
    if LOOT_SHARED and LOOT_SHARED.GetLootCurrencyInformation then
        local info = LOOT_SHARED:GetLootCurrencyInformation()[CURT_MONEY]
        if not info then return 0 end
        return (info.currencyAmount or 0) + (info.stolenCurrencyAmount or 0)
    end
    local unowned, owned = GetLootCurrency(CURT_MONEY)
    return (unowned or 0) + (owned or 0)
end

local function ReadLootList(session)
    for i = 1, GetNumLootItems() do
        local lootId, name, _, count, _, _, isQuest, _, lootType = GetLootItemInfo(i)
        if lootId and session.prevSeen and session.prevSeen[lootId] then
            -- Already offered when this source was last opened (leftovers)
            session.seen[lootId] = true
            session.reopened     = true
        elseif lootId and not session.seen[lootId] then
            session.seen[lootId] = true
            -- Quest items belong to the quest, not to the source.
            -- Leads arrive with their antiquity ID through EVENT_LOOT_RECEIVED.
            local skip = isQuest or lootType == LOOT_TYPE_QUEST_ITEM or lootType == LOOT_TYPE_ANTIQUITY_LEAD
            if not skip then
                local itemLink = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
                if itemLink and itemLink ~= "" then
                    AddItem(session, itemLink, count)
                else
                    -- Not an item (e.g. collectible): store by name
                    AddNonItem(session, "n:" .. zo_strformat("<<C:1>>", name), count,
                        ITEM_DISPLAY_QUALITY_NORMAL, "NO_ITEM")
                end
            end
        end
    end

    -- Gold: remember the highest value seen (after looting it reads 0).
    -- For a reopened source, leftover gold has already been counted.
    if not session.reopened then
        local gold = ReadLootGold()
        if gold > session.gold then session.gold = gold end
    end
end

-- Did a reopened source offer nothing new?
local function IsPureReopen(session)
    return session.reopened and next(session.itemIds) == nil and next(session.items) == nil
        and next(session.cats) == nil and next(session.sets) == nil
end

local function CommitSession(session)
    if session.name == "" then
        dbg(WDH_STRINGS.DEBUG_NO_NAME)
        for _, line in ipairs(session.lines) do dbg(line) end
        return
    end

    -- Remember the lootIds seen, so that reopening the same source is detected
    -- (loot windows only; pickpocketing and "Take" without a window have no lootIds)
    if session.fromWindow then
        WDH_Last.lootKey  = session.key
        WDH_Last.lootSeen = session.seen
    end

    if IsPureReopen(session) then
        WDH_Last.closedAt = Now()
        dbg(string.format(WDH_STRINGS.DEBUG_REOPEN, session.name))
        return
    end

    local rec = GetRecord(session.zoneId, session.key, session.name, session.kind)
    if session.collective then rec.collective = true end
    rec.loots      = rec.loots + 1
    rec.gold       = rec.gold + session.gold
    rec.targetType = session.targetType
    -- "container" is the fallback when nothing more specific was detected:
    -- a type detected once (enemy, resource) is not overwritten by it
    if session.sourceType ~= "container" or rec.type == nil then
        rec.type = session.sourceType
    end
    rec.last       = GetTimeStamp()
    -- Excavation: the antiquity dug up (not counted as loot)
    if session.antiquityId then
        rec.digs = rec.digs or {}
        rec.digs[session.antiquityId] = (rec.digs[session.antiquityId] or 0) + 1
    end

    for id, s in pairs(session.sets)  do MergeStat(rec.sets,  id, s) end
    for id, s in pairs(session.items) do MergeStat(rec.items, id, s) end
    for id, s in pairs(session.cats)  do MergeStat(rec.cats,  id, s) end

    WDH_Last.zoneId   = session.zoneId
    WDH_Last.key      = session.key
    -- Grace period only for loot windows: loot without a window (stealing several items from a
    -- table, pickpocketing) does not arrive late and must not swallow the next one
    if session.fromWindow then
        WDH_Last.closedAt = Now()
        WDH_Last.itemIds  = session.itemIds
    end
    -- Remember for /wdh without an argument, also across restarts
    SV.last = { zoneId = session.zoneId, key = session.key }

    dbg(string.format(WDH_STRINGS.DEBUG_SESSION,
        session.name, ZoneName(session.zoneId), tostring(session.targetType),
        tostring(session.aoe), tostring(IsAoeSettingOn()), session.gold, tostring(session.sourceType)))
    for _, line in ipairs(session.lines) do dbg(line) end

    -- Rebuild the crosshair display on the next frame
    if WDH.Hud then WDH.Hud:Invalidate() end
end

-- Assign a lead that arrives after the loot window closed
local function AddLeadToLastRecord(antiquityId)
    local rec = WDH_Last.key and FindRecord(WDH_Last.zoneId, WDH_Last.key)
    if not rec then return false end
    local quality = GetAntiquityQuality(antiquityId)
    MergeStat(rec.items, "lead:" .. antiquityId, { n = 1, q = { [quality] = 1 }, cat = "LEAD" })
    MergeStat(rec.cats, "LEAD", { n = 1, q = { [quality] = 1 } })
    dbg(string.format(WDH_STRINGS.DEBUG_ITEM, ItemName("lead:" .. antiquityId), 1, rec.name))
    return true
end

-- -----------------------------------------------------------------------------
-- Event-Handler
-- -----------------------------------------------------------------------------

-- Session that takes loot from LOOT_RECEIVED/CURRENCY_UPDATE (only for a window found empty)
local function LateTarget()
    if WDH_Session then
        return WDH_Session.emptyWindow and WDH_Session or nil
    end
    return WDH_Pending
end

-- Gold changes are only needed while such a session exists:
-- EVENT_MONEY_UPDATE is only registered then (otherwise it would run on every purchase, sale, repair ...)
local OnMoneyUpdate  -- defined below
local moneyWatched = false
local function UpdateMoneyWatch()
    local needed = LateTarget() ~= nil
    if needed == moneyWatched then return end
    moneyWatched = needed
    if needed then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Money", EVENT_MONEY_UPDATE, OnMoneyUpdate)
    else
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Money", EVENT_MONEY_UPDATE)
    end
end

-- Save the running session (LOOT_CLOSED, timeout, loading screen)
local function FinishPending()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Pending")
    if not WDH_Pending then return end
    local session = WDH_Pending
    WDH_Pending = nil
    CommitSession(session)
    UpdateMoneyWatch()
end

local function FinishSession()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_SessionTimeout")
    if not WDH_Session then return end
    local session = WDH_Session
    WDH_Session = nil
    if session.emptyWindow then
        -- Loot is still on its way: collect briefly, then save
        FinishPending()
        WDH_Pending = session
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Pending", RECEIVED_GRACE_MS, FinishPending)
    else
        CommitSession(session)
    end
    UpdateMoneyWatch()
end

-- In tests LOOT_CLOSED did not always arrive (probably when an auto-loot addon closes the window).
-- Without this safeguard the session would stay open until the next loot
-- and would be lost on /reloadui.
-- If the loot window is still visible, the session goes on (otherwise double counting
-- when another LOOT_UPDATED for the same source follows).
local function IsLootWindowShowing()
    return SCENE_MANAGER:IsShowing("loot") or SCENE_MANAGER:IsShowing("lootGamepad")
end

local function ArmSessionTimeout()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_SessionTimeout")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_SessionTimeout", SESSION_TIMEOUT_MS, function()
        if IsLootWindowShowing() then return end
        dbg(WDH_STRINGS.DEBUG_TIMEOUT)
        FinishSession()
    end)
end

local function OnLootUpdated()
    local rawName, targetType, _, isOwned = GetLootTargetInfo()
    local name = FormatTargetName(rawName, targetType)

    -- Some containers give no name in the loot window (e.g. the Dark Anchor chest).
    -- If there was no new interaction since the open session started, it is the same window
    -- (e.g. update after taking an item); otherwise use the last interaction.
    if name == "" then
        local recent = WDH_Interact.name and Now() - WDH_Interact.at <= INTERACT_VALID_MS
        if WDH_Session and not (recent and WDH_Interact.at > WDH_Session.startedAt) then
            name = WDH_Session.name
        elseif recent then
            name = WDH_Interact.name
        end
    end

    if WDH_Session and WDH_Session.name ~= name then
        dbg(WDH_STRINGS.DEBUG_NEW_TARGET)
        FinishSession()
    end
    if not WDH_Session then
        FinishPending()
        WDH_Session = NewSession(name, targetType, "loot", isOwned)
        -- Window without target and content: an auto-loot addon emptied and closed it before us
        if rawName == "" and GetNumLootItems() == 0 then
            WDH_Session.emptyWindow = true
            WDH_Session.lines[#WDH_Session.lines + 1] = WDH_STRINGS.DEBUG_LATE
        end
        -- Same source as last time: do not count leftovers again
        if WDH_Last.lootKey == WDH_Session.key then
            WDH_Session.prevSeen = WDH_Last.lootSeen
        end
    end
    ReadLootList(WDH_Session)
    if WDH_Session.emptyWindow and (next(WDH_Session.seen) or WDH_Session.gold > 0) then
        WDH_Session.emptyWindow = false
    end
    UpdateMoneyWatch()
    ArmSessionTimeout()
end

local function OnLootClosed()
    FinishSession()
end

-- Item lying around ("Take" without a window): weapon/armor (the interaction is called e.g. "Shield",
-- the item "Nightwood Shield") or an item named like the source. Critters give other loot.
local function IsLooseItem(itemLink, sourceName)
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then return true end
    return MakeKey(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))) == MakeKey(sourceName)
end

local function FinishDirectSession()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DirectCommit")
    local session = WDH_Direct
    if not session then return end
    WDH_Direct = nil
    if session.kind == "theft" then
        -- Stolen loose items: one collective record per zone instead of one source per item
        session.key        = LOOSE_THEFT_KEY
        session.name       = WDH_STRINGS.RECORD_LOOSE
        session.collective = true
    elseif session.loose then
        -- Weapons/armor lying around in the open world: trash, do not store
        dbg(string.format(WDH_STRINGS.DEBUG_LOOSE_IGNORED, session.name))
        for _, line in ipairs(session.lines) do dbg(line) end
        return
    end
    CommitSession(session)
end

-- Assign loot without a loot window to the last interaction.
-- Returns false if there is no matching interaction.
local function AddDirectLoot(itemLink, quantity)
    if not WDH_Interact.name or Now() - WDH_Interact.at > INTERACT_VALID_MS then
        return false
    end
    -- New interaction since the running session: save the old one first
    if WDH_Direct and WDH_Direct.interactAt ~= WDH_Interact.at then
        FinishDirectSession()
    end
    if not WDH_Direct then
        WDH_Direct = NewSession(WDH_Interact.name, nil, "take", WDH_Interact.owned)
        WDH_Direct.interactAt = WDH_Interact.at
    end
    WDH_Direct.loose = WDH_Direct.loose ~= false and IsLooseItem(itemLink, WDH_Direct.name)
    AddItem(WDH_Direct, itemLink, quantity)

    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DirectCommit")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_DirectCommit", DIRECT_COMMIT_MS, FinishDirectSession)
    return true
end

-- After the interaction, briefly watch which kind of interaction the game starts
-- (harvesting, lockpicking ...). The loot window itself (INTERACTION_LOOT) does not count.
local function PollInteractionType()
    local itype = GetInteractionType()
    if itype ~= INTERACTION_NONE and itype ~= INTERACTION_LOOT and not WDH_Interact.itype then
        WDH_Interact.itype = itype
    end
    if WDH_Interact.itype or Now() - WDH_Interact.at > INTERACT_VALID_MS then
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_InteractType")
    end
end

local function OnInteractionStart()
    local action, name, _, isOwned = GetGameCameraInteractableActionInfo()
    if not name or name == "" then return end
    WDH_Interact.name    = zo_strformat("<<C:1>>", name)
    WDH_Interact.action  = action
    WDH_Interact.at      = Now()
    WDH_Interact.monster = IsGameCameraInteractableUnitMonster()
    WDH_Interact.owned   = isOwned == true
    WDH_Interact.itype   = nil
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_InteractType")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_InteractType", INTERACT_POLL_MS, PollInteractionType)
    dbg(string.format(WDH_STRINGS.DEBUG_INTERACT, tostring(action), WDH_Interact.name))
end

-- -----------------------------------------------------------------------------
-- Excavations
-- Excavation loot does not come through EVENT_LOOT_RECEIVED (test 2026-11-17), and the list
-- of the summary screen (GetDigSpotBonusLootRewardInfo) is not available to addons.
-- Therefore: whatever goes into the inventory or craft bag, is added as gold or acquired as a lead
-- between start and exit of the excavation (plus a short grace period) is its bonus loot.
-- The antiquity itself is certain through the lead and not bonus loot: not counted (nor its
-- reward, e.g. a furnishing), only its ID in rec.digs.
-- Only successful excavations count.
-- The events are only registered during an excavation.
-- -----------------------------------------------------------------------------

local DIG_NAME_VALID_MS = 30000  -- "Excavate" interaction until the excavation starts (3.8 s in the test)
local DIG_GRACE_MS      = 2000   -- grace period after leaving the excavation

local DigSession = nil
local OnDigItem, OnDigGold, OnDigLead  -- defined below

local function SetDigWatch(on)
    local ns = ADDON_NAME .. "_DigLoot"
    EVENT_MANAGER:UnregisterForEvent(ns .. "Bag",   EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(ns .. "Craft", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(ns .. "Gold",  EVENT_MONEY_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(ns .. "Lead",  EVENT_ANTIQUITY_LEAD_ACQUIRED)
    if not on then return end
    for suffix, bag in pairs({ Bag = BAG_BACKPACK, Craft = BAG_VIRTUAL }) do
        EVENT_MANAGER:RegisterForEvent(ns .. suffix, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnDigItem)
        EVENT_MANAGER:AddFilterForEvent(ns .. suffix, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            REGISTER_FILTER_BAG_ID, bag,
            REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    end
    EVENT_MANAGER:RegisterForEvent(ns .. "Gold", EVENT_MONEY_UPDATE, OnDigGold)
    EVENT_MANAGER:RegisterForEvent(ns .. "Lead", EVENT_ANTIQUITY_LEAD_ACQUIRED, OnDigLead)
end

-- Item ID the antiquity itself gives as reward (not counted as bonus loot)
local function AntiquityRewardItemId(antiquityId)
    local rewardId = GetAntiquityRewardId(antiquityId)
    if rewardId and rewardId ~= 0 and GetRewardType(rewardId) == REWARD_ENTRY_TYPE_ITEM then
        return GetItemRewardItemId(rewardId)
    end
end

function OnDigItem(_, bagId, slotIndex, _, _, _, stackCountChange)
    if not DigSession or not stackCountChange or stackCountChange <= 0 then return end
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink == "" then return end
    if GetItemLinkItemId(itemLink) == DigSession.rewardItemId then
        dbg(string.format(WDH_STRINGS.DEBUG_DIG_REWARD, itemLink))
        return
    end
    AddItem(DigSession, itemLink, stackCountChange)
end

function OnDigGold(_, newMoney, oldMoney)
    if DigSession and newMoney > oldMoney then
        DigSession.gold = DigSession.gold + (newMoney - oldMoney)
    end
end

function OnDigLead(_, antiquityId)
    if DigSession then AddLead(DigSession, antiquityId) end
end

local function FinishDig()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DigFinish")
    SetDigWatch(false)
    local session = DigSession
    DigSession = nil
    if not session then return end
    if not session.victory then
        dbg(string.format(WDH_STRINGS.DEBUG_DIG_FAILED, tostring(session.gameOverFlags)))
        for _, line in ipairs(session.lines) do dbg(line) end
        return
    end
    CommitSession(session)
end

local function OnDigReady()
    FinishDig()  -- previous excavation, in case its end never arrived
    local name = WDH_Interact.name
    if not name or Now() - WDH_Interact.at > DIG_NAME_VALID_MS then name = WDH_STRINGS.DIG_SITE end
    local antiquityId = GetDigSpotAntiquityId()
    DigSession = NewSession(name, nil, "dig")
    DigSession.antiquityId  = antiquityId
    DigSession.rewardItemId = AntiquityRewardItemId(antiquityId)
    SetDigWatch(true)
    dbg(string.format(WDH_STRINGS.DEBUG_DIG_START, name,
        zo_strformat(SI_TOOLTIP_ITEM_NAME, GetAntiquityName(antiquityId))))
end

local function OnDigGameOver(_, gameOverFlags)
    if not DigSession then return end
    DigSession.victory       = gameOverFlags == ANTIQUITY_DIGGING_GAME_OVER_FLAGS_VICTORY
    DigSession.gameOverFlags = gameOverFlags
end

-- Excavation left: grace period, then save
local function OnDigExit(_, accept)
    if not DigSession or not accept then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DigFinish")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_DigFinish", DIG_GRACE_MS, FinishDig)
end

-- Gold an auto-loot addon took from a window found empty
function OnMoneyUpdate(_, newMoney, oldMoney, reason)
    if reason ~= CURRENCY_CHANGE_REASON_LOOT and reason ~= CURRENCY_CHANGE_REASON_LOOT_STOLEN then return end
    local late = LateTarget()
    if late and newMoney > oldMoney then
        late.gold = late.gold + (newMoney - oldMoney)
    end
end

local function OnLootReceived(_, _, itemLink, quantity, _, lootType, isSelf, isPickpocketLoot, _, itemId)
    if not isSelf then return end

    -- Leads: itemId is the antiquity ID here
    if lootType == LOOT_TYPE_ANTIQUITY_LEAD then
        local late = LateTarget()
        if late then
            AddLead(late, itemId)
        elseif WDH_Session then
            AddLead(WDH_Session, itemId)
        elseif Now() - WDH_Last.closedAt <= RECEIVED_GRACE_MS then
            AddLeadToLastRecord(itemId)
        else
            dbg(string.format(WDH_STRINGS.DEBUG_NO_WINDOW, ItemName("lead:" .. itemId), 1))
        end
        return
    end

    -- Pickpocketing: no loot window. The victim is the last interaction,
    -- otherwise the target under the crosshair
    if isPickpocketLoot then
        local target
        if WDH_Interact.name and Now() - WDH_Interact.at <= INTERACT_VALID_MS then
            target = WDH_Interact.name
        else
            target = GetUnitName("reticleover")
        end
        if target == nil or target == "" then target = WDH_STRINGS.PICKPOCKET_UNKNOWN end
        local session = NewSession(zo_strformat("<<C:1>>", target), nil, "pickpocket")
        if lootType == LOOT_TYPE_ITEM then
            AddItem(session, itemLink, quantity)
        end
        CommitSession(session)
        return
    end

    -- Loot window was already empty: count the loot here
    local late = LateTarget()
    if late then
        if lootType == LOOT_TYPE_ITEM then AddItem(late, itemLink, quantity) end
        return
    end

    -- Loot without a loot window (e.g. critters with "Take")
    if not WDH_Session and Now() - WDH_Last.closedAt > RECEIVED_GRACE_MS then
        if lootType == LOOT_TYPE_ITEM and AddDirectLoot(itemLink, quantity) then return end
        dbg(string.format(WDH_STRINGS.DEBUG_NO_WINDOW, tostring(itemLink), quantity))
    elseif WDH_Session and not WDH_Session.itemIds[itemId] then
        -- While a loot window is open, but not in its list.
        -- Possible hint at AoE loot: loot of other corpses going straight into the inventory?
        dbg(string.format(WDH_STRINGS.DEBUG_DURING_WINDOW, tostring(itemLink), quantity, WDH_Session.name))
    elseif not WDH_Session and not WDH_Last.itemIds[itemId] then
        -- Shortly after a loot window, but not in its list: should not happen.
        -- (Items from the list regularly arrive only after LOOT_CLOSED; those are already counted.)
        dbg(string.format(WDH_STRINGS.DEBUG_AFTER_WINDOW, tostring(itemLink), quantity))
    end
end

-- -----------------------------------------------------------------------------
-- Output
-- -----------------------------------------------------------------------------

local function QualityList(q)
    local parts = {}
    local highest = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE or ITEM_DISPLAY_QUALITY_LEGENDARY
    for quality = ITEM_DISPLAY_QUALITY_TRASH, highest do
        if q[quality] then
            parts[#parts + 1] = ColorByQuality(quality, string.format("%s %d", QualityName(quality), q[quality]))
        end
    end
    return table.concat(parts, ", ")
end

local function BestQuality(q)
    local best = ITEM_DISPLAY_QUALITY_NORMAL
    for quality in pairs(q) do
        if quality > best then best = quality end
    end
    return best
end

-- -----------------------------------------------------------------------------
-- Interface for WDH_Hud.lua
-- -----------------------------------------------------------------------------

WDH.CurrentZoneId  = CurrentZoneId
WDH.MakeKey        = MakeKey
WDH.RecordKey      = RecordKey
WDH.FindRecord     = FindRecord
WDH.ItemName       = ItemName
WDH.SetName        = SetName
WDH.CatName        = CatName
WDH.ColorByQuality = ColorByQuality
WDH.BestQuality    = BestQuality
WDH.QualityName    = QualityName
WDH.SHOW_OFF       = SHOW_OFF

-- Display settings of the logged-in character
function WDH.Settings()
    return SV.chars[WDH.charId].settings
end

-- Other characters of the account with stored settings: names and IDs, sorted.
-- Deleted characters drop out, renamed ones appear with their current name.
function WDH.OtherCharacters()
    local list = {}
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        if id ~= WDH.charId and SV.chars[id] then
            list[#list + 1] = { name = zo_strformat("<<1>>", name), id = id }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local names, ids = {}, {}
    for _, c in ipairs(list) do
        names[#names + 1] = c.name
        ids[#ids + 1]     = c.id
    end
    return names, ids
end

-- Copies the display settings of another character
function WDH.CopySettingsFrom(charId)
    local source = SV.chars[charId]
    if not source or charId == WDH.charId then return false end
    SV.chars[WDH.charId].settings = CopyDisplay(source.settings)
    if WDH.Hud then WDH.Hud:Invalidate() end
    return true
end

function WDH:PrintRecord(zoneId, rec)
    local header = string.format(WDH_STRINGS.RECORD_HEADER, RecordName(rec), ZoneName(zoneId), rec.loots, rec.gold)
    if rec.kind == "aoe" then header = header .. WDH_STRINGS.RECORD_AOE end
    if rec.kind == "pickpocket" then header = header .. WDH_STRINGS.RECORD_PICKPOCKET end
    if rec.kind == "theft" then header = header .. WDH_STRINGS.RECORD_THEFT end
    d(WDH_STRINGS.PREFIX .. header)

    for setId, s in pairs(rec.sets) do
        local slots = {}
        for slot, count in pairs(s.slots or {}) do
            slots[#slots + 1] = string.format("%s %d", WDH_SLOT_NAMES[slot] or slot, count)
        end
        d(string.format(WDH_STRINGS.RECORD_SET,
            ColorByQuality(BestQuality(s.q), SetName(setId)), table.concat(slots, ", "),
            s.n, s.hits, rec.loots, QualityList(s.q)))
    end
    -- Categories, with their items indented below (set pieces are already listed per set above)
    local itemsByCat = {}
    for id, s in pairs(rec.items) do
        local cat = s.cat or ""
        if cat ~= "SET" then
            itemsByCat[cat] = itemsByCat[cat] or {}
            table.insert(itemsByCat[cat], { id = id, s = s })
        end
    end
    local function PrintItems(list, format)
        for _, e in ipairs(list or {}) do
            d(string.format(format, ColorByQuality(BestQuality(e.s.q), ItemName(e.id)),
                e.s.n, e.s.hits, rec.loots, QualityList(e.s.q)))
        end
    end
    for key, s in pairs(rec.cats) do
        if key ~= "SET" then
            d(string.format(WDH_STRINGS.RECORD_LINE, CatName(key), s.n, s.hits, rec.loots, QualityList(s.q)))
            PrintItems(itemsByCat[key], WDH_STRINGS.RECORD_ITEM)
            itemsByCat[key] = nil
        end
    end
    -- Items without a category (data from version 0.1, before all item IDs were stored)
    for _, list in pairs(itemsByCat) do
        PrintItems(list, WDH_STRINGS.RECORD_LINE)
    end
end

local function SearchZones(needle, zoneIds, found)
    for _, zoneId in ipairs(zoneIds) do
        for key, rec in pairs(SV.zones[zoneId] or {}) do
            if zo_plainstrfind(key, needle) or (rec.collective and zo_plainstrfind(MakeKey(RecordName(rec)), needle)) then
                found[#found + 1] = { zoneId = zoneId, rec = rec }
            end
        end
    end
end

-- Finds sources whose name contains the search text: first the current zone and
-- inventory containers, without hits there in all zones
local function SearchRecords(text)
    local needle = zo_strlower(text)
    local found  = {}
    local here   = CurrentZoneId()
    SearchZones(needle, { here, 0 }, found)
    if #found == 0 then
        local others = {}
        for zoneId in pairs(SV.zones) do
            if zoneId ~= here and zoneId ~= 0 then others[#others + 1] = zoneId end
        end
        SearchZones(needle, others, found)
    end
    return found
end

-- List zones with stored data in chat (/wdh_zones, menu)
function WDH:PrintZones()
    d(WDH_STRINGS.ZONES_HEADER)
    local any = false
    for zoneId, zone in pairs(SV.zones) do
        local sources, loots = 0, 0
        for _, rec in pairs(zone) do
            sources = sources + 1
            loots   = loots + rec.loots
        end
        if sources > 0 then
            any = true
            d(string.format(WDH_STRINGS.ZONES_ENTRY, ZoneName(zoneId), sources, loots))
        end
    end
    if not any then d(WDH_STRINGS.RECORD_NONE) end
end

-- Delete all collected data, settings stay (/wdh_reset yes, menu)
function WDH:ResetData()
    SV.zones = {}
    SV.last  = nil
    WDH_Last.zoneId, WDH_Last.key = nil, nil
    WDH_Last.lootKey, WDH_Last.lootSeen = nil, nil
    WDH.Hud:Invalidate()
    d(WDH_STRINGS.RESET_DONE)
end

-- -----------------------------------------------------------------------------
-- Slash commands
-- -----------------------------------------------------------------------------

local function RegisterSlashCommands()
    SLASH_COMMANDS["/wdh"] = function(args)
        args = args and zo_strtrim(args) or ""
        if args == "" then
            local rec = WDH_Last.key and FindRecord(WDH_Last.zoneId, WDH_Last.key)
            if not rec then
                d(WDH_STRINGS.RECORD_NO_LAST)
                return
            end
            WDH:PrintRecord(WDH_Last.zoneId, rec)
            return
        end
        local found = SearchRecords(args)
        if #found == 0 then
            d(WDH_STRINGS.RECORD_NONE)
            return
        end
        for _, entry in ipairs(found) do
            WDH:PrintRecord(entry.zoneId, entry.rec)
        end
    end

    SLASH_COMMANDS["/wdh_zone"] = function()
        local zoneId = CurrentZoneId()
        d(string.format(WDH_STRINGS.ZONE_HEADER, ZoneName(zoneId)))
        local zone = SV.zones[zoneId]
        if not zone or next(zone) == nil then
            d(WDH_STRINGS.RECORD_NONE)
            return
        end
        for _, rec in pairs(zone) do
            local name = RecordName(rec)
            if rec.kind == "aoe" then name = name .. WDH_STRINGS.RECORD_AOE end
            if rec.kind == "pickpocket" then name = name .. WDH_STRINGS.RECORD_PICKPOCKET end
            if rec.kind == "theft" then name = name .. WDH_STRINGS.RECORD_THEFT end
            d(string.format(WDH_STRINGS.ZONE_ENTRY, name, rec.loots))
        end
    end

    SLASH_COMMANDS["/wdh_zones"] = function()
        WDH:PrintZones()
    end

    SLASH_COMMANDS["/wdh_hud"] = function()
        WDH.Settings().hud = not WDH.Settings().hud
        d(WDH.Settings().hud and WDH_STRINGS.HUD_ON or WDH_STRINGS.HUD_OFF)
    end

    SLASH_COMMANDS["/wdh_units"] = function()
        WDH.Settings().hudUnits = not WDH.Settings().hudUnits
        WDH.Hud:Invalidate()
        d(WDH.Settings().hudUnits and WDH_STRINGS.HUD_UNITS_ON or WDH_STRINGS.HUD_UNITS_OFF)
    end

    SLASH_COMMANDS["/wdh_show"] = function(args)
        local quality = tonumber(args)
        if not quality or quality < ITEM_DISPLAY_QUALITY_TRASH or quality > ITEM_DISPLAY_QUALITY_LEGENDARY then
            d(WDH_STRINGS.SHOW_USAGE)
            return
        end
        -- Applies to all enabled types; individually in the menu
        local settings = WDH.Settings()
        for _, key in ipairs(TYPE_THRESHOLDS) do
            if settings[key] ~= SHOW_OFF then settings[key] = quality end
        end
        WDH.Hud:Invalidate()
        d(string.format(WDH_STRINGS.SHOW_SET, ColorByQuality(quality, QualityName(quality))))
    end

    SLASH_COMMANDS["/wdh_debug"] = function()
        SV.settings.debug = not SV.settings.debug
        d(SV.settings.debug and WDH_STRINGS.DEBUG_ON or WDH_STRINGS.DEBUG_OFF)
    end

    SLASH_COMMANDS["/wdh_names"] = function(args)
        local quality = tonumber(args)
        if not quality or quality < ITEM_DISPLAY_QUALITY_TRASH or quality > ITEM_DISPLAY_QUALITY_LEGENDARY then
            d(WDH_STRINGS.NAMES_USAGE)
            return
        end
        WDH.Settings().nameQuality = quality
        WDH.Hud:Invalidate()
        d(string.format(WDH_STRINGS.NAMES_SET, ColorByQuality(quality, QualityName(quality))))
    end

    SLASH_COMMANDS["/wdh_reset"] = function(args)
        -- "yes" works in every language, plus the word of the client language ("ja")
        local answer = zo_strlower(zo_strtrim(args or ""))
        if answer ~= "yes" and answer ~= WDH_STRINGS.RESET_CONFIRM then
            d(WDH_STRINGS.RESET_USAGE)
            return
        end
        WDH:ResetData()
    end
end

-- -----------------------------------------------------------------------------
-- Initialization
-- -----------------------------------------------------------------------------

-- Up to 0.2 the display settings were account-wide in SV.settings.
-- They become the template every character starts with on its first login.
local function MigrateAccountDisplay()
    local old = SV.settings
    if old.showQuality == nil and old.hud == nil then return end
    local template = {}
    for k in pairs(DEFAULT_DISPLAY) do template[k] = old[k] end
    for key, switch in pairs(LEGACY_TYPE_SWITCH) do
        if old[switch] == false then
            template[key] = SHOW_OFF
        else
            template[key] = old.showQuality
        end
        old[switch] = nil
    end
    for k in pairs(DEFAULT_DISPLAY) do old[k] = nil end
    old.showQuality = nil
    SV.template = CopyDisplay(template)
end

-- Merges one stored source into another (migration)
local function MergeRecord(dst, src)
    dst.loots = dst.loots + src.loots
    dst.gold  = dst.gold + src.gold
    dst.last  = math.max(dst.last or 0, src.last or 0)
    for _, field in ipairs({ "sets", "items", "cats" }) do
        for id, s in pairs(src[field]) do
            local d = dst[field][id]
            if not d then
                dst[field][id] = s
            else
                d.n    = d.n + s.n
                d.hits = d.hits + s.hits
                d.cat  = d.cat or s.cat
                d.min  = (d.min and s.min) and math.min(d.min, s.min) or d.min or s.min
                d.max  = math.max(d.max or 0, s.max or 0)
                for quality, count in pairs(s.q) do d.q[quality] = (d.q[quality] or 0) + count end
                for slot, count in pairs(s.slots or {}) do
                    d.slots = d.slots or {}
                    d.slots[slot] = (d.slots[slot] or 0) + count
                end
            end
        end
    end
end

-- Source from "Take" without a window that only holds items lying around (see IsLooseItem)
local function IsLooseRecord(rec)
    if next(rec.items) == nil then return false end
    for id in pairs(rec.items) do
        if type(id) ~= "number" or not IsLooseItem(ItemLinkFromId(id), rec.name) then return false end
    end
    return true
end

-- Up to 0.3.0 every item lying around became a source of its own.
-- Without a loot window targetType is missing. Stolen -> collective record of the zone, otherwise delete.
local function MigrateLooseItems()
    for zoneId, zone in pairs(SV.zones) do
        local stolen = {}
        for key, rec in pairs(zone) do
            if rec.targetType == nil and not rec.collective then
                if rec.kind == "theft" then
                    stolen[#stolen + 1] = key
                elseif rec.kind == "take" and IsLooseRecord(rec) then
                    zone[key] = nil
                end
            end
        end
        for _, key in ipairs(stolen) do
            local rec = zone[key]
            zone[key] = nil
            local dst = GetRecord(zoneId, LOOSE_THEFT_KEY, WDH_STRINGS.RECORD_LOOSE, "theft")
            dst.collective = true
            dst.type       = "theft"
            MergeRecord(dst, rec)
        end
    end
end

-- Up to 0.3.1 the SavedVariable was called WDH_Saved and covered all servers and accounts.
-- Now: WhatDropsHere_Saved[server][@account]. The first account logging in after the update
-- takes over the old data (every account wrote into the same table anyway);
-- afterwards WDH_Saved is cleared and removed from the file on the next save.
local function OpenSaved()
    if type(WhatDropsHere_Saved) ~= "table" then WhatDropsHere_Saved = {} end
    local world, account = GetWorldName(), GetDisplayName()
    local root = WhatDropsHere_Saved
    root[world] = root[world] or {}
    local data = root[world][account]
    if not data then
        data = type(WDH_Saved) == "table" and WDH_Saved or {}
        root[world][account] = data
    end
    WDH_Saved = nil
    return data
end

local function InitSaved()
    SV = OpenSaved()
    WDH.sv = SV
    SV.zones = SV.zones or {}
    if (SV.version or SAVED_VERSION) < 3 then MigrateLooseItems() end
    SV.version  = SAVED_VERSION
    SV.settings = SV.settings or {}
    MigrateAccountDisplay()
    FillDefaults(SV.settings, DEFAULT_ACCOUNT)

    -- Display settings per character (the ID stays the same on renaming)
    SV.chars = SV.chars or {}
    local charId = GetCurrentCharacterId()
    local char = SV.chars[charId]
    if not char then
        char = { settings = CopyDisplay(SV.template or DEFAULT_DISPLAY) }
        SV.chars[charId] = char
    end
    char.name = zo_strformat("<<1>>", GetUnitName("player"))
    FillDefaults(char.settings, DEFAULT_DISPLAY)
    WDH.charId = charId

    SV.zones = SV.zones or {}
    if SV.last then
        WDH_Last.zoneId = SV.last.zoneId
        WDH_Last.key    = SV.last.key
    end
end

local function RegisterLootTracking()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootUpdated",  EVENT_LOOT_UPDATED,  OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootClosed",   EVENT_LOOT_CLOSED,   OnLootClosed)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootReceived", EVENT_LOOT_RECEIVED, OnLootReceived)
    -- EVENT_MONEY_UPDATE only when needed, see UpdateMoneyWatch
    -- Save open sessions before loading screens, /reloadui and logout
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Deactivated",  EVENT_PLAYER_DEACTIVATED, function()
        FinishSession()
        FinishPending()
        FinishDirectSession()
        FinishDig()
    end)
    -- Remember the source for loot without a loot window. The hook returns nothing,
    -- so the interaction continues normally.
    ZO_PreHook(INTERACTIVE_WHEEL_MANAGER, "StartInteraction", OnInteractionStart)
    -- Excavations
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_DigReady",    EVENT_ANTIQUITY_DIGGING_READY_TO_PLAY, OnDigReady)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_DigGameOver", EVENT_ANTIQUITY_DIGGING_GAME_OVER,     OnDigGameOver)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_DigExit",     EVENT_ANTIQUITY_DIGGING_EXIT_RESPONSE, OnDigExit)
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME .. "_Loaded",
    EVENT_ADD_ON_LOADED,
    function(_, addonName)
        if addonName ~= ADDON_NAME then return end
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Loaded", EVENT_ADD_ON_LOADED)
        if WDH_Initialized then return end
        WDH_Initialized = true

        InitSaved()
        RegisterLootTracking()
        RegisterSlashCommands()
        WDH.Hud:Init()
        WDH.Menu:Init()
    end
)
