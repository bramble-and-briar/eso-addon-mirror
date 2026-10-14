--[[
Copyright (c) 2017-now Dolores Scott
All rights reserved.
See LICENSE file for terms.
]]
local SF = LibSFUtils
local color = SF.hex
local TT = ThiefTools

local L = GetString

local ZOS_addSystemMsg = CHAT_SYSTEM.AddMessage

local logDebug = TT.logDebug

-- -----------------------------
-- send debug messages to chat if enabled
local TTmsg = SF.addonChatter:New(TT.name)
local debugmode=false
TTmsg:disableDebug()

local function dbg(...)	
	TT.logDebug(...)
	-- mostly because I hate to type
	TTmsg:debugMsg(...)
end

local AUTO_LOOT_OFF = "0"
local AUTO_LOOT_ON = "1"

local tempHideBar = false
local message_dest = 0		-- set this to 3 to turn off message on screen and in chat

local function slashToggleDebug()
	-- have a local debugmode variable instead of just using TTmsg:toggleDebug()
	-- (the addonChatter keeps track of its own state without outside assistance)
	-- just so that I can print to chat that I am enabling or disabling debug mode.
	if debugmode == false then
		debugmode = true
		TTmsg:enableDebug()
		TTmsg:systemMessage("Enabling debug")
		TT.logDebug("Enabling debug")

	else
		TTmsg:systemMessage("Disabling debug")
		TT.logDebug("Disabling debug")
		debugmode = false
		TTmsg:disableDebug()
	end
end

-- -----------------------------
-- Default Settings

-- default settings for the display and location
local displayTable = {
    offsetx = 0,
    offsety = 0,
    scale = 1,
    border = 10,
    hidden = false,
    locked = false,
    hideMeter = false,
    autoLock = false,
    hide_on_menu = false,
    ann_top = 100,
    ann_left = 100,
}
-- default settings for the status bar
local barTable = {
	Kill = true,
	Loot = true,
    Value = true,
    SellsLeft = true,
    LaundersLeft = true,
    FenceTimer = false,
    BountyTimer = false,
    Bounty = false,
    ClemencyTimer = false,
    Recipes = false,
    Average = false,
    Quality = true,
    Estimate = true,
    Background = true,
    QualityBars = true,
}
local dynamicTable = {
	Kill = true,
	Loot = true,
    Bounty = true,
    BountyTimer = true,
    ClemencyTimer = nil,
}
local filterTable = {
    nojunk = true,
	unjunk = true,
    ignscale = 0,
    autojunkbelow = true,
	never_junk_quality = 5,

    dest_prov_recipe = "Mode_Fence",
    dest_furn_recipe = "Mode_Fence",
    dest_motif      = "Mode_Launder",
    dest_style      = "Mode_Launder",
    dest_trait      = "Mode_Launder",
    dest_gear       = "Mode_Fence",
	dest_jewelry    = "Mode_Ignore",
    dest_furnishing = "Mode_Launder",
    dest_lockpick   = "Mode_Launder",
    dest_soulgem    = "Mode_Launder",
    dest_ingredient = "Mode_Launder",
    dest_ingredient_rare = "Mode_Launder",
    dest_alch_solvent = "Mode_Launder",
    dest_alch_reagent = "Mode_Launder",
    dest_furnmat    = "Mode_Launder",
    dest_mat        = "Mode_Launder",
}
local warnsTable = {
    slotsleft = 5,
    fenceleft = 5,
}

local charTable = {
    not_thief = false,
    autoSteal = false,
	enableJunking = true,
}

-- character-level switches to set if char or AW
-- settings are to be used.
local scopeTable = {
    isFilterAW = true,
    isBarAW = true,
    isDynamicAW = true,
    isWarnAW = true,
    isDisplayAW = true,
}

TT.DefaultAW = {
	filter = filterTable,
	show = barTable,
	dshow = dynamicTable,
	warns = warnsTable,
	display = displayTable,
	-- scope is always character-local
	-- chartt is always character-local
}  -- end of DefaultAW
TT.DefaultC = {
	filter = filterTable,
	show = barTable,
	dshow = dynamicTable,
	warns = warnsTable,
	-- display is always account-wide
	scope = scopeTable,
	chartt = charTable,
} -- end of DefaultC

-- -----------------------------

TT.options = {}

TT.delaying = false
TT.quality = { [0] = 0, 0, 0, 0, 0, 0 }

TT.dshow = { }		-- runtime flags indicating whether each control is currently permitted to be shown.
TT.bounty = GetFullBountyPayoffAmount()
TT.bounty_start = 0
if TT.bounty > 0 then TT.bounty_start = GetTimeStamp() end

TT.last_fence_d = 0

TT.totalValue = 0
TT.totalQual = 0
TT.recipeCount = 0
TT.motifCount = 0
TT.furnitureCount = 0

TT.fenceCount = 0
TT.launderCount = 0

-- ItemHandlers for each ITEMTYPE.
-- Key = ITEMTYPE_* that the entry applies to
-- See ItemTypeHandler:New()
TT.ItemHandlers = {}
-- ItemHandlers for select EQUIP_TYPEs.
-- Key = EQUIP_TYPE_* that the entry applies to
TT.EquipHandlers = {}

TT.itemChoices = {
	L(TT_CHOICES_FENCE),   -- "Fence",
	L(TT_CHOICES_LAUNDER), -- "Launder",
	L(TT_CHOICES_IGNORE),  -- "Ignore"
	L(TT_CHOICES_JUNK),  -- "Junk"
}
TT.qualityChoices = {
	SF.ColorText(TT_QUAL_LEGENDARY,color.legendary),   -- "Legendary",
	SF.ColorText(TT_QUAL_EPIC,color.epic), -- "Epic",
	SF.ColorText(TT_QUAL_SUPERIOR,color.superior),  -- "Superior",
}
-- Define translation array
TT.ModeArray = {
	["Mode_Fence"] = L(TT_CHOICES_FENCE),
	["Mode_Launder"] = L(TT_CHOICES_LAUNDER),
	["Mode_Ignore"] = L(TT_CHOICES_IGNORE),
	["Mode_Junk"] = L(TT_CHOICES_JUNK),
	[L(TT_CHOICES_FENCE)] = "Mode_Fence",
	[L(TT_CHOICES_LAUNDER)] = "Mode_Launder",
	[L(TT_CHOICES_IGNORE)] = "Mode_Ignore",
	[L(TT_CHOICES_JUNK)] = "Mode_Junk",
}
TT.QualityModeArray = {
	[5] = SF.ColorText(TT_QUAL_LEGENDARY,color.legendary),	-- Legendary
	[4] = SF.ColorText(TT_QUAL_EPIC,color.epic),	-- Epic
	[3] = SF.ColorText(TT_QUAL_SUPERIOR,color.superior),	-- Superior
	[SF.ColorText(TT_QUAL_LEGENDARY,color.legendary)] = 5,
	[SF.ColorText(TT_QUAL_EPIC,color.epic)] = 4,
	[SF.ColorText(TT_QUAL_SUPERIOR,color.superior)] = 3,
	[L(TT_QUAL_LEGENDARY)] = 5,
	[L(TT_QUAL_EPIC)] = 4,
	[L(TT_QUAL_SUPERIOR)] = 3,
}
TT.tempDisableJunking = false
TT.realDisplayValue = false
-- end of ThiefTools options

local WM = WINDOW_MANAGER
local HotItem = ThiefTools_HotItem
local HotList = ThiefTools_HotList
TT.hotSheet = HotList:New(BAG_BACKPACK)

