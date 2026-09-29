DIAhelp 1.0.5
Developed with AI assistance, including code generation.
Author: alabuzya <aabuziarov@gmail.com>

Update notes / Обновление
EN: Settings are now independent for each server and account. Character settings
remain per character ID, also separated from PTS copies. Legacy settings migrate
automatically on first use of each server; previous data is retained for rollback.
Already separated server settings are not overwritten. No manual file editing or
extra reload is required when updating from the previous version of this addon.
See CHANGELOG.txt and CREDITS.txt. UI appearance and feature behavior are unchanged.
RU: Настройки разделены по серверам и аккаунтам. Настройки персонажа остаются
привязаны к его ID, включая отдельную копию на PTS. Старые значения переносятся
автоматически при первом использовании на сервере; исходные данные сохраняются.
Уже существующие серверные настройки не перезаписываются. Для обычного обновления
не нужно редактировать сохранения или дополнительно перезагружать интерфейс.
Внешний вид и поведение функций сохранены. Подробности: CHANGELOG.txt, CREDITS.txt.

Usage guide and previous release notes / Инструкция и история версий

DIAhelp 1.0.4
Русский / English
Автор / Author: alabuzya
Связь / Contact: aabuziarov@gmail.com

==================== РУССКИЙ ====================

Аддон разработан с использованием искусственного интеллекта (ИИ), в том числе для написания кода.

DIAhelp — интерфейс для The Elder Scrolls Online в стиле Diablo и набор
повседневных помощников. Основа оформления — DiabloFrames авторов
BulDeZir и Forsion. Аддон предназначен для интерфейса с клавиатурой и мышью.


ВОЗМОЖНОСТИ
- Сферы ресурсов, две строки умений, увеличенные цифры таймеров.
  Вторая строка показывает умения неактивного оружия; она не позволяет
  применять их без смены оружия и не отслеживает все их эффекты.
- Переключение списка и сетки предметов: инвентарь, банки, домашнее
  хранилище, ремесленная сумка, хранилище мебели, торговля и поддерживаемые
  ремесленные списки. Выбор сохраняется отдельно для типа окна.
  Домашние сундуки используют общую настройку типа хранилища.
- DPS-метр: подробный и краткий виды, переключение щелчком мыши.
  В кратком виде: урон в секунду, приблизительная доля урона, время боя.
  Доля относится к наблюдаемой цели и учитывает снижение её здоровья
  от всех атакующих, в том числе вне группы. Это оценка, а не точный
  групповой отчёт; при нехватке данных отображается --.
  В личный урон включены атаки игрока и его боевых питомцев.
- Индикаторы критического шанса и силы, здоровье цели и босса в формате
  «текущее / максимальное (процент)» с разделением тысяч пробелами.
- В группе больше четырёх игроков включается рейдовая сетка: по шесть
  игроков в колонке, имя и здоровье на отдельных строках. Спутники в этом
  режиме скрыты, чтобы не занимать места игроков.
- Компактные полосы группы, отдельные узкие строки спутников, значки
  ролей и корона лидера. Правая кнопка по игроку открывает меню действий.
- Миникарта с часами, автоматическим масштабом при движении и верховой
  езде, метками основной карты. Колесо мыши меняет масштаб.
- Список заданий по областям со сворачиваемыми разделами.
- Длительные и постоянные эффекты справа снизу, короткие эффекты
  и отрицательные эффекты — над панелью умений. Для временных эффектов
  показывается оставшееся время.
- Встроенный QuestArrow: кнопка в журнале заданий включает стрелку
  навигации. Подсказывает путь к цели или святилищу; перемещение
  и телепортацию игрок выполняет самостоятельно.
- Чат: цвета по типам сообщений, время [14:28], копирование текста.
- Автоматический ремонт надетого снаряжения при прочности 10% и ниже,
  зарядка оружия при заряде 10% и ниже, в том числе во время боя.
  Подходящие обычные материалы из рюкзака выбираются сначала по цене
  продажи торговцу, кронные — после обычных. Групповые ремонтные наборы
  не используются. Подтверждённый ремонт и зарядка сообщаются в чат.
