local ua = UAssistant
local banking = ua.Banking

banking.AutoBanking = banking.AutoBanking or {}
local autoBanking = banking.AutoBanking

local PERSONAL_MOVE_DELAY_MS = 15
local GUILD_MOVE_DELAY_MS = 100
local MOVE_TIMEOUT_MS = 5000
local OPEN_DELAY_MS = 350
local PERSONAL_RESCAN_DELAY_MS = 500
local PERSONAL_RESCAN_LIMIT = 3
local EVENT_NAMESPACE = ua.addonName .. "AutoBanking"

local MODE_NONE = "none"
local MODE_DEPOSIT = "deposit"
local MODE_WITHDRAW = "withdraw"
local REPORT_MODE_NONE = "none"
local REPORT_MODE_ITEMS = "items"
local REPORT_MODE_SUMMARY = "summary"
local CHAT_PREFIX = "|cFFFFFF[|r|c3A92FFU|r|cFFFF00A|r" .. "|cFFFFFFBanking]|r "

autoBanking.MODE_NONE = MODE_NONE
autoBanking.MODE_DEPOSIT = MODE_DEPOSIT
autoBanking.MODE_WITHDRAW = MODE_WITHDRAW
autoBanking.rules = autoBanking.rules or {}
autoBanking.ruleOrder = autoBanking.ruleOrder or {}

local CompletePendingMove
local sessionToken = 0

local function StartSession()
    sessionToken = sessionToken + 1
    autoBanking.queue = {}
    autoBanking.pendingMove = nil
    autoBanking.processActive = false
    autoBanking.moveToken = (autoBanking.moveToken or 0) + 1
end

local function ScheduleForSession(callback, delay)
    local token = sessionToken

    zo_callLater(function()
        if token == sessionToken then
            callback()
        end
    end, delay)
end

local function L(key)
    return ua.GetString("BANKING_" .. key)
end

local function GetSettings()
    local savedVariables = ua.savedVariables
    savedVariables.banking = savedVariables.banking or {}
    local settings = savedVariables.banking

    if type(settings.stackBankOnOpen) ~= "boolean" then
        settings.stackBankOnOpen = false
    end

    if type(settings.stackBackpackOnOpen) ~= "boolean" then
        settings.stackBackpackOnOpen = false
    end

    if
        settings.chatReportMode ~= REPORT_MODE_NONE
        and settings.chatReportMode ~= REPORT_MODE_ITEMS
        and settings.chatReportMode ~= REPORT_MODE_SUMMARY
    then
        settings.chatReportMode = REPORT_MODE_NONE
    end

    return settings
end

function autoBanking.IsValidMode(mode)
    return mode == MODE_NONE or mode == MODE_DEPOSIT or mode == MODE_WITHDRAW
end

function autoBanking.RegisterRule(ruleId, getMode, matches, getMoveCount, allowGuildBankWithdraw)
    if not autoBanking.rules[ruleId] then
        table.insert(autoBanking.ruleOrder, ruleId)
    end

    autoBanking.rules[ruleId] = {
        id = ruleId,
        getMode = getMode,
        matches = matches,
        getMoveCount = getMoveCount,
        allowGuildBankWithdraw = allowGuildBankWithdraw == true,
    }
end

local function IsBankInteractionActive()
    if not ua.savedVariables.bankingEnabled then
        return false
    end

    if autoBanking.interactionKind == "guild" then
        local guildId = autoBanking.guildBankId

        return guildId
            and guildId > 0
            and GetInteractionType() == INTERACTION_GUILDBANK
            and (
                DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)
                or autoBanking.StackPlacement.CanDepositToGuild(guildId)
            )
    end

    if autoBanking.interactionKind == "house" then
        return IsBankOpen() and autoBanking.bankBagId and IsHouseBankBag(autoBanking.bankBagId)
    end

    return IsBankOpen() and GetInteractionType() == INTERACTION_BANK
end

local function IsEligibleItem(bagId, slotIndex)
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)

    if not itemLink or itemLink == "" then
        return false
    end

    if IsItemPlayerLocked(bagId, slotIndex) or IsItemStolen(bagId, slotIndex) then
        return false
    end

    return true, itemLink
end

