-- Initialize AC namespace if not exists
if not ASJ then ASJ = {} end

ASJ.addOnName = "AbahsAppraiser"
ASJ.addOnDisplayName = "Auto mark/sell junk"
ASJ.version = "1.51.04"
ASJ.author = "xbutch"
local C = ASJ.Config

ASJ.defaults = {
	asjStore = true,
	-- Trash items
	asjTrash = true,
	-- Collectibles
	asjMarkSellToMerchant = true,
	-- Misc item types
	asjTreasures = true,
	asjGlyphQualityThreshold = -1,
	asjCompanionItemsQualityThreshold = -1,
	-- Apparel/Weapons/Jewelry settings (shared logic)
	asjOrnate = true,
	asjApparelQualityThreshold = -1,
	asjIncludingSets = false,
	asjIntricate = false,
	asjIncludingKnownTraits = false,
	asjIncludingUnknownTraits = false,
	-- Deconstruction value protections
	asjIncludingDLCStyle = false, -- when false, protect DLC/area styles from being junked
	asjIncludingRareTraits = false, -- when false, protect rare/expensive traits from being junked
	-- Potions / Poisons
	asjAutoMarkNonCraftedPotionsPoisons = false, -- when true, non player-crafted potions & poisons become junk
	asjExcludeBastiansInsight = true, -- when true, keep Bastian's Insight potions out of junk
	-- Quest items
	asjClockworkCity = false,
	asjThievesGuild = false,
	asjEvents = false,
	-- Announcements / performance
	asjPerItemAnnouncements = false, -- individual junk lines outside bulk scans
	asjBulkScanSummary = true, -- show one summary line after deferred scan
	asjManagedJunk = {}, -- item instance IDs marked by ASJ (never manual junk)
	questTreasureItemIds = {}, -- stable itemId -> Crow/Countess bitmask cache
	questTreasureCacheVersion = 1
}
ASJ.variableVersion = 2

-- Announcement prefixes and fixed messages per event type
local PRE_PREFIX = "|cE5C07BASJ|r " -- soft gold
local PREFIX = PRE_PREFIX .. "<<1>>: "

local MSG_JUNK = "Marked as junk."
local MSG_UNJUNK = "Removed from junk."
local MSG_QUEST = "Quest item, kept."
local MSG_EVENT = "Event item, kept."

local ITEM_QUALITY = {
	ITEM_QUALITY_DISABLED = -1,
	ITEM_QUALITY_TRASH = 0,
	ITEM_QUALITY_NORMAL = 1,
	ITEM_QUALITY_MAGIC = 2,
	ITEM_QUALITY_ARCANE = 3,
	ITEM_QUALITY_ARTIFACT = 4,
	ITEM_QUALITY_LEGENDARY = 5,
	ITEM_QUALITY_ALL = 99
}

local JUNK = {
	TRASH_ITEMIDS = {
		NIBBLES_AND_BITS = {
			54381, -- Trash: Foul Hide
			54382, -- Trash: Carapace
			54383 -- Trash: Daedra Husk
		},
		MORSELS_AND_PECKS = {
			54384, -- Trash: Ectoplasm
			54385, -- Trash: Elemental Essence
			54388 -- Trash: Supple Root
		}
	}
}

-- Stable quest-treasure identification.
-- Decisions are cached by GetItemLinkItemId(), which is language-independent.
-- Exact localized treasure tags are used only to learn previously unseen item IDs.
local QUEST_TREASURE_CROW = 1
local QUEST_TREASURE_COUNTESS = 2
local QUEST_TREASURE_BOTH = QUEST_TREASURE_CROW + QUEST_TREASURE_COUNTESS

