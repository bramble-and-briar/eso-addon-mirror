-- BankManagerCustomRules.lua
-- Centralized custom-item and filter-based rule management for BankManagerRevived.
-- Loaded after BankManager.lua and BankManagerRules.lua; runtime state is supplied via BMR.CustomRulesContext.
BMR = BMR or {}
BMR.CustomRules = BMR.CustomRules or {}
local C = BMR.CustomRules
local function Context() return BMR.CustomRulesContext or {} end
local function A(name) return Context()[name] end
local function ActualProfile() return type(A("GetActualProfile")) == "function" and A("GetActualProfile")() or 1 end
local function DeepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do copy[key] = DeepCopy(child) end
	return copy
end
local function ActionValue(name) return A(name) end
local ACTION_NOTSET = ActionValue("ACTION_NOTSET") or 1
local ACTION_PUSH = ActionValue("ACTION_PUSH") or 2
local ACTION_PULL = ActionValue("ACTION_PULL") or 3
local ACTION_PUSH_GBANK = ActionValue("ACTION_PUSH_GBANK") or 4
local ACTION_PUSH_BOTH = ActionValue("ACTION_PUSH_BOTH") or 5
local ACTION_KEEP_ONE_STACK = ActionValue("ACTION_KEEP_ONE_STACK") or 6
local ACTION_KEEP_ONE_STACK_BANK = ActionValue("ACTION_KEEP_ONE_STACK_BANK") or 7
local ACTION_PUSH_FURNITURE = ActionValue("ACTION_PUSH_FURNITURE") or 8
local ACTION_PUSH_ALL_STACKS = ActionValue("ACTION_PUSH_ALL_STACKS") or 9
local ACTION_PULL_ALL_STACKS = ActionValue("ACTION_PULL_ALL_STACKS") or 10
local BMR_ITEMLINK = ActionValue("ITEMLINK") or 1
local function FormatCustomItemName(itemLink, fallbackName)
	local fn = A("FormatCustomItemName")
	if type(fn) == "function" then return fn(itemLink, fallbackName) end
	return fallbackName
end

function C.GetCustomItemDisplayName(itemId, itemData)
	if type(itemData) ~= "table" then
		local rules = db and db.customItemRules or {}
		itemData = rules[tostring(itemId)] or rules[tonumber(itemId)]
	end
	if type(itemData) ~= "table" then return "Item " .. tostring(itemId or "?") end
	local alias = string.gsub(tostring(itemData.displayName or ""), "^%s*(.-)%s*$", "%1")
	if alias ~= "" then return alias end
	return FormatCustomItemName(itemData.itemLink, itemData.name) or itemData.name or ("Item " .. tostring(itemId or "?"))
end

local function CustomRuleDebug(message)
	local fn = A("CustomRuleDebug")
	if type(fn) == "function" then fn(message) end
end

-- Chat output must also work in ForcedConsoleFlow, where CHAT_SYSTEM can be nil.
local function SendCustomRuleMessage(message)
	if type(BMR.SafeAddChatMessage) == "function" then
		return BMR.SafeAddChatMessage(message)
	end
	if CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
		local ok = pcall(CHAT_SYSTEM.AddMessage, CHAT_SYSTEM, tostring(message or ""))
		return ok
	end
	return false
end
local function FireBmrRuleCountRefresh()
	local fn = A("FireRuleCountRefresh")
	if type(fn) == "function" then fn() end
end

-- Filter-based Custom Rules --------------------------------------------------
-- Search strings match the localized item name. Specifications are ANDed
-- together; multiple values within one specification are alternatives (OR).
local function SafeGetItemLinkValue(apiName, itemLink)
	local api = _G and _G[apiName]
	if type(api) ~= "function" then return nil end
	local ok, first, second = pcall(api, itemLink)
	if ok then return first, second end
	return nil
end

local function TextContains(haystack, needle)
	local text = zo_strlower(tostring(haystack or ""))
	local search = zo_strlower(tostring(needle or ""))
	return search ~= "" and string.find(text, search, 1, true) ~= nil
end

local function BuildItemTagProbeLink(itemId)
	itemId = tonumber(itemId)
	if not itemId or itemId <= 0 then return nil end
	-- Match ItemFinder's generated link format rather than using the short H0 probe.
	-- Its quality/level payload makes generated links resolve the same item metadata
	-- that ItemFinder uses when it enumerates IDs without requiring inventory copies.
	local quality, level = 364, 50
	local itemFinder = _G and _G.ItemFinder
	if type(itemFinder) == "table" and type(itemFinder.Default) == "table" then
		quality = tonumber(itemFinder.Default.quality) or quality
		level = tonumber(itemFinder.Default.level) or level
	end
	return string.format("|H1:item:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h", itemId, quality, level)
end

local ITEM_TAG_REFERENCE_CACHE = {}

local function ParseItemTagReference(value)
	local itemId, tagIndex, category = string.match(tostring(value or ""), "^tagref:(%d+):(%d+):(%d+)$")
	if not itemId or not tagIndex or not category then return nil end
	return tonumber(itemId), tonumber(tagIndex), tonumber(category)
end

