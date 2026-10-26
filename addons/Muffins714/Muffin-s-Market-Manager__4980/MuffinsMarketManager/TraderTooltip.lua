-- Create a local shortcut for global
local MMM = MuffinsMarketManager
-- Optional addons saved once
local ttcAddon = nil
local ttcItemInfo = nil
local mmAddon = nil
local guildStoreLib = nil
-- Colors and icons are in MuffinsMarketManager.lua

----------------------------------------------------------------------
-- CUSTOM TOOLTIP STYLES
----------------------------------------------------------------------
-- Crafting station label
local StyleCraftText = {
    width          = ZO_GAMEPAD_CONTENT_WIDTH,
    paddingLeft    = 0,
    paddingRight   = 0,
    fontFace       = "$(GAMEPAD_LIGHT_FONT)",
    fontSize       = "$(GP_34)",
    fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3, -- off white
    fontStyle      = "soft-shadow-thick",
}

-- Crafting station gold amount
local StyleCraftGold = {
    width          = ZO_GAMEPAD_CONTENT_WIDTH,
    paddingLeft    = 0,
    paddingRight   = 0,
    fontFace       = "$(GAMEPAD_MEDIUM_FONT)",
    fontSize       = "$(GP_36)",
    fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1, -- white
    fontStyle      = "soft-shadow-thick",
}

-- Smaller text for the TTC updated line
local StyleAlertTrader = {
    layoutPrimaryDirection = "right",
    layoutSecondaryDirection = "up",
    widthPercent = 100,
    childSpacing = 8,
    fontSize = "$(GP_22)",
    height = 32,
}

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function IsValidPrice(price) return (price or 0) > 0 end

local function IsTraderTooltipEnabled()
    return MMM.GetSettings().tt_enabled
end

local function RoundPrice(num, decimals)
    if not num then return num end
    local places = MMM.GetSettings().tt_roundPrice and 0 or (decimals or 0)
    local mult = 10 ^ places
    return math.floor(num * mult + 0.5) / mult
end

