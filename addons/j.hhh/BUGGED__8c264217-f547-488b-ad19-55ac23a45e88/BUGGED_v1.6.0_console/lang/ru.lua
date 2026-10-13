local strings = {

	-- BOSSES
	SI_ICTHENEXTBOSS_AMONCRUL = "Амонкрул",
	SI_ICTHENEXTBOSS_THIRSK = "Барон Тирск",
	SI_ICTHENEXTBOSS_GLORGOLOCH = "Глорголок Разрушитель",
	SI_ICTHENEXTBOSS_CHARR = "Поджигатель Чар",
	SI_ICTHENEXTBOSS_KHROGO = "Король Крого",
	SI_ICTHENEXTBOSS_MALYGDA = "Леди Малигда",
	SI_ICTHENEXTBOSS_MAZALUHAD = "Мазалухад",
	SI_ICTHENEXTBOSS_NUNATAK = "Нунатак",
	SI_ICTHENEXTBOSS_MATRON = "Визжащая Матрона",
	SI_ICTHENEXTBOSS_VOLGHASS = "Волгас",
	SI_ICTHENEXTBOSS_YSENDA = "Изенда Сияющая",
	SI_ICTHENEXTBOSS_ZOAL = "Зоал Недремлющий",

	-- DISTRICTS
	SI_ICTHENEXTBOSS_NOBLESDISTRICT = "Район Знати",
	SI_ICTHENEXTBOSS_ARENADISTRICT = "Район Арена",
	SI_ICTHENEXTBOSS_TEMPLEDISTRICT = "Храмовый район",
	SI_ICTHENEXTBOSS_ARBORETUMDISTRICT = "Дендрарий",
	SI_ICTHENEXTBOSS_MEMORIALDISTRICT = "Мемориальный район",
	SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT = "Район Эльфийские сады",

	-- GUI
	SI_ICTHENEXTBOSS_GUI_WIDTH = "270",
	SI_ICTHENEXTBOSS_OPTION_DESCRIPTION = "Отслеживает время появления боссов в Имперском Городе.",
	SI_ICTHENEXTBOSS_OPTION_TIMETABLE = "Показать таблицу с временем появления",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS = "Показать время появления на карте",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS_TOOLTIP = "Это отключит увеличение на карте Имперского Города.\nНе работает с Режимом-Геймпада!",
}

for id, value in pairs(strings) do
	ZO_CreateStringId(id, value)
	SafeAddVersion(id, 1)
end