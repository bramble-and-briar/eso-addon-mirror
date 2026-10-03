local KD = KyzderpsDerps
KD.SpawnTimer = {}
local SpawnTimer = KD.SpawnTimer

local running = false

-- Dungeon zoneIds
local DUNGEON_ZONEIDS = {
    ["144" ] = true,  -- Spindleclutch I
    ["936" ] = true,  -- Spindleclutch II
    ["380" ] = true,  -- The Banished Cells I
    ["935" ] = true,  -- The Banished Cells II
    ["283" ] = true,  -- Fungal Grotto I
    ["934" ] = true,  -- Fungal Grotto II
    ["146" ] = true,  -- Wayrest Sewers I
    ["933" ] = true,  -- Wayrest Sewers II
    ["126" ] = true,  -- Elden Hollow I
    ["931" ] = true,  -- Elden Hollow II
    ["63"  ] = true,  -- Darkshade Caverns I
    ["930" ] = true,  -- Darkshade Caverns II
    ["130" ] = true,  -- Crypt of Hearts I
    ["932" ] = true,  -- Crypt of Hearts II
    ["176" ] = true,  -- City of Ash I
    ["681" ] = true,  -- City of Ash II (Inner Grove)
    ["148" ] = true,  -- Arx Corinium
    ["22"  ] = true,  -- Volenfell
    ["131" ] = true,  -- Tempest Island
    ["449" ] = true,  -- Direfrost Keep
    ["38"  ] = true,  -- Blackheart Haven
    ["31"  ] = true,  -- Selene's Web
    ["64"  ] = true,  -- Blessed Crucible
    ["11"  ] = true,  -- Vaults of Madness
    ["678" ] = true,  -- Imperial City Prison (Bastion)
    ["688" ] = true,  -- White-Gold Tower (Green Emperor Way)
    ["843" ] = true,  -- Ruins of Mazzatun
    ["848" ] = true,  -- Cradle of Shadows
    ["973" ] = true,  -- Bloodroot Forge
    ["974" ] = true,  -- Falkreath Hold
    ["1009"] = true,  -- Fang Lair
    ["1010"] = true,  -- Scalecaller Peak
    ["1052"] = true,  -- Moon Hunter Keep
    ["1055"] = true,  -- March of Sacrifices (Bloodscent Pass)
    ["1080"] = true,  -- Frostvault
    ["1081"] = true,  -- Depths of Malatar
    ["1122"] = true,  -- Moongrave Fane
    ["1123"] = true,  -- Lair of Maarselok
    ["1152"] = true,  -- Icereach
    ["1153"] = true,  -- Unhallowed Grave
    ["1197"] = true,  -- Stone Garden
    ["1201"] = true,  -- Castle Thorn
    ["1228"] = true,  -- Black Drake Villa
    ["1229"] = true,  -- The Cauldron
    ["1267"] = true,  -- Red Petal Bastion
    ["1268"] = true,  -- The Dread Cellar
    ["1301"] = true,  -- Coral Aerie
    ["1302"] = true,  -- Shipwright's Regret
    ["1360"] = true,  -- Earthen Root Enclave
    ["1361"] = true,  -- Graven Deep
    ["1389"] = true,  -- Bal Sunnar
    ["1390"] = true,  -- Scrivener's Hall
    ["1470"] = true,  -- Oathsworn Pit
    ["1471"] = true,  -- Bedlam Veil
    ["1496"] = true,  -- Exiled Redoubt
    ["1497"] = true,  -- Lep Seclusa
    ["1551"] = true,  -- Naj-Caldeesh
    ["1552"] = true,  -- Black Gem Foundry
    ["1562"] = true,  -- Gossamer Crypt (Night Market)
    ["1563"] = true,  -- Mournful Catacomb (Night Market)
    ["1564"] = true,  -- Timeless Wallow (Night Market)
    ["1592"] = true,  -- March of Sacrifices (solo)
    ["1593"] = true,  -- Moon Hunter Keep (solo)
}
KyzderpsDerps.DUNGEON_ZONEIDS = DUNGEON_ZONEIDS

-- Trial/Arena zoneIds
local TRIAL_ZONEIDS = {
    ["636" ] = true,  -- Hel Ra Citadel
    ["638" ] = true,  -- Aetherian Archive
    ["639" ] = true,  -- Sanctum Ophidia
    ["725" ] = true,  -- Maw of Lorkhaj
    ["975" ] = true,  -- Halls of Fabrication
    ["1000"] = true,  -- Asylum Sanctorium
    ["1051"] = true,  -- Cloudrest
    ["1121"] = true,  -- Sunspire
    ["1196"] = true,  -- Kyne's Aegis
    ["1263"] = true,  -- Rockgrove
    ["1344"] = true,  -- Dreadsail Reef
    ["1427"] = true,  -- Sanity's Edge
    ["1478"] = true,  -- Lucent Citadel
    ["1548"] = true,  -- Ossein Cage
    ["1565"] = true,  -- Opulent Ordeal (Night Market)
}
KyzderpsDerps.TRIAL_ZONEIDS = TRIAL_ZONEIDS

local ARENA_ZONEIDS = {
    ["635" ] = true,  -- Dragonstar Arena
    ["677" ] = true,  -- Maelstrom Arena
    ["1082"] = true,  -- Blackrose Prison
    ["1227"] = true,  -- Vateshran Hollows
    ["1436"] = true,  -- Infinite Archive
}
KyzderpsDerps.ARENA_ZONEIDS = ARENA_ZONEIDS

local function IsInstanceId(zoneId)
    return (DUNGEON_ZONEIDS[zoneId] or TRIAL_ZONEIDS[zoneId] or ARENA_ZONEIDS[zoneId]) ~= nil
end
KyzderpsDerps.IsInstanceId = IsInstanceId

