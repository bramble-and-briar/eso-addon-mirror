TeamShadowsManager = TeamShadowsManager or {}

local PBT = TeamShadowsManager

PBT.name = "TeamShadowsManager"
PBT.displayName = "Team Shadows Manager"
PBT.version = "1.1.20"
PBT.savedVariableName = "TeamShadowsManagerSavedVariables"
PBT.savedVariableVersion = 1

PBT.defaults = {
    language = "fr",
    enabled = true,
    unlocked = false,
    scale = 1.0,
    color = { r = 1, g = 0.12, b = 0.08, a = 1 },
    goColor = { r = 0.2, g = 1, b = 0.2, a = 1 },
    x = 0,
    y = -220,
    menuButtonEnabled = true,
    menuButtonX = 0,
    menuButtonY = 0,
    menuButtonSize = 46,
    managerWindowX = 0,
    managerWindowY = -40,
    soundEnabled = true,
    lockoutSeconds = 30,
    timerOverrides = {},
    instanceTimerEnabled = {},
    bossTimerEnabled = {},
    customAliases = {},
    bossSpawnTimers = true,
    useSamuraiTimers = true,
    showMechanicTimers = true,
    nahvPortalHpWarning = true,
    bahseiRaidOptions = true,
    bahseiWallArrows = true,
    bahseiGhostCounter = true,
    bahseiGhostCall = true,
    bahseiGhostReceive = true,
    bahseiGhostTotal = 24,
    bahseiGhostThreshold = 5,
    narrationDebug = false,
    practiceSeconds = 10,
    groupCountdownEnabled = true,
    groupCountdownSeconds = 10,
    groupCountdownDpsDelay = 0,
    groupCountdownBroadcast = true,
    groupRendezvousReceive = false,
    groupBeaconTextureId = 1,
    groupBeaconColor = { r = 0.82, g = 0.11, b = 0.11 },
    groupBeaconLabel = "auto",
    groupBeaconCustomLabel = "",
    groupBeaconNextNumber = 1,
    groupBeaconSize = 112,
    groupBeaconHeight = 0,
    groupBeaconDuration = 8,
    groupBeaconPlacementEnabled = false,
    groupBeaconSavedMarkers = {},
    groupBeaconMarkerSets = {},
    groupBeaconMarkerSetSlot = 1,
    groupBeaconMarkerSetName = "",
    groupBeaconDirectoryKey = "",
    groupBeaconDisplayMode = "all",
    groupBeaconDisplayLabel = "all",
    autoPracticeOnDummyReset = true,
    bossNameTimers = false,
    bossUnitDetection = false,
    genericCinematicTimers = false,
    genericCinematicSeconds = 8,
    worldBossTimers = false,
    asOlmsFourthLanding = true,
    asOlmsLandingSeconds = 20,
}

PBT.beaconTextureChoices = {
    { label = "Carre rouge", value = 1 },
    { label = "Carre bleu", value = 2 },
    { label = "Carre jaune", value = 3 },
    { label = "Carre vert", value = 4 },
    { label = "Carre orange", value = 5 },
    { label = "Carre rose", value = 6 },
    { label = "Marker bleu clair", value = 7 },
    { label = "Carre MT", value = 8 },
    { label = "Carre OT", value = 9 },
    { label = "Fleche", value = 10 },
    { label = "Fleche verte", value = 11 },
    { label = "Shadow test", value = 12 },
}

PBT.beaconLabelChoices = {
    { label = "Auto 1-10", value = "auto" },
    { label = "1", value = "1" },
    { label = "2", value = "2" },
    { label = "3", value = "3" },
    { label = "4", value = "4" },
    { label = "5", value = "5" },
    { label = "6", value = "6" },
    { label = "7", value = "7" },
    { label = "8", value = "8" },
    { label = "9", value = "9" },
    { label = "10", value = "10" },
    { label = "H1", value = "H1" },
    { label = "H2", value = "H2" },
    { label = "MT", value = "MT" },
    { label = "OT", value = "OT" },
}

PBT.beaconLabelIds = {
    ["1"] = 1,
    ["2"] = 2,
    ["3"] = 3,
    ["4"] = 4,
    ["5"] = 5,
    ["6"] = 6,
    ["7"] = 7,
    ["8"] = 8,
    ["9"] = 9,
    ["10"] = 10,
    H1 = 11,
    H2 = 12,
    MT = 13,
    OT = 14,
}

