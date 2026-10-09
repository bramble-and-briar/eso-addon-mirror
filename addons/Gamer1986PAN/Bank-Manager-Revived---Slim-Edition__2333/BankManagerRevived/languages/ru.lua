--[[
File : ru.lua
Version : 4.5
Author : Ayantir
Translator: Scope

]]--

--Option Translation

SafeAddString(BMR_AUTO_TRANSFERT								, "Автом. перемещение при открытии банка", 1)
SafeAddString(BMR_AUTO_TRANSFERT_TOOLTIP					, "При открытии банка будут запущены все операции по перемещению", 1)

SafeAddString(BMR_STACK_DETAILLED							, "Показывать подробности перемещения", 1)
SafeAddString(BMR_STACK_DETAILLED_TOOLTIP					, "Показывать в чате подробности по каждому перемещенному предмету", 1)

SafeAddString(BMR_DISPLAY_SUMMARY							, "Показывать суммарную информацию", 1)
SafeAddString(BMR_DISPLAY_SUMMARY_TOOLTIP					, "Показывать итоговую информацию по количеству перемещенных вещей и валюты", 1)

SafeAddString(BMR_STACK_DETAILLED_NOTMOVED				, "Показывать неудачные перемещения", 1)
SafeAddString(BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP		, "Показывать сообщения когда BMR не смог переместить предметы при нехватке места", 1)

SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS				, "Не перемещать защищенные предметы", 1)
SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP	, "Не перемещать предметы отмеченные ItemSaver или FCO ItemSaver", 1)
SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS_EXT			, " - Опция отключена, дополнения не найдены", 1)

SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS					, "Оставить уже перемещенные предметы", 1)
SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP			, "Оставить предметы уже перемещенные в банк самостоятельно или другими дополнениями", 1)

SafeAddString(BMR_WAIT_AT_STARTUP							, "Ожидание перед началом перемещения", 1)
SafeAddString(BMR_WAIT_AT_STARTUP_TOOLTIP					, "Уменьшите значение если не хотите ждать. Низкие значения могут вызвать ошибки BMR если ваш компьютер недостаточно быстрый, особенно при перемещении в гильдейском банке", 1)

SafeAddString(BMR_NO_OVERFILL									, "Оставлять свободное место в сумке", 1)
SafeAddString(BMR_NO_OVERFILL_TOOLTIP						, "Если задано, BMR попытается оставить данное количество свободного места в вашей сумке и не будет перемещать дополнительные предметы пока лимит достигнут", 1)

SafeAddString(BMR_DELAY_BETWEEN_MOVES						, "Задержка между каждым перемещением", 1)
SafeAddString(BMR_DELAY_BETWEEN_MOVES_TOOLTIP			, "Добавить задержку перед перемещением каждого предмета для предотвращения возможных вылетов или блокирования игрой", 1)

SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK					, "Только если стек не заполнен", 1)
SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP		, "Перемещать предметы только если в принимаемой сумке еще нет полностью заполненного стека", 1)

SafeAddString(BMR_MAX_STACK									, "Макс. стеков", 1)
SafeAddString(BMR_MAX_STACK_TOOLTIP							, "Максимум стеков предметов для перемещения в нужную сумку", 1)

SafeAddString(BMR_GUILD_LIST									, "Выбрать гильдейский банк", 1)
SafeAddString(BMR_GUILD_LIST_TOOLTIP						, "Название гильдейского банка в который BMR будет перемещать предметы по заданным ниже условиям.", 1)

-- Profiles
SafeAddString(BMR_PROFILES										, "Профили", 1)
SafeAddString(BMR_PROFILE_LIST								, "Выбранный профиль", 1)
SafeAddString(BMR_PROFILE_LIST_TOOLTIP						, "Для каждого персонажа вы можете задать до 9 разных профилей со своими правилами", 1)
SafeAddString(BMR_PROFILE_NAME								, "Имя профиля", 1)
SafeAddString(BMR_PROFILE_NAME_TOOLTIP						, "Имя выбранного профиля", 1)
SafeAddString(BMR_PROFILE_RESET								, "Сбросить профиль", 1)
SafeAddString(BMR_PROFILE_RESET_TOOLTIP					, "Сбросить этот профиль на значения по умолчанию", 1)

