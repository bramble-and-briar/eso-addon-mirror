-- AccountHold/ui/PrioritiesMenu_Gamepad.lua
--
-- Adds a "Priorities" entry to the GAMEPAD pause menu under COLLECTIONS
-- (Start -> Collections -> Priorities), alongside Collections, Item Sets and
-- Tribute Patrons, and registers the scene that entry opens. The list that
-- fills the scene lives in the sibling file ui/PrioritiesScreen_Gamepad.lua.
--
-- WHY THE COLLECTIONS SUBMENU AND NOT THE TOP LEVEL
-- -------------------------------------------------
-- This module used to insert a TOP-LEVEL row into ZO_MENU_ENTRIES
-- (zo_mainmenu_gamepad.lua:4). That is genuinely unsafe and has been retired:
--
--   RefreshMainList (:868-896) walks every entry through AddEntryToList
--   (:835-866) and only calls mainList:Commit() at :895, AFTER the loop.
--   OPTIONS and LOG_OUT are entries 14 and 15 of that same array
--   (ZO_MENU_MAIN_ENTRIES :6-23). A throw from an add-on row therefore aborts
--   the build BEFORE the commit, leaving a console player in a pause menu with
--   no way to log out.
--
-- The submenu has the same insert mechanics but a fundamentally better failure
-- mode. RefreshSubList (:898-909) runs only after the main list is already
-- committed, and the Collections submenu holds nothing safety-critical --
-- Collections, Item Sets, Tribute Patrons (:41-46, :222-259). If our row ever
-- threw, the player loses that submenu, not their ability to quit the game.
--
-- It is also where the feature belongs: the neighbouring Item Sets book is
-- exactly where a player browses sets and marks them wanted (see the sibling
-- file ui/PrioritiesSetsBook_Gamepad.lua, which adds that action).
--
-- Two absolute rules, both learned from BlindingFireBird/KelaPadUI, which gets
-- both wrong:
--   1. NEVER hard-code an insert index. The base enum gains entries between
--      patches, so that add-on's literal 14 now points somewhere else entirely.
--      We SEARCH for Collections by id and fail closed if it is gone.
--   2. NEVER renumber entry.id. entry.id is a LOOKUP KEY, not a position
--      (:861). Six base-game deep-links resolve through it
--      (achievements_gamepad.lua:551, lorelibrary_gamepad.lua:79/80,
--      zo_activityfinderroot_gamepad.lua:426/431, notifications_common.lua:2303,
--      timedactivities_manager.lua:665). We use a STRING id, which can never
--      collide with the numeric MENU_COLLECTIONS_ENTRIES values -- the same
--      trick LibHarvensAddonSettings uses on Xbox today
--      (LibHarvensAddonSettings/Console/Settings.lua:660-763), and the same
--      trick ACCOUNT_HOLD_LIST uses in ui/InventoryTab_Gamepad.lua:36.
--
-- WHY THE HARDENING IS STILL NOT OPTIONAL
-- ---------------------------------------
-- AddEntryToList dereferences entry.data unguarded (:836) and
-- UpdateEntryEnabledStates calls entry:SetEnabled on both the main list AND
-- every submenu (:730-737), so our row must be a real ZO_GamepadEntryData with
-- a real .data table or it throws. Every callback below is pcall-guarded with a
-- safe fallback, and the whole install fails CLOSED: if Collections cannot be
-- found, if the API is missing, if the scene cannot be registered, or if the
-- screen cannot build its list, we add NOTHING and log a diagnostic.
--
-- This add-on has already crashed the game once by taking ownership of a
-- base-UI surface (the Character-screen keybind collision, AccountHold/README.md
-- "Xbox / PS5 quick reference"). The difference here is that we claim no
-- keybind and mutate no existing entry -- we append one data row to an array the
-- base game re-reads anyway, which is the same architectural move that already
-- ships twice on console (the inventory tab and the bank tab).

