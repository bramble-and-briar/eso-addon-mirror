StoreHelper={panelName="StoreHelperPanel"
		,author="Rexorn"
		,version="0.27"
		,variableVersion=1
	}

StoreHelper.localization = {}		-- global lang files will load

local L = StoreHelper.localization	-- keep typing sane
									-- also since LUA has no table copy this must be a pointer/alias
									-- can access text strings by L['name'] or shortcut L.name



local savedVarsDefault = {
			 useCharacterSettings = false
			,buy2chat = true
			,StyleMatsToStock={
				 Molybdenum = 0		--style id 1  Molybdenum
				,Starmetal = 0		--style id 2  Starmetal
				,Manganese = 0		--style id 3  Manganese
				,Obsidian = 0		--style id 4  Obsidian
				,Corundum = 0		--style id 5  Corundum
				,Flint = 0			--style id 6  flint <- yes lower case
				,Adamantite = 0		--style id 7  Adamantite
				,Bone = 0			--style id 8  Bone
				,Moonstone = 0		--style id 9  Moonstone
				,Nickel = 0}		--style id 34 Nickel
			,AllTypes = 0
			,Imp_override = 1 		-- use ID vs name in case user changes client language setting
			,ShowPA_AddFunc_msg = true}

local savedVarsAcct  = savedVarsDefault		-- pointer not actual table copy 
local savedVarsToon  = savedVarsDefault		-- pointer not actual table copy 

-- savedVarsUsing will point to one of the above based on savedVarsToon.useCharacterSettings
-- savedVarsUsing replaces IF savedVarsToon.useCharacterSettings == true THEN savedVarsToon.*
--									ELSE savedVarsAcct.*
local savedVarsUsing = savedVarsDefault


local alltypes_mat = "NotSet"
local alltypes_matID = 0
local delay_for_store_addons = 0
local debug_msg_on = false
local gold_on_char = 0
local shop_functions_other_addon_ap = {}
local shop_functions_other_addon_gold = {}
local shop_functions_other_addon_gold_only = {}
local shop_functions_other_addon_telvar = {}
local shop_functions_changed = false
local show_buy_msg = true
local store_entry_max = 0
local ToonRaceID = 0
local ToonRaceMat = "NotSet"
local total_mats_on_hand = 0

-- some day this will handle pchat and other stuff
local function ToChat(addMessageString)
	CHAT_SYSTEM:AddMessage(addMessageString)
end


local function slash_sh_debug()
	if debug_msg_on == true then
		debug_msg_on = false
		ToChat(L.SH_debug_msg_off)
	else
		debug_msg_on = true
		ToChat(L.SH_debug_msg_on)
	end	
end