-- Timings are centralized here. Only log/game-triggered timers should be used
-- for automatic prebuff; boss-name and boss-unit modes stay legacy/off by default.
PBT.trials = {
    aetherianArchive = {
        name = "Aetherian Archive",
        bosses = {},
    },
    sanctumOphidia = {
        name = "Sanctum Ophidia",
        bosses = {},
    },
    helRaCitadel = {
        name = "Hel Ra Citadel",
        bosses = {},
    },
    rockgrove = {
        name = "Rockgrove",
        bosses = {
            ["oaxiltso"] = { displayName = "Oaxiltso", seconds = 11, aliases = { "oaxiltso" } },
            ["flame-herald bahsei"] = { displayName = "Flame-Herald Bahsei", seconds = 15, aliases = { "heraut des flammes bahsei" } },
            ["xalvakka"] = { displayName = "Xalvakka", seconds = 18, aliases = { "xalvakka" } },
        },
    },
    dreadsailReef = {
        name = "Dreadsail Reef",
        bosses = {
            ["lylanar"] = { displayName = "Lylanar", seconds = 11, aliases = { "lylanar" } },
            ["turlassil"] = { displayName = "Turlassil", seconds = 11, aliases = { "turlassil" } },
            ["reef guardian"] = { displayName = "Reef Guardian", seconds = 15, aliases = { "gardien du recif" } },
            ["taleria"] = { displayName = "Taleria", seconds = 18, aliases = { "tideborn taleria", "fleet queen taleria", "taleria nee-des-marees" } },
        },
    },
    sunspire = {
        name = "Sunspire",
        bosses = {
            ["lokkestiiz"] = { displayName = "Lokkestiiz", seconds = 11, aliases = { "lokkestiiz" } },
            ["yolnahkriin"] = { displayName = "Yolnahkriin", seconds = 12, aliases = { "yolnahkriin" } },
            ["nahviintaas"] = { displayName = "Nahviintaas", seconds = 18, aliases = { "nahviintaas" } },
        },
    },
    kynesAegis = {
        name = "Kyne's Aegis",
        bosses = {
            ["yandir the butcher"] = { displayName = "Yandir the Butcher", seconds = 11, aliases = { "yandir le boucher" } },
            ["captain vrol"] = { displayName = "Captain Vrol", seconds = 14, aliases = { "capitaine vrol" } },
            ["lord falgravn"] = { displayName = "Lord Falgravn", seconds = 20, aliases = { "seigneur falgravn" } },
        },
    },
    cloudrest = {
        name = "Cloudrest",
        bosses = {
            ["shade of galenwe"] = { displayName = "Shade of Galenwe", seconds = 9, aliases = { "ombre de galenwe" } },
            ["shade of relequen"] = { displayName = "Shade of Relequen", seconds = 9, aliases = { "ombre de relequen" } },
            ["shade of siroria"] = { displayName = "Shade of Siroria", seconds = 9, aliases = { "ombre de siroria" } },
            ["z'maja"] = { displayName = "Z'Maja", seconds = 9.1, source = "Samurai", aliases = { "zmaja", "z'maja" } },
        },
    },
    lucentCitadel = {
        name = "Lucent Citadel",
        bosses = {
            ["orphic shattered shard"] = { displayName = "Orphic Shattered Shard", seconds = 12, aliases = { "fragment brise orphique" } },
            ["arcane knot"] = { displayName = "Arcane Knot", seconds = 14 },
            ["xoryn"] = { displayName = "Xoryn", seconds = 18, aliases = { "xoryn" } },
        },
    },
    osseinCage = {
        name = "Ossein Cage",
        bosses = {},
    },
    sanitysEdge = {
        name = "Sanity's Edge",
        bosses = {
            ["exarchanic yaseyla"] = { displayName = "Exarchanic Yaseyla", seconds = 12, aliases = { "exarchanique yaseyla" } },
            ["archwizard twelvane"] = { displayName = "Archwizard Twelvane", seconds = 14 },
            ["ansuul the tormentor"] = { displayName = "Ansuul the Tormentor", seconds = 18, aliases = { "ansuul la tormentrice" } },
        },
    },
    asylumSanctorium = {
        name = "Asylum Sanctorium",
        bosses = {
            ["saint llothis the pious"] = { displayName = "Saint Llothis the Pious", seconds = 9, aliases = { "saint llothis le pieux" } },
            ["saint felms the bold"] = { displayName = "Saint Felms the Bold", seconds = 9, aliases = { "saint felms l'audacieux" } },
            ["saint olms the just"] = { displayName = "Saint Olms the Just", seconds = 14, aliases = { "saint olms le juste" } },
        },
    },
    mawOfLorkhaj = {
        name = "Maw of Lorkhaj",
        bosses = {
            ["zhaj'hassa the forgotten"] = { displayName = "Zhaj'hassa the Forgotten", seconds = 12, aliases = { "zhaj'hassa l'oublie" } },
            ["rakkhat"] = { displayName = "Rakkhat", seconds = 18, aliases = { "rakkhat" } },
        },
    },
    hallsOfFabrication = {
        name = "Halls of Fabrication",
        bosses = {
            ["hunter-killer fabricants"] = { displayName = "Hunter-Killer Fabricants", seconds = 22.1, source = "Samurai", aliases = { "chasseur-tueur fabricants", "chasseur-tueur negatrix" } },
            ["pinnacle factotum"] = { displayName = "Pinnacle Factotum", seconds = 7.2, manualOnly = true, aliases = { "factotum du pinacle" } },
            ["reclaimer reducer reactor"] = { displayName = "Reclaimer / Reducer / Reactor", seconds = 9.3, manualOnly = true, aliases = { "reclaimer", "reducer", "reactor", "recuperateur", "reducteur", "reacteur" } },
            ["assembly general"] = { displayName = "Assembly General", seconds = 16, aliases = { "assembleur general" } },
        },
    },
    infiniteArchive = {
        name = "Infinite Archive",
        bosses = {
            ["tho'at replicanum"] = { displayName = "Tho'at Replicanum", seconds = 8, aliases = { "thoat replicanum", "tho'at replicanum" } },
            ["tho'at shard"] = { displayName = "Tho'at Shard", seconds = 5, aliases = { "thoat shard", "tho'at shard", "fragment de tho'at" } },
            ["tho'at frost atronach"] = { displayName = "Tho'at Frost Atronach", seconds = 5, aliases = { "thoat frost atronach", "tho'at frost atronach", "atronach de glace de tho'at" } },
            ["tho'at mantikora"] = { displayName = "Tho'at Mantikora", seconds = 5, aliases = { "thoat mantikora", "mantikora", "manti" } },
            ["tho'at dragon"] = { displayName = "Tho'at Dragon", seconds = 5, aliases = { "thoat dragon", "dragon" } },
            ["marauder bittog"] = { displayName = "Marauder Bittog", seconds = 6, aliases = { "maraudeur bittog" } },
            ["marauder gothmau"] = { displayName = "Marauder Gothmau", seconds = 6, aliases = { "maraudeur gothmau" } },
            ["marauder hilkarax"] = { displayName = "Marauder Hilkarax", seconds = 6, aliases = { "maraudeur hilkarax" } },
            ["marauder ulmor"] = { displayName = "Marauder Ulmor", seconds = 6, aliases = { "maraudeur ulmor" } },
            ["marauder zulfimbul"] = { displayName = "Marauder Zulfimbul", seconds = 6, aliases = { "maraudeur zulfimbul" } },
            ["gw the pilferer"] = { displayName = "Gw the Pilferer", seconds = 4, aliases = { "gw le chapardeur", "gw le voleur" } },
        },
    },
}

