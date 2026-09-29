YANP = {
	name = "YANP",
	settingsRev = 1,
	version = "1.13",
    author = "SimonIllyan",
	prefix = "[YANP] ",
}

local LAM2 = LibAddonMenu2
local LFDB = LIB_FOOD_DRINK_BUFF
local LSD = LibSetDetection
local LS = LibSets
local LSV = LibSavedVars

local settings
local defaults = {
    colors = {
        critical  = { r = 1,   g = 0,  b = 0,   a = 1, }, -- red
        danger    = { r = 1,   g = 0,  b = 0,   a = 1, }, -- red
        warning   = { r = 1,   g = .5, b = 0,   a = 1, }, -- orange
        caution   = { r = 1,   g = 1,  b = 0,   a = 1, }, -- yellow
        active    = { r = 0,   g = 1,  b = 1,   a = 1, }, -- cyan
        good      = { r = 0,   g = 1,  b = 0,   a = 1, }, -- green
        normal    = { r = .8,  g = .8, b = 0.8, a = 1, }, -- off-white
        highlight = { r = 1,   g = 1,  b = 1,   a = 1, }, -- white
        header    = { r = .81, g = .7, b = .15, a = 1, }, -- dark yellow

    },
	verbosity = 1,
}

local G = {
	colors = {},
}
YANP.G = G -- for debugging

local YANP_LIST_DATA_TYPE = 1
local YANP_LIST_SEPARATOR_TYPE = 2
local YANP_ROW_HEIGHT = 22

local soul_or_repair = {
    [33271] = "normal_filled",
    [61080] = "crown_filled",
    [44879] = "grandRepairKit",
    [61079] = "crownRepairKit",
	[157516] = "groupRepairKit",
}

local repairKits = {
    { "grandRepairKit", "Equipment Repair Kit", },
    { "crownRepairKit", "Crown Repair Kit", },
    { "groupRepairKit", "Group Repair Kit", },
}

local mundusStoneReference = {
	"Warrior", "Mage", "Thief", "Serpent", "Lady", "Steed", "Lord",
	"Apprentice", "Atronach", "Ritual", "Lover", "Shadow", "Tower",
}

local constellation_map = {
    {"craft", "stamina"}, {"warfare", "magicka"}, {"fitness", "health"}, 
}

local attributes_map = {
    {"fitness", "health"}, {"warfare", "magicka"}, {"craft", "stamina"}, 
}

local compass = { "SE", "E", "NE", "N", "NW", "W", "SW", "S" }

local roles = { "Damage", "Tank", "", "Healer" }

local function chat(level, fmt, ...)
	local verbosity
	if YANP and YANP.settings then
		verbosity = YANP.settings.verbosity
		if verbosity == nil then
			d(YANP.prefix .. "Verbosity not set!")
			verbosity = 4
		end
		if level <= verbosity then
			local args = {...}
			-- find max key - some keys may be missing, 
			-- if corresponding arguments are nil!
			local last_k = 0
			for k, _ in pairs(args) do
				if k > last_k then
					last_k = k
				end
			end
			if last_k > 0 then
				local t = {}
				for k = 1, last_k do
					table.insert(t, tostring(args[k])) -- tostring handles nil just fine
				end
				df(YANP.prefix .. fmt, unpack(t))
			else
				d(YANP.prefix .. fmt)
			end
		end
	else
		d(YANP.prefix .. "YANP.settings missing!")
	end
end

local function FillColors(name_color_table)
    for k, v in pairs(name_color_table) do
        G.colors[k] = ZO_ColorDef:New(v)
    end
end

local function ConvertSeconds(displayMethod, seconds)
    local struct = os.date("!*t", seconds)
    local exact_time = os.date("!%Hh%Mm%Ss", seconds)
    struct.yday = struct.yday - 1 -- yday is never 0 - New Year is 1st day of the year, not 0th
    if displayMethod == "exact" then
        return (struct.yday > 0 and string.format("%dd", struct.yday) or "") .. exact_time
    elseif displayMethod == "short" then
        return struct.yday > 0 and string.format("%dd%dh", struct.yday, struct.hour) or
        struct.hour > 0 and string.format("%dh%dm", struct.hour, struct.min) or
        struct.min > 0 and string.format("%dm%ds", struct.min, struct.sec) or
        string.format("%ds", struct.sec)
    elseif displayMethod == "simple" then
        return struct.yday > 0 and string.format("%dd", struct.yday) or
        struct.hour > 0 and string.format("%dh", struct.hour) or
        struct.min > 0 and string.format("%dm", struct.min) or
        string.format("%ds", struct.sec)
    end
