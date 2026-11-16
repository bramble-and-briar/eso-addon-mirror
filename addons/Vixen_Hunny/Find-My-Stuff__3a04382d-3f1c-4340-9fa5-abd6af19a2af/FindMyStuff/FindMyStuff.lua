FindMyStuff = FindMyStuff or {}
FindMyStuff.Name = "FindMyStuff"
FindMyStuff.Author = "Vixen Hunny"
FindMyStuff.Version = "1.1.0"
FindMyStuff.SettingsVersion = "1.0"
local pmax = 184000
local gmin = 1
local gmax = pmax
local total_results = 0
local max_results = 100
local current_cycle = 1
local cycles = 5
local cycle_size = 0
local base_suffix = ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"
local link_suffix = ""
local dump_output = {}
local dump_position = 1

-- Nil-safe table builder: skips entries whose ESO constant key is nil in this API version
local function FMS_BuildTable(list)
	local t = {}
	for i = 1, #list do
		if list[i][1] ~= nil then
			t[list[i][1]] = list[i][2]
		end
	end
	return t
end

FindMyStuff.TraitTable = FMS_BuildTable({
	{ITEM_TRAIT_TYPE_NONE, "None"},
	{ITEM_TRAIT_TYPE_ARMOR_DIVINES, "Divines"},
	{ITEM_TRAIT_TYPE_ARMOR_EXPLORATION, "Invigorating"},   -- pre-Update 28 name
	{ITEM_TRAIT_TYPE_ARMOR_INVIGORATING, "Invigorating"},  -- current name (renamed from Exploration)
	{ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE, "Impenetrable"},
	{ITEM_TRAIT_TYPE_ARMOR_INFUSED, "Infused"},
	{ITEM_TRAIT_TYPE_ARMOR_INTRICATE, "Intricate"},
	{ITEM_TRAIT_TYPE_ARMOR_NIRNHONED, "Nirnhoned"},
	{ITEM_TRAIT_TYPE_ARMOR_ORNATE, "Ornate"},
	{ITEM_TRAIT_TYPE_ARMOR_REINFORCED, "Reinforced"},
	{ITEM_TRAIT_TYPE_ARMOR_STURDY, "Sturdy"},
	{ITEM_TRAIT_TYPE_ARMOR_TRAINING, "Training"},
	{ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED, "Well-Fitted"},
	{ITEM_TRAIT_TYPE_WEAPON_CHARGED, "Charged"},
	{ITEM_TRAIT_TYPE_WEAPON_DECISIVE, "Decisive"},
	{ITEM_TRAIT_TYPE_WEAPON_DEFENDING, "Defending"},
	{ITEM_TRAIT_TYPE_WEAPON_INFUSED, "Infused"},
	{ITEM_TRAIT_TYPE_WEAPON_INTRICATE, "Intricate"},
	{ITEM_TRAIT_TYPE_WEAPON_NIRNHONED, "Nirnhoned"},
	{ITEM_TRAIT_TYPE_WEAPON_ORNATE, "Ornate"},
	{ITEM_TRAIT_TYPE_WEAPON_POWERED, "Powered"},
	{ITEM_TRAIT_TYPE_WEAPON_PRECISE, "Precise"},
	{ITEM_TRAIT_TYPE_WEAPON_SHARPENED, "Sharpened"},
	{ITEM_TRAIT_TYPE_WEAPON_TRAINING, "Training"},
	{ITEM_TRAIT_TYPE_JEWELRY_ARCANE, "Arcane"},
	{ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY, "Bloodthirsty"},
	{ITEM_TRAIT_TYPE_JEWELRY_HARMONY, "Harmony"},
	{ITEM_TRAIT_TYPE_JEWELRY_HEALTHY, "Healthy"},
	{ITEM_TRAIT_TYPE_JEWELRY_INFUSED, "Infused"},
	{ITEM_TRAIT_TYPE_JEWELRY_INTRICATE, "Intricate"},
	{ITEM_TRAIT_TYPE_JEWELRY_ORNATE, "Ornate"},
	{ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE, "Protective"},
	{ITEM_TRAIT_TYPE_JEWELRY_ROBUST, "Robust"},
	{ITEM_TRAIT_TYPE_JEWELRY_SWIFT, "Swift"},
	{ITEM_TRAIT_TYPE_JEWELRY_TRIUNE, "Triune"},
	{ITEM_TRAIT_TYPE_ARMOR_AGGRESSIVE, "Aggressive"},
	{ITEM_TRAIT_TYPE_ARMOR_AUGMENTED, "Augmented"},
	{ITEM_TRAIT_TYPE_ARMOR_BOLSTERED, "Bolstered"},
	{ITEM_TRAIT_TYPE_ARMOR_FOCUSED, "Focused"},
	{ITEM_TRAIT_TYPE_ARMOR_PROLIFIC, "Prolific"},
	{ITEM_TRAIT_TYPE_ARMOR_QUICKENED, "Quickened"},
	{ITEM_TRAIT_TYPE_ARMOR_SHATTERING, "Shattering"},
	{ITEM_TRAIT_TYPE_ARMOR_SOOTHING, "Soothing"},
	{ITEM_TRAIT_TYPE_ARMOR_VIGOROUS, "Vigorous"},
	{ITEM_TRAIT_TYPE_JEWELRY_AGGRESSIVE, "Aggressive"},
	{ITEM_TRAIT_TYPE_JEWELRY_AUGMENTED, "Augmented"},
	{ITEM_TRAIT_TYPE_JEWELRY_BOLSTERED, "Bolstered"},
	{ITEM_TRAIT_TYPE_JEWELRY_FOCUSED, "Focused"},
	{ITEM_TRAIT_TYPE_JEWELRY_PROLIFIC, "Prolific"},
	{ITEM_TRAIT_TYPE_JEWELRY_QUICKENED, "Quickened"},
	{ITEM_TRAIT_TYPE_JEWELRY_SHATTERING, "Shattering"},
	{ITEM_TRAIT_TYPE_JEWELRY_SOOTHING, "Soothing"},
	{ITEM_TRAIT_TYPE_JEWELRY_VIGOROUS, "Vigorous"},
	{ITEM_TRAIT_TYPE_WEAPON_AGGRESSIVE, "Aggressive"},
	{ITEM_TRAIT_TYPE_WEAPON_AUGMENTED, "Augmented"},
	{ITEM_TRAIT_TYPE_WEAPON_BOLSTERED, "Bolstered"},
	{ITEM_TRAIT_TYPE_WEAPON_FOCUSED, "Focused"},
	{ITEM_TRAIT_TYPE_WEAPON_PROLIFIC, "Prolific"},
	{ITEM_TRAIT_TYPE_WEAPON_QUICKENED, "Quickened"},
	{ITEM_TRAIT_TYPE_WEAPON_SHATTERING, "Shattering"},
	{ITEM_TRAIT_TYPE_WEAPON_SOOTHING, "Soothing"},
	{ITEM_TRAIT_TYPE_WEAPON_VIGOROUS, "Vigorous"},
})

FindMyStuff.EquipTable = FMS_BuildTable({
	{EQUIP_TYPE_INVALID, ""},
	{EQUIP_TYPE_CHEST, "chest"},
	{EQUIP_TYPE_COSTUME, "costume"},
	{EQUIP_TYPE_FEET, "feet"},
	{EQUIP_TYPE_HAND, "hand"},
	{EQUIP_TYPE_HEAD, "head"},
	{EQUIP_TYPE_LEGS, "legs"},
	{EQUIP_TYPE_MAIN_HAND, "weapon"},
	{EQUIP_TYPE_NECK, "necklace"},
	{EQUIP_TYPE_OFF_HAND, "weapon"},
	{EQUIP_TYPE_ONE_HAND, "weapon"},
	{EQUIP_TYPE_POISON, "poison"},
	{EQUIP_TYPE_RING, "ring"},
	{EQUIP_TYPE_SHOULDERS, "shoulders"},
	{EQUIP_TYPE_TWO_HAND, "weapon"},
	{EQUIP_TYPE_WAIST, "waist"},
})
FindMyStuff.EquipTable[16] = "robe"  --Handle robe/shirts
FindMyStuff.EquipTable[17] = "shirt"

FindMyStuff.WeaponTable = FMS_BuildTable({
	{WEAPONTYPE_RUNE, "rune"},
	{WEAPONTYPE_NONE, "none"},
	{WEAPONTYPE_AXE, "axe"},
	{WEAPONTYPE_BOW, "bow"},
	{WEAPONTYPE_DAGGER, "dagger"},
	{WEAPONTYPE_FIRE_STAFF, "firestaff"},
	{WEAPONTYPE_FROST_STAFF, "froststaff"},
	{WEAPONTYPE_HAMMER, "mace"},
	{WEAPONTYPE_HEALING_STAFF, "healingstaff"},
	{WEAPONTYPE_LIGHTNING_STAFF, "lightningstaff"},
	{WEAPONTYPE_SHIELD, "shield"},
	{WEAPONTYPE_SWORD, "sword"},
	{WEAPONTYPE_TWO_HANDED_AXE, "battleaxe"},
	{WEAPONTYPE_TWO_HANDED_HAMMER, "maul"},
	{WEAPONTYPE_TWO_HANDED_SWORD, "greatsword"},
})

FindMyStuff.ArmorTable = FMS_BuildTable({
	{ARMORTYPE_NONE, "none"},
	{ARMORTYPE_HEAVY, "heavy"},
	{ARMORTYPE_LIGHT, "light"},
	{ARMORTYPE_MEDIUM, "medium"},
})

