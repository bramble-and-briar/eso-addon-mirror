-- TodoList: функциональный список задач и трекер для The Elder Scrolls Online
-- ВАЖНО: добавьте в TodoList.txt строку:
-- ## SavedVariables: TodoListSavedVariables
--
-- v7: исправлена ошибка ползунка прозрачности; состояние окна сохраняется между /reloadui;
--     окна прячутся в меню через фрагменты сцен HUD/HUD UI; редактирование задач (двойной клик);
--     опция «список для каждого персонажа».
-- v6: автоматическая локализация интерфейса (RU, EN, FR, DE, ES, IT) в зависимости от языка клиента игры.

local ADDON_NAME = "TodoList"
local PAGE_SIZE = 8
local MAX_TASK_CHARS = 300
local LIST_TOP = 122          -- верх списка в обычном режиме (под полем ввода и фильтрами)
local BOTTOM_PAD = 70         -- место под счётчик/страницы внизу окна
local MIN_WINDOW_WIDTH = 400
local DEFAULT_FONT = "$(MEDIUM_FONT)|18|soft-shadow-thick"
local DEFAULT_SPACING = 3

---------------------------------------------------------------------------
-- Локализация (автоопределение языка клиента ESO)
---------------------------------------------------------------------------

local LOCALIZATION = {
    ru = {
        TITLE = "Мои задачи",
        TITLE_COLLAPSED = "Мои задачи (%d/%d)",
        ADD_BTN = "Добавить",
        EDIT_HINT_ALL = "Введите задачу и нажмите Enter...",
        EDIT_HINT_CAT = "Новая задача · %s — введите и нажмите Enter...",
        FILTER_ALL = "Все",
        CAT_HOME = "Дом",
        CAT_CRAFT = "Ремесло",
        CAT_ADVENTURE = "Приключения",
        CAT_SHOPPING = "Покупки",
        EMPTY_ALL = "Задач пока нет. Введите первую выше.",
        EMPTY_CAT = "В категории «%s» пока нет задач.",
        COUNT_SUMMARY = "Всего: %d   Выполнено: %d",
        CLEAR_COMPLETED = "Убрать выполненные",
        TOOLTIP_HUD = "Зажмите ЛКМ — переместить весь список\nКороткий ЛКМ — выполнить\nShift+ЛКМ или СКМ — следующая категория\nCtrl+ЛКМ — предыдущая\nПКМ — удалить задачу",
        TOOLTIP_NORMAL = "ЛКМ — отметить выполнение\nShift+ЛКМ или СКМ — следующая категория\nCtrl+ЛКМ — предыдущая\nПКМ — удалить задачу",
        BTN_TOOLTIP = "Список задач (осталось %d из %d)\nЛКМ — открыть/перетащить\nПКМ — режим прозрачного HUD",

        -- Настройки
        SETTINGS_TITLE = "Настройки TodoList",
        SEC_APPEARANCE = "ВНЕШНИЙ ВИД",
        ALPHA_LABEL = "Прозрачность окна",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Прозрачное",
        ALPHA_HINT_R = "Непрозрачное",
        ALPHA_HINT_HUD = "Меньше 15% — прозрачный HUD (также ПКМ по иконке TDL)",
        SEC_FONT = "ШРИФТ",
        FONT_NORMAL = "Обычный",
        FONT_LARGE = "Крупный",
        FONT_SMALL = "Мелкий",
        FONT_BOLD = "Жирный",
        SEC_SIZE = "РАЗМЕР ОКНА",
        SIZE_WIDTH = "Ширина",
        SIZE_HEIGHT = "Высота",
        SIZE_RESET = "Сбросить\nразмер",
        ROW_SPACING = "Интервал между задачами",
        SEC_BEHAVIOR = "ПОВЕДЕНИЕ",
        OPT_LOCK = "Закрепить положение",
        OPT_DAILY_RESET = "Ежедневный сброс галочек",
        STATE_ON = "ВКЛ",
        STATE_OFF = "ВЫКЛ",
        RESET_ALL = "Сбросить все настройки",
        RESET_CONFIRM = "Нажмите ещё раз для подтверждения",
        TITLE_EDITING = "Редактирование задачи",
        SAVE_BTN = "Сохранить",
        TOOLTIP_EDIT = "Двойной клик — редактировать",
        OPT_PER_CHARACTER = "Список для каждого персонажа",
    },
    en = {
        TITLE = "My Tasks",
        TITLE_COLLAPSED = "My Tasks (%d/%d)",
        ADD_BTN = "Add",
        EDIT_HINT_ALL = "Enter a task and press Enter...",
        EDIT_HINT_CAT = "New task · %s — type and press Enter...",
        FILTER_ALL = "All",
        CAT_HOME = "Housing",
        CAT_CRAFT = "Crafting",
        CAT_ADVENTURE = "Adventure",
        CAT_SHOPPING = "Shopping",
        EMPTY_ALL = "No tasks yet. Type your first one above.",
        EMPTY_CAT = "No tasks in «%s» category yet.",
        COUNT_SUMMARY = "Total: %d   Completed: %d",
        CLEAR_COMPLETED = "Clear Completed",
        TOOLTIP_HUD = "Hold LMB — move entire list\nShort LMB — toggle done\nShift+LMB or MMB — next category\nCtrl+LMB — previous category\nRMB — delete task",
        TOOLTIP_NORMAL = "LMB — toggle completion\nShift+LMB or MMB — next category\nCtrl+LMB — previous category\nRMB — delete task",
        BTN_TOOLTIP = "Todo List (%d of %d remaining)\nLMB — open/drag\nRMB — transparent HUD mode",

        -- Settings
        SETTINGS_TITLE = "TodoList Settings",
        SEC_APPEARANCE = "APPEARANCE",
        ALPHA_LABEL = "Window Opacity",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Transparent",
        ALPHA_HINT_R = "Opaque",
        ALPHA_HINT_HUD = "Below 15% — transparent HUD (or RMB on TDL icon)",
        SEC_FONT = "FONT",
        FONT_NORMAL = "Normal",
        FONT_LARGE = "Large",
        FONT_SMALL = "Small",
        FONT_BOLD = "Bold",
        SEC_SIZE = "WINDOW SIZE",
        SIZE_WIDTH = "Width",
        SIZE_HEIGHT = "Height",
        SIZE_RESET = "Reset\nSize",
        ROW_SPACING = "Task spacing",
        SEC_BEHAVIOR = "BEHAVIOR",
        OPT_LOCK = "Lock position",
        OPT_DAILY_RESET = "Daily reset checkmarks",
        STATE_ON = "ON",
        STATE_OFF = "OFF",
        RESET_ALL = "Reset all settings",
        RESET_CONFIRM = "Click again to confirm",
        TITLE_EDITING = "Editing task",
        SAVE_BTN = "Save",
        TOOLTIP_EDIT = "Double-click — edit",
        OPT_PER_CHARACTER = "Separate list per character",
    },
    fr = {
        TITLE = "Mes tâches",
        TITLE_COLLAPSED = "Mes tâches (%d/%d)",
        ADD_BTN = "Ajouter",
        EDIT_HINT_ALL = "Entrez une tâche et appuyez sur Entrée...",
        EDIT_HINT_CAT = "Nouvelle tâche · %s — tapez et appuyez sur Entrée...",
        FILTER_ALL = "Tout",
        CAT_HOME = "Maison",
        CAT_CRAFT = "Artisanat",
        CAT_ADVENTURE = "Aventure",
        CAT_SHOPPING = "Achats",
        EMPTY_ALL = "Aucune tâche. Saisissez la première ci-dessus.",
        EMPTY_CAT = "Aucune tâche dans la catégorie « %s ».",
        COUNT_SUMMARY = "Total : %d   Terminées : %d",
        CLEAR_COMPLETED = "Effacer terminées",
        TOOLTIP_HUD = "Maintenir Clic G — déplacer la liste\nClic G court — terminer\nMaj+Clic G ou Clic M — catégorie suivante\nCtrl+Clic G — catégorie précédente\nClic D — supprimer la tâche",
        TOOLTIP_NORMAL = "Clic G — marquer comme fait\nMaj+Clic G ou Clic M — catégorie suivante\nCtrl+Clic G — catégorie précédente\nClic D — supprimer la tâche",
        BTN_TOOLTIP = "Liste des tâches (%d sur %d restantes)\nClic G — ouvrir/déplacer\nClic D — mode HUD transparent",

        -- Paramètres
        SETTINGS_TITLE = "Paramètres TodoList",
        SEC_APPEARANCE = "APPARENCE",
        ALPHA_LABEL = "Opacité de la fenêtre",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Transparent",
        ALPHA_HINT_R = "Opaque",
        ALPHA_HINT_HUD = "Moins de 15% — HUD transparent (ou Clic D sur TDL)",
        SEC_FONT = "POLICE",
        FONT_NORMAL = "Normale",
        FONT_LARGE = "Grande",
        FONT_SMALL = "Petite",
        FONT_BOLD = "Grasse",
        SEC_SIZE = "TAILLE DE LA FENÊTRE",
        SIZE_WIDTH = "Largeur",
        SIZE_HEIGHT = "Hauteur",
        SIZE_RESET = "Réinitialiser\nla taille",
        ROW_SPACING = "Espacement des tâches",
        SEC_BEHAVIOR = "COMPORTEMENT",
        OPT_LOCK = "Verrouiller la position",
        OPT_DAILY_RESET = "Réinitialisation quotidienne",
        STATE_ON = "OUI",
        STATE_OFF = "NON",
        RESET_ALL = "Réinitialiser tous les paramètres",
        RESET_CONFIRM = "Cliquez encore pour confirmer",
        TITLE_EDITING = "Modification de la tâche",
        SAVE_BTN = "Enregistrer",
        TOOLTIP_EDIT = "Double-clic — modifier",
        OPT_PER_CHARACTER = "Liste par personnage",
    },
    de = {
        TITLE = "Meine Aufgaben",
        TITLE_COLLAPSED = "Meine Aufgaben (%d/%d)",
        ADD_BTN = "Hinzufügen",
        EDIT_HINT_ALL = "Aufgabe eingeben und Enter drücken...",
        EDIT_HINT_CAT = "Neue Aufgabe · %s — eingeben und Enter drücken...",
        FILTER_ALL = "Alle",
        CAT_HOME = "Heim",
        CAT_CRAFT = "Handwerk",
        CAT_ADVENTURE = "Abenteuer",
        CAT_SHOPPING = "Einkauf",
        EMPTY_ALL = "Noch keine Aufgaben. Gib oben deine erste ein.",
        EMPTY_CAT = "Keine Aufgaben in der Kategorie «%s».",
        COUNT_SUMMARY = "Gesamt: %d   Erledigt: %d",
        CLEAR_COMPLETED = "Erledigte löschen",
        TOOLTIP_HUD = "LMT halten — ganze Liste verschieben\nKurzer LMT — erledigen\nUmschalt+LMT oder MMT — nächste Kategorie\nStrg+LMT — vorherige Kategorie\nRMT — Aufgabe löschen",
        TOOLTIP_NORMAL = "LMT — als erledigt markieren\nUmschalt+LMT oder MMT — nächste Kategorie\nStrg+LMT — vorherige Kategorie\nRMT — Aufgabe löschen",
        BTN_TOOLTIP = "Aufgabenliste (%d von %d übrig)\nLMT — öffnen/verschieben\nRMT — transparenter HUD-Modus",

        -- Einstellungen
        SETTINGS_TITLE = "TodoList Einstellungen",
        SEC_APPEARANCE = "AUSSEHEN",
        ALPHA_LABEL = "Fenster-Deckkraft",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Transparent",
        ALPHA_HINT_R = "Undurchsichtig",
        ALPHA_HINT_HUD = "Unter 15% — transparentes HUD (auch RMT auf TDL-Symbol)",
        SEC_FONT = "SCHRIFTART",
        FONT_NORMAL = "Normal",
        FONT_LARGE = "Groß",
        FONT_SMALL = "Klein",
        FONT_BOLD = "Fett",
        SEC_SIZE = "FENSTERGRÖSSE",
        SIZE_WIDTH = "Breite",
        SIZE_HEIGHT = "Höhe",
        SIZE_RESET = "Größe\nzurücksetzen",
        ROW_SPACING = "Aufgabenabstand",
        SEC_BEHAVIOR = "VERHALTEN",
        OPT_LOCK = "Position sperren",
        OPT_DAILY_RESET = "Tägliches Zurücksetzen",
        STATE_ON = "EIN",
        STATE_OFF = "AUS",
        RESET_ALL = "Alle Einstellungen zurücksetzen",
        RESET_CONFIRM = "Zum Bestätigen erneut klicken",
        TITLE_EDITING = "Aufgabe bearbeiten",
        SAVE_BTN = "Speichern",
        TOOLTIP_EDIT = "Doppelklick — bearbeiten",
        OPT_PER_CHARACTER = "Liste pro Charakter",
    },
    es = {
        TITLE = "Mis tareas",
        TITLE_COLLAPSED = "Mis tareas (%d/%d)",
        ADD_BTN = "Añadir",
        EDIT_HINT_ALL = "Escribe una tarea y pulsa Intro...",
        EDIT_HINT_CAT = "Nueva tarea · %s — escribe y pulsa Intro...",
        FILTER_ALL = "Todas",
        CAT_HOME = "Hogar",
        CAT_CRAFT = "Artesanía",
        CAT_ADVENTURE = "Aventura",
        CAT_SHOPPING = "Compras",
        EMPTY_ALL = "Aún no hay tareas. Escribe la primera arriba.",
        EMPTY_CAT = "No hay tareas en la categoría «%s».",
        COUNT_SUMMARY = "Total: %d   Completadas: %d",
        CLEAR_COMPLETED = "Limpiar completadas",
        TOOLTIP_HUD = "Mantener Clic I — mover toda la lista\nClic I corto — completar\nMayús+Clic I o Clic C — siguiente categoría\nCtrl+Clic I — categoría anterior\nClic D — eliminar tarea",
        TOOLTIP_NORMAL = "Clic I — marcar completada\nMayús+Clic I o Clic C — siguiente categoría\nCtrl+Clic I — categoría anterior\nClic D — eliminar tarea",
        BTN_TOOLTIP = "Lista de tareas (quedan %d de %d)\nClic I — abrir/arrastrar\nClic D — modo HUD transparente",

        -- Ajustes
        SETTINGS_TITLE = "Ajustes de TodoList",
        SEC_APPEARANCE = "APARIENCIA",
        ALPHA_LABEL = "Opacidad de ventana",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Transparente",
        ALPHA_HINT_R = "Opaco",
        ALPHA_HINT_HUD = "Menos del 15% — HUD transparente (también Clic D en TDL)",
        SEC_FONT = "FUENTE",
        FONT_NORMAL = "Normal",
        FONT_LARGE = "Grande",
        FONT_SMALL = "Pequeña",
        FONT_BOLD = "Negrita",
        SEC_SIZE = "TAMAÑO DE VENTANA",
        SIZE_WIDTH = "Ancho",
        SIZE_HEIGHT = "Alto",
        SIZE_RESET = "Restablecer\ntamaño",
        ROW_SPACING = "Espaciado entre tareas",
        SEC_BEHAVIOR = "COMPORTAMIENTO",
        OPT_LOCK = "Bloquear posición",
        OPT_DAILY_RESET = "Reinicio diario de marcas",
        STATE_ON = "SÍ",
        STATE_OFF = "NO",
        RESET_ALL = "Restablecer todos los ajustes",
        RESET_CONFIRM = "Haz clic de nuevo para confirmar",
        TITLE_EDITING = "Editando tarea",
        SAVE_BTN = "Guardar",
        TOOLTIP_EDIT = "Doble clic — editar",
        OPT_PER_CHARACTER = "Lista por personaje",
    },
    it = {
        TITLE = "Le mie attività",
        TITLE_COLLAPSED = "Le mie attività (%d/%d)",
        ADD_BTN = "Aggiungi",
        EDIT_HINT_ALL = "Inserisci un'attività e premi Invio...",
        EDIT_HINT_CAT = "Nuova attività · %s — scrivi e premi Invio...",
        FILTER_ALL = "Tutte",
        CAT_HOME = "Casa",
        CAT_CRAFT = "Artigianato",
        CAT_ADVENTURE = "Avventura",
        CAT_SHOPPING = "Acquisti",
        EMPTY_ALL = "Nessuna attività. Scrivi la prima qui sopra.",
        EMPTY_CAT = "Nessuna attività nella categoria «%s».",
        COUNT_SUMMARY = "Totale: %d   Completate: %d",
        CLEAR_COMPLETED = "Rimuovi completate",
        TOOLTIP_HUD = "Tieni premuto Clic S — sposta l'intera lista\nClic S breve — completa\nMaiusc+Clic S o Clic C — categoria successiva\nCtrl+Clic S — categoria precedente\nClic D — elimina attività",
        TOOLTIP_NORMAL = "Clic S — segna come completata\nMaiusc+Clic S o Clic C — categoria successiva\nCtrl+Clic S — categoria precedente\nClic D — elimina attività",
        BTN_TOOLTIP = "Lista attività (%d di %d rimanenti)\nClic S — apri/trascina\nClic D — modalità HUD trasparente",

        -- Impostazioni
        SETTINGS_TITLE = "Impostazioni TodoList",
        SEC_APPEARANCE = "ASPETTO",
        ALPHA_LABEL = "Opacità finestra",
        ALPHA_HUD = "%d%% · HUD",
        ALPHA_HINT_L = "Trasparente",
        ALPHA_HINT_R = "Opaco",
        ALPHA_HINT_HUD = "Meno del 15% — HUD trasparente (o Clic D sull'icona TDL)",
        SEC_FONT = "CARATTERE",
        FONT_NORMAL = "Normale",
        FONT_LARGE = "Grande",
        FONT_SMALL = "Piccolo",
        FONT_BOLD = "Grassetto",
        SEC_SIZE = "DIMENSIONE FINESTRA",
        SIZE_WIDTH = "Larghezza",
        SIZE_HEIGHT = "Altezza",
        SIZE_RESET = "Reimposta\ndimensioni",
        ROW_SPACING = "Spaziatura attività",
        SEC_BEHAVIOR = "COMPORTAMENTO",
        OPT_LOCK = "Blocca posizione",
        OPT_DAILY_RESET = "Azzeramento giornaliero",
        STATE_ON = "SÌ",
        STATE_OFF = "NO",
        RESET_ALL = "Reimposta tutte le impostazioni",
        RESET_CONFIRM = "Clicca di nuovo per confermare",
        TITLE_EDITING = "Modifica attività",
        SAVE_BTN = "Salva",
        TOOLTIP_EDIT = "Doppio clic — modifica",
        OPT_PER_CHARACTER = "Elenco per personaggio",
    },
}

