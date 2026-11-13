-- BGF_Activities.lua
-- Descriptive data: what you are doing (intents), per-category info, and a
-- database of dungeons / trials / arenas matched by name against the
-- activity names the game's group finder gives us.

local BGF = BetterGroupFinderConsole
local U = BGF.util

BGF.Activities = {}
local A = BGF.Activities

---------------------------------------------------------------------------
-- Categories (the game's GROUP_FINDER_CATEGORY_* values)
---------------------------------------------------------------------------
-- key -> global constant name. Resolved lazily so a missing constant on an
-- older/newer client simply drops that category.
local CATEGORY_KEYS = {
    { key = "dungeon", const = "GROUP_FINDER_CATEGORY_DUNGEON",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds",
      blurb = "4-player instanced dungeons. Normal for pledges and leveling, Veteran for gear, Hard Modes and achievements." },
    { key = "trial", const = "GROUP_FINDER_CATEGORY_TRIAL",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_trial_up.dds",
      blurb = "12-player raids. Veteran trials drop perfected gear; Hard Modes and score runs need a practised group." },
    { key = "arena", const = "GROUP_FINDER_CATEGORY_ARENA",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_trial_up.dds",
      blurb = "Group arenas such as Dragonstar Arena and Blackrose Prison: wave fights with stages and a final boss." },
    { key = "endless", const = "GROUP_FINDER_CATEGORY_ENDLESS_DUNGEON",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds",
      blurb = "Infinite Archive: a 1-2 player roguelike dungeon. Push arcs, farm Archival Fortunes or chase high cycles." },
    { key = "pvp", const = "GROUP_FINDER_CATEGORY_PVP",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_pvp_up.dds",
      blurb = "Cyrodiil campaigns, Imperial City and Battlegrounds. Ball groups, small-scale roaming or premade BG teams." },
    { key = "zone", const = "GROUP_FINDER_CATEGORY_ZONE",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_zoneStories_up.dds",
      blurb = "Open-world content: world bosses, dolmens, geysers, harrowstorms, public dungeons and zone quests." },
    { key = "custom", const = "GROUP_FINDER_CATEGORY_CUSTOM",
      icon = "EsoUI/Art/LFG/LFG_indexIcon_group_up.dds",
      blurb = "Anything else: role-play, housing tours, fishing, crafting, guild events or social groups." },
}

function A:GetCategories()
    if self.categories then return self.categories end
    local list = {}
    for _, info in ipairs(CATEGORY_KEYS) do
        local value = _G[info.const]
        if value ~= nil then
            list[#list + 1] = {
                key = info.key,
                value = value,
                name = self:CategoryName(value, info.key),
                icon = info.icon,
                blurb = info.blurb,
            }
        end
    end
    self.categories = list
    return list
end

function A:CategoryByKey(key)
    for _, c in ipairs(self:GetCategories()) do
        if c.key == key then return c end
    end
end

function A:CategoryByValue(value)
    for _, c in ipairs(self:GetCategories()) do
        if c.value == value then return c end
    end
end

function A:CategoryName(value, fallback)
    local name = value and GetString("SI_GROUPFINDERCATEGORY", value) or ""
    if name == nil or name == "" then
        name = fallback and (fallback:gsub("^%l", string.upper)) or "Unknown"
    end
    return name
end

---------------------------------------------------------------------------
-- Intents: "What are you doing?"
---------------------------------------------------------------------------
-- category     : category key (see above)
-- difficulty   : "normal" / "veteran" / nil (leave as the game has it)
-- playstyle    : keywords matched (in order) against the game's playstyle
--                names; the first hit is picked. English client only, it
--                simply keeps the current playstyle otherwise.
-- cp           : suggested minimum CP (0 = none)
-- tag          : short tag used in auto titles ("HM", "Farm"...)
-- roleStyle    : "standard" | "flex" | "pvp" | "any"
-- lines        : extra description lines for the auto description
A.INTENTS = {
    -- Dungeons
    { id = "pledges", category = "dungeon", difficulty = nil, cp = 0, tag = "Pledge",
      name = "Undaunted Pledges",
      summary = "Daily pledge run for keys and Undaunted rep.",
      details = "Quick clears of the daily pledge dungeons. Normal or Veteran as listed. No Hard Modes, no wiping on purpose.",
      playstyle = { "casual", "farm" }, roleStyle = "standard",
      lines = { "Quick pledge clear, no HM." } },
    { id = "normal_dungeon", category = "dungeon", difficulty = "normal", cp = 0, tag = "Normal",
      name = "Normal Dungeon",
      summary = "Relaxed normal-mode run.",
      details = "Normal difficulty. Good for leveling, quests, skyshards and learning a new role. Any level welcome.",
      playstyle = { "casual", "learn" }, roleStyle = "standard",
      lines = { "Relaxed normal run, all levels welcome." } },
    { id = "vet_dungeon", category = "dungeon", difficulty = "veteran", cp = 160, tag = "Vet",
      name = "Veteran Dungeon",
      summary = "Veteran clear without Hard Mode.",
      details = "Veteran difficulty for better gear quality and monster helms. CP 160 gear expected; know your role.",
      playstyle = { "casual", "competitive" }, roleStyle = "standard",
      lines = { "Vet clear, no HM. CP160 gear please." } },
    { id = "vet_hm", category = "dungeon", difficulty = "veteran", cp = 810, tag = "HM",
      name = "Veteran Hard Mode",
      summary = "Veteran with the Hard Mode on the last boss.",
      details = "Hard Mode on the final boss for the monster-set shoulders, HM achievements and better drops. Bring a real build: tank with group buffs, healer with support sets, 60k+ DPS recommended.",
      playstyle = { "competitive", "achievement" }, roleStyle = "standard",
      lines = { "Vet HM. Know the mechanics.", "DPS 60k+ recommended." } },
    { id = "trifecta", category = "dungeon", difficulty = "veteran", cp = 1500, tag = "Trifecta",
      name = "Trifecta / Achievements",
      summary = "Hard Mode + Speed Run + No Death in one go.",
      details = "Achievement run going for the title: Hard Mode, Speed Run and No Death together. Experienced players with optimised builds and voice chat preferred.",
      playstyle = { "achievement", "competitive", "speed" }, roleStyle = "standard",
      lines = { "Going for the trifecta (HM + speed + no death).", "Experienced only." } },
    { id = "speed_farm", category = "dungeon", difficulty = "veteran", cp = 810, tag = "Farm",
      name = "Gear / Monster Set Farm",
      summary = "Repeated runs farming a set or monster helm.",
      details = "Multiple back-to-back runs farming a specific set or the monster helm. Stay for several runs if you can.",
      playstyle = { "farm", "casual" }, roleStyle = "standard",
      lines = { "Farming runs, staying for several clears." } },
    { id = "teaching", category = "dungeon", difficulty = "veteran", cp = 160, tag = "Learning",
      name = "Learning / Teaching Run",
      summary = "Patient run where mechanics are explained.",
      details = "New to this dungeon or difficulty? Mechanics are explained before each boss. Wipes are expected and fine.",
      playstyle = { "learn", "casual" }, roleStyle = "standard",
      lines = { "Learning run, mechanics explained. New players welcome." } },

    -- Trials
    { id = "trial_normal", category = "trial", difficulty = "normal", cp = 160, tag = "Normal",
      name = "Normal Trial",
      summary = "Normal 12-player trial clear.",
      details = "Normal difficulty trial. Good for weekly coffers, learning the fights and newer players.",
      playstyle = { "casual", "learn" }, roleStyle = "standard",
      lines = { "Normal clear, newer players welcome." } },
    { id = "trial_vet", category = "trial", difficulty = "veteran", cp = 810, tag = "Vet",
      name = "Veteran Trial",
      summary = "Veteran clear for perfected gear.",
      details = "Veteran trial clear for perfected sets and weeklies. Know the mechanics and bring the requested support sets.",
      playstyle = { "competitive", "casual" }, roleStyle = "standard",
      lines = { "Vet clear. Know mechanics, bring requested sets." } },
    { id = "trial_hm", category = "trial", difficulty = "veteran", cp = 1500, tag = "HM",
      name = "Veteran Trial HM / Score",
      summary = "Hard Mode or score push with an experienced group.",
      details = "Hard Mode on the last boss, score or trifecta attempts. Parses and build checks are likely. Voice chat expected.",
      playstyle = { "competitive", "achievement", "speed" }, roleStyle = "standard",
      lines = { "HM / score run. Parse and build check may apply." } },
    { id = "trial_prog", category = "trial", difficulty = "veteran", cp = 1200, tag = "Prog",
      name = "Trial Progression",
      summary = "Practising a fight or Hard Mode over several attempts.",
      details = "Progression night working on a specific boss or Hard Mode. Expect many attempts; stay for the session.",
      playstyle = { "learn", "competitive" }, roleStyle = "standard",
      lines = { "Progression, many pulls expected. Stay for the session." } },

    -- Arenas / Endless
    { id = "arena", category = "arena", difficulty = "veteran", cp = 810, tag = "Arena",
      name = "Group Arena",
      summary = "Dragonstar Arena or Blackrose Prison.",
      details = "Group arena run through every stage. Veteran clears and the Hard Mode drop the arena weapons.",
      playstyle = { "competitive", "farm" }, roleStyle = "standard",
      lines = { "Full arena clear." } },
    { id = "endless", category = "endless", difficulty = nil, cp = 0, tag = "Archive",
      name = "Infinite Archive Duo",
      summary = "Duo push through the Infinite Archive.",
      details = "Two-player Infinite Archive. Say which arc or cycle you are going for and whether you farm Fortunes or push depth.",
      playstyle = { "casual", "competitive" }, roleStyle = "any",
      lines = { "Duo archive push." } },

    -- PvP
    { id = "pvp_cyro", category = "pvp", difficulty = nil, cp = 0, tag = "Cyro",
      name = "Cyrodiil Group",
      summary = "Roaming, keep sieges or ball group in Cyrodiil.",
      details = "Cyrodiil campaign group: keep takes, defence and open-field fights. Group buffs and purge welcome.",
      playstyle = { "casual", "competitive" }, roleStyle = "pvp",
      lines = { "Cyrodiil group, follow the crown." } },
    { id = "pvp_bg", category = "pvp", difficulty = nil, cp = 0, tag = "BG",
      name = "Battlegrounds Premade",
      summary = "Premade team for Battlegrounds.",
      details = "Premade Battlegrounds team. Healer and burst DPS wanted.",
      playstyle = { "competitive", "casual" }, roleStyle = "pvp",
      lines = { "BG premade." } },
    { id = "pvp_ic", category = "pvp", difficulty = nil, cp = 0, tag = "IC",
      name = "Imperial City",
      summary = "Telvar farming and districts in Imperial City.",
      details = "Imperial City sewers and districts: Telvar farming, bosses and fights. Bank often.",
      playstyle = { "farm", "casual" }, roleStyle = "pvp",
      lines = { "IC run, Telvar farming." } },

    -- World
    { id = "world_events", category = "zone", difficulty = nil, cp = 0, tag = "World",
      name = "World Events",
      summary = "World bosses, dolmens, geysers, harrowstorms.",
      details = "Open-world zone events: world bosses, dolmens, geysers, harrowstorms, volcanic vents and the like. Great for zone sets and achievements.",
      playstyle = { "casual", "farm" }, roleStyle = "flex",
      lines = { "World events tour." } },
    { id = "public_dungeon", category = "zone", difficulty = nil, cp = 0, tag = "PD",
      name = "Public Dungeon / Delves",
      summary = "Public dungeon group events and skyshards.",
      details = "Public dungeons and delves: group events, champion bosses, skyshards and skill points.",
      playstyle = { "casual" }, roleStyle = "flex",
      lines = { "Public dungeon + delves." } },
    { id = "zone_story", category = "zone", difficulty = nil, cp = 0, tag = "Quests",
      name = "Zone Story / Quests",
      summary = "Questing together through a zone.",
      details = "Quest together through a zone's story. Shared quest steps, no rushing dialogue.",
      playstyle = { "casual", "role" }, roleStyle = "any",
      lines = { "Zone story together." } },

    -- Custom
    { id = "social", category = "custom", difficulty = nil, cp = 0, tag = "Social",
      name = "Social / Role-play / Other",
      summary = "Anything else: RP, housing, fishing, crafting.",
      details = "Social groups and everything not covered above. Describe it in the description.",
      playstyle = { "role", "casual" }, roleStyle = "any",
      lines = {} },
}

function A:GetIntent(id)
    for _, intent in ipairs(self.INTENTS) do
        if intent.id == id then return intent end
    end
    return self.INTENTS[1]
end

function A:IntentsForCategory(categoryKey)
    local list = {}
    for _, intent in ipairs(self.INTENTS) do
        if categoryKey == nil or intent.category == categoryKey then
            list[#list + 1] = intent
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Activity database
---------------------------------------------------------------------------
-- roles = { tank, heal, dps } for the activity's normal group size.
local DUNGEON = { 1, 1, 2 }
local TRIAL = { 2, 2, 8 }

local DB = {}
A.DB = DB
A.TRIAL_DEFAULT = TRIAL

local function Add(kind, name, abbr, source, summary, extra)
    local entry = extra or {}
    entry.kind = kind
    entry.name = name
    entry.abbr = abbr
    entry.source = source
    entry.summary = summary
    entry.roles = entry.roles or (kind == "trial" and TRIAL or DUNGEON)
    DB[U.Normalize(name)] = entry
end

-- Base game dungeons
local BASE = "Base game"
Add("dungeon", "Fungal Grotto I", "FG1", BASE, "Short starter dungeon; ideal for new tanks and pledges.")
Add("dungeon", "Fungal Grotto II", "FG2", BASE, "Compact, quick clear. Good warm-up dungeon.")
Add("dungeon", "Spindleclutch I", "SC1", BASE, "Spider-infested cave; straightforward bosses.")
Add("dungeon", "Spindleclutch II", "SC2", BASE, "Known for a punishing first boss on veteran; DPS check.")
Add("dungeon", "Banished Cells I", "BC1", BASE, "Daedric prison; quick, beginner friendly.")
Add("dungeon", "Banished Cells II", "BC2", BASE, "Daedric dungeon with a portal-heavy final boss.")
Add("dungeon", "Darkshade Caverns I", "DSC1", BASE, "Mine dungeon with a construct final boss.")
Add("dungeon", "Darkshade Caverns II", "DSC2", BASE, "Longer dungeon with lots of trash and adds.")
Add("dungeon", "Elden Hollow I", "EH1", BASE, "Short and simple; good for leveling.")
Add("dungeon", "Elden Hollow II", "EH2", BASE, "Final boss punishes standing in the wrong place.")
Add("dungeon", "Wayrest Sewers I", "WS1", BASE, "Short sewer crawl; easy pledge.")
Add("dungeon", "Wayrest Sewers II", "WS2", BASE, "Ghostly bosses; final boss has a DPS race feel.")
Add("dungeon", "Crypt of Hearts I", "CoH1", BASE, "Undead crypt, simple mechanics.")
Add("dungeon", "Crypt of Hearts II", "CoH2", BASE, "Long-ish dungeon; final boss has strong AoE.")
Add("dungeon", "City of Ash I", "CoA1", BASE, "Fire-themed Daedric ruin; moderate length.")
Add("dungeon", "City of Ash II", "CoA2", BASE, "Notoriously tough on veteran; fire pools and heavy damage.")
Add("dungeon", "Tempest Island", "TI", BASE, "Storm-themed island; healer pressure on later bosses.")
Add("dungeon", "Selene's Web", "SW", BASE, "Long jungle dungeon; spriggans and a spider final boss.")
Add("dungeon", "Volenfell", "VF", BASE, "Dwemer ruin with traps; rewards careful pulls.")
Add("dungeon", "Blessed Crucible", "BCr", BASE, "Arena-style gauntlet of bosses.")
Add("dungeon", "Direfrost Keep", "DK", BASE, "Frost keep with a two-phase final boss.")
Add("dungeon", "Vaults of Madness", "VoM", BASE, "Sheogorath-themed vaults; maze-like layout.")
Add("dungeon", "Arx Corinium", "AC", BASE, "Argonian ruin; mostly add management.")
Add("dungeon", "Blackheart Haven", "BH", BASE, "Pirate dungeon; mobile bosses, lots of trash.")

-- DLC dungeons
Add("dungeon", "Imperial City Prison", "ICP", "Imperial City", "Prison break through Molag Bal's dungeon; long trash pulls.", { hm = true })
Add("dungeon", "White-Gold Tower", "WGT", "Imperial City", "Climb of the tower; long run with a tough final fight.", { hm = true })
Add("dungeon", "Cradle of Shadows", "CoS", "Shadows of the Hist", "Dark, stealth-themed dungeon with darkness mechanics.", { hm = true })
Add("dungeon", "Ruins of Mazzatun", "RoM", "Shadows of the Hist", "Argonian ruins; final boss with tree/totem mechanics.", { hm = true })
Add("dungeon", "Bloodroot Forge", "BRF", "Horns of the Reach", "Forge dungeon with heavy fire damage and adds.", { hm = true })
Add("dungeon", "Falkreath Hold", "FH", "Horns of the Reach", "Nord hold under siege; giant final boss.", { hm = true })
Add("dungeon", "Fang Lair", "FL", "Dragon Bones", "Bone dragon dungeon; final boss with skeletal adds.", { hm = true })
Add("dungeon", "Scalecaller Peak", "SCP", "Dragon Bones", "Plague-themed peak; final boss is a DPS check.", { hm = true })
Add("dungeon", "Moon Hunter Keep", "MHK", "Wolfhunter", "Werewolf keep; tank swaps and add control.", { hm = true })
Add("dungeon", "March of Sacrifices", "MoS", "Wolfhunter", "Hunting grounds with a wolf-themed final boss.", { hm = true })
Add("dungeon", "Frostvault", "FV", "Wrathstone", "Dwemer vault with an ice-themed final boss.", { hm = true })
Add("dungeon", "Depths of Malatar", "DoM", "Wrathstone", "Ayleid depths; boss mechanics punish greed.", { hm = true })
Add("dungeon", "Moongrave Fane", "MGF", "Scalebreaker", "Khajiiti temple; final boss with blood mechanics.", { hm = true })
Add("dungeon", "Lair of Maarselok", "LoM", "Scalebreaker", "Corrupted dragon lair; lots of poison AoE.", { hm = true })
Add("dungeon", "Icereach", "IR", "Harrowstorm", "Witch coven in the snow; frost and harrowstorm mechanics.", { hm = true })
Add("dungeon", "Unhallowed Grave", "UG", "Harrowstorm", "Grave dungeon with a hard-hitting final boss.", { hm = true })
Add("dungeon", "Stone Garden", "SG", "Stonethorn", "Arena-like fights with mutated creatures.", { hm = true })
Add("dungeon", "Castle Thorn", "CT", "Stonethorn", "Vampire castle; final boss with blood mechanics.", { hm = true })
Add("dungeon", "Black Drake Villa", "BDV", "Flames of Ambition", "Villa dungeon; boss swaps and positioning.", { hm = true })
Add("dungeon", "The Cauldron", "CA", "Flames of Ambition", "Dwemer forge; long with mechanic-heavy final boss.", { hm = true })
Add("dungeon", "Red Petal Bastion", "RPB", "Waking Flame", "Fortress dungeon; fire and add pressure.", { hm = true })
Add("dungeon", "The Dread Cellar", "DC", "Waking Flame", "Daedric cellar; final boss with lots of mechanics.", { hm = true })
Add("dungeon", "Coral Aerie", "CoA", "Ascending Tide", "Coastal Maormer dungeon with storm mechanics.", { hm = true })
Add("dungeon", "Shipwright's Regret", "SR", "Ascending Tide", "Haunted shipwreck; ghostly mechanics.", { hm = true })
Add("dungeon", "Earthen Root Enclave", "ERE", "Lost Depths", "Druidic enclave; final boss with stage mechanics.", { hm = true })
Add("dungeon", "Graven Deep", "GD", "Lost Depths", "Deep underwater-themed dungeon; positioning heavy.", { hm = true })
Add("dungeon", "Bal Sunnar", "BS", "Scribes of Fate", "Telvanni ruin with time-shift mechanics.", { hm = true })
Add("dungeon", "Scrivener's Hall", "SH", "Scribes of Fate", "Apocrypha-touched hall; one of the hardest HMs.", { hm = true })
Add("dungeon", "Oathsworn Pit", "OP", "Scions of Ithelia", "Arena pit with escalating boss mechanics.", { hm = true })
Add("dungeon", "Bedlam Veil", "BV", "Scions of Ithelia", "Shattered-reality dungeon; demanding final boss.", { hm = true })
Add("dungeon", "Exiled Redoubt", "ER", "Fallen Banners", "Fortress dungeon from the Fallen Banners pack.", { hm = true })
Add("dungeon", "Lep Seclusa", "LS", "Fallen Banners", "Island hideout dungeon from the Fallen Banners pack.", { hm = true })

-- Trials
Add("trial", "Hel Ra Citadel", "HRC", BASE, "Craglorn trial; good first veteran trial.", { hm = true, cp = 160 })
Add("trial", "Aetherian Archive", "AA", BASE, "Craglorn trial; mage final boss with heavy damage.", { hm = true, cp = 160, roles = { 1, 2, 9 } })
Add("trial", "Sanctum Ophidia", "SO", BASE, "Craglorn trial; serpent final boss and poison mechanics.", { hm = true, cp = 160 })
Add("trial", "Maw of Lorkhaj", "MoL", "Thieves Guild", "Khajiiti trial; colour-swap mechanics on the final boss.", { hm = true, cp = 300 })
Add("trial", "Halls of Fabrication", "HoF", "Morrowind", "Clockwork factory; Assembly General is a big DPS check.", { hm = true, cp = 500 })
Add("trial", "Asylum Sanctorium", "AS", "Clockwork City", "Single-arena trial; HM adds both minis to the fight.", { hm = true, cp = 500 })
Add("trial", "Cloudrest", "CR", "Summerset", "Single-boss trial; difficulty scales with minis (+0 to +3).", { hm = true, cp = 500 })
Add("trial", "Sunspire", "SS", "Elsweyr", "Dragon trial; Nahviintaas HM is a classic progression goal.", { hm = true, cp = 810 })
Add("trial", "Kyne's Aegis", "KA", "Greymoor", "Nordic trial; tightly coordinated portals and adds.", { hm = true, cp = 810 })
Add("trial", "Rockgrove", "RG", "Blackwood", "Deadlands-touched trial; heavy on positioning.", { hm = true, cp = 810 })
Add("trial", "Dreadsail Reef", "DSR", "High Isle", "Sea-elf trial; stacks and debuffs to manage.", { hm = true, cp = 810 })
Add("trial", "Sanity's Edge", "SE", "Necrom", "Dream-themed trial with split mechanics.", { hm = true, cp = 810 })
Add("trial", "Lucent Citadel", "LC", "Gold Road", "Crystal citadel; beam and tether coordination.", { hm = true, cp = 810 })
Add("trial", "Ossein Cage", "OC", "Seasons of the Worm Cult", "Worm Cult trial; one of the newest and hardest.", { hm = true, cp = 1200 })

-- Arenas
Add("arena", "Dragonstar Arena", "DSA", "Base game", "10-stage group arena in Craglorn.", { hm = true, cp = 160 })
Add("arena", "Blackrose Prison", "BRP", "Murkmire", "5-arena gauntlet with waves of prisoners.", { hm = true, cp = 160 })
Add("arena", "Maelstrom Arena", "vMA", "Orsinium", "Solo arena (listed for completeness).", { cp = 160, roles = { 0, 0, 1 } })
Add("arena", "Vateshran Hollows", "VH", "Markarth", "Solo arena (listed for completeness).", { cp = 160, roles = { 0, 0, 1 } })

-- Looks up an activity by the game's display name (secondary option text).
-- Also tries without a trailing "I"/"II" roman numeral style suffix change
-- and prefix/suffix matches so slight renames still hit.
function A:Lookup(name)
    if name == nil or name == "" then return nil end
    local key = U.Normalize(name)
    if DB[key] then return DB[key] end
    for dbKey, entry in pairs(DB) do
        if zo_plainstrfind(key, dbKey) or zo_plainstrfind(dbKey, key) then
            return entry
        end
    end
    return nil
end

-- Short label for titles: "vSS", "nFG1", or the plain name.
function A:ShortLabel(activityName, isVeteran)
    local entry = self:Lookup(activityName)
    if entry and entry.abbr then
        if entry.kind == "arena" and entry.abbr:sub(1, 1) == "v" then
            return entry.abbr
        end
        return (isVeteran and "v" or "n") .. entry.abbr
    end
    return activityName
end