local function FormatNumber(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Gold for chat, chat can't show colors or icons so plain text
local function ChatGold(amount)
    return FormatNumber(RoundPrice(amount or 0, 2)) .. "g"
end

local function ColorPrefix(color)
    if not color then return MMM.HEX_COLOR.WHITE end
    local c = ZO_ColorDef:New(color.r or 1, color.g or 1, color.b or 1, 1)
    return "|c" .. c:ToHex()
end

----------------------------------------------------------------------
-- PRICE SOURCES
----------------------------------------------------------------------
-- Shared keys
-- key              - tt_use<key>
-- label            - source name on every line except the short price
-- shortPrice       - true if it has a short price line
-- shortPriceLabel  - short price label or falls back to label
-- printChat        - returns the price text for chat
-- chatModes        - Price to chat menu entries, each has a label and a mode for printChat
-- isReady          - true once the source addon is loaded
-- fetch            - returns price + extra lines for tooltip
-- suggestedPrice   - suggested price label TTC ONLY

MMM.TT_Sources = {
    {
        -- Tamriel Trade Centre
        key             = "TTC",
        label           = "TTC",
        shortPrice      = true,
        shortPriceLabel = GetString(MMM_TT_TTC_SALES_AVG),
        chatModes       = {
            { label = GetString(MMM_TT_PRICE_CHAT_TTC_SHORT), mode = "short" },
            { label = GetString(MMM_TT_PRICE_CHAT_TTC_LONG),  mode = "long" },
        },
        suggestedPrice  = GetString(MMM_TT_TTC_SUGGESTED),
        isReady         = function() return ttcAddon ~= nil end,
        fetch           = function(itemLink)
            local info = ttcAddon:GetPriceInfo(itemLink)
            if not info then return nil end

            -- Short price is SaleAvg, falls back to Avg
            local price = info.SaleAvg or info.Avg
            if not IsValidPrice(price) and not IsValidPrice(info.SuggestedPrice) then return nil end
            local settings = MMM.GetSettings()
            local extras = {}
            local salesExtras = {}
            local numColor = ColorPrefix(settings.tt_mainColorTTC or { r = 0.6, g = 1, b = 0.6 })

            if settings.tt_showMetricsTTC and info.Avg then
                table.insert(extras,
                    MMM.HEX_COLOR.SAND ..
                    GetString(MMM_TT_AVG) .. " " .. numColor .. ZO_CommaDelimitNumber(math.floor(info.Avg + 0.5)) .. "|r"
                    .. MMM.HEX_COLOR.SAND ..
                    "  " ..
                    GetString(MMM_TT_MIN) ..
                    " " .. numColor .. ZO_CommaDelimitNumber(math.floor((info.Min or 0) + 0.5)) .. "|r"
                    .. MMM.HEX_COLOR.SAND ..
                    "  " ..
                    GetString(MMM_TT_MAX) ..
                    " " .. numColor .. ZO_CommaDelimitNumber(math.floor((info.Max or 0) + 0.5)) .. "|r")
            end
            -- Listings line
            if settings.tt_listingsModeTTC_Enabled and info.EntryCount then
                local mode = settings.tt_listingsModeTTC
                if mode == "short" then
                    table.insert(extras,
                        numColor ..
                        ZO_CommaDelimitNumber(info.EntryCount) ..
                        MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_LISTINGS) .. "|r")
                elseif mode == "full" then
                    if info.EntryCount == (info.AmountCount or 0) then
                        table.insert(extras,
                            numColor ..
                            ZO_CommaDelimitNumber(info.EntryCount) ..
                            MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_LISTINGS) .. "|r")
                    else
                        table.insert(extras,
                            numColor ..
                            ZO_CommaDelimitNumber(info.EntryCount) ..
                            MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_LISTINGS) .. " / "
                            .. numColor ..
                            ZO_CommaDelimitNumber(info.AmountCount or 0) ..
                            MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_ITEMS) .. "|r")
                    end
                end
            end
            -- Sales line
            if settings.tt_salesModeTTC_Enabled and info.SaleEntryCount and info.SaleEntryCount > 0 then
                local mode = settings.tt_salesModeTTC
                if mode == "short" then
                    table.insert(salesExtras,
                        numColor ..
                        ZO_CommaDelimitNumber(info.SaleEntryCount) ..
                        MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_SALES) .. "|r")
                elseif mode == "full" then
                    table.insert(salesExtras,
                        numColor ..
                        ZO_CommaDelimitNumber(info.SaleEntryCount) ..
                        MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_SALES) .. " / "
                        .. numColor ..
                        ZO_CommaDelimitNumber(info.SaleAmountCount or 0) ..
                        MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_ITEMS) .. "|r")
                end
            end
            -- Updated today line
            if settings.tt_showUpdatedTTC and ttcAddon.GetPriceTableUpdatedDateString then
                local updatedText = ttcAddon:GetPriceTableUpdatedDateString()
                if updatedText and updatedText ~= "" then
                    -- Table so this line can use the smaller style
                    table.insert(extras, {
                        text  = MMM.HEX_COLOR.SAND .. updatedText .. "|r",
                        style = StyleAlertTrader,
                    })
                end
            end
            -- Top of the suggested range is 25% over
            local suggestedHigh = info.SuggestedPrice and (info.SuggestedPrice * 1.25) or nil

            return {
                price         = price,
                suggested     = info.SuggestedPrice,
                suggestedHigh = suggestedHigh,
                extras        = extras,
                salesExtras   = salesExtras,
            }
        end,
        -- Short is sales avg and suggested, long adds everything else
        printChat       = function(itemLink, mode)
            local prefix = "TTC " .. GetString(MMM_TT_PRICE_FOR) .. " " .. itemLink .. ": "
            local info = ttcAddon:GetPriceInfo(itemLink)
            if not info then return prefix .. GetString(MMM_TT_NO_SALES_DATA) end
            local isLong = mode == "long"

            local parts = {}
            if IsValidPrice(info.SaleAvg) then
                local salesPart = GetString(MMM_TT_CHAT_SALES_AVG) .. " " .. ChatGold(info.SaleAvg)
                if isLong and info.SaleEntryCount and info.SaleEntryCount > 0 then
                    salesPart = salesPart ..
                        " (" .. ZO_CommaDelimitNumber(info.SaleEntryCount) .. " " .. GetString(MMM_TT_SALES)
                    if info.SaleAmountCount and info.SaleAmountCount ~= info.SaleEntryCount then
                        salesPart = salesPart ..
                            " / " .. ZO_CommaDelimitNumber(info.SaleAmountCount) .. " " .. GetString(MMM_TT_ITEMS)
                    end
                    salesPart = salesPart .. ")"
                end
                table.insert(parts, salesPart)
            end
            if IsValidPrice(info.SuggestedPrice) then
                table.insert(parts, GetString(MMM_TT_CHAT_SUGGESTED) .. " " .. ChatGold(info.SuggestedPrice) ..
                    " - " .. ChatGold(info.SuggestedPrice * 1.25))
            end
            if isLong and IsValidPrice(info.Avg) then
                table.insert(parts, GetString(MMM_TT_AVG) .. " " .. ChatGold(info.Avg) ..
                    " " .. GetString(MMM_TT_MIN) .. " " .. ChatGold(info.Min) ..
                    " " .. GetString(MMM_TT_MAX) .. " " .. ChatGold(info.Max))
            end
            if isLong and info.EntryCount and info.EntryCount > 0 then
                local listingsPart = ZO_CommaDelimitNumber(info.EntryCount) .. " " .. GetString(MMM_TT_LISTINGS)
                if info.AmountCount and info.AmountCount ~= info.EntryCount then
                    listingsPart = listingsPart ..
                        " / " .. ZO_CommaDelimitNumber(info.AmountCount) .. " " .. GetString(MMM_TT_ITEMS)
                end
                table.insert(parts, listingsPart)
            end

            if #parts == 0 then return prefix .. GetString(MMM_TT_NO_SALES_DATA) end
            return prefix .. table.concat(parts, " | ")
        end,
    },
    -- Master Merchant
    {
        key        = "MM",
        label      = "MM",
        shortPrice = true,
        chatModes  = {
            { label = GetString(MMM_TT_PRICE_CHAT_MM), mode = "short" },
        },
        -- isInitialized and guildStoreReady = true after MM and GuildStore
        isReady    = function()
            return mmAddon ~= nil and mmAddon.isInitialized
                and guildStoreLib ~= nil and guildStoreLib.guildStoreReady
        end,
        fetch      = function(itemLink)
            local stats = mmAddon:itemStats(itemLink, false)
            if not stats or not IsValidPrice(stats.avgPrice) then return nil end

            local settings = MMM.GetSettings()
            local extras = {}
            if settings.tt_showMetricsMM then
                -- Built piece by piece so each number gets the source color
                local numColor = ColorPrefix(settings.tt_mainColorMM or { r = 1, g = 0.85, b = 0.29 })
                local salesPart = numColor .. ZO_CommaDelimitNumber(stats.numSales or 0) .. "|r" ..
                    MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_SALES)
                if stats.numSales ~= stats.numItems then
                    salesPart = salesPart .. " / " .. numColor .. ZO_CommaDelimitNumber(stats.numItems or 0) .. "|r" ..
                        MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_ITEMS)
                end
                table.insert(extras,
                    MMM.HEX_COLOR.SAND .. "MM (" .. salesPart .. MMM.HEX_COLOR.SAND .. ", "
                    .. numColor ..
                    ZO_CommaDelimitNumber(stats.numDays or 0) ..
                    "|r" .. MMM.HEX_COLOR.SAND .. " " .. GetString(MMM_TT_DAYS) .. ") " .. "|r")
            end
            -- MM's own craft cost, separate from the crafting station lines
            if settings.tt_showCraftCostMM then
                local craftCost = mmAddon:itemCraftPrice(itemLink)
                -- nil when the item isn't craftable
                if craftCost then
                    local numColor = ColorPrefix(settings.tt_mainColorMM or { r = 1, g = 0.85, b = 0.29 })
                    table.insert(extras,
                        MMM.HEX_COLOR.SAND .. GetString(MMM_TT_MM_CRAFT_COST) .. " " .. numColor ..
                        ZO_CommaDelimitNumber(math.floor(craftCost + 0.5)) .. "|r")
                end
            end
            return { price = stats.avgPrice, extras = extras }
        end,
        -- MM only has the one line
        printChat  = function(itemLink, mode)
            local prefix = "MM " .. GetString(MMM_TT_PRICE_FOR) .. " " .. itemLink .. ": "
            local stats = mmAddon:itemStats(itemLink, false)
            if not stats or not IsValidPrice(stats.avgPrice) then
                return prefix .. GetString(MMM_TT_NO_SALES_DATA)
            end

            local salesPart = ZO_CommaDelimitNumber(stats.numSales or 0) .. " " .. GetString(MMM_TT_SALES)
            if stats.numSales ~= stats.numItems then
                salesPart = salesPart ..
                    " / " .. ZO_CommaDelimitNumber(stats.numItems or 0) .. " " .. GetString(MMM_TT_ITEMS)
            end
            return prefix .. ChatGold(stats.avgPrice) .. " (" .. salesPart .. ", " ..
                ZO_CommaDelimitNumber(stats.numDays or 0) .. " " .. GetString(MMM_TT_DAYS) .. ")"
        end,
    },
}