end

local function topNitems(N, dict)
	local array = { }
	for k, v in pairs(dict) do
		table.insert(array, { key=k, value=v })
	end
	table.sort(array, function(a,b) return a.value > b.value end)
	local top = {}
	local n = N < #array and N or #array 
	for i = 1, n do
		top[i] = array[i]
	end
	return top
end

local function bagItems(pane)
    local bagUsedSlots, bagMaxSlots = PLAYER_INVENTORY:GetNumSlots(INVENTORY_BACKPACK)
    G.kits, G.foods, G.potions = { }, { }, { }
    for _, n in pairs(soul_or_repair) do
        G.kits[n] = 0
    end
    for slotIndex = 0, bagMaxSlots-1 do
        local itemLink = GetItemLink( INVENTORY_BACKPACK, slotIndex )
        local itemType, specializedItemType = GetItemLinkItemType( itemLink )
        local itemId = GetItemLinkItemId( itemLink )
        local repair_or_soulgem = soul_or_repair[itemId]
		local inventoryCount, bankCount, craftBagCount = GetItemLinkStacks(itemLink)
		local name = GetItemLinkName(itemLink) -- may contain localization control codes	
		local formattedName = zo_strformat("<<t:1>>", name) -- no control codes
		if itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK then
            G.foods[formattedName] = inventoryCount
		elseif itemType == ITEMTYPE_POTION then
            G.potions[formattedName] = inventoryCount
		elseif repair_or_soulgem then
            G.kits[repair_or_soulgem] = inventoryCount
        end
    end
    -- soul gems
	table.insert(pane, { label =  G.colors.header:Colorize("Soul gems"), value = "" })
	local soulgemColor = G.kits.normal_filled + G.kits.crown_filled < 10 and G.colors.danger or G.colors.good
    table.insert(pane, { label =  soulgemColor:Colorize("Regular"), value = soulgemColor:Colorize(G.kits.normal_filled) })
    table.insert(pane, { label =  soulgemColor:Colorize("Crown"), value = soulgemColor:Colorize(G.kits.crown_filled) })
	table.insert(pane, { label = "", value = "" })
	-- repair kits
	table.insert(pane, { label =  G.colors.header:Colorize("Repair kits"), value = "" })
    for _, p in ipairs(repairKits) do
        table.insert(pane, { label =  G.colors.good:Colorize(p[2]), value = G.colors.good:Colorize(G.kits[p[1]]) })
    end
	table.insert(pane, { label = "", value = "" })
	-- foods
	local foods = topNitems(3, G.foods)
	if #foods > 0 then
		table.insert(pane, { label = G.colors.header:Colorize("Largest food stacks"), value = "" })
		for _, p in ipairs(foods) do
			table.insert(pane, { label = p.key, value = p.value })	
		end
	else
		table.insert(pane, { label = G.colors.danger:Colorize("No food!"), value = "" })
	end
	table.insert(pane, { label = "", value = "" })
	-- potions
	local potions = topNitems(3, G.potions)
	if #potions > 0 then
		table.insert(pane, { label = G.colors.header:Colorize("Largest potion stacks"), value = "" })
		for _, p in ipairs(potions) do
			table.insert(pane, { label = p.key, value = p.value })	
		end
	else
		table.insert(pane, { label = G.colors.danger:Colorize("No potions!"), value = "" })
	end
	table.insert(pane, { label = "", value = "" })
end

local function equipped(pane)
	local lang = "en"
	table.insert(pane, { label =  G.colors.header:Colorize("Currently Equipped"), value = "" })
    local equip_sets = LSD.GetEquippedSetsTable()
	-- this loop based on CurrentlyEquipped addon
    for setID, info in pairs(equip_sets) do
		local set_max_equip = 0
		local set_num_equip = 0
		local temp_bar = 0
		local set_name
        if info.name ~= "" then
            set_name = info.name
        else
            set_name = LS.GetSetName(setID, lang)
        end
        if info.maxEquipped ~= 0 then 
            set_max_equip = info.maxEquipped
        else
            _, set_max_equip, _ = LS.GetNumEquippedItemsBySetId(setID)
        end
        -- If body pieces, add them, if weapons, add highest value, otherwise double barred set will add front and back
        for loc, num_equip in pairs(info.numEquipped) do
            if loc == "body" then 
                set_num_equip = set_num_equip + num_equip
            elseif num_equip > temp_bar then
                set_num_equip = set_num_equip + num_equip - temp_bar
                temp_bar = num_equip
            end            
        end
		local tmp_right = string.format("%d/%s", set_num_equip, set_max_equip)
		local setColor = G.colors.good
		if set_name == "Ring of the Pale Order" then
			setColor = G.colors.danger
		elseif set_num_equip < set_max_equip and LS.IsMonsterSet(setID) or set_num_equip > set_max_equip then -- underequipped monster or overequipped
			setColor = G.colors.caution
		elseif set_num_equip < set_max_equip then -- underequipped and not monster
			setColor = G.colors.warning
		end
		table.insert(pane, { label = setColor:Colorize(set_name), value = setColor:Colorize(tmp_right) })
	end
	table.insert(pane, { label = "", value = "" })
