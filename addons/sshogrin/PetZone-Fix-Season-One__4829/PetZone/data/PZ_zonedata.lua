if PZ == nil then PZ = {} end
local PetZone = PZ

PetZone.ZoneData = {}
--The zones and subzones of the game, as strings (for library libMapPin access)
--> Taken zone names from addon Skyshards by Ayantir & Garkin: http://www.esoui.com/downloads/info128-SkyShards.html
PetZone.ZoneData["alikr"] = { --Alik'r Desert
    [PZ_ZONE_ID_STRING] = 104,
    --Alik'r Desert
    ["alikr_base"] = 104, --Alik'r Desert
    ["sentinel_base"] = 756,
    ["bergama_base"] = true,
    ["kozanset_base"] = true,
    ["aldunz_base"] = 329,
    ["coldrockdiggings_base"] = 330,
    ["divadschagrinmine_base"] = 328,
    ["sandblownmine_base"] = 331,
    ["santaki_base"] = 327,
    ["yldzuun_base"] = 332,
    ["lostcity_base"] = 308,
}

PetZone.ZoneData["eyevea"] = { --Eyevea
    [PZ_ZONE_ID_STRING] = 267,
    --Eyevea
    ["eyevea_base"] = 267, --"Augvea"
}

PetZone.ZoneData["auridon"] = { --Auridon
    [PZ_ZONE_ID_STRING] = 381,
    --Auridon
    ["auridon_base"] = 381, -- Auridon
    ["vulkhelguard_base"] = "Vulkhel Guard",
    ["skywatch_base"] = true,
    ["bewan_base"] = 401,
    ["delsclaim_base"] = 397,
    ["entilasfolly_base"] = 398,
    ["mehrunesspite_base"] = 400,
    ["ondil_base"] = 396,
    ["wansalen_base"] = 399,
    ["toothmaulgully_base"] = 486,
    ["khenarthisroost_base"] = 537 ,--"Khenarthis Roost",
    ["mistral_base"] = true,
    ["firsthold_base"] = true,
}

PetZone.ZoneData["bangkorai"] = { --Bangkorai
    [PZ_ZONE_ID_STRING] = 92,
    --Bangkorai
    ["bangkorai_base"] = 92, --Bangkorai
    ["evermore_base"] = true,
    ["cryptoftheexiles_base"] = 336,
    ["jaggerjaw_base"] = true,
    ["murciensclaim_base"] = "Murchien's Hamlet",
    ["rubblebutte_base"] = 338,
    ["trollstoothpick_base"] = 334,
    ["viridianwatch_base"] = 335,
    ["razakswheel_base"] = 169,
    --??? Check if those exist!
    ["klathzgar_base"] = 337,
    ["torogsspite_base"] = 333,
    ["hallinsstand_base"] = "Hallins Stand",
}

PetZone.ZoneData["battlegrounds"] = {
	[PZ_ZONE_MAPPING_STRING] = "~Battlegrounds",
	["aldcarac_base"] = 509,
	["aldcaracalt_base"] = 509,
	["arcane_base"] = 511,
	["ayleid_map"] = "INCOMPLETE",
	["coloviancrossing_base"] = "Colovian Crossing",
	["eldangavar1_base"] = 517,
	["eldangavar2_base"] = 517,
	["foyada_base"] = 508,
	["istirusarena_base"] = 514,
	["istirus_base"] = 514,
	["morkhazgur_base"] = 513,
	["necro_base"] = "INCOMPLETE", --Deeping Drome?
	["ularra_base"] = 510,
}

PetZone.ZoneData["coldharbor"] = { --Coldharbour
    [PZ_ZONE_ID_STRING] = 347,
    --Coldharbour
    ["coldharbour_base"] = 347, -- Coldharbour
    ["aba-loria_base"] = 417,
    ["vaultofhamanforgefire_base"] = 418,
    ["depravedgrotto_base"] = 419,
    ["caveoftrophies_base"] = 420,
    ["malsorrastomb_base"] = 421,
    ["wailingmaw_base"] = 422,
    ["villageofthelost_base"] = 557,
    ["thehollowcity_base"] = "Hollow City",
    ["hollowcity_base"] = "Hollow City",
}

PetZone.ZoneData["craglorn"] = { --Craglorn
    [PZ_ZONE_ID_STRING] = 888,
    --Craglorn
    ["craglorn_base"] = 888, --Craglorn
    ["belkarth_base"] = true,
    ["molavar_base"] = 889,
    ["rkundzelft_base"] = 890,
    ["kardala_base"] = 893,
    ["rkhardahrk_0"] = true,
    ["haddock_base"] = 896,
    ["chiselshriek_base"] = 897,
    ["burriedsands_base"] = 898,
    ["mtharnaz_base"] = 899,
    ["balamath_base"] = 901,
    ["thaliasretreat_base"] = "Thalia's Retreat",
    ["cryptoftarishzizone_base"] = 905, -- Tombs of the Na-Totambu
    ["hircineshaunt_base"] = 906,
    --Upper Craglorn
    ["serpentsnest_base"] = 891,
    ["ilthagsundertower_base"] = 892,
    ["lothna_base"] = 894,
    ["howlingsepulchersoverland_base"] = 900,
    ["fearfang_base"] = 902,
    ["exarchsstronghold_base"] = 903,
    ["dragonstar_base"] = true,
    --Check (South-West)
    ["zalgazsden_base"] = 904,
    --Check (South-East)
    ["elinhir_base"] = 910,

    ["craglorn_dragonstar_base"] = "Dragonstar", --Dragonstar
}