local evtmgr = SF.EvtMgr:New("ThiefTools")

--[[
------------------------------------------------------------------------
	item handler functions that can be assigned to itemtypes
--]]
local function ignoreIt(hotItem)
	logDebug("Ignoring ",hotItem.name," IT=",hotItem.itemType,"  SIT=",hotItem.specializedItemType,"  ET=",hotItem.equipType)
	-- do nothing with it
end

local function fenceIt(hotItem)
	logDebug("Fencing ",hotItem.name," IT=",hotItem.itemType,"  SIT=",hotItem.specializedItemType,"  ET=",hotItem.equipType)

	local stackCount = hotItem.stackCount
	local quality = hotItem.quality
	local sellPrice = hotItem.stackSellPrice

	TT.fenceCount = math.max(0, TT.fenceCount + stackCount)
	TT.totalQual  = math.max(0, TT.totalQual + (quality * stackCount))
    if stackCount < 0 then
        TT.totalValue = TT.totalValue - sellPrice
    else
        TT.totalValue = TT.totalValue + sellPrice
    end
	if TT.totalValue < 0 then TT.totalValue = 0 end
	TT.quality[quality] = math.max(0,
		SF.nilDefault(TT.quality[quality], 0) + stackCount)
end

--[[
    Increment the launder-able items counters given the stack size.
    Unlike fencing, we don't care about the value or quality of laundered items.

    To decrement, pass in a negative stackCount.
]]
local function launderIt(hotItem)
	logDebug("Laundering ",hotItem.name," IT=",hotItem.itemType,"  SIT=",hotItem.specializedItemType,"  ET=",hotItem.equipType)
	local stackCount = hotItem.stackCount 
	TT.launderCount = math.max(0, TT.launderCount + stackCount)
end

-- stash it in junk (or not)
local function junkIt(hotItem, isJunk)
	logDebug("Junking",hotItem.name,"IT=",hotItem.itemType,"  SIT=",hotItem.specializedItemType,"  ET=",hotItem.equipType)
    isJunk = SF.nilDefault(isJunk, true)
    if TT.options.chartt.enableJunking == false or TT.tempDisableJunking == true  then
        return
    end
    if CanItemBeMarkedAsJunk(hotItem.bagId, hotItem.slotIndex) == false then
        return
    end
    if isJunk == true then
		local quality = hotItem.quality or nil
		local neverJunkQuality =		-- never auto-junk legendary items!
			tonumber(TT.options.filter.never_junk_quality) or 5
		if quality == nil then
			return
		end
		if quality >= neverJunkQuality then
			return
		end

		SetItemIsJunk(hotItem.bagId, hotItem.slotIndex, isJunk)
		hotItem.isJunk = true

	else
		-- unjunking
		if hotItem.isJunk == false  then return end
        SetItemIsJunk(hotItem.bagId, hotItem.slotIndex, false)
		hotItem.isJunk = false
    end
end

--[[
    Increment the fence-able items counters, quality bars, and values
    given the stack size, the adjusted value of a single item,
    and the quality of the item.
]]
local function incrFence( hotItem )
    logDebug(hotItem.name, ": incrFence    ", hotItem.sellPrice)
    -- only increment if the value is greater than the threshold setting
    --local index = hotItem.slotIndex
    if hotItem.sellPrice >= TT.options.filter.ignscale then
        fenceIt(hotItem)

    elseif TT.options.filter.autojunkbelow == true then
        junkIt(hotItem)
    end
end

-- special handler for ITEMTYPE_FOOD so that we can distinguish (and junk)
-- spoiled food from regular food.
local function foodHandler( hotItem )
	logDebug(hotItem.name, ": foodHandler")
	if hotItem.sellPrice == 0 then
		junkIt(hotItem)
	end
  incrFence(hotItem)
end

--[[
	end of item handler functions
------------------------------------------------------------------------
--]]

-- Setup for the ItemTypeHandler prototype
local ItemTypeHandler = ThiefTools_ItemTypeHandler
ItemTypeHandler.namelist = {
	[incrFence] = "incrFence",
	[fenceIt] = "fenceIt",
	[launderIt] = "launderIt",
	[ignoreIt] = "ignoreIt",
	[junkIt] = "junkIt",
	[foodHandler] = "foodHandler",
}
ItemTypeHandler.defaultHandler = incrFence

------------------------------------------------------------------------

function TT.setOptionsScope()
    TT.options = {}
    -- scope is always per-char
    TT.options.scope = TT.savedC.scope
	SF.defaultMissing(TT.options.scope, scopeTable)
	local scope = TT.options.scope

    -- chartt is always per-char
    TT.options.chartt = TT.savedC.chartt
	SF.defaultMissing(TT.options.chartt,charTable)

     -- display is always AW
    TT.options.display = TT.savedAW.display
	SF.defaultMissing(TT.options.display,displayTable)

    if scope.isFilterAW then
        TT.options.filter = TT.savedAW.filter

    else
        TT.options.filter = TT.savedC.filter
    end
	SF.defaultMissing(TT.options.filter,filterTable)

	-- TT.options.dshow — configuration indicating whether each control has a dynamic visibility settings condition.
    if scope.isBarAW then
        TT.options.show = TT.savedAW.show
        TT.options.dshow = TT.savedAW.dshow

    else
        TT.options.show = TT.savedC.show
        TT.options.dshow = TT.savedC.dshow
    end
	SF.defaultMissing(TT.options.show,barTable)
	SF.defaultMissing(TT.options.dshow,dynamicTable)

    if scope.isWarnAW  then
        TT.options.warns = TT.savedAW.warns

    else
        TT.options.warns = TT.savedC.warns
    end
	SF.defaultMissing(TT.options.warns,warnsTable)

end

--[[ h5. StealthState (hiddenStates)
		* STEALTH_STATE_HIDDEN = true
		* STEALTH_STATE_STEALTH = true
		* STEALTH_STATE_HIDDEN_ALMOST_DETECTED = true
		* STEALTH_STATE_STEALTH_ALMOST_DETECTED = true
		* STEALTH_STATE_DETECTED = false
		* STEALTH_STATE_NONE = false
		* STEALTH_STATE_HIDING
--]]
-- handler for EVENT_STEALTH_STATE_CHANGED
local function onStealthChanged(iEventCode, sUnitTag, iStealthState)
	if sUnitTag ~= "player" then return end

    local tmsg = SF.GetIconized(L(TT_ANNOUNCE_BE_CAREFUL), color.bronze)
    if iStealthState == STEALTH_STATE_HIDDEN_ALMOST_DETECTED
            or iStealthState == STEALTH_STATE_STEALTH_ALMOST_DETECTED  then
        TT:ShowMessage(tmsg, message_dest)
    end
	if TT.options.chartt == nil  then return end
	if TT.options.chartt.autoSteal ~= true  then return end

    local isAutoLootEnabled = GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN)
	if iStealthState == STEALTH_STATE_NONE or iStealthState == STEALTH_STATE_DETECTED  then
		-- not sneaking (or we've been seen!)
		if isAutoLootEnabled == AUTO_LOOT_ON then
			-- we're not sneaking so disable auto-steal
			SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN, AUTO_LOOT_OFF)
		end

	else
		-- we are sneaking so enable auto-steal
		if isAutoLootEnabled == AUTO_LOOT_OFF then 
			SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN, AUTO_LOOT_ON)
		end
	end
end

