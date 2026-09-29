-- =================================================================================================
-- DovahMova — ядро адона.
-- Цей файл завантажується ПЕРШИМ (див. DovahMova.txt) і створює єдину глобальну таблицю DovahMova.
-- Усі інші файли адона додають свої функції та дані лише в цю таблицю.
-- =================================================================================================

DovahMova = DovahMova or {}
local DovahMova = DovahMova

DovahMova.name = "DovahMova"
DovahMova.version = "1.5.0"
DovahMova.author = "Frozenshtoldts and DovahMova Team"

-- Режими відображення назв (значення зберігаються в налаштуваннях)
DovahMova.MODE_UA = "ua"     -- лише українська назва
DovahMova.MODE_UAEN = "uaen" -- «українська (English)»
DovahMova.MODE_EN = "en"     -- лише англійська назва

DovahMova.MODE_LABELS = {
	ua = "Українська",
	uaen = "Українська+Англійська",
	en = "Англійська",
}

-- Простори імен, які заповнюють інші файли
DovahMova.Util = DovahMova.Util or {}
DovahMova.StaticData = DovahMova.StaticData or {}         -- дані, що поставляються з адоном (engPostfix/data)
DovahMova.IntegrationStrings = DovahMova.IntegrationStrings or {} -- переклади для чужих адонів (integration/*)
DovahMova.integrations = DovahMova.integrations or {}

-- true, поки будується мовна база: хуки мають повертати оригінальні значення без постфіксів
DovahMova.isBuildingDatabase = false
-- Детальний вивід у чат для відлагодження (/dovahmovadebug debug)
DovahMova.debugEnabled = false

local Util = DovahMova.Util

-- -------------------------------------------------------------------------------------------------
-- Мова клієнта
-- -------------------------------------------------------------------------------------------------

function DovahMova.GetClientLanguage()
	return GetCVar("language.2")
end

function DovahMova.IsUkrainian()
	return GetCVar("language.2") == "ua"
end

function DovahMova.SetClientLanguage(lang)
	if GetCVar("language.2") == lang then
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Ви вже переключені на цю мову.")
		return
	end
	SetCVar("language.2", lang) -- гра одразу перезавантажує інтерфейс
end

-- -------------------------------------------------------------------------------------------------
-- Вивід у чат
-- -------------------------------------------------------------------------------------------------

function DovahMova.Print(fmt, ...)
	d("|cffdd00Dovah|r|c0057b8Mova|r: " .. string.format(fmt, ...))
end

function DovahMova.Debug(fmt, ...)
	if DovahMova.debugEnabled then
		d("|c888888[DovahMova]|r " .. string.format(fmt, ...))
	end
end

-- -------------------------------------------------------------------------------------------------
-- Рядкові утиліти.
-- Увага: у клієнті ESO клас %s у Lua-патернах збігається з байтом 0xA0, який є частиною
-- кириличної літери «Р» (D0 A0). Тому для українського тексту слова завжди розділяємо
-- явним пробілом " ", а не %s/%S.
-- -------------------------------------------------------------------------------------------------

--- Екранує спецсимволи Lua-патернів.
function Util.EscapePattern(text)
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

--- Замінює всі входження підрядка (без патернів).
function Util.PlainReplace(text, what, with)
	if not text or not what or what == "" then
		return text
	end
	return (zo_strgsub(text, Util.EscapePattern(what), (string.gsub(with, "%%", "%%%%"))))
end

--- Розбиває текст на слова за пробілами.
function Util.SplitWords(text)
	local words = {}
	for word in string.gmatch(text, "[^ ]+") do
		words[#words + 1] = word
	end
	return words
end

function Util.CountWords(text)
	local count = 0
	for _ in string.gmatch(text, "[^ ]+") do
		count = count + 1
	end
	return count
end

--- Повертає частину назви до англійського постфікса: "назва (Name)" -> "назва".
function Util.StripPostfix(name)
	local pos = string.find(name, " (", 1, true)
	if pos then
		return string.sub(name, 1, pos - 1)
	end
	return name
end

--- Чи закінчується назва постфіксом у дужках.
function Util.HasPostfix(name)
	return string.find(name, " %(.*%)$") ~= nil
end

--- Нижній регістр + прибирання граматичних тегів (^m, ^f, ...). Ключ для пошуку в мовній базі.
function Util.ToKey(text)
	return ZO_CachedStrFormat("<<z:1>>", text)
end

--- Прибирає граматичні теги ESO (^m, ^F, ^n, ^p, ^a, кириличний ^а ...).
-- Класи на кшталт %a тут не підходять: вони можуть зачепити байти кирилиці.
function Util.StripGrammarTags(text)
	text = string.gsub(text, "%^[a-zA-Z]+", "")
	text = string.gsub(text, "%^а", "")
	return text
end

--- Виправляє кириличну «Р», розбиту клієнтом на окремий байт/символ-замінник і пробіл.
function Util.RepairCyrillic(text)
	text = string.gsub(text, "\208 ", "\208\160")       -- "\xD0 " -> "Р"
	text = string.gsub(text, "\239\191\189 ", "\209\128") -- "� " -> "р"
	return text
end

--- Формує назву відповідно до режиму відображення.
-- @param uaName  українська назва
-- @param enName  англійська назва (може бути nil)
-- @param mode    DovahMova.MODE_*
function Util.FormatBilingual(uaName, enName, mode)
	if not enName or enName == "" or mode == DovahMova.MODE_UA then
		return uaName
	end
	if mode == DovahMova.MODE_EN then
		return enName
	end
	if Util.HasPostfix(uaName) then
		return uaName
	end
	return string.format("%s (%s)", uaName, enName)
end

local ITEM_LINK_FIELD_COUNT = 21

--- Будує посилання на предмет. spec — itemId або рядок "itemId:поле2:поле3...";
-- решта полів доповнюється нулями.
function Util.ItemLink(spec)
	spec = tostring(spec)
	local _, separators = string.gsub(spec, ":", "")
	return "|H1:item:" .. spec .. string.rep(":0", ITEM_LINK_FIELD_COUNT - separators - 1) .. "|h|h"
end

-- -------------------------------------------------------------------------------------------------
-- Інтеграції з чужими адонами
--
-- Порядок завантаження ESO: спершу виконуються файли ВСІХ адонів (цільові адони з OptionalDependsOn —
-- раніше за DovahMova), і лише потім по черзі надсилається EVENT_ADD_ON_LOADED кожному адону
-- (знову ж таки цільовим адонам — раніше).
--
-- Опис інтеграції (integration/*/integration.lua викликає DovahMova.RegisterIntegration):
--   name        — назва для статусу
--   IsAvailable — function(): чи завантажений цільовий адон
--   Prepare     — function(integration), необов'язково: виконується одразу під час завантаження файлів,
--                 тобто ДО ініціалізації цільового адона. Лише зміна даних (рядки, таблиці перекладів),
--                 без реєстрації подій.
--   Apply       — function(integration), необов'язково: виконується з EVENT_ADD_ON_LOADED DovahMova,
--                 ПІСЛЯ ініціалізації цільового адона (оновлення вже збудованих ним структур, події).
-- -------------------------------------------------------------------------------------------------

