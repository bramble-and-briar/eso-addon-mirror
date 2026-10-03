local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'



AGLang.msg = {
Copy = 'Копировать',
Paste = 'Вставить',
Clear = 'Очистить',
Insert = 'Вставить сейчас надетое',

-- new since 6.6.0
ToBankAll = 'Сложить все наборы экипировки',
FromBankAll = 'Забрать все наборы экипировки',
FailedToMoveItem = 'Не удалось переместить <<1>>',
MovingSet = 'Перемещен набор <<1>>...',
-- end new 6.6.0

-- new since 6.2.1
ToBank = 'Положить набор в банк',
FromBank = 'Забрать набор из банка',
CurrentlyEquipped = '<<1>> все еще надето',
NotEnoughSpaceInBackPack = 'В инвентаре не хватает места для <<1>>',
NotEnoughSpaceInBank = 'В банке не хватает места для <<1>>',
ItemIsStolen = '<<1>> это краденное. Нельзя класть в банк.',
ReassignHint = 'Чтоб получать корректную подсказку обновите пожалуйста это умение (Shift + Click или перетаскиванием)',
ToolTipSkillIcon = lmb..' Выбрать значок\n'..rmb..' Переназначить значек',
BindLoadNextSet = 'Использовать следующий набор',
BindLoadPreviousSet = 'Использовать предыдущий набор',
BindToggleSet = 'Переключить два последних набора',
MsgNoPreviousSet = 'Второй набор не был экипирован.',
ShowMainBinding = 'Показать/скрыть окно AlphaGear',
-- end new 6.2.1

Icon = lmb..'Выберите значок',
Set = lmb..' Экипировать набор\n'..rmb..' Редактировать набор',
NotFound = '<<1>> |cFF0000не был найден...|r',
NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000Нет места в инвентаре...|r',
SoulgemUsed = '<<C:1>> |cFFAA33был перезаряжен.|r',
SetPart = '\n|cFFAA33Часть набора: <<C:1>>|r',
Lock = 'Если набор заблокирован то все пустые слоты будут деэкипированы.\nЕсли набор разблокирован, все пустые слоты игнорируются.\n\n'..lmb..' Заблокировать/Разблокировать',
Unequip = 'Снять броню',
UnequipAll = 'Снять все предметы',

-- new since 6.1.1
SetsHeader = 'Наборы',
SettingsDesc = 'Настроить интерфейс AlphaGear, Автозарядка и Авторемонт.',
NumVisibleSetButtons = 'Количество показываемых кнопок наборов',
GearHeader = 'Броня',
WeaponsHeader = 'Оружие',
EquipmentHeader = 'Панель экипировки',
UIHeader = 'Пользовательский интерфейс',
ResetPositions = 'Восстановить расположение',
-- end new 6.1.1
-- new since 6.1.3
ShowItemLevelChoices = {'Всегда', 'Только низкоуровневые', 'Никогда'},
-- end new 6.1.3

-- new since 6.2.0
OutfitLabel = 'Наряд',
UneqipAllBinding = 'Снять все',
LoadSetBinding = 'Загрузить набор ',
KeepOutfitItemLabel = 'Оставить текущий наряд',
SetChangeQueuedMsg = 'Набор <<1>> (<<2>>) будет надет при выходе из боя.',
ActionBar1Text = 'Панель умений 1',
ActionBar2Text = 'Панель умений 2',
ActionBarNText = 'Панель умений <<1>>',
NotEnoughMoneyForRepairMsg = 'Не хватает золота на ремонт.',
ItemsRepairedMsg = '<<1>> вещей отремонтировано. На сумму: <<2>> золотых.',
ItemsNotRepairedMsg = 'Не хватило золота на ремонт <<1>> предметов.',
-- end new since 6.2.0

-- new since 6.5.0
BindLoadProfile = 'Загрузить профиль',
BindLoadNextProfile = 'Загрузить следующий профиль',
BindLoadPreviousProfile = 'Загрузить предыдущий профиль',
BindToggleProfile = 'Переключить два последних профиля',
MsgNoPreviousProfile = 'Нет профиля для переключения.',
-- end new since 6.5.0

SetConnector = {
    lmb..' Связать броню с набором\n'..rmb..' Удалить связь с набором',
    lmb..' Связать первую панель умений с набором\n'..rmb..' Удалить связь с набором',
    lmb..' Связать вторую панель умений с набором\n'..rmb..' Удалить связь с набором'
},
Head = {
    Gear = 'Броня ',
    Skill = 'Умения '
},
Button = {
    Gear = lmb..' Одеть предмет\n'..rmb..' Удалить предмет',
    Skill = lmb..' Установить умение\n'..rmb..' Удалить умение'
},
Selector = {
    Gear = lmb..' Одеть все предметы\n'..rmb..' Больше действий',
    Skill = lmb..' Установить все умения\n'..rmb..' Больше действий'
},
OptionWidth = 360,
Options = {
    'Показывать кнопку интерфейса',
    'Показывать кнопки наборов',
    'Показывать иконку прочности доспехов',
    'Показывать стоимость ремонта',
    'Показывать иконку заряда оружия',
    'Показывать сообщение о смене набора',
    'Показывать экипированный набор',
    'Помечать в инвентаре предметы набора',
    'Показывать износ брони в процентах',
    'Показывать цветом качество предмета',
    'Закрывать окно при передвижение персонажа',
    'Зафиксировать все панели AlphaGear',
    'Автозарядка оружия',
-- new since 6.1.1
    'Авторемонт брони у торговцев',
-- end new 6.1.1
-- new since 6.1.3
    'Показывать маркеры уровней предметов',
-- end new 6.1.3
-- new since 6.4.1
    '<Unused Message>',
    'Автоматическая загрузка последнего профиля', -- AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE = 17
-- end new since 6.4.1
},

-- new since 6.8.1
Integrations = {
    Inventory = {
        Title = 'Inventory Manager',
        UseFCOIS = 'Show FCOIS marker icons',
        FCOIS = {
            GearMarkerIconLabel = 'Значок маркера',
            NoGearMarkerIconEntry = '-None-',
        }
    },

    Styling = {
        Title = 'Style Manager',
        UseAlphaStyle = 'Use AlphaStyle',
    },

    Champion = {
        Title = 'Champion Point Manager',
        UseCPSlots = 'Use Champion Point Slots',
    },

    QuickSlot = {
        Title = 'Quickslot Manager',
        UseGMQSB = 'Use Greymind Quick Slot Bar',
    },

},
-- new since 6.8.1
}
