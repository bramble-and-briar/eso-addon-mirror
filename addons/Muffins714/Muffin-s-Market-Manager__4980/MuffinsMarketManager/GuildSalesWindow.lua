-- Create a local shortcut for global
local MMM = MuffinsMarketManager

----------------------------------------------------------------------
-- LibHistoire / guild history
----------------------------------------------------------------------
MMM.LibHistoireCache = MMM.LibHistoireCache or {} -- guildId -> event list
MMM.guildCaughtUp = MMM.guildCaughtUp or {}       -- guildId -> true once initial catch up finished

-- Copies the fields used out of a LibHistoire event into a plain table
local function ExtractTraderEventFields(event)
    local info = event:GetEventInfo()
    return {
        eventId           = info.eventId,
        timestampS        = info.timestampS,
        isRedacted        = info.isRedacted,
        eventType         = info.eventType,
        sellerDisplayName = info.sellerDisplayName,
        buyerDisplayName  = info.buyerDisplayName,
        itemLink          = info.itemLink,
        quantity          = info.quantity,
        price             = info.price,
        tax               = info.tax,
    }
end

-- Caches this week's trader events for one guild into MMM.LibHistoireCache
local function StartLibHistoireProcessorForGuild(guildId, weekStart)
    local processor = LibHistoire:CreateGuildHistoryProcessor(
        guildId,
        GUILD_HISTORY_EVENT_CATEGORY_TRADER,
        "MuffinsMarketManager"
    )
    if not processor then return end

    MMM.LibHistoireCache[guildId] = MMM.LibHistoireCache[guildId] or {}

    processor:SetAfterEventTime(weekStart - 1)
    processor:SetStopOnLastCachedEvent(false)

    processor:SetNextEventCallback(function(event)
        local fields = ExtractTraderEventFields(event)
        table.insert(MMM.LibHistoireCache[guildId], fields)
        MMM.RefreshGuildSalesWindow()
        MMM.NotifyDataReady()
    end)

    processor:Start()
end

-- Ready if linked this session, or already up to date with events cached
local function IsGuildReady(guildId)
    if MMM.guildCaughtUp[guildId] then return true end
    local cached = MMM.LibHistoireCache[guildId]
    return DoesGuildHistoryEventCategoryHaveUpToDateEvents(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER)
        and cached ~= nil and #cached > 0
end

-- True once every shown guild is caught up, skips guilds with no trader or turned off in settings
local function AreAllGuildsCaughtUp()
    local enabledByGuild = MMM.GetSettings().guildRowEnabled or {}
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        local isShown = guildId and GetGuildOwnedKioskInfo(guildId) and enabledByGuild[guildId] ~= false
        if isShown and not IsGuildReady(guildId) then
            return false
        end
    end

    return true
end

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
MMM.dataReadyNotified = false
local DATA_READY_DEBOUNCE_MS = 1500
local dataReadyDebounceHandle = "MuffinsMarketManager_DataReadyDebounce"

-- Builds center screen label used by ShowAlert
function MMM.CreateUI()
    local wm = WINDOW_MANAGER
    local frame = wm:CreateTopLevelWindow("MuffinsMarketManager_AlertFrame")
    frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    frame:SetHidden(true)

    local label = wm:CreateControl("$(parent)Text", frame, CT_LABEL)
    label:SetAnchor(CENTER, frame, CENTER, 0, -100)
    label:SetFont("ZoFontGamepad54")
    label:SetColor(unpack(MMM.DEFAULT_COLORS.white))
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    MMM.AlertLabel = label
    MMM.AlertFrame = frame
end

-- Settings for alerts (center, standard alert, print to chat)
function MMM.ShowAlert(text, sound, printToChat, chatLines)
    local settings = MMM.GetSettings()

    if settings.alertStyleDataReady == "center" then
        MMM.AlertLabel:SetText(text)
        MMM.AlertFrame:SetHidden(false)
        PlaySound(sound)
        zo_callLater(function() MMM.AlertFrame:SetHidden(true) end, 4000)
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, text)
    end

    if printToChat then
        for _, line in ipairs(chatLines or { text }) do
            MMM.MMMPrint(line)
        end
    end
end