-- Stable, localized list of automatic timers shown in the Manager. The keys
-- are intentionally independent from localized NPC names and SavedVariables.
PBT.timerBossDefinitions = {
    cloudrest = {
        { key = "zmaja", fr = "Z'Maja", en = "Z'Maja", aliases = { "z'maja", "zmaja" } },
    },
    hallsOfFabrication = {
        { key = "hunterKillers", fr = "Fabricants chasseurs-tueurs", en = "Hunter-Killer Fabricants", aliases = { "hunter-killer", "hunter killer", "chasseur-tueur" } },
        { key = "pinnacle", fr = "Factotum du Pinacle", en = "Pinnacle Factotum", aliases = { "pinnacle", "pinacle" } },
        { key = "triplets", fr = "Récupérateur / Réducteur / Réacteur", en = "Reclaimer / Reducer / Reactor", aliases = { "triplets", "reclaimer", "reducer", "reactor", "recuperateur", "reducteur", "reacteur", "hof triplets" } },
    },
    asylumSanctorium = {
        { key = "olms", fr = "Saint Olms le Juste", en = "Saint Olms the Just", aliases = { "olms" } },
    },
    mawOfLorkhaj = {
        { key = "zhajhassa", fr = "Zhaj'hassa l'Oublié", en = "Zhaj'hassa the Forgotten", aliases = { "zhaj'hassa", "zhajhassa" } },
        { key = "rakkhat", fr = "Rakkhat", en = "Rakkhat", aliases = { "rakkhat" } },
    },
    aetherianArchive = {
        { key = "varlariel", fr = "Varlariel", en = "Varlariel", aliases = { "varlariel" } },
    },
    sunspire = {
        { key = "lokkestiiz", fr = "Lokkestiiz", en = "Lokkestiiz", aliases = { "lokkestiiz" } },
        { key = "yolnahkriin", fr = "Yolnahkriin", en = "Yolnahkriin", aliases = { "yolnahkriin" } },
        { key = "nahviintaas", fr = "Nahviintaas", en = "Nahviintaas", aliases = { "nahviintaas" } },
    },
    kynesAegis = {
        { key = "falgravn", fr = "Seigneur Falgravn", en = "Lord Falgravn", aliases = { "falgravn" } },
    },
    dreadsailReef = {
        { key = "taleria", fr = "Taleria Née-des-marées", en = "Tideborn Taleria", aliases = { "taleria" } },
    },
    sanitysEdge = {
        { key = "yaseyla", fr = "Yaseyla l'Exarchanique", en = "Exarchanic Yaseyla", aliases = { "yaseyla" } },
    },
    rockgrove = {
        { key = "oaxiltso", fr = "Oaxiltso", en = "Oaxiltso", aliases = { "oaxiltso" } },
        { key = "bahsei", fr = "Le Héraut des flammes Bahsei", en = "Flame-Herald Bahsei", aliases = { "bahsei", "le heraut des flammes bahsei", "flame-herald bahsei" } },
        { key = "xalvakka", fr = "Xalvakka", en = "Xalvakka", aliases = { "xalvakka" } },
    },
}

