-- =============================================================================
-- Ability Icons Framework (AIF) - Heroism Potions Visual Overhaul
-- =============================================================================
-- Gives crafted Heroism potions distinct, glowing purple icons and colorized tooltips.
--
-- Why this exists:
-- Because accidentally chugging a 5,000-gold crafted Heroism potion in a random
-- normal dungeon when you just wanted a cheap 5-gold trash Magicka pot hurts deep
-- inside your soul, your wallet, and your raid leader's sanity.
--
-- By default in ESO, crafted Heroism potions share the exact same generic blue bottle
-- art as baseline Magicka potions. This subsystem hooks inventory slots, tooltips,
-- quickslots, and guild stores to give them the distinct royal purple look they deserve.
-- =============================================================================

--- @class (partial) AbilityIconsFramework
AbilityIconsFramework = AbilityIconsFramework or {}
local AbilityIconsFramework = AbilityIconsFramework

local pairs                            = pairs
local ipairs                           = ipairs
local tonumber                         = tonumber
local tostring                         = tostring
local zo_strformat                     = zo_strformat
local GetString                        = GetString
local GetItemLink                      = GetItemLink
local GetSlotItemLink                  = GetSlotItemLink
local GetItemLinkItemId                = GetItemLinkItemId
local GetItemLinkRequiredLevel         = GetItemLinkRequiredLevel
local GetItemLinkRequiredChampionPoints = GetItemLinkRequiredChampionPoints
local ZO_ClearTable                    = ZO_ClearTable

--------------------------------------------------------------------------------
-- Heroism Potions Configuration & State
--------------------------------------------------------------------------------

AbilityIconsFramework.HEROISM_POTIONS = {
    -- Heroism potions in ESO strictly use one of two base item IDs:
    potionItemIds = {
        [54340] = true, -- All Magicka-based Heroism Potions
        [54341] = true, -- All Stamina-based Heroism Potions
    },
    -- Internal alchemy effect IDs identifying the Minor Heroism trait:
    potionEffects = {
        [197919] = true, -- Tri-Restoration / Restore Magicka + Restore Stamina + Minor Heroism
        [335616] = true, -- Restore Stamina + Minor Heroism
    },
    potions = {},
    isStationInteract = false, -- True while interacting with an Alchemy crafting station
    tooltipColor = "B066FF",   -- Distinctive royal purple hue for Heroism
}

-- Fast lookup cache for itemLink -> potionData (or false if verified regular potion)
local linkHeroismCache = {}

--- Helper to construct a localized potion metadata record with purple markup.
--- @param stringId number Localization string identifier.
--- @param iconPath string High-resolution texture asset path.
--- @return table entry Record containing uncolored name, colored markup, and icon.
local function CreatePotionEntry(stringId, iconPath)
    local name = GetString(stringId)
    return {
        name = name,
        coloredName = "|cB066FF" .. name .. "|r",
        icon = iconPath,
    }
end

--- Rebuilds localized potion names and clears the itemLink cache.
--- Invoked during startup and when language preferences change.
function AbilityIconsFramework.InitializePotionNames()
    AbilityIconsFramework.HEROISM_POTIONS.potions = {
        [3]   = CreatePotionEntry(HP_POTION_NAME_3, "/AbilityIconsFramework/HeroismPotions/potion_type_001.dds"),
        [10]  = CreatePotionEntry(HP_POTION_NAME_10, "/AbilityIconsFramework/HeroismPotions/potion_type_001.dds"),
        [20]  = CreatePotionEntry(HP_POTION_NAME_20, "/AbilityIconsFramework/HeroismPotions/potion_type_002.dds"),
        [30]  = CreatePotionEntry(HP_POTION_NAME_30, "/AbilityIconsFramework/HeroismPotions/potion_type_003.dds"),
        [40]  = CreatePotionEntry(HP_POTION_NAME_40, "/AbilityIconsFramework/HeroismPotions/potion_type_004.dds"),
        [60]  = CreatePotionEntry(HP_POTION_NAME_CP10, "/AbilityIconsFramework/HeroismPotions/potion_type_005.dds"),
        [100] = CreatePotionEntry(HP_POTION_NAME_CP50, "/AbilityIconsFramework/HeroismPotions/potion_type_005.dds"),
        [150] = CreatePotionEntry(HP_POTION_NAME_CP100, "/AbilityIconsFramework/HeroismPotions/potion_type_005.dds"),
        [200] = CreatePotionEntry(HP_POTION_NAME_CP150, "/AbilityIconsFramework/HeroismPotions/potion_type_005.dds"),
        [210] = CreatePotionEntry(HP_POTION_NAME_CP150, "/AbilityIconsFramework/HeroismPotions/potion_type_005.dds"),
    }
    ZO_ClearTable(linkHeroismCache)
