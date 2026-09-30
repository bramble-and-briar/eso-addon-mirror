-- ESO Adventurer Suite
-- Unified LibAddonMenu integration for the Suite Market Price Checker.
-- This extends the existing organized settings tree without issuing a second
-- RegisterOptionControls call for the Suite panel.

local EPC = ESOProgressionCoach
if not EPC or not EPC.Settings then return end
local S = EPC.Settings
local Market = EPC.MarketPriceChecker
if not Market then return end

if S._easMarketSettings029683 then return end
S._easMarketSettings029683 = true


local function buildMarketControls()
    return {
        {
            type = "description",
            title = "Live market pricing + located trader travel",
            text = "Reads installed LibEsoHubPrices and Tamriel Trade Centre data. Global market prices and exact trader locations are kept separate: aggregate price tables do not identify which kiosk owns the global minimum, so the Suite only shows a travel location when that exact listing was actually seen in a live Guild Trader search or in TTC's locally recorded scan history.",
            width = "full",
        },
        {
            type = "checkbox", name = "Enable Market Price Checker",
            getFunc = function() return EPC.saved.marketPriceCheckerEnabled029683 ~= false end,
            setFunc = function(v)
                EPC.saved.marketPriceCheckerEnabled029683 = v == true
                if v and Market.StartTTCSeenIndex029683 then Market:StartTTCSeenIndex029683(false) end
                if not v and Market.HideTravelButton029683 then Market:HideTravelButton029683() end
            end,
            default = EPC.defaults.marketPriceCheckerEnabled029683,
        },
        {
            type = "checkbox", name = "Show Suite market info in item tooltips",
            tooltip = "Shows global low/average/suggested pricing, source freshness, the lowest exact listing the Suite has actually located, and deal status where fresh data is available.",
            getFunc = function() return EPC.saved.marketPriceTooltipEnabled029683 ~= false end,
            setFunc = function(v)
                EPC.saved.marketPriceTooltipEnabled029683 = v == true
                Market.lastTooltipSignature = nil
                if not v and Market.HideTravelButton029683 then Market:HideTravelButton029683() end
            end,
            default = EPC.defaults.marketPriceTooltipEnabled029683,
        },
        {
            type = "checkbox", name = "Show TRAVEL button for located listings",
            tooltip = "When the Suite has a real kiosk/location for the located listing, shows a clickable TRAVEL button below the item tooltip and routes through the Suite's existing discovered-wayshrine travel path.",
            getFunc = function() return EPC.saved.marketPriceTravelEnabled029683 ~= false end,
            setFunc = function(v)
                EPC.saved.marketPriceTravelEnabled029683 = v == true
                if not v and Market.HideTravelButton029683 then Market:HideTravelButton029683() end
            end,
            default = EPC.defaults.marketPriceTravelEnabled029683,
        },
        {
            type = "dropdown", name = "Market price source",
            tooltip = "Prefer ESO-Hub is the Suite default: ESO-Hub supplies the primary aggregate price and TTC is shown as a fallback/cross-check when available. Freshest Available instead compares loaded dataset timestamps. Prefer Tamriel Trade Centre reverses the priority while retaining ESO-Hub as fallback/cross-check.",
            choices = { "Freshest Available", "Prefer ESO-Hub", "Prefer Tamriel Trade Centre" },
            choicesValues = { "FRESHEST", "ESOHUB", "TTC" },
            getFunc = function() return EPC.saved.marketPriceSource029683 or EPC.defaults.marketPriceSource029683 or "ESOHUB" end,
            setFunc = function(v) EPC.saved.marketPriceSource029683 = tostring(v or EPC.defaults.marketPriceSource029683 or "ESOHUB") Market.lastTooltipSignature = nil end,
            default = EPC.defaults.marketPriceSource029683 or "ESOHUB",
        },
        {
            type = "slider", name = "Deal rating max market-data age (hours)", min = 1, max = 72, step = 1,
            tooltip = "The Suite can still display older price information, but it stops calling listings Good/Great Deals once the loaded aggregate dataset is older than this limit.",
            getFunc = function() return math.floor(tonumber(EPC.saved.marketPriceMaxDealAgeHours029683) or 24) end,
            setFunc = function(v) EPC.saved.marketPriceMaxDealAgeHours029683 = math.floor(tonumber(v) or 24) Market.lastTooltipSignature = nil end,
            default = EPC.defaults.marketPriceMaxDealAgeHours029683,
        },
        {
            type = "checkbox", name = "Use TTC seen listings for trader locations",
            tooltip = "Builds a lightweight, chunked index from TTC's locally recorded Guild Trader scans. This does not query the internet. It lets the Suite attach a guild/kiosk location to listings your TTC data has actually seen.",
            getFunc = function() return EPC.saved.marketPriceUseTTCLocations029683 ~= false end,
            setFunc = function(v)
                EPC.saved.marketPriceUseTTCLocations029683 = v == true
                Market.ttcIndexReady = false
                if v and Market.StartTTCSeenIndex029683 then Market:StartTTCSeenIndex029683(true) end
                Market.lastTooltipSignature = nil
            end,
            default = EPC.defaults.marketPriceUseTTCLocations029683,
        },
        {
            type = "button", name = "TTC trader-location index", buttonText = "Rebuild Seen Listings",
            tooltip = "Rebuilds the Suite's in-memory lowest-seen listing index from TTC scan history. The scan is split into small batches to avoid a single-frame hitch.",
            func = function()
                Market.ttcIndexReady = false
                if Market.StartTTCSeenIndex029683 then Market:StartTTCSeenIndex029683(true) end
                if EPC.Print then EPC:Print("Rebuilding TTC seen-listing market location index.") end
            end,
            width = "half",
        },
        {
            type = "description",
            title = "Price-data freshness",
            text = "ESO-Hub/TTC desktop updaters may replace their Lua price files while ESO is running, but ESO only loads addon Lua data when the UI loads. After the updater downloads newer price tables, use /reloadui, relog, or restart the game to load the new global dataset. Guild Trader rows you browse in the current session are captured live immediately.",
            width = "full",
        },
        {
            type = "description",
            title = "Command",
            text = "/easmarket - while hovering an item, prints its current Suite global-low source and the cheapest exact listing location the Suite has actually seen.",
            width = "full",
        },
    }
end

local function hasSubmenu(options, name)
    for _, option in ipairs(options or {}) do
        if option and option.type == "submenu" and option.name == name then return true end
    end
    return false
end

local function insertAfterSubmenu(options, afterName, submenu)
    if type(options) ~= "table" or type(submenu) ~= "table" then return false end
    for i, option in ipairs(options) do
        if option and option.type == "submenu" and option.name == afterName then
            table.insert(options, i + 1, submenu)
            return true
        end
    end
    options[#options + 1] = submenu
    return true
end

S:RegisterOptionsExtension("MarketPrice", function(options)
    if hasSubmenu(options, "Market & Trading") then return end
    local controls = {
        {
            type = "description",
            text = "Current-market pricing, live/seen Guild Trader locations, deal freshness, and travel-to-trader controls. Global aggregate prices never claim an exact trader unless the Suite has real listing-location evidence.",
            width = "full",
        },
    }
    for _, control in ipairs(buildMarketControls()) do controls[#controls + 1] = control end
    insertAfterSubmenu(options, "Gear & Maintenance", {
        type = "submenu",
        name = "Market & Trading",
        tooltip = "ESO-Hub/TTC pricing, located listings, freshness, deal checks, and travel to known Guild Trader locations.",
        controls = controls,
    })
end, 300)

EPC.marketPriceSettings029683 = true