AccountHold = AccountHold or {}
AccountHold.UI = AccountHold.UI or {}
AccountHold.UI.PrioritiesMenuGamepad = AccountHold.UI.PrioritiesMenuGamepad or {}

local Menu = AccountHold.UI.PrioritiesMenuGamepad

-- Strings come from AccountHold.L with an English fallback; feature agents must
-- not edit the shared localization/en.lua.
local function L(id, fallback)
    if AccountHold and type(AccountHold.L) == "function" then
        return AccountHold.L(id, fallback)
    end
    return fallback
end

-- String id: cannot collide with the numeric ZO_MENU_MAIN_ENTRIES values.
local ENTRY_ID   = "ACCOUNT_HOLD_PRIORITIES"
-- The Armory row shares this module's install path. A separate STRING id, so
-- the two rows are independently findable and independently removable.
local ARMORY_ENTRY_ID = "ACCOUNT_HOLD_ARMORY"
local SCENE_NAME = "accountHoldPrioritiesGamepad"

-- Test seams, mirroring Tab._Blade / Tab._records.
Menu._ENTRY_ID   = ENTRY_ID
Menu._ARMORY_ENTRY_ID = ARMORY_ENTRY_ID
Menu._SCENE_NAME = SCENE_NAME

-- ---------------------------------------------------------------------------
-- The pure placement functions
-- ---------------------------------------------------------------------------

-- Locate the Collections row's submenu array.
--
-- ZO_MENU_ENTRIES rows are ZO_GamepadEntryData objects built by CreateEntry
-- (zo_mainmenu_gamepad.lua:503-524); the build loop (:526-540) sets
-- newEntry.id from ipairs and newEntry.subMenu for any row that declares one
-- (:530-537). Collections is ZO_MENU_MAIN_ENTRIES.COLLECTIONS (:11) and does
-- declare one (:228-258).
--
-- Returns the live subMenu array, or nil when the anchor is absent or has no
-- submenu -- in which case the caller FAILS CLOSED. We never fabricate a
-- subMenu on a base entry that lacks one: SwitchToSelectedScene branches on
-- entryData.subMenu (:816) and inventing one would change how a base row
-- behaves.
--
-- Deliberately ZO-free so the mock harness can test the contract with no ZO_*
-- globals at all. Malformed neighbours (nil holes, non-tables, entries with no
-- id) are skipped rather than dereferenced, because ZO_MENU_ENTRIES is a shared
-- global that any other add-on may also have written to.
function Menu.FindSubMenu(entries, anchorId)
    if type(entries) ~= "table" then return nil end
    if anchorId == nil then return nil end
    for i = 1, #entries do
        local e = entries[i]
        if type(e) == "table" and e.id == anchorId then
            if type(e.subMenu) == "table" then return e.subMenu end
            return nil
        end
    end
    return nil
end

-- Where does our row go inside that submenu?
--
-- Returns (index, alreadyPresent):
--   * (n, false)   insert at n -- the end, after Tribute Patrons
--   * (nil, true)  our entry is already there; do nothing (idempotent)
--   * (nil, false) the array is unusable -- FAIL CLOSED.
--
-- Appending is correct here in a way it never was at the top level: the
-- submenu's last entry is Tribute Patrons, not LOG_OUT, so there is nothing we
-- must stay in front of. Idempotence is checked FIRST so a second install is a
-- no-op even after a partial failure.
function Menu.FindInsertIndex(subMenu, entryId)
    if type(subMenu) ~= "table" then return nil, false end
    if entryId == nil then return nil, false end
    for i = 1, #subMenu do
        local e = subMenu[i]
        if type(e) == "table" and e.id == entryId then
            return nil, true
        end
    end
    return #subMenu + 1, false
end

