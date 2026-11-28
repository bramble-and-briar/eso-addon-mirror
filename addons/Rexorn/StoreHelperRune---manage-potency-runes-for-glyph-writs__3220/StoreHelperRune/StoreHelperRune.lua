StoreHelperRune={
		 author="Rexorn"
		,version="0.24"
		,variableVersion=1
	}

StoreHelperRune.localization = {}		-- global lang files will load

local L = StoreHelperRune.localization	-- keep typing sane
									-- also since LUA has no table copy this must be a pointer/alias
									-- can access text strings by L['name'] or shortcut L.name

local savedVarsDefault = {
			 useCharacterSettings = false
			,AddRunes2Stock={
				 Jora	= 0			-- craft level 1 trifling
				,Jera	= 0			-- craft level 2 petty
				,Odra	= 0			-- craft level 3 minor
				,Edora	= 0			-- craft level 4 moderate
				,Pora	= 0			-- craft level 5 strong
				,Rera	= 0			-- craft level 6 greater
				,Derado	= 0			-- craft level 7 grand
				,Rekura	= 0			-- craft level 8 splendid
				,Kura	= 0			-- craft level 9 monumental
				,Rejera	= 0			-- craft level 10 superb
			}
			,TurnInRunes2Stock={
				 Jode   = 0			-- handin with Potency 1 writs
				,Ode	= 0			-- handin with Potency 2 & 5 writs
				,Jayde	= 0			-- handin with Potency 3 writs
				,Pojode	= 0			-- handin with Potency 4 writs
				,Idode	= 0			-- handin with Potency 6 writs  (potency 7 writs turn in Ta)
				,Kedeko	= 0			-- handin with Potency 8 writs
				,Rede	= 0			-- handin with Potency 9 writs
				,Jehade	= 0			-- handin with Potency 10 writs
			}
} 

-- setup pointing to defaults, Init() - ZO_SavedVars will point to final table
local savedVarsAcct = savedVarsDefault		-- pointer not actual table copy 
local savedVarsToon = savedVarsDefault		-- pointer not actual table copy 

-- this will flip between savedVarsAcct & savedVarsToon based on
-- savedVarsToon.useCharacterSettings value
-- simplifies structure if savedVarsToon.useCharacterSettings 
--                         then savedVarsToon.* else savedVarsAcct.*
-- should only be set in Init() and setupPanel() optionsData checkbox

local savedVarsUsing = savedVarsDefault


local bag_entry_id = 0				-- for GetItemId in bag search
local debug_msg_on = false			-- final value imported from StoreHelper
local gold_on_char = 0
local itemID = 0
local runes2shop4 = 0
local show_buy_msg = true			-- final value imported from StoreHelper
local store_entry = 1
local store_entry_max = 0
local storehelper_accepted_load = false

-- for GetStoreEntryInfo
local gsei_name, stack, price = "x",0,0


local itemID_Jora   = 45855			-- Jora to Rejera used for glyph crafting
local itemID_Jera   = 45857
local itemID_Odra   = 45807
local itemID_Edora  = 45809
local itemID_Pora   = 45811
local itemID_Rera   = 45813
local itemID_Derado = 45814
local itemID_Rekura = 45815
local itemID_Kura   = 45816
local itemID_Rejera = 64509
local itemID_Jode	= 45817			-- Jode to Jehade are for direct handin not crafting
local itemID_Ode	= 45819
local itemID_Jayde	= 45821
local itemID_Pojode	= 45823
local itemID_Idode	= 45826
local itemID_Kedeko	= 45828
local itemID_Rede	= 45829
local itemID_Jehade	= 64508
local need2buyJora   = 0			-- Jora to Rejera used for glyph crafting
local need2buyJera   = 0
local need2buyOdra   = 0
local need2buyEdora  = 0
local need2buyPora   = 0
local need2buyRera   = 0
local need2buyDerado = 0
local need2buyRekura = 0
local need2buyKura   = 0
local need2buyRejera = 0
local need2buyJode   = 0			-- Jode to Jehade are for direct handin not crafting
local need2buyOde    = 0
local need2buyJayde  = 0
local need2buyPojode = 0
local need2buyIdode  = 0
local need2buyKedeko = 0
local need2buyRede   = 0
local need2buyJehade = 0

