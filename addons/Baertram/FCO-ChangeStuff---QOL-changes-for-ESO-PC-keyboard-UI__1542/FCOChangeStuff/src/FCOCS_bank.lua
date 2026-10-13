if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS
local FCOCS_name = FCOChangeStuff.addonVars.addonName
local FCOCS_name_prefix = "[" .. FCOCS_name .. "]"

local EM = EVENT_MANAGER
local tos = tostring

------------------------------------------------------------------------------------------------------------------------
-- Bank --
------------------------------------------------------------------------------------------------------------------------

local sceneHooksDoneAt = {}

--[[
local bankingBagIdToInvType = {
    [BAG_BACKPACK]          = INVENTORY_BACKPACK,
    [BAG_BANK]              = INVENTORY_BANK,
    [BAG_GUILDBANK]         = INVENTORY_GUILD_BANK,
    [BAG_HOUSE_BANK_ONE]    = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_TWO]    = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_THREE]  = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_FOUR]   = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_FIVE]   = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_SIX]    = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_SEVEN]  = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_EIGHT]  = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_NINE]   = INVENTORY_HOUSE_BANK,
    [BAG_HOUSE_BANK_TEN]    = INVENTORY_HOUSE_BANK,
}
]]
local houseBankMenuBar = ZO_HouseBankMenuBar
local bankingBagIdToMenuBar = {
    [BAG_BACKPACK]          = ZO_PlayerInventoryMenuBar,
    [BAG_BANK]              = ZO_PlayerBankMenuBar,
    [BAG_GUILDBANK]         = ZO_GuildBankMenuBar,
    [BAG_HOUSE_BANK_ONE]    = houseBankMenuBar,
    [BAG_HOUSE_BANK_TWO]    = houseBankMenuBar,
    [BAG_HOUSE_BANK_THREE]  = houseBankMenuBar,
    [BAG_HOUSE_BANK_FOUR]   = houseBankMenuBar,
    [BAG_HOUSE_BANK_FIVE]   = houseBankMenuBar,
    [BAG_HOUSE_BANK_SIX]    = houseBankMenuBar,
    [BAG_HOUSE_BANK_SEVEN]  = houseBankMenuBar,
    [BAG_HOUSE_BANK_EIGHT]  = houseBankMenuBar,
    [BAG_HOUSE_BANK_NINE]   = houseBankMenuBar,
    [BAG_HOUSE_BANK_TEN]    = houseBankMenuBar,
}
local houseBankDescriptors = {
    [SI_BANK_DEPOSIT] = SI_BANK_WITHDRAW,            --Withdraw
    [SI_BANK_WITHDRAW] = SI_BANK_DEPOSIT,            --Deposit
}
local bankingBagIdToDescriptors = {
    [BAG_BACKPACK]          = {
        [SI_BANK_DEPOSIT] = SI_BANK_WITHDRAW,        --Withdraw
        [SI_BANK_WITHDRAW] = SI_BANK_DEPOSIT,        --Deposit
    },
    [BAG_BANK]              = {
        [SI_BANK_DEPOSIT] = SI_BANK_WITHDRAW,     --Withdraw
        [SI_BANK_WITHDRAW] = SI_BANK_DEPOSIT,     --Deposit
    },
    [BAG_GUILDBANK]         = {
        [SI_BANK_DEPOSIT] = SI_BANK_WITHDRAW,        --Withdraw
        [SI_BANK_WITHDRAW] = SI_BANK_DEPOSIT,        --Deposit
    },
    [BAG_HOUSE_BANK_ONE]    = houseBankDescriptors,
    [BAG_HOUSE_BANK_TWO]    = houseBankDescriptors,
    [BAG_HOUSE_BANK_THREE]  = houseBankDescriptors,
    [BAG_HOUSE_BANK_FOUR]   = houseBankDescriptors,
    [BAG_HOUSE_BANK_FIVE]   = houseBankDescriptors,
    [BAG_HOUSE_BANK_SIX]    = houseBankDescriptors,
    [BAG_HOUSE_BANK_SEVEN]  = houseBankDescriptors,
    [BAG_HOUSE_BANK_EIGHT]  = houseBankDescriptors,
    [BAG_HOUSE_BANK_NINE]   = houseBankDescriptors,
    [BAG_HOUSE_BANK_TEN]    = houseBankDescriptors,
}

local PI = PLAYER_INVENTORY
local SM = SCENE_MANAGER