-- dump the tables of other shop functions that will be called
local function slash_sh_showother()
	ToChat(string.format(L.SH_debug_show_ap_entries, #shop_functions_other_addon_ap))
	for k,v in ipairs(shop_functions_other_addon_ap) do
		ToChat(string.format("SH: %u %s (%s)", k, v.fa, v.fd))
	end
	
	ToChat(string.format(L.SH_debug_show_gold_entries, #shop_functions_other_addon_gold))
	for k,v in ipairs(shop_functions_other_addon_gold) do
		ToChat(string.format("SH: %u %s (%s)", k, v.fa, v.fd))
	end
	
	ToChat(string.format(L.SH_debug_show_gold_only_entries, #shop_functions_other_addon_gold_only))
	for k,v in ipairs(shop_functions_other_addon_gold_only) do
		ToChat(string.format("SH: %u %s (%s)", k, v.fa, v.fd))
	end
	
	ToChat(string.format(L.SH_debug_show_telvar_entries, #shop_functions_other_addon_telvar))
	for k,v in ipairs(shop_functions_other_addon_telvar) do
		ToChat(string.format("SH: %u %s (%s)", k, v.fa, v.fd))
	end
end


local function ToChatDebug(addMessageString)
	if debug_msg_on == true then
		CHAT_SYSTEM:AddMessage(addMessageString)
	end
end


-- *****************************************************
-- functions needed to allow other addons to expand SH
-- *****************************************************
local function add_for_store(store_tbl, func2add, func_addon, func_desc)
	if func_addon == nil or func_addon == "" then
		ToChat(L.SH_err_add_for_store_no_addon_name)
		return false
	end

	if func_desc == nil or func_desc == "" then
		ToChat(string.format(L.SH_err_add_for_store_no_func_desc, func_addon))
		return false
	end

	if type(func2add) ~= "function" then		
		ToChat(string.format(L.SH_err_add_for_store_not_func, func_addon, func_desc))
		return false
	end
	
	for k, v in ipairs(store_tbl) do
		if v.func == func2add and v.fa == func_addon then
			ToChat(string.format(L.SH_err_add_for_store_already_added, func_addon, func_desc))
			return false
		end
	end
	
	table.insert(store_tbl, {func=func2add, fa=func_addon, fd=func_desc})

	if savedVarsUsing.ShowPA_AddFunc_msg == true then
		ToChat(string.format(L.SH_accepted_func, func_addon, func_desc))
	end

	return true
end


local function remove_store_func(store_tbl, func2remove, func_addon, func_desc)
	if func_addon == nil or func_addon == "" then
		ToChat(L.SH_err_remove_func_no_addon_name)
		return false
	end

	if func_desc == nil or func_desc == "" then
		ToChat(string.format(L.SH_err_remove_func_no_func_desc, func_addon))
		return false
	end
	
	if type(func2remove) ~= "function" then		
		ToChat(string.format(L.SH_err_remove_func_not_func, func_addon))
		return false
	end
	
	for k, v in ipairs(store_tbl) do
		if v.func == func2remove and v.fa == func_addon then
			local _ = table.remove(store_tbl, k)
			ToChat(string.format(L.SH_removed_func, func_addon, func_desc))
			return true
		end
	end
	
	ToChat(string.format(L.SH_err_remove_func_not_found, func_addon, func_desc))
	return false
end


local function exec_tabled_store_functions(store_tbl)
	for _,entry in ipairs(store_tbl) do
		entry.func()
	end
end


-- *****************************************************
-- functions used in StoreHelper & offered external
-- *****************************************************
local function find_store_entry_id_num(store_entry)
	local itemIDnum = 0

	-- |H1:item:45810:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|hJode|h
	local itemLink = GetStoreItemLink(store_entry, LINK_STYLE_BRACKETS)

	-- ie  45810 from above
	local itemIDstr = string.match(itemLink,"item:(.-):")

	if itemIDstr == nil then
		ToChatDebug("SHDB: itemId not found")
		itemIDnum = 0
	else
		itemIDnum = tonumber(itemIDstr)
		if itemIDnum == nil then
			ToChatDebug("SHDB: itemId not numeric")
			itemIDnum = 0
		end			
	end

	ToChatDebug(string.format("SHDB findID: itemID %d  %s  %s", 
			itemIDnum, string.sub(itemLink,2,15), itemLink))
	
	return itemIDnum
end


-- *****************************************************
-- used by internal SH shopping functions 
-- *****************************************************
local function set_alltypes_matID(raceID)
	    if raceID == ITEMSTYLE_RACIAL_BRETON   then alltypes_matID = 33251
	elseif raceID == ITEMSTYLE_RACIAL_REDGUARD then alltypes_matID = 33258
	elseif raceID == ITEMSTYLE_RACIAL_ORC      then alltypes_matID = 33257
	elseif raceID == ITEMSTYLE_RACIAL_DARK_ELF then alltypes_matID = 33253
	elseif raceID == ITEMSTYLE_RACIAL_NORD     then alltypes_matID = 33256
	elseif raceID == ITEMSTYLE_RACIAL_ARGONIAN then alltypes_matID = 33150
	elseif raceID == ITEMSTYLE_RACIAL_HIGH_ELF then alltypes_matID = 33252
	elseif raceID == ITEMSTYLE_RACIAL_WOOD_ELF then alltypes_matID = 33194
	elseif raceID == ITEMSTYLE_RACIAL_KHAJIIT  then alltypes_matID = 33255
	elseif raceID == ITEMSTYLE_RACIAL_IMPERIAL then alltypes_matID = 33254
	else alltypes_matID = 0
		ToChat(L.SH_cannot_find_alltypes_matID)
	end

	-- will not see on load because debug defaults off
	-- usable for imperial in options menu
	ToChatDebug(string.format("SHDB: alltypes_matID=%d", alltypes_matID))
end


local function MaxBuyable(mat_name, mats_needed, price)
	-- local maxBuyable = GetStoreEntryMaxBuyable(store_entry)
	-- returned number available for purchase not number affordable
	-- store seems to have 66535 so we will never reach that limit

	local maxBuyable, fraction = math.modf(gold_on_char / price)
	ToChatDebug(string.format("      gold=%u  maxBuyable=%u", gold_on_char, maxBuyable))

	if maxBuyable < mats_needed then 
		if show_buy_msg == true then
			ToChat(string.format(L.SH_buy_reduced_msg, mat_name, mats_needed, maxBuyable))
		end
		
		return maxBuyable
	else
		return mats_needed
	end
end


local function Find_and_Buy(mat_name, mats_needed, matID)
	-- define outside of loop, we don't need a new iteration for each loop -- works fine but burns cpu
	local name = "x"
	local stack, price, itemID = 0,0,0
	local store_entry = 1

	for store_entry = 1, store_entry_max do
		-- store_entry_max set in shop_for_style_mats()
		-- stack from function is how many you get for one purchase always 1 for mats
		-- don't try to use entryType return value, seems to always be 0
		_, name, stack, price, _, _, _, _, _, _, _, _, _, _, _, _ = 
			GetStoreEntryInfo(store_entry)

		if (stack == 1) and (name == mat_name) and (price <= 20) then
			ToChatDebug(string.format("SHDB: store_entry=%2u  %s %ug <= 20g", store_entry, name, price))

			itemID = find_store_entry_id_num(store_entry)
			if itemID == matID then
				-- reduce to prevent failure do to insufficient gold with warning message
				mats_needed = MaxBuyable(mat_name, mats_needed, price)

				if mats_needed > 0 then
					gold_on_char = gold_on_char - (mats_needed * price)
					BuyStoreItem(store_entry, mats_needed) 
				-- could we have failed to buy? yes :( insufficient gold prevented & also has a warning
				-- hope other issues do too because I am not aware of a return code to check on BuyStoreItem...
				-- BuyStoreItem plays nice with mats_needed of 0 but why call it
				end

				if show_buy_msg == true then
					ToChat(string.format(L.SH_bought_mats_msg, mats_needed, mat_name))
				end
				return mats_needed
			else
				ToChat("SH: Rats! Matched name but not itemID !?!")
			end
		end
	end
	-- if we reach this point no mats were found for sale so we bought 0
	return 0
end


local function stylemat_check_buy(style_index, mat_name, mats_desired, matID)
	local mats_on_hand = GetCurrentSmithingStyleItemCount(style_index)
	ToChatDebug(string.format("SHDB: chk_buy sid=%d want=%d  have=%d  iid=%d %s ", 
		style_index, mats_desired, mats_on_hand, matID, mat_name))

	total_mats_on_hand = total_mats_on_hand + mats_on_hand
	
	if mats_on_hand < mats_desired then
		local mats_needed = mats_desired - mats_on_hand
		local mats_bought = Find_and_Buy(mat_name, mats_needed, matID) 

		total_mats_on_hand = total_mats_on_hand + mats_bought 
	end
end -- func


local function shop_for_style_mats()
	store_entry_max = GetNumStoreItems()		-- local to SH for use in other routines
	total_mats_on_hand = 0						-- local to SH for use in other routines
	gold_on_char = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
	-- testing shows the update is slow, might buy several items before 1st gold
	-- change registers -> read here & track internally after each buy
	
	-- stylemat_check_buy does not change passed in mats_desired
	stylemat_check_buy(1, L.SH_mat_breton,   savedVarsUsing.StyleMatsToStock.Molybdenum, 33251)
	stylemat_check_buy(2, L.SH_mat_redguard, savedVarsUsing.StyleMatsToStock.Starmetal,  33258)
	stylemat_check_buy(3, L.SH_mat_orc,      savedVarsUsing.StyleMatsToStock.Manganese,  33257)
	stylemat_check_buy(4, L.SH_mat_darkelf,  savedVarsUsing.StyleMatsToStock.Obsidian,   33253)
	stylemat_check_buy(5, L.SH_mat_nord,     savedVarsUsing.StyleMatsToStock.Corundum,   33256)
	stylemat_check_buy(6, L.SH_mat_argonian, savedVarsUsing.StyleMatsToStock.Flint,      33150)
	stylemat_check_buy(7, L.SH_mat_highelf,  savedVarsUsing.StyleMatsToStock.Adamantite, 33252)
	stylemat_check_buy(8, L.SH_mat_woodelf,  savedVarsUsing.StyleMatsToStock.Bone,       33194)
	stylemat_check_buy(9, L.SH_mat_khajiit,  savedVarsUsing.StyleMatsToStock.Moonstone,  33255)

	ToChatDebug(string.format("SHDB: all_types want %u have %u pad with %s",
		savedVarsUsing.AllTypes, total_mats_on_hand, alltypes_mat))

	
	local needed_for_alltypes_goal = 0
	if ToonRaceID == ITEMSTYLE_RACIAL_IMPERIAL and alltypes_mat == L.SH_mat_imperial then
		-- Imp who is gonna pad all mats totals with Nickel, need to have Nickel bought first for totals
		stylemat_check_buy(34, L.SH_mat_imperial, savedVarsUsing.StyleMatsToStock.Nickel, 33254)

		if total_mats_on_hand < savedVarsUsing.AllTypes then
			-- update needed_ because we just bought Nickel
			needed_for_alltypes_goal = savedVarsUsing.AllTypes - total_mats_on_hand
			Find_and_Buy(alltypes_mat, needed_for_alltypes_goal, alltypes_matID)
		end
	else
		-- everyone else, check all types goal first to skip Nickel
		if total_mats_on_hand < savedVarsUsing.AllTypes then
			needed_for_alltypes_goal = savedVarsUsing.AllTypes - total_mats_on_hand
			Find_and_Buy(alltypes_mat, needed_for_alltypes_goal, alltypes_matID)
		end
		
		stylemat_check_buy(34, L.SH_mat_imperial, savedVarsUsing.StyleMatsToStock.Nickel, 33254)
	end
	
	ToChatDebug("SHDB: end mats -----")

end -- func


-- *****************************************************
-- store flow control
-- might be/probably will be executed as Fire&Forget 
--    out of onOpenStore
-- *****************************************************
local function shop_by_store_type()
	local gold, ap, telvar, vouchers, eventcurr = GetStoreCurrencyTypes()

	ToChatDebug("SHDB: We are here to help you shop/debug -----")
	if gold      then ToChatDebug("SHDB: store takes gold") end
	if ap        then ToChatDebug("SHDB: store takes ap") end
	if telvar    then ToChatDebug("SHDB: store takes telvar") end
	if vouchers  then ToChatDebug("SHDB: store takes vouchers - skip") end 
	if eventcurr then ToChatDebug("SHDB: store takes eventcurr - skip") end	

	-- vouchers & event-curr are to hard to get & not likely to need lots of buys
	-- skip any stores that take them, even if they might take other currency
	if eventcurr then return end
	if vouchers  then return end 

	if gold then
		if ap or telvar then
			exec_tabled_store_functions(shop_functions_other_addon_gold)
		else
			shop_for_style_mats()
			exec_tabled_store_functions(shop_functions_other_addon_gold_only)
		end
	elseif ap then
		exec_tabled_store_functions(shop_functions_other_addon_ap)
	elseif telvar then
		exec_tabled_store_functions(shop_functions_other_addon_telvar)
	--else
		-- crown store merchants fall here
		-- cannot spend money so we will not have any hooks here
	end 
	
	ToChatDebug("SHDB: end all stores")

end


local function onOpenStore(event_code)
	-- set show_buy_msg here to simplify option menu logic
	-- could set later but that would complicate adding new shop_ types later
	show_buy_msg = savedVarsUsing.buy2chat

	if delay_for_store_addons == 0 then
		shop_by_store_type()
	else
		-- delay is in millisecons but is approximate not exact. test 300ms delayed 502ms
		zo_callLater(function() shop_by_store_type() end, delay_for_store_addons)
		-- NOTE: use wrapper "function() shop_by_store_type() end" or 
		--       use "StoreHelper.shop_by_store_type" and 
		--           define StoreHelper.shop_by_store_type w/o LOCAL FLAG
		-- NOTE: this is fire and forget!  will continue to process logic from here
	end
	
end -- func-onOpenStore


-- *****************************************************
-- option panel setup
-- *****************************************************
local function init_name_vars()
-- custom languages will take data from SH_default_lang.lua & set SH_load_ZOS_names false

-- if a new race is added define SH_style_*, SH_mat_*, and SH_OptMenu_*
-- yes in tables flint is lowercase but it matches the store entry. Argonians get no respect :(
	if L.SH_load_ZOS_names == true then
		L.SH_style_breton	= GetItemStyleName(ITEMSTYLE_RACIAL_BRETON)
		L.SH_style_redguard	= GetItemStyleName(ITEMSTYLE_RACIAL_REDGUARD)
		L.SH_style_orc		= GetItemStyleName(ITEMSTYLE_RACIAL_ORC)
		L.SH_style_darkelf	= GetItemStyleName(ITEMSTYLE_RACIAL_DARK_ELF)
		L.SH_style_nord		= GetItemStyleName(ITEMSTYLE_RACIAL_NORD)
		L.SH_style_argonian	= GetItemStyleName(ITEMSTYLE_RACIAL_ARGONIAN)
		L.SH_style_highelf	= GetItemStyleName(ITEMSTYLE_RACIAL_HIGH_ELF)
		L.SH_style_woodelf	= GetItemStyleName(ITEMSTYLE_RACIAL_WOOD_ELF)
		L.SH_style_khajiit	= GetItemStyleName(ITEMSTYLE_RACIAL_KHAJIIT)
		L.SH_style_imperial	= GetItemStyleName(ITEMSTYLE_RACIAL_IMPERIAL)

		-- see scrap notes GetSmithingStyleItemInfo entry
		L.SH_mat_breton		= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_BRETON))
		L.SH_mat_redguard	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_REDGUARD))
		L.SH_mat_orc		= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_ORC))
		L.SH_mat_darkelf	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_DARK_ELF))
		L.SH_mat_nord		= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_NORD))
		L.SH_mat_argonian	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_ARGONIAN))
		L.SH_mat_highelf	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_HIGH_ELF))
		L.SH_mat_woodelf	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_WOOD_ELF))
		L.SH_mat_khajiit	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_KHAJIIT))
		L.SH_mat_imperial	= GetItemLinkName(GetItemStyleMaterialLink(ITEMSTYLE_RACIAL_IMPERIAL))
		
	end
	
	-- assembling option menu data now that all parts are set
	-- L.SH_OptMenu_breton is syntax shortcut for L['SH_OptMenu_breton']
	local fmtopt = "ID %u  %s - %s"
	L.SH_OptMenu_breton		= string.format(fmtopt, ITEMSTYLE_RACIAL_BRETON,   L.SH_style_breton,   L.SH_mat_breton)
	L.SH_OptMenu_redguard	= string.format(fmtopt, ITEMSTYLE_RACIAL_REDGUARD, L.SH_style_redguard, L.SH_mat_redguard)
	L.SH_OptMenu_orc	  	= string.format(fmtopt, ITEMSTYLE_RACIAL_ORC,      L.SH_style_orc,      L.SH_mat_orc)
	L.SH_OptMenu_darkelf	= string.format(fmtopt, ITEMSTYLE_RACIAL_DARK_ELF, L.SH_style_darkelf,  L.SH_mat_darkelf)
	L.SH_OptMenu_nord		= string.format(fmtopt, ITEMSTYLE_RACIAL_NORD,     L.SH_style_nord,     L.SH_mat_nord)
	L.SH_OptMenu_argonian	= string.format(fmtopt, ITEMSTYLE_RACIAL_ARGONIAN, L.SH_style_argonian, L.SH_mat_argonian)
	L.SH_OptMenu_highelf	= string.format(fmtopt, ITEMSTYLE_RACIAL_HIGH_ELF, L.SH_style_highelf,  L.SH_mat_highelf)
	L.SH_OptMenu_woodelf	= string.format(fmtopt, ITEMSTYLE_RACIAL_WOOD_ELF, L.SH_style_woodelf,  L.SH_mat_woodelf)
	L.SH_OptMenu_khajiit	= string.format(fmtopt, ITEMSTYLE_RACIAL_KHAJIIT,  L.SH_style_khajiit,  L.SH_mat_khajiit)
	L.SH_OptMenu_imperial	= string.format(fmtopt, ITEMSTYLE_RACIAL_IMPERIAL, L.SH_style_imperial, L.SH_mat_imperial)

	-- Imperial Race All Mat Override text choice build here
	fmtopt ="%s - %s"
	L.SH_imp_ovr_breton		= string.format(fmtopt, L.SH_style_breton,   L.SH_mat_breton)
	L.SH_imp_ovr_redguard	= string.format(fmtopt, L.SH_style_redguard, L.SH_mat_redguard)
	L.SH_imp_ovr_orc	  	= string.format(fmtopt, L.SH_style_orc,      L.SH_mat_orc)
	L.SH_imp_ovr_darkelf	= string.format(fmtopt, L.SH_style_darkelf,  L.SH_mat_darkelf)
	L.SH_imp_ovr_nord		= string.format(fmtopt, L.SH_style_nord,     L.SH_mat_nord)
	L.SH_imp_ovr_argonian	= string.format(fmtopt, L.SH_style_argonian, L.SH_mat_argonian)
	L.SH_imp_ovr_highelf	= string.format(fmtopt, L.SH_style_highelf,  L.SH_mat_highelf)
	L.SH_imp_ovr_woodelf	= string.format(fmtopt, L.SH_style_woodelf,  L.SH_mat_woodelf)
	L.SH_imp_ovr_khajiit	= string.format(fmtopt, L.SH_style_khajiit,  L.SH_mat_khajiit)
	L.SH_imp_ovr_imperial	= string.format(fmtopt, L.SH_style_imperial, L.SH_mat_imperial)
	
	