-- "Name" of boss (including location/groups) to the number of seconds it takes to respawn. true = default 306s
local BOSS_NAMES = {
-- Dolmens - TODO: 5:18? stonefalls 6:14?

-- Alik'r Desert
    ["Tarrent Herano"] = true, -- Delve: Santaki
    ["Feremuzh"] = true, -- Delve: Coldrock Diggings

-- Apocrypha
    ["Caz'iunes the Executioner"] = 305, -- PD: The Underweave
    ["Creepclaw"] = 302, -- PD: The Underweave
    ["Qacath the Silent"] = 302, -- PD: The Underweave
    ["Kynreve Kev'ni"] = 302, -- PD: The Underweave
    ["Loremaster Trigon"] = 305, -- PD: The Underweave

-- Bangkorai
    ["Curnard the Generous"] = true, -- Delve: Viridian Watch
    ["Razak's Behemoth"] = 300, -- PD: Razak's Wheel
    ["Archivist Sanctius"] = 300, -- PD: Razak's Wheel

-- Blackwood
    ["Havocrel Duke of Storms"] = 311, -- Oblivion Portal
    ["Bhrum / Koska"] = 331, -- WB
    ["War Chief Zathmoz"] = 313, -- WB - I sat at one once that took over 20 minutes to spawn... weird. But after that was 5:03. He takes a while to become damageable though, so this is the damageable timer
    ["Xeemhok the Trophy-Taker"] = 313, -- WB
    ["Old Deathwart"] = 330, -- WB
    ["Ghemvas the Harbinger"] = 302, -- WB
    ["Sul-Xan Ritual Site"] = 301, -- WB
    ["Grapnur / Burthar"] = 305, -- PD: Zenithar's Abbey

-- The Reach / Arkthzand Caverns
    ["Dwarven Dynastor Supreme"] = 335, -- WB

-- Clockwork City
    ["The Imperfect"] = 310, -- WB

-- Coldharbor
    ["Aez the Collector"] = 305, -- PD: Village of the Lost
    ["Cirterisse"] = 305, -- Delve: Aba-Loria
    ["Nerazakan"] = 304, -- Delve: The Grotto of Depravity
    ["Mal Sorra"] = 304, -- Delve: Mal Sorra's Tomb
    ["Daedroth Larder"] = true, -- WB

-- Craglorn
    ["Secluded Nirncrux Mine"] = 600, -- WB: Nirncrux Mine
    ["Defunct Nirncrux Mine"] = 600, -- WB: Nirncrux Mine
    ["Overrun Nirncrux Mine"] = 600, -- WB: Nirncrux Mine
    ["Pillaged Nirncrux Mine"] = 600, -- WB: Nirncrux Mine
    ["Packleader Sigmund"] = 304, -- Delve: Hircine's Haunt
    ["Macharus the Defiler"] = true, -- Celestial Portal

-- Deadlands
    ["The Unmaker"] = 315, -- WB: The Unmaker - doesn't become damageable until 5:15
    ["Taupezu Azzida"] = 312, -- WB: The Abomination Cradle - doesn't become damageable until 5:12 ish?

-- Deshaan
    ["General Celdien"] = true, -- Delve: The Corpse Garden
    ["Bthanual Centurion"] = true, -- Delve: Lower Bthanual

-- Galen
    ["Traux / Druid Rerlas"] = true, -- Delve: Embervine
    ["Bahltur"] = 311, -- Delve: Fauns' Thicket

-- Glenumbra
    ["Rutmange"] = 305, -- PD: Bad Man's Hallows - Skeever
    ["Skitterflame"] = 300, -- PD: Bad Man's Hallows - Incineration BEEEEEEEETLE
    ["Bloatgut"] = 300, -- PD: Bad Man's Hallows - Hoarvor
    ["Bloodcraw"] = 300, -- PD: Bad Man's Hallows - Hoarvor
    ["Gaetane"] = 305, -- Delve: Ilessan Tower
    ["Valenwe"] = true, -- Delve: Cryptwatch Fort
    ["Lilou"] = true, -- Delve: Mines of Khuras

-- Gold Coast
    ["Limenauruus"] = true, -- WB: Minotaur
    ["Ironfang"] = true, -- Delve: Garlas Agea
    ["Exulus"] = true, -- Delve: Hrota Cave
    ["Kvatch Arena"] = 330, -- WB TODO

-- Grahtwood
    ["Great Thorn"] = 300, -- PD: Rood Sunder Ruins
    ["The Devil Wrathmaw"] = 300, -- PD: Rood Sunder Ruins
    ["Rustjaw"] = 300, -- PD: Rood Sunder Ruins
    ["Thick-Bark"] = 300, -- PD: Rood Sunder Ruins
    ["Silent Claw"] = 300, -- PD: Rood Sunder Ruins

-- Greenshade
    ["Maormer Camp"] = true, -- WB: Maormer Camp
    ["Domina Ssaranth"] = true, -- Delve: The Underroot
    ["Hergor the Fallen"] = true, -- PD: Rulanyil's Fall (group event. timer just for loot cooldown)

-- High Isle
    ["Mornard Falls"] = 301, -- WB: Mornard Falls (Hadolids)
    ["Dark Stone Hollow"] = 301, -- WB: Dark Stone Hollow (Ascendant Order fanatics)
    ["Amenos Basin"] = 301, -- WB: Amenos Basin (Eldertide Theurges)

-- Malabal Tor
    ["Arrai"] = true, -- Delve: Shael Ruins
    ["Adavos Dren"] = true, -- Delve: Roots of Silvenar

-- Murkmire
    ["Walks-Like-Thunder"] = true, -- WB: Lurcher

-- Northern Elsweyr
    ["Dragon"] = 620, -- It spawns on the map at around 10:20 (or at least, once), but landed at 11:00
    ["Lieutenant Kurzatha"] = 300, -- PD: Rimmen Necropolis
    ["Lieutenant Fazumir"] = 300, -- PD: Rimmen Necropolis

-- Reaper's March
    ["Sergeant Atilus"] = 300, -- PD: Vile Manse
    ["Pelona the Marksman"] = 300, -- PD: Vile Manse
    ["Limbrender"] = true, -- Delve: Kuna's Delve

-- Shadowfen
    ["Drel"] = 305, -- PD: Sanguine's Demense
    ["The Bloody Judge"] = 305, -- PD: Sanguine's Demense
    ["Kwama Overseer"] = 304, -- Delve: Onkobra Kwama Mine

-- Solstice
    ["Voskrona Guardians"] = true, -- WB

-- Stonefalls
    ["The Moonlit Maiden"] = 305, -- PD: Crow's Wood - Wispmother next to skyshard
    ["Buron"] = 305, -- PD: Crow's Wood - Ghost in cave
    ["Aurig Mireh"] = 307, -- WB
    ["Dezanu / Calls-to-Nature"] = 303, -- Delve: Sheogorath's Tongue

-- Stormhaven
    ["Lughar"] = 300, -- PD: Bonesnap Ruins - first ogre
    ["Bloodmaw"] = 300, -- PD: Bonesnap Ruins - durzog
    ["Rork Bonehammer"] = 300, -- PD: Bonesnap Ruins - goblin

-- Summerset
    ["Direnni Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Sil-Var-Woad Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Rellenthil Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Corgrad Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Welenkin Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Sunhold Abyssal Geyser"] = 645, -- Abyssal Geyser
    ["Welkadra"] = 305, -- PD: Sunhold - Echatere closest to entrance

-- Southern Elsweyr
    ["Ri'Atahrashi"] = 600, -- WB
    ["Iratan the Lightbringer"] = 600, -- WB

-- Telvanni Peninsula
    ["Staxuira"] = 311, -- PD: Gorne (has a long spawn animation)
    ["Stupulag / Gujelag"] = 304, -- PD: Gorne
    ["Zaedare the Afflicted"] = 310, -- Delve: Anchre Egg Mine

-- The Deadlands
    ["Wandering Havocrel"] = 360, -- Wandering WBs seem to be 6 mins ish and random spawn point

-- Vvardenfell
    ["Mud-Tusk"] = 310, -- PD: Nchuleftingth
    ["Mynar Igna / Llaals"] = true, -- PD: Forgotten Wastes
    ["Th'krak the Tunnel-King"] = 304, -- Delve: Matus-Akin Egg Mine
    ["Nchuthand Far-Hurler"] = 304, -- Delve: Nchuleft
    ["Zvvius the Hive Lord"] = 304, -- Delve: Zainsipilu
    ["Old Rust-Eye"] = 304, -- Delve: Khartag Point
    ["Phobbiicus"] = 304, -- Delve: Ashalmawia
    ["Salothan's Council"] = true, -- WB: Salothan's Council
    ["Wuyuvus"] = 304, -- WB: Sulipund Grange

-- West Weald
    ["Swarmkeeper Xvarcon"] = 302, -- PD: Leftwheal Trading Post

-- Western Skyrim
    ["Shademother"] = 606, -- WB
    ["Tulnir"] = 301, -- PD: Labyrinthian - Exterior altar

-- Wrothgar
    ["Magnar Child-Eater"] = true, -- Delve: Argent Mine

-- Cyrodiil
    ["Bear Matriarch"] = 302, -- Delve: Temple to the Divines

-- Imperial City Sewers (non-event 10 mins, event same I think?)
    ["Hzu-Hakan"] = 600, -- Irrigation Tunnels (AD)
    ["Emperor Leovic"] = 605, -- Abyssal Depths (AD)
    ["General Kryozote"] = 600, -- Abyssal Depths (AD)
    ["Lady of the Depths"] = 600, -- Weaver's Nest (AD)
    ["Gati the Storm Sister"] = 600, -- Lambent Passage (DC)
    ["General Zamachar"] = 600, -- Lambent Passage (DC)
    ["Otholug gro-Goldfolly"] = 600, -- Vile Drainage (DC)
    ["Taebod the Gatekeeper"] = 600, -- Wavering Veil (DC)
    ["Wadracki"] = 600, -- Harena Hypogeum (EP)
    ["Ebral the Betrayer"] = 600, -- Antediluvian Vaults (EP)
    ["General Nazenaechar"] = 600, -- Antediluvian Vaults (EP)
    ["Secundinus the Despoiler"] = 600, -- Alessian Tombs (EP)
    ["Simulacrum of Molag Bal"] = 311, -- Center

-- Imperial City (non-event 15 mins)
    ["Arboretum"] = 900,
    ["Arena District"] = 900,
    ["Elven Gardens District"] = 900,
    ["Memorial District"] = 900,
    ["Nobles District"] = 900,
    ["Temple District"] = 900,

-- Dynamic Events
    ["Auridon DE"] = 960, -- 31 -> 16
    ["Glenumbra DE"] = 910, -- 30 -> 15:10
    ["Stonefalls DE"] = 1080, -- 33 -> 18
}