end

local function attributes(pane)
	table.insert(pane, { label = G.colors.header:Colorize("Attributes and skill points"), value = "" })
	local unspent = GetAttributeUnspentPoints()
	local sp = GetAvailableSkillPoints()
	for i, r in ipairs(attributes_map) do
		local c, name = unpack(r)
		local attr = GetAttributeSpentPoints(i)
		local color = G.colors[c]
		table.insert(pane, { label = color:Colorize(zo_strformat("<<C:1>>", name)), value = color:Colorize(attr) })
	end
	if unspent > 0 then
		table.insert(pane, { label = G.colors.danger:Colorize("Unspent attribute points"), value = G.colors.danger:Colorize(unspent) })
	end
	if sp > 0 then
		table.insert(pane, { label = G.colors.danger:Colorize("Unspent skill points"), value = G.colors.danger:Colorize(sp) })
	end
	table.insert(pane, { label = "", value = "" })
end

local function buffs(pane)
    -- food
    local isBuffActive, timeLeftInSeconds, abilityId =
        LFDB:IsFoodBuffActiveAndGetTimeLeft("player")
    table.insert(pane, { label = G.colors.header:Colorize("Active buffs"), value = "" })
	local foodColor = timeLeftInSeconds < 3600 and G.colors.danger or G.colors.good
    table.insert(pane, { label = foodColor:Colorize("Food remaining"), value = foodColor:Colorize(ConvertSeconds("short", timeLeftInSeconds)) })
    -- mundus
    local mundus
    numBuffs = GetNumBuffs("player")
    if numBuffs then
        for i = 0, numBuffs, 1 do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, textureName,
                buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff =
                GetUnitBuffInfo("player", i)
            if textureName and textureName ~= "" then
                if PlainStringFind(textureName, "ability_mundusstones_") then
                    mundus = tonumber(string.sub(textureName,-7, -5))
				end
            end
        end
    end
	local mundusColor = mundus and G.colors.good or G.colors.danger
    table.insert(pane, { label = mundusColor:Colorize("Mundus Stone"), 
		value = mundusColor:Colorize(mundus and mundusStoneReference[mundus] or"None") })
	table.insert(pane, { label = "", value = "" })
end

