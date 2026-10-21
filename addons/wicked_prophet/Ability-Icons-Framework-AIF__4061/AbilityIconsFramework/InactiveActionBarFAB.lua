-- =============================================================================
-- Ability Icons Framework (AIF) - Inactive Action Bar Compatibility (FAB / FAB+)
-- =============================================================================
-- Bridges icon replacements into FancyActionBar and FancyActionBar+ backbars.
-- Because players who keep track of their backbar buffs and dots deserve to see
-- their gorgeous custom HD icons too, rather than blurry vanilla textures.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

local tonumber       = tonumber
local GetSlotBoundId = GetSlotBoundId
local GetAbilityIcon = GetAbilityIcon

--------------------------------------------------------------------------------
-- Button Resolver
--------------------------------------------------------------------------------

--- Retrieves the inactive action bar button corresponding to a given slot index,
--- providing seamless compatibility with both FancyActionBar+ and classic FancyActionBar.
---
--- Physical Index Mapping:
---   Both FAB and FAB+ allocate physical button controls 23-28 to represent the
---   inactive backbar (standard ability slots 3-8 shifted by SLOT_INDEX_OFFSET = 20).
---
--- @param slotIndex number The logical slot index (3-8) or backbar physical index (23-28).
--- @return any? btn The inactive bar button control, or nil if FancyActionBar is absent.
function AbilityIconsFramework.GetInactiveBarButtonFAB(slotIndex)
    if not FancyActionBar then return nil end

    local physicalIndex = type(slotIndex) == "number" and slotIndex or (tonumber(slotIndex) or 0)
    if physicalIndex >= AbilityIconsFramework.MIN_INDEX and physicalIndex <= AbilityIconsFramework.MAX_INDEX then
        physicalIndex = physicalIndex + AbilityIconsFramework.SLOT_INDEX_OFFSET
    end

    -- FancyActionBar+ exposes GetActionButton(physicalIndex)
    if FancyActionBar.GetActionButton then
        return FancyActionBar.GetActionButton(physicalIndex)
    -- Classic FancyActionBar stores backbar button controls in FancyActionBar.buttons
    elseif FancyActionBar.buttons then
        return FancyActionBar.buttons[physicalIndex]
    end

    return nil
end

--------------------------------------------------------------------------------
-- Texture & State Injection
--------------------------------------------------------------------------------

--- Updates the texture and visibility state of an inactive/backbar action button.
---
--- CRITICAL ENGINE QUIRK:
---   Do NOT call btn:HandleSlotChanged() on backbar buttons!
---   Because backbar buttons use physical indices outside the standard range (23-28),
---   passing these indices to ESO's native ActionButton:HandleSlotChanged() causes the
---   engine to evaluate GetSlotType(23) as ACTION_TYPE_NOTHING. The native controller
---   then helpfully runs self:Clear(), unsets the texture, and hides the button.
---
---   To avoid this, we bypass ESO's native slot handler entirely:
---     1. Ask FAB/FAB+ for the true bound ability ID on the inactive hotbar category.
---     2. Fetch the redirected icon path from GetAbilityIcon().
---     3. Directly inject the texture into btn.icon:SetTexture(icon).
---
--- @param slotIndex number The ability slot index (3-8).
--- @param inactiveHotbarCategory number The inactive hotbar category (Primary or Backup).
function AbilityIconsFramework.UpdateInactiveBarButtonFAB(slotIndex, inactiveHotbarCategory)
    local btn = AbilityIconsFramework.GetInactiveBarButtonFAB(slotIndex)
    if not btn then return end

    -- NOTE: Never call btn:HandleSlotChanged() on backbar buttons!
    -- Backbar buttons in FancyActionBar/FancyActionBar+ use physical indices (23-28).
    -- Calling ESO's ActionButton:HandleSlotChanged() on slot > 8 causes ESO's engine
    -- to evaluate GetSlotType() as ACTION_TYPE_NOTHING and run self:Clear(), wiping
    -- the button texture and setting it hidden. We manually set the texture instead.
    if btn.icon and btn.icon.SetTexture then
        local boundId = nil
        if FancyActionBar.GetSlotTrueBoundId then
            boundId = FancyActionBar.GetSlotTrueBoundId(slotIndex, inactiveHotbarCategory)
        elseif FancyActionBar.GetSlotBoundAbilityId then
            boundId = FancyActionBar.GetSlotBoundAbilityId(slotIndex, inactiveHotbarCategory)
        else
            boundId = GetSlotBoundId(slotIndex, inactiveHotbarCategory)
        end
        if boundId and boundId > 0 then
            local icon = GetAbilityIcon(boundId)
            if icon and icon ~= "" then
                btn.icon:SetTexture(icon)
                btn.icon:SetHidden(false)
            end
        else
            btn.icon:SetHidden(true)
        end
    end
end
