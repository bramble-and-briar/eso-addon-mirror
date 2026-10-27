-- PreviewAnywhereInventoryFraming.lua: give the inventory's own (hold Square) preview the vendor
-- Buy tab's layout, so the piece sits right of the item tooltip instead of behind it.
--
-- Two kinds of scene fragment decide where a preview lands:
--   frame target  - the screen point the camera puts the preview at (SetFrameLocalPlayerTarget).
--                   Inventory: FRAME_TARGET_GAMEPAD_FRAGMENT, 0.65 of the width (quadrant 3, which
--                   the quadrant-2 tooltip overlaps). Vendor: FRAME_TARGET_STORE_GAMEPAD_FRAGMENT,
--                   0.8 of the width. The character-framing blur is keyed to the same point.
--   options       - how much screen the furniture framing may use. Inventory:
--                   GAMEPAD_NAV_QUADRANT_2_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT; vendor:
--                   GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT.
-- 1.1.0 swapped only the options, so the piece stayed centred at 0.65; 1.3.0 swaps all three.
-- Swaps happen IN PLACE in the scene's fragment list: the game requires the options fragment to
-- precede the ITEM_PREVIEW_GAMEPAD fragment, and RemoveFragment + AddFragment would append it after.
-- The inventory scene also hosts Better Character Overview's All Inventories page, so that page
-- gets the same layout. Side effect: the character standing behind the inventory menus moves to
-- 0.8 as well, exactly as at a vendor.
local PA = PreviewAnywhere

local InventoryFraming = {}

local VENDOR_TARGET_X, VENDOR_TARGET_Y = 0.8, 0.55 -- CalculateGamepadStoreFramingTarget

local vendorBlurFragment -- the game has no gamepad blur fragment at the vendor point; made once

local function VendorBlur()
    if vendorBlurFragment == nil and ZO_CharacterFramingBlur then
        vendorBlurFragment = ZO_CharacterFramingBlur:New(function()
            local screenWidth, screenHeight = GuiRoot:GetDimensions()
            return VENDOR_TARGET_X * screenWidth, VENDOR_TARGET_Y * screenHeight
        end)
    end
    return vendorBlurFragment
end

---Stock fragment and its vendor-layout replacement, per role.
---@return table[] { label, stock, vendor }
local function Swaps()
    return {
        { "frame target", rawget(_G, "FRAME_TARGET_GAMEPAD_FRAGMENT"), rawget(_G, "FRAME_TARGET_STORE_GAMEPAD_FRAGMENT") },
        { "framing blur", rawget(_G, "FRAME_TARGET_BLUR_GAMEPAD_FRAGMENT"), VendorBlur() },
        { "preview options", rawget(_G, "GAMEPAD_NAV_QUADRANT_2_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT"), rawget(_G, "GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT") },
    }
end

local function ReplaceFragmentInPlace(scene, oldFragment, newFragment)
    if not (scene and scene.fragments and oldFragment and newFragment) or oldFragment == newFragment then
        return false
    end
    if scene:HasFragment(newFragment) then
        return false
    end
    for i, fragment in ipairs(scene.fragments) do
        if fragment == oldFragment then
            scene.fragments[i] = newFragment
            newFragment:SetSceneManager(scene.sceneManager)
            -- Refresh both so a showing scene applies the new layout right away.
            oldFragment:Refresh()
            newFragment:Refresh()
            return true
        end
    end
    return false
end

---Apply the saved setting to the inventory scene (idempotent).
---@return boolean applied every role had both fragments
function InventoryFraming.Apply()
    local scene = rawget(_G, "GAMEPAD_INVENTORY_ROOT_SCENE") or SCENE_MANAGER:GetScene("gamepad_inventory_root")
    if not scene then
        PA.Log("inventory framing: scene missing")
        return false
    end
    local wantVendor = PA.state.savedVars.enabled and PA.state.savedVars.inventoryFraming ~= false
    local applied = true
    for _, swap in ipairs(Swaps()) do
        local label, stock, vendor = swap[1], swap[2], swap[3]
        if stock and vendor then
            local changed
            if wantVendor then
                changed = ReplaceFragmentInPlace(scene, stock, vendor)
            else
                changed = ReplaceFragmentInPlace(scene, vendor, stock)
            end
            if changed then
                PA.Log("inventory %s -> %s", label, wantVendor and "vendor layout" or "stock")
            end
        else
            PA.Log("inventory framing: %s fragment missing", label)
            applied = false
        end
    end
    return applied
end

function InventoryFraming.Initialize()
    assert(InventoryFraming.Apply(), "inventory framing not fully applied")
end

PA.InventoryFraming = InventoryFraming