-- Shows the data ready alert once all guilds are caught up, debounced so it waits until events stop arriving
function MMM.NotifyDataReady()
    local settings = MMM.GetSettings()

    if not settings.notifyDataReady then return end
    if MMM.dataReadyNotified then return end
    if not AreAllGuildsCaughtUp() then return end

    EVENT_MANAGER:UnregisterForUpdate(dataReadyDebounceHandle)
    EVENT_MANAGER:RegisterForUpdate(dataReadyDebounceHandle, DATA_READY_DEBOUNCE_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(dataReadyDebounceHandle)
        if MMM.dataReadyNotified then return end
        MMM.dataReadyNotified = true
        MMM.ShowAlert(GetString(MMM_NOTIFY_DATA_UI), SOUNDS.NEW_NOTIFICATION, true)
        MMM.RefreshGuildSalesWindow()
    end)
end

----------------------------------------------------------------------
-- LibHistoire startup
----------------------------------------------------------------------
-- Called when LibHistoire links a guild category to present events
local function OnCategoryLinked(guildId, category)
    if category ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then return end

    MMM.guildCaughtUp[guildId] = true
    MMM.NotifyDataReady()
    MMM.RefreshGuildSalesWindow()
end

-- Starts processors for all guilds once LibHistoire is ready
function MMM.StartLibHistoire()
    -- if not LibHistoire then return end
    LibHistoire:RegisterCallback(
        LibHistoire.callback.CATEGORY_LINKED,
        OnCategoryLinked
    )

    LibHistoire:OnReady(function()
        local weekStart = MMM.GetCurrentWeekStartTimestamp()

        for guildIndex = 1, GetNumGuilds() do
            local guildId = GetGuildId(guildIndex)
            if guildId then
                StartLibHistoireProcessorForGuild(guildId, weekStart)
            end
        end
    end)
end

----------------------------------------------------------------------
-- Weekly reset
----------------------------------------------------------------------
local RESET_WEEKDAY = 3
local RESET_HOUR_UTC = 19

function MMM.GetCurrentWeekStartTimestamp()
    local now = GetTimeStamp()
    local nowTable = os.date("!*t", now)
    -- 0 on Tuesday, 6 on Monday
    local daysSinceReset = (nowTable.wday - RESET_WEEKDAY) % 7
    if daysSinceReset == 0 and nowTable.hour < RESET_HOUR_UTC then
        daysSinceReset = 7
    end
    local todayMidnightUTC = now - (nowTable.hour * 3600 + nowTable.min * 60 + nowTable.sec)
    return todayMidnightUTC - (daysSinceReset * 86400) + (RESET_HOUR_UTC * 3600)
end

----------------------------------------------------------------------
-- Weekly sales totals
----------------------------------------------------------------------
-- Listed counts are account wide
local function GetListingData()
    return LibMuffinsMarketManagerData.SavedVars
end