----------------------------------------------------------------------
-- CORE GETPRICES
----------------------------------------------------------------------
-- Collects every enabled source's price for one item
function MMM.TT_GetPrices(itemLink)
    if not itemLink or itemLink == "" then return nil end

    local settings = MMM.GetSettings()
    local result = {
        vendorPrice = 0,
        sources = {},
        average = nil,
    }

    local _, vendor = GetItemLinkInfo(itemLink)
    result.vendorPrice = IsValidPrice(vendor) and vendor or 0
    result.noDataSources = {}      -- source addon not loaded
    result.noItemPriceSources = {} -- source loaded but no price for this item

    -- Skips disabled sources
    local sum, count = 0, 0
    for _, src in ipairs(MMM.TT_Sources) do
        if settings["tt_use" .. src.key] then
            if src.isReady() then
                local data = src.fetch(itemLink)
                if data and (IsValidPrice(data.price) or IsValidPrice(data.suggested)) then
                    table.insert(result.sources, {
                        key             = src.key,
                        label           = src.label,
                        shortPriceLabel = src.shortPriceLabel or src.label,
                        price           = data.price and RoundPrice(data.price, 2) or nil,
                        suggested       = data.suggested and RoundPrice(data.suggested, 2) or nil,
                        suggestedLabel  = src.suggestedPrice,
                        suggestedHigh   = data.suggestedHigh and RoundPrice(data.suggestedHigh, 2) or nil,
                        extras          = data.extras or {},
                        salesExtras     = data.salesExtras or {}, -- TTC only
                    })
                    -- Only the short price counts toward the average
                    if IsValidPrice(data.price) then
                        sum = sum + data.price
                        count = count + 1
                    end
                else
                    -- Loaded but no price for this item
                    table.insert(result.noItemPriceSources, { key = src.key, label = src.label })
                end
            else
                -- Turned on but the addon isn't loaded
                table.insert(result.noDataSources, { key = src.key, label = src.label })
            end
        end
    end

    if count > 0 then result.average = RoundPrice(sum / count, 2) end

    return result
end

----------------------------------------------------------------------
-- INDICATORS
----------------------------------------------------------------------
-------------------------------
-- Purchase indicator
-------------------------------
-- DEBUG Mail track
-- Doesn't do anything till true but still commenting out
--[[
local MAIL_TRACK = false
local function MailTrackDebug(itemLink, msg)
    if not MAIL_TRACK then return end
    local coloredName = itemLink
    if itemLink and itemLink ~= "" then
        -- Work around because GetItemDisplayQuality needs bagID
        local quality = GetItemLinkDisplayQuality(itemLink)
        local qualityColor = GetItemQualityColor(quality)
        coloredName = qualityColor:Colorize(GetItemLinkName(itemLink))
    end
    MMM.MMMPrint("MMM Debug " .. msg .. " " .. tostring(coloredName))
end
]]

-- Account wide unlocks so any character can check them
local ACCOUNT_WIDE_LEARNABLE_TYPES = {
    [SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE] = true,
    [ITEMTYPE_RACIAL_STYLE_MOTIF] = true,
    [ITEMTYPE_ARMOR] = true,
    [ITEMTYPE_WEAPON] = true,
}

-- Recipes always track and the rest only if not learned yet
local function ShouldTrackPurchase(itemLink)
    if not itemLink or itemLink == "" then
        return false
    end
    local itemType, specializedType = GetItemLinkItemType(itemLink)

    if itemType == ITEMTYPE_RECIPE then
        return true
    end

    if ACCOUNT_WIDE_LEARNABLE_TYPES[itemType] or ACCOUNT_WIDE_LEARNABLE_TYPES[specializedType] then
        return CanItemLinkBeUsedToLearn(itemLink)
    end

    return false
end

-- Purchases waiting in the mail, clears on reload
local purchasedItems = {}
local pendingPurchaseItemId = nil
-- DEBUG Mail track
-- local pendingPurchaseItemLink = nil

-- Taken from the mail and still in the bag
local itemsInBackpack = {}

-- Counts a confirmed purchase
local function OnTradingHouseResponse(eventCode, responseType, result)
    if responseType == TRADING_HOUSE_RESULT_PURCHASE_PENDING and result == TRADING_HOUSE_RESULT_SUCCESS then
        if pendingPurchaseItemId then
            purchasedItems[pendingPurchaseItemId] = (purchasedItems[pendingPurchaseItemId] or 0) + 1
            -- DEBUG Mail track
            -- MailTrackDebug(pendingPurchaseItemLink, "Purchase confirmed for")
            pendingPurchaseItemId = nil
            -- pendingPurchaseItemLink = nil

            -- Refresh so the row updates right away
            GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:RefreshData()
        end
    end
end
MMM.OnTradingHouseResponse = OnTradingHouseResponse

-- Rescans the bag and updates both icons
local function ScanBackpackForTrackedItems()
    if not next(purchasedItems) and not next(itemsInBackpack) then return end

    local countInBag = {} -- itemId -> count in bag

    -- Item link for each itemId in the bag
    -- local linkInBag = {} -- DEBUG Mail track

    local bagSize = GetBagSize(BAG_BACKPACK)
    for slotIndex = 0, bagSize do
        local slotLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if slotLink and slotLink ~= "" then
            local itemId = GetItemLinkItemId(slotLink)
            countInBag[itemId] = (countInBag[itemId] or 0) + (GetSlotStackSize(BAG_BACKPACK, slotIndex) or 1)
            -- DEBUG Mail track
            -- linkInBag[itemId] = slotLink
        end
    end

    local changedAny = false

    -- Landed in the bag, swap the mail icon for the backpack icon
    for itemId in pairs(purchasedItems) do
        if countInBag[itemId] and countInBag[itemId] > 0 then
            purchasedItems[itemId] = nil
            itemsInBackpack[itemId] = true
            changedAny = true
            -- DEBUG Mail track
            -- MailTrackDebug(linkInBag[itemId], "Landed in backpack:")
        end
    end
    -- No longer in the bag at all, clear the backpack icon
    for itemId in pairs(itemsInBackpack) do
        if not countInBag[itemId] or countInBag[itemId] <= 0 then
            itemsInBackpack[itemId] = nil
            changedAny = true
        end
    end

    if changedAny and GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:IsActive() then
        GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:RefreshData()
    end
end
MMM.ScanBackpackForTrackedItems = ScanBackpackForTrackedItems

-- Rescans after taking one mail item
local function OnMailTakeAttachmentSuccess(eventCode, mailId)
    zo_callLater(ScanBackpackForTrackedItems, 150)
end
MMM.OnMailTakeAttachmentSuccess = OnMailTakeAttachmentSuccess

-- Rescans after take all
local function OnTakeAllCategoryResponse(eventCode, result)
    zo_callLater(ScanBackpackForTrackedItems, 150)
end
MMM.OnTakeAllCategoryResponse = OnTakeAllCategoryResponse

-- Rescans when the bag changes
local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory,
                                     inventoryUpdateReason, stackCountChange)
    -- Removed because the check is now in RegisterForEvent _InvSlotUpdate
    -- if bagId ~= BAG_BACKPACK then return end
    if not next(purchasedItems) and not next(itemsInBackpack) then return end

    zo_callLater(ScanBackpackForTrackedItems, 50)
end
MMM.OnInventorySlotUpdate = OnInventorySlotUpdate

-------------------------------
-- Good deal indicator
-------------------------------
-- Good deal % below sales avg per item type
local SPECIAL_THRESHOLDS = {
    -- Improving
    [ITEMTYPE_BLACKSMITHING_BOOSTER]                                = 20,
    [ITEMTYPE_CLOTHIER_BOOSTER]                                     = 20,
    [ITEMTYPE_ENCHANTING_RUNE_ASPECT]                               = 20,
    [ITEMTYPE_JEWELRYCRAFTING_BOOSTER]                              = 20,
    [ITEMTYPE_WOODWORKING_BOOSTER]                                  = 20,
    -- Motifs and style pages
    [SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE]                   = 35,
    [SPECIALIZED_ITEMTYPE_RACIAL_STYLE_MOTIF_CHAPTER]               = 20,
    -- Furnishing recipes
    [SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING]        = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING]  = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING]       = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING]   = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING] = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING]    = 25,
    [SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING]  = 25,
    -- Under 5000 needs 25% off and 5000 or more needs 12% off
    [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK]       = {
        breakpoint = 5000,
        low = 25,
        high = 12
    },
    [SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD]        = {
        breakpoint = 5000,
        low = 25,
        high = 12
    },
}
local MIN_SALES_FOR_AVG = 10 -- under this the low sales rule is used