--[[
local priceJora   = 30				-- Jora to Rejera used for glyph crafting
local priceJera   = 51
local priceOdra   = 60
local priceEdora  = 72
local pricePora   = 84
local priceRera   = 93
local priceDerado = 96
local priceRekura = 99
local priceKura   = 105
local priceRejera = 111
local priceJode	  = 30				-- Jode to Jehade are for direct handin not crafting
local priceOde	  = 51
local priceJayde  = 60
local pricePojode = 72
local priceIdode  = 87
local priceKedeko = 96
local priceRede   = 99
local priceJehade = 111
]]

-- some day this will handle pchat and other stuff
local function ToChat(addMessageString)
	CHAT_SYSTEM:AddMessage(addMessageString)
end

local function ToChatDebug(addMessageString)
	if debug_msg_on == true then
		CHAT_SYSTEM:AddMessage(addMessageString)
	end
end

local function debug_show_needs()
	if debug_msg_on == true then
		df("        Jora%+d  Jera%+d  Odra%+d  Edora%+d  Pora%+d ", 
				need2buyJora, need2buyJera, need2buyOdra, need2buyEdora, need2buyPora)
		df("        Rera%+d  Derado%+d  Rekura%+d  Kura%+d  Rejera%+d", 
				need2buyRera, need2buyDerado, need2buyRekura, need2buyKura, need2buyRejera)
		df("        Jode%+d  Ode%+d  Jayde%+d  Idode%+d ", 
				need2buyJode, need2buyOde, need2buyJayde, need2buyIdode)
		df("        Kedeko%+d  Rede%+d  Jehade%+d", 
				need2buyKedeko, need2buyRede, need2buyJehade)
		CHAT_SYSTEM:AddMessage("        a negative shows stock is more than needed")
	end
end -- func debug_show_needs


-- dump store contents to chat
-- helps with shr_store_* names for localization
local function slash_shr_storedump()
	-- sometimes have store data from last store visited
	-- store data may or may not persist across /reloadui (stables do)

	local entry_itemID
	store_entry_max = GetNumStoreItems()
	ToChat(string.format("SHR: Store Dump found %d entries", store_entry_max))
	
	for store_entry = 1, store_entry_max do
		-- stack from GetStoreEntryInfo is how many you get for one purchase always 1 for mats
		-- dont' try to use entryType -- seems to always return 0 at enchanter store
		_, gsei_name, stack, price, _, _, _, _, _, _, _, _, _, _, _, _ = 
			GetStoreEntryInfo(store_entry)

		entry_itemID = StoreHelper.shared.find_store_entry_id_num(store_entry)
		ToChat(string.format("%2u  %4ug  id=%5u %s", store_entry, price, entry_itemID, gsei_name))	
	end
end -- func slash_shr_storedump


local function FindMaxBuyable(item_name, num_needed, price)
	-- local maxBuyable = GetStoreEntryMaxBuyable(store_entry)
	-- returned number available for purchase not number affordable

	local maxBuyable, fraction = math.modf(gold_on_char / price)

	ToChatDebug(string.format("      gold=%u  maxBuyable=%u", gold_on_char, maxBuyable))

	if maxBuyable < num_needed then 
		if show_buy_msg == true then
			ToChat(string.format(L.SHR_buy_reduced_msg, item_name, num_needed, maxBuyable))
		end
		
		return maxBuyable
	else
		return num_needed
	end
end -- func FindMaxBuyable


local function count_in_craftbag()
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Jora)
	need2buyJora = need2buyJora - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Jera)
	need2buyJera = need2buyJera - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Odra)
	need2buyOdra = need2buyOdra - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Edora)
	need2buyEdora = need2buyEdora - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Pora)
	need2buyPora = need2buyPora - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Rera)
	need2buyRera = need2buyRera - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Derado)
	need2buyDerado = need2buyDerado - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Rekura)
	need2buyRekura	= need2buyRekura - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Kura)
	need2buyKura = need2buyKura - stack
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Rejera)
	need2buyRejera = need2buyRejera - stack	
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Jode)
	need2buyJode = need2buyJode - stack	
	
	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Ode)
	need2buyOde = need2buyOde - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Jayde)
	need2buyJayde = need2buyJayde - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Pojode)
	need2buyPojode = need2buyPojode - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Idode)
	need2buyIdode = need2buyIdode - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Kedeko)
	need2buyKedeko = need2buyKedeko - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Rede)
	need2buyRede = need2buyRede - stack	

	_, stack, _, _, _, _, _, _, _ = GetItemInfo(BAG_VIRTUAL,itemID_Jehade)
	need2buyJehade = need2buyJehade - stack	