-- set the primary, secondary, and alternate handlers for the list of ITEMTYPEs in types
-- specializedHandlerMap is a table of handlers keyed with the SPECIALIZED_ITEMTYPEs
-- if some SPECIALIZED_ITEMTYPEs are not specified it will use the primary instead
local function set_item_handlers(types, primaryfunc, secondaryfunc, specializedHandlerMap)
	if types == nil then return end

	-- make sure we have values
	local specializedHandler = specializedHandlerMap or {}

	-- for each of the ITEMTYPEs passed in, set up the handler set
	for _,v in pairs(types) do
		local handler = TT.ItemHandlers[v]
		if handler == nil then
			handler = ItemTypeHandler:New(v)
			TT.ItemHandlers[v] = handler
		end
		handler:setPrimary(primaryfunc)
		handler:setSecondary(secondaryfunc)

		for skey,shdlr in pairs(specializedHandler) do
			-- because we don't have handler name strings available here
			-- to pass in, we have to have already set them up in
			-- ItemTypeHandler.namelist.
			handler:setAlternate(skey, shdlr)
		end
	end
end

-- set the primary handlers for the list of EQUIP_TYPEs in types
local function set_equip_handlers(types, primaryfunc)
	if types == nil then return end

	-- for each of the EQUIP_TYPEs passed in, set up the handler set
	for _,v in pairs(types) do
		TT.EquipHandlers[v] = TT.EquipHandlers[v] or ItemTypeHandler:New(v)
		TT.EquipHandlers[v].primary = primaryfunc
	end
end

--[[ Pick the appropriate handler for an itemtype based on the
    option passed in (one of "Fence", "Launder", "Junk", or "Ignore").
    Return the chosen handler function.
]]
local function pick_handler(opt)
    if opt == "Mode_Fence" then
        return incrFence

	elseif opt == "Mode_Launder" then
        return launderIt

    elseif opt == "Mode_Junk" then
        return junkIt

    else
        return ignoreIt  -- ignore
    end
end

--[[ Set the handlers for all of the itemtypes that we allow separate settings
    for on the option page. Pass in the table of filter settings. Add entries
    into our ItemHandler table for each of the itemtypes we care about.
    Setting a handler function to nil means ignore that itemtype (alternatively
	you can set the handler function to ignoreIt).
]]
function TT.set_recipe_handler(filters)
	filters = filters or TT.options.filter
	local types = {ITEMTYPE_RECIPE}
	local furnprime = pick_handler(filters.dest_furn_recipe)	-- this will be the default
	--[[
	-- furnishing recipe subtypes
		SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING,
		SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING,
	--]]

	local provfunc = pick_handler(filters.dest_prov_recipe)

	-- provisioning recipe subtypes
	local consumable_subtypes = {
		[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK]=provfunc,
		[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD]=provfunc,
	}

	-- count all recipes
	local secondfunc  = function(stackCount)
			TT.recipeCount = math.max(0,TT.recipeCount + stackCount)
		end
	set_item_handlers(types, furnprime, secondfunc, consumable_subtypes )
end

function TT.set_motif_handler(filters)
	local types = {ITEMTYPE_RACIAL_STYLE_MOTIF}
	local primefunc = pick_handler(filters.dest_motif)

	-- count motifs
	local secondfunc  = function(stackCount)
			TT.motifCount = math.max(0,TT.motifCount + stackCount)
		end
	set_item_handlers(types, primefunc, secondfunc)
end

function TT.set_alch_reagent_handler(filters)
	local types = {ITEMTYPE_REAGENT}
	local primefunc = pick_handler(filters.dest_alch_reagent)
	set_item_handlers(types, primefunc)
end

function TT.set_alch_solvent_handler(filters)
	local types = {ITEMTYPE_POTION_BASE, ITEMTYPE_POISON_BASE}
	local primefunc = pick_handler(filters.dest_alch_solvent)
	set_item_handlers(types, primefunc)
end

function TT.set_furnishing_handler(filters)
	local types = {ITEMTYPE_FURNISHING}
	local primefunc = pick_handler(filters.dest_furnishing)
    local secondfunc = function(stackCount)
            TT.furnitureCount = math.max(0,TT.furnitureCount + stackCount)
        end
	set_item_handlers(types, primefunc, secondfunc)
end

function TT.set_ingredient_handler(filters)
	local primefunc = pick_handler(filters.dest_ingredient)
	local tertiaryfunc = pick_handler(filters.dest_ingredient_rare)
	set_item_handlers({ITEMTYPE_INGREDIENT}, primefunc, nil, {
		[SPECIALIZED_ITEMTYPE_INGREDIENT_RARE]=tertiaryfunc,
		[SPECIALIZED_ITEMTYPE_INGREDIENT_FOOD_ADDITIVE]=tertiaryfunc,
		})
	local types = {ITEMTYPE_FLAVORING, ITEMTYPE_SPICE}
	set_item_handlers(types, primefunc)
end

function TT.set_furnishing_material_handler(filters)
	local types = {ITEMTYPE_FURNISHING_MATERIAL, ITEMTYPE_ADDITIVE}
	local primefunc = pick_handler(filters.dest_furnmat)
	set_item_handlers(types, primefunc)
end

-- don't really expect this one so it does not have an option setting right now
function TT.set_material_handler(filters)
	local types = {ITEMTYPE_RAW_MATERIAL,
			ITEMTYPE_WOODWORKING_MATERIAL, ITEMTYPE_WOODWORKING_RAW_MATERIAL,
			ITEMTYPE_CLOTHIER_MATERIAL, ITEMTYPE_CLOTHIER_RAW_MATERIAL,
			ITEMTYPE_BLACKSMITHING_MATERIAL, ITEMTYPE_BLACKSMITHING_RAW_MATERIAL}
	local primefunc = pick_handler(filters.dest_mat)
	set_item_handlers(types, primefunc)
end

function TT.set_gear_handler(filters)
	local types = {ITEMTYPE_ARMOR, ITEMTYPE_WEAPON}
	local primefunc = pick_handler(filters.dest_gear)
	set_item_handlers(types, primefunc)
end

function TT.set_jewelry_handler(filters)
	local types = {EQUIP_TYPE_RING, EQUIP_TYPE_NECK}
	local primefunc = pick_handler(filters.dest_jewelry)
	set_equip_handlers(types, primefunc)
end


function TT.set_trait_handler(filters)
    -- handle trait materials
	local types = {ITEMTYPE_ARMOR_TRAIT, ITEMTYPE_WEAPON_TRAIT}
	local primefunc = pick_handler(filters.dest_trait)
	set_item_handlers(types, primefunc)
end

function TT.set_style_handler(filters)
    -- handle style materials
	local types = {ITEMTYPE_STYLE_MATERIAL}
	local primefunc = pick_handler(filters.dest_style)
	set_item_handlers(types, primefunc)
end

function TT.set_lockpick_handler(filters)
    -- handle lockpicks
	local types = {ITEMTYPE_LOCKPICK, ITEMTYPE_TOOL}
	local primefunc = pick_handler(filters.dest_lockpick)
	set_item_handlers(types, primefunc)
end

function TT.set_soulgem_handler(filters)
    -- handle soulgems
	local types = {ITEMTYPE_SOUL_GEM}
	local primefunc = pick_handler(filters.dest_soulgem)
	set_item_handlers(types, primefunc)
end

