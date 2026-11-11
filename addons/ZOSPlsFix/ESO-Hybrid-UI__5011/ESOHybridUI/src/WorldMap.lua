-- Hybrid keeps ESO's native gamepad world map: the Map button and every direct
-- map-open call are routed through the native gamepad scene.

local ADDON = ESOHybridUI

local function InstallMapCategoryHook()
    local mainMenu = MAIN_MENU_KEYBOARD
    if not mainMenu or not mainMenu.ToggleCategory then
        return false
    end

    ZO_PreHook(mainMenu, "ToggleCategory", function(_, category)
        if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() and category == MENU_CATEGORY_MAP then
            -- The dedicated Map button runs through the keyboard main menu in
            -- Hybrid; bypass its keyboard scene selection.
            ADDON:WithNativeGamepadMode(function()
                SCENE_MANAGER:Show("gamepad_worldMap")
            end)
            return true
        end
        return false
    end)
    return true
end

local function InstallMapSceneHook()
    local originalShowWorldMap = _G.ZO_WorldMap_ShowWorldMap
    if type(originalShowWorldMap) ~= "function" then
        return false
    end

    -- ESO's function only selects/shows a scene and returns nothing, so a
    -- pre-hook can safely run it under the native answer and suppress the original.
    ZO_PreHook("ZO_WorldMap_ShowWorldMap", function(...)
        if ADDON:IsHybrid() and ADDON:IsNativeGamepadMode() then
            ADDON:WithNativeGamepadMode(originalShowWorldMap, ...)
            return true
        end
        return false
    end)
    return true
end

function ADDON:ApplyWorldMap()
    self:InstallWhenReady("mapSceneHook", InstallMapSceneHook)
    self:InstallWhenReady("mapCategoryHook", InstallMapCategoryHook)
end