local function GetClientLanguage()
    local lang = GetCVar("language.2") or "en"
    lang = string.lower(lang)
    if LOCALIZATION[lang] then
        return lang
    end
    return "en" -- язык по умолчанию, если клиент на неподдерживаемом языке
end

local CURRENT_LANG = GetClientLanguage()
local L = LOCALIZATION[CURRENT_LANG]

-- Категории задач. Порядок важен: по нему работает Shift+ЛКМ (смена категории).
local CATEGORY_ORDER = { "home", "craft", "adventure", "shopping" }
local CATEGORIES = {
    home      = { name = L.CAT_HOME,      color = "E8B04A" },
    craft     = { name = L.CAT_CRAFT,     color = "7FB8E8" },
    adventure = { name = L.CAT_ADVENTURE, color = "E57C6C" },
    shopping  = { name = L.CAT_SHOPPING,  color = "B98FE0" },
}
local FILTER_ORDER = { "all", "home", "craft", "adventure", "shopping" }

local TodoList = {
    window = nil,
    settingsWindow = nil,
    editBox = nil,
    rows = {},
    page = 1,
    saved = nil,
    buttonWindow = nil,
    titleLabel = nil,
    countLabel = nil,
    pageLabel = nil,
    collapseBtn = nil,
    chromeControls = {},
    -- v5
    pageTasks = {},       -- [номер строки] = индекс задачи в saved.tasks
    pages = {},
    filtered = {},
    filterChips = {},
    measureLabel = nil,
    emptyLabel = nil,
    counterLabel = nil,
    refreshSettingsUI = nil,
    -- v7
    charSaved = nil,         -- данные текущего персонажа (если включена опция)
    editingIndex = nil,      -- индекс редактируемой задачи
    addButton = nil,
    settingsOpen = false,
    mainFragment = nil,      -- фрагменты сцен HUD / HUD UI (прячут окна в меню)
    buttonFragment = nil,
    settingsFragment = nil,
    focusTask = nil,
}

