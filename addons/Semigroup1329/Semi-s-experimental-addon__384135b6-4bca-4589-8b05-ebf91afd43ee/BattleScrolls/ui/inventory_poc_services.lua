---@diagnostic disable: undefined-field, inject-field -- Scene registries expose native runtime fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocServiceUI
local ui = {}
BattleScrolls.inventoryPocServiceUI = ui
local poc = BattleScrolls.inventoryPoc
local UPDATE_NAME = 'BattleScrollsInventoryPocServices'
local COOLDOWN_MS = 5 * 60 * 1000
local enabled = false
---@class InventoryPocService
---@field interaction number
---@field action InventoryPocActivity
---@field scene ZO_Scene
---@field routes table<string, ZO_Scene>
---@field armed boolean
---@field cooldownUntil number
---@field closing boolean|nil
---@type table<number, InventoryPocService>
local services = {}
---@type InventoryPocService|nil
local active
local armoryResultCallback
local armoryCallbackRegistered = false

---The manager resumes its dialog queue in its restore-response handler. Its
---result-closed callback updates a keybind descriptor allocated by the native
---Armory screen. Keep that presentation callback suspended until that screen
---has opened, including late restore results after Cancel.
local function suppressArmoryResultUI() return true end

local function restoreArmoryResultUI()
    if armoryResultCallback then
        if ZO_ARMORY_MANAGER.OnBuildOperationResultClosed == suppressArmoryResultUI then
            ZO_ARMORY_MANAGER.OnBuildOperationResultClosed = armoryResultCallback
        end
        armoryResultCallback = nil
    end
end

local function suspendArmoryResultUI()
    if armoryResultCallback then return end
    armoryResultCallback = ZO_ARMORY_MANAGER.OnBuildOperationResultClosed
    ZO_ARMORY_MANAGER.OnBuildOperationResultClosed = suppressArmoryResultUI
    if not armoryCallbackRegistered then
        armoryCallbackRegistered = true
        for _, scene in ipairs({ ARMORY_ROOT_GAMEPAD_SCENE, ARMORY_KEYBOARD_SCENE }) do
            scene:RegisterCallback('StateChange', function(_, state)
                if state == SCENE_SHOWN then restoreArmoryResultUI() end
            end)
        end
    end
end

---@param service InventoryPocService
local function restore(service)
    for name, original in pairs(service.routes) do
        if SCENE_MANAGER.scenes[name] == service.scene then SCENE_MANAGER.scenes[name] = original end
        service.routes[name] = nil
    end
    service.armed = false
    if service.interaction == INTERACTION_TRADINGHOUSE then
        BattleScrolls.inventoryPocTradingHouseUI.setSuspended(false)
    elseif service.interaction == INTERACTION_ARMORY and ARMORY_GAMEPAD.keybindStripDescriptor then
        restoreArmoryResultUI()
    end
end

---@param service InventoryPocService
local function finish(service)
    if active == service then
        active = nil
        service.cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
        poc.endVisit()
    end
    service.closing = nil
    restore(service)
end

---@param service InventoryPocService
local function close(service)
    if service.closing then return end
    service.closing = true
    service.cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
    if poc.visitFinished then poc.endVisit() else poc.cancelWork() end
    -- The owned interaction scene ends the server interaction as it closes.
    -- A later player interaction opens ESO's restored scene during cooldown.
    if SCENE_MANAGER:GetCurrentScene() == service.scene or SCENE_MANAGER:GetNextScene() == service.scene then
        SCENE_MANAGER:RequestShowLeaderBaseScene(ZO_BHSCR_INTERACT_ENDED)
    else
        EndInteraction(service.interaction)
        finish(service)
    end
end