PBT.zoneAliases = {
    hallsOfFabrication = {
        "Halls of Fabrication",
        "Salles de la Fabrication",
    },
    sunspire = {
        "Sunspire",
        "Sollance",
    },
    cloudrest = {
        "Cloudrest",
        "Pas-des-Nuees",
        "Pas des Nuees",
    },
    asylumSanctorium = {
        "Asylum Sanctorium",
        "Asile sanctuaire",
    },
    kynesAegis = {
        "Kyne's Aegis",
        "Egide de Kyne",
    },
    dreadsailReef = {
        "Dreadsail Reef",
        "Recif des Voiles funestes",
    },
    sanitysEdge = {
        "Sanity's Edge",
        "Bord de la Folie",
    },
    mawOfLorkhaj = {
        "Maw of Lorkhaj",
        "Gueule de Lorkhaj",
    },
    aetherianArchive = {
        "Aetherian Archive",
        "Archive aetherienne",
    },
    sanctumOphidia = {
        "Sanctum Ophidia",
        "Sanctum Ophidia",
    },
    helRaCitadel = {
        "Hel Ra Citadel",
        "Citadelle d'Hel Ra",
    },
    rockgrove = {
        "Rockgrove",
        "Rochebosque",
    },
    lucentCitadel = {
        "Lucent Citadel",
        "Citadelle lucide",
    },
    osseinCage = {
        "Ossein Cage",
        "Cage d'ossein",
        "Ossein",
    },
}

