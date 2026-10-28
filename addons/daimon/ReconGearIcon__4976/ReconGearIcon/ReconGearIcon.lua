-- ReconGearIcon
-- Shows the game's own "Reconstructed" icon on reconstructed items in the
-- character window's equipment slots, and optionally on the item icons in the inventory.
-- Size, position, color and opacity can be changed in Settings > Addons > ReconGearIcon.

-- Local only: the addon has one file, no keybindings and no API for other addons.
local addon = {}
addon.name = "ReconGearIcon"
addon.displayName = "ReconGearIcon"
addon.version = "1.1"

local SV_NAME = "ReconGearIcon_SV"
local SV_VERSION = 1

-- The same texture the inventory uses for reconstructed items.
local ICON_TEXTURE = "EsoUI/Art/Inventory/inventory_trait_reconstruct_icon.dds"

-- Available positions. dirX/dirY tell which way the icon is pushed outwards from the
-- corner (-1 = left/up, 1 = right/down). The amount in pixels is set per place
-- (see PLACE_EQUIPMENT / PLACE_INVENTORY), so the icon covers less of the item icon.
local POSITIONS = {
    TOPLEFT     = { label = "Top left",     anchor = TOPLEFT,     dirX = -1, dirY = -1 },
    TOPRIGHT    = { label = "Top right",    anchor = TOPRIGHT,    dirX =  1, dirY = -1 },
    CENTER      = { label = "Center",       anchor = CENTER,      dirX =  0, dirY =  0 },
    BOTTOMLEFT  = { label = "Bottom left",  anchor = BOTTOMLEFT,  dirX = -1, dirY =  1 },
    BOTTOMRIGHT = { label = "Bottom right", anchor = BOTTOMRIGHT, dirX =  1, dirY =  1 },
}
-- Order of the positions in the settings dropdowns.
local POSITION_ORDER = { "TOPLEFT", "TOPRIGHT", "CENTER", "BOTTOMLEFT", "BOTTOMRIGHT" }

local MIN_SIZE, MAX_SIZE = 8, 40

-- Bottom right is the default, as other addons commonly use the top corners
-- of item slots for their own indicators.
-- Color is stored as separate r/g/b fields (0-1), default pure yellow.
-- Opacity is stored in percent (0-100). Color and opacity are shared by both places.
local DEFAULTS = {
    -- Equipment panel
    iconSize = 26,
    position = "BOTTOMRIGHT",
    -- Inventory
    showInInventory = false,
    invIconSize = 26,
    invPosition = "BOTTOMRIGHT",
    -- Shared
    colorR = 1,
    colorG = 1,
    colorB = 0,
    opacity = 60,
}

-- Where an icon is shown. Each place has its own size and position settings, and its
-- own outset: how many pixels the icon is pushed outwards from the corner
-- (a negative value moves it inwards).
local PLACE_EQUIPMENT = { sizeKey = "iconSize",    positionKey = "position",    outset = 3 }
local PLACE_INVENTORY = { sizeKey = "invIconSize", positionKey = "invPosition", outset = -2 }

-- Equipment slot id -> name suffix of the slot control (ZO_CharacterEquipmentSlots<suffix>).
local SLOT_CONTROLS = {
    [EQUIP_SLOT_HEAD]          = "Head",
    [EQUIP_SLOT_NECK]          = "Neck",
    [EQUIP_SLOT_CHEST]         = "Chest",
    [EQUIP_SLOT_SHOULDERS]     = "Shoulder",
    [EQUIP_SLOT_MAIN_HAND]     = "MainHand",
    [EQUIP_SLOT_OFF_HAND]      = "OffHand",
    [EQUIP_SLOT_WAIST]         = "Belt",
    [EQUIP_SLOT_LEGS]          = "Leg",
    [EQUIP_SLOT_FEET]          = "Foot",
    [EQUIP_SLOT_RING1]         = "Ring1",
    [EQUIP_SLOT_RING2]         = "Ring2",
    [EQUIP_SLOT_HAND]          = "Glove",
    [EQUIP_SLOT_BACKUP_MAIN]   = "BackupMain",
    [EQUIP_SLOT_BACKUP_OFF]    = "BackupOff",
}