-- Open a gamepad dialog from a pause-menu entry.
--
-- THIS IS NOT OPTIONAL PLUMBING -- without it the dialog is silently DROPPED.
--
-- ZO_Dialogs_ShowGamepadDialog (zo_dialog.lua:352-378) only shows immediately
-- when SCENE_MANAGER:GetCurrentScene():IsShowing() is true (:356). When
-- activatedCallback fires, the pause menu is mid-transition: the scene exists
-- but is no longer "showing", and there is no next scene, so control falls to
-- :372-376 and the request is thrown away. That is exactly the
--   "[armory] Armory show request was dropped -- no scene was showing"
-- report, and the same reason the Priorities blade appeared to do nothing.
--
-- Fix: close the pause menu ourselves, then show the dialog once a scene has
-- actually settled. We prefer the same SceneStateChanged handshake the base
-- game uses for deferred dialogs (:364-371) and fall back to a short timer, so
-- a client without one still works.
local function showDialogFromMenu(showFn, addonRef)
    if type(showFn) ~= "function" then return end

    local function report(ok)
        if not ok and addonRef and addonRef.Diagnostic then
            addonRef:Diagnostic("warn",
                "[priorities] Dialog could not be shown after leaving the pause menu.")
        end
    end

    local fired = false
    local function fire()
        if fired then return end
        fired = true
        local ok = pcall(showFn)
        report(ok)
    end

    -- Close the pause menu first. Without this the dialog would open behind it.
    if SCENE_MANAGER ~= nil then
        if type(SCENE_MANAGER.RegisterCallback) == "function"
           and type(SCENE_MANAGER.UnregisterCallback) == "function" then
            local handler
            handler = function(_scene, _oldState, newState)
                if newState == SCENE_SHOWN then
                    pcall(function()
                        SCENE_MANAGER:UnregisterCallback("SceneStateChanged", handler)
                    end)
                    fire()
                end
            end
            pcall(function()
                SCENE_MANAGER:RegisterCallback("SceneStateChanged", handler)
            end)
        end
        if type(SCENE_MANAGER.ShowBaseScene) == "function" then
            pcall(function() SCENE_MANAGER:ShowBaseScene() end)
        end
    end

    -- Belt and braces: if no scene transition ever completes (or the callback
    -- API is absent) still show, rather than leaving the player with a button
    -- that does nothing.
    if type(zo_callLater) == "function" then
        pcall(function() zo_callLater(fire, 250) end)
    else
        fire()
    end
end

Menu._ShowDialogFromMenu = showDialogFromMenu

-- ---------------------------------------------------------------------------
-- Feature gate
-- ---------------------------------------------------------------------------

-- 0005's acceptance criteria: "The feature is invisible while available = false
-- or the account is not allowed by config/FeatureAccess.lua."
--
-- `available` is a SHIP-TIME property (src/Features.lua REGISTRY) that cannot
-- change without a reload, so it gates INSTALLATION -- while the epic is not
-- shipped we put nothing at all into ZO_MENU_ENTRIES, which is the strictly
-- lowest-risk posture. The per-account allow/deny state CAN change at runtime
-- from the settings panel, so it gates VISIBILITY through the entry's own
-- callback below.
--
-- When Features is absent entirely (mock harness, stripped build) we cannot
-- tell, so we do not block on it.
local function featureAvailable()
    local f = AccountHold and AccountHold.Features
    if type(f) ~= "table" or type(f.REGISTRY) ~= "table" then return true end
    local reg = f.REGISTRY.priorities
    if type(reg) ~= "table" then return true end
    return reg.available ~= false
end

local function featureEnabled()
    local f = AccountHold and AccountHold.Features
    if type(f) ~= "table" or type(f.IsEnabled) ~= "function" then return true end
    return f:IsEnabled("priorities") and true or false
end

-- ---------------------------------------------------------------------------
-- Install
-- ---------------------------------------------------------------------------