local function IsCandidateValid(candidate)
    local rule = autoBanking.rules[candidate.ruleId]

    if not rule or rule.getMode() ~= candidate.mode then
        return false
    end

    local eligible, itemLink = IsEligibleItem(candidate.bagId, candidate.slotIndex)

    return eligible
        and itemLink == candidate.itemLink
        and rule.matches(itemLink, candidate.bagId, candidate.slotIndex)
end

local function ScanBag(bagId, mode, rule, candidates, seenSlots)
    local bagSize = GetBagSize(bagId)

    for slotIndex = 0, bagSize - 1 do
        local slotKey = tostring(bagId) .. ":" .. tostring(slotIndex)
        local eligible, itemLink = IsEligibleItem(bagId, slotIndex)

        if not seenSlots[slotKey] and eligible and rule.matches(itemLink, bagId, slotIndex) then
            seenSlots[slotKey] = true
            table.insert(candidates, {
                bagId = bagId,
                slotIndex = slotIndex,
                mode = mode,
                ruleId = rule.id,
                itemLink = itemLink,
            })
        end
    end
end

local function CollectCandidates()
    local candidates = {}
    local seenSlots = {}

    for _, ruleId in ipairs(autoBanking.ruleOrder) do
        local rule = autoBanking.rules[ruleId]
        local mode = rule.getMode()

        if mode == MODE_DEPOSIT then
            ScanBag(BAG_BACKPACK, mode, rule, candidates, seenSlots)
        elseif mode == MODE_WITHDRAW then
            ScanBag(BAG_BANK, mode, rule, candidates, seenSlots)

            if IsESOPlusSubscriber() then
                ScanBag(BAG_SUBSCRIBER_BANK, mode, rule, candidates, seenSlots)
            end
        end
    end

    return candidates
end

local function CollectGuildBankCandidates()
    local candidates = {}
    local seenSlots = {}
    local guildId = autoBanking.guildBankId

    if
        not guildId
        or not DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)
    then
        return candidates
    end

    for _, ruleId in ipairs(autoBanking.ruleOrder) do
        local rule = autoBanking.rules[ruleId]

        if rule.allowGuildBankWithdraw and rule.getMode() == MODE_WITHDRAW then
            ScanBag(BAG_GUILDBANK, MODE_WITHDRAW, rule, candidates, seenSlots)
        end
    end

    return candidates
end

local function IsSameStack(sourceBag, sourceSlot, targetBag, targetSlot)
    local sourceLink = GetItemLink(sourceBag, sourceSlot, LINK_STYLE_DEFAULT)
    local targetLink = GetItemLink(targetBag, targetSlot, LINK_STYLE_DEFAULT)

    sourceLink = sourceLink and string.gsub(sourceLink, "^|H%d+:", "|H1:")
    targetLink = targetLink and string.gsub(targetLink, "^|H%d+:", "|H1:")

    return sourceLink and sourceLink ~= "" and sourceLink == targetLink
end

local function FindStackDestination(candidate, targetBag)
    local sourceCount = GetSlotStackSize(candidate.bagId, candidate.slotIndex)
    local bagSize = GetBagSize(targetBag)

    for slotIndex = 0, bagSize - 1 do
        local targetCount, targetMaximum = GetSlotStackSize(targetBag, slotIndex)

        if
            targetCount
            and targetCount > 0
            and targetMaximum
            and targetCount < targetMaximum
            and IsSameStack(candidate.bagId, candidate.slotIndex, targetBag, slotIndex)
        then
            return slotIndex, math.min(sourceCount, targetMaximum - targetCount)
        end
    end
end

local function FindDestinationInBags(candidate, targetBags)
    for _, targetBag in ipairs(targetBags) do
        local slotIndex, moveCount = FindStackDestination(candidate, targetBag)

        if slotIndex ~= nil then
            return targetBag, slotIndex, moveCount
        end
    end

    local sourceCount = GetSlotStackSize(candidate.bagId, candidate.slotIndex)

    for _, targetBag in ipairs(targetBags) do
        local slotIndex = FindFirstEmptySlotInBag(targetBag)

        if slotIndex ~= nil then
            return targetBag, slotIndex, sourceCount
        end
    end
end

local function FindDestination(candidate)
    if candidate.targetBags then
        return FindDestinationInBags(candidate, candidate.targetBags)
    end

    if candidate.mode == MODE_WITHDRAW then
        return FindDestinationInBags(candidate, { BAG_BACKPACK })
    end

    local targetBags = { BAG_BANK }

    if IsESOPlusSubscriber() then
        table.insert(targetBags, BAG_SUBSCRIBER_BANK)
    end

    return FindDestinationInBags(candidate, targetBags)