end -- func count_in_craftbag


local function count_in_a_bag(bagID)
	if  need2buyJora <= 0 and need2buyJera <= 0 and need2buyOdra <= 0   and need2buyEdora <= 0
	and need2buyPora <= 0 and need2buyRera <= 0 and need2buyDerado <= 0 and need2buyRekura <= 0
	and need2buyKura <= 0 and need2buyRejera <= 0 
	and need2buyJode <= 0 and need2buyOde <= 0  and need2buyJayde <= 0  and need2buyPojode <= 0 
	and need2buyKedeko <= 0 and need2buyRede <= 0 and need2buyJehade <= 0 then
		-- early exit in case prior bag search found enough of everything

		-- yes, need2buy could be negative if you have more than your base limit
		-- check <= needs fewer operations than always zeroing negatives after subtraction
		return
	end

	-- bagID might be BAG_BACKPACK, BAG_BANK, or BAG_SUBSCRIBER_BANK
	-- yes, there are empty slots in the middle of a bag
	SHARED_INVENTORY:RefreshInventory(bagID)

	for x=0, GetBagSize(bagID) do
		bag_entry_id = GetItemId(bagID,x)
		
		if bag_entry_id == 0 then
			-- empty slot just skip
		elseif bag_entry_id == itemID_Jora then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyJora = need2buyJora - stack

		elseif bag_entry_id == itemID_Rejera then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyRejera = need2buyRejera - stack
			-- yes, Rejera out of level order.  expected to be one of two most commonly found in inventory

		elseif bag_entry_id == itemID_Jera then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyJera = need2buyJera - stack

		elseif bag_entry_id == itemID_Odra then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyOdra = need2buyOdra - stack

		elseif bag_entry_id == itemID_Edora then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyEdora = need2buyEdora - stack

		elseif bag_entry_id == itemID_Pora then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyPora = need2buyPora - stack

		elseif bag_entry_id == itemID_Rera then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyRera = need2buyRera - stack

		elseif bag_entry_id == itemID_Derado then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyDerado = need2buyDerado - stack

		elseif bag_entry_id == itemID_Rekura then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyRekura = need2buyRekura - stack

		elseif bag_entry_id == itemID_Kura then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyKura = need2buyKura - stack
		
		-- begin checks for subtractive turn in only runes
		elseif bag_entry_id == itemID_Jode then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyJode = need2buyJode - stack

		elseif bag_entry_id == itemID_Ode then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyOde = need2buyOde - stack

		elseif bag_entry_id == itemID_Jayde then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyJayde = need2buyJayde - stack

		elseif bag_entry_id == itemID_Pojode then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyPojode = need2buyPojode - stack

		elseif bag_entry_id == itemID_Idode then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyIdode = need2buyIdode - stack

		elseif bag_entry_id == itemID_Kedeko then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyKedeko = need2buyKedeko - stack

		elseif bag_entry_id == itemID_Rede then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyRede = need2buyRede - stack

		elseif bag_entry_id == itemID_Jehade then
			_, stack, _, _, _, _, _, _, _ = GetItemInfo(bagID,x)
			need2buyJehade = need2buyJehade - stack		
		end
	end
end -- func count_in_a_bag


