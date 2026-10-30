InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local function Check(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function CheckEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

local function CountEntries(values)
    local count = 0
    for _ in pairs(values) do
        count = count + 1
    end
    return count
end

local function PruneDiagnosticSavedVariables(accountWide, character)
    local removedCount = 0
    local visited = {}

    local function RemoveLastQueryKeys(values)
        if type(values) ~= "table" or visited[values] then
            return
        end
        visited[values] = true

        for key, value in pairs(values) do
            if type(key) == "string" and key:lower() == "lastquery" then
                values[key] = nil
                removedCount = removedCount + 1
            elseif type(key) == "string"
                and key:lower() ~= "trackeditems"
                and key:lower() ~= "trackedrules"
                and type(value) == "table" then
                RemoveLastQueryKeys(value)
            end
        end
    end

    RemoveLastQueryKeys(accountWide)
    RemoveLastQueryKeys(character)

    if accountWide.currencyInfo ~= nil then
        accountWide.currencyInfo = nil
        removedCount = removedCount + 1
    end

    return removedCount
end

local function RecordCurrencyName(namesById, currencyType, name, namesChanged)
    local previousName = namesById[currencyType]
    if previousName ~= nil and previousName ~= name then
        Check(type(previousName) == "string", "Saved currency name is invalid for ID " .. currencyType)
        table.insert(namesChanged, string.format(
            "WARN Currency ID %d name changed from '%s' to '%s' (name is localized)",
            currencyType,
            previousName,
            name
        ))
    end
    namesById[currencyType] = name
end

local function AuditCurrencyNames(accountWide)
    local namesById = accountWide.currencyNamesById
    if namesById == nil then
        namesById = {}
        accountWide.currencyNamesById = namesById
    elseif type(namesById) ~= "table" then
        error("Saved currencyNamesById data is not a table")
    end

    local namesChanged = {}
    local currencyCount = 0
    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currencyType) then
            local name = GetCurrencyName(currencyType, false, false)
            Check(type(name) == "string" and name ~= "", "Currency name is unavailable")
            currencyCount = currencyCount + 1
            RecordCurrencyName(namesById, currencyType, name, namesChanged)
        end
    end

    Check(currencyCount > 0, "No valid currency IDs were found")
    return currencyCount, namesChanged
end

------------------------------------------------------------------
-- Currency notification message scenarios
------------------------------------------------------------------
-- Each scenario feeds currency events through the real notification path with message output
-- captured, then compares the exact messages the player would see. The Expect* builders are the
-- one place that mirrors the message format; update them when the wording changes.
local function BigText(value)
    return (this.Utils.FormatBigNumber(value))
end

local function ExpectedBalances(bag, bank, abbreviated)
    local format = abbreviated and BigText or tostring
    return this.FormatBalanceEntry("bag", format(bag)) .. " · " .. this.FormatBalanceEntry("bank", format(bank))
end

local function ExpectChange(delta, bag, bank)
    local name = GetCurrencyName(CURT_MONEY, false, false)
    local header = this.FormatCurrencyChangeHeader(CURT_MONEY, delta > 0 and "gain" or "spend")
    local direction = delta > 0 and "Gained" or "Spent"
    local amount = math.abs(delta)
    return {
        chat = string.format("%s %s %s %s. You now have %s", header, direction, tostring(amount), name, ExpectedBalances(bag, bank, false)),
        hud = string.format("%s %s %s %s. You now have %s", header, direction, BigText(amount), name, ExpectedBalances(bag, bank, true)),
    }
end

local function ExpectTransfer(amount, isWithdrawal, bag, bank)
    local name = GetCurrencyName(CURT_MONEY, false, false)
    local header = this.FormatCurrencyChangeHeader(CURT_MONEY, "transfer")
    local from = isWithdrawal and "Bank" or "Backpack"
    local to = isWithdrawal and "Backpack" or "Bank"
    return {
        chat = string.format(
            "%s Transferred %s %s from %s to %s. You now have %s",
            header, tostring(amount), name, from, to, ExpectedBalances(bag, bank, false)
        ),
        hud = string.format(
            "%s Transferred %s %s from %s to %s. You now have %s",
            header, BigText(amount), name, from, to, ExpectedBalances(bag, bank, true)
        ),
    }
end

local function GetCurrencyMessageScenarios()
    local function Bag(amount, reason) return { location = CURRENCY_LOCATION_CHARACTER, amount = amount, reason = reason } end
    local function Bank(amount, reason) return { location = CURRENCY_LOCATION_BANK, amount = amount, reason = reason } end
    local Flush = { flush = true }
    local withdrawal = CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
    local deposit = CURRENCY_CHANGE_REASON_BANK_DEPOSIT

    -- Starting balances default to bag 1000 / bank 50000. Steps are events or a quiet period (Flush);
    -- a final quiet period always follows.
    return {
        {
            name = "Picking up 10 gold",
            steps = { Bag(1010) },
            expected = { ExpectChange(10, 1010, 50000) },
        },
        {
            name = "Picking up three 10-gold piles in quick succession merges",
            steps = { Bag(1010), Bag(1020), Bag(1030) },
            expected = { ExpectChange(30, 1030, 50000) },
        },
        {
            name = "Picking up three 10-gold piles with quiet periods between",
            steps = { Bag(1010), Flush, Bag(1020), Flush, Bag(1030) },
            expected = {
                ExpectChange(10, 1010, 50000),
                ExpectChange(10, 1020, 50000),
                ExpectChange(10, 1030, 50000),
            },
        },
        {
            name = "Withdrawing 10 gold (bank event first)",
            steps = { Bank(49990, withdrawal), Bag(1010, withdrawal) },
            expected = { ExpectTransfer(10, true, 1010, 49990) },
        },
        {
            name = "Withdrawing 10 gold (bag event first)",
            steps = { Bag(1010, withdrawal), Bank(49990, withdrawal) },
            expected = { ExpectTransfer(10, true, 1010, 49990) },
        },
        {
            name = "Depositing 10 gold",
            steps = { Bag(990, deposit), Bank(50010, deposit) },
            expected = { ExpectTransfer(10, false, 990, 50010) },
        },
        {
            name = "Withdrawing a large amount",
            bag = 0,
            bank = 2000000,
            steps = { Bank(500000, withdrawal), Bag(1500000, withdrawal) },
            expected = { ExpectTransfer(1500000, true, 1500000, 500000) },
        },
        {
            name = "Depositing a large amount",
            bag = 3400000,
            bank = 12345,
            steps = { Bag(400000, deposit), Bank(3012345, deposit) },
            expected = { ExpectTransfer(3000000, false, 400000, 3012345) },
        },
        {
            name = "Spending a large amount",
            bag = 5000000,
            bank = 123456,
            steps = { Bag(3765433) },
            expected = { ExpectChange(-1234567, 3765433, 123456) },
        },
        {
            name = "Spending a small amount",
            steps = { Bag(750) },
            expected = { ExpectChange(-250, 750, 50000) },
        },
        {
            name = "Login balance report is silent",
            steps = { Bag(5000, CURRENCY_CHANGE_REASON_PLAYER_INIT), Bank(60000, CURRENCY_CHANGE_REASON_PLAYER_INIT) },
            expected = {},
        },
        {
            name = "Withdrawing then depositing the same amount in one window sends nothing",
            steps = { Bank(49990, withdrawal), Bag(1010, withdrawal), Bag(1000, deposit), Bank(50000, deposit) },
            expected = {},
        },
        {
            name = "Pickup and withdrawal in one window show consistent balances",
            steps = { Bag(1010), Bank(49990, withdrawal), Bag(1020, withdrawal) },
            expected = { ExpectChange(10, 1020, 49990), ExpectTransfer(10, true, 1020, 49990) },
        },
    }
end

-- Alliance Points, Transmute Crystals and Trade Bars are stored differently from gold (and from each
-- other), so these scenarios read each currency's real storage layout from the game API and expect
-- the matching balance format: Account for account-wide, bag only, or bag plus bank.
local function GetCurrencyTypeMessageScenarios()
    local scenarios = {}
    local currencyTypes = {
        { name = "Alliance Points", type = CURT_ALLIANCE_POINTS },
        { name = "Transmute Crystals", type = CURT_TRANSMUTE_CRYSTALS },
        { name = "Trade Bars", type = CURT_TRADE_BARS },
    }

    for _, entry in ipairs(currencyTypes) do
        local currencyType = entry.type
        if currencyType ~= nil and IsCurrencyValid(currencyType) then
            local isAccount = GetCurrencyPlayerStoredLocation(currencyType) == CURRENCY_LOCATION_ACCOUNT
            local hasBank = not isAccount and CanCurrencyBeStoredInLocation(currencyType, CURRENCY_LOCATION_BANK)
            local primary = isAccount and CURRENCY_LOCATION_ACCOUNT or CURRENCY_LOCATION_CHARACTER
            local currencyName = GetCurrencyName(currencyType, false, false)

            local function Balances(primaryAmount, bankAmount, abbreviated)
                local format = abbreviated and BigText or tostring
                if isAccount then
                    if IsCurrencyCapped(currencyType, CURRENCY_LOCATION_ACCOUNT) then
                        local cap = GetMaxPossibleCurrency(currencyType, CURRENCY_LOCATION_ACCOUNT)
                        return this.FormatCappedBalance(currencyType, primaryAmount, cap, abbreviated)
                    end
                    return format(primaryAmount)
                end
                local text = this.FormatBalanceEntry("bag", format(primaryAmount))
                if hasBank then
                    text = text .. " · " .. this.FormatBalanceEntry("bank", format(bankAmount))
                end
                return text
            end

            local function Change(delta, primaryAmount, bankAmount)
                local header = this.FormatCurrencyChangeHeader(currencyType, delta > 0 and "gain" or "spend")
                local direction = delta > 0 and "Gained" or "Spent"
                local amount = math.abs(delta)
                return {
                    chat = string.format("%s %s %s %s. You now have %s", header, direction, tostring(amount), currencyName,
                        Balances(primaryAmount, bankAmount, false)),
                    hud = string.format("%s %s %s %s. You now have %s", header, direction, BigText(amount), currencyName,
                        Balances(primaryAmount, bankAmount, true)),
                }
            end

            local function Transfer(amount, isWithdrawal, bagAmount, bankAmount)
                local from = isWithdrawal and "Bank" or "Backpack"
                local to = isWithdrawal and "Backpack" or "Bank"
                local header = this.FormatCurrencyChangeHeader(currencyType, "transfer")
                return {
                    chat = string.format("%s Transferred %s %s from %s to %s. You now have %s", header, tostring(amount), currencyName,
                        from, to, Balances(bagAmount, bankAmount, false)),
                    hud = string.format("%s Transferred %s %s from %s to %s. You now have %s", header, BigText(amount), currencyName,
                        from, to, Balances(bagAmount, bankAmount, true)),
                }
            end

            local baselines = { [primary] = 100 }
            if hasBank then baselines[CURRENCY_LOCATION_BANK] = 500 end

            table.insert(scenarios, {
                name = entry.name .. " gained",
                currencyType = currencyType,
                baselines = baselines,
                steps = { { location = primary, amount = 110 } },
                expected = { Change(10, 110, 500) },
            })
            table.insert(scenarios, {
                name = entry.name .. " spent",
                currencyType = currencyType,
                baselines = baselines,
                steps = { { location = primary, amount = 95 } },
                expected = { Change(-5, 95, 500) },
            })
            if hasBank then
                table.insert(scenarios, {
                    name = entry.name .. " withdrawn from the bank",
                    currencyType = currencyType,
                    baselines = baselines,
                    steps = {
                        { location = CURRENCY_LOCATION_BANK, amount = 490, reason = CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL },
                        { location = CURRENCY_LOCATION_CHARACTER, amount = 110, reason = CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL },
                    },
                    expected = { Transfer(10, true, 110, 490) },
                })
                table.insert(scenarios, {
                    name = entry.name .. " deposited in the bank",
                    currencyType = currencyType,
                    baselines = baselines,
                    steps = {
                        { location = CURRENCY_LOCATION_CHARACTER, amount = 90, reason = CURRENCY_CHANGE_REASON_BANK_DEPOSIT },
                        { location = CURRENCY_LOCATION_BANK, amount = 510, reason = CURRENCY_CHANGE_REASON_BANK_DEPOSIT },
                    },
                    expected = { Transfer(10, false, 90, 510) },
                })
            end
        end
    end

    return scenarios