end

local ProcessNextCandidate

local function SchedulePersonalRescan()
    if
        autoBanking.interactionKind ~= "personal"
        or autoBanking.stackPlacementPhase
        or autoBanking.personalRescanCount >= PERSONAL_RESCAN_LIMIT
    then
        return false
    end

    autoBanking.personalRescanCount = autoBanking.personalRescanCount + 1

    ScheduleForSession(function()
        if
            not autoBanking.processActive
            or autoBanking.interactionKind ~= "personal"
            or not IsBankInteractionActive()
        then
            return
        end

        autoBanking.queue = CollectCandidates()
        ProcessNextCandidate()
    end, PERSONAL_RESCAN_DELAY_MS)

    return true
end

local function RecordMove(candidate, movedCount)
    if movedCount <= 0 then
        return
    end

    autoBanking.movedItemCount = autoBanking.movedItemCount + movedCount

    local itemLink = candidate.itemLink or ""
    local itemKey = string.gsub(itemLink, "^|H%d+:", "|H1:")
    local key = candidate.mode
        .. ":"
        .. itemKey
        .. ":"
        .. tostring(candidate.destinationKind or "")
        .. ":"
        .. tostring(candidate.destinationId or 0)
    local entry = autoBanking.movedItems[key]

    if not entry then
        entry = {
            itemLink = itemLink,
            mode = candidate.mode,
            count = 0,
            destinationKind = candidate.destinationKind,
            destinationName = candidate.destinationName,
        }
        autoBanking.movedItems[key] = entry
        table.insert(autoBanking.movedItemOrder, key)
    end

    entry.count = entry.count + movedCount
end

local function StackBankContents(force)
    if not force and not GetSettings().stackBankOnOpen then
        return
    end

    StackBag(BAG_BANK)

    if IsESOPlusSubscriber() then
        StackBag(BAG_SUBSCRIBER_BANK)
    end
end

local function PrintReport()
    local reportMode = GetSettings().chatReportMode

    if reportMode == REPORT_MODE_NONE or autoBanking.movedItemCount <= 0 then
        return
    end

    if reportMode == REPORT_MODE_SUMMARY then
        d(CHAT_PREFIX .. string.format(L("REPORT_SUMMARY"), autoBanking.movedItemCount))
        return
    end

    for _, key in ipairs(autoBanking.movedItemOrder) do
        local entry = autoBanking.movedItems[key]

        if entry.destinationKind == "guild" then
            d(
                CHAT_PREFIX
                    .. string.format(
                        L("REPORT_DEPOSITED_GUILD"),
                        entry.destinationName,
                        entry.itemLink,
                        entry.count
                    )
            )
        elseif entry.destinationKind == "house" then
            d(
                CHAT_PREFIX
                    .. string.format(
                        L("REPORT_DEPOSITED_HOUSE"),
                        entry.destinationName,
                        entry.itemLink,
                        entry.count
                    )
            )
        else
            local stringKey = entry.mode == MODE_DEPOSIT and "REPORT_DEPOSITED"
                or "REPORT_WITHDRAWN"

            d(CHAT_PREFIX .. string.format(L(stringKey), entry.itemLink, entry.count))
        end
    end
end

local function CompleteProcess()
    autoBanking.processActive = false

    if autoBanking.interactionKind == "personal" then
        StackBankContents()
    end

    if GetSettings().stackBackpackOnOpen then
        StackBag(BAG_BACKPACK)
    end

    PrintReport()
end

local function FinishProcess()
    if not autoBanking.processActive then
        return
    end

    if
        autoBanking.interactionKind == "personal"
        and not autoBanking.stackPlacementPhase
        and autoBanking.StackPlacement.IsActive()
    then
        autoBanking.stackPlacementPhase = true
        StackBankContents(true)
        local phaseToken = autoBanking.moveToken

        zo_callLater(function()
            if
                not autoBanking.processActive
                or autoBanking.interactionKind ~= "personal"
                or autoBanking.moveToken ~= phaseToken
            then
                return
            end

            autoBanking.queue = autoBanking.StackPlacement.CollectPersonalCandidates()

            if #autoBanking.queue > 0 then
                ProcessNextCandidate()
                return
            end

            CompleteProcess()
        end, 250)

        return
    end

    CompleteProcess()