-- Adds up weekly sales, taxes and items sold, plus guild sales
-- We use DecorateDisplayName before comparing against GetDisplayName() or it always fails!
function MMM.GetWeeklySalesForGuild(guildId, kioskName)
    local settings = MMM.GetSettings()
    local weekStart = MMM.GetCurrentWeekStartTimestamp()
    local myDisplayName = GetDisplayName()

    local mySales = 0
    local myTaxes = 0
    local myItemCount = 0
    local mySoldListings = 0 -- one per sale event, a stack counts once like a listing does
    local guildTotalSales = 0
    -- Time of the last listing count capture, older saved data was a table so it is ignored
    local listingData = GetListingData()
    local baselines = listingData.itemsListedBaseline
    local captureTime = type(baselines) == "table" and type(baselines[guildId]) == "number" and baselines[guildId] or nil
    local soldAfterCapture = 0

    local libHistoireEvents = MMM.LibHistoireCache and MMM.LibHistoireCache[guildId]
    -- Use the LibHistoire cache when it has events, it holds the full week
    if libHistoireEvents and #libHistoireEvents > 0 then
        for _, eventData in ipairs(libHistoireEvents) do
            local isSoldType = eventData.eventType == GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
            local isInWeek = eventData.timestampS and eventData.timestampS >= weekStart
            local passes = not eventData.isRedacted and isSoldType and isInWeek

            if passes then
                guildTotalSales = guildTotalSales + (eventData.price or 0)
                -- sellerDisplayName comes back undecorated, decorate before comparing
                if DecorateDisplayName(eventData.sellerDisplayName) == myDisplayName then
                    mySales = mySales + (eventData.price or 0)
                    myItemCount = myItemCount + (eventData.quantity or 1)
                    myTaxes = myTaxes + (eventData.tax or 0)
                    mySoldListings = mySoldListings + 1
                    -- count sales made after the last listing capture so they can be subtracted from the listed count
                    if captureTime and eventData.timestampS > captureTime then soldAfterCapture = soldAfterCapture + 1 end
                end
            end
        end
    else
        -- Used when LibHistoire has not finished yet
        local category = GUILD_HISTORY_EVENT_CATEGORY_TRADER

        local numEvents = GetNumGuildHistoryEvents(guildId, category)

        for eventIndex = 1, numEvents do
            local eventId, timestampS, isRedacted, eventType, sellerDisplayName, buyerDisplayName, itemLink, quantity, price, tax =
                GetGuildHistoryTraderEventInfo(guildId, eventIndex)

            if not eventId or eventId == 0 then break end
            if timestampS < weekStart then break end -- newest first, stop at old data

            if not isRedacted and eventType == GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
                guildTotalSales = guildTotalSales + (price or 0)
                if DecorateDisplayName(sellerDisplayName) == myDisplayName then
                    mySales = mySales + (price or 0)
                    myItemCount = myItemCount + (quantity or 1)
                    myTaxes = myTaxes + (tax or 0)
                    mySoldListings = mySoldListings + 1
                    if captureTime and timestampS > captureTime then soldAfterCapture = soldAfterCapture + 1 end
                end
            end
        end
    end

    -- Each guild gets its own weekly goal
    local goldGoal = 0
    if settings.weeklySalesGoalEnabled and settings.weeklySalesGoalsByGuild then
        goldGoal = settings.weeklySalesGoalsByGuild[guildId] or 0
    end

    -- Items currently listed, count saved at last visit minus sales made since then
    local itemListed = nil
    local counts = listingData.currentListingCountByGuild
    if settings.myListingsEnabled and type(counts) == "table" then
        local saved = counts[guildId]
        if saved then
            itemListed = math.max(0, saved - soldAfterCapture)
        end
    end
    -- Everything the window needs for this guild's row
    return {
        guildId = guildId,
        guildName = GetGuildName(guildId),
        kioskName = kioskName,
        mySales = mySales,
        myTaxes = myTaxes,
        myItemCount = myItemCount,
        guildTotalSales = guildTotalSales,
        myGoal = goldGoal,
        myListings = itemListed,
        mySoldListings = mySoldListings,
    }
end

-- Returns sales data for every guild with a trader kiosk that isn't turned off in settings
function MMM.GetWeeklySalesAllGuilds()
    local settings = MMM.GetSettings()
    local enabledByGuild = settings.guildRowEnabled or {}
    local results = {}
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        if guildId then
            local kioskName = GetGuildOwnedKioskInfo(guildId)
            -- Defaults to shown unless the player turned this guild off
            local isEnabled = enabledByGuild[guildId]
            if isEnabled == nil then isEnabled = true end
            if kioskName and isEnabled then
                table.insert(results, MMM.GetWeeklySalesForGuild(guildId, kioskName))
            end
        end
    end
    return results
end

-- Saves how many items are listed in the selected guild store
function MMM.CaptureListingCount()
    -- No HasTradingHouseListings check needed since this works on the sell tab
    local guildId = GetSelectedTradingHouseGuildId()
    if not guildId or guildId == 0 then return end

    local listingData = GetListingData()
    -- Only the first return is used, the second is max slots
    local currentListings = GetTradingHouseListingCounts()
    -- Tables are nil on first run
    if type(listingData.currentListingCountByGuild) ~= "table" then listingData.currentListingCountByGuild = {} end
    if type(listingData.itemsListedBaseline) ~= "table" then listingData.itemsListedBaseline = {} end
    listingData.currentListingCountByGuild[guildId] = currentListings
    -- Sales after this time get subtracted from the count
    listingData.itemsListedBaseline[guildId] = GetTimeStamp()
    -- d("MMM DEBUG: CaptureListingCount guild=" .. GetGuildName(guildId) .. " listed=" .. tostring(currentListings))
    MMM.RefreshGuildSalesWindow()
end