-- Boss actual names to name of the group. GetPlayerLocationName = should use output of that method
local BOSS_GROUPS = {
-- Dolmens
    ["Dread Daedroth"] = "GetPlayerLocationName", -- Dolmen unnamed
    ["Dread Frost Atronach"] = "GetPlayerLocationName", -- Dolmen unnamed
    ["Dread Xivkyn Banelord"] = "GetPlayerLocationName", -- Dolmen unnamed
    ["Dread Lich"] = "GetPlayerLocationName", -- Dolmen unnamed

    ["Lord Dregas Volar"] = "GetPlayerLocationName", -- Dolmen - holder of the Daedric Crescent
    ["Gedna Relvel"] = "GetPlayerLocationName", -- Dolmen - Lich of Mournhold
    ["Vika"] = "GetPlayerLocationName", -- Dolmen - Dark Seducer sister
    ["Dylora"] = "GetPlayerLocationName", -- Dolmen - Dark Seducer sister
    ["Jansa"] = "GetPlayerLocationName", -- Dolmen - Dark Seducer sister
    ["Nomeg Haga"] = "GetPlayerLocationName", -- Dolmen - Frost Atronach
    ["Hrelvesuu"] = "GetPlayerLocationName", -- Dolmen - Daedroth
    ["Zymel Hriz"] = "GetPlayerLocationName", -- Dolmen - Storm Atronach
    ["Menta Na"] = "GetPlayerLocationName", -- Dolmen - Daedroth
    ["Kathutet"] = "GetPlayerLocationName", -- Dolmen - Torturer
    ["Amkaos"] = "GetPlayerLocationName", -- Dolmen - Torturer
    ["Ranyu"] = "GetPlayerLocationName", -- Dolmen - Torturer
    ["Yggmanei the Ever-Open Eye"] = "GetPlayerLocationName", -- Dolmen - Molag Bal's greatest spy
    ["Velehk Sain"] = "GetPlayerLocationName", -- Dolmen - Dremora pirate
    ["Anaxes"] = "GetPlayerLocationName", -- Dolmen - Xivilai torturer
    ["Medrike"] = "GetPlayerLocationName", -- Dolmen - Xivilai torturer
    ["King Styriche of Verkarth"] = "GetPlayerLocationName", -- Dolmen
    ["Fangaril"] = "GetPlayerLocationName", -- Dolmen - companion of the King
    ["Zayzahad"] = "GetPlayerLocationName", -- Dolmen - companion of the King
    ["Rhagothan"] = "GetPlayerLocationName", -- Dolmen - Devourer of Souls
    ["Glut"] = "GetPlayerLocationName", -- Dolmen - Ogrim brother
    ["Hogshead"] = "GetPlayerLocationName", -- Dolmen - Ogrim brother
    ["Stumble"] = "GetPlayerLocationName", -- Dolmen - Ogrim brother
    ["Ozozzachar"] = "GetPlayerLocationName", -- Dolmen - Titan
    ["Methats"] = "GetPlayerLocationName", -- Dolmen - Dremora traveler
    ["Vonshala"] = "GetPlayerLocationName", -- Dolmen - Dremora traveler
    ["Sumeer"] = "GetPlayerLocationName", -- Dolmen - Dremora traveler

-- Bangkorai
    ["Zaman"] = "Telesubi Ruins", -- WB: Liches
    ["Qumehdi"] = "Telesubi Ruins", -- WB: Liches

-- Blackwood
    ["Bhrum"] = "Bhrum / Koska", -- WB: Minotaurs at Shardius's Excavation
    ["Koska"] = "Bhrum / Koska", -- WB: Minotaurs at Shardius's Excavation
    ["Yaxhat Deathmaker"] = "Sul-Xan Ritual Site", -- WB: Sul-Xan Ritual Site
    ["Veesha the Swamp Mystic"] = "Sul-Xan Ritual Site", -- WB: Sul-Xan Ritual Site
    ["Shuvh-Mok"] = "Sul-Xan Ritual Site", -- WB: Sul-Xan Ritual Site
    ["Nukhujeema"] = "Sul-Xan Ritual Site", -- WB: Sul-Xan Ritual Site
    ["Grapnur the Crusher"] = "Grapnur / Burthar", -- PD: Zenithar's Abbey - ogres
    ["Burthar Meatwise"] = "Grapnur / Burthar", -- PD: Zenithar's Abbey - ogres

-- Coldharbor
    ["Rsolignah"] = "Daedroth Larder", -- WB
    ["Keggahiha"] = "Daedroth Larder", -- WB
    ["Nolagha"] = "Daedroth Larder", -- WB

-- Craglorn
    ["Troll Colossus"] = "GetPlayerLocationName", -- Nirncrux Mine

-- Galen
    ["Traux the Ancient"] = "Traux / Druid Rerlas", -- Delve: Embervine
    ["Druid Rerlas"] = "Traux / Druid Rerlas", -- Delve: Embervine

-- Gold Coast
    ["Order Champion"] = "Kvatch Arena",
    ["Knight Commander Panthius"] = "Kvatch Arena",

-- Greenshade
    ["Neiral"] = "Maormer Camp", -- WB: Maormer Camp
    ["Jahlasri"] = "Maormer Camp", -- WB: Maormer Camp
    ["Hetsha"] = "Maormer Camp", -- WB: Maormer Camp

-- High Isle
    ["Hadolid Matron"] = "Mornard Falls", -- WB: Mornard Falls
    ["Hadolid Consort"] = "Mornard Falls", -- WB: Mornard Falls
    ["The Ascendant Harrower"] = "Dark Stone Hollow", -- WB: Dark Stone Hollow
    ["The Ascendant Executioner"] = "Dark Stone Hollow", -- WB: Dark Stone Hollow
    ["Rosara the Theurge"] = "Amenos Basin", -- WB: Amenos Basin (Eldertide Theurges)
    ["Skerard the Theurge"] = "Amenos Basin", -- WB: Amenos Basin (Eldertide Theurges)

-- Northern Elsweyr
    ["Zav'i"] = "Zav'i / Akumjhargo", -- WB: Red Hands Run
    ["Akumjhargo"] = "Zav'i / Akumjhargo", -- WB: Red Hands Run

-- Reaper's March
    ["Varien"] = "Reaper's Henge", -- WB: Reaper's Henge
    ["Gravecaller Niramo"] = "Reaper's Henge", -- WB: Reaper's Henge

-- Solstice
    ["Wind-Bound Voskrona"] = "Voskrona Guardians", -- WB: Shrine of Vakkan
    ["Flame-Bound Voskrona"] = "Voskrona Guardians", -- WB: Shrine of Vakkan
    ["Growth-Bound Voskrona"] = "Voskrona Guardians", -- WB: Shrine of Vakkan
    ["The Tender"] = "Tender / Ogrim", -- PD: Calindvale Gardens
    ["Ensnared Ogrim"] = "Tender / Ogrim", -- PD: Calindvale Gardens

-- Stonefalls
    ["Dezanu"] = "Dezanu / Calls-to-Nature", -- Delve: Sheogorath's Tongue
    ["Calls-to-Nature"] = "Dezanu / Calls-to-Nature", -- Delve: Sheogorath's Tongue

-- Summerset
    ["Ruella Many-Claws"] = "GetPlayerLocationName", -- Abyssal Geyser
    ["Churug of the Abyss"] = "GetPlayerLocationName", -- Abyssal Geyser
    ["Sheefar of the Depths"] = "GetPlayerLocationName", -- Abyssal Geyser
    ["Girawell the Erratic"] = "GetPlayerLocationName", -- Abyssal Geyser - Salamander
    ["Muustikar Wave-Eater"] = "GetPlayerLocationName", -- Abyssal Geyser
    ["Reefhammer"] = "GetPlayerLocationName", -- Abyssal Geyser - Haj Mota
    ["Darkstorm the Alluring"] = "GetPlayerLocationName", -- Abyssal Geyser - Nereid thing
    ["Eejoba the Radiant"] = "GetPlayerLocationName", -- Abyssal Geyser - Wispmother
    ["Tidewrack"] = "GetPlayerLocationName", -- Abyssal Geyser - Sea Lurcher
    ["Vsskalvor"] = "GetPlayerLocationName", -- Abyssal Geyser - Sea Viper

-- Telvanni Peninsula
    ["Stupulag"] = "Stupulag / Gujelag", -- PD: Gorne
    ["Gujelag"] = "Stupulag / Gujelag", -- PD: Gorne

-- The Deadlands
    ["Vorsholazh the Anvil"] = "Wandering Havocrel", -- Wandering WB
    ["Irncifel the Despoiler"] = "Wandering Havocrel", -- Wandering WB
    ["Kothan the Razorsworn"] = "Wandering Havocrel", -- Wandering WB

-- Vvardenfell
    ["Councilor Reynis"] = "Salothan's Council", -- WB: ghosts
    ["Orator Salothan"] = "Salothan's Council", -- WB: ghosts
    ["General Tanasa"] = "Salothan's Council", -- WB: ghosts
    ["Regent Beleth"] = "Salothan's Council", -- WB: ghosts
    ["Mynar Igna"] = "Mynar Igna / Llaals", -- PD: Forgotten Wastes
    ["Conflagrator Llaals"] = "Mynar Igna / Llaals", -- PD: Forgotten Wastes

-- West Weald
    ["Greenspeaker Baedalas"] = "Frontier's Cradle", -- WB: southwest
    ["Rootstrider Maglin"] = "Frontier's Cradle", -- WB: southwest
    ["Venombow Daitel"] = "Frontier's Cradle", -- WB: southwest
    ["Keeper Taman"] = "Frontier's Cradle", -- WB: southwest
    ["Fang"] = "Centurion's Rise", -- WB: mid
    ["Talon"] = "Centurion's Rise", -- WB: mid
    ["Spitetooth"] = "Tharrikers", -- PD: Silorn
    ["Bloodmane"] = "Tharrikers", -- PD: Silorn
    ["Bone-Breaker"] = "Shaman / Bone-Breaker", -- PD: Silorn
    ["Shaman Rezzutum"] = "Shaman / Bone-Breaker", -- PD: Silorn
    ["Shrakkaher"] = "GetPlayerLocationName", -- Mirrormoor Incursion
    ["Rrarrvok"] = "GetPlayerLocationName", -- Mirrormoor Incursion
    ["Krrazzak"] = "GetPlayerLocationName", -- Mirrormoor Incursion

-- Western Skyrim
    ["Vig"] = "Hordrek's Hunting Grounds",
    ["Hordrek"] = "Hordrek's Hunting Grounds",
    ["Otal"] = "Hordrek's Hunting Grounds",

-- Imperial City
    ["Lady Malygda"] = "Arboretum",
    ["Ysenda Resplendent"] = "Arboretum",
    ["Glorgoloch the Destroyer"] = "Arena District",
    ["King Khrogo"] = "Arena District",
    ["The Screeching Matron"] = "Elven Gardens District",
    ["Zoal the Ever-Wakeful"] = "Elven Gardens District",
    ["Nunatak"] = "Memorial District",
    ["Volghass"] = "Memorial District",
    ["Amoncrul"] = "Nobles District",
    ["Baron Thirsk"] = "Nobles District",
    ["Immolator Charr"] = "Temple District",
    ["Mazaluhad"] = "Temple District",
}