local function ParseItemTagGroup(value)
	local body = string.match(tostring(value or ""), "^taggroup:(.+)$")
	if not body then return nil end
	local references = {}
	for reference in string.gmatch(body, "([^|]+)") do
		if ParseItemTagReference(reference) then references[#references + 1] = reference end
	end
	return (#references > 0) and references or nil
end

local function GetItemTagReferenceInfo(reference)
	local cached = ITEM_TAG_REFERENCE_CACHE[reference]
	if cached then return cached.description, cached.category end
	local itemId, tagIndex = ParseItemTagReference(reference)
	if not itemId or not tagIndex then return nil end
	local itemLink = BuildItemTagProbeLink(itemId)
	local api = _G and _G.GetItemLinkItemTagInfo
	if not itemLink or type(api) ~= "function" then return nil end
	local ok, description, category = pcall(api, itemLink, tagIndex)
	if ok and type(description) == "string" and description ~= "" then
		ITEM_TAG_REFERENCE_CACHE[reference] = {description = description, category = tonumber(category)}
		return description, tonumber(category)
	end
	return nil
end

local function FormatItemTagDisplayLabel(description)
	if type(description) ~= "string" or description == "" then return description end
	-- GetItemTagReferenceLabel may already have formatted this label for the summary.
	if string.sub(description, 1, 2) == "°" and string.sub(description, -2) == "°" then return description end
	-- ESO exposes raw localized tag names with grammar suffixes such as ^f/^p.
	-- The game's own formatter removes those markers and adds the tooltip's degree signs.
	if _G and _G.SI_TOOLTIP_ITEM_TAG_FORMATER and type(zo_strformat) == "function" then
		local ok, formatted = pcall(zo_strformat, _G.SI_TOOLTIP_ITEM_TAG_FORMATER, description)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	if type(zo_strformat) == "function" then
		local ok, formatted = pcall(zo_strformat, "<<C:1>>", description)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	return (string.gsub(description, "%^[%a][%a]?", ""))
end

local function GetItemTagReferenceLabel(reference)
	local group = ParseItemTagGroup(reference)
	if group then return GetItemTagReferenceLabel(group[1]) end
	local description = GetItemTagReferenceInfo(reference)
	if description and description ~= "" then return FormatItemTagDisplayLabel(description) end
	return nil
end

local TAG_SOURCE_ITEM_TYPE_CACHE = {}
local function GetTagReferenceSourceItemType(reference)
	local itemId = ParseItemTagReference(reference)
	if not itemId then return nil end
	if TAG_SOURCE_ITEM_TYPE_CACHE[itemId] ~= nil then return TAG_SOURCE_ITEM_TYPE_CACHE[itemId] or nil end
	local itemLink = BuildItemTagProbeLink(itemId)
	local itemType = itemLink and SafeGetItemLinkValue("GetItemLinkItemType", itemLink) or nil
	itemType = tonumber(itemType)
	TAG_SOURCE_ITEM_TYPE_CACHE[itemId] = itemType or false
	return itemType
end

local function IsFoodOrDrinkTagReference(reference)
	local members = ParseItemTagGroup(reference)
	if members then
		for _, member in ipairs(members) do if IsFoodOrDrinkTagReference(member) then return true end end
		return false
	end
	local itemType = GetTagReferenceSourceItemType(reference)
	-- Provisioning tags such as Coffee, Cheese, Tea, and Sweets can be exposed
	-- by ingredient items as well as by prepared food/drink consumables.
	return itemType ~= nil and (itemType == _G.ITEMTYPE_FOOD or itemType == _G.ITEMTYPE_DRINK or itemType == _G.ITEMTYPE_INGREDIENT)
end

local function ItemHasTagText(itemLink, query)
	if not itemLink or not query or query == "" then return false end
	local targetReferences = {}
	local tagGroup = ParseItemTagGroup(query)
	if tagGroup then
		for _, reference in ipairs(tagGroup) do
			local itemId, tagIndex, category = ParseItemTagReference(reference)
			local description, resolvedCategory = GetItemTagReferenceInfo(reference)
			if itemId and description then
				targetReferences[#targetReferences + 1] = {description = description, category = tonumber(resolvedCategory) or category}
			end
		end
	elseif ParseItemTagReference(query) then
		local _, _, category = ParseItemTagReference(query)
		local description, resolvedCategory = GetItemTagReferenceInfo(query)
		if description then targetReferences[1] = {description = description, category = tonumber(resolvedCategory) or category} end
	end
	if (tagGroup or ParseItemTagReference(query)) and #targetReferences == 0 then return false end
	local count = SafeGetItemLinkValue("GetItemLinkNumItemTags", itemLink)
	count = tonumber(count) or 0
	for index = 1, count do
		local api = _G and _G.GetItemLinkItemTagInfo
		if type(api) == "function" then
			local ok, description, category = pcall(api, itemLink, index)
			if ok then
				if #targetReferences > 0 then
					-- A grouped option matches the same localized tag label across all
					-- category IDs that ESO exposes under that label.
					for _, target in ipairs(targetReferences) do
						if zo_strlower(tostring(description or "")) == zo_strlower(tostring(target.description or ""))
							and tonumber(category) == tonumber(target.category) then return true end
					end
				else
					-- Compatibility path for older rules saved as plain localized text.
					if TextContains(description, query) then return true end
					if description and _G.SI_TOOLTIP_ITEM_TAG_FORMATER and type(zo_strformat) == "function" then
						local formatOk, formattedTag = pcall(zo_strformat, _G.SI_TOOLTIP_ITEM_TAG_FORMATER, description)
						if formatOk and TextContains(formattedTag, query) then return true end
					end
					if type(category) == "number" and type(GetString) == "function" then
						local stringId = _G.SI_ITEMTAGCATEGORY
						if stringId then
							local stringOk, categoryText = pcall(GetString, stringId, category)
							if stringOk and TextContains(categoryText, query) then return true end
						end
					end
				end
			end
		end
	end
	return false
end

local function GetCustomFilterProperty(itemLink, field)
	if field == "quality" then return SafeGetItemLinkValue("GetItemLinkQuality", itemLink) end
	if field == "equipType" then return SafeGetItemLinkValue("GetItemLinkEquipType", itemLink) end
	if field == "armorType" then return SafeGetItemLinkValue("GetItemLinkArmorType", itemLink) end
	if field == "weaponType" then return SafeGetItemLinkValue("GetItemLinkWeaponType", itemLink) end
	if field == "itemType" then return SafeGetItemLinkValue("GetItemLinkItemType", itemLink) end
	if field == "specializedType" then
		local _, specialized = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
		return specialized
	end
	if field == "traitInfo" then
		-- ESO's trait-information API is the canonical cross-equipment lookup for
		-- Intricate and Ornate. Unlike trait-type enums, this works across weapon,
		-- armor, and jewelry variants that use different underlying trait IDs.
		return SafeGetItemLinkValue("GetItemTraitInformationFromItemLink", itemLink)
	end
	return nil
end

local function SpecializedTypeValueMatches(actualValue, filterValue)
	local actual = tonumber(actualValue)
	if not actual then return false end
	local grouped = string.match(tostring(filterValue or ""), "^specializedGroup:(.+)$")
	if grouped then
		for id in string.gmatch(grouped, "([^,]+)") do
			if tonumber(id) == actual then return true end
		end
		return false
	end
	return tonumber(filterValue) == actual
end

local function GroupedEnumValueMatches(actualValue, filterValue, groupPrefix)
	local actual = tonumber(actualValue)
	if not actual then return false end
	local grouped = string.match(tostring(filterValue or ""), "^" .. groupPrefix .. "(.+)$")
	if grouped then
		for id in string.gmatch(grouped, "([^,]+)") do
			if tonumber(id) == actual then return true end
		end
		return false
	end
	return tonumber(filterValue) == actual
end

-- Keep this parser above SpecializedTypeOptionContains so that its local
-- binding is in scope when summaries resolve saved option values.
local function ParseFoodGroup(value)
	local body = string.match(tostring(value or ""), "^foodGroup:(.+)$")
	if not body then return nil end
	local members = {}
	for member in string.gmatch(body, "([^;]+)") do members[#members + 1] = member end
	return (#members > 0) and members or nil
end

local function SpecializedTypeOptionContains(optionValue, storedValue)
	if tostring(optionValue) == tostring(storedValue) then return true end
	local optionText = tostring(optionValue or "")
	local storedText = tostring(storedValue or "")
	local target = tonumber(storedText)
	local grouped = string.match(optionText, "^specializedGroup:(.+)$")
		or string.match(optionText, "^weaponTypeGroup:(.+)$")
		or string.match(optionText, "^itemTypeGroup:(.+)$")
		or string.match(optionText, "^recipeSpecializedGroup:(.+)$")
	if grouped and target then
		for id in string.gmatch(grouped, "([^,]+)") do
			if tonumber(id) == target then return true end
		end
	end
	local foodGrouped = ParseFoodGroup(optionText)
	if foodGrouped then
		for _, member in ipairs(foodGrouped) do if member == storedText then return true end end
	end
	return false
end

-- ESO exposes a complete, localized furnishing category/subcategory taxonomy through
-- the Furniture API. Use it directly instead of relying on a numeric item-ID sweep of
-- visible item tags, which can never guarantee that every furnishing was discovered.
local function GetFurnitureCategoryDisplayName(categoryId)
	categoryId = tonumber(categoryId)
	if not categoryId then return nil end
	local getName = _G and _G.GetFurnitureCategoryName
	if type(getName) == "function" then
		local ok, name = pcall(getName, categoryId)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	local getInfo = _G and _G.GetFurnitureCategoryInfo
	if type(getInfo) == "function" then
		local ok, name = pcall(getInfo, categoryId)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	return nil
end

local function GetNativeFurnishingTaxonomyLabel(value)
	local categoryId = string.match(tostring(value or ""), "^furnishingCategory:(%d+)$")
	if categoryId then return GetFurnitureCategoryDisplayName(categoryId) end
	local groupBody = string.match(tostring(value or ""), "^furnishingSubcategoryGroup:(.+)$")
	if groupBody then
		local firstPair = string.match(groupBody, "([^,]+)")
		local subcategoryId
		if firstPair then
			local _, parsedSubcategoryId = string.match(firstPair, "^(%d+):(%d+)$")
			subcategoryId = parsedSubcategoryId
		end
		return subcategoryId and GetFurnitureCategoryDisplayName(subcategoryId) or nil
	end
	local parentId, subcategoryId = string.match(tostring(value or ""), "^furnishingSubcategory:(%d+):(%d+)$")
	if parentId and subcategoryId then return GetFurnitureCategoryDisplayName(subcategoryId) end
	return nil
end

local function DoesFurnishingTaxonomyValueMatch(itemLink, value)
	local categoryId = string.match(tostring(value or ""), "^furnishingCategory:(%d+)$")
	local groupBody = string.match(tostring(value or ""), "^furnishingSubcategoryGroup:(.+)$")
	local parentId, subcategoryId = string.match(tostring(value or ""), "^furnishingSubcategory:(%d+):(%d+)$")
	if not categoryId and not groupBody and not (parentId and subcategoryId) then return false end
	local getFurnitureDataId = _G and _G.GetItemLinkFurnitureDataId
	local getCategoryInfo = _G and _G.GetFurnitureDataCategoryInfo
	if type(getFurnitureDataId) ~= "function" or type(getCategoryInfo) ~= "function" then return false end
	local idOk, furnitureDataId = pcall(getFurnitureDataId, itemLink)
	furnitureDataId = idOk and tonumber(furnitureDataId) or nil
	if not furnitureDataId or furnitureDataId <= 0 then return false end
	local infoOk, actualCategoryId, actualSubcategoryId = pcall(getCategoryInfo, furnitureDataId)
	if not infoOk or actualCategoryId == nil then return false end
	if categoryId then return tonumber(actualCategoryId) == tonumber(categoryId) end
	if groupBody then
		for pair in string.gmatch(groupBody, "([^,]+)") do
			local pairCategory, pairSubcategory = string.match(pair, "^(%d+):(%d+)$")
			if tonumber(actualCategoryId) == tonumber(pairCategory) and tonumber(actualSubcategoryId) == tonumber(pairSubcategory) then return true end
		end
		return false
	end
	return tonumber(actualCategoryId) == tonumber(parentId) and tonumber(actualSubcategoryId) == tonumber(subcategoryId)
end

local function DoesFoodFilterValueMatch(itemLink, value)
	local group = ParseFoodGroup(value)
	if group then
		for _, member in ipairs(group) do
			if DoesFoodFilterValueMatch(itemLink, member) then return true end
		end
		return false
	end
	local specializedId = string.match(tostring(value or ""), "^foodSpecializedType:(%d+)$")
	if specializedId then
		local _, actualSpecializedType = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
		return tonumber(actualSpecializedType) == tonumber(specializedId)
	end
	local itemTypeId = string.match(tostring(value or ""), "^foodItemType:(%d+)$")
	if itemTypeId then
		local actualItemType = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
		return tonumber(actualItemType) == tonumber(itemTypeId)
	end
	return ItemHasTagText(itemLink, tostring(value))
end

local function DoesCustomFilterMatch(itemLink, filterData)
	if not itemLink or itemLink == "" or type(filterData) ~= "table" then return false end
	local searchString = tostring(filterData.searchString or "")
	local hasCondition = searchString ~= ""
	if searchString ~= "" and not TextContains(GetItemLinkName(itemLink), searchString) then return false end

	for _, specification in ipairs(filterData.specifications or {}) do
		local field = specification.field
		local values = specification.values or {}
		if #values > 0 then
			hasCondition = true
			local matched = false
			if field == "foodTag" then
				for _, value in ipairs(values) do
					if DoesFoodFilterValueMatch(itemLink, value) then matched = true break end
				end
			elseif field == "recipe" then
				local actualItemType, actualSpecializedType = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
				for _, value in ipairs(values) do
					local recipeItemType = string.match(tostring(value or ""), "^recipeItemType:(%d+)$")
					local recipeSpecializedType = string.match(tostring(value or ""), "^recipeSpecializedType:(%d+)$")
					if recipeItemType and tonumber(actualItemType) == tonumber(recipeItemType) then matched = true break end
					if recipeSpecializedType and tonumber(actualSpecializedType) == tonumber(recipeSpecializedType) then matched = true break end
					if GroupedEnumValueMatches(actualSpecializedType, value, "recipeSpecializedGroup:") then matched = true break end
				end
			elseif field == "itemType" then
				local actualItemType = GetCustomFilterProperty(itemLink, "itemType")
				for _, value in ipairs(values) do
					if GroupedEnumValueMatches(actualItemType, value, "itemTypeGroup:") then matched = true break end
				end
			elseif field == "tagContains" or field == "treasureType" then
				for _, value in ipairs(values) do
					if ItemHasTagText(itemLink, tostring(value)) then matched = true break end
				end
			elseif field == "furnitureBehavior" then
				for _, value in ipairs(values) do
					if DoesFurnishingTaxonomyValueMatch(itemLink, tostring(value)) or ItemHasTagText(itemLink, tostring(value)) then matched = true break end
				end
			else
				local actualValue = GetCustomFilterProperty(itemLink, field)
				for _, value in ipairs(values) do
					if field == "specializedType" then
						if SpecializedTypeValueMatches(actualValue, value) then matched = true break end
					elseif field == "weaponType" then
						if GroupedEnumValueMatches(actualValue, value, "weaponTypeGroup:") then matched = true break end
					elseif actualValue ~= nil and tonumber(actualValue) == tonumber(value) then
						matched = true
						break
					end
				end
			end
			if not matched then return false end
		end
	end
	return hasCondition
end

local function GetCustomFilterRuleName(filterId)
	return "customFilter_" .. tostring(filterId)
end

-- Keep unnamed filters compact in rule lists. The full search/specification
-- details remain available in the tooltip and in the rule editor.
function C.GetCustomFilterDisplayName(filterId, filterData)
	local displayName = tostring(filterData and filterData.displayName or "")
	displayName = string.gsub(displayName, "^%s*(.-)%s*$", "%1")
	if displayName ~= "" then return displayName end
	local searchString = tostring(filterData and filterData.searchString or "")
	if searchString ~= "" then return searchString end
	return GetString(BMR_CUSTOM_FILTER_RULE_SHORT) .. " " .. tostring(filterId)
end

function C.FindActiveCustomFilterRule(itemLink, profileRules)
	local ids = {}
	for filterId, filterData in pairs(db.customFilterRules or {}) do
		if type(filterData) == "table" and tonumber(filterId) then table.insert(ids, tostring(filterId)) end
	end
	table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
	for _, filterId in ipairs(ids) do
		local ruleName = GetCustomFilterRuleName(filterId)
		local rule = profileRules and profileRules[ruleName]
		local filterData = db.customFilterRules[filterId] or db.customFilterRules[tonumber(filterId)]
		if rule and rule.action ~= nil and rule.action ~= ACTION_NOTSET and DoesCustomFilterMatch(itemLink, filterData) then
			return ruleName, rule
		end
	end
	return nil, nil
end

function C.SyncFilterRuleDefinitions()
	if not (BankManagerRules and BankManagerRules.data and BankManagerRules.defaults) then return end
	db.customFilterRules = db.customFilterRules or {}
	-- Remove stale definitions after a filter is deleted.
	for ruleName in pairs(BankManagerRules.data) do
		local filterId = type(ruleName) == "string" and tonumber(string.match(ruleName, "^customFilter_(%d+)$")) or nil
		if filterId and not db.customFilterRules[tostring(filterId)] and not db.customFilterRules[filterId] then
			BankManagerRules.data[ruleName] = nil
			BankManagerRules.defaults[ruleName] = nil
			for _, profile in pairs(db.profiles or {}) do if profile.rules then profile.rules[ruleName] = nil end end
		end
	end
	for filterId, filterData in pairs(db.customFilterRules) do
		local numericId = tonumber(filterId)
		if numericId and type(filterData) == "table" then
			local key = tostring(numericId)
			local ruleName = GetCustomFilterRuleName(key)
			filterData.id = numericId
			filterData.searchString = tostring(filterData.searchString or "")
			filterData.specifications = type(filterData.specifications) == "table" and filterData.specifications or {}
			local function MatchSavedFilter(itemLink)
				local saved = db.customFilterRules[key] or db.customFilterRules[numericId]
				return DoesCustomFilterMatch(itemLink, saved)
			end
			BankManagerRules.data[ruleName] = {
				params = {{func = MatchSavedFilter, funcArgs = BMR_ITEMLINK, values = {true}}},
				position = 9997,
				name = C.GetCustomFilterDisplayName(key, filterData),
				tooltip = tostring(filterData.summary or filterData.name or "Specific Filter " .. key),
			}
			BankManagerRules.defaults[ruleName] = BankManagerRules.defaults[ruleName] or {
				action = ACTION_NOTSET,
				associatedGuild = GetString(BMR_ACTION_NOTSET),
				onlyIfNotFullStack = true,
				onlyStacks = 1,
			}
			for _, profile in pairs(db.profiles or {}) do
				if type(profile) == "table" then
					profile.rules = profile.rules or {}
					profile.rules.customFilterAll = profile.rules.customFilterAll or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
					if profile.rules[ruleName] == nil then
						profile.rules[ruleName] = {
							action = ACTION_NOTSET,
							associatedGuild = profile.rules.customFilterAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
							onlyIfNotFullStack = profile.rules.customFilterAll.onlyIfNotFullStack ~= false,
							onlyStacks = tonumber(profile.rules.customFilterAll.onlyStacks) or 1,
						}
					end
				end
			end
		end
	end
end


function C.SyncExactItemRuleDefinitions()
	db.customItemRules = db.customItemRules or {}
	-- Remove orphaned custom rule definitions/profile entries so the UI and rule
	-- engine always match the saved customItemRules list.
	for ruleName in pairs(BankManagerRules.data or {}) do
		local numericId = type(ruleName) == "string" and tonumber(string.match(ruleName, "^customItem_(%d+)$")) or nil
		if numericId and not db.customItemRules[tostring(numericId)] and not db.customItemRules[numericId] then
			BankManagerRules.data[ruleName] = nil
			if BankManagerRules.defaults then BankManagerRules.defaults[ruleName] = nil end
			for _, profile in pairs(db.profiles or {}) do
				if profile.rules then profile.rules[ruleName] = nil end
			end
		end
	end
	for itemId, itemData in pairs(db.customItemRules) do
		local numericId = tonumber(itemId)
		if numericId and type(itemData) == "table" then
			local ruleName = "customItem_" .. tostring(numericId)
			local originalItemName = FormatCustomItemName(itemData.itemLink, itemData.name) or ("Item " .. tostring(numericId))
			-- Keep the localized ESO name separately from an optional user-facing alias.
			itemData.name = originalItemName
			local displayItemName = C.GetCustomItemDisplayName(numericId, itemData)
			BankManagerRules.data[ruleName] = {
				params = {{func = GetItemLinkItemId, funcArgs = BMR_ITEMLINK, values = {numericId}}},
				position = 9999,
				name = displayItemName,
				tooltip = itemData.itemLink or ("Item ID: " .. tostring(numericId)),
			}
			BankManagerRules.defaults[ruleName] = BankManagerRules.defaults[ruleName] or {
				action = ACTION_NOTSET,
				associatedGuild = GetString(BMR_ACTION_NOTSET),
				onlyIfNotFullStack = true,
				onlyStacks = 1,
			}
			for _, profile in pairs(db.profiles or {}) do
				if type(profile) == "table" then
					profile.rules = profile.rules or {}
					profile.rules.customItemsAll = profile.rules.customItemsAll or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
					if profile.rules[ruleName] == nil then
						profile.rules[ruleName] = {
							action = ACTION_NOTSET,
							associatedGuild = profile.rules.customItemsAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
							onlyIfNotFullStack = profile.rules.customItemsAll.onlyIfNotFullStack ~= false,
							onlyStacks = tonumber(profile.rules.customItemsAll.onlyStacks) or 1,
						}
					end
				end
			end
		end
	end

	
end


C._RuleUi = C._RuleUi or {}
function C._RuleUi.GetCustomGuildChoices()
	local unset = GetString(BMR_ACTION_NOTSET)
	local choices = {{name = unset, value = unset, slot = 0}}
	local count = 0
	if type(GetNumGuilds) == "function" and type(GetGuildId) == "function" and type(GetGuildName) == "function" then
		local ok, value = pcall(GetNumGuilds)
		if ok then count = tonumber(value) or 0 end
	end
	for slot = 1, count do
		local okId, guildId = pcall(GetGuildId, slot)
		if okId then
			local okName, guildName = pcall(GetGuildName, guildId)
			if not okName or type(guildName) ~= "string" or guildName == "" then guildName = "Guild " .. tostring(slot) end
			choices[#choices + 1] = {name = tostring(slot) .. " - " .. guildName, value = guildName, slot = slot}
		end
	end
	return choices
end

function C._RuleUi.GetCustomProfileRule(ruleName, aggregateRuleName)
	local profile = db.profiles and db.profiles[ActualProfile()]
	if not profile then return nil end
	profile.rules = profile.rules or {}
	local rule = profile.rules[ruleName]
	if type(rule) ~= "table" then
		local aggregate = profile.rules[aggregateRuleName] or {}
		rule = {
			action = ACTION_NOTSET,
			associatedGuild = aggregate.associatedGuild or GetString(BMR_ACTION_NOTSET),
			onlyIfNotFullStack = aggregate.onlyIfNotFullStack ~= false,
			onlyStacks = tonumber(aggregate.onlyStacks) or 1,
		}
		profile.rules[ruleName] = rule
	end
	return rule
end

function C._RuleUi.SetCustomProfileRuleGuild(ruleName, aggregateRuleName, guildName)
	local rule = C._RuleUi.GetCustomProfileRule(ruleName, aggregateRuleName)
	if not rule then return false end
	rule.associatedGuild = guildName or GetString(BMR_ACTION_NOTSET)
	FireBmrRuleCountRefresh()
	return true
end

function C._RuleUi.GetCustomGuildSlotLabel(guildName)
	if not guildName or guildName == "" or guildName == GetString(BMR_ACTION_NOTSET) then return "-" end
	for _, choice in ipairs(C._RuleUi.GetCustomGuildChoices()) do if choice.value == guildName then return tostring(choice.slot) end end
	return "?"
end

function C._RuleUi.CreateCustomGuildCombo(row, uniqueId)
	if row.bmrGuildDropdown then return row.bmrGuildContainer, row.bmrGuildDropdown end
	row.bmrGuildContainer = WINDOW_MANAGER:CreateControlFromVirtual("BMRCustomGuildCombo_" .. tostring(uniqueId), row, "ZO_ComboBox")
	row.bmrGuildContainer:SetDimensions(92, 28)
	row.bmrGuildDropdown = ZO_ComboBox_ObjectFromContainer(row.bmrGuildContainer)
	row.bmrGuildDropdown:SetSortsItems(false)
	row.bmrGuildContainer:SetMouseEnabled(true)
	row.bmrGuildContainer:SetHandler("OnMouseEnter", function(self)
		if InformationTooltip and InitializeTooltip then
			InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
			if InformationTooltip.AddLine then InformationTooltip:AddLine(GetString(BMR_GUILD_LIST_TOOLTIP)) end
		end
	end)
	row.bmrGuildContainer:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
	return row.bmrGuildContainer, row.bmrGuildDropdown
end

function C._RuleUi.RefreshCustomGuildCombo(row, ruleName, aggregateRuleName)
	local combo = row and row.bmrGuildDropdown
	if not combo then return end
	local rule = C._RuleUi.GetCustomProfileRule(ruleName, aggregateRuleName)
	local currentGuild = rule and rule.associatedGuild or GetString(BMR_ACTION_NOTSET)
	combo:ClearItems()
	local selectedName, selectedShort = GetString(BMR_ACTION_NOTSET), "-"
	for _, choice in ipairs(C._RuleUi.GetCustomGuildChoices()) do
		local label, value, slot = choice.name, choice.value, choice.slot
		local selectedGuildValue, selectedGuildSlot = value, slot
		local entry = combo:CreateItemEntry(label, function()
			C._RuleUi.SetCustomProfileRuleGuild(ruleName, aggregateRuleName, selectedGuildValue)
			if combo.SetSelectedItemText then combo:SetSelectedItemText(selectedGuildSlot == 0 and "-" or tostring(selectedGuildSlot)) end
		end)
		combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
		if value == currentGuild then
			selectedName = label
			selectedShort = slot == 0 and "-" or tostring(slot)
		end
	end
	combo:SetSelectedItem(selectedName)
	if combo.SetSelectedItemText then combo:SetSelectedItemText(selectedShort) end
end

function C._RuleUi.GetCustomRuleColumnLayout(width)
	width = math.max(400, tonumber(width) or 585)
	local removeWidth = math.max(82, math.min(96, width * 0.13))
	local actionWidth = width * 0.44 -- Match the action column in normal categories.
	local guildPopupWidth = math.max(92, math.min(112, width * 0.145))
	local guildWidth = math.max(48, math.min(52, width * 0.08))
	local gap = 7
	-- Right-to-left fixed columns: GB, Action, Remove. The item label gets
	-- every remaining pixel on the left and therefore remains left aligned.
	local guildX = width - guildWidth
	local actionX = guildX - gap - actionWidth
	local removeX = actionX - gap - removeWidth
	return {
		labelX = 0, labelWidth = math.max(60, removeX - gap),
		guildX = guildX, guildWidth = guildWidth, guildPopupWidth = guildPopupWidth,
		removeX = removeX, removeWidth = removeWidth,
		actionX = actionX, actionWidth = actionWidth,
	}
end

function C._RuleUi.CreateCustomRuleTableHeader(control)
	if control.bmrHeader then return end
	control.bmrHeader = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
	control.bmrHeader:SetDimensions(control:GetWidth(), 24)
	control.bmrHeader:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
	control.bmrHeaderLabels = {}
	for index = 1, 4 do
		local label = WINDOW_MANAGER:CreateControl(nil, control.bmrHeader, CT_LABEL)
		label:SetFont("ZoFontWinH4")
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		control.bmrHeaderLabels[index] = label
	end
	control.bmrHeaderLabels[1]:SetText(GetString(BMR_RULE_TABLE_ITEM))
	control.bmrHeaderLabels[2]:SetText(GetString(BMR_CUSTOM_RULE_REMOVE_SHORT))
	control.bmrHeaderLabels[3]:SetText(GetString(BMR_RULE_TABLE_ACTION))
	control.bmrHeaderLabels[4]:SetText(GetString(BMR_GUILD_LIST_SHORT))
	control.bmrHeaderLabels[4]:SetMouseEnabled(true)
	control.bmrHeaderLabels[4]:SetHandler("OnMouseEnter", function(self)
		if InformationTooltip and InitializeTooltip then
			InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
			if InformationTooltip.AddLine then InformationTooltip:AddLine(GetString(BMR_GUILD_LIST_TOOLTIP)) end
		end
	end)
	control.bmrHeaderLabels[4]:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
end

function C._RuleUi.LayoutCustomRuleHeader(control)
	if not control.bmrHeader then return end
	local columns = C._RuleUi.GetCustomRuleColumnLayout(control:GetWidth())
	control.bmrHeader:SetWidth(control:GetWidth())
	local labels = control.bmrHeaderLabels
	labels[1]:ClearAnchors(); labels[1]:SetAnchor(LEFT, control.bmrHeader, LEFT, columns.labelX, 0); labels[1]:SetDimensions(columns.labelWidth, 24)
	labels[2]:ClearAnchors(); labels[2]:SetAnchor(LEFT, control.bmrHeader, LEFT, columns.removeX, 0); labels[2]:SetDimensions(columns.removeWidth, 24)
	labels[3]:ClearAnchors(); labels[3]:SetAnchor(LEFT, control.bmrHeader, LEFT, columns.actionX, 0); labels[3]:SetDimensions(columns.actionWidth, 24)
	labels[4]:ClearAnchors(); labels[4]:SetAnchor(RIGHT, control.bmrHeader, RIGHT, 0, 0); labels[4]:SetDimensions(columns.guildWidth, 24)
end

function C._RuleUi.LayoutCustomRuleRow(row, control)
	local columns = C._RuleUi.GetCustomRuleColumnLayout(control:GetWidth())
	row:SetWidth(control:GetWidth())
	row.label:ClearAnchors(); row.label:SetAnchor(LEFT, row, LEFT, columns.labelX, 0); row.label:SetDimensions(columns.labelWidth, 32)
	row.bmrGuildContainer:ClearAnchors(); row.bmrGuildContainer:SetAnchor(RIGHT, row, RIGHT, 0, 0); row.bmrGuildContainer:SetDimensions(columns.guildWidth, 28)
	-- m_containerWidth controls the opened list width; the closed selector
	-- is sized independently by bmrGuildContainer above.
	row.bmrGuildDropdown.m_containerWidth = columns.guildPopupWidth
	if row.bmrGuildDropdown.m_dropdown and row.bmrGuildDropdown.m_dropdown.SetWidth then
		row.bmrGuildDropdown.m_dropdown:SetWidth(columns.guildPopupWidth)
	end
	row.removeButton:ClearAnchors(); row.removeButton:SetAnchor(LEFT, row, LEFT, columns.removeX, 0); row.removeButton:SetDimensions(columns.removeWidth, 28)
	row.dropdownContainer:ClearAnchors(); row.dropdownContainer:SetAnchor(LEFT, row, LEFT, columns.actionX, 0); row.dropdownContainer:SetDimensions(columns.actionWidth, 28)
	row.dropdown.m_containerWidth = columns.actionWidth
end

-- Dynamic item-rule list: LAM creates ordinary controls only once, so this custom
-- widget rebuilds the per-item rows in-place whenever rules are added or removed.
function C.RefreshCustomRuleList(control)
	if not control then return end
	control.bmrRows = control.bmrRows or {}
	C._RuleUi.CreateCustomRuleTableHeader(control)
	C._RuleUi.LayoutCustomRuleHeader(control)
	local itemIds = {}
	for itemId in pairs(db.customItemRules or {}) do table.insert(itemIds, tostring(itemId)) end
	table.sort(itemIds, function(a, b) return tonumber(a) < tonumber(b) end)
	local actions = {
		{label = GetString(BMR_ACTION_NOTSET), value = ACTION_NOTSET},
		{label = GetString(BMR_ACTION_PUSH), value = ACTION_PUSH},
		{label = GetString(BMR_ACTION_PULL), value = ACTION_PULL},
		{label = GetString(BMR_ACTION_PUSH_ALL_STACKS), value = ACTION_PUSH_ALL_STACKS},
		{label = GetString(BMR_ACTION_PULL_ALL_STACKS), value = ACTION_PULL_ALL_STACKS},
		{label = GetString(BMR_ACTION_PUSH_GBANK), value = ACTION_PUSH_GBANK},
		{label = GetString(BMR_ACTION_PUSH_BOTH), value = ACTION_PUSH_BOTH},
		{label = GetString(BMR_ACTION_KEEP_ONE_STACK), value = ACTION_KEEP_ONE_STACK},
		{label = GetString(BMR_ACTION_KEEP_ONE_STACK_BANK), value = ACTION_KEEP_ONE_STACK_BANK},
		{label = GetString(BMR_ACTION_PUSH_FURNITURE), value = ACTION_PUSH_FURNITURE},
	}
	for _, row in ipairs(control.bmrRows) do row:SetHidden(true) end
	for index, itemId in ipairs(itemIds) do
		local itemData = db.customItemRules[itemId] or db.customItemRules[tonumber(itemId)]
		local ruleName = "customItem_" .. itemId
		if itemData and BankManagerRules.data[ruleName] then
			local row = control.bmrRows[index]
			if not row then
				row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
				row:SetDimensions(control:GetWidth(), 42)
				row.label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
				row.label:SetFont("ZoFontGame")
				row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
				BMR.customRuleControlSerial = (BMR.customRuleControlSerial or 0) + 1
				local uniqueControlId = tostring(itemId) .. "_" .. tostring(BMR.customRuleControlSerial)
				row.dropdownContainer = WINDOW_MANAGER:CreateControlFromVirtual("BMRCustomRuleCombo_" .. uniqueControlId, row, "ZO_ComboBox")
				row.dropdown = ZO_ComboBox_ObjectFromContainer(row.dropdownContainer)
				row.dropdown:SetSortsItems(false)
				C._RuleUi.CreateCustomGuildCombo(row, uniqueControlId)
				row.removeButton = WINDOW_MANAGER:CreateControlFromVirtual("BMRCustomRuleRemove_" .. uniqueControlId, row, "ZO_DefaultButton")
				row.measureLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
				row.measureLabel:SetFont("ZoFontGame")
				row.measureLabel:SetDimensions(1000, 28)
				row.measureLabel:SetHidden(true)
				row.removeButton:SetHandler("OnClicked", function()
					local id = row.bmrItemId
					if id then
						local savedItem = db.customItemRules and (db.customItemRules[tostring(id)] or db.customItemRules[id])
						local name = savedItem and C.GetCustomItemDisplayName(id, savedItem) or tostring(id)
						C.RemoveCustomItemRuleById(id)
						CustomRuleDebug("removed from options: " .. tostring(name) .. " itemId=" .. tostring(id))
					end
				end)
				control.bmrRows[index] = row
			end
			row.bmrItemId = tonumber(itemId)
			row.label:SetText(C.GetCustomItemDisplayName(itemId, itemData))
			row.label:SetMouseEnabled(true)
			row.label:SetHandler("OnMouseEnter", function(self)
				if itemData.itemLink and InformationTooltip and InitializeTooltip then
					InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
					if InformationTooltip.SetLink then InformationTooltip:SetLink(itemData.itemLink) elseif InformationTooltip.AddLine then InformationTooltip:AddLine(itemData.itemLink) end
				end
			end)
			row.label:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
			row.label:SetHandler("OnMouseUp", function(self, button, upInside)
				if button == MOUSE_BUTTON_INDEX_RIGHT and upInside and type(ClearMenu) == "function" and type(AddMenuItem) == "function" and type(ShowMenu) == "function" then
					local selectedId = row.bmrItemId
					ClearMenu()
					AddMenuItem(GetString(BMR_CUSTOM_ITEM_RENAME), function() C.ShowRenameCustomItemDialog(selectedId) end)
					ShowMenu()
				end
			end)
			row:ClearAnchors()
			row:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 26 + (index - 1) * 44)
			row:SetHeight(42)
			row:SetHidden(false)
			row.removeButton:SetText(GetString(BMR_CUSTOM_RULE_REMOVE_SHORT))
			row.dropdown:ClearItems()
			local currentRule = C._RuleUi.GetCustomProfileRule(ruleName, "customItemsAll")
			local selectedLabel = GetString(BMR_ACTION_NOTSET)
			for _, action in ipairs(actions) do
				local actionValue, actionLabel = action.value, action.label
				local entry = row.dropdown:CreateItemEntry(actionLabel, function()
					local currentId = row.bmrItemId
					local currentRule = currentId and C._RuleUi.GetCustomProfileRule("customItem_" .. tostring(currentId), "customItemsAll")
					if currentRule then currentRule.action = actionValue; FireBmrRuleCountRefresh() end
				end)
				row.dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
				if currentRule and currentRule.action == action.value then selectedLabel = action.label end
			end
			row.dropdown:SetSelectedItem(selectedLabel)
			C._RuleUi.RefreshCustomGuildCombo(row, ruleName, "customItemsAll")
			C._RuleUi.LayoutCustomRuleRow(row, control)
		end
	end
	for index = #itemIds + 1, #control.bmrRows do control.bmrRows[index]:SetHidden(true) end
	control:SetHeight(math.max(30, 26 + #itemIds * 44))
end

local function FormatEnumDisplayLabel(label)
	if type(label) ~= "string" or label == "" then return label end
	-- GetString(SI_ITEMTYPE, value) may return grammatical suffixes such as ^m/^f.
	-- Run the returned enum text through ESO's formatter instead of displaying raw markers.
	if type(ZO_CachedStrFormat) == "function" then
		local ok, formatted = pcall(ZO_CachedStrFormat, "<<C:1>>", label)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	if type(zo_strformat) == "function" then
		local ok, formatted = pcall(zo_strformat, "<<C:1>>", label)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	return (string.gsub(label, "%^[%a][%a]?", ""))
end

local function FilterEnumLabel(kind, value, fallback)
	if type(GetString) == "function" then
		local stringId = nil
		if kind == "quality" then stringId = _G["SI_ITEMQUALITY" .. tostring(value)] end
		if stringId then
			local ok, label
			if type(zo_strformat) == "function" then ok, label = pcall(zo_strformat, stringId) else ok, label = pcall(GetString, stringId) end
			if ok and type(label) == "string" and label ~= "" then return FormatEnumDisplayLabel(label) end
		end
		local formatId = ({equipType = "SI_EQUIPTYPE", armorType = "SI_ARMORTYPE", itemType = "SI_ITEMTYPE", specializedType = "SI_SPECIALIZEDITEMTYPE", weaponType = "SI_WEAPONTYPE"})[kind]
		if formatId then
			-- ESO enum strings must be queried with GetString(stringId, numericValue).
			local ok, label = pcall(GetString, formatId, value)
			if ok and type(label) == "string" and label ~= "" and label ~= formatId then return FormatEnumDisplayLabel(label) end
		end
	end
	return FormatEnumDisplayLabel(fallback or tostring(value))
end

local CUSTOM_FILTER_QUALITY_FALLBACKS = {
	ITEM_QUALITY_TRASH = 0, ITEM_QUALITY_NORMAL = 1, ITEM_QUALITY_MAGIC = 2,
	ITEM_QUALITY_ARCANE = 3, ITEM_QUALITY_ARTIFACT = 4, ITEM_QUALITY_LEGENDARY = 5,
}
local function AddFilterEnumOption(options, field, constantName, fallbackLabel, seen)
	local value = _G[constantName]
	if type(value) ~= "number" and field == "quality" then value = CUSTOM_FILTER_QUALITY_FALLBACKS[constantName] end
	if type(value) == "number" and not seen[value] then
		seen[value] = true
		table.insert(options, {label = FilterEnumLabel(field, value, fallbackLabel), value = value})
	end
end

-- Stable baseline of item-tag references collected from the maintainer's full
-- SavedVariables catalog. Only numeric item/tag/category identities are stored here;
-- visible labels are always resolved from ESO's current localized item-link API.
-- This gives every account the same filter choices without running ItemFinder or
-- the long ID sweep on every account. New tags can still be learned from accessible bags.
local STATIC_ITEM_TAG_REFERENCES = {
	{28409, 2, 0}, {28465, 1, 0}, {28497, 1, 0}, {30158, 1, 0},
	{42879, 1, 0}, {54184, 1, 0}, {61090, 1, 1}, {61091, 1, 1},
	{61093, 2, 1}, {61094, 1, 1}, {61102, 2, 1}, {61110, 2, 1},
	{61117, 2, 1}, {61129, 1, 1}, {61133, 2, 1}, {61138, 1, 1},
	{61140, 1, 1}, {61156, 1, 1}, {61159, 1, 1}, {61162, 1, 1},
	{61171, 1, 1}, {61198, 1, 1}, {61205, 1, 1}, {61239, 2, 1},
	{61258, 1, 1}, {61302, 1, 1}, {61302, 2, 1}, {61319, 1, 1},
	{61341, 1, 1}, {61456, 1, 1}, {61521, 1, 1}, {61593, 2, 1},
	{61647, 1, 1}, {61718, 1, 1}, {64487, 1, 0}, {68236, 1, 0},
	{73772, 1, 1}, {87709, 1, 2}, {87709, 2, 2}, {94101, 1, 2},
	{101879, 1, 0}, {118327, 1, 2}, {118553, 1, 2}, {118553, 2, 2},
	{120082, 1, 2}, {120828, 2, 2}, {130081, 1, 2}, {130216, 3, 2},
	{138903, 1, 3}, {145493, 1, 2}, {145493, 2, 2}, {171323, 1, 0},
	{187701, 1, 0}, {190953, 1, 0}, {191151, 1, 1}, {192368, 1, 0},
	{192612, 1, 0}, {194412, 1, 0}, {194428, 1, 0}, {220261, 1, 0},
	{223790, 1, 0}, {225212, 1, 2}, {227237, 1, 0},
}

-- The full item-ID sweep is an internal catalog-maintenance tool and is deliberately
-- enabled only on the designated maintainer account. Other accounts receive the fixed
-- baseline above and can still discover extra tags naturally from items in their bags.
local TAG_SCAN_MAINTAINER_ACCOUNT = "gamer1986pan"
local function IsTagCatalogScanAllowed()
	local getter = _G and _G.GetDisplayName
	if type(getter) ~= "function" then return false end
	local ok, displayName = pcall(getter)
	if not ok then return false end
	displayName = string.lower(tostring(displayName or "")):gsub("^@", "")
	return displayName == TAG_SCAN_MAINTAINER_ACCOUNT
end

local function NotifyTagCatalogScanRestricted()
	local message = "[BMR] The full item-tag scan is restricted to @Gamer1986PAN. Built-in filter catalogs remain available on this account."
	if type(GetString) == "function" and BMR_CUSTOM_FILTER_SCAN_RESTRICTED then
		local ok, localized = pcall(GetString, BMR_CUSTOM_FILTER_SCAN_RESTRICTED)
		if ok and type(localized) == "string" and localized ~= "" then message = localized end
	end
	SendCustomRuleMessage(message)
end

local TAG_SCAN_BATCH_SIZE = 250
local TAG_SCAN_DELAY_MS = 15
local TAG_SCAN_RUNNING = false
local TAG_SCAN_MAX_DEFAULT = 500000
local TAG_SCAN_MAX_LIMIT = 1000000
local TAG_LABEL_INDEX
local TAG_ALIAS_INDEX
local TAG_REFERENCE_INDEX
local TAG_STORAGE_INDEX

local function EnsureTagCatalog()
	db.customItemTagCatalog = db.customItemTagCatalog or {}
	db.customItemTagScan = db.customItemTagScan or {nextId = 1, maxId = TAG_SCAN_MAX_DEFAULT, completed = false}
	-- Catalog format 4 preserves separate tag identities by (visible label, category).
	-- Older scans could merge equal labels from different categories into one record,
	-- which produced misleading duplicates and could overwrite a representative ref.
	if db.customItemTagScan.catalogFormatVersion ~= 4 then
		for key in pairs(db.customItemTagCatalog) do db.customItemTagCatalog[key] = nil end
		db.customItemTagScan.catalogFormatVersion = 4
		db.customItemTagScan.probeFormatVersion = 4
		db.customItemTagScan.nextId = 1
		db.customItemTagScan.maxId = TAG_SCAN_MAX_DEFAULT
		db.customItemTagScan.completed = false
	end
	-- Seed the static reference catalog for every account. Do not hard-code display
	-- strings: PrepareTagCatalogIndex refreshes them from localized ESO SI strings.
	for _, referenceData in ipairs(STATIC_ITEM_TAG_REFERENCES) do
		local itemId, tagIndex, category = referenceData[1], referenceData[2], referenceData[3]
		local key = string.format("tagref:%d:%d:%d", itemId, tagIndex, category)
		local record = db.customItemTagCatalog[key]
		if type(record) ~= "table" then record = {}; db.customItemTagCatalog[key] = record end
		record.key = key
		record.sourceItemId = tonumber(record.sourceItemId) or itemId
		record.sourceTagIndex = tonumber(record.sourceTagIndex) or tagIndex
		record.category = tonumber(record.category) or category
		record.staticCatalog = true
	end
	return db.customItemTagCatalog, db.customItemTagScan
end

local function TagReferenceKey(itemId, tagIndex, category)
	itemId, tagIndex = tonumber(itemId), tonumber(tagIndex)
	if not itemId or itemId <= 0 or not tagIndex or tagIndex <= 0 then return nil end
	return string.format("tagref:%d:%d:%d", itemId, tagIndex, tonumber(category) or 0)
end

local function TagLabelIndexKey(label, category)
	return zo_strlower(tostring(label or "")) .. "\31" .. tostring(tonumber(category) or 0)
end

local function AddTagAlias(record, label)
	label = tostring(label or "")
	if label == "" then return end
	record.aliases = record.aliases or {}
	record.aliases[zo_strlower(label)] = true
end

local function RefreshTagRecordLabel(record)
	if type(record) ~= "table" or not record.sourceItemId or not record.sourceTagIndex then return end
	local reference = TagReferenceKey(record.sourceItemId, record.sourceTagIndex, record.category)
	local label, category = GetItemTagReferenceInfo(reference)
	if label and label ~= "" then
		if record.label and zo_strlower(record.label) ~= zo_strlower(label) then AddTagAlias(record, record.label) end
		record.label = label
		if category ~= nil then record.category = category end
		record.key = TagReferenceKey(record.sourceItemId, record.sourceTagIndex, record.category) or reference
	end
end

local function PrepareTagCatalogIndex(refreshLabels)
	local catalog = EnsureTagCatalog()
	TAG_LABEL_INDEX, TAG_ALIAS_INDEX, TAG_REFERENCE_INDEX, TAG_STORAGE_INDEX = {}, {}, {}, {}
	local aliasReferenceSets = {}
	local storageKeys = {}
	for storageKey in pairs(catalog) do table.insert(storageKeys, storageKey) end
	table.sort(storageKeys, function(a, b) return tostring(a) < tostring(b) end)
	for _, storageKey in ipairs(storageKeys) do
		local record = catalog[storageKey]
		if type(record) ~= "table" then
			record = {label = tostring(record or "")}
			catalog[storageKey] = record
		end
		if refreshLabels then RefreshTagRecordLabel(record) end
		local key = record.key or TagReferenceKey(record.sourceItemId, record.sourceTagIndex, record.category) or tostring(storageKey)
		record.key = key
		-- Infer the furnishing family from persisted source references as well, so
		-- existing catalogs gain the new classification without being discarded.
		local refItemId, refTagIndex, refCategory = ParseItemTagReference(key)
		if refItemId then
			local itemType = GetTagReferenceSourceItemType(key)
			local furnishingItemType = _G and tonumber(_G.ITEMTYPE_FURNISHING)
			local furnitureBehaviorCategory = _G and tonumber(_G.TAG_CATEGORY_FURNITURE_BEHAVIOR)
			if furnishingItemType ~= nil and itemType == furnishingItemType then
				if (tonumber(refTagIndex) or 0) > 1 or (furnitureBehaviorCategory ~= nil and tonumber(refCategory) == furnitureBehaviorCategory) then
					record.furnishing = true
				elseif (tonumber(refTagIndex) or 0) == 1 and not record.furnishing then
					record.furnishingRoot = true
				end
			end
		end
		if TAG_REFERENCE_INDEX[key] == nil then TAG_REFERENCE_INDEX[key] = {storageKey = storageKey, record = record} end
		if TAG_STORAGE_INDEX[key] == nil then TAG_STORAGE_INDEX[key] = storageKey end
		local label = tostring(record.label or "")
		if label ~= "" then
			local labelIndexKey = TagLabelIndexKey(label, record.category)
			if TAG_LABEL_INDEX[labelIndexKey] == nil then TAG_LABEL_INDEX[labelIndexKey] = key end
			if ParseItemTagReference(key) then
				local plainKey = zo_strlower(label)
				aliasReferenceSets[plainKey] = aliasReferenceSets[plainKey] or {}
				aliasReferenceSets[plainKey][key] = true
			end
		end
		for alias in pairs(record.aliases or {}) do
			local aliasKey = zo_strlower(tostring(alias))
			if ParseItemTagReference(key) then
				aliasReferenceSets[aliasKey] = aliasReferenceSets[aliasKey] or {}
				aliasReferenceSets[aliasKey][key] = true
			end
		end
	end
	-- Migrate old text-only rules to all known category-specific references with
	-- that visible label, rather than silently choosing just one category.
	for aliasKey, referenceSet in pairs(aliasReferenceSets) do
		local references = {}
		for reference in pairs(referenceSet) do references[#references + 1] = reference end
		table.sort(references)
		if #references == 1 then
			TAG_ALIAS_INDEX[aliasKey] = references[1]
		elseif #references > 1 then
			TAG_ALIAS_INDEX[aliasKey] = "taggroup:" .. table.concat(references, "|")
		end
	end
	return catalog
end

local function CacheTag(description, category, sourceItemId, tagIndex, sourceItemType)
	local catalog = EnsureTagCatalog()
	local label = tostring(description or "")
	if label == "" then return false end
	if not TAG_LABEL_INDEX or not TAG_REFERENCE_INDEX then PrepareTagCatalogIndex(false) end
	local numericCategory = tonumber(category) or 0
	local referenceKey = TagReferenceKey(sourceItemId, tagIndex, numericCategory)
	local labelKey = TagLabelIndexKey(label, numericCategory)
	local selectedKey = referenceKey and TAG_REFERENCE_INDEX[referenceKey] and referenceKey or TAG_LABEL_INDEX[labelKey]

	-- Upgrade legacy text-only entries only when their category is unknown or matches.
	-- Do not use the global label alias here: identical labels in different categories
	-- are distinct tag references and must be retained for a grouped dropdown choice.
	if not selectedKey then
		for legacyKey, legacyRecord in pairs(catalog) do
			if type(legacyRecord) == "table" and not legacyRecord.sourceItemId and not legacyRecord.sourceTagIndex
				and zo_strlower(tostring(legacyRecord.label or "")) == zo_strlower(label)
				and (legacyRecord.category == nil or tonumber(legacyRecord.category) == numericCategory) then
				selectedKey = legacyKey
				break
			end
		end
	end

	local entry = selectedKey and TAG_REFERENCE_INDEX[selectedKey]
	local record = entry and entry.record or (selectedKey and catalog[selectedKey])
	local storageKey = entry and entry.storageKey or selectedKey
	local discovered = false
	-- The ESO tag taxonomy for furnishings is layered: the first tag is the
	-- broad "Furnishing" marker, followed by useful category/subcategory labels
	-- such as Workshop + Tools or Hearth + Produce. Keep those labels available
	-- in the dedicated Furnishing specification even when the same label was
	-- first discovered on a non-furnishing item.
	sourceItemType = tonumber(sourceItemType)
	local furnishingItemType = _G and tonumber(_G.ITEMTYPE_FURNISHING)
	local furnitureBehaviorCategory = _G and tonumber(_G.TAG_CATEGORY_FURNITURE_BEHAVIOR)
	local numericTagIndex = tonumber(tagIndex) or 0
	local isFurnishingSource = furnishingItemType ~= nil and sourceItemType == furnishingItemType
	local isFurnishingDetail = isFurnishingSource and (numericTagIndex > 1 or numericCategory == furnitureBehaviorCategory)
	local isFurnishingRoot = isFurnishingSource and numericTagIndex == 1 and numericCategory ~= furnitureBehaviorCategory
	if not record then
		selectedKey = referenceKey or labelKey
		record = {
			key = selectedKey,
			label = label,
			category = numericCategory,
			sourceItemId = tonumber(sourceItemId),
			sourceTagIndex = tonumber(tagIndex),
		}
		catalog[selectedKey] = record
		storageKey = selectedKey
		discovered = true
	elseif referenceKey and not (record.sourceItemId and record.sourceTagIndex) then
		-- Upgrade legacy text-only entry to a stable representative item/tag reference.
		if storageKey ~= referenceKey then catalog[storageKey] = nil end
		record.key = referenceKey
		record.sourceItemId = tonumber(sourceItemId)
		record.sourceTagIndex = tonumber(tagIndex)
		record.category = numericCategory
		catalog[referenceKey] = record
		selectedKey, storageKey = referenceKey, referenceKey
	end

	if record then
		if record.label and zo_strlower(tostring(record.label)) ~= zo_strlower(label) then AddTagAlias(record, record.label) end
		record.label = label
		record.category = numericCategory
		if not record.sourceItemId and sourceItemId then record.sourceItemId = tonumber(sourceItemId) end
		if not record.sourceTagIndex and tagIndex then record.sourceTagIndex = tonumber(tagIndex) end
		if isFurnishingDetail then record.furnishing = true end
		if isFurnishingRoot and not record.furnishing then record.furnishingRoot = true end
		record.key = TagReferenceKey(record.sourceItemId, record.sourceTagIndex, record.category) or tostring(selectedKey or storageKey)
		selectedKey = record.key
		catalog[selectedKey] = record
		TAG_REFERENCE_INDEX[selectedKey] = {storageKey = selectedKey, record = record}
		TAG_STORAGE_INDEX[selectedKey] = selectedKey
		TAG_LABEL_INDEX[labelKey] = selectedKey
		local plainKey = zo_strlower(label)
		if TAG_ALIAS_INDEX[plainKey] == nil then TAG_ALIAS_INDEX[plainKey] = selectedKey end
	end
	return discovered
end

-- Fixed baseline based on the specialized item-type IDs present in the supplied
-- SavedVariables snapshot. Runtime labels are resolved with ESO's localized
-- SI_SPECIALIZEDITEMTYPE strings; newly encountered IDs are still cached too.
local BASE_SPECIALIZED_TYPE_IDS = {
	1, 2, 3, 4, 5, 6, 7, 8, 20, 21, 22, 23,
	24, 25, 26, 27, 40, 41, 42, 43, 44, 45, 46, 47,
	48, 60, 61, 80, 81, 82, 100, 101, 102, 103, 104, 105,
	106, 107, 108, 109, 111, 112, 150, 151, 152, 170, 171, 172,
	173, 174, 175, 176, 177, 178, 210, 211, 212, 213, 214, 215,
	250, 300, 350, 400, 401, 402, 404, 405, 406, 407, 409, 450,
	500, 650, 700, 750, 800, 850, 851, 875, 890, 900, 950, 1000,
	1050, 1250, 1400, 1450, 1460, 1465, 1500, 1550, 1560, 1600, 1650, 1660,
	1700, 1750, 1760, 1800, 1850, 1900, 1950, 2000, 2050, 2100, 2150, 2300,
	2350, 2400, 2410, 2450, 2500, 2550, 2600, 2650, 2700, 2750, 2760, 2800,
	2850, 2860, 2900, 2950, 3050, 3100, 3150, 3250, 3251, 3252, 3300, 3350,
}

function C.GetSpecializedTypeCatalog()
	db.customItemSpecializedTypeCatalog = db.customItemSpecializedTypeCatalog or {}
	for _, value in ipairs(BASE_SPECIALIZED_TYPE_IDS) do
		db.customItemSpecializedTypeCatalog[tostring(value)] = true
	end
	return db.customItemSpecializedTypeCatalog
end

function C.CacheSpecializedTypeFromItemLink(itemLink)
	if type(itemLink) ~= "string" or itemLink == "" then return false end
	local _, specializedType = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
	specializedType = tonumber(specializedType)
	if not specializedType or specializedType <= 0 then return false end
	local catalog = C.GetSpecializedTypeCatalog()
	catalog[tostring(specializedType)] = true
	return true
end

local function CollectTagsFromItemLink(itemLink, explicitItemId)
	if type(itemLink) ~= "string" or itemLink == "" then return 0 end
	-- Some labels users see in an item's tooltip (e.g. "Runebox Fragment")
	-- are specialized item types, not item tags. Collect them alongside tags.
	C.CacheSpecializedTypeFromItemLink(itemLink)
	local getCount = _G and _G.GetItemLinkNumItemTags
	local getInfo = _G and _G.GetItemLinkItemTagInfo
	if type(getCount) ~= "function" or type(getInfo) ~= "function" then return 0 end
	local sourceItemId = tonumber(explicitItemId) or SafeGetItemLinkValue("GetItemLinkItemId", itemLink)
	local sourceItemTypeValue = SafeGetItemLinkValue("GetItemLinkItemType", itemLink)
	local sourceItemType = tonumber(sourceItemTypeValue)
	local ok, count = pcall(getCount, itemLink)
	if not ok then return 0 end
	local discovered = 0
	for index = 1, tonumber(count) or 0 do
		local infoOk, description, category = pcall(getInfo, itemLink, index)
		if infoOk and CacheTag(description, category, sourceItemId, index, sourceItemType) then discovered = discovered + 1 end
	end
	return discovered
end
C.CollectTagsFromItemLink = CollectTagsFromItemLink

function C.CollectTagsFromAccessibleBags()
	EnsureTagCatalog()
	if not TAG_REFERENCE_INDEX then PrepareTagCatalogIndex(true) end
	local bags, seen = {}, {}
	local function AddBag(bagId)
		if bagId ~= nil and not seen[bagId] then seen[bagId] = true; bags[#bags + 1] = bagId end
	end
	AddBag(BAG_BACKPACK)
	AddBag(BAG_WORN)
	AddBag(BAG_BANK)
	AddBag(BAG_SUBSCRIBER_BANK)
	AddBag(BAG_VIRTUAL)
	AddBag(BAG_GUILDBANK)
	AddBag(BAG_HOUSE_BANK_ONE)
	AddBag(BAG_HOUSE_BANK_TWO)
	AddBag(BAG_HOUSE_BANK_THREE)
	AddBag(BAG_HOUSE_BANK_FOUR)
	AddBag(BAG_HOUSE_BANK_FIVE)
	AddBag(BAG_HOUSE_BANK_SIX)
	AddBag(BAG_HOUSE_BANK_SEVEN)
	AddBag(BAG_HOUSE_BANK_EIGHT)
	AddBag(BAG_HOUSE_BANK_NINE)
	AddBag(BAG_HOUSE_BANK_TEN)
	AddBag(BAG_FURNITURE_VAULT)
	if type(GetBagSize) ~= "function" or type(GetItemLink) ~= "function" then return 0 end
	local discovered = 0
	for _, bagId in ipairs(bags) do
		local sizeOk, size = pcall(GetBagSize, bagId)
		if sizeOk then
			for slot = 0, (tonumber(size) or 0) - 1 do
				local linkOk, itemLink = pcall(GetItemLink, bagId, slot)
				if linkOk then discovered = discovered + CollectTagsFromItemLink(itemLink) end
			end
		end
	end
	return discovered
end

local function MigrateSavedTagValues()
	if not TAG_ALIAS_INDEX then return end
	local function MigrateFilterData(filterData)
		if type(filterData) ~= "table" then return end
		for _, specification in ipairs(filterData.specifications or {}) do
			if specification.field == "tagContains" or specification.field == "treasureType" or specification.field == "furnitureBehavior" or specification.field == "foodTag" then
				for index, value in ipairs(specification.values or {}) do
					local valueText = tostring(value or "")
					if not ParseItemTagReference(valueText) then
						local key = TAG_ALIAS_INDEX[zo_strlower(valueText)]
						if key and (ParseItemTagReference(key) or ParseItemTagGroup(key)) then specification.values[index] = key end
					end
				end
			end
		end
	end
	for _, filterData in pairs(db.customFilterRules or {}) do MigrateFilterData(filterData) end
	MigrateFilterData(db.customFilterDraft)
end

local function IsFurnishingDetailTagReference(reference)
	local members = ParseItemTagGroup(reference)
	if members then
		for _, member in ipairs(members) do
			if IsFurnishingDetailTagReference(member) then return true end
		end
		return false
	end
	local itemId, tagIndex, category = ParseItemTagReference(reference)
	if not itemId then return false end
	local entry = TAG_REFERENCE_INDEX and TAG_REFERENCE_INDEX[reference]
	if entry and entry.record and entry.record.furnishing then return true end
	local itemType = GetTagReferenceSourceItemType(reference)
	local furnishingItemType = _G and tonumber(_G.ITEMTYPE_FURNISHING)
	local furnitureBehaviorCategory = _G and tonumber(_G.TAG_CATEGORY_FURNITURE_BEHAVIOR)
	return furnishingItemType ~= nil and itemType == furnishingItemType
		and ((tonumber(tagIndex) or 0) > 1 or (furnitureBehaviorCategory ~= nil and tonumber(category) == furnitureBehaviorCategory))
end

local function IsFurnishingRootTagReference(reference)
	local members = ParseItemTagGroup(reference)
	if members then
		for _, member in ipairs(members) do
			if IsFurnishingRootTagReference(member) then return true end
		end
		return false
	end
	local itemId, tagIndex, category = ParseItemTagReference(reference)
	if not itemId then return false end
	local entry = TAG_REFERENCE_INDEX and TAG_REFERENCE_INDEX[reference]
	if entry and entry.record and entry.record.furnishingRoot and not entry.record.furnishing then return true end
	local itemType = GetTagReferenceSourceItemType(reference)
	local furnishingItemType = _G and tonumber(_G.ITEMTYPE_FURNISHING)
	local furnitureBehaviorCategory = _G and tonumber(_G.TAG_CATEGORY_FURNITURE_BEHAVIOR)
	return furnishingItemType ~= nil and itemType == furnishingItemType and (tonumber(tagIndex) or 0) == 1
		and not (furnitureBehaviorCategory ~= nil and tonumber(category) == furnitureBehaviorCategory)
end

local function IsInternalFurnishingTaxonomyKey(value)
	local normalized = zo_strlower(tostring(value or ""))
	return string.match(normalized, "^furnishingsubcategorygroup:") ~= nil
		or string.match(normalized, "^furnishingsubcategory:") ~= nil
		or string.match(normalized, "^furnishingcategory:") ~= nil
end

local function GetCustomFilterTagOptions(categoryFilter, displayMode)
	categoryFilter = tonumber(categoryFilter)
	displayMode = displayMode or (categoryFilter ~= nil and "category" or "generic")
	local catalog = PrepareTagCatalogIndex(true)
	C.CollectTagsFromAccessibleBags()
	catalog = PrepareTagCatalogIndex(true)
	MigrateSavedTagValues()

	local treasureCategory = _G and tonumber(_G.TAG_CATEGORY_TREASURE_TYPE)
	local furnitureCategory = _G and tonumber(_G.TAG_CATEGORY_FURNITURE_BEHAVIOR)
	local function ReferenceAllowed(reference, category)
		local members = ParseItemTagGroup(reference)
		if members then
			for _, member in ipairs(members) do
				local _, memberCategory = GetItemTagReferenceInfo(member)
				if ReferenceAllowed(member, memberCategory or select(3, ParseItemTagReference(member))) then return true end
			end
			return false
		end
		local itemId, _, encodedCategory = ParseItemTagReference(reference)
		category = tonumber(category) or encodedCategory
		if categoryFilter ~= nil and category ~= categoryFilter then return false end
		if displayMode == "category" then return categoryFilter == nil or category == categoryFilter end
		if displayMode == "treasure" then return treasureCategory ~= nil and category == treasureCategory end
		if displayMode == "furniture" then
			-- Category/subcategory taxonomy is enumerated from ESO's Furniture API below.
			-- This scanned-tag list is reserved for actual behavior tags such as Light,
			-- Sittable and Readable; otherwise names like Workshop/Tools would be duplicated.
			return furnitureCategory ~= nil and category == furnitureCategory
		end
		if displayMode == "food" then return itemId ~= nil and IsFoodOrDrinkTagReference(reference) end
		-- Generic Item-Tag excludes the newly separated tag families.
		if treasureCategory ~= nil and category == treasureCategory then return false end
		if furnitureCategory ~= nil and category == furnitureCategory then return false end
		if IsFurnishingDetailTagReference(reference) or IsFurnishingRootTagReference(reference) then return false end
		if itemId and IsFoodOrDrinkTagReference(reference) then return false end
		return true
	end

	-- Merge identical visible labels while retaining their actual tag references.
	-- Tag references are filtered individually so a label shared with another item
	-- family can still appear in the appropriate specification.
	local groups = {}
	local function AddGroupedOption(labelValue, optionValue, optionCategory)
		local originalLabel = tostring(labelValue or "")
		local rawValue = tostring(optionValue or originalLabel)
		-- These are internal value encodings used by the native Furnishing taxonomy,
		-- not real ESO item tags. Hide legacy copies from all item-tag dropdowns.
		if IsInternalFurnishingTaxonomyKey(originalLabel) or IsInternalFurnishingTaxonomyKey(rawValue) then return end
		local label = FormatItemTagDisplayLabel(originalLabel)
		if label == "" or rawValue == "" then return end
		local filteredReferences = {}
		local members = ParseItemTagGroup(rawValue)
		if members then
			for _, member in ipairs(members) do
				local _, memberCategory = GetItemTagReferenceInfo(member)
				if ReferenceAllowed(member, memberCategory or select(3, ParseItemTagReference(member))) then filteredReferences[#filteredReferences + 1] = member end
			end
		elseif ParseItemTagReference(rawValue) then
			local _, resolvedCategory = GetItemTagReferenceInfo(rawValue)
			if ReferenceAllowed(rawValue, resolvedCategory or optionCategory) then filteredReferences[1] = rawValue end
		elseif displayMode == "generic" and categoryFilter == nil then
			-- Keep older text-only tag entries in the general list until they can be upgraded.
			filteredReferences[1] = rawValue
		end
		if #filteredReferences == 0 then return end
		local value = filteredReferences[1]
		if #filteredReferences > 1 then value = "taggroup:" .. table.concat(filteredReferences, "|") end
		local groupKey = zo_strlower(label)
		if not groups[groupKey] then groups[groupKey] = {label = label, references = {}, legacy = {}} end
		local group = groups[groupKey]
		if ParseItemTagReference(value) then group.references[value] = true
		elseif ParseItemTagGroup(value) then for _, reference in ipairs(ParseItemTagGroup(value)) do group.references[reference] = true end
		else group.legacy[value] = true end
	end

	for catalogKey, record in pairs(catalog) do
		if type(record) == "table" then
			AddGroupedOption(record.label, record.key or catalogKey, record.category)
		else
			AddGroupedOption(record, catalogKey, nil)
		end
	end
	local function AddSaved(source)
		for _, specification in ipairs(source and source.specifications or {}) do
			if specification.field == "tagContains" or specification.field == "treasureType" or specification.field == "furnitureBehavior" or specification.field == "foodTag" then
				for _, value in ipairs(specification.values or {}) do
					local valueText = tostring(value or "")
					local label = GetItemTagReferenceLabel(valueText) or valueText
					local _, category = GetItemTagReferenceInfo(valueText)
					AddGroupedOption(label, valueText, category)
				end
			end
		end
	end
	for _, filterData in pairs(db.customFilterRules or {}) do AddSaved(filterData) end
	AddSaved(db.customFilterDraft)

	local options = {}
	for _, group in pairs(groups) do
		local references = {}
		for reference in pairs(group.references) do references[#references + 1] = reference end
		table.sort(references)
		local optionValue
		if #references == 1 then
			optionValue = references[1]
		elseif #references > 1 then
			optionValue = "taggroup:" .. table.concat(references, "|")
		else
			local legacyValues = {}
			for legacyValue in pairs(group.legacy) do legacyValues[#legacyValues + 1] = legacyValue end
			table.sort(legacyValues)
			optionValue = legacyValues[1]
		end
		if optionValue then table.insert(options, {label = group.label, value = optionValue}) end
	end
	table.sort(options, function(a, b) return zo_strlower(tostring(a.label)) < zo_strlower(tostring(b.label)) end)
	return options
end

C.getCustomFilterTagOptions = GetCustomFilterTagOptions

function C.GetSpecializedTypeDisplayLabelCount()
	local labels = {}
	for specializedType in pairs(C.GetSpecializedTypeCatalog()) do
		local value = tonumber(specializedType)
		if value and value > 0 then
			labels[zo_strlower(tostring(FilterEnumLabel("specializedType", value, "Specialized type " .. tostring(value))))] = true
		end
	end
	local count = 0
	for _ in pairs(labels) do count = count + 1 end
	return count
end

function C.CanStartItemTagCatalogScan()
	return IsTagCatalogScanAllowed()
end

function C.StartItemTagCatalogScan(maxItemId)
	if not IsTagCatalogScanAllowed() then
		NotifyTagCatalogScanRestricted()
		return false
	end
	if TAG_SCAN_RUNNING then
		SendCustomRuleMessage(GetString(BMR_CUSTOM_FILTER_SCAN_ALREADY_RUNNING))
		return false
	end
	local _, scan = EnsureTagCatalog()
	PrepareTagCatalogIndex(true)
	C.InvalidateConsoleFilterValueCache()
	local getCount = _G and _G.GetItemLinkNumItemTags
	local getInfo = _G and _G.GetItemLinkItemTagInfo
	if type(getCount) ~= "function" or type(getInfo) ~= "function" then
		SendCustomRuleMessage(GetString(BMR_CUSTOM_FILTER_SCAN_API_MISSING))
		return false
	end
	maxItemId = math.min(TAG_SCAN_MAX_LIMIT, math.max(1, tonumber(maxItemId) or TAG_SCAN_MAX_DEFAULT))
	local nextId = math.max(1, tonumber(scan.nextId) or 1)
	if nextId > maxItemId then nextId = 1 end
	scan.maxId = maxItemId
	scan.completed = false
	TAG_SCAN_RUNNING = true
	SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_FILTER_SCAN_START), nextId, maxItemId))
	local function ScanBatch()
		if not TAG_SCAN_RUNNING then return end
		local lastId = math.min(nextId + TAG_SCAN_BATCH_SIZE - 1, maxItemId)
		if type(getCount) == "function" and type(getInfo) == "function" then
			local getName = _G and _G.GetItemLinkName
			for itemId = nextId, lastId do
				local itemLink = BuildItemTagProbeLink(itemId)
				local validItemLink = itemLink ~= nil
				if validItemLink and type(getName) == "function" then
					local nameOk, itemName = pcall(getName, itemLink)
					validItemLink = nameOk and type(itemName) == "string" and itemName ~= "" and itemName ~= "h"
				end
				if validItemLink then CollectTagsFromItemLink(itemLink, itemId) end
			end
		end
		scan.nextId = lastId + 1
		nextId = lastId + 1
		if lastId >= maxItemId then
			TAG_SCAN_RUNNING = false
			scan.completed = true
			local specializedLabelCount = C.GetSpecializedTypeDisplayLabelCount()
			SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_FILTER_SCAN_COMPLETE), #C.getCustomFilterTagOptions(), specializedLabelCount))
			local editor = _G.BMRCustomFilterRuleEditor
			if editor then editor.bmrValueChoicesCache = {} end
			if editor and editor.bmrRefreshValueChoices then editor.bmrRefreshValueChoices() end
			if editor then C.RefreshCustomFilterRuleEditor(editor) end
		else
			if lastId % 25000 < TAG_SCAN_BATCH_SIZE then
				SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_FILTER_SCAN_PROGRESS), lastId, maxItemId))
			end
			zo_callLater(ScanBatch, TAG_SCAN_DELAY_MS)
		end
	end
	zo_callLater(ScanBatch, 50)
	return true
end

if SLASH_COMMANDS then
	SLASH_COMMANDS["/bmr/scantags"] = function(text)
		if not IsTagCatalogScanAllowed() then NotifyTagCatalogScanRestricted(); return end
		local argument = zo_strlower(tostring(text or "")):gsub("^%s+", ""):gsub("%s+$", "")
		if argument == "stop" then
			TAG_SCAN_RUNNING = false
			local _, scan = EnsureTagCatalog()
			SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_FILTER_SCAN_PAUSED), tonumber(scan.nextId) or 1))
			return
		end
		C.StartItemTagCatalogScan(tonumber(argument) or TAG_SCAN_MAX_DEFAULT)
	end
end

-- Never enumerate the global environment (_G) to discover constants. ESO exposes
-- some private/protected functions there; iterating the table from addon code can
-- taint the call stack and raise errors such as the protected ForceCancelMounted
-- access. Resolve only the known public constants by exact name instead.
local function GetSpecializedTypeIdsByConstantNames(constantNames)
	local ids = {}
	for _, constantName in ipairs(constantNames) do
		local value = _G and _G[constantName]
		if type(value) == "number" and value > 0 then
			ids[value] = true
		end
	end
	return ids
end

local RECIPE_SPECIALIZED_TYPE_CONSTANTS = {
	"SPECIALIZED_ITEMTYPE_RECIPE_ALCHEMY_FORMULA_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_BLACKSMITHING_DIAGRAM_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_CLOTHIER_PATTERN_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_ENCHANTING_SCHEMATIC_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_JEWELRYCRAFTING_SKETCH_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_DESIGN_FURNISHING",
	"SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK",
	"SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD",
	"SPECIALIZED_ITEMTYPE_RECIPE_WOODWORKING_BLUEPRINT_FURNISHING",
}

local FOOD_DRINK_SPECIALIZED_TYPE_CONSTANTS = {
	"SPECIALIZED_ITEMTYPE_FOOD",
	"SPECIALIZED_ITEMTYPE_FOOD_ENTREMET",
	"SPECIALIZED_ITEMTYPE_FOOD_FRUIT",
	"SPECIALIZED_ITEMTYPE_FOOD_GOURMET",
	"SPECIALIZED_ITEMTYPE_FOOD_MEAT",
	"SPECIALIZED_ITEMTYPE_FOOD_RAGOUT",
	"SPECIALIZED_ITEMTYPE_FOOD_SAVOURY",
	"SPECIALIZED_ITEMTYPE_FOOD_UNIQUE",
	"SPECIALIZED_ITEMTYPE_FOOD_VEGETABLE",
	"SPECIALIZED_ITEMTYPE_DRINK",
	"SPECIALIZED_ITEMTYPE_DRINK_ALCOHOLIC",
	"SPECIALIZED_ITEMTYPE_DRINK_CORDIAL_TEA",
	"SPECIALIZED_ITEMTYPE_DRINK_DISTILLATE",
	"SPECIALIZED_ITEMTYPE_DRINK_LIQUEUR",
	"SPECIALIZED_ITEMTYPE_DRINK_TEA",
	"SPECIALIZED_ITEMTYPE_DRINK_TINCTURE",
	"SPECIALIZED_ITEMTYPE_DRINK_TONIC",
	"SPECIALIZED_ITEMTYPE_DRINK_UNIQUE",
}

local function GetRecipeSpecializedTypeIds()
	return GetSpecializedTypeIdsByConstantNames(RECIPE_SPECIALIZED_TYPE_CONSTANTS)
end

local function GetFoodDrinkSpecializedTypeIds()
	return GetSpecializedTypeIdsByConstantNames(FOOD_DRINK_SPECIALIZED_TYPE_CONSTANTS)
end

local function GetCustomFilterSpecificationFields()
	return {
		{key = "tagContains", label = GetString(BMR_CUSTOM_FILTER_TAG)},
		{key = "treasureType", label = GetString(BMR_CUSTOM_FILTER_TREASURE_TYPE)},
		{key = "furnitureBehavior", label = GetString(BMR_CUSTOM_FILTER_FURNITURE_BEHAVIOR)},
		{key = "foodTag", label = GetString(BMR_CUSTOM_FILTER_FOOD_TAG)},
		{key = "recipe", label = GetString(BMR_CUSTOM_FILTER_RECIPE)},
		{key = "quality", label = GetString(BMR_CUSTOM_FILTER_QUALITY)},
		{key = "traitInfo", label = GetString(BMR_CUSTOM_FILTER_SPECIAL_TRAIT)},
		{key = "equipType", label = GetString(BMR_CUSTOM_FILTER_EQUIP_TYPE)},
		{key = "armorType", label = GetString(BMR_CUSTOM_FILTER_ARMOR_TYPE)},
		{key = "itemType", label = GetString(BMR_CUSTOM_FILTER_ITEM_TYPE)},
		{key = "specializedType", label = GetString(BMR_CUSTOM_FILTER_SPECIALIZED_TYPE)},
		{key = "weaponType", label = GetString(BMR_CUSTOM_FILTER_WEAPON_TYPE)},
	}
end

local function GetNativeFurnishingTaxonomyOptions()
	local options, seen, subcategoryGroups = {}, {}, {}
	local getNumCategories = _G and _G.GetNumFurnitureCategories
	local getCategoryId = _G and _G.GetFurnitureCategoryId
	local getNumSubcategories = _G and _G.GetNumFurnitureSubcategories
	local getSubcategoryId = _G and _G.GetFurnitureSubcategoryId
	if type(getNumCategories) ~= "function" or type(getCategoryId) ~= "function"
		or type(getNumSubcategories) ~= "function" or type(getSubcategoryId) ~= "function" then
		return options
	end
	local countOk, categoryCount = pcall(getNumCategories)
	if not countOk then return options end
	categoryCount = math.max(0, tonumber(categoryCount) or 0)
	local function add(label, value)
		if type(label) ~= "string" or label == "" or not value or seen[value] then return end
		seen[value] = true
		options[#options + 1] = {label = label, value = value}
	end
	for categoryIndex = 1, categoryCount do
		local idOk, categoryId = pcall(getCategoryId, categoryIndex)
		categoryId = idOk and tonumber(categoryId) or nil
		local categoryName = categoryId and GetFurnitureCategoryDisplayName(categoryId) or nil
		if categoryId and categoryName then
			add(categoryName, "furnishingCategory:" .. tostring(categoryId))
			local subCountOk, subCount = pcall(getNumSubcategories, categoryIndex)
			if subCountOk then
				for subIndex = 1, math.max(0, tonumber(subCount) or 0) do
					local subOk, subcategoryId = pcall(getSubcategoryId, categoryIndex, subIndex)
					subcategoryId = subOk and tonumber(subcategoryId) or nil
					local subcategoryName = subcategoryId and GetFurnitureCategoryDisplayName(subcategoryId) or nil
					if subcategoryId and subcategoryName then
						local groupKey = zo_strlower(subcategoryName)
						subcategoryGroups[groupKey] = subcategoryGroups[groupKey] or {label = subcategoryName, pairs = {}}
						subcategoryGroups[groupKey].pairs[tostring(categoryId) .. ":" .. tostring(subcategoryId)] = true
					end
				end
			end
		end
	end
	-- Subcategory names are exposed as standalone choices (Tools, Materials, Produce).
	-- If ESO reuses a localized name under multiple parents, one option matches all of
	-- those category/subcategory pairs rather than creating duplicate visible entries.
	for _, group in pairs(subcategoryGroups) do
		local pairsList = {}
		for pair in pairs(group.pairs) do pairsList[#pairsList + 1] = pair end
		table.sort(pairsList)
		local value = "furnishingSubcategoryGroup:" .. table.concat(pairsList, ",")
		add(group.label, value)
	end
	table.sort(options, function(a, b) return zo_strlower(tostring(a.label)) < zo_strlower(tostring(b.label)) end)
	return options
end

local function GetCustomFilterSpecificationValues(field)
	local options, seen = {}, {}
	local function add(constantName, fallback)
		AddFilterEnumOption(options, field, constantName, fallback, seen)
	end
	if field == "tagContains" then
		return C.getCustomFilterTagOptions(nil, "generic")
	elseif field == "treasureType" then
		local category = _G and _G.TAG_CATEGORY_TREASURE_TYPE
		if type(category) == "number" then return C.getCustomFilterTagOptions(category, "treasure") end
		return {}
	elseif field == "furnitureBehavior" then
		-- All native furnishing categories and subcategories are available regardless
		-- of which furnishing IDs/tags have been encountered by the scanner. Labels are
		-- fetched from ESO's current localized Furniture API at runtime.
		for _, option in ipairs(C.getCustomFilterTagOptions(nil, "furniture")) do options[#options + 1] = option end
		for _, option in ipairs(GetNativeFurnishingTaxonomyOptions()) do options[#options + 1] = option end
		table.sort(options, function(a, b) return zo_strlower(tostring(a.label)) < zo_strlower(tostring(b.label)) end)
		return options
	elseif field == "foodTag" then
		-- Merge tag values and native item/specialized types by their localized
		-- display label, so labels such as Drink, Tea and Alcoholic Drink appear once.
		local rawOptions = {}
		for _, option in ipairs(C.getCustomFilterTagOptions(nil, "food")) do rawOptions[#rawOptions + 1] = option end
		local function addFoodTypeOption(constantName, prefix, labelKind, fallback)
			local value = _G[constantName]
			if type(value) ~= "number" then return end
			rawOptions[#rawOptions + 1] = {label = FilterEnumLabel(labelKind, value, fallback), value = prefix .. ":" .. tostring(value)}
		end
		addFoodTypeOption("ITEMTYPE_FOOD", "foodItemType", "itemType", "Food")
		addFoodTypeOption("ITEMTYPE_DRINK", "foodItemType", "itemType", "Drink")
		for _, constantName in ipairs({
			"SPECIALIZED_ITEMTYPE_FOOD_ENTREMET", "SPECIALIZED_ITEMTYPE_FOOD_FRUIT",
			"SPECIALIZED_ITEMTYPE_FOOD_GOURMET", "SPECIALIZED_ITEMTYPE_FOOD_MEAT",
			"SPECIALIZED_ITEMTYPE_FOOD_RAGOUT", "SPECIALIZED_ITEMTYPE_FOOD_SAVOURY",
			"SPECIALIZED_ITEMTYPE_FOOD_UNIQUE", "SPECIALIZED_ITEMTYPE_FOOD_VEGETABLE",
			"SPECIALIZED_ITEMTYPE_DRINK_ALCOHOLIC", "SPECIALIZED_ITEMTYPE_DRINK_CORDIAL_TEA",
			"SPECIALIZED_ITEMTYPE_DRINK_DISTILLATE", "SPECIALIZED_ITEMTYPE_DRINK_LIQUEUR",
			"SPECIALIZED_ITEMTYPE_DRINK_TEA", "SPECIALIZED_ITEMTYPE_DRINK_TINCTURE",
			"SPECIALIZED_ITEMTYPE_DRINK_TONIC", "SPECIALIZED_ITEMTYPE_DRINK_UNIQUE",
		}) do
			addFoodTypeOption(constantName, "foodSpecializedType", "specializedType", constantName)
		end
		local groups = {}
		for _, option in ipairs(rawOptions) do
			local rawLabel = FormatEnumDisplayLabel(tostring(option.label or ""))
			local isTagDecorated = string.sub(rawLabel, 1, 2) == "°" and string.sub(rawLabel, -2) == "°"
			local label = isTagDecorated and string.sub(rawLabel, 3, -3) or rawLabel
			local value = tostring(option.value or "")
			if label ~= "" and value ~= "" then
				local key = zo_strlower(label)
				groups[key] = groups[key] or {label = rawLabel, values = {}}
				-- Prefer the ordinary localized enum label when a tag and item type
				-- share the same visible name; retain tag decoration for tag-only values.
				if not isTagDecorated then groups[key].label = label end
				local members = ParseFoodGroup(value) or {value}
				for _, member in ipairs(members) do groups[key].values[member] = true end
			end
		end
		for _, group in pairs(groups) do
			local members = {}
			for member in pairs(group.values) do members[#members + 1] = member end
			table.sort(members)
			local value = members[1]
			if #members > 1 then value = "foodGroup:" .. table.concat(members, ";") end
			options[#options + 1] = {label = group.label, value = value}
		end
		table.sort(options, function(a, b) return zo_strlower(tostring(a.label)) < zo_strlower(tostring(b.label)) end)
		return options
	elseif field == "recipe" then
		local recipeItemType = _G and tonumber(_G.ITEMTYPE_RECIPE)
		if recipeItemType then
			local label = FilterEnumLabel("itemType", recipeItemType, "Recipe")
			options[#options + 1] = {label = label, value = "recipeItemType:" .. tostring(recipeItemType)}
		end
		local groups = {}
		for value in pairs(GetRecipeSpecializedTypeIds()) do
			local label = FilterEnumLabel("specializedType", value, "Recipe subtype " .. tostring(value))
			local key = zo_strlower(tostring(label))
			groups[key] = groups[key] or {label = tostring(label), values = {}}
			groups[key].values[#groups[key].values + 1] = value
		end
		local keys = {}
		for key in pairs(groups) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local group = groups[key]
			table.sort(group.values)
			local value = "recipeSpecializedType:" .. tostring(group.values[1])
			if #group.values > 1 then
				local ids = {}
				for _, id in ipairs(group.values) do ids[#ids + 1] = tostring(id) end
				value = "recipeSpecializedGroup:" .. table.concat(ids, ",")
			end
			options[#options + 1] = {label = group.label, value = value}
		end
		return options
	elseif field == "traitInfo" then
		-- Use ESO's localized item-trait strings. ItemTraitInformation has a
		-- shared Intricate/Ornate value for all applicable equipment categories.
		for _, entry in ipairs({
			{"ITEM_TRAIT_INFORMATION_INTRICATE", "SI_ITEMTRAITTYPE9", "Intricate"},
			{"ITEM_TRAIT_INFORMATION_ORNATE", "SI_ITEMTRAITTYPE10", "Ornate"},
		}) do
			local value = _G[entry[1]]
			if type(value) == "number" and not seen[value] then
				seen[value] = true
				local stringId = _G[entry[2]]
				local label = entry[3]
				if stringId and type(GetString) == "function" then
					local ok, localized = pcall(GetString, stringId)
					if ok and type(localized) == "string" and localized ~= "" then label = localized end
				end
				table.insert(options, {label = FormatEnumDisplayLabel(label), value = value})
			end
		end
	elseif field == "quality" then
		add("ITEM_QUALITY_TRASH", GetString(BMR_CUSTOM_FILTER_QUALITY_TRASH))
		add("ITEM_QUALITY_NORMAL", GetString(BMR_CUSTOM_FILTER_QUALITY_NORMAL))
		add("ITEM_QUALITY_MAGIC", GetString(BMR_CUSTOM_FILTER_QUALITY_FINE))
		add("ITEM_QUALITY_ARCANE", GetString(BMR_CUSTOM_FILTER_QUALITY_SUPERIOR))
		add("ITEM_QUALITY_ARTIFACT", GetString(BMR_CUSTOM_FILTER_QUALITY_EPIC))
		add("ITEM_QUALITY_LEGENDARY", GetString(BMR_CUSTOM_FILTER_QUALITY_LEGENDARY))
	elseif field == "equipType" then
		local values = {
			{"EQUIP_TYPE_HEAD", "Head"}, {"EQUIP_TYPE_CHEST", "Chest"}, {"EQUIP_TYPE_SHOULDERS", "Shoulders"},
			{"EQUIP_TYPE_WAIST", "Waist"}, {"EQUIP_TYPE_LEGS", "Legs"}, {"EQUIP_TYPE_FEET", "Feet"},
			{"EQUIP_TYPE_HAND", "Hands"}, {"EQUIP_TYPE_NECK", "Neck"}, {"EQUIP_TYPE_RING", "Ring"},
			{"EQUIP_TYPE_MAIN_HAND", "Main hand"}, {"EQUIP_TYPE_OFF_HAND", "Off hand"}, {"EQUIP_TYPE_TWO_HAND", "Two hand"},
		}
		for _, v in ipairs(values) do add(v[1], v[2]) end
	elseif field == "armorType" then
		-- Armor weight is a native item property, not a scanned item tag or
		-- specialized type. Always offer all three values independently of scan coverage.
		for _, armor in ipairs({
			{"ARMORTYPE_LIGHT", "Light"},
			{"ARMORTYPE_MEDIUM", "Medium"},
			{"ARMORTYPE_HEAVY", "Heavy"},
		}) do
			local value = _G[armor[1]]
			if type(value) == "number" and not seen[value] then
				seen[value] = true
				table.insert(options, {label = FilterEnumLabel("armorType", value, armor[2]), value = value})
			end
		end
	elseif field == "specializedType" then
		-- Food/drink-specific types belong to Food and drink, and recipe/blueprint
		-- types belong to Recipes. Keep them out here to avoid duplicate choices.
		local groups = {}
		local excludedIds = GetRecipeSpecializedTypeIds()
		for value in pairs(GetFoodDrinkSpecializedTypeIds()) do excludedIds[value] = true end
		for specializedType in pairs(C.GetSpecializedTypeCatalog()) do
			local value = tonumber(specializedType)
			if value and value > 0 and not excludedIds[value] then
				local label = FilterEnumLabel("specializedType", value, "Specialized type " .. tostring(value))
				local groupKey = zo_strlower(tostring(label))
				if not groups[groupKey] then groups[groupKey] = {label = tostring(label), values = {}} end
				table.insert(groups[groupKey].values, value)
			end
		end
		local groupKeys = {}
		for key in pairs(groups) do table.insert(groupKeys, key) end
		table.sort(groupKeys)
		for _, groupKey in ipairs(groupKeys) do
			local group = groups[groupKey]
			table.sort(group.values)
			local optionValue = group.values[1]
			if #group.values > 1 then
				local ids = {}
				for _, id in ipairs(group.values) do ids[#ids + 1] = tostring(id) end
				optionValue = "specializedGroup:" .. table.concat(ids, ",")
			end
			table.insert(options, {label = group.label, value = optionValue})
		end
	elseif field == "itemType" then
		-- Different native item types can share a localized label (notably the
		-- various Material entries). Show one label and OR-match every matching ID.
		local values = {
			{"ITEMTYPE_ARMOR", "Armor"}, {"ITEMTYPE_WEAPON", "Weapon"}, {"ITEMTYPE_JEWELRY", "Jewelry"},
			{"ITEMTYPE_CONSUMABLE", "Consumable"}, {"ITEMTYPE_CONTAINER", "Container"}, {"ITEMTYPE_TREASURE", "Treasure"},
			{"ITEMTYPE_FOOD", "Food"}, {"ITEMTYPE_DRINK", "Drink"}, {"ITEMTYPE_POTION", "Potion"}, {"ITEMTYPE_POISON", "Poison"},
			{"ITEMTYPE_RECIPE", "Recipe"}, {"ITEMTYPE_FURNISHING", "Furnishing"}, {"ITEMTYPE_SIEGE", "Siege"},
			{"ITEMTYPE_COLLECTIBLE", "Collectible"}, {"ITEMTYPE_FISH", "Fish"}, {"ITEMTYPE_TOOL", "Tool"},
			{"ITEMTYPE_STYLE_MATERIAL", "Style material"}, {"ITEMTYPE_RAW_MATERIAL", "Raw material"},
			{"ITEMTYPE_BLACKSMITHING_MATERIAL", "Blacksmithing material"}, {"ITEMTYPE_CLOTHIER_MATERIAL", "Clothier material"},
			{"ITEMTYPE_WOODWORKING_MATERIAL", "Woodworking material"}, {"ITEMTYPE_REAGENT", "Reagent"},
			{"ITEMTYPE_GLYPH_ARMOR", "Armor glyph"}, {"ITEMTYPE_GLYPH_WEAPON", "Weapon glyph"}, {"ITEMTYPE_GLYPH_JEWELRY", "Jewelry glyph"},
			{"ITEMTYPE_ANTIQUITY_LEAD", "Antiquity lead"},
		}
		local groups = {}
		for _, entry in ipairs(values) do
			local value = _G[entry[1]]
			if type(value) == "number" then
				local label = FilterEnumLabel("itemType", value, entry[2])
				local key = zo_strlower(tostring(label))
				groups[key] = groups[key] or {label = tostring(label), values = {}}
				groups[key].values[#groups[key].values + 1] = value
			end
		end
		local keys = {}
		for key in pairs(groups) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local group = groups[key]
			table.sort(group.values)
			local value = group.values[1]
			if #group.values > 1 then
				local ids = {}
				for _, id in ipairs(group.values) do ids[#ids + 1] = tostring(id) end
				value = "itemTypeGroup:" .. table.concat(ids, ",")
			end
			options[#options + 1] = {label = group.label, value = value}
		end
	elseif field == "weaponType" then
		-- ESO weapon-type strings intentionally use the same visible label for
		-- one-handed and two-handed variants (Axe, Mace, Sword). Group enum IDs
		-- by their localized label so each weapon family appears once. The
		-- separate Equipment Slot specification can then restrict matches to
		-- Two-Handed when needed.
		local values = {
			{"WEAPONTYPE_AXE", "Axe"}, {"WEAPONTYPE_HAMMER", "Mace"}, {"WEAPONTYPE_SWORD", "Sword"},
			{"WEAPONTYPE_TWO_HANDED_SWORD", "Sword"}, {"WEAPONTYPE_TWO_HANDED_AXE", "Axe"},
			{"WEAPONTYPE_TWO_HANDED_HAMMER", "Mace"}, {"WEAPONTYPE_DAGGER", "Dagger"}, {"WEAPONTYPE_BOW", "Bow"},
			{"WEAPONTYPE_HEALING_STAFF", "Healing staff"}, {"WEAPONTYPE_FIRE_STAFF", "Flame staff"},
			{"WEAPONTYPE_FROST_STAFF", "Frost staff"}, {"WEAPONTYPE_LIGHTNING_STAFF", "Lightning staff"},
			{"WEAPONTYPE_SHIELD", "Shield"}, {"WEAPONTYPE_RUNE", "Rune"},
		}
		local groups = {}
		for _, v in ipairs(values) do
			local value = _G[v[1]]
			if type(value) == "number" then
				local label = FilterEnumLabel("weaponType", value, v[2])
				local key = zo_strlower(tostring(label))
				if not groups[key] then groups[key] = {label = tostring(label), values = {}} end
				table.insert(groups[key].values, value)
			end
		end
		local groupKeys = {}
		for key in pairs(groups) do table.insert(groupKeys, key) end
		table.sort(groupKeys)
		for _, groupKey in ipairs(groupKeys) do
			local group = groups[groupKey]
			table.sort(group.values)
			local optionValue = group.values[1]
			if #group.values > 1 then
				local ids = {}
				for _, id in ipairs(group.values) do ids[#ids + 1] = tostring(id) end
				optionValue = "weaponTypeGroup:" .. table.concat(ids, ",")
			end
			table.insert(options, {label = group.label, value = optionValue})
		end
	end
	table.sort(options, function(a, b) return tostring(a.label) < tostring(b.label) end)
	return options
end

local function BuildCustomFilterSummary(filterData)
	local parts = {}
	local searchString = tostring(filterData and filterData.searchString or "")
	if searchString ~= "" then table.insert(parts, GetString(BMR_CUSTOM_FILTER_NAME_CONTAINS) .. ' "' .. searchString .. '"') end
	local fields = {}
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do fields[field.key] = field.label end
	for _, spec in ipairs(filterData and filterData.specifications or {}) do
		local labels = {}
		for _, value in ipairs(spec.values or {}) do
			local label = tostring(value)
			if spec.field == "furnitureBehavior" then
				label = GetNativeFurnishingTaxonomyLabel(value) or GetItemTagReferenceLabel(value) or FormatItemTagDisplayLabel(label)
			elseif spec.field == "foodTag" then
				local found = false
				for _, option in ipairs(GetCustomFilterSpecificationValues(spec.field)) do
					if SpecializedTypeOptionContains(option.value, value) then label = option.label; found = true; break end
				end
				if not found then label = GetItemTagReferenceLabel(value) or FormatItemTagDisplayLabel(label) end
			elseif spec.field == "tagContains" or spec.field == "treasureType" then
				label = GetItemTagReferenceLabel(value) or FormatItemTagDisplayLabel(label)
			elseif spec.field == "specializedType" or spec.field == "weaponType" or spec.field == "itemType" or spec.field == "recipe" then
				for _, option in ipairs(GetCustomFilterSpecificationValues(spec.field)) do
					if SpecializedTypeOptionContains(option.value, value) then label = option.label break end
				end
			elseif tonumber(value) then
				for _, option in ipairs(GetCustomFilterSpecificationValues(spec.field)) do
					if tonumber(option.value) and tonumber(option.value) == tonumber(value) then label = option.label break end
				end
			end
			table.insert(labels, label)
		end
		if #labels > 0 then table.insert(parts, tostring(fields[spec.field] or spec.field) .. ": " .. table.concat(labels, " / ")) end
	end
	return (#parts > 0) and table.concat(parts, " · ") or GetString(BMR_CUSTOM_FILTER_NO_SPECS)
end

-- Console/gamepad editor helpers. LibHarvensAddonSettings does not support LAM's
-- custom widget controls, so expose the same draft/rule operations through native
-- dropdown, edit and button controls instead of rendering PC-only placeholders.
local CONSOLE_FILTER_VALUE_CACHE = {}
local CONSOLE_FILTER_VALUE_LIMIT = 300

local function ConsoleRuleSelection()
	db.consoleCustomRuleSelection = db.consoleCustomRuleSelection or {}
	return db.consoleCustomRuleSelection
end

local function RefreshConsoleCustomRulePanel()
	local settings = BMR._consoleSettingsPanel
	if not settings then return end
	-- UpdateControls() is the documented LibHarvensAddonSettings panel API.
	-- Prefer it over per-control methods, which are not present in every shipped
	-- LibHarvens/LibVotans build. RefreshSettings() is retained as a fork fallback.
	local refreshed = false
	local refresh = type(settings.UpdateControls) == "function" and settings.UpdateControls
		or (type(settings.RefreshSettings) == "function" and settings.RefreshSettings)
	if type(refresh) == "function" then
		local ok, err = pcall(refresh, settings)
		refreshed = ok
		if not ok then CustomRuleDebug("console settings refresh failed: " .. tostring(err)) end
	end
	-- Dynamic tooltip functions are evaluated by LibHarvensAddonSettings when
	-- the focused control's help/description area is refreshed.
	CustomRuleDebug("console builder tooltip refreshed=" .. tostring(refreshed))
end
C.RefreshConsoleCustomRulePanel = RefreshConsoleCustomRulePanel

local function GetConsoleActionOptions()
	return {
		{name = GetString(BMR_ACTION_NOTSET), data = ACTION_NOTSET},
		{name = GetString(BMR_ACTION_PUSH), data = ACTION_PUSH},
		{name = GetString(BMR_ACTION_PULL), data = ACTION_PULL},
		{name = GetString(BMR_ACTION_PUSH_ALL_STACKS), data = ACTION_PUSH_ALL_STACKS},
		{name = GetString(BMR_ACTION_PULL_ALL_STACKS), data = ACTION_PULL_ALL_STACKS},
		{name = GetString(BMR_ACTION_PUSH_GBANK), data = ACTION_PUSH_GBANK},
		{name = GetString(BMR_ACTION_PUSH_BOTH), data = ACTION_PUSH_BOTH},
		{name = GetString(BMR_ACTION_KEEP_ONE_STACK), data = ACTION_KEEP_ONE_STACK},
		{name = GetString(BMR_ACTION_KEEP_ONE_STACK_BANK), data = ACTION_KEEP_ONE_STACK_BANK},
		{name = GetString(BMR_ACTION_PUSH_FURNITURE), data = ACTION_PUSH_FURNITURE},
	}
end
C.GetConsoleActionOptions = GetConsoleActionOptions

function C.GetConsoleGuildOptions()
	local options = {}
	for _, guild in ipairs(C._RuleUi.GetCustomGuildChoices()) do options[#options + 1] = {name = guild.name, data = guild.value} end
	return options
end

local function GetConsoleProfile()
	return db.profiles and db.profiles[ActualProfile()] or nil
end

local function GetConsoleRuleAction(ruleName)
	local profile = GetConsoleProfile()
	local rule = profile and profile.rules and profile.rules[ruleName]
	return tonumber(rule and rule.action) or ACTION_NOTSET
end

local function SetConsoleRuleAction(ruleName, aggregateRuleName, actionValue)
	local profile = GetConsoleProfile()
	if not profile or not ruleName then return false end
	profile.rules = profile.rules or {}
	local aggregate = profile.rules[aggregateRuleName] or {}
	local rule = profile.rules[ruleName]
	if type(rule) ~= "table" then
		rule = {
			action = ACTION_NOTSET,
			associatedGuild = aggregate.associatedGuild or GetString(BMR_ACTION_NOTSET),
			onlyIfNotFullStack = aggregate.onlyIfNotFullStack ~= false,
			onlyStacks = tonumber(aggregate.onlyStacks) or 1,
		}
		profile.rules[ruleName] = rule
	end
 	rule.action = tonumber(actionValue) or ACTION_NOTSET
	FireBmrRuleCountRefresh()
	return true
end

local function GetConsoleRuleGuild(ruleName)
	local profile = GetConsoleProfile()
	local rule = profile and profile.rules and profile.rules[ruleName]
	return rule and rule.associatedGuild or GetString(BMR_ACTION_NOTSET)
end

local function SetConsoleRuleGuild(ruleName, aggregateRuleName, guildName)
	local profile = GetConsoleProfile()
	if not profile or not ruleName then return false end
	profile.rules = profile.rules or {}
	local rule = profile.rules[ruleName]
	if type(rule) ~= "table" then
		local aggregate = profile.rules[aggregateRuleName] or {}
		rule = {action = ACTION_NOTSET, associatedGuild = aggregate.associatedGuild or GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = aggregate.onlyIfNotFullStack ~= false, onlyStacks = tonumber(aggregate.onlyStacks) or 1}
		profile.rules[ruleName] = rule
	end
	rule.associatedGuild = guildName or GetString(BMR_ACTION_NOTSET)
	FireBmrRuleCountRefresh()
	return true
end

local function GetConsoleGuildLabel(guildName)
	for _, choice in ipairs(C.GetConsoleGuildOptions()) do if choice.data == guildName then return choice.name end end
	return GetString(BMR_ACTION_NOTSET)
end

local function GetConsoleCustomItemIds()
	local ids = {}
	local seen = {}
	for itemId, itemData in pairs(db.customItemRules or {}) do
		local numericId = tonumber(itemId)
		if numericId and type(itemData) == "table" and not seen[numericId] then
			seen[numericId] = true
			ids[#ids + 1] = numericId
		end
	end
	table.sort(ids, function(a, b)
		local aData = db.customItemRules[tostring(a)] or db.customItemRules[a] or {}
		local bData = db.customItemRules[tostring(b)] or db.customItemRules[b] or {}
		local aName = zo_strlower(C.GetCustomItemDisplayName(a, aData))
		local bName = zo_strlower(C.GetCustomItemDisplayName(b, bData))
		if aName == bName then return a < b end
		return aName < bName
	end)
	return ids
end

function C.GetConsoleCustomItemOptions()
	local options = {}
	for _, itemId in ipairs(GetConsoleCustomItemIds()) do
		local itemData = db.customItemRules[tostring(itemId)] or db.customItemRules[itemId] or {}
		local itemName = C.GetCustomItemDisplayName(itemId, itemData)
		options[#options + 1] = {name = tostring(itemName) .. " (#" .. tostring(itemId) .. ")", data = itemId}
	end
	return options
end

function C.GetConsoleSelectedCustomItemId()
	local selection = ConsoleRuleSelection()
	local rules = db.customItemRules or {}
	local selected = tonumber(selection.itemId)
	if selected and (rules[tostring(selected)] or rules[selected]) then return selected end
	local ids = GetConsoleCustomItemIds()
	selection.itemId = ids[1]
	return ids[1]
end

function C.SetConsoleSelectedCustomItemId(itemId)
	local numericId = tonumber(itemId)
	local rules = db.customItemRules or {}
	if numericId and (rules[tostring(numericId)] or rules[numericId]) then
		ConsoleRuleSelection().itemId = numericId
	end
end

function C.GetConsoleCustomItemAction()
	local id = C.GetConsoleSelectedCustomItemId()
	return id and GetConsoleRuleAction("customItem_" .. tostring(id)) or ACTION_NOTSET
end

function C.SetConsoleCustomItemAction(actionValue)
	local id = C.GetConsoleSelectedCustomItemId()
	if not id then return end
	SetConsoleRuleAction("customItem_" .. tostring(id), "customItemsAll", actionValue)
end

function C.GetConsoleCustomItemGuildLabel()
	local id = C.GetConsoleSelectedCustomItemId()
	return id and GetConsoleGuildLabel(GetConsoleRuleGuild("customItem_" .. tostring(id))) or nil
end

function C.SetConsoleCustomItemGuild(guildName)
	local id = C.GetConsoleSelectedCustomItemId()
	if not id then return end
	SetConsoleRuleGuild("customItem_" .. tostring(id), "customItemsAll", guildName)
end

function C.GetConsoleFilterRuleOptions()
	local options = {}
	local ids = {}
	local seen = {}
	for id, filterData in pairs(db.customFilterRules or {}) do
		local numericId = tonumber(id)
		if numericId and type(filterData) == "table" and not seen[numericId] then
			seen[numericId] = true
			ids[#ids + 1] = numericId
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local filterData = db.customFilterRules[tostring(id)] or db.customFilterRules[id]
		local title = C.GetCustomFilterDisplayName(id, filterData)
		options[#options + 1] = {name = title .. " (#" .. tostring(id) .. ")", data = id}
	end
	return options
end

function C.GetConsoleSelectedFilterId()
	local selection = ConsoleRuleSelection()
	local rules = db.customFilterRules or {}
	local selected = tonumber(selection.filterId)
	if selected and (rules[tostring(selected)] or rules[selected]) then return selected end
	local ids = {}
	local seen = {}
	for id, filterData in pairs(db.customFilterRules or {}) do
		local numericId = tonumber(id)
		if numericId and type(filterData) == "table" and not seen[numericId] then
			seen[numericId] = true
			ids[#ids + 1] = numericId
		end
	end
	table.sort(ids)
	selection.filterId = ids[1]
	return ids[1]
end

function C.SetConsoleSelectedFilterId(filterId)
	local numericId = tonumber(filterId)
	local rules = db.customFilterRules or {}
	if numericId and (rules[tostring(numericId)] or rules[numericId]) then
		local selection = ConsoleRuleSelection()
		local changed = tonumber(selection.filterId) ~= numericId
		selection.filterId = numericId
		if changed then RefreshConsoleCustomRulePanel() end
		return true
	end
	return false
end

function C.GetConsoleFilterAction()
	local id = C.GetConsoleSelectedFilterId()
	return id and GetConsoleRuleAction(GetCustomFilterRuleName(id)) or ACTION_NOTSET
end

function C.SetConsoleFilterAction(actionValue)
	local id = C.GetConsoleSelectedFilterId()
	if not id then return end
	SetConsoleRuleAction(GetCustomFilterRuleName(id), "customFilterAll", actionValue)
end

function C.GetConsoleFilterGuildLabel()
	local id = C.GetConsoleSelectedFilterId()
	return id and GetConsoleGuildLabel(GetConsoleRuleGuild(GetCustomFilterRuleName(id))) or nil
end

function C.SetConsoleFilterGuild(guildName)
	local id = C.GetConsoleSelectedFilterId()
	if not id then return end
	SetConsoleRuleGuild(GetCustomFilterRuleName(id), "customFilterAll", guildName)
end

function C.GetConsoleFilterFieldOptions()
	local options = {}
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do
		options[#options + 1] = {name = field.label, data = field.key}
	end
	return options
end

local function GetConsoleDraft()
	if type(db.customFilterDraft) ~= "table" then
		db.customFilterDraft = {searchString = "", specifications = {}, editingId = nil, consoleField = "quality", consoleValueSearch = ""}
	end
	local draft = db.customFilterDraft
	draft.searchString = tostring(draft.searchString or "")
	draft.specifications = type(draft.specifications) == "table" and draft.specifications or {}
	draft.consoleField = tostring(draft.consoleField or "quality")
	draft.consoleValueSearch = tostring(draft.consoleValueSearch or "")
	return draft
end

function C.GetConsoleFilterField()
	local draft = GetConsoleDraft()
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do
		if field.key == draft.consoleField then return field.key end
	end
	draft.consoleField = "quality"
	return draft.consoleField
end

function C.SetConsoleFilterField(fieldKey)
	local valid = false
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do if field.key == fieldKey then valid = true break end end
	if not valid then return end
	local draft = GetConsoleDraft()
	draft.consoleField = fieldKey
	draft.consoleValueSearch = ""
	CustomRuleDebug("console filter field selected=" .. tostring(fieldKey))
	draft.consoleSelectedField = nil
	draft.consoleSelectedValue = nil
	draft.consoleSelectedValueLabel = nil
	RefreshConsoleCustomRulePanel()
end

function C.GetConsoleFilterFieldLabel()
	local fieldKey = C.GetConsoleFilterField()
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do if field.key == fieldKey then return field.label end end
	return ""
end

function C.GetConsoleFilterSearchString()
	return GetConsoleDraft().searchString
end

function C.SetConsoleFilterSearchString(value)
	GetConsoleDraft().searchString = tostring(value or "")
	RefreshConsoleCustomRulePanel()
end

function C.GetConsoleFilterValueSearch()
	return GetConsoleDraft().consoleValueSearch
end

function C.SetConsoleFilterValueSearch(value)
	GetConsoleDraft().consoleValueSearch = tostring(value or "")
	local draft = GetConsoleDraft()
	draft.consoleSelectedField = nil
	draft.consoleSelectedValue = nil
	draft.consoleSelectedValueLabel = nil
	RefreshConsoleCustomRulePanel()
end

function C.GetConsoleFilterValueOptions()
	local draft = GetConsoleDraft()
	local currentField = C.GetConsoleFilterField()
	local search = zo_strlower(tostring(draft.consoleValueSearch or ""))
	local fields = GetCustomFilterSpecificationFields()
	local options = {}
	local function getValues(fieldKey)
		local cached = CONSOLE_FILTER_VALUE_CACHE[fieldKey]
		if not cached then
			cached = GetCustomFilterSpecificationValues(fieldKey) or {}
			CONSOLE_FILTER_VALUE_CACHE[fieldKey] = cached
		end
		return cached
	end
	for _, field in ipairs(fields) do
		if search ~= "" or field.key == currentField then
			for _, option in ipairs(getValues(field.key)) do
				local label = tostring(option.label or "")
				local displayName = (search ~= "" and (label .. " (" .. tostring(field.label) .. ")")) or label
				if search == "" or string.find(zo_strlower(displayName), search, 1, true) then
					options[#options + 1] = {name = displayName, data = {field = field.key, value = option.value, label = displayName}}
				end
			end
		end
	end
	table.sort(options, function(a, b) return zo_strlower(tostring(a.name)) < zo_strlower(tostring(b.name)) end)
		if #options > CONSOLE_FILTER_VALUE_LIMIT then
			for i = #options, CONSOLE_FILTER_VALUE_LIMIT + 1, -1 do options[i] = nil end
		end
	if #options == 0 then
		options[1] = {name = GetString(BMR_CUSTOM_FILTER_NO_VALUES), data = nil}
	end
	return options
end

function C.GetConsoleFilterValueLabel()
	local draft = GetConsoleDraft()
	return tostring(draft.consoleSelectedValueLabel or "")
end

function C.SetConsoleFilterValue(valueData)
	if type(valueData) ~= "table" or valueData.value == nil or valueData.field == nil then
		CustomRuleDebug("console filter dropdown returned invalid value data; type=" .. type(valueData))
		SendCustomRuleMessage("[BMR] " .. GetString(BMR_CUSTOM_FILTER_NO_VALUE))
		return false
	end
	local valid = false
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do if field.key == valueData.field then valid = true break end end
	if not valid then return end
	local draft = GetConsoleDraft()
	draft.consoleField = valueData.field
	draft.consoleSelectedField = valueData.field
	draft.consoleSelectedValue = valueData.value
	draft.consoleSelectedValueLabel = tostring(valueData.label or valueData.value)
	RefreshConsoleCustomRulePanel()
	local fieldLabel = tostring(valueData.field)
	for _, fieldData in ipairs(GetCustomFilterSpecificationFields()) do
		if fieldData.key == valueData.field then fieldLabel = tostring(fieldData.label or fieldData.key); break end
	end
	local valueLabel = tostring(draft.consoleSelectedValueLabel)
	CustomRuleDebug("console filter value selected field=" .. tostring(valueData.field) .. " value=" .. tostring(valueData.value))
	SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_SELECTED), fieldLabel, valueLabel))
	return true
end

local function GetConsoleFilterDraftCounts(draft)
	draft = draft or GetConsoleDraft()
	local specificationCount, valueCount = 0, 0
	for _, specification in ipairs(draft.specifications or {}) do
		if type(specification) == "table" and type(specification.values) == "table" and #specification.values > 0 then
			specificationCount = specificationCount + 1
			valueCount = valueCount + #specification.values
		end
	end
	return specificationCount, valueCount
end

local function GetConsoleFilterFieldLabelByKey(fieldKey)
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do
		if field.key == fieldKey then return tostring(field.label or field.key) end
	end
	return tostring(fieldKey or "")
end

-- These getters intentionally return one line each. LHA's gamepad label is a
-- single-row control; embedding newline characters in one ST_LABEL made the
-- previous builder preview effectively invisible/clipped on the console UI.
local function BuildConsoleFilterBuilderExpression(filterData)
	filterData = filterData or GetConsoleDraft()
	local parts = {}
	if tostring(filterData.searchString or "") ~= "" then
		parts[#parts + 1] = GetString(BMR_CUSTOM_FILTER_NAME_CONTAINS) .. ' "' .. tostring(filterData.searchString) .. '"'
	end
	for _, specification in ipairs(filterData.specifications or {}) do
		if type(specification) == "table" and type(specification.values) == "table" and #specification.values > 0 then
			local specificationSummary = BuildCustomFilterSummary({specifications = {specification}})
			if specificationSummary ~= "" and specificationSummary ~= GetString(BMR_CUSTOM_FILTER_NO_SPECS) then
				parts[#parts + 1] = specificationSummary
			end
		end
	end
	if #parts == 0 then return GetString(BMR_CUSTOM_FILTER_NO_SPECS) end
	return table.concat(parts, "  +  ")
end

function C.GetConsoleFilterDraftBuilderExpression()
	return BuildConsoleFilterBuilderExpression(GetConsoleDraft())
end

function C.GetConsoleFilterDraftCountsLine()
	local specificationCount, valueCount = GetConsoleFilterDraftCounts()
	return zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_COUNTS), specificationCount, valueCount)
end

function C.GetConsoleFilterDraftPendingLine()
	local draft = GetConsoleDraft()
	if draft.consoleSelectedValue == nil then return GetString(BMR_CUSTOM_FILTER_BUILDER_PENDING_NONE) end
	local fieldLabel = GetConsoleFilterFieldLabelByKey(draft.consoleSelectedField or draft.consoleField)
	local valueLabel = tostring(draft.consoleSelectedValueLabel or draft.consoleSelectedValue)
	return zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_PENDING), fieldLabel, valueLabel)
end

-- The console frontend presents the focused setting's tooltip in its shared
-- description area. Use that reliable, always-visible information area for
-- the live rule builder instead of adding ST_LABEL rows to the navigation list.
-- When the draft is empty after saving, show the selected persisted rule.
function C.GetConsoleFilterRuleBuilderTooltip(includeGuildTooltip)
	local draft = GetConsoleDraft()
	local selectedId = C.GetConsoleSelectedFilterId()
	local selectedRule = selectedId and db.customFilterRules
		and (db.customFilterRules[tostring(selectedId)] or db.customFilterRules[selectedId]) or nil
	local draftHasContent = tostring(draft.searchString or '') ~= ''
		or #(draft.specifications or {}) > 0
		or draft.consoleSelectedValue ~= nil
	local draftIsSelectedForEdit = tonumber(draft.editingId) ~= nil
		and tonumber(draft.editingId) == tonumber(selectedId)
	local data = (draftHasContent or draftIsSelectedForEdit or not selectedRule) and draft or selectedRule
	local specificationCount, valueCount = GetConsoleFilterDraftCounts(data)
	local lines = {
		GetString(BMR_CUSTOM_FILTER_RULE_BUILDER),
		zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_COUNTS), specificationCount, valueCount),
		BuildConsoleFilterBuilderExpression(data),
	}
	if data == draft and draft.consoleSelectedValue ~= nil then
		lines[#lines + 1] = C.GetConsoleFilterDraftPendingLine()
	end
	if includeGuildTooltip then
		lines[#lines + 1] = ''
		lines[#lines + 1] = GetString(BMR_GUILD_LIST_TOOLTIP)
	end
	return table.concat(lines, '\n')
end

-- Saved-rule counterpart to the live builder tooltip. It always reads the currently
-- selected persisted rule, so the same help area verifies what was actually saved.
function C.GetConsoleSelectedFilterRuleTooltip(includeGuildTooltip)
	local selectedId = C.GetConsoleSelectedFilterId()
	local selectedRule = selectedId and db.customFilterRules
		and (db.customFilterRules[tostring(selectedId)] or db.customFilterRules[selectedId]) or nil
	if type(selectedRule) ~= "table" then
		return C.GetConsoleFilterRuleBuilderTooltip(includeGuildTooltip)
	end
	local specificationCount, valueCount = GetConsoleFilterDraftCounts(selectedRule)
	local displayName = C.GetCustomFilterDisplayName(selectedId, selectedRule)
	local lines = {
		GetString(BMR_CUSTOM_FILTER_RULE_BUILDER),
		zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_SAVED), specificationCount, valueCount),
		displayName,
		BuildConsoleFilterBuilderExpression(selectedRule),
	}
	if includeGuildTooltip then
		lines[#lines + 1] = ""
		lines[#lines + 1] = GetString(BMR_GUILD_LIST_TOOLTIP)
	end
	return table.concat(lines, "\n")
end

-- Compatibility getter retained for callers outside the console settings page.
function C.GetConsoleFilterDraftSummary()
	return C.GetConsoleFilterDraftBuilderExpression()
end

function C.AddConsoleFilterDraftSpecification()
	local draft = GetConsoleDraft()
	local field = draft.consoleSelectedField or draft.consoleField
	local value = draft.consoleSelectedValue
	if value == nil or tostring(value) == "" then
		SendCustomRuleMessage("[BMR] " .. GetString(BMR_CUSTOM_FILTER_NO_VALUE))
		return false
	end
	local validField = false
	for _, fieldData in ipairs(GetCustomFilterSpecificationFields()) do if fieldData.key == field then validField = true break end end
	if not validField then return false end
	local target
	for _, spec in ipairs(draft.specifications) do if spec.field == field then target = spec break end end
	if not target then target = {field = field, values = {}}; draft.specifications[#draft.specifications + 1] = target end
	local exists = false
	for _, priorValue in ipairs(target.values or {}) do if tostring(priorValue) == tostring(value) then exists = true break end end
	local fieldLabel = GetConsoleFilterFieldLabelByKey(field)
	local valueLabel = tostring(draft.consoleSelectedValueLabel or value)
	if not exists then target.values[#target.values + 1] = value end
	local specificationCount, valueCount = GetConsoleFilterDraftCounts(draft)
	CustomRuleDebug("console filter specification " .. (exists and "duplicate" or "added") .. " field=" .. tostring(field) .. " value=" .. tostring(value) .. " specifications=" .. tostring(specificationCount) .. " values=" .. tostring(valueCount))
	draft.consoleSelectedValue = nil
	draft.consoleSelectedField = nil
	draft.consoleSelectedValueLabel = nil
	RefreshConsoleCustomRulePanel()
	if exists then
		SendCustomRuleMessage("[BMR] " .. GetString(BMR_CUSTOM_FILTER_BUILDER_DUPLICATE))
	else
		SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_ADDED), fieldLabel, valueLabel, specificationCount, valueCount))
	end
	return not exists
end

function C.RemoveConsoleFilterDraftSpecification()
	local draft = GetConsoleDraft()
	if #draft.specifications > 0 then table.remove(draft.specifications, #draft.specifications) end
	RefreshConsoleCustomRulePanel()
end

function C.ClearConsoleFilterDraft()
	local draft = GetConsoleDraft()
	db.customFilterDraft = {searchString = "", specifications = {}, editingId = nil, consoleField = draft.consoleField or "quality", consoleValueSearch = ""}
	RefreshConsoleCustomRulePanel()
end

function C.SaveCustomFilterDraft(overwriteEdited)
	local currentDraft = GetConsoleDraft()
	-- A selected dropdown value is only a pending candidate. Refuse to save until
	-- it has been explicitly added, so the UI can never imply it was persisted.
	if currentDraft.consoleSelectedValue ~= nil then
		SendCustomRuleMessage("[BMR] " .. GetString(BMR_CUSTOM_FILTER_BUILDER_SAVE_PENDING))
		RefreshConsoleCustomRulePanel()
		return false
	end
	local validFields = {}
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do validFields[field.key] = true end
	local normalizedSpecifications = {}
	for _, specification in ipairs(currentDraft.specifications or {}) do
		if type(specification) == "table" and validFields[specification.field] and type(specification.values) == "table" then
			local values, seenValues = {}, {}
			for _, value in ipairs(specification.values) do
				if value ~= nil and tostring(value) ~= "" and not seenValues[tostring(value)] then
					seenValues[tostring(value)] = true
					values[#values + 1] = value
				end
			end
			if #values > 0 then normalizedSpecifications[#normalizedSpecifications + 1] = {field = specification.field, values = values} end
		end
	end
	local specificationCount, valueCount = GetConsoleFilterDraftCounts({specifications = normalizedSpecifications})
	if currentDraft.searchString == "" and specificationCount == 0 then
		SendCustomRuleMessage("[BMR] " .. GetString(BMR_CUSTOM_FILTER_NEED_CONDITION))
		return false
	end
	db.customFilterRules = db.customFilterRules or {}
	local editingId = tonumber(currentDraft.editingId)
	local existing = editingId and (db.customFilterRules[tostring(editingId)] or db.customFilterRules[editingId])
	local overwrite = overwriteEdited == true and existing ~= nil
	local id
	if overwrite then
		id = editingId
	else
		local maxId = 0
		for existingId in pairs(db.customFilterRules) do maxId = math.max(maxId, tonumber(existingId) or 0) end
		id = maxId + 1
	end
	local filterData = DeepCopy(currentDraft)
	filterData.consoleField = nil
	filterData.consoleValueSearch = nil
	filterData.consoleSelectedField = nil
	filterData.consoleSelectedValue = nil
	filterData.consoleSelectedValueLabel = nil
	filterData.id = id
	filterData.editingId = nil
	filterData.searchString = tostring(filterData.searchString or "")
	filterData.specifications = normalizedSpecifications
	filterData.summary = BuildCustomFilterSummary(filterData)
	filterData.displayName = overwrite and existing and (existing.displayName or nil) or nil
	filterData.name = (filterData.displayName and filterData.displayName ~= "" and filterData.displayName) or (filterData.searchString ~= "" and filterData.searchString) or filterData.summary
	db.customFilterRules[tostring(id)] = filterData
	db.customFilterRules[id] = nil
	if not overwrite then
		for _, profile in pairs(db.profiles or {}) do
			if type(profile) == "table" then
				profile.rules = profile.rules or {}
				profile.rules.customFilterAll = profile.rules.customFilterAll or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
				profile.rules[GetCustomFilterRuleName(id)] = {
					action = ACTION_NOTSET,
					associatedGuild = profile.rules.customFilterAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
					onlyIfNotFullStack = profile.rules.customFilterAll.onlyIfNotFullStack ~= false,
					onlyStacks = tonumber(profile.rules.customFilterAll.onlyStacks) or 1,
				}
			end
		end
	end
	C.SyncFilterRuleDefinitions()
	ConsoleRuleSelection().filterId = id
	local messageKey = overwrite and BMR_CUSTOM_FILTER_UPDATED or BMR_CUSTOM_FILTER_ADDED
	CustomRuleDebug("console filter saved id=" .. tostring(id) .. " overwrite=" .. tostring(overwrite) .. " specifications=" .. tostring(specificationCount) .. " values=" .. tostring(valueCount) .. " matcher=DoesCustomFilterMatch")
	SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(messageKey), filterData.name) .. " — " .. zo_strformat(GetString(BMR_CUSTOM_FILTER_BUILDER_SAVED), specificationCount, valueCount))
	db.customFilterDraft = {searchString = "", specifications = {}, editingId = nil, consoleField = currentDraft.consoleField or "quality", consoleValueSearch = ""}
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() else RefreshConsoleCustomRulePanel() end
	return true, id
end

function C.RenameCustomFilterRuleById(filterId, newName)
	local id = tonumber(filterId)
	if not id then return false, "invalid-id" end
	local key = tostring(id)
	local filterData = db.customFilterRules and (db.customFilterRules[key] or db.customFilterRules[id])
	if type(filterData) ~= "table" then return false, "missing-rule" end
	local name = string.gsub(tostring(newName or ""), "^%s*(.-)%s*$", "%1")
	if name == "" then return false, "empty-name" end
	local nameLength = type(zo_strlen) == "function" and zo_strlen(name) or #name
	if nameLength > 64 then return false, "too-long" end
	local normalized = zo_strlower(name)
	for otherId, otherData in pairs(db.customFilterRules or {}) do
		if tonumber(otherId) and tonumber(otherId) ~= id and type(otherData) == "table" then
			if zo_strlower(C.GetCustomFilterDisplayName(otherId, otherData)) == normalized then return false, "duplicate-name" end
		end
	end
	for otherId, otherData in pairs(db.customItemRules or {}) do
		if tonumber(otherId) and type(otherData) == "table" and zo_strlower(C.GetCustomItemDisplayName(otherId, otherData)) == normalized then return false, "duplicate-name" end
	end
	filterData.displayName = name
	C.SyncFilterRuleDefinitions()
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() else RefreshConsoleCustomRulePanel() end
	return true
end

function C.ShowRenameCustomFilterDialog(filterId)
	if type(ZO_Dialogs_ShowDialog) ~= "function" then return false end
	local dialogName = "BMR_CUSTOM_FILTER_RENAME_DIALOG"
	if not C._renameDialogRegistered then
		if type(ESO_Dialogs) ~= "table" then return false end
		ESO_Dialogs[dialogName] = {
			title = {text = GetString(BMR_CUSTOM_FILTER_RENAME_TITLE)},
			mainText = {text = GetString(BMR_CUSTOM_FILTER_RENAME_PROMPT)},
			editBox = {maxInputCharacters = 64},
			buttons = {
				{text = SI_DIALOG_CONFIRM, callback = function(dialog)
						local id = dialog and dialog.data and tonumber(dialog.data[1])
						local value = type(ZO_Dialogs_GetEditBoxText) == "function" and ZO_Dialogs_GetEditBoxText(dialog) or ""
						local ok, reason = C.RenameCustomFilterRuleById(id, value)
						if not ok then
							local message = reason == "duplicate-name" and GetString(BMR_CUSTOM_FILTER_RENAME_DUPLICATE) or GetString(BMR_CUSTOM_FILTER_RENAME_INVALID)
						SendCustomRuleMessage("[BMR] " .. message)
					end
					end},
				{text = SI_DIALOG_CANCEL},
			},
		}
		C._renameDialogRegistered = true
	end
	ZO_Dialogs_ShowDialog(dialogName, {tonumber(filterId)}, {initialEditText = C.GetCustomFilterDisplayName(filterId)})
	return true
end

function C._RuleUi.GetCurrentConsoleFilterRenameTarget()
	local id = C.GetConsoleSelectedFilterId()
	if not id then return nil, nil end
	local data = db.customFilterRules and (db.customFilterRules[tostring(id)] or db.customFilterRules[id])
	return id, data
end

function C.GetConsoleFilterRenameDraft()
	local id, data = C._RuleUi.GetCurrentConsoleFilterRenameTarget()
	if not id or not data then return "" end
	if tonumber(db.customFilterRenameTarget) ~= tonumber(id) then
		db.customFilterRenameTarget = id
		db.customFilterRenameDraft = C.GetCustomFilterDisplayName(id, data)
	end
	return tostring(db.customFilterRenameDraft or "")
end

function C.SetConsoleFilterRenameDraft(value)
	db.customFilterRenameDraft = tostring(value or "")
end

function C.ApplyConsoleFilterRename()
	local id = C.GetConsoleSelectedFilterId()
	if not id then return false end
	local ok, reason = C.RenameCustomFilterRuleById(id, db.customFilterRenameDraft or "")
	if not ok then
		local message = reason == "duplicate-name" and GetString(BMR_CUSTOM_FILTER_RENAME_DUPLICATE) or GetString(BMR_CUSTOM_FILTER_RENAME_INVALID)
		SendCustomRuleMessage("[BMR] " .. message)
		return false
	end
	SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(BMR_CUSTOM_FILTER_RENAMED), C.GetCustomFilterDisplayName(id, db.customFilterRules[tostring(id)])))
		return true
end

function C.DeleteCustomFilterRuleById(filterId)
	local id = tonumber(filterId)
	if not id then return false end
	local key = tostring(id)
	if not db.customFilterRules or not (db.customFilterRules[key] or db.customFilterRules[id]) then return false end
	db.customFilterRules[key] = nil
	db.customFilterRules[id] = nil
	local ruleName = GetCustomFilterRuleName(key)
	for _, profile in pairs(db.profiles or {}) do if profile.rules then profile.rules[ruleName] = nil end end
	if BankManagerRules and BankManagerRules.data then BankManagerRules.data[ruleName] = nil end
	if BankManagerRules and BankManagerRules.defaults then BankManagerRules.defaults[ruleName] = nil end
	C.SyncFilterRuleDefinitions()
	if ConsoleRuleSelection().filterId == id then ConsoleRuleSelection().filterId = nil end
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() else RefreshConsoleCustomRulePanel() end
	return true
end

function C.InvalidateConsoleFilterValueCache()
	CONSOLE_FILTER_VALUE_CACHE = {}
end


function C.RefreshCustomFilterRuleEditor(control)
	if not control then return end
	-- LibAddonMenu may invoke refreshFunc on its reference wrapper before
	-- CreateCustomFilterRuleEditor has attached the editor-specific children,
	-- or a panel refresh can temporarily expose a wrapper instead of the editor.
	-- Treat that as a no-op rather than indexing a missing bmrDraftSummary.
	local summary = control.bmrDraftSummary
	if not summary or not summary.SetText then return end

	if type(db.customFilterDraft) ~= "table" then
		db.customFilterDraft = {searchString = "", specifications = {}}
	end
	local draft = db.customFilterDraft
	if type(draft.searchString) ~= "string" then draft.searchString = tostring(draft.searchString or "") end
	if type(draft.specifications) ~= "table" then draft.specifications = {} end

	summary:SetText(BuildCustomFilterSummary(draft))
	local count = 0
	for _, spec in ipairs(draft.specifications) do count = count + 1 end
	if summary.SetHeight then summary:SetHeight(math.max(38, math.min(70, 22 + count * 12))) end
	if control.SetHeight then control:SetHeight(math.min(420, 300 + math.max(0, count - 1) * 7)) end
end

function C.RefreshCustomFilterRuleList(control)
	if not control then return end
	control.bmrRows = control.bmrRows or {}
	C._RuleUi.CreateCustomRuleTableHeader(control)
	C._RuleUi.LayoutCustomRuleHeader(control)
	local filterIds = {}
	for id, filterData in pairs(db.customFilterRules or {}) do if tonumber(id) and type(filterData) == "table" then table.insert(filterIds, tostring(id)) end end
	table.sort(filterIds, function(a, b) return tonumber(a) < tonumber(b) end)
	local actions = {
		{label = GetString(BMR_ACTION_NOTSET), value = ACTION_NOTSET},
		{label = GetString(BMR_ACTION_PUSH), value = ACTION_PUSH},
		{label = GetString(BMR_ACTION_PULL), value = ACTION_PULL},
		{label = GetString(BMR_ACTION_PUSH_ALL_STACKS), value = ACTION_PUSH_ALL_STACKS},
		{label = GetString(BMR_ACTION_PULL_ALL_STACKS), value = ACTION_PULL_ALL_STACKS},
		{label = GetString(BMR_ACTION_PUSH_GBANK), value = ACTION_PUSH_GBANK},
		{label = GetString(BMR_ACTION_PUSH_BOTH), value = ACTION_PUSH_BOTH},
		{label = GetString(BMR_ACTION_KEEP_ONE_STACK), value = ACTION_KEEP_ONE_STACK},
		{label = GetString(BMR_ACTION_KEEP_ONE_STACK_BANK), value = ACTION_KEEP_ONE_STACK_BANK},
		{label = GetString(BMR_ACTION_PUSH_FURNITURE), value = ACTION_PUSH_FURNITURE},
	}
	for _, row in ipairs(control.bmrRows) do row:SetHidden(true) end
	for index, filterId in ipairs(filterIds) do
		local key = tostring(filterId)
		local filterData = db.customFilterRules[key] or db.customFilterRules[tonumber(key)]
		local ruleName = GetCustomFilterRuleName(key)
		local row = control.bmrRows[index]
		if not row then
			row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
			row.label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
			row.label:SetFont("ZoFontGame")
			row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
			row.dropdownContainer = WINDOW_MANAGER:CreateControlFromVirtual("BMRCustomFilterCombo_" .. key, row, "ZO_ComboBox")
			row.dropdown = ZO_ComboBox_ObjectFromContainer(row.dropdownContainer)
			row.dropdown:SetSortsItems(false)
			C._RuleUi.CreateCustomGuildCombo(row, "filter_" .. key)
			row.removeButton = WINDOW_MANAGER:CreateControlFromVirtual("BMRCustomFilterRemove_" .. key, row, "ZO_DefaultButton")
			control.bmrRows[index] = row
		end
		row.bmrFilterId = tonumber(key)
		row:ClearAnchors()
		row:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 26 + (index - 1) * 44)
		row:SetHeight(42)
		row:SetHidden(false)
		row.label:ClearAnchors()
		row.label:SetAnchor(LEFT, row, LEFT, 0, 0)
		row.label:SetText(C.GetCustomFilterDisplayName(key, filterData))
		local rule = C._RuleUi.GetCustomProfileRule(ruleName, "customFilterAll")
		local selectedLabel = GetString(BMR_ACTION_NOTSET)
		row.dropdown:ClearItems()
		for _, action in ipairs(actions) do
			local actionValue, actionLabel = action.value, action.label
			local entry = row.dropdown:CreateItemEntry(actionLabel, function()
				local currentId = row.bmrFilterId
				local currentRule = currentId and C._RuleUi.GetCustomProfileRule(GetCustomFilterRuleName(currentId), "customFilterAll")
				if currentRule then currentRule.action = actionValue; FireBmrRuleCountRefresh() end
			end)
			row.dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
			if rule and (rule.action or ACTION_NOTSET) == action.value then selectedLabel = action.label end
		end
		row.dropdown:SetSelectedItem(selectedLabel)
		C._RuleUi.RefreshCustomGuildCombo(row, ruleName, "customFilterAll")
		local columns = C._RuleUi.GetCustomRuleColumnLayout(control:GetWidth())
		row.label:SetWidth(columns.labelWidth)
		C._RuleUi.LayoutCustomRuleRow(row, control)
		row.removeButton:SetText(GetString(BMR_CUSTOM_RULE_REMOVE_SHORT))
		row.removeButton:SetHandler("OnClicked", function()
			local id = row.bmrFilterId
			if id then C.DeleteCustomFilterRuleById(id) end
		end)
		row.label:SetMouseEnabled(true)
		row.label:SetHandler("OnMouseEnter", function(self)
			if InformationTooltip and InitializeTooltip then
				InitializeTooltip(InformationTooltip, self, TOPRIGHT, 0, 0)
				if InformationTooltip.AddLine then InformationTooltip:AddLine(BuildCustomFilterSummary(filterData)) end
			end
		end)
		row.label:SetHandler("OnMouseExit", function() if InformationTooltip and ClearTooltip then ClearTooltip(InformationTooltip) end end)
		row.label:SetHandler("OnMouseUp", function(self, button, upInside)
			if button == MOUSE_BUTTON_INDEX_RIGHT and upInside and type(ClearMenu) == "function" and type(AddMenuItem) == "function" and type(ShowMenu) == "function" then
				local selectedId = row.bmrFilterId
				ClearMenu()
				AddMenuItem(GetString(BMR_CUSTOM_FILTER_EDIT), function() C.LoadCustomFilterRuleIntoDraft(selectedId) end)
				AddMenuItem(GetString(BMR_CUSTOM_FILTER_RENAME), function() C.ShowRenameCustomFilterDialog(selectedId) end)
				ShowMenu()
			end
		end)
	end
	for index = #filterIds + 1, #control.bmrRows do control.bmrRows[index]:SetHidden(true) end
	control:SetHeight(math.max(30, 26 + #filterIds * 44))
end

function C.CreateCustomFilterRuleList(control)
	-- The list height is calculated explicitly in RefreshCustomFilterRuleList.
	-- Do not derive its width from descendants: that would keep the table at its
	-- initial width after LAM's settings panel is widened.
	control:SetResizeToFitDescendents(false)
	control:SetDimensionConstraints(400, 30, 1500, 2000)
	control:SetHandler("OnSizeChanged", function(self)
		C._RuleUi.LayoutCustomRuleHeader(self)
		for _, row in ipairs(self.bmrRows or {}) do if not row:IsHidden() then C._RuleUi.LayoutCustomRuleRow(row, self) end end
	end)
	C.RefreshCustomFilterRuleList(control)
end

function C.CreateCustomFilterRuleEditor(control)
	-- Virtual templates create named child controls (BG, SelectedItemText,
	-- OpenDropdown, etc.). Give every template instance a unique name to avoid
	-- collisions when the filter editor creates multiple controls or is rebuilt.
	BMR.customFilterEditorInstanceCounter = (BMR.customFilterEditorInstanceCounter or 0) + 1
	local controlPrefix = "BMRCustomFilterEditor_" .. tostring(BMR.customFilterEditorInstanceCounter) .. "_"
	control:SetResizeToFitDescendents(false)
	-- The LAM custom control can now grow with the settings panel. Its child
	-- controls are repositioned proportionally by bmrResizeLayout below.
	control:SetDimensionConstraints(400, 300, 1500, 420)
	control:SetHeight(300)
	local function label(text, x, y, w, h, font)
		local c = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
		c:SetFont(font or "ZoFontGame")
		c:SetText(text)
		c:SetDimensions(w, h)
		c:SetAnchor(TOPLEFT, control, TOPLEFT, x, y)
		return c
	end
	local searchLabel = label(GetString(BMR_CUSTOM_FILTER_SEARCH_STRING), 0, 2, 500, 22)
	local searchBox = WINDOW_MANAGER:CreateControl(controlPrefix .. "SearchBox", control, CT_CONTROL)
	searchBox:SetDimensions(500, 30)
	searchBox:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 24)
	local searchBg = WINDOW_MANAGER:CreateControl(controlPrefix .. "SearchBg", searchBox, CT_BACKDROP)
	searchBg:SetAnchorFill()
	searchBg:SetDrawLayer(DL_BACKGROUND)
	searchBg:SetAlpha(1)
	searchBg:SetCenterColor(0, 0, 0, 0.25)
	searchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
	searchBg:SetEdgeTexture("", 1, 1, 0, 0)
	local searchButton = WINDOW_MANAGER:CreateControl(controlPrefix .. "SearchButton", searchBox, CT_BUTTON)
	searchButton:SetDimensions(32, 30)
	searchButton:SetAnchor(LEFT, searchBox, LEFT, 2, 0)
	-- Match BeamMeUp's familiar search affordance.
	searchButton:SetNormalTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds")
	searchButton:SetPressedTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds")
	searchButton:SetMouseOverTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds")
	local searchEdit = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "SearchEdit", searchBox, "ZO_DefaultEdit")
	searchEdit:SetDimensions(460, 28)
	searchEdit:SetAnchor(LEFT, searchButton, RIGHT, 4, 1)
	searchEdit:SetAnchor(RIGHT, searchBox, RIGHT, -4, 1)
	searchEdit:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
	searchEdit:SetMaxInputChars(250)
	searchButton:SetHandler("OnClicked", function() searchEdit:TakeFocus() end)
	searchBox:SetMouseEnabled(true)
	searchBox:SetHandler("OnMouseEnter", function() searchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA()) end)
	searchBox:SetHandler("OnMouseExit", function() if not searchEdit:HasFocus() then searchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA()) end end)
	searchEdit:SetHandler("OnFocusGained", function() searchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA()) end)
	searchEdit:SetHandler("OnFocusLost", function() searchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA()) end)
	searchEdit:SetHandler("OnEscape", function(self) self:Clear(); self:LoseFocus() end)
	control.bmrSearchBox, control.bmrSearchEdit = searchBox, searchEdit

	local fieldLabel = label(GetString(BMR_CUSTOM_FILTER_FIELD), 0, 56, 160, 22)
	local valueSearchLabel = label(GetString(BMR_CUSTOM_FILTER_VALUE_SEARCH), 176, 56, 320, 22)
	local fieldContainer = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "FieldCombo", control, "ZO_ComboBox")
	fieldContainer:SetDimensions(160, 28)
	fieldContainer:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 78)
	local fieldCombo = ZO_ComboBox_ObjectFromContainer(fieldContainer)
	fieldCombo:SetSortsItems(false)
	control.bmrFieldCombo = fieldCombo
	local valueContainer = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "ValueCombo", control, "ZO_ComboBox")
	valueContainer:SetDimensions(320, 28)
	valueContainer:SetAnchor(TOPLEFT, control, TOPLEFT, 176, 126)
	local valueCombo = ZO_ComboBox_ObjectFromContainer(valueContainer)
	valueCombo:SetSortsItems(false)
	control.bmrValueContainer, control.bmrValueCombo = valueContainer, valueCombo
	local valueLabel = label(GetString(BMR_CUSTOM_FILTER_VALUE), 176, 108, 320, 18)
	local valueSearchBox = WINDOW_MANAGER:CreateControl(controlPrefix .. "ValueSearchBox", control, CT_CONTROL)
	valueSearchBox:SetDimensions(320, 27)
	valueSearchBox:SetAnchor(TOPLEFT, control, TOPLEFT, 176, 78)
	local valueSearchBg = WINDOW_MANAGER:CreateControl(controlPrefix .. "ValueSearchBg", valueSearchBox, CT_BACKDROP)
	valueSearchBg:SetAnchorFill()
	valueSearchBg:SetDrawLayer(DL_BACKGROUND)
	valueSearchBg:SetAlpha(1)
	valueSearchBg:SetCenterColor(0, 0, 0, 0.25)
	valueSearchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA())
	valueSearchBg:SetEdgeTexture("", 1, 1, 0, 0)
	local valueSearchButton = WINDOW_MANAGER:CreateControl(controlPrefix .. "ValueSearchButton", valueSearchBox, CT_BUTTON)
	valueSearchButton:SetDimensions(32, 27)
	valueSearchButton:SetAnchor(LEFT, valueSearchBox, LEFT, 2, 0)
	valueSearchButton:SetNormalTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_up.dds")
	valueSearchButton:SetPressedTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_down.dds")
	valueSearchButton:SetMouseOverTexture("EsoUI/Art/LFG/LFG_tabIcon_groupTools_over.dds")
	local valueSearchEdit = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "ValueSearchEdit", valueSearchBox, "ZO_DefaultEdit")
	valueSearchEdit:SetDimensions(275, 25)
	valueSearchEdit:SetAnchor(LEFT, valueSearchButton, RIGHT, 4, 1)
	valueSearchEdit:SetAnchor(RIGHT, valueSearchBox, RIGHT, -5, 1)
	valueSearchButton:SetHandler("OnClicked", function() valueSearchEdit:TakeFocus() end)
	valueSearchEdit:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
	valueSearchEdit:SetMaxInputChars(100)
	valueSearchBox:SetMouseEnabled(true)
	valueSearchBox:SetHandler("OnMouseEnter", function() valueSearchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA()) end)
	valueSearchBox:SetHandler("OnMouseExit", function() if not valueSearchEdit:HasFocus() then valueSearchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA()) end end)
	valueSearchEdit:SetHandler("OnFocusGained", function() valueSearchBg:SetEdgeColor(ZO_SECOND_CONTRAST_TEXT:UnpackRGBA()) end)
	valueSearchEdit:SetHandler("OnFocusLost", function() valueSearchBg:SetEdgeColor(ZO_DISABLED_TEXT:UnpackRGBA()) end)
	valueSearchEdit:SetHandler("OnEscape", function(self) self:Clear(); self:LoseFocus() end)
	control.bmrValueSearchEdit = valueSearchEdit
	-- Two full-width rows keep all localized button captions readable.
	local buttonWidth = 247
	local secondButtonX = 253
	local addSpec = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "AddSpec", control, "ZO_DefaultButton")
	addSpec:SetDimensions(buttonWidth, 28)
	addSpec:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 159)
	addSpec:SetText(GetString(BMR_CUSTOM_FILTER_ADD_SPEC))
	control.bmrAddSpec = addSpec
	local removeSpec = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "RemoveSpec", control, "ZO_DefaultButton")
	removeSpec:SetDimensions(buttonWidth, 28)
	removeSpec:SetAnchor(TOPLEFT, control, TOPLEFT, secondButtonX, 159)
	removeSpec:SetText(GetString(BMR_CUSTOM_FILTER_REMOVE_LAST))
	control.bmrRemoveSpec = removeSpec
	local clearDraft = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "ClearDraft", control, "ZO_DefaultButton")
	clearDraft:SetDimensions(buttonWidth, 28)
	clearDraft:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 193)
	clearDraft:SetText(GetString(BMR_CUSTOM_FILTER_CLEAR))
	control.bmrClearDraft = clearDraft
	local addRule = WINDOW_MANAGER:CreateControlFromVirtual(controlPrefix .. "AddRule", control, "ZO_DefaultButton")
	addRule:SetDimensions(buttonWidth, 28)
	addRule:SetAnchor(TOPLEFT, control, TOPLEFT, secondButtonX, 193)
	addRule:SetText(GetString(BMR_CUSTOM_FILTER_ADD_RULE))
	control.bmrAddRule = addRule
	local summary = label("", 0, 227, 500, 52, "ZoFontGameSmall")
	summary:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	control.bmrDraftSummary = summary

	-- Reflow every custom-editor child when LAM changes the parent width.
	-- Keep the two selector columns balanced and let the action buttons use
	-- the available row width instead of leaving a large empty right margin.
	control.bmrSearchLabel = searchLabel
	control.bmrFieldLabel = fieldLabel
	control.bmrValueSearchLabel = valueSearchLabel
	control.bmrValueLabel = valueLabel
	control.bmrResizeLayout = function(targetWidth)
		local width = math.max(400, math.min(1500, tonumber(targetWidth) or control:GetWidth()))
		local columnGap = 16
		local leftWidth = math.floor((width - columnGap) / 3)
		local rightX = leftWidth + columnGap
		local rightWidth = math.max(220, width - rightX)
		local buttonGap = 6
		local buttonWidth = math.floor((width - buttonGap) / 2)
		control:SetDimensionConstraints(400, 300, 1500, 420)
		control:SetWidth(width)
		searchLabel:SetWidth(width - 4)
		searchBox:SetWidth(width - 4)
		searchEdit:SetWidth(math.max(100, width - 48))
		fieldLabel:SetWidth(leftWidth)
		fieldContainer:SetWidth(leftWidth)
		fieldCombo.m_containerWidth = leftWidth
		if fieldCombo.m_dropdown and fieldCombo.m_dropdown.SetWidth then fieldCombo.m_dropdown:SetWidth(leftWidth) end
		valueSearchLabel:ClearAnchors()
		valueSearchLabel:SetAnchor(TOPLEFT, control, TOPLEFT, rightX, 56)
		valueSearchLabel:SetDimensions(rightWidth, 22)
		valueLabel:ClearAnchors()
		valueLabel:SetAnchor(TOPLEFT, control, TOPLEFT, rightX, 108)
		valueLabel:SetDimensions(rightWidth, 18)
		valueSearchBox:ClearAnchors()
		valueSearchBox:SetAnchor(TOPLEFT, control, TOPLEFT, rightX, 78)
		valueSearchBox:SetDimensions(rightWidth, 27)
		valueSearchEdit:SetWidth(math.max(100, rightWidth - 48))
		valueContainer:ClearAnchors()
		valueContainer:SetAnchor(TOPLEFT, control, TOPLEFT, rightX, 126)
		valueContainer:SetDimensions(rightWidth, 28)
		valueCombo.m_containerWidth = rightWidth
		if valueCombo.m_dropdown and valueCombo.m_dropdown.SetWidth then valueCombo.m_dropdown:SetWidth(rightWidth) end
		for _, button in ipairs({addSpec, removeSpec, clearDraft, addRule}) do button:SetWidth(buttonWidth) end
		removeSpec:ClearAnchors(); removeSpec:SetAnchor(TOPLEFT, control, TOPLEFT, buttonWidth + buttonGap, 159)
		clearDraft:SetWidth(buttonWidth)
		addRule:SetWidth(buttonWidth)
		addRule:ClearAnchors(); addRule:SetAnchor(TOPLEFT, control, TOPLEFT, buttonWidth + buttonGap, 193)
		summary:SetWidth(width - 4)
	end
	control.bmrResizeLayout(control:GetWidth())
	control.bmrSelectedField = "quality"
	control.bmrSelectedValue = nil
	control.bmrBuilding = true
	local draft = db.customFilterDraft or {searchString = "", specifications = {}}
	db.customFilterDraft = draft
	draft.specifications = type(draft.specifications) == "table" and draft.specifications or {}
	searchEdit:SetText(tostring(draft.searchString or ""))
	control.bmrBuilding = false
	searchEdit:SetHandler("OnTextChanged", function(self)
		db.customFilterDraft.searchString = self:GetText() or ""
		C.RefreshCustomFilterRuleEditor(control)
	end)

	local function RefreshValueChoices()
		local field = control.bmrSelectedField
		local filterText = zo_strlower(tostring(valueSearchEdit:GetText() or ""))
		local previousField = control.bmrSelectedField
		local previousValue = control.bmrSelectedValue
		valueCombo:ClearItems()
		control.bmrSelectedValue = nil
		control.bmrValueChoicesCache = control.bmrValueChoicesCache or {}
		local specificationFields = GetCustomFilterSpecificationFields()
		local fieldLabels = {}
		for _, fieldData in ipairs(specificationFields) do fieldLabels[fieldData.key] = fieldData.label end

		local candidates = {}
		local function getCachedValues(fieldKey)
			local values = control.bmrValueChoicesCache[fieldKey]
			if not values then
				values = GetCustomFilterSpecificationValues(fieldKey) or {}
				control.bmrValueChoicesCache[fieldKey] = values
			end
			return values
		end

		if filterText ~= "" then
			-- A non-empty query searches values across every specification. The
			-- source specification is appended to each result so duplicate labels
			-- remain distinguishable and the user can see which field will be used.
			for _, fieldData in ipairs(specificationFields) do
				for _, option in ipairs(getCachedValues(fieldData.key)) do
					local optionLabel = tostring(option.label or "")
					local displayLabel = optionLabel .. " (" .. tostring(fieldData.label) .. ")"
					if string.find(zo_strlower(displayLabel), filterText, 1, true) then
						table.insert(candidates, {field = fieldData.key, option = option, displayLabel = displayLabel})
					end
				end
			end
		else
			-- With an empty search, preserve the original one-specification view.
			local values = getCachedValues(field)
			if #values == 0 then
				local emptyLabel
				if field == "treasureType" then
					emptyLabel = GetString(BMR_CUSTOM_FILTER_NO_TREASURE_TYPES)
				elseif field == "furnitureBehavior" then
					emptyLabel = GetString(BMR_CUSTOM_FILTER_NO_FURNITURE_TAGS)
				elseif field == "foodTag" then
					emptyLabel = GetString(BMR_CUSTOM_FILTER_NO_FOOD_TAGS)
				elseif field == "tagContains" then
					emptyLabel = GetString(BMR_CUSTOM_FILTER_NO_TAGS)
				else
					emptyLabel = GetString(BMR_CUSTOM_FILTER_NO_VALUES)
				end
				local entry = valueCombo:CreateItemEntry(emptyLabel, function() control.bmrSelectedValue = nil end)
				valueCombo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
				valueCombo:SetSelectedItem(emptyLabel)
				return
			end
			for _, option in ipairs(values) do
				table.insert(candidates, {field = field, option = option, displayLabel = tostring(option.label or "")})
			end
		end

		local visibleCount = 0
		local selectedLabel = nil
		for _, candidate in ipairs(candidates) do
			local optionValue = candidate.option.value
			local optionLabel = candidate.displayLabel
			local candidateField = candidate.field
			local entry = valueCombo:CreateItemEntry(optionLabel, function()
				control.bmrSelectedField = candidateField
				control.bmrSelectedValue = optionValue
				-- Reflect the source field in the specification dropdown without
				-- treating this programmatic change like a manual field selection.
				control.bmrProgrammaticFieldSelection = true
				fieldCombo:SetSelectedItem(tostring(fieldLabels[candidateField] or candidateField))
				control.bmrProgrammaticFieldSelection = false
				RefreshValueChoices()
			end)
			entry.bmrFilterField = candidateField
			entry.bmrFilterValue = optionValue
			valueCombo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
			visibleCount = visibleCount + 1
			if previousValue ~= nil and previousField == candidateField and tostring(previousValue) == tostring(optionValue) then
				control.bmrSelectedValue = optionValue
				selectedLabel = optionLabel
			end
		end
		if visibleCount == 0 then
			local noMatchLabel = GetString(BMR_CUSTOM_FILTER_NO_MATCHING_VALUES)
			local entry = valueCombo:CreateItemEntry(noMatchLabel, function() control.bmrSelectedValue = nil end)
			valueCombo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
			valueCombo:SetSelectedItem(noMatchLabel)
			control.bmrSelectedValue = nil
		elseif selectedLabel then
			valueCombo:SetSelectedItem(selectedLabel)
		else
			-- Start with an empty selection; never silently choose the first option.
			if valueCombo.SetSelectedItemText then valueCombo:SetSelectedItemText("") else valueCombo:SetSelectedItem("") end
		end
	end
	control.bmrRefreshValueChoices = RefreshValueChoices
	fieldCombo:ClearItems()
	for _, field in ipairs(GetCustomFilterSpecificationFields()) do
		local fieldKey, fieldLabel = field.key, field.label
		local entry = fieldCombo:CreateItemEntry(fieldLabel, function()
			if control.bmrProgrammaticFieldSelection then return end
			control.bmrSelectedField = fieldKey
			control.bmrSelectedValue = nil
			control.bmrValueChoicesCache = control.bmrValueChoicesCache or {}
			valueSearchEdit:SetText("")
			RefreshValueChoices()
		end)
		entry.bmrFilterField = fieldKey
		fieldCombo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
	end
	valueSearchEdit:SetHandler("OnTextChanged", function() RefreshValueChoices() end)
	local initialFieldLabel = nil
	for _, fieldData in ipairs(GetCustomFilterSpecificationFields()) do
		if fieldData.key == control.bmrSelectedField then initialFieldLabel = fieldData.label break end
	end
	fieldCombo:SetSelectedItem(initialFieldLabel or GetString(BMR_CUSTOM_FILTER_QUALITY))
	RefreshValueChoices()

	local function ShowFilterMessage(message)
		SendCustomRuleMessage("[BMR] " .. tostring(message))
	end
	addSpec:SetHandler("OnClicked", function()
		local field = control.bmrSelectedField
		local fieldData
		for _, candidate in ipairs(GetCustomFilterSpecificationFields()) do if candidate.key == field then fieldData = candidate break end end
		if not fieldData then return end
		local value = control.bmrSelectedValue
		if value == nil or tostring(value) == "" then ShowFilterMessage(GetString(BMR_CUSTOM_FILTER_NO_VALUE)); return end
		local specs = db.customFilterDraft.specifications or {}
		local target
		for _, spec in ipairs(specs) do if spec.field == field then target = spec break end end
		if not target then target = {field = field, values = {}}; table.insert(specs, target) end
		local exists = false
		for _, priorValue in ipairs(target.values) do if tostring(priorValue) == tostring(value) then exists = true break end end
		if not exists then table.insert(target.values, value) end
		db.customFilterDraft.specifications = specs
		C.RefreshCustomFilterRuleEditor(control)
	end)
	removeSpec:SetHandler("OnClicked", function()
		local specs = db.customFilterDraft.specifications or {}
		if #specs > 0 then table.remove(specs, #specs); db.customFilterDraft.specifications = specs end
		C.RefreshCustomFilterRuleEditor(control)
	end)
	clearDraft:SetHandler("OnClicked", function()
		db.customFilterDraft = {searchString = "", specifications = {}, editingId = nil}
		searchEdit:SetText("")
		valueSearchEdit:SetText("")
		RefreshValueChoices()
		C.RefreshCustomFilterRuleEditor(control)
	end)
	local function SaveDraftAsNewOrOverwrite(overwriteEdited)
		local saved = C.SaveCustomFilterDraft(overwriteEdited)
		if not saved then return end
		searchEdit:SetText("")
		valueSearchEdit:SetText("")
		RefreshValueChoices()
		C.RefreshCustomFilterRuleEditor(control)
		local filterList = _G.BMRCustomFilterRuleDynamicList
		if filterList then C.RefreshCustomFilterRuleList(filterList) end
	end

	addRule:SetHandler("OnClicked", function()
		local currentDraft = db.customFilterDraft or {searchString = "", specifications = {}}
		local editingId = tonumber(currentDraft.editingId)
		local existing = editingId and db.customFilterRules and (db.customFilterRules[tostring(editingId)] or db.customFilterRules[editingId])
		if existing and type(ClearMenu) == "function" and type(AddMenuItem) == "function" and type(ShowMenu) == "function" then
			ClearMenu()
			AddMenuItem(GetString(BMR_CUSTOM_FILTER_SAVE_NEW), function() SaveDraftAsNewOrOverwrite(false) end)
			AddMenuItem(GetString(BMR_CUSTOM_FILTER_OVERWRITE), function() SaveDraftAsNewOrOverwrite(true) end)
			ShowMenu()
		else
			SaveDraftAsNewOrOverwrite(false)
		end
	end)
	C.RefreshCustomFilterRuleEditor(control)
end

function C.LoadCustomFilterRuleIntoDraft(filterId)
	local numericId = tonumber(filterId)
	local filterData = numericId and db.customFilterRules and (db.customFilterRules[tostring(numericId)] or db.customFilterRules[numericId])
	if type(filterData) ~= "table" then return end
	local previousDraft = GetConsoleDraft()
	db.customFilterDraft = {
		searchString = tostring(filterData.searchString or ""),
		specifications = DeepCopy(filterData.specifications or {}),
		editingId = numericId,
		consoleField = previousDraft.consoleField or "quality",
		consoleValueSearch = "",
	}
	ConsoleRuleSelection().filterId = numericId
	local editor = _G.BMRCustomFilterRuleEditor
	if editor and editor.bmrSearchEdit then
		editor.bmrSearchEdit:SetText(db.customFilterDraft.searchString)
		C.RefreshCustomFilterRuleEditor(editor)
	end
	SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_FILTER_EDIT_LOADED), tostring(filterData.name or numericId)))
	RefreshConsoleCustomRulePanel()
