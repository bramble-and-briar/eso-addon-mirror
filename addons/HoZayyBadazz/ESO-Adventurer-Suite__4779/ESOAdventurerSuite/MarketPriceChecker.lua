-- ESO Adventurer Suite
-- Market price checker + located guild-trader travel helper.
-- Uses installed ESO-Hub/TTC price data, never performs network I/O from ESO.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.MarketPriceChecker = EPC.MarketPriceChecker or {}
local M = EPC.MarketPriceChecker

EPC.defaults.marketPriceCheckerEnabled029683 = true
EPC.defaults.marketPriceTooltipEnabled029683 = true
EPC.defaults.marketPriceTravelEnabled029683 = true
EPC.defaults.marketPriceSource029683 = "FRESHEST"
EPC.defaults.marketPriceMaxDealAgeHours029683 = 24
EPC.defaults.marketPriceUseTTCLocations029683 = true

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_MarketPriceChecker029683"
local GOLD = "|cFFD700"
local WHITE = "|cFFFFFF"
local GREY = "|cA0A0A0"
local GREEN = "|c66FF66"
local YELLOW = "|cFFFF66"
local ORANGE = "|cFFAA55"
local RED = "|cFF6666"
local CYAN = "|c66CCFF"
local RESET = "|r"

-- Kiosk ids and friendly locations are derived from factual trader-location
-- observations in the user-supplied TTC/ESO-Hub updater reference. The updater
-- itself is not bundled or executed by ESO Adventurer Suite. The exact guild/listing
-- still comes from a live/local listing record; aggregate price tables do not name
-- the guild trader that owns the global minimum.
local KIOSK_LOCATIONS = {
    [0] = { label = "Belkarth", zone = "Craglorn" },
    [1] = { label = "Belkarth Outlaws Refuge", zone = "Craglorn" },
    [2] = { label = "The Hollow City", zone = "Coldharbour" },
    [3] = { label = "Haj Uxith Wayshrine", zone = "Coldharbour" },
    [4] = { label = "Court of Contempt Wayshrine", zone = "Coldharbour" },
    [5] = { label = "Rawl'kha", zone = "Reaper's March" },
    [6] = { label = "Rawl'kha Outlaws Refuge", zone = "Reaper's March" },
    [7] = { label = "Vinedusk Wayshrine", zone = "Reaper's March" },
    [8] = { label = "Dune", zone = "Reaper's March" },
    [9] = { label = "Baandari Trading Post", zone = "Malabal Tor" },
    [10] = { label = "Dra'bul Wayshrine", zone = "Malabal Tor" },
    [11] = { label = "Valeguard Wayshrine", zone = "Malabal Tor" },
    [12] = { label = "Velyn Harbor Outlaws Refuge", zone = "Malabal Tor" },
    [13] = { label = "Marbruk", zone = "Greenshade" },
    [14] = { label = "Marbruk Outlaws Refuge", zone = "Greenshade" },
    [15] = { label = "Verrant Morass Wayshrine", zone = "Greenshade" },
    [16] = { label = "Greenheart Wayshrine", zone = "Greenshade" },
    [17] = { label = "Elden Root", zone = "Grahtwood" },
    [18] = { label = "Elden Root Outlaws Refuge", zone = "Grahtwood" },
    [19] = { label = "Cormount Wayshrine", zone = "Grahtwood" },
    [20] = { label = "Southpoint Wayshrine", zone = "Grahtwood" },
    [21] = { label = "Skywatch", zone = "Auridon" },
    [22] = { label = "Firsthold Wayshrine", zone = "Auridon" },
    [23] = { label = "Vulkhel Guard", zone = "Auridon" },
    [24] = { label = "Vulkhel Guard Outlaws Refuge", zone = "Auridon" },
    [25] = { label = "Mistral", zone = "Khenarthi's Roost" },
    [26] = { label = "Evermore", zone = "Bangkorai" },
    [27] = { label = "Evermore Outlaws Refuge", zone = "Bangkorai" },
    [28] = { label = "Bangkorai Pass Wayshrine", zone = "Bangkorai" },
    [29] = { label = "Hallin's Stand", zone = "Bangkorai" },
    [30] = { label = "Sentinel", zone = "Alik'r Desert" },
    [31] = { label = "Sentinel Outlaws Refuge", zone = "Alik'r Desert" },
    [32] = { label = "Morwha's Bounty Wayshrine", zone = "Alik'r Desert" },
    [33] = { label = "Bergama Wayshrine", zone = "Alik'r Desert" },
    [34] = { label = "Shornhelm", zone = "Rivenspire" },
    [35] = { label = "Shornhelm Outlaws Refuge", zone = "Rivenspire" },
    [36] = { label = "Hoarfrost Downs", zone = "Rivenspire" },
    [37] = { label = "Oldgate Wayshrine", zone = "Rivenspire" },
    [38] = { label = "Wayrest", zone = "Stormhaven" },
    [39] = { label = "Wayrest Outlaws Refuge", zone = "Stormhaven" },
    [40] = { label = "Firebrand Keep Wayshrine", zone = "Stormhaven" },
    [41] = { label = "Koeglin Village", zone = "Stormhaven" },
    [42] = { label = "Daggerfall", zone = "Glenumbra" },
    [43] = { label = "Daggerfall Outlaws Refuge", zone = "Glenumbra" },
    [44] = { label = "Lion Guard Redoubt Wayshrine", zone = "Glenumbra" },
    [45] = { label = "Wyrd Tree Wayshrine", zone = "Glenumbra" },
    [46] = { label = "Stonetooth", zone = "Betnikh" },
    [47] = { label = "Port Hunding", zone = "Stros M'Kai" },
    [48] = { label = "Riften", zone = "The Rift" },
    [49] = { label = "Riften Outlaws Refuge", zone = "The Rift" },
    [50] = { label = "Nimalten", zone = "The Rift" },
    [51] = { label = "Fallowstone Hall", zone = "The Rift" },
    [52] = { label = "Windhelm", zone = "Eastmarch" },
    [53] = { label = "Windhelm Outlaws Refuge", zone = "Eastmarch" },
    [54] = { label = "Voljar Meadery Wayshrine", zone = "Eastmarch" },
    [55] = { label = "Fort Amol", zone = "Eastmarch" },
    [56] = { label = "Stormhold", zone = "Shadowfen" },
    [57] = { label = "Stormhold Outlaws Refuge", zone = "Shadowfen" },
    [58] = { label = "Venomous Fens Wayshrine", zone = "Shadowfen" },
    [59] = { label = "Hissmir Wayshrine", zone = "Shadowfen" },
    [60] = { label = "Mournhold", zone = "Deshaan" },
    [61] = { label = "Mournhold Outlaws Refuge", zone = "Deshaan" },
    [62] = { label = "Tal'Deic Grounds Wayshrine", zone = "Deshaan" },
    [63] = { label = "Muth Gnaar Hills Wayshrine", zone = "Deshaan" },
    [64] = { label = "Ebonheart", zone = "Stonefalls" },
    [65] = { label = "Kragenmoor", zone = "Stonefalls" },
    [66] = { label = "Davon's Watch", zone = "Stonefalls" },
    [67] = { label = "Davon's Watch Outlaws Refuge", zone = "Stonefalls" },
    [68] = { label = "Dhalmora", zone = "Bal Foyen" },
    [69] = { label = "Bleakrock Wayshrine", zone = "Bleakrock Isle" },
    [70] = { label = "Orsinium", zone = "Wrothgar" },
    [71] = { label = "Orsinium Outlaws Refuge", zone = "Wrothgar" },
    [72] = { label = "Morkul Stronghold", zone = "Wrothgar" },
    [73] = { label = "Thieves Den", zone = "Hew's Bane" },
    [74] = { label = "Abah's Landing", zone = "Hew's Bane" },
    [75] = { label = "Anvil", zone = "Gold Coast" },
    [76] = { label = "Kvatch", zone = "Gold Coast" },
    [77] = { label = "Anvil Outlaws Refuge", zone = "Gold Coast" },
    [78] = { label = "Vivec City", zone = "Vvardenfell" },
    [79] = { label = "Vivec City Outlaws Refuge", zone = "Vvardenfell" },
    [80] = { label = "Sadrith Mora", zone = "Vvardenfell" },
    [81] = { label = "Balmora", zone = "Vvardenfell" },
    [82] = { label = "Brass Fortress", zone = "Clockwork City" },
    [83] = { label = "Brass Fortress Outlaws Refuge", zone = "Clockwork City" },
    [84] = { label = "Lillandril", zone = "Summerset" },
    [85] = { label = "Shimmerene", zone = "Summerset" },
    [86] = { label = "Alinor", zone = "Summerset" },
    [87] = { label = "Alinor Outlaws Refuge", zone = "Summerset" },
    [88] = { label = "Lilmoth", zone = "Murkmire" },
    [89] = { label = "Lilmoth Outlaws Refuge", zone = "Murkmire" },
    [90] = { label = "Rimmen", zone = "Northern Elsweyr" },
    [91] = { label = "Rimmen Outlaws Refuge", zone = "Northern Elsweyr" },
    [92] = { label = "Senchal", zone = "Southern Elsweyr" },
    [93] = { label = "Senchal Outlaws Refuge", zone = "Southern Elsweyr" },
    [94] = { label = "Solitude", zone = "Western Skyrim" },
    [95] = { label = "Solitude Outlaws Refuge", zone = "Western Skyrim" },
    [96] = { label = "Markarth", zone = "The Reach" },
    [97] = { label = "Markarth Outlaws Refuge", zone = "The Reach" },
    [98] = { label = "Leyawiin", zone = "Blackwood" },
    [99] = { label = "Leyawiin Outlaws Refuge", zone = "Blackwood" },
    [100] = { label = "Fargrave", zone = "Fargrave" },
    [101] = { label = "Fargrave Outlaws Refuge", zone = "Fargrave" },
    [102] = { label = "Gonfalon Bay", zone = "High Isle" },
    [103] = { label = "Gonfalon Bay Outlaws Refuge", zone = "High Isle" },
    [104] = { label = "Vastyr", zone = "Galen" },
    [105] = { label = "Vastyr Outlaws Refuge", zone = "Galen" },
    [106] = { label = "Necrom", zone = "Telvanni Peninsula" },
    [107] = { label = "Necrom Outlaws Refuge", zone = "Telvanni Peninsula" },
    [108] = { label = "Skingrad", zone = "West Weald" },
    [109] = { label = "Skingrad Outlaws Refuge", zone = "West Weald" },
    [110] = { label = "Sunport", zone = "Solstice" },
    [111] = { label = "Sunport Outlaws Refuge", zone = "Solstice" },
}
M.KIOSK_LOCATIONS = KIOSK_LOCATIONS