SafeAddString(BMR_PROFILE 										, "Профиль <<1>>", 1)
	
-- Currencies
SafeAddString(BMR_CURRENCY_PUSH								, "Оставлять сумму", 1)
SafeAddString(BMR_CURRENCY_PUSH_TOOLTIP					, "Оставлять эту сумму в вашем инвентаре.\n\n Если вы выбрали значение для 'Забирать до', оно будет использовано как минимальное для этой опции.", 1)
		
SafeAddString(BMR_CURRENCY_PULL								, "Забирать до", 1)
SafeAddString(BMR_CURRENCY_PULL_TOOLTIP					, "Забирать валюту из банка в ваш инвентарь до указанного значения. Поставьте 0 для отключения этой опции.", 1)

SafeAddString(BMR_CURRENCY_NOTHING							, "Не оставлять <<1>>", 1)
SafeAddString(BMR_CURRENCY_NOTHING_TOOLTIP				, "Когда \"Оставлять сумму\" установлено в 0, включение этой опции подтверждает перемещение всех ваших <<1>> в банк", 1)

SafeAddString(BMR_CURRENCY_KEEP_IN_BANK					, "Оставлять в банке вместо сумки", 1)
SafeAddString(BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP			, "Оставлять заданную сумму в банке вместо сумки и также пополнять банк если задана опция \"Забирать до\"", 1)

-- Crafting Types as their ID are language dependant
SafeAddString(BMR_TRADESKILL_ALCHEMY						, "Алхимия", 1)
SafeAddString(BMR_TRADESKILL_CLOTHIER						, "Портняжное дело", 1)
SafeAddString(BMR_TRADESKILL_PROVISIONING					, "Снабжение", 1)
SafeAddString(BMR_TRADESKILL_ENCHANTING						, "Зачарование", 1)
SafeAddString(BMR_TRADESKILL_BLACKSMITHING					, "Кузнечное дело", 1)
SafeAddString(BMR_TRADESKILL_WOODWORKING					, "Столярное дело", 1)
SafeAddString(BMR_TRADESKILL_JEWELRYCRAFTING				, "Ювелирное дело", 1)

-- Trophies are hardcoded because there is nothing to label them
SafeAddString(BMR_TROPHY_TREASURE_MAP						, "Карты сокровищ", 1)
SafeAddString(BMR_TROPHY_SURVEY_MAP							, "Карты исследований", 1)
SafeAddString(BMR_TROPHY_MOTIF_FRAGMENT					, "Фрагменты мотивов стиля", 1)
SafeAddString(BMR_TROPHY_RECIPE_FRAGMENT					, "Фрагменты рецептов", 1)
SafeAddString(BMR_TROPHY_IMPERIALCITY_PVE					, "награды Имперского города", 1)
SafeAddString(BMR_TROPHY_QUEST_REWARD						, "Награды за задания", 1)

-- Writ quests
SafeAddString(BMR_WRIT_QUESTS									, "Забирать материалы для заказов", 1)
SafeAddString(BMR_WRIT_QUESTS_TOOLTIP						, "Забирать в сумку материалы требуемые для выполнения ежедневных ремесленных заданий", 1)

-- Bindings
SafeAddString(SI_BINDING_NAME_BMR_PROFILE1				, "Запустить профиль 1", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE2				, "Запустить профиль 2", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE3				, "Запустить профиль 3", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE4				, "Запустить профиль 4", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE5				, "Запустить профиль 5", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE6				, "Запустить профиль 6", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE7				, "Запустить профиль 7", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE8				, "Запустить профиль 8", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE9				, "Запустить профиль 9", 1)

