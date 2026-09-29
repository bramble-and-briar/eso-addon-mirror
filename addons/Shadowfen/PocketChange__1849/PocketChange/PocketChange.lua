local SF = LibSFUtils

local PC=PocketChange

local LOCKPICKS = 101
local REPAIRS = 102
local GEMS=103
local EMPTY_GEMS=104
local MAIN_WEAPON=105
local BKUP_WEAPON=106

-- Define translation array
local ModeArray = {
	["Mode_No"] = GetString(PC_NOPT_NO),
	["Mode_Chat"] = GetString(PC_NOPT_CHAT),
	["Mode_SoundChat"] = GetString(PC_NOPT_BOTH),
	[GetString(PC_NOPT_NO)] = "Mode_No",
	[GetString(PC_NOPT_CHAT)] = "Mode_Chat",
	[GetString(PC_NOPT_BOTH)] = "Mode_SoundChat",
}

local defaults = {
	accountWide = false,
	minimum = {
		[CURT_MONEY] = 2000, 	        -- GD
		[CURT_ALLIANCE_POINTS] = 0, 	-- AP
		[CURT_TELVAR_STONES] = 0, 		-- TV
		[CURT_WRIT_VOUCHERS] = 0, 		-- WV
		[LOCKPICKS] = 100,
		[GEMS]=100,
		[EMPTY_GEMS]=0,
		[REPAIRS]=40,
		[MAIN_WEAPON]=0,
		[BKUP_WEAPON]=0,
	},
	notify = {
		[LOCKPICKS] = "Mode_No",
		[REPAIRS] = "Mode_No",
		[GEMS] = "Mode_No",
		[EMPTY_GEMS] = "Mode_No",
		[MAIN_WEAPON] = "Mode_No",
		[BKUP_WEAPON] = "Mode_No",
    },
	disables = {
        [CURT_MONEY] = false,
        [CURT_ALLIANCE_POINTS] = false,
        [CURT_TELVAR_STONES] = false,
        [CURT_WRIT_VOUCHERS] = false,
    },
	debug = false,
}

local currencies = {
    [CURT_MONEY] = {
        name = GetString(SI_CURRENCY_GOLD), color = SF.colors.gold 
    },
    [CURT_ALLIANCE_POINTS] = {
		name = GetString(SI_CURRENCY_ALLIANCE_POINTS), color = SF.colors.fine,
    },
    [CURT_TELVAR_STONES] = {
		name = GetString(SI_CURRENCY_TELVAR_STONES), color = SF.colors.ltskyblue,
    },
	[CURT_WRIT_VOUCHERS] = {
		name = GetString(SI_CURRENCY_WRIT_VOUCHERS), color = SF.colors.normal,
    },
}

local saved, aw, toon
local iconSize = "90%"

local logDebug = PC.logDebug

---------------------
-- send debug messages to chat if enabled
local PCmsg = SF.addonChatter:New(PC.name)
local debugmode=false
PCmsg:disableDebug()

local function dbg(...)	-- mostly because I hate to type
	PCmsg:debugMsg(...)
end

local function SystemMessage(...) 
    PCmsg:systemMessage(...)
end

local function slashToggleDebug()
	-- have a local debugmode variable instead of just using PCmsg:toggleDebug()
	-- (the addonChatter keeps track of its own state without outside assistance)
	-- just so that I can print to chat that I am enabling or disabling debug mode.
	if debugmode == false then
		debugmode = true
		PCmsg:enableDebug()
		PCmsg:systemMessage("Enabling debug")

	else
		PCmsg:systemMessage("Disabling debug")
		debugmode = false
		PCmsg:disableDebug()
	end
end

