-------------------------------------------------------------------------------
-- LibZoneTemp
-- Version: 2.3.18
--
-- A library that calculates ambient temperatures (in Celsius) for ESO zones.
--
-- CONFIRMED API USAGE:
--   ESO native:
--     GetZoneId(zoneIndex)               -> zoneId
--     GetZoneNameById(zoneId)            -> name
--     GetNumZones()                      -> numZones  (returns total zone count)
--     GetCurrentMapZoneIndex()           -> zoneIndex of the player's current map
--
--   LibZone:
--     LibZone:GetCurrentZoneIds()        -> currentZoneId, currentZoneParentId, ...
--     LibZone:GetCurrentZoneAndGroupStatus() -> zoneId, ..., isInDelve, isInDungeon, ...
--
--   LibClockTST:
--     LibClockTST:Instance()             -> singleton clock instance
--     clockInstance:GetTime()            -> { hour, minute, second }
--     clockInstance:RegisterForTime(addonId, callback) -> subscribe to time updates
--     clockInstance:CancelSubscriptionForTime(addonId) -> unsubscribe
--
--   LibAddonMenu-2.0:
--     LAM:RegisterAddonPanel(panelName, panelData)
--     LAM:RegisterOptionControls(panelName, optionsTable)
--
-- IMPORTANT NOTE ON WEATHER:
--   The ESO addon API does NOT expose any function to read the current client-side
--   weather state (rain, snow, clear, etc.). Weather is entirely client-side and
--   visual only; ZOS has not published a public Lua API for reading it.
--   LibZoneTemp therefore uses a STATIC weather probability table, derived from
--   known zone lore and climate descriptions, to estimate a weather modifier.
--   The modifier is NOT real-time. Users can override per-zone base temps via the
--   settings panel.
-------------------------------------------------------------------------------

local LIB_NAME    = "LibZoneTemp"
local LIB_VERSION = 22

-- Guard against loading an older version over a newer one.
if LibZoneTemp and LibZoneTemp.version >= LIB_VERSION then
    return
end

LibZoneTemp = LibZoneTemp or {}
local lib = LibZoneTemp
lib.version = LIB_VERSION

-------------------------------------------------------------------------------
-- CONSTANTS & INTERNAL STATE
-------------------------------------------------------------------------------

local ADDON_ID   = "LibZoneTemp"   -- Used as the LibClockTST subscription ID and LAM panel name

-- Default saved variables structure
local DEFAULTS = {
    useFahrenheit = false,
    zoneOverrides = {},   -- [zoneId (string key)] = number (Celsius override)
}

-- This is set once EVENT_ADD_ON_LOADED fires.
lib.savedVars = nil

-- Cache: current computed temperature
lib._currentTemp = nil
lib._currentZoneId = nil
lib._currentSpecificZoneId = nil

-------------------------------------------------------------------------------
-- ZONE CLIMATE DATA — keyed by real, language-independent zoneId
--
-- These three tables (ZONE_BASE_TEMPS, ZONE_WEATHER, ZONE_WATER_TEMPS) are
-- authored directly by zoneId (e.g. Wrothgar is 684, Shadowfen is 117) --
-- not by name, and not resolved from a name at load time. There is no
-- separate "runtime" table produced from a "source" table; what's below
-- IS what gets read at runtime.
--
-- VERIFICATION: every zoneId here was cross-checked against LibZone's own
-- public-domain zoneId/name data (https://github.com/Baertram/LibZone,
-- LibZone_Data.lua, the "en" table, dated 2026-06-08 / API101050) at
-- authoring time -- not fabricated, not guessed. The English name in the
-- trailing comment on each line is that authoring-time cross-check,
-- kept for human readability and future re-verification; it is never
-- read at runtime; only the zoneId key is used. Two names from the prior
-- name-keyed version didn't resolve against that data and are called out
-- where each table ends: "Morrowind" turned out to be a duplicate alias
-- of Vvardenfell's own zoneId (849), not a separate zone, and was dropped;
-- "Amenos" has no confirmed zoneId yet and is listed as pending rather
-- than guessed at -- it currently has no effect and falls back to
-- DEFAULT_TEMP / DEFAULT_WATER_TEMP like any other unlisted zone.
--
-- COVERAGE:
--   Every overland zone released up to and including the Necrom chapter (2023)
--   is listed.  Delves, group dungeons, and trials are not listed — they
--   inherit from their parent zone via currentZoneParentId (see
--   GetCurrentTemperature).  Any zone not found here falls back to
--   DEFAULT_TEMP / DEFAULT_WATER_TEMP.
-------------------------------------------------------------------------------

