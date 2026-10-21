-- =============================================================================
-- Ability Icons Framework (AIF) - Core Utilities & Engine Redirection Helpers
-- =============================================================================
-- This module houses the heavy-lifting utility functions that bridge the gap
-- between ESO's action bar system and our texture replacement engine.
--
-- Key Responsibilities:
-- 1. Skill ID Resolution: Traversing ESO's SkillsDataManager hierarchy from
--    any evolved skill morph back to its primordial root (MORPH_SLOT_BASE),
--    or resolving crafted Scribing abilities to their base Grimoire ID.
-- 2. Low-Overhead Texture Redirection: Delta-checking every texture swap
--    against an internal cache (`activeRedirects`) to ensure we only invoke the
--    underlying C++ `RedirectTexture()` engine API when a target path genuinely changes.
-- 3. The Sacred Stagger Stomp Protection: Shielding Dragonknight's Stomp texture
--    from being clobbered by overzealous pack replacements.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

-- -----------------------------------------------------------------------------
-- Localized API Cache: Faster lookups, less garbage collection
-- -----------------------------------------------------------------------------
local pairs                           = pairs
local tonumber                        = tonumber
local GetSlotBoundId                  = GetSlotBoundId
local GetSlotType                     = GetSlotType
local GetAbilityIdForCraftedAbilityId = GetAbilityIdForCraftedAbilityId
local RedirectTexture                 = RedirectTexture

-- -----------------------------------------------------------------------------
-- The Sacred Dragonknight Stagger Stomp Exemption
-- -----------------------------------------------------------------------------
-- Dragonknight's Stonefist / Obsidian Shard / Staggering Claw morph sequence
-- contains a notorious internal quirk: the stomp sub-phase icon
-- (`ability_dragonknight_013_a_stomp.dds`) shares base asset pointers in ways
-- that cause bizarre visual artifacts or unwanted texture bleed if modified.
-- We fiercely guard this specific icon behind a VIP velvet rope—no matter what
-- icon pack or setting tries to touch it, it is perpetually forced back onto its
-- vanilla path.
local STAGGER_STOMP_BASE_ICON = "/esoui/art/icons/ability_dragonknight_013_a_stomp.dds"

-- -----------------------------------------------------------------------------
-- Action Bar Slot & Ability ID Inspection Helpers
-- -----------------------------------------------------------------------------