---------------------
--[[ Rebalance

    Automatically balances currency holdings between character pockets and bank vaults.

    Iterates through all tracked currency types and performs automatic transfers to
    maintain pocket amounts at or near configured minimum thresholds. When pockets
    exceed the minimum, excess is deposited to the bank. When pockets fall below
    the minimum, funds are withdrawn from the bank (if available).

    This function is the core economic automation engine of PocketChange, called
    every time a bank interface opens. It manages gold, Alliance Points, Telvar
    Stones, and Writ Vouchers, respecting user-disabled currencies and minimum
    balance preferences stored in saved variables.

    The function both executes transfers and returns summary strings describing
    what was moved, which are formatted and displayed to the player via system
    messages after the function completes.

    Uses SF.safeCall10() from LibSFUtils for safe API calls, preventing addon crashes
    when ESO API functions fail unexpectedly (network issues, server timeouts, etc.).

    @return string, string
        Two comma-separated strings (may be empty):
        1. Deposit summary — All currency amounts transferred from pocket to bank
           Format: "|c<hex>amount<icon>|r + |c<hex>amount<icon>|r + ..."
        2. Withdrawal summary — All currency amounts transferred from bank to pocket
           Format: Same as deposit, but represents withdrawals from bank.
        Both strings are empty if no transfers were necessary.
--]]
local function Rebalance()
    if not saved then
        return "", ""
    end

	local deposit = {}          -- list of deposits to bank
	local withdrawal = {}       -- list of withdrawals from bank

	for currencyType, currency in pairs(currencies) do
        if saved.disables[currencyType] == false then
            -- Safe balance retrieval with defaults
            local okBank, bankBalance = SF.safeCall10(GetCurrencyAmount, currencyType, CURRENCY_LOCATION_BANK)
            local okPocket, pocketChange = SF.safeCall10(GetCurrencyAmount, currencyType, CURRENCY_LOCATION_CHARACTER)
			if not okBank then bankBalance = 0 end
            if not okPocket then pocketChange = 0 end

			-- Ensure minCurr has a value
			local minCurr = saved.minimum[currencyType] or 0
            local diffCurr = pocketChange - minCurr
			-- Only process if there is a discrepancy from target
			if diffCurr ~= 0 then
                local isDeposit = true
                local transferAmount = diffCurr
                -- Determine direction and normalize transfer amount
                if diffCurr < 0 then
                    isDeposit = false
                    transferAmount = minCurr - pocketChange
                end

                -- Check withdrawal feasibility before attempting transfer
                local shouldProceed = true
                if not isDeposit then
                    if bankBalance <= 0 then
                        shouldProceed = false
                    elseif bankBalance < transferAmount then
                        transferAmount = bankBalance
                    end
                end

                -- Execute transfer if conditions are met
                if shouldProceed == true then
                    local currColor = currency.color
                    local currIcon = ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType, iconSize)
                    local entry = zo_strformat("|c<<1>><<2>><<3>>|r", currColor.hex, transferAmount, currIcon)

                    local transferOk = false
                    local transferErr = nil

                    if isDeposit == true then
                        -- Transfer from character to bank
                        transferOk, transferErr = SF.safeCall10(TransferCurrency,
                            currencyType, transferAmount,
                            CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK)
                    else
                        -- Transfer from bank to character
                        transferOk, transferErr = SF.safeCall10(TransferCurrency,
                            currencyType, transferAmount,
                            CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_CHARACTER)
                    end

                    if transferOk == true then
                        -- Record successful transfer in appropriate list
                        if isDeposit == true then
                            deposit[#deposit + 1] = entry
                        else
                            withdrawal[#withdrawal + 1] = entry
                        end
                    else
                        -- Log failure for debugging
                        logDebug("Rebalance: Transfer failed for <<1>>: <<2>>", currency.name, transferErr)
                    end
                end
            end
        end
    end

    return table.concat(deposit, " + "), table.concat(withdrawal, " + ")
end

--[[ getLockpicksNeeded

    Checks if the player's lockpick supply is below the configured minimum threshold.

    Scans the character's backpack for all lockpick items and sums their stack sizes
    to determine total inventory count. Compares the result against the user-defined
    minimum in saved variables and returns a formatted notification string if supplies
    are insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization to
    alert players about low supply levels before they begin banking transactions.
    It is one of six supply-checking functions that monitor lockpicks, soul gems,
    empty soul gems, repair kits, and weapon poisons.

    Uses PC.Bag.GetItemsByType() from LibSFUtils to efficiently locate items by
    itemType criteria, avoiding manual iteration through all bag slots.

    @return string|nil
        nil    if current lockpick count meets or exceeds the configured minimum.
        string if current lockpick count is below the configured minimum.
               Format: "- Lockpicks (current < minimum)"
               Example: "- Lockpicks (45 < 100)"
               The string includes localized item name, current count, and target minimum.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[LOCKPICKS] — User-configured target minimum
        - BAG_BACKPACK — Character inventory (hardcoded scan target)
        - LOCKPICKS — Constant identifier (101)
--]]
local function getLockpicksNeeded()
	local pickStacks = PC.Bag.GetItemsByType(BAG_BACKPACK,{[1]=ITEMTYPE_TOOL,[2]=ITEMTYPE_LOCKPICK})
	local lockpicks = 0
	for i,t in ipairs(pickStacks) do
		lockpicks = lockpicks + t.size
	end

	if( saved.minimum[LOCKPICKS] > lockpicks ) then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_LOCKPICKS),
							SF.str(lockpicks), saved.minimum[LOCKPICKS])
	end
	return nil