-- When a two-handed weapon is equipped, the game shows a ghost image of it in the
-- off hand slot but does not fire "WornSlotUpdate" for that slot. So whenever a main
-- hand slot is updated, the matching off hand slot is updated too.
local LINKED_OFF_HAND = {
    [EQUIP_SLOT_MAIN_HAND]   = EQUIP_SLOT_OFF_HAND,
    [EQUIP_SLOT_BACKUP_MAIN] = EQUIP_SLOT_BACKUP_OFF,
}

-- Inventory types whose item rows get the icon. Reconstructed items are bound to the
-- account, so they can never be in the guild bank (or listed in a guild store), and the
-- furniture vault and craft bag can never contain gear.
local INVENTORY_TYPES = {
    INVENTORY_BACKPACK,
    INVENTORY_BANK,
    INVENTORY_HOUSE_BANK,
}

-- Parent control -> icon texture control, created on first use.
-- Each icon also stores icon.place (PLACE_EQUIPMENT or PLACE_INVENTORY) and
-- icon.anchorTarget (the control whose corners it is anchored to).
local icons = {}

-------------------------------------------------------------------------------
-- Icon handling (shared by the equipment panel and the inventory)
-------------------------------------------------------------------------------

-- Applies the current size, position, color and opacity settings to one icon.
local function ApplyLayout(icon)
    local sv = addon.sv
    local place = icon.place
    local size = sv[place.sizeKey]
    local pos = POSITIONS[sv[place.positionKey]]
    icon:SetDimensions(size, size)
    icon:ClearAnchors()
    icon:SetAnchor(pos.anchor, icon.anchorTarget, pos.anchor, pos.dirX * place.outset, pos.dirY * place.outset)
    icon:SetColor(sv.colorR, sv.colorG, sv.colorB, sv.opacity / 100)
end

-- Returns the icon of parent, creating it on first use. The icon is anchored to the
-- corners of anchorTarget (defaults to parent). If the anchor target has changed since
-- the last call, the icon is re-anchored.
local function GetOrCreateIcon(parent, place, anchorTarget)
    anchorTarget = anchorTarget or parent
    local icon = icons[parent]
    if icon then
        if icon.anchorTarget ~= anchorTarget then
            icon.anchorTarget = anchorTarget
            ApplyLayout(icon)
        end
    else
        icon = WINDOW_MANAGER:CreateControl(parent:GetName() .. "ReconGearIcon", parent, CT_TEXTURE)
        icon:SetTexture(ICON_TEXTURE)
        -- The original texture is dark gray, and SetColor multiplies the texture's pixels
        -- by the chosen color, so bright colors would look dark. Using the texture's alpha
        -- channel as its color turns the icon into a white silhouette, which the chosen
        -- color then tints at full brightness.
        icon:SetTextureSampleProcessingWeight(TEX_SAMPLE_PROCESSING_RGB, 0)
        icon:SetTextureSampleProcessingWeight(TEX_SAMPLE_PROCESSING_ALPHA_AS_RGB, 1)
        icon:SetDrawLayer(DL_OVERLAY)
        icon:SetMouseEnabled(false)
        icon:SetHidden(true)
        icon.place = place
        icon.anchorTarget = anchorTarget
        ApplyLayout(icon)
        icons[parent] = icon
    end
    return icon
end

-- Shows the icon on parent if the item is reconstructed, otherwise hides it.
-- The texture is only created when it is actually needed.
local function SetIconShown(parent, place, shown, anchorTarget)
    if shown then
        GetOrCreateIcon(parent, place, anchorTarget):SetHidden(false)
    elseif icons[parent] then
        icons[parent]:SetHidden(true)
    end
end