PBT.zoneIds = {
    helRaCitadel = { [636] = true },
    hallsOfFabrication = { [975] = true },
    sanctumOphidia = { [639] = true },
    sunspire = { [1121] = true },
    cloudrest = { [1051] = true },
    asylumSanctorium = { [1000] = true },
    kynesAegis = { [1196] = true },
    rockgrove = { [1263] = true },
    dreadsailReef = { [1344] = true },
    sanitysEdge = { [1427] = true },
    mawOfLorkhaj = { [725] = true },
    aetherianArchive = { [638] = true },
}

PBT.hpThresholdAnnouncements = {
    {
        zoneKey = "dreadsailReef",
        bossNames = { "tideborn taleria", "taleria nee-des-marees", "taleria" },
        thresholds = {
            { percent = 20, text = "TALERIA EXECUTE", color = { 1, 0.15, 0.1 } },
        },
    },
    {
        zoneKey = "sanitysEdge",
        bossNames = { "exarchanic yaseyla", "yaseyla l'exarchanique", "yaseyla" },
        thresholds = {
            { percent = 90, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
            { percent = 70, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
            { percent = 60, text = "YASEYLA PORTAILS", color = { 0.3, 0.8, 1 } },
            { percent = 50, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
            { percent = 35, text = "YASEYLA PORTAILS", color = { 0.3, 0.8, 1 } },
            { percent = 30, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
            { percent = 20, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
            { percent = 10, text = "YASEYLA WAMASU", color = { 1, 1, 1 } },
        },
    },
}

PBT.bossLookup = {}

PBT.samuraiNarrationTimers = {
    -- Curated boss timers only: spawn / RP / invulnerability exit windows.
    -- Source: Samurai 2.12.0 bossLines, kept English because ESO localized text is not literal.

    -- Halls of Fabrication
    { pattern = "Reprocessing yard contamination critical", displayName = "HoF Triplets", seconds = 9.3, plain = true, zoneKey = "hallsOfFabrication", lockoutKey = "hofTripletsArch", lockoutSeconds = 600, source = "Samurai" },
    { pattern = "There! Somethings coming through! Another fabricant!", displayName = "Pinnacle Factotum", seconds = 7.2, plain = true, zoneKey = "hallsOfFabrication", lockoutKey = "hofPinnacleNarration", lockoutSeconds = 600, source = "Samurai" },

    -- Maw of Lorkhaj
    { pattern = "Don't .... It's ... trap.", displayName = "Zhaj'hassa", seconds = 15.6, plain = false, zoneKey = "mawOfLorkhaj", lockoutKey = "molZhajNarration", lockoutSeconds = 600, source = "Samurai" },
    { pattern = "Have you not heard me? Have I not", displayName = "Rakkhat", seconds = 24.4, plain = true, zoneKey = "mawOfLorkhaj", lockoutKey = "molRakkhatNarration", lockoutSeconds = 600, source = "Samurai" },

    -- Aetherian Archive
    { pattern = "The Celestial Mage summons me to", displayName = "Varlariel", seconds = 4.4, plain = true, zoneKey = "aetherianArchive", lockoutKey = "aaVarlarielNarration", lockoutSeconds = 600, source = "Samurai" },

    -- Sunspire
    { pattern = "To restore the natural order. To reclaim all that was and will be", displayName = "Nahviintaas", seconds = 21.2, plain = true, zoneKey = "sunspire", lockoutKey = "ssNahviintaasIntro", lockoutSeconds = 600, source = "Samurai" },

    -- Dreadsail Reef
    { pattern = "Barging into a lady's private chambers. You are bold.", displayName = "Taleria", seconds = 23.5, plain = true, zoneKey = "dreadsailReef", lockoutKey = "dsrTaleriaIntro", lockoutSeconds = 600, source = "CrutchAlerts" },
    { pattern = "Vous vous invitez dans les appartements d'une dame", displayName = "Taleria", seconds = 23.5, plain = true, zoneKey = "dreadsailReef", lockoutKey = "dsrTaleriaIntro", lockoutSeconds = 600, source = "CrutchAlerts" },
}
PBT.samuraiAbilityTimers = {
    -- Maw of Lorkhaj: Rakkhat's spawn/theater events -> boss becomes hostile.
    -- Both events occur together; the shared lockout prevents a duplicate countdown.
    [59245] = { displayName = "Rakkhat", seconds = 11.1, setting = "useSamuraiTimers", zoneKey = "mawOfLorkhaj", results = { [ACTION_RESULT_STUNNED] = true }, lockoutKey = "molRakkhatSpawn", lockoutSeconds = 600, source = "EncounterLog" },
    [74217] = { displayName = "Rakkhat", seconds = 11.1, setting = "useSamuraiTimers", zoneKey = "mawOfLorkhaj", results = { [ACTION_RESULT_STUNNED] = true }, lockoutKey = "molRakkhatSpawn", lockoutSeconds = 600, source = "EncounterLog" },

    -- Halls of Fabrication: overhead rail -> spider becomes damageable.
    [94805] = { displayName = "Hunter-Killer Fabricants", seconds = 23.2, setting = "useSamuraiTimers", zoneKey = "hallsOfFabrication", lockoutSeconds = 600, source = "CrutchAlerts" },

    -- Sunspire: boss flight/takeoff -> damageable window. Ability IDs from CrutchAlerts.
    [122820] = { displayName = "Lokkestiiz Return 80", seconds = 53.3, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 70, source = "CrutchAlerts" },
    [122821] = { displayName = "Lokkestiiz Return 50", seconds = 64.9, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 75, source = "CrutchAlerts" },
    [122822] = { displayName = "Lokkestiiz Return 20", seconds = 63.9, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 75, source = "CrutchAlerts" },
    [124910] = { displayName = "Yolnahkriin Landing 75", seconds = 22.8, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 35, source = "CrutchAlerts" },
    [124915] = { displayName = "Yolnahkriin Landing 50", seconds = 23.4, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 35, source = "CrutchAlerts" },
    [124916] = { displayName = "Yolnahkriin Landing 25", seconds = 23.5, setting = "useSamuraiTimers", zoneKey = "sunspire", lockoutSeconds = 35, source = "CrutchAlerts" },
    [118884] = { displayName = "Nahviintaas Landing", seconds = 22.5, setting = "useSamuraiTimers", zoneKey = "sunspire", results = { [ACTION_RESULT_BEGIN] = true }, maxHitValue = 1999, lockoutSeconds = 35, source = "CrutchAlerts" },

    -- Cloudrest: Z'Maja becomes damageable shortly after this port/burst event.
    [104555] = { displayName = "Z'Maja", seconds = 3.9, setting = "useSamuraiTimers", zoneKey = "cloudrest", lockoutKey = "cloudrestZmajaDamageable", lockoutSeconds = 8, restart = true, source = "ZMajaTimer" },

    -- Kyne's Aegis: only mark Falgravn airborne. Countdown starts after 3 basement adds die.
    [135281] = { displayName = "Falgravn Take Off", setting = "useSamuraiTimers", zoneKey = "kynesAegis", markState = "falgravnAirborne" },
}

PBT.samuraiDeathNameTimers = {
    {
        displayName = "Falgravn Return",
        seconds = 6.0,
        setting = "useSamuraiTimers",
        zoneKey = "kynesAegis",
        requireState = "falgravnAirborne",
        countRequired = 3,
        counterKey = "falgravnBasementAddsKilled",
        lockoutKey = "falgravnBasementReturn",
        lockoutSeconds = 600,
        clearStateAfterMs = 5000,
        names = {
            "sanguine prison", "blood knight", "crimson knight", "bitter knight",
            "prison sanguine", "chevalier de sang", "chevalier cramoisi", "chevalier amer",
        },
    },
}

function PBT.BuildBossLookup()
    PBT.bossLookup = {}

    for trialKey, trial in pairs(PBT.trials) do
        for normalizedName, data in pairs(trial.bosses) do
            PBT.bossLookup[normalizedName] = {
                key = normalizedName,
                trialName = trial.name,
                bossName = data.displayName,
                seconds = data.seconds,
                lockoutSeconds = data.lockoutSeconds,
                bossUnitTrigger = data.bossUnitTrigger,
                zoneKey = data.zoneKey or trial.zoneKey or trialKey,
                manualOnly = data.manualOnly,
            }

            PBT.bossLookup[string.lower(data.displayName)] = PBT.bossLookup[normalizedName]

            if data.aliases then
                for _, alias in ipairs(data.aliases) do
                    PBT.bossLookup[string.lower(alias)] = PBT.bossLookup[normalizedName]
                end
            end
        end
    end
end

PBT.BuildBossLookup()