--- Retrieves the root/base ability ID of a skill (its unmorphed Rank I version).
---
--- In ESO, every skill morph possesses its own distinct integer ID (e.g., morph 1,
--- morph 2, and the base morph are completely different numbers in ZOS's database).
--- However, third-party icon packs and replacement tables almost universally register
--- their high-res textures against the unmorphed base ability.
---
--- If a player morphs Cleave into Brawler, `GetAbilityId` returns Brawler's ID.
--- This function traverses ESO's `SKILLS_DATA_MANAGER` progression tree backwards
--- to extract the underlying `MORPH_SLOT_BASE` ID so our lookup tables always match.
---
--- For Scribing (Gold Road), crafted abilities use `ACTION_TYPE_CRAFTED_ABILITY`,
--- which requires delegating to `GetAbilityIdForCraftedAbilityId` to retrieve the
--- base Grimoire ability ID.
---
--- @param slotIndex number The action bar slot index (3-8).
--- @param hotbarCategory number The active hotbar category (Primary, Backup, etc.).
--- @return number? baseAbilityId The root unmorphed ability ID, or nil if the slot is empty.
function AbilityIconsFramework.GetBaseAbilityId(slotIndex, hotbarCategory)
    local abilityId = AbilityIconsFramework.GetAbilityId(slotIndex, hotbarCategory)
    if not abilityId then return nil end

    local actionType = GetSlotType(slotIndex, hotbarCategory)
    if actionType == ACTION_TYPE_CRAFTED_ABILITY then
        return GetAbilityIdForCraftedAbilityId(abilityId)
    end

    local progressionData = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
    if not progressionData then return abilityId end

    local skillData = progressionData:GetSkillData()
    if not skillData.GetMorphData then return abilityId end

    local baseMorphData = skillData:GetMorphData(MORPH_SLOT_BASE)
    return baseMorphData and baseMorphData:GetAbilityId() or abilityId
end

--- Retrieves the raw ability ID bound to an action bar slot.
---
--- Guards against invalid slot indices: in ESO, slots 1 and 2 are engine-reserved
--- for Light and Heavy attacks. Standard player-slotted skills only occupy slots 3
--- through 8 (slot 8 being the Ultimate).
---
--- @param slotIndex number The slot index (3-8).
--- @param hotbarCategory number The hotbar category (Primary, Backup, etc.).
--- @return number? abilityId The bound ability ID, or nil if out-of-bounds/empty.
function AbilityIconsFramework.GetAbilityId(slotIndex, hotbarCategory)
    local index = tonumber(slotIndex) or 0
    if index < AbilityIconsFramework.MIN_INDEX or index > AbilityIconsFramework.MAX_INDEX then
        return nil
    end

    return GetSlotBoundId(slotIndex, hotbarCategory)
end

-- -----------------------------------------------------------------------------
-- Texture Redirection Pipeline
-- -----------------------------------------------------------------------------

-- Tracks currently active redirection targets to prevent redundant C++ engine calls.
-- Crossing the Lua-to-C++ boundary in ESO's graphics engine via `RedirectTexture`
-- is surprisingly heavy when spammed across hundreds of textures per frame.
-- This dictionary acts as our cache layer so we only issue draw calls on real deltas.
AbilityIconsFramework.activeRedirects = AbilityIconsFramework.activeRedirects or {}
local activeRedirects = AbilityIconsFramework.activeRedirects

--- Centralized texture redirection helper.
---
--- Enforces cache delta-checking: if `oldTexture` is already redirected to `newTexture`,
--- this function early-exits in $O(1)$ time without disturbing ESO's C++ graphics pipeline.
--- Also guarantees the legendary Stagger Stomp always stays safely on its vanilla track.
---
--- @param oldTexture string The base game texture path to redirect (e.g. "/esoui/art/icons/...").
--- @param newTexture string The destination replacement texture path.
function AbilityIconsFramework.RedirectTexture(oldTexture, newTexture)
    if not oldTexture then return end
    if oldTexture == STAGGER_STOMP_BASE_ICON then
        newTexture = STAGGER_STOMP_BASE_ICON
    end
    if activeRedirects[oldTexture] ~= newTexture then
        RedirectTexture(oldTexture, newTexture)
        activeRedirects[oldTexture] = newTexture
    end
end

--- Iterates through configured base-game texture replacements and swaps
--- outdated low-resolution 2014 textures for crisp, high-definition replacements.
---
--- Skips custom Scribing icons (which are dynamically governed by Focus Scripts in Scribing.lua).
--- Employs our delta-checked `RedirectTexture()` so toggling settings or switching zones
--- only touches textures that actually changed.
function AbilityIconsFramework.ReplaceMismatchedIcons()
    local doReplace = AbilityIconsFramework.GetSettings().replaceMismatchedBaseIcons

    for key, value in pairs(AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE) do
        -- Skip scribing icons here (handled separately).
        if AbilityIconsFramework.CUSTOM_ABILITY_ICONS[key] == nil then
            local target = doReplace and value or key
            AbilityIconsFramework.RedirectTexture(key, target)
        end
    end

    -- Safety: always guarantee Stagger Stomp stays on its vanilla track
    AbilityIconsFramework.RedirectTexture(STAGGER_STOMP_BASE_ICON, STAGGER_STOMP_BASE_ICON)
end

--- Resets all redirected textures back to vanilla defaults.
--- Called when clearing or disabling active icon packs to clean up the UI
--- without leaving phantom textures lingering in ESO's graphics memory.
function AbilityIconsFramework.ResetAllTextureRedirects()
    for key, _ in pairs(AbilityIconsFramework.BASE_GAME_ICONS_TO_REPLACE) do
        AbilityIconsFramework.RedirectTexture(key, key)
    end

    -- Extra safety
    AbilityIconsFramework.RedirectTexture(STAGGER_STOMP_BASE_ICON, STAGGER_STOMP_BASE_ICON)
end