local BOSS_BLACKLIST = {
    ["Orilo"] = true, -- Glenumbra DE
    ["Bandit Swashbuckler Captain"] = true, -- Auridon DE
}


---------------------------------------------------------------------------------------------------
-- Hide panel while in menus
---------------------------------------------------------------------------------------------------
local function FragmentChange(oldState, newState)
    if (newState == SCENE_FRAGMENT_HIDDEN) then
        SpawnTimerContainer:SetHidden(true)
    elseif (newState == SCENE_FRAGMENT_SHOWN) then
        local index = 0
        for bossName, bossVals in pairs(KyzderpsDerps.savedValues.spawnTimer.timers) do
            index = index + 1
        end
        if (index > 0) then
            SpawnTimerContainer:SetHidden(not KyzderpsDerps.savedOptions.spawnTimer.enable)
        end
    end
end


---------------------------------------------------------------------------------------------------
-- Initialize a timer line and add to the panel
---------------------------------------------------------------------------------------------------
local function AddBoss(bossName)
    local index = SpawnTimerContainer:GetNumChildren() - 1
    local bossControl = CreateControlFromVirtual(
        "$(parent)Boss" .. tostring(index),  -- name
        SpawnTimerContainer,           -- parent
        "SpawnTimer_Line_Template",    -- template
        "")                            -- suffix
    bossControl:SetAnchor(TOPLEFT, SpawnTimerContainerLabel, BOTTOMLEFT, 0, (index - 1) * 24)
    return bossControl