local function count_runes_in_stock()
	need2buyJora   = savedVarsUsing.AddRunes2Stock.Jora
	need2buyJera   = savedVarsUsing.AddRunes2Stock.Jera
	need2buyOdra   = savedVarsUsing.AddRunes2Stock.Odra
	need2buyEdora  = savedVarsUsing.AddRunes2Stock.Edora
	need2buyPora   = savedVarsUsing.AddRunes2Stock.Pora
	need2buyRera   = savedVarsUsing.AddRunes2Stock.Rera
	need2buyDerado = savedVarsUsing.AddRunes2Stock.Derado
	need2buyRekura = savedVarsUsing.AddRunes2Stock.Rekura
	need2buyKura   = savedVarsUsing.AddRunes2Stock.Kura
	need2buyRejera = savedVarsUsing.AddRunes2Stock.Rejera
	
	need2buyJode   = savedVarsUsing.TurnInRunes2Stock.Jode
	need2buyOde	   = savedVarsUsing.TurnInRunes2Stock.Ode
	need2buyJayde  = savedVarsUsing.TurnInRunes2Stock.Jayde
	need2buyPojode = savedVarsUsing.TurnInRunes2Stock.Pojode
	need2buyIdode  = savedVarsUsing.TurnInRunes2Stock.Idode
	need2buyKedeko = savedVarsUsing.TurnInRunes2Stock.Kedeko
	need2buyRede   = savedVarsUsing.TurnInRunes2Stock.Rede
	need2buyJehade = savedVarsUsing.TurnInRunes2Stock.Jehade

	count_in_craftbag()	
	count_in_a_bag(BAG_BACKPACK)
	count_in_a_bag(BAG_BANK)
	count_in_a_bag(BAG_SUBSCRIBER_BANK)
	-- always check BAG_SUBSCRIBER_BANK & craftbag even if not subscriber currently
	-- player may have recently dropped ESO+

	runes2shop4 = 0		  -- count of how many different runes we want
	if need2buyJora > 0   then runes2shop4 = 1 end
	if need2buyJera > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyOdra > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyEdora > 0  then runes2shop4 = runes2shop4 + 1 end
	if need2buyPora > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyRera > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyDerado > 0 then runes2shop4 = runes2shop4 + 1 end
	if need2buyRekura > 0 then runes2shop4 = runes2shop4 + 1 end
	if need2buyKura > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyRejera > 0 then runes2shop4 = runes2shop4 + 1 end
	
	if need2buyJode > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyOde > 0    then runes2shop4 = runes2shop4 + 1 end
	if need2buyJayde > 0  then runes2shop4 = runes2shop4 + 1 end
	if need2buyPojode > 0 then runes2shop4 = runes2shop4 + 1 end
	if need2buyIdode > 0  then runes2shop4 = runes2shop4 + 1 end
	if need2buyKedeko > 0 then runes2shop4 = runes2shop4 + 1 end
	if need2buyRede > 0   then runes2shop4 = runes2shop4 + 1 end
	if need2buyJehade > 0 then runes2shop4 = runes2shop4 + 1 end
	
	ToChatDebug("SHRDB: after bag scan runes need:")
	debug_show_needs()	
	ToChatDebug(string.format("SHRDB:      runes2shop4=%u", runes2shop4))
end -- func count_runes_in_stock


local function checkBuyThisEntry(item_name, num_needed, store_entry, price)			
	ToChatDebug(string.format("SHRDB: checkBuy e=%u want %u %s %ug",
		store_entry, num_needed, item_name, price))

	num_needed = FindMaxBuyable(item_name, num_needed, price)
	-- don't worry, this will not change the original value passed in,
	-- a func local version of the passed vars seems to be created

	if num_needed > 0 then
		BuyStoreItem(store_entry, num_needed)
		gold_on_char = gold_on_char - (num_needed * price)
	end

	runes2shop4 = runes2shop4 - 1
	
	if show_buy_msg == true then
		ToChat(string.format(L.SHR_purchased_msg, num_needed, item_name))
	end
end -- func checkBuyThisEntry



-- this is the function we will pass to StoreHelper
-- I set this to loop once through the store looking at each store item
-- to see if it was something we need instead of looping through store
-- once for each item we need, not sure if it really helps performance
-- sure is a lot more typing :)

