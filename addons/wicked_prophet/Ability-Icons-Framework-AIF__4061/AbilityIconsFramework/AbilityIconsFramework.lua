-- =============================================================================
-- Ability Icons Framework (AIF) - Core Engine Lifecycle & Bar Synchronization
-- =============================================================================
-- Coordinates high-resolution texture redirection, dynamic Scribing Grimoire
-- icon resolution, third-party action bar synchronizations (FancyActionBar / FAB+),
-- and critical visual sanity fixes (such as taming the monstrous vAS tip icon).
--
-- Think of this file as the central air traffic controller: it makes sure that
-- whether you just logged in, ported to a trial, or finished scribing a spicy new
-- Grimoire at the Scholarium altar, your action bars actually show the right art.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}

local AbilityIconsFramework = AbilityIconsFramework

-- Cached engine globals for quick access and cleaner call sites
local GetActiveHotbarCategory = GetActiveHotbarCategory
local ZO_ActionBar_GetButton  = ZO_ActionBar_GetButton
local zo_callLater            = zo_callLater

--------------------------------------------------------------------------------
-- Declarations & Versioning
--------------------------------------------------------------------------------

local ADDON_VERSION = "2.0.1"

AbilityIconsFramework.version = ADDON_VERSION
AbilityIconsFramework.name    = "AbilityIconsFramework"

--------------------------------------------------------------------------------
-- Visual Bug Fixes & Engine Workarounds
--------------------------------------------------------------------------------

--- Tames an infamous ESO visual bug in Veteran Asylum Sanctorium (vAS).
--- Without dimension constraints, the combat tip warning icon can expand to
--- truly elephantine proportions, blotting out Saint Olms, your group, and
--- any hope of seeing incoming boss mechanics.
--- Clamping it firmly to 64x64 ensures it remains a helpful tip rather than
--- an accidental full-screen flashbang.
function AbilityIconsFramework.ApplyFixVas()
    if ZO_ActiveCombatTipsTipIcon then
        ZO_ActiveCombatTipsTipIcon:SetDimensionConstraints(64, 64, 64, 64)
    end
end

--------------------------------------------------------------------------------
-- Master Initialization Sequence
--------------------------------------------------------------------------------

--- Master initialization sequence for the framework.
--- Order of operations here is paramount:
---   1. Tame the vAS combat tip before it consumes your screen.
---   2. Reconcile user-defined icon pack priority orders.
---   3. Compile the comprehensive replacement dictionary (Base + Packs + Scribing).
---   4. Apply delta-checked redirects for base-game mismatched abilities.
---   5. Inspect slotted Grimoires and redirect textures to match their active Focus Scripts.
---   6. Hook Heroism Potion visual overrides and metadata filters.
---   7. Force a synchronous action bar repaint (unless deferred to post-activation).
---
--- @param skipSlotUpdate boolean? If true, defers immediate bar repaints to the caller.
function AbilityIconsFramework.Initialize(skipSlotUpdate)
    AbilityIconsFramework.ApplyFixVas()
    AbilityIconsFramework.InitializeSortOrderEntries()
    AbilityIconsFramework.GenerateReplacementLists()
    AbilityIconsFramework.ReplaceMismatchedIcons()
    AbilityIconsFramework.UpdateDefaultScribingIcons()

    if AbilityIconsFramework.InitializeHeroismPotions then
        AbilityIconsFramework.InitializeHeroismPotions()
    end

    if not skipSlotUpdate then
        if AbilityIconsFramework.RefreshInventoryHeroismPotions then
            AbilityIconsFramework.RefreshInventoryHeroismPotions()
        end
        AbilityIconsFramework.UpdateAllSlots()
    end
    AbilityIconsFramework.isInitialized = true
end

--------------------------------------------------------------------------------
-- Action Bar Slot Updating & Third-Party Compatibility
--------------------------------------------------------------------------------

--- Signals ESO's native ActionButton controller to repaint a given slot.
--- If the slot controller exists and has a HandleSlotChanged method, we invoke
--- it with the specified hotbar category to force the engine to re-query the icon.
--- @param actionSlotIndex number The action bar slot index (3-8 for skills, 9 for quickslot).
--- @param hotbarCategory number The hotbar category (HOTBAR_CATEGORY_PRIMARY or BACKUP).
function AbilityIconsFramework.HandleSlotChanged(actionSlotIndex, hotbarCategory)
    local btn = ZO_ActionBar_GetButton(actionSlotIndex, hotbarCategory)
    if btn and btn.HandleSlotChanged then
        btn:HandleSlotChanged(hotbarCategory)
    end
