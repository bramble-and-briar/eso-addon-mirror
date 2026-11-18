---@diagnostic disable: undefined-field, inject-field -- Scene registries expose native runtime fields
if not SemisPlaygroundCheckAccess() then return end

---Which service visits the helper automates, and how a guild-store visit is
---shown.
---
---At a bank, merchant, smithing station, Armory or companion menu ESO shows
---its own screen and the work panel covers it. ESO opened that screen itself
---and keeps it current through its own events, so the helper starts no scene
---change there: the panel hides and the player is already in the menu
---(docs/inventory-addon/ui-taint.md, Q6 d).
---
---The guild store cannot be covered. Its screen shares the request channel
---and the search tracker with the helper, reselects its guild as it shows,
---and locks its input around every request. An automated guild-store visit
---gets this module's own scene instead and closes when its work ends; the
---next visit within the cooldown opens ESO's screen.
---@class InventoryPocServiceUI
local ui = {}
BattleScrolls.inventoryPocServiceUI = ui
local poc = BattleScrolls.inventoryPoc
local UPDATE_NAME = 'BattleScrollsInventoryPocServices'
local SCENE_NAME = 'battleScrollsInventoryGuildStore'
local COOLDOWN_MS = 5 * 60 * 1000
---ESO answers an interaction the helper ended within a frame or two.
local CLOSE_GRACE_MS = 500
local enabled = false
---Created when automation is first enabled; everything below runs after that.
---@type ZO_Scene
local scene
---@type table<string, ZO_Scene> ESO's scenes whose registry entry currently leads to ours
local routes = {}
local armed, visiting, closing = false, false, false
local cooldownUntil = 0
---@type number|nil When our own scene change stands in for ESO's missing answer
local closeDeadline
---The Armory and the companion menu start work only when something is
---waiting for them. That is decided before the visit and held through it,
---because the work itself ends the need: a restore completes the build's
---request, and equipping removes the companion's upgrade.
local armoryWanted, companionWanted = false, false

local function restore()
    for name, original in pairs(routes) do
        if SCENE_MANAGER.scenes[name] == scene then SCENE_MANAGER.scenes[name] = original end
        routes[name] = nil
    end
    armed = false
    BattleScrolls.inventoryPocTradingHouseUI.setSuspended(false)
end

local function finish()
    if visiting then
        visiting = false
        cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
        poc.endVisit()
    end
    closing, closeDeadline = false, nil
    restore()
    if not enabled then EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME) end
end

local function close()
    if closing then return end
    closing = true
    cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
    if poc.visitFinished then poc.endVisit() else poc.cancelWork() end
    local current = SCENE_MANAGER:GetCurrentScene() == scene
    if current and scene:IsShowing() and GetInteractionType() == INTERACTION_TRADINGHOUSE then
        -- ESO answers the ended interaction by calling the scene's cancel
        -- handler, which is ESO's own closure and hides the scene from a
        -- trusted stack. A scene change started here would run that whole
        -- transition untrusted (docs/inventory-addon/ui-taint.md, T6 and T7).
        closeDeadline = GetFrameTimeMilliseconds() + CLOSE_GRACE_MS
        EndInteraction(INTERACTION_TRADINGHOUSE)
    elseif current or SCENE_MANAGER:GetNextScene() == scene then
        -- The interaction is already over, or the scene is only queued, so
        -- ESO has nothing left to answer.
        SCENE_MANAGER:RequestShowLeaderBaseScene(ZO_BHSCR_INTERACT_ENDED)
    else
        EndInteraction(INTERACTION_TRADINGHOUSE)
        finish()
    end
end

---ESO answers an interaction that ended (combat, the NPC leaving, our own
---EndInteraction) by calling the scene descriptor's OnInteractionCanceled,
---which changes scenes. A handler created while this addon builds its scene
---would be untrusted and run that whole transition untrusted. ESO's own
---handlers, created at load, only consult their descriptor's scene registry,
---so one of them can serve our scene once it is registered there.
---@return table|nil descriptor A native interaction descriptor with a trusted handler
local function nativeInteraction()
    local fallback
    for _, candidate in pairs(SCENE_MANAGER.scenes) do
        local info = candidate.GetInteractionInfo and candidate:GetInteractionInfo()
        if info and info.registeredScenes and info.OnInteractionCanceled and IsTrustedFunction(info.OnInteractionCanceled) then
            for _, kind in ipairs(info.interactTypes) do
                if kind == INTERACTION_TRADINGHOUSE then return info end
            end
            fallback = fallback or info
        end
    end
    return fallback
end