local function shop_for_potency_runes()
	-- import store-helper buy message setting
	-- pull here not in Init() in case user changes settings after load
	show_buy_msg = StoreHelper.shared.get_show_buy_msg()
	debug_msg_on = StoreHelper.shared.get_show_debug_msg()

	count_runes_in_stock()
	
	if runes2shop4 == 0 then
		-- we don't need any runes so stop
		ToChatDebug("SHRDB: no runes needed")
		return
	end

	gold_on_char = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
	-- testing shows the update is slow, might buy several items before 1st gold
	-- change registers -> read here & track internally after each buy

	
	store_entry_max = GetNumStoreItems()
	for store_entry = 1, store_entry_max do
		-- stack from function is how many you get for one purchase always 1 for mats
		_, gsei_name, stack, price, _, _, _, _, _, _, _, _, _, _, _, _ = GetStoreEntryInfo(store_entry)


		-- Rejera & Jehade are the most expensives rune we will auto buy at 111
		if (stack == 1) and (price <= 111) then	
			ToChatDebug(string.format("SHRDB: entry%2u  runes2shop4=%2u  %ug  %s",
					store_entry, runes2shop4, price, gsei_name))

			itemID = StoreHelper.shared.find_store_entry_id_num(store_entry)
		
			-- version 0.4 replaced "and price == priceJora" with "and itemID = itemID_Jora"
			if need2buyJora > 0 and gsei_name == L.SHR_store_Jora and itemID == itemID_Jora then
				checkBuyThisEntry(L.SHR_opt_Jora, need2buyJora, store_entry, price)
				-- no, we are not going to find a 2nd Jora in the store (we hope)
				-- but this means we will stop testing after the 1st AND condition of the if block
				need2buyJora = 0

			elseif need2buyJera > 0 and gsei_name == L.SHR_store_Jera and itemID == itemID_Jera then
				checkBuyThisEntry(L.SHR_opt_Jera, need2buyJera, store_entry, price)
				need2buyJera = 0

			elseif need2buyOdra > 0 and gsei_name == L.SHR_store_Odra and itemID == itemID_Odra then
				checkBuyThisEntry(L.SHR_opt_Odra, need2buyOdra, store_entry, price)
				need2buyOdra = 0

			elseif need2buyEdora > 0 and gsei_name == L.SHR_store_Edora and itemID == itemID_Edora then
				checkBuyThisEntry(L.SHR_opt_Edora, need2buyEdora, store_entry, price)
				need2buyEdora = 0

			elseif need2buyPora > 0 and gsei_name == L.SHR_store_Pora and itemID == itemID_Pora then
				checkBuyThisEntry(L.SHR_opt_Pora, need2buyPora, store_entry, price)
				need2buyPora = 0

			elseif need2buyRera > 0 and gsei_name == L.SHR_store_Rera and itemID == itemID_Rera then
				checkBuyThisEntry(L.SHR_opt_Rera, need2buyRera, store_entry, price)
				need2buyRera = 0

			elseif need2buyDerado > 0 and gsei_name == L.SHR_store_Derado and itemID == itemID_Derado then
				checkBuyThisEntry(L.SHR_opt_Derado, need2buyDerado, store_entry, price)
				need2buyDerado = 0

			elseif need2buyRekura > 0 and gsei_name == L.SHR_store_Rekura and itemID == itemID_Rekura then
				checkBuyThisEntry(L.SHR_opt_Rekura, need2buyRekura, store_entry, price)
				need2buyRekura = 0

			elseif need2buyKura > 0 and gsei_name == L.SHR_store_Kura and itemID == itemID_Kura then
				checkBuyThisEntry(L.SHR_opt_Kura, need2buyKura, store_entry, price)
				need2buyKura = 0

			elseif need2buyRejera > 0 and gsei_name == L.SHR_store_Rejera and itemID == itemID_Rejera then
				checkBuyThisEntry(L.SHR_opt_Rejera, need2buyRejera, store_entry, price)
				need2buyRejera = 0

			-- begin subtractive runes for turnin
			elseif need2buyJode > 0 and gsei_name == L.SHR_store_Jode and itemID == itemID_Jode then
				checkBuyThisEntry(L.SHR_opt_Jode, need2buyJode, store_entry, price)
				need2buyJode = 0

			elseif need2buyOde > 0 and gsei_name == L.SHR_store_Ode and itemID == itemID_Ode then
				checkBuyThisEntry(L.SHR_opt_Ode, need2buyOde, store_entry, price)
				need2buyOde = 0

			elseif need2buyJayde > 0 and gsei_name == L.SHR_store_Jayde and itemID == itemID_Jayde then
				checkBuyThisEntry(L.SHR_opt_Jayde, need2buyJayde, store_entry, price)
				need2buyJayde = 0

			elseif need2buyPojode > 0 and gsei_name == L.SHR_store_Pojode and itemID == itemID_Pojode then
				checkBuyThisEntry(L.SHR_opt_Pojode, need2buyPojode, store_entry, price)
				need2buyPojode = 0

			elseif need2buyIdode > 0 and gsei_name == L.SHR_store_Idode and itemID == itemID_Idode then
				checkBuyThisEntry(L.SHR_opt_Idode, need2buyIdode, store_entry, price)
				need2buyIdode = 0

			elseif need2buyKedeko > 0 and gsei_name == L.SHR_store_Kedeko and itemID == itemID_Kedeko then
				checkBuyThisEntry(L.SHR_opt_Kedeko, need2buyKedeko, store_entry, price)
				need2buyKedeko = 0

			elseif need2buyRede > 0 and gsei_name == L.SHR_store_Rede and itemID == itemID_Rede then
				checkBuyThisEntry(L.SHR_opt_Rede, need2buyRede, store_entry, price)
				need2buyRede = 0

			elseif need2buyJehade > 0 and gsei_name == L.SHR_store_Jehade and itemID == itemID_Jehade then
				checkBuyThisEntry(L.SHR_opt_Jehade, need2buyJehade, store_entry, price)
				need2buyJehade = 0
			end			
		end
		
		if runes2shop4 == 0 then
			-- found all the rune types we need to buy so stop searching
			ToChatDebug("SHRDB: found last rune needed")
			break
		end
		
	end -- store loop

	ToChatDebug("SHRDB: done -----")