function TT.set_handlers(filters)
    -- handle gear types
    TT.set_gear_handler(filters)

    -- handle jewelry types
    TT.set_jewelry_handler(filters)

    -- handle trait materials
    TT.set_trait_handler(filters)

    -- handle recipes, blueprints, designs, praxis, etc
    TT.set_recipe_handler(filters)

    -- handle motifs
    TT.set_motif_handler(filters)

    -- handle style materials
    TT.set_style_handler(filters)

    -- handle furnishings
    TT.set_furnishing_handler(filters)

    -- handle lockpicks
    TT.set_lockpick_handler(filters)
    TT.set_soulgem_handler(filters)

    -- handle ingredients
    TT.set_ingredient_handler(filters)
	TT.set_furnishing_material_handler(filters)
	TT.set_material_handler(filters)
	TT.set_alch_solvent_handler(filters)
	TT.set_alch_reagent_handler(filters)

	-- handle food
	set_item_handlers({ITEMTYPE_FOOD},foodHandler)

    -- ignore treasure maps (and other trophies)
	set_item_handlers({ITEMTYPE_TROPHY}, ignoreIt)

    -- automatically junk stuff
	set_item_handlers({ITEMTYPE_DEPRECATED}, junkIt)

	-- always ignore containers
	set_item_handlers({ITEMTYPE_CONTAINER}, ignoreIt)
end

local function fmt_time(t)
    t = math.max(0, math.floor(t))

    if t >= 86400 then
        local dd = math.floor(t / 86400)
        local hh = math.floor((t % 86400) / 3600)
        return string.format("%02dd%02dh", dd, hh)

    elseif t >= 3600 then
        local hh = math.floor(t / 3600)
        local mm = math.floor((t % 3600) / 60)
        return string.format("%02d:%02d", hh, mm)

    else
        local mm = math.floor(t / 60)
        local ss = t % 60
        return string.format("%02d:%02d", mm, ss)
    end
end

--[[ Zero all of our counters
--]]
local function zeroStats()
   TT.recipeCount = 0
   TT.motifCount = 0
   TT.furnitureCount = 0

   TT.fenceCount = 0
   TT.launderCount = 0

   TT.totalValue = 0
   TT.totalQual = 0

   for i = 0,5 do
      TT.quality[i] = 0
   end
end

--[[ Add the contents of a slot to our counts
	(Relies on ScanStolenGoods having created a hotSheet)
--]]
local function incrGoodsFromSlot(bagId, index)

	local hotItem = TT.hotSheet:getItem(index)
	if not hotItem then return end
    if TT.options.filter.nojunk == true and hotItem.isJunk == true then return end

	--hotItem:Display()
	local stackCount = hotItem.stackCount

	if hotItem.equipType ~= nil and hotItem.equipType ~= 0  then
		logDebug("Found non-nil EQUIP_TYPE ", hotItem.equipType)
		local ehandlerSet = TT.EquipHandlers[hotItem.equipType]
		if ehandlerSet ~= nil then
			logDebug("Found EQUIP_TYPE item handler for ", hotItem.name)
			logDebug(ItemTypeHandler.namelist[ehandlerSet:getEffectivePrimary()])
			ehandlerSet:effectiveEquip(hotItem)
			return
		end
	end

	local handlerSet = TT.ItemHandlers[hotItem.itemType]
	if handlerSet then
		logDebug("Found ITEMTYPE item handler")
		logDebug(handlerSet:getHandlerName(handlerSet:getEffectivePrimary()))
		handlerSet:effectivePrimary(hotItem)
        if handlerSet.special then
            handlerSet.special(stackCount)
        end
    else
		logDebug("No handler found - fence it")
        -- anything without a handler is counted as fence-able
        incrFence(hotItem)
    end
end

-- Create a list of all stolen items we have in our pack
function TT:ScanStolenGoods()
    local bagId = BAG_BACKPACK
    local bagSlots = GetBagSize(bagId)
	local hotSheet = TT.hotSheet

    hotSheet:empty()
	logDebug("bagSlots = ", bagSlots)
    for index = 1, bagSlots do
		local isHot = IsItemStolen(bagId, index)
		if isHot == true then
			logDebug("HotItem - ", bagId, "  ", index)
			local slot = HotItem:New(bagId, index)
			hotSheet:addItem(slot)
		end
    end
end

function TT:CalcStolenGoods()
	if TT.delaying == true then return; end

	zeroStats()
	TT:ScanStolenGoods()
    local bagId = BAG_BACKPACK
    for k,v in pairs(TT.hotSheet.itemList) do
        if v.stolen == true then -- should always be true
            incrGoodsFromSlot(bagId, k)
        end
    end
end

local delayedCalcUpdateName = TT.name .. "DelayedCalc"

function TT:DelayedCalcStolenGoods(dur)
    if TT.delaying == true then return end
    TT.delaying = true
    dur = dur or 250
    evtmgr:registerUpdateEvt(delayedCalcUpdateName, dur,
      function()
        evtmgr:unregUpdateEvt(delayedCalcUpdateName)
		TT.delaying = false
        TT:CalcStolenGoods()
        TT:checkFenceSlotsWarning(INVENTORY_BACKPACK)
        TT:UpdateControls()		-- because of delay, control visibility might change
        TT:UpdateDisplay()
   end)
end

function TT:lockWindow()
    if TT.options.display.locked == true then
        TT.window:SetMovable(false)
    else
        TT.window:SetMovable(true)
    end
end

function TT:hideMeter()
    if TT.options.display.hideMeter == true then
        ZO_HUDInfamyMeter:SetHidden(true)
    else
        ZO_HUDInfamyMeter:SetHidden(false)
    end
end

--[[
local TT_D = { -- Dungeons ----------------------------------------------------------
		[ 144] = 1, -- Spindleclutch I
		[ 936] = 1, -- Spindleclutch II
		[ 380] = 1, -- The Banished Cells I
		[ 935] = 1, -- The Banished Cells II
		[ 283] = 1, -- Fungal Grotto I
		[ 934] = 1, -- Fungal Grotto II
		[ 146] = 1, -- Wayrest Sewers I
		[ 933] = 1, -- Wayrest Sewers II
		[ 126] = 1, -- Elden Hollow I
		[ 931] = 1, -- Elden Hollow II
		[  63] = 1, -- Darkshade Caverns I
		[ 930] = 1, -- Darkshade Caverns II
		[ 130] = 1, -- Crypt of Hearts I
		[ 932] = 1, -- Crypt of Hearts II
		[ 176] = 1, -- City of Ash I
		[ 681] = 1, -- City of Ash II (Inner Grove)
		[ 148] = 1, -- Arx Corinium
		[  22] = 1, -- Volenfell
		[ 131] = 1, -- Tempest Island
		[ 449] = 1, -- Direfrost Keep
		[  38] = 1, -- Blackheart Haven
		[  31] = 1, -- Selene's Web
		[  64] = 1, -- Blessed Crucible
		[  11] = 1, -- Vaults of Madness
		[ 678] = 1, -- Imperial City Prison (Bastion)
		[ 688] = 1, -- White-Gold Tower (Green Emperor Way)
		[ 843] = 1, -- Ruins of Mazzatun
		[ 848] = 1, -- Cradle of Shadows
		[ 973] = 1, -- Bloodroot Forge
		[ 974] = 1, -- Falkreath Hold
		[1009] = 1, -- Fang Lair
		[1010] = 1, -- Scalecaller Peak
		[1052] = 1, -- Moon Hunter Keep
		[1055] = 1, -- March of Sacrifices (Bloodscent Pass)
		[1080] = 1, -- Frostvault
		[1081] = 1, -- Depths of Malatar
		[1122] = 1, -- Moongrave Fane
		[1123] = 1, -- Lair of Maarselok
		[1152] = 1, -- Icereach
		[1153] = 1, -- Unhallowed Grave
		[1197] = 1, -- Stone Garden
		[1201] = 1, -- Castle Thorn
		[1228] = 1, -- Black Drake Villa
		[1229] = 1, -- The Cauldron
		[1267] = 1, -- Red Petal Bastion
		[1268] = 1, -- The Dread Cellar
		[1301] = 1, -- Coral Aerie
		[1302] = 1, -- Shipwright's Regret
		[1360] = 1, -- Earthen Root Enclave
		[1361] = 1, -- Graven Deep
		[1389] = 1, -- Bal Sunnar
		[1390] = 1, -- Scrivener's Hall
		[1470] = 1, -- Oathsworn Pit
		[1471] = 1, -- Bedlam Veil

	}

local TT_T = { -- Trials ------------------------------------------------------------
		[ 636] = 1, -- Hel Ra Citadel
		[ 638] = 1, -- Aetherian Archive
		[ 639] = 1, -- Sanctum Ophidia
		[ 725] = 1, -- Maw of Lorkhaj
		[ 975] = 1, -- Halls of Fabrication
		[1000] = 1, -- Asylum Sanctorium
		[1051] = 1, -- Cloudrest
		[1121] = 1, -- Sunspire
		[1196] = 1, -- Kyne's Aegis
		[1263] = 1, -- Rockgrove
		[1344] = 1, -- Dreadsail Reef
		[1427] = 1, -- Sanity's Edge
	}
--]]
local TT_A = { -- Arenas ------------------------------------------------------------
		[ 635] = 1, -- Dragonstar Arena
		[ 677] = 1, -- Maelstrom Arena
		[1082] = 1, -- Blackrose Prison
		[1227] = 1, -- Vateshran Hollows
		[1436] = 1, -- Infinite Archive
	}

