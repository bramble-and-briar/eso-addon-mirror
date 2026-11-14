NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local Guilds = {}
local defaults = { guilds = { trackGoldDeposits = false, lastGoldDeposits = {} } }
local EVENT_NAMESPACE = "NQOLGuildGoldDeposits"
local DIALOG_NAMES = { "GUILD_BANK_GAMEPAD_CHANGE_ACTIVE_GUILD", "TRADING_HOUSE_CHANGE_ACTIVE_GUILD" }
local savedVariables
local initialized = false
local pendingDeposits = {}
local dialogs = setmetatable({}, { __mode = "k" })

local function GetSettings()
    local settings = NQOL.Settings.GetSection(savedVariables, defaults, "guilds")
    NQOL.Settings.Boolean(settings, defaults.guilds, "trackGoldDeposits")
    NQOL.Settings.EnsureTable(settings, "lastGoldDeposits")
    return settings
end

local function GetDeposits()
    -- Guild IDs and memberships belong to a megaserver, while settings are account-wide.
    local records = GetSettings().lastGoldDeposits
    local world = GetWorldName()
    if type(records[world]) ~= "table" then
        records[world] = {}
    end
    return records[world]
end

local function GetMembership()
    local membership = {}
    for index = 1, GetNumGuilds() do
        membership[GetGuildId(index)] = true
    end
    return membership
end

local function GetDepositText(guildId)
    if not GetSettings().trackGoldDeposits then
        return nil
    end
    local deposit = GetDeposits()[guildId]
    if type(deposit) ~= "table" or type(deposit.timestamp) ~= "number" or type(deposit.amount) ~= "number" then
        return NQOL.L("features.guilds.no_gold_deposit_record")
    end
    local amount = ZO_CurrencyControl_FormatCurrencyAndAppendIcon(deposit.amount, false, CURT_MONEY, true)
    local days = math.max(0, math.floor((GetTimeStamp() - deposit.timestamp) / 86400))
    local age
    if days == 0 then
        age = NQOL.L("features.guilds.today")
    elseif days == 1 then
        age = NQOL.L("features.guilds.yesterday")
    else
        age = zo_strformat(SI_TIME_DURATION_AGO, zo_strformat(SI_TIME_FORMAT_DAYS_DESC, days))
    end
    return NQOL.L("features.guilds.last_deposit", GetDateStringFromTimestamp(deposit.timestamp), amount), age
end

local function RefreshDialog(dialog)
    local list = dialog.entryList
    if not list or not list.GetNumEntries or not list.GetEntryData then
        return
    end
    for index = 1, list:GetNumEntries() do
        local entry = list:GetEntryData(index)
        if entry and entry.guildId and entry.AddSubLabel then
            local text = GetDepositText(entry.guildId)
            if text then
                if not entry.nqolGoldDepositProvider then
                    entry.nqolGoldDepositProvider = function() return GetDepositText(entry.guildId) end
                    entry.nqolGoldDepositAgeProvider = function()
                        local _, age = GetDepositText(entry.guildId)
                        return age
                    end
                    entry.nqolGoldDepositShowUnselected = entry.showUnselectedSublabels
                    entry:AddSubLabel(entry.nqolGoldDepositProvider)
                    entry:AddSubLabel(entry.nqolGoldDepositAgeProvider)
                end
                entry:SetShowUnselectedSublabels(true)
            elseif entry.nqolGoldDepositProvider then
                for subIndex = #(entry.subLabels or {}), 1, -1 do
                    if entry.subLabels[subIndex] == entry.nqolGoldDepositProvider
                        or entry.subLabels[subIndex] == entry.nqolGoldDepositAgeProvider then
                        table.remove(entry.subLabels, subIndex)
                    end
                end
                entry:SetShowUnselectedSublabels(entry.nqolGoldDepositShowUnselected)
                entry.nqolGoldDepositProvider = nil
                entry.nqolGoldDepositAgeProvider = nil
                entry.nqolGoldDepositShowUnselected = nil
            end
        end
    end
    list:RefreshVisible()
end

local function RefreshDialogs()
    for dialog, info in pairs(dialogs) do
        -- ESO reuses the same parametric dialog control for unrelated dialogs.
        if dialog.info == info then
            RefreshDialog(dialog)
        else
            dialogs[dialog] = nil
        end
    end
end

local function OnTransferCurrency(currencyType, amount, source, destination)
    if GetSettings().trackGoldDeposits and currencyType == CURT_MONEY
        and source == CURRENCY_LOCATION_CHARACTER and destination == CURRENCY_LOCATION_GUILD_BANK
        and type(amount) == "number" and amount > 0 then
        pendingDeposits[#pendingDeposits + 1] = {
            guildId = GetSelectedGuildBankId(), amount = amount, timestamp = GetTimeStamp(),
        }
    end
end

local function OnMoneyUpdate(_, newMoney, oldMoney, reason)
    if not GetSettings().trackGoldDeposits or reason ~= CURRENCY_CHANGE_REASON_GUILD_BANK_DEPOSIT
        or type(newMoney) ~= "number" or type(oldMoney) ~= "number" or oldMoney <= newMoney then
        return
    end

    local amount = oldMoney - newMoney
    local timestamp = GetTimeStamp()
    local guildId = GetSelectedGuildBankId()
    -- Retain the guild at submission if the player switches banks before confirmation.
    for index = #pendingDeposits, 1, -1 do
        if timestamp - pendingDeposits[index].timestamp > 60 then
            table.remove(pendingDeposits, index)
        end
    end
    for index, pending in ipairs(pendingDeposits) do
        if pending.amount == amount then
            guildId = pending.guildId
            table.remove(pendingDeposits, index)
            break
        end
    end

    local membership = GetMembership()
    if not membership[guildId] then
        return
    end
    local deposits = GetDeposits()
    deposits[guildId] = { timestamp = timestamp, amount = amount }
    for recordedGuildId in pairs(deposits) do
        if not membership[recordedGuildId] then
            deposits[recordedGuildId] = nil
        end
    end
    local manager = GetAddOnManager and GetAddOnManager()
    if manager and manager.RequestAddOnSavedVariablesPrioritySave then
        manager:RequestAddOnSavedVariablesPrioritySave(NQOL.name or "NQOL")
    end
    RefreshDialogs()
end

function Guilds.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    GetSettings()
end

function Guilds.Initialize()
    if initialized then return end
    initialized = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_MONEY_UPDATE, OnMoneyUpdate)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_GUILD_BANK_TRANSFER_ERROR, function() pendingDeposits = {} end)
    if type(SecurePostHook) == "function" then
        if type(TransferCurrency) == "function" then
            SecurePostHook("TransferCurrency", OnTransferCurrency)
        end
        for _, name in ipairs(DIALOG_NAMES) do
            local info = ESO_Dialogs and ESO_Dialogs[name]
            if info and type(info.setup) == "function" then
                SecurePostHook(info, "setup", function(dialog)
                    dialogs[dialog] = info
                    RefreshDialog(dialog)
                end)
            end
        end
    end
end

function Guilds.GetTrackGoldDeposits() return GetSettings().trackGoldDeposits end
function Guilds.GetTrackGoldDepositsDefault() return defaults.guilds.trackGoldDeposits end
function Guilds.SetTrackGoldDeposits(value)
    GetSettings().trackGoldDeposits = value == true
    pendingDeposits = {}
    RefreshDialogs()
end

NQOL.Features.Guilds = Guilds