PetZone.ZoneData["cyrodiil"] = { --Cyrodiil
    [PZ_ZONE_ID_STRING] = 181,
    --Cyrodiil
    ["ava_whole"] = 181, --"Cyrodiil",
    --Aldmeri
    ["bloodmaynecave_base"] = 507,
    ["breakneckcave_base"] = 493,
    ["haynotecave_base"] = 497,
    ["nisincave_base"] = 502,
    ["potholecavern_base"] = 503,
    ["serpenthollowcave_base"] = 506,
    --Dagerrfall
    ["capstonecave_base"] = 494,
    ["echocave_base"] = 496,
    ["lipsandtarn_base"] = 499,
    ["redrubycave_base"] = 505,
    ["toadstoolhollow_base"] = 531,
    ["underpallcave_base"] = 533,
    --Ebonheart
    ["crackedwoodcave_base"] = 495,
    ["kingscrest_base"] = 498,
    ["muckvalleycavern_base"] = 500,
    ["newtcave_base"] = 501,
    ["quickwatercave_base"] = 504,
    ["vahtacen_base"] = 532,
    --Imperial City
    ["imperialcity_base"] = 584,
    ["imperialsewers_ebon1"] = "IC sewers: Ebonheart Pact 1",
    ["imperialsewers_ebon2"] = "IC sewers: Ebonheart Pact 2",
    ["imperialsewers_aldmeri1"] = "IC sewers: Aldmeri Dominion 1",
    ["imperialsewers_aldmeri2"] = "IC sewers: Aldmeri Dominion 2",
    ["imperialsewer_daggerfall1"] = "IC sewers: Daggerfall Covenant 1",
    ["imperialsewer_daggerfall2"] = "IC sewers: Daggerfall 2",
    ["imperialsewershub_base"] = "IC sewers: Imperial Sewers",
    ["imperialsewer_ebonheart3"] = "IC sewers: Ebonheart Pact 3",
    ["imperialsewers_aldmeri3"] = "IC sewers: Aldmeri Dominion 3",
    ["imperialsewer_daggerfall3"] = "IC sewers: Daggerfall Covenant 3",

    ["southhighrockgate_base"] = "Southern High Rock Gate", --Southern High Rock Gate
    ["imperialsewer_daggerfall1_base"] = 643, --Lambent Passage
    ["northhighrockgate_base"] = "Northern High Rock Gate", --Northern High Rock Gate
}

PetZone.ZoneData["deshaan"] = { --"Deshaan"
    [PZ_ZONE_ID_STRING] = 57,
    --Deshaan
    ["deshaan_base"] = 57, -- Deshaan
    ["narsis_base"] = 250,
    ["mournhold_base"] = 600,
    ["forgottencrypts_base"] = 306,
    ["desolatecave_base"] = "Desolate Cave",
    ["kwamacolony_base"] = 274,
    ["lowerbthanuel_base"] = 406,
    ["triplecirclemine_base"] = 407,
    ["unexploredcrag_base"] = 408,
    ["corpsegarden_base"] = 410,
    --Check (North-West)
    ["ladyllarelsshelter_base"] = 405,
    --Check (North-East)
    ["knifeeargrotto_base"] = 409,
}