local zoneType = { DELVE = 1, PUBLICDUNGEON=2, GROUPDUNGEON=3, TRIAL=4, IA =5, ARENA=6, UNKNOWN=7}
local function getCurrentZoneType()

	local currentZoneId = GetZoneId(GetCurrentMapZoneIndex())
    if IsInstanceEndlessDungeon() then  return zoneType.IA end

    if TT_A[currentZoneId] then return zoneType.ARENA end


    if IsPlayerInRaid() or IsPlayerInRaidStagingArea() then return zoneType.TRIAL end


    local isInDungeon = (IsUnitInDungeon("player") or GetMapContentType() == MAP_CONTENT_DUNGEON) or false

    --Check if user is in any dungeon
	if isInDungeon then
        --Difficulty will be 0 if not in a dungeon, 1 if in a delve, 2 if elsewhere
        -- if Difficulty is anything other than zero; it's a Group Dungeon
		if ZO_WorldMap_GetMapDungeonDifficulty() > DUNGEON_DIFFICULTY_NONE then
			return zoneType.GROUPDUNGEON
		else
		    -- if Difficulty is zero; it's either a Delve or a Public Dungeon
            --local poiIndex = pin:GetPOIIndex()
            --local poiType = GetPOIType(zoneIndex, poiIndex)
           -- local instanceType = GetPOIInstanceType(zoneIndex, poiIndex)
            --if instanceType == INSTANCE_TYPE_PUBLIC_DUNGEON then
            --    return zoneType.PUBLICDUNGEON
            --end

            -- right now we return delve for public dungeons too
            return zoneType.DELVE
        
		end
	end

    return zoneType.UNKNOWN
end

local function isNotJusticeArea()
	local shouldhide = false
	local zoneName = GetZoneNameByIndex(GetCurrentMapZoneIndex())
	local currentZoneId = GetZoneId(GetCurrentMapZoneIndex())
    local tw = SCENE_MANAGER:GetCurrentScene():GetName()
    local currentZoneType = getCurrentZoneType()
	local display = TT.options.display
	if IsPlayerInAvAWorld() or IsActiveWorldBattleground() then
		shouldhide = true

	elseif currentZoneType == zoneType.IA and display.hide_on_IA then
		shouldhide = true

	elseif currentZoneType == zoneType.GROUPDUNGEON and display.hide_on_Dung then
		shouldhide = true

	elseif currentZoneType == zoneType.TRIAL and display.hide_on_Trial then
		shouldhide = true

	elseif currentZoneType == zoneType.ARENA and display.hide_on_Arena then
		shouldhide = true

	elseif currentZoneType == zoneType.DELVE and display.hide_on_PublicDungeon then
		shouldhide = true
	end
	return shouldhide
end

--[[ Determines whether the ThiefTools belt should be displayed.

Returns:
    true  if the belt should be visible
    false if the belt should be hidden
--]]
function TT:ShouldDisplayBelt()
    local options = TT.options
    local display = options.display

    if isNotJusticeArea() then return false end

    local tw = SCENE_MANAGER:GetCurrentScene():GetName()
    if tw ~= "hudui" and tw ~= "hud" and display.hide_on_menu == true then
        return false
    end

    if options.chartt.not_thief == true then return false end
    if tempHideBar == true then return false end
    if display.hidden == true then return false end

    return true
end

-- used by bindings.xml
function TT:toggle()
   local sbar = TT.window

   if sbar:IsHidden() == true then
      TT:CalcStolenGoods()
      TT:UpdateDisplay()
   end

   local display = TT.options.display
   display.hidden = not sbar:IsHidden()
   sbar:SetHidden(display.hidden)
end

-- used by bindings.xml
function TT:lockWindow1()
	local display = TT.options.display
    if display.locked == true then
        TT.window:SetMovable(true)
        display.locked = false
        TTmsg:systemMessage(L(TT_MSG_UNLOCKED))
        TT.SavePosition()

    else
        TT.window:SetMovable(false)
        display.locked = true
        TTmsg:systemMessage(L(TT_MSG_LOCKED))
        TT.SavePosition()
    end
end

function TT:checkFreeSlotsWarning(bagId)
    if TT.options.warns.slotsleft > 0 then
        local slotsleft = GetNumBagFreeSlots(bagId)
        local fmsg = SF.str(L(TT_FREE_SLOTS_LEFT)," ",slotsleft)
        if slotsleft == 0 then
            TT.ShowMessage(SF.GetIconized(fmsg, color.red), message_dest)

        elseif slotsleft <= TT.options.warns.slotsleft then
                TT.ShowMessage(fmsg, message_dest)
        end
    end
end

local lastfencelevel = -1
function TT:checkFenceSlotsWarning(bagId)
	local warns = TT.options.warns
    if warns.fenceleft and (warns.fenceleft > 0) then
        local sellsLeft = FENCE_MANAGER.totalSells - FENCE_MANAGER.sellsUsed - TT.fenceCount
        local floored = math.max(0,sellsLeft)
        if floored == lastfencelevel then return end
        if floored == 0 then
            TT.ShowMessage("|c"..color.red.." "..L(TT_FENCE_SLOTS_LEFT).." "..floored.."|r", message_dest)

        elseif sellsLeft <= warns.fenceleft then
            TT.ShowMessage(L(TT_FENCE_SLOTS_LEFT).." "..sellsLeft, message_dest)
        end
        lastfencelevel = floored
    end
end


-- Announce the given Message to: 0=both, 1=Chat, 2=Box, 3=No messages ever)
-- (0 depends on what is set in settings)
function TT.ShowMessage(sText, ChatOrBox)
	if ChatOrBox == 3 or  message_dest == 3 or sText == nil or sText == "" then return end

    if type(sText) == 'number' then
        sText = L(sText)
    end
    if type(sText) ~= 'string' then return end

	-- info goes to MessageBox, to chat or both
	if ChatOrBox == 0  or ChatOrBox == 2 then
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, sText)
	end
	if ChatOrBox == nil or ChatOrBox == 0  or ChatOrBox == 1 then
		TTmsg:systemMessage(sText)
	end
