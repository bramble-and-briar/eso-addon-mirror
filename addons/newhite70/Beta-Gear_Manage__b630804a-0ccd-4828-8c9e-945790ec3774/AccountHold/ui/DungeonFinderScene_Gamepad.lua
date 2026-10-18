-- AccountHold/ui/DungeonFinderScene_Gamepad.lua
--
-- "Quartermaster Dungeons" as a REAL THIRD ROW in the gamepad Dungeon Finder's
-- own category list, directly under the base game's "Random Dungeons" and
-- "Specific Dungeons".
--
-- It is a TRUNCATED PROXY OF SPECIFIC DUNGEONS: the same screen, the same rows,
-- the same keybinds, the same queue -- filtered down to the dungeons the
-- player's Priorities point at -- plus ONE new action, Solo Queue.
--
-- The rows are not reimplemented. They are BUILT BY ZOS AND THEN FILTERED: this
-- module drives the base RefreshView in the base's own SPECIFIC_ENTRIES mode,
-- harvests the entries it produced, keeps the prioritised ones and re-lays the
-- list out. Every row therefore carries ZOS's own narration text, lock reasons,
-- enabled/selected state and entry template, and inherits future ZOS changes
-- for free. See Tab._HarvestSpecificRows.
--
-- =============================================================================
-- 1. THE SEAM, WITH file:line EVIDENCE (esoui/esoui@master)
--    esoui/ingame/lfg/gamepad/zo_activityfindertemplate_gamepad.lua
-- =============================================================================
-- :4-9    local NAVIGATION_MODES = { CATEGORIES = 1, RANDOM_ENTRIES = 2,
--                                    SPECIFIC_ENTRIES = 3 }
--         A file-LOCAL, so no add-on can collide with it by accident -- and a
--         STRING mode of ours can never equal any of the three numbers. We do
--         not hardcode 3 either: Tab.DiscoverBaseModes reads the two numbers
--         back off the base game's OWN category rows at install time.
--
-- :70-117 InitializeLists(). When the category has both random and specific
--         entries (:94):
--           :95  self.categoryList = self:GetMainList()
--           :97  self:AddRolesMenuEntry(self.categoryList)   <-- the base game
--                itself puts a NON-mode row in this list, which is the proof
--                that the list is not a closed set of two.
--           :101-107 Random  -> data = { navigationMode = RANDOM_ENTRIES }
--           :109-116 Specific-> data = { navigationMode = SPECIFIC_ENTRIES }
--           :117 self.categoryList:Commit()
--           :118-121 self.entryList = self:AddList("Entries"); hasCategories = true
--         :124-128 is the OTHER branch: entryList IS the main list and there is
--         NO categoryList at all. We fail closed there -- see Tab.Install.
--
--         The category list is built ONCE at construction and is never Cleared
--         anywhere else in the file, so a single append at install time is
--         permanent. We append; we never renumber and never touch a base entry.
--
-- :193-206 The A keybind, in CATEGORIES mode:
--           :196  local navigationMode = entryData.navigationMode
--           :197  self:SetNavigationMode(navigationMode)
--         So our row is dispatched by the BASE keybind, with no keybind of ours.
--
-- :682-717 SetNavigationMode(navigationMode). Verified against an UNKNOWN mode:
--           :685-687 mode ~= CATEGORIES  -> targetList  = self.entryList
--           :690-694 mode ~= RANDOM      -> targetHeader = self.specificHeaderData
--           :697-698 targetList:GetTargetData() -- nil on an empty list, safe
--           :707-713 mode differs -> SetCurrentList(entryList);
--                    self.navigationMode = <ours>  (set BEFORE the refresh);
--                    self:RefreshHeaderAndView(targetHeader)
--           :716    self:RefreshSingularSectionPanel()
--         IT TOLERATES AN UNKNOWN MODE COMPLETELY. We still wrap it, but only
--         to keep a fallback flag and to swap in our own header data instead of
--         the Normal/Veteran tab bar the specific view uses.
--
-- :224-228 The B keybind: mode ~= CATEGORIES and hasCategories -> ClearSelections()
--         + SetNavigationMode(CATEGORIES). Back out of our list works natively.
--
-- =============================================================================
-- 2. WHY THE ROWS ARE HARVESTED, NOT REBUILT
-- =============================================================================
-- RefreshView (:398-549) builds each row through a local closure:
--     :418  local function AddLocationEntry(location)
--     :419-424   ZO_GamepadEntryData:New(location:GetNameGamepad(), menuIcon)
--                entryData.data = location
--                data:SetLockReasonTextOverride(lockReasonTextOverride)
--                SetEnabled(not location:IsLocked() and not isSearching)
--                SetSelected(location:IsSelected())
--     :426-520   a large narrationText closure (group size, roles, lock reason,
--                rewards, set types) -- 95 lines of screen-reader text
--     :522  self.entryList:AddEntry("ZO_GamepadItemSubEntryTemplate", entryData)
-- AddLocationEntry is a FILE-LOCAL CLOSURE with upvalues (isSearching,
-- lockReasonTextOverride, modes, self) and cannot be called from outside. The
-- narrowest reusable seam that produces those exact rows is RefreshView itself.
--
-- The specific branch (:536-544) reads ONE activity type,
-- self.currentSpecificActivityType, and FilterByActivity (:358-361) is the base
-- game's own two-line "set that field and refresh" entry point. So harvesting is
-- literally what the base does when you change the Normal/Veteran filter:
--     set navigationMode = <the base's own SPECIFIC number, discovered at :109-116>
--     set currentSpecificActivityType = LFG_ACTIVITY_DUNGEON
--     call the ORIGINAL RefreshView
--     read the rows back out with GetNumEntries / GetEntryData
--     repeat for LFG_ACTIVITY_MASTER_DUNGEON
--     restore both fields, keep the prioritised rows, re-lay the list out
-- Both fields are restored even if the base throws. RefreshView does NOT call
-- ClearSelections -- that lives in RefreshHeaderAndView (:386), which we never
-- drive -- so harvesting cannot disturb the player's ticks.
--
-- If a harvest ever fails, that difficulty falls back to Tab._BuildRowsManually,
-- which constructs the same shape by hand. Proxy first, hand-rolled second, base
-- view third: the player always gets a list.
--
-- =============================================================================
-- 3. WHAT MAKES IT A PROXY RATHER THAN A LOOKALIKE
-- =============================================================================
-- :723-777 RefreshSingularSectionPanel(): for any non-CATEGORIES mode it reads
--         targetData.data as a LOCATION -- descriptionTextureGamepad, nameGamepad,
--         SetGroupSizeRangeText, RefreshRewards (-> location:HasRewardData(),
--         zo_activityfindertemplate_shared.lua:408), isLocked, activityType and
--         AppendSetDataToControl (-> setData:IsSetEntryType(),
--         zo_activityfindertemplate_shared.lua:655).
--
-- Our rows carry the REAL ZO_ActivityFinderLocation objects, because they ARE
-- the base game's rows. So:
--   * the checkmarks are the game's         (:206 ToggleLocationSelected)
--   * the selection count is the game's     (zo_activityfinderroot_manager.lua:541)
--   * X = Join Queue is the game's, and it already does exactly the sequence the
--     brief names: ActivityFinderRoot_Manager:StartSearch
--     (zo_activityfinderroot_manager.lua:617-637) calls ClearActivityFinderSearch()
--     (:622), location:AddActivitySearchEntry() for every selected location
--     across EVERY activity type (:625-631), then StartActivityFinderSearch()
--     (:633). Because it walks all of sortedLocationsData, one press queues our
--     Normal and Veteran picks together.
--   * B = back is the game's                (:224-228)
-- There is no second selection model, no second queue and nothing to keep in sync.
--
-- =============================================================================
-- 4. THE ONE ADDITION: SOLO QUEUE
-- =============================================================================
-- Solo Queue is NOT the in-game matchmaker and never calls
-- StartActivityFinderSearch. It spins the wheel over the player's Quartermaster
-- dungeons, picks one, and puts it on the map so the player can walk in and
-- their friends can join them there:
--     AccountHold.DungeonQueue.PickOne(entries, roll)   -- roll is injectable
--     AccountHold.Travel:FindNodeForActivity(activity)  -- returns node, matchKind
--     AccountHold.Travel:ShowOnMap(nodeIndex)           -- returns shown, reason
-- It draws from the TICKED dungeons, or from everything listed when none are
-- ticked, and the keybind label says which. It never calls Travel:TravelTo --
-- travel is a player decision made on the map, not a side effect of a keybind.
--
-- Cross-player Quartermaster matchmaking is explicitly OUT OF SCOPE and is not
-- built, stubbed or hinted at anywhere in this file.
--
-- =============================================================================
-- 5. WHICH FINDER. This screen class is shared.
-- =============================================================================
-- ZO_ActivityFinderTemplate_Gamepad is used by the dungeon, battleground and
-- tribute finders alike, so we hook THE INSTANCE and we check its identity:
--   zo_dungeonfinder_manager.lua:31  ZO_ActivityFinderFilterModeData:New(
--                                        LFG_ACTIVITY_DUNGEON,
--                                        LFG_ACTIVITY_MASTER_DUNGEON)
--   zo_dungeonfinder_manager.lua:32  ...Manager.Initialize(self, "ZO_DungeonFinder", ...)
--   zo_dungeonfinder_manager.lua:37  DUNGEON_FINDER_GAMEPAD = self:GetGamepadObject()
-- Tab.IsDungeonFinder requires BOTH the manager name and the two activity types,
-- so a future finder that happens to be reachable under that global still can
-- not pick up a dungeon row by accident.
--
-- Normal vs Veteran are two different LFG activity TYPES, not a difficulty flag,
-- which is why both are listed together and why SetVeteranDifficulty is never
-- called -- it mutates group state and is not ours to touch. Veteran rows are
-- self-labelling: zo_activityfinderroot_classes.lua:316-323 formats a
-- master-dungeon location's gamepad name through
-- SI_GAMEPAD_ACTIVITY_FINDER_VETERAN_LOCATION_FORMAT.
--
-- =============================================================================
-- 6. KEYBINDS. Nothing the screen already owns.
-- =============================================================================
-- ZO_ActivityFinderTemplate_Gamepad:InitializeKeybindStripDescriptors()
-- (:180-357) builds ONE group, self.keybindStripDescriptor, holding:
--     :189 UI_SHORTCUT_PRIMARY     Select  -> :197 SetNavigationMode (categories)
--                                         -> :206 ToggleLocationSelected (entries)
--     :222 UI_SHORTCUT_NEGATIVE    Back
--     :239 UI_SHORTCUT_TERTIARY    View Rewards (visible only for Tribute, :249-255)
--     :277 UI_SHORTCUT_QUATERNARY  Ungate       (visible only when gated, :306-322)
--     :336 UI_SHORTCUT_SECONDARY   Toggle Queue -> :342 StartSearch,
--                                                  :349 visible on IsAnyLocationSelected
-- ALL FIVE ARE TAKEN and zo_keybindstrip.lua:342-343 REMOVES the existing
-- descriptor on a duplicate, which has crashed this game before. We claim NONE
-- of them -- not even TERTIARY, which is invisible here but still registered.
--
-- Being a proxy, we inherit all five. Only the two ADDITIONS need a home, on the
-- two shortcuts the screen does not claim:
--     UI_SHORTCUT_LEFT_STICK   Select All  (real: gamepadinventory.lua:579/673)
--     UI_SHORTCUT_RIGHT_STICK  Solo Queue  (real: gamepadinventory.lua:588/683,
--                                           zo_activityfinderroot_gamepad.lua:63)
-- Both are visible ONLY while our row is the active mode. Appending never
-- renumbers or mutates a base entry, each of ours carries a string key so a
-- second install is a no-op, and Tab.Uninstall takes them back out.
--
-- =============================================================================
-- 7. WHY A CUSTOM SCENE WAS NEVER THE PROBLEM (kept: it explains the doctrine)
-- =============================================================================
-- Three custom gamepad scenes "failed" on Xbox and the platform was blamed. The
-- real cause was a type guard against ESO userdata, and it is still in the tree:
--     ui/PrioritiesMenu_Gamepad.lua:560
--         if type(WINDOW_MANAGER) ~= "table" or type(ZO_Scene) ~= "table" then
--             return false
--         end
-- globalvars.lua:2-4 sets WINDOW_MANAGER = GetWindowManager(), an ENGINE object,
-- i.e. `userdata` -- the same Lua type as a control. That guard was TRUE on every
-- console session, so _EnsureScene() returned false on its FIRST LINE and never
-- touched ZO_Scene. Sibling copies still kill the retry paths at
-- PrioritiesMenu_Gamepad.lua:494, ArmoryScreen_Gamepad.lua:2465 and
-- PrioritiesSetsBook_Gamepad.lua:651 (all `type(EVENT_MANAGER) ~= "table"`).
-- Hence isControl() below: a control or an engine manager is userdata on
-- hardware and a table under the mock, and we accept both, always.
--
-- =============================================================================
-- 8. FAILURE DOCTRINE
-- =============================================================================
-- Every base touch is pcall'd and every global is type-guarded. If any step of
-- the install fails, nothing is hooked and ui/DungeonFinder_Gamepad.lua falls
-- back to the standalone parametric dialog that already ships. If our view build
-- ever throws at runtime we latch Tab._broken, hand the screen straight back to
-- the base RefreshView and stay out for the rest of the session -- so the worst
-- observable outcome is "the third row shows the full Specific list", never a
-- blank screen and never a broken Dungeon Finder. The empty state is a real,
-- disabled row whose data answers every read listed in section 3, not an absence
-- of rows.