end

local function MessageSummary(message)
    return string.format(
        "%s{chat=%s, hud=%s}",
        message.suppressed and "SUPPRESSED " or "",
        tostring(message.chat),
        tostring(message.hud)
    )
end

local function SummarizeMessages(messages)
    local lines = {}
    for _, message in ipairs(messages) do
        table.insert(lines, MessageSummary(message))
    end
    table.sort(lines)
    return lines
end

local function RunCurrencyMessageScenario(scenario, verbose)
    local currencyType = scenario.currencyType or CURT_MONEY
    local savedPreferences = this.accountWide.currencyPreferences
    local clock = 100000

    local ok, err = pcall(function()
        this.accountWide.currencyPreferences = {}
        this.SetCurrencyNotificationEnabled(currencyType, true)
        this.BeginCurrencyNotificationSuppression(0)
        if scenario.baselines then
            for location, amount in pairs(scenario.baselines) do
                this.SetCurrencyNotificationBaseline(currencyType, location, amount)
            end
        else
            this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_CHARACTER, scenario.bag or 1000)
            this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_BANK, scenario.bank or 50000)
        end

        this.Utils.BeginMessageCapture(function() return clock end)
        for _, step in ipairs(scenario.steps) do
            if step.flush then
                clock = clock + 1100
                this.FlushCurrencyNotifications()
            else
                clock = clock + 50
                this.NotifyCurrencyChange(currencyType, step.location, step.amount, step.reason, clock)
            end
        end
        clock = clock + 1100
        this.FlushCurrencyNotifications()
    end)

    local captured = this.Utils.EndMessageCapture()
    this.BeginCurrencyNotificationSuppression(0)
    this.accountWide.currencyPreferences = savedPreferences
    if not ok then error(err, 0) end

    local actualLines = SummarizeMessages(captured)
    local expectedMessages = {}
    for _, message in ipairs(scenario.expected) do
        table.insert(expectedMessages, { chat = message.chat, hud = message.hud })
    end
    local expectedLines = SummarizeMessages(expectedMessages)

    if verbose then
        for _, line in ipairs(actualLines) do
            d("[InventoryCompanion tests] " .. scenario.name .. " -> " .. line)
        end
    end

    local matches = #actualLines == #expectedLines
    for index = 1, #expectedLines do
        matches = matches and actualLines[index] == expectedLines[index]
    end
    if not matches then
        error(string.format(
            "Unexpected messages\n  expected (%d):\n    %s\n  actual (%d):\n    %s",
            #expectedLines,
            table.concat(expectedLines, "\n    "),
            #actualLines,
            table.concat(actualLines, "\n    ")
        ), 0)
    end
end

local CAPACITY_TEST_MARKERS = {
    gain = "|t20:20:EsoUI/Art/Buttons/plus_up.dds|t",
    spend = "|t20:20:EsoUI/Art/Buttons/minus_up.dds|t",
    transfer = "|t20:20:EsoUI/Art/Miscellaneous/transform_arrow.dds|t",
}
local CAPACITY_TEST_BAG_ICON = "|t20:20:EsoUI/Art/Tooltips/icon_bag.dds|t"
local CAPACITY_TEST_BANK_ICON = "|t20:20:EsoUI/Art/Tooltips/icon_bank.dds|t"

local function GetCapacityMessageScenarios()
    local function Balance(kind, used, max)
        return this.FormatCapacityBalance(kind, used, max)
    end
    local function Same(text) return { chat = text, hud = text } end
    local function Freed(count, used, max)
        return Same(string.format("%s%s Freed up %d Bag Space. You now have %s",
            CAPACITY_TEST_MARKERS.gain, CAPACITY_TEST_BAG_ICON, count, Balance("bag", used, max)))
    end
    local function Used(count, used, max)
        return Same(string.format("%s%s Used an additional %d Bag Space. You now have %s",
            CAPACITY_TEST_MARKERS.spend, CAPACITY_TEST_BAG_ICON, count, Balance("bag", used, max)))
    end
    local function Moved(count, fromBank, bagUsed, bankUsed)
        return Same(string.format("%s You just moved %d %s from your %s to your %s. You now have %s %s · %s %s",
            CAPACITY_TEST_MARKERS.transfer, count, count == 1 and "item" or "items",
            fromBank and "bank" or "bag", fromBank and "bag" or "bank",
            CAPACITY_TEST_BAG_ICON, Balance("bag", bagUsed, 100),
            CAPACITY_TEST_BANK_ICON, Balance("bank", bankUsed, 200)))
    end
    local function Bag(used) return { kind = "bag", used = used, max = 100 } end
    local function Bank(used, atBank, items) return { kind = "bank", used = used, max = 200, atBank = atBank, items = items } end
    local function BagAtBank(used, items) return { kind = "bag", used = used, max = 100, atBank = true, items = items } end

    return {
        { name = "bag space used by looting", steps = { Bag(52) }, expected = { Used(2, 52, 100) } },
        { name = "bag space freed by selling", steps = { Bag(49), Bag(47) }, expected = { Freed(3, 47, 100) } },
        { name = "bag changes that cancel out", steps = { Bag(51), Bag(50) }, expected = {} },
        { name = "bag space crossing the warning and danger thresholds", baselines = { bag = 74 },
            steps = { Bag(76) }, expected = { Used(2, 76, 100) } },
        { name = "bank to bag move", steps = { Bank(38, true), BagAtBank(52) },
            expected = { Moved(2, true, 52, 38) } },
        { name = "bag to bank move", steps = { BagAtBank(47), Bank(43, true) },
            expected = { Moved(3, false, 47, 43) } },
        { name = "moving a stack of 10 counts all items", steps = { Bank(41, true, 10), BagAtBank(49, -10) },
            expected = { Moved(10, false, 49, 41) } },
        { name = "stack merged into an existing stack still reports the move",
            steps = { Bank(40, true, 10), BagAtBank(50, -10) }, expected = { Moved(10, false, 50, 40) } },
        { name = "bank change away from the bank is silent", steps = { Bank(38) }, expected = {} },
        { name = "opposite changes without a bank visit are bag-only", steps = { Bank(38), Bag(52) },
            expected = { Used(2, 52, 100) } },
        { name = "transfer plus a pickup", steps = { Bank(39, true), BagAtBank(52) },
            expected = { Moved(1, true, 52, 39), Used(1, 52, 100) } },
        { name = "bag-only notification during a withdrawal", enabled = { bag = true },
            steps = { Bank(38, true), BagAtBank(52) }, expected = { Used(2, 52, 100) } },
        { name = "disabled notifications stay silent", enabled = {}, steps = { Bag(60), Bank(30, true) }, expected = {} },
        { name = "load-screen reports stay silent", suppressed = true, steps = { Bag(70), Bank(10, true) }, expected = {} },
    }
end

local function RunCapacityMessageScenario(scenario, verbose)
    local savedPreferences = this.accountWide.capacityPreferences
    local clock = 100000

    local ok, err = pcall(function()
        this.accountWide.capacityPreferences = {}
        for _, kind in ipairs({ "bag", "bank" }) do
            local enabled = scenario.enabled == nil or scenario.enabled[kind] == true
            this.SetCapacityNotificationEnabled(kind, enabled)
        end
        this.BeginCurrencyNotificationSuppression(scenario.suppressed and clock or 0)
        local baselines = scenario.baselines or {}
        this.SetCapacityNotificationBaseline("bag", baselines.bag or 50)
        this.SetCapacityNotificationBaseline("bank", baselines.bank or 40)

        this.Utils.BeginMessageCapture(function() return clock end)
        for _, step in ipairs(scenario.steps) do
            clock = clock + 50
            this.NotifyCapacityChange(step.kind, step.used, step.max, clock, step.atBank == true, step.items)
        end
        clock = clock + 1100
        this.FlushCurrencyNotifications()
    end)

    local captured = this.Utils.EndMessageCapture()
    this.BeginCurrencyNotificationSuppression(0)
    this.accountWide.capacityPreferences = savedPreferences
    if not ok then error(err, 0) end

    local expectedMessages = {}
    for _, message in ipairs(scenario.expected) do
        table.insert(expectedMessages, { chat = message.chat, hud = message.hud })
    end
    local actualLines = SummarizeMessages(captured)
    local expectedLines = SummarizeMessages(expectedMessages)
    if verbose then
        for _, line in ipairs(actualLines) do
            d("[InventoryCompanion tests] " .. scenario.name .. " -> " .. line)
        end
    end

    local matches = #actualLines == #expectedLines
    for index = 1, #expectedLines do
        matches = matches and actualLines[index] == expectedLines[index]
    end
    if not matches then
        error(string.format(
            "Unexpected messages\n  expected (%d):\n    %s\n  actual (%d):\n    %s",
            #expectedLines,
            table.concat(expectedLines, "\n    "),
            #actualLines,
            table.concat(actualLines, "\n    ")
        ), 0)
    end
end

local function RunBankItems(arguments)
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion bank items] Addon is not fully loaded.")
        return
    end
    if not IsBankOpen() then
        d("[InventoryCompanion bank items] Open a bank or house chest before running this command.")
        return
    end

    local limitText = tostring(arguments or ""):match("^%s*(.-)%s*$")
    local limit = limitText == "" and 10 or tonumber(limitText)
    if not limit or limit % 1 ~= 0 or limit < 1 or limit > 20 then
        d("[InventoryCompanion bank items] Usage: /icbankitems [1-20]")
        return
    end

    local bags = {
        { id = BAG_BANK, label = "Standard bank" },
        { id = BAG_SUBSCRIBER_BANK, label = "ESO Plus subscriber bank" },
    }

    for _, bag in ipairs(bags) do
        if bag.id ~= BAG_SUBSCRIBER_BANK or IsESOPlusSubscriber() then
            local contents = this.Scanning.GetBagContents({ bag.id })
            d(string.format(
                "[InventoryCompanion bank items] %s: %d occupied slots; listing up to %d.",
                bag.label,
                #contents,
                limit
            ))

            for index = 1, math.min(#contents, limit) do
                local item = contents[index]
                d(string.format(
                    "  x%s %s (item ID %s, slot %s)",
                    tostring(item.count),
                    GetItemLinkName(item.link) or item.link,
                    tostring(item.itemId),
                    tostring(item.slotIndex)
                ))
            end
        else
            d("[InventoryCompanion bank items] ESO Plus subscriber bank unavailable on this account.")
        end
    end
end

local function RunCleanup()
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion cleanup] Addon is not fully loaded.")
        return
    end

    local pruneOk, removedDiagnosticCount = pcall(function()
        return PruneDiagnosticSavedVariables(this.accountWide, this.character)
    end)
    if pruneOk then
        d(string.format(
            "[InventoryCompanion cleanup] Removed %d known diagnostic saved-variable entries.",
            removedDiagnosticCount
        ))
    else
        d("[InventoryCompanion cleanup] Failed to prune diagnostic entries: " .. tostring(removedDiagnosticCount))
    end

    local currencyAuditOk, currencyCount, changedCurrencyNames = pcall(function()
        local count, changes = AuditCurrencyNames(this.accountWide)
        return count, changes
    end)
    if currencyAuditOk then
        d(string.format("[InventoryCompanion cleanup] Checked %d valid currency IDs.", currencyCount))
        for _, warning in ipairs(changedCurrencyNames) do
            d("[InventoryCompanion cleanup] " .. warning)
        end
    else
        d("[InventoryCompanion cleanup] Failed to audit currency names: " .. tostring(currencyCount))
    end
