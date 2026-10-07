-- Multi-boss and exclusion data adapted from Character Zone Tracker 1.3.0.
-- https://www.esoui.com/downloads/info3323-CharacterZoneTracker.html
-- Data originally researched from UESP; legacy coverage through March 2022.
--[[
MIT License

Copyright (c) 2022 silvereyes

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]
-- Boss names provided by https://en.uesp.net/wiki/Online:Delves. Thank you!

ZoneSweepMultiBossDelves = {

-- Sheogorath's Tongue, Stonefalls
[291] = {"Dezanu", "Calls-to-Nature"},

-- Erokii Ruins, Rivenspire
[325] = {"Abal-jo", "Earelcar", "Miruin Woodwalker"},

-- Torog's Spite, Bangkorai
[333] = {"Lorogdu gra-Gulash", "Ograt gro-Gulash", "Tazgul gro-Gulash"},

-- Old Sord's Cave, Eastmarch
[361] = {"Braxek", "Eorim the Hammer", "Gadof"},

-- Claw's Strike, Reaper's March
[465] = {"Fishbreath", "Lord Tawnlii-do"},

-- Breakneck Cave, Cyrodiil
[493] = {"Hegris the Black Dagger", "Longfang"},

-- Cracked Wood Cave, Cyrodiil
[495] = {"Mebs Runnyeye", "Regsrot Blacktongue", "Traug Wolfbreath"},

-- Haynote Cave, Cyrodiil
[497] = {"Theurgist Thelas", "Diabolist Volcatia"},

-- Lipsand Tarn, Cyrodiil
[499] = {"Gaston Ashham", "Marbita"},

-- Muck Valley Cavern, Cyrodiil
[500] = {"Kerks Half-Ear", "Ogre Biter", "Webmistress"},

-- Nisin Cave, Cyrodiil
[502] = {"Barasatii", "Volgo the Harrower"},

-- Pothole Caverns, Cyrodiil
[503] = {"Serrin Vol", "Diabolist Vethisa", "Blighttooth"},

-- Quickwater Cave, Cyrodiil
[504] = {"Athal Andas", "Steel-Tail"},

-- Red Ruby Cave, Cyrodiil
[505] = {"Endare", "Zandur"},

-- Serpent Hollow Cave, Cyrodiil
[506] = {"Bruuke", "Bear Matriarch"},

-- Bloodmayne Cave, Cyrodiil
[507] = {"Acanthia, Chosen of Nirn", "Razorback", "Ironlash"},

-- Toadstool Hollow, Cyrodiil
[531] = {"Lucienne Cerine", "Captain Roreles", "Captain Serniel", "General Virane", "Dreadfang"},

-- Underpall Cave, Cyrodiil
[533] = {"Raelynne Ashham", "Emelin the Returned"},

-- Shark's Teeth Grotto, Hew's Bane
[676] = {"First Mate Rodros", "Krona Keeba"},

-- Bahraha's Gloom, Hew's Bane
[817] = {"The First", "Magnifico Bahraha"},

-- Molavar, Craglorn
[889] = {"The Charnel Cage", "Thaliel the Voracious"},

-- Serpent's Nest, Craglorn
[891] = {"Aurieae", "Laurieae", "Taurieae"},

-- Ilthag's Undertower, Craglorn
[892] = {"Uzka Trollfeeder", "Killraken", "Vrauloch", "Ilthag Ironblood", "Vosh", "Rahk"},

-- Haddock's Market, Craglorn
[896] = {"Ariana At-Fara", "Grandmother Thunder"},

-- Mtharnaz, Craglorn
[899] = {"The Brass Hatchling", "The Skillful Seamstress"},

-- Balamath, Craglorn
[901] = {"Nomeg Zozumiralpachar", "Fire Mage Linia", "Frost Mage Porcia", "Storm Mage Iribia"},

-- Fearfangs Cavern, Craglorn
[902] = {"Lakorrah the Matron", "Sepilisk"},

-- Exarch's Stronghold, Craglorn
[903] = {"Grothuska", "Iron Orc Fire Shaman", "Ordooth the Corruptor"},

}
-- Monster difficulty data provided by https://en.uesp.net/wiki/Online:Creatures. Thank you!

ZoneSweepExcludedMonsters = {

"argonian behemoth",
"avrusa duleri",
"bone colossus",
"bull netch",
"captain jena apinia",
"celestial bat",
"celestial scorpion",
"craghammer giant",
"daedric titan",
"daedroth",
"draugr corpse",
"draugr stormlord",
"dremora kynreeve",
"drovos nelvayn",
"drublog mammoth",
"dwarven centurion",
"dwarven sphere",
"dwarven sphere master",
"emperor tarish-zi",
"fetcherfly hive golem",
"frost atronach",
"frost troll",
"frostbite spider",
"gargoyle",
"giant scorpion",
"giant",
"grievous twilight",
"haj mota",
"harvester",
"haunted centurion",
"hive golem",
"hunger",
"iron atronach",
"iron head",
"justiciar avanaire",
"mammoth",
"mantikora",
"minotaur shaman",
"minotaur",
"miregaunt",
"lieutenant lepida",
"rosathild",
"nereid empress",
"nereid",
"river troll",
"shadow bloodfiend",
"spider daedra",
"spirit giant",
"storm atronach",
"the swarming tide",
"timber mammoth",
"titan",
"troll",
"tundra mammoth",
"veiled colossus",
"vessel of worms",
"wamasu",
"watcher",
"white fall giant",
"wispmother",
"wraith-of-crows",
"zalar-do",
"zylara",

}