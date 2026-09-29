-- =================================================================================================
-- Tamriel Trade Centre: ціни для предметів з українськими назвами.
--
-- TTC шукає ціну за ключем string.lower(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link)))
-- у таблиці TamrielTradeCentre.ItemLookUpTable, яка містить лише англійські назви.
-- Кнопка «Згенерувати TTC» будує відповідність «український ключ -> англійський ключ»
-- (зберігається в збережених змінних), а при кожному запуску ці аліаси додаються в таблицю TTC.
--
-- Щоб TTC взагалі запускався в українському клієнті, його треба один раз пропатчити скриптом
-- ttc_ua_setup.bat / ttc_ua_setup.sh (див. README.txt).
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local TTCPrices = {}
DovahMova.TTCPrices = TTCPrices

local store -- збережені змінні: { aliases = { [укр. ключ] = англ. ключ }, displayMode, addonVersion }

local function ToLookupKey(name)
	return string.lower(zo_strformat(SI_TOOLTIP_ITEM_NAME, name))
end

local function GetLookupTable()
	return TamrielTradeCentre and TamrielTradeCentre.ItemLookUpTable
end

--- Перебирає пари «українська назва — англійська назва» гліфів, сутностей, зілль і отрут.
local function ForEachHardcodedName(callback)
	local names = DovahMova.IntegrationStrings.TamrielTradeCentre
	for ukrainianName, englishName in pairs(names.essences) do
		callback(ukrainianName, englishName)
	end
	for ukrainianName, englishName in pairs(names.potions) do
		callback(ukrainianName, englishName)
		for ukrainianType, englishType in pairs(names.potionTypes) do
			callback(ukrainianType .. " " .. ukrainianName, englishType .. " " .. englishName)
		end
	end
	for ukrainianName, englishName in pairs(names.poisons) do
		callback(ukrainianName, englishName)
		for ukrainianNumber, englishNumber in pairs(names.romanNumerals) do
			callback(ukrainianName .. " " .. ukrainianNumber, englishName .. " " .. englishNumber)
		end
	end
	for ukrainianPrefix, englishPrefix in pairs(names.glyphPrefixes) do
		for ukrainianGlyph, englishGlyph in pairs(names.glyphTypes) do
			callback(ukrainianPrefix .. " " .. ukrainianGlyph, englishPrefix .. " " .. englishGlyph)
		end
	end
end

--- Додає збережені аліаси в таблицю TTC. Записи TTC не копіюються, тож ціни завжди актуальні.
function TTCPrices.ApplyAliases()
	local lookupTable = GetLookupTable()
	if not lookupTable or not store then
		return
	end
	for ukrainianKey, englishKey in pairs(store.aliases) do
		local entry = lookupTable[englishKey]
		if entry then
			lookupTable[ukrainianKey] = entry
		end
	end
end

function TTCPrices.IsAvailable()
	return GetLookupTable() ~= nil and store ~= nil and DovahMova.IsUkrainian()
end

--- Будує аліаси для всіх предметів мовної бази (кнопка в налаштуваннях). Повертає кількість аліасів.
function TTCPrices.Generate()
	local lookupTable = GetLookupTable()
	local aliases = {}
	local count = 0

	local function AddAlias(ukrainianName, englishKey)
		local ukrainianKey = ToLookupKey(ukrainianName)
		if ukrainianKey ~= englishKey and not aliases[ukrainianKey] then
			aliases[ukrainianKey] = englishKey
			count = count + 1
		end
	end

	for itemId, englishName in pairs(DovahMova.db.Items) do
		local englishKey = ToLookupKey(englishName)
		if lookupTable[englishKey] then
			local itemLink = Util.ItemLink(itemId)
			AddAlias(GetItemLinkName(itemLink), englishKey) -- як показується з поточними налаштуваннями
			AddAlias(DovahMova.ItemNames.GetRawItemLinkName(itemLink), englishKey)
		end
	end

	ForEachHardcodedName(function(ukrainianName, englishName)
		local englishKey = string.lower(englishName)
		if lookupTable[englishKey] then
			AddAlias(ukrainianName, englishKey)
			AddAlias(string.format("%s (%s)", ukrainianName, englishName), englishKey)
		end
	end)

	store.aliases = aliases
	store.displayMode = DovahMova.settings.ShowItemsDisplay
	store.addonVersion = DovahMova.version
	TTCPrices.ApplyAliases()
	return count
end

DovahMova.RegisterIntegration({
	name = "TamrielTradeCentre",
	IsAvailable = function()
		return GetLookupTable() ~= nil
	end,
	Apply = function()
		store = ZO_SavedVars:NewAccountWide("DovahMovaVariables", 2, "TTC", { aliases = {} })
		TTCPrices.ApplyAliases()

		local isOutdated = next(store.aliases) == nil
			or store.displayMode ~= DovahMova.settings.ShowItemsDisplay
			or store.addonVersion ~= DovahMova.version
		if isOutdated then
			-- Чат доступний лише після входу у світ
			local eventName = DovahMova.name .. "_TTCPrices"
			EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, function()
				EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
				DovahMova.Print("таблиця цін TTC застаріла — натисніть «Згенерувати TTC» у налаштуваннях DovahMova.")
			end)
		end
	end,
})