end

--------------------------------------------------------------------------------
-- ItemLink Parsing & Fast Identification Filter
--------------------------------------------------------------------------------

--- Extracts the 21st parameter from an ESO itemLink string.
---
--- In ESO's internal item link protocol (|H0:item:id:...|h), the 21st parameter
--- encodes the specific alchemy effect signature. Rather than allocating table splits,
--- we extract it with zero runtime allocations via pattern matching directly before |h.
---
--- @param itemLink string The full ESO item link string.
--- @return number effectId The extracted potion effect ID, or 0.
function AbilityIconsFramework.GetPotionEffectFromItemLink(itemLink)
    if not itemLink or itemLink == "" then return 0 end
    return tonumber(itemLink:match(":(%d+)|h")) or 0
end

--- Two-stage fast filter to verify whether an item is a crafted Heroism potion.
---
--- STAGE 1: Item ID Filter (Instant O(1) bail-out)
---   Heroism potions strictly use Item IDs 54340 or 54341. 99.9% of all items
---   (weapons, armor, materials, trash pots) are rejected immediately without cache overhead.
---
--- STAGE 2: Alchemy Trait Verification
---   Inspects the 21st field to confirm presence of the Minor Heroism trait (197919 / 335616).
---
--- @param itemLink string The item link to inspect.
--- @return table? potion Potion metadata record, or nil if not a Heroism potion.
function AbilityIconsFramework.FindPotion(itemLink)
    if not itemLink or itemLink == "" then return nil end

    -- Fast bail-out: Heroism potions ONLY use Item IDs 54340 and 54341.
    -- Non-potion items are immediately rejected with zero cache overhead.
    local itemId = GetItemLinkItemId(itemLink)
    if not AbilityIconsFramework.HEROISM_POTIONS.potionItemIds[itemId] then
        return nil
    end

    local cached = linkHeroismCache[itemLink]
    if cached ~= nil then
        return cached or nil
    end

    local effect = AbilityIconsFramework.GetPotionEffectFromItemLink(itemLink)
    if not AbilityIconsFramework.HEROISM_POTIONS.potionEffects[effect] then
        linkHeroismCache[itemLink] = false
        return nil
    end

    local combinedLevel = (GetItemLinkRequiredLevel(itemLink) + GetItemLinkRequiredChampionPoints(itemLink))
    local potion = AbilityIconsFramework.HEROISM_POTIONS.potions[combinedLevel]
    if not potion and combinedLevel >= 150 then
        potion = AbilityIconsFramework.HEROISM_POTIONS.potions[200]
    end

    linkHeroismCache[itemLink] = potion or false
    return potion
end

--- Local helper returning active potion metadata if enabled and not at an Alchemy table.
--- @param itemLink string
--- @return table? potion
local function GetActivePotion(itemLink)
    if not itemLink or itemLink == "" then return nil end
    if AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then return nil end
    local settings = AbilityIconsFramework.GetSettings()
    if not (settings and settings.enableHeroismPotionIcons) then return nil end

    return AbilityIconsFramework.FindPotion(itemLink)
end

--- Retrieves the uncolored display name for a Heroism potion.
--- @param itemLink string
--- @return string? name
function AbilityIconsFramework.GetPotionName(itemLink)
    local potion = AbilityIconsFramework.FindPotion(itemLink)
    return potion and potion.name
end

--- Retrieves the custom purple texture asset path for a Heroism potion.
--- @param itemLink string
--- @return string? icon
function AbilityIconsFramework.GetPotionIcon(itemLink)
    local potion = AbilityIconsFramework.FindPotion(itemLink)
    return potion and potion.icon
end

--- Checks if an item qualifies for the Heroism visual override.
--- Returns false at alchemy tables so crafting station UIs remain completely vanilla.
--- @param itemLink string
--- @return boolean shouldReplace
function AbilityIconsFramework.ShouldReplacePotion(itemLink)
    return GetActivePotion(itemLink) ~= nil