-- Хранилище задач: общее на аккаунт или отдельное на персонажа.
local function GetData()
    local sv = TodoList.saved
    if sv and sv.perCharacter and TodoList.charSaved then
        return TodoList.charSaved
    end
    return sv
end

-- Видимость окон: окна принадлежат фрагментам сцен HUD и HUD UI, поэтому игра сама
-- прячет их в меню и диалогах. Условие фрагмента = «окно открыто пользователем».
-- Refresh() заставляет фрагмент заново проверить это условие.
local function ApplyVisibility()
    if TodoList.mainFragment then TodoList.mainFragment:Refresh() end
    if TodoList.settingsFragment then TodoList.settingsFragment:Refresh() end
end

-- Создаёт фрагмент для окна один раз и добавляет его в сцены HUD и HUD UI.
local function CreateSceneFragment(control, conditionFunc)
    local fragment = ZO_SimpleSceneFragment:New(control)
    if conditionFunc then fragment:SetConditional(conditionFunc) end
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    return fragment
end

local function SetMainOpen(open)
    TodoList.saved.windowOpen = open and true or false
    ApplyVisibility()
end

local function ToggleMain()
    SetMainOpen(not TodoList.saved.windowOpen)
    return TodoList.saved.windowOpen
end

local function SetSettingsOpen(open)
    TodoList.settingsOpen = open and true or false
    ApplyVisibility()
end

---------------------------------------------------------------------------
-- Вспомогательные функции интерфейса
---------------------------------------------------------------------------

local function CreateBackdrop(name, parent, alpha)
    local backdrop = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    backdrop:SetAnchorFill(parent)
    backdrop:SetCenterColor(0.06, 0.06, 0.07, alpha or 0.94)
    backdrop:SetEdgeColor(0.65, 0.52, 0.25, alpha or 1)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    return backdrop
end

local function CreateLabel(name, parent, font, text)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or DEFAULT_FONT)
    label:SetText(text or "")
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

-- Тонкая золотистая линия-разделитель.
local function CreateDivider(parent, y, width)
    local d = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    d:SetDimensions(width, 1)
    d:SetAnchor(TOPLEFT, parent, TOPLEFT, 20, y)
    d:SetCenterColor(0.65, 0.52, 0.25, 0.55)
    d:SetEdgeColor(0, 0, 0, 0)
    return d
end

-- Плоская кнопка-«чип» с рамкой (используется для фильтров и настроек).
local function CreateChip(name, parent, text, font, width, height, onClick)
    local btn = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    btn:SetDimensions(width, height)
    btn:SetFont(font or "$(MEDIUM_FONT)|15|soft-shadow-thick")
    btn:SetText(text)
    btn:SetMouseOverFontColor(1, 0.92, 0.65, 1)

    local bd = WINDOW_MANAGER:CreateControl(nil, btn, CT_BACKDROP)
    bd:SetAnchorFill(btn)
    bd:SetEdgeTexture("", 1, 1, 1)

    if onClick then btn:SetHandler("OnClicked", onClick) end

    local chip = { btn = btn, bd = bd }
    return chip
end

local function StyleChip(chip, selected)
    if selected then
        chip.bd:SetEdgeColor(0.85, 0.70, 0.35, 1)
        chip.bd:SetCenterColor(0.85, 0.70, 0.35, 0.12)
        chip.btn:SetNormalFontColor(1, 0.86, 0.50, 1)
    else
        chip.bd:SetEdgeColor(0.35, 0.32, 0.28, 0.95)
        chip.bd:SetCenterColor(0, 0, 0, 0)
        chip.btn:SetNormalFontColor(0.82, 0.80, 0.74, 1)
    end
end

---------------------------------------------------------------------------
-- Данные: категории, фильтр, счётчики
---------------------------------------------------------------------------

local function GetFilter()
    local f = TodoList.saved and TodoList.saved.filter or "all"
    if f ~= "all" and not CATEGORIES[f] then f = "all" end
    return f
end

local function CycleCategory(task, backwards)
    -- состояния: 0 = без категории, 1..N = CATEGORY_ORDER
    local cur = 0
    for i, id in ipairs(CATEGORY_ORDER) do
        if id == task.category then cur = i end
    end
    local n = #CATEGORY_ORDER + 1
    cur = (cur + (backwards and -1 or 1)) % n
    if cur == 0 then
        task.category = nil
    else
        task.category = CATEGORY_ORDER[cur]
    end
end

-- Меняет категорию. Если включён фильтр — он переключается вслед за задачей,
-- поэтому задача не пропадает с экрана (даже если промежуточные категории пусты).
local function ChangeCategory(task, taskIndex, backwards)
    CycleCategory(task, backwards)
    if TodoList.saved.filter and TodoList.saved.filter ~= "all" then
        TodoList.saved.filter = task.category or "all"
    end
    TodoList.focusTask = taskIndex   -- RefreshList перейдёт на страницу с этой задачей
end

local function GetTaskText(task)
    local cat = task.category and CATEGORIES[task.category]
    if cat then
        local color = task.done and "6F8A6F" or cat.color
        return string.format("|c%s[%s]|r %s", color, cat.name, task.text)
    end
    return task.text
end

local function GetCounts()
    local total, done = 0, 0
    local data = GetData()
    if data and data.tasks then
        for _, t in ipairs(data.tasks) do
            total = total + 1
            if t.done then done = done + 1 end
        end
    end
    return total, done
end

local function CheckDailyReset()
    if not TodoList.saved or not TodoList.saved.autoResetDaily then return end
    local currentDay = math.floor(GetTimeStamp() / 86400)
    local data = GetData()
    if data.lastResetDay ~= currentDay then
        for _, task in ipairs(data.tasks) do
            task.done = false
        end
        data.lastResetDay = currentDay
    end
end

---------------------------------------------------------------------------
-- Метрики, измерение высоты строк и постраничная разбивка
---------------------------------------------------------------------------

local function GetMetrics()
    local s = TodoList.saved
    local bgAlpha = s.bgAlpha
    if bgAlpha == nil then bgAlpha = 0.94 end

    local spacing = s.rowSpacing
    if spacing == nil then spacing = DEFAULT_SPACING end
    spacing = math.max(0, math.min(12, spacing))

    local m = {
        isHud = (bgAlpha < 0.15),
        normalW = math.max(MIN_WINDOW_WIDTH, s.windowWidth or 460),
        normalH = s.windowHeight or 510,
    }

    if m.isHud then
        m.w = 320
        m.btnW = 312
        m.labelW = 268
        m.listTop = 8
        m.minRowH = 28
        m.pad = 4
        m.spacing = math.max(0, spacing - 1)
        m.budget = math.max(200, GuiRoot:GetHeight() - 140)
    else
        m.w = m.normalW
        m.btnW = m.normalW - 36
        m.labelW = m.normalW - 78
        m.listTop = LIST_TOP
        m.minRowH = 36
        m.pad = 8
        m.spacing = spacing
        m.budget = m.normalH - LIST_TOP - BOTTOM_PAD
    end
    return m
end

-- Высота текста с учётом переноса по словам (через невидимую метку-измеритель).
local function MeasureText(text, m)
    local font = TodoList.saved.fontName or DEFAULT_FONT
    local size = tonumber(font:match("|(%d+)|")) or 18
    local minH = size + 4

    local ml = TodoList.measureLabel
    if not ml then return minH end

    ml:SetFont(font)
    ml:SetWidth(m.labelW)
    ml:SetText(text)
    local h = ml:GetTextHeight() or 0
    if h < minH then h = minH end
    return h
end

