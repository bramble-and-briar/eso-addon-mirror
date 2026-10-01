--	===============================================================================================================
--	Gold Ledger
--	===============================================================================================================
--	This addon serves as a alternative/upgrade for the discontinued 'Ledger' addon, offering many improvements from the predecessor.
--	A large amount of functionality has been built upon, repaired or added as unique new features for additional convenience.
--	Please review the addon website for further details & function specifics.
--
--	(c) 02/06/23 - Present
--
--	'Gold Ledger' coded & maintained by: P5YCH3 (https://www.esoui.com/forums/member.php?u=47541)
--	===============================================================================================================

local ledger={}
local goldledger={} --P5YCH3
local GOLD_LEDGER_ADDON_WEBSITE = "https://www.esoui.com/downloads/info3566-GoldLedger.html#info"
local GOLD_LEDGER_FEEDBACK_WEBSITE = "https://www.esoui.com/forums/member.php?u=47541"
goldledger.name="gold ledger"
goldledger.version="2.3.1"
goldledger.loaded=false

GOLD_LEDGER = "GoldLedger"

local INCOME_COLOR = ZO_ColorDef:New("11EE99")
local EXPENSE_COLOR = ZO_ColorDef:New("EE2222")

local function Ledger_FormatCurrencyVariation(value)

    local formattedValue = ZO_CurrencyControl_FormatCurrency(zo_abs(value))

    if value >= 0 then
        return INCOME_COLOR:Colorize("+"..formattedValue)
    else
        return EXPENSE_COLOR:Colorize("-"..formattedValue)
    end
end

local function Ledger_SetupComboBox(self, name)
    local comboBox = ZO_ComboBox_ObjectFromContainer(GetControl(self.control, name))
    comboBox:SetSortsItems(false)
    return comboBox
end

local GoldLedger = ZO_SortFilterList:Subclass()

GOLD_LEDGER_ROW_HEIGHT = 28

function GoldLedger:New(...)
    return ZO_SortFilterList.New(self, ...)
end

function GoldLedger:Initialize(control, savedVars)
    ZO_SortFilterList.Initialize(self, control)

    ZO_ScrollList_AddDataType(self.list, 1, "LedgerRow", GOLD_LEDGER_ROW_HEIGHT, function(...) self:SetupRow(...) end)
    ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

    self:SetAlternateRowBackgrounds(true)
    self:SetEmptyText(GetString(SI_GOLD_LEDGER_EMPTY))

    self.sortHeaderGroup:SelectHeaderByKey("timestamp")

    self.savedVars = savedVars

    self.control:SetHandler("OnMoveStop", function()
        self.savedVars.offsetX = self.control:GetLeft()
        self.savedVars.offsetY = self.control:GetTop()
    end)

    self.control:SetHandler("OnResizeStop", function()
        self.savedVars.x = self.control:GetWidth()
        self.savedVars.y = self.control:GetHeight()
        self:RefreshScrollListHeight()
    end)

    if not (self.savedVars.offsetX == 0 and self.savedVars.offsetY == 0) then
        self.control:ClearAnchors()
        self.control:SetAnchor(TOPLEFT, nil, TOPLEFT, self.savedVars.offsetX, self.savedVars.offsetY)
    end
    self.control:SetDimensions(self.savedVars.x, self.savedVars.y)

    self.sceneFragment = ZO_HUDFadeSceneFragment:New(self.control)
    HUD_SCENE:AddFragment(self.sceneFragment)
    HUD_UI_SCENE:AddFragment(self.sceneFragment)
    self.sceneFragment:SetHiddenForReason("hidden", self.savedVars.isHidden)

    local function OnFragmentStateChange()
        self.savedVars.isHidden = self.sceneFragment:IsHidden()
        self:Refresh()
    end
    self.sceneFragment:RegisterCallback("StateChange", OnFragmentStateChange)

    local characterName = GetUnitName("player")

    if not table.indexOf(self.savedVars.charactersList, characterName) then
        table.insert(self.savedVars.charactersList, characterName)
    end

    self.summaryLabel = GetControl(self.control, "Summary")

    self:SetupPeriodComboBox()
    self:SetupCharacterComboBox()

    self.mergeCheckBox = GetControl(self.control, "OptionsMergeCheckBox")
    ZO_CheckButton_SetLabelText(self.mergeCheckBox, GetString(SI_GOLD_LEDGER_MERGE_LABEL))
    ZO_CheckButton_SetCheckState(self.mergeCheckBox, self.savedVars.options.shouldMerge)
    ZO_CheckButton_SetToggleFunction(self.mergeCheckBox, function(control, state)
        self.savedVars.options.shouldMerge = state
        self:Refresh()
    end)

    self.searchBox = GetControl(self.control, "OptionsSearchBox")
    self.searchBox:SetHandler("OnTextChanged", function(editBox)
        ZO_EditDefaultText_OnTextChanged(editBox)
        self.savedVars.options.searchQuery = editBox:GetText()
        self:Refresh()
    end)
    self.searchBox:SetText(self.savedVars.options.searchQuery)

    local function OnPlayerCombatState(event, inCombat)
        self.sceneFragment:SetHiddenForReason("combat", inCombat)
    end
    self.control:RegisterForEvent(EVENT_PLAYER_COMBAT_STATE, OnPlayerCombatState)

    local function OnMoneyUpdate(event, newBalance, previousBalance, reason)
        local record =
        {
            timestamp = GetTimeStamp(),
            character = GetUnitName("player"),
            reason = reason,
            variation = newBalance - previousBalance,
            balance = newBalance,
        }

        table.insert(self.savedVars.masterList, record)

        self:Refresh()
    end
    self.control:RegisterForEvent(EVENT_MONEY_UPDATE, OnMoneyUpdate)

    local function OnBankedMoneyUpdate(event, newBalance, previousBalance)
        local entry =
        {
            timestamp = GetTimeStamp(),
            character = "bank",
            variation = newBalance - previousBalance,
            balance = newBalance,
        }

        if newBalance > previousBalance then
            entry.reason = CURRENCY_CHANGE_REASON_BANK_DEPOSIT
        else
            entry.reason = CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
        end

        table.insert(self.savedVars.masterList, entry)

        self:Refresh()
    end
    self.control:RegisterForEvent(EVENT_BANKED_MONEY_UPDATE , OnBankedMoneyUpdate)

    ---------------------------------------------------------------------------------------------------------------------------
    --P5YCH3 - New chat/console commands and functions.
    ---------------------------------------------------------------------------------------------------------------------------
    SLASH_COMMANDS["/goldledger"] = function()
        self:Toggle()
    end

    SLASH_COMMANDS["/gl"] = function()
        self:Toggle()
    end

    SLASH_COMMANDS["/ledger"] = function()
        self:Toggle()
    end

    SLASH_COMMANDS["/l"] = function()
        self:Toggle()
    end

    SLASH_COMMANDS["/gls"] = function()
        self.ShowAddonSettingsMenu()
    end
    ---------------------------------------------------------------------------------------------------------------------------

    self:Refresh()
end

function GoldLedger:SetupPeriodComboBox()
    self.periodComboBox = Ledger_SetupComboBox(self, "OptionsPeriodComboBox")

    local selectedIndex = 1

    local options =
    {
        [1] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_HOUR),
            value = 3600, --3600 seconds = 1 hour.
        },
        [2] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_DAY),
            value = 3600 * 24, --1 hour x 24 = 1 day.
        },
        [3] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_WEEK),
            value = 3600 * 24 * 7, --1 hour x 24 = 1 day x 7 = 1 week
        },
        [4] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_MONTH),
            value = 3600 * 24 * 30, --1 hour x 24 = 1 day x 30 = 1 month
        },
        [5] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_QUARTER),
            value = 3600 * 24 * 30 * 3, --1 hour x 24 = 1 day x 30 = 1 month x 3 = 3 months or 1 business quarter year
        },
        [6] =
        {
            label = GetString(SI_GOLD_LEDGER_PERIOD_1_YEAR),
            value = 3600 * 24 * 30 * 12, --1 hour x 24 = 1 day x 30 = 1 month x 12 = 1 year
        },
    }

    for i = 1, #options do
        local item = self.periodComboBox:CreateItemEntry(options[i].label, function()
            self.savedVars.options.selectedPeriod = options[i].value --Use the value of the selected time period to determine what data to present within the table.
            self:Refresh()
        end)

        self.periodComboBox:AddItem(item) --Add each 'item' returned from the function above to 'periodComboBox'.

        if self.savedVars.options.selectedPeriod == options[i].value then
            selectedIndex = i
        end
    end

    self.periodComboBox:SelectItemByIndex(selectedIndex)