if type(AccountHold) ~= "table" then return end

AccountHold.UI = AccountHold.UI or {}
AccountHold.UI.DungeonFinderTabGamepad = AccountHold.UI.DungeonFinderTabGamepad or {}

local Tab = AccountHold.UI.DungeonFinderTabGamepad

-- Back-compat alias: ui/DungeonFinder_Gamepad.lua, AccountHold.lua's UI
-- initialiser and the retry timer all reach for the native surface by this name.
AccountHold.UI.DungeonFinderSceneGamepad = Tab

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

-- Our navigation mode. A STRING, so it can never equal NAVIGATION_MODES.CATEGORIES
-- (1), RANDOM_ENTRIES (2) or SPECIFIC_ENTRIES (3)
-- (zo_activityfindertemplate_gamepad.lua:4-9), and it follows the same
-- convention as ACCOUNT_HOLD_LIST in ui/InventoryTab_Gamepad.lua and
-- ACCOUNT_HOLD_PRIORITIES in ui/PrioritiesMenu_Gamepad.lua.
local NAV_MODE = "ACCOUNT_HOLD_QUARTERMASTER_DUNGEONS"

-- String keys, never indices. Everything we append to base data is findable and
-- removable by key, so a second Install() is a no-op and Uninstall() is exact.
local ROW_KEY        = "accountHoldQuartermasterDungeonsRow"
local SELECT_ALL_KEY = "accountHoldQuartermasterSelectAll"
local SOLO_QUEUE_KEY = "accountHoldQuartermasterQueue"

-- zo_dungeonfinder_manager.lua:19
local DUNGEON_FINDER_SCENE = "gamepadDungeonFinder"
-- zo_activityfindertemplate_manager.lua:63 / zo_dungeonfinder_manager.lua:32
local DUNGEON_MANAGER_NAME = "ZO_DungeonFinder"

-- The category rows use ZO_GamepadMenuEntryTemplate
-- (zo_activityfindertemplate_gamepad.lua:107, :116); the entry rows use
-- ZO_GamepadItemSubEntryTemplate, which is what :129-133 registers on entryList.
-- Using anything else would simply not render.
local CATEGORY_TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local ENTRY_TEMPLATE    = "ZO_GamepadItemSubEntryTemplate"

-- zo_dungeonfinder_manager.lua:16
local MENU_ICON = "EsoUI/Art/LFG/Gamepad/gp_LFG_menuIcon_Dungeon.dds"

local SELECT_ALL_BIND = "UI_SHORTCUT_LEFT_STICK"

-- Y. The brief asks for Y and the right stick is handed back to the player.
--
-- UI_SHORTCUT_TERTIARY IS already registered by this screen, at
-- zo_activityfindertemplate_gamepad.lua:239 ("View Rewards/Veterancy"), so
-- APPENDING a second TERTIARY descriptor would hit
-- zo_keybindstrip.lua:341-343 -- internalassert(false, "Duplicate Keybind: ...")
-- followed by RemoveKeybindButton(existingDescriptor) -- which is exactly the
-- crash this project has shipped before.
--
-- So we do not append. We TAKE OVER the existing descriptor IN PLACE: same
-- table identity, same `keybind` field, only name/callback/visible/enabled
-- swapped for closures that DELEGATE to the captured originals whenever our tab
-- is not the active mode. There is therefore never more than one TERTIARY in
-- the group, the duplicate path is never reached, and base behaviour is bit-for-
-- bit preserved off our tab. Tab.Uninstall puts the four fields back.
--
-- (The base TERTIARY is in any case permanently invisible on the DUNGEON finder:
-- its visible() at :283-297 only returns true for Tribute and Battleground
-- activity types, which this finder never contains -- zo_dungeonfinder_manager.lua:32
-- builds it from LFG_ACTIVITY_DUNGEON and LFG_ACTIVITY_MASTER_DUNGEON only.)
local SOLO_QUEUE_BIND = "UI_SHORTCUT_TERTIARY"

Tab.NAV_MODE             = NAV_MODE
Tab.ROW_KEY              = ROW_KEY
Tab.SELECT_ALL_KEY       = SELECT_ALL_KEY
Tab.SOLO_QUEUE_KEY       = SOLO_QUEUE_KEY
Tab.CATEGORY_TEMPLATE    = CATEGORY_TEMPLATE
Tab.ENTRY_TEMPLATE       = ENTRY_TEMPLATE
Tab.SELECT_ALL_BIND      = SELECT_ALL_BIND
Tab.SOLO_QUEUE_BIND      = SOLO_QUEUE_BIND
Tab.DUNGEON_FINDER_SCENE = DUNGEON_FINDER_SCENE
Tab.DUNGEON_MANAGER_NAME = DUNGEON_MANAGER_NAME

-- Owned by ZO_ActivityFinderTemplate_Gamepad:InitializeKeybindStripDescriptors
-- (zo_activityfindertemplate_gamepad.lua:180-357). APPENDING any of these would
-- REMOVE the base descriptor (zo_keybindstrip.lua:341-343). TERTIARY is absent
-- from this list because we do not append it -- we take it over in place and
-- delegate to the original, which never reaches the duplicate path. See
-- SOLO_QUEUE_BIND above and Tab.TakeOverDescriptor below.
Tab.RESERVED_KEYBINDS = {
    UI_SHORTCUT_PRIMARY    = true,
    UI_SHORTCUT_NEGATIVE   = true,
    UI_SHORTCUT_QUATERNARY = true,
    UI_SHORTCUT_SECONDARY  = true,
}

-- Which difficulties the list shows. Normal and Veteran are two different LFG
-- activity TYPES (zo_dungeonfinder_manager.lua:32), never a flag, and
-- SetVeteranDifficulty is never called -- veterandifficultysettings.lua:141-143
-- is its only base caller and it mutates the player's GROUP settings.
Tab.DIFFICULTY_ALL     = "all"
Tab.DIFFICULTY_NORMAL  = "normal"
Tab.DIFFICULTY_VETERAN = "veteran"
-- The base tab bar has no "All" tab -- RefreshSpecificFilters
-- (zo_activityfindertemplate_gamepad.lua:623-638) emits exactly one tab per
-- activity type and the screen opens on the first one. We match that, so the
-- screen opens on Normal. DIFFICULTY_ALL stays supported by DifficultyAllows
-- for callers that want an unfiltered pool (the Quartermaster Queue does), but
-- it is deliberately NOT offered as a tab.
Tab._difficulty        = Tab.DIFFICULTY_NORMAL
Tab._inHeaderRefresh   = false

Tab._active         = false
Tab._hooked         = false
Tab._broken         = false
Tab._suspendRebuild = false
Tab._harvesting     = false
Tab._lastFailure    = nil

-- ---------------------------------------------------------------------------
-- Guarded primitives (same doctrine as the rest of the add-on)
-- ---------------------------------------------------------------------------

local function L(id, fallback)
    if AccountHold and type(AccountHold.L) == "function" then
        local ok, s = pcall(AccountHold.L, id, fallback)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return fallback
end