end

--------------------------------------------------------------------------------
-- Tooltip Title Overlays & Interceptors
--------------------------------------------------------------------------------

local HEROISM_TOOLTIP_COLOR = ZO_ColorDef:New("B066FF")
local heroismTitleStyle = {
    fontColor = HEROISM_TOOLTIP_COLOR,
}

local tooltipFunctions = {
    ["SetBagItem"]             = GetItemLink,
    ["SetTradeItem"]           = GetTradeItemLink,
    ["SetBuybackItem"]         = GetBuybackItemLink,
    ["SetStoreItem"]           = GetStoreItemLink,
    ["SetAttachedMailItem"]    = GetAttachedItemLink,
    ["SetLootItem"]            = GetLootItemLink,
    ["SetTradingHouseItem"]    = GetTradingHouseSearchResultItemLink,
    ["SetTradingHouseListing"] = GetTradingHouseListingItemLink,
    ["SetWornItem"]            = function(slotIndex, bagId) return GetItemLink(bagId or BAG_WORN, slotIndex) end,
    ["SetAction"]              = function(slotIndex, hotbarCategory) return GetSlotItemLink(slotIndex, hotbarCategory) end,
}

local function ReturnItemLink(itemLink)
    return itemLink
end

local titleOverlays = {}

--- Hides any active Heroism title overlay on the given tooltip control.
--- @param tooltipControl any The tooltip window control.
local function HideTitleOverlay(tooltipControl)
    if not tooltipControl then return end
    local overlay = titleOverlays[tooltipControl]
    if overlay and overlay.backdrop then
        overlay.backdrop:SetHidden(true)
    end
end

--- Retrieves or creates a custom overlay backdrop and label on Keyboard tooltips
--- to visually replace the C++ native title with our purple "Essence of Heroism".
--- @param tooltipControl any The tooltip window control.
--- @return table? overlayData Backdrop and label controls.
local function GetOrCreateTitleOverlay(tooltipControl)
    if not tooltipControl then return nil end
    local name = tooltipControl.GetName and tooltipControl:GetName()
    if not name or name == "" then return nil end

    if titleOverlays[tooltipControl] then
        return titleOverlays[tooltipControl]
    end

    local overlayName = name .. "_HeroismTitleOverlay"
    local overlay = _G[overlayName] or WINDOW_MANAGER:CreateControl(overlayName, tooltipControl, CT_BACKDROP)
    if not overlay then return nil end

    if overlay.SetTier and tooltipControl.GetTier then
        overlay:SetTier(tooltipControl:GetTier())
    end
    if overlay.SetDrawLayer then
        overlay:SetDrawLayer(DL_OVERLAY)
    end
    if overlay.SetDrawLevel then
        overlay:SetDrawLevel(100)
    end
    overlay:SetCenterColor(0, 0, 0, 1)
    overlay:SetEdgeColor(0, 0, 0, 0)
    overlay:SetEdgeTexture("", 1, 1, 0)

    -- Anchor to cover the exact title band where ESSENCE OF MAGICKA renders (center Y = 99)
    overlay:ClearAnchors()
    overlay:SetAnchor(TOPLEFT, tooltipControl, TOPLEFT, 16, 36)
    overlay:SetAnchor(TOPRIGHT, tooltipControl, TOPRIGHT, -16, 36)
    overlay:SetHeight(32)

    local labelName = overlayName .. "_Label"
    local label = _G[labelName] or WINDOW_MANAGER:CreateControl(labelName, overlay, CT_LABEL)
    label:SetAnchorFill()
    label:SetFont("ZoFontHeader3")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if label.SetDrawLayer then
        label:SetDrawLayer(DL_OVERLAY)
    end
    if label.SetDrawLevel then
        label:SetDrawLevel(101)
    end
    label:SetColor(176 / 255, 102 / 255, 255 / 255, 1)

    local data = {
        backdrop = overlay,
        label = label,
    }
    titleOverlays[tooltipControl] = data
    return data
end