end

function GoldLedger:SetupCharacterComboBox()
    self.characterComboBox = Ledger_SetupComboBox(self, "OptionsCharacterComboBox")

    local selectedIndex = 1

    local options =
    {
        [1] =
        {
            label = GetString(SI_GOLD_LEDGER_ALL_CHARACTERS),
            value = nil,
        },
        [2] =
        {
            label = GetString(SI_GOLD_LEDGER_BANK_CHARACTER),
            value = "bank",
        }
    }

    for i = 1, #self.savedVars.charactersList do
        local option =
        {
            label = self.savedVars.charactersList[i],
            value = self.savedVars.charactersList[i],
        }

        table.insert(options, option)
    end

    for i = 1, #options do
        local item = self.characterComboBox:CreateItemEntry(options[i].label, function()
            self.savedVars.options.selectedCharacter = options[i].value
            self:Refresh()
        end)

        self.characterComboBox:AddItem(item)

        if self.savedVars.options.selectedCharacter == options[i].value then
            selectedIndex = i
        end
    end

    self.characterComboBox:SelectItemByIndex(selectedIndex)
end

function GoldLedger:Refresh()
    if not self.sceneFragment:IsHidden() then
        self:RefreshData()
        self:RefreshSummary()
    end

    ---------------------------------------------------------------------------------------------------------------------------
    --P5YCH3 - New variables to update the button text for the new bagged gold and banked gold displays.
    ---------------------------------------------------------------------------------------------------------------------------
    local currentBagGold = GoldLedger.BagBalance()
    local currentBankGold = GoldLedger.BankBalance()
    LedgerCurrentBagBalanceButton:SetText(currentBagGold)
    LedgerCurrentBankBalanceButton:SetText(currentBankGold)
end