local function gfn(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "function" then return v end
    return nil
end

local function gtable(name)
    local v = (type(_G) == "table") and _G[name] or nil
    if type(v) == "table" then return v end
    return nil
end

local function gvalue(name)
    if type(_G) ~= "table" then return nil end
    return _G[name]
end

-- A control or an engine manager is USERDATA on hardware and a table under the
-- mock. Accept both; never reject on container type alone. This is the guard
-- whose absence cost this add-on four releases -- see section 4 of the header.
local function isControl(v)
    local t = type(v)
    return (t == "userdata" or t == "table") and true or false
end
Tab._IsControl = isControl

local function gobject(name)
    if type(_G) ~= "table" then return nil end
    local v = _G[name]
    if isControl(v) then return v end
    return nil
end
Tab._GObject = gobject

-- Read a field/method off a possibly-userdata object without ever throwing.
local function field(obj, name)
    if not isControl(obj) then return nil end
    local ok, v = pcall(function() return obj[name] end)
    if ok then return v end
    return nil
end
Tab._Field = field

local function method(obj, name)
    local v = field(obj, name)
    if type(v) == "function" then return v end
    return nil
end
Tab._Method = method

-- Call obj:name(...) if it exists, never throwing. Returns ok, result.
local function invoke(obj, name, ...)
    local fn = method(obj, name)
    if not fn then return false, nil end
    return pcall(fn, obj, ...)
end
Tab._Invoke = invoke

local function diag(level, fmt, ...)
    local addonRef = Tab.addon or AccountHold
    if type(addonRef) ~= "table" or type(addonRef.Diagnostic) ~= "function" then
        return
    end
    pcall(addonRef.Diagnostic, addonRef, level, "[qmdungeons] " .. tostring(fmt), ...)
end

local function alert(message)
    if type(message) ~= "string" or message == "" then return end
    local notify = AccountHold and AccountHold.Notify
    if notify and type(notify.Alert) == "function" then
        if pcall(function() notify:Alert(message) end) then return end
    end
    if AccountHold and type(AccountHold.Log) == "function" then
        pcall(AccountHold.Log, AccountHold, "%s", message)
    end
end

-- The model that the fallback dialog uses. Shared so the two surfaces can never
-- disagree about what is prioritised.
local function finder()
    local F = AccountHold and AccountHold.UI and AccountHold.UI.DungeonFinderGamepad
    if type(F) == "table" then return F end
    return nil
end
Tab._Finder = finder

local function dungeonQueue()
    local DQ = AccountHold and AccountHold.DungeonQueue
    if type(DQ) == "table" then return DQ end
    return nil
end
Tab._DungeonQueue = dungeonQueue

local function fail(reason)
    Tab._lastFailure = reason
    diag("warn", "not installed: %s", tostring(reason))
    return false, reason
end

-- The live gamepad Dungeon Finder screen object.
-- zo_dungeonfinder_manager.lua:37  DUNGEON_FINDER_GAMEPAD = self:GetGamepadObject()
local function host()
    if Tab._hostObj ~= nil then return Tab._hostObj end
    local h = gobject("DUNGEON_FINDER_GAMEPAD")
    if h == nil then return nil end
    if not method(h, "RefreshView") then return nil end
    if not method(h, "SetNavigationMode") then return nil end
    return h
end
Tab._Host = host

-- ===========================================================================
-- PURE HELPERS -- ZO-free, duck-typed, and therefore the entire testable
-- surface under tests/zos_mock.lua, which has no Activity Finder globals.
-- ===========================================================================

-- Fold a display name to a comparison key. Delegates to the finder/DungeonQueue
-- so the three modules can never drift apart on the join.
function Tab.NormalizeName(s)
    local F = finder()
    if F and type(F.NormalizeName) == "function" then
        local ok, key = pcall(F.NormalizeName, s)
        if ok and key ~= nil then return key end
    end
    local DQ = dungeonQueue()
    if DQ and type(DQ.NormalizeName) == "function" then
        local ok, key = pcall(DQ.NormalizeName, s)
        if ok and key ~= nil then return key end
    end
    if type(s) ~= "string" then return nil end
    local out = string.gsub(string.lower(s), "[^%w]", "")
    if out == "" then return nil end
    return out
end

-- A veteran location's RAW name is the plain dungeon name
-- (zo_activityfinderroot_classes.lua:316-323 applies the veteran wrapper at
-- DISPLAY time only), but if a locale ever bakes the marker into the raw name
-- an unprefixed alias keeps the join working. First write wins.
local function stripVeteran(key)
    if type(key) ~= "string" then return nil end
    local out = string.gsub(key, "^veteran", "")
    if out == "" or out == key then return nil end
    return out
end
Tab._StripVeteran = stripVeteran

-- A CANONICAL key, for the numbered-dungeon case (docs/BUGS.md QMQ-3).
--
-- Reported from hardware: adding a set sourced from Fungal Grotto to Priorities
-- did not put Fungal Grotto on the Quartermaster Dungeons tab. Fungal Grotto is
-- one of the dungeons that exists as I and II, each with its own monster set.
--
-- NormalizeName is punctuation-blind but NOT numeral-blind, so it produces
-- "fungalgrottoi" from "Fungal Grotto I" and "fungalgrotto1" from
-- "Fungal Grotto 1". If the Priorities plan and the finder's location list
-- disagree on which form to use -- and they come from different sources, so
-- there is no reason they must agree -- the join silently misses and the
-- dungeon never appears.
--
-- Delegates to Travel._CanonicalName, which already solves exactly this and is
-- covered by tests against three real traced node names. Reusing it keeps ONE
-- definition of "the same place spelled differently"; a second scheme here
-- would inevitably drift from it.
--
-- The fold is symmetric, so it does not matter which side uses which form.
function Tab.CanonicalName(s)
    local T = AccountHold and AccountHold.Travel
    if type(T) == "table" and type(T._CanonicalName) == "function" then
        local ok, key = pcall(T._CanonicalName, s)
        if ok and key ~= nil then return key end
    end
    return nil
end

-- The `.data` table our category row carries. Pure, so the "cannot collide with
-- 1/2/3" property is provable without the game.
function Tab.CategoryRowData()
    local d = { navigationMode = NAV_MODE }
    d[ROW_KEY] = true
    return d
end

function Tab.IsOurCategoryData(data)
    if type(data) ~= "table" then return false end
    return data[ROW_KEY] == true or data.navigationMode == NAV_MODE
end

-- Priorities plan -> { byName = { key -> { activity, order } }, count = n }.
--
-- The plan is an array of activity tables (see ui/DungeonFinder_Gamepad.lua
-- Finder.BuildRows). "unknown" is the synthetic source-unknown row and can
-- never describe a queueable dungeon, so it is dropped rather than counted as
-- a miss the player has to reason about.
function Tab.BuildPlanIndex(plan)
    local index = { byName = {}, count = 0, skipped = 0 }
    if type(plan) ~= "table" then return index end

    for i = 1, #plan do
        local activity = plan[i]
        if type(activity) == "table" and activity.activityKey ~= "unknown" then
            local key = Tab.NormalizeName(activity.activityName)
            if key then
                if index.byName[key] == nil then
                    index.byName[key] = { activity = activity, order = i }
                    index.count = index.count + 1
                end
                local alias = stripVeteran(key)
                if alias and index.byName[alias] == nil then
                    index.byName[alias] = { activity = activity, order = i }
                end
                -- Numeral-blind key, so "Fungal Grotto I" also answers to
                -- "Fungal Grotto 1" and vice versa (QMQ-3).
                local canon = Tab.CanonicalName(activity.activityName)
                if canon and index.byName[canon] == nil then
                    index.byName[canon] = { activity = activity, order = i }
                end
            else
                index.skipped = index.skipped + 1
            end
        else
            index.skipped = index.skipped + 1
        end
    end
    return index
end

-- Look one location up in the plan index. Duck-typed: anything answering
-- GetRawName() (or carrying a .rawName field) works, which is what makes this
-- testable without the game.
function Tab.MatchLocation(location, planIndex)
    if type(planIndex) ~= "table" or type(planIndex.byName) ~= "table" then
        return nil
    end
    if not isControl(location) then return nil end

    local name = nil
    local ok, raw = invoke(location, "GetRawName")
    if ok and type(raw) == "string" then
        name = raw
    else
        local f = field(location, "rawName")
        if type(f) == "string" then name = f end
    end
    if name == nil then return nil end

    local key = Tab.NormalizeName(name)
    if not key then return nil end

    local hit = planIndex.byName[key]
    if hit == nil then
        local alias = stripVeteran(key)
        if alias then hit = planIndex.byName[alias] end
    end
    if hit == nil then
        -- Numeral-blind last resort (QMQ-3). "Fungal Grotto I" on one side and
        -- "Fungal Grotto 1" on the other meet here and nowhere else.
        local canon = Tab.CanonicalName(name)
        if canon then hit = planIndex.byName[canon] end
    end
    if hit == nil then return nil end

    return { activity = hit.activity, order = hit.order, name = name }
end

-- Filter one activity type's locations down to the plan, preserving the
-- player's priority order.
--
-- This is the HAND-ROLLED path's filter -- see Tab.FilterHarvest for the proxy
-- path. `predicate` mirrors the base visibility test at
-- zo_activityfindertemplate_gamepad.lua:540-542 (entry type visible AND active
-- AND no reward data). A predicate that throws EXCLUDES the row -- failing
-- closed -- and the count is reported so a wholesale failure shows up as a
-- diagnostic rather than as a mysteriously short list.
function Tab.FilterLocations(locations, planIndex, difficulty, predicate)
    local out, errors = {}, 0
    if type(locations) ~= "table" then return out, errors end

    for i = 1, #locations do
        local location = locations[i]
        local hit = Tab.MatchLocation(location, planIndex)
        if hit then
            local keep = true
            if predicate ~= nil then
                local ok, allowed = pcall(predicate, location)
                if not ok then
                    errors = errors + 1
                    keep = false
                else
                    keep = allowed and true or false
                end
            end
            if keep then
                out[#out + 1] = {
                    location   = location,
                    activity   = hit.activity,
                    order      = hit.order,
                    name       = hit.name,
                    difficulty = difficulty,
                    index      = i,
                }
            end
        end
    end

    -- ALPHABETICAL by dungeon name.
    --
    -- This previously sorted by the player's priority order (the position the
    -- wanted set was added in), which made the list order an artefact of the
    -- order things were wishlisted -- unpredictable, and impossible to scan for
    -- a specific dungeon. The player asked for alphabetical, which is also what
    -- the base game's own Specific Dungeons list does.
    --
    -- Priority order is kept as the tie-break, then base list index, so the
    -- result is still fully deterministic and a rebuild can never shuffle rows
    -- under the cursor.
    table.sort(out, function(a, b)
        local an = (type(a.name) == "string") and a.name:lower() or ""
        local bn = (type(b.name) == "string") and b.name:lower() or ""
        if an ~= bn then return an < bn end
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    return out, errors
end

-- Read a parametric list's entries back out through its PUBLIC accessors
-- (zo_parametricscrolllist.lua:256-260 GetNumEntries, :269-271 GetEntryData) --
-- never by reaching into dataList.
function Tab.ReadEntries(list)
    local out = {}
    if not isControl(list) then return out end
    local okN, n = invoke(list, "GetNumEntries")
    if not okN or type(n) ~= "number" then return out end
    for i = 1, n do
        local okD, entry = invoke(list, "GetEntryData", i)
        if okD and isControl(entry) then out[#out + 1] = entry end
    end
    return out
end

-- Read the base game's OWN navigation-mode numbers back off its own category
-- rows, so nothing in this file hardcodes NAVIGATION_MODES.
-- zo_activityfindertemplate_gamepad.lua:101-116 adds Random first, then Specific;
-- the roles row (:97, :368-377) carries isRoleSelector and no navigationMode.
function Tab.DiscoverBaseModes(entries)
    local modes = {}
    if type(entries) ~= "table" then return nil, nil end
    for i = 1, #entries do
        local data = field(entries[i], "data")
        if type(data) == "table" and type(data.navigationMode) == "number" then
            modes[#modes + 1] = data.navigationMode
        end
    end
    if #modes < 2 then return nil, nil end
    return modes[1], modes[2]
end

-- Keep the prioritised rows out of a harvest of BASE-BUILT entries, sorted
-- alphabetically by dungeon name. This is the filter half of the "filtered proxy": the
-- entryData objects here were constructed by ZOS's own AddLocationEntry
-- (zo_activityfindertemplate_gamepad.lua:418-523), so they already carry the
-- right narration, lock reason, enabled and selected state.
--
-- The roles row (data.isRoleSelector, :368-377) is dropped: the rebuild adds a
-- fresh one through the base's own AddRolesMenuEntry.
function Tab.FilterHarvest(entries, planIndex, difficulty)
    local out = {}
    if type(entries) ~= "table" then return out end

    for i = 1, #entries do
        local entryData = entries[i]
        local location = field(entryData, "data")
        local isRoles = false
        if type(location) == "table" and location.isRoleSelector then isRoles = true end
        if not isRoles then
            local hit = Tab.MatchLocation(location, planIndex)
            if hit then
                out[#out + 1] = {
                    entryData  = entryData,
                    location   = location,
                    activity   = hit.activity,
                    order      = hit.order,
                    name       = hit.name,
                    difficulty = difficulty,
                    index      = i,
                }
            end
        end
    end

    -- ALPHABETICAL, exactly as FilterLocations sorts the hand-rolled path.
    -- This proxy path is the one that normally runs, so sorting it by
    -- wishlist order left the alphabetical fix invisible to the player.
    table.sort(out, function(a, b)
        local an = (type(a.name) == "string") and a.name:lower() or ""
        local bn = (type(b.name) == "string") and b.name:lower() or ""
        if an ~= bn then return an < bn end
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    return out
end

-- Keybind descriptors. Pure so the reserved-keybind rule is provable.
function Tab.MakeKeybindDescriptor(key, keybind, name, callback, visible, enabled)
    if type(key) ~= "string" or key == "" then return nil end
    if type(keybind) ~= "string" or keybind == "" then return nil end
    if Tab.RESERVED_KEYBINDS[keybind] then return nil end
    if type(callback) ~= "function" then return nil end
    local d = {
        keybind = keybind,
        name = name,
        callback = function()
            local ok, err = pcall(callback)
            if not ok then diag("error", "%s failed: %s", key, tostring(err)) end
        end,
    }
    if visible ~= nil then d.visible = visible end
    if enabled ~= nil then d.enabled = enabled end
    d[key] = true
    return d
end

function Tab.FindDescriptorIndex(descriptor, key)
    if type(descriptor) ~= "table" or type(key) ~= "string" then return nil end
    for i = 1, #descriptor do
        local e = descriptor[i]
        if type(e) == "table" and e[key] then return i end
    end
    return nil
end

function Tab.DescriptorHasKeybind(descriptor, keybind)
    if type(descriptor) ~= "table" then return false end
    for i = 1, #descriptor do
        local e = descriptor[i]
        if type(e) == "table" and e.keybind == keybind then return true end
    end
    return false
end

-- Append one descriptor to a base keybind group. Refuses if the group already
-- claims that keybind, because zo_keybindstrip.lua:342-343 REMOVES the existing
-- descriptor on a duplicate rather than merely complaining.
function Tab.AppendDescriptor(descriptor, entry, key)
    if type(descriptor) ~= "table" or type(entry) ~= "table" then return nil end
    if type(key) ~= "string" or key == "" then return nil end
    local existing = Tab.FindDescriptorIndex(descriptor, key)
    if existing then return existing end
    if Tab.DescriptorHasKeybind(descriptor, entry.keybind) then return nil end
    descriptor[#descriptor + 1] = entry
    return #descriptor
end

function Tab.RemoveDescriptor(descriptor, key)
    local at = Tab.FindDescriptorIndex(descriptor, key)
    if at == nil then return false end
    table.remove(descriptor, at)
    return true
end

-- Selection helpers over an array of match records. `isSelected` is injected so
-- the counting is provable without the game's location objects.
function Tab.CountSelected(matches, isSelected)
    local n = 0
    if type(matches) ~= "table" then return 0 end
    for i = 1, #matches do
        local m = matches[i]
        local ok, sel = pcall(isSelected, m and m.location)
        if ok and sel then n = n + 1 end
    end
    return n
end

function Tab.AreAllSelected(matches, isSelected)
    if type(matches) ~= "table" or #matches == 0 then return false end
    return Tab.CountSelected(matches, isSelected) == #matches
end

-- Flatten the two difficulty groups into one array, normal first.
function Tab.Flatten(groups)
    local out = {}
    if type(groups) ~= "table" then return out end
    for g = 1, #groups do
        local group = groups[g]
        if type(group) == "table" and type(group.matches) == "table" then
            for i = 1, #group.matches do
                out[#out + 1] = group.matches[i]
            end
        end
    end
    return out
end

-- Random pick -> the entry shape DungeonQueue.PickOne expects
-- ({ name = ..., activity = ... }).
function Tab.ToQueueEntries(matches)
    local out = {}
    if type(matches) ~= "table" then return out end
    for i = 1, #matches do
        local m = matches[i]
        if type(m) == "table" and type(m.activity) == "table" then
            out[#out + 1] = {
                name       = m.name,
                activity   = m.activity,
                difficulty = m.difficulty,
                order      = m.order,
                -- The ESO activityId, lifted off the finder's own location
                -- object. The `activity` record above comes from the Priorities
                -- plan (data/setSources.lua) and has no id, but the LOCATION is
                -- ZO_ActivityFinderLocation_Specific, whose GetId() is the
                -- activityId the base game itself passes to
                -- AddActivityFinderSpecificSearchEntry
                -- (zo_activityfinderroot_classes.lua:329).
                --
                -- This is what lets Travel resolve a destination by ZONE rather
                -- than by name -- the fix for "No wayshrine matches it", since
                -- wayshrines are named after places, not dungeons.
                -- See BUGS.md QMQ-1.
                activityId = Tab.LocationActivityId(m.location),
            }
        end
    end
    return out
end

-- The activityId behind a finder location, or nil. Never throws: `location` is
-- a base-game object and may be userdata, so it is probed by METHOD presence,
-- never by type() == "table".
function Tab.LocationActivityId(location)
    if location == nil then return nil end
    local getId = method(location, "GetId")
    if getId == nil then return nil end
    local ok, id = pcall(getId, location)
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end

-- The empty-state row's data.
--
-- It is NOT a plain table: the base screen dereferences targetData.data on every
-- cursor move (zo_activityfindertemplate_gamepad.lua:723-777), so this stands in
-- for a location and answers every one of those reads. isLocked = true routes
-- the explanation into the native "locked" tooltip, which is exactly the right
-- place for "you have not prioritised any dungeons yet".
function Tab.EmptyStateData(title, reason)
    local nameText   = type(title) == "string" and title or ""
    local reasonText = type(reason) == "string" and reason or ""
    local stub = {
        accountHoldEmptyState     = true,
        nameGamepad               = nameText,
        nameKeyboard              = nameText,
        rawName                   = nameText,
        descriptionTextureGamepad = "",
        description               = reasonText,
        isLocked                  = true,
        lockReasonText            = reasonText,
        lockReasonTextOverride    = nil,
        activityType              = nil,
        isRoleSelector            = nil,
    }
    function stub:GetNameGamepad()   return nameText end
    function stub:GetNameKeyboard()  return nameText end
    function stub:GetRawName()       return nameText end
    function stub:GetDescription()   return reasonText end
    function stub:GetId()            return 0 end
    function stub:GetActivityType()  return nil end
    function stub:GetEntryType()     return nil end
    function stub:GetZoneId()        return 0 end
    function stub:IsSelected()       return false end
    function stub:SetSelected()      return false end
    function stub:IsLocked()         return true end
    function stub:SetLocked()        end
    function stub:IsActive()         return false end
    function stub:SetLockReasonTextOverride() end
    function stub:GetLockReasonText() return reasonText end
    function stub:GetLockReasonTextOverride() return nil end
    function stub:HasRewardData()    return false end
    function stub:GetRewardData()    return 0, 0 end
    -- RefreshSingularSectionPanel dereferences these on EVERY cursor move --
    -- entryData:HasSoloBonus() at zo_activityfindertemplate_gamepad.lua:838 and
    -- entryData:HasMMR() / :GetMMR() at :900-902. Without them the very first
    -- press of the stick onto the empty-state row raised a Lua error. Real
    -- locations define them at zo_activityfinderroot_classes.lua:233, :372,
    -- :564 and :568.
    function stub:HasSoloBonus()     return false end
    function stub:HasMMR()           return false end
    function stub:GetMMR()           return 0 end
    function stub:IsEligibleForDailyReward() return false end
    function stub:IsSetEntryType()   return false end
    function stub:IsSpecificEntryType() return false end
    function stub:GetSetTypesHeaderText() return "" end
    function stub:GetSetTypesListText()   return "" end
    function stub:GetGroupSizeRange() return 0, 0 end
    function stub:GetMinGroupSize()  return 0 end
    function stub:GetMaxGroupSize()  return 0 end
    function stub:GetFirstLockingCollectible() return 0 end
    function stub:GetQuestToUnlock() return 0 end
    function stub:DoesPlayerMeetLevelRequirements() return false end
    function stub:DoesGroupMeetLevelRequirements() return false end
    function stub:CountsForAverageRoleTime() return false end
    function stub:IsInstanceOf() return false end
    function stub:SetGroupSizeRangeText(labelControl)
        if isControl(labelControl) then
            local setText = method(labelControl, "SetText")
            if setText then pcall(setText, labelControl, "") end
        end
        return ""
    end
    return stub
end

-- Choose the empty-state wording from the model, so the player is told WHICH
-- problem they have instead of a generic "nothing here".
function Tab.EmptyStateText(planCount, matchCount, apiAvailable)
    local title = L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_TITLE", "No dungeons to show")
    if apiAvailable == false then
        return title, L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_NOAPI",
            "The Dungeon Finder is not ready yet. Leave this screen and come back.")
    end
    if (planCount or 0) == 0 then
        return title, L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_NOPLAN",
            "Nothing is prioritised yet. Add gear to your Priorities and the dungeons that drop it will appear here.")
    end
    if (matchCount or 0) == 0 then
        return title, L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_NOMATCH",
            "None of your priorities come from a dungeon you can queue for right now.")
    end
    return nil, nil
end

-- ===========================================================================
-- MODEL BRIDGE (impure, but every base touch is guarded)
-- ===========================================================================

function Tab.Plan()
    local P = AccountHold and AccountHold.Priorities
    if type(P) ~= "table" or type(P.BuildPlan) ~= "function" then return nil end
    local ok, plan = pcall(P.BuildPlan, P)
    if ok and type(plan) == "table" then return plan end
    return nil
end

-- Localized activity-type name, the same source the base filters use
-- (zo_activityfindertemplate_gamepad.lua:569 GetString("SI_LFGACTIVITY", activityType)).
function Tab.ActivityTypeName(activityType, fallback)
    local getString = gfn("GetString")
    if getString and activityType ~= nil then
        local ok, s = pcall(getString, "SI_LFGACTIVITY", activityType)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    return fallback
end

-- Only the DUNGEON finder gets our row. Both conditions must hold.
function Tab.IsDungeonFinder(hostObj)
    local dm = field(hostObj, "dataManager")
    if dm == nil then return false end

    local okName, name = invoke(dm, "GetName")
    if okName and type(name) == "string" and name ~= DUNGEON_MANAGER_NAME then
        return false
    end

    local normalType = gvalue("LFG_ACTIVITY_DUNGEON")
    local vetType    = gvalue("LFG_ACTIVITY_MASTER_DUNGEON")
    if normalType == nil then return false end

    local okModes, modes = invoke(dm, "GetFilterModeData")
    if not okModes or modes == nil then return false end
    local okTypes, types = invoke(modes, "GetActivityTypes")
    if not okTypes or type(types) ~= "table" then return false end

    local sawNormal, sawVet = false, false
    for i = 1, #types do
        if types[i] == normalType then sawNormal = true end
        if vetType ~= nil and types[i] == vetType then sawVet = true end
    end
    if vetType == nil then return sawNormal end
    return sawNormal and sawVet
end

-- Which activity types this finder covers, in list order.
-- zo_dungeonfinder_manager.lua:31 -- Normal and Veteran are TWO ACTIVITY TYPES,
-- not a difficulty flag on one. SetVeteranDifficulty is never called.
function Tab.DungeonActivityTypes()
    local defs = {}
    local normalType = gvalue("LFG_ACTIVITY_DUNGEON")
    local vetType    = gvalue("LFG_ACTIVITY_MASTER_DUNGEON")
    if normalType == nil then return defs end

    defs[#defs + 1] = {
        difficulty   = "normal",
        activityType = normalType,
        header       = Tab.ActivityTypeName(normalType, L("SI_ACCOUNTHOLD_DF_NORMAL", "Normal")),
    }
    if vetType ~= nil and vetType ~= normalType then
        defs[#defs + 1] = {
            difficulty   = "veteran",
            activityType = vetType,
            header       = Tab.ActivityTypeName(vetType, L("SI_ACCOUNTHOLD_DF_VETERAN", "Veteran")),
        }
    end
    return defs
end

-- THE PROXY. Drive the BASE RefreshView once, in the BASE's own SPECIFIC_ENTRIES
-- mode, for ONE activity type, and hand back the entries it built.
--
-- Why this and not a reimplementation: RefreshView builds each row through
-- AddLocationEntry (zo_activityfindertemplate_gamepad.lua:418-523), a FILE-LOCAL
-- closure over isSearching / lockReasonTextOverride / modes / self. It cannot be
-- called from outside, and copying its 95-line narrationText closure would mean
-- maintaining a fork of ZOS's screen-reader text forever. RefreshView is the
-- narrowest reusable seam that produces those exact rows.
--
-- The two assignments below are exactly what the base game's own
-- FilterByActivity(activityType) does (:358-361) when the player switches the
-- Normal/Veteran filter -- set currentSpecificActivityType, then refresh. We add
-- navigationMode only because our mode is current while we are showing.
--
-- SAFETY:
--   * both fields are restored even if the base throws, in a second pcall;
--   * Tab._harvesting is raised for the duration, so Tab.IsActive answers FALSE
--     and anything that re-enters RefreshView/RefreshHeaderAndView mid-harvest
--     gets the base implementation instead of ours;
--   * the base's specific branch calls RebuildSelections UNPAIRED with the
--     ClearSelections that normally precedes it (that lives in
--     RefreshHeaderAndView, :420, which we never drive), and RebuildSelections
--     is INCREMENT-ONLY -- zo_activityfinderroot_manager.lua:455-483 only ever
--     does numSelected = numSelected + 1 and SetSelected(true). Two harvests per
--     view build, on every cursor tick, inflated numSelected without limit.
--     IsAnyLocationSelected() is numSelected > 0 (:574-576) and it gates the
--     base X/"Join Queue" keybind (:349) and StartSearch (:636-656), which
--     queues EVERY location still flagged selected across EVERY activity type
--     with no regard for navigationMode. That is a direct leak from our tab into
--     the base queue. The harvest is a READ, so it is made selection-neutral:
--     numSelected is snapshotted and restored around it.
--   * we call the ORIGINAL RefreshView, so our own wrapper is never re-entered;
--   * returns nil on failure (so the caller can fall back), or a possibly-empty
--     array on success.
function Tab._HarvestSpecificRows(hostObj, activityType)
    if Tab._specificMode == nil then return nil end

    local list = field(hostObj, "entryList")
    if not isControl(list) then return nil end

    local orig = (type(Tab._orig) == "table" and Tab._orig.RefreshView)
                 or method(hostObj, "RefreshView")
    if type(orig) ~= "function" then return nil end

    local savedMode = field(hostObj, "navigationMode")
    local savedType = field(hostObj, "currentSpecificActivityType")
    -- Remembered on Tab too, so Deactivate can repair it if we die mid-harvest.
    Tab._savedSpecificActivityType = savedType

    local restoreCount = Tab._SnapshotSelectionCount()

    local harvested = nil
    Tab._harvesting = true
    local okRun, err = pcall(function()
        hostObj.navigationMode = Tab._specificMode
        hostObj.currentSpecificActivityType = activityType
        orig(hostObj)
        harvested = Tab.ReadEntries(list)
    end)

    -- ALWAYS restore, on both paths.
    Tab._harvesting = false
    pcall(function()
        hostObj.navigationMode = savedMode
        hostObj.currentSpecificActivityType = savedType
    end)
    Tab._savedSpecificActivityType = nil
    restoreCount()

    if not okRun then
        diag("warn", "harvest failed for activity type %s: %s",
             tostring(activityType), tostring(err))
        return nil
    end
    return harvested
end

-- Snapshot the root manager's selected COUNT and return a restorer.
--
-- Pairs with any base call that runs RebuildSelections without the
-- ClearSelections that normally precedes it. RebuildSelections re-applies the
-- player's LIVE queue to the location objects -- SetSelected(true), which is
-- idempotent on the location -- but numSelected is a bare running total
-- (zo_activityfinderroot_manager.lua:455-483) and only ClearSelections (:440)
-- ever resets it. Restoring the count leaves the ticks correct and the counter
-- exactly where the base put it.
function Tab._SnapshotSelectionCount()
    local mgr = gobject("ZO_ACTIVITY_FINDER_ROOT_MANAGER")
    if mgr == nil then return function() end end
    local ok, before = pcall(function() return mgr.numSelected end)
    if not ok or type(before) ~= "number" then return function() end end
    return function()
        pcall(function()
            if type(mgr.numSelected) == "number" and mgr.numSelected ~= before then
                mgr.numSelected = before
            end
        end)
    end
end

-- FALLBACK. Build the same rows by hand when a harvest could not run at all.
-- Mirrors zo_activityfindertemplate_gamepad.lua:418-424 and the specific
-- branch's visibility test at :540-542. Produces the same match record shape
-- Tab.FilterHarvest produces, so the assembly below does not care which path
-- supplied it.
function Tab._BuildRowsManually(hostObj, planIndex, def)
    local mgr = gobject("ZO_ACTIVITY_FINDER_ROOT_MANAGER")
    if mgr == nil or not method(mgr, "GetLocationsData") then return nil end

    local entryDataClass = gtable("ZO_GamepadEntryData")
    if entryDataClass == nil or type(entryDataClass.New) ~= "function" then return nil end

    local modes = nil
    local dm = field(hostObj, "dataManager")
    if dm ~= nil then
        local ok, m = invoke(dm, "GetFilterModeData")
        if ok then modes = m end
    end

    local function visible(location)
        local okActive, isActive = invoke(location, "IsActive")
        if okActive and not isActive then return false end
        if modes ~= nil and method(modes, "IsEntryTypeVisible") then
            local okType, entryType = invoke(location, "GetEntryType")
            if okType then
                local okVis, vis = invoke(modes, "IsEntryTypeVisible", entryType)
                if okVis then return vis and true or false end
            end
        end
        return true
    end

    -- :537 -- the base does this before reading IsSelected(), so an already
    -- queued activity shows as ticked. Selection-neutral for the same reason as
    -- the harvest: RebuildSelections is increment-only and there is no paired
    -- ClearSelections on this path.
    local restoreCount = Tab._SnapshotSelectionCount()
    invoke(mgr, "RebuildSelections", { def.activityType })
    restoreCount()

    local okData, locations = invoke(mgr, "GetLocationsData", def.activityType)
    if not okData or type(locations) ~= "table" then return nil end

    local matches, errors = Tab.FilterLocations(locations, planIndex, def.difficulty, visible)
    if errors > 0 then
        diag("warn", "%d location(s) skipped by a failing visibility check", errors)
    end

    local isSearching = false
    local searchFn = gfn("IsCurrentlySearchingForGroup")
    if searchFn then
        local ok, v = pcall(searchFn)
        if ok then isSearching = v and true or false end
    end

    local lockOverride = nil
    local okLock, text = invoke(hostObj, "GetGlobalLockText")
    if okLock then lockOverride = text end

    local categoryData = field(hostObj, "categoryData")
    local menuIcon = MENU_ICON
    if type(categoryData) == "table" and type(categoryData.menuIcon) == "string" then
        menuIcon = categoryData.menuIcon
    end

    local out = {}
    for i = 1, #matches do
        local m = matches[i]
        local location = m.location

        local okName, name = invoke(location, "GetNameGamepad")
        if not okName or type(name) ~= "string" or name == "" then
            name = tostring(m.name or "")
        end

        local okNew, entryData = pcall(entryDataClass.New, entryDataClass, name, menuIcon)
        if okNew and isControl(entryData) then
            pcall(function() entryData.data = location end)
            if lockOverride ~= nil then
                invoke(location, "SetLockReasonTextOverride", lockOverride)
            end
            local locked = false
            local okLocked, isLocked = invoke(location, "IsLocked")
            if okLocked then locked = isLocked and true or false end
            invoke(entryData, "SetEnabled", (not locked) and (not isSearching))
            local okSel, selected = invoke(location, "IsSelected")
            invoke(entryData, "SetSelected", okSel and selected or false)

            m.entryData = entryData
            out[#out + 1] = m
        end
    end
    return out
end

-- Collect the prioritised rows for every dungeon activity type.
-- Returns groups = { { difficulty, header, matches }, ... }, planCount, apiOk.
function Tab.CollectGroups(hostObj, difficultyOverride)
    local groups = {}
    local planIndex = Tab.BuildPlanIndex(Tab.Plan())
    Tab._planCount = planIndex.count

    local defs = Tab.DungeonActivityTypes()
    if #defs == 0 then return groups, planIndex.count, false end

    local filter = difficultyOverride or Tab._difficulty
    local anyPath = false
    local proxied = 0
    for i = 1, #defs do
        local def = defs[i]
        -- Normal / Veteran filter. Skipping the whole activity type is the
        -- cheapest correct implementation: they ARE two different LFG activity
        -- types (zo_dungeonfinder_manager.lua:32), so filtering by type IS
        -- filtering by difficulty. SetVeteranDifficulty is never called.
        if Tab.DifficultyAllows(filter, def.difficulty) then
        local matches = nil

        local harvested = Tab._HarvestSpecificRows(hostObj, def.activityType)
        if harvested ~= nil then
            matches = Tab.FilterHarvest(harvested, planIndex, def.difficulty)
            anyPath = true
            proxied = proxied + 1
        else
            matches = Tab._BuildRowsManually(hostObj, planIndex, def)
            if matches ~= nil then anyPath = true end
        end

        if matches ~= nil and #matches > 0 then
            groups[#groups + 1] = {
                difficulty = def.difficulty,
                header     = def.header,
                matches    = matches,
            }
        end
        end
    end

    Tab._proxiedTypes = proxied
    return groups, planIndex.count, anyPath
end

-- ===========================================================================
-- VIEW BUILD -- runs INSTEAD of ZO_ActivityFinderTemplate_Gamepad:RefreshView
-- while our mode is current. Assembles the harvested/filtered rows into the
-- finder's OWN entry list, following the base method's own structure (:398-549)
-- so the screen the player sees is Specific Dungeons with a shorter list.
-- ===========================================================================

function Tab._BuildView(hostObj)
    -- :399-401 -- the base bails the same way.
    local okShowing, showing = invoke(hostObj, "IsShowing")
    if okShowing and not showing then return true end

    local list = field(hostObj, "entryList")
    if not isControl(list) or not method(list, "AddEntry") then
        return false, "entryList unavailable"
    end

    -- Harvest FIRST: it drives the base RefreshView, which clears and refills
    -- this same list. Everything below then lays out the result.
    local groups, planCount, apiOk = Tab.CollectGroups(hostObj)
    Tab._groups = groups

    invoke(list, "Clear")

    -- :404-409 -- the ethereal roles entry, through the base's own method, and
    -- the default index that keeps the cursor off it.
    local categoryData = field(hostObj, "categoryData")
    local hideRoles = false
    if type(categoryData) == "table" then
        hideRoles = categoryData.hideGroupRoles and true or false
    end
    if not hideRoles and method(hostObj, "AddRolesMenuEntry") then
        invoke(hostObj, "AddRolesMenuEntry", list)
        invoke(list, "SetDefaultSelectedIndex", 2)
    else
        invoke(list, "SetDefaultSelectedIndex", 1)
    end

    local added = 0
    for g = 1, #groups do
        local group = groups[g]
        for i = 1, #group.matches do
            local entryData = group.matches[i].entryData
            if isControl(entryData) then
                -- zo_activityfindertemplate_gamepad.lua:132 registers the
                -- with-header variant of the same template, so the Normal and
                -- Veteran groups can be labelled without a second template.
                -- Base Specific Dungeons splits them across header tabs; we
                -- merge them into one list, so each group announces itself.
                if i == 1 and type(group.header) == "string" and group.header ~= ""
                   and method(list, "AddEntryWithHeader") and method(entryData, "SetHeader") then
                    invoke(entryData, "SetHeader", group.header)
                    local okAdd = invoke(list, "AddEntryWithHeader", ENTRY_TEMPLATE, entryData)
                    if not okAdd then invoke(list, "AddEntry", ENTRY_TEMPLATE, entryData) end
                else
                    invoke(list, "AddEntry", ENTRY_TEMPLATE, entryData)
                end
                added = added + 1
            end
        end
    end

    -- Never a blank list.
    if added == 0 then
        local entryDataClass = gtable("ZO_GamepadEntryData")
        if entryDataClass == nil or type(entryDataClass.New) ~= "function" then
            return false, "ZO_GamepadEntryData unavailable"
        end
        local menuIcon = MENU_ICON
        if type(categoryData) == "table" and type(categoryData.menuIcon) == "string" then
            menuIcon = categoryData.menuIcon
        end
        local title, reason = Tab.EmptyStateText(planCount, 0, apiOk)
        local okNew, entryData = pcall(entryDataClass.New, entryDataClass, title or "", menuIcon)
        if okNew and isControl(entryData) then
            pcall(function() entryData.data = Tab.EmptyStateData(title, reason) end)
            -- Disabled, so the base A keybind's enabled() (:214-221) is false and
            -- ToggleLocationSelected can never be reached with a stand-in.
            invoke(entryData, "SetEnabled", false)
            invoke(entryData, "SetSelected", false)
            invoke(list, "AddEntry", ENTRY_TEMPLATE, entryData)
        end
    end

    invoke(list, "Commit")

    -- :169 -- the base refreshes the strip whenever selection changes; our own
    -- two descriptors need the same nudge when the list is rebuilt.
    Tab._UpdateKeybinds(hostObj)
    return true
end

function Tab._UpdateKeybinds(hostObj)
    local strip = gobject("KEYBIND_STRIP")
    if strip == nil then return end
    local descriptor = field(hostObj, "keybindStripDescriptor")
    if type(descriptor) ~= "table" then return end
    invoke(strip, "UpdateKeybindButtonGroup", descriptor)
end

-- Our own header, used in place of the specific view's Normal/Veteran tab bar.
-- We never mutate self.specificHeaderData; we hand RefreshHeaderAndView a
-- different table, exactly as the base hands it categoryHeaderData or
-- randomHeaderData (zo_activityfindertemplate_gamepad.lua:57-60, :690-694).
--
-- THE NORMAL / VETERAN TAB BAR.
-- The player asked for "that same system replicated ... giving the players the
-- same familiar system", so this is a line-for-line mirror of the base game's
-- own RefreshSpecificFilters (zo_activityfindertemplate_gamepad.lua:601-651)
-- rather than an invented control:
--   :605-606  the activity types come from dataManager:GetFilterModeData()
--   :610      a type only earns a tab if it actually has locations, measured
--             with GetNumLocationsByActivity(type, modes:GetVisibleEntryTypes())
--   :611-612  level-locked types are skipped
--   :616      the tab is named GetString("SI_LFGACTIVITY", activityType)
--   :623-648  >1 type -> tabBarEntries; exactly 1 -> titleText; 0 -> {}
--   :633      the list is re-narrated on a tab change
--
-- A native dropdown was considered and rejected: ZO_GamepadDropdownItem is only
-- registered on the parametric-dialog list pool (zo_genericdialog_gamepad.lua:763-766)
-- and this screen is not a dialog. The header tab bar is what the base game
-- itself uses for this exact choice, and it is what the player asked for.

-- Mirrors :608-621. Returns { { activityType, difficulty, name }, ... }.
function Tab.ValidActivityTypes(hostObj)
    local valid = {}
    local defs = Tab.DungeonActivityTypes()
    if #defs == 0 then return valid end

    local h = hostObj or Tab._hostObj
    local mgr = gobject("ZO_ACTIVITY_FINDER_ROOT_MANAGER")

    local visibleEntryTypes = nil
    local dm = field(h, "dataManager")
    if dm ~= nil then
        local okModes, modes = invoke(dm, "GetFilterModeData")
        if okModes and modes ~= nil then
            local okVis, vis = invoke(modes, "GetVisibleEntryTypes")
            if okVis then visibleEntryTypes = vis end
        end
    end

    for i = 1, #defs do
        local def = defs[i]
        local keep = true

        -- :610 -- no locations, no tab.
        if mgr ~= nil and method(mgr, "GetNumLocationsByActivity") then
            local okN, n = invoke(mgr, "GetNumLocationsByActivity", def.activityType, visibleEntryTypes)
            if okN and type(n) == "number" and n <= 0 then keep = false end
        end

        -- :611-612 -- a level-locked type is not offered.
        if keep and h ~= nil and method(h, "GetLevelLockInfoByActivity") then
            local okLock, isLocked = invoke(h, "GetLevelLockInfoByActivity", def.activityType)
            if okLock and isLocked then keep = false end
        end

        if keep then
            valid[#valid + 1] = {
                activityType = def.activityType,
                difficulty   = def.difficulty,
                name         = def.header,
            }
        end
    end
    return valid
end

-- Pure: given the valid types and the current selection, what shape should the
-- header be? Mirrors :623-648 exactly. Returns (kind, entries, selectedIndex)
-- where kind is "tabs" | "single" | "empty".
function Tab.PlanHeader(validTypes, selectedDifficulty)
    if type(validTypes) ~= "table" or #validTypes == 0 then return "empty", {}, 0 end
    if #validTypes == 1 then return "single", validTypes, 1 end
    local index = 1
    for i = 1, #validTypes do
        if validTypes[i].difficulty == selectedDifficulty then index = i break end
    end
    return "tabs", validTypes, index
end

function Tab.HeaderData(hostObj)
    local title = L("SI_ACCOUNTHOLD_DF_ROW", "Quartermaster Dungeons")
    local valid = Tab.ValidActivityTypes(hostObj)
    local kind, entries, selectedIndex = Tab.PlanHeader(valid, Tab._difficulty)

    if kind == "empty" then
        return { titleText = title }
    end

    if kind == "single" then
        -- :639-644 -- one type, so there is nothing to choose; the type names
        -- the screen and the filter is pinned to it.
        Tab._difficulty = entries[1].difficulty
        return { titleText = title, headerText = entries[1].name }
    end

    -- :624-638 -- one tab per activity type, in the finder's own order.
    local tabBarEntries = {}
    for i = 1, #entries do
        local activityData = entries[i]
        tabBarEntries[i] = {
            text = activityData.name,
            callback = function()
                Tab._difficulty = activityData.difficulty
                -- ZO_GamepadGenericHeader_Refresh fires the selected tab's
                -- callback while it commits the bar (genericheaders.lua:646).
                -- RefreshHeaderAndView calls RefreshView itself immediately
                -- afterwards, so rebuilding here as well would run the harvest
                -- twice for one tab press.
                if not Tab._inHeaderRefresh then
                    local h = Tab._hostObj
                    if h ~= nil and Tab.IsActive(h) then invoke(h, "RefreshView") end
                end
                -- :631-633 -- re-narrate on a tab change.
                local narrator = gobject("SCREEN_NARRATION_MANAGER")
                local h2 = Tab._hostObj
                if narrator ~= nil and h2 ~= nil and method(narrator, "QueueParametricListEntry") then
                    local NARRATE_HEADER = true
                    invoke(narrator, "QueueParametricListEntry", field(h2, "entryList"), NARRATE_HEADER)
                end
            end,
        }
    end
    -- NO titleText here, deliberately.
    --
    -- titleText and tabBarEntries occupy the SAME header slot, and the base
    -- game treats them as mutually exclusive (:623-648): more than one activity
    -- type produces tabBarEntries, exactly one produces titleText, none
    -- produces an empty table. Supplying both -- which this did -- left
    -- "Quartermaster Dungeons" rendered in the same space as the Normal /
    -- Veteran tab labels, which is the reported defect (BUGS.md QMQ-2).
    --
    -- The two branches above keep their titleText: with 0 or 1 activity types
    -- there is no tab bar, so the slot is free and naming the screen is right.
    return {
        tabBarEntries      = tabBarEntries,
        tabBarEntryIndex   = selectedIndex,
    }
end

-- Pure: does the current filter admit this activity type's difficulty?
function Tab.DifficultyAllows(filter, difficulty)
    if filter == nil or filter == Tab.DIFFICULTY_ALL then return true end
    return filter == difficulty
end

-- Pure: set the filter, returning (changed, value). Rejects unknown values so a
-- bad tab callback can never blank the list.
function Tab.SetDifficulty(value)
    if value ~= Tab.DIFFICULTY_ALL and value ~= Tab.DIFFICULTY_NORMAL
       and value ~= Tab.DIFFICULTY_VETERAN then
        return false, Tab._difficulty
    end
    local changed = Tab._difficulty ~= value
    Tab._difficulty = value
    return changed, value
end

-- ===========================================================================
-- ACTIONS
-- ===========================================================================

local function selectionReader()
    local mgr = gobject("ZO_ACTIVITY_FINDER_ROOT_MANAGER")
    return function(location)
        if location == nil then return false end
        local ok, sel = invoke(location, "IsSelected")
        return ok and sel or false
    end, mgr
end

function Tab.CurrentMatches()
    return Tab.Flatten(Tab._groups)
end

-- Select All / Clear All. Goes through the base manager so numSelected and the
-- OnSelectionsChanged callback (zo_activityfinderroot_manager.lua:534-547) stay
-- correct -- the X keybind's visibility depends on both.
function Tab.ToggleSelectAll()
    local matches = Tab.CurrentMatches()
    if #matches == 0 then
        alert(L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_TITLE", "No dungeons to show"))
        return 0
    end

    local isSelected, mgr = selectionReader()
    if mgr == nil or not method(mgr, "SetLocationSelected") then
        diag("error", "ZO_ACTIVITY_FINDER_ROOT_MANAGER:SetLocationSelected unavailable")
        return 0
    end

    local target = not Tab.AreAllSelected(matches, isSelected)
    local changed = 0

    -- Every SetLocationSelected fires OnSelectionsChanged, which the base screen
    -- answers with RefreshSelections -> RefreshView
    -- (zo_activityfindertemplate_gamepad.lua:378-381, :154). Left alone that is
    -- one full list rebuild PER DUNGEON. Suspend our rebuild and do one at the end.
    Tab._suspendRebuild = true
    for i = 1, #matches do
        local ok = invoke(mgr, "SetLocationSelected", matches[i].location, target)
        if ok then changed = changed + 1 end
    end
    Tab._suspendRebuild = false

    local h = host()
    if h ~= nil then
        local okBuild, built, why = pcall(Tab._BuildView, h)
        if not okBuild or built == false then
            diag("error", "select-all rebuild failed, handing back to base: %s",
                 tostring(okBuild and why or built))
            Tab._broken = true
            invoke(h, "RefreshView")
        end
    end
    return changed, target
end

function Tab.SelectAllName()
    local matches = Tab.CurrentMatches()
    local isSelected = selectionReader()
    if #matches > 0 and Tab.AreAllSelected(matches, isSelected) then
        return L("SI_ACCOUNTHOLD_DF_ROW_CLEAR_ALL", "Clear All")
    end
    return L("SI_ACCOUNTHOLD_DF_ROW_SELECT_ALL", "Select All")
end

-- QUARTERMASTER QUEUE -- the one thing this screen does that Specific Dungeons
-- does not. Bound to Y.
--
-- Deliberately NOT called "Random": it is only random if everything is ticked.
-- It picks from the dungeons the player SELECTED on this tab.
--
-- It is not the in-game matchmaker and does not touch StartActivityFinderSearch.
-- It picks one of the selected dungeons and TRAVELS the player there.
--
-- IMPORTANT, and the cause of the "spins but never goes anywhere" bug: the old
-- implementation only ever called Travel:ShowOnMap. Showing a node on the world
-- map is not travelling to it, so the wheel spun, the map moved, and the player
-- never left. A deliberate Y press IS the player's confirmation, so this now
-- calls Travel:TravelTo and only falls back to ShowOnMap when travel is refused.
--
-- Every AccountHold.Travel entry point is MULTI-RETURN and every return is
-- captured here; collapsing them is what made the failure silent:
--   FindNodeForActivity -> (nodeIndex, matchKind)   Travel.lua:293
--   CanTravelTo         -> (canTravel, reason)      Travel.lua:353
--   TravelTo            -> (performed, reason)      Travel.lua:512
--   ShowOnMap           -> (shown, reason)          Travel.lua:443
--
-- `roll` is injectable so the wheel is testable; PickOne is the shared
-- implementation in AccountHold/src/DungeonQueue.lua, so the dialog and this
-- screen can never spin differently.
--
-- GROUP TRAVEL IS NOT POSSIBLE FROM AN ADDON. The in-game queue moves a group
-- because the SERVER does it, off the ready-check the player accepts
-- (AcceptLFGReadyCheckNotification, ESOUIDocumentation.txt:17889 @ API 101050);
-- there is no Lua call anywhere in that chain. Every jump API -- FastTravelToNode
-- (:15384), JumpToGroupMember (:13890), JumpToGroupLeader (:13888) -- moves ONLY
-- the caller. So this moves the player, and says so.
--
-- PURE DECISION HELPER. Everything above the alert() is decided here, with no
-- ZO calls at all, so the whole matrix is testable.
--   travel: { find=fn(activity)->node,kind  can=fn(node)->ok,reason
--             go=fn(node)->done,reason      show=fn(node)->shown,reason }
-- Returns (action, detail) where action is one of:
--   "travelled"     we went there
--   "shown"         we could NOT travel -- detail.reason says why -- so the map
--                   was centred on it instead
--   "blocked"       we could not travel AND could not even show it
--   "no_node"       nothing on the map matches the dungeon
--   "no_travel_api" the Travel module is not available
--   "failed"        something else went wrong; detail.reason says what
function Tab.PlanQueueTravel(pick, travel)
    if type(pick) ~= "table" then return "failed", { reason = "no_pick" } end
    local name = tostring(pick.name or "?")

    if type(travel) ~= "table" or type(travel.find) ~= "function" then
        return "no_travel_api", { name = name, reason = "no_api" }
    end

    -- BOTH returns. matchKind == "zone" means the right zone, not necessarily
    -- the right door, and the player is told.
    --
    -- The activity record is passed with the activityId folded in, so Travel's
    -- zone-id tier can run. Without it Travel falls back to name matching,
    -- which cannot resolve a group dungeon at all (BUGS.md QMQ-1). A shallow
    -- copy, because the record belongs to the Priorities plan and must not be
    -- mutated by a queue roll.
    local activity = pick.activity
    if pick.activityId and type(activity) == "table" then
        local merged = {}
        for k, v in pairs(activity) do merged[k] = v end
        merged.activityId = pick.activityId
        activity = merged
    end

    local okFind, nodeIndex, matchKind = pcall(travel.find, activity)
    if not okFind or type(nodeIndex) ~= "number" then
        -- SELF-DIAGNOSING FAILURE, STRAIGHT TO CHAT.
        --
        -- What a dungeon's fast-travel node is called -- or whether one exists
        -- -- is game data that cannot be read from esoui source, and two
        -- guesses at it have already shipped wrong. So when the lookup fails,
        -- print what the client actually reports.
        --
        -- To CHAT, not the diagnostics ring buffer. The buffer needs the
        -- settings panel or the gear-scene keystrip to read, the panel needs
        -- LibHarvensAddonSettings which many players do not have, and a
        -- diagnostic nobody can reach is not a diagnostic. This prints where
        -- the player already is, at the moment the thing failed.
        pcall(function()
            local Tr = AccountHold and AccountHold.TravelTrace
            local T  = AccountHold and AccountHold.Travel
            if type(Tr) ~= "table" or type(T) ~= "table" then return end

            Tr.Say("could not find a destination for '%s'.", tostring(name))
            T:Probe(activity, function(fmt, ...) Tr.Say(fmt, ...) end)

            -- The decisive census: do dungeons have travel nodes at all, and
            -- what are they called? Capped so a failure cannot flood chat.
            local okN, nodes = pcall(T.DungeonNodes, T)
            if okN and type(nodes) == "table" then
                Tr.Say("dungeon-type travel nodes known to the client: %d", #nodes)
                for i = 1, math.min(#nodes, 12) do
                    Tr.Say("  '%s' (node %s, zone %s)",
                        tostring(nodes[i].name), tostring(nodes[i].index), tostring(nodes[i].zone))
                end
                if #nodes > 12 then Tr.Say("  ...and %d more", #nodes - 12) end
            end
        end)
        return "no_node", { name = name, reason = "unknown_node" }
    end

    local detail = { name = name, node = nodeIndex, matchKind = matchKind }

    -- Fall back to the map, ALWAYS carrying the reason travel did not happen.
    -- Never spin and silently do nothing.
    local function fallback()
        if type(travel.show) == "function" then
            local okShow, shown, showReason = pcall(travel.show, nodeIndex)
            if okShow and shown then
                detail.shown = true
                return "shown", detail
            end
            detail.showReason = okShow and showReason or "no_api"
        end
        return "blocked", detail
    end

    if type(travel.can) == "function" then
        local okCan, canTravel, reason = pcall(travel.can, nodeIndex)
        if not okCan then
            detail.reason = "no_api"
            return fallback()
        end
        if not canTravel then
            detail.reason = reason or "cannot_teleport"
            return fallback()
        end
    end

    if type(travel.go) == "function" then
        local okGo, performed, reason = pcall(travel.go, nodeIndex)
        if okGo and performed then
            detail.reason = reason or "ok"
            return "travelled", detail
        end
        detail.reason = (okGo and reason) or "no_api"
    else
        detail.reason = "no_api"
    end

    return fallback()
end

-- Bind the pure planner to the real AccountHold.Travel, capturing every return.
function Tab._TravelAdapter()
    local Travel = AccountHold and AccountHold.Travel
    if type(Travel) ~= "table" or type(Travel.FindNodeForActivity) ~= "function" then
        return nil
    end
    local a = {}
    a.find = function(activity)
        local ok, node, kind = pcall(Travel.FindNodeForActivity, Travel, activity)
        if not ok then return nil end
        return node, kind
    end
    if type(Travel.CanTravelTo) == "function" then
        a.can = function(node)
            local ok, can, reason = pcall(Travel.CanTravelTo, Travel, node)
            if not ok then return nil, "no_api" end
            return can, reason
        end
    end
    if type(Travel.TravelTo) == "function" then
        a.go = function(node)
            local ok, done, reason = pcall(Travel.TravelTo, Travel, node)
            if not ok then return false, "no_api" end
            return done, reason
        end
    end
    if type(Travel.ShowOnMap) == "function" then
        a.show = function(node)
            local ok, shown, reason = pcall(Travel.ShowOnMap, Travel, node)
            if not ok then return false, "no_api" end
            return shown, reason
        end
    end
    return a
end

-- Turn a planner verdict into the sentence the player actually sees. Pure.
function Tab.QueueTravelText(action, detail)
    local d = type(detail) == "table" and detail or {}
    local name = tostring(d.name or "?")

    local function reasonText(reason)
        local Travel = AccountHold and AccountHold.Travel
        if type(Travel) == "table" and type(Travel.GetReasonText) == "function" then
            local ok, text = pcall(Travel.GetReasonText, Travel, reason)
            if ok and type(text) == "string" and text ~= "" then return text end
        end
        return tostring(reason or "unknown")
    end

    local caveat = ""
    if d.matchKind == "zone" then
        caveat = " " .. L("SI_ACCOUNTHOLD_DF_QM_QUEUE_ZONE_CAVEAT",
            "(nearest wayshrine to the zone, not the dungeon door.)")
    end

    if action == "travelled" then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_TRAVELLING",
            "Quartermaster Queue: %s. Travelling now."), name) .. caveat
    elseif action == "shown" then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_SHOWN",
            "Quartermaster Queue: %s. Cannot travel (%s) - shown on the map instead."),
            name, reasonText(d.reason)) .. caveat
    elseif action == "blocked" then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_BLOCKED",
            "Quartermaster Queue: %s. Cannot travel: %s"), name, reasonText(d.reason))
    elseif action == "no_node" then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_NO_NODE",
            "Quartermaster Queue: %s. No wayshrine matches it, so it cannot be reached."), name)
    elseif action == "no_travel_api" then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_NO_API",
            "Quartermaster Queue: %s. Travel is unavailable right now."), name)
    end
    return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_FAILED",
        "Quartermaster Queue: %s. Travel failed: %s"), name, reasonText(d.reason))
