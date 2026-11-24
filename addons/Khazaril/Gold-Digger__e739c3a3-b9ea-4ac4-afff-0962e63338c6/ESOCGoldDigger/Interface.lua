-- Gold Digger screens: a side panel, plus one page in Settings > Add-Ons.
-- On console each section of that page opens as its own submenu.
-- It adds no trader buttons, so it can't clash with other add-ons' keybinds.

local GP = ESOC_GoldDigger
local Interface = {}
GP.Interface = Interface

-- Parked while the guild trader work comes first: daily checklist, farming, events and price history.
-- Their code is kept. Set this to true to bring them back.
Interface.SHOW_EXTRAS = false

local PANEL_WIDTH = 460
local RUN_PANEL_WIDTH = 1100
local PADDING = 12
local TRADER_PANEL_WIDTH = 620   -- fits the empty space above the game's Browse heading
local TRADER_PANEL_X, TRADER_PANEL_Y = 90, 6
local MAX_GOLD = 2100000000
local LOGIN_SHOW_MS = 30000
local LIST_ROWS = 10
local TRADER_ROWS = 4
local MAX_STOPS = 30
local MAX_ROWS_PER_STOP = 12

local panel
local loginShowing = false
local settingsPage

local function gold(value)
    return ZO_CommaDelimitNumber(zo_round(value))
end

local function trimNumber(value)
    local text = string.format("%.3f", value)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    return text
end

-- 655000 reads as 655K and 1500000 as 1.5M. Amounts that don't shorten neatly keep their commas.
function Interface.ShortGold(value)
    value = tonumber(value) or 0
    if value >= 1000000 and value % 1000 == 0 then return trimNumber(value / 1000000) .. "M" end
    if value >= 1000 and value < 1000000 and value % 100 == 0 then return trimNumber(value / 1000) .. "K" end
    return ZO_CommaDelimitNumber(value)
end

-- Reads 655K, 1.5M, 2 million, 12,500 or 12500. Returns nil if it isn't an amount.
function Interface.ParseGold(text)
    local cleaned = string.lower(tostring(text or ""))
    cleaned = string.gsub(cleaned, "[%s,]", "")
    if cleaned == "none" or cleaned == "off" or cleaned == "any" then return 0 end
    local number, suffix = string.match(cleaned, "^([%d%.]+)(%a*)$")
    local amount = number and tonumber(number)
    if not amount then return nil end
    local multiplier
    if suffix == "" then multiplier = 1
    elseif suffix == "k" or suffix == "thousand" then multiplier = 1000
    elseif suffix == "m" or suffix == "mil" or suffix == "million" then multiplier = 1000000
    else return nil end
    return math.min(math.floor(amount * multiplier + 0.5), MAX_GOLD)
end

local function traderName(name)
    return name ~= "" and name or "Unknown guild"
end

local function npcName(name)
    return name and name ~= "" and name or "Name not recorded"
end

-- Zone, trader and guild, for one-line mentions of a trader.
local function placeText(trader, zone)
    local progress = GP.Scanner.TraderProgress(trader, zone)
    local parts = { zone, "Trader: " .. npcName(progress and progress.npc), "Guild: " .. traderName(trader) }
    if progress and progress.town then table.insert(parts, 2, progress.town) end
    return table.concat(parts, ", ")
end

local function sellZone()
    return GP.Selling.PrimaryZone()
end

local function daysText(row)
    if not row.age then return "" end
    local days = math.floor(row.age)
    local when = days < 1 and ", listed today" or (", listed " .. days .. "d ago")
    if row.aged then return when .. ", slow seller" end
    return when
end

local function rowText(row)
    local listing = row.listing
    local verb = row.flag == "hold" and "HOLD, then sell in " or "Sell in "
    local warning = row.slowMarket and " (market is slow)" or ""
    local checked = row.check and "" or " (not price-checked)"
    return string.format("BUY %s x%d at %s each%s\n   %s%s at %s, +%s%s%s", row.name, listing.q, gold(listing.p), daysText(row),
        verb, row.sellZone or sellZone(), gold(row.sellAt), gold(row.profit), warning, checked)
end

local function tourText()
    local traders, partial, listings = GP.Scanner.TourSummary()
    if traders == 0 then return "No tour yet. Open a trader and choose Gold Digger: Scan new listings." end
    local text = traders .. " traders, " .. ZO_CommaDelimitNumber(listings) .. " listings."
        return text
end