end

--- Comprehensive action bar refresh routine.
--- Synchronizes icons across:
---   1. Vanilla UI active and inactive hotbars (slots 3-8).
---   2. The player's assigned Quickslot button (slot 9).
---   3. Inactive/backbar physical buttons in FancyActionBar and FancyActionBar+.
--- Poking both primary and backup bars ensures that bar-swapping doesn't reveal
--- un-redirected low-res textures waiting in ambush on your backbar.
function AbilityIconsFramework.UpdateAllSlots()
    local activeHotbarCategory = GetActiveHotbarCategory()
    local inactiveHotbarCategory = activeHotbarCategory == HOTBAR_CATEGORY_BACKUP and HOTBAR_CATEGORY_PRIMARY or
    HOTBAR_CATEGORY_BACKUP

    -- 1. Base Game Action Bars (Vanilla UI & active bar of FancyActionBar / FancyActionBar+)
    for slotIndex = AbilityIconsFramework.MIN_INDEX, AbilityIconsFramework.MAX_INDEX do
        AbilityIconsFramework.HandleSlotChanged(slotIndex, activeHotbarCategory)
        AbilityIconsFramework.HandleSlotChanged(slotIndex, inactiveHotbarCategory)
    end

    -- Quickslot button (slot 9)
    AbilityIconsFramework.HandleSlotChanged(9, activeHotbarCategory)
    AbilityIconsFramework.HandleSlotChanged(9, inactiveHotbarCategory)

    -- 2. FancyActionBar+ & FancyActionBar inactive/backbar buttons compatibility
    -- Backbar buttons in FAB/FAB+ use offset physical indices (23-28) rather than
    -- standard action slots, requiring specialized texture injection via our bridge.
    if FancyActionBar and AbilityIconsFramework.UpdateInactiveBarButtonFAB then
        for slotIndex = AbilityIconsFramework.MIN_INDEX, AbilityIconsFramework.MAX_INDEX do
            AbilityIconsFramework.UpdateInactiveBarButtonFAB(slotIndex, inactiveHotbarCategory)
        end
    end
end

--------------------------------------------------------------------------------
-- Event Handlers & Lifecycle Registration
--------------------------------------------------------------------------------

--- Addon startup handler triggered when our manifest loads.
--- Registers settings, chat commands, and event listeners.
--- @param eventCode number Event ID.
--- @param addOnName string Name of the addon currently being loaded.
function AbilityIconsFramework.OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= AbilityIconsFramework.name then return end

    EVENT_MANAGER:UnregisterForEvent(AbilityIconsFramework.name, EVENT_ADD_ON_LOADED)

    AbilityIconsFramework.InitializeSettings()
    AbilityIconsFramework.CreateSlashCommands()

    -- Re-apply scribed icons whenever you finish crafting a new Grimoire at the Scribing altar.
    -- ESO fires "CraftingAnimationsStopped" once the altar craft sequence completes.
    CALLBACK_MANAGER:RegisterCallback("CraftingAnimationsStopped", AbilityIconsFramework.OnScribingUpdate)

    -- Defer primary initialization until PLAYER_ACTIVATED.
    -- At this point, all external icon pack addons, SavedVariables, skills data managers,
    -- and UI controllers are fully initialized and ready for redirection.
    EVENT_MANAGER:RegisterForEvent(AbilityIconsFramework.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            EVENT_MANAGER:UnregisterForEvent(AbilityIconsFramework.name .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED)
            -- Pass true to skip redundant immediate repaint; the deferred call below handles it cleanly
            AbilityIconsFramework.Initialize(true)

            -- Deferred update: gives third-party action bar addons (like FancyActionBar+)
            -- and inventory managers a brief moment to finish their own initial layouts
            -- so our texture overrides aren't immediately clobbered by their startup logic.
            zo_callLater(AbilityIconsFramework.UpdateAllSlots, 100)
            if AbilityIconsFramework.RefreshInventoryHeroismPotions then
                zo_callLater(AbilityIconsFramework.RefreshInventoryHeroismPotions, 200)
            end
        end)
end

--------------------------------------------------------------------------------
-- Engine Hook
--------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(AbilityIconsFramework.name, EVENT_ADD_ON_LOADED, AbilityIconsFramework.OnAddOnLoaded)