function GoldLedger:RefreshSummary()
    local scrollData = ZO_ScrollList_GetDataList(self.list)

    local isBankSelected = (self.savedVars.options.selectedCharacter == "bank")

    if #scrollData > 0 then
        local variationByPeriod = 0
        local variationsByReason = {}

        for i = 1, #scrollData do
            local data = scrollData[i].data

            local isBankDeposit = (data.reason == CURRENCY_CHANGE_REASON_BANK_DEPOSIT)
            local isBankWithdrawal = (data.reason == CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL)

            local isActuallyIncomeOrExpense = not (isBankDeposit or isBankWithdrawal)
            if isBankSelected then
                isActuallyIncomeOrExpense = true
            end

            if isActuallyIncomeOrExpense then
                variationByPeriod = variationByPeriod + data.variation
            end

            if variationsByReason[data.reason] then
                variationsByReason[data.reason] = variationsByReason[data.reason] + data.variation
            else
                variationsByReason[data.reason] = data.variation
            end
        end

        variationsByReason[CURRENCY_CHANGE_REASON_BANK_DEPOSIT] = nil
        variationsByReason[CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL] = nil

        local largestExpenseVariation = 0
        local largestExpenseReason
        local largestProfitVariation = 0
        local largestProfitReason

        for reason, variation in pairs(variationsByReason) do
            if variation > largestProfitVariation then
                largestProfitVariation = variation
                largestProfitReason = reason
            end

            if variation < largestExpenseVariation then
                largestExpenseVariation = variation
                largestExpenseReason = reason
            end
        end

        local t =
        {
            Ledger_FormatCurrencyVariation(variationByPeriod),
            ZO_DEFAULT_ENABLED_COLOR:Colorize(self.periodComboBox:GetSelectedItem()),
        }

        local summary1 = zo_strformat(GetString("SI_GOLD_LEDGER_SUMMARY", 1), unpack(t))
        local summary2 = ""

        if largestExpenseReason and largestProfitReason then
            t =
            {
                ZO_DEFAULT_ENABLED_COLOR:Colorize(GetString("SI_GOLD_LEDGER_REASON", largestProfitReason)),
                Ledger_FormatCurrencyVariation(largestProfitVariation),
                ZO_DEFAULT_ENABLED_COLOR:Colorize(GetString("SI_GOLD_LEDGER_REASON", largestExpenseReason)),
                Ledger_FormatCurrencyVariation(largestExpenseVariation),
            }

            summary2 = zo_strformat(GetString("SI_GOLD_LEDGER_SUMMARY", 2), unpack(t))
        elseif largestExpenseReason then
            t =
            {
                ZO_DEFAULT_ENABLED_COLOR:Colorize(GetString("SI_GOLD_LEDGER_REASON", largestExpenseReason)),
                Ledger_FormatCurrencyVariation(largestExpenseVariation),
            }

            summary2 = zo_strformat(GetString(SI_GOLD_LEDGER_SUMMARY2_EXPENSE), unpack(t))
        elseif largestProfitReason then
            t =
            {
                ZO_DEFAULT_ENABLED_COLOR:Colorize(GetString("SI_GOLD_LEDGER_REASON", largestProfitReason)),
                Ledger_FormatCurrencyVariation(largestProfitVariation),
            }

            summary2 = zo_strformat(GetString(SI_GOLD_LEDGER_SUMMARY2_PROFIT), unpack(t))
        end

        self.summaryLabel:SetText(zo_strjoin(" ", summary1, summary2))
    else
        self.summaryLabel:SetText(GetString(SI_GOLD_LEDGER_SUMMARY_EMPTY))
    end
end

function GoldLedger:BuildMasterList()
    self.masterList = {}

    local t = {}
    local threshold = GetTimeStamp() - self.savedVars.options.selectedPeriod

    for i = #self.savedVars.masterList, 1, -1 do
        local entry = self.savedVars.masterList[i]

        if entry.timestamp >= threshold then
            table.insert(t, ZO_ShallowTableCopy(entry))
        else
            break
        end
    end

    for i = #t, 1, -1 do
        table.insert(self.masterList, t[i])
    end
end

function GoldLedger:FilterScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

    local previousEntry

    for i = 1, #self.masterList do
        currentEntry = self.masterList[i]

        local matchSelectedCharacter = (currentEntry.character == self.savedVars.options.selectedCharacter)
        local matchSearchQuery = true
        if (#self.savedVars.options.searchQuery > 0) then
            local reason = string.lower(GetString("SI_GOLD_LEDGER_REASON", currentEntry.reason))
            local query = string.lower(self.savedVars.options.searchQuery)
            matchSearchQuery = string.find(reason, query, 0, true)
        end

        if (matchSearchQuery) and (not self.savedVars.options.selectedCharacter or matchSelectedCharacter) then
            if (not self.savedVars.options.shouldMerge) or (self.savedVars.options.shouldMerge and not previousEntry) then
                table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, currentEntry))
                previousEntry = currentEntry
            else
                local isSameCharacter = currentEntry.character == previousEntry.character
                local isSameReason = currentEntry.reason == previousEntry.reason

                if (isSameReason and isSameCharacter) then
                    previousEntry.mergeCount = (previousEntry.mergeCount or 1) + 1
                    previousEntry.variation = previousEntry.variation + currentEntry.variation
                    previousEntry.balance = currentEntry.balance
                else
                    table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, currentEntry))
                    previousEntry = currentEntry
                end
            end
        end
    end
end

function GoldLedger:SortScrollList()
    local scrollData = ZO_ScrollList_GetDataList(self.list)
    table.sort(scrollData, function(...) return self:CompareRows(...) end)
end

local sortKeys =
{
    timestamp =
    {
        isNumeric = true
    },
    character =
    {
        caseInsensitive = true,
        tiebreaker = "timestamp"
    },
    reason =
    {
        caseInsensitive = true,
        tiebreaker = "timestamp"
    },
    variation =
    {
        isNumeric = true,
        tiebreaker = "timestamp"
    },
    balance =
    {
        isNumeric = true,
        tiebreaker = "timestamp"
    },
}

function GoldLedger:CompareRows(row1, row2)
    return ZO_TableOrderingFunction(row1.data, row2.data, self.currentSortKey, sortKeys, self.currentSortOrder)
end

function GoldLedger:GetRowColors()
end

function GoldLedger:SetupRow(control, data)
    ZO_SortFilterList.SetupRow(self, control, data)

    local formattedDateTime = TimeFunctions_GetLocalizedDateTime(data.timestamp)

    local reasonDescription = GetString("SI_GOLD_LEDGER_REASON", data.reason)
    if data.mergeCount and (data.mergeCount > 0) then
        reasonDescription = reasonDescription..string.format(" (%d)", data.mergeCount)
    end

    local characterName = data.character
    if characterName == "bank" then
        characterName = GetString(SI_GOLD_LEDGER_BANK_CHARACTER)
    end

    GetControl(control, "Timestamp"):SetText(formattedDateTime)
    GetControl(control, "Character"):SetText(characterName)
    GetControl(control, "Reason"):SetText(reasonDescription)
    GetControl(control, "Variation"):SetText(Ledger_FormatCurrencyVariation(data.variation))
    GetControl(control, "Balance"):SetText(ZO_CurrencyControl_FormatCurrency(data.balance))
end

function GoldLedger:RefreshScrollListHeight()
    ZO_ScrollList_SetHeight(self.list, self.list:GetHeight())
    ZO_ScrollList_Commit(self.list)
end

function GoldLedger:Toggle()
    if self.sceneFragment:IsHidden() then
        self.sceneFragment:SetHiddenForReason("hidden", false)
        self.control:BringWindowToTop()
        SCENE_MANAGER:Show('hudui') --P5YCH3 - Added to ensure that the window gets shown, even if the command is run within another window.
        SCENE_MANAGER:SetInUIMode(true) -- This comes after the fact to make sure the cursor is active.
    else
        self.sceneFragment:SetHiddenForReason("hidden", true)
        SCENE_MANAGER:SetInUIMode(false)
    end