end


-- [[ Event handlers ]]
-- handler for EVENT_ACTION_LAYER_PUSHED and EVENT_ACTION_LAYER_POPPED
local function onLayerChange(evc, index, active)
	local display = TT.options.display
    if display.hide_on_menu == false then return end

	TT.window:SetHidden(not TT:ShouldDisplayBelt())
end

local lastLaundered = {}
local function onSlotUpdate(evCode, bagId, slotIndex, isNewItem, 
	itemSoundCategory, updateReason,  stackCountChange)

    if updateReason ~= INVENTORY_UPDATE_REASON_DEFAULT then return end
    if IsUnderArrest() then return end

	local itm = HotItem:New(bagId,slotIndex)
	itm.isJunk = IsItemJunk(bagId, slotIndex)
    if isNewItem and itm.stolen then
        TT.hotSheet:addItem(itm)
    end
	lastLaundered = {}
	if isNewItem == false and itm.isJunk and stackCountChange >= 0 and itm.stolen == false then
		lastLaundered.bagId = bagId
		lastLaundered.slotIndex = slotIndex
	end

    if TT.delaying == true  then
		return
	end

    if isNewItem == true  then
		TT:checkFreeSlotsWarning(bagId)
    end

   -- All right, we've got some bag management going on, so don't
   -- update every time.
   TT:DelayedCalcStolenGoods(250)
end

-- handler for EVENT_LOOT_RECEIVED
local function onLoot(evc, receiver, name, count, isc, itemtype, isself, ispicked)
	logDebug("name=", name, " count=", count,
				" itype=", itemtype, " isself=", SF.bool2str(isself),
				" ispicked=", SF.bool2str(ispicked))
    if not isself  then return end

    -- No way to tell if the item was stolen!  IsItemLinkStolen()
    -- doesn't return true.  Doing this in onSlotUpdate() means we
    -- can't tell if it's being added to a stack, or splitting a stack.
    TT:DelayedCalcStolenGoods(250)
end

-- handler for EVENT_ITEM_LAUNDER_RESULT
local function onLaunder(evc, res)
    if res ~= ITEM_LAUNDER_RESULT_SUCCESS then return end

	if TT.options.filter.unjunk and not ZO_IsTableEmpty(lastLaundered)  then
		logDebug("moving out of junk - bag ", lastLaundered.bagId,
			" slot ", lastLaundered.slotIndex)
		SetItemIsJunk(lastLaundered.bagId, lastLaundered.slotIndex, false)
		lastLaundered={}
	end

    TT:DelayedCalcStolenGoods(500)
end

-- handler for EVENT_OPEN_FENCE and EVENT_CLOSE_STORE
local function onFence(status)
    if status then
        TT.isFencing = true

	elseif TT.isFencing == true then
        TT.isFencing = false
        TT:UpdateDisplay()
		TT:UpdateControls()
    end
end

-- handler for EVENT_JUSTICE_STOLEN_ITEMS_REMOVED
local function onApprehended(evc)
	zeroStats()
	TT.hotSheet:empty()
	lastLaundered = {}
	TT:UpdateDisplay()
	TT:UpdateControls()
end

-- handler for EVENT_SELL_RECEIPT
local function onSold(evc, itemlink, count, money)
    if not TT.isFencing then return end
    if TT.isFencing == false then return end

    -- There's no way to tell if the itemlink is junk,
    -- so we can't tell whether to (un)track it or not
    -- Just wait and then rescan the backpack.
    TT:DelayedCalcStolenGoods()
end

-- Stolen item is removed from inventory
local function onRemoved(bagId, slotIndex, slot)
    if slot.stolen == false then return end

	if lastLaundered.slotIndex == slotIndex then
		lastLaundered = {}
	end
	local item = TT.hotSheet:getItem(slotIndex)
	if not item then return end

	item.stackCount = -1 * item.stackCount
    incrGoodsFromSlot(bagId, slotIndex)
	TT.hotSheet:removeItem(slotIndex)

    TT:UpdateDisplay()
	TT:UpdateControls()
end

--[[ bounty calculation and updating
--]]
local function resetBountyWatch()
    TT.bounty = GetFullBountyPayoffAmount()

    if TT.bounty == 0 then
        TT.bounty_start = 0
        TT.window.l_bountytimer:SetText("00:00")
    else
        TT.bounty_start = GetTimeStamp()
    end
end

local function bountyCheck(now, drift)
    if TT.bounty_start == 0 then return end

    local bounty = GetFullBountyPayoffAmount()
	local sec = GetSecondsUntilBountyDecaysToZero()
    if sec < 0 then
      TT.window.l_bountytimer:SetText("00:00")
    else
      TT.window.l_bountytimer:SetText(SF.secondsToClock(sec))
    end
	TT:UpdateDisplay()
	TT:DynamicBountyCheck()
    if TT.options.display.hideMeter == true then
        ZO_HUDInfamyMeter:SetHidden(true)
    else
        ZO_HUDInfamyMeter:SetHidden(false)
    end
end

function TT:DynamicBountyCheck()
	local dshow = TT.dshow
	dshow.Bounty = false
	dshow.BountyTimer = false

	local value = GetBounty()
	if value ~= 0 then
		dshow.Bounty = true
		dshow.BountyTimer = true
	end

	TT:UpdateDisplay()
	TT:UpdateControls()
end

local function onBountyChange(evc, old, new)
   resetBountyWatch()
   if ((new == 0) or ( new ~= old )) then
      TT:DynamicBountyCheck()
   end
end

local function fenceCheck(now, drift)
    local reset, d = TT:TimeToFenceReset(now)
    TT.window.l_fencetimer:SetText(reset)
    TT.last_fence_d = d
end

local function clemencyCheck(now, drift)
    --if TT.clemency_start == 0 then return end

    local sec = GetTimeToClemencyResetInSeconds()
    if sec <= 0 then
      TT.window.l_clemencytimer:SetText("00:00")
    else
      TT.window.l_clemencytimer:SetText(SF.secondsToClock(sec))
    end
end

local function onTick()
	local now = GetTimeStamp()
	local drift = (now - TT.lasttick - 1)

	bountyCheck(now, drift)
	fenceCheck(now, drift)
	clemencyCheck(now, drift)

	TT:UpdateDisplay()
	TT:UpdateControls()

   TT.lasttick = now
end

local function setupTimer()
   TT.lasttick = GetTimeStamp()
   TT.bounty = GetBounty()
   TT:DynamicBountyCheck()

   EVENT_MANAGER:RegisterForUpdate(TT.name.."OnTick", 5000, onTick)
end

--[[ Registers a callback for inventory scene state changes to temporarily disable
	automatic junking while the inventory is open.

	When the inventory scene begins showing, sets TT.tempDisableJunking to true.
	When the scene begins hiding, resets TT.tempDisableJunking to false.

	This prevents automatic junking from running while the player is viewing the
	inventory. The flag is reset when the inventory scene starts hiding, rather
	than waiting until the scene is fully hidden.

	Note:
		This callback directly resets the flag on the inventory scene's hiding
		transition. If other UI scenes can also temporarily disable junking,
		consider tracking those states separately to avoid re-enabling junking
		while another scene still requires it to remain disabled.
--]]
local InventoryScene = SCENE_MANAGER.scenes.inventory
InventoryScene:RegisterCallback("StateChange", function(oldState, newState)
		-- states: hiding, showing, shown, hidden
		if newState == "showing" then
			-- disable autojunking for now
			TT.tempDisableJunking = true

		elseif newState == "hiding" then
			-- reenable autojunking
			TT.tempDisableJunking = false
		end
	end)

