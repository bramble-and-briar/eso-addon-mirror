local LCCC = LibCodesCommonCode
local LootLog = LootLog
local LootLogMulti = LootLog.modules.multi

local LMAS = LibMultiAccountSets
local LCK = LibCharacterKnowledge
local LMAC = LibMultiAccountCollectibles


LootLogMulti.name = "LootLogMulti"

LootLogMulti.CONTEXT_LOOTED_PERSONAL = true
LootLogMulti.CONTEXT_LOOTED_OTHERS = false
LootLogMulti.CONTEXT_HISTORY_FILTER = 1
LootLogMulti.CONTEXT_INCOMING_CHAT = 2
LootLogMulti.CONTEXT_MAIL_ATTACHMENT = 3
LootLogMulti.FALLBACK_COLOR = 0xFFFFFF

local FLAG_SUPPORTED_LMAS = 1
local FLAG_SUPPORTED_LCK = 2
local FLAG_SUPPORTED_LMAC = 4
local MASK_MULTI_ACCOUNT = 5

local PRIORITY_OFF = 0
local PRIORITY_LOW = 1
local PRIORITY_MAX = 3

local IndicatorIcons = { default = "LootLog/art/uncollected.dds" }
for i = PRIORITY_LOW, PRIORITY_MAX do
	IndicatorIcons[i] = string.format("LootLog/art/uncollected-%d.dds", i)
end

local AntiquityIcons = {
	general = "LootLog/art/antiquities-general.dds",
	motif = "LootLog/art/antiquities-motif.dds",
	motif2 = "LootLog/art/antiquities-motif-light.dds",
}


--------------------------------------------------------------------------------
-- LootLogMulti.Initialize
--------------------------------------------------------------------------------