PetZone.ZoneData["dungeonsGrp"] = {
	[PZ_ZONE_MAPPING_STRING] = "~Group Dungeons",
	--Alik'r Desert
	["eyeschamber_base"] = 22,
	["guardiansorbit_base"] = 22,
	["secret_tunnel_base"] = 22, --moved from Bangkorai
	["the_guardians_skull_base"] = 22,  --moved from Bangkorai
	["volenfell_base"] = 22,
	["volenfell_pledge_base"] = 22,
	--Auridon
	["thebanishedcells_base"] = "The Banished Cells",
	--Bangkorai
	["blackhearthavenarea1_base"] = 38,
	["blackhearthavenarea2_base"] = 38,
	["blackhearthavenarea3_base"] = 38,
	["blackhearthavenarea4_base"] = 38,
	["ui_map_fanglairext_base"] = 1009, --duplicated in Stormhaven for some reason
	["unhallowedgravemap001"] = 1153,
	["unhallowedgravemap002"] = 1153,
	["unhallowedgravemap003"] = 1153,
	["unhallowedgravemap004"] = 1153,
	["unhallowedgravemap005"] = 1153,
	["unhallowedgravemap001b"] = 1153,
	["unhallowedgravemap001c"] = 1153,
	["unhallowedgravesecret2map"] = 1153,
	--Clockwork City
	["ui_map_asylumsanctorum001_base"] = 1000,
	["ui_map_asylumsanctorum002_base"] = 1000,
	--Coldharbour
	["vaultsofmadness1_base"] = 11,
	["vaultsofmadness2_base"] = 11,
	--Craglorn
	["aetherianarchivebottom_base"] = 638,
	["aetherianarchiveend_base"] = 638,
	["aetherianarchiveislanda_base"] = 638,
	["aetherianarchiveislandb_base"] = 638,
	["aetherianarchiveislandc_base"] = 638,
	["aetherianarchivemiddle_base"] = 638,
	["dragonstararena01"] = 635,
	["dragonstararena01_base"] = 635,
	["dragonstararena02_base"] = 635,
	["dragonstararena03_base"] = 635,
	["dragonstararena04_base"] = 635,
	["dragonstararena05_base"] = 635,
	["dragonstararena06_base"] = 635,
	["dragonstararena07_base"] = 635,
	["dragonstararena08_base"] = 635,
	["dragonstararena09crypt_base"] = 635,
	["dragonstararena09_base"] = 635,
	["dragonstararena10_base"] = 635,
	["dragonstararenavault_base"] = 635,
	["gladiatorsassembly_base"] = 635,
	["helracitadelentry_base"] = 636,
	["helracitadelhallofwarrior_base"] = 636,
	["helracitadel_base"] = 636,
	["trl_so_map01_base"] = 639,
	["trl_so_map02_base"] = 639,
	["trl_so_map03_base"] = 639,
	["trl_so_map04_base"] = 639,
	["ui_map_bloodrootext1_base"] = 973,
	["ui_map_bloodrootint1_base"] = 973,
	["ui_map_bloodrootint2_base"] = 973,
	["ui_map_falkreathsdemise_base"] = 974,
	["ui_map_falkreathsdemise_b_base"] = 974,
	["ui_map_falkreathsdemise_i_base"] = 974,
	--Cyrodiil
	["wgtbattlemage_base"] = 688,
	["wgtgreenemporerway_base"] = 688,
	["wgtimperialguardquarters_base"] = 688,
	["wgtimperialthroneroom_base"] = 688,
	["wgtlibraryhall_base"] = 688,
	["wgtlibrarymain_base"] = 688,
	["wgtpalacesewers_base"] = 688,
	["wgtpinnacleboss_base"] = 688,
	["wgtpinnacle_base"] = 688,
	["wgtregentsquarters_base"] = 688,
	["wgtvoid1_base"] = 688,
	["wgtvoid2_base"] = 688,
	["imperialprisondistrictdun_base"] = 678,
	["imperialprisondunint01_base"] = 678,
	["imperialprisondunint02_base"] = 678,
	["imperialprisondunint03_base"] = 678,
	["imperialprisondunint04_base"] = 678,
	--Deshaan
	["darkshadecavernsheroic_base"] = "Darkshade Caverns",
	["darkshadecaverns_base"] = "Darkshade Caverns",
	--Eastmarch
	["direfrostkeep_base"] = 449,
	["direfrostkeepheroic_base"] = 449,
	["direfrostkeepsummit_base"] = 449,
	["ui_map_frvfrstvlt01_base"] = 1080,
	["ui_map_frvfrstvlt02_base"] = 1080,
	["ui_map_frvfrstvlt03_base"] = 1080,
	["ui_map_frvfrstvlt04_base"] = 1080,
	["ui_map_frvfrstvlt05_base"] = 1080,
	--Elsweyr
	["sunspirehall001_base"] = 1121,
	["sunspirehall002_base"] = 1121,
	["sunspirehall003_base"] = 1121,
	["sunspirehall004_base"] = 1121,
	["sunspireoverworld_base"] = 1121,
	["sunspireroom001_base"] = 1121,
	["sunspireroom002_base"] = 1121,
	--Glenumbra
	["spindleclutch_base"] = "Spindleclutch",
	["spindleclutchheroic_base"] = "Spindleclutch",
	--Gold Coast
	["ui_map_domdepthsofmal2_base"] = 1081,
	["ui_map_domdepthsofmal3_base"] = 1081,
	["ui_map_domdepthsofmal4_base"] = 1081,
	["ui_map_domdepthsofmal5_base"] = 1081,
	["ui_map_domdepthsofmal_base"] = 1081,
	--Grahtwood
	["eldenhollow_base"] = "Elden Hollow",
	["eldenhollowheroic1_base"] = "Elden Hollow",
	["eldenhollowheroic2_base"] = "Elden Hollow",
	["maarscave1_base"] = 1123,
	["maarsmap01_base"] = 1123,
	["maarsmap02_base"] = 1123,
	["maarsmap03_base"] = 1123,
	["maarsmap04_base"] = 1123,
	["maarsmap05_base"] = 1123,
	["maarsmap06_base"] = 1123,
	["maarsoutsidemap001_base"] = 1123,
	["maarsoutsidemap002_base"] = 1123,
	["maarsoutsidemap003_base"] = 1123,
	--Greenshade
	["cityofashboss_base"] = "City of Ash",
	["cityofashmain_base"] = "City of Ash",
	["vetcirtyash01_base"] = "City of Ash",
	["vetcirtyash02_base"] = "City of Ash",
	["vetcirtyash03_base"] = "City of Ash",
	["vetcirtyash04_base"] = "City of Ash",
	["marchodsacrifices_base"] = 1055,
	--Malabal Tor
	["tempestisland_base"] = 131,
	["tempestislandncave_base"] = 131,
	["tempestislandsecave_base"] = 131,
	["tempestislandswcave_base"] = 131,
	--Murkmire
	["ui_map_blackroseprison01_base"] = 1082,
	--Reaper's March
	["maw_of_lorkaj_base"] = 725,
	["mawlorkajhall_base"] = 725,
	["mawlorkajsevenriddles_base"] = 725,
	["mawlorkajsuthaysanctuary_base"] = 725,
	["mhkmoonhunterkeep2_base"] = 1052,
	["mhkmoonhunterkeep3_base"] = 1052,
	["mhkmoonhunterkeep_base"] = 1052,
	["selenesweb_base"] = 31,
	["seleneswebfinalbossarea_base"] = 31,
	--Rivenspire
	["cryptofhearts_base"] = "Crypt of Hearts",
	["cryptofheartsheroic_base"] = "Crypt of Hearts",
	["cryptofheartsheroicboss"] = "Crypt of Hearts",
	--Shadowfen
	["arxcorinium_base"] = 148,
	["ui_cradleofshadowsint_001_base"] = 848,
	["ui_cradleofshadowsint_002_base"] = 848,
	["ui_cradleofshadowsint_003_base"] = 848,
	["ui_cradleofshadowsint_004_base"] = 848,
	["ui_cradleofshadowsint_005_base"] = 848,
	["shadowscaleenclave_base"] = 843,
	["ui_map_mazzatunext_base"] = 843,
	["ui_map_mazzatunint001_base"] = 843,
	["ui_map_mazzatunint002_base"] = 843,
	["ui_map_mazzatunint003_base"] = 843,
	--Southern Elsweyr
	["moongravesection1_base"] = 1122,
	["moongravesection2_base"] = 1122,
	["moongravesection3_base"] = 1122,
	["moongravesection4_base"] = 1122,
	--Stonefalls
	["fungalgrotto_base"] = "Fungal Grotto",
	["fungalgrottosecretroom_base"] = "Fungal Grotto",
	--Stormhaven
	["ui_map_fanglairext_base"] = 1009, --duplicated in Bangkorai for some reason
	["ui_map_scalecaller001_base"] = 1010,
	["ui_map_scalecaller002_base"] = 1010,
	["ui_map_scalecaller003_base"] = 1010,
	["ui_map_scalecaller004_base"] = 1010,
	["wayrestsewers_base"] = "Wayrest Sewers",
	--Summerset
	["ui_map_cloudresttrial_base"] = 1051,
	--The Rift
	["blessedcrucible1_base"] = 64,
	["blessedcrucible2_base"] = 64,
	["blessedcrucible3_base"] = 64,
	["blessedcrucible4_base"] = 64,
	["blessedcrucible5_base"] = 64,
	["blessedcrucible6_base"] = 64,
	["blessedcrucible7_base"] = 64,
	--Vvardenfell
	["ui_map_hofabricboss3_base"] = 975,
	["ui_map_hofabriccaves_base"] = 975,
	["ui_map_hofabricext1_base"] = 975,
	["ui_map_hofabrichall1_base"] = 975,
	["ui_map_hofabrichall2_base"] = 975,
	["ui_map_hofabricloop_base"] = 975,
	--Wrothgar
	["arenasclockwork2_base"] = 677,
	["arenasclockworkint_base"] = 677,
	["arenaslavacaveinterior_base"] = 677,
	["arenaslobbyexterior_base"] = 677,
	["arenasmephalaexterior_base"] = 677,
	["arenasmurkmirecaveint_base"] = 677,
	["arenasmurkmirecaveinter_base"] = 677,
	["arenasmurkmireexterior_base"] = 677,
	["arenasoblivionexterior_base"] = 677,
	["arenasshiveringisles_base"] = 677,
	["arenaswrothgarexterior_base"] = 677,
	["icereachpart1"] = 1152,
	["icereachpart2"] = 1152,
}

