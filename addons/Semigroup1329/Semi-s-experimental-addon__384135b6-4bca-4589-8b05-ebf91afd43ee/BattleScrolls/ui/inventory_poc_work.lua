---@diagnostic disable: undefined-field, inject-field -- Native controls and scene fragments expose additional runtime fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocWorkUI
local ui = {}
BattleScrolls.inventoryPocWorkUI = ui
local poc = BattleScrolls.inventoryPoc
local services = BattleScrolls.inventoryPocServiceUI
local UPDATE_NAME = 'BattleScrollsInventoryPocWork'
local ACTION_LAYER = 'BattleScrollsInventoryWork'
local SHOW_DELAY_MS = 150
local LABELS = {
    bank = BATTLESCROLLS_IPOC_WORK_BANK,
    sell = BATTLESCROLLS_IPOC_WORK_SELL, deconstruct = BATTLESCROLLS_IPOC_WORK_DECONSTRUCT,
    search = BATTLESCROLLS_IPOC_WORK_SEARCH, listings = BATTLESCROLLS_IPOC_WORK_LISTINGS,
    list = BATTLESCROLLS_IPOC_WORK_LIST,
    armory = BATTLESCROLLS_IPOC_WORK_ARMORY, wardrobe = BATTLESCROLLS_IPOC_WORK_WARDROBE,
    equip = BATTLESCROLLS_IPOC_WORK_EQUIP, bind = BATTLESCROLLS_IPOC_WORK_BIND,
}
local SERVICE_INTERACTIONS = { INTERACTION_BANK, INTERACTION_VENDOR, INTERACTION_CRAFT, INTERACTION_TRADINGHOUSE }
local control, taskLabel, itemLabel, maskedScene
local enabled, registered, showing, updating = false, false, false, false
local action, itemLink, guildId, itemCount, showAt
local ARMORY_NOTICES = { 'ARMORY_BUILD_RESTORE_DIALOG', 'ARMORY_BUILD_RESTORE_SUCCESS_DIALOG' }
---ESO's dialog functions return early for a definition that is not a table.
local HIDDEN_NOTICE = ''
---@type table<string, table> Native definitions set aside during our own restore
local hiddenNotices = {}
---@type table<Control, number>
local masked = {}

---Consume navigation while the work panel owns input.
function ui:UpdateDirectionalInput()
    DIRECTIONAL_INPUT:ConsumeAll()
end

local function restoreControls()
    for target, alpha in pairs(masked) do
        if target:GetAlpha() == 0 then target:SetAlpha(alpha) end
        masked[target] = nil
    end
end

local function hide()
    showAt = nil
    if showing then
        showing = false
        control:SetHidden(true)
        DIRECTIONAL_INPUT:Deactivate(ui)
        RemoveActionLayerByName(ACTION_LAYER)
        restoreControls()
    end
    maskedScene = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
    updating = false
end

---@param target Control
local function maskOpacity(target)
    local alpha = target:GetAlpha()
    if alpha ~= 0 then
        masked[target] = alpha
        target:SetAlpha(0)
    end
end

---@param target Control|nil
local function mask(target)
    if not target then return end
    if target == GuiRoot or target == control then return end
    if target:IsControlHidden() then return end
    -- Window fades can keep animating their root. Suppress its child panels
    -- so those fades finish normally while the work panel is visible.
    local count = target == target:GetOwningWindow() and target:GetNumChildren() or 0
    if count == 0 then maskOpacity(target)
    else for index = 1, count do maskOpacity(target:GetChild(index)) end end
end

---@param nextAction InventoryPocActivity
---@return boolean
local function canCoverScene(nextAction)
    if not services.isShowing() then return false end
    local scene = SCENE_MANAGER:GetCurrentScene()
    if not scene or not scene:IsShowing() then return false end
    local interaction = GetInteractionType()
    local expected
    if nextAction == 'bank' then expected = INTERACTION_BANK
    elseif nextAction == 'sell' then expected = INTERACTION_VENDOR
    elseif nextAction == 'deconstruct' then expected = INTERACTION_CRAFT
    elseif nextAction == 'search' or nextAction == 'listings' or nextAction == 'list' then expected = INTERACTION_TRADINGHOUSE
    elseif nextAction == 'armory' then expected = INTERACTION_ARMORY
    elseif nextAction == 'equip' then expected = INTERACTION_COMPANION_MENU
    elseif nextAction == 'wardrobe' and (interaction == INTERACTION_BANK or interaction == INTERACTION_ARMORY) then
        expected = interaction
    elseif nextAction == 'bind' then
        for _, candidate in ipairs(SERVICE_INTERACTIONS) do
            if interaction == candidate then expected = interaction end
        end
    end
    if not expected or interaction ~= expected then return false end
    local info = scene.GetInteractionInfo and scene:GetInteractionInfo()
    if info then
        for _, kind in ipairs(info.interactTypes) do
            if kind == expected then return true end
        end
    end
    return false
end