-- Dropwdons
SafeAddString(BMR_ACTION_PUSH									, "Положить в банк", 1)
SafeAddString(BMR_ACTION_PULL									, "Взять из банка", 1)
SafeAddString(BMR_ACTION_NOTSET								, "-", 1)	
SafeAddString(BMR_ACTION_PUSH_GBANK							, "Положить в гильдейский банк", 1)
SafeAddString(BMR_ACTION_PUSH_BOTH							, "Складывать в оба банка", 1)

-- Chat notifications
SafeAddString(BMR_ACTION_ITEMS_MOVED						, "BMR переместил <<3>>x |t16:16:<<2>>|t<<1>> <<4>>", 1)
SafeAddString(BMR_ACTION_ITEMS_NOT_MOVED					, "BMR не переместил <<3>>x |t16:16:<<2>>|t<<1>> <<4>>", 1)
SafeAddString(BMR_ACTION_CURRENCY_SUMMARY					, "BMR переместил <<1>> <<2>>", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO1					, "в сумку", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO2					, "в банк", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO6					, "в банк", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO3					, "в гильдейский банк <<5>>", 1)

SafeAddString(BMR_ACTION_ITEMS_SUMMARY						, "BMR переместил <<1>>x различных предметов (<<2>> шт.) ", 1)
SafeAddString(BMR_RARE_INGREDIENTS							, "<<1>>, <<2>> и <<3>>", 1)

-- Import
SafeAddString(BMR_IMPORT										, "Импортировать настройки BMR с персонажа", 1)
SafeAddString(BMR_IMPORT_DESC									, "Выбрать с какого персонажа BMR должен импортировать настройки. Обратите внимание, что эти настройки останутся только на этом персонаже и не синхронизируются между остальными", 1)
SafeAddString(BMR_IMPORTED										, "Настройки BMR были импортированы с персонажа <<1>>", 1)

SafeAddString(BMR_ZOS_LIMITATIONS							, "Учитывая ограничения игры, за один раз BMR обрабатывает только 98 предметов. Пожалуйста, подождите 10 секунд и повторите действие еще раз.", 1)
-- Новые параметры / ScriptTracker
SafeAddString(BMR_GLOBAL_ADDON_PROFILE			, "Глобальный профиль аддона (перезагрузка после выбора)", 1)
SafeAddString(BMR_GLOBAL_ADDON_PROFILE_TOOLTIP	, "Выберите глобальный профиль BMR. Интерфейс будет перезагружен после изменения. По умолчанию: <<1>>", 1)
SafeAddString(BMR_PROFILE_COUNT					, "Количество профилей", 1)
SafeAddString(BMR_PROFILE_COUNT_TOOLTIP			, "Определяет количество доступных профилей BMR. Профили выше этого числа сохраняются, но скрываются до увеличения значения.", 1)

SafeAddString(BMR_SCRIPTTRACKER						, "ScriptTracker / Скриптуры", 1)
SafeAddString(BMR_SCRIPTTRACKER_DESC					, "Автоматически помещает в банк скриптуры, уже известные текущему персонажу, и извлекает из банка скриптуры, которые персонаж ещё не знает. Перемещение выполняет BMR.", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE				, "Включить автоматическое управление скриптурами", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE_TOOLTIP	, "При открытии банка использует данные ScriptTracker о знаниях текущего персонажа.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEPOSIT_KNOWN	, "Помещать известные скриптуры в банк", 1)
SafeAddString(BMR_SCRIPTTRACKER_WITHDRAW_UNKNOWN, "Извлекать неизвестные скриптуры из банка", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY			, "Извлекать только один экземпляр каждой неизвестной скриптуры", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY_TOOLTIP, "Если включено, BMR извлекает из банка не более одного экземпляра каждой неизвестной скриптуры. Если скриптура уже есть в инвентаре, дополнительный экземпляр не извлекается.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG				, "Включить отладочные сообщения ScriptTracker", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG_TOOLTIP	, "Выводит подробную диагностическую информацию ScriptTracker/BMR в чат. По умолчанию отключено.", 1)

