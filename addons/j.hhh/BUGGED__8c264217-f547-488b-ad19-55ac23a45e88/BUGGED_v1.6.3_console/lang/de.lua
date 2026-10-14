local strings = {

	-- BOSSES
	SI_ICTHENEXTBOSS_AMONCRUL = "Amoncrul",
	SI_ICTHENEXTBOSS_THIRSK = "Baron Thirsk",
	SI_ICTHENEXTBOSS_GLORGOLOCH = "Glorgoloch der Zerstörer",
	SI_ICTHENEXTBOSS_CHARR = "Entflammer Charr",
	SI_ICTHENEXTBOSS_KHROGO = "König Khrogo",
	SI_ICTHENEXTBOSS_MALYGDA = "Fürstin Malygda",
	SI_ICTHENEXTBOSS_MAZALUHAD = "Mazaluhad",
	SI_ICTHENEXTBOSS_NUNATAK = "Nunatak",
	SI_ICTHENEXTBOSS_MATRON = "Die kreischende Matrone",
	SI_ICTHENEXTBOSS_VOLGHASS = "Volghass",
	SI_ICTHENEXTBOSS_YSENDA = "Ysenda Strahlenpracht",
	SI_ICTHENEXTBOSS_ZOAL = "Zoal der Immerwache",

	-- DISTRICTS
	SI_ICTHENEXTBOSS_NOBLESDISTRICT = "Adelsbezirk",
	SI_ICTHENEXTBOSS_ARENADISTRICT = "Arenabezirk",
	SI_ICTHENEXTBOSS_TEMPLEDISTRICT = "Tempelbezirk",
	SI_ICTHENEXTBOSS_ARBORETUMDISTRICT = "Baumgartenbezirk",
	SI_ICTHENEXTBOSS_MEMORIALDISTRICT = "Gedenkbezirk",
	SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT = "Elfengartenbezirk",

	-- GUI
	SI_ICTHENEXTBOSS_GUI_WIDTH = "200",
	SI_ICTHENEXTBOSS_OPTION_DESCRIPTION = "Trackt die Spawnzeiten der Bosse in der Kaiserstadt.",
	SI_ICTHENEXTBOSS_OPTION_TIMETABLE = "Tabelle mit Countdowns",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS = "Countdowns auf Kaiserstadt Karte",
	SI_ICTHENEXTBOSS_OPTION_MAPTIMERS_TOOLTIP = "Deaktiviert den Zoom auf der Kaiserstadt Karte.\nFunktioniert nicht im Gamepad-Modus!",
}

for id, value in pairs(strings) do
	ZO_CreateStringId(id, value)
	SafeAddVersion(id, 1)
end