-- Returns the good deal icon for a listing or an empty string
local function GetIndicators(itemLink, listingPricePerUnit, ttcSuggestedPrice)
    local settings = MMM.GetSettings()
    local result = ""
    if not settings.tt_goodDealIndicator or not listingPricePerUnit then
        return result
    end

    local itemType, specializedItemType = GetItemLinkItemType(itemLink)
    local entry = SPECIAL_THRESHOLDS[specializedItemType] or SPECIAL_THRESHOLDS[itemType]

    -- Not in the table so compare against suggested
    if not entry then
        if ttcSuggestedPrice and listingPricePerUnit < ttcSuggestedPrice then
            result = result .. MMM.IconsFor.BUYER_SYMBOL
        end
        return result
    end

    -- Read TTC directly since src.price falls back to Avg
    local info = ttcAddon and ttcAddon:GetPriceInfo(itemLink)
    if not info then return result end

    local salesAvg = tonumber(info.SaleAvg)
    local salesCount = tonumber(info.SaleEntryCount) or 0
    local listingAvg = tonumber(info.Avg)

    -- 10 or more sales uses the % below sales avg
    if salesAvg and salesAvg > 0 and salesCount >= MIN_SALES_FOR_AVG then
        local maxPercent = entry
        if type(entry) == "table" then
            maxPercent = (salesAvg >= entry.breakpoint) and entry.high or entry.low
        end
        local maxPrice = salesAvg * (1 - maxPercent / 100)
        if listingPricePerUnit <= maxPrice then
            result = result .. MMM.IconsFor.BUYER_SYMBOL
        end
        return result
    end

    -- Under 10 sales has to beat both averages or whichever one exists
    local hasSalesAvg = salesAvg and salesAvg > 0
    local hasListingAvg = listingAvg and listingAvg > 0
    if not hasSalesAvg and not hasListingAvg then return result end

    local belowSales = not hasSalesAvg or listingPricePerUnit < salesAvg
    local belowListings = not hasListingAvg or listingPricePerUnit < listingAvg
    if belowSales and belowListings then
        result = result .. MMM.IconsFor.BS_LOW_SALES
    end

    return result
end

-------------------------------
-- VENDOR INDICATOR
-------------------------------
-- Uses the MMM.VendorMap and MMM.FurnishingMap tables
local function GetItemIdFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    local id = string.match(itemLink, "|H%d:item:(%d+):")
    return id and tonumber(id) or nil
end

-- Returns the vendor labels and price for an item or nil
local function GetVendorLine(itemId, sourcePrice)
    if not itemId then return nil end

    -- Regular vendors first
    local entry = MMM.VendorMap and MMM.VendorMap[itemId]
    if entry then
        local typeInfo = MMM.VendorTypes and MMM.VendorTypes[entry.vendorType]
        local typeVendorLabel = typeInfo and (typeInfo.groupLabel or typeInfo.name) or GetString(MMM_TT_VENDOR)
        local NO_NPC_LABEL = nil
        return typeVendorLabel, nil, nil, NO_NPC_LABEL, entry.price, MMM.IconsFor.VENDOR_SYMBOL
    end

    -- Furnishing vendors show name and zone instead of type
    local furnEntry = MMM.FurnishingMap and MMM.FurnishingMap[itemId]
    if furnEntry then
        local namedVendorLabel = furnEntry.npcName
        local vendorZoneLabel = furnEntry.zone
        local IS_FURNISHING_VENDOR = true
        return nil, namedVendorLabel, vendorZoneLabel, IS_FURNISHING_VENDOR, furnEntry.price,
            MMM.IconsFor.VENDOR_HF_SYMBOL
    end

    return nil
end

-- Builds the vendor name line and the price difference line
local function BuildVendorLine(itemId, sourcePrice)
    if not IsValidPrice(sourcePrice) then return nil end

    local typeVendorLabel, namedVendorLabel, vendorZoneLabel, _, vendorPrice, vendorSymbol = GetVendorLine(itemId,
        sourcePrice)
    if not (typeVendorLabel or namedVendorLabel or vendorZoneLabel) or not IsValidPrice(vendorPrice) then return nil end

    local diffMath = sourcePrice - vendorPrice
    local sign = diffMath >= 0 and "+" or "" -- lua doesnt add + for positive numbers

    local diffColor
    if diffMath > 0 then
        diffColor = MMM.HEX_COLOR.RED
    elseif diffMath < 0 then
        diffColor = MMM.HEX_COLOR.GREEN
    else
        diffColor = MMM.HEX_COLOR.WHITE
    end

    local numberPart = MMM.HEX_COLOR.SAND ..
        GetString(MMM_TT_SELLS_FOR) .. " " .. MMM.HEX_COLOR.GOLD .. FormatNumber(vendorPrice) .. " " .. MMM.goldIcon
        .. MMM.HEX_COLOR.SAND ..
        " (" .. diffColor .. sign .. FormatNumber(diffMath) .. "|r"
        .. MMM.HEX_COLOR.SAND .. ")" .. "|r"

    local vendorInfoLabels
    if namedVendorLabel then
        -- Furnishing vendor
        vendorInfoLabels = MMM.HEX_COLOR.SAND .. namedVendorLabel .. " " .. MMM.HEX_COLOR.WHITE .. vendorZoneLabel
    else
        -- Regular vendor
        vendorInfoLabels = MMM.HEX_COLOR.WHITE .. typeVendorLabel
    end

    local typeLine = vendorSymbol .. " " .. vendorInfoLabels .. "|r"
    local priceLine = numberPart
    return typeLine, priceLine
end

----------------------------------------------------------------------
-- DISPLAY ADDPRICELINES
----------------------------------------------------------------------
-- True for a real item link and not some other link type
local function IsRealItemLink(itemLink)
    return type(itemLink) == "string" and itemLink ~= "" and string.find(itemLink, "|H.-:item:") ~= nil
end

