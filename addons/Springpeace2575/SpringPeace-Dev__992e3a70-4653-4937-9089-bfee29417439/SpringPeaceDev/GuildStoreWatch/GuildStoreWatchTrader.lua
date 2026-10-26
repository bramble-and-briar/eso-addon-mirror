-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- Trader helpers for GuildStoreWatch add-on
-----------------------------------------------------------

GuildStoreWatchTrader = GuildStoreWatchTrader or {}
local GSWTrader = GuildStoreWatchTrader

GSWTrader.sv = {
    captureSearchResponses = true,
    capturePageResponses = true,
    debug = false,
}

GSWTrader.state = {
    responseRegistered = false,
}

GSWTrader.callbacks = {
    StoreCurrentSearchResults = function(items, sourceLabel, savedAt, searchText, page, traderZone, traderName, guildName) return true, false end,
    ClearRowsForTraderSearch = function(traderName, searchText) end,
    RefreshTrader = function(traderName) end,
    RefreshFull = function(traderName) end,
}

function GSWTrader.Initialize(sv, eventPrefix, StoreCurrentSearchResults, ClearRowsForTraderSearch, RefreshTrader, RefreshFull)
    GSWTrader.sv = sv

    GSWTrader.EnsureSavedVariables()
    GSWTrader.EnsureState()

    if StoreCurrentSearchResults then GSWTrader.callbacks.StoreCurrentSearchResults = StoreCurrentSearchResults end
    if ClearRowsForTraderSearch then GSWTrader.callbacks.ClearRowsForTraderSearch = ClearRowsForTraderSearch end
    if RefreshTrader then GSWTrader.callbacks.RefreshTrader = RefreshTrader end
    if RefreshFull then GSWTrader.callbacks.RefreshFull = RefreshFull end

    GSWTrader.RegisterEvents(eventPrefix)
end

function GSWTrader.EnsureSavedVariables()
    if type(GSWTrader.sv.captureSearchResponses) ~= "boolean" then GSWTrader.sv.captureSearchResponses = true end
    if type(GSWTrader.sv.capturePageResponses) ~= "boolean" then GSWTrader.sv.capturePageResponses = true end
    if type(GSWTrader.sv.debug) ~= "boolean" then GSWTrader.sv.debug = false end
end

function GSWTrader.EnsureState()
    GSWTrader.state.responseRegistered = GSWTrader.state.responseRegistered or false
end

function GSWTrader.RegisterEvents(prefix)
    if GSWTrader.state.responseRegistered then return end
    GSWTrader.state.responseRegistered = true
    EVENT_MANAGER:RegisterForEvent(prefix .. "_TradingHouse", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(...)
        GSWTrader.OnTradingHouseResponse(...)
    end)
end

local function getCurrentGuildName()
    if GetCurrentTradingHouseGuildDetails then
        local _, guildName = GetCurrentTradingHouseGuildDetails()
        return guildName or ""
    end
    return ""
end

local function getCurrentTraderName()
    local traderName = GetUnitName and GetUnitName("interact") or ""
    if traderName and traderName ~= "" then
        return traderName
    end
    return ""
end

local function getTraderZoneLabel()
    local zoneName = GetUnitZone and GetUnitZone("player") or ""
    if zoneName and zoneName ~= "" then
        return zoneName
    end
    return ""
end

local function stripEsoFormatting(text)
    if not text then return "" end

    -- remove color tags |cXXXXXX a |r
    text = text:gsub("|c%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")

    -- remove other ESO markup begining |
    text = text:gsub("|[^|]+|h", "")
    text = text:gsub("|h", "")

    return text
end

local function normalizeSearchDescriptorPart(value)
    value = tostring(value or "")
    value = stripEsoFormatting(value)
    value = value:gsub("\r\n", "|"):gsub("\n", "|"):gsub("\r", "|")
    value = value:gsub("%s+", " ")
    return zo_strtrim(value)
end