end -- func shop_for_potency_runes



-- *****************************************************
-- option panel setup
-- *****************************************************
local function setupPanel()
	-- need to registerForRefresh in case set_boxnum has to edit an out of range value 
	local panelData = {type = "panel", name = L.SHR_mod_name, 
		 				displayName = L.SHR_display_name, author = StoreHelperRune.author, 
		 				version = StoreHelperRune.version, registerForRefresh = true}


	-- note: savedVarsUsing points to savedVarsAcct or savedVarsToon depending on savedVarsToon.useCharacterSettings
	local slider_max = 50
	local optionsData = {
		 [1] = {type = "header", name = L.SHR_OptMenu_header_name }
		,[2] = {type = "description", text = L.SHR_OptMenu_description }
		,[3] = {type = "checkbox", name = L.SHR_OptMenu_chk_UseToon_name, 
				tooltip = L.SHR_OptMenu_chk_UseToon_tooltip,
				getFunc = function() return savedVarsToon.useCharacterSettings end,
				setFunc = function(enable)
					savedVarsToon.useCharacterSettings = enable
					if savedVarsToon.useCharacterSettings == true then
						savedVarsUsing = savedVarsToon
					else
						savedVarsUsing = savedVarsAcct
					end
				end 
			}
		,[4] = {type = "description", text = L.SHR_OptMenu_craft_block_description }
		,[5] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Jora,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Jora end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Jora = val end}
		,[6] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Jera,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Jera end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Jera = val end}
		,[7] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Odra,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Odra end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Odra = val end}
		,[8] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Edora,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Edora end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Edora = val end}
		,[9] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Pora,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Pora end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Pora = val end}
		,[10] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Rera,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Rera end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Rera = val end}
		,[11] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Derado,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Derado end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Derado = val end}
		,[12] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Rekura,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Rekura end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Rekura = val end}
		,[13] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Kura,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Kura end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Kura = val end}
		,[14] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Rejera,
				getFunc = function() return savedVarsUsing.AddRunes2Stock.Rejera end,
				setFunc = function(val) savedVarsUsing.AddRunes2Stock.Rejera = val end}
		,[15] = {type = "divider"}
		,[16] = {type = "description", text = L.SHR_OptMenu_handin_description }

		,[17] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Jode,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Jode end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Jode = val end}
		,[18] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Ode,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Ode end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Ode = val end}
		,[19] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Jayde,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Jayde end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Jayde = val end}
		,[20] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Pojode,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Pojode end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Pojode = val end}
		,[21] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Idode,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Idode end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Idode = val end}
		,[22] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Kedeko,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Kedeko end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Kedeko = val end}
		,[23] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Rede,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Rede end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Rede = val end}
		,[24] = {type = "slider", default = 0, min = 0, max = slider_max, clampInput = false, 
				tooltip = L.SHR_OptMenu_box_genRune_tooltip,
				name = L.SHR_opt_Jehade,
				getFunc = function() return savedVarsUsing.TurnInRunes2Stock.Jehade end,
				setFunc = function(val) savedVarsUsing.TurnInRunes2Stock.Jehade = val end}		
		}


	-- CANNOT use mod name L['SHR_mod_name'] here 

	LibAddonMenu2:RegisterAddonPanel("StoreHelperRunePanel", panelData)
	LibAddonMenu2:RegisterOptionControls("StoreHelperRunePanel", optionsData)
	