-- Adds every price line to a tooltip
function MMM.TT_AddPriceLines(control, itemLink, listingPricePerUnit)
    if not IsTraderTooltipEnabled() then return end
    if not control or type(control.AddLine) ~= "function" then return end
    if not IsRealItemLink(itemLink) then return end
    local settings = MMM.GetSettings()
    local errorColor = MMM.HEX_COLOR.RED
    local prices = MMM.TT_GetPrices(itemLink)
    if not prices then return end

    local addedLine = false
    local style = ZO_TOOLTIP_STYLES.topSubsection
    for i, src in ipairs(prices.sources) do
        local mainColor = ColorPrefix(settings["tt_mainColor" .. src.key] or { r = 0.6, g = 1, b = 0.6 })
        -- Good deal icon, TTC only
        local indicators = ""
        if src.key == "TTC" then
            indicators = GetIndicators(itemLink, listingPricePerUnit, src.suggested)
        end

        -- Short price line, TTC uses SaleAvg and MM uses avg
        if settings["tt_shortPrice" .. src.key] and IsValidPrice(src.price) then
            local labelPart = MMM.HEX_COLOR.SAND .. src.shortPriceLabel .. "|r"
            local numberPart = mainColor .. FormatNumber(src.price) .. " " .. MMM.goldIcon .. " " .. indicators .. "|r"
            control:AddLine(labelPart .. " " .. numberPart, style)
            addedLine = true
            -- Sales line goes right under the short price, TTC only
            if src.salesExtras and #src.salesExtras > 0 then
                for _, salesExtrasLine in ipairs(src.salesExtras) do
                    control:AddLine(salesExtrasLine, style)
                end
            end
        end

        -- Suggested price line, TTC only
        if src.suggestedLabel and IsValidPrice(src.suggested) and settings.tt_showSuggested then
            local priceText = FormatNumber(src.suggested)
            if src.suggestedHigh then
                priceText = priceText .. " - " .. FormatNumber(src.suggestedHigh)
            end

            local labelPart = MMM.HEX_COLOR.SAND .. src.suggestedLabel .. "|r"
            local numberPart = mainColor .. priceText .. " " .. MMM.goldIcon .. "|r"
            control:AddLine(labelPart .. " " .. numberPart, style)
            addedLine = true
        end

        -- Extra lines, each setting is checked inside fetch
        if src.extras then
            for _, extraLine in ipairs(src.extras) do
                -- Tables carry their own style
                if type(extraLine) == "table" then
                    control:AddLine(extraLine.text, extraLine.style or style)
                else
                    control:AddLine(extraLine, style)
                end
                addedLine = true
            end
        end
    end

    -- Vendor indicator
    if settings.tt_vendorIndicator and listingPricePerUnit then
        local itemId = GetItemIdFromLink(itemLink)

        local typeLine, priceLine = BuildVendorLine(itemId, listingPricePerUnit, MMM.HEX_COLOR.WHITE)
        if typeLine then
            control:AddLine(typeLine, ZO_TOOLTIP_STYLES.topSubsection)
            addedLine = true
            if priceLine then
                control:AddLine(priceLine, ZO_TOOLTIP_STYLES.topSubsection)
            end
        end
    end

    if settings.tt_showMissingWarnings and listingPricePerUnit then
        -- Source addon not loaded
        for _, src in ipairs(MMM.TT_Sources) do
            if settings["tt_use" .. src.key] and not src.isReady() then
                control:AddLine(errorColor .. src.label .. " " .. GetString(MMM_TT_NOT_AVAILABLE) .. "|r",
                    ZO_TOOLTIP_STYLES.topSubsection)
                addedLine = true
            end
        end
    end

    -- No price for this item, always shown
    if prices and prices.noItemPriceSources and not IsItemLinkBound(itemLink) then
        for _, noData in ipairs(prices.noItemPriceSources) do
            control:AddLine(
                MMM.HEX_COLOR.SAND .. noData.label .. ": " .. errorColor .. GetString(MMM_TT_NO_SALES_DATA) .. "|r",
                ZO_TOOLTIP_STYLES.topSubsection)
            addedLine = true
        end
    end

    if addedLine then control:AddLine(" ") end
end

----------------------------------------------------------------------
-- TTC MENU
----------------------------------------------------------------------
-- Dialog name for the TTC gamepad options menu
local MMM_TTC_OPTIONS_DIALOG = "MUFFINSMARKETMANAGER_TTC_OPTIONS_DIALOG"

-- Selected listing in browse results
MMM.TT_PendingListingPrice = nil

-- Opens TTC Search Online for the selected item
local function OpenTTCSearchOnline(itemLink)
    if not itemLink or itemLink == "" then return end
    if not ttcItemInfo or not ttcAddon then return end

    local itemInfo = ttcItemInfo:New(itemLink)
    if not itemInfo or not itemInfo.ID then return end

    ttcAddon:SearchOnline(itemInfo)
end

-- Opens TTC Price History Online for the selected item
local function OpenTTCPriceHistoryOnline(itemLink)
    if not itemLink or itemLink == "" then return end
    if not ttcItemInfo or not ttcAddon then return end

    local itemInfo = ttcItemInfo:New(itemLink)
    if not itemInfo or not itemInfo.ID then return end

    ttcAddon:PriceDetailOnline(itemInfo)
end

---------------------------------------------------------------------------------------
-- PARAMETRIC GAMEPAD MENU
---------------------------------------------------------------------------------------
ZO_Dialogs_RegisterCustomDialog(MMM_TTC_OPTIONS_DIALOG,
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title =
        {
            text = GetString(MMM_TT_ACTION_MENU_TITLE),
        },
        mainText =
        {
            text = MMM_TT_ACTION_MENU_PROMPT,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList =
        {
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(TTC_SEARCHONLINE),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        local itemLink = dialog.data and dialog.data.itemLink
                        OpenTTCSearchOnline(itemLink)
                    end,
                },
            },
            {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = GetString(TTC_PRICEHISTORYONLINE),
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function(dialog)
                        local itemLink = dialog.data and dialog.data.itemLink
                        OpenTTCPriceHistoryOnline(itemLink)
                    end,
                },
            },
        },
        buttons =
        {
            {
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    data.callback(dialog)
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    })

----------------------------------------------------------------------
-- KEYBIND
----------------------------------------------------------------------
-- Defines the tertiary keybind that opens the TTC options menu
local priceHistoryKeybindEntry = {
    name = GetString(MMM_TT_ACTION_MENU_TITLE_KEYBIND),
    keybind = "UI_SHORTCUT_TERTIARY",
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    visible = function()
        local settings = MMM.GetSettings()
        local settings = MMM.GetSettings()
        -- TEMP DEBUG
        -- keybind showing on every guild store tab not just browse results
        -- local isBrowseResultsActive = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:IsActive()
        -- d("MMM DEBUG is browse active: " .. tostring(isBrowseResultsActive))
        return settings.tt_enabled and settings.tt_useTTC and settings.tt_menuTTC_enabled and
            MMM.TT_PendingListingPrice ~= nil
    end,
    callback = function()
        if MMM.TT_PendingListingPrice then
            ZO_Dialogs_ShowGamepadDialog(MMM_TTC_OPTIONS_DIALOG, { itemLink = MMM.TT_PendingListingPrice.itemLink })
        end
    end,
}

-- Tracks whether the TTC keybind has already been injected
local isPriceHistoryKeybindInjected = false

----------------------------------------------------------------------
-- REFRESH INPUT STATE
----------------------------------------------------------------------
-- Hides browse results and Addon keybinds while a dialog is open
local browseResultsKeybindsSuppressed = false

-- Addon keybind buttons to hide while a dialog is open. Add more here if needed
local ADDON_KEYBIND_BUTTONS = {
    -- TTC Scan All Listings
    function()
        return TamrielTradeCentre and TamrielTradeCentre.Buttons and TamrielTradeCentre.Buttons.StartScanButton
    end,
}
-- Addon buttons we hid so we know what to put back
local suppressedAddonButtons = {}
local dialogSyncHandlersInstalled = false

