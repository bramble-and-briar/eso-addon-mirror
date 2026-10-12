
-- ============================================================================
-- When updating the price data, change these:
-- The version on line 10
-- The NOTIFICATION_MESSAGE on line 29
-- ============================================================================

local TSC = {
    name = "TSCPriceFetcher2",
    version = 123
}

-- Local references for performance
local EVENT_MANAGER = EVENT_MANAGER
local zo_callLater = zo_callLater
local ZO_CommaDelimitNumber = ZO_CommaDelimitNumber
local ZO_PostHook = ZO_PostHook
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local MAX_PLAYER_CURRENCY = MAX_PLAYER_CURRENCY
local savedVars -- Will be set after initialization
local notificationProvider

-- Saved variables version and update notification version
local SAVED_VARS_VERSION = 1
local ANNOUNCEMENT_VERSION = TSC.version
local NOTIFICATION_MESSAGE = "TSC Price Fetcher 2 has been updated with new sales data thru Oct 11."

-- Default settings structure
TSC.default = {
    lastSeenAnnouncementVersion = nil,
    autoListAverage = true,
    bumperPriceAdjustment = 5,
    roundingTarget = 100
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function toGold(amount)
    amount = tonumber(amount)
    if not amount then return "0" end
    return ZO_CommaDelimitNumber(amount)
end

-- ============================================================================
-- DATA FUNCTIONS
-- ============================================================================

local function getAvgPrice(itemLink)
    -- Since TSCPriceDataAPI is a library dependency, it will always be available
    return TSCPriceDataAPI:GetPrice(itemLink) -- Returns nil if no data found
end

-- ============================================================================
-- TOOLTIP FUNCTIONS
-- ============================================================================

local function tooltipHasPriceInfo(tooltip)
    if not tooltip then return false end

    -- Check scrollTooltip.contents
    if tooltip.scrollTooltip and tooltip.scrollTooltip.contents and tooltip.scrollTooltip.contents.GetNumChildren then
        local content = tooltip.scrollTooltip.contents
        local numChildren = content:GetNumChildren()
        for i = 1, numChildren do
            local child = content:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("TSC") or text:find("Item Avg") or text:find("Exact Avg") or text:find("Average Price:") or text:find("No Price Data") or text:find("Loading%.%.%.") or text:find("Bound Item")) then
                    return true
                end
            end
        end
    end

    -- Check direct children
    if tooltip.GetNumChildren then
        local numChildren = tooltip:GetNumChildren()
        for i = 1, numChildren do
            local child = tooltip:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("TSC") or text:find("Item Avg") or text:find("Exact Avg") or text:find("Average Price:") or text:find("No Price Data") or text:find("Loading%.%.%.") or text:find("Bound Item")) then
                    return true
                end
            end
        end
    end

    return false
end

local function shouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink)
    -- Must have valid tooltip and tooltip type
    if not tooltipType or not tooltipObject then return false end

    -- Must have a valid item link
    if type(itemLink) ~= "string" or not itemLink:find("^|H%d:item:") then return false end

    -- Must have a valid item name
    local itemName = GetItemLinkName(itemLink)
    if not itemName or itemName == "" then return false end

    -- Must have a valid item type
    local itemType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_NONE then return false end

    return true
end

-- Color: quality-specific price (bright gold); legacy fallback (muted)
local TSC_PRICE_COLOR_QUALITY = "|cDBC14D"  -- gold