local function getCurrentSearchText()
    local descriptionParts = {}

    if TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.CreateSearchTable then
        local searchTable = TRADING_HOUSE_SEARCH:CreateSearchTable()
        if searchTable then
            if TRADING_HOUSE_SEARCH.GenerateSearchTableDescription then
                local description = normalizeSearchDescriptorPart(TRADING_HOUSE_SEARCH:GenerateSearchTableDescription(searchTable))
                if description ~= "" then
                    table.insert(descriptionParts, description)
                end
            elseif TRADING_HOUSE_SEARCH.GenerateSearchTableShortDescription then
                local shortDescription = normalizeSearchDescriptorPart(TRADING_HOUSE_SEARCH:GenerateSearchTableShortDescription(searchTable))
                if shortDescription ~= "" then
                    table.insert(descriptionParts, shortDescription)
                end
            end
        end
    end

    if #descriptionParts == 0 and GAMEPAD_TRADING_HOUSE_BROWSE and GAMEPAD_TRADING_HOUSE_BROWSE.GetNameSearchFeature then
        local nameFeature = GAMEPAD_TRADING_HOUSE_BROWSE:GetNameSearchFeature()
        if nameFeature and nameFeature.GetSearchText then
            local searchText = normalizeSearchDescriptorPart(nameFeature:GetSearchText())
            if searchText ~= "" then
                table.insert(descriptionParts, searchText)
            end
        end
    end

    if #descriptionParts > 0 then
        return table.concat(descriptionParts, "|")
    end

    return ""
end

local function getSearchResultsInfoSafe()
    if not GetTradingHouseSearchResultsInfo then
        return 0, 0, false
    end

    local numItemsOnPage, page, hasMorePages = GetTradingHouseSearchResultsInfo()
    return numItemsOnPage or 0, page or 0, hasMorePages or false
end

function GSWTrader.Debug(text)
    if GSWTrader.sv.debug then
        d(string.format("[GSW] DEBUG: %s", tostring(text)))
    end
end

function GSWTrader.StoreCurrentSearchResults(sourceLabel)
    if not GetTradingHouseSearchResultsInfo or not ZO_TradingHouse_CreateSearchResultItemData then
        GSWTrader.Debug("Trading House result helpers unavailable")
        return 0
    end

    local numItemsOnPage, page = getSearchResultsInfoSafe()
    if numItemsOnPage <= 0 then
        GSWTrader.Debug("No rows to capture from " .. tostring(sourceLabel))
        GSWTrader.callbacks.RefreshTrader(getCurrentTraderName())
        return 0
    end

    local guildName = getCurrentGuildName()
    local traderZone = getTraderZoneLabel()
    local traderName = getCurrentTraderName()
    local savedAt = GetTimeStamp()
    local searchText = getCurrentSearchText()
    if searchText == "" then
        GSWTrader.Debug("Current search text is unavailable")
    end
    if sourceLabel == "search" or page == 0 then
        -- TODO: check behavior when return to prev page and it is first page
        GSWTrader.callbacks.ClearRowsForTraderSearch(traderName, searchText)
    end

    local items = {}
    for i = 1, numItemsOnPage do
        local itemData = ZO_TradingHouse_CreateSearchResultItemData(i)

        if itemData then
            table.insert(items, itemData)
        end
    end

    GSWTrader.callbacks.StoreCurrentSearchResults(items, sourceLabel, savedAt, searchText, page, traderZone, traderName, guildName)

    GSWTrader.callbacks.RefreshFull()
end

function GSWTrader.IsSearchResponse(responseType)
    return responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING
end

function GSWTrader.IsNextPageResponse(responseType)
    if not TRADING_HOUSE_RESULT_NEXT_PAGE_PENDING then
        GSWTrader.Debug("TRADING_HOUSE_RESULT_NEXT_PAGE_PENDING is unavailable")
    end
    return responseType == TRADING_HOUSE_RESULT_NEXT_PAGE_PENDING
end

function GSWTrader.OnTradingHouseResponse(eventCode, responseType, result)
    if result ~= TRADING_HOUSE_RESULT_SUCCESS then return end

    local shouldCapture = false
    local sourceLabel = nil

    if GSWTrader.sv.captureSearchResponses and GSWTrader.IsSearchResponse(responseType) then
        shouldCapture = true
        sourceLabel = "search"
    elseif GSWTrader.sv.capturePageResponses and GSWTrader.IsNextPageResponse(responseType) then
        shouldCapture = true
        sourceLabel = "nextPage"
    end

    if not shouldCapture then
        GSWTrader.Debug("Will not be captured because of responseType " .. tostring(responseType))
        return
    end

    zo_callLater(function()
        GSWTrader.StoreCurrentSearchResults(sourceLabel)
    end, 50)
end