end

local defaultSavedVars =
{
    ["masterList"] = {},
    ["charactersList"] = {},
    ["isHidden"] = false,
    ["x"] = 980,
    ["y"] = 320,
    ---------------------------------------------------------------------------------------------------------------------------
    --P5YCH3 - New default values.
    ---------------------------------------------------------------------------------------------------------------------------
    ["IconShownInsideInventory"] = true,
    ["BankerButtonHidesMainWindow"] = true,
    ["BankerButtonAssistantSelection"] = "Tythis Andromo",
    ["MerchantButtonAssistantSelection"] = "Nuzhimeh the Merchant",
    ["GoldLedgerInventoryButton_left"] = 0,
    ["GoldLedgerInventoryButton_top"] = 0,
    ---------------------------------------------------------------------------------------------------------------------------
    ["offsetX"] = 0,
    ["offsetY"] = 0,
    ["options"] =
    {
        ["searchQuery"] = "",
        ["shouldMerge"] = true,
        ["selectedPeriod"] = 3600,
        ["selectedCharacter"] = nil
    }
}

---------------------------------------------------------------------------------------------------------------------------
--P5YCH3 - New settings panel functions.
---------------------------------------------------------------------------------------------------------------------------
function GoldLedger.InitializeOptions()
	-- LibAddonMenu Version 2.0
	local panelData = {
				type = "panel",
				name = "Gold Ledger",
                displayName = "|cFFC814" .. "Gold Ledger" .. "|r", --Gold header title
                author = goldledger.authorAccount .. ", " .. ledger.authorAccount,
				website = GOLD_LEDGER_ADDON_WEBSITE,
				feedback = GOLD_LEDGER_FEEDBACK_WEBSITE,
				version = goldledger.version,
				registerForRefresh = true,
				registerForDefaults = true}
	local optionsData={
            [1]={
                type = "button",
                name = GetString(SI_GOLD_LEDGER_VIEW_LEDGER_BUTTON),
                tooltip = GetString(SI_GOLD_LEDGER_VIEW_LEDGER_BUTTON_TOOLTIP),
                func = function() SCENE_MANAGER:Show('hudui') GOLD_LEDGER:Toggle() end,
                width = "half"
                },
            [2]={
                type = "button",
                name = GetString(SI_GOLD_LEDGER_VIEW_INVENTORY_BUTTON),
                tooltip = GetString(SI_GOLD_LEDGER_VIEW_INVENTORY_BUTTON_TOOLTIP),
                func = function() SCENE_MANAGER:Show('inventory') end,
                width = "half"
                },
			[3]={ --P5YCH3 - New settings option to show / hide Gold Ledger icon within inventory menu.
				type="checkbox",
				name=GetString(SI_GOLD_LEDGER_SHOW_INVENTORY_OPTION),
                tooltip = GetString(SI_GOLD_LEDGER_SHOW_INVENTORY_OPTION_TOOLTIP),
				getFunc=function() return GoldLedger.savedVars.IconShownInsideInventory end,
				setFunc=function(newValue) GoldLedger.savedVars.IconShownInsideInventory=newValue if newValue == false then GoldLedgerInventoryButton:SetHidden(true) GoldLedgerInventoryButtonControl:SetHidden(true) end end,
				default=defaultSavedVars.IconShownInsideInventory,
                },
			[4]={ --P5YCH3 - New settings option to show / hide Gold Ledger window when spawning a personal banker.
				type="checkbox",
				name=GetString(SI_GOLD_LEDGER_BANKER_HIDE_WINDOW_OPTION),
                tooltip = GetString(SI_GOLD_LEDGER_BANKER_HIDE_WINDOW_TOOLTIP),
				getFunc=function() return GoldLedger.savedVars.BankerButtonHidesMainWindow end,
				setFunc=function(newValue) GoldLedger.savedVars.BankerButtonHidesMainWindow=newValue end,
				default=defaultSavedVars.BankerButtonHidesMainWindow,
                },
			[5] = { --P5YCH3 - New settings option to select which banker is preferred.
				type="dropdown",
				name=GetString(SI_GOLD_LEDGER_BANKER_ASSISTANT),
				tooltip=GetString(SI_GOLD_LEDGER_BANKER_ASSISTANT_TOOLTIP),
				choices={"Tythis Andromo", "Ezabi", "Baron Jangleplume", "Factotum Property Steward", "Pyroclast, Infernace Conservator"},
				getFunc=function() return GoldLedger.savedVars.BankerButtonAssistantSelection end,
				setFunc=function(value) GoldLedger.savedVars.BankerButtonAssistantSelection=value end,
				default=defaultSavedVars.BankerButtonAssistantSelection
				},
			[6] = { --P5YCH3 - New settings option to select which merchant is preferred.
				type="dropdown",
				name=GetString(SI_GOLD_LEDGER_MERCHANT_ASSISTANT),
				tooltip=GetString(SI_GOLD_LEDGER_MERCHANT_ASSISTANT_TOOLTIP),
				choices={"Nuzhimeh the Merchant", "Fezez the Merchant", "Peddler of Prizes, the Merchant", "Factotum Commerce Delegate", "Hoarfrost, Takubar Trader"},
				getFunc=function() return GoldLedger.savedVars.MerchantButtonAssistantSelection end,
				setFunc=function(value) GoldLedger.savedVars.MerchantButtonAssistantSelection=value end,
				default=defaultSavedVars.MerchantButtonAssistantSelection
				},
            ---------------------------------------------------------------------------------------------
            --P5YCH3 - New submenu for all addon console commands.
            ---------------------------------------------------------------------------------------------
            [7]={
				type = "submenu",
				name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_GOLD_LEDGER_CONSOLE_COMMANDS)), -- Console Commands
				controls =
					{
						{
						type = "header",
						name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_GOLD_LEDGER_FUNCTIONS_HEADER)), -- Gold Ledger - Functions
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/goldledger") .. " - " .. GetString(SI_GOLD_LEDGER_COMMAND_GOLD_LEDGER)
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/gl") .. " - " .. GetString(SI_GOLD_LEDGER_COMMAND_GOLD_LEDGER_SHORT)
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/ledger") .. " - " .. GetString(SI_GOLD_LEDGER_COMMAND_LEDGER)
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/l") .. " - " .. GetString(SI_GOLD_LEDGER_COMMAND_LEDGER_SHORT) .. "\n"
						},
						{
						type = "header",
						name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_GOLD_LEDGER_SETTINGS_HEADER)), -- Gold Ledger - Settings (This Menu)
						},
						{
						type = "description",
						text = ZO_HIGHLIGHT_TEXT:Colorize("/gls") .. " - " .. GetString(SI_GOLD_LEDGER_COMMAND_LEDGER_SETTINGS) .. "\n"
						},
					}
				},
			}
    -------------------------------------------------------------------
    -- P5YCH3 -- LAM2 Variables.
    -------------------------------------------------------------------
	GoldLedgerAddonPanel = LibAddonMenu2:RegisterAddonPanel("GoldLedgerConfig", panelData) 
	LibAddonMenu2:RegisterOptionControls("GoldLedgerConfig", optionsData)
