-- Tamriel Collections - user-verified Style Page source/map corrections
-- v0.1.15
--
-- These records are authoritative overrides collected from in-game PS5 testing.
-- They are loaded after StylePageSources.lua.  Do not infer or fuzzy-match a
-- destination for any entry here: the explicit map type/target is intentional.

local sources = TamrielCollectionsStylePageSources or {}
TamrielCollectionsStylePageSources = sources

local function Patch(name, values)
    local record = sources[name]
    if type(record) ~= 'table' then
        record = {}
        sources[name] = record
    end
    for key, value in pairs(values) do
        record[key] = value
    end
end

local function Hub(name, hub, location, text)
    local values = {
        mapType = 'HUB',
        hub = hub,
        location = location,
    }
    if text then values.text = text end
    Patch(name, values)
end

local function Node(name, nodeName, location, text)
    local values = {
        mapType = 'NODE',
        nodeName = nodeName,
        location = location or nodeName,
    }
    if text then values.text = text end
    Patch(name, values)
end

local function Zone(name, zoneName, location, text)
    local values = {
        mapType = 'ZONE',
        zoneName = zoneName,
        location = location or zoneName,
    }
    if text then values.text = text end
    Patch(name, values)
end

local function Poi(name, poiName, zoneName, location, text)
    local values = {
        mapType = 'POI',
        poiName = poiName,
        zoneName = zoneName,
        location = location or poiName,
    }
    if text then values.text = text end
    Patch(name, values)
end

-- -------------------------------------------------------------------------
-- Event merchant / Impresario destinations
-- -------------------------------------------------------------------------
Hub('Zenithar Battlesmith', 'BELKARTH_IMPRESARIO', 'Impresario / Event Exchange - Belkarth')
Hub('Kwama Miner\'s Kit', 'BELKARTH_IMPRESARIO', 'Impresario / Event Exchange - Belkarth')
Hub('High Rock Spellsword', 'BELKARTH_IMPRESARIO', 'Impresario / Event Exchange - Belkarth')
Hub('Gold Road Dragoon', 'BELKARTH_IMPRESARIO', 'Impresario / Event Exchange - Belkarth')
Hub('Heart\'s Day Duelist', 'BELKARTH_IMPRESARIO', 'Heart\'s Week / Impresario - Belkarth Festival Grounds')

Hub('Worm Cult Hunter', 'GLENUMBRA_IMPRESARIO', 'Impresario / Event Exchange - Glenumbra')

for _, name in ipairs({
    'Lion Guard Captain',
    'Earthbone Ayleid',
    'Earthbound Ayleid',
    'Dapper Daredevil',
    'Bucket',
    'Bonemold',
    'Second Seed Raiment',
    'Sai Sahan',
    'Regal Regalia',
    'Prophet',
    'Abnur Tharn',
    'Lyris Titanborn',
    "Jester's Seeker Suit",
    'One Bad Knight',
    'Jephrine Paladin',
    'Jade-Crown Dragonslayer',
}) do
    Hub(name, 'IMPRESARIO', 'Impresario / Event Exchange')
end

local jesterMimicryText = [[Jester's Festival: obtain these Mimicry Style Pages from Jester's Festival rewards and the event merchant when offered.]]
for _, name in ipairs({
    "Jester's Aldmeri Mimicry",
    "Jester's Covenant Mimicry",
    "Jester's Pact Mimicry",
}) do
    Hub(name, 'IMPRESARIO', 'Impresario / Event Exchange', jesterMimicryText)
end

-- -------------------------------------------------------------------------
-- Battleground styles: all user-verified to the Battleground location in
-- Alinor's Gladiator's Quarters (the exact coordinate is resolved by HUB).
-- -------------------------------------------------------------------------
for _, name in ipairs({
    'Truth in Wisdom',
    "Dovah's Du'ul",
    'Arkay Unending Cycle',
    'Battleground Runner',
    'Legion Zero',
    'House Dufort Banneret',
    'Ebonsteel Knight',
    'Galeskirmish Gladiator',
    'Black Drake Clanwrap',
    'Second Legion',
    'Legion Zero Vigiles',
    "Tava's Goshawk",
}) do
    Hub(name, 'BATTLEGROUNDS', "Battlegrounds - Gladiator's Quarters, Alinor")
end

-- -------------------------------------------------------------------------
-- Witches Festival: use Crosswych Wayshrine, the user-verified nearest
-- wayshrine for Olyve's Brewery.
-- -------------------------------------------------------------------------
for _, name in ipairs({
    'Glenmoril Wyrd',
    'Crowborne Hunter',
    'Zhekleg',
    "Witchmother's Servant",
    'Eltheric Revenant',
    'Wickerchain Soul',
}) do
    Hub(name, 'WITCHES', "Witches Festival - Olyve's Brewery near Crosswych Wayshrine")
