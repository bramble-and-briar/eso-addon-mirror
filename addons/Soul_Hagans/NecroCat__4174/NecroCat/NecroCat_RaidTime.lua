---------------------------------------------------------
-- МОДУЛЬ: БАЗА ДАННЫХ СПИДРАНОВ И РЕЙДОВ (RAID TIME)
---------------------------------------------------------

NecroCat = NecroCat or {}
local NC = NecroCat

-- Реестр ID Триалов для проверки зоны
NC.TrialZoneIds = {
    [636]  = true, -- Hel Ra Citadel (Цитадель Хель-Ра)
    [638]  = true, -- Aetherian Archive (Этерианский Архив)
    [639]  = true, -- Sanctum Ophidia (Санктум-Офидия)
    [725]  = true, -- Maw of Lorkhaj (Пасть Лоркаджа)
    [975]  = true, -- Halls of Fabrication (Залы Фабрикации)
    [1000] = true, -- Asylum Sanctorium (Изоляционный Санктуарий)
    [1051] = true, -- Cloudrest (Клаудрест)
    [1121] = true, -- Sunspire (Солнечный Шпиль)
    [1196] = true, -- Kyne's Aegis (Эгида Кин)
    [1263] = true, -- Rockgrove (Каменная Роща)
    [1344] = true, -- Dreadsail Reef (Риф Зловещих Парусов)
    [1427] = true, -- Sanity's Edge (Грань Безумия)
    [1478] = true, -- Lucent Citadel (Цитадель Люцентов)
    [1548] = true, -- Ossein Cage (Костяная Клетка)
    [1565] = true, -- Opulent Ordeal (Платиновое горнило)
}

-- Особые подзоны старта таймера (Путь Жертвоприношений, Тюрьма ИГ, Башня, Город Пепла II)
NC.DungeonStartSubzones = {
    [681]  = 8388,  -- City of Ash II (Inner Grove / Внутренняя роща)
    [678]  = 8748,  -- Imperial City Prison (Bastion / Бастион)
    [688]  = 8982,  -- White-Gold Tower (Green Emperor Way / Аллея Зеленого Императора)
    [1055] = 13161, -- March of Sacrifices (Bloodscent Pass / Ущелье Запаха Крови)
}