- Продажа уже отмеченного мусором содержимого рюкзака при открытии
  обычного торговца. Заблокированные, краденые и ничего не стоящие
  предметы пропускаются. Сам аддон не помечает предметы мусором.
- Кнопка ультимативного умения спутника скрыта; включается штатное
  автоматическое применение. Эта настройка игры может сохраняться
  после отключения аддона; изменить её можно в настройках игры.

УСТАНОВКА И ОБНОВЛЕНИЕ
1. Распакуйте папку DIAhelp из ZIP в:
   Documents\Elder Scrolls Online\live\AddOns\
   Итоговый путь: AddOns\DIAhelp\DIAhelp.txt.
2. Включите DIAhelp в списке модификаций. Обязательных библиотек нет.
3. При обновлении замените файлы и выполните /reloadui либо перезапустите
   игру. Пользовательские настройки сохраняются отдельно игрой.

Отключите аддоны, дублирующие нужные вам функции DIAhelp: оригинальный
DiabloFrames, GridList, AutoRecharge, JunkHandler, а также соответствующие
модули Bandits UI. Для использования встроенных аналогов отключите
FancyActionBar, Votan's Minimap, Ravalox Quest Tracker, pChat и QuestArrow.
Если pChat или отдельный QuestArrow включены, DIAhelp отдаёт им приоритет.
Другие аддоны и необходимые им библиотеки можно оставить.

УПРАВЛЕНИЕ
- Включите курсор для взаимодействия с панелями.
- Щелчок по DPS-метру переключает подробный и краткий режимы.
- DPS-метр и индикаторы характеристик можно перетаскивать. Блок группы
  перемещается через Shift + левую кнопку мыши.
  Миникарта и задания перемещаются за заголовок; позиции сохраняются.
- Кнопка над предметами переключает список и сетку.
- Правая кнопка по времени сообщения → «Копировать сообщение».
  В открывшемся поле текст выделен: нажмите Ctrl+C.
- /qa help — команды стрелки; /qa unlock — перемещение стрелки;
  /qa lock — закрепление; /qa stop — остановка навигации.

ОСОБЕННОСТИ
Если будет хотя бы 100–200 установок, добавлю настройки (а там много чего можно настраивать).

Отдельного меню настроек пока нет. Интерфейс геймпада не является целью
этой версии. Списки с неподдерживаемыми типами строк не переводятся в сетку.
Миникарта отображает доступные метки основной карты; произвольные слои
других аддонов и области не гарантируются. Время Тамриэля приблизительное.
Лечение в подробном метре может включать избыточное лечение.
Копирование чата доступно для последних 5000 обработанных сообщений
текущего сеанса; история после перезагрузки интерфейса не восстанавливается.
Настройки отдельного QuestArrow не переносятся автоматически во встроенный.

Вопросы, пожелания и сообщения об ошибках: aabuziarov@gmail.com.
Укажите версию DIAhelp, что произошло, текст ошибки и при необходимости
приложите скриншот. Лицензия и авторство: LICENSE и CREDITS.txt.

==================== ENGLISH ====================

This add-on was developed with AI assistance, including code generation.

DIAhelp brings a Diablo-style interface and everyday helpers to
The Elder Scrolls Online. Its visual foundation is DiabloFrames by
BulDeZir and Forsion. Designed for the keyboard and mouse interface.

FEATURES
- Resource orbs, two skill rows and larger timer numbers. The inactive
  weapon row is a preview: it does not cast skills without swapping
  weapons or track every effect on that bar.
- List/grid toggle for inventory, banks, house storage, craft bag,
  furniture vault, vendors and supported crafting lists. View preferences
  are saved per window type. House chests share a storage-type preference.