-- Base ambient air temperatures in Celsius.
local ZONE_BASE_TEMPS = {
    -- zoneId -> value, verified against LibZone's public-domain zone-name data
    -- (https://github.com/Baertram/LibZone, LibZone_Data.lua, "en" table,
    -- dated 2026-06-08 / API101050). Comment on each line is the English zone
    -- name at authoring time, for human readability only -- it is never read at
    -- runtime; only the zoneId key is used.
    [3] = 14, -- Glenumbra
    [11] = -4, -- Vaults of Madness
    [19] = 13, -- Stormhaven
    [20] = 4, -- Rivenspire
    [22] = 24, -- Volenfell
    [31] = 26, -- Selene's Web
    [38] = 21, -- Blackheart Haven
    [41] = 22, -- Stonefalls
    [57] = 18, -- Deshaan
    [58] = 26, -- Malabal Tor
    [63] = 20, -- Darkshade Caverns I
    [64] = 44, -- Blessed Crucible
    [92] = 26, -- Bangkorai
    [101] = -2, -- Eastmarch
    [103] = 4, -- The Rift
    [104] = 46, -- Alik'r Desert
    [108] = 24, -- Greenshade
    [117] = 30, -- Shadowfen
    [124] = 26, -- Root Sunder Ruins
    [126] = 24, -- Elden Hollow I
    [130] = 10, -- Crypt of Hearts I
    [131] = 26, -- Tempest Island
    [134] = -4, -- Sanguine's Demesne
    [137] = 24, -- Rulanyil's Fall
    [138] = 16, -- Crimson Cove
    [142] = 14, -- Bonesnap Ruins
    [144] = 12, -- Spindleclutch I
    [146] = 13, -- Wayrest Sewers I
    [148] = 26, -- Arx Corinium
    [159] = 14, -- Emeric's Dream
    [162] = 18, -- Obsidian Scar
    [166] = 12, -- Cath Bedraud
    [168] = 26, -- Bisnensel
    [169] = 14, -- Razak's Wheel
    [176] = 50, -- City of Ash I
    [181] = 17, -- Cyrodiil
    [187] = 30, -- Loriasel
    [188] = 20, -- The Apothecarium
    [189] = 25, -- Tribunal Temple
    [190] = 15, -- Reservoir of Souls
    [191] = 48, -- Ash Mountain
    [192] = 25, -- Virak Keep
    [193] = 52, -- Tormented Spire
    [199] = 16, -- The Harborage
    [200] = -6, -- The Foundry of Woe
    [201] = -4, -- Castle of the Worm
    [203] = -5, -- Cheesemonger's Hollow
    [207] = 35, -- Mzeneldt
    [208] = 46, -- The Earth Forge
    [209] = -3, -- Halls of Submission
    [212] = 22, -- Mournhold Sewers
    [213] = 27, -- Sunscale Ruins
    [214] = 15, -- Lair of the Skin Stealer
    [215] = 30, -- Vision of the Hist
    [216] = 10, -- Crow's Wood
    [217] = -3, -- The Halls of Torment
    [218] = 16, -- Circus of Cheerful Slaughter
    [219] = 10, -- Chateau of the Ravenous Rodent
    [222] = 8, -- Dresan Keep
    [223] = 12, -- Tomb of Lost Kings
    [224] = 8, -- Breagha-Fin
    [227] = 20, -- Sunken Road
    [228] = 22, -- Bangkorai Garrison
    [229] = 22, -- Nilata Ruins
    [231] = 20, -- Hall of Heroes
    [232] = 26, -- Silyanorn Ruins
    [233] = 30, -- Ruins of Ten-Maur-Wolk
    [234] = 28, -- Odious Chapel
    [235] = 22, -- Temple of Sul
    [236] = 16, -- White Rose Prison Dungeon
    [237] = 12, -- Impervious Vault
    [238] = 26, -- Salas En
    [239] = 28, -- Kulati Mines
    [241] = 20, -- House Indoril Crypt
    [242] = 28, -- Fort Arand Dungeons
    [243] = 22, -- Coral Heart Chamber
    [245] = 28, -- Heimlyn Keep Reliquary
    [246] = 24, -- Iliath Temple Mines
    [247] = 28, -- House Dres Crypts
    [248] = 25, -- Mzithumz
    [249] = 22, -- Tal'Deic Crypts
    [250] = 22, -- Narsis Ruins
    [252] = 11, -- The Hollow Cave
    [253] = 22, -- Shad Astula Underhalls
    [254] = 12, -- Deepcrag Den
    [255] = 20, -- Bthanual
    [256] = 12, -- Crosswych Mine
    [257] = 8, -- Vaults of Vernim
    [258] = 5, -- Arcwind Point
    [259] = 5, -- Trolhetta
    [260] = -2, -- Lost Knife Cave
    [261] = -8, -- Bonestrewn Barrow
    [262] = -1, -- Wittestadr Crypts
    [263] = 5, -- Mistwatch Crevasse
    [264] = -2, -- Fort Morvunskar
    [265] = -1, -- Mzulft
    [266] = -2, -- Cragwallow
    [267] = 15, -- Eyevea
    [268] = 11, -- Stormwarden Undercroft
    [269] = 26, -- Abamath Ruins
    [270] = 27, -- Shrine of the Black Maw
    [271] = 29, -- Broken Tusk
    [272] = 35, -- Atanaz Ruins
    [273] = 30, -- Chid-Moska Ruins
    [274] = 30, -- Onkobra Kwama Mine
    [275] = 26, -- Gandranen Ruins
    [280] = -8, -- Bleakrock Isle
    [281] = 20, -- Bal Foyen
    [283] = 24, -- Fungal Grotto I
    [284] = 12, -- Bad Man's Hallows
    [287] = 25, -- Inner Sea Armature
    [288] = 12, -- Mephala's Nest
    [289] = 28, -- Softloam Cavern
    [290] = 22, -- Hightide Hollow
    [291] = 16, -- Sheogorath's Tongue
    [296] = 38, -- Emberflint Mine
    [306] = 16, -- Forgotten Crypts
    [308] = 28, -- Lost City of the Na-Totambu
    [309] = 12, -- Ilessan Tower
    [310] = 12, -- Silumm
    [311] = 26, -- Mines of Khuras
    [312] = 4, -- Enduum
    [313] = 11, -- Ebon Crypt
    [314] = 5, -- Cryptwatch Fort
    [315] = 14, -- Portdun Watch
    [316] = 14, -- Koeglin Mine
    [317] = 10, -- Pariah Catacombs
    [318] = 14, -- Farangel's Delve
    [319] = 14, -- Bearclaw Mine
    [320] = 26, -- Norvulk Ruins
    [321] = 8, -- Crestshade Mine
    [322] = 6, -- Flyleaf Catacombs
    [323] = 8, -- Tribulation Crypt
    [324] = 8, -- Orc's Finger Ruins
    [325] = 8, -- Erokii Ruins
    [326] = 6, -- Hildune's Secret Refuge
    [327] = 38, -- Santaki
    [328] = 36, -- Divad's Chagrin Mine
    [329] = 38, -- Aldunz
    [330] = 28, -- Coldrock Diggings
    [331] = 40, -- Sandblown Mine
    [332] = 38, -- Yldzuun
    [333] = 40, -- Torog's Spite
    [334] = 6, -- Troll's Toothpick
    [335] = 26, -- Viridian Watch
    [336] = 20, -- Crypt of the Exiles
    [337] = 32, -- Klathzgar
    [338] = 35, -- Rubble Butte
    [339] = -1, -- Hall of the Dead
    [341] = 5, -- The Lion's Den
    [346] = 5, -- Skuldafn
    [347] = -8, -- Coldharbour
    [353] = 12, -- Hall of Trials
    [354] = -2, -- Cradlecrush Arena
    [359] = -6, -- The Chill Hollow
    [360] = -8, -- Icehammer's Vault
    [361] = 12, -- Old Sord's Cave
    [362] = -10, -- The Frigid Grotto
    [363] = -4, -- Stormcrag Crypt
    [364] = 15, -- The Bastard's Tomb
    [365] = 10, -- Library of Dusk
    [366] = 6, -- Lightless Oubliette
    [367] = 6, -- Lightless Cell
    [368] = 44, -- The Black Forge
    [369] = -3, -- The Vile Laboratory
    [370] = -5, -- Reaver Citadel Pyramid
    [371] = -6, -- The Mooring
    [372] = 18, -- Manor of Revelry
    [374] = -5, -- The Endless Stair
    [375] = 9, -- Chapel of Light
    [376] = 4, -- Grunda's Gatehouse
    [377] = 26, -- Dra'bul
    [378] = 4, -- Shrine of Mauloch
    [379] = 26, -- Silvenar's Audience Hall
    [380] = 22, -- The Banished Cells I
    [381] = 20, -- Auridon
    [382] = 36, -- Reaper's March
    [383] = 28, -- Grahtwood
    [385] = 12, -- Ragnthar
    [386] = 28, -- Fort Virak Ruin
    [387] = 26, -- Tower of the Vale
    [388] = 22, -- Phaer Catacombs
    [389] = 16, -- Reliquary Ruins
    [390] = 12, -- The Veiled Keep
    [392] = 12, -- The Vault of Exile
    [393] = 22, -- Saltspray Cave
    [394] = 22, -- Ezduiin Undercroft
    [395] = 42, -- The Refuge of Dread
    [396] = 16, -- Ondil
    [397] = 36, -- Del's Claim
    [398] = 16, -- Entila's Folly
    [399] = 16, -- Wansalen
    [400] = 48, -- Mehrunes' Spite
    [401] = 28, -- Bewan
    [402] = 4, -- Shor's Stone Mine
    [403] = 2, -- Northwind Mine
    [404] = 2, -- Fallowstone Vault
    [405] = 25, -- Lady Llarel's Shelter
    [406] = 25, -- Lower Bthanual
    [407] = 22, -- The Triple Circle Mine
    [408] = 22, -- Taleon's Crag
    [409] = 24, -- Knife Ear Grotto
    [410] = 22, -- The Corpse Garden
    [411] = 20, -- The Hunting Grounds
    [412] = 4, -- Nimalten Barrow
    [413] = 2, -- Avanchnzel
    [414] = 24, -- Pinepeak Caverns
    [415] = -1, -- Trolhetta Cave
    [416] = 22, -- Inner Tanzelwil
    [417] = -8, -- Aba-Loria
    [418] = 45, -- The Vault of Haman Forgefire
    [419] = -8, -- The Grotto of Depravity
    [420] = 12, -- Cave of Trophies
    [421] = 22, -- Mal Sorra's Tomb
    [422] = -8, -- The Wailing Maw
    [424] = 12, -- Camlorn Keep
    [425] = 12, -- Daggerfall Castle
    [426] = 12, -- Angof's Sanctum
    [429] = 12, -- Glenumbra Moors Cave
    [430] = 32, -- Aphren's Tomb
    [431] = 5, -- Taarengrav Barrow
    [433] = 16, -- Nairume's Prison
    [434] = 12, -- The Orrery
    [435] = 28, -- Cathedral of the Golden Path
    [436] = 15, -- Reliquary Vault
    [437] = 16, -- Laeloria Ruins
    [438] = 27, -- Cave of Broken Sails
    [439] = 26, -- Ossuary of Telacar
    [440] = 28, -- The Aquifer
    [442] = 16, -- Ne Salas
    [444] = 25, -- Burroot Kwama Mine
    [447] = 28, -- Mobar Mine
    [449] = -10, -- Direfrost Keep
    [451] = 28, -- Senalana
    [452] = 16, -- Temple to the Divines
    [453] = 28, -- Halls of Ichor
    [454] = 35, -- Do'Krin Temple
    [455] = 28, -- Rawl'kha Temple
    [456] = 32, -- Five Finger Dance
    [457] = 35, -- Moonmont Temple
    [458] = 28, -- Fort Sphinxmoth
    [459] = 28, -- Thizzrini Arena
    [460] = 33, -- The Demiplane of Jode
    [461] = 35, -- Den of Lorkhaj
    [462] = 28, -- Thibaut's Cairn
    [463] = 35, -- Kuna's Delve
    [464] = 15, -- Fardir's Folly
    [465] = 35, -- Claw's Strike
    [466] = 28, -- Weeping Wind Cave
    [467] = 35, -- Jode's Light
    [468] = 5, -- Dead Man's Drop
    [469] = 26, -- Tomb of Apostates
    [470] = 30, -- Hoarvor Pit
    [471] = 26, -- Shael Ruins
    [472] = 26, -- Roots of Silvenar
    [473] = 26, -- Black Vine Ruins
    [475] = 34, -- The Scuttle Pit
    [477] = 26, -- Vinedeath Cave
    [478] = 26, -- Wormroot Depths
    [480] = 24, -- Snapleg Cave
    [481] = 5, -- Fort Greenwall
    [482] = 5, -- Shroud Hearth Barrow
    [484] = 5, -- Faldar's Tooth
    [485] = 5, -- Broken Helm Hollow
    [486] = 18, -- Toothmaul Gully
    [487] = 20, -- The Vile Manse
    [492] = 54, -- Tormented Spire Summit
    [493] = 24, -- Breakneck Cave
    [494] = 14, -- Capstone Cave
    [495] = 16, -- Cracked Wood Cave
    [496] = 15, -- Echo Cave
    [497] = 35, -- Haynote Cave
    [498] = 15, -- Kingscrest Cavern
    [499] = 14, -- Lipsand Tarn
    [500] = 30, -- Muck Valley Cavern
    [501] = 30, -- Newt Cave
    [502] = 26, -- Nisin Cave
    [503] = 15, -- Pothole Caverns
    [504] = 14, -- Quickwater Cave
    [505] = 14, -- Red Ruby Cave
    [506] = 16, -- Serpent Hollow Cave
    [507] = 17, -- Bloodmayne Cave
    [508] = 25, -- Foyada Quarry
    [509] = 25, -- Ald Carac
    [510] = 16, -- Ularra
    [511] = 16, -- Arcane University
    [512] = 20, -- Deeping Drome
    [513] = -8, -- Mor Khazgur
    [514] = 18, -- Istirus Outpost
    [515] = 18, -- Istirus Outpost Arena
    [516] = 25, -- Ald Carac
    [517] = 22, -- Eld Angavar
    [518] = 22, -- Eld Angavar
    [520] = 16, -- Reman's Folly
    [525] = -5, -- Cheesemonger's Hollow
    [526] = 14, -- Greenhill Catacombs
    [527] = 14, -- Sancre Tor
    [529] = 15, -- Eyevea Mages Guild
    [530] = 30, -- Haj Uxith Corridors
    [531] = 2, -- Toadstool Hollow
    [532] = 16, -- Vahtacen
    [533] = 14, -- Underpall Cave
    [534] = 34, -- Stros M'Kai
    [535] = 15, -- Betnikh
    [537] = 30, -- Khenarthi's Roost
    [539] = 13, -- Carzog's Demise
    [541] = 16, -- Glade of the Divines
    [542] = 21, -- Buraniim
    [543] = 4, -- Dourstone Vault
    [544] = 28, -- Stonefang Cavern
    [545] = 14, -- Alcaire Keep
    [546] = 14, -- Wayrest Castle
    [547] = 26, -- Shrouded Hollow
    [548] = 22, -- Silatar
    [549] = 26, -- The Middens
    [551] = 14, -- Imperial Underground
    [552] = 22, -- Shademist Enclave
    [553] = 16, -- Ilmyris
    [554] = 22, -- Serpent's Grotto
    [555] = 22, -- Abecean Sea
    [556] = 22, -- Nereid Temple Cave
    [557] = -8, -- Village of the Lost
    [558] = 26, -- Hectahame Grotto
    [559] = 26, -- Valenheart
    [560] = 4, -- Nimalten Barrow
    [561] = -5, -- Isles of Torment
    [562] = 30, -- Khaj Rawlith
    [565] = 30, -- Ren-dro Caverns
    [566] = 12, -- Heart of the Wyrd Tree
    [567] = 20, -- The Hunting Grounds
    [569] = 36, -- Ash'abah Pass
    [570] = 36, -- Tu'whacca's Sanctum
    [571] = 24, -- Suturah's Crypt
    [572] = 16, -- Stirk
    [573] = 12, -- The Worm's Retreat
    [574] = 28, -- The Valley of Blades
    [575] = 24, -- Carac Dena
    [576] = 4, -- Gurzag's Mine
    [577] = 26, -- The Underroot
    [578] = 30, -- Naril Nagaia
    [579] = 24, -- Harridan's Lair
    [580] = 26, -- Barrow Trench
    [581] = -10, -- Heart's Grief
    [582] = 22, -- Temple of Auri-El
    [584] = 17, -- Imperial City
    [585] = 25, -- Nchu Duabthar Threshold
    [586] = -6, -- The Wailing Prison
    [587] = 6, -- Fevered Mews
    [588] = 8, -- Doomcrag
    [589] = 8, -- Northpoint
    [590] = 16, -- Edrald Undercroft
    [591] = 36, -- Lorkrata Ruins
    [592] = 8, -- Shadowfate Cavern
    [593] = 22, -- Bangkorai Garrison
    [594] = 26, -- The Far Shores
    [595] = 16, -- Abagarlas
    [596] = 8, -- Blood Matron's Crypt
    [598] = 20, -- The Colored Rooms
    [599] = 26, -- Elden Root
    [600] = 20, -- Mournhold
    [601] = 14, -- Wayrest
    [628] = 8, -- Doomcrag
    [632] = 36, -- Skyreach Hold
    [635] = 24, -- Dragonstar Arena
    [636] = 26, -- Hel Ra Citadel
    [637] = 30, -- Quarantine Serk Catacombs
    [638] = 22, -- Aetherian Archive
    [639] = 28, -- Sanctum Ophidia
    [640] = 10, -- Godrun's Dream
    [641] = 15, -- Themond Mine
    [642] = 46, -- The Earth Forge
    [643] = 15, -- Imperial Sewers
    [649] = 35, -- The Dragonfire Cathedral
    [676] = 22, -- Shark's Teeth Grotto
    [677] = 20, -- Maelstrom Arena
    [678] = 15, -- Imperial City Prison
    [681] = 55, -- City of Ash II
    [684] = -8, -- Wrothgar
    [688] = 17, -- White-Gold Tower
    [689] = -5, -- Nikolvara's Kennel
    [691] = 4, -- Thukhozod's Sanctum
    [692] = 4, -- Watcher's Hold
    [693] = -6, -- Coldperch Cavern
    [694] = 4, -- Argent Mine
    [695] = -8, -- Coldwind's Den
    [697] = 4, -- Zthenganaz
    [698] = -8, -- Morkul Descent
    [699] = 15, -- Honor's Rest
    [700] = -8, -- Exile's Barrow
    [701] = 15, -- Graystone Quarry Depths
    [702] = -12, -- Frostbreak Fortress
    [703] = -4, -- Paragon's Remembrance
    [704] = 3, -- Bonerock Cavern
    [705] = -5, -- Rkindaleft
    [706] = -6, -- Old Orsinium
    [707] = -14, -- Ice-Heart's Lair
    [708] = 15, -- Temple Library
    [710] = -8, -- Fharun Prison
    [711] = 15, -- Temple Rectory
    [712] = 5, -- Chambers of Loyalty
    [715] = 15, -- Sanctum of Prowess
    [719] = 18, -- Time-Lost Throne Room
    [723] = -10, -- Heart's Grief
    [724] = 16, -- Sorrow
    [725] = 35, -- Maw of Lorkhaj
    [726] = 34, -- Murkmire
    [745] = 40, -- Charred Ridge
    [746] = 22, -- Vulkhel Guard Outlaws Refuge
    [747] = 26, -- Elden Root Outlaws Refuge
    [748] = 26, -- Marbruk Outlaws Refuge
    [749] = 26, -- Velyn Harbor Outlaws Refuge
    [750] = 28, -- Rawl'kha Outlaws Refuge
    [751] = 28, -- Belkarth Outlaws Refuge
    [752] = 14, -- Wayrest Outlaws Refuge
    [753] = 12, -- Daggerfall Outlaws Refuge
    [754] = 22, -- Evermore Outlaws Refuge
    [755] = 8, -- Shornhelm Outlaws Refuge
    [756] = 26, -- Sentinel Outlaws Refuge
    [757] = 28, -- Davon's Watch Outlaws Refuge
    [758] = 1, -- Windhelm Outlaws Refuge
    [759] = 30, -- Stormhold Outlaws Refuge
    [760] = 22, -- Mournhold Outlaws Refuge
    [761] = 5, -- Riften Outlaws Refuge
    [763] = 14, -- Secluded Sewers
    [764] = 14, -- Underground Sepulcher
    [765] = 11, -- Smuggler's Den
    [766] = 20, -- Trader's Cove
    [767] = 15, -- Deadhollow Halls
    [769] = 14, -- Sewer Tenement
    [770] = 15, -- The Hideaway
    [771] = 12, -- Glittering Grotto
    [773] = 30, -- Cold-Blood Cavern
    [774] = 33, -- Sugar-Slinger's Den
    [780] = -3, -- Orsinium Outlaws Refuge
    [808] = -8, -- Dragon Bridge Smuggler Caves
    [809] = -6, -- The Wailing Prison
    [810] = 11, -- Smuggler's Tunnel
    [811] = 12, -- Ancient Carzog's Demise
    [814] = 28, -- Temple of Ire
    [815] = 36, -- Scarp Keep
    [816] = 36, -- Hew's Bane
    [817] = 32, -- Bahraha's Gloom
    [818] = 32, -- Iron Wheel Headquarters
    [819] = 32, -- Al-Danobia Tomb
    [820] = 32, -- Hubalajad Palace
    [821] = 12, -- Thieves Den
    [823] = 22, -- Gold Coast
    [824] = 20, -- Hrota Cave
    [825] = 20, -- Garlas Agea
    [826] = 16, -- Dark Brotherhood Sanctuary
    [827] = 20, -- Jarol Estate
    [828] = 18, -- At-Himah Estate
    [829] = 19, -- Knightsgrave
    [831] = 16, -- Anvil Castle
    [832] = 16, -- Castle Kvatch
    [833] = 12, -- Enclave of the Hourglass
    [834] = 22, -- Fulstrom Homestead
    [836] = 16, -- Cathedral of Akatosh
    [837] = 16, -- Anvil Outlaws Refuge
    [841] = 5, -- Jerall Mountains Logging Track
    [842] = 30, -- Blackwood Borderlands
    [843] = 28, -- Ruins of Mazzatun
    [844] = 22, -- Sulima Mansion
    [845] = 16, -- Velmont Mansion
    [848] = 28, -- Cradle of Shadows
    [849] = 38, -- Vvardenfell
    [852] = 13, -- Captain Margaux's Place
    [853] = 8, -- Ravenhurst
    [854] = 24, -- Mournoth Keep
    [855] = 20, -- Hammerdeath Bungalow
    [856] = 22, -- Twin Arches
    [857] = 32, -- House of the Silent Magnifico
    [858] = 23, -- Cliffshade
    [859] = 26, -- Black Vine Villa
    [860] = 26, -- Snugpod
    [861] = 25, -- Bouldertree Refuge
    [862] = 28, -- Sleek Creek House
    [863] = 35, -- Moonmirth House
    [864] = 5, -- Autumn's-Gate
    [865] = -8, -- Grymharth's Woe
    [866] = 20, -- Velothi Reverie
    [867] = 30, -- Kragenhome
    [868] = 30, -- Humblemud
    [869] = 20, -- The Ample Domicile
    [870] = 30, -- Domus Phrasticus
    [871] = 26, -- Cyrodilic Jungle House
    [872] = 28, -- Strident Springs Demesne
    [873] = 27, -- Stay-Moist Mansion
    [874] = 26, -- Quondam Indorilia
    [875] = 5, -- Old Mistveil Manor
    [876] = 34, -- Dawnshadow
    [877] = 26, -- The Gorinir Estate
    [878] = 22, -- Mathiisen Manor
    [879] = 36, -- Hunding's Palatial Hall
    [880] = 24, -- Forsaken Stronghold
    [881] = 15, -- Gardner House
    [882] = 35, -- Grand Topal Hideaway
    [883] = 25, -- Earthtear Cavern
    [888] = 24, -- Craglorn
    [889] = 30, -- Molavar
    [890] = 36, -- Rkundzelft
    [891] = 36, -- Serpent's Nest
    [892] = 24, -- Ilthag's Undertower
    [893] = 28, -- Ruins of Kardala
    [894] = 28, -- Loth'Na Caverns
    [895] = 36, -- Rkhardahrk
    [896] = 20, -- Haddock's Market
    [897] = 30, -- Chiselshriek Mine
    [898] = 35, -- Buried Sands
    [899] = 22, -- Mtharnaz
    [900] = 36, -- The Howling Sepulchers
    [901] = 28, -- Balamath
    [902] = 35, -- Fearfangs Cavern
    [903] = 8, -- Exarch's Stronghold
    [904] = 36, -- Zalgaz's Den
    [905] = 26, -- Tombs of the Na-Totambu
    [906] = 24, -- Hircine's Haunt
    [907] = 30, -- Rahni'Za, School of Warriors
    [908] = 36, -- Shada's Tear
    [909] = 12, -- Seeker's Archive
    [910] = 26, -- Elinhir Sewerworks
    [911] = 14, -- Reinhold's Retreat
    [913] = 20, -- The Mage's Staff
    [914] = 26, -- Skyreach Catacombs
    [915] = 26, -- Skyreach Temple
    [916] = 32, -- Skyreach Pinnacle
    [918] = 30, -- Nchuleftingth
    [919] = 34, -- Forgotten Wastes
    [920] = 32, -- Inanius Egg Mine
    [921] = 30, -- Khartag Point
    [922] = 32, -- Zainsipilu
    [923] = 32, -- Matus-Akin Egg Mine
    [924] = 30, -- Pulk
    [925] = 30, -- Nchuleft
    [926] = 22, -- Pinsun
    [927] = 32, -- Vassir-Didanat Mine
    [928] = 32, -- Zalkin-Sul Egg Mine
    [929] = 32, -- Gnisis Egg Mine
    [930] = 22, -- Darkshade Caverns II
    [931] = 24, -- Elden Hollow II
    [932] = 10, -- Crypt of Hearts II
    [933] = 13, -- Wayrest Sewers II
    [934] = 24, -- Fungal Grotto II
    [935] = 22, -- The Banished Cells II
    [936] = 12, -- Spindleclutch II
    [937] = 22, -- Flaming Nix Deluxe Garret
    [938] = 36, -- Sisters of the Sands Apartment
    [939] = 20, -- Barbed Hook Private Room
    [940] = 20, -- Mara's Kiss Public House
    [941] = 28, -- The Ebony Flask Inn Room
    [942] = 15, -- The Rosy Lion
    [943] = 12, -- Daggerfall Overlook
    [944] = 15, -- Serenity Falls Estate
    [945] = 28, -- Ebonheart Chateau
    [946] = 36, -- Bal Ur
    [947] = 34, -- Ramimilk
    [948] = 32, -- Tusenend
    [949] = 34, -- Dreudurai Glass Mine
    [950] = 32, -- Zaintiraris
    [951] = 32, -- Vassamsi Mine
    [952] = 32, -- Shulk Ore Mine
    [953] = 30, -- Arkngthunch-Sturdumz
    [954] = 30, -- Galom Daeus
    [955] = 30, -- Mallapi Cave
    [956] = 30, -- Kaushtarari
    [957] = 25, -- Dreloth Ancestral Tomb
    [958] = 25, -- Veloth Ancestral Tomb
    [959] = 25, -- Andrano Ancestral Tomb
    [960] = 28, -- Hleran Ancestral Tomb
    [961] = 42, -- Ashalmawia
    [962] = 26, -- Library of Andule
    [963] = 28, -- Barilzar's Tower
    [964] = 36, -- Ashimanu Cave
    [965] = 25, -- Skar
    [966] = 28, -- Cavern of the Incarnate
    [967] = 12, -- Clockwork City Vault
    [968] = 34, -- Firemoth Island
    [969] = 40, -- Ashurnibibi
    [970] = 25, -- Redoran Garrison
    [971] = 25, -- Vivec City Outlaws Refuge
    [972] = 25, -- Kudanat Mine
    [973] = 48, -- Bloodroot Forge
    [974] = 5, -- Falkreath Hold
    [975] = 24, -- Halls of Fabrication
    [977] = -8, -- Prison of Xykenaz
    [979] = 12, -- Clockwork City Vault
    [980] = 20, -- Clockwork City
    [981] = 20, -- The Brass Fortress
    [982] = 22, -- Slag Town Outlaws Refuge
    [983] = 22, -- Mechanical Fundament
    [984] = 21, -- Machine District
    [985] = 20, -- Halls of Regulation
    [986] = 18, -- The Shadow Cleft
    [988] = 12, -- Clockwork City Vaults
    [989] = 21, -- Ventral Terminus
    [990] = 20, -- Incarnatorium
    [991] = 20, -- Cogitum Centralis
    [992] = 20, -- Everwound Wellspring
    [993] = 18, -- Mnemonic Planisphere
    [994] = 25, -- Saint Delyn Penthouse
    [995] = 25, -- Amaya Lake Lodge
    [996] = 25, -- Tel Galen
    [997] = 25, -- Ald Velothi Harbor House
    [998] = 26, -- Dranil Kir
    [999] = -5, -- Evergloam
    [1000] = 20, -- Asylum Sanctorium
    [1004] = 11, -- The Serviflume
    [1005] = 14, -- Linchal Grand Manor
    [1006] = 8, -- Exorcised Coven Cottage
    [1007] = 20, -- Hakkvild's High Hall
    [1008] = -8, -- Coldharbour Surreal Estate
    [1009] = 30, -- Fang Lair
    [1010] = -6, -- Scalecaller Peak
    [1011] = 18, -- Summerset
    [1012] = 10, -- The Spiral Skein
    [1013] = 32, -- Eldbur Sanctuary
    [1014] = 15, -- Tor-Hame-Khard
    [1015] = 12, -- Eton Nir Grotto
    [1016] = 15, -- Traitor's Vault
    [1017] = 19, -- Archon's Grove
    [1018] = 14, -- King's Haven Pass
    [1019] = 18, -- Wasten Coraldale
    [1020] = 16, -- Karnwasten
    [1021] = 22, -- Sunhold
    [1022] = 18, -- Direnni Acropolis
    [1023] = 22, -- Shimmerene Waterworks
    [1024] = 17, -- Eldbur Ruins
    [1025] = 15, -- Cey-Tarn Keep
    [1026] = 14, -- The Vaults of Heinarwe
    [1027] = 15, -- Artaeum
    [1028] = 22, -- Alinor Outlaws Refuge
    [1029] = 12, -- Ebon Sanctum
    [1030] = 17, -- Corgrad Wastes
    [1031] = 22, -- Illumination Academy Stacks
    [1032] = 16, -- Sea Keep
    [1033] = 20, -- Red Temple Catacombs
    [1034] = 18, -- College of Sapiarchs
    [1035] = 10, -- The Spiral Skein
    [1036] = 20, -- Cathedral of Webs
    [1037] = 16, -- The Crystal Tower
    [1038] = 15, -- Rellenthil Sinkhole
    [1039] = 15, -- Psijic Relic Vaults
    [1040] = -5, -- Evergloam
    [1042] = 4, -- Pariah's Pinnacle
    [1043] = 12, -- The Orbservatory Prior
    [1044] = 12, -- The Erstwhile Sanctuary
    [1045] = 32, -- Princely Dawnlight Palace
    [1046] = 22, -- Saltbreeze Cave
    [1047] = 22, -- Monastery of Serene Harmony
    [1048] = 22, -- Alinor Royal Palace
    [1051] = 14, -- Cloudrest
    [1052] = 28, -- Moon Hunter Keep
    [1055] = -2, -- March of Sacrifices
    [1059] = 14, -- Golden Gryphon Garret
    [1060] = 22, -- Alinor Crest Townhouse
    [1061] = 22, -- Colossal Aldmeri Grotto
    [1063] = 22, -- Grand Psijic Villa
    [1064] = 15, -- Hunter's Glade
    [1065] = 30, -- Blight Bog Sump
    [1066] = 30, -- Tsofeer Cavern
    [1067] = 12, -- The Dreaming Nest
    [1068] = 30, -- Ixtaxh Xanmeer
    [1069] = 30, -- Tomb of Many Spears
    [1070] = 30, -- Lilmoth Outlaws Refuge
    [1071] = 28, -- Xul-Thuxis
    [1072] = 30, -- Norg-Tzel
    [1073] = 32, -- Teeth of Sithis
    [1074] = 15, -- The Sunless Hollow
    [1075] = 15, -- The Sunless Hollow
    [1076] = 15, -- The Sunless Hollow
    [1077] = 30, -- The Swallowed Grove
    [1078] = 28, -- Remnant of Argon
    [1079] = 30, -- Vakka-Bok Xanmeer
    [1080] = -14, -- Frostvault
    [1081] = 16, -- Depths of Malatar
    [1082] = 30, -- Blackrose Prison
    [1083] = 30, -- Deep-Root
    [1085] = 22, -- Halls of Colossus
    [1086] = 40, -- Northern Elsweyr
    [1088] = 26, -- Rimmen Outlaws Refuge
    [1089] = 26, -- Rimmen Necropolis
    [1090] = 35, -- Orcrest
    [1091] = 28, -- Abode of Ignominy
    [1092] = 28, -- Predator Mesa
    [1094] = 33, -- Tomb of the Serpents
    [1095] = 32, -- Darkpool Mine
    [1096] = 33, -- The Tangle
    [1097] = 33, -- Sleepy Senche Mine
    [1098] = 35, -- Riverhold
    [1099] = 28, -- Rimmen Palace
    [1101] = 24, -- Rimmen Palace Recesses
    [1102] = 12, -- Sepulcher of Mischance
    [1103] = 35, -- Moon Gate of Anequina
    [1105] = 33, -- Skooma Cat's Cloister
    [1106] = 35, -- Star Haven Adeptorium
    [1108] = 30, -- Lakemire Xanmeer Manor
    [1109] = 6, -- Enchanted Snow Globe Home
    [1110] = 5, -- Dov-Vahl Shrine
    [1111] = 26, -- Cicatrice Caverns
    [1112] = 33, -- Tenarr Zalviit Ossuary
    [1113] = 28, -- Hidden Moon Crypts
    [1114] = 35, -- Hakoshae Tombs
    [1115] = 35, -- Merryvale Sugar Farm Caves
    [1116] = 35, -- Moon Gate
    [1117] = 33, -- Shadow Dance Temple
    [1118] = 15, -- Vault of the Heavenly Scourge
    [1119] = 28, -- Desert Wind Caverns
    [1120] = 16, -- Meirvale Keep
    [1121] = 42, -- Sunspire
    [1122] = 28, -- Moongrave Fane
    [1123] = 24, -- Lair of Maarselok
    [1125] = -12, -- Frostvault Chasm
    [1126] = 30, -- Elinhir Private Arena
    [1128] = 33, -- Sugar Bowl Suite
    [1129] = 35, -- Hall of the Lunar Champion
    [1130] = 35, -- Jode's Embrace
    [1133] = 32, -- Southern Elsweyr
    [1134] = 28, -- Forsaken Citadel
    [1135] = 22, -- Moonlit Cove
    [1136] = 28, -- Zazaradi's Quarry and Mine
    [1137] = 35, -- Path of Pride
    [1138] = 46, -- Dragonhold
    [1139] = 22, -- Senchal Outlaws Refuge
    [1140] = 28, -- Wind Scour Temple
    [1141] = 30, -- Dark Water Temple
    [1142] = 28, -- The Valley of Blades
    [1143] = 5, -- Storm Talon Temple
    [1144] = 28, -- Vahlokzin's Lair
    [1145] = 30, -- Passage of Dad'na Ghaten
    [1146] = 28, -- Tideholm
    [1147] = 35, -- New Moon Fortress
    [1148] = 22, -- Halls of the Highmane
    [1149] = 28, -- Doomstone Keep
    [1150] = 28, -- Doomstone Caverns
    [1151] = 44, -- Dragonhold Ruins
    [1152] = -16, -- Icereach
    [1153] = 14, -- Unhallowed Grave
    [1154] = 35, -- Moon-Sugar Meadow
    [1155] = 8, -- Wraithhome
    [1160] = -10, -- Western Skyrim
    [1161] = -6, -- Blackreach: Greymoor Caverns
    [1165] = -4, -- The Scraps
    [1166] = -8, -- Chillwind Depths
    [1167] = -5, -- Dragonhome
    [1168] = -12, -- Frozen Coast
    [1169] = -6, -- Midnight Barrow
    [1170] = -3, -- Shadowgreen
    [1172] = -8, -- Greymoor Keep
    [1173] = -9, -- Greymoor Keep: West Wing
    [1174] = 4, -- Verglas Hollow
    [1176] = -2, -- Kilkreath Temple
    [1177] = -8, -- Bleakridge Barrow
    [1178] = 4, -- Solitude Outlaws Refuge
    [1179] = -8, -- Mor Khazgur Mine
    [1180] = 16, -- Imperial Cache Annex
    [1181] = -6, -- Kagnthamz
    [1182] = -2, -- Morthal Barrow
    [1183] = -4, -- Tzinghalis's Tower
    [1184] = 2, -- Castle Dour
    [1185] = 26, -- Deepwood Vale
    [1186] = -6, -- Labyrinthian
    [1187] = -5, -- Nchuthnkarst
    [1188] = 2, -- Palace of Kings
    [1189] = 2, -- Palace of Kings
    [1190] = 5, -- Riften Ratway
    [1191] = -7, -- Blackreach
    [1192] = 28, -- Lucky Cat Landing
    [1193] = 16, -- Potentate's Retreat
    [1195] = 15, -- The Undergrove
    [1196] = -12, -- Kyne's Aegis
    [1197] = -8, -- Stone Garden
    [1199] = 36, -- Forgemaster Falls
    [1200] = 36, -- Thieves' Oasis
    [1201] = -6, -- Castle Thorn
    [1205] = 6, -- Grayhome
    [1206] = 6, -- Grayhome Ritual Chamber
    [1207] = -3, -- The Reach
    [1208] = -5, -- Blackreach: Arkthzand Cavern
    [1209] = -6, -- Gloomreach
    [1210] = 2, -- Briar Rock Ruins
    [1211] = 5, -- Markarth Outlaws Refuge
    [1212] = -5, -- Arkthzand Research Wing
    [1213] = -3, -- Sanuarach Mine
    [1214] = -4, -- Bthar-Zel
    [1215] = -5, -- Bthar-Zel Vaults
    [1216] = -6, -- The Dark Descent
    [1217] = -5, -- The Arkthzand Orrery
    [1218] = 8, -- Snowmelt Suite
    [1219] = 4, -- Proudspire Manor
    [1220] = 4, -- Bastion Sanguinaris
    [1221] = 15, -- Grayhaven
    [1222] = -4, -- Valthume
    [1223] = -5, -- Lost Valley Redoubt
    [1224] = -4, -- Nighthollow Keep
    [1225] = -3, -- Nchuand-Zel
    [1226] = -5, -- Reachwind Depths
    [1227] = 6, -- Vateshran Hollows
    [1228] = 16, -- Black Drake Villa
    [1229] = 44, -- The Cauldron
    [1233] = 4, -- Antiquarian's Alpine Gallery
    [1234] = 4, -- Stillwaters Retreat
    [1235] = 16, -- Ne Salas Cache Annex
    [1236] = 15, -- Imperial Sewers
    [1237] = 52, -- The Deadlands: Testing Grounds
    [1238] = 24, -- Tidewater Cave
    [1239] = 24, -- Welke
    [1240] = 30, -- Leyawiin Castle
    [1241] = 32, -- Doomvault Capraxus
    [1242] = 50, -- Vandacia's Deadlands Keep
    [1243] = 30, -- Fort Redmane
    [1244] = 15, -- Isle of Balfiera
    [1245] = 23, -- Borderwatch Ruins
    [1246] = 24, -- Deepscorn Hollow
    [1247] = 16, -- Veyond
    [1248] = 32, -- Doomvault Vulpinaz
    [1249] = 8, -- Twyllbek Ruins
    [1250] = 26, -- Glenbridge Xanmeer
    [1251] = 15, -- Xynaa's Sanctuary
    [1252] = 16, -- Leyawiin Outlaws Refuge
    [1253] = 22, -- Undertow Cavern
    [1254] = 16, -- Arpenia
    [1255] = 25, -- Bloodrun Cave
    [1256] = 32, -- Doomvault Porcixid
    [1257] = 26, -- Xi-Tsei
    [1258] = 26, -- Vunalk
    [1259] = 16, -- Zenithar's Abbey
    [1260] = 18, -- The Silent Halls
    [1261] = 28, -- Blackwood
    [1262] = 20, -- Festival Arena
    [1263] = 26, -- Rockgrove
    [1264] = 3, -- Stone Eagle Aerie
    [1265] = 4, -- Shalidor's Shrouded Realm
    [1266] = 30, -- Xal Irasotl
    [1267] = 18, -- Red Petal Bastion
    [1268] = 12, -- The Dread Cellar
    [1270] = 36, -- Kushalit Sanctuary
    [1271] = 26, -- Varlaisvea Ayleid Ruins
    [1272] = 42, -- Atoll of Immolation
    [1274] = 12, -- Garden of Shadows
    [1275] = 15, -- Pilgrim's Rest
    [1276] = 16, -- Water's Edge
    [1277] = 18, -- Pantherfang Chapel
    [1278] = 20, -- Lyranth's Hidden Lair
    [1279] = 40, -- Waking Flame Camp
    [1280] = 42, -- Waking Flame Fargrave Conclave
    [1281] = 42, -- Waking Flame Fargrave Conclave
    [1282] = 38, -- Fargrave
    [1283] = 28, -- The Shambles
    [1284] = 20, -- The Collector's Villa
    [1285] = 52, -- Burning Gyre Keep
    [1286] = 54, -- The Deadlands
    [1287] = 50, -- Wretched Spire
    [1289] = 22, -- Fort Grief Citadel
    [1290] = -8, -- Deadlight
    [1291] = 42, -- Ardent Hope
    [1292] = 53, -- The Path of Cinders
    [1293] = 42, -- Fargrave Outlaws Refuge
    [1294] = 16, -- Isle of Joys
    [1295] = 50, -- Destruction's Solace
    [1296] = 16, -- Fort Sundercliff
    [1297] = 50, -- The Brandfire Reformatory
    [1298] = 12, -- False Martyrs' Folly
    [1300] = 22, -- Fort Grief
    [1301] = 17, -- Coral Aerie
    [1302] = 16, -- Shipwright's Regret
    [1304] = 20, -- The Bathhouse
    [1306] = 48, -- Doomchar Plateau
    [1307] = 15, -- Sweetwater Cascades
    [1310] = 42, -- Atoll of Immolation
    [1311] = 15, -- Ascendant Order Hideout
    [1312] = 26, -- Sareloth Grotto
    [1313] = 15, -- Systres Sisters Vault
    [1314] = 15, -- Sword's Rest Isle
    [1315] = 15, -- Abhain Chapel Crypts
    [1316] = 24, -- Old Coin Fort
    [1317] = 20, -- All Flags Islet
    [1318] = 18, -- High Isle
    [1319] = 15, -- Gonfalon Bay Outlaws Refuge
    [1320] = 16, -- Tarnished Grotto
    [1321] = 15, -- Navire Dungeons
    [1322] = 15, -- Mistmouth Cave
    [1324] = 17, -- Steadfast Manor
    [1325] = 32, -- Loom of the Untraveled Road
    [1326] = 16, -- Castle Navire
    [1327] = 15, -- The Undergrove
    [1328] = 14, -- Garick's Rest
    [1329] = 16, -- Castle Navire
    [1330] = 23, -- Brokerock Mine
    [1331] = 5, -- Death's Valor Keep
    [1332] = 32, -- The Firepot
    [1333] = 16, -- Breakwater Cave
    [1334] = 16, -- Whalefall
    [1335] = 15, -- Shipwreck Shoals
    [1336] = 25, -- Coral Cliffs
    [1337] = 15, -- Spire of the Crimson Coin
    [1338] = 24, -- Ghost Haven Bay
    [1342] = 28, -- Ossa Accentium
    [1343] = 42, -- Agony's Ascent
    [1344] = 17, -- Dreadsail Reef
    [1345] = 16, -- Seaveil Spire
    [1360] = 14, -- Earthen Root Enclave
    [1361] = 12, -- Graven Deep
    [1363] = 17, -- Highhallow Hold
    [1364] = 18, -- Ancient Anchor Berth
    [1365] = 12, -- Eimhir's Cavern
    [1366] = 12, -- Glenmoril Ritual Site
    [1367] = 15, -- Vastyr Outlaws Refuge
    [1368] = 26, -- Y'ffre's Path
    [1369] = 12, -- Dreadsail Sea Witch Sanctum
    [1370] = 15, -- Castle Tonnere
    [1371] = 15, -- Vastyr Cathedral District
    [1372] = 18, -- Temple of Y'ffelon
    [1373] = 36, -- Mount Firesong
    [1374] = 26, -- Fauns' Thicket
    [1375] = 32, -- Embervine
    [1376] = 22, -- Suncleft Grotto
    [1377] = 14, -- Clohaigh
    [1378] = 16, -- Steadfast Manor Cellars
    [1379] = 15, -- The Mad Maiden
    [1380] = 14, -- Garick's Rest Dungeons
    [1381] = 26, -- Y'ffre's Path Ruins
    [1382] = 17, -- All Flags Castle
    [1383] = 15, -- Galen
    [1385] = 15, -- Draoife Dell
    [1386] = 18, -- Temple of Y'ffelon
    [1387] = 15, -- Ivyhame
    [1389] = 24, -- Bal Sunnar
    [1390] = 20, -- Scrivener's Hall
    [1391] = 26, -- Emerald Glyphic Vault
    [1392] = 15, -- Shrine of the Golden Eye
    [1393] = 12, -- The Tranquil Catalog
    [1394] = 12, -- The Infinite Panopticon
    [1395] = 12, -- The Infinite Panopticon
    [1396] = 24, -- Anchre Egg Mine
    [1397] = 22, -- Camonnaruhn
    [1398] = 20, -- Quires Wind
    [1399] = 20, -- The Disquiet Study
    [1400] = 18, -- Fathoms Drift
    [1401] = 30, -- Apogee of the Tormenting Eye
    [1402] = 20, -- Necrom Necropolis
    [1403] = 22, -- Tel Rendys
    [1404] = 20, -- Tel Baro Cavern
    [1405] = 20, -- Tel Huulen Assembly Hall
    [1406] = 12, -- Shrine of Vaermina
    [1407] = 25, -- Tel Dreloth
    [1408] = 24, -- Kemel-Ze
    [1409] = 12, -- The Sidereal Cloisters
    [1410] = 6, -- Cenotaph of the Remnants
    [1411] = 15, -- The Rectory Corporea
    [1412] = 20, -- Necrom Outlaws Refuge
    [1413] = 20, -- Apocrypha
    [1414] = 22, -- Telvanni Peninsula
    [1415] = 22, -- Gorne
    [1416] = 12, -- The Underweave
    [1417] = 12, -- The Mythos
    [1420] = 20, -- Bastion Nymic
    [1421] = 20, -- The Forbidden Exhibit
    [1422] = 20, -- Sailenmora Crypts
    [1423] = 25, -- Old Sailenmora Outpost
    [1424] = 20, -- Obscured Forum
    [1425] = 24, -- Alavelis Glass Mine
    [1427] = 20, -- Sanity's Edge
    [1429] = 16, -- The Harborage
    [1432] = 16, -- Fogbreak Lighthouse
    [1433] = 21, -- Journey's End Lodgings
    [1434] = 20, -- Emissary's Enclave
    [1435] = 22, -- The Fair Winds
    [1436] = 20, -- Infinite Archive
    [1437] = 12, -- Shadow Queen's Labyrinth
    [1438] = 36, -- Sword-Singer's Redoubt
    [1439] = 12, -- Shrine of Inevitable Secrets
    [1440] = 15, -- Miscarcand
    [1441] = 32, -- Loom of the Untraveled Road
    [1442] = 18, -- Hoperoot
    [1443] = 19, -- West Weald
    [1444] = 16, -- Legion's Rest
    [1445] = 18, -- Fyrelight Cave
    [1446] = 16, -- Nonungalo
    [1447] = 18, -- Fort Colovia
    [1448] = 14, -- Haldain Lumber Camp
    [1449] = 16, -- Varen's Watch
    [1450] = 12, -- Rustwall Catacombs
    [1451] = 16, -- Elenglynn
    [1452] = 16, -- Essondul
    [1453] = 16, -- Niryastare
    [1454] = 8, -- Feldagard Keep
    [1455] = 17, -- Ceyond
    [1456] = 16, -- Sutch Mine
    [1457] = 22, -- Scholarium Outer Ruins
    [1458] = 12, -- The Mythos
    [1459] = 16, -- Wendir
    [1460] = 16, -- Valente Winery
    [1461] = 16, -- Outcast Inn Cellar
    [1462] = 12, -- Weatherleah
    [1463] = 19, -- The Scholarium
    [1464] = 40, -- Fargrave Outer Ruins
    [1465] = 16, -- Skingrad Outlaws Refuge
    [1466] = 18, -- Leftwheal Trading Post
    [1467] = 14, -- Silorn
    [1468] = 18, -- Kelesan'ruhn
    [1470] = 18, -- Oathsworn Pit
    [1471] = 18, -- Bedlam Veil
    [1472] = 15, -- Gladesong Arboretum
    [1473] = 12, -- Tower of Unutterable Truths
    [1474] = 12, -- The Mythos
    [1475] = -2, -- Seat of Detritus
    [1478] = 18, -- Lucent Citadel
    [1479] = 26, -- Willowpond Haven
    [1481] = 30, -- Mota-ka
    [1482] = 19, -- Strid River Valley
    [1483] = 17, -- Huntsman's Fortress
    [1484] = 36, -- Shehai Waystation
    [1485] = 15, -- Port Dufort
    [1487] = 28, -- Zhan Khaj Crest
    [1488] = 15, -- Wing of the Crow
    [1491] = 14, -- Rosewine Retreat
    [1492] = 26, -- Merryvine Estate
    [1494] = 22, -- Seabloom Villa
    [1495] = 15, -- Haven of the Five Companions
    [1496] = 4, -- Exiled Redoubt
    [1497] = 16, -- Lep Seclusa
    [1498] = 16, -- Dusk Keep
    [1499] = 35, -- Star Haven Adeptorium
    [1500] = -6, -- Kthendral Deep Mines
    [1501] = 20, -- Grand Gallery of Tamriel
    [1502] = 30, -- Solstice
    [1504] = -8, -- Coldharbour Colosseum
    [1505] = 12, -- Underground Sanctum
    [1506] = 12, -- Worm Cult Lair
    [1507] = 46, -- The Earth Forge
    [1508] = 16, -- Stirk
    [1509] = 30, -- Vosgah Shrine
    [1510] = 28, -- Sunport Palace District
    [1511] = 28, -- Vale of Revelry
    [1512] = 29, -- Carapace Cavern
    [1513] = 28, -- Tainted Leel
    [1514] = 22, -- Deetra Grotto
    [1515] = 28, -- Sunport Outlaws Refuge
    [1516] = 22, -- Corelanya Manor
    [1517] = 30, -- Li-Xal Pass
    [1518] = 32, -- Broken Light Temple
    [1520] = 28, -- Tarnur Mine
    [1521] = 20, -- The Colored Rooms
    [1534] = 30, -- Tide-Born Dream-Wallow
    [1535] = 12, -- Shrine of Sithis
    [1546] = 36, -- Shattered Mirror Isle
    [1547] = 16, -- Castle Skingrad
    [1548] = 12, -- Ossein Cage
    [1554] = 18, -- Theater of the Ancestors
    [1555] = 28, -- Bismuth Steam Baths
    [1556] = 28, -- The Sleepy Sloth
    [1557] = 15, -- Hero's Return
    [1584] = 14, -- Glenumbra
    -- 2.3.19: zones present in LibZone 9.01 (Sept 2026) but missing here.
    -- 6 are new since July (Update 51 / Season One: 1533, 1570, 1592,
    -- 1593, 1609, 1610); the rest were already in LibZone by April 2026
    -- but never made it into these tables. Values copy the existing entry
    -- named in each comment, as approved by the author; none are
    -- independently measured. Dev placeholders (174, 279, 917, 1107, 1171,
    -- 1175, 1204, 1346) are intentionally omitted.
    -- The Nowhere Vault (1533, 1583): a realm "suspended between realms".
    -- Deliberately neutral rather than modeled on any real climate - the
    -- magic of the Vault protects the player from the elements. Air is 25
    -- so that, with INTERIOR_MODIFIER (-3) applied, it lands on 22C
    -- (Frostfall's neutral point, inside RND's 10-25C comfort band). The
    -- reduced indoor time-of-day swing still moves it about -1.5/+0.9C.
    -- Both zoneIds share these values; UESP lists ~17 Vault rooms, but
    -- per-room values would need a map-based lookup, not a zoneId one.
    [1522] = 30, -- Xor-Hist | basis: Solstice (1502)
    [1523] = 22, -- A Battle at Sea | basis: Abecean Sea (555) - assumed on the Abecean Sea, per author
    [1524] = 29, -- Fissure Ruins | basis: Carapace Cavern (1512) - Daedric ruin in a bismuth cave
    [1526] = 30, -- Mor Naril | basis: Solstice (1502)
    [1527] = 29, -- Xul-Katama | basis: Carapace Cavern (1512) - delve
    [1528] = 28, -- Lair of the Black Worm | basis: Tainted Leel (1513) - outdoor Solstice delve
    [1529] = 29, -- Sea and Sword Lodge | basis: Carapace Cavern (1512) - delve
    [1530] = 28, -- Calindvale Gardens | basis: Tainted Leel (1513) - public dungeon
    [1531] = 29, -- Ashbound Hall | basis: Carapace Cavern (1512) - entered through a cave
    [1532] = 30, -- Xul-Haj | basis: Vakka-Bok Xanmeer (1079) - necropolis
    [1533] = 25, -- The Nowhere Vault | basis: neutral - see Nowhere Vault note
    [1536] = 12, -- Dwynnarth Crypts | basis: Bad Man's Hallows (284) - Glenumbra crypt
    [1537] = 30, -- Gristmung Hold | basis: Solstice (1502)
    [1538] = 10, -- Shivering Isles | basis: Chateau of the Ravenous Rodent (219)
    [1551] = 30, -- Naj-Caldeesh | basis: Vakka-Bok Xanmeer (1079) - dungeon
    [1552] = -4, -- Black Gem Foundry | basis: Vaults of Madness (11) - Coldharbour dungeon
    [1553] = -8, -- Writhing Fortress | basis: Coldharbour (347)
    [1559] = 38, -- Night Market | basis: Fargrave (1282)
    [1560] = 22, -- Hiddenspring Cottage | basis: Gold Coast (823) - house
    [1561] = 19, -- Wildgrown Chapel of Julianos | basis: West Weald (1443) - house
    [1562] = 42, -- Gossamer Crypt | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1563] = 42, -- Mournful Catacomb | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1564] = 42, -- Timeless Wallow | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1565] = 38, -- Opulent Ordeal | basis: Fargrave (1282) - Night Market trial
    [1566] = 30, -- Cradle of the Worm Colossus | basis: Solstice (1502) - house
    [1567] = 18, -- Druidspring Conservatory | basis: High Isle (1318) - house
    [1568] = 42, -- Night's Den | basis: Fargrave Outlaws Refuge (1293) - house
    [1569] = 22, -- Buccaneer Bay | basis: Abecean Sea (555) - island house, per author
    [1570] = 22, -- Voyage on the Abecean Sea | basis: Abecean Sea (555)
    [1574] = 14, -- Birien Manor | basis: Glenumbra (3)
    [1575] = 14, -- Hidden Library | basis: Glenumbra (3)
    [1577] = 14, -- Rols Boron's Warehouse | basis: Glenumbra (3)
    [1578] = 14, -- Daggerfall | basis: Glenumbra (3)
    [1579] = 10, -- Sage's Isle | basis: Glenumbra (3) minus 4C - fog-bound isle far to the north
    [1583] = 25, -- The Nowhere Vault | basis: neutral - see Nowhere Vault note
    [1592] = -2, -- March of Sacrifices | basis: March of Sacrifices (1055) - second instance
    [1593] = 28, -- Moon Hunter Keep | basis: Moon Hunter Keep (1052) - second instance
    [1594] = 14, -- Rogue's Refuge | basis: Glenumbra (3) - house, exterior entry over a crypt, per author
    [1595] = 18, -- Dancing Waters Wellspring | basis: Summerset (1011) - house, exterior per author
    [1597] = -3, -- Star-Gazer's Vigil | basis: The Reach (1207) - house
    [1609] = 25, -- Sheogorad Chateau | basis: Amaya Lake Lodge (995), per author
    [1610] = 18, -- Grotto of Desires | basis: Pantherfang Chapel (1277), per author
}

