local LCCC = LibCodesCommonCode

local Public = { }
LibCharacterKnowledge = Public


--------------------------------------------------------------------------------
-- Internal Components
--------------------------------------------------------------------------------

local Internal = {
	name = "LibCharacterKnowledge",

	CATEGORY_RECIPE = "recipes",
	CATEGORY_PLAN = "plans",
	CATEGORY_MOTIF = "motifs",
	CATEGORY_SCRIBING = "sc",
	CATEGORY_RESEARCH = "rt",
	CATEGORY_NONE = false,
	CATEGORY_INVALID = nil,

	SCRIBE_GRIMOIRE = "grimoires",
	SCRIBE_SCRIPT = "scripts",

	QUALITY_LOW = 1,
	QUALITY_MEDIUM = 2,
	QUALITY_HIGH = 3,

	KNOWLEDGE_INVALID = -1,
	KNOWLEDGE_NODATA = 0,
	KNOWLEDGE_KNOWN = 1,
	KNOWLEDGE_UNKNOWN = 2,

	PRIORITY_RANKS = 100,
	PRIORITY_RANK_DEFAULT = 50,

	-- SV format version
	FORMAT_VERSION = 1,

	scanThrottle = 200, -- 0.2s

	server = LCCC.GetServerName(),
	userId = GetDisplayName(),
	charId = GetCurrentCharacterId(),

	maxIds = { },
	ids = { },
	idsPublic = { },
	cachedCharLists = { },
	decoderIndices = { },
	initialized = false,

	-- Placeholders to allow pre-init calls to fail gracefully
	accounts = { },
	characters = { },
}
LibCharacterKnowledgeInternal = Internal

-- Data encoding parameters
local ENCODE_BITS = 6 -- 6-bit encoding
local BLOCK_BITS = 36 -- Block size for single-bit data
local BLOCK_BYTES = 6 -- BLOCK_BITS / ENCODE_BITS

-- Data storage parameters
local CHUNK_BYTES = 0x600 -- Line size for LCCC.Chunk; needs to be compatible with both fieldSize 3 and 4 for the master list
local CHUNK_BITS = 0x2400 -- CHUNK_BYTES * ENCODE_BITS

LCCC.RunAfterInitialLoadscreen(function( )
	zo_callLater(Internal.Initialize, Internal.scanThrottle)
end)


--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------

local Diagnostics = {
	cg = LCCC.NOP,
	times = { },
}

if (IsConsoleUI()) then
	Internal.scanThrottle = 300
	Diagnostics.cg = collectgarbage
end

function Diagnostics.Stopwatch( start )
	local tick = GetGameTimeMilliseconds()
	if (start) then
		Diagnostics.cg("stop")
		ZO_ClearTable(Diagnostics.times)
	else
		table.insert(Diagnostics.times, tick - Diagnostics.tick)
	end
	Diagnostics.tick = tick
end

