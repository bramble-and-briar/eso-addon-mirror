local strings = {

	-- BOSSES
	SI_ICTHENEXTBOSS_AMONCRUL = "Amoncrul",
	SI_ICTHENEXTBOSS_THIRSK = "Baron Thirsk",
	SI_ICTHENEXTBOSS_GLORGOLOCH = "Glorgoloch the Destroyer",
	SI_ICTHENEXTBOSS_CHARR = "Immolator Charr",
	SI_ICTHENEXTBOSS_KHROGO = "King Khrogo",
	SI_ICTHENEXTBOSS_MALYGDA = "Lady Malygda",
	SI_ICTHENEXTBOSS_MAZALUHAD = "Mazaluhad",
	SI_ICTHENEXTBOSS_NUNATAK = "Nunatak",
	SI_ICTHENEXTBOSS_MATRON = "The Screeching Matron",
	SI_ICTHENEXTBOSS_VOLGHASS = "Volghass",
	SI_ICTHENEXTBOSS_YSENDA = "Ysenda Resplendent",
	SI_ICTHENEXTBOSS_ZOAL = "Zoal the Ever-Wakeful",

	-- DISTRICTS
	SI_ICTHENEXTBOSS_NOBLESDISTRICT = "Nobles District",
	SI_ICTHENEXTBOSS_ARENADISTRICT = "Arena District",
	SI_ICTHENEXTBOSS_TEMPLEDISTRICT = "Temple District",
	SI_ICTHENEXTBOSS_ARBORETUMDISTRICT = "Arboretum District",
	SI_ICTHENEXTBOSS_MEMORIALDISTRICT = "Memorial District",
	SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT = "Elven Gardens District",

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