end



function C.CreateCustomRuleList(control)
	-- Row/header widths are recalculated from this control's width. Height is
	-- already set explicitly by RefreshCustomRuleList, so fit-to-descendants
	-- would only freeze the table to the original (narrower) content width.
	control:SetResizeToFitDescendents(false)
	control:SetDimensionConstraints(400, 30, 1500, 2400)
	control:SetHandler("OnSizeChanged", function(self)
		C._RuleUi.LayoutCustomRuleHeader(self)
		for _, row in ipairs(self.bmrRows or {}) do if not row:IsHidden() then C._RuleUi.LayoutCustomRuleRow(row, self) end end
	end)
	C.RefreshCustomRuleList(control)
end


function C.GetCustomRuleItemIdFromSlot(bagId, slotIndex)
	if not bagId or not slotIndex or GetItemType(bagId, slotIndex) == ITEMTYPE_NONE then return nil end
	local itemLink = GetItemLink(bagId, slotIndex)
	if not itemLink or itemLink == "" then return nil end
	local itemId = GetItemLinkItemId(itemLink)
	if not itemId or itemId <= 0 then return nil end
	return tonumber(itemId), itemLink
end

function C.HasCustomItemRule(itemId)
	local numericId = tonumber(itemId)
	if not numericId then return false end
	local rules = db.customItemRules or {}
	return rules[tostring(numericId)] ~= nil or rules[numericId] ~= nil