-- Строит страницы так, чтобы строки (разной высоты) помещались в окно.
local function RebuildPages()
    local saved = TodoList.saved
    local m = GetMetrics()
    local filter = GetFilter()

    local filtered = {}
    for idx, task in ipairs(GetData().tasks) do
        if filter == "all" or task.category == filter then
            filtered[#filtered + 1] = idx
        end
    end
    TodoList.filtered = filtered

    local pages = {}
    local cur, curH = nil, 0
    for _, idx in ipairs(filtered) do
        local textH = MeasureText(GetTaskText(GetData().tasks[idx]), m)
        local rowH = math.max(m.minRowH, textH + m.pad)
        local need = rowH + m.spacing

        if not cur or #cur.items >= PAGE_SIZE or (#cur.items > 0 and curH + need > m.budget) then
            cur = { items = {}, heights = {}, textHs = {} }
            pages[#pages + 1] = cur
            curH = 0
        end
        local n = #cur.items + 1
        cur.items[n] = idx
        cur.heights[n] = rowH
        cur.textHs[n] = textH
        curH = curH + need
    end

    if #pages == 0 then
        pages[1] = { items = {}, heights = {}, textHs = {} }
    end
    TodoList.pages = pages
    return pages
end

local function GetPageCount()
    if not TodoList.saved or not GetData().tasks then return 1 end
    return math.max(1, #RebuildPages())
end

---------------------------------------------------------------------------
-- Раскладка окна
---------------------------------------------------------------------------

local function UpdateLayout()
    if not TodoList.window or not TodoList.saved then return end

    local m = GetMetrics()
    local bgAlpha = TodoList.saved.bgAlpha
    if bgAlpha == nil then bgAlpha = 0.94 end

    local isHudMode = m.isHud
    local isCollapsed = TodoList.saved.collapsed and not isHudMode
    local normalW, normalH = m.normalW, m.normalH
    local w = m.w

    local backdrop = WINDOW_MANAGER:GetControlByName("TodoListMainBackdrop")
    if backdrop then
        if isHudMode then
            backdrop:SetHidden(true)
        else
            backdrop:SetHidden(false)
            backdrop:SetCenterColor(0.06, 0.06, 0.07, bgAlpha)
            backdrop:SetEdgeColor(0.65, 0.52, 0.25, bgAlpha)
        end
    end

    local isLocked = TodoList.saved.locked or false
    TodoList.window:SetMovable(not isLocked)
    TodoList.window:SetClampedToScreen(true)

    if TodoList.buttonWindow then
        TodoList.buttonWindow:SetMovable(not isLocked)
    end

    for _, ctrl in ipairs(TodoList.chromeControls) do
        if ctrl then
            if isHudMode then
                ctrl:SetHidden(true)
            elseif isCollapsed then
                local keepInHeader = (ctrl == TodoList.titleLabel)
                    or (ctrl == TodoList.collapseBtn)
                    or (ctrl:GetName() == "TodoListSettingsOpenBtn")
                    or (ctrl:GetName() == "TodoListCloseButton")
                ctrl:SetHidden(not keepInHeader)
            else
                ctrl:SetHidden(false)
            end
        end
    end

    -- Кнопки фильтра категорий: ширина пропорциональна длине названия.
    if not isHudMode and not isCollapsed and #TodoList.filterChips > 0 then
        local gap = 4
        local avail = (normalW - 36) - gap * (#TodoList.filterChips - 1)
        local totalWeight = 0
        for _, chip in ipairs(TodoList.filterChips) do totalWeight = totalWeight + chip.weight end
        local x = 0
        for _, chip in ipairs(TodoList.filterChips) do
            local cw = math.floor(avail * chip.weight / totalWeight)
            chip.btn:ClearAnchors()
            chip.btn:SetAnchor(TOPLEFT, TodoList.window, TOPLEFT, 18 + x, 90)
            chip.btn:SetDimensions(cw, 24)
            x = x + cw + gap
        end
    end

    -- В HUD справа текст прижимается к правому краю экрана.
    local rightAligned = isHudMode
        and ((TodoList.window:GetLeft() or 0) + w / 2 > GuiRoot:GetWidth() / 2)

    local y = m.listTop
    local visibleTasksOnPage = 0

    for i = 1, PAGE_SIZE do
        local row = TodoList.rows[i]
        if row then
            row.strike:SetHidden(true)
            row.strike:SetDimensions(0, 0)

            if row.isEmpty then
                row.button:SetHidden(true)
            else
                local rowH = row.height or m.minRowH
                local textH = row.textH or (rowH - m.pad)
                local labelY = math.max(m.pad / 2, math.floor((rowH - textH) / 2))

                row.button:ClearAnchors()
                row.icon:ClearAnchors()
                row.label:ClearAnchors()

                if isHudMode and rightAligned then
                    row.button:SetAnchor(TOPRIGHT, TodoList.window, TOPRIGHT, -4, y)
                    row.icon:SetAnchor(TOPRIGHT, row.button, TOPRIGHT, -4, math.floor((m.minRowH - 22) / 2))
                    row.label:SetAnchor(TOPRIGHT, row.button, TOPRIGHT, -34, labelY)
                    row.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                else
                    row.button:SetAnchor(TOPLEFT, TodoList.window, TOPLEFT, isHudMode and 4 or 18, y)
                    row.icon:SetAnchor(TOPLEFT, row.button, TOPLEFT, 4, math.floor((m.minRowH - 22) / 2))
                    row.label:SetAnchor(TOPLEFT, row.button, TOPLEFT, 34, labelY)
                    row.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                end

                row.button:SetDimensions(m.btnW, rowH)
                row.label:SetDimensions(m.labelW, textH + 4)

                if isCollapsed then
                    row.button:SetHidden(true)
                else
                    row.button:SetHidden(false)
                    visibleTasksOnPage = visibleTasksOnPage + 1
                end

                y = y + rowH + m.spacing
            end
        end
    end

    -- Сообщение, если в выбранной категории нет задач.
    if TodoList.emptyLabel then
        local show = (not isHudMode) and (not isCollapsed) and (#TodoList.filtered == 0)
        TodoList.emptyLabel:SetHidden(not show)
        if show then
            local filter = GetFilter()
            if filter == "all" then
                TodoList.emptyLabel:SetText(L.EMPTY_ALL)
            else
                TodoList.emptyLabel:SetText(string.format(L.EMPTY_CAT, CATEGORIES[filter].name))
            end
            TodoList.emptyLabel:ClearAnchors()
            TodoList.emptyLabel:SetAnchor(TOP, TodoList.window, TOP, 0, LIST_TOP + 30)
            TodoList.emptyLabel:SetDimensions(normalW - 60, 30)
        end
    end

    if isCollapsed then
        TodoList.window:SetDimensions(normalW, 46)
    elseif isHudMode then
        TodoList.window:SetDimensions(w, math.max(36, y + 4))
    else
        -- Окно растёт, если длинные заметки не помещаются в заданную высоту.
        TodoList.window:SetDimensions(normalW, math.max(normalH, y + BOTTOM_PAD))
    end

    if TodoList.editBox then
        TodoList.editBox:SetDimensions(normalW - 130, 32)
    end

    if TodoList.collapseBtn then
        TodoList.collapseBtn:SetText(isCollapsed and "+" or "—")
    end
end

local function UpdateFilterChips()
    local filter = GetFilter()
    for _, chip in ipairs(TodoList.filterChips) do
        StyleChip(chip, chip.id == filter)
    end
end

local function UpdateEditHint()
    if not TodoList.editBox then return end
    local filter = GetFilter()
    if filter == "all" then
        TodoList.editBox:SetDefaultText(L.EDIT_HINT_ALL)
    else
        TodoList.editBox:SetDefaultText(string.format(L.EDIT_HINT_CAT, CATEGORIES[filter].name))
    end
end

local function UpdateButtonCounter()
    if not TodoList.counterLabel then return end
    local total, done = GetCounts()
    local remaining = total - done
    TodoList.counterLabel:SetText(string.format("%d/%d", remaining, total))
    if total > 0 and remaining == 0 then
        TodoList.counterLabel:SetColor(0.45, 0.85, 0.50, 1)
    else
        TodoList.counterLabel:SetColor(1, 0.92, 0.72, 1)
    end
end

local function RefreshList()
    if not TodoList.saved then return end

    local tasks = GetData().tasks
    local pages = RebuildPages()
    local pageCount = #pages
    if TodoList.focusTask then
        for p, pg in ipairs(pages) do
            for _, idx in ipairs(pg.items) do
                if idx == TodoList.focusTask then TodoList.page = p end
            end
        end
        TodoList.focusTask = nil
    end
    TodoList.page = math.max(1, math.min(TodoList.page, pageCount))
    local pageData = pages[TodoList.page]

    local total, doneTotal = GetCounts()

    for rowIndex = 1, PAGE_SIZE do
        local row = TodoList.rows[rowIndex]
        local taskIndex = pageData.items[rowIndex]
        local task = taskIndex and tasks[taskIndex]
        TodoList.pageTasks[rowIndex] = taskIndex

        if row then
            if task then
                row.isEmpty = false
                row.height = pageData.heights[rowIndex]
                row.textH = pageData.textHs[rowIndex]
                row.button:SetHidden(false)
                row.icon:SetHidden(false)
                row.label:SetHidden(false)
                row.label:SetText(GetTaskText(task))

                if task.done then
                    row.icon:SetTexture("EsoUI/Art/Miscellaneous/check.dds")
                    row.icon:SetColor(0.35, 0.9, 0.35, 1)
                    row.label:SetColor(0.50, 0.70, 0.52, 1)   -- приглушённо-зелёный
                else
                    row.icon:SetTexture("EsoUI/Art/Buttons/decline_up.dds")
                    row.icon:SetColor(0.95, 0.35, 0.35, 1)
                    row.label:SetColor(1.0, 0.93, 0.72, 1)    -- золотисто-белый
                end
                row.strike:SetHidden(true)
            else
                row.isEmpty = true
                row.button:SetHidden(true)
                row.icon:SetHidden(true)
                row.label:SetHidden(true)
                row.strike:SetHidden(true)
            end
        end
    end

    if TodoList.titleLabel then
        if TodoList.editingIndex then
            TodoList.titleLabel:SetText(L.TITLE_EDITING)
        elseif TodoList.saved.collapsed then
            TodoList.titleLabel:SetText(string.format(L.TITLE_COLLAPSED, doneTotal, total))
        else
            TodoList.titleLabel:SetText(L.TITLE)
        end
    end

    if TodoList.pageLabel then
        TodoList.pageLabel:SetText(string.format("%d / %d", TodoList.page, pageCount))
    end
    if TodoList.countLabel then
        TodoList.countLabel:SetText(string.format(L.COUNT_SUMMARY, total, doneTotal))
    end

    UpdateFilterChips()
    UpdateEditHint()
    UpdateButtonCounter()
    UpdateLayout()
end

---------------------------------------------------------------------------
-- Действия
---------------------------------------------------------------------------

local function CancelEdit()
    if TodoList.editingIndex then
        TodoList.editingIndex = nil
        if TodoList.editBox then TodoList.editBox:SetText("") end
        if TodoList.addButton then TodoList.addButton:SetText(L.ADD_BTN) end
    end
end

-- Редактирование: текст задачи попадает в поле ввода, Enter — сохранить, Esc — отмена.
local function StartEdit(taskIndex)
    local task = GetData().tasks[taskIndex]
    if not task or not TodoList.editBox then return end
    TodoList.editingIndex = taskIndex
    TodoList.editBox:SetText(task.text)
    if TodoList.addButton then TodoList.addButton:SetText(L.SAVE_BTN) end
    TodoList.editBox:TakeFocus()
end

local function AddTask()
    if not TodoList.editBox or not TodoList.saved then return end

    TodoList.editBox:TakeFocus()

    local text = TodoList.editBox:GetText()
    text = (text or ""):match("^%s*(.-)%s*$")

    -- Режим редактирования существующей задачи
    if TodoList.editingIndex then
        local idx = TodoList.editingIndex
        local task = GetData().tasks[idx]
        if task and text ~= "" then task.text = text end   -- пустой текст = отмена
        CancelEdit()
        TodoList.focusTask = idx
        RefreshList()
        return
    end

    if text == "" then return end

    local filter = GetFilter()
    table.insert(GetData().tasks, {
        text = text,
        done = false,
        category = (filter ~= "all") and filter or nil,
    })

    TodoList.editBox:SetText("")
    TodoList.page = GetPageCount()
    RefreshList()
    TodoList.editBox:TakeFocus()
end

-- Убирает выполненные задачи. При активном фильтре — только из видимой категории.
local function ClearCompleted()
    if not TodoList.saved then return end

    CancelEdit()
    local filter = GetFilter()
    local remaining = {}
    for _, task in ipairs(GetData().tasks) do
        local inScope = (filter == "all") or (task.category == filter)
        if not (task.done and inScope) then
            table.insert(remaining, task)
        end
    end

    GetData().tasks = remaining
    TodoList.page = 1
    RefreshList()
end

local function ApplyFonts()
    if not TodoList.saved then return end
    local fontName = TodoList.saved.fontName or DEFAULT_FONT

    if TodoList.titleLabel then TodoList.titleLabel:SetFont("$(BOLD_FONT)|22|soft-shadow-thick") end
    if TodoList.editBox then TodoList.editBox:SetFont(fontName) end
    if TodoList.countLabel then TodoList.countLabel:SetFont("$(MEDIUM_FONT)|15|soft-shadow-thick") end
    if TodoList.pageLabel then TodoList.pageLabel:SetFont(fontName) end

    for _, row in ipairs(TodoList.rows) do
        if row.label then row.label:SetFont(fontName) end
    end
end

---------------------------------------------------------------------------
-- Окно настроек
---------------------------------------------------------------------------

local SETTINGS_W, SETTINGS_H = 400, 640

local function CreateSettingsWindow()
    if TodoList.settingsWindow then return end

    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow("TodoListSettingsWindow")
    TodoList.settingsWindow = window

    window:SetDimensions(SETTINGS_W, SETTINGS_H)
    window:SetAnchor(CENTER, GuiRoot, CENTER, -260, 0)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)

    TodoList.settingsFragment = CreateSceneFragment(window, function()
        return TodoList.settingsOpen
    end)

    CreateBackdrop("TodoListSettingsBackdrop", window, 0.96)

    local contentW = SETTINGS_W - 40
    local refreshers = {}
    local function RefreshSettingsUI()
        for _, fn in ipairs(refreshers) do fn() end
    end
    TodoList.refreshSettingsUI = RefreshSettingsUI

    local FONT_LABEL = "$(MEDIUM_FONT)|17|soft-shadow-thick"
    local FONT_HINT = "$(MEDIUM_FONT)|13|soft-shadow-thick"
    local FONT_SECTION = "$(BOLD_FONT)|15|soft-shadow-thick"

    local function Section(text, y)
        local lbl = CreateLabel(nil, window, FONT_SECTION, text)
        lbl:SetAnchor(TOPLEFT, window, TOPLEFT, 20, y)
        lbl:SetDimensions(260, 22)
        lbl:SetColor(0.92, 0.78, 0.43, 1)
        return lbl
    end

    -- Заголовок и закрытие ------------------------------------------------
    local title = CreateLabel("TodoListSettingsTitle", window, "$(BOLD_FONT)|22|soft-shadow-thick", L.SETTINGS_TITLE)
    title:SetAnchor(TOP, window, TOP, 0, 12)
    title:SetColor(0.92, 0.78, 0.43, 1)

    local closeBtn = wm:CreateControl("TodoListSettingsClose", window, CT_BUTTON)
    closeBtn:SetDimensions(30, 28)
    closeBtn:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 8)
    closeBtn:SetFont("ZoFontGame")
    closeBtn:SetText("X")
    closeBtn:SetHandler("OnClicked", function()
        SetSettingsOpen(false)
    end)

    CreateDivider(window, 46, contentW)

    -- ВНЕШНИЙ ВИД: прозрачность ------------------------------------------
    Section(L.SEC_APPEARANCE, 56)

    local alphaLabel = CreateLabel(nil, window, FONT_LABEL, L.ALPHA_LABEL)
    alphaLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 80)
    alphaLabel:SetDimensions(220, 26)

    local alphaValLabel = CreateLabel(nil, window, "$(BOLD_FONT)|15|soft-shadow-thick", "")
    alphaValLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 80)
    alphaValLabel:SetDimensions(130, 26)
    alphaValLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    alphaValLabel:SetColor(0.92, 0.78, 0.43, 1)

    local trackW = contentW
    local track = wm:CreateControl("TodoListAlphaTrack", window, CT_CONTROL)
    track:SetDimensions(trackW, 22)
    track:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 110)
    track:SetMouseEnabled(true)

    local bar = wm:CreateControl(nil, track, CT_BACKDROP)
    bar:SetDimensions(trackW, 6)
    bar:SetAnchor(LEFT, track, LEFT, 0, 0)
    bar:SetCenterColor(0.14, 0.14, 0.15, 1)
    bar:SetEdgeColor(0, 0, 0, 0)

    local fill = wm:CreateControl(nil, track, CT_BACKDROP)
    fill:SetDimensions(1, 6)
    fill:SetAnchor(LEFT, track, LEFT, 0, 0)
    fill:SetCenterColor(0.78, 0.65, 0.32, 1)
    fill:SetEdgeColor(0, 0, 0, 0)

    local thumb = wm:CreateControl(nil, track, CT_BACKDROP)
    thumb:SetDimensions(8, 20)
    thumb:SetAnchor(LEFT, track, LEFT, 0, 0)
    thumb:SetCenterColor(0.96, 0.84, 0.50, 1)
    thumb:SetEdgeColor(0, 0, 0, 0)

    local function UpdateAlphaVisual()
        local val = TodoList.saved.bgAlpha
        if val == nil then val = 0.94 end
        fill:SetDimensions(math.max(1, trackW * val), 6)
        thumb:ClearAnchors()
        thumb:SetAnchor(LEFT, track, LEFT, math.max(0, math.min(trackW - 8, trackW * val - 4)), 0)
        local pct = math.floor(val * 100 + 0.5)
        if val < 0.15 then
            alphaValLabel:SetText(string.format(L.ALPHA_HUD, pct))
        else
            alphaValLabel:SetText(string.format("%d%%", pct))
        end
    end
    refreshers[#refreshers + 1] = UpdateAlphaVisual

    local dragging = false
    local function SetAlphaFromMouse()
        local mx = GetUIMousePosition()
        local frac = (mx - track:GetLeft()) / trackW
        frac = math.max(0, math.min(1, frac))
        local val = math.floor(frac * 20 + 0.5) / 20   -- шаг 5%
        local cur = TodoList.saved.bgAlpha
        if cur == nil then cur = 0.94 end
        if math.abs(val - cur) > 0.0001 then
            TodoList.saved.bgAlpha = val
            if val >= 0.15 then TodoList.saved.savedAlpha = val end
            UpdateAlphaVisual()
            RefreshList()
        end
    end

    -- В ESO нет IsMouseButtonDown(), поэтому конец перетаскивания ловим событием.
    local DRAG_EVENT_NAME = ADDON_NAME .. "_AlphaDrag"
    local function StopAlphaDrag()
        dragging = false
        EVENT_MANAGER:UnregisterForEvent(DRAG_EVENT_NAME, EVENT_GLOBAL_MOUSE_UP)
    end

    track:SetHandler("OnMouseDown", function(self, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            dragging = true
            EVENT_MANAGER:RegisterForEvent(DRAG_EVENT_NAME, EVENT_GLOBAL_MOUSE_UP, function(_, btn)
                if btn == MOUSE_BUTTON_INDEX_LEFT then StopAlphaDrag() end
            end)
            SetAlphaFromMouse()
        end
    end)
    track:SetHandler("OnMouseUp", function()
        StopAlphaDrag()
    end)
    track:SetHandler("OnUpdate", function()
        if dragging then SetAlphaFromMouse() end
    end)

    local hintL = CreateLabel(nil, window, FONT_HINT, L.ALPHA_HINT_L)
    hintL:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 134)
    hintL:SetDimensions(150, 18)
    hintL:SetColor(0.70, 0.70, 0.70, 1)

    local hintR = CreateLabel(nil, window, FONT_HINT, L.ALPHA_HINT_R)
    hintR:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 134)
    hintR:SetDimensions(150, 18)
    hintR:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hintR:SetColor(0.70, 0.70, 0.70, 1)

    local hintHud = CreateLabel(nil, window, FONT_HINT, L.ALPHA_HINT_HUD)
    hintHud:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 152)
    hintHud:SetDimensions(contentW, 18)
    hintHud:SetColor(0.60, 0.60, 0.60, 1)

    CreateDivider(window, 178, contentW)

    -- ШРИФТ ----------------------------------------------------------------
    Section(L.SEC_FONT, 188)

    local fonts = {
        { name = L.FONT_NORMAL, font = "$(MEDIUM_FONT)|18|soft-shadow-thick" },
        { name = L.FONT_LARGE,  font = "$(MEDIUM_FONT)|22|soft-shadow-thick" },
        { name = L.FONT_SMALL,  font = "$(MEDIUM_FONT)|15|soft-shadow-thick" },
        { name = L.FONT_BOLD,   font = "$(BOLD_FONT)|20|soft-shadow-thick" },
    }
    local fontChips = {}
    for index, fontInfo in ipairs(fonts) do
        local chip = CreateChip(nil, window, fontInfo.name, fontInfo.font, 175, 32, function()
            TodoList.saved.fontName = fontInfo.font
            ApplyFonts()
            RefreshList()
            RefreshSettingsUI()
        end)
        chip.btn:SetAnchor(TOPLEFT, window, TOPLEFT,
            20 + ((index - 1) % 2) * 185, 214 + math.floor((index - 1) / 2) * 38)
        chip.font = fontInfo.font
        fontChips[#fontChips + 1] = chip
    end
    refreshers[#refreshers + 1] = function()
        local current = TodoList.saved.fontName or DEFAULT_FONT
        for _, chip in ipairs(fontChips) do
            StyleChip(chip, chip.font == current)
        end
    end

    CreateDivider(window, 292, contentW)

    -- РАЗМЕР ОКНА ----------------------------------------------------------
    Section(L.SEC_SIZE, 302)

    local sizeValLabel = CreateLabel(nil, window, "$(BOLD_FONT)|15|soft-shadow-thick", "")
    sizeValLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 302)
    sizeValLabel:SetDimensions(130, 22)
    sizeValLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    sizeValLabel:SetColor(0.92, 0.78, 0.43, 1)
    refreshers[#refreshers + 1] = function()
        local s = TodoList.saved
        sizeValLabel:SetText(string.format("%d × %d",
            math.max(MIN_WINDOW_WIDTH, s.windowWidth or 460), s.windowHeight or 510))
    end

    local function SizeRow(y, labelText, onMinus, onPlus)
        local lbl = CreateLabel(nil, window, FONT_LABEL, labelText)
        lbl:SetAnchor(TOPLEFT, window, TOPLEFT, 20, y)
        lbl:SetDimensions(85, 30)

        local minus = CreateChip(nil, window, "−", "$(BOLD_FONT)|18|soft-shadow-thick", 44, 30, function()
            onMinus()
            RefreshList()
            RefreshSettingsUI()
        end)
        minus.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 110, y)
        StyleChip(minus, false)

        local plus = CreateChip(nil, window, "+", "$(BOLD_FONT)|18|soft-shadow-thick", 44, 30, function()
            onPlus()
            RefreshList()
            RefreshSettingsUI()
        end)
        plus.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 160, y)
        StyleChip(plus, false)
    end

    SizeRow(330, L.SIZE_WIDTH,
        function() TodoList.saved.windowWidth = math.max(MIN_WINDOW_WIDTH, (TodoList.saved.windowWidth or 460) - 30) end,
        function() TodoList.saved.windowWidth = math.min(850, (TodoList.saved.windowWidth or 460) + 30) end)
    SizeRow(368, L.SIZE_HEIGHT,
        function() TodoList.saved.windowHeight = math.max(430, (TodoList.saved.windowHeight or 510) - 30) end,
        function() TodoList.saved.windowHeight = math.min(850, (TodoList.saved.windowHeight or 510) + 30) end)

    local resetSize = CreateChip(nil, window, L.SIZE_RESET, "ZoFontGameSmall", 110, 68, function()
        TodoList.saved.windowWidth = 460
        TodoList.saved.windowHeight = 510
        RefreshList()
        RefreshSettingsUI()
    end)
    resetSize.btn:SetAnchor(TOPRIGHT, window, TOPRIGHT, -20, 330)
    StyleChip(resetSize, false)

    -- Интервал между задачами
    local spacingLabel = CreateLabel(nil, window, FONT_LABEL, L.ROW_SPACING)
    spacingLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 408)
    spacingLabel:SetDimensions(240, 30)

    local spacingVal = CreateLabel(nil, window, "$(BOLD_FONT)|15|soft-shadow-thick", "")
    spacingVal:SetAnchor(TOPLEFT, window, TOPLEFT, 302, 408)
    spacingVal:SetDimensions(46, 30)
    spacingVal:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    spacingVal:SetColor(0.92, 0.78, 0.43, 1)

    local function GetSpacing()
        local v = TodoList.saved.rowSpacing
        if v == nil then v = DEFAULT_SPACING end
        return v
    end
    refreshers[#refreshers + 1] = function()
        spacingVal:SetText(tostring(GetSpacing()))
    end

    local spMinus = CreateChip(nil, window, "−", "$(BOLD_FONT)|18|soft-shadow-thick", 32, 30, function()
        TodoList.saved.rowSpacing = math.max(0, GetSpacing() - 1)
        RefreshList()
        RefreshSettingsUI()
    end)
    spMinus.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 268, 408)
    StyleChip(spMinus, false)

    local spPlus = CreateChip(nil, window, "+", "$(BOLD_FONT)|18|soft-shadow-thick", 32, 30, function()
        TodoList.saved.rowSpacing = math.min(12, GetSpacing() + 1)
        RefreshList()
        RefreshSettingsUI()
    end)
    spPlus.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 348, 408)
    StyleChip(spPlus, false)

    CreateDivider(window, 448, contentW)

    -- ПОВЕДЕНИЕ ------------------------------------------------------------
    Section(L.SEC_BEHAVIOR, 458)

    local function ToggleRow(y, labelText, getter, setter)
        local row = wm:CreateControl(nil, window, CT_BUTTON)
        row:SetDimensions(contentW, 30)
        row:SetAnchor(TOPLEFT, window, TOPLEFT, 20, y)

        local lbl = CreateLabel(nil, row, FONT_LABEL, labelText)
        lbl:SetAnchor(LEFT, row, LEFT, 0, 0)
        lbl:SetDimensions(280, 30)

        local pillBg = wm:CreateControl(nil, row, CT_BACKDROP)
        pillBg:SetDimensions(58, 22)
        pillBg:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        pillBg:SetEdgeColor(0, 0, 0, 0)

        local pill = CreateLabel(nil, row, "$(BOLD_FONT)|14|soft-shadow-thick", "")
        pill:SetDimensions(58, 22)
        pill:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        pill:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

        local function Update()
            if getter() then
                pill:SetText(L.STATE_ON)
                pill:SetColor(0.45, 0.95, 0.50, 1)
                pillBg:SetCenterColor(0.10, 0.35, 0.14, 0.9)
            else
                pill:SetText(L.STATE_OFF)
                pill:SetColor(0.70, 0.70, 0.70, 1)
                pillBg:SetCenterColor(0.18, 0.18, 0.19, 0.9)
            end
        end
        refreshers[#refreshers + 1] = Update

        row:SetHandler("OnClicked", function()
            setter(not getter())
            Update()
        end)
    end

    ToggleRow(484, L.OPT_LOCK,
        function() return TodoList.saved.locked or false end,
        function(v)
            TodoList.saved.locked = v
            UpdateLayout()
        end)

    ToggleRow(518, L.OPT_DAILY_RESET,
        function() return TodoList.saved.autoResetDaily or false end,
        function(v)
            TodoList.saved.autoResetDaily = v
            if v then
                GetData().lastResetDay = math.floor(GetTimeStamp() / 86400)
            end
        end)

    ToggleRow(552, L.OPT_PER_CHARACTER,
        function() return TodoList.saved.perCharacter or false end,
        function(v)
            CancelEdit()
            TodoList.saved.perCharacter = v
            TodoList.page = 1
            CheckDailyReset()
            RefreshList()
        end)

    CreateDivider(window, 590, contentW)

    -- Сброс всех настроек (с подтверждением вторым нажатием) ---------------
    local RESET_TEXT = L.RESET_ALL
    local confirming = false
    local resetAll
    resetAll = CreateChip(nil, window, RESET_TEXT, "ZoFontGameSmall", contentW, 30, function()
        if not confirming then
            confirming = true
            resetAll.btn:SetText(L.RESET_CONFIRM)
            zo_callLater(function()
                confirming = false
                resetAll.btn:SetText(RESET_TEXT)
            end, 3000)
            return
        end

        confirming = false
        resetAll.btn:SetText(RESET_TEXT)

        local s = TodoList.saved
        s.bgAlpha = 0.94
        s.savedAlpha = 0.94
        s.fontName = DEFAULT_FONT
        s.windowWidth = 460
        s.windowHeight = 510
        s.rowSpacing = DEFAULT_SPACING
        s.locked = false
        s.autoResetDaily = false
        s.collapsed = false

        ApplyFonts()
        RefreshList()
        RefreshSettingsUI()
    end)
    resetAll.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 600)
    StyleChip(resetAll, false)
    resetAll.bd:SetEdgeColor(0.75, 0.35, 0.30, 0.9)

    RefreshSettingsUI()