end -- func-init_name_vars


local function setupPanel()
	local panelData = {type = "panel", name = L.SH_mod_name, 
		 				displayName = L.SH_display_name, author = StoreHelper.author, 
		 				version = StoreHelper.version, registerForRefresh = true}

	-- just block assign values until IF THEN
	local optionsData = {
		 [1] = {type = "header", name = L.SH_OptMenu_header_name }
		,[2] = {type = "description", text = L.SH_OptMenu_description }
		,[3] = {type = "checkbox", name = L.SH_OptMenu_chk_UseToon_name, 
				tooltip = L.SH_OptMenu_chk_UseToon_tooltip,
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
		,[4] = {type = "checkbox", name = L.SH_OptMenu_chk_buy2chat_name, 
				tooltip = L.SH_OptMenu_chk_buy2chat_tooltip,
				getFunc = function() return savedVarsUsing.buy2chat end,
				setFunc = function(enable) savedVarsUsing.buy2chat = enable end
			}
		,[5] = {type = "divider"}
		}

	
	if ToonRaceID == ITEMSTYLE_RACIAL_IMPERIAL then
		-- skip this table line
	else
		table.insert(optionsData, {type = "description",
				text = string.format(L['SH_OptMenu_AllTypes_desc'], alltypes_mat)})
	end
		
	-- now continue inserts of data
	-- not sure what efficiency loss is, but it does simplify moving order of entries!
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_AllTypes_tooltip, 
			name = L.SH_OptMenu_AllTypes_name,
			getFunc = function() return savedVarsUsing.AllTypes end,
			setFunc = function(val) savedVarsUsing.AllTypes = val end})

	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_breton,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Molybdenum end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Molybdenum = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_redguard,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Starmetal end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Starmetal = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_orc,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Manganese end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Manganese = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_darkelf,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Obsidian end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Obsidian = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_nord,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Corundum end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Corundum = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_argonian,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Flint end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Flint = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_highelf,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Adamantite end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Adamantite = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_woodelf,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Bone end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Bone = val end})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_khajiit,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Moonstone end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Moonstone = val end})

	table.insert(optionsData, {type = "divider"})
	table.insert(optionsData, {type = "slider", default = 0, min = 0, max = 250, clampInput = false,
			tooltip = L.SH_OptMenu_box_genMat_tooltip, 
			name = L.SH_OptMenu_imperial,
			getFunc = function() return savedVarsUsing.StyleMatsToStock.Nickel end,
			setFunc = function(val) savedVarsUsing.StyleMatsToStock.Nickel = val end})

	table.insert(optionsData, {type = "description", text = L['SH_OptMenu_Nickel_note']})

	table.insert(optionsData, {type = "dropdown", name = L['SH_OptMenu_Imp_override_name'],
			tooltip = L['SH_OptMenu_Imp_override_tooltip'],
			choices = {L.SH_imp_ovr_breton,  L.SH_imp_ovr_redguard, L.SH_imp_ovr_orc,
					   L.SH_imp_ovr_darkelf, L.SH_imp_ovr_nord, L.SH_imp_ovr_argonian,
					   L.SH_imp_ovr_highelf, L.SH_imp_ovr_woodelf, L.SH_imp_ovr_khajiit,
					   L.SH_imp_ovr_imperial},
			choicesValues = {ITEMSTYLE_RACIAL_BRETON, ITEMSTYLE_RACIAL_REDGUARD, ITEMSTYLE_RACIAL_ORC,
							 ITEMSTYLE_RACIAL_DARK_ELF, ITEMSTYLE_RACIAL_NORD, ITEMSTYLE_RACIAL_ARGONIAN,
							 ITEMSTYLE_RACIAL_HIGH_ELF, ITEMSTYLE_RACIAL_WOOD_ELF, ITEMSTYLE_RACIAL_KHAJIIT,
							 ITEMSTYLE_RACIAL_IMPERIAL},
						-- order MUST match between tables
			getFunc = function() return savedVarsUsing.Imp_override end,
			setFunc = function(var) 
				savedVarsUsing.Imp_override = var
				if ToonRaceID == ITEMSTYLE_RACIAL_IMPERIAL then
					alltypes_mat = GetItemLinkName(GetItemStyleMaterialLink(var))
					-- only update mat used for imperials
					set_alltypes_matID(var)
				end
			end
			})

	table.insert(optionsData, {type = "description", text = L['SH_OptMenu_Imp_override_desc'] })

	table.insert(optionsData, {type = "divider"})
	table.insert(optionsData, {type = "checkbox", name = L.SH_OptMenu_ShowPA_AddFunc_name, 
			tooltip = L.SH_OptMenu_ShowPA_AddFunc_tooltip,
			getFunc = function() return savedVarsUsing.ShowPA_AddFunc_msg end,
			setFunc = function(enable) savedVarsUsing.ShowPA_AddFunc_msg = enable end
			})


	-- CANNOT use mod name L['SH_mod_name'] here 
	LibAddonMenu2:RegisterAddonPanel(StoreHelper.panelName, panelData)
	LibAddonMenu2:RegisterOptionControls(StoreHelper.panelName, optionsData)
	
