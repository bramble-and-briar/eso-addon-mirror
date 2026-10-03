local ADDON_NAME = "NowhereKeys"
local SAVED_VARS_NAME = "NowhereKeysSavedVariables"
local SAVED_VARS_VERSION = 1

local ITEM_ID = 224302

local KEY_ICON  = "/esoui/art/icons/housing_uni_inc_nowherekey001.dds"
local BAG_ICON  = "/esoui/art/tooltips/icon_bag.dds"
local BANK_ICON = "/esoui/art/tooltips/icon_bank.dds"

local DEFAULTS = {x = 500, y = 300, enabled = true,}

-- Lokale Variablen
local savedVariables
local window
local hudFragment
local inventoryCountLabel
local bankCountLabel

-- Item in einer Tasche zählen
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

-- Schlüsselstände holen
local function GetCounts()
    local backpackCount = GetCountFromBag(BAG_BACKPACK)
    local bankCount = GetCountFromBag(BAG_BANK) + GetCountFromBag(BAG_SUBSCRIBER_BANK)
    return backpackCount, bankCount
end

-- Sichtbarkeit setzen
local function UpdateVisibility(backpackCount, bankCount)
    if not window then return end
    local hasKeys = (backpackCount + bankCount) > 0
    local hudVisible = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")

    local shouldShow = savedVariables.enabled and hasKeys and hudVisible
    window:SetHidden(not shouldShow)
end

-- Anzeige aktualisieren
local function Update()
    if not window then return end
    local backpackCount, bankCount = GetCounts()

    inventoryCountLabel:SetText(tostring(backpackCount))
    bankCountLabel:SetText(tostring(bankCount))

    UpdateVisibility(backpackCount, bankCount)
end

-- Fenster erstellen
local function CreateWindow()
    window = WINDOW_MANAGER:CreateTopLevelWindow("NowhereKeysWindow")

    window:SetDimensions(110, 104)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)

    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVariables.x, savedVariables.y)

    -- Hintergrund
    local background = WINDOW_MANAGER:CreateControl("NowhereKeysBackground", window, CT_BACKDROP)
    background:SetAnchorFill()
    background:SetCenterColor(0, 0, 0, 0.45)
    background:SetEdgeColor(0.35, 0.35, 0.35, 0.70)

    -- Header: Schlüssel-Icon
    local keyIcon = WINDOW_MANAGER:CreateControl("NowhereKeysKeyIcon", window, CT_TEXTURE)
    keyIcon:SetDimensions(26, 26)
    keyIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 7)
    keyIcon:SetTexture(KEY_ICON)

    -- Header: Nowhere
    local headerLabel = WINDOW_MANAGER:CreateControl("NowhereKeysHeaderLabel", window, CT_LABEL)
    headerLabel:SetFont("ZoFontWinH4")
    headerLabel:SetText("Nowhere")
    headerLabel:SetColor(1, 1, 1, 1)
    headerLabel:SetAnchor(LEFT, keyIcon, RIGHT, 8, 0)

    -- Fensterbreite automatisch an Header anpassen
    local windowWidth = 10 + 26 + 8 + math.ceil(headerLabel:GetTextWidth()) + 16
    window:SetWidth(windowWidth)

    -- Trennlinie
    local divider = WINDOW_MANAGER:CreateControl("NowhereKeysDivider", window, CT_TEXTURE)
    divider:SetDimensions(windowWidth - 20, 1)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 39)
    divider:SetColor(0.7, 0.7, 0.7, 0.35)

    -- Inventar-Icon
    local inventoryIcon = WINDOW_MANAGER:CreateControl("NowhereKeysInventoryIcon", window, CT_TEXTURE)
    inventoryIcon:SetDimensions(22, 22)
    inventoryIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 48)
    inventoryIcon:SetTexture(BAG_ICON)

    -- Inventar-Anzahl
    inventoryCountLabel = WINDOW_MANAGER:CreateControl("NowhereKeysInventoryCount", window, CT_LABEL)
    inventoryCountLabel:SetFont("ZoFontGameBold")
    inventoryCountLabel:SetColor(1, 0.84, 0, 1)
    inventoryCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    inventoryCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    inventoryCountLabel:SetDimensions(35, 22)
    inventoryCountLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 48)

    -- Bank-Icon
    local bankIcon = WINDOW_MANAGER:CreateControl("NowhereKeysBankIcon", window, CT_TEXTURE)
    bankIcon:SetDimensions(22, 22)
    bankIcon:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 76)
    bankIcon:SetTexture(BANK_ICON)

    -- Bank-Anzahl
    bankCountLabel = WINDOW_MANAGER:CreateControl("NowhereKeysBankCount", window, CT_LABEL)
    bankCountLabel:SetFont("ZoFontGameBold")
    bankCountLabel:SetColor(1, 0.84, 0, 1)
    bankCountLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    bankCountLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    bankCountLabel:SetDimensions(35, 22)
    bankCountLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 76)

    -- Position speichern
    window:SetHandler("OnMoveStop", function(control) savedVariables.x = control:GetLeft() savedVariables.y = control:GetTop() end)

    -- HUD / HUDUI
    hudFragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(hudFragment)
    HUD_UI_SCENE:AddFragment(hudFragment)

    hudFragment:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWN then Update() end
    end)
end

-- Manuell ein-/ausschalten
local function Toggle()
    savedVariables.enabled = not savedVariables.enabled

    if savedVariables.enabled then
        d("|cFFD700Nowhere Keys:|r Window shown.")
    else
        d("|cFFD700Nowhere Keys:|r Window hidden.")
    end
    Update()
end

-- Gefiltertes Inventory-Event registrieren
local function RegisterBagEvent(eventName, bagId)
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Update)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, bagId)
end

-- Initialisierung
local function Initialize()
    savedVariables = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, DEFAULTS)
    CreateWindow()
	
    RegisterBagEvent(ADDON_NAME .. "_Backpack", BAG_BACKPACK)
    RegisterBagEvent(ADDON_NAME .. "_Bank", BAG_BANK)
    RegisterBagEvent(ADDON_NAME .. "_SubscriberBank", BAG_SUBSCRIBER_BANK)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_FullUpdate", EVENT_INVENTORY_FULL_UPDATE, Update)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_OpenBank", EVENT_OPEN_BANK, Update)

    SLASH_COMMANDS["/nowhere"] = Toggle
    SLASH_COMMANDS["/nk"] = Toggle

    Update()
end

-- Addon geladen
local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)