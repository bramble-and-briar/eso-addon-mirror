-- =================================================================================================
-- Узгодження прикметників з родом іменника.
--
-- Мовний файл містить теги:
--   ^a / ^а            — позначка прикметника, який треба узгодити;
--   ^m ^f ^n ^p        — рід іменника (чоловічий, жіночий, середній, множина).
-- Приклад: "стальний^a булава^f" -> "стальна булава".
-- =================================================================================================

local DovahMova = DovahMova
local Util = DovahMova.Util

local Adjectives = {}
DovahMova.Adjectives = Adjectives

local ENDINGS = {
	["ий"] = { f = "а", n = "е", p = "і" }, -- стальний -> стальна / стальне / стальні
	["ій"] = { f = "я", n = "є", p = "і" }, -- синій -> синя / синє / сині
}

-- Іменники, для яких мовний файл не містить тегу роду, але перед ними стоїть прикметник
local NOUN_GENDERS = {
	["намисто"] = "n",
	["кільце"] = "n",
	["озброєння"] = "n",
	["сережки"] = "p",
	["поножі"] = "p",
	["рукавиці"] = "p",
	["обладунки"] = "p",
	["сорочка"] = "f",
	["броня"] = "f",
}

--- Узгоджує прикметник з родом: ("стальний", "f") -> "стальна".
function Adjectives.Decline(adjective, gender)
	if not adjective or not gender or gender == "m" then
		return adjective
	end
	for ending, forms in pairs(ENDINGS) do
		if string.sub(adjective, -#ending) == ending then
			return string.sub(adjective, 1, -#ending - 1) .. forms[gender]
		end
	end
	return adjective
end

local function IsAdjective(word)
	local ending = string.sub(word, -4) -- два кириличні символи = 4 байти
	return ENDINGS[ending] ~= nil
end

local function RemoveTags(text)
	-- Кириличне «а» — два байти (D0 B0), тому не в класі [aа]: клас зрізав би лише "^\208",
	-- лишаючи байт \176 — невалідний UTF-8, і гра не показує рядок взагалі
	text = string.gsub(text, "%^a", "")
	text = string.gsub(text, "%^а", "")
	text = string.gsub(text, "%^[fmnp]", "")
	return text
end

--- Чи містить рядок щось, що треба узгоджувати.
function Adjectives.NeedsProcessing(text)
	return type(text) == "string"
		and (string.find(text, "^a", 1, true) ~= nil
			or string.find(text, "^а", 1, true) ~= nil
			or string.find(text, "й [^ ]+%^[fmnp]") ~= nil)
end

--- Обробляє рядок з тегами і повертає його з узгодженими прикметниками та без тегів.
function Adjectives.ProcessTaggedString(text)
	if not text or text == "" then
		return text
	end
	text = Util.RepairCyrillic(text)

	-- 1. Явно позначені прикметники: "прикметник^a іменник^g"
	local declineTagged = function(adjective, noun, gender)
		return Adjectives.Decline(adjective, gender) .. " " .. noun
	end
	local result, count = string.gsub(text, "([^ ]+)%^a +([^ ]+)%^([fmnp])", declineTagged)
	if count == 0 then
		result, count = string.gsub(text, "([^ ]+)%^а +([^ ]+)%^([fmnp])", declineTagged)
	end
	if count > 0 then
		return RemoveTags(result)
	end

	-- 2. Лише тег роду: узгоджуємо всі прикметники перед ним
	local before, gender, after = string.match(text, "^(.-)%^([fmnp])(.*)$")
	if before then
		local words = Util.SplitWords(before)
		for i, word in ipairs(words) do
			if IsAdjective(word) then
				words[i] = Adjectives.Decline(word, gender)
			end
		end
		return RemoveTags(table.concat(words, " ") .. after)
	end

	return RemoveTags(text)
end

--- Додає тег роду до назв предметів, для яких мовний файл його не містить.
function Adjectives.AddMissingGenderTag(name)
	if string.find(name, "%^[fmnp]") then
		return name
	end
	for noun, gender in pairs(NOUN_GENDERS) do
		if string.find(name, "ий " .. noun, 1, true) or string.find(name, "ій " .. noun, 1, true) then
			return name .. "^" .. gender
		end
	end
	return name
end

--- Повна обробка назви предмета.
function Adjectives.ProcessItemName(name)
	if not name or name == "" then
		return name
	end
	name = Adjectives.AddMissingGenderTag(name)
	if Adjectives.NeedsProcessing(name) then
		name = Adjectives.ProcessTaggedString(name)
	end
	return name
end

-- -------------------------------------------------------------------------------------------------
-- Глобальні хуки рядкових функцій (лише в українському клієнті)
-- -------------------------------------------------------------------------------------------------

local function ProcessArguments(...)
	local count = select("#", ...)
	local args = { ... }
	for i = 1, count do
		if Adjectives.NeedsProcessing(args[i]) then
			args[i] = Adjectives.ProcessTaggedString(args[i])
		end
	end
	return unpack(args, 1, count)
end

local installed = false

function Adjectives.InstallStringHooks()
	if installed then
		return
	end
	installed = true

	local originalGetString = GetString
	GetString = function(...)
		local text = originalGetString(...)
		if Adjectives.NeedsProcessing(text) then
			return Adjectives.ProcessTaggedString(text)
		end
		return text
	end

	local originalCachedStrFormat = ZO_CachedStrFormat
	ZO_CachedStrFormat = function(pattern, ...)
		if Adjectives.NeedsProcessing(pattern) then
			pattern = Adjectives.ProcessTaggedString(pattern)
		end
		return originalCachedStrFormat(pattern, ProcessArguments(...))
	end

	local originalLocalizeString = LocalizeString
	LocalizeString = function(formatString, ...)
		return originalLocalizeString(formatString, ProcessArguments(...))
	end

	local originalStrFormat = zo_strformat
	zo_strformat = function(formatString, ...)
		return originalStrFormat(formatString, ProcessArguments(...))
	end
end

-- -------------------------------------------------------------------------------------------------
-- Самоперевірка (/dovahmovadebug adj)
-- -------------------------------------------------------------------------------------------------

function Adjectives.RunSelfTest()
	local cases = {
		{ "стальний поножі^p", "стальні поножі" },
		{ "мідний намисто^n", "мідне намисто" },
		{ "стальний булава^f", "стальна булава" },
		{ "дубовий щит^m", "дубовий щит" },
		{ "синій море^n", "синє море" },
		{ "синій очі^p", "сині очі" },
		{ "стальний^a булава^f", "стальна булава" },
		{ "кленовий вогняний посох^n", "кленове вогняне посох" },
	}
	local passed = 0
	for _, case in ipairs(cases) do
		local result = Adjectives.ProcessTaggedString(case[1])
		if result == case[2] then
			passed = passed + 1
		else
			DovahMova.Print("✗ '%s' -> '%s' (очікувалось '%s')", case[1], result, case[2])
		end
	end
	DovahMova.Print("прикметники: %d/%d тестів пройдено", passed, #cases)
end
