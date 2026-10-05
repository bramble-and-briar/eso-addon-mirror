local BossData = EOTU.internal.bossData or {}
EOTU.internal.bossData = BossData

BossData.ChampionTableIndex = {
	X = 1,
	Y = 2,
	NAME = 3,
}

BossData.PublicChampionTableStore = {
	["u30_oblivion_portal_base_0"] = {
		{ 0.1545, 0.4500, "Outer Ring Boss" },
		{ 0.1822, 0.3075, "Outer Ring Boss" },
		{ 0.3030, 0.1628, "Outer Ring Boss" },
		{ 0.3135, 0.3255, "Salosuum" },
		{ 0.3187, 0.4080, "Salosuum" },
		{ 0.4133, 0.5272, "Outer Ring Boss" },
		{ 0.4178, 0.3645, "Salosuum" },
		{ 0.4793, 0.2137, "Outer Ring Boss" },
		{ 0.5767, 0.4118, "Outer Ring Boss" },
	},
	["u30_oblivion_portal_boss"] = {
		{ 0.7350, 0.4860, "Havocrel Duke of Storms" },
	},
	["u48_base_calindvalegardenspd_0"] = {
    { 0.2130, 0.5150, "Ensnared Ogrim" },
    { 0.2230, 0.5320, "The Tender" },
    { 0.4450, 0.7510, "The Stone Raiser" },
    { 0.5550, 0.5770, "Brooding Infernium" },
    { 0.5970, 0.2270, "Ux the Unmerciful" },
    { 0.6100, 0.2420, "Speaker Waldyr" },
    { 0.6420, 0.8220, "Stone Gryphon" },
    { 0.7430, 0.4430, "Infested Lurcher" },
	},
	["badmanscave_base_0"] = {
		{ 0.1880, 0.4010, "Giant Snake Mother" },
		{ 0.4230, 0.7080, "Rutmange" },
		{ 0.5360, 0.7040, "Bloodcraw" },
		{ 0.6020, 0.4600, "Skitterflame" },
		{ 0.7140, 0.7500, "Bloatgut" },
	},
	["bonesnapruinssecret_base_0"] = {
		{ 0.2440, 0.5310, "Zix" },
		{ 0.2900, 0.7330, "Thargen" },
		{ 0.3290, 0.5500, "Mar-Zak" },
		{ 0.3830, 0.1630, "The Eternal One" },
		{ 0.4340, 0.3220, "Rork Bonehammer" },
		{ 0.5050, 0.7980, "Torak Shadebringer" },
		{ 0.5430, 0.3370, "Zix" },
		{ 0.5960, 0.5790, "Lughar" },
		{ 0.6280, 0.4170, "Bloodmaw" },
	},
	["crimsoncove02_base_0"] = {
		{ 0.3460, 0.5540, "Old Strongclaw" },
		{ 0.5460, 0.4690, "Povaren One-Eye" },
		{ 0.5310, 0.3400, "Yiralai the Wicked" },
		{ 0.6090, 0.0960, "Reja Laransdottir" },
		{ 0.5920, 0.7620, "Flat Tooth" },
		{ 0.6090, 0.7080, "Kathner the Cunning" },
		{ 0.6930, 0.5480, "Rokut the Mauler" },
		{ 0.6890, 0.3410, "Pilot Ostrala" },
		{ 0.7090, 0.4510, "Captain Cynoric" },
		{ 0.8740, 0.3030, "Viro Redhands (wanders)" },
		{ 0.8530, 0.4790, "Captain Siro" },
		{ 0.8710, 0.4990, "Helvia Livianus" },
	},
	["crowswood_base_0"] = {
		{ 0.2710, 0.8550, "The Moonlit Maiden" },
		{ 0.2700, 0.5830, "Buron" },
		{ 0.3670, 0.5310, "Shriekscorn" },
		{ 0.6000, 0.4340, "Grizzlehide" },
		{ 0.5700, 0.3770, "Wrathvenom" },
		{ 0.6370, 0.1890, "Rulantaril's Construct" },
		{ 0.6950, 0.5380, "Ghyslain" },
	},
	["forgottencrypts_base_0"] = {
		{ 0.4780, 0.1600, "Timothe the Sharp" },
		{ 0.5430, 0.4170, "The Forgotten Sheriff" },
		{ 0.5570, 0.9220, "Vindicator Kalga" },
		{ 0.5820, 0.8830, "Vindicator Alga" },
		{ 0.5960, 0.8300, "Group Event" },
		{ 0.6050, 0.9210, "Vindicator Tralga" },
		{ 0.6940, 0.2630, "Fyrayn Telvanni" },
		{ 0.7510, 0.5520, "The Silent Colossus" },
	},

	["forgottenwastesext_base_0"] = {
		{ 0.2010, 0.5530, "Stone-Boiler Omalas" },
		{ 0.2140, 0.5340, "Mountain-Caller Hlaren" },
		{ 0.2380, 0.5360, "Brander Releth" },
		{ 0.6190, 0.5020, "Cliff Strider Matriarch" },
	},
	["koradurfw02_base_0"] = {
		{ 0.2450, 0.7830, "Mynar Igna" },
		{ 0.2890, 0.7510, "Conflagrator Llaals" },
	},
	["cavernsofkogoruhnfw03_base_0"] = {
		{ 0.0900, 0.2380, "Beckoner Morvayn" },
	},
	["forgottendepthsfw04_base_0"] = {
		{ 0.1860, 0.5000, "Coaxer Veran" },
		{ 0.2240, 0.4660, "Castigator Athin" },
		{ 0.2260, 0.5300, "Confessor Dradas" },
		{ 0.7000, 0.7890, "Nevena Nirith" },
		{ 0.7370, 0.7520, "Wakener Maras" },
	},
	["drinithtombfw01_base_0"] = {
		{ 0.7230, 0.8070, "Voracity" },
	},
	["u34_ghosthavenbayext_base_0"] = {
		{ 0.5680, 0.2100, "Razor Fangs" },
		{ 0.6660, 0.7940, "Captain Altair" },
		{ 0.7700, 0.5050, "Hadolid Broodmother" },
	},
	["u34_ghosthavenbayint_base_0"] = {
		{ 0.4040, 0.4520, "Captain Marley" },
		{ 0.4700, 0.6020, "Captain Tuvacca" },
		{ 0.4800, 0.2630, "Captain Fauvette" },
		{ 0.5610, 0.4380, "Commodore Malfairre" },
	},
	["hallofthedead_base_0"] = {
		{ 0.2380, 0.7470, "Hrerik Lodorrsbane" },
		{ 0.3420, 0.8830, "Sorgild Lodorrsbane" },
		{ 0.3660, 0.4400, "Malana" },
		{ 0.4170, 0.2230, "The Old Priest" },
		{ 0.4220, 0.9030, "Hlaki Lodorrsbane" },
		{ 0.4990, 0.7630, "Lodorr" },
		{ 0.5120, 0.5750, "Ulfnir Ice-Blood" },
		{ 0.6570, 0.9310, "Jalfrid Lodorrsbane" },
		{ 0.7640, 0.5010, "Reynir the Destroyer" },
		{ 0.7610, 0.7810, "Gefvid Lodorrsbane" },
	},
	["sum_karnwasten_base_0"] = {
		{ 0.1890, 0.6940, "Gilleruk the Vicious" },
		{ 0.2040, 0.4710, "Tendirrion" },
		{ 0.5210, 0.6060, "Nolore Stieve" },
		{ 0.6370, 0.8180, "Waste of Flesh" },
		{ 0.6540, 0.5000, "Shahmar" },
		{ 0.8830, 0.7160, "K'Garza" },
	},
	["labyrinthian_base_0"] = {
		{ 0.8140, 0.6940, "Blackmaw" },
		{ 0.8330, 0.2860, "Tulnir" },
	},
	["labyrinthianb_base_0"] = {
		{ 0.1420, 0.5120, "Garneld the Hollow" },
		{ 0.4060, 0.5770, "Gralthum the Tormented" },
		{ 0.6850, 0.4020, "Andumgar" },
		{ 0.8390, 0.5610, "Sleeraak" },
		{ 0.8750, 0.6020, "Hjarnnir" },
	},
	["u42_leftwheal_ext2_base_0"] = {
		{ 0.0690, 0.5300, "Klynklaynk" },
		{ 0.2750, 0.6210, "Yrrkkyyn" },
		{ 0.3050, 0.5620, "Zvartek the Weapon Master" },
		{ 0.4510, 0.1170, "Ranishyn the Marred" },
		{ 0.4620, 0.1280, "Olashyn the Twisted" },
		{ 0.5650, 0.3530, "Zenefrit" },
		{ 0.6060, 0.8080, "Swarmkeeper Xvarcon" },
		{ 0.8550, 0.5010, "Hrakkzur" },
	},
	["lostcity_base_0"] = {
		{ 0.3300, 0.6120, "Spider Guardian" },
		{ 0.3440, 0.5890, "Scorpion Guardian" },
		{ 0.3350, 0.5650, "The Silent Sword" },
		{ 0.3410, 0.6380, "Scarab Guardian" },
		{ 0.4260, 0.8760, "Arbhu-ra" },
		{ 0.4630, 0.9320, "Vath'ira" },
		{ 0.6380, 0.4640, "Gritstone the Patriarch" },
		{ 0.6580, 0.7190, "Clacker" },
	},
	["nchuleftingth3_base_0"] = {
		{ 0.3680, 0.2760, "Mud-Tusk" },
	},
	["nchuleftingth2_base_0"] = {
		{ 0.4680, 0.6560, "Guardian of Bthark" },
	},
	["nchuleftingth4_base_0"] = {
		{ 0.1070, 0.4870, "Renduril the Hammer" },
		{ 0.1310, 0.4560, "Friar Hadelar" },
		{ 0.4390, 0.4350, "Nilarion the Cavalier" },
	},
	["nchuleftingth5_base_0"] = {
		{ 0.4730, 0.4000, "Steamreaver" },
	},
	["nchuleftingth6_base_0"] = {
		{ 0.5040, 0.5860, "Nchulaeon the Eternal" },
	},
	["nchuthnkarst_base_0"] = {
		{ 0.1000, 0.5590, "Dwarf-light the Destroyer" },
		{ 0.3270, 0.4710, "Krodunth the Mantikora" },
		{ 0.3850, 0.1120, "Imperfect Iteration" },
		{ 0.6160, 0.2420, "Shahmar" },
		{ 0.6340, 0.4110, "Brsssp the Behemoth" },
		{ 0.7730, 0.5100, "Clockwork Criterion" },
	},
	["obsidianscar_base_0"] = {
		{ 0.2480, 0.3460, "Murgbakh Axe-Hands" },
		{ 0.2440, 0.4240, "Zozullu" },
		{ 0.3750, 0.1210, "Zilbash the Deceiver" },
		{ 0.5640, 0.8840, "Ogmash the Mighty" },
		{ 0.5790, 0.2150, "Grand Shaman Glazgor" },
		{ 0.6850, 0.7480, "Doom Witch Dekamma" },
		{ 0.6940, 0.2140, "High Overseer Kvotai" },
		{ 0.9000, 0.4260, "Bumbuk Bear-Slayer" },
	},
	["oldorsiniummap02_base_0"] = {
		{ 0.1910, 0.8240, "Great Zoraluma" },
	},
	["oldorsiniummap03_base_0"] = {
		{ 0.2470, 0.8920, "Fleshrender" },
		{ 0.3110, 0.9040, "Orzik the Storm-Born" },
		{ 0.4000, 0.8920, "Talonclaw" },
	},
	["oldorsiniummap04_base_0"] = {
		{ 0.0890, 0.5860, "Janavynn" },
		{ 0.0910, 0.4590, "Millengor" },
		{ 0.0890, 0.5210, "Wuhkusto" },
	},
	["oldorsiniummap05_base_0"] = {
		{ 0.4910, 0.2500, "Mercedene the Cursed" },
	},
	["oldorsiniummap06_base_0"] = {
		{ 0.7550, 0.5550, "Batunalulr" },
	},
	["oldorsiniummap07_base_0"] = {
		{ 0.1550, 0.6480, "Pyre Keeper Rugdrulz" },
	},
	["orcrest_base_0"] = {
		{ 0.2610, 0.7790, "Meat of the Discarded" },
		{ 0.4290, 0.4230, "The Charred Prince" },
		{ 0.5400, 0.6370, "Eludin the Cannibal King" },
		{ 0.6270, 0.4190, "Alchemist Zhininda" },
		{ 0.7790, 0.2980, "Plague of Crows" },
	},
	["orcrestsewer_base_0"] = {
		{ 0.4620, 0.4990, "Noordigloop the Clog" },
	},
	["razakswheel_base_0"] = {
		{ 0.3010, 0.4570, "Major Carina" },
		{ 0.3540, 0.5640, "Archivist Sanctius" },
		{ 0.4360, 0.4340, "Centurion Solinthia" },
		{ 0.4910, 0.4950, "Spymaster Geta" },
		{ 0.6800, 0.7890, "Mzanchndalft" },
		{ 0.7080, 0.5210, "Rkurdamz" },
		{ 0.7470, 0.6160, "Archivist Poneria" },
		{ 0.7810, 0.3580, "Razak's Behemoth" },
	},
	["rimmennecropolis_base_0"] = {
		{ 0.0960, 0.4700, "Gormandizer Blyhicius" },
		{ 0.1080, 0.6770, "Bakea the Forge Guardian" },
		{ 0.4660, 0.6320, "Champion of Mehrunnez" },
		{ 0.4730, 0.2520, "Tullar-dra" },
		{ 0.4920, 0.2430, "Jinninji-ri" },
		{ 0.5120, 0.2530, "Zebiden-jo" },
		{ 0.5160, 0.6330, "Aspect of Darloc Brae" },
		{ 0.7960, 0.4030, "Lieutenant Fazumir" },
		{ 0.9100, 0.7460, "Lieutenant Kurzatha" },
	},
	["rkindaleftint01_base_0"] = {
		{ 0.6910, 0.7910, "Sharga the Firestarter" },
	},
	["rkindaleftoutside_base_0"] = {
		{ 0.0850, 0.4760, "Wandering Illia" },
		{ 0.1160, 0.4920, "Thragdus" },
		{ 0.1150, 0.4540, "Sifgof" },
		{ 0.2020, 0.3360, "Azorrinuz" },
		{ 0.5770, 0.5360, "Rkinadhar" },
	},
	["rkindaleftint02_base_0"] = {
		{ 0.5030, 0.4820, "Resonant Centurion" },
	},
	["rkindaleftint03_base_0"] = {
		{ 0.5230, 0.4920, "Vessel of the Auditor" },
	},
	["rootsunder_base_0"] = {
		{ 0.2180, 0.5680, "Rootbiter" },
		{ 0.3200, 0.3400, "Guardian of Root Sunder" },
		{ 0.5080, 0.3400, "Thick-Bark" },
		{ 0.5900, 0.5920, "The Devil Wrathmaw" },
		{ 0.5980, 0.7600, "Great Thorn" },
		{ 0.6790, 0.1640, "The Bonemonger" },
		{ 0.7390, 0.4800, "Silent Claw" },
		{ 0.8620, 0.4510, "Rustjaw" },
	},
	["rulanyilsfall_base_0"] = {
		{ 0.1340, 0.3820, "Vree" },
		{ 0.2240, 0.5510, "Hannat the Bonebringer" },
		{ 0.3380, 0.3460, "Magna Tharn" },
		{ 0.4860, 0.8090, "Thorasa Scipio" },
		{ 0.5060, 0.4390, "Skirar the Decaying" },
		{ 0.6390, 0.4360, "Utiasl" },
		{ 0.8050, 0.3700, "Onkal the Harbinger" },
		{ 0.8460, 0.6570, "Hergor the Fallen" },
	},
	["sanguinesdemesne_base_0"] = {
		{ 0.0730, 0.5250, "Shrom" },
		{ 0.1940, 0.2480, "Fight-Master Grel" },
		{ 0.3860, 0.4360, "The Guest That Wouldn't Leave" },
		{ 0.5140, 0.1920, "Drel" },
		{ 0.4980, 0.2690, "The Bloody Judge" },
		{ 0.7880, 0.6840, "Lord Brol" },
		{ 0.8480, 0.5290, "The Fire-Eater" },
	},
	["u34_crimsoncoin_ext_base_0"] = {
		{ 0.3670, 0.6330, "The Blighted Carapace" },
		{ 0.5420, 0.3460, "Mouz the Unclean" },
		{ 0.6890, 0.7020, "Chillspine" },
		{ 0.6770, 0.2460, "Shambleback" },
		{ 0.8230, 0.4810, "Crimson Apprentice" },
	},
	["u34_tots_crypt_intt_base_0"] = {
		{ 0.5180, 0.6470, "The Crimson Mother" },
	},
	["sunhold_base_0"] = {
		{ 0.4360, 0.8010, "Shipbreaker" },
		{ 0.4470, 0.2730, "The Pyandonean Wind" },
		{ 0.4290, 0.1490, "Konugil the Leviathan" },
		{ 0.5900, 0.3730, "Captain Quergura" },
		{ 0.6490, 0.4250, "Kolondir the Demon" },
		{ 0.8100, 0.7500, "Welkadra" },
	},
	["thelionsden_base_0"] = {
		{ 0.1050, 0.8520, "Lonely Giant" },
		{ 0.3290, 0.2200, "Sergeant Themond" },
		{ 0.3930, 0.1300, "Den Mother" },
		{ 0.6660, 0.3090, "Lieutenant Derone" },
		{ 0.7140, 0.5770, "Lieutenant Stenric" },
		{ 0.6820, 0.5270, "Crazy Sebastien" },
		{ 0.7110, 0.3390, "Sergeant Lort" },
		{ 0.8300, 0.1650, "Inulu the Fierce" },
	},
	["u30_silenthalls_int01_base_0"] = {
		{ 0.2400, 0.5990, "Rootwhisperer" },
		{ 0.5470, 0.1640, "Vor'chul the Beastbreaker" },
	},
	["u30_silenthalls_int02_base_0"] = {
		{ 0.4620, 0.7450, "Dread Irenan" },
		{ 0.6200, 0.2800, "Warlord Iaza" },
	},
	["u30_silenthalls_ext01_base_0"] = {
		{ 0.3400, 0.7010, "The Silent Sentry" },
		{ 0.5960, 0.3370, "Kao'kuul" },
	},
	["u38_underweave_central_base_0"] = {
		{ 0.3750, 0.1850, "Creepclaw" },
		{ 0.4900, 0.8030, "Caz'iunes the Executioner" },
		{ 0.5940, 0.3490, "All-Seeing Ky'zuu" },
		{ 0.6714, 0.7239, "Kynreve Kev'ni" },
	},
	["u38_underweave_process02_base_0"] = {
		{ 0.3260, 0.3090, "Qacath the Silent" },
	},
	["u38_underweave_process01_base_0"] = {
		{ 0.8790, 0.7290, "Loremaster Trigon" },
	},
	["u38_underweave_heart_base_0"] = {
		{ 0.5030, 0.8200, "Kynreeve Kev'ni" },
	},
	["thevilemansefirstfloor_base_0"] = {
		{ 0.3330, 0.1180, "Venissia the Twisted" },
		{ 0.3600, 0.5470, "Marrow Thief" },
		{ 0.4730, 0.9030, "Dread Atronach" },
		{ 0.6890, 0.2780, "Pelona the Marksman" },
		{ 0.6870, 0.5030, "Sergeant Atilus" },
	},
	["thevilemansesecondfloor_base_0"] = {
		{ 0.3190, 0.3240, "Graccus" },
		{ 0.3280, 0.6050, "Primalist Orata" },
		{ 0.6450, 0.3840, "Xevat-Golok" },
	},
	["toothmaulgully_base_0"] = {
		{ 0.2540, 0.2410, "Nitch" },
		{ 0.2890, 0.4000, "Black Bessie" },
		{ 0.2790, 0.4290, "Thek Elf-Stabber" },
		{ 0.4420, 0.6350, "Togga the Skewerer" },
		{ 0.4780, 0.6520, "Bloodroot" },
		{ 0.4980, 0.7660, "Dzeizik" },
		{ 0.6030, 0.6460, "Gorg" },
		{ 0.6180, 0.6250, "Slakkith" },
	},
	["villageofthelost_base_0"] = {
		{ 0.1200, 0.4530, "Taskmaster Uldun" },
		{ 0.1870, 0.5730, "Majdi" },
		{ 0.2080, 0.6760, "Gruthaz" },
		{ 0.3360, 0.2500, "Vrendi" },
		{ 0.3300, 0.6780, "Aez the Collector" },
		{ 0.3710, 0.2360, "Zatalguch" },
		{ 0.4150, 0.6370, "Rararyn" },
		{ 0.5190, 0.4430, "Uluzzur" },
		{ 0.6720, 0.4660, "Begnar" },
		{ 0.7180, 0.3410, "Iluzan" },
		{ 0.7700, 0.5590, "Macius Cento" },
		{ 0.8530, 0.4160, "Mirok the Deplorable" },
		{ 0.8480, 0.3370, "Taskmaster Mirit" },
	},
	["zhmain_base_0"] = {
		{ 0.2140, 0.7200, "The Frigid Temptress" },
		{ 0.3470, 0.4800, "Grapnur the Crusher" },
		{ 0.3480, 0.4650, "Burthar Meatwise" },
		{ 0.3990, 0.1800, "Gloom-Tooth" },
		{ 0.5460, 0.4820, "Arbitrator Tasellis" },
		{ 0.6032, 0.7149, "Ra'back the Trap Master" },
		{ 0.7570, 0.5310, "Praeconicus" },
		{ 0.8580, 0.5420, "Fulciinius the Bone Miser" },
	},
	["zhgroupevent_base_0"] = {
		{ 0.6050, 0.5230, "Ra'back the Trap Master" },
	},
}

