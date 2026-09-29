-- =================================================================================================
-- Мовна база: відповідність українських назв англійським.
--
-- Англійські назви беремо з самої гри, двічі перемикаючи мову клієнта:
--   1. Українська мова (CollectUkrainianKeys): збираємо українські назви -> id / посилання.
--   2. Англійська мова (CollectEnglishValues): за тими самими id отримуємо англійські назви.
--   3. Повертаємо українську мову.
-- Кожне перемикання мови перезавантажує інтерфейс, тому поточний крок зберігається в db.pendingStep.
-- База спільна для всіх серверів (вона залежить лише від версії гри та адона).
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util
local StaticData = DovahMova.StaticData

local Database = {}
DovahMova.Database = Database

local MAX_ITEM_ID = 300000
local MAX_KEEP_ID = 1000
local MAX_TRAIT_TYPE = 100
local GLYPH_BASE_ITEM_ID = 5364        -- гліф, з назв якого вирізаються префікси сили гліфа
local AFFIX_BASE_ITEM_ID = 43533       -- предмет, до якого додаються зачарування-суфікси

local STEP_UKRAINIAN = "ua"
local STEP_ENGLISH = "en"

Database.DEFAULTS = {
	ApiVersion = 0,
	AddonVersion = "",
	pendingStep = nil,
	Abilities = {},       -- abilityId -> англійська назва
	Items = {},           -- itemId -> англійська назва
	Sets = {},            -- setId -> англійська назва сету
	SetsNames = {},       -- укр. назва сету -> англійська
	Traits = {},          -- traitType -> англійська назва
	Potions = {},         -- укр. назва зілля -> англійська
	Locations = {},       -- укр. назва локації -> англійська
	ScribingScripts = {}, -- scriptId -> англійська назва
	Parts = {},           -- укр. базова частина предмета -> англійська
	Prefixes = {},        -- укр. матеріал (нормалізований) -> англійський префікс
	Affixes = {},         -- укр. суфікс зачарування -> англійський
	EnchantPrefixes = {}, -- укр. префікс гліфа -> англійський
}

local TABLE_NAMES = {
	"Abilities", "Items", "Sets", "SetsNames", "Traits", "Potions", "Locations",
	"ScribingScripts", "Parts", "Prefixes", "Affixes", "EnchantPrefixes",
}

local function GetItemName(spec)
	-- Під час побудови бази беремо назву без хуків DovahMova
	return DovahMova.ItemNames.GetRawItemLinkName(Util.ItemLink(spec))
end

local function GetBaseItemId(spec)
	return tonumber(string.match(tostring(spec), "^(%d+)"))
end

local function FormatItemName(name)
	return ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, name)
end

local function SwitchLanguage(lang)
	SetCVar("language.2", lang)
end

function Database.IsOutdated()
	local db = DovahMova.db
	return db.ApiVersion ~= GetAPIVersion() or db.AddonVersion ~= DovahMova.version
end

-- -------------------------------------------------------------------------------------------------
-- Крок 1: українські ключі
-- -------------------------------------------------------------------------------------------------

local function CollectSetNamesUkrainian(db)
	for itemId = 1, MAX_ITEM_ID do
		local hasSet, setName = GetItemLinkSetInfo(Util.ItemLink(itemId))
		if hasSet then
			local key = Util.ToKey(setName)
			if not db.SetsNames[key] then
				db.SetsNames[key] = itemId
			end
		end
	end
end

--- Додає запис «ключ з назви -> значення», пропускаючи порожні назви.
local function AddKey(target, name, value)
	local key = name and Util.ToKey(name)
	if key and key ~= "" then
		target[key] = value
	end
end

local function CollectItemPartsUkrainian(db)
	for _, spec in ipairs(StaticData.PotionLinks) do
		AddKey(db.Potions, GetItemName(spec), spec)
	end

	for _, itemId in ipairs(StaticData.BasePartItemIds) do
		AddKey(db.Parts, GetItemName(itemId), itemId)
	end

	local glyphBase = Util.ToKey(GetItemName(GLYPH_BASE_ITEM_ID))
	for _, spec in ipairs(StaticData.GlyphPrefixLinks) do
		local prefix = zo_strtrim(Util.PlainReplace(Util.ToKey(GetItemName(spec)), glyphBase, ""))
		if prefix ~= "" then
			db.EnchantPrefixes[prefix] = spec
		end
	end

	for _, spec in ipairs(StaticData.MaterialPrefixLinks) do
		local base = Util.ToKey(GetItemName(GetBaseItemId(spec)))
		local prefix = Util.PlainReplace(Util.ToKey(GetItemName(spec)), " " .. base, "")
		prefix = Util.RepairCyrillic(Util.StripGrammarTags(prefix))
		if prefix ~= "" and prefix ~= base then
			db.Prefixes[DovahMova.ItemNames.NormalizeAdjective(prefix)] = spec
		end
	end

	local affixBase = Util.ToKey(GetItemName(AFFIX_BASE_ITEM_ID))
	for _, enchantId in ipairs(StaticData.AffixEnchantIds) do
		local name = Util.ToKey(GetItemName(string.format("%d:0:0:%d", AFFIX_BASE_ITEM_ID, enchantId)))
		local affix = Util.PlainReplace(name, affixBase .. " ", "")
		if affix ~= "" and affix ~= affixBase then
			db.Affixes[affix] = enchantId
		end
	end
