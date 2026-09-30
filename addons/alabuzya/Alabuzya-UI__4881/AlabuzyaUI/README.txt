Alabuzya UI 0.1.44

Developed with AI assistance, including code generation and new UI textures.
Разработано с помощью ИИ, включая написание кода и создание новых текстур интерфейса.

MORE INTERFACE STYLES ARE PLANNED / ПЛАНИРУЮТСЯ НОВЫЕ СТИЛИ ИНТЕРФЕЙСА
Diablo is the first available style for Alabuzya UI. Additional interface styles are planned for future releases; they are not available yet.
Diablo — первый доступный стиль Alabuzya UI. В будущих версиях планируется добавить новые варианты оформления; сейчас они ещё недоступны.

INSTALL ALONGSIDE / УСТАНОВИТЕ ВМЕСТЕ С АДДОНОМ
LibAddonMenu-2.0 — https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html — required for the settings menu / нужна для меню настроек.
Find “LibAddonMenu-2.0” in Minion and install it separately.
Найдите «LibAddonMenu-2.0» в Minion и установите отдельно.
No other libraries are required. Without this library, the addon loads and uses its saved settings/defaults, but its settings menu is unavailable.
Другие библиотеки не нужны. Без этой библиотеки аддон загружается и использует сохранённые настройки или значения по умолчанию, но меню настроек недоступно.

Alabuzya UI — English
A configurable interface and everyday helpers for The Elder Scrolls Online on PC. The current Diablo style combines resource orbs, ornamental frames and a coordinated HUD. You can also select the standard ESO interface while keeping the independent utility features enabled.

The custom UI textures were newly generated with OpenAI image generation and prepared for use in ESO. The resource display and theme system were written anew, and the functional modules have been reworked and integrated into the Alabuzya UI codebase. Game-provided icons, maps and fonts remain supplied by ESO.

Features
- Health, magicka and stamina orbs, skill panel, styled compass and chat window.
- Combat statistics, critical chance and power displays, effects and target health information.
- Compact group and trial frames with level/Champion Points, roles and context menus.
- Minimap with clocks and a quest tracker.
- Item list/grid switching, including inventory, merchant, bank and supported crafting lists.
- Automatic weapon recharge and equipment repair with separate enable switches, thresholds from 1–90% and permission to use Crown materials.
- Automatic sale of items already marked as junk to ordinary merchants; locked and stolen items are skipped.
- Chat timestamps, channel colors and message copying.
- Bundled QuestArrow navigation with optional wayshrine suggestions. Movement and teleportation remain manual.

Settings and use
Open Settings → Addons → Alabuzya UI, or enter /alabuzya. The aliases /alabuzyaui and /diaui are also supported. LibAddonMenu-2.0 is needed to open this panel.
Choose Diablo or Disabled — standard ESO under Interfaces. Style changes require a UI reload. Recharge, repair, junk selling and chat helpers can be switched independently of the visual style. The grid, bundled quest arrow and guild roster background adjustment also have their own switches.
Repair/recharge default to enabled at 10%, with Crown materials allowed. Regular suitable materials are preferred; the addon does not purchase materials.
Account-wide settings are separate for EU, NA and PTS. Navigation settings are also stored per character. Previous settings migrate automatically when updating from the preceding Alabuzya UI version.

Compatibility and limitations
Designed primarily for keyboard/mouse UI. Standalone pChat and QuestArrow take priority over the corresponding bundled helpers; they are optional, not required dependencies. FancyActionBar and Arkadius' Trade Tools are optional integrations, not required installations.
Disable the old DiaUI, DIAhelp and overlapping full UI replacements when using Alabuzya UI. Avoid enabling two addons that control the same panels or automatic item handling at once.
Combat damage share is an estimate from observed target health loss, not a synchronized group combat log. Quest navigation depends on game-provided data and shows direction rather than a path around obstacles.

Installation
Close ESO and extract the AlabuzyaUI folder into Documents/Elder Scrolls Online/live/AddOns. The manifest must be at AddOns/AlabuzyaUI/AlabuzyaUI.txt. Enable Alabuzya UI in the addon list. Install LibAddonMenu-2.0 separately for settings. Do not delete SavedVariables when updating.