local listingHooksInstalled = false
-- Recaptures the listing count when listings change or the guild switches
function MMM.InstallListingCountHooks()
    if listingHooksInstalled then return end
    listingHooksInstalled = true

    -- listings loaded or a sale was cancelled or a new listing was posted
    TRADING_HOUSE_SEARCH:RegisterCallback("OnResponseReceived", function(responseType, result)
        if result ~= TRADING_HOUSE_RESULT_SUCCESS then return end
        if responseType == TRADING_HOUSE_RESULT_LISTINGS_PENDING
            or responseType == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING
            or responseType == TRADING_HOUSE_RESULT_POST_PENDING then
            -- let the game update its listing data first
            zo_callLater(MMM.CaptureListingCount, 250)
        end
    end)

    TRADING_HOUSE_SEARCH:RegisterCallback("OnSelectedGuildChanged", function()
        zo_callLater(MMM.CaptureListingCount, 250)
    end)
end

-------------------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------------------
local SIZE                    = {
    sidePad   = 30,
    columnPad = 20,
    rowHeight = 70,
    rowGap    = 10,

    -- column widths
    guild     = 260,
    items     = 90,
    listed    = 50,
    profit    = 110,
    taxes     = 100,
    goal      = 100,
}
local TITLE_AND_HEADER_HEIGHT = 110
local BOTTOM_PADDING          = 40
-- FOR V2
-- local FOOTER_HEIGHT        = 50
local MAX_GUILD_ROWS          = 5

-- Set once in OnInitialized
local guildSalesWindowControl = nil
local isGuildSalesWindowShown = false

-------------------------------------------------------------------------------------------
-- Text formatting
-------------------------------------------------------------------------------------------
-- 12345 becomes 12,345g
local function FormatGold(amount)
    return zo_strformat("<<1>>g", ZO_CommaDelimitNumber(amount or 0))
end

-- 1.0k becomes 1k
local function TrimTrailingZero(numStr)
    return (numStr:gsub("%.0$", ""))
end

-- 1500 becomes 1.5k
local function AbbreviateGold(amount)
    amount = amount or 0
    local sign = amount < 0 and "-" or ""
    local absAmount = amount < 0 and -amount or amount
    if absAmount >= 1000000 then
        return sign .. TrimTrailingZero(string.format("%.1f", absAmount / 1000000)) .. "mil"
    elseif absAmount >= 1000 then
        return sign .. TrimTrailingZero(string.format("%.1f", absAmount / 1000)) .. "k"
    else
        return sign .. tostring(absAmount)
    end
end

local function FormatGoal(amount)
    if MMM.GetSettings().useAbbreviatedGoalFormat then
        return AbbreviateGold(amount)
    end
    return FormatGold(amount)
end

----------------------------------------------------------------------
-- Column colors (base colors and icons are in MuffinsMarketManager.lua)
----------------------------------------------------------------------
-- Used when custom colors are on but none picked yet
local DEFAULT_COLUMN_COLORS = {
    profitColor = MMM.DEFAULT_COLORS.limeGreen,
    taxesColor  = MMM.DEFAULT_COLORS.red,
    goalColor   = MMM.DEFAULT_COLORS.softGold,
}

-- White unless Use Custom Colors is on
local function GetColumnColor(colorKey)
    local settings = MMM.GetSettings()
    if not settings.useCustomColors then
        return MMM.DEFAULT_COLORS.white
    end

    local saved = settings[colorKey]
    if saved and saved.r then
        return { saved.r, saved.g, saved.b, saved.a or 1 }
    end
    return DEFAULT_COLUMN_COLORS[colorKey] or MMM.DEFAULT_COLORS.white
