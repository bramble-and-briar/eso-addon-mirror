-- TomesGuard
-- Prevents UI lockups and fatal taint errors (QuerySkuCatalog) by preventing
-- Tamriel Tomes from opening while conflicting scenes (mail, inventory, etc.) are active.
-- Author: alezhu

local TomesGuard = {
    name = "TomesGuard",
    version = "1.0.2",
}

local TOMES_SCENES = {
    ["tamrieltomesscenekeyboard"] = true,
    ["tamrieltomesscenegamepad"] = true,
    ["tamrieltomespurchasescenekeyboard"] = true,
    ["tamrieltomespurchasescenegamepad"] = true,
}

local TOMES_GROUPS = {
    ["tamrieltomesscenegroup"] = true,
    ["tamriel_tomes_scene_group_keyboard"] = true,
    ["tamriel_tomes_scene_group_gamepad"] = true,
}

local function IsTomesScene(sceneName)
    return sceneName and TOMES_SCENES[string.lower(sceneName)] == true
end

local function IsTomesSceneGroup(groupName)
    return groupName and TOMES_GROUPS[string.lower(groupName)] == true
end

local function IsConflictingSceneActive()
    local currentScene = SCENE_MANAGER:GetCurrentScene()
    if not currentScene then return false end

    local name = currentScene:GetName()
    if not name or name == "hud" or name == "hudui" or IsTomesScene(name) then
        return false
    end

    return true, name
end

local function GetLocalizedSceneName(sceneName)
    if not sceneName then return "" end
    local stringIdName = "SI_TOMESGUARD_SCENE_" .. string.upper(sceneName)
    local stringId = _G[stringIdName]
    if stringId then
        return GetString(stringId)
    end
    return sceneName
end

local function CheckAndBlockTomes()
    local isConflict, activeSceneName = IsConflictingSceneActive()
    if isConflict then
        PlaySound(SOUNDS.GENERAL_ALERT_ERROR)

        local localizedScene = GetLocalizedSceneName(activeSceneName)
        local rawTemplate = GetString(SI_TOMESGUARD_WARNING)
        local formatted = (rawTemplate and rawTemplate ~= "") and zo_strformat(rawTemplate, localizedScene) or ("Please close " .. tostring(localizedScene) .. " before opening Tamriel Tomes!")
        local msg = "|cFF4444[TomesGuard]|r " .. formatted

        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NONE, msg)
        CHAT_ROUTER:AddSystemMessage(msg)
        return true -- Block the transition to prevent UI crash
    end
    return false
end

local function Initialize()
    if MAIN_MENU_KEYBOARD then
        ZO_PreHook(MAIN_MENU_KEYBOARD, "ToggleSceneGroup", function(self, sceneGroupName, categoryIndex)
            if IsTomesSceneGroup(sceneGroupName) then
                if CheckAndBlockTomes() then
                    return true
                end
            end
        end)

        ZO_PreHook(MAIN_MENU_KEYBOARD, "ShowSceneGroup", function(self, sceneGroupName, specificScene)
            if IsTomesSceneGroup(sceneGroupName) or IsTomesScene(specificScene) then
                if CheckAndBlockTomes() then
                    return true
                end
            end
        end)

        ZO_PreHook(MAIN_MENU_KEYBOARD, "ShowScene", function(self, sceneName)
            if IsTomesScene(sceneName) then
                if CheckAndBlockTomes() then
                    return true
                end
            end
        end)

        ZO_PreHook(MAIN_MENU_KEYBOARD, "ToggleCategory", function(self, category)
            if category == 3 then
                if CheckAndBlockTomes() then
                    return true
                end
            end
        end)
    end
end

local function OnAddOnLoaded(event, addonName)
    if addonName == TomesGuard.name then
        EVENT_MANAGER:UnregisterForEvent(TomesGuard.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(TomesGuard.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