-- Официальные лимиты времени спидранов (в секундах)
NC.SpeedrunParTimes = {
    -- ==========================================
    -- ТРИАЛЫ (12 чел.)
    -- ==========================================
    [636]  = 1980, -- Hel Ra Citadel — 33 мин
    [638]  = 1980, -- Aetherian Archive — 33 мин
    [639]  = 1980, -- Sanctum Ophidia — 33 мин
    [725]  = 2700, -- Maw of Lorkhaj — 45 мин
    [975]  = 2400, -- Halls of Fabrication — 40 мин
    [1000] = 900,  -- Asylum Sanctorium — 15 мин (Swift Mercy)
    [1051] = 900,  -- Cloudrest — 15 мин
    [1121] = 1800, -- Sunspire — 30 мин
    [1196] = 2100, -- Kyne's Aegis — 35 мин
    [1263] = 1800, -- Rockgrove — 30 мин
    [1344] = 1800, -- Dreadsail Reef — 30 мин (Tip of the Harpoon)
    [1427] = 2100, -- Sanity's Edge — 35 мин
    [1478] = 1800, -- Lucent Citadel — 30 мин (Expedited Excursion)
    [1548] = 1800, -- Ossein Cage — 30 мин
    [1565] = 1800, -- Opulent Ordeal — 30 мин

    -- ==========================================
    -- АРЕНЫ (4 чел. и Соло)
    -- ==========================================
    [635]  = 2700, -- Dragonstar Arena — 45 мин
    [677]  = 2700, -- Maelstrom Arena — 45 мин
    [1082] = 2400, -- Blackrose Prison — 40 мин
    [1227] = 2700, -- Vateshran Hollows — 45 мин

    -- ==========================================
    -- ДАНЖИ: БАЗОВАЯ ИГРА (4 чел.)
    -- ==========================================
    [283]  = 900,  -- Fungal Grotto I — 15 мин
    [934]  = 1200, -- Fungal Grotto II — 20 мин
    [144]  = 1200, -- Spindleclutch I — 20 мин
    [936]  = 1200, -- Spindleclutch II — 20 мин
    [380]  = 1200, -- The Banished Cells I — 20 мин
    [935]  = 1200, -- The Banished Cells II — 20 мин
    [146]  = 900,  -- Wayrest Sewers I — 15 мин
    [933]  = 1200, -- Wayrest Sewers II — 20 мин
    [126]  = 1200, -- Elden Hollow I — 20 мин
    [931]  = 1200, -- Elden Hollow II — 20 мин
    [63]   = 1200, -- Darkshade Caverns I — 20 мин
    [930]  = 1200, -- Darkshade Caverns II — 20 мин
    [130]  = 1200, -- Crypt of Hearts I — 20 мин
    [932]  = 1800, -- Crypt of Hearts II — 30 мин
    [176]  = 1200, -- City of Ash I — 20 мин
    [681]  = 1800, -- City of Ash II — 30 мин
    [148]  = 1200, -- Arx Corinium — 20 мин
    [22]   = 1200, -- Volenfell — 20 мин
    [131]  = 1200, -- Tempest Island — 20 мин
    [449]  = 1200, -- Direfrost Keep — 20 мин
    [38]   = 1200, -- Blackheart Haven — 20 мин
    [31]   = 1200, -- Selene's Web — 20 мин
    [64]   = 1200, -- Blessed Crucible — 20 мин
    [11]   = 1200, -- Vaults of Madness — 20 мин

    -- ==========================================
    -- ДАНЖИ: DLC (4 чел.)
    -- ==========================================
    [678]  = 2700, -- Imperial City Prison — 45 мин (Out of Prison)
    [688]  = 1800, -- White-Gold Tower — 30 мин
    [843]  = 1800, -- Ruins of Mazzatun — 30 мин
    [848]  = 1800, -- Cradle of Shadows — 30 мин
    [973]  = 1200, -- Bloodroot Forge — 20 мин
    [974]  = 1200, -- Falkreath Hold — 20 мин
    [1009] = 1800, -- Fang Lair — 30 мин
    [1010] = 1800, -- Scalecaller Peak — 30 мин
    [1052] = 1800, -- Moon Hunter Keep — 30 мин
    [1055] = 1800, -- March of Sacrifices — 30 мин
    [1080] = 1800, -- Frostvault — 30 мин
    [1081] = 1800, -- Depths of Malatar — 30 мин
    [1122] = 1800, -- Moongrave Fane — 30 мин
    [1123] = 2100, -- Lair of Maarselok — 35 мин
    [1152] = 1800, -- Icereach — 30 мин
    [1153] = 1800, -- Unhallowed Grave — 30 мин
    [1197] = 1500, -- Stone Garden — 25 мин
    [1201] = 1800, -- Castle Thorn — 30 мин
    [1228] = 1500, -- Black Drake Villa — 25 мин
    [1229] = 2100, -- The Cauldron — 35 мин
    [1267] = 1500, -- Red Petal Bastion — 25 мин
    [1268] = 1500, -- The Dread Cellar — 25 мин
    [1301] = 1500, -- Coral Aerie — 25 мин
    [1302] = 1500, -- Shipwright's Regret — 25 мин
    [1360] = 1500, -- Earthen Root Enclave — 25 мин
    [1361] = 1500, -- Graven Deep — 25 мин
    [1389] = 1500, -- Bal Sunnar — 25 мин
    [1390] = 1500, -- Scrivener's Hall — 25 мин
    [1470] = 1500, -- Oathsworn Pit — 25 мин
    [1471] = 1500, -- Bedlam Veil — 25 мин
}

-- База номеров квестов для данжей (для авто-приема расшаренных квестов)
NC.DungeonQuestIds = {
    [144] = 4054, [936] = 4555, [380] = 4107, [935] = 4597, [283] = 3993, [934] = 4303,
    [146] = 4246, [933] = 4813, [126] = 4336, [931] = 4675, [63]  = 4145, [930] = 4641,
    [130] = 4379, [932] = 5113, [176] = 4778, [681] = 5120, [148] = 4202, [22]  = 4432,
    [131] = 4538, [449] = 4346, [38]  = 4589, [31]  = 4733, [64]  = 4469, [11]  = 4822,
    [678] = 5136, [688] = 5342, [843] = 5403, [848] = 5702, [973] = 5889, [974] = 5891,
    [1009]= 6064, [1010]= 6065, [1052]= 6186, [1055]= 6188, [1081]= 6251, [1080]= 6249,
    [1122]= 6349, [1123]= 6351, [1152]= 6414, [1153]= 6416, [1197]= 6505, [1201]= 6507,
    [1228]= 6576, [1229]= 6578, [1267]= 6683, [1268]= 6685, [1301]= 6740, [1302]= 6742,
    [1360]= 6835, [1361]= 6837, [1389]= 6896, [1390]= 7027, [1470]= 7105, [1471]= 7155,
}

-- Получение целевого времени спидрана для текущей зоны
function NC.GetCurrentSpeedrunTarget()
    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    if zoneId and NC.SpeedrunParTimes and NC.SpeedrunParTimes[zoneId] then
        return NC.SpeedrunParTimes[zoneId]
    end
    return nil
end