end

local function AddLocation(db, name, reference)
	if name and name ~= "" then
		db.Locations[Util.ToKey(name)] = reference
	end
end

local function CollectLocationsUkrainian(db)
	for zoneIndex = 1, GetNumZones() do
		AddLocation(db, GetZoneNameByIndex(zoneIndex), string.format("zone:%d:0", zoneIndex))
		for poiIndex = 1, GetNumPOIs(zoneIndex) do
			AddLocation(db, GetPOIInfo(zoneIndex, poiIndex), string.format("poi:%d:%d", zoneIndex, poiIndex))
		end
	end

	for nodeIndex = 1, GetNumFastTravelNodes() do
		local _, name = GetFastTravelNodeInfo(nodeIndex)
		AddLocation(db, name, string.format("ft:%d:0", nodeIndex))
	end

	for keepId = 1, MAX_KEEP_ID do
		AddLocation(db, GetKeepName(keepId), string.format("keep:%d:0", keepId))
	end

	local sortedLocations = ZO_ACTIVITY_FINDER_ROOT_MANAGER and ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData
	if sortedLocations then
		for _, activityType in ipairs({ LFG_ACTIVITY_DUNGEON, LFG_ACTIVITY_MASTER_DUNGEON }) do
			for index, location in ipairs(sortedLocations[activityType] or {}) do
				local key = location.rawName and Util.ToKey(location.rawName)
				if key and key ~= "" and not db.Locations[key] then
					db.Locations[key] = string.format("activity:%d:%d", index, activityType)
				end
			end
		end
	end
end

local function CollectScribingScriptIds(db)
	if not IsScribingEnabled() then
		return
	end
	for abilityIndex = 1, GetNumCraftedAbilities() do
		local craftedAbilityId = GetCraftedAbilityIdAtIndex(abilityIndex)
		for slotType = SCRIBING_SLOT_PRIMARY, SCRIBING_SLOT_TERTIARY do
			for scriptIndex = 1, GetNumScriptsInSlotForCraftedAbility(craftedAbilityId, slotType) do
				local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slotType, scriptIndex)
				if scriptId then
					db.ScribingScripts[scriptId] = true
				end
			end
		end
	end
end

function Database.CollectUkrainianKeys()
	local db = DovahMova.db
	DovahMova.isBuildingDatabase = true

	CollectSetNamesUkrainian(db)
	CollectItemPartsUkrainian(db)
	CollectLocationsUkrainian(db)
	CollectScribingScriptIds(db)

	DovahMova.isBuildingDatabase = false
	db.pendingStep = STEP_ENGLISH
	SwitchLanguage("en")
end

-- -------------------------------------------------------------------------------------------------
-- Крок 2: англійські значення
-- -------------------------------------------------------------------------------------------------

local function CollectItemsEnglish(db)
	for itemId = 1, MAX_ITEM_ID do
		local itemLink = Util.ItemLink(itemId)
		local name = GetItemLinkName(itemLink)
		if name ~= "" and not zo_plainstrfind(name, "_") then
			db.Items[itemId] = FormatItemName(name)
		end
		local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink)
		if hasSet then
			db.Sets[setId] = setName
		end
	end
end

local function CollectItemPartsEnglish(db)
	for key, itemId in pairs(db.SetsNames) do
		local hasSet, setName = GetItemLinkSetInfo(Util.ItemLink(itemId))
		db.SetsNames[key] = hasSet and FormatItemName(setName) or nil
	end

	for key, spec in pairs(db.Potions) do
		db.Potions[key] = FormatItemName(GetItemName(spec))
	end

	for key, itemId in pairs(db.Parts) do
		db.Parts[key] = FormatItemName(GetItemName(itemId))
	end

	local glyphBase = " " .. GetItemName(GLYPH_BASE_ITEM_ID)
	for key, spec in pairs(db.EnchantPrefixes) do
		db.EnchantPrefixes[key] = FormatItemName(Util.PlainReplace(GetItemName(spec), glyphBase, ""))
	end

	for key, spec in pairs(db.Prefixes) do
		local base = " " .. FormatItemName(GetItemName(GetBaseItemId(spec)))
		db.Prefixes[key] = Util.PlainReplace(FormatItemName(GetItemName(spec)), base, "")
	end

	local affixBase = FormatItemName(GetItemName(AFFIX_BASE_ITEM_ID)) .. " "
	for key, enchantId in pairs(db.Affixes) do
		local name = FormatItemName(GetItemName(string.format("%d:0:0:%d", AFFIX_BASE_ITEM_ID, enchantId)))
		db.Affixes[key] = Util.PlainReplace(name, affixBase, "")
	end