end

---------------------------------------------------------------------------
-- Основное окно
---------------------------------------------------------------------------

local function CreateMainWindow()
    if TodoList.window then return end

    local wm = WINDOW_MANAGER
    local window = wm:CreateTopLevelWindow("TodoListMainWindow")
    TodoList.window = window
    TodoList.chromeControls = {}

    if TodoList.saved.windowX and TodoList.saved.windowY then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TodoList.saved.windowX, TodoList.saved.windowY)
    else
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end

    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetHidden(true)
    window:SetHandler("OnMoveStop", function(self)
        TodoList.saved.windowX = self:GetLeft()
        TodoList.saved.windowY = self:GetTop()
        UpdateLayout()
    end)

    CreateBackdrop("TodoListMainBackdrop", window, TodoList.saved.bgAlpha or 0.94)

    -- Невидимая метка для измерения высоты переносимого текста.
    local measure = CreateLabel("TodoListMeasureLabel", window, DEFAULT_FONT, "")
    measure:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    measure:SetAlpha(0)
    measure:SetMouseEnabled(false)
    TodoList.measureLabel = measure

    TodoList.titleLabel = CreateLabel("TodoListTitle", window, "$(BOLD_FONT)|22|soft-shadow-thick", L.TITLE)
    TodoList.titleLabel:SetAnchor(TOP, window, TOP, 0, 12)
    TodoList.titleLabel:SetColor(0.92, 0.78, 0.43, 1)
    table.insert(TodoList.chromeControls, TodoList.titleLabel)

    local settingsButton = wm:CreateControl("TodoListSettingsOpenBtn", window, CT_BUTTON)
    settingsButton:SetDimensions(32, 32)
    settingsButton:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 8)
    settingsButton:SetNormalTexture("EsoUI/Art/ChatWindow/chat_options_up.dds")
    settingsButton:SetPressedTexture("EsoUI/Art/ChatWindow/chat_options_down.dds")
    settingsButton:SetMouseOverTexture("EsoUI/Art/ChatWindow/chat_options_over.dds")
    settingsButton:SetHandler("OnClicked", function()
        CreateSettingsWindow()
        SetSettingsOpen(not TodoList.settingsOpen)
        if TodoList.settingsOpen and TodoList.refreshSettingsUI then TodoList.refreshSettingsUI() end
    end)
    table.insert(TodoList.chromeControls, settingsButton)

    local collapseBtn = wm:CreateControl("TodoListCollapseButton", window, CT_BUTTON)
    TodoList.collapseBtn = collapseBtn
    collapseBtn:SetDimensions(28, 28)
    collapseBtn:SetAnchor(TOPRIGHT, window, TOPRIGHT, -40, 8)
    collapseBtn:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    collapseBtn:SetText("—")
    collapseBtn:SetHandler("OnClicked", function()
        TodoList.saved.collapsed = not TodoList.saved.collapsed
        RefreshList()
    end)
    table.insert(TodoList.chromeControls, collapseBtn)

    local closeButton = wm:CreateControl("TodoListCloseButton", window, CT_BUTTON)
    closeButton:SetDimensions(28, 28)
    closeButton:SetAnchor(TOPRIGHT, window, TOPRIGHT, -8, 8)
    closeButton:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    closeButton:SetText("X")
    closeButton:SetHandler("OnClicked", function()
        SetMainOpen(false)
    end)
    table.insert(TodoList.chromeControls, closeButton)

    TodoList.editBox = wm:CreateControl("TodoListTaskEditBox", window, CT_EDITBOX)
    TodoList.editBox:SetDimensions(330, 32)
    TodoList.editBox:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 52)
    TodoList.editBox:SetFont(DEFAULT_FONT)
    TodoList.editBox:SetText("")
    TodoList.editBox:SetDefaultText(L.EDIT_HINT_ALL)
    TodoList.editBox:SetMouseEnabled(true)
    TodoList.editBox:SetMaxInputChars(MAX_TASK_CHARS)
    TodoList.editBox:SetHandler("OnEnter", function()
        AddTask()
    end)
    TodoList.editBox:SetHandler("OnEscape", function()
        if TodoList.editingIndex then
            CancelEdit()
            RefreshList()
        end
        TodoList.editBox:LoseFocus()
    end)
    table.insert(TodoList.chromeControls, TodoList.editBox)

    local addButton = wm:CreateControl("TodoListAddButton", window, CT_BUTTON)
    addButton:SetDimensions(88, 32)
    addButton:SetAnchor(LEFT, TodoList.editBox, RIGHT, 8, 0)
    addButton:SetFont("ZoFontGame")
    addButton:SetText(L.ADD_BTN)
    addButton:SetNormalTexture("EsoUI/Art/Buttons/standard_button_up.dds")
    addButton:SetPressedTexture("EsoUI/Art/Buttons/standard_button_down.dds")
    addButton:SetHandler("OnClicked", AddTask)
    TodoList.addButton = addButton
    table.insert(TodoList.chromeControls, addButton)

    -- Фильтр по категориям -------------------------------------------------
    TodoList.filterChips = {}
    for _, id in ipairs(FILTER_ORDER) do
        local text = (id == "all") and L.FILTER_ALL or CATEGORIES[id].name
        local chip = CreateChip("TodoListFilterChip_" .. id, window, text,
            "$(MEDIUM_FONT)|14|soft-shadow-thick", 60, 24, function()
                TodoList.saved.filter = id
                TodoList.page = 1
                RefreshList()
            end)
        chip.id = id
        chip.weight = zo_strlen(text) + 3
        chip.btn:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 90)
        StyleChip(chip, false)
        TodoList.filterChips[#TodoList.filterChips + 1] = chip
        table.insert(TodoList.chromeControls, chip.btn)
    end

    TodoList.emptyLabel = CreateLabel("TodoListEmptyLabel", window, "$(MEDIUM_FONT)|16|soft-shadow-thick", "")
    TodoList.emptyLabel:SetAnchor(TOP, window, TOP, 0, LIST_TOP + 30)
    TodoList.emptyLabel:SetDimensions(400, 30)
    TodoList.emptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    TodoList.emptyLabel:SetColor(0.65, 0.65, 0.65, 1)
    TodoList.emptyLabel:SetHidden(true)

    -- Строки задач ---------------------------------------------------------
    for i = 1, PAGE_SIZE do
        local rowButton = wm:CreateControl("TodoListRowButton" .. i, window, CT_BUTTON)
        rowButton:SetDimensions(420, 36)
        rowButton:SetAnchor(TOPLEFT, window, TOPLEFT, 18, LIST_TOP + (i - 1) * 39)
        rowButton:SetMouseEnabled(true)

        local hudMouseDownX, hudMouseDownY

        rowButton:SetHandler("OnMouseDown", function(self, mouseButton)
            if mouseButton == MOUSE_BUTTON_INDEX_LEFT
                and TodoList.saved
                and (TodoList.saved.bgAlpha or 0.94) < 0.15
                and not (TodoList.saved.locked or false) then

                -- В прозрачном режиме зажатие ЛКМ на задаче двигает
                -- всё окно со списком, а не отдельную строку.
                hudMouseDownX = TodoList.window:GetLeft()
                hudMouseDownY = TodoList.window:GetTop()
                TodoList.window:StartMoving()
            end
        end)

        rowButton:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
            local isHudMode = TodoList.saved
                and (TodoList.saved.bgAlpha or 0.94) < 0.15

            if mouseButton == MOUSE_BUTTON_INDEX_LEFT and isHudMode
                and hudMouseDownX and hudMouseDownY then
                TodoList.window:StopMovingOrResizing()

                local newX = TodoList.window:GetLeft()
                local newY = TodoList.window:GetTop()
                local wasDragged = math.abs(newX - hudMouseDownX) > 3
                    or math.abs(newY - hudMouseDownY) > 3

                TodoList.saved.windowX = newX
                TodoList.saved.windowY = newY
                hudMouseDownX = nil
                hudMouseDownY = nil

                -- Перетаскивание только перемещает список.
                -- Короткий клик без движения отмечает задачу.
                if wasDragged then return end
            end

            if not upInside then return end
            local taskIndex = TodoList.pageTasks[i]
            local task = taskIndex and GetData().tasks[taskIndex]
            if not task then return end

            if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
                if IsShiftKeyDown() then
                    ChangeCategory(task, taskIndex, false)
                elseif IsControlKeyDown() then
                    ChangeCategory(task, taskIndex, true)
                else
                    -- Двойной клик (два нажатия по одной задаче за 350 мс) = редактирование.
                    -- Первое нажатие уже переключило галочку, поэтому второе откатывает её.
                    local now = GetGameTimeMilliseconds()
                    if TodoList.lastClickIndex == taskIndex and TodoList.lastClickTime
                        and (now - TodoList.lastClickTime) < 350 then
                        TodoList.lastClickIndex = nil
                        task.done = not task.done
                        if not isHudMode then StartEdit(taskIndex) end
                    else
                        TodoList.lastClickIndex = taskIndex
                        TodoList.lastClickTime = now
                        task.done = not task.done
                    end
                end
                RefreshList()
            elseif mouseButton == MOUSE_BUTTON_INDEX_MIDDLE then
                ChangeCategory(task, taskIndex, IsShiftKeyDown())
                RefreshList()
            elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT then
                CancelEdit()
                table.remove(GetData().tasks, taskIndex)
                RefreshList()
            end
        end)

        rowButton:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, LEFT, 5, 0)
            if TodoList.saved and (TodoList.saved.bgAlpha or 0.94) < 0.15 then
                SetTooltipText(InformationTooltip, L.TOOLTIP_HUD)
            else
                SetTooltipText(InformationTooltip, L.TOOLTIP_NORMAL .. "\n" .. L.TOOLTIP_EDIT)
            end
        end)
        rowButton:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)

        local icon = wm:CreateControl("TodoListRowIcon" .. i, rowButton, CT_TEXTURE)
        icon:SetDimensions(22, 22)
        icon:SetAnchor(TOPLEFT, rowButton, TOPLEFT, 4, 7)
        icon:SetTexture("EsoUI/Art/Buttons/decline_up.dds")

        local label = CreateLabel("TodoListRowLabel" .. i, rowButton, DEFAULT_FONT, "")
        label:SetAnchor(TOPLEFT, rowButton, TOPLEFT, 34, 2)
        label:SetDimensions(380, 32)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

        local strike = wm:CreateControl("TodoListStrike" .. i, rowButton, CT_TEXTURE)
        strike:SetDimensions(0, 0)
        strike:SetAnchor(LEFT, icon, RIGHT, 8, 1)
        strike:SetHidden(true)

        TodoList.rows[i] = {
            button = rowButton,
            icon = icon,
            label = label,
            strike = strike,
            isEmpty = true,
            height = 36,
            textH = 22,
        }
    end

    -- Нижняя панель --------------------------------------------------------
    TodoList.countLabel = CreateLabel("TodoListCountLabel", window, "$(MEDIUM_FONT)|15|soft-shadow-thick", "")
    TodoList.countLabel:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 20, -48)
    TodoList.countLabel:SetDimensions(270, 24)
    TodoList.countLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    table.insert(TodoList.chromeControls, TodoList.countLabel)

    TodoList.pageLabel = CreateLabel("TodoListPageLabel", window, DEFAULT_FONT, "")
    TodoList.pageLabel:SetAnchor(BOTTOM, window, BOTTOM, 0, -15)
    TodoList.pageLabel:SetDimensions(80, 25)
    table.insert(TodoList.chromeControls, TodoList.pageLabel)

    local previousButton = wm:CreateControl("TodoListPreviousButton", window, CT_BUTTON)
    previousButton:SetDimensions(36, 28)
    previousButton:SetAnchor(RIGHT, TodoList.pageLabel, LEFT, -8, 0)
    previousButton:SetFont("ZoFontGame")
    previousButton:SetText("<")
    previousButton:SetHandler("OnClicked", function()
        TodoList.page = math.max(1, TodoList.page - 1)
        RefreshList()
    end)
    table.insert(TodoList.chromeControls, previousButton)

    local nextButton = wm:CreateControl("TodoListNextButton", window, CT_BUTTON)
    nextButton:SetDimensions(36, 28)
    nextButton:SetAnchor(LEFT, TodoList.pageLabel, RIGHT, 8, 0)
    nextButton:SetFont("ZoFontGame")
    nextButton:SetText(">")
    nextButton:SetHandler("OnClicked", function()
        TodoList.page = math.min(GetPageCount(), TodoList.page + 1)
        RefreshList()
    end)
    table.insert(TodoList.chromeControls, nextButton)

    local clearButton = wm:CreateControl("TodoListClearButton", window, CT_BUTTON)
    clearButton:SetDimensions(155, 28)
    clearButton:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -16, -14)
    clearButton:SetFont("ZoFontGameSmall")
    clearButton:SetText(L.CLEAR_COMPLETED)
    clearButton:SetHandler("OnClicked", ClearCompleted)
    table.insert(TodoList.chromeControls, clearButton)

    ApplyFonts()
    UpdateLayout()