local function IsReconstructed(bagId, slotIndex)
    return GetItemTraitInformation(bagId, slotIndex) == ITEM_TRAIT_INFORMATION_RECONSTRUCTED
end

-- Re-applies the settings to all icons that already exist (after a settings change).
local function ApplyLayoutToAll()
    for _, icon in pairs(icons) do
        ApplyLayout(icon)
    end
end

-------------------------------------------------------------------------------
-- Equipment panel
-------------------------------------------------------------------------------

-- Slot id -> slot control, looked up once.
local slotControls = {}

local function GetSlotControl(slotIndex)
    local control = slotControls[slotIndex]
    if not control then
        control = GetControl("ZO_CharacterEquipmentSlots" .. SLOT_CONTROLS[slotIndex])
        slotControls[slotIndex] = control
    end
    return control
end

local function RefreshEquipmentIcon(slotControl)
    if not slotControl then return end
    SetIconShown(slotControl, PLACE_EQUIPMENT, IsReconstructed(BAG_WORN, slotControl.slotIndex))
end

-- "WornSlotUpdate" callback handler.
local function OnWornSlotUpdate(slotControl)
    if not slotControl or slotControl.bagId ~= BAG_WORN then return end
    local slotIndex = slotControl.slotIndex
    if not SLOT_CONTROLS[slotIndex] then return end

    RefreshEquipmentIcon(slotControl)

    local offHandIndex = LINKED_OFF_HAND[slotIndex]
    if offHandIndex then
        RefreshEquipmentIcon(GetSlotControl(offHandIndex))
    end
end

local function RefreshAllEquipmentIcons()
    for slotIndex in pairs(SLOT_CONTROLS) do
        RefreshEquipmentIcon(GetSlotControl(slotIndex))
    end
end

-------------------------------------------------------------------------------
-- Inventory
-------------------------------------------------------------------------------

-- Hides the game's own Reconstructed icon on a row, so it is not shown twice:
--   TraitInfo:       the trait information icon (normally next to the price; grid view
--                    addons may move it on top of the item icon)
--   SellInformation: the same information, shown instead of TraitInfo at vendors
-- The game sets both up again every time the row is set up, so nothing needs to be restored.
local function HideDefaultIcon(rowControl)
    local traitInfo = rowControl:GetNamedChild("TraitInfo")
    if traitInfo and traitInfo.ClearIcons then
        traitInfo:ClearIcons()
    end
    local sellInformation = rowControl:GetNamedChild("SellInformation")
    if sellInformation then
        sellInformation:SetHidden(true)
    end
end

-- Returns the control whose corners the inventory icon is anchored to.
-- A normal inventory row is wide (509 x 52), so the icon is anchored to the item icon.
-- Grid view addons (e.g. GridList) turn each row into a square cell with the item icon
-- in the middle and allow changing the item icon's size. There the icon is anchored to
-- the cell, so it stays in the cell's corner whatever the item icon size is.
local function GetInventoryAnchorTarget(rowControl, button)
    local width, height = rowControl:GetDimensions()
    if height > 0 and width < height * 2 then
        return rowControl
    end
    return button
end

-- Runs after the game has set up an inventory row. Rows are reused while
-- scrolling, so the icon is hidden again on rows without a reconstructed item.
-- The icon is a child of the row (not of the item icon), so mouse-over scaling of
-- the item icon by grid view addons does not resize it.
local function OnInventoryRowSetup(rowControl, slot)
    local shown = false
    if addon.sv.showInInventory and slot and slot.bagId and slot.slotIndex then
        local traitInformation = slot.traitInformation or GetItemTraitInformation(slot.bagId, slot.slotIndex)
        shown = traitInformation == ITEM_TRAIT_INFORMATION_RECONSTRUCTED
    end

    if not shown then
        -- Most rows: only hide the icon if this row has one (no work when the option is off).
        SetIconShown(rowControl, PLACE_INVENTORY, false)
        return
    end

    local button = rowControl:GetNamedChild("Button")
    if not button then return end
    SetIconShown(rowControl, PLACE_INVENTORY, true, GetInventoryAnchorTarget(rowControl, button))
    HideDefaultIcon(rowControl)