Author, credits and contact
Alabuzya UI: alabuzya. Developed with OpenAI AI assistance for code and artwork. Supporting modules are adapted from the author's DIAhelp project; bundled QuestArrow is also by alabuzya. Full credits and licensing details are included in CREDITS.txt and LICENSE (GPL-3.0-or-later).
Contact: aabuziarov@gmail.com. For bug reports, include the addon version, a description of what happened, steps to reproduce, a screenshot or Lua error, and relevant enabled addons.
An independent community addon; not affiliated with or sponsored by ZeniMax Media Inc.

Alabuzya UI — Русский
Настраиваемый интерфейс и повседневные помощники для The Elder Scrolls Online на ПК. Текущее оформление Diablo объединяет сферы ресурсов, декоративные рамки и игровые панели в едином стиле. Можно выбрать стандартный интерфейс ESO и продолжить пользоваться независимыми вспомогательными функциями.

Собственные текстуры интерфейса заново сгенерированы с помощью OpenAI и подготовлены для использования в ESO. Панель ресурсов и система оформления написаны заново; функциональные модули переработаны и объединены в кодовой базе Alabuzya UI. Штатные значки, карты и шрифты предоставляет сама игра.

Возможности
- Сферы здоровья, магии и запаса сил, панель умений, оформление компаса и чата.
- Боевая статистика, показатели критического шанса и силы, эффекты и здоровье цели.
- Компактные панели группы и испытания с уровнем/ОГ, ролями и контекстным меню.
- Миникарта с часами и список заданий.
- Переключение списка и сетки предметов в инвентаре, у торговца, в банке и поддерживаемых ремесленных списках.
- Автоматическая зарядка оружия и ремонт снаряжения: отдельные переключатели, пороги от 1 до 90%, разрешение на использование кронных материалов.
- Продажа обычному торговцу предметов, уже отмеченных как мусор. Заблокированные и краденые вещи пропускаются.
- Время сообщений, цвета каналов и копирование текста чата.
- Встроенная навигация QuestArrow с рекомендациями дорожных святилищ. Перемещение и телепортацию игрок выполняет самостоятельно.

Настройки и использование
Откройте Настройки → Дополнения → Alabuzya UI или введите /alabuzya. Также работают /alabuzyaui и /diaui. Для этого меню нужна LibAddonMenu-2.0.
В разделе «Интерфейсы» доступны Diablo и «Отключено — стандартный ESO». После смены оформления требуется перезагрузка интерфейса. Зарядка, ремонт, продажа мусора и функции чата включаются независимо от оформления. Дополнительно предусмотрены переключатели сетки, встроенной стрелки заданий и подгонки фона списка гильдии.
По умолчанию ремонт и зарядка включены, порог — 10%, кронные материалы разрешены. Подходящие обычные материалы используются первыми; аддон ничего не покупает.
Общие настройки аккаунта разделены между EU, NA и PTS. Настройки навигации дополнительно привязаны к персонажу. При обновлении с предыдущей версии Alabuzya UI прежние настройки переносятся автоматически.

Совместимость и ограничения
Основной режим — клавиатура и мышь. Если установлены отдельные pChat или QuestArrow, соответствующие встроенные помощники уступают им управление. Эти аддоны необязательны. FancyActionBar и Arkadius' Trade Tools также относятся к необязательным интеграциям.
При использовании Alabuzya UI отключите старый DiaUI, DIAhelp и другие полные замены интерфейса с пересекающимися функциями. Не включайте одновременно два аддона, управляющих одними панелями или автоматической обработкой предметов.
Доля урона оценивается по наблюдаемой потере здоровья цели и не является синхронизированным журналом боя группы. Навигация зависит от данных игры и показывает направление, а не маршрут в обход препятствий.

Установка
Закройте ESO и распакуйте папку AlabuzyaUI в Documents/Elder Scrolls Online/live/AddOns. Итоговый путь: AddOns/AlabuzyaUI/AlabuzyaUI.txt. Включите Alabuzya UI в списке модификаций. Для настроек отдельно установите LibAddonMenu-2.0. При обновлении не удаляйте SavedVariables.

Авторство и обратная связь
Автор Alabuzya UI — alabuzya. При разработке кода и графики использовалась помощь ИИ OpenAI. Вспомогательные модули адаптированы из собственного проекта автора DIAhelp; встроенный QuestArrow также создан alabuzya. Полные сведения об авторстве и лицензии — в CREDITS.txt и LICENSE (GPL-3.0-or-later).
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
