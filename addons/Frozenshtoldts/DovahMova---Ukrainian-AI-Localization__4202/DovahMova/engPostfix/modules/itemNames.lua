-- =================================================================================================
-- Пошук англійської назви предмета за українською назвою та itemId.
-- Спільна логіка для спливаючих вікон, інвентаря, торговців і гільдійського магазину.
--
-- Звідки беруться дані (див. Database.lua):
--   db.Items[itemId]          — англійська назва базового предмета;
--   db.Prefixes[укр. матеріал] — префікс матеріалу ("кленовий" -> "Maple");
--   db.Parts[укр. база]        — базова частина ремісничого предмета ("лук" -> "Bow");
--   db.Affixes[укр. суфікс]    — суфікс зачарування ("полум'я" -> "of Flame");
--   db.EnchantPrefixes         — префікси гліфів ("незначний" -> "Trifling");
--   db.Potions[укр. назва]     — повні назви зілль/отрут.
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local ItemNames = {}
DovahMova.ItemNames = ItemNames

-- Оригінальні функції гри; заповнюються до встановлення будь-яких хуків (див. itemsDisplay.lua)
ItemNames.GetRawItemLinkName = GetItemLinkName
ItemNames.GetRawItemName = GetItemName

-- Прикраси в ESO теж мають тип ITEMTYPE_ARMOR
local GEAR_TYPES = {
	[ITEMTYPE_ARMOR] = true,
	[ITEMTYPE_WEAPON] = true,
}
local GLYPH_TYPES = {
	[ITEMTYPE_GLYPH_ARMOR] = true,
	[ITEMTYPE_GLYPH_JEWELRY] = true,
	[ITEMTYPE_GLYPH_WEAPON] = true,
}
local POTION_TYPES = {
	[ITEMTYPE_POTION] = true,
	[ITEMTYPE_POISON] = true,
}
ItemNames.GEAR_TYPES = GEAR_TYPES
ItemNames.GLYPH_TYPES = GLYPH_TYPES

local UKRAINIAN_VOWELS = {
	["а"] = true, ["е"] = true, ["є"] = true, ["и"] = true, ["і"] = true,
	["ї"] = true, ["о"] = true, ["у"] = true, ["ю"] = true, ["я"] = true,
}
local MIN_STEM_BYTES = 6 -- три кириличні літери

local function GetDB()
	return DovahMova.db
end

--- Зводить прикметник до «чоловічої» форми, у якій зберігаються ключі db.Prefixes.
-- Та сама нормалізація застосовується при побудові бази.
function ItemNames.NormalizeAdjective(word)
	word = string.gsub(word, "і$", "ий") -- залізоткані -> залізотканий
	word = string.gsub(word, "а$", "ий") -- залізоткана -> залізотканий
	word = string.gsub(word, "я$", "ий")
	word = string.gsub(word, "е$", "ий")
	return word
end

--- Основа прикметника без закінчення: "кленова" -> "кленов", "синій" -> "син".
local function GetStem(word)
	if string.sub(word, -2) == "й" then
		word = string.sub(word, 1, -3)
	end
	if UKRAINIAN_VOWELS[string.sub(word, -2)] then
		word = string.sub(word, 1, -3)
	end
	return word
end

local materialCache = {}

--- Англійський префікс матеріалу для українського прикметника ("кленова" -> "Maple").
function ItemNames.FindMaterial(word)
	local cached = materialCache[word]
	if cached ~= nil then
		return cached or nil
	end

	local prefixes = GetDB().Prefixes
	local key = Util.ToKey(Util.StripGrammarTags(word))
	local result = prefixes[key] or prefixes[ItemNames.NormalizeAdjective(key)]

	if not result then
		-- Інша форма відмінювання: шукаємо найдовший ключ з тією ж основою
		local stem = GetStem(key)
		if #stem >= MIN_STEM_BYTES then
			local bestLength = 0
			for prefixKey, englishPrefix in pairs(prefixes) do
				if #prefixKey > bestLength and string.sub(prefixKey, 1, #stem) == stem then
					result = englishPrefix
					bestLength = #prefixKey
				end
			end
		end
	end

	materialCache[word] = result or false
	return result
end