end

--[[ getGemsNeeded

    Checks if the player's soul gem supply is below the configured minimum threshold.

    Scans the character's backpack for all soul gem items using LibSFUtils's
    specialized GetSoulGems() helper and sums their stack sizes to determine
    total inventory count. Compares the result against the user-defined minimum
    in saved variables and returns a formatted notification string if supplies
    are insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization
    to alert players about low soul gem supplies before they begin banking
    transactions. It is one of six supply-checking functions that monitor
    lockpicks, soul gems, empty soul gems, repair kits, and weapon poisons.

    Uses PC.Bag.GetSoulGems() from LibSFUtils to efficiently locate soul gem
    items without manual itemType filtering.

    @return string|nil
        nil    if current soul gem count meets or exceeds the configured minimum.
        string if current soul gem count is below the configured minimum.
               Format: "- Soul Gems (current < minimum)"
               Example: "- Soul Gems (25 < 100)"
               The string includes localized item name, current count, and target minimum.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[GEMS] — User-configured target minimum
        - BAG_BACKPACK — Character inventory (hardcoded scan target)
        - GEMS — Constant identifier (103)
--]]
local function getGemsNeeded()
	local gemStacks = PC.Bag.GetSoulGems(BAG_BACKPACK)
	local gems = 0
	for i,t in ipairs(gemStacks) do
		gems = gems + t.size
	end

	if( saved.minimum[GEMS] > gems ) then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_GEMS),
							SF.str(gems), saved.minimum[GEMS])
	end
	return nil
end

--[[ getEmptyGemsNeeded

    Checks if the player's empty soul gem supply is below the configured minimum threshold.

    Scans the character's backpack for empty soul gem items using LibSFUtils's
    specialized GetEmptySoulGems() helper and sums their stack sizes to determine
    total count. Compares the result against the user-defined minimum in saved
    variables and returns a formatted notification string if supplies are
    insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization
    to alert players about low empty soul gem supplies. It is one of six
    supply-checking functions that monitor lockpicks, soul gems, empty soul gems,
    repair kits, and weapon poisons.

    Unlike getGemsNeeded(), which counts BOTH filled and empty soul gems, this
    function tracks exclusively EMPTY gems — the refillable resource consumed
    by soul-trapping abilities. Players who rely on Soul Trap skills use this
    threshold to ensure they always have empty gems available to capture souls
    during combat.

    @return string|nil
        nil    if current empty soul gem count meets or exceeds the configured minimum.
        string if current empty soul gem count is below the configured minimum.
               Format: "- Empty Soul Gems (current < minimum)"
               Example: "- Empty Soul Gems (20 < 50)"
               The string includes localized item name, current count, and target minimum.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[EMPTY_GEMS] — User-configured target minimum
        - BAG_BACKPACK — Character inventory (hardcoded scan target)
        - EMPTY_GEMS — Constant identifier (104)
--]]
local function getEmptyGemsNeeded()
	local gemStacks = PC.Bag.GetEmptySoulGems(BAG_BACKPACK)
	local gems = 0
	for i,t in ipairs(gemStacks) do
		gems = gems + t.size
	end

	if( saved.minimum[EMPTY_GEMS] > gems ) then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_EMPTYGEMS),
							SF.str(gems), saved.minimum[EMPTY_GEMS])
	end
	return nil
end