end

---------------------------------------------------------------------------
-- Кнопка TDL со счётчиком
---------------------------------------------------------------------------

local function CreateToggleButton()
    if TodoList.buttonWindow then return end

    local wm = WINDOW_MANAGER
    local buttonWindow = wm:CreateTopLevelWindow("TodoListToggleWindow")
    TodoList.buttonWindow = buttonWindow
    buttonWindow:SetDimensions(44, 44)

    if TodoList.saved.buttonX and TodoList.saved.buttonY then
        buttonWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TodoList.saved.buttonX, TodoList.saved.buttonY)
    else
        buttonWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, -100)
    end

    buttonWindow:SetMovable(not (TodoList.saved.locked or false))
    buttonWindow:SetMouseEnabled(true)
    buttonWindow:SetClampedToScreen(true)
    buttonWindow:SetHidden(false)

    local bg = wm:CreateControl("TodoListToggleBg", buttonWindow, CT_BACKDROP)
    bg:SetAnchorFill(buttonWindow)
    bg:SetCenterColor(0.035, 0.03, 0.025, 0.94)
    bg:SetEdgeColor(0.78, 0.63, 0.30, 1)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)

    local button = wm:CreateControl("TodoListToggleButton", buttonWindow, CT_BUTTON)
    button:SetAnchorFill(buttonWindow)
    button:SetMouseEnabled(true)

    -- Эмблема TDL сверху, счётчик «осталось/всего» снизу.
    local iconLabel = CreateLabel("TodoListToggleIconLabel", button,
        "$(BOLD_FONT)|17|soft-shadow-thick", "TDL")
    iconLabel:SetAnchor(TOP, button, TOP, 0, 4)
    iconLabel:SetDimensions(44, 20)
    iconLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    iconLabel:SetColor(0.96, 0.89, 0.70, 1)

    local counter = CreateLabel("TodoListToggleCounter", button,
        "$(MEDIUM_FONT)|13|soft-shadow-thick", "0/0")
    counter:SetAnchor(BOTTOM, button, BOTTOM, 0, -4)
    counter:SetDimensions(44, 16)
    counter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    counter:SetColor(1, 0.92, 0.72, 1)
    TodoList.counterLabel = counter

    local isDragging = false

    button:SetHandler("OnMouseDown", function(self, mouseButton)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT and not TodoList.saved.locked then
            isDragging = false
            buttonWindow:StartMoving()
        end
    end)

    button:SetHandler("OnMouseUp", function(self, mouseButton, upInside)
        if mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            local oldX = TodoList.saved.buttonX
            local oldY = TodoList.saved.buttonY
            buttonWindow:StopMovingOrResizing()
            local newX = buttonWindow:GetLeft()
            local newY = buttonWindow:GetTop()

            if oldX and oldY and (math.abs(newX - oldX) > 3 or math.abs(newY - oldY) > 3) then
                isDragging = true
            end

            TodoList.saved.buttonX = newX
            TodoList.saved.buttonY = newY

            if upInside and not isDragging then
                local opened = ToggleMain()
                if opened and TodoList.editBox and not TodoList.editBox:IsHidden() then
                    TodoList.editBox:TakeFocus()
                end
            end
            isDragging = false
        elseif mouseButton == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            if (TodoList.saved.bgAlpha or 0.94) >= 0.15 then
                TodoList.saved.savedAlpha = TodoList.saved.bgAlpha or 0.94
                TodoList.saved.bgAlpha = 0.0
            else
                TodoList.saved.bgAlpha = TodoList.saved.savedAlpha or 0.94
            end
            SetMainOpen(true)
            RefreshList()
            if TodoList.refreshSettingsUI then TodoList.refreshSettingsUI() end
        end
    end)

    button:SetHandler("OnMouseEnter", function(self)
        iconLabel:SetColor(1, 0.78, 0.30, 1)
        local total, done = GetCounts()
        InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
        SetTooltipText(InformationTooltip, string.format(L.BTN_TOOLTIP, total - done, total))
    end)
    button:SetHandler("OnMouseExit", function()
        iconLabel:SetColor(0.96, 0.89, 0.70, 1)
        ClearTooltip(InformationTooltip)
    end)