--One s removed from each for optimum matching ease
FindMyStuff.EquipSynonymTable = {
	--Light
	[1]= {[1]="hat",[2]=EQUIP_TYPE_HEAD,[3]="light"},
	[2]= {[1]="robe",[2]=16,[3]="light"},
	[3]= {[1]="shirt",[2]=17,[3]="light"},
	[4]= {[1]="epaulet",[2]=EQUIP_TYPE_SHOULDERS,[3]="light"},
	[5]= {[1]="sash",[2]=EQUIP_TYPE_WAIST,[3]="light"},
	[6]= {[1]="breeche",[2]=EQUIP_TYPE_LEGS,[3]="light"},
	[7]= {[1]="shoe",[2]=EQUIP_TYPE_FEET,[3]="light"},
	[8]= {[1]="glove",[2]=EQUIP_TYPE_HAND,[3]="light"},
	--Medium
	[9]= {[1]="helmet",[2]=EQUIP_TYPE_HEAD,[3]="medium"},
	[10]= {[1]="jack",[2]=EQUIP_TYPE_CHEST,[3]="medium"},
	[11]= {[1]="armcop",[2]=EQUIP_TYPE_SHOULDERS,[3]="medium"},
	[12]= {[1]="belt",[2]=EQUIP_TYPE_WAIST,[3]="medium"},
	[13]= {[1]="guard",[2]=EQUIP_TYPE_LEGS,[3]="medium"},
	[14]= {[1]="boot",[2]=EQUIP_TYPE_FEET,[3]="medium"},
	[15]= {[1]="bracer",[2]=EQUIP_TYPE_HAND,[3]="medium"},
	--Heavy
	[16]= {[1]="helm",[2]=EQUIP_TYPE_HEAD,[3]="heavy"},
	[17]= {[1]="cuiras",[2]=EQUIP_TYPE_CHEST,[3]="heavy"},
	[18]= {[1]="pauldron",[2]=EQUIP_TYPE_SHOULDERS,[3]="heavy"},
	[19]= {[1]="girdle",[2]=EQUIP_TYPE_WAIST,[3]="heavy"},
	[20]= {[1]="greave",[2]=EQUIP_TYPE_LEGS,[3]="heavy"},
	[21]= {[1]="sabaton",[2]=EQUIP_TYPE_FEET,[3]="heavy"},
	[22]= {[1]="gauntlet",[2]=EQUIP_TYPE_HAND,[3]="heavy"}
}

FindMyStuff.ItemTable = {built=0,items={},}	

FindMyStuff.Default = {quality=364,level=50}
-- User settings (edited from the LibAddonMenu panel)
FindMyStuff.SettingDefaults = {
	showLogin = true,    -- print the "loaded" line on login
	autoScan = true,     -- rescan bags after looting
	maxResults = 100,    -- lines per page for chat output
	traderPages = 10,    -- default pages per guild for trader scans
	traderChat = true,   -- print trader matches to chat as well as the UI
	windowLocked = false,
}
ZO_CreateStringId("SI_BINDING_NAME_FINDMYSTUFF_TOGGLE", "Open Find My Stuff")
-- Acts as a bridge between input and cycle
local function bridge(text,min,max,trait,etype,weight)
	if min == nil then gmin = 1 else gmin = min end
	if max == nil then gmax = pmax else gmax = max end
	
	trait = trait:lower()	
		
	--equipment type poison doesn't have results until over 75k, stops by 82k and resumes at 135k then 152k. Partial selective search for beginning for efficiency.
	if etype ~= "" and etype:lower() == "poison" and gmax > 75000 and gmin < 75000 then
		gmin = 75000
	end	
		
	--Summerset jewelry traits do not begin until 139k; partial selective search for efficiency
	if (trait == "bloodthirsty" or trait == "harmony" or trait == "infused" or trait == "protective" or trait == "swift" or trait == "triune") and gmax > 139000 and gmin < 139000 then
		gmin = 139000
	end
	
	total_results = 0
	current_cycle = 1
	--create major cycle size
	cycle_size = math.ceil((gmax-gmin)/cycles)	
	tmin = gmin
	tmax = gmin+cycle_size	
	if tmax > pmax then
		tmax = pmax
	end	
		
	d("Beginning search for " .. (text ~= "" and ("\"" ..text.. "\"") or "anything") .. (trait ~= "" and (" with trait \"" .. trait .. "\"") or "") .. (etype ~= "" and (" with equipment type \"" .. etype .. "\"") or "") .. (weight ~= "" and (" with armor weight \"" .. weight .. "\"") or ""))

	--check for specific weight etype
	if etype ~= "" then
		local temp_etype = etype:lower():gsub("s$","")
		for index,equip in pairs(FindMyStuff.EquipSynonymTable) do
			--must be exact match due to helm/helmet
			if temp_etype == equip[1] then
				etype = FindMyStuff.EquipTable[equip[2]]
				--if no specified weight, let's assume they want the correct one
				if weight == "" then
					weight = equip[3]
				end
			end
		end
	end
	
	--handle uniformity
	etype = etype:lower()
	weight = weight:lower()

	EVENT_MANAGER:RegisterForUpdate(FindMyStuff.Name, 100, function() FindMyStuff.UseName(text,trait,etype,weight) end)
end

