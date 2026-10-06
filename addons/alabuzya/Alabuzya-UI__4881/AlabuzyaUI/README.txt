Alabuzya UI 1.0.6

Developed with AI assistance, including code generation and new UI textures.
Разработано с помощью ИИ, включая написание кода и создание новых текстур интерфейса.

INSTALL ALONGSIDE / УСТАНОВИТЕ ВМЕСТЕ С АДДОНОМ
LibAddonMenu-2.0 — https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html — required for the settings menu / нужна для меню настроек.
Find “LibAddonMenu-2.0” in Minion and install it separately.
Найдите «LibAddonMenu-2.0» в Minion и установите отдельно.
No other libraries are required. Without this library, the addon loads and uses its saved settings/defaults, but its settings menu is unavailable.
Другие библиотеки не нужны. Без этой библиотеки аддон загружается и использует сохранённые настройки или значения по умолчанию, но меню настроек недоступно.

AVAILABLE STYLES / Существующие стили

English
- Diablo — resource orbs, ornate frames, and a combined minimap/quest sidebar.
- WoW — compact dual action bars, horizontal resource bars, role icons, a round minimap and a separate quest tracker. In groups and trials, your resources appear above the action bars.
- DS_3 — ash/brass minimalist HUD: fixed dual skill rows, a truly collapsible chat icon, round minimap, active quest without a frame, DPS/damage share beneath personal resources.

Русский
- Diablo — сферы ресурсов, декоративные рамки и общая боковая панель миникарты и заданий.
- WoW — компактные панели навыков в два ряда, полосы ресурсов, значки ролей, круглая миникарта и отдельный список заданий. В группе и триале личные ресурсы отображаются над навыками.
- DS_3 — минималистичная тема: два фиксированных ряда навыков, сворачиваемый значок чата, круглая миникарта, задание без рамки и DPS/доля урона под ресурсами.

Choose a style under Settings → Addons → Alabuzya UI → Interfaces. You can also disable the skin to use the standard ESO interface. All styles share the same functional modules and their settings. Diablo was the first style; more styles are planned.
Выбор: Настройки → Дополнения → Alabuzya UI → Интерфейсы. Оформление также можно отключить и использовать стандартный интерфейс ESO. Функциональные модули и их настройки общие для всех тем. Diablo — первый стиль; в дальнейшем планируются новые.

Alabuzya UI — English
A configurable interface and everyday helpers for The Elder Scrolls Online on PC. Choose between the Diablo, WoW and DS_3 styles described above. You can also select the standard ESO interface while keeping the independent utility features enabled.

The custom UI textures were newly generated with OpenAI image generation and prepared for use in ESO. The resource display and theme system were written anew, and the functional modules have been reworked and integrated into the Alabuzya UI codebase. Game-provided icons, maps and fonts remain supplied by ESO.

Features
- Frameless desaturated map overlay with colored native pins and quest/excavation areas, in every style and the stock UI. Assign a toggle key in Controls → Keybindings → Alabuzya UI. Map overlay settings: enable, opacity and size. No default key.
- Diablo resource orbs or WoW horizontal bars/role icons, dual skill panels, styled compass and chat window.
- Combat statistics, critical chance and power displays, effects and target health information.
- Compact group and trial frames with level/Champion Points, roles and context menus.
- Minimap with clocks and a collapsible quest tracker. WoW and DS_3 keep them in separate windows. Click Quests to collapse/expand the list in every custom theme.
- Item list/grid switching, including inventory, merchant, bank and supported crafting lists.
- Automatic weapon recharge and equipment repair with separate enable switches, thresholds from 1–90% and permission to use Crown materials.
- Automatic sale of items already marked as junk to ordinary merchants; locked and stolen items are skipped.
- Chat timestamps, channel colors and message copying.
- Bundled QuestArrow navigation with optional wayshrine suggestions. Movement and teleportation remain manual.

Settings and use
Open Settings → Addons → Alabuzya UI, or enter /alabuzya. The aliases /alabuzyaui and /diaui are also supported. LibAddonMenu-2.0 is needed to open this panel.
Choose Diablo, WoW, DS_3 or Disabled — standard ESO under Interfaces. Use the Reload UI button in that section to apply a style change. Recharge, repair, junk selling and chat helpers can be switched independently of the visual style. The grid and guild roster background adjustment also have their own switches.
Repair/recharge default to enabled at 10%, with Crown materials allowed. Regular suitable materials are preferred; the addon does not purchase materials.
Account-wide settings are separate for EU, NA and PTS. Navigation settings are also stored per character. Previous settings migrate automatically when updating from the preceding Alabuzya UI version.