--[[ getKitsNeeded

    Checks if the player's repair kit supply is below the configured minimum threshold.

    Scans the character's backpack for all repair kit items using LibSFUtils's
    specialized GetRepairKits() helper and sums their stack sizes to determine
    total inventory count. Compares the result against the user-defined minimum
    in saved variables and returns a formatted notification string if supplies
    are insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization
    to alert players about low repair kit supplies. It is one of six
    supply-checking functions that monitor lockpicks, soul gems, empty soul gems,
    repair kits, and weapon poisons.

    Repair kits (including Grand Repair Kits) are consumables used to restore
    worn equipment durability in the field, away from merchant repair services.
    This threshold matters most to players running extended dungeon delves,
    trials, or long overland sessions where vendor access is limited.

    @return string|nil
        nil    if current repair kit count meets or exceeds the configured minimum.
        string if current repair kit count is below the configured minimum.
               Format: "- Repair Kits (current < minimum)"
               Example: "- Repair Kits (12 < 40)"
               The string includes localized item name, current count, and target minimum.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[REPAIRS] — User-configured target minimum
        - BAG_BACKPACK — Character inventory (hardcoded scan target)
        - REPAIRS — Constant identifier (102)
--]]
local function getKitsNeeded()
	local kitStacks = PC.Bag.GetRepairKits(BAG_BACKPACK)
	local kits = 0
	for i,t in ipairs(kitStacks) do
		kits = kits + t.size
	end

	if( saved.minimum[REPAIRS] > kits ) then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_KITS),
							SF.str(kits), saved.minimum[REPAIRS])
	end
	return nil
end

--[[ getMainPoisonsNeeded

    Checks if the player's main weapon poison supply is below the configured minimum threshold.

    Inspects the character's equipped main hand weapon and its paired poison slot to
    determine how many poison vials are currently carried. Unlike the bag-scanning
    supply checks (lockpicks, gems, kits), this function queries EQUIPMENT STATE via
    ESO's gear inspection API rather than inventory contents.

    Compares the resulting poison stack size against the user-defined minimum in
    saved variables and returns a formatted notification string if supplies are
    insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization
    to alert players about low poison supplies. It is one of six
    supply-checking functions that monitor lockpicks, soul gems, empty soul gems,
    repair kits, and weapon poisons.

    Crucial for stealth builds (assassins, nightblades) and any DPS rotation
    relying on poison applications for damage-over-time effects or special procs.

    @return string|nil
        nil    if current main weapon poison count meets or exceeds the configured minimum.
        string if current main weapon poison count is below the configured minimum.
               Format: "- Main Weapon Poisons (current < minimum)"
               Example: "- Main Weapon Poisons (5 < 10)"
               The string includes localized item name, current count, and target minimum.
               Returns "- Main Weapon Poisons (0 < 10)" if no poison is currently paired.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[MAIN_WEAPON] — User-configured target minimum
        - EQUIP_SLOT_MAIN_HAND — Equipped main hand weapon slot
        - EQUIP_SLOT_POISON — Paired poison slot for main hand
        - MAIN_WEAPON — Constant identifier (105)
--]]
local function getMainPoisonsNeeded()
	local equipSlot = EQUIP_SLOT_MAIN_HAND
	local hasPoison = GetItemPairedPoisonInfo(equipSlot) 
	local _, stackSize = GetItemInfo(BAG_WORN, EQUIP_SLOT_POISON)
	if hasPoison ~= true then
		stackSize = 0
	end

	if saved.minimum[MAIN_WEAPON] > stackSize then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_MAIN),
							SF.str(stackSize), saved.minimum[MAIN_WEAPON])
	end
	return nil
end

