РАСКРЫТИЕ ИСПОЛЬЗОВАНИЯ ИИ
При разработке Ramaladni частично применялся ИИ: отдельные части Lua-кода, исследование API, рефакторинг и автоматизированные тесты. Автор также самостоятельно вносил изменения в код и тестировал аддон в игре. Автономные тесты с эмуляцией API не заменяют полную проверку в ESO.

RAMALADNI — CLASS MASTERY & BUFF/DEBUFF TRACKER
Версия: 1.0.1-Stable
Автор: Northknightwest (Ramaladni)
Внешние библиотеки не требуются. Платформа: ESO (ПК).

ВОЗМОЖНОСТИ
- Автоматическое определение изученных мастерств текущей допустимой сборки: 35 пассивок семи классов. При смене сборки набор иконок обновляется автоматически.
- Новые иконки мастерств появляются возле центра экрана; перемещённые позиции запоминаются отдельно для каждой пассивки. Мастерства не занимают 12 обычных слотов эффектов.
- Раздельный поиск: 41 бафф и 33 дебаффа, статусных и специальных эффекта (74 именованных эффекта). Поиск по RU/EN названию, части названия или известному ID. Нажатие на результат добавляет индикатор.
- Связанные ID объединяются в один индикатор. Автоматические игровые иконки, перемещаемые HUD-индикаторы, таймеры и значения мастерств. Некоторые механики рассчитываются по наблюдаемым событиям.
- Индикаторы скрываются в основных игровых меню и возвращаются в игровом интерфейсе.
- Раздельные настройки EU, NA и PTS. Существующие серверные профили имеют приоритет, старые общие настройки импортируются один раз только при отсутствии настроек отдельного сервера.

УСТАНОВКА
1. Закройте ESO. Сделайте резервную копию старой папки аддона и Documents/Elder Scrolls Online/live/SavedVariables/RamaladniTrackerSaved.lua.
2. Распакуйте папку Ramaladni_buff_debuff_tracker в Documents/Elder Scrolls Online/live/AddOns/. Оставьте только одну копию аддона.
3. Запустите игру и введите /ramaladni. Горячие клавиши: Settings > Controls > Keybindings > Ramaladni.
4. Перемещайте иконки ЛКМ. Удаляйте обычные индикаторы через X или «Удалить баффы/дебаффы». Мастерства следуют текущей сборке.

КОМАНДЫ
/ramaladni — настройки
/ramaladni debug — диагностика
/ramaladni inspect — эффекты цели
/ramaladni inspect self — эффекты персонажа
/ramaladni offbalance — диагностика Off Balance
/ramaladni test — демонстрация таймера

СОВМЕСТИМОСТЬ И ПРОВЕРКИ
В манифесте указаны API 101051 и 101052. Используются нативные EventFilters и режим совместимости для сопоставления по имени. Интервал обновления HUD — 200 мс. Финальные изменения g4 проверены автономно; полноценная игровая регрессия, проверка PTS и измерение CPU/памяти в клиенте ещё не завершены. Не каждый игровой эффект доступен через ESO API.

ИСТОЧНИКИ И БЛАГОДАРНОСТИ
Developed by Northknightwest (Ramaladni).
- ESO ID Dictionary (Update 52): effect-ID reference data, organized into Ramaladni effect groups from the project’s supplied dataset.
- ESO Logs (https://www.esologs.com/): ability catalogs and combat-event reference data used for Class Mastery research.
- ESO-Hub (https://eso-hub.com/): named-effect and Class Mastery mechanics references.
- MD Community (https://md-eso.ru/): buff/debuff classification reference and community logo. Effect reference: https://md-eso.ru/topic/8229-active-buffs-and-debuffs/
- Untaunted by Solinur (https://www.esoui.com/downloads/info1475-Untaunted.html).
- ZeniMax Online Studios and the ESOUI community: ESO UI/API documentation and reference implementation (https://github.com/esoui/esoui).
- Special thanks to Baertram for technical review and guidance on addon development best practices.
The referenced addons are not runtime dependencies. The Elder Scrolls Online, game icons and associated marks belong to their respective owners. Ramaladni is not affiliated with or endorsed by ZeniMax Online Studios.

САЙТЫ
Buff/Debuff Base: https://md-eso.ru/topic/8229-active-buffs-and-debuffs/
MD: https://md-eso.ru/
Discord: https://discord.gg/azr8QDYhyJ
Copyright (c) 2026 Northknightwest (Ramaladni).