Compatibility and limitations
Designed primarily for keyboard/mouse UI. WoW uses ESO role icons in round frames rather than live character portraits. The first WoW release needs in-game visual feedback. Standalone pChat takes priority over the bundled chat helper. QuestArrow is included as a complete independent addon with its own manifest and AddOnVersion; ESO selects the newest installed copy. Enable or disable QuestArrow in the game addon list; use /qa help for its settings. FancyActionBar and Arkadius' Trade Tools are optional integrations, not required installations.
Disable the old DiaUI, DIAhelp and overlapping full UI replacements when using Alabuzya UI. Avoid enabling two addons that control the same panels or automatic item handling at once.
Combat damage share is an estimate from observed target health loss, not a synchronized group combat log. Quest navigation depends on game-provided data and shows direction rather than a path around obstacles.

Installation
Close ESO and extract the AlabuzyaUI folder into Documents/Elder Scrolls Online/live/AddOns. The manifest must be at AddOns/AlabuzyaUI/AlabuzyaUI.txt. Enable Alabuzya UI in the addon list. Install LibAddonMenu-2.0 separately for settings. Do not delete SavedVariables when updating.

Author, credits and contact
Alabuzya UI: alabuzya. Developed with OpenAI AI assistance for code and artwork. Supporting modules are adapted from the author's DIAhelp project; bundled QuestArrow is also by alabuzya. Full credits and licensing details are included in CREDITS.txt and LICENSE (GPL-3.0-or-later).
Thanks to Baertram for valuable guidance as I learn to develop ESO addons.
Profile: https://www.esoui.com/forums/member.php?u=2028
Thanks also to Atharti for suggesting texture compression — without that tip,
I would have taken much longer to realize it was needed.
Profile: https://www.esoui.com/forums/member.php?u=75599

Thanks to Bandits UI — https://www.esoui.com/downloads/info1643-BanditsUserInterface.html for long-buff placement and power/critical displays.
Thanks to AUI — https://www.esoui.com/downloads/info919-AUI-AdvancedUI.html for DPS display inspiration.
Thanks to Votan’s Minimap — https://www.esoui.com/downloads/info1399-VotansMiniMap.html for minimap inspiration.
Thanks to Ravalox’ Quest Tracker — https://www.esoui.com/downloads/info13-RavaloxQuestTracker.html for quest grouping by zone.
Thanks to Fancy Action Bar — https://www.esoui.com/downloads/info2462-FancyActionBar.html for the dual action-bar idea.
Thanks to DiabloFrames — https://www.esoui.com/downloads/info3051-DiabloFrames.html for the inspiration to start this project.
Thanks to Fyrakin’s Minimap [Masteroshi430 branch] — https://www.esoui.com/downloads/info3384-MiniMapbyFyrakinMasteroshi430sbranch.html for round minimap and ActionMap inspiration.
Thanks to MapRadar — https://www.esoui.com/downloads/info3866-MapRadar.html for overlay research.


Contact: aabuziarov@gmail.com. For bug reports, include the addon version, a description of what happened, steps to reproduce, a screenshot or Lua error, and relevant enabled addons.
An independent community addon; not affiliated with or sponsored by ZeniMax Media Inc.

Alabuzya UI — Русский
Настраиваемый интерфейс и повседневные помощники для The Elder Scrolls Online на ПК. Доступны описанные выше стили Diablo, WoW и DS_3. Можно выбрать стандартный интерфейс ESO и продолжить пользоваться независимыми вспомогательными функциями.

Собственные текстуры интерфейса заново сгенерированы с помощью OpenAI и подготовлены для использования в ESO. Панель ресурсов и система оформления написаны заново; функциональные модули переработаны и объединены в кодовой базе Alabuzya UI. Штатные значки, карты и шрифты предоставляет сама игра.

Возможности
- Оверлей обесцвеченной карты без рамки с цветными значками и областями заданий/раскопок, во всех темах и стандартном интерфейсе. Назначьте клавишу в «Управление → Назначение клавиш → Alabuzya UI». В настройках оверлея — включение, прозрачность и размер. По умолчанию клавиша не назначена.
- Сферы ресурсов Diablo или полосы ресурсов и значки ролей WoW, две панели умений, оформление компаса и чата.
- Боевая статистика, показатели критического шанса и силы, эффекты и здоровье цели.
- Компактные панели группы и испытания с уровнем/ОГ, ролями и контекстным меню.
- Миникарта с часами и сворачиваемый список заданий. В WoW и DS_3 они находятся в отдельных окнах. Клик по «Задания» сворачивает/разворачивает список во всех темах.
- Переключение списка и сетки предметов в инвентаре, у торговца, в банке и поддерживаемых ремесленных списках.
- Автоматическая зарядка оружия и ремонт снаряжения: отдельные переключатели, пороги от 1 до 90%, разрешение на использование кронных материалов.
- Продажа обычному торговцу предметов, уже отмеченных как мусор. Заблокированные и краденые вещи пропускаются.
- Время сообщений, цвета каналов и копирование текста чата.
- Встроенная навигация QuestArrow с рекомендациями дорожных святилищ. Перемещение и телепортацию игрок выполняет самостоятельно.