--[[ getBkupPoisonsNeeded

    Checks if the player's backup weapon poison supply is below the configured minimum threshold.

    Inspects the character's backup weapon set (the second weapon pair on the
    ability bar swap) and its paired poison slot to determine how many poison
    vials are currently carried in that slot. This is the mirror function of
    getMainPoisonsNeeded(), differing only in the equipment slots inspected
    (EQUIP_SLOT_BACKUP_MAIN instead of EQUIP_SLOT_MAIN_HAND, and
    EQUIP_SLOT_BACKUP_POISON instead of EQUIP_SLOT_POISON).

    Like its main-hand counterpart, this function queries EQUIPMENT STATE via
    ESO's gear inspection API rather than inventory contents. Poison vials in
    BAG_BACKPACK are invisible to this check — only poisons actively applied
    to the backup weapon's poison slot are counted.

    Compares the resulting poison stack size against the user-defined minimum
    in saved variables and returns a formatted notification string if supplies
    are insufficient, or nil if the threshold is met or exceeded.

    This function is called by onBankOpen() during bank interface initialization.
    It is one of six supply-checking functions monitoring lockpicks, soul gems,
    empty soul gems, repair kits, and weapon poisons. Most relevant to players
    who keep different poisons on each weapon bar (e.g., damage poison on the
    DPS bar, utility poison on the buff bar).

    @return string|nil
        nil    if current backup weapon poison count meets or exceeds the configured minimum.
        string if current backup weapon poison count is below the configured minimum.
               Format: "- Backup Weapon Poisons (current < minimum)"
               Example: "- Backup Weapon Poisons (5 < 10)"
               The string includes localized item name, current count, and target minimum.
               Returns "- Backup Weapon Poisons (0 < 10)" if no poison is paired
               to the backup weapon.

    @param none
        Takes no parameters. Operates on global state:
        - saved.minimum[BKUP_WEAPON] — User-configured target minimum
        - EQUIP_SLOT_BACKUP_MAIN — Backup (second) main hand weapon slot
        - EQUIP_SLOT_BACKUP_POISON — Paired poison slot for backup weapon
        - BKUP_WEAPON — Constant identifier (106)
--]]
local function getBkupPoisonsNeeded()
	-- EQUIP_SLOT_BACKUP_POISON
	local equipSlot = EQUIP_SLOT_BACKUP_MAIN
	local hasPoison = GetItemPairedPoisonInfo(equipSlot) 	
	local _, stackSize = GetItemInfo(BAG_WORN, EQUIP_SLOT_BACKUP_POISON)
	if hasPoison ~= true then
		stackSize = 0
	end

	if saved.minimum[BKUP_WEAPON] > stackSize then
		return zo_strformat("- <<1>> (<<2>> < <<3>>)",GetString(PC_ITEM_BKUP),
							SF.str(stackSize), saved.minimum[BKUP_WEAPON])
	end
	return nil
end

