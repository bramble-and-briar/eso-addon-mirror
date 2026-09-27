local Addon = LarvalTearMod
local RecipeWatcher = Addon.Modules.RecipeWatcher

local SCENE_CALLBACK_RETRY_INTERVAL_MS = 1000
local SCENE_CALLBACK_MAX_RETRY = 30
local configs = {}

function RecipeWatcher.GetSceneShowingState()
    return rawget(_G, "SCENE_SHOWING") or "showing"
end

function RecipeWatcher.IsSceneShowingState(newState)
    return newState == RecipeWatcher.GetSceneShowingState()
end

function RecipeWatcher.IsSceneOpen(recipeModule, scene)
    if type(scene) ~= "table" then
        return recipeModule.isStationOpen == true
    end

    if type(scene.IsShowing) == "function" then
        local ok, isShowing = pcall(scene.IsShowing, scene)
        if ok and isShowing == true then
            return true
        end
    end

    if type(scene.GetState) == "function" then
        local ok, state = pcall(scene.GetState, scene)
        if ok then
            return state == RecipeWatcher.GetSceneShowingState() or state == rawget(_G, "SCENE_SHOWN")
        end
    end

    return recipeModule.isStationOpen == true
end

local function RegisterSceneCallback(recipeModule, config)
    if recipeModule[config.callbackRegisteredField] == true then
        return false
    end

    local scene = config.getScene()
    if scene == nil or type(scene.RegisterCallback) ~= "function" then
        return false
    end

    recipeModule[config.callbackRegisteredField] = true
    scene:RegisterCallback("StateChange", config.onSceneStateChange)
    return true
end

local function ScheduleSceneCallbackRegistration(recipeModule, config)
    if recipeModule[config.callbackRegisteredField] == true
        or recipeModule[config.retryScheduledField] == true then
        return false
    end
    if type(EVENT_MANAGER) ~= "table" or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
        return false
    end

    recipeModule[config.retryScheduledField] = true
    local retryCount = 0
    EVENT_MANAGER:RegisterForUpdate(config.updateName, SCENE_CALLBACK_RETRY_INTERVAL_MS, function()
        retryCount = retryCount + 1

        if recipeModule[config.callbackRegisteredField] == true then
            recipeModule[config.retryScheduledField] = false
            if type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
                EVENT_MANAGER:UnregisterForUpdate(config.updateName)
            end
            return
        end
        if RegisterSceneCallback(recipeModule, config) then
            recipeModule[config.retryScheduledField] = false
            if type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
                EVENT_MANAGER:UnregisterForUpdate(config.updateName)
            end
            return
        end

        if retryCount >= SCENE_CALLBACK_MAX_RETRY then
            recipeModule[config.retryScheduledField] = false
            if type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
                EVENT_MANAGER:UnregisterForUpdate(config.updateName)
            end
            config.debug(config.retryExhaustedMessage)
        end
    end)

    return true
end

local function EnsureSceneCallback(recipeModule, config)
    if not RegisterSceneCallback(recipeModule, config) then
        ScheduleSceneCallbackRegistration(recipeModule, config)
    end
end

function RecipeWatcher.Initialize(recipeModule)
    recipeModule:RegisterStationEvents()
    EnsureSceneCallback(recipeModule, configs[recipeModule])
end

function RecipeWatcher.RegisterStationEvents(recipeModule)
    if recipeModule.stationEventsRegistered == true then
        return false
    end
    if EVENT_MANAGER == nil or type(EVENT_MANAGER.RegisterForEvent) ~= "function" then
        return false
    end

    local stationInteractEvent = rawget(_G, "EVENT_CRAFTING_STATION_INTERACT")
    local stationEndEvent = rawget(_G, "EVENT_END_CRAFTING_STATION_INTERACT")
    if stationInteractEvent == nil or stationEndEvent == nil then
        return false
    end

    local config = configs[recipeModule]
    recipeModule.stationEventsRegistered = true
    EVENT_MANAGER:RegisterForEvent(config.stationInteractName, stationInteractEvent, function(_, craftingType)
        if craftingType == rawget(_G, config.craftingTypeName) then
            recipeModule.isStationOpen = true
            EnsureSceneCallback(recipeModule, config)
        end
    end)
    EVENT_MANAGER:RegisterForEvent(config.stationEndName, stationEndEvent, function(_, craftingType)
        if craftingType == rawget(_G, config.craftingTypeName) then
            recipeModule.isStationOpen = false
        end
    end)
    return true
end

function RecipeWatcher.Attach(recipeModule, config)
    configs[recipeModule] = config
    recipeModule.isStationOpen = false
    recipeModule.RegisterStationEvents = RecipeWatcher.RegisterStationEvents
end
