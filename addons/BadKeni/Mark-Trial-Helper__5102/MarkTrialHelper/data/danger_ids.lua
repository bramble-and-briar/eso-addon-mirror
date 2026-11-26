-- Опасные атаки из
local AH = _G.MarkTrialHelper

-- Цвета (чтобы не зависеть от danger.lua)
local COLOR = {
    RED = "FF0000",
    YELLOW = "FFFF00",
    GREEN = "00FF00",
    BLUE = "1F51FF",
    CYAN = "00FFFF",
    PINK = "FF00FF",
    ORANGE = "FF6600",
    PURPLE = "BF40BF",
    GOLD = "E2E8A9",
}

AH.DANGER_IDS = {
    -- Стрелки
    [196689] = { duration = 1000, color = COLOR.RED, text = "ARROW" }, -- Venomous Arrow

    -- Штормовые Импы
    [196997] = { duration = 3500, color = COLOR.RED, text = "ZAP" },
    [223720] = { duration = 3500, color = COLOR.RED, text = "ZAP" },

    -- Инфьюзеры
    [210837] = { duration = 15000, color = COLOR.YELLOW, text = "INFUSE" },

    -- Реалмшейперы
    [157030] = { duration = 1200, color = COLOR.RED, text = "MIASMA" },
    [196848] = { duration = 1000, color = COLOR.YELLOW, text = "WAVE" },

    -- Сферы
    [202513] = { duration = 3000, color = COLOR.RED, text = "SPHERE" },

    -- Спеллтифы
    [212001] = { duration = 500, color = COLOR.PURPLE, text = "NULL" },

    -- Боссы
    [192517] = { duration = 2333, color = COLOR.RED, text = "BLOB" },
    [198819] = { duration = 2000, color = COLOR.RED, text = "BREATH" },
    [221792] = { duration = 500, color = COLOR.PINK, text = "BREW" },

    -- Тяжёлые атаки боссов
    [209924] = { duration = 1500, color = COLOR.YELLOW, text = "CHOMP" },
    [209925] = { duration = 1500, color = COLOR.YELLOW, text = "CHOMP" },
    [209926] = { duration = 1500, color = COLOR.YELLOW, text = "CHOMP" },
    [209931] = { duration = 1500, color = COLOR.GREEN, text = "BREATH" },
    [209948] = { duration = 1500, color = COLOR.GREEN, text = "BREATH" },
    [209846] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },

    -- Шэдоуренд
    [191598] = { duration = 2000, color = COLOR.RED, text = "HIT" },
    [191596] = { duration = 2000, color = COLOR.YELLOW, text = "TAIL" },

    -- Ра'хаджин
    [203525] = { duration = 1000, color = COLOR.YELLOW, text = "HIT" },
    [28408] = { duration = 1000, color = COLOR.YELLOW, text = "WHIRL" },
    [203519] = { duration = 1000, color = COLOR.YELLOW, text = "DAGGER" },

    -- Гаррон
    [195959] = { duration = 4000, color = COLOR.BLUE, text = "LIFE" },

    -- Биттергрин
    [198680] = { duration = 800, color = COLOR.YELLOW, text = "BITE" },
    [198685] = { duration = 800, color = COLOR.YELLOW, text = "JUMP" },

    -- Королева рифа
    [193811] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Хай Кинлорд
    [195079] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Войдмазер
    [195460] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195484] = { duration = 1500, color = COLOR.GREEN, text = "ZONE" },
    [195487] = { duration = 1500, color = COLOR.GREEN, text = "BOOM" },

    -- Синамон
    [198723] = { duration = 1500, color = COLOR.YELLOW, text = "WINTER" },

    -- Капитан Блэкхарт
    [192522] = { duration = 2000, color = COLOR.YELLOW, text = "SKELETON" },

    -- Лавовая королева
    [195513] = { duration = 1500, color = COLOR.YELLOW, text = "FIRE" },
    [195510] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Олд Снагара
    [193518] = { duration = 1500, color = COLOR.YELLOW, text = "HEADBUTT" },
    [193521] = { duration = 1500, color = COLOR.GREEN, text = "WAVE" },
    [193515] = { duration = 1500, color = COLOR.RED, text = "SPIT" },

    -- Вила Теран
    [195655] = { duration = 3000, color = COLOR.YELLOW, text = "SHADOW" },

    -- Рада аль-Саран
    [194269] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [145467] = { duration = 1500, color = COLOR.RED, text = "CHARGE" },

    -- Эш Титан
    [195420] = { duration = 1500, color = COLOR.YELLOW, text = "CLEAVE" },
    [195448] = { duration = 1000, color = COLOR.RED, text = "BOOM" },
    [195455] = { duration = 1500, color = COLOR.GREEN, text = "RAIN" },

    -- Сэйбл Найт
    [198902] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [209537] = { duration = 1500, color = COLOR.YELLOW, text = "SHIELD" },

    -- Краг
    [191702] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [191689] = { duration = 1500, color = COLOR.GREEN, text = "ZONE" },
    [191693] = { duration = 2000, color = COLOR.BLUE, text = "WHIRL" },

    -- Лименаурус
    [195639] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195640] = { duration = 1500, color = COLOR.RED, text = "CHARGE" },

    -- Вождь Озозай
    [191650] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [191653] = { duration = 1500, color = COLOR.YELLOW, text = "CHARGE" },
    [191670] = { duration = 1500, color = COLOR.YELLOW, text = "BOOM" },

    -- Эксарх Краглен
    [197573] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [197580] = { duration = 1500, color = COLOR.RED, text = "RAGE" },
    [197614] = { duration = 1500, color = COLOR.YELLOW, text = "ZONE" },
    [197604] = { duration = 1500, color = COLOR.YELLOW, text = "CHARGE" },

    -- Разар Мастер
    [192348] = { duration = 1500, color = COLOR.YELLOW, text = "EMBERS" },

    -- Таупезу
    [194335] = { duration = 1500, color = COLOR.RED, text = "SPEAR" },
    [194303] = { duration = 1500, color = COLOR.YELLOW, text = "ZONE" },

    -- Валкиназ
    [194345] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [194356] = { duration = 1500, color = COLOR.YELLOW, text = "WAVE" },
    [194373] = { duration = 1500, color = COLOR.YELLOW, text = "WAVE" },
    [194378] = { duration = 1500, color = COLOR.YELLOW, text = "WAVE" },
    [194416] = { duration = 1500, color = COLOR.GREEN, text = "FIRE" },

    -- Сентинел Аксалаз
    [197661] = { duration = 2000, color = COLOR.YELLOW, text = "HIT" },
    [197868] = { duration = 1500, color = COLOR.YELLOW, text = "DEATH" },
    [197683] = { duration = 3750, color = COLOR.BLUE, text = "ICE" },
    [209767] = { duration = 1500, color = COLOR.YELLOW, text = "SPHERE" },
    [150355] = { duration = 1500, color = COLOR.RED, text = "HIT" },

    -- Дойлемиш
    [199901] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [199906] = { duration = 800, color = COLOR.GREEN, text = "EARTH" },

    -- Жадж'хасса
    [197355] = { duration = 1500, color = COLOR.YELLOW, text = "SHATTER" },
    [197421] = { duration = 1750, color = COLOR.BLUE, text = "CURSE" },

    -- Ракхат
    [204209] = { duration = 3500, color = COLOR.YELLOW, text = "HIT" },
    [204216] = { duration = 3600, color = COLOR.BLUE, text = "BARRAGE" },
    [204260] = { duration = 1500, color = COLOR.YELLOW, text = "SMASH" },
    [204225] = { duration = 1900, color = COLOR.YELLOW, text = "SWING" },

    -- Сонория
    [46732] = { duration = 700, color = COLOR.RED, text = "SCREAM" },
    [9674] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [9671] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Мурклайт
    [195669] = { duration = 1500, color = COLOR.BLUE, text = "HIT" },
    [195671] = { duration = 1500, color = COLOR.RED, text = "STOMP" },
    [195722] = { duration = 3100, color = COLOR.GREEN, text = "RUNE" },

    -- Нериен'ет
    [196235] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196129] = { duration = 1500, color = COLOR.YELLOW, text = "BOOM" },
    [196238] = { duration = 1500, color = COLOR.RED, text = "HIT" },

    -- Имперфект
    [195351] = { duration = 1000, color = COLOR.YELLOW, text = "HIT" },
    [195323] = { duration = 667, color = COLOR.RED, text = "PULSE" },
    [94074] = { duration = 1000, color = COLOR.YELLOW, text = "SPIN" },

    -- Селена
    [209645] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [122995] = { duration = 600, color = COLOR.YELLOW, text = "ROAR" },
    [209640] = { duration = 1800, color = COLOR.YELLOW, text = "HIT" },

    -- Молаг Кена
    [196397] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196401] = { duration = 1500, color = COLOR.RED, text = "CLEAVE" },
    [196441] = { duration = 1500, color = COLOR.GREEN, text = "STORM" },
    [196407] = { duration = 1000, color = COLOR.BLUE, text = "SPEAR" },
    [196414] = { duration = 2000, color = COLOR.GREEN, text = "METEOR" },

    -- Исмгар
    [194756] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195612] = { duration = 1500, color = COLOR.GREEN, text = "WAVE" },
    [195591] = { duration = 1500, color = COLOR.BLUE, text = "HIT" },

    -- Лорд Уорден
    [197157] = { duration = 1500, color = COLOR.YELLOW, text = "BARRAGE" },
    [197016] = { duration = 1500, color = COLOR.BLUE, text = "SPHERE" },

    -- Канонрив
    [9944] = { duration = 1500, color = COLOR.BLUE, text = "BOOM" },

    -- Змей
    [191707] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196517] = { duration = 5000, color = COLOR.YELLOW, text = "TOTEM" },

    -- Йольнахкрин
    [194736] = { duration = 1500, color = COLOR.RED, text = "FORCE" },
    [194932] = { duration = 1500, color = COLOR.RED, text = "SWING" },
    [194918] = { duration = 1500, color = COLOR.RED, text = "SWING" },
    [194907] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194908] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194966] = { duration = 1500, color = COLOR.BLUE, text = "TAKEOFF" },

    -- Ксемхок
    [193812] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [191526] = { duration = 1500, color = COLOR.YELLOW, text = "ZONE" },
    [191542] = { duration = 1500, color = COLOR.GREEN, text = "BREATH" },
    [195462] = { duration = 1500, color = COLOR.GREEN, text = "ROCK" },

    -- Мулаамнир
    [196308] = { duration = 1500, color = COLOR.YELLOW, text = "BREATH" },
    [194811] = { duration = 1500, color = COLOR.BLUE, text = "TAKEOFF" },
    [196371] = { duration = 1000, color = COLOR.BLUE, text = "LAND" },
    [196372] = { duration = 2000, color = COLOR.GREEN, text = "RUN" },
    [196257] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },
    [196278] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },

    -- Симфония клинков
    [196919] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196920] = { duration = 5400, color = COLOR.BLUE, text = "DANCE" },
    [197065] = { duration = 500, color = COLOR.GREEN, text = "HIT" },

    -- З'База
    [204558] = { duration = 1000, color = COLOR.BLUE, text = "BOOM" },
    [204560] = { duration = 2000, color = COLOR.YELLOW, text = "HIT" },
    [159824] = { duration = 2200, color = COLOR.RED, text = "HIT" },

    -- Гемвас
    [198946] = { duration = 1000, color = COLOR.YELLOW, text = "HIT" },
    [198949] = { duration = 1000, color = COLOR.YELLOW, text = "HIT" },
    [198950] = { duration = 2100, color = COLOR.YELLOW, text = "HIT" },
    [198958] = { duration = 1500, color = COLOR.BLUE, text = "BLITZ" },

    -- Глемиос
    [194549] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194550] = { duration = 1500, color = COLOR.YELLOW, text = "STOMP" },
    [195773] = { duration = 1100, color = COLOR.RED, text = "HIT" },
    [195790] = { duration = 1500, color = COLOR.GREEN, text = "ROOTS" },
    [173998] = { duration = 500, color = COLOR.YELLOW, text = "ZAP" },

    -- Эндлинг
    [198817] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [198775] = { duration = 1500, color = COLOR.YELLOW, text = "SLAM" },
    [195350] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [198819] = { duration = 2000, color = COLOR.RED, text = "BREATH" },
    [198844] = { duration = 1500, color = COLOR.CYAN, text = "ICE" },
    [198853] = { duration = 1300, color = COLOR.BLUE, text = "BOLT" },

    -- Приор Тьеррик
    [199600] = { duration = 1500, color = COLOR.YELLOW, text = "CLEAVE" },
    [199608] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [199628] = { duration = 2000, color = COLOR.RED, text = "BEWILDER" },

    -- Барон Заудрус
    [205013] = { duration = 1000, color = COLOR.YELLOW, text = "HIT" },
    [205030] = { duration = 1500, color = COLOR.RED, text = "BOOM" },
    [205036] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [205021] = { duration = 2000, color = COLOR.YELLOW, text = "EARTH" },

    -- Лаатвулон
    [194749] = { duration = 1500, color = COLOR.CYAN, text = "BREATH" },
    [194830] = { duration = 3000, color = COLOR.GREEN, text = "RUN" },
    [194828] = { duration = 1000, color = COLOR.BLUE, text = "LAND" },
    [194777] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },
    [194765] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },

    -- Назарай
    [204446] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [204515] = { duration = 1200, color = COLOR.RED, text = "LIQUIDATE" },

    -- Плачущая женщина
    [199437] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [199410] = { duration = 1500, color = COLOR.YELLOW, text = "SWAT" },

    -- Леди Белейн
    [194663] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194605] = { duration = 1500, color = COLOR.YELLOW, text = "CHARGE" },
    [194609] = { duration = 1500, color = COLOR.BLUE, text = "SMASH" },
    [194626] = { duration = 1500, color = COLOR.YELLOW, text = "BARRAGE" },

    -- Леди Торн
    [198007] = { duration = 1500, color = COLOR.GREEN, text = "CHARGE" },
    [197982] = { duration = 1250, color = COLOR.RED, text = "DODGE" },
    [198103] = { duration = 1500, color = COLOR.YELLOW, text = "DIVE" },

    -- Шёпот
    [193164] = { duration = 1500, color = COLOR.GREEN, text = "SPIDERS" },

    -- Воин
    [191366] = { duration = 1500, color = COLOR.YELLOW, text = "SWING" },
    [191428] = { duration = 1500, color = COLOR.GREEN, text = "SHIELD" },
    [191506] = { duration = 1500, color = COLOR.RED, text = "CLEAVE" },
    [191429] = { duration = 1500, color = COLOR.GREEN, text = "LEAP" },
    [43237] = { duration = 1000, color = COLOR.YELLOW, text = "INFERNO" },
    [47461] = { duration = 4500, color = COLOR.BLUE, text = "CHANNEL" },

    -- Вандация
    [194158] = { duration = 1500, color = COLOR.RED, text = "HIT" },

    -- Варлариэль
    [226975] = { duration = 6700, color = COLOR.RED, text = "BOOM" },

    -- Сейл Риппер (гарпия)
    [221964] = { duration = 1500, color = COLOR.BLUE, text = "CYCLONE" },
    [221959] = { duration = 2500, color = COLOR.RED, text = "HIT" },
    [221929] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [228021] = { duration = 1500, color = COLOR.GREEN, text = "CELL" },

    -- Яндир Мясник
    [221988] = { duration = 1500, color = COLOR.YELLOW, text = "CLEAVE" },
    [221975] = { duration = 1600, color = COLOR.RED, text = "HIT" },
    [221979] = { duration = 2400, color = COLOR.GREEN, text = "TIDE" },

    -- Стаада
    [221207] = { duration = 1500, color = COLOR.YELLOW, text = "HAMMER" },
    [221209] = { duration = 2000, color = COLOR.RED, text = "AURA" },
    [227953] = { duration = 1500, color = COLOR.BLUE, text = "STRIKE" },

    -- Грауфанг (медведь)
    [221213] = { duration = 1500, color = COLOR.YELLOW, text = "SLAM" },

    -- Дранос Веладор
    [203593] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [221816] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [221791] = { duration = 1500, color = COLOR.GREEN, text = "MOVE" },
    [221809] = { duration = 1500, color = COLOR.BLUE, text = "MARK" },

    -- Дуган Красный
    [221216] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [221219] = { duration = 1000, color = COLOR.RED, text = "STANDARD" },

    -- Варзунон
    [221231] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Кован Гирйон
    [220881] = { duration = 1000, color = COLOR.GREEN, text = "ZONE" },
    [220959] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },

    -- Руины
    [227222] = { duration = 1500, color = COLOR.YELLOW, text = "BOULDER" },
    [227232] = { duration = 1000, color = COLOR.BLUE, text = "NULL" },

    -- Траш
    [7095] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196867] = { duration = 1500, color = COLOR.YELLOW, text = "JUMP" },
    [196860] = { duration = 1500, color = COLOR.YELLOW, text = "BITE" },
    [202945] = { duration = 1500, color = COLOR.YELLOW, text = "CHARGE" },
    [211114] = { duration = 1400, color = COLOR.YELLOW, text = "HIT" },
    [223086] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202940] = { duration = 1500, color = COLOR.CYAN, text = "BITE" },
    [202948] = { duration = 1500, color = COLOR.CYAN, text = "BITE" },
    [202374] = { duration = 1500, color = COLOR.BLUE, text = "POUND" },
    [202607] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202531] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202539] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196719] = { duration = 2000, color = COLOR.BLUE, text = "HIT" },
    [196727] = { duration = 1000, color = COLOR.ORANGE, text = "STANDARD" },
    [211594] = { duration = 1500, color = COLOR.RED, text = "BASH" },
    [197002] = { duration = 2100, color = COLOR.BLUE, text = "HIT" },
    [197004] = { duration = 1500, color = COLOR.YELLOW, text = "STORM" },
    [203104] = { duration = 1500, color = COLOR.YELLOW, text = "DIVE" },
    [203100] = { duration = 900, color = COLOR.GREEN, text = "ZONE" },
    [201835] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194894] = { duration = 1500, color = COLOR.RED, text = "UPPERCUT" },
    [194984] = { duration = 1500, color = COLOR.RED, text = "UPPERCUT" },
    [194656] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [196845] = { duration = 1500, color = COLOR.BLUE, text = "ZONE" },
    [203467] = { duration = 750, color = COLOR.RED, text = "OIL" },
    [201727] = { duration = 1200, color = COLOR.YELLOW, text = "CHARGE" },
    [196959] = { duration = 1400, color = COLOR.RED, text = "HIT" },
    [203496] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [203492] = { duration = 1500, color = COLOR.YELLOW, text = "STRIKE" },
    [196875] = { duration = 1500, color = COLOR.RED, text = "BLAST" },
    [196715] = { duration = 1500, color = COLOR.RED, text = "BASH" },
    [35849] = { duration = 1500, color = COLOR.BLUE, text = "CLOAK" },
    [202632] = { duration = 700, color = COLOR.ORANGE, text = "PILLARS" },
    [202656] = { duration = 2000, color = COLOR.GREEN, text = "ZONE" },
    [210599] = { duration = 2000, color = COLOR.YELLOW, text = "TOTEM" },
    [210561] = { duration = 2000, color = COLOR.YELLOW, text = "TOTEM" },
    [221730] = { duration = 1000, color = COLOR.CYAN, text = "FLOOD" },
    [221364] = { duration = 2000, color = COLOR.RED, text = "BASH" },
    [221745] = { duration = 2600, color = COLOR.GOLD, text = "ZONE" },
    [221753] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [222919] = { duration = 1365, color = COLOR.YELLOW, text = "CAGE" },
    [211976] = { duration = 500, color = COLOR.YELLOW, text = "METEOR" },
    [222916] = { duration = 700, color = COLOR.BLUE, text = "ZONE" },
    [222933] = { duration = 2500, color = COLOR.RED, text = "ZONE" },
    [222885] = { duration = 1700, color = COLOR.YELLOW, text = "FIREBALL" },
    [223378] = { duration = 2500, color = COLOR.YELLOW, text = "LEAP" },
    [223191] = { duration = 1500, color = COLOR.BLUE, text = "SWARM" },
    [223119] = { duration = 1500, color = COLOR.YELLOW, text = "REAP" },
    [223135] = { duration = 1500, color = COLOR.YELLOW, text = "ABYSS" },

    -- Мародеры
    [210006] = { duration = 1500, color = COLOR.YELLOW, text = "COMBO" },
    [210010] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [210028] = { duration = 1750, color = COLOR.RED, text = "BLADES" },
    [210519] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [210840] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [210841] = { duration = 1500, color = COLOR.YELLOW, text = "WAVE" },
    [210830] = { duration = 1500, color = COLOR.BLUE, text = "BOLT" },
    [221112] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [221108] = { duration = 1500, color = COLOR.YELLOW, text = "BITE" },
    [220298] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [227457] = { duration = 1500, color = COLOR.GREEN, text = "ZONE" },

    -- Арамиль
    [201193] = { duration = 1500, color = COLOR.YELLOW, text = "FIGHT" },
    [199387] = { duration = 2000, color = COLOR.RED, text = "HIT" },
    [199503] = { duration = 2000, color = COLOR.GREEN, text = "ZONE" },
    [194077] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [194034] = { duration = 750, color = COLOR.BLUE, text = "FEAR" },

    -- Дополнительные из EAA
    [194053] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [193534] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195490] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [192658] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [192659] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [198333] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [197152] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [192205] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [201360] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195978] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [195965] = { duration = 3000, color = COLOR.YELLOW, text = "HIT" },
    [194987] = { duration = 1500, color = COLOR.RED, text = "HIT" },
    [202665] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202377] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202129] = { duration = 2100, color = COLOR.YELLOW, text = "HIT" },
    [203464] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202530] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [202541] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [192695] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    [192707] = { duration = 1500, color = COLOR.YELLOW, text = "HIT" },
    -- МЕХАНИКИ (отдельные уведомления в центре экрана)
    [200060] = { duration = 10000, color = COLOR.GREEN, text = "SCAMP" },
    [200067] = { duration = 5000, color = COLOR.RED, text = "SCAMP" },
    [196806] = { duration = 1500, color = COLOR.RED, text = "NEGATE" },
    [210483] = { duration = 1000, color = COLOR.RED, text = "INFERNO" },
}