PetZone.ZoneData["dungeonsPub"] = {
	[PZ_ZONE_MAPPING_STRING] = "~Public Dungeons",
	--Alik'r Desert
	["lostcity_base"] = 308,
	--Auridon
	["toothmaulgully_base"] = 486,
	--Bangkorai
	["razakswheel_base"] = 169,
	--Coldharbour
	["villageofthelost_base"] = 557,
	--Cyrodiil
--[[ No pets in Cyrodiil!
	]]
	--Deshaan
	["forgottencrypts_base"] = 306,
	--Eastmarch
	["hallofthedead_base"] = 339,
	--Elsweyr
	["orcrest2_base"] = 1090,
	["orcrest_base"] = 1090,
	["orcrestsewer_base"] = 1090,
	["ui_maps_orcrest"] = 1090,
	["rimmennecropolis_base"] = 1089,
	--Glenumbra
	["badmanscave_base"] = 284,
	["badmansend_base"] = 284,
	["badmansstart_base"] = 284,
	--Grahtwood
	["rootsunder_base"] = 124,
	--Greenshade
	["rulanyilsfall_base"] = 137,
	--Malabal Tor
	["crimsoncove02_base"] = 138,
	["crimsoncove_base"] = 138,
	--Reaper's March
	["thevilemansefirstfloor_base"] = 487,
	["thevilemansesecondfloor_base"] = 487,
	["vilemansehouse01_base"] = 487,
	["vilemansehouse02_base"] = 487,
	--Rivenspire
	["obsidianscar_base"] = 162,
	--Shadowfen
	["sanguinesdemesne_base"] = 134,
	--Stonefalls
	["crowswood_base"] = 216,
	["crowswooddungeon_base"] = 216,
	--Stormhaven
	["bonesnapruins_base"] = 142,
	["bonesnapruinssecret_base"] = 142,
	--Summerset
	["karndar_01_base"] = 1020, --unsure. Karnwasten?
	["karndar_02_base"] = 1020,
	["karndar_03_base"] = 1020,
	["karndar_03b_base"] = 1020,
	["karndar_04_base"] = 1020,
	["karndar_05_base"] = 1020,
	["karndar_06_base"] = 1020,
	["sum_karnwasten_base"] = 1020,
	["sunhold_base"] = 1021,
	["ui_maps_sunhold"] = 1021,
	--The Rift
	["lionsden_hiddentunnel_base"] = 341,
	["thelionsden_base"] = 341,
	--Vvardenfell
	["cavernsofkogoruhnfw03_base"] = 919,
	["drinithtombfw01b_base"] = 919,
	["drinithtombfw01_base"] = 919,
	["forgottendepthsfw04_base"] = 919,
	["forgottenwastesext_base"] = 919,
	["koradurfw02_base"] = 919,
	["nchuleftingth1_base"] = 918,
	["nchuleftingth2_base"] = 918,
	["nchuleftingth3_base"] = 918,
	["nchuleftingth4_base"] = 918,
	["nchuleftingth5a_base"] = 918,
	["nchuleftingth5_base"] = 918,
	["nchuleftingth6_base"] = 918,
	["nchuleftingth7_base"] = 918,
	--Wrothgar
	["oldorsiniummap01_base"] = 706,
	["oldorsiniummap02_base"] = 706,
	["oldorsiniummap03_base"] = 706,
	["oldorsiniummap04_base"] = 706,
	["oldorsiniummap05_base"] = 706,
	["oldorsiniummap06_base"] = 706,
	["oldorsiniummap07_base"] = 706,
	["rkindaleftint01_base"] = 705,
	["rkindaleftint02_base"] = 705,
	["rkindaleftint03_base"] = 705,
	["rkindaleftoutside_base"] = 705,
}