end

function C.ShouldShowSetCustomRuleAction()
	return db.hideSetAsBmrRule ~= true
end

function C.AddCustomItemRuleFromSlot(bagId, slotIndex)
	local itemId, itemLink = C.GetCustomRuleItemIdFromSlot(bagId, slotIndex)
	if not itemId then return false, "no-item" end
	db.customItemRules = db.customItemRules or {}
	local key = tostring(itemId)
	if C.HasCustomItemRule(itemId) then return false, "already-exists" end
	local itemName = FormatCustomItemName(itemLink, "Item " .. key) or ("Item " .. key)
	db.customItemRules[key] = {itemId = itemId, itemLink = itemLink, name = itemName}
	ConsoleRuleSelection().itemId = itemId
	for _, profile in pairs(db.profiles or {}) do
		if type(profile) == "table" then
			profile.rules = profile.rules or {}
			profile.rules.customItemsAll = profile.rules.customItemsAll or {action = ACTION_NOTSET, associatedGuild = GetString(BMR_ACTION_NOTSET), onlyIfNotFullStack = true, onlyStacks = 1}
			local ruleName = "customItem_" .. key
			profile.rules[ruleName] = {
				action = ACTION_NOTSET,
				associatedGuild = profile.rules.customItemsAll.associatedGuild or GetString(BMR_ACTION_NOTSET),
				onlyIfNotFullStack = profile.rules.customItemsAll.onlyIfNotFullStack ~= false,
				onlyStacks = tonumber(profile.rules.customItemsAll.onlyStacks) or 1,
			}
		end
	end
	if BMR.SyncCustomItemRuleDefinitions then BMR.SyncCustomItemRuleDefinitions() end
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() end
	SendCustomRuleMessage(zo_strformat(GetString(BMR_CUSTOM_RULE_ADDED), itemName))
	return true, itemId