end -- func-setupPanel


local function check_PersonalAssistant_integration()
	if PersonalAssistant and PersonalAssistant.EventManager then
		-- both pieces are defined (else one/both would be nil lua takes ELSE branch)
			
		-- PA keeps a table list of all registered events in PAEM._registeredIdentifierSet -> get a copy
		local PAEM = PersonalAssistant.EventManager
		local PAEM_registered_events = PAEM.getAllEventsInSet()
		--d(PAEM_registered_events)
		
		if PersonalAssistant.Junk then 
			local PAJ_AddonName = PersonalAssistant.Junk.AddonName
			-- build name string used as key by PersonalAssistant.EventManager._registeredIdentifierSet
			local SH_PAJunk_EV = table.concat({"EV", EVENT_OPEN_STORE, PAJ_AddonName, "OpenStore"}, "_")

			if PAEM_registered_events[SH_PAJunk_EV] == nil then
				-- not registered do nothing
			else
				-- PA Junk found in PA event table so StoreHelper will wait for it
				delay_for_store_addons = 200
			end
		end
		
		-- do NOT use IF-ELSEIF here!  what if PAJunk exists but not used
		-- skip check for PARepair as callback, that happens when PAJunk is running & delay above handles that
		if PersonalAssistant.Repair then
			local PAR_AddonName = PersonalAssistant.Repair.AddonName
			-- might exist as an event or (if pa.junk has event) as a callback
			-- build name string used as key by PersonalAssistant.EventManager._registeredIdentifierSet
			local SH_PARepair_EV = table.concat({"EV", EVENT_OPEN_STORE, PAR_AddonName, "OpenStore"}, "_")
			--local SH_PARepair_CB = table.concat({"CB", EVENT_OPEN_STORE, PAR_AddonName, "OpenStore"}, "_")

			if PAEM_registered_events[SH_PARepair_EV] == nil then
			--and PAEM_registered_events[SH_PARepair_CB] == nil then
				-- not registered do nothing
			else
				-- PA Repair found as event
				delay_for_store_addons = 200
			end
		end
		
	end
	