end
-------------------------------------------------------------------------------------------
-- Columns
-------------------------------------------------------------------------------------------
local COLUMNS = {
    {
        row        = "GuildName",
        header     = "ColGuild",
        width      = SIZE.guild,
        headerText = GetString(SI_TRADING_HOUSE_GUILD_HEADER),
        getText    = function(data) return data.guildName or "" end,
    },
    {
        row        = "Items",
        header     = "ColItemsSold",
        width      = SIZE.items,
        headerText = GetString(SI_GAMEPAD_FENCE_SELL_LIMIT),
        getText    = function(data) return tostring(data.myItemCount or 0) end,
    },
    {
        row        = "NumListed",
        header     = "ColItemsListed",
        width      = SIZE.listed,
        headerText = GetString(MMM_ITEMS_LISTED),
        getText    = function(data) return data.myListings and tostring(data.myListings) or "-" end,
        isShown    = function() return MMM.GetSettings().myListingsEnabled end,
    },
    {
        row        = "Profit",
        header     = "ColProfit",
        width      = SIZE.profit,
        headerText = MMM.goldIcon .. " " .. GetString(SI_TRADING_HOUSE_POSTING_PROFIT),
        getText    = function(data) return FormatGold(data.mySales) end,
        getColor   = function() return GetColumnColor("profitColor") end,
    },
    {
        row        = "Taxes",
        header     = "ColTax",
        width      = SIZE.taxes,
        headerText = MMM.goldIcon .. " " .. GetString(MMM_TAXES_COLLECTED),
        getText    = function(data) return FormatGold(data.myTaxes) end,
        getColor   = function() return GetColumnColor("taxesColor") end,
    },
    {
        row        = "Goal",
        header     = "ColGoal",
        width      = SIZE.goal,
        headerText = MMM.goldIcon .. " " .. GetString(MMM_SELLER_GOAL),
        getText    = function(data) return FormatGoal(data.myGoal) end,
        getColor   = function(data)
            local goalReached = (data.mySales or 0) >= (data.myGoal or 0)
            return goalReached and GetColumnColor("goalColor") or MMM.DEFAULT_COLORS.disableGray
        end,
        isShown    = function() return MMM.GetSettings().weeklySalesGoalEnabled end,
    },
}

-- No isShown means always shown
local function IsColumnShown(column)
    return column.isShown == nil or column.isShown()
end

-- XML sets the column order and this sets the sizes
local function SetColumnShown(label, column, shown)
    label:SetHidden(not shown)
    label:SetWidth(shown and column.width or 0)

    -- first column starts at the edge and hidden columns take no space
    local offsetX
    if column == COLUMNS[1] then
        offsetX = SIZE.sidePad
    else
        offsetX = shown and SIZE.columnPad or 0
    end

    -- keep the xml anchor target and only change the offset
    local _, point, relativeTo, relativePoint = label:GetAnchor(0)
    relativeTo = relativeTo or label:GetParent()
    label:ClearAnchors()
    label:SetAnchor(point, relativeTo, relativePoint, offsetX, 0)
end

-- side pads + shown columns + gaps between them
local function GetWindowWidth()
    local width = SIZE.sidePad * 2
    for index, column in ipairs(COLUMNS) do
        if IsColumnShown(column) then
            width = width + column.width
            if index > 1 then
                width = width + SIZE.columnPad
            end
        end
    end
    return width
end

-------------------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------------------
local function RefreshGuildSalesInfo()
    if not guildSalesWindowControl then return end

    local settings = MMM.GetSettings()
    local headerContainer = guildSalesWindowControl:GetNamedChild("HeaderContainer")

    -- Headers
    for _, column in ipairs(COLUMNS) do
        local headerLabel = headerContainer:GetNamedChild(column.header)
        SetColumnShown(headerLabel, column, IsColumnShown(column))
    end

    -- one row per guild that owns a trader
    local salesData = MMM.GetWeeklySalesAllGuilds()
    local visibleRowCount = 0

    for rowIndex = 1, MAX_GUILD_ROWS do
        local row = guildSalesWindowControl:GetNamedChild("Row" .. rowIndex)
        local guildData = salesData[rowIndex]

        if guildData then
            for _, column in ipairs(COLUMNS) do
                local label = row:GetNamedChild(column.row)
                local shown = IsColumnShown(column)
                SetColumnShown(label, column, shown)

                if shown then
                    label:SetText(column.getText(guildData))
                    local color = column.getColor and column.getColor(guildData) or MMM.DEFAULT_COLORS.white
                    label:SetColor(unpack(color))
                end
            end
            -- Second line under the guild name
            row:GetNamedChild("KioskName"):SetText(MMM.IconsFor.TRADER_ICON .. " " .. (guildData.kioskName or ""))
            -- Second line under the goal, how much is left to reach it
            local goalMathLabel = row:GetNamedChild("GoalMath")
            local remaining = (guildData.myGoal or 0) - (guildData.mySales or 0)
            if settings.weeklySalesGoalEnabled and remaining > 0 then
                goalMathLabel:SetText(MMM.IconsFor.GOAL_MET_ICON .. " " .. FormatGoal(remaining))
                goalMathLabel:SetHidden(false)
            else
                goalMathLabel:SetHidden(true)
            end

            row:SetHidden(false)
            visibleRowCount = visibleRowCount + 1
        else
            row:SetHidden(true)
        end
    end

    -- Always keep room for at least one row
    local rowCount = math.max(visibleRowCount, 1)
    local rowsHeight = (rowCount * SIZE.rowHeight) + ((rowCount - 1) * SIZE.rowGap)

    local windowHeight = TITLE_AND_HEADER_HEIGHT + rowsHeight + BOTTOM_PADDING
    -- Title, headers and rows are anchored to both sides, so they stretch with the window
    guildSalesWindowControl:SetDimensions(GetWindowWidth(), windowHeight)