end

function C.RenameCustomItemRuleById(itemId, newName)
	local numericId = tonumber(itemId)
	if not numericId then return false, "invalid-id" end
	local key = tostring(numericId)
	local itemData = db.customItemRules and (db.customItemRules[key] or db.customItemRules[numericId])
	if type(itemData) ~= "table" then return false, "missing-rule" end
	local name = string.gsub(tostring(newName or ""), "^%s*(.-)%s*$", "%1")
	if name == "" then return false, "empty-name" end
	local nameLength = type(zo_strlen) == "function" and zo_strlen(name) or #name
	if nameLength > 64 then return false, "too-long" end
	local normalized = zo_strlower(name)
	for otherId, otherData in pairs(db.customItemRules or {}) do
		if tonumber(otherId) and tonumber(otherId) ~= numericId and type(otherData) == "table" then
			if zo_strlower(C.GetCustomItemDisplayName(otherId, otherData)) == normalized then return false, "duplicate-name" end
		end
	end
	for otherId, otherData in pairs(db.customFilterRules or {}) do
		if tonumber(otherId) and type(otherData) == "table" and zo_strlower(C.GetCustomFilterDisplayName(otherId, otherData)) == normalized then return false, "duplicate-name" end
	end
	local originalName = FormatCustomItemName(itemData.itemLink, itemData.name) or itemData.name or ("Item " .. key)
	if zo_strlower(originalName) == normalized then itemData.displayName = nil else itemData.displayName = name end
	if BMR.SyncCustomItemRuleDefinitions then BMR.SyncCustomItemRuleDefinitions() end
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() else RefreshConsoleCustomRulePanel() end
	return true