--[[ onBankOpen

    Orchestrates all automated banking operations when a bank interface opens.

    Responds to EVENT_OPEN_BANK and performs three distinct categories of
    banking automation: (1) automatic currency rebalancing between pockets
    and bank vaults, (2) deposit/withdrawal transaction notifications, and
    (3) supply-level monitoring with configurable alerts. This is the central
    coordination point for the entire PocketChange addon.

    The function gates execution to only standard bank bags (excluding trade
    bags, mail attachments, and other non-bank containers), executes the
    Rebalance() currency automation, and then aggregates all six supply-check
    functions to provide configurable notifications based on user preferences
    (No/Chat/Chat+Sound).

    This function is registered by onPlayerActivated() after initialization
    completes, ensuring it runs only after saved variables are properly loaded
    and all dependent functions are available.

    @param eventCode number
        ESO event code for EVENT_OPEN_BANK. Passed by the event system;
        value is unused by this handler.

    @param bag number
        Bag identifier indicating which bag was opened. Used to validate
        that the event corresponds to a bank interface (BAG_BANK or
        BAG_SUBSCRIBER_BANK) rather than a trade bag or mail attachment.

    @return nil
        No value is returned. The function performs side effects including
        currency transfers, system message display, and audio alert triggering.
--]]
local function onBankOpen(_, bag)
	if bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then
		return
	end
	local deposit, withdrawal = Rebalance()
	if deposit ~= "" then
		local msg = zo_strformat("<<1>> <<2>>", GetString(POCKETCHANGE_DEPOSIT), deposit)
		SystemMessage(msg)
	end
	if withdrawal ~= "" then
		local msg = zo_strformat("<<1>> <<2>>", GetString(POCKETCHANGE_WITHDRAWAL), withdrawal)
		SystemMessage(msg)
	end
	local lkp = getLockpicksNeeded()
	local sg = getGemsNeeded()
	local esg = getEmptyGemsNeeded()
	local rk = getKitsNeeded()
	local mp = getMainPoisonsNeeded()
	local bp = getBkupPoisonsNeeded()
	if lkp ~= nil or sg ~= nil or rk ~= nil or esg ~= nil or bp ~= nil or mp ~= nil then
		local ps = 0
		local alrt = 0
		if lkp ~= nil and saved.notify[LOCKPICKS] ~= "Mode_No" then 
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(lkp) 
			ps = 1
			if saved.notify[LOCKPICKS] == "Mode_SoundChat" then alrt = 1 end
		end
		if sg ~= nil and saved.notify[GEMS] ~= "Mode_No"  then
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(sg) 
			ps = 1
			if saved.notify[GEMS] == "Mode_SoundChat"  then alrt = 1 end
		end
		if esg ~= nil and saved.notify[EMPTY_GEMS] ~= "Mode_No"  then
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(esg) 
			ps = 1
			if saved.notify[EMPTY_GEMS] == "Mode_SoundChat" then alrt = 1 end
		end
		if rk ~= nil and saved.notify[REPAIRS] ~= "Mode_No"  then
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(rk) 
			ps = 1
			if( saved.notify[REPAIRS] == "Mode_SoundChat" ) then alrt = 1 end
		end
		if mp ~= nil and saved.notify[MAIN_WEAPON] ~= "Mode_No"  then
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(mp) 
			ps = 1
			if( saved.notify[MAIN_WEAPON] == "Mode_SoundChat" ) then alrt = 1 end
		end
		if bp ~= nil and saved.notify[BKUP_WEAPON] ~= "Mode_No"  then
			if ps == 0 then SystemMessage(GetString(PC_SUPPLIES_NEEDED)) end
			SystemMessage(bp) 
			ps = 1
			if saved.notify[BKUP_WEAPON] == "Mode_SoundChat"  then alrt = 1 end
		end
		if alrt == 1  then
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.ABILITY_ULTIMATE_READY, 
				SFcolor.red(PC_SUPPLIES_NEEDED))
		end
	end
end

--------------
local function getCurrencyLabel(currencyType)
	local icon = ZO_Currency_GetPlatformFormattedCurrencyIcon(currencyType, iconSize)
	local text = currencies[currencyType].name
	logDebug("currency name: ",text, "    currency type: ",currencyType)
	local label = zo_strformat("<<1>> |c<<2>><<3>>|r", icon, currencies[currencyType].color.hex, text)
	return label
end

