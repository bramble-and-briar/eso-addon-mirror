local MAJOR = "LibGamepadContextMenuBridge"
local MINOR = 154
local ADDON_VERSION = "1.5.4"

local existing = _G[MAJOR]
if existing and existing.minor and existing.minor >= MINOR then
    return
end

local bridge = existing or {}
_G[MAJOR] = bridge

bridge.major = MAJOR
bridge.minor = MINOR
bridge.enabled = true
bridge.debug = bridge.debug or false
bridge._initialized = false
bridge._discoverHooked = false
bridge._refreshHooked = false
bridge._settingsPanelRegistered = bridge._settingsPanelRegistered or false
bridge._slashCommandsRegistered = bridge._slashCommandsRegistered or false
bridge._tooltipPriceHooked = bridge._tooltipPriceHooked or false
bridge._tradingHouseTooltipHooked = bridge._tradingHouseTooltipHooked or false
bridge._playerActivatedHookRegistered = bridge._playerActivatedHookRegistered or false
bridge._debugLog = bridge._debugLog or {}
bridge._stringIdByLabel = bridge._stringIdByLabel or {}
bridge._nextStringIdIndex = bridge._nextStringIdIndex or 1
bridge._tooltipTtcCache = bridge._tooltipTtcCache or {}
bridge._formattedTooltipLineCache = bridge._formattedTooltipLineCache or {}
bridge._tooltipTtcCacheSize = bridge._tooltipTtcCacheSize or 0
bridge._formattedTooltipLineCacheSize = bridge._formattedTooltipLineCacheSize or 0
bridge._overlayWindow = bridge._overlayWindow or nil
bridge._craftingStationActive = bridge._craftingStationActive or false
bridge._templateCraftingOverlayActive = bridge._templateCraftingOverlayActive or false

local SAVED_VARS_NAME = MAJOR .. "_SavedVars"
local SAVED_VARS_VERSION = 1
local DEFAULTS = {
    enabled = true,
    debug = false,
    debugVerbose = false,
    debugToChat = true,
    debugStoreHistory = true,
    maxDebugMessages = 200,
    debugLog = {},
    showTtcPriceInTooltip = true,
    showTtcPriceDetailsInTooltip = false,
    showJunkStatusInTooltip = true,
    showVendorPriceInTooltip = true,
}