end

function C.ShowRenameCustomItemDialog(itemId)
	if type(ZO_Dialogs_ShowDialog) ~= "function" then return false end
	local dialogName = "BMR_CUSTOM_ITEM_RENAME_DIALOG"
	if not C._renameItemDialogRegistered then
		if type(ESO_Dialogs) ~= "table" then return false end
		ESO_Dialogs[dialogName] = {
			title = {text = GetString(BMR_CUSTOM_ITEM_RENAME_TITLE)},
			mainText = {text = GetString(BMR_CUSTOM_ITEM_RENAME_PROMPT)},
			editBox = {maxInputCharacters = 64},
			buttons = {
				{text = SI_DIALOG_CONFIRM, callback = function(dialog)
					local id = dialog and dialog.data and tonumber(dialog.data[1])
					local value = type(ZO_Dialogs_GetEditBoxText) == "function" and ZO_Dialogs_GetEditBoxText(dialog) or ""
					local ok, reason = C.RenameCustomItemRuleById(id, value)
					if not ok then
						local message = reason == "duplicate-name" and GetString(BMR_CUSTOM_FILTER_RENAME_DUPLICATE) or GetString(BMR_CUSTOM_FILTER_RENAME_INVALID)
						SendCustomRuleMessage("[BMR] " .. message)
					else
						SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(BMR_CUSTOM_ITEM_RENAMED), C.GetCustomItemDisplayName(id)))
					end
				end},
				{text = SI_DIALOG_CANCEL},
			},
		}
		C._renameItemDialogRegistered = true
	end
	ZO_Dialogs_ShowDialog(dialogName, {tonumber(itemId)}, {initialEditText = C.GetCustomItemDisplayName(itemId)})
	return true
