-- Russian overrides. English is loaded first and remains the fallback for any
-- string omitted here, matching the localization contract used by the other
-- Bureau addons.
--
-- Keys are the string-id *names*, not the ids themselves. Indexing this table
-- with the global (`[SI_BPD_HEADER_COUNT] = ...`) would raise "table index is
-- nil" and drop the whole file if English had not defined that id yet, so the
-- name is resolved at assignment time and unknown names are skipped instead.
local strings = {
    -- Notification panel
    SI_BPD_HEADER_TITLE = "ЛИЧНЫЕ",
    SI_BPD_HEADER_COUNT = "%d · %d",
    SI_BPD_HEADER_COUNT_OVERFLOW = "%d · %d+",
    SI_BPD_HEADER_COUNT_WITH_OVERDUE = "%d · %d  !%d",
    SI_BPD_HEADER_COUNT_OVERFLOW_WITH_OVERDUE = "%d · %d+  !%d",
    SI_BPD_NOTIFICATION_COMPACT = "%s  %s",
    SI_BPD_NOTIFICATION_EMPTY = "(пустое сообщение)",
    SI_BPD_NOTIFICATION_RESTORED = "получено личное сообщение",
    SI_BPD_OVERFLOW_SENDERS = "+%d отправителей",
    SI_BPD_UNREAD_COUNT = "x%d",
    SI_BPD_UNREAD_COUNT_OVERFLOW = "x%d+",
    SI_BPD_TOOLTIP_OVERFLOW = "ЛКМ: следующие отправители. ПКМ: вернуть последнее скрытое.",

    -- Relative timestamps
    SI_BPD_TIME_NOW = "сейчас",
    SI_BPD_TIME_SECONDS = "%dс",
    SI_BPD_TIME_MINUTES = "%dм",
    SI_BPD_TIME_HOURS = "%dч",

    -- Mouse tooltips
    SI_BPD_TOOLTIP_DISMISS = "Скрыть уведомление",
    SI_BPD_TOOLTIP_CLEAR_ALL = "Скрыть все уведомления",
    SI_BPD_TOOLTIP_COLLAPSE = "Свернуть или развернуть панель",
    SI_BPD_TOOLTIP_LOCK = "Зафиксировать панель",
    SI_BPD_TOOLTIP_UNLOCK = "Разрешить перемещение",
    SI_BPD_TOOLTIP_RELATION_GROUP = "Группа",
    SI_BPD_TOOLTIP_RELATION_FRIEND = "Друг",
    SI_BPD_TOOLTIP_RELATION_GUILD = "Гильдия",
    SI_BPD_TOOLTIP_STATUS_UNREAD = "%d непрочитанных",
    SI_BPD_TOOLTIP_STATUS_READ = "прочитано",
    SI_BPD_TOOLTIP_STATUS_PENDING = "ожидает ответа",
    SI_BPD_TOOLTIP_STATUS_WAITING = "ждёт",
    SI_BPD_TOOLTIP_STATUS_OVERDUE = "просрочено",
    SI_BPD_TOOLTIP_STATUS_ANSWERED = "отвечено",
    SI_BPD_TOOLTIP_STATUS_COMPOSING = "ответ",
    SI_BPD_TOOLTIP_PLACEHOLDER = "Текст не сохранялся. Он мог остаться в чате или истории pChat.",
    SI_BPD_TOOLTIP_GESTURES = "Действия",
    SI_BPD_TOOLTIP_GESTURE_REPLY = "Ответить · ЛКМ",
    SI_BPD_TOOLTIP_GESTURE_OPEN = "Открыть чат · Shift+ЛКМ",
    SI_BPD_TOOLTIP_GESTURE_READ = "Прочитано · Средняя",
    SI_BPD_TOOLTIP_GESTURE_HIDE = "Скрыть · ПКМ",
    SI_BPD_TOOLTIP_GESTURE_MAIL = "Почта · Ctrl+ЛКМ",
    SI_BPD_TOOLTIP_GESTURE_JUMP = "Телепорт · Ctrl+Shift+ЛКМ",
    SI_BPD_TOOLTIP_GESTURE_IGNORE = "В игнор · Ctrl+Alt+ПКМ",
    SI_BPD_IGNORE_TITLE = "Игнорировать отправителя",
    SI_BPD_IGNORE_BODY = "Игнорировать <<1>> и скрыть это уведомление?",

    -- Test notification payload
    SI_BPD_TEST_MESSAGE = "Тестовое личное сообщение номер %d от отправителя %d",

    -- Slash command help
    SI_BPD_HELP_TITLE = "|cC5C29EКоманды Bureau of Private Dispatches:|r",
    SI_BPD_HELP_CLEAR = "|cFFFFFF/bpd clear|r - скрыть все уведомления.",
    SI_BPD_HELP_TOGGLE = "|cFFFFFF/bpd toggle|r - свернуть или развернуть панель.",
    SI_BPD_HELP_RESET = "|cFFFFFF/bpd reset|r - вернуть область в исходную позицию.",
    SI_BPD_HELP_MUTE = "|cFFFFFF/bpd mute|r - выключить или включить звуки.",
    SI_BPD_HELP_DND = "|cFFFFFF/bpd dnd|r - режим «не беспокоить» на пять минут.",
    SI_BPD_HELP_SCALE = "|cFFFFFF/bpd scale [0.85-1.5]|r - показать или задать масштаб.",
    SI_BPD_HELP_OPACITY = "|cFFFFFF/bpd opacity [0.4-1]|r - показать или задать прозрачность фона.",
    SI_BPD_HELP_AUTOCOLLAPSE = "|cFFFFFF/bpd autocollapse|r - сворачивать панель в бою.",
    SI_BPD_HELP_SETTINGS = "|cFFFFFF/bpd settings|r - открыть панель настроек.",
    SI_BPD_HELP_DEBUG = "|cFFFFFF/bpd debug|r - показать диагностические команды.",

    SI_BPD_PANEL_NAME = "Bureau of Private Dispatches",
    SI_BPD_PANEL_DISPLAY_NAME = "|c6FCB9FBureau|r of Private Dispatches",
    SI_BPD_PANEL_INTRO = "|c6FCB9FКомпактные уведомления о шёпотах,|r чтобы личное сообщение не потерялось в занятом чате. Bureau of Private Dispatches держит одну карточку на отправителя, следит, ответили ли вы, и восстанавливает неотвеченные шёпоты после /reloadui.",
    SI_BPD_PANEL_OVERVIEW = "|c8C8A82• Одна карточка на @id, с непрочитанными и статусом ответа\n• Звук входящего, mute и удержание в бою / «не беспокоить»\n• Неотвеченные шёпоты переживают /reloadui без текста сообщения\n• По желанию превью из pChat после восстановления|r",
    SI_BPD_SLASH_HINT = "|cC5C29EБыстрые команды|r: |cFFFFFF/bpd|r  |cC5C29E•|r  |cFFFFFF/bpd settings|r  |cC5C29E•|r  |cFFFFFF/bpdsettings|r  |cC5C29E•|r  |cFFFFFF/bpd mute|r",

    SI_BPD_STATUS_TITLE = "|cC5C29EТекущее состояние|r",
    SI_BPD_STATUS_ON = "вкл",
    SI_BPD_STATUS_OFF = "выкл",
    SI_BPD_STATUS_LABEL_SOUNDS = "Звуки:",
    SI_BPD_STATUS_LABEL_DND = "Не беспокоить:",
    SI_BPD_STATUS_LABEL_AUTO_DND = "Авто-DND в бою:",
    SI_BPD_STATUS_LABEL_LOCK = "Замок панели:",
    SI_BPD_STATUS_LABEL_AUTOCOLLAPSE = "Сворачивание в бою:",
    SI_BPD_STATUS_LABEL_PCHAT = "Превью pChat:",

    SI_BPD_HEADER_SOUND = "|cC5C29EЗвук|r",
    SI_BPD_SECTION_SOUND_DESCRIPTION = "|c8C8A82Входящие шёпоты дают короткий звук отдельно от напоминания о просрочке. Mute глушит оба. Карточки по-прежнему собираются, пока сигналы удерживаются.|r",
    SI_BPD_SETTINGS_MUTE = "Выключить все звуки",
    SI_BPD_SETTINGS_MUTE_TT = "Отключает звук входящего шёпота и напоминание о просроченном ответе.",
    SI_BPD_SETTINGS_INCOMING_SOUND = "Звук входящего шёпота",
    SI_BPD_SETTINGS_INCOMING_SOUND_TT = "Короткий звук при новом шёпоте. Всё равно удерживается при mute или DND.",
    SI_BPD_SETTINGS_OVERDUE_SOUND = "Звук просроченного ответа",
    SI_BPD_SETTINGS_OVERDUE_SOUND_TT = "Одно напоминание, когда отправитель становится просроченным. Удерживается при mute или DND.",

    SI_BPD_HEADER_DND = "|cC5C29EНе беспокоить|r",
    SI_BPD_SECTION_DND_DESCRIPTION = "|c8C8A82Удерживать пульсы и звуки, пока вы заняты. Пятиминутный DND включается через /bpd dnd или клавишу и не сохраняется. |r|c6FCB9FАвто-DND в бою включён по умолчанию.|r",
    SI_BPD_SETTINGS_AUTO_DND = "Авто-DND в бою",
    SI_BPD_SETTINGS_AUTO_DND_TT = "В бою удерживать пульсы и звуки. Карточки по-прежнему собираются.",

    SI_BPD_HEADER_PANEL = "|cC5C29EПанель|r",
    SI_BPD_SECTION_PANEL_DESCRIPTION = "|c8C8A82Положение, масштаб и затемнение стопки уведомлений. Прозрачность меняет только фон: текст, глифы и рельсы остаются непрозрачными. |r|cD0905EСворачивание в бою по умолчанию выключено.|r",
    SI_BPD_SETTINGS_LOCK = "Зафиксировать позицию",
    SI_BPD_SETTINGS_LOCK_TT = "Запретить перетаскивание за заголовок. Клавиша блокировки делает то же.",
    SI_BPD_SETTINGS_SCALE = "Масштаб панели",
    SI_BPD_SETTINGS_SCALE_TT = "Изменить размер всей панели уведомлений.",
    SI_BPD_SETTINGS_OPACITY = "Прозрачность фона",
    SI_BPD_SETTINGS_OPACITY_TT = "Тускнеет только фон. Текст, глифы и рельсы остаются непрозрачными.",
    SI_BPD_SETTINGS_VISIBLE_SENDERS = "Видимых уведомлений",
    SI_BPD_SETTINGS_VISIBLE_SENDERS_TT = "Показывать 6, 8 или 12 отправителей одновременно. Остальные продолжают отслеживаться и доступны через строку дополнительных отправителей.",
    SI_BPD_SETTINGS_AUTOCOLLAPSE = "Сворачивать в бою",
    SI_BPD_SETTINGS_AUTOCOLLAPSE_TT = "Прятать карточки в бою, не подменяя DND. Если развернуть шапку во время боя, панель останется открытой до конца боя.",
    SI_BPD_SETTINGS_RESET_POSITION = "Сбросить позицию",
    SI_BPD_SETTINGS_RESET_POSITION_TT = "Вернуть панель на место по умолчанию и сохранить его.",

    SI_BPD_HEADER_FOLLOWUP = "|cC5C29EТаймеры ответа|r",
    SI_BPD_SECTION_FOLLOWUP_DESCRIPTION = "|c8C8A82Неотвеченный шёпот сначала ждёт, затем становится просроченным для одного напоминания. Открытие ответа даёт короткую паузу, пока вы печатаете. Подтверждённый ответ ненадолго остаётся на экране, после чего карточка снимается.|r",
    SI_BPD_SETTINGS_FOLLOWUP_WAITING = "Ожидание через (сек.)",
    SI_BPD_SETTINGS_FOLLOWUP_WAITING_TT = "Сколько неотвеченный шёпот остаётся в ожидании до маркера «ждёт».",
    SI_BPD_SETTINGS_FOLLOWUP_OVERDUE = "Просрочка через (сек.)",
    SI_BPD_SETTINGS_FOLLOWUP_OVERDUE_TT = "Когда срабатывает одно напоминание. Всегда позже таймера ожидания.",
    SI_BPD_SETTINGS_FOLLOWUP_GRACE = "Пауза на набор (сек.)",
    SI_BPD_SETTINGS_FOLLOWUP_GRACE_TT = "Открытие ответа откладывает напоминание, пока вы печатаете.",
    SI_BPD_SETTINGS_FOLLOWUP_ANSWERED = "Карточка «отвечено» (сек.)",
    SI_BPD_SETTINGS_FOLLOWUP_ANSWERED_TT = "Сколько подтверждённый ответ остаётся на экране, прежде чем карточка исчезнет.",

    SI_BPD_HEADER_RESTORE = "|cC5C29EВосстановление|r",
    SI_BPD_SECTION_RESTORE_DESCRIPTION = "|c8C8A82Неотвеченные карточки переживают /reloadui без текста сообщения. Если pChat загружен, совпадающий входящий шёпот может заполнить превью из его истории в памяти. |r|c6FCB9FВключено по умолчанию, когда pChat есть.|r",
    SI_BPD_SETTINGS_PCHAT_PREVIEW = "Подставлять превью из pChat",
    SI_BPD_SETTINGS_PCHAT_PREVIEW_TT = "Если pChat загружен, после reload взять совпадающий входящий шёпот из его истории в памяти. Текст этим аддоном не сохраняется.",

    SI_BPD_HEADER_NOTES = "|cC5C29EЖесты, отношения и клавиши|r",
    SI_BPD_SECTION_GESTURES_DESCRIPTION = "|c8C8A82Ответить · ЛКМ\nОткрыть чат · Shift+ЛКМ\nПрочитано · Средняя\nСкрыть · ПКМ\nПочта · Ctrl+ЛКМ\nТелепорт · Ctrl+Shift+ЛКМ\nВ игнор · Ctrl+Alt+ПКМ\nЖесты перечислены в подсказке карточки и здесь не переназначаются.|r",
    SI_BPD_SECTION_BADGES_DESCRIPTION = "|c8C8A82Группа, друзья и гильдия указаны в подсказке карточки. В строке остаются только отправитель, сообщение, непрочитанные, статус ответа и время.|r",
    SI_BPD_SECTION_KEYBINDS_DESCRIPTION = "|c8C8A82Ответ, фокус, прочитано, сворачивание, очистка, mute, DND, возврат и замок назначаются в Управление → Bureau of Private Dispatches.|r",
    SI_BPD_SCALE_SET = "Масштаб панели: %.2f.",
    SI_BPD_OPACITY_SET = "Прозрачность фона: %.2f.",
    SI_BPD_AUTOCOLLAPSE_ON = "Панель сворачивается в бою.",
    SI_BPD_AUTOCOLLAPSE_OFF = "Панель больше не сворачивается в бою.",
    SI_BPD_MUTE_ON = "Звуки выключены.",
    SI_BPD_MUTE_OFF = "Звуки включены.",
    SI_BPD_DND_ON = "Не беспокоить на 5 минут. Карточки по-прежнему собираются.",
    SI_BPD_DND_OFF = "Режим «не беспокоить» снят.",
    SI_BPD_HELP_DEBUG_TITLE = "|cC5C29EДиагностика Bureau of Private Dispatches:|r",
    SI_BPD_HELP_DEBUG_TEST = "|cFFFFFF/bpd debug test|r - обновить одно тестовое уведомление.",
    SI_BPD_HELP_DEBUG_TEST_MANY = "|cFFFFFF/bpd debug testmany|r - создать восемь тестовых отправителей.",
    SI_BPD_HELP_DEBUG_TEST_OVERDUE = "|cFFFFFF/bpd debug testoverdue|r - вызвать тестовое напоминание об ответе.",
    SI_BPD_HELP_DEBUG_TEST_REPLY = "|cFFFFFF/bpd debug testreply|r - отметить тестового отправителя отвеченным.",
    SI_BPD_HELP_DEBUG_READ = "|cFFFFFF/bpd debug read|r - отметить тестового отправителя прочитанным.",
    SI_BPD_HELP_DEBUG_RESTORE = "|cFFFFFF/bpd debug restore|r - вернуть последнее скрытое уведомление.",

    SI_BPD_KEYBIND_CATEGORY = "Bureau of Private Dispatches",
    SI_BINDING_NAME_BPD_REPLY = "Ответить сфокусированному / последнему",
    SI_BINDING_NAME_BPD_FOCUS_NEXT = "Следующий отправитель",
    SI_BINDING_NAME_BPD_FOCUS_PREV = "Предыдущий отправитель",
    SI_BINDING_NAME_BPD_MARK_READ = "Отметить сфокусированного прочитанным",
    SI_BINDING_NAME_BPD_TOGGLE = "Свернуть или развернуть панель",
    SI_BINDING_NAME_BPD_CLEAR = "Скрыть все видимые уведомления",
    SI_BINDING_NAME_BPD_MUTE = "Выключить или включить звуки",
    SI_BINDING_NAME_BPD_DND = "Режим «не беспокоить»",
    SI_BINDING_NAME_BPD_RESTORE = "Вернуть последнее скрытое",
    SI_BINDING_NAME_BPD_LOCK = "Заблокировать или разблокировать панель",
}

for stringName, value in pairs(strings) do
    local stringId = _G[stringName]
    if type(stringId) == "number" then
        SafeAddString(stringId, value, 1)
    end
end
