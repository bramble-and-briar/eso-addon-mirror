---@diagnostic disable: undefined-field, inject-field -- Native controls and scene fragments expose additional runtime fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocWorkUI
local ui = {}
BattleScrolls.inventoryPocWorkUI = ui
local poc = BattleScrolls.inventoryPoc
local tradingHouse = BattleScrolls.inventoryPocTradingHouseUI
local UPDATE_NAME = 'BattleScrollsInventoryPocWork'
local ACTION_LAYER = 'BattleScrollsInventoryWork'
local SHOW_DELAY_MS = 150
local LABELS = {
    bank = BATTLESCROLLS_IPOC_WORK_BANK,
    sell = BATTLESCROLLS_IPOC_WORK_SELL, deconstruct = BATTLESCROLLS_IPOC_WORK_DECONSTRUCT,
    search = BATTLESCROLLS_IPOC_WORK_SEARCH, listings = BATTLESCROLLS_IPOC_WORK_LISTINGS,
    list = BATTLESCROLLS_IPOC_WORK_LIST,
    armory = BATTLESCROLLS_IPOC_WORK_ARMORY, wardrobe = BATTLESCROLLS_IPOC_WORK_WARDROBE,
}
local control, taskLabel, itemLabel, maskedScene
local enabled, registered, showing, updating = false, false, false, false
local action, itemLink, guildId, showAt
local armoryRequest, armoryDialogName
local ARMORY_PROGRESS = 'ARMORY_BUILD_RESTORE_DIALOG'
local ARMORY_SUCCESS = 'ARMORY_BUILD_RESTORE_SUCCESS_DIALOG'
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
    local scene = SCENE_MANAGER:GetCurrentScene()
    if not scene or not scene:IsShowing() then return false end
    local interaction = GetInteractionType()
    local expected
    if nextAction == 'bank' then expected = INTERACTION_BANK
    elseif nextAction == 'sell' then expected = INTERACTION_VENDOR
    elseif nextAction == 'deconstruct' then expected = INTERACTION_CRAFT
    elseif nextAction == 'search' or nextAction == 'listings' or nextAction == 'list' then expected = INTERACTION_TRADINGHOUSE
    elseif nextAction == 'armory' then expected = INTERACTION_ARMORY
    elseif nextAction == 'wardrobe' and (interaction == INTERACTION_BANK or interaction == INTERACTION_ARMORY) then
        expected = interaction
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
    if armoryDialogName then mask(ZO_Dialogs_FindDialog(armoryDialogName)) end
end

---Release the native notices belonging to our restore through their normal
---lifecycle. Their existing callbacks finish the native Armory UI updates.
local function releaseArmoryNotice()
    if not enabled or poc.cancelled then armoryRequest, armoryDialogName = nil, nil; return end
    local request = BattleScrolls.inventoryPocBuilds.request
    if request and request.kind == 'armory' then armoryRequest = request end
    if armoryDialogName and not ZO_Dialogs_IsShowing(armoryDialogName) then armoryDialogName = nil end
    if armoryRequest then
        local name = ZO_Dialogs_IsShowing(ARMORY_PROGRESS) and ARMORY_PROGRESS
            or (ZO_Dialogs_IsShowing(ARMORY_SUCCESS) and ARMORY_SUCCESS)
        if name then
            armoryDialogName = name
            if name == ARMORY_SUCCESS then armoryRequest = nil end
            ZO_Dialogs_ReleaseDialog(name)
        elseif not armoryDialogName and request ~= armoryRequest then armoryRequest = nil end
    end
    return armoryDialogName ~= nil
end

local function create()
    control = BattleScrollsInventoryPocWork
    local header = control:GetNamedChild('PanelHeaderContainer').header
    ZO_GamepadGenericHeader_Initialize(header)
    ZO_GamepadGenericHeader_Refresh(header, { titleText = GetString(BATTLESCROLLS_IPOC_TITLE) })
    taskLabel = control:GetNamedChild('PanelTask')
    itemLabel = control:GetNamedChild('PanelItem')
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
    tradingHouse.update()
    ui.refresh()
    if not action then hide(); return end
    if not showing and showAt and GetFrameTimeMilliseconds() >= showAt then show() end
    if showing then maskScene() end
end

function ui.refresh()
    if maskedScene and maskedScene ~= SCENE_MANAGER:GetCurrentScene() then hide() end
    local previousArmoryDialog = armoryDialogName
    local ownArmoryNotice = releaseArmoryNotice()
    local nextAction, nextItem, nextGuild
    if enabled then nextAction, nextItem, nextGuild = poc.activity() end
    if tradingHouse.isDeferred() and not nextAction then
        nextAction, nextGuild = 'listings', GetSelectedTradingHouseGuildId()
    end
    if ownArmoryNotice and not nextAction then nextAction = 'armory' end
    if nextAction and not canCoverScene(nextAction) then nextAction = nil end
    if nextAction and enabled and not poc.cancelled and not ownArmoryNotice and ZO_Dialogs_IsShowingDialog() then
        poc.cancelWork()
        return
    end
    if not nextAction then
        action, itemLink, guildId = nil, nil, nil
        hide()
        return
    end
    if not control then create() end
    if nextAction ~= action or nextItem ~= itemLink or nextGuild ~= guildId then
        action, itemLink, guildId = nextAction, nextItem, nextGuild
        local label = GetString(LABELS[action])
        taskLabel:SetText(guildId and zo_strformat(label, GetGuildName(guildId)) or label)
        itemLabel:SetText(itemLink or '')
    end
    if not showing and not showAt then showAt = GetFrameTimeMilliseconds() + SHOW_DELAY_MS end
    if not updating then
        updating = true
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 0, onUpdate)
    end
    if ownArmoryNotice and showing and previousArmoryDialog ~= armoryDialogName then
        -- Keep Cancel above the native dialog's temporary input layer.
        RemoveActionLayerByName(ACTION_LAYER)
        PushActionLayerByName(ACTION_LAYER)
    end
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    tradingHouse.setEnabled(value)
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