local function SettingsMenu()

	local notifyChoices = {
		GetString(PC_NOPT_NO), 
		GetString(PC_NOPT_CHAT),
		GetString(PC_NOPT_BOTH), 
	}
	local menu = LibAddonMenu2
	
	local panel = {
		type = "panel",
		name = PC.name,
		displayName = PC.displayName,
		author = PC.author,
        version = PC.version,
	    slashCommand = "/pocketchange.settings",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local options = {
		{
			type = "checkbox",
			name = POCKETCHANGE_ACCOUNTWIDE,
			tooltip = POCKETCHANGE_ACCOUNTWIDE_TT,
			getFunc = function() return toon.accountWide end,
			setFunc = function(value) 
                saved = SF.currentSavedVars(aw,toon,value)
			end,
			default = defaults.accountWide,
		},
		{
			type = "header",
			name = POCKETCHANGE_CURRENCY,
		},
		{
			type = "description",
			text = POCKETCHANGE_AUTOMANAGEMENT,
		},
		{
			type = "checkbox",
			name = PC_DISABLE_AUTOGOLD,
			tooltip = POCKETCHANGE_DISABLEAUTO_TT,
			getFunc = function() return saved.disables[CURT_MONEY] end,
			setFunc = function(value) 
				saved.disables[CURT_MONEY] = value 
			end,
			default = defaults.disables[CURT_MONEY],
		},
		{
			type = "checkbox",
			name = PC_DISABLE_AUTOAP,
			tooltip = POCKETCHANGE_DISABLEAUTO_TT,
			getFunc = function() return saved.disables[CURT_ALLIANCE_POINTS] end,
			setFunc = function(value) 
				saved.disables[CURT_ALLIANCE_POINTS] = value 
			end,
			default = defaults.disables[CURT_ALLIANCE_POINTS],
		},
		{
			type = "checkbox",
			name = PC_DISABLE_AUTOTELVAR,
			tooltip = POCKETCHANGE_DISABLEAUTO_TT,
			getFunc = function() return saved.disables[CURT_TELVAR_STONES] end,
			setFunc = function(value) 
				saved.disables[CURT_TELVAR_STONES] = value 
			end,
			default = defaults.disables[CURT_TELVAR_STONES],
		},
		{
			type = "checkbox",
			name = PC_DISABLE_AUTOVOUCHER,
			tooltip = POCKETCHANGE_DISABLEAUTO_TT,
			getFunc = function() return saved.disables[CURT_WRIT_VOUCHERS] end,
			setFunc = function(value) 
				saved.disables[CURT_WRIT_VOUCHERS] = value 
			end,
			default = defaults.disables[CURT_WRIT_VOUCHERS],
		},
		{
			type = "description",
			text = POCKETCHANGE_DESCRIPTION,
		},
		{
			type = "slider",
			name = getCurrencyLabel(CURT_MONEY),
			min = 0,
			max = 200000,
			step = 1000,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			disabled = function() 
					return saved.disables[CURT_MONEY]
				end,
			getFunc = function() 
					if saved.minimum[CURT_MONEY] < 0 then
						return 0
					end
					return saved.minimum[CURT_MONEY]
				end,
			setFunc = function(value) 
					if value < 0 then
						saved.minimum[CURT_MONEY] = 0
					else
						saved.minimum[CURT_MONEY] = value
					end
				end,
			default = defaults.minimum[CURT_MONEY],
		},
		{
			type = "slider",
			name = getCurrencyLabel(CURT_TELVAR_STONES),
			min = 0,
			max = 6000,
			step = 100,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			disabled = function() 
					return saved.disables[CURT_TELVAR_STONES]
				end,
			getFunc = function() 
					if saved.minimum[CURT_TELVAR_STONES] < 0 then
						return 0
					else
						return saved.minimum[CURT_TELVAR_STONES]
					end
				end,
			setFunc = function(value) 
					if value < 0 then
						saved.minimum[CURT_TELVAR_STONES] = 0
					else
						saved.minimum[CURT_TELVAR_STONES] = value 
					end
				end,
			default = defaults.minimum[CURT_TELVAR_STONES],
		},
		{
			type = "slider",
			name = getCurrencyLabel(CURT_ALLIANCE_POINTS),
			min = 0,
			max = 1000000,
			step = 100000,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			disabled = function() 
					return saved.disables[CURT_ALLIANCE_POINTS]
				end,
			getFunc = function() 
					if saved.minimum[CURT_ALLIANCE_POINTS] < 0 then
						return 0
					else
						return saved.minimum[CURT_ALLIANCE_POINTS] 
					end
				end,
			setFunc = function(value) 
					if value < 0 then
						saved.minimum[CURT_ALLIANCE_POINTS] = 0
					else
						saved.minimum[CURT_ALLIANCE_POINTS] = value
					end
				end,
			default = defaults.minimum[CURT_ALLIANCE_POINTS],
		},
		{
			type = "slider",
			name = getCurrencyLabel(CURT_WRIT_VOUCHERS),
			min = 0,
			max = 1000,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			disabled = function() 
					return saved.disables[CURT_WRIT_VOUCHERS]
				end,
			getFunc = function() return saved.minimum[CURT_WRIT_VOUCHERS] end,
			setFunc = function(value) saved.minimum[CURT_WRIT_VOUCHERS] = value end,
			default = defaults.minimum[CURT_WRIT_VOUCHERS],
		},
		{
			type = "header",
			name = PC_SUPPLIES,
		},
		{
			type = "description",
			text = PC_SUPPLIES_DESC,
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_LP,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[LOCKPICKS]] end,
			setFunc = function(var)
				saved.notify[LOCKPICKS] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_LOCKPICKS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[LOCKPICKS] end,
			setFunc = function(value) saved.minimum[LOCKPICKS] = value end,
			default = defaults.minimum[LOCKPICKS],
			width = "half",
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_RK,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[REPAIRS]] end,
			setFunc = function(var)
				saved.notify[REPAIRS] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_REPAIRKITS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[REPAIRS] end,
			setFunc = function(value) saved.minimum[REPAIRS] = value end,
			default = defaults.minimum[REPAIRS],
			width = "half",
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_SG,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[GEMS]] end,
			setFunc = function(var)
				saved.notify[GEMS] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_SOULGEMS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[GEMS] end,
			setFunc = function(value) saved.minimum[GEMS] = value end,
			default = defaults.minimum[GEMS],
			width = "half",
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_ESG,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[EMPTY_GEMS]] end,
			setFunc = function(var)
				saved.notify[EMPTY_GEMS] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_ESOULGEMS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[EMPTY_GEMS] end,
			setFunc = function(value) saved.minimum[EMPTY_GEMS] = value end,
			default = defaults.minimum[EMPTY_GEMS],
			width = "half",
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_MAIN,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[MAIN_WEAPON]] end,
			setFunc = function(var)
				saved.notify[MAIN_WEAPON] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_MAINPOISONS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[MAIN_WEAPON] end,
			setFunc = function(value) saved.minimum[MAIN_WEAPON] = value end,
			default = defaults.minimum[MAIN_WEAPON],
			width = "half",
		},
		{
			type = "dropdown",
			name = PC_NOTIFY_BKUP,
			choices = notifyChoices,
			getFunc = function() return ModeArray[saved.notify[BKUP_WEAPON]] end,
			setFunc = function(var)
				saved.notify[BKUP_WEAPON] = ModeArray[var]
			end,
			default = ModeArray[GetString(PC_NOPT_NO)], 
			width = "half",
		},  -- end dropdown
		{
			type = "slider",
			name = GetString(PC_BKUPPOISONS),
			min = 0,
			max = 400,
			step = 10,
			inputLocation = "right",
			clampInput = false,
			decimals = 0,
			getFunc = function() return saved.minimum[BKUP_WEAPON] end,
			setFunc = function(value) saved.minimum[BKUP_WEAPON] = value end,
			default = defaults.minimum[BKUP_WEAPON],
			width = "half",
		},
	}

	menu:RegisterAddonPanel("PCOptionsMenu", panel)
	menu:RegisterOptionControls("PCOptionsMenu", options)