end -- func-setupPanel


-- *****************************************************
-- on Player event - main setup
-- *****************************************************
local function onPlayer(EventCode)
	-- this will tell StoreHelper to schedule our function to run if the store opened
	-- takes gold & only gold.  Letting StoreHelper handle store open reduces chance
	-- of store shopping addons running at the same instant.
	
	-- wait until onPlayer so SH can display it's diag messages if needed
	storehelper_accepted_load = StoreHelper.shared.add_for_store_takes_gold_only(
			shop_for_potency_runes,
			L.SHR_mod_name,
			L.SHR_add_for_store_desc)

	if storehelper_accepted_load == false then ToChat(L.SHR_load_not_accepted) end

	setupPanel()

	EVENT_MANAGER:UnregisterForEvent("StoreHelperRuneActivated", EVENT_PLAYER_ACTIVATED)
end


-- *****************************************************
-- On Addon Loaded entry point
-- *****************************************************
local function Init(EventCode, AddonName)
	-- event is triggered for EACH addon loaded 
	-- if trigger was for another addon just exit out
	if AddonName ~= L.SHR_mod_name then return end

	
	savedVarsAcct = ZO_SavedVars:NewAccountWide("StoreHelperRuneAcct", -- file name
				StoreHelperRune.variableVersion,		-- if saved version diff then wipe file
				nil,									-- optional name in subtable (default="Default")
				savedVarsDefault)						-- defaults to use if a var is not in saved file

	savedVarsToon = ZO_SavedVars:NewCharacterIdSettings("StoreHelperRuneToon",
				StoreHelperRune.variableVersion,		
				nil,							
				savedVarsDefault)						-- trying to use savedVarsAcct for default makes a mess
														-- because savedVarsAcct is a pointer not a table


	if savedVarsToon.useCharacterSettings == true then
		savedVarsUsing = savedVarsToon
	else
		savedVarsUsing = savedVarsAcct
	end

	
	-- do NOT setup panel here wait for language files to load


	-- setup shr_storedump which will dump store items to chat to help with localization of shr_store_*
	SLASH_COMMANDS['/shr_storedump'] = slash_shr_storedump
	
	-- drop on_loaded cause only init once & setup to trigger toon loaded for panel
	EVENT_MANAGER:UnregisterForEvent("StoreHelperRuneInit", EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent("StoreHelperRuneActivated", EVENT_PLAYER_ACTIVATED, onPlayer)
	-- do NOT setup for EVENT_OPEN_STORE - let store-helper do that
end -- func-Init


EVENT_MANAGER:RegisterForEvent("StoreHelperRuneInit", EVENT_ADD_ON_LOADED, Init)



--[[ notes for rune purchase support
gold	LEVEL	name		skill
30		1		Jora		1
42		5		Porade		1*
51		10		Jera		2
54		15		Jejora		2*
60		20		Odra		3
66		25		Pojora		3*
72		30		Edora		4
78		35		Jaera		4*
84		40		Pora		5
87		c10		Denara		5*
93		c30		Rera		6
96		c50		Derado		7
99		c70		Rekura		8
105		c100	Kura		9
111		c150	Rejera		10
2508	c160	Repora	!!!	10*


30		1		Jode
42		5		Notade
51		10		Ode
54		15		Tade
60		20		Jayde
66		25		Edode
72		30		Pojode
78		35		Rekude
84		40		Hade
87		c10		Idode
93		c30		Pode
96		c50		Kedeko
99		c70		Rede
105		c100	Kude
111		c150	Jehade
2508	c160	Itade	!!!
]]