---@param interaction number
---@param action InventoryPocActivity
local function create(interaction, action)
    local name = 'battleScrollsInventoryService' .. action
    local scene = ZO_InteractScene:New(name, SCENE_MANAGER, {
        type = name, interactTypes = { interaction },
    })
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(FRAME_INTERACTION_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(FRAME_TARGET_BLUR_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    ---@type InventoryPocService
    local service = { interaction = interaction, action = action, scene = scene, routes = {}, armed = false, cooldownUntil = 0 }
    services[interaction] = service
    scene:RegisterCallback('StateChange', function(_, state)
        if state == SCENE_SHOWING then
            active = service
            poc.beginVisit()
        elseif state == SCENE_HIDING then
            service.closing = true
            if poc.visitFinished then poc.endVisit() else poc.cancelWork() end
        elseif state == SCENE_HIDDEN then
            finish(service)
        end
        BattleScrolls.inventoryPocWorkUI.refresh()
    end)
    ZO_PostHook(scene, 'OnRemovedFromQueue', function()
        -- Queue cancellation can happen before StateChange has established a visit.
        if service.armed then
            service.cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
            poc.cancelWork()
            finish(service)
        end
    end)
end

---@param service InventoryPocService
local function arm(service)
    -- The scene registry supplies the destination to ESO's existing Show call.
    -- Native scene methods, state callbacks and shared Show functions retain
    -- their original function identities throughout the visit.
    for name, scene in pairs(SCENE_MANAGER.scenes) do
        local info = scene.GetInteractionInfo and scene:GetInteractionInfo()
        -- Every alchemy/provisioning subscene shares its station descriptor.
        if scene ~= service.scene and info and info.type ~= 'Alchemy Station' and info.type ~= 'Provisioner Station' then
            for _, interaction in ipairs(info.interactTypes) do
                -- Merchants and stables share an interaction descriptor.
                local merchant = service.interaction ~= INTERACTION_VENDOR or name == 'store' or name == 'gamepad_store'
                if interaction == service.interaction and merchant then
                    service.routes[name] = scene
                    SCENE_MANAGER.scenes[name] = service.scene
                    break
                end
            end
        end
    end
    service.armed = next(service.routes) ~= nil
    if service.armed and service.interaction == INTERACTION_TRADINGHOUSE then
        BattleScrolls.inventoryPocTradingHouseUI.setSuspended(true)
    elseif service.armed and service.interaction == INTERACTION_ARMORY then
        suspendArmoryResultUI()
    end
end

---@return boolean
function ui.canAutomate()
    local interaction = GetInteractionType()
    if interaction == INTERACTION_CRAFT then
        local craftingType = GetCraftingInteractionType()
        if craftingType == CRAFTING_TYPE_ALCHEMY or craftingType == CRAFTING_TYPE_PROVISIONING then return false end
    end
    local service = services[interaction]
    return not service or service.armed
end

---@return InventoryPocActivity|nil
function ui.activity()
    if active and not active.closing and SCENE_MANAGER:GetCurrentScene() == active.scene then return active.action end
end

---@return boolean
function ui.isShowing()
    return active ~= nil and SCENE_MANAGER:GetCurrentScene() == active.scene and active.scene:IsShowing()
end

function ui.update()
    if active then
        local service = active
        if not enabled or poc.cancelled or poc.visitFinished or GetInteractionType() ~= service.interaction
            or IsUnitInCombat('player') or IsUnitDead('player')
            or (service.interaction == INTERACTION_TRADINGHOUSE and BattleScrolls.inventoryPocMarket.stopped) then
            close(service)
        end
    end
    if not enabled then return end
    local interaction, now = GetInteractionType(), GetFrameTimeMilliseconds()
    for _, service in pairs(services) do
        if not active and service.armed and SCENE_MANAGER:GetNextScene() == service.scene
            and (interaction ~= service.interaction or poc.cancelled or poc.visitFinished) then close(service) end
        -- Leave a manual visit intact even when its cooldown expires.
        local usingDestination = interaction == service.interaction
            or (service.interaction == INTERACTION_VENDOR and interaction == INTERACTION_STABLE)
        if not usingDestination then
            local ready = service.interaction ~= INTERACTION_COMPANION_MENU or BattleScrolls.inventoryPocCompanions.hasUpgrade()
            if service.armed and not ready then restore(service)
            elseif not service.armed and ready and now >= service.cooldownUntil then arm(service) end
        end
    end
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    if value and not next(services) then
        create(INTERACTION_BANK, 'bank')
        create(INTERACTION_VENDOR, 'sell')
        create(INTERACTION_CRAFT, 'deconstruct')
        create(INTERACTION_TRADINGHOUSE, 'listings')
        create(INTERACTION_ARMORY, 'armory')
        create(INTERACTION_COMPANION_MENU, 'equip')
        -- StableInteractStart updates stats before opening the shared merchant
        -- scene. Restore its destination before ESO continues that event.
        SecurePostHook(STABLE_MANAGER, 'UpdateStats', function()
            local service = services[INTERACTION_VENDOR]
            if service.armed and GetInteractionType() == INTERACTION_STABLE then restore(service) end
        end)
    end
    BattleScrolls.inventoryPocTradingHouseUI.setEnabled(value)
    if value then
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 100, ui.update)
    else
        if active then close(active) end
        for _, service in pairs(services) do
            if SCENE_MANAGER:GetNextScene() == service.scene then close(service) end
            restore(service)
        end
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    end
    ui.update()
end