end

CompletePendingMove = function()
    local pendingMove = autoBanking.pendingMove

    if not pendingMove then
        return
    end

    local currentCount = GetSlotStackSize(pendingMove.bagId, pendingMove.slotIndex) or 0

    RecordMove(pendingMove, math.max(0, pendingMove.sourceCount - currentCount))

    autoBanking.pendingMove = nil
    autoBanking.moveToken = autoBanking.moveToken + 1

    if
        currentCount > 0
        and currentCount < pendingMove.sourceCount
        and IsCandidateValid(pendingMove)
    then
        table.insert(autoBanking.queue, 1, pendingMove)
    end

    local nextMoveDelay = pendingMove.bagId == BAG_GUILDBANK and GUILD_MOVE_DELAY_MS
        or PERSONAL_MOVE_DELAY_MS

    ScheduleForSession(ProcessNextCandidate, nextMoveDelay)
end

local function GetNextMovableCandidate()
    local candidateCount = #autoBanking.queue

    for _ = 1, candidateCount do
        local candidate = table.remove(autoBanking.queue, 1)

        if IsCandidateValid(candidate) then
            local destinationBag, destinationSlot, moveCount = FindDestination(candidate)

            if destinationBag ~= nil and moveCount then
                local rule = autoBanking.rules[candidate.ruleId]

                if rule and rule.getMoveCount then
                    moveCount = rule.getMoveCount(candidate.mode, moveCount)
                end

                if moveCount and moveCount > 0 then
                    return candidate, destinationBag, destinationSlot, moveCount
                end
            else
                table.insert(autoBanking.queue, candidate)
            end
        end
    end
end

ProcessNextCandidate = function()
    if not autoBanking.processActive or autoBanking.pendingMove then
        return
    end

    if not IsBankInteractionActive() then
        autoBanking.queue = {}
        autoBanking.pendingMove = nil
        autoBanking.processActive = false
        return
    end

    local candidate, destinationBag, destinationSlot, moveCount = GetNextMovableCandidate()

    if not candidate then
        if SchedulePersonalRescan() then
            return
        end

        FinishProcess()
        return
    end

    local sourceCount = GetSlotStackSize(candidate.bagId, candidate.slotIndex)

    if not sourceCount or sourceCount <= 0 then
        local nextMoveDelay = candidate.bagId == BAG_GUILDBANK and GUILD_MOVE_DELAY_MS
            or PERSONAL_MOVE_DELAY_MS

        ScheduleForSession(ProcessNextCandidate, nextMoveDelay)
        return
    end

    candidate.sourceCount = sourceCount
    candidate.itemLink = candidate.itemLink
        or GetItemLink(candidate.bagId, candidate.slotIndex, LINK_STYLE_DEFAULT)
    autoBanking.pendingMove = candidate
    autoBanking.moveToken = autoBanking.moveToken + 1
    local moveToken = autoBanking.moveToken

    if destinationBag == BAG_GUILDBANK then
        TransferToGuildBank(candidate.bagId, candidate.slotIndex)
    elseif candidate.bagId == BAG_GUILDBANK then
        TransferFromGuildBank(candidate.slotIndex)
    elseif IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected(
            "RequestMoveItem",
            candidate.bagId,
            candidate.slotIndex,
            destinationBag,
            destinationSlot,
            moveCount
        )
    else
        RequestMoveItem(
            candidate.bagId,
            candidate.slotIndex,
            destinationBag,
            destinationSlot,
            moveCount
        )
    end

    zo_callLater(function()
        if autoBanking.pendingMove and autoBanking.moveToken == moveToken then
            CompletePendingMove()
        end
    end, MOVE_TIMEOUT_MS)
end

function autoBanking.Process()
    StartSession()
    autoBanking.interactionKind = "personal"
    autoBanking.bankBagId = BAG_BANK

    if not IsBankInteractionActive() then
        return
    end

    autoBanking.Potions.RefreshChoices()
    autoBanking.FoodDrinks.RefreshChoices()

    autoBanking.queue = CollectCandidates()
    autoBanking.pendingMove = nil
    autoBanking.movedItemCount = 0
    autoBanking.movedItems = {}
    autoBanking.movedItemOrder = {}
    autoBanking.processActive = true
    autoBanking.stackPlacementPhase = false
    autoBanking.personalRescanCount = 0
    autoBanking.moveToken = autoBanking.moveToken + 1
    ProcessNextCandidate()
