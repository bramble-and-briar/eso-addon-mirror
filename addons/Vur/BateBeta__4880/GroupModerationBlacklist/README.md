# Group Moderation - Blacklist

Аддон для The Elder Scrolls Online: модерация группы с чёрным списком аккаунтов.

## Установка

1. Скопируйте папку `GroupModerationBlacklist` в `Documents/Elder Scrolls Online/live/AddOns/`
2. Установите библиотеку **LibAddonMenu-2.0** (опционально, для панели настроек):
   - Скачайте с [ESOUI](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
   - Распакуйте в `AddOns/LibAddonMenu-2.0/`
3. Перезапустите игру или выполните `/reloadui`

## Структура

```
GroupModerationBlacklist/
├── GroupModerationBlacklist.txt      — manifest
├── GroupModerationBlacklist.lua      — точка входа, инициализация
├── Moderation.lua                    — логика фильтрации и исключения
├── GroupActivity.lua                 — перевыставление в Activity Finder
├── UI.lua                            — вкладка GroupMenu + ScrollList
├── blacklist.xml                     — шаблон строки списка
└── README.md                         — этот файл
```

## Функционал

### Вкладка «Черный список»
- Прокручиваемый список сохранённых аккаунтов
- Поле ввода для добавления аккаунта формата `@accountName`
- Кнопка быстрого удаления записи при наведении

### Автоматическое исключение
- При входе участника в группу (`EVENT_GROUP_MEMBER_JOINED`) аккаунт проверяется по чёрному списку
- При совпадении лидер группы автоматически исключает участника
- Только лидер может выполнять исключение
- Throttle: не чаще 1 кика в 5 секунд

### Перевыставление в Activity Finder
- Сохраняет параметры группы (название, описание, роли, сложность)
- Если исключённый участник был финальным (группа была полной), автоматически перевыставляет группу
- Защита от двойного срабатывания

## Технические детали

### SavedVariables
```lua
GroupModerationBlacklistSV = {
    version = 1,
    blacklist = { ["@account"] = timestamp, ... },
    groupActivitySnapshot = { name, description, roles, difficulty },
    lastKickTime = 0,
    isReposting = false,
    kickCooldown = 5,
}
```

### События
- `EVENT_GROUP_MEMBER_JOINED` — проверка входящего по чёрному списку
- `EVENT_GROUP_MEMBER_LEFT` — фиксация результата исключения
- `EVENT_LEADER_CHANGED` — инвалидация кэша лидера
- `EVENT_GROUP_UPDATE` — обновление снимка параметров группы
- `EVENT_GROUP_DISBANDED` — сброс состояния

### Защита от protected-блокировок
- Все защищённые вызовы через `CallSecureFunction`
- Проверка `IsUnitGroupLeader("player")` перед каждой мутацией
- Флаги идемпотентности против двойного срабатывания

## Тестирование

Подробный чек-лист тестирования см. в [TESTING.md](TESTING.md).

### Быстрый старт
1. **Добавление в чёрный список**: откройте меню группы → вкладка «Черный список» → введите `@accountName` → «Добавить»
2. **Удаление из списка**: наведите на запись → нажмите кнопку удаления
3. **Автоматическое исключение**: добавьте тестовый аккаунт в список → попросите его войти в группу → он будет автоматически исключён
4. **Перевыставление**: после исключения финального участника группа автоматически перевыставится в Activity Finder

## Совместимость

- **ESO API**: 101045
- **LibAddonMenu-2.0**: опционально
- **Платформа**: Windows, Mac, Xbox, PlayStation

## Лицензия

MIT License
