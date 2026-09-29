Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework успешно загружен",
  CRITICAL_ERROR = "КРИТИЧЕСКАЯ ОШИБКА: Не удалось создать панель настроек!",
  ERROR_REGISTERING = "ОШИБКА при регистрации настроек",
  LAM2_UNAVAILABLE = "LibAddonMenu2 недоступен!",
  ALREADY_INITIALIZED = "Уже инициализировано, пропуск...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton недоступен - кнопки чата отключены",
  HEADER_DESC = "Основной фреймворк для Scrollkeeper Guild Tools с расширенными интеграциями библиотек. Отдельные модули имеют свои настройки и не требуют перезагрузки.",
  DONATE_BUTTON = "Поддержать Разработку",
  DONATE_TOOLTIP = "Отправить пожертвование @WolfStar07 на PC/NA для поддержки дальнейшей разработки",
  OPEN_ALL_WINDOWS = "Открыть Все Окна Scrollkeeper",
  OPEN_SETTINGS = "Открыть Настройки Scrollkeeper",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Цветовые Темы",
  DESCRIPTION = "Выберите из предопределённых цветовых тем для элементов интерфейса Scrollkeeper.",
  ACTIVE_THEME = "Активная Тема",
  ACTIVE_THEME_TOOLTIP = "Выберите, какую цветовую тему применить к элементам интерфейса Scrollkeeper.",
  CURRENT_THEME = "Текущая тема: %s",
  
  -- Preview Section
  PREVIEW_HEADER = "Предпросмотр Цветов:",
  BORDER_COLOR = "Цвет Границы",
  BORDER_DESC = "Границы и края окон",
  HEADER_COLOR = "Цвет Заголовка",
  HEADER_DESC = "Строки заголовка и заголовки столбцов",
  TEXT_COLOR = "Цвет Текста", 
  TEXT_DESC = "Основной текст и метки",
  ACCENT_COLOR = "Акцентный Цвет",
  ACCENT_DESC = "Выделенные кнопки и выделения",
  NOTE = "Примечание: Изменения темы применяются немедленно ко всем открытым окнам Scrollkeeper.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  
  -- Theme Names
  THEME_EMBER = "Угли",
  THEME_FORGE = "Кузница",
  THEME_OCEAN = "Океан",
  THEME_SKY = "Небо",
  THEME_REGALIA = "Регалия",
  THEME_BRIAR = "Шиповник",
  THEME_JUNGLE = "Джунгли",
  
  -- Status Messages
  STATUS_UNKNOWN = "Неизвестно",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Отслеживание Временных Членов",
  DESCRIPTION = "Отслеживайте членов гильдии в испытательных рангах и тех, кто не выполнил требования по пожертвованиям. Используйте |cFFD700/sgtprovision|r для открытия окна управления.",
  MASTER_ENABLE = "Включить Отслеживание Временных Членов (Мастер)",
  MASTER_ENABLE_TIP = "Главный переключатель для всех функций отслеживания временных членов.",
  OPEN_ADMIN = "Открыть Окно Администрирования",
  OPEN_ADMIN_TIP = "Открыть окно управления временными членами",
  CLEAR_SCAN = "Очистить Неверные Данные и Сканировать",
  CLEAR_SCAN_TIP = "Очистить неправильно отслеживаемых членов и сканировать для новых",
  RESET_GOLD = "Сбросить Удаления по Золоту",
  RESET_GOLD_TIP = "Очистить все флаги удаления на основе золота, позволяя повторно оценивать членов для отслеживания золота",
  STATUS_TRACKING = "Сейчас отслеживается: %d активных временных членов",
  STATUS_RANK_REMOVED = "Удалено навсегда (ранг): %d членов",
  STATUS_GOLD_REMOVED = "Удалено временно (золото): %d членов",
  WINDOW_OPENED_MESSAGE = "Окно открыто. Используйте кнопку |cFFFFFFСканировать|r для проверки членов, требующих отслеживания.",
    
  -- Window UI
  WINDOW_TITLE = "Управление Временными Членами",
  SELECT_GUILD = "Выбрать Гильдию:",
  FILTER_LABEL = "Фильтр:",
  MEMBER_NAME = "Имя Члена",
  DAYS = "Дни",
  STATUS = "Статус Отслеживания",
  NOTES = "Заметки",
  ACTIONS = "Действия",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "Включить для %s",
  ENABLE_FOR_GUILD_TIP = "Включить отслеживание временных членов для этой гильдии.",
  AUTO_TAG = "Автоматически Помечать Новых Членов",
  AUTO_TAG_TIP = "Автоматически помечать членов, соответствующих критериям отслеживания.",
  NOTIFY_JOIN = "Уведомлять о Присоединении Членов",
  NOTIFY_JOIN_TIP = "Показывать уведомления для новых членов в этой гильдии.",
  PROBATION_DAYS = "Испытательный Период (Дни)",
  PROBATION_DAYS_TIP = "Сколько дней члены остаются в испытательном статусе перед повышением.",
    
  -- Gold Tracking
  GOLD_HEADER = "Отслеживание Требований к Золоту",
  INACTIVITY_HEADER = "Отслеживание Неактивности",
  DONOR_HEADER = "Признание Жертвователей",
  GOLD_ENABLE = "Включить Фильтр Пожертвований Золота",
  GOLD_ENABLE_TIP = "Отслеживать членов, которые не выполнили требования по пожертвованиям.",
  GOLD_AMOUNT = "Требуемая Сумма Пожертвования",
  GOLD_AMOUNT_TIP = "Количество золота, которое члены должны пожертвовать в течение периода времени (например, 5000 для взносов 5k).",
  GOLD_PERIOD = "Период Времени (Дни)",
  GOLD_PERIOD_TIP = "Количество дней для проверки пожертвований (например, 30 для ежемесячных взносов, 7 для еженедельных).",
  STATUS_PENDING_DONATION = "Ожидается Пожертвование",
  SOURCE_MANUAL = "Вручную",
  TIP_DAYS_MANUAL = "^ = Включает записи ручных пожертвований",
    
  -- Statistics
  GUILD_STATS = "Статистика Гильдии",
  NO_MEMBERS = "В настоящее время нет отслеживаемых временных членов для этой гильдии",
  STATS_FORMAT = "Отслеживание %d членов: %d активных, %d просроченных, %d повышенных",
  RECENT_ADDITIONS = "Недавние добавления (последние 7 дней): %d",
  
  -- Integration Status
  INTEGRATION_HEADER = "Источники Данных Времени Присоединения и Интеграция",
  AMT_AVAILABLE = "Advanced Member Tooltip - Самое точное время присоединения доступно",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - Не установлен",
  AMT_INSTALL = "Установить из: esoui.com/downloads/info2351",
  AMT_DESC = "Обеспечивает наиболее точное отслеживание времени присоединения к гильдии",
  LH_READY = "LibHistoire - Готов и обрабатывает историю гильдии",
  LH_MISSING = "LibHistoire - Не найден (требуемая зависимость)",
  DATA_AVAILABLE = "Модуль Данных - Отслеживание пожертвований золота включено",
  DATA_UNAVAILABLE = "Модуль Данных - Фильтрация золота недоступна",
    
  -- Symbol Legend
  SYMBOL_LEGEND = "Символы в Столбце Дней:",
  SYMBOL_AMT = "* = Данные AMT (самые точные)",
  SYMBOL_HISTOIRE = "~ = История гильдии LibHistoire",
  SYMBOL_DONATION = "? = Оценка первого пожертвования",
  SYMBOL_TAGGED = "! = Время начала отслеживания",
  SYMBOL_VALIDATED = "(без символа) = Проверенные сохранённые данные",
  SYMBOL_UNKNOWN = "НЕИЗВ = Неизвестный/ненадёжный источник",
  SYMBOL_FOOTER = "Наведите курсор на любое значение дней для подробной информации об источнике.",
  TIP_SORT_NAME = "Нажмите для сортировки по имени",
  TIP_SORT_DAYS = "Нажмите для сортировки по дням с момента присоединения",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] ОШИБКА: Фреймворк отсутствует!",
  ERROR_NO_GUILD_SELECTED = "Гильдия не выбрана",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail недоступен",
  ERROR_NO_MEMBERS_TO_MAIL = "Нет членов для отправки почты",
  ERROR_MAIL_WINDOW_FAILED = "Не удалось получить доступ к окну почты",
  ERROR_SETTINGS_UNAVAILABLE = "Настройки недоступны",
  ERROR_NO_GUILDS = "Гильдии недоступны. Присоединитесь к гильдии для настройки параметров для каждой гильдии.",
   
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip обнаружен - расширенное отслеживание включено",
  SUCCESS_HISTOIRE_READY = "Интеграция LibHistoire готова - точное время присоединения доступно",
  SUCCESS_REMOVED = "%s удалён из отслеживания",
  SUCCESS_BULK_REMOVED = "%d членов массово удалены из отслеживания",
  SUCCESS_CLEARED_DATA = "Данные отслеживания очищены для %s",
  SUCCESS_CLEARED_GOLD = "%d флагов удаления на основе золота очищено",
  SUCCESS_MAIL_OPENED = "Окно почты открыто с %d временными членами из %s",
  
  -- Status Messages
  STATUS_DISABLED = "Временное отслеживание отключено",
  STATUS_NO_DATA = "Данные недоступны",
  STATUS_NO_TRACKING = "Данные отслеживания недоступны",
  STATUS_SELECT_GUILD = "Выберите гильдию для просмотра статистики",
  STATUS_NO_FILTER_MATCH = "Нет членов, соответствующих текущим критериям фильтра.",
  STATUS_NO_SELECTED = "Нет выбранных членов для повышения",
  STATUS_NO_SELECTED_REMOVE = "Нет выбранных членов для удаления",
  
  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Зеленый: Информация о пожертвованиях",
  NOTES_COLOR_OFFLINE = "Оранжевый: Информация об отключении",
  NOTES_COLOR_NO_DONATION = "Красный: Пожертвования не найдены",
  
  -- Button Labels
  BTN_REFRESH = "Обновить",
  BTN_REFRESH_TIP = "Обновить данные гильдии и список членов",
  BTN_EXPORT = "Экспорт",
  BTN_EXPORT_TIP = "Экспортировать данные членов в копируемое текстовое окно",
  BTN_SCAN = "Сканировать",
  BTN_SCAN_TIP = "Сканировать списки гильдий для новых временных членов",
  BTN_VIEW_SELECTED = "Просмотр Выбранных",
  BTN_VIEW_ALL = "Просмотр Всех",
  BTN_VIEW_SELECTED_TIP = "Переключение между просмотром всех членов и только выбранных",
  BTN_PROMOTE_ALL = "Повысить Всех",
  BTN_PROMOTE_ALL_TIP = "Открыть список гильдии для повышения выделенных членов.",
  BTN_REMOVE_ALL = "Удалить Всех",
  BTN_REMOVE_ALL_TIP = "Удалить всех выбранных членов из отслеживания",
  BTN_MAIL_SELECTED = "Отправить Почту Выбранным",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Открыть окно почты с выбранными членами (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Открыть окно почты с отфильтрованными членами",
  BTN_SELECT_ALL = "Выбрать Всех",
  BTN_CLOSE = "Закрыть",
  
  -- Filter Labels
  FILTER_ALL = "ВСЕ",
  FILTER_PROBATION_ICON_TIP = "Фильтр по испытательным членам",
  FILTER_GOLD_ICON_TIP = "Фильтр по участникам с низкими пожертвованиями золота",
  STATUS_INACTIVE = "Неактивен",
  STATUS_DONOR = "Активный Жертвователь",
  
  -- Export Window
  EXPORT_TITLE = "Экспорт Данных - Выберите и Скопируйте Текст",
  EXPORT_INSTRUCTION = "Нажмите 'Выбрать Всех', затем используйте Ctrl+C для копирования в буфер обмена",
  EXPORT_REPORT_HEADER = "Отчёт о Временных Членах для %s",
  EXPORT_GENERATED = "Создано: %s",
  EXPORT_FILTER = "Фильтр: %s",
  EXPORT_VIEW_SELECTED = "Вид: Только Выбранные Члены",
  EXPORT_FILTER_ALL = "Все Члены",
  EXPORT_FILTER_RANK = "Испытательные Члены",
  EXPORT_FILTER_GOLD = "Члены с Пожертвованиями Золота",
  EXPORT_FILTER_CUSTOM = "Отфильтрованные Члены",
  EXPORT_FORMAT = "%s | Статус: %s | Дней в гильдии: %s | Причина: %s | Заметки: %s",
  EXPORT_DAYS_NA = "Н/Д (фильтр золота)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "фактический",
  EXPORT_DAYS_ESTIMATED = "расчётный",
  EXPORT_FILTER_INACTIVE = "Неактивные Участники",
  EXPORT_FILTER_DONOR = "Активные Жертвователи",
  
  -- Tooltips
  TIP_OPEN_ROSTER = "Открыть список гильдии для %s",
  TIP_REMOVE = "Удалить %s из отслеживания",
  TIP_DAYS_HEADER = "Дней с момента присоединения к гильдии\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Дней Не в Сети",
  TIP_DAYS_OFFLINE_DESC = "Показывает, сколько дней этот участник был не в сети.\nБольшие числа указывают на более длительную неактивность.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (самый точный)",
  TIP_DAYS_HISTOIRE = "~ = История гильдии LibHistoire",
  TIP_DAYS_DONATION = "? = Оценка первого пожертвования",
  TIP_DAYS_TAGGED = "! = Время начала отслеживания",
  TIP_DAYS_UNKNOWN = "(Неизвестно - нет надёжного источника данных)",
  TIP_DAYS_GOLD = "(Член фильтра золота)",
  TIP_DAYS_VALIDATED = "(Проверено из сохранённых данных)",
  TIP_INSTALL_AMT = "Установите Advanced Member Tooltip\nдля более точного времени присоединения",
  TIP_REVIEW_KICK = "Открыть список для проверки/исключения %s (неактивный участник)",
  TIP_REVIEW_PROMOTE = "Открыть список для проверки/исключения %s (участник на испытательном сроке)",
  TIP_REVIEW_DONATION = "Открыть список для проверки %s (ожидающее пожертвование)",
  TIP_PROMOTE_DONOR = "Открыть список для повышения %s (ценный вкладчик)",
  FILTER_INACTIVE_TIP = "Показать участников, которые были не в сети в течение настроенного периода",
  FILTER_DONOR_TIP = "Показать участников, которые соответствуют минимальным требованиям к пожертвованиям",
  
  -- Logging Messages
  LOG_STARTING_SCAN = "Начало ручного сканирования...",
  LOG_SCAN_COMPLETE = "Ручное сканирование завершено - очищено %d неверных записей, найдено %d новых членов",
  LOG_REFRESHED = "Отображение обновлено",
  LOG_NEW_MEMBER = "Новый член присоединился к %s: %s",
  LOG_OPENING_ROSTER_PROMOTE = "Открытие списка для повышения: %s",
  LOG_OPENING_ROSTER_BULK = "Открытие списка - повысить этих %d членов: %s",
  LOG_NO_GUILD_ID = "Не удалось найти ID гильдии для: %s",
  LOG_NO_GUILD_ID_SIMPLE = "Не удалось найти ID гильдии",
  LOG_FILTER_MODE = "Режим %s - %d членов выбрано",
  LOG_INITIALIZING = "Инициализация - %s",
  ERROR_DATA_NOT_READY = "Данные истории гильдии еще не готовы. Подождите немного и попробуйте снова.",
  LOG_SCAN_COMPLETE_SHORT = "Сканирование завершено!",
  
  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Напоминание о Взносах Гильдии - %s",
  MAIL_RECIPIENT_COUNT = "Временные Получатели: %d",
  MAIL_STATUS = "Статус: %d временных членов готовы к отправке почты",
  
  -- Stats Display
  STATS_FORMAT_FULL = "Гильдия: %s | Всего: %d | Активных: %d | Просроченных: %d | Повышенных: %d | Испытание: %d | Золото: %d",
  STATS_LH_READY = "готов",
  STATS_LH_LOADING = "загрузка",
  
  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Автопометка (сканирование)",
  AUTO_TAG_LOGIN = "Автопометка (сканирование входа)",
  AUTO_TAG_ONLINE = "Автопометка (присоединился онлайн)",
  ACTIVE_DONOR = "Активный Жертвователь",
  
  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "Нет гильдий, настроенных для отслеживания",
  
  -- Status Values
  STATUS_PROVISIONAL = "временный",
  STATUS_PROMOTED = "повышенный",
  
  -- Reason Values
  REASON_RANK = "ранг",
  REASON_GOLD = "золото",
  REASON_INACTIVE = "Неактивен",
  REASON_DONOR = "Жертвователь",
  
  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Статус интегрированных аддонов и источников данных:",
  
  -- Member Count Status
  MEMBER_COUNT_STATUS = "Статус Подсчёта Членов",
  MEMBER_COUNT_FORMAT = "Сейчас отслеживается: %d активных временных членов\nУдалено навсегда (ранг): %d членов\nУдалено временно (золото): %d членов",
  
  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "пожертвование",
  SOURCE_TAGGED = "помеченный",
  SOURCE_STORED = "сохранённый",
  SOURCE_UNKNOWN = "неизвестный",
  SOURCE_DATA = "данные",
  
  -- Days display values
  DAYS_UNKNOWN = "НЕИЗВ",
  DAYS_ERROR = "ОШБ",
  DAYS_NA = "-",
    
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Отслеживать Неактивных Участников",
  INACTIVITY_ENABLE_TIP = "Автоматически отслеживать участников, которые были не в сети в течение длительного периода",
  INACTIVITY_DAYS = "Неактивен После (Дней)",
  INACTIVITY_DAYS_TIP = "Считать участника неактивным, если он не входил в систему столько дней",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "Отслеживать Активных Жертвователей",
  DONOR_ENABLE_TIP = "Отслеживать участников, которые соответствуют или превышают минимальные требования к пожертвованиям (полезно для признания вкладчиков)",
  DONOR_AMOUNT = "Минимальная Сумма Пожертвования",
  DONOR_AMOUNT_TIP = "Количество золота, необходимое для того, чтобы считаться активным жертвователем",
  DONOR_PERIOD = "Период Времени (Дней)",
  DONOR_PERIOD_TIP = "Проверять пожертвования за последние X дней",
  MANUAL_SCAN_NOTE = "Примечание: Отслеживание участников требует ручного сканирования. Откройте окно Временных Участников и нажмите кнопку Сканировать, чтобы проверить участников, нуждающихся в отслеживании.",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Почта Гильдии",
  DESCRIPTION = "Массовое составление почты с интеграцией шаблонов. Отправка почты автоматически ограничена до 3,1 секунды между сообщениями. Используйте |cFFD700/sgtmail|r для открытия окна почты.",
  ENABLE_MAIL = "Включить Почту Гильдии",
  ENABLE_MAIL_TIP = "Включить/отключить функцию Почты Гильдии.",
  OPEN_MAIL = "Открыть Окно Почты",
  OPEN_MAIL_TIP = "Нажмите, чтобы открыть окно составления почты.",
    
  -- Window UI
  WINDOW_TITLE = "Почта Гильдии Scrollkeeper",
  MAIL_TEMPLATES = "Шаблоны Почты:",
  SELECT_TEMPLATE = "-- Выбрать Шаблон --",
  GUILD_LABEL = "Гильдия:",
  RANK_FILTER = "Фильтр Ранга:",
  ALL_RANKS = "Все Ранги",
  PROVISIONAL_LABEL = "Временные Члены:",
  ALL_PROVISIONAL = "Все Временные",
  GOLD_ONLY = "Только Фильтр Золота",
  RANK_ONLY = "Только Фильтр Ранга",
  USE_PROVISIONAL = "Использовать Временный Список",
  KICK_AFTER_MAIL = "Удалить после отправки:",
  KICK_NO = "Не удалять",
  KICK_YES = "Удалить после отправки",
  KICK_NO_PERMISSION = "У вас нет прав на удаление участников из этой гильдии",
  MEMBER_KICKED = "Исключён: %s",
  MEMBER_NOT_FOUND = "Не удалось найти участника %s в реестре гильдии",
  PREVIEW_TITLE = "Предварительный просмотр письма",
  PREVIEW_MAIL = "Просмотр",
    
  -- Composition
  SUBJECT_LABEL = "Тема:",
  BODY_LABEL = "Тело Сообщения:",
  READY_TO_SEND = "Готово к отправке",
  STATUS_READY = "Статус: Готово",
  RECIPIENTS = "Получатели: %d",
    
  -- Buttons
  SAVE_TEMPLATE = "Сохранить Шаблон",
  PREVIEW_RECIPIENTS = "Предпросмотр Получателей",
  SEND_MAIL = "Отправить Почту",
  PAUSE = "Пауза",
  RESUME = "Продолжить",
    
  -- Status Messages
  NO_GUILD = "Статус: Сначала выберите гильдию",
  NO_SUBJECT = "Статус: Введите тему",
  NO_BODY = "Статус: Введите тело сообщения",
  NO_RECIPIENTS = "Статус: Получатели не найдены",
  STARTING = "Статус: Начало отправки почты...",
  SENDING = "Отправка %d/%d",
  SENDING_TO = "Кому: %s",
  SUCCESS = "Статус: Почта успешно отправлена",
  FAILED = "Статус: Неудача - %s",
  PAUSED = "Статус: Приостановлено",
  COMPLETED = "Завершено: %d отправлено, %d неудач",
  TEMPLATE_SAVED = "Статус: Шаблон сохранён",
  TEMPLATE_FAILED = "Статус: Не удалось сохранить шаблон",
  NEED_SUBJECT_BODY = "Статус: Введите тему и тело",
  RECIPIENTS_FOUND = "Статус: %d получателей найдено",
  NO_MATCH_FILTERS = "Статус: Нет получателей, соответствующих фильтрам",
  PROVISIONAL_SELECTED = "Статус: %d временных членов выбрано",
  NO_PROVISIONAL = "Статус: Временные члены не найдены",
  USING_PROVISIONAL = "Статус: Использование списка временных членов...",
    
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Получатель не найден",
  MAILBOX_FULL = "Почтовый ящик заполнен",
  IGNORED = "Получатель игнорирует почту",
  BLANK_MAIL = "Пустая почта не разрешена",
  UNKNOWN_ERROR = "Неизвестная ошибка",
  
  -- Character count display
  CHAR_COUNT = "%d/%d",
  
  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "все",
  PROVISION_FILTER_GOLD = "золото", 
  PROVISION_FILTER_RANK = "ранг",
  
  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Напоминание о Взносах Гильдии - %s",
  
  -- Failure log content
  FAILURE_LOG_TITLE = "Отчёт о Неудаче Отправки Почты",
  FAILURE_LOG_DATE = "Дата: %s",
  FAILURE_LOG_SUBJECT_LINE = "Тема: %s",
  FAILURE_LOG_TOTAL_SENT = "Всего Отправлено: %d",
  FAILURE_LOG_TOTAL_FAILED = "Всего Неудач: %d",
  FAILURE_LOG_FAILED_LIST = "Неудачные Получатели:",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Исходное Тело Сообщения:",
  FAILURE_LOG_SAVED = "Журнал неудач сохранён в Блокноте: '%s'",
  FAILURE_LOG_SAVE_FAILED = "Не удалось сохранить журнал неудач в Блокноте",
  FAILURE_LOG_NO_NOTEBOOK = "Невозможно сохранить журнал неудач - Блокнот недоступен",
  
  -- Mail tags
  TAG_MAIL = "почта",
  TAG_TEMPLATE = "шаблон",
  TAG_MAIL_LOG = "лог-почты",
  TAG_FAILURES = "ошибки",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "Ошибки отправки почты - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Настройки Блокнота",
  WINDOW_TITLE = "Блокнот Scrollkeeper",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Уже инициализировано, пропуск...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r Окно уже существует, возврат существующего",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Предупреждение: Не удалось создать выпадающее меню",
  ERROR_WINDOW_NOT_INIT = "Окно блокнота не инициализировано.",
  ERROR_NO_NOTE_ENTRY = "Нет записи заметки для %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r Блокнот отключён",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Введите заголовок для заметки",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Не удалось сохранить заметку",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Введите заголовок для шаблона",
    
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Заметка сохранена: %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Шаблон почты сохранён: %s",
    
  -- Window Labels
  LABEL_SEARCH = "Поиск:",
  LABEL_CATEGORY = "Категория:",
  LABEL_SAVED_NOTES = "Сохранённые Заметки:",
  LABEL_NOTE_TITLE = "Заголовок Заметки:",
  LABEL_TAGS = "Теги (через запятую):",
  LABEL_NOTE_CONTENT = "Содержимое Заметки:",
  LABEL_NOTES_COUNT = "Заметки: %d/%d",
  LABEL_NOTES_SIMPLE = "Заметки: %d",
    
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
    
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Выбрать Заметку --",
  DROPDOWN_NO_MATCHES = "-- Совпадений не найдено --",
    
  -- Default Text
  DEFAULT_NOTE_TITLE = "Новая Заметка",
  DEFAULT_NOTE_BODY = "Введите вашу заметку здесь...",
    
  -- Button Labels
  BTN_SAVE = "Сохранить",
  BTN_NEW = "Новая",
  BTN_DELETE = "Удалить",
  BTN_SAVE_MAIL = "Сохранить Почту",
  BTN_OPEN_NOTEBOOK = "Открыть Блокнот",
    
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Нажмите, чтобы открыть окно блокнота (как команда /sgtnote).",
    
  -- Settings
  SETTING_ENABLE = "Включить Модуль Блокнота",
  SETTING_ENABLE_TIP = "Включить/отключить функцию Блокнота.",
  SETTING_SEARCH = "Включить Фильтр Поиска",
  SETTING_SEARCH_TIP = "Разрешить фильтрацию заметок по поисковым терминам.",
  SETTING_DEFAULT_CATEGORY = "Категория по Умолчанию",
  SETTING_DEFAULT_CATEGORY_TIP = "Категория по умолчанию для новых заметок. Используйте 'Почта' для шаблонов почты.",
    
  -- Descriptions
  DESC_MAIN = "Полнофункциональный внутриигровой блокнот с поиском, категориями и тегами. Используйте |cFFD700/sgtnote|r для открытия окна блокнота.",
  DESC_MAIL_TEMPLATES = "Шаблоны почты: Сохраняйте заметки в категории 'Почта', чтобы использовать их как шаблоны как в родном почтовом клиенте, так и в системе почты гильдии.",
    
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Шаблоны Почты:",
  MAIL_DROPDOWN_SELECT = "-- Выбрать Шаблон --",
    
  -- Categories
  CAT_GENERAL = "Общее",
  CAT_MAIL = "Почта",
  CAT_EVENTS = "События",
  CAT_ALL_CATEGORIES = "Все Категории",

  ERROR_MAX_TOTAL_NOTES = "Невозможно создать заметку: Достигнуто максимальное общее количество заметок (%d). Сначала удалите некоторые заметки.",
  ERROR_MAX_CATEGORY_NOTES = "Невозможно создать заметку: Достигнуто максимальное количество заметок (%d) для категории '%s'.",
  ERROR_NOTE_TOO_LARGE = "Заметка слишком большая (%d символов). Максимум %d символов.",
  STATS_HEADER = "Статистика Хранилища Записной Книжки Scrollkeeper",
  STATS_TOTAL = "Всего Заметок: %d / %d",
  STATS_CATEGORY = " %s: %d / %d заметок (~%.1f КБ)",
  BTN_PREVIEW_MAIL = "Просмотр",
  PREVIEW_TITLE = "Предварительный просмотр письма",
  ERROR_NO_BODY = "Пожалуйста, введите текст в тело сообщения",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(Используйте «Сохранить как письмо» в Блокноте, чтобы добавить шаблоны)",
  SETTING_GUILDMAIL_INJECT = "Показывать список шаблонов в почте гильдии",
  SETTING_GUILDMAIL_INJECT_TIP = "Отображает список шаблонов писем из Блокнота в окне создания почты гильдии.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Поиск Истории Гильдии",
  WINDOW_TITLE = "Поиск Истории Гильдии",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Не удалось создать окно",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r Нет событий для экспорта",
    
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Готово - используйте /sgthistory",
    
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Загрузка... SF.Data существует: %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents при загрузке: %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents недоступен",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Запущена резервная инициализация",
    
  -- Window Labels
  LABEL_GUILD = "Гильдия:",
  LABEL_CATEGORY = "Категория:",
  LABEL_SEARCH = "Поиск:",
  LABEL_EVENTS_COUNT = "События: %d",
  LABEL_REFRESH = "Обновить",
  LABEL_EXPORT = "Экспорт",
    
  -- Status Messages
  STATUS_READY = "Готово",
  STATUS_READY_LOADED = "Готово - загружено событий: %d",
  STATUS_NO_GUILD = "Гильдия не выбрана",
  STATUS_DATA_NOT_READY = "Модуль данных не готов",
  STATUS_NO_EVENTS_CACHE = "События не найдены - кэш может всё ещё строиться. Убедитесь, что категория активна в LibHistoire.",
  STATUS_WAITING_LH = "Ожидание инициализации LibHistoire...",
  STATUS_ENABLE_GUILDS = "Включите гильдии в настройках Истории",
    
  -- Column Headers
  HEADER_TIME = "Время",
  HEADER_CATEGORY = "Категория",
  HEADER_EVENT = "Событие",
  HEADER_MEMBER = "Член",
  HEADER_DETAILS = "Детали",
    
  -- Category Names
  CAT_ALL = "Все События",
  CAT_ROSTER = "Список",
  CAT_BANK_GOLD = "Золото Банка",
  CAT_BANK_ITEMS = "Предметы Банка",
  CAT_SALES = "Продажи",
    
  -- Event Type Names - Roster
  EVENT_INVITED = "Приглашён",
  EVENT_JOINED = "Присоединился",
  EVENT_PROMOTED = "Повышен",
  EVENT_DEMOTED = "Понижен",
  EVENT_LEFT = "Покинул",
  EVENT_KICKED = "Исключён",
  EVENT_APP_ACCEPTED = "Заявка Принята",
    
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Золото Внесено",
  EVENT_GOLD_WITHDRAWN = "Золото Снято",
  EVENT_TRADER_BID = "Ставка Торговца",
  EVENT_BID_RETURNED = "Ставка Возвращена",
    
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Предмет Внесён",
  EVENT_ITEM_WITHDRAWN = "Предмет Снят",
    
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Предмет Продан",
    
  -- Unknown Event
  EVENT_UNKNOWN = "Неизвестно (%s)",
    
  -- Time Formatting
  TIME_JUST_NOW = "Только что",
  TIME_MINUTES_AGO = "%dм назад",
  TIME_HOURS_AGO = "%dч назад",
  TIME_DAYS_AGO = "%dд назад",
  TIME_MONTHS_AGO = "%dмес назад",
    
  -- Export Window
  EXPORT_TITLE = "Экспорт Данных - Выберите и Скопируйте Текст",
  EXPORT_INSTRUCTION = "Нажмите 'Выбрать Всех', затем используйте Ctrl+C для копирования в буфер обмена",
  EXPORT_SELECT_ALL = "Выбрать Всех",
  EXPORT_HEADER = "Экспорт Истории Гильдии для %s",
  EXPORT_GENERATED = "Создано: %s",
  EXPORT_CATEGORY = "Категория: %s",
  EXPORT_TOTAL = "Всего Событий: %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
    
  -- Tooltips
  TIP_REFRESH = "Обновить список гильдий и данные событий",
  TIP_EXPORT = "Экспортировать видимые события в текст",
  TIP_FULL_TIMESTAMP = "Полная временная метка",
  TIP_FULL_DETAILS = "Полные детали",
    
  -- Settings - Main
  SETTINGS_DESC = "Поиск кэшированных событий истории гильдии. Используйте |cFFD700/sgthistory|r для открытия окна поиска.\n\nДанные автоматически кэшируются для всех гильдий модулем ScrollkeeperData. Здесь вы контролируете, какие гильдии и категории отображать в окне поиска.",
  SETTINGS_DISPLAY = "Настройки Отображения",
  SETTINGS_MAX_EVENTS = "Максимум Событий",
  SETTINGS_MAX_EVENTS_TIP = "Максимальное количество событий для загрузки за раз",
  SETTINGS_SEARCH_DELAY = "Задержка Поиска (мс)",
  SETTINGS_SEARCH_DELAY_TIP = "Задержка перед выполнением поиска во время набора",
  SETTINGS_COLOR_CODING = "Включить Цветовое Кодирование",
  SETTINGS_COLOR_CODING_TIP = "Кодировать события цветом по типу",
    
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "Показать в Окне Истории",
  SETTINGS_SHOW_GUILD_TIP = "Отображать эту гильдию в окне поиска истории",
  SETTINGS_CATEGORIES = "Категории Событий для Отображения",
  SETTINGS_ROSTER_EVENTS = "События Списка",
  SETTINGS_ROSTER_EVENTS_TIP = "Показать присоединения членов, уходы, повышения, исключения",
  SETTINGS_BANK_GOLD_EVENTS = "События Золота Банка",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Показать внесения золота, снятия, ставки торговца",
  SETTINGS_BANK_ITEMS_EVENTS = "События Предметов Банка",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Показать внесения и снятия предметов",
  SETTINGS_SALES_EVENTS = "События Продаж",
  SETTINGS_SALES_EVENTS_TIP = "Показать продажи магазина гильдии",
    
  -- Dropdown
  DROPDOWN_NO_GUILDS = "Нет включённых гильдий - смотрите настройки",
    
  -- Formatting
  FORMAT_GOLD = "%s золота",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "%s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "Это пожертвование, записанное вручную",
  NOTES_LABEL = "Заметки",
  DELETE_MANUAL_ENTRY = "Удалить эту запись вручную",
  SUCCESS_DELETED_ENTRY = "Запись вручную успешно удалена",
  ERROR_DELETE_FAILED = "Не удалось удалить запись",
    
  -- Member Names
  MEMBER_UNKNOWN = "Неизвестно",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll не найден - используется базовая прокрутка",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Улучшение Списка",
    
  -- Settings
  SETTING_TRADER_TIMER = "Показать Таймер Смены Торговца",
  SETTING_TRADER_TIMER_TIP = "Показать таймер обратного отсчёта, показывающий время до следующей смены торговца гильдии.\n\n" ..
                              "Цвет таймера указывает на срочность:\n" ..
                              "• |c00FF0024+ ч|r - Безопасно\n" ..
                              "• |cFFFF006-24 ч|r - Планировать заранее\n" ..
                              "• |cFF88002-6 ч|r - Действовать скоро\n" ..
                              "• |cFF0000< 2 ч|r - Срочно!",
  
  -- Timer Display
  TIMER_LABEL = "Смена Торговца: %s",
  TIMER_FLIPPING = "Сменяется сейчас",
  TIMER_FORMAT = "%dч %dм",
    
  -- Full tooltip
  TOOLTIP_FULL = "Время до смены торговца гильдии\n\n" ..
                 "Цвет указывает на срочность:\n" ..
                 "|c00FF0024+ часа|r - Безопасно\n" ..
                 "|cFFFF006-24 часа|r - Планировать заранее\n" ..
                 "|cFF88002-6 часов|r - Действовать скоро\n" ..
                 "|cFF0000< 2 часов|r - Срочно!",
				   
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  
  -- Tasks
  TASKS_HEADER = "Напоминания о Задачах",
  TASKS_DESCRIPTION = "Напоминания о задачах настраиваются для каждой гильдии ниже. Включите 'Показывать задачи в реестре' для каждой гильдии, где вы хотите напоминания.",
  CUSTOM_TASKS = "Пользовательские Задачи",
  CUSTOM_TASKS_DESC = "Добавляйте и настраивайте пользовательские задачи. Панель настроек не обновится до перезагрузки, но задача будет добавлена или удалена в реальном времени.",
  ADD_CUSTOM_TASK = "Добавить Пользовательскую Задачу",
  REMOVE = "Удалить",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Показывать задачи в реестре",
  GUILD_TASKS_ENABLE_TIP = "Включить напоминания о задачах для страницы реестра этой гильдии",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Настроить напоминания о задачах для %s",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Предустановленные задачи",

  -- Frequency settings
  FREQUENCY_NUMBER = "Частота (число)",
  FREQUENCY_NUMBER_TIP = "Введите количество единиц времени",
  FREQUENCY_UNIT = "Единица",

  -- Task window
  TASK_WINDOW_TITLE = "Добавить пользовательскую задачу",
  TASK_WINDOW_NAME_LABEL = "Название задачи:",
  TASK_WINDOW_FREQ_LABEL = "Частота:",
  TASK_WINDOW_GUILD_LABEL = "Гильдии (выберите несколько или 'Все'):",
  TASK_WINDOW_ADD = "Добавить задачу",
  TASK_WINDOW_CANCEL = "Отмена",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Пожалуйста, введите название задачи",
  ERROR_INVALID_FREQ_NUMBER = "Пожалуйста, введите корректное число для частоты",
  ERROR_NO_FREQ_UNIT = "Пожалуйста, выберите единицу частоты",

  -- Task completion messages
  TASK_COMPLETED = "Задача выполнена: %s",
  TASK_ADDED = "Задача добавлена: %s (гильдия: %s, включена: true, пользовательская: true)",
  TASK_REMOVED = "Задача удалена: %s",
  ERROR_PRESET_REMOVE = "Предустановленные задачи нельзя удалить. Отключите их в настройках.",
  
  -- Task list display
  TASK_STATUS_OVERDUE = "ПРОСРОЧЕНА",
  
  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Левая кнопка: Завершить задачу",
  TASK_TOOLTIP_RIGHT = "Правая кнопка: Удалить задачу",
  
  PRESET_REVIEW_APPLICATIONS = "Проверить заявки",
  PRESET_CHECK_BANK_DEPOSITS = "Проверить вклады в банк",
  PRESET_UPDATE_MOTD = "Обновить сообщение дня",
  PRESET_PROMOTE_PROBATIONARY = "Повысить испытуемых",
  PRESET_REVIEW_INACTIVES = "Проверить неактивных",

  TASK_COLOR_LEGEND = "Легенда цветов - Оставшееся время:\n|c00FF00>25%|r - Безопасно\n|cFFFF0010-25%|r - Планировать заранее\n|cFF88005-10%|r - Действовать скоро\n|cFF0000<5% или просрочена|r - Срочно!",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Удалить Пользовательскую Задачу",
  REMOVE_CUSTOM_TASK_TIP = "Выберите пользовательскую задачу для окончательного удаления",
  REMOVE_WARNING = "ВНИМАНИЕ: Удаление необратимо! Чтобы восстановить задачу, вам придется добавить её заново вручную.",
  REMOVE_INSTRUCTION = "Нажмите на задачу ниже, чтобы удалить её:",
  REMOVE_WINDOW_CANCEL = "Отмена",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Опции Контекстного Меню",
  DESCRIPTION = "Добавляет записи новой почты, приглашения в гильдию и приглашения в чат во все контекстные меню правого клика.",
  MASTER_ENABLE = "Включить Функции Контекстного Меню",
  MASTER_ENABLE_TIP = "Главный переключатель для всех улучшений контекстного меню.",
  SF_UNAVAILABLE = "ОШИБКА: ScrollkeeperFramework отсутствует!",
    
  -- Headers
  SCROLLKEEPER_TOOLS = "Инструменты Scrollkeeper",
  CHAT_HEADER = "Опции Чата",
  ROSTER_HEADER = "Опции Списка Гильдии",
    
  -- Options
  NEW_MAIL = "Новая Почта",
  NEW_MAIL_TIP = "Добавить опцию 'Новая Почта' в контекстные меню чата.",
  GUILD_INVITE = "Приглашение в Гильдию",
  GUILD_INVITE_TIP = "Добавить опции приглашения в гильдию в контекстные меню чата.",
  ROSTER_DESC = "Добавляет интеграцию блокнота в контекстное меню правого клика списка гильдии.",
  NOTEBOOK_CONTEXT = "Включить Контекстное Меню Блокнота",
  NOTEBOOK_CONTEXT_TIP = "Правый клик по членам гильдии для открытия или создания записей блокнота.",
  ROSTER_INVITE = "Приглашение в Гильдию из Списка",
  ROSTER_INVITE_TIP = "Добавить опции приглашения в гильдию в контекстные меню списка гильдии.",
    
  -- Context Menu Items
  INVITE_TO = "Пригласить в %s",
  GO_TO_NOTEBOOK = "Перейти к Записи Блокнота",
  MAKE_NOTE = "Создать Заметку в Блокноте",
    
  -- Messages
  NOTEBOOK_NOT_FOUND = "Модуль блокнота не найден.",
  NOTE_EXISTS = "Заметка уже существует для %s.",
  NOTE_CREATED = "Заметка создана для %s в Блокноте.",
  OPEN_NOTE = "Открыть Запись Блокнота",
  CREATE_NOTE = "Создать Заметку в Блокноте",
  LOG_CONVERSATION = "Записать Недавний Чат",
  CONVERSATION_LOGGED = "Записано %d недавних сообщений с %s в Блокноте в категории 'Чат'",
  NO_CONVERSATION = "Не найдено недавнего чата с участием %s в последних 100 сообщениях.",
  LOG_CONVERSATIONS = "Включить Логирование Разговоров",
  LOG_CONVERSATIONS_TIP = "Записывать разговоры чата в Блокнот (требуется аддон pChat).",
  PCHAT_WARNING = "Аддон pChat не обнаружен - эта функция не будет работать",
    
  -- Mail Items
  LOG_DONATION = "Записать Пожертвование",
  LOG_DONATION_TIP = "Вручную записать пожертвование для этого игрока",
  DONATION_WINDOW_TITLE = "Записать Ручное Пожертвование",
  DONATION_PLAYER = "Игрок",
  DONATION_GUILD = "Гильдию", 
  DONATION_VALUE_LABEL = "Стоимость в Золоте",
  DONATION_VALUE_TIP = "Введите стоимость этого пожертвования в золоте (для предметов введите их приблизительную стоимость)",
  DONATION_NOTES_LABEL = "Заметки (Необязательно)",
  DONATION_NOTES_TIP = "Дополнительные детали, например 'Отправлено 50 Воска Драу по почте' или 'Золото отправлено 25.12'",
  DONATION_TYPE_LABEL = "Тип Пожертвования",
  DONATION_TYPE_GOLD = "Золото (Почта)",
  DONATION_TYPE_ITEMS = "Предметы (Оцененные)",
  BTN_RECORD_DONATION = "Записать Пожертвование",
  BTN_CANCEL = "Отмена",
  SUCCESS_DONATION_LOGGED = "Пожертвование %d золота записано для %s",
  ERROR_INVALID_AMOUNT = "Пожалуйста, введите действительную сумму золота",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Фоновая служба кэширования для данных истории гильдии с использованием LibHistoire.",
    
  -- Status Messages
  HISTOIRE_READY = "LibHistoire готов - кэширование всей истории гильдии",
  CACHE_STATUS = "=== Статус Кэша Событий ===",
  NO_CACHED_DATA = "Кэшированные данные не найдены",
  CACHE_EMPTY = "Кэш пуст - это может занять несколько минут при первой загрузке",
  WAITING_FOR_HISTOIRE = "Ожидание инициализации LibHistoire...",
    
  -- Log Messages
  EVENTS_CACHED = "%s/%s: %d событий в кэше",
  STARTED_CACHING = "Начато кэширование %d гильдий",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Загружен - фоновая служба кэширования",
  LOG_MANUAL_DONATION = "%s - %d золота записано вручную",
  MANUAL_DONATION_SOURCE = "Ручной Ввод",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r КРИТИЧНО: SF.Data не является таблицей!",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r ОШИБКА: LibHistoire не найден!",
    
  -- Cache Display
  GUILD_HEADER = "%s:",
  CATEGORY_LINE = "  %s: %d событий",
  HISTOIRE_STATUS = "LibHistoire готов: %s",
    
  -- Category Names (for display)
  CAT_ROSTER = "список",
  CAT_BANKED_GOLD = "золотоБанка",
  CAT_BANKED_ITEMS = "предметыБанка",
  CAT_SALES = "продажи",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Записано: %d золота от %s в %s",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Отсутствуют обязательные параметры",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Ручная запись успешно удалена из кеша и хранилища",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Запись не найдена",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[Отладка Данных] Гильдия не указана",
  DEBUG_NO_CACHE_FOR_GUILD = "[Отладка Данных] Нет кеша для гильдии: %s",
  DEBUG_AVAILABLE_GUILDS = "[Отладка Данных] Доступные гильдии:",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Отладка Данных] Кеш для %s:",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold: %d событий",
  DEBUG_RECENT_DEPOSITS = "  Недавние депозиты:",
  DEBUG_NO_DEPOSITS = "  Депозитов не найдено",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold: НЕ ПРИСУТСТВУЕТ",
  DEBUG_ROSTER_COUNT = "  roster: %d событий",
  DEBUG_ROSTER_MISSING = "  roster: НЕ ПРИСУТСТВУЕТ",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Модуль данных или функция проверки недоступны",
  CMD_CHECKGOLD_USAGE = "Использование: /sgtcheckgold НазваниеГильдии|@ОтображаемоеИмя|Дни",
  CMD_CHECKGOLD_EXAMPLE = "Пример: /sgtcheckgold Dragon's Nest Thievery Co|@ВашеИмя|14",
  CMD_CHECKGOLD_RESULT = "%s пожертвовал %d золота за последние %d дней (%s)",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r ОШИБКА: LibHistoire не найден",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Приветственные Сообщения",
  DESCRIPTION = "Настройте приветственные сообщения для членов гильдии. Используйте %1 для имени игрока и %2 для названия гильдии. Сообщения будут поставлены в очередь при принятии нескольких заявок или если текстовое поле активно.",
  MASTER_ENABLE = "Включить Приветственные Сообщения",
  MASTER_ENABLE_TIP = "Включить/отключить все приветственные сообщения.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s присоединился к %s как %s",
    
  -- Template
  TEMPLATE_HEADER = "Переменные Шаблона",
  VAR_PLAYER = "%1 - Имя Игрока",
  VAR_GUILD = "%2 - Название Гильдии",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "Включить для этой Гильдии",
  MESSAGE_TEMPLATE = "Шаблон Сообщения",
  PREVIEW = "Предпросмотр: %s",
  DEFAULT_MESSAGE = "Добро пожаловать %1 в %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Команды Чата и Утилиты",
  DESCRIPTION = "Дополнительные команды утилит и поддержка привязки клавиш для Scrollkeeper.",
    
  -- Headers
  COMMANDS_HEADER = "Доступные Команды",
  UTILITY_HEADER = "Команды Утилит",
  STATUS_HEADER = "Команды Статуса",
  MODULE_HEADER = "Команды Модулей",
  DEBUG_HEADER = "Команды Отладки",
    
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Показать информацию об отладке системы",
  CMD_SKTEST = "|cf3ebd1/sktest <опция>|r - Выполнить тесты модулей (опции: context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Переключить окно блокнота",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Открыть окно почты",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Открыть окно поиска истории",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Открыть окно временных членов",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Показать статус кэша событий",
  CMD_ROLL = "|cf3ebd1/roll <число>|r - Бросить кости (пример: /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <число>|r - То же, что /roll",
  CMD_RL = "|cf3ebd1/rl|r - Перезагрузить интерфейс",
  CMD_ON = "|cf3ebd1/on|r - Установить статус на В сети",
  CMD_OFF = "|cf3ebd1/off|r - Установить статус на Не в сети",
  CMD_AFK = "|cf3ebd1/afk|r - Установить статус на Отошёл",
  CMD_DND = "|cf3ebd1/dnd|r - Установить статус на Не беспокоить",
  CMD_OFFL = "|cf3ebd1/offl|r - Переключить В сети/Не в сети",
    
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Переключить окно блокнота\n" ..
                "|cf3ebd1/sgtmail|r - Открыть окно почты\n" ..
                "|cf3ebd1/sgthistory|r - Открыть поиск истории\n" ..
                "|cf3ebd1/sgtprovision|r - Открыть окно временных членов\n" ..
                "|cf3ebd1/roll <число>|r - Бросить кости\n" ..
                "|cf3ebd1/rl|r - Перезагрузить интерфейс\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - Установить статус игрока\n" ..
                "|cf3ebd1/offl|r - Переключить офлайн\n" ..
                "|cf3ebd1/skdebug|r - Показать информацию отладки\n" ..
                "|cf3ebd1/sgtcache|r - Показать статус кэша",
				"|cf3ebd1/sgtcheckpm ИмяГильдии|@ИмяПользователя|r - Отладка проверки пожертвований золота для конкретного участника\n" ..
				"|cf3ebd1/sgtattendance start [название события]|r - Начать отслеживание\n" ..
				"|cf3ebd1/sgtattendance stop|r - Остановить и сохранить отчет\n" ..
				"|cf3ebd1/sgtattendance status|r - Показать информацию о текущей сессии" ..
				"|cf3ebd1/sgttask add <имя>|<частота>|<гильдия>|r для добавления пользовательской задачи" ..
				"|cf3ebd1/sgttask list|r - Показать все задачи со статусом" ..
				"|cf3ebd1/sgttask complete <номер>|r - Отметить задачу как выполненную",
  
  -- Buttons
  TEST_BUTTON = "Тестировать Все Системы",
  TEST_BUTTON_TIP = "Выполнить комплексный тест всех модулей Scrollkeeper",
    
  -- Status Messages
  STATUS_ONLINE = "Статус установлен на В сети",
  STATUS_OFFLINE = "Статус установлен на Не в сети",
  STATUS_DND = "Статус установлен на Не беспокоить",
  STATUS_AWAY = "Статус установлен на Отошёл",
  STATUS_CHANGED = "Scrollkeeper: Статус установлен на %s",
  STATUS_TOGGLED = "Окно блокнота переключено",
    
  -- Roll Messages
  ROLL_USAGE = "Использование: /roll <макс>",
  ROLL_EXAMPLE = "Пример: /roll 20",
  ROLL_INVALID = "Неверное число: %s",
  ROLL_OUTPUT = "бросил %d (1-%d)",
    
  -- Debug Messages
  DEBUG_HEADER = "=== Информация об Отладке Scrollkeeper ===",
  DEBUG_FRAMEWORK = "Фреймворк загружен: %s",
  DEBUG_SETTINGS = "Таблица настроек: %s",
  DEBUG_LAM = "LAM2 доступен: %s",
  DEBUG_FUNC = "SF.func доступен: %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings: %s",
  DEBUG_PANEL = "Панель зарегистрирована: %s",
  DEBUG_MODULE = "Модуль: %s - Элементы управления: %d - Иконка: %s",
  DEBUG_TOTAL_MODULES = "Всего зарегистрированных модулей: %d",
  DEBUG_NO_MODULES = "Настройки модулей не найдены",
  DEBUG_CONTEXT = "Контекстное меню включено: %s",
  DEBUG_NOTEBOOK = "Модуль блокнота: %s",
  DEBUG_DATA = "Модуль данных: %s",
  DEBUG_HISTOIRE = "LibHistoire: %s",
  DEBUG_DATETIME = "LibDateTime: %s",
    
  -- Test Messages
  TEST_HEADER = "=== Команды Тестирования Scrollkeeper ===",
  TEST_USAGE = "Использование: /sktest <опция>",
  TEST_OPTIONS = "Опции: context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Выполнение комплексного теста системы...",
  TEST_UNKNOWN = "Неизвестная опция теста: %s",
  TEST_AVAILABLE = "Доступные опции: context, settings, notebook, mail, data, attendance",
  
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Тест Контекстного Меню ===",
  TEST_CONTEXT_ACTIVE = "Хук контекстного меню активен",
  TEST_CONTEXT_ENABLED = "Контекстное меню включено в настройках: %s",
  TEST_CONTEXT_MAIL = "Опция новой почты чата: %s",
  TEST_CONTEXT_INVITE = "Опция приглашения чата: %s",
  TEST_CONTEXT_NOT_LOADED = "Модуль ScrollkeeperContextMenu не загружен",
  TEST_CONTEXT_FAILED = "Хук контекстного меню ОТКАЗАЛ - CHAT_SYSTEM недоступен",
    
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Тест Настроек ===",
  TEST_SETTINGS_ACCESSIBLE = "Настройки %s доступны: %s",
  TEST_SETTINGS_PANEL = "Панель настроек зарегистрирована",
  TEST_SETTINGS_NO_PANEL = "Панель настроек не зарегистрирована",
  TEST_SETTINGS_NO_ACCESS = "Невозможно получить доступ к настройкам модуля - проблема фреймворка",
    
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Тест Блокнота ===",
  TEST_NOTEBOOK_LOADED = "Модуль блокнота загружен",
  TEST_NOTEBOOK_ENABLED = "Включено: %s",
  TEST_NOTEBOOK_WINDOW = "Окно блокнота существует: %s",
  TEST_NOTEBOOK_SAVE = "Тест сохранения заметки: %s",
  TEST_NOTEBOOK_NOT_LOADED = "Модуль блокнота не загружен",
    
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Тест Модуля Почты ===",
  TEST_MAIL_LOADED = "Модуль почты загружен",
  TEST_MAIL_ENABLED = "Включено: %s",
  TEST_MAIL_WINDOW = "Окно почты существует: %s",
  TEST_MAIL_COMMAND = "Команда /sgtmail зарегистрирована",
  TEST_MAIL_NO_COMMAND = "Команда /sgtmail не зарегистрирована",
  TEST_MAIL_NOT_LOADED = "Модуль почты не загружен",
    
  -- Test: Data
  TEST_DATA_HEADER = "=== Тест Модуля Данных ===",
  TEST_DATA_LOADED = "Модуль данных загружен",
  TEST_DATA_LH_AVAILABLE = "LibHistoire доступен",
  TEST_DATA_CACHE_ACCESSIBLE = "Кэш событий доступен: %s",
  TEST_DATA_RECORDS = "Всего записей событий в кэше: %d",
  TEST_DATA_NO_FUNCTIONS = "Функции данных недоступны",
  TEST_DATA_NO_LH = "LibHistoire недоступен",
  TEST_DATA_NOT_LOADED = "Модуль данных не загружен",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r ОШИБКА: ScrollkeeperFramework отсутствует!",
  ERROR_NOTEBOOK_DISABLED = "Блокнот отключён в настройках",
  ERROR_NOTEBOOK_NO_WINDOW = "Окно блокнота недоступно",
  ERROR_NOTEBOOK_NOT_LOADED = "Модуль блокнота не загружен",
    
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Регистрация slash-команд...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Slash-команды зарегистрированы",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Инициализация...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Инициализация завершена",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Посещаемость Событий",
  
  -- Description
  DESCRIPTION = "Отслеживание посещаемости событий с автоматическим определением опозданий/ранних уходов.",
  
  -- Settings
  MASTER_ENABLE = "Включить Отслеживание Посещаемости Событий",
  MASTER_ENABLE_TIP = "Включить функции и команды отслеживания посещаемости",
  
  -- Headers
  HEADER_COMMANDS = "Команды и Использование",
  HEADER_HISTORY = "История Сессий",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [название] - Начать отслеживание\n/sgtattendance stop - Завершить и сохранить\n/sgtattendance status - Проверить текущую сессию",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Команды Отслеживания Посещаемости ===",
  HELP_START = "/sgtattendance start [название события] - Начать отслеживание",
  HELP_STOP = "/sgtattendance stop - Остановить и сохранить отчет",
  HELP_STATUS = "/sgtattendance status - Показать информацию о текущей сессии",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Отслеживание началось: %s (%d участников присутствует)",
  SUCCESS_TRACKING_STOPPED = "Отслеживание остановлено: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Отчет о посещаемости сохранен в категории 'События' Записной книжки как '%s'",
  SUCCESS_HISTORY_CLEARED = "История посещаемости очищена",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "Событие уже отслеживается! Сначала используйте /sgtattendance stop.",
  ERROR_NO_ACTIVE_SESSION = "Нет активной сессии отслеживания",
  ERROR_UNKNOWN_COMMAND = "Неизвестная команда. Используйте /sgtattendance help",
  ERROR_NOT_SAVED = "Предупреждение: Не удалось сохранить в Записной книжке",
  ERROR_NOTEBOOK_DISABLED = "Записная книжка недоступна - отчет сохранен только в истории посещаемости",
  
  -- Status messages
  STATUS_NO_SESSION = "Нет активной сессии отслеживания",
  STATUS_ACTIVE = "Отслеживание: %s | Длительность: %d мин | Участников: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s присоединился к событию (опоздание на %d минут)",
  LOG_MEMBER_LEFT = "%s покинул событие (присутствовал %d минут)",
  
  -- Report sections
  REPORT_HEADER = "Отчет о Посещаемости: %s",
  REPORT_TIME = "Время: с %s до %s",
  REPORT_SUMMARY = "Всего Участников: %d | Полная Посещаемость: %d | Опоздавшие: %d | Ушедшие Рано: %d",
  
  SECTION_FULL_ATTENDANCE = "Полная Посещаемость",
  SECTION_ON_TIME = "Вовремя",
  SECTION_LATE = "Опоздавшие",
  SECTION_LEFT_EARLY = "Ушедшие Рано",
  
  -- History display
  NO_SESSIONS = "Пока нет отслеженных сессий",
  SESSIONS_COUNT = "Отслеженных Сессий: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Очистить Историю",
  BTN_CLEAR_HISTORY_TIP = "Удалить все сохраненные сессии посещаемости",
  WARNING_CLEAR_HISTORY = "Это навсегда удалит все записи о посещаемости!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Заявки в Гильдию",
  DESCRIPTION = "Автоматически записывает заявки в гильдию в ваш Блокнот для ведения учета. Заявки сохраняются со всеми деталями, включая сообщение заявителя.",
  
  -- Settings
  MASTER_ENABLE = "Включить Запись Заявок",
  MASTER_ENABLE_TIP = "Главный переключатель для функции записи заявок",
  AUTO_LOG = "Автоматически Записывать Новые Заявки",
  AUTO_LOG_TIP = "Когда включено, новые заявки в гильдию автоматически сохраняются в Блокнот",
  SHOW_NOTIFICATIONS = "Показывать Уведомления в Чате",
  SHOW_NOTIFICATIONS_TIP = "Отображать сообщение в чате при записи заявок",
  
  -- Guild settings
  HEADER_GUILDS = "Настройки для Каждой Гильдии",
  GUILDS_DESC = "Выберите, для каких гильдий записывать заявки:",
  GUILD_TOGGLE_TIP = "Записывать заявки для %s",
  
  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r Модуль Блокнота недоступен. Заявки не могут быть записаны.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r ВНИМАНИЕ: Модуль Блокнота не загружен. Запись заявок не будет работать.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Заявка от |cFFD700%s|r в |cFFD700%s|r записана",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Не удалось сохранить заявку от %s",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r Записано заявок для |cFFD700%s|r: %d",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization