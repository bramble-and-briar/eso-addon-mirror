local ADDON_NAME = "NowhereKeys"
local SAVED_VARS_NAME = "NowhereKeysSavedVariables"
local SAVED_VARS_VERSION = 1

local ITEM_ID = 224302

local KEY_ICON = "/esoui/art/icons/housing_uni_inc_nowherekey001.dds"
local BAG_ICON = "/esoui/art/tooltips/icon_bag.dds"
local BANK_ICON = "/esoui/art/tooltips/icon_bank.dds"

local DEFAULTS = {
    x = 500,
    y = 300,
    enabled = true,
}

local EVENT_BACKPACK = ADDON_NAME .. "_Backpack"
local EVENT_BANK = ADDON_NAME .. "_Bank"
local EVENT_SUBSCRIBER_BANK = ADDON_NAME .. "_SubscriberBank"
local EVENT_FULL_UPDATE = ADDON_NAME .. "_FullUpdate"
local EVENT_OPEN_BANK_NAME = ADDON_NAME .. "_OpenBank"

local savedVariables
local window
local hudFragment
local inventoryCountLabel
local bankCountLabel
local eventsRegistered = false

local function GetCountFromBag(bagId)
    local count = 0

    for slotIndex in ZO_IterateBagSlots(bagId) do
        local itemLink = GetItemLink(bagId, slotIndex)

        if itemLink ~= "" and GetItemLinkItemId(itemLink) == ITEM_ID then
            local _, stackCount = GetItemInfo(bagId, slotIndex)
            count = count + (stackCount or 0)
        end
    end

    return count
end

local function GetCounts()
    local backpackCount = GetCountFromBag(BAG_BACKPACK)
    local bankCount = GetCountFromBag(BAG_BANK) + GetCountFromBag(BAG_SUBSCRIBER_BANK)

    return backpackCount, bankCount
end

local function UpdateVisibility(backpackCount, bankCount)
    hudFragment:SetHiddenForReason("NoKeys", (backpackCount + bankCount) == 0, 0, 0)
end

local function Update()
    local backpackCount, bankCount = GetCounts()

    inventoryCountLabel:SetText(tostring(backpackCount))
    bankCountLabel:SetText(tostring(bankCount))

    UpdateVisibility(backpackCount, bankCount)
end

local function RegisterBagEvent(eventName, bagId)
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Update)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, bagId)
end

local function RegisterEvents()
    if eventsRegistered then
        return
    end

    RegisterBagEvent(EVENT_BACKPACK, BAG_BACKPACK)
    RegisterBagEvent(EVENT_BANK, BAG_BANK)
    RegisterBagEvent(EVENT_SUBSCRIBER_BANK, BAG_SUBSCRIBER_BANK)

    EVENT_MANAGER:RegisterForEvent(EVENT_FULL_UPDATE, EVENT_INVENTORY_FULL_UPDATE, Update)
    EVENT_MANAGER:RegisterForEvent(EVENT_OPEN_BANK_NAME, EVENT_OPEN_BANK, Update)

    eventsRegistered = true
end

local function UnregisterEvents()
    if not eventsRegistered then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_BACKPACK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_SUBSCRIBER_BANK, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_FULL_UPDATE, EVENT_INVENTORY_FULL_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_OPEN_BANK_NAME, EVENT_OPEN_BANK)

    eventsRegistered = false
end

local function CreateWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("NowhereKeysWindow")
	window:SetHidden(true)

    window:SetDimensions(110, 104)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVariables.x, savedVariables.y)

    local background = WINDOW_MANAGER:CreateControl("NowhereKeysBackground", window, CT_BACKDROP)
    background:SetAnchorFill()
    background:SetCenterColor(0, 0, 0, 0.45)
    background:SetEdgeColor(0.35, 0.35, 0.35, 0.70)

    local keyIcon = WINDOW_MANAGER:CreateControl("NowhereKeysKeyIcon", window, CT_TEXTURE)
    keyIcon:SetDimensions(26, 26)
    keyIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 7)
    keyIcon:SetTexture(KEY_ICON)

    local headerLabel = WINDOW_MANAGER:CreateControl("NowhereKeysHeaderLabel", window, CT_LABEL)
    headerLabel:SetFont("ZoFontWinH4")
    headerLabel:SetText("Nowhere")
    headerLabel:SetColor(1, 1, 1, 1)
    headerLabel:SetAnchor(LEFT, keyIcon, RIGHT, 8, 0)

    local windowWidth = 10 + 26 + 8 + math.ceil(headerLabel:GetTextWidth()) + 16
    window:SetWidth(windowWidth)

    local divider = WINDOW_MANAGER:CreateControl("NowhereKeysDivider", window, CT_TEXTURE)
    divider:SetDimensions(windowWidth - 20, 1)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 39)
    divider:SetColor(0.7, 0.7, 0.7, 0.35)

    local inventoryIcon = WINDOW_MANAGER:CreateControl("NowhereKeysInventoryIcon", window, CT_TEXTURE)
    inventoryIcon:SetDimensions(22, 22)
    inventoryIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 48)
    inventoryIcon:SetTexture(BAG_ICON)

    inventoryCountLabel = WINDOW_MANAGER:CreateControl("NowhereKeysInventoryCount", window, CT_LABEL)
    inventoryCountLabel:SetFont("ZoFontGameBold")
    inventoryCountLabel:SetColor(1, 0.84, 0, 1)
    inventoryCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    inventoryCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    inventoryCountLabel:SetDimensions(35, 22)
    inventoryCountLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 48)

    local bankIcon = WINDOW_MANAGER:CreateControl("NowhereKeysBankIcon", window, CT_TEXTURE)
    bankIcon:SetDimensions(22, 22)
    bankIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 76)
    bankIcon:SetTexture(BANK_ICON)

    bankCountLabel = WINDOW_MANAGER:CreateControl("NowhereKeysBankCount", window, CT_LABEL)
    bankCountLabel:SetFont("ZoFontGameBold")
    bankCountLabel:SetColor(1, 0.84, 0, 1)
    bankCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    bankCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    bankCountLabel:SetDimensions(35, 22)
    bankCountLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 76)

    window:SetHandler("OnMoveStop", function(control)
        savedVariables.x = control:GetLeft()
        savedVariables.y = control:GetTop()
    end)

    hudFragment = ZO_HUDFadeSceneFragment:New(window)
    hudFragment:SetHiddenForReason("Disabled", true, 0, 0)

    HUD_SCENE:AddFragment(hudFragment)
    HUD_UI_SCENE:AddFragment(hudFragment)
end

local function Enable()
    RegisterEvents()
    Update()
    hudFragment:SetHiddenForReason("Disabled", false, 0, 0)
end

local function Disable()
    hudFragment:SetHiddenForReason("Disabled", true, 0, 0)
    UnregisterEvents()
end

local function Toggle()
    savedVariables.enabled = not savedVariables.enabled

    if savedVariables.enabled then
        Enable()
        --d("|cFFD700Nowhere Keys:|r Anzeige eingeschaltet.")
    else
        Disable()
        --d("|cFFD700Nowhere Keys:|r Anzeige ausgeschaltet.")
    end
end

local function Initialize()
    --soll auf EU und NA an der gleichen Position sein, wenns verschoben wird ;) (@Baertram)
	savedVariables = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, DEFAULTS)
	
    CreateWindow()

    SLASH_COMMANDS["/nowhere"] = Toggle
    SLASH_COMMANDS["/nk"] = Toggle

    if savedVariables.enabled then
        Enable()
    end
end

-----------------------------------------------------------------------------------------------
local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)