local function TrimString(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetDebugTimestamp()
    return tostring(GetTimeStamp())
end

function bridge:_addDebugHistory(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    local entry = string.format("%s %s", GetDebugTimestamp(), message)
    self._debugLog[#self._debugLog + 1] = entry

    -- Also persist to SavedVars so the log survives /reloadui and is written to disk.
    if self.savedVars then
        if type(self.savedVars.debugLog) ~= "table" then
            self.savedVars.debugLog = {}
        end
        local sv = self.savedVars.debugLog
        sv[#sv + 1] = entry
        -- Keep SavedVars log bounded (max 500 lines to avoid giant file).
        local svLimit = 500
        while #sv > svLimit do
            table.remove(sv, 1)
        end
    end

    local limit = DEFAULTS.maxDebugMessages
    if self.savedVars and tonumber(self.savedVars.maxDebugMessages) then
        limit = math.max(20, tonumber(self.savedVars.maxDebugMessages))
    end

    while #self._debugLog > limit do
        table.remove(self._debugLog, 1)
    end
end

function bridge:_debugMessage(message, verboseOnly)
    if not self.debug then
        return
    end

    if verboseOnly and not self.debugVerbose then
        return
    end

    local formatted = string.format("[%s] %s", MAJOR, tostring(message))

    if not self.savedVars or self.savedVars.debugStoreHistory ~= false then
        self:_addDebugHistory(formatted)
    end

    if not self.savedVars or self.savedVars.debugToChat ~= false then
        d(formatted)
    end
end

local function LogDebug(message)
    bridge:_debugMessage(message, false)
end

local function LogTrace(message)
    bridge:_debugMessage(message, true)
end

local function RunExternalAction(callback)
    -- External action callbacks may fail after side effects; never retry them.
    local ok, err = pcall(callback)
    if not ok then
        LogDebug("Menu callback failed: " .. tostring(err))
    end
end

local function EvaluateValue(value, ...)
    if type(value) == "function" then
        return value(...)
    end
    return value
end

local function IsValidItemLink(link)
    return type(link) == "string" and link:find("|H") ~= nil
end

function bridge:_makeCraftContext(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex)
    return {
        patternIndex = patternIndex,
        materialIndex = materialIndex,
        materialQuantity = materialQuantity,
        styleIndex = styleIndex,
        traitIndex = traitIndex,
    }
end

function bridge:_makeRecipeCraftContext(recipeListIndex, recipeIndex, selectedData)
    local context = {
        recipeListIndex = recipeListIndex,
        recipeIndex = recipeIndex,
    }
    if type(selectedData) == "table" then
        context.selectedData = selectedData
    end
    return context
end

local function ResolveCategory(lcm, category)
    return zo_clamp(tonumber(category) or lcm.CATEGORY_LATE, lcm.CATEGORY_EARLY, lcm.CATEGORY_LATE)
end

local function ResolveLabel(value, contextControl)
    value = EvaluateValue(value, ZO_Menu, contextControl)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        value = GetString(value)
    elseif type(value) ~= "string" then
        value = tostring(value)
    end
    return value ~= "" and value or nil
end

local function IsDividerLabel(label)
    if not label then
        return true
    end

    if label == "-" then
        return true
    end

    if type(LibCustomMenu) == "table" and label == LibCustomMenu.DIVIDER then
        return true
    end

    return false
end

local function CollectExistingActionNames(slotActions)
    local names = {}
    for _, action in ipairs(slotActions.m_slotActions) do
        names[action[1]] = true
    end
    return names
end

local function StampActionLabel(slotActions, label, callback)
    -- ESO stores action name/callback at indices 1/2. Named aliases support
    -- third-party dialogs that consume the same action table.
    local entry = slotActions.m_slotActions[#slotActions.m_slotActions]
    entry.name = label
    entry.actionName = label
end

function bridge:_ensureActionStringId(label)
    local id = self._stringIdByLabel[label]
    if not id then
        local name = string.format("SI_LGCMB_ACTION_%d", self._nextStringIdIndex)
        self._nextStringIdIndex = self._nextStringIdIndex + 1
        ZO_CreateStringId(name, label)
        id = _G[name]
        self._stringIdByLabel[label] = id
    end
    return id
end

function bridge:_readContextMenuRegistry()
    return LibCustomMenu.contextMenuRegistry
end

function bridge:_summarizeContextRegistry()
    local registry = self:_readContextMenuRegistry().callbackRegistry
    local chunks, total = {}, 0
    for category = LibCustomMenu.CATEGORY_EARLY, LibCustomMenu.CATEGORY_LATE do
        local count = 0
        for _, entry in ipairs(registry and registry[category] or {}) do
            if not entry[3] then
                count = count + 1
            end
        end
        total = total + count
        chunks[#chunks + 1] = string.format("%d:%d", category, count)
    end
    return table.concat(chunks, ","), total
end

function bridge:_resolveNormalizedSlotType(inventorySlot, slotType)
    if slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM then
        return slotType
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bagId == nil or slotIndex == nil then
        return slotType
    end
    if bagId == BAG_BACKPACK then
        return SLOT_TYPE_ITEM
    elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
        return SLOT_TYPE_BANK_ITEM
    elseif bagId == BAG_GUILDBANK then
        return SLOT_TYPE_GUILD_BANK_ITEM
    end
    return slotType
end

function bridge:_resolveBagAndSlot(inventorySlot)
    if not inventorySlot then
        return nil, nil
    end
    return ZO_Inventory_GetBagAndIndex(inventorySlot)
end

function bridge:_buildNativeJunkAction(inventorySlot)
    local bagId, slotIndex = self:_resolveBagAndSlot(inventorySlot)
    if bagId == nil or slotIndex == nil or bagId == BAG_VIRTUAL then
        return nil
    end
    local isJunk = IsItemJunk(bagId, slotIndex)
    if not isJunk and (IsItemPlayerLocked(bagId, slotIndex) or not CanItemBeMarkedAsJunk(bagId, slotIndex)) then
        return nil
    end
    return {
        label = GetString(isJunk and SI_ITEM_ACTION_UNMARK_AS_JUNK or SI_ITEM_ACTION_MARK_AS_JUNK),
        callback = function()
            SetItemIsJunk(bagId, slotIndex, not isJunk)
        end,
    }
end

function bridge:RegisterContextMenu(callback, category, ...)
    if type(callback) ~= "function" then
        return false
    end
    LibCustomMenu:RegisterContextMenu(callback, ResolveCategory(LibCustomMenu, category), ...)
    return true
end

function bridge:SetEnabled(enabled)
    self.enabled = not not enabled
    if self.savedVars then
        self.savedVars.enabled = self.enabled
    end
    if not self.enabled then
        self:_hideOverlay()
    end
    LogDebug("Bridge enabled: " .. tostring(self.enabled))
end

function bridge:SetDebugEnabled(enabled)
    self.debug = not not enabled
    if self.savedVars then
        self.savedVars.debug = self.debug
    end
    self:_debugMessage("Debug enabled: " .. tostring(self.debug), false)
end

function bridge:SetDebugVerbose(enabled)
    self.debugVerbose = not not enabled
    if self.savedVars then
        self.savedVars.debugVerbose = self.debugVerbose
    end
    self:_debugMessage("Debug verbose: " .. tostring(self.debugVerbose), false)
end

function bridge:SetShowTtcPriceInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showTtcPriceInTooltip = value
    end
end

function bridge:SetShowTtcPriceDetailsInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showTtcPriceDetailsInTooltip = value
    end
end

function bridge:SetShowJunkStatusInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showJunkStatusInTooltip = value
    end
end

function bridge:SetShowVendorPriceInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showVendorPriceInTooltip = value
    end
end

function bridge:ClearDebugLog()
    self._debugLog = {}
    if self.savedVars then
        self.savedVars.debugLog = {}
    end
    self:_debugMessage("Debug log cleared", false)
end

function bridge:DumpDebugLog(limit)
    local count = #self._debugLog
    if count == 0 then
        d(string.format("[%s] Debug log is empty", MAJOR))
        return
    end

    local maxLines = tonumber(limit) or 40
    if maxLines < 1 then
        maxLines = 1
    end

    local startIndex = math.max(1, count - maxLines + 1)
    d(string.format("[%s] Debug log (%d entries, showing %d..%d)", MAJOR, count, startIndex, count))
    for i = startIndex, count do
        d(self._debugLog[i])
    end
end

function bridge:DumpRuntimeStatus()
    local summary, total = self:_summarizeContextRegistry()
    local overlayVisible = false
    if self._overlayWindow and self._overlayWindow.window then
        overlayVisible = not self._overlayWindow.window:IsHidden()
    end

    d(string.format(
        "[%s] enabled=%s debug=%s verbose=%s overlay=%s initialized=%s",
        MAJOR,
        tostring(self.enabled),
        tostring(self.debug),
        tostring(self.debugVerbose),
        tostring(overlayVisible),
        tostring(self._initialized)
    ))
    d(string.format(
        "[%s] hooks tooltip=%s crafting=%s tradingHouse=%s discover=%s refresh=%s playerActivated=%s",
        MAJOR,
        tostring(self._tooltipPriceHooked),
        tostring(self._craftingTooltipsHooked == true),
        tostring(self._tradingHouseTooltipHooked),
        tostring(self._discoverHooked),
        tostring(self._refreshHooked),
        tostring(self._playerActivatedHookRegistered)
    ))
    d(string.format(
        "[%s] overlay created=%s visible=%s cachedLines=%d formattedCache=%d",
        MAJOR,
        tostring(self._overlayWindow ~= nil),
        tostring(overlayVisible),
        tonumber(self._tooltipTtcCacheSize or 0),
        tonumber(self._formattedTooltipLineCacheSize or 0)
    ))
    d(string.format(
        "[%s] settings TTC=%s TTCdetails=%s junk=%s vendor=%s registry=%d (%s)",
        MAJOR,
        tostring(self:_shouldShowTtcTooltipPrice()),
        tostring(self:_shouldShowTtcTooltipDetails()),
        tostring(self:_shouldShowJunkStatusInTooltip()),
        tostring(self:_shouldShowVendorPriceInTooltip()),
        tonumber(total or 0),
        tostring(summary)
    ))
end

function bridge:_initializeSavedVars()
    if self.savedVars then
        return
    end

    self.savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, DEFAULTS)
    self.enabled = self.savedVars.enabled ~= false
    self.debug = self.savedVars.debug == true
    self.debugVerbose = self.savedVars.debugVerbose == true
    -- Restore in-memory log from persisted SavedVars log.
    if type(self.savedVars.debugLog) == "table" then
        for _, v in ipairs(self.savedVars.debugLog) do
            self._debugLog[#self._debugLog + 1] = v
        end
    else
        self.savedVars.debugLog = {}
    end
    LogTrace("SavedVars loaded")
end

function bridge:_shouldShowTtcTooltipPrice()
    return not not (not self.savedVars or self.savedVars.showTtcPriceInTooltip ~= false)
end

function bridge:_shouldShowTtcTooltipDetails()
    return self.savedVars and self.savedVars.showTtcPriceDetailsInTooltip == true
end

function bridge:_shouldShowJunkStatusInTooltip()
    return not not (not self.savedVars or self.savedVars.showJunkStatusInTooltip ~= false)
end

function bridge:_shouldShowVendorPriceInTooltip()
    return not not (not self.savedVars or self.savedVars.showVendorPriceInTooltip ~= false)
end

function bridge:_shouldShowTemplateCraftingOverlay()
    return self._templateCraftingOverlayActive == true
end

function bridge:_getTtcPriceInfo(itemLink)
    -- TTC is optional; once loaded, use its documented public price provider.
    if not TamrielTradeCentrePrice or not IsValidItemLink(itemLink) then
        return nil
    end
    return TamrielTradeCentrePrice:GetPriceInfo(itemLink)
end

function bridge:_getTtcPriceTableUpdatedText()
    if TamrielTradeCentrePrice then
        return TamrielTradeCentrePrice:GetPriceTableUpdatedDateString()
    end
end

function bridge:_formatTtcCurrency(value)
    if type(value) == "number" then
        return ZO_CurrencyControl_FormatCurrency(math.floor(value + 0.5), true)
    end
end

function bridge:_formatTooltipInfoCurrency(value)
    return self:_formatTtcCurrency(value)
end

function bridge:_formatCompactTooltipCurrency(value)
    if type(value) ~= "number" then
        return nil
    end

    value = math.floor(value + 0.5)

    local suffix = nil
    local scaled = value
    if value >= 1000000 then
        scaled = value / 1000000
        suffix = "кк"
    elseif value >= 1000 then
        scaled = value / 1000
        suffix = "к"
    end

    if not suffix then
        return tostring(value)
    end

    local precision = scaled >= 10 and 0 or 1
    local text = string.format("%0." .. tostring(precision) .. "f", scaled)
    text = text:gsub("([%.%,]0+)$", "")
    text = text:gsub("%.$", "")
    text = text:gsub("%,$", "")
    return text .. suffix
end

function bridge:_getTooltipTtcCacheKey(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    return table.concat({
        itemLink,
        tostring(self:_shouldShowTtcTooltipPrice()),
        tostring(self:_shouldShowTtcTooltipDetails()),
    }, "|")
end

function bridge:_getCachedTtcTooltipLines(itemLink)
    local cacheKey = self:_getTooltipTtcCacheKey(itemLink)
    if not cacheKey then
        return nil
    end

    local cached = self._tooltipTtcCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    local lines = {}
    if self:_shouldShowTtcTooltipPrice() then
        local priceInfo = self:_getTtcPriceInfo(itemLink)
        if type(priceInfo) == "table" then
            local primaryPrice = priceInfo.SuggestedPrice or priceInfo.Avg or priceInfo.Min
            local primaryPriceText = self:_formatTooltipInfoCurrency(primaryPrice)
            if type(primaryPriceText) == "string" and primaryPriceText ~= "" then
                lines[#lines + 1] = "TTC: " .. primaryPriceText
            end

            if self:_shouldShowTtcTooltipDetails() then
                local minPriceText = self:_formatCompactTooltipCurrency(priceInfo.Min or primaryPrice)
                local avgPriceText = self:_formatCompactTooltipCurrency(priceInfo.Avg or primaryPrice)
                local maxPriceText = self:_formatCompactTooltipCurrency(priceInfo.Max or primaryPrice)
                if minPriceText and avgPriceText and maxPriceText then
                    lines[#lines + 1] = string.format("Min/Avg/Max: %s / %s / %s", minPriceText, avgPriceText, maxPriceText)
                end
            end
        end
    end

    if self._tooltipTtcCache[cacheKey] == nil then
        self._tooltipTtcCacheSize = (self._tooltipTtcCacheSize or 0) + 1
        if self._tooltipTtcCacheSize > 256 then
            self._tooltipTtcCache = {}
            self._tooltipTtcCacheSize = 0
        end
    end

    self._tooltipTtcCache[cacheKey] = lines
    return lines
end

function bridge:_getItemLinkFromBagAndSlot(bagId, slotIndex)
    if bagId ~= nil and slotIndex ~= nil then
        local link = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
        return link ~= "" and link or nil
    end
end

function bridge:_getVendorPriceText(bagId, slotIndex)
    if self:_shouldShowVendorPriceInTooltip() then
        local value = GetItemSellValueWithBonuses(bagId, slotIndex)
        if value > 0 then
            return "Vendor: " .. self:_formatTooltipInfoCurrency(value)
        end
    end
end

function bridge:_getJunkStatusText(bagId, slotIndex)
    if self:_shouldShowJunkStatusInTooltip() then
        if IsItemJunk(bagId, slotIndex) then
            return "Junk: Yes"
        elseif CanItemBeMarkedAsJunk(bagId, slotIndex) then
            return "Junk: No"
        end
    end
end

function bridge:_isBoundItem(bagId, slotIndex, itemLink)
    if bagId ~= nil and slotIndex ~= nil then
        return IsItemBound(bagId, slotIndex)
    end
    return IsValidItemLink(itemLink) and IsItemLinkBound(itemLink) or false
end

function bridge:_buildTooltipInfoLines(bagId, slotIndex)
    local lines = {}
    local itemLink = self:_getItemLinkFromBagAndSlot(bagId, slotIndex)
    if self:_isBoundItem(bagId, slotIndex, itemLink) then
        return lines
    end

    local stackCount = GetSlotStackSize(bagId, slotIndex)
    if itemLink then
        local linkLines = self:_buildTooltipInfoLinesByLink(itemLink, stackCount, nil, false)
        for i = 1, #linkLines do
            lines[#lines + 1] = linkLines[i]
        end
    end

    local junkStatus = self:_getJunkStatusText(bagId, slotIndex)
    if junkStatus then
        lines[#lines + 1] = junkStatus
    end

    local vendorPrice = self:_getVendorPriceText(bagId, slotIndex)
    if vendorPrice then
        lines[#lines + 1] = vendorPrice
    end

    return lines
end

function bridge:_buildTooltipInfoLinesByLink(itemLink, stackCount, listingPrice, includeVendor, craftContext, source)
    local lines = {}
    if type(itemLink) ~= "string" or itemLink == "" then
        return lines
    end

    if self:_isBoundItem(nil, nil, itemLink) then
        return lines
    end

    if includeVendor == nil then
        includeVendor = true
    end

    if self:_shouldShowTtcTooltipPrice() then
        local ttcLines = self:_getCachedTtcTooltipLines(itemLink)
        if type(ttcLines) == "table" then
            for i = 1, #ttcLines do
                lines[#lines + 1] = ttcLines[i]
            end
        end

        if type(stackCount) == "number" and stackCount > 1 then
            local priceInfo = self:_getTtcPriceInfo(itemLink)
            if priceInfo then
                local unitPrice = priceInfo.SuggestedPrice or priceInfo.Avg
                if type(unitPrice) == "number" and unitPrice > 0 then
                    local stackTotal = unitPrice * stackCount
                    local stackText = self:_formatTooltipInfoCurrency(stackTotal)
                    if type(stackText) == "string" and stackText ~= "" then
                        lines[#lines + 1] = "TTC x" .. stackCount .. ": " .. stackText
                    end
                end
            end
        end

        if type(listingPrice) == "number" and listingPrice > 0
            and type(stackCount) == "number" and stackCount > 0
        then
            local priceInfo = self:_getTtcPriceInfo(itemLink)
            local unitPrice = priceInfo and (priceInfo.SuggestedPrice or priceInfo.Avg)
            if type(unitPrice) == "number" and unitPrice > 0 then
                local listingPerUnit = listingPrice / stackCount
                local diff = listingPerUnit - unitPrice
                local absDiff = math.abs(diff)
                local diffText = self:_formatCompactTooltipCurrency(absDiff)
                if type(diffText) == "string" and diffText ~= "" then
                    if diff > 0.5 then
                        lines[#lines + 1] = "vs TTC: +" .. diffText .. " overpriced"
                    elseif diff < -0.5 then
                        lines[#lines + 1] = "vs TTC: -" .. diffText .. " cheaper"
                    else
                        lines[#lines + 1] = "vs TTC: fair"
                    end
                end
            end
        end
    end

    if source == "furncraft" and type(craftContext) == "table" then
        local craftLines = self:_buildCraftMaterialCostLines(itemLink, craftContext)
        if type(craftLines) == "table" then
            for i = 1, #craftLines do
                lines[#lines + 1] = craftLines[i]
            end
        end
    end

    if includeVendor and self:_shouldShowVendorPriceInTooltip() then
        local sellPrice = GetItemLinkValue(itemLink, false)
        if sellPrice > 0 then
            local priceText = self:_formatTooltipInfoCurrency(sellPrice)
            if type(priceText) == "string" and priceText ~= "" then
                lines[#lines + 1] = "Vendor: " .. priceText
            end
        end
    end

    return lines
end

local function ClampColorByte(value)
    value = tonumber(value) or 1
    if value < 0 then value = 0 end
    if value > 1 then value = 1 end
    return math.floor(value * 255 + 0.5)
end

local function RgbToHex(r, g, b)
    return string.format("%02X%02X%02X", ClampColorByte(r), ClampColorByte(g), ClampColorByte(b))
end

local function FirstPositiveNumber(...)
    local count = select("#", ...)
    for i = 1, count do
        local v = select(i, ...)
        if type(v) == "number" and v > 0 then
            return v
        end
    end
    return nil
end

function bridge:_getItemLinkQualityHex(itemLink)
    if not IsValidItemLink(itemLink) then
        return "B8B29A"
    end
    local quality = GetItemLinkDisplayQuality(itemLink)
    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, quality)
    return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function bridge:_collectRecipeIngredients(recipeListIndex, recipeIndex)
    local ingredients = {}
    if recipeListIndex == nil or recipeIndex == nil then
        return ingredients
    end

    local _, _, ingredientCount = GetRecipeInfo(recipeListIndex, recipeIndex)
    for i = 1, ingredientCount do
        local link = GetRecipeIngredientItemLink(recipeListIndex, recipeIndex, i)
        local quantity = GetRecipeIngredientRequiredQuantity(recipeListIndex, recipeIndex, i)
        if quantity and quantity > 0 then
            ingredients[#ingredients + 1] = {
                itemLink = IsValidItemLink(link) and link or nil,
                quantity = quantity,
                name = IsValidItemLink(link) and GetItemLinkName(link) or nil,
            }
        end
    end
    return ingredients
end

function bridge:_itemIdFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("|H%d+:item:(%d+):"))
end

function bridge:_collectRecipeIngredientsByResultLink(resultItemLink)
    local itemId = self:_itemIdFromLink(resultItemLink)
    if itemId then
        local _, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(itemId)
        if recipeListIndex and recipeIndex then
            return self:_collectRecipeIngredients(recipeListIndex, recipeIndex)
        end
    end
    return {}
end

function bridge:_collectIngredientsFromSelectedData(selectedData)
    if selectedData and selectedData.recipeListIndex and selectedData.recipeIndex then
        return self:_collectRecipeIngredients(selectedData.recipeListIndex, selectedData.recipeIndex)
    end
    return {}
end

function bridge:_collectSmithingPatternIngredients(craftContext)
    local ingredients = {}
    if not craftContext or not craftContext.patternIndex or not craftContext.materialIndex then
        return ingredients
    end
    -- SetPendingSmithingItem supplies the selected quantity; ItemInfo's stack
    -- is the tier baseline, not the user's current quantity slider selection.
    local quantity = craftContext.materialQuantity
    if not quantity or quantity <= 0 then
        return ingredients
    end
    local function AddMaterial(link, count)
        if IsValidItemLink(link) then
            ingredients[#ingredients + 1] = {itemLink = link, quantity = count, name = GetItemLinkName(link)}
        end
    end
    AddMaterial(GetSmithingPatternMaterialItemLink(craftContext.patternIndex, craftContext.materialIndex, LINK_STYLE_DEFAULT), quantity)
    if craftContext.styleIndex and craftContext.styleIndex > 0 then
        AddMaterial(GetItemStyleMaterialLink(craftContext.styleIndex, LINK_STYLE_DEFAULT), 1)
    end
    if craftContext.traitIndex and craftContext.traitIndex > 0 then
        AddMaterial(GetSmithingTraitItemLink(craftContext.traitIndex, LINK_STYLE_DEFAULT), 1)
    end
    return ingredients
end

function bridge:_buildCraftMaterialCostLines(resultItemLink, craftContext)
    if type(craftContext) ~= "table" then
        return {}
    end

    local ingredients
    if craftContext.recipeListIndex and craftContext.recipeIndex then
        ingredients = self:_collectRecipeIngredients(craftContext.recipeListIndex, craftContext.recipeIndex)
    elseif craftContext.forceSmithingPatternMaterials then
        ingredients = self:_collectSmithingPatternIngredients(craftContext)
    elseif craftContext.selectedData then
        ingredients = self:_collectIngredientsFromSelectedData(craftContext.selectedData)
    else
        ingredients = self:_collectRecipeIngredientsByResultLink(resultItemLink)
    end

    if #ingredients == 0 then
        return {}
    end

    local lines = {}
    lines[#lines + 1] = "|c8E8B68Materials:|r"

    local totalCost = 0
    local knownCostCount = 0
    local displayedCount = 0
    local namedIngredientCount = 0
    local maxLines = 8

    -- Calculate every ingredient; the limit applies only to displayed rows.
    for i = 1, #ingredients do
        local entry = ingredients[i]
        local qty = entry.quantity
        local link = entry.itemLink
        local qualityHex = self:_getItemLinkQualityHex(link)

        local name = entry.name
        if not name or name == "" then
            name = IsValidItemLink(link) and GetItemLinkName(link) or "Unknown mat."
        end

        if type(name) ~= "string" or name == "" then
            -- Skip unknown placeholder-like ingredients to avoid noisy fake entries.
        else
            namedIngredientCount = namedIngredientCount + 1
            local costText = "n/a"
            if IsValidItemLink(link) then
                local priceInfo = self:_getTtcPriceInfo(link)
                local unitPrice = priceInfo and (priceInfo.SuggestedPrice or priceInfo.Avg)
                if type(unitPrice) == "number" and unitPrice > 0 then
                    local lineCost = unitPrice * qty
                    totalCost = totalCost + lineCost
                    knownCostCount = knownCostCount + 1
                    costText = self:_formatCompactTooltipCurrency(lineCost) or tostring(math.floor(lineCost + 0.5))
                end
            end

            if displayedCount < maxLines then
                lines[#lines + 1] = string.format("|c%s• %s x%d: %s|r", qualityHex, name, qty, costText)
                displayedCount = displayedCount + 1
            end
        end
    end

    if namedIngredientCount > displayedCount then
        lines[#lines + 1] = string.format("|c8E8B68  ...and %d more mats|r", namedIngredientCount - displayedCount)
    end

    if knownCostCount == #ingredients then
        local totalText = self:_formatCompactTooltipCurrency(totalCost) or tostring(math.floor(totalCost + 0.5))
        lines[#lines + 1] = "|cD7C98FMat total: " .. totalText .. "|r"

        local resultPriceInfo = self:_getTtcPriceInfo(resultItemLink)
        local resultUnit = resultPriceInfo and (resultPriceInfo.SuggestedPrice or resultPriceInfo.Avg)
        if type(resultUnit) == "number" and resultUnit > 0 then
            local delta = resultUnit - totalCost
            local deltaText = self:_formatCompactTooltipCurrency(math.abs(delta)) or tostring(math.floor(math.abs(delta) + 0.5))
            if delta > 0.5 then
                lines[#lines + 1] = "|c6AB87Avs crafted: +" .. deltaText .. "|r"
            elseif delta < -0.5 then
                lines[#lines + 1] = "|cD46A6Avs crafted: -" .. deltaText .. "|r"
            else
                lines[#lines + 1] = "|cA0A070vs crafted: near zero|r"
            end
        end
    end

    if knownCostCount < #ingredients then
        if knownCostCount == 0 then
            lines[#lines + 1] = "|cD7C98FMat estimate: incomplete (no pricing)|r"
        else
            local knownText = self:_formatCompactTooltipCurrency(totalCost) or tostring(math.floor(totalCost + 0.5))
            lines[#lines + 1] = string.format("|cD7C98FMat estimate: partial (%d/%d priced; known subtotal %s)|r", knownCostCount, #ingredients, knownText)
        end
    end

    return lines
end

local function FormatTooltipLine(text)
    if type(text) ~= "string" or text == "" then
        return text
    end

    local cached = bridge._formattedTooltipLineCache[text]
    if cached ~= nil then
        return cached
    end

    local formatted = nil

    if text:match("^TTC:%s") then
        formatted = "|cD8C06A" .. text .. "|r"
    elseif text:match("^Vendor:%s") then
        formatted = "|cC9B36B" .. text .. "|r"
    elseif text:match("^Junk:%s") then
        local junkValue = text:match("^Junk:%s*(.+)$")
        if junkValue == "Yes" then
            formatted = "|cB088D9" .. text .. "|r"
        else
            formatted = "|cF0F0F0" .. text .. "|r"
        end
    elseif text:match("^Min/Avg/Max:%s") then
        formatted = "|c9F9780" .. text .. "|r"
    elseif text:match("^TTC x%d") then
        -- TTC stack total — same gold colour as TTC line
        formatted = "|cD8C06A" .. text .. "|r"
    elseif text:match("^vs TTC:") then
        -- cheaper = green, overpriced = red, fair = neutral gray
        if text:find("cheaper") or text:find("дешевле") then
            formatted = "|c6AB87A" .. text .. "|r"
        elseif text:find("overpriced") or text:find("дороже") then
            formatted = "|cD46A6A" .. text .. "|r"
        else
            formatted = "|cA0A070" .. text .. "|r"
        end
    elseif text:match("^Bound:%s") then
        formatted = "|cA7A7A7" .. text .. "|r"
    else
        formatted = "|cB8B29A" .. text .. "|r"
    end

    if bridge._formattedTooltipLineCache[text] == nil then
        bridge._formattedTooltipLineCacheSize = (bridge._formattedTooltipLineCacheSize or 0) + 1
        if bridge._formattedTooltipLineCacheSize > 128 then
            bridge._formattedTooltipLineCache = {}
            bridge._formattedTooltipLineCacheSize = 0
        end
    end

    bridge._formattedTooltipLineCache[text] = formatted
    return formatted
end

function bridge:_ensureOverlayWindow()
    if self._overlayWindow then
        LogTrace("Overlay reuse existing window")
        return self._overlayWindow
    end

    local wm = WINDOW_MANAGER

    local guiRoot = _G.GuiRoot
    local window = wm:CreateTopLevelWindow(MAJOR .. "_Overlay")

    window:SetHidden(true)
    window:SetMouseEnabled(false)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)
    window:SetDrawLevel(10)
    window:SetMovable(false)
    window:SetClampedToScreen(true)
    window:SetDimensions(320, 120)
    window:ClearAnchors()
    window:SetAnchor(TOPRIGHT, guiRoot, TOPRIGHT, -40, 140)

    local backdrop = wm:CreateControl(nil, window, CT_BACKDROP)
    backdrop:SetAnchorFill(window)
    backdrop:SetCenterColor(0, 0, 0, 0.70)
    backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/gp_tooltip_edge_semitrans_64.dds", 64, 8, 8)
    backdrop:SetHidden(false)

    -- Gold border lines (CT_TEXTURE), shown only for furncraft
    local function makeBorderTex(parent)
        local b = wm:CreateControl(nil, parent, CT_TEXTURE)
        b:SetColor(0.678, 0.651, 0.518, 1.0)
        b:SetHidden(true)
        return b
    end
    -- 3px черный отступ от края окна, затем 2px золотая линия
    local P, T = 3, 2
    local borderTop = makeBorderTex(window)
    borderTop:SetAnchor(TOPLEFT, window, TOPLEFT, P, P)
    borderTop:SetAnchor(BOTTOMRIGHT, window, TOPRIGHT, -P, P + T)
    local borderBottom = makeBorderTex(window)
    borderBottom:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, P, -P)
    borderBottom:SetAnchor(TOPRIGHT, window, BOTTOMRIGHT, -P, -(P + T))
    local borderLeft = makeBorderTex(window)
    borderLeft:SetAnchor(TOPLEFT, window, TOPLEFT, P, P)
    borderLeft:SetAnchor(BOTTOMRIGHT, window, BOTTOMLEFT, P + T, -P)
    local borderRight = makeBorderTex(window)
    borderRight:SetAnchor(TOPRIGHT, window, TOPRIGHT, -P, P)
    borderRight:SetAnchor(BOTTOMLEFT, window, BOTTOMRIGHT, -(P + T), -P)

    local label = wm:CreateControl(nil, window, CT_LABEL)
    label:SetAnchor(TOPLEFT, window, TOPLEFT, 12, 8)
    label:SetWidth(296)
    label:SetHeight(92)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetFont("ZoFontGamepad27")
    label:SetColor(1, 1, 1, 1)

    self._overlayWindow = {
        window = window,
        backdrop = backdrop,
        borderTop = borderTop,
        borderBottom = borderBottom,
        borderLeft = borderLeft,
        borderRight = borderRight,
        label = label,
        lineLabels = { label },
        renderedLineCount = 0,
    }

    LogDebug("Overlay window created")

    return self._overlayWindow
end

function bridge:_ensureOverlayLineLabels(overlay, lineCount)
    if not overlay or not overlay.window or not overlay.label then
        return nil
    end

    overlay.lineLabels = overlay.lineLabels or { overlay.label }
    local lineLabels = overlay.lineLabels
    local wm = WINDOW_MANAGER

    for index = #lineLabels + 1, lineCount do
        local lineLabel = wm:CreateControl(nil, overlay.window, CT_LABEL)
        lineLabel:SetWidth(296)
        lineLabel:SetHeight(28)
        lineLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        lineLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        lineLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        lineLabel:SetFont("ZoFontGamepad27")
        lineLabel:SetColor(1, 1, 1, 1)

        lineLabel:ClearAnchors()
        lineLabel:SetAnchor(TOPLEFT, lineLabels[index - 1], BOTTOMLEFT, 0, 0)
        lineLabels[index] = lineLabel
    end

    return lineLabels
end

function bridge:_renderOverlayLines(overlay, formattedLines)
    if not overlay or not overlay.label then
        return
    end

    local lineCount = math.max(1, #formattedLines)
    local lineLabels = self:_ensureOverlayLineLabels(overlay, lineCount)
    if not lineLabels then
        return
    end

    overlay.renderedLineCount = #formattedLines
    for index = 1, #lineLabels do
        local lineLabel = lineLabels[index]
        lineLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        local text = formattedLines[index]
        if type(text) == "string" and text ~= "" then
            lineLabel:SetHeight(28)
            lineLabel:SetText(text)
            lineLabel:SetHidden(false)
        else
            lineLabel:SetText("")
            lineLabel:SetHidden(true)
            lineLabel:SetHeight(0)
        end
    end
end

function bridge:_isRenderableControl(control)
    return control ~= nil
        and not control:IsControlHidden()
        and control:GetWidth() > 0
        and control:GetHeight() > 0
end

function bridge:_getOverlayTooltipBySource(source)

    local tooltipTypes = nil
    if source == "furncraft" then
        tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
    else
        tooltipTypes = { GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_LEFT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
    end

    for i = 1, #tooltipTypes do
        local tooltipType = tooltipTypes[i]
        if tooltipType ~= nil then
            local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
            if self:_isRenderableControl(tooltip) then
                return tooltip
            end
        end
    end

    return nil
end

function bridge:_getActiveOverlayTooltip()
    if self:_isRenderableControl(self._overlayTooltipControl) then
        return self._overlayTooltipControl
    end

    return self:_getOverlayTooltipBySource(self._overlaySource)
end

function bridge:_getOverlayAnchorContainer()
    local tooltip = self:_getActiveOverlayTooltip()
    if not self:_isRenderableControl(tooltip) then
        return nil
    end

    local current = tooltip
    local best = tooltip
    local guiRoot = _G.GuiRoot

    for _ = 1, 8 do
        local parent = current:GetParent()
        if parent == nil or not self:_isRenderableControl(parent) or parent == guiRoot then
            break
        end

        best = parent
        current = parent
    end

    return best
end

function bridge:_shouldKeepOverlayVisible()
    local tooltip = self:_getActiveOverlayTooltip()
    return self:_isRenderableControl(tooltip) or self:_isRenderableControl(self._overlayAnchorControl)
end

function bridge:_refreshOverlayVisibility()
    local overlay = self._overlayWindow
    if not overlay or not overlay.window or overlay.window:IsHidden() then
        return
    end

    local now = GetGameTimeMilliseconds()
    if now - (overlay._lastVisibilityCheckAt or 0) < 100 then
        return
    end
    overlay._lastVisibilityCheckAt = now

    if self:_shouldKeepOverlayVisible() then
        return
    end

    self:_hideOverlay()
    LogTrace("Overlay hidden by visibility guard")
end

function bridge:_resizeOverlayToText(overlay)
    if not overlay or not overlay.window or not overlay.label then
        return
    end

    local tooltip = self:_getOverlayAnchorContainer() or self:_getActiveOverlayTooltip()
    local guiRoot = _G.GuiRoot
    local availableWidth = 500
    local maxHeight = 220

    if tooltip then
        if self._overlaySource == "furncraft" then
            availableWidth = math.max(380, math.min(math.floor(tooltip:GetWidth() * 0.92), 540))
        elseif self._overlaySource == "guildstore" then
            availableWidth = math.max(360, math.min(tooltip:GetWidth() - 28, 470))
        else
            availableWidth = math.max(430, math.min(tooltip:GetWidth() - 12, 560))
        end
    end
    if tooltip then
        if self._overlaySource == "furncraft" then
            maxHeight = math.max(280, math.min(math.floor(tooltip:GetHeight() * 1.35), 900))
        else
            maxHeight = math.max(120, math.min(math.floor(tooltip:GetHeight() * 0.42), 220))
        end
    end

    if guiRoot then
        local screenMax = math.max(220, (guiRoot:GetHeight() or 1080) - 24)
        maxHeight = math.min(maxHeight, screenMax)
    end

    local labelWidth = availableWidth - 20
    local lineLabels = overlay.lineLabels or { overlay.label }
    local renderedLineCount = overlay.renderedLineCount or 0
    local usedHeight = 14

    for index = 1, #lineLabels do
        local lineLabel = lineLabels[index]
        lineLabel:SetWidth(labelWidth)
        lineLabel:SetDimensionConstraints(labelWidth, 0, labelWidth, maxHeight - 12)

        if index <= renderedLineCount then
            local textHeight = lineLabel:GetTextHeight()
            local lineHeight = math.max(30, textHeight + 2)
            lineLabel:SetHeight(lineHeight)
            lineLabel:SetHidden(false)
            usedHeight = usedHeight + lineHeight
        else
            lineLabel:SetHeight(0)
            lineLabel:SetHidden(true)
        end
    end

    local minHeight = (self._overlaySource == "furncraft") and 156 or 96
    local desiredHeight = math.max(minHeight, math.min(usedHeight + 16, maxHeight))

    overlay.window:SetDimensions(availableWidth, desiredHeight)
end

function bridge:_getOverlayInsetsForSource(source)
    if source == "guildstore" then
        return -10, -168
    end
    if source == "bag" then
        return -12, -176
    end
    if source == "furncraft" then
        return 0, -184
    end
    return 0, -100
end

function bridge:_hideOverlay()
    self._overlayGeneration = (self._overlayGeneration or 0) + 1
    self._overlayAnchorControl = nil
    self._overlaySource = nil
    self._overlayTooltipControl = nil

    local overlay = self._overlayWindow
    if overlay and overlay.window then
        overlay._lastVisibilityCheckAt = 0
        overlay.window:SetHandler("OnUpdate", nil)
        overlay.window:SetHidden(true)
    end
end

function bridge:_positionOverlay()
    local overlay = self:_ensureOverlayWindow()
    if not overlay or not overlay.window then
        LogDebug("Overlay position skipped: overlay missing")
        return false
    end

    local guiRoot = _G.GuiRoot
    local anchorTarget = guiRoot
    local point = TOPRIGHT
    local relativePoint = TOPRIGHT
    local offsetX = -24
    local offsetY = 120

    local tooltip = self:_getOverlayAnchorContainer() or self:_getActiveOverlayTooltip()
    if tooltip then
        local insetX, insetY = self:_getOverlayInsetsForSource(self._overlaySource)
        anchorTarget = tooltip
        if self._overlaySource == "furncraft" then
            local gap = 42
            local safe = 8
            local overlayWidth = overlay.window:GetWidth()
            local tooltipLeft = tooltip:GetLeft()
            local tooltipRight = tooltip:GetRight()
            local screenWidth = guiRoot:GetWidth()
            local leftSpace = tooltipLeft - safe
            local rightSpace = screenWidth - tooltipRight - safe

            if leftSpace >= overlayWidth + gap then
                point = TOPRIGHT
                relativePoint = TOPLEFT
                offsetX = -gap
                offsetY = -18
            elseif rightSpace >= overlayWidth + gap then
                point = TOPLEFT
                relativePoint = TOPRIGHT
                offsetX = gap
                offsetY = -18
            else
                point = TOP
                relativePoint = TOP
                offsetX = insetX
                offsetY = insetY
            end
        else
            point = TOPLEFT
            relativePoint = TOPLEFT
            offsetX = insetX
            offsetY = insetY
        end
        LogTrace("Overlay anchored inside active tooltip")
    elseif self:_isRenderableControl(self._overlayAnchorControl) then
        anchorTarget = self._overlayAnchorControl
        point = BOTTOMLEFT
        relativePoint = TOPLEFT
        offsetX = 18
        offsetY = -8
        LogTrace("Overlay anchored above selected item row fallback")
    else
        LogTrace("Overlay fallback anchor: GuiRoot")
        return false
    end

    overlay.window:ClearAnchors()
    overlay.window:SetAnchor(point, anchorTarget, relativePoint, offsetX, offsetY)

    -- Keep the full dynamic window inside the screen bounds by nudging vertically.
    local rootTop = guiRoot:GetTop()
    local rootBottom = guiRoot:GetBottom()
    local winTop = overlay.window:GetTop()
    local winBottom = overlay.window:GetBottom()
    local safe = 6
    local adjustY = 0
    if winBottom > (rootBottom - safe) then
        adjustY = adjustY - (winBottom - (rootBottom - safe))
    end
    if (winTop + adjustY) < (rootTop + safe) then
        adjustY = adjustY + ((rootTop + safe) - (winTop + adjustY))
    end

    if math.abs(adjustY) >= 1 then
        overlay.window:ClearAnchors()
        overlay.window:SetAnchor(point, anchorTarget, relativePoint, offsetX, offsetY + adjustY)
    end

    return true
end

local function ParseCompactOverlayInfo(lines)
    local info = {
        ttc = nil,
        minAvgMax = nil,
        stackTotal = nil,
        versusTtc = nil,
        vendor = nil,
        junk = nil,
    }

    for i = 1, #lines do
        local line = lines[i]
        if type(line) == "string" then
            local value = line:match("^TTC:%s*(.+)$")
            if value then
                info.ttc = value
            end

            local minValue, avgValue, maxValue = line:match("^Min/Avg/Max:%s*(.-)%s*/%s*(.-)%s*/%s*(.+)$")
            if minValue and avgValue and maxValue then
                info.minAvgMax = string.format("%s / %s / %s", minValue, avgValue, maxValue)
            end

            local stackCount, stackPrice = line:match("^TTC x(%d+):%s*(.+)$")
            if stackCount and stackPrice then
                info.stackTotal = string.format("x%s %s", stackCount, stackPrice)
            end

            local diffValue = line:match("^vs TTC:%s*(.+)$")
            if diffValue then
                info.versusTtc = diffValue
            end

            local vendorValue = line:match("^Vendor:%s*(.+)$")
            if vendorValue then
                info.vendor = vendorValue
            end

            local junkValue = line:match("^Junk:%s*(.+)$")
            if junkValue then
                info.junk = junkValue
            end
        end
    end

    return info
end

local function BuildCompactMinAvgMaxLine(text)
    if not text then
        return nil
    end

    return string.format("|c9F9780Min/Avg/Max: %s|r", text)
end

local function BuildCompactVersusTtcLine(text)
    if not text then
        return nil
    end

    local prefix = "|cA0A070"
    if text:find("cheaper") or text:find("дешевле") then
        prefix = "|c6AB87A"
    elseif text:find("overpriced") or text:find("дороже") then
        prefix = "|cD46A6A"
    end

    return string.format("%svs TTC: %s|r", prefix, text)
end

local function AppendIfValue(lines, value)
    if value then
        lines[#lines + 1] = value
    end
end

local function BuildCompactOverlayBaseLines(info)
    local compact = {}

    AppendIfValue(compact, info.ttc and string.format("|cD8C06ATTC: %s|r", info.ttc) or nil)
    AppendIfValue(compact, BuildCompactMinAvgMaxLine(info.minAvgMax))
    AppendIfValue(compact, info.stackTotal and string.format("|cD8C06ATTC x%s|r", info.stackTotal:sub(2)) or nil)

    return compact
end

function bridge:_buildCompactOverlayLines(lines, source)
    if type(lines) ~= "table" or #lines == 0 then
        return lines
    end

    if source == "furncraft" then
        return lines
    end

    local info = ParseCompactOverlayInfo(lines)

    if source == "bag" then
        local compact = BuildCompactOverlayBaseLines(info)

        AppendIfValue(compact, info.vendor and string.format("|cC9B36BVendor: %s|r", info.vendor) or nil)
        AppendIfValue(compact, info.junk == "Yes" and "|cB088D9Junk: Yes|r" or nil)
        AppendIfValue(compact, BuildCompactVersusTtcLine(info.versusTtc))

        if #compact > 0 then
            return compact
        end
    end

    local compact = BuildCompactOverlayBaseLines(info)
    AppendIfValue(compact, info.vendor and string.format("|cC9B36BVendor: %s|r", info.vendor) or nil)
    AppendIfValue(compact, BuildCompactVersusTtcLine(info.versusTtc))

    if #compact > 0 then
        return compact
    end

    return lines
end

function bridge:_scheduleOverlayShowRetry(lines, source, tooltipControl, retryCount, generation)
    retryCount = tonumber(retryCount) or 0
    if retryCount >= 6 then
        return false
    end

    zo_callLater(function()
        if bridge._overlayGeneration ~= generation then
            return
        end
        bridge:_showOverlayLines(lines, source, tooltipControl, retryCount + 1, generation)
    end, 40)

    LogTrace("Overlay show delayed until tooltip anchor is ready")
    return true
end

function bridge:_showOverlayLines(lines, source, tooltipControl, retryCount, generation)
    if not self.enabled then
        return
    end
    if generation == nil then
        self._overlayGeneration = (self._overlayGeneration or 0) + 1
        generation = self._overlayGeneration
    elseif self._overlayGeneration ~= generation then
        return
    end

    if type(lines) ~= "table" or #lines == 0 then
        LogTrace("Overlay show skipped: no lines")
        self:_hideOverlay()
        return
    end

    local overlay = self:_ensureOverlayWindow()
    if not overlay or not overlay.label then
        LogDebug("Overlay show failed: overlay or label missing")
        return
    end

    local overlayLines = self:_buildCompactOverlayLines(lines, source)
    local formattedLines = {}
    for i = 1, #overlayLines do
        local line = overlayLines[i]
        if type(line) == "string" and line:find("|c") then
            formattedLines[#formattedLines + 1] = line
        else
            formattedLines[#formattedLines + 1] = FormatTooltipLine(line)
        end
    end

    self._overlaySource = source
    self._overlayTooltipControl = tooltipControl
    local isFurncraft = (source == "furncraft")
    if overlay.backdrop then
        if isFurncraft then
            overlay.backdrop:SetCenterColor(0, 0, 0, 0.70)
            overlay.backdrop:SetHidden(false)
        else
            overlay.backdrop:SetHidden(true)
        end
    end
    for _, bName in ipairs({ "borderTop", "borderBottom", "borderLeft", "borderRight" }) do
        local b = overlay[bName]
        if b then
            b:SetHidden(not isFurncraft)
        end
    end
    self:_renderOverlayLines(overlay, formattedLines)
    self:_resizeOverlayToText(overlay)

    local anchored = self:_positionOverlay()
    if not anchored then
        if self:_scheduleOverlayShowRetry(lines, source, tooltipControl, retryCount, generation) then
            return
        end
    end

    if not bridge._onRefreshOverlay then
        bridge._onRefreshOverlay = function()
            bridge:_refreshOverlayVisibility()
        end
    end
    overlay.window:SetHandler("OnUpdate", bridge._onRefreshOverlay)
    overlay.window:SetHidden(false)
    LogDebug(string.format("Overlay shown: source=%s lines=%d", tostring(source), #lines))
end

function bridge:_appendGamepadTooltipInfoByLink(tooltip, itemLink, stackCount, listingPrice, source, craftContext)
    if tooltip == nil or type(itemLink) ~= "string" or itemLink == "" then
        return
    end

    LogTrace("_appendByLink: " .. tostring(itemLink):sub(1, 50)
        .. " sc=" .. tostring(stackCount) .. " price=" .. tostring(listingPrice))

    -- Dedup: include stackCount/listingPrice in key so same item at different TH prices
    -- doesn't get skipped within the 200ms window.
    local contextKey = ""
    if type(craftContext) == "table" then
        contextKey = table.concat({
            tostring(craftContext.recipeListIndex or ""),
            tostring(craftContext.recipeIndex or ""),
            tostring(craftContext.patternIndex or ""),
            tostring(craftContext.materialIndex or ""),
            tostring(craftContext.materialQuantity or ""),
        }, ":")
    end
    local dedupKey = itemLink .. "|" .. tostring(stackCount or "") .. "|" .. tostring(listingPrice or "") .. "|" .. contextKey
    local now = GetGameTimeMilliseconds()
    if tooltip._lgcmbLastKey == dedupKey and now - (tooltip._lgcmbLastLinkTime or 0) < 200 then
        return
    end
    tooltip._lgcmbLastKey = dedupKey
    tooltip._lgcmbLastLinkTime = now

    local lines = self:_buildTooltipInfoLinesByLink(itemLink, stackCount, listingPrice, true, craftContext, source)

    if #lines == 0 then
        self:_hideOverlay()
        return
    end

    self:_showOverlayLines(lines, source, tooltip)
end

function bridge:_appendGamepadTooltipInfo(tooltip, bagId, slotIndex, source)
    local lines = self:_buildTooltipInfoLines(bagId, slotIndex)

    if #lines == 0 then
        self:_hideOverlay()
        return
    end

    self:_showOverlayLines(lines, source, tooltip)
end

-- Price lookup is limited to the selected Trading House lot; no item-ID scan.

function bridge:_lookupTradingHouseListingPrice(itemLink, stackCount, sellerName)
    local scene = GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS
    -- BrowseResults inherits ZO_SortFilterList, not a parametric gamepad list.
    local selectedData = scene and scene:GetSelectedData()
    if not selectedData then
        return nil, nil
    end
    local selectedLink = selectedData.isGuildSpecificItem and GetGuildSpecificItemLink(selectedData.slotIndex) or selectedData.itemLink
    if selectedLink ~= itemLink then
        return nil, nil
    end
    if sellerName and selectedData.sellerName ~= sellerName then
        return nil, nil
    end
    if stackCount and selectedData.stackCount ~= stackCount then
        return nil, nil
    end
    return selectedData.purchasePrice, selectedData.stackCount
end

function bridge:_hookTooltipPrice()
    if self._tooltipPriceHooked then
        return true
    end
    -- The manager/container instances can be created after addon load.
    if not GAMEPAD_TOOLTIPS then
        return false
    end
    local allHooked = true
    for _, kind in ipairs({GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP}) do
        local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(kind)
        if not tooltip then
            allHooked = false
        elseif not tooltip._lgcmbBagHooksInstalled then
            -- Native tooltip controls are userdata; SecurePostHook only accepts tables.
            ZO_PostHook(tooltip, "LayoutBagItem", function(control, bagId, slotIndex)
                if bridge.enabled then
                    bridge:_appendGamepadTooltipInfo(control, bagId, slotIndex, "bag")
                end
            end)
            ZO_PostHookHandler(tooltip, "OnEffectivelyHidden", function(control)
                if bridge._overlayTooltipControl == control then
                    bridge:_hideOverlay()
                end
            end)
            tooltip._lgcmbBagHooksInstalled = true
        end
    end
    self._tooltipPriceHooked = allHooked
    return allHooked
end

function bridge:_hookCraftingTooltips()
    if self._craftingTooltipsHooked then
        return true
    end
    -- Hook the actual gamepad classes, not guessed globals or keyboard overrides.
    local function ShowResult(control, tooltip, itemLink, context)
        if not bridge.enabled then
            return
        end
        if control:IsControlHidden() or not IsValidItemLink(itemLink) then
            bridge._templateCraftingOverlayActive = false
            bridge:_hideOverlay()
            return
        end
        bridge._templateCraftingOverlayActive = true
        bridge:_appendGamepadTooltipInfoByLink(tooltip, itemLink, nil, nil, "furncraft", context)
    end
    SecurePostHook(ZO_GamepadSmithingCreation, "SetupResultTooltip", function(creation, pattern, material, quantity, styleId, trait)
        local context = bridge:_makeCraftContext(pattern, material, quantity, styleId, trait)
        context.forceSmithingPatternMaterials = true
        local link = GetSmithingPatternResultLink(pattern, material, quantity, styleId, trait, LINK_STYLE_DEFAULT)
        ShowResult(creation.resultTooltip, creation.resultTooltip.tip, link, context)
    end)
    SecurePostHook(ZO_GamepadProvisioner, "RefreshRecipeDetails", function(provisioner, selectedData)
        if not selectedData then
            bridge._templateCraftingOverlayActive = false
            bridge:_hideOverlay()
            return
        end
        local listIndex, recipeIndex = selectedData.recipeListIndex, selectedData.recipeIndex
        local link = GetRecipeResultItemLink(listIndex, recipeIndex, LINK_STYLE_DEFAULT)
        local context = bridge:_makeRecipeCraftContext(listIndex, recipeIndex, selectedData)
        ShowResult(provisioner.resultTooltip, provisioner.resultTooltip.tip, link, context)
    end)
    SecurePostHook(ZO_GamepadAlchemy, "UpdateTooltip", function(alchemy)
        local link = alchemy:IsCraftable() and alchemy:GetResultItemLink() or nil
        ShowResult(alchemy.tooltip, alchemy.tooltip.tip, link)
    end)
    SecurePostHook(ZO_GamepadEnchanting, "UpdateTooltip", function(enchanting)
        local link = enchanting:IsCraftable() and enchanting:GetResultItemLink() or nil
        ShowResult(enchanting.resultTooltip, enchanting.resultTooltip.tip, link)
    end)
    self._craftingTooltipsHooked = true
    return true
end

function bridge:_hookTradingHouseTooltip()
    if self._tradingHouseTooltipHooked then
        return true
    end
    if not GAMEPAD_TOOLTIPS then
        return false
    end
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
    if not tooltip then
        return false
    end
    ZO_PostHook(tooltip, "LayoutGuildStoreSearchResult", function(control, itemLink, stackCount, sellerName)
        if not bridge.enabled then
            return
        end
        if not IsValidItemLink(itemLink) then
            bridge:_hideOverlay()
            return
        end
        local price, selectedCount = bridge:_lookupTradingHouseListingPrice(itemLink, stackCount, sellerName)
        control._lgcmbLastKey = nil
        bridge:_appendGamepadTooltipInfoByLink(control, itemLink, selectedCount or stackCount, price, "guildstore")
    end)
    self._tradingHouseTooltipHooked = true
    return true
end

function bridge:_scheduleTooltipPriceHookRetry()
    if self._tooltipHookRetryScheduled or (self._tooltipPriceHooked and self._craftingTooltipsHooked and self._tradingHouseTooltipHooked) then
        return
    end
    local attempts = self._tooltipHookRetryAttempts or 0
    if attempts >= 6 then
        return
    end
    self._tooltipHookRetryAttempts = attempts + 1
    self._tooltipHookRetryScheduled = true
    zo_callLater(function()
        bridge._tooltipHookRetryScheduled = false
        bridge:_hookTooltipPrice()
        bridge:_hookCraftingTooltips()
        bridge:_hookTradingHouseTooltip()
        bridge:_scheduleTooltipPriceHookRetry()
    end, 2500)
end

function bridge:_initializeSlashCommands()
    if self._slashCommandsRegistered then
        return
    end

    local function PrintHelp()
        d(string.format("[%s] /lgcmb status", MAJOR))
        d(string.format("[%s] /lgcmb on|off", MAJOR))
        d(string.format("[%s] /lgcmb debug on|off", MAJOR))
        d(string.format("[%s] /lgcmb verbose on|off", MAJOR))
        d(string.format("[%s] /lgcmb log [count]", MAJOR))
        d(string.format("[%s] /lgcmb clearlog", MAJOR))
    end

    SLASH_COMMANDS["/lgcmb"] = function(text)
        local cmd = string.lower(TrimString(text or ""))
        if cmd == "" or cmd == "help" then
            PrintHelp()
            return
        end

        if cmd == "status" then
            self:DumpRuntimeStatus()
            return
        end

        if cmd == "on" then
            self:SetEnabled(true)
            return
        end
        if cmd == "off" then
            self:SetEnabled(false)
            return
        end
        if cmd == "debug on" then
            self:SetDebugEnabled(true)
            return
        end
        if cmd == "debug off" then
            self:SetDebugEnabled(false)
            return
        end
        if cmd == "verbose on" then
            self:SetDebugVerbose(true)
            return
        end
        if cmd == "verbose off" then
            self:SetDebugVerbose(false)
            return
        end
        if cmd == "clearlog" then
            self:ClearDebugLog()
            return
        end

        local logCount = cmd:match("^log%s+(%d+)$")
        if cmd == "log" or logCount then
            self:DumpDebugLog(tonumber(logCount) or 40)
            return
        end

        PrintHelp()
    end

    self._slashCommandsRegistered = true
    LogTrace("Slash command /lgcmb registered")
end

function bridge:_initializeSettingsPanel()
    if self._settingsPanelRegistered then
        return
    end

    local lam = LibAddonMenu2
    if not lam then
        return
    end

    local panelData = {
        type = "panel",
        name = MAJOR,
        displayName = MAJOR,
        author = "Azmail",
        version = ADDON_VERSION,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "Bridge for LibCustomMenu context actions in gamepad mode.",
        },
        {
            type = "checkbox",
            name = "Enable bridge",
            getFunc = function()
                return self.enabled
            end,
            setFunc = function(value)
                self:SetEnabled(value)
            end,
            default = DEFAULTS.enabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Debug mode",
            getFunc = function()
                return self.debug
            end,
            setFunc = function(value)
                self:SetDebugEnabled(value)
            end,
            default = DEFAULTS.debug,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Verbose debug",
            getFunc = function()
                return self.debugVerbose
            end,
            setFunc = function(value)
                self:SetDebugVerbose(value)
            end,
            default = DEFAULTS.debugVerbose,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show TTC price in gamepad overlay",
            getFunc = function()
                return self:_shouldShowTtcTooltipPrice()
            end,
            setFunc = function(value)
                self:SetShowTtcPriceInTooltip(value)
            end,
            default = DEFAULTS.showTtcPriceInTooltip,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show expanded TTC details",
            getFunc = function()
                return self:_shouldShowTtcTooltipDetails()
            end,
            setFunc = function(value)
                self:SetShowTtcPriceDetailsInTooltip(value)
            end,
            disabled = function()
                return not self:_shouldShowTtcTooltipPrice()
            end,
            default = DEFAULTS.showTtcPriceDetailsInTooltip,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show junk status in gamepad overlay",
            getFunc = function()
                return self:_shouldShowJunkStatusInTooltip()
            end,
            setFunc = function(value)
                self:SetShowJunkStatusInTooltip(value)
            end,
            default = DEFAULTS.showJunkStatusInTooltip,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show vendor price in gamepad overlay",
            getFunc = function()
                return self:_shouldShowVendorPriceInTooltip()
            end,
            setFunc = function(value)
                self:SetShowVendorPriceInTooltip(value)
            end,
            default = DEFAULTS.showVendorPriceInTooltip,
            width = "full",
        },
        {
            type = "button",
            name = "Print debug log to chat",
            func = function()
                self:DumpDebugLog(60)
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Clear debug log",
            func = function()
                self:ClearDebugLog()
            end,
            width = "half",
        },
    }

    lam:RegisterAddonPanel(MAJOR .. "_Settings", panelData)
    lam:RegisterOptionControls(MAJOR .. "_Settings", optionsData)
    self._settingsPanelRegistered = true
    LogTrace("Settings panel registered in LibAddonMenu")
end

function bridge:_captureMenuEntry(capture, labelValue, callback, itemType, enabled)
    local itemTypeValue = itemType or MENU_ADD_OPTION_LABEL
    if itemTypeValue == MENU_ADD_OPTION_HEADER then
        return #capture.entries
    end

    enabled = EvaluateValue(enabled, ZO_Menu, capture.contextControl)
    if enabled == false then
        return #capture.entries
    end

    local label = ResolveLabel(labelValue, capture.contextControl)
    if not label or IsDividerLabel(label) then
        return #capture.entries
    end

    if itemTypeValue == MENU_ADD_OPTION_CHECKBOX then
        label = "[ ] " .. label
    end

    if type(callback) ~= "function" then
        return #capture.entries
    end

    capture.entries[#capture.entries + 1] = {
        kind = "action",
        label = label,
        callback = function()
            RunExternalAction(callback)
        end,
    }
    LogTrace(string.format("Captured action: %s", tostring(label)))

    return #capture.entries
end

function bridge:_captureSubMenuEntries(capture, submenuLabelValue, entries, submenuCallback)
    local submenuLabel = ResolveLabel(submenuLabelValue, capture.contextControl)
    if not submenuLabel then
        LogTrace("Skipped submenu with empty label")
        return #capture.entries
    end

    local submenuEntries = entries
    if type(submenuEntries) == "function" then
        submenuEntries = EvaluateValue(submenuEntries, ZO_Menu, capture.contextControl)
    end

    if type(submenuEntries) ~= "table" then
        LogTrace(string.format("Skipped submenu '%s': entries is %s", tostring(submenuLabel), type(submenuEntries)))
        return #capture.entries
    end

    local submenuActionEntries = {}

    for i = 1, #submenuEntries do
        local entry = submenuEntries[i]
        if type(entry) == "table" then
            local visible = EvaluateValue(entry.visible, ZO_Menu, capture.contextControl)
            if visible ~= false then
                local disabled = EvaluateValue(entry.disabled or false, ZO_Menu, capture.contextControl)
                if not disabled then
                    local itemTypeValue = entry.itemType or MENU_ADD_OPTION_LABEL
                    if itemTypeValue ~= MENU_ADD_OPTION_HEADER then
                        local childLabel = ResolveLabel(entry.label or entry.name or entry[1], capture.contextControl)
                        if childLabel and not IsDividerLabel(childLabel) then
                            local checked
                            if itemTypeValue == MENU_ADD_OPTION_CHECKBOX then
                                checked = not not EvaluateValue(entry.checked or false, ZO_Menu, capture.contextControl)
                                childLabel = string.format("[%s] %s", checked and "x" or " ", childLabel)
                            end

                            local callback = entry.callback or entry.func or entry[2]
                            if type(callback) == "function" then
                                submenuActionEntries[#submenuActionEntries + 1] = {
                                    label = childLabel,
                                    callback = function()
                                        if itemTypeValue == MENU_ADD_OPTION_CHECKBOX then
                                            RunExternalAction(function()
                                                callback(not checked)
                                            end)
                                        else
                                            RunExternalAction(callback)
                                        end
                                    end,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if #submenuActionEntries == 0 and type(submenuCallback) ~= "function" then
        LogTrace(string.format("Skipped submenu '%s': no visible actions", submenuLabel))
        return #capture.entries
    end

    capture.entries[#capture.entries + 1] = {
        kind = "submenu",
        label = submenuLabel,
        entries = submenuActionEntries,
        callback = type(submenuCallback) == "function" and function()
            RunExternalAction(submenuCallback)
        end or nil,
    }
    LogTrace(string.format("Captured submenu: %s (%d items)", submenuLabel, #submenuActionEntries))

    return #capture.entries
end

function bridge:_beginCapture(lcm)
    local capture = {
        entries = {},
        originals = {},
        contextControl = nil,
    }

    capture.originals.AddMenuItem = AddMenuItem
    capture.originals.AddCustomMenuItem = AddCustomMenuItem
    capture.originals.AddCustomSubMenuItem = AddCustomSubMenuItem
    capture.originals.AddCustomMenuTooltip = AddCustomMenuTooltip
    capture.originals.ShowMenu = ShowMenu
    capture.originals.ClearMenu = ClearMenu

    _G.AddMenuItem = function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
        return bridge:_captureMenuEntry(capture, mytext, myfunction, itemType, enabled)
    end

    _G.AddCustomMenuItem = function(mytext, myfunction, itemType, myFont, normalColor, highlightColor, itemYPad, horizontalAlignment, isHighlighted, onEnter, onExit, enabled)
        return bridge:_captureMenuEntry(capture, mytext, myfunction, itemType, enabled)
    end

    _G.AddCustomSubMenuItem = function(mytext, entries, myfont, normalColor, highlightColor, itemYPad, callback)
        return bridge:_captureSubMenuEntries(capture, mytext, entries, callback)
    end

    _G.AddCustomMenuTooltip = function()
        return nil
    end

    _G.ShowMenu = function()
        return nil
    end

    _G.ClearMenu = function()
        return nil
    end

    do
        capture.originals.LibAddMenuItem = lcm.AddMenuItem
        lcm.AddMenuItem = function(...)
            return _G.AddMenuItem(...)
        end
    end

    return capture
end

function bridge:_endCapture(lcm, capture)
    if not capture or not capture.originals then
        return
    end

    _G.AddMenuItem = capture.originals.AddMenuItem
    _G.AddCustomMenuItem = capture.originals.AddCustomMenuItem
    _G.AddCustomSubMenuItem = capture.originals.AddCustomSubMenuItem
    _G.AddCustomMenuTooltip = capture.originals.AddCustomMenuTooltip
    _G.ShowMenu = capture.originals.ShowMenu
    _G.ClearMenu = capture.originals.ClearMenu

    if capture.originals.LibAddMenuItem then
        lcm.AddMenuItem = capture.originals.LibAddMenuItem
    end
end

function bridge:_runContextCallbacks(lcm, inventorySlot, slotActions)
    if self._isCapturing then
        return {}
    end
    self._isCapturing = true
    local capture = self:_beginCapture(lcm)
    capture.contextControl = inventorySlot
    local originalGetSlotType = ZO_InventorySlot_GetType
    local originalContextMenuMode = slotActions.m_contextMenuMode
    -- Capture temporarily replaces menu globals. Always restore them even if
    -- an external builder, label, or visibility callback raises an error.
    local ok, err = pcall(function()
        ZO_InventorySlot_GetType = function(slot)
            local slotType = originalGetSlotType(slot)
            return slot == inventorySlot and bridge:_resolveNormalizedSlotType(slot, slotType) or slotType
        end
        slotActions.m_contextMenuMode = true
        local registry = self:_readContextMenuRegistry()
        for category = lcm.CATEGORY_EARLY, lcm.CATEGORY_LATE do
            -- Do not retry an empty or failed callback; side effects may have
            -- happened already. Recover ESO's depth counter after an error.
            local depth = registry:GetFireCallbackDepth()
            local callbackOk, callbackErr = pcall(registry.FireCallbacks, registry, category, inventorySlot, slotActions)
            if not callbackOk then
                registry.fireCallbackDepth = depth
                registry:Clean(category)
                LogDebug("Context callback failed: " .. tostring(callbackErr))
            end
        end
    end)
    slotActions.m_contextMenuMode = originalContextMenuMode
    ZO_InventorySlot_GetType = originalGetSlotType
    self:_endCapture(lcm, capture)
    self._isCapturing = false
    if not ok then
        LogDebug(err)
    end
    return capture.entries
end

function bridge:_appendEntriesToSlotActions(slotActions, entries, inventorySlot)
    local knownNames = CollectExistingActionNames(slotActions)
    local addedCount = 0

    local function AddUniqueAction(label, callback)
        if type(label) ~= "string" or label == "" then
            return
        end
        if type(callback) ~= "function" then
            return
        end
        if knownNames[label] then
            return
        end

        knownNames[label] = true
        local actionName = bridge:_ensureActionStringId(label)
        -- Keep this nil for compatibility with gamepad action dialogs that derive labels from raw action metadata.
        slotActions:AddSlotAction(actionName, callback, nil)
        StampActionLabel(slotActions, label, callback)
        addedCount = addedCount + 1
    end

    for i = 1, #entries do
        local entry = entries[i]
        if type(entry) == "table" then
            if entry.kind == "submenu" then
                -- Clicking the parent is a separate action, not child setup.
                if type(entry.callback) == "function" then
                    AddUniqueAction(entry.label, entry.callback)
                end
                local submenuEntries = entry.entries
                if type(submenuEntries) == "table" and #submenuEntries > 0 then
                    for subIndex = 1, #submenuEntries do
                        local submenuEntry = submenuEntries[subIndex]
                        if
                            type(submenuEntry) == "table"
                            and type(submenuEntry.label) == "string"
                            and submenuEntry.label ~= ""
                            and type(submenuEntry.callback) == "function"
                        then
                            AddUniqueAction(string.format("%s: %s", entry.label, submenuEntry.label), submenuEntry.callback)
                        end
                    end
                end
            else
                AddUniqueAction(entry.label, entry.callback)
            end
        end
    end

    local nativeJunkAction = self:_buildNativeJunkAction(inventorySlot)
    if nativeJunkAction then
        AddUniqueAction(nativeJunkAction.label, nativeJunkAction.callback)
    end

    LogTrace(string.format("Injected %d actions from %d captured entries", addedCount, #entries))
end

function bridge:_tryInjectGamepadContextActions(inventorySlot, slotActions)
    if not self.enabled then
        LogTrace("Skip inject: bridge disabled")
        return
    end

    if slotActions.m_contextMenuMode then
        LogTrace("Skip inject: already in context menu mode")
        return
    end

    if not IsInGamepadPreferredMode() then
        LogTrace("Skip inject: not in gamepad preferred mode")
        return
    end

    do
        local bagId, slotIndex = self:_resolveBagAndSlot(inventorySlot)
        if bagId == nil or slotIndex == nil then
            LogTrace("Skip inject: slot has no bag/slot index")
            return
        end
    end

    local capturedEntries = self:_runContextCallbacks(LibCustomMenu, inventorySlot, slotActions)

    if #capturedEntries == 0 then
        LogTrace("No LibCustomMenu entries captured for this slot")
    end

    self:_appendEntriesToSlotActions(slotActions, capturedEntries, inventorySlot)
end

function bridge:_hookDiscoverSlotActions()
    if self._discoverHooked then
        return
    end
    SecurePostHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
        bridge:_tryInjectGamepadContextActions(inventorySlot, slotActions)
    end)
    self._discoverHooked = true
end

function bridge:_hookRefreshKeybindStrip()
    if self._refreshHooked then
        return
    end
    SecurePostHook(ZO_ItemSlotActionsController, "RefreshKeybindStrip", function(controller)
        if controller.inventorySlot then
            bridge:_tryInjectGamepadContextActions(controller.inventorySlot, controller.slotActions)
        end
    end)
    self._refreshHooked = true
end

function bridge:Initialize()
    if self._initialized then
        return
    end

    self:_initializeSavedVars()
    self:_initializeSlashCommands()
    self:_initializeSettingsPanel()

    self:_hookDiscoverSlotActions()
    self:_hookRefreshKeybindStrip()
    
    -- Попытка подцепить тултипы
    local tooltipHookSuccess = self:_hookTooltipPrice()
    if not tooltipHookSuccess then
        LogDebug("Initial tooltip hook failed, scheduling retry...")
        self:_scheduleTooltipPriceHookRetry()
    end

    -- Тултипы крафтовых станций (gamepad-режим)
    self:_hookCraftingTooltips()

    -- Тултип торгового дома (gamepad-режим)
    self:_hookTradingHouseTooltip()

    self:_registerPlayerActivatedHook()

    self._initialized = true
    LogDebug(string.format(
        "Initialize summary: tooltipHooks=%s crafting=%s tradingHouse=%s overlay=%s enabled=%s",
        tostring(self._tooltipPriceHooked),
        tostring(self._craftingTooltipsHooked == true),
        tostring(self._tradingHouseTooltipHooked),
        tostring(self._overlayWindow ~= nil),
        tostring(self.enabled)
    ))
    LogDebug("Initialized")
end

local EVENT_NAMESPACE = MAJOR .. "_OnLoaded"
local PLAYER_ACTIVATED_EVENT_NAMESPACE = MAJOR .. "_PlayerActivated"

function bridge:_registerPlayerActivatedHook()
    if self._playerActivatedHookRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(PLAYER_ACTIVATED_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        local hooked = bridge:_hookTooltipPrice()
        if not hooked then
            bridge:_scheduleTooltipPriceHookRetry()
        end
        bridge:_hookCraftingTooltips()
        bridge:_hookTradingHouseTooltip()
        EVENT_MANAGER:UnregisterForEvent(PLAYER_ACTIVATED_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    end)

    -- LayoutGuildStoreSearchResult is added to tooltip instances dynamically the first
    -- time the trading house is opened.  Hook on EVENT_OPEN_TRADING_HOUSE so we catch
    -- that moment reliably, even if the player never triggered EVENT_PLAYER_ACTIVATED
    -- while in front of a TH.
    local TH_OPEN_NS = MAJOR .. "_THOpen"
    EVENT_MANAGER:RegisterForEvent(TH_OPEN_NS, EVENT_OPEN_TRADING_HOUSE, function()
        bridge:_hookTradingHouseTooltip()
        LogTrace("EVENT_OPEN_TRADING_HOUSE: retried TH tooltip hook")
    end)

    local TH_CLOSE_NS = MAJOR .. "_THClose"
    EVENT_MANAGER:RegisterForEvent(TH_CLOSE_NS, EVENT_CLOSE_TRADING_HOUSE, function()
        bridge:_hideOverlay()
        LogTrace("Overlay hidden on EVENT_CLOSE_TRADING_HOUSE")
    end)

    local CRAFT_OPEN_NS = MAJOR .. "_CraftOpen"
    EVENT_MANAGER:RegisterForEvent(CRAFT_OPEN_NS, EVENT_CRAFTING_STATION_INTERACT, function(_, craftSkill, sameStation, craftMode)
        bridge._craftingStationActive = true
        bridge._templateCraftingOverlayActive = false
        bridge:_hookTooltipPrice()
        bridge:_hookCraftingTooltips()
        LogTrace(string.format("EVENT_CRAFTING_STATION_INTERACT: skill=%s same=%s mode=%s",
            tostring(craftSkill), tostring(sameStation), tostring(craftMode)))
    end)

    local CRAFT_CLOSE_NS = MAJOR .. "_CraftClose"
    EVENT_MANAGER:RegisterForEvent(CRAFT_CLOSE_NS, EVENT_END_CRAFTING_STATION_INTERACT, function()
        bridge._craftingStationActive = false
        bridge._templateCraftingOverlayActive = false
        bridge:_hideOverlay()
        LogTrace("Overlay hidden on EVENT_END_CRAFTING_STATION_INTERACT")
    end)

    self._playerActivatedHookRegistered = true
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= MAJOR then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)
    bridge:Initialize()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)
