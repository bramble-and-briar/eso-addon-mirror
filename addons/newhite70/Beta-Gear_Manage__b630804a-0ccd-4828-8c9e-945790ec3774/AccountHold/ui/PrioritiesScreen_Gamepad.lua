-- AccountHold/ui/PrioritiesScreen_Gamepad.lua
--
-- The console (gamepad) Priorities screen for epic 0005: a parametric list that
-- answers "what should I go do tonight?" from AccountHold.Priorities:BuildPlan()
-- and lets the player travel to an activity or drop something off the wishlist
-- without leaving the pause menu.
--
-- The pause-menu entry lives in the sibling file ui/PrioritiesMenu_Gamepad.lua.
-- The LIVE surface is the parametric dialog ACCOUNT_HOLD_PRIORITIES_DIALOG,
-- shown on a fragment-only native host scene with a detail panel beside it --
-- see "PRI-11" below for why it is built that way. That split is deliberate: everything in
-- THAT file runs inside ZO_MENU_ENTRIES, the same array that owns OPTIONS, QUIT
-- and LOG_OUT (esoui/ingame/mainmenu/gamepad/zo_mainmenu_gamepad.lua:21-23), so
-- it is kept as small and as boring as possible. Nothing in THIS file is ever
-- walked by MAIN_MENU_GAMEPAD:RefreshMainList (:1037-1057) -- it only runs once
-- our own scene is showing -- which is why the list logic can afford to be big.
--
-- === ToS-CRITICAL STRUCTURE ==================================================
-- FastTravelToNode is NOT a protected function (ESOUIDocumentation.txt :13872
-- carries no *protected* marker, unlike PlaceInTradeWindow at :11385), so the
-- client would happily teleport the player from a render pass. 0005's ToS
-- section draws the line at "ability to automate is not permission to
-- automate", and src/Travel.lua is the single chokepoint. This file is the only
-- caller of that chokepoint in the UI layer, and it is built so that a test can
-- PROVE travel is unreachable from rendering:
--
--   1. Screen._PerformTravel is the only function here that names
--      Travel:TravelTo, and it refuses unless handed CONFIRM_TOKEN -- a
--      file-local table whose only reference outside _PerformTravel is captured
--      by the travel dialog's confirm-button closure. No render, refresh,
--      selection or event path can produce that value.
--   2. The travel keybind's `visible` and `name` callbacks are purely
--      structural (what KIND of row is selected). They never call
--      Travel:FindNodeForActivity, Travel:CanTravelTo or Travel:GetCost, so the
--      keybind-strip update loop -- which runs on every cursor move -- touches
--      no travel API at all.
--   3. Node resolution happens only in OfferTravelForSelected, which is reached
--      only from an explicit button press, and which ends by SHOWING A DIALOG.
--      It never travels.
--   4. Populate / Refresh / OnTargetChanged call nothing in AccountHold.Travel.
-- =============================================================================
--
-- Console constraints honoured here (0005 "Console / Xbox constraints"):
--   * No free text anywhere -- every action is selection-driven. Nothing in
--     this file creates an edit box (Platform.SupportsFreeTextSearch() is false
--     on console).
--   * Confirmations go through ZO_Dialogs_ShowPlatformDialog. Showing a gamepad
--     dialog through the KEYBOARD path previously crashed console at
--     zo_dialog.lua:556 -- see the comment in ui/BankActionPanel.lua:370-375.
--   * Every ZOS global is type-guarded before use so the file LOADS (and the
--     pure helpers stay callable) under the mock harness, which has none of the
--     gamepad UI framework.

AccountHold = AccountHold or {}
AccountHold.UI = AccountHold.UI or {}
AccountHold.UI.PrioritiesScreenGamepad = AccountHold.UI.PrioritiesScreenGamepad or {}

local Screen = AccountHold.UI.PrioritiesScreenGamepad

-- Foundation layer. Resolved at CALL time, never captured at load time: src/
-- loads before ui/, but a stripped environment or a load-order change must
-- degrade to a safe no-op rather than a nil index.
--
-- Safe.Method is the correct guard for an ENGINE global. SCENE_MANAGER,
-- KEYBIND_STRIP and friends are USERDATA on hardware (globalvars.lua:2-4), so
-- `type(x) == "table"` is false in game -- a bug class that has already cost
-- this screen its entire keybind strip. See docs/BUGS.md PRI-6.
local Safe = setmetatable({}, {
    __index = function(_, key)
        local core = AccountHold and AccountHold.Core
        local S = core and core.Safe
        if type(S) == "table" and type(S[key]) == "function" then
            return S[key]
        end
        -- Standalone fallback with identical semantics to Safe.Method.
        if key == "Method" then
            return function(obj, name)
                if obj == nil or type(name) ~= "string" then return nil end
                local ok, fn = pcall(function() return obj[name] end)
                if ok and type(fn) == "function" then return fn end
                return nil
            end
        end
        return nil
    end,
})

-- Strings are registered centrally by the coordinator; feature agents must not
-- edit localization/en.lua (concurrent edits to one shared file collide). Same
-- helper shape as src/Travel.lua so the module renders correctly either way.
local function L(id, fallback)
    if AccountHold and type(AccountHold.L) == "function" then
        return AccountHold.L(id, fallback)
    end
    return fallback
end

-- Chat/diagnostic lines stay to ONE short line: console players read these in
-- chat and a multi-line traceback is unusable there. Mirrors
-- ui/InventoryTab_Gamepad.lua:48.
local function shortErr(err)
    local s = tostring(err or "")
    s = s:gsub("[\r\n].*$", "")
    if #s > 120 then s = s:sub(1, 117) .. "..." end
    return s
end

-- ---------------------------------------------------------------------------
-- Row kinds and dialog ids
-- ---------------------------------------------------------------------------

-- The list carries three kinds of row. Keeping the kind on the row (rather than
-- inferring it from which fields happen to be set) is what lets every keybind
-- `visible` callback be a cheap structural test with no API calls in it -- see
-- rule 2 in the ToS block above.
local ROW_ACTIVITY = "activity"
local ROW_PRIORITY = "priority"
local ROW_EMPTY    = "empty"

Screen.ROW_ACTIVITY = ROW_ACTIVITY
Screen.ROW_PRIORITY = ROW_PRIORITY
Screen.ROW_EMPTY    = ROW_EMPTY

-- SetSources emits this synthetic activityKey for wanted sets it has no source
-- record for (contract B). 0005's acceptance criteria require it to be SHOWN,
-- never silently dropped, so the key is a first-class constant here.
local UNKNOWN_ACTIVITY_KEY = "unknown"
Screen.UNKNOWN_ACTIVITY_KEY = UNKNOWN_ACTIVITY_KEY

local TRAVEL_DIALOG = "ACCOUNT_HOLD_PRIORITIES_TRAVEL"
local REMOVE_DIALOG = "ACCOUNT_HOLD_PRIORITIES_REMOVE"

Screen.TRAVEL_DIALOG = TRAVEL_DIALOG
Screen.REMOVE_DIALOG = REMOVE_DIALOG

-- The capability token described in rule 1 of the ToS block. It is a plain
-- table with no identity anyone can reconstruct: `== CONFIRM_TOKEN` is true
-- only for the exact value captured by the confirm-button closure registered in
-- EnsureTravelDialog. Rendering code cannot name it, so rendering code cannot
-- travel -- this is a structural guarantee, not a convention.
local CONFIRM_TOKEN = {}

-- ---------------------------------------------------------------------------
-- Pure presentation helpers -- NO ZO_* globals, callable from the mock harness
-- with nothing loaded. Exposed as test seams at the bottom of this block.
-- ---------------------------------------------------------------------------

-- activityType is one of exactly dungeon|trial|arena|overland|crafted|pvp|other
-- (contract A). An unrecognised value falls through to the "other" label rather
-- than rendering a raw enum token at the player.
local ACTIVITY_TYPE_STRING = {
    dungeon  = { "SI_ACCOUNTHOLD_PRIO_TYPE_DUNGEON",  "Dungeon" },
    trial    = { "SI_ACCOUNTHOLD_PRIO_TYPE_TRIAL",    "Trial" },
    arena    = { "SI_ACCOUNTHOLD_PRIO_TYPE_ARENA",    "Arena" },
    overland = { "SI_ACCOUNTHOLD_PRIO_TYPE_OVERLAND", "Overland" },
    crafted  = { "SI_ACCOUNTHOLD_PRIO_TYPE_CRAFTED",  "Crafting station" },
    pvp      = { "SI_ACCOUNTHOLD_PRIO_TYPE_PVP",      "PvP" },
    other    = { "SI_ACCOUNTHOLD_PRIO_TYPE_OTHER",    "Other" },
}

local function activityTypeLabel(activityType)
    local entry = ACTIVITY_TYPE_STRING[activityType] or ACTIVITY_TYPE_STRING.other
    return L(entry[1], entry[2])
end

-- ---------------------------------------------------------------------------
-- Row icons
-- ---------------------------------------------------------------------------
-- Every path below was read out of esoui/esoui@master, never guessed. A texture
-- path that does not resolve draws an empty square on a TV, which looks more
-- broken than no icon at all -- so an activity type with no verified art gets
-- nil and ZO_SharedGamepadEntryIconSetup simply never shows the multi-icon
-- (zo_gamepadtemplatescommon.lua, ZO_SharedGamepadEntryIconSetup: the icon is
-- only :Show()n inside `if numIcons > 0`).
--
--   mapKey_*            publicallingames/globals/sharedtextures.lua:96-105
--                       (ZONE_DISPLAY_TYPE_ICONS)
--   gp_LFG_menuIcon_*   ingame/lfg/zo_dungeonfinder_manager.lua (menuIcon),
--                       and ui/DungeonFinderScene_Gamepad.lua:206 in this repo
--   LFG_menuIcon_zoneStories  ingame/zonestories/zonestories_manager.lua
--   gp_playerMenu_icon_allianceWar  ingame/mainmenu/gamepad/zo_mainmenu_gamepad.lua
--   gp_playerMenu_icon_itemSetCollections
--                       ingame/collections/itemsetcollectionsdata.lua
--                       (ZO_ItemSetCollectionSummaryCategoryData:GetGamepadIcon)
--   gp_playerMenu_icon_inventory / _journal  ui/PrioritiesMenu_Gamepad.lua:334,442
--   gp_crafting_menuIcon_diagrams  sharedtextures.lua:427
--   ESO_Icon_Warning    ingame/contacts/keyboard/notifications_keyboard.lua
local ICON_SET_FALLBACK  = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_itemSetCollections.dds"
local ICON_ITEM_FALLBACK = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds"
local ICON_UNKNOWN       = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"

local ACTIVITY_TYPE_ICON = {
    dungeon  = "EsoUI/Art/LFG/Gamepad/gp_LFG_menuIcon_Dungeon.dds",
    trial    = "EsoUI/Art/Icons/mapKey/mapKey_raidDungeon.dds",
    arena    = "EsoUI/Art/Icons/mapKey/mapKey_groupArea.dds",
    overland = "EsoUI/Art/LFG/Gamepad/LFG_menuIcon_zoneStories.dds",
    crafted  = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_diagrams.dds",
    pvp      = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_allianceWar.dds",
    other    = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_journal.dds",
}

-- PURE. No ZO_* global, no state: a string in, a string (or nil) out.
local function activityTypeIcon(activityType, isUnknown)
    if isUnknown then return ICON_UNKNOWN end
    return ACTIVITY_TYPE_ICON[activityType] or ACTIVITY_TYPE_ICON.other
end

-- "Fungal Grotto I, Banished Cells I and 2 more" would be nicer, but console
-- rows are narrow and the sub-label is already the third line. Cap the list and
-- say how many were elided rather than letting the row overflow.
local MAX_SETS_LISTED = 3

local function joinSetNames(setIds, setNameFn)
    if type(setIds) ~= "table" or #setIds == 0 then return nil end
    local parts = {}
    local shown = 0
    for i = 1, #setIds do
        if shown >= MAX_SETS_LISTED then break end
        local name = setNameFn and setNameFn(setIds[i]) or nil
        if type(name) == "string" and name ~= "" then
            shown = shown + 1
            parts[shown] = name
        end
    end
    if shown == 0 then return nil end
    local text = table.concat(parts, ", ")
    local remaining = #setIds - shown
    if remaining > 0 then
        text = text .. string.format(
            L("SI_ACCOUNTHOLD_PRIO_COVERS_MORE", " and %d more"), remaining)
    end
    return string.format(L("SI_ACCOUNTHOLD_PRIO_COVERS", "Covers: %s"), text)
end