--splits string into array
local function split_str(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
		local i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

--Finds items using their name
function FindMyStuff.UseName(text,trait,etype,weight)
	local searchstring = text:lower():gsub("-","--")
	local out_ary = {}
	
	--create search array
	local searcharray = split_str(searchstring)
	local terms = #searcharray
	
	local item_id = -1
	for i = tmin, tmax, 1 do
		local matched = true
		local temp_trait = ""
		local temp_equip = ""
		local temp_wep = ""
		local temp_weight = ""
		local temp_etype = etype
		
		--check if it is blank before anything else
		if FindMyStuff.ItemTable['items'][i] ~= "" and FindMyStuff.ItemTable['items'][i] ~= nil then
			local linkstring = tostring(FindMyStuff.ItemTable['items'][i])
			--check for first term
			if terms == 0 or string.find(linkstring, tostring(searcharray[1])) ~= nil then
				--check if there are additional terms to compare it against
				if terms > 1 then
					for a = 2, terms, 1 do
						if string.find(linkstring, tostring(searcharray[a])) == nil then
							matched = false
						end
					end
				end
				if matched then
					--handle traits being included in search
					temp_trait = FindMyStuff.TraitTable[select(1,GetItemLinkTraitInfo("|H1:item:" .. i .. link_suffix))]
					if trait == "" or temp_trait:lower():match(trait) then
						--handle equiptype being included
						if temp_etype ~= "" then
							temp_equip = FindMyStuff.EquipTable[GetItemLinkEquipType("|H1:item:" .. i .. link_suffix)]
							--check if it is a shirt or robe
							if temp_equip == "chest" then
								if temp_etype == "shirt" then
									if linkstring:find("robe") == nil then
										temp_etype = "chest"
									else
										matched = false
									end	
								elseif temp_etype == "robe" then
									if linkstring:find("robe") ~= nil then
										temp_etype = "chest"
									else
										matched = false
									end	
								end
							end
							if matched then
								--check if it matches, otherwise check the weapon table
								if temp_equip ~= nil and temp_equip:find(temp_etype) == 1 then
								--check through the weapon table instead
								elseif temp_equip ~= nil and temp_equip:find("weapon") == 1 then
									temp_wep = FindMyStuff.WeaponTable[GetItemLinkWeaponType("|H1:item:" .. i .. link_suffix)]
									if  temp_wep:find(temp_etype) ~= 1 then
										matched = false
									end
								else
									matched = false
								end
							end
						end
						--handle weight
						if weight ~= "" then
							temp_weight = FindMyStuff.ArmorTable[GetItemLinkArmorType("|H1:item:" .. i .. link_suffix)]
							if temp_weight ~= nil and temp_weight:find(weight) == 1 then
							else
								matched = false
							end
						end
						if matched then
						if i > 176000 and (temp_trait == nil or link_suffix == nil) then
						d(i)
						end
							out_ary[#out_ary+1] = "ID #" .. i .. ": |H1:item:" .. i .. link_suffix .. (temp_trait ~= "None" and (" " .. temp_trait) or "")
							total_results = total_results + 1
							--break at 100 results
							if total_results >= max_results then 
								item_id = i
								break 
							end
						end
					end	
				end
			end
		end	
	end

	if total_results < max_results and tmax < gmax then
		d(table.concat(out_ary,"\n"))
	elseif total_results < max_results and tmax >= gmax then
		d(table.concat(out_ary,"\n") .. "\nFinished search. Total results: " .. total_results)
	elseif total_results >= max_results then
		d(table.concat(out_ary,"\n") .. "\nFinished search. Too many results.")
		--Determine if it got cut short
		local next_id = tmax
		if item_id ~= -1 then
			next_id = item_id
		end	
		--clean up extra spacing
		local out_string = "/" .. text .. (text ~= "" and " " or "") .. (trait ~= "" and "trait:" .. trait .. " " or "") .. (etype ~= "" and "type:" .. etype .. " " or "") .. (weight ~= "" and "weight:" .. weight .. " " or "") .. (next_id+1)
		out_string = out_string:gsub("/%s*","/findid ")
		if not IsConsoleUI() then
			CHAT_SYSTEM.textEntry:Open(out_string)
			CHAT_SYSTEM.textEntry:SetCursorPosition(0)
		end
		EVENT_MANAGER:UnregisterForUpdate(FindMyStuff.Name)
	end
	--Cancel once fully looped through
	if tmax >= gmax then
		EVENT_MANAGER:UnregisterForUpdate(FindMyStuff.Name)
	--Otherwise update the range for the next round	
	else	
		current_cycle = current_cycle+1 
		tmin = gmin+(cycle_size*(current_cycle-1))+1
		tmax = gmin+cycle_size*current_cycle
	end
end

--Finds items by id or reassemble broken item
local function ShowItem(text)
	if string.match(text,"[^%d]") then
		d("|" .. text)
	else	
		d("ID #" .. text .. ": |H1:item:" .. text .. link_suffix)
	end	
end	

--Takes a link and returns the text
local function BreakItem(text)
	text = string.gsub(text,"|H",'H')
	if not IsConsoleUI() then
		CHAT_SYSTEM.textEntry:Open("/showitem " .. text)
		CHAT_SYSTEM.textEntry:SetCursorPosition(10)
	else
		d("/showitem " .. text)
	end
end	

--Helper function for building the table
local function TableBuilder(text,mode)
	current_cycle = 1
	--create major cycle size
	bcycles = 3
	cycle_size = math.ceil((gmax-gmin)/bcycles)
	tmin = gmin
	tmax = gmin+cycle_size	
	d("Building current item table...")		
	EVENT_MANAGER:RegisterForUpdate(FindMyStuff.Name, 100, function() FindMyStuff.BuildTable(text,mode) end)
end

--Takes the input and determines if a range was included
local function RangeCheck(text)
	--check if the table has been built
	if FindMyStuff.ItemTable.built == 0 then
		TableBuilder(text)
	else
		local trait = ""
		--check if using traits
		if text:match("%s-trait:%w+") ~= nil then
			trait = text:match("trait:(%w+)")
			text = text:gsub(text:match("%s-trait:%w+"),'',1)
		end
		local etype = ""
		--check if using type
		if text:match("%s-type:%w+") ~= nil then
			etype = text:match("type:(%w+)")
			text = text:gsub(text:match("%s-type:%w+"),'',1)
		end	
		local weight = ""
		--check if using weight
		if text:match("%s-weight:%w+") ~= nil then
			weight = text:match("weight:(%w+)")
			text = text:gsub(text:match("%s-weight:%w+"),'',1)
		end			
		--check if using just offsets
		if text:match("%a") == nil then
			text = " " .. text
		end	
		--check for offset
		local fmin = string.match(text,"(%s%d+)")
		if fmin ~= nil then	
			--remove the min
			text = text:gsub(fmin,'',1)
			--attempt to create a max
			local fmax = tonumber(text:match("(%s%d+)"))
			if fmax ~= nil then
				--remove the max
				text = text:gsub(fmax,'')
				if text:gsub("%s+",'') == "" then
					text = ""
				end	
				bridge(text,tonumber(fmin),tonumber(fmax),trait,etype,weight)
			else
				if text:gsub("%s+",'') == "" then
					text = ""
				end	
				bridge(text,tonumber(fmin),nil,trait,etype,weight)
			end	
		else	
			bridge(text,nil,nil,trait,etype,weight)
		end	
	end	
end

--Helper to reset table when necessary
function TableReset(table)
	local count = #table
	for i=0, count do table[i]=nil end
end

-- Acts as a bridge between input and cycle
local function DumpBridge(text,min,max)
	if min == nil then gmin = 1 else gmin = min end
	if max == nil then gmax = pmax else gmax = max end
	total_results = 0
	current_cycle = 1
	--create major cycle size
	cycle_size = math.ceil((gmax-gmin)/cycles)	
	tmin = gmin
	tmax = gmin+cycle_size	
	if tmax > pmax then
		tmax = pmax
	end	
	
	--Reset before use
	TableReset(dump_output)
	dump_position = 1
	
	EVENT_MANAGER:RegisterForUpdate(FindMyStuff.Name, 100, function() FindMyStuff.DumpBuilder(text) end)
end	

--Assembles the data for searching
function FindMyStuff.BuildTable(text,mode)
	if text == '' then text = nil end
	if mode == nil then mode = 0 end
	for i = tmin, tmax, 1 do
		local link = "|H1:item:" .. i .. link_suffix
		local snaglink = GetItemLinkName(link)
		--check if it is blank before anything else
		if snaglink ~= "h" then
			FindMyStuff.ItemTable['items'][i] = tostring(snaglink):lower()
		else
			FindMyStuff.ItemTable['items'][i] = ""
		end
	end
	--Cancel once fully looped through
	if tmax >= gmax then
		FindMyStuff.ItemTable.built = 1	
		d("Item table built.")
		EVENT_MANAGER:UnregisterForUpdate(FindMyStuff.Name)
		if text ~= nil and mode == 0 then
			RangeCheck(text)
		elseif mode == 1 then
			DumpBridge(text)
		end
	--Otherwise update the range for the next round	
	else	
		d("Building...")
		current_cycle = current_cycle+1 
		tmin = gmin+(cycle_size*(current_cycle-1))+1
		tmax = gmin+cycle_size*current_cycle
	end	
end

--Handles concating numbers
function implode(delimiter, list)
	local len = #list
	if len == 0 then
		return ""
	end
	local string = list[1]
	for i = 2, len do
		string = string .. delimiter .. list[i]
	end
	return string
end

--Attempts to dump all furniture/cooking recipe IDs to savedvars
local function Dump(text)
	if text == 'furniture' or text == 'provisioning' or text == 'reagent' then
		if FindMyStuff.ItemTable.built == 0 then
			TableBuilder(text,1)
		else
			DumpBridge(text)
		end	
	else
		d('Current dump options: "furniture" "provisioning" "reagent"')
	end	
end

function FindMyStuff.DumpBuilder(text)
	--Handle mode
	mode = -1
	if text == 'provisioning' then
		mode = 0
	elseif text == 'furniture' then
		mode = 1
	elseif text == 'reagent' then
		mode = 2
	end
	
	for i = tmin, tmax, 1 do
		if FindMyStuff.ItemTable['items'][i] ~= "" then
			--Only ignore Roast Pig BOP
			if i ~= 55462 then
				local itemLink = "|H1:item:" .. i .. link_suffix
				local _,sType = GetItemLinkItemType(itemLink)
				if mode == 0 then
					if sType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK then
						dump_output[#dump_output+1] = i	
					end
				elseif mode == 1 then
					if sType == SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING or
						sType == SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING then
						dump_output[#dump_output+1] = i
					end
				elseif mode == 2 then
					if sType == SPECIALIZED_ITEMTYPE_REAGENT_ANIMAL_PART or
						sType == SPECIALIZED_ITEMTYPE_REAGENT_FUNGUS or
						sType == SPECIALIZED_ITEMTYPE_REAGENT_HERB then
						dump_output[#dump_output+1] = i
					end	
				end
				--Handle size threat
				if #dump_output >= 100 then
					FindMyStuff.SavedVariables[text .. dump_position] = implode(",",dump_output)
					dump_position = dump_position+1
					TableReset(dump_output)
				end
			end
		end	
	end
	
	--Cancel once fully looped through
	if tmax >= gmax then
		EVENT_MANAGER:UnregisterForUpdate(FindMyStuff.Name)
		--Handle stragglers
		if #dump_output ~= 0 then
			FindMyStuff.SavedVariables[text .. dump_position] = implode(",",dump_output)
		end	
		d('Dump completed. Reload and view your Saved Vars.')
	--Otherwise update the range for the next round	
	else	
		current_cycle = current_cycle+1 
		tmin = gmin+(cycle_size*(current_cycle-1))+1
		tmax = gmin+cycle_size*current_cycle
		--Prove it's still working 
		d('Building dump...')
	end
end

--Grade helper
local function AssembleItem(item_data,quality)
	if quality ~= nil then item_data[4] = quality end
	local out = ""
	if tonumber(item_data[4]) < 0 then
		item_data[4] = 0
	end		
	for i = 1, #item_data, 1 do
		out = out .. ":" .. item_data[i]
	end
	return out:sub(2)
end

--Attempts to show all qualities of an item
local function GradeItem(text)
	local item_data = split_str(text,":")
	local temp_item = ""
	local temp_quality = ""
	local quality = tonumber(item_data[4])
	local quality_tier = GetItemLinkQuality(text)
	local quality_attempts = 0
	local quality_table = {}
	--Try to handle CP10-100 (batch 1)
	if quality >= 39 and quality <= 120 then
		--Handle normal
		if quality >= 111 and quality <= 120 then
			quality_table = {[1]=quality,[2]=quality-60,[3]=quality-50,[4]=quality-40,[5]=quality-10}
		--Handle fine quest rewards
		elseif quality >= 39 and quality <= 48 then
			quality_table = {[1]=quality+72,[2]=quality,[3]=quality+22,[4]=quality+32,[5]=quality+62}
		--Handle fine		
		elseif quality >= 51 and quality <= 60 then
			quality_table = {[1]=quality+60,[2]=quality,[3]=quality+10,[4]=quality+20,[5]=quality+50}
		--Handle superior	
		elseif quality >= 61 and quality <= 70 then
			quality_table = {[1]=quality+50,[2]=quality-10,[3]=quality,[4]=quality+10,[5]=quality+40}
		--Handle superior second set
		elseif quality >= 81 and quality <= 90 then
			quality_table = {[1]=quality+30,[2]=quality-30,[3]=quality,[4]=quality-10,[5]=quality+20}		
		--Handle epic
		elseif quality >= 71 and quality <= 80 then
			quality_table = {[1]=quality+40,[2]=quality-20,[3]=quality-10,[4]=quality,[5]=quality+30}
		--Handle epic second set
		elseif quality >= 91 and quality <= 100 then
			quality_table = {[1]=quality+20,[2]=quality-40,[3]=quality-30,[4]=quality,[5]=quality+10}		
		--Handle legendary
		elseif quality >= 101 and quality <= 110 then
			quality_table = {[1]=quality+10,[2]=quality-50,[3]=quality-40,[4]=quality-30,[5]=quality}
		end
	--Try to handle CP10-100 (batch 2)
	elseif quality >= 125 and quality <= 174 then
		--Handle normal
		if quality >= 125 and quality <= 134 then
			quality_table = {[1]=quality,[2]=quality+10,[3]=quality+20,[4]=quality+30,[5]=quality+40}
		--Handle fine
		elseif quality >= 135 and quality <= 144 then
			quality_table = {[1]=quality-10,[2]=quality,[3]=quality+10,[4]=quality+20,[5]=quality+30}
		--Handle superior
		elseif quality >= 145 and quality <= 154 then
			quality_table = {[1]=quality-20,[2]=quality-10,[3]=quality,[4]=quality+10,[5]=quality+20}	
		--Handle epic
		elseif quality >= 155 and quality <= 164 then
			quality_table = {[1]=quality-30,[2]=quality-20,[3]=quality-10,[4]=quality,[5]=quality+10}	
		--Handle legendary
		elseif quality >= 165 and quality <= 174 then
			quality_table = {[1]=quality-40,[2]=quality-30,[3]=quality-20,[4]=quality-10,[5]=quality}			
		end
	elseif quality_tier ~= 0 then
		quality_table[quality_tier] = quality
		--Attempt to find tier 5 when tier 1
		if quality_table[1] ~= nil then
			item_data[4] = item_data[4]-1
			temp_item = AssembleItem(item_data)
			temp_quality = GetItemLinkQuality(temp_item)			
			if temp_quality == 5 then
				quality_table[5] = item_data[4]
			end
		end
		--Attempts to find tier 5
		if quality_table[5] == nil then
			while quality_table[5] == nil and quality_attempts < 7 do 
				item_data[4] = item_data[4]+1
				temp_item = AssembleItem(item_data)
				temp_quality = GetItemLinkQuality(temp_item)
				if temp_quality == 5 then
					quality_table[5] = item_data[4]
				end	
				quality_attempts = quality_attempts+1
			end	
		end
		--Tries to work backward from there
		local temp_attempts = quality_attempts
		while quality_attempts < (7+temp_attempts) do
			item_data[4] = item_data[4]-1
			temp_item = AssembleItem(item_data)
			temp_quality = GetItemLinkQuality(temp_item)
			if quality_table[temp_quality] == nil then
				quality_table[temp_quality] = item_data[4]
			end
			quality_attempts = quality_attempts+1		
		end
		--Attempts to handle tier 1 post 5 if not found sub 5 if 5 was found
		if quality_table[1] == nil and quality_table[5] ~= nil then
			item_data[4] = quality_table[5]
			quality_attempts = 0
			while quality_table[1] == nil and quality_attempts < 7 do 
				item_data[4] = item_data[4]+1
				temp_item = AssembleItem(item_data)
				temp_quality = GetItemLinkQuality(temp_item)
				if temp_quality == 1 then
					quality_table[1] = item_data[4]
				end	
				quality_attempts = quality_attempts+1
			end				
		end
	end
	--Ensure ordered table
	for key = 1, 5, 1 do
		if quality_table[key] ~= nil then
			d("ID #" .. item_data[3] .. ": " .. AssembleItem(item_data,quality_table[key]) .. " Quality: " .. quality_table[key])
		end	
	end	
end

--Updates quality settings
local function SetQuality(text)
	local item_data = split_str(text,":")
	if tonumber(item_data[4]) ~= nil and tonumber(item_data[5]) ~= nil then
		FindMyStuff.SavedVariables.quality = item_data[4]
		FindMyStuff.SavedVariables.level = item_data[5]
		FindMyStuff.Default = {quality=FindMyStuff.SavedVariables.quality,level=FindMyStuff.SavedVariables.level}
		link_suffix = ":" .. FindMyStuff.Default.quality .. ":" .. FindMyStuff.Default.level .. base_suffix	
		d("Item Finder quality updated.")
	else
		d("Item Finder refuses your offering. Try an item with a level.")
	end	
end

--Shows command usage
local function IFHelp()
	d("Item Finder Command Usage")
	d("Command: |cFF7700/fms|r")
	d("Purpose: Opens the Find My Stuff window (gamepad screen in gamepad mode). Add items, traders or leads to pick a tab.")
	d("Usage: /fms leads")
	--Find item in inventory (cross-character)
	d("Command: |cFF7700/finditem|r")
	d("Purpose: Searches your saved cross-character inventory for an item by name.")
	d("Usage: /finditem item_name")
	d("Example: /finditem night mother")
	--Rescan inventory
	d("Command: |cFF7700/fmsscan|r")
	d("Purpose: Manually rescans and saves the current character's inventory.")
	d("Usage: /fmsscan")
	--Guild trader filter
	d("Command: |cFF7700/fmstrader|r")
	d("Purpose: Pages through guild trader listings and shows only the ones matching your filter.")
	d("Usage: /fmstrader words [trait:x] [quality:epic] [max:gold] [unit:gold] [pages:N] [unknown] [all]")
	d("Example: /fmstrader dreugh wax unit:9000")
	d("Example: /fmstrader unknown max:20000 all")
	d("Also: /fmstrader stop, /fmstrader last")
	d("Command: |cFF7700/fmstraderlead|r - scan guild stores for antiquity leads")
	d("Example: /fmstraderlead mythic    Example: /fmstraderlead ring of the wild hunt missing")
	--Lead search
	d("Command: |cFF7700/fmslead|r")
	d("Purpose: Searches every antiquity lead in the game by name, set or zone.")
	d("Usage: /fmslead [words] [have] [missing] [new] [all] [page:N]")
	d("Example: /fmslead ring of the wild hunt")
	d("Example: /fmslead summerset missing")
	--Find item in database
	d("Command: |cFF7700/findindb|r or |cFF7700/findid|r or |cFF7700/findbyname|r")
	d("Purpose: Searches all possible game items by ID (full database search).")
	d("Usage: /findindb item_name (optional)start_id (optional)end_id")
	d("Example: /findindb night mother")
	d("Advanced Example: /findindb night mother 40000 50000")
	--Find name
	d("Command: |cFF7700/showitem|r or |cFF7700/findname|r or |cFF7700/findbyid|r")
	d("Purpose: Uses an item's ID or the output from /breakitem and outputs an item link.")
	d("Usage: /showitem item_id")
	d("Example: /showitem 61225")
	--Break Item
	d("Command: |cFF7700/breakitem|r")
	d("Purpose: Takes an item link and converts it to text for editing/viewing.")
	d("Usage: /breakitem item_link")
	d("Example: /breakitem |H1:item:61225:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h")	
	--Show quality
	d("Command: |cFF7700/gradeitem|r")
	d("Purpose: Takes an item link and attempts to show it at each quality.")
	d("Usage: /gradeitem item_link")
	d("Example: /gradeitem |H1:item:84984:362:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h")
	--Change quality
	d("Command: |cFF7700/ifdump|r")
	d("Purpose: Sends a dump of IDs for furniture recipes/provisioning recipes.")
	d("Usage: /ifdump option")
	d("Example: /ifdump furniture")		
	--Change quality
	d("Command: |cFF7700/ifsetquality|r")
	d("Purpose: Takes an item link and uses the item's quality and level for your /findindb results. Character specific setting.")
	d("Usage: /ifsetquality item_link")
	d("Example: /ifsetquality |H1:item:84984:362:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h")	
	--Trait flag
	d("Flag: |c0077FFtrait:|r")
	d("Purpose: Allows for searching by trait.")
	d("Example: /findindb night mother trait:divines")	
	--Equipment flag weapon/armor
	d("Flag: |c0077FFtype:|r")
	d("Purpose: Allows for searching by armor or weapon type.")
	d("Weapon Keywords: Axe, Bow, Dagger, Mace, Shield, Sword, Fire, Frost, Lightning, Healing, BattleAxe, Maul, Greatsword")
	d("Armor Keywords: Chest, Feet, Hand, Head, Legs, Necklace, Ring, Shoulders, Waist")
	d("Example: /findindb night mother type:sword")
	--Equipment flag weighted armor
	d("Flag: |c0077FFtype:|r")
	d("Advanced Purpose: Allows for searching by armor type and weight by using the weight-specific names below.")
	d("Light Armor Keywords: Hat, Robe, Shirt, Epaulets, Sash, Breeches, Shoes, Gloves")
	d("Medium Armor Keywords: Helmet, Jack, ArmCops, Belt, Guards, Boots, Bracers")
	d("Heavy Armor Keywords: Helm, Cuirass, Pauldrons, Girdle, Greaves, Sabatons, Gauntlets")
	d("Example: /findindb night mother type:jack")
	--Weight flag
	d("Flag: |c0077FFweight:|r")
	d("Purpose: Allows for searching by armor weight.")	
	d("Weight Keywords: Light, Medium, Heavy")
	d("Example: /findindb night mother weight:light")
	d("Advanced Example: /findindb night mother type:head weight:light")
end
-- ========================
-- INVENTORY TRACKING SYSTEM
-- ========================

-- Quality color codes indexed by ESO ItemQuality (0=Trash .. 5=Legendary)
local FMS_QUALITY_COLORS = {
	[ITEM_DISPLAY_QUALITY_TRASH] = "|c9D9D9D",  -- Trash
	[ITEM_DISPLAY_QUALITY_NORMAL] = "|cFFFFFF",  -- Normal
	[ITEM_DISPLAY_QUALITY_MAGIC] = "|c2DC50E",  -- Fine
	[ITEM_DISPLAY_QUALITY_ARCANE] = "|c4169E1",  -- Superior
	[ITEM_DISPLAY_QUALITY_ARTIFACT] = "|cA02EF7",  -- Epic
	[ITEM_DISPLAY_QUALITY_LEGENDARY] = "|cffff00",  -- Legendary
	[ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE] = "|cFFA500",  -- Mythic
}

local function FMS_ScanBag(bag, inv)
	local numSlots = GetBagSize(bag)
	for slot = 0, numSlots - 1 do
		local itemLink = GetItemLink(bag, slot)
		if itemLink ~= "" then
			local itemName = GetItemLinkName(itemLink)
			if itemName ~= "" then
				local stack = GetSlotStackSize(bag, slot)
				local quality = GetItemLinkDisplayQuality(itemLink)
				local traitType = select(1, GetItemLinkTraitInfo(itemLink))
				local traitName = FindMyStuff.TraitTable[traitType]
				if traitName == "None" then traitName = nil end
				-- Binding status
				local bindType = GetItemLinkBindType(itemLink)
				local boundStr
				if bindType == BIND_TYPE_NONE then
					boundStr = "Unbound"
				elseif bindType == BIND_TYPE_ON_EQUIP then
					boundStr = "BoE"
				else
					boundStr = "Bound"
				end
				-- Known/Unknown for learnable items (recipes, motifs)
				local knownStr = nil
				local itemType = GetItemLinkItemType(itemLink)
				if itemType == ITEMTYPE_RECIPE or itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then
					local isKnown = IsItemLinkRecipeKnown(itemLink)
					if isKnown then
						knownStr = "Known"
					else
						knownStr = "Unknown"
					end
				elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or itemType == ITEMTYPE_COLLECTIBLE then
					if IsItemLinkBookKnown(itemLink) then
						knownStr = "Known"
					else
						knownStr = "Unknown"
					end
				end
				-- composite key keeps different-trait copies of the same item separate
				local key = itemName .. (traitName and ("\t" .. traitName) or "")
				local existing = inv[key]
				if existing and type(existing) == "table" then
					existing.n = existing.n + stack
				else
					inv[key] = {n = stack, q = quality, t = traitName, name = itemName, bound = boundStr, known = knownStr, l = itemLink}
				end
			end
		end
	end
end

function FindMyStuff.ScanInventory()
	if not FindMyStuff.SavedVariables then return end
	if not FindMyStuff.SavedVariables.charInventory then
		FindMyStuff.SavedVariables.charInventory = {}
	end
	local charName = GetUnitName("player")
	local charInv = {}
	FMS_ScanBag(BAG_BACKPACK, charInv)
	FMS_ScanBag(BAG_WORN, charInv)
	FindMyStuff.SavedVariables.charInventory[charName] = charInv
	-- Shared bags stored under a common key (updated each time any character logs in)
	local sharedInv = {}
	FMS_ScanBag(BAG_BANK, sharedInv)
	if GetBagSize(BAG_SUBSCRIBER_BANK) > 0 then
		FMS_ScanBag(BAG_SUBSCRIBER_BANK, sharedInv)
	end
	if GetBagSize(BAG_CRAFT_BAG) > 0 then
		FMS_ScanBag(BAG_CRAFT_BAG, sharedInv)
	end
	if next(sharedInv) ~= nil then
		FindMyStuff.SavedVariables.charInventory["[Bank/Craft Bag]"] = sharedInv
	end
end


-- ========================
-- SHARED HELPERS
-- ========================

local PREFIX = "|cFF7700FindMyStuff:|r "

local function FMS_Trim(s)
	return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
FindMyStuff.Trim = FMS_Trim

-- Calls fn only if this API version has it (fn is passed as a global value, so it is nil when missing)
local function FMS_Call(fn, ...)
	if type(fn) == "function" then return fn(...) end
end

-- Strips ESO grammar suffixes ("^n", "^F") from names
local function FMS_CleanName(name)
	if not name or name == "" then return "" end
	return zo_strformat("<<1>>", name)
end

-- Splits "words key:value flag" input into {words={}, flags={}, key=value}
local function FMS_ParseOptions(text, knownFlags)
	local opts = {words = {}, flags = {}}
	for token in (text or ""):lower():gmatch("%S+") do
		local key, value = token:match("^(%a+):(.+)$")
		if key then
			opts[key] = value
		elseif knownFlags and knownFlags[token] then
			opts.flags[token] = true
		else
			opts.words[#opts.words + 1] = token
		end
	end
	return opts
end

local function FMS_MatchesAllWords(haystack, words)
	for i = 1, #words do
		if not haystack:find(words[i], 1, true) then return false end
	end
	return true
end

local function FMS_Gold(n)
	n = n or 0
	if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
	return tostring(n)
end

local function FMS_Setting(key)
	local sv = FindMyStuff.SavedVariables
	if sv and sv[key] ~= nil then return sv[key] end
	return FindMyStuff.SettingDefaults[key]
end
FindMyStuff.GetSetting = FMS_Setting

-- Every search returns rows shaped like:
--   line   = full chat / keyboard line (may contain item links)
--   title  = short coloured name for the gamepad list
--   detail = plain description for tooltips
--   link   = item link, when there is one
local function FMS_PrintRows(rows, summary, err)
	if err then
		d(PREFIX .. err)
		return
	end
	if summary then d(PREFIX .. summary) end
	for i = 1, #(rows or {}) do d(rows[i].line) end
end

-- ========================
-- CROSS-CHARACTER INVENTORY SEARCH
-- ========================

local function FMS_BoundTag(bound)
	if bound == "Unbound" then return " |c2DC50E[Unbound]|r", "Unbound"
	elseif bound == "BoE" then return " |cF5A9B8[Bind On Equip]|r", "Bind on equip"
	elseif bound == "Bound" then return " |caaaaaa[Bound]|r", "Bound" end
	return "", nil
end

-- Returns rows, summary, errorText
function FindMyStuff.SearchInventory(searchText)
	local sv = FindMyStuff.SavedVariables
	if not sv or not sv.charInventory then
		return nil, nil, "No inventory data saved. Log in with each character to populate."
	end
	searchText = FMS_Trim(searchText)
	if searchText == "" then
		return nil, nil, "Type the name of an item to search for."
	end
	local search = searchText:lower()
	local results = {}
	for charName, items in pairs(sv.charInventory) do
		for key, entry in pairs(items) do
			-- handle legacy format where entry was just a count number
			if type(entry) == "number" then
				entry = {n = entry, q = 1, t = nil, name = key}
			end
			local displayName = entry.name or key
			if displayName:lower():find(search, 1, true) then
				results[#results + 1] = {char = charName, name = displayName, entry = entry}
			end
		end
	end
	table.sort(results, function(a, b)
		if a.char ~= b.char then return a.char < b.char end
		return a.name < b.name
	end)

	local rows = {}
	for _, r in ipairs(results) do
		local e = r.entry
		local qColor = FMS_QUALITY_COLORS[e.q] or FMS_QUALITY_COLORS[1]
		local traitStr = e.t and (" |caaaaaa[" .. e.t .. "]|r") or ""
		local boundStr, boundPlain = FMS_BoundTag(e.bound)
		local knownStr = e.known == "Known" and " |caaaaaa[Known]|r" or (e.known == "Unknown" and " |c5BCEFA[Unknown]|r" or "")
		local name = FMS_CleanName(r.name)
		local detail = {"On: " .. r.char, "Amount: " .. (e.n or 1)}
		if e.t then detail[#detail + 1] = "Trait: " .. e.t end
		if boundPlain then detail[#detail + 1] = boundPlain end
		if e.known then detail[#detail + 1] = e.known end
		rows[#rows + 1] = {
			line = "  |caaaaaaCharacter:|r |cffff00" .. r.char .. "|r  - " .. qColor .. name .. "|r" .. traitStr .. boundStr .. knownStr .. " |caaaaaa(x" .. (e.n or 1) .. ")|r",
			title = qColor .. name .. "|r |caaaaaax" .. (e.n or 1) .. " - " .. r.char .. "|r",
			detail = table.concat(detail, "\n"),
			link = e.l,
		}
	end
	local summary
	if #rows == 0 then
		summary = "No items found: |cffff00" .. searchText .. "|r"
	else
		summary = "|cffff00" .. #rows .. "|r result(s) for: |cffff00" .. searchText .. "|r"
	end
	return rows, summary
end

local function FindInInventory(searchText)
	if FMS_Trim(searchText) == "" then
		d(PREFIX .. "Usage: /finditem <item name>")
		return
	end
	FMS_PrintRows(FindMyStuff.SearchInventory(searchText))
end

-- ========================
-- GUILD TRADER FILTER
-- ========================

local FMS_QUALITY_NAMES = {
	trash = 0, normal = 1, white = 1, fine = 2, green = 2, superior = 3, blue = 3,
	epic = 4, purple = 4, legendary = 5, gold = 5, mythic = 6,
}
local FMS_TRADER_LOG_MAX = 200
local TRADER_CALLBACK = "FindMyStuff_TraderUpdate"
FindMyStuff.TRADER_CALLBACK = TRADER_CALLBACK

local trader = {
	open = false,        -- is a guild store currently open
	filter = nil,        -- active filter, also applied to manual searches
	filterText = "",
	pendingScan = false, -- start a scan as soon as a store opens
	scanning = false,
	guildQueue = {},
	guildIndex = 0,
	guildName = nil,
	page = 0,
	token = 0,           -- increments per search request, used by the watchdog
	matches = 0,
	pagesDone = 0,
	seen = {},
	rows = {},
}

local function FMS_TraderChanged()
	CALLBACK_MANAGER:FireCallbacks(TRADER_CALLBACK)
end

local function FMS_TraderGuildName(guildId)
	local num = FMS_Call(GetNumTradingHouseGuilds) or 0
	for i = 1, num do
		local id, name = GetTradingHouseGuildDetails(i)
		if id == guildId and name and name ~= "" then return name end
	end
	local name = guildId and FMS_Call(GetGuildName, guildId)
	if name and name ~= "" then return name end
	return "Guild Trader"
end

-- True for recipes, motifs and style/collectible containers you have not learned yet
local function FMS_IsUnknownLearnable(link)
	local itemType = GetItemLinkItemType(link)
	if itemType == ITEMTYPE_RECIPE then
		return not IsItemLinkRecipeKnown(link)
	elseif itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
		return not IsItemLinkBookKnown(link)
	end
	local collectibleId = FMS_Call(GetItemLinkContainerCollectibleId, link)
	if collectibleId and collectibleId ~= 0 then
		return not IsCollectibleUnlocked(collectibleId)
	end
	return false
end

-- Antiquity helpers shared by the trader lead search and /fmslead -------------

-- The item an antiquity (or its set) rewards, as a link, or nil
local function FMS_AntiquityRewardLink(antiquityId)
	local rewardId = FMS_Call(GetAntiquityRewardId, antiquityId)
	if not rewardId or rewardId == 0 then
		local setId = FMS_Call(GetAntiquitySetId, antiquityId) or 0
		if setId ~= 0 then rewardId = FMS_Call(GetAntiquitySetRewardId, setId) end
	end
	if not rewardId or rewardId == 0 then return nil end
	local link = FMS_Call(GetItemRewardItemLink, rewardId, 1, LINK_STYLE_BRACKETS)
	if link and link ~= "" then return link end
	return nil
end

-- True when the antiquity is part of a mythic item
function FindMyStuff.IsMythicAntiquity(antiquityId)
	local link = FMS_AntiquityRewardLink(antiquityId)
	if link and ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE and GetItemLinkDisplayQuality then
		return GetItemLinkDisplayQuality(link) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE, link
	end
	-- no reward data: mythic fragments are the gold (legendary) antiquities
	local quality = FMS_Call(GetAntiquityQuality, antiquityId) or 0
	return quality >= (ANTIQUITY_QUALITY_GOLD or 5), link
end

-- Builds the list of antiquities a trader lead search looks for.
-- words match the antiquity, its set, its zone or the item it rewards.
local function FMS_BuildLeadTargets(words, flags)
	local targets = {}
	if type(GetNextAntiquityId) ~= "function" then return targets end
	local id = GetNextAntiquityId()
	while id and id ~= 0 do
		if FMS_Call(DoesAntiquityRequireLead, id) ~= false then
			local name = FMS_CleanName(GetAntiquityName(id))
			local setId = FMS_Call(GetAntiquitySetId, id) or 0
			local setName = setId ~= 0 and FMS_CleanName(FMS_Call(GetAntiquitySetName, setId)) or ""
			local zoneId = FMS_Call(GetAntiquityZoneId, id) or 0
			local zoneName = zoneId ~= 0 and FMS_CleanName(GetZoneNameById(zoneId)) or "Anywhere"
			local isMythic, rewardLink = FindMyStuff.IsMythicAntiquity(id)
			local rewardName = rewardLink and FMS_CleanName(GetItemLinkName(rewardLink)) or ""
			local hasLead = FMS_Call(DoesAntiquityHaveLead, id) and true or false
			local recovered = FMS_Call(GetNumAntiquitiesRecovered, id) or 0
			local haystack = (name .. " " .. setName .. " " .. zoneName .. " " .. rewardName):lower()
			local keep = FMS_MatchesAllWords(haystack, words)
				and not (flags.mythic and not isMythic)
				and not (flags.have and not hasLead)
				and not (flags.missing and hasLead)
				and not (flags.new and recovered > 0)
			if keep and name ~= "" then
				targets[#targets + 1] = {
					key = name:lower(), name = name, set = setName, zone = zoneName,
					reward = rewardName, rewardKey = rewardName:lower(),
					mythic = isMythic, hasLead = hasLead,
				}
			end
		end
		id = GetNextAntiquityId(id)
	end
	return targets
end

-- Finds the antiquity a store listing belongs to, or nil.
-- Listings can be named after the lead ("Lead: X"), the antiquity, or the
-- item it makes (e.g. the mythic itself).
local function FMS_MatchLeadTarget(targets, listingName)
	local n = listingName:gsub("^lead:%s*", "")
	for _, t in ipairs(targets) do
		if n == t.key or n:find(t.key, 1, true)
			or (t.rewardKey ~= "" and (n == t.rewardKey or n:find(t.rewardKey, 1, true))) then
			return t
		end
	end
	return nil
end

local FMS_LEAD_TRADER_FLAGS = {all = true, unknown = true, mythic = true, have = true, missing = true, new = true}

local function FMS_BuildTraderFilter(text)
	-- "leads ..." switches the filter to lead mode
	local leadMode = false
	local first, rest = (text or ""):match("^(%S+)%s*(.*)$")
	if first and (first:lower() == "lead" or first:lower() == "leads") then
		leadMode = true
		text = rest
	end
	local o = FMS_ParseOptions(text, leadMode and FMS_LEAD_TRADER_FLAGS or {all = true, unknown = true})
	local f = {
		words = o.words,
		trait = o.trait,
		maxPrice = tonumber(o.max),
		maxUnit = tonumber(o.unit),
		allGuilds = o.flags.all or false,
		unknown = o.flags.unknown or false,
		maxPages = tonumber(o.pages) or FMS_Setting("traderPages"),
	}
	if o.quality then
		f.quality = tonumber(o.quality) or FMS_QUALITY_NAMES[o.quality]
	end
	if leadMode then
		f.leadMode = true
		f.mythic = o.flags.mythic or false
		f.leadFlags = o.flags
		f.leadWords = o.words
		f.leadTargets = FMS_BuildLeadTargets(o.words, o.flags)
		-- The words pick antiquities, so listings are matched against those
		-- instead. Only hand the words to the store's name search when they're
		-- part of every chosen antiquity's (or mythic's) name; a zone or set
		-- word would otherwise hide the listings we want.
		f.words = {}
		f.hashWords = {}
		local joined = table.concat(o.words, " ")
		if joined ~= "" and #f.leadTargets > 0 then
			local allNamed = true
			for _, t in ipairs(f.leadTargets) do
				if not (t.key:find(joined, 1, true) or t.rewardKey:find(joined, 1, true)) then
					allNamed = false
					break
				end
			end
			if allNamed then f.hashWords = o.words end
		end
	end
	return f
end

local function FMS_DescribeTraderFilter(f)
	local parts = {}
	if f.leadMode then
		local what = f.mythic and "mythic leads" or "leads"
		if #f.leadWords > 0 then what = what .. " for \"" .. table.concat(f.leadWords, " ") .. "\"" end
		local lf = f.leadFlags
		if lf.have then what = what .. " you have" elseif lf.missing then what = what .. " you're missing" end
		if lf.new then what = what .. " (never found)" end
		parts[#parts + 1] = what .. " [" .. #f.leadTargets .. " antiquities]"
	end
	if #f.words > 0 then parts[#parts + 1] = "\"" .. table.concat(f.words, " ") .. "\"" end
	if f.trait then parts[#parts + 1] = "trait:" .. f.trait end
	if f.quality then parts[#parts + 1] = "quality " .. f.quality .. "+" end
	if f.maxPrice then parts[#parts + 1] = "max " .. FMS_Gold(f.maxPrice) .. "g" end
	if f.maxUnit then parts[#parts + 1] = "max " .. FMS_Gold(f.maxUnit) .. "g each" end
	if f.unknown then parts[#parts + 1] = "unknown only" end
	if f.allGuilds then parts[#parts + 1] = "all guilds" end
	return #parts > 0 and table.concat(parts, ", ") or "everything"
end

-- Returns a row and a de-duplication key for a matching result, or nil
local function FMS_TraderCheckResult(f, index, guildName)
	local _, name, quality, stack, seller, _, price, _, uid, unitPrice = GetTradingHouseSearchResultItemInfo(index)
	if not name or name == "" or not price then return nil end
	stack = stack or 1
	unitPrice = unitPrice or (stack > 0 and price / stack or price)
	local cleanName = FMS_CleanName(name)

	if #f.words > 0 and not FMS_MatchesAllWords(cleanName:lower(), f.words) then return nil end
	local lead
	if f.leadMode then
		lead = FMS_MatchLeadTarget(f.leadTargets, cleanName:lower())
		if not lead then return nil end
	end
	if f.maxPrice and price > f.maxPrice then return nil end
	if f.maxUnit and unitPrice > f.maxUnit then return nil end
	if f.quality and (quality or 0) < f.quality then return nil end

	local link = GetTradingHouseSearchResultItemLink(index, LINK_STYLE_BRACKETS)
	local traitName = FindMyStuff.TraitTable[select(1, GetItemLinkTraitInfo(link))]
	if traitName == "None" then traitName = nil end
	if f.trait and not (traitName and traitName:lower():find(f.trait, 1, true)) then return nil end
	if f.unknown and not FMS_IsUnknownLearnable(link) then return nil end

	local key = (uid and Id64ToString) and Id64ToString(uid) or (guildName .. link .. price .. (seller or ""))
	local each = math.floor(unitPrice + 0.5)
	local qColor = FMS_QUALITY_COLORS[quality] or FMS_QUALITY_COLORS[1]
	local detail = {"Guild: " .. guildName, "Price: " .. FMS_Gold(price) .. "g for " .. stack}
	if stack > 1 then detail[#detail + 1] = "Each: " .. FMS_Gold(each) .. "g" end
	if traitName then detail[#detail + 1] = "Trait: " .. traitName end
	if seller and seller ~= "" then detail[#detail + 1] = "Seller: " .. seller end
	local leadTag = ""
	if lead then
		detail[#detail + 1] = "Antiquity: " .. lead.name .. " (" .. lead.zone .. ")"
		if lead.reward ~= "" then detail[#detail + 1] = (lead.mythic and "Mythic: " or "Makes: ") .. lead.reward end
		detail[#detail + 1] = lead.hasLead and "You have this lead" or "You don't have this lead"
		leadTag = (lead.mythic and " |cFFA500[Mythic]|r" or "")
			.. (lead.hasLead and " |c2DC50E[Have lead]|r" or " |c5BCEFA[No lead]|r")
	end
	local row = {
		line = "|cFF7700[" .. guildName .. "]|r " .. link .. leadTag
			.. (traitName and (" |caaaaaa[" .. traitName .. "]|r") or "")
			.. " |caaaaaax" .. stack .. "|r - |cffff00" .. FMS_Gold(price) .. "g|r"
			.. (stack > 1 and (" |caaaaaa(" .. FMS_Gold(each) .. "g ea)|r") or "")
			.. " |caaaaaa" .. (seller or "") .. "|r",
		title = qColor .. cleanName .. "|r |cffff00" .. FMS_Gold(price) .. "g|r",
		detail = table.concat(detail, "\n"),
		link = link,
	}
	return row, key
end

local FMS_TraderQueueSearch -- forward declaration

local function FMS_TraderFinish(reason)
	trader.scanning = false
	trader.awaiting = false
	trader.guildName = nil
	trader.token = trader.token + 1
	d(PREFIX .. "Trader scan " .. (reason or "finished") .. ". |cffff00" .. trader.matches
		.. "|r match(es) across " .. trader.pagesDone .. " page(s).")
	FMS_TraderChanged()
end

local function FMS_TraderNextGuild()
	trader.guildIndex = trader.guildIndex + 1
	local guildId = trader.guildQueue[trader.guildIndex]
	if not guildId then
		FMS_TraderFinish()
		return
	end
	trader.guildName = FMS_TraderGuildName(guildId)
	d(PREFIX .. "Scanning |cffff00" .. trader.guildName .. "|r...")
	FMS_TraderChanged()
	if FMS_Call(GetSelectedTradingHouseGuildId) == guildId then
		FMS_TraderQueueSearch(0)
	else
		SelectTradingHouseGuildId(guildId)
		zo_callLater(function()
			if trader.scanning then FMS_TraderQueueSearch(0) end
		end, 1000)
	end
end

-- Sets the store's search terms: whatever category/filters are picked in the
-- store UI, plus our name, price and quality filters, so the server only sends
-- back listings that can match (the local check below still runs on each one).
local function FMS_TraderApplySearchTerms(f)
	local applied = false
	if TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.ApplyFilters then
		applied = pcall(TRADING_HOUSE_SEARCH.ApplyFilters, TRADING_HOUSE_SEARCH, true)
	end
	if not applied then FMS_Call(ClearAllTradingHouseSearchTerms) end

	if trader.nameHashes and #trader.nameHashes > 0 then
		pcall(SetTradingHouseFilter, TRADING_HOUSE_FILTER_TYPE_NAME_HASH, unpack(trader.nameHashes))
	end
	if f.maxPrice then
		pcall(SetTradingHouseFilterRange, TRADING_HOUSE_FILTER_TYPE_PRICE, nil, f.maxPrice)
	end
	if f.quality then
		local qualities = {}
		for q = f.quality, 6 do qualities[#qualities + 1] = q end
		pcall(SetTradingHouseFilter, TRADING_HOUSE_FILTER_TYPE_QUALITY, unpack(qualities))
	end
end

-- Waits out the store's search cooldown (and any search the store UI itself
-- is running), then requests a page
FMS_TraderQueueSearch = function(page)
	trader.page = page
	trader.token = trader.token + 1
	local myToken = trader.token
	local wait = (FMS_Call(GetTradingHouseCooldownRemaining) or 0) + 250
	zo_callLater(function()
		if not trader.scanning or not trader.open or myToken ~= trader.token then return end
		local cooldown = FMS_Call(GetTradingHouseCooldownRemaining) or 0
		local uiBusy = TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.CanPerformSearch
			and not TRADING_HOUSE_SEARCH:CanPerformSearch()
		if cooldown > 0 or uiBusy then
			FMS_TraderQueueSearch(page)
			return
		end
		FMS_TraderApplySearchTerms(trader.filter)
		trader.awaiting = true
		local ok, err = pcall(ExecuteTradingHouseSearch, page,
			TRADING_HOUSE_SORT_SALE_PRICE or TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT,
			ZO_SORT_ORDER_UP ~= nil and ZO_SORT_ORDER_UP or true, false)
		if not ok then
			trader.awaiting = false
			FMS_TraderFinish("failed (" .. tostring(err) .. ")")
			return
		end
		-- Watchdog: if the server never answers, move on to the next guild
		zo_callLater(function()
			if trader.scanning and myToken == trader.token then
				trader.awaiting = false
				d(PREFIX .. "No response from the trader, skipping to the next guild.")
				FMS_TraderNextGuild()
			end
		end, 20000)
	end, wait)
end

-- Turns the filter words into the store's item-name hashes (the same lookup
-- the store's own name search uses). Calls done() when finished.
local function FMS_TraderMatchNames(words, done)
	trader.nameHashes = nil
	local text = table.concat(words, " ")
	local minLetters = FMS_Call(GetMinLettersInTradingHouseItemNameForCurrentLanguage) or 2
	if text == "" or #text < minLetters or not MatchTradingHouseItemNames then
		done()
		return
	end
	local ok, id = pcall(MatchTradingHouseItemNames, text)
	if not ok or not id then
		done()
		return
	end
	trader.nameMatchId = id
	local eventName = FindMyStuff.Name .. "_TraderNames"
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE)
		trader.nameMatchId = nil
		done()
	end
	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE, function(_, matchId, numResults)
		if matchId ~= trader.nameMatchId then return end
		numResults = numResults or FMS_Call(GetNumMatchTradingHouseItemNamesResults, matchId) or 0
		local maxTerms = FMS_Call(GetMaxTradingHouseFilterExactTerms, TRADING_HOUSE_FILTER_TYPE_NAME_HASH) or 0
		if numResults == 0 then
			d(PREFIX .. "No item names contain \"" .. text .. "\", scanning without a name filter.")
		elseif maxTerms > 0 and numResults > maxTerms then
			d(PREFIX .. "\"" .. text .. "\" matches " .. numResults .. " item names (the store takes " .. maxTerms
				.. "), so the name is checked on each page instead. Use more words for a faster scan.")
		else
			local hashes = {}
			for i = 1, numResults do
				local _, hash = GetMatchTradingHouseItemNamesResult(matchId, i)
				if hash then hashes[#hashes + 1] = hash end
			end
			trader.nameHashes = hashes
		end
		finish()
	end)
	-- never hang the scan on the name lookup
	zo_callLater(function()
		if not finished then
			FMS_Call(CancelMatchTradingHouseItemNames, id)
			finish()
		end
	end, 5000)
end

-- Puts the filter words into the store's own name search box, so the store
-- shows what is being searched for. It also stops an old word left in that box
-- from narrowing our search (the store's name filter is applied with ours).
local function FMS_SyncStoreSearchBox(text)
	local feature
	if TRADING_HOUSE_SEARCH and TRADING_HOUSE_SEARCH.features then
		feature = TRADING_HOUSE_SEARCH.features.nameSearchFeature
	end
	if not feature and GAMEPAD_TRADING_HOUSE_BROWSE and GAMEPAD_TRADING_HOUSE_BROWSE.GetNameSearchFeature then
		local ok, f = pcall(GAMEPAD_TRADING_HOUSE_BROWSE.GetNameSearchFeature, GAMEPAD_TRADING_HOUSE_BROWSE)
		if ok then feature = f end
	end
	if not feature or not feature.SetSearchText then return end
	local current = feature.GetSearchText and feature:GetSearchText() or nil
	if current == text then return end
	local ok, err = pcall(feature.SetSearchText, feature, text)
	if not ok then
		d(PREFIX .. "Couldn't fill the store's search box: " .. tostring(err))
	end
end

local function FMS_StartTraderScan()
	trader.pendingScan = false
	trader.scanning = true
	trader.matches = 0
	trader.pagesDone = 0
	trader.seen = {}
	trader.rows = {}
	trader.guildQueue = {}
	trader.guildIndex = 0
	FindMyStuff.SavedVariables.traderLog = {}
	if trader.filter.allGuilds then
		for i = 1, (FMS_Call(GetNumTradingHouseGuilds) or 0) do
			trader.guildQueue[#trader.guildQueue + 1] = (GetTradingHouseGuildDetails(i))
		end
	end
	if #trader.guildQueue == 0 then
		trader.guildQueue[1] = FMS_Call(GetSelectedTradingHouseGuildId)
	end
	d(PREFIX .. "Filtering guild trader listings for " .. FMS_DescribeTraderFilter(trader.filter)
		.. " (up to " .. trader.filter.maxPages .. " page(s) per guild). Uses the category you picked in the store.")
	FMS_TraderChanged()
	FMS_SyncStoreSearchBox(table.concat(trader.filter.hashWords or trader.filter.words, " "))
	FMS_TraderMatchNames(trader.filter.hashWords or trader.filter.words, function()
		if trader.scanning then FMS_TraderNextGuild() end
	end)
end

local FMS_ProcessTraderPage -- forward declaration

-- The store reports search results through EVENT_TRADING_HOUSE_RESPONSE_RECEIVED;
-- the page itself is read with GetTradingHouseSearchResultsInfo().
local function FMS_OnTraderResponse(_, responseType, result)
	if responseType ~= TRADING_HOUSE_RESULT_SEARCH_PENDING then return end
	if not trader.scanning or not trader.awaiting then return end
	trader.awaiting = false
	if result ~= TRADING_HOUSE_RESULT_SUCCESS then
		trader.token = trader.token + 1 -- cancel the watchdog
		if FMS_Call(GetTradingHouseCooldownRemaining) and GetTradingHouseCooldownRemaining() > 0 then
			FMS_TraderQueueSearch(trader.page) -- rate limited, try this page again
		else
			d(PREFIX .. "The store refused the search, skipping to the next guild.")
			FMS_TraderNextGuild()
		end
		return
	end
	local numItems, page, hasMorePages = GetTradingHouseSearchResultsInfo()
	FMS_ProcessTraderPage(FMS_Call(GetSelectedTradingHouseGuildId), numItems, page or trader.page, hasMorePages)
end

FMS_ProcessTraderPage = function(guildId, numItems, page, hasMorePages)
	if not trader.filter then return end
	local guildName = FMS_TraderGuildName(guildId)
	local log = FindMyStuff.SavedVariables.traderLog or {}
	FindMyStuff.SavedVariables.traderLog = log
	local toChat = FMS_Setting("traderChat")
	local cheapest
	for i = 1, (numItems or 0) do
		local _, _, _, _, _, _, price = GetTradingHouseSearchResultItemInfo(i)
		if price and (not cheapest or price < cheapest) then cheapest = price end
		local row, key = FMS_TraderCheckResult(trader.filter, i, guildName)
		if row and not trader.seen[key] then
			trader.seen[key] = true
			trader.matches = trader.matches + 1
			trader.rows[#trader.rows + 1] = row
			if toChat then d(row.line) end
			if #log < FMS_TRADER_LOG_MAX then log[#log + 1] = row end
		end
	end
	FMS_TraderChanged()

	if not trader.scanning then return end
	trader.pagesDone = trader.pagesDone + 1
	trader.token = trader.token + 1 -- cancels the watchdog for this page
	-- Results are sorted cheapest first, so once a whole page is over budget we can stop
	local overBudget = trader.filter.maxPrice and cheapest and cheapest > trader.filter.maxPrice
	if hasMorePages and not overBudget and (page + 1) < trader.filter.maxPages then
		FMS_TraderQueueSearch(page + 1)
	else
		FMS_TraderNextGuild()
	end
end

-- Public trader API (used by slash commands, the window and the gamepad screen)
function FindMyStuff.StartTraderFilter(text)
	local filterText = FMS_Trim(text)
	local filter = FMS_BuildTraderFilter(filterText)
	if filter.leadMode and #filter.leadTargets == 0 then
		d(PREFIX .. "No antiquities match " .. FMS_DescribeTraderFilter(filter) .. ", so there's nothing to look for.")
		FMS_TraderChanged()
		return false
	end
	trader.filterText = filterText
	trader.filter = filter
	if trader.open then
		FMS_StartTraderScan()
	else
		trader.pendingScan = true
		d(PREFIX .. "Filter set for " .. FMS_DescribeTraderFilter(trader.filter) .. ". Open a guild trader and the scan starts automatically.")
		FMS_TraderChanged()
	end
	return true
end

-- Searches guild trader listings for antiquity leads.
-- text: item / antiquity / set / zone words, plus the flags
--   mythic (only mythic leads), have, missing, new, and the usual trader
--   options (max:gold, unit:gold, pages:N, all).
-- e.g. FindMyStuff.StartTraderLeadSearch("mythic")
--      FindMyStuff.StartTraderLeadSearch("ring of the wild hunt")
function FindMyStuff.StartTraderLeadSearch(text)
	return FindMyStuff.StartTraderFilter("leads " .. FMS_Trim(text or ""))
end

function FindMyStuff.IsTraderLeadSearch()
	return trader.filter ~= nil and trader.filter.leadMode == true
end

function FindMyStuff.StopTrader()
	local wasScanning = trader.scanning
	trader.filter = nil
	trader.pendingScan = false
	trader.scanning = false
	trader.awaiting = false
	trader.guildName = nil
	trader.token = trader.token + 1
	d(PREFIX .. "Trader filter " .. (wasScanning and "stopped." or "cleared."))
	FMS_TraderChanged()
end

function FindMyStuff.IsTraderFilterActive()
	return trader.filter ~= nil
end

function FindMyStuff.GetTraderFilterText()
	return trader.filterText or ""
end

-- Matches from this session, or the saved matches from the last scan
function FindMyStuff.GetTraderRows()
	if #trader.rows > 0 then return trader.rows end
	local rows = {}
	for _, entry in ipairs(FindMyStuff.SavedVariables.traderLog or {}) do
		if type(entry) == "table" then
			rows[#rows + 1] = entry
		elseif type(entry) == "string" then
			rows[#rows + 1] = {line = entry, title = entry, detail = ""}
		end
	end
	return rows
end

function FindMyStuff.GetTraderStatus()
	if trader.scanning then
		return "Scanning " .. (trader.guildName or "guild trader") .. ", page " .. (trader.page + 1)
			.. " - " .. trader.matches .. " match(es) so far"
	elseif trader.pendingScan then
		return "Filter set for " .. FMS_DescribeTraderFilter(trader.filter) .. ". Open a guild trader to start."
	elseif trader.filter then
		return "Filter active for " .. FMS_DescribeTraderFilter(trader.filter) .. " - " .. trader.matches .. " match(es)"
	elseif #trader.rows == 0 and #(FindMyStuff.SavedVariables.traderLog or {}) > 0 then
		return "Showing the matches from your last scan."
	end
	return trader.open and "Guild store open. Enter a filter and search." or "Open a guild store, pick a category, then search."
end

local function FMS_TraderHelp()
	d(PREFIX .. "Usage: /fmstrader <words> [trait:x] [quality:epic] [max:gold] [unit:gold] [pages:N] [unknown] [all]")
	d("  Pick a category in the guild store, then run the command to page through and filter the listings.")
	d("  all = scan every guild store you can reach (at a bank).  unknown = only recipes/motifs/styles you don't know.")
	d("  /fmstrader stop - turn the filter off    /fmstrader last - show the last matches")
	d("  /fmstrader leads [mythic] [item words] [have|missing|new] - look for antiquity leads (also /fmstraderlead)")
end

local function TraderLeadCommand(text)
	if FMS_Trim(text):lower() == "help" then
		d(PREFIX .. "Usage: /fmstraderlead [mythic] [item words] [have] [missing] [new] [max:gold] [pages:N] [all]")
		d("  Scans guild store listings for antiquity leads. Words match the antiquity, its set, its zone,")
		d("  or the item it makes. mythic = only leads for mythic items. Example: /fmstraderlead mythic")
		d("  Example: /fmstraderlead ring of the wild hunt")
		return
	end
	FindMyStuff.StartTraderLeadSearch(text)
end

local function TraderCommand(text)
	text = FMS_Trim(text)
	local lower = text:lower()
	if lower == "" or lower == "help" then
		FMS_TraderHelp()
	elseif lower == "stop" or lower == "clear" or lower == "off" then
		FindMyStuff.StopTrader()
	elseif lower == "last" then
		local rows = FindMyStuff.GetTraderRows()
		if #rows == 0 then
			d(PREFIX .. "No saved trader matches.")
		else
			FMS_PrintRows(rows, "Last " .. #rows .. " trader match(es):")
		end
	else
		FindMyStuff.StartTraderFilter(text)
	end
end

local function FMS_OnTraderOpen()
	trader.open = true
	FMS_TraderChanged()
	if trader.pendingScan and trader.filter then
		-- give the store UI a moment to finish opening
		zo_callLater(function()
			if trader.open and trader.pendingScan then FMS_StartTraderScan() end
		end, 1500)
	end
end

local function FMS_OnTraderClose()
	trader.open = false
	if trader.scanning then
		FMS_TraderFinish("stopped (store closed)")
	else
		FMS_TraderChanged()
	end
end

-- ========================
-- ANTIQUITY LEAD SEARCH
-- ========================

local LEAD_FLAGS = {have = true, missing = true, new = true, all = true, help = true, mythic = true}

local function FMS_FormatDuration(seconds)
	seconds = seconds or 0
	local days = math.floor(seconds / 86400)
	if days >= 1 then return days .. "d" end
	local hours = math.floor(seconds / 3600)
	if hours >= 1 then return hours .. "h" end
	return math.max(1, math.floor(seconds / 60)) .. "m"
end

-- Returns rows, summary, errorText, parsedOptions
function FindMyStuff.SearchLeads(text)
	if type(GetNextAntiquityId) ~= "function" then
		return nil, nil, "Antiquities aren't available in this game version."
	end
	local o = FMS_ParseOptions(FMS_Trim(text), LEAD_FLAGS)

	local results = {}
	local totalLeads, held = 0, 0
	local id = GetNextAntiquityId()
	while id and id ~= 0 do
		local requiresLead = FMS_Call(DoesAntiquityRequireLead, id)
		if requiresLead ~= false or o.flags.all then
			local name = FMS_CleanName(GetAntiquityName(id))
			local zoneId = FMS_Call(GetAntiquityZoneId, id) or 0
			local zoneName = zoneId ~= 0 and FMS_CleanName(GetZoneNameById(zoneId)) or "Anywhere"
			local setId = FMS_Call(GetAntiquitySetId, id) or 0
			local setName = setId ~= 0 and FMS_CleanName(FMS_Call(GetAntiquitySetName, setId)) or ""
			local hasLead = FMS_Call(DoesAntiquityHaveLead, id) and true or false
			local recovered = FMS_Call(GetNumAntiquitiesRecovered, id) or 0
			totalLeads = totalLeads + 1
			if hasLead then held = held + 1 end

			local haystack = (name .. " " .. setName .. " " .. zoneName):lower()
			local keep = FMS_MatchesAllWords(haystack, o.words)
				and not (o.flags.have and not hasLead)
				and not (o.flags.missing and hasLead)
				and not (o.flags.new and recovered > 0)
				and not (o.flags.mythic and not FindMyStuff.IsMythicAntiquity(id))
			if keep then
				results[#results + 1] = {
					id = id, name = name, zone = zoneName, set = setName, hasLead = hasLead,
					recovered = recovered, quality = FMS_Call(GetAntiquityQuality, id) or 1,
				}
			end
		end
		id = GetNextAntiquityId(id)
	end

	table.sort(results, function(a, b)
		if a.zone ~= b.zone then return a.zone < b.zone end
		return a.name < b.name
	end)

	local rows = {}
	for _, r in ipairs(results) do
		local qColor = FMS_QUALITY_COLORS[r.quality] or FMS_QUALITY_COLORS[1]
		local leadStr, leadPlain
		if r.hasLead then
			local remaining = FMS_Call(GetAntiquityLeadTimeRemainingSeconds, r.id)
			local left = (remaining and remaining > 0) and (", " .. FMS_FormatDuration(remaining) .. " left") or ""
			leadStr = " |c2DC50E[Have lead" .. left .. "]|r"
			leadPlain = "You have this lead" .. left
		else
			leadStr = " |caaaaaa[No lead]|r"
			leadPlain = "You don't have this lead"
		end
		local foundStr = r.recovered > 0 and (" |caaaaaa(dug up x" .. r.recovered .. ")|r") or " |c5BCEFA(never found)|r"
		local detail = {"Zone: " .. r.zone}
		if r.set ~= "" then detail[#detail + 1] = "Set: " .. r.set end
		detail[#detail + 1] = leadPlain
		detail[#detail + 1] = r.recovered > 0 and ("Dug up " .. r.recovered .. " time(s)") or "Never found"
		rows[#rows + 1] = {
			line = "  " .. qColor .. r.name .. "|r" .. (r.set ~= "" and (" |caaaaaa<" .. r.set .. ">|r") or "")
				.. " - |cffff00" .. r.zone .. "|r" .. leadStr .. foundStr,
			title = qColor .. r.name .. "|r" .. (r.hasLead and " |c2DC50E(lead)|r" or ""),
			detail = table.concat(detail, "\n"),
		}
	end

	local summary
	if #rows == 0 then
		summary = "No leads found" .. (#o.words > 0 and (" for |cffff00" .. table.concat(o.words, " ") .. "|r") or "") .. "."
	else
		summary = "|cffff00" .. #rows .. "|r lead(s) found (you hold " .. held .. " of " .. totalLeads .. ")."
	end
	return rows, summary, nil, o
end

local function LeadCommand(text)
	if FMS_Trim(text):lower() == "help" then
		d(PREFIX .. "Usage: /fmslead [words] [mythic] [have] [missing] [new] [all] [page:N]")
		d("  mythic = only antiquities that make a mythic item. /fmstraderlead looks for leads in guild stores.")
		d("  Words match the antiquity, its set, or its zone. have = leads you hold, missing = leads you don't,")
		d("  new = never recovered, all = include antiquities that don't need a lead.")
		return
	end
	local rows, summary, err, o = FindMyStuff.SearchLeads(text)
	if err or #rows == 0 then
		FMS_PrintRows(nil, summary, err)
		return
	end
	local perPage = FMS_Setting("maxResults")
	local pages = math.ceil(#rows / perPage)
	local page = math.min(math.max(1, tonumber(o.page) or 1), pages)
	local first = (page - 1) * perPage + 1
	local last = math.min(#rows, page * perPage)
	d(PREFIX .. summary .. " Showing " .. first .. "-" .. last
		.. (pages > 1 and (", page " .. page .. "/" .. pages .. " - add page:" .. (page % pages + 1) .. " for more") or "") .. ".")
	for i = first, last do d(rows[i].line) end
end

-- ========================
-- INITIALIZATION
-- ========================

function FindMyStuff:Initialize()
	for key, value in pairs(FindMyStuff.SettingDefaults) do
		if FindMyStuff.Default[key] == nil then FindMyStuff.Default[key] = value end
	end
	FindMyStuff.SavedVariables = ZO_SavedVars:NewAccountWide("FindMyStuffSV", FindMyStuff.SettingsVersion, nil, FindMyStuff.Default)
	EVENT_MANAGER:UnregisterForEvent(FindMyStuff.Name, EVENT_ADD_ON_LOADED)
	FindMyStuff.Default = {quality=FindMyStuff.SavedVariables.quality,level=FindMyStuff.SavedVariables.level}
	link_suffix = ":" .. FindMyStuff.Default.quality .. ":" .. FindMyStuff.Default.level .. base_suffix
	max_results = FMS_Setting("maxResults")
	if FMS_Setting("showLogin") then
		d("FindMyStuff v" .. FindMyStuff.Version .. " loaded. Type /fms to open the window or /fmshelp for commands.")
	end
	-- Inventory cross-character search
	SLASH_COMMANDS["/finditem"] = FindInInventory
	SLASH_COMMANDS["/fmsscan"] = function()
		FindMyStuff.ScanInventory()
		d(PREFIX .. "Inventory rescanned.")
	end
	--Tries to find all recipes/blueprints
	SLASH_COMMANDS["/fmsdump"] = Dump
	--Allows changing the found item quality
	SLASH_COMMANDS["/fmssetquality"] = SetQuality
	--Shows command usage
	SLASH_COMMANDS["/fmshelp"] = IFHelp
	-- Guild trader filtering
	SLASH_COMMANDS["/fmstrader"] = TraderCommand
	SLASH_COMMANDS["/fmstraderlead"] = TraderLeadCommand
	SLASH_COMMANDS["/fmstraderleads"] = TraderLeadCommand
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Trader", EVENT_OPEN_TRADING_HOUSE, FMS_OnTraderOpen)
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Trader", EVENT_CLOSE_TRADING_HOUSE, FMS_OnTraderClose)
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Trader", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, FMS_OnTraderResponse)
	-- Antiquity lead search
	SLASH_COMMANDS["/fmslead"] = LeadCommand
	SLASH_COMMANDS["/fmsleads"] = LeadCommand
	-- Window / gamepad screen
	SLASH_COMMANDS["/fms"] = function(text) FindMyStuff.ShowUI(FMS_Trim(text):lower()) end

	-- Auto-scan inventory on each login (3 second delay to ensure bags are loaded)
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name .. "_Inv", EVENT_PLAYER_ACTIVATED, function()
		zo_callLater(FindMyStuff.ScanInventory, 3000)
	end)
	EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name, EVENT_LOOT_UPDATED, function()
		if FMS_Setting("autoScan") then
			zo_callLater(FindMyStuff.ScanInventory, 3000)
		end
	end)

	-- UI pieces live in their own files; each is optional
	for _, init in ipairs({FindMyStuff.InitWindow, FindMyStuff.InitGamepad, FindMyStuff.InitSettings}) do
		if type(init) == "function" then
			local ok, err = pcall(init)
			if not ok then d(PREFIX .. "UI setup error: " .. tostring(err)) end
		end
	end
end

-- Opens the gamepad screen in gamepad mode, the window otherwise. tab = "items" | "traders" | "leads"
function FindMyStuff.ShowUI(tab)
	if tab == "" then tab = nil end
	if IsInGamepadPreferredMode() and FindMyStuff.ShowGamepad then
		if not tab and FindMyStuff.IsGamepadShowing and FindMyStuff.IsGamepadShowing() then
			FindMyStuff.CloseGamepad()
		else
			FindMyStuff.ShowGamepad(tab)
		end
	elseif FindMyStuff.ToggleWindow then
		FindMyStuff.ToggleWindow(tab)
	end
end

function FindMyStuff:OnAddOnLoaded(event, addonName)
	FindMyStuff:Initialize()
end

EVENT_MANAGER:RegisterForEvent(FindMyStuff.Name, EVENT_ADD_ON_LOADED, function(event, addonName)
	if addonName == FindMyStuff.Name then
		FindMyStuff:OnAddOnLoaded(event, addonName)
	end
end)