end

----------------------------------------------------
--P5YCH3 - Brand new tooltip functions/variables.
----------------------------------------------------
function GoldLedger.ShowTooltip(self,tooltipText)
	if self:GetAlpha()~=0 then
		InitializeTooltip(InformationTooltip,self,TOPRIGHT,0,5,BOTTOMRIGHT)
		SetTooltipText(InformationTooltip,tooltipText)
	end
end

------------------------------------------------
-- P5YCH3 - New addon panel functions.
------------------------------------------------
function GoldLedger.ShowAddonSettingsMenu()
	LibAddonMenu2:OpenToPanel(GoldLedgerAddonPanel)
end

------------------------------------------------
-- P5YCH3 - New currency functions.
------------------------------------------------
function GoldLedger.BagBalance()
    local currencyInBag = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
    local character = GetUnitName("player")

    return ZO_CurrencyControl_FormatCurrency(zo_abs(currencyInBag))
end

function GoldLedger.BankBalance()
    local currencyInBank = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK)
    local character = GetUnitName("player")

    return ZO_CurrencyControl_FormatCurrency(zo_abs(currencyInBank))
end

--------------------------------------------------------------------------------------------------
-- P5YCH3 - New collectible/assistant functions.
-- Bankers
--------------------------------------------------------------------------------------------------
--Tythis Andromo the Banker (Dark Elf) | 267
--Ezabi the Banker (Alfiq) | 6376
--Baron Jangleplume (Crow) | 8994
--Factotum Property Steward | 9743
--Pyroclast, Infernace Conservator (Fire Atronach) | 11097

function GoldLedger.SpawnBanker()
    -------------------------------------------------
    --Tythis Andromo (Dark Elf)
    -------------------------------------------------
    if GoldLedger.savedVars.BankerButtonAssistantSelection == "Tythis Andromo" then
        if GetCollectibleUnlockStateById(267) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(267) -- Tythis Andromo (Dark Elf)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_TOGGLED_TYTHIS))
        else
            UseCollectible(267) -- Tythis Andromo (Dark Elf)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_UNAVAILABLE_TYTHIS))
            ------------------------------
            --Ezabi the Banker (Alfiq)
            if GetCollectibleUnlockStateById(6376) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(6376)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_EZABI))
            else
                --Baron Jangleplume the Banker (Crow)
                if GetCollectibleUnlockStateById(8994) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(8994)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_JANGLEPLUME))
                else
                    --Factotum Property Steward
                    if GetCollectibleUnlockStateById(9743) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9743)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_FACTOTUM))
                    else
                        --Pyroclast, Infernace Conservator (Fire Atronach)
                        if GetCollectibleUnlockStateById(11097) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11097)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_PYROCLAST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Ezabi the Banker (Alfiq)
    -------------------------------------------------
    if GoldLedger.savedVars.BankerButtonAssistantSelection == "Ezabi" then
        if GetCollectibleUnlockStateById(6376) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(6376) --Ezabi the Banker (Alfiq)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_TOGGLED_EZABI))
        else
            UseCollectible(6376) --Ezabi the Banker (Alfiq)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_UNAVAILABLE_EZABI))

            ------------------------------
            --Tythis Andromo the Banker (Dark Elf)
            if GetCollectibleUnlockStateById(267) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(267)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_TYTHIS))
            else
                --Baron Jangleplume the Banker (Crow)
                if GetCollectibleUnlockStateById(8994) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(8994)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_JANGLEPLUME))
                else
                    --Factotum Property Steward
                    if GetCollectibleUnlockStateById(9743) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9743)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_FACTOTUM))
                    else
                        --Pyroclast, Infernace Conservator (Fire Atronach)
                        if GetCollectibleUnlockStateById(11097) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11097)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_PYROCLAST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Baron Jangleplume the Banker (Crow)
    -------------------------------------------------
    if GoldLedger.savedVars.BankerButtonAssistantSelection == "Baron Jangleplume" then
        if GetCollectibleUnlockStateById(8994) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(8994) -- Baron Jangleplume the Banker (Crow)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_TOGGLED_JANGLEPLUME))
        else
            UseCollectible(8994) -- Baron Jangleplume the Banker (Crow)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_UNAVAILABLE_JANGLEPLUME))

            ------------------------------
            --Tythis Andromo the Banker (Dark Elf)
            if GetCollectibleUnlockStateById(267) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(267)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_TYTHIS))
            else
                --Ezabi the Banker (Alfiq)
                if GetCollectibleUnlockStateById(6376) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6376) 
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_EZABI))
                else
                    --Factotum Property Steward
                    if GetCollectibleUnlockStateById(9743) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9743)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_FACTOTUM))
                    else
                        --Pyroclast, Infernace Conservator (Fire Atronach)
                        if GetCollectibleUnlockStateById(11097) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11097)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_PYROCLAST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Factotum Property Steward
    -------------------------------------------------
    if GoldLedger.savedVars.BankerButtonAssistantSelection == "Factotum Property Steward" then
        if GetCollectibleUnlockStateById(9743) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(9743) -- Factotum Property Steward
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_TOGGLED_FACTOTUM))
        else
            UseCollectible(9743) -- Factotum Property Steward
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_UNAVAILABLE_FACTOTUM))

            ------------------------------
            --Tythis Andromo the Banker (Dark Elf)
            if GetCollectibleUnlockStateById(267) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(267)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_TYTHIS))
            else
                --Ezabi the Banker (Alfiq)
                if GetCollectibleUnlockStateById(6376) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6376) 
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_EZABI))
                else
                    --Baron Jangleplume the Banker (Crow)
                    if GetCollectibleUnlockStateById(8994) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(8994)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_JANGLEPLUME))
                    else
                        --Pyroclast, Infernace Conservator (Fire Atronach)
                        if GetCollectibleUnlockStateById(11097) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11097)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_PYROCLAST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Pyroclast, Infernace Conservator (Fire Atronach)
    -------------------------------------------------
    if GoldLedger.savedVars.BankerButtonAssistantSelection == "Pyroclast, Infernace Conservator" then
        if GetCollectibleUnlockStateById(11097) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(11097) -- Pyroclast, Infernace Conservator
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_TOGGLED_PYROCLAST))
        else
            UseCollectible(971109743) -- Pyroclast, Infernace Conservator
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_UNAVAILABLE_PYROCLAST))

            ------------------------------
            --Tythis Andromo the Banker (Dark Elf)
            if GetCollectibleUnlockStateById(267) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(267)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_TYTHIS))
            else
                --Ezabi the Banker (Alfiq)
                if GetCollectibleUnlockStateById(6376) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6376) 
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_EZABI))
                else
                    --Baron Jangleplume the Banker (Crow)
                    if GetCollectibleUnlockStateById(8994) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(8994)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_JANGLEPLUME))
                    else
                        --Factotum Property Steward
                        if GetCollectibleUnlockStateById(9743) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(9743)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_BANKER_ALTERNATIVE_FACTOTUM))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end