local function safeField(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function lower(value)
    return string.lower(clean(value))
end

local function formatNumber(value)
    local n = tonumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, formatted = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and formatted then return tostring(formatted) end
    end
    local sign = n < 0 and "-" or ""
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return sign .. digits
end

local function now()
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function itemKey(itemLink)
    itemLink = tostring(itemLink or "")
    if itemLink == "" then return nil end
    local payload = itemLink:match("|H%d+:item:([^|]+)|h")
    if payload and payload ~= "" then return payload end
    return itemLink
end

local function itemName(itemLink)
    if type(GetItemLinkName) == "function" then
        local ok, value = pcall(GetItemLinkName, itemLink)
        if ok and value and value ~= "" then
            if type(zo_strformat) == "function" and SI_TOOLTIP_ITEM_NAME ~= nil then
                local fmtOk, formatted = pcall(zo_strformat, SI_TOOLTIP_ITEM_NAME, value)
                if fmtOk and formatted and formatted ~= "" then return tostring(formatted) end
            end
            return tostring(value)
        end
    end
    return "Item"
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function statusForAge(seconds)
    local hours = (tonumber(seconds) or 0) / 3600
    if hours <= 6 then return "FRESH", GREEN end
    if hours <= 24 then return "CURRENT", CYAN end
    if hours <= 72 then return "AGING", YELLOW end
    return "STALE", RED
end

local function currentSettings()
    local saved = EPC.saved or {}
    return {
        enabled = saved.marketPriceCheckerEnabled029683 ~= false,
        tooltip = saved.marketPriceTooltipEnabled029683 ~= false,
        travel = saved.marketPriceTravelEnabled029683 ~= false,
        source = tostring(saved.marketPriceSource029683 or "FRESHEST"),
        maxDealAgeHours = math.max(1, tonumber(saved.marketPriceMaxDealAgeHours029683) or 24),
        useTTCLocations = saved.marketPriceUseTTCLocations029683 ~= false,
    }
end

function M:GetESOHubData029683(itemLink)
    local lib = rawget(_G, "LibEsoHubPrices")
    if type(lib) ~= "table" or type(lib.GetItemPriceData) ~= "function" then return nil end
    local ok, data = pcall(lib.GetItemPriceData, itemLink)
    if not ok or type(data) ~= "table" then return nil end

    local internal = lib.internal
    local ts = type(internal) == "table" and tonumber(internal.dataTimeStamp) or 0
    return {
        source = "ESO-Hub",
        timestamp = ts or 0,
        min = tonumber(data.listingPriceMin),
        max = tonumber(data.listingPriceMax),
        avg = tonumber(data.averageListing),
        listings = tonumber(data.numberOfListings),
        suggestedMin = tonumber(data.suggestedListingPriceMin),
        suggestedMax = tonumber(data.suggestedListingPriceMax),
        saleAvg = tonumber(data.averageSales),
        sales = tonumber(data.numberOfSales),
    }
end

function M:GetTTCData029683(itemLink)
    local price = rawget(_G, "TamrielTradeCentrePrice")
    if type(price) ~= "table" or type(price.GetPriceInfo) ~= "function" then return nil end
    local ok, data = pcall(price.GetPriceInfo, price, itemLink)
    if not ok or type(data) ~= "table" then return nil end

    local ts = 0
    local tableData = safeField(price, "PriceTable")
    if type(tableData) == "table" then ts = tonumber(tableData.TimeStamp) or 0 end
    local suggested = tonumber(data.SuggestedPrice)
    return {
        source = "TTC",
        timestamp = ts,
        min = tonumber(data.Min),
        max = tonumber(data.Max),
        avg = tonumber(data.Avg),
        listings = tonumber(data.EntryCount),
        suggestedMin = suggested,
        suggestedMax = suggested and (suggested * 1.25) or nil,
        saleAvg = tonumber(data.SaleAvg),
        sales = tonumber(data.SaleEntryCount),
    }
end

local GetMarketData029683ImplArch

function M:GetMarketData029683(...)
    return GetMarketData029683ImplArch(self, ...)
end

GetMarketData029683ImplArch = function(self, itemLink)
    local settings = currentSettings()
    if not settings.enabled then return nil end

    local eh = self:GetESOHubData029683(itemLink)
    local ttc = self:GetTTCData029683(itemLink)
    if settings.source == "ESOHUB" then return eh or ttc end
    if settings.source == "TTC" then return ttc or eh end
    if eh and ttc then
        local ehTs = tonumber(eh.timestamp) or 0
        local ttcTs = tonumber(ttc.timestamp) or 0
        if ttcTs > ehTs then return ttc end
        return eh
    end
    return eh or ttc
end

function M:GetLocationInfo029683(record)
    if type(record) ~= "table" then return nil end
    local kioskId = tonumber(record.kioskId)
    local mapped = kioskId and KIOSK_LOCATIONS[kioskId] or nil
    if mapped then
        return {
            label = mapped.label,
            zone = mapped.zone,
            kioskId = kioskId,
        }
    end

    local label = clean(record.locationName or record.traderName or "")
    local zone = clean(record.zoneName or "")
    if label == "" and zone == "" then return nil end
    return { label = label ~= "" and label or zone, zone = zone, kioskId = kioskId }
end

local PutLocatedListing029683ImplArch

function M:PutLocatedListing029683(...)
    return PutLocatedListing029683ImplArch(self, ...)
end

PutLocatedListing029683ImplArch = function(self, record)
    if type(record) ~= "table" or not record.itemLink then return end
    local key = itemKey(record.itemLink)
    if not key then return end
    local unit = tonumber(record.unitPrice)
    if not unit or unit <= 0 then return end

    self.sessionLocated = self.sessionLocated or {}
    local old = self.sessionLocated[key]
    local oldExpired = old and tonumber(old.expireAt) and tonumber(old.expireAt) > 0 and tonumber(old.expireAt) <= now()
    if not old or oldExpired or unit < (tonumber(old.unitPrice) or math.huge) or (unit == tonumber(old.unitPrice) and (tonumber(record.seenAt) or 0) > (tonumber(old.seenAt) or 0)) then
        self.sessionLocated[key] = record
    end
end

function M:GetLocatedListing029683(itemLink)
    local key = itemKey(itemLink)
    if not key then return nil end
    local currentTime = now()
    local best = self.sessionLocated and self.sessionLocated[key] or nil
    if best and tonumber(best.expireAt) and tonumber(best.expireAt) > 0 and tonumber(best.expireAt) <= currentTime then
        best = nil
    end

    local settings = currentSettings()
    if settings.useTTCLocations and self.ttcLocated then
        local ttc = self.ttcLocated[key]
        if ttc and (not tonumber(ttc.expireAt) or tonumber(ttc.expireAt) <= 0 or tonumber(ttc.expireAt) > currentTime) then
            if not best or (tonumber(ttc.unitPrice) or math.huge) < (tonumber(best.unitPrice) or math.huge) then
                best = ttc
            end
        end
    end
    return best
end

function M:RecordCurrentTraderResults029683()
    local settings = currentSettings()
    if not settings.enabled then return end
    if type(GetTradingHouseSearchResultsInfo) ~= "function" or type(GetTradingHouseSearchResultItemLink) ~= "function" then return end

    local okInfo, count = pcall(GetTradingHouseSearchResultsInfo)
    count = okInfo and tonumber(count) or 0
    if not count or count <= 0 then return end

    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local okGuild, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if okGuild then guildId, guildName = tonumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local okKiosk, value = pcall(ttc.GetCurrentKioskID, ttc)
        if okKiosk then kioskId = tonumber(value) end
    end

    local traderName = ""
    if type(GetUnitName) == "function" then
        local okTrader, value = pcall(GetUnitName, "interact")
        if okTrader then traderName = clean(value) end
    end
    local locationName = type(GetPlayerLocationName) == "function" and clean(GetPlayerLocationName()) or ""
    local zoneName = type(GetPlayerActiveZoneName) == "function" and clean(GetPlayerActiveZoneName()) or ""
    local seenAt = now()

    for i = 1, count do
        local okLink, link = pcall(GetTradingHouseSearchResultItemLink, i)
        if okLink and type(link) == "string" and link ~= "" then
            local okRow, _, _, _, stackCount, sellerName, timeRemaining, totalPrice = pcall(GetTradingHouseSearchResultItemInfo, i)
            if okRow then
                stackCount = math.max(1, tonumber(stackCount) or 1)
                totalPrice = tonumber(totalPrice) or 0
                if totalPrice > 0 then
                    self:PutLocatedListing029683({
                        itemLink = link,
                        unitPrice = totalPrice / stackCount,
                        totalPrice = totalPrice,
                        amount = stackCount,
                        sellerName = clean(sellerName),
                        guildName = guildName,
                        guildId = guildId,
                        kioskId = kioskId,
                        traderName = traderName,
                        locationName = locationName,
                        zoneName = zoneName,
                        seenAt = seenAt,
                        expireAt = seenAt + math.max(0, tonumber(timeRemaining) or 0),
                        source = "LIVE",
                    })
                end
            end
        end
    end
end

local StartTTCSeenIndex029683ImplArch

function M:StartTTCSeenIndex029683(...)
    return StartTTCSeenIndex029683ImplArch(self, ...)
end

StartTTCSeenIndex029683ImplArch = function(self, force)
    local settings = currentSettings()
    if not settings.useTTCLocations then return end
    if self.ttcIndexBuilding then return end
    if self.ttcIndexReady and not force then return end

    local ttc = rawget(_G, "TamrielTradeCentre")
    local data = type(ttc) == "table" and safeField(ttc, "Data") or nil
    local auto = type(data) == "table" and data.AutoRecordEntries or nil
    local guilds = type(auto) == "table" and auto.Guilds or nil
    if type(guilds) ~= "table" then
        self.ttcIndexReady = true
        self.ttcLocated = {}
        return
    end

    self.ttcIndexBuilding = true
    self.ttcIndexReady = false
    self.ttcLocated = {}
    local target = self.ttcLocated
    local currentTime = now()

    local co = coroutine.create(function()
        local processed = 0
        for guildName, guildData in pairs(guilds) do
            if type(guildData) == "table" then
                local kioskId = tonumber(guildData.KioskLocationID)
                local lastUpdate = tonumber(guildData.LastUpdate) or 0
                local players = guildData.PlayerListings
                if type(players) == "table" then
                    for sellerName, listings in pairs(players) do
                        if type(listings) == "table" then
                            for _, entry in pairs(listings) do
                                if type(entry) == "table" then
                                    local link = entry.ItemLink
                                    local amount = math.max(1, tonumber(entry.Amount) or 1)
                                    local total = tonumber(entry.TotalPrice) or 0
                                    local expireAt = tonumber(entry.ExpireTime) or 0
                                    if type(link) == "string" and link ~= "" and total > 0 and (expireAt <= 0 or expireAt > currentTime) then
                                        local key = itemKey(link)
                                        local unit = total / amount
                                        if key and unit > 0 then
                                            local old = target[key]
                                            if not old or unit < (tonumber(old.unitPrice) or math.huge) then
                                                target[key] = {
                                                    itemLink = link,
                                                    unitPrice = unit,
                                                    totalPrice = total,
                                                    amount = amount,
                                                    sellerName = clean(sellerName),
                                                    guildName = clean(guildName),
                                                    kioskId = kioskId,
                                                    seenAt = tonumber(entry.DiscoverTime) or lastUpdate,
                                                    expireAt = expireAt,
                                                    source = "TTC SEEN",
                                                }
                                            end
                                        end
                                    end
                                    processed = processed + 1
                                    if processed % 250 == 0 then coroutine.yield() end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    local function step()
        if not M.ttcIndexBuilding then return end
        local ok, err = coroutine.resume(co)
        if not ok then
            M.ttcIndexBuilding = false
            M.ttcIndexReady = true
            if EPC and type(EPC.Print) == "function" then EPC:Print("Market TTC location index failed: " .. tostring(err)) end
            return
        end
        if coroutine.status(co) == "dead" then
            M.ttcIndexBuilding = false
            M.ttcIndexReady = true
            return
        end
        zo_callLater(step, 16)
    end
    step()
end

local function controlName(control)
    if not control or type(control.GetName) ~= "function" then return "" end
    local ok, value = pcall(control.GetName, control)
    return ok and tostring(value or "") or ""
end

local function getMouseControl()
    local wm = rawget(_G, "WINDOW_MANAGER")
    if wm and type(wm.GetMouseOverControl) == "function" then
        local ok, control = pcall(wm.GetMouseOverControl, wm)
        if ok then return control end
    end
    if type(GetMouseOverControl) == "function" then
        local ok, control = pcall(GetMouseOverControl)
        if ok then return control end
    end
    return nil
end

function M:GetItemLinkFromControl029683(control)
    local current = control
    for _ = 1, 7 do
        if not current then break end
        local dataEntry = safeField(current, "dataEntry")
        local data = type(dataEntry) == "table" and dataEntry.data or safeField(current, "data")
        if type(data) == "table" then
            local link = data.itemLink or data.link
            if type(link) == "string" and link ~= "" then return link end
            local bagId = data.bagId or data.bag
            local slotIndex = data.slotIndex or data.slot
            if bagId ~= nil and slotIndex ~= nil and type(GetItemLink) == "function" then
                local ok, itemLinkValue = pcall(GetItemLink, bagId, slotIndex, LINK_STYLE_DEFAULT)
                if ok and itemLinkValue and itemLinkValue ~= "" then return itemLinkValue end
            end
            local rowIndex = tonumber(data.slotIndex or data.index)
            if rowIndex and type(GetTradingHouseSearchResultItemLink) == "function" then
                local ok, itemLinkValue = pcall(GetTradingHouseSearchResultItemLink, rowIndex)
                if ok and itemLinkValue and itemLinkValue ~= "" then return itemLinkValue end
            end
        end

        local bagId = safeField(current, "bagId")
        local slotIndex = safeField(current, "slotIndex")
        if bagId ~= nil and slotIndex ~= nil and type(GetItemLink) == "function" then
            local ok, itemLinkValue = pcall(GetItemLink, bagId, slotIndex, LINK_STYLE_DEFAULT)
            if ok and itemLinkValue and itemLinkValue ~= "" then return itemLinkValue end
        end

        if type(current.GetParent) ~= "function" then break end
        local ok, parent = pcall(current.GetParent, current)
        current = ok and parent or nil
    end
    return nil
end

function M:GetHoveredItemLink029683()
    local popup = rawget(_G, "PopupTooltip")
    if popup and type(popup.IsHidden) == "function" then
        local okHidden, hidden = pcall(popup.IsHidden, popup)
        if okHidden and hidden == false then
            local link = safeField(popup, "lastLink")
            if type(link) == "string" and link ~= "" then return link end
        end
    end

    local control = getMouseControl()
    if control then
        local link = self:GetItemLinkFromControl029683(control)
        if link then return link end
    end
    return nil
end

function M:EnsureTravelButton029683()
    if self.travelButton or not WINDOW_MANAGER or not GuiRoot then return self.travelButton end
    local button = WINDOW_MANAGER:CreateControl("EASMarketTravelButton029683", GuiRoot, CT_BUTTON)
    button:SetDimensions(220, 30)
    if type(button.SetFont) == "function" then button:SetFont("ZoFontGameBold") end
    button:SetText("TRAVEL TO TRADER")
    button:SetMouseEnabled(true)
    if type(button.SetDrawLayer) == "function" and DL_OVERLAY ~= nil then button:SetDrawLayer(DL_OVERLAY) end
    if type(button.SetDrawTier) == "function" and DT_HIGH ~= nil then button:SetDrawTier(DT_HIGH) end
    button:SetHidden(true)
    button:SetHandler("OnClicked", function()
        if EPC.MarketPriceChecker then EPC.MarketPriceChecker:TravelToActiveListing029683() end
    end)
    self.travelButton = button
    return button
end

local function travelNeedle(label)
    local text = lower(label)
    text = text:gsub(" outlaws refuge", "")
    text = text:gsub(" wayshrine", "")
    text = text:gsub("^the ", "")
    text = text:gsub("%s+", " ")
    return text
end

function M:FindTravelNode029683(location, record)
    if type(location) ~= "table" or type(GetNumFastTravelNodes) ~= "function" or type(GetFastTravelNodeInfo) ~= "function" then return nil end

    if type(record) == "table" and tonumber(record.travelNodeIndex) then
        return tonumber(record.travelNodeIndex), record.travelNodeName
    end

    local needle = travelNeedle(location.label)
    local zoneNeedle = lower(location.zone)
    if needle == "" then return nil end

    local okCount, count = pcall(GetNumFastTravelNodes)
    count = okCount and tonumber(count) or 0
    local bestIndex, bestName, bestScore = nil, nil, -1
    for nodeIndex = 1, (count or 0) do
        local ok, known, nodeName, _, _, _, _, poiType, _, locked = pcall(GetFastTravelNodeInfo, nodeIndex)
        if ok and known == true and locked ~= true and type(nodeName) == "string" and nodeName ~= "" then
            if POI_TYPE_WAYSHRINE == nil or poiType == POI_TYPE_WAYSHRINE then
                local nodeNeedle = travelNeedle(nodeName)
                local score = 0
                if nodeNeedle == needle then
                    score = 1000
                elseif nodeNeedle:find(needle, 1, true) then
                    score = 800
                elseif needle:find(nodeNeedle, 1, true) then
                    score = 650
                else
                    local first = needle:match("^([^%s]+)")
                    if first and #first >= 5 and nodeNeedle:find(first, 1, true) then score = 300 end
                end

                -- Prefer a same-zone wayshrine when the Suite Travel module can
                -- expose zone metadata for the node. This prevents similarly named
                -- places in different zones from winning a loose name match.
                if score > 0 and zoneNeedle ~= "" and EPC.Travel and type(EPC.Travel.GetWayshrineNodeEntry) == "function" then
                    local entryOk, entry = pcall(EPC.Travel.GetWayshrineNodeEntry, EPC.Travel, nodeIndex)
                    if entryOk and type(entry) == "table" then
                        local nodeZone = lower(entry.zoneName)
                        if nodeZone ~= "" and nodeZone == zoneNeedle then
                            score = score + 500
                        elseif nodeZone ~= "" then
                            score = score - 200
                        end
                    end
                end

                if score > bestScore then
                    bestScore, bestIndex, bestName = score, nodeIndex, nodeName
                end
            end
        end
    end
    if bestScore < 300 then return nil end
    if type(record) == "table" then
        record.travelNodeIndex = bestIndex
        record.travelNodeName = bestName
    end
    return bestIndex, bestName
end

function M:TravelToActiveListing029683()
    local settings = currentSettings()
    if not settings.enabled or not settings.travel then return false end
    local record = self.activeLocatedListing
    local location = self:GetLocationInfo029683(record)
    if not location then
        if EPC and type(EPC.Print) == "function" then EPC:Print("No exact trader location is available for this listing yet.") end
        return false
    end

    local nodeIndex, nodeName = self:FindTravelNode029683(location, record)
    if not nodeIndex then
        if EPC and type(EPC.Print) == "function" then
            EPC:Print("No discovered matching wayshrine was found for " .. tostring(location.label) .. ".")
        end
        return false
    end

    -- Reuse the Suite's existing wayshrine travel owner whenever possible so
    -- Market travel follows the same discovered-node validation and messaging as
    -- the Teleporter instead of maintaining a second fast-travel implementation.
    if EPC.Travel and type(EPC.Travel.TravelToWayshrineNode) == "function" then
        local ok, result = pcall(EPC.Travel.TravelToWayshrineNode, EPC.Travel, nodeIndex, nodeName or location.label)
        return ok and result ~= false
    end

    if type(FastTravelToNode) ~= "function" then
        if EPC and type(EPC.Print) == "function" then EPC:Print("ESO's wayshrine travel API is unavailable.") end
        return false
    end

    if EPC and type(EPC.Print) == "function" then
        EPC:Print("Traveling toward " .. tostring(location.label) .. " via " .. tostring(nodeName or "wayshrine") .. ".")
    end
    local ok = pcall(FastTravelToNode, nodeIndex)
    if not ok and EPC and type(EPC.Print) == "function" then
        EPC:Print("ESO rejected the travel request. Try the normal World Map.")
    end
    return ok
end

local HideTravelButton029683ImplArch

function M:HideTravelButton029683(...)
    return HideTravelButton029683ImplArch(self, ...)
end

HideTravelButton029683ImplArch = function(self)
    local button = self.travelButton
    if button then button:SetHidden(true) end
    self.activeLocatedListing = nil
end

local UpdateTravelButton029683ImplArch

function M:UpdateTravelButton029683(...)
    return UpdateTravelButton029683ImplArch(self, ...)
end

UpdateTravelButton029683ImplArch = function(self, tooltip, record)
    local settings = currentSettings()
    local button = self:EnsureTravelButton029683()
    if not button then return end
    if not settings.enabled or not settings.travel or not tooltip or not record then
        self:HideTravelButton029683()
        return
    end

    local location = self:GetLocationInfo029683(record)
    local nodeIndex = location and self:FindTravelNode029683(location, record) or nil
    if not location or not nodeIndex then
        self:HideTravelButton029683()
        return
    end

    self.activeLocatedListing = record
    button:ClearAnchors()
    button:SetAnchor(TOPRIGHT, tooltip, BOTTOMRIGHT, 0, 4)
    local text = "TRAVEL: " .. clean(location.label)
    if #text > 34 then text = string.sub(text, 1, 31) .. "..." end
    button:SetText(text)
    button:SetHidden(false)
end

local GetDealLabel029683ImplArch

function M:GetDealLabel029683(...)
    return GetDealLabel029683ImplArch(self, ...)
end

GetDealLabel029683ImplArch = function(self, located, market)
    if type(located) ~= "table" or type(market) ~= "table" then return nil end
    local live = tonumber(located.unitPrice)
    local low = tonumber(market.min)
    if not live or not low or low <= 0 then return nil end
    local ts = tonumber(market.timestamp) or 0
    local age = ts > 0 and math.max(0, now() - ts) or math.huge
    if age > currentSettings().maxDealAgeHours * 3600 then return nil end

    local pct = ((low - live) / low) * 100
    if pct >= 30 then return string.format("GREAT DEAL  %.0f%% below global low", pct), GREEN end
    if pct >= 15 then return string.format("GOOD DEAL  %.0f%% below global low", pct), GREEN end
    if pct >= 5 then return string.format("BELOW MARKET  %.0f%%", pct), CYAN end
    if pct >= -5 then return "NEAR CURRENT LOW", WHITE end
    return string.format("%.0f%% above current low", math.abs(pct)), ORANGE
end

local AppendMarketTooltip029683ImplArch

function M:AppendMarketTooltip029683(...)
    return AppendMarketTooltip029683ImplArch(self, ...)
end

AppendMarketTooltip029683ImplArch = function(self, tooltip, itemLink)
    local settings = currentSettings()
    if not settings.enabled or not settings.tooltip or not tooltip or type(itemLink) ~= "string" or itemLink == "" then
        self:HideTravelButton029683()
        return
    end

    local market = self:GetMarketData029683(itemLink)
    local located = self:GetLocatedListing029683(itemLink)
    if not market and not located then
        self:HideTravelButton029683()
        return
    end

    if type(tooltip.AddVerticalPadding) == "function" then pcall(tooltip.AddVerticalPadding, tooltip, 5) end
    if type(ZO_Tooltip_AddDivider) == "function" then pcall(ZO_Tooltip_AddDivider, tooltip) end
    if type(tooltip.AddLine) ~= "function" then return end

    pcall(tooltip.AddLine, tooltip, GOLD .. "ESO ADVENTURER SUITE MARKET" .. RESET)

    if market then
        local ts = tonumber(market.timestamp) or 0
        local age = ts > 0 and math.max(0, now() - ts) or nil
        local status, statusColor = "UNKNOWN", GREY
        if age then status, statusColor = statusForAge(age) end
        local ageText = age and (formatAge(age) .. " old") or "timestamp unavailable"
        pcall(tooltip.AddLine, tooltip, string.format("%sSource:%s %s  %s%s%s  %s", GREY, RESET, tostring(market.source), statusColor, status, RESET, ageText))

        local priceBits = {}
        if market.min then priceBits[#priceBits + 1] = "Global Low " .. GOLD .. formatNumber(market.min) .. "g" .. RESET end
        if market.avg then priceBits[#priceBits + 1] = "Avg " .. formatNumber(market.avg) .. "g" end
        if market.listings then priceBits[#priceBits + 1] = formatNumber(market.listings) .. " listings" end
        if #priceBits > 0 then pcall(tooltip.AddLine, tooltip, table.concat(priceBits, "   ")) end

        if market.suggestedMin or market.suggestedMax then
            local lo = market.suggestedMin or market.suggestedMax
            local hi = market.suggestedMax or market.suggestedMin
            local text = lo and hi and lo ~= hi and (formatNumber(lo) .. "-" .. formatNumber(hi) .. "g") or (formatNumber(lo or hi) .. "g")
            pcall(tooltip.AddLine, tooltip, "Suggested " .. text .. (market.saleAvg and ("   Sales Avg " .. formatNumber(market.saleAvg) .. "g") or ""))
        elseif market.saleAvg then
            pcall(tooltip.AddLine, tooltip, "Recent Sale Avg " .. formatNumber(market.saleAvg) .. "g")
        end
    end

    if located then
        local location = self:GetLocationInfo029683(located)
        local locPrice = tonumber(located.unitPrice)
        local guildName = clean(located.guildName)
        local seenAt = tonumber(located.seenAt) or 0
        local seenAge = seenAt > 0 and formatAge(math.max(0, now() - seenAt)) or "unknown"
        local title = "Located lowest seen " .. GOLD .. formatNumber(locPrice) .. "g" .. RESET
        if guildName ~= "" then title = title .. "  " .. CYAN .. guildName .. RESET end
        pcall(tooltip.AddLine, tooltip, title)
        if market and tonumber(market.min) and tonumber(market.min) > 0 and locPrice then
            local delta = math.abs(locPrice - tonumber(market.min))
            local tolerance = math.max(1, tonumber(market.min) * 0.001)
            if delta <= tolerance then
                pcall(tooltip.AddLine, tooltip, GREEN .. "MATCHES GLOBAL LOWEST" .. RESET)
            end
        end
        if location then
            local where = clean(location.label)
            if clean(location.zone) ~= "" and lower(location.zone) ~= lower(where) then where = where .. " - " .. clean(location.zone) end
            pcall(tooltip.AddLine, tooltip, WHITE .. where .. RESET .. GREY .. "  seen " .. seenAge .. " ago" .. (located.source and ("  [" .. tostring(located.source) .. "]") or "") .. RESET)
        end
        local dealText, dealColor = self:GetDealLabel029683(located, market)
        if dealText then pcall(tooltip.AddLine, tooltip, dealColor .. dealText .. RESET) end
    elseif market then
        pcall(tooltip.AddLine, tooltip, GREY .. "Exact trader location is not carried by the aggregate price table." .. RESET)
        pcall(tooltip.AddLine, tooltip, GREY .. "Visit/scan guild traders to build a travel-ready located listing." .. RESET)
    end

    self:UpdateTravelButton029683(tooltip, located)
end

function M:RefreshTooltip029683(tooltip)
    local itemLink = self:GetHoveredItemLink029683()
    if not itemLink then return end
    local key = itemKey(itemLink)
    local control = getMouseControl()
    local controlId = control and controlName(control) or ""
    local signature = tostring(key or "") .. "|" .. tostring(controlId)
    if self.lastTooltipSignature == signature then return end
    self.lastTooltipSignature = signature
    self.lastTooltipLink = itemLink
    self:AppendMarketTooltip029683(tooltip, itemLink)
end

function M:InitializeTooltipHooks029683()
    local tooltip = rawget(_G, "ItemTooltip")
    if not tooltip or type(tooltip.SetHandler) ~= "function" then return end

    tooltip:SetHandler("OnUpdate", function(control)
        if not EPC.MarketPriceChecker then return end
        EPC.MarketPriceChecker:RefreshTooltip029683(control)
    end, CONTROL_HANDLER_ORDER_AFTER)

    local function cleared()
        if not EPC.MarketPriceChecker then return end
        EPC.MarketPriceChecker.lastTooltipSignature = nil
        EPC.MarketPriceChecker.lastTooltipLink = nil
        EPC.MarketPriceChecker:HideTravelButton029683()
    end
    tooltip:SetHandler("OnHide", cleared, CONTROL_HANDLER_ORDER_AFTER)
    tooltip:SetHandler("OnCleared", cleared, CONTROL_HANDLER_ORDER_AFTER)
end

function M:Initialize029683()
    if self.initialized029683 then return end
    self.initialized029683 = true
    self.sessionLocated = {}
    self.ttcLocated = {}

    self:InitializeTooltipHooks029683()
    self:EnsureTravelButton029683()
    zo_callLater(function()
        if EPC.MarketPriceChecker then EPC.MarketPriceChecker:StartTTCSeenIndex029683(false) end
    end, 3500)

    if EVENT_MANAGER and EVENT_TRADING_HOUSE_RESPONSE_RECEIVED ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceChecker","Trader",EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function()
            zo_callLater(function()
                if EPC.MarketPriceChecker then EPC.MarketPriceChecker:RecordCurrentTraderResults029683() end
            end, 50)
        end)
    end
    if EVENT_MANAGER and EVENT_CLOSE_TRADING_HOUSE ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceChecker","Close",EVENT_CLOSE_TRADING_HOUSE, function()
            if EPC.MarketPriceChecker then EPC.MarketPriceChecker:HideTravelButton029683() end
        end)
    end
end

if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
    EPC.Runtime:RegisterEvent("MarketPriceChecker","Activated",EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_PLAYER_ACTIVATED)
        zo_callLater(function()
            if EPC.MarketPriceChecker then EPC.MarketPriceChecker:Initialize029683() end
        end, 500)
    end)
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easmarket"] = function()
    if not EPC.MarketPriceChecker then return end
    local link = EPC.MarketPriceChecker.lastTooltipLink or EPC.MarketPriceChecker:GetHoveredItemLink029683()
    if not link then
        if type(EPC.Print) == "function" then EPC:Print("Hover an item, then use /easmarket.") end
        return
    end
    local market = EPC.MarketPriceChecker:GetMarketData029683(link)
    local located = EPC.MarketPriceChecker:GetLocatedListing029683(link)
    local parts = { itemName(link) }
    if market and market.min then parts[#parts + 1] = "global low " .. formatNumber(market.min) .. "g (" .. tostring(market.source) .. ")" end
    if located then
        local loc = EPC.MarketPriceChecker:GetLocationInfo029683(located)
        parts[#parts + 1] = "located " .. formatNumber(located.unitPrice) .. "g" .. (loc and (" at " .. tostring(loc.label)) or "")
    end
    if type(EPC.Print) == "function" then EPC:Print(table.concat(parts, " | ")) end
end

EPC.marketPriceChecker029683 = true


-- Market Price absorbed passive correction layers

-- BEGIN ABSORBED: MarketPriceCheckerPolishFix.lua
-- ESO Adventurer Suite
-- Market Price Checker polish: ESO-Hub-first source policy, TTC cross-check,
-- and exact hovered Guild Trader row deal comparison.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end

local M = EPC.MarketPriceChecker
if M._marketPricePolish029683 then return end
M._marketPricePolish029683 = true

-- ESO-Hub is the Suite's primary aggregate source. TTC remains the fallback and
-- cross-check source. The user can still explicitly choose TTC or Freshest Available.
EPC.defaults = EPC.defaults or {}
EPC.defaults.marketPriceSource029683 = "ESOHUB"

local GOLD = "|cFFD700"
local WHITE = "|cFFFFFF"
local GREY = "|cA0A0A0"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local ORANGE = "|cFFAA55"
local RED = "|cFF6666"
local RESET = "|r"

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function now()
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local sign = n < 0 and "-" or ""
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return sign .. digits
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m " .. tostring(seconds % 60) .. "s" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function ageColor(seconds)
    local hours = (safeNumber(seconds) or math.huge) / 3600
    if hours <= 6 then return GREEN end
    if hours <= 24 then return CYAN end
    if hours <= 72 then return YELLOW end
    return RED
end

local function marketReference(market)
    if type(market) ~= "table" then return nil, nil end

    local saleAvg = safeNumber(market.saleAvg)
    if saleAvg and saleAvg > 0 then
        return saleAvg, "recent sale avg"
    end

    local lo = safeNumber(market.suggestedMin)
    local hi = safeNumber(market.suggestedMax)
    if lo and lo > 0 and hi and hi > 0 then
        return (lo + hi) * 0.5, "suggested midpoint"
    end
    if lo and lo > 0 then return lo, "suggested price" end
    if hi and hi > 0 then return hi, "suggested price" end

    local avg = safeNumber(market.avg)
    if avg and avg > 0 then return avg, "average listing" end

    local low = safeNumber(market.min)
    if low and low > 0 then return low, "global low" end
    return nil, nil
end

function M:GetMarketSources029683(itemLink)
    local saved = EPC.saved or {}
    if saved.marketPriceCheckerEnabled029683 == false then return nil, nil end

    local esoHub = self:GetESOHubData029683(itemLink)
    local ttc = self:GetTTCData029683(itemLink)
    local preference = tostring(saved.marketPriceSource029683 or EPC.defaults.marketPriceSource029683 or "ESOHUB")

    if preference == "TTC" then
        return ttc or esoHub, (ttc and esoHub) or nil
    end

    if preference == "FRESHEST" then
        if esoHub and ttc then
            local ehTs = safeNumber(esoHub.timestamp) or 0
            local ttcTs = safeNumber(ttc.timestamp) or 0
            if ttcTs > ehTs then return ttc, esoHub end
            return esoHub, ttc
        end
        return esoHub or ttc, nil
    end

    -- Default and explicit ESOHUB mode: ESO-Hub first, TTC fallback/cross-check.
    return esoHub or ttc, (esoHub and ttc) or nil
end

GetMarketData029683ImplArch = function(self, itemLink)
    local primary = self:GetMarketSources029683(itemLink)
    return primary
end

GetDealLabel029683ImplArch = function(self, listing, market)
    if type(listing) ~= "table" or type(market) ~= "table" then return nil end
    local live = safeNumber(listing.unitPrice)
    local reference, basis = marketReference(market)
    if not live or live <= 0 or not reference or reference <= 0 then return nil end

    local ts = safeNumber(market.timestamp) or 0
    local age = ts > 0 and math.max(0, now() - ts) or math.huge
    local maxAgeHours = math.max(1, safeNumber((EPC.saved or {}).marketPriceMaxDealAgeHours029683) or 24)
    if age > maxAgeHours * 3600 then return nil end

    local pct = ((reference - live) / reference) * 100
    if pct >= 35 then
        return string.format("EXCEPTIONAL DEAL  %.0f%% below %s", pct, basis), GREEN, pct, basis
    elseif pct >= 20 then
        return string.format("GREAT DEAL  %.0f%% below %s", pct, basis), GREEN, pct, basis
    elseif pct >= 10 then
        return string.format("GOOD DEAL  %.0f%% below %s", pct, basis), GREEN, pct, basis
    elseif pct >= 5 then
        return string.format("BELOW MARKET  %.0f%% below %s", pct, basis), CYAN, pct, basis
    elseif pct > -5 then
        return string.format("FAIR PRICE  %.0f%% vs %s", math.abs(pct), basis), WHITE, pct, basis
    elseif pct > -15 then
        return string.format("SLIGHT MARKUP  %.0f%% above %s", math.abs(pct), basis), YELLOW, pct, basis
    elseif pct > -30 then
        return string.format("MARKUP  %.0f%% above %s", math.abs(pct), basis), ORANGE, pct, basis
    end
    return string.format("HIGH MARKUP  %.0f%% above %s", math.abs(pct), basis), RED, pct, basis
end

local function getMouseControl()
    local wm = rawget(_G, "WINDOW_MANAGER")
    if wm and type(wm.GetMouseOverControl) == "function" then
        local ok, control = pcall(wm.GetMouseOverControl, wm)
        if ok then return control end
    end
    if type(GetMouseOverControl) == "function" then
        local ok, control = pcall(GetMouseOverControl)
        if ok then return control end
    end
    return nil
end

local function safeField(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

function M:GetHoveredTraderRow029683(expectedItemLink)
    if type(GetTradingHouseSearchResultItemInfo) ~= "function" or type(GetTradingHouseSearchResultItemLink) ~= "function" then return nil end

    local tradingHouse = rawget(_G, "TRADING_HOUSE")
    if tradingHouse and type(tradingHouse.GetCurrentMode) == "function" and ZO_TRADING_HOUSE_MODE_BROWSE ~= nil then
        local okMode, mode = pcall(tradingHouse.GetCurrentMode, tradingHouse)
        if okMode and mode ~= ZO_TRADING_HOUSE_MODE_BROWSE then return nil end
    end

    local control = getMouseControl()
    local rowIndex = nil
    for _ = 1, 8 do
        if not control then break end
        local dataEntry = safeField(control, "dataEntry")
        local data = type(dataEntry) == "table" and dataEntry.data or safeField(control, "data")
        if type(data) == "table" then
            local candidate = safeNumber(data.slotIndex or data.resultIndex or data.index)
            local looksLikeTraderRow = data.purchasePrice ~= nil or data.purchasePricePerUnit ~= nil or data.sellerName ~= nil
            if candidate and candidate >= 1 and looksLikeTraderRow then
                rowIndex = math.floor(candidate)
                break
            end
        end
        if type(control.GetParent) ~= "function" then break end
        local okParent, parent = pcall(control.GetParent, control)
        control = okParent and parent or nil
    end
    if not rowIndex then return nil end

    local okLink, itemLink = pcall(GetTradingHouseSearchResultItemLink, rowIndex)
    if not okLink or type(itemLink) ~= "string" or itemLink == "" then return nil end
    if type(expectedItemLink) == "string" and expectedItemLink ~= "" and itemLink ~= expectedItemLink then
        -- Item links can be equivalent while differing in display-link style. Only
        -- reject when their item IDs prove they are actually different.
        if type(GetItemLinkItemId) == "function" then
            local okA, idA = pcall(GetItemLinkItemId, itemLink)
            local okB, idB = pcall(GetItemLinkItemId, expectedItemLink)
            if okA and okB and tonumber(idA) and tonumber(idB) and tonumber(idA) ~= tonumber(idB) then return nil end
        end
    end

    local okInfo, _, _, _, stackCount, sellerName, timeRemaining, totalPrice, _, itemUniqueId, unitPrice = pcall(GetTradingHouseSearchResultItemInfo, rowIndex)
    if not okInfo then return nil end
    stackCount = math.max(1, safeNumber(stackCount) or 1)
    totalPrice = safeNumber(totalPrice) or 0
    unitPrice = safeNumber(unitPrice) or (totalPrice > 0 and totalPrice / stackCount or nil)
    if not unitPrice or unitPrice <= 0 then return nil end

    return {
        rowIndex = rowIndex,
        itemLink = itemLink,
        unitPrice = unitPrice,
        totalPrice = totalPrice,
        amount = stackCount,
        sellerName = tostring(sellerName or ""),
        timeRemaining = safeNumber(timeRemaining) or 0,
        itemUniqueId = itemUniqueId,
        source = "LIVE ROW",
    }
end

local baseAppendMarketTooltip029683 = AppendMarketTooltip029683ImplArch

AppendMarketTooltip029683ImplArch = function(self, tooltip, itemLink)
    baseAppendMarketTooltip029683(self, tooltip, itemLink)

    local saved = EPC.saved or {}
    if saved.marketPriceCheckerEnabled029683 == false or saved.marketPriceTooltipEnabled029683 == false then return end
    if not tooltip or type(tooltip.AddLine) ~= "function" or type(itemLink) ~= "string" or itemLink == "" then return end

    local primary, cross = self:GetMarketSources029683(itemLink)
    if cross then
        local crossBits = {}
        if safeNumber(cross.min) then crossBits[#crossBits + 1] = "low " .. GOLD .. formatNumber(cross.min) .. "g" .. RESET end
        if safeNumber(cross.avg) then crossBits[#crossBits + 1] = "avg " .. formatNumber(cross.avg) .. "g" end
        if safeNumber(cross.listings) then crossBits[#crossBits + 1] = formatNumber(cross.listings) .. " listings" end

        local ts = safeNumber(cross.timestamp) or 0
        local age = ts > 0 and math.max(0, now() - ts) or nil
        local ageText = age and (ageColor(age) .. formatAge(age) .. " old" .. RESET) or (GREY .. "age unknown" .. RESET)
        local line = CYAN .. "Cross-check " .. tostring(cross.source or "secondary") .. RESET
        if #crossBits > 0 then line = line .. ": " .. table.concat(crossBits, "   ") end
        line = line .. "   " .. ageText
        pcall(tooltip.AddLine, tooltip, line)

        if primary then
            local primaryRef = marketReference(primary)
            local crossRef = marketReference(cross)
            if primaryRef and crossRef and primaryRef > 0 then
                local gap = ((crossRef - primaryRef) / primaryRef) * 100
                pcall(tooltip.AddLine, tooltip, GREY .. string.format("Source reference gap: %+.1f%%", gap) .. RESET)
            end
        end
    end

    local liveRow = self:GetHoveredTraderRow029683(itemLink)
    if liveRow then
        local liveText = GOLD .. "LIVE LISTING  " .. formatNumber(liveRow.unitPrice) .. "g/unit" .. RESET
        if liveRow.amount and liveRow.amount > 1 then
            liveText = liveText .. GREY .. "  x" .. tostring(math.floor(liveRow.amount)) .. " = " .. formatNumber(liveRow.totalPrice) .. "g" .. RESET
        end
        pcall(tooltip.AddLine, tooltip, liveText)

        local dealText, dealColor = self:GetDealLabel029683(liveRow, primary)
        if dealText then
            pcall(tooltip.AddLine, tooltip, (dealColor or WHITE) .. dealText .. RESET)
        elseif primary and safeNumber(primary.timestamp) then
            local age = math.max(0, now() - safeNumber(primary.timestamp))
            local maxAgeHours = math.max(1, safeNumber(saved.marketPriceMaxDealAgeHours029683) or 24)
            if age > maxAgeHours * 3600 then
                pcall(tooltip.AddLine, tooltip, GREY .. "Deal rating withheld: aggregate market data is too old." .. RESET)
            end
        end
    end
end

EPC.marketPriceCheckerPolish029683 = true

-- END ABSORBED: MarketPriceCheckerPolishFix.lua

-- BEGIN ABSORBED: MarketPriceMultiTraderFix.lua
-- ESO Adventurer Suite
-- Suite Market Price Checker multi-trader persistence and travel-button reliability.
-- Keeps real trader observations beyond TTC's short-lived AutoRecordEntries cleanup,
-- shows multiple known traders for the hovered item, and does not hide TRAVEL merely
-- because a wayshrine cannot be pre-resolved before the user clicks it.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end

local M = EPC.MarketPriceChecker
if M._marketPriceMultiTrader029683 then return end
M._marketPriceMultiTrader029683 = true

EPC.defaults = EPC.defaults or {}
EPC.defaults.marketPriceTraderComparisonCount029683 = 5

local GOLD = "|cFFD700"
local WHITE = "|cFFFFFF"
local GREY = "|cA0A0A0"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local RESET = "|r"

local MAX_TRADERS_PER_ITEM = 12
local MAX_CACHED_ITEMS = 600
local MAX_CACHE_AGE = 30 * 24 * 60 * 60

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function now()
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok then return tonumber(value) or 0 end
    end
    return 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(clean(value))
end

local function itemKey(itemLink)
    itemLink = tostring(itemLink or "")
    if itemLink == "" then return nil end
    local payload = itemLink:match("|H%d+:item:([^|]+)|h")
    if payload and payload ~= "" then return payload end
    return itemLink
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local sign = n < 0 and "-" or ""
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return sign .. digits
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function cacheRoot()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketPriceTraderCache029683) ~= "table" then
        EPC.saved.marketPriceTraderCache029683 = {}
    end
    return EPC.saved.marketPriceTraderCache029683
end

local function traderIdentity(record)
    if type(record) ~= "table" then return nil end
    local kioskId = safeNumber(record.kioskId)
    local guild = lower(record.guildName)
    local trader = lower(record.traderName)
    local location = lower(record.locationName)
    local zone = lower(record.zoneName)

    if kioskId then
        return "k:" .. tostring(math.floor(kioskId)) .. "|g:" .. guild
    end
    if guild ~= "" then
        return "g:" .. guild .. "|l:" .. location .. "|z:" .. zone
    end
    if trader ~= "" then
        return "t:" .. trader .. "|l:" .. location .. "|z:" .. zone
    end
    if location ~= "" or zone ~= "" then
        return "l:" .. location .. "|z:" .. zone
    end
    return nil
end

local function isExpired(record, currentTime)
    if type(record) ~= "table" then return true end
    currentTime = currentTime or now()
    local expireAt = safeNumber(record.expireAt)
    if expireAt and expireAt > 0 and expireAt <= currentTime then return true end
    local seenAt = safeNumber(record.seenAt)
    if seenAt and seenAt > 0 and currentTime - seenAt > MAX_CACHE_AGE then return true end
    return false
end

local function trimTraderGroup(group)
    if type(group) ~= "table" or type(group.traders) ~= "table" then return end
    local currentTime = now()
    local rows = {}
    for id, record in pairs(group.traders) do
        if isExpired(record, currentTime) then
            group.traders[id] = nil
        else
            rows[#rows + 1] = { id = id, record = record }
        end
    end
    table.sort(rows, function(a, b)
        local ap = safeNumber(a.record.unitPrice) or math.huge
        local bp = safeNumber(b.record.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.record.seenAt) or 0) > (safeNumber(b.record.seenAt) or 0)
    end)
    for i = MAX_TRADERS_PER_ITEM + 1, #rows do
        group.traders[rows[i].id] = nil
    end
end

function M:PrunePersistentTraderCache029683()
    local root = cacheRoot()
    local currentTime = now()
    local groups = {}
    for key, group in pairs(root) do
        if type(group) ~= "table" then
            root[key] = nil
        else
            group.traders = type(group.traders) == "table" and group.traders or {}
            trimTraderGroup(group)
            local lastSeen = safeNumber(group.lastSeen) or 0
            local any = next(group.traders) ~= nil
            if not any or (lastSeen > 0 and currentTime - lastSeen > MAX_CACHE_AGE) then
                root[key] = nil
            else
                groups[#groups + 1] = { key = key, lastSeen = lastSeen }
            end
        end
    end
    if #groups > MAX_CACHED_ITEMS then
        table.sort(groups, function(a, b) return a.lastSeen > b.lastSeen end)
        for i = MAX_CACHED_ITEMS + 1, #groups do root[groups[i].key] = nil end
    end
end

local StorePersistentTraderListing029683ImplArch

function M:StorePersistentTraderListing029683(...)
    return StorePersistentTraderListing029683ImplArch(self, ...)
end

StorePersistentTraderListing029683ImplArch = function(self, record)
    if type(record) ~= "table" or type(record.itemLink) ~= "string" or record.itemLink == "" then return false end
    local key = itemKey(record.itemLink)
    local identity = traderIdentity(record)
    local unitPrice = safeNumber(record.unitPrice)
    if not key or not identity or not unitPrice or unitPrice <= 0 then return false end

    local currentTime = now()
    if isExpired(record, currentTime) then return false end

    local root = cacheRoot()
    local group = root[key]
    if type(group) ~= "table" then
        group = { lastSeen = 0, traders = {} }
        root[key] = group
    end
    group.traders = type(group.traders) == "table" and group.traders or {}

    local seenAt = safeNumber(record.seenAt) or currentTime
    local old = group.traders[identity]
    local replace = old == nil or isExpired(old, currentTime)
    if old and not replace then
        local oldSeen = safeNumber(old.seenAt) or 0
        local oldPrice = safeNumber(old.unitPrice) or math.huge
        -- Newer observations replace older ones. Within the same observation time,
        -- keep the cheaper row for that trader.
        replace = seenAt > oldSeen or (seenAt == oldSeen and unitPrice < oldPrice)
    end

    if replace then
        group.traders[identity] = {
            itemLink = record.itemLink,
            unitPrice = unitPrice,
            totalPrice = safeNumber(record.totalPrice),
            amount = math.max(1, safeNumber(record.amount) or 1),
            sellerName = clean(record.sellerName),
            guildName = clean(record.guildName),
            guildId = safeNumber(record.guildId),
            kioskId = safeNumber(record.kioskId),
            traderName = clean(record.traderName),
            locationName = clean(record.locationName),
            zoneName = clean(record.zoneName),
            seenAt = seenAt,
            expireAt = safeNumber(record.expireAt),
            source = clean(record.source ~= "" and record.source or "SUITE CACHE"),
        }
    end

    group.lastSeen = math.max(safeNumber(group.lastSeen) or 0, seenAt)
    trimTraderGroup(group)
    return true
end

local basePutLocatedListing029683 = PutLocatedListing029683ImplArch
PutLocatedListing029683ImplArch = function(self, record)
    self:StorePersistentTraderListing029683(record)
    return basePutLocatedListing029683(self, record)
end

function M:ImportTTCTraderHistory029683(force)
    if self.ttcPersistentImportBuilding then return end
    if self.ttcPersistentImportReady and not force then return end

    local ttc = rawget(_G, "TamrielTradeCentre")
    local data = type(ttc) == "table" and ttc.Data or nil
    local auto = type(data) == "table" and data.AutoRecordEntries or nil
    local guilds = type(auto) == "table" and auto.Guilds or nil
    if type(guilds) ~= "table" then
        self.ttcPersistentImportReady = true
        return
    end

    self.ttcPersistentImportBuilding = true
    self.ttcPersistentImportReady = false
    local currentTime = now()

    local co = coroutine.create(function()
        local processed = 0
        for guildName, guildData in pairs(guilds) do
            if type(guildData) == "table" then
                local kioskId = safeNumber(guildData.KioskLocationID)
                local lastUpdate = safeNumber(guildData.LastUpdate) or 0
                local players = guildData.PlayerListings
                if type(players) == "table" then
                    for sellerName, listings in pairs(players) do
                        if type(listings) == "table" then
                            for _, entry in pairs(listings) do
                                if type(entry) == "table" then
                                    local link = entry.ItemLink
                                    local amount = math.max(1, safeNumber(entry.Amount) or 1)
                                    local total = safeNumber(entry.TotalPrice) or 0
                                    local expireAt = safeNumber(entry.ExpireTime) or 0
                                    if type(link) == "string" and link ~= "" and total > 0 and (expireAt <= 0 or expireAt > currentTime) then
                                        self:StorePersistentTraderListing029683({
                                            itemLink = link,
                                            unitPrice = total / amount,
                                            totalPrice = total,
                                            amount = amount,
                                            sellerName = clean(sellerName),
                                            guildName = clean(guildName),
                                            kioskId = kioskId,
                                            seenAt = safeNumber(entry.DiscoverTime) or lastUpdate,
                                            expireAt = expireAt,
                                            source = "TTC HISTORY",
                                        })
                                    end
                                    processed = processed + 1
                                    if processed % 200 == 0 then coroutine.yield() end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    local function step()
        if not M.ttcPersistentImportBuilding then return end
        local ok, err = coroutine.resume(co)
        if not ok then
            M.ttcPersistentImportBuilding = false
            M.ttcPersistentImportReady = true
            if EPC and type(EPC.Print) == "function" then EPC:Print("Market multi-trader TTC import failed: " .. tostring(err)) end
            return
        end
        if coroutine.status(co) == "dead" then
            M.ttcPersistentImportBuilding = false
            M.ttcPersistentImportReady = true
            M:PrunePersistentTraderCache029683()
            M.lastTooltipSignature = nil
            return
        end
        if type(zo_callLater) == "function" then zo_callLater(step, 12) else step() end
    end
    step()
end

local baseStartTTCSeenIndex029683 = StartTTCSeenIndex029683ImplArch
StartTTCSeenIndex029683ImplArch = function(self, force)
    local result = baseStartTTCSeenIndex029683(self, force)
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if EPC.MarketPriceChecker then EPC.MarketPriceChecker:ImportTTCTraderHistory029683(force == true) end
        end, 30)
    else
        self:ImportTTCTraderHistory029683(force == true)
    end
    return result
end

local function currentTraderIdentity()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then guildId, guildName = safeNumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, id = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(id) end
    end

    if kioskId then return "k:" .. tostring(math.floor(kioskId)) .. "|g:" .. lower(guildName), kioskId, guildName, guildId end
    if guildName ~= "" then return "g:" .. lower(guildName), kioskId, guildName, guildId end
    return nil, kioskId, guildName, guildId
end

local GetComparableTraderListings029683ImplArch

function M:GetComparableTraderListings029683(...)
    return GetComparableTraderListings029683ImplArch(self, ...)
end

GetComparableTraderListings029683ImplArch = function(self, itemLink, limit)
    local key = itemKey(itemLink)
    if not key then return {} end
    local root = cacheRoot()
    local group = root[key]
    if type(group) ~= "table" or type(group.traders) ~= "table" then return {} end

    trimTraderGroup(group)
    local currentIdentity, currentKiosk, currentGuild = currentTraderIdentity()
    local currentGuildLower = lower(currentGuild)
    local rows = {}
    local currentTime = now()

    for id, record in pairs(group.traders) do
        if type(record) == "table" and not isExpired(record, currentTime) then
            local isCurrent = false
            local recordKiosk = safeNumber(record.kioskId)
            local recordGuild = lower(record.guildName)
            if currentKiosk and recordKiosk and math.floor(currentKiosk) == math.floor(recordKiosk) then
                if currentGuildLower == "" or recordGuild == "" or currentGuildLower == recordGuild then isCurrent = true end
            elseif currentIdentity and id == currentIdentity then
                isCurrent = true
            elseif currentGuildLower ~= "" and recordGuild ~= "" and currentGuildLower == recordGuild then
                isCurrent = true
            end
            record._easCurrentTrader = isCurrent
            rows[#rows + 1] = record
        end
    end

    table.sort(rows, function(a, b)
        local ap = safeNumber(a.unitPrice) or math.huge
        local bp = safeNumber(b.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.seenAt) or 0) > (safeNumber(b.seenAt) or 0)
    end)

    limit = math.max(1, math.floor(safeNumber(limit) or EPC.defaults.marketPriceTraderComparisonCount029683 or 5))
    while #rows > limit do table.remove(rows) end
    return rows
end

local GetBestTravelTrader029683ImplArch

function M:GetBestTravelTrader029683(...)
    return GetBestTravelTrader029683ImplArch(self, ...)
end

GetBestTravelTrader029683ImplArch = function(self, itemLink)
    local rows = self:GetComparableTraderListings029683(itemLink, MAX_TRADERS_PER_ITEM)
    for _, record in ipairs(rows) do
        if not record._easCurrentTrader and self:GetLocationInfo029683(record) then return record end
    end
    for _, record in ipairs(rows) do
        if self:GetLocationInfo029683(record) then return record end
    end
    return self:GetLocatedListing029683(itemLink)
end

-- The old implementation hid the button unless a matching discovered wayshrine
-- was found during tooltip construction. Keep the button visible whenever a real
-- trader location exists. TravelToActiveListing029683 performs the authoritative
-- wayshrine lookup after the user clicks it and can explain any failure.
UpdateTravelButton029683ImplArch = function(self, tooltip, record)
    local saved = EPC.saved or {}
    local button = self:EnsureTravelButton029683()
    if not button then return end
    if saved.marketPriceCheckerEnabled029683 == false or saved.marketPriceTravelEnabled029683 == false or not tooltip or not record then
        self:HideTravelButton029683()
        return
    end

    local location = self:GetLocationInfo029683(record)
    if not location then
        self:HideTravelButton029683()
        return
    end

    self.activeLocatedListing = record
    button:SetDimensions(260, 34)
    button:ClearAnchors()

    local placeAbove = false
    if type(tooltip.GetBottom) == "function" and GuiRoot and type(GuiRoot.GetHeight) == "function" then
        local okBottom, bottom = pcall(tooltip.GetBottom, tooltip)
        local okHeight, height = pcall(GuiRoot.GetHeight, GuiRoot)
        if okBottom and okHeight and safeNumber(bottom) and safeNumber(height) and bottom + 42 > height then placeAbove = true end
    end
    if placeAbove then
        button:SetAnchor(BOTTOMRIGHT, tooltip, TOPRIGHT, 0, -4)
    else
        button:SetAnchor(TOPRIGHT, tooltip, BOTTOMRIGHT, 0, 4)
    end

    local label = clean(location.label)
    local text = "TRAVEL TO: " .. label
    if #text > 40 then text = string.sub(text, 1, 37) .. "..." end
    button:SetText(text)

    if not button._easMarketBackdrop and WINDOW_MANAGER then
        local bg = WINDOW_MANAGER:CreateControl("EASMarketTravelButtonBackdrop029683", button, CT_BACKDROP)
        bg:SetAnchorFill(button)
        if type(bg.SetCenterColor) == "function" then bg:SetCenterColor(0.04, 0.04, 0.04, 0.96) end
        if type(bg.SetEdgeColor) == "function" then bg:SetEdgeColor(0.85, 0.65, 0.12, 1) end
        if type(bg.SetEdgeTexture) == "function" then pcall(bg.SetEdgeTexture, bg, nil, 1, 1, 1) end
        if type(bg.SetDrawLayer) == "function" and DL_BACKGROUND ~= nil then bg:SetDrawLayer(DL_BACKGROUND) end
        button._easMarketBackdrop = bg
    end

    button:SetHidden(false)
end

local baseAppendMarketTooltip029683 = AppendMarketTooltip029683ImplArch
AppendMarketTooltip029683ImplArch = function(self, tooltip, itemLink)
    baseAppendMarketTooltip029683(self, tooltip, itemLink)

    local saved = EPC.saved or {}
    if saved.marketPriceCheckerEnabled029683 == false or saved.marketPriceTooltipEnabled029683 == false then return end
    if not tooltip or type(tooltip.AddLine) ~= "function" or type(itemLink) ~= "string" or itemLink == "" then return end

    local requested = math.max(1, math.floor(safeNumber(saved.marketPriceTraderComparisonCount029683) or EPC.defaults.marketPriceTraderComparisonCount029683 or 5))
    requested = math.min(MAX_TRADERS_PER_ITEM, requested)
    local rows = self:GetComparableTraderListings029683(itemLink, requested)

    if #rows > 0 then
        pcall(tooltip.AddLine, tooltip, CYAN .. "TRADER COMPARISON" .. RESET .. GREY .. "  (real listings seen by this client)" .. RESET)
        for i, record in ipairs(rows) do
            local price = formatNumber(record.unitPrice) .. "g"
            local guild = clean(record.guildName)
            local location = self:GetLocationInfo029683(record)
            local where = location and clean(location.label) or clean(record.locationName)
            local seenAt = safeNumber(record.seenAt) or 0
            local age = seenAt > 0 and formatAge(math.max(0, now() - seenAt)) or "unknown"
            local marker = record._easCurrentTrader and (GREEN .. "CURRENT" .. RESET) or (WHITE .. "OTHER" .. RESET)
            local line = tostring(i) .. ". " .. GOLD .. price .. RESET .. "  " .. marker
            if guild ~= "" then line = line .. "  " .. CYAN .. guild .. RESET end
            if where ~= "" then line = line .. "  " .. WHITE .. where .. RESET end
            line = line .. GREY .. "  seen " .. age .. " ago" .. RESET
            pcall(tooltip.AddLine, tooltip, line)
        end
    else
        pcall(tooltip.AddLine, tooltip, GREY .. "No other trader locations cached for this exact item yet." .. RESET)
        pcall(tooltip.AddLine, tooltip, GREY .. "The Suite now permanently remembers real traders as you search them." .. RESET)
    end

    local travelRecord = self:GetBestTravelTrader029683(itemLink)
    self:UpdateTravelButton029683(tooltip, travelRecord)
end

-- A small diagnostic command is useful when checking whether cross-trader data
-- exists without guessing from the tooltip.
SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easmarkettraders"] = function()
    if not EPC.MarketPriceChecker then return end
    local link = EPC.MarketPriceChecker.lastTooltipLink or EPC.MarketPriceChecker:GetHoveredItemLink029683()
    if not link then
        if type(EPC.Print) == "function" then EPC:Print("Hover an item, then use /easmarkettraders.") end
        return
    end
    local rows = EPC.MarketPriceChecker:GetComparableTraderListings029683(link, MAX_TRADERS_PER_ITEM)
    local others = 0
    for _, row in ipairs(rows) do if not row._easCurrentTrader then others = others + 1 end end
    if type(EPC.Print) == "function" then
        EPC:Print("Market cache: " .. tostring(#rows) .. " known trader(s) for this exact item; " .. tostring(others) .. " other trader(s).")
    end
end

if type(zo_callLater) == "function" then
    zo_callLater(function()
        if EPC.MarketPriceChecker then
            EPC.MarketPriceChecker:PrunePersistentTraderCache029683()
            EPC.MarketPriceChecker:ImportTTCTraderHistory029683(false)
        end
    end, 4500)
end

EPC.marketPriceMultiTrader029683 = true

-- END ABSORBED: MarketPriceMultiTraderFix.lua

-- BEGIN ABSORBED: MarketPriceLiveTraderCaptureFix.lua
-- ESO Adventurer Suite
-- Verified market comparison + live trader capture.
-- Canonically matches the same sellable item across guild traders, keeps aggregate
-- pricing separate from verified trader locations, and only travels to a real
-- alternate trader record.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketPriceLiveCapture029683 then return end
M._marketPriceLiveCapture029683 = true
M._marketPriceVerifiedComparison029683 = true

local GOLD = "|cFFD700"
local WHITE = "|cFFFFFF"
local GREY = "|cA0A0A0"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local RESET = "|r"

local MAX_TRADERS_PER_ITEM = 12
local MAX_CACHE_AGE = 30 * 24 * 60 * 60

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function now()
    return safeNumber(safeCall(GetTimeStamp, 0)) or 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(clean(value))
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local sign = n < 0 and "-" or ""
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return sign .. digits
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function firstResult(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

-- TTC price rows may represent the same market item with item-link fields that are
-- not byte-for-byte identical. Build a stable market identity from public APIs.
local function canonicalItemKey(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then return nil end

    local itemId = safeNumber(firstResult(GetItemLinkItemId, itemLink))
    if not itemId or itemId <= 0 then
        local payload = itemLink:match("|H%d+:item:([^|]+)|h")
        return payload and ("raw:" .. payload) or ("raw:" .. itemLink)
    end

    local itemType, specializedItemType = 0, 0
    if type(GetItemLinkItemType) == "function" then
        local ok, a, b = pcall(GetItemLinkItemType, itemLink)
        if ok then
            itemType = safeNumber(a) or 0
            specializedItemType = safeNumber(b) or 0
        end
    end

    if rawget(_G, "ITEMTYPE_MASTER_WRIT") ~= nil and itemType == ITEMTYPE_MASTER_WRIT then
        local payload = itemLink:match("|H%d+:item:([^|]+)|h")
        return payload and ("writ:" .. payload) or ("writ:" .. itemLink)
    end

    local quality = safeNumber(firstResult(GetItemLinkQuality, itemLink)) or 0
    local reqLevel = safeNumber(firstResult(GetItemLinkRequiredLevel, itemLink)) or 0
    local reqCP = safeNumber(firstResult(GetItemLinkRequiredChampionPoints, itemLink)) or 0
    local traitType = safeNumber(firstResult(GetItemLinkTraitInfo, itemLink)) or 0
    local style = safeNumber(firstResult(GetItemLinkItemStyle, itemLink)) or 0
    local equipType = safeNumber(firstResult(GetItemLinkEquipType, itemLink)) or 0
    local armorType = safeNumber(firstResult(GetItemLinkArmorType, itemLink)) or 0
    local weaponType = safeNumber(firstResult(GetItemLinkWeaponType, itemLink)) or 0
    local name = lower(safeCall(GetItemLinkName, "", itemLink))

    local setName = ""
    if type(GetItemLinkSetInfo) == "function" then
        local ok, isSet, value = pcall(GetItemLinkSetInfo, itemLink)
        if ok and isSet then setName = lower(value) end
    end

    return table.concat({
        "v2", tostring(math.floor(itemId)), tostring(math.floor(itemType)),
        tostring(math.floor(specializedItemType)), tostring(math.floor(quality)),
        tostring(math.floor(reqLevel)), tostring(math.floor(reqCP)), tostring(math.floor(traitType)),
        tostring(math.floor(style)), tostring(math.floor(equipType)), tostring(math.floor(armorType)),
        tostring(math.floor(weaponType)), name, setName,
    }, ":")
end

function M:GetMarketItemKey029683(itemLink)
    return canonicalItemKey(itemLink)
end

local function cacheRoot()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketPriceTraderCacheV2029683) ~= "table" then
        EPC.saved.marketPriceTraderCacheV2029683 = {}
    end
    return EPC.saved.marketPriceTraderCacheV2029683
end

local function traderIdentity(record)
    if type(record) ~= "table" then return nil end
    local kioskId = safeNumber(record.kioskId)
    local guild = lower(record.guildName)
    local trader = lower(record.traderName)
    local location = lower(record.locationName)
    local zone = lower(record.zoneName)
    if kioskId then return "k:" .. tostring(math.floor(kioskId)) .. "|g:" .. guild end
    if guild ~= "" then return "g:" .. guild .. "|l:" .. location .. "|z:" .. zone end
    if trader ~= "" then return "t:" .. trader .. "|l:" .. location .. "|z:" .. zone end
    if location ~= "" or zone ~= "" then return "l:" .. location .. "|z:" .. zone end
    return nil
end

local function recordExpired(record, currentTime)
    if type(record) ~= "table" then return true end
    currentTime = currentTime or now()
    local expireAt = safeNumber(record.expireAt)
    if expireAt and expireAt > 0 and expireAt <= currentTime then return true end
    local seenAt = safeNumber(record.seenAt)
    if seenAt and seenAt > 0 and currentTime - seenAt > MAX_CACHE_AGE then return true end
    return false
end

local function trimGroup(group)
    if type(group) ~= "table" or type(group.traders) ~= "table" then return end
    local currentTime = now()
    local rows = {}
    for id, record in pairs(group.traders) do
        if recordExpired(record, currentTime) then
            group.traders[id] = nil
        else
            rows[#rows + 1] = { id = id, record = record }
        end
    end
    table.sort(rows, function(a, b)
        local ap = safeNumber(a.record.unitPrice) or math.huge
        local bp = safeNumber(b.record.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.record.seenAt) or 0) > (safeNumber(b.record.seenAt) or 0)
    end)
    for i = MAX_TRADERS_PER_ITEM + 1, #rows do group.traders[rows[i].id] = nil end
end

-- This replaces the raw-link cache writer added by the earlier multi-trader fix.
-- All existing callers dispatch through this method, including live searches and
-- TTC AutoRecordEntries import.
StorePersistentTraderListing029683ImplArch = function(self, record)
    if type(record) ~= "table" or type(record.itemLink) ~= "string" or record.itemLink == "" then return false end
    local key = canonicalItemKey(record.itemLink)
    local identity = traderIdentity(record)
    local unitPrice = safeNumber(record.unitPrice)
    if not key or not identity or not unitPrice or unitPrice <= 0 then return false end
    local currentTime = now()
    if recordExpired(record, currentTime) then return false end

    local root = cacheRoot()
    local group = root[key]
    if type(group) ~= "table" then
        group = { lastSeen = 0, traders = {} }
        root[key] = group
    end
    group.traders = type(group.traders) == "table" and group.traders or {}

    local seenAt = safeNumber(record.seenAt) or currentTime
    local old = group.traders[identity]
    local replace = old == nil or recordExpired(old, currentTime)
    if old and not replace then
        local oldSeen = safeNumber(old.seenAt) or 0
        local oldPrice = safeNumber(old.unitPrice) or math.huge
        replace = seenAt > oldSeen or (seenAt == oldSeen and unitPrice < oldPrice)
    end

    if replace then
        group.traders[identity] = {
            itemLink = record.itemLink,
            unitPrice = unitPrice,
            totalPrice = safeNumber(record.totalPrice),
            amount = math.max(1, safeNumber(record.amount) or 1),
            sellerName = clean(record.sellerName),
            guildName = clean(record.guildName),
            guildId = safeNumber(record.guildId),
            kioskId = safeNumber(record.kioskId),
            traderName = clean(record.traderName),
            locationName = clean(record.locationName),
            zoneName = clean(record.zoneName),
            seenAt = seenAt,
            expireAt = safeNumber(record.expireAt),
            source = clean(record.source ~= "" and record.source or "SUITE CACHE"),
        }
    end

    group.lastSeen = math.max(safeNumber(group.lastSeen) or 0, seenAt)
    trimGroup(group)
    return true
end

local function getCurrentTraderContext()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then guildId, guildName = safeNumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, id = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(id) end
    end

    local traderName = ""
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "interact")
        if ok then traderName = clean(value) end
    end

    local locationName = ""
    if type(GetPlayerLocationName) == "function" then
        local ok, value = pcall(GetPlayerLocationName)
        if ok then locationName = clean(value) end
    end

    local zoneName = ""
    if type(GetPlayerActiveZoneName) == "function" then
        local ok, value = pcall(GetPlayerActiveZoneName)
        if ok then zoneName = clean(value) end
    end

    return guildId, guildName, kioskId, traderName, locationName, zoneName
end

local function findCurrentResultForItem(expectedItemLink)
    if type(GetTradingHouseSearchResultsInfo) ~= "function" or type(GetTradingHouseSearchResultItemLink) ~= "function" or type(GetTradingHouseSearchResultItemInfo) ~= "function" then return nil end
    local expectedKey = canonicalItemKey(expectedItemLink)
    if not expectedKey then return nil end

    local okCount, count = pcall(GetTradingHouseSearchResultsInfo)
    count = okCount and safeNumber(count) or 0
    if not count or count <= 0 then return nil end

    local best = nil
    for i = 1, count do
        local okLink, link = pcall(GetTradingHouseSearchResultItemLink, i)
        if okLink and type(link) == "string" and link ~= "" and canonicalItemKey(link) == expectedKey then
            local okInfo, _, _, _, stackCount, sellerName, timeRemaining, totalPrice, _, uniqueId, unitPrice = pcall(GetTradingHouseSearchResultItemInfo, i)
            if okInfo then
                stackCount = math.max(1, safeNumber(stackCount) or 1)
                totalPrice = safeNumber(totalPrice) or 0
                unitPrice = safeNumber(unitPrice) or (totalPrice > 0 and totalPrice / stackCount or nil)
                if unitPrice and unitPrice > 0 and (not best or unitPrice < best.unitPrice) then
                    best = {
                        rowIndex = i,
                        itemLink = link,
                        unitPrice = unitPrice,
                        totalPrice = totalPrice,
                        amount = stackCount,
                        sellerName = clean(sellerName),
                        timeRemaining = safeNumber(timeRemaining) or 0,
                        itemUniqueId = uniqueId,
                        source = "LIVE",
                    }
                end
            end
        end
    end
    return best
end

function M:CaptureCurrentTraderForTooltip029683(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then return nil end
    local row = nil
    if type(self.GetHoveredTraderRow029683) == "function" then
        local ok, value = pcall(self.GetHoveredTraderRow029683, self, itemLink)
        if ok and type(value) == "table" then row = value end
    end
    if not row then row = findCurrentResultForItem(itemLink) end
    if not row then return nil end

    local guildId, guildName, kioskId, traderName, locationName, zoneName = getCurrentTraderContext()
    local seenAt = now()
    row.guildId = guildId
    row.guildName = guildName
    row.kioskId = kioskId
    row.traderName = traderName
    row.locationName = locationName
    row.zoneName = zoneName
    row.seenAt = seenAt
    row.expireAt = seenAt + math.max(0, safeNumber(row.timeRemaining) or 0)
    row.source = "LIVE"

    if type(self.PutLocatedListing029683) == "function" then
        self:PutLocatedListing029683(row)
    else
        self:StorePersistentTraderListing029683(row)
    end
    return row
end

GetComparableTraderListings029683ImplArch = function(self, itemLink, limit)
    local key = canonicalItemKey(itemLink)
    if not key then return {} end
    local group = cacheRoot()[key]
    if type(group) ~= "table" or type(group.traders) ~= "table" then return {} end
    trimGroup(group)

    local _, currentGuild, currentKiosk = getCurrentTraderContext()
    local currentGuildLower = lower(currentGuild)
    local rows = {}
    local currentTime = now()
    for _, record in pairs(group.traders) do
        if type(record) == "table" and not recordExpired(record, currentTime) then
            local recordKiosk = safeNumber(record.kioskId)
            local recordGuild = lower(record.guildName)
            local isCurrent = false
            if currentKiosk and recordKiosk and math.floor(currentKiosk) == math.floor(recordKiosk) then
                if currentGuildLower == "" or recordGuild == "" or currentGuildLower == recordGuild then isCurrent = true end
            elseif currentGuildLower ~= "" and recordGuild ~= "" and currentGuildLower == recordGuild then
                isCurrent = true
            end
            record._easCurrentTrader = isCurrent
            rows[#rows + 1] = record
        end
    end

    table.sort(rows, function(a, b)
        local ap = safeNumber(a.unitPrice) or math.huge
        local bp = safeNumber(b.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.seenAt) or 0) > (safeNumber(b.seenAt) or 0)
    end)

    limit = math.max(1, math.min(MAX_TRADERS_PER_ITEM, math.floor(safeNumber(limit) or 5)))
    while #rows > limit do table.remove(rows) end
    return rows
end

GetBestTravelTrader029683ImplArch = function(self, itemLink)
    local rows = self:GetComparableTraderListings029683(itemLink, MAX_TRADERS_PER_ITEM)
    for _, record in ipairs(rows) do
        if not record._easCurrentTrader and self:GetLocationInfo029683(record) then return record end
    end
    return nil
end

local function addLine(tooltip, text)
    if tooltip and type(tooltip.AddLine) == "function" then pcall(tooltip.AddLine, tooltip, text) end
end

local function addMarketSource(tooltip, market, label)
    if type(market) ~= "table" then return end
    local ts = safeNumber(market.timestamp) or 0
    local ageText = ts > 0 and (formatAge(math.max(0, now() - ts)) .. " old") or "age unknown"
    addLine(tooltip, CYAN .. label .. ": " .. tostring(market.source or "market") .. RESET .. GREY .. "  " .. ageText .. RESET)

    local bits = {}
    if safeNumber(market.min) then bits[#bits + 1] = "Global low " .. GOLD .. formatNumber(market.min) .. "g" .. RESET .. GREY .. " (location unknown)" .. RESET end
    if safeNumber(market.avg) then bits[#bits + 1] = "Avg " .. formatNumber(market.avg) .. "g" end
    if safeNumber(market.listings) then bits[#bits + 1] = formatNumber(market.listings) .. " listings" end
    if #bits > 0 then addLine(tooltip, table.concat(bits, "   ")) end

    local lo, hi = safeNumber(market.suggestedMin), safeNumber(market.suggestedMax)
    if lo or hi then
        lo, hi = lo or hi, hi or lo
        local suggested = lo and hi and lo ~= hi and (formatNumber(lo) .. "-" .. formatNumber(hi) .. "g") or (formatNumber(lo or hi) .. "g")
        local line = "Suggested " .. suggested
        if safeNumber(market.saleAvg) then line = line .. "   Recent sale avg " .. formatNumber(market.saleAvg) .. "g" end
        addLine(tooltip, line)
    elseif safeNumber(market.saleAvg) then
        addLine(tooltip, "Recent sale avg " .. formatNumber(market.saleAvg) .. "g")
    end
end

-- This is the authoritative market tooltip renderer. It intentionally does not
-- call the older renderer, which could visually associate aggregate global-low
-- pricing with a locally observed trader even though ESO-Hub/TTC aggregate data
-- does not identify that global-low kiosk.
AppendMarketTooltip029683ImplArch = function(self, tooltip, itemLink)
    local saved = EPC.saved or {}
    if saved.marketPriceCheckerEnabled029683 == false or saved.marketPriceTooltipEnabled029683 == false then
        self:HideTravelButton029683()
        return
    end
    if not tooltip or type(tooltip.AddLine) ~= "function" or type(itemLink) ~= "string" or itemLink == "" then
        self:HideTravelButton029683()
        return
    end

    local captured = self:CaptureCurrentTraderForTooltip029683(itemLink)

    local primary, cross = nil, nil
    if type(self.GetMarketSources029683) == "function" then
        primary, cross = self:GetMarketSources029683(itemLink)
    else
        primary = self:GetMarketData029683(itemLink)
    end

    local rows = self:GetComparableTraderListings029683(itemLink, MAX_TRADERS_PER_ITEM)
    if not primary and not cross and #rows == 0 and not captured then
        self:HideTravelButton029683()
        return
    end

    if type(tooltip.AddVerticalPadding) == "function" then pcall(tooltip.AddVerticalPadding, tooltip, 5) end
    if type(ZO_Tooltip_AddDivider) == "function" then pcall(ZO_Tooltip_AddDivider, tooltip) end
    addLine(tooltip, GOLD .. "ESO ADVENTURER SUITE MARKET" .. RESET)

    if primary then addMarketSource(tooltip, primary, "Aggregate reference") end
    if cross then addMarketSource(tooltip, cross, "Cross-check") end
    if primary or cross then
        addLine(tooltip, GREY .. "Aggregate sources provide market prices, not the guild/kiosk owning their global-low listing." .. RESET)
    end

    if captured then
        local line = WHITE .. "CURRENT LISTING  " .. GOLD .. formatNumber(captured.unitPrice) .. "g/unit" .. RESET
        if safeNumber(captured.amount) and captured.amount > 1 then
            line = line .. GREY .. "  x" .. tostring(math.floor(captured.amount)) .. " = " .. formatNumber(captured.totalPrice) .. "g" .. RESET
        end
        addLine(tooltip, line)
        local dealText, dealColor = self:GetDealLabel029683(captured, primary)
        if dealText then addLine(tooltip, (dealColor or WHITE) .. dealText .. RESET) end
    end

    local others = 0
    for _, record in ipairs(rows) do if not record._easCurrentTrader then others = others + 1 end end
    addLine(tooltip, CYAN .. "VERIFIED LOCATED TRADERS" .. RESET .. GREY .. "  " .. tostring(#rows) .. " known / " .. tostring(others) .. " other" .. RESET)

    if #rows > 0 then
        local displayCount = math.min(5, #rows)
        for i = 1, displayCount do
            local record = rows[i]
            local location = self:GetLocationInfo029683(record)
            local guild = clean(record.guildName)
            local where = location and clean(location.label) or clean(record.locationName)
            local seenAt = safeNumber(record.seenAt) or 0
            local age = seenAt > 0 and formatAge(math.max(0, now() - seenAt)) or "unknown"
            local marker = record._easCurrentTrader and (GREEN .. "CURRENT" .. RESET) or (WHITE .. "OTHER" .. RESET)
            local cheapest = (i == 1) and (GOLD .. "  CHEAPEST LOCATED" .. RESET) or ""
            local line = tostring(i) .. ". " .. GOLD .. formatNumber(record.unitPrice) .. "g" .. RESET .. "  " .. marker .. cheapest
            if guild ~= "" then line = line .. "  " .. CYAN .. guild .. RESET end
            if where ~= "" then line = line .. "  " .. WHITE .. where .. RESET end
            line = line .. GREY .. "  seen " .. age .. " ago" .. RESET
            addLine(tooltip, line)
        end
    end

    if others == 0 then
        addLine(tooltip, YELLOW .. "No other verified trader is located yet; the aggregate global-low trader cannot be inferred." .. RESET)
        addLine(tooltip, GREY .. "Search the same item at another Guild Trader, or import a TTC observation that includes a kiosk, to create a real comparison." .. RESET)
    end

    local travelRecord = self:GetBestTravelTrader029683(itemLink)
    self:UpdateTravelButton029683(tooltip, travelRecord)
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easmarketdebug"] = function()
    if not EPC.MarketPriceChecker then return end
    local link = EPC.MarketPriceChecker.lastTooltipLink or EPC.MarketPriceChecker:GetHoveredItemLink029683()
    if not link then
        if type(EPC.Print) == "function" then EPC:Print("Hover an item, then use /easmarketdebug.") end
        return
    end
    local rows = EPC.MarketPriceChecker:GetComparableTraderListings029683(link, MAX_TRADERS_PER_ITEM)
    local others = 0
    for _, row in ipairs(rows) do if not row._easCurrentTrader then others = others + 1 end end
    local primary = EPC.MarketPriceChecker.GetMarketSources029683 and EPC.MarketPriceChecker:GetMarketSources029683(link) or EPC.MarketPriceChecker:GetMarketData029683(link)
    local aggregate = primary and safeNumber(primary.min) and (formatNumber(primary.min) .. "g") or "none"
    if type(EPC.Print) == "function" then
        EPC:Print("Market debug: aggregate low " .. aggregate .. " (location unknown); " .. tostring(#rows) .. " verified located trader(s), " .. tostring(others) .. " other trader(s).")
    end
end

-- Rebuild the corrected cache from TTC's currently available observed-kiosk data.
if type(zo_callLater) == "function" then
    zo_callLater(function()
        if EPC.MarketPriceChecker and type(EPC.MarketPriceChecker.ImportTTCTraderHistory029683) == "function" then
            EPC.MarketPriceChecker.ttcPersistentImportReady = false
            EPC.MarketPriceChecker:ImportTTCTraderHistory029683(true)
            EPC.MarketPriceChecker.lastTooltipSignature = nil
        end
    end, 4700)
end

EPC.marketPriceLiveTraderCapture029683 = true
EPC.marketPriceVerifiedComparison029683 = true

-- END ABSORBED: MarketPriceLiveTraderCaptureFix.lua

-- BEGIN ABSORBED: MarketPriceContextMenuFix.lua
-- ESO Adventurer Suite
-- Market Price Checker right-click UX.
-- Adds a durable Guild Trader context-menu travel action and a persistent,
-- opaque market-details panel so travel/details do not depend on mouse hover.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketPriceContextMenu029685 then return end
M._marketPriceContextMenu029685 = true

local GOLD = "|cFFD700"
local WHITE = "|cFFFFFF"
local GREY = "|cA0A0A0"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local RESET = "|r"
local MAX_ROWS = 5

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return (n < 0 and "-" or "") .. digits
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function now()
    if type(GetTimeStamp) ~= "function" then return 0 end
    local ok, value = pcall(GetTimeStamp)
    return ok and (safeNumber(value) or 0) or 0
end

local function currentTraderContext()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then guildId, guildName = safeNumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, value = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(value) end
    end

    local traderName, locationName, zoneName = "", "", ""
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "interact")
        if ok then traderName = clean(value) end
    end
    if type(GetPlayerLocationName) == "function" then
        local ok, value = pcall(GetPlayerLocationName)
        if ok then locationName = clean(value) end
    end
    if type(GetPlayerActiveZoneName) == "function" then
        local ok, value = pcall(GetPlayerActiveZoneName)
        if ok then zoneName = clean(value) end
    end
    return guildId, guildName, kioskId, traderName, locationName, zoneName
end

local function searchResultIndex(searchResultSlot)
    if not searchResultSlot then return nil end

    if type(ZO_InventorySlot_GetInventorySlotComponents) == "function" and type(ZO_Inventory_GetSlotIndex) == "function" then
        local okSlot, inventorySlot = pcall(ZO_InventorySlot_GetInventorySlotComponents, searchResultSlot)
        if okSlot and inventorySlot then
            local okIndex, index = pcall(ZO_Inventory_GetSlotIndex, inventorySlot)
            index = okIndex and safeNumber(index) or nil
            if index and index > 0 then return math.floor(index) end
        end
    end

    local dataEntry = searchResultSlot.dataEntry
    local data = type(dataEntry) == "table" and dataEntry.data or searchResultSlot.data
    if type(data) == "table" then
        local candidates = { data.slotIndex, data.index, data.searchResultIndex, data.tradingHouseIndex }
        for i = 1, #candidates do
            local value = safeNumber(candidates[i])
            if value and value > 0 then return math.floor(value) end
        end
    end
    return nil
end

function M:CaptureClickedTraderListing029685(searchResultSlot)
    local index = searchResultIndex(searchResultSlot)
    if not index or type(GetTradingHouseSearchResultItemLink) ~= "function" or type(GetTradingHouseSearchResultItemInfo) ~= "function" then return nil, nil end

    local okLink, itemLink = pcall(GetTradingHouseSearchResultItemLink, index)
    if not okLink or type(itemLink) ~= "string" or itemLink == "" then return nil, nil end

    local okInfo, _, _, _, stackCount, sellerName, timeRemaining, totalPrice, _, uniqueId, unitPrice = pcall(GetTradingHouseSearchResultItemInfo, index)
    if not okInfo then return itemLink, nil end

    stackCount = math.max(1, safeNumber(stackCount) or 1)
    totalPrice = safeNumber(totalPrice) or 0
    unitPrice = safeNumber(unitPrice) or (totalPrice > 0 and totalPrice / stackCount or nil)
    if not unitPrice or unitPrice <= 0 then return itemLink, nil end

    local guildId, guildName, kioskId, traderName, locationName, zoneName = currentTraderContext()
    local seenAt = now()
    local record = {
        rowIndex = index,
        itemLink = itemLink,
        unitPrice = unitPrice,
        totalPrice = totalPrice,
        amount = stackCount,
        sellerName = clean(sellerName),
        timeRemaining = safeNumber(timeRemaining) or 0,
        itemUniqueId = uniqueId,
        guildId = guildId,
        guildName = guildName,
        kioskId = kioskId,
        traderName = traderName,
        locationName = locationName,
        zoneName = zoneName,
        seenAt = seenAt,
        expireAt = seenAt + math.max(0, safeNumber(timeRemaining) or 0),
        source = "LIVE RIGHT-CLICK",
    }

    if type(self.PutLocatedListing029683) == "function" then
        self:PutLocatedListing029683(record)
    elseif type(self.StorePersistentTraderListing029683) == "function" then
        self:StorePersistentTraderListing029683(record)
    end
    return itemLink, record
end

local function ensurePanel()
    if M.marketContextPanel029685 then return M.marketContextPanel029685 end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local panel = WINDOW_MANAGER:CreateControl("EASMarketContextPanel029685", GuiRoot, CT_CONTROL)
    panel:SetDimensions(620, 430)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    panel:SetMouseEnabled(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    if type(panel.SetDrawTier) == "function" and DT_HIGH ~= nil then panel:SetDrawTier(DT_HIGH) end
    if type(panel.SetDrawLayer) == "function" and DL_OVERLAY ~= nil then panel:SetDrawLayer(DL_OVERLAY) end
    if type(panel.SetDrawLevel) == "function" then panel:SetDrawLevel(12050) end

    local bg = WINDOW_MANAGER:CreateControl("EASMarketContextPanelBG029685", panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.015, 0.015, 0.02, 0.985)
    bg:SetEdgeColor(0.86, 0.66, 0.12, 1)
    bg:SetMouseEnabled(false)

    local title = WINDOW_MANAGER:CreateControl("EASMarketContextPanelTitle029685", panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 18, 14)
    title:SetFont("ZoFontWinH2")
    title:SetColor(1, 0.82, 0.2, 1)
    title:SetText("ESO ADVENTURER SUITE MARKET")

    local close = WINDOW_MANAGER:CreateControl("EASMarketContextPanelClose029685", panel, CT_BUTTON)
    close:SetDimensions(34, 28)
    close:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -10, 10)
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetHandler("OnClicked", function() panel:SetHidden(true) end)

    local content = WINDOW_MANAGER:CreateControl("EASMarketContextPanelContent029685", panel, CT_LABEL)
    content:SetAnchor(TOPLEFT, panel, TOPLEFT, 18, 54)
    content:SetDimensions(584, 300)
    content:SetFont("ZoFontGame")
    content:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    content:SetVerticalAlignment(TEXT_ALIGN_TOP)
    content:SetColor(1, 1, 1, 1)

    local travel = WINDOW_MANAGER:CreateControl("EASMarketContextPanelTravel029685", panel, CT_BUTTON)
    travel:SetDimensions(430, 38)
    travel:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 18, -18)
    travel:SetFont("ZoFontGameBold")
    travel:SetText("TRAVEL TO CHEAPEST LOCATED TRADER")
    travel:SetHandler("OnClicked", function()
        local record = panel.travelRecord
        if not record then return end
        M.activeLocatedListing = record
        M:TravelToActiveListing029683()
    end)

    local hint = WINDOW_MANAGER:CreateControl("EASMarketContextPanelHint029685", panel, CT_LABEL)
    hint:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -18, -27)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.68, 0.68, 0.68, 1)
    hint:SetText("Drag panel to move")

    panel.bg, panel.title, panel.close, panel.content, panel.travel, panel.hint = bg, title, close, content, travel, hint
    panel:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and type(control.StartMoving) == "function" then control:StartMoving() end
    end)
    panel:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and type(control.StopMovingOrResizing) == "function" then control:StopMovingOrResizing() end
    end)
    panel:SetHidden(true)
    M.marketContextPanel029685 = panel
    return panel
end

local ShowMarketContextPanel029685ImplArch

function M:ShowMarketContextPanel029685(...)
    return ShowMarketContextPanel029685ImplArch(self, ...)
end

ShowMarketContextPanel029685ImplArch = function(self, itemLink, clickedRecord)
    if type(itemLink) ~= "string" or itemLink == "" then return end
    local panel = ensurePanel()
    if not panel then return end

    local primary, cross = nil, nil
    if type(self.GetMarketSources029683) == "function" then
        primary, cross = self:GetMarketSources029683(itemLink)
    elseif type(self.GetMarketData029683) == "function" then
        primary = self:GetMarketData029683(itemLink)
    end
    local rows = type(self.GetComparableTraderListings029683) == "function" and self:GetComparableTraderListings029683(itemLink, 12) or {}
    local travelRecord = type(self.GetBestTravelTrader029683) == "function" and self:GetBestTravelTrader029683(itemLink) or nil

    local itemName = type(GetItemLinkName) == "function" and clean(GetItemLinkName(itemLink)) or "Item"
    local lines = { GOLD .. itemName .. RESET }

    local function sourceLine(label, market)
        if type(market) ~= "table" then return end
        local bits = { CYAN .. label .. RESET }
        if safeNumber(market.min) then bits[#bits + 1] = "Global low " .. GOLD .. formatNumber(market.min) .. "g" .. RESET .. GREY .. " (location unknown)" .. RESET end
        if safeNumber(market.avg) then bits[#bits + 1] = "Avg " .. formatNumber(market.avg) .. "g" end
        if safeNumber(market.listings) then bits[#bits + 1] = formatNumber(market.listings) .. " listings" end
        local stamp = safeNumber(market.timestamp) or 0
        if stamp > 0 then bits[#bits + 1] = GREY .. formatAge(math.max(0, now() - stamp)) .. " old" .. RESET end
        lines[#lines + 1] = table.concat(bits, "   ")
    end

    sourceLine("Aggregate", primary)
    sourceLine("Cross-check", cross)

    if clickedRecord then
        local line = WHITE .. "RIGHT-CLICKED LISTING  " .. GOLD .. formatNumber(clickedRecord.unitPrice) .. "g/unit" .. RESET
        if safeNumber(clickedRecord.amount) and clickedRecord.amount > 1 then
            line = line .. GREY .. "  x" .. tostring(math.floor(clickedRecord.amount)) .. " = " .. formatNumber(clickedRecord.totalPrice) .. "g" .. RESET
        end
        lines[#lines + 1] = line
    end

    local others = 0
    for _, row in ipairs(rows) do if not row._easCurrentTrader then others = others + 1 end end
    lines[#lines + 1] = CYAN .. "VERIFIED LOCATED TRADERS" .. RESET .. GREY .. "  " .. tostring(#rows) .. " known / " .. tostring(others) .. " other" .. RESET

    if #rows == 0 then
        lines[#lines + 1] = YELLOW .. "No verified trader locations are cached for this item yet." .. RESET
    else
        for i = 1, math.min(MAX_ROWS, #rows) do
            local row = rows[i]
            local location = type(self.GetLocationInfo029683) == "function" and self:GetLocationInfo029683(row) or nil
            local where = location and clean(location.label) or clean(row.locationName)
            local guild = clean(row.guildName)
            local marker = row._easCurrentTrader and (GREEN .. "CURRENT" .. RESET) or (WHITE .. "OTHER" .. RESET)
            local line = tostring(i) .. ". " .. GOLD .. formatNumber(row.unitPrice) .. "g" .. RESET .. "  " .. marker
            if guild ~= "" then line = line .. "  " .. CYAN .. guild .. RESET end
            if where ~= "" then line = line .. "  " .. WHITE .. where .. RESET end
            lines[#lines + 1] = line
        end
    end

    if others == 0 then
        lines[#lines + 1] = GREY .. "Aggregate ESO-Hub/TTC pricing cannot identify the guild trader that owns its global-low price." .. RESET
    end

    panel.content:SetText(table.concat(lines, "\n"))
    panel.travelRecord = travelRecord
    if travelRecord then
        local location = self:GetLocationInfo029683(travelRecord)
        local label = location and clean(location.label) or "LOCATED TRADER"
        panel.travel:SetText("TRAVEL TO: " .. label .. " — " .. formatNumber(travelRecord.unitPrice) .. "g")
        panel.travel:SetEnabled(true)
        panel.travel:SetAlpha(1)
    else
        panel.travel:SetText("NO OTHER VERIFIED TRADER LOCATION AVAILABLE")
        panel.travel:SetEnabled(false)
        panel.travel:SetAlpha(0.55)
    end

    if type(self.HideTravelButton029683) == "function" then self:HideTravelButton029683() end
    panel:SetHidden(false)
end

local EnsureMarketTooltipShade029685ImplArch

function M:EnsureMarketTooltipShade029685(...)
    return EnsureMarketTooltipShade029685ImplArch(self, ...)
end

EnsureMarketTooltipShade029685ImplArch = function(self, tooltip)
    if not tooltip or not WINDOW_MANAGER then return nil end
    if tooltip._easMarketShade029685 then
        tooltip._easMarketShade029685:SetHidden(false)
        return tooltip._easMarketShade029685
    end
    local shade = WINDOW_MANAGER:CreateControl(nil, tooltip, CT_BACKDROP)
    shade:SetAnchorFill(tooltip)
    shade:SetCenterColor(0.01, 0.01, 0.015, 0.965)
    shade:SetEdgeColor(0.35, 0.28, 0.08, 0.95)
    shade:SetMouseEnabled(false)
    if type(shade.SetDrawLayer) == "function" and DL_BACKGROUND ~= nil then shade:SetDrawLayer(DL_BACKGROUND) end
    tooltip._easMarketShade029685 = shade
    local oldHide = tooltip:GetHandler("OnHide")
    tooltip:SetHandler("OnHide", function(control)
        if oldHide then pcall(oldHide, control) end
        if control._easMarketShade029685 then control._easMarketShade029685:SetHidden(true) end
    end)
    return shade
end

local baseAppendMarketTooltip029683 = AppendMarketTooltip029683ImplArch
AppendMarketTooltip029683ImplArch = function(self, tooltip, itemLink)
    baseAppendMarketTooltip029683(self, tooltip, itemLink)
    local primary, cross = nil, nil
    if type(itemLink) == "string" and itemLink ~= "" then
        if type(self.GetMarketSources029683) == "function" then
            primary, cross = self:GetMarketSources029683(itemLink)
        elseif type(self.GetMarketData029683) == "function" then
            primary = self:GetMarketData029683(itemLink)
        end
    end
    local rows = type(self.GetComparableTraderListings029683) == "function" and self:GetComparableTraderListings029683(itemLink, 1) or {}
    if primary or cross or #rows > 0 then self:EnsureMarketTooltipShade029685(tooltip) end
end

function M:OpenTraderRightClickMenu029685(searchResultSlot, button)
    if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
    local saved = EPC.saved or {}
    if saved.marketPriceCheckerEnabled029683 == false then return end

    local itemLink, clickedRecord = self:CaptureClickedTraderListing029685(searchResultSlot)
    if not itemLink then return end
    local travelRecord = self:GetBestTravelTrader029683(itemLink)

    if type(AddCustomMenuItem) ~= "function" or type(ShowMenu) ~= "function" then
        if EPC.Print then EPC:Print("LibCustomMenu is required for the Market right-click actions.") end
        return
    end

    AddCustomMenuItem("ESO ADVENTURER SUITE — OPEN MARKET DETAILS", function()
        M:ShowMarketContextPanel029685(itemLink, clickedRecord)
    end, MENU_ADD_OPTION_LABEL)

    if travelRecord and saved.marketPriceTravelEnabled029683 ~= false then
        local location = self:GetLocationInfo029683(travelRecord)
        local where = location and clean(location.label) or "Located Trader"
        local text = "TRAVEL TO " .. string.upper(where) .. " — " .. formatNumber(travelRecord.unitPrice) .. "g"
        AddCustomMenuItem(text, function()
            M.activeLocatedListing = travelRecord
            M:TravelToActiveListing029683()
        end, MENU_ADD_OPTION_LABEL)
    else
        AddCustomMenuItem("TRAVEL — NO OTHER VERIFIED TRADER LOCATION", function()
            if EPC.Print then EPC:Print("No other verified trader location is available for this item yet. Aggregate global-low pricing does not include a kiosk location.") end
        end, MENU_ADD_OPTION_LABEL)
    end

    ShowMenu(searchResultSlot)
end

if type(SecurePostHook) == "function" and type(rawget(_G, "ZO_TradingHouse_OnSearchResultClicked")) == "function" then
    SecurePostHook("ZO_TradingHouse_OnSearchResultClicked", function(searchResultSlot, button)
        if EPC.MarketPriceChecker then EPC.MarketPriceChecker:OpenTraderRightClickMenu029685(searchResultSlot, button) end
    end)
end

EPC.marketPriceContextMenu029685 = true

-- END ABSORBED: MarketPriceContextMenuFix.lua

-- BEGIN ABSORBED: MarketPriceAnchorSafetyFix.lua
-- ESO Adventurer Suite
-- Market Price Checker anchor safety.
-- The live ESO ItemTooltip must never own, size against, or be the relative anchor
-- for Suite-created controls. Interactive market actions live in the right-click
-- menu and persistent Market Details panel instead.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketPriceAnchorSafety029686 then return end
M._marketPriceAnchorSafety029686 = true

local function detachControl(control)
    if not control then return end
    if type(control.ClearAnchors) == "function" then pcall(control.ClearAnchors, control) end
    if type(control.SetHidden) == "function" then pcall(control.SetHidden, control, true) end
end

local function detachLegacyTooltipControls()
    local button = M.travelButton or rawget(_G, "EASMarketTravelButton029683")
    if button then
        local backdrop = button._easMarketBackdrop or rawget(_G, "EASMarketTravelButtonBackdrop029683")
        detachControl(backdrop)
        detachControl(button)
    end

    local tooltips = {
        rawget(_G, "ItemTooltip"),
        rawget(_G, "PopupTooltip"),
        rawget(_G, "InformationTooltip"),
    }
    for i = 1, #tooltips do
        local tooltip = tooltips[i]
        if tooltip and tooltip._easMarketShade029685 then
            detachControl(tooltip._easMarketShade029685)
            tooltip._easMarketShade029685 = nil
        end
    end
end

-- Override the original hide helper so any legacy hover button left alive in the
-- current UI session is detached, not merely hidden while retaining its anchor.
HideTravelButton029683ImplArch = function(self)
    detachLegacyTooltipControls()
    self.activeLocatedListing = nil
end

-- Hover tooltips are text-only from this point forward. Travel remains available
-- through the Guild Trader right-click menu and persistent Market Details panel.
UpdateTravelButton029683ImplArch = function(self, tooltip, record)
    detachLegacyTooltipControls()
end

-- v0.29.685 added a nearly opaque backdrop as a tooltip child for readability.
-- ESO's ItemTooltip has native background/munge controls and dynamic sizing; adding
-- another anchored child can participate in the same anchor traversal. Disable it.
EnsureMarketTooltipShade029685ImplArch = function(self, tooltip)
    if tooltip and tooltip._easMarketShade029685 then
        detachControl(tooltip._easMarketShade029685)
        tooltip._easMarketShade029685 = nil
    end
    return nil
end

-- Detach immediately in case another market file created controls earlier during
-- this same UI load. No OnUpdate or polling is needed.
detachLegacyTooltipControls()

EPC.marketPriceAnchorSafety029686 = true

-- END ABSORBED: MarketPriceAnchorSafetyFix.lua

-- BEGIN ABSORBED: MarketPriceLiveEngineSafetyFix.lua
-- ESO Adventurer Suite
-- v0.29.687+ Live Market safety pass.
-- Makes a completed TTC full-store scan authoritative for that trader and also
-- bounds the older market caches that existed before the Live Market engine.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketLiveSafety029687 then return end
M._marketLiveSafety029687 = true

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function now()
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok then return safeNumber(value) or 0 end
    end
    return 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(clean(value))
end

local function currentContext()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then guildId, guildName = safeNumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, id = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(id) end
    end
    return { guildId = guildId, guildName = guildName, kioskId = kioskId }
end

local function sameTrader(record, ctx)
    if type(record) ~= "table" or type(ctx) ~= "table" then return false end
    local recordKiosk = safeNumber(record.kioskId)
    local ctxKiosk = safeNumber(ctx.kioskId)
    local recordGuild = lower(record.guildName)
    local ctxGuild = lower(ctx.guildName)

    if ctxKiosk and recordKiosk and math.floor(ctxKiosk) == math.floor(recordKiosk) then
        return ctxGuild == "" or recordGuild == "" or ctxGuild == recordGuild
    end
    return ctxGuild ~= "" and recordGuild ~= "" and ctxGuild == recordGuild
end

local function pruneGroupRoot(root, rowField, retentionSeconds, maxItems)
    if type(root) ~= "table" then return end
    local currentTime = now()
    local groups = {}

    for key, group in pairs(root) do
        if type(group) ~= "table" then
            root[key] = nil
        else
            local rows = group[rowField]
            if type(rows) ~= "table" then
                root[key] = nil
            else
                local newest = safeNumber(group.lastSeen) or 0
                for id, record in pairs(rows) do
                    local remove = type(record) ~= "table"
                    if not remove then
                        local expireAt = safeNumber(record.expireAt)
                        local seenAt = safeNumber(record.seenAt) or 0
                        if expireAt and expireAt > 0 and expireAt <= currentTime then remove = true end
                        if not remove and seenAt > 0 and currentTime - seenAt > retentionSeconds then remove = true end
                        if seenAt > newest then newest = seenAt end
                    end
                    if remove then rows[id] = nil end
                end
                group.lastSeen = newest
                if next(rows) == nil then
                    root[key] = nil
                else
                    groups[#groups + 1] = { key = key, lastSeen = newest }
                end
            end
        end
    end

    if #groups > maxItems then
        table.sort(groups, function(a, b) return a.lastSeen > b.lastSeen end)
        for i = maxItems + 1, #groups do root[groups[i].key] = nil end
    end
end

function M:PurgeTraderListingsBefore029687(ctx, beforeTime)
    if type(ctx) ~= "table" or clean(ctx.guildName) == "" then return 0 end
    beforeTime = safeNumber(beforeTime) or 0
    if beforeTime <= 0 then return 0 end

    local removed = 0
    local roots = {
        { root = EPC.saved and EPC.saved.marketLiveTopCache029687, field = "rows" },
        { root = EPC.saved and EPC.saved.marketPriceTraderCacheV2029683, field = "traders" },
        { root = EPC.saved and EPC.saved.marketPriceTraderCache029683, field = "traders" },
    }

    for _, spec in ipairs(roots) do
        local root = spec.root
        if type(root) == "table" then
            for key, group in pairs(root) do
                local rows = type(group) == "table" and group[spec.field] or nil
                if type(rows) == "table" then
                    for id, record in pairs(rows) do
                        local seenAt = type(record) == "table" and (safeNumber(record.seenAt) or 0) or 0
                        if seenAt > 0 and seenAt < beforeTime and sameTrader(record, ctx) then
                            rows[id] = nil
                            removed = removed + 1
                        end
                    end
                    if next(rows) == nil then root[key] = nil end
                end
            end
        end
    end
    return removed
end

function M:PruneOlderMarketCaches029687()
    local saved = EPC.saved or {}
    local retentionDays = safeNumber(saved.marketLiveRetentionDays029687) or 7
    retentionDays = math.max(1, math.min(30, retentionDays))
    local retention = retentionDays * 24 * 60 * 60
    local maxItems = math.floor(safeNumber(saved.marketLiveMaxCachedItems029687) or 2400)
    maxItems = math.max(250, math.min(8000, maxItems))

    pruneGroupRoot(saved.marketPriceTraderCacheV2029683, "traders", retention, maxItems)
    pruneGroupRoot(saved.marketPriceTraderCache029683, "traders", retention, maxItems)
end

-- A TTC full-store scan can feed thousands of rows quickly. Do not run a full
-- cache sweep every 1,500 stores while that scan is active; the completed-scan
-- path performs one authoritative prune instead.
local baseStoreLive029687 = StoreLiveTopListing029687ImplArch
if type(baseStoreLive029687) == "function" then
    local StoreLiveTopListing029687ImplArch

function M:StoreLiveTopListing029687(...)
    return StoreLiveTopListing029687ImplArch(self, ...)
end

StoreLiveTopListing029687ImplArch = function(self, record)
        if self.marketLiveScanSession029687 and (safeNumber(self.marketLiveStoresSincePrune029687) or 0) >= 1400 then
            self.marketLiveStoresSincePrune029687 = 0
        end
        return baseStoreLive029687(self, record)
    end
end

local basePrune029687 = PruneLiveMarketCache029687ImplArch
if type(basePrune029687) == "function" then
    local PruneLiveMarketCache029687ImplArch

function M:PruneLiveMarketCache029687(...)
    return PruneLiveMarketCache029687ImplArch(self, ...)
end

PruneLiveMarketCache029687ImplArch = function(self, ...)
        local result = basePrune029687(self, ...)
        if not self.marketLiveScanSession029687 then
            self:PruneOlderMarketCaches029687()
        end
        return result
    end
end

local baseFinish029687 = FinishCurrentTraderScan029687ImplArch
if type(baseFinish029687) == "function" then
    local FinishCurrentTraderScan029687ImplArch

function M:FinishCurrentTraderScan029687(...)
    return FinishCurrentTraderScan029687ImplArch(self, ...)
end

FinishCurrentTraderScan029687ImplArch = function(self, reason)
        local session = self.marketLiveScanSession029687
        local ctx = currentContext()
        local startedAt = type(session) == "table" and (safeNumber(session.startedAt) or 0) or 0
        local result = baseFinish029687(self, reason)
        if startedAt > 0 and clean(ctx.guildName) ~= "" then
            local removed = self:PurgeTraderListingsBefore029687(ctx, startedAt)
            if removed > 0 and EPC and type(EPC.Print) == "function" then
                EPC:Print("Live Market removed " .. tostring(removed) .. " older listing" .. (removed == 1 and "" or "s") .. " that the completed trader scan no longer found.")
            end
        end
        self:PruneOlderMarketCaches029687()
        return result
    end
end

-- Building the Guild Trader hub route can inspect many fast-travel nodes. Keep
-- that work user-triggered and cache the result so it never becomes a periodic
-- or login-time FPS cost. Resetting the route clears the cache when a rebuild is wanted.
local baseBuildRoute029687 = BuildTraderHubRoute029687ImplArch
if type(baseBuildRoute029687) == "function" then
    local BuildTraderHubRoute029687ImplArch

function M:BuildTraderHubRoute029687(...)
    return BuildTraderHubRoute029687ImplArch(self, ...)
end

BuildTraderHubRoute029687ImplArch = function(self, force)
        if force ~= true and type(self.marketLiveHubRoute029687) == "table" then
            return self.marketLiveHubRoute029687
        end
        return baseBuildRoute029687(self)
    end
end

EPC.marketPriceLiveEngineSafety029687 = true
-- END ABSORBED: MarketPriceLiveEngineSafetyFix.lua

-- BEGIN ABSORBED: MarketPriceLiveAnalyticsFix.lua
-- ESO Adventurer Suite
-- v0.29.688 Live Market analytics.
-- Keeps a compact hourly low/high history from real located Guild Trader
-- observations and adds freshness/trend intelligence to Market Details.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketLiveAnalytics029688 then return end
M._marketLiveAnalytics029688 = true

EPC.defaults = EPC.defaults or {}
EPC.defaults.marketLiveHistoryHours029688 = 24
EPC.defaults.marketLiveHistoryMaxItems029688 = 800

local GOLD = "|cFFD700"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local GREY = "|cA0A0A0"
local RESET = "|r"

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function now()
    if type(GetTimeStamp) ~= "function" then return 0 end
    local ok, value = pcall(GetTimeStamp)
    return ok and (safeNumber(value) or 0) or 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local digits = tostring(math.abs(n))
    while true do
        local replaced, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then break end
    end
    return (n < 0 and "-" or "") .. digits
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    return tostring(math.floor(hours / 24)) .. "d"
end

local function itemKey(itemLink)
    if type(M.GetMarketItemKey029683) == "function" then
        local ok, key = pcall(M.GetMarketItemKey029683, M, itemLink)
        if ok and key then return key end
    end
    if type(itemLink) ~= "string" or itemLink == "" then return nil end
    return "raw:" .. itemLink
end

local function historyHours()
    local saved = EPC.saved or {}
    local value = safeNumber(saved.marketLiveHistoryHours029688) or 24
    return math.max(6, math.min(72, math.floor(value)))
end

local function historyMaxItems()
    local saved = EPC.saved or {}
    local value = safeNumber(saved.marketLiveHistoryMaxItems029688) or 800
    return math.max(200, math.min(2000, math.floor(value)))
end

local function historyRoot()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketLiveHourlyHistory029688) ~= "table" then
        EPC.saved.marketLiveHourlyHistory029688 = {}
    end
    return EPC.saved.marketLiveHourlyHistory029688
end

function M:PruneLiveMarketHistory029688()
    local root = historyRoot()
    local cutoff = now() - ((historyHours() + 2) * 3600)
    local groups = {}

    for key, group in pairs(root) do
        if type(group) ~= "table" or type(group.hours) ~= "table" then
            root[key] = nil
        else
            local newest = 0
            for bucketKey, bucket in pairs(group.hours) do
                local stamp = type(bucket) == "table" and (safeNumber(bucket.time) or safeNumber(bucketKey) or 0) or 0
                if stamp < cutoff then
                    group.hours[bucketKey] = nil
                elseif stamp > newest then
                    newest = stamp
                end
            end
            group.lastSeen = math.max(safeNumber(group.lastSeen) or 0, newest)
            if next(group.hours) == nil then
                root[key] = nil
            else
                groups[#groups + 1] = { key = key, lastSeen = safeNumber(group.lastSeen) or 0 }
            end
        end
    end

    local limit = historyMaxItems()
    if #groups > limit then
        table.sort(groups, function(a, b) return a.lastSeen > b.lastSeen end)
        for i = limit + 1, #groups do root[groups[i].key] = nil end
    end
    self.marketLiveHistoryStores029688 = 0
    self.marketLiveHistoryPruneQueued029688 = false
end

function M:QueueLiveMarketHistoryPrune029688(delayMs)
    if self.marketLiveScanSession029687 or self.marketLiveHistoryPruneQueued029688 then return end
    self.marketLiveHistoryPruneQueued029688 = true
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local market = EPC and EPC.MarketPriceChecker
            if not market then return end
            if market.marketLiveScanSession029687 then
                market.marketLiveHistoryPruneQueued029688 = false
                return
            end
            market:PruneLiveMarketHistory029688()
        end, math.max(25, math.floor(safeNumber(delayMs) or 75)))
    else
        self:PruneLiveMarketHistory029688()
    end
end

function M:RecordLiveMarketHistory029688(record)
    if type(record) ~= "table" or type(record.itemLink) ~= "string" or record.itemLink == "" then return false end
    local price = safeNumber(record.unitPrice)
    local seenAt = safeNumber(record.seenAt) or now()
    if not price or price <= 0 or seenAt <= 0 then return false end
    local currentTime = now()
    if currentTime > 0 and currentTime - seenAt > (historyHours() + 2) * 3600 then return false end

    local key = itemKey(record.itemLink)
    if not key then return false end
    local root = historyRoot()
    local group = root[key]
    if type(group) ~= "table" then
        group = { itemLink = record.itemLink, lastSeen = 0, hours = {} }
        root[key] = group
    end
    group.hours = type(group.hours) == "table" and group.hours or {}

    local bucketTime = math.floor(seenAt / 3600) * 3600
    local bucketKey = tostring(bucketTime)
    local bucket = group.hours[bucketKey]
    if type(bucket) ~= "table" then
        bucket = { time = bucketTime, low = price, high = price, last = price }
        group.hours[bucketKey] = bucket
    else
        bucket.low = math.min(safeNumber(bucket.low) or price, price)
        bucket.high = math.max(safeNumber(bucket.high) or price, price)
        if seenAt >= (safeNumber(bucket.lastSeen) or 0) then bucket.last = price end
    end
    bucket.lastSeen = math.max(safeNumber(bucket.lastSeen) or 0, seenAt)
    group.itemLink = record.itemLink
    group.lastSeen = math.max(safeNumber(group.lastSeen) or 0, seenAt)

    self.marketLiveHistoryStores029688 = (self.marketLiveHistoryStores029688 or 0) + 1
    if not self.marketLiveScanSession029687 and self.marketLiveHistoryStores029688 >= 1200 then
        self:QueueLiveMarketHistoryPrune029688(75)
    end
    return true
end

local baseStore029688 = StorePersistentTraderListing029683ImplArch
if type(baseStore029688) == "function" then
    StorePersistentTraderListing029683ImplArch = function(self, record)
        local result = baseStore029688(self, record)
        self:RecordLiveMarketHistory029688(record)
        return result
    end
end

-- Run one compact history cleanup after an authoritative TTC full-store scan,
-- never repeatedly while thousands of search rows are streaming in.
local baseFinish029688 = FinishCurrentTraderScan029687ImplArch
if type(baseFinish029688) == "function" then
    FinishCurrentTraderScan029687ImplArch = function(self, reason)
        local result = baseFinish029688(self, reason)
        self.marketLiveHistoryPruneQueued029688 = false
        self:QueueLiveMarketHistoryPrune029688(125)
        return result
    end
end

local function average(values)
    if #values == 0 then return nil end
    local total = 0
    for i = 1, #values do total = total + values[i] end
    return total / #values
end

function M:GetLiveMarketAnalytics029688(itemLink)
    local currentTime = now()
    local freshWindow = ((EPC.saved and safeNumber(EPC.saved.marketLiveFreshMinutes029687)) or 30) * 60
    local rows = type(self.GetComparableTraderListings029683) == "function" and self:GetComparableTraderListings029683(itemLink, 60) or {}
    local freshestAge, freshRows, knownRows, locatedLow = nil, 0, 0, nil

    for _, row in ipairs(rows) do
        local seenAt = safeNumber(row.seenAt) or 0
        local age = seenAt > 0 and math.max(0, currentTime - seenAt) or math.huge
        knownRows = knownRows + 1
        if age <= freshWindow then freshRows = freshRows + 1 end
        if not freshestAge or age < freshestAge then freshestAge = age end
        local price = safeNumber(row.unitPrice)
        if price and (not locatedLow or price < locatedLow) then locatedLow = price end
    end

    local key = itemKey(itemLink)
    local group = key and historyRoot()[key] or nil
    local historyLow, historyHigh = nil, nil
    local recent, previous = {}, {}
    local bucketCount = 0
    local cutoff = currentTime - historyHours() * 3600
    local recentCutoff = currentTime - 6 * 3600

    if type(group) == "table" and type(group.hours) == "table" then
        for _, bucket in pairs(group.hours) do
            local stamp = type(bucket) == "table" and (safeNumber(bucket.time) or 0) or 0
            if stamp >= cutoff then
                local low = safeNumber(bucket.low)
                local high = safeNumber(bucket.high)
                if low then
                    bucketCount = bucketCount + 1
                    historyLow = historyLow and math.min(historyLow, low) or low
                    if stamp >= recentCutoff then recent[#recent + 1] = low else previous[#previous + 1] = low end
                end
                if high then historyHigh = historyHigh and math.max(historyHigh, high) or high end
            end
        end
    end

    local recentAverage = average(recent)
    local previousAverage = average(previous)
    local trendPercent = nil
    if recentAverage and previousAverage and previousAverage > 0 and #recent >= 1 and #previous >= 2 then
        trendPercent = ((recentAverage - previousAverage) / previousAverage) * 100
    end

    return {
        knownRows = knownRows,
        freshRows = freshRows,
        freshestAge = freshestAge,
        locatedLow = locatedLow,
        historyLow = historyLow,
        historyHigh = historyHigh,
        historyBuckets = bucketCount,
        recentLowAverage = recentAverage,
        previousLowAverage = previousAverage,
        trendPercent = trendPercent,
    }
end

function M:FormatLiveMarketAnalytics029688(itemLink)
    local a = self:GetLiveMarketAnalytics029688(itemLink)
    local bits = { CYAN .. "LIVE INTELLIGENCE" .. RESET }
    if a.knownRows > 0 then
        bits[#bits + 1] = GREEN .. tostring(a.freshRows) .. "/" .. tostring(a.knownRows) .. " fresh" .. RESET
    else
        bits[#bits + 1] = GREY .. "no located listings yet" .. RESET
    end
    if a.freshestAge and a.freshestAge < math.huge then bits[#bits + 1] = "freshest " .. formatAge(a.freshestAge) end
    if a.historyLow then bits[#bits + 1] = GOLD .. tostring(historyHours()) .. "h low " .. formatNumber(a.historyLow) .. "g" .. RESET end

    if a.trendPercent then
        local pct = math.abs(a.trendPercent)
        if pct < 1 then
            bits[#bits + 1] = GREY .. "low trend flat" .. RESET
        elseif a.trendPercent < 0 then
            bits[#bits + 1] = GREEN .. string.format("low trend down %.1f%%", pct) .. RESET
        else
            bits[#bits + 1] = YELLOW .. string.format("low trend up %.1f%%", pct) .. RESET
        end
    end
    return table.concat(bits, "   ")
end

local baseShowPanel029688 = ShowMarketContextPanel029685ImplArch
if type(baseShowPanel029688) == "function" then
    ShowMarketContextPanel029685ImplArch = function(self, itemLink, clickedRecord)
        local result = baseShowPanel029688(self, itemLink, clickedRecord)
        local panel = self.marketContextPanel029685
        if panel and panel.content and type(panel.content.GetText) == "function" and type(panel.content.SetText) == "function" then
            local text = tostring(panel.content:GetText() or "")
            if not text:find("LIVE INTELLIGENCE", 1, true) then
                panel.content:SetText(text .. "\n" .. self:FormatLiveMarketAnalytics029688(itemLink))
            end
        end
        return result
    end
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easmarkettrend"] = function()
    local market = EPC and EPC.MarketPriceChecker
    if not market then return end
    local link = market.lastTooltipLink or (type(market.GetHoveredItemLink029683) == "function" and market:GetHoveredItemLink029683())
    if type(link) ~= "string" or link == "" then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Hover an item first, then use /easmarkettrend.") end
        return
    end
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(clean(market:FormatLiveMarketAnalytics029688(link)))
    end
end

if type(zo_callLater) == "function" then
    zo_callLater(function()
        local market = EPC and EPC.MarketPriceChecker
        if market and market.QueueLiveMarketHistoryPrune029688 then market:QueueLiveMarketHistoryPrune029688(75) end
    end, 5500)
end

EPC.marketPriceLiveAnalytics029688 = true
-- END ABSORBED: MarketPriceLiveAnalyticsFix.lua

-- BEGIN ABSORBED: MarketPriceLiveSettingsFix.lua
-- ESO Adventurer Suite
-- Settings extension for the v0.29.689 Live Market Engine.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Settings or not EPC.MarketPriceChecker then return end
local S = EPC.Settings
local M = EPC.MarketPriceChecker
if S._marketLiveSettings029687 then return end
S._marketLiveSettings029687 = true

local baseInitialize = S.Initialize

local function liveControls()
    return {
        {
            type = "header",
            name = "Live Guild Trader Engine",
        },
        {
            type = "description",
            text = "EAS captures ESO Guild Trader search results immediately and preserves the best recent located listings. The normal workflow is fully button-driven through the Live Market Control Center and Teleporter > Tools. TTC is optional; EAS can full-scan the current store itself with ESO's native Trading House API.",
            width = "full",
        },
        {
            type = "button",
            name = "Live Market Control Center",
            buttonText = "OPEN CONTROL CENTER",
            tooltip = "Opens the full button-driven Live Market panel with scan, route, next hub, pause/resume, reset, auto-scan, refresh, and cache controls.",
            func = function() if M.OpenLiveMarketControlPanel029689 then M:OpenLiveMarketControlPanel029689() end end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Auto-scan stale Guild Traders",
            tooltip = "During an active Guild Trader Scan Route, opening a stale trader starts a full-store scan. EAS uses TTC Scan All when TTC is available; otherwise it uses the native ESO Trading House API. Outside the route, normal shopping is never forced into a native full scan.",
            getFunc = function() return EPC.saved.marketLiveAutoScanTTC029687 ~= false end,
            setFunc = function(value) EPC.saved.marketLiveAutoScanTTC029687 = value == true end,
            default = EPC.defaults.marketLiveAutoScanTTC029687,
        },
        {
            type = "slider",
            name = "Live listing freshness window (minutes)",
            min = 5, max = 180, step = 5,
            tooltip = "Listings seen inside this window are prioritized as fresh. Auto-scan also uses this window to avoid immediately rescanning the same trader.",
            getFunc = function() return math.floor(tonumber(EPC.saved.marketLiveFreshMinutes029687) or 30) end,
            setFunc = function(value) EPC.saved.marketLiveFreshMinutes029687 = math.floor(tonumber(value) or 30) end,
            default = EPC.defaults.marketLiveFreshMinutes029687,
        },
        {
            type = "slider",
            name = "Maximum age for TRAVEL TO (minutes)",
            min = 5, max = 360, step = 5,
            tooltip = "EAS will not route you to an old listing even if it remains in history. This protects Travel to Cheapest from stale observations.",
            getFunc = function() return math.floor(tonumber(EPC.saved.marketLiveTravelMaxAgeMinutes029687) or 60) end,
            setFunc = function(value) EPC.saved.marketLiveTravelMaxAgeMinutes029687 = math.floor(tonumber(value) or 60) end,
            default = EPC.defaults.marketLiveTravelMaxAgeMinutes029687,
        },
        {
            type = "slider",
            name = "Located-listing retention (days)",
            min = 1, max = 14, step = 1,
            tooltip = "How long EAS can retain historical exact trader observations for comparison. Expired ESO listings are still removed immediately, and TRAVEL uses the much shorter maximum-age setting above.",
            getFunc = function() return math.floor(tonumber(EPC.saved.marketLiveRetentionDays029687) or 7) end,
            setFunc = function(value)
                EPC.saved.marketLiveRetentionDays029687 = math.floor(tonumber(value) or 7)
                if M.PruneLiveMarketCache029687 then M:PruneLiveMarketCache029687() end
            end,
            default = EPC.defaults.marketLiveRetentionDays029687,
        },
        {
            type = "slider",
            name = "Live price history window (hours)",
            min = 6, max = 72, step = 6,
            tooltip = "Controls the compact hourly low/high history shown by LIVE INTELLIGENCE in Market Details.",
            getFunc = function() return math.floor(tonumber(EPC.saved.marketLiveHistoryHours029688) or 24) end,
            setFunc = function(value)
                EPC.saved.marketLiveHistoryHours029688 = math.floor(tonumber(value) or 24)
                if M.PruneLiveMarketHistory029688 then M:PruneLiveMarketHistory029688() end
            end,
            default = (EPC.defaults and EPC.defaults.marketLiveHistoryHours029688) or 24,
        },
        {
            type = "button",
            name = "Current Guild Trader",
            buttonText = "FULL STORE SCAN",
            tooltip = "Open a Guild Trader first. EAS uses TTC Scan All when available; otherwise it pages through the complete current store using ESO's public Trading House API and native search cooldown.",
            func = function() if M.StartCurrentTraderFullScan029687 then M:StartCurrentTraderFullScan029687(true) end end,
            width = "half",
        },
        {
            type = "button",
            name = "Live Market Database",
            buttonText = "OPEN STATUS",
            tooltip = "Opens the Live Market Control Center showing fresh/known trader counts, locations, cached item count, active scanner provider, current scan progress, and route state.",
            func = function() if M.OpenLiveMarketControlPanel029689 then M:OpenLiveMarketControlPanel029689() elseif M.PrintLiveMarketStatus029687 then M:PrintLiveMarketStatus029687() end end,
            width = "half",
        },
        {
            type = "button",
            name = "Guild Trader Scan Route",
            buttonText = "START / RESTART",
            tooltip = "Builds a route from discovered wayshrines to known trader hubs. At each hub, open the Guild Traders; EAS captures searches and can automatically run a full scan with TTC or the native scanner. Use the Live Market Control Center or Teleporter > Tools to advance to the next hub.",
            func = function() if M.StartTraderRoute029687 then M:StartTraderRoute029687(true) end end,
            width = "half",
        },
        {
            type = "button",
            name = "Live Market Cache",
            buttonText = "PRUNE NOW",
            tooltip = "Removes expired/old located listings and enforces the bounded item/listing/history cache limits immediately.",
            func = function()
                if M.PruneLiveMarketCache029687 then M:PruneLiveMarketCache029687() end
                if M.PruneLiveMarketHistory029688 then M:PruneLiveMarketHistory029688() end
                if EPC.Print then EPC:Print("Live Market cache pruned.") end
            end,
            width = "half",
        },
        {
            type = "description",
            title = "Normal workflow",
            text = "Open a Guild Trader and click EAS LIVE MARKET, or open Teleporter > Tools > LIVE MARKET CONTROL CENTER. Use the buttons there for scanning and the trader route. Slash commands remain available only as optional diagnostics/fallbacks; they are not required for normal use.",
            width = "full",
        },
    }
end

local function appendToMarketSubmenu(options)
    if type(options) ~= "table" then return end
    for _, option in ipairs(options) do
        if type(option) == "table" and option.type == "submenu" and option.name == "Market & Trading" then
            option.controls = type(option.controls) == "table" and option.controls or {}
            for _, existing in ipairs(option.controls) do
                if type(existing) == "table" and existing.name == "Live Guild Trader Engine" then return end
            end
            for _, control in ipairs(liveControls()) do option.controls[#option.controls + 1] = control end
            return
        end
    end
end

function S:Initialize(...)
    local LAM = LibAddonMenu2
    if not LAM or type(LAM.RegisterOptionControls) ~= "function" then
        return baseInitialize(self, ...)
    end

    local previousRegister = LAM.RegisterOptionControls
    LAM.RegisterOptionControls = function(lam, panelName, options, ...)
        if panelName == "ESOProgressionCoachSettings" then appendToMarketSubmenu(options) end
        return previousRegister(lam, panelName, options, ...)
    end

    local ok, result = pcall(baseInitialize, self, ...)
    LAM.RegisterOptionControls = previousRegister
    if not ok then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Live Market settings integration failed: " .. tostring(result)) end
        return nil
    end
    return result
end

EPC.marketPriceLiveSettings029687 = true
-- END ABSORBED: MarketPriceLiveSettingsFix.lua


-- Market Price absorbed active engine layers

-- BEGIN ABSORBED: MarketPriceLiveEngineFix.lua
-- ESO Adventurer Suite
-- Live Market Engine: high-freshness Guild Trader capture, TTC deep integration,
-- persistent top-listing cache, watch alerts, trader health, and Teleporter route tools.
--
-- This module intentionally performs no network I/O. It consumes ESO's live Guild
-- Trader search results plus already-loaded TTC observations. Global TTC listing
-- search can be added later as a provider if sanctioned access becomes available.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._marketLiveEngine029687 then return end
M._marketLiveEngine029687 = true

EPC.defaults = EPC.defaults or {}
EPC.defaults.marketLiveAutoScanTTC029687 = true
EPC.defaults.marketLiveFreshMinutes029687 = 30
EPC.defaults.marketLiveTravelMaxAgeMinutes029687 = 60
EPC.defaults.marketLiveRetentionDays029687 = 7
EPC.defaults.marketLiveMaxListingsPerItem029687 = 24
EPC.defaults.marketLiveMaxCachedItems029687 = 2400

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_MarketLive029687"
local GOLD = "|cFFD700"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local GREY = "|cA0A0A0"
local RESET = "|r"

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e, f, g, h, i, j
end

local function now()
    return safeNumber(safeCall(GetTimeStamp, 0)) or 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(clean(value))
end

local function formatAge(seconds)
    seconds = math.max(0, math.floor(safeNumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m" end
    local hours = math.floor(minutes / 60)
    if hours < 48 then return tostring(hours) .. "h " .. tostring(minutes % 60) .. "m" end
    local days = math.floor(hours / 24)
    return tostring(days) .. "d " .. tostring(hours % 24) .. "h"
end

local function formatNumber(value)
    local n = safeNumber(value)
    if not n then return "-" end
    n = math.floor(n + 0.5)
    if type(ZO_CommaDelimitDecimalNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitDecimalNumber, n)
        if ok and text then return tostring(text) end
    end
    local digits = tostring(math.abs(n))
    local sign = n < 0 and "-" or ""
    while true do
        local nextDigits, count = digits:gsub("^(%d+)(%d%d%d)", "%1,%2")
        digits = nextDigits
        if count == 0 then break end
    end
    return sign .. digits
end

local function settingNumber(key, defaultValue, minimum, maximum)
    local saved = EPC.saved or {}
    local value = safeNumber(saved[key]) or defaultValue
    if minimum then value = math.max(minimum, value) end
    if maximum then value = math.min(maximum, value) end
    return value
end

local function freshSeconds()
    return settingNumber("marketLiveFreshMinutes029687", 30, 1, 1440) * 60
end

local function travelFreshSeconds()
    return settingNumber("marketLiveTravelMaxAgeMinutes029687", 60, 1, 10080) * 60
end

local function retentionSeconds()
    return settingNumber("marketLiveRetentionDays029687", 7, 1, 30) * 24 * 60 * 60
end

local function maxListingsPerItem()
    return math.floor(settingNumber("marketLiveMaxListingsPerItem029687", 24, 5, 60))
end

local function maxCachedItems()
    return math.floor(settingNumber("marketLiveMaxCachedItems029687", 2400, 250, 8000))
end

local function itemKey(itemLink)
    if type(M.GetMarketItemKey029683) == "function" then
        local ok, key = pcall(M.GetMarketItemKey029683, M, itemLink)
        if ok and key then return key end
    end
    itemLink = tostring(itemLink or "")
    if itemLink == "" then return nil end
    local payload = itemLink:match("|H%d+:item:([^|]+)|h")
    return payload and ("raw:" .. payload) or ("raw:" .. itemLink)
end

local function currentTraderContext()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then
            guildId = safeNumber(id) or 0
            guildName = clean(name)
        end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, id = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(id) end
    end

    local traderName = ""
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "interact")
        if ok then traderName = clean(value) end
    end
    if traderName == "" and type(GetRawUnitName) == "function" then
        local ok, value = pcall(GetRawUnitName, "interact")
        if ok then traderName = clean(value) end
    end

    local locationName = ""
    if type(GetPlayerLocationName) == "function" then
        local ok, value = pcall(GetPlayerLocationName)
        if ok then locationName = clean(value) end
    end

    local zoneName = ""
    if type(GetPlayerActiveZoneName) == "function" then
        local ok, value = pcall(GetPlayerActiveZoneName)
        if ok then zoneName = clean(value) end
    end

    return {
        guildId = guildId,
        guildName = guildName,
        kioskId = kioskId,
        traderName = traderName,
        locationName = locationName,
        zoneName = zoneName,
    }
end

local function traderIdentity(record)
    if type(record) ~= "table" then return nil end
    local kioskId = safeNumber(record.kioskId)
    local guild = lower(record.guildName)
    if kioskId then return "k:" .. tostring(math.floor(kioskId)) .. "|g:" .. guild end
    local location = lower(record.locationName)
    local zone = lower(record.zoneName)
    if guild ~= "" then return "g:" .. guild .. "|l:" .. location .. "|z:" .. zone end
    local trader = lower(record.traderName)
    if trader ~= "" then return "t:" .. trader .. "|l:" .. location .. "|z:" .. zone end
    return nil
end

local function copyRecord(record)
    local out = {}
    for key, value in pairs(record or {}) do
        if type(value) ~= "table" then out[key] = value end
    end
    return out
end

local function isRecordExpired(record, currentTime)
    if type(record) ~= "table" then return true end
    currentTime = currentTime or now()
    local expireAt = safeNumber(record.expireAt)
    if expireAt and expireAt > 0 and expireAt <= currentTime then return true end
    local seenAt = safeNumber(record.seenAt) or 0
    if seenAt > 0 and currentTime - seenAt > retentionSeconds() then return true end
    return false
end

local function liveCache()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketLiveTopCache029687) ~= "table" then
        EPC.saved.marketLiveTopCache029687 = {}
    end
    return EPC.saved.marketLiveTopCache029687
end

local function healthRoot()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketLiveTraderHealth029687) ~= "table" then
        EPC.saved.marketLiveTraderHealth029687 = { traders = {}, locations = {} }
    end
    local root = EPC.saved.marketLiveTraderHealth029687
    root.traders = type(root.traders) == "table" and root.traders or {}
    root.locations = type(root.locations) == "table" and root.locations or {}
    return root
end

local function watchRoot()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketLiveWatchlist029687) ~= "table" then
        EPC.saved.marketLiveWatchlist029687 = {}
    end
    return EPC.saved.marketLiveWatchlist029687
end

local function routeState()
    EPC.saved = EPC.saved or {}
    if type(EPC.saved.marketLiveRoute029687) ~= "table" then
        EPC.saved.marketLiveRoute029687 = { active = false, paused = false, index = 1, visited = {} }
    end
    local state = EPC.saved.marketLiveRoute029687
    state.visited = type(state.visited) == "table" and state.visited or {}
    return state
end

local function trimLiveGroup(group)
    if type(group) ~= "table" then return end
    group.rows = type(group.rows) == "table" and group.rows or {}
    local currentTime = now()
    local rows = {}
    for identity, record in pairs(group.rows) do
        if isRecordExpired(record, currentTime) then
            group.rows[identity] = nil
        else
            rows[#rows + 1] = { identity = identity, record = record }
        end
    end
    table.sort(rows, function(a, b)
        local ap = safeNumber(a.record.unitPrice) or math.huge
        local bp = safeNumber(b.record.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.record.seenAt) or 0) > (safeNumber(b.record.seenAt) or 0)
    end)
    local limit = maxListingsPerItem()
    for i = limit + 1, #rows do
        group.rows[rows[i].identity] = nil
    end
end

PruneLiveMarketCache029687ImplArch = function(self)
    local root = liveCache()
    local groups = {}
    for key, group in pairs(root) do
        if type(group) ~= "table" then
            root[key] = nil
        else
            trimLiveGroup(group)
            if next(group.rows or {}) == nil then
                root[key] = nil
            else
                groups[#groups + 1] = { key = key, lastSeen = safeNumber(group.lastSeen) or 0 }
            end
        end
    end
    local limit = maxCachedItems()
    if #groups > limit then
        table.sort(groups, function(a, b) return a.lastSeen > b.lastSeen end)
        for i = limit + 1, #groups do root[groups[i].key] = nil end
    end
    self.marketLiveStoresSincePrune029687 = 0
end

StoreLiveTopListing029687ImplArch = function(self, record)
    if type(record) ~= "table" or type(record.itemLink) ~= "string" or record.itemLink == "" then return false end
    local key = itemKey(record.itemLink)
    local identity = traderIdentity(record)
    local unitPrice = safeNumber(record.unitPrice)
    if not key or not identity or not unitPrice or unitPrice <= 0 then return false end
    local currentTime = now()
    if isRecordExpired(record, currentTime) then return false end

    local root = liveCache()
    local group = root[key]
    if type(group) ~= "table" then
        group = { itemLink = record.itemLink, lastSeen = 0, rows = {} }
        root[key] = group
    end
    group.rows = type(group.rows) == "table" and group.rows or {}

    local seenAt = safeNumber(record.seenAt) or currentTime
    local old = group.rows[identity]
    local replace = old == nil or isRecordExpired(old, currentTime)
    if old and not replace then
        local oldSeen = safeNumber(old.seenAt) or 0
        local oldPrice = safeNumber(old.unitPrice) or math.huge
        replace = seenAt > oldSeen or (seenAt == oldSeen and unitPrice < oldPrice)
    end

    if replace then
        group.rows[identity] = {
            itemLink = record.itemLink,
            unitPrice = unitPrice,
            totalPrice = safeNumber(record.totalPrice),
            amount = math.max(1, safeNumber(record.amount) or 1),
            sellerName = clean(record.sellerName),
            guildName = clean(record.guildName),
            guildId = safeNumber(record.guildId),
            kioskId = safeNumber(record.kioskId),
            traderName = clean(record.traderName),
            locationName = clean(record.locationName),
            zoneName = clean(record.zoneName),
            seenAt = seenAt,
            expireAt = safeNumber(record.expireAt),
            source = clean(record.source ~= "" and record.source or "EAS LIVE"),
            uid = record.uid,
        }
    end

    group.itemLink = record.itemLink
    group.lastSeen = math.max(safeNumber(group.lastSeen) or 0, seenAt)
    trimLiveGroup(group)

    self.marketLiveStoresSincePrune029687 = (self.marketLiveStoresSincePrune029687 or 0) + 1
    if self.marketLiveStoresSincePrune029687 >= 1500 then
        if type(zo_callLater) == "function" then
            if not self.marketLivePruneQueued029687 then
                self.marketLivePruneQueued029687 = true
                zo_callLater(function()
                    if EPC.MarketPriceChecker then
                        EPC.MarketPriceChecker.marketLivePruneQueued029687 = false
                        EPC.MarketPriceChecker:PruneLiveMarketCache029687()
                    end
                end, 25)
            end
        else
            self:PruneLiveMarketCache029687()
        end
    end

    self:CheckLiveWatch029687(group.rows[identity])
    return true
end

local baseStorePersistent029687 = StorePersistentTraderListing029683ImplArch
if type(baseStorePersistent029687) == "function" then
    StorePersistentTraderListing029683ImplArch = function(self, record)
        local result = baseStorePersistent029687(self, record)
        self:StoreLiveTopListing029687(record)
        return result
    end
end

local baseComparable029687 = GetComparableTraderListings029683ImplArch
GetComparableTraderListings029683ImplArch = function(self, itemLink, limit)
    local merged = {}
    local function accept(record)
        if type(record) ~= "table" or isRecordExpired(record) then return end
        local identity = traderIdentity(record)
        if not identity then return end
        local old = merged[identity]
        if not old then
            merged[identity] = copyRecord(record)
            return
        end
        local seenAt = safeNumber(record.seenAt) or 0
        local oldSeen = safeNumber(old.seenAt) or 0
        if seenAt > oldSeen or (seenAt == oldSeen and (safeNumber(record.unitPrice) or math.huge) < (safeNumber(old.unitPrice) or math.huge)) then
            merged[identity] = copyRecord(record)
        end
    end

    if type(baseComparable029687) == "function" then
        local ok, rows = pcall(baseComparable029687, self, itemLink, 60)
        if ok and type(rows) == "table" then
            for _, record in ipairs(rows) do accept(record) end
        end
    end

    local key = itemKey(itemLink)
    local group = key and liveCache()[key] or nil
    if type(group) == "table" then
        trimLiveGroup(group)
        for _, record in pairs(group.rows or {}) do accept(record) end
    end

    local ctx = currentTraderContext()
    local currentGuild = lower(ctx.guildName)
    local currentKiosk = safeNumber(ctx.kioskId)
    local currentTime = now()
    local rows = {}
    for _, record in pairs(merged) do
        local recordKiosk = safeNumber(record.kioskId)
        local recordGuild = lower(record.guildName)
        local isCurrent = false
        if currentKiosk and recordKiosk and math.floor(currentKiosk) == math.floor(recordKiosk) then
            if currentGuild == "" or recordGuild == "" or currentGuild == recordGuild then isCurrent = true end
        elseif currentGuild ~= "" and recordGuild ~= "" and currentGuild == recordGuild then
            isCurrent = true
        end
        record._easCurrentTrader = isCurrent
        local seenAt = safeNumber(record.seenAt) or 0
        record._easAge029687 = seenAt > 0 and math.max(0, currentTime - seenAt) or math.huge
        record._easFresh029687 = record._easAge029687 <= freshSeconds()
        rows[#rows + 1] = record
    end

    table.sort(rows, function(a, b)
        if a._easFresh029687 ~= b._easFresh029687 then return a._easFresh029687 == true end
        local ap = safeNumber(a.unitPrice) or math.huge
        local bp = safeNumber(b.unitPrice) or math.huge
        if ap ~= bp then return ap < bp end
        return (safeNumber(a.seenAt) or 0) > (safeNumber(b.seenAt) or 0)
    end)

    local requested = math.floor(safeNumber(limit) or maxListingsPerItem())
    requested = math.max(1, math.min(60, requested))
    while #rows > requested do table.remove(rows) end
    return rows
end

GetBestTravelTrader029683ImplArch = function(self, itemLink)
    local rows = self:GetComparableTraderListings029683(itemLink, 60)
    local maxAge = travelFreshSeconds()
    for _, record in ipairs(rows) do
        local age = safeNumber(record._easAge029687)
        if age == nil then
            local seenAt = safeNumber(record.seenAt) or 0
            age = seenAt > 0 and math.max(0, now() - seenAt) or math.huge
        end
        if not record._easCurrentTrader and age <= maxAge and self:GetLocationInfo029683(record) then
            return record
        end
    end
    return nil
end

local UpdateTraderHealth029687ImplArch

function M:UpdateTraderHealth029687(...)
    return UpdateTraderHealth029687ImplArch(self, ...)
end

UpdateTraderHealth029687ImplArch = function(self, context, fullScan, rows, pages)
    context = context or currentTraderContext()
    if clean(context.guildName) == "" then return end
    local root = healthRoot()
    local identity = traderIdentity(context)
    if not identity then identity = "g:" .. lower(context.guildName) end
    local record = root.traders[identity]
    if type(record) ~= "table" then
        record = {}
        root.traders[identity] = record
    end
    record.guildId = safeNumber(context.guildId)
    record.guildName = clean(context.guildName)
    record.kioskId = safeNumber(context.kioskId)
    record.traderName = clean(context.traderName)
    record.locationName = clean(context.locationName)
    record.zoneName = clean(context.zoneName)
    record.lastSeen = now()
    if fullScan then record.lastFullScan = record.lastSeen end
    if rows ~= nil then record.lastRows = safeNumber(rows) or 0 end
    if pages ~= nil then record.lastPages = safeNumber(pages) or 0 end

    if record.kioskId then
        local kioskKey = tostring(math.floor(record.kioskId))
        local location = root.locations[kioskKey]
        if type(location) ~= "table" then location = {} root.locations[kioskKey] = location end
        location.kioskId = record.kioskId
        location.locationName = record.locationName
        location.zoneName = record.zoneName
        location.lastSeen = math.max(safeNumber(location.lastSeen) or 0, record.lastSeen)
        if fullScan then location.lastFullScan = math.max(safeNumber(location.lastFullScan) or 0, record.lastSeen) end
    end
end

function M:IsCurrentTraderFresh029687()
    local ctx = currentTraderContext()
    if clean(ctx.guildName) == "" then return false end
    local root = healthRoot()
    local identity = traderIdentity(ctx) or ("g:" .. lower(ctx.guildName))
    local record = root.traders[identity]
    local ts = type(record) == "table" and (safeNumber(record.lastFullScan) or 0) or 0
    return ts > 0 and now() - ts <= freshSeconds()
end

local GetLiveMarketHealth029687ImplArch

function M:GetLiveMarketHealth029687(...)
    return GetLiveMarketHealth029687ImplArch(self, ...)
end

GetLiveMarketHealth029687ImplArch = function(self)
    local root = healthRoot()
    local currentTime = now()
    local traders, freshTraders, locations, freshLocations = 0, 0, 0, 0
    for _, record in pairs(root.traders) do
        if type(record) == "table" then
            traders = traders + 1
            local ts = safeNumber(record.lastFullScan) or safeNumber(record.lastSeen) or 0
            if ts > 0 and currentTime - ts <= freshSeconds() then freshTraders = freshTraders + 1 end
        end
    end
    for _, record in pairs(root.locations) do
        if type(record) == "table" then
            locations = locations + 1
            local ts = safeNumber(record.lastFullScan) or safeNumber(record.lastSeen) or 0
            if ts > 0 and currentTime - ts <= freshSeconds() then freshLocations = freshLocations + 1 end
        end
    end
    local items = 0
    for _ in pairs(liveCache()) do items = items + 1 end
    return {
        traders = traders,
        freshTraders = freshTraders,
        locations = locations,
        freshLocations = freshLocations,
        items = items,
        ttc = type(rawget(_G, "TamrielTradeCentre")) == "table",
        scanActive = self.marketLiveScanSession029687 ~= nil,
    }
end

local PrintLiveMarketStatus029687ImplArch

function M:PrintLiveMarketStatus029687(...)
    return PrintLiveMarketStatus029687ImplArch(self, ...)
end

PrintLiveMarketStatus029687ImplArch = function(self)
    local h = self:GetLiveMarketHealth029687()
    local state = routeState()
    local routeText = state.active and (state.paused and "route paused" or "route active") or "route idle"
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(string.format(
            "Live Market: %d/%d traders fresh, %d/%d locations fresh, %d cached items, TTC %s, %s.",
            h.freshTraders, h.traders, h.freshLocations, h.locations, h.items,
            h.ttc and "ready" or "not installed", routeText))
    end
end

function M:CaptureCurrentSearchPage029687(source)
    if type(GetTradingHouseSearchResultsInfo) ~= "function" or type(GetTradingHouseSearchResultItemLink) ~= "function" or type(GetTradingHouseSearchResultItemInfo) ~= "function" then return 0 end
    local okCount, count, currentPage = pcall(GetTradingHouseSearchResultsInfo)
    if not okCount then return 0 end
    count = math.max(0, math.floor(safeNumber(count) or 0))
    currentPage = math.max(0, math.floor(safeNumber(currentPage) or 0))
    local ctx = currentTraderContext()
    if clean(ctx.guildName) == "" then return 0 end
    local seenAt = now()
    local stored = 0

    for i = 1, count do
        local okLink, link = pcall(GetTradingHouseSearchResultItemLink, i)
        if okLink and type(link) == "string" and link ~= "" then
            local okInfo, _, _, _, stackCount, sellerName, timeRemaining, totalPrice, _, uid, unitPrice = pcall(GetTradingHouseSearchResultItemInfo, i)
            if okInfo then
                stackCount = math.max(1, safeNumber(stackCount) or 1)
                totalPrice = safeNumber(totalPrice) or 0
                unitPrice = safeNumber(unitPrice) or (totalPrice > 0 and totalPrice / stackCount or nil)
                if unitPrice and unitPrice > 0 then
                    local uidText = uid
                    if type(Id64ToString) == "function" and uid ~= nil then
                        local okUid, value = pcall(Id64ToString, uid)
                        if okUid then uidText = value end
                    end
                    self:StorePersistentTraderListing029683({
                        itemLink = link,
                        unitPrice = unitPrice,
                        totalPrice = totalPrice,
                        amount = stackCount,
                        sellerName = clean(sellerName),
                        guildName = ctx.guildName,
                        guildId = ctx.guildId,
                        kioskId = ctx.kioskId,
                        traderName = ctx.traderName,
                        locationName = ctx.locationName,
                        zoneName = ctx.zoneName,
                        seenAt = seenAt,
                        expireAt = seenAt + math.max(0, safeNumber(timeRemaining) or 0),
                        source = source or "LIVE SEARCH",
                        uid = uidText,
                    })
                    stored = stored + 1
                end
            end
        end
    end

    self:UpdateTraderHealth029687(ctx, false, stored, currentPage + 1)
    return stored, currentPage
end

function M:ImportCurrentTTCGuild029687(source)
    local ttc = rawget(_G, "TamrielTradeCentre")
    local data = type(ttc) == "table" and ttc.Data or nil
    local auto = type(data) == "table" and data.AutoRecordEntries or nil
    local guilds = type(auto) == "table" and auto.Guilds or nil
    local ctx = currentTraderContext()
    if type(guilds) ~= "table" or clean(ctx.guildName) == "" then return 0 end
    local guildData = guilds[ctx.guildName]
    if type(guildData) ~= "table" then return 0 end

    local kioskId = safeNumber(guildData.KioskLocationID) or ctx.kioskId
    local lastUpdate = safeNumber(guildData.LastUpdate) or now()
    local players = guildData.PlayerListings
    if type(players) ~= "table" then return 0 end
    local imported = 0
    local currentTime = now()

    for sellerName, listings in pairs(players) do
        if type(listings) == "table" then
            for _, entry in pairs(listings) do
                if type(entry) == "table" then
                    local link = entry.ItemLink
                    local amount = math.max(1, safeNumber(entry.Amount) or 1)
                    local total = safeNumber(entry.TotalPrice) or 0
                    local expireAt = safeNumber(entry.ExpireTime) or 0
                    if type(link) == "string" and link ~= "" and total > 0 and (expireAt <= 0 or expireAt > currentTime) then
                        self:StorePersistentTraderListing029683({
                            itemLink = link,
                            unitPrice = total / amount,
                            totalPrice = total,
                            amount = amount,
                            sellerName = clean(sellerName),
                            guildName = ctx.guildName,
                            guildId = ctx.guildId,
                            kioskId = kioskId,
                            traderName = ctx.traderName,
                            locationName = ctx.locationName,
                            zoneName = ctx.zoneName,
                            seenAt = safeNumber(entry.DiscoverTime) or lastUpdate,
                            expireAt = expireAt,
                            source = source or "TTC LIVE SCAN",
                            uid = entry.UID,
                        })
                        imported = imported + 1
                    end
                end
            end
        end
    end
    return imported
end

FinishCurrentTraderScan029687ImplArch = function(self, reason)
    local session = self.marketLiveScanSession029687
    if not session then return end
    local ctx = currentTraderContext()
    local imported = self:ImportCurrentTTCGuild029687("TTC FULL SCAN")
    session.rows = math.max(safeNumber(session.rows) or 0, imported)
    self:UpdateTraderHealth029687(ctx, true, session.rows, session.pages)
    self.marketLiveScanSession029687 = nil
    if type(self.PruneLiveMarketCache029687) == "function" then self:PruneLiveMarketCache029687() end
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(string.format("Live Market scan complete: %s - %d listings captured across %d page%s%s.",
            clean(ctx.guildName) ~= "" and ctx.guildName or session.guildName or "Guild Trader",
            math.floor(safeNumber(session.rows) or 0), math.floor(safeNumber(session.pages) or 0),
            (safeNumber(session.pages) or 0) == 1 and "" or "s",
            reason and (" [" .. tostring(reason) .. "]") or ""))
    end
end

local StartCurrentTraderFullScan029687ImplArch

function M:StartCurrentTraderFullScan029687(...)
    return StartCurrentTraderFullScan029687ImplArch(self, ...)
end

StartCurrentTraderFullScan029687ImplArch = function(self, force)
    if self.marketLiveScanSession029687 then
        if EPC and type(EPC.Print) == "function" then EPC:Print("A Live Market trader scan is already running.") end
        return false
    end
    local ctx = currentTraderContext()
    if clean(ctx.guildName) == "" then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Open a Guild Trader first, then start the Live Market scan.") end
        return false
    end
    if not force and self:IsCurrentTraderFresh029687() then
        if EPC and type(EPC.Print) == "function" then EPC:Print(ctx.guildName .. " was fully scanned recently; skipping duplicate scan.") end
        return true
    end

    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) ~= "table" or type(ttc.StartNewGuildListingScan) ~= "function" then
        if EPC and type(EPC.Print) == "function" then
            EPC:Print("Tamriel Trade Centre is required for automatic full-store scanning. Normal Guild Trader searches are still captured live by EAS.")
        end
        return false
    end
    if type(ttc.Settings) ~= "table" or ttc.Settings.EnableAutoRecordStoreEntries ~= true then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Enable TTC's automatic store-entry recording before using full Live Market scans.") end
        return false
    end
    if not ctx.kioskId then
        if EPC and type(EPC.Print) == "function" then EPC:Print("TTC could not identify this Guild Trader kiosk, so a full routed scan was not started.") end
        return false
    end

    self.marketLiveScanSession029687 = {
        guildName = ctx.guildName,
        kioskId = ctx.kioskId,
        startedAt = now(),
        pages = 0,
        rows = 0,
        zeroTail = 0,
        sawResults = false,
    }
    local ok, err = pcall(ttc.StartNewGuildListingScan, ttc)
    if not ok then
        self.marketLiveScanSession029687 = nil
        if EPC and type(EPC.Print) == "function" then EPC:Print("TTC full scan could not start: " .. tostring(err)) end
        return false
    end

    if EPC and type(EPC.Print) == "function" then EPC:Print("Live Market: TTC full scan started for " .. ctx.guildName .. ".") end
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local market = EPC and EPC.MarketPriceChecker
            local session = market and market.marketLiveScanSession029687
            if session and now() - (safeNumber(session.startedAt) or now()) >= 600 then
                market.marketLiveScanSession029687 = nil
                if EPC and type(EPC.Print) == "function" then EPC:Print("Live Market scan timed out after 10 minutes; route progress was preserved.") end
            end
        end, 600000)
    end
    return true
end

local HandleTradingHouseResponse029687ImplArch

function M:HandleTradingHouseResponse029687(...)
    return HandleTradingHouseResponse029687ImplArch(self, ...)
end

HandleTradingHouseResponse029687ImplArch = function(self, responseType)
    if responseType ~= nil and TRADING_HOUSE_RESULT_SEARCH_PENDING ~= nil and responseType ~= TRADING_HOUSE_RESULT_SEARCH_PENDING then return end
    local source = self.marketLiveScanSession029687 and "LIVE FULL SCAN" or "LIVE SEARCH"
    local rows, currentPage = self:CaptureCurrentSearchPage029687(source)
    local session = self.marketLiveScanSession029687
    if not session then return end

    rows = safeNumber(rows) or 0
    currentPage = safeNumber(currentPage) or 0
    if rows > 0 then
        session.sawResults = true
        session.zeroTail = 0
        session.pages = math.max(safeNumber(session.pages) or 0, currentPage + 1)
        session.rows = (safeNumber(session.rows) or 0) + rows
    else
        session.zeroTail = (safeNumber(session.zeroTail) or 0) + 1
        if session.zeroTail >= 2 then
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if EPC.MarketPriceChecker then EPC.MarketPriceChecker:FinishCurrentTraderScan029687("TTC") end
                end, 100)
            else
                self:FinishCurrentTraderScan029687("TTC")
            end
        end
    end
end

local MaybeAutoScanCurrentTrader029687ImplArch

function M:MaybeAutoScanCurrentTrader029687(...)
    return MaybeAutoScanCurrentTrader029687ImplArch(self, ...)
end

MaybeAutoScanCurrentTrader029687ImplArch = function(self)
    if not EPC.saved or EPC.saved.marketLiveAutoScanTTC029687 == false then return false end
    if self.marketLiveScanSession029687 then return false end
    return self:StartCurrentTraderFullScan029687(false)
end

function M:CheckLiveWatch029687(record)
    if type(record) ~= "table" then return end
    local source = string.upper(clean(record.source))
    if not source:find("LIVE", 1, true) and not source:find("FULL SCAN", 1, true) then return end
    local key = itemKey(record.itemLink)
    local watch = key and watchRoot()[key] or nil
    if type(watch) ~= "table" then return end
    local target = safeNumber(watch.target)
    local price = safeNumber(record.unitPrice)
    if not target or not price or price > target then return end
    local seenAt = safeNumber(record.seenAt) or 0
    if seenAt <= 0 or now() - seenAt > 300 then return end

    self.marketLiveAlerted029687 = self.marketLiveAlerted029687 or {}
    local alertKey = key .. "|" .. tostring(math.floor(price)) .. "|" .. lower(record.guildName)
    if self.marketLiveAlerted029687[alertKey] then return end
    self.marketLiveAlerted029687[alertKey] = true
    if EPC and type(EPC.Print) == "function" then
        local location = self:GetLocationInfo029683(record)
        local where = location and clean(location.label) or clean(record.locationName)
        EPC:Print(GREEN .. "MARKET WATCH HIT" .. RESET .. ": " .. clean(watch.name or "Item") .. " at " .. GOLD .. formatNumber(price) .. "g" .. RESET ..
            (clean(record.guildName) ~= "" and (" - " .. record.guildName) or "") .. (where ~= "" and (" - " .. where) or ""))
    end
end

function M:AddHoveredWatch029687(target)
    target = safeNumber(target)
    if not target or target <= 0 then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Usage: /easwatch <max unit price> while hovering an item.") end
        return false
    end
    local link = self.lastTooltipLink or (type(self.GetHoveredItemLink029683) == "function" and self:GetHoveredItemLink029683())
    if type(link) ~= "string" or link == "" then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Hover an item first, then use /easwatch <max unit price>.") end
        return false
    end
    local key = itemKey(link)
    if not key then return false end
    local name = clean(safeCall(GetItemLinkName, "Item", link))
    watchRoot()[key] = { itemLink = link, name = name ~= "" and name or "Item", target = target, addedAt = now() }
    if EPC and type(EPC.Print) == "function" then EPC:Print("Market watch added: " .. (name ~= "" and name or "Item") .. " <= " .. formatNumber(target) .. "g/unit.") end
    return true
end

function M:RemoveHoveredWatch029687()
    local link = self.lastTooltipLink or (type(self.GetHoveredItemLink029683) == "function" and self:GetHoveredItemLink029683())
    local key = type(link) == "string" and itemKey(link) or nil
    if not key or not watchRoot()[key] then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Hover a watched item to remove it.") end
        return false
    end
    local name = clean(watchRoot()[key].name)
    watchRoot()[key] = nil
    if EPC and type(EPC.Print) == "function" then EPC:Print("Market watch removed: " .. (name ~= "" and name or "Item") .. ".") end
    return true
end

function M:PrintWatchlist029687()
    local count = 0
    for _, watch in pairs(watchRoot()) do
        if type(watch) == "table" then
            count = count + 1
            if EPC and type(EPC.Print) == "function" then EPC:Print("Watch: " .. clean(watch.name or "Item") .. " <= " .. formatNumber(watch.target) .. "g/unit") end
        end
    end
    if count == 0 and EPC and type(EPC.Print) == "function" then EPC:Print("Market watchlist is empty.") end
end

BuildTraderHubRoute029687ImplArch = function(self)
    local byNode = {}
    local locations = self.KIOSK_LOCATIONS or {}
    for kioskId, mapped in pairs(locations) do
        if type(mapped) == "table" then
            local record = { kioskId = kioskId }
            local location = self:GetLocationInfo029683(record)
            local nodeIndex, nodeName = nil, nil
            if location then nodeIndex, nodeName = self:FindTravelNode029683(location, record) end
            if nodeIndex then
                local key = tostring(math.floor(nodeIndex))
                local hub = byNode[key]
                if not hub then
                    hub = { nodeIndex = nodeIndex, nodeName = nodeName or mapped.label, zone = mapped.zone, kioskIds = {}, labels = {}, order = safeNumber(kioskId) or 9999 }
                    byNode[key] = hub
                end
                hub.order = math.min(hub.order or 9999, safeNumber(kioskId) or 9999)
                hub.kioskIds[#hub.kioskIds + 1] = kioskId
                hub.labels[#hub.labels + 1] = clean(mapped.label)
            end
        end
    end
    local route = {}
    for _, hub in pairs(byNode) do route[#route + 1] = hub end
    table.sort(route, function(a, b)
        if (a.order or 9999) ~= (b.order or 9999) then return (a.order or 9999) < (b.order or 9999) end
        return lower(a.nodeName) < lower(b.nodeName)
    end)
    self.marketLiveHubRoute029687 = route
    return route
end

function M:GetTraderHubRoute029687()
    return type(self.marketLiveHubRoute029687) == "table" and self.marketLiveHubRoute029687 or self:BuildTraderHubRoute029687()
end

function M:TravelTraderHub029687(hub)
    if type(hub) ~= "table" or not safeNumber(hub.nodeIndex) then return false end
    if EPC.Travel and type(EPC.Travel.TravelToWayshrineNode) == "function" then
        local ok, result = pcall(EPC.Travel.TravelToWayshrineNode, EPC.Travel, hub.nodeIndex, hub.nodeName or "Guild Trader hub")
        return ok and result ~= false
    end
    if type(FastTravelToNode) == "function" then return pcall(FastTravelToNode, hub.nodeIndex) end
    return false
end

function M:PrintRoutePosition029687()
    local state = routeState()
    local route = self:GetTraderHubRoute029687()
    local hub = route[math.max(1, math.floor(safeNumber(state.index) or 1))]
    if not hub then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Guild Trader route has no reachable discovered hubs.") end
        return
    end
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(string.format("Guild Trader route: hub %d/%d - %s%s. Open each trader here; EAS captures searches and can auto-run TTC full scans. Use /easmarketscan next when finished with the hub.",
            math.max(1, math.floor(safeNumber(state.index) or 1)), #route, clean(hub.nodeName or "Trader Hub"),
            clean(hub.zone) ~= "" and (" - " .. clean(hub.zone)) or ""))
    end
end

function M:StartTraderRoute029687(restart)
    local route = self:BuildTraderHubRoute029687()
    if #route == 0 then
        if EPC and type(EPC.Print) == "function" then EPC:Print("No discovered Guild Trader hub wayshrines could be resolved for the Live Market route.") end
        return false
    end
    local state = routeState()
    if restart == true or state.active ~= true then
        state.index = 1
        state.visited = {}
        state.startedAt = now()
    end
    state.active = true
    state.paused = false
    local index = math.max(1, math.min(#route, math.floor(safeNumber(state.index) or 1)))
    state.index = index
    local hub = route[index]
    self:PrintRoutePosition029687()
    return self:TravelTraderHub029687(hub)
end

function M:NextTraderHub029687()
    local state = routeState()
    local route = self:GetTraderHubRoute029687()
    if state.active ~= true then return self:StartTraderRoute029687(false) end
    if state.paused == true then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Guild Trader route is paused. Resume it before advancing.") end
        return false
    end
    local current = math.max(1, math.min(#route, math.floor(safeNumber(state.index) or 1)))
    local hub = route[current]
    if hub then state.visited[tostring(hub.nodeIndex)] = now() end
    current = current + 1
    if current > #route then
        state.active = false
        state.paused = false
        if EPC and type(EPC.Print) == "function" then EPC:Print(GREEN .. "Guild Trader Live Scan Route complete." .. RESET) end
        return true
    end
    state.index = current
    self:PrintRoutePosition029687()
    return self:TravelTraderHub029687(route[current])
end

function M:PauseTraderRoute029687(paused)
    local state = routeState()
    state.paused = paused == true
    if EPC and type(EPC.Print) == "function" then EPC:Print("Guild Trader route " .. (state.paused and "paused." or "resumed.")) end
    if not state.paused and state.active then self:PrintRoutePosition029687() end
end

function M:ResetTraderRoute029687()
    local state = routeState()
    state.active = false
    state.paused = false
    state.index = 1
    state.visited = {}
    state.startedAt = nil
    self.marketLiveHubRoute029687 = nil
    if EPC and type(EPC.Print) == "function" then EPC:Print("Guild Trader route reset.") end
end

local function installTeleporterTools()
    local Travel = EPC.Travel
    if not Travel or Travel._marketLiveTools029687 or type(Travel.ShowMapTeleporterToolsMenu02967) ~= "function" then return end
    Travel._marketLiveTools029687 = true
    local baseTools = ShowMapTeleporterToolsMenu02967ImplArch

    local ShowMapTeleporterToolsMenu02967ImplArch

function Travel:ShowMapTeleporterToolsMenu02967(...)
    return ShowMapTeleporterToolsMenu02967ImplArch(self, ...)
end

ShowMapTeleporterToolsMenu02967ImplArch = function(self, owner)
        local originalFlyout = self.ShowMapTeleporterFlyout02969
        if type(originalFlyout) ~= "function" then return baseTools(self, owner) end
        local injected = false
        self.ShowMapTeleporterFlyout02969 = function(travel, titleText, items, flyoutOwner, contextMode)
            if not injected and tostring(titleText or "") == "TOOLS" and type(items) == "table" then
                injected = true
                local market = EPC.MarketPriceChecker
                local health = market and market:GetLiveMarketHealth029687() or { freshTraders = 0, traders = 0 }
                local state = routeState()
                items[#items + 1] = {
                    label = string.format("Live Market: %d/%d Traders Fresh", health.freshTraders or 0, health.traders or 0),
                    action = function() if EPC.MarketPriceChecker then EPC.MarketPriceChecker:PrintLiveMarketStatus029687() end end,
                }
                items[#items + 1] = {
                    label = "Scan Current Guild Trader (TTC)",
                    enabled = health.ttc == true,
                    action = function() if EPC.MarketPriceChecker then EPC.MarketPriceChecker:StartCurrentTraderFullScan029687(true) end end,
                }
                items[#items + 1] = {
                    label = "Auto TTC Scan: " .. ((EPC.saved and EPC.saved.marketLiveAutoScanTTC029687 ~= false) and "ON" or "OFF"),
                    selected = EPC.saved and EPC.saved.marketLiveAutoScanTTC029687 ~= false,
                    action = function()
                        EPC.saved.marketLiveAutoScanTTC029687 = not (EPC.saved.marketLiveAutoScanTTC029687 ~= false)
                        if EPC.Print then EPC:Print("Live Market auto TTC scan " .. (EPC.saved.marketLiveAutoScanTTC029687 and "enabled." or "disabled.")) end
                    end,
                }
                items[#items + 1] = {
                    label = state.active and "Resume Guild Trader Scan Route" or "Start Guild Trader Scan Route",
                    action = function() if EPC.MarketPriceChecker then EPC.MarketPriceChecker:StartTraderRoute029687(false) end end,
                }
                items[#items + 1] = {
                    label = "Next Guild Trader Hub",
                    enabled = state.active == true and state.paused ~= true,
                    action = function() if EPC.MarketPriceChecker then EPC.MarketPriceChecker:NextTraderHub029687() end end,
                }
                items[#items + 1] = {
                    label = state.paused and "Resume Trader Route" or "Pause Trader Route",
                    enabled = state.active == true,
                    action = function() if EPC.MarketPriceChecker then EPC.MarketPriceChecker:PauseTraderRoute029687(not state.paused) end end,
                }
            end
            return originalFlyout(travel, titleText, items, flyoutOwner, contextMode)
        end

        local ok, result = pcall(baseTools, self, owner)
        self.ShowMapTeleporterFlyout02969 = originalFlyout
        if not ok then
            if EPC and type(EPC.Print) == "function" then EPC:Print("Live Market Teleporter tools failed: " .. tostring(result)) end
            return false
        end
        return result
    end
end

function M:InitializeLiveMarket029687()
    if self.marketLiveInitialized029687 then return end
    self.marketLiveInitialized029687 = true
    self.marketLiveAlerted029687 = {}
    healthRoot()
    liveCache()
    watchRoot()
    routeState()
    installTeleporterTools()

    if EVENT_MANAGER and EVENT_OPEN_TRADING_HOUSE ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceLiveEngine","Open",EVENT_OPEN_TRADING_HOUSE, function()
            if not EPC.MarketPriceChecker then return end
            local market = EPC.MarketPriceChecker
            market:UpdateTraderHealth029687(currentTraderContext(), false)
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if EPC.MarketPriceChecker then EPC.MarketPriceChecker:MaybeAutoScanCurrentTrader029687() end
                end, 850)
            else
                market:MaybeAutoScanCurrentTrader029687()
            end
        end)
    end

    if EVENT_MANAGER and EVENT_TRADING_HOUSE_RESPONSE_RECEIVED ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceLiveEngine","Response",EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType)
            local market = EPC and EPC.MarketPriceChecker
            if not market then return end
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    if EPC.MarketPriceChecker then EPC.MarketPriceChecker:HandleTradingHouseResponse029687(responseType) end
                end, 25)
            else
                market:HandleTradingHouseResponse029687(responseType)
            end
        end)
    end

    if EVENT_MANAGER and EVENT_CLOSE_TRADING_HOUSE ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceLiveEngine","Close",EVENT_CLOSE_TRADING_HOUSE, function()
            local market = EPC and EPC.MarketPriceChecker
            if not market then return end
            if market.marketLiveScanSession029687 then
                market:ImportCurrentTTCGuild029687("TTC PARTIAL SCAN")
                market.marketLiveScanSession029687 = nil
            end
        end)
    end

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local market = EPC and EPC.MarketPriceChecker
            if not market then return end
            if type(market.ImportTTCTraderHistory029683) == "function" then market:ImportTTCTraderHistory029683(true) end
            market:PruneLiveMarketCache029687()
        end, 4200)
    end
end

SLASH_COMMANDS = SLASH_COMMANDS or {}
SLASH_COMMANDS["/easmarketlive"] = function()
    if EPC.MarketPriceChecker then EPC.MarketPriceChecker:PrintLiveMarketStatus029687() end
end

SLASH_COMMANDS["/easmarketscan"] = function(text)
    local market = EPC.MarketPriceChecker
    if not market then return end
    local command = lower(text)
    if command == "start" then
        market:StartTraderRoute029687(true)
    elseif command == "next" then
        market:NextTraderHub029687()
    elseif command == "pause" then
        market:PauseTraderRoute029687(true)
    elseif command == "resume" then
        local state = routeState()
        if state.active then market:PauseTraderRoute029687(false) else market:StartTraderRoute029687(false) end
    elseif command == "reset" then
        market:ResetTraderRoute029687()
    elseif command == "current" or command == "scan" then
        market:StartCurrentTraderFullScan029687(true)
    else
        market:PrintLiveMarketStatus029687()
        market:PrintRoutePosition029687()
        if EPC.Print then EPC:Print("/easmarketscan start | current | next | pause | resume | reset") end
    end
end

SLASH_COMMANDS["/easwatch"] = function(text)
    local market = EPC.MarketPriceChecker
    if not market then return end
    local command = lower(text)
    if command == "" or command == "list" then
        market:PrintWatchlist029687()
    elseif command == "remove" then
        market:RemoveHoveredWatch029687()
    elseif command == "clear" then
        EPC.saved.marketLiveWatchlist029687 = {}
        if EPC.Print then EPC:Print("Market watchlist cleared.") end
    else
        market:AddHoveredWatch029687(tonumber(text))
    end
end

if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
    EPC.Runtime:RegisterEvent("MarketPriceLiveEngine","Activated",EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_PLAYER_ACTIVATED)
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                if EPC.MarketPriceChecker then EPC.MarketPriceChecker:InitializeLiveMarket029687() end
            end, 900)
        elseif EPC.MarketPriceChecker then
            EPC.MarketPriceChecker:InitializeLiveMarket029687()
        end
    end)
end

EPC.marketPriceLiveEngine029687 = true
-- END ABSORBED: MarketPriceLiveEngineFix.lua

-- BEGIN ABSORBED: MarketPriceNativeTraderScanFix.lua
-- ESO Adventurer Suite
-- v0.29.688 native Guild Trader full-scan fallback.
--
-- TTC is optional. When the Tamriel Trade Centre addon runtime is present, EAS can
-- continue using TTC's mature Scan All implementation. When TTC is absent, EAS
-- performs the same store-page traversal through ESO's public Trading House API,
-- obeying the native cooldown and consuming EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED.
-- This fixes Live Market being limited to the one visible 50-item page when TTC
-- is not installed/enabled.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._nativeTraderScan029688 then return end
M._nativeTraderScan029688 = true

local NAME = (EPC.name or "ESOAdventurerSuite") .. "_NativeTraderScan029688"
local GREEN = "|c66FF66"
local GOLD = "|cFFD700"
local RESET = "|r"

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function now()
    if type(GetTimeStamp) ~= "function" then return 0 end
    local ok, value = pcall(GetTimeStamp)
    return ok and (safeNumber(value) or 0) or 0
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(clean(value))
end

local function currentContext()
    local guildId, guildName = 0, ""
    if type(GetCurrentTradingHouseGuildDetails) == "function" then
        local ok, id, name = pcall(GetCurrentTradingHouseGuildDetails)
        if ok then guildId, guildName = safeNumber(id) or 0, clean(name) end
    end

    local kioskId = nil
    local ttc = rawget(_G, "TamrielTradeCentre")
    if type(ttc) == "table" and type(ttc.GetCurrentKioskID) == "function" then
        local ok, id = pcall(ttc.GetCurrentKioskID, ttc)
        if ok then kioskId = safeNumber(id) end
    end

    local traderName, locationName, zoneName = "", "", ""
    if type(GetUnitName) == "function" then
        local ok, value = pcall(GetUnitName, "interact")
        if ok then traderName = clean(value) end
    end
    if traderName == "" and type(GetRawUnitName) == "function" then
        local ok, value = pcall(GetRawUnitName, "interact")
        if ok then traderName = clean(value) end
    end
    if type(GetPlayerLocationName) == "function" then
        local ok, value = pcall(GetPlayerLocationName)
        if ok then locationName = clean(value) end
    end
    if type(GetPlayerActiveZoneName) == "function" then
        local ok, value = pcall(GetPlayerActiveZoneName)
        if ok then zoneName = clean(value) end
    end

    return {
        guildId = guildId,
        guildName = guildName,
        kioskId = kioskId,
        traderName = traderName,
        locationName = locationName,
        zoneName = zoneName,
    }
end

local function hasTTCRuntime()
    local ttc = rawget(_G, "TamrielTradeCentre")
    return type(ttc) == "table" and type(ttc.StartNewGuildListingScan) == "function"
end

local function routeIsActive()
    local state = EPC.saved and EPC.saved.marketLiveRoute029687
    return type(state) == "table" and state.active == true and state.paused ~= true
end

-- Count location health even without TTC kiosk ids. The original Live Market
-- health table keyed locations only by TTC KioskLocationID, which made a native
-- observation display 0/0 locations despite having a real ESO area + zone.
local baseUpdateHealth029688 = UpdateTraderHealth029687ImplArch
if type(baseUpdateHealth029688) == "function" then
    UpdateTraderHealth029687ImplArch = function(self, context, fullScan, rows, pages)
        local result = baseUpdateHealth029688(self, context, fullScan, rows, pages)
        context = context or currentContext()
        if not safeNumber(context.kioskId) then
            local locationName = clean(context.locationName)
            local zoneName = clean(context.zoneName)
            if locationName ~= "" or zoneName ~= "" then
                EPC.saved = EPC.saved or {}
                EPC.saved.marketLiveTraderHealth029687 = type(EPC.saved.marketLiveTraderHealth029687) == "table"
                    and EPC.saved.marketLiveTraderHealth029687 or { traders = {}, locations = {} }
                local root = EPC.saved.marketLiveTraderHealth029687
                root.locations = type(root.locations) == "table" and root.locations or {}
                local key = "native:" .. lower(locationName) .. "|" .. lower(zoneName)
                local record = root.locations[key]
                if type(record) ~= "table" then record = {} root.locations[key] = record end
                record.locationName = locationName
                record.zoneName = zoneName
                record.lastSeen = now()
                if fullScan then record.lastFullScan = record.lastSeen end
            end
        end
        return result
    end
end

function M:IsNativeTraderScanAvailable029688()
    return type(ExecuteTradingHouseSearch) == "function"
        and type(GetTradingHouseSearchResultsInfo) == "function"
        and type(GetTradingHouseSearchResultItemInfo) == "function"
        and type(GetTradingHouseSearchResultItemLink) == "function"
        and EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED ~= nil
end

function M:CancelNativeTraderScan029688(reason)
    local session = self.marketLiveScanSession029687
    if type(session) ~= "table" or session.provider ~= "EAS NATIVE" then return false end
    self.marketLiveScanSession029687 = nil
    if EPC and type(EPC.Print) == "function" and reason then
        EPC:Print("Live Market native scan stopped: " .. tostring(reason) .. ".")
    end
    return true
end

function M:FinishNativeTraderScan029688(reason)
    local session = self.marketLiveScanSession029687
    if type(session) ~= "table" or session.provider ~= "EAS NATIVE" then return false end
    local ctx = currentContext()
    local rows = math.floor(safeNumber(session.rows) or 0)
    local pages = math.floor(safeNumber(session.pages) or 0)
    local startedAt = safeNumber(session.startedAt) or 0

    self.marketLiveScanSession029687 = nil
    if type(self.UpdateTraderHealth029687) == "function" then
        self:UpdateTraderHealth029687(ctx, true, rows, pages)
    end
    if startedAt > 0 and type(self.PurgeTraderListingsBefore029687) == "function" then
        self:PurgeTraderListingsBefore029687(ctx, startedAt)
    end
    if type(self.PruneLiveMarketCache029687) == "function" then self:PruneLiveMarketCache029687() end

    if EPC and type(EPC.Print) == "function" then
        EPC:Print(GREEN .. "Live Market native full scan complete" .. RESET .. ": " ..
            (clean(ctx.guildName) ~= "" and ctx.guildName or clean(session.guildName) ~= "" and session.guildName or "Guild Trader") ..
            " - " .. tostring(rows) .. " listing" .. (rows == 1 and "" or "s") ..
            " across " .. tostring(pages) .. " page" .. (pages == 1 and "" or "s") ..
            (reason and (" [" .. tostring(reason) .. "]") or "") .. ".")
    end
    return true
end

function M:RequestNativeTraderPage029688(page)
    local session = self.marketLiveScanSession029687
    if type(session) ~= "table" or session.provider ~= "EAS NATIVE" then return false end
    if session.requestQueued == true then return true end

    page = math.max(0, math.floor(safeNumber(page) or 0))
    session.nextPage = page
    session.requestQueued = true

    local function attempt()
        local market = EPC and EPC.MarketPriceChecker
        local active = market and market.marketLiveScanSession029687
        if type(active) ~= "table" or active.provider ~= "EAS NATIVE" then return end
        active.requestQueued = false

        local ctx = currentContext()
        if clean(ctx.guildName) == "" then
            market:CancelNativeTraderScan029688("Guild Trader closed")
            return
        end
        if safeNumber(active.guildId) and safeNumber(active.guildId) > 0 and safeNumber(ctx.guildId)
            and safeNumber(ctx.guildId) > 0 and math.floor(active.guildId) ~= math.floor(ctx.guildId) then
            market:CancelNativeTraderScan029688("Guild Trader changed")
            return
        end

        local cooldown = 0
        if type(GetTradingHouseCooldownRemaining) == "function" then
            local ok, value = pcall(GetTradingHouseCooldownRemaining)
            if ok then cooldown = math.max(0, math.floor(safeNumber(value) or 0)) end
        end
        if cooldown > 0 then
            active.requestQueued = true
            if type(zo_callLater) == "function" then zo_callLater(attempt, cooldown + 350) end
            return
        end

        local search = rawget(_G, "TRADING_HOUSE_SEARCH")
        if type(search) == "table" and type(search.CanDoCommonOperation) == "function" then
            local ok, canDo = pcall(search.CanDoCommonOperation, search)
            if ok and canDo == false then
                active.requestQueued = true
                if type(zo_callLater) == "function" then zo_callLater(attempt, 350) end
                return
            end
        end

        active.awaitingPage = page
        active.lastRequestAt = now()
        local ok, err = pcall(ExecuteTradingHouseSearch, page, TRADING_HOUSE_SORT_SALE_PRICE, true, false)
        if not ok then
            active.awaitingPage = nil
            active.retries = (safeNumber(active.retries) or 0) + 1
            if active.retries <= 3 and type(zo_callLater) == "function" then
                active.requestQueued = true
                zo_callLater(attempt, 1500)
            else
                market:CancelNativeTraderScan029688("ESO rejected the search request: " .. tostring(err))
            end
        else
            active.retries = 0
        end
    end

    if type(zo_callLater) == "function" then zo_callLater(attempt, 0) else attempt() end
    return true
end

function M:StartNativeTraderFullScan029688(force)
    if self.marketLiveScanSession029687 then
        if EPC and type(EPC.Print) == "function" then EPC:Print("A Live Market trader scan is already running.") end
        return false
    end
    if not self:IsNativeTraderScanAvailable029688() then
        if EPC and type(EPC.Print) == "function" then EPC:Print("ESO's native Guild Trader search API is unavailable on this client.") end
        return false
    end

    local ctx = currentContext()
    if clean(ctx.guildName) == "" then
        if EPC and type(EPC.Print) == "function" then EPC:Print("Open a Guild Trader first, then start the Live Market scan.") end
        return false
    end
    if force ~= true and type(self.IsCurrentTraderFresh029687) == "function" and self:IsCurrentTraderFresh029687() then
        if EPC and type(EPC.Print) == "function" then EPC:Print(ctx.guildName .. " was fully scanned recently; skipping duplicate scan.") end
        return true
    end

    -- Full-store means no category/text/price restrictions. This intentionally
    -- takes over the current Guild Trader search only when the user explicitly
    -- requests a scan or while the Live Trader Route is active.
    if type(ClearAllTradingHouseSearchTerms) == "function" then pcall(ClearAllTradingHouseSearchTerms) end

    self.marketLiveScanSession029687 = {
        provider = "EAS NATIVE",
        nativeScan = true,
        guildId = ctx.guildId,
        guildName = ctx.guildName,
        startedAt = now(),
        pages = 0,
        rows = 0,
        seenPages = {},
        requestQueued = false,
        awaitingPage = nil,
        retries = 0,
    }

    if EPC and type(EPC.Print) == "function" then
        EPC:Print(GOLD .. "Live Market" .. RESET .. ": EAS native full-store scan started for " .. ctx.guildName .. ". TTC is not required.")
    end
    return self:RequestNativeTraderPage029688(0)
end

-- Keep TTC as the preferred provider when its addon runtime is actually present,
-- but never make TTC a requirement for EAS full-store scans.
local baseStartFullScan029688 = StartCurrentTraderFullScan029687ImplArch
StartCurrentTraderFullScan029687ImplArch = function(self, force)
    if hasTTCRuntime() and type(baseStartFullScan029688) == "function" then
        return baseStartFullScan029688(self, force)
    end
    return self:StartNativeTraderFullScan029688(force)
end

-- The original response handler owns TTC scan bookkeeping. Native scans use the
-- more precise SEARCH_RESULTS_RECEIVED event (which includes page + hasMorePages),
-- so bypass the TTC completion heuristic while an EAS-native session is active.
local baseHandleResponse029688 = HandleTradingHouseResponse029687ImplArch
if type(baseHandleResponse029688) == "function" then
    HandleTradingHouseResponse029687ImplArch = function(self, responseType)
        local session = self.marketLiveScanSession029687
        if type(session) == "table" and session.provider == "EAS NATIVE" then return end
        return baseHandleResponse029688(self, responseType)
    end
end

-- Auto full scanning without TTC is intentionally restricted to an active Trader
-- Route. Opening a store during normal shopping still captures the visible search
-- results, but EAS will not clear the shopper's filters just because TTC is absent.
local baseMaybeAuto029688 = MaybeAutoScanCurrentTrader029687ImplArch
MaybeAutoScanCurrentTrader029687ImplArch = function(self)
    if hasTTCRuntime() and type(baseMaybeAuto029688) == "function" then
        return baseMaybeAuto029688(self)
    end
    if not EPC.saved or EPC.saved.marketLiveAutoScanTTC029687 == false then return false end
    if not routeIsActive() then return false end
    if self.marketLiveScanSession029687 then return false end
    return self:StartNativeTraderFullScan029688(false)
end

if EVENT_MANAGER and EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED ~= nil then
    EPC.Runtime:RegisterEvent("MarketPriceNativeScan","Results",EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED,
        function(_, guildId, numItemsOnPage, currentPage, hasMorePages)
            local market = EPC and EPC.MarketPriceChecker
            local session = market and market.marketLiveScanSession029687
            if type(session) ~= "table" or session.provider ~= "EAS NATIVE" then return end

            local expectedGuild = safeNumber(session.guildId)
            local receivedGuild = safeNumber(guildId)
            if expectedGuild and expectedGuild > 0 and receivedGuild and receivedGuild > 0
                and math.floor(expectedGuild) ~= math.floor(receivedGuild) then return end

            currentPage = math.max(0, math.floor(safeNumber(currentPage) or 0))
            local pageKey = tostring(currentPage)
            if session.seenPages[pageKey] then return end
            session.seenPages[pageKey] = true
            session.awaitingPage = nil

            local captured = 0
            if type(market.CaptureCurrentSearchPage029687) == "function" then
                local ok, value = pcall(market.CaptureCurrentSearchPage029687, market, "EAS NATIVE FULL SCAN")
                if ok then captured = math.max(0, math.floor(safeNumber(value) or 0)) end
            end
            if captured <= 0 then captured = math.max(0, math.floor(safeNumber(numItemsOnPage) or 0)) end
            session.rows = (safeNumber(session.rows) or 0) + captured
            session.pages = math.max(safeNumber(session.pages) or 0, currentPage + 1)

            if currentPage > 0 and currentPage % 10 == 9 and EPC and type(EPC.Print) == "function" then
                EPC:Print("Live Market native scan: " .. tostring(currentPage + 1) .. " pages / " .. tostring(math.floor(session.rows)) .. " listings captured...")
            end

            if hasMorePages == true then
                market:RequestNativeTraderPage029688(currentPage + 1)
            else
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if EPC.MarketPriceChecker then EPC.MarketPriceChecker:FinishNativeTraderScan029688("EAS NATIVE") end
                    end, 100)
                else
                    market:FinishNativeTraderScan029688("EAS NATIVE")
                end
            end
        end)
end

-- Replace the status text so a missing TTC addon is reported as an optional
-- provider choice, not as a broken/required dependency.
local baseHealth029688 = GetLiveMarketHealth029687ImplArch
if type(baseHealth029688) == "function" then
    GetLiveMarketHealth029687ImplArch = function(self)
        local health = baseHealth029688(self)
        health = type(health) == "table" and health or {}
        health.nativeScan = self:IsNativeTraderScanAvailable029688()
        health.ttc = hasTTCRuntime()
        health.scanProvider = health.ttc and "TTC + EAS Native" or (health.nativeScan and "EAS Native" or "Unavailable")
        return health
    end
end

PrintLiveMarketStatus029687ImplArch = function(self)
    local h = self:GetLiveMarketHealth029687()
    local state = EPC.saved and EPC.saved.marketLiveRoute029687
    local routeText = type(state) == "table" and state.active == true
        and (state.paused == true and "route paused" or "route active") or "route idle"
    if EPC and type(EPC.Print) == "function" then
        EPC:Print(string.format(
            "Live Market: %d/%d traders fresh, %d/%d locations fresh, %d cached items, scanner %s, %s.",
            safeNumber(h.freshTraders) or 0, safeNumber(h.traders) or 0,
            safeNumber(h.freshLocations) or 0, safeNumber(h.locations) or 0,
            safeNumber(h.items) or 0, tostring(h.scanProvider or "Unavailable"), routeText))
    end
end

-- Patch Teleporter > Tools after the v0.29.687 wrapper has installed. This makes
-- the full-scan button available whether TTC is installed or not and removes the
-- misleading TTC-required wording from the route controls.
local function patchTeleporterTools()
    local Travel = EPC and EPC.Travel
    if not Travel or Travel._nativeMarketTools029688 or type(Travel.ShowMapTeleporterToolsMenu02967) ~= "function" then return end
    Travel._nativeMarketTools029688 = true
    local baseTools = ShowMapTeleporterToolsMenu02967ImplArch

    ShowMapTeleporterToolsMenu02967ImplArch = function(self, owner)
        local originalFlyout = self.ShowMapTeleporterFlyout02969
        if type(originalFlyout) ~= "function" then return baseTools(self, owner) end
        self.ShowMapTeleporterFlyout02969 = function(travel, titleText, items, flyoutOwner, contextMode)
            if tostring(titleText or "") == "TOOLS" and type(items) == "table" then
                local market = EPC.MarketPriceChecker
                local ttcReady = hasTTCRuntime()
                for _, item in ipairs(items) do
                    if type(item) == "table" then
                        local label = tostring(item.label or "")
                        if label == "Scan Current Guild Trader (TTC)" then
                            item.label = ttcReady and "Scan Current Guild Trader (TTC)" or "Scan Current Guild Trader (EAS Native)"
                            item.enabled = true
                        elseif label:find("Auto TTC Scan:", 1, true) == 1 then
                            item.label = label:gsub("Auto TTC Scan:", "Auto Full Scan:", 1)
                        end
                    end
                end
            end
            return originalFlyout(travel, titleText, items, flyoutOwner, contextMode)
        end
        local ok, result = pcall(baseTools, self, owner)
        self.ShowMapTeleporterFlyout02969 = originalFlyout
        if not ok then
            if EPC and type(EPC.Print) == "function" then EPC:Print("Native Live Market Teleporter tools failed: " .. tostring(result)) end
            return false
        end
        return result
    end
end

if EVENT_MANAGER and EVENT_PLAYER_ACTIVATED ~= nil then
    EPC.Runtime:RegisterEvent("MarketPriceNativeScan","Activated",EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_PLAYER_ACTIVATED)
        if type(zo_callLater) == "function" then zo_callLater(patchTeleporterTools, 1800) else patchTeleporterTools() end
    end)
end

EPC.marketPriceNativeTraderScan029688 = true
-- END ABSORBED: MarketPriceNativeTraderScanFix.lua

-- BEGIN ABSORBED: MarketPriceLiveControlPanelFix.lua
-- ESO Adventurer Suite
-- v0.29.689 button-driven Live Market control center.
-- Makes the normal market scanning/route workflow fully usable without slash commands.

local EPC = ESOProgressionCoach
if not EPC or not EPC.MarketPriceChecker then return end
local M = EPC.MarketPriceChecker
if M._liveMarketControlPanel029689 then return end
M._liveMarketControlPanel029689 = true

local GOLD = "|cFFD700"
local GREEN = "|c66FF66"
local CYAN = "|c66CCFF"
local YELLOW = "|cFFFF66"
local GREY = "|cA0A0A0"
local WHITE = "|cFFFFFF"
local RESET = "|r"
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_MarketControl029689"

local function safeNumber(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

local function clean(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and type(formatted) == "string" and formatted ~= "" then text = formatted end
    end
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[%c]+", " "):gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function routeState()
    EPC.saved = EPC.saved or {}
    local state = EPC.saved.marketLiveRoute029687
    if type(state) ~= "table" then
        state = { active = false, paused = false, index = 1, visited = {} }
        EPC.saved.marketLiveRoute029687 = state
    end
    state.visited = type(state.visited) == "table" and state.visited or {}
    return state
end

local function setButtonText(button, text)
    if button and type(button.SetText) == "function" then button:SetText(text) end
end

local function setEnabled(button, enabled)
    if not button then return end
    if type(button.SetEnabled) == "function" then button:SetEnabled(enabled == true) end
    if type(button.SetAlpha) == "function" then button:SetAlpha(enabled == true and 1 or 0.45) end
end

local function createButton(parent, name, text, x, y, width, height, callback)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:SetDimensions(width, height)
    button:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    if type(button.SetFont) == "function" then button:SetFont("ZoFontGameBold") end
    button:SetText(text)
    button:SetHandler("OnClicked", function()
        if callback then callback() end
        if EPC and EPC.MarketPriceChecker and EPC.MarketPriceChecker.RefreshLiveMarketControlPanel029689 then
            EPC.MarketPriceChecker:RefreshLiveMarketControlPanel029689()
        end
    end)

    local bg = WINDOW_MANAGER:CreateControl(name .. "BG", button, CT_BACKDROP)
    bg:SetAnchorFill(button)
    bg:SetCenterColor(0.06, 0.06, 0.075, 0.96)
    bg:SetEdgeColor(0.72, 0.55, 0.12, 0.92)
    bg:SetMouseEnabled(false)
    if type(bg.SetDrawLevel) == "function" then bg:SetDrawLevel(0) end
    return button
end

function M:EnsureLiveMarketControlPanel029689()
    if self.liveMarketControlPanel029689 then return self.liveMarketControlPanel029689 end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local panel = WINDOW_MANAGER:CreateControl("EASLiveMarketControlPanel029689", GuiRoot, CT_CONTROL)
    panel:SetDimensions(700, 520)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    panel:SetMouseEnabled(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    if type(panel.SetDrawTier) == "function" and DT_HIGH ~= nil then panel:SetDrawTier(DT_HIGH) end
    if type(panel.SetDrawLayer) == "function" and DL_OVERLAY ~= nil then panel:SetDrawLayer(DL_OVERLAY) end
    if type(panel.SetDrawLevel) == "function" then panel:SetDrawLevel(12500) end

    local bg = WINDOW_MANAGER:CreateControl("EASLiveMarketControlPanelBG029689", panel, CT_BACKDROP)
    bg:SetAnchorFill(panel)
    bg:SetCenterColor(0.012, 0.012, 0.02, 0.985)
    bg:SetEdgeColor(0.88, 0.67, 0.12, 1)
    bg:SetMouseEnabled(false)

    local title = WINDOW_MANAGER:CreateControl("EASLiveMarketControlTitle029689", panel, CT_LABEL)
    title:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, 16)
    title:SetFont("ZoFontWinH2")
    title:SetColor(1, 0.82, 0.2, 1)
    title:SetText("ESO ADVENTURER SUITE — LIVE MARKET")

    local subtitle = WINDOW_MANAGER:CreateControl("EASLiveMarketControlSubtitle029689", panel, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, 48)
    subtitle:SetDimensions(650, 42)
    subtitle:SetFont("ZoFontGame")
    subtitle:SetColor(0.82, 0.82, 0.82, 1)
    subtitle:SetText("No slash commands required. Open a Guild Trader and use SCAN CURRENT STORE, or start the trader-hub route below.")

    local close = WINDOW_MANAGER:CreateControl("EASLiveMarketControlClose029689", panel, CT_BUTTON)
    close:SetDimensions(34, 28)
    close:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -10, 10)
    close:SetFont("ZoFontGameBold")
    close:SetText("X")
    close:SetHandler("OnClicked", function() panel:SetHidden(true) end)

    local statusTitle = WINDOW_MANAGER:CreateControl("EASLiveMarketControlStatusTitle029689", panel, CT_LABEL)
    statusTitle:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, 96)
    statusTitle:SetFont("ZoFontGameBold")
    statusTitle:SetColor(0.4, 0.8, 1, 1)
    statusTitle:SetText("LIVE MARKET STATUS")

    local status = WINDOW_MANAGER:CreateControl("EASLiveMarketControlStatus029689", panel, CT_LABEL)
    status:SetAnchor(TOPLEFT, panel, TOPLEFT, 20, 122)
    status:SetDimensions(655, 112)
    status:SetFont("ZoFontGame")
    status:SetColor(1, 1, 1, 1)
    status:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    status:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local scan = createButton(panel, "EASLiveMarketScanButton029689", "SCAN CURRENT STORE", 20, 250, 315, 42, function()
        if M.StartCurrentTraderFullScan029687 then M:StartCurrentTraderFullScan029687(true) end
    end)
    local auto = createButton(panel, "EASLiveMarketAutoButton029689", "AUTO FULL SCAN: ON", 365, 250, 315, 42, function()
        EPC.saved = EPC.saved or {}
        EPC.saved.marketLiveAutoScanTTC029687 = not (EPC.saved.marketLiveAutoScanTTC029687 ~= false)
    end)
    local start = createButton(panel, "EASLiveMarketRouteStart029689", "START TRADER ROUTE", 20, 304, 315, 42, function()
        if M.StartTraderRoute029687 then M:StartTraderRoute029687(true) end
    end)
    local nextHub = createButton(panel, "EASLiveMarketRouteNext029689", "NEXT TRADER HUB", 365, 304, 315, 42, function()
        if M.NextTraderHub029687 then M:NextTraderHub029687() end
    end)
    local pause = createButton(panel, "EASLiveMarketRoutePause029689", "PAUSE ROUTE", 20, 358, 315, 42, function()
        local state = routeState()
        if M.PauseTraderRoute029687 then M:PauseTraderRoute029687(state.paused ~= true) end
    end)
    local reset = createButton(panel, "EASLiveMarketRouteReset029689", "RESET ROUTE", 365, 358, 315, 42, function()
        if M.ResetTraderRoute029687 then M:ResetTraderRoute029687() end
    end)
    local refresh = createButton(panel, "EASLiveMarketRefresh029689", "REFRESH STATUS", 20, 412, 315, 42, function() end)
    local prune = createButton(panel, "EASLiveMarketPrune029689", "PRUNE OLD MARKET DATA", 365, 412, 315, 42, function()
        if M.PruneLiveMarketCache029687 then M:PruneLiveMarketCache029687() end
        if M.PruneLiveMarketHistory029688 then M:PruneLiveMarketHistory029688() end
    end)

    local hint = WINDOW_MANAGER:CreateControl("EASLiveMarketControlHint029689", panel, CT_LABEL)
    hint:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 20, -22)
    hint:SetDimensions(650, 34)
    hint:SetFont("ZoFontGameSmall")
    hint:SetColor(0.63, 0.63, 0.63, 1)
    hint:SetText("Route flow: START ROUTE → travel → open each Guild Trader → scan completes → NEXT TRADER HUB. Drag this panel to move it.")

    panel:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and type(control.StartMoving) == "function" then control:StartMoving() end
    end)
    panel:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and type(control.StopMovingOrResizing) == "function" then control:StopMovingOrResizing() end
    end)

    panel.status = status
    panel.scan = scan
    panel.auto = auto
    panel.start = start
    panel.nextHub = nextHub
    panel.pause = pause
    panel.reset = reset
    panel.refresh = refresh
    panel.prune = prune
    panel:SetHidden(true)
    self.liveMarketControlPanel029689 = panel
    return panel
end

function M:RefreshLiveMarketControlPanel029689()
    local panel = self:EnsureLiveMarketControlPanel029689()
    if not panel then return end

    local health = type(self.GetLiveMarketHealth029687) == "function" and self:GetLiveMarketHealth029687() or {}
    local state = routeState()
    local route = type(self.GetTraderHubRoute029687) == "function" and self:GetTraderHubRoute029687() or {}
    if type(route) ~= "table" then route = {} end
    local routeCount = #route
    local index = math.max(1, math.floor(safeNumber(state.index) or 1))
    if routeCount > 0 then index = math.min(index, routeCount) end

    local scanner = clean(health.scanProvider)
    if scanner == "" then scanner = health.ttc == true and "TTC + EAS" or "EAS Native" end
    local routeText = "Idle"
    if state.active == true then routeText = state.paused == true and "Paused" or "Active" end
    if routeCount > 0 and state.active == true then routeText = routeText .. " — hub " .. tostring(index) .. "/" .. tostring(routeCount) end

    local session = self.marketLiveScanSession029687
    local scanText = "No full-store scan running"
    if type(session) == "table" then
        local provider = clean(session.provider)
        if provider == "" then provider = scanner end
        local guild = clean(session.guildName)
        if guild == "" then guild = "Current Guild Trader" end
        scanText = string.format("%sScanning%s %s — %s — %d pages / %d listings",
            YELLOW, RESET, guild, provider,
            math.floor(safeNumber(session.pages) or 0), math.floor(safeNumber(session.rows) or 0))
    end

    panel.status:SetText(table.concat({
        string.format("%sScanner:%s %s%s%s", CYAN, RESET, WHITE, scanner, RESET),
        string.format("%sFresh traders:%s %d/%d    %sFresh locations:%s %d/%d    %sCached items:%s %d",
            GREEN, RESET, safeNumber(health.freshTraders) or 0, safeNumber(health.traders) or 0,
            GREEN, RESET, safeNumber(health.freshLocations) or 0, safeNumber(health.locations) or 0,
            GOLD, RESET, safeNumber(health.items) or 0),
        string.format("%sRoute:%s %s", CYAN, RESET, routeText),
        scanText,
    }, "\n"))

    local scanActive = type(session) == "table"
    setButtonText(panel.scan, scanActive and "SCAN IN PROGRESS..." or "SCAN CURRENT STORE")
    setEnabled(panel.scan, not scanActive)

    local autoEnabled = EPC.saved and EPC.saved.marketLiveAutoScanTTC029687 ~= false
    setButtonText(panel.auto, "AUTO FULL SCAN: " .. (autoEnabled and "ON" or "OFF"))
    setButtonText(panel.start, state.active == true and "RESTART TRADER ROUTE" or "START TRADER ROUTE")
    setButtonText(panel.pause, state.paused == true and "RESUME ROUTE" or "PAUSE ROUTE")
    setEnabled(panel.nextHub, state.active == true and state.paused ~= true and routeCount > 0)
    setEnabled(panel.pause, state.active == true)
    setEnabled(panel.reset, state.active == true or routeCount > 0)
end

function M:OpenLiveMarketControlPanel029689()
    local panel = self:EnsureLiveMarketControlPanel029689()
    if not panel then return false end
    panel:SetHidden(false)
    self:RefreshLiveMarketControlPanel029689()

    panel.refreshGeneration029689 = (panel.refreshGeneration029689 or 0) + 1
    local generation = panel.refreshGeneration029689
    local function tick()
        if not panel or panel:IsHidden() or panel.refreshGeneration029689 ~= generation then return end
        if EPC and EPC.MarketPriceChecker and EPC.MarketPriceChecker.RefreshLiveMarketControlPanel029689 then
            EPC.MarketPriceChecker:RefreshLiveMarketControlPanel029689()
        end
        if type(zo_callLater) == "function" then zo_callLater(tick, 1000) end
    end
    if type(zo_callLater) == "function" then zo_callLater(tick, 1000) end
    return true
end

function M:ToggleLiveMarketControlPanel029689()
    local panel = self:EnsureLiveMarketControlPanel029689()
    if not panel then return false end
    if panel:IsHidden() then return self:OpenLiveMarketControlPanel029689() end
    panel:SetHidden(true)
    return true
end

function M:EnsureLiveMarketTraderLauncher029689()
    if self.liveMarketTraderLauncher029689 then return self.liveMarketTraderLauncher029689 end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local parent = rawget(_G, "ZO_TradingHouse") or GuiRoot
    local button = WINDOW_MANAGER:CreateControl("EASLiveMarketTraderLauncher029689", parent, CT_BUTTON)
    button:SetDimensions(190, 34)
    button:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -36, 68)
    button:SetFont("ZoFontGameBold")
    button:SetText("EAS LIVE MARKET")
    button:SetHandler("OnClicked", function()
        if EPC and EPC.MarketPriceChecker then EPC.MarketPriceChecker:OpenLiveMarketControlPanel029689() end
    end)

    local bg = WINDOW_MANAGER:CreateControl("EASLiveMarketTraderLauncherBG029689", button, CT_BACKDROP)
    bg:SetAnchorFill(button)
    bg:SetCenterColor(0.025, 0.025, 0.035, 0.96)
    bg:SetEdgeColor(0.9, 0.68, 0.12, 1)
    bg:SetMouseEnabled(false)
    button:SetHidden(true)
    self.liveMarketTraderLauncher029689 = button
    return button
end

local function installTeleporterControlEntry()
    local Travel = EPC.Travel
    if not Travel or Travel._marketControlCenter029689 or type(Travel.ShowMapTeleporterToolsMenu02967) ~= "function" then return end
    Travel._marketControlCenter029689 = true
    local baseTools = ShowMapTeleporterToolsMenu02967ImplArch

    ShowMapTeleporterToolsMenu02967ImplArch = function(self, owner)
        local originalFlyout = self.ShowMapTeleporterFlyout02969
        if type(originalFlyout) ~= "function" then return baseTools(self, owner) end
        local injected = false
        self.ShowMapTeleporterFlyout02969 = function(travel, titleText, items, flyoutOwner, contextMode)
            if not injected and tostring(titleText or "") == "TOOLS" and type(items) == "table" then
                injected = true
                table.insert(items, 1, {
                    label = "LIVE MARKET CONTROL CENTER",
                    action = function()
                        if EPC and EPC.MarketPriceChecker then EPC.MarketPriceChecker:OpenLiveMarketControlPanel029689() end
                    end,
                })
                for _, item in ipairs(items) do
                    if type(item) == "table" and type(item.label) == "string" and item.label:find("^Live Market:") then
                        item.action = function()
                            if EPC and EPC.MarketPriceChecker then EPC.MarketPriceChecker:OpenLiveMarketControlPanel029689() end
                        end
                    end
                end
            end
            return originalFlyout(travel, titleText, items, flyoutOwner, contextMode)
        end
        local ok, result = pcall(baseTools, self, owner)
        self.ShowMapTeleporterFlyout02969 = originalFlyout
        if not ok then
            if EPC and type(EPC.Print) == "function" then EPC:Print("Live Market Control Center integration failed: " .. tostring(result)) end
            return false
        end
        return result
    end
end

if EVENT_MANAGER then
    if EVENT_OPEN_TRADING_HOUSE ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceControlPanel","Open",EVENT_OPEN_TRADING_HOUSE, function()
            local market = EPC and EPC.MarketPriceChecker
            if not market then return end
            local launcher = market:EnsureLiveMarketTraderLauncher029689()
            if launcher then launcher:SetHidden(false) end
        end)
    end
    if EVENT_CLOSE_TRADING_HOUSE ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceControlPanel","Close",EVENT_CLOSE_TRADING_HOUSE, function()
            local launcher = EPC and EPC.MarketPriceChecker and EPC.MarketPriceChecker.liveMarketTraderLauncher029689
            if launcher then launcher:SetHidden(true) end
        end)
    end
    if EVENT_PLAYER_ACTIVATED ~= nil then
        EPC.Runtime:RegisterEvent("MarketPriceControlPanel","Activated",EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(NAME .. "_Activated", EVENT_PLAYER_ACTIVATED)
            if type(zo_callLater) == "function" then
                zo_callLater(function()
                    installTeleporterControlEntry()
                    if EPC and EPC.MarketPriceChecker then EPC.MarketPriceChecker:EnsureLiveMarketTraderLauncher029689() end
                end, 2200)
            else
                installTeleporterControlEntry()
                M:EnsureLiveMarketTraderLauncher029689()
            end
        end)
    end
end

EPC.marketPriceLiveControlPanel029689 = true

-- END ABSORBED: MarketPriceLiveControlPanelFix.lua