end


---------------------------------------------------------------------------------------------------
-- Display a center-screen announcement with sound effect
---------------------------------------------------------------------------------------------------
local function ShowAnnouncement(msgText, secondText, sound)
    local msgSound = sound or SOUNDS.CHAMPION_POINT_GAINED
    local msg = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, msgSound)
    msg:SetText(msgText, secondText)
    msg:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_CHAMPION_POINT_GAINED)
    msg:MarkSuppressIconFrame()
    CENTER_SCREEN_ANNOUNCE:DisplayMessage(msg)
end


---------------------------------------------------------------------------------------------------
-- Poll every 900ms to update the timer
---------------------------------------------------------------------------------------------------
local function PollTimer()
    local index = 0
    -- Iterate through all bosses stored in the table
    for bossName, bossVals in pairs(KyzderpsDerps.savedValues.spawnTimer.timers) do
        index = index + 1
        local elapsed = (bossVals.startTime > 0) and GetTimeStamp() - bossVals.startTime or 0

        local respawnTime = 306 -- default of 5:06
        if (type(BOSS_NAMES[bossName]) == "number") then
            respawnTime = BOSS_NAMES[bossName]
        end

        -- Remove timers that are >= 2.5x length of respawn
        if (elapsed >= respawnTime * 2.5) then
            KyzderpsDerps.savedValues.spawnTimer.timers[bossName] = nil
            KyzderpsDerps:dbg("Removed " .. bossName .. " from respawn timers at " .. elapsed / 60 .. " mins")
        else

            local timerFormatted = string.format("%02d:%02d", zo_floor(elapsed / 60), elapsed % 60)
            local color = "00FF00" -- green
            if (elapsed >= respawnTime) then color = "FF0000" -- red
            elseif (elapsed >= respawnTime - 10) then color = "FF9100" -- orange
            elseif (elapsed >= respawnTime - 30) then color = "FFFF00" -- yellow
            end


            -- Get or create the control
            local bossControl = SpawnTimerContainer:GetNamedChild("Boss" .. index)
            if (bossControl == nil) then
                bossControl = AddBoss(bossName)
            end
            bossControl:GetNamedChild("TimerText"):SetText("|c" .. color .. timerFormatted .. "|r")
            bossControl:GetNamedChild("BossText"):SetText(bossName)
            bossControl:SetHidden(false)

            -- Special scamp handling during event?
            if (bossName == "Sewers Scamp") then
                -- Display an alert X seconds prior to respawn
                if (elapsed >= (KyzderpsDerps.savedOptions.spawnTimer.scamp - KyzderpsDerps.savedOptions.spawnTimer.alert.seconds)
                    and not KyzderpsDerps.savedValues.spawnTimer.timers[bossName].alerted) then
                    KyzderpsDerps.savedValues.spawnTimer.timers[bossName].alerted = true
                    if (KyzderpsDerps.savedOptions.spawnTimer.alert.enable) then
                        ShowAnnouncement(bossName,
                                         "Respawning in " .. KyzderpsDerps.savedOptions.spawnTimer.alert.seconds .. " seconds!",
                                         SOUNDS.BATTLEGROUND_NEARING_VICTORY)
                    end
                end
            end

            -- Display an alert X seconds prior to respawn
            if (elapsed >= (respawnTime - KyzderpsDerps.savedOptions.spawnTimer.alert.seconds)
                and not KyzderpsDerps.savedValues.spawnTimer.timers[bossName].alerted) then
                KyzderpsDerps.savedValues.spawnTimer.timers[bossName].alerted = true
                if (KyzderpsDerps.savedOptions.spawnTimer.alert.enable) then
                    ShowAnnouncement(bossName,
                                     "Respawning in " .. KyzderpsDerps.savedOptions.spawnTimer.alert.seconds .. " seconds!",
                                     SOUNDS.BATTLEGROUND_NEARING_VICTORY)
                end
            end
        end
    end

    -- Hide boss controls that are no longer being used
    if (SpawnTimerContainer:GetNumChildren() - 2 > index) then
        for i = index + 1, SpawnTimerContainer:GetNumChildren() - 2 do
            SpawnTimerContainer:GetNamedChild("Boss" .. i):SetHidden(true)
        end
    end

    -- Adjust the panel height
    SpawnTimerContainer:SetHeight((index + 1) * 24 + 6)

    -- Hide the panel if there are no timers
    if (index == 0) then
        SpawnTimerContainer:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate(KyzderpsDerps.name .. "SpawnTimerTimer")
        KyzderpsDerps:dbg("Stopping SpawnTimer polling")
        running = false
    elseif (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()) then
        SpawnTimerContainer:SetHidden(not KyzderpsDerps.savedOptions.spawnTimer.enable)
    end