end

---------------------------------------------------------------------------
-- Загрузка аддона
---------------------------------------------------------------------------

local function OnAddonLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then return end

    -- Обновляем язык на момент загрузки, если клиент успел переключить настройки
    CURRENT_LANG = GetClientLanguage()
    L = LOCALIZATION[CURRENT_LANG]

    CATEGORIES.home.name = L.CAT_HOME
    CATEGORIES.craft.name = L.CAT_CRAFT
    CATEGORIES.adventure.name = L.CAT_ADVENTURE
    CATEGORIES.shopping.name = L.CAT_SHOPPING

    TodoList.saved = ZO_SavedVars:NewAccountWide(
        "TodoListSavedVariables",
        1,
        nil,
        {
            tasks = {},
            buttonX = nil,
            buttonY = nil,
            windowX = nil,
            windowY = nil,
            windowWidth = 460,
            windowHeight = 510,
            bgAlpha = 0.94,
            savedAlpha = 0.94,
            fontName = DEFAULT_FONT,
            locked = false,
            collapsed = false,
            autoResetDaily = false,
            lastResetDay = 0,
            rowSpacing = DEFAULT_SPACING,
            filter = "all",
            windowOpen = false,
            perCharacter = false,
        }
    )

    if type(TodoList.saved.tasks) ~= "table" then
        TodoList.saved.tasks = {}
    end

    -- Отдельные данные персонажа (задачи + день последнего сброса)
    local charDefaults = { tasks = {}, lastResetDay = 0 }
    if ZO_SavedVars.NewCharacterIdSettings then
        TodoList.charSaved = ZO_SavedVars:NewCharacterIdSettings(
            "TodoListSavedVariables", 1, "Characters", charDefaults)
    else
        TodoList.charSaved = ZO_SavedVars:New(
            "TodoListSavedVariables", 1, "Characters", charDefaults)
    end
    if TodoList.charSaved and type(TodoList.charSaved.tasks) ~= "table" then
        TodoList.charSaved.tasks = {}
    end

    CheckDailyReset()
    CreateMainWindow()
    CreateToggleButton()
    RefreshList()

    -- Окна показываются только в HUD / HUD UI и сами прячутся в меню и диалогах.
    TodoList.mainFragment = CreateSceneFragment(TodoList.window, function()
        return TodoList.saved.windowOpen == true
    end)
    TodoList.buttonFragment = CreateSceneFragment(TodoList.buttonWindow)
    ApplyVisibility()

    ZO_PreHook("ZO_LinkHandler_OnLinkClicked", function(link, button, control)
        if TodoList.editBox and TodoList.editBox:HasFocus() then
            TodoList.editBox:InsertText(link)
            return true
        end
    end)

    SLASH_COMMANDS["/todo"] = function()
        ToggleMain()
    end

    SLASH_COMMANDS["/todosettings"] = function()
        CreateSettingsWindow()
        SetSettingsOpen(not TodoList.settingsOpen)
        if TodoList.settingsOpen and TodoList.refreshSettingsUI then TodoList.refreshSettingsUI() end
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, REGISTER_FILTER_ADDON_NAME, ADDON_NAME)