BossData.DelveChampionTableStore = {
	["aba-loria_base_0"] = {
		{ 0.7530, 0.6280, "Cirterisse" },
	},
	["abodeofignominy_base_0"] = {
		{ 0.1730, 0.7330, "Sugarsnout" },
		{ 0.1770, 0.7490, "Zaorir" },
	},
	["aldunz_base_0"] = {
		{ 0.7110, 0.5590, "Thinks-in-Gears" },
	},
	["archonsgrove_base_0"] = {
		{ 0.1350, 0.5860, "Den Mother Toamna" },
		{ 0.4370, 0.6150, "Seldine Second-Skin" },
	},
	["ashalmawia02_base_0"] = {
		{ 0.3650, 0.3050, "Phobbiicus" },
	},
	["atanazruins_base_0"] = {
		{ 0.5530, 0.4490, "Stormscale" },
	},
	["avancheznel_base_0"] = {
		{ 0.5200, 0.5710, "Thzallek Eft" },
	},
	["bahrahasgloom_base_0"] = {
		{ 0.6600, 0.6840, "Magnifico Bahraha" },
	},
	["barrowtrench_base_0"] = {
		{ 0.3090, 0.6040, "Overseer Basri" },
	},
	["bearclawmine_base_0"] = {
		{ 0.2850, 0.6250, "Octavia" },
	},
	["bewan_base_0"] = {
		{ 0.5610, 0.2100, "Camandar" },
	},
	["blackvineruins_base_0"] = {
		{ 0.5480, 0.2900, "Blackvine Strangler" },
	},
	["bloodmaynecave_base_0"] = {
		{ 0.1450, 0.3460, "Acanthia, Choosen of Nirn" },
		{ 0.3980, 0.4440, "Razorback" },
		{ 0.4790, 0.3820, "Ironlash" },
	},
	["breakneckcave_base_0"] = {
		{ 0.2750, 0.2990, "Hegris the Black Dagger" },
		{ 0.2770, 0.5800, "Longfang" },
	},
	["brokenhelm_base_0"] = {
		{ 0.5630, 0.7060, "Skullcrusher" },
	},
	["brokentuskcave_base_0"] = {
		{ 0.3440, 0.2720, "Naeraizozan" },
	},
	["burrootkwamamine_base_0"] = {
		{ 0.7970, 0.4970, "Stormhead the Ravenous" },
	},
	["capstonecave_base_0"] = {
		{ 0.7150, 0.1680, "Claudette the Sharper" },
	},
	["caracdena_base_0"] = {
		{ 0.5650, 0.6290, "Urrumaz the Terrifying" },
	},
	["caveoftrophies_base_0"] = {
		{ 0.5610, 0.3700, "Gnilokelo" },
	},
	["chidmoskaruins_base_0"] = {
		{ 0.6820, 0.3820, "Lirlane" },
	},
	["clawsstrike_base_0"] = {
		{ 0.8390, 0.7060, "Lord Tawnlii-do" },
		{ 0.8780, 0.6910, "Fishbreath" },
	},
	["coldperchcavern_base_0"] = {
		{ 0.7530, 0.4900, "Kraala Birdsong" },
	},
	["coldrockdiggings_base_0"] = {
		{ 0.2150, 0.8200, "Feremuzh" },
	},
	["corpsegarden_base_0"] = {
		{ 0.2600, 0.4210, "General Celdien" },
	},
	["crackedwoodcave_base_0"] = {
		{ 0.3330, 0.0820, "Regsrot Blacktongue" },
		{ 0.3390, 0.3530, "Traug Wolfbreath" },
		{ 0.7110, 0.3660, "Mebs Runnyeye" },
	},
	["molavar_base_0"] = {
		{ 0.1380, 0.7560, "The Charnel Cage" },
		{ 0.4760, 0.3670, "Thalie the Voracious" },
		{ 0.5260, 0.9230, "Magdra Ibrai" },
	},
	["moonlitcove01_base_0"] = {
		{ 0.4100, 0.4040, "The Tigershark" },
	},
	["rkundzelft_base_0"] = {
		{ 0.4860, 0.3760, "Mzeklok" },
	},
	["kardala_base_0"] = {
		{ 0.1390, 0.5510, "Mazar the Vengeful" },
		{ 0.1800, 0.2120, "Izrunath the Corruptor" },
		{ 0.1860, 0.8520, "Ahmat the Forgotten" },
		{ 0.6260, 0.3330, "Satagna" },
		{ 0.7820, 0.4820, "Rajdara the Restless One" },
	},
	["haddock_base_0"] = {
		{ 0.6930, 0.4840, "Grandmother Thunder" },
		{ 0.7360, 0.3330, "Ariana At-Fara" },
	},
	["chiselshriek_base_0"] = {
		{ 0.6800, 0.2380, "The Gracious Beacon" },
	},
	["burriedsands_base_0"] = {
		{ 0.2300, 0.3800, "The Swarming Tide" },
		{ 0.6950, 0.2860, "Den Mother" },
	},
	["mtharnaz_base_0"] = {
		{ 0.1740, 0.6350, "The Skillful Seamstress" },
		{ 0.3840, 0.5290, "The Brass Hatchling" },
	},
	["balamath_base_0"] = {
		{ 0.4050, 0.5980, "Corrupted Scion of Balamath" },
		{ 0.7370, 0.2210, "Storm Mage Iribia" },
		{ 0.7830, 0.2420, "Fire Mage Linia" },
		{ 0.8300, 0.2230, "Frost Mage Porcia" },
	},
	["thaliasretreat_base_0"] = {
		{ 0.2680, 0.1450, "Zalgaz" },
		{ 0.2700, 0.1710, "Zalgaz's Handmaiden" },
		{ 0.2930, 0.1330, "Zalgaz's Handmaiden" },
	},
	["cryptoftarishzizone_base_0"] = {
		{ 0.2410, 0.4900, "The Glorious Coil" },
		{ 0.2520, 0.4870, "The Fumbled Knife" },
		{ 0.2520, 0.4980, "The Craven Shield" },
		{ 0.2520, 0.5090, "The Servile Staff" },
		{ 0.4290, 0.5870, "Namsah the Fallen" },
		{ 0.4660, 0.3630, "Prince Tarjal the Lost" },
		{ 0.5600, 0.6590, "The Hungry Pillar" },
	},
	["hircineshaunt_base_0"] = {
		{ 0.2190, 0.7760, "Packleader Sigmund" },
		{ 0.4430, 0.1810, "Iron Head" },
	},
	["serpentsnest_base_0"] = {
		{ 0.3620, 0.7810, "Hruzizolk the Progenitor Mantikora" },
		{ 0.4780, 0.2250, "Aurieae" },
		{ 0.4960, 0.1950, "Laurieae" },
		{ 0.5090, 0.2270, "Taurieae" },
	},
	["ilthagsundertower_base_0"] = {
		{ 0.1580, 0.4840, "Rahk" },
		{ 0.1560, 0.4410, "Vosh" },
	},
	["lothna_base_0"] = {
		{ 0.6000, 0.2750, "Visskar" },
	},
	["fearfang_base_0"] = {
		{ 0.1900, 0.5900, "Fearfang Cavern" },
		{ 0.5720, 0.4730, "Sepilisk" },
	},
	["exarchsstronghold_base_0"] = {
		{ 0.1450, 0.1990, "Exarch Braadoth" },
		{ 0.1770, 0.1970, "Kurzoth" },
		{ 0.4160, 0.8480, "Ordooth the Corruptor" },
		{ 0.5050, 0.6200, "Agganor" },
		{ 0.5130, 0.0790, "Grothuska" },
	},
	["crestshademine_base_0"] = {
		{ 0.4450, 0.4700, "Grimtooth" },
	},
	["cryptoftheexiles_base_0"] = {
		{ 0.1650, 0.5790, "Ulbazar Thief-Lord" },
	},
	["cryptwatchfort_base_0"] = {
		{ 0.4710, 0.8130, "Valenwe" },
	},
	["deadmansdrop_base_0"] = {
		{ 0.3740, 0.7280, "Captain Shammin" },
	},
	["delsclaim_base_0"] = {
		{ 0.7940, 0.1790, "Polinus" },
	},
	["depravedgrotto_base_0"] = {
		{ 0.7250, 0.5760, "Nerazakan" },
	},
	["desertwind2a_base_0"] = {
		{ 0.5490, 0.1930, "Tasam-ri" },
		{ 0.5430, 0.1410, "Augurius the Mad" },
	},
	["desolatecave_base_0"] = {
		{ 0.7930, 0.3790, "Drulshasa" },
	},
	["dessicatedcave_base_0"] = {
		{ 0.3590, 0.2550, "Spider Queen" },
	},
	["divadschagrinmine_base_0"] = {
		{ 0.7420, 0.5590, "Nokhailaedhaz" },
	},
	["eboncrypt_base_0"] = {
		{ 0.6640, 0.4880, "The Ebon Lord" },
	},
	["ebonmeretower_base_0"] = {
		{ 0.5230, 0.8630, "Rozelun" },
	},
	["echocave_base_0"] = {
		{ 0.2750, 0.1840, "Sargos Grent" },
	},
	["emberflintmine_base_0"] = {
		{ 0.4190, 0.6760, "Maebomaz" },
	},
	["enduum_base_0"] = {
		{ 0.6990, 0.0890, "Odilon" },
	},
	["entilasfolly_base_0"] = {
		{ 0.1740, 0.4330, "Bakhig" },
	},
	["erokii_base_0"] = {
		{ 0.6750, 0.7040, "Miruin Woodwalker" },
		{ 0.7070, 0.6710, "Abal-jo" },
		{ 0.7070, 0.7380, "Earelcar" },
	},
	["etonnir_01_base_0"] = {
		{ 0.1390, 0.7810, "Kayliriax the Spinner" },
		{ 0.4040, 0.3280, "Webmistress Xoraxia" },
	},
	["fardirsfolly_base_0"] = {
		{ 0.7700, 0.1760, "Ravo Peltrasius" },
	},
	["farangelsdelve_base_0"] = {
		{ 0.2770, 0.4930, "Dimitri" },
	},
	["flyleafcatacombs_base_0"] = {
		{ 0.6780, 0.1970, "Miremonwe Spellslinger" },
	},
	["fortgreenwall_base_0"] = {
		{ 0.6740, 0.8250, "Uggurek the Vile" },
	},
	["gandranen_base_0"] = {
		{ 0.7550, 0.6070, "Fenlord" },
	},
	["garlasagea_base_0"] = {
		{ 0.5100, 0.1030, "Captain Jena Apinia" },
		{ 0.6110, 0.4270, "Ironfang" },
	},
	["gurzagsmine_base_0"] = {
		{ 0.7460, 0.4690, "Retribution" },
	},
	["hallsofregulation_base_0"] = {
		{ 0.7320, 0.4000, "The Steadfast Regulator" },
	},
	["harridanslair_base_0"] = {
		{ 0.2210, 0.7540, "Razorclaw" },
	},
	["haynotecave_base_0"] = {
		{ 0.3150, 0.4780, "Theurgist Thelas" },
		{ 0.5590, 0.1890, "Diabolist  Volcatia" },
	},
	["hightidehollow_base_0"] = {
		{ 0.4700, 0.2790, "Oodegu" },
	},
	["hildunessecretrefuge_base_0"] = {
		{ 0.8520, 0.2890, "Leidmir Corpse-Caller" },
	},
	["hoarvorpit_base_0"] = {
		{ 0.6770, 0.4510, "Oghezai" },
	},
	["houseofembersoutside_base_0"] = {
		{ 0.4850, 0.2720, "Commandant Weston" },
	},
	["hrotacave_base_0"] = {
		{ 0.2520, 0.1460, "Lecalus" },
		{ 0.3180, 0.8020, "Malinanta" },
		{ 0.8520, 0.7770, "Exulus" },
	},
	["icehammersvault_base_0"] = {
		{ 0.4770, 0.4790, "Thane Icehammer" },
	},
	["ilessantower_base_0"] = {
		{ 0.4280, 0.4930, "Gaetane" },
	},
	["innerseaarmature_base_0"] = {
		{ 0.2550, 0.8310, "Zozuzetharus" },
	},
	["jaggerjaw_base_0"] = {
		{ 0.4690, 0.1130, "Klathzgar's Centurion" },
		{ 0.8040, 0.6130, "Urenenya's Soul" },
	},
	["jodeslight_base_0"] = {
		{ 0.5310, 0.6000, "Yenadar" },
	},
	["khartagpoint_base_0"] = {
		{ 0.5210, 0.5730, "Avrusa Duleri" },
		{ 0.7790, 0.2030, "Old Rust-Eye" },
	},
	["kennelrun_base_0"] = {
		{ 0.4190, 0.3450, "Nikolvara the Durzog Trainer" },
	},
	["kingscrest_base_0"] = {
		{ 0.8490, 0.5050, "Cynaceae the Verdant" },
	},
	["kingshavenext_base_0"] = {
		{ 0.1520, 0.4020, "Avuuma the Whirlwind" },
	},
	["kingshavenint1_base_0"] = {
		{ 0.8170, 0.5020, "Keetas the Weaver" },
	},
	["koeglinmine_base_0"] = {
		{ 0.4540, 0.3370, "Girara" },
	},
	["kunasdelve_base_0"] = {
		{ 0.1810, 0.3090, "Limbrender" },
	},
	["kwamacolony_base_0"] = {
		{ 0.5150, 0.7620, "Lady Llarel" },
	},
	["lipsandtarn_base_0"] = {
		{ 0.2580, 0.5870, "Marbita" },
		{ 0.4010, 0.1760, "Gaston Ashham" },
	},
	["lowerbthanuel_base_0"] = {
		{ 0.5360, 0.4370, "Bthanual Centurion" },
	},
	["malsorrastomb_base_0"] = {
		{ 0.7850, 0.3500, "Mal Sorra" },
	},
	["matusakin_base_0"] = {
		{ 0.5170, 0.5860, "Th'krak the Tunnel-King" },
	},
	["mehrunesspite_base_0"] = {
		{ 0.2890, 0.4010, "Mati" },
	},
	["mephalasnest_base_0"] = {
		{ 0.1140, 0.4940, "Gozzak" },
	},
	["minesofkhuras_base_0"] = {
		{ 0.3220, 0.2200, "Lilou" },
	},
	["mobarmine_base_0"] = {
		{ 0.0940, 0.6200, "Sgolag" },
	},
	["muckvalleycavern_base_0"] = {
		{ 0.1860, 0.6810, "Kerks Half-Ear" },
		{ 0.3750, 0.8880, "Webmistress" },
		{ 0.7830, 0.1480, "Ogre Biter" },
	},
	["murciensclaim_base_0"] = {
		{ 0.6300, 0.3710, "Lorogdu gra-Gulash" },
	},
	["narilnagaia_base_0"] = {
		{ 0.7470, 0.6120, "Archmage Camaano" },
	},
	["nesalas_base_0"] = {
		{ 0.6600, 0.7210, "Lieutenant Khari" },
	},
	["newtcave_base_0"] = {
		{ 0.1430, 0.3120, "Gravel Tooth" },
		{ 0.6060, 0.7170, "Rock Wing" },
	},
	["nisincave_base_0"] = {
		{ 0.1210, 0.6450, "Barasatii" },
		{ 0.6090, 0.5940, "Volgo the Harrower" },
	},
	["norvulkruins_base_0"] = {
		{ 0.5840, 0.6780, "Nariam" },
	},
	["ondil_base_0"] = {
		{ 0.4960, 0.2680, "Aluvus" },
	},
	["onkobrakwamamine_base_0"] = {
		{ 0.6330, 0.5560, "Kwama Overseer" },
	},
	["orcsfingerruins_base_0"] = {
		{ 0.7670, 0.7650, "Fingaenion Forestsmasher" },
	},
	["pariahcatacombs_base_0"] = {
		{ 0.2900, 0.2150, "Uncle Bones" },
	},
	["portdunwatch_base_0"] = {
		{ 0.6050, 0.4280, "Ariane" },
		{ 0.6100, 0.4560, "Birakh-do" },
	},
	["potholecavern_base_0"] = {
		{ 0.5340, 0.1380, "Blighttooth" },
		{ 0.6050, 0.6960, "Diabolist Vethisa" },
		{ 0.6130, 0.4600, "Serrin Vol" },
	},
	["predatorrise_base_0"] = {
		{ 0.2690, 0.3240, "Kuzo the Thunderclaw" },
		{ 0.5680, 0.4320, "Zahalar Oak-Eye" },
		{ 0.7060, 0.6850, "Quillmane" },
		{ 0.8070, 0.3680, "Split-Ear Tahuda" },
	},
	["pulklower_base_0"] = {
		{ 0.7860, 0.4780, "Bralsa Inlador" },
	},
	["quickwatercave_base_0"] = {
		{ 0.4010, 0.9140, "Athal Andas" },
	},
	["quickwaterdepths_base_0"] = {
		{ 0.1880, 0.4560, "Steel-Tail" },
	},
	["redrubycave_base_0"] = {
		{ 0.3850, 0.2150, "Endare" },
		{ 0.7730, 0.2630, "Zandur" },
	},
	["rootsofsilvenar_base_0"] = {
		{ 0.8550, 0.5650, "Adavos Dren" },
	},
	["rubblebutte_base_0"] = {
		{ 0.6160, 0.4640, "Lady Edwyge" },
	},
	["sandblownmine_base_0"] = {
		{ 0.9190, 0.6780, "Mirudda" },
	},
	["santaki_base_0"] = {
		{ 0.3490, 0.2080, "Tarrent Herano" },
	},
	["serpenthollowcave_base_0"] = {
		{ 0.2190, 0.5780, "Bruuke" },
		{ 0.4310, 0.3040, "Bear Matriarch" },
	},
	["shadowcleft_base_0"] = {
		{ 0.3610, 0.2160, "Night Sister Kamira" },
	},
	["shaelruins_base_0"] = {
		{ 0.7500, 0.7100, "Arrai" },
	},
	["sharktoothgrotto2_base_0"] = {
		{ 0.1670, 0.6220, "First Mate Rodros" },
		{ 0.1930, 0.5850, "Korna Keeba" },
	},
	["sheogorathstongue_base_0"] = {
		{ 0.2140, 0.6240, "Calls-to-Nature" },
		{ 0.2010, 0.5970, "Dezanu" },
	},
	["shrineofblackworm_base_0"] = {
		{ 0.6320, 0.7100, "Peers-Through-Glass" },
	},
	["shroudhearth_base_0"] = {
		{ 0.6000, 0.5230, "Jakalor" },
	},
	["silumm_base_0"] = {
		{ 0.8240, 0.4750, "Sincano" },
	},
	["snaplegcave_base_0"] = {
		{ 0.5030, 0.3740, "Frostmaiden Apa" },
	},
	["softloamcavern_base_0"] = {
		{ 0.6830, 0.6580, "Dugrul" },
	},
	["stormcragcrypt_base_0"] = {
		{ 0.7960, 0.1310, "Deathknight Stormcrag" },
	},
	["teethofsithis02b_base_0"] = {
		{ 0.5380, 0.6850, "Shuxaltsei" },
	},
	["thebastardstomb_base_0"] = {
		{ 0.7890, 0.7540, "Agnenor the Blade" },
	},
	["thechillhollow_base_0"] = {
		{ 0.6840, 0.4180, "Nomeg Chal" },
	},
	["thetangle_base_0"] = {
		{ 0.4540, 0.6260, "Zayreba Sharpclaw" },
	},
	["theunderroot_base_0"] = {
		{ 0.3050, 0.2840, "Domina Ssaranth" },
	},
	["thefrigidgrotto_base_0"] = {
		{ 0.7120, 0.3010, "Frostbite Mangler" },
	},
	["thescab_base_0"] = {
		{ 0.4540, 0.1810, "Iron Heart Atronach" },
		{ 0.4850, 0.2140, "Zadrahd the Iron Hearted" },
	},
	["thibautscairn_base_0"] = {
		{ 0.2210, 0.1800, "Worm Eremite" },
	},
	["thukozods_base_0"] = {
		{ 0.7810, 0.7370, "Gorlar the Dark" },
	},
	["toadstoolhollow_base_0"] = {
		{ 0.2450, 0.2870, "Dreadfang" },
	},
	["toadstoolhollowlower_base_0"] = {
		{ 0.0860, 0.5280, "Lucienne Cerine" },
		{ 0.2860, 0.5290, "Captain Roreles" },
		{ 0.3070, 0.3460, "General Virane" },
		{ 0.3080, 0.7530, "Captain Serniel" },
	},
	["tomboftheapostates_base_0"] = {
		{ 0.6170, 0.5870, "Gwaeregil" },
	},
	["tombofserpents_base_0"] = {
		{ 0.5040, 0.4630, "Gornikaus Oxtooth" },
	},
	["torhamekhard_01_base_0"] = {
		{ 0.2850, 0.4500, "Justiciar Avanaire" },
		{ 0.6360, 0.2330, "The Kurgando" },
	},
	["traitorsvault01_base_0"] = {
		{ 0.1330, 0.7420, "Vessel of Worms" },
		{ 0.7170, 0.7700, "The First Flesh Colossus" },
	},
	["tribulationcrypt_base_0"] = {
		{ 0.6780, 0.1990, "Alameric Daillon" },
	},
	["triplecirclemine_base_0"] = {
		{ 0.5760, 0.3130, "Bonetooth" },
	},
	["trollstoothpick_base_0"] = {
		{ 0.5800, 0.5550, "Pale Squnque" },
	},
	["underpallcave_base_0"] = {
		{ 0.3010, 0.1740, "Raelynne Ashham" },
		{ 0.7010, 0.5760, "Emelin the Returned" },
	},
	["unexploredcrag_base_0"] = {
		{ 0.4600, 0.5390, "Egg-Eater" },
	},
	["vahtacen_base_0"] = {
		{ 0.1450, 0.6520, "The Faceless" },
	},
	["vaultofhamanforgefire_base_0"] = {
		{ 0.6770, 0.6690, "Haman Forgefire" },
	},
	["vindeathcave_base_0"] = {
		{ 0.3150, 0.7730, "Madruin" },
	},
	["viridianwatch_base_0"] = {
		{ 0.7240, 0.4760, "Curnard the Generous" },
	},
	["wailingmaw_base_0"] = {
		{ 0.6340, 0.3540, "Marwoleath" },
	},
	["wansalen_base_0"] = {
		{ 0.3670, 0.8650, "Nolonir" },
	},
	["watchershold_base_0"] = {
		{ 0.6330, 0.2380, "Sir Marq Tailas" },
	},
	["weepingwindcave_base_0"] = {
		{ 0.6430, 0.2980, "Nimriian" },
	},
	["wormrootdepths_base_0"] = {
		{ 0.6820, 0.4050, "Raynia" },
	},
	["yldzuun_base_0"] = {
		{ 0.7710, 0.7770, "Captain Candidus" },
	},
	["zainsipilu_base_0"] = {
		{ 0.1490, 0.7910, "Zvvius the Hive Lord" },
	},
	["zthenganaz_base_0"] = {
		{ 0.8150, 0.3270, "Ztheng Guardian" },
	},
	["chillwinddepths_base_0"] = {
		{ 0.4310, 0.1850, "Mother Krkktkk" },
		{ 0.4600, 0.2160, "Zrem-Zram" },
	},
	["dragonhome_base_0"] = {
		{ 0.3460, 0.2920, "Aspirant Yolstagg" },
	},
	["frozencoast_base_0"] = {
		{ 0.7220, 0.1910, "Chief Gruthar" },
	},
	["midnightbarrow_base_0"] = {
		{ 0.6370, 0.1250, "Delida the Damned" },
	},
	["shadowgreen_lower_base_0"] = {
		{ 0.3590, 0.4840, "Ya'intha" },
	},
	["thescraps_base_0"] = {
		{ 0.2840, 0.5990, "Dwarven Spider" },
	},
	["briarrockruins_ext_base_0"] = {
		{ 0.1300, 0.5710, "Matron Grygarsnit" },
	},
	["u30_undertowcavern_base_0"] = {
		{ 0.4980, 0.1650, "Druvaakh the Smasher" },
	},
	["u30_xanmeeroverlook_ext_base_0"] = {
		{ 0.5150, 0.4590, "Raj-Kaal Ioraxeek" },
	},
	["vaultdelve_int03_base_0"] = {
		{ 0.3420, 0.6480, "Karzikon the Razorsworn" },
	},
	["u30_bloodruncave_base_0"] = {
		{ 0.2900, 0.6370, "Tumma-Maxath" },
	},
	["vunalk2_base_0"] = {
		{ 0.2870, 0.4190, "Choking Vine" },
	},
	["u32_folly_delve_base_0"] = {
		{ 0.5480, 0.4420, "Kurkron the Mangler" },
	},
	["u32_dreaded_refuge_ext_base_0"] = {
		{ 0.2900, 0.1490, "Infernium" },
	},
	["u34_firepotcave_base_0"] = {
		{ 0.6520, 0.4780, "Esh'curnu the Behemoth" },
	},
	["u34_breakwatercave_base_0"] = {
		{ 0.1190, 0.6620, "Brineclaw" },
	},
	["u34_hauntedsepulcherint_base_0"] = {
		{ 0.3520, 0.4690, "Lord Leobert" },
	},
	["u34_shipwreckshoalsint_base_0"] = {
		{ 0.2920, 0.8240, "Captain Ithala" },
	},
	["u34_whalefall_cay_base_0"] = {
		{ 0.4590, 0.4950, "Hunter Crow" },
		{ 0.3860, 0.2840, "Jailer Mannick" },
		{ 0.5080, 0.5000, "Hunter Lucia" },
		{ 0.5250, 0.6180, "Hunter Cam" },
		{ 0.0562, 0.0519, "Hunter Guildner" },
		{ 0.5970, 0.4370, "Hunter Dee" },
		{ 0.6470, 0.5780, "Hunter Marcus" },
	},
	["u34_coralcliffsext_base_0"] = {
		{ 0.5660, 0.7230, "Madena Bracques" },
	},
	["u36_embervine_base_0"] = {
		{ 0.2320, 0.3060, "Traux the Ancient" },
		{ 0.2810, 0.2710, "Druid Rerlas" },
	},
	["u36_lkh_base_0"] = {
		{ 0.5840, 0.5270, "Bahltur" },
	},
	["u38_camonnaruhn_base_0"] = {
		{ 0.5960, 0.2060, "Matron Chruchak" },
	},
	["u38_eggmine_base_0"] = {
		{ 0.5110, 0.4730, "Zaedare the Afflicted" },
	},
	["u38_quires_wind_base_0"] = {
		{ 0.2490, 0.7250, "Cipher Gelon" },
	},
	["u38_disquiet_study_base_0"] = {
		{ 0.4360, 0.6350, "Uzur the All-Seeing" },
	},
	["u38_apogee_wind_base_0"] = {
		{ 0.5480, 0.7990, "The Supernal Trespasser" },
	},
	["u38_corpusclebight_01_base_0"] = {
		{ 0.5000, 0.1250, "The Lightkeeper" },
	},
	["u42_windcave_base_0"] = {
		{ 0.3700, 0.4980, "Gilroy Vassinus" },
		{ 0.6343, 0.3038, "Commander Hanhael" },
	},
	["u48_delve_sithis_crest_01_base_0"] = {
		{ 0.0810, 0.3090, "Whisper of the Sacred Stones" },
	},
	["u48_ssl_delve_base_1_base_0"] = {
		{ 0.5160, 0.4670, "Lector Fenworine" },
	},
	["u46_base_sanguinehdlv_base_0"] = { { 0.567, 0.638, "The Wine Sommelier" } },
	["u46_base_lostvillage_base_0"] = { { 0.869, 0.313, "Nardirin Death-Hand" } },
	["u46_carapacecaverns_base_0"] = { { 0.345, 0.528, "Headcracker" } },
	["u46_base_lotwc_room_base_0"] = {    { 0.546, 0.554, "Riuzzan The Ravenous" },},
	["u46_base_lotwc_0"] = { { 0.546, 0.554, "Riuzzan The Ravenous" },},
	["u48_delve_sithis_crest_01_base_0"] = {    { 0.061, 0.232, "Whisper of the Sacred Stones" },},
	["u48_ssl_delve_base_1_base_0"] = {    { 0.387, 0.350, "Lector Fenworine" },},
}