end

function GoldLedger.SpawnMerchant()
--------------------------------------------------------------------------------------------------
-- P5YCH3 - New collectible/assistant functions.
-- Merchant
--------------------------------------------------------------------------------------------------
--Nuzhimeh the Merchant (Redguard) | 301
--Fezez the Merchant (Alfiq) | 6378
--Peddler of Prizes, the Merchant (Crow) | 8995
--Factotum Commerce Delegate | 9744
--Hoarfrost, Takubar Trader (Elemental) | 11059

    -------------------------------------------------
    --Nuzhimeh the Merchant (Redguard)
    -------------------------------------------------
    if GoldLedger.savedVars.MerchantButtonAssistantSelection == "Nuzhimeh the Merchant" then
        if GetCollectibleUnlockStateById(301) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(301) -- Nuzhimeh the Merchant (Redguard)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_TOGGLED_NUZHIMEH))
        else
            UseCollectible(301) -- Nuzhimeh the Merchant (Redguard)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_UNAVAILABLE_NUZHIMEH))
            ------------------------------
            --Fezez the Merchant (Alfiq)
            if GetCollectibleUnlockStateById(6378) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(6378)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FEZEZ))
            else
                --Peddler of Prizes, the Merchant (Crow)
                if GetCollectibleUnlockStateById(8995) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(8995)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_PEDDLER))
                else
                    --Factotum Commerce Delegate
                    if GetCollectibleUnlockStateById(9744) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9744)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FACTOTEM))
                    else
                        --Hoarfrost, Takubar Trader (Elemental)
                        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11059)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_HOARFROST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Fezez the Merchant (Alfiq)
    -------------------------------------------------
    if GoldLedger.savedVars.MerchantButtonAssistantSelection == "Fezez the Merchant" then
        if GetCollectibleUnlockStateById(6378) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(6378) -- Fezez the Merchant (Alfiq)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_TOGGLED_FEZEZ))
        else
            UseCollectible(6378) -- Fezez the Merchant (Alfiq)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_UNAVAILABLE_FEZEZ))
            ------------------------------
            --Nuzhimeh the Merchant (Redguard)
            if GetCollectibleUnlockStateById(301) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(301)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_NUZHIMEH))
            else
                --Peddler of Prizes, the Merchant (Crow)
                if GetCollectibleUnlockStateById(8995) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(8995)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_PEDDLER))
                else
                    --Factotum Commerce Delegate
                    if GetCollectibleUnlockStateById(9744) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9744)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FACTOTEM))
                    else
                        --Hoarfrost, Takubar Trader (Elemental)
                        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11059)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_HOARFROST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Peddler of Prizes, the Merchant (Crow)
    -------------------------------------------------
    if GoldLedger.savedVars.MerchantButtonAssistantSelection == "Peddler of Prizes, the Merchant" then
        if GetCollectibleUnlockStateById(8995) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(8995) -- Peddler of Prizes, the Merchant (Crow)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_TOGGLED_PEDDLER))
        else
            UseCollectible(8995) -- Peddler of Prizes, the Merchant (Crow)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_UNAVAILABLE_PEDDLER))
            ------------------------------
            --Nuzhimeh the Merchant (Redguard)
            if GetCollectibleUnlockStateById(301) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(301)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_NUZHIMEH))
            else
                --Fezez the Merchant (Alfiq)
                if GetCollectibleUnlockStateById(6378) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6378)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FEZEZ))
                else
                    --Factotum Commerce Delegate
                    if GetCollectibleUnlockStateById(9744) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(9744)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FACTOTEM))
                    else
                        --Hoarfrost, Takubar Trader (Elemental)
                        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11059)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_HOARFROST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Factotum Commerce Delegate
    -------------------------------------------------
    if GoldLedger.savedVars.MerchantButtonAssistantSelection == "Factotum Commerce Delegate" then
        if GetCollectibleUnlockStateById(9744) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(9744) -- Factotum Commerce Delegate
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_TOGGLED_FACTOTEM))
        else
            UseCollectible(9744) -- Factotum Commerce Delegate
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_UNAVAILABLE_FACTOTEM))
            ------------------------------
            --Nuzhimeh the Merchant (Redguard)
            if GetCollectibleUnlockStateById(301) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(301)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_NUZHIMEH))
            else
                --Fezez the Merchant (Alfiq)
                if GetCollectibleUnlockStateById(6378) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6378)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FEZEZ))
                else
                    --Peddler of Prizes, the Merchant
                    if GetCollectibleUnlockStateById(8995) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(8995)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_PEDDLER))
                    else
                        --Hoarfrost, Takubar Trader (Elemental)
                        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11059)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_HOARFROST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end

    -------------------------------------------------
    --Hoarfrost, Takubar Trader (Elemental)
    -------------------------------------------------
    if GoldLedger.savedVars.MerchantButtonAssistantSelection == "Hoarfrost, Takubar Trader" then
        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
            UseCollectible(11059) -- Hoarfrost, Takubar Trader (Elemental)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_TOGGLED_HOARFROST))
        else
            UseCollectible(11059) -- Hoarfrost, Takubar Trader (Elemental)
            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_UNAVAILABLE_HOARFROST))
            ------------------------------
            --Nuzhimeh the Merchant (Redguard)
            if GetCollectibleUnlockStateById(301) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                UseCollectible(301)
                CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_NUZHIMEH))
            else
                --Fezez the Merchant (Alfiq)
                if GetCollectibleUnlockStateById(6378) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                    UseCollectible(6378)
                    CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_FEZEZ))
                else
                    --Peddler of Prizes, the Merchant
                    if GetCollectibleUnlockStateById(8995) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                        UseCollectible(8995)
                        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_PEDDLER))
                    else
                        --Hoarfrost, Takubar Trader (Elemental)
                        if GetCollectibleUnlockStateById(11059) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
                            UseCollectible(11059)
                            CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_MERCHANT_ALTERNATIVE_HOARFROST))
                        end
                    end
                end
            end
            ------------------------------
        end
        if GoldLedger.savedVars.BankerButtonHidesMainWindow == true then
            GOLD_LEDGER:Toggle()
        end
    end
