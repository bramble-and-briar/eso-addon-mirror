-- =================================================================================================
-- Панель налаштувань (LibAddonMenu-2.0).
-- =================================================================================================

local DovahMova = DovahMova

local SettingsMenu = {}
DovahMova.SettingsMenu = SettingsMenu

local UA, UAEN, EN = DovahMova.MODE_UA, DovahMova.MODE_UAEN, DovahMova.MODE_EN
local RELOAD_WARNING = "|cffcc00Увага:|r Зміна цього налаштування призведе до перезавантаження інтерфейсу."

local function ReloadInterface()
	ReloadUI("ingame")
end

local function IsDatabaseOutdated()
	return DovahMova.Database.IsOutdated()
end

local function DatabaseWarning()
	return IsDatabaseOutdated() and "Необхідно оновити мовну базу." or nil
end

--- Випадаючий список режиму відображення назв.
-- @param onChange  function(newValue) — застосувати зміну (необов'язково)
local function ModeDropdown(name, tooltip, settingKey, modes, onChange)
	local choices = {}
	for i, mode in ipairs(modes) do
		choices[i] = DovahMova.MODE_LABELS[mode]
	end
	return {
		type = "dropdown",
		name = name,
		tooltip = tooltip,
		choices = choices,
		choicesValues = modes,
		warning = DatabaseWarning,
		disabled = IsDatabaseOutdated,
		getFunc = function() return DovahMova.settings[settingKey] end,
		setFunc = function(value)
			DovahMova.settings[settingKey] = value
			if onChange then
				onChange(value)
			end
		end,
		width = "full",
	}
end

local function Checkbox(name, tooltip, settingKey, extra)
	local option = {
		type = "checkbox",
		name = name,
		tooltip = tooltip,
		getFunc = function() return DovahMova.settings[settingKey] end,
		setFunc = function(value) DovahMova.settings[settingKey] = value end,
		width = "full",
	}
	for key, value in pairs(extra or {}) do
		option[key] = value
	end
	return option
end

local function Header(name)
	return { type = "header", name = name, width = "full" }
end

local function Label(text)
	return { type = "description", text = text, width = "full" }
end

local function GenerateTTCTable()
	local ttcPrices = DovahMova.TTCPrices
	if not ttcPrices or not ttcPrices.IsAvailable() then
		DovahMova.Print("Tamriel Trade Centre не завантажено або не пропатчено скриптом ttc_ua_setup (див. README).")
		return
	end
	DovahMova.Print("генерую українську таблицю цін TTC...")
	DovahMova.Print("таблицю TTC згенеровано: %d назв.", ttcPrices.Generate())
end

local function BuildOptions()
	local modules = DovahMova
	return {
		Header("Загальні"),
		Label(RELOAD_WARNING),
		{
			type = "checkbox",
			name = "Увімкнути українську мову",
			tooltip = "Негайно вмикає/вимикає українську мову та перезавантажує UI.",
			getFunc = DovahMova.IsUkrainian,
			setFunc = function(enabled) DovahMova.SetClientLanguage(enabled and "ua" or "en") end,
			width = "full",
		},
		{
			type = "button",
			name = "Оновити мовну базу",
			tooltip = "Виконує індексацію мовного файлу після оновлення гри чи аддона.",
			func = function() DovahMova.Database.StartRebuild() end,
			width = "full",
		},
		{ type = "divider", width = "full" },
		Checkbox("Автозбір листів від найманців",
			"Автоматично збирати матеріали з листів від найманців при відкритті поштової скриньки.",
			"AutoCollectHirelingMail"),
		Checkbox("Видаляти листи після збору",
			"Автоматично видаляти листи від найманців після збору матеріалів.",
			"AutoDeleteHirelingMail",
			{ disabled = function() return not DovahMova.settings.AutoCollectHirelingMail end }),
		Label("|cffcc00Увага:|r Генеруйте таблицю TTC щоразу, коли змінюєте «Предмети в інвентарі»."),
		{
			type = "button",
			name = "Згенерувати TTC",
			tooltip = "Створює українську таблицю пошуку для Tamriel Trade Centre, щоб ціни відображалися для українських назв предметів. Потрібно виконати після запуску скрипту інтеграції.",
			func = GenerateTTCTable,
			width = "full",
		},
		Checkbox("Двомовний пошук сетів в меню колекцій",
			"Дозволяє використовувати англійські назви сетів під час пошуку в меню колекцій.",
			"EnglishSearch",
			{ warning = DatabaseWarning, disabled = IsDatabaseOutdated }),

		Header("Інтерфейс"),
		ModeDropdown("Предмети в інвентарі (reloadui)",
			"Мова назв предметів в інвентарі, банку та у торговців. " .. RELOAD_WARNING,
			"ShowItemsDisplay", { UA, UAEN }, ReloadInterface),
		ModeDropdown("Гільдійський магазин (reloadui)",
			"Мова назв предметів у гільдійському магазині. Працює з Awesome Guild Store. " .. RELOAD_WARNING,
			"ShowGuildStoreDisplay", { UA, UAEN }, ReloadInterface),
		ModeDropdown("Назви підземель (reloadui)",
			"Мова назв підземель. " .. RELOAD_WARNING,
			"ShowLocations", { UA, UAEN }, ReloadInterface),
		ModeDropdown("Здібності",
			"Мова назв умінь у вікні навичок.",
			"ShowAbilitiesMenu", { UA, EN }, function() modules.Abilities.Refresh() end),
		ModeDropdown("Система ЧП",
			"Мова назв умінь у розділі ЧП.",
			"ShowChampionTooltip", { UA, UAEN }),
		ModeDropdown("Сети обладунків",
			"Мова назв сетів обладунків у меню колекцій.",
			"ShowCollectionsSetsMenu", { UA, UAEN }, function() modules.Collections.Refresh() end),
		ModeDropdown("Скрипти скрайбінгу",
			"Мова назв скриптів скрайбінгу в меню скрайбінгу.",
			"ShowScribing", { UA, UAEN }),
		ModeDropdown("Назви комплектів у ремісничих верстатах",
			"Мова назв комплектів при наведенні на ремісничі верстати.",
			"ShowCraft", { UA, UAEN }),
		ModeDropdown("Трейти",
			"Мова назв трейтів у спливаючих вікнах.",
			"ShowItemsTraitsTooltip", { UA, UAEN }),

		Header("Спливаючі вікна"),
		ModeDropdown("Уміння",
			"Мова назв умінь у спливаючих вікнах.",
			"ShowAbilitiesTooltip", { UA, UAEN }),
		ModeDropdown("Предмети",
			"Мова назв предметів у спливаючих вікнах.",
			"ShowItemsNamesTooltip", { UA, UAEN }),
		ModeDropdown("Зачарування",
			"Мова назв зачарувань у спливаючих вікнах.",
			"ShowItemsEnchantsTooltip", { UA, UAEN }),
		ModeDropdown("Сети обладунків",
			"Мова назв комплектів у спливаючих вікнах.",
			"ShowItemsSetsTooltip", { UA, UAEN }),
	}
end

function SettingsMenu.Initialize()
	local LAM = LibAddonMenu2
	local panelName = DovahMova.name .. "Settings"
	LAM:RegisterAddonPanel(panelName, {
		type = "panel",
		name = DovahMova.name,
		displayName = "|cffdd00Dovah|r|c0057b8Mova|r",
		author = DovahMova.author,
		version = DovahMova.version,
		slashCommand = "/dovahmova",
		registerForRefresh = true,
		registerForDefaults = true,
	})
	LAM:RegisterOptionControls(panelName, BuildOptions())
end