--- Updates the title label overlay within a tooltip to display the custom Heroism title in purple.
--- Zero DOM crawling, zero regex matching over child controls.
--- @param tooltipControl any Tooltip window.
--- @param potion table Potion metadata.
local function UpdateTooltipTitle(tooltipControl, potion)
    if not tooltipControl or not potion then return end

    local newTitle = (potion.name or "Essence of Heroism"):upper()
    local coloredTitle = "|cB066FF" .. newTitle .. "|r"
    local r, g, b, a = 176 / 255, 102 / 255, 255 / 255, 1

    local overlay = GetOrCreateTitleOverlay(tooltipControl)
    if overlay then
        overlay.backdrop:ClearAnchors()
        overlay.backdrop:SetAnchor(TOPLEFT, tooltipControl, TOPLEFT, 16, 36)
        overlay.backdrop:SetAnchor(TOPRIGHT, tooltipControl, TOPRIGHT, -16, 36)
        overlay.backdrop:SetHeight(32)
        overlay.label:SetText(coloredTitle)
        overlay.label:SetColor(r, g, b, a)
        overlay.backdrop:SetHidden(false)
    end
end

--- Intercepts tooltips across inventories, stores, trading houses, and links to update icon and title.
local function TooltipHook(tooltipControl, method, linkFunc)
    if not tooltipControl then return end
    local hookKey = "_aifHooked_" .. tostring(method)
    if tooltipControl[hookKey] then return end
    local origMethod = tooltipControl[method]
    if not origMethod then return end
    tooltipControl[hookKey] = true

    tooltipControl[method] = function(self, ...)
        origMethod(self, ...)

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            HideTitleOverlay(self)
            return
        end

        local link = linkFunc(...)
        local potion = GetActivePotion(link)
        if potion then
            if potion.icon then
                ZO_ItemIconTooltip_OnAddGameData(self, TOOLTIP_GAME_DATA_ITEM_ICON, potion.icon)
            end
            UpdateTooltipTitle(self, potion)
        else
            HideTitleOverlay(self)
        end
    end
end

--- Hooks tooltip controllers across Keyboard and Gamepad interfaces.
local function InitializeTooltipHooks()
    -- Gamepad tooltips: hook AddItemTitle to apply royal purple text style
    if ZO_Tooltip and ZO_Tooltip.AddItemTitle and not ZO_Tooltip._aifAddItemTitleHooked then
        ZO_Tooltip._aifAddItemTitleHooked = true
        local origAddItemTitle = ZO_Tooltip.AddItemTitle
        ZO_Tooltip.AddItemTitle = function(self, itemLink, name)
            local settings = AbilityIconsFramework.GetSettings()
            if settings and settings.enableHeroismPotionIcons and not AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
                local potion = AbilityIconsFramework.FindPotion(itemLink)
                if potion then
                    local potionName = potion.name or GetItemLinkName(itemLink)
                    local titleStyle = (self.GetStyle and self:GetStyle("title")) or {}
                    self:AddLine(zo_strformat(SI_TOOLTIP_ITEM_NAME, potionName), heroismTitleStyle, titleStyle)
                    if potion.icon and self.AddGameData then
                        ZO_ItemIconTooltip_OnAddGameData(self, TOOLTIP_GAME_DATA_ITEM_ICON, potion.icon)
                    end
                    return
                end
            end
            return origAddItemTitle(self, itemLink, name)
        end
    end

    -- Universal tooltip layout hook
    if ZO_Tooltip and ZO_Tooltip.LayoutItem and not ZO_Tooltip._aifLayoutItemHooked then
        ZO_Tooltip._aifLayoutItemHooked = true
        SecurePostHook(ZO_Tooltip, "LayoutItem", function(self, itemLink)
            local settings = AbilityIconsFramework.GetSettings()
            if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
                HideTitleOverlay(self)
                return
            end
            local potion = GetActivePotion(itemLink)
            if potion then
                if potion.icon and self.AddGameData then
                    ZO_ItemIconTooltip_OnAddGameData(self, TOOLTIP_GAME_DATA_ITEM_ICON, potion.icon)
                end
                UpdateTooltipTitle(self, potion)
            else
                HideTitleOverlay(self)
            end
        end)
    end

    if ZO_ItemTooltip_Cleared then
        SecurePostHook("ZO_ItemTooltip_Cleared", function(control)
            HideTitleOverlay(control)
        end)
    end

    -- Keyboard item and comparative tooltips
    local tooltipsToHook = {
        ItemTooltip,
        PopupTooltip,
        ComparativeTooltip1,
        ComparativeTooltip2,
    }

    for _, tt in ipairs(tooltipsToHook) do
        if tt then
            for method, linkFunc in pairs(tooltipFunctions) do
                TooltipHook(tt, method, linkFunc)
            end
            TooltipHook(tt, "SetLink", ReturnItemLink)

            -- Automatically hide overlay when tooltip clears or hides
            ZO_PreHookHandler(tt, "OnCleared", HideTitleOverlay)
            ZO_PreHookHandler(tt, "OnHide", HideTitleOverlay)
        end
    end