local function durability(pane)
    local totalRepairCost = 0
    local mostDamagedItem = 0
    local mostDamagedCondition = 100
	local totalDurability = 0
	local itemCount = 0
    table.insert(pane, { label =  G.colors.header:Colorize("Armor durability"), value = "" })
    for slotIndex = 0, 16, 1 do
        if DoesItemHaveDurability(BAG_WORN, slotIndex) then
            local repairCost = GetItemRepairCost(BAG_WORN, slotIndex) or 0
            totalRepairCost = totalRepairCost + repairCost
            local condition = GetItemCondition(BAG_WORN, slotIndex)
			if condition and condition < mostDamagedCondition then
                mostDamagedItem = slotIndex
                mostDamagedCondition = condition
            end
			itemCount = itemCount + 1
			totalDurability = totalDurability + condition
        end
    end
	local durabilityColor = mostDamagedCondition == 100 and G.colors.good or G.colors.danger
	--table.insert(pane, { label = durabilityColor:Colorize(zo_strformat("<<C:1>>", GetItemName(BAG_WORN, mostDamagedItem))), 
	table.insert(pane, { label = durabilityColor:Colorize("Lowest durability"), 
		value = durabilityColor:Colorize(string.format("%d%%", mostDamagedCondition)) })
	table.insert(pane, { label = durabilityColor:Colorize("Average durability"), 
		value = durabilityColor:Colorize(string.format("%.0f%%", totalDurability / itemCount)) })
    -- table.insert(pane, { label = G.colors.normal:Colorize("Total Repair Cost"), 
    -- value = G.colors.normal:Colorize(zo_strformat("<<1>>g", ZO_LocalizeDecimalNumber(totalRepairCost))) })
	table.insert(pane, { label = "", value = "" })
end

local function champion(panes)
	for c, constellation in ipairs(constellation_map) do
		local pane = panes[c]
		local name, attr = unpack(constellation)
		local unspent = GetNumUnspentChampionPoints( (c+1) % 3 + 1 ) 
		local cpColor = unspent == 0 and G.colors.good or G.colors.danger
		table.insert(pane, { label =  G.colors[name]:Colorize(string.format("Unspent %s points", name)), value = cpColor:Colorize(tostring(unspent)) })
		for i = 1, 4 do
			local championSkillId = GetSlotBoundId(i + c * 4 - 4, HOTBAR_CATEGORY_CHAMPION)
			table.insert(pane, { label = GetChampionSkillName(championSkillId), value = "" })
		end	
	end
end

local function quickslots(pane)
    table.insert(pane, { label =  G.colors.header:Colorize("Quick Slots"), value = "" })
	local quickslots = ZO_GetUtilityWheelSlottedEntries(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
	for i, slot in ipairs(quickslots) do
		local name = GetSlotName(i, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
		local link = GetSlotItemLink(i, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
		local inventoryCount, bankCount, craftBagCount = GetItemLinkStacks(link)
        table.insert(pane, { label = name, value = inventoryCount })		
	end
	table.insert(pane, { label = "", value = "" })
end

local function role(pane)
	local selected_role = GetSelectedLFGRole()
    table.insert(pane, { label =  G.colors.header:Colorize("Selected Role"), value = G.colors.header:Colorize(roles[selected_role]) })
	table.insert(pane, { label = "", value = "" })
end

local function getitemcharge(slotNum)
    local itemLink = GetItemLink( BAG_WORN, slotNum )
    if itemLink == nil or not IsItemChargeable( BAG_WORN, slotNum ) then
        return 10000
    end
    return math.floor(100 * GetItemLinkNumEnchantCharges(itemLink) / GetItemLinkMaxEnchantCharges(itemLink))
end

local function wc(pane)
    local activeWeaponPair, locked = GetActiveWeaponPairInfo()
    if activeWeaponPair == 0 then
        table.insert(pane, { label=G.colors.danger:Colorize("No weapons are equipped."), value=""})
        return
    end
    local mainHandHasPoison, mainHandPoisonCount, _, _ =
        GetItemPairedPoisonInfo(EQUIP_SLOT_MAIN_HAND)
    local backupMainHandHasPoison, backupMainHandPoisonCount, _, _ =
        GetItemPairedPoisonInfo(EQUIP_SLOT_BACKUP_MAIN)
    local mainHandChargePerc = getitemcharge(EQUIP_SLOT_MAIN_HAND)
    local offHandChargePerc = getitemcharge(EQUIP_SLOT_OFF_HAND)
    local backupMainHandChargePerc = getitemcharge(EQUIP_SLOT_BACKUP_MAIN)
    local backupOffHandChargePerc = getitemcharge(EQUIP_SLOT_BACKUP_OFF)
    -- charges
	if not (mainHandHasPoison and backupMainHandHasPoison) then -- there's a non-poisoned weapon
        table.insert(pane, { label=G.colors.header:Colorize("Weapon Charge"), value="" })
		for _, p in ipairs({
			{ mainHandChargePerc, mainHandHasPoison, mainHandPoisonCount, EQUIP_SLOT_MAIN_HAND, },
			{ offHandChargePerc,  mainHandHasPoison, mainHandPoisonCount, EQUIP_SLOT_OFF_HAND},
			{ backupMainHandChargePerc, backupMainHandHasPoison, backupMainHandPoisonCount, EQUIP_SLOT_BACKUP_MAIN, },
			{ backupOffHandChargePerc,  backupMainHandHasPoison, backupMainHandPoisonCount, EQUIP_SLOT_BACKUP_OFF},
		}) do
			local handChargePerc, handHasPoison, handPoisonCount, equipSlot = unpack(p)
			if not handHasPoison then
				local name = GetItemName(BAG_WORN, equipSlot)
				if name ~= "" then
					local wcColor
					if handChargePerc and handChargePerc ~= 10000 then
						wcColor = handChargePerc < 100.0 and G.colors.danger or G.colors.good
						table.insert(pane, { label = wcColor:Colorize(zo_strformat("<<C:1>>", name)), 
							value = wcColor:Colorize(string.format("%s%%", handChargePerc)) })
					end
				end
			end	
		end
		table.insert(pane, { label = "", value = "" })
	end
	-- poisons
    if mainHandHasPoison or backupMainHandHasPoison then
        table.insert(pane, { label = G.colors.header:Colorize("Poison Count"), value = "" })
        for _, p in ipairs({
            { mainHandChargePerc, mainHandHasPoison, mainHandPoisonCount, "Primary Weapon", },
            { backupMainHandChargePerc, backupMainHandHasPoison, backupMainHandPoisonCount, "Secondary Weapon", },
            }) do
            local handChargePerc, handHasPoison, handPoisonCount, equipSlot = unpack(p)
			if handHasPoison then
				local poisonColor = handPoisonCount < 100 and G.colors.danger or G.colors.good
				table.insert(pane, { label = poisonColor:Colorize(equipSlot), value = poisonColor:Colorize(handPoisonCount) })
			end
        end
    end
	table.insert(pane, { label = "", value = "" })
end

local function UpdateListData(control, data)
	local dataList = ZO_ScrollList_GetDataList(control)
	ZO_ScrollList_Clear(control)
	for _, d in ipairs(data) do
		table.insert(dataList, ZO_ScrollList_CreateDataEntry(YANP_LIST_DATA_TYPE, d))
	end
	ZO_ScrollList_Commit(control)
	control:SetHeight(YANP_ROW_HEIGHT * #data)
end

function YANP.SetupItem(control, data)
	control.data = data
	local label = control:GetNamedChild("_Label")
	local value = control:GetNamedChild("_Value")
	label:SetText(data.label)
	value:SetText(data.value)
end

function YANP.Toggle()
	SCENE_MANAGER:ToggleTopLevel(YANP_Top)
	if not YANP_Top:IsHidden() then
		local left, middle, right, cp_craft, cp_warfare, cp_fitness = { }, { }, { }, { }, { }, { }
		YANP_Top_Character:SetText(GetUnitName("player"))
		bagItems(left)
		buffs(middle)
		attributes(middle)
		quickslots(middle)
		role(right)
		equipped(right)
		durability(right)
		wc(right)
		champion({cp_craft, cp_warfare, cp_fitness})
		UpdateListData(YANP_Top_Left, left)
		UpdateListData(YANP_Top_Middle, middle)
		UpdateListData(YANP_Top_Right, right)
		UpdateListData(YANP_Top_CP_Craft, cp_craft)
		UpdateListData(YANP_Top_CP_Warfare, cp_warfare)
		UpdateListData(YANP_Top_CP_Fitness, cp_fitness)
		-- YANP_Top:SetHidden(false)
	else
		-- YANP_Top:SetHidden(true)
	end
end

local function OnPlayerActivated(eventCode)
	if G.addonInitialized then return end
    chat(1, "%s v. %s initialized for %s.",YANP.name, YANP.version, GetUnitName("player"))
	G.addonInitialized = true
end

local function OnAddonLoaded(event, addOnName)
    if addOnName ~= YANP.name then return end
	    -- read in settings from SavedVariables
    local sv_name = "YANP_SavedVariables"
    settings = LSV:NewAccountWide(sv_name, "Account", defaults)
    YANP.settings = settings -- to simplify debugging
    ZO_CreateStringId("SI_BINDING_NAME_TOGGLE", "Toggle YANP Window")
	-- fill G.colors with ZO_ColorDef objects
    FillColors(settings.colors)
    -- add colors for CP constellations
    FillColors({ craft = "51AB0D", warfare = "1970C9", fitness = "D6660C", })
	SLASH_COMMANDS["/yanp"] = YANP.Toggle
	for _, pane in ipairs({ YANP_Top_Left, YANP_Top_Middle, YANP_Top_Right, YANP_Top_CP_Craft, YANP_Top_CP_Warfare, YANP_Top_CP_Fitness }) do
		ZO_ScrollList_AddDataType(pane, YANP_LIST_DATA_TYPE, "YANP_ItemTemplate", YANP_ROW_HEIGHT, function(control, data) YANP.SetupItem(control, data) end)
	end
	SCENE_MANAGER:RegisterTopLevel(YANP_Top, locksUIMode)
	EVENT_MANAGER:RegisterForEvent(YANP.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	EVENT_MANAGER:UnregisterForEvent(YANP.name, EVENT_ADD_ON_LOADED)

end

EVENT_MANAGER:RegisterForEvent(YANP.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