end

function C.GetConsoleCustomItemRenameDraft()
	local id = C.GetConsoleSelectedCustomItemId()
	if not id then return "" end
	if tonumber(db.customItemRenameTarget) ~= tonumber(id) then
		db.customItemRenameTarget = id
		db.customItemRenameDraft = C.GetCustomItemDisplayName(id)
	end
	return tostring(db.customItemRenameDraft or "")
end

function C.SetConsoleCustomItemRenameDraft(value)
	db.customItemRenameDraft = tostring(value or "")
end

function C.ApplyConsoleCustomItemRename()
	local id = C.GetConsoleSelectedCustomItemId()
	if not id then return false end
	local ok, reason = C.RenameCustomItemRuleById(id, db.customItemRenameDraft or "")
	if not ok then
		local message = reason == "duplicate-name" and GetString(BMR_CUSTOM_FILTER_RENAME_DUPLICATE) or GetString(BMR_CUSTOM_FILTER_RENAME_INVALID)
		SendCustomRuleMessage("[BMR] " .. message)
		return false
	end
	SendCustomRuleMessage("[BMR] " .. zo_strformat(GetString(BMR_CUSTOM_ITEM_RENAMED), C.GetCustomItemDisplayName(id)))
	return true
end

function C.RemoveCustomItemRuleById(itemId)
	local numericId = tonumber(itemId)
	if not numericId then return false end
	local key = tostring(numericId)
	if not db.customItemRules or not (db.customItemRules[key] or db.customItemRules[numericId]) then return false end
	db.customItemRules[key] = nil
	db.customItemRules[numericId] = nil
	local ruleName = "customItem_" .. key
	for _, profile in pairs(db.profiles or {}) do if profile.rules then profile.rules[ruleName] = nil end end
	if BankManagerRules and BankManagerRules.data then BankManagerRules.data[ruleName] = nil end
	if BankManagerRules and BankManagerRules.defaults then BankManagerRules.defaults[ruleName] = nil end
	if ConsoleRuleSelection().itemId == numericId then ConsoleRuleSelection().itemId = nil end
	if BMR.SyncCustomItemRuleDefinitions then BMR.SyncCustomItemRuleDefinitions() end
	if BMR.refreshCustomRuleOptions then BMR.refreshCustomRuleOptions() else RefreshConsoleCustomRulePanel() end
	return true