end

-------------------------------------------------------------------------------------------
-- Setup, called once from the XML OnInitialized
-------------------------------------------------------------------------------------------
function MMM.GuildSalesWindowGamepadOnInitialized(control)
    guildSalesWindowControl = control
    control:GetNamedChild("Title"):SetText(GetString(MMM_TITLE_HEADER))
    -- Header text never changes, so its set once here
    local headerContainer = control:GetNamedChild("HeaderContainer")
    for _, column in ipairs(COLUMNS) do
        headerContainer:GetNamedChild(column.header):SetText(column.headerText)
    end

    -- Row height and the gap under every row except the first
    local previousRow = nil
    for rowIndex = 1, MAX_GUILD_ROWS do
        local row = control:GetNamedChild("Row" .. rowIndex)
        row:SetHeight(SIZE.rowHeight)
        if previousRow then
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT, previousRow, BOTTOMLEFT, 0, SIZE.rowGap)
            row:SetAnchor(TOPRIGHT, previousRow, BOTTOMRIGHT, 0, SIZE.rowGap)
        end
        previousRow = row
    end
    --[[
    zo_callLater(function()
        MMM.SetupDragHandlers()
        MMM.RestorePosition()
        MMM.UpdateVisibility()
    end, 0)
    ]]
end

----------------------------------------------------------------------
-- Show / hide / refresh helpers
----------------------------------------------------------------------
function MMM.SetupDragHandlers()
    if not guildSalesWindowControl then return end

    guildSalesWindowControl:SetHandler("OnMoveStop", function(self)
        local settings = MMM.GetSettings()
        settings.left = self:GetLeft()
        settings.top = self:GetTop()
    end)
end

function MMM.RestorePosition()
    if not guildSalesWindowControl then return end
    local settings = MMM.GetSettings()

    if settings.left == nil or settings.top == nil then return end

    guildSalesWindowControl:ClearAnchors()
    guildSalesWindowControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.left, settings.top)
end

function MMM.UpdateVisibility()
    if not guildSalesWindowControl then return end

    local settings = MMM.GetSettings()
    local isUnlocked = settings.unlocked

    guildSalesWindowControl:SetMovable(isUnlocked)
    guildSalesWindowControl:SetMouseEnabled(isUnlocked)
end

function MMM.ShowGuildSalesWindow()
    if not guildSalesWindowControl then return end
    RefreshGuildSalesInfo()
    guildSalesWindowControl:SetHidden(false)
    isGuildSalesWindowShown = true
end

function MMM.HideGuildSalesWindow()
    if not guildSalesWindowControl then return end
    guildSalesWindowControl:SetHidden(true)
    isGuildSalesWindowShown = false
end

function MMM.ToggleGuildSalesWindow()
    if isGuildSalesWindowShown then
        MMM.HideGuildSalesWindow()
    else
        MMM.ShowGuildSalesWindow()
    end
end

-- Refreshes only if currently shown
function MMM.RefreshGuildSalesWindow()
    if isGuildSalesWindowShown then
        RefreshGuildSalesInfo()
    end
end