end

local function HookInventoryLists()
    for _, inventoryType in ipairs(INVENTORY_TYPES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        if inventory and inventory.listView then
            local dataType = ZO_ScrollList_GetDataTypeTable(inventory.listView, inventory.listDataType)
            if dataType and dataType.setupCallback then
                SecurePostHook(dataType, "setupCallback", OnInventoryRowSetup)
            end
        end
    end
end

-- Re-runs the row setup for the visible inventory rows (e.g. after the option was turned on or off).
-- Only lists that are currently shown are refreshed right away. Hidden lists (e.g. the
-- house storage when not in a house, or the bank when not at a banker) are marked dirty
-- instead; the game rebuilds a dirty list itself when it is shown the next time.
local function RefreshInventoryLists()
    for _, inventoryType in ipairs(INVENTORY_TYPES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        local listView = inventory and inventory.listView
        if listView then
            if listView:IsHidden() then
                PLAYER_INVENTORY.isListDirty[inventoryType] = true
            else
                ZO_ScrollList_RefreshVisible(listView)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local function CreateSettingsMenu()
    local LAM = LibAddonMenu2
    local sv = addon.sv

    local panelData = {
        type = "panel",
        name = addon.displayName,
        author = "daimon (Claude AI)",
        version = addon.version,
        slashCommand = "/recongearicon",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(addon.name .. "Options", panelData)

    local positionChoices, positionValues = {}, {}
    for i, key in ipairs(POSITION_ORDER) do
        positionChoices[i] = POSITIONS[key].label
        positionValues[i] = key
    end

    local function InventoryDisabled()
        return not sv.showInInventory
    end

    local optionsTable = {
        {
            type = "description",
            text = "Shows the Reconstructed icon on reconstructed items in the character equipment panel, and optionally in the inventory.",
        },
        {
            type = "header",
            name = "Equipment panel",
        },
        {
            type = "slider",
            name = "Icon size",
            tooltip = "Size of the icon in pixels. The equipment slot itself is 44 pixels.",
            min = MIN_SIZE,
            max = MAX_SIZE,
            step = 1,
            getFunc = function() return sv.iconSize end,
            setFunc = function(value)
                sv.iconSize = value
                ApplyLayoutToAll()
            end,
            default = DEFAULTS.iconSize,
        },
        {
            type = "dropdown",
            name = "Icon position",
            tooltip = "Where the icon is shown on the equipment slot.",
            choices = positionChoices,
            choicesValues = positionValues,
            getFunc = function() return sv.position end,
            setFunc = function(value)
                sv.position = value
                ApplyLayoutToAll()
            end,
            default = DEFAULTS.position,
        },
        {
            type = "header",
            name = "Inventory",
        },
        {
            type = "checkbox",
            name = "Show icon in inventory",
            tooltip = "Replace the original Reconstructed icon in your inventory to retain the same style.",
            getFunc = function() return sv.showInInventory end,
            setFunc = function(value)
                sv.showInInventory = value
                RefreshInventoryLists()
            end,
            default = DEFAULTS.showInInventory,
        },
        {
            type = "slider",
            name = "Icon size",
            tooltip = "Size of the icon in pixels. The inventory item icon itself is 40 pixels.",
            min = MIN_SIZE,
            max = MAX_SIZE,
            step = 1,
            getFunc = function() return sv.invIconSize end,
            setFunc = function(value)
                sv.invIconSize = value
                ApplyLayoutToAll()
            end,
            disabled = InventoryDisabled,
            default = DEFAULTS.invIconSize,
        },
        {
            type = "dropdown",
            name = "Icon position",
            tooltip = "Where the icon is shown on the inventory item icon.",
            choices = positionChoices,
            choicesValues = positionValues,
            getFunc = function() return sv.invPosition end,
            setFunc = function(value)
                sv.invPosition = value
                ApplyLayoutToAll()
            end,
            disabled = InventoryDisabled,
            default = DEFAULTS.invPosition,
        },
        {
            type = "header",
            name = "Appearance",
        },
        {
            type = "colorpicker",
            name = "Icon color",
            tooltip = "Color of the icon.",
            getFunc = function() return sv.colorR, sv.colorG, sv.colorB end,
            setFunc = function(r, g, b)
                sv.colorR, sv.colorG, sv.colorB = r, g, b
                ApplyLayoutToAll()
            end,
            default = { r = DEFAULTS.colorR, g = DEFAULTS.colorG, b = DEFAULTS.colorB },
        },
        {
            type = "slider",
            name = "Icon opacity (%)",
            tooltip = "100 = fully visible, 0 = invisible.",
            min = 0,
            max = 100,
            step = 5,
            getFunc = function() return sv.opacity end,
            setFunc = function(value)
                sv.opacity = value
                ApplyLayoutToAll()
            end,
            default = DEFAULTS.opacity,
        },
    }
    LAM:RegisterOptionControls(addon.name .. "Options", optionsTable)
end

-- Returns value if it is a number within min..max, otherwise the default value.
local function ValidNumber(value, min, max, default)
    if type(value) ~= "number" then return default end
    return zo_clamp(value, min, max)
end

-- Fall back to defaults if the saved values are invalid (e.g. edited by hand).
local function ValidateSettings(sv)
    if not POSITIONS[sv.position] then sv.position = DEFAULTS.position end
    if not POSITIONS[sv.invPosition] then sv.invPosition = DEFAULTS.invPosition end
    sv.showInInventory = sv.showInInventory == true
    sv.iconSize    = ValidNumber(sv.iconSize, MIN_SIZE, MAX_SIZE, DEFAULTS.iconSize)
    sv.invIconSize = ValidNumber(sv.invIconSize, MIN_SIZE, MAX_SIZE, DEFAULTS.invIconSize)
    sv.colorR      = ValidNumber(sv.colorR, 0, 1, DEFAULTS.colorR)
    sv.colorG      = ValidNumber(sv.colorG, 0, 1, DEFAULTS.colorG)
    sv.colorB      = ValidNumber(sv.colorB, 0, 1, DEFAULTS.colorB)
    sv.opacity     = ValidNumber(sv.opacity, 0, 100, DEFAULTS.opacity)
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Account-wide settings, saved separately for each server (EU, NA, PTS): the server name
-- is used as the ZO_SavedVars profile.
-- Version 1.0 saved the settings without the server ("Default" profile). They are copied
-- to the current server the first time, and the old entry is removed.
local function LoadSettings()
    local worldName = GetWorldName()
    local displayName = GetDisplayName()
    local raw = _G[SV_NAME]
    local hasServerSettings = raw and raw[worldName] and raw[worldName][displayName] ~= nil
    local oldProfile = raw and raw["Default"]
    local oldSettings = oldProfile and oldProfile[displayName] and oldProfile[displayName]["$AccountWide"]

    local sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, DEFAULTS, worldName)

    if oldSettings then
        if not hasServerSettings then
            for key in pairs(DEFAULTS) do
                if oldSettings[key] ~= nil then
                    sv[key] = oldSettings[key]
                end
            end
        end
        oldProfile[displayName] = nil
        if next(oldProfile) == nil then
            raw["Default"] = nil
        end
    end
    return sv
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon.sv = LoadSettings()
    ValidateSettings(addon.sv)

    CreateSettingsMenu()

    -- The character window fires this callback every time an equipment slot is refreshed
    -- (item equipped, removed, swapped etc.).
    CALLBACK_MANAGER:RegisterCallback("WornSlotUpdate", OnWornSlotUpdate)

    HookInventoryLists()

    -- Initial state after login / reloadui.
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED)
        RefreshAllEquipmentIcons()
    end)
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
