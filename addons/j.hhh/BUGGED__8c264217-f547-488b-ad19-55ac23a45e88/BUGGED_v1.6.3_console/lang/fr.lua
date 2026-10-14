local strings = {

	-- BOSSES
	SI_ICTHENEXTBOSS_AMONCRUL = "Amoncrul",
	SI_ICTHENEXTBOSS_THIRSK = "Le baron Thirsk",
	SI_ICTHENEXTBOSS_GLORGOLOCH = "Glorgoloch le destructeur",
	SI_ICTHENEXTBOSS_CHARR = "L'immolateur Charr",
	SI_ICTHENEXTBOSS_KHROGO = "Le roi Khrogo",
	SI_ICTHENEXTBOSS_MALYGDA = "Dame Malygda",
	SI_ICTHENEXTBOSS_MAZALUHAD = "Mazaluhad",
	SI_ICTHENEXTBOSS_NUNATAK = "Nunatak",
	SI_ICTHENEXTBOSS_MATRON = "La matrone hurlante",
	SI_ICTHENEXTBOSS_VOLGHASS = "Volghass",
	SI_ICTHENEXTBOSS_YSENDA = "Ysenda la resplendissante",
	SI_ICTHENEXTBOSS_ZOAL = "Zoal l'Éveillé",

	-- DISTRICTS
	SI_ICTHENEXTBOSS_NOBLESDISTRICT = "Nobles",
	SI_ICTHENEXTBOSS_ARENADISTRICT = "L'Arene",
	SI_ICTHENEXTBOSS_TEMPLEDISTRICT = "Temple",
	SI_ICTHENEXTBOSS_ARBORETUMDISTRICT = "L'Arboretum",
	SI_ICTHENEXTBOSS_MEMORIALDISTRICT = "Souvenir",
	SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT = "Jardin elfique",

	-- GUI
	SI_ICTHENEXTBOSS_GUI_WIDTH = "230",
	SI_ICTHENEXTBOSS_OPTION_DESCRIPTION = "Tracks spawn times of bosses in Imperial City.",
	SI_ICTHENEXTBOSS_OPTION_TIMETABLE = "Table with spawntimes",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS = "Spawntimes on IC map",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS_TOOLTIP = "This will disable zoom on Imperial City map.\nDoes not work with Gamepad-Mode!",
}

for id, value in pairs(strings) do
	ZO_CreateStringId(id, value)
	SafeAddVersion(id, 1)
end