function DovahMova.RegisterIntegration(integration)
	assert(integration.name and integration.IsAvailable and (integration.Prepare or integration.Apply),
		"DovahMova: неповний опис інтеграції")
	integration.status = "не застосовано"
	DovahMova.integrations[#DovahMova.integrations + 1] = integration

	if integration.Prepare and DovahMova.IsUkrainian() and integration.IsAvailable() then
		local ok, err = pcall(integration.Prepare, integration)
		if not ok then
			integration.prepareError = tostring(err)
		end
	end
end

function DovahMova.ApplyIntegrations()
	for _, integration in ipairs(DovahMova.integrations) do
		if not integration.IsAvailable() then
			integration.status = "адон не завантажено"
		else
			local ok, err = not integration.prepareError, integration.prepareError
			if ok and integration.Apply then
				ok, err = pcall(integration.Apply, integration)
			end
			if ok then
				integration.status = "активна"
			else
				integration.status = "помилка: " .. tostring(err)
				DovahMova.Print("помилка інтеграції %s: %s", integration.name, tostring(err))
			end
		end
	end
end

--- Застосовує таблицю перекладів вигляду { STRING_ID_NAME = "текст" } через ZO_CreateStringId.
-- version — як у мовних файлах цільового адона (SafeAddVersion), якщо вони його використовують.
function Util.CreateStringIds(strings, version)
	for stringIdName, text in pairs(strings) do
		ZO_CreateStringId(stringIdName, text)
		if version then
			SafeAddVersion(stringIdName, version)
		end
	end
end

--- Застосовує таблицю { STRING_ID_NAME = "текст" } до вже існуючих рядків через SafeAddString.
function Util.OverrideStrings(strings, version)
	for stringIdName, text in pairs(strings) do
		local stringId = _G[stringIdName]
		if stringId then
			SafeAddString(stringId, text, version or 1)
		end
	end
end