PetZone.ZoneData["eastmarch"] = { --Eastmarch
    [PZ_ZONE_ID_STRING] = 101,
    --Eastmarch
    ["eastmarch_base"] = 101, --Eastmarch
    ["fortamol_base"] = "Fort Amol",
    ["hallofthedead_base"] = 339,
    ["thechillhollow_base"] = 359,
    ["icehammersvault_base"] = 360,
    ["oldsordscave_base"]   = 361,
    ["thefrigidgrotto_base"] = 362,
    ["stormcragcrypt_base"] = 363,
    ["thebastardstomb_base"] = 364,
    ["windhelm_base"] = true,
}

PetZone.ZoneData["glenumbra"] = { --Glenumbra
    [PZ_ZONE_ID_STRING] = 3,
    --Glenumbra
    ["glenumbra_base"] = 3, -- Glenumbra
    ["daggerfall_base"] = true,
    ["crosswych_base"] = 256,
    ["ilessantower_base"] = 309,
    ["silumm_base"] = 310,
    ["minesofkhuras_base"] = 311,
    ["enduum_base"] = 312,
    ["eboncrypt_base"] = 313,
    ["cryptwatchfort_base"] = 314,
    ["badmanscave_base"] = 284,
    ["aldcroft_base"] = true,
    --Betnikh (Daggerfall, lvl 1-5)
    ["betnihk_base"] = 535, --"Betnikh"
    ["stonetoothfortress_base"] = "Stonetooth Fortress",
    --Stros M'Kai (Daggerfall, lvl 1-5)
    ["strosmkai_base"] = 534, -- "Stros M'Kai",
    ["porthunding_base"] = "Port Hunding",
}

PetZone.ZoneData["grahtwood"] = { --Grahtwood
    [PZ_ZONE_ID_STRING] = 383,
    --Grahtwood
    ["grahtwood_base"] = 383, -- Grahtwodd
    ["haven_base"] = true,
    ["eldenrootgroundfloor_base"] = 599,
    ["nesalas_base"] = 442,
    ["dessicatedcave_base"] = 475,
    ["burrootkwamamine_base"] = 444,
    ["vindeathcave_base"] = 477,
    ["wormrootdepths_base"] = 478,
    ["mobarmine_base"] = 447,
    ["rootsunder_base"] = 124,
    ["redfurtradingpost_base"] = "Redfur Trading Post",
    ["eldenrootservices_base"] = 383,
}

PetZone.ZoneData["greenshade"] = { --Greenshade
    [PZ_ZONE_ID_STRING] = 108,
    --Greenshade
    ["greenshade_base"] = 108, -- Greenshade
    ["marbruk_base"] = true,
    ["woodhearth_base"] = true,
    ["caracdena_base"] = 575,
    ["gurzagsmine_base"] = 576,
    ["theunderroot_base"] = 577,
    ["narilnagaia_base"] = 578,
    ["harridanslair_base"] = 579,
    ["barrowtrench_base"] = 580,
    ["rulanyilsfall_base"] = 137,
}

PetZone.ZoneData["guildmaps"] = {
	[PZ_ZONE_MAPPING_STRING] = "~Fighters and Mages Guilds",
	["abagarlas_base"] = 595,
	["chateaumasterbedroom_base"] = 219,
	["chateauravenousrodent_base"] = 219,
	["cheesemongershollow_base"] = 203,
	["circusofcheerfulslaughter_base"] = 218,
	["eyevea_base"] = 267,
	["fortvirakruin_base"] = 386,
	["gladeofthedivineasakala_base"] = 541,
	["gladeofthedivineshivering_base"] = 541,
	["gladeofthedivinevuldngrav_base"] = 541,
	["hallsofsubmission_base"] = 209,
	["mzendeldt_base"] = 207,
	["ragnthar_base"] = 385,
	["stonefang_base"] = 544,
	["theearthforgepublic_base"] = 208,
	["theearthforge_base"] = 208,
	["_fortinbras"] = "Fortinbras",
}

PetZone.ZoneData["malabaltor"] = { --Malabal Tor
    [PZ_ZONE_ID_STRING] = 58,
    --Malabal Tor
    [PZ_ZONE_MAPPING_STRING] = "Malabal Tor",
    ["malabaltor_base"] = 58, -- Malabal Tor
    ["velynharbor_base"] = "Velyn Harbor",
    ["vulkwasten_base"] = true,
    ["baandaritradingpost_base"] = "Baandari Trading Post",
    ["blackvineruins_base"] = 473,
    ["deadmansdrop_base"] = 468,
    ["hoarvorpit_base"] = 470,
    ["shaelruins_base"] = 471,
    ["rootsofsilvenar_base"] = 472,
    ["tomboftheapostates_base"] = 469,
    ["crimsoncove02_base"] = 138,
}