local function create()
    local native = nativeInteraction()
    scene = ZO_InteractScene:New(SCENE_NAME, SCENE_MANAGER, {
        type = SCENE_NAME, interactTypes = { INTERACTION_TRADINGHOUSE },
        OnInteractionCanceled = native and native.OnInteractionCanceled,
    })
    if native then native.registeredScenes[scene] = true end
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(FRAME_INTERACTION_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(FRAME_TARGET_BLUR_QUADRANT_4_GAMEPAD_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:RegisterCallback('StateChange', function(_, state)
        if state == SCENE_SHOWING then
            visiting = true
            poc.beginVisit()
        elseif state == SCENE_HIDING then
            closing = true
            if poc.visitFinished then poc.endVisit() else poc.cancelWork() end
        elseif state == SCENE_HIDDEN then
            finish()
        end
        BattleScrolls.inventoryPocWorkUI.refresh()
    end)
    -- The native post-hook runs the scene's own removal under the caller's trust.
    SecurePostHook(scene, 'OnRemovedFromQueue', function()
        -- Queue cancellation can happen before StateChange has established a visit.
        if armed then
            cooldownUntil = GetFrameTimeMilliseconds() + COOLDOWN_MS
            poc.cancelWork()
            finish()
        end
    end)
end

local function arm()
    -- The scene registry supplies the destination to ESO's existing Show call.
    -- Native scene methods, state callbacks and shared Show functions retain
    -- their original function identities throughout the visit.
    for name, candidate in pairs(SCENE_MANAGER.scenes) do
        local info = candidate ~= scene and candidate.GetInteractionInfo and candidate:GetInteractionInfo()
        if info then
            for _, interaction in ipairs(info.interactTypes) do
                if interaction == INTERACTION_TRADINGHOUSE then
                    routes[name] = candidate
                    SCENE_MANAGER.scenes[name] = scene
                    break
                end
            end
        end
    end
    armed = next(routes) ~= nil
    if armed then BattleScrolls.inventoryPocTradingHouseUI.setSuspended(true) end
end

---@return boolean
function ui.canAutomate()
    local interaction = GetInteractionType()
    if interaction == INTERACTION_TRADINGHOUSE then return armed end
    if interaction == INTERACTION_ARMORY then return armoryWanted end
    if interaction == INTERACTION_COMPANION_MENU then return companionWanted end
    if interaction == INTERACTION_CRAFT then
        local craftingType = GetCraftingInteractionType()
        return craftingType ~= CRAFTING_TYPE_ALCHEMY and craftingType ~= CRAFTING_TYPE_PROVISIONING
            and craftingType ~= CRAFTING_TYPE_SCRIBING
    end
    -- Storage chests and the furniture vault open ESO's banking screen too.
    if IsBankOpen() then
        local bag = GetBankingBag()
        return bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK
    end
    return true
end

---@return InventoryPocActivity|nil
function ui.activity()
    if visiting and not closing and SCENE_MANAGER:GetCurrentScene() == scene then return 'listings' end
end

---@return boolean The helper's own guild-store scene is on screen
function ui.isShowing()
    return visiting and SCENE_MANAGER:GetCurrentScene() == scene and scene:IsShowing()
end

function ui.update()
    local now = GetFrameTimeMilliseconds()
    if closeDeadline then
        if now >= closeDeadline then
            closeDeadline = nil
            if SCENE_MANAGER:GetCurrentScene() == scene or SCENE_MANAGER:GetNextScene() == scene then
                SCENE_MANAGER:RequestShowLeaderBaseScene(ZO_BHSCR_INTERACT_ENDED)
            end
        end
    elseif visiting and not closing then
        local ended = GetInteractionType() ~= INTERACTION_TRADINGHOUSE or IsUnitInCombat('player') or IsUnitDead('player')
        local finished = not enabled or poc.cancelled or poc.visitFinished or BattleScrolls.inventoryPocMarket.stopped
        -- A gamepad dialog is a fragment of the scene under it. Closing the
        -- visit while ESO shows one would dismiss it unread. The player
        -- answers it first.
        if ended or (finished and not ZO_Dialogs_IsShowingDialog()) then close() end
    end
    if not enabled then return end
    local interaction = GetInteractionType()
    if interaction ~= INTERACTION_ARMORY then armoryWanted = BattleScrolls.inventoryPocBuilds.wantsArmory() end
    if interaction ~= INTERACTION_COMPANION_MENU then
        companionWanted = BattleScrolls.inventoryPocCompanions.hasUpgrade()
    end
    if not visiting and armed and SCENE_MANAGER:GetNextScene() == scene
        and (interaction ~= INTERACTION_TRADINGHOUSE or poc.cancelled or poc.visitFinished) then close() end
    -- Leave a manual visit intact even when its cooldown expires.
    if interaction ~= INTERACTION_TRADINGHOUSE and not armed and now >= cooldownUntil then arm() end
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    if value and not scene then create() end
    BattleScrolls.inventoryPocTradingHouseUI.setEnabled(value)
    if value then
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 100, ui.update)
    elseif scene then
        if visiting or SCENE_MANAGER:GetNextScene() == scene then close() end
        restore()
        armoryWanted, companionWanted = false, false
        -- The watch on ESO's answer outlives disabling.
        if not closeDeadline then EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME) end
    end
    ui.update()
end