function Diagnostics.LogTime( name )
	Diagnostics.Stopwatch()

	if (not Diagnostics.vars[name]) then
		Diagnostics.vars[name] = { next = 1 }
	end
	local history = Diagnostics.vars[name]

	if (#Diagnostics.times == 1) then
		history[history.next] = Diagnostics.times[1]
	else
		local total = 0
		for _, time in ipairs(Diagnostics.times) do
			total = total + time
		end
		history[history.next] = string.format("%dms (%s)", total, table.concat(Diagnostics.times, "/"))
	end

	history.next = history.next % 4 + 1
	Diagnostics.cg("restart")
end


------ Workaround Issue #1 -----------------------------------------------------
-- There was an edge case of a chaptered motif that had no book version; that
-- problem has since been fixed by ZOS, so the handling for that no longer runs,
-- but the code still exists just in case and is marked by BOOKLESS
------ Workaround Issue #2 -----------------------------------------------------
-- There is a rare bug where IsItemLinkBookKnown will incorrectly report a book
-- as unknown, so this works around the problem by looking at chapter knowledge
--------------------------------------------------------------------------------

local MotifFixer = { }

do
	local COMPLETE_STYLE = 0x3FFF
	local activeFixData

	function MotifFixer.Init( )
		-- Active fixes are used only during init; later scan fixes are passive
		activeFixData = (not Internal.initialized) and { styles = { }, incompleteBooks = { } } or nil
	end

	function MotifFixer.RecordKnownStyle( itemId )
		if (activeFixData) then
			local styleId, chapterId = Internal.GetMotifStyleAndChapter(itemId)
			local styles = activeFixData.styles
			if (chapterId == ITEM_STYLE_CHAPTER_ALL) then
				styles[styleId] = COMPLETE_STYLE
			else
				styles[styleId] = BitOr(styles[styleId] or 0, 2 ^ (chapterId - 1))
			end
		end
	end

	function MotifFixer.HandleUnknownStyle( itemId, index )
		local styleId, chapterId = Internal.GetMotifStyleAndChapter(itemId)
		if (styleId > 0 and chapterId == ITEM_STYLE_CHAPTER_ALL) then
			if (activeFixData) then
				activeFixData.incompleteBooks[itemId] = index * 0x10000 + styleId
			end
			if (Internal.IndexedGetKnowledge(Internal.server, Internal.charId, Internal.CATEGORY_MOTIF, itemId, index)) then
				return 1
			end
		end
		return 0
	end

	function MotifFixer.ApplyFixes( )
		if (activeFixData) then
			local overrides = { }
			for itemId, styleIdAndIndex in pairs(activeFixData.incompleteBooks) do
				local styleId = styleIdAndIndex % 0x10000
				if (activeFixData.styles[styleId] == COMPLETE_STYLE) then
					table.insert(overrides, itemId)
					LCCC.SetBitInEncodedData(Internal.characters[Internal.server][Internal.charId], Internal.CATEGORY_MOTIF, BitRShift(styleIdAndIndex, 16), CHUNK_BITS, true)
				end
			end
			local dv = Diagnostics.vars
			if (#overrides > 0) then
				table.sort(overrides)
				if (not dv.bookCorrections) then
					dv.bookCorrections = { }
				end
				dv.bookCorrections[Internal.charId] = table.concat(overrides, ",")
			elseif (dv.bookCorrections) then
				dv.bookCorrections[Internal.charId] = nil
				if (not next(dv.bookCorrections)) then
					dv.bookCorrections = nil
				end
			end
			activeFixData = nil
		end
	end
end


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

Internal.IndexedCategories = {
	-- The three "traditional" categories in which state is stored by index
	Internal.CATEGORY_RECIPE,
	Internal.CATEGORY_PLAN,
	Internal.CATEGORY_MOTIF,
}

Internal.ItemIdStores = {
	-- The keys by which item IDs are stored in the master list
	Internal.CATEGORY_RECIPE,
	Internal.CATEGORY_PLAN,
	Internal.CATEGORY_MOTIF,
	Internal.SCRIBE_GRIMOIRE,
	Internal.SCRIBE_SCRIPT,
}

Internal.DataStores = {
	-- The keys by which states are stored for each character
	Internal.CATEGORY_RECIPE,
	Internal.CATEGORY_PLAN,
	Internal.CATEGORY_MOTIF,
	Internal.CATEGORY_SCRIBING,
	Internal.CATEGORY_RESEARCH,
}

Internal.ScribingTypes = {
	[Internal.SCRIBE_GRIMOIRE] = {
		order = 1,
		know = IsCraftedAbilityUnlocked,
	},
	[Internal.SCRIBE_SCRIPT] = {
		order = 2,
		know = IsCraftedAbilityScriptUnlocked,
	},
}

Internal.KnowFunctions = {
	[Internal.CATEGORY_RECIPE] = IsItemLinkRecipeKnown,
	[Internal.CATEGORY_PLAN] = IsItemLinkRecipeKnown,
	[Internal.CATEGORY_MOTIF] = IsItemLinkBookKnown,
}

Internal.CategoryLabels = {
	[Internal.CATEGORY_RECIPE] = LocalizeString("<<1>>", GetString("SI_ITEMTYPE", ITEMTYPE_RECIPE)),
	[Internal.CATEGORY_PLAN] = LocalizeString("<<1>>", GetString("SI_PROVISIONERSPECIALINGREDIENTTYPE_TRADINGHOUSERECIPECATEGORY", PROVISIONER_SPECIAL_INGREDIENT_TYPE_FURNISHING)),
	[Internal.CATEGORY_MOTIF] = LocalizeString("<<1>>", GetString("SI_ITEMTYPE", ITEMTYPE_RACIAL_STYLE_MOTIF)),
	[Internal.CATEGORY_SCRIBING] = GetString(SI_SCRIBING_TITLE),
	[Internal.CATEGORY_RESEARCH] = GetString(SI_SMITHING_TAB_RESEARCH),
}

Internal.ItemQualityTranslation = {
	[ITEM_FUNCTIONAL_QUALITY_TRASH]     = Internal.QUALITY_LOW,
	[ITEM_FUNCTIONAL_QUALITY_NORMAL]    = Internal.QUALITY_LOW,
	[ITEM_FUNCTIONAL_QUALITY_MAGIC]     = Internal.QUALITY_LOW,
	[ITEM_FUNCTIONAL_QUALITY_ARCANE]    = Internal.QUALITY_MEDIUM,
	[ITEM_FUNCTIONAL_QUALITY_ARTIFACT]  = Internal.QUALITY_HIGH,
	[ITEM_FUNCTIONAL_QUALITY_LEGENDARY] = Internal.QUALITY_HIGH,
}

Internal.MotifAchievementCriterionIndexToChapterId = {
	ITEM_STYLE_CHAPTER_AXES,
	ITEM_STYLE_CHAPTER_BELTS,
	ITEM_STYLE_CHAPTER_BOOTS,
	ITEM_STYLE_CHAPTER_BOWS,
	ITEM_STYLE_CHAPTER_CHESTS,
	ITEM_STYLE_CHAPTER_DAGGERS,
	ITEM_STYLE_CHAPTER_GLOVES,
	ITEM_STYLE_CHAPTER_HELMETS,
	ITEM_STYLE_CHAPTER_LEGS,
	ITEM_STYLE_CHAPTER_MACES,
	ITEM_STYLE_CHAPTER_SHIELDS,
	ITEM_STYLE_CHAPTER_SHOULDERS,
	ITEM_STYLE_CHAPTER_STAVES,
	ITEM_STYLE_CHAPTER_SWORDS,
}

function Internal.Msg( text )
	CHAT_ROUTER:AddSystemMessage(text)
end

function Internal.MsgTag( text )
	CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", Internal.name, text))
end

function Internal.Chunk( data )
	return LCCC.Chunk(data, CHUNK_BYTES)
end

do
	local cache = { }

	function Internal.GetItemLink( itemId, cacheable )
		if (cache[itemId]) then
			return cache[itemId]
		else
			local itemLink = "|H0:item:" .. itemId .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
			if (cacheable) then
				cache[itemId] = itemLink
			end
			return itemLink
		end
	end
end

function Internal.GetCharRawData( server, charId, category )
	return Internal.characters[server] and Internal.characters[server][charId] and Internal.characters[server][charId][category]
end

function Internal.TranslateItem( item )
	local itemId, itemLink = 0, ""
	local styleId -- BOOKLESS

	if (type(item) == "number") then
		itemId, itemLink = item, Internal.GetItemLink(item)
	elseif (type(item) == "string") then
		itemId, itemLink = GetItemLinkItemId(item), item
	elseif (type(item) == "table") then
		-- BOOKLESS ------------------------------------------------------------
		if (type(item.styleId) == "number") then
			styleId = item.styleId
			local data = Internal.GetStyleMotifItems(styleId)
			if (data) then
				if (type(item.chapterId) == "number" and item.chapterId ~= ITEM_STYLE_CHAPTER_ALL) then
					itemId = data.chapters[item.chapterId] or itemId
				else
					itemId = data.books[1] or itemId
				end
			end
		end
		if (type(item.itemId) == "number") then itemId = item.itemId end
		if (type(item.itemLink) == "string") then itemLink = item.itemLink end
		if (itemId == 0 and itemLink ~= "") then
			itemId = GetItemLinkItemId(itemLink)
		elseif (itemId ~= 0 and itemLink == "") then
			itemLink = Internal.GetItemLink(itemId)
		end
		------------------------------------------------------------------------
	end

	return itemId, itemLink, styleId
end

function Internal.GetItemCategoryAndQuality( item )
	local itemId, itemLink, styleId = Internal.TranslateItem(item)
	local itemType, specializedItemType = GetItemLinkItemType(itemLink)

	if (itemType == ITEMTYPE_NONE) then
		if (styleId) then
			return Internal.CATEGORY_MOTIF, Internal.GetStyleQuality(styleId)
		else
			return Internal.CATEGORY_INVALID
		end
	elseif (itemType == ITEMTYPE_RECIPE) then
		local quality = Internal.ItemQualityTranslation[GetItemLinkFunctionalQuality(itemLink)]
		if (specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD or specializedItemType == SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK) then
			return Internal.CATEGORY_RECIPE, quality
		else
			return Internal.CATEGORY_PLAN, quality
		end
	elseif (itemType == ITEMTYPE_RACIAL_STYLE_MOTIF) then
		styleId = Internal.GetMotifStyleAndChapter(itemId)
		return Internal.CATEGORY_MOTIF, Internal.GetStyleQuality(styleId)
	elseif (itemType == ITEMTYPE_CRAFTED_ABILITY or itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT) then
		-- The "quality" of a scribing item is just where it fits in
		local refId = GetItemLinkItemUseReferenceId(itemLink)
		if (refId > 0) then
			if (itemType == ITEMTYPE_CRAFTED_ABILITY) then
				-- Grimoire
				return Internal.CATEGORY_SCRIBING, SCRIBING_SLOT_NONE, { itemLink, refId }
			else
				-- Script
				return Internal.CATEGORY_SCRIBING, GetCraftedAbilityScriptScribingSlot(refId), { itemLink, refId }
			end
		end
	end

	return Internal.CATEGORY_NONE
end

function Internal.GetMasterListParam( key )
	if (Internal.vars.masterList and type(Internal.vars.masterList[key]) == "number") then
		return Internal.vars.masterList[key]
	else
		return -1
	end
end

function Internal.CanSave( account )
	if (Internal.vars.noSave and Internal.vars.noSave[zo_strlower(account or Internal.userId)]) then
		return false
	else
		return true
	end
end

local function IsSet( value )
	return value ~= nil and value ~= 0
end

function Internal.IsCharacterEnabled( server, charId )
	local result
	local char = Internal.characters[server] and Internal.characters[server][charId]
	if (char) then
		result = char.settings and char.settings.enabled
		if (not IsSet(result)) then
			local account = Internal.accounts[server] and Internal.accounts[server][char.account]
			result = account and account.enabled
		end
	end
	return result ~= 2
end

function Internal.GetEffectiveParameterValue( server, charId, param )
	local char = Internal.characters[server] and Internal.characters[server][charId]
	if (char) then
		if (char.settings and IsSet(char.settings[param])) then
			return char.settings[param]
		elseif (Internal.accounts[server]) then
			local account = Internal.accounts[server][char.account] or Internal.accounts[server].defaults
			if (account and IsSet(account[param])) then
				return account[param]
			end
		end
	end
	return Internal.vars.defaults[param]
end

function Internal.GetCharacterParams( server, charId )
	local results
	local char = Internal.characters[server] and Internal.characters[server][charId]
	if (char) then
		results = {
			enabled = Internal.IsCharacterEnabled(server, charId),
			priority = Internal.GetEffectiveParameterValue(server, charId, "priority"),
			tracking = { },
		}
		for _, category in ipairs(Internal.DataStores) do
			results.tracking[category] = Internal.GetEffectiveParameterValue(server, charId, category)
		end
	end
	return results
end

function Internal.Sort( server, charIds, usePriority )
	if (usePriority) then
		table.sort(charIds, function( a, b )
			local pa = Internal.GetEffectiveParameterValue(server, a, "priority")
			local pb = Internal.GetEffectiveParameterValue(server, b, "priority")
			if (pa == pb) then
				return LCCC.CompareCharIds(a, b)
			else
				return pa < pb
			end
		end)
	else
		table.sort(charIds, LCCC.CompareCharIds)
	end
end

function Internal.AccountFilter( accountFilter, character )
	if (not accountFilter) then
		return true
	elseif (type(accountFilter) == "string") then
		return accountFilter == character.account
	elseif (type(accountFilter) == "table") then
		return accountFilter[character.account]
	end
end

function Internal.NotifyRefresh( invalidateCharacterList )
	if (invalidateCharacterList) then
		Internal.cachedFilteredServerList = nil
		ZO_ClearTable(Internal.cachedCharLists)
	end
	Internal.FireCallbacks(Public.EVENT_UPDATE_REFRESH, invalidateCharacterList)
end

function Internal.CheckVengeanceState( )
	Internal.isInVengeance = IsCurrentCampaignVengeanceRuleset()
	if (Internal.pendingVengeanceScan and not Internal.isInVengeance) then
		Internal.pendingVengeanceScan = false
		Internal.RefreshKnowledge()
	end
end

do
	local buffer = { }
	function Internal.GetScratchBuffer( wantMerged )
		local result = wantMerged and table.concat(buffer, "") or buffer
		ZO_ClearTable(buffer)
		return result
	end
end


--------------------------------------------------------------------------------
-- Motif Associations
--------------------------------------------------------------------------------

function Internal.LoadMotifData( )
	Internal.motifAssociations = {
		motifs = { },
		styles = { },
		styleIds = { },
	}
	local data = Internal.motifAssociations
	local blacklist = Internal.InvalidIds
	local indexToChapterId = Internal.MotifAchievementCriterionIndexToChapterId

	-- Associate style and chapter IDs with motif item IDs
	local FIELD_ITEM_ID = 3 -- 18 bits: 0-17 = itemId
	local FIELD_PAYLOAD = 2 -- 12 bits: 0-3 = chapterId, 4-11 = styleId

	local encoded = Internal.MotifData
	local length = zo_strlen(encoded)
	local itemId, payload
	local i = 1
	while (i < length) do
		itemId, i = LCCC.ReadAndDecode(encoded, i, FIELD_ITEM_ID)
		payload, i = LCCC.ReadAndDecode(encoded, i, FIELD_PAYLOAD)

		local chapterId = payload % 0x10
		local styleId = BitRShift(payload, 4)

		data.motifs[itemId] = { styleId, chapterId }

		if (not blacklist[itemId]) then
			if (not data.styles[styleId]) then
				data.styles[styleId] = {
					books = { },
					chapters = { },
				}
			end

			if (chapterId == ITEM_STYLE_CHAPTER_ALL) then
				table.insert(data.styles[styleId].books, itemId)
			else
				data.styles[styleId].chapters[chapterId] = itemId
			end
		end
	end

	-- Associate motif numbers, crown-exclusive status, and achievement IDs with style IDs
	local FIELD_STYLEDATA = 5 -- 30 bits: 0-7 = styleId, 8-15 = number, 16 = crown, 17-29 = achievementId
	local FIELD_BOOKDATA = 4 -- 24 bits: 0-13 = bookId, 14-21 = offsetToFirstChapterBookId (signed), 22-23 = unused

	encoded = Internal.StyleData
	length = zo_strlen(encoded)
	i = 1
	while (i < length) do
		payload, i = LCCC.ReadAndDecode(encoded, i, FIELD_STYLEDATA)
		local style = data.styles[payload % 0x100]
		style.number = BitRShift(payload, 8) % 0x100
		style.crown = BitRShift(payload, 16) == 1
		style.achievementId = BitRShift(payload, 17) % 0x2000

		payload, i = LCCC.ReadAndDecode(encoded, i, FIELD_BOOKDATA)
		local bookId = payload % 0x4000
		local offset = BitRShift(payload, 14) % 0x100
		local bookIds = { [ITEM_STYLE_CHAPTER_ALL] = bookId }
		if (offset ~= 0) then
			if (offset > 0x80) then
				-- Since offset is 8-bit signed, need to extend it to a larger width if negative
				offset = offset + 0xFF00
			end
			local base = (bookId + offset) % 0x10000 - 1
			for i = 1, 14 do
			 	bookIds[indexToChapterId[i]] = base + i
			end
		end
		style.bookIds = bookIds
	end

	-- Build list of valid style IDs, omitting ones that were mined from a future patch and are not active in the current patch
	for styleId, style in pairs(data.styles) do
		if (Internal.GetItemCategoryAndQuality(style.books[1] or style.chapters[ITEM_STYLE_CHAPTER_CHESTS]) == Internal.CATEGORY_MOTIF) then
			table.insert(data.styleIds, styleId)
		end
	end
	table.sort(data.styleIds)
end

function Internal.GetMotifStyleAndChapter( itemId, _, styleId )
	-- Returns styleId, chapterId
	local data = Internal.motifAssociations
	if (data and data.motifs[itemId]) then
		return unpack(data.motifs[itemId])
	elseif (data and styleId) then -- BOOKLESS
		return styleId, ITEM_STYLE_CHAPTER_ALL
	else
		return 0, 0
	end
end

function Internal.GetStyleIds( )
	local data = Internal.motifAssociations
	return data and data.styleIds
end

function Internal.GetStyleMotifItems( styleId )
	local data = Internal.motifAssociations
	return data and data.styles[styleId]
end

function Internal.GetStyleQuality( styleId )
	return Internal.StyleQuality[styleId] or Internal.QUALITY_HIGH
end

-- Used only for LCK_MotifDataTool; do not call
function Public.InternalUseOnly_GetRawMotifIds( )
	return Internal.ids[Internal.CATEGORY_MOTIF]
end


--------------------------------------------------------------------------------
-- Initialization 1
--------------------------------------------------------------------------------

function Internal.Initialize( )
	Diagnostics.Stopwatch(true)

	-- Schedule the settings panel initialization
	Public.RegisterForCallback(Internal.name, Public.EVENT_INITIALIZED, Internal.RegisterSettingsPanel)

	-- Initialize data store
	if (not LibCharacterKnowledgeData or LibCharacterKnowledgeData.formatVersion ~= Internal.FORMAT_VERSION) then
		LibCharacterKnowledgeData = {
			formatVersion = Internal.FORMAT_VERSION,
		}
	end
	Internal.vars = LibCharacterKnowledgeData

	-- Diagnostics
	if (not Internal.vars.diagnostics) then
		Internal.vars.diagnostics = { }
	end
	Diagnostics.vars = Internal.vars.diagnostics

	-- Default settings
	if (not Internal.vars.defaults) then
		Internal.vars.defaults = {
			[Internal.CATEGORY_RECIPE] = 4,
			[Internal.CATEGORY_PLAN] = 4,
			[Internal.CATEGORY_MOTIF] = 4,
			[Internal.CATEGORY_SCRIBING] = 2,
			[Internal.CATEGORY_RESEARCH] = 2,
			priority = Internal.PRIORITY_RANK_DEFAULT,
		}
	end

	if (not Internal.vars.defaults[Internal.CATEGORY_SCRIBING]) then
		Internal.vars.defaults[Internal.CATEGORY_SCRIBING] = 2
	end

	if (not Internal.vars.defaults[Internal.CATEGORY_RESEARCH]) then
		Internal.vars.defaults[Internal.CATEGORY_RESEARCH] = 2
	end

	-- Initialize account and character sections
	for _, key in ipairs({ "accounts", "characters" }) do
		if (not Internal.vars[key]) then
			Internal.vars[key] = { }
		end
		if (not Internal.vars[key][Internal.server]) then
			Internal.vars[key][Internal.server] = { }
		end
		Internal[key] = Internal.vars[key]
	end

	-- Load motif associations
	Internal.LoadMotifData()

	-- Indices for decoding should be initialized on demand
	setmetatable(Internal.decoderIndices, { __index = function( tbl, key )
		local ids = Internal.ids[key]
		if (ids) then
			local results = { }
			for i, id in ipairs(ids) do
				results[id] = i
			end
			tbl[key] = results
			return results
		end
	end })

	Internal.InitializeMasterList()
end


--------------------------------------------------------------------------------
-- Initialization 2: Master List
--------------------------------------------------------------------------------

function Internal.InitializeMasterList( )
	Diagnostics.Stopwatch()

	if (Internal.GetMasterListParam("api") > 0 and Internal.GetMasterListParam("fieldSize") > 0) then
		-- Existing master list, but we don't know yet if it's current

		-- Load scribing max IDs (also checks if scribing data exists)
		local validScribingIds = Internal.ReadMasterListScribingMaxIds()

		if (Internal.GetMasterListParam("api") == GetAPIVersion() and not Internal.DoesNewerBaseDataExist() and validScribingIds) then
			-- List is current
			Internal.LoadMasterList(Internal.ids)
			Internal.InitializeCharacterData()
		else
			-- List is outdated; get old indices before getting new list
			Internal.oldIndices = { }
			Internal.LoadMasterList(Internal.oldIndices, true)
			Internal.AcquireNewMasterList()
		end
	else
		-- Master list not found
		Internal.AcquireNewMasterList()
	end
end

function Internal.ReadMasterListScribingMaxIds( )
	local valid = true
	for key in pairs(Internal.ScribingTypes) do
		Internal.maxIds[key] = Internal.GetMasterListParam("maxId_" .. key)
		if (Internal.maxIds[key] <= 0) then
			valid = false
		end
	end
	return valid
end

do
	local itemIndex

	local function ReadMasterListLine( line, fieldSize, results )
		local length = zo_strlen(line)
		local pos, itemId = 1
		while (pos < length) do
			itemId, pos = LCCC.ReadAndDecode(line, pos, fieldSize)
			if (itemIndex) then
				results[itemId] = itemIndex
				itemIndex = itemIndex + 1
			else
				table.insert(results, itemId)
			end
		end
	end

	function Internal.LoadMasterList( store, reverseLookup )
		local fieldSize = Internal.GetMasterListParam("fieldSize")

		for _, category in ipairs(Internal[reverseLookup and "IndexedCategories" or "ItemIdStores"]) do
			itemIndex = reverseLookup and 1 or nil
			local encoded = Internal.vars.masterList[category]
			local results = { }
			if (type(encoded) == "table") then
				for _, line in ipairs(encoded) do
					ReadMasterListLine(line, fieldSize, results)
				end
			elseif (type(encoded) == "string") then
				ReadMasterListLine(encoded, fieldSize, results)
			end
			store[category] = results
		end
	end
end

function Internal.AcquireNewMasterList( )
	Internal.MsgTag(GetString(SI_LCK_SCAN_START))

	if (Internal.DoesValidBaseDataExist()) then
		local data = Internal.BaseData.get()
		data.api = Internal.BaseData.api
		data.timestamp = Internal.BaseData.timestamp
		Internal.vars.masterList = data
		Internal.ReadMasterListScribingMaxIds()
		Internal.LoadMasterList(Internal.ids)
		return Internal.FinalizeNewMasterList()
	elseif (IsConsoleUI()) then
		Internal.MsgTag(GetString(SI_LCK_SCAN_CONSOLE))
		return Diagnostics.LogTime("initialization")
	end

	local BLOCK_SIZE = 10000 -- Block size

	for _, category in ipairs(Internal.ItemIdStores) do
		Internal.ids[category] = { }
	end

	-- Pre-zero the scribing tables to account for any gaps in the IDs
	for key, data in pairs(Internal.ScribingTypes) do
		Internal.maxIds[key] = data.max()
		for i = 1, Internal.maxIds[key] do
			Internal.ids[key][i] = 0
		end
	end

	local startId = 1
	local invalidCount = 0
	local lastValidId = 0

	EVENT_MANAGER:RegisterForUpdate(Internal.name, Internal.scanThrottle, function( )
		local stopId = startId + BLOCK_SIZE
		for i = startId, stopId - 1 do
			local category, quality, data = Internal.GetItemCategoryAndQuality(i)
			if (category == Internal.CATEGORY_INVALID) then
				invalidCount = invalidCount + 1
				if (invalidCount == BLOCK_SIZE) then
					-- Conclude the scan when we see a very large number of consecutive invalid items (highest observed: 4515)
					EVENT_MANAGER:UnregisterForUpdate(Internal.name)
					return Internal.WriteMasterList(lastValidId)
				end
			else
				invalidCount = 0
				lastValidId = i
				if (category == Internal.CATEGORY_SCRIBING) then
					local tbl = Internal.ids[Internal[(quality == SCRIBING_SLOT_NONE) and "SCRIBE_GRIMOIRE" or "SCRIBE_SCRIPT"]]
					local bindType = GetItemLinkBindType(data[1])
					if (tbl[data[2]] == 0 or (bindType ~= BIND_TYPE_ON_PICKUP and bindType ~= BIND_TYPE_ON_PICKUP_BACKPACK)) then
						tbl[data[2]] = i
					end
				elseif (category ~= Internal.CATEGORY_NONE) then
					table.insert(Internal.ids[category], i)
				end
			end
		end
		startId = stopId
	end)
end

function Internal.WriteMasterList( maxId )
	local fieldSize = zo_ceil(math.log(maxId) / math.log(64))

	Internal.vars.masterList = {
		api = GetAPIVersion(),
		fieldSize = fieldSize,
		timestamp = GetTimeStamp(),
	}

	for _, category in ipairs(Internal.ItemIdStores) do
		local encoded = Internal.GetScratchBuffer()
		for _, id in ipairs(Internal.ids[category]) do
			table.insert(encoded, LCCC.Encode(id, fieldSize))
		end
		Internal.vars.masterList[category] = Internal.Chunk(Internal.GetScratchBuffer(true))
	end

	-- Save scribing max IDs
	for key in pairs(Internal.ScribingTypes) do
		Internal.vars.masterList["maxId_" .. key] = Internal.maxIds[key]
	end

	Internal.FinalizeNewMasterList()
end

function Internal.FinalizeNewMasterList( )
	Diagnostics.vars.masterList = { }
	for _, category in ipairs(Internal.IndexedCategories) do
		Diagnostics.vars.masterList[category] = #Internal.ids[category]
	end

	-- Migrate data
	if (Internal.oldIndices) then
		for server, characters in pairs(Internal.characters) do
			for charId, data in pairs(characters) do
				for _, category in ipairs(Internal.IndexedCategories) do
					if (data[category]) then
						data[category] = Internal.IndexedScanAndEncode(category, server, charId, Internal.oldIndices)
					end
				end
			end
		end
		Internal.oldIndices = nil
	end

	Internal.MsgTag(GetString(SI_LCK_SCAN_COMPLETE))
	Internal.InitializeCharacterData()
end

function Internal.DoesValidBaseDataExist( )
	return type(Internal.BaseData) == "table" and Internal.BaseData.api == GetAPIVersion()
end

function Internal.DoesNewerBaseDataExist( )
	return Internal.DoesValidBaseDataExist() and type(Internal.BaseData.timestamp) == "number" and Internal.BaseData.timestamp > Internal.GetMasterListParam("timestamp")
end


--------------------------------------------------------------------------------
-- Initialization 3: Accounts and Characters
--------------------------------------------------------------------------------

function Internal.InitializeCharacterData( )
	Diagnostics.Stopwatch()

	local charactersLocal = Internal.characters[Internal.server]
	local exists = { }

	-- Create entries for every character on the account
	if (Internal.CanSave()) then
		for i = 1, GetNumCharacters() do
			local name, _, _, _, _, _, id = GetCharacterInfo(i)
			if (not charactersLocal[id]) then
				charactersLocal[id] = { }
			end
			charactersLocal[id].account = Internal.userId
			charactersLocal[id].name = LocalizeString("<<1>>", name)
			exists[id] = true
		end
	end

	-- Delete characters that no longer exist or are on the no-save list
	for id, data in pairs(charactersLocal) do
		if ((data.account == Internal.userId and not exists[id]) or not Internal.CanSave(data.account)) then
			charactersLocal[id] = nil
		end
	end

	-- Initial scan
	Internal.CheckVengeanceState()
	Internal.ScanKnowledge()

	-- Listen for changes
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_MULTIPLE_RECIPES_LEARNED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_RECIPE_LEARNED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_STYLE_LEARNED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_CRAFTED_ABILITY_LOCK_STATE_CHANGED, function(_, _, _, isFromInit) if (not isFromInit) then Internal.RefreshKnowledge() end end)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED, Internal.RefreshKnowledge)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_SKILL_RESPEC_RESULT, function(_, result) if (result == RESPEC_RESULT_SUCCESS and Internal.ResearchCheckPassives()) then Internal.RefreshKnowledge() end end)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function(_, result) if (result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS and Internal.ResearchCheckPassives()) then Internal.RefreshKnowledge() end end)
	EVENT_MANAGER:RegisterForEvent(Internal.name, EVENT_PLAYER_ACTIVATED, Internal.CheckVengeanceState)