Настройки и использование
Откройте Настройки → Дополнения → Alabuzya UI или введите /alabuzya. Также работают /alabuzyaui и /diaui. Для этого меню нужна LibAddonMenu-2.0.
В разделе «Интерфейсы» доступны Diablo, WoW, DS_3 и «Отключено — стандартный ESO». Для применения смены темы нажмите там же «Перезагрузить интерфейс». Зарядка, ремонт, продажа мусора и функции чата включаются независимо от оформления. Дополнительно предусмотрены переключатели сетки и подгонки фона списка гильдии.
По умолчанию ремонт и зарядка включены, порог — 10%, кронные материалы разрешены. Подходящие обычные материалы используются первыми; аддон ничего не покупает.
Общие настройки аккаунта разделены между EU, NA и PTS. Настройки навигации дополнительно привязаны к персонажу. При обновлении с предыдущей версии Alabuzya UI прежние настройки переносятся автоматически.

Совместимость и ограничения
Основной режим — клавиатура и мышь. WoW использует значки ролей ESO в круглых рамках вместо живых портретов. Первая версия WoW нуждается в проверке внешнего вида в игре. Отдельный pChat имеет приоритет над встроенным помощником чата. QuestArrow включён как полноценный независимый аддон со своим манифестом и AddOnVersion: ESO выбирает наиболее новую установленную копию. Включение и отключение QuestArrow — в игровом списке аддонов; его настройки — /qa help. FancyActionBar и Arkadius' Trade Tools также относятся к необязательным интеграциям.
При использовании Alabuzya UI отключите старый DiaUI, DIAhelp и другие полные замены интерфейса с пересекающимися функциями. Не включайте одновременно два аддона, управляющих одними панелями или автоматической обработкой предметов.
Доля урона оценивается по наблюдаемой потере здоровья цели и не является синхронизированным журналом боя группы. Навигация зависит от данных игры и показывает направление, а не маршрут в обход препятствий.

Установка
Закройте ESO и распакуйте папку AlabuzyaUI в Documents/Elder Scrolls Online/live/AddOns. Итоговый путь: AddOns/AlabuzyaUI/AlabuzyaUI.txt. Включите Alabuzya UI в списке модификаций. Для настроек отдельно установите LibAddonMenu-2.0. При обновлении не удаляйте SavedVariables.

Авторство и обратная связь
Автор Alabuzya UI — alabuzya. При разработке кода и графики использовалась помощь ИИ OpenAI. Вспомогательные модули адаптированы из собственного проекта автора DIAhelp; встроенный QuestArrow также создан alabuzya. Полные сведения об авторстве и лицензии — в CREDITS.txt и LICENSE (GPL-3.0-or-later).
Выражаю благодарность Baertram за важные подсказки новичку в разработке аддонов ESO.
Профиль: https://www.esoui.com/forums/member.php?u=2028
А также Atharti за совет сжать текстуры — без него я бы ещё долго
не догадался это сделать.
Профиль: https://www.esoui.com/forums/member.php?u=75599

Спасибо Bandits UI — https://www.esoui.com/downloads/info1643-BanditsUserInterface.html за расположение длительных бафов и показатели силы/крита.
Спасибо AUI — https://www.esoui.com/downloads/info919-AUI-AdvancedUI.html за идею отображения DPS.
Спасибо Votan’s Minimap — https://www.esoui.com/downloads/info1399-VotansMiniMap.html за идеи миникарты.
Спасибо Ravalox’ Quest Tracker — https://www.esoui.com/downloads/info13-RavaloxQuestTracker.html за группировку заданий по зонам.
Спасибо Fancy Action Bar — https://www.esoui.com/downloads/info2462-FancyActionBar.html за идею двух панелей навыков.
Спасибо DiabloFrames — https://www.esoui.com/downloads/info3051-DiabloFrames.html за вдохновение для создания этого проекта.
Спасибо Fyrakin’s Minimap [Masteroshi430 branch] — https://www.esoui.com/downloads/info3384-MiniMapbyFyrakinMasteroshi430sbranch.html за идеи круглой миникарты и ActionMap.
Спасибо MapRadar — https://www.esoui.com/downloads/info3866-MapRadar.html за материалы для изучения оверлеев.


Связь: aabuziarov@gmail.com. В сообщении об ошибке укажите версию аддона, описание проблемы, шаги для повторения, приложите скриншот или текст Lua-ошибки и перечислите связанные включённые аддоны.
Независимый аддон сообщества, не связанный с ZeniMax Media Inc. и не спонсируемый ею.