------------------------------------------------------------------------------------------------------------------------
function FCOChangeStuff.EnableCharacterFragment(where)
    if not where or where == "" then return end
    local settings = FCOChangeStuff.settingsVars.settings
    local whereToScene = {
        ["bank"] = nil,
        ["guildbank"] = nil,
    }
    local whereToSceneByName = {
        ["bank"]      = "bank",
        ["guildbank"] = "guildBank",
    }
    --[[
    local whereToFragment = {
        ["bank"] = BANK_FRAGMENT,
    }
    ]]
    local whereToAddNewFragments = {
        ["bank"] = {
            CHARACTER_WINDOW_FRAGMENT,
            CHARACTER_WINDOW_STATS_FRAGMENT,
            LEFT_PANEL_BG_FRAGMENT,
        }
    }
    whereToAddNewFragments["guildbank"] = whereToAddNewFragments["bank"]

    local sceneToHook = whereToScene[where]
    local sceneToHookName
    if not sceneToHook then
        sceneToHookName = whereToSceneByName[where]
    end
    if not sceneToHookName or sceneToHookName == "" then return end
    sceneToHook = SM:GetScene(sceneToHookName)
    if not sceneToHook then return end
    --local fragmentToHook = whereToFragment[where]
    --if not fragmentToHook then return end
    local fragmentsToAddNew = whereToAddNewFragments[where]
    if not fragmentsToAddNew then return end

    local function removeFragments()
--d("[FCOCS]removeFragments")
        for _, fragmentToAddNew in ipairs(fragmentsToAddNew) do
            sceneToHook:RemoveFragment(fragmentToAddNew)
        end
    end
    local function sceneStateChange(oldState, newState, whereWasItDone)
--d("[FCOCS]sceneStateChange-newState: " .. tos(newState) .. ", whereWasItDone: " .. tos(whereWasItDone))
        if whereWasItDone and sceneHooksDoneAt[whereWasItDone] == true then
            if whereWasItDone == "bank" and not settings.showCharacterPanelAtBank then
                removeFragments()
                return
            end
            if whereWasItDone == "guildbank" and not settings.showCharacterPanelAtGuildBank then
                removeFragments()
                return
            end
        end
        if newState == SCENE_SHOWN then
--d("[SHOWN]addFragments")
            for _, fragmentToAddNew in ipairs(fragmentsToAddNew) do
                sceneToHook:AddFragment(fragmentToAddNew)
            end
        elseif newState == SCENE_HIDDEN then
--d("[HIDDEN]")
            removeFragments()
        end
    end
    if (where == "bank" and settings.showCharacterPanelAtBank == true)
       or (where == "guildbank" and settings.showCharacterPanelAtGuildBank  == true)
    then
        sceneHooksDoneAt[where] = true
        sceneToHook:RegisterCallback("StateChange", function(oldState, newState) sceneStateChange(oldState, newState, where) end)
    end
end

------------------------------------------------------------------------------------------------------------------------


local function getMenuBar(bankBagId)
    local menuBar = bankingBagIdToMenuBar[bankBagId]
    return menuBar
end

local function getMenuBarAndNotSelectedDescriptor(bankBagId)
--d("getMenuBarAndNotSelectedDescriptor")
    local menuBar = getMenuBar(bankBagId)
    if not menuBar then return end
--d(">Found menubar")
    local selectedDescriptor = menuBar.m_object.m_clickedButton.m_buttonData.descriptor
    if not selectedDescriptor then return end
--d(">Found selectedDescriptor:" .. GetString(selectedDescriptor))
    local nonSelectedDescriptor = bankingBagIdToDescriptors[bankBagId][selectedDescriptor]
    return menuBar, nonSelectedDescriptor
end

--[[
local function getMenuBarAndSelectedFilterTab(bankBagId)
d("getMenuBarAndSelectedTab - bankBagId: " ..tos(bankBagId))
    local layoutData = PI.appliedLayout
    if not layoutData then return end
d(">1")
    local invType = bankingBagIdToInvType[bankBagId]
    if not invType then return end
d(">invType: " ..tos(invType))
    local menuBar = PI.inventories[invType].filterBar
    if not menuBar or not menuBar.IsHidden or menuBar:IsHidden() then return end
    local selectedTab = layoutData.selectedTab or ITEM_TYPE_DISPLAY_CATEGORY_ALL
d(">selectedTab: " ..tos(selectedTab))
    return menuBar, selectedTab
end
]]

local function getMenuBarAndDescriptor()
    --d("getMenuBarAndDescriptor")
    local bankBagId
    if IsBankOpen() then bankBagId = GetBankingBag()
    elseif IsGuildBankOpen() then
        if ZO_SelectGuildBankDialog:IsHidden() then
            bankBagId = BAG_GUILDBANK
        end
    end
    --d(">bankBagId: " ..tos(bankBagId))
    if not bankBagId or bankBagId <= 0 then return end
    --Get the bank menubar and descriptor (selected filter tab) of the bank bagId
    local menuBar, descriptorNew = getMenuBarAndNotSelectedDescriptor(bankBagId)
    --d(">descriptor to select new: " ..tos(descriptorNew))
    if not menuBar or not descriptorNew then return end
    return menuBar, descriptorNew
end

function FCOChangeStuff.switchBankMenuBarDescriptor()
--d("[FCOChangeStuff]SwitchBankMenuBarDescriptor()")
    local categoryBar, category = getMenuBarAndDescriptor()
    if not categoryBar or not category then return end
    ZO_MenuBar_SelectDescriptor(categoryBar, category, true)
end