end

function Tab.QuartermasterQueue(roll)
    local matches = Tab.CurrentMatches()
    if #matches == 0 then
        alert(L("SI_ACCOUNTHOLD_DF_ROW_EMPTY_TITLE", "No dungeons to show"))
        return nil, "empty"
    end

    local pool, usingSelection = Tab.QueuePool(matches, selectionReader())
    local entries = Tab.ToQueueEntries(pool)
    if #entries == 0 then
        alert(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_NONE_SELECTED",
            "Quartermaster Queue: select at least one dungeon first."))
        return nil, "empty"
    end

    local DQ = dungeonQueue()
    if not DQ or type(DQ.PickOne) ~= "function" then
        alert(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_NO_PICKER",
            "Quartermaster Queue is unavailable: the picker did not load."))
        diag("error", "DungeonQueue.PickOne unavailable")
        return nil, "no_api"
    end

    local okPick, pick = pcall(DQ.PickOne, entries, roll)
    if not okPick or type(pick) ~= "table" then
        alert(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_NO_PICK",
            "Quartermaster Queue could not pick a dungeon."))
        return nil, "empty"
    end

    local action, detail = Tab.PlanQueueTravel(pick, Tab._TravelAdapter())
    diag("info", "quartermaster queue: %s -> %s (node %s, %s)",
         tostring(pick.name), tostring(action),
         tostring(detail and detail.node), tostring(detail and detail.reason))

    -- ALWAYS say something. The bug this replaces spun and went quiet.
    alert(Tab.QueueTravelText(action, detail))

    -- The queue moves the PLAYER only. An addon cannot move a group: the base
    -- queue's zone transfer is done by the server off the ready check
    -- (AcceptLFGReadyCheckNotification, ESOUIDocumentation.txt:17889), and every
    -- jump API in the docs moves only the caller. Tell the group what to do.
    if action == "travelled" and usingSelection ~= nil then
        local groupSize = 0
        local fn = gfn("GetGroupSize")
        if fn then
            local okG, n = pcall(fn)
            if okG and type(n) == "number" then groupSize = n end
        end
        if groupSize > 1 then
            alert(string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_GROUP",
                "Your group is not moved automatically - tell them: %s."),
                tostring(pick.name)))
        end
    end

    return pick, action, detail