------------------------------
end
-----------------------------------------------------------------------
-- P5YCH3 - New function for the fence assistant.
-----------------------------------------------------------------------
function GoldLedger.SpawnFence()
    if GetCollectibleUnlockStateById(300) == COLLECTIBLE_UNLOCK_STATE_UNLOCKED_OWNED then
	    UseCollectible(300) -- Fence
        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_FENCE_TOGGLED_PIRHARRI))
    else
        CHAT_SYSTEM:AddMessage(GetString(SI_GOLD_LEDGER_FENCE_UNAVAILABLE_PIRHARRI))
    end
end

-----------------------------------------------------
--P5YCH3 - New initialization functions/variables.
-----------------------------------------------------
function GoldLedger_OnInitialized(control)
    EVENT_MANAGER:RegisterForEvent(GOLD_LEDGER, EVENT_ADD_ON_LOADED, function(event, addonName)
        if (addonName == GOLD_LEDGER) then
            EVENT_MANAGER:UnregisterForEvent(GOLD_LEDGER, EVENT_ADD_ON_LOADED)

            --------------------------------------------------------------------------------------------------------
            -- Fetch the saved variables and replace and nil values with data from the defaultSavedVars table.
            --------------------------------------------------------------------------------------------------------
            GoldLedger.savedVars = ZO_SavedVars:NewAccountWide("GoldLedgerSavedVars", 1, nil, defaultSavedVars)
            GOLD_LEDGER = GoldLedger:New(control, GoldLedger.savedVars)

            -------------------------------------------------------------------
            -- P5YCH3 -- Variables for the addon settings menu.
            -------------------------------------------------------------------
            ledger.authorAccount="haggen"
            goldledger.authorAccount="|c4779ce" .. "P5YCH3" .. "|r"
            goldledger.authorAccount_InGameName="P5YCH3"
            GoldLedger.InitializeOptions()
            goldledger.loaded=true

            -------------------------------------------------------------------
            -- P5YCH3 -- Variables and functions for the UI window.
            -------------------------------------------------------------------
            LedgerTitleIcon:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,GetString(SI_GOLD_LEDGER_ICON_TOOLTIP)) end) --P5YCH3 - Updated the main window gold icon tooltip.
            LedgerTitleIcon:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
            LedgerTitleIcon:SetHandler("OnMouseUp", function(self,button) if button == 3 then GoldLedger.ShowAddonSettingsMenu() elseif button == MOUSE_BUTTON_INDEX_RIGHT then SCENE_MANAGER:Show('inventory') end end)

            LedgerOpenInventoryButton:SetText(GetString(SI_GOLD_LEDGER_MAIN_WINDOW_INVENTORY_BUTTON))
            LedgerOpenInventoryButton:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,GetString(SI_GOLD_LEDGER_MAIN_WINDOW_INVENTORY_BUTTON_TOOLTIP)) end)
            LedgerOpenInventoryButton:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

            LedgerOpenSettingsButton:SetText(GetString(SI_GOLD_LEDGER_MAIN_WINDOW_SETTINGS_BUTTON))
            LedgerOpenSettingsButton:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,GetString(SI_GOLD_LEDGER_MAIN_WINDOW_SETTINGS_BUTTON_TOOLTIP)) end)
            LedgerOpenSettingsButton:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

            LedgerCurrentBankBalanceButton:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,GetString(SI_GOLD_LEDGER_CURRENT_BANK_BALANCE_TOOLTIP)) end)
            LedgerCurrentBankBalanceButton:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

            LedgerCurrentBagBalanceButton:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,GetString(SI_GOLD_LEDGER_CURRENT_BAG_BALANCE_TOOLTIP)) end)
            LedgerCurrentBagBalanceButton:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)

            local currentBagGold = GoldLedger.BagBalance()
            local currentBankGold = GoldLedger.BankBalance()

            LedgerCurrentBagBalanceButton:SetText(currentBagGold)
            LedgerCurrentBankBalanceButton:SetText(currentBankGold)

            --------------------------------------------------------------------------------------------------
            -- P5YCH3 -- Add the Gold Ledger button to the inventory menu interface (if enabled via settings).
            --------------------------------------------------------------------------------------------------
            local GoldLedgerInventoryButtonFragment = ZO_SimpleSceneFragment:New(GoldLedgerInventoryButton)
            local Inventory_Window = SCENE_MANAGER:GetScene("inventory")
            local Inventory_Window_Tooltip = GetString(SI_GOLD_LEDGER_INVENTORY_ICON_TOOLTIP)

            --------------------------------------------------------------------------------------------------
            -- P5YCH3 -- Inventory button behavior.
            --------------------------------------------------------------------------------------------------
            if GoldLedger.savedVars.IconShownInsideInventory == true then
                Inventory_Window:AddFragment(GoldLedgerInventoryButtonFragment)
            else
                Inventory_Window:RemoveFragment(GoldLedgerInventoryButtonFragment)
            end

            GoldLedgerInventoryButtonControl:SetHandler("OnMouseEnter", function(self) GoldLedger.ShowTooltip(self,Inventory_Window_Tooltip) end)
            GoldLedgerInventoryButtonControl:SetHandler("OnMouseExit", function(self) ClearTooltip(InformationTooltip) end)
            GoldLedgerInventoryButtonControl:SetHandler("OnMouseUp", function(self,button)
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    SCENE_MANAGER:Show('hudui') GOLD_LEDGER:Toggle()
                    GOLD_LEDGER.RestorePosition()
                elseif button == 2 then
                    GOLD_LEDGER.OnInventoryButtonMoveStop()
                elseif button == 3 then
                    GoldLedger.ShowAddonSettingsMenu()
                    GoldLedger.RestorePosition()
                end
            end)

            if (GoldLedger.savedVars == nil) then  
                GoldLedger.savedVars = self.defaultSavedVars
            end

            GoldLedger.RestorePosition()
        end
    end)
