local MAJOR = "LibGamepadContextMenuBridge"
local MINOR = 155
local ADDON_VERSION = "1.5.5"

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
bridge._tooltipTtcCache = bridge._tooltipTtcCache or {}
bridge._formattedTooltipLineCache = bridge._formattedTooltipLineCache or {}
bridge._tooltipTtcCacheSize = bridge._tooltipTtcCacheSize or 0
bridge._formattedTooltipLineCacheSize = bridge._formattedTooltipLineCacheSize or 0
bridge._overlayWindow = bridge._overlayWindow or nil

local SAVED_VARS_NAME = MAJOR .. "_SavedVars"
local SAVED_VARS_VERSION = 1
local EVENT_NAMESPACE = MAJOR .. "_OnLoaded"
local PLAYER_ACTIVATED_EVENT_NAMESPACE = MAJOR .. "_PlayerActivated"
local MODE_EVENT_NAMESPACE = MAJOR .. "_InputMode"
local TH_OPEN_NS, TH_CLOSE_NS = MAJOR .. "_THOpen", MAJOR .. "_THClose"
local CRAFT_OPEN_NS, CRAFT_CLOSE_NS = MAJOR .. "_CraftOpen", MAJOR .. "_CraftClose"
local TOOLTIP_RETRY_NS = MAJOR .. "_TooltipHookRetry"
local BAG_ID_TO_SLOT_TYPE = {
    [BAG_BACKPACK] = SLOT_TYPE_ITEM,
    [BAG_BANK] = SLOT_TYPE_BANK_ITEM,
    [BAG_SUBSCRIBER_BANK] = SLOT_TYPE_BANK_ITEM,
    [BAG_GUILDBANK] = SLOT_TYPE_GUILD_BANK_ITEM,
}
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

local function GetDebugTimestamp()
    return tostring(GetTimeStamp())
end