- Click-to-switch detailed/compact combat meter. Compact mode displays
  DPS, estimated damage share and combat time. Damage share concerns
  the observed target and its health loss from all attackers, including
  players outside your group. It is an estimate, not an exact group report;
  unavailable data is shown as --. Personal damage includes player pets.
- Critical chance and power gauges; target/boss health shown as
  current / maximum (percentage), with spaces separating thousands.
- Groups larger than four use a raid layout: six players per column, with
  separate name and health lines. Companion rows are hidden in this mode.
- Compact group health bars, shorter companion rows, role icons and
  a leader crown. Right-click a player for available group actions.
- Minimap with clocks, automatic movement/mount zoom and main-map pins.
  Use the mouse wheel to adjust zoom.
- Quest tracker with collapsible zone sections.
- Long-lasting and permanent effects at the bottom right; short effects
  and debuffs above the action bar. Timed effects show their remaining time.
- Bundled QuestArrow: start navigation from the quest journal button.
  The arrow suggests a quest destination or wayshrine. Moving and
  teleporting remain manual actions.
- Chat channel colors, [14:28] timestamps and message copying.
- Automatic equipped-gear repair at 10% condition or below and weapon
  recharge at 10% charge or below, including during combat. Suitable
  ordinary backpack materials are used by ascending vendor sale price;
  Crown materials come after ordinary ones. Group repair kits are excluded.
  Confirmed repairs and recharges are reported in chat.
- Automatically sells backpack items already marked as junk when opening
  a regular vendor. Locked, stolen and zero-value items are skipped.
  DIAhelp does not automatically mark items as junk.
- Hides the companion ultimate button and enables the game's native
  automatic casting option. That game setting can persist after disabling
  DIAhelp; it can be changed in the game's settings.

INSTALLATION AND UPDATES
1. Extract the DIAhelp folder from the ZIP into:
   Documents\Elder Scrolls Online\live\AddOns\
   The manifest must be at AddOns\DIAhelp\DIAhelp.txt.
2. Enable DIAhelp in the Add-Ons menu. No required libraries.
3. To update, replace the files, then use /reloadui or restart the game.
   Your settings are stored separately by the game.

Disable add-ons that duplicate the DIAhelp features you intend to use:
original DiabloFrames, GridList, AutoRecharge, JunkHandler and overlapping
Bandits UI modules. To use the integrated alternatives, disable
FancyActionBar, Votan's Minimap, Ravalox Quest Tracker, pChat and QuestArrow.
If pChat or standalone QuestArrow is enabled, DIAhelp gives it priority.
Other add-ons and their required libraries can remain enabled.

CONTROLS
- Enable the mouse cursor to interact with panels.
- Click the combat meter to switch between detailed and compact modes.
- Drag the combat meter and stat gauges to move them. Hold Shift and drag
  a group row with the left mouse button to move the group panel.
  Drag the minimap and quest tracker by their headers. Positions are saved.
- Use the button above the items to switch between list and grid.
- Right-click a message timestamp and select Copy message.
  The dialog selects the text for you; press Ctrl+C to copy it.
- /qa help lists navigation commands; /qa unlock enables arrow dragging;
  /qa lock locks the arrow; /qa stop stops navigation.

NOTES
If the add-on reaches at least 100–200 installs, I will add settings (there is plenty to customize).

There is no dedicated settings menu yet. Gamepad UI is not the focus of
this release. Unsupported custom inventory row types remain in list mode.
The minimap uses available main-map pins; arbitrary third-party overlays
and areas are not guaranteed. Tamriel time is approximate.
Healing in the detailed meter may include overhealing.
Chat copying covers the last 5000 processed messages of the current session;
chat history is not restored after a UI reload. Standalone QuestArrow
settings are not automatically imported into the bundled module.

Questions, suggestions and bug reports: aabuziarov@gmail.com.
Please include your DIAhelp version, steps to reproduce, error text and
screenshots where helpful. See LICENSE and CREDITS.txt for attribution.

Not affiliated with or sponsored by ZeniMax Media Inc.