PetZone.ZoneData["reapersmarch"] = { --Reaper's March
    [PZ_ZONE_ID_STRING] = 382,
    --Reaper's March
    [PZ_ZONE_MAPPING_STRING] = "Reapers March",
    ["reapersmarch_base"] = 382, --"Reapers March",
    ["dune_base"] = true,
    ["thibautscairn_base"] = 462,
    ["kunasdelve_base"] = 463,
    ["fardirsfolly_base"] = 464,
    ["clawsstrike_base"] = 465,
    ["weepingwindcave_base"] = 466,
    ["jodeslight_base"] = 467,
    ["thevilemansefirstfloor_base"] = 487,
    ["rawlkha_base"] = 455,
    ["arenthia_base"] = true,
}

PetZone.ZoneData["rivenspire"] = { --Rivenspire
    [PZ_ZONE_ID_STRING] = 20,
    ["rivenspire_base"] = 20, --Rivenspire
    ["shornhelm_base"] = true,
    ["northpoint_base"] = 589,
    ["crestshademine_base"] = 321,
    ["erokii_base"] = 325,
    ["flyleafcatacombs_base"] = 322,
    ["hildunessecretrefuge_base"] = 326,
    ["orcsfingerruins_base"] = 324,
    ["tribulationcrypt_base"] = 323,
    ["obsidianscar_base"] = 162,
    ["hoarfrostdowns_base"] = "Hoarfrost Downs",

    ["hoarfrost_base"] = "Hoarfrost Downs", --Hoarfrost Downs
    ["shroudedpass_base"] = "Shrouded Pass", --Shrouded Pass
}

PetZone.ZoneData["shadowfen"] = { --Shadowfen
    [PZ_ZONE_ID_STRING] = 117,
    ["shadowfen_base"] = 117, --Shadowfen
    ["stormhold_base"] = true,
    ["altencorimont_base"] = "Alten Corimont",
    ["atanazruins_base"] = 272,
    ["brokentuskcave_base"] = 271,
    ["chidmoskaruins_base"] = 273,
    ["gandranen_base"] = 275,
    ["onkobrakwamamine_base"] = 274,
    ["shrineofblackworm_base"] = 270,
    ["sanguinesdemesne_base"] = 134,
}

PetZone.ZoneData["stonefalls"] = { --Stonefalls
    [PZ_ZONE_ID_STRING] = 41,
    ["stonefalls_base"] = 41, --Stonefalls
    ["davonswatch_base"] = "Davons Watch",
    ["innerseaarmature_base"] = 287,
    ["emberflintmine_base"] = 296,
    ["mephalasnest_base"] = 288,
    ["softloamcavern_base"] = 289,
    ["hightidehollow_base"] = 290,
    ["sheogorathstongue_base"] = 291,
    ["crowswood_base"] = 216,
    ["balfoyen_base"] = 281, -- Bal Foyen
    ["dhalmora_base"] = true,
    ["bleakrock_base"] = 280,
    ["hozzinsfolley_base"] = "Hozzins Folley",
    ["ebonheart_base"] = true,
    ["kragenmoor_base"] = true,
    ["bleakrockvillage_base"] = "Bleackrock Village",
}

PetZone.ZoneData["stormhaven"] = { --Stormhaven
    [PZ_ZONE_ID_STRING] = 19,
    ["stormhaven_base"] = 19, --Stormhaven
    ["portdunwatch_base"] = 315,
    ["koeglinmine_base"] = 316,
    ["pariahcatacombs_base"] = 317,
    ["farangelsdelve_base"] = 318,
    ["bearclawmine_base"] = 319,
    ["norvulkruins_base"] = 320,
    ["bonesnapruins_base"] = 142,
    ["wayrest_base"] = 601,
    ["koeglinvillage_base"] = "Koeglin Village",
    ["alcairecastle_base"] = 545,
}

PetZone.ZoneData["therift"] = { --The Rift
    [PZ_ZONE_ID_STRING] = 103,
    [PZ_ZONE_MAPPING_STRING] = "The Rift",
    ["therift_base"] = 103, --The Rift
    ["shorsstone_base"] = 402,
    ["riften_base"] = true,
    ["avancheznel_base"] = 413,
    ["ebonmeretower_base"] = "Ebonmere Tower",
    ["snaplegcave_base"] = 480,
    ["fortgreenwall_base"] = 481,
    ["shroudhearth_base"] = 482,
    ["brokenhelm_base"] = 485,
    ["thelionsden_base"] = 341,
    ["nimalten_base"] = 412,
}

PetZone.ZoneData["wrothgar"] = { --Wrothgar
    [PZ_ZONE_ID_STRING] = 684,
    ["wrothgar_base"] = 684, --Wrothgar
    ["morkul_base"] = true,
    ["rkindaleftoutside_base"] = 705,
    ["oldorsiniummap06_base"] = 706,
    ["argentmine2_base"] = 694,
    ["coldperchcavern_base"] = 693,
    ["thukozods_base"] = 691,
    ["zthenganaz_base"] = 697,
    ["kennelrun_base"] = 689,
    ["watchershold_base"] = 692,
    ["orsinium_base"] = true,
    ["morkulstronghold_base"] = 698,

    ["arenaslobbyexterior_base"] = "Lobby of Maelstrom Arena",
}

PetZone.ZoneData["thievesguild"] = { --Hew's Bane
    [PZ_ZONE_ID_STRING] = 816,
    [PZ_ZONE_MAPPING_STRING] = "Hews Bane",
    ["hewsbane_base"] = 816, --Hew's Bane
    ["abahslanding_base"] = "Abahs Landing",
    ["bahrahasgloom_base"] = 817,
    ["sharktoothgrotto1_base"] = 676,
}