end

function autoBanking.ProcessGuildBank()
    StartSession()
    autoBanking.interactionKind = "guild"

    if not IsBankInteractionActive() then
        return
    end

    autoBanking.queue = CollectGuildBankCandidates()

    local placementCandidates =
        autoBanking.StackPlacement.CollectDestinationCandidates("guild", BAG_GUILDBANK)

    for _, candidate in ipairs(placementCandidates) do
        table.insert(autoBanking.queue, candidate)
    end
    autoBanking.pendingMove = nil
    autoBanking.movedItemCount = 0
    autoBanking.movedItems = {}
    autoBanking.movedItemOrder = {}
    autoBanking.processActive = true
    autoBanking.stackPlacementPhase = false
    autoBanking.personalRescanCount = 0
    autoBanking.moveToken = autoBanking.moveToken + 1
    ProcessNextCandidate()
end

function autoBanking.ProcessHouseBank(bankBagId)
    StartSession()
    autoBanking.interactionKind = "house"
    autoBanking.bankBagId = bankBagId

    if
        not IsBankInteractionActive()
        or not autoBanking.StackPlacement.IsSelectedHouseBank(bankBagId)
    then
        return
    end

    autoBanking.queue = autoBanking.StackPlacement.CollectDestinationCandidates("house", bankBagId)
    autoBanking.pendingMove = nil
    autoBanking.movedItemCount = 0
    autoBanking.movedItems = {}
    autoBanking.movedItemOrder = {}
    autoBanking.processActive = true
    autoBanking.stackPlacementPhase = false
    autoBanking.personalRescanCount = 0
    autoBanking.moveToken = autoBanking.moveToken + 1
    ProcessNextCandidate()
end

local function RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(
        EVENT_NAMESPACE .. "Open",
        EVENT_OPEN_BANK,
        function(_, bankBagId)
            StartSession()
            if bankBagId and IsHouseBankBag(bankBagId) then
                ScheduleForSession(function()
                    autoBanking.ProcessHouseBank(bankBagId)
                end, OPEN_DELAY_MS)
            else
                ScheduleForSession(autoBanking.Process, OPEN_DELAY_MS)
            end
        end
    )

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Close", EVENT_CLOSE_BANK, function()
        StartSession()
        autoBanking.queue = {}
        autoBanking.pendingMove = nil
        autoBanking.processActive = false
        autoBanking.interactionKind = nil
        autoBanking.bankBagId = nil
        autoBanking.stackPlacementPhase = false
        autoBanking.moveToken = autoBanking.moveToken + 1
    end)

    EVENT_MANAGER:RegisterForEvent(
        EVENT_NAMESPACE .. "GuildSelected",
        EVENT_GUILD_BANK_SELECTED,
        function(_, guildBankId)
            StartSession()
            autoBanking.guildBankId = guildBankId
            autoBanking.guildReadyToken = autoBanking.guildReadyToken + 1
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        EVENT_NAMESPACE .. "GuildReady",
        EVENT_GUILD_BANK_ITEMS_READY,
        function()
            autoBanking.guildReadyToken = autoBanking.guildReadyToken + 1
            local readyToken = autoBanking.guildReadyToken

            ScheduleForSession(function()
                if readyToken == autoBanking.guildReadyToken then
                    autoBanking.ProcessGuildBank()
                end
            end, 1000)
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        EVENT_NAMESPACE .. "GuildClose",
        EVENT_CLOSE_GUILD_BANK,
        function()
            autoBanking.guildBankId = nil
            StartSession()
            autoBanking.guildReadyToken = autoBanking.guildReadyToken + 1
            autoBanking.queue = {}
            autoBanking.pendingMove = nil
            autoBanking.processActive = false
            autoBanking.interactionKind = nil
            autoBanking.stackPlacementPhase = false
            autoBanking.moveToken = autoBanking.moveToken + 1
        end
    )

    EVENT_MANAGER:RegisterForEvent(
        EVENT_NAMESPACE .. "Slot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bagId, slotIndex)
            local pendingMove = autoBanking.pendingMove

            if not pendingMove then
                return
            end

            if pendingMove.bagId == BAG_GUILDBANK then
                if bagId == BAG_BACKPACK then
                    local moveToken = autoBanking.moveToken

                    zo_callLater(function()
                        if autoBanking.pendingMove and autoBanking.moveToken == moveToken then
                            CompletePendingMove()
                        end
                    end, GUILD_MOVE_DELAY_MS)
                end

                return
            end

            if bagId ~= pendingMove.bagId or slotIndex ~= pendingMove.slotIndex then
                return
            end

            local currentCount = GetSlotStackSize(bagId, slotIndex) or 0

            if currentCount < pendingMove.sourceCount then
                CompletePendingMove()
            end
        end
    )