end

----------
-- INIT --
----------
local function onPlayerActivated()
    if saved.debug == true then
        SystemMessage(GetString(POCKETCHANGE_ENABLE_DEBUG))
    end
	PC.evtmgr:unregEvt(EVENT_PLAYER_ACTIVATED)
	PC.evtmgr:registerEvt(EVENT_OPEN_BANK, onBankOpen)
end

local function onAddonLoaded(_, addonName)
	if addonName == PC.name then
		PC.evtmgr:unregEvt(EVENT_ADD_ON_LOADED)

        aw, toon = SF.getAllSavedVars("PocketChangeVar", 1, defaults)
        saved = SF.currentSavedVars(aw, toon)

		SettingsMenu()

		PC.evtmgr:registerEvt(EVENT_PLAYER_ACTIVATED, onPlayerActivated)
	end

end

function PC.slashHelp()
	if PCmsg == nil then return end
    local cmdtable = {
        {"/pocketchange", 			PC_SLASH_HELP},
        {"/pocketchange.settings", 	PC_SLASH_SETTINGS},
        {"/pocketchange debug", 	PC_SLASH_DEBUG},
    }
    local title = "PocketChange commands"
    PCmsg:slashHelp(title, cmdtable)
end

-- slash commands (must not have capital letters!!)
SLASH_COMMANDS["/pocketchange"] = function(...)
	local nargs = select('#',...)
	if nargs == 0 then
		PC.slashHelp()

	else
		local v = select(1,...)
        local t = type(v)
        if v == nil or v == "" then
			PC.slashHelp()

		elseif t == "table" then
			PCmsg:debugMsg("Invalid argument for /pocketchange")

		else
			local s = tostring(v)
			if s == "debug"  then
				slashToggleDebug()

			elseif s == "help" then
				PC.slashHelp()

            else
                PCmsg:debugMsg("Invalid argument for /pocketchange")
			end
		end
	end
end

PC.evtmgr:registerEvt(EVENT_ADD_ON_LOADED, onAddonLoaded)