function LootLogMulti.Initialize( server )
	-- Determine how much of LootLogMulti will be supported
	LootLogMulti.support = 0
	if (LMAS) then
		local accounts = LMAS.GetAccountList(false)
		if (#accounts > 1) then
			LootLogMulti.support = BitOr(LootLogMulti.support, FLAG_SUPPORTED_LMAS)
		end
	end
	if (LCK) then
		LootLogMulti.support = BitOr(LootLogMulti.support, FLAG_SUPPORTED_LCK)
		LCK.RegisterForCallback(LootLogMulti.name, LCK.EVENT_INITIALIZED, function( )
			LootLogMulti.lckReady = true
		end)
	end
	if (LMAC) then
		local accounts = LMAC.GetServerAndAccountList(true)[1].accounts
		if (#accounts > 1) then
			LootLogMulti.support = BitOr(LootLogMulti.support, FLAG_SUPPORTED_LMAC)
		end
	end

	-- If the old key name is present, rename it
	if (LootLog.vars.multiAccounts and not LootLog.vars.multi) then
		LootLog.vars.multi = LootLog.vars.multiAccounts
		LootLog.vars.multiAccounts = nil
	end

	-- Initialize color settings
	if (LootLogMulti.support > 0) then
		if (not LootLog.vars.multi) then
			LootLog.vars.multi = { }
		end

		if (not LootLog.vars.multi.colors) then
			LootLog.vars.multi.colors = {
				0xCCFFCC,
				0x00CC99,
				0x33CCFF,
			}
		end
		LootLogMulti.colors = LootLog.vars.multi.colors
	else
		LootLogMulti.colors = { }
	end

	-- Initialize account priority settings
	if (BitAnd(LootLogMulti.support, MASK_MULTI_ACCOUNT) ~= 0) then
		if (not LootLog.vars.multi[server]) then
			LootLog.vars.multi[server] = {
				enabled = false,
			}
		end
		LootLogMulti.vars = LootLog.vars.multi[server]
	else
		LootLogMulti.vars = { enabled = false }
	end
end


--------------------------------------------------------------------------------
-- LootLogMulti.GetCurrentAccountPriority
--------------------------------------------------------------------------------

function LootLogMulti.GetCurrentAccountPriority( )
	if (LootLogMulti.vars.enabled) then
		return LootLogMulti.vars[LootLog.self.userId] or PRIORITY_OFF
	else
		return PRIORITY_MAX
	end
end


--------------------------------------------------------------------------------
-- LootLogMulti.ShouldFlagAsUncollected
--------------------------------------------------------------------------------

local function MultiEnabled( flag )
	return LootLogMulti.vars.enabled and BitAnd(LootLogMulti.support, flag) == flag
end

local function LCKEnabled( )
	if (LootLogMulti.vars.lck ~= nil) then
		-- Explicit setting
		return LootLogMulti.vars.lck
	elseif (CharacterKnowledge and CharacterKnowledge.AddTooltipExtension) then
		return true
	else
		-- Disable by default because the markings can be confusing without the CK tooltip for context
		return false
	end
end

local function GetItemPriority( itemLink, context, checkInventory, ignorePriorityFloor )
	local results = LMAS.GetItemCollectionAndTradabilityStatus(nil, itemLink, context)
	if (results == LMAS.ITEM_UNCOLLECTIBLE) then return false end

	-- Amend the current account's collection status with "unused" items, if requested
	if (checkInventory and results[LootLog.self.userId] ~= LMAS.ITEM_COLLECTED) then
		LootLog.ScanInventoryForUncollectedItems()
		if (LootLog.inventory.pieces[LootLog.GetItemLinkItemSetCollectionKey(itemLink)]) then
			results[LootLog.self.userId] = LMAS.ITEM_COLLECTED
		end
	end

	-- Find the highest matching priority
	local priority = PRIORITY_OFF
	for account, status in pairs(results) do
		local accountPriority = LootLogMulti.vars[account] or PRIORITY_OFF
		if (status == LMAS.ITEM_UNCOLLECTED_TRADE and accountPriority > priority) then
			priority = accountPriority
		end
	end

	-- Determine if the current account should "use" the item
	local selfPriority = LootLogMulti.vars[LootLog.self.userId] or PRIORITY_OFF
	local selfUse = priority == selfPriority and (ignorePriorityFloor or priority > PRIORITY_OFF) and results[LootLog.self.userId] ~= LMAS.ITEM_COLLECTED

	-- Use multi-account flagging only if the item is not intended for the current account
	return not selfUse, priority
end

local function ShouldFlagAsUncollectedSetItem( itemLink, context, checkInventory )
	if (type(context) == "table") then
		-- Item lists
		if (MultiEnabled(FLAG_SUPPORTED_LMAS)) then
			local useMulti, priority = GetItemPriority(itemLink, context, checkInventory, GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP)
			if (useMulti) then
				return priority > PRIORITY_OFF, LootLogMulti.colors[priority], IndicatorIcons[priority]
			end
		end

		-- Default fallback
		return LootLog.IsItemLinkUncollected(itemLink, checkInventory), LootLog.vars.uncollectedColors.itemLists
	elseif (context == LootLogMulti.CONTEXT_INCOMING_CHAT) then
		-- Linked in chat
		if (not LootLog.IsItemLinkTradeable(itemLink)) then
			return false
		end

		-- Use multi-account mode only for BoE items for accounts of equal or higher priority
		if (MultiEnabled(FLAG_SUPPORTED_LMAS) and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_EQUIP) then
			local useMulti, priority = GetItemPriority(itemLink, nil, checkInventory)
			if (useMulti) then
				return priority > PRIORITY_OFF and priority >= LootLogMulti.GetCurrentAccountPriority(), LootLogMulti.colors[priority], IndicatorIcons[priority]
			end
		end

		-- Default fallback
		return LootLog.IsItemLinkUncollected(itemLink, checkInventory), LootLog.vars.uncollectedColors.linkedChat
	elseif (context == LootLogMulti.CONTEXT_HISTORY_FILTER) then
		-- Uncollected filter in the Loot History browser: Use multi-account mode only for BoE items for accounts of equal or higher priority
		if (MultiEnabled(FLAG_SUPPORTED_LMAS) and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_EQUIP) then
			local useMulti, priority = GetItemPriority(itemLink, nil, checkInventory)
			if (useMulti) then
				return priority > PRIORITY_OFF and priority >= LootLogMulti.GetCurrentAccountPriority()
			end
		end

		-- Default fallback
		return LootLog.IsItemLinkUncollected(itemLink, checkInventory)
	else
		-- All other contexts: Use multi-account mode only for BoE items
		if (MultiEnabled(FLAG_SUPPORTED_LMAS) and GetItemLinkBindType(itemLink) == BIND_TYPE_ON_EQUIP) then
			local useMulti, priority = GetItemPriority(itemLink, nil, checkInventory)
			if (useMulti) then
				return priority > PRIORITY_OFF, LootLogMulti.colors[priority], IndicatorIcons[priority]
			end
		end

		-- Default fallback
		local color
		if (context == LootLogMulti.CONTEXT_LOOTED_PERSONAL) then
			color = LootLog.vars.uncollectedColors.lootedPersonal
		elseif (context == LootLogMulti.CONTEXT_LOOTED_OTHERS) then
			color = LootLog.vars.uncollectedColors.lootedGroup
		elseif (context == LootLogMulti.CONTEXT_MAIL_ATTACHMENT) then
			color = LootLog.vars.uncollectedColors.itemLists
		end
		return LootLog.IsItemLinkUncollected(itemLink, checkInventory), color
	end
end

local function ShouldFlagAsUncollectedRecipeOrMotif( itemLink, context, _, personal )
	local characters = LCK.GetItemKnowledgeList(itemLink)

	local rank
	local selfRank = #characters + 1
	local bindType = GetItemLinkBindType(itemLink)

	if (type(context) == "table" or context == LootLogMulti.CONTEXT_LOOTED_PERSONAL or context == LootLogMulti.CONTEXT_MAIL_ATTACHMENT) then
		personal = true
	elseif (context == LootLogMulti.CONTEXT_LOOTED_OTHERS or context == LootLogMulti.CONTEXT_INCOMING_CHAT) then
		personal = false
	end

	for i, character in ipairs(characters) do
		if (character.id == LootLog.self.charId) then
			selfRank = i
		end

		-- Find the first character that does not know the item and is eligible for trade
		if (not rank and character.knowledge == LCK.KNOWLEDGE_UNKNOWN) then
			if (bindType == BIND_TYPE_ON_PICKUP) then
				if (personal and character.account == LootLog.self.userId) then
					rank = i
				end
			elseif (bindType == BIND_TYPE_ON_PICKUP_BACKPACK) then
				if (personal and selfRank == i) then
					rank = i
				end
			else
				rank = i
			end
		end
	end

	if (not rank) then
		return false
	elseif (rank == selfRank) then
		if (context == LootLogMulti.CONTEXT_LOOTED_PERSONAL) then
			return true, LootLog.vars.uncollectedColors.lootedPersonal
		elseif (context == LootLogMulti.CONTEXT_LOOTED_OTHERS) then
			return true, LootLog.vars.uncollectedColors.lootedGroup
		elseif (context == LootLogMulti.CONTEXT_INCOMING_CHAT) then
			return true, LootLog.vars.uncollectedColors.linkedChat
		else
			return true, LootLog.vars.uncollectedColors.itemLists
		end
	else
		local priority
		if (rank == 1) then
			priority = PRIORITY_MAX
		elseif (rank < selfRank) then
			priority = 2
		else
			priority = PRIORITY_LOW
		end
		return true, LootLogMulti.colors[priority], IndicatorIcons[priority]
	end
end

local function ShouldFlagAsUncollectedCollectible( itemLink, context, checkInventory, personal )
	local bindType = GetItemLinkBindType(itemLink)

	if (type(context) == "table" or context == LootLogMulti.CONTEXT_LOOTED_PERSONAL or context == LootLogMulti.CONTEXT_MAIL_ATTACHMENT) then
		personal = true
	elseif (context == LootLogMulti.CONTEXT_LOOTED_OTHERS or context == LootLogMulti.CONTEXT_INCOMING_CHAT) then
		personal = false
	end

	if (bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK) then
		-- BoP items: Always unflag if not personal, and fall through to the
		-- default behavior, which is single-account
		if (not personal) then
			return false
		end
	else
		-- Tradeable items
		local collectibleId = GetItemLinkContainerCollectibleId(itemLink)

		local uncollected = function( account )
			if (not account or account == LootLog.self.userId) then
				-- Need to respect the checkInventory flag for the current account
				return LootLog.IsItemLinkUncollected(itemLink, checkInventory)
			else
				return not LMAC.IsCollectibleOwnedByAccount(nil, account, collectibleId)
			end
		end

		-- Find the highest matching priority
		local priority = PRIORITY_OFF
		for _, account in ipairs(LMAC.GetServerAndAccountList(true)[1].accounts) do
			local accountPriority = LootLogMulti.vars[account] or PRIORITY_OFF
			if (uncollected(account) and accountPriority > priority) then
				priority = accountPriority
			end
		end

		if (priority > PRIORITY_OFF) then
			-- Determine if the current account should "use" the item
			local selfPriority = LootLogMulti.vars[LootLog.self.userId] or PRIORITY_OFF
			local selfUse = priority == selfPriority and uncollected()

			if (not selfUse) then
				return true, LootLogMulti.colors[priority], IndicatorIcons[priority]
			end
		else
			return false
		end
	end

	-- Fall through to the default single-account behavior; this will be reached
	-- for BoP items and for self-use items
	return ShouldFlagAsUncollectedSetItem(itemLink, context, checkInventory)
end

local function ShouldFlagAsTreasureMapWithLeadsOrTradeableLead( itemLink, context )
	if (context == LootLogMulti.CONTEXT_HISTORY_FILTER or context == LootLogMulti.CONTEXT_INCOMING_CHAT) then
		return false
	end

	local totalLoreAcquired = 0
	local totalLore = 0
	local neverFound = false
	local hasMotif = false

	local tradeableLeadId = LootLog.GetAntiquityIdFromItem(itemLink)
	local isTreasureMap = tradeableLeadId == 0

	for _, antiquityId in ipairs(isTreasureMap and LootLog.GetAntiquityIdsForTreasureMap(itemLink) or { tradeableLeadId }) do
		local loreAcquired = GetNumAntiquityLoreEntriesAcquired(antiquityId)
		local lore = GetNumAntiquityLoreEntries(antiquityId)

		if (loreAcquired < lore and DoesAntiquityHaveLead(antiquityId)) then
			-- If the player has an unexcavated lead, let it count towards the codex
			loreAcquired = loreAcquired + 1
		end

		if (loreAcquired == 0) then
			neverFound = true
		end
		totalLoreAcquired = totalLoreAcquired + loreAcquired
		totalLore = totalLore + lore

		if (not hasMotif and GetItemLinkItemType(LootLog.GetAntiquityRewardLink(antiquityId)) == ITEMTYPE_RACIAL_STYLE_MOTIF) then
			hasMotif = true
		end
	end

	if (totalLore > 0 and ((isTreasureMap and (hasMotif or not LootLog.vars.antiquityOnlyMotifs)) or (not isTreasureMap and LootLog.vars.antiquityFlagTradeable and totalLoreAcquired < totalLore))) then
		local color
		if (totalLoreAcquired >= totalLore) then
			color = "fullCodex"
		elseif (not neverFound) then
			color = "incompleteCodex"
		else
			color = "neverFound"
		end
		local icon
		if (not hasMotif) then
			icon = "general"
		elseif (totalLore <= 4) then
			icon = "motif2"
		else
			icon = "motif"
		end
		return true, LootLog.vars.antiquityMapColors[color], AntiquityIcons[icon], not neverFound
	else
		return false
	end
end

function LootLogMulti.ShouldFlagAsUncollected( ... )
	local results
	local itemLink = ...
	if (LootLogMulti.CanUseLCK() and LCK.GetItemCategory(itemLink) ~= LCK.ITEM_CATEGORY_NONE) then
		results = { ShouldFlagAsUncollectedRecipeOrMotif(...) }
	elseif (MultiEnabled(FLAG_SUPPORTED_LMAC) and GetItemLinkContainerCollectibleId(itemLink) > 0) then
		results = { ShouldFlagAsUncollectedCollectible(...) }
	elseif (LootLog.vars.antiquityEnabled and (select(2, GetItemLinkItemType(itemLink)) == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or LootLog.GetAntiquityIdFromItem(itemLink) > 0)) then
		results = { ShouldFlagAsTreasureMapWithLeadsOrTradeableLead(...) }
	else
		results = { ShouldFlagAsUncollectedSetItem(...) }
	end

	-- Set default color and icon as needed
	if (type(results[2]) ~= "number") then results[2] = LootLogMulti.FALLBACK_COLOR end
	if (type(results[3]) ~= "string") then results[3] = IndicatorIcons.default end
	return unpack(results)
end


--------------------------------------------------------------------------------
-- LootLogMulti.CountUncollectedAccounts
--------------------------------------------------------------------------------

function LootLogMulti.CountUncollectedAccounts( itemLink, context, priorityFloor )
	local count = 0

	if (MultiEnabled(FLAG_SUPPORTED_LMAS)) then
		local results = LMAS.GetItemCollectionAndTradabilityStatus(nil, itemLink, context)
		if (results ~= LMAS.ITEM_UNCOLLECTIBLE) then
			if (not priorityFloor) then priorityFloor = PRIORITY_OFF end

			for account, status in pairs(results) do
				local accountPriority = LootLogMulti.vars[account] or PRIORITY_OFF
				if (status == LMAS.ITEM_UNCOLLECTED_TRADE and accountPriority > priorityFloor) then
					count = count + 1
				end
			end
		end
	end

	return count
end


--------------------------------------------------------------------------------
-- LootLogMulti.CanUseLCK
--------------------------------------------------------------------------------

function LootLogMulti.CanUseLCK( )
	if (LCKEnabled() and LootLogMulti.lckReady) then
		return true
	else
		return false
	end
end


--------------------------------------------------------------------------------
-- LootLogMulti.BuildSettings
--------------------------------------------------------------------------------

local function BuildAccountList( )
	local accounts = { }

	if (BitAnd(LootLogMulti.support, FLAG_SUPPORTED_LMAS) == FLAG_SUPPORTED_LMAS) then
		for _, account in ipairs(LMAS.GetAccountList(false)) do
			accounts[account] = true
		end
	end

	if (BitAnd(LootLogMulti.support, FLAG_SUPPORTED_LMAC) == FLAG_SUPPORTED_LMAC) then
		for _, account in ipairs(LMAC.GetServerAndAccountList(false)[1].accounts) do
			accounts[account] = true
		end
	end

	return LCCC.GetSortedKeys(accounts)
end

function LootLogMulti.BuildSettings( Colors )
	local controls = { }

	local priorityCaptions = {
		[PRIORITY_OFF] = SI_CHECK_BUTTON_OFF,
		[PRIORITY_LOW] = SI_SUBSAMPLINGMODE0, -- formerly SI_LOW, before it was changed
		[PRIORITY_MAX] = SI_SUBSAMPLINGMODE2, -- formerly SI_HIGH, before it was changed
	}

	--------
	-- Colors section
	--------

	if (LootLogMulti.support > 0) then
		for i = PRIORITY_LOW, PRIORITY_MAX do
			local key = string.format("multi%d", i)
			local title = string.format(GetString(SI_LOOTLOG_MULTI_PRIORITY), i)
			if (priorityCaptions[i]) then
				title = string.format("%s (%s)", title, GetString(priorityCaptions[i]))
			end
			table.insert(controls, {
				type = "colorpicker",
				name = title,
				getFunc = function() return LCCC.Int24ToRGB(LootLogMulti.colors[i] or LootLogMulti.FALLBACK_COLOR) end,
				setFunc = function(...)
					LootLogMulti.colors[i] = LCCC.RGBToInt24(...)
					Colors.UpdatePreview(key)
					LootLog.RefreshUI(1)
				end,
				reference = Colors.GetGlobalName(key),
			})
			Colors.data[key] = {
				setting = LootLogMulti.colors,
				priority = i,
				icon = IndicatorIcons[i],
			}
		end
	end

	--------
	-- Account priorities section
	--------

	if (BitAnd(LootLogMulti.support, MASK_MULTI_ACCOUNT) ~= 0) then
		local accounts = BuildAccountList()
		local priorities = { }
		local priorityLabels = { }

		for i = PRIORITY_OFF, PRIORITY_MAX do
			table.insert(priorities, i)
			if (i == PRIORITY_OFF) then
				table.insert(priorityLabels, GetString(priorityCaptions[i]))
			elseif (priorityCaptions[i]) then
				table.insert(priorityLabels, string.format("%d (%s)", i, GetString(priorityCaptions[i])))
			else
				table.insert(priorityLabels, tostring(i))
			end
		end

		local accountsSection = { }
		for _, account in ipairs(accounts) do
			table.insert(accountsSection, {
				type = "dropdown",
				name = account,
				choices = priorityLabels,
				choicesValues = priorities,
				getFunc = function() return LootLogMulti.vars[account] or PRIORITY_OFF end,
				setFunc = function(priority)
					LootLogMulti.vars[account] = (priority ~= PRIORITY_OFF) and priority or nil
					LootLog.RefreshUI(1)
				end,
			})
		end

		if (BitAnd(LootLogMulti.support, FLAG_SUPPORTED_LCK) == FLAG_SUPPORTED_LCK) then
			LCCC.ConcatTables(controls, {
				--------------------------------------------------------------------
				{
					type = "header",
					name = SI_LOOTLOG_SECTION_LCK,
				},
				--------------------
				{
					type = "description",
					text = SI_LOOTLOG_LCK_DESCRIPTION,
				},
				--------------------
				{
					type = "checkbox",
					name = SI_ADDON_MANAGER_ENABLED,
					getFunc = LCKEnabled,
					setFunc = function(enabled)
						LootLogMulti.vars.lck = enabled
						LootLog.RefreshUI(1)
					end,
				},
			})
		end

		LCCC.ConcatTables(controls, {
			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LOOTLOG_SECTION_MULTI,
			},
			--------------------
			{
				type = "description",
				text = SI_LOOTLOG_MULTI_DESCRIPTION,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_ADDON_MANAGER_ENABLED,
				getFunc = function() return LootLogMulti.vars.enabled end,
				setFunc = function(enabled)
					LootLogMulti.vars.enabled = enabled
					LootLog.RefreshUI(1)
				end,
			},
			--------------------
			{
				type = "submenu",
				name = SI_LOOTLOG_MULTI_ACCOUNTS,
				controls = accountsSection,
				disabled = function() return not LootLogMulti.vars.enabled end,
			},
		})
	end

	return controls
end
