-- SatchelExchangeKeybindActions.lua: Injects the toggle keybind into the gamepad
-- vendor buy screen. Highlight the item, press Y/Triangle (Auto-Buy Item) to
-- buy one and arm the auto-exchange; press again (while armed) to disarm it.

local StoreUtils = SatchelExchange.StoreUtils
local KeybindUtils = SatchelExchange.KeybindUtils

local SatchelExchangeKeybindActions = {}

local function GetKeybindName()
    local StoreActions = SatchelExchange.StoreActions
    if StoreActions.IsRunning() or StoreActions.IsArmed() then
        return "Stop Auto-Buy Item"
    end
    return "Auto-Buy Item"
end

local function IsKeybindVisible()
    if not SatchelExchange.state.savedVars.enabled then
        return false
    end
    local StoreActions = SatchelExchange.StoreActions
    if StoreActions.IsRunning() or StoreActions.IsArmed() then
        return true
    end
    -- Shown only while an openable container is highlighted, so at vendors
    -- selling several satchel variants (e.g. the Archival Sacks at Filer Tezurs)
    -- it is clear the highlighted one is what gets bought. StoreActions keeps
    -- its own container guards at run start and pre-buy as the last line of defense.
    local entryData = StoreUtils.GetSelectedBuyEntry()
    if not entryData or entryData.entryType ~= STORE_ENTRY_TYPE_ITEM or not entryData.slotIndex then
        return false
    end
    return StoreUtils.IsContainerItemLink(GetStoreItemLink(entryData.slotIndex))
end

local function OnKeybindPressed()
    local StoreActions = SatchelExchange.StoreActions
    if StoreActions.IsRunning() or StoreActions.IsArmed() then
        StoreActions.Stop("stopped by user")
    else
        StoreActions.Start()
    end
end

function SatchelExchangeKeybindActions.Initialize()
    local component = StoreUtils.GetBuyComponent()
    if not component or not component.keybindStripDescriptor then
        SatchelExchange.Log("ERROR: gamepad store buy component not available; keybind not installed")
        return
    end

    table.insert(component.keybindStripDescriptor, KeybindUtils.BuildToggleDescriptor({
        name = GetKeybindName,
        callback = OnKeybindPressed,
        visible = IsKeybindVisible,
    }))
end

SatchelExchange.KeybindActions = SatchelExchangeKeybindActions