function Menu:Initialize(addonRef)
    self.addon = addonRef

    local function warn(fmt, ...)
        if addonRef and addonRef.Diagnostic then
            addonRef:Diagnostic("warn", "[priorities] " .. fmt, ...)
        end
    end
    local function info(fmt, ...)
        if addonRef and addonRef.Diagnostic then
            addonRef:Diagnostic("info", "[priorities] " .. fmt, ...)
        end
    end

    -- Guard 0: the epic is gated. Nothing is inserted while it is unavailable.
    if not featureAvailable() then
        info("Feature 'priorities' is not available - pause-menu entry NOT added.")
        return
    end

    -- Guard 1: is the gamepad main menu API present at all? (Keyboard-only
    -- builds, the mock harness, or a future refactor must degrade to "no
    -- entry", never error.)
    --
    -- Note SCENE_MANAGER is NOT required any more: this entry no longer opens a
    -- custom scene. See the entryData comment below.
    if type(ZO_MENU_ENTRIES) ~= "table"
       or type(ZO_MENU_MAIN_ENTRIES) ~= "table"
       or ZO_MENU_MAIN_ENTRIES.COLLECTIONS == nil
       or type(ZO_GamepadEntryData) ~= "table" then
        warn("Gamepad main-menu API unavailable - Priorities entry NOT added.")
        return
    end

    -- Guard 2: find the Collections submenu. Failing closed here is the whole
    -- reason this is safer than the old top-level insert: if the base layout
    -- ever changes we simply add nothing.
    local subMenu = Menu.FindSubMenu(ZO_MENU_ENTRIES, ZO_MENU_MAIN_ENTRIES.COLLECTIONS)
    if not subMenu then
        warn("Collections submenu not found in ZO_MENU_ENTRIES - Priorities entry NOT added. "
             .. "(Base menu layout changed; refusing to guess a position.)")
        return
    end

    -- Guard 3: idempotence. Ask BEFORE building anything, so a second
    -- Initialize (or an add-on that reloads us) cannot leave a second row.
    local index, alreadyPresent = Menu.FindInsertIndex(subMenu, ENTRY_ID)
    if alreadyPresent then
        info("Entry already present; skipping.")
        self._installed = true
        return
    end
    if not index then
        warn("Collections submenu unusable - Priorities entry NOT added.")
        return
    end

    -- The entry data table. Consumed by ShouldDisableEntry (:698-715),
    -- AddEntryToList (:835-866) and SwitchToSelectedScene (:805-826).
    --
    -- WHY THERE IS NO `scene` FIELD ANY MORE
    -- --------------------------------------
    -- This entry used to carry scene = SCENE_NAME, and the install was gated on
    -- that custom scene registering AND the Priorities screen building a
    -- ZO_GamepadVerticalItemParametricScrollList from CreateControlFromVirtual.
    -- That build failed repeatedly on real Xbox hardware, and because it was a
    -- PRECONDITION the whole menu entry silently never appeared.
    --
    -- SwitchToSelectedScene has a third branch: `activatedCallback` (:819-820),
    -- taken when there is no scene and no subMenu. We use it, which removes the
    -- custom top-level window, the scene registration and the runtime list
    -- build from the critical path entirely. The callback opens a parametric
    -- DIALOG instead — the same mechanism as the Item Sets "Add to Priorities"
    -- action, which worked first time on the same hardware.
    --
    -- Net effect: the entry now installs whenever the pause menu itself exists.
    local entryData = {
        name  = (function()
            -- Resolved ONCE, here, rather than as a callback: a name callback is
            -- one more thing RefreshMainList can trip over, and this label never
            -- changes at runtime.
            local ok, s = pcall(L, "SI_ACCOUNTHOLD_PRIORITIES_MENU", "Quartermaster Priorities")
            if ok and type(s) == "string" and s ~= "" then return s end
            return "Quartermaster Priorities"   -- never let a missing SI_ blank the row
        end)(),
        icon  = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_journal.dds",

        -- SwitchToSelectedScene (zo_mainmenu_gamepad.lua:1010-1011). Must never
        -- throw: it runs inside the pause menu's own input handler.
        --
        -- PRI-11: first choice is the native host screen (ui/
        -- PrioritiesScreen_Gamepad.lua, Screen:OpenFromMenu). It is PUSHED on
        -- top of the Collections submenu exactly as the native rows' `scene`
        -- is (:999-1001), so the screen gets the sibling Collections screens'
        -- backdrop and B returns to this submenu. If it cannot be built or the
        -- push does not take, fall back to the proven dialog-over-the-world
        -- path below, unchanged.
        activatedCallback = function()
            pcall(function()
                local screen = AccountHold and AccountHold.UI
                              and AccountHold.UI.PrioritiesScreenGamepad
                if type(screen) ~= "table" then return end
                if type(screen.OpenFromMenu) == "function" then
                    local okOpen, opened = pcall(screen.OpenFromMenu, screen)
                    if okOpen and opened then return end
                end
                if type(screen.Show) == "function" then
                    showDialogFromMenu(function() screen:Show() end, AccountHold)
                end
            end)
        end,

        -- Feature gate. MUST NOT THROW: AddEntryToList calls this while building
        -- the Collections submenu.
        isVisibleCallback = function()
            local ok, visible = pcall(featureEnabled)
            return (ok and visible) and true or false   -- fail CLOSED: hide
        end,
    }

    -- Build the entry exactly the way CreateEntry does (:503-524) so it is
    -- indistinguishable from a native row to AddEntryToList (:835-866).
    local okEntry, entry = pcall(function()
        local e = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
        if e.SetIconTintOnSelection then e:SetIconTintOnSelection(true) end
        if e.SetIconDisabledTintOnSelection then e:SetIconDisabledTintOnSelection(true) end
        e.data = entryData
        e.id   = ENTRY_ID                          -- string: collision-proof
        return e
    end)
    if not okEntry or not entry then
        warn("Failed to build gamepad entry data - Priorities entry NOT added.")
        return
    end

    -- The insert itself. Note we do NOT touch any other entry's .id, and we
    -- append rather than splice, so Collections / Item Sets / Tribute Patrons
    -- all keep their positions.
    local okInsert = pcall(function()
        table.insert(subMenu, index, entry)
    end)
    if not okInsert then
        warn("table.insert into the Collections submenu failed - Priorities entry NOT added.")
        return
    end
    self._entry = entry

    -- The Armory shares this install path deliberately: every guard, the
    -- string-id collision rule and the append-only discipline are already
    -- proven here, and duplicating them in a second module would be two places
    -- to get the pause menu wrong.
    self:_InstallArmoryEntry(subMenu, warn, info)

    -- Refresh only if the menu already exists AND is currently showing. When it
    -- is not showing, OnShowing -> RefreshLists (:601-612) will pick us up
    -- anyway, so an unnecessary early RefreshMainList is pure added risk.
    pcall(function()
        if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.IsShowing
           and MAIN_MENU_GAMEPAD:IsShowing() and MAIN_MENU_GAMEPAD.RefreshLists then
            MAIN_MENU_GAMEPAD:RefreshLists()
        end
    end)

    info("Priorities entry appended to the Collections submenu at index %d.", index)
    self._installed = true
end

-- Second Collections row: the Quartermaster Armory (epic 0002).
--
-- Registering the Armory's dialog is NOT the same as making it reachable --
-- ui/ArmoryScreen_Gamepad.lua exposes Show() but nothing called it, so the
-- feature was fully built and completely invisible. This is the entry point.
--
-- Gated independently of Priorities: the two features have separate allowlists,
-- so one being off must never suppress the other.
function Menu:_InstallArmoryEntry(subMenu, warn, info)
    local armoryId = ARMORY_ENTRY_ID

    local index, present = Menu.FindInsertIndex(subMenu, armoryId)
    if present then
        info("Armory entry already present; skipping.")
        return
    end
    if not index then return end

    local function armoryEnabled()
        local f = AccountHold and AccountHold.Features
        if type(f) ~= "table" or type(f.IsEnabled) ~= "function" then return true end
        local ok, v = pcall(f.IsEnabled, f, "buildCreator")
        return (ok and v) and true or false
    end

    -- Ship-time gate: install nothing at all while the epic is unavailable.
    local reg = AccountHold and AccountHold.Features and AccountHold.Features.REGISTRY
    if type(reg) == "table" and type(reg.buildCreator) == "table"
       and reg.buildCreator.available == false then
        info("Feature 'buildCreator' unavailable - Armory entry NOT added.")
        return
    end

    local entryData = {
        name = (function()
            local ok, s = pcall(L, "SI_ACCOUNTHOLD_ARMORY_MENU", "Quartermaster Armory")
            if ok and type(s) == "string" and s ~= "" then return s end
            return "Quartermaster Armory"
        end)(),
        icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds",

        -- No `scene`: same reasoning as the Priorities row. The Armory is a
        -- parametric dialog, reached through SwitchToSelectedScene's
        -- activatedCallback branch (zo_mainmenu_gamepad.lua:819-820).
        activatedCallback = function()
            pcall(function()
                local armory = AccountHold and AccountHold.UI and AccountHold.UI.ArmoryGamepad
                if type(armory) == "table" and type(armory.Show) == "function" then
                    showDialogFromMenu(function() armory:Show() end, AccountHold)
                end
            end)
        end,

        isVisibleCallback = function()
            local ok, visible = pcall(armoryEnabled)
            return (ok and visible) and true or false
        end,
    }

    local okEntry, entry = pcall(function()
        local e = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
        if e.SetIconTintOnSelection then e:SetIconTintOnSelection(true) end
        if e.SetIconDisabledTintOnSelection then e:SetIconDisabledTintOnSelection(true) end
        e.data = entryData
        e.id   = armoryId
        return e
    end)
    if not okEntry or not entry then
        warn("Failed to build Armory entry data - Armory entry NOT added.")
        return
    end

    if not pcall(function() table.insert(subMenu, index, entry) end) then
        warn("table.insert into the Collections submenu failed - Armory entry NOT added.")
        return
    end
    self._armoryEntry = entry
    info("Armory entry appended to the Collections submenu at index %d.", index)
end

-- Retry once the player is in the world.
--
-- Initialize runs on EVENT_ADD_ON_LOADED, which is the earliest possible moment
-- and NOT a guarantee that the gamepad main menu, SCENE_MANAGER or GuiRoot are
-- fully stood up. Every guard in Initialize fails closed, so an early attempt
-- simply adds nothing -- and without a retry that would be permanent for the
-- whole session, which is exactly the "I don't see the menu" failure.
--
-- Safe to call repeatedly: Initialize's Guard 2 checks for our entry BEFORE
-- building anything, so a second pass after a successful install is a no-op.
function Menu:ScheduleRetry(addonRef)
    if EVENT_MANAGER == nil or type(EVENT_MANAGER.RegisterForEvent) ~= "function" then
        return
    end
    if not EVENT_PLAYER_ACTIVATED then return end
    local name = ((addonRef and addonRef.name) or "AccountHold") .. "_PrioritiesMenuRetry"
    pcall(function()
        EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
            if Menu._installed then
                -- Nothing more to do; stop paying for the callback.
                pcall(function() EVENT_MANAGER:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED) end)
                return
            end
            pcall(function() Menu:Initialize(addonRef) end)
        end)
    end)
