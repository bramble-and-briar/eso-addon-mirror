-- PreviewAnywhereInventoryFraming.lua: frame the inventory's own (hold Square) preview like the
-- vendor Buy tab does.
--
-- The inventory scene ships GAMEPAD_NAV_QUADRANT_2_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT (left padding
-- one panel, 1150 px consumed), so a previewed furnishing is centred across quadrants 2-4 and sits
-- behind the item tooltip in quadrant 2. The vendor uses GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT
-- (left padding two panels) and the piece lands right of the tooltip. We swap the options fragment
-- in the scene's fragment list IN PLACE: the game requires the options fragment to precede the
-- ITEM_PREVIEW_GAMEPAD fragment, and RemoveFragment + AddFragment would append it after.
-- Character framing (the standing player at 0.65 of the width) is left alone.
local PA = PreviewAnywhere

local InventoryFraming = {}

local STOCK_OPTIONS_FRAGMENT_NAME = "GAMEPAD_NAV_QUADRANT_2_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT"
local WIDE_OPTIONS_FRAGMENT_NAME = "GAMEPAD_NAV_QUADRANT_3_4_ITEM_PREVIEW_OPTIONS_FRAGMENT"

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
            -- Refresh both so a showing scene applies the new options right away.
            oldFragment:Refresh()
            newFragment:Refresh()
            return true
        end
    end
    return false
end

---Apply the saved setting to the inventory scene (idempotent).
function InventoryFraming.Apply()
    local scene = rawget(_G, "GAMEPAD_INVENTORY_ROOT_SCENE") or SCENE_MANAGER:GetScene("gamepad_inventory_root")
    local stock = rawget(_G, STOCK_OPTIONS_FRAGMENT_NAME)
    local wide = rawget(_G, WIDE_OPTIONS_FRAGMENT_NAME)
    if not (scene and stock and wide) then
        PA.Log("inventory framing: scene or fragments missing")
        return false
    end
    local wantWide = PA.state.savedVars.enabled and PA.state.savedVars.inventoryFraming ~= false
    local changed
    if wantWide then
        changed = ReplaceFragmentInPlace(scene, stock, wide)
    else
        changed = ReplaceFragmentInPlace(scene, wide, stock)
    end
    if changed then
        PA.Log("inventory preview framing -> %s", wantWide and "vendor style (quadrants 3-4)" or "stock (quadrants 2-4)")
    end
    return true
end

function InventoryFraming.Initialize()
    assert(InventoryFraming.Apply(), "inventory framing not applied")
end

PA.InventoryFraming = InventoryFraming