end


--------------------------------------------------------------------------------
-- Aggregators for Scanning and Retrieval
--------------------------------------------------------------------------------

function Internal.RefreshKnowledge( )
	EVENT_MANAGER:UnregisterForUpdate(Internal.name)
	EVENT_MANAGER:RegisterForUpdate(Internal.name, Internal.scanThrottle, Internal.ScanKnowledge, true)
end

function Internal.ScanKnowledge( )
	if (Internal.initialized) then
		Diagnostics.Stopwatch(true)
	end

	if (Internal.isInVengeance) then
		Internal.pendingVengeanceScan = true
	elseif (Internal.CanSave()) then
		MotifFixer.Init()
		local charData = Internal.characters[Internal.server][Internal.charId]
		for _, category in ipairs(Internal.IndexedCategories) do
			charData[category] = Internal.IndexedScanAndEncode(category)
		end
		charData[Internal.CATEGORY_SCRIBING] = Internal.ScribingScanAndEncode()
		charData[Internal.CATEGORY_RESEARCH] = Internal.ResearchScanAndEncode()
		charData.timestamp = GetTimeStamp()
		MotifFixer.ApplyFixes()
	end

	if (not Internal.initialized) then
		Internal.initialized = true
		Diagnostics.Stopwatch()
		Internal.FireCallbacks(Public.EVENT_INITIALIZED)
		Diagnostics.LogTime("initialization")
	else
		Internal.NotifyRefresh(false)
		Diagnostics.LogTime("refresh")
	end
