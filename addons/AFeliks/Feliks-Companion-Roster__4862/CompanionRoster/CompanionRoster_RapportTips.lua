CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

-- Community-researched data (UESP Wiki, https://en.uesp.net/wiki/Online:Companions#Rapport)
-- of what raises/lowers each companion's rapport, with amounts and cooldowns.
-- There's no API for this - the game only exposes the resulting rapport
-- number and delta (EVENT_COMPANION_RAPPORT_UPDATE), never *why* it
-- changed - so like KEEPSAKE_COLLECTIBLE_IDS in CompanionRoster_Data.lua,
-- this is hand-transcribed, not derived live. Keyed by the exact name
-- GetCompanionName() returns (matches KEEPSAKE_COLLECTIBLE_IDS's keys).
--
-- `amount` is a plain number for ranking (the higher figure when the wiki
-- lists two, e.g. "+25 / +5" -> 25); `amountLabel` is the exact wiki text
-- when it's not just that single number. `categories` are free-form tags
-- (not an exhaustive fixed enum) matched by CompanionRoster.Data.SearchRapportTips
-- against both the tags and the description text.
CompanionRoster.RapportTips = {
    ["Bastian Hallix"] = {
        positive = {
            { amount = 500, description = "Complete Things Lost, Things Found and Family Secrets companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Complete a Mages Guild daily offered by Alvur Baren", cooldown = "No cooldown", categories = { "Mages Guild" } },
            { amount = 10, description = "Visit or pass by a Mages Guild guildhall within Alliance zones", cooldown = "20 hours", categories = { "Mages Guild" } },
            { amount = 10, description = "Visit Artaeum or Eyevea", cooldown = "20 hours", categories = { "Psijic Order" } },
            { amount = 10, description = "Complete random Encounters that help people (rescuing merchants, summoners, travelers)", cooldown = "Unknown", categories = { "World Event" } },
            { amount = 5, description = "Scry an Antiquity", cooldown = "5 minutes", categories = { "Antiquities" } },
            { amount = 5, description = "Loot a Psijic portal", cooldown = "Unknown", categories = { "Psijic Order" } },
            { amount = 5, description = "Kill a Worm Cultist at the start of a Dark Anchor", cooldown = "5-10 minutes", categories = { "Combat" } },
            { amount = 1, description = "Kill any Cultist", cooldown = "1 minute", categories = { "Combat" } },
            { amount = 1, description = "Kill bandits anywhere", cooldown = "1 minute", categories = { "Combat" } },
            { amount = 1, description = "Read a book", cooldown = "15 minutes", categories = { "Books" } },
        },
        negative = {
            { amount = -25, description = "Murder", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -10, description = "Attack innocents", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -10, description = "Get caught stealing or pickpocketing", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Kill livestock", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Steal", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Pickpocket", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -1, description = "Cook food with cheese", cooldown = "Unknown", categories = { "Provisioning" } },
            { amount = -1, description = "Attempt to flee from guards", cooldown = "Unknown", categories = { "Crime" } },
        },
    },

    ["Mirri Elendis"] = {
        positive = {
            { amount = 500, description = "Return A Mother's Obsession and Dead Weight companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Return a Dark Anchor contract offered by Cardea Gallus in the Fighters Guild", cooldown = "No cooldown", categories = { "Fighters Guild" } },
            { amount = 125, description = "Return Numani-Rasi relics daily in Vvardenfell", cooldown = "Daily", categories = { "Antiquities" } },
            { amount = 10, description = "Have Mirri comment on Clockwork City while visiting it", cooldown = "24-44 hours", categories = { "Exploration" } },
            { amount = 10, description = "Enter certain daedric delves/public dungeons (Ashalmawia, Broken Tusk, Mehrunes' Spite, Sanguine's Demesne, The Cave of Trophies, The Grotto of Depravity)", cooldown = "30 minutes", categories = { "Dungeon" } },
            { amount = 10, description = "Talk to Sotha Sil", cooldown = "Unknown", categories = { "NPC Interaction" } },
            { amount = 10, amountLabel = "10 / 1", description = "Take all loot from a treasure chest", cooldown = "60 minutes / no cooldown", categories = { "Treasure" } },
            { amount = 5, description = "Excavate an Antiquity", cooldown = "5 minutes", categories = { "Antiquities" } },
            { amount = 75, amountLabel = "75 / 5", description = "View a completed Khajiit of the Moons, Library of Vivec, Kari's Hit List, House of Orsimer Glories, Vault of Moawita, Rithana-di-Renada, or Bards College antiquity set", cooldown = "20 hours", categories = { "Antiquities" } },
            { amount = 1, description = "Kill a goblin, riekling, or snake", cooldown = "150 seconds - 5 minutes", categories = { "Combat" } },
            { amount = 1, description = "Craft an alcoholic beverage", cooldown = "5 minutes", categories = { "Provisioning" } },
            { amount = 1, description = "Read a book from a shelf", cooldown = "30+ minutes", categories = { "Books" } },
            { amount = 1, description = "Summon certain Daedric pets (e.g. Daemon Chicken, Slate-Skinned Daedrat)", cooldown = "Unknown", categories = { "Pets" } },
        },
        negative = {
            { amount = -25, amountLabel = "25 / 5", description = "Use the Blade of Woe, including against enemies", cooldown = "5 minutes / no cooldown", categories = { "Crime" } },
            { amount = -10, description = "Enter the Dark Brotherhood Sanctuary", cooldown = "Unknown", categories = { "Dark Brotherhood" } },
            { amount = -1, description = "Interact with or harvest a torchbug, butterfly, or honey bee", cooldown = "Unknown", categories = { "Gathering" } },
        },
    },

    ["Ember"] = {
        positive = {
            { amount = 500, description = "Return Cold Trail, Cold Blood, Old Pain, or Green with Envy companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Return a Thieves Guild heist", cooldown = "Daily", categories = { "Thieves Guild" } },
            { amount = 125, description = "Return a relic-retrieving quest offered by Alvur Baren in a Mages Guild", cooldown = "Daily", categories = { "Mages Guild" } },
            { amount = 125, description = "Return a delve quest offered by Wayllod in High Isle", cooldown = "Daily", categories = { "Dungeon" } },
            { amount = 25, amountLabel = "25 / 5", description = "Fence a purple-quality stolen item", cooldown = "24 hours", categories = { "Thieves Guild", "Crime" } },
            { amount = 10, amountLabel = "10 / 1", description = "Win a game of Tales of Tribute", cooldown = "1 hour", categories = { "Tales of Tribute" } },
            { amount = 10, amountLabel = "10 / 1", description = "Begin a Black Sacrament", cooldown = "24 hours", categories = { "Dark Brotherhood" } },
            { amount = 10, amountLabel = "10 / 1", description = "Pickpocket a guard", cooldown = "1 hour", categories = { "Crime" } },
            { amount = 10, description = "Use clemency", cooldown = "24 hour skill reset", categories = { "Crime" } },
            { amount = 5, amountLabel = "5 / 1", description = "Loot a Thieves Trove or safebox", cooldown = "1 hour", categories = { "Thieves Guild" } },
            { amount = 5, description = "Use a Counterfeit Pardon Edict", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 5, description = "Return a Thieves Guild job from a Tip Board", cooldown = "1 hour", categories = { "Thieves Guild" } },
            { amount = 1, description = "Visit an Outlaws Refuge or the Thieves Guild Den", cooldown = "1 hour", categories = { "Thieves Guild" } },
            { amount = 1, description = "Harvest a runestone", cooldown = "5 minutes", categories = { "Gathering" } },
            { amount = 1, description = "Kill a werewolf or wolf", cooldown = "5 minutes", categories = { "Combat" } },
            { amount = 1, description = "Summon the Big-Eared Ginger Kitten or Witch's Infernal Familiar pet", cooldown = "24 hours", categories = { "Pets" } },
            { amount = 1, description = "Sell a purple-quality item to a vendor", cooldown = "Unknown", categories = { "Trading" } },
            { amount = 1, description = "Successfully flee from the guard", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 1, description = "Trespass a restricted area", cooldown = "Unknown", categories = { "Crime" } },
        },
        negative = {
            { amount = -25, amountLabel = "25 / 5", description = "Pay a bounty to a guard after being caught", cooldown = "1 hour", categories = { "Crime" } },
            { amount = -10, description = "Get caught committing a crime", cooldown = "5 minutes", categories = { "Crime" } },
            { amount = -10, description = "Get spotted while trespassing in a restricted area", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -10, description = "Enter The Halls of Colossus", cooldown = "Unknown", categories = { "Dungeon" } },
            { amount = -5, amountLabel = "5 / 1", description = "Start fishing", cooldown = "5 minutes", categories = { "Fishing" } },
        },
    },

    ["Isobel Veloise"] = {
        positive = {
            { amount = 500, description = "Complete The Lost Symbol, A Mother's Request, and The Princess Detective companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Return an Undaunted daily challenge offered by Bolgrul", cooldown = "Daily", categories = { "Undaunted" } },
            { amount = 125, description = "Return a High Isle group boss daily offered by Parisse Plouff", cooldown = "Daily", categories = { "World Boss" } },
            { amount = 25, amountLabel = "25 / 5", description = "Visit an Undaunted Enclave", cooldown = "20 hours", categories = { "Undaunted" } },
            { amount = 10, amountLabel = "10 / 5 / 1", description = "Talk to an alliance leader (Emeric / Ayrenn / Jorunn)", cooldown = "1 hour", categories = { "NPC Interaction" } },
            { amount = 10, description = "Talk to Lyris Titanborn", cooldown = "1 hour", categories = { "NPC Interaction" } },
            { amount = 10, description = "Complete a volcanic vent", cooldown = "Unknown, possibly bugged", categories = { "World Event" } },
            { amount = 10, description = "Kill a world boss", cooldown = "5 minutes", categories = { "World Boss" } },
            { amount = 5, description = "Craft sweet delicacies or fruit dishes", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 5, description = "Craft an item at a blacksmithing station", cooldown = "1 hour", categories = { "Crafting" } },
            { amount = 5, description = "Kill a delve boss or group dungeon boss", cooldown = "Unknown", categories = { "Dungeon" } },
            { amount = 5, description = "Kill a daedric boss", cooldown = "1 hour", categories = { "Combat" } },
            { amount = 1, description = "Kill a daedra", cooldown = "210 seconds", categories = { "Combat" } },
            { amount = 1, description = "Use a repair kit", cooldown = "Daily", categories = { "Repair" } },
            { amount = 1, description = "Accept a duel", cooldown = "Unknown", categories = { "Combat" } },
            { amount = 1, description = "Summon a dog non-combat pet", cooldown = "1 hour", categories = { "Pets" } },
        },
        negative = {
            { amount = -10, amountLabel = "10 / 1", description = "Murder", cooldown = "No cooldown", categories = { "Crime" } },
            { amount = -5, description = "Enter the Dark Brotherhood Sanctuary", cooldown = "20 hours", categories = { "Dark Brotherhood" } },
            { amount = -1, description = "Steal from a container or loot a thieves trove", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -1, description = "Enter an Outlaw's Refuge", cooldown = "Unknown", categories = { "Crime" } },
        },
    },

    ["Sharp-as-Night"] = {
        positive = {
            { amount = 500, description = "Complete Between a Rock and a Whetstone, Dim and Distant Pasts, and Light the Way to Freedom companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Return a Daily Boss quest offered by Ordinator Nelyn in Necrom", cooldown = "Daily", categories = { "World Boss" } },
            { amount = 125, description = "Complete an Ashlander daily quest offered by Huntmaster Sorim-Nakar or Numani-Rasi in Vvardenfell", cooldown = "Daily", categories = { "World Event" } },
            { amount = 10, description = "Obtain a monster trophy", cooldown = "10 minutes", categories = { "Combat" } },
            { amount = 10, description = "Visit the Hist tree sapling in Ebonheart, Hatching Pools, Haj Uxith, or Bright-Throat Village", cooldown = "10 minutes", categories = { "Exploration" } },
            { amount = 10, description = "Talk to M'aiq the Liar", cooldown = "Unknown", categories = { "NPC Interaction" } },
            { amount = 5, description = "Eat a meal", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 5, description = "Craft a poison", cooldown = "1 hour", categories = { "Alchemy" } },
            { amount = 5, amountLabel = "5 / 1", description = "Find a Treasure Map Chest (digging up the chest, not looting it)", cooldown = "No cooldown", categories = { "Treasure" } },
            { amount = 5, amountLabel = "5 / 1", description = "Find a Heavy Sack", cooldown = "No cooldown", categories = { "Treasure" } },
            { amount = 5, amountLabel = "5 / 1", description = "Catch a rare fish (green or better)", cooldown = "1 hour / no cooldown", categories = { "Fishing" } },
            { amount = 1, description = "Kill a Ghost", cooldown = "5 minutes", categories = { "Combat" } },
            { amount = 1, description = "Kill a Fabricant or Dwarven Construct", cooldown = "5 minutes", categories = { "Combat" } },
            { amount = 1, description = "Repair gear (merchant or repair kit)", cooldown = "Daily", categories = { "Repair" } },
            { amount = 1, description = "Recharge a weapon with a soul gem", cooldown = "Unknown", categories = { "Enchanting" } },
            { amount = 1, description = "Travel via Wayshrine", cooldown = "Unknown, unverified", categories = { "Travel" } },
            { amount = 1, description = "Use a soul gem to resurrect someone", cooldown = "Unknown", categories = { "Combat" } },
            { amount = 1, description = "Go fishing", cooldown = "10 minutes, unverified", categories = { "Fishing" } },
            { amount = 1, description = "Harvest any flower, mushroom, water, or apothecary satchel alchemy node", cooldown = "1 hour", categories = { "Gathering" } },
        },
        negative = {
            { amount = -10, description = "Pay a bounty to a guard", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Destroy items of the same type worth over 20 gold in inventory", cooldown = "5+ minutes", categories = { "Inventory" } },
            { amount = -5, description = "Pickpocket a beggar, laborer, or fisher", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -1, description = "Let your gear break", cooldown = "Unknown", categories = { "Repair" } },
            { amount = -1, description = "Use an outfitting station (decreases even if the outfit isn't changed - doesn't apply inside player homes)", cooldown = "Unknown", categories = { "Outfit Station" } },
        },
    },

    ["Azandar"] = {
        positive = {
            { amount = 500, description = "Complete Paths Unwalked, Adversarial Adventures, and Tempting Fates companion quests", cooldown = "Once each", categories = { "Companion Quest" } },
            { amount = 125, description = "Return the Ordinator Tilena Necrom delve daily", cooldown = "Daily", categories = { "Dungeon" } },
            { amount = 125, description = "Return an Enchanter Writ daily", cooldown = "Daily", categories = { "Enchanting" } },
            { amount = 15, description = "Return a Master Enchanter writ", cooldown = "15 minutes", categories = { "Enchanting" } },
            { amount = 15, description = "Collect a Psijic portal", cooldown = "15 minutes", categories = { "Psijic Order" } },
            { amount = 10, description = "Visit the Brass Fortress, The Hollow City, or Fargrave City District", cooldown = "Daily", categories = { "Exploration" } },
            { amount = 10, description = "Visit any Mundus Stone", cooldown = "Daily", categories = { "Mundus Stone" } },
            { amount = 5, description = "Complete an Oblivion Portal (may actually give +3)", cooldown = "No cooldown", categories = { "World Event" } },
            { amount = 5, description = "Interact with any Ayleid Well (Aetherial Wells on Auridon do not count)", cooldown = "1 hour", categories = { "Exploration" } },
            { amount = 5, description = "Read a new Mages Guild book", cooldown = "1 hour", categories = { "Mages Guild", "Books" } },
            { amount = 5, description = "Upgrade an item", cooldown = "Unknown", categories = { "Crafting" } },
            { amount = 5, description = "Acquire a lead", cooldown = "Unknown", categories = { "Antiquities" } },
            { amount = 5, description = "Scry", cooldown = "15 minutes", categories = { "Antiquities" } },
            { amount = 5, description = "Consume any tea-type beverage", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 5, amountLabel = "5 / 1", description = "Steal treasure of type Magic Curiosities, Maps, Writings, or Ritual Objects", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 5, amountLabel = "5 / 1", description = "Brew any tea-type beverage", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 5, amountLabel = "5 / 1", description = "Read a lorebook", cooldown = "Unknown", categories = { "Books" } },
            { amount = 1, description = "Kill a chaurus, duneripper, dreugh, harpy, mudcrab, nix-ox, ogre, or troll", cooldown = "15 minutes", categories = { "Combat" } },
        },
        negative = {
            { amount = -10, description = "Visit Artaeum or Eyevea (he's okay with The Scholarium)", cooldown = "15 minutes", categories = { "Psijic Order" } },
            { amount = -10, description = "Give to a beggar", cooldown = "Unknown", categories = { "Charity" } },
            { amount = -10, description = "Light a Campfire (Lightbringer)", cooldown = "Unknown", categories = { "Misc" } },
            { amount = -5, description = "Consume a beverage with Coffee", cooldown = "Unknown", categories = { "Provisioning" } },
            { amount = -1, description = "Pick a mushroom", cooldown = "15 minutes", categories = { "Gathering" } },
            { amount = -1, description = "Brew a beverage with Coffee", cooldown = "Unknown", categories = { "Provisioning" } },
            { amount = -1, description = "Play a game of Tales of Tribute", cooldown = "Unknown", categories = { "Tales of Tribute" } },
        },
    },

    ["Tanlorin"] = {
        positive = {
            { amount = 500, description = "Return their companion quests", cooldown = "Once", categories = { "Companion Quest" } },
            { amount = 125, description = "Return an Alchemy Writ daily", cooldown = "Daily", categories = { "Alchemy" } },
            { amount = 125, description = "Return a Dark Anchor contract offered by Cardea Gallus in the Fighters Guild", cooldown = "Daily", categories = { "Fighters Guild" } },
            { amount = 25, description = "Scribe a spell", cooldown = "Unknown", categories = { "Scribing" } },
            { amount = 10, description = "Visit a Mundus Stone", cooldown = "Daily", categories = { "Mundus Stone" } },
            { amount = 10, description = "Use a Mystery Transformation Verse in the Infinite Archive", cooldown = "Unknown", categories = { "Infinite Archive" } },
            { amount = 10, description = "Use the Persuasive Will passive in dialogue", cooldown = "Unknown", categories = { "NPC Interaction" } },
            { amount = 10, amountLabel = "10 / 1", description = "Pickpocket a guard or a noble", cooldown = "Unknown / no cooldown", categories = { "Crime" } },
            { amount = 5, description = "Visit Alinor", cooldown = "Unknown", categories = { "Exploration" } },
            { amount = 5, description = "Use the Campfire Kit or Glanir's Smoke Bomb memento", cooldown = "Unknown", categories = { "Misc" } },
            { amount = 5, description = "Drink wine", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 5, description = "Successfully lockpick a container or a door", cooldown = "1 hour", categories = { "Lockpicking" } },
            { amount = 5, description = "Hide in a basket while trespassing", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 5, description = "Use an Ayleid well", cooldown = "Unknown", categories = { "Exploration" } },
            { amount = 5, amountLabel = "5 / 1", description = "Obtain a skyshard", cooldown = "Unknown", categories = { "Skyshard" } },
            { amount = 5, description = "Gain any skill point", cooldown = "Unknown", categories = { "Skill Point" } },
            { amount = 5, description = "Use the Antiquarian's Eye at a dig site", cooldown = "1 hour", categories = { "Antiquities" } },
            { amount = 5, description = "Obtain a vision in the Infinite Archive", cooldown = "5 minutes", categories = { "Infinite Archive" } },
            { amount = 5, amountLabel = "5 / 1", description = "Harvest a flower", cooldown = "1 hour / no cooldown", categories = { "Gathering" } },
            { amount = 5, amountLabel = "5 / 1", description = "Fill a Soul Gem using the Soul Trap skill", cooldown = "1 hour / no cooldown", categories = { "Combat" } },
            { amount = 5, amountLabel = "5 / 1", description = "Loot a Scribing script", cooldown = "No cooldown", categories = { "Scribing" } },
            { amount = 5, amountLabel = "5 / 1", description = "Return a Witches Festival or Imperial Charity Writ", cooldown = "No cooldown", categories = { "Festival" } },
            { amount = 5, amountLabel = "5 / 1", description = "Interact (dance/pet) with an animal", cooldown = "Unknown", categories = { "Misc" } },
            { amount = 5, amountLabel = "5 / 1", description = "Craft a Furnishing", cooldown = "No cooldown", categories = { "Furnishing" } },
            { amount = 5, amountLabel = "5 / 1", description = "Return a New Life Festival quest", cooldown = "1 hour / no cooldown", categories = { "Festival" } },
            { amount = 1, description = "Learn a furnishing plan", cooldown = "1 hour", categories = { "Furnishing" } },
            { amount = 1, description = "Craft wine", cooldown = "1 hour", categories = { "Provisioning" } },
            { amount = 1, description = "Mount an Indrik", cooldown = "1 hour", categories = { "Misc" } },
            { amount = 1, description = "Trespass", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 1, description = "Successfully run away from a guard", cooldown = "Unknown", categories = { "Crime" } },
            { amount = 1, description = "Kill a hostile daedra", cooldown = "4 minutes", categories = { "Combat" } },
            { amount = 1, description = "Kill a hostile Maormer", cooldown = "5 minutes", categories = { "Combat" } },
            { amount = 1, description = "Obtain a verse in the Infinite Archive", cooldown = "No cooldown", categories = { "Infinite Archive" } },
            { amount = 1, description = "Loot a Plunder Skull", cooldown = "Unknown", categories = { "Treasure" } },
        },
        negative = {
            { amount = -10, amountLabel = "10 / 1", description = "Murder", cooldown = "3 hours / no cooldown", categories = { "Crime" } },
            { amount = -10, amountLabel = "10 / 1", description = "Use the Blade of Woe, including against enemies", cooldown = "5 minutes / no cooldown", categories = { "Crime" } },
            { amount = -5, description = "Visit Artaeum", cooldown = "Unknown", categories = { "Psijic Order" } },
            { amount = -1, description = "Loot a Psijic Portal", cooldown = "Unknown", categories = { "Psijic Order" } },
            { amount = -1, description = "Kill a Gryphon, Indrik, or Chimera", cooldown = "Unknown", categories = { "Combat" } },
            { amount = -1, description = "Harvest Nirnroot or Crimson Nirnroot", cooldown = "1 hour", categories = { "Gathering" } },
            { amount = -1, description = "Visit a Mages Guild guildhall (being in the vicinity can trigger it)", cooldown = "1 hour", categories = { "Mages Guild" } },
            { amount = -1, description = "Read a lorebook", cooldown = "Unknown", categories = { "Books" } },
            { amount = -1, description = "Steal treasure of type Children's Toys or Dolls", cooldown = "Unknown", categories = { "Crime" } },
        },
    },

    ["Zerith-var"] = {
        positive = {
            { amount = 500, description = "Complete his companion quests", cooldown = "Once per quest", categories = { "Companion Quest" } },
            { amount = 150, description = "Complete Maw of Lorkhaj with Zerith-var present", cooldown = "Unknown", categories = { "Trial" } },
            { amount = 125, description = "Complete a Defense Force quest offered by Zahari at Grahtwood Northern Gate", cooldown = "Daily", categories = { "World Event" } },
            { amount = 125, description = "Complete a Tales of Tribute daily quest (only one per day)", cooldown = "Daily", categories = { "Tales of Tribute" } },
            { amount = 25, description = "Complete an Antiquity with multiple pieces, such as a Mythic item", cooldown = "1 hour", categories = { "Antiquities" } },
            { amount = 10, amountLabel = "10 / 1", description = "Complete a Dark Anchor encounter", cooldown = "1 hour", categories = { "World Event" } },
            { amount = 10, amountLabel = "10 / 1", description = "Kill a Dragon", cooldown = "1 hour", categories = { "Combat" } },
            { amount = 10, amountLabel = "10 / 1", description = "Complete a Tales of Tribute match", cooldown = "10 minutes", categories = { "Tales of Tribute" } },
            { amount = 10, description = "Complete The Demon Weapon or The Halls of Colossus", cooldown = "Unknown", categories = { "Dungeon" } },
            { amount = 10, description = "Kill a Marauder in the Infinite Archive", cooldown = "Unknown", categories = { "Infinite Archive" } },
            { amount = 10, description = "Cure yourself of Vampirism", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = 10, description = "Drink a Purifying Bloody Mara", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = 10, description = "Excavate an Antiquity whose codex is incomplete", cooldown = "1 hour", categories = { "Antiquities" } },
            { amount = 10, description = "Give to a beggar", cooldown = "Unknown", categories = { "Charity" } },
            { amount = 10, description = "Heal yourself in combat while below 25% health", cooldown = "Unknown", categories = { "Combat" } },
            { amount = 5, description = "Visit Baandari Trading Post", cooldown = "Unknown", categories = { "Exploration" } },
            { amount = 5, description = "Loot a heavy sack", cooldown = "2-5 hours", categories = { "Treasure" } },
            { amount = 5, description = "Harvest a water node", cooldown = "1 hour", categories = { "Gathering" } },
            { amount = 5, description = "Defeat Tho'at Replicanum in the Infinite Archive", cooldown = "Unknown", categories = { "Infinite Archive" } },
            { amount = 10, amountLabel = "5 to 10", description = "Defeat Aramril in the Infinite Archive", cooldown = "Unknown", categories = { "Infinite Archive" } },
            { amount = 1, description = "Kill an undead enemy (Vampire or Skeleton)", cooldown = "3 minutes", categories = { "Combat" } },
            { amount = 1, description = "Kill a dro-m'Athra", cooldown = "2 minutes", categories = { "Combat" } },
            { amount = 1, description = "Defeat a boss in the Infinite Archive", cooldown = "Unknown", categories = { "Infinite Archive" } },
        },
        negative = {
            { amount = -50, description = "Complete the Scion of the Blood Matron quest to become a vampire", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = -25, description = "Infect another player with Vampirism", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = -10, description = "Soultrap someone with the Soul Trap skill (not if from the Soul Lock passive)", cooldown = "Unknown", categories = { "Combat" } },
            { amount = -5, amountLabel = "5 / 1", description = "Steal a medicinal, religious, or sentimental item", cooldown = "1 hour or relog / no cooldown", categories = { "Crime" } },
            { amount = -5, description = "Use a Counterfeit Pardon Edict or Leniency Edict", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Fence stolen goods", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -5, description = "Drink a Corrupting Bloody Mara", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = -5, description = "Travel to the Hollow City in Coldharbour", cooldown = "Unknown", categories = { "Exploration" } },
            { amount = -5, description = "Speak to Cadwell", cooldown = "Unknown", categories = { "NPC Interaction" } },
            { amount = -1, description = "Get a bounty", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -1, description = "Select the Dro-m'Athra skin", cooldown = "Unknown", categories = { "Vampire" } },
            { amount = -1, description = "Murder an innocent", cooldown = "Unknown", categories = { "Crime" } },
            { amount = -1, description = "Feed as a vampire, including on hostile NPCs", cooldown = "Unknown", categories = { "Vampire" } },
        },
    },
}

local function GetCompanionIdByName(name)
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        if companion.name == name then
            return companion.id
        end
    end
    return nil
end

local function ActionMatches(action, term)
    for _, category in ipairs(action.categories) do
        if zo_strlower(category):find(term, 1, true) then
            return true
        end
    end
    return zo_strlower(action.description):find(term, 1, true) ~= nil
end

-- This companion's Guild-type skill lines (Fighters Guild, Mages Guild,
-- Undaunted) whose name contains `term`, as { name, rank, isMaxed }. Empty
-- when the term isn't a Guild skill line, or the companion's skill lines
-- were never recorded (they're only readable while that companion is out).
local function GetMatchingGuildLines(companionId, term)
    local matches = {}
    local skillLines = companionId and CompanionRoster.Data.GetSkillLinesForCompanion(companionId)
    if skillLines == nil then
        return matches
    end

    local guildTypeName = GetString("SI_SKILLTYPE", SKILL_TYPE_GUILD)
    for _, group in ipairs(skillLines) do
        if group.typeName == guildTypeName then
            for _, line in ipairs(group.lines) do
                if zo_strlower(line.name):find(term, 1, true) then
                    table.insert(matches, { name = line.name, rank = line.rank, isMaxed = line.isMaxed })
                end
            end
        end
    end
    return matches
end

-- Ranks companions by the best (highest-amount) matching positive rapport
-- action for `term` (case-insensitive substring match against each
-- action's categories and description text). A companion already at max
-- rapport on the CURRENT character is demoted below everyone else, since
-- another point of rapport can't do anything for them - falls back to
-- showing them anyway (flagged isMaxed) if nobody else has a match at all.
function CompanionRoster.Data.SearchRapportTips(term)
    term = zo_strlower(term or "")
    if term == "" then
        return {}
    end

    local characterKey = CompanionRoster.Data.GetCurrentCharacterName()
    local recordedCompanions = CompanionRoster.Data.GetCompanionsForCharacter(characterKey)

    local results = {}
    for companionName, tips in pairs(CompanionRoster.RapportTips) do
        local bestMatch = nil
        for _, action in ipairs(tips.positive) do
            if ActionMatches(action, term) and (bestMatch == nil or action.amount > bestMatch.amount) then
                bestMatch = action
            end
        end

        if bestMatch then
            local companionId = GetCompanionIdByName(companionName)
            local recorded = companionId and recordedCompanions[companionId]
            local isMaxed = recorded ~= nil and recorded.rapportValue ~= nil and recorded.rapportMax ~= nil
                and recorded.rapportValue >= recorded.rapportMax

            local skillLineRanks = GetMatchingGuildLines(companionId, term)
            local lowestSkillRank = nil
            for _, line in ipairs(skillLineRanks) do
                if lowestSkillRank == nil or line.rank < lowestSkillRank then
                    lowestSkillRank = line.rank
                end
            end

            table.insert(results, {
                companionName = companionName,
                companionId = companionId,
                amount = bestMatch.amount,
                amountLabel = bestMatch.amountLabel,
                description = bestMatch.description,
                cooldown = bestMatch.cooldown,
                isMaxed = isMaxed,
                rapportValue = recorded and recorded.rapportValue,
                rapportMax = recorded and recorded.rapportMax,
                skillLineRanks = skillLineRanks,
                lowestSkillRank = lowestSkillRank,
            })
        end
    end

    -- Most rapport gained comes first; only when that ties does the lower
    -- Guild skill line rank win (more room to gain), with an unknown rank
    -- after a known one, then name so the order is stable.
    table.sort(results, function(a, b)
        if a.isMaxed ~= b.isMaxed then
            return not a.isMaxed
        end
        if a.amount ~= b.amount then
            return a.amount > b.amount
        end
        if a.lowestSkillRank ~= b.lowestSkillRank then
            if a.lowestSkillRank == nil then
                return false
            end
            if b.lowestSkillRank == nil then
                return true
            end
            return a.lowestSkillRank < b.lowestSkillRank
        end
        return a.companionName < b.companionName
    end)

    return results
end

-- Copies a tips list sorted by magnitude (biggest effect first). Ties keep
-- their original table order, since table.sort alone isn't stable.
local function SortedByMagnitude(actions, descending)
    local indexed = {}
    for i, action in ipairs(actions) do
        indexed[i] = { action = action, index = i }
    end
    table.sort(indexed, function(a, b)
        if a.action.amount ~= b.action.amount then
            if descending then
                return a.action.amount > b.action.amount
            end
            return a.action.amount < b.action.amount
        end
        return a.index < b.index
    end)

    local sorted = {}
    for i, entry in ipairs(indexed) do
        sorted[i] = entry.action
    end
    return sorted
end

-- Finds companions whose name contains `term` (case-insensitive), so a
-- partial name like "tan" works. An exact name match wins outright, so it
-- never reports an ambiguity against a longer name that happens to contain it.
-- Returns a list of { name, likes, dislikes }: likes biggest gain first,
-- dislikes biggest loss first.
function CompanionRoster.Data.FindRapportTipsByName(term)
    term = zo_strlower(term or "")
    if term == "" then
        return {}
    end

    local matches = {}
    for companionName, tips in pairs(CompanionRoster.RapportTips) do
        local lowerName = zo_strlower(companionName)
        local entry = {
            name = companionName,
            likes = SortedByMagnitude(tips.positive, true),
            dislikes = SortedByMagnitude(tips.negative, false),
        }
        if lowerName == term then
            return { entry }
        end
        if lowerName:find(term, 1, true) then
            table.insert(matches, entry)
        end
    end

    table.sort(matches, function(a, b) return a.name < b.name end)
    return matches
end