end


---------------------------------------------------------------------------------------------------
-- On boss killed, add it to the timers
---------------------------------------------------------------------------------------------------
local function BossKilled(groupName, bossName)
    KyzderpsDerps.savedValues.spawnTimer.timers[groupName] = { startTime = GetTimeStamp(), alerted = false, }
    if (not running) then
        KyzderpsDerps:dbg("Starting SpawnTimer polling")
        EVENT_MANAGER:RegisterForUpdate(KyzderpsDerps.name .. "SpawnTimerTimer", 900, PollTimer)
        running = true
    end

    -- Display chat message if enabled
    if (KyzderpsDerps.savedOptions.spawnTimer.chat.enable) then
        local msg = "|cFFFFFF" .. groupName .. "|r died"
        if (bossName ~= nil and groupName ~= bossName) then
            msg = "|cFFFFFF" .. bossName .. "|r died at |cFFFFFF" .. groupName .. "|r"
        end
        if (KyzderpsDerps.savedOptions.spawnTimer.chat.timestamp) then
            msg = "[" .. GetTimeString() .. "] " .. msg
        end
        CHAT_ROUTER:AddSystemMessage(msg)
    end
end


---------------------------------------------------------------------------------------------------
-- Check if a unit is a boss
-- Returns: group name
---------------------------------------------------------------------------------------------------
local function IsBossByUnitTag(unitTag)
    local bossName = GetUnitName(unitTag)
    if (BOSS_NAMES[bossName] or BOSS_GROUPS[bossName]) then
        -- All hand hard-coded bosses
    elseif (string.find(unitTag, "^boss")) then
        -- Should handle all world bosses, newer public dungeons, and world events
        KyzderpsDerps:dbg("|cFF8888Unhandled: " .. bossName .. "|r")
    elseif (unitTag == "reticleover") then
        -- Try all deadly and hard mobs?
        local diff = GetUnitDifficulty(unitTag)
        if (diff ~= MONSTER_DIFFICULTY_DEADLY and diff ~= MONSTER_DIFFICULTY_HARD) then
            if (bossName == "Trove Scamp" or bossName == "Cunning Scamp") then
                BossKilled("Sewers Scamp")
                return false
            elseif (not BOSS_NAMES[bossName] and not BOSS_GROUPS[bossName]) then
                return false
            end
        end

        -- Only care about "dungeons", this will be public dungeons and delves because group dungeons are skipped below
        if (not IsUnitInDungeon("player") and bossName ~= "Dragon") then
            -- This can be overland, so unnamed bosses at dolmens, or dragons
            local groupName = GetPlayerLocationName()
            if (string.find(groupName, "Dolmen$")) then
                return groupName
            end
            return false
        end
        KyzderpsDerps:dbg("|cFF8888Unhandled: " .. bossName .. "|r")
    else
        return false
    end

    -- Skip trial or dungeon bosses
    if (GetCurrentParticipatingRaidId() ~= 0
        or IsInstanceId(tostring(GetZoneId(GetUnitZoneIndex("player"))))) then
        KyzderpsDerps:dbg("Skipping " .. bossName .. " because it is a trial/dungeon boss.")
        return false
    end

    -- Skip bosses in the ignore list
    if (KyzderpsDerps.savedOptions.spawnTimer.ignoreList[bossName]) then
        KyzderpsDerps:dbg("Skipping " .. bossName .. " because it is in the ignore filter.")
        return false
    end

    -- Skip bosses in hardcoded ignore list
    if (BOSS_BLACKLIST[bossName]) then
        return false
    end

    -- Skip bosses in the Night Market
    if (GetZoneId(GetUnitZoneIndex("player")) == 1559) then
        KyzderpsDerps:dbg("Skipping " .. bossName .. " because it is in the Night Market.")
        return false
    end

    -- Skip bosses in High Seas of Tamriel event
    if (GetZoneId(GetUnitZoneIndex("player")) == 1570) then
        KyzderpsDerps:dbg("Skipping " .. bossName .. " because it is in Voyage of the Abecean Sea.")
        return false
    end

    -- Check the data
    local groupName = BOSS_GROUPS[bossName] or bossName
    if (groupName == "GetPlayerLocationName") then
        groupName = GetPlayerLocationName()
    end
    return groupName