end

function C.RemoveCustomItemRuleFromSlot(bagId, slotIndex)
	local itemId = C.GetCustomRuleItemIdFromSlot(bagId, slotIndex)
	if not itemId then return false, "no-item" end
	return C.RemoveCustomItemRuleById(itemId)
end

function C.RegisterCustomItemContextMenuActions()
	-- Use LibCustomMenu's supported callback API rather than hooking ESO's
	-- inventory action discovery directly. Hooking that function can taint
	-- native secure actions such as TryBankItem/PickupInventoryItem.
	if BMR.customItemActionsRegistered then return true, "already registered" end
	local menu = LibCustomMenu
	if not menu or type(menu.RegisterContextMenu) ~= "function" then
		-- Do not fall back to an unsafe hook when LibCustomMenu is unavailable.
		return false, "LibCustomMenu:RegisterContextMenu unavailable"
	end

	local function AddCustomRuleAction(inventorySlot, slotActions)
		if not inventorySlot or not slotActions or type(slotActions.AddCustomSlotAction) ~= "function" then
			CustomRuleDebug("CONTEXT ACTION SKIP reason=missing inventory slot or AddCustomSlotAction")
			return
		end
		-- Gamepad bridge versions normalize their slot type, but controller inventory
		-- flows can still expose a different type constant than the keyboard UI. Do not
		-- whitelist slot types here: a valid bag/index containing a real item is enough.
		if type(ZO_Inventory_GetBagAndIndex) ~= "function" then
			CustomRuleDebug("CONTEXT ACTION SKIP reason=ZO_Inventory_GetBagAndIndex unavailable")
			return
		end
		local bagOk, bagId, slotIndex = pcall(ZO_Inventory_GetBagAndIndex, inventorySlot)
		if not bagOk or bagId == nil or slotIndex == nil then
			local slotType = "n/a"
			if type(ZO_InventorySlot_GetType) == "function" then
				local typeOk, resolvedType = pcall(ZO_InventorySlot_GetType, inventorySlot)
				if typeOk then slotType = tostring(resolvedType) end
			end
			CustomRuleDebug("CONTEXT ACTION SKIP reason=bag/index unavailable slotType=" .. slotType)
			return
		end
		local itemOk, itemId = pcall(C.GetCustomRuleItemIdFromSlot, bagId, slotIndex)
		if not itemOk or not itemId then
			CustomRuleDebug("CONTEXT ACTION SKIP reason=no item bag=" .. tostring(bagId) .. " slot=" .. tostring(slotIndex) .. " error=" .. tostring(itemId))
			return
		end
		local hasRule = db.customItemRules and (db.customItemRules[tostring(itemId)] ~= nil or db.customItemRules[itemId] ~= nil)
		local slotType = "n/a"
		if type(ZO_InventorySlot_GetType) == "function" then
			local typeOk, resolvedType = pcall(ZO_InventorySlot_GetType, inventorySlot)
			if typeOk then slotType = tostring(resolvedType) end
		end
		if hasRule then
			local added, addError = pcall(slotActions.AddCustomSlotAction, slotActions, BMR_CUSTOM_RULE_REMOVE_MENU, function()
				C.RemoveCustomItemRuleFromSlot(bagId, slotIndex)
			end, "secondary")
			CustomRuleDebug("CONTEXT ACTION " .. (added and "ADDED" or "ADD FAILED") .. " remove itemId=" .. tostring(itemId) .. " bag=" .. tostring(bagId) .. " slot=" .. tostring(slotIndex) .. " slotType=" .. tostring(slotType) .. (not added and (" error=" .. tostring(addError)) or ""))
		elseif db.hideSetAsBmrRule ~= true then
			local added, addError = pcall(slotActions.AddCustomSlotAction, slotActions, BMR_CUSTOM_RULE_SET, function()
				C.AddCustomItemRuleFromSlot(bagId, slotIndex)
			end, "secondary")
			CustomRuleDebug("CONTEXT ACTION " .. (added and "ADDED" or "ADD FAILED") .. " set itemId=" .. tostring(itemId) .. " bag=" .. tostring(bagId) .. " slot=" .. tostring(slotIndex) .. " slotType=" .. tostring(slotType) .. (not added and (" error=" .. tostring(addError)) or ""))
		else
			CustomRuleDebug("CONTEXT ACTION HIDDEN by setting itemId=" .. tostring(itemId))
		end
	end

	-- CATEGORY_LATE places the BMR entry after native game actions/variants.
	menu:RegisterContextMenu(AddCustomRuleAction, menu.CATEGORY_LATE)
	BMR.customItemActionsRegistered = true
	return true, "LibCustomMenu context callback registered"
end



-- Ensure new account-wide catalogue storage exists after BMVars has been loaded.
if db then
	db.customItemTagCatalog = db.customItemTagCatalog or {}
	db.customItemTagScan = db.customItemTagScan or {nextId = 1, maxId = TAG_SCAN_MAX_DEFAULT, completed = false}
end