BossData.GroupChampionTableStore = {
	["fungalgrotto_base_0"] = {
		{ 0.3700, 0.4290, "Kra'gh the Dreugh King" },
		{ 0.3890, 0.2450, "Bloodbirther" },
		{ 0.4880, 0.4340, "Clatterclaw" },
		{ 0.6400, 0.8480, "Tazkad the Packmaster" },
		{ 0.7840, 0.6070, "War Chief Ozozai" },
	},
	["fungalgrottosecretroom_base_0"] = {
		{ 0.0720, 0.5160, "Reggr Dark-Dawn" },
		{ 0.3630, 0.4430, "Spawn of Mephala" },
		{ 0.3900, 0.7370, "Vila Theran" },
		{ 0.3910, 0.2410, "Ciirenas the Shepherd" },
		{ 0.6270, 0.8420, "Mephala's Fang" },
		{ 0.7960, 0.6160, "Gamyne Bandu" },
	},
	["spindleclutch_base_0"] = {
		{ 0.2760, 0.3150, "Spindlekin" },
		{ 0.3660, 0.8610, "The Whisperer" },
		{ 0.5780, 0.5350, "Big Rabbu" },
		{ 0.6850, 0.5380, "Cerise the Widow-Maker" },
		{ 0.7150, 0.2380, "Swarm Mother" },
	},
	["spindleclutchheroic_base_0"] = {
		{ 0.3190, 0.3290, "Mad Mortine" },
		{ 0.3740, 0.8550, "Urvan Veleth" },
		{ 0.6450, 0.2290, "Blood Spawn" },
		{ 0.6590, 0.5000, "Flesh Atronach Trio" },
		{ 0.7590, 0.8640, "Vorenor Winterbourne" },
		{ 0.8320, 0.3990, "Praxin Douare" },
	},
	["thebanishedcells_base_0"] = {
		{ 0.2570, 0.4360, "High Kinlord Rilis" },
		{ 0.3890, 0.6540, "Angata the Clannfear Handler" },
		{ 0.4580, 0.1280, "Skeletal Destroyer" },
		{ 0.6310, 0.5030, "Shadowrend" },
		{ 0.8260, 0.7510, "Cell Haunter" },
	},
	["darkshadecaverns_base_0"] = {
		{ 0.4340, 0.6040, "Cutting Sphere" },
		{ 0.5070, 0.6670, "Cavern Patriarch" },
		{ 0.5150, 0.1540, "Head Shepherd Neloren" },
		{ 0.5330, 0.8680, "Sentinel of Rkugamz" },
		{ 0.6890, 0.2690, "Foreman Llothan" },
		{ 0.7020, 0.7200, "The Hive Lord" },
	},
	["darkshadecavernsheroic_base_0"] = {
		{ 0.4640, 0.5810, "The Engine Guardian" },
	},
	["eldenhollow_base_0"] = {
		{ 0.1330, 0.5380, "Justicar Elanar" },
		{ 0.4910, 0.3020, "Canonreeve Oraneth" },
		{ 0.6550, 0.4300, "Nenesh gro-Mal" },
		{ 0.7150, 0.2940, "Leafseether" },
		{ 0.7310, 0.7680, "Ancient Spriggan" },
		{ 0.7880, 0.6170, "Akash gra-Mal" },
		{ 0.9000, 0.5180, "Chokethorn" },
	},
	["eldenhollowheroic1_base_0"] = {
		{ 0.2320, 0.2550, "Murklight" },
		{ 0.4710, 0.3040, "The Shadow Guard" },
		{ 0.4900, 0.8500, "Bogdan the Nightflame" },
		{ 0.7420, 0.6410, "Dubroze the Infester" },
		{ 0.7810, 0.6130, "Dark Root" },
		{ 0.9010, 0.5180, "Azara the Frightener" },
	},
	["wayrestsewers_base_0"] = {
		{ 0.2430, 0.1690, "The Rat Whisperer" },
		{ 0.4080, 0.4480, "Investigator Garron" },
		{ 0.4100, 0.7210, "Slimecraw" },
		{ 0.5220, 0.2790, "Uulgarg the Hungry" },
		{ 0.6560, 0.2250, "Varaine Pellingare" },
		{ 0.6910, 0.6520, "Allene Pellingare" },
	},
	["arxcorinium_base_0"] = {
		{ 0.1370, 0.3300, "Sellistrix the Lamia Queen" },
		{ 0.2670, 0.7660, "Sliklenia the Songstress" },
		{ 0.3360, 0.5320, "Ancient Lurcher" },
		{ 0.4920, 0.6920, "Matron Ixniaa" },
		{ 0.5200, 0.5610, "Fanged Menace" },
		{ 0.7950, 0.5910, "Ganakton the Tempest" },
	},
	["cityofashmain_base_0"] = {
		{ 0.1760, 0.6390, "Golor the Banekin Handler" },
		{ 0.2980, 0.5810, "Warden of the Shrine" },
		{ 0.4480, 0.2070, "Infernal Guardian" },
		{ 0.4750, 0.4650, "Dark Ember" },
		{ 0.5480, 0.5310, "Rothariel Flameheart" },
		{ 0.7300, 0.6910, "Razor Master Erthas" },
	},
	["vetcirtyash01_base_0"] = {
		{ 0.7360, 0.6520, "Rukhan" },
	},
	["vetcirtyash02_base_0"] = {
		{ 0.1890, 0.7470, "Horvantud the Fire Maw" },
		{ 0.4870, 0.3940, "Urata the Legion" },
	},
	["vetcirtyash03_base_0"] = {
		{ 0.4060, 0.3530, "Ash Titan" },
	},
	["vetcirtyash04_base_0"] = {
		{ 0.2440, 0.5650, "Xivilai Boltaic" },
		{ 0.3510, 0.7150, "Valkyn Skoria" },
		{ 0.4530, 0.5620, "Xivilai Fulminator" },
	},
	["cryptofhearts_base_0"] = {
		{ 0.2400, 0.2960, "The Mage Master" },
		{ 0.4980, 0.2060, "Archmaster Siniel" },
		{ 0.5070, 0.8700, "Ilambris-Athor" },
		{ 0.5280, 0.7530, "Dogas the Berserker" },
		{ 0.5310, 0.3820, "Death's Leviathan" },
		{ 0.5390, 0.8710, "Ilambris-Zaven" },
		{ 0.7700, 0.5970, "Uulkar Bonehand" },
	},
	["cryptofheartsheroic_base_0"] = {
		{ 0.1590, 0.2870, "Ibelgast" },
		{ 0.4210, 0.2020, "Ruzozuzalpamaz" },
		{ 0.4410, 0.8670, "Mezeluth" },
		{ 0.4630, 0.3860, "Ilambris Amalgam" },
		{ 0.8180, 0.1660, "Chamber Guardian" },
	},
	["cryptofheartsheroicboss_base_0"] = {
		{ 0.5090, 0.7640, "Nerien'eth" },
	},
	["direfrostkeep_base_0"] = {
		{ 0.2600, 0.3910, "Drodda's Dreadlord" },
		{ 0.5410, 0.7650, "Teethnasher the Frostbound" },
		{ 0.5890, 0.1710, "Iceheart" },
		{ 0.6740, 0.4620, "Guardian of the Flame" },
		{ 0.7490, 0.4890, "Drodda's Apprentice" },
	},
	["direfrostkeepsummit_base_0"] = {
		{ 0.4920, 0.5370, "Drodda of Icereach" },
	},
	["tempestisland_base_0"] = {
		{ 0.3840, 0.4260, "Valaran Stormcaller" },
		{ 0.6240, 0.5000, "Stormreeve Neidir" },
		{ 0.8320, 0.3610, "Stormfist" },
	},
	["tempestislandncave_base_0"] = {
		{ 0.6360, 0.6190, "Yalorasse the Speaker" },
	},
	["tempestislandsecave_base_0"] = {
		{ 0.3240, 0.4990, "Commodore Ohmanil" },
	},
	["tempestislandswcave_base_0"] = {
		{ 0.5140, 0.2430, "Sonolia the Matriarch" },
	},
	["volenfell_base_0"] = {
		{ 0.1390, 0.6420, "Desert Lion" },
		{ 0.2770, 0.4970, "Quintus Verres" },
		{ 0.2349, 0.3726, "Monstrous Gargoyle" },
		{ 0.7380, 0.6240, "Tremorscale" },
	},
	["volenfell_pledge_base_0"] = {
		{ 0.5100, 0.3480, "Boilbite" },
	},
	["eyeschamber_base_0"] = {
		{ 0.3830, 0.3760, "The Guardian's Soul" },
		{ 0.4950, 0.3960, "The Guardian's Spark" },
		{ 0.4960, 0.3630, "Guardian Trinity" },
		{ 0.6130, 0.3300, "The Guardian's Strength" },
	},
	["the_guardians_skull_base_0"] = {
		{ 0.3950, 0.1780, "Unstable Construct" },
	},
	["blackhearthavenarea1_base_0"] = {
		{ 0.8010, 0.5560, "Iron-Heel" },
	},
	["blackhearthavenarea2_base_0"] = {
		{ 0.6460, 0.2820, "Atarus" },
	},
	["blackhearthavenarea3_base_0"] = {
		{ 0.4900, 0.7110, "First Mate Wavecutter" },
		{ 0.5290, 0.4020, "Roost Mother" },
		{ 0.5310, 0.0890, "Hollow Heart" },
	},
	["blackhearthavenarea4_base_0"] = {
		{ 0.6200, 0.5960, "Captain Blackheart" },
	},
	["blessedcrucible1_base_0"] = {
		{ 0.4940, 0.3450, "Grunt the Clever" },
		{ 0.5140, 0.8590, "Teranya the Faceless" },
		{ 0.5700, 0.5000, "The Pack" },
	},
	["blessedcrucible4_base_0"] = {
		{ 0.2420, 0.2160, "The Beast Master" },
		{ 0.3830, 0.4650, "Captain Thoran" },
		{ 0.4980, 0.6300, "The Lava Queen" },
	},
	["selenesweb_base_0"] = {
		{ 0.2400, 0.1270, "Selene" },
		{ 0.2700, 0.3460, "Longclaw" },
		{ 0.4800, 0.3780, "Mennir Many-Legs" },
		{ 0.4900, 0.6630, "Treethane Kerninn" },
		{ 0.4900, 0.3780, "Queen Aklayah" },
		{ 0.7050, 0.4410, "Foulhide" },
	},
	["vaultsofmadness1_base_0"] = {
		{ 0.2300, 0.2960, "Death's Head" },
		{ 0.2680, 0.5550, "Ulguna Soul-Reaver" },
		{ 0.2690, 0.6350, "The Cursed One" },
		{ 0.4150, 0.2090, "Grothdarr" },
		{ 0.6320, 0.1380, "Achaeraizur" },
		{ 0.6860, 0.4380, "The Ancient One" },
		{ 0.6900, 0.5220, "Iskra the Omen" },
		{ 0.9380, 0.8160, "Mad Architect" },
	},
	["balsunn_b1_map_base_0"] = {
		{ 0.5170, 0.2630, "Kovan Giryon" },
	},
	["balsunn_pasttown01_map_base_0"] = {
		{ 0.3760, 0.7240, "Urvel Drath" },
	},
	["balsunn_b2_map_base_0"] = {
		{ 0.6540, 0.4930, "Roksa the Warped" },
	},
	["balsunn_b3_map_base_0"] = {
		{ 0.4880, 0.3890, "Matriarch Lladi Telvanni" },
	},
	["u41_bv_sc1_map_base_0"] = {
		{ 0.7230, 0.6290, "Shattered Champion" },
	},
	["u41_bv_sc2_map_base_0"] = {
		{ 0.9130, 0.2520, "Darkshard" },
	},
	["u41_bv_sc3_map_base_0"] = {
		{ 0.4970, 0.5190, "The Blind" },
	},
	["bdvilla_boss3map_base_0"] = {
		{ 0.5030, 0.3500, "Pyroturge Encratis" },
		{ 0.5630, 0.4910, "Sentinel Aksalaz" },
	},
	["bdvillamap1ext1_base_0"] = {
		{ 0.7430, 0.4520, "Kinras Ironeye" },
	},
	["bdvilla_map2ext2_base_0"] = {
		{ 0.5280, 0.1330, "Pyroturge Encratis" },
	},
	["bdvilla_mapsecret3_base_0"] = {
		{ 0.6050, 0.7210, "Avatar of Fortitude" },
	},
	["bdvilla_mapsecret2_base_0"] = {
		{ 0.5770, 0.8060, "Avatar of Vigor" },
	},
	["bdvilla_map3int1_base_0"] = {
		{ 0.8670, 0.2460, "Captain Geminus" },
	},
	["bdvilla_mapsecret1_base_0"] = {
		{ 0.2670, 0.3750, "Avatar of Zeal" },
	},
	["blackgemfound_map03_base_0"] = {
		{ 0.4440, 0.8960, "Black Gem Monstrosity" },
		{ 0.6360, 0.5030, "Gemcarver Hynax" },
	},
	["blackgemfound_map04_base_0"] = {
		{ 0.8400, 0.8100, "Misura, Assistant to the High Soulbinder" },
	},
	["blackgemfound_map05_base_0"] = {
		{ 0.4610, 0.4110, "Prospector Lyrakta" },
	},
	["blackgemfound_map06_base_0"] = {
		{ 0.5040, 0.4120, "Quartermaster Saldezaar" },
	},
	["blackgemfound_map07_base_0"] = {
		{ 0.4910, 0.4990, "High Soulbinder Vykand" },
	},
	["ui_map_bloodrootext1_base_0"] = {
		{ 0.4090, 0.2700, "Caillaoife" },
		{ 0.6410, 0.5750, "Mathgamain" },
	},
	["ui_map_bloodrootint1_base_0"] = {
		{ 0.5160, 0.3950, "Stoneheart" },
		{ 0.8420, 0.6280, "Galchobhar" },
	},
	["ui_map_bloodrootint2_base_0"] = {
		{ 0.5120, 0.7170, "Attendant of Flame" },
		{ 0.5520, 0.7550, "Gherig Bullblood" },
		{ 0.5520, 0.7150, "Earthgore Amalgam" },
		{ 0.5940, 0.7170, "Attendant of Blood" },
	},
	["castlethornmap_001_base_0"] = {
		{ 0.5510, 0.2220, "Vaduroth" },
		{ 0.5520, 0.6210, "Dread Tindulra" },
		{ 0.6970, 0.4060, "Talfyg" },
	},
	["castlethorn_int_03_base_0"] = {
		{ 0.4080, 0.5160, "Lady Thorn" },
	},
	["castlethorn_int_01_base_0"] = {
		{ 0.3150, 0.2550, "Blood Twilight" },
	},
	["coralaerie_mbwave_001_base_0"] = {
		{ 0.7600, 0.3260, "S'zarzo the Bulwark" },
		{ 0.7800, 0.3050, "Jakarn" },
	},
	["coralaeriesecretmap001_base_0"] = {
		{ 0.2940, 0.5380, "Sword Guardian" },
		{ 0.4630, 0.3720, "Shield Guardian" },
		{ 0.5290, 0.5330, "Staff Guardian" },
	},
	["coralaerieb3_001_base_0"] = {
		{ 0.4110, 0.5050, "Mafremare" },
		{ 0.5010, 0.5920, "Kargaeda" },
		{ 0.5030, 0.4240, "Ofallo" },
		{ 0.5030, 0.5080, "Varallion" },
		{ 0.5920, 0.5060, "Iliata" },
	},
	["coralaerie_b2_001_base_0"] = {
		{ 0.4100, 0.4880, "Sarydil" },
	},
	["coralaerie_b1_001_base_0"] = {
		{ 0.4890, 0.4820, "Maligalig" },
	},
	["ui_cradleofshadowsint_002_base_0"] = {
		{ 0.2340, 0.5000, "Khephidaen" },
		{ 0.7470, 0.7620, "Sithera" },
	},
	["ui_cradleofshadowsint_005_base_0"] = {
		{ 0.4600, 0.5080, "Velidreth" },
	},
	["ui_cradleofshadowsint_003_base_0"] = {
		{ 0.4700, 0.4710, "Dranos Velador" },
		{ 0.5070, 0.2380, "Votary of Velidreth" },
	},
	["ui_map_domdepthsofmal3_base_0"] = {
		{ 0.3590, 0.3480, "Dark Orb" },
		{ 0.4080, 0.6610, "King Narilmor" },
		{ 0.4170, 0.5060, "Symphony of Blades" },
	},
	["ui_map_domdepthsofmal2_base_0"] = {
		{ 0.3780, 0.2930, "The Weeping Woman" },
	},
	["ui_map_domdepthsofmal_base_0"] = {
		{ 0.4670, 0.3160, "The Scavenging Maw" },
	},
	["ere_outsidemap01_base_0"] = {
		{ 0.6110, 0.3020, "Corruption of Stone" },
		{ 0.7600, 0.5400, "Scalded Roots" },
	},
	["ere_insidemap01_base_0"] = {
		{ 0.5560, 0.6820, "Lutea" },
		{ 0.6750, 0.1940, "Corruption of Root" },
	},
	["ere_outsidemap02_base_0"] = {
		{ 0.4100, 0.2950, "Jodoro" },
		{ 0.4530, 0.2100, "Archdruid Devyric" },
	},
	["u45_exiledredoubtmap001_base_0"] = {
		{ 0.0450, 0.6030, "Docent Domitius" },
		{ 0.3490, 0.4540, "Prime Sorcerer Vandorallen" },
		{ 0.5010, 0.2890, "Squall of Retribution" },
		{ 0.6600, 0.5520, "Executioner Jerensi" },
		{ 0.7190, 0.4020, "Eliana Albus" },
		{ 0.9430, 0.5630, "Guard Captain Paratius" },
	},
	["ui_map_falkreathsdemise_base_0"] = {
		{ 0.1930, 0.6340, "Erbogar" },
		{ 0.1990, 0.6480, "Cernuunon" },
		{ 0.2070, 0.6630, "Mochveda" },
		{ 0.2140, 0.6420, "Tuecille" },
		{ 0.4470, 0.4970, "Siege Mammoth" },
		{ 0.5560, 0.4760, "Morrigh Bullblood" },
	},
	["ui_map_falkreathsdemise_i_base_0"] = {
		{ 0.4180, 0.5830, "Deathlord Bjarfrud Skjoralmor" },
	},
	["ui_map_falkreathsdemise_b_base_0"] = {
		{ 0.5300, 0.5350, "Domihaus the Bloody-Horned" },
	},
	["ui_map_fanglairext_base_0"] = {
		{ 0.2170, 0.5120, "Lizabet Charnis" },
		{ 0.5490, 0.4550, "Ulfnor" },
		{ 0.5500, 0.1660, "Cadaverous Dire Wolf" },
		{ 0.5670, 0.1670, "Cadaverous Bear" },
		{ 0.5760, 0.1780, "Cadaverous Senche-Tiger" },
		{ 0.5820, 0.1900, "Cadaverous Guar" },
		{ 0.6980, 0.4700, "Caluurion" },
		{ 0.8030, 0.7990, "Orryn the Black" },
		{ 0.8120, 0.7980, "Thorvokun" },
	},
	["ui_map_frvfrstvlt01_base_0"] = {
		{ 0.8700, 0.5030, "Icestalker" },
	},
	["ui_map_frvfrstvlt04_base_0"] = {
		{ 0.5740, 0.5700, "The Stonekeeper" },
	},
	["ui_map_frvfrstvlt02_base_0"] = {
		{ 0.7400, 0.7420, "Rizzuk Bonechill" },
		{ 0.7640, 0.7460, "Avalanche" },
	},
	["ui_map_frvfrstvlt03_base_0"] = {
		{ 0.4230, 0.7020, "Warlord Tzogvin" },
		{ 0.7800, 0.5130, "Vault Protector" },
	},
	["icereachpart2_base_0"] = {
		{ 0.2350, 0.3820, "Mother Ciannait" },
		{ 0.3800, 0.5900, "Stormborn Revenant" },
	},
	["icereachpart1_base_0"] = {
		{ 0.3560, 0.4310, "Kjarg the Tuskscraper" },
		{ 0.5380, 0.0800, "Vearogh the Shambler" },
		{ 0.6800, 0.3000, "Sister Skelga" },
	},
	["imperialprisondunint01_base_0"] = {
		{ 0.1300, 0.4230, "Overfiend" },
	},
	["imperialprisondunint02_base_0"] = {
		{ 0.3480, 0.5630, "Ibomez the Flesh Sculptor" },
	},
	["imperialprisondunint03_base_0"] = {
		{ 0.5310, 0.5920, "Gravelight Sentry" },
		{ 0.6600, 0.3860, "Flesh Abomination" },
	},
	["imperialprisondunint04_base_0"] = {
		{ 0.4280, 0.2680, "Lord Warden Dusk" },
		{ 0.6560, 0.5680, "Lord-Warden's Council" },
	},
	["maarsmap06_base_0"] = {
		{ 0.8600, 0.7050, "Maarselok" },
	},
	["maarsmap05_base_0"] = {
		{ 0.7520, 0.2590, "Selene" },
		{ 0.8440, 0.1690, "Maarselok" },
	},
	["maarsoutsidemap003_base_0"] = {
		{ 0.5890, 0.6940, "Azureblight Lurcher" },
	},
	["maarscave1_base_0"] = {
		{ 0.7990, 0.2240, "Selene's Claws & Selene's Fangs" },
	},
	["maarsmap04_base_0"] = {
		{ 0.1790, 0.7920, "Azureblight Cancroid" },
	},
	["u45_lepseclusa_map01_base_0"] = {
		{ 0.3190, 0.1120, "Garvin the Tracker" },
		{ 0.4410, 0.3190, "Lewin Frey" },
	},
	["u45_lepseclusa_map02_base_0"] = {
		{ 0.1980, 0.5910, "Siege Master Malthoras" },
		{ 0.2050, 0.4410, "Noriwen" },
		{ 0.5170, 0.5120, "Flamedancer Ajim-Rei" },
		{ 0.8210, 0.5120, "Orpheon the Tactician" },
	},
	["marchodsacrifices_base_0"] = {
		{ 0.3650, 0.3210, "Aghaedh of the Solstice" },
		{ 0.3830, 0.4560, "Wyress Strigidae," },
		{ 0.3900, 0.4490, "Wyress Rangifer" },
		{ 0.3980, 0.4590, "Wyress Ursus" },
		{ 0.5720, 0.3010, "Dagrund the Bulky" },
		{ 0.6650, 0.3930, "Tarcyr" },
		{ 0.7320, 0.6950, "Balorgh" },
	},
	["mhkmoonhunterkeep_base_0"] = {
		{ 0.4830, 0.6210, "Jailer Melitus" },
	},
	["mhkmoonhunterkeep2_base_0"] = {
		{ 0.6250, 0.4620, "Hedge Maze Guardian" },
	},
	["mhkmoonhunterkeep3_base_0"] = {
		{ 0.2640, 0.6970, "Mylenne Moon-Caller" },
		{ 0.5010, 0.2510, "Archivist Ernarde" },
		{ 0.7440, 0.2550, "Ary" },
		{ 0.7450, 0.3160, "Zel" },
		{ 0.7450, 0.2860, "Vykosa the Ascendant" },
	},
	["moongravesection1_base_0"] = {
		{ 0.4000, 0.7660, "Risen Ruins" },
	},
	["moongravesection2_base_0"] = {
		{ 0.5760, 0.4950, "Dro'zakar" },
	},
	["moongravesection4_base_0"] = {
		{ 0.3757, 0.2505, "Grundwulf" },
		{ 0.5100, 0.3540, "Nisaazda" },
		{ 0.4425, 0.2100, "Grundwulf" },
	},
	["moongravesection3_base_0"] = {
		{ 0.4470, 0.5590, "Kujo Kethba" },
	},
	["u41_osp_map_section2_base_0"] = {
		{ 0.8420, 0.2130, "Anthelmir's Construct" },
		{ 0.8610, 0.2190, "Anthelmir" },
	},
	["u41_osp_map_starterarea_base_0"] = {
		{ 0.2540, 0.3900, "Great Bear" },
		{ 0.4550, 0.3940, "Malthil" },
		{ 0.4610, 0.4040, "Packmaster Rethelros" },
	},
	["u41_osp_map_section3_base_0"] = {
		{ 0.3290, 0.6500, "Maerolor" },
		{ 0.4170, 0.6510, "Aradros the Awakened" },
		{ 0.4170, 0.7350, "Faenalir" },
		{ 0.4180, 0.7790, "The Smelter" },
		{ 0.5090, 0.6500, "Nilborwen" },
	},
	["u41_osp_map_secret1bottom_base_0"] = {
		{ 0.5550, 0.3710, "Sluthrug the Bloodied" },
	},
	["u41_osp_map_secret2_base_0"] = {
		{ 0.6940, 0.4830, "Bolg of Wicked Barbs" },
	},
	["u41_osp_map_secret3_base_0"] = {
		{ 0.1430, 0.5420, "Grubduthag Many-Fates" },
	},
	["rpb_map_ext001_base_0"] = {
		{ 0.1450, 0.4360, "Rogerain the Sly" },
	},
	["rpb_map_int001_base_0"] = {
		{ 0.1650, 0.6710, "Prior Thierric Sarazen" },
		{ 0.6750, 0.6580, "Eliam Merick" },
	},
	["rpb_map_secret001_base_0"] = {
		{ 0.3450, 0.4490, "Grievous Twilight" },
		{ 0.5700, 0.6440, "Spider Daedra" },
		{ 0.6940, 0.3320, "Wraith of Crows" },
	},
	["ui_map_mazzatunext_base_0"] = {
		{ 0.3830, 0.7290, "Zatzu" },
		{ 0.4230, 0.3350, "Xal-Nur the Slaver" },
		{ 0.4990, 0.5070, "Tree-Minder Na-Kesh" },
		{ 0.6520, 0.7610, "Mighty Chudan" },
	},
	["ui_map_scalecaller004_base_0"] = {
		{ 0.2730, 0.7450, "Plague Concocter Mortieu" },
		{ 0.7710, 0.5460, "Zaan the Scalecaller" },
	},
	["ui_map_scalecaller001_base_0"] = {
		{ 0.3650, 0.1700, "Orzun the Foul-Smelling" },
		{ 0.3670, 0.1960, "Rinaerus the Rancid" },
		{ 0.6810, 0.4480, "Doylemish Ironheart" },
	},
	["ui_map_scalecaller002_base_0"] = {
		{ 0.3030, 0.2170, "Matriarch Aldis" },
	},
	["u37_scrivenershall_sect1baseme_base_0"] = {
		{ 0.6150, 0.4780, "Zilipif" },
		{ 0.7070, 0.6120, "Keshargo" },
	},
	["u37_scrivenershall_sect2b_map_base_0"] = {
		{ 0.6580, 0.0730, "Ozezan the Inferno" },
	},
	["u37_scrivenershall_boss3_map_base_0"] = {
		{ 0.4670, 0.7070, "Lamikhai" },
		{ 0.5140, 0.2570, "Valinna" },
	},
	["u37_scrivenershall_boss3int_ma_base_0"] = {
		{ 0.6670, 0.1690, "Valinna" },
		{ 0.7370, 0.2460, "Lamikhai" },
	},
	["u37_scrivenershall_sect1_map_base_0"] = {
		{ 0.2850, 0.5420, "Reinfyr" },
		{ 0.8870, 0.6020, "Riftmaster Naqri" },
	},
	["lostshipyard_map001_base_0"] = {
		{ 0.1850, 0.4990, "Shrouded Axeman" },
		{ 0.4490, 0.6280, "Nazaray" },
		{ 0.4530, 0.3170, "Foreman Bradiggan" },
		{ 0.8270, 0.5350, "Captain Numirril" },
		{ 0.8750, 0.6840, "Storm-Cursed Sailor" },
	},
	["rivenyardsecarea1_base_0"] = {
		{ 0.3150, 0.5170, "Lost Maiden" },
	},
	["stonegarden01_base_0"] = {
		{ 0.6900, 0.1690, "Exarch Kraglen" },
	},
	["cauldronmapstart_base_0"] = {
		{ 0.2620, 0.6300, "Oxblood the Depraved" },
		{ 0.2660, 0.3840, "Taskmaster Viccia" },
		{ 0.6940, 0.2830, "Molten Guardian" },
		{ 0.7170, 0.7130, "Baron Zaudrus" },
	},
	["tdc_map_inside_001_base_0"] = {
		{ 0.1990, 0.8170, "Magma Incarnate" },
		{ 0.5270, 0.4020, "Cyronin Artellian" },
	},
	["tdc_map_outside_001_base_0"] = {
		{ 0.1990, 0.3630, "Scorion Broodlord" },
	},
	["tdc_map_secret_001_base_0"] = {
		{ 0.3800, 0.4580, "Grim Warden" },
		{ 0.4570, 0.6040, "Purgator" },
		{ 0.6330, 0.5330, "Undertaker" },
	},
	["unhallowedgravesecret2map_base_0"] = {
		{ 0.6340, 0.6990, "Voria the Heart-Thief" },
	},
	["unhallowedgravemap001_base_0"] = {
		{ 0.4090, 0.2630, "Hakgrym the Howler" },
	},
	["unhallowedgravemap004_base_0"] = {
		{ 0.3250, 0.4770, "Nabor the Forgotten" },
	},
	["unhallowedgravemap001b_base_0"] = {
		{ 0.5650, 0.5110, "Eternal Aegis" },
	},
	["unhallowedgravemap001c_base_0"] = {
		{ 0.4540, 0.3890, "Ondagore the Mad" },
	},
	["unhallowedgravemap002_base_0"] = {
		{ 0.5740, 0.5030, "Keeper of the Kiln" },
	},
	["unhallowedgravemap003_base_0"] = {
		{ 0.5250, 0.4740, "Kjalnar Tombskald" },
		{ 0.6680, 0.4710, "Tzirzhalir" },
	},
	["unhallowedgravemap005_base_0"] = {
		{ 0.4640, 0.4880, "Voria's Masterpiece" },
	},
	["wgtgreenemporerway_base_0"] = {
		{ 0.2990, 0.7410, "The Iron-Swathed Glutton" },
	},
	["wgtimperialthroneroom_base_0"] = {
		{ 0.5390, 0.5270, "The Adjudicator" },
	},
	["wgtlibrarymain_base_0"] = {
		{ 0.3920, 0.6390, "Otho Numida" },
		{ 0.4560, 0.6610, "Cordius Pontifio" },
		{ 0.5280, 0.6430, "Micella Carlinus" },
	},
	["wgtvoid2_base_0"] = {
		{ 0.4040, 0.4210, "The Scion of Wrath" },
		{ 0.4110, 0.2420, "The Planar Inhibitor" },
	},
	["wgtpinnacleboss_base_0"] = {
		{ 0.4670, 0.4910, "Molag Kena" },
	},
}

