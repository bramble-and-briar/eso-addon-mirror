QuestArrow 0.2.2
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

QuestArrow 0.2.1
===============

ENGLISH first / РУССКИЙ ниже

English

QuestArrow is an add-on for The Elder Scrolls Online on PC. It points toward your selected quest objective and suggests wayshrines when fast travel can shorten the journey. Cross-zone destination lookup is supported when the necessary game data is available.

Author: alabuzya  
Questions, suggestions and bug reports: aabuziarov@gmail.com

Created with AI assistance. No external libraries are required.

Installation and updates

1. Close ESO.
2. Extract the QuestArrow folder into Documents\Elder Scrolls Online\live\AddOns. If Documents has been relocated, for example to OneDrive, use its actual location.
3. Check the resulting path: AddOns\QuestArrow\QuestArrow.txt.
4. Start the game and enable QuestArrow in the Add-Ons menu.

To update, replace the files in AddOns\QuestArrow while the game is closed. Your settings are preserved.

Getting started

Open the standard keyboard-mode quest journal, select a quest, and click «Показывать путь» (Show route). Close the journal. Obtaining an objective marker may take a few seconds. Clicking the button again for the same quest turns navigation off.

The add-on's own interface text is currently in Russian. This README provides English instructions; the interface has not yet been translated.

With gamepad mode or a replacement journal, focus the desired quest using the game's built-in quest tracking, close the journal, and enter /qa.

Moving and reading the pointer

Enter /qa unlock, enable the mouse cursor using your assigned in-game key (usually the period key), and drag an empty part of the frame. Enter /qa lock to lock it; the frame disappears and stops intercepting mouse input. /qa reset restores the default position, size and opacity. Settings and the selected quest are saved separately for each character.

- Gold: points toward a quest marker, search area or intermediate passage.
- Turquoise: points toward the departure wayshrine; the text identifies the travel destination.
- An upward-pointing arrow means the direction your camera is facing.
- At a marker, a message prompts you to perform the quest action or search the area.
- At the wayshrine, travel to the suggested destination manually. The route is recalculated after you arrive.
- The pointer is hidden while viewing the map and other menus.

Wayshrine suggestions

On an outdoor zone or city map, QuestArrow compares the direct approach with walking to a wayshrine and the remaining walk after fast travel. Suggestions consider usable wayshrines and the expected reduction in walking distance.

For a destination in another zone, it first looks for an unlocked travel node at the destination itself, or a wayshrine near the available quest location marker. If there is insufficient information, it falls back to the game's intermediate passage marker. Cross-zone suggestions need one local departure wayshrine; comparisons within a zone need at least two usable wayshrines.

Commands

| Command | Action |
| --- | --- |
| /qa | Toggle navigation for the selected or focused quest |
| /qa stop | Stop navigation |
| /qa next | Select another available objective within the quest |
| /qa unlock, /qa lock | Unlock movement / lock the pointer |
| /qa reset | Reset position, size and opacity |
| /qa travel on, /qa travel off | Enable / disable wayshrine suggestions (enabled by default) |
| /qa threshold 1 | Same-zone travel threshold, from 0.5 to 2; lower values allow earlier suggestions |
| /qa scale 1.5 | Pointer scale, from 0.5 to 2 |
| /qa alpha 0.7 | Opacity, from 0.2 to 1 |
| /qa refresh | Refresh the objective and resume navigation after an error |
| /qa debug | Print diagnostic information in chat |
| /qa help | Show command help |

Features and limitations

- The arrow indicates a straight-line direction. It does not find paths around walls, mountains or between floors.
- Objective accuracy depends on game data. A search area is not the exact position of a quest item.
- Cross-zone suggestions require destination information and unlocked, usable travel nodes. The game makes the final decision on whether travel is available.
- Inside buildings, a local objective or passage marker may be available if the game provides one.
- Regular wayshrine suggestions are disabled in PvP areas and dungeons.
- Distance is displayed as a percentage of map height, not in metres.
- Use /qa next when the quest offers several objectives.
- The journal button is added to the standard keyboard interface. In gamepad mode, use /qa for the focused quest.

Feedback

Email aabuziarov@gmail.com with questions and suggestions. For bug reports, include the add-on version, quest name, zone, current quest step, /qa debug output, and any Lua error message. A screenshot and a list of add-ons that modify the journal or map are also helpful.

Uninstalling

Close the game and remove AddOns\QuestArrow. Settings remain in SavedVariables\QuestArrowSavedVariables.lua; delete that file while the game is closed if you also want to remove the saved settings.

================================================
РУССКИЙ
================================================

Автор: alabuzya
Вопросы, пожелания и сообщения об ошибках: aabuziarov@gmail.com

QuestArrow добавляет в The Elder Scrolls Online на PC указатель к выбранному
заданию и рекомендует дорожные святилища, если перенос сокращает путь.
Поддерживается поиск назначения в другой зоне при наличии данных игры.
Аддон создан при помощи ИИ. Сторонние библиотеки не требуются.