function TT:ToggleSafeInnocents()
    local mood = { ["aggressive"] = "0", ["passive"] = "1" }
	local safeInnocents = GetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS)
	if safeInnocents == mood.aggressive  then
		SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, mood.passive)
        TT.ShowMessage(TT_SAFE_INNOCENTS,TT.options.warns.message_dest)
		TT.dshow["Kill"] = false

	else
		SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_PREVENT_ATTACKING_INNOCENTS, mood.aggressive)
        TT.ShowMessage(TT_UNSAFE_INNOCENTS, message_dest)
		TT.dshow["Kill"] = true
	end
	TT:UpdateDisplay()
	TT:UpdateControls()
end

function TT:GetAutoSteal()
	return TT.options.chartt.autoSteal or false
end

function TT.DisableAutoSteal()
	local chartt = TT.options.chartt
	if chartt.autoSteal == nil then
		logDebug("TT.DisableAutoSteal: autoSteal was nil - setting to false")
		chartt.autoSteal = false
	end
	local isAutoLootEnabled = GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN)
	if chartt.autoSteal then
		logDebug("TT.DisableAutoSteal: autoSteal was true - setting to false")
		chartt.autoSteal = false
		TT.shouldShowAutoSteal()
		if isAutoLootEnabled == AUTO_LOOT_ON then
			SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN, AUTO_LOOT_OFF)
		end
		TT.ShowMessage(TT_AUTOSTEAL_OFF, message_dest)
	end
	logDebug("TT.DisableAutoSteal: updating display and controls")
	TT:UpdateDisplay()
	TT:UpdateControls()
end

function TT.EnableAutoSteal()
	if TT.options.chartt.autoSteal == nil then
		logDebug("TT.EnableAutoSteal: autoSteal was nil - setting to false")
		TT.options.chartt.autoSteal = false
	end
	if TTFAS and TTFAS_isEnabled() then
		TTFAS_Disable()
		TTmsg:systemMessage(L(TT_TTFAS_OFF))
	end

	if TT.options.chartt.autoSteal == false then
		logDebug("TT.EnableAutoSteal: autoSteal was false - setting to true")
		TT.options.chartt.autoSteal = true
		TT.shouldShowAutoSteal()
		TT.ShowMessage(TT_AUTOSTEAL_ON, message_dest)
		if GetUnitStealthState("player") == STEALTH_STATE_NONE then
			SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN, AUTO_LOOT_OFF)

		else
			SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN, AUTO_LOOT_ON)
		end
	end
	logDebug("TT.EnableAutoSteal: updating display and controls")
	TT:UpdateDisplay()
	TT:UpdateControls()
end

function TT:ToggleAutoSteal()
	if TT.options.chartt.autoSteal == nil then
		logDebug("TT:ToggleAutoSteal: autoSteal was nil - setting to false")
		TT.options.chartt.autoSteal = false
	end
	local isAutoLootEnabled = GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN)
	if TT.options.chartt.autoSteal == true then
		logDebug("TT:ToggleAutoSteal: autoSteal was true - setting to false")
		TT.DisableAutoSteal()

	else
		logDebug("TT:ToggleAutoSteal: autoSteal - setting to true")
		TT.EnableAutoSteal()
	end
	logDebug("TT:ToggleAutoSteal: updating display and controls")
	TT:UpdateDisplay()
	TT:UpdateControls()
end

function TT:toggleAutoJunk()
    if TT.options.chartt.enableJunking then
        TT.options.chartt.enableJunking = false
        TT.ShowMessage(TT_AUTOJUNK_OFF,1)

    else
        TT.options.chartt.enableJunking = true
        TT.ShowMessage(TT_AUTOJUNK_ON,1)
    end
end


-- handler for EVENT_RETICLE_HIDDEN_UPDATE
local function onReticleHidden()
	TT:UpdateControls()
end