----------------------------------------------------------------------
-- Trading house hooks
----------------------------------------------------------------------
--[[
local function HookShowHide(tradingHouseListInstance)
    local originalShow = tradingHouseListInstance.Show
    tradingHouseListInstance.Show = function(self, ...)
        originalShow(self, ...)
        -- Save the listing count as soon as the sell tab opens, after a short wait so the game updates first
        if self == GAMEPAD_TRADING_HOUSE_SELL then
            zo_callLater(MMM.CaptureListingCount, 250)
        end
        local settings = MMM.GetSettings()
        if settings.guildSalesAutoOpen then
            MMM.ShowGuildSalesWindow()
        end
    end

    local originalHide = tradingHouseListInstance.Hide
    tradingHouseListInstance.Hide = function(self, ...)
        originalHide(self, ...)
        MMM.HideGuildSalesWindow()
    end
end

local tradingHouseTabsHooked = false
local function HookTradingHouseTabs()
    if tradingHouseTabsHooked then return end
    tradingHouseTabsHooked = true
    HookShowHide(GAMEPAD_TRADING_HOUSE_SELL)
    HookShowHide(GAMEPAD_TRADING_HOUSE_LISTINGS)
end


-- Refreshes after a listing is confirmed
local originalShowListItemConfirmationForSales = ZO_GamepadTradingHouse_CreateListing.ShowListItemConfirmation
ZO_GamepadTradingHouse_CreateListing.ShowListItemConfirmation = function(self)
    originalShowListItemConfirmationForSales(self)
    MMM.RefreshGuildSalesWindow()
end
]]
local function HookShowHide(tradingHouseListInstance)
    -- Runs after the tab shows
    SecurePostHook(tradingHouseListInstance, "Show", function(self)
        -- Save the listing count as soon as the sell tab opens, after a short wait so the game updates first
        if self == GAMEPAD_TRADING_HOUSE_SELL then
            zo_callLater(MMM.CaptureListingCount, 250)
        end
        if MMM.GetSettings().guildSalesAutoOpen then
            MMM.ShowGuildSalesWindow()
        end
    end)

    -- Runs after the tab hides
    SecurePostHook(tradingHouseListInstance, "Hide", function()
        MMM.HideGuildSalesWindow()
    end)
end

local tradingHouseTabsHooked = false
local function HookTradingHouseTabs()
    if tradingHouseTabsHooked then return end
    tradingHouseTabsHooked = true
    HookShowHide(GAMEPAD_TRADING_HOUSE_SELL)
    HookShowHide(GAMEPAD_TRADING_HOUSE_LISTINGS)
end


-- Refreshes after a listing is confirmed
SecurePostHook(ZO_GamepadTradingHouse_CreateListing, "ShowListItemConfirmation", function()
    MMM.RefreshGuildSalesWindow()
end)

-- TEMP debugs
--[[
SLASH_COMMANDS["/mmmready"] = function()
    local settings = MMM.GetSettings()
    d("notifyDataReady setting: " .. tostring(settings.notifyDataReady))
    d("already notified: " .. tostring(MMM.dataReadyNotified))
    d("all guilds caught up: " .. tostring(AreAllGuildsCaughtUp()))
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        d(string.format("%s (id %d): caught up = %s",
            GetGuildName(guildId), guildId, tostring(MMM.guildCaughtUp[guildId])))
        local category = GUILD_HISTORY_EVENT_CATEGORY_TRADER
        d(string.format("   kiosk=%s  gameUpToDate=%s  gameEvents=%d  ranges=%d  mmmCached=%d",
            tostring(GetGuildOwnedKioskInfo(guildId)),
            tostring(DoesGuildHistoryEventCategoryHaveUpToDateEvents(guildId, category)),
            GetNumGuildHistoryEvents(guildId, category),
            GetNumGuildHistoryEventRanges(guildId, category),
            #(MMM.LibHistoireCache[guildId] or {})))
    end
end

SLASH_COMMANDS["/mmmalert"] = function()
    MMM.ShowAlert(GetString(MMM_NOTIFY_DATA_UI), SOUNDS.NEW_NOTIFICATION, true)
end

SLASH_COMMANDS["/mmmweek"] = function()
    d(MMM.GetCurrentWeekStartTimestamp())
end

SLASH_COMMANDS["/mmmcalc"] = function()
    local listed = 0
    for _ in pairs(LibMuffinsMarketManagerData.SavedVars.lastListedPrices or {}) do listed = listed + 1 end
    d("listed prices saved: " .. listed)
end
]]

----------------------------------------------------------------------
-- Addon load
----------------------------------------------------------------------
function MMM.GSW_Initialize()
    -- Tabs are created the first time the guild store opens, so hook them on first show
    TRADING_HOUSE_GAMEPAD_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            HookTradingHouseTabs()
        end
    end)
    MMM.InstallListingCountHooks()
end
