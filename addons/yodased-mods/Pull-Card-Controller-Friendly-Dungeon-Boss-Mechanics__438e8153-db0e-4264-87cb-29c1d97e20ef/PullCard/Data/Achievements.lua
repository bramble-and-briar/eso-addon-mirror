-- Dungeon-wide achievements shown in each Dungeon Overview with done/not done.
-- Names are exact in-game text (datamined; ESO Decoded / UESP esolog).
-- Hard mode achievements live on the boss (HardModes.lua) and are counted too.

local ach = PullCardData.setDungeonAchievements

-- Veteran clear, speed run, no death.
local function vet(dungeonName, prefix, survivorName)
    ach(dungeonName, {
        prefix .. " Conqueror",
        prefix .. " Assassin",
        survivorName or (prefix .. " Survivor"),
    })
end

-- Base game
vet("Arx Corinium", "Arx Corinium")
vet("The Banished Cells I", "Banished Cells I")
vet("The Banished Cells II", "Banished Cells II")
vet("Blackheart Haven", "Blackheart Haven")
vet("Blessed Crucible", "Blessed Crucible")
vet("City of Ash I", "City of Ash I")
vet("City of Ash II", "City of Ash II", "Deadly Deadlands Survivor")
vet("Crypt of Hearts I", "Crypt of Hearts I")
vet("Crypt of Hearts II", "Crypt of Hearts II", "Deadly Crypt Survivor")
vet("Darkshade Caverns I", "Darkshade Caverns I")
vet("Darkshade Caverns II", "Darkshade Caverns II")
vet("Direfrost Keep", "Direfrost Keep")
vet("Elden Hollow I", "Elden Hollow I")
vet("Elden Hollow II", "Elden Hollow II")
vet("Fungal Grotto I", "Fungal Grotto I")
vet("Fungal Grotto II", "Fungal Grotto II")
vet("Selene's Web", "Selene's Web")
vet("Spindleclutch I", "Spindleclutch I")
vet("Spindleclutch II", "Spindleclutch II")
vet("Tempest Island", "Tempest Island")
vet("Vaults of Madness", "Vaults of Madness")
vet("Volenfell", "Volenfell")
vet("Wayrest Sewers I", "Wayrest Sewers I")
vet("Wayrest Sewers II", "Wayrest Sewers II")

-- DLC: Veteran clear, speed run, no death, trifecta (hard mode + speed + no death).
-- Source: esodecoded.com/achievements/dlc-dungeons (datamined).
local function dlc(dungeonName, names) ach(dungeonName, names) end

dlc("Imperial City Prison", { "Imperial City Prison Conqueror", "No Prison Can Hold Me", "Life Sentence" })
dlc("White-Gold Tower", { "White-Gold Tower Conqueror", "First to the Top", "To Spite a Tharn" })
dlc("Cradle of Shadows", { "Cradle of Shadows Conqueror", "Exterminator", "Beacon in the Night" })
dlc("Ruins of Mazzatun", { "Ruins of Mazzatun Conqueror", "Ruination", "Unbowed" })
dlc("Bloodroot Forge", { "Bloodroot Forge Conqueror", "Right to the Root of the Problem", "Parched Earth" })
dlc("Falkreath Hold", { "Falkreath Hold Conqueror", "Bull Rush", "The Unbroken Line" })
dlc("Fang Lair", { "Fang Lair Conqueror", "The Quick and the Dead", "Not a Statistic", "Leave No Bone Unbroken" })
dlc("Scalecaller Peak", { "Scalecaller Peak Conqueror", "Peak Performance", "On Top", "Mountain God" })
dlc("March of Sacrifices", { "March of Sacrifices Conqueror", "Pure Instinct", "Survival of the Fittest", "Apex Predator" })
dlc("Moon Hunter Keep", { "Moon Hunter Keep Conqueror", "Running with the Pack", "Head of the Pack", "Pure Lunacy" })
dlc("Depths of Malatar", { "Depths of Malatar Conqueror", "The Speed of Light", "Purified", "Depths Defier" })
dlc("Frostvault", { "Frostvault Conqueror", "Smash and Grab", "Safe Keeping", "Relentless Raider" })
dlc("Lair of Maarselok", { "Lair of Maarselok Conqueror", "Weed Eater", "Undying Endurance", "Nature's Wrath" })
dlc("Moongrave Fane", { "Moongrave Fane Conqueror", "Blood Rush", "Escape the Grave", "Defanged the Devourer" })
dlc("Icereach", { "Icereach Conqueror", "Thane's Haste", "Hex-Proof", "No Rest for the Wicked" })
dlc("Unhallowed Grave", { "Unhallowed Grave Conqueror", "Grave Robber", "Unscathed Grave", "In Defiance of Death" })
dlc("Castle Thorn", { "Castle Thorn Conqueror", "Homewrecker", "Impervious Onslaught", "Bane of Thorns" })
dlc("Stone Garden", { "Stone Garden Conqueror", "Expeditious Experimenter", "Safety First!", "True Genius" })
dlc("Black Drake Villa", { "Black Drake Villa Conqueror", "Speed Reader", "Unsinged", "Ardent Bibliophile" })
dlc("The Cauldron", { "The Cauldron Conqueror", "Hot-Footed", "Relentless Justice", "Subterranean Smasher" })
dlc("The Dread Cellar", { "The Dread Cellar Conqueror", "Dreadful Dash", "Stay of Execution", "Battlespire's Best" })
dlc("Red Petal Bastion", { "Red Petal Bastion Conqueror", "World's Shortest Siege", "Untarnished Victory", "Bastion Breaker" })
dlc("Coral Aerie", { "Coral Aerie Conqueror", "Aerie Glider", "Shellback", "Land, Air, and Sea Supremacy" })
dlc("Shipwright's Regret", { "Shipwright's Regret Conqueror", "Shipyard Sprint", "In Shipshape", "Zero Regrets" })
dlc("Earthen Root Enclave", { "Earthen Root Enclave Conqueror", "Swift Retaliation", "Hardy Hero", "Invaders' Bane" })
dlc("Graven Deep", { "Graven Deep Conqueror", "Storming the Beach", "Life Among the Undying", "Fist of Tava" })
dlc("Scrivener's Hall", { "Scrivener's Hall Conqueror", "Speed Reader", "Unstilled Quill", "Magnastylus in the Making" })
dlc("Bal Sunnar", { "Bal Sunnar Conqueror", "Time's Arrow", "Fate's Master", "Temporal Tempest" })
dlc("Bedlam Veil", { "Bedlam Veil Conqueror", "Following a Path", "Demiprince's Delight", "Unshakeable Fervor" })
dlc("Oathsworn Pit", { "Oathsworn Pit Conqueror", "Malacath's Swift Revenge", "Enduring Retribution", "Lighting the Embers" })
dlc("Exiled Redoubt", { "Exiled Redoubt Conqueror", "Swift Hand of Justice", "Leave No Ghosts", "Revenge Breaker" })
dlc("Lep Seclusa", { "Lep Seclusa Conqueror", "Quick Deliverance", "Strike True", "Sic Semper" })
dlc("Black Gem Foundry", { "Black Gem Foundry Conqueror", "Quicksilver", "Flawless Execution", "Cut Above the Rest" })
dlc("Naj-Caldeesh", { "Naj-Caldeesh Conqueror", "Unexplored not Unhurried", "Grave Song Silenced", "Key to the Stone" })