end

function Internal.GetItemKnowledge( server, charId, category, itemId, itemLink, styleId )
	if (itemId == 0 and styleId) then
		-- BOOKLESS ------------------------------------------------------------
		local data = Internal.GetStyleMotifItems(styleId)
		if (data and #data.chapters > 0) then
			for _, chapter in ipairs(data.chapters) do
				local result = Internal.GetItemKnowledge(server, charId, category, Internal.TranslateItem(chapter))
				if (result ~= Internal.KNOWLEDGE_KNOWN) then
					return result
				end
			end
			return Internal.KNOWLEDGE_KNOWN
		else
			return Internal.KNOWLEDGE_INVALID
		end
		------------------------------------------------------------------------
	elseif (category == Internal.CATEGORY_SCRIBING) then
		return Internal.ScribingGetKnowledge(
			server,
			charId,
			Internal[(GetItemLinkItemType(itemLink) == ITEMTYPE_CRAFTED_ABILITY) and "SCRIBE_GRIMOIRE" or "SCRIBE_SCRIPT"],
			GetItemLinkItemUseReferenceId(itemLink)
		)
	elseif (category) then
		local fallback = Internal.KNOWLEDGE_NODATA

		-- Use direct determination if possible since there is a scan delay when
		-- learning new items
		if ((not server or server == Internal.server) and charId == Internal.charId and not Internal.isInVengeance) then
			if (Internal.KnowFunctions[category](itemLink)) then
				return Internal.KNOWLEDGE_KNOWN
			elseif (category ~= Internal.CATEGORY_MOTIF) then
				return Internal.KNOWLEDGE_UNKNOWN
			else
				-- The motif book bug makes the unknown status unreliable
				fallback = Internal.KNOWLEDGE_UNKNOWN
			end
		end

		-- Use internal data for all other scenarios
		local result = Internal.IndexedGetKnowledge(server, charId, category, itemId)
		if (result == nil) then
			return fallback
		elseif (result) then
			return Internal.KNOWLEDGE_KNOWN
		else
			return Internal.KNOWLEDGE_UNKNOWN
		end
	else
		-- Either CATEGORY_NONE or CATEGORY_INVALID
		return Internal.KNOWLEDGE_INVALID
	end
end


--------------------------------------------------------------------------------
-- Indexed Categories: Recipes, Furnishing Plans, Motifs
--------------------------------------------------------------------------------

function Internal.IndexedScanAndEncode( category, server, charId, oldIndices )
	-- server, charId, and oldIndices are used only for version migration

	-- Special handling for the motif book bug
	local isMotif = category == Internal.CATEGORY_MOTIF and not oldIndices

	local knowFunc
	if (oldIndices) then
		knowFunc = function(id) return Internal.IndexedGetKnowledge(server, charId, category, id, nil, oldIndices) end
	else
		local baseKnowFunc = Internal.KnowFunctions[category]
		knowFunc = function(id) return baseKnowFunc(Internal.GetItemLink(id, true)) end
	end

	local field = 0
	local fields = Internal.GetScratchBuffer()

	for i, id in ipairs(Internal.ids[category]) do
		field = field * 2

		if (knowFunc(id)) then
			field = field + 1
			if (isMotif) then MotifFixer.RecordKnownStyle(id) end
		elseif (isMotif) then
			field = field + MotifFixer.HandleUnknownStyle(id, i)
		end

		if (i % BLOCK_BITS == 0) then
			table.insert(fields, LCCC.Encode(field, BLOCK_BYTES))
			field = 0
		end
	end

	local remainder = #Internal.ids[category] % BLOCK_BITS
	if (remainder > 0) then
		table.insert(fields, LCCC.Encode(BitLShift(field, BLOCK_BITS - remainder), BLOCK_BYTES))
	end

	return Internal.Chunk(Internal.GetScratchBuffer(true))
end

function Internal.IndexedGetKnowledge( server, charId, category, itemId, itemIndex, decoderIndices )
	local data = Internal.GetCharRawData(server, charId, category)
	if (data) then
		if (not itemIndex) then
			decoderIndices = decoderIndices or Internal.decoderIndices
			itemIndex = decoderIndices[category] and decoderIndices[category][itemId]
		end
		if (itemIndex) then
			return LCCC.ReadBitFromEncodedData(data, itemIndex, CHUNK_BITS)
		end
	end
	return nil
end


--------------------------------------------------------------------------------
-- Scribing
--------------------------------------------------------------------------------

function Internal.ScribingScanAndEncode( )
	local results = { }

	for key, data in pairs(Internal.ScribingTypes) do
		local result = ""

		-- Pad the scan sequence as needed
		local maxId = zo_ceil(Internal.maxIds[key] / ENCODE_BITS) * ENCODE_BITS

		-- Scan and encode
		local field = 0
		for currentId = 1, maxId do
			field = field * 2
			if (data.know(currentId)) then
				field = field + 1
			end
			if (currentId % ENCODE_BITS == 0) then
				result = result .. LCCC.Encode(field, 1)
				field = 0
			end
		end

		results[data.order] = result
	end

	return table.concat(results, ":")
end

function Internal.ScribingGetKnowledge( server, charId, key, id )
	server = server or Internal.server
	charId = charId or Internal.charId
	if (server == Internal.server and charId == Internal.charId and not Internal.isInVengeance) then
		-- Return the result directly from the API
		if (Internal.ScribingTypes[key].know(id)) then
			return Internal.KNOWLEDGE_KNOWN
		else
			return Internal.KNOWLEDGE_UNKNOWN
		end
	else
		local data = Internal.GetCharRawData(server, charId, Internal.CATEGORY_SCRIBING)
		local valid, offset = zo_plainstrfind(data, ":")
		if (not valid) then
			return Internal.KNOWLEDGE_NODATA
		else
			local order = Internal.ScribingTypes[key].order
			if (order == 1 and id > (offset - 1) * ENCODE_BITS) then
				-- Out of bounds: don't let it read past the delimiter
				id = 0
			elseif (order == 2) then
				id = id + offset * ENCODE_BITS
			end
			if (LCCC.ReadBitFromEncodedData(data, id)) then
				return Internal.KNOWLEDGE_KNOWN
			else
				return Internal.KNOWLEDGE_UNKNOWN
			end
		end
	end
end

do
	local function GetMaxScribingId( checkFn, checkRet )
		local MAX_CONSECUTIVE_INVALID_IDS = 10
		local currentId = 1
		local invalidCount = 0
		local lastValidId = 0

		repeat
			if (checkFn(currentId) == checkRet) then
				invalidCount = invalidCount + 1
			else
				invalidCount = 0
				lastValidId = currentId
			end
			currentId = currentId + 1
		until invalidCount >= MAX_CONSECUTIVE_INVALID_IDS

		return lastValidId
	end

	Internal.ScribingTypes[Internal.SCRIBE_GRIMOIRE].max = function( )
		-- Could use GetNumCraftedAbilities instead, but it's unclear how it would handle gaps in the IDs should any arise in the future
		return GetMaxScribingId(GetSkillTypeForCraftedAbilityId, SKILL_TYPE_NONE)
	end

	Internal.ScribingTypes[Internal.SCRIBE_SCRIPT].max = function( )
		return GetMaxScribingId(GetCraftedAbilityScriptScribingSlot, SCRIBING_SLOT_NONE)
	end
end


--------------------------------------------------------------------------------
-- Research
-- 54 bytes: trait knowledge (324b)
-- 1 byte: number of extra slots (so 0-2, not 1-3) for non-jewelry (2b each)
-- 10 bytes: each active research slot (12b index, 24b duration, 24b remaining)
--------------------------------------------------------------------------------

do
	local TraitBytes = nil -- Also doubles as initialization check

	-- For traits currently being researched
	local TIME_INDEX_SIZE = 2
	local TIME_FIELD_SIZE = 4
	local TIME_TOTAL_SIZE = 10

	local TRADESKILL_LOOKUP, TRADESKILL_REVERSE_LOOKUP
	Internal.TRADESKILL_TYPES = {
		CRAFTING_TYPE_BLACKSMITHING,
		CRAFTING_TYPE_CLOTHIER,
		CRAFTING_TYPE_WOODWORKING,
		CRAFTING_TYPE_JEWELRYCRAFTING,
	}

	-- Used for ResearchGetIndicesFromItemLink
	local ITEM_LOOKUPS = {
		EQUIP = {
			[EQUIP_TYPE_CHEST] = 1,
			[EQUIP_TYPE_FEET] = 2,
			[EQUIP_TYPE_HAND] = 3,
			[EQUIP_TYPE_HEAD] = 4,
			[EQUIP_TYPE_LEGS] = 5,
			[EQUIP_TYPE_SHOULDERS] = 6,
			[EQUIP_TYPE_WAIST] = 7,
			[EQUIP_TYPE_RING] = 1,
			[EQUIP_TYPE_NECK] = 2,
			[EQUIP_TYPE_MAIN_HAND] = -1,
			[EQUIP_TYPE_OFF_HAND] = -1,
			[EQUIP_TYPE_ONE_HAND] = -1,
			[EQUIP_TYPE_TWO_HAND] = -1,
		},
		WEAPON = {
			[WEAPONTYPE_AXE] = 1,
			[WEAPONTYPE_HAMMER] = 2,
			[WEAPONTYPE_SWORD] = 3,
			[WEAPONTYPE_TWO_HANDED_AXE] = 4,
			[WEAPONTYPE_TWO_HANDED_HAMMER] = 5,
			[WEAPONTYPE_TWO_HANDED_SWORD] = 6,
			[WEAPONTYPE_DAGGER] = 7,
			[WEAPONTYPE_BOW] = 1,
			[WEAPONTYPE_FIRE_STAFF] = 2,
			[WEAPONTYPE_FROST_STAFF] = 3,
			[WEAPONTYPE_LIGHTNING_STAFF] = 4,
			[WEAPONTYPE_HEALING_STAFF] = 5,
			[WEAPONTYPE_SHIELD] = 6,
		},
		TRAIT = {
			[ITEM_TRAIT_TYPE_ARMOR_STURDY] = 1,
			[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 2,
			[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 3,
			[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 4,
			[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 5,
			[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 6,
			[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 7,
			[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 8,
			[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 9,
			[ITEM_TRAIT_TYPE_WEAPON_POWERED] = 1,
			[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 2,
			[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 3,
			[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 4,
			[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 5,
			[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 6,
			[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 7,
			[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 8,
			[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 9,
			[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 1,
			[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 2,
			[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 3,
			[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 4,
			[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = 5,
			[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 6,
			[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 7,
			[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 8,
			[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 9,
		},
		ARMOR_OFFSET = {
			[ARMORTYPE_MEDIUM] = 7,
			[ARMORTYPE_HEAVY] = 7,
		},
	}

	-- Initialization does two things:
	-- 1/ Build a lookup table to map a specific trait to a bitfield index
	-- 2/ Since research uses indices with no corresponding IDs and indices are
	--    not guaranteed to be stable (e.g., that time when rings and necks were
	--    swapped), build a signature tripwire to hopefully catch changes early
	local function InitializeResearch( )
		if (TraitBytes) then return end

		local index = 0
		local signature = { }
		TRADESKILL_LOOKUP = { }
		TRADESKILL_REVERSE_LOOKUP = { }

		-- Build lookup table, gather signature data
		for i, craftingSkillType in ipairs(Internal.TRADESKILL_TYPES) do
			TRADESKILL_LOOKUP[craftingSkillType] = { slotsShift = (i - 1) * 2 }

			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				TRADESKILL_LOOKUP[craftingSkillType][researchLineIndex] = { }

				local _, icon, numTraits = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
				table.insert(signature, icon)
				table.insert(signature, numTraits)

				for traitIndex = 1, numTraits do
					index = index + 1
					TRADESKILL_LOOKUP[craftingSkillType][researchLineIndex][traitIndex] = index
					TRADESKILL_REVERSE_LOOKUP[index] = {
						craftingSkillType = craftingSkillType,
						researchLineIndex = researchLineIndex,
						traitIndex = traitIndex,
					}
				end
			end
		end

		-- Check trait count
		if (Diagnostics.vars.researchTraits ~= index) then
			if (Diagnostics.vars.researchTraits) then
				Internal.MsgTag(GetString(SI_LCK_SCAN_RESEARCH_BAD_TRAITS))
			end
			Diagnostics.vars.researchTraits = index
		end

		-- Check signature
		signature = HashString(table.concat(signature, ","))
		if (Diagnostics.vars.researchSignature ~= signature) then
			if (Diagnostics.vars.researchSignature) then
				Internal.MsgTag(GetString(SI_LCK_SCAN_RESEARCH_BAD_SIG))
			end
			Diagnostics.vars.researchSignature = signature
		end

		-- Total bytes devoted to traits
		TraitBytes = zo_ceil(index / BLOCK_BITS) * BLOCK_BYTES
	end

	local function GetTraitIndex( craftingSkillType, researchLineIndex, traitIndex )
		InitializeResearch()
		return craftingSkillType and researchLineIndex and traitIndex and TRADESKILL_LOOKUP[craftingSkillType] and TRADESKILL_LOOKUP[craftingSkillType][researchLineIndex] and TRADESKILL_LOOKUP[craftingSkillType][researchLineIndex][traitIndex]
	end

	function Internal.ResearchScanAndEncode( )
		InitializeResearch()

		Internal.ResearchCheckPassives()

		local index = 0
		local field = 0
		local slots = 0
		local times = { }
		local result = ""

		for i, craftingSkillType in ipairs(Internal.TRADESKILL_TYPES) do
			for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
				for traitIndex = 1, select(3, GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)) do
					index = index + 1

					field = field * 2
					if (select(3, GetSmithingResearchLineTraitInfo(craftingSkillType, researchLineIndex, traitIndex))) then
						field = field + 1
					end
					if (index % BLOCK_BITS == 0) then
						result = result .. LCCC.Encode(field, BLOCK_BYTES)
						field = 0
					end

					local duration, timeRemainingSecs = GetSmithingResearchLineTraitTimes(craftingSkillType, researchLineIndex, traitIndex)
					if (duration and timeRemainingSecs) then
						table.insert(times, LCCC.Encode(index, TIME_INDEX_SIZE) .. LCCC.Encode(duration, TIME_FIELD_SIZE) .. LCCC.Encode(timeRemainingSecs, TIME_FIELD_SIZE))
					end
				end
			end

			local shift = TRADESKILL_LOOKUP[craftingSkillType].slotsShift
			if (shift <= 4) then
				slots = BitOr(BitLShift(BitAnd(GetMaxSimultaneousSmithingResearch(craftingSkillType) - 1, 3), shift), slots)
			end
		end

		local remainder = index % BLOCK_BITS
		if (remainder > 0) then
			-- This should never run unless new traits are added to the game
			result = result .. LCCC.Encode(BitLShift(field, BLOCK_BITS - remainder), BLOCK_BYTES)
		end

		return result .. LCCC.Encode(slots, 1) .. table.concat(times, "")
	end

	function Internal.ResearchGetTraitKnowledge( server, charId, ... )
		server = server or Internal.server
		charId = charId or Internal.charId
		if (server == Internal.server and charId == Internal.charId and not Internal.isInVengeance) then
			-- Return the result directly from the API
			if (select(3, GetSmithingResearchLineTraitInfo(...))) then
				return Internal.KNOWLEDGE_KNOWN
			else
				return Internal.KNOWLEDGE_UNKNOWN
			end
		else
			local data = Internal.GetCharRawData(server, charId, Internal.CATEGORY_RESEARCH)
			if (not data) then
				return Internal.KNOWLEDGE_NODATA
			else
				local index = GetTraitIndex(...)
				if (not index) then
					return Internal.KNOWLEDGE_INVALID
				elseif (LCCC.ReadBitFromEncodedData(data, index)) then
					return Internal.KNOWLEDGE_KNOWN
				else
					return Internal.KNOWLEDGE_UNKNOWN
				end
			end
		end
	end

	function Internal.ResearchGetMaxSlots( server, charId, craftingSkillType )
		server = server or Internal.server
		charId = charId or Internal.charId
		if (server == Internal.server and charId == Internal.charId and not Internal.isInVengeance) then
			-- Return the result directly from the API
			return GetMaxSimultaneousSmithingResearch(craftingSkillType)
		else
			local shift = craftingSkillType and TRADESKILL_LOOKUP[craftingSkillType] and TRADESKILL_LOOKUP[craftingSkillType].slotsShift
			if (not shift) then
				return 0 -- Invalid craft
			elseif (shift > 4) then
				return 1 -- Jewelry
			else
				local data = Internal.GetCharRawData(server, charId, Internal.CATEGORY_RESEARCH)
				if (data) then
					InitializeResearch()
					return BitAnd(BitRShift(LCCC.ReadAndDecode(data, TraitBytes + 1, 1), shift), 3) + 1
				else
					return 1
				end
			end
		end
	end

	function Internal.ReadResearchTimes( server, charId, index )
		-- Returns single result matching index, or table of all results if index is nil
		local results = (not index) and { } or nil
		local data = Internal.GetCharRawData(server, charId, Internal.CATEGORY_RESEARCH)
		if (data) then
			local length = zo_strlen(data)
			local pos = TraitBytes + 2
			local field
			while (pos + TIME_TOTAL_SIZE - 1 <= length) do
				field, pos = LCCC.ReadAndDecode(data, pos, TIME_INDEX_SIZE)
				if (results or field == index) then
					local entry = { }
					entry.duration, pos = LCCC.ReadAndDecode(data, pos, TIME_FIELD_SIZE)
					entry.remaining, pos = LCCC.ReadAndDecode(data, pos, TIME_FIELD_SIZE)
					entry.remaining = entry.remaining - (GetTimeStamp() - Public.GetLastScanTime(server, charId))
					if (results) then
						table.insert(results, LCCC.MergeTables(entry, TRADESKILL_REVERSE_LOOKUP[field]))
					else
						return entry.duration, entry.remaining
					end
				else
					pos = pos + TIME_FIELD_SIZE * 2
				end
			end
		end
		return results
	end

	function Internal.ResearchGetTime( server, charId, ... )
		server = server or Internal.server
		charId = charId or Internal.charId
		if (server == Internal.server and charId == Internal.charId and not Internal.isInVengeance) then
			-- Return the result directly from the API
			return GetSmithingResearchLineTraitTimes(...)
		else
			local index = GetTraitIndex(...)
			if (index) then
				return Internal.ReadResearchTimes(server, charId, index)
			end
			return nil
		end
	end

	function Internal.ResearchGetResearchability( server, charId, craftingSkillType, researchLineIndex, traitIndex, extendedCheck )
		if ( Internal.ResearchGetTraitKnowledge(server, charId, craftingSkillType, researchLineIndex, traitIndex) == Internal.KNOWLEDGE_UNKNOWN and
		     not select(2, Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex)) ) then
			if (extendedCheck) then
				-- Check for other research in the line
				for traitIndex = 1, select(3, GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)) do
					local _, remaining = Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex)
					if (remaining and remaining > 0) then
						return remaining
					end
				end

				-- Check for research slot limit
				local found = 0
				local minTime = nil
				for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
					for traitIndex = 1, select(3, GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)) do
						local _, remaining = Internal.ResearchGetTime(server, charId, craftingSkillType, researchLineIndex, traitIndex)
						if (remaining and remaining > 0) then
							found = found + 1
							minTime = minTime and zo_min(remaining, minTime) or remaining
						end
					end
				end
				return (found >= Internal.ResearchGetMaxSlots(server, charId, craftingSkillType)) and minTime or true
			else
				return true
			end
		else
			return false
		end
	end

	function Internal.ResearchGetIndicesFromItemLink( itemLink )
		local itemTraitInformation = GetItemTraitInformationFromItemLink(itemLink)
		if (itemTraitInformation == ITEM_TRAIT_INFORMATION_NONE or itemTraitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED) then
			-- GetItemLinkCraftingSkillType only returns craftingSkillType
			local craftingSkillType, researchLineIndex, traitIndex = GetItemLinkCraftingSkillType(itemLink)
			if (GetNumSmithingResearchLines(craftingSkillType) > 0) then
				researchLineIndex = ITEM_LOOKUPS.EQUIP[select(4, GetItemLinkInfo(itemLink))]
				if (researchLineIndex == -1) then
					researchLineIndex = ITEM_LOOKUPS.WEAPON[GetItemLinkWeaponType(itemLink)]
				elseif (researchLineIndex) then
					researchLineIndex = researchLineIndex + (ITEM_LOOKUPS.ARMOR_OFFSET[GetItemLinkArmorType(itemLink)] or 0)
				end
				traitIndex = ITEM_LOOKUPS.TRAIT[GetItemLinkTraitType(itemLink)]
				if (researchLineIndex and traitIndex) then
					return craftingSkillType, researchLineIndex, traitIndex
				end
			end
		end
		return nil
	end

	do
		local RESEARCH_PASSIVES = {
			48160, -- Metallurgy
			48181, -- Carpentry
			48190, -- Stitching
			103640, -- Lapidary Research
		}

		local current = nil

		function Internal.ResearchCheckPassives( )
			local previous = current
			current = 0
			for _, abilityId in ipairs(RESEARCH_PASSIVES) do
				local _, _, _, _, _, purchased, _, rank = GetSkillAbilityInfo(GetSpecificSkillAbilityKeysByAbilityId(abilityId))
				current = (current * 8) + (purchased and rank or 0)
			end
			return previous ~= current
		end
	end
end