-- What to list, where, and the price it has to beat.
local function sellPlanLines(tick)
    local lines = {}
    for _, entry in ipairs(GP.sv.stock) do
        if tick then tick() end
        if GP.Stockpile.IsReady(entry) then
            local target, guild, cheapest = GP.Scanner.SellPlan(entry.link)
            if target then
                local profit = GP.Scoring.Profit(entry.paid, entry.q, target)
                lines[#lines + 1] = entry.name .. " x" .. entry.q .. ": list at " .. gold(target) .. " each, +" .. gold(profit)
                if guild then
                    lines[#lines + 1] = "   Guild: " .. guild.name
                    lines[#lines + 1] = "   Trader: " .. npcName(guild.kiosk)
                    lines[#lines + 1] = "   Town: " .. GP.Selling.PlaceText(guild)
                end
                if cheapest then lines[#lines + 1] = "   Cheapest nearby: " .. gold(cheapest) end
            end
        end
    end
    return lines
end

Interface.BuildPlanLines = sellPlanLines

local function actionText()
    local lines = { tourText() }
    local report = GP.Scanner.Report()
    if report.building then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Building your report. Press X to refresh in a moment."
        return table.concat(lines, "\n")
    end
    local rows, stops = report.rows, report.stops
    local options = GP.sv.options
    local filter = "Showing listings from the last " .. (options.maxAgeDays or 3) .. " days"
    if (options.maxPrice or 0) > 0 then filter = filter .. ", up to " .. gold(options.maxPrice) .. " gold" end
    lines[#lines + 1] = filter .. ". Hidden: " .. ZO_CommaDelimitNumber(report.hiddenOld + report.hiddenPrice) .. "."

    local budget = report.budgetInfo
    if budget then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "SPENDING LIMIT: " .. gold(budget.budget)
        lines[#lines + 1] = "Buy for " .. gold(budget.cost) .. ", keep " .. gold(budget.fees) .. " for listing fees, " .. gold(budget.left) .. " unused."
        lines[#lines + 1] = "Expected profit " .. gold(budget.profit) .. "."
        if budget.skipped > 0 then lines[#lines + 1] = budget.skipped .. " other deals left out to stay within your limit." end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "YOUR SELLING TRADERS"
    for _, line in ipairs(GP.Selling.GuildLines()) do lines[#lines + 1] = line end

    local plan = report.plan or {}
    if #plan > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "SELL PLAN (list at any banker)"
        for _, line in ipairs(plan) do lines[#lines + 1] = line end
    end

    if #stops > 0 then
        local unchecked = GP.Scanner.UncheckedNames(rows)
        lines[#lines + 1] = ""
        if #unchecked > 0 then
            lines[#lines + 1] = "CHECK IN " .. string.upper(sellZone()) .. " BEFORE BUYING"
            lines[#lines + 1] = "At a trader there, search each name:"
            for _, name in ipairs(unchecked) do lines[#lines + 1] = "- " .. name end
        else
            lines[#lines + 1] = "Top buys are price-checked."
        end
    else
        lines[#lines + 1] = ""
        if budget and budget.skipped > 0 then
            lines[#lines + 1] = "None of the " .. budget.skipped .. " deals fit your spending limit. Raise it in Filters."
        else
            lines[#lines + 1] = "Nothing worth buying yet. Scan more traders, including " .. sellZone() .. ", so there are prices to compare."
        end
    end

    local shownStops, number = 0, 0
    for _, zone in ipairs(GP.Scanner.Zones(stops)) do
        if shownStops >= MAX_STOPS then break end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "ZONE: " .. string.upper(zone.name)
        lines[#lines + 1] = "Spend " .. gold(zone.cost) .. ", profit " .. gold(zone.profit)
        for _, stop in ipairs(zone.stops) do
            if shownStops >= MAX_STOPS then break end
            shownStops, number = shownStops + 1, number + 1
            lines[#lines + 1] = ""
            lines[#lines + 1] = number .. ". Trader: " .. npcName(stop.npc)
            lines[#lines + 1] = "   Guild: " .. traderName(stop.trader)
            if stop.town then lines[#lines + 1] = "   Town: " .. stop.town end
            lines[#lines + 1] = "   Spend " .. gold(stop.cost) .. ", profit " .. gold(stop.profit)
            for rowIndex, row in ipairs(stop.rows) do
                if rowIndex > MAX_ROWS_PER_STOP then
                    lines[#lines + 1] = (#stop.rows - MAX_ROWS_PER_STOP) .. " more here."
                    break
                end
                lines[#lines + 1] = rowText(row)
            end
        end
    end
    if #stops > MAX_STOPS then lines[#lines + 1] = (#stops - MAX_STOPS) .. " more traders not shown." end
    if (report.hiddenBlacklist or 0) > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "BLACKLISTED ITEMS: " .. report.hiddenBlacklist .. " deals left out"
        local warned = report.warned or {}
        if #warned > 0 then
            lines[#lines + 1] = "Huge discounts, but these failed to sell twice. Not on your buy run:"
            for index = 1, math.min(#warned, 5) do
                lines[#lines + 1] = rowText(warned[index])
                lines[#lines + 1] = "   " .. placeText(warned[index].listing.t, warned[index].listing.z)
            end
        end
    end
    return table.concat(lines, "\n")
end
Interface.ReportText = actionText

local function historyText(key)
    local item = key and GP.sv.items[key]
    if not item then return "Pick an item, then press Show." end
    local today = GP.Today()
    local view = GP.Scoring.View(item)
    local rate = GP.Scoring.GoingRate(view, today)
    local lines = { item.name, "Usual price: " .. (rate and gold(rate) or "not enough data") }
    local series = GP.Scoring.WeeklySeries(view, today, 8)
    for index = 1, 8 do
        local row = series[index]
        if row then
            local when = index == 1 and "This week" or ((index - 1) .. " wk ago")
            local range = row.l and (", " .. gold(row.l) .. " to " .. gold(row.h)) or ""
            lines[#lines + 1] = when .. ": " .. gold(row.s / row.c) .. range .. (row.e and " (event)" or "")
        end
    end
    for _, name in ipairs(GP.Events.NAMES) do
        local prices = view.ev and view.ev[name]
        if prices and prices.c > 0 then lines[#lines + 1] = name .. ": " .. gold(prices.s / prices.c) end
    end
    return table.concat(lines, "\n")
end

local function eventBuysText()
    local lines = {}
    for _, row in ipairs(GP.Scanner.Report().rows) do
        if row.flag == "hold" and #lines < LIST_ROWS then
            lines[#lines + 1] = rowText(row) .. "\n   " .. placeText(row.listing.t, row.listing.z)
        end
    end
    if #lines == 0 then return "No event bargains yet. Browse some traders." end
    return table.concat(lines, "\n")
end

local function farmText()
    local report = GP.Scanner.Report()
    if report.building then return "Building your report. Press X to refresh in a moment." end
    local rows = report.farm or {}
    if #rows == 0 then return "No prices yet. Browse materials, motifs and recipes at traders." end
    local lines = {}
    for _, row in ipairs(rows) do
        local advice = row.flooded and "Cheap right now: farm and hold" or "Good to sell now"
        lines[#lines + 1] = row.name .. ": about " .. gold(row.rate) .. " each. " .. advice .. "\n   " .. row.tip
        lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n")
end

local function checklistText()
    local open = GP.Checklist.Open()
    if #open == 0 then return "Gold Digger\nAll done today." end
    local lines = { "Gold Digger: " .. #open .. " left today" }
    for _, task in ipairs(open) do lines[#lines + 1] = "- " .. task.label end
    return table.concat(lines, "\n")
end

local function pageText(here, zone)
    local progress = GP.Scanner.TraderProgress(here, zone)
    if not progress then
        if GP.Scanner.IsScanning() then return "Scanning page 1. Press B to stop." end
        return "Choose Scan new listings to scan this trader."
    end
    if GP.Scanner.IsScanning() then
        return "Scanning page " .. (GP.Scanner.ScanPages() + 1) .. ". Press B to stop."
    end
    if progress.cutoff then
        return "All listings from the last " .. (GP.sv.options.maxAgeDays or 3) .. " days read. Move on."
    end
    if progress.scannedAt then return "Scan saved. Choose Scan new listings to run it again." end
    return "Choose Scan new listings to scan this trader."
end

-- Kept short on purpose: what the scan is doing, and how many buys this trader has.
local function traderText(fresh)
    local here, zone, _, _, atBank = GP.Scanner.StoreLocation()
    local lines = { "Gold Digger: " .. (atBank and "Choose List what I bought to sell." or pageText(here, zone)) }
    if fresh then GP.Scanner.Report() end
    local report = GP.Scanner.CachedReport()
    if report and not GP.Scanner.IsScanning() and not atBank then
        local count = 0
        for _, row in ipairs(report.rows) do
            if row.listing.t == here then count = count + 1 end
        end
        if count > 0 then
            lines[#lines + 1] = count .. (count == 1 and " buy" or " buys") .. " here. Open the report for details."
        end
    end
    if #GP.sv.stock > 0 and not GP.Scanner.IsScanning() and not atBank then
        lines[#lines + 1] = #GP.sv.stock .. " bought. To sell, choose List what I bought."
    end
    if not GP.Scanner.IsScanning() and not atBank then
        local ok, needs = pcall(GP.Levels.Shortfalls)
        if ok and #needs > 0 then lines[#lines + 1] = #needs .. " below stock level. Choose Restock materials." end
    end
    return table.concat(lines, "\n")
end

local function isAtTrader()
    return TRADING_HOUSE_GAMEPAD_SCENE and TRADING_HOUSE_GAMEPAD_SCENE:IsShowing()
end

local function placePanel()
    -- The run guide has its own place at the top of the screen
    if not panel or panel.runShown then return end
    local options = GP.sv.options
    local atTrader = isAtTrader() and true or false
    panel.atTrader = atTrader
    panel.window:ClearAnchors()
    local width = atTrader and TRADER_PANEL_WIDTH or PANEL_WIDTH
    panel.window:SetWidth(width)
    panel.label:SetWidth(width - PADDING * 2)
    if atTrader then
        panel.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TRADER_PANEL_X, TRADER_PANEL_Y)
    elseif options.side == "right" then
        panel.window:SetAnchor(RIGHT, GuiRoot, RIGHT, -24, options.height)
    else
        panel.window:SetAnchor(LEFT, GuiRoot, LEFT, 24, options.height)
    end
end

local function createPanel()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCGoldDiggerPanel")
    window:SetDimensions(PANEL_WIDTH, 100)
    window:SetMouseEnabled(false)
    window:SetHidden(true)
    local overlay = rawget(_G, "DL_OVERLAY")
    if overlay then window:SetDrawLayer(overlay) end

    local root = WINDOW_MANAGER:CreateControl("ESOCGoldDiggerPanelRoot", window, CT_CONTROL)
    root:SetAnchorFill(window)
    local background = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
    background:SetAnchorFill(root)
    background:SetColor(0, 0, 0, 0.6)
    local label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    label:SetFont("ZoFontGamepad22")
    label:SetColor(0.95, 0.88, 0.62, 1)
    label:SetAnchor(TOPLEFT, root, TOPLEFT, PADDING, PADDING)
    label:SetWidth(PANEL_WIDTH - PADDING * 2)

    panel = { window = window, root = root, label = label }
    panel.fragment = ZO_SimpleSceneFragment:New(window)
    if HUD_SCENE then HUD_SCENE:AddFragment(panel.fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(panel.fragment) end
    if TRADING_HOUSE_GAMEPAD_SCENE then
        TRADING_HOUSE_GAMEPAD_SCENE:AddFragment(panel.fragment)
        TRADING_HOUSE_GAMEPAD_SCENE:RegisterCallback("StateChange", function() Interface.RefreshPanel(true) end)
    end
    placePanel()
end

-- Only the side panel, so reading a trader page stays light.
function Interface.RefreshPanel(fresh)
    if not panel then return end
    local text = ""
    local runText = GP.unlocked and GP.Run.PanelText() or nil
    if runText ~= panel.runShown then
        if (runText ~= nil) ~= (panel.runShown ~= nil) then
            if runText then
                panel.window:ClearAnchors()
                panel.window:SetAnchor(TOP, GuiRoot, TOP, 0, 30)
                panel.window:SetWidth(RUN_PANEL_WIDTH)
                panel.label:SetWidth(RUN_PANEL_WIDTH - PADDING * 2)
                panel.label:SetFont("ZoFontGamepad34")
            else
                panel.window:SetWidth(PANEL_WIDTH)
                panel.label:SetWidth(PANEL_WIDTH - PADDING * 2)
                panel.label:SetFont("ZoFontGamepad22")
            end
        end
        local hadRun = panel.runShown ~= nil
        panel.runShown = runText
        if hadRun and not runText then placePanel() end
    end
    if runText then
        panel.atTrader = nil
    elseif panel.atTrader ~= (isAtTrader() and true or false) then
        placePanel()
    end
    if runText then
        text = runText
    elseif GP.unlocked then
        if isAtTrader() then
            if GP.sv.options.showAtTrader then text = traderText(fresh) end
        elseif loginShowing then
            text = checklistText()
        end
    elseif loginShowing then
        text = "Gold Digger\n" .. GP.LOCKED_TEXT
    end
    panel.root:SetHidden(text == "")
    if text ~= "" then
        panel.label:SetText(text)
        panel.window:SetHeight(panel.label:GetTextHeight() + PADDING * 2)
    end
end

function Interface.Refresh()
    if GP.Scanner then GP.Scanner.MarkDirty() end
    Interface.RefreshPanel(true)
    if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
end

-- A background report has finished.
function Interface.OnReportReady()
    Interface.RefreshPanel()
    if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
    if GP.ReportScreen.IsShowing() then GP.ReportScreen.Refresh() end
end

function Interface.ShowLogin()
    if not Interface.SHOW_EXTRAS or not GP.sv.options.showOnLogin then
        Interface.Refresh()
        return
    end
    loginShowing = true
    Interface.Refresh()
    zo_callLater(function()
        loginShowing = false
        Interface.Refresh()
    end, LOGIN_SHOW_MS)
end

-- Console LibHarvensAddonSettings passes the whole { name, data } item; other versions pass the data.
local function dropdownValue(item)
    if type(item) == "table" then return item.data end
    return item
end

local function unlockedText(build)
    return function()
        if not GP.unlocked then return GP.LOCKED_TEXT end
        return build()
    end
end

local function add(controls, list)
    for _, control in ipairs(list) do controls[#controls + 1] = control end
end

local function actionControls(LHAS)
    return {
        { type = LHAS.ST_SECTION, label = "Action List" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local report = GP.Scanner.Report()
            return tourText() .. "\n" .. #report.rows .. " buys at " .. #report.stops .. " traders."
        end) },
        {
            type = LHAS.ST_BUTTON, label = "Open full report", buttonText = "Open",
            tooltip = "A large screen with your selling traders, sell plan, price checks and buys by zone. LB and RB change page.",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.ReportScreen.Open("Gold Digger Report", actionText) end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Start buy run", buttonText = "Start",
            tooltip = "Guides you trader by trader. Open each trader and it finds the item, so you only press A to buy. Then it does the same for listing.",
            disable = function() return not GP.unlocked or GP.Run.IsActive() end,
            clickHandler = function()
                if GP.Run.Start() then pcall(function() SCENE_MANAGER:ShowBaseScene() end) end
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "List what I bought", buttonText = "Start",
            tooltip = "Collect your mail, then open your guild store at any banker. Gold Digger opens each listing with the price filled in, and you press A to confirm.",
            disable = function() return not GP.unlocked or GP.Run.IsActive() or #GP.sv.stock == 0 end,
            clickHandler = function()
                if GP.Run.StartSelling() then pcall(function() SCENE_MANAGER:ShowBaseScene() end) end
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "View run checklist", buttonText = "Open",
            disable = function() return not GP.unlocked or not GP.sv.run end,
            clickHandler = function() GP.ReportScreen.Open("Run Checklist", GP.Run.ChecklistText) end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Stop run", buttonText = "Stop",
            disable = function() return not GP.Run.IsActive() end,
            clickHandler = function() GP.Run.Stop() end,
        },
    }
end

local function filterControls(LHAS)
    local options = GP.sv.options
    -- Any amount can be typed, such as 655K, 1.5M or 12500
    local function goldField(label, key, default, tooltip)
        return {
            type = LHAS.ST_EDIT, label = label,
            tooltip = tooltip .. " Type any amount, like 655K, 1.5M or 12500.",
            getFunction = function()
                local value = options[key]
                if value == nil then value = default end
                return Interface.ShortGold(value)
            end,
            setFunction = function(text)
                if not text or text == "" then return end
                local amount = Interface.ParseGold(text)
                if amount then
                    options[key] = amount
                    GP.Scanner.MarkDirty()
                else
                    GP.Alert("enter an amount like 655K, 1.5M or 12500")
                end
                if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
            end,
        }
    end
    return {
        { type = LHAS.ST_SECTION, label = "Filters" },
        goldField("Spending limit (0 = no limit)", "budget", 0,
            "The most gold to put into one buy run, including the fee to relist. The report picks the most profitable deals that fit."),
        goldField("Minimum listing value", "minListValue", 5000,
            "Skips anything that wouldn't resell for at least this much as one listing. Materials count as a whole stack, and motifs and recipes count singly."),
        goldField("Minimum profit after fees", "minProfit", 1000,
            "Only trades that make at least this much go on your buy run."),
        {
            type = LHAS.ST_SLIDER, label = "Only listings from the last (days)", min = 1, max = 30, step = 1, format = "%d",
            tooltip = "New listings are where pricing mistakes are. Older ones have sat without selling.",
            getFunction = function() return options.maxAgeDays or 3 end,
            setFunction = function(value) options.maxAgeDays = tonumber(value) or 3; GP.Scanner.MarkDirty() end,
        },
        goldField("Maximum price per listing (0 = any)", "maxPrice", 0,
            "Leaves out anything that costs more than this in total."),
        {
            type = LHAS.ST_CHECKBOX, label = "Scan as soon as I open a trader",
            tooltip = "Off: a trader stays normal until you choose Gold Digger: Scan new listings in its Browse list. On: each trader scans when opened, at most once every 30 minutes. B stops a scan.",
            getFunction = function() return options.scanOnOpen == true end,
            setFunction = function(value) options.scanOnOpen = value end,
        },
    }
end

local function stockpileControls(LHAS)
    local removeNumber = 1
    local function chosenEntry()
        local count = #GP.sv.stock
        if count == 0 then return nil, 1 end
        local number = math.max(1, math.min(removeNumber, count))
        return GP.sv.stock[number], number
    end
    return {
        { type = LHAS.ST_SECTION, label = "Stockpile" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local stock = GP.sv.stock
            if #stock == 0 then return "Nothing here yet. Add items from your inventory's Actions menu, or buy from the report." end
            return #stock .. " items in your stockpile."
        end) },
        {
            type = LHAS.ST_BUTTON, label = "View stockpile", buttonText = "Open",
            disable = function() return not GP.unlocked or #GP.sv.stock == 0 end,
            clickHandler = function()
                GP.ReportScreen.Open("Stockpile", function()
                    local lines = {}
                    for index, entry in ipairs(GP.sv.stock) do lines[#lines + 1] = index .. ". " .. GP.Stockpile.Line(entry) end
                    return table.concat(lines, "\n")
                end)
            end,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Let me set prices on items I add",
            tooltip = "Off: Gold Digger prices items you add from its market data, or uses the game's suggested price if it has none. You still confirm each listing. On: each one opens for you to set the price.",
            getFunction = function() return GP.sv.options.choosePrice == true end,
            setFunction = function(value) GP.sv.options.choosePrice = value end,
        },
        {
            type = LHAS.ST_SLIDER, label = "Stockpile entry to remove", min = 1, max = 100, step = 1, format = "%d",
            tooltip = "Use the number shown on the View stockpile screen.",
            disable = function() return not GP.unlocked or #GP.sv.stock == 0 end,
            getFunction = function()
                local _, number = chosenEntry()
                return number
            end,
            setFunction = function(value)
                removeNumber = tonumber(value) or 1
                if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
            end,
        },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local entry, number = chosenEntry()
            if not entry then return "Nothing to remove." end
            return "Selected: " .. number .. ". " .. entry.name .. " x" .. entry.q
        end) },
        {
            type = LHAS.ST_BUTTON, label = "Remove selected entry", buttonText = "Remove",
            tooltip = "Takes it off Gold Digger's list only. It doesn't touch the item itself.",
            disable = function() return not GP.unlocked or #GP.sv.stock == 0 end,
            clickHandler = function()
                local _, number = chosenEntry()
                GP.Stockpile.Remove(number)
            end,
        },
    }
end

local function watchControls(LHAS)
    local clearNumber = 1
    local function chosenRow()
        local list = GP.Stockpile.StrikeList()
        if #list == 0 then return nil, 1 end
        local number = math.max(1, math.min(clearNumber, #list))
        return list[number], number
    end
    return {
        { type = LHAS.ST_SECTION, label = "Watch List and Blacklist" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local watching, blocked = 0, 0
            for _, row in ipairs(GP.Stockpile.StrikeList()) do
                if row.till then blocked = blocked + 1 else watching = watching + 1 end
            end
            return watching .. " on the watch list, " .. blocked .. " blacklisted."
        end) },
        {
            type = LHAS.ST_BUTTON, label = "View watch list and blacklist", buttonText = "Open",
            tooltip = "An item that comes back unsold is watched. If it comes back again it's blacklisted for 60 days, and any sale clears it.",
            disable = function() return not GP.unlocked or #GP.Stockpile.StrikeList() == 0 end,
            clickHandler = function()
                GP.ReportScreen.Open("Watch List and Blacklist", function()
                    local lines = {}
                    for index, row in ipairs(GP.Stockpile.StrikeList()) do
                        lines[#lines + 1] = index .. ". " .. GP.Stockpile.StrikeLine(row)
                    end
                    return table.concat(lines, "\n")
                end)
            end,
        },
        {
            type = LHAS.ST_SLIDER, label = "Entry to clear", min = 1, max = 100, step = 1, format = "%d",
            tooltip = "Use the number shown on the watch list screen.",
            disable = function() return not GP.unlocked or #GP.Stockpile.StrikeList() == 0 end,
            getFunction = function()
                local _, number = chosenRow()
                return number
            end,
            setFunction = function(value)
                clearNumber = tonumber(value) or 1
                if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
            end,
        },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local row, number = chosenRow()
            if not row then return "Nothing to clear." end
            return "Selected: " .. number .. ". " .. row.name
        end) },
        {
            type = LHAS.ST_BUTTON, label = "Clear selected entry", buttonText = "Clear",
            tooltip = "Gold Digger will recommend this item again.",
            disable = function() return not GP.unlocked or #GP.Stockpile.StrikeList() == 0 end,
            clickHandler = function()
                local row = chosenRow()
                if row then
                    GP.Stockpile.ClearStrike(row.key)
                    Interface.Refresh()
                end
            end,
        },
    }
end

local function stockLevelControls(LHAS)
    local Levels = GP.Levels
    local number = 1
    local function chosen()
        local list = Levels.ItemList()
        if #list == 0 then return nil, 1 end
        local index = math.max(1, math.min(number, #list))
        return list[index], index
    end
    local function refreshPage()
        if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
    end
    local function levelField(label, tooltip, read, write)
        return {
            type = LHAS.ST_EDIT, label = label,
            tooltip = tooltip .. " Type a number like 150, or All to keep everything.",
            getFunction = function() return Levels.FormatLevel(read()) end,
            setFunction = function(text)
                if not text or text == "" then return end
                local value = Levels.ParseLevel(text)
                if value == nil then
                    GP.Alert("enter a number like 150, or All")
                else
                    write(value)
                    GP.Scanner.MarkDirty()
                end
                refreshPage()
            end,
        }
    end
    local controls = {
        { type = LHAS.ST_SECTION, label = "Stock Levels" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local needs = Levels.Shortfalls()
            return #needs .. " materials below their level. Set a level on one item from its Actions menu in your inventory."
        end) },
        {
            type = LHAS.ST_BUTTON, label = "Check what's excess", buttonText = "Check",
            tooltip = "Looks through your craft bag and shows what's above your levels and worth selling. Nothing is listed yet.",
            disable = function() return not GP.unlocked end,
            clickHandler = function()
                Levels.CheckExcess()
                GP.ReportScreen.Open("Sell Excess", Levels.ExcessText)
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Add excess to my sell list", buttonText = "Add",
            tooltip = "Then choose List what I bought at a banker. You still confirm every listing.",
            disable = function() return not GP.unlocked or #Levels.Excess() == 0 end,
            clickHandler = function()
                Levels.QueueExcess()
                refreshPage()
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "View restock list", buttonText = "Open",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.ReportScreen.Open("Restock List", Levels.RestockText) end,
        },
        {
            type = LHAS.ST_EDIT, label = "Restock budget per visit (0 = no limit)",
            tooltip = "Kept apart from your spending limit for flips. Type any amount, like 655K, 1.5M or 12500.",
            getFunction = function() return Interface.ShortGold(Levels.Budget()) end,
            setFunction = function(text)
                if not text or text == "" then return end
                local value = Interface.ParseGold(text)
                if value then Levels.SetBudget(value) else GP.Alert("enter an amount like 655K, 1.5M or 12500") end
                refreshPage()
            end,
        },
    }
    local function writField(label, tooltip, read, write)
        return {
            type = LHAS.ST_EDIT, label = label, tooltip = tooltip,
            getFunction = function() return tostring(read()) end,
            setFunction = function(text)
                if not text or text == "" then return end
                local value = Interface.ParseGold(text)
                if value then write(value) else GP.Alert("enter a whole number") end
                refreshPage()
            end,
        }
    end
    add(controls, {
        writField("Max-level writ characters",
            "Characters making writs with top-tier materials. Your writ materials are kept at the level your characters need. What's below it goes on your restock list, and they're never sold as excess.",
            function() return (Levels.WritPlan()) end, Levels.SetWritCharacters),
        writField("Level 1 writ characters",
            "Characters making writs with the lowest-tier materials, like Iron and Jute.",
            function()
                local _, _, low = Levels.WritPlan()
                return low
            end, Levels.SetWritLowCharacters),
        writField("Days of writ supply to keep",
            "How many days of materials to hold for those characters.",
            function()
                local _, days = Levels.WritPlan()
                return days
            end, Levels.SetWritDays),
        {
            type = LHAS.ST_BUTTON, label = "View writ supply", buttonText = "Open",
            tooltip = "Shows what your writs need, what you have, and what to buy or sell.",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.ReportScreen.Open("Writ Supply", Levels.WritText) end,
        },
    })
    for _, group in ipairs(Levels.GROUPS) do
        if group.canKeep then
            controls[#controls + 1] = levelField(group.label .. ": keep at least",
                "Below this, each one goes on your restock list.",
                function() return (Levels.GroupSetting(group.id)) end,
                function(value) Levels.SetGroup(group.id, "keep", value or 0) end)
        end
        if not group.neverSell then
            controls[#controls + 1] = levelField(group.label .. ": sell above",
                "Anything over this can be sold as excess.",
                function()
                    local _, sell = Levels.GroupSetting(group.id)
                    return sell
                end,
                function(value) Levels.SetGroup(group.id, "sell", value) end)
        end
    end
    add(controls, {
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local row, index = chosen()
            if not row then return "No single-item levels yet." end
            local keep, sell = Levels.For(row.item.link)
            return "Item " .. index .. " of " .. #Levels.ItemList() .. ": " .. row.item.name
                .. "\nKeep " .. Levels.FormatLevel(keep) .. ", sell above " .. Levels.FormatLevel(sell)
        end) },
        {
            type = LHAS.ST_SLIDER, label = "Single item to change", min = 1, max = 100, step = 1, format = "%d",
            disable = function() return #Levels.ItemList() == 0 end,
            getFunction = function()
                local _, index = chosen()
                return index
            end,
            setFunction = function(value)
                number = tonumber(value) or 1
                refreshPage()
            end,
        },
        levelField("This item: keep at least", "Below this, it goes on your restock list.",
            function()
                local row = chosen()
                return row and (Levels.For(row.item.link)) or 0
            end,
            function(value)
                local row = chosen()
                if row then row.item.keep = value or 0 end
            end),
        levelField("This item: sell above", "Anything over this can be sold as excess.",
            function()
                local row = chosen()
                if not row then return nil end
                local _, sell = Levels.For(row.item.link)
                return sell
            end,
            function(value)
                local row = chosen()
                if row then row.item.sell = value end
            end),
        {
            type = LHAS.ST_EDIT, label = "This item: most to pay each (0 = automatic)",
            tooltip = "Automatic won't pay more than a quarter above its usual price.",
            getFunction = function()
                local row = chosen()
                return Interface.ShortGold(row and row.item.maxPrice or 0)
            end,
            setFunction = function(text)
                local row = chosen()
                if not row or not text or text == "" then return end
                local value = Interface.ParseGold(text)
                if value then row.item.maxPrice = value > 0 and value or nil else GP.Alert("enter an amount like 2.5K") end
                refreshPage()
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Clear this item's level", buttonText = "Clear",
            disable = function() return #Levels.ItemList() == 0 end,
            clickHandler = function()
                local row = chosen()
                if row then Levels.ClearItem(row.item.link) end
                refreshPage()
            end,
        },
    })
    return controls
end

local function sellingGuildControls(LHAS)
    local number = 1
    local function chosen()
        local list = GP.Selling.Guilds()
        if #list == 0 then return nil, 1 end
        local index = math.max(1, math.min(number, #list))
        return list[index], index
    end
    return {
        { type = LHAS.ST_SECTION, label = "Selling Guilds" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            pcall(GP.Selling.Refresh)
            local lines = {}
            for index, guild in ipairs(GP.Selling.Guilds()) do
                local status = not guild.canSell and "Can't sell" or (GP.Selling.GuildEnabled(guild) and "On" or "Off")
                local place = guild.kiosk and GP.Selling.PlaceText(guild) or "No trader"
                lines[#lines + 1] = index .. ". " .. guild.name .. ": " .. status .. " (" .. place .. ")"
            end
            if #lines == 0 then return "You aren't in a guild." end
            return table.concat(lines, "\n")
        end) },
        {
            type = LHAS.ST_SLIDER, label = "Guild number", min = 1, max = 5, step = 1, format = "%d",
            tooltip = "Pick a guild from the list above.",
            getFunction = function()
                local _, index = chosen()
                return index
            end,
            setFunction = function(value)
                number = tonumber(value) or 1
                if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
            end,
        },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local guild, index = chosen()
            if not guild then return "No guild selected." end
            return "Selected: " .. index .. ". " .. guild.name
        end) },
        {
            type = LHAS.ST_BUTTON, label = "Turn selected guild on or off", buttonText = "Switch",
            tooltip = "When your main guild is full, listings move to the next guild that's on. Guilds with no trader start off, because only their members would see your items.",
            disable = function()
                local guild = chosen()
                return not GP.unlocked or not guild or not guild.canSell
            end,
            clickHandler = function()
                local guild = chosen()
                if not guild then return end
                GP.Selling.SetGuildEnabled(guild, not GP.Selling.GuildEnabled(guild))
                if settingsPage then pcall(function() settingsPage:UpdateControls() end) end
            end,
        },
    }
end

-- Console dropdowns fire at every step, so they only pick. A button does the work.
local function eventControls(LHAS)
    local chosen = GP.Events.NAMES[1]
    local items = {}
    for _, name in ipairs(GP.Events.NAMES) do items[#items + 1] = { name = name, data = name } end
    return {
        { type = LHAS.ST_SECTION, label = "Events" },
        { type = LHAS.ST_LABEL, label = unlockedText(function()
            local name = GP.Events.ActiveName()
            return name and ("Running: " .. name) or "No event marked."
        end) },
        {
            type = LHAS.ST_DROPDOWN, label = "Choose event", items = items,
            getFunction = function() return chosen end,
            setFunction = function(_, _, item) chosen = dropdownValue(item) or chosen end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Mark event started", buttonText = "Start",
            tooltip = "The game can't tell add-ons when a festival is on. Prices from now on are saved as event prices.",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.Events.Start(chosen) end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Mark event ended", buttonText = "End",
            tooltip = "Ends by itself after 21 days if you forget.",
            disable = function() return not GP.unlocked or not GP.Events.Current() end,
            clickHandler = function() GP.Events.End() end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Buy now, sell after the event", buttonText = "Open",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.ReportScreen.Open("Event Buys", eventBuysText) end,
        },
    }
end

local function historyControls(LHAS)
    local chosenKey
    local function nameOf(key)
        local item = key and GP.sv.items[key]
        return item and item.name or "Choose an item"
    end
    return {
        { type = LHAS.ST_SECTION, label = "Price History" },
        {
            type = LHAS.ST_DROPDOWN, label = "Item",
            items = function()
                local items = {}
                for _, row in ipairs(GP.Scanner.TopItems(30)) do items[#items + 1] = { name = row.name, data = row.key } end
                if #items == 0 then items[1] = { name = "Choose an item", data = false } end
                return items
            end,
            getFunction = function() return nameOf(chosenKey) end,
            setFunction = function(_, _, item) chosenKey = dropdownValue(item) or nil end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Show this item", buttonText = "Show",
            disable = function() return not GP.unlocked or not chosenKey end,
            clickHandler = function()
                local key = chosenKey
                GP.ReportScreen.Open("Price History", function() return historyText(key) end)
            end,
        },
    }
end

local function farmControls(LHAS)
    return {
        { type = LHAS.ST_SECTION, label = "What to Farm" },
        {
            type = LHAS.ST_BUTTON, label = "Open farming list", buttonText = "Open",
            disable = function() return not GP.unlocked end,
            clickHandler = function() GP.ReportScreen.Open("What to Farm", farmText) end,
        },
    }
end

local function checklistControls(LHAS)
    local controls = { { type = LHAS.ST_SECTION, label = "Daily Checklist" } }
    for _, task in ipairs(GP.Checklist.TASKS) do
        controls[#controls + 1] = {
            type = LHAS.ST_CHECKBOX,
            label = task.label .. (task.scope == "account" and " (account)" or ""),
            disable = function() return not GP.unlocked or not GP.Checklist.IsShown(task) end,
            getFunction = function() return GP.Checklist.IsDone(task) end,
            setFunction = function(value) GP.Checklist.SetDone(task, value) end,
        }
    end
    return controls
end

local function accessControls(LHAS)
    return {
        { type = LHAS.ST_SECTION, label = "Access" },
        { type = LHAS.ST_LABEL, label = function() return GP.Access.StatusText() end },
        {
            type = LHAS.ST_EDIT, label = "Enter access code",
            tooltip = "Only needed if an invite doesn't unlock by itself when you open your mail. Codes work only for your account.",
            disable = function() return GP.Access.IsOwner() end,
            getFunction = function() return "" end,
            setFunction = function(value)
                if not value or value == "" then return end
                local start = GP.Access.Enter(value)
                if start then
                    GP.Alert("access through the end of " .. GP.Access.PeriodName(GP.Access.LastPeriod(start)))
                else
                    GP.Alert("that code isn't valid for this account")
                end
                Interface.Refresh()
            end,
        },
    }
end

-- Only the owner's account gets these.
function Interface.OwnerControls(LHAS)
    local picked
    return {
        { type = LHAS.ST_SECTION, label = "Manage Players" },
        {
            type = LHAS.ST_EDIT, label = "Add player (@name)",
            tooltip = "Type their @name exactly, including any spaces. Then choose them below and send an invite.",
            getFunction = function() return "" end,
            setFunction = function(value)
                if not value or value == "" then return end
                if not GP.Access.AddPlayer(value) then GP.Alert("couldn't add that name") end
            end,
        },
        { type = LHAS.ST_LABEL, label = function() return GP.Access.PlayersText() end },
        {
            type = LHAS.ST_DROPDOWN, label = "Player",
            items = function()
                local items = {}
                for _, name in ipairs(GP.sv.members) do items[#items + 1] = { name = name, data = name } end
                if #items == 0 then items[1] = { name = "No players", data = false } end
                return items
            end,
            getFunction = function()
                if picked and not GP.sv.memberInfo[GP.Access.Normalize(picked)] then picked = nil end
                return picked or "Choose a player"
            end,
            setFunction = function(_, _, item) picked = dropdownValue(item) or nil end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Send or renew invite", buttonText = "Send mail",
            tooltip = "Mails this player an invite from your account. It lasts six months, and renewing starts a new six months.",
            disable = function() return not picked end,
            clickHandler = function()
                if picked then GP.Access.SendInvite(picked) end
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Remove this player", buttonText = "Remove",
            tooltip = "Mails them a removal. Their access ends the next time they open their mail.",
            disable = function() return not picked end,
            clickHandler = function()
                local name = picked
                if not name then return end
                local wasInvited = GP.Access.RemovalFailed(name) or GP.sv.memberInfo[GP.Access.Normalize(name)].sentStart
                if GP.Access.RequestRemoval(name) and not wasInvited then picked = nil end
                Interface.Refresh()
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Take off list without mail", buttonText = "Take off",
            tooltip = "Only for when the removal mail failed. Mail them the subject shown above first, or their access runs until it expires.",
            disable = function() return not GP.Access.RemovalFailed(picked) end,
            clickHandler = function()
                if picked then GP.Access.ForgetPlayer(picked) end
                picked = nil
                Interface.Refresh()
            end,
        },
    }
end

local function optionControls(LHAS)
    local options = GP.sv.options
    return {
        { type = LHAS.ST_SECTION, label = "Options" },
        { type = LHAS.ST_LABEL, label = function()
            return string.format("Saved data: about %.1f MB of 5 MB", GP.Scanner.EstimateBytes() / (1024 * 1024))
        end },
        {
            type = LHAS.ST_DROPDOWN, label = "Main selling guild",
            tooltip = "Automatic uses your guild with a trader in your selling zone.",
            items = function()
                local items = { { name = "Automatic", data = false } }
                for _, guild in ipairs(GP.Selling.Guilds()) do
                    if guild.canSell and guild.kiosk then items[#items + 1] = { name = guild.name, data = guild.name } end
                end
                return items
            end,
            getFunction = function() return options.sellGuild or "Automatic" end,
            setFunction = function(_, _, item) options.sellGuild = dropdownValue(item) or nil; GP.Scanner.MarkDirty() end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Where you sell",
            tooltip = "Used when none of your guilds has a trader whose location is known.",
            items = function()
                local items = {}
                for _, zone in ipairs(GP.Scanner.SeenZones()) do items[#items + 1] = { name = zone, data = zone } end
                return items
            end,
            getFunction = function() return sellZone() end,
            setFunction = function(_, _, item) options.sellZone = dropdownValue(item) or options.sellZone; GP.Scanner.MarkDirty() end,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Show panel at traders",
            getFunction = function() return options.showAtTrader end,
            setFunction = function(value) options.showAtTrader = value; Interface.RefreshPanel() end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Panel side",
            items = { { name = "Left", data = "left" }, { name = "Right", data = "right" } },
            getFunction = function() return options.side == "right" and "Right" or "Left" end,
            setFunction = function(_, _, item) options.side = dropdownValue(item) or "left"; placePanel() end,
        },
        {
            type = LHAS.ST_SLIDER, label = "Move panel up or down", min = -400, max = 400, step = 10, format = "%d",
            getFunction = function() return options.height end,
            setFunction = function(value) options.height = tonumber(value) or 0; placePanel() end,
        },
    }
end

-- The parked menus. See SHOW_EXTRAS at the top of this file.
function Interface.ExtraControls(LHAS)
    local options = GP.sv.options
    local controls = {}
    add(controls, eventControls(LHAS))
    add(controls, historyControls(LHAS))
    add(controls, farmControls(LHAS))
    add(controls, checklistControls(LHAS))
    add(controls, {
        {
            type = LHAS.ST_CHECKBOX, label = "Show checklist at login",
            getFunction = function() return options.showOnLogin end,
            setFunction = function(value) options.showOnLogin = value end,
        },
        {
            type = LHAS.ST_CHECKBOX, label = "Include Tamriel Tome challenges",
            getFunction = function() return options.includeTome end,
            setFunction = function(value) options.includeTome = value; Interface.Refresh() end,
        },
        {
            type = LHAS.ST_SLIDER, label = "Daily reset hour (UTC)", min = 0, max = 23, step = 1, format = "%d",
            tooltip = "Checklist items clear at this hour. Change it if they clear at the wrong time.",
            getFunction = function() return GP.ResetHour() end,
            setFunction = function(value) options.resetHour = tonumber(value) or GP.ResetHour(); Interface.Refresh() end,
        },
    })
    return controls
end

-- One page in one batch: console builds its submenus from the sections.
local function createSettings(LHAS)
    settingsPage = LHAS:AddAddon("Gold Digger", { allowRefresh = true })
    local controls = {}
    add(controls, actionControls(LHAS))
    add(controls, filterControls(LHAS))
    add(controls, stockpileControls(LHAS))
    add(controls, watchControls(LHAS))
    add(controls, stockLevelControls(LHAS))
    add(controls, sellingGuildControls(LHAS))
    if Interface.SHOW_EXTRAS then add(controls, Interface.ExtraControls(LHAS)) end
    add(controls, accessControls(LHAS))
    if GP.Access.IsOwner() then add(controls, Interface.OwnerControls(LHAS)) end
    add(controls, optionControls(LHAS))
    settingsPage:AddSettings(controls)
end

function Interface.Install()
    createPanel()
    local LHAS = LibHarvensAddonSettings
    if LHAS and LHAS.AddAddon then createSettings(LHAS) end
end
