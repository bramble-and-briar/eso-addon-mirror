local AlabuzyaUI = AlabuzyaUI
-- Independent feature settings; style changes are applied only after ReloadUI.
AlabuzyaUI.Settings = {}
local S = AlabuzyaUI.Settings
S.defaults = {
    style = 'diablo',
    charge = { enabled = true, threshold = 10, crown = true },
    repair = { enabled = true, threshold = 10, crown = true },
    assistantPanel = true, junk = true, chat = true, grid = true, questArrow = true,
    guildBackground = true,
}
local saved, loadedStyle
function S.Get()
    if not saved then
        saved = AlabuzyaUI.SavedVariables.Account('features', S.defaults)
        -- Migrate the previous theme ID without changing saved layout keys.
        if saved.style == 'classic' then saved.style = 'wow' end
        if saved.style ~= 'diablo' and saved.style ~= 'wow' and saved.style ~= 'ds3' and saved.style ~= 'none' then saved.style = 'diablo' end
        for _, kind in ipairs({'charge', 'repair'}) do
            saved[kind].threshold = math.max(1, math.min(90, tonumber(saved[kind].threshold) or 10))
        end
        loadedStyle = saved.style
    end
    return saved
end
function S.StyleEnabled()
    S.Get()
    return loadedStyle ~= 'none'
end
function S.Style() S.Get() return loadedStyle end
function S.Enabled(key) return S.Get()[key] ~= false end
function S.Maintenance(kind) return S.Get()[kind] end