QUICK CONTROLS / БЫСТРЫЕ ДЕЙСТВИЯ
EN: Shift + left-drag moves the group panel. Right-click a chat timestamp to
copy a message (when the bundled chat helper is active). /qa help lists arrow
commands; /qa unlock and /qa lock control its position. /qa stop stops tracking.
Navigation distances are fractions of map height, not metres.
If upgrading from the old DiaUI name, see RENAME-0.1.37.txt first.
Release changes: CHANGELOG.txt. Credits: CREDITS.txt. License: LICENSE.

RU: Shift + перетаскивание левой кнопкой перемещает панель группы. Правая кнопка
по времени сообщения открывает копирование, если включён встроенный помощник чата.
/qa help показывает команды стрелки; /qa unlock и /qa lock управляют её положением,
/qa stop выключает отслеживание. Расстояния стрелки — доля высоты карты, не метры.
Для перехода со старого названия DiaUI сначала прочитайте RENAME-0.1.37.txt.
Изменения: CHANGELOG.txt. Авторство: CREDITS.txt. Лицензия: LICENSE.

Assistant toolbar / Панель помощников (0.1.57)
EN: Settings > Chat > Assistant toolbar beside chat. Independent of the visual theme and chat formatting toggle. A vertical column of native collectible icons follows chat visibility. Click to summon a random available unlocked assistant in that category; an already active collectible is dismissed. Locked/unusable categories are dimmed. The assistant ID registry is maintained in AssistantPanel.lua as new assistants are added to ESO.
RU: Настройки > Чат > Панель помощников рядом с чатом. Не зависит от темы и переключателя обработки сообщений чата. Вертикальный столбец игровых иконок следует за видимостью чата. Клик вызывает случайного доступного помощника категории; уже активный убирается. Недоступные категории затемнены. Список идентификаторов в AssistantPanel.lua обновляется по мере добавления помощников в ESO.

SESSION GOLD AND FONTS / ЗОЛОТО СЕССИИ И ШРИФТЫ
EN: Interfaces → Font selects a localized ESO client font independently for each style; use Reload UI to apply. Income and expenses → Session gold tracker enables a theme-independent HUD widget. Click the gold square for date, character, session number, net and character gold balance; 12 recent rows initially, then a scrollable last 30 days and earlier periods via Show more. Records persist across updates, separately for EU/NA/PTS. Login/character entry starts a session; /reloadui continues it. Own-bank transfers are excluded; guild bank, trades, mail, purchases and rewards affect net according to actual gold changes. Disabled time is excluded. Shift-drag the widget to move it.
RU: «Интерфейсы → Шрифт» выбирает локализованный шрифт ESO отдельно для темы; примените перезагрузкой интерфейса. «Доходы и расходы → Счётчик золота за сессию» включает независимый значок. Клик открывает дату, персонажа, номер сессии, сальдо и остаток золота: сначала 12 записей, затем последние 30 дней со скроллом и более ранние периоды по кнопке. История сохраняется при обновлении отдельно для EU/NA/PTS. Вход на персонажа создаёт сессию; /reloadui её продолжает. Переводы в собственный банк исключены; гильдейский банк, обмен, почта, покупки и награды учитываются по фактическому изменению золота. Выключенное время не считается. Перемещение значка: Shift + перетаскивание.
EN: Quest circles and excavation polygons use the native world-map pins and visibility filters, shared by every custom theme. Unscryed/undiscovered dig areas unavailable on the main map cannot be shown.
RU: Круги заданий и области раскопок используют игровые данные и фильтры основной карты во всех темах. Неизвестные/неоткрытые области, отсутствующие на основной карте, не показываются.

EN: Income and expenses → Accounting period offers By day (default) and By session. Changes the widget and table immediately, retaining all session data. Daily totals cover all characters on the current server. Daily gold balance sums the latest recorded balances of characters included that day. New transactions are split by calendar date across midnight; legacy session totals belong to the start date because transaction timestamps were not previously recorded.
RU: «Доходы и расходы → Период подсчёта»: «По дням» (по умолчанию) или «По сессиям». Значок и таблица меняются сразу, история сохраняется. Дневной итог объединяет всех персонажей текущего сервера. Остаток золота за день — сумма последних записанных остатков персонажей, участвовавших в этот день. Новые операции разделяются по календарным датам при переходе через полночь; прежние итоги сессий относятся к дате начала, поскольку время отдельных операций ранее не сохранялось.

Overlay troubleshooting / Диагностика оверлея
/auimap toggles the overlay and prints status; /auimap status reports state without toggling. Include the printed line when reporting a problem.
/auimap переключает оверлей и выводит состояние; /auimap status только выводит состояние. При проблеме приложите строку из чата.