end

-- -------------------------------------------------------------------------
-- Infinite Archive styles
-- -------------------------------------------------------------------------
local infiniteArchiveText = [[Infinite Archive: obtain these Style Pages from Infinite Archive rewards and its associated reward sources.]]
for _, name in ipairs({
    'Wrathsun',
    'Monolith of Storms',
    'Soulcleaver',
    'Reawakened Hierophant',
    'Nobility in Decay',
    'Gardener of Seasons',
    'Basalt-Blood Warrior',
}) do
    Hub(name, 'INFINITE_ARCHIVE', 'Infinite Archive', infiniteArchiveText)
end

-- -------------------------------------------------------------------------
-- Achievement / chapter locations
-- -------------------------------------------------------------------------
Node('Shroomtender', 'Necrom Wayshrine', 'Necrom',
    [[Necrom: obtain Shroomtender pieces by completing the linked Necrom achievements shown below.]])
Node("Nantharion's Royal", 'Skingrad Wayshrine', 'Skingrad - Gold Road',
    [[Gold Road: obtain Nantharion's Royal pieces by completing the linked Gold Road achievements shown below.]])
Node('Knights of the Scythe', 'Sunport Wayshrine', 'Sunport - Solstice',
    [[Solstice: obtain Knights of the Scythe pieces by completing the linked Solstice achievements shown below.]])
Node('Chaplain of the Worm', 'Sunport Wayshrine', 'Sunport - Solstice',
    [[Solstice: obtain Chaplain of the Worm pieces by completing the linked Solstice achievements shown below.]])

-- -------------------------------------------------------------------------
-- Exact dungeons, trial, activity hubs, and quest locations
-- -------------------------------------------------------------------------
Node('Lucent Sentinel', 'Lucent Citadel', 'Lucent Citadel Trial',
    [[Lucent Citadel Trial: obtain Lucent Sentinel Style Pages from Lucent Citadel weekly coffers and related trial rewards.]])
Hub('Lady Thorn', 'UNDAUNTED_WAYREST', 'Undaunted Enclave - Wayrest',
    [[Undaunted Enclave: obtain the Lady Thorn Shoulder Style Page from the Undaunted shoulder vendor/reward source.]])
Node('Tarcyr', 'March of Sacrifices', 'March of Sacrifices',
    [[Solo March of Sacrifices: the Tarcyr Mask is obtained from Balorgh; the Tarcyr Shoulder is available from the Undaunted shoulder vendor.]])
Node('Myleene Moon-Caller', 'Moon Hunter Keep', 'Moon Hunter Keep',
    [[Moon Hunter Keep: obtain the Myleene Moon-Caller Style Page from its Moon Hunter Keep source.]])
Node('Mylenne Moon-Caller', 'Moon Hunter Keep', 'Moon Hunter Keep',
    [[Moon Hunter Keep: obtain the Myleene Moon-Caller Style Page from its Moon Hunter Keep source.]])
Node('Dread-Aurelian', 'Moongrave Fane', 'Moongrave Fane',
    [[Scalebreaker achievements: Dread-Aurelian rewards require Scalebreaker dungeon achievements. Show on Map opens Moongrave Fane as the selected dungeon destination.]])
Node('Wormwrithe', 'Stirk Wayshrine', 'Stirk Fellowship Camp',
    [[Writhing Wall: obtain Wormwrithe Style Pages from Writhing Wall daily quest coffers and associated event rewards at the Stirk Fellowship Camp.]])
Node('Alessian Rebel', 'Vulkhel Guard Wayshrine', 'Auridon - Dynamic Encounter near Vulkhel Guard',
    [[Dynamic Encounters: obtain Alessian Rebel Style Pages from the relevant dynamic encounters; Show on Map opens the Auridon encounter starting area near Vulkhel Guard.]])

-- Tales of Tribute / Gonfalon Gaming Hall
for _, name in ipairs({ "Frandar's Tribute", 'Psijic Psion', "Pelin's Paragon" }) do
    Poi(name, 'Gonfalon Gaming Hall', 'High Isle and Amenos', 'Gonfalon Gaming Hall')
end

-- Night Market / Fargrave
for _, name in ipairs({
    'Ruckus', 'The Ruckus', 'Glittering Goad', 'Thousand Eyes',
    'Helm of the Ruckus', 'Helm of the Glittering Goad', 'Helm of the Thousand Eyes',
    'Shoulder of the Ruckus', 'Shoulders of the Ruckus',
    'Shoulder of the Glittering Goad', 'Shoulders of the Glittering Goad',
    'Shoulder of the Thousand Eyes', 'Shoulders of the Thousand Eyes',
}) do
    Hub(name, 'NIGHT_MARKET', 'Night Market - Fargrave',
        [[Night Market: obtain this Style Page from the Night Market event in Fargrave.]])
end

-- Greymoor prologue / Windhelm Scale
local windhelmText = [[Greymoor Prologue: obtain Windhelm Scale through Lyris Titanborn's quest "The Coven Conundrum." Show on Map opens Solitude, the main city of Western Skyrim.]]
Node('Windhelm Scale', 'Solitude Wayshrine', 'Solitude - Western Skyrim', windhelmText)
Node('Windhelm Scale Tunic', 'Solitude Wayshrine', 'Solitude - Western Skyrim', windhelmText)

-- Vvardenfell Barbas reward
local barbasText = [[Vvardenfell: obtain the Barbas Helmet Replica through its Vvardenfell reward source. Show on Map opens Vivec City.]]
Node('Barbas Helmet Replica', 'Vivec City Wayshrine', 'Vivec City - Vvardenfell', barbasText)
Node('Barbas Replica', 'Vivec City Wayshrine', 'Vivec City - Vvardenfell', barbasText)

-- -------------------------------------------------------------------------
-- Zone-level destinations
-- -------------------------------------------------------------------------
Zone('Oaken Order', 'High Isle and Amenos', 'High Isle')
Zone("Annihilarch's Chosen", 'Deadlands', 'Deadlands - Oblivion Portals')
Zone('Annihilarch Chosen', 'Deadlands', 'Deadlands - Oblivion Portals')
Zone("Yffre's Fallen-Wood", 'Blackwood', 'Blackwood')
Zone("Yffres Fallen-Wood", 'Blackwood', 'Blackwood')
Zone('Doctrine Ordinator', 'Clockwork City', 'Clockwork City')
Zone('Saarthal Scholar', 'The Reach', 'The Reach')
Zone('Red Rook Bandit', 'Imperial City', 'Imperial City',
    [[Imperial City: obtain Red Rook Bandit Style Pages from their Imperial City reward source.]])
Zone('Light of Knowledge', 'Summerset', 'Summerset')
Zone('Claw-Dance Acolyte', 'Northern Elsweyr', 'Northern Elsweyr')
Zone('Sovngarde Stalwart', 'The Reach', 'The Reach')
Node('Apocrypha Expedition', 'Necrom Wayshrine', 'Necrom',
    [[Necrom / Secrets of the Telvanni: obtain Apocrypha Expedition Style Pages from the relevant Necrom/Telvanni event reward sources.]])
Zone('Legacy of the Draoife', 'Galen', 'Galen')
Zone("Ja'zennji Siir", 'Northern Elsweyr', 'Northern Elsweyr',
    [[Pan-Elsweyr Celebration: obtain Ja'zennji Siir Style Pages from Elsweyr event reward coffers and related event sources.]])

-- -------------------------------------------------------------------------
-- Opal monster styles: every family is explicitly wired to its dungeon.
-- -------------------------------------------------------------------------
local function Opal(name, dungeon)
    Node(name, dungeon, dungeon,
        string.format('Undaunted Celebration: the Opal %s style is tied to %s. The mask comes from the associated Veteran dungeon boss during the event; shoulder/weapon pages come from the corresponding Undaunted/event reward sources.',
            name:gsub('^Opal ', ''), dungeon))
end

Opal('Opal Chokethorn', 'Elden Hollow I')
Opal('Opal Earthgore', 'Bloodroot Forge')
Opal('Opal Ilambris', 'Crypt of Hearts I')
Opal('Opal Troll King', 'Blessed Crucible')
Opal('Opal Engine Guardian', 'Darkshade Caverns II')
Opal('Opal Bloodspawn', 'Spindleclutch II')
Opal('Opal Iceheart', 'Direfrost Keep')
Opal('Opal Swarm Mother', 'Spindleclutch I')
Opal('Opal Lord Warden', 'Imperial City Prison')
Opal('Opal Nightflame', 'Elden Hollow II')
Opal('Opal Rkugamz Sentinel', 'Darkshade Caverns I')
Opal('Opal Sentinel of Rkugamz', 'Darkshade Caverns I')
Opal('Opal Velidreth', 'Cradle of Shadows')
Opal('Opal Scourge Harvester', 'Wayrest Sewers II')