local QUEST_TREASURE_TAGS = {
	en = {
		["Games"] = QUEST_TREASURE_BOTH, ["Dolls"] = QUEST_TREASURE_BOTH,
		["Statues"] = QUEST_TREASURE_COUNTESS, ["Ritual Objects"] = QUEST_TREASURE_COUNTESS,
		["Oddities"] = QUEST_TREASURE_COUNTESS, ["Magic Curiosities"] = QUEST_TREASURE_COUNTESS,
		["Writings"] = QUEST_TREASURE_COUNTESS, ["Maps"] = QUEST_TREASURE_COUNTESS,
		["Scrivener Supplies"] = QUEST_TREASURE_COUNTESS, ["Cosmetics"] = QUEST_TREASURE_BOTH,
		["Dry Goods"] = QUEST_TREASURE_COUNTESS, ["Wardrobe Accessories"] = QUEST_TREASURE_COUNTESS,
		["Drinkware"] = QUEST_TREASURE_BOTH, ["Utensils"] = QUEST_TREASURE_BOTH,
		["Dishes and Cookware"] = QUEST_TREASURE_BOTH, ["Children's Toys"] = QUEST_TREASURE_CROW,
		["Toys"] = QUEST_TREASURE_CROW, ["Grooming Items"] = QUEST_TREASURE_CROW,
	},
	de = {
		["Spiele"] = QUEST_TREASURE_BOTH, ["Puppen"] = QUEST_TREASURE_BOTH,
		["Statuen"] = QUEST_TREASURE_COUNTESS, ["Ritualgegenstände"] = QUEST_TREASURE_COUNTESS,
		["Kuriositäten"] = QUEST_TREASURE_COUNTESS, ["Magische Kuriositäten"] = QUEST_TREASURE_COUNTESS,
		["Schriften"] = QUEST_TREASURE_COUNTESS, ["Karten"] = QUEST_TREASURE_COUNTESS,
		["Schreiberbedarf"] = QUEST_TREASURE_COUNTESS, ["Kosmetika"] = QUEST_TREASURE_BOTH,
		["Trockenwaren"] = QUEST_TREASURE_COUNTESS, ["Schmuckstücke"] = QUEST_TREASURE_COUNTESS,
		["Trinkgefäße"] = QUEST_TREASURE_BOTH, ["Utensilien"] = QUEST_TREASURE_BOTH,
		["Teller und Kochgeschirr"] = QUEST_TREASURE_BOTH, ["Kinderspielzeug"] = QUEST_TREASURE_CROW,
		["Körperpflegegegenstände"] = QUEST_TREASURE_CROW,
	},
	es = {
		["Juegos"] = QUEST_TREASURE_BOTH, ["Muñecos"] = QUEST_TREASURE_BOTH,
		["Estatuas"] = QUEST_TREASURE_COUNTESS, ["Objetos ceremoniales"] = QUEST_TREASURE_COUNTESS,
		["Rarezas"] = QUEST_TREASURE_COUNTESS, ["Curiosidades mágicas"] = QUEST_TREASURE_COUNTESS,
		["Escritos"] = QUEST_TREASURE_COUNTESS, ["Mapas"] = QUEST_TREASURE_COUNTESS,
		["Materiales de escribano"] = QUEST_TREASURE_COUNTESS, ["Estéticos"] = QUEST_TREASURE_BOTH,
		["Productos secos"] = QUEST_TREASURE_COUNTESS, ["Accesorios de armario"] = QUEST_TREASURE_COUNTESS,
		["Cristalería"] = QUEST_TREASURE_BOTH, ["Utensilios"] = QUEST_TREASURE_BOTH,
		["Utensilios de cocina"] = QUEST_TREASURE_BOTH, ["Juegos infantiles"] = QUEST_TREASURE_CROW,
		["Objetos de aseo"] = QUEST_TREASURE_CROW,
	},
	fr = {
		["Jeux"] = QUEST_TREASURE_BOTH, ["Poupées"] = QUEST_TREASURE_BOTH,
		["Statues"] = QUEST_TREASURE_COUNTESS, ["Objets rituels"] = QUEST_TREASURE_COUNTESS,
		["Curiosités"] = QUEST_TREASURE_COUNTESS, ["Curiosités magiques"] = QUEST_TREASURE_COUNTESS,
		["Écrits"] = QUEST_TREASURE_COUNTESS, ["Cartes"] = QUEST_TREASURE_COUNTESS,
		["Fournitures de scribe"] = QUEST_TREASURE_COUNTESS, ["Produits cosmétiques"] = QUEST_TREASURE_BOTH,
		["Denrées sèches"] = QUEST_TREASURE_COUNTESS, ["Accessoires vestimentaires"] = QUEST_TREASURE_COUNTESS,
		["Récipients à boire"] = QUEST_TREASURE_BOTH, ["Ustensiles"] = QUEST_TREASURE_BOTH,
		["Plats et moules"] = QUEST_TREASURE_BOTH, ["Jouets d'enfants"] = QUEST_TREASURE_CROW,
		["Ustensiles de toilette"] = QUEST_TREASURE_CROW,
	},
	ru = {
		["игры"] = QUEST_TREASURE_BOTH, ["куклы"] = QUEST_TREASURE_BOTH,
		["статуэтки"] = QUEST_TREASURE_COUNTESS, ["ритуальные объекты"] = QUEST_TREASURE_COUNTESS,
		["диковины"] = QUEST_TREASURE_COUNTESS, ["магические диковинки"] = QUEST_TREASURE_COUNTESS,
		["сочинения"] = QUEST_TREASURE_COUNTESS, ["карты"] = QUEST_TREASURE_COUNTESS,
		["писчие принадлежности"] = QUEST_TREASURE_COUNTESS, ["косметика"] = QUEST_TREASURE_BOTH,
		["ткани"] = QUEST_TREASURE_COUNTESS, ["аксессуары"] = QUEST_TREASURE_COUNTESS,
		["посуда для напитков"] = QUEST_TREASURE_BOTH, ["утварь"] = QUEST_TREASURE_BOTH,
		["приборы"] = QUEST_TREASURE_BOTH, ["посуда и кухонные принадлежности"] = QUEST_TREASURE_BOTH,
		["детские игрушки"] = QUEST_TREASURE_CROW, ["предметы для ухода"] = QUEST_TREASURE_CROW,
	},
	jp = {
		["遊具"] = QUEST_TREASURE_BOTH, ["人形"] = QUEST_TREASURE_BOTH,
		["像"] = QUEST_TREASURE_COUNTESS, ["儀式用品"] = QUEST_TREASURE_COUNTESS,
		["珍品"] = QUEST_TREASURE_COUNTESS, ["魔法の珍品"] = QUEST_TREASURE_COUNTESS,
		["書物"] = QUEST_TREASURE_COUNTESS, ["マップ"] = QUEST_TREASURE_COUNTESS,
		["筆記用具"] = QUEST_TREASURE_COUNTESS, ["化粧品"] = QUEST_TREASURE_BOTH,
		["生地"] = QUEST_TREASURE_COUNTESS, ["ワードローブ用品"] = QUEST_TREASURE_COUNTESS,
		["飲み物用食器"] = QUEST_TREASURE_BOTH, ["調理器具"] = QUEST_TREASURE_BOTH,
		["食器と調理用具"] = QUEST_TREASURE_BOTH, ["子供のおもちゃ"] = QUEST_TREASURE_CROW,
		["身だしなみ用品"] = QUEST_TREASURE_CROW,
	},
	zh = {
		["游戏"] = QUEST_TREASURE_BOTH, ["玩偶"] = QUEST_TREASURE_BOTH,
		["雕像"] = QUEST_TREASURE_COUNTESS, ["仪式物品"] = QUEST_TREASURE_COUNTESS,
		["奇异物品"] = QUEST_TREASURE_COUNTESS, ["魔法新奇之物"] = QUEST_TREASURE_COUNTESS,
		["文字"] = QUEST_TREASURE_COUNTESS, ["地图"] = QUEST_TREASURE_COUNTESS,
		["公证人补给"] = QUEST_TREASURE_COUNTESS, ["装扮品"] = QUEST_TREASURE_BOTH,
		["干制物品"] = QUEST_TREASURE_COUNTESS, ["衣橱配饰"] = QUEST_TREASURE_COUNTESS,
		["饮具"] = QUEST_TREASURE_BOTH, ["餐具"] = QUEST_TREASURE_BOTH,
		["餐盘和厨具"] = QUEST_TREASURE_BOTH, ["儿童玩具"] = QUEST_TREASURE_CROW,
		["刷洗物品"] = QUEST_TREASURE_CROW,
	},
}