УСТАНОВКА И ОБНОВЛЕНИЕ
1. Закройте ESO.
2. Распакуйте папку QuestArrow из архива в папку AddOns вашего клиента.
   Обычно: Документы\Elder Scrolls Online\live\AddOns\
   Если Документы перенесены, например в OneDrive, используйте фактический путь.
3. Проверьте итоговый путь: AddOns\QuestArrow\QuestArrow.txt.
4. Запустите игру и включите QuestArrow в меню дополнений.

Для обновления замените файлы AddOns\QuestArrow при закрытой игре.
Настройки сохранятся.

ИСПОЛЬЗОВАНИЕ
Откройте стандартный журнал в клавиатурном режиме, выделите задание
и нажмите «Показывать путь». Закройте журнал. Получение метки может занять
несколько секунд. Повторное нажатие для того же задания убирает стрелку.

В режиме геймпада или при использовании другого журнала включите штатное
отслеживание нужного задания, закройте журнал и введите /qa.

ПЕРЕМЕЩЕНИЕ И НАСТРОЙКА
/qa unlock — разблокировать рамку.
Включите курсор назначенной в игре клавишей (обычно точка «.»)
и перетащите рамку за свободную область.
/qa lock — закрепить; рамка исчезнет и перестанет перехватывать мышь.
/qa reset — вернуть положение, размер и прозрачность по умолчанию.
Настройки и выбранное задание сохраняются отдельно для персонажа.

КАК ЧИТАТЬ УКАЗАТЕЛЬ
Золотая стрелка: к квестовой метке, области поиска или переходу.
Бирюзовая стрелка: к святилищу отправления; подпись указывает назначение.
Стрелка вверх означает направление взгляда камеры.
У метки появляется подсказка выполнить действие; в области поиска — искать цель.
У святилища перенеситесь вручную в указанное назначение.
После перемещения аддон пересчитает путь по фактическому местоположению.
Во время просмотра карты и других меню указатель скрывается.

ВЫБОР СВЯТИЛИЩА
В открытой зоне или городе аддон сравнивает прямой путь с подходом
к святилищу и остатком пути после переноса. Рекомендация учитывает
расположение пригодных святилищ и ожидаемое сокращение пути.

Для цели в другой зоне сначала ищется открытый узел непосредственно
у места назначения либо святилище рядом с доступной меткой места задания.
Если сведений недостаточно, остаётся штатная метка перехода.
Для межзональной рекомендации достаточно одного местного святилища
отправления; для сравнения вариантов внутри зоны нужны хотя бы два.

КОМАНДЫ
/qa                    Включить/выключить путь к выбранному или отслеживаемому заданию.
/qa stop               Выключить навигацию.
/qa next               Переключить доступную цель внутри задания.
/qa unlock             Разрешить перемещение указателя.
/qa lock               Закрепить указатель.
/qa reset              Сбросить положение, размер и прозрачность.
/qa travel on          Включить рекомендации святилищ (по умолчанию).
/qa travel off         Вести только к метке задания.
/qa threshold 1        Порог переноса внутри зоны; диапазон 0.5–2.
                       Меньшее значение позволяет рекомендовать перенос раньше.
/qa scale 1.5          Размер; диапазон 0.5–2.
/qa alpha 0.7          Прозрачность; диапазон 0.2–1.
/qa refresh            Обновить цель и возобновить навигацию после ошибки.
/qa debug              Вывести диагностику в чат.
/qa help               Список команд.

ОСОБЕННОСТИ И ОГРАНИЧЕНИЯ
- Стрелка показывает направление по прямой, без обхода стен, гор и этажей.
- Точность цели зависит от данных игры. Область поиска не является
  точным положением квестового предмета.
- Межзональный перенос зависит от сведений о назначении и открытых
  пригодных узлов. Окончательную возможность переноса определяет сама игра.
- В помещениях доступна локальная метка или метка перехода, если её отдаёт игра.
- В PvP и подземельях рекомендации обычных святилищ отключены.
- Расстояние отображается в процентах высоты карты, а не в метрах.
- При нескольких целях используйте /qa next для выбора нужной.
- Кнопка добавляется в стандартный клавиатурный журнал.
  В режиме геймпада используйте /qa для отслеживаемого задания.

ОБРАТНАЯ СВЯЗЬ
Пишите на aabuziarov@gmail.com с вопросами и пожеланиями.
При сообщении об ошибке приложите версию аддона, название задания,
зону, текущий этап, вывод /qa debug и текст Lua-ошибки, если он появился.
Скриншот и список аддонов, меняющих журнал или карту, помогут разобраться.

УДАЛЕНИЕ
Закройте игру и удалите папку AddOns\QuestArrow.
Настройки остаются в SavedVariables\QuestArrowSavedVariables.lua.
Для полного сброса удалите этот файл при закрытой игре.