end


---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
--  EVENT_UNIT_DEATH_STATE_CHANGED (number eventCode, string unitTag, boolean isDead)
local function OnDeathStateChanged(_, unitTag, isDead)
    if (not isDead) then
        return
    end

    local groupName = IsBossByUnitTag(unitTag)
    if (groupName) then
        BossKilled(groupName, GetUnitName(unitTag))
    end
end

-- This seems to filter to killing blows, but only shows the string information for your own killing blows
-- EVENT_COMBAT_EVENT (number eventCode, number ActionResult result, boolean isError, string abilityName, number abilityGraphic, number ActionSlotType abilityActionSlotType, string sourceName, number CombatUnitType sourceType, string targetName, number CombatUnitType targetType, number hitValue, number CombatMechanicType powerType, number DamageType damageType, boolean log, number sourceUnitId, number targetUnitId, number abilityId, number overflow)
local function OnCombatXP(_, _, _, abilityName, _, _, sourceName, _, targetName, _, _, _, _, _, sourceUnitId, targetUnitId, abilityId, _)
    -- KyzderpsDerps:dbg(string.format("%s(%d) killed %s(%d) with %s", sourceName, sourceUnitId, targetName, targetUnitId, abilityName))
    if (targetName == "Trove Scamp" or targetName == "Cunning Scamp") then
        BossKilled("Sewers Scamp")
    end
end

-- EVENT_LOOT_RECEIVED (number eventCode, string receivedBy, string itemName, number quantity, ItemUISoundCategory soundCategory, LootItemType lootType, boolean self, boolean isPickpocketLoot, string questItemIcon, number itemId, boolean isStolen)
local function OnLootReceived(_, _, itemLink, _, _, lootType, isSelf)
    if (not isSelf) then return end
    if (lootType == LOOT_TYPE_ITEM) then
        local itemType = GetItemLinkItemType(itemLink)

        if (itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR) then
            if (GetItemLinkSetInfo(itemLink, false)) then
                -- This is a set item
                local groupName = IsBossByUnitTag("reticleover")
                if (groupName) then
                    local startTime
                    if (KyzderpsDerps.savedValues.spawnTimer.timers[groupName]) then
                        startTime = KyzderpsDerps.savedValues.spawnTimer.timers[groupName].startTime
                    end
                    if (not startTime or (GetTimeStamp() - startTime > 30)) then -- Only consider the loot reticle if it's not "new"
                        BossKilled(groupName)
                    end
                end
            end
        end
    end
end


---------------------------------------------------------------------------------------------------
-- Remove a timer line and remove it from the data
---------------------------------------------------------------------------------------------------
local function RemoveBoss(bossName)
    KyzderpsDerps:msg("You removed " .. bossName .. " from the boss timers.")
    KyzderpsDerps.savedValues.spawnTimer.timers[bossName] = nil
    PollTimer() -- Update it immediately
end
KyzderpsDerps.RemoveBoss = RemoveBoss


---------------------------------------------------------------------------------------------------
-- Fill the chat text field with the spawn timer for the clicked boss
---------------------------------------------------------------------------------------------------
local function PrintBoss(bossName)
    local respawnTime = 306 -- default of 5:06
    if (type(BOSS_NAMES[bossName]) == "number") then
        respawnTime = BOSS_NAMES[bossName]
    end

    local startTime = KyzderpsDerps.savedValues.spawnTimer.timers[bossName].startTime
    local seconds = respawnTime - GetTimeStamp() + startTime
    if (KEYBOARD_CHAT_SYSTEM) then
        KEYBOARD_CHAT_SYSTEM:StartTextEntry(bossName .. string.format(" should respawn in %d mins %d secs", zo_floor(seconds / 60), seconds % 60))
    end
end
KyzderpsDerps.PrintBoss = PrintBoss

---------------------------------------------------------------------------------------------------
-- Manually adding timer via command
---------------------------------------------------------------------------------------------------
local function ManualBossKilled(bossName)
    if (not bossName or bossName == "") then return end
    KyzderpsDerps:msg("Manually adding timer for \"" .. bossName .. "\"")
    -- Check the data
    local groupName = BOSS_GROUPS[bossName] or bossName
    if (groupName == "GetPlayerLocationName") then
        groupName = GetPlayerLocationName()
    end
    BossKilled(groupName, bossName)
end

-- TODO: timer doesn't persist across reloads, so this is bad for long timers that get cleaned up
local function CustomBossKilled(bossName, timer)
    if (timer) then
        BOSS_NAMES[bossName] = timer
    end
    BossKilled(bossName, bossName)
end
SpawnTimer.CustomBossKilled = CustomBossKilled