-- True if nothing else is using this keybind right now
local function IsKeybindFree(keybind)
    return KEYBIND_STRIP:GetButtonOrEtherealDescriptorForKeybind(keybind) == nil
end

local function RefreshBrowseResultsKeybindState()
    local keybindDescriptor =
        GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.keybindStripDescriptor

    if not keybindDescriptor then return end

    -- Dialog is open
    if ZO_DIALOG_SYNC_OBJECT:IsShown() then
        -- Remove Browse Results keybinds
        if not browseResultsKeybindsSuppressed then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindDescriptor)
            browseResultsKeybindsSuppressed = true
        end

        -- Remove addon keybind buttons from the list
        for _, getButton in ipairs(ADDON_KEYBIND_BUTTONS) do
            local button = getButton()
            if button and not suppressedAddonButtons[button] and KEYBIND_STRIP:HasKeybindButton(button) then
                KEYBIND_STRIP:RemoveKeybindButton(button)
                suppressedAddonButtons[button] = true
            end
        end
    elseif GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:IsActive() then
        -- Restore Browse Results keybinds
        if browseResultsKeybindsSuppressed then
            -- Sort header owns A when the list is empty so leave it
            if IsKeybindFree("UI_SHORTCUT_PRIMARY") then
                KEYBIND_STRIP:AddKeybindButtonGroup(keybindDescriptor)
            end
            browseResultsKeybindsSuppressed = false
        end

        -- Restore addon keybind buttons if their keybind is still free
        for button in pairs(suppressedAddonButtons) do
            if not KEYBIND_STRIP:HasKeybindButton(button) and IsKeybindFree(button.keybind) then
                KEYBIND_STRIP:AddKeybindButton(button)
            end
            suppressedAddonButtons[button] = nil
        end
    end
end

-- Runs the keybind refresh when a dialog opens or closes
local function InstallDialogSyncHandlers()
    if dialogSyncHandlersInstalled then return end

    ZO_DIALOG_SYNC_OBJECT:SetHandler(
        "OnShown",
        RefreshBrowseResultsKeybindState,
        "MuffinsMarketManager"
    )

    ZO_DIALOG_SYNC_OBJECT:SetHandler(
        "OnHidden",
        RefreshBrowseResultsKeybindState,
        "MuffinsMarketManager"
    )

    dialogSyncHandlersInstalled = true
end

-- Injects the TTC keybind into the guild trader browse results
local function InjectPriceHistoryKeybind()
    if isPriceHistoryKeybindInjected then return end

    table.insert(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.keybindStripDescriptor, priceHistoryKeybindEntry)
    InstallDialogSyncHandlers()
    isPriceHistoryKeybindInjected = true
end

----------------------------------------------------------------------
-- PRICE TO CHAT
----------------------------------------------------------------------
local MMM_PRICE_TO_CHAT_DIALOG = "MMM_PRICE_TO_CHAT_DIALOG"
local priceToChatInstalled = false

-- TEMP debug prints for price to chat
--[[
local DEBUG_PRICE_CHAT = true
local function PriceChatDebug(msg)
    if DEBUG_PRICE_CHAT then d("MMM PriceChat: " .. tostring(msg)) end
end
]]

-- Sources turned on and loaded that can print to chat
local function GetPriceToChatSources()
    local settings = MMM.GetSettings()
    local list = {}
    for _, src in ipairs(MMM.TT_Sources) do
        if src.printChat and settings["tt_use" .. src.key] and settings["tt_printChat" .. src.key] and src.isReady() then
            table.insert(list, src)
        end
    end
    return list
end

-- price text to chat
local function SendPriceToChat(src, mode, itemLink)
    -- PriceChatDebug("4 picked source: " .. tostring(src.key) .. " " .. tostring(mode))

    -- Gamepad chat won't open while any dialog is open so wait for it to close
    local attempts = 0
    local function TrySend()
        attempts = attempts + 1
        local dialogOpen = ZO_Dialogs_IsShowingDialog()
        -- PriceChatDebug("5 dialog still open: " .. tostring(dialogOpen) .. " try " .. attempts)
        if dialogOpen and attempts < 20 then
            zo_callLater(TrySend, 100)
            return
        end

        local ok, text = pcall(src.printChat, itemLink, mode)
        -- PriceChatDebug("6 printChat ran: " .. tostring(ok) .. " " .. tostring(text))
        if not ok or not text or text == "" then return end
        StartChatInput(text)

        local editControl = CHAT_SYSTEM.textEntry and CHAT_SYSTEM.textEntry.editControl
        --[[
        PriceChatDebug("7 chat open: " .. tostring(editControl ~= nil and editControl:HasFocus()) ..
            " text: " .. tostring(editControl and editControl:GetText()))
    ]]
    end
    zo_callLater(TrySend, 100)
end

-- Entries get filled in each time the dialog opens
local priceToChatDialogInfo = {
    canQueue = true,
    gamepadInfo =
    {
        dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
    },
    title =
    {
        text = GetString(MMM_TT_PRICE_MENU_TITLE),
    },
    setup = function(dialog)
        dialog:setupFunc()
    end,
    parametricList = {},
    buttons =
    {
        {
            text = SI_GAMEPAD_SELECT_OPTION,
            callback = function(dialog)
                local data = dialog.entryList:GetTargetData()
                -- PriceChatDebug("3 select pressed, has callback: " .. tostring(data ~= nil and data.callback ~= nil))
                ZO_Dialogs_ReleaseDialogOnButtonPress(MMM_PRICE_TO_CHAT_DIALOG)
                if data and data.callback then data.callback(dialog) end
            end,
        },
        {
            text = SI_DIALOG_CANCEL,
        },
    },
}
ZO_Dialogs_RegisterCustomDialog(MMM_PRICE_TO_CHAT_DIALOG, priceToChatDialogInfo)