-- alias for orcrest
BossData.PublicChampionTableStore["orcrest2_base_0"] = BossData.PublicChampionTableStore["orcrest_base_0"]

-- alias for Halls of Regulation
BossData.DelveChampionTableStore["hallsofregulation_base_0"] = BossData.DelveChampionTableStore
	["hallsofregulation_2_base_0"]

-- alias for pulkupper_base_0
BossData.DelveChampionTableStore["pulkupper_base_0"] = BossData.DelveChampionTableStore["pulklower_base_0"]

-- alias for Gloomreach
BossData.DelveChampionTableStore["gloomreach2_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach2b_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach2c_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach3_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach4_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach5_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]
BossData.DelveChampionTableStore["gloomreach5b_base_0"] = BossData.DelveChampionTableStore["gloomreach_base_0"]

-- Alias for Blackwood
BossData.DelveChampionTableStore["arpeniah_base_0"] = BossData.DelveChampionTableStore["arpenial_base_0"]
BossData.DelveChampionTableStore["arpeniah2_base_0"] = BossData.DelveChampionTableStore["arpenial_base_0"]
BossData.DelveChampionTableStore["arpenial3_base_0"] = BossData.DelveChampionTableStore["arpenial_base_0"]

-- vunalk
BossData.DelveChampionTableStore["vunalk1_base_0"] = BossData.DelveChampionTableStore["vunalk2_base_0"]

-- u32_dreaded_refuge_int_base_0
BossData.DelveChampionTableStore["u32_dreaded_refuge_int_base_0"] = BossData.DelveChampionTableStore
	["u32_dreaded_refuge_int_base2_0"]

-- Champion categories
BossData.ChampionCategory = {
	delve = "delve",
	public = "public",
	group = "group",
}

-- Categorized stores (format: { x, y, "Name" })
BossData.DelveChampionTableStore = BossData.DelveChampionTableStore or {}
BossData.PublicChampionTableStore = BossData.PublicChampionTableStore or {}
BossData.GroupChampionTableStore = BossData.GroupChampionTableStore or {}

local CATEGORY_TO_STORE = {
	[BossData.ChampionCategory.delve]  = function() return BossData.DelveChampionTableStore end,
	[BossData.ChampionCategory.public] = function() return BossData.PublicChampionTableStore end,
	[BossData.ChampionCategory.group]  = function() return BossData.GroupChampionTableStore end,
}

-- Lightweight classifier using POI types; returns "delve" | "public" | "group" | "unknown"
local function ClassifyCurrentMapCategory()
	local zoneIndex = GetCurrentMapZoneIndex()
	if zoneIndex and zoneIndex > 0 then
		local px, py = GetMapPlayerPosition("player")
		local bestPoi, bestDist2 = nil, math.huge
		for poiIndex = 1, GetNumPOIs(zoneIndex) do
			-- Use GetPOIMapInfo for normalized coordinates
			local poiX, poiY = GetPOIMapInfo(zoneIndex, poiIndex)
			if poiX and poiY and poiX > 0 and poiY > 0 then
				local dx, dy = poiX - px, poiY - py
				local d2 = dx * dx + dy * dy
				if d2 < bestDist2 then bestDist2, bestPoi = d2, poiIndex end
			end
		end
		if bestPoi then
			local poiType = GetPOIType(zoneIndex, bestPoi)
			if poiType == POI_TYPE_DUNGEON then
				return BossData.ChampionCategory.delve
			elseif poiType == POI_TYPE_PUBLIC_DUNGEON then
				return BossData.ChampionCategory.public
			elseif poiType == POI_TYPE_GROUP_DUNGEON then
				return BossData.ChampionCategory.group
			end
		end
	end
	-- Fallback: treat active instance as group dungeon
	if (IsPlayerInGroupDungeon and IsPlayerInGroupDungeon()) or (GetCurrentZoneDungeonDifficulty and GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE) then
		return
			BossData.ChampionCategory.group
	end
	return "unknown"
end

-- Expose classifier for external reuse while keeping local calls intact
BossData.ClassifyCurrentMapCategory = BossData.ClassifyCurrentMapCategory or ClassifyCurrentMapCategory

-- Unified accessor. If category is provided, only that store is searched.
-- If omitted, the function classifies and tries the best-matching store, then falls back to all.
function BossData.GetChampionEntriesForMap(mapTexture, category)
	local function copyInto(dst, src) for i = 1, #src do dst[#dst + 1] = src[i] end end

	-- Build a small set of normalized candidate keys to handle common texture naming variants.
	local function buildKeyCandidates(key)
		if not key or key == "" then return {} end
		key = tostring(key):lower()
		-- Strip any folder prefixes if present
		key = key:gsub("^.*/", "")

		local seen, out = {}, {}
		local function add(k)
			if k and not seen[k] then seen[k] = true; out[#out + 1] = k end
		end

		-- Base key and simple prefixes
		add(key)
		add(key:gsub("^ui_map_", ""))

		-- With/without _base_ before trailing numeric level (handles e.g. rpb_map_ext001_0 vs rpb_map_ext001_base_0)
		if key:match("_(%d+)$") and not key:find("_base_") then
			add((key:gsub("_(%d+)$", "_base_%1")))
		end
		if key:find("_base_%d+$") then
			add((key:gsub("_base_(%d+)$", "_%1")))
		end

		-- Also produce the above for the ui_map_-stripped variant
		local noUi = key:gsub("^ui_map_", "")
		if noUi ~= key then
			if noUi:match("_(%d+)$") and not noUi:find("_base_") then
				add((noUi:gsub("_(%d+)$", "_base_%1")))
			end
			if noUi:find("_base_%d+$") then
				add((noUi:gsub("_base_(%d+)$", "_%1")))
			end
		end

		return out
	end

	local function tryStoresForKeyCandidates(getStore, candidates)
		local store = getStore()
		if not store then return nil end
		for i = 1, #candidates do
			local k = candidates[i]
			local t = store[k]
			if t then return t end
		end
		return nil
	end

	local candidates = buildKeyCandidates(mapTexture)

	if category and CATEGORY_TO_STORE[category] then
		return tryStoresForKeyCandidates(CATEGORY_TO_STORE[category], candidates)
	end

	-- Auto classify via POI proximity first
	local inferred = ClassifyCurrentMapCategory()
	if CATEGORY_TO_STORE[inferred] then
		local t = tryStoresForKeyCandidates(CATEGORY_TO_STORE[inferred], candidates)
		if t then return t end
	end

	-- Heuristic: if exactly one store has entries for this map (across candidates), return that
	local found, foundTable = 0, nil
	for _, getStore in pairs(CATEGORY_TO_STORE) do
		local t = tryStoresForKeyCandidates(getStore, candidates)
		if t then
			found = found + 1
			foundTable = foundTable or t
			if found > 1 then break end
		end
	end
	if found == 1 then return foundTable end

	-- Fallback: merge all stores that have any entries for any candidate key
	local merged = nil
	for _, getStore in pairs(CATEGORY_TO_STORE) do
		local t = tryStoresForKeyCandidates(getStore, candidates)
		if t then
			merged = merged or {}
			copyInto(merged, t)
		end
	end
	return merged
end