end

-- Kept so anything still calling the old names keeps working.
Tab.SoloQueue  = Tab.QuartermasterQueue
Tab.RandomPick = Tab.QuartermasterQueue

-- Pure: which dungeons the Quartermaster Queue picks from. The player's own
-- words -- "it will randomly pick from all the SELECTED dungeons" -- so the
-- ticked rows are the pool. Falling back to everything when nothing is ticked
-- would be a surprise trip, so an empty selection stays empty and the caller
-- tells the player to tick something.
-- Returns (pool, usingSelection).
function Tab.QueuePool(matches, isSelected)
    local pool = {}
    if type(matches) ~= "table" then return pool, false end
    for i = 1, #matches do
        local ok, sel = pcall(isSelected, matches[i].location)
        if ok and sel then pool[#pool + 1] = matches[i] end
    end
    return pool, #pool > 0
end
Tab.SoloQueuePool = Tab.QueuePool

-- The label must make it obvious this is not matchmaking, and must say how many
-- dungeons the press will pick from.
function Tab.QuartermasterQueueName()
    local matches = Tab.CurrentMatches()
    local pool = Tab.QueuePool(matches, selectionReader())
    if #pool > 0 then
        return string.format(L("SI_ACCOUNTHOLD_DF_QM_QUEUE_N",
            "Quartermaster Queue (%d)"), #pool)
    end
    return L("SI_ACCOUNTHOLD_DF_QM_QUEUE_EMPTY", "Quartermaster Queue")
end
Tab.SoloQueueName = Tab.QuartermasterQueueName

-- ===========================================================================
-- ACTIVE STATE -- the single authority for "are our rows allowed on screen?"
-- ===========================================================================
--
-- THIS IS THE RANDOM DUNGEONS FIX. The base game keeps Random and Specific
-- apart with exactly one piece of state, self.navigationMode
-- (zo_activityfindertemplate_gamepad.lua:433 bails on CATEGORIES, :573 branches
-- RANDOM vs everything-else), and the ONLY correct authority for us is that
-- same field ON THE HOST WE WERE HANDED.
--
-- The previous implementation read Tab._hostObj.navigationMode -- a DIFFERENT
-- object from the `selfHost` the wrapper was invoked with -- and, when it could
-- not read it, fell back to Tab._active, a flag written by our own
-- SetNavigationMode wrapper BEFORE the base method runs. The base only assigns
-- self.navigationMode inside `if self.navigationMode ~= navigationMode`
-- (:806-812), so a SetNavigationMode call that the base declines to act on left
-- Tab._active saying "ours" while the screen was still on Random. From then on
-- our RefreshView wrapper answered for the Random view.
--
-- Now: derive it from `hostObj` only, and FAIL CLOSED. Unreadable mode, no
-- host, broken, or mid-harvest all mean "not ours", which means the base
-- implementation runs. Our rows can only ever appear when the screen itself
-- says our mode is current.
function Tab.IsOurMode(mode)
    return mode == NAV_MODE
end

function Tab.IsActive(hostObj)
    if Tab._broken then return false end
    -- During a harvest we deliberately drive the BASE RefreshView with the
    -- base's own SPECIFIC mode. Anything that re-enters while that is true must
    -- get the base behaviour, not ours.
    if Tab._harvesting then return false end

    local h = hostObj
    if h == nil then h = Tab._hostObj end
    if h == nil then return false end

    local ok, mode = pcall(function() return h.navigationMode end)
    if not ok then return false end
    return Tab.IsOurMode(mode)
end

-- Leave our mode cleanly and hand the finder's own filter state back exactly as
-- we found it. Called on EVERY transition away from our mode, not just on
-- teardown -- leaving _suspendRebuild set was enough on its own to make the next
-- RefreshView a no-op.
function Tab.Deactivate(hostObj)
    Tab._active         = false
    Tab._suspendRebuild = false
    Tab._harvesting     = false
    Tab._groups         = nil

    local h = hostObj or Tab._hostObj
    if h == nil then return end

    -- The harvest borrows currentSpecificActivityType (the field the base's own
    -- FilterByActivity owns, :393-396). It restores it, but if the base threw
    -- mid-harvest the restore could have been skipped, so put the finder's own
    -- filter back the way the base builds it.
    if Tab._savedSpecificActivityType ~= nil then
        pcall(function() h.currentSpecificActivityType = Tab._savedSpecificActivityType end)
        Tab._savedSpecificActivityType = nil
    end

    -- :601-651 rebuilds specificHeaderData from the live activity types. We
    -- never mutate that table, but re-deriving it is the cheapest way to be sure
    -- the Normal/Veteran tab bar the SPECIFIC view depends on is the base's own.
    invoke(h, "RefreshSpecificFilters")
end

-- ===========================================================================
-- INSTALL
-- ===========================================================================

-- Find our row in the category list without touching list internals:
-- ZO_ParametricScrollList:GetNumEntries / :GetEntryData
-- (zo_parametricscrolllist.lua:256-270).
function Tab.FindCategoryRow(list)
    if not isControl(list) then return nil end
    local okN, n = invoke(list, "GetNumEntries")
    if not okN or type(n) ~= "number" then return nil end
    for i = 1, n do
        local okD, entry = invoke(list, "GetEntryData", i)
        if okD and isControl(entry) then
            local data = field(entry, "data")
            if Tab.IsOurCategoryData(data) then return i, entry end
        end
    end
    return nil
end

function Tab._AppendCategoryRow(hostObj)
    local list = field(hostObj, "categoryList")
    -- zo_activityfindertemplate_gamepad.lua:124-128 -- the finder can be built
    -- with NO category list at all. Nothing to append to; fail closed.
    if not isControl(list) or not method(list, "AddEntry") then
        return false, "no categoryList (see zo_activityfindertemplate_gamepad.lua:124-128)"
    end

    -- Learn the base game's own Random / Specific mode numbers from its own rows
    -- BEFORE we add ours, so ours can never be mistaken for one of them and so
    -- nothing in this file hardcodes NAVIGATION_MODES (:4-9).
    local randomMode, specificMode = Tab.DiscoverBaseModes(Tab.ReadEntries(list))
    if specificMode == nil then
        return false, "could not find the base Random/Specific rows to proxy"
    end
    Tab._randomMode, Tab._specificMode = randomMode, specificMode

    if Tab.FindCategoryRow(list) then return true, "already present" end

    local entryDataClass = gtable("ZO_GamepadEntryData")
    if entryDataClass == nil or type(entryDataClass.New) ~= "function" then
        return false, "ZO_GamepadEntryData unavailable"
    end

    local categoryData = field(hostObj, "categoryData")
    local menuIcon = MENU_ICON
    if type(categoryData) == "table" and type(categoryData.menuIcon) == "string" then
        menuIcon = categoryData.menuIcon
    end

    local text = L("SI_ACCOUNTHOLD_DF_ROW", "Quartermaster Dungeons")
    local okNew, entryData = pcall(entryDataClass.New, entryDataClass, text, menuIcon)
    if not okNew or not isControl(entryData) then
        return false, "could not build the entry data"
    end

    -- :103-106 / :111-114 -- exactly the shape the base game's own two rows use.
    local okData = pcall(function() entryData.data = Tab.CategoryRowData() end)
    if not okData then return false, "could not attach the row data" end
    invoke(entryData, "SetIconTintOnSelection", true)

    local okAdd = invoke(list, "AddEntry", CATEGORY_TEMPLATE, entryData)
    if not okAdd then return false, "AddEntry refused" end

    -- Re-lay-out. blockSelectionChangedCallback keeps the append from firing
    -- SetupList's OnSelectedEntry (:164-176) while we are mid-install.
    local DONT_RESELECT, BLOCK_CALLBACK = false, true
    local okCommit = invoke(list, "Commit", DONT_RESELECT, BLOCK_CALLBACK)
    if not okCommit then invoke(list, "Commit") end

    Tab._categoryRow = entryData
    return true
end

function Tab.Install(addonRef)
    if addonRef ~= nil then Tab.addon = addonRef end
    if Tab._hooked then return true end

    local h = gobject("DUNGEON_FINDER_GAMEPAD")
    if h == nil then return fail("DUNGEON_FINDER_GAMEPAD unavailable") end
    if not Tab.IsDungeonFinder(h) then
        return fail("DUNGEON_FINDER_GAMEPAD is not the dungeon finder")
    end

    local origSetNavigationMode   = method(h, "SetNavigationMode")
    local origRefreshView         = method(h, "RefreshView")
    local origRefreshHeaderAndView = method(h, "RefreshHeaderAndView")
    if not origSetNavigationMode or not origRefreshView or not origRefreshHeaderAndView then
        return fail("Dungeon Finder methods missing")
    end

    local okRow, why = Tab._AppendCategoryRow(h)
    if not okRow then return fail(tostring(why)) end

    Tab._orig = {
        SetNavigationMode    = origSetNavigationMode,
        RefreshView          = origRefreshView,
        RefreshHeaderAndView = origRefreshHeaderAndView,
    }

    -- (1) Bookkeeping + a CLEAN EXIT. SetNavigationMode already tolerates our
    --     unknown mode (:786-795 route it to entryList, :806-812 set it and
    --     refresh), so this wrapper deliberately changes nothing about the base
    --     behaviour. What it MUST do is fully deactivate when the screen leaves
    --     our mode: the old wrapper cleared a flag and left _suspendRebuild,
    --     _groups and the borrowed currentSpecificActivityType behind.
    local ok1 = pcall(function()
        h.SetNavigationMode = function(selfHost, mode, ...)
            local leaving = Tab._active and not Tab.IsOurMode(mode)
            Tab._active = Tab.IsOurMode(mode) and not Tab._broken
            if leaving then
                pcall(Tab.Deactivate, selfHost)
            elseif not Tab._active then
                Tab._groups = nil
            end
            return origSetNavigationMode(selfHost, mode, ...)
        end
    end)
    if not ok1 then return fail("could not wrap SetNavigationMode") end

    -- (2) Our header instead of the specific view's Normal/Veteran tab bar.
    --     :690-694 would otherwise hand us self.specificHeaderData, whose tab bar
    --     belongs to the base filters and would be inert on our list.
    local ok2 = pcall(function()
        h.RefreshHeaderAndView = function(selfHost, headerData, ...)
            if Tab.IsActive(selfHost) then
                -- ZO_GamepadGenericHeader_Refresh commits the tab bar and fires
                -- the selected tab's callback (genericheaders.lua:646). This
                -- call refreshes the view itself straight afterwards, so the
                -- callback must not also rebuild -- see Tab.HeaderData.
                local ourHeader = Tab.HeaderData(selfHost)
                Tab._inHeaderRefresh = true
                local okCall, a, b = pcall(origRefreshHeaderAndView, selfHost, ourHeader, ...)
                Tab._inHeaderRefresh = false
                if okCall then return a, b end
                return nil
            end
            return origRefreshHeaderAndView(selfHost, headerData, ...)
        end
    end)
    if not ok2 then
        pcall(function() h.SetNavigationMode = origSetNavigationMode end)
        return fail("could not wrap RefreshHeaderAndView")
    end

    -- (3) The list itself. Any failure latches _broken and hands the screen back
    --     to the base implementation for the rest of the session.
    local ok3 = pcall(function()
        h.RefreshView = function(selfHost, ...)
            if not Tab.IsActive(selfHost) then
                return origRefreshView(selfHost, ...)
            end
            if Tab._suspendRebuild then return end
            local ok, built, why = pcall(Tab._BuildView, selfHost)
            if not ok or built == false then
                Tab._broken = true
                Tab._active = false
                diag("error", "view build failed, handing back to base: %s",
                     tostring(ok and why or built))
                return origRefreshView(selfHost, ...)
            end
        end
    end)
    if not ok3 then
        pcall(function() h.SetNavigationMode = origSetNavigationMode end)
        pcall(function() h.RefreshHeaderAndView = origRefreshHeaderAndView end)
        return fail("could not wrap RefreshView")
    end

    Tab._hostObj = h
    Tab._hooked = true
    Tab._broken = false
    Tab._lastFailure = nil

    -- Best-effort: if either append is refused the row still works, it just
    -- loses that shortcut.
    Tab._InstallKeybinds(h)

    diag("info", "Quartermaster Dungeons added to the gamepad Dungeon Finder.")
    return true
end

-- Take over an EXISTING keybind descriptor in place, delegating to the original
-- whenever our tab is not the active mode.
--
-- This is how the Y button is claimed. UI_SHORTCUT_TERTIARY already exists on
-- this screen (zo_activityfindertemplate_gamepad.lua:239), and appending a
-- second one would hit zo_keybindstrip.lua:341-343 --
-- internalassert(false, "Duplicate Keybind: ...") followed by
-- RemoveKeybindButton(existingDescriptor) -- i.e. an assert AND the loss of the
-- base binding. Swapping four fields on the SAME table keeps the strip's
-- references valid, keeps exactly one TERTIARY in the group, and never reaches
-- the duplicate path.
--
-- Returns a restore function, or nil if the keybind is not present.
function Tab.TakeOverDescriptor(descriptor, keybind, name, callback, activeTest)
    if type(descriptor) ~= "table" then return nil end
    local target = nil
    for i = 1, #descriptor do
        local d = descriptor[i]
        if type(d) == "table" and d.keybind == keybind then target = d break end
    end
    if target == nil then return nil end

    local origName     = target.name
    local origCallback = target.callback
    local origVisible  = target.visible
    local origEnabled  = target.enabled

    local function ours()
        local ok, active = pcall(activeTest)
        return ok and active and true or false
    end
    local function passthrough(orig, default, ...)
        if orig == nil then return default end
        if type(orig) ~= "function" then return orig end
        local ok, v = pcall(orig, ...)
        if not ok then return default end
        return v
    end

    target.name = function(...)
        if ours() then
            local ok, text = pcall(name)
            if ok then return text end
            return ""
        end
        return passthrough(origName, "", ...)
    end
    target.callback = function(...)
        if ours() then return callback() end
        if type(origCallback) == "function" then return origCallback(...) end
    end
    target.visible = function(...)
        if ours() then return true end
        return passthrough(origVisible, true, ...) and true or false
    end
    target.enabled = function(...)
        if ours() then return true end
        return passthrough(origEnabled, true, ...) and true or false
    end

    return function()
        target.name     = origName
        target.callback = origCallback
        target.visible  = origVisible
        target.enabled  = origEnabled
    end
end

function Tab._InstallKeybinds(hostObj)
    local descriptor = field(hostObj, "keybindStripDescriptor")
    if type(descriptor) ~= "table" then
        diag("warn", "keybindStripDescriptor unavailable; Select All / Quartermaster Queue unbound")
        return false
    end

    -- The host is captured, so the visibility test asks the SAME object the
    -- wrappers do rather than trusting a flag.
    local visible = function() return Tab.IsActive(hostObj) end

    -- Left stick click = Select All. Explicitly kept: the player asked for it.
    local selectAll = Tab.MakeKeybindDescriptor(
        SELECT_ALL_KEY, SELECT_ALL_BIND,
        function() return Tab.SelectAllName() end,
        function() Tab.ToggleSelectAll() end,
        visible)
    if selectAll and Tab.AppendDescriptor(descriptor, selectAll, SELECT_ALL_KEY) == nil then
        diag("warn", "%s already claimed; Select All unbound", SELECT_ALL_BIND)
    end

    -- Y = Quartermaster Queue. Taken over in place; the right stick is left free.
    Tab._restoreTertiary = Tab.TakeOverDescriptor(
        descriptor, SOLO_QUEUE_BIND,
        function() return Tab.QuartermasterQueueName() end,
        function() Tab.QuartermasterQueue() end,
        visible)

    if Tab._restoreTertiary == nil then
        -- Not present on this client: appending is safe precisely because there
        -- is nothing to duplicate.
        local qm = Tab.MakeKeybindDescriptor(
            SOLO_QUEUE_KEY, SOLO_QUEUE_BIND,
            function() return Tab.QuartermasterQueueName() end,
            function() Tab.QuartermasterQueue() end,
            visible)
        if qm and Tab.AppendDescriptor(descriptor, qm, SOLO_QUEUE_KEY) == nil then
            diag("warn", "%s already claimed; Quartermaster Queue unbound", SOLO_QUEUE_BIND)
        end
    else
        diag("info", "Quartermaster Queue bound to %s (taken over in place).", SOLO_QUEUE_BIND)
    end
    return true
end

-- Restore discipline: put back every original method and take our own additions
-- out again, in the reverse order they went in. Same doctrine as
-- ui/BankTab_Gamepad.lua's keybind-group teardown.
function Tab.Uninstall()
    local h = Tab._hostObj
    Tab.Deactivate()
    Tab._DisarmPendingSelect()
    Tab._broken = false

    if h ~= nil and type(Tab._orig) == "table" then
        pcall(function() h.SetNavigationMode = Tab._orig.SetNavigationMode end)
        pcall(function() h.RefreshHeaderAndView = Tab._orig.RefreshHeaderAndView end)
        pcall(function() h.RefreshView = Tab._orig.RefreshView end)
    end

    if h ~= nil then
        local descriptor = field(h, "keybindStripDescriptor")
        if type(descriptor) == "table" then
            Tab.RemoveDescriptor(descriptor, SELECT_ALL_KEY)
            Tab.RemoveDescriptor(descriptor, SOLO_QUEUE_KEY)
        end

        -- Put the base TERTIARY descriptor's four fields back exactly as found.
        if type(Tab._restoreTertiary) == "function" then
            pcall(Tab._restoreTertiary)
        end
        Tab._restoreTertiary = nil

        -- zo_parametricscrolllist.lua:243-253 RemoveEntry takes the row back out
        -- by identity, so the base rows keep their own positions.
        local list = field(h, "categoryList")
        if isControl(list) and Tab._categoryRow ~= nil and method(list, "RemoveEntry") then
            invoke(list, "RemoveEntry", CATEGORY_TEMPLATE, Tab._categoryRow)
            invoke(list, "Commit")
        end
    end

    Tab._orig = nil
    Tab._categoryRow = nil
    Tab._hostObj = nil
    Tab._specificMode = nil
    Tab._randomMode = nil
    Tab._hooked = false
    return true
end

-- ===========================================================================
-- PUBLIC ENTRY POINTS
-- ===========================================================================

function Tab.IsAvailable()
    local h = gobject("DUNGEON_FINDER_GAMEPAD")
    return h ~= nil and Tab.IsDungeonFinder(h)
end

function Tab.IsEnabled()
    return Tab._hooked == true and Tab._broken == false
end

-- Open the native gamepad Dungeon Finder. Returns true only if the base screen
-- was actually reached; ui/DungeonFinder_Gamepad.lua falls back to its dialog
-- otherwise.
--
-- ZO_ActivityFinderRoot_Gamepad:ShowCategory (zo_activityfinderroot_gamepad.lua:302-320)
-- is the base game's own "take me to this finder" path -- it selects the main
-- menu entry and rebuilds the scene stack, which a bare SCENE_MANAGER:Push does
-- not do. We land the player on the category list, where Quartermaster Dungeons
-- now sits under Random and Specific; if the screen is ALREADY up we jump
-- straight into our mode.
-- The category table ZO_ActivityFinderRoot_Gamepad:ShowCategory expects.
--
-- ROOT CAUSE of "the Priorities X button drops me at the Specific Dungeons
-- selector": Tab.Open passed DUNGEON_FINDER_SCENE, the scene NAME STRING.
-- ShowCategory (zo_activityfinderroot_gamepad.lua:411) immediately does
-- categoryData.gamepadData, which on a string is an error, so the pcall swallowed
-- it, ShowCategory never ran, and we fell through to a bare SCENE_MANAGER:Push
-- that lands on the category list with no mode selected.
-- The real table is DungeonFinder_Manager:GetCategoryData()
-- (zo_dungeonfinder_manager.lua:43-45), reachable from the screen's dataManager.
function Tab.CategoryData(hostObj)
    local h = hostObj or Tab._hostObj or gobject("DUNGEON_FINDER_GAMEPAD")
    if h == nil then return nil end
    local existing = field(h, "categoryData")
    if type(existing) == "table" and existing.gamepadData ~= nil then return existing end
    local dm = field(h, "dataManager")
    if dm ~= nil and method(dm, "GetCategoryData") then
        local ok, data = invoke(dm, "GetCategoryData")
        if ok and type(data) == "table" then return data end
    end
    if type(existing) == "table" then return existing end
    return nil
end

function Tab.Open()
    if not Tab._hooked then
        local ok = Tab.Install()
        if not ok then return false, Tab._lastFailure end
    end

    local h = Tab._hostObj
    local okShowing, showing = invoke(h, "IsShowing")
    if okShowing and showing then
        local okJump = invoke(h, "SetNavigationMode", NAV_MODE)
        if okJump then return true end
    end

    local root = gobject("ZO_ACTIVITY_FINDER_ROOT_GAMEPAD")
    local categoryData = Tab.CategoryData(h)
    if root ~= nil and categoryData ~= nil and method(root, "ShowCategory") then
        if invoke(root, "ShowCategory", categoryData) then return true end
        diag("warn", "ShowCategory failed; trying SCENE_MANAGER")
    end

    local sm = gobject("SCENE_MANAGER")
    if sm ~= nil and method(sm, "Push") then
        if invoke(sm, "Push", DUNGEON_FINDER_SCENE) then return true end
    end
    return false, "could not open the Dungeon Finder scene"
end

-- ===========================================================================
-- ShowOnQuartermasterTab -- the entry point the Priorities blade's X button
-- should call.
-- ===========================================================================
--
-- SEMANTICS. Returns (landed, state):
--   true,  "shown"    the finder was ALREADY up; our mode is now current and
--                     that has been VERIFIED by reading navigationMode back.
--   true,  "pending"  the finder was not up. The scene has been pushed and a
--                     ONE-SHOT scene callback is armed that selects our mode as
--                     soon as the scene is shown. The player WILL land on the
--                     Quartermaster tab, one frame later.
--   false, <reason>   nothing happened, and <reason> says why. Reasons:
--                     "not_installed" | "no_screen" | "mode_rejected" |
--                     "could not open the Dungeon Finder scene"
--
-- Never throws; every ZOS touch is pcall'd; fails closed with a reason.
function Tab.ShowOnQuartermasterTab()
    if not Tab._hooked then
        local ok = Tab.Install()
        if not ok then return false, Tab._lastFailure or "not_installed" end
    end
    if Tab._broken then return false, "not_installed" end

    local h = Tab._hostObj
    if h == nil then return false, "no_screen" end

    -- Already up: switch mode now and CONFIRM it took. SetNavigationMode is a
    -- no-op when the mode already matches (:806-812), so read the field back
    -- rather than trusting the call's return.
    local okShowing, showing = invoke(h, "IsShowing")
    if okShowing and showing then
        invoke(h, "SetNavigationMode", NAV_MODE)
        if Tab.IsActive(h) then return true, "shown" end
        return false, "mode_rejected"
    end

    -- Not up yet. Arm a one-shot, THEN open: the base OnShowing (:676-697) sets
    -- CATEGORIES itself, so selecting our mode before the push would be undone.
    Tab._ArmPendingSelect()

    local opened, why = Tab.Open()
    if not opened then
        Tab._DisarmPendingSelect()
        return false, why or "could not open the Dungeon Finder scene"
    end

    -- Open() may have selected the mode directly if the screen came up
    -- synchronously.
    if Tab.IsActive(h) then
        Tab._DisarmPendingSelect()
        return true, "shown"
    end
    return true, "pending"
end

-- One-shot: select our mode the moment the finder's scene is shown, then remove
-- itself so it can never fire on a later, unrelated open.
-- GAMEPAD_DUNGEON_FINDER_SCENE is published at zo_dungeonfinder_manager.lua:40.
function Tab._ArmPendingSelect()
    Tab._DisarmPendingSelect()

    local scene = gobject("GAMEPAD_DUNGEON_FINDER_SCENE")
    if scene == nil or not method(scene, "RegisterCallback") then
        -- No scene object to hang it on; fall back to a flag the caller can act
        -- on, and to Tab.Open's own direct mode set.
        Tab._pendingSelect = true
        return false
    end

    local shownState = _G and rawget(_G, "SCENE_SHOWN")
    local handler
    handler = function(oldState, newState)
        if shownState ~= nil and newState ~= shownState then return end
        Tab._DisarmPendingSelect()
        local h = Tab._hostObj
        if h == nil then return end
        pcall(function() h:SetNavigationMode(NAV_MODE) end)
    end

    local ok = invoke(scene, "RegisterCallback", "StateChange", handler)
    if not ok then
        Tab._pendingSelect = true
        return false
    end
    Tab._pendingSelect = true
    Tab._pendingHandler = handler
    Tab._pendingScene = scene
    return true
end

function Tab._DisarmPendingSelect()
    local scene, handler = Tab._pendingScene, Tab._pendingHandler
    Tab._pendingSelect, Tab._pendingScene, Tab._pendingHandler = false, nil, nil
    if scene ~= nil and handler ~= nil and method(scene, "UnregisterCallback") then
        invoke(scene, "UnregisterCallback", "StateChange", handler)
    end
end

function Tab.Close()
    Tab.Deactivate()
    local sm = gobject("SCENE_MANAGER")
    if sm ~= nil and method(sm, "HideCurrentScene") then
        invoke(sm, "HideCurrentScene")
        return true
    end
    return false
end

function Tab:Initialize(addonRef)
    if addonRef ~= nil then Tab.addon = addonRef end
    local ok = Tab.Install(addonRef)
    if not ok then Tab:ScheduleRetry(addonRef) end
    return ok
end

-- DUNGEON_FINDER_GAMEPAD is created by zo_dungeonfinder_manager.lua at load, but
-- an add-on can still run before the gamepad object exists on a slow console
-- boot. EVENT_MANAGER is USERDATA (globalvars.lua:2-4) -- gobject, never gtable.
-- Getting that wrong is precisely the bug this file's header is about.
function Tab:ScheduleRetry(addonRef)
    if addonRef ~= nil then Tab.addon = addonRef end
    if Tab._retryScheduled then return false end

    local em = gobject("EVENT_MANAGER")
    local register = method(em, "RegisterForEvent")
    local unregister = method(em, "UnregisterForEvent")
    local eventId = gvalue("EVENT_PLAYER_ACTIVATED")
    if not register or eventId == nil then return false end

    local name = "AccountHold_QuartermasterDungeonsRetry"
    local ok = pcall(register, em, name, eventId, function()
        if unregister then pcall(unregister, em, name, eventId) end
        Tab._retryScheduled = false
        Tab.Install(Tab.addon)
    end)
    Tab._retryScheduled = ok and true or false
    return Tab._retryScheduled
end

return Tab