end

--------------------------------------------------------------------------------
-- Slot Data & Inventory Overrides (With Safe State Restoration)
--------------------------------------------------------------------------------

--- Mutates or restores SHARED_INVENTORY slotData records for Heroism potions.
---
--- SAFE RESTORATION ARCHITECTURE:
---   When first mutating a slot, we save the vanilla values on the slotData:
---     slotData._aifOrigIcon    = slotData.iconFile
---     slotData._aifOrigName    = slotData.name
---     slotData._aifOrigRawName = slotData.rawName
---   If the player disables Heroism Potion icons in settings OR steps up to an
---   Alchemy crafting station, we cleanly restore the original vanilla strings!
---
--- @param slotData table The SHARED_INVENTORY slot record.
--- @param bagId number Bag identifier.
--- @param slotIndex number Slot index within the bag.
local function ApplyPotionOverrides(slotData, bagId, slotIndex)
    if not slotData then return end
    local itemLink = slotData.itemLink or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
    local potion = AbilityIconsFramework.FindPotion(itemLink)
    if not potion then return end

    -- Store original vanilla values when first mutating
    if not slotData._aifOrigIcon then
        slotData._aifOrigIcon = slotData.iconFile
        slotData._aifOrigName = slotData.name
        slotData._aifOrigRawName = slotData.rawName
    end

    local settings = AbilityIconsFramework.GetSettings()
    local isEnabled = settings and settings.enableHeroismPotionIcons and not AbilityIconsFramework.HEROISM_POTIONS.isStationInteract

    if isEnabled then
        if potion.icon then
            slotData.iconFile = potion.icon
        end
        if potion.coloredName then
            slotData.name = potion.coloredName
        end
        if potion.name then
            slotData.rawName = potion.name
        end
    else
        -- Restore original values when disabled or at crafting stations
        if slotData._aifOrigIcon then
            slotData.iconFile = slotData._aifOrigIcon
            slotData.name = slotData._aifOrigName
            slotData.rawName = slotData._aifOrigRawName
        end
    end
end

local isRefreshingInventory = false

--- Refreshes SHARED_INVENTORY's cached bag slots across all bags and redraws inventory views.
function AbilityIconsFramework.RefreshInventoryHeroismPotions()
    if isRefreshingInventory then return end
    isRefreshingInventory = true

    if SHARED_INVENTORY then
        local bags = {
            BAG_BACKPACK,
            BAG_BANK,
            BAG_SUBSCRIBER_BANK,
            BAG_VIRTUAL,
            BAG_HOUSE_BANK_ONE,
            BAG_HOUSE_BANK_TWO,
            BAG_HOUSE_BANK_THREE,
            BAG_HOUSE_BANK_FOUR,
            BAG_HOUSE_BANK_FIVE,
            BAG_HOUSE_BANK_SIX,
            BAG_HOUSE_BANK_SEVEN,
            BAG_HOUSE_BANK_EIGHT,
            BAG_HOUSE_BANK_NINE,
            BAG_HOUSE_BANK_TEN,
        }
        for _, bagId in ipairs(bags) do
            local cache = (SHARED_INVENTORY.GetBagCache and SHARED_INVENTORY:GetBagCache(bagId))
                       or (SHARED_INVENTORY.bagCache and SHARED_INVENTORY.bagCache[bagId])
            if cache then
                for slotIndex, slotData in pairs(cache) do
                    ApplyPotionOverrides(slotData, bagId, slotIndex)
                end
            end
        end
    end

    -- Trigger a redraw of active inventory scroll lists
    if PLAYER_INVENTORY and PLAYER_INVENTORY.UpdateList then
        if PLAYER_INVENTORY.inventories then
            for invType, inv in pairs(PLAYER_INVENTORY.inventories) do
                if inv and inv.listView and (invType == INVENTORY_BACKPACK or (inv.control and not inv.control:IsHidden())) then
                    PLAYER_INVENTORY:UpdateList(invType)
                end
            end
        else
            PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK)
        end
    end

    isRefreshingInventory = false