function TT.RegisterEvents()
	evtmgr:registerEvt(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onSlotUpdate)
	evtmgr:filterEvt(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	evtmgr:filterEvt(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

	evtmgr:registerEvt(EVENT_LOOT_RECEIVED, onLoot)
	evtmgr:registerEvt(EVENT_ITEM_LAUNDER_RESULT, onLaunder)
	evtmgr:registerEvt(EVENT_JUSTICE_STOLEN_ITEMS_REMOVED, onApprehended)
	evtmgr:registerEvt(EVENT_OPEN_FENCE, function(evc) onFence(true) end)
	evtmgr:registerEvt(EVENT_CLOSE_STORE, function(evc) onFence(false) end)
	evtmgr:registerEvt(EVENT_SELL_RECEIPT, onSold)

	evtmgr:registerEvt(EVENT_ACTION_LAYER_PUSHED, onLayerChange)
	evtmgr:registerEvt(EVENT_ACTION_LAYER_POPPED, onLayerChange)

    evtmgr:registerEvt(EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED, onBountyChange)
	evtmgr:registerEvt(EVENT_RETICLE_HIDDEN_UPDATE, onReticleHidden)

	evtmgr:registerEvt(EVENT_STEALTH_STATE_CHANGED, onStealthChanged)
	evtmgr:filterEvt(EVENT_STEALTH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    SHARED_INVENTORY:RegisterCallback("SlotRemoved", onRemoved)
end

function TT.UnregisterEvents()
	evtmgr:unregAllEvt()
    SHARED_INVENTORY:UnregisterCallback("SlotRemoved", onRemoved)
end


function TT:TimeToFenceReset(t)
   -- Seems to reset at 3am utc
   local fence_start = 10800

   t = t or GetTimeStamp()

   local one_day = (24*60*60)
   local d = one_day - ((t - fence_start) % one_day)

   local timestr = fmt_time(d)
   return timestr, d
end

-- Things to do when zone changes...
local function onPlayerActivated()
	TT:UpdateDisplay()
end

local function onPlayerActivatedOnce()
    evtmgr:unregEvt(EVENT_PLAYER_ACTIVATED)
    TT.set_handlers(TT.options.filter)

    TT:BuildUI()
	clemencyCheck()
	TT.RegisterEvents()
	setupTimer()

    TT:checkFreeSlotsWarning(BAG_BACKPACK)
    TT:checkFenceSlotsWarning(BAG_BACKPACK)
	evtmgr:registerEvt(EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

local function onLoaded(ev, addon)
    if addon ~= TT.name then return end
    evtmgr:unregEvt(EVENT_ADD_ON_LOADED)

    TT.savedAW = ZO_SavedVars:NewAccountWide("ThiefToolsVars", 3, GetWorldName(), TT.DefaultAW)
    TT.savedC = ZO_SavedVars:New("ThiefToolsVars", 3, GetWorldName(), TT.DefaultC)
    TT.setOptionsScope()
    TT:RegisterSettings()
	evtmgr:registerEvt(EVENT_PLAYER_ACTIVATED, onPlayerActivatedOnce)
end

evtmgr:registerEvt(EVENT_ADD_ON_LOADED, onLoaded)

-- --------------------------------------------------------
-- Slash commands
-- --------------------------------------------------------

local function slashHelp()
	if TTmsg == nil then return end
    local cmdtable = {
        {"/thieftools", "Print this help message"},
        {"/tt", 		TT_CHAT_CMD_TOGGLE},
        {"/tt.lock" , 	TT_CHAT_CMD_LOCK_BAR_POSITION},
        {"/tt.meter", 	TT_CHAT_CMD_METER},
        {"/tt.fencetime", TT_CHAT_CMD_FENCETIME},
        {"/tt.update", 	TT_CHAT_CMD_RECALC},
        {"/tt.counts", 	TT_CHAT_CMD_COUNTS},
        {"/tt.safe", 	TT_CHAT_CMD_SAFE},
        {"/tt.as", 		TT_CHAT_CMD_AUTOSTEAL},
        {"/tt.fas", 	TT_CHAT_CMD_TTFAS},
        {"/tt.junk", 	TT_CHAT_CMD_AUTOJUNK},
        {"/tt.stop", 	TT_CHAT_CMD_STOP},
    }
    local title = L(TT_CHAT_THIEFTOOLS_COMMANDS)
    TTmsg:slashHelp(title, cmdtable)
end

SLASH_COMMANDS["/thieftools"] = function()
	local sysmsg = function (cmd, desc)
		cmd = SF.ColorText(cmd, SF.hex.teal)
		if  type(desc) == "number" then
			desc = L(desc)
		end
		desc = SF.ColorText(SF.str(" = ", desc), TTmsg.normalcolor)
		local msg = SF.dstr( " ", TTmsg.prefix, cmd, desc )
		ZOS_addSystemMsg(msg);
	end

    if tempHideBar == true then
        TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING))
        TTmsg:systemMessage(L(TT_CHAT_THIEFTOOLS_COMMANDS))
        sysmsg("/tt.start", TT_CHAT_CMD_START)
		
    else
        slashHelp()
    end
end

SLASH_COMMANDS["/tt"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end
	local win = TT.window

   if win:IsHidden() then
		TT:CalcStolenGoods()
		TT:UpdateDisplay()
		TT:UpdateControls()
   end

   TT.options.display.hidden = not win:IsHidden()
   win:SetHidden(not TT:ShouldDisplayBelt())
end

SLASH_COMMANDS["/tt.lock"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end

    local lockwin = TT.options.display.locked
    if lockwin == true then
        TT.window:SetMovable(true)
        TT.options.display.locked = false
        TTmsg:systemMessage(L(TT_MSG_UNLOCKED))
        TT.SavePosition()

    else
        TT.window:SetMovable(false)
        TT.options.display.locked = true
        TTmsg:systemMessage(L(TT_MSG_LOCKED))
        TT.SavePosition()
    end
end

SLASH_COMMANDS["/tt.meter"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end

    if TT.options.display.hideMeter == true then
        ZO_HUDInfamyMeter:SetHidden(false)
        TT.options.display.hideMeter = false
		
    else
        ZO_HUDInfamyMeter:SetHidden(true)
        TT.options.display.hideMeter = true
    end
end

SLASH_COMMANDS["/tt.resetbar"] = function()
    local win = TT.window

	TT.options.chartt.not_thief = false
	ZO_HUDInfamyMeter:SetHidden(true)
	TT.options.display.hideMeter = true
	win:SetMovable(true)
	TT.options.display.locked = false
	TT.options.display.hidden = false

	win:SetHidden(not TT:ShouldDisplayBelt())
	TT:ResetPosition()
	TT.SavePosition()
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetClampedToScreenInsets(4, 4, -4, -4)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
end


SLASH_COMMANDS["/tt.fencetime"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end

   local str = TT:TimeToFenceReset()
   TTmsg:systemMessage("Fence will reset in", str)
end

-- --------------------------------------------------------
local rescan = function()
    if tempHideBar == true then 
		TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING))
		return
	end

    TT.set_handlers(TT.options.filter)
	TTmsg:systemMessage(L(TT_CHAT_CMD_RECALC_ACK))
	TT.delaying = false
	TT:CalcStolenGoods()
	--TTmsg:debugMsg("EQUIP_TYPE_RING=",EQUIP_TYPE_RING)
	--TTmsg:debugMsg("EQUIP_TYPE_NECK=",EQUIP_TYPE_NECK)
end

SLASH_COMMANDS["/tt.rescan"] = rescan
SLASH_COMMANDS["/tt.update"] = rescan

-- --------------------------------------------------------
local statcounter = function()
    if tempHideBar == true then 
		TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING))
		return
	end

    TTmsg:systemMessage(L(TT_STATS_RECIPES), TT.recipeCount)
    TTmsg:systemMessage(L(TT_STATS_MOTIFS), TT.motifCount)
    TTmsg:systemMessage(L(TT_STATS_FURNITURE), TT.furnitureCount)
    TTmsg:systemMessage(L(TT_STATS_FENCE), TT.fenceCount)
    TTmsg:systemMessage(L(TT_STATS_LAUNDER), TT.launderCount)
end

SLASH_COMMANDS["/tt.count"] = statcounter
SLASH_COMMANDS["/tt.counts"] = statcounter

-- --------------------------------------------------------

SLASH_COMMANDS["/tt.safe"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end
    TT.ToggleSafeInnocents()
end
SLASH_COMMANDS["/tt.tm"] = SLASH_COMMANDS["/tt.safe"]

-- --------------------------------------------------------
SLASH_COMMANDS["/tt.as"] = function()
    if tempHideBar == true then 
		TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING))
		return 
	end
	local autoSteal = ThiefTools.options.chartt.autoSteal
	if autoSteal == true then
		TT.DisableAutoSteal()

	else
		TT.EnableAutoSteal()
	end
end

SLASH_COMMANDS["/tt.fas"] = function()
    if tempHideBar == true then 
		TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING))
		return
	end
	local autoSteal = ThiefTools.options.chartt.autoSteal

	if not TTFAS then
		TTmsg:systemMessage(L(TT_CHAT_TTFAS_NOT_AVAIL))
		return
	end
	if autoSteal == true then
		TT.DisableAutoSteal()
	end
	if not TTFAS_isEnabled() then
		TTFAS_Enable()
		TTmsg:systemMessage(L(TT_TTFAS_ON))

	else
		TTFAS_Disable() -- this also runs TT.DisableAutoSteal
		TTmsg:systemMessage(L(TT_TTFAS_OFF))
	end
	TT:UpdateDisplay()
end

-- --------------------------------------------------------
SLASH_COMMANDS["/tt.junk"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end
    TT.toggleAutoJunk()
end

SLASH_COMMANDS["/tt.debug"] = function()
    if tempHideBar == true then TTmsg:systemMessage(L(TT_CHAT_NOT_RUNNING));return end
    slashToggleDebug()
end

SLASH_COMMANDS["/tt.stop"] = function()
    if not tempHideBar then
        TTmsg:systemMessage(L(TT_STOPPING))

		tempHideBar = true
		TT.window:SetHidden(not TT:ShouldDisplayBelt())
        TT.UnregisterEvents()

    else
        TTmsg:systemMessage(L(TT_ALREADY_STOPPED))
    end
end

SLASH_COMMANDS["/tt.start"] = function()
    if tempHideBar then
        TTmsg:systemMessage(L(TT_STARTING))
        tempHideBar = false
        onBountyChange(nil,0,0)
        TT:CalcStolenGoods()
        TT:UpdateDisplay()
        TT:UpdateControls()
        TT.RegisterEvents()

    else
        TTmsg:systemMessage(L(TT_ALREADY_RUNNING))
    end
end