PetZone.ZoneData["darkbrotherhood"] = { -- Gold Coast
    [PZ_ZONE_ID_STRING] = 823,
    [PZ_ZONE_MAPPING_STRING] = "Gold Coast",
    ["goldcoast_base"] = 823, -- "Gold Coast",
    ["hrotacave_base"] = 824,
    ["garlasagea_base"] = 825,
    ["anvilcity_base"] = 831,
    ["kvatchcity_base"] = 832,
}

PetZone.ZoneData["vvardenfell"] = { -- Vvardenfell
    [PZ_ZONE_ID_STRING] = 849,
    ["vvardenfell_base"] = 849, --Vvardenfell
    ["cavernsofkogoruhnfw03_base"] = "Caverns Of Kogoruhn",
    ["khartagpoint_base"] = 921,
    ["ashalmawia02_base"] = 961,
    ["zainsipilu_base"] = 922,
    ["matusakin_base"] = 923,
    ["pulklower_base"] = 924,
    ["nchuleftdepths_base"] = 918,
    ["viveccity_base"] = "Vivec City",
    ["viviccity_base"] = "Vivec City",
    ["balmora_base"] = true,
    ["sadrithmora_base"] = true,
    ["forgottenwastes_base"] = 919,
    ["vivecsdelyn03b_base"] = "Vivecs Delyn 03b",
}

PetZone.ZoneData["clockwork"] = {-- Clockwork City
    [PZ_ZONE_ID_STRING] = 980,
    [PZ_ZONE_MAPPING_STRING] = "Clockwork City",
    ["clockwork_base"] = 980, -- Clockwork City
    ["brassfortress_base"] = 981,
    ["hallsofregulation_base"] = 985,
    ["shadowcleft_base"] = 986,
}

PetZone.ZoneData["summerset"] = {-- Summerset
    [PZ_ZONE_ID_STRING] = 1011,
    --Summerset
    ["alinor_base"] = true,
    ["archonsgrove_base"] = 1017,
    ["artaeum_base"] = 1027, --"Artaeum"
    ["etonnir_base"] = 1015,
    ["kingshavenint1_base"] = 1018,
    ["lillandrill_base"] = true,
    ["shimmerene_base"] = true,
    ["sum_karnwasten"] = 1020,
    ["summerset_base"] = 1011, -- Summerset
    ["sunhold_base"] = 1021,
    ["torhamekhard_base"] = 1014,
    ["traitorsvault03_base"] = 1016,
    ["wastencoraldale_base"] = 1019,
    ["collegeofpsijicsruins_base"] = "College of Psijics Ruins (indoor)", --College of Psijics Ruins (indoors area...)
}

PetZone.ZoneData["murkmire"] = {-- Murkmire
    [PZ_ZONE_ID_STRING] = 726,
    --Murkmire
    ["murkmire_base"]       = 726, -- Murkmire
    ["lilmothcity_base"]    = "Lilmoth",
    ["deadwatervillage_base"] = "Deadwater Village",
    --[[
        [1064] = "Hunter's Glade",
        [1065] = "Blight Bog Sump",
        [1066] = "Tsofeer Cavern",
        [1067] = "The Dreaming Nest",
        [1068] = "Ixtaxh Xanmeer",
        [1069] = "Tomb of Many Spears",
        [1070] = "Lilmoth Outlaws Refuge",
        [1071] = "Xul-Thuxis",
        [1072] = "Norg-Tzel",
        [1073] = "Teeth of Sithis",
        [1074] = "The Sunless Hollow",
        [1075] = "The Sunless Hollow",
        [1076] = "The Sunless Hollow",
        [1077] = "The Swallowed Grove",
        [1078] = "Remnant of Argon",
        [1079] = "Vakka-Bok Xanmeer",
        [1083] = "Deep-Root",
        [1108] = "Lakemire Xanmeer Manor",
        [1109] = "Enchanted Snow Globe Home",
    ]]
}