--- Розбір назви ремісничого предмета, для якого немає прямого перекладу:
-- "[матеріал] база [суфікс]" -> "[Material] Base [of Affix]".
local function TranslateCraftedName(ukrainianName)
	local db = GetDB()
	local words = Util.SplitWords(Util.ToKey(ukrainianName))

	for first = 1, #words do
		for last = #words, first, -1 do
			local englishBase = db.Parts[table.concat(words, " ", first, last)]
			if englishBase then
				local parts = {}
				if first > 1 then
					local material = ItemNames.FindMaterial(table.concat(words, " ", 1, first - 1))
					if material then
						parts[#parts + 1] = material
					end
				end
				parts[#parts + 1] = englishBase
				if last < #words then
					local affix = db.Affixes[table.concat(words, " ", last + 1, #words)]
					if affix then
						parts[#parts + 1] = affix
					end
				end
				return table.concat(parts, " ")
			end
		end
	end
	return nil
end

local function TranslateGlyphName(ukrainianName, englishBase)
	local paddedName = " " .. Util.ToKey(ukrainianName) .. " "
	for ukrainianPrefix, englishPrefix in pairs(GetDB().EnchantPrefixes) do
		if zo_plainstrfind(paddedName, " " .. ukrainianPrefix .. " ") then
			return englishPrefix .. " " .. englishBase
		end
	end
	return englishBase
end

local function TranslateGearName(ukrainianName, englishBase)
	-- Назви спорядження в базі — без матеріалу ("Bow"), а в грі — з ним ("кленовий лук")
	if Util.CountWords(ukrainianName) > Util.CountWords(englishBase) then
		local material = ItemNames.FindMaterial(Util.SplitWords(ukrainianName)[1])
		if material then
			return material .. " " .. englishBase
		end
	end
	return englishBase
end

local englishNameCache = {}

--- Англійська назва предмета.
-- @param ukrainianName  назва з гри (після узгодження прикметників, без постфікса)
-- @param itemId         id предмета
-- @param itemType       ITEMTYPE_* (необов'язково)
-- @return англійська назва або nil
function ItemNames.GetEnglishName(ukrainianName, itemId, itemType)
	if not ukrainianName or ukrainianName == "" or not itemId or itemId <= 0 then
		return nil
	end
	ukrainianName = Util.StripPostfix(ukrainianName)

	local cacheKey = itemId .. ":" .. ukrainianName
	local cached = englishNameCache[cacheKey]
	if cached ~= nil then
		return cached or nil
	end

	local db = GetDB()
	local englishName
	if POTION_TYPES[itemType] then
		englishName = db.Potions[Util.ToKey(ukrainianName)]
	end

	if not englishName then
		local englishBase = db.Items[itemId]
		if type(englishBase) == "string" and englishBase ~= "" then
			englishBase = Util.StripPostfix(englishBase)
			if GLYPH_TYPES[itemType] then
				englishName = TranslateGlyphName(ukrainianName, englishBase)
			elseif GEAR_TYPES[itemType] then
				englishName = TranslateGearName(ukrainianName, englishBase)
			else
				englishName = englishBase
			end
		else
			englishName = TranslateCraftedName(ukrainianName)
		end
	end

	englishNameCache[cacheKey] = englishName or false
	DovahMova.Debug("предмет %d: '%s' -> '%s'", itemId, ukrainianName, tostring(englishName))
	return englishName
end

--- Англійська назва за посиланням на предмет.
function ItemNames.GetEnglishNameForLink(itemLink, ukrainianName)
	return ItemNames.GetEnglishName(ukrainianName, GetItemLinkItemId(itemLink), GetItemLinkItemType(itemLink))
end

--- Назва для відображення: узгоджені прикметники + англійський постфікс згідно з режимом.
function ItemNames.FormatForDisplay(ukrainianName, itemLink, mode)
	if not ukrainianName or ukrainianName == "" then
		return ukrainianName
	end
	ukrainianName = DovahMova.Adjectives.ProcessItemName(ukrainianName)
	if mode == DovahMova.MODE_UA or not itemLink or itemLink == "" then
		return ukrainianName
	end
	-- Граматичний тег (^M, ^F...) лишаємо в кінці, щоб zo_strformat продовжував його прибирати
	local name, grammarTag = string.match(ukrainianName, "^(.-)(%^[a-zA-Z]+)$")
	name = name or ukrainianName
	local englishName = ItemNames.GetEnglishNameForLink(itemLink, name)
	return Util.FormatBilingual(name, englishName, mode) .. (grammarTag or "")
end