end

local function GetEnglishLocationName(locationType, id, subId)
	if locationType == "zone" then
		return GetZoneNameByIndex(id)
	elseif locationType == "poi" then
		return GetPOIInfo(id, subId)
	elseif locationType == "keep" then
		return GetKeepName(id)
	elseif locationType == "ft" then
		return select(2, GetFastTravelNodeInfo(id))
	elseif locationType == "activity" then
		local locations = ZO_ACTIVITY_FINDER_ROOT_MANAGER.sortedLocationsData[subId]
		return locations and locations[id] and locations[id].rawName
	end
end

local function CollectLocationsEnglish(db)
	for key, reference in pairs(db.Locations) do
		local locationType, id, subId = string.match(reference, "^(%a+):(%d+):(%d+)$")
		if locationType then
			local name = GetEnglishLocationName(locationType, tonumber(id), tonumber(subId))
			db.Locations[key] = name and ZO_CachedStrFormat(SI_ZONE_NAME, name) or nil
		end
		-- Записи без посилання — готові англійські назви з StaticData.DungeonNames
	end
end

local function CollectAbilitiesEnglish(db)
	for skillType = 1, GetNumSkillTypes() do
		for skillLineIndex = 1, GetNumSkillLines(skillType) do
			for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
				local _, _, _, isPassive = GetSkillAbilityInfo(skillType, skillLineIndex, skillIndex)
				if isPassive then
					for rank = 1, GetNumPassiveSkillRanks(skillType, skillLineIndex, skillIndex) do
						local abilityId = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 0, rank)
						db.Abilities[abilityId] = GetAbilityName(abilityId)
					end
				else
					for morph = 0, 2 do
						local abilityId = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, morph, 1)
						db.Abilities[abilityId] = GetAbilityName(abilityId)
					end
				end
			end
		end
	end

	for abilityId in pairs(StaticData.CompanionAbilities) do
		db.Abilities[abilityId] = GetAbilityName(abilityId)
	end

	for disciplineIndex = 1, GetNumChampionDisciplines() do
		for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
			local championSkillId = GetChampionSkillId(disciplineIndex, skillIndex)
			db.Abilities[GetChampionAbilityId(championSkillId)] = GetChampionSkillName(championSkillId)
		end
	end
end

function Database.CollectEnglishValues()
	local db = DovahMova.db
	DovahMova.isBuildingDatabase = true

	CollectItemsEnglish(db)
	CollectItemPartsEnglish(db)
	CollectLocationsEnglish(db)
	CollectAbilitiesEnglish(db)

	for traitType = 1, MAX_TRAIT_TYPE do
		local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
		if traitName ~= "" then
			db.Traits[traitType] = traitName
		end
	end

	for scriptId in pairs(db.ScribingScripts) do
		db.ScribingScripts[scriptId] = GetCraftedAbilityScriptDisplayName(scriptId)
	end

	db.ApiVersion = GetAPIVersion()
	db.AddonVersion = DovahMova.version
	DovahMova.settings.IsUpdateNeeded = true
	DovahMova.isBuildingDatabase = false

	db.pendingStep = nil
	SwitchLanguage("ua")
end

-- -------------------------------------------------------------------------------------------------
-- Керування процесом
-- -------------------------------------------------------------------------------------------------

--- Починає перебудову бази (кнопка в налаштуваннях / діалог після оновлення).
function Database.StartRebuild()
	local db = DovahMova.db
	for _, tableName in ipairs(TABLE_NAMES) do
		db[tableName] = {}
	end
	ZO_ShallowTableCopy(StaticData.DungeonNames, db.Locations)

	if DovahMova.IsUkrainian() then
		Database.CollectUkrainianKeys()
	else
		db.pendingStep = STEP_UKRAINIAN
		SwitchLanguage("ua")
	end
end

--- Продовжує перебудову після перезавантаження інтерфейсу (EVENT_PLAYER_ACTIVATED).
function Database.ResumePendingStep()
	local step = DovahMova.db.pendingStep
	local lang = DovahMova.GetClientLanguage()
	if step == STEP_ENGLISH and lang == "en" then
		Database.CollectEnglishValues()
	elseif step == STEP_UKRAINIAN and lang == "ua" then
		Database.CollectUkrainianKeys()
	end
end
