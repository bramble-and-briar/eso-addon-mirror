-- Preserve native gamepad map routing in Hybrid mode.

local ADDON = ESOHybridUI

local function InstallHybridMapCategoryHook()
    if ADDON.runtime.hybridMapCategoryHookInstalled then
        return
    end

    local mainMenu = MAIN_MENU_KEYBOARD
    if not mainMenu or type(mainMenu.ToggleCategory) ~= "function" then
        return
    end

    ZO_PreHook(mainMenu, "ToggleCategory", function(_, category)
        local settings = ADDON:GetSettings()
        if settings.useHybridUI and ADDON:IsNativeGamepadMode() and category == MENU_CATEGORY_MAP then
            -- The dedicated Map button is routed through the keyboard main-menu
            -- object in Hybrid mode. Bypass its keyboard scene selection.
            ADDON:WithNativeGamepadMode(function()
                SCENE_MANAGER:Show("gamepad_worldMap")
            end)
            return true
        end
        return false
    end)

    ADDON.runtime.hybridMapCategoryHookInstalled = true
end

local function InstallHybridWorldMapSceneHook()
    if ADDON.runtime.hybridWorldMapHookInstalled or type(ZO_WorldMap_ShowWorldMap) ~= "function" then
        return
    end

    local originalShowWorldMap = ZO_WorldMap_ShowWorldMap
    ADDON.runtime.originalShowWorldMap = originalShowWorldMap
    -- ESO's function only selects/shows a scene and has no return value,
    -- so a native pre-hook can safely run it under the gamepad context.
    ZO_PreHook("ZO_WorldMap_ShowWorldMap", function(...)
        local settings = ADDON:GetSettings()
        if settings.useHybridUI and ADDON:IsNativeGamepadMode() then
            ADDON:WithNativeGamepadMode(originalShowWorldMap, ...)
            return true
        end
        return false
    end)

    ADDON.runtime.hybridWorldMapHookInstalled = true
end

function ADDON:ApplyWorldMap()
    InstallHybridWorldMapSceneHook()
    InstallHybridMapCategoryHook()
    if self.runtime.worldMapHooksInstalled then return end

    self.runtime.worldMapHooksInstalled = true
end
