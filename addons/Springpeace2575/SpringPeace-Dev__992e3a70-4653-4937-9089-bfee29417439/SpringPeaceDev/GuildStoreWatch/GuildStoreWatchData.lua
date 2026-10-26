GuildStoreWatchData = GuildStoreWatchData or {}
local GSWData = GuildStoreWatchData

GSWData.signs = {
    { value = "P", name = "Primary" },
    { value = "S", name = "Secondary" },
    { value = "W", name = "Wayshrine" },
    { value = "O", name = "Outlaws" },
}

GSWData.provinces = { "Black Marsh", "Cyrodiil", "Elsweyr", "Hammerfell", "High Rock", "Morrowind", "Skyrim", "Summerset Isles", "Systres", "Valenwood", "Realms" }
GSWData.alliances = { "Aldmeri Dominion", "Daggerfall Covenant", "Ebonheart Pact", "Neutral" }

-- sorted by alliance and alphabet
GSWData.zones = {
    {
        zone = "Auridon",
        province = "Summerset Isles",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Cerweriell", place = "Skywatch", sign = "P" },
            { name = "Ferzhela", place = "Skywatch", sign = "P" },
            { name = "Guzg", place = "Skywatch", sign = "P" },
            { name = "Lanirsare", place = "Skywatch", sign = "P" },
            { name = "Renzaiq", place = "Skywatch", sign = "P" },

            { name = "Carillda", place = "Vulkhel Guard", sign = "S" },

            { name = "Panersewen", place = "Firsthold", sign = "W" },

            { name = "Uraacil", place = "Vulkhel Guard Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Grahtwood",
        province = "Valenwood",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Bols Thirandus", place = "Elden Root", sign = "P" },
            { name = "Fintilorwe", place = "Elden Root", sign = "P" },
            { name = "Goh", place = "Elden Root", sign = "P" },
            { name = "Iannianith", place = "Elden Root", sign = "P" },
            { name = "Mizul", place = "Elden Root", sign = "P" },
            { name = "Naifineh", place = "Elden Root", sign = "P" },
            { name = "Walks-In-Leaves", place = "Elden Root", sign = "P" },

            { name = "Glothozug", place = "Southpoint", sign = "W" },
            { name = "Nirywy", place = "Cormount", sign = "W" },

            { name = "Naerorien", place = "Elden Root Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Greenshade",
        province = "Valenwood",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Camyaale", place = "Marbruk", sign = "P" },
            { name = "Fendros Faryon", place = "Marbruk", sign = "P" },
            { name = "Ghobargh", place = "Marbruk", sign = "P" },
            { name = "Goudadul", place = "Marbruk", sign = "P" },
            { name = "Hasiwen", place = "Marbruk", sign = "P" },

            { name = "Halash", place = "Greenheart", sign = "W" },
            { name = "Seeks-Better-Deals", place = "Verrant Morass", sign = "W" },

            { name = "Dugugikh", place = "Marbruk Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Khenarthi's Roost",
        province = "Elsweyr",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Dulia", place = "Mistral", sign = "P" },
            { name = "Shamuniz", place = "Mistral", sign = "P" },
        },
    },
    {
        zone = "Malabal Tor",
        province = "Valenwood",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Jalaima", place = "Baandari Trading Post", sign = "P" },
            { name = "Mani", place = "Baandari Trading Post", sign = "P" },
            { name = "Murgrud", place = "Baandari Trading Post", sign = "P" },
            { name = "Nindenel", place = "Baandari Trading Post", sign = "P" },
            { name = "Teromawen", place = "Baandari Trading Post", sign = "P" },

            { name = "Kharg", place = "Valeguard", sign = "W" },
            { name = "Ulyn Marys", place = "Dra'bul", sign = "W" },

            { name = "Galis Andalen", place = "Velyn Harbor Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Reaper's March",
        province = "Valenwood",
        alliance = "Aldmeri Dominion",
        traders = {
            { name = "Canda", place = "Rawl'kha", sign = "P" },
            { name = "Heat-On-Scales", place = "Rawl'kha", sign = "P" },
            { name = "Muheh", place = "Rawl'kha", sign = "P" },
            { name = "Ronuril", place = "Rawl'kha", sign = "P" },
            { name = "Shiniraer", place = "Rawl'kha", sign = "P" },

            { name = "Uzarrur", place = "Dune", sign = "S" },

            { name = "Ambarys Teran", place = "Vinedusk", sign = "W" },

            { name = "Sharaddargo", place = "Rawl'kha Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Alik'r Desert",
        province = "Hammerfell",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Laknar", place = "Sentinel", sign = "P" },
            { name = "Saymimah", place = "Sentinel", sign = "P" },
            { name = "Uurwaerion", place = "Sentinel", sign = "P" },
            { name = "Vinder Hlaran", place = "Sentinel", sign = "P" },
            { name = "Yat", place = "Sentinel", sign = "P" },

            { name = "Lejesha", place = "Bergama", sign = "W" },
            { name = "Manidah", place = "Morwha's Bounty", sign = "W" },

            { name = "Marbilah", place = "Sentinel Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Bangkorai",
        province = "Hammerfell",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Arver Falos", place = "Evermore", sign = "P" },
            { name = "Kaale", place = "Evermore", sign = "P" },
            { name = "Tilinarie", place = "Evermore", sign = "P" },
            { name = "Values-Many-Things", place = "Evermore", sign = "P" },
            { name = "Zunlog", place = "Evermore", sign = "P" },

            { name = "Glorgzorgo", place = "Hallin's Stand", sign = "S" },

            { name = "Malirzzaka", place = "Bangkorai Pass", sign = "W" },

            { name = "Ornyenque", place = "Evermore Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Betnikh",
        province = "High Rock",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Ghatrugh", place = "Stonetooth Fortress", sign = "P" },
        },
    },
    {
        zone = "Glenumbra",
        province = "High Rock",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Brara Hlaalo", place = "Daggerfall", sign = "P" },
            { name = "Faedre", place = "Daggerfall", sign = "P" },
            { name = "Khalatah", place = "Daggerfall", sign = "P" },
            { name = "Murgoz", place = "Daggerfall", sign = "P" },
            { name = "Sintilfalion", place = "Daggerfall", sign = "P" },

            { name = "Mogazgur", place = "Wyrd Tree", sign = "W" },
            { name = "Nameel", place = "Lion Guard Redoubt", sign = "W" },

            { name = "Zulgozu", place = "Daggerfall Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Rivenspire",
        province = "High Rock",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Frenidela", place = "Shornhelm", sign = "P" },
            { name = "Roudi", place = "Shornhelm", sign = "P" },
            { name = "Shakh", place = "Shornhelm", sign = "P" },
            { name = "Tendir Vlaren", place = "Shornhelm", sign = "P" },
            { name = "Vorh", place = "Shornhelm", sign = "P" },

            { name = "Aldam Urvyn", place = "Hoarfrost Downs", sign = "S" },

            { name = "Fanwyearie", place = "Oldgate", sign = "W" },

            { name = "Bixitleesh", place = "Shornhelm Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Stormhaven",
        province = "High Rock",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Aerchith", place = "Wayrest", sign = "P" },
            { name = "Ah-Zish", place = "Wayrest", sign = "P" },
            { name = "Atin", place = "Wayrest", sign = "P" },
            { name = "Azarati", place = "Wayrest", sign = "P" },
            { name = "Estilldo", place = "Wayrest", sign = "P" },
            { name = "Morg", place = "Wayrest", sign = "P" },
            { name = "Tredyn Daram", place = "Wayrest", sign = "P" },

            { name = "Aniama", place = "Koeglin Village", sign = "S" },

            { name = "Dromash", place = "Firebrand Keep", sign = "W" },

            { name = "Essilion", place = "Wayrest Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Stros M'Kai",
        province = "Hammerfell",
        alliance = "Daggerfall Covenant",
        traders = {
            { name = "Makmargo", place = "Port Hunding", sign = "P" },
        },
    },
    {
        zone = "Bal Foyen",
        province = "Morrowind",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Galam Seleth", place = "Dhalmora", sign = "P" },
        },
    },
    {
        zone = "Bleakrock Isle",
        province = "Skyrim",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Inishez", place = "Bleakrock", sign = "P" },
        },
    },
    {
        zone = "Deshaan",
        province = "Morrowind",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Endoriell", place = "Mournhold", sign = "P" },
            { name = "Erwurlde", place = "Mournhold", sign = "P" },
            { name = "Gals Fendyn", place = "Mournhold", sign = "P" },
            { name = "Hayaia", place = "Mournhold", sign = "P" },
            { name = "Razgugul", place = "Mournhold", sign = "P" },
            { name = "Through-Gilded-Eyes", place = "Mournhold", sign = "P" },
            { name = "Zarum", place = "Mournhold", sign = "P" },

            { name = "Feran Relenim", place = "Southwest of Muth Gnaar Hills", sign = "W" },
            { name = "Telvon Arobar", place = "Tal'Deic Grounds", sign = "W" },

            { name = "Nakmargo", place = "Mournhold Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Eastmarch",
        province = "Skyrim",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Alisewen", place = "Windhelm", sign = "P" },
            { name = "Celorien", place = "Windhelm", sign = "P" },
            { name = "Deras Golathyn", place = "Windhelm", sign = "P" },
            { name = "Dosa", place = "Windhelm", sign = "P" },
            { name = "Ghogurz", place = "Windhelm", sign = "P" },

            { name = "Muslabliz", place = "Fort Amol", sign = "S" },

            { name = "Alareth", place = "Voljar Meadery", sign = "W" },

            { name = "Meden Berendus", place = "Windhelm Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Shadowfen",
        province = "Black Marsh",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Emuin", place = "Stormhold", sign = "P" },
            { name = "Gasheg", place = "Stormhold", sign = "P" },
            { name = "Tar-Shehs", place = "Stormhold", sign = "P" },
            { name = "Vals Salvani", place = "Stormhold", sign = "P" },
            { name = "Zino", place = "Stormhold", sign = "P" },

            { name = "Junal-Nakal", place = "Weeping Wamasu Falls", sign = "S" },
            { name = "Talen-Dum", place = "East of Hissmir", sign = "S" },

            { name = "Geeh-Sakka", place = "Stormhold Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Stonefalls",
        province = "Morrowind",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Gananith", place = "Ebonheart", sign = "P" },
            { name = "J'zaraer", place = "Ebonheart", sign = "P" },
            { name = "Luz", place = "Ebonheart", sign = "P" },
            { name = "Silver-Scales", place = "Ebonheart", sign = "P" },
            { name = "Urvel Hlaren", place = "Ebonheart", sign = "P" },

            { name = "Ma'jidid", place = "Kragenmoor", sign = "S" },
            { name = "Tanur Llervu", place = "Davon's Watch", sign = "S" },

            { name = "Adagwen", place = "Davon's Watch Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "The Rift",
        province = "Skyrim",
        alliance = "Ebonheart Pact",
        traders = {
            { name = "Arnyeana", place = "Riften", sign = "P" },
            { name = "Eralian", place = "Riften", sign = "P" },
            { name = "Jeelus-Lei", place = "Riften", sign = "P" },
            { name = "Llether Nilem", place = "Riften", sign = "P" },
            { name = "Parvaia", place = "Riften", sign = "P" },

            { name = "Adainji", place = "Shor's Stone", sign = "S" },
            { name = "Atheval", place = "Nimalten", sign = "S" },

            { name = "Majdawa", place = "Riften Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Blackwood",
        province = "Cyrodiil",
        alliance = "Neutral",
        traders = {
            { name = "Amirudda", place = "Leyawiin", sign = "P" },
            { name = "Dandras Omayn", place = "Leyawiin", sign = "P" },
            { name = "Lhotahir", place = "Leyawiin", sign = "P" },
            { name = "Praxedes Vestalis", place = "Leyawiin", sign = "P" },
            { name = "Shuruthikh", place = "Leyawiin", sign = "P" },
            { name = "Sihrimaya", place = "Leyawiin", sign = "P" },

            { name = "Dion Hassildor", place = "Leyawiin Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Clockwork City",
        province = "Realms",
        alliance = "Neutral",
        traders = {
            { name = "Commerce Delegate", place = "Brass Fortress", sign = "P" },
            { name = "Noveni Adrano", place = "Brass Fortress", sign = "P" },
            { name = "Orstag", place = "Brass Fortress", sign = "P" },
            { name = "Ravam Sedas", place = "Brass Fortress", sign = "P" },
            { name = "Shogarz", place = "Brass Fortress", sign = "P" },
            { name = "Valowende", place = "Brass Fortress", sign = "P" },

            { name = "Nardhil Barys", place = "Slag Town Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Coldharbour",
        province = "Realms",
        alliance = "Neutral",
        traders = {
            { name = "Balver Sarvani", place = "The Hollow City", sign = "P" },
            { name = "Nistyniel", place = "The Hollow City", sign = "P" },
            { name = "Ramzasa", place = "The Hollow City", sign = "P" },
            { name = "Virwillaure", place = "The Hollow City", sign = "P" },

            { name = "Shuliish", place = "Haj Uxith", sign = "S" },

            { name = "Harzdak", place = "Court of Contempt", sign = "W" },
        },
    },
    {
        zone = "Craglorn",
        province = "Hammerfell",
        alliance = "Neutral",
        traders = {
            { name = "Donnaelain", place = "Belkarth", sign = "P" },
            { name = "Glegokh", place = "Belkarth", sign = "P" },
            { name = "Keen-Eyes", place = "Belkarth", sign = "P" },
            { name = "Mengilwaen", place = "Belkarth", sign = "P" },
            { name = "Nelvon Galen", place = "Belkarth", sign = "P" },
            { name = "Shelzaka", place = "Belkarth", sign = "P" },
            { name = "Shuhasa", place = "Belkarth", sign = "P" },

            { name = "Makkhzahr", place = "Belkarth Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Fargrave",
        province = "Realms",
        alliance = "Neutral",
        traders = {
            { name = "Bodsa Manas", place = "The Bazaar", sign = "P" },
            { name = "Furnvekh", place = "The Bazaar", sign = "P" },
            { name = "Livia Tappo", place = "The Bazaar", sign = "P" },
            { name = "Ven", place = "The Bazaar", sign = "P" },
            { name = "Vesakta", place = "The Bazaar", sign = "P" },
            { name = "Zenelaz", place = "The Bazaar", sign = "P" },

            { name = "Tuxutl", place = "Fargrave Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Galen",
        province = "Systres",
        alliance = "Neutral",
        traders = {
            { name = "Arzalaya", place = "Vastyr", sign = "P" },
            { name = "Gei", place = "Vastyr", sign = "P" },
            { name = "Sharflekh", place = "Vastyr", sign = "P" },
            { name = "Stephenn Surilie", place = "Vastyr", sign = "P" },
            { name = "Tildinfanya", place = "Vastyr", sign = "P" },
            { name = "Var the Vague", place = "Vastyr", sign = "P" },

            { name = "Jahim", place = "Vastyr Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Gold Coast",
        province = "Cyrodiil",
        alliance = "Neutral",
        traders = {
            { name = "Daynas Sadrano", place = "Anvil", sign = "P" },
            { name = "Majhasur", place = "Anvil", sign = "P" },
            { name = "Onurai-Maht", place = "Anvil", sign = "P" },

            { name = "Erluramar", place = "Kvatch", sign = "S" },
            { name = "Farul", place = "Kvatch", sign = "S" },
            { name = "Zagh gro-Stugh", place = "Kvatch", sign = "S" },

            { name = "Syalleth", place = "Anvil Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Hew's Bane",
        province = "Hammerfell",
        alliance = "Neutral",
        traders = {
            { name = "Farvyn Rethan", place = "Abah's Landing", sign = "P" },
            { name = "Gathewen", place = "Abah's Landing", sign = "P" },
            { name = "Qanliz", place = "Abah's Landing", sign = "P" },
            { name = "Shiny-Trades", place = "Abah's Landing", sign = "P" },
            { name = "Snegbug", place = "Abah's Landing", sign = "P" },
            { name = "Virwen", place = "Abah's Landing", sign = "P" },

            { name = "Dahnadreel", place = "Thieves Den", sign = "O" },
        },
    },
    {
        zone = "High Isle",
        province = "Systres",
        alliance = "Neutral",
        traders = {
            { name = "Innryk", place = "Gonfalon Bay", sign = "P" },
            { name = "Kemshelar", place = "Gonfalon Bay", sign = "P" },
            { name = "Marcelle Fanis", place = "Gonfalon Bay", sign = "P" },
            { name = "Pugereau Laffoon", place = "Gonfalon Bay", sign = "P" },
            { name = "Shakhrath", place = "Gonfalon Bay", sign = "P" },
            { name = "Zoe Frernile", place = "Gonfalon Bay", sign = "P" },

            { name = "Janne Jonnicent", place = "Gonfalon Bay Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Murkmire",
        province = "Black Marsh",
        alliance = "Neutral",
        traders = {
            { name = "Aki-Osheeja", place = "Lilmoth", sign = "P" },
            { name = "Faelemar", place = "Lilmoth", sign = "P" },
            { name = "Mahadal at-Bergama", place = "Lilmoth", sign = "P" },
            { name = "Ordasha", place = "Lilmoth", sign = "P" },
            { name = "Thaloril", place = "Lilmoth", sign = "P" },
            { name = "Xokomar", place = "Lilmoth", sign = "P" },

            { name = "Gir-Ta", place = "Lilmoth Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Northern Elsweyr",
        province = "Elsweyr",
        alliance = "Neutral",
        traders = {
            { name = "Adiblargo", place = "Rimmen", sign = "P" },
            { name = "Artura Pamarc", place = "Rimmen", sign = "P" },
            { name = "Fortis Asina", place = "Rimmen", sign = "P" },
            { name = "Maelanrith", place = "Rimmen", sign = "P" },
            { name = "Nirshala", place = "Rimmen", sign = "P" },
            { name = "Razzamin", place = "Rimmen", sign = "P" },

            { name = "Begok", place = "Rimmen Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Solstice",
        province = "Black Marsh",
        alliance = "Neutral",
        traders = {
            { name = "Florentina Verus", place = "Sunport", sign = "P" },
            { name = "Gilur Vules", place = "Sunport", sign = "P" },
            { name = "Grobert Agnan", place = "Sunport", sign = "P" },
            { name = "Mandyl", place = "Sunport", sign = "P" },
            { name = "Ohanath", place = "Sunport", sign = "P" },
            { name = "Tuhdri", place = "Sunport", sign = "P" },

            { name = "Fanyehna", place = "Sunport Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Southern Elsweyr",
        province = "Elsweyr",
        alliance = "Neutral",
        traders = {
            { name = "Glaetaldo", place = "Senchal", sign = "P" },
            { name = "Golgakul", place = "Senchal", sign = "P" },
            { name = "Jaflinna Snow-born", place = "Senchal", sign = "P" },
            { name = "Maguzak", place = "Senchal", sign = "P" },
            { name = "Saden Sarvani", place = "Senchal", sign = "P" },
            { name = "Wusava", place = "Senchal", sign = "P" },

            { name = "Laytiva Sendris", place = "Senchal Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Summerset",
        province = "Summerset Isles",
        alliance = "Neutral",
        traders = {
            { name = "Huzzin", place = "Alinor", sign = "P" },
            { name = "Irna Dren", place = "Alinor", sign = "P" },
            { name = "Rialilrin", place = "Alinor", sign = "P" },
            { name = "Rubyn Denile", place = "Alinor", sign = "P" },
            { name = "Talwullaure", place = "Alinor", sign = "P" },
            { name = "Yggurz Strongbow", place = "Alinor", sign = "P" },

            { name = "Ambalor", place = "Lillandril", sign = "S" },
            { name = "Nowajan", place = "Lillandril", sign = "S" },
            { name = "Quelilmor", place = "Shimmerene", sign = "S" },
            { name = "Rinedel", place = "Lillandril", sign = "S" },
            { name = "Shargalash", place = "Shimmerene", sign = "S" },
            { name = "Varandia", place = "Shimmerene", sign = "S" },

            { name = "Utzaei", place = "Alinor Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Telvanni Peninsula",
        province = "Morrowind",
        alliance = "Neutral",
        traders = {
            { name = "Alvura Thenim", place = "Necrom", sign = "P" },
            { name = "Falani", place = "Necrom", sign = "P" },
            { name = "Grudogg", place = "Necrom", sign = "P" },
            { name = "Runethyne Brenur", place = "Necrom", sign = "P" },
            { name = "Tuls Madryon", place = "Necrom", sign = "P" },
            { name = "Wyn Serpe", place = "Necrom", sign = "P" },

            { name = "Thredis", place = "Necrom Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "The Reach",
        province = "Skyrim",
        alliance = "Neutral",
        traders = {
            { name = "Bodfira", place = "Markarth", sign = "P" },
            { name = "Brighortan", place = "Markarth", sign = "P" },
            { name = "Jotep-Mota", place = "Markarth", sign = "P" },
            { name = "Keltorgan", place = "Markarth", sign = "P" },
            { name = "Marilia Verethi", place = "Markarth", sign = "P" },
            { name = "Victoire Madach", place = "Markarth", sign = "P" },

            { name = "Morborgol", place = "Markarth Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Vvardenfell",
        province = "Morrowind",
        alliance = "Neutral",
        traders = {
            { name = "Atazha", place = "Vivec City", sign = "P" },
            { name = "Jena Calvus", place = "Vivec City", sign = "P" },
            { name = "Lorthodaer", place = "Vivec City", sign = "P" },
            { name = "Mauhoth", place = "Vivec City", sign = "P" },
            { name = "Rinami", place = "Vivec City", sign = "P" },
            { name = "Sebastian Brutya", place = "Vivec City", sign = "P" },

            { name = "Felayn Uvaram", place = "Sadrith Mora", sign = "S" },
            { name = "Ginette Malarelie", place = "Balmora", sign = "S" },
            { name = "Mahrahdr", place = "Balmora", sign = "S" },
            { name = "Narril", place = "Balmora", sign = "S" },
            { name = "Runik", place = "Sadrith Mora", sign = "S" },
            { name = "Ruxultav", place = "Sadrith Mora", sign = "S" },

            { name = "Relieves-Burdens", place = "Vivec City Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Western Skyrim",
        province = "Skyrim",
        alliance = "Neutral",
        traders = {
            { name = "Bredromathor", place = "Solitude", sign = "P" },
            { name = "Huleida", place = "Solitude", sign = "P" },
            { name = "Maevolk", place = "Solitude", sign = "P" },
            { name = "Trallinarian", place = "Solitude", sign = "P" },
            { name = "Wita", place = "Solitude", sign = "P" },
            { name = "Zuugozag", place = "Solitude", sign = "P" },

            { name = "M'deshargo", place = "Solitude Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "West Weald",
        province = "Cyrodiil",
        alliance = "Neutral",
        traders = {
            { name = "Bezaiq", place = "Skingrad", sign = "P" },
            { name = "Irg", place = "Skingrad", sign = "P" },
            { name = "Jabariq", place = "Skingrad", sign = "P" },
            { name = "Synnolian Entius", place = "Skingrad", sign = "P" },
            { name = "Ushataga", place = "Skingrad", sign = "P" },
            { name = "Vaelelanda", place = "Skingrad", sign = "P" },

            { name = "Amwuana", place = "Skingrad Outlaws Refuge", sign = "O" },
        },
    },
    {
        zone = "Wrothgar",
        province = "High Rock",
        alliance = "Neutral",
        traders = {
            { name = "Jee-Ma", place = "Orsinium", sign = "P" },
            { name = "Lianorien", place = "Orsinium", sign = "P" },
            { name = "Logogru", place = "Orsinium", sign = "P" },
            { name = "Mabit", place = "Orsinium", sign = "P" },
            { name = "Mervs Sarys", place = "Orsinium", sign = "P" },
            { name = "Terorne", place = "Orsinium", sign = "P" },

            { name = "Borgrara", place = "Morkul Stronghold", sign = "S" },
            { name = "Henriette Panoit", place = "Morkul Stronghold", sign = "S" },
            { name = "Nagrul gro-Stugbaz", place = "Morkul Stronghold", sign = "S" },
            { name = "Oorgurn", place = "Morkul Stronghold", sign = "S" },

            { name = "Narkhukulg", place = "Orsinium Outlaws Refuge", sign = "O" },
        },
    },
}