end

-- Teardown, mirroring BankTab_Gamepad's restore discipline: remove OUR entry by
-- identity only, never by index, and never disturb neighbours. Also sweeps the
-- root array so a client that still carries the retired top-level row from an
-- earlier build gets it cleaned up rather than ending up with two.
function Menu:Teardown()
    if type(ZO_MENU_ENTRIES) ~= "table" then return end
    pcall(function()
        local function sweep(list)
            if type(list) ~= "table" then return end
            for i = #list, 1, -1 do
                local e = list[i]
                if type(e) == "table"
                   and (e.id == ENTRY_ID or e.id == ARMORY_ENTRY_ID) then
                    table.remove(list, i)
                end
            end
        end
        sweep(ZO_MENU_ENTRIES)
        for i = 1, #ZO_MENU_ENTRIES do
            local e = ZO_MENU_ENTRIES[i]
            if type(e) == "table" then sweep(e.subMenu) end
        end
        if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.IsShowing
           and MAIN_MENU_GAMEPAD:IsShowing() and MAIN_MENU_GAMEPAD.RefreshLists then
            MAIN_MENU_GAMEPAD:RefreshLists()
        end
    end)
    self._entry = nil
    self._installed = nil
end

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------

-- Minimum viable gamepad scene. The fragment set mirrors
-- LibHarvensAddonSettings/Console/Settings.lua:772-779, which is shipping on
-- Xbox today.
--
-- Returns true only when the scene exists AND the Priorities screen accepted
-- the control (i.e. it built a real parametric list). Returning false is what
-- makes Initialize fail closed rather than install a row that opens a blank
-- scene the player then has to back out of.
function Menu:_EnsureScene()
    if SCENE_MANAGER == nil or type(SCENE_MANAGER.GetScene) ~= "function" then
        return false
    end
    if self._sceneReady and SCENE_MANAGER:GetScene(SCENE_NAME) then return true end

    -- ZO_Scene is a Lua CLASS table, so type()=="table" is correct for it.
    -- WINDOW_MANAGER is NOT: globalvars.lua:2 assigns GetWindowManager(), a C++
    -- engine object, i.e. USERDATA. The original guard here was
    --     type(WINDOW_MANAGER) ~= "table"
    -- which was TRUE on every real session, so this function returned false on
    -- its first line -- before ZO_Scene, before CreateTopLevelWindow, before
    -- the list. Three "failed scene attempts" never executed a line of scene
    -- code. Guard on presence, and on the METHOD actually needed.
    if WINDOW_MANAGER == nil
       or type(WINDOW_MANAGER.CreateTopLevelWindow) ~= "function"
       or type(ZO_Scene) ~= "table" then
        return false
    end

    local control = self._control
    if not control then
        control = WINDOW_MANAGER:CreateTopLevelWindow("AccountHoldPrioritiesGamepadTLW")
        control:SetAnchorFill(GuiRoot)
        control:SetHidden(true)
        self._control = control
    end

    -- Hand the control to the screen FIRST. If it cannot build its list there
    -- is no point registering a scene, and definitely no point advertising it
    -- in the pause menu.
    local screen = AccountHold and AccountHold.UI and AccountHold.UI.PrioritiesScreenGamepad
    if type(screen) ~= "table" or type(screen.AttachTo) ~= "function" then
        return false
    end

    local scene = SCENE_MANAGER:GetScene(SCENE_NAME)
    if not scene then
        scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
        -- Fragment groups/fragments are added defensively one at a time: a
        -- missing global on some future client must cost us that one fragment,
        -- not the whole scene.
        local function addGroup(group)
            if group ~= nil and scene.AddFragmentGroup then
                pcall(function() scene:AddFragmentGroup(group) end)
            end
        end
        local function addFragment(fragment)
            if fragment ~= nil and scene.AddFragment then
                pcall(function() scene:AddFragment(fragment) end)
            end
        end
        if type(FRAGMENT_GROUP) == "table" then
            addGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
            addGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
        end
        addFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        addFragment(MINIMIZE_CHAT_FRAGMENT)
        addFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
        if type(ZO_FadeSceneFragment) == "table" then
            local okFade, fade = pcall(function() return ZO_FadeSceneFragment:New(control) end)
            if okFade then addFragment(fade) end
        end
    end
    self._scene = scene

    local okAttach, attached = pcall(screen.AttachTo, screen, control, scene)
    if not okAttach or not attached then
        -- Leave the scene registered (SCENE_MANAGER has no public unregister)
        -- but report failure so no menu entry ever points at it.
        return false
    end

    -- Only from here on may Initialize proceed; the flag also short-circuits a
    -- second Initialize so the screen never registers two scene callbacks.
    self._sceneReady = true
    return true
end