-- Build the display rows for the screen.
--
-- PURE by construction: no ZO_* global, no SavedVariables, no module state. It
-- takes the plan, the raw wishlist and two name resolvers, and returns row
-- descriptors. That is what lets the harness assert ordering, the "source
-- unknown" row and the empty state with none of the gamepad UI framework
-- present.
--
-- ORDER IS NOT TOUCHED. Contract B fixes it (outstanding DESC, then
-- activityName ASC) and Priorities:BuildPlan preserves it, so re-sorting here
-- would mean two modules owning one guarantee. In particular the synthetic
-- "unknown" activity is rendered wherever the rollup put it; it is marked, not
-- moved.
--
-- The trailing "Wanted" section is not decoration. Plan rows are ACTIVITIES,
-- and an activity can cover several wanted sets, so "remove the priority under
-- the cursor" has no unambiguous meaning on an activity row. Listing the
-- wishlist records themselves gives the remove keybind exactly one target and
-- keeps the list manageable without leaving the menu (epic requirement).
function Screen._BuildRows(plan, priorities, setNameFn, itemNameFn, setIconFn)
    local rows = {}
    plan       = (type(plan) == "table") and plan or {}
    priorities = (type(priorities) == "table") and priorities or {}

    -- Optional, injected exactly like setNameFn so this function stays pure:
    -- resolving a set's collection icon is a base-game call and must not happen
    -- in here. A resolver that is absent, or that returns nothing, degrades to
    -- the generic Item Set Collections menu icon.
    local function setIcon(setId)
        if type(setIconFn) == "function" then
            local icon = setIconFn(setId)
            if type(icon) == "string" and icon ~= "" then return icon end
        end
        return ICON_SET_FALLBACK
    end

    local planHeader = L("SI_ACCOUNTHOLD_PRIO_HEADER_PLAN", "Run these - dungeons & trials")
    for i = 1, #plan do
        local activity = plan[i]
        if type(activity) == "table" then
            local isUnknown = (activity.activityKey == UNKNOWN_ACTIVITY_KEY)
            local outstanding = tonumber(activity.outstanding) or 0
            local subLabels = {}

            -- PRI-11: the row carries only what a native list row carries -- a
            -- kind and the count that orders the list. Zone and the "Covers:"
            -- list moved to the detail panel (Screen._DetailFor), which is
            -- where the native Activity Finder / Item Sets screens put them;
            -- four sub-labels per row is what made this blade look unlike them.
            local zoneName
            if isUnknown then
                -- Honest incompleteness beats a tidy lie: the player has to be
                -- able to tell that the plan does not cover these sets at all.
                subLabels[#subLabels + 1] = L(
                    "SI_ACCOUNTHOLD_PRIO_UNKNOWN_SOURCE_DESC",
                    "No activity data for these sets - this plan is incomplete.")
            else
                subLabels[#subLabels + 1] = activityTypeLabel(activity.activityType)
                if type(activity.zoneName) == "string" and activity.zoneName ~= ""
                   and activity.zoneName ~= activity.activityName then
                    zoneName = activity.zoneName
                end
            end

            subLabels[#subLabels + 1] = string.format(
                L("SI_ACCOUNTHOLD_PRIO_OUTSTANDING", "%d wanted piece(s) outstanding"),
                outstanding)

            -- Every covered set, uncapped, for the detail panel.
            local setIds, setNames = {}, {}
            if type(activity.setIds) == "table" then
                for s = 1, #activity.setIds do
                    local sid = activity.setIds[s]
                    setIds[#setIds + 1] = sid
                    local sname = setNameFn and setNameFn(sid) or nil
                    if type(sname) ~= "string" or sname == "" then
                        sname = L("SI_ACCOUNTHOLD_PRIO_SET_UNKNOWN", "Unknown set")
                    end
                    setNames[#setNames + 1] = sname
                end
            end

            local name
            if isUnknown then
                -- Same string id src/SetSources.lua uses for the synthetic
                -- row's activityName, so the coordinator registers ONE string
                -- and the two modules can never disagree about the wording.
                name = L("SI_ACCOUNTHOLD_SOURCE_UNKNOWN", "Source unknown")
            elseif type(activity.activityName) == "string" and activity.activityName ~= "" then
                name = activity.activityName
            else
                name = L("SI_ACCOUNTHOLD_PRIO_UNNAMED_ACTIVITY", "Unnamed activity")
            end

            rows[#rows + 1] = {
                rowType     = ROW_ACTIVITY,
                activity    = activity,
                isUnknown   = isUnknown,
                name        = name,
                outstanding = outstanding,
                subLabels   = subLabels,
                icon        = activityTypeIcon(activity.activityType, isUnknown),
                header      = (#rows == 0) and planHeader or nil,
                typeLabel   = (not isUnknown) and activityTypeLabel(activity.activityType) or nil,
                zoneName    = zoneName,
                setIds      = setIds,
                setNames    = setNames,
            }
        end
    end

    -- Empty state. A blank screen on console reads as a broken add-on, so the
    -- two reasons the plan can be empty get two different messages: nothing
    -- wanted at all, versus everything wanted is already owned.
    if #rows == 0 then
        local message
        if #priorities == 0 then
            message = L("SI_ACCOUNTHOLD_PRIO_EMPTY",
                "Nothing marked as wanted yet. Mark a set or item as wanted from the Account Gear list.")
        else
            message = L("SI_ACCOUNTHOLD_PRIO_NOTHING_OUTSTANDING",
                "Nothing outstanding - you already own every wanted piece.")
        end
        rows[#rows + 1] = {
            rowType   = ROW_EMPTY,
            name      = message,
            subLabels = {},
            icon      = ICON_UNKNOWN,
            header    = planHeader,
        }
    end

    -- Which activities drop each wanted set, for the detail panel of a set row.
    local sourcesBySet, unknownBySet = {}, {}
    for i = 1, #plan do
        local activity = plan[i]
        if type(activity) == "table" and type(activity.setIds) == "table" then
            local isUnknownAct = (activity.activityKey == UNKNOWN_ACTIVITY_KEY)
            local actName = activity.activityName
            for s = 1, #activity.setIds do
                local sid = tonumber(activity.setIds[s])
                if sid then
                    if isUnknownAct then
                        unknownBySet[sid] = true
                    elseif type(actName) == "string" and actName ~= "" then
                        sourcesBySet[sid] = sourcesBySet[sid] or {}
                        local list = sourcesBySet[sid]
                        list[#list + 1] = actName
                    end
                end
            end
        end
    end

    local wantedHeader = L("SI_ACCOUNTHOLD_PRIO_HEADER_WANTED", "Wanted sets & items")
    local firstPriorityRow = true
    for i = 1, #priorities do
        local rec = priorities[i]
        if type(rec) == "table" then
            local name, sub, icon, itemLink, rowSetId
            if rec.kind == "item" then
                local itemName = itemNameFn and itemNameFn(rec.itemSignature) or nil
                if type(itemName) ~= "string" or itemName == "" then
                    itemName = L("SI_ACCOUNTHOLD_PRIO_ITEM_UNKNOWN", "Unknown item")
                end
                name = itemName
                sub  = L("SI_ACCOUNTHOLD_PRIO_KIND_ITEM", "Item")
                icon = ICON_ITEM_FALLBACK
                -- Contract C: an item priority stores the item LINK as its
                -- signature, so it doubles as the source for the real item icon
                -- and the display-quality colour. Resolved outside this pure
                -- function; only carried here.
                if type(rec.itemSignature) == "string" and rec.itemSignature ~= "" then
                    itemLink = rec.itemSignature
                end
            else
                local setId = tonumber(rec.setId)
                local setName = (setId and setNameFn) and setNameFn(setId) or nil
                if type(setName) ~= "string" or setName == "" then
                    setName = L("SI_ACCOUNTHOLD_PRIO_SET_UNKNOWN", "Unknown set")
                end
                name = setName
                sub  = L("SI_ACCOUNTHOLD_PRIO_KIND_SET", "Set")
                icon = setId and setIcon(setId) or ICON_SET_FALLBACK
                rowSetId = setId
            end
            rows[#rows + 1] = {
                rowType   = ROW_PRIORITY,
                priority  = rec,
                name      = name,
                subLabels = { sub },
                icon      = icon,
                itemLink  = itemLink,
                header    = firstPriorityRow and wantedHeader or nil,
                setId     = rowSetId,
                sources   = rowSetId and sourcesBySet[rowSetId] or nil,
                sourceUnknown = (rowSetId and unknownBySet[rowSetId]) and true or nil,
            }
            firstPriorityRow = false
        end
    end

    return rows
end

-- Test seams (mirroring Tab._Blade in ui/InventoryTab_Gamepad.lua): the pure
-- helpers are reachable without a single ZO_* global.
Screen._ActivityTypeLabel = activityTypeLabel
Screen._ActivityTypeIcon  = activityTypeIcon
Screen._JoinSetNames      = joinSetNames
Screen._ICON_SET_FALLBACK  = ICON_SET_FALLBACK
Screen._ICON_ITEM_FALLBACK = ICON_ITEM_FALLBACK
Screen._ICON_UNKNOWN       = ICON_UNKNOWN

-- ---------------------------------------------------------------------------
-- Guarded name resolution
-- ---------------------------------------------------------------------------

-- GetItemSetName resolves a set the account owns NOTHING of
-- (ESOUIDocumentation.txt :19929), which is exactly the "I want this, I do not
-- have it" case that defines a priority -- so it is preferred over any lookup
-- through Index. Falls back to the numeric id so a row is never blank.
function Screen:_SetName(setId)
    setId = tonumber(setId)
    if not setId then return nil end
    if type(GetItemSetName) == "function" then
        local ok, name = pcall(GetItemSetName, setId)
        if ok and type(name) == "string" and name ~= "" then
            -- Native set rows never show the raw string: ZO_ItemSetCollectionData
            -- :GetFormattedName runs it through SI_ITEM_SET_NAME_FORMATTER
            -- (ingame/collections/itemsetcollectionsdata.lua). Without it a name
            -- carrying ^Fn gender/article markup renders the markup literally.
            if type(zo_strformat) == "function" and SI_ITEM_SET_NAME_FORMATTER ~= nil then
                local okFmt, pretty = pcall(zo_strformat, SI_ITEM_SET_NAME_FORMATTER, name)
                if okFmt and type(pretty) == "string" and pretty ~= "" then return pretty end
            end
            return name
        end
    end
    local index = AccountHold and AccountHold.Index
    if index and type(index.GetKnownSets) == "function" then
        local ok, sets = pcall(index.GetKnownSets, index)
        if ok and type(sets) == "table" then
            for i = 1, #sets do
                local s = sets[i]
                if tonumber(s.setId) == setId and type(s.name) == "string" and s.name ~= "" then
                    return s.name
                end
            end
        end
    end
    return string.format(L("SI_ACCOUNTHOLD_PRIO_SET_NUMBERED", "Set #%d"), setId)
end

-- The icon for a set row: the set's first piece, exactly as
-- ZO_ItemSetCollectionPieceData:GetIcon does (itemsetcollectionsdata.lua:97-98),
-- or failing that the gamepad icon of the set's TOP-LEVEL collection category.
--
-- PRI-4 (the red "?"): the set's own category is a SUBCATEGORY, and the base
-- game never draws a gamepad icon for one -- itemsetsbook_gamepad.lua:158
-- builds subcategory rows with no icon at all; only top-level categories
-- (:480, :492) call GetGamepadIcon. Asking for a subcategory's gamepad icon
-- returned a texture name that does not exist, which renders as the red
-- missing-texture "?". The piece icon is now tried first and the category
-- route walks up to the root.
function Screen:_SetIcon(setId)
    setId = tonumber(setId)
    if not setId then return nil end

    if type(GetItemSetCollectionPieceInfo) == "function"
       and type(GetItemSetCollectionPieceItemLink) == "function"
       and type(GetItemLinkIcon) == "function" then
        local okPiece, pieceId = pcall(GetItemSetCollectionPieceInfo, setId, 1)
        if okPiece and type(pieceId) == "number" and pieceId ~= 0 then
            local okLink, link = pcall(GetItemSetCollectionPieceItemLink, pieceId,
                                       LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
            if okLink and type(link) == "string" and link ~= "" then
                local okIcon, icon = pcall(GetItemLinkIcon, link)
                if okIcon and type(icon) == "string" and icon ~= "" then return icon end
            end
        end
    end

    if type(GetItemSetCollectionCategoryId) == "function"
       and type(GetItemSetCollectionCategoryGamepadIcon) == "function" then
        local okCat, categoryId = pcall(GetItemSetCollectionCategoryId, setId)
        if okCat and type(categoryId) == "number" and categoryId ~= 0 then
            -- Walk to the root category; bounded in case the tree ever cycles.
            if type(GetItemSetCollectionCategoryParentId) == "function" then
                for _ = 1, 8 do
                    local okParent, parentId = pcall(GetItemSetCollectionCategoryParentId, categoryId)
                    if not okParent or type(parentId) ~= "number" or parentId == 0
                       or parentId == categoryId then
                        break
                    end
                    categoryId = parentId
                end
            end
            local okIcon, icon = pcall(GetItemSetCollectionCategoryGamepadIcon, categoryId)
            if okIcon and type(icon) == "string" and icon ~= "" then return icon end
        end
    end

    return nil
end

-- A real item link for the set's first collection piece -- the link the native
-- Item Sets book hands to LayoutItemSetCollectionPieceLink
-- (itemsetsbook_gamepad.lua:134-135, data from itemsetcollectionsdata.lua). The
-- piece tooltip carries the set's name and every set bonus, which is exactly
-- the detail a player wants when looking at a wanted set.
--   GetItemSetCollectionPieceInfo(itemSetId, index) -> pieceId, slot
--                                               ESOUIDocumentation.txt:20107
--   GetItemSetCollectionPieceItemLink(pieceId, linkStyle, traitType)
--                                               ESOUIDocumentation.txt:20148
function Screen:_SetPieceLink(setId)
    setId = tonumber(setId)
    if not setId then return nil end
    if type(GetItemSetCollectionPieceInfo) ~= "function"
       or type(GetItemSetCollectionPieceItemLink) ~= "function" then
        return nil
    end
    local okPiece, pieceId = pcall(GetItemSetCollectionPieceInfo, setId, 1)
    if not okPiece or type(pieceId) ~= "number" or pieceId == 0 then return nil end
    local okLink, link = pcall(GetItemSetCollectionPieceItemLink, pieceId,
                               LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
    if okLink and type(link) == "string" and link ~= "" then return link end
    return nil
end

-- (unlocked, total) collection pieces for a set, or nil. The same two numbers
-- the Item Sets book shows as its progress bar.
--   GetNumItemSetCollectionPieces(itemSetId)        ESOUIDocumentation.txt:20104
--   GetNumItemSetCollectionSlotsUnlocked(itemSetId) ESOUIDocumentation.txt:20110
function Screen:_SetProgress(setId)
    setId = tonumber(setId)
    if not setId then return nil end
    if type(GetNumItemSetCollectionPieces) ~= "function"
       or type(GetNumItemSetCollectionSlotsUnlocked) ~= "function" then
        return nil
    end
    local okT, total = pcall(GetNumItemSetCollectionPieces, setId)
    local okU, unlocked = pcall(GetNumItemSetCollectionSlotsUnlocked, setId)
    if not okT or not okU or type(total) ~= "number" or type(unlocked) ~= "number"
       or total <= 0 then
        return nil
    end
    return unlocked, total
end

-- An item priority stores the item LINK as its signature (contract C), so the
-- display name comes straight off the link.
function Screen:_ItemName(itemSignature)
    if type(itemSignature) ~= "string" or itemSignature == "" then return nil end
    if type(GetItemLinkName) == "function" then
        local ok, name = pcall(GetItemLinkName, itemSignature)
        if ok and type(name) == "string" and name ~= "" then
            -- sharedinventory.lua runs every raw item name through
            -- zo_strformat(SI_TOOLTIP_ITEM_NAME, ...) before it reaches a row;
            -- skipping it renders ^Fn article/gender markup literally.
            if type(zo_strformat) == "function" and SI_TOOLTIP_ITEM_NAME ~= nil then
                local okFmt, pretty = pcall(zo_strformat, SI_TOOLTIP_ITEM_NAME, name)
                if okFmt and type(pretty) == "string" and pretty ~= "" then return pretty end
            end
            return name
        end
    end
    return itemSignature
end

-- ---------------------------------------------------------------------------
-- Data gathering
-- ---------------------------------------------------------------------------

-- Both model calls are pcall-wrapped even though contract C promises they never
-- throw: this screen is reached from the pause menu, and a model that throws
-- here must degrade to an empty plan rather than leave the player on a scene
-- that failed halfway through building.
function Screen:_Plan()
    local p = AccountHold and AccountHold.Priorities
    if type(p) ~= "table" or type(p.BuildPlan) ~= "function" then return {} end
    local ok, plan = pcall(p.BuildPlan, p)
    if ok and type(plan) == "table" then return plan end
    if self.addon and self.addon.Diagnostic then
        self.addon:Diagnostic("warn", "[priorities] BuildPlan failed: %s", shortErr(plan))
    end
    return {}
end

function Screen:_Wishlist()
    local p = AccountHold and AccountHold.Priorities
    if type(p) ~= "table" or type(p.List) ~= "function" then return {} end
    local ok, list = pcall(p.List, p)
    if ok and type(list) == "table" then return list end
    return {}
end

function Screen:Rows()
    local screen = self
    return Screen._BuildRows(
        self:_Plan(),
        self:_Wishlist(),
        function(setId) return screen:_SetName(setId) end,
        function(sig)   return screen:_ItemName(sig) end,
        function(setId)
            local ok, icon = pcall(function() return screen:_SetIcon(setId) end)
            if ok then return icon end
            return nil
        end)
end

-- ---------------------------------------------------------------------------
-- List construction
-- ---------------------------------------------------------------------------

-- We do NOT hand-roll a control tree. ZO_Gamepad_ParametricList_Screen_ListContainer
-- is the base game's own virtual template for a parametric list container -- the
-- same one ZO_Gamepad_ParametricList_Screen:AddList instantiates, and the same
-- one the Quartermaster inventory blade gets for free by going through
-- GAMEPAD_INVENTORY:AddList (see the header of ui/InventoryTab_Gamepad.lua for
-- why a hand-built runtime control crashed the session). Creating it from the
-- virtual template keeps the XML-defined children, anchors and render pass.
--
-- Every step is pcall-guarded and the whole thing returns nil on any failure,
-- because PrioritiesMenu_Gamepad refuses to install the pause-menu entry unless
-- this succeeds: an entry that opens a broken scene is worse than no entry.
function Screen:_EnsureList()
    if self.list then return self.list end
    if not self.control then return nil end
    -- Granular reasons: "could not build the list" was too coarse to act on
    -- when this failed on hardware. Name the exact missing global instead.
    local function fail(why)
        if self.addon and self.addon.Diagnostic then
            self.addon:Diagnostic("warn", "[priorities] list not built: %s", why)
        end
        self._lastListFailure = why
        return nil
    end
    if type(CreateControlFromVirtual) ~= "function" then
        return fail("CreateControlFromVirtual unavailable")
    end
    if type(ZO_GamepadVerticalItemParametricScrollList) ~= "table" then
        return fail("ZO_GamepadVerticalItemParametricScrollList unavailable")
    end

    local screen = self
    local ok, err = pcall(function()
        local container = CreateControlFromVirtual(
            "AccountHoldPrioritiesGamepadListContainer", screen.control,
            "ZO_Gamepad_ParametricList_Screen_ListContainer")
        screen.listContainer = container

        -- Quadrant 1 is where GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT paints
        -- the list background, so anchor to that control when it exists and fall
        -- back to filling our own top-level window otherwise. Geometry is the
        -- one part of this file that cannot be checked without hardware.
        container:ClearAnchors()
        local quadrant = _G and _G["ZO_GamepadNavQuadrant_1_Background"]
        if type(quadrant) == "table" or type(quadrant) == "userdata" then
            container:SetAnchor(TOPLEFT, quadrant, TOPLEFT, 0, 0)
            container:SetAnchor(BOTTOMRIGHT, quadrant, BOTTOMRIGHT, 0, 0)
        else
            container:SetAnchor(TOPLEFT, screen.control, TOPLEFT, 0, 0)
            container:SetAnchor(BOTTOMRIGHT, screen.control, BOTTOMRIGHT, 0, 0)
        end

        local listControl = container.list or container:GetNamedChild("List")
        local list = ZO_GamepadVerticalItemParametricScrollList:New(listControl)

        if list.SetAlignToScreenCenter then list:SetAlignToScreenCenter(true) end

        -- One row template, with and without a header, so the "Do this next" /
        -- "Wanted" sections render as real gamepad section headers rather than
        -- as fake rows the cursor can land on.
        if list.AddDataTemplate and ZO_SharedGamepadEntry_OnSetup
           and ZO_GamepadMenuEntryTemplateParametricListFunction then
            list:AddDataTemplate("ZO_GamepadMenuEntryTemplate",
                ZO_SharedGamepadEntry_OnSetup,
                ZO_GamepadMenuEntryTemplateParametricListFunction)
        end
        if list.AddDataTemplateWithHeader and ZO_SharedGamepadEntry_OnSetup
           and ZO_GamepadMenuEntryTemplateParametricListFunction then
            list:AddDataTemplateWithHeader("ZO_GamepadMenuEntryTemplate",
                ZO_SharedGamepadEntry_OnSetup,
                ZO_GamepadMenuEntryTemplateParametricListFunction,
                nil, "ZO_GamepadMenuEntryHeaderTemplate")
        end

        -- Selection changes only ever refresh the keybind strip. They must not
        -- reach any travel API (ToS rule 4).
        local onChanged = function(_, selectedData)
            screen:OnTargetChanged(selectedData)
        end
        if list.SetOnTargetDataChangedCallback then
            list:SetOnTargetDataChangedCallback(onChanged)
        elseif list.SetOnSelectedDataChangedCallback then
            list:SetOnSelectedDataChangedCallback(onChanged)
        end

        screen.list = list
    end)

    if not ok then
        if self.addon and self.addon.Diagnostic then
            self.addon:Diagnostic("warn",
                "[priorities] Could not build the gamepad list: %s", shortErr(err))
        end
        self.list = nil
        return nil
    end
    return self.list
end

-- ---------------------------------------------------------------------------
-- Population
-- ---------------------------------------------------------------------------

function Screen:Populate()
    local list = self:_EnsureList()
    if not list then
        -- The list still cannot be built. Say so on screen: the player opened
        -- this deliberately, so a blank panel would look like a hang. The
        -- diagnostics buffer already carries the specific reason.
        self._lastPopulateFailed = true
        local addon = self.addon
        if addon and addon.Notify and addon.Notify.Alert then
            pcall(function()
                addon.Notify:Alert(L("SI_ACCOUNTHOLD_PRIO_LIST_FAILED",
                    "Priorities could not open. Use Show recent diagnostics for details."))
            end)
        end
        return
    end
    self._lastPopulateFailed = nil
    if type(ZO_GamepadEntryData) ~= "table" then return end

    local rows = self:Rows()
    self.rows = rows

    if list.Clear then pcall(function() list:Clear() end) end

    for i = 1, #rows do
        local row = rows[i]
        local ok, data = pcall(function()
            local d = ZO_GamepadEntryData:New(row.name)
            d.accountHoldPriorityRow = row
            if d.SetIconTintOnSelection then d:SetIconTintOnSelection(true) end
            if row.subLabels and #row.subLabels > 0 and d.SetSubLabels then
                d:SetSubLabels(row.subLabels)
                if d.SetShowUnselectedSublabels then
                    d:SetShowUnselectedSublabels(true)
                end
            end
            if row.header then
                d.header = row.header
                if d.SetHeader then d:SetHeader(row.header) end
            end
            return d
        end)
        if ok and data then
            local added = false
            if row.header and list.AddEntryWithHeader then
                added = pcall(function()
                    list:AddEntryWithHeader("ZO_GamepadMenuEntryTemplate", data)
                end)
            end
            if not added and list.AddEntry then
                pcall(function()
                    list:AddEntry("ZO_GamepadMenuEntryTemplate", data)
                end)
            end
        end
    end

    if list.Commit then pcall(function() list:Commit() end) end
    self:RefreshKeybinds()
end

-- Rebuild after a wishlist change. Deliberately re-reads the model rather than
-- mutating rows in place, so what is on screen is always what BuildPlan says.
function Screen:Refresh()
    if not self.control then return end
    self:Populate()
end

function Screen:OnTargetChanged(_selectedData)
    -- Nothing but keybinds. See ToS rule 4 -- this runs on every cursor move.
    self:RefreshKeybinds()
end

function Screen:SelectedRow()
    -- The dialog surface (Screen:Show) has no parametric list of its own; it
    -- sets this override before invoking an action so every existing action
    -- handler keeps working unchanged against either surface.
    if type(self._selectedRowOverride) == "table" then
        return self._selectedRowOverride
    end
    local list = self.list
    if type(list) ~= "table" then return nil end
    local data
    if list.GetTargetData then
        local ok, d = pcall(list.GetTargetData, list)
        if ok then data = d end
    end
    if type(data) ~= "table" then return nil end
    return data.accountHoldPriorityRow
end

-- ---------------------------------------------------------------------------
-- Keybinds
-- ---------------------------------------------------------------------------

-- Every closure below runs inside ZOS's own (UNHARDENED) keybind update loop,
-- so none of them may propagate an error. Same discipline as
-- ui/InventoryTab_Gamepad.lua:1630-1690.
local function safeBool(fn)
    local ok, value = pcall(fn)
    return (ok and value) and true or false
end

local function safeText(fn, fallback)
    local ok, value = pcall(fn)
    if ok and type(value) == "string" and value ~= "" then return value end
    return fallback
end

function Screen:Keybinds()
    if self.keybinds then return self.keybinds end
    local screen = self

    local function selectedRowType()
        local row = screen:SelectedRow()
        return row and row.rowType or nil
    end

    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_RIGHT,
        {
            -- (A) Travel. `visible` is a pure structural test: is the cursor on
            -- a real activity row? It must NOT resolve a node -- that is both a
            -- full walk of GetNumFastTravelNodes on every cursor move and the
            -- exact blurring of the ToS boundary 0005 forbids.
            name    = function()
                return safeText(function()
                    return L("SI_ACCOUNTHOLD_PRIO_BTN_TRAVEL", "Travel")
                end, "Travel")
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return safeBool(function()
                    local row = screen:SelectedRow()
                    if not row or row.rowType ~= ROW_ACTIVITY then return false end
                    -- The synthetic "source unknown" row describes no place, so
                    -- there is nothing to travel to (src/Travel.lua returns nil
                    -- for it anyway; hiding the keybind avoids offering an
                    -- action that can only fail).
                    return not row.isUnknown
                end)
            end,
            callback = function() screen:OfferTravelForSelected() end,
        },
        {
            -- (X) Drop something off the wishlist. Only ever offered on a
            -- wishlist row, where "the priority under the cursor" is exactly one
            -- record -- an activity row can cover several wanted sets and would
            -- make this destructive and ambiguous.
            name    = function()
                return safeText(function()
                    return L("SI_ACCOUNTHOLD_PRIO_BTN_REMOVE", "Remove from wanted")
                end, "Remove from wanted")
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return safeBool(function() return selectedRowType() == ROW_PRIORITY end)
            end,
            callback = function() screen:RemoveSelectedPriority() end,
        },
    }

    -- (B) back out of the scene to the pause menu. Without an explicit back
    -- entry our own keybind group leaves the player with no way off this scene.
    local function backCallback()
        -- Method guard, not type(). SCENE_MANAGER is userdata on hardware, so
        -- the old `type(SCENE_MANAGER) == "table"` test was false in game and
        -- this never ran -- the player pressed B and fell through to the game
        -- instead of returning to Collections (docs/BUGS.md PRI-6).
        local hide = Safe.Method(SCENE_MANAGER, "HideCurrentScene")
        if hide then pcall(hide, SCENE_MANAGER) end
    end
    if type(ZO_Gamepad_AddBackNavigationKeybindDescriptors) == "function"
       and type(GAME_NAVIGATION_TYPE_BUTTON) ~= "nil" then
        pcall(function()
            ZO_Gamepad_AddBackNavigationKeybindDescriptors(
                self.keybinds, GAME_NAVIGATION_TYPE_BUTTON, backCallback)
        end)
    else
        -- Test harness / older client: replicate the helper's BUTTON entry.
        self.keybinds[#self.keybinds + 1] = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name      = function() return L("SI_ACCOUNTHOLD_PRIO_BTN_BACK", "Back") end,
            keybind   = "UI_SHORTCUT_NEGATIVE",
            order     = -1500,
            callback  = backCallback,
        }
    end

    return self.keybinds
end

function Screen:RefreshKeybinds()
    if type(KEYBIND_STRIP) ~= "table" then return end
    if not self._keybindsActive then return end
    if KEYBIND_STRIP.UpdateKeybindButtonGroup then
        pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(self:Keybinds()) end)
    end
end

-- ---------------------------------------------------------------------------
-- Travel
-- ---------------------------------------------------------------------------

local function alert(message)
    if type(message) ~= "string" or message == "" then return end
    local notify = AccountHold and AccountHold.Notify
    if notify and type(notify.Alert) == "function" then
        pcall(function() notify:Alert(message) end)
    end
end

-- THE ONLY CALLER OF Travel:TravelTo IN THE UI LAYER.
--
-- `token` must be CONFIRM_TOKEN, which is captured exclusively by the travel
-- dialog's confirm-button closure. A refresh, a render, a selection change or
-- an event handler has no way to name that value, so this function is
-- structurally unreachable from any of them -- which is precisely what 0005's
-- ToS-critical test asserts.
--
-- Exposed on the module so the harness can call it directly and observe the
-- refusal; that visibility does not weaken the guarantee, because the token is
-- still a file-local upvalue.
function Screen._PerformTravel(data, token)
    if token ~= CONFIRM_TOKEN then
        -- Not a player confirmation. Refuse and say so loudly enough to show up
        -- in a diagnostics dump, because reaching here means a wiring bug that
        -- would otherwise be an automation path.
        local addon = AccountHold and AccountHold.UI
            and AccountHold.UI.PrioritiesScreenGamepad
            and AccountHold.UI.PrioritiesScreenGamepad.addon
        if addon and addon.Diagnostic then
            addon:Diagnostic("error",
                "[priorities] Travel was requested without a player confirmation - refused.")
        end
        return false, "not_confirmed"
    end
    if type(data) ~= "table" then return false, "not_confirmed" end

    local travel = AccountHold and AccountHold.Travel
    if type(travel) ~= "table" or type(travel.ShowOnMap) ~= "function" then
        return false, "no_api"
    end

    -- Opens ESO's own world map centred on the wayshrine and lets the PLAYER
    -- make the jump through the base game's native confirmation. We deliberately
    -- do NOT call Travel:TravelTo here: routing through the map means this
    -- add-on never invokes FastTravelToNode at all, so there is no automation
    -- surface to defend on this path -- the player is always the one travelling.
    --
    -- ShowOnMap returns (shown, reason) -- both captured. Collapsing a
    -- multi-return through a one-result wrapper is the bug class that cost this
    -- add-on a whole filter category.
    local ok, performed, reason = pcall(travel.ShowOnMap, travel, data.nodeIndex)
    if not ok then return false, "no_api" end
    if not performed then
        if type(travel.GetReasonText) == "function" then
            local okText, text = pcall(travel.GetReasonText, travel, reason)
            if okText then alert(text) end
        end
        return false, reason
    end
    return true, reason
end

-- The old TRAVEL_DIALOG (a cost-confirmation whose confirm button read
-- "Show on Map") was REMOVED. It was vestigial from when this action
-- really travelled, it quoted a cost that was never charged, and it stood
-- between the player and the map they asked for. A is now a direct map
-- open -- see Screen:OfferTravelForSelected.
local function showPlatformDialog(name, data)
    -- ShowPlatformDialog picks gamepad on console and keyboard on PC. The
    -- explicit fallbacks exist for older clients only; ZO_Dialogs_ShowDialog is
    -- last because it is the keyboard path.
    local show = ZO_Dialogs_ShowPlatformDialog
        or ZO_Dialogs_ShowGamepadDialog
        or ZO_Dialogs_ShowDialog
    if type(show) ~= "function" then return false end
    local ok = pcall(show, name, data)
    return ok
end

-- Resolve a destination and ASK. This function never travels; its last act is
-- to show a dialog. Reached only from the (A) keybind callback.
-- (A) "Show Map" -- open ESO's own world map on this activity's wayshrine.
--
-- This USED to open a confirmation dialog reading "Travel to X? Cost: N gold"
-- whose confirm button was labelled "Show on Map". That was vestigial: it dates
-- from when this action really did travel, and it survived the change to
-- map-only. It asked the player to agree to a cost that was never charged, and
-- it put a second dialog between them and the map. Reported from hardware:
-- "The show map does not actually pull up a map, but it does currently tell me
-- how much it would cost to travel. I would prefer it pull up the map."
--
-- So the cost dialog is gone and the map opens directly. Nothing is confirmed
-- because nothing is spent -- ZO_WorldMap_ShowWorldMap only shows a scene
-- (worldmap.lua:3184, which routes to "gamepad_worldMap" on console). The
-- PLAYER then travels from the map through the base game's own confirmation,
-- which is what keeps FastTravelToNode out of this add-on's hands entirely.
--
-- CanTravelTo is deliberately NOT consulted. It answers "can you teleport right
-- now" (combat, cooldown), which has no bearing on whether a map may be looked
-- at. Gating on it meant a player in combat asking "where is this?" got a
-- refusal instead of a map. ShowOnMap still refuses an undiscovered wayshrine,
-- which is the check that actually matters, because there is no pin to focus.
function Screen:OfferTravelForSelected()
    local row = self:SelectedRow()
    if not row or row.rowType ~= ROW_ACTIVITY or row.isUnknown then return end

    local travel = AccountHold and AccountHold.Travel
    if type(travel) ~= "table" or type(travel.FindNodeForActivity) ~= "function" then
        alert(L("SI_ACCOUNTHOLD_TRAVEL_NO_API", "Travel is unavailable on this client"))
        return
    end

    -- FindNodeForActivity returns (nodeIndex, matchKind) -- the tuple is
    -- captured in full; collapsing a multi-return through a one-result wrapper
    -- is the bug class that cost this add-on a whole filter category.
    local okFind, nodeIndex, matchKind = pcall(travel.FindNodeForActivity, travel, row.activity)
    if not okFind or type(nodeIndex) ~= "number" then
        local text = L("SI_ACCOUNTHOLD_TRAVEL_UNKNOWN_NODE",
                       "No wayshrine known for this activity")
        if type(travel.GetReasonText) == "function" then
            local okText, t = pcall(travel.GetReasonText, travel, "unknown_node")
            if okText and type(t) == "string" and t ~= "" then text = t end
        end
        alert(text)
        return
    end

    -- A zone match lands on the zone's wayshrine, not the activity's door. That
    -- is worth saying, but it is a note on a map -- not a reason to interrupt
    -- with a dialog.
    if type(travel.GetMatchCaveatText) == "function" then
        local okCaveat, t = pcall(travel.GetMatchCaveatText, travel, matchKind)
        if okCaveat and type(t) == "string" and t ~= "" then alert(t) end
    end

    -- Routed through the guarded chokepoint rather than calling ShowOnMap
    -- directly, so this file keeps exactly ONE place that acts on a node and
    -- that place keeps refusing anything that cannot name CONFIRM_TOKEN.
    Screen._PerformTravel({ nodeIndex = nodeIndex }, CONFIRM_TOKEN)
end

-- ---------------------------------------------------------------------------
-- Removing a priority
-- ---------------------------------------------------------------------------

local removeDialogRegistered = false
local function ensureRemoveDialog()
    if removeDialogRegistered then return end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return end
    removeDialogRegistered = true
    ZO_Dialogs_RegisterCustomDialog(REMOVE_DIALOG, {
        canQueue    = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC or 1 },
        title       = { text = L("SI_ACCOUNTHOLD_PRIO_REMOVE_TITLE", "Stop tracking") },
        mainText    = {
            text = function(dialog)
                local ok, text = pcall(function()
                    local d = (dialog and dialog.data) or {}
                    return string.format(
                        L("SI_ACCOUNTHOLD_PRIO_REMOVE_BODY", "Stop tracking %s?"),
                        tostring(d.label or "?"))
                end)
                if ok and type(text) == "string" then return text end
                return L("SI_ACCOUNTHOLD_PRIO_REMOVE_BODY", "Stop tracking %s?")
            end,
        },
        buttons = {
            {
                text     = L("SI_ACCOUNTHOLD_PRIO_REMOVE_CONFIRM", "Remove"),
                keybind  = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local screen = AccountHold and AccountHold.UI
                        and AccountHold.UI.PrioritiesScreenGamepad
                    if not screen then return end
                    local d = (dialog and dialog.data) or {}
                    local ok, err = pcall(function()
                        screen:_RemovePriorityConfirmed(d)
                    end)
                    if not ok and screen.addon and screen.addon.Diagnostic then
                        screen.addon:Diagnostic("error",
                            "[priorities] Remove failed: %s", shortErr(err))
                    end
                    -- Back to the list the player started from, not out to the
                    -- world. Only when the dialog surface opened this; the scene
                    -- path has its own list still standing behind it.
                    if d.returnToDialog then
                        Screen._ReturnToPriorities(REMOVE_DIALOG)
                    end
                end,
            },
            {
                text    = L("SI_ACCOUNTHOLD_DIALOG_CANCEL", "Cancel"),
                keybind = "DIALOG_NEGATIVE",
                callback = function(dialog)
                    local d = (dialog and dialog.data) or {}
                    if d.returnToDialog then
                        Screen._ReturnToPriorities(REMOVE_DIALOG)
                    end
                end,
            },
        },
    })
end

Screen._EnsureRemoveDialog = ensureRemoveDialog

function Screen:RemoveSelectedPriority()
    local row = self:SelectedRow()
    if not row or row.rowType ~= ROW_PRIORITY then return end
    local rec = row.priority
    if type(rec) ~= "table" or rec.id == nil then return end

    ensureRemoveDialog()
    showPlatformDialog(REMOVE_DIALOG, {
        priorityId = rec.id,
        label      = row.name,
    })
end

-- Separate from the dialog so it can be pcall'd from the button callback and
-- driven directly by a test, exactly like Blade:_ClearMyHoldsUnsafe.
function Screen:_RemovePriorityConfirmed(data)
    if type(data) ~= "table" then return false end
    local p = AccountHold and AccountHold.Priorities
    if type(p) ~= "table" or type(p.Remove) ~= "function" then return false end
    local ok, removed = pcall(p.Remove, p, data.priorityId)
    if not ok then return false end
    -- Repaint from the model so the plan reflects the removal immediately --
    -- dropping a wanted set can also drop a whole activity off the plan.
    self:Refresh()
    return removed and true or false
end

-- ---------------------------------------------------------------------------
-- Scene lifecycle
-- ---------------------------------------------------------------------------

function Screen:Initialize(addonRef)
    self.addon = addonRef
end

-- Called by ui/PrioritiesMenu_Gamepad.lua once it has a top-level window and a
-- registered scene. Returns true only when a usable list exists: the menu file
-- refuses to insert its pause-menu row unless this returns true, so the player
-- can never reach a scene that has nothing on it.
function Screen:AttachTo(control, scene)
    if control == nil then return false end
    self.control = control
    self.scene   = scene

    -- The list is built LAZILY, not here.
    --
    -- It was originally a precondition, which meant a failure at
    -- EVENT_ADD_ON_LOADED (when some gamepad UI globals and virtual templates
    -- are not yet resolvable) permanently suppressed the pause-menu entry for
    -- the whole session -- the "I don't see the Priorities menu" failure.
    -- Populate calls _EnsureList on every show, so deferring costs nothing and
    -- the first show retries with a fully-loaded UI. If it still cannot build,
    -- Populate renders an explicit error row rather than a blank screen, which
    -- is far more useful to the player than a missing menu entry.
    self:_EnsureList()

    if type(scene) == "table" and type(scene.RegisterCallback) == "function"
       and not self._sceneHooked then
        local screen = self
        local ok = pcall(function()
            scene:RegisterCallback("StateChange", function(_, newState)
                -- Never let a scene callback throw: an error here fires while
                -- the pause menu is pushing our scene.
                pcall(function() screen:OnSceneStateChange(newState) end)
            end)
        end)
        if ok then
            -- Registering twice would populate twice on every show.
            self._sceneHooked = true
        elseif self.addon and self.addon.Diagnostic then
            -- Non-fatal on purpose. Returning false here would suppress the
            -- pause-menu entry for the whole session over a hook we can retry:
            -- _sceneHooked stays false, so the next AttachTo tries again.
            self.addon:Diagnostic("warn",
                "[priorities] scene StateChange hook failed; will retry")
        end
    end

    return true
end

function Screen:OnSceneStateChange(newState)
    if newState == SCENE_SHOWING then
        self:Populate()
    elseif newState == SCENE_SHOWN then
        self:Activate()
    elseif newState == SCENE_HIDING then
        self:Deactivate()
    elseif newState == SCENE_HIDDEN then
        self:Deactivate()
    end
end

function Screen:Activate()
    if self.list and self.list.Activate then
        pcall(function() self.list:Activate() end)
    end
    -- Guard on the METHOD, never on type() == "table".
    --
    -- This read `type(KEYBIND_STRIP) == "table"`, which is FALSE on hardware:
    -- ESO engine globals are userdata (globalvars.lua:2-4). The whole keybind
    -- group therefore never registered on console, which is why the player
    -- reported BOTH "there is no way to remove a priority" (the X / Remove
    -- from wanted button lives in this group) and "B backs out to the game
    -- instead of Collections" (so does the back navigation entry). One dead
    -- gate, two symptoms. See docs/BUGS.md PRI-6.
    local add = Safe.Method(KEYBIND_STRIP, "AddKeybindButtonGroup")
    if add then
        local ok = pcall(add, KEYBIND_STRIP, self:Keybinds())
        self._keybindsActive = ok and true or false
    end
end

function Screen:Deactivate()
    if self.list and self.list.Deactivate then
        pcall(function() self.list:Deactivate() end)
    end
    local remove = Safe.Method(KEYBIND_STRIP, "RemoveKeybindButtonGroup")
    if remove then
        pcall(remove, KEYBIND_STRIP, self:Keybinds())
    end
    self._keybindsActive = false
end

-- ---------------------------------------------------------------------------
-- Dialog surface (the one that actually works on console)
-- ---------------------------------------------------------------------------
-- WHY THIS EXISTS AND WHY IT REPLACED THE SCENE
--
-- The original surface was a custom ZO_Scene backed by a
-- ZO_GamepadVerticalItemParametricScrollList built from CreateControlFromVirtual
-- at add-on load. That failed repeatedly on real Xbox hardware -- the control
-- tree simply never built -- and because the pause-menu entry was GATED on it,
-- the entry silently never appeared at all.
--
-- A parametric gamepad DIALOG has none of those dependencies: no top-level
-- window, no scene registration, no runtime control tree. The same mechanism
-- already works on this player's hardware (ui/PrioritiesSetsBook_Gamepad.lua).
--
-- The scene path above is left intact and harmless: if it ever does build, it
-- still works. This is simply the path the menu entry uses.
--
-- Verified contract (esoui/esoui @ master):
--   zo_dialog.lua:1207-1209              RegisterCustomDialog -> ESO_Dialogs[name] = info
--   zo_genericdialog_gamepad.lua:745     templateData.setup is called UNCONDITIONALLY
--   zo_genericdialog_gamepad.lua:785     ipairs over dialog.info.parametricList, every open
--   zo_genericdialog_gamepad.lua:791-795 `visible` is read from templateData
--   zo_genericdialog_gamepad.lua:801-807 a `text` FUNCTION is entry-level only
--   zo_genericdialog_gamepad.lua:833-838 `header` is entry-level and static
--   itemsetcollectionsmanager.lua:171-195 the buttons array shape
--
-- === WHY THE LIST WAS EMPTY FOR FOUR ROUNDS =================================
--
-- The `setup` this file passes to ZO_Dialogs_RegisterCustomDialog is the ONLY
-- thing that ever builds the parametric list: zo_dialog.lua:603-605 calls
-- dialogInfo.setup(dialog, data, textParams), and for a PARAMETRIC gamepad
-- dialog it is dialog:setupFunc() -- assigned
-- ZO_GenericParametricListGamepadDialogTemplate_Setup at
-- zo_genericdialog_gamepad.lua:692 -- that walks dialog.info.parametricList
-- (:785) and adds the entries.
--
-- The previous `setup` was:
--
--     if type(dialog) == "table" and type(dialog.setupFunc) == "function" then
--         dialog:setupFunc()
--     end
--
-- `dialog` here is the dialog CONTROL returned by
-- ZO_GenericGamepadDialog_GetControl (zo_genericdialog_gamepad.lua:309-321) --
-- ZO_GamepadDialogPara, an XML-declared control. ESO controls are Lua
-- **userdata**, not tables. The base game itself uses exactly that distinction:
--   zo_keybindstrip.lua   GetDescriptorFromButton -> `type(x) == "userdata"`
--                         separates a control from a descriptor TABLE
--   zo_contextmenus.lua   SetMenuOwner            -> `type(owner) == "userdata"`
--   craftingcreateslotanimation.lua GetSlotControl-> `type(slot) == "userdata"`
--   debugutils.lua        mon()                   -> `type(moc()) == "userdata"`
--
-- So `type(dialog) == "table"` was FALSE on hardware, dialog:setupFunc() never
-- ran, the entry list was never rebuilt -- and because
-- ZO_GenericParametricListGamepadDialogTemplate_OnInitialized's hideFunction
-- calls dialog.entryList:Clear() on every hide (:697-703), the shared
-- ZO_GamepadDialogPara list was empty every single time. The dialog opened
-- with a title and nothing else: exactly "no dungeons, no gear sets".
--
-- It cost four rounds because the guard LOOKS defensive, the model tests pass
-- (they never reach Show()), and the failure produced no words at all. Both
-- halves are fixed below: the control test now accepts userdata, and every path
-- out of Show() either renders entries or SAYS why it could not.
-- =============================================================================

local PRIORITIES_DIALOG = "ACCOUNT_HOLD_PRIORITIES_DIALOG"
Screen._DIALOG_NAME = PRIORITIES_DIALOG

-- THE row template. This is the single biggest visual defect the player
-- reported, and it is a one-word bug:
--
--   ZO_GamepadFullWidthLeftLabelEntryTemplate
--       -> ZO_GamepadFullWidthLabelTemplate (zo_gamepadtemplatescommon.xml:586)
--       -> ZO_GamepadMenuEntryLabelTemplate (:212-215) which declares
--          modifyTextType="UPPERCASE", AND HAS NO ICON CHILD.
--   ZO_GamepadItemSubEntryTemplate (ingame/gamepad/gamepadtemplates/
--       gamepadtemplates.xml) -> ZO_GamepadSubMenuEntryTemplate (:278-291)
--       -> ZO_GamepadSubMenuEntryLabelTemplate (:188-191): ZoFontGamepad34,
--          NO modifyTextType, indented, with an Icon/SubStatusIcon/StackCount.
--
-- So every row on this blade was being shouted in capitals with no icon. The
-- sub-entry template is what the real Armory list (ingame/armory/gamepad/
-- armory_gamepad.lua:303, :412, :514) and the base game's own item rows inside
-- a PARAMETRIC DIALOG (ingame/crafting/gamepad/consolidatedsmithingsets_gamepad
-- .lua:494) use, so it is proven to work in this exact context.
--
-- Full-width UPPERCASE is kept as the fallback because it is what
-- itemsetcollectionsmanager.lua:143 uses for a dialog ACTION row -- a correct
-- native look in its own right, and the value this blade shipped with. If the
-- native template cannot be instantiated on some client, _DialogSetup demotes
-- to it and rebuilds rather than leaving the player with an empty dialog.
--
-- ONE template for the whole list, deliberately: the FIRST entry using a given
-- template fixes the header template for every later entry using it
-- (zo_genericdialog_gamepad.lua:825-827), so mixing templates would make the
-- two section headers disagree with each other.
local DIALOG_ENTRY_TEMPLATE          = "ZO_GamepadItemSubEntryTemplate"
local DIALOG_ENTRY_TEMPLATE_FALLBACK = "ZO_GamepadFullWidthLeftLabelEntryTemplate"
Screen._DIALOG_ENTRY_TEMPLATE          = DIALOG_ENTRY_TEMPLATE
Screen._DIALOG_ENTRY_TEMPLATE_FALLBACK = DIALOG_ENTRY_TEMPLATE_FALLBACK

-- The template actually in use. Only ever demoted, never promoted back inside a
-- session: a client that cannot draw the native template will not start being
-- able to.
function Screen._EntryTemplate()
    return Screen._DIALOG_ENTRY_TEMPLATE
end

function Screen._DemoteEntryTemplate()
    if Screen._DIALOG_ENTRY_TEMPLATE == DIALOG_ENTRY_TEMPLATE_FALLBACK then return false end
    Screen._DIALOG_ENTRY_TEMPLATE = DIALOG_ENTRY_TEMPLATE_FALLBACK
    return true
end

-- A dialog CONTROL is userdata on hardware and a plain table under the test
-- harness. Accept both, and NEVER reject on the container type alone -- that is
-- the bug documented above. Exposed so a regression test can prove a userdata
-- value is accepted.
function Screen._IsDialogControl(dialog)
    local t = type(dialog)
    return (t == "userdata" or t == "table") and true or false
end

-- Fold a row's sub-labels into one line. PURE. This is the DEGRADED rendering:
-- a client with no ZO_GamepadEntryData gets one flat string rather than a blank
-- row, and every existing harness assertion about entry.text keeps holding.
function Screen._FoldRowText(row)
    if type(row) ~= "table" then return "?" end
    local text = row.name or "?"
    if type(row.subLabels) == "table" and #row.subLabels > 0 then
        local detail = table.concat(row.subLabels, "  -  ")
        if detail ~= "" then text = text .. "  (" .. detail .. ")" end
    end
    return text
end

-- Build a real ZO_GamepadEntryData for a row: mixed-case name on the main
-- label, every detail on its own sub-label, an icon, and display-quality
-- colouring where a genuine item link exists.
--
-- Verified construction, copied from the base game rather than invented:
--   ZO_GamepadEntryData:New(text, icon)      zo_gamepadentrydata.lua:10-11
--   :AddSubLabel(sub)                        :366-371   (there is no SetSubLabels)
--   :SetSubLabelColors(colour)               :324
--   :SetShowUnselectedSublabels(true)        :379   -- both taken together from
--       InitializeTradingHouseVisualData:48-52, the base game's own recipe for
--       "row with permanently visible secondary text"
--   :SetFontScaleOnSelection(false)          :35    -- "item entries don't grow
--       on selection"; only menu/category rows scale
--   :SetIconTintOnSelection(true)            armory_gamepad.lua:305, :412
--   :SetNameColors(:GetColorsBasedOnQuality(displayQuality))  :32, :209-214
--
-- FAILS CLOSED, and that is the whole point: any missing global, any missing
-- method, any throw anywhere returns nil, and _RowsToDialogEntries falls back
-- to the flat text entry that this blade already shipped. Styling must never be
-- able to blank a screen that works.
function Screen._MakeRowEntryData(row, setupFn)
    if type(row) ~= "table" then return nil end
    if type(ZO_GamepadEntryData) ~= "table" then return nil end
    if type(ZO_GamepadEntryData.New) ~= "function" then return nil end

    local built
    local ok = pcall(function()
        local data = ZO_GamepadEntryData:New(row.name or "?", row.icon)
        if type(data) ~= "table" then return end

        -- Optional polish. Each call is guarded on its own so that a client
        -- missing ONE method still gets everything else.
        local function try(method, ...)
            if type(data[method]) == "function" then
                pcall(data[method], data, ...)
            end
        end

        if type(row.subLabels) == "table" then
            for i = 1, #row.subLabels do
                local sub = row.subLabels[i]
                if type(sub) == "string" and sub ~= "" then try("AddSubLabel", sub) end
            end
        end
        if type(ZO_NORMAL_TEXT) == "table" then try("SetSubLabelColors", ZO_NORMAL_TEXT) end
        try("SetShowUnselectedSublabels", true)
        try("SetFontScaleOnSelection", false)
        try("SetIconTintOnSelection", true)

        -- Colour by DISPLAY quality, never functional quality
        -- (sharedinventory.lua:649,651). Only a genuine item link can answer
        -- this; a set has no single quality, so set rows stay default-coloured
        -- exactly as native item-set rows do.
        if type(row.itemLink) == "string" and row.itemLink ~= ""
           and type(GetItemLinkDisplayQuality) == "function"
           and type(data.GetColorsBasedOnQuality) == "function"
           and type(data.SetNameColors) == "function" then
            local okQ, quality = pcall(GetItemLinkDisplayQuality, row.itemLink)
            if okQ and quality ~= nil then
                pcall(function()
                    data:SetNameColors(data:GetColorsBasedOnQuality(quality))
                end)
            end
        end

        -- A PREMADE entryData is used verbatim: zo_genericdialog_gamepad.lua
        -- only copies templateData onto the entry data when it BUILDS one
        -- (:801-819). So setup and our row payload have to live on the entry
        -- data itself, or :745 calls a nil setup and the whole rebuild throws.
        data.setup = setupFn
        data.accountHoldPriorityRow = row
        -- PRI-11: screen narration reads the detail panel with the row, the
        -- same field the base game sets on rows whose detail lives in the
        -- dialog tooltip (consolidatedsmithingsets_gamepad.lua:490).
        if GAMEPAD_LEFT_DIALOG_TOOLTIP ~= nil then
            data.narrationTooltip = GAMEPAD_LEFT_DIALOG_TOOLTIP
        end
        built = data
    end)

    if ok then return built end
    return nil
end

-- Turn Screen:Rows() into dialog parametric entries. Pure apart from the
-- GetString lookups, so the row->entry mapping is testable on its own.
function Screen._RowsToDialogEntries(rows, setupFn)
    local entries = {}
    if type(rows) ~= "table" then return entries end
    local template = Screen._EntryTemplate()
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" then
            local entry = {
                template = template,
                header   = row.header,
                -- Fallback path only. When entryData is present the base
                -- rebuild loop ignores text and icon entirely (:801).
                text     = Screen._FoldRowText(row),
                icon     = row.icon,
                templateData = {
                    setup = setupFn,
                    accountHoldPriorityRow = row,
                },
            }
            entry.entryData = Screen._MakeRowEntryData(row, setupFn)
            entries[#entries + 1] = entry
        end
    end
    return entries
end

-- Rebuild the registered dialog's parametricList from the current model. Used
-- by the template-demotion retry in _DialogSetup: the entries already handed to
-- the base game carry the template that just failed, so they have to be
-- regenerated before the rebuild is attempted again.
function Screen._RepopulateDialogList()
    if type(ESO_Dialogs) ~= "table" then return false end
    local info = ESO_Dialogs[PRIORITIES_DIALOG]
    if type(info) ~= "table" or type(info.parametricList) ~= "table" then return false end

    local okRows, rows = pcall(Screen.Rows, Screen)
    if not okRows or type(rows) ~= "table" then return false end

    local setupFn = (type(ZO_SharedGamepadEntry_OnSetup) == "function")
        and ZO_SharedGamepadEntry_OnSetup or nil
    local entries = Screen._RowsToDialogEntries(rows, setupFn)
    if #entries == 0 then return false end

    -- In place: dialog.info is the same table object the base game holds
    -- (zo_dialog.lua:482), so mutating the list it already points at is the
    -- safest way to change what the next rebuild walks.
    local list = info.parametricList
    for i = #list, 1, -1 do list[i] = nil end
    for i = 1, #entries do list[i] = entries[i] end
    return true
end

-- Count what is on the plan for the one-line summary above the list. Pure.
function Screen._SummaryText(rows, errText)
    -- string.format is pcall'd throughout: a translation that declares the wrong
    -- specifier must degrade to a readable line, never throw and blank the blade.
    if type(errText) == "string" and errText ~= "" then
        local okE, msg = pcall(string.format,
            L("SI_ACCOUNTHOLD_PRIO_SUMMARY_ERROR",
              "Could not read your priorities: %s"), errText)
        if okE and type(msg) == "string" then return msg end
        return "Could not read your priorities: " .. errText
    end
    local activities, wanted = 0, 0
    if type(rows) == "table" then
        for i = 1, #rows do
            local r = rows[i]
            if type(r) == "table" then
                if r.rowType == ROW_ACTIVITY then
                    activities = activities + 1
                elseif r.rowType == ROW_PRIORITY then
                    wanted = wanted + 1
                end
            end
        end
    end
    if activities == 0 and wanted == 0 then
        return L("SI_ACCOUNTHOLD_PRIO_EMPTY_HINT",
                 "Nothing wanted yet. Collections > Item Sets, highlight a set piece, press Y.")
    end
    -- PRI-1: one short line that fits the blade header without wrapping, with
    -- real singular/plural wording instead of "activity(s)" / "set(s)/item(s)".
    local function count(n, oneId, oneText, manyId, manyText)
        local fmt = (n == 1) and L(oneId, oneText) or L(manyId, manyText)
        local okF, s = pcall(string.format, fmt, n)
        if okF and type(s) == "string" then return s end
        return tostring(n)
    end
    local runPart = count(activities,
        "SI_ACCOUNTHOLD_PRIO_SUMMARY_ACTIVITY_ONE",  "%d activity",
        "SI_ACCOUNTHOLD_PRIO_SUMMARY_ACTIVITY_MANY", "%d activities")
    local wantPart = string.format("%d", wanted)
    local okW, w = pcall(string.format, L("SI_ACCOUNTHOLD_PRIO_SUMMARY_WANTED", "%d wanted"), wanted)
    if okW and type(w) == "string" then wantPart = w end
    local okS, summary = pcall(string.format,
        L("SI_ACCOUNTHOLD_PRIO_SUMMARY", "%s, %s"), runPart, wantPart)
    if okS and type(summary) == "string" then return summary end
    return runPart .. ", " .. wantPart
end


-- ---------------------------------------------------------------------------
-- Dialog plumbing
-- ---------------------------------------------------------------------------

-- Say -- OUT LOUD, on screen -- that the blade could not open, and why.
--
-- Requirement from the field report: the player must never again be unable to
-- tell "nothing to show" from "failed to show". Notify:Alert writes to chat AND
-- the centre screen (src/Notify.lua:71-74), so this is visible on a TV without
-- opening the chat window.
function Screen._ReportShowFailure(reason)
    Screen._lastShowFailure = reason or "unknown"
    -- This is the path that exists so failures are never silent, so it must be
    -- the one path that cannot itself throw -- a mis-declared format string in
    -- a translation would otherwise swallow the very message it is reporting.
    local template = L("SI_ACCOUNTHOLD_PRIO_SHOW_FAILED",
        "Quartermaster Priorities could not open (%s). Type /qmpriorities to read the list in chat.")
    local okFmt, text = pcall(string.format, template, tostring(reason or "reason unknown"))
    if not okFmt or type(text) ~= "string" then
        text = tostring(template) .. " (" .. tostring(reason or "reason unknown") .. ")"
    end
    alert(text)
    if Screen.addon and Screen.addon.Diagnostic then
        pcall(function()
            Screen.addon:Diagnostic("warn", "[priorities] show failed: %s",
                                    tostring(reason or "unknown"))
        end)
    end
end

-- THE function that builds the list. Called from dialogInfo.setup, which
-- zo_dialog.lua:603-605 invokes on every open of a gamepad dialog.
--
-- `dialog` is a CONTROL (userdata on hardware). Duck-type dialog.setupFunc
-- instead of testing the container type -- see the block comment above; testing
-- for "table" here is what emptied this dialog for four releases.
function Screen._DialogSetup(dialog, titleText, mainText)
    Screen._lastSetupRan   = false
    Screen._lastSetupError = nil

    if not Screen._IsDialogControl(dialog) then
        Screen._lastSetupError = "no dialog control"
        return false, Screen._lastSetupError
    end

    -- Title + one-line summary go through the base game's own channel
    -- (zo_genericdialog_gamepad.lua:408-438), exactly like
    -- itemsetcollectionsmanager.lua:89. That is also why this dialog carries NO
    -- `title` field: RefreshMainText (zo_dialog.lua:301-310) would set the
    -- header and then this call would ZO_ClearTable it again (:414).
    if type(ZO_GenericGamepadDialog_RefreshText) == "function" then
        pcall(ZO_GenericGamepadDialog_RefreshText, dialog, titleText, mainText)
    end

    local setupFunc
    local okField = pcall(function() setupFunc = dialog.setupFunc end)
    if not okField or type(setupFunc) ~= "function" then
        Screen._lastSetupError = "dialog.setupFunc missing"
        return false, Screen._lastSetupError
    end

    -- dialog:setupFunc() -- ZO_GenericParametricListGamepadDialogTemplate_Setup
    -- (zo_genericdialog_gamepad.lua:707-731), which ends in
    -- RebuildEntryList and Commit.
    local okBuild, err = pcall(setupFunc, dialog)
    if not okBuild then
        -- The one thing that can newly throw in here is the row TEMPLATE:
        -- RebuildEntryList calls AddDataTemplate with whatever name we handed
        -- it (:823-831), and a name this client cannot instantiate raises
        -- inside the base loop. Demote to the template this blade shipped with,
        -- rebuild the list, and try exactly once more. A styling change must
        -- never be able to empty a dialog that used to work.
        if Screen._DemoteEntryTemplate() then
            if Screen.addon and Screen.addon.Diagnostic then
                pcall(function()
                    Screen.addon:Diagnostic("warn",
                        "[priorities] row template %q failed (%s); falling back to %q.",
                        DIALOG_ENTRY_TEMPLATE, shortErr(err), DIALOG_ENTRY_TEMPLATE_FALLBACK)
                end)
            end
            pcall(function() Screen._RepopulateDialogList() end)
            local okRetry, retryErr = pcall(setupFunc, dialog)
            if okRetry then
                Screen._lastSetupRan = true
                return true
            end
            err = retryErr
        end
        Screen._lastSetupError = shortErr(err)
        return false, Screen._lastSetupError
    end

    Screen._lastSetupRan = true
    return true
end

-- Read the row under the cursor off the dialog's own parametric list.
-- entryList is a ZO_GamepadVerticalItemParametricScrollList OBJECT (a Lua
-- table), hung on the control by
-- GenericParametricListGamepadDialogTemplate_InitializeEntryList (:762-764).
-- Ask before dropping a wanted set, then drop it.
--
-- Takes the ROW rather than reading the selection, because the dialog is closed
-- before this runs (_CloseThenRun) and the selection is gone by then. Reuses the
-- existing REMOVE_DIALOG confirm, so the dialog surface and the scene surface
-- ask in exactly the same words.
--
-- Guarded at every step: a row that is not a wishlist record does nothing at
-- all, which is the correct outcome for a destructive action with no target.
function Screen._ConfirmRemoveRow(row)
    if type(row) ~= "table" or row.rowType ~= ROW_PRIORITY then return false end
    local rec = row.priority
    if type(rec) ~= "table" or rec.id == nil then return false end

    ensureRemoveDialog()
    showPlatformDialog(REMOVE_DIALOG, {
        priorityId     = rec.id,
        label          = row.name,
        -- Opened FROM the dialog surface, which _CloseThenRun has just released.
        -- Both buttons must therefore put it back; otherwise the player is
        -- dumped out to the world.
        returnToDialog = true,
    })
    return true
end

function Screen._TargetRow(dialog)    if not Screen._IsDialogControl(dialog) then return nil end
    local row
    pcall(function()
        local list = dialog.entryList
        if not Screen._IsDialogControl(list)
           or type(list.GetTargetData) ~= "function" then
            return
        end
        local data = list:GetTargetData()
        if type(data) == "table" then row = data.accountHoldPriorityRow end
    end)
    return row
end

-- Return to the Priorities dialog after a sub-dialog finishes.
--
-- Reported from hardware: after removing a set the game "backs all the way out
-- of the menu", and B did the same. Cause: _CloseThenRun RELEASES the priorities
-- dialog before opening the sub-dialog (it has to -- see the note there), and
-- nothing ever brought it back, so when the sub-dialog closed the player was
-- left on whatever scene happened to be underneath.
--
-- Same re-entrancy trap as _CloseThenRun, in the other direction: the
-- sub-dialog is still displayed while its button callback runs, and
-- ZO_Dialogs_ShowDialog bails while g_displayedDialog is set
-- (zo_dialog.lua:435-440). g_displayedDialog is cleared by
-- ZO_CompleteReleaseDialogOnDialogHidden (:953-957), which for a GAMEPAD dialog
-- runs when the fragment finishes hiding -- not on this frame. So release the
-- sub-dialog first, then re-show a few frames later.
function Screen._ReturnToPriorities(dialogName)
    if dialogName and type(ZO_Dialogs_ReleaseDialogOnButtonPress) == "function" then
        pcall(ZO_Dialogs_ReleaseDialogOnButtonPress, dialogName)
    end
    local function reopen()
        pcall(function() Screen:Show() end)
    end
    if type(zo_callLater) == "function" then
        if pcall(zo_callLater, reopen, 150) then return true end
    end
    reopen()
    return true
end

-- Close this dialog, THEN do the thing.
--
-- A second dialog opened from inside this one is dropped: ZO_Dialogs_ShowDialog
-- bails at :435-440 while g_displayedDialog is set, and g_displayedDialog is
-- only cleared by ZO_CompleteReleaseDialogOnDialogHidden (:953-957), which for a
-- GAMEPAD dialog runs when the fragment finishes hiding (:895-915,
-- zo_genericdialog_gamepad.lua:396-420) -- i.e. NOT on this frame. So release
-- first and run the follow-up a few frames later.
function Screen._CloseThenRun(fn)
    if type(ZO_Dialogs_ReleaseDialogOnButtonPress) == "function" then
        pcall(ZO_Dialogs_ReleaseDialogOnButtonPress, PRIORITIES_DIALOG)
    end
    if type(fn) ~= "function" then return end
    if type(zo_callLater) == "function" then
        local ok = pcall(zo_callLater, function() pcall(fn) end, 150)
        if ok then return end
    end
    pcall(fn)
end

-- (X) Open the Quartermaster Dungeons finder, falling back to queueing.
-- Exported so it is drivable from a test without a dialog.
function Screen._OpenDungeonFinder()
    local finder = AccountHold and AccountHold.UI and AccountHold.UI.DungeonFinderGamepad
    if type(finder) == "table" and type(finder.Show) == "function" then
        local ok = pcall(function() finder:Show() end)
        if ok then return true end
    end

    -- The finder ships separately; until it is present (or if it refused), fall
    -- back to queueing directly rather than doing nothing at all.
    local DQ = AccountHold and AccountHold.DungeonQueue
    if type(DQ) ~= "table" or type(DQ.QueueForPrioritized) ~= "function" then
        alert(L("SI_ACCOUNTHOLD_PRIO_QUEUE_NO_API",
                "The activity finder is unavailable on this client."))
        return false
    end

    local okQ, queued, reason, unmatched = pcall(DQ.QueueForPrioritized, DQ)
    if not okQ then
        alert(L("SI_ACCOUNTHOLD_PRIO_QUEUE_NO_API",
                "The activity finder is unavailable on this client."))
        return false
    end
    if type(queued) == "number" and queued > 0 then
        local msg = string.format(
            L("SI_ACCOUNTHOLD_PRIO_QUEUED", "Queued for %d activity(s)."), queued)
        if type(unmatched) == "number" and unmatched > 0 then
            msg = msg .. " " .. string.format(
                L("SI_ACCOUNTHOLD_PRIO_QUEUE_SKIPPED",
                  "%d could not be queued (not a group activity)."), unmatched)
        end
        alert(msg)
        return true
    end
    if reason == "no_api" then
        alert(L("SI_ACCOUNTHOLD_PRIO_QUEUE_NO_API",
                "The activity finder is unavailable on this client."))
    else
        alert(L("SI_ACCOUNTHOLD_PRIO_QUEUE_EMPTY",
                "Nothing on your plan can be queued for."))
    end
    return false
end

-- (A) Show the selected activity on the map. Routes through the existing,
-- tested OfferTravelForSelected via _selectedRowOverride.
function Screen._TravelForRow(row)
    if type(row) ~= "table" then
        alert(L("SI_ACCOUNTHOLD_PRIO_NO_SELECTION",
                "Nothing is selected on the Priorities list."))
        return false
    end
    if row.rowType ~= ROW_ACTIVITY or row.isUnknown then
        alert(L("SI_ACCOUNTHOLD_PRIO_NOT_A_PLACE",
                "Pick a row under the activities heading - a wanted set is not a place."))
        return false
    end
    local screen = Screen
    if type(screen) ~= "table" then return false end
    screen._selectedRowOverride = row
    local ok = pcall(function() screen:OfferTravelForSelected() end)
    screen._selectedRowOverride = nil
    return ok and true or false
end

-- ===========================================================================
-- PRI-11: MAKE IT LOOK AND BEHAVE LIKE THE OTHER COLLECTIONS SCREENS
-- ===========================================================================
-- (esoui file:line citations in this block are at esoui/esoui@6639eb2,
-- branch live, API 101051.)
--
-- Player report (Xbox): "Collections > Quartermaster Priorities ... does not
-- look like the other menus. It needs to look like them and it needs to
-- function the same." The player chose to keep it in the Collections menu.
--
-- WHAT WAS DIFFERENT. The list was a parametric dialog shown over the BASE
-- scene: the pause menu was closed first (ui/PrioritiesMenu_Gamepad.lua,
-- showDialogFromMenu) and the blade floated over the live game world, with no
-- camera framing, no blur, no detail panel, and B dropped the player in the
-- world instead of back on Collections.
--
-- WHY NOT A FULL CUSTOM SCREEN. Three custom-scene attempts "failed" on Xbox.
-- The recorded root cause (ui/PrioritiesMenu_Gamepad.lua:_EnsureScene comment,
-- ui/DungeonFinderScene_Gamepad.lua section 7, git 502be0d / 3b715ea) is that a
-- `type(WINDOW_MANAGER) ~= "table"` guard was TRUE on hardware (userdata), so
-- the scene code never ran at all -- AND that the old design hand-built a
-- top-level window plus a ZO_GamepadVerticalItemParametricScrollList from
-- CreateControlFromVirtual at runtime, which is the part that "never built".
-- That runtime control tree has never been proven on console; the parametric
-- dialog has (PRI-7, confirmed on hardware 2026-08-03). So the proven dialog
-- stays as THE list, and only two things are added around it:
--
--   1. A HOST SCENE made of nothing but base-game fragments -- no control of
--      ours, no CreateControlFromVirtual, no top-level window. It carries
--      exactly the fragment set of the sibling Collections screens:
--        gamepadingamescenes.lua:457-463 (Item Sets) and :468-473 (Tribute
--        Patrons): GAMEPAD_DRIVEN_UI_WINDOW, FRAME_TARGET_GAMEPAD_RIGHT_
--        FURTHER_AWAY (camera frames the character, background blurred),
--        GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT, MINIMIZE_CHAT_FRAGMENT,
--        GAMEPAD_MENU_SOUND_FRAGMENT.
--      The Collections row PUSHES it, exactly like the native rows push
--      theirs (zo_mainmenu_gamepad.lua:999-1001), so the scene stack is
--      mainMenuGamepad > playerSubmenu > host and B pops ONE level, back to
--      the Collections submenu (zo_scenemanager_leader.lua:292-296, :167-179).
--      The dialog is shown ON the host when it is SHOWN. If the host cannot be
--      built or pushed, the menu falls back to the old over-the-world path.
--
--   2. A DETAIL PANEL beside the list. A parametric dialog has its own
--      tooltip, GAMEPAD_LEFT_DIALOG_TOOLTIP, anchored in nav quadrant 2 right
--      of the dialog (zo_tooltip_gamepad.xml:58-61, zo_tooltip_gamepad.lua:91)
--      and shown with ZO_GenericGamepadDialog_ShowTooltip
--      (zo_genericdialog_gamepad.lua:624-629). The base game drives it from
--      info.parametricListOnSelectionChangedCallback (:718-729) -- the closest
--      precedent is the smithing set picker, an item-set list in a parametric
--      dialog (consolidatedsmithingsets_gamepad.lua:488-520). The dialog hides
--      it itself on close (OnDialogHiding, :363-364).
-- ===========================================================================

-- Fixed by tooltips (zo_tooltip_gamepad.lua:64). Never hard-coded here: a
-- client without the global simply gets no panel.
local function detailTooltipType()
    return GAMEPAD_LEFT_DIALOG_TOOLTIP
end

-- itemsetsbook_gamepad.lua:134 -- `local HIDE_TRAIT = true` (a file local there).
local HIDE_TRAIT = true

local unpackFn = table.unpack or unpack

-- What the detail panel says about a row. PURE: no ZO_* global; the only live
-- data (collection progress) comes in through `progressFn`, exactly like the
-- resolvers _BuildRows takes. Returns nil when there is nothing to show (the
-- empty-state row), which hides the panel.
--   { kind = "activity"|"set"|"item", title = string, lines = { string... },
--     setId = n?, itemLink = s? }
function Screen._DetailFor(row, progressFn)
    if type(row) ~= "table" then return nil end

    local function fmt(id, fallback, ...)
        local ok, s = pcall(string.format, L(id, fallback), ...)
        if ok and type(s) == "string" then return s end
        local ok2, s2 = pcall(string.format, fallback, ...)
        if ok2 then return s2 end
        return fallback
    end
    local function progress(setId)
        if type(progressFn) ~= "function" or setId == nil then return nil end
        local ok, unlocked, total = pcall(progressFn, setId)
        if ok and type(unlocked) == "number" and type(total) == "number" and total > 0 then
            return unlocked, total
        end
        return nil
    end

    if row.rowType == ROW_ACTIVITY then
        local lines = {}
        if row.isUnknown then
            lines[#lines + 1] = L("SI_ACCOUNTHOLD_PRIO_UNKNOWN_SOURCE_DESC",
                "No activity data for these sets - this plan is incomplete.")
        else
            if type(row.typeLabel) == "string" and row.typeLabel ~= "" then
                lines[#lines + 1] = row.typeLabel
            end
            if type(row.zoneName) == "string" and row.zoneName ~= "" then
                lines[#lines + 1] = fmt("SI_ACCOUNTHOLD_PRIO_ZONE", "Zone: %s", row.zoneName)
            end
        end
        lines[#lines + 1] = fmt("SI_ACCOUNTHOLD_PRIO_OUTSTANDING",
            "%d wanted piece(s) outstanding", tonumber(row.outstanding) or 0)

        local setIds   = type(row.setIds) == "table" and row.setIds or {}
        local setNames = type(row.setNames) == "table" and row.setNames or {}
        if #setNames > 0 then
            lines[#lines + 1] = L("SI_ACCOUNTHOLD_PRIO_DETAIL_SETS_HEADER", "Wanted sets from here:")
            for i = 1, #setNames do
                local unlocked, total = progress(setIds[i])
                if unlocked then
                    lines[#lines + 1] = fmt("SI_ACCOUNTHOLD_PRIO_DETAIL_SET_PROGRESS",
                        "%s - %d/%d collected", setNames[i], unlocked, total)
                else
                    lines[#lines + 1] = setNames[i]
                end
            end
        end
        return { kind = "activity", title = row.name, lines = lines }
    end

    if row.rowType == ROW_PRIORITY then
        local rec = type(row.priority) == "table" and row.priority or {}
        if rec.kind == "item" then
            return {
                kind = "item", title = row.name, itemLink = row.itemLink,
                lines = { L("SI_ACCOUNTHOLD_PRIO_DETAIL_WANTED_ITEM", "Marked as wanted.") },
            }
        end
        local lines = {}
        local unlocked, total = progress(row.setId)
        if unlocked then
            lines[#lines + 1] = fmt("SI_ACCOUNTHOLD_PRIO_DETAIL_COLLECTED",
                "Collected: %d/%d pieces", unlocked, total)
        end
        if type(row.sources) == "table" and #row.sources > 0 then
            lines[#lines + 1] = fmt("SI_ACCOUNTHOLD_PRIO_DETAIL_DROPS_FROM",
                "Drops from: %s", table.concat(row.sources, ", "))
        elseif row.sourceUnknown then
            lines[#lines + 1] = L("SI_ACCOUNTHOLD_PRIO_DETAIL_SOURCE_UNKNOWN",
                "Source unknown - Quartermaster has no activity data for this set yet.")
        else
            lines[#lines + 1] = L("SI_ACCOUNTHOLD_PRIO_DETAIL_NOTHING_OUTSTANDING",
                "Nothing outstanding - every wanted piece is collected.")
        end
        return { kind = "set", title = row.name, setId = row.setId, lines = lines }
    end

    return nil
end

local detailFailures = 0
local function reportDetailFailure(why)
    detailFailures = detailFailures + 1
    Screen._lastDetailError = why
    -- First few only: this runs on every cursor move.
    if detailFailures <= 3 and Screen.addon and Screen.addon.Diagnostic then
        pcall(function()
            Screen.addon:Diagnostic("warn", "[priorities] detail panel: %s", tostring(why))
        end)
    end
end

-- Hide the panel. ZO_GenericGamepadDialog_HideTooltip clears and resets it
-- only if ShowTooltip ran (zo_genericdialog_gamepad.lua:631-640); a client
-- without it gets a plain ClearTooltip.
function Screen._HideDetail(dialog)
    Screen._lastDetail = nil
    local which = detailTooltipType()
    if type(ZO_GenericGamepadDialog_HideTooltip) == "function" and dialog ~= nil then
        if pcall(ZO_GenericGamepadDialog_HideTooltip, dialog) then return true end
    end
    if which ~= nil and GAMEPAD_TOOLTIPS ~= nil then
        local clear = Safe.Method(GAMEPAD_TOOLTIPS, "ClearTooltip")
        if clear then pcall(clear, GAMEPAD_TOOLTIPS, which) end
    end
    return true
end

-- Append our own lines under a native layout, the way the Quartermaster
-- inventory tab does on hardware (ui/InventoryTab_Gamepad.lua UpdateTooltip:
-- AcquireSection(bodySection) / AddLine(bodyDescription) / AddSection). The
-- tooltip object is a CONTROL with ZO_Tooltip mixed in (zo_tooltip.lua:1205-
-- 1207), i.e. userdata on hardware -- so guard on methods, never type().
local function appendLines(which, lines)
    if type(lines) ~= "table" or #lines == 0 then return true end
    local getTip = Safe.Method(GAMEPAD_TOOLTIPS, "GetTooltip")
    if not getTip then return false end
    local ok = pcall(function()
        local tt = getTip(GAMEPAD_TOOLTIPS, which)
        if tt == nil or not Safe.Method(tt, "AcquireSection")
           or not Safe.Method(tt, "AddSection") or not Safe.Method(tt, "GetStyle") then
            error("tooltip has no section API")
        end
        local section = tt:AcquireSection(tt:GetStyle("bodySection"))
        for i = 1, #lines do
            section:AddLine(lines[i], tt:GetStyle("bodyDescription"))
        end
        tt:AddSection(section)
    end)
    return ok
end

-- Paint the detail panel for `row`. Every step guarded; returns (ok, why).
--
-- Layout calls go through GAMEPAD_TOOLTIPS' metatable, which turns ANY
-- unknown method name into a layout dispatcher (zo_tooltip_gamepad.lua:3-58),
-- so a Safe.Method probe proves nothing there. The names used are therefore
-- verified against source instead:
--   LayoutItemSetCollectionPieceLink(itemLink, hideTrait)  itemtooltips.lua:2111
--   LayoutItemWithStackCountSimple(itemLink, stackCount)    itemtooltips.lua:1876
--   LayoutTitleAndMultiSectionDescriptionTooltip(title, ...) zo_tooltip.lua:1259
function Screen._ShowDetail(dialog, row)
    local which = detailTooltipType()
    if which == nil or GAMEPAD_TOOLTIPS == nil then
        return false, "no dialog tooltip on this client"
    end

    local detail = Screen._DetailFor(row, function(setId) return Screen:_SetProgress(setId) end)
    if not detail then
        Screen._HideDetail(dialog)
        return true
    end

    local tips = GAMEPAD_TOOLTIPS
    local laidOut = false
    if detail.kind == "set" then
        local link = Screen:_SetPieceLink(detail.setId)
        if link then
            laidOut = pcall(function()
                tips:LayoutItemSetCollectionPieceLink(which, link, HIDE_TRAIT)
            end)
            if laidOut then
                detail.layout = "piece"
                detail.pieceLink = link
                appendLines(which, detail.lines)
            end
        end
    elseif detail.kind == "item" and type(detail.itemLink) == "string" and detail.itemLink ~= "" then
        laidOut = pcall(function()
            tips:LayoutItemWithStackCountSimple(which, detail.itemLink, 1)
        end)
        if laidOut then
            detail.layout = "item"
            appendLines(which, detail.lines)
        end
    end

    if not laidOut then
        local lines = detail.lines or {}
        local ok, err = pcall(function()
            tips:LayoutTitleAndMultiSectionDescriptionTooltip(which, detail.title, unpackFn(lines))
        end)
        if not ok then return false, shortErr(err) end
        detail.layout = "text"
    end

    -- Layout first, THEN show: the base game's own order
    -- (consolidatedsmithingsets_gamepad.lua:514-516).
    if type(ZO_GenericGamepadDialog_ShowTooltip) == "function" and dialog ~= nil then
        local okShow, errShow = pcall(ZO_GenericGamepadDialog_ShowTooltip, dialog)
        if not okShow then return false, shortErr(errShow) end
    end
    Screen._lastDetail = detail
    return true
end

-- The dialog's selection-changed hook. Runs inside the base list's own
-- callback chain, BEFORE the default keybind refresh
-- (zo_genericdialog_gamepad.lua:721-724) -- so a throw here would also leave
-- the keybind strip stale. Nothing escapes.
function Screen._OnDialogSelectionChanged(dialog, selectedData)
    local ok, shown, why = pcall(function()
        local row = type(selectedData) == "table" and selectedData.accountHoldPriorityRow or nil
        if row == nil then
            Screen._HideDetail(dialog)
            return true
        end
        return Screen._ShowDetail(dialog, row)
    end)
    if not ok then
        reportDetailFailure(shortErr(shown))
        return false
    end
    if not shown then
        reportDetailFailure(why or "unknown")
        return false
    end
    return true
end

-- ---------------------------------------------------------------------------
-- The host scene
-- ---------------------------------------------------------------------------

local HOST_SCENE_NAME = "accountHoldPrioritiesHostGamepad"
Screen._HOST_SCENE_NAME = HOST_SCENE_NAME

local function hostDiag(level, fmtText, ...)
    local addon = Screen.addon
    if addon and addon.Diagnostic then
        local args = { ... }
        pcall(function() addon:Diagnostic(level, "[priorities] " .. fmtText, unpackFn(args)) end)
    end
end

-- Is the host the scene on screen right now? ZO_SceneManager_Base:IsShowing
-- (zo_scenemanager_base.lua:241-248) is true for SHOWING or SHOWN only.
function Screen._IsHosted()
    local isShowing = Safe.Method(SCENE_MANAGER, "IsShowing")
    if not isShowing then return false end
    local ok, showing = pcall(isShowing, SCENE_MANAGER, HOST_SCENE_NAME)
    return (ok and showing) and true or false
end

-- Pop the host: back to the Collections submenu. ZO_SceneManager_Leader:Hide
-- pops exactly one scene and only when the host IS the current scene
-- (zo_scenemanager_leader.lua:292-296), so it can never close something else.
function Screen._LeaveHost()
    if not Screen._IsHosted() then return false end
    local hide = Safe.Method(SCENE_MANAGER, "Hide")
    if not hide then return false end
    local ok, err = pcall(hide, SCENE_MANAGER, HOST_SCENE_NAME)
    if not ok then
        hostDiag("warn", "could not leave the Priorities screen: %s", shortErr(err))
        return false
    end
    return true
end

-- After an action has run with the list closed: if the player is still on the
-- host with nothing on it (the action alerted instead of navigating -- e.g. no
-- known wayshrine), put the list back rather than leave an empty screen.
function Screen._RestoreIfStranded()
    if not Screen._IsHosted() then return false end
    if type(ZO_Dialogs_IsShowingDialog) == "function" then
        local ok, any = pcall(ZO_Dialogs_IsShowingDialog)
        if ok and any then return false end
    end
    pcall(function() Screen:Show() end)
    return true
end

-- The host's own keybind strip. It is only ever visible while NO dialog is up:
-- every gamepad dialog pushes the keybind group state on show and pops it on
-- hide (zo_genericdialog_gamepad.lua:337, :389). So this is the recovery strip
-- -- B leaves, A puts the list back -- and it can collide with nothing because
-- the host scene is ours alone.
function Screen._HostKeybinds()
    if Screen._hostKeybinds then return Screen._hostKeybinds end
    local desc = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name     = L("SI_ACCOUNTHOLD_PRIO_BTN_REOPEN", "Show list"),
            keybind  = "UI_SHORTCUT_PRIMARY",
            callback = function() pcall(function() Screen:Show() end) end,
        },
    }
    local function back() pcall(Screen._LeaveHost) end
    local added = false
    if type(ZO_Gamepad_AddBackNavigationKeybindDescriptors) == "function"
       and GAME_NAVIGATION_TYPE_BUTTON ~= nil then
        added = pcall(ZO_Gamepad_AddBackNavigationKeybindDescriptors,
                      desc, GAME_NAVIGATION_TYPE_BUTTON, back)
    end
    if not added then
        desc[#desc + 1] = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name      = L("SI_ACCOUNTHOLD_PRIO_BTN_BACK", "Back"),
            keybind   = "UI_SHORTCUT_NEGATIVE",
            order     = -1500,
            callback  = back,
        }
    end
    Screen._hostKeybinds = desc
    return desc
end

-- SHOWING: keybinds (API_REFERENCE "Scenes": add on SHOWING, remove on
-- HIDDEN, siegebar.lua:46-55). SHOWN: put the list up -- a gamepad dialog only
-- shows on a scene that IsShowing (zo_dialog.lua:366 at API 101051). HIDING: take the list
-- down so it can never outlive its screen.
function Screen._OnHostStateChange(newState)
    if newState == SCENE_SHOWING then
        local add = Safe.Method(KEYBIND_STRIP, "AddKeybindButtonGroup")
        if add then pcall(add, KEYBIND_STRIP, Screen._HostKeybinds()) end
    elseif newState == SCENE_SHOWN then
        local ok, err = pcall(function() Screen:Show() end)
        if not ok then hostDiag("warn", "list did not open on its screen: %s", shortErr(err)) end
    elseif newState == SCENE_HIDING then
        if type(ZO_Dialogs_IsShowing) == "function"
           and type(ZO_Dialogs_ReleaseDialog) == "function" then
            local okIs, showing = pcall(ZO_Dialogs_IsShowing, PRIORITIES_DIALOG)
            if okIs and showing then pcall(ZO_Dialogs_ReleaseDialog, PRIORITIES_DIALOG) end
        end
    elseif newState == SCENE_HIDDEN then
        local remove = Safe.Method(KEYBIND_STRIP, "RemoveKeybindButtonGroup")
        if remove and Screen._hostKeybinds then
            pcall(remove, KEYBIND_STRIP, Screen._hostKeybinds)
        end
    end
end

-- Build (once) the fragment-only host scene. Returns scene or (nil, reason).
-- Everything that can fail is checked BEFORE ZO_Scene:New, because a scene
-- registers itself with the manager on construction (zo_scene.lua:28-37) and
-- there is no unregister: a half-built host must never exist.
function Screen._EnsureHostScene()
    if Screen._hostScene then return Screen._hostScene end

    local getScene = Safe.Method(SCENE_MANAGER, "GetScene")
    if not getScene or not Safe.Method(SCENE_MANAGER, "Push")
       or not Safe.Method(SCENE_MANAGER, "Hide") then
        return nil, "SCENE_MANAGER unavailable"
    end
    if type(ZO_Scene) ~= "table" or type(ZO_Scene.New) ~= "function" then
        return nil, "ZO_Scene unavailable"
    end
    -- REQUIRED: this group carries the gamepad keybind strip, its backdrop and
    -- gamepad UI mode (ingamefragmentgroups.lua:42-53). Without it the player
    -- would have no visible B. Fail closed.
    local groups = FRAGMENT_GROUP
    local driven = type(groups) == "table" and groups.GAMEPAD_DRIVEN_UI_WINDOW or nil
    if type(driven) ~= "table" or #driven == 0 then
        return nil, "FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW unavailable"
    end

    local ok, sceneOrErr = pcall(function()
        local s = getScene(SCENE_MANAGER, HOST_SCENE_NAME)
        if s == nil then s = ZO_Scene:New(HOST_SCENE_NAME, SCENE_MANAGER) end
        return s
    end)
    if not ok or sceneOrErr == nil then
        return nil, "scene not created: " .. shortErr(sceneOrErr)
    end
    local scene = sceneOrErr

    -- Each extra is optional and added on its own: a missing global costs that
    -- one piece of polish, never the screen.
    local okDriven = pcall(scene.AddFragmentGroup, scene, driven)
    if not okDriven then return nil, "could not add GAMEPAD_DRIVEN_UI_WINDOW" end
    local framing = groups.FRAME_TARGET_GAMEPAD_RIGHT_FURTHER_AWAY
    if type(framing) == "table" then pcall(scene.AddFragmentGroup, scene, framing) end
    local function addFragment(fragment)
        if fragment ~= nil then pcall(scene.AddFragment, scene, fragment) end
    end
    addFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    addFragment(MINIMIZE_CHAT_FRAGMENT)
    addFragment(GAMEPAD_MENU_SOUND_FRAGMENT)

    local register = Safe.Method(scene, "RegisterCallback")
    if not register then return nil, "scene has no RegisterCallback" end
    -- ZO_Scene fires StateChange(oldState, newState) (zo_scene.lua:163).
    local okCb = pcall(register, scene, "StateChange", function(_oldState, newState)
        pcall(Screen._OnHostStateChange, newState)
    end)
    if not okCb then return nil, "could not hook the scene" end

    Screen._hostScene = scene
    return scene
end

-- The Collections row's entry point. Pushes the host (the dialog follows on
-- SHOWN). Returns false -- and the caller falls back to the old dialog-over-
-- the-world path -- whenever the host cannot be built or the push did not take.
function Screen:OpenFromMenu()
    local scene, why = Screen._EnsureHostScene()
    if not scene then
        hostDiag("warn", "native screen unavailable (%s); opening the list on its own.",
                 tostring(why))
        return false
    end
    local push = Safe.Method(SCENE_MANAGER, "Push")
    local ok, err = pcall(push, SCENE_MANAGER, HOST_SCENE_NAME)
    if not ok then
        hostDiag("warn", "could not open the Priorities screen: %s", shortErr(err))
        return false
    end
    -- Push hides the current scene first and only then shows ours
    -- (zo_scenemanager_leader.lua:270-273), so "next" counts as taken.
    if Screen._IsHosted() then return true end
    local isNext = Safe.Method(SCENE_MANAGER, "IsShowingNext")
    if isNext then
        local okN, next_ = pcall(isNext, SCENE_MANAGER, HOST_SCENE_NAME)
        if okN and next_ then return true end
    end
    hostDiag("warn", "the Priorities screen did not open; opening the list on its own.")
    return false
end

-- Test seam.
function Screen._ResetHost()
    Screen._hostScene    = nil
    Screen._hostKeybinds = nil
    detailFailures       = 0
    Screen._lastDetail   = nil
    Screen._lastDetailError = nil
end

-- ---------------------------------------------------------------------------
-- The dialog itself
-- ---------------------------------------------------------------------------
--
-- Registered ONCE, not on every Show(). ZO_Dialogs_ShowGamepadDialog MUTATES
-- dialog.gamepadInfo (it parks a SceneStateChanged callback there when a show
-- has to wait for the next scene -- zo_dialog.lua:358-371), and the queue holds
-- only the dialog NAME (:31-46), so handing the game a fresh info table on every
-- open leaks that callback and makes a queued show read from a table nobody
-- expects. The LIST is what changes per open, so only parametricList is
-- reassigned.
local dialogInfo

local function ensurePrioritiesDialog()
    if dialogInfo then return dialogInfo end
    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function" then return nil end

    local info
    info = {
        -- Without this a show request that arrives while ANY other dialog is up
        -- is thrown away in silence (zo_dialog.lua:435-440).
        canQueue = true,

        gamepadInfo = {
            dialogType = (type(GAMEPAD_DIALOGS) == "table" and GAMEPAD_DIALOGS.PARAMETRIC) or 2,
            -- Belt and braces with the pause-menu handshake in
            -- ui/PrioritiesMenu_Gamepad.lua: if we ask while a scene change is
            -- still in flight, the base game re-issues the show itself once the
            -- next scene is SHOWN (zo_dialog.lua:358-371) instead of dropping it.
            allowShowOnNextScene = true,
        },

        -- REQUIRED, and the reason this blade was empty. See the block comment.
        setup = function(dialog)
            local ok, reason = Screen._DialogSetup(dialog, info._titleText, info._mainText)
            if not ok then Screen._ReportShowFailure(reason) end
        end,

        -- NO `title` field on purpose: itemsetcollectionsmanager.lua:82-95 -- the
        -- working example this blade is modelled on -- sets the header from
        -- inside setup with ZO_GenericGamepadDialog_RefreshText, because that
        -- call ZO_ClearTable()s headerData (zo_genericdialog_gamepad.lua:414)
        -- and would otherwise wipe whatever RefreshMainText had just put there.

        parametricList = {},
        blockDialogReleaseOnPress = true,

        -- PRI-11: the detail panel follows the cursor. Signature
        -- (dialog, list, newSelectedData, oldSelectedData) -- base callers at
        -- consolidatedsmithingsets_gamepad.lua:513, armory_gamepad.lua:708.
        parametricListOnSelectionChangedCallback = function(dialog, _list, newSelectedData)
            Screen._OnDialogSelectionChanged(dialog, newSelectedData)
        end,

        -- OnDialogHiding already hides a shown dialog tooltip (zo_genericdialog_
        -- gamepad.lua:363-364) and then calls this (:370-372). Belt and braces:
        -- a stale panel must never sit over the next screen.
        onHidingCallback = function(dialog)
            pcall(Screen._HideDetail, dialog)
        end,

        -- noChoiceCallback has TWO call sites and they mean opposite things:
        --   zo_dialog.lua:372-376  the show request was DROPPED. The argument is
        --                          the dialogInfo table itself.
        --   zo_dialog.lua:958-960  the player closed the dialog without pressing
        --                          a button. The argument is the dialog CONTROL.
        -- The old code alerted/logged on both, so a normal B press reported a
        -- dropped request. Identity against `info` separates them exactly.
        noChoiceCallback = function(arg)
            if arg == info then
                Screen._ReportShowFailure(
                    L("SI_ACCOUNTHOLD_PRIO_NO_SCENE", "no screen was ready to host it"))
            end
        end,

        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text    = L("SI_ACCOUNTHOLD_PRIO_TRAVEL", "Show on map"),
                -- PRI-11: like a native screen, an action that cannot apply to
                -- the highlighted row is not offered. A wanted set or the
                -- "source unknown" row is not a place. Same `visible`
                -- mechanism as Remove below, confirmed on hardware (PRI-7).
                visible = function(dialog)
                    local ok, res = pcall(function()
                        local row = Screen._TargetRow(dialog)
                        return type(row) == "table" and row.rowType == ROW_ACTIVITY
                           and not row.isUnknown
                    end)
                    return (ok and res) and true or false
                end,
                callback = function(dialog)
                    local row = Screen._TargetRow(dialog)
                    Screen._CloseThenRun(function()
                        Screen._TravelForRow(row)
                        -- No map opened (e.g. no known wayshrine): the
                        -- alert has spoken; put the list back.
                        Screen._RestoreIfStranded()
                    end)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text    = L("SI_ACCOUNTHOLD_PRIO_BTN_BACK", "Back"),
                callback = function()
                    -- PRI-11: on the native host, B goes back ONE level, to the
                    -- Collections submenu, like every sibling screen. Opened
                    -- any other way (fallback, /command) it just closes.
                    if Screen._IsHosted() then
                        Screen._CloseThenRun(function() Screen._LeaveHost() end)
                    else
                        Screen._CloseThenRun(nil)
                    end
                end,
            },
            -- X. DIALOG_TERTIARY is the third dialog action the base game binds
            -- for gamepad dialogs (collectionsbook_gamepad.lua, giftinventory-
            -- dialogs_gamepad.lua, consolidatedsmithingsets_gamepad.lua all use
            -- it inside a parametric dialog's buttons array). UI_SHORTCUT_* is
            -- NOT used in any base-game dialog buttons array: dialog buttons are
            -- bound through the dialog keybind group under the Dialog action
            -- layer (zo_genericdialog_gamepad.lua:243-267, :335-341), so a
            -- UI_SHORTCUT_ action there simply never gets a glyph.
            {
                keybind = "DIALOG_TERTIARY",
                text    = L("SI_ACCOUNTHOLD_PRIO_QUEUE", "Quartermaster Dungeons"),
                callback = function()
                    Screen._CloseThenRun(function()
                        Screen._OpenDungeonFinder()
                        Screen._RestoreIfStranded()
                    end)
                end,
            },
            -- Remove the wanted set under the cursor.
            --
            -- REPORTED FROM HARDWARE: "the only place I'm able to remove sets
            -- from my list of priorities is from the set items list." Correct --
            -- this dialog had no remove action at all. Screen:RemoveSelectedPriority
            -- existed, but only on the SCENE path, which this dialog replaced
            -- precisely because the scene never builds on Xbox. Fixing the
            -- scene's keybinds did nothing for the player.
            --
            -- DIALOG_SECONDARY was the free slot: PRIMARY, NEGATIVE and TERTIARY
            -- are taken above, and SECONDARY is a real dialog action with 29
            -- base-game uses.
            --
            -- Visible ONLY on a wishlist row. Dialog buttons support a `visible`
            -- function evaluated per open (zo_genericdialog_gamepad.lua:35, :209).
            -- An activity row can cover several wanted sets, so "remove the
            -- priority under the cursor" would be ambiguous and destructive
            -- there -- the same rule the scene applied.
            {
                keybind = "DIALOG_SECONDARY",
                text    = L("SI_ACCOUNTHOLD_PRIO_BTN_REMOVE", "Remove from wanted"),
                visible = function(dialog)
                    local ok, res = pcall(function()
                        local row = Screen._TargetRow(dialog)
                        return type(row) == "table"
                           and row.rowType == ROW_PRIORITY
                           and type(row.priority) == "table"
                           and row.priority.id ~= nil
                    end)
                    return (ok and res) and true or false
                end,
                callback = function(dialog)
                    local row = Screen._TargetRow(dialog)
                    Screen._CloseThenRun(function() Screen._ConfirmRemoveRow(row) end)
                end,
            },
        },
    }

    local ok = pcall(ZO_Dialogs_RegisterCustomDialog, PRIORITIES_DIALOG, info)
    if not ok then return nil end
    dialogInfo = info
    return dialogInfo
end

Screen._EnsurePrioritiesDialog = ensurePrioritiesDialog

-- Test seam: forget the registration so a fresh harness run re-registers.
function Screen._ResetDialogRegistration()
    dialogInfo = nil
end

-- Open the Priorities list.
--
-- Safe to call at any time. EVERY exit either puts entries on screen, puts an
-- explicit sentence on screen, or alerts the player by name. It never again
-- returns "true" for a show that produced nothing.
function Screen:Show()
    -- Tolerate Screen.Show() as well as screen:Show(): a dot call from a menu
    -- callback must not become another silent empty blade.
    local this = self
    if type(this) ~= "table" or type(this.Rows) ~= "function" then this = Screen end

    Screen._lastShowFailure = nil
    Screen._lastSetupRan    = false
    Screen._lastSetupError  = nil

    if type(ZO_Dialogs_RegisterCustomDialog) ~= "function"
       or type(ZO_Dialogs_ShowGamepadDialog) ~= "function"
       or type(ESO_Dialogs) ~= "table" then
        Screen._ReportShowFailure(
            L("SI_ACCOUNTHOLD_PRIO_NO_DIALOG_API", "gamepad dialogs are unavailable"))
        return false
    end
    if type(ZO_SharedGamepadEntry_OnSetup) ~= "function" then
        Screen._ReportShowFailure(
            L("SI_ACCOUNTHOLD_PRIO_NO_ENTRY_API", "the gamepad list template is unavailable"))
        return false
    end

    -- Read the model. A throw here must NOT produce a blank list -- it must
    -- produce a sentence that names the failure.
    local okRows, rows = pcall(this.Rows, this)
    local rowsError
    if not okRows then
        rowsError = shortErr(rows)
        rows = {}
    end
    if type(rows) ~= "table" then rows = {} end

    local entries = Screen._RowsToDialogEntries(rows, ZO_SharedGamepadEntry_OnSetup)

    -- _BuildRows always yields at least one row, so an empty list here means the
    -- model threw. Either way the player gets words, not a void.
    if #entries == 0 then
        local text
        if rowsError then
            local okFmt, formatted = pcall(string.format,
                L("SI_ACCOUNTHOLD_PRIO_SUMMARY_ERROR",
                  "Could not read your priorities: %s"), rowsError)
            text = (okFmt and type(formatted) == "string") and formatted
                or ("Could not read your priorities: " .. tostring(rowsError))
        else
            text = L("SI_ACCOUNTHOLD_PRIO_EMPTY_HINT",
                     "Nothing wanted yet. Collections > Item Sets, highlight a set piece, press Y.")
        end
        entries[1] = {
            template = Screen._EntryTemplate(),
            text     = text,
            templateData = { setup = ZO_SharedGamepadEntry_OnSetup },
        }
    end

    local info = ensurePrioritiesDialog()
    if not info then
        Screen._ReportShowFailure(
            L("SI_ACCOUNTHOLD_PRIO_NO_REGISTER", "the dialog could not be registered"))
        return false
    end

    info.parametricList = entries
    info._titleText     = L("SI_ACCOUNTHOLD_PRIORITIES_MENU", "Quartermaster Priorities")
    info._mainText      = Screen._SummaryText(rows, rowsError)

    -- Already open (e.g. reopened after removing something): rebuild the list in
    -- place. A second ZO_Dialogs_ShowGamepadDialog would be rejected outright
    -- (zo_dialog.lua:435-440) and, with canQueue set, merely parked behind the
    -- copy already on screen.
    if type(ZO_Dialogs_IsShowing) == "function" then
        local okIs, showing = pcall(ZO_Dialogs_IsShowing, PRIORITIES_DIALOG)
        if okIs and showing then
            -- The live control, in order of preference:
            --   ZO_Dialogs_FindDialog       zo_dialog.lua:93-98
            --   ZO_GenericGamepadDialog_GetControl
            --                               zo_genericdialog_gamepad.lua:309-321
            local dlg
            if type(ZO_Dialogs_FindDialog) == "function" then
                local okFind, d = pcall(ZO_Dialogs_FindDialog, PRIORITIES_DIALOG)
                if okFind then dlg = d end
            end
            if not Screen._IsDialogControl(dlg)
               and type(ZO_GenericGamepadDialog_GetControl) == "function" then
                local okGet, d = pcall(ZO_GenericGamepadDialog_GetControl,
                                       info.gamepadInfo.dialogType)
                if okGet then dlg = d end
            end

            if Screen._IsDialogControl(dlg) then
                local okBuild, reason = Screen._DialogSetup(dlg, info._titleText, info._mainText)
                if not okBuild then
                    Screen._ReportShowFailure(reason)
                    return false
                end
                return true
            end

            -- No way to reach the control on this client: close the copy that is
            -- up and let the show below re-open it. canQueue means a show issued
            -- while the release is still in flight is queued and replayed when
            -- the hide completes (zo_dialog.lua:982-984), not lost.
            if type(ZO_Dialogs_ReleaseDialog) == "function" then
                pcall(ZO_Dialogs_ReleaseDialog, PRIORITIES_DIALOG)
            end
        end
    end

    local okShow = pcall(ZO_Dialogs_ShowGamepadDialog, PRIORITIES_DIALOG)
    if not okShow then
        Screen._ReportShowFailure(
            L("SI_ACCOUNTHOLD_PRIO_SHOW_THREW", "the game refused the request"))
        return false
    end

    -- VERIFY. The whole point of this round: never report success for a show
    -- that put nothing on screen. g_displayedDialog is assigned synchronously
    -- inside ZO_Dialogs_ShowDialog (zo_dialog.lua:795) before the fragment is
    -- added, so this is a valid same-frame check.
    local showing = false
    if type(ZO_Dialogs_IsShowing) == "function" then
        local okIs, s = pcall(ZO_Dialogs_IsShowing, PRIORITIES_DIALOG)
        showing = (okIs and s) and true or false
    end

    if showing then
        if not Screen._lastSetupRan then
            -- The dialog is on screen but the list was never built. This is the
            -- exact four-round failure; it now announces itself.
            Screen._ReportShowFailure(Screen._lastSetupError
                or L("SI_ACCOUNTHOLD_PRIO_LIST_NOT_BUILT", "the list was not built"))
            return false
        end
        return true
    end

    -- Not showing. noChoiceCallback already spoke if the request was dropped.
    if Screen._lastShowFailure then return false end

    local otherDialog = false
    if type(ZO_Dialogs_IsShowingDialog) == "function" then
        local okAny, any = pcall(ZO_Dialogs_IsShowingDialog)
        otherDialog = (okAny and any) and true or false
    end
    if otherDialog then
        alert(L("SI_ACCOUNTHOLD_PRIO_QUEUED_BEHIND",
                "Quartermaster Priorities will open when the current window closes."))
        return true
    end

    -- allowShowOnNextScene parked it on the next scene transition.
    alert(L("SI_ACCOUNTHOLD_PRIO_DEFERRED",
            "Quartermaster Priorities will open as soon as you are back in the world."))
    return true
end