-- Pending zoneId verification (not found in LibZone's data as of API101050) -- currently inert, falls back to default:
--   "Amenos" = 27

-- Weather probability profiles per zone name.
-- Format: { rainChance = 0–1, snowChance = 0–1 }
-- Applied as a constant climate modifier (not random per-tick).
local ZONE_WEATHER = {
    -- zoneId -> value, verified against LibZone's public-domain zone-name data
    -- (https://github.com/Baertram/LibZone, LibZone_Data.lua, "en" table,
    -- dated 2026-06-08 / API101050). Comment on each line is the English zone
    -- name at authoring time, for human readability only -- it is never read at
    -- runtime; only the zoneId key is used.
    [3] = { rainChance = 0.35, snowChance = 0.05 }, -- Glenumbra
    [11] = { rainChance = 0.0, snowChance = 0.0 }, -- Vaults of Madness
    [19] = { rainChance = 0.3, snowChance = 0.05 }, -- Stormhaven
    [20] = { rainChance = 0.25, snowChance = 0.2 }, -- Rivenspire
    [41] = { rainChance = 0.15, snowChance = 0.05 }, -- Stonefalls
    [57] = { rainChance = 0.35, snowChance = 0.0 }, -- Deshaan
    [58] = { rainChance = 0.5, snowChance = 0.0 }, -- Malabal Tor
    [92] = { rainChance = 0.1, snowChance = 0.05 }, -- Bangkorai
    [101] = { rainChance = 0.2, snowChance = 0.35 }, -- Eastmarch
    [103] = { rainChance = 0.2, snowChance = 0.3 }, -- The Rift
    [104] = { rainChance = 0.05, snowChance = 0.0 }, -- Alik'r Desert
    [108] = { rainChance = 0.4, snowChance = 0.0 }, -- Greenshade
    [117] = { rainChance = 0.5, snowChance = 0.0 }, -- Shadowfen
    [176] = { rainChance = 0.0, snowChance = 0.0 }, -- City of Ash I
    [181] = { rainChance = 0.25, snowChance = 0.05 }, -- Cyrodiil
    [191] = { rainChance = 0.0, snowChance = 0.0 }, -- Ash Mountain
    [193] = { rainChance = 0.0, snowChance = 0.0 }, -- Tormented Spire
    [280] = { rainChance = 0.15, snowChance = 0.6 }, -- Bleakrock Isle
    [281] = { rainChance = 0.15, snowChance = 0.05 }, -- Bal Foyen
    [347] = { rainChance = 0.0, snowChance = 0.2 }, -- Coldharbour
    [368] = { rainChance = 0.0, snowChance = 0.0 }, -- The Black Forge
    [381] = { rainChance = 0.25, snowChance = 0.0 }, -- Auridon
    [382] = { rainChance = 0.15, snowChance = 0.0 }, -- Reaper's March
    [383] = { rainChance = 0.55, snowChance = 0.0 }, -- Grahtwood
    [534] = { rainChance = 0.1, snowChance = 0.0 }, -- Stros M'Kai
    [535] = { rainChance = 0.3, snowChance = 0.05 }, -- Betnikh
    [537] = { rainChance = 0.4, snowChance = 0.0 }, -- Khenarthi's Roost
    [581] = { rainChance = 0.0, snowChance = 0.1 }, -- Heart's Grief
    [584] = { rainChance = 0.25, snowChance = 0.05 }, -- Imperial City
    [681] = { rainChance = 0.0, snowChance = 0.0 }, -- City of Ash II
    [684] = { rainChance = 0.15, snowChance = 0.55 }, -- Wrothgar
    [702] = { rainChance = 0.0, snowChance = 0.2 }, -- Frostbreak Fortress
    [707] = { rainChance = 0.0, snowChance = 0.0 }, -- Ice-Heart's Lair
    [723] = { rainChance = 0.0, snowChance = 0.1 }, -- Heart's Grief
    [726] = { rainChance = 0.6, snowChance = 0.0 }, -- Murkmire
    [816] = { rainChance = 0.05, snowChance = 0.0 }, -- Hew's Bane
    [823] = { rainChance = 0.2, snowChance = 0.0 }, -- Gold Coast
    [849] = { rainChance = 0.05, snowChance = 0.0 }, -- Vvardenfell
    [888] = { rainChance = 0.1, snowChance = 0.0 }, -- Craglorn
    [980] = { rainChance = 0.0, snowChance = 0.0 }, -- Clockwork City
    [1010] = { rainChance = 0.05, snowChance = 0.7 }, -- Scalecaller Peak
    [1011] = { rainChance = 0.3, snowChance = 0.0 }, -- Summerset
    [1051] = { rainChance = 0.2, snowChance = 0.15 }, -- Cloudrest
    [1055] = { rainChance = 0.2, snowChance = 0.2 }, -- March of Sacrifices
    [1080] = { rainChance = 0.0, snowChance = 0.0 }, -- Frostvault
    [1086] = { rainChance = 0.05, snowChance = 0.0 }, -- Northern Elsweyr
    [1121] = { rainChance = 0.0, snowChance = 0.0 }, -- Sunspire
    [1125] = { rainChance = 0.0, snowChance = 0.0 }, -- Frostvault Chasm
    [1133] = { rainChance = 0.3, snowChance = 0.0 }, -- Southern Elsweyr
    [1138] = { rainChance = 0.0, snowChance = 0.0 }, -- Dragonhold
    [1152] = { rainChance = 0.05, snowChance = 0.8 }, -- Icereach
    [1160] = { rainChance = 0.1, snowChance = 0.5 }, -- Western Skyrim
    [1161] = { rainChance = 0.0, snowChance = 0.0 }, -- Blackreach: Greymoor Caverns
    [1168] = { rainChance = 0.1, snowChance = 0.6 }, -- Frozen Coast
    [1196] = { rainChance = 0.1, snowChance = 0.7 }, -- Kyne's Aegis
    [1201] = { rainChance = 0.15, snowChance = 0.4 }, -- Castle Thorn
    [1207] = { rainChance = 0.2, snowChance = 0.35 }, -- The Reach
    [1208] = { rainChance = 0.0, snowChance = 0.0 }, -- Blackreach: Arkthzand Cavern
    [1237] = { rainChance = 0.0, snowChance = 0.0 }, -- The Deadlands: Testing Grounds
    [1261] = { rainChance = 0.4, snowChance = 0.0 }, -- Blackwood
    [1263] = { rainChance = 0.4, snowChance = 0.0 }, -- Rockgrove
    [1282] = { rainChance = 0.0, snowChance = 0.0 }, -- Fargrave
    [1285] = { rainChance = 0.0, snowChance = 0.0 }, -- Burning Gyre Keep
    [1286] = { rainChance = 0.0, snowChance = 0.0 }, -- The Deadlands
    [1318] = { rainChance = 0.35, snowChance = 0.0 }, -- High Isle
    [1383] = { rainChance = 0.35, snowChance = 0.0 }, -- Galen
    [1413] = { rainChance = 0.0, snowChance = 0.0 }, -- Apocrypha
    [1414] = { rainChance = 0.2, snowChance = 0.0 }, -- Telvanni Peninsula
    [1443] = { rainChance = 0.25, snowChance = 0.05 }, -- West Weald
    [1502] = { rainChance = 0.45, snowChance = 0.0 }, -- Solstice
    [1584] = { rainChance = 0.35, snowChance = 0.05 }, -- Glenumbra
    -- 2.3.19: see the matching note in ZONE_BASE_TEMPS.
    [1559] = { rainChance = 0.0, snowChance = 0.0 }, -- Night Market | basis: Fargrave (1282)
    [1578] = { rainChance = 0.35, snowChance = 0.05 }, -- Daggerfall | basis: Glenumbra (3)
    [1592] = { rainChance = 0.2, snowChance = 0.2 }, -- March of Sacrifices | basis: March of Sacrifices (1055)
}

-- Pending zoneId verification:
--   "Amenos" rainChance=0.45 snowChance=0.0

-- Water temperatures in Celsius (used when player is swimming).
local ZONE_WATER_TEMPS = {
    -- zoneId -> value, verified against LibZone's public-domain zone-name data
    -- (https://github.com/Baertram/LibZone, LibZone_Data.lua, "en" table,
    -- dated 2026-06-08 / API101050). Comment on each line is the English zone
    -- name at authoring time, for human readability only -- it is never read at
    -- runtime; only the zoneId key is used.
    [3] = 13, -- Glenumbra
    [11] = -1, -- Vaults of Madness
    [19] = 13, -- Stormhaven
    [20] = 6, -- Rivenspire
    [22] = 20, -- Volenfell
    [31] = 22, -- Selene's Web
    [38] = 18, -- Blackheart Haven
    [41] = 22, -- Stonefalls
    [57] = 12, -- Deshaan
    [58] = 24, -- Malabal Tor
    [63] = 20, -- Darkshade Caverns I
    [92] = 16, -- Bangkorai
    [101] = 4, -- Eastmarch
    [103] = 5, -- The Rift
    [104] = 22, -- Alik'r Desert
    [108] = 22, -- Greenshade
    [117] = 26, -- Shadowfen
    [131] = 22, -- Tempest Island
    [138] = 16, -- Crimson Cove
    [142] = 14, -- Bonesnap Ruins
    [146] = 12, -- Wayrest Sewers I
    [148] = 24, -- Arx Corinium
    [159] = 15, -- Emeric's Dream
    [162] = 14, -- Obsidian Scar
    [166] = 13, -- Cath Bedraud
    [168] = 22, -- Bisnensel
    [169] = 15, -- Razak's Wheel
    [176] = 55, -- City of Ash I
    [181] = 14, -- Cyrodiil
    [187] = 26, -- Loriasel
    [188] = 18, -- The Apothecarium
    [189] = 22, -- Tribunal Temple
    [190] = 14, -- Reservoir of Souls
    [191] = 48, -- Ash Mountain
    [192] = 22, -- Virak Keep
    [193] = 52, -- Tormented Spire
    [207] = 26, -- Mzeneldt
    [208] = 55, -- The Earth Forge
    [212] = 20, -- Mournhold Sewers
    [213] = 24, -- Sunscale Ruins
    [214] = 15, -- Lair of the Skin Stealer
    [215] = 26, -- Vision of the Hist
    [216] = 12, -- Crow's Wood
    [218] = 16, -- Circus of Cheerful Slaughter
    [219] = 10, -- Chateau of the Ravenous Rodent
    [222] = 10, -- Dresan Keep
    [223] = 13, -- Tomb of Lost Kings
    [224] = 10, -- Breagha-Fin
    [227] = 18, -- Sunken Road
    [229] = 18, -- Nilata Ruins
    [231] = 16, -- Hall of Heroes
    [232] = 22, -- Silyanorn Ruins
    [233] = 26, -- Ruins of Ten-Maur-Wolk
    [234] = 24, -- Odious Chapel
    [235] = 20, -- Temple of Sul
    [236] = 16, -- White Rose Prison Dungeon
    [237] = 12, -- Impervious Vault
    [238] = 22, -- Salas En
    [239] = 22, -- Kulati Mines
    [241] = 18, -- House Indoril Crypt
    [242] = 26, -- Fort Arand Dungeons
    [243] = 20, -- Coral Heart Chamber
    [245] = 24, -- Heimlyn Keep Reliquary
    [246] = 20, -- Iliath Temple Mines
    [247] = 24, -- House Dres Crypts
    [248] = 22, -- Mzithumz
    [249] = 20, -- Tal'Deic Crypts
    [250] = 20, -- Narsis Ruins
    [252] = 12, -- The Hollow Cave
    [253] = 20, -- Shad Astula Underhalls
    [254] = 12, -- Deepcrag Den
    [255] = 18, -- Bthanual
    [256] = 13, -- Crosswych Mine
    [257] = 10, -- Vaults of Vernim
    [258] = 8, -- Arcwind Point
    [259] = 8, -- Trolhetta
    [260] = 5, -- Lost Knife Cave
    [261] = 3, -- Bonestrewn Barrow
    [262] = 4, -- Wittestadr Crypts
    [263] = 8, -- Mistwatch Crevasse
    [264] = 4, -- Fort Morvunskar
    [266] = 3, -- Cragwallow
    [267] = 15, -- Eyevea
    [268] = 12, -- Stormwarden Undercroft
    [269] = 22, -- Abamath Ruins
    [270] = 24, -- Shrine of the Black Maw
    [271] = 26, -- Broken Tusk
    [272] = 26, -- Atanaz Ruins
    [273] = 26, -- Chid-Moska Ruins
    [274] = 26, -- Onkobra Kwama Mine
    [275] = 22, -- Gandranen Ruins
    [280] = 0, -- Bleakrock Isle
    [281] = 18, -- Bal Foyen
    [283] = 22, -- Fungal Grotto I
    [284] = 13, -- Bad Man's Hallows
    [287] = 22, -- Inner Sea Armature
    [288] = 12, -- Mephala's Nest
    [289] = 24, -- Softloam Cavern
    [290] = 22, -- Hightide Hollow
    [291] = 16, -- Sheogorath's Tongue
    [306] = 14, -- Forgotten Crypts
    [308] = 24, -- Lost City of the Na-Totambu
    [309] = 13, -- Ilessan Tower
    [310] = 13, -- Silumm
    [311] = 22, -- Mines of Khuras
    [312] = 7, -- Enduum
    [313] = 12, -- Ebon Crypt
    [314] = 6, -- Cryptwatch Fort
    [315] = 15, -- Portdun Watch
    [316] = 15, -- Koeglin Mine
    [317] = 12, -- Pariah Catacombs
    [318] = 15, -- Farangel's Delve
    [319] = 15, -- Bearclaw Mine
    [320] = 22, -- Norvulk Ruins
    [321] = 10, -- Crestshade Mine
    [322] = 8, -- Flyleaf Catacombs
    [323] = 10, -- Tribulation Crypt
    [324] = 10, -- Orc's Finger Ruins
    [325] = 10, -- Erokii Ruins
    [326] = 8, -- Hildune's Secret Refuge
    [327] = 20, -- Santaki
    [328] = 20, -- Divad's Chagrin Mine
    [329] = 20, -- Aldunz
    [330] = 22, -- Coldrock Diggings
    [331] = 22, -- Sandblown Mine
    [334] = 9, -- Troll's Toothpick
    [335] = 22, -- Viridian Watch
    [336] = 16, -- Crypt of the Exiles
    [337] = 24, -- Klathzgar
    [338] = 26, -- Rubble Butte
    [339] = 4, -- Hall of the Dead
    [341] = 8, -- The Lion's Den
    [346] = 8, -- Skuldafn
    [347] = -2, -- Coldharbour
    [353] = 12, -- Hall of Trials
    [354] = 5, -- Cradlecrush Arena
    [359] = 3, -- The Chill Hollow
    [361] = 13, -- Old Sord's Cave
    [362] = 1, -- The Frigid Grotto
    [364] = 15, -- The Bastard's Tomb
    [365] = 12, -- Library of Dusk
    [366] = 7, -- Lightless Oubliette
    [367] = 7, -- Lightless Cell
    [368] = 50, -- The Black Forge
    [372] = 18, -- Manor of Revelry
    [375] = 9, -- Chapel of Light
    [376] = 7, -- Grunda's Gatehouse
    [377] = 22, -- Dra'bul
    [378] = 7, -- Shrine of Mauloch
    [379] = 22, -- Silvenar's Audience Hall
    [380] = 22, -- The Banished Cells I
    [381] = 16, -- Auridon
    [382] = 26, -- Reaper's March
    [383] = 24, -- Grahtwood
    [385] = 10, -- Ragnthar
    [386] = 26, -- Fort Virak Ruin
    [387] = 22, -- Tower of the Vale
    [388] = 22, -- Phaer Catacombs
    [389] = 16, -- Reliquary Ruins
    [390] = 12, -- The Veiled Keep
    [392] = 12, -- The Vault of Exile
    [393] = 22, -- Saltspray Cave
    [394] = 22, -- Ezduiin Undercroft
    [395] = 38, -- The Refuge of Dread
    [397] = 28, -- Del's Claim
    [401] = 22, -- Bewan
    [403] = 4, -- Northwind Mine
    [405] = 22, -- Lady Llarel's Shelter
    [406] = 22, -- Lower Bthanual
    [407] = 20, -- The Triple Circle Mine
    [408] = 20, -- Taleon's Crag
    [410] = 20, -- The Corpse Garden
    [411] = 20, -- The Hunting Grounds
    [412] = 6, -- Nimalten Barrow
    [415] = 4, -- Trolhetta Cave
    [416] = 22, -- Inner Tanzelwil
    [417] = 2, -- Aba-Loria
    [419] = 2, -- The Grotto of Depravity
    [420] = 12, -- Cave of Trophies
    [421] = 20, -- Mal Sorra's Tomb
    [422] = 2, -- The Wailing Maw
    [424] = 13, -- Camlorn Keep
    [425] = 13, -- Daggerfall Castle
    [426] = 13, -- Angof's Sanctum
    [429] = 13, -- Glenumbra Moors Cave
    [430] = 24, -- Aphren's Tomb
    [431] = 6, -- Taarengrav Barrow
    [433] = 16, -- Nairume's Prison
    [434] = 12, -- The Orrery
    [435] = 24, -- Cathedral of the Golden Path
    [436] = 15, -- Reliquary Vault
    [437] = 16, -- Laeloria Ruins
    [438] = 24, -- Cave of Broken Sails
    [439] = 22, -- Ossuary of Telacar
    [440] = 22, -- The Aquifer
    [442] = 16, -- Ne Salas
    [444] = 22, -- Burroot Kwama Mine
    [447] = 26, -- Mobar Mine
    [449] = 1, -- Direfrost Keep
    [451] = 22, -- Senalana
    [452] = 16, -- Temple to the Divines
    [453] = 24, -- Halls of Ichor
    [454] = 26, -- Do'Krin Temple
    [455] = 22, -- Rawl'kha Temple
    [456] = 26, -- Five Finger Dance
    [457] = 26, -- Moonmont Temple
    [458] = 22, -- Fort Sphinxmoth
    [459] = 22, -- Thizzrini Arena
    [460] = 24, -- The Demiplane of Jode
    [461] = 26, -- Den of Lorkhaj
    [462] = 22, -- Thibaut's Cairn
    [463] = 26, -- Kuna's Delve
    [464] = 15, -- Fardir's Folly
    [465] = 26, -- Claw's Strike
    [466] = 22, -- Weeping Wind Cave
    [467] = 26, -- Jode's Light
    [468] = 8, -- Dead Man's Drop
    [469] = 22, -- Tomb of Apostates
    [471] = 22, -- Shael Ruins
    [472] = 22, -- Roots of Silvenar
    [473] = 22, -- Black Vine Ruins
    [477] = 22, -- Vinedeath Cave
    [478] = 22, -- Wormroot Depths
    [481] = 8, -- Fort Greenwall
    [482] = 6, -- Shroud Hearth Barrow
    [484] = 8, -- Faldar's Tooth
    [485] = 8, -- Broken Helm Hollow
    [487] = 18, -- The Vile Manse
    [493] = 20, -- Breakneck Cave
    [494] = 15, -- Capstone Cave
    [495] = 16, -- Cracked Wood Cave
    [496] = 15, -- Echo Cave
    [497] = 26, -- Haynote Cave
    [498] = 14, -- Kingscrest Cavern
    [499] = 14, -- Lipsand Tarn
    [500] = 26, -- Muck Valley Cavern
    [501] = 26, -- Newt Cave
    [502] = 22, -- Nisin Cave
    [503] = 15, -- Pothole Caverns
    [504] = 15, -- Quickwater Cave
    [505] = 15, -- Red Ruby Cave
    [506] = 16, -- Serpent Hollow Cave
    [507] = 14, -- Bloodmayne Cave
    [508] = 22, -- Foyada Quarry
    [509] = 22, -- Ald Carac
    [510] = 16, -- Ularra
    [511] = 16, -- Arcane University
    [512] = 20, -- Deeping Drome
    [513] = 2, -- Mor Khazgur
    [514] = 15, -- Istirus Outpost
    [515] = 15, -- Istirus Outpost Arena
    [516] = 22, -- Ald Carac
    [517] = 18, -- Eld Angavar
    [518] = 18, -- Eld Angavar
    [526] = 15, -- Greenhill Catacombs
    [529] = 15, -- Eyevea Mages Guild
    [530] = 26, -- Haj Uxith Corridors
    [531] = 4, -- Toadstool Hollow
    [532] = 16, -- Vahtacen
    [533] = 15, -- Underpall Cave
    [534] = 24, -- Stros M'Kai
    [535] = 14, -- Betnikh
    [537] = 28, -- Khenarthi's Roost
    [539] = 14, -- Carzog's Demise
    [541] = 16, -- Glade of the Divines
    [542] = 20, -- Buraniim
    [543] = 7, -- Dourstone Vault
    [544] = 24, -- Stonefang Cavern
    [545] = 15, -- Alcaire Keep
    [546] = 15, -- Wayrest Castle
    [547] = 22, -- Shrouded Hollow
    [548] = 22, -- Silatar
    [549] = 22, -- The Middens
    [552] = 22, -- Shademist Enclave
    [553] = 16, -- Ilmyris
    [554] = 22, -- Serpent's Grotto
    [555] = 22, -- Abecean Sea
    [556] = 22, -- Nereid Temple Cave
    [557] = 4, -- Village of the Lost
    [558] = 22, -- Hectahame Grotto
    [559] = 22, -- Valenheart
    [560] = 6, -- Nimalten Barrow
    [562] = 24, -- Khaj Rawlith
    [565] = 26, -- Ren-dro Caverns
    [566] = 13, -- Heart of the Wyrd Tree
    [567] = 20, -- The Hunting Grounds
    [569] = 28, -- Ash'abah Pass
    [570] = 28, -- Tu'whacca's Sanctum
    [571] = 20, -- Suturah's Crypt
    [572] = 16, -- Stirk
    [573] = 12, -- The Worm's Retreat
    [574] = 22, -- The Valley of Blades
    [575] = 20, -- Carac Dena
    [576] = 7, -- Gurzag's Mine
    [577] = 22, -- The Underroot
    [578] = 26, -- Naril Nagaia
    [579] = 20, -- Harridan's Lair
    [580] = 22, -- Barrow Trench
    [581] = -3, -- Heart's Grief
    [582] = 22, -- Temple of Auri-El
    [584] = 14, -- Imperial City
    [585] = 22, -- Nchu Duabthar Threshold
    [587] = 8, -- Fevered Mews
    [588] = 10, -- Doomcrag
    [589] = 8, -- Northpoint
    [590] = 16, -- Edrald Undercroft
    [591] = 28, -- Lorkrata Ruins
    [592] = 10, -- Shadowfate Cavern
    [594] = 22, -- The Far Shores
    [595] = 16, -- Abagarlas
    [596] = 8, -- Blood Matron's Crypt
    [598] = 18, -- The Colored Rooms
    [599] = 22, -- Elden Root
    [600] = 18, -- Mournhold
    [601] = 15, -- Wayrest
    [628] = 10, -- Doomcrag
    [632] = 28, -- Skyreach Hold
    [636] = 18, -- Hel Ra Citadel
    [637] = 26, -- Quarantine Serk Catacombs
    [639] = 22, -- Sanctum Ophidia
    [640] = 12, -- Godrun's Dream
    [641] = 15, -- Themond Mine
    [642] = 55, -- The Earth Forge
    [643] = 13, -- Imperial Sewers
    [676] = 22, -- Shark's Teeth Grotto
    [677] = 18, -- Maelstrom Arena
    [681] = 60, -- City of Ash II
    [684] = 2, -- Wrothgar
    [689] = 3, -- Nikolvara's Kennel
    [691] = 6, -- Thukhozod's Sanctum
    [692] = 6, -- Watcher's Hold
    [694] = 6, -- Argent Mine
    [697] = 5, -- Zthenganaz
    [698] = 3, -- Morkul Descent
    [699] = 15, -- Honor's Rest
    [700] = 3, -- Exile's Barrow
    [701] = 15, -- Graystone Quarry Depths
    [702] = 2, -- Frostbreak Fortress
    [704] = 5, -- Bonerock Cavern
    [707] = 1, -- Ice-Heart's Lair
    [708] = 15, -- Temple Library
    [710] = 3, -- Fharun Prison
    [711] = 15, -- Temple Rectory
    [712] = 5, -- Chambers of Loyalty
    [715] = 15, -- Sanctum of Prowess
    [719] = 16, -- Time-Lost Throne Room
    [723] = -3, -- Heart's Grief
    [724] = 16, -- Sorrow
    [725] = 26, -- Maw of Lorkhaj
    [726] = 28, -- Murkmire
    [745] = 36, -- Charred Ridge
    [746] = 22, -- Vulkhel Guard Outlaws Refuge
    [747] = 22, -- Elden Root Outlaws Refuge
    [748] = 22, -- Marbruk Outlaws Refuge
    [749] = 22, -- Velyn Harbor Outlaws Refuge
    [750] = 24, -- Rawl'kha Outlaws Refuge
    [751] = 22, -- Belkarth Outlaws Refuge
    [752] = 15, -- Wayrest Outlaws Refuge
    [753] = 13, -- Daggerfall Outlaws Refuge
    [754] = 18, -- Evermore Outlaws Refuge
    [755] = 10, -- Shornhelm Outlaws Refuge
    [756] = 20, -- Sentinel Outlaws Refuge
    [757] = 26, -- Davon's Watch Outlaws Refuge
    [758] = 5, -- Windhelm Outlaws Refuge
    [759] = 26, -- Stormhold Outlaws Refuge
    [760] = 20, -- Mournhold Outlaws Refuge
    [761] = 8, -- Riften Outlaws Refuge
    [765] = 12, -- Smuggler's Den
    [766] = 18, -- Trader's Cove
    [767] = 15, -- Deadhollow Halls
    [770] = 15, -- The Hideaway
    [771] = 12, -- Glittering Grotto
    [773] = 26, -- Cold-Blood Cavern
    [774] = 24, -- Sugar-Slinger's Den
    [780] = 3, -- Orsinium Outlaws Refuge
    [808] = 1, -- Dragon Bridge Smuggler Caves
    [810] = 12, -- Smuggler's Tunnel
    [811] = 13, -- Ancient Carzog's Demise
    [814] = 26, -- Temple of Ire
    [815] = 28, -- Scarp Keep
    [816] = 25, -- Hew's Bane
    [818] = 24, -- Iron Wheel Headquarters
    [819] = 24, -- Al-Danobia Tomb
    [820] = 24, -- Hubalajad Palace
    [821] = 12, -- Thieves Den
    [823] = 18, -- Gold Coast
    [826] = 16, -- Dark Brotherhood Sanctuary
    [827] = 18, -- Jarol Estate
    [828] = 16, -- At-Himah Estate
    [829] = 17, -- Knightsgrave
    [831] = 16, -- Anvil Castle
    [832] = 16, -- Castle Kvatch
    [833] = 12, -- Enclave of the Hourglass
    [834] = 20, -- Fulstrom Homestead
    [836] = 16, -- Cathedral of Akatosh
    [837] = 16, -- Anvil Outlaws Refuge
    [841] = 8, -- Jerall Mountains Logging Track
    [842] = 26, -- Blackwood Borderlands
    [843] = 26, -- Ruins of Mazzatun
    [844] = 22, -- Sulima Mansion
    [845] = 16, -- Velmont Mansion
    [848] = 24, -- Cradle of Shadows
    [849] = 32, -- Vvardenfell
    [852] = 14, -- Captain Margaux's Place
    [853] = 10, -- Ravenhurst
    [854] = 20, -- Mournoth Keep
    [855] = 18, -- Hammerdeath Bungalow
    [856] = 18, -- Twin Arches
    [857] = 24, -- House of the Silent Magnifico
    [858] = 20, -- Cliffshade
    [859] = 22, -- Black Vine Villa
    [860] = 22, -- Snugpod
    [861] = 22, -- Bouldertree Refuge
    [862] = 22, -- Sleek Creek House
    [863] = 26, -- Moonmirth House
    [864] = 8, -- Autumn's-Gate
    [865] = 3, -- Grymharth's Woe
    [866] = 18, -- Velothi Reverie
    [867] = 26, -- Kragenhome
    [868] = 26, -- Humblemud
    [869] = 18, -- The Ample Domicile
    [870] = 26, -- Domus Phrasticus
    [871] = 22, -- Cyrodilic Jungle House
    [872] = 22, -- Strident Springs Demesne
    [873] = 25, -- Stay-Moist Mansion
    [874] = 22, -- Quondam Indorilia
    [875] = 8, -- Old Mistveil Manor
    [876] = 24, -- Dawnshadow
    [877] = 22, -- The Gorinir Estate
    [878] = 22, -- Mathiisen Manor
    [879] = 28, -- Hunding's Palatial Hall
    [880] = 18, -- Forsaken Stronghold
    [881] = 15, -- Gardner House
    [882] = 26, -- Grand Topal Hideaway
    [883] = 22, -- Earthtear Cavern
    [888] = 15, -- Craglorn
    [889] = 26, -- Molavar
    [890] = 26, -- Rkundzelft
    [891] = 28, -- Serpent's Nest
    [892] = 18, -- Ilthag's Undertower
    [893] = 24, -- Ruins of Kardala
    [894] = 22, -- Loth'Na Caverns
    [895] = 26, -- Rkhardahrk
    [896] = 20, -- Haddock's Market
    [897] = 24, -- Chiselshriek Mine
    [898] = 26, -- Buried Sands
    [899] = 20, -- Mtharnaz
    [900] = 26, -- The Howling Sepulchers
    [902] = 26, -- Fearfangs Cavern
    [903] = 8, -- Exarch's Stronghold
    [904] = 28, -- Zalgaz's Den
    [905] = 20, -- Tombs of the Na-Totambu
    [906] = 18, -- Hircine's Haunt
    [907] = 24, -- Rahni'Za, School of Warriors
    [908] = 22, -- Shada's Tear
    [909] = 12, -- Seeker's Archive
    [910] = 22, -- Elinhir Sewerworks
    [911] = 15, -- Reinhold's Retreat
    [913] = 18, -- The Mage's Staff
    [914] = 22, -- Skyreach Catacombs
    [915] = 22, -- Skyreach Temple
    [916] = 24, -- Skyreach Pinnacle
    [918] = 26, -- Nchuleftingth
    [919] = 28, -- Forgotten Wastes
    [920] = 24, -- Inanius Egg Mine
    [921] = 26, -- Khartag Point
    [926] = 20, -- Pinsun
    [930] = 20, -- Darkshade Caverns II
    [933] = 12, -- Wayrest Sewers II
    [934] = 22, -- Fungal Grotto II
    [935] = 22, -- The Banished Cells II
    [937] = 20, -- Flaming Nix Deluxe Garret
    [938] = 28, -- Sisters of the Sands Apartment
    [939] = 20, -- Barbed Hook Private Room
    [940] = 18, -- Mara's Kiss Public House
    [941] = 26, -- The Ebony Flask Inn Room
    [942] = 14, -- The Rosy Lion
    [943] = 13, -- Daggerfall Overlook
    [944] = 15, -- Serenity Falls Estate
    [945] = 24, -- Ebonheart Chateau
    [949] = 26, -- Dreudurai Glass Mine
    [957] = 22, -- Dreloth Ancestral Tomb
    [958] = 22, -- Veloth Ancestral Tomb
    [959] = 22, -- Andrano Ancestral Tomb
    [960] = 24, -- Hleran Ancestral Tomb
    [961] = 40, -- Ashalmawia
    [964] = 36, -- Ashimanu Cave
    [965] = 22, -- Skar
    [967] = 12, -- Clockwork City Vault
    [969] = 38, -- Ashurnibibi
    [970] = 22, -- Redoran Garrison
    [971] = 22, -- Vivec City Outlaws Refuge
    [972] = 22, -- Kudanat Mine
    [973] = 50, -- Bloodroot Forge
    [974] = 8, -- Falkreath Hold
    [977] = 2, -- Prison of Xykenaz
    [979] = 12, -- Clockwork City Vault
    [980] = 12, -- Clockwork City
    [981] = 14, -- The Brass Fortress
    [982] = 18, -- Slag Town Outlaws Refuge
    [988] = 12, -- Clockwork City Vaults
    [990] = 20, -- Incarnatorium
    [993] = 16, -- Mnemonic Planisphere
    [994] = 22, -- Saint Delyn Penthouse
    [995] = 22, -- Amaya Lake Lodge
    [996] = 22, -- Tel Galen
    [997] = 22, -- Ald Velothi Harbor House
    [998] = 22, -- Dranil Kir
    [999] = 4, -- Evergloam
    [1000] = 14, -- Asylum Sanctorium
    [1004] = 12, -- The Serviflume
    [1005] = 15, -- Linchal Grand Manor
    [1006] = 10, -- Exorcised Coven Cottage
    [1007] = 16, -- Hakkvild's High Hall
    [1008] = 4, -- Coldharbour Surreal Estate
    [1009] = 22, -- Fang Lair
    [1010] = 1, -- Scalecaller Peak
    [1011] = 18, -- Summerset
    [1012] = 12, -- The Spiral Skein
    [1013] = 24, -- Eldbur Sanctuary
    [1021] = 22, -- Sunhold
    [1023] = 22, -- Shimmerene Waterworks
    [1024] = 18, -- Eldbur Ruins
    [1027] = 15, -- Artaeum
    [1028] = 22, -- Alinor Outlaws Refuge
    [1029] = 12, -- Ebon Sanctum
    [1031] = 20, -- Illumination Academy Stacks
    [1033] = 18, -- Red Temple Catacombs
    [1035] = 12, -- The Spiral Skein
    [1036] = 18, -- Cathedral of Webs
    [1039] = 15, -- Psijic Relic Vaults
    [1040] = 4, -- Evergloam
    [1042] = 7, -- Pariah's Pinnacle
    [1043] = 12, -- The Orbservatory Prior
    [1044] = 12, -- The Erstwhile Sanctuary
    [1045] = 26, -- Princely Dawnlight Palace
    [1046] = 22, -- Saltbreeze Cave
    [1047] = 22, -- Monastery of Serene Harmony
    [1048] = 22, -- Alinor Royal Palace
    [1051] = 8, -- Cloudrest
    [1052] = 24, -- Moon Hunter Keep
    [1055] = 4, -- March of Sacrifices
    [1059] = 15, -- Golden Gryphon Garret
    [1060] = 22, -- Alinor Crest Townhouse
    [1061] = 22, -- Colossal Aldmeri Grotto
    [1063] = 20, -- Grand Psijic Villa
    [1064] = 15, -- Hunter's Glade
    [1065] = 26, -- Blight Bog Sump
    [1066] = 26, -- Tsofeer Cavern
    [1067] = 12, -- The Dreaming Nest
    [1069] = 26, -- Tomb of Many Spears
    [1070] = 26, -- Lilmoth Outlaws Refuge
    [1072] = 26, -- Norg-Tzel
    [1073] = 28, -- Teeth of Sithis
    [1074] = 15, -- The Sunless Hollow
    [1075] = 15, -- The Sunless Hollow
    [1076] = 15, -- The Sunless Hollow
    [1077] = 26, -- The Swallowed Grove
    [1079] = 26, -- Vakka-Bok Xanmeer
    [1080] = -1, -- Frostvault
    [1081] = 16, -- Depths of Malatar
    [1082] = 26, -- Blackrose Prison
    [1085] = 20, -- Halls of Colossus
    [1086] = 28, -- Northern Elsweyr
    [1088] = 20, -- Rimmen Outlaws Refuge
    [1089] = 20, -- Rimmen Necropolis
    [1090] = 26, -- Orcrest
    [1091] = 22, -- Abode of Ignominy
    [1092] = 22, -- Predator Mesa
    [1094] = 24, -- Tomb of the Serpents
    [1095] = 24, -- Darkpool Mine
    [1096] = 24, -- The Tangle
    [1097] = 24, -- Sleepy Senche Mine
    [1098] = 26, -- Riverhold
    [1099] = 22, -- Rimmen Palace
    [1101] = 20, -- Rimmen Palace Recesses
    [1102] = 12, -- Sepulcher of Mischance
    [1103] = 26, -- Moon Gate of Anequina
    [1105] = 24, -- Skooma Cat's Cloister
    [1106] = 26, -- Star Haven Adeptorium
    [1108] = 26, -- Lakemire Xanmeer Manor
    [1109] = 9, -- Enchanted Snow Globe Home
    [1110] = 8, -- Dov-Vahl Shrine
    [1111] = 22, -- Cicatrice Caverns
    [1112] = 24, -- Tenarr Zalviit Ossuary
    [1113] = 22, -- Hidden Moon Crypts
    [1114] = 26, -- Hakoshae Tombs
    [1115] = 26, -- Merryvale Sugar Farm Caves
    [1116] = 26, -- Moon Gate
    [1117] = 24, -- Shadow Dance Temple
    [1118] = 15, -- Vault of the Heavenly Scourge
    [1119] = 22, -- Desert Wind Caverns
    [1120] = 16, -- Meirvale Keep
    [1121] = 38, -- Sunspire
    [1125] = 0, -- Frostvault Chasm
    [1126] = 24, -- Elinhir Private Arena
    [1128] = 24, -- Sugar Bowl Suite
    [1129] = 26, -- Hall of the Lunar Champion
    [1130] = 26, -- Jode's Embrace
    [1133] = 29, -- Southern Elsweyr
    [1134] = 22, -- Forsaken Citadel
    [1135] = 22, -- Moonlit Cove
    [1136] = 24, -- Zazaradi's Quarry and Mine
    [1137] = 26, -- Path of Pride
    [1138] = 44, -- Dragonhold
    [1139] = 20, -- Senchal Outlaws Refuge
    [1140] = 24, -- Wind Scour Temple
    [1141] = 26, -- Dark Water Temple
    [1142] = 22, -- The Valley of Blades
    [1143] = 8, -- Storm Talon Temple
    [1144] = 24, -- Vahlokzin's Lair
    [1145] = 26, -- Passage of Dad'na Ghaten
    [1146] = 26, -- Tideholm
    [1147] = 26, -- New Moon Fortress
    [1148] = 20, -- Halls of the Highmane
    [1149] = 24, -- Doomstone Keep
    [1150] = 24, -- Doomstone Caverns
    [1152] = -1, -- Icereach
    [1153] = 18, -- Unhallowed Grave
    [1154] = 26, -- Moon-Sugar Meadow
    [1155] = 10, -- Wraithhome
    [1160] = 1, -- Western Skyrim
    [1161] = 3, -- Blackreach: Greymoor Caverns
    [1166] = 2, -- Chillwind Depths
    [1174] = 5, -- Verglas Hollow
    [1176] = 4, -- Kilkreath Temple
    [1178] = 5, -- Solitude Outlaws Refuge
    [1179] = 3, -- Mor Khazgur Mine
    [1180] = 16, -- Imperial Cache Annex
    [1182] = 4, -- Morthal Barrow
    [1183] = 4, -- Tzinghalis's Tower
    [1184] = 5, -- Castle Dour
    [1185] = 22, -- Deepwood Vale
    [1188] = 6, -- Palace of Kings
    [1189] = 6, -- Palace of Kings
    [1190] = 6, -- Riften Ratway
    [1191] = 3, -- Blackreach
    [1192] = 26, -- Lucky Cat Landing
    [1193] = 16, -- Potentate's Retreat
    [1195] = 16, -- The Undergrove
    [1196] = 1, -- Kyne's Aegis
    [1197] = 2, -- Stone Garden
    [1200] = 22, -- Thieves' Oasis
    [1201] = 3, -- Castle Thorn
    [1205] = 7, -- Grayhome
    [1206] = 7, -- Grayhome Ritual Chamber
    [1207] = 3, -- The Reach
    [1208] = 3, -- Blackreach: Arkthzand Cavern
    [1210] = 4, -- Briar Rock Ruins
    [1218] = 6, -- Snowmelt Suite
    [1219] = 6, -- Proudspire Manor
    [1220] = 6, -- Bastion Sanguinaris
    [1221] = 15, -- Grayhaven
    [1224] = 4, -- Nighthollow Keep
    [1227] = 9, -- Vateshran Hollows
    [1228] = 16, -- Black Drake Villa
    [1229] = 48, -- The Cauldron
    [1233] = 6, -- Antiquarian's Alpine Gallery
    [1234] = 5, -- Stillwaters Retreat
    [1235] = 16, -- Ne Salas Cache Annex
    [1236] = 13, -- Imperial Sewers
    [1237] = 55, -- The Deadlands: Testing Grounds
    [1240] = 26, -- Leyawiin Castle
    [1243] = 26, -- Fort Redmane
    [1244] = 15, -- Isle of Balfiera
    [1245] = 20, -- Borderwatch Ruins
    [1246] = 22, -- Deepscorn Hollow
    [1247] = 16, -- Veyond
    [1249] = 10, -- Twyllbek Ruins
    [1251] = 15, -- Xynaa's Sanctuary
    [1252] = 16, -- Leyawiin Outlaws Refuge
    [1253] = 22, -- Undertow Cavern
    [1254] = 16, -- Arpenia
    [1255] = 22, -- Bloodrun Cave
    [1259] = 16, -- Zenithar's Abbey
    [1260] = 16, -- The Silent Halls
    [1261] = 24, -- Blackwood
    [1262] = 20, -- Festival Arena
    [1263] = 22, -- Rockgrove
    [1264] = 5, -- Stone Eagle Aerie
    [1265] = 6, -- Shalidor's Shrouded Realm
    [1266] = 26, -- Xal Irasotl
    [1267] = 16, -- Red Petal Bastion
    [1268] = 12, -- The Dread Cellar
    [1270] = 28, -- Kushalit Sanctuary
    [1271] = 22, -- Varlaisvea Ayleid Ruins
    [1272] = 40, -- Atoll of Immolation
    [1274] = 12, -- Garden of Shadows
    [1275] = 15, -- Pilgrim's Rest
    [1276] = 16, -- Water's Edge
    [1277] = 16, -- Pantherfang Chapel
    [1278] = 16, -- Lyranth's Hidden Lair
    [1282] = 35, -- Fargrave
    [1283] = 24, -- The Shambles
    [1284] = 18, -- The Collector's Villa
    [1285] = 52, -- Burning Gyre Keep
    [1286] = 60, -- The Deadlands
    [1289] = 22, -- Fort Grief Citadel
    [1290] = 1, -- Deadlight
    [1291] = 38, -- Ardent Hope
    [1293] = 40, -- Fargrave Outlaws Refuge
    [1294] = 16, -- Isle of Joys
    [1295] = 52, -- Destruction's Solace
    [1296] = 14, -- Fort Sundercliff
    [1298] = 12, -- False Martyrs' Folly
    [1300] = 20, -- Fort Grief
    [1304] = 18, -- The Bathhouse
    [1307] = 15, -- Sweetwater Cascades
    [1310] = 40, -- Atoll of Immolation
    [1311] = 15, -- Ascendant Order Hideout
    [1312] = 22, -- Sareloth Grotto
    [1313] = 15, -- Systres Sisters Vault
    [1314] = 15, -- Sword's Rest Isle
    [1315] = 16, -- Abhain Chapel Crypts
    [1316] = 24, -- Old Coin Fort
    [1317] = 18, -- All Flags Islet
    [1318] = 16, -- High Isle
    [1319] = 15, -- Gonfalon Bay Outlaws Refuge
    [1321] = 15, -- Navire Dungeons
    [1325] = 26, -- Loom of the Untraveled Road
    [1327] = 16, -- The Undergrove
    [1328] = 15, -- Garick's Rest
    [1330] = 20, -- Brokerock Mine
    [1331] = 8, -- Death's Valor Keep
    [1335] = 16, -- Shipwreck Shoals
    [1336] = 25, -- Coral Cliffs
    [1337] = 16, -- Spire of the Crimson Coin
    [1338] = 24, -- Ghost Haven Bay
    [1342] = 24, -- Ossa Accentium
    [1343] = 38, -- Agony's Ascent
    [1345] = 18, -- Seaveil Spire
    [1360] = 12, -- Earthen Root Enclave
    [1361] = 10, -- Graven Deep
    [1363] = 16, -- Highhallow Hold
    [1364] = 18, -- Ancient Anchor Berth
    [1365] = 13, -- Eimhir's Cavern
    [1366] = 13, -- Glenmoril Ritual Site
    [1367] = 15, -- Vastyr Outlaws Refuge
    [1368] = 22, -- Y'ffre's Path
    [1369] = 12, -- Dreadsail Sea Witch Sanctum
    [1370] = 15, -- Castle Tonnere
    [1371] = 15, -- Vastyr Cathedral District
    [1372] = 18, -- Temple of Y'ffelon
    [1374] = 22, -- Fauns' Thicket
    [1376] = 22, -- Suncleft Grotto
    [1377] = 14, -- Clohaigh
    [1378] = 16, -- Steadfast Manor Cellars
    [1379] = 16, -- The Mad Maiden
    [1380] = 15, -- Garick's Rest Dungeons
    [1381] = 22, -- Y'ffre's Path Ruins
    [1383] = 16, -- Galen
    [1385] = 15, -- Draoife Dell
    [1386] = 18, -- Temple of Y'ffelon
    [1387] = 15, -- Ivyhame
    [1391] = 22, -- Emerald Glyphic Vault
    [1392] = 15, -- Shrine of the Golden Eye
    [1393] = 12, -- The Tranquil Catalog
    [1394] = 12, -- The Infinite Panopticon
    [1395] = 12, -- The Infinite Panopticon
    [1405] = 18, -- Tel Huulen Assembly Hall
    [1406] = 12, -- Shrine of Vaermina
    [1407] = 22, -- Tel Dreloth
    [1409] = 12, -- The Sidereal Cloisters
    [1410] = 6, -- Cenotaph of the Remnants
    [1411] = 15, -- The Rectory Corporea
    [1412] = 18, -- Necrom Outlaws Refuge
    [1413] = 14, -- Apocrypha
    [1414] = 17, -- Telvanni Peninsula
    [1416] = 12, -- The Underweave
    [1417] = 12, -- The Mythos
    [1423] = 22, -- Old Sailenmora Outpost
    [1432] = 16, -- Fogbreak Lighthouse
    [1433] = 18, -- Journey's End Lodgings
    [1434] = 20, -- Emissary's Enclave
    [1435] = 22, -- The Fair Winds
    [1437] = 12, -- Shadow Queen's Labyrinth
    [1438] = 28, -- Sword-Singer's Redoubt
    [1439] = 12, -- Shrine of Inevitable Secrets
    [1441] = 26, -- Loom of the Untraveled Road
    [1442] = 15, -- Hoperoot
    [1443] = 14, -- West Weald
    [1444] = 16, -- Legion's Rest
    [1448] = 15, -- Haldain Lumber Camp
    [1449] = 16, -- Varen's Watch
    [1450] = 12, -- Rustwall Catacombs
    [1454] = 10, -- Feldagard Keep
    [1455] = 17, -- Ceyond
    [1456] = 16, -- Sutch Mine
    [1457] = 22, -- Scholarium Outer Ruins
    [1458] = 12, -- The Mythos
    [1460] = 16, -- Valente Winery
    [1461] = 16, -- Outcast Inn Cellar
    [1462] = 13, -- Weatherleah
    [1464] = 45, -- Fargrave Outer Ruins
    [1465] = 16, -- Skingrad Outlaws Refuge
    [1466] = 15, -- Leftwheal Trading Post
    [1472] = 15, -- Gladesong Arboretum
    [1473] = 12, -- Tower of Unutterable Truths
    [1474] = 12, -- The Mythos
    [1475] = 4, -- Seat of Detritus
    [1479] = 22, -- Willowpond Haven
    [1481] = 26, -- Mota-ka
    [1483] = 16, -- Huntsman's Fortress
    [1484] = 28, -- Shehai Waystation
    [1485] = 16, -- Port Dufort
    [1487] = 24, -- Zhan Khaj Crest
    [1488] = 15, -- Wing of the Crow
    [1491] = 15, -- Rosewine Retreat
    [1492] = 22, -- Merryvine Estate
    [1494] = 22, -- Seabloom Villa
    [1495] = 15, -- Haven of the Five Companions
    [1496] = 7, -- Exiled Redoubt
    [1497] = 16, -- Lep Seclusa
    [1498] = 17, -- Dusk Keep
    [1499] = 26, -- Star Haven Adeptorium
    [1500] = 2, -- Kthendral Deep Mines
    [1501] = 20, -- Grand Gallery of Tamriel
    [1502] = 28, -- Solstice
    [1504] = 4, -- Coldharbour Colosseum
    [1505] = 12, -- Underground Sanctum
    [1506] = 12, -- Worm Cult Lair
    [1507] = 55, -- The Earth Forge
    [1508] = 16, -- Stirk
    [1509] = 26, -- Vosgah Shrine
    [1510] = 26, -- Sunport Palace District
    [1511] = 24, -- Vale of Revelry
    [1512] = 26, -- Carapace Cavern
    [1513] = 26, -- Tainted Leel
    [1514] = 22, -- Deetra Grotto
    [1515] = 26, -- Sunport Outlaws Refuge
    [1516] = 22, -- Corelanya Manor
    [1517] = 26, -- Li-Xal Pass
    [1518] = 24, -- Broken Light Temple
    [1520] = 26, -- Tarnur Mine
    [1521] = 18, -- The Colored Rooms
    [1534] = 26, -- Tide-Born Dream-Wallow
    [1535] = 12, -- Shrine of Sithis
    [1546] = 30, -- Shattered Mirror Isle
    [1547] = 16, -- Castle Skingrad
    [1548] = 12, -- Ossein Cage
    [1554] = 16, -- Theater of the Ancestors
    [1555] = 26, -- Bismuth Steam Baths
    [1556] = 24, -- The Sleepy Sloth
    [1557] = 15, -- Hero's Return
    [1584] = 13, -- Glenumbra
    -- 2.3.19: zones present in LibZone 9.01 (Sept 2026) but missing here.
    -- 6 are new since July (Update 51 / Season One: 1533, 1570, 1592,
    -- 1593, 1609, 1610); the rest were already in LibZone by April 2026
    -- but never made it into these tables. Values copy the existing entry
    -- named in each comment, as approved by the author; none are
    -- independently measured. Dev placeholders (174, 279, 917, 1107, 1171,
    -- 1175, 1204, 1346) are intentionally omitted.
    [1522] = 28, -- Xor-Hist | basis: Solstice (1502)
    [1523] = 22, -- A Battle at Sea | basis: Abecean Sea (555) - assumed on the Abecean Sea, per author
    [1524] = 26, -- Fissure Ruins | basis: Carapace Cavern (1512) - Daedric ruin in a bismuth cave
    [1526] = 28, -- Mor Naril | basis: Solstice (1502)
    [1527] = 26, -- Xul-Katama | basis: Carapace Cavern (1512) - delve
    [1528] = 26, -- Lair of the Black Worm | basis: Tainted Leel (1513) - outdoor Solstice delve
    [1529] = 26, -- Sea and Sword Lodge | basis: Carapace Cavern (1512) - delve
    [1530] = 26, -- Calindvale Gardens | basis: Tainted Leel (1513) - public dungeon
    [1531] = 26, -- Ashbound Hall | basis: Carapace Cavern (1512) - entered through a cave
    [1532] = 26, -- Xul-Haj | basis: Vakka-Bok Xanmeer (1079) - necropolis
    [1533] = 22, -- The Nowhere Vault | basis: neutral - see Nowhere Vault note
    [1536] = 13, -- Dwynnarth Crypts | basis: Bad Man's Hallows (284) - Glenumbra crypt
    [1537] = 28, -- Gristmung Hold | basis: Solstice (1502)
    [1538] = 10, -- Shivering Isles | basis: Chateau of the Ravenous Rodent (219)
    [1551] = 26, -- Naj-Caldeesh | basis: Vakka-Bok Xanmeer (1079) - dungeon
    [1552] = -1, -- Black Gem Foundry | basis: Vaults of Madness (11) - Coldharbour dungeon
    [1553] = -2, -- Writhing Fortress | basis: Coldharbour (347)
    [1559] = 35, -- Night Market | basis: Fargrave (1282)
    [1560] = 18, -- Hiddenspring Cottage | basis: Gold Coast (823) - house
    [1561] = 14, -- Wildgrown Chapel of Julianos | basis: West Weald (1443) - house
    [1562] = 40, -- Gossamer Crypt | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1563] = 40, -- Mournful Catacomb | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1564] = 40, -- Timeless Wallow | basis: Fargrave Outlaws Refuge (1293) - Night Market dungeon
    [1565] = 35, -- Opulent Ordeal | basis: Fargrave (1282) - Night Market trial
    [1566] = 28, -- Cradle of the Worm Colossus | basis: Solstice (1502) - house
    [1567] = 16, -- Druidspring Conservatory | basis: High Isle (1318) - house
    [1568] = 40, -- Night's Den | basis: Fargrave Outlaws Refuge (1293) - house
    [1569] = 22, -- Buccaneer Bay | basis: Abecean Sea (555) - island house, per author
    [1570] = 22, -- Voyage on the Abecean Sea | basis: Abecean Sea (555)
    [1574] = 13, -- Birien Manor | basis: Glenumbra (3)
    [1575] = 13, -- Hidden Library | basis: Glenumbra (3)
    [1577] = 13, -- Rols Boron's Warehouse | basis: Glenumbra (3)
    [1578] = 13, -- Daggerfall | basis: Glenumbra (3)
    [1579] = 10, -- Sage's Isle | basis: Glenumbra (3) minus 4C - fog-bound isle far to the north
    [1583] = 22, -- The Nowhere Vault | basis: neutral - see Nowhere Vault note
    [1592] = 4, -- March of Sacrifices | basis: March of Sacrifices (1055) - second instance
    [1593] = 24, -- Moon Hunter Keep | basis: Moon Hunter Keep (1052) - second instance
    [1594] = 13, -- Rogue's Refuge | basis: Glenumbra (3) - house, exterior entry over a crypt, per author
    [1595] = 18, -- Dancing Waters Wellspring | basis: Summerset (1011) - house, exterior per author
    [1597] = 3, -- Star-Gazer's Vigil | basis: The Reach (1207) - house
    [1609] = 22, -- Sheogorad Chateau | basis: Amaya Lake Lodge (995), per author
    [1610] = 16, -- Grotto of Desires | basis: Pantherfang Chapel (1277), per author
}