end

local function CollectTestDiscovery(lines)
    local apiVersion = GetAPIVersion()
    Check(type(apiVersion) == "number" and apiVersion > 0, "Running API version is unavailable")
    table.insert(lines, string.format(
        "INFO Environment: timestamp=%s (Unix UTC); game=%s; API=%d; server=%s; language=%s",
        tostring(GetTimeStamp()), GetESOVersionString(), apiVersion, GetWorldName(), GetCVar("language.2")
    ))
    table.insert(lines, string.format(
        "INFO Installation: %s; runtime version=%s; DEV=%s; ESO Plus=%s; bank=%s",
        this.Name, this.Version, tostring(this.IsDevelopment == true),
        tostring(IsESOPlusSubscriber()), IsBankOpen() and "open" or "closed"
    ))

    local manager = GetAddOnManager()
    local foundInstallation = false
    for index = 1, manager:GetNumAddOns() do
        local name, _, _, _, enabled, state, isOutOfDate = manager:GetAddOnInfo(index)
        if enabled then
            local version = manager:GetAddOnVersion(index)
            Check(type(version) == "number" and version >= 0 and version % 1 == 0,
                "Integer AddOnVersion is unavailable for " .. tostring(name))
            table.insert(lines, string.format(
                "INFO Enabled add-on: %s; AddOnVersion=%s; state=%s; outOfDate=%s",
                name, tostring(version), tostring(state), tostring(isOutOfDate)
            ))
            if name == this.Name then
                foundInstallation = true
            end
        end
    end
    Check(foundInstallation, "Running installation was not found among enabled add-ons")

    for _, entry in ipairs({
        { name = "Alliance Points", id = CURT_ALLIANCE_POINTS },
        { name = "Transmute Crystals", id = CURT_TRANSMUTE_CRYSTALS },
        { name = "Trade Bars", id = CURT_TRADE_BARS },
    }) do
        local valid = entry.id ~= nil and IsCurrencyValid(entry.id)
        table.insert(lines, string.format(
            "INFO Conditional currency coverage: %s; ID=%s; available=%s",
            entry.name, tostring(entry.id), tostring(valid)
        ))
        if not valid then
            table.insert(lines, "WARN Currency message scenarios unavailable for " .. entry.name)
        elseif entry.id == CURT_TRANSMUTE_CRYSTALS then
            local location = GetCurrencyPlayerStoredLocation(entry.id)
            local capped = IsCurrencyCapped(entry.id, location)
            table.insert(lines, "INFO Transmute Crystals capped-colour assertions enabled=" .. tostring(capped))
            if not capped then
                table.insert(lines, "WARN Transmute Crystals capped-colour assertions are not exercised")
            end
        end
    end
    table.insert(lines, "INFO Human evidence still required: Live/PTS channel, candidate SHA256/installation verification, manifest API/minimum-version comparison, UI/event delivery, transfers, persistence and collision checks.")
    table.insert(lines, "INFO Safety: live scans are read-only; synthetic tests temporarily replace runtime state and restore it; no inventory transfers or intentional saved-variable writes.")
end