function bridge:_addDebugHistory(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    local entry = string.format("%s %s", GetDebugTimestamp(), message)
    local debugLog = self._debugLog
    debugLog[#debugLog + 1] = entry

    -- Also persist to SavedVars so the log survives /reloadui and is written to disk.
    local savedVars = self.savedVars
    if savedVars then
        if type(savedVars.debugLog) ~= "table" then
            savedVars.debugLog = {}
        end
        local sv = savedVars.debugLog
        sv[#sv + 1] = entry
        -- Keep SavedVars log bounded (max 500 lines to avoid giant file).
        local svLimit = 500
        while #sv > svLimit do
            table.remove(sv, 1)
        end
    end

    local limit = DEFAULTS.maxDebugMessages
    if savedVars and tonumber(savedVars.maxDebugMessages) then
        limit = math.max(20, tonumber(savedVars.maxDebugMessages))
    end

    while #debugLog > limit do
        table.remove(debugLog, 1)
    end
end

function bridge:_debugMessage(message, verboseOnly, ...)
    if not self.debug then
        return
    end

    if verboseOnly and not self.debugVerbose then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    local formatted = string.format("[%s] %s", MAJOR, tostring(message))
    local savedVars = self.savedVars

    if not savedVars or savedVars.debugStoreHistory ~= false then
        self:_addDebugHistory(formatted)
    end

    if not savedVars or savedVars.debugToChat ~= false then
        d(formatted)
    end
end

local function LogDebug(message, ...)
    bridge:_debugMessage(message, false, ...)
end

local function LogTrace(message, ...)
    bridge:_debugMessage(message, true, ...)
end

local function EvaluateValue(value, ...)
    if type(value) == "function" then
        return value(...)
    end
    return value
end

local function HasItemLink(link)
    return type(link) == "string" and GetLinkType(link) == LINK_TYPE_ITEM
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

    if label == LibCustomMenu.DIVIDER then
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

local function StampActionLabel(slotActions, label)
    -- ESO stores action name/callback at indices 1/2. Named aliases support
    -- third-party dialogs that consume the same action table.
    local entry = slotActions.m_slotActions[#slotActions.m_slotActions]
    entry.name = label
    entry.actionName = label
end

function bridge:_ensureActionStringId(label)
    -- AddSlotAction snapshots GetString(id) into the action's name immediately.
    -- Reuse one private ID; dynamic labels must not allocate globals forever.
    if not self._actionStringId then
        ZO_CreateStringId("SI_LGCMB_ACTION", label)
        self._actionStringId = SI_LGCMB_ACTION
    else
        SafeAddString(self._actionStringId, label, 0)
    end
    return self._actionStringId
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
            if not entry[4] then
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
    return BAG_ID_TO_SLOT_TYPE[bagId] or slotType
end

function bridge:_resolveBagAndSlot(inventorySlot)
    if not inventorySlot then
        return nil, nil
    end
    return ZO_Inventory_GetBagAndIndex(inventorySlot)
end

-- Bag/slot is an address, not an item identity. ESO id64 values must not be
-- converted to floating-point numbers (two different instances may share a link).
function bridge:_getSlotIdentity(inventorySlot)
    local bagId, slotIndex = self:_resolveBagAndSlot(inventorySlot)
    if bagId == nil or slotIndex == nil then return nil end
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if uniqueId == nil then return nil end
    local id = Id64ToString(uniqueId)
    if id == "0" then return nil end
    return { bagId=bagId, slotIndex=slotIndex, id=id }
end

function bridge:_isCurrentActionItem(identity, inventorySlot)
    if not self.enabled or not IsInGamepadPreferredMode() or not identity then return false end
    local current = self:_getSlotIdentity(inventorySlot)
    return current ~= nil and current.bagId == identity.bagId
        and current.slotIndex == identity.slotIndex and current.id == identity.id
end

function bridge:_buildNativeJunkAction(inventorySlot)
    local bagId, slotIndex = self:_resolveBagAndSlot(inventorySlot)
    if bagId == nil or slotIndex == nil or bagId == BAG_VIRTUAL then
        return nil
    end
    local identity = self:_getSlotIdentity(inventorySlot)
    if not identity then return nil end
    local isJunk = IsItemJunk(bagId, slotIndex)
    if IsItemPlayerLocked(bagId, slotIndex) or not CanItemBeMarkedAsJunk(bagId, slotIndex) then
        return nil
    end
    return {
        label = GetString(isJunk and SI_ITEM_ACTION_UNMARK_AS_JUNK or SI_ITEM_ACTION_MARK_AS_JUNK),
        callback = function()
            if not bridge:_isCurrentActionItem(identity, inventorySlot)
                or IsItemJunk(bagId, slotIndex) ~= isJunk
                or IsItemPlayerLocked(bagId, slotIndex)
                or not CanItemBeMarkedAsJunk(bagId, slotIndex) then
                LogDebug("Skipped stale or ineligible junk action")
                return
            end
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
    if self._initialized then self:_syncRuntime() end
    LogDebug("Bridge enabled: %s", tostring(self.enabled))
end

function bridge:SetDebugEnabled(enabled)
    self.debug = not not enabled
    if self.savedVars then
        self.savedVars.debug = self.debug
    end
    self:_debugMessage("Debug enabled: %s", false, tostring(self.debug))
end

function bridge:SetDebugVerbose(enabled)
    self.debugVerbose = not not enabled
    if self.savedVars then
        self.savedVars.debugVerbose = self.debugVerbose
    end
    self:_debugMessage("Debug verbose: %s", false, tostring(self.debugVerbose))
end

function bridge:SetShowTtcPriceInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showTtcPriceInTooltip = value
    end
    if self._initialized then self:_syncRuntime() end
end

function bridge:SetShowTtcPriceDetailsInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showTtcPriceDetailsInTooltip = value
    end
    if self._initialized then self:_syncRuntime() end
end

function bridge:SetShowJunkStatusInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showJunkStatusInTooltip = value
    end
    if self._initialized then self:_syncRuntime() end
end

function bridge:SetShowVendorPriceInTooltip(enabled)
    local value = not not enabled
    if self.savedVars then
        self.savedVars.showVendorPriceInTooltip = value
    end
    if self._initialized then self:_syncRuntime() end
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

    local world = GetWorldName()
    local raw = _G[SAVED_VARS_NAME]
    local account = GetDisplayName()
    local worldAccount = raw and raw[world] and raw[world][account]
    local legacyAccount = raw and raw.Default and raw.Default[account]
    local legacy = legacyAccount and legacyAccount["$AccountWide"]
    local defaults = DEFAULTS
    -- Seed each new server profile, preserving the shared legacy settings and
    -- any server profile that the player already configured.
    if not (worldAccount and worldAccount["$AccountWide"]) and legacy and legacy.version == SAVED_VARS_VERSION then
        defaults = ZO_DeepTableCopy(DEFAULTS)
        for key in pairs(DEFAULTS) do
            local value = legacy[key]
            if value ~= nil then
                defaults[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
            end
        end
    end
    local savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, nil, defaults, world)
    self.savedVars = savedVars
    self.enabled = savedVars.enabled ~= false
    self.debug = savedVars.debug == true
    self.debugVerbose = savedVars.debugVerbose == true
    -- Restore in-memory log from persisted SavedVars log.
    if type(savedVars.debugLog) == "table" then
        for _, v in ipairs(savedVars.debugLog) do
            self._debugLog[#self._debugLog + 1] = v
        end
    else
        savedVars.debugLog = {}
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

function bridge:_getTtcPriceInfo(itemLink)
    -- TTC is optional; once loaded, use its documented public price provider.
    if not TamrielTradeCentrePrice then
        LogTrace("TTC lookup skipped: provider missing")
        return nil
    end
    if not HasItemLink(itemLink) then
        LogTrace("TTC lookup skipped: invalid item link")
        return nil
    end
    local info = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
    if info == nil then LogTrace("TTC lookup returned no price") end
    return info
end

function bridge:_formatTooltipInfoCurrency(value)
    if type(value) == "number" then
        return ZO_CurrencyControl_FormatCurrency(math.floor(value + 0.5), true)
    end
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

local function BoundedCacheInsert(owner, cacheField, sizeField, limit, key, value)
    if owner[cacheField][key] == nil then
        if owner[sizeField] >= limit then
            owner[cacheField], owner[sizeField] = {}, 0
        end
        owner[sizeField] = owner[sizeField] + 1
    end
    owner[cacheField][key] = value
end

function bridge:_getTtcCacheFingerprint()
    local provider = TamrielTradeCentrePrice
    local prices = provider and provider.PriceTable
    local region = TamrielTradeCentre and TamrielTradeCentre:GetCurrentServerRegion()
    return table.concat({tostring(provider), tostring(prices), tostring(prices and prices.Data),
        tostring(prices and prices.TimeStamp), tostring(region), GetWorldName()}, "|")
end

function bridge:_getCachedTtcTooltipLines(itemLink)
    local cacheKey = self:_getTooltipTtcCacheKey(itemLink)
    if not cacheKey then
        return nil
    end

    local now = GetGameTimeMilliseconds()
    local fingerprint = self:_getTtcCacheFingerprint()
    local cached = self._tooltipTtcCache[cacheKey]
    if cached and cached.fingerprint == fingerprint and now < cached.expiresAt then
        return cached.lines, cached.info, cached.expiresAt
    end

    local lines, priceInfo = {}, nil
    local info = self:_getTtcPriceInfo(itemLink)
    if type(info) == "table" then
        -- TTC can return a mutable table; retain only this request's price values.
        priceInfo = {SuggestedPrice=info.SuggestedPrice, Avg=info.Avg, Min=info.Min, Max=info.Max}
    end
    if self:_shouldShowTtcTooltipPrice() then
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

    local expiresAt = now + (priceInfo and 5000 or 1000)
    BoundedCacheInsert(self, "_tooltipTtcCache", "_tooltipTtcCacheSize", 256, cacheKey,
        {lines=lines, info=priceInfo, expiresAt=expiresAt, fingerprint=fingerprint})
    return lines, priceInfo, expiresAt
end

function bridge:_getRequestPriceInfo(request, itemLink)
    if not HasItemLink(itemLink) then return nil, {} end
    local snapshot = request.prices[itemLink]
    if snapshot == nil then
        local lines, info, expiresAt = self:_getCachedTtcTooltipLines(itemLink)
        snapshot = {lines=lines or {}, info=info}
        request.prices[itemLink] = snapshot
        if expiresAt then request.expiresAt = math.min(request.expiresAt or expiresAt, expiresAt) end
    end
    return snapshot.info, snapshot.lines
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
    return HasItemLink(itemLink) and IsItemLinkBound(itemLink) or false
end

function bridge:_buildTooltipInfoLines(bagId, slotIndex)
    local lines = {}
    local itemLink = self:_getItemLinkFromBagAndSlot(bagId, slotIndex)
    if self:_isBoundItem(bagId, slotIndex, itemLink) then
        return lines
    end

    local stackCount = GetSlotStackSize(bagId, slotIndex)
    if itemLink then
        local itemLines = self:_buildTooltipInfoLinesByLink(itemLink, stackCount, nil, false)
        ZO_CombineNumericallyIndexedTables(lines, itemLines)
        lines.expiresAt = itemLines.expiresAt
        lines.priceFingerprint = itemLines.priceFingerprint
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

function bridge:_buildTooltipInfoLinesByLink(itemLink, stackCount, listingPrice, includeVendor, craftContext, source, request)
    local lines = {}
    request = request or {prices={}}
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
        local priceInfo, unitLines = self:_getRequestPriceInfo(request, itemLink)
        ZO_CombineNumericallyIndexedTables(lines, unitLines)

        if type(stackCount) == "number" and stackCount > 1 then
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
        ZO_CombineNumericallyIndexedTables(lines, self:_buildCraftMaterialCostLines(itemLink, craftContext, request))
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

    lines.expiresAt = request.expiresAt
    lines.priceFingerprint = self:_getTtcCacheFingerprint()
    return lines
end

function bridge:_getItemLinkQualityHex(itemLink)
    if not HasItemLink(itemLink) then
        return "B8B29A"
    end
    return GetItemQualityColor(GetItemLinkDisplayQuality(itemLink)):ToHex()
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
                itemLink = HasItemLink(link) and link or nil,
                quantity = quantity,
                name = HasItemLink(link) and GetItemLinkName(link) or nil,
            }
        end
    end
    return ingredients
end

function bridge:_collectRecipeIngredientsByResultLink(resultItemLink)
    if not HasItemLink(resultItemLink) then return {} end
    local itemId = GetItemLinkItemId(resultItemLink)
    if itemId > 0 then
        local _, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(itemId)
        if recipeListIndex and recipeIndex then
            return self:_collectRecipeIngredients(recipeListIndex, recipeIndex), recipeListIndex, recipeIndex
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
        if HasItemLink(link) then
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

function bridge:_buildCraftMaterialCostLines(resultItemLink, craftContext, request)
    if type(craftContext) ~= "table" then
        return {}
    end
    request = request or {prices={}}

    local ingredients, outputQuantity
    local recipeListIndex, recipeIndex = craftContext.recipeListIndex, craftContext.recipeIndex
    if craftContext.recipeListIndex and craftContext.recipeIndex then
        ingredients = self:_collectRecipeIngredients(craftContext.recipeListIndex, craftContext.recipeIndex)
    elseif craftContext.forceSmithingPatternMaterials then
        ingredients = self:_collectSmithingPatternIngredients(craftContext)
        outputQuantity = 1
    elseif craftContext.selectedData then
        ingredients = self:_collectIngredientsFromSelectedData(craftContext.selectedData)
        recipeListIndex, recipeIndex = craftContext.selectedData.recipeListIndex, craftContext.selectedData.recipeIndex
    else
        ingredients, recipeListIndex, recipeIndex = self:_collectRecipeIngredientsByResultLink(resultItemLink)
    end
    if recipeListIndex and recipeIndex then
        outputQuantity = GetRecipeResultQuantity(recipeListIndex, recipeIndex, 1)
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
            name = HasItemLink(link) and GetItemLinkName(link) or "Unknown mat."
        end

        if type(name) ~= "string" or name == "" then
            -- Skip unknown placeholder-like ingredients to avoid noisy fake entries.
        else
            name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
            namedIngredientCount = namedIngredientCount + 1
            local costText = "n/a"
            if HasItemLink(link) then
                local priceInfo = self:_getRequestPriceInfo(request, link)
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
        lines[#lines + 1] = "|cD7C98FMat total: " .. totalText .. " (per craft)|r"

        local resultPriceInfo = self:_getRequestPriceInfo(request, resultItemLink)
        local resultUnit = resultPriceInfo and (resultPriceInfo.SuggestedPrice or resultPriceInfo.Avg)
        if type(outputQuantity) == "number" and outputQuantity > 0 and type(resultUnit) == "number" and resultUnit > 0 then
            local delta = resultUnit * outputQuantity - totalCost
            local deltaText = self:_formatCompactTooltipCurrency(math.abs(delta)) or tostring(math.floor(math.abs(delta) + 0.5))
            local basis = string.format(" (per craft; output x%d)|r", outputQuantity)
            if delta > 0.5 then
                lines[#lines + 1] = "|c6AB87Avs crafted: +" .. deltaText .. basis
            elseif delta < -0.5 then
                lines[#lines + 1] = "|cD46A6Avs crafted: -" .. deltaText .. basis
            else
                lines[#lines + 1] = "|cA0A070vs crafted: near zero" .. basis
            end
        elseif type(outputQuantity) ~= "number" or outputQuantity <= 0 then
            lines[#lines + 1] = "|cD7C98FCraft comparison unavailable: output unknown|r"
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

    BoundedCacheInsert(bridge, "_formattedTooltipLineCache", "_formattedTooltipLineCacheSize", 128, text, formatted)
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

-- A content tooltip mixes in a styled GetParent(), not native ancestry.
-- Native callers pass the manager container / crafting panel explicitly.
function bridge:_getActiveOverlayTooltip()
    local owner = self._overlayOwnerControl or self._overlayTooltipControl
    if self:_isRenderableControl(owner) then return self._overlayTooltipControl end
    return nil
end

function bridge:_getOverlayAnchorContainer()
    local owner = self._overlayOwnerControl or self._overlayTooltipControl
    if self:_isRenderableControl(owner) then return owner end
    return nil
end

function bridge:_shouldKeepOverlayVisible()
    if self._overlayOwnerControl or self._overlayTooltipControl then
        return self:_getOverlayAnchorContainer() ~= nil
    end
    return self:_isRenderableControl(self._overlayAnchorControl)
end

function bridge:_refreshOverlayVisibility()
    local overlay = self._overlayWindow
    if not overlay or not overlay.window or overlay.window:IsHidden() then return end
    local now = GetGameTimeMilliseconds()
    if now - (overlay._lastVisibilityCheckAt or 0) < 100 then return end
    overlay._lastVisibilityCheckAt = now
    if not self:_canUseOverlay() or not self:_shouldKeepOverlayVisible() then
        self:_hideOverlay()
        return
    end
    -- No timer/polling survives hide. Only the current visible owner's model can
    -- refresh, using its retained request, never a different visible tooltip.
    if self._overlayRefresh and self._overlayPriceExpiresAt
        and (now >= self._overlayPriceExpiresAt or self._overlayPriceFingerprint ~= self:_getTtcCacheFingerprint()) then
        local refresh = self._overlayRefresh
        self._overlayRefresh = nil
        refresh()
    end
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
    self._overlayOwnerControl = nil
    self._overlayRefresh = nil
    self._overlayPriceExpiresAt = nil
    self._overlayPriceFingerprint = nil

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
    elseif not self._overlayOwnerControl and not self._overlayTooltipControl and self:_isRenderableControl(self._overlayAnchorControl) then
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

local function AppendIfValue(lines, value)
    if value then
        lines[#lines + 1] = value
    end
end

local function BuildCompactOverlayBaseLines(info)
    local compact = {}

    AppendIfValue(compact, info.ttc and string.format("|cD8C06ATTC: %s|r", info.ttc) or nil)
    AppendIfValue(compact, info.minAvgMax and FormatTooltipLine("Min/Avg/Max: " .. info.minAvgMax))
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

    local compact = BuildCompactOverlayBaseLines(info)
    AppendIfValue(compact, info.vendor and string.format("|cC9B36BVendor: %s|r", info.vendor) or nil)
    if source == "bag" then
        AppendIfValue(compact, info.junk == "Yes" and "|cB088D9Junk: Yes|r" or nil)
    end
    AppendIfValue(compact, info.versusTtc and FormatTooltipLine("vs TTC: " .. info.versusTtc))

    if #compact > 0 then
        return compact
    end

    return lines
end

function bridge:_scheduleOverlayShowRetry(lines, source, tooltipControl, retryCount, generation, owner)
    retryCount = tonumber(retryCount) or 0
    if retryCount >= 6 then return false end
    zo_callLater(function()
        if bridge._overlayGeneration ~= generation then return end
        bridge:_showOverlayLines(lines, source, tooltipControl, retryCount + 1, generation, owner)
    end, 40)
    return true
end

function bridge:_showOverlayLines(lines, source, tooltipControl, retryCount, generation, owner)
    if not self.enabled or not IsInGamepadPreferredMode() then return end
    local preparing = generation == nil
    if preparing then
        self._overlayGeneration = (self._overlayGeneration or 0) + 1
        generation = self._overlayGeneration
        self._overlayRefresh = nil
    elseif self._overlayGeneration ~= generation then
        return
    end
    if type(lines) ~= "table" or #lines == 0 then self:_hideOverlay();return end
    local overlay = self:_ensureOverlayWindow()
    if not overlay or not overlay.label then return end
    if preparing then
        -- A replacement/pending request must not expose the previous anchor.
        overlay.window:SetHidden(true)
        overlay.window:SetHandler("OnUpdate", nil)
        self._overlaySource = source
        self._overlayTooltipControl = tooltipControl
        self._overlayOwnerControl = owner or tooltipControl
        self._overlayPriceExpiresAt = lines.expiresAt
        self._overlayPriceFingerprint = lines.priceFingerprint
        local overlayLines = self:_buildCompactOverlayLines(lines, source)
        local formattedLines = {}
        for i = 1, #overlayLines do
            local line = overlayLines[i]
            formattedLines[i] = type(line) == "string" and line:find("|c") and line or FormatTooltipLine(line)
        end
        local crafting = source == "furncraft"
        if overlay.backdrop then
            if crafting then overlay.backdrop:SetCenterColor(0, 0, 0, 0.70) end
            overlay.backdrop:SetHidden(not crafting)
        end
        for _, name in ipairs({"borderTop", "borderBottom", "borderLeft", "borderRight"}) do
            if overlay[name] then overlay[name]:SetHidden(not crafting) end
        end
        self:_renderOverlayLines(overlay, formattedLines)
    end
    -- Only geometry may change between anchor attempts. Presentation is prepared once.
    self:_resizeOverlayToText(overlay)
    if not self:_positionOverlay() then
        overlay.window:SetHidden(true)
        if not self:_scheduleOverlayShowRetry(lines, source, tooltipControl, retryCount, generation, owner) then
            LogDebug("Overlay request cancelled: owner anchor unavailable after retries")
            self:_hideOverlay()
        end
        return
    end
    if not self._onRefreshOverlay then
        self._onRefreshOverlay = function() bridge:_refreshOverlayVisibility() end
    end
    overlay.window:SetHandler("OnUpdate", self._onRefreshOverlay)
    overlay.window:SetHidden(false)
end

function bridge:_appendGamepadTooltipInfoByLink(tooltip, itemLink, stackCount, listingPrice, source, craftContext, owner)
    if tooltip == nil or type(itemLink) ~= "string" or itemLink == "" then
        return
    end

    -- Coalesce only requests for the current overlay generation and owner.
    -- Hiding or replacing the overlay must allow the same item to show again.
    local contextKey = ""
    if type(craftContext) == "table" then
        contextKey = table.concat({
            tostring(craftContext.recipeListIndex or ""),
            tostring(craftContext.recipeIndex or ""),
            tostring(craftContext.patternIndex or ""),
            tostring(craftContext.materialIndex or ""),
            tostring(craftContext.materialQuantity or ""),
            tostring(craftContext.styleIndex or ""),
            tostring(craftContext.traitIndex or ""),
            tostring(craftContext.forceSmithingPatternMaterials or false),
        }, ":")
    end
    local dedupKey = itemLink .. "|" .. tostring(stackCount or "") .. "|" .. tostring(listingPrice or "") .. "|" .. tostring(source or "") .. "|" .. contextKey
    local now = GetGameTimeMilliseconds()
    if self._overlayTooltipControl == tooltip
        and self._overlayOwnerControl == (owner or tooltip)
        and tooltip._lgcmbLastPriceFingerprint == self:_getTtcCacheFingerprint()
        and (not self._overlayPriceExpiresAt or now < self._overlayPriceExpiresAt)
        and tooltip._lgcmbLastGeneration == self._overlayGeneration
        and tooltip._lgcmbLastKey == dedupKey
        and now - (tooltip._lgcmbLastLinkTime or 0) < 200 then
        return
    end

    local lines = self:_buildTooltipInfoLinesByLink(itemLink, stackCount, listingPrice, true, craftContext, source)

    if #lines == 0 then
        self:_hideOverlay()
        return
    end

    self:_showOverlayLines(lines, source, tooltip, nil, nil, owner)
    self._overlayRefresh = function()
        bridge:_appendGamepadTooltipInfoByLink(tooltip, itemLink, stackCount, listingPrice, source, craftContext, owner)
    end
    tooltip._lgcmbLastPriceFingerprint = self:_getTtcCacheFingerprint()
    tooltip._lgcmbLastKey = dedupKey
    tooltip._lgcmbLastLinkTime = now
    tooltip._lgcmbLastGeneration = self._overlayGeneration
end

function bridge:_appendGamepadTooltipInfo(tooltip, bagId, slotIndex, source, owner)
    local lines = self:_buildTooltipInfoLines(bagId, slotIndex)

    if #lines == 0 then
        self:_hideOverlay()
        return
    end

    self:_showOverlayLines(lines, source, tooltip, nil, nil, owner)
    local slot = {bagId=bagId, slotIndex=slotIndex}
    local identity = self:_getSlotIdentity(slot)
    self._overlayRefresh = function()
        if bridge:_isCurrentActionItem(identity, slot) then
            bridge:_appendGamepadTooltipInfo(tooltip, bagId, slotIndex, source, owner)
        else
            bridge:_hideOverlay()
        end
    end
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
            -- Every manager layout clears this content, including unsupported
            -- layouts that reuse a visible owner without a hidden event.
            ZO_PostHook(tooltip, "ClearLines", function(control)
                if bridge._overlayTooltipControl == control then
                    bridge:_hideOverlay()
                end
            end)
            ZO_PostHook(tooltip, "LayoutBagItem", function(control, bagId, slotIndex)
                if bridge:_canUseOverlay() then
                    bridge:_appendGamepadTooltipInfo(control, bagId, slotIndex, "bag", GAMEPAD_TOOLTIPS:GetTooltipContainer(kind))
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
        if not bridge:_canUseOverlay() then
            return
        end
        if control:IsControlHidden() or not HasItemLink(itemLink) then
            bridge:_hideOverlay()
            return
        end
        bridge:_appendGamepadTooltipInfoByLink(tooltip, itemLink, nil, nil, "furncraft", context, control)
    end
    SecurePostHook(ZO_GamepadSmithingCreation, "SetupResultTooltip", function(creation, pattern, material, quantity, styleId, trait)
        if not bridge:_canUseOverlay() then return end
        local context = bridge:_makeCraftContext(pattern, material, quantity, styleId, trait)
        context.forceSmithingPatternMaterials = true
        local link = GetSmithingPatternResultLink(pattern, material, quantity, styleId, trait, LINK_STYLE_DEFAULT)
        ShowResult(creation.resultTooltip, creation.resultTooltip.tip, link, context)
    end)
    SecurePostHook(ZO_GamepadProvisioner, "RefreshRecipeDetails", function(provisioner, selectedData)
        if not bridge:_canUseOverlay() then return end
        if not selectedData then
            bridge:_hideOverlay()
            return
        end
        local listIndex, recipeIndex = selectedData.recipeListIndex, selectedData.recipeIndex
        local link = GetRecipeResultItemLink(listIndex, recipeIndex, LINK_STYLE_DEFAULT)
        local context = bridge:_makeRecipeCraftContext(listIndex, recipeIndex, selectedData)
        ShowResult(provisioner.resultTooltip, provisioner.resultTooltip.tip, link, context)
    end)
    SecurePostHook(ZO_GamepadAlchemy, "UpdateTooltip", function(alchemy)
        if not bridge:_canUseOverlay() then return end
        local link = alchemy:IsCraftable() and alchemy:GetResultItemLink() or nil
        ShowResult(alchemy.tooltip, alchemy.tooltip.tip, link)
    end)
    SecurePostHook(ZO_GamepadEnchanting, "UpdateTooltip", function(enchanting)
        if not bridge:_canUseOverlay() then return end
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
        if not bridge:_canUseOverlay() then
            return
        end
        if not HasItemLink(itemLink) then
            bridge:_hideOverlay()
            return
        end
        local price, selectedCount = bridge:_lookupTradingHouseListingPrice(itemLink, stackCount, sellerName)
        control._lgcmbLastKey = nil
        bridge:_appendGamepadTooltipInfoByLink(control, itemLink, selectedCount or stackCount, price, "guildstore", nil,
            GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_RIGHT_TOOLTIP))
    end)
    self._tradingHouseTooltipHooked = true
    return true
end

function bridge:_scheduleTooltipPriceHookRetry()
    if not self:_canUseOverlay() or self._tooltipHookRetryScheduled or (self._tooltipPriceHooked and self._craftingTooltipsHooked and self._tradingHouseTooltipHooked) then
        return
    end
    local attempts = self._tooltipHookRetryAttempts or 0
    if attempts >= 6 then
        return
    end
    self._tooltipHookRetryAttempts = attempts + 1
    self._tooltipHookRetryScheduled = true
    local generation = self._tooltipHookRetryGeneration or 0
    EVENT_MANAGER:RegisterForUpdate(TOOLTIP_RETRY_NS, 2500, function()
        if generation ~= (bridge._tooltipHookRetryGeneration or 0) then return end
        EVENT_MANAGER:UnregisterForUpdate(TOOLTIP_RETRY_NS)
        bridge._tooltipHookRetryScheduled = false
        if not bridge:_canUseOverlay() then return end
        bridge:_hookTooltipPrice()
        bridge:_hookCraftingTooltips()
        bridge:_hookTradingHouseTooltip()
        bridge:_scheduleTooltipPriceHookRetry()
    end)
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
        local cmd = string.lower(zo_strtrim(text or ""))
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

    if itemTypeValue == MENU_ADD_OPTION_CHECKBOX then
        LogDebug("Unsupported top-level checkbox: requires a native mouse control")
        return #capture.entries
    end
    if itemTypeValue ~= MENU_ADD_OPTION_LABEL or type(labelValue) == "function" then
        LogDebug("Unsupported top-level menu item: requires a native mouse row")
        return #capture.entries
    end
    -- Native AddMenuItem stores enabled as a value; it does not call it.
    if enabled == false then
        return #capture.entries
    end

    local label = ResolveLabel(labelValue, capture.contextControl)
    if not label or IsDividerLabel(label) then
        return #capture.entries
    end

    if type(callback) ~= "function" then
        return #capture.entries
    end

    capture.entries[#capture.entries + 1] = {
        kind = "action",
        label = label,
        callback = function()
            callback()
        end,
    }
    LogTrace("Captured action: %s", label)

    return #capture.entries
end

-- LCM evaluates these fields against real mouse-menu rows, never bag rows.
local function NormalizeSubmenuEntry(entry)
    if type(entry) ~= "table" then return nil end
    if entry.visible ~= nil and not EvaluateValue(entry.visible, ZO_Menu) then return nil end
    local kind = entry.itemType or MENU_ADD_OPTION_LABEL
    if kind == MENU_ADD_OPTION_HEADER then return nil end
    local labelValue = entry.label or entry.name or entry[1]
    if type(labelValue) == "function" or type(entry.disabled) == "function"
        or (kind == MENU_ADD_OPTION_CHECKBOX and type(entry.checked) == "function") then
        LogDebug("Unsupported submenu evaluator: requires a native mouse row")
        return nil
    end
    if entry.disabled then return nil end
    local label = ResolveLabel(labelValue)
    local callback = entry.callback or entry.func or entry[2]
    if not label or IsDividerLabel(label) or type(callback) ~= "function" then return nil end
    local checked = not not entry.checked
    if kind == MENU_ADD_OPTION_CHECKBOX then
        label = string.format("[%s] %s", checked and "x" or " ", label)
    elseif kind ~= MENU_ADD_OPTION_LABEL then
        LogDebug("Unsupported submenu item type: %s", tostring(kind))
        return nil
    end
    return {label=label, callback=function()
        if kind == MENU_ADD_OPTION_CHECKBOX then return callback(not checked) end
        return callback()
    end}
end

function bridge:_captureSubMenuEntries(capture, submenuLabelValue, entries, submenuCallback)
    if type(entries) == "function" or type(submenuLabelValue) == "function" then
        LogDebug("Unsupported submenu builder: requires a native mouse parent")
        return #capture.entries
    end
    local label = ResolveLabel(submenuLabelValue)
    if not label or type(entries) ~= "table" then return #capture.entries end
    if type(submenuCallback) == "function" then
        LogDebug("Unsupported submenu parent click: requires a native mouse control")
    end
    local children = {}
    for i = 1, #entries do
        local child = NormalizeSubmenuEntry(entries[i])
        if child then children[#children + 1] = child end
    end
    if #children > 0 then
        capture.entries[#capture.entries + 1] = {kind="submenu", label=label, entries=children}
    end
    return #capture.entries
end

-- Each replacement is journaled before assignment, including an absent field.
-- The caller owns the journal before setup starts, so partial setup can unwind.
local function ReplaceCaptured(capture, target, key, value)
    capture.journal[#capture.journal + 1] = {target=target, key=key, value=rawget(target, key)}
    target[key] = value
end

function bridge:_beginCapture(lcm, capture)
    capture = capture or {entries={}, journal={}}
    local function MenuItem(text, callback, kind, font, normal, highlight, pad, alignment, highlighted, onEnter, onExit, enabled)
        if capture.nativeAdding then
            local native = capture.nativeAdding
            native._contextMenuRows[native.m_slotActions[#native.m_slotActions]] = true
            return #capture.entries
        end
        return bridge:_captureMenuEntry(capture, text, callback, kind, enabled)
    end
    ReplaceCaptured(capture, _G, "AddMenuItem", MenuItem)
    ReplaceCaptured(capture, _G, "AddCustomMenuItem", MenuItem)
    ReplaceCaptured(capture, _G, "AddCustomSubMenuItem", function(text, entries, font, normal, highlight, pad, callback)
        return bridge:_captureSubMenuEntries(capture, text, entries, callback)
    end)
    ReplaceCaptured(capture, _G, "ClearMenu", function()
        -- Only menu rows are cleared; identity and transaction state survive.
        for i = #capture.entries, 1, -1 do capture.entries[i] = nil end
        local facade = capture.actionFacade
        if facade then
            for action, emitted in pairs(facade._contextMenuRows) do
                if emitted then facade._contextMenuRows[action] = false end
            end
        end
    end)
    for _, key in ipairs({"AddCustomMenuTooltip", "ShowMenu"}) do
        ReplaceCaptured(capture, _G, key, function() end)
    end
    ReplaceCaptured(capture, lcm, "AddMenuItem", MenuItem)
    return capture
end

function bridge:_endCapture(lcm, capture)
    for i = #capture.journal, 1, -1 do
        local entry = capture.journal[i]
        -- Raw restoration cannot trigger the setter that made setup fail.
        rawset(entry.target, entry.key, entry.value)
    end
end

local function CopyActionState(value, seen)
    if type(value) ~= "table" then return value end
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do copy[key] = CopyActionState(entry, seen) end
    return setmetatable(copy, getmetatable(value))
end

local function CreateActionFacade(slotActions, capture)
    local facade = {}
    for key, value in pairs(slotActions) do facade[key] = value end
    local seen = {}
    facade.m_slotActions = CopyActionState(slotActions.m_slotActions or {}, seen)
    facade.m_keybindActions = CopyActionState(slotActions.m_keybindActions or {}, seen)
    facade.m_contextMenuMode = true
    facade._contextMenuRows = {}
    facade._originalActions = {}
    for original, copy in pairs(seen) do facade._originalActions[copy] = original end
    -- Inherit the actual native/third-party methods: add/read/clear/adjust all
    -- operate on the same isolated arrays, not an append-only imitation.
    setmetatable(facade, getmetatable(slotActions))
    local add = slotActions.AddSlotAction
    facade.AddSlotAction = function(self, ...)
        capture.nativeAdding = self
        local result = add(self, ...)
        capture.nativeAdding = false
        local action = self.m_slotActions[#self.m_slotActions]
        if self._contextMenuRows[action] == nil then self._contextMenuRows[action] = false end
        return result
    end
    return facade
end

function bridge:_runContextCallbacks(lcm, inventorySlot, slotActions)
    if self._isCapturing then return {} end
    local capture = {entries={}, journal={}, contextControl=inventorySlot}
    local registry, originalDepth, activeCategory
    self._isCapturing = true
    local ok, err = xpcall(function()
        self:_beginCapture(lcm, capture)
        local originalGetSlotType = ZO_InventorySlot_GetType
        ReplaceCaptured(capture, _G, "ZO_InventorySlot_GetType", function(slot)
            local kind = originalGetSlotType(slot)
            return slot == inventorySlot and bridge:_resolveNormalizedSlotType(slot, kind) or kind
        end)
        registry = self:_readContextMenuRegistry()
        originalDepth = registry:GetFireCallbackDepth()
        capture.entries.identity = self:_getSlotIdentity(inventorySlot)
        local facade = CreateActionFacade(slotActions, capture)
        capture.actionFacade = facade
        for category = lcm.CATEGORY_EARLY, lcm.CATEGORY_LATE do
            activeCategory = category
            registry:FireCallbacks(category, inventorySlot, facade)
        end
        capture.entries.nativeState = facade
    end, debug.traceback)
    self:_endCapture(lcm, capture)
    self._isCapturing = false
    if not ok then
        if registry and originalDepth ~= nil then
            registry.fireCallbackDepth = originalDepth
            if activeCategory then registry:Clean(activeCategory) end
        end
        error(err, 0)
    end
    return capture.entries
end

local function SameActionState(left, right, seen)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    seen = seen or {}
    if seen[left] then return seen[left] == right end
    seen[left] = right
    for key, value in pairs(left) do
        if not SameActionState(value, right[key], seen) then return false end
    end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

function bridge:_mergeNativeActions(slotActions, state, identity, inventorySlot)
    local function GuardChanged(rows)
        for _, action in pairs(rows) do
            local original = state._originalActions[action]
            if not original or not SameActionState(action, original) then
                local callback, visible = action[2], action[4]
                action[2] = function()
                    if bridge:_isCurrentActionItem(identity, inventorySlot) and (not visible or visible()) then
                        return callback()
                    end
                    LogDebug("Skipped stale or hidden native context action")
                end
            end
        end
    end
    -- Native AddSlotAction stores silent/hidden rows for reads/keybinds, but
    -- does not emit them into a context menu. Keep that distinction when
    -- translating the new context rows into the gamepad dialog's flat array.
    local contextRows = {}
    for _, action in ipairs(state.m_slotActions) do
        if state._contextMenuRows[action] ~= false then contextRows[#contextRows + 1] = action end
    end
    state.m_slotActions = contextRows
    GuardChanged(state.m_slotActions)
    GuardChanged(state.m_keybindActions)
    slotActions.m_slotActions = state.m_slotActions
    slotActions.m_keybindActions = state.m_keybindActions
    slotActions.m_inventorySlot = state.m_inventorySlot
    slotActions.m_hasActions = state.m_hasActions
    slotActions.m_numContextMenuActions = state.m_numContextMenuActions
end

function bridge:_appendEntriesToSlotActions(slotActions, entries, inventorySlot)
    local identity = entries.identity
    if not entries.nativeState then identity = self:_getSlotIdentity(inventorySlot) end
    if entries.nativeState then
        if not self:_isCurrentActionItem(identity, inventorySlot) then return end
        self:_mergeNativeActions(slotActions, entries.nativeState, identity, inventorySlot)
    end
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
        slotActions:AddSlotAction(actionName, function()
            if bridge:_isCurrentActionItem(identity, inventorySlot) then
                return callback()
            end
            LogDebug("Skipped stale context action: %s", label)
        end, nil)
        StampActionLabel(slotActions, label)
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

    LogTrace("Injected %d actions from %d captured entries", addedCount, #entries)
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

    -- This native read completes LCM's pending keybind categories against the
    -- live actions before we snapshot them. Inherited AddSlotAction prehooks
    -- must not advance that lifecycle inside the isolated context transaction.
    slotActions:GetPrimaryActionName()
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
    SecurePostHook(_G, "ZO_InventorySlot_DiscoverSlotActionsFromActionList", function(inventorySlot, slotActions)
        bridge:_tryInjectGamepadContextActions(inventorySlot, slotActions)
    end)
    self._discoverHooked = true
end

function bridge:_hookRefreshKeybindStrip()
    -- RebuildActions already invokes discovery before RefreshKeybindStrip.
    -- A refresh is presentation-only, including when the builder returned empty.
    -- Keep the private entrypoint for callers, but never redispatch from here.
end

function bridge:Initialize()
    if self._initialized then
        return
    end

    self:_initializeSavedVars()
    self:_initializeSlashCommands()
    self:_initializeSettingsPanel()

    -- Keep addon load limited to settings and readiness listeners. Gamepad hooks
    -- are installed on first activation of the input mode, not at addon load.
    self:_registerPlayerActivatedHook()
    self._initialized = true
    LogDebug("Initialized")
end

function bridge:_canUseOverlay()
    return self.enabled and IsInGamepadPreferredMode() and
        (self:_shouldShowTtcTooltipPrice() or self:_shouldShowJunkStatusInTooltip() or self:_shouldShowVendorPriceInTooltip())
end

function bridge:_stopOverlayRuntime()
    EVENT_MANAGER:UnregisterForEvent(TH_OPEN_NS, EVENT_OPEN_TRADING_HOUSE)
    EVENT_MANAGER:UnregisterForEvent(TH_CLOSE_NS, EVENT_CLOSE_TRADING_HOUSE)
    EVENT_MANAGER:UnregisterForEvent(CRAFT_OPEN_NS, EVENT_CRAFTING_STATION_INTERACT)
    EVENT_MANAGER:UnregisterForEvent(CRAFT_CLOSE_NS, EVENT_END_CRAFTING_STATION_INTERACT)
    EVENT_MANAGER:UnregisterForUpdate(TOOLTIP_RETRY_NS)
    self._contextEventsRegistered = false
    self._tooltipHookRetryGeneration = (self._tooltipHookRetryGeneration or 0) + 1
    self._tooltipHookRetryScheduled = false
    self._tooltipHookRetryAttempts = 0
    self:_hideOverlay()
end

function bridge:_registerContextEvents()
    if self._contextEventsRegistered then return end
    local function OnTradingHouseOpen()
        if not bridge:_canUseOverlay() then return end
        bridge:_hookTradingHouseTooltip()
        EVENT_MANAGER:RegisterForEvent(TH_CLOSE_NS, EVENT_CLOSE_TRADING_HOUSE, function()
            EVENT_MANAGER:UnregisterForEvent(TH_CLOSE_NS, EVENT_CLOSE_TRADING_HOUSE)
            bridge:_hideOverlay()
        end)
    end
    local function OnCraftingOpen()
        if not bridge:_canUseOverlay() then return end
        bridge:_hookCraftingTooltips()
        EVENT_MANAGER:RegisterForEvent(CRAFT_CLOSE_NS, EVENT_END_CRAFTING_STATION_INTERACT, function()
            EVENT_MANAGER:UnregisterForEvent(CRAFT_CLOSE_NS, EVENT_END_CRAFTING_STATION_INTERACT)
            bridge:_hideOverlay()
        end)
    end
    EVENT_MANAGER:RegisterForEvent(TH_OPEN_NS, EVENT_OPEN_TRADING_HOUSE, OnTradingHouseOpen)
    EVENT_MANAGER:RegisterForEvent(CRAFT_OPEN_NS, EVENT_CRAFTING_STATION_INTERACT, OnCraftingOpen)
    self._contextEventsRegistered = true
    -- Settings/input mode can change while an interaction is already open.
    if GetInteractionType() == INTERACTION_TRADINGHOUSE then OnTradingHouseOpen() end
    if GetCraftingInteractionType() ~= CRAFTING_TYPE_INVALID then OnCraftingOpen() end
end

function bridge:_syncRuntime()
    if not self.enabled then
        EVENT_MANAGER:UnregisterForEvent(MODE_EVENT_NAMESPACE, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(PLAYER_ACTIVATED_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        self._modeEventRegistered = false
        self._playerActivatedHookRegistered = false
        self:_stopOverlayRuntime()
        return
    end
    self:_registerPlayerActivatedHook()
    if not IsInGamepadPreferredMode() then
        self:_stopOverlayRuntime()
        return
    end
    self:_hookDiscoverSlotActions()
    self:_hookRefreshKeybindStrip()
    if self:_canUseOverlay() then
        self:_hookTooltipPrice()
        self:_hookCraftingTooltips()
        self:_hookTradingHouseTooltip()
        self:_registerContextEvents()
        self:_scheduleTooltipPriceHookRetry()
    else
        self:_stopOverlayRuntime()
    end
end

function bridge:_registerPlayerActivatedHook()
    if not self.enabled then return end
    if not self._modeEventRegistered then
        EVENT_MANAGER:RegisterForEvent(MODE_EVENT_NAMESPACE, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
            bridge:_syncRuntime()
        end)
        self._modeEventRegistered = true
    end
    if not self._playerActivatedSeen and not self._playerActivatedHookRegistered then
        EVENT_MANAGER:RegisterForEvent(PLAYER_ACTIVATED_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(PLAYER_ACTIVATED_EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
            bridge._playerActivatedSeen = true
            bridge._playerActivatedHookRegistered = false
            bridge:_syncRuntime()
        end)
        self._playerActivatedHookRegistered = true
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= MAJOR then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)
    bridge:Initialize()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoaded)