end


-- *****************************************************
-- on Player event - main setup
-- *****************************************************
local function onPlayer(EventCode)
	--ToonRaceID = 34  -- for testing Imperial race
	ToonRaceID = GetUnitRaceId("player")
	
	if ToonRaceID == ITEMSTYLE_RACIAL_IMPERIAL then
		alltypes_mat = GetItemLinkName(GetItemStyleMaterialLink(savedVarsUsing.Imp_override))
		set_alltypes_matID(savedVarsUsing.Imp_override)
	else
		alltypes_mat = GetItemLinkName(GetItemStyleMaterialLink(ToonRaceID))
		set_alltypes_matID(ToonRaceID)
	end

	init_name_vars()
	setupPanel()

	if delay_for_store_addons > 0 then
		if savedVarsUsing.ShowPA_AddFunc_msg == true then
			ToChat(L.SH_PA_integration_msg)
		end
	end

	EVENT_MANAGER:UnregisterForEvent("StoreHelperActivated", EVENT_PLAYER_ACTIVATED)
end


-- *****************************************************
-- On Addon Loaded entry point
-- *****************************************************
local function Init(EventCode, AddonName)
	-- event is triggered for EACH addon loaded <load 5 addons fire 5 triggers - sigh>
	-- & do NOT just fire for 1st one cause we need libs loaded & initialized before we start
	if AddonName ~= L.SH_mod_name then return end
	
	savedVarsAcct = ZO_SavedVars:NewAccountWide("StoreHelperAcct", -- file name
				StoreHelper.variableVersion,			-- if saved version diff then wipe file
				nil,									-- optional name in subtable (default="Default")
				savedVarsDefault)						-- defaults to use if a var is not in saved file

	savedVarsToon = ZO_SavedVars:NewCharacterIdSettings("StoreHelperToon",
				StoreHelper.variableVersion,		
				nil,							
				savedVarsDefault)						-- trying to use savedVarsAcct for default makes a mess
														-- because savedVarsAcct is a pointer not a table


	if savedVarsToon.useCharacterSettings == true then
		savedVarsUsing = savedVarsToon
	else
		savedVarsUsing = savedVarsAcct
	end
		

	check_PersonalAssistant_integration()


	-- do NOT setup panel here because we need SH loaded to create local THEN lang files loaded THEN appied to panel
	--init_name_vars()
	--setupPanel()

	SLASH_COMMANDS['/sh_debug'] = slash_sh_debug				-- do not use uppercase initials
	SLASH_COMMANDS['/sh_showother'] = slash_sh_showother
	
	-- drop on_loaded cause only init once & setup to trigger when store opened
	EVENT_MANAGER:UnregisterForEvent("StoreHelperInit", EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:RegisterForEvent("StoreHelperOpenStore", EVENT_OPEN_STORE, onOpenStore)
	EVENT_MANAGER:RegisterForEvent("StoreHelperActivated", EVENT_PLAYER_ACTIVATED, onPlayer)
end -- func-Init


EVENT_MANAGER:RegisterForEvent("StoreHelperInit", EVENT_ADD_ON_LOADED, Init)



-- ****************************************************
-- functions made external for other AddOns
-- ****************************************************
local function add_for_store_takes_ap(func2add, func_addon, func_desc)
	return add_for_store(shop_functions_other_addon_ap, func2add, func_addon, func_desc)
end

local function add_for_store_takes_gold(func2add, func_addon, func_desc)
	return add_for_store(shop_functions_other_addon_gold, func2add, func_addon, func_desc)
end

local function add_for_store_takes_gold_only(func2add, func_addon, func_desc)
	return add_for_store(shop_functions_other_addon_gold_only, func2add, func_addon, func_desc)
end

local function add_for_store_takes_telvar(func2add, func_addon, func_desc)
	return add_for_store(shop_functions_other_addon_telvar, func2add, func_addon, func_desc)
end

local function remove_store_func_ap(func2remove, func_addon, func_desc)
	return remove_store_func(shop_functions_other_addon_ap, func2remove, func_addon, func_desc)
end

local function remove_store_func_gold(func2remove, func_addon, func_desc)
	return remove_store_func(shop_functions_other_addon_gold, func2remove, func_addon, func_desc)
end

local function remove_store_func_gold_only(func2remove, func_addon, func_desc)
	return remove_store_func(shop_functions_other_addon_gold_only, func2remove, func_addon, func_desc)
end

local function remove_store_func_telvar(func2remove, func_addon, func_desc)
	return remove_store_func(shop_functions_other_addon_telvar, func2remove, func_addon, func_desc)
end

local function get_show_buy_msg()
	return show_buy_msg
end

local function get_show_debug_msg()
	return debug_msg_on
end

-- end of helpers for other addons



StoreHelper.shared = {
	 add_for_store_takes_ap			= add_for_store_takes_ap
	,add_for_store_takes_gold		= add_for_store_takes_gold
	,add_for_store_takes_gold_only	= add_for_store_takes_gold_only
	,add_for_store_takes_telvar		= add_for_store_takes_telvar
		-- *function* function to add, *string* addon name, *string* addon short-description
		-- returns *boolean* true if loaded otherwise false

			
	,remove_store_func_ap			= remove_store_func_ap
	,remove_store_func_gold			= remove_store_func_gold
	,remove_store_func_gold_only	= remove_store_func_gold_only
	,remove_store_func_telvar		= remove_store_func_telvar
		-- *function* function to remove, *string* addon name, *string* addon short-description
		-- returns *boolean* true if removed otherwise false

	,get_show_buy_msg 				= get_show_buy_msg
		-- returns *boolean* value of SH "Buy Msgs to Chat"
		-- use this in your store function not in your EVENT_ADD_ON_LOADED function
		-- in case user changes setting after load
		
	,get_show_debug_msg				= get_show_debug_msg
		-- returns *boolean* value of debug_msg_on set by /sh_debug
		-- use this in your store function not in your EVENT_ADD_ON_LOADED function
		-- in case user changes setting after load
		
	,find_store_entry_id_num		= find_store_entry_id_num
		-- *integer* story entry number 
		-- returns *integer* itemID number for the store entry
		-- returns itemID = 0 on error
	}


--[[ notes about having another addon push a function into the StoreHelper addon
		local your_func() <stuff> end

		local SHx = StoreHelper.shared
		SHx['add_for_store_takes_gold_only'](your_func, YourAddon.name, "some text desc")
		
		or
		
		StoreHelper.shared.add_for_store_takes_gold_only(your_func, YourAddon.name, "some text desc")

		-- notice the [' '] around the table function name
		-- notice NO () after your_func.  it is being passed in not called
		
		
		-- your_func can use any variable it could if called from your addon
		-- i've tested with locals in the func, outside the func, and AddOn.variables
		
		-- i've tested local function x(), function Addon.x(), and table referenced functions



	]]


