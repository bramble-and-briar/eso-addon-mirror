local AlabuzyaUI = AlabuzyaUI
-- Independent feature settings; style changes are applied only after ReloadUI.
AlabuzyaUI.Settings = {}
local S = AlabuzyaUI.Settings
S.defaults = {
    style = 'diablo', fonts = {}, goldLedger = true, goldLedgerMode = 'day',
    charge = { enabled = true, threshold = 10, crown = true },
    repair = { enabled = true, threshold = 10, crown = true },
    assistantPanel = true, junk = true, chat = true, grid = true,
    guildBackground = true, overlayMap = {enabled=true,opacity=0.28,scale=1},
}
S.fonts = {'default','MEDIUM_FONT','BOLD_FONT','CHAT_FONT','ANTIQUE_FONT','HANDWRITTEN_FONT','STONE_TABLET_FONT','GAMEPAD_LIGHT_FONT','GAMEPAD_MEDIUM_FONT','GAMEPAD_BOLD_FONT'}
function S.FontFace(style)
    local value=S.Get().fonts[style or S.Style()]
    for _,face in ipairs(S.fonts) do
        if face==value and face~='default' then return '$('..face..')' end
    end
end
local saved, loadedStyle
function S.Get()
    if not saved then
        saved = AlabuzyaUI.SavedVariables.Account('features', S.defaults)
        saved.fonts=type(saved.fonts)=='table' and saved.fonts or {}
        -- Migrate the previous theme ID without changing saved layout keys.
        if saved.style == 'classic' then saved.style = 'wow' end
        if saved.style ~= 'diablo' and saved.style ~= 'wow' and saved.style ~= 'ds3' and saved.style ~= 'none' then saved.style = 'diablo' end
        for _, kind in ipairs({'charge', 'repair'}) do
            saved[kind].threshold = math.max(1, math.min(90, tonumber(saved[kind].threshold) or 10))
        end
        saved.overlayMap=type(saved.overlayMap)=='table' and saved.overlayMap or {}
        saved.overlayMap.enabled=saved.overlayMap.enabled~=false
        saved.overlayMap.opacity=math.max(0.05,math.min(0.8,tonumber(saved.overlayMap.opacity) or 0.28))
        saved.overlayMap.scale=math.max(0.5,math.min(1.2,tonumber(saved.overlayMap.scale) or 1))
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
        type='panel', name='Alabuzya UI', displayName='Alabuzya UI', author='alabuzya', version='1.0.8',
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
            {type='dropdown', name=L('Шрифт','Font'),
                choices={L('По умолчанию для темы','Theme default'),'ESO Medium','ESO Bold','ESO Chat','Antique','Handwritten','Stone Tablet','Gamepad Light','Gamepad Medium','Gamepad Bold'},
                choicesValues=S.fonts, getFunc=function() return db.fonts[db.style] or 'default' end,
                setFunc=function(v) db.fonts[db.style]=v end, default='default', needsReload=true,
                tooltip=L('Шрифты клиента ESO с локализованными символами. Выбор сохраняется отдельно для каждой темы; примените перезагрузкой интерфейса.','ESO client fonts with localized glyphs. Saved separately for each theme; apply with Reload UI.')},
            Toggle('grid', L('Сетка предметов', 'Item grid'), L('Сетка инвентаря, торговца, банка и ремесла. Применяется после перезагрузки при любом оформлении.', 'Inventory, merchant, bank and crafting grids. Works with every style; requires reload.'), true),
            {type='description', text=L('QuestArrow поставляется отдельным аддоном в комплекте. Включайте или отключайте его в игровом списке аддонов; настройки стрелки: /qa help.', 'QuestArrow is bundled as an independent addon. Enable or disable it in the game addon list; arrow settings: /qa help.')},
        {type='button', name=L('Перезагрузить интерфейс','Reload UI'),
            tooltip=L('Применить изменения настроек без ввода /reloadui.','Apply pending settings without typing /reloadui.'),
            func=function() ReloadUI() end, width='full'},
        }},
        {type='submenu', name=L('Доходы и расходы','Income and expenses'), controls={
            {type='checkbox',name=L('Счётчик золота','Gold tracker'),default=true,
                getFunc=function() return db.goldLedger end,
                setFunc=function(v) db.goldLedger=v if AlabuzyaUI.GoldLedger then AlabuzyaUI.GoldLedger.SetEnabled(v) end end,
                tooltip=L('Клик по значку открывает историю. Переводы в собственный банк не считаются доходом/расходом. Выключенное время не учитывается.','Click the gold icon for history. Own-bank transfers are excluded. Changes while disabled are not counted.')},
            {type='dropdown',name=L('Период подсчёта','Accounting period'),
                choices={L('По сессиям','By session'),L('По дням','By day')},choicesValues={'session','day'},
                getFunc=function() return db.goldLedgerMode or 'day' end,
                setFunc=function(v) db.goldLedgerMode=v if AlabuzyaUI.GoldLedger then AlabuzyaUI.GoldLedger.Refresh() end end,
                default='day',tooltip=L('Меняет значок и историю сразу. По дням суммируются все сессии одной календарной даты на текущем сервере.','Immediately changes the widget and history. Daily mode sums all sessions on the same calendar date on this server.')},
        }},
        {type='submenu',name=L('Оверлей карты','Map overlay'),controls={
            {type='checkbox',name=L('Включить оверлей карты','Enable map overlay'),
                getFunc=function() return db.overlayMap.enabled end,
                setFunc=function(v) db.overlayMap.enabled=v if AlabuzyaUI.OverlayMap then AlabuzyaUI.OverlayMap.Refresh() end end,default=true},
            {type='description',text=L('Назначьте клавишу в Управление → Назначение клавиш → Alabuzya UI. Нажатие показывает или скрывает обесцвеченную карту без рамки; значки и области остаются цветными. Работает со всеми стилями, включая стандартный ESO.','Assign a key under Controls → Keybindings → Alabuzya UI. Press to show or hide a borderless desaturated map; pins and areas remain colored. Works with every style, including standard ESO.')},
            {type='slider',name=L('Видимость подложки (%)','Map background opacity (%)'),min=5,max=80,step=1,
                getFunc=function() return math.floor(db.overlayMap.opacity*100+0.5) end,
                setFunc=function(v) db.overlayMap.opacity=v/100 end,default=28},
            {type='slider',name=L('Размер карты (%)','Map size (%)'),min=50,max=120,step=5,
                getFunc=function() return math.floor(db.overlayMap.scale*100+0.5) end,
                setFunc=function(v) db.overlayMap.scale=v/100 end,default=100},
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