-- one entry per source
local function ShowPriceToChatDialog(itemLink)
    -- local settings = MMM.GetSettings()
    --[[
    for _, src in ipairs(MMM.TT_Sources) do

        PriceChatDebug("2 " .. src.key .. " use: " .. tostring(settings["tt_use" .. src.key] == true) ..
            " chat: " .. tostring(settings["tt_printChat" .. src.key] == true) ..
            " ready: " .. tostring(src.isReady() and true or false))
        end
        ]]
    local entries = {}
    for _, src in ipairs(GetPriceToChatSources()) do
        for _, chatMode in ipairs(src.chatModes) do
            table.insert(entries, {
                template = "ZO_GamepadMenuEntryTemplate",
                templateData =
                {
                    text = chatMode.label,
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function()
                        SendPriceToChat(src, chatMode.mode, itemLink)
                    end,
                },
            })
        end
    end
    -- PriceChatDebug("2 menu has sources: " .. tostring(#entries > 0) .. " (" .. #entries .. ")")
    if #entries == 0 then return end

    priceToChatDialogInfo.parametricList = entries
    ZO_Dialogs_ShowGamepadDialog(MMM_PRICE_TO_CHAT_DIALOG, { itemLink = itemLink })
end

-- Item link for a bag slot in the action menu
local function GetActionSlotItemLink(inventorySlot)
    if not inventorySlot then return nil end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or not slotIndex then return nil end
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink == "" then return nil end
    return itemLink
end

-- Adds Price to chat to the gamepad item action menu
local function InstallPriceToChatAction()
    if priceToChatInstalled then return end
    priceToChatInstalled = true

    SecurePostHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
        if not IsInGamepadPreferredMode() then return end
        if not MMM.GetSettings().tt_enabled then return end
        local itemLink = GetActionSlotItemLink(inventorySlot)
        if not itemLink then return end
        if #GetPriceToChatSources() == 0 then return end

        slotActions:AddSlotAction(
            MMM_TT_PRICE_MENU_TITLE,
            function()
                -- PriceChatDebug("1 action clicked: true " .. itemLink)
                ShowPriceToChatDialog(itemLink)
            end,
            "secondary"
        )
    end)
end

----------------------------------------------------------------------
-- CRAFT COST DISPLAY
----------------------------------------------------------------------
-- TTC price for one material
local function GetMatPrice(link)
    if not link or link == "" or not ttcAddon then return 0 end
    local info = ttcAddon:GetPriceInfo(link)
    if info then return info.SuggestedPrice or info.Avg or info.SaleAvg or 0 end
    return 0
end

-- Adds up TTC prices for bag and slot pairs
local function GetBagSlotCost(...)
    local cost, args = 0, { ... }
    for i = 1, #args, 2 do
        local bagId, slotIndex = args[i], args[i + 1]
        if bagId and slotIndex then
            cost = cost + GetMatPrice(GetItemLink(bagId, slotIndex))
        end
    end
    return cost
end

-- Adds Total Mat Cost and Market Value to a craft tooltip
local function AddCraftCostLines(tooltip, matCost, resultItemLink)
    if not tooltip or not tooltip.tip then return end
    if not IsTraderTooltipEnabled() then return end
    if not MMM.GetSettings().tt_displayCraftCost then return end

    local marketValue = GetMatPrice(resultItemLink)
    local matText = ZO_CommaDelimitNumber(math.floor(matCost + 0.5))
    local marketText = IsValidPrice(marketValue)
        and ZO_CommaDelimitNumber(math.floor(marketValue + 0.5))
        or GetString(MMM_NO_TTC_DATA)

    tooltip.tip:AddLine(GetString(MMM_CRAFT_TOTAL_MAT_COST), StyleCraftText)
    tooltip.tip:AddLine(matText .. " " .. MMM.goldIcon, StyleCraftGold)
    tooltip.tip:AddLine(GetString(MMM_CRAFT_MARKET_VALUE), StyleCraftText)
    tooltip.tip:AddLine(marketText .. " " .. MMM.goldIcon, StyleCraftGold)
end

----------------------------------------------------------------------
-- HOOKS
----------------------------------------------------------------------
-- Pull the item link out of each hook's arguments
local function bagExtract(bagId, slotIndex)
    if type(bagId) == "number" then return GetItemLink(bagId, slotIndex) end
end

local function dataExtract(data)
    if type(data) == "table" then return data.itemLink, data.purchasePricePerUnit end
    if type(data) == "string" and string.find(data, ":item:") then
        if MMM.TT_PendingListingPrice and MMM.TT_PendingListingPrice.itemLink == data then
            return data, MMM.TT_PendingListingPrice.price
        end
        return data
    end
end

local function linkExtract(a, b, c)
    for _, v in ipairs({ a, b, c }) do
        if type(v) == "string" and string.find(v, "|H.-:item:") then return v end
    end
end

-- Wraps LayoutBagItem for inventory items
local function HookLayoutBagItem(control)
    if not control then return end
    local base = control.LayoutBagItem
    if not base then return end

    control.LayoutBagItem = function(self, bagId, slotIndex, ...)
        local itemLink = bagExtract(bagId, slotIndex)
        if itemLink then MMM.TT_AddPriceLines(self, itemLink) end
        return base(self, bagId, slotIndex, ...)
    end
end

-- Wraps LayoutGuildStoreSearchResult or LayoutStoreWindowItem
local function HookLayoutDataMethod(control, methodName)
    if not control then return end
    local base = control[methodName]
    if not base then return end

    control[methodName] = function(self, data, ...)
        local itemLink, listingPricePerUnit = dataExtract(data)
        if itemLink then MMM.TT_AddPriceLines(self, itemLink, listingPricePerUnit) end
        return base(self, data, ...)
    end
end

-- Wraps LayoutLink for chat links
local function HookLayoutLink(control)
    if not control then return end
    local base = control.LayoutLink
    if not base then return end

    control.LayoutLink = function(self, a, b, c, ...)
        local itemLink = linkExtract(a, b, c)
        if itemLink then MMM.TT_AddPriceLines(self, itemLink) end
        return base(self, a, b, c, ...)
    end
end

local itemSelectedHooked = false
-- Saves the selected browse listing for the TTC keybind
local function HookUpdateItemSelectedTooltip()
    if itemSelectedHooked then return end
    itemSelectedHooked = true
    local base = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.UpdateItemSelectedTooltip

    GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS.UpdateItemSelectedTooltip = function(self, selectedData)
        if selectedData then
            local itemLink
            if selectedData.isGuildSpecificItem then
                itemLink = GetGuildSpecificItemLink(selectedData.slotIndex)
            else
                itemLink = selectedData.itemLink
            end
            if itemLink then
                MMM.TT_PendingListingPrice = { itemLink = itemLink, price = selectedData.purchasePricePerUnit }
            end
        else
            MMM.TT_PendingListingPrice = nil
        end

        return base(self, selectedData)
    end
end

-- Item from the buy dialog, only tracked if the player confirms
local pendingConfirmItemLink = nil
local purchaseConfirmationHooked = false

-- Hooks the instance since the browse results class is local to ESO's file
local function HookGamepadPurchaseConfirmation()
    if purchaseConfirmationHooked then return end
    purchaseConfirmationHooked = true

    -- Buy dialog opened
    ZO_PreHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "ShowPurchaseItemConfirmation", function(self, selectedData)
        pendingConfirmItemLink = selectedData and selectedData.itemLink or nil
    end)

    -- Player confirmed the purchase
    ZO_PreHook("ConfirmPendingItemPurchase", function()
        -- d("DEBUG: ConfirmPendingItemPurchase fired, pendingConfirmItemLink=" .. tostring(pendingConfirmItemLink))
        if pendingConfirmItemLink and ShouldTrackPurchase(pendingConfirmItemLink) then
            pendingPurchaseItemId = GetItemLinkItemId(pendingConfirmItemLink)
            -- pendingPurchaseItemLink = pendingConfirmItemLink
            -- d("MMM DEBUG: pendingPurchaseItemId set to " .. tostring(pendingPurchaseItemId))
        else
            pendingPurchaseItemId = nil
            -- pendingPurchaseItemLink = nil
            -- d("MMM DEBUG: not tracked, pendingPurchaseItemId cleared")
        end
        pendingConfirmItemLink = nil
    end)
end




local tradingHouseRowHooked = false