-- Pending zoneId verification (not found in LibZone's data as of API101050) -- currently inert, falls back to default:
--   "Amenos" = 27

-- Default temperature for any zone not in the table.
local DEFAULT_TEMP = 20

-- Interior/dungeon modifier: underground spaces are generally cooler in summer
-- and warmer in winter relative to outside. We apply a flat moderate modifier.
local INTERIOR_MODIFIER = -3

-------------------------------------------------------------------------------
-- UNIT CONVERSION HELPERS
-------------------------------------------------------------------------------

--- Converts a Celsius value to Fahrenheit.
--- @param celsius number
--- @return number
local function CelsiusToFahrenheit(celsius)
    return (celsius * 9 / 5) + 32
end

--- Returns a display-ready temperature string respecting the user's unit preference.
--- Always calculates internally in Celsius; converts only for display.
--- @param celsius number  The temperature in Celsius.
--- @return string         e.g. "23.4°C" or "74.1°F"
function lib.FormatTemperature(celsius)
    if lib.savedVars and lib.savedVars.useFahrenheit then
        return string.format("%.1f°F", CelsiusToFahrenheit(celsius))
    end
    return string.format("%.1f°C", celsius)
end

-------------------------------------------------------------------------------
-- TIME-OF-DAY MODIFIERS
--
-- Uses the hour (0-23) from LibClockTST:GetTime().
-- Tamriel's in-game day is roughly 2 real-world hours = 24 lore hours.
-- We model a simple diurnal curve:
--   Night (0–5):   -5°C
--   Dawn  (6–8):   -2°C
--   Day   (9–17):  +3°C
--   Dusk  (18–20): +1°C
--   Night (21–23): -4°C
-------------------------------------------------------------------------------
local function GetTimeOfDayModifier(hour)
    if hour >= 0 and hour <= 5 then
        return -5
    elseif hour >= 6 and hour <= 8 then
        return -2
    elseif hour >= 9 and hour <= 17 then
        return 3
    elseif hour >= 18 and hour <= 20 then
        return 1
    else
        return -4
    end
end

-- ZONE_BASE_TEMPS, ZONE_WEATHER, and ZONE_WATER_TEMPS above are the runtime
-- lookup tables, authored directly keyed by real, language-independent
-- zoneId -- see the header comment on ZONE_BASE_TEMPS for how they were
-- verified. There is no name-based resolution step at load time: no
-- LibZone:GetAllZoneData() call, no name -> zoneId inversion, nothing to
-- silently break on a punctuation mismatch. Every runtime lookup
-- (GetBaseTemperatureForZone, GetWaterTemperature, GetWeatherModifier,
-- GetCurrentTemperature, the settings-panel zone picker) reads these
-- tables directly by zoneId.
--
-- LibZone remains a hard ## DependsOn requirement -- it's still used for
-- GetCurrentZoneIds() and GetCurrentZoneAndGroupStatus() (delve/dungeon
-- detection), which are zone-status lookups, not name lookups.

local DEFAULT_WATER_TEMP  = 16
local DEFAULT_WEATHER     = { rainChance = 0.20, snowChance = 0.05 }

local RAIN_COOLING = -4   -- max °C cooling from rain
local SNOW_COOLING = -6   -- max °C cooling from snow

local function GetWeatherModifier(zoneId)
    local profile = ZONE_WEATHER[zoneId] or DEFAULT_WEATHER
    return (profile.rainChance * RAIN_COOLING) + (profile.snowChance * SNOW_COOLING)
end

-------------------------------------------------------------------------------
-- SWIMMING / WATER TEMPERATURE
--
-- Confirmed ESO API used:
--   IsUnitSwimming(unitTag) -> boolean isSwimming
--   Called with unitTag = "player".
--
-- When the player is swimming, CalculateTemperature returns the zone's water
-- temperature directly rather than the air temperature.  Water temps are
-- independent of time-of-day and weather.  Values are in ZONE_WATER_TEMPS above.
-------------------------------------------------------------------------------
local function GetWaterTemperature(zoneId)
    return ZONE_WATER_TEMPS[zoneId] or DEFAULT_WATER_TEMP
end

-------------------------------------------------------------------------------
-- CORE TEMPERATURE CALCULATION
-------------------------------------------------------------------------------

--- Returns the base temperature for a zone in Celsius, respecting:
---   1. User override on the exact current zone (e.g. a delve/dungeon that
---      has no climate table entry of its own)
---   2. User override on the climate zone used for the table lookup below
---      (e.g. the overland parent a delve inherits from)
---   3. Internal static table
---   4. Interior/dungeon penalty if appropriate
---   5. Default fallback
---
--- @param zoneId         number   The zone ID used for the base-temp table lookup
---                                (may be an overland parent; see CalculateTemperature).
--- @param isInterior     boolean  True if the player is indoors - via LibInteriorDetection if installed (any building/interior it detects), otherwise a delve/dungeon/trial fallback.
--- @param specificZoneId number|nil  The player's exact current zone ID, if it
---                                differs from zoneId (e.g. the delve itself,
---                                as opposed to the overland zone it inherits
---                                climate from). Checked first so overrides set
---                                on interior zones are actually honoured.
--- @return number   Base temperature in Celsius.
function lib.GetBaseTemperatureForZone(zoneId, isInterior, specificZoneId)
    -- Check for user override first (stored as string keys in saved vars).
    -- The exact zone the player is standing in takes priority over the
    -- climate zone used for the table fallback, so an override set on a
    -- delve/dungeon isn't shadowed by its overland parent.
    if lib.savedVars and lib.savedVars.zoneOverrides then
        if specificZoneId then
            local specificKey = tostring(specificZoneId)
            if lib.savedVars.zoneOverrides[specificKey] ~= nil then
                return lib.savedVars.zoneOverrides[specificKey]
            end
        end

        local svKey = tostring(zoneId)
        if lib.savedVars.zoneOverrides[svKey] ~= nil then
            return lib.savedVars.zoneOverrides[svKey]
        end
    end

    local base = ZONE_BASE_TEMPS[zoneId] or DEFAULT_TEMP

    if isInterior then
        base = base + INTERIOR_MODIFIER
    end

    return base
end

--- Calculates the full ambient temperature for a given zone and lore hour.
---
--- @param zoneId         number   The zone ID used for the base-temp table lookup
---                                (may be an overland parent zone; see
---                                GetCurrentTemperature).
--- @param isInterior     boolean  True if the player is indoors - via LibInteriorDetection if installed (any building/interior it detects), otherwise a delve/dungeon/trial fallback.
--- @param loreHour       number   Hour 0–23 from LibClockTST.
--- @param isSwimming     boolean  True if the player is currently swimming.
--- @param specificZoneId number|nil  The player's exact current zone ID; passed
---                                through so an override set on that specific
---                                zone (e.g. a delve) is honoured even when it
---                                has no climate table entry of its own.
--- @return number   Final ambient temperature in Celsius.
function lib.CalculateTemperature(zoneId, isInterior, loreHour, isSwimming, specificZoneId)
    -- Swimming overrides air temperature entirely: the player is submerged and
    -- feels the water temperature, not the air above the surface.
    -- Time-of-day and weather do not meaningfully affect water temperature.
    if isSwimming then
        return GetWaterTemperature(zoneId)
    end

    local base    = lib.GetBaseTemperatureForZone(zoneId, isInterior, specificZoneId)
    local timeMod = GetTimeOfDayModifier(loreHour)
    -- Interiors are shielded from both time-of-day and weather effects.
    if isInterior then
        return base + (timeMod * 0.3)   -- reduced diurnal swing indoors
    end
    local weatherMod = GetWeatherModifier(zoneId)
    return base + timeMod + weatherMod
end

--- Returns the current ambient temperature for the player's location.
---
--- Requires LibZone and LibClockTST to be available.
--- Returns nil if the required libraries have not been initialised yet.
---
--- @return number|nil   Temperature in Celsius, or nil on error.
--- @return string|nil   Zone name, or nil on error.
--- @return number|nil   Temperature in Fahrenheit, or nil on error.
--- @return string|nil   Pre-formatted temperature string using the user's preferred unit.
function lib.GetCurrentTemperature()
    -- Get current zone information via LibZone's confirmed API.
    -- LibZone is a hard ## DependsOn requirement, so it is guaranteed to be
    -- loaded here -- ESO would not have loaded this addon otherwise.
    -- currentZoneId is the specific zone (may be a delve or dungeon with no
    -- climate entry).  currentZoneParentId is the overland parent zone, which
    -- will always have a climate entry.  We use parentZoneId as a fallback for
    -- temperature lookups when the specific zone is unlisted.
    local zoneId, parentZoneId = LibZone:GetCurrentZoneIds()
    if not zoneId then
        return nil, nil
    end

    -- For climate lookups, use the specific zone if it has data, otherwise
    -- fall back to the parent (e.g. a Wrothgar delve inherits Wrothgar's climate).
    local climateZoneId = ZONE_BASE_TEMPS[zoneId] and zoneId or (parentZoneId or zoneId)

    -- Determine if we are in an interior zone. Prefers LibInteriorDetection's
    -- live, general-purpose indoor detection (catches ordinary buildings,
    -- player houses, and door transitions, not just delve/dungeon/trial)
    -- when it's installed; falls back to the original LibZone-based
    -- delve/dungeon/trial-only check otherwise, so this behaves exactly as
    -- before for anyone who doesn't have LibInteriorDetection.
    -- LibInteriorDetection is a NEW ## OptionalDependsOn (2.3.16) - not a
    -- hard requirement, since other addons may depend on LibZoneTemp
    -- without wanting to also pull in LibInteriorDetection.
    local isInterior
    if LibInteriorDetection and LibInteriorDetection.IsPlayerIndoors then
        local liveIsInterior = LibInteriorDetection.IsPlayerIndoors()
        if liveIsInterior ~= nil then
            isInterior = liveIsInterior
        end
    end
    if isInterior == nil then
        -- Fallback: LibInteriorDetection not installed, or its state hasn't
        -- been established yet (e.g. before its first EVENT_PLAYER_ACTIVATED).
        local _, _, isInDelve, isInPublicDungeon, isInGroupDungeon, isInTrial =
            LibZone:GetCurrentZoneAndGroupStatus()
        isInterior = isInDelve or isInPublicDungeon or isInGroupDungeon or isInTrial
    end

    -- Retrieve the current lore hour from LibClockTST.
    local loreHour = 12  -- sensible noon default if clock is unavailable
    if LibClockTST then
        local clock = LibClockTST:Instance()
        if clock then
            local timeData = clock:GetTime()
            if timeData and timeData.hour then
                loreHour = timeData.hour
            end
        end
    end

    -- Detect whether the player is currently swimming.
    -- IsUnitSwimming(unitTag) is a confirmed public ESO API function.
    local isSwimming = IsUnitSwimming("player") or false

    local temp     = lib.CalculateTemperature(climateZoneId, isInterior, loreHour, isSwimming, zoneId)
    local zoneName = GetZoneNameById(zoneId) or "Unknown Zone"

    -- Cache the result.
    lib._currentTemp           = temp
    lib._currentZoneId         = climateZoneId
    lib._currentSpecificZoneId = zoneId
    lib._currentSwimming       = isSwimming

    return temp, zoneName, CelsiusToFahrenheit(temp), lib.FormatTemperature(temp)
end

-------------------------------------------------------------------------------
-- LIVE UPDATE: Subscribe to LibClockTST for time-of-day driven updates
-- and to ESO events for zone-change driven updates.
-------------------------------------------------------------------------------

local function OnTimeUpdate(timeData)
    -- Recalculate and cache temperature on every lore-hour tick.
    -- This is called by LibClockTST's internal timer (default ~2 s real time).
    -- Debug output is no longer automatic; use /ztemp in chat to print on demand.
    lib.GetCurrentTemperature()
end

local function OnZoneChange(eventCode)
    -- Immediately recalculate when the player enters a new zone.
    lib.GetCurrentTemperature()
end

-------------------------------------------------------------------------------
-- SLASH COMMAND: /ztemp
--
-- Prints a one-shot debug snapshot to the chat window on demand.
-- ESO registers slash commands via the global SLASH_COMMANDS table.
-- The key must be lowercase and start with a slash.
-------------------------------------------------------------------------------

local function PrintDebugInfo()
    -- Force a fresh calculation so the output is never stale.
    local temp, zoneName = lib.GetCurrentTemperature()

    if not temp then
        d("[LibZoneTemp] Could not retrieve temperature. Are LibZone and LibClockTST loaded?")
        return
    end

    -- Retrieve the current lore time for the snapshot.
    local loreHour, loreMinute = 0, 0
    if LibClockTST then
        local clock = LibClockTST:Instance()
        if clock then
            local timeData = clock:GetTime()
            if timeData then
                loreHour   = timeData.hour   or 0
                loreMinute = timeData.minute  or 0
            end
        end
    end

    local zoneId         = lib._currentZoneId or 0
    local specificZoneId = lib._currentSpecificZoneId or zoneId
    local hasOverride    = lib.savedVars and lib.savedVars.zoneOverrides and
        (lib.savedVars.zoneOverrides[tostring(specificZoneId)] ~= nil or
         lib.savedVars.zoneOverrides[tostring(zoneId)] ~= nil)

    d(string.format("|cFFD700[LibZoneTemp]|r Zone: |cADD8E6%s|r", zoneName))
    d(string.format("  Temperature : |cFFFFFF%s|r  (%.1f°C / %.1f°F)",
        lib.FormatTemperature(temp), temp, (temp * 9 / 5) + 32))
    d(string.format("  Lore time   : |cFFFFFF%02d:%02d|r", loreHour, loreMinute))
    d(string.format("  Zone ID     : |cFFFFFF%d|r%s",
        zoneId, hasOverride and "  |cFF8800[override active]|r" or ""))
    d(string.format("  Swimming    : |cFFFFFF%s|r%s",
        tostring(lib._currentSwimming or false),
        (lib._currentSwimming) and string.format("  (water temp: %.1f°C)", GetWaterTemperature(zoneId)) or ""))
end

local function InitializeSubscriptions()
    -- Subscribe to LibClockTST for real-time updates.
    if LibClockTST then
        local clock = LibClockTST:Instance()
        if clock then
            clock:RegisterForTime(ADDON_ID, OnTimeUpdate)
        end
    end

    -- Listen for zone change events via ESO's native event system.
    EVENT_MANAGER:RegisterForEvent(ADDON_ID, EVENT_PLAYER_ACTIVATED, OnZoneChange)

    -- Register the /ztemp slash command.
    -- SLASH_COMMANDS is a global table in ESO; keys are the slash strings (lowercase).
    SLASH_COMMANDS["/ztemp"] = function()
        PrintDebugInfo()
    end
end

-------------------------------------------------------------------------------
-- SETTINGS MENU (LibAddonMenu-2.0)
-------------------------------------------------------------------------------

local function BuildSettingsMenu()
    -- LibAddonMenu-2.0 is a hard ## DependsOn requirement, so LibAddonMenu2
    -- is guaranteed to exist here -- ESO would not have loaded this addon
    -- otherwise.
    local LAM = LibAddonMenu2

    local panelData = {
        type        = "panel",
        name        = "LibZoneTemp",
        displayName = "LibZoneTemp Settings",
        author      = "@Kreksar5 and Claude.ai",
        version     = tostring(LIB_VERSION),
        website     = "",
        slashCommand = "/libzonetemp",
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel(ADDON_ID .. "Panel", panelData)

    -- ── Helper: build zone picker choices from ESO's own native zone API ────
    -- We build a simple sorted list of zone names and their IDs so the user
    -- can pick a zone from a dropdown. This enumerates every zoneIndex via
    -- the confirmed native functions GetNumZones() / GetZoneId(zoneIndex) /
    -- GetZoneNameById(zoneId) -- no LibZone (or any other third-party
    -- library) is involved in this lookup, and the names shown are
    -- automatically in the player's own client language since
    -- GetZoneNameById() returns the client's localized string directly.
    local zoneChoices    = {}   -- display strings
    local zoneChoiceKeys = {}   -- corresponding zoneIds (integers)

    local sorted = {}
    local seenZoneIds = {}
    local numZones = GetNumZones()
    for zoneIndex = 0, numZones do
        local zId = GetZoneId(zoneIndex)
        if zId and zId > 0 and not seenZoneIds[zId] then
            seenZoneIds[zId] = true
            local zName = GetZoneNameById(zId)
            if zName and zName ~= "" then
                sorted[#sorted + 1] = { id = zId, name = zName }
            end
        end
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    for _, entry in ipairs(sorted) do
        zoneChoices[#zoneChoices + 1]    = entry.name
        zoneChoiceKeys[#zoneChoiceKeys + 1] = entry.id
    end

    -- Selected zone index (1-based into zoneChoices).
    local selectedZoneIdx = 1

    -- ── Controls ─────────────────────────────────────────────────────────────
    local optionsData = {
        -- Section header
        {
            type = "header",
            name = "Display",
        },
        -- Temperature unit toggle
        {
            type    = "checkbox",
            name    = "Display in Fahrenheit",
            tooltip = "When enabled, temperatures are displayed in Fahrenheit (°F) instead of " ..
                      "Celsius (°C). All internal calculations remain in Celsius; only the " ..
                      "display and lib.FormatTemperature() output are affected.",
            getFunc = function()
                return lib.savedVars and lib.savedVars.useFahrenheit or false
            end,
            setFunc = function(value)
                if lib.savedVars then
                    lib.savedVars.useFahrenheit = value
                end
            end,
            default = DEFAULTS.useFahrenheit,
        },
        -- Section header
        {
            type = "header",
            name = "Zone Temperature Overrides",
        },
        -- Description
        {
            type = "description",
            text = "Select a zone below and set a custom base temperature (°C). " ..
                   "Set to blank/zero to revert to the library default. " ..
                   "Note: the override applies to the BASE temperature only; " ..
                   "time-of-day and climate modifiers are still applied on top.",
        },
        -- Celsius / Fahrenheit reference chart, with a sense of what kind of
        -- zone tends to land in each range, to help pick a sensible value.
        {
            type = "description",
            text = "Temperature reference:\n" ..
                   "  -40°C to -20°C (-40°F to -4°F)  — glacial peaks, Coldharbour depths\n" ..
                   "  -20°C to  -5°C ( -4°F to 23°F)  — frozen tundra, harsh winter zones\n" ..
                   "   -5°C to   5°C ( 23°F to 41°F)  — cold moors, snowy highlands\n" ..
                   "    5°C to  15°C ( 41°F to 59°F)  — cool temperate woodland\n" ..
                   "   15°C to  25°C ( 59°F to 77°F)  — mild/temperate, Mediterranean-like\n" ..
                   "   25°C to  35°C ( 77°F to 95°F)  — warm jungle, humid swamp\n" ..
                   "   35°C to  45°C ( 95°F to 113°F) — hot savanna, tropical coast\n" ..
                   "        45°C+   (      113°F+)   — scorching desert wastes",
        },
        -- Section header for the active-overrides list
        {
            type = "header",
            name = "Currently Active Overrides",
        },
        -- Dynamic list of every zone override currently set, refreshed
        -- whenever the panel is (re)opened or an override is added/removed.
        {
            type = "description",
            text = function()
                if not (lib.savedVars and lib.savedVars.zoneOverrides) then
                    return "No overrides set."
                end

                local entries = {}
                for svKey, temp in pairs(lib.savedVars.zoneOverrides) do
                    local zId   = tonumber(svKey)
                    local zName = (zId and GetZoneNameById(zId))
                    if not zName or zName == "" then
                        zName = "Zone " .. svKey
                    end
                    local fTemp = (temp * 9 / 5) + 32
                    entries[#entries + 1] = {
                        name = zName,
                        text = string.format("  %s: %.1f°C / %.1f°F", zName, temp, fTemp),
                    }
                end

                if #entries == 0 then
                    return "No overrides currently set."
                end

                table.sort(entries, function(a, b) return a.name < b.name end)

                local lines = {}
                for _, entry in ipairs(entries) do
                    lines[#lines + 1] = entry.text
                end
                return table.concat(lines, "\n")
            end,
        },
    }

    -- Only add zone override controls if LibZone provided us zone data.
    if #zoneChoices > 0 then
        -- Dropdown to pick zone
        optionsData[#optionsData + 1] = {
            type    = "dropdown",
            name    = "Zone to Override",
            tooltip = "Choose which zone to set a temperature override for.",
            choices = zoneChoices,
            getFunc = function()
                return zoneChoices[selectedZoneIdx] or zoneChoices[1]
            end,
            setFunc = function(value)
                for i, name in ipairs(zoneChoices) do
                    if name == value then
                        selectedZoneIdx = i
                        break
                    end
                end
            end,
            default = zoneChoices[1],
        }

        -- EditBox for temperature value.
        -- LAM's editbox fires setFunc when the user presses Enter or moves focus
        -- away from the field.  The "Apply Override" button below provides an
        -- explicit submit action for users who expect one.
        --
        -- We store the pending value in a closure variable so the button can
        -- read whatever is currently typed without relying on LAM internals.
        local pendingOverrideValue = ""

        optionsData[#optionsData + 1] = {
            type         = "editbox",
            name         = "Override Base Temp (°C)",
            tooltip      = "Enter the base temperature in Celsius for the selected zone. " ..
                           "Press Enter, click away, or use the Apply button to save. " ..
                           "Leave empty or enter 0 to remove the override.",
            isMultiLine  = false,
            maxChars     = 6,
            getFunc      = function()
                if not lib.savedVars then return "" end
                local zId  = zoneChoiceKeys[selectedZoneIdx]
                local svKey = tostring(zId)
                local val   = lib.savedVars.zoneOverrides[svKey]
                return val and tostring(val) or ""
            end,
            setFunc      = function(value)
                -- Cache for the Apply button and also save immediately on
                -- Enter / focus-loss (standard LAM editbox behaviour).
                pendingOverrideValue = value
                if not lib.savedVars then return end
                local zId   = zoneChoiceKeys[selectedZoneIdx]
                local svKey = tostring(zId)
                local num   = tonumber(value)
                if num and num ~= 0 then
                    lib.savedVars.zoneOverrides[svKey] = num
                else
                    lib.savedVars.zoneOverrides[svKey] = nil
                end
                -- Recalculate with the new override immediately.
                lib.GetCurrentTemperature()
            end,
            default      = "",
        }

        -- Explicit "Apply Override" button — submits whatever is currently in
        -- pendingOverrideValue.  This gives users a clear, unambiguous way to
        -- commit their override in addition to the Enter/focus-loss path above.
        optionsData[#optionsData + 1] = {
            type    = "button",
            name    = "Apply Override",
            tooltip = "Save the temperature override for the currently selected zone. " ..
                      "You can also press Enter in the text field above to save.",
            func    = function()
                if not lib.savedVars then return end
                local zId   = zoneChoiceKeys[selectedZoneIdx]
                local svKey = tostring(zId)
                local num   = tonumber(pendingOverrideValue)
                if num and num ~= 0 then
                    lib.savedVars.zoneOverrides[svKey] = num
                else
                    lib.savedVars.zoneOverrides[svKey] = nil
                end
                lib.GetCurrentTemperature()
            end,
        }

        -- Button to clear all overrides
        optionsData[#optionsData + 1] = {
            type    = "button",
            name    = "Clear All Overrides",
            tooltip = "Removes all zone temperature overrides, reverting to library defaults.",
            func    = function()
                if lib.savedVars then
                    lib.savedVars.zoneOverrides = {}
                    lib.GetCurrentTemperature()
                end
            end,
            isDangerous = true,
        }
    else
        -- LibZone data not available; show a notice.
        optionsData[#optionsData + 1] = {
            type = "description",
            text = "|cFF4444Warning:|r LibZone zone data could not be loaded. " ..
                   "Zone override controls are unavailable.",
        }
    end

    LAM:RegisterOptionControls(ADDON_ID .. "Panel", optionsData)
end

-------------------------------------------------------------------------------
-- PUBLIC API SUMMARY
--
--   lib.GetCurrentTemperature()
--       -> number|nil tempCelsius, string|nil zoneName,
--          number|nil tempFahrenheit, string|nil formattedString
--       Returns the current ambient temperature for the player's zone.
--       When the player is swimming, returns the zone's water temperature
--       directly (time-of-day and weather modifiers are not applied to water).
--       formattedString respects the user's unit preference ("23.4°C" / "74.1°F").
--
--   lib.GetBaseTemperatureForZone(zoneId, isInterior)
--       -> number tempCelsius
--       Returns the base temperature for a given zone ID (before time/weather).
--
--   lib.CalculateTemperature(zoneId, isInterior, loreHour, isSwimming)
--       -> number tempCelsius
--       Returns the full temperature for arbitrary input values. Always Celsius.
--       Pass isSwimming = true to get the zone's water temperature instead.
--
--   lib.FormatTemperature(celsius)
--       -> string   e.g. "23.4°C" or "74.1°F"
--       Converts and formats a Celsius value using the user's saved unit preference.
--       Safe to call before savedVars is loaded (falls back to Celsius).
--
--   Slash command: /ztemp
--       Prints a one-shot debug snapshot to chat showing zone name, temperature
--       (both units), current lore time, zone ID, override status, and whether
--       the player is swimming (with the zone's water temperature if so).
--
--   lib.savedVars.useFahrenheit (boolean)
--       Toggle via settings menu. When true, FormatTemperature() returns °F.
--
--   lib.savedVars.zoneOverrides (table)
--       Map of tostring(zoneId) -> number (Celsius).  Set via settings menu.
--
--   lib._currentSwimming (boolean)
--       Cached swimming state from the last GetCurrentTemperature() call.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- INITIALISATION
-------------------------------------------------------------------------------

local function OnAddonLoaded(eventCode, addonName)
    -- Only initialise when our own addon fires the event.
    if addonName ~= ADDON_ID then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_ID, EVENT_ADD_ON_LOADED)

    -- Initialise saved variables using ESO's built-in ZO_SavedVars wrapper.
    --
    -- GetWorldName() ("EU Megaserver" / "NA Megaserver" / "PTS") is passed as
    -- the namespace argument so each server gets its own nested save-data
    -- table. Without this, ZO_SavedVars:NewAccountWide stores everything
    -- under one shared account-wide table regardless of server, so playing
    -- on EU, then NA, then PTS on the same account would each overwrite the
    -- other's zone overrides. This does mean any overrides set before this
    -- fix will appear "reset" once -- they're still in the file under the
    -- old un-namespaced location, just not read anymore; this is a one-time
    -- cost of separating the data correctly.
    lib.savedVars = ZO_SavedVars:NewAccountWide(
        "LibZoneTempSavedVars",  -- matches the ## SavedVariables entry in the .txt
        1,                       -- version; increment when DEFAULTS structure changes
        GetWorldName(),          -- namespace: separates EU / NA / PTS data
        DEFAULTS
    )

    -- Set up clock and zone event listeners.
    InitializeSubscriptions()

    -- Build the settings panel.
    BuildSettingsMenu()

    -- Do an initial temperature calculation.
    lib.GetCurrentTemperature()
end

EVENT_MANAGER:RegisterForEvent(ADDON_ID, EVENT_ADD_ON_LOADED, OnAddonLoaded)
