-- =================================================================================================
-- DovahMova — точка входу: збережені змінні, ініціалізація модулів, події та команди.
-- Цей файл завантажується останнім, коли всі модулі вже додали себе в таблицю DovahMova.
-- =================================================================================================

local DovahMova = DovahMova
local UA, UAEN = DovahMova.MODE_UA, DovahMova.MODE_UAEN

local SAVED_VARIABLES = "DovahMovaVariables"
local SAVED_VARIABLES_VERSION = 2
local LEGACY_SAVED_VARIABLES_VERSION = 1

DovahMova.SETTINGS_DEFAULTS = {
	-- Інтерфейс
	ShowItemsDisplay = UAEN,
	ShowGuildStoreDisplay = UAEN,
	ShowLocations = UAEN,
	ShowAbilitiesMenu = UA,
	ShowChampionTooltip = UAEN,
	ShowCollectionsSetsMenu = UAEN,
	ShowScribing = UAEN,
	ShowCraft = UAEN,
	EnglishSearch = true,
	-- Спливаючі вікна
	ShowAbilitiesTooltip = UAEN,
	ShowItemsNamesTooltip = UAEN,
	ShowItemsEnchantsTooltip = UAEN,
	ShowItemsTraitsTooltip = UAEN,
	ShowItemsSetsTooltip = UAEN,
	-- Пошта
	AutoCollectHirelingMail = true,
	AutoDeleteHirelingMail = true,
	-- Службові
	IsUpdateNeeded = true,      -- показувати діалог оновлення мовної бази
	SubtitlesConfigured = false, -- субтитри вже увімкнено при першому запуску
	migrated = false,           -- налаштування перенесено зі старої версії
}

-- -------------------------------------------------------------------------------------------------
-- Збережені змінні
--
--   DovahMovaVariables[<сервер>][@акаунт]["$AccountWide"]["Settings"] — налаштування (окремо для NA/EU/PTS)
--   DovahMovaVariables["Default"][@акаунт]["$AccountWide"]["Database"] — мовна база (спільна)
--   DovahMovaVariables["Default"][@акаунт]["$AccountWide"]["TTC"]      — таблиця TTC (integration/TamrielTradeCentreUA)
--
-- До версії 1.5.0 усе зберігалося прямо в DovahMovaVariables["Default"][@акаунт]["$AccountWide"].
-- -------------------------------------------------------------------------------------------------

local function GetSharedAccountTable()
	local profile = DovahMovaVariables and DovahMovaVariables.Default
	local account = profile and profile[GetDisplayName()]
	return account and account["$AccountWide"], account
end

--- Прибирає дані старого формату, зберігаючи знімок налаштувань для перенесення на кожен сервер.
local function MigrateLegacySavedVariables()
	local shared, account = GetSharedAccountTable()
	if not shared or shared.version ~= LEGACY_SAVED_VARIABLES_VERSION then
		return
	end

	local snapshot = {}
	for key in pairs(DovahMova.SETTINGS_DEFAULTS) do
		snapshot[key] = shared[key]
	end
	for key in pairs(shared) do
		if key ~= "Database" and key ~= "Settings" and key ~= "TTC" then
			shared[key] = nil
		end
	end
	if next(snapshot) then
		shared.legacySettings = snapshot
	end

	-- Старі посимвольні налаштування (лише прапорець першого запуску) більше не потрібні
	for key, value in pairs(account) do
		if key ~= "$AccountWide" and type(value) == "table" and value.IsFirstLaunch ~= nil then
			account[key] = nil
		end
	end
end

local function ApplyLegacySettings(settings)
	if settings.migrated then
		return
	end
	settings.migrated = true
	local shared = GetSharedAccountTable()
	local snapshot = shared and shared.legacySettings
	if not snapshot then
		return
	end
	for key, value in pairs(snapshot) do
		settings[key] = value
	end
	settings.SubtitlesConfigured = true
end

local function InitializeSavedVariables()
	MigrateLegacySavedVariables()
	DovahMova.db = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES, SAVED_VARIABLES_VERSION, "Database", DovahMova.Database.DEFAULTS)
	DovahMova.settings = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES, SAVED_VARIABLES_VERSION, "Settings", DovahMova.SETTINGS_DEFAULTS, GetWorldName())
	ApplyLegacySettings(DovahMova.settings)
end

-- -------------------------------------------------------------------------------------------------
-- Модулі
-- -------------------------------------------------------------------------------------------------

local function InstallUkrainianModules()
	DovahMova.Adjectives.InstallStringHooks()
	DovahMova.ItemsDisplay.Install()

	-- Двомовні назви потребують актуальної мовної бази
	if not DovahMova.Database.IsOutdated() then
		DovahMova.ItemTooltips.Install()
		DovahMova.Abilities.Install()
		DovahMova.Champion.Install()
		DovahMova.Craft.Install()
		DovahMova.Scribing.Install()
		DovahMova.Collections.Install()
		DovahMova.Dungeons.Install()
	end

	DovahMova.ApplyIntegrations()