---------------------------------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------------------------------
function SpawnTimer.Initialize()
    KyzderpsDerps:dbg("    Initializing SpawnTimer module...")

    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpawnTimerDeath", EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathStateChanged)
    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpawnTimerDeathXP", EVENT_COMBAT_EVENT, OnCombatXP)
    EVENT_MANAGER:AddFilterForEvent(KyzderpsDerps.name .. "SpawnTimerDeathXP", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED_XP)
    EVENT_MANAGER:RegisterForEvent(KyzderpsDerps.name .. "SpawnTimerLootReceived", EVENT_LOOT_RECEIVED, OnLootReceived)

    -- Register timer update
    EVENT_MANAGER:RegisterForUpdate(KyzderpsDerps.name .. "SpawnTimerTimer", 900, PollTimer)
    KyzderpsDerps:dbg("Starting SpawnTimer polling")
    running = true

    -- Initialize position
    SpawnTimerContainer:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        KyzderpsDerps.savedValues.spawnTimer.x, KyzderpsDerps.savedValues.spawnTimer.y)
    SpawnTimerContainer:SetHidden(not KyzderpsDerps.savedOptions.spawnTimer.enable)

    -- Hide panel while in menus
    HUD_SCENE:RegisterCallback("StateChange", FragmentChange)
    HUD_UI_SCENE:RegisterCallback("StateChange", FragmentChange)

    SLASH_COMMANDS["/addtimer"] = ManualBossKilled
end


---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------
-- Returns a new array of just boss names, to be used in dropdown
local function GetBossNames()
    local newArray = {}

    if not KyzderpsDerps.savedOptions.spawnTimer.ignoreList then return newArray end

    for name, _ in pairs(KyzderpsDerps.savedOptions.spawnTimer.ignoreList) do
        table.insert(newArray, name)
    end

    return newArray
end

function SpawnTimer.GetSettings()
    return {
        {
            type = "description",
            title = nil,
            text = "Most world and public dungeon bosses respawn approximately 5:06 after they die. Delve bosses have the same base cooldown, but they respawn earlier if a player who has not completed it enters the delve area.",
            width = "full",
        },
        {
            type = "description",
            title = nil,
            text = "The death detection only works if the boss has a boss HP bar at the top of the screen, which includes all world bosses but not delve or public dungeon bosses except Summerset and newer. There is also currently only some detection of multi-bosses, so a single boss event with multiple boss enemies may display as separate timers.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Enable Boss List Panel",
            tooltip = "Display the timers on recently killed bosses",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.enable end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.spawnTimer.enable = value
                SpawnTimerContainer:SetHidden(not value)
            end,
            width = "full",
            reference = "KyzderpsDerps#SpawnTimerEnable"
        },
        {
            type = "checkbox",
            name = "Boss List Panel Background",
            tooltip = "Display a background for the panel",
            default = true,
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.background end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.spawnTimer.background = value
                SpawnTimerContainerBackdrop:SetHidden(not value)
            end,
            width = "full",
            disabled = function() return not KyzderpsDerps.savedOptions.spawnTimer.enable end,
        },
        {
            type = "checkbox",
            name = "Enable Respawn Alert",
            tooltip = "Display a center-screen announcement and notification sound when a boss is about to respawn",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.alert.enable end,
            setFunc = function(value) KyzderpsDerps.savedOptions.spawnTimer.alert.enable = value end,
            width = "full",
        },
        {
            type = "slider",
            name = "Alert Time",
            tooltip = "How many seconds before a boss is predicted to respawn should the alert be shown?",
            min = 0,
            max = 60,
            step = 1,
            default = 10,
            width = "full",
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.alert.seconds end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.spawnTimer.alert.seconds = value
            end,
            disabled = function() return not KyzderpsDerps.savedOptions.spawnTimer.alert.enable end,
        },
        {
            type = "checkbox",
            name = "Enable Chat Output",
            tooltip = "Display a message in chat when a boss dies",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.chat.enable end,
            setFunc = function(value) KyzderpsDerps.savedOptions.spawnTimer.chat.enable = value end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Chat Timestamp",
            tooltip = "Add a timestamp to the boss death chat message",
            default = false,
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.chat.timestamp end,
            setFunc = function(value) KyzderpsDerps.savedOptions.spawnTimer.chat.timestamp = value end,
            width = "full",
            disabled = function() return not KyzderpsDerps.savedOptions.spawnTimer.chat.enable end,
        },
        {
            type = "header",
            name = "Ignore Filter",
            width = "half",
        },
        {
            type = "editbox",
            name = "Add a Boss",
            width = "full",
            tooltip = "Enter the full Boss name exactly as it appears, case sensitive!",
            getFunc = function() return WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterBox").editbox:GetText() end,
            setFunc = function(name)
                if (name == "") then return end

                -- Clear the textbox
                WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterBox").editbox:SetText("")

                -- Add it to the dropdown
                local namesDropdown = WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterList")
                KyzderpsDerps.savedOptions.spawnTimer.ignoreList[name] = true
                namesDropdown:UpdateChoices(GetBossNames())
                namesDropdown.dropdown:SetSelectedItem(name)
            end,
            isMultiline = false,
            isExtraWide = false,
            reference = "KyzderpsDerps#IgnoreFilterBox",
        },
        {
            type = "dropdown",
            name = "Select Boss",
            width = "full",
            tooltip = "Choose a boss name to delete",
            choices = GetBossNames(),
            getFunc = function() return WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterList").combobox.m_comboBox:GetSelectedItem() end,
            setFunc = function(name) end,
            reference = "KyzderpsDerps#IgnoreFilterList",
        },
        {
            type = "button",
            name = "Remove",
            width = "full",
            func = function()
                local selectedName = WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterList").combobox.m_comboBox:GetSelectedItem()
                if (not selectedName or selectedName == "") then return end
                KyzderpsDerps.savedOptions.spawnTimer.ignoreList[selectedName] = nil
                local namesDropdown = WINDOW_MANAGER:GetControlByName("KyzderpsDerps#IgnoreFilterList")
                namesDropdown:UpdateChoices(GetBossNames())
            end,
        },
        {
            type = "header",
            name = "Imperial City Scamps",
            width = "half",
        },
        {
            type = "slider",
            name = "Respawn Time",
            tooltip = "How many seconds does it take for the Trove or Cunning Scamp to respawn? This value can be different depending on Imperial City events and location of the scamp, e.g. the EP location with 2 rooms spawns every 150s during the IC event.",
            min = 150,
            max = 900,
            step = 15,
            default = 150,
            width = "full",
            getFunc = function() return KyzderpsDerps.savedOptions.spawnTimer.scamp end,
            setFunc = function(value)
                KyzderpsDerps.savedOptions.spawnTimer.scamp = value
            end,
        },
    }
end