------------------------------------------------------------------------------------------------------------------------
--Currencies
------------------------------------------------------------------------------------------------------------------------
local currencyBankEventName = FCOCS_name .. "_CurrencyBank"
local currenciesBankSupported = {
    [CURT_TELVAR_STONES] = true,
    [CURT_ALLIANCE_POINTS] = true,
}
local currencyIcons = {
    [CURT_TELVAR_STONES] = zo_iconTextFormatNoSpace(GetCurrencyKeyboardIcon(CURT_TELVAR_STONES), 24, 24), --Tel'Var Stones
    [CURT_ALLIANCE_POINTS] = zo_iconTextFormatNoSpace(GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS), 24, 24), --Alliance Points
}
local currencyIconStrings = {
    [CURT_TELVAR_STONES] = currencyIcons[CURT_TELVAR_STONES] .. " (" .. GetCurrencyName(CURT_TELVAR_STONES, true, false) .. ")", --Tel'Var Stones
    [CURT_ALLIANCE_POINTS] = currencyIcons[CURT_ALLIANCE_POINTS] .. " (" .. GetCurrencyName(CURT_ALLIANCE_POINTS, true, false) .. ")", --Alliance Points
}

--[[
local function afterDepositChecks(eventId)

end
]]

local function depositCurrencyNow(currencyType, currencyAmount)
    local settings = FCOChangeStuff.settingsVars.settings
    if currencyType == nil then return end
    if not currenciesBankSupported[currencyType] then return end
    if currencyAmount == nil then currencyAmount = GetCarriedCurrencyAmount(currencyType) end
    if currencyAmount == nil or currencyAmount <= 0 then return end

    --CurrencyAmount on toon is equal or above the threshold, or threshold is set to 0 (bank always all) then deposit all!
    local thresholdAmountForCurrency = settings.currencyThresholdOnChar[currencyType]
    if thresholdAmountForCurrency == 0 or currencyAmount >= thresholdAmountForCurrency then
        --Check anything with the currencyType's amount already depositted to the bank? local currentCurrencyInBank = GetBankedCurrencyAmount(currencyType)
        --Deposit all the currencyTypes' amount from toon to bank now
        DepositCurrencyIntoBank(currencyType, currencyAmount)
        d(FCOCS_name_prefix .. "Automatically deposited \'" ..tos(currencyAmount) .. currencyIconStrings[currencyType] .. " into your bank.")
    end
end

local function depositCurrencyCheck(eventId)
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.enableCurrencyDepositHelpers then return end

    --todo: Test if we can we deposit AP and Tel'Var if the withdraw tab is active?
    for currencyTypeSupported, isSupported in pairs(currenciesBankSupported) do
        if isSupported then depositCurrencyNow(currencyTypeSupported, GetCurrencyAmount(currencyTypeSupported, CURRENCY_LOCATION_CHARACTER)) end
    end
    --EM:RegisterForEvent(currencyBankEventName, EVENT_BANKED_CURRENCY_UPDATE, afterDepositChecks)
end

--[[
local function closeBankCurrencyCheck(eventId)
    EM:UnregisterForEvent(currencyBankEventName, EVENT_BANKED_CURRENCY_UPDATE)
end
]]

local function loadBankCurrencyEvents(enableCurrencyDepositHelpersNow)
    if enableCurrencyDepositHelpersNow then
        -- Bank Scene
        EM:RegisterForEvent(currencyBankEventName, EVENT_OPEN_BANK, depositCurrencyCheck)
        --EM:RegisterForEvent(currencyBankEventName, EVENT_CLOSE_BANK, closeBankCurrencyCheck)
    else
        -- Bank Scene
        EM:UnregisterForEvent(currencyBankEventName, EVENT_OPEN_BANK)
        --EM:UnregisterForEvent(currencyBankEventName, EVENT_CLOSE_BANK)
        --closeBankCurrencyCheck()
    end
end

--Auto deposit currencies like AP and Tel'Var to your bank, if it's above a defined threshold
local function enableCurrencyDepositHelpers()
    loadBankCurrencyEvents(FCOChangeStuff.settingsVars.settings.enableCurrencyDepositHelpers)
end
FCOChangeStuff.EnableCurrencyDepositHelpers = enableCurrencyDepositHelpers

--[[
local function enableCurrencyDepositDialogHelpers()
    local settings = FCOChangeStuff.settingsVars.settings
    if not settings.enableCurrencyDepositDialogHelper then return end

    --todo hook into the dialog's OnEffectivelyShown handler and focus the amount editbox
    if settings.autoFocusCurrencyDepositDialogEditBox then

    end
end
FCOChangeStuff.EnableCurrencyDepositDialogHelpers = enableCurrencyDepositDialogHelpers
]]

function FCOChangeStuff.EnableCurrencyFeatures()
    enableCurrencyDepositHelpers()
    --enableCurrencyDepositDialogHelpers()
end



------------------------------------------------------------------------------------------------------------------------
--Enable the bank modifications
function FCOChangeStuff.bankChanges()
    FCOChangeStuff.EnableCharacterFragment("bank")
    FCOChangeStuff.EnableCharacterFragment("guildbank")

    FCOChangeStuff.EnableCurrencyFeatures()
end