local function GetClientLanguage()
	local language = string.lower(GetCVar("language.2") or "en")
	local short = string.sub(language, 1, 2)
	if short == "ja" then short = "jp" end
	return QUEST_TREASURE_TAGS[short] and short or "en"
end

local function NormalizeTreasureTag(text)
	if not text or text == "" then return "" end
	if SI_TOOLTIP_ITEM_TAG_FORMATER then
		return zo_strformat(SI_TOOLTIP_ITEM_TAG_FORMATER, text)
	end
	return zo_strformat("<<1>>", text)
end

local function GetQuestTreasureMask(itemLink)
	if not itemLink or itemLink == "" then return 0 end
	local itemId = GetItemLinkItemId(itemLink)
	if not itemId or itemId == 0 then return 0 end

	local SV = ASJ.savedVars or ASJ.defaults
	local cache = SV.questTreasureItemIds
	if type(cache) ~= "table" then
		cache = {}
		SV.questTreasureItemIds = cache
	end

	local key = tostring(itemId)
	local cached = cache[key]
	if type(cached) == "number" then return cached end

	local languageTags = QUEST_TREASURE_TAGS[GetClientLanguage()] or QUEST_TREASURE_TAGS.en
	local mask = 0
	local numTags = GetItemLinkNumItemTags(itemLink)
	for i = 1, numTags do
		local tagDescription, tagCategory = GetItemLinkItemTagInfo(itemLink, i)
		if tagCategory == TAG_CATEGORY_TREASURE_TYPE then
			local tag = NormalizeTreasureTag(tagDescription)
			local tagMask = languageTags[tag] or QUEST_TREASURE_TAGS.en[tag] or 0
			if tagMask == QUEST_TREASURE_BOTH then
				mask = QUEST_TREASURE_BOTH
				break
			elseif tagMask > 0 and mask ~= tagMask then
				mask = mask + tagMask
			end
		end
	end

	if mask > 0 then cache[key] = mask end
	return mask
end