local function maskScene()
    local scene = SCENE_MANAGER:GetCurrentScene()
    if scene then
        for _, fragment in ipairs(scene:GetFragments()) do
            mask(fragment.control or (fragment.GetControl and fragment:GetControl()))
        end
    end
    mask(ZO_GamepadTooltipTopLevel)
    mask(ItemTooltip)
    mask(PopupTooltip)
    mask(KEYBIND_STRIP.control)
    mask(ZO_KeybindStripGamepadBackground)
    mask(ZO_KeybindStripMungeBackground)
end

---Keep ESO from showing its progress and success notices for our own Armory
---restore. Releasing a shown dialog from addon code runs ESO's dialog queue
---untrusted; a button descriptor created there joins the pool shared by every
---gamepad dialog and later breaks unrelated prompts until the UI reloads
---(docs/inventory-addon/ui-taint.md). Swapping the definition is a data
---write: ESO's own handlers then skip the notice. Failures stay visible.
local function routeArmoryNotices()
    local request = BattleScrolls.inventoryPocBuilds.request
    local own = enabled and not poc.cancelled and not poc.visitFinished and request ~= nil and request.kind == 'armory'
    for _, name in ipairs(ARMORY_NOTICES) do
        local definition = ESO_Dialogs[name]
        if own and type(definition) == 'table' then
            hiddenNotices[name], ESO_Dialogs[name] = definition, HIDDEN_NOTICE
        elseif not own and hiddenNotices[name] then
            if definition == HIDDEN_NOTICE then ESO_Dialogs[name] = hiddenNotices[name] end
            hiddenNotices[name] = nil
        end
    end
end

local function create()
    control = BattleScrollsInventoryPocWork
    local header = control:GetNamedChild('PanelHeaderContainer').header
    ZO_GamepadGenericHeader_Initialize(header)
    ZO_GamepadGenericHeader_Refresh(header, { titleText = GetString(BATTLESCROLLS_IPOC_TITLE) })
    taskLabel = control:GetNamedChild('PanelTask')
    itemLabel = control:GetNamedChild('PanelItem')
    control:GetNamedChild('PanelHint'):SetText(GetString(BATTLESCROLLS_IPOC_WORK_REOPEN))
    local cancel = control:GetNamedChild('Cancel')
    cancel:SetKeybind('BATTLESCROLLS_IPOC_CANCEL_WORK', true)
    cancel:SetText(GetString(SI_DIALOG_CANCEL))
    cancel:SetCallback(poc.cancelWork)
end

local function show()
    showing = true
    maskedScene = SCENE_MANAGER:GetCurrentScene()
    control:SetHidden(false)
    PushActionLayerByName(ACTION_LAYER)
    DIRECTIONAL_INPUT:Activate(ui, control)
    maskScene()
end

local function onUpdate()
    ui.refresh()
    if not action then hide(); return end
    if not showing and showAt and GetFrameTimeMilliseconds() >= showAt then show() end
    if showing then maskScene() end
end

function ui.refresh()
    if maskedScene and maskedScene ~= SCENE_MANAGER:GetCurrentScene() then hide() end
    routeArmoryNotices()
    local nextAction, nextItem, nextGuild, nextCount
    if enabled then nextAction, nextItem, nextGuild, nextCount = poc.activity() end
    if enabled and not nextAction then
        nextAction = services.activity()
        if nextAction == 'listings' then nextGuild = GetSelectedTradingHouseGuildId() end
    end
    if nextAction and not canCoverScene(nextAction) then nextAction = nil end
    if nextAction and enabled and not poc.cancelled and ZO_Dialogs_IsShowingDialog() then
        poc.cancelWork()
        return
    end
    if not nextAction then
        action, itemLink, guildId, itemCount = nil, nil, nil, nil
        hide()
        return
    end
    if not control then create() end
    if nextAction ~= action or nextItem ~= itemLink or nextGuild ~= guildId or nextCount ~= itemCount then
        action, itemLink, guildId, itemCount = nextAction, nextItem, nextGuild, nextCount
        local label = GetString(LABELS[action])
        taskLabel:SetText(guildId and zo_strformat(label, GetGuildName(guildId)) or label)
        itemLabel:SetText(itemLink or (itemCount and zo_strformat(GetString(BATTLESCROLLS_IPOC_WORK_COUNT), itemCount)) or '')
    end
    if not showing and not showAt then showAt = GetFrameTimeMilliseconds() + SHOW_DELAY_MS end
    if not updating then
        updating = true
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, onUpdate)
    end
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    services.setEnabled(value)
    if value and not registered then
        registered = true
        SCENE_MANAGER:RegisterCallback('SceneStateChanged', function(scene, _, newState)
            if scene == maskedScene and (newState == SCENE_HIDING or newState == SCENE_HIDDEN) then hide() end
        end)
        EVENT_MANAGER:RegisterForEvent(UPDATE_NAME, EVENT_PLAYER_DEACTIVATED, function()
            if enabled then poc.cancelWork() end
        end)
    end
    ui.refresh()
end