end

--------------------------------------------------------------------------------
-- Global API Hooking & Station Management
--------------------------------------------------------------------------------

--- Hooks item getters across inventories, quickslots, and guild store searches.
function AbilityIconsFramework.InitializeHeroismPotions()
    if AbilityIconsFramework._heroismPotionsInitialized then
        AbilityIconsFramework.RefreshInventoryHeroismPotions()
        return
    end
    AbilityIconsFramework._heroismPotionsInitialized = true

    AbilityIconsFramework.InitializePotionNames()

    local ZO_GetItemName                         = GetItemName
    local ZO_GetItemInfo                         = GetItemInfo
    local ZO_GetItemLinkName                     = GetItemLinkName
    local ZO_GetItemLinkInfo                     = GetItemLinkInfo
    local ZO_GetSlotTexture                      = GetSlotTexture
    local ZO_GetSlotName                         = GetSlotName
    local ZO_GetTradingHouseListingItemInfo      = GetTradingHouseListingItemInfo
    local ZO_GetTradingHouseSearchResultItemInfo = GetTradingHouseSearchResultItemInfo

    -- Return ZO_GetItemName unmodified so third-party inventory sorting/filtering addons
    -- (AutoCategory, Arkadius, Inventory Grid View) are not broken by embedded color hex codes!
    GetItemName = function(bagId, slotIndex)
        return ZO_GetItemName(bagId, slotIndex)
    end
    _G.GetItemName = GetItemName

    -- Inventory and bag item info hook
    GetItemInfo = function(bagId, slotIndex)
        local icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality =
            ZO_GetItemInfo(bagId, slotIndex)
        if not icon or not stack or stack <= 0 then
            return icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality
        end

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality
        end

        local itemLink = GetItemLink(bagId, slotIndex)
        local potion = GetActivePotion(itemLink)
        if potion and potion.icon then
            return potion.icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality
        end

        return icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, functionalQuality, displayQuality
    end
    _G.GetItemInfo = GetItemInfo

    -- Uncolored item link name hook
    GetItemLinkName = function(itemLink)
        local rawName = ZO_GetItemLinkName(itemLink)
        if not rawName or rawName == "" then
            return rawName
        end

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return rawName
        end

        local potion = GetActivePotion(itemLink)
        if potion and potion.name then
            return potion.name
        end

        return rawName
    end
    _G.GetItemLinkName = GetItemLinkName

    -- Item link icon info hook
    GetItemLinkInfo = function(itemLink)
        local icon, sellPrice, meetsUsageRequirement, equipType, itemStyleId = ZO_GetItemLinkInfo(itemLink)
        if not icon then
            return icon, sellPrice, meetsUsageRequirement, equipType, itemStyleId
        end

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return icon, sellPrice, meetsUsageRequirement, equipType, itemStyleId
        end

        local potion = GetActivePotion(itemLink)
        if potion and potion.icon then
            return potion.icon, sellPrice, meetsUsageRequirement, equipType, itemStyleId
        end

        return icon, sellPrice, meetsUsageRequirement, equipType, itemStyleId
    end
    _G.GetItemLinkInfo = GetItemLinkInfo

    -- Action bar and quickslot texture hook
    GetSlotTexture = function(slotIndex, hotbarCategory)
        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return ZO_GetSlotTexture(slotIndex, hotbarCategory)
        end
        local itemLink = GetSlotItemLink(slotIndex, hotbarCategory)
        local potion = GetActivePotion(itemLink)
        if potion and potion.icon then
            return potion.icon
        end
        return ZO_GetSlotTexture(slotIndex, hotbarCategory)
    end
    _G.GetSlotTexture = GetSlotTexture

    -- Action bar and quickslot display name hook
    GetSlotName = function(slotIndex, hotbarCategory)
        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return ZO_GetSlotName(slotIndex, hotbarCategory)
        end
        local itemLink = GetSlotItemLink(slotIndex, hotbarCategory)
        local potion = GetActivePotion(itemLink)
        if potion and potion.coloredName then
            return potion.coloredName
        end
        return ZO_GetSlotName(slotIndex, hotbarCategory)
    end
    _G.GetSlotName = GetSlotName

    -- Guild store listing info hook
    GetTradingHouseListingItemInfo = function(index)
        local icon, itemName, displayQuality, stackCount, sellerName, timeRemaining, salePrice, currencyType, itemUniqueId, salePricePerUnit =
            ZO_GetTradingHouseListingItemInfo(index)
        if not icon then
            return icon, itemName, displayQuality, stackCount, sellerName, timeRemaining, salePrice, currencyType, itemUniqueId, salePricePerUnit
        end

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return icon, itemName, displayQuality, stackCount, sellerName, timeRemaining, salePrice, currencyType, itemUniqueId, salePricePerUnit
        end

        local itemLink = GetTradingHouseListingItemLink(index)
        local potion = GetActivePotion(itemLink)
        if potion then
            if potion.icon then icon = potion.icon end
            if potion.coloredName then itemName = potion.coloredName end
        end

        return icon, itemName, displayQuality, stackCount, sellerName, timeRemaining, salePrice, currencyType, itemUniqueId, salePricePerUnit
    end
    _G.GetTradingHouseListingItemInfo = GetTradingHouseListingItemInfo

    -- Guild store search result item info hook
    GetTradingHouseSearchResultItemInfo = function(index)
        local icon, name, displayQuality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit =
            ZO_GetTradingHouseSearchResultItemInfo(index)
        if not icon then
            return icon, name, displayQuality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
        end

        local settings = AbilityIconsFramework.GetSettings()
        if not (settings and settings.enableHeroismPotionIcons) or AbilityIconsFramework.HEROISM_POTIONS.isStationInteract then
            return icon, name, displayQuality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
        end

        local itemLink = GetTradingHouseSearchResultItemLink(index)
        local potion = GetActivePotion(itemLink)
        if potion then
            if potion.icon then icon = potion.icon end
            if potion.coloredName then name = potion.coloredName end
        end

        return icon, name, displayQuality, stackCount, sellerName, timeRemaining, purchasePrice, currencyType, itemUniqueId, purchasePricePerUnit
    end
    _G.GetTradingHouseSearchResultItemInfo = GetTradingHouseSearchResultItemInfo

    -- Hook SHARED_INVENTORY slot data creation using SecurePostHook to avoid breaking internal return values
    if SHARED_INVENTORY then
        if SHARED_INVENTORY.CreateOrUpdateSlotData then
            SecurePostHook(SHARED_INVENTORY, "CreateOrUpdateSlotData", function(self, existingSlotData, bagId, slotIndex, isNewItem)
                local cache = (self.GetBagCache and self:GetBagCache(bagId))
                           or (self.bagCache and self.bagCache[bagId])
                local slotData = (cache and cache[slotIndex]) or existingSlotData
                if slotData then
                    ApplyPotionOverrides(slotData, bagId, slotIndex)
                end
            end)
        end

        if SHARED_INVENTORY.RegisterCallback then
            SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", function(bagId, slotIndex)
                local cache = (SHARED_INVENTORY.GetBagCache and SHARED_INVENTORY:GetBagCache(bagId))
                           or (SHARED_INVENTORY.bagCache and SHARED_INVENTORY.bagCache[bagId])
                if cache and cache[slotIndex] then
                    ApplyPotionOverrides(cache[slotIndex], bagId, slotIndex)
                end
            end)
            SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", function()
                AbilityIconsFramework.RefreshInventoryHeroismPotions()
            end)
        end
    end

    InitializeTooltipHooks()
    AbilityIconsFramework.RefreshInventoryHeroismPotions()

    -- Temporarily disable overrides while interacting with Alchemy tables so crafting stays vanilla
    EVENT_MANAGER:RegisterForEvent(AbilityIconsFramework.name .. "_CraftingStart", EVENT_CRAFTING_STATION_INTERACT,
        function()
            AbilityIconsFramework.HEROISM_POTIONS.isStationInteract = true
            AbilityIconsFramework.RefreshInventoryHeroismPotions()
        end)
    EVENT_MANAGER:RegisterForEvent(AbilityIconsFramework.name .. "_CraftingEnd", EVENT_END_CRAFTING_STATION_INTERACT,
        function()
            AbilityIconsFramework.HEROISM_POTIONS.isStationInteract = false
            AbilityIconsFramework.RefreshInventoryHeroismPotions()
        end)
end