end

--------------------------------------------------------------------------------
--P5YCH3 - New function to refresh the UI on demand. Runs after initialization.
--------------------------------------------------------------------------------
function GoldLedger.RestorePosition()
    -----------------------------------------------------------------------------------------------------------------------------
    -- P5YCH3 - Saved variable integrity checks for settings options.
    -----------------------------------------------------------------------------------------------------------------------------
    if (GoldLedger.savedVars.IconShownInsideInventory == 0 or GoldLedger.savedVars.IconShownInsideInventory == nil) then
        GoldLedger.savedVars.IconShownInsideInventory = self.defaultSavedVars.IconShownInsideInventory
    end

    -----------------------------------------------------------------------------------------------------------------------------
    -- P5YCH3 - SCENE_MANAGER handling for UI controls.
    -----------------------------------------------------------------------------------------------------------------------------
    -- Checks for 'inventory' UI state and if not present, then hide the Gold Ledger button UI.
    if not SCENE_MANAGER:IsShowing("inventory") then
        GoldLedgerInventoryButton:SetHidden(true)
        GoldLedgerInventoryButtonControl:SetHidden(true)
    end

    -----------------------------------------------------------------------------------------------------------------------------
    -- P5YCH3 - Saved variable integrity checks for inventory button position.
    -----------------------------------------------------------------------------------------------------------------------------
    local GoldLedgerInventoryButton_left = GoldLedger.savedVars.GoldLedgerInventoryButton_left
    local GoldLedgerInventoryButton_top = GoldLedger.savedVars.GoldLedgerInventoryButton_top
    local centerscreen = GuiRoot:GetCenter()

    if (GoldLedgerInventoryButton_left == 0 or GoldLedgerInventoryButton_left == nil) then
        GoldLedgerInventoryButtonControl:ClearAnchors()
        GoldLedgerInventoryButtonControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, centerscreen, centerscreen) --If no previous location is saved, the inventory icon will appear center screen at the bottom of the inventory.
    else
        GoldLedgerInventoryButtonControl:ClearAnchors()
        GoldLedgerInventoryButtonControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GoldLedgerInventoryButton_left, GoldLedgerInventoryButton_top)
    end

    if (GoldLedgerInventoryButton_top == 0 or GoldLedgerInventoryButton_top == nil) then
        GoldLedgerInventoryButtonControl:ClearAnchors()
        GoldLedgerInventoryButtonControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, centerscreen, centerscreen) --If no previous location is saved, the inventory icon will appear center screen at the bottom of the inventory.
    else
        GoldLedgerInventoryButtonControl:ClearAnchors()
        GoldLedgerInventoryButtonControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GoldLedgerInventoryButton_left, GoldLedgerInventoryButton_top)
    end
end

----------------------------------------------------------------------------------------------
--P5YCH3 - New function to track the position of the Gold Ledger button (inventory screen).
----------------------------------------------------------------------------------------------
function GoldLedger.OnInventoryButtonMoveStop()
    GoldLedger.savedVars.GoldLedgerInventoryButton_left = GoldLedgerInventoryButtonControl:GetLeft()
    GoldLedger.savedVars.GoldLedgerInventoryButton_top = GoldLedgerInventoryButtonControl:GetTop()
end

----------------------------------------------------------------------------------------------
--P5YCH3 - New functions and variables for scene management.
----------------------------------------------------------------------------------------------
local function GoldLedger_InventorySceneChange(oldState, newState)
    if (newState == SCENE_SHOWN) then
        if GoldLedger.savedVars.IconShownInsideInventory == true then
            GoldLedgerInventoryButton:SetHidden(false)
            GoldLedgerInventoryButtonControl:SetHidden(false)
        else
            GoldLedgerInventoryButton:SetHidden(true)
            GoldLedgerInventoryButtonControl:SetHidden(true)
        end
    elseif (newState == SCENE_HIDDEN) then
        GoldLedgerInventoryButton:SetHidden(true)
        GoldLedgerInventoryButtonControl:SetHidden(true)
    end
end
 
local inventory_scene = SCENE_MANAGER:GetScene("inventory")
inventory_scene:RegisterCallback("StateChange", GoldLedger_InventorySceneChange)