PetZone.ZoneData["elsweyr"] = {-- Elsweyr
    [PZ_ZONE_ID_STRING] = 1086,
    --Northern Elsweyr
    ["elsweyr_base"]       = 1086, -- Northern Elsweyr
    ["abodeofignominy_base"] = 1091,
    ["ashencombs1_base"] = 1086, --unsure
    ["ashencombs2_base"] = 1086, --unsure
    ["cheesemongerava_base"] = 203,
    ["cicatriceoasis_base"] = 1111,
    ["cicatriceoasisbossroom_base"] = 1111,
    ["cicatriceoasisupperfloor_base"] = 1111,
    ["dancingmoon01_base"] = 1117,
    ["dancingmoon02_base"] = 1117,
    ["dancingmoon03_base"] = 1117,
    ["desertwind2_2a_base"] = 1119,
    ["desertwind2_base"] = 1119,
    ["desertwind2a_base"] = 1119,
    ["desertwind3_base"] = 1119,
    ["desertwind_base"] = 1119,
    ["dragonguardoutpost_base"] = 1110,
    ["elsweyr_base"] = 1086,
    ["hakoshaecrypts_base"] = 1114,
    ["jodesembrace1.base"] = 1130,
    ["jodesembrace2.base"] = 1130,
    ["jodesembrace3.base"] = 1130,
    ["khasdaskeep01_base"] = 1120, --Meirvale Keep?
    ["khasdaskeep02_base"] = 1120,
    ["khasdaskeep03_base"] = 1120,
    ["khasdaskeep04_base"] = 1120,
    ["khasdaskeep05_base"] = 1120,
    ["khasdaskeep06_base"] = 1120,
    ["merrivillesugarfarm_base"] = 1115,
    ["moongate_base"] = 1103,
    ["moonsurface_base"] = 1103,
    ["mulaamnirslair_base"] = 1097,
    ["phoom01_base"] = 1086, --unsure
    ["predatorrise_base"] = 1092,
    ["rimmen_base"] = "Rimmen",
    ["rimmencrypts_base"] = 1101,
    ["rimmenoutlawsrefuge_base"] = 1088,
    ["rimmenpalace_base"] = 1099,
    ["rimmenpalacecourtyard_base"] = 1099,
    ["rimmenpalaceinterior_base"] = 1099,
    ["rimmensewer_base"] = 1101,
    ["riverholdcity_base"] = 1098,
    ["riverholdinstance_base"] = 1098,
    ["sepulcherofmischance00_base"] = 1102,
    ["sepulcherofmischance00b_base"] = 1102,
    ["sepulcherofmischance01_base"] = 1102,
    ["sepulcherofmischance02_base"] = 1102,
    ["sepulcherofmischance03_base"] = 1102,
    ["sepulcherofmischance04_base"] = 1102,
    ["skoomacatscloister1_base"] = 1105,
    ["skoomacatscloister2_base"] = 1105,
    ["smugglershideout_base"] = 1098,
    ["starhavencatacombs_base"] = 1106,
    ["starhaventraininghalls_base"] = 1106,
    ["stitches_base"] = "The Stitches",
    ["sugarslingersden01_base"] = 774,
    ["sugarslingersden01a_base"] = 774,
    ["sugarslingersden01b_base"] = 774,
    ["sugarslingersden02_base"] = 774,
    ["sugarslingersden02a_base"] = 774,
    ["sugarslingersden02b_base"] = 774,
    ["sugarslingersden02c_base"] = 774,
    ["thescab_base"] = 1095,
    ["thetangle_base"] = 1096,
    ["tombofserpents_base"] = 1094,
    ["tutorial1_base"] = 1086,
    ["tutorial2_base"] = 1086,
    ["tutorial3_base"] = 1086,
    ["weepingscar_base"] = 1112, --one or more of these is probably not the ossuary
    ["weepingscar_f2_base"] = 1112,
    ["weepingscarmain_base"] = 1112,
    ["weepingscarpit_base"] = 1112,
}

PetZone.ZoneData["southernelsweyr"] = {-- Southern Elsweyr
    [PZ_ZONE_ID_STRING] = 1133,
    --Southern Elsweyr
    ["southernelsweyr_base"]       = 1133, -- Southern Elsweyr
	["senchal_base"] = "Senchal",
    ["els_dg_sanctuary_base"] = 1146, --Dragonguard Sanctum
    ["senchalpalace01_base"] = "Senchal Palace",
}

PetZone.ZoneData["skyrim"] = {-- Skyrim
    [PZ_ZONE_ID_STRING] = 1160,
    --Western Skyrim
    ["westernskryim_base"]  = 1160,
    ["solitudecity_base"]   = "Solitude City",
    --Blackreach
    ["blackreach_base"]     = 1161, -- Blackreach (underground of Western Skyrim)
}

PetZone.ZoneData["reach"] = {-- Reach
    [PZ_ZONE_ID_STRING] = 1207,
    --The Reach
    ["reach_base"] = 1207,
    ["markarthcity_base"] = "Markarth City",
    --Blackreach
    ["u28_blackreach_base"] = 1208, -- Blackreach (underground of The Reach)
}

PetZone.ZoneData["blackwood"] = {-- Blackwood
    [PZ_ZONE_ID_STRING] = 1261,
    ["blackwood_base"] = 1261,
    ["u30_gideoncity_base"] = "Gideon",
    ["u30_leyawiincity_base"] = "Leyawiin",
    ["stonewastesfortress_base"] = "Stonewastes Fortress",
}

PetZone.ZoneData["deadlands"] = {--Deadlands
    [PZ_ZONE_ID_STRING] = 1282,
    ["u32deadlandszone_base"] = 1286, --Deadlands
    ["u32_fargrave_base"] = 1282, --Fargrave
}

PetZone.ZoneData["galen"] = { --Galen
    [PZ_ZONE_ID_STRING] = 1383,
    ["u36_galenisland_base"] = 1383,
    ["u36_vastyrcity_base"] = "Vastyr City",
}

PetZone.ZoneData["systres"] = { --Systren
    [PZ_ZONE_ID_STRING] = 1318,
    ["u34_systreszone_base"] = 1318,
    ["u34_gonfalonbaycity_base"] = "Gonfalon",
    ["u34_amenosstation_city_base"] = "Amenos Station",
}

PetZone.ZoneData["telvanni"] = { --Telvanni Peninsula
    [PZ_ZONE_ID_STRING] = 1414,
    ["u38_telvannipeninsula_base"] = 1414,
    ["u38_necrom_base"] = "Necrom",
}

PetZone.ZoneData["apocrypha"] = {--Apocrypha
    [PZ_ZONE_ID_STRING]           = 1413,
    ["u38_apocrypha_base"]          = 1413,
    ["u38_ciphersmidden_city_base"] = "Ciphersmidden",
}

PetZone.ZoneData["westweald"] =  { -- Gold Coast
    [PZ_ZONE_ID_STRING] = 1443,
    ["u42_skingrad_base"] = "Skingrad",
    ["westwealdoverland_base"] = "Westweald Overland",
}

PetZone.ZoneData["solstice"] =  { -- Seasons of the Worm Cult Pt 1 & 2
    [PZ_ZONE_ID_STRING] = 1502,
    ["u46_sunport_base"] = "Sunport",
    ["solsticeoverland_base"] = "Solstice Overland",
}