local function addPriceToTooltip(tooltip, itemLink)
    local priceSection = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
    if not priceSection then
        return false
    end

    -- Check if item is bound
    if IsItemLinkBound(itemLink) then
        priceSection:AddLine("Bound Item", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return true
    end

    local itemData = TSCPriceDataAPI:GetItemData(itemLink)
    if itemData == TSCPriceDataAPI.LOADING then
        priceSection:AddLine("Loading...", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return true
    end
    if not itemData or not itemData.avgPrice then
        priceSection:AddLine("No Price Data", tooltip:GetStyle("bodyDescription"))
        tooltip:AddSection(priceSection)
        return true
    end

    -- All numbers in gold. Set = legacy; Exact = trait+quality (only shown when we have exact data).
    if itemData.legacyAvg then
        priceSection:AddLine("Item Avg: " .. TSC_PRICE_COLOR_QUALITY .. toGold(itemData.legacyAvg) .. "|r", tooltip:GetStyle("bodyDescription"))
    end
    if itemData.legacyMin and itemData.legacyMax then
        priceSection:AddLine("Item Range: " .. TSC_PRICE_COLOR_QUALITY .. toGold(itemData.legacyMin) .. " - " .. toGold(itemData.legacyMax) .. "|r", tooltip:GetStyle("bodyDescription"))
    end
    if not itemData.fromLegacy then
        priceSection:AddLine("Exact Avg: " .. TSC_PRICE_COLOR_QUALITY .. toGold(itemData.avgPrice) .. "|r", tooltip:GetStyle("bodyDescription"))
        if itemData.commonMin and itemData.commonMax then
            priceSection:AddLine("Exact Range: " .. TSC_PRICE_COLOR_QUALITY .. toGold(itemData.commonMin) .. " - " .. toGold(itemData.commonMax) .. "|r", tooltip:GetStyle("bodyDescription"))
        end
    end

    tooltip:AddSection(priceSection)
    return true
end

local function addPriceToGamepadTooltip(tooltipObject, tooltipType, itemLink)
    if not shouldAddPriceToTooltip(tooltipType, tooltipObject, itemLink) then
        return
    end

    local tooltip = tooltipObject:GetTooltip(tooltipType)
    if not tooltip or tooltipHasPriceInfo(tooltip) then
        return
    end

    -- Just try once with error handling
    pcall(addPriceToTooltip, tooltip, itemLink)
end

-- -----------------------------------------------------------------------------
-- RELEASE: Comment out for console. No PC keyboard tooltip code in release.
-- Comment out: shouldAddPriceToKeyboardTooltip, addPriceToKeyboardTooltip,
-- hookKeyboardTooltips(), and the hookKeyboardTooltips() call in initialize().
-- -----------------------------------------------------------------------------
-- PC keyboard tooltip: ItemTooltip uses AddLine(text, font, r, g, b, ...) not AcquireSection
-- local function shouldAddPriceToKeyboardTooltip(itemLink)
--     if type(itemLink) ~= "string" or not itemLink:find("^|H%d:item:") then return false end
--     local itemName = GetItemLinkName(itemLink)
--     if not itemName or itemName == "" then return false end
--     if GetItemLinkItemType(itemLink) == ITEMTYPE_NONE then return false end
--     return true
-- end

-- local function addPriceToKeyboardTooltip(tooltipControl, itemLink)
--     if not shouldAddPriceToKeyboardTooltip(itemLink) then return end
--     if tooltipHasPriceInfo(tooltipControl) then return end
--     if not tooltipControl.AddLine then return end

--     -- ItemTooltip:AddLine(text, font, r, g, b, lineAnchor, modifyTextType, textAlignment, setToFullSize)
--     -- ZoFontTooltipTitle (22) / ZoFontTooltipSubtitle (18) are larger than ZoFontGamepadBody
--     local keyboardTooltipFont = "ZoFontTooltipTitle"
--     local function addLine(text, r, g, b)
--         r, g, b = r or 1, g or 1, b or 1
--         tooltipControl:AddLine(text, keyboardTooltipFont, r, g, b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, false)
--     end

--     if IsItemLinkBound(itemLink) then
--         addLine("Bound Item", 0.7, 0.7, 0.7)
--         return
--     end

--     local itemData = TSCPriceDataAPI:GetItemData(itemLink)
--     if itemData == TSCPriceDataAPI.LOADING then
--         addLine("Loading...", 0.7, 0.7, 0.7)
--         return
--     end
--     if not itemData or not itemData.avgPrice then
--         addLine("No Price Data", 0.7, 0.7, 0.7)
--         return
--     end

--     local goldR, goldG, goldB = 0.85, 0.75, 0.36
--     if itemData.legacyAvg then
--         addLine("Item Avg: " .. toGold(itemData.legacyAvg), goldR, goldG, goldB)
--     end
--     if itemData.legacyMin and itemData.legacyMax then
--         addLine("Item Range: " .. toGold(itemData.legacyMin) .. " - " .. toGold(itemData.legacyMax), goldR, goldG, goldB)
--     end
--     if not itemData.fromLegacy then
--         addLine("Exact Avg: " .. toGold(itemData.avgPrice), goldR, goldG, goldB)
--         if itemData.commonMin and itemData.commonMax then
--             addLine("Exact Range: " .. toGold(itemData.commonMin) .. " - " .. toGold(itemData.commonMax), goldR, goldG, goldB)
--         end
--     end
-- end

-- ============================================================================
-- UPDATE NOTIFICATION FUNCTIONS
-- ============================================================================

local UPDATE_NOTIFICATION_ID = "TSC_PRICE_DATA_UPDATED"

local function markAnnouncementSeen()
    savedVars.lastSeenAnnouncementVersion = ANNOUNCEMENT_VERSION
end

local function clearUpdateNotification()
    if not notificationProvider then
        return
    end

    local notifications = notificationProvider.notifications
    for i = #notifications, 1, -1 do
        local notification = notifications[i]
        if notification and notification.data and notification.data.id == UPDATE_NOTIFICATION_ID then
            table.remove(notifications, i)
        end
    end

    notificationProvider.UpdateNotifications()
end

local function setupUpdateNotification()
    if savedVars.lastSeenAnnouncementVersion == ANNOUNCEMENT_VERSION then
        return
    end

    if not LibNotification then
        return
    end

    notificationProvider = notificationProvider or LibNotification:CreateProvider()
    table.insert(notificationProvider.notifications, {
        dataType = NOTIFICATIONS_ALERT_DATA,
        secsSinceRequest = ZO_NormalizeSecondsSince(0),
        message = NOTIFICATION_MESSAGE,
        heading = "TSC Price Fetcher",
        texture = "/esoui/art/icons/servicemappins/servicepin_vendor.dds",
        shortDisplayText = "Updated TSC Prices",
        controlsOwnSounds = true,
        keyboardAcceptCallback = clearUpdateNotification,
        keyboardDeclineCallback = clearUpdateNotification,
        gamepadAcceptCallback = clearUpdateNotification,
        gamepadDeclineCallback = clearUpdateNotification,
        data = {
            id = UPDATE_NOTIFICATION_ID
        }
    })

    notificationProvider.UpdateNotifications()
    markAnnouncementSeen()
end

--[[ QR CODE FUNCTIONS (LibQRCode no longer available - buttons use RequestOpenUnsafeURL instead)
local function showQRCode(url, title)
    if not LibQRCode then
        RequestOpenUnsafeURL(url)
        return
    end

    -- Create our own QR code window (copied from LibQRCode but with custom positioning)
    local defaultTextureSize = 200
    local defaultHeaderHeight = 30
    local defaultXInset = 5
    local defaultYInset = 5

    if tscQRWindow == nil then
        -- Create the main window (only once)
        tscQRWindow = WINDOW_MANAGER:CreateTopLevelWindow("TSCQRWindow")
        local windowWidth = defaultTextureSize + 2 * defaultXInset
        local windowHeight = defaultTextureSize + defaultHeaderHeight + 3 * defaultYInset
        tscQRWindow:SetDimensions(windowWidth, windowHeight)

        -- Position at center + 500px offset
        tscQRWindow:SetAnchor(CENTER, GUI_ROOT, CENTER, 500, 0)
        tscQRWindow:SetMovable(true)
        tscQRWindow:SetMouseEnabled(true)
        tscQRWindow:SetClampedToScreen(true)

        -- Create title header
        local header = WINDOW_MANAGER:CreateControl("TSCQRWindowTitle", tscQRWindow, CT_LABEL)
        header:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        header:SetDimensions(defaultTextureSize, defaultHeaderHeight)
        header:SetColor(0.5, 0.5, 1, 1) -- Blue color like original
        header:SetAnchor(TOP, tscQRWindow, TOP, 0, defaultYInset)
        header:SetFont("ZoFontAnnounceMedium")

        -- Add backdrop
        local backdrop = WINDOW_MANAGER:CreateControlFromVirtual("TSCQRCodeBackdrop", tscQRWindow, "ZO_DefaultBackdrop")
        backdrop:SetAnchorFill()
        backdrop:SetDrawTier(DT_LOW)

        -- Add close button
        local closeButton = WINDOW_MANAGER:CreateControl("TSCQRCodeCloseButton", tscQRWindow, CT_BUTTON)
        closeButton:SetDimensions(defaultHeaderHeight, defaultHeaderHeight)
        closeButton:SetAnchor(TOPRIGHT, tscQRWindow, TOPRIGHT, defaultXInset, defaultYInset)
        closeButton:SetHandler("OnClicked", function()
            SCENE_MANAGER:ToggleTopLevel(tscQRWindow)
            tscQRWindow:SetHidden(true)
        end)
        closeButton:SetEnabled(true)
        closeButton:SetNormalTexture("EsoUI/Art/Buttons/closebutton_up.dds")
        closeButton:SetPressedTexture("EsoUI/Art/Buttons/closebutton_down.dds")
        closeButton:SetMouseOverTexture("EsoUI/Art/Buttons/closebutton_mouseover.dds")
        closeButton:EnableMouseButton(MOUSE_BUTTON_INDEX_LEFT, true)
    else
        -- Window already exists, just show it
        SCENE_MANAGER:ToggleTopLevel(tscQRWindow)
        tscQRWindow:SetHidden(false)
    end

    -- Update the title
    local header = WINDOW_MANAGER:GetControlByName("TSCQRWindowTitle")
    if header then
        header:SetText(title or "QR Code")
    end

    -- Create or update QR code
    if tscQRContainer == nil then
        tscQRContainer = LibQRCode.CreateQRControl(defaultTextureSize, url)
    else
        LibQRCode.DrawQRCode(tscQRContainer, url)
    end

    tscQRContainer:SetParent(tscQRWindow)
    tscQRContainer:SetAnchor(TOPLEFT, tscQRWindow, TOPLEFT, defaultXInset, defaultHeaderHeight + 2 * defaultYInset)
    tscQRContainer:SetAnchor(BOTTOMRIGHT, tscQRWindow, BOTTOMRIGHT, -defaultXInset, -defaultYInset)

    -- Auto-hide after 10 seconds
    zo_callLater(function()
        if not tscQRWindow:IsHidden() then
            tscQRWindow:SetHidden(true)
        end
    end, 10000)
end
--]]

-- ============================================================================
-- SETTINGS FUNCTIONS
-- ============================================================================

local function initializeSavedVars()
    -- Initialize account-wide saved variables only
    TSC.savedVars = ZO_SavedVars:NewAccountWide(
        "TSCPriceFetcherSavedData", SAVED_VARS_VERSION, nil, TSC.default)

    -- Set local reference for performance
    savedVars = TSC.savedVars

    -- Handle migration by adding any missing default fields
    if TSC.savedVars.version ~= SAVED_VARS_VERSION then
        for key, defaultValue in pairs(TSC.default) do
            if TSC.savedVars[key] == nil then
                TSC.savedVars[key] = defaultValue
            end
        end
        TSC.savedVars.version = SAVED_VARS_VERSION
    end
end

local function setupSettingsMenu()
    local LHAS = LibHarvensAddonSettings
    if not LHAS then
        CHAT_ROUTER:AddSystemMessage("LibHarvensAddonSettings not found - settings menu will not be available")
        return
    end

    local options = {
        allowDefaults = true,         --will allow users to reset the settings to default values
        allowRefresh = true,          --if this is true, when one of settings is changed, all other settings will be checked for state change (disable/enable)
        defaultsFunction = function() --this function is called when allowDefaults is true and user hit the reset button
            d("Reset")
        end,
    }
    --Create settings "container" for your addon
    --First parameter is the name that will be displayed in the options,
    --Second parameter is the options table (it is optional)
    local settings = LHAS:AddAddon("TSC Price Fetcher", options)
    if not settings then
        return
    end

    --[[
        INFORMATION SECTION
    --]]
    local informationSection = {
        type = LHAS.ST_SECTION,
        label = "Information",
    }
    settings:AddSetting(informationSection)

    --[[ QR version (uncomment when LibQRCode available; comment out URL version below)
    local bugReportButton = {
        type = LHAS.ST_BUTTON,
        label = "Troubleshoot",
        tooltip = "Generate a QR code that will link to the FAQ + Troubleshooting page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://tamrielsavings.com/faq", "Troubleshoot")
        end,
    }
    --]]
    local bugReportButton = {
        type = LHAS.ST_BUTTON,
        label = "Troubleshoot",
        tooltip = "Open the FAQ + Troubleshooting page on tamrielsavings.com",
        buttonText = "Open Link",
        clickHandler = function(control, button)
            RequestOpenUnsafeURL("https://tamrielsavings.com/faq")
        end,
    }
    settings:AddSetting(bugReportButton)

    --[[ QR version (uncomment when LibQRCode available; comment out URL version below)
    local discordButton = {
        type = LHAS.ST_BUTTON,
        label = "Join TSC on Discord",
        tooltip = "Generate a QR code that will link to the TSC Discord server",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://discord.gg/7DzUVCQ", "Join TSC on Discord")
        end,
    }
    --]]
    local discordButton = {
        type = LHAS.ST_BUTTON,
        label = "Join TSC on Discord",
        tooltip = "Open the TSC Discord server invite",
        buttonText = "Open Link",
        clickHandler = function(control, button)
            RequestOpenUnsafeURL("https://discord.gg/7DzUVCQ")
        end,
    }
    settings:AddSetting(discordButton)

    --[[ QR version (uncomment when LibQRCode available; comment out URL version below)
    local donateButton = {
        type = LHAS.ST_BUTTON,
        label = "Donate to TSC",
        tooltip = "Generate a QR code that will link to the Donate page on tamrielsavings.com",
        buttonText = "Open QR Code",
        clickHandler = function(control, button)
            showQRCode("https://tamrielsavings.com/donations", "Donate to TSC")
        end,
    }
    --]]
    local donateButton = {
        type = LHAS.ST_BUTTON,
        label = "Donate to TSC",
        tooltip = "Open the Donate page on tamrielsavings.com",
        buttonText = "Open Link",
        clickHandler = function(control, button)
            RequestOpenUnsafeURL("https://tamrielsavings.com/donations")
        end,
    }
    settings:AddSetting(donateButton)

    --[[
        TRADING SETTINGS SECTION
    --]]
    local tradingSettingsSection = {
        type = LHAS.ST_SECTION,
        label = "Item Listing Settings",
    }
    settings:AddSetting(tradingSettingsSection)

    --Define checkbox table
    local autoListAverage = {
        type = LHAS.ST_CHECKBOX,
        label = "Auto List Average",
        tooltip =
        "Setting this ON will cause an item to be listed at the average price of the item.  Setting this OFF will use the game default price",
        default = true,               --default value, only used when options.allowDefaults == true (optional)
        setFunction = function(state) --this function is called when the setting is changed
            savedVars.autoListAverage = state
        end,
        getFunction = function() --this function is called to set initial state of the checkbox
            return savedVars.autoListAverage
        end,
    }
    settings:AddSetting(autoListAverage)

    local bumperPriceAdjustment = {
        type = LHAS.ST_SLIDER,
        label = "Bumper Price Adjustment",
        tooltip = "Use bumpers to adjust the current listing price by the chosen percentage of the TSC average",
        setFunction = function(value)
            savedVars.bumperPriceAdjustment = value
        end,
        getFunction = function()
            return savedVars.bumperPriceAdjustment
        end,
        default = 5,
        min = 1,
        max = 10,
        step = 1,
        unit = "%",
        format = "%d",
        disable = function() return false end,
    }
    settings:AddSetting(bumperPriceAdjustment)

    local roundingTarget = {
        type = LHAS.ST_DROPDOWN,
        label = "Price Rounding Target",
        tooltip =
        "Use triggers to round prices up or down to the nearest chosen value (10, 100, or 1000).",
        setFunction = function(combobox, name, item)
            savedVars.roundingTarget = item.data
        end,
        getFunction = function()
            local target = savedVars.roundingTarget or 100
            if target == 10 then return "10" end
            if target == 100 then return "100" end
            if target == 1000 then return "1000" end
            return "100"
        end,
        default = "100",
        items = {
            {
                name = "10",
                data = 10
            },
            {
                name = "100",
                data = 100
            },
            {
                name = "1000",
                data = 1000
            },
        },
        disable = function() return false end,
    }
    settings:AddSetting(roundingTarget)
end

-- ============================================================================
-- ACTION FUNCTIONS
-- ============================================================================

-- Reusable logic for round and bump actions
local function TSC_PerformRound(up)
    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD then
        local self = TRADING_HOUSE_CREATE_LISTING_GAMEPAD
        local roundingTarget = savedVars.roundingTarget or TSC.default.roundingTarget
        local currentPrice = self.listingPrice
        if currentPrice and currentPrice >= 0 then
            local newPrice
            if currentPrice % roundingTarget == 0 then
                if up then
                    newPrice = math_min(currentPrice + roundingTarget, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_max(currentPrice - roundingTarget, 0)
                end
            else
                if up then
                    newPrice = math_min(math_ceil(currentPrice / roundingTarget) * roundingTarget, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_floor(currentPrice / roundingTarget) * roundingTarget
                end
            end
            self:SetListingPrice(newPrice)
        end
    end
end

local function TSC_PerformBump(up)
    if TRADING_HOUSE_CREATE_LISTING_GAMEPAD then
        local self = TRADING_HOUSE_CREATE_LISTING_GAMEPAD
        local currentAdjustment = savedVars.bumperPriceAdjustment or TSC.default.bumperPriceAdjustment
        local currentPrice = self.listingPrice
        if currentPrice and currentPrice >= 0 then
            local itemLink = GetItemLink(self.itemBag, self.itemIndex)
            local avgPricePerUnit = getAvgPrice(itemLink)
            if avgPricePerUnit and type(avgPricePerUnit) == "number" then
                local stackCount = GetSlotStackSize(self.itemBag, self.itemIndex)
                local avgPriceTotal = avgPricePerUnit * stackCount
                local adjustmentAmount = math_floor(avgPriceTotal * currentAdjustment / 100)
                local newPrice
                if up then
                    newPrice = math_min(currentPrice + adjustmentAmount, MAX_PLAYER_CURRENCY)
                else
                    newPrice = math_max(currentPrice - adjustmentAmount, 0)
                end
                self:SetListingPrice(newPrice)
            end
        end
    end
end

-- ============================================================================
-- GLOBAL FUNCTIONS (for keybindings)
-- ============================================================================

function TSCPriceFetcher_RoundUp()
    TSC_PerformRound(true)
end

function TSCPriceFetcher_RoundDown()
    TSC_PerformRound(false)
end

function TSCPriceFetcher_BumpUp()
    TSC_PerformBump(true)
end

function TSCPriceFetcher_BumpDown()
    TSC_PerformBump(false)
end

-- ============================================================================
-- KEYBIND GROUP DEFINITION
-- ============================================================================

local tradingKeybindGroup = {
    {
        name = "Bump Down",
        order = -3000,
        keybind = "UI_SHORTCUT_LEFT_SHOULDER",
        callback = function()
            TSC_PerformBump(false)
        end,
    },
    {
        name = "Bump Up",
        order = -4000,
        keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
        callback = function()
            TSC_PerformBump(true)
        end,
    },
    {
        name = "Round Down",
        order = -1000,
        keybind = "UI_SHORTCUT_LEFT_TRIGGER",
        callback = function()
            TSC_PerformRound(false)
        end,
    },
    {
        name = "Round Up",
        order = -2000,
        keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
        callback = function()
            TSC_PerformRound(true)
        end,
    }
}

-- ============================================================================
-- HOOK FUNCTIONS
-- ============================================================================

-- RELEASE: Comment out this function and its call in initialize() (see RELEASE block above shouldAddPriceToKeyboardTooltip for full list).
-- local function hookKeyboardTooltips()
--     if not ItemTooltip then return end
--     ZO_PostHook(ItemTooltip, "SetLink", function(self, itemLink)
--         pcall(addPriceToKeyboardTooltip, self, itemLink)
--     end)
--     ZO_PostHook(ItemTooltip, "SetBagItem", function(self, bagId, slotIndex)
--         local itemLink = GetItemLink(bagId, slotIndex)
--         if itemLink and itemLink ~= "" then
--             pcall(addPriceToKeyboardTooltip, self, itemLink)
--         end
--     end)
-- end

local function hookGamepadTooltips()
    local function OnPlayerActivated()
        EVENT_MANAGER:UnregisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED)

        zo_callLater(function()
            if GAMEPAD_TOOLTIPS then
                local leftTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
                local rightTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)

                -- Hook into LEFT tooltip: only the earliest available function
                if leftTooltip then
                    if leftTooltip.AddItemTitle then
                        ZO_PostHook(leftTooltip, "AddItemTitle", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    elseif leftTooltip.LayoutGenericItem then
                        ZO_PostHook(leftTooltip, "LayoutGenericItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    else
                        ZO_PostHook(leftTooltip, "LayoutItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_LEFT_TOOLTIP, itemLink)
                        end)
                    end
                end

                -- Hook into RIGHT tooltip: only the earliest available function
                if rightTooltip then
                    if rightTooltip.AddItemTitle then
                        ZO_PostHook(rightTooltip, "AddItemTitle", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    elseif rightTooltip.LayoutGenericItem then
                        ZO_PostHook(rightTooltip, "LayoutGenericItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    else
                        ZO_PostHook(rightTooltip, "LayoutItem", function(self, itemLink)
                            addPriceToGamepadTooltip(GAMEPAD_TOOLTIPS,
                                GAMEPAD_RIGHT_TOOLTIP, itemLink)
                        end)
                    end
                end
            end
        end, 1000)
    end

    EVENT_MANAGER:RegisterForEvent("TSCUniversalContext", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

local function setupCreateListingHooks()
    if ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing then
        ZO_PostHook("ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing",
            function(selectedData, bag, index, listingPrice)
                -- Only auto-set price if the setting is enabled
                if not savedVars.autoListAverage then
                    return
                end

                local itemLink = GetItemLink(bag, index)

                local avgPricePerUnit = getAvgPrice(itemLink)
                if avgPricePerUnit and type(avgPricePerUnit) == "number" then
                    local stackCount = GetSlotStackSize(bag, index)
                    local ourPrice = avgPricePerUnit * stackCount

                    if ourPrice ~= listingPrice then
                        -- Wait for UI to be fully initialized, then set our price
                        zo_callLater(function()
                            if TRADING_HOUSE_CREATE_LISTING_GAMEPAD and TRADING_HOUSE_CREATE_LISTING_GAMEPAD.SetListingPrice then
                                TRADING_HOUSE_CREATE_LISTING_GAMEPAD:SetListingPrice(ourPrice)
                            end
                        end, 200)
                    end
                end
            end
        )
    end
end



-- ============================================================================
-- KEYBIND MANAGEMENT
-- ============================================================================


local function addTradingKeybinds()
    KEYBIND_STRIP:AddKeybindButtonGroup(tradingKeybindGroup)
end

-- NEW METHOD TO REMOVE KEYBINDS FROM MIDNITE
local previousScene = ""
local function removeTradingKeybinds()
    if previousScene == "gamepad_trading_house_create_listing" then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tradingKeybindGroup)
        -- need to push and pop keybind group to restore system bindings
        KEYBIND_STRIP:PushKeybindGroupState()
        KEYBIND_STRIP:PopKeybindGroupState()
    end
end

-- NEW METHOD TO ADD KEYBINDS FROM MIDNITE
local function setupTradingHouseKeybinds()

    -- Add keybinds when entering trading house create listing scene
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, newState)
        local sceneName = scene:GetName()
        -- Remove keybinds when leaving trading house
        EVENT_MANAGER:RegisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE, function()
            removeTradingKeybinds()
            EVENT_MANAGER:UnregisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE)
        end)

        -- Check for the correct trading house create listing scene
        if newState == SCENE_SHOWING and sceneName == "gamepad_trading_house_create_listing" then
            addTradingKeybinds()
        elseif  newState == SCENE_SHOWING and sceneName == "gamepad_trading_house" then
            removeTradingKeybinds()
            EVENT_MANAGER:UnregisterForEvent("OnGuildStoreClosed", EVENT_CLOSE_TRADING_HOUSE)
        end
        previousScene = sceneName
    end)
end

-- ============================================================================
-- INITIALIZATION FUNCTIONS
-- ============================================================================

-- Flag to track if the addon is initialized
local isInitialized = false

local function initialize()
    if isInitialized then
        return
    end

    -- Set up existing hooks
    -- hookKeyboardTooltips()  -- RELEASE: comment out for console release
    hookGamepadTooltips()
    setupCreateListingHooks()
    setupTradingHouseKeybinds()

    setupUpdateNotification()
    setupSettingsMenu()
    isInitialized = true
end


-- ============================================================================
-- STRING IDS (for keybindings)
-- ============================================================================

ZO_CreateStringId("SI_BINDING_NAME_TSC_ROUND_UP", "Round Up")
ZO_CreateStringId("SI_BINDING_NAME_TSC_ROUND_DOWN", "Round Down")
ZO_CreateStringId("SI_BINDING_NAME_TSC_BUMP_UP", "Bump Up")
ZO_CreateStringId("SI_BINDING_NAME_TSC_BUMP_DOWN", "Bump Down")

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

-- ============================================================================
-- ADDON SETUP
-- ============================================================================

-- Make it globally accessible (needed for ESO addon structure)
_G.TSCPriceFetcher = TSC

-- Register events directly
EVENT_MANAGER:RegisterForEvent(TSC.name, EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == TSC.name then
        -- Initialize saved variables first
        initializeSavedVars()

        -- Initialize the addon
        initialize()

        EVENT_MANAGER:UnregisterForEvent(TSC.name, EVENT_ADD_ON_LOADED)
    end
end)

EVENT_MANAGER:RegisterForEvent(TSC.name, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(TSC.name, EVENT_PLAYER_ACTIVATED)
end)