-- Adds the mail icon and grays out purchased rows
local function HookGamepadTradingHouseRow()
    if tradingHouseRowHooked then return end
    tradingHouseRowHooked = true

    SecurePostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "SetupResultItemRow", function(self, control, itemData)
        local settings = MMM.GetSettings()
        if settings.tt_enabled and itemData and itemData.itemLink then
            local itemId = GetItemLinkItemId(itemData.itemLink)

            -- Still waiting in the mail
            if settings.tt_purchasedIndicator and purchasedItems[itemId] and purchasedItems[itemId] > 0 then
                -- d("MMM DEBUG: SetupResultItemRow marking row for itemId=" .. tostring(itemId))
                if control.nameLabel then
                    local currentText = control.nameLabel:GetText()
                    control.nameLabel:SetText(currentText .. " " .. MMM.IconsFor.MAIL_SYMBOL)
                    control.nameLabel:SetColor(unpack(MMM.DEFAULT_COLORS.disableGray))
                end
                -- In the backpack now
            elseif settings.tt_backpackIndicator and itemsInBackpack[itemId] then
                if control.nameLabel then
                    local currentText = control.nameLabel:GetText()
                    control.nameLabel:SetText(currentText .. " " .. MMM.IconsFor.BAG_SYMBOL)
                end
            end
        end
    end)
end


-- Hooks every gamepad tooltip
function MMM.InstallTooltipHooks()
    if not GAMEPAD_TOOLTIPS then return end

    local leftTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
    local movableTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP)

    -- Bag / inventory items
    HookLayoutBagItem(leftTooltip)
    HookLayoutBagItem(rightTooltip)
    HookLayoutBagItem(movableTooltip)

    -- Guild store search results
    HookLayoutDataMethod(leftTooltip, "LayoutGuildStoreSearchResult")
    HookLayoutDataMethod(rightTooltip, "LayoutGuildStoreSearchResult")
    HookLayoutDataMethod(movableTooltip, "LayoutGuildStoreSearchResult")

    -- listings
    HookLayoutDataMethod(leftTooltip, "LayoutStoreWindowItem")

    -- Chat links
    HookLayoutLink(leftTooltip)
    HookLayoutLink(rightTooltip)
    HookLayoutLink(movableTooltip)
end

-- Hooks each crafting station for the material cost lines
function MMM.InstallCraftHooks()
    -- Alchemy
    if GAMEPAD_ALCHEMY then
        SecurePostHook(GAMEPAD_ALCHEMY, "UpdateTooltip", function(self)
            if not self or not self.IsCraftable or not self:IsCraftable() then return end
            if not self.tooltip then return end
            local itemLink = GetAlchemyResultingItemLink(self:GetAllCraftingBagAndSlots())
            if itemLink and itemLink ~= "" then
                local matCost = GetBagSlotCost(self:GetAllCraftingBagAndSlots())
                AddCraftCostLines(self.tooltip, matCost, itemLink)
            end
        end)
    end

    -- Enchanting
    if GAMEPAD_ENCHANTING then
        SecurePostHook(GAMEPAD_ENCHANTING, "UpdateTooltip", function(self)
            if not self or not self.IsCraftable or not self:IsCraftable() then return end
            if not self.resultTooltip then return end
            local itemLink = GetEnchantingResultingItemLink(self:GetAllCraftingBagAndSlots())
            if itemLink and itemLink ~= "" then
                local matCost = GetBagSlotCost(self:GetAllCraftingBagAndSlots())
                AddCraftCostLines(self.resultTooltip, matCost, itemLink)
            end
        end)
    end

    -- Provisioning
    if GAMEPAD_PROVISIONER then
        SecurePostHook(GAMEPAD_PROVISIONER, "RefreshRecipeDetails", function(self, selectedData)
            if not selectedData or not self.resultTooltip then return end
            local listID, itemID = selectedData.recipeListIndex, selectedData.recipeIndex
            if not listID or not itemID then return end
            local itemLink = GetRecipeResultItemLink(listID, itemID)
            if itemLink and itemLink ~= "" then
                local _, _, numIngredients = GetRecipeInfo(listID, itemID)
                local matCost = 0
                for i = 1, numIngredients do
                    local _, _, qty = GetRecipeIngredientItemInfo(listID, itemID, i)
                    local link = GetRecipeIngredientItemLink(listID, itemID, i)
                    matCost = matCost + (GetMatPrice(link) * qty)
                end
                AddCraftCostLines(self.resultTooltip, matCost, itemLink)
            end
        end)
    end

    -- Smithing creation
    if SMITHING_GAMEPAD and SMITHING_GAMEPAD.creationPanel then
        SecurePostHook(SMITHING_GAMEPAD.creationPanel, "SetupResultTooltip", function(self)
            if not self or not self.resultTooltip then return end
            local patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex =
                self:GetAllCraftingParameters()
            local itemLink = GetSmithingPatternResultLink(
                patternIndex, materialIndex, materialQuantity, itemStyleId, traitIndex)
            if itemLink and itemLink ~= "" then
                local baseLink = GetSmithingPatternMaterialItemLink(patternIndex, materialIndex)
                local styleLink = GetItemStyleMaterialLink(itemStyleId)
                local traitLink = GetSmithingTraitItemLink(traitIndex)
                local matCost = (GetMatPrice(baseLink) * materialQuantity)
                    + GetMatPrice(styleLink) + GetMatPrice(traitLink)
                AddCraftCostLines(self.resultTooltip, matCost, itemLink)
            end
        end)
    end

    -- Smithing improvement
    if SMITHING_GAMEPAD and SMITHING_GAMEPAD.improvementPanel then
        SecurePostHook(SMITHING_GAMEPAD.improvementPanel, "SetupResultTooltip",
            function(self, bagId, slotIndex)
                if not self or not self.resultTooltip then return end
                if not bagId or not slotIndex then
                    bagId, slotIndex = self.inventory:CurrentSelectionBagAndSlot()
                end
                if not bagId or not slotIndex then return end
                local craftingType = GetCraftingInteractionType()
                local itemLink = GetSmithingImprovedItemLink(bagId, slotIndex, craftingType)
                if itemLink and itemLink ~= "" then
                    local quality = GetItemLinkQuality(GetItemLink(bagId, slotIndex))
                    local boosterLink = GetSmithingImprovementItemLink(craftingType, quality)
                    local qty = 1
                    if self.spinner and self.spinner.GetValue then qty = self.spinner:GetValue() end
                    local matCost = GetMatPrice(boosterLink) * qty
                    AddCraftCostLines(self.resultTooltip, matCost, itemLink)
                end
            end)
    end
end

----------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------
function MMM.TT_Initialize()
    -- init addons once
    ttcAddon = TamrielTradeCentrePrice
    -- for the buttons
    ttcItemInfo = TamrielTradeCentre_ItemInfo
    mmAddon = MasterMerchant
    guildStoreLib = LibGuildStore
    InstallPriceToChatAction()
    -- Browse results is created when the guild store first opens, so hook on first show
    TRADING_HOUSE_GAMEPAD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            InjectPriceHistoryKeybind()
            HookUpdateItemSelectedTooltip()
            HookGamepadPurchaseConfirmation()
            HookGamepadTradingHouseRow()
        end
    end)
end