local function RunTests(arguments)
    if not this.state or not this.state.isLoaded then
        d("[InventoryCompanion tests] Addon is not fully loaded.")
        return
    end

    local options = {}
    for option in tostring(arguments or ""):lower():gmatch("%S+") do
        if option ~= "verbose" and option ~= "copy" then
            d("[InventoryCompanion tests] Usage: /ictest [verbose] [copy]")
            return
        end
        options[option] = true
    end

    local liveScanIterations = 100
    local liveScanLimitMs = 500
    local liveScanMs
    local liveItemCount
    local bankOpenDuringLiveScan = IsBankOpen()

    local original = {
        getBagContents = this.Scanning.GetBagContents,
        getItemLinkName = _G.GetItemLinkName,
    }

    local results = {}
    local passed = 0
    local discovery = {}
    local discoveryOk, discoveryError = pcall(CollectTestDiscovery, discovery)
    if discoveryOk then
        passed = passed + 1
        table.insert(results, "PASS Runtime and dependency discovery")
    else
        table.insert(results, "FAIL Runtime and dependency discovery: " .. tostring(discoveryError))
    end

    local liveBagIds = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
    if IsESOPlusSubscriber() then
        table.insert(liveBagIds, BAG_VIRTUAL)
    end

    local scanOk, scanError = pcall(function()
        local startedAt = GetGameTimeMilliseconds()
        for iteration = 1, liveScanIterations do
            local contents = original.getBagContents(liveBagIds)
            if iteration == liveScanIterations then
                liveItemCount = #contents
                for _, itemData in ipairs(contents) do
                    Check(itemData.itemId and itemData.itemId > 0, "Live scan returned an invalid item ID")
                    Check(itemData.link and itemData.link ~= "", "Live scan returned an empty item link")
                    Check(type(itemData.count) == "number", "Live scan returned an invalid stack count")
                end
            end
        end
        liveScanMs = GetGameTimeMilliseconds() - startedAt
    end)

    if scanOk then
        local result = string.format(
            "PASS Live read-only scan: %d scans, %d occupied entries on final scan, bank %s",
            liveScanIterations,
            liveItemCount,
            bankOpenDuringLiveScan and "open" or "closed"
        )
        if liveScanMs > liveScanLimitMs then
            result = string.format(
                "FAIL %s; took %d ms (target <= %d ms)",
                result:sub(6),
                liveScanMs,
                liveScanLimitMs
            )
        else
            passed = passed + 1
        end
        table.insert(results, result)
    else
        table.insert(results, "FAIL Live read-only scan: " .. tostring(scanError))
    end

    local syntheticOriginal = {
        accountWide = this.accountWide,
        character = this.character,
        preLoadedRulesets = this.preLoadedRulesets,
        getBagContents = this.Scanning.GetBagContents,
        getActiveTrackedItems = this.GetActiveTrackedItems,
        getActiveTrackedRules = this.GetActiveTrackedRules,
        getItemLinkName = _G.GetItemLinkName,
        getItemId = _G.GetItemId,
        getItemLink = _G.GetItemLink,
        isESOPlusSubscriber = _G.IsESOPlusSubscriber,
        userWarning = this.Utils.UserWarning,
    }

    local namesByLink = {
        ["item-exact"] = "Mundane Rune",
        ["item-wildcard"] = "Treasure Map: Glenumbra",
        ["item-special"] = "Wayfinder's Kit +1",
    }

    local syntheticBags = {
        [BAG_BACKPACK] = {},
        [BAG_VIRTUAL] = {},
    }
    for index = 1, 100 do
        local link = "synthetic-item-" .. index
        namesByLink[link] = string.format("Synthetic Item %03d", index)
        local bagId = index <= 50 and BAG_BACKPACK or BAG_VIRTUAL
        table.insert(syntheticBags[bagId], {
            bagId = bagId,
            slotIndex = index,
            itemId = 980000 + index,
            link = link,
            icon = "synthetic-icon",
            count = 1,
            maxCount = 200,
        })
    end

    local performanceMs
    local slotMatchMs
    local slotUpdateMs
    local performanceLimitMs = 500
    local slotMatchLimitMs = 100
    local slotUpdateLimitMs = 200
    local environmentOk, environmentError = pcall(function()
        this.accountWide = { trackedRules = {} }
        this.character = { useCharacterItemList = false }
        this.preLoadedRulesets = {}
        this.Scanning.GetBagContents = function(bagIds, selectFunc)
            local contents = {}
            for _, bagId in ipairs(bagIds) do
                for _, itemData in ipairs(syntheticBags[bagId] or {}) do
                    if not selectFunc or selectFunc(itemData) then
                        table.insert(contents, itemData)
                    end
                end
            end
            return contents
        end
        _G.GetItemLinkName = function(itemLink)
            return namesByLink[itemLink]
        end
        _G.GetItemId = function(bagId, slotIndex)
            local itemData = syntheticBags[bagId] and syntheticBags[bagId][slotIndex]
            return itemData and itemData.itemId or 0
        end
        _G.GetItemLink = function(bagId, slotIndex)
            local itemData = syntheticBags[bagId] and syntheticBags[bagId][slotIndex]
            return itemData and itemData.link or ""
        end
        _G.IsESOPlusSubscriber = function()
            return true
        end

        local baselineRules = {
            default = {
                displayName = "Default Group",
                patterns = { "Default *" },
                display = {
                    show = true,
                    notify = false,
                    bank = false,
                    group = true,
                    isExpanded = true,
                    isHidden = false,
                },
            },
            hidden = {
                displayName = "Hidden Group",
                patterns = { "Hidden *" },
                display = { show = true, notify = false, bank = false, group = true, isExpanded = true, isHidden = false },
            },
        }

        local tests = {
            {
                name = "Progress bar resource model and preferences",
                run = function()
                    local savedPreferences = this.accountWide.progressBarPreferences
                    local savedAlertColors = this.accountWide.progressBarAlertColors
                    local savedTestValue = this.accountWide.unrelatedProgressTestValue
                    local ok, err = pcall(function()
                        this.accountWide.progressBarPreferences = {}
                        this.accountWide.progressBarAlertColors = {}
                        local resources = this.GetProgressBarResources()
                        local resourcesByKey = {}
                        local capacityCount = 0

                        for _, resource in ipairs(resources) do
                            Check(type(resource.key) == "string" and resource.key ~= "", "Progress resource needs a stable key")
                            Check(not resourcesByKey[resource.key], "Progress resource keys must be unique")
                            resourcesByKey[resource.key] = resource

                            local values = this.GetProgressBarResourceValues(resource)
                            Check(values ~= nil, "Progress resource values should be available")
                            Check(type(values.amount) == "number", "Progress resource amount should be numeric")
                            Check(type(values.cap) == "number" and values.cap > 0, "Progress resource cap should be positive")

                            local settings = this.GetProgressBarSettings(resource.key)
                            Check(type(settings.showBar) == "boolean", "Progress bar visibility default should be boolean")
                            Check(
                                settings.warningThreshold >= 0
                                    and settings.warningThreshold <= settings.dangerThreshold
                                    and settings.dangerThreshold <= 1,
                                "Progress bar thresholds should be ordered within 0 to 1"
                            )

                            if resource.kind == "capacity" then
                                capacityCount = capacityCount + 1
                                CheckEqual(resource.defaultShowBar, true, "Capacity bars should preserve their visible defaults")
                            else
                                CheckEqual(resource.kind, "currency", "Progress resource kind should be capacity or currency")
                                CheckEqual(resource.defaultShowBar, false, "Capped currency bars should default to hidden")
                            end
                        end

                        CheckEqual(capacityCount, 2, "Expected backpack and bank capacity resources")
                        local bag = resourcesByKey["capacity:bag"]
                        local bank = resourcesByKey["capacity:bank"]
                        Check(bag ~= nil and bank ~= nil, "Expected stable backpack and bank resource identities")
                        CheckEqual(this.GetProgressBarSettings(bag.key).warningThreshold, 0.75, "Backpack warning default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bag.key).dangerThreshold, 0.90, "Backpack danger default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bank.key).warningThreshold, 0.80, "Bank warning default should be preserved")
                        CheckEqual(this.GetProgressBarSettings(bank.key).dangerThreshold, 0.95, "Bank danger default should be preserved")
                        local originalNormalColor = this.GetProgressBarNormalColor(bag.key)
                        this.SetProgressBarSetting(bag.key, "normalColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 })
                        local changedNormalColor = this.GetProgressBarSettings(bag.key).normalColor
                        CheckEqual(changedNormalColor.r, 0.1, "Per-bar normal color should persist")
                        CheckEqual(this.GetProgressBarSettings(bank.key).normalColor, nil, "Per-bar normal colors should be independent")
                        this.SetProgressBarAlertColor("warning", { r = 0.7, g = 0.6, b = 0.2, a = 1 })
                        CheckEqual(this.GetProgressBarAlertColor("warning").g, 0.6, "Shared warning color should persist")
                        CheckEqual(this.GetProgressBarAlertColor("danger").r, 0.85, "Changing warning color should not alter danger color")
                        Check(type(originalNormalColor) == "table", "Default normal color should be available to settings")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetX, 50, "Backpack default horizontal position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetY, 90, "Backpack default vertical position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetX, 50, "Bank default horizontal position should be stable")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetY, 130, "Bank default vertical position should be stable")
                        this.SetProgressBarPosition(bag.key, 25, 35)
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetX, 25, "Backpack position should persist independently")
                        CheckEqual(this.GetProgressBarSettings(bag.key).offsetY, 35, "Backpack position should persist independently")
                        CheckEqual(this.GetProgressBarSettings(bank.key).offsetY, 130, "Moving backpack should not move bank")

                        for _, currencyType in ipairs(this.GetCappedCurrencyList()) do
                            local key = "currency:" .. tostring(currencyType)
                            Check(resourcesByKey[key] ~= nil, "Every capped ESO currency should have a progress resource")
                            local info = this.GetCappedCurrencyInfo(currencyType)
                            Check(info and type(info.amount) == "number" and type(info.cap) == "number", "Capped currency values should be numeric")
                        end

                        this.accountWide.unrelatedProgressTestValue = "preserved"
                        this.SetProgressBarSetting(bag.key, "showBar", false)
                        CheckEqual(this.GetProgressBarSettings(bag.key).showBar, false, "False visibility overrides should persist")
                        CheckEqual(this.GetProgressBarSettings(bank.key).showBar, true, "Visibility preferences should be independent")
                        for _, resource in ipairs(resources) do
                            if resource.kind == "currency" then
                                this.SetProgressBarSetting(resource.key, "showBar", true)
                                CheckEqual(this.GetProgressBarSettings(resource.key).showBar, true, "Currency bars should be independently configurable")
                                Check(this.HasVisibleCurrencyProgressBars(), "An enabled capped-currency bar should be discoverable by event registration")
                                Check(this.IsCurrencyProgressBarVisible(resource.currencyType), "An enabled capped-currency bar should be individually discoverable")
                                CheckEqual(this.GetProgressBarSettings(bag.key).showBar, false, "Currency preferences should not affect capacity bars")
                                break
                            end
                        end

                        this.SetProgressBarSetting(bag.key, "warningThreshold", 0.96)
                        local settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.warningThreshold, 0.96, "Warning threshold change should be retained")
                        CheckEqual(settings.dangerThreshold, 0.96, "Crossing warning should move danger to the selected value")
                        this.SetProgressBarSetting(bag.key, "dangerThreshold", 0.20)
                        settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.warningThreshold, 0.20, "Crossing danger should move warning to the selected value")
                        CheckEqual(settings.dangerThreshold, 0.20, "Danger threshold change should be retained")

                        this.accountWide.progressBarPreferences = {
                            [bag.key] = { showBar = "invalid", warningThreshold = 1.5, dangerThreshold = 0.2 },
                            ["capacity:future"] = { futureSetting = true },
                        }
                        settings = this.GetProgressBarSettings(bag.key)
                        CheckEqual(settings.showBar, true, "Malformed visibility should fall back to the resource default")
                        CheckEqual(settings.warningThreshold, 0.75, "Malformed threshold ordering should fall back to defaults")
                        CheckEqual(settings.dangerThreshold, 0.90, "Malformed threshold ordering should fall back to defaults")
                        CheckEqual(
                            this.accountWide.progressBarPreferences["capacity:future"].futureSetting,
                            true,
                            "Unknown resource preferences should be preserved"
                        )
                        this.accountWide.progressBarPreferences = "malformed"
                        CheckEqual(this.GetProgressBarSettings(bag.key).showBar, true, "Malformed preference tables should use resource defaults")
                        Check(type(this.accountWide.progressBarPreferences) == "table", "Malformed preference tables should be recovered")
                        CheckEqual(this.accountWide.unrelatedProgressTestValue, "preserved", "Unrelated saved variables should remain unchanged")
                    end)
                    this.accountWide.progressBarPreferences = savedPreferences
                    this.accountWide.progressBarAlertColors = savedAlertColors
                    this.accountWide.unrelatedProgressTestValue = savedTestValue
                    if not ok then error(err) end
                end,
            },
            {
                name = "Currency notification preferences and changes",
                run = function()
                    local savedPreferences = this.accountWide.currencyPreferences
                    local savedUserWarning = this.Utils.UserWarning
                    local ok, err = pcall(function()
                        local currencyTypes = this.GetCurrencyList()
                        local currencyType = CURT_MONEY
                        Check(currencyType ~= nil, "Expected a currency for notification tests")
                        local isGoldAvailable = false
                        for _, availableCurrencyType in ipairs(currencyTypes) do
                            if availableCurrencyType == currencyType then
                                isGoldAvailable = true
                                break
                            end
                        end
                        Check(isGoldAvailable, "Expected gold to be initialized for notification tests")
                        this.accountWide.currencyPreferences = {}
                        local notifications = {}
                        this.Utils.UserWarning = function(chat, hud)
                            table.insert(notifications, { chat = chat, hud = hud })
                        end

                        this.SetCurrencyNotificationEnabled(currencyType, true)
                        Check(this.IsCurrencyNotificationEnabled(currencyType), "Currency notification preference should turn on")
                        Check(this.HasCurrencyNotifications(), "Enabled currency notification should request an event listener")

                        this.BeginCurrencyNotificationSuppression(0)
                        local location = CURRENCY_LOCATION_CHARACTER
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 20),
                            "A login balance matching the baseline should not notify"
                        )
                        Check(not this.FlushCurrencyNotifications(), "Unchanged balances should queue nothing")
                        CheckEqual(#notifications, 0, "Startup balances should not produce notifications")

                        Check(this.NotifyCurrencyChange(currencyType, location, 25), "Positive currency changes should queue")
                        CheckEqual(#notifications, 0, "Changes should be held until the quiet period ends")
                        Check(this.FlushCurrencyNotifications(), "A held change should announce when flushed")
                        CheckEqual(#notifications, 1, "One positive change should produce one notification")
                        Check(notifications[1].chat:find("Gained 5 ", 1, true) ~= nil, "Gain should identify the amount gained")

                        this.NotifyCurrencyChange(currencyType, location, 20)
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 2, "A currency decrease should produce a notification")
                        Check(
                            notifications[2].chat:find("Spent 5 ", 1, true) ~= nil,
                            "Currency decrease notification should identify the amount spent"
                        )

                        this.NotifyCurrencyChange(currencyType, location, 1020)
                        this.NotifyCurrencyChange(currencyType, location, 2020)
                        this.NotifyCurrencyChange(currencyType, location, 12020)
                        CheckEqual(#notifications, 2, "A burst should not announce each change")
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 3, "A burst should produce one combined notification")
                        Check(
                            notifications[3].chat:find(" 12000 ", 1, true) ~= nil
                                and notifications[3].chat:find(this.FormatCurrencyChangeHeader(currencyType, "gain"), 1, true) ~= nil
                                and notifications[3].chat:find(this.FormatBalanceEntry("bag", "12020"), 1, true) ~= nil
                                and notifications[3].chat:find(this.FormatBalanceIcon("EsoUI/Art/Tooltips/icon_bank.dds"), 1, true) ~= nil
                                and notifications[3].hud:find(" 12k ", 1, true) ~= nil
                                and notifications[3].hud:find(this.FormatBalanceEntry("bag", "12k"), 1, true) ~= nil
                                and notifications[3].hud:find("· " .. this.FormatBalanceIcon("EsoUI/Art/Tooltips/icon_bank.dds"), 1, true) ~= nil,
                            "Combined notification should use exact chat balances and abbreviated HUD balances with explicit locations"
                        )

                        this.NotifyCurrencyChange(currencyType, location, 13020)
                        this.NotifyCurrencyChange(currencyType, location, 12020)
                        Check(not this.FlushCurrencyNotifications(), "Changes that cancel out should not announce")
                        CheckEqual(#notifications, 3, "Net-zero bursts should add no notifications")

                        Check(
                            CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL ~= nil,
                            "Expected the bank withdrawal currency change reason"
                        )
                        this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_CHARACTER, 12020)
                        this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_BANK, 500)
                        this.NotifyCurrencyChange(
                            currencyType,
                            CURRENCY_LOCATION_BANK,
                            490,
                            CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
                        )
                        this.NotifyCurrencyChange(
                            currencyType,
                            CURRENCY_LOCATION_CHARACTER,
                            12030,
                            CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
                        )
                        Check(this.FlushCurrencyNotifications(), "A bank withdrawal should announce as one transfer")
                        CheckEqual(#notifications, 4, "A bank withdrawal should produce one notification")
                        Check(
                            notifications[4].chat:find(this.FormatCurrencyChangeHeader(currencyType, "transfer") .. " Transferred 10 ", 1, true) ~= nil
                                and notifications[4].chat:find("from Bank to Backpack", 1, true) ~= nil
                                and notifications[4].chat:find(this.FormatBalanceEntry("bag", "12030"), 1, true) ~= nil
                                and notifications[4].chat:find(this.FormatBalanceEntry("bank", "490"), 1, true) ~= nil
                                and notifications[4].hud:find(this.FormatCurrencyChangeHeader(currencyType, "transfer") .. " Transferred 10 ", 1, true) ~= nil
                                and notifications[4].hud:find(this.FormatBalanceEntry("bag", "12k") .. " · " .. this.FormatBalanceEntry("bank", "490"), 1, true) ~= nil,
                            "Bank withdrawal notification should identify the transfer direction"
                        )

                        Check(
                            CURRENCY_CHANGE_REASON_BANK_DEPOSIT ~= nil,
                            "Expected the bank deposit currency change reason"
                        )
                        this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_CHARACTER, 12030)
                        this.SetCurrencyNotificationBaseline(currencyType, CURRENCY_LOCATION_BANK, 490)
                        this.NotifyCurrencyChange(
                            currencyType,
                            CURRENCY_LOCATION_BANK,
                            515,
                            CURRENCY_CHANGE_REASON_BANK_DEPOSIT
                        )
                        this.NotifyCurrencyChange(
                            currencyType,
                            CURRENCY_LOCATION_CHARACTER,
                            12005,
                            CURRENCY_CHANGE_REASON_BANK_DEPOSIT
                        )
                        Check(this.FlushCurrencyNotifications(), "A bank deposit should announce as one transfer")
                        CheckEqual(#notifications, 5, "A bank deposit should produce one notification")
                        Check(
                            notifications[5].chat:find(this.FormatCurrencyChangeHeader(currencyType, "transfer") .. " Transferred 25 ", 1, true) ~= nil
                                and notifications[5].chat:find("from Backpack to Bank", 1, true) ~= nil
                                and notifications[5].chat:find(this.FormatBalanceEntry("bag", "12005"), 1, true) ~= nil
                                and notifications[5].chat:find(this.FormatBalanceEntry("bank", "515"), 1, true) ~= nil
                                and notifications[5].hud:find(this.FormatBalanceEntry("bag", "12k") .. " · " .. this.FormatBalanceEntry("bank", "515"), 1, true) ~= nil,
                            "Bank deposit notification should identify the transfer direction"
                        )

                        local unseededLocation = CURRENCY_LOCATION_BANK
                        this.SetCurrencyNotificationBaseline(currencyType, unseededLocation, nil)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, unseededLocation, 500),
                            "The first observed balance should initialize silently"
                        )
                        CheckEqual(#notifications, 5, "Initializing a balance should not add notifications")

                        this.BeginCurrencyNotificationSuppression(1000)
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 0, nil, 2000),
                            "Balance reports shortly after a load screen should not notify"
                        )
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 20, nil, 3000),
                            "Restored balances after a load screen should not notify"
                        )
                        Check(not this.FlushCurrencyNotifications(), "Load-screen reports should queue nothing")
                        Check(
                            this.NotifyCurrencyChange(currencyType, location, 25, nil, 7000),
                            "Changes after the load window should queue"
                        )
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 6, "A change after the load window should notify")
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)

                        this.SetCurrencyNotificationEnabled(currencyType, false)
                        Check(not this.HasCurrencyNotifications(), "Disabled currency notifications should release the event listener")
                        this.SetCurrencyNotificationBaseline(currencyType, location, 20)
                        Check(
                            not this.NotifyCurrencyChange(currencyType, location, 30),
                            "Disabled currency notifications should not emit messages"
                        )
                        this.FlushCurrencyNotifications()
                        CheckEqual(#notifications, 6, "Disabled currency notification should not add messages")
                    end)
                    this.FlushCurrencyNotifications()
                    this.SeedCurrencyNotificationBaselines()
                    this.accountWide.currencyPreferences = savedPreferences
                    this.Utils.UserWarning = savedUserWarning
                    if not ok then error(err) end
                end,
            },
            {
                name = "Prune known saved-variable diagnostic keys only",
                run = function()
                    local accountWide = {
                        currencyInfo = { CURT_EVENT_TICKETS = { currencyType = 18 } },
                        nested = { lastquery = { stale = true }, keep = "value" },
                        trackedRules = { keep = true, lastquery = { patterns = { "Last Query*" } } },
                    }
                    local character = {
                        nested = { LastQuery = "stale" },
                        trackedItems = { keep = true },
                    }

                    local removedCount = PruneDiagnosticSavedVariables(accountWide, character)
                    CheckEqual(removedCount, 3, "Only known diagnostic data should be removed")
                    Check(accountWide.currencyInfo == nil, "Currency diagnostic data should be removed")
                    Check(accountWide.nested.lastquery == nil, "Nested lastquery data should be removed")
                    Check(character.nested.LastQuery == nil, "Case-insensitive lastquery data should be removed")
                    CheckEqual(accountWide.nested.keep, "value", "Unrelated account settings should remain")
                    Check(accountWide.trackedRules.keep, "Tracked rules should remain")
                    Check(accountWide.trackedRules.lastquery ~= nil, "A user-created rule named lastquery should remain")
                    Check(character.trackedItems.keep, "Tracked items should remain")

                    local currencyNames = { [42] = "Old Name" }
                    local nameWarnings = {}
                    RecordCurrencyName(currencyNames, 42, "New Name", nameWarnings)
                    CheckEqual(#nameWarnings, 1, "A renamed currency ID should produce one warning")
                    Check(nameWarnings[1]:find("Currency ID 42", 1, true) ~= nil, "Warning should identify the currency ID")
                    CheckEqual(currencyNames[42], "New Name", "Currency name history should track the latest name")
                    RecordCurrencyName(currencyNames, 42, "New Name", nameWarnings)
                    CheckEqual(#nameWarnings, 1, "An unchanged currency name should not warn again")
                end,
            },
            {
                name = "Currency panel resource preferences",
                run = function()
                    local savedCurrencyPreferences = this.accountWide.currencyPreferences
                    local savedCapacityPreferences = this.accountWide.capacityPreferences
                    local ok, err = pcall(function()
                        this.accountWide.currencyPreferences = {}
                        this.accountWide.capacityPreferences = {}

                        local entries = this.GetCurrencyPanelResourceEntries()
                        Check(#entries > 0, "Expected currency and capacity resources")

                        local currencyEntry
                        for _, entry in ipairs(entries) do
                            Check(entry.isVisible, "Resources should be visible by default")
                            if entry.kind == "currency" and not currencyEntry then
                                currencyEntry = entry
                            elseif entry.kind == "capacity" then
                                CheckEqual(
                                    this.IsCapacityResourceVisible(entry.resourceKey),
                                    true,
                                    "Capacity resources should be visible by default"
                                )
                            end
                        end
                        Check(currencyEntry ~= nil, "Expected a discovered currency resource")

                        this.accountWide.capacityPreferences.bag = { showCompact = false }
                        CheckEqual(this.IsCapacityResourceVisible("bag"), false, "A hidden backpack capacity should report hidden")
                        this.accountWide.capacityPreferences.bag.showCompact = nil
                        CheckEqual(this.IsCapacityResourceVisible("bag"), true, "A shown backpack capacity should report visible")

                        this.accountWide.currencyPreferences[currencyEntry.currencyType] = {
                            locations = {
                                [currencyEntry.location] = { hidden = true },
                            },
                        }
                        local hiddenCount = 0
                        for _, entry in ipairs(this.GetCurrencyPanelResourceEntries()) do
                            if entry.key == currencyEntry.key then
                                Check(not entry.isVisible, "Hiding one currency location should hide that entry")
                                hiddenCount = hiddenCount + 1
                            else
                                Check(entry.isVisible, "Hiding one currency location should not affect other resources")
                            end
                        end
                        CheckEqual(hiddenCount, 1, "Expected exactly one matching currency location")

                        this.accountWide.currencyPreferences = {}
                        this.accountWide.capacityPreferences = {}
                        local function SetTestOrder(entry, order)
                            if entry.kind == "currency" then
                                this.accountWide.currencyPreferences[entry.currencyType] = {
                                    locations = { [entry.location] = { order = order } },
                                }
                            else
                                this.accountWide.capacityPreferences[entry.resourceKey] = { order = order }
                            end
                        end
                        SetTestOrder(entries[1], 2)
                        SetTestOrder(entries[2], 1)
                        local orderedEntries = this.GetCurrencyPanelResourceEntries()
                        CheckEqual(orderedEntries[1].key, entries[2].key, "Explicit resource order should be applied")
                        CheckEqual(orderedEntries[2].key, entries[1].key, "Explicit resource order should be deterministic")
                    end)
                    this.accountWide.currencyPreferences = savedCurrencyPreferences
                    this.accountWide.capacityPreferences = savedCapacityPreferences
                    if not ok then error(err) end
                end,
            },
            {
                name = "Live currency helper API",
                run = function()
                    local currencyTypes = this.GetCurrencyList()
                    local seenCurrencyTypes = {}
                    Check(#currencyTypes > 0, "Expected at least one displayable currency")

                    for _, currencyType in ipairs(currencyTypes) do
                        Check(IsCurrencyValid(currencyType), "Currency list contains an invalid currency type")
                        Check(not seenCurrencyTypes[currencyType], "Currency list contains a duplicate type")
                        seenCurrencyTypes[currencyType] = true

                        local info = this.GetInfo(currencyType)
                        Check(info ~= nil, "Expected current information for every listed currency")
                        Check(type(info.name) == "string" and info.name ~= "", "Currency name should be available")
                        Check(type(info.amount) == "number", "Currency amount should be numeric")
                        Check(type(info.locationName) == "string", "Currency location name should be available")

                        local characterAmount, totalAmount = this.GetTotalInfo(currencyType)
                        Check(type(totalAmount) == "number", "Currency total should be numeric")
                        if info.isAccountWide then
                            Check(characterAmount == nil, "Account-wide currency should not have a character total")
                            CheckEqual(totalAmount, info.amount, "Account-wide total should match current amount")
                        else
                            Check(type(characterAmount) == "number", "Character currency amount should be numeric")
                            Check(totalAmount >= characterAmount, "Currency total should include character amount")
                        end

                        local capInfo = this.GetCapInfo(currencyType)
                        if info.cap ~= nil then
                            Check(capInfo ~= nil, "Capped currency should return cap information")
                            CheckEqual(capInfo.amount, info.amount, "Cap amount should match current amount")
                            CheckEqual(capInfo.cap, info.cap, "Cap information should match currency information")
                            Check(type(this.IsCurrencyNearCap(currencyType)) == "boolean", "Near-cap query should return a boolean")
                        else
                            Check(capInfo == nil, "Uncapped currency should not return cap information")
                        end
                    end

                    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
                        if IsCurrencyValid(currencyType) and ShouldShowCurrencyInCurrencyPanel(currencyType) then
                            Check(seenCurrencyTypes[currencyType], "A displayable currency is missing from the helper list")
                        end
                    end
                end,
            },
            {
                name = "Profile import copies tracked items and rule overrides",
                run = function()
                    local savedAccountWide = this.accountWide
                    local savedCharacter = this.character
                    local savedSavedVariables = _G[this.SettingsName]
                    local ok, err = pcall(function()
                        local sourceProfile = {
                            trackedItems = {
                                [101] = {
                                    link = "item-one",
                                    icon = "icon-one",
                                    mode = 3,
                                    display = { show = false, notify = true, bank = true },
                                },
                                [102] = {
                                    link = "item-two",
                                    icon = "icon-two",
                                    mode = 2,
                                },
                            },
                            trackedRules = {
                                baseline = {
                                    displayName = "Renamed baseline",
                                    patterns = { "Custom *" },
                                    display = { show = false, notify = true, isHidden = true },
                                },
                                custom = {
                                    displayName = "Custom group",
                                    patterns = { "Other *" },
                                },
                            },
                        }

                        this.accountWide = {
                            trackedItems = { [999] = { link = "old-item" } },
                            trackedRules = { old = { patterns = { "Old *" } } },
                        }
                        this.character = { useCharacterItemList = false }
                        _G[this.SettingsName] = {
                            Default = {
                                account = {
                                    ["$AccountWide"] = sourceProfile,
                                    sourceCharacter = sourceProfile,
                                },
                            },
                        }

                        Check(this.CopyProfile("sourceCharacter"), "A valid saved profile should import")
                        local copiedItems = this.accountWide.trackedItems
                        CheckEqual(CountEntries(copiedItems), 2, "Import should replace the destination item list")
                        CheckEqual(copiedItems[101].link, "item-one", "Item link should be copied")
                        CheckEqual(copiedItems[101].display.show, false, "Explicit hidden state should be copied")
                        CheckEqual(copiedItems[101].display.notify, true, "Notification preference should be copied")
                        CheckEqual(copiedItems[101].display.bank, true, "Bank preference should be copied")
                        CheckEqual(copiedItems[102].display.show, true, "Legacy mode should retain its visible default")
                        CheckEqual(copiedItems[102].display.notify, true, "Legacy notify mode should be normalized")

                        local copiedRules = this.accountWide.trackedRules
                        CheckEqual(CountEntries(copiedRules), 2, "Import should replace the destination rule list")
                        CheckEqual(copiedRules.baseline.displayName, "Renamed baseline", "Rule name override should be copied")
                        CheckEqual(copiedRules.baseline.addedPatterns[1], "Custom *", "Rule pattern deltas should be copied")
                        CheckEqual(copiedRules.baseline.display.isHidden, true, "Rule display overrides should be copied")
                        CheckEqual(copiedRules.custom.displayName, "Custom group", "Custom rule should be copied")
                        Check(not this.CopyProfile("missingCharacter"), "An unknown profile should not import")
                    end)
                    this.accountWide = savedAccountWide
                    this.character = savedCharacter
                    _G[this.SettingsName] = savedSavedVariables
                    if not ok then error(err) end
                end,
            },
            {
                name = "Tracked item count respects backpack and craft-bag scope",
                run = function()
                    local savedGetBagContents = this.Scanning.GetBagContents
                    local savedIsESOPlusSubscriber = _G.IsESOPlusSubscriber
                    local ok, err = pcall(function()
                        local scanCalls = 0
                        local scannedBagIds
                        local entries = {
                            { bagId = BAG_BACKPACK, itemId = 77, count = 2 },
                            { bagId = BAG_BACKPACK, itemId = 88, count = 50 },
                            { bagId = BAG_VIRTUAL, itemId = 77, count = 5 },
                        }
                        this.Scanning.GetBagContents = function(bagIds, selectFunc)
                            scanCalls = scanCalls + 1
                            scannedBagIds = bagIds
                            local contents = {}
                            for _, entry in ipairs(entries) do
                                local bagMatches = false
                                for _, bagId in ipairs(bagIds) do
                                    if entry.bagId == bagId then
                                        bagMatches = true
                                        break
                                    end
                                end
                                if bagMatches and (not selectFunc or selectFunc(entry)) then
                                    table.insert(contents, entry)
                                end
                            end
                            return contents
                        end

                        _G.IsESOPlusSubscriber = function() return true end
                        CheckEqual(this.GetTrackedItemCount(77), 7, "Count should include backpack and craft-bag stacks")
                        CheckEqual(#scannedBagIds, 2, "ESO+ scans should include two item bags")
                        CheckEqual(scannedBagIds[1], BAG_BACKPACK, "Backpack should be scanned first")
                        CheckEqual(scannedBagIds[2], BAG_VIRTUAL, "Craft bag should be included for ESO+")

                        _G.IsESOPlusSubscriber = function() return false end
                        CheckEqual(this.GetTrackedItemCount(77), 2, "Non-ESO+ count should include only backpack stacks")
                        CheckEqual(#scannedBagIds, 1, "Non-ESO+ scans should use only one item bag")
                        CheckEqual(scannedBagIds[1], BAG_BACKPACK, "Non-ESO+ scans should use the backpack")

                        local callsBeforeMissingId = scanCalls
                        CheckEqual(this.GetTrackedItemCount(nil), 0, "Missing item ID should return zero")
                        CheckEqual(scanCalls, callsBeforeMissingId, "Missing item ID should not scan inventory")
                    end)
                    this.Scanning.GetBagContents = savedGetBagContents
                    _G.IsESOPlusSubscriber = savedIsESOPlusSubscriber
                    if not ok then error(err) end
                end,
            },
            {
                name = "Case-insensitive substring matching",
                run = function()
                    Check(this.ItemMatchesRule("item-exact", "mundane rune"), "Expected case-insensitive exact match")
                    Check(this.ItemMatchesRule("item-exact", "mundane"), "Expected plain text patterns to match substrings")
                end,
            },
            {
                name = "Wildcard matching",
                run = function()
                    Check(this.ItemMatchesRule("item-wildcard", "Treasure Map:*"), "Expected wildcard match")
                    Check(not this.ItemMatchesRule("item-wildcard", "Treasure * Grahtwood"), "Unexpected wildcard match")
                end,
            },
            {
                name = "Literal punctuation and missing names",
                run = function()
                    Check(this.ItemMatchesRule("item-special", "Wayfinder's Kit +1"), "Expected punctuation to be matched literally")
                    Check(not this.ItemMatchesRule("item-special", "Wayfinder's Kit 1"), "Expected plus sign to be significant")
                    Check(not this.ItemMatchesRule("missing-item", "Anything"), "Missing item name should not match")
                end,
            },
            {
                name = "Any-pattern matching",
                run = function()
                    Check(this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Treasure Map:*" }), "Expected one matching pattern")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", { "No Match", "Still No Match" }), "Unexpected any-pattern match")
                    Check(not this.ItemMatchesAnyRule("item-wildcard", nil), "Nil pattern list should not match")
                end,
            },
            {
                name = "Baseline and saved-rule override resolution",
                run = function()
                    this.preLoadedRulesets = baselineRules
                    this.accountWide = {
                        trackedRules = {
                            default = { displayName = "Renamed", display = { show = false } },
                            hidden = { display = { isHidden = true } },
                            custom = { patterns = { "Custom *" } },
                        },
                    }

                    local activeRules = this.GetActiveTrackedRules()
                    CheckEqual(activeRules.default.displayName, "Renamed", "Saved display-name override should apply")
                    CheckEqual(activeRules.default.patterns[1], "Default *", "Unmodified patterns should come from the baseline")
                    CheckEqual(activeRules.default.display.show, false, "Saved display flag should apply")
                    CheckEqual(activeRules.default.display.notify, false, "Unmodified display flag should remain at baseline")
                    Check(activeRules.hidden == nil, "Hidden rule should be filtered by default")
                    CheckEqual(activeRules.custom.displayName, "custom", "Custom rule should use its key as the default name")
                    CheckEqual(activeRules.custom.display.show, true, "Custom rule should receive default display settings")
                    Check(this.GetActiveTrackedRules(true).hidden ~= nil, "includeHidden should retain hidden rules")
                    CheckEqual(baselineRules.default.displayName, "Default Group", "Reading overrides must not mutate the baseline")
                end,
            },
            {
                name = "Display-flag writes preserve other overrides",
                run = function()
                    this.accountWide = {
                        trackedRules = {
                            default = {
                                displayName = "Existing Name",
                                patterns = { "Existing *" },
                                display = { notify = false },
                            },
                        },
                    }

                    this.SetRuleFlag("default", "show", false)
                    local savedRule = this.accountWide.trackedRules.default
                    CheckEqual(savedRule.displayName, "Existing Name", "Flag update should preserve display name")
                    CheckEqual(savedRule.patterns[1], "Existing *", "Flag update should preserve patterns")
                    CheckEqual(savedRule.display.notify, false, "Flag update should preserve other flags")
                    CheckEqual(savedRule.display.show, false, "Flag update should write selected flag")
                    CheckEqual(CountEntries(savedRule), 3, "Flag update should not add unrelated root properties")
                    CheckEqual(CountEntries(savedRule.display), 2, "Flag update should not add unrelated display flags")
                end,
            },
            {
                name = "100-item backpack and craft-bag scan",
                run = function()
                    this.accountWide.trackedRules = { synthetic = { addedPatterns = { "Synthetic Item *" } } }
                    this.preLoadedRulesets = {}
                    local rules = this.GetActiveTrackedRules()
                    local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                    CheckEqual(CountEntries(snapshot.items), 100, "Every synthetic item should be included")
                    CheckEqual(#snapshot.ruleIndex.synthetic, 100, "Every synthetic item should be indexed under its rule")

                    local bagCount = 0
                    local bankCount = 0
                    for _, item in pairs(snapshot.items) do
                        bagCount = bagCount + item.bagCount
                        bankCount = bankCount + item.bankCount
                    end
                    CheckEqual(bagCount, 50, "Only backpack items should contribute to the backpack count")
                    CheckEqual(bankCount, 100, "The overall total should include backpack and craft-bag items")
                end,
            },
            {
                name = "Repeated 100-item inventory scan performance",
                run = function()
                    this.accountWide.trackedRules = {}
                    this.preLoadedRulesets = {}
                    for index = 1, 20 do
                        this.accountWide.trackedRules["synthetic-" .. index] = { addedPatterns = { "Synthetic Item *" } }
                    end
                    local rules = this.GetActiveTrackedRules()

                    local startedAt = GetGameTimeMilliseconds()
                    for _ = 1, 20 do
                        local snapshot = this.GetMasterItemList({}, rules, { BAG_BACKPACK, BAG_VIRTUAL })
                        CheckEqual(CountEntries(snapshot.items), 100, "Repeated scan should retain all synthetic items")
                    end
                    performanceMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        performanceMs <= performanceLimitMs,
                        string.format("20 scans of 100 items across 20 rules took %d ms (limit %d ms)", performanceMs, performanceLimitMs)
                    )
                end,
            },
            {
                name = "100 repeated slot-rule matches",
                run = function()
                    local startedAt = GetGameTimeMilliseconds()
                    for index = 1, 100 do
                        Check(
                            this.ItemMatchesAnyRule("synthetic-item-" .. index, { "Synthetic Item *" }),
                            "Synthetic slot update should match its tracked rule"
                        )
                    end
                    slotMatchMs = GetGameTimeMilliseconds() - startedAt
                    Check(
                        slotMatchMs <= slotMatchLimitMs,
                        string.format("100 slot-rule matches took %d ms (limit %d ms)", slotMatchMs, slotMatchLimitMs)
                    )
                end,
            },
            {
                name = "100 synthetic tracked-item slot updates",
                run = function()
                    local warningCount = 0
                    this.accountWide.trackedItems = {}
                    this.preLoadedRulesets = {
                        synthetic = {
                            displayName = "Synthetic",
                            patterns = { "Synthetic Item *" },
                            display = { show = true, notify = true, bank = false, group = true, isExpanded = true, isHidden = false },
                        },
                    }
                    this.InvalidateRuleCache()
                    this.Utils.UserWarning = function()
                        warningCount = warningCount + 1
                    end

                    local startedAt = GetGameTimeMilliseconds()
                    for index = 1, 100 do
                        local bagId = index <= 50 and BAG_BACKPACK or BAG_VIRTUAL
                        local slotIndex = index <= 50 and index or index - 50
                        this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, 1)
                    end
                    slotUpdateMs = GetGameTimeMilliseconds() - startedAt
                    -- Later tests (e.g. currency message scenarios) need the real messaging.
                    this.Utils.UserWarning = syntheticOriginal.userWarning

                    CheckEqual(warningCount, 100, "Every matching synthetic slot update should trigger a notification")
                    Check(
                        slotUpdateMs <= slotUpdateLimitMs,
                        string.format(
                            "100 tracked-item slot updates took %d ms (limit %d ms)",
                            slotUpdateMs,
                            slotUpdateLimitMs
                        )
                    )
                end,
            },
            {
                name = "Event listener transitions and refresh debounce",
                run = function()
                    local liveAccountWide = syntheticOriginal.accountWide
                    local savedAutoMergeChests = liveAccountWide.autoMergeChests
                    local savedShowTrackedItemsPanel = liveAccountWide.showTrackedItemsPanel
                    -- Isolate settings changes from the live SavedVariables table.
                    local eventTestAccountWide = {}
                    for key, value in pairs(liveAccountWide) do
                        eventTestAccountWide[key] = value
                    end

                    local listenerState = {
                        visibleProgressBars = false,
                        visibleCapacityResources = false,
                        currencyResourcesToTrack = false,
                        visibleCurrencyProgressBars = false,
                        currencyNotifications = false,
                        capacityNotifications = false,
                        visibleCappedCurrencyResources = false,
                        visibleCappedProgressBars = false,
                        bagProgressBar = false,
                        bankProgressBar = false,
                        bagCapacity = false,
                        bankCapacity = false,
                    }
                    local queryNames = {
                        "HasVisibleProgressBars",
                        "HasVisibleCapacityResources",
                        "HasCurrencyResourcesToTrack",
                        "HasVisibleCurrencyProgressBars",
                        "HasCurrencyNotifications",
                        "HasCapacityNotifications",
                        "HasVisibleCappedCurrencyResources",
                        "HasVisibleCappedProgressBars",
                        "IsProgressBarVisible",
                        "IsCapacityResourceVisible",
                    }
                    local savedQueries = {}
                    for _, name in ipairs(queryNames) do
                        savedQueries[name] = this[name]
                    end

                    local manager = EVENT_MANAGER
                    local savedRegister = manager.RegisterForEvent
                    local savedUnregister = manager.UnregisterForEvent
                    local savedAddFilter = manager.AddFilterForEvent
                    local managerProxy = setmetatable({}, { __index = manager })
                    local registrationCalls = {}
                    local unregistrationCalls = {}
                    local filterCalls = {}
                    local slotUpdateHandler

                    managerProxy.RegisterForEvent = function(_, eventId, eventCode, handler)
                        table.insert(registrationCalls, { eventId = eventId, eventCode = eventCode })
                        if eventId == this.Name .. "_Event_SlotUpdate_Backpack" then
                            slotUpdateHandler = handler
                        end
                        local registered = savedRegister(manager, eventId, eventCode, handler)
                        Check(registered == true, "Event registration failed for " .. eventId)
                        return registered
                    end
                    managerProxy.UnregisterForEvent = function(_, eventId, eventCode)
                        table.insert(unregistrationCalls, { eventId = eventId, eventCode = eventCode })
                        return savedUnregister(manager, eventId, eventCode)
                    end
                    managerProxy.AddFilterForEvent = function(_, eventId, eventCode, filterType, filterValue)
                        table.insert(filterCalls, {
                            eventId = eventId,
                            eventCode = eventCode,
                            filterType = filterType,
                            filterValue = filterValue,
                        })
                        local applied = savedAddFilter(manager, eventId, eventCode, filterType, filterValue)
                        Check(applied == true, "Event filter application failed for " .. eventId)
                        return applied
                    end
                    EVENT_MANAGER = managerProxy

                    this.HasVisibleProgressBars = function() return listenerState.visibleProgressBars end
                    this.HasVisibleCapacityResources = function() return listenerState.visibleCapacityResources end
                    this.HasCurrencyResourcesToTrack = function() return listenerState.currencyResourcesToTrack end
                    this.HasVisibleCurrencyProgressBars = function() return listenerState.visibleCurrencyProgressBars end
                    this.HasCurrencyNotifications = function() return listenerState.currencyNotifications end
                    this.HasCapacityNotifications = function() return listenerState.capacityNotifications end
                    this.HasVisibleCappedCurrencyResources = function() return listenerState.visibleCappedCurrencyResources end
                    this.HasVisibleCappedProgressBars = function() return listenerState.visibleCappedProgressBars end
                    this.IsProgressBarVisible = function(resourceKey)
                        if resourceKey == "capacity:bag" then return listenerState.bagProgressBar end
                        if resourceKey == "capacity:bank" then return listenerState.bankProgressBar end
                        return false
                    end
                    this.IsCapacityResourceVisible = function(resourceKey)
                        if resourceKey == "bag" then return listenerState.bagCapacity end
                        if resourceKey == "bank" then return listenerState.bankCapacity end
                        return false
                    end

                    local oldCallLater = zo_callLater
                    local oldRemoveCallLater = zo_removeCallLater
                    local scheduledCallbacks = {}
                    local removedCallbacks = {}
                    local nextCallbackId = 0
                    local debounceRefreshes = { tracker = 0, currency = 0, progress = 0, slotUpdate = 0 }
                    local savedHandleTrackedItemInventoryUpdate = this.HandleTrackedItemInventoryUpdate
                    local savedRefreshItemTrackerPanel = this.RefreshItemTrackerPanel
                    local savedRefreshCurrencyPanel = this.RefreshCurrencyPanel
                    local savedRefreshResourceProgressBars = this.RefreshResourceProgressBars
                    local testOk, testError = pcall(function()
                        this.accountWide = eventTestAccountWide
                        eventTestAccountWide.autoMergeChests = false
                        eventTestAccountWide.showTrackedItemsPanel = false
                        this.UpdateEventRegistry()

                        local function ClearCalls()
                            registrationCalls = {}
                            unregistrationCalls = {}
                            filterCalls = {}
                        end
                        local function HasEventCall(calls, eventId)
                            for _, call in ipairs(calls) do
                                if call.eventId == eventId then return true end
                            end
                            return false
                        end
                        local function CheckSlotListenersRegistered()
                            local filtersBySuffix = {
                                Backpack = BAG_BACKPACK,
                                Virtual = BAG_VIRTUAL,
                                Bank = BAG_BANK,
                                SubscriberBank = BAG_SUBSCRIBER_BANK,
                            }
                            for suffix, bagId in pairs(filtersBySuffix) do
                                local eventId = this.Name .. "_Event_SlotUpdate_" .. suffix
                                Check(HasEventCall(registrationCalls, eventId), "Expected registration for " .. suffix .. " slot updates")
                                for _, call in ipairs(registrationCalls) do
                                    if call.eventId == eventId then
                                        CheckEqual(call.eventCode, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, "Slot registration should use the inventory event")
                                    end
                                end
                                local filterFound = false
                                for _, filter in ipairs(filterCalls) do
                                    if filter.eventId == eventId then
                                        CheckEqual(filter.eventCode, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, "Bag filter should use the registered inventory event")
                                        CheckEqual(filter.filterType, REGISTER_FILTER_BAG_ID, "Slot-update filter should match bag IDs")
                                        CheckEqual(filter.filterValue, bagId, "Slot-update filter should use the expected bag")
                                        filterFound = true
                                        break
                                    end
                                end
                                Check(filterFound, "Expected a bag filter for " .. suffix .. " slot updates")
                            end
                            CheckEqual(#filterCalls, 4, "Each slot-update listener should receive a bag filter")
                        end

                        ClearCalls()
                        eventTestAccountWide.autoMergeChests = true
                        this.UpdateEventRegistry()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_OpenBank"),
                            "Enabling chest merging should register the bank-open listener"
                        )

                        ClearCalls()
                        eventTestAccountWide.autoMergeChests = false
                        this.UpdateEventRegistry()
                        Check(
                            HasEventCall(unregistrationCalls, this.Name .. "_Event_OpenBank"),
                            "Disabling chest merging should unregister the bank-open listener"
                        )

                        ClearCalls()
                        eventTestAccountWide.showTrackedItemsPanel = true
                        this.UpdateEventRegistry()
                        CheckSlotListenersRegistered()

                        ClearCalls()
                        this.UpdateEventRegistry()
                        CheckEqual(#registrationCalls, 0, "An unchanged registry should not register duplicate listeners")
                        CheckEqual(#unregistrationCalls, 0, "An unchanged registry should not unregister listeners")
                        CheckEqual(#filterCalls, 0, "An unchanged registry should not apply duplicate filters")

                        listenerState.capacityNotifications = true
                        this.UpdateEventRegistry()
                        eventTestAccountWide.showTrackedItemsPanel = false
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 0, "A shared slot listener should remain while capacity notifications need it")
                        listenerState.capacityNotifications = false

                        ClearCalls()
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 4, "Hiding the tracker should unregister its four slot-update listeners")

                        ClearCalls()
                        listenerState.visibleCapacityResources = true
                        listenerState.bagCapacity = true
                        this.UpdateEventRegistry()
                        CheckSlotListenersRegistered()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_BagCapacity"),
                            "Visible backpack capacity should register its capacity listener"
                        )
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_BankCapacity") == false,
                            "Hidden bank capacity should not register its capacity listener"
                        )

                        ClearCalls()
                        listenerState.visibleCapacityResources = false
                        listenerState.bagCapacity = false
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 5, "Hiding capacity indicators should unregister slot and bag-capacity listeners")

                        ClearCalls()
                        listenerState.visibleCapacityResources = true
                        listenerState.bankCapacity = true
                        this.UpdateEventRegistry()
                        CheckSlotListenersRegistered()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_BankCapacity"),
                            "Visible bank capacity should register its capacity listener"
                        )
                        Check(
                            not HasEventCall(registrationCalls, this.Name .. "_Event_BagCapacity"),
                            "Hidden backpack capacity should not register its capacity listener"
                        )

                        ClearCalls()
                        listenerState.visibleCapacityResources = false
                        listenerState.bankCapacity = false
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 5, "Hiding bank capacity should unregister slot and bank-capacity listeners")

                        ClearCalls()
                        listenerState.currencyResourcesToTrack = true
                        listenerState.visibleCappedCurrencyResources = true
                        this.UpdateEventRegistry()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_CurrencyUpdate"),
                            "Tracked currencies should register currency updates"
                        )
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_CurrencyCapsChanged"),
                            "Visible capped currencies should register cap-change updates"
                        )

                        ClearCalls()
                        listenerState.currencyResourcesToTrack = false
                        listenerState.visibleCappedCurrencyResources = false
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 2, "Hiding currency indicators should unregister both currency listeners")

                        ClearCalls()
                        listenerState.currencyNotifications = true
                        this.UpdateEventRegistry()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_CurrencyUpdate"),
                            "Enabled currency notifications should register currency updates"
                        )
                        ClearCalls()
                        listenerState.currencyNotifications = false
                        this.UpdateEventRegistry()
                        Check(
                            HasEventCall(unregistrationCalls, this.Name .. "_Event_CurrencyUpdate"),
                            "Disabling currency notifications should unregister currency updates when nothing else needs them"
                        )

                        ClearCalls()
                        listenerState.capacityNotifications = true
                        this.UpdateEventRegistry()
                        CheckSlotListenersRegistered()
                        Check(
                            not HasEventCall(registrationCalls, this.Name .. "_Event_BagCapacity"),
                            "Capacity notifications alone should not register capacity-change listeners"
                        )
                        ClearCalls()
                        listenerState.capacityNotifications = false
                        this.UpdateEventRegistry()
                        CheckEqual(#unregistrationCalls, 4, "Disabling capacity notifications should unregister the slot-update listeners")

                        ClearCalls()
                        listenerState.visibleProgressBars = true
                        listenerState.bagProgressBar = true
                        listenerState.visibleCurrencyProgressBars = true
                        listenerState.visibleCappedProgressBars = true
                        this.UpdateEventRegistry()
                        CheckSlotListenersRegistered()
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_BagCapacity"),
                            "A visible backpack progress bar should register capacity updates"
                        )
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_CurrencyUpdate"),
                            "A visible currency progress bar should register currency updates"
                        )
                        Check(
                            HasEventCall(registrationCalls, this.Name .. "_Event_CurrencyCapsChanged"),
                            "Visible capped progress bars should register cap-change updates"
                        )
                        Check(slotUpdateHandler ~= nil, "Expected the backpack slot-update handler to be registered")
                        listenerState.visibleCapacityResources = true

                        this.HandleTrackedItemInventoryUpdate = function()
                            debounceRefreshes.slotUpdate = debounceRefreshes.slotUpdate + 1
                        end
                        this.RefreshItemTrackerPanel = function()
                            debounceRefreshes.tracker = debounceRefreshes.tracker + 1
                        end
                        this.RefreshCurrencyPanel = function()
                            debounceRefreshes.currency = debounceRefreshes.currency + 1
                        end
                        this.RefreshResourceProgressBars = function()
                            debounceRefreshes.progress = debounceRefreshes.progress + 1
                        end
                        eventTestAccountWide.showTrackedItemsPanel = true
                        zo_callLater = function(callback, delay)
                            nextCallbackId = nextCallbackId + 1
                            local callbackId = nextCallbackId
                            scheduledCallbacks[callbackId] = {
                                callback = function()
                                    scheduledCallbacks[callbackId] = nil
                                    callback()
                                end,
                                delay = delay,
                            }
                            return callbackId
                        end
                        zo_removeCallLater = function(callbackId)
                            removedCallbacks[callbackId] = true
                            scheduledCallbacks[callbackId] = nil
                        end

                        slotUpdateHandler(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BAG_BACKPACK, 1, false, nil, nil, 1)
                        slotUpdateHandler(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BAG_BACKPACK, 2, false, nil, nil, 1)
                        CheckEqual(nextCallbackId, 6, "Two slot updates should debounce three refresh actions")
                        CheckEqual(CountEntries(scheduledCallbacks), 1, "Only the final debounced callback should remain scheduled")
                        CheckEqual(CountEntries(removedCallbacks), 5, "Each newly enqueued action should cancel the prior callback")
                        local finalCallback = scheduledCallbacks[nextCallbackId]
                        CheckEqual(finalCallback.delay, 500, "Refresh debounce should retain the 500 ms delay")
                        finalCallback.callback()
                        CheckEqual(debounceRefreshes.slotUpdate, 2, "Each inventory event should update tracked-item notification state")
                        CheckEqual(debounceRefreshes.tracker, 1, "A burst should refresh the tracker once")
                        CheckEqual(debounceRefreshes.currency, 1, "A burst should refresh the currency panel once")
                        CheckEqual(debounceRefreshes.progress, 1, "A burst should refresh progress bars once")
                    end)

                    for _, pending in pairs(scheduledCallbacks) do
                        local cleanupOk, cleanupError = pcall(pending.callback)
                        if not cleanupOk and testOk then
                            testOk = false
                            testError = "Failed to flush a pending synthetic refresh: " .. tostring(cleanupError)
                        end
                        break
                    end

                    EVENT_MANAGER = manager
                    for name, query in pairs(savedQueries) do
                        this[name] = query
                    end
                    this.HandleTrackedItemInventoryUpdate = savedHandleTrackedItemInventoryUpdate
                    this.RefreshItemTrackerPanel = savedRefreshItemTrackerPanel
                    this.RefreshCurrencyPanel = savedRefreshCurrencyPanel
                    this.RefreshResourceProgressBars = savedRefreshResourceProgressBars
                    zo_callLater = oldCallLater
                    zo_removeCallLater = oldRemoveCallLater
                    this.accountWide = liveAccountWide

                    local restoreOk, restoreError = pcall(this.UpdateEventRegistry)
                    if not restoreOk then
                        error("Failed to restore live event listeners: " .. tostring(restoreError))
                    end
                    CheckEqual(liveAccountWide.autoMergeChests, savedAutoMergeChests, "Chest-merge setting should be unchanged after the test")
                    CheckEqual(liveAccountWide.showTrackedItemsPanel, savedShowTrackedItemsPanel, "Tracker visibility setting should be unchanged after the test")
                    if not testOk then error(testError) end
                end,
            },
        }

        table.insert(tests, {
            name = "Currency messages: capped balance colours follow the progress bar thresholds",
            run = function()
                local currencyType = CURT_TRANSMUTE_CRYSTALS
                if currencyType == nil or not IsCurrencyValid(currencyType) then return end
                local location = GetCurrencyPlayerStoredLocation(currencyType)
                if not IsCurrencyCapped(currencyType, location) then return end
                local cap = GetMaxPossibleCurrency(currencyType, location)
                local resourceKey = "currency:" .. tostring(currencyType)

                local savedColors = this.accountWide.progressBarAlertColors
                local savedPreferences = this.accountWide.progressBarPreferences
                local ok, err = pcall(function()
                    this.accountWide.progressBarAlertColors = {}
                    this.accountWide.progressBarPreferences = {}
                    this.SetProgressBarAlertColor("warning", { r = 1, g = 0.5, b = 0, a = 1 })
                    this.SetProgressBarAlertColor("danger", { r = 1, g = 0, b = 0, a = 1 })
                    local settings = this.GetProgressBarSettings(resourceKey)

                    local function Expected(color, amount)
                        local text = string.format("%d/%d (%d%%)", amount, cap, math.floor(amount / cap * 100))
                        return string.format("|c%s%s|r", ZO_ColorDef:New(color.r, color.g, color.b, 1):ToHex(), text)
                    end

                    local normalAmount = math.floor(cap * settings.warningThreshold * 0.5)
                    local warningAmount = math.ceil(cap * settings.warningThreshold)
                    local dangerAmount = math.ceil(cap * settings.dangerThreshold)
                    CheckEqual(
                        this.FormatCappedBalance(currencyType, normalAmount, cap, false),
                        Expected(this.GetProgressBarNormalColor(resourceKey), normalAmount),
                        "Below the warning threshold the balance should use the bar's normal colour"
                    )
                    CheckEqual(
                        this.FormatCappedBalance(currencyType, warningAmount, cap, false),
                        Expected({ r = 1, g = 0.5, b = 0 }, warningAmount),
                        "At the warning threshold the balance should use the warning colour"
                    )
                    CheckEqual(
                        this.FormatCappedBalance(currencyType, dangerAmount, cap, false),
                        Expected({ r = 1, g = 0, b = 0 }, dangerAmount),
                        "At the danger threshold the balance should use the danger colour"
                    )
                end)
                this.accountWide.progressBarAlertColors = savedColors
                this.accountWide.progressBarPreferences = savedPreferences
                if not ok then error(err, 0) end
            end,
        })

        local scenarios = GetCurrencyMessageScenarios()
        for _, scenario in ipairs(GetCurrencyTypeMessageScenarios()) do
            table.insert(scenarios, scenario)
        end
        for _, scenario in ipairs(scenarios) do
            table.insert(tests, {
                name = "Currency messages: " .. scenario.name,
                run = function()
                    RunCurrencyMessageScenario(scenario, options.verbose)
                end,
            })
        end

        for _, scenario in ipairs(GetCapacityMessageScenarios()) do
            table.insert(tests, {
                name = "Capacity messages: " .. scenario.name,
                run = function()
                    RunCapacityMessageScenario(scenario, options.verbose)
                end,
            })
        end

        table.insert(tests, {
            name = "Capacity messages: balance colours follow the progress bar thresholds",
            run = function()
                local savedColors = this.accountWide.progressBarAlertColors
                local savedPreferences = this.accountWide.progressBarPreferences
                local ok, err = pcall(function()
                    this.accountWide.progressBarAlertColors = {}
                    this.accountWide.progressBarPreferences = {}
                    this.SetProgressBarAlertColor("warning", { r = 1, g = 0.5, b = 0, a = 1 })
                    this.SetProgressBarAlertColor("danger", { r = 1, g = 0, b = 0, a = 1 })
                    for _, kind in ipairs({ "bag", "bank" }) do
                        local resourceKey = "capacity:" .. kind
                        local settings = this.GetProgressBarSettings(resourceKey)
                        local max = 200
                        local function Expected(color, used)
                            local text = string.format("%d/%d (%d%%)", used, max, math.floor(used / max * 100))
                            return string.format("|c%s%s|r", ZO_ColorDef:New(color.r, color.g, color.b, 1):ToHex(), text)
                        end
                        local normalUsed = math.floor(max * settings.warningThreshold * 0.5)
                        local warningUsed = math.ceil(max * settings.warningThreshold)
                        local dangerUsed = math.ceil(max * settings.dangerThreshold)
                        CheckEqual(
                            this.FormatCapacityBalance(kind, normalUsed, max),
                            Expected(this.GetProgressBarNormalColor(resourceKey), normalUsed),
                            kind .. " below the warning threshold should use the normal colour"
                        )
                        CheckEqual(
                            this.FormatCapacityBalance(kind, warningUsed, max),
                            Expected({ r = 1, g = 0.5, b = 0 }, warningUsed),
                            kind .. " at the warning threshold should use the warning colour"
                        )
                        CheckEqual(
                            this.FormatCapacityBalance(kind, dangerUsed, max),
                            Expected({ r = 1, g = 0, b = 0 }, dangerUsed),
                            kind .. " at the danger threshold should use the danger colour"
                        )
                    end
                end)
                this.accountWide.progressBarAlertColors = savedColors
                this.accountWide.progressBarPreferences = savedPreferences
                if not ok then error(err, 0) end
            end,
        })

        table.insert(tests, {
            name = "Capacity notification preferences",
            run = function()
                local savedPreferences = this.accountWide.capacityPreferences
                local ok, err = pcall(function()
                    this.accountWide.capacityPreferences = {}
                    Check(not this.HasCapacityNotifications(), "Capacity notifications should default to off")
                    this.SetCapacityNotificationEnabled("bank", true)
                    Check(this.IsCapacityNotificationEnabled("bank"), "Bank notifications should turn on")
                    Check(not this.IsCapacityNotificationEnabled("bag"), "Bag notifications should stay off")
                    Check(this.HasCapacityNotifications(), "Any enabled capacity notification should be reported")
                    this.SetCapacityNotificationEnabled("bank", false)
                    Check(not this.HasCapacityNotifications(), "Turning the last notification off should be reported")
                    Check(this.accountWide.capacityPreferences.bank == nil, "Empty capacity preferences should be removed")
                end)
                this.accountWide.capacityPreferences = savedPreferences
                if not ok then error(err, 0) end
            end,
        })

        for _, test in ipairs(this.GetRuleTests()) do
            table.insert(tests, test)
        end

        for _, test in ipairs(tests) do
            local ok, err = pcall(test.run)
            if ok then
                passed = passed + 1
                table.insert(results, "PASS " .. test.name)
            else
                table.insert(results, "FAIL " .. test.name .. ": " .. tostring(err))
            end
        end
    end)

    this.accountWide = syntheticOriginal.accountWide
    this.character = syntheticOriginal.character
    this.preLoadedRulesets = syntheticOriginal.preLoadedRulesets
    this.Scanning.GetBagContents = syntheticOriginal.getBagContents
    this.GetActiveTrackedItems = syntheticOriginal.getActiveTrackedItems
    this.GetActiveTrackedRules = syntheticOriginal.getActiveTrackedRules
    _G.GetItemLinkName = syntheticOriginal.getItemLinkName
    _G.GetItemId = syntheticOriginal.getItemId
    _G.GetItemLink = syntheticOriginal.getItemLink
    _G.IsESOPlusSubscriber = syntheticOriginal.isESOPlusSubscriber
    this.Utils.UserWarning = syntheticOriginal.userWarning
    this.InvalidateRuleCache()

    if not environmentOk then
        table.insert(results, "FAIL test setup: " .. tostring(environmentError))
    end

    local total = 0
    for _, result in ipairs(results) do
        if result:sub(1, 5) ~= "WARN " then
            total = total + 1
        end
    end
    local summary
    if performanceMs and slotMatchMs and slotUpdateMs then
        summary = string.format(
            "[InventoryCompanion tests] %d/%d passed; 20 x 100-item scans / 20 rules: %d/%d ms; 100 slot-rule matches: %d/%d ms; 100 tracked-item slot updates: %d/%d ms%s",
            passed,
            total,
            performanceMs,
            performanceLimitMs,
            slotMatchMs,
            slotMatchLimitMs,
            slotUpdateMs,
            slotUpdateLimitMs,
            string.format(
                "; 100 live backpack/bank%s scans (bank %s): %d/%d ms, %d occupied entries",
                IsESOPlusSubscriber() and "/craft-bag" or "",
                bankOpenDuringLiveScan and "open" or "closed",
                liveScanMs or 0,
                liveScanLimitMs,
                liveItemCount or 0
            )
        )
    else
        summary = string.format("[InventoryCompanion tests] %d/%d passed.", passed, total)
    end

    local reportLines = { summary }
    for _, line in ipairs(discovery) do
        table.insert(reportLines, "[InventoryCompanion tests] " .. line)
    end
    for _, result in ipairs(results) do
        table.insert(reportLines, "[InventoryCompanion tests] " .. result)
    end

    local hasFailures = passed < total
    if options.copy or hasFailures then
        error(table.concat(reportLines, "\n"), 0)
    elseif options.verbose then
        for _, reportLine in ipairs(reportLines) do
            d(reportLine)
        end
    else
        d(summary)
        for _, line in ipairs(discovery) do
            d("[InventoryCompanion tests] " .. line)
        end
        for _, result in ipairs(results) do
            if result:sub(1, 5) == "FAIL " or result:sub(1, 5) == "WARN " then
                d("[InventoryCompanion tests] " .. result)
            end
        end
    end
end

this.RunTests = RunTests
SLASH_COMMANDS["/ictest"] = RunTests
SLASH_COMMANDS["/icclean"] = RunCleanup
SLASH_COMMANDS["/icbankitems"] = RunBankItems