local function RegisterPanel()
    local db = S.Get()
    local LAM = LibAddonMenu2
    if not LAM then
        -- Optional dependency: the addon still loads if the library is missing.
        SLASH_COMMANDS['/alabuzyaui'] = function()
            d('Alabuzya UI: install LibAddonMenu-2.0 to open settings / установите LibAddonMenu-2.0 для настроек.')
        end
        SLASH_COMMANDS['/alabuzya'] = SLASH_COMMANDS['/alabuzyaui']
        SLASH_COMMANDS['/diaui'] = SLASH_COMMANDS['/alabuzyaui'] -- previous command remains usable
        return
    end
    local ru = GetCVar('language.2') == 'ru'
    local function L(a,b) return ru and a or b end
    local panel = LAM:RegisterAddonPanel('AlabuzyaUIOptions', {
        type='panel', name='Alabuzya UI', displayName='Alabuzya UI', author='alabuzya', version='0.1.54',
        registerForRefresh=true, registerForDefaults=true,
    })
    SLASH_COMMANDS['/alabuzyaui'] = function() LAM:OpenToPanel(panel) end
    SLASH_COMMANDS['/alabuzya'] = SLASH_COMMANDS['/alabuzyaui']
    SLASH_COMMANDS['/diaui'] = SLASH_COMMANDS['/alabuzyaui'] -- compatibility alias
    local function Toggle(key, name, tooltip, reload)
        return {type='checkbox', name=name, tooltip=tooltip,
            getFunc=function() return db[key] end, setFunc=function(v) db[key]=v end,
            default=S.defaults[key], needsReload=reload or false}
    end
    local function Maintenance(kind, title)
        local config = db[kind]
        return {type='submenu', name=title, controls={
            {type='checkbox', name=L('Включить', 'Enable'),
                getFunc=function() return config.enabled end, setFunc=function(v) config.enabled=v end,
                default=S.defaults[kind].enabled},
            {type='slider', name=L('Порог, %', 'Threshold, %'), min=1, max=90, step=1,
                tooltip=L('Срабатывает, когда оставшийся заряд или прочность не выше выбранного процента. Используются материалы из рюкзака.', 'Runs when remaining charge or condition is at or below this percentage. Uses backpack materials.'),
                getFunc=function() return config.threshold end,
                setFunc=function(v) config.threshold=math.max(1,math.min(90,math.floor(v))) end,
                default=10, disabled=function() return not config.enabled end},
            {type='checkbox', name=L('Разрешить кронные материалы', 'Allow Crown materials'),
                tooltip=L('Обычные материалы используются первыми. Кронные — только если подходящих обычных нет. Ничего не покупает.', 'Uses regular materials first, then Crown materials if no suitable regular ones remain. Never purchases materials.'),
                getFunc=function() return config.crown end, setFunc=function(v) config.crown=v end,
                default=S.defaults[kind].crown, disabled=function() return not config.enabled end},
        }}
    end
    LAM:RegisterOptionControls('AlabuzyaUIOptions', {
        {type='description', text=L('Настройки общие для персонажей одного аккаунта на текущем сервере. Зарядка, ремонт, мусор и функции чата работают независимо от оформления. Связь: aabuziarov@gmail.com', 'Account-wide settings, separate for each server. Recharge, repair, junk selling and chat helpers work independently of the skin. Contact: aabuziarov@gmail.com')},
        {type='submenu', name=L('Интерфейсы', 'Interfaces'), controls={
            {type='dropdown', name=L('Оформление', 'Style'), choices={L('Отключено — стандартный ESO', 'Disabled — standard ESO'),'Diablo','WoW','DS_3'},
                choicesValues={'none','diablo','wow','ds3'}, getFunc=function() return db.style end,
                setFunc=function(v) db.style=v end, default='diablo', needsReload=true,
                tooltip=L('Выбор меняет только оформление после перезагрузки. Сетка, стрелка и остальные помощники работают независимо от темы и управляются своими настройками.', 'Changes presentation after reload. Grid, quest arrow and other helpers work independently of the theme, controlled by their own settings.')},
            Toggle('grid', L('Сетка предметов', 'Item grid'), L('Сетка инвентаря, торговца, банка и ремесла. Применяется после перезагрузки при любом оформлении.', 'Inventory, merchant, bank and crafting grids. Works with every style; requires reload.'), true),
            Toggle('questArrow', L('Встроенная стрелка заданий', 'Bundled quest arrow'), L('Не управляет отдельно установленным QuestArrow. Применяется после перезагрузки при любом оформлении.', 'Does not control a separately installed QuestArrow. Works with every style; requires reload.'), true),
        {type='button', name=L('Перезагрузить интерфейс','Reload UI'),
            tooltip=L('Применить изменения настроек без ввода /reloadui.','Apply pending settings without typing /reloadui.'),
            func=function() ReloadUI() end, width='full'},
        }},
        Maintenance('charge', L('Зарядка оружия', 'Weapon recharge')),
        Maintenance('repair', L('Ремонт снаряжения', 'Equipment repair')),
        {type='submenu', name=L('Мусор', 'Junk'), controls={
            Toggle('junk',L('Автопродажа мусора торговцу', 'Automatically sell junk'),L('Только предметы, уже отмеченные как мусор. Заблокированные и краденые предметы не продаются. Не помечает предметы автоматически.', 'Only items already marked as junk. Skips locked and stolen items. Does not mark items automatically.')),
        }},
        {type='submenu', name=L('Чат', 'Chat'), controls={
            Toggle('chat', L('Дополнительные функции чата', 'Chat helpers'), L('Время сообщений, цвета каналов и копирование по правому клику на время. Не меняет рамку чата. При установленном pChat обработка оставляется ему. Уже показанные сообщения сохраняют формат.', 'Timestamps, channel colors and copying via right-click on a timestamp. Does not change the chat frame. Defers to pChat when installed. Existing messages keep their formatting.')),
        }},
        {type='submenu', name=L('Совместимость', 'Compatibility'), controls={
            Toggle('guildBackground', L('Фон расширенного списка гильдии', 'Extended guild roster background'), L('Подгоняет только штатный фон под ширину таблицы. Не перемещает столбцы. После выхода из списка восстанавливает фон.', 'Fits only the native background to the table width. Does not move columns. Restores the background on leaving the roster.')),
        }},
    })
end
function AlabuzyaUI.Settings.Initialize()
    RegisterPanel()
end