end

local function EnableSubtitlesOnce()
	local settings = DovahMova.settings
	if not settings.SubtitlesConfigured then
		SetSetting(SETTING_TYPE_SUBTITLES, SUBTITLE_SETTING_ENABLED_FOR_NPCS, "true")
		SetSetting(SETTING_TYPE_SUBTITLES, SUBTITLE_SETTING_ENABLED_FOR_VIDEOS, "true")
		settings.SubtitlesConfigured = true
	end
end

-- -------------------------------------------------------------------------------------------------
-- Діалог оновлення мовної бази
-- -------------------------------------------------------------------------------------------------

local UPDATE_DIALOG = "DovahMovaUpdateDatabase"

local function RegisterUpdateDialog()
	ZO_Dialogs_RegisterCustomDialog(UPDATE_DIALOG, {
		canQueue = true,
		onlyQueueOnce = true,
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
		title = { text = "Потрібно оновити мовну базу" },
		mainText = {
			text = "Гра розпочне змінювати мови (текст на екрані переключатиметься з української на англійську). "
				.. "Це звичайний процес. Не закривай гру. Тривалість може становити від кількох секунд до 10 хвилин, "
				.. "залежно від продуктивності твого комп'ютера.",
		},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = "Оновити мовну базу",
				callback = function() DovahMova.Database.StartRebuild() end,
				clickSound = SOUNDS.DIALOG_ACCEPT,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = "Скасувати",
				callback = function() DovahMova.settings.IsUpdateNeeded = false end,
				clickSound = SOUNDS.DIALOG_DECLINE,
			},
		},
	})
end

-- -------------------------------------------------------------------------------------------------
-- Команди для відлагодження: /dovahmovadebug <команда>
-- -------------------------------------------------------------------------------------------------

local function PrintIntegrationStatus()
	DovahMova.Print("інтеграції:")
	for _, integration in ipairs(DovahMova.integrations) do
		d(string.format("  %s — %s", integration.name, integration.status))
	end
end

local function PrintItemInfo(argument)
	local itemId = tonumber(argument)
	if not itemId then
		DovahMova.Print("використання: /dovahmovadebug item <itemId>")
		return
	end
	local itemLink = DovahMova.Util.ItemLink(itemId)
	local ukrainianName = DovahMova.ItemNames.GetRawItemLinkName(itemLink)
	DovahMova.Print("предмет %d: '%s' -> '%s' (у базі: '%s')", itemId, ukrainianName,
		tostring(DovahMova.ItemNames.GetEnglishNameForLink(itemLink, ukrainianName)),
		tostring(DovahMova.db.Items[itemId]))
end

local DEBUG_COMMANDS = {
	status = PrintIntegrationStatus,
	adj = function(text)
		if text ~= "" then
			DovahMova.Print("'%s' -> '%s'", text, DovahMova.Adjectives.ProcessTaggedString(text))
		else
			DovahMova.Adjectives.RunSelfTest()
		end
	end,
	item = PrintItemInfo,
	mail = function() DovahMova.MailHandler.CollectAttachments() end,
	debug = function()
		DovahMova.debugEnabled = not DovahMova.debugEnabled
		DovahMova.Print("детальний вивід %s", DovahMova.debugEnabled and "увімкнено" or "вимкнено")
	end,
}

local function OnDebugCommand(arguments)
	local command, rest = string.match(arguments or "", "^(%S*) *(.-)$")
	local handler = DEBUG_COMMANDS[command]
	if handler then
		handler(rest)
	else
		DovahMova.Print("команди: status, adj [текст], item <itemId>, mail, debug")
	end
end

-- -------------------------------------------------------------------------------------------------
-- Події
-- -------------------------------------------------------------------------------------------------

local function OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(DovahMova.name, EVENT_PLAYER_ACTIVATED)

	DovahMova.Database.ResumePendingStep()

	if DovahMova.IsUkrainian() and DovahMova.settings.IsUpdateNeeded and DovahMova.Database.IsOutdated() then
		ZO_Dialogs_ShowDialog(UPDATE_DIALOG)
	end
end

local function OnAddOnLoaded(_, addonName)
	if addonName ~= DovahMova.name then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(DovahMova.name, EVENT_ADD_ON_LOADED)

	InitializeSavedVariables()
	EnableSubtitlesOnce()
	DovahMova.SettingsMenu.Initialize()
	DovahMova.MailHandler.Initialize()
	RegisterUpdateDialog()

	if DovahMova.IsUkrainian() then
		InstallUkrainianModules()
	end

	EVENT_MANAGER:RegisterForEvent(DovahMova.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	SLASH_COMMANDS["/dovahmovadebug"] = OnDebugCommand
end

EVENT_MANAGER:RegisterForEvent(DovahMova.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