--------------------------------------------------------------------
-- DEBUG Helper : simple debug print (disabled in release if needed)
-- ===== Early debug ring buffer (captures messages before /ac_debug) =====
local preDebugBuffer = {}
local preDebugBufferMax = 200
local function bufferDebugLine(txt)
	if #preDebugBuffer >= preDebugBufferMax then table.remove(preDebugBuffer, 1) end
	preDebugBuffer[#preDebugBuffer + 1] = txt
end

local debugEnabled = false -- shared flag everyone sees
local debugCount = 0
local addonInitialized = false

local function dbg(msg)
	-- capture everything in buffer (even if debug off) for later review
	bufferDebugLine(msg)
	if debugEnabled then
		debugCount = debugCount + 1
		if type(d) == 'function' then d('|c99CCFF[ASJ ' .. debugCount .. ']|r ' .. msg) end
	end
end

local function SwitchDebugMode()
	if debugEnabled then
		dbg('Debug disabled')
		debugEnabled = false
		debugCount = 0
	else
		debugEnabled = true
		dbg('Debug enabled')
		-- flush buffered lines (without double-buffering)
		if #preDebugBuffer > 0 then
			for _, ln in ipairs(preDebugBuffer) do
				debugCount = debugCount + 1
				if type(d) == 'function' then d('|c99CCFF[ASJ PRE ' .. debugCount .. ']|r ' .. ln) end
			end
		end
		if not addonInitialized then dbg('Addon not initialized yet (waiting for EVENT_ADD_ON_LOADED).') end
	end
end

--------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------
-- Directly register events with ESO. No external helpers needed.
local function RegisterForEvent(eventId, callback) EVENT_MANAGER:RegisterForEvent(ASJ.addOnName, eventId, callback) end

-- Add event filters with correct ESO signature (namespace, eventId, filterType, filterParam)
local function RegisterFilterForEvent(eventId, filterID, filterValue) if filterID ~= nil and filterValue ~= nil then EVENT_MANAGER:AddFilterForEvent(ASJ.addOnName, eventId, filterID, filterValue) end end

local function UnregisterForEvent(eventId) EVENT_MANAGER:UnregisterForEvent(ASJ.addOnName, eventId) end

--------------------------------------------------------------------
-- Options value handling
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Addon initialization
--------------------------------------------------------------------

-- Controlled announcement function (respects performance settings)

local function AnnounceJunk(itemLink, message)
	if ASJ._bulkScanning then return end
	local SV = ASJ.savedVars or ASJ.defaults
	if not SV.asjPerItemAnnouncements then return end
	local tmpl = PREFIX .. (message or MSG_JUNK)
	local out = zo_strformat and zo_strformat(tmpl, itemLink) or tostring(tmpl):gsub("<<1>>", tostring(itemLink))
	if type(d) == 'function' then d(out) end
end

local function GetItemInstanceKey(bagId, slotIndex)
	if not GetItemUniqueId or not Id64ToString then return nil end
	local id = GetItemUniqueId(bagId, slotIndex)
	if not id then return nil end
	local key = Id64ToString(id)
	if not key or key == "" or key == "0" then return nil end
	return key
end

local function GetManagedJunkTable()
	local SV = ASJ.savedVars or ASJ.defaults
	local managed = SV.asjManagedJunk
	if type(managed) ~= "table" then
		managed = {}
		SV.asjManagedJunk = managed
	end
	return managed
end

local function MarkItemAsJunk(bagId, slotIndex, silent)
	if IsItemJunk(bagId, slotIndex) then return false end
	if CanItemBeMarkedAsJunk and not CanItemBeMarkedAsJunk(bagId, slotIndex) then return false end
	local itemLink = GetItemLink(bagId, slotIndex)
	SetItemIsJunk(bagId, slotIndex, true)
	local key = GetItemInstanceKey(bagId, slotIndex)
	if key then GetManagedJunkTable()[key] = true end
	if not silent then AnnounceJunk(itemLink, MSG_JUNK) end
	return true
end

local function UnmarkManagedJunk(bagId, slotIndex, silent)
	local key = GetItemInstanceKey(bagId, slotIndex)
	if not key then return false end
	local managed = GetManagedJunkTable()
	if not managed[key] then return false end
	if not IsItemJunk(bagId, slotIndex) then
		managed[key] = nil
		return false
	end
	local itemLink = GetItemLink(bagId, slotIndex)
	SetItemIsJunk(bagId, slotIndex, false)
	managed[key] = nil
	if not silent then AnnounceJunk(itemLink, MSG_UNJUNK) end
	return true
end

local function CleanupManagedJunk()
	local managed = GetManagedJunkTable()
	local live = {}
	local bagId = BAG_BACKPACK
	for slotIndex = 0, GetBagSize(bagId) - 1 do
		if HasItemInSlot(bagId, slotIndex) then
			local key = GetItemInstanceKey(bagId, slotIndex)
			if key then live[key] = true end
		end
	end
	for key in pairs(managed) do
		if not live[key] then managed[key] = nil end
	end
end

-- Check if item is quest-excluded for trash logic
local function isTrashItemQuestJunkable(bagId, slotIndex)
	local SV = ASJ.savedVars or ASJ.defaults
	if SV.asjClockworkCity then return true end -- no exclusions apply
	local itemId = GetItemId(bagId, slotIndex)
	for _, constItemId in pairs(JUNK.TRASH_ITEMIDS.NIBBLES_AND_BITS) do
		if itemId == constItemId then
			AnnounceJunk(GetItemLink(bagId, slotIndex), MSG_QUEST)
			return false
		end
	end
	for _, constItemId in pairs(JUNK.TRASH_ITEMIDS.MORSELS_AND_PECKS) do
		if itemId == constItemId then
			AnnounceJunk(GetItemLink(bagId, slotIndex), MSG_QUEST)
			return false
		end
	end
	return true
end

-- Check if item is quest-excluded for sell-to-merchant logic
local function isSellToMerchantItemQuestJunkable(specializedItemType, itemLink)
	local SV = ASJ.savedVars or ASJ.defaults
	if SV.asjEvents then return true end
	if specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH then
		local ItemId = GetItemLinkItemId(itemLink)
		if ItemId >= 100393 and ItemId <= 100395 then
			AnnounceJunk(itemLink, MSG_EVENT)
			return false
		end
	end
	return true
end

-- Check if item is quest-excluded for treasure logic
local function isTreasureItemQuestJunkable(itemLink)
	local SV = ASJ.savedVars or ASJ.defaults
	if SV.asjClockworkCity and SV.asjThievesGuild then return true end

	local mask = GetQuestTreasureMask(itemLink)
	if not SV.asjClockworkCity and (mask == QUEST_TREASURE_CROW or mask == QUEST_TREASURE_BOTH) then
		AnnounceJunk(itemLink, MSG_QUEST)
		return false
	end
	if not SV.asjThievesGuild and (mask == QUEST_TREASURE_COUNTESS or mask == QUEST_TREASURE_BOTH) then
		AnnounceJunk(itemLink, MSG_QUEST)
		return false
	end
	return true
end

-- Reverse style logic: treat ANY non-basic style as DLC/valuable so we don't have to maintain a growing whitelist.
-- Basic styles: core racial styles available from the start + a few early common styles.
-- Basic racial styles: Breton=1 .. Khajiit=9 (confirmed), assume contiguous block.
local BASIC_STYLE_MIN = 1
local BASIC_STYLE_MAX = 9
local BASIC_STYLE_IMPERIAL = 34

local function isBasicStyle(styleId) return (type(styleId) == "number" and ((styleId >= BASIC_STYLE_MIN and styleId <= BASIC_STYLE_MAX) or styleId == BASIC_STYLE_IMPERIAL)) end

local function isDLCOrValuableStyle(itemLink)
	if not itemLink or itemLink == "" then return false end
	local styleId = GetItemLinkItemStyle(itemLink)
	if not styleId then return false end
	return (not isBasicStyle(styleId))
end

-- Rare/expensive trait detection (focus on Nirnhoned and valuable jewelry traits)
local RARE_TRAITS = {}
local function _addTrait(t) if t ~= nil then RARE_TRAITS[t] = true end end
_addTrait(ITEM_TRAIT_TYPE_ARMOR_NIRNHONED)
_addTrait(ITEM_TRAIT_TYPE_WEAPON_NIRNHONED)
_addTrait(ITEM_TRAIT_TYPE_JEWELRY_SWIFT)
_addTrait(ITEM_TRAIT_TYPE_JEWELRY_INFUSED)
_addTrait(ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY)
_addTrait(ITEM_TRAIT_TYPE_JEWELRY_HARMONY)
_addTrait(ITEM_TRAIT_TYPE_JEWELRY_TRIUNE)

local function hasRareOrValuableTrait(itemTrait) return itemTrait ~= nil and RARE_TRAITS[itemTrait] == true end

-- Bastian's Insight potent potions use stable base item IDs; level/CP tier is
-- encoded in the item-link fields, so these IDs cover Sip through Essence.
local BASTIAN_POTION_ITEM_IDS = {
	[176040] = true, -- Potent Magicka
	[176041] = true, -- Potent Health
	[176042] = true, -- Potent Stamina
}
local function isBastiansInsightPotion(itemLink)
	if not itemLink or itemLink == "" then return false end
	return BASTIAN_POTION_ITEM_IDS[GetItemLinkItemId(itemLink)] == true
end

-- Companion items
-- Check if item is for companion (to apply companion-specific quality threshold)
local function isItemForCompanion(bagId, slotIndex)
	local actorCategory = GetItemActorCategory(bagId, slotIndex)
	return actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION
end

-- Extracted shared logic: applies junk rules for a single bag/slot
-- Returns: true if the item was marked as junk, false otherwise
local function ApplyJunkRules(bagId, slotIndex)
	-- Resolve link and types once
	local itemLink = GetItemLink(bagId, slotIndex)
	if not itemLink or itemLink == "" then return false end

	local itemType, specializedItemType = GetItemType(bagId, slotIndex)
	local sellInformation = GetItemLinkSellInformation(itemLink)
	local SV = ASJ.savedVars or ASJ.defaults

	-- cannot sell items are not junk, even if they match other rules (e.g. some quest items, some event items, etc.)
	if sellInformation == ITEM_SELL_INFORMATION_CANNOT_SELL then return false end

	-- Always exclude player-crafted items
	if IsItemLinkCrafted and IsItemLinkCrafted(itemLink) then
		dbg('Skipping player-crafted item: ' .. tostring(itemLink))
		return false
	end

	-- Trash items
	if (itemType == ITEMTYPE_TRASH or specializedItemType == SPECIALIZED_ITEMTYPE_TRASH) then
		if SV.asjTrash then
			if not isTrashItemQuestJunkable(bagId, slotIndex) then
				dbg("Skipping quest-excluded trash item: " .. tostring(itemLink))
				return false
			end
			-- If we reach here, the item is trash and can be junked
			return true
		end
	end

	-- Treasures
	if (itemType == ITEMTYPE_TREASURE or specializedItemType == SPECIALIZED_ITEMTYPE_TREASURE) then
		if SV.asjTreasures then
			if not isTreasureItemQuestJunkable(itemLink) then
				dbg("Skipping quest-excluded treasure item: " .. tostring(itemLink))
				return false
			end
			-- If we reach here, the item is treasure and can be junked
			return true
		end
	end

	-- Sell to merchant for gold (collectibles)
	if sellInformation == ITEM_SELL_INFORMATION_PRIORITY_SELL then
		if SV.asjMarkSellToMerchant then
			if not isSellToMerchantItemQuestJunkable(specializedItemType, itemLink) then
				dbg("Skipping quest-excluded collectible item: " .. tostring(itemLink))
				return false
			end
			-- If we reach here, the item is a collectible sellable to merchant and can be junked
			return true
		end
	end

	-- Potions / Poisons (non-crafted) handling
	if SV.asjAutoMarkNonCraftedPotionsPoisons and (itemType == ITEMTYPE_POTION or itemType == ITEMTYPE_POISON) then
		-- Optionally exclude Bastian's Insight potions
		if SV.asjExcludeBastiansInsight and isBastiansInsightPotion(itemLink) then
			dbg("Protected Bastian's Insight potion: " .. tostring(itemLink))
			return false
		end
		-- Non-crafted potions/poisons are junk
		return true
	end

	-- Get item quality once
	local itemQuality = GetItemFunctionalQuality(bagId, slotIndex)

	-- Companion gear: use the same junk pipeline as every other item.
	if isItemForCompanion(bagId, slotIndex) then
		local threshold = SV.asjCompanionItemsQualityThreshold or ITEM_QUALITY.ITEM_QUALITY_DISABLED
		if threshold == ITEM_QUALITY.ITEM_QUALITY_DISABLED then return false end
		if itemQuality > threshold then
			dbg("Skipping companion item (quality above threshold): " .. tostring(itemLink))
			return false
		end
		return true
	end

	-- Glyphs
	if (itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON) then
		local threshold = SV.asjGlyphQualityThreshold or ITEM_QUALITY.ITEM_QUALITY_DISABLED
		-- Disabled means: never auto-junk glyphs
		if threshold == ITEM_QUALITY.ITEM_QUALITY_DISABLED then return false end

		-- If item quality is ABOVE threshold, protect (skip)
		if itemQuality > threshold then
			dbg("Skipping glyph (quality above threshold): " .. tostring(itemLink))
			return false
		end
		-- Otherwise (quality <= threshold) mark as junk
		return true
	end

	-- Apparel
	if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
		local itemTrait = GetItemTrait(bagId, slotIndex)
		local isIntricate = itemTrait == ITEM_TRAIT_TYPE_WEAPON_INTRICATE
			or itemTrait == ITEM_TRAIT_TYPE_ARMOR_INTRICATE
			or itemTrait == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE
		local isOrnate = itemTrait == ITEM_TRAIT_TYPE_WEAPON_ORNATE
			or itemTrait == ITEM_TRAIT_TYPE_ARMOR_ORNATE
			or itemTrait == ITEM_TRAIT_TYPE_JEWELRY_ORNATE

		-- Protection rules are vetoes. Once one matches, no later auto-junk rule
		-- may override it.
		local hasSet = GetItemLinkSetInfo(itemLink, false)
		if hasSet and not SV.asjIncludingSets then
			dbg("Protected set item: " .. tostring(itemLink))
			return false
		end

		if not SV.asjIncludingRareTraits and hasRareOrValuableTrait(itemTrait) then
			dbg("Protected from junking due to valuable trait: " .. tostring(itemLink))
			return false
		end

		if not SV.asjIncludingDLCStyle and isDLCOrValuableStyle(itemLink) then
			dbg("Protected from junking due to non-basic style: " .. tostring(itemLink))
			return false
		end

		-- Intricate OFF is itself an explicit protection.
		if isIntricate and not SV.asjIntricate then
			dbg("Protected intricate item (setting OFF): " .. tostring(itemLink))
			return false
		end

		-- Positive dedicated rules are evaluated only after every protection veto.
		if isIntricate and SV.asjIntricate then
			dbg("Intricate item marked as junk: " .. tostring(itemLink))
			return true
		end

		if isOrnate and SV.asjOrnate then
			dbg("Ornate item marked as junk: " .. tostring(itemLink))
			return true
		end

		-- Generic apparel rule. Disabled means this generic rule is off; it is not
		-- a veto against the dedicated Ornate/Intricate rules above.
		local qualityThreshold = SV.asjApparelQualityThreshold or ITEM_QUALITY.ITEM_QUALITY_DISABLED
		if qualityThreshold == ITEM_QUALITY.ITEM_QUALITY_DISABLED then return false end
		if itemQuality > qualityThreshold then
			dbg("Skipping apparel (quality above threshold): " .. tostring(itemLink))
			return false
		end

		-- Known/researchable toggles are eligibility gates for the generic apparel
		-- rule only. Ornate/Intricate are handled separately above.
		local itemTraitType = GetItemLinkTraitType(itemLink)
		if itemTraitType ~= ITEM_TRAIT_TYPE_NONE then
			local canBeResearched = CanItemLinkBeTraitResearched(itemLink)
			local include = (canBeResearched and SV.asjIncludingUnknownTraits)
				or (not canBeResearched and SV.asjIncludingKnownTraits)
			if not include then
				dbg("Skipping item due to generic trait eligibility: " .. tostring(itemLink))
				return false
			end
		end

		return true
	end

	-- If we reach here, no junk rules matched
	-- dbg("No junk rules matched for: " .. tostring(itemLink))
	return false
end

local function OnInventorySingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
	dbg('OnInventorySingleSlotUpdate called')
	-- pcall guards against any runtime error: ESO permanently unregisters an event callback
	-- that throws, so a crash here (e.g. from a race with another inventory addon) would
	-- silently stop all future junk-marking until the next UI reload.
	local ok, err = pcall(function() if ApplyJunkRules(bagId, slotIndex) then MarkItemAsJunk(bagId, slotIndex) end end)
	if not ok then dbg('OnInventorySingleSlotUpdate error: ' .. tostring(err)) end
end

-- =============================================================
-- Deferred Backpack Scan (time-sliced to stay under frame budget)
-- =============================================================
ASJ.scanSliceTimeMS = 8 -- approx processing time budget per slice
ASJ.scanSliceDelayMS = 5 -- delay between slices (ms)

local scanState = {
	running = false,
	bag = BAG_BACKPACK,
	nextSlot = 0,
	lastIndex = 0, -- last slot index (bag size - 1)
	processed = 0,
	junked = 0,
	unjunked = 0,
	silent = true,
	skippedEmpty = 0,
	showSummary = true
}

local function ProcessScanSlice()
	if not scanState.running then return end
	local start = GetFrameTimeMilliseconds()
	local bagId = scanState.bag
	while scanState.nextSlot <= scanState.lastIndex do
		local slotIndex = scanState.nextSlot
		if HasItemInSlot(bagId, slotIndex) then
			scanState.processed = scanState.processed + 1
			if ApplyJunkRules(bagId, slotIndex) then
				if MarkItemAsJunk(bagId, slotIndex, true) then scanState.junked = scanState.junked + 1 end
			else
				if UnmarkManagedJunk(bagId, slotIndex, true) then scanState.unjunked = scanState.unjunked + 1 end
			end
		else
			scanState.skippedEmpty = scanState.skippedEmpty + 1
		end
		scanState.nextSlot = scanState.nextSlot + 1
		if (GetFrameTimeMilliseconds() - start) >= ASJ.scanSliceTimeMS then break end
	end
	if scanState.nextSlot > scanState.lastIndex then
		scanState.running = false
		ASJ._bulkScanning = false
		CleanupManagedJunk()
		if type(d) == 'function' then
			if scanState.showSummary then
				if ASJ.savedVars and ASJ.savedVars.asjBulkScanSummary then
					local msg = string.format("%d junked, %d unjunked (processed %d, empty %d, slots %d).", scanState.junked, scanState.unjunked, scanState.processed, scanState.skippedEmpty, scanState.lastIndex + 1)
					d(PRE_PREFIX .. msg)
				end
			end
		end
		dbg(string.format('Deferred scan complete (processed=%d empty=%d totalSlots=%d).', scanState.processed, scanState.skippedEmpty, scanState.lastIndex + 1))
	else
		zo_callLater(ProcessScanSlice, ASJ.scanSliceDelayMS)
	end
end

local function StartDeferredScan(force, showSummary)
	if scanState.running and not force then return end
	scanState.bag = BAG_BACKPACK
	scanState.nextSlot = 0
	scanState.lastIndex = GetBagSize(scanState.bag) - 1
	scanState.processed = 0
	scanState.junked = 0
	scanState.unjunked = 0
	scanState.skippedEmpty = 0
	scanState.showSummary = (showSummary ~= false)
	scanState.running = true
	ASJ._bulkScanning = true
	dbg(string.format('Starting deferred backpack scan (slot range 0..%d, used=%d).', scanState.lastIndex, GetNumBagUsedSlots(scanState.bag)))
	zo_callLater(ProcessScanSlice, 0)
end

local function ScanBackpackForJunk(forceSync, showSummary)
	if forceSync then
		dbg('ScanBackpackForJunk (synchronous) called')
		local bagId = BAG_BACKPACK
		local lastIndex = GetBagSize(bagId) - 1
		local junked, unjunked, processed, empty = 0, 0, 0, 0
		ASJ._bulkScanning = true -- still suppress per-item spam
		for slotIndex = 0, lastIndex do
			if HasItemInSlot(bagId, slotIndex) then
				processed = processed + 1
				if ApplyJunkRules(bagId, slotIndex) then
					if MarkItemAsJunk(bagId, slotIndex, true) then junked = junked + 1 end
				else
					if UnmarkManagedJunk(bagId, slotIndex, true) then unjunked = unjunked + 1 end
				end
			else
				empty = empty + 1
			end
		end
		ASJ._bulkScanning = false
		CleanupManagedJunk()
		if showSummary ~= false and ASJ.savedVars and ASJ.savedVars.asjBulkScanSummary then if type(d) == 'function' then d(PRE_PREFIX .. string.format("Bulk scan: %d junked, %d unjunked (processed %d empty %d totalSlots %d).", junked, unjunked, processed, empty, lastIndex + 1)) end end
		dbg(string.format('Synchronous scan complete (processed=%d empty=%d totalSlots=%d).', processed, empty, lastIndex + 1))
	else
		StartDeferredScan(true)
	end
end

-- Public API
ASJ.StartDeferredScan = StartDeferredScan
ASJ.ScanBackpackForJunk = ScanBackpackForJunk

local function OnShopOpen()
	dbg('OnShopOpen called')
	if ASJ.savedVars.asjStore then
		ScanBackpackForJunk(true, false) -- apply current rules, including companion gear
		SellAllJunk()
		d(PRE_PREFIX .. "Sold junk items.")
	else
		dbg("Skipping junk sell to store (disabled in settings)")
	end
end

-- onLoad initializion
local function OnLoad(eventCode, name)
	if name ~= ASJ.addOnName then return end
	dbg('OnLoad called for ' .. tostring(name) .. ' (char=' .. GetUnitName('player') .. ')')

	-- Migrate before applying defaults. ZO_SavedVars copies defaults into the raw
	-- table, so doing nil checks after that point cannot distinguish a missing
	-- setting from a newly supplied default.
	local migrationSV = ZO_SavedVars:NewAccountWide(C.SAVEDVARS, ASJ.variableVersion, nil, nil)
	local migrationMT = getmetatable(migrationSV)
	local rawSV = migrationMT and migrationMT.__index or migrationSV
	local migrationVersion = rawget(rawSV, "migrationVersion") or 0
	if migrationVersion < 1 then
		local function migrate(oldKey, newKey)
			local oldValue = rawget(rawSV, oldKey)
			if oldValue ~= nil and rawget(rawSV, newKey) == nil then
				rawSV[newKey] = oldValue
			end
		end
		migrate("autoMarkIncludingSets", "asjIncludingSets")
		migrate("autoMarkQualityThreshold", "asjApparelQualityThreshold")
		migrate("asjSellToMerchant", "asjMarkSellToMerchant")
		migrate("asjGlyphsQuality", "asjGlyphQualityThreshold")
		migrate("asjCompanionQuality", "asjCompanionItemsQualityThreshold")
		rawSV.migrationVersion = 1
	end

	if rawget(rawSV, "questTreasureCacheVersion") ~= ASJ.defaults.questTreasureCacheVersion then
		rawSV.questTreasureItemIds = {}
		rawSV.questTreasureCacheVersion = ASJ.defaults.questTreasureCacheVersion
	end
	if type(rawget(rawSV, "asjManagedJunk")) ~= "table" then rawSV.asjManagedJunk = {} end

	ASJ.savedVars = ZO_SavedVars:NewAccountWide(C.SAVEDVARS, ASJ.variableVersion, nil, ASJ.defaults)
	local SV = ASJ.savedVars

	-- Options panel callback + dirty flag removed; user triggers scan manually via button.
	if ASJ.CreateOptions then ASJ:CreateOptions() end

	dbg('OnLoad: Registering vendor open/close events')
	RegisterForEvent(EVENT_OPEN_STORE, OnShopOpen)
	RegisterForEvent(EVENT_CLOSE_STORE, function()
		dbg('OnShopClose: deferred scan to catch items missed during vendor session')
		StartDeferredScan(true, false)
	end)

	RegisterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySingleSlotUpdate)
	RegisterFilterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_IS_NEW_ITEM, true)
	RegisterFilterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	RegisterFilterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

	dbg('onLoad: Unregistering for EVENT_ADD_ON_LOADED')
	UnregisterForEvent(EVENT_ADD_ON_LOADED)

	addonInitialized = true
end

--------------------------------------------------------------------
-- Slash Commands for Testing and Debug
--------------------------------------------------------------------
if GetDisplayName() == "@XBUTCH" or GetDisplayName() == "@xbutch" then
	SLASH_COMMANDS['/asj_debug'] = SwitchDebugMode
	SLASH_COMMANDS['/asj_scan'] = function(arg)
		if arg == 'sync' then
			ScanBackpackForJunk(true)
		else
			StartDeferredScan(true)
		end
	end
end

-- Register for event onload
EVENT_MANAGER:RegisterForEvent(ASJ.addOnName, EVENT_ADD_ON_LOADED, OnLoad)