end

function autoBanking.Initialize()
    autoBanking.rules = {}
    autoBanking.ruleOrder = {}
    autoBanking.queue = {}
    autoBanking.pendingMove = nil
    autoBanking.movedItemCount = 0
    autoBanking.movedItems = {}
    autoBanking.movedItemOrder = {}
    autoBanking.processActive = false
    autoBanking.interactionKind = nil
    autoBanking.bankBagId = nil
    autoBanking.guildBankId = nil
    autoBanking.guildReadyToken = 0
    autoBanking.moveToken = 0
    autoBanking.stackPlacementPhase = false
    autoBanking.personalRescanCount = 0

    autoBanking.CraftingItems.Initialize()
    autoBanking.StackPlacement.Initialize()
    autoBanking.Potions.Initialize()
    autoBanking.FoodDrinks.Initialize()
    autoBanking.SpecialItems.Initialize()
    autoBanking.PvP.Initialize()
    RegisterEvents()
end

function autoBanking.CreateMenuControls()
    local controls = {
        {
            type = "header",
            name = ua.GetString("BANKING_CRAFTING_ITEMS"),
        },
        autoBanking.CraftingItems.CreateEnableControl(),
        autoBanking.CraftingItems.CreateAllModeControl(),
    }

    for _, control in ipairs(autoBanking.CraftingItems.CreateMenuControls()) do
        table.insert(controls, control)
    end

    for _, control in ipairs(autoBanking.StackPlacement.CreateMenuControls()) do
        table.insert(controls, control)
    end

    table.insert(controls, { type = "divider" })
    table.insert(controls, {
        type = "header",
        name = ua.GetString("BANKING_SPECIAL_ITEMS"),
    })
    table.insert(controls, autoBanking.SpecialItems.CreateEnableControl())

    for _, control in ipairs(autoBanking.SpecialItems.CreateMenuControls()) do
        table.insert(controls, control)
    end

    table.insert(controls, { type = "divider" })
    table.insert(controls, {
        type = "header",
        name = ua.GetString("BANKING_PVP"),
    })
    table.insert(controls, autoBanking.PvP.CreateEnableControl())

    for _, control in ipairs(autoBanking.PvP.CreateMenuControls()) do
        table.insert(controls, control)
    end

    local settings = GetSettings()

    table.insert(controls, { type = "divider" })
    table.insert(controls, {
        type = "checkbox",
        name = L("STACK_BANK_ON_OPEN"),
        tooltip = L("STACK_BANK_ON_OPEN_TOOLTIP"),
        getFunc = function()
            return settings.stackBankOnOpen
        end,
        setFunc = function(value)
            settings.stackBankOnOpen = value
        end,
        default = false,
    })
    table.insert(controls, {
        type = "checkbox",
        name = L("STACK_BACKPACK_ON_OPEN"),
        tooltip = L("STACK_BACKPACK_ON_OPEN_TOOLTIP"),
        getFunc = function()
            return settings.stackBackpackOnOpen
        end,
        setFunc = function(value)
            settings.stackBackpackOnOpen = value
        end,
        default = false,
    })
    table.insert(controls, {
        type = "dropdown",
        name = L("CHAT_REPORT"),
        tooltip = L("CHAT_REPORT_TOOLTIP"),
        choices = {
            L("REPORT_MODE_NONE"),
            L("REPORT_MODE_ITEMS"),
            L("REPORT_MODE_SUMMARY"),
        },
        choicesValues = {
            REPORT_MODE_NONE,
            REPORT_MODE_ITEMS,
            REPORT_MODE_SUMMARY,
        },
        getFunc = function()
            return settings.chatReportMode
        end,
        setFunc = function(value)
            settings.chatReportMode = value
        end,
        default = REPORT_MODE_NONE,
    })

    return controls
end
