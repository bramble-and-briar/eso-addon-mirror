-- Base-game (non-DLC) 4-player dungeons.
-- Cards are intentionally concise: pull-level mechanics, not full achievement guides.

local addDungeon = PullCardData.addDungeon
local addBoss = PullCardData.addBoss
local addShared = PullCardData.addShared

-- Fungal Grotto I
addDungeon("Fungal Grotto I", "base")
addBoss("Tazkad the Packmaster", "Fungal Grotto I", "Tazkad the Packmaster", {"Tazkad"},
    "Goblin packmaster with Durzog and goblin adds.",
    "Stack adds on the boss, interrupt channels, and stay out of the frontal attacks.",
    "Taunt Tazkad and the Durzogs; face the boss away from the group.",
    "Expect light add pressure while the pack is being stacked.",
    "Cleave the adds down with the boss.",
    "[Tazkad] Stack adds, interrupt, avoid front.")

addBoss("War Chief Ozozai", "Fungal Grotto I", "War Chief Ozozai", {"Ozozai", "Ozazai"},
    "Goblin war chief with two guards and a dangerous jumping/ground-AoE pattern.",
    "Kill or cleave the guards, then move out of the large red circles when Ozozai leaps.",
    "Keep the boss steady and collect the guards.",
    "Top the group after leaps and guard charges.",
    "Burn guards quickly, then boss.",
    "[Ozozai] Guards first; move out of leap AoE.")

addBoss("Broodbirther", "Fungal Grotto I", "Broodbirther", {},
    "Dreugh miniboss supported by adds.",
    "Stay behind the boss and clear spawned adds.",
    "Face away and gather adds.",
    "Watch incidental damage from adds.",
    "Cleave adds and boss together.",
    "[Broodbirther] Face away; cleave adds.")

addBoss("Clatterclaw", "Fungal Grotto I", "Clatterclaw", {},
    "Giant mudcrab that calls in mudcrab swarms.",
    "Do not chase individual crabs; stack and AoE the swarm.",
    "Hold Clatterclaw still so adds can be burned on top of it.",
    "Heal through swarm pressure.",
    "Use AoE; the small crabs are the mechanic.",
    "[Clatterclaw] Stack and AoE crab adds.")

addBoss("Kra'gh the Dreugh King", "Fungal Grotto I", "Kra'gh the Dreugh King", {"Kra'gh", "Kragh"},
    "Final dreugh boss with frontal pressure, lightning ground effects, and mudcrab adds.",
    "Stay behind the boss, avoid lightning/AoE, and clean up mudcrabs if they accumulate.",
    "Face Kra'gh away and block the heavy attack.",
    "Keep the group stable during lightning and add spawns.",
    "Stay behind and burn; AoE adds when needed.",
    "[Kra'gh] Behind boss; avoid lightning; AoE crabs.")

-- Fungal Grotto II
addDungeon("Fungal Grotto II", "base")
addBoss("Mephala's Fang", "Fungal Grotto II", "Mephala's Fang", {"Mephala Fang"},
    "Spider miniboss with healer adds and persistent poison.",
    "Kill the healers first and move poison away from the stack.",
    "Face the spider away and keep it out of poison pools when possible.",
    "Watch poison DoTs and players moving out to drop pools.",
    "Delete healer adds, then boss.",
    "[Mephala's Fang] Healers first; drop poison away.")

addBoss("Gamyne Bandu", "Fungal Grotto II", "Gamyne Bandu", {"Gamyne"},
    "Spider-cult boss with chained-player and shadow-copy mechanics.",
    "If two players are chained, separate quickly; kill the four shadow copies when they appear.",
    "Hold Gamyne centered and block heavies.",
    "Keep chained players alive while they separate.",
    "Swap immediately to the shadow copies.",
    "[Gamyne] Break chain by separating; kill 4 shadows.")

addBoss("Ciirenas the Shepherd", "Fungal Grotto II", "Ciirenas the Shepherd", {"Ciirenas", "Ciirenas the Sheperd"},
    "Cultist boss accompanied by three spiders that empower her when killed.",
    "Do not kill the three spiders; burn Ciirenas while the tank controls them.",
    "Taunt the spiders away from the group and hold Ciirenas in range.",
    "Heal the player targeted by the spiders.",
    "Single-target the boss; avoid cleaving the spiders down.",
    "[Ciirenas] DO NOT kill spiders; burn boss.")

addBoss("Spawn of Mephala", "Fungal Grotto II", "Spawn of Mephala", {"Spawn"},
    "Large spider that sends a player through a portal to deal with adds.",
    "Handle the portal phase immediately; outside players avoid poison and keep the boss controlled.",
    "Keep the boss faced away and stable while a player is below.",
    "Keep the outside group healthy; be ready for reduced group size.",
    "Inside portal: kill the spiders and return; outside: keep burning.",
    "[Spawn] Portal player kills spiders; outside avoid poison.")

addBoss("Reggr Dark-Dawn", "Fungal Grotto II", "Reggr Dark-Dawn", {"Reggr"},
    "Two-handed cultist with nearby adds and a group-wide magicka drain.",
    "Kill/cleave the room adds, block the heavy attack, and expect the magicka drain.",
    "Stack adds on Reggr and hold him still.",
    "Plan sustain around the magicka drain.",
    "Cleave adds; do not waste time chasing.",
    "[Reggr] Stack adds; block heavy; expect magicka drain.")

addBoss("Vila Theran", "Fungal Grotto II", "Vila Theran", {"Vila"},
    "Final caster with growing shadow pools and a high-damage channel.",
    "Stack to place shadow pools cleanly, move together, and use the protection bubble for the channel unless intentionally doing the no-bubble achievement.",
    "Keep Vila positioned so the group has clean floor space.",
    "Heavy group healing during the channel if the bubble is skipped.",
    "Move as a group between safe areas and maintain damage.",
    "[Vila] Stack pools, move together; bubble for beam.")

-- Spindleclutch I
addDungeon("Spindleclutch I", "base")
addBoss("Spindlekin", "Spindleclutch I", "Spindlekin", {},
    "Spider miniboss with spider adds.",
    "Stack and AoE the small spiders.",
    "Keep the boss still and gather spiders.",
    "Watch add pressure.",
    "Cleave everything together.",
    "[Spindlekin] Stack spiders and AoE.")

addBoss("Swarm Mother", "Spindleclutch I", "Swarm Mother", {"Swarm Mother"},
    "Large spider with web/poison pressure and spider adds.",
    "Stay out of ground effects and clean up adds when they build up.",
    "Face away and keep the boss stationary.",
    "Watch players caught in control effects or poison.",
    "Burn from behind and AoE adds.",
    "[Swarm Mother] Behind boss; avoid ground effects; AoE adds.")

addBoss("Cerise the Widow-Maker", "Spindleclutch I", "Cerise the Widow-Maker", {"Cerise"},
    "Corrupted Fighters Guild miniboss with several adds.",
    "Kill/cleave the supporting enemies and avoid frontal attacks.",
    "Stack the adds on Cerise.",
    "Cover the opening add burst.",
    "Cleave the pack.",
    "[Cerise] Stack and cleave adds.")

addBoss("Big Rabbu", "Spindleclutch I", "Big Rabbu", {"Rabbu"},
    "Large melee miniboss with a long charge.",
    "Step out of the charge line and do not stand in front.",
    "Block the charge/heavy and point Rabbu away.",
    "Top anyone clipped by the charge.",
    "Stay behind and keep damage on boss.",
    "[Rabbu] Avoid charge line; stay behind.")

addBoss("The Whisperer", "Spindleclutch I", "The Whisperer", {"Whisperer"},
    "Final spider-daedra with dangerous frontal/ground attacks and player-targeted control.",
    "Spread enough that personal mechanics do not overlap; block/dodge telegraphed attacks.",
    "Hold the boss centered and faced away.",
    "Watch for sudden damage on targeted players.",
    "Stay behind and keep personal AoEs separated.",
    "[Whisperer] Spread slightly; avoid telegraphs; stay behind.")

-- Spindleclutch II
addDungeon("Spindleclutch II", "base")
addBoss("Mad Mortine", "Spindleclutch II", "Mad Mortine", {"Mad Martine"},
    "Bloodfiend miniboss surrounded by adds.",
    "Stack and burn the bloodfiends with the boss.",
    "Collect adds and hold the boss still.",
    "Heal through the opening pack damage.",
    "AoE the room down.",
    "[Mortine] Stack and AoE bloodfiends.")

addBoss("Bloodspawn", "Spindleclutch II", "Bloodspawn", {"Blood Spawn", "Bloodspawn"},
    "Gargoyle boss with a room-filling falling-rock soft enrage.",
    "Stay grouped behind the boss, avoid falling rocks, and kill before the room becomes unsafe.",
    "Hold Bloodspawn still and block the heavy attack.",
    "Sustain healing during the rock phase.",
    "This is a burn check; keep uptime high.",
    "[Bloodspawn] Hold still; avoid rocks; burn before room fills.")

addBoss("Praxin Douare", "Spindleclutch II", "Praxin Douare", {"Praxin"},
    "Multi-wave encounter that reprises enemies from Spindleclutch I before Praxin becomes attackable.",
    "Clear each add wave cleanly; prioritize dangerous/healer adds and then burn Praxin.",
    "Group each wave tightly for AoE.",
    "Expect sustained group damage through multiple waves.",
    "AoE waves, then single-target Praxin.",
    "[Praxin] Clear waves first; boss becomes active after them.")

addShared({"Flesh Atronach", "Flesh Atronach Trio"}, "Spindleclutch II", "Flesh Atronach Trio", {"Atronach Trio"},
    "Three flesh atronachs fought together.",
    "Keep them stacked and avoid overlapping frontal attacks.",
    "Taunt all three and face them the same direction.",
    "Watch tank spikes while all three are active.",
    "Cleave evenly while stacked.",
    "[Atronachs] Stack all 3; face away; cleave.")

addBoss("Urvan Veleth", "Spindleclutch II", "Urvan Veleth", {"Urvan"},
    "Vampire miniboss with Boneman archers.",
    "Kill or stack the archers and interrupt dangerous casts.",
    "Pull ranged adds into the boss where possible.",
    "Watch ranged chip damage.",
    "Cleave adds with Urvan.",
    "[Urvan] Stack archers; interrupt; cleave.")

addBoss("Vorenor Winterbourne", "Spindleclutch II", "Vorenor Winterbourne", {"Vorenor"},
    "Final vampire boss with captive victims used for healing.",
    "Keep pressure on Vorenor and avoid killing captives if pursuing Compassionate Hero.",
    "Hold Vorenor away from captives and face him from the group.",
    "Keep the tank stable through the boss's self-heal windows.",
    "Burn Vorenor; do not splash captives if doing the achievement.",
    "[Vorenor] Burn boss; spare captives for achievement.")

-- The Banished Cells I
addDungeon("The Banished Cells I", "base")
addBoss("Cell Haunter", "The Banished Cells I", "Cell Haunter", {},
    "Undead miniboss with supporting enemies.",
    "Stack adds and avoid obvious ground attacks.",
    "Collect adds and face boss away.",
    "Heal through add pressure.",
    "Cleave the pack.",
    "[Cell Haunter] Stack and cleave adds.")

addBoss("Shadowrend", "The Banished Cells I", "Shadowrend", {},
    "Clannfear boss that creates a shadow duplicate.",
    "When the duplicate appears, control and burn it before pressure builds.",
    "Keep boss and copy controlled and pointed away.",
    "Watch spike damage while both are active.",
    "Swap to the duplicate, then return to boss.",
    "[Shadowrend] Kill shadow copy; avoid front.")

addBoss("Angata the Clannfear Handler", "The Banished Cells I", "Angata the Clannfear Handler", {"Angata"},
    "Handler miniboss with clannfear/skeleton adds.",
    "Stack and AoE the adds; block clannfear charges.",
    "Collect adds on Angata.",
    "Cover add pressure.",
    "Cleave all targets.",
    "[Angata] Stack adds; block charges.")

addBoss("Skeletal Destroyer", "The Banished Cells I", "Skeletal Destroyer", {},
    "Large skeleton with summoned adds.",
    "Stay behind, avoid frontal attacks, and clear summons as needed.",
    "Face away and gather summons.",
    "Watch tank and add pressure.",
    "Cleave summons with boss.",
    "[Destroyer] Face away; cleave summons.")

addBoss("High Kinlord Rilis", "The Banished Cells I", "High Kinlord Rilis", {"Rilis"},
    "Final caster with teleporting, soul-blast pressure, and large AoEs.",
    "Block the soul blast and move out of persistent ground effects.",
    "Reposition quickly after teleports and keep him faced safely.",
    "Prepare for burst damage after teleports/casts.",
    "Maintain uptime while moving out of AoE.",
    "[Rilis I] Block soul blast; move out of AoE.")

-- The Banished Cells II
addDungeon("The Banished Cells II", "base")
addBoss("Keeper Areldur", "The Banished Cells II", "Keeper Areldur", {"Areldur"},
    "Corrupted keeper with flame atronachs and add-wave disappear phases.",
    "Kill flame atronachs away from the group and clear each add wave quickly.",
    "Collect the wave adds and keep them grouped.",
    "Watch flame damage and atronach death bursts.",
    "AoE waves aggressively.",
    "[Areldur] Clear add waves; avoid atronach death explosions.")

addBoss("Maw of the Infernal", "The Banished Cells II", "Maw of the Infernal", {"Maw"},
    "Large daedroth with heavy frontal fire pressure.",
    "Never stand in front unless tanking; avoid fire breath and ground fire.",
    "Face the Maw away and block its heavy attacks/breath.",
    "Keep the tank topped through sustained fire damage.",
    "Stay behind and burn.",
    "[Maw] Stay behind; tank blocks fire/frontals.")

addBoss("Keeper Voranil", "The Banished Cells II", "Keeper Voranil", {"Voranil"},
    "Corrupted keeper with Daedric adds.",
    "Stack and burn the adds with the boss.",
    "Collect adds and face away.",
    "Watch opening add pressure.",
    "Cleave efficiently.",
    "[Voranil] Stack adds; cleave.")

addBoss("Keeper Imiril", "The Banished Cells II", "Keeper Imiril", {"Imiril"},
    "Keeper with portal/add phases that temporarily remove him from the fight.",
    "Kill the portal adds quickly so Imiril returns; do not let waves pile up.",
    "Group adds tightly each phase.",
    "Sustain the group during repeated waves.",
    "Save AoE/ultimates for add phases.",
    "[Imiril] Kill portal waves fast; boss returns after adds.")

addShared({"Sister Vera", "Sister Sihna"}, "The Banished Cells II", "Sister Vera & Sister Sihna", {"Vera", "Sihna", "Sisters"},
    "Paired boss encounter with complementary ranged/melee pressure.",
    "Keep the pair controlled and avoid overlapping their attacks.",
    "Taunt both and stack them when safe.",
    "Watch group damage while both are active.",
    "Cleave both together.",
    "[Sisters] Stack both; avoid overlapping attacks; cleave.")

addBoss("High Kinlord Rilis", "The Banished Cells II", "High Kinlord Rilis", {"Rilis"},
    "Final fight adds Daedroths and color-coded bubble/curse mechanics to Rilis's normal spell pressure.",
    "Kill/handle Daedroths, move to the matching rune/cleansing area when cursed, and avoid large AoEs.",
    "Hold Rilis safely while collecting Daedroths.",
    "Prioritize cursed players and heavy group damage.",
    "Swap to Daedroths when required, otherwise burn Rilis.",
    "[Rilis II] Handle curse/runes; control Daedroths; avoid AoE.")

-- Darkshade Caverns I
addDungeon("Darkshade Caverns I", "base")
addBoss("Head Shepherd Neloren", "Darkshade Caverns I", "Head Shepherd Neloren", {"Neloren"},
    "Caster miniboss with healers and interruptible spells.",
    "Kill the healers and interrupt Neloren's heal/channel.",
    "Stack adds on the boss.",
    "Cover fire damage while interrupts are missed.",
    "Healers first; interrupt boss.",
    "[Neloren] Kill healers; interrupt casts.")

addBoss("Foreman Llothan", "Darkshade Caverns I", "Foreman Llothan", {"Llothan"},
    "Foreman boss that summons Kwama and places poison/ground pressure.",
    "Avoid ground effects and burn spawned Kwama.",
    "Keep adds stacked on the boss.",
    "Watch poison and add damage.",
    "Cleave Kwama with boss.",
    "[Llothan] Avoid ground AoE; cleave Kwama.")

addBoss("The Hive Lord", "Darkshade Caverns I", "The Hive Lord", {"Hive Lord"},
    "Large Kwama boss with frontal attacks and spawned Kwama.",
    "Stay behind and clear spawned Kwama.",
    "Face away and gather adds.",
    "Heal through add pressure.",
    "Cleave adds behind boss.",
    "[Hive Lord] Stay behind; cleave Kwama adds.")

addBoss("Cavern Patriarch", "Darkshade Caverns I", "Cavern Patriarch", {},
    "Netch miniboss with electrical/ground pressure.",
    "Spread enough to see ground effects and move out promptly.",
    "Hold centered when possible.",
    "Watch unavoidable shock damage.",
    "Maintain damage while moving out of AoE.",
    "[Patriarch] Avoid ground AoE; keep uptime.")

addBoss("Cutting Sphere", "Darkshade Caverns I", "Cutting Sphere", {},
    "Dwemer sphere encounter with construct adds.",
    "Stack the constructs and avoid frontal/cone attacks.",
    "Collect the constructs and face them away.",
    "Watch tank spikes from multiple constructs.",
    "AoE the pack.",
    "[Cutting Sphere] Stack constructs; avoid frontals.")

addBoss("Sentinel of Rkugamz", "Darkshade Caverns I", "Sentinel of Rkugamz", {"Sentinel"},
    "Final Dwemer boss that summons healing spiders.",
    "Kill the healing spiders immediately or drag the boss out of their healing area.",
    "Keep the Sentinel away from healing spiders and face it from the group.",
    "Watch sustained pressure while spiders are alive.",
    "Priority target: healing spiders, then boss.",
    "[Sentinel] Kill healing spiders / move boss off heals.")

-- Darkshade Caverns II
addDungeon("Darkshade Caverns II", "base")
addBoss("The Fallen Foreman", "Darkshade Caverns II", "The Fallen Foreman", {"Fallen Foreman"},
    "Foreman miniboss with dangerous telegraphed attacks amid add pressure.",
    "Interrupt/avoid the obvious high-damage cast and keep adds stacked.",
    "Hold boss and adds together.",
    "Watch for sudden group spikes.",
    "Cleave adds; react to telegraphs.",
    "[Foreman] Stack adds; react to big telegraph.")

addBoss("Transmuted Hive Lord", "Darkshade Caverns II", "Transmuted Hive Lord", {"Hive Lord"},
    "Kwama boss supported by draining and sedating scribs.",
    "Kill priority scribs quickly and stay out of frontal attacks.",
    "Face boss away and group scribs when possible.",
    "Watch resource/health pressure from scribs.",
    "Swap to priority scribs.",
    "[Hive Lord II] Kill priority scribs; stay behind.")

addShared({"Transmuted Alit", "Transmuted Alit 1", "Transmuted Alit 2", "Transmuted Alit 3"}, "Darkshade Caverns II", "Transmuted Alit Trio", {"Alit Trio"},
    "Three linked Alit bosses fought together.",
    "Keep all three controlled and burn them evenly so one does not remain active alone for long.",
    "Taunt and stack the trio.",
    "Tank damage is highest while all three are active.",
    "Use cleave and keep health totals reasonably even.",
    "[Alit Trio] Stack 3; cleave evenly.")

addBoss("Grobull the Transmuted", "Darkshade Caverns II", "Grobull the Transmuted", {"Grobull"},
    "Bull netch encounter where the boss is shielded while netch adds are active.",
    "Kill the netch adds; use their deaths to open damage windows on Grobull. Avoid the large electrical field.",
    "Control adds and keep the group positioned for clean AoE.",
    "Heavy AoE healing while the arena is electrified.",
    "Adds are priority; burst Grobull when vulnerable.",
    "[Grobull] Kill netches to drop shield; burst boss in window.")

addShared({"Engine Garrison", "Engine Garrison's Centurion", "Engine Garrison's Sphere", "Engine Garrison's Spider"}, "Darkshade Caverns II", "Engine Garrison", {"Mech Army"},
    "Large Dwemer construct army encounter.",
    "Stay together, interrupt dangerous construct channels, and burn priority machines before they snowball.",
    "Collect melee constructs and control the centurion.",
    "Expect sustained group-wide mechanical damage.",
    "AoE aggressively and interrupt.",
    "[Garrison] Stay stacked; interrupt; AoE constructs.")

addBoss("The Engine Guardian", "Darkshade Caverns II", "The Engine Guardian", {"Engine Guardian"},
    "Final Dwemer boss cycles colored phases with different attacks and defenses.",
    "React to the current phase, stay mobile for poison/fire, and avoid chasing blindly around the room.",
    "Keep taunt and reposition only as needed; block heavy mechanical attacks.",
    "Be ready for sustained group damage during poison/fire phases.",
    "Maintain ranged uptime while the boss moves.",
    "[Engine Guardian] React to color phase; stay mobile; keep uptime.")

-- Elden Hollow I
addDungeon("Elden Hollow I", "base")
addBoss("Akash gra-Mal", "Elden Hollow I", "Akash gra-Mal", {"Akash"},
    "Wood Orc boss with melee pressure and adds.",
    "Stack adds and avoid frontal/whirlwind attacks.",
    "Face away and collect adds.",
    "Cover opening add damage.",
    "Cleave adds and boss.",
    "[Akash] Stack adds; avoid front/whirlwind.")

addBoss("Ancient Spriggan", "Elden Hollow I", "Ancient Spriggan", {},
    "Optional spriggan miniboss that can heal itself and nearby allies.",
    "Interrupt the heals and AoE the spriggan pack.",
    "Stack the spriggans.",
    "Minimal pressure if heals are interrupted.",
    "Interrupt and burn.",
    "[Spriggan] Interrupt heals; AoE pack.")

addBoss("Chokethorn", "Elden Hollow I", "Chokethorn", {},
    "Strangler boss that summons saplings which heal it.",
    "Kill healing saplings immediately and avoid frontal/ground attacks.",
    "Hold Chokethorn still and away from saplings if possible.",
    "Watch group damage while DPS swaps targets.",
    "Priority: healing saplings.",
    "[Chokethorn] Kill healing saplings ASAP.")

addBoss("Nenesh gro-Mal", "Elden Hollow I", "Nenesh gro-Mal", {"Nenesh"},
    "Wood Orc miniboss with adds.",
    "Stack and cleave the pack; avoid heavy melee telegraphs.",
    "Collect adds and face away.",
    "Cover add damage.",
    "AoE the group.",
    "[Nenesh] Stack adds; cleave.")

addBoss("Leafseether", "Elden Hollow I", "Leafseether", {},
    "Alit miniboss with charge/frontal pressure.",
    "Stay out of the front and dodge charge lines.",
    "Face away and block heavy attacks.",
    "Top anyone clipped by charges.",
    "Stay behind and burn.",
    "[Leafseether] Avoid front and charge.")

addBoss("Canonreeve Oraneth", "Elden Hollow I", "Canonreeve Oraneth", {"Oraneth"},
    "Final caster with summoned skeletons and dangerous magical ground effects.",
    "Clear or cleave skeletons, interrupt when possible, and move out of ground AoE.",
    "Keep adds grouped on Oraneth.",
    "Watch group damage during add phases.",
    "Cleave adds and maintain interrupts.",
    "[Oraneth] Stack skeletons; interrupt; avoid AoE.")

-- Elden Hollow II
addDungeon("Elden Hollow II", "base")
addBoss("Dubroze the Infestor", "Elden Hollow II", "Dubroze the Infestor", {"Dubroze"},
    "Daedroth miniboss with ranged Daedric support.",
    "Stay behind the Daedroth and stack/kill the ranged adds.",
    "Face Dubroze away and pull adds in.",
    "Watch fire damage.",
    "Cleave adds with boss.",
    "[Dubroze] Behind boss; stack adds.")

addBoss("Dark Root", "Elden Hollow II", "Dark Root", {},
    "Corrupted nature boss with dangerous ground effects.",
    "Stay out of corrupted ground and react to spawned threats.",
    "Hold the boss in clean space.",
    "Watch sustained environmental damage.",
    "Maintain uptime while moving.",
    "[Dark Root] Avoid corrupted ground; keep boss in clean space.")

addBoss("Azara the Frightener", "Elden Hollow II", "Azara the Frightener", {"Azara"},
    "Twilight miniboss with fear/control pressure.",
    "Break free promptly and avoid frontal attacks.",
    "Face away and keep control of the boss.",
    "Be ready for damage on feared players.",
    "Stay behind and burn.",
    "[Azara] Break free; avoid front.")

addBoss("Murklight", "Elden Hollow II", "Murklight", {},
    "Daedric boss with a darkness phase that punishes poor positioning.",
    "Stay with the group and move to the safe/light area when the arena darkens.",
    "Keep the boss near the group's safe route.",
    "Heavy healing if players miss the safe area.",
    "Do not tunnel through the darkness mechanic.",
    "[Murklight] Move to safe/light area during darkness.")

addBoss("The Shadow Guard", "Elden Hollow II", "The Shadow Guard", {"Shadow Guard"},
    "Caster miniboss supported by ranged adds.",
    "Kill or stack the ranged adds and interrupt dangerous casts.",
    "Pull ranged enemies together where possible.",
    "Watch spread ranged damage.",
    "Cleave and interrupt.",
    "[Shadow Guard] Stack ranged adds; interrupt.")

addBoss("Bogdan the Nightflame", "Elden Hollow II", "Bogdan the Nightflame", {"Bogdan", "Nightflame"},
    "Final Daedric Titan with heavy fire AoE and add pressure.",
    "Stay out of fire, avoid the frontal breath, and kill/cleave adds quickly.",
    "Face Bogdan away and keep him positioned in clear space.",
    "Expect heavy group damage during fire phases.",
    "Stay behind and cleave adds.",
    "[Bogdan] Avoid fire/front; cleave adds.")

-- Wayrest Sewers I
addDungeon("Wayrest Sewers I", "base")
addBoss("Slimecraw", "Wayrest Sewers I", "Slimecraw", {},
    "Crocodile boss with a heavy tail swipe and frontal pressure.",
    "Stay behind/at the side and block if targeted by the heavy swipe.",
    "Face Slimecraw away and block heavies.",
    "Minimal healing if positioning is clean.",
    "Stay behind and burn.",
    "[Slimecraw] Stay behind; block heavy tail swipe.")

addBoss("Investigator Garron", "Wayrest Sewers I", "Investigator Garron", {"Garron"},
    "Necromancer with moving mist, Restless Souls, and interruptible ranged attacks.",
    "Avoid the mist, kill/cleave Restless Souls, and interrupt channels.",
    "Keep Garron positioned so the group has room to move.",
    "Watch ranged spikes and soul adds.",
    "Cleave adds and interrupt.",
    "[Garron] Avoid mist; kill souls; interrupt.")

addBoss("The Rat Whisperer", "Wayrest Sewers I", "The Rat Whisperer", {"Rat Whisperer"},
    "Skeever-summoning boss with interruptible channels.",
    "AoE the skeever swarms and interrupt the boss.",
    "Hold boss still and collect adds.",
    "Heal through swarm pressure.",
    "AoE rats; interrupt boss.",
    "[Rat Whisperer] AoE rats; interrupt channels.")

addBoss("Uulgarg the Hungry", "Wayrest Sewers I", "Uulgarg the Hungry", {"Uulgarg", "Ulugarg"},
    "Large melee boss with fear and whirlwind pressure.",
    "Break free from fear, step out of whirlwind, and block heavies.",
    "Face away and block heavy attacks.",
    "Watch feared players and melee spikes.",
    "Stay behind; move out for whirlwind.",
    "[Uulgarg] Break fear; avoid whirlwind; block heavy.")

addBoss("Varaine Pellingare", "Wayrest Sewers I", "Varaine Pellingare", {"Varaine"},
    "Mobile fighter with heavy attacks and expanding ground shockwaves.",
    "Block heavies and move out of expanding ground effects.",
    "Keep Varaine positioned predictably.",
    "Watch players clipped by shockwaves.",
    "Maintain uptime while dodging AoE.",
    "[Varaine] Block heavy; avoid expanding AoE.")

addBoss("Allene Pellingare", "Wayrest Sewers I", "Allene Pellingare", {"Allene"},
    "Final vampire with ambushes, spin attacks, and bats.",
    "Avoid the spin, block heavy attacks, and handle bat pressure.",
    "Keep Allene controlled and faced safely.",
    "Watch burst damage during ambush/bat phases.",
    "Stay behind and burn through final phase.",
    "[Allene] Avoid spin; block heavy; handle bats.")

-- Wayrest Sewers II
addDungeon("Wayrest Sewers II", "base")
addBoss("Malubeth the Scourger", "Wayrest Sewers II", "Malubeth the Scourger", {"Malubeth"},
    "Harvester that lifts a player and requires teammates to use the two altars to release them.",
    "When a player is lifted, two teammates activate the altars immediately; avoid growing ground AoEs.",
    "Keep Malubeth centered and block heavy projectiles.",
    "Keep the lifted player alive until released.",
    "Drop damage, then help with altars instantly.",
    "[Malubeth] Lift = two players hit altars; avoid red circles.")

addBoss("Uulgarg the Risen", "Wayrest Sewers II", "Uulgarg the Risen", {"Uulgarg", "Ulugarg the Risen"},
    "Undead Uulgarg with fear that leaves dangerous fire trails.",
    "Break free from fear immediately so you do not drag fire through the group.",
    "Face away and interrupt/control when possible.",
    "Watch feared players standing in fire.",
    "Stay spread enough not to overlap fire trails.",
    "[Uulgarg II] Break fear instantly; don't trail fire through group.")

addBoss("Skull Reaper", "Wayrest Sewers II", "Skull Reaper", {},
    "Optional bone colossus with healer skeletons and a lethal frontal cone.",
    "Kill the healer skeletons first and never stand in front of the boss.",
    "Face Skull Reaper away and block the frontal.",
    "Keep tank stable until healer adds are dead.",
    "Healers first, then boss.",
    "[Skull Reaper] Kill healer skeletons; avoid front.")

addBoss("Garron the Returned", "Wayrest Sewers II", "Garron the Returned", {"Garron"},
    "Lich encounter with ground AoEs, ghost adds, and a heavy center-room beam phase.",
    "Kill/control ghosts, stay out of circles, and stack for healing during the beam.",
    "Keep ghosts controlled and boss positioned cleanly.",
    "Save strong group healing for the beam phase.",
    "Swap to ghosts, then burn during clean windows.",
    "[Garron II] Kill ghosts; avoid circles; heal through beam.")

addBoss("The Forgotten One", "Wayrest Sewers II", "The Forgotten One", {"Forgotten One", "The Lost One", "Lost One"},
    "Ghost boss with adds and a strong directional fear/wave.",
    "Stay out of the frontal fear and clear adds.",
    "Face the boss away and stack adds nearby.",
    "Watch players hit by the fear/wave.",
    "Cleave adds and boss.",
    "[Forgotten One] Avoid frontal fear; stack adds.")

addShared({"Varaine Pellingare", "Allene Pellingare"}, "Wayrest Sewers II", "Varaine & Allene Pellingare", {"Pellingare Twins", "Varaine", "Allene"},
    "Final twin encounter combining both Pellingares with zombies, bats, shields, and heavy AoE pressure.",
    "Keep the twins controlled, avoid overlapping AoEs, and manage adds. For hard-mode achievement, kill 15 zombies before finishing the twins.",
    "Taunt both and keep them stacked when safe.",
    "Expect high group damage while both are active.",
    "Cleave twins/adds; delay kill if doing 15-zombie achievement.",
    "[Twins] Stack safely; manage adds; 15 zombies for achievement.")

-- Crypt of Hearts I
addDungeon("Crypt of Hearts I", "base")
addBoss("Mage Master", "Crypt of Hearts I", "Mage Master", {},
    "Caster miniboss with undead support.",
    "Interrupt dangerous casts and stack the undead adds.",
    "Gather adds on the boss.",
    "Watch ranged magic damage.",
    "Cleave and interrupt.",
    "[Mage Master] Stack adds; interrupt casts.")

addBoss("Archmaster Siniel", "Crypt of Hearts I", "Archmaster Siniel", {"Siniel"},
    "Necromancer boss with skeleton adds and magical AoE.",
    "Clear/cleave skeletons and avoid ground effects.",
    "Stack adds and face boss safely.",
    "Watch group damage from adds.",
    "Cleave skeletons.",
    "[Siniel] Stack skeletons; avoid AoE.")

addBoss("Death's Leviathan", "Crypt of Hearts I", "Death's Leviathan", {"Deaths Leviathan", "Leviathan"},
    "Large bone colossus with heavy frontal attacks and ground shockwaves.",
    "Stay behind and move out of large telegraphs.",
    "Face away and block heavies.",
    "Top players clipped by shockwaves.",
    "Stay behind and burn.",
    "[Leviathan] Stay behind; block/avoid heavy telegraphs.")

addBoss("Uulkar Bonehand", "Crypt of Hearts I", "Uulkar Bonehand", {"Uulkar"},
    "Undead miniboss with melee pressure and adds.",
    "Stack and cleave adds; avoid frontal attacks.",
    "Face away and gather adds.",
    "Cover add pressure.",
    "AoE the pack.",
    "[Uulkar] Stack adds; stay behind.")

addBoss("Dogas the Berserker", "Crypt of Hearts I", "Dogas the Berserker", {"Dogas"},
    "Berserker miniboss with dangerous melee AoE.",
    "Step out of whirlwind/large melee telegraphs.",
    "Hold steady and face away.",
    "Watch melee players during AoE.",
    "Back out for AoE, then return.",
    "[Dogas] Avoid melee AoE/whirlwind.")

addShared({"Ilambris-Zaven", "Ilambris-Athor"}, "Crypt of Hearts I", "Ilambris Twins", {"Ilambris", "Zaven", "Athor"},
    "Final twin encounter combining fire and lightning mechanics.",
    "Keep the twins controlled, avoid fire/lightning ground effects, and do not stack dangerous personal AoEs.",
    "Taunt both and keep them positioned for cleave when safe.",
    "Expect sustained elemental group damage.",
    "Cleave both while respecting ground effects.",
    "[Ilambris] Control both; avoid fire/lightning; cleave.")

-- Crypt of Hearts II
addDungeon("Crypt of Hearts II", "base")
addBoss("Ibelgast", "Crypt of Hearts II", "Ibelgast", {},
    "Opening undead boss with add pressure.",
    "Stack adds and avoid frontal/ground telegraphs.",
    "Collect adds and face away.",
    "Watch opening burst.",
    "Cleave the pack.",
    "[Ibelgast] Stack adds; avoid telegraphs.")

addBoss("Ruzozuzalpamaz", "Crypt of Hearts II", "Ruzozuzalpamaz", {"Ruzozuz", "Spider"},
    "Spider boss that cocoons players and sends a large lightning field after a target.",
    "Free cocooned players immediately and kite the moving lightning away from the group.",
    "Keep the spider stable and faced away.",
    "Prioritize healing the lightning target/cocooned player.",
    "Free cocoons; keep damage up while kiting lightning.",
    "[Ruzozuz] Free cocoon; kite lightning away.")

addBoss("Chamber Guardian", "Crypt of Hearts II", "Chamber Guardian", {},
    "Guardian with strong frontal/fear pressure.",
    "Stay out of the front and break free quickly if feared.",
    "Face away and keep the boss off walls where possible.",
    "Watch feared players.",
    "Stay behind and burn.",
    "[Guardian] Avoid front; break fear quickly.")

addShared({"Ilambris-Zaven", "Ilambris-Athor", "Brothers Ilambris"}, "Crypt of Hearts II", "Brothers Ilambris", {"Ilambris Twins", "Ilambris", "Zaven", "Athor"},
    "Return of the Ilambris brothers with fire and lightning mechanics.",
    "Avoid elemental ground effects and keep the pair under control.",
    "Taunt both and position for safe cleave.",
    "Expect elemental group damage.",
    "Cleave both while moving out of AoE.",
    "[Ilambris II] Control both; avoid fire/lightning.")

addBoss("Ilambris Amalgam", "Crypt of Hearts II", "Ilambris Amalgam", {"Amalgam"},
    "Combined Ilambris form with mixed fire/lightning pressure.",
    "Stay mobile and avoid overlapping elemental AoEs.",
    "Hold in a predictable position and face safely.",
    "Sustain healing through mixed elemental damage.",
    "Maintain uptime while moving.",
    "[Amalgam] Avoid mixed elemental AoE; keep moving.")

addBoss("Mezeluth", "Crypt of Hearts II", "Mezeluth", {},
    "Lich boss that lifts the group and marks players with separate explosion circles.",
    "After the lift, spread immediately so player circles do not overlap; interrupt dangerous casts when possible.",
    "Keep Mezeluth centered to give the group room to spread.",
    "Top everyone before/after the lift.",
    "Spread after lift; keep circles separated.",
    "[Mezeluth] Lift -> spread; never overlap player circles.")

addBoss("Nerien'eth", "Crypt of Hearts II", "Nerien'eth", {"Nerieneth"},
    "Final lich with students/adds, teleporting magical attacks, and the Ebony Blade phase.",
    "Avoid ground AoEs, control adds, and react quickly to target swaps/teleports.",
    "Keep adds controlled and boss positioned when possible.",
    "Watch burst damage during blade/add phases.",
    "Kill required adds, then burn boss; save burst for clean windows.",
    "[Nerien'eth] Avoid AoE; control adds; burn in clean windows.")

-- City of Ash I
addDungeon("City of Ash I", "base")
addBoss("Infernal Guardian", "City of Ash I", "Infernal Guardian", {},
    "Flame atronach boss with persistent fire attacks.",
    "Stay out of fire and interrupt channels when possible.",
    "Keep boss steady and face away.",
    "Watch sustained flame damage.",
    "Maintain uptime while moving out of fire.",
    "[Infernal Guardian] Avoid fire; interrupt channels.")

addBoss("Golor the Banekin Handler", "City of Ash I", "Golor the Banekin Handler", {"Golor"},
    "Handler miniboss with Banekin/Scamp adds.",
    "Stack adds and interrupt summons/casts.",
    "Collect adds on Golor.",
    "Cover add pressure.",
    "AoE and interrupt.",
    "[Golor] Stack adds; interrupt summons.")

addBoss("Warden of the Shrine", "City of Ash I", "Warden of the Shrine", {"Warden"},
    "Daedric boss with heavy fire frontals.",
    "Stay behind and dodge/block heavy flame attacks.",
    "Face away and block heavies.",
    "Watch tank fire damage.",
    "Stay behind and burn.",
    "[Warden] Stay behind; avoid heavy fire attacks.")

addBoss("Dark Ember", "City of Ash I", "Dark Ember", {},
    "Flame miniboss with moving fire pressure.",
    "Keep moving out of fire walls/ground effects.",
    "Hold in clear space.",
    "Heal through incidental fire damage.",
    "Maintain damage while repositioning.",
    "[Dark Ember] Move out of fire; keep clear space.")

addBoss("Rothariel Flameheart", "City of Ash I", "Rothariel Flameheart", {"Rothariel"},
    "Flame caster that creates multiple copies.",
    "Identify and kill the copies quickly while avoiding fire attacks.",
    "Keep the real boss controlled when visible.",
    "Watch distributed damage during copy phase.",
    "Swap to copies immediately.",
    "[Rothariel] Kill copies; avoid fire.")

addBoss("Razor Master Erthas", "City of Ash I", "Razor Master Erthas", {"Erthas"},
    "Final fire boss that summons Flame Atronachs and blankets the arena with fire.",
    "Avoid firestorms, kill/cleave atronachs, and interrupt dangerous channels.",
    "Keep Erthas positioned with room to move and collect adds.",
    "Heavy group healing during fire phases.",
    "Cleave atronachs and keep interrupts up.",
    "[Erthas] Avoid fire; cleave atronachs; interrupt.")

-- City of Ash II
addDungeon("City of Ash II", "base")
addShared({"Xivilai Rukhan", "Rukhan", "Akezel", "Marruz"}, "City of Ash II", "Rukhan, Akezel & Marruz", {"First Trio"},
    "Three-Xivilai opening encounter: melee pressure, heals, teleports, and fire traps.",
    "Interrupt Akezel's heals, avoid Marruz's fire traps, and move out of Rukhan's large AoE.",
    "Control Rukhan and keep the trio grouped when possible.",
    "Watch burst while all three are active.",
    "Interrupt heals and cleave the trio.",
    "[Rukhan Trio] Interrupt heals; avoid fire/AoE; cleave.")

addBoss("Urata the Legion", "City of Ash II", "Urata the Legion", {"Urata"},
    "Caster miniboss that summons two adds and can heal by recalling them.",
    "Kill summoned adds quickly and move out of flame circles.",
    "Stack adds on Urata.",
    "Watch spread fire-circle damage.",
    "Adds are priority.",
    "[Urata] Kill adds before recall/heal; avoid flame circles.")

addBoss("Horvantud the Fire Maw", "City of Ash II", "Horvantud the Fire Maw", {"Horvantud", "Fire Maw"},
    "Daedroth boss with heavy frontal fire and waves of Dremora.",
    "Stay behind, avoid ground quakes, and control add waves.",
    "Face Horvantud away and stack adds.",
    "Watch sustained flame/add damage.",
    "Cleave Dremora with boss.",
    "[Horvantud] Stay behind; avoid quakes; cleave adds.")

addBoss("Ash Titan", "City of Ash II", "Ash Titan", {},
    "Daedric Titan with heavy fire attacks and Air Atronach adds.",
    "Avoid frontal breath/ground fire and kill dangerous adds when they spawn.",
    "Face away and keep the Titan stable.",
    "Expect high flame damage.",
    "Stay behind; swap to adds when needed.",
    "[Ash Titan] Avoid front/fire; kill adds.")

addShared({"Xivilai Boltaic", "Xivilai Fulminator", "Fulminator"}, "City of Ash II", "Xivilai Boltaic & Fulminator", {"Two Guardians", "Bridge Guardians"},
    "Paired Xivilai encounter with storm atronach support.",
    "Control both bosses and clean up storm atronachs before the arena becomes crowded.",
    "Taunt both and stack when safe.",
    "Watch shock damage and add pressure.",
    "Cleave bosses and atronachs.",
    "[Guardians] Stack both; control storm atronachs; cleave.")

addBoss("Valkyn Skoria", "City of Ash II", "Valkyn Skoria", {"Skoria"},
    "Final boss on shrinking platforms with fire, atronachs, and lethal environmental pressure.",
    "Avoid fire, kill atronachs, and move promptly when a platform becomes unsafe/destroyed.",
    "Hold Skoria near a safe platform edge and block heavy attacks.",
    "Keep everyone stable during platform transitions.",
    "Maintain burn while respecting platform mechanics.",
    "[Skoria] Avoid fire; move platforms; kill atronachs.")

-- Arx Corinium
addDungeon("Arx Corinium", "base")
addBoss("Fanged Menace", "Arx Corinium", "Fanged Menace", {},
    "Giant snake whose poison cloud damages players and heals the boss.",
    "Get out of the poison cloud immediately; never let the boss sit in it longer than necessary.",
    "Drag the snake out of poison and face it away.",
    "Watch poison DoTs.",
    "Stay behind and keep boss out of poison.",
    "[Fanged Menace] Poison heals boss; move it out.")

addBoss("Ganakton the Tempest", "Arx Corinium", "Ganakton the Tempest", {"Ganakton"},
    "Wamasu with lightning spit, breath, and control effects.",
    "Avoid the lightning breath/projectiles and break free if pinned.",
    "Face Ganakton away and block heavies.",
    "Heal through unavoidable shock ticks.",
    "Stay behind and dodge lightning.",
    "[Ganakton] Avoid lightning breath/spit; break free.")

addBoss("Sliklenia the Songstress", "Arx Corinium", "Sliklenia the Songstress", {"Sliklenia"},
    "Lamia whose pet snake creates the protective bubble for her Cacophony scream.",
    "Do NOT kill the pet snake; stand in its bubble during Cacophony unless your group intentionally heals through it.",
    "Keep boss controlled without killing the snake.",
    "Prepare for heavy group damage if anyone misses the bubble.",
    "Do not cleave the pet snake down.",
    "[Sliklenia] DO NOT kill snake; use its bubble for scream.")

addBoss("Matron Ixniaa", "Arx Corinium", "Matron Ixniaa", {"Ixniaa"},
    "Lamia miniboss with summoned spectral lamias and a large targeted ground attack.",
    "Move out of the inner circle and cleave spectral adds.",
    "Keep adds grouped on boss.",
    "Watch players caught by the ground attack.",
    "Cleave adds and boss.",
    "[Ixniaa] Move out of inner circle; cleave adds.")

addBoss("Ancient Lurcher", "Arx Corinium", "Ancient Lurcher", {},
    "Lurcher miniboss with a dangerous interruptible eruption and stronger damage below 50%.",
    "Interrupt the eruption quickly and avoid ground AoEs.",
    "Face away and be ready to interrupt.",
    "Watch increased damage under 50%.",
    "Prioritize interrupts, then burn.",
    "[Lurcher] Interrupt eruption; burn hard under 50%.")

addBoss("Sellistrix the Lamia Queen", "Arx Corinium", "Sellistrix the Lamia Queen", {"Sellistrix"},
    "Final lamia: standing on land shields her, while standing in water electrifies it; ceiling debris punishes the islands.",
    "Use water/land positioning deliberately, block her cone scream, and move into safer water during falling debris.",
    "Position Sellistrix to balance her shield against electrified-water damage; face cone away.",
    "Heal group through water ticks and scream damage.",
    "Stay behind and follow the tank's positioning.",
    "[Sellistrix] Position in water to remove shield; block scream; avoid debris.")

-- Direfrost Keep
addDungeon("Direfrost Keep", "base")
addBoss("Teethnasher the Frostbound", "Direfrost Keep", "Teethnasher the Frostbound", {"Teethnasher"},
    "Frost troll miniboss with heavy melee and frost pressure.",
    "Avoid frontal attacks and ground frost.",
    "Face away and block heavies.",
    "Watch tank spikes.",
    "Stay behind and burn.",
    "[Teethnasher] Stay behind; avoid frost.")

addBoss("Guardian of the Flame", "Direfrost Keep", "Guardian of the Flame", {"Guardian"},
    "Flame guardian with strong fire ground effects.",
    "Stay out of fire and interrupt dangerous casts when possible.",
    "Keep boss in clear space.",
    "Heal through flame pressure.",
    "Move out of fire; keep damage up.",
    "[Guardian] Avoid fire; interrupt.")

addBoss("Drodda's Dreadlord", "Direfrost Keep", "Drodda's Dreadlord", {"Dreadlord"},
    "Undead melee boss with add/control pressure.",
    "Stay behind and clear adds/control effects promptly.",
    "Face away and gather adds.",
    "Watch tank and add pressure.",
    "Cleave adds.",
    "[Dreadlord] Stay behind; cleave adds.")

addBoss("Drodda's Apprentice", "Direfrost Keep", "Drodda's Apprentice", {"Apprentice"},
    "Frost caster with dangerous spell pressure.",
    "Interrupt casts and avoid frost ground effects.",
    "Keep boss positioned for interrupts.",
    "Watch ranged frost spikes.",
    "Interrupt and burn.",
    "[Apprentice] Interrupt frost casts; avoid AoE.")

addBoss("Iceheart", "Direfrost Keep", "Iceheart", {},
    "Frost atronach boss with ice AoE and add pressure.",
    "Avoid expanding frost and control adds.",
    "Hold Iceheart steady and face away.",
    "Expect sustained frost damage.",
    "Cleave adds and boss.",
    "[Iceheart] Avoid frost AoE; cleave adds.")

addBoss("Drodda of Icereach", "Direfrost Keep", "Drodda of Icereach", {"Drodda"},
    "Final ice mage who drains a targeted player's health and uses frost AoE.",
    "Break/interrupt the life-drain mechanic immediately and stay out of frost ground effects.",
    "Keep Drodda controlled and interrupt when possible.",
    "Hard-focus healing on the drain target.",
    "Interrupt drain; otherwise burn boss.",
    "[Drodda] Stop life drain ASAP; avoid frost AoE.")

-- Blessed Crucible
addDungeon("Blessed Crucible", "base")
addBoss("Grunt the Clever", "Blessed Crucible", "Grunt the Clever", {"Grunt"},
    "Arena fighter with fear and a large frontal melee attack.",
    "Break free from fear and get out of the huge frontal attack.",
    "Face away and block heavy attacks.",
    "Watch feared players.",
    "Stay behind and burn.",
    "[Grunt] Break fear; avoid giant frontal.")

addShared({"Dynus Aralas", "Kayd at-Sal", "Nusana", "Snagg gro-Mashul"}, "Blessed Crucible", "The Pack", {"Pack"},
    "Four-boss arena pack fought together.",
    "Stay stacked enough for support, focus dangerous targets, and avoid overlapping AoEs.",
    "Control as many Pack members as possible and keep them grouped.",
    "Heavy group healing while multiple bosses are active.",
    "Focus/cleave the Pack down quickly.",
    "[Pack] Group them; focus/cleave; avoid overlapping AoE.")

addBoss("Teranya the Faceless", "Blessed Crucible", "Teranya the Faceless", {"Teranya"},
    "Arena miniboss with two enraged Durzogs.",
    "Kill/stack the Durzogs and avoid frontal melee pressure.",
    "Taunt Durzogs and boss; stack them.",
    "Watch opening damage from all three enemies.",
    "Cleave Durzogs with boss.",
    "[Teranya] Stack Durzogs; cleave.")

addBoss("The Beast Master", "Blessed Crucible", "The Beast Master", {"Beast Master"},
    "Arena handler encounter fought through successive beast phases, including Stinger and the Troll King.",
    "Kill each beast phase cleanly, avoid frontal/ground attacks, and stay ready for the next spawn.",
    "Pick up each spawned beast immediately and face it away from the group.",
    "Watch transition damage as each new beast enters.",
    "Burn each beast in sequence; keep AoE off dangerous ground effects.",
    "[Beast Master] Sequential beasts: control each spawn and burn it down.")

addBoss("Stinger", "Blessed Crucible", "Stinger", {"Scorpion"},
    "First Beast Master stage: giant scorpion.",
    "Avoid frontal attacks and poison; burn it quickly.",
    "Face away.",
    "Watch poison damage.",
    "Stay behind and burn.",
    "[Stinger] Avoid front/poison; burn.")

addBoss("The Troll King", "Blessed Crucible", "The Troll King", {"Troll King"},
    "Final Beast Master stage and monster-set boss with heavy troll attacks.",
    "Avoid frontal/ground attacks and burn through regeneration pressure.",
    "Face away and block heavies.",
    "Keep tank stable.",
    "Stay behind and maintain pressure.",
    "[Troll King] Stay behind; keep pressure on boss.")

addBoss("Captain Thoran", "Blessed Crucible", "Captain Thoran", {"Thoran"},
    "Captain surrounded by adds; later gains protection tied to a Lava Atronach.",
    "Clear adds, avoid purple/fire ground effects, and kill the Lava Atronach when it appears to remove protection.",
    "Stack adds on Thoran.",
    "Watch fire damage during the shield phase.",
    "Atronach is priority when spawned.",
    "[Thoran] Clear adds; kill Lava Atronach to drop protection.")

addBoss("The Lava Queen", "Blessed Crucible", "The Lava Queen", {"Lava Queen"},
    "Final arena boss with heavy fire pressure and Lava Atronachs.",
    "Keep moving out of fire and kill/cleave atronachs before they overwhelm the arena.",
    "Keep boss positioned in clear space and collect adds.",
    "Heavy group healing during fire phases.",
    "Cleave atronachs and boss; respect fire.",
    "[Lava Queen] Avoid fire; control Lava Atronachs.")

-- Tempest Island
addDungeon("Tempest Island", "base")
addBoss("Sonolia the Matriarch", "Tempest Island", "Sonolia the Matriarch", {"Sonolia"},
    "Lamia miniboss with Sea Viper/Lamia adds and a conal scream.",
    "Kill/stack adds and stay out of the frontal scream.",
    "Face away and collect adds.",
    "Watch tank damage from the scream.",
    "Cleave adds behind boss.",
    "[Sonolia] Stack adds; avoid frontal scream.")

addBoss("Valaran Stormcaller", "Tempest Island", "Valaran Stormcaller", {"Valaran"},
    "Storm mage with lightning AoE, summoned avatar, and stuns.",
    "Move out of lightning, break free if stunned, and kill/cleave the avatar.",
    "Control the boss/avatar and block heavies.",
    "Watch shock damage.",
    "Cleave avatar and boss.",
    "[Valaran] Avoid lightning; kill avatar; break stuns.")

addBoss("Yalorasse the Speaker", "Tempest Island", "Yalorasse the Speaker", {"Yalorasse"},
    "Maormer miniboss with adds, whirlwind, and lightning AoE.",
    "Clear adds and step out of whirlwind/lightning.",
    "Stack adds and face boss away.",
    "Watch melee damage during whirlwind.",
    "Cleave adds and boss.",
    "[Yalorasse] Stack adds; avoid whirlwind/lightning.")

addBoss("Stormfist", "Tempest Island", "Stormfist", {},
    "Storm atronach boss with stomps, lightning bursts, adds, and an execute enrage.",
    "Avoid stomp/lightning AoEs, control adds, and burn hard below ~25%.",
    "Hold boss steady and gather adds.",
    "Prepare for heavier damage in execute.",
    "Save burst for execute.",
    "[Stormfist] Avoid stomp/lightning; burn hard at execute.")

addBoss("Commodore Ohmanil", "Tempest Island", "Commodore Ohmanil", {"Ohmanil", "Ohmamil"},
    "Maormer miniboss fought with a large add pack and a player-stun orb.",
    "Stack/cleave adds and break free from control effects.",
    "Group the entire pack on Ohmanil.",
    "Watch opening pack damage.",
    "AoE aggressively.",
    "[Ohmanil] Stack whole pack; AoE; break control.")

addBoss("Stormreeve Neidir", "Tempest Island", "Stormreeve Neidir", {"Neidir"},
    "Final storm boss with a lethal close AoE, long-range charge, gusts, and shock attacks.",
    "Stay at controlled mid-range, step out of Sparking Strike, avoid standing too far away, and recover quickly from gust knockdowns.",
    "Position Neidir predictably and use charge only deliberately for repositioning.",
    "Watch players caught by gust + lightning combinations.",
    "Maintain mid-range uptime and avoid the large close AoE.",
    "[Neidir] Mid-range; out of Sparking Strike; don't bait charge.")

-- Selene's Web
addDungeon("Selene's Web", "base")
addBoss("Treethane Kerninn", "Selene's Web", "Treethane Kerninn", {"Treethane Kerninn", "Keminn", "Kerninn"},
    "Bosmer miniboss with adds, pull-in/raven AoE, and whirlwind.",
    "Kill/cleave adds and move out after the pull-in when the raven AoE appears.",
    "Stack adds and keep boss centered.",
    "Watch group after pull-in.",
    "Cleave adds; step out of whirlwind/ravens.",
    "[Treethane] Stack adds; move out after pull-in.")

addBoss("Longclaw", "Selene's Web", "Longclaw", {},
    "Archer boss with recurring spirit Senche and poison/arrow ground effects.",
    "Control tiger spirits, avoid poison/arrow circles, and keep pressure on Longclaw.",
    "Pick up spirit cats if possible.",
    "Watch ranged and add damage.",
    "Boss pressure matters; cleave/control cats rather than chasing endlessly.",
    "[Longclaw] Control spirit cats; avoid poison/arrow AoE.")

addBoss("Queen Aklayah", "Selene's Web", "Queen Aklayah", {"Aklayah"},
    "Hoarvor queen with small add spawns and a conal attack.",
    "Stay out of the cone and AoE the small hoarvors.",
    "Face away and gather adds.",
    "Light add pressure.",
    "Cleave adds.",
    "[Aklayah] Avoid cone; AoE hoarvors.")

addBoss("Foulhide", "Selene's Web", "Foulhide", {},
    "Bear boss with charge, knockdown, fear, and summoned stranglers.",
    "Dodge the charge line, break fear, and avoid standing in front.",
    "Face away and block heavy attacks.",
    "Watch players hit by charge/fear.",
    "Stay behind and burn; stranglers can usually be ignored if positioned well.",
    "[Foulhide] Dodge charge; break fear; stay behind.")

addBoss("Mennir Many-Legs", "Selene's Web", "Mennir Many-Legs", {"Mennir"},
    "Spider-summoning caster with a high-damage shock AoE.",
    "Avoid the shock AoE and clear spider adds.",
    "Keep boss/adds grouped.",
    "Watch shock burst.",
    "AoE spiders and boss.",
    "[Mennir] Avoid shock AoE; kill spiders.")

addBoss("Selene", "Selene's Web", "Selene", {},
    "Final two-phase encounter: spider form followed by Selene's humanoid form with heavy spirit-bear attacks.",
    "Stay out of large telegraphs and react to the spirit-bear strike; keep the arena clear of adds/mechanics.",
    "Face Selene away and hold her steady through phase two.",
    "Watch sudden burst from the bear mechanic.",
    "Burn through phase changes while respecting the bear telegraph.",
    "[Selene] Two phases; dodge spirit-bear/large telegraphs.")

-- Volenfell
addDungeon("Volenfell", "base")
addBoss("Desert Lion", "Volenfell", "Desert Lion", {},
    "Lion boss with four lioness adds and an AoE fear.",
    "Stack the lionesses, break free from Roar, and stay out of the front.",
    "Gather lionesses on the boss and block heavies.",
    "Watch feared players.",
    "Cleave all lions together.",
    "[Desert Lion] Stack lions; break fear.")

addBoss("Quintus Verres", "Volenfell", "Quintus Verres", {"Quintus"},
    "Multi-phase humanoid boss who switches weapons and attack patterns.",
    "Block melee heavies, avoid whirlwind/fire ground effects, and adapt when he changes phase.",
    "Keep pressure on Quintus and control positioning between phases.",
    "Watch random ranged/fire damage.",
    "Maintain uptime while avoiding phase-specific AoE.",
    "[Quintus] Multi-phase; block heavies; avoid whirlwind/fire.")

addBoss("Monstrous Gargoyle", "Volenfell", "Monstrous Gargoyle", {"Gargoyle"},
    "Paired encounter with Quintus Verres; the gargoyle adds heavy melee pressure while Quintus uses ranged and phase attacks.",
    "Keep both controlled, stay out of frontal attacks, and avoid Quintus's ground effects.",
    "Taunt the gargoyle and Quintus; keep dangerous fronts away from the group.",
    "Expect extra tank pressure while both are active.",
    "Focus or cleave the pair depending group damage; avoid telegraphs.",
    "[Quintus/Gargoyle] Control both; avoid fronts and ground AoE.")

addBoss("Boilbite", "Volenfell", "Boilbite", {"Boibite"},
    "Large beetle miniboss with smaller insect adds.",
    "Stack and AoE the adds while avoiding frontal attacks.",
    "Face away and collect adds.",
    "Watch swarm damage.",
    "Cleave the pack.",
    "[Boilbite] Stack insects; cleave.")

addBoss("Tremorscale", "Volenfell", "Tremorscale", {},
    "Duneripper boss with heavy frontal attacks and burrowing/ground pressure.",
    "Stay behind and move out of obvious ground telegraphs.",
    "Face away and block heavies.",
    "Watch burst around burrow/ground attacks.",
    "Stay behind and burn.",
    "[Tremorscale] Stay behind; avoid ground telegraphs.")

addBoss("Unstable Construct", "Volenfell", "Unstable Construct", {},
    "Fast Dwemer construct encounter with mechanical adds.",
    "Stay together, interrupt dangerous construct abilities, and AoE the adds.",
    "Collect adds and control the construct.",
    "Watch tank spikes from multiple machines.",
    "AoE and interrupt.",
    "[Construct] Stack machines; interrupt; AoE.")

addShared({"Guardian's Strength", "Guardian's Spark", "Guardian's Soul", "Guardian Council", "The Guardian Council"}, "Volenfell", "Guardian Council", {"Guardian Constructs"},
    "Final encounter with three Dwemer guardians using different elemental/role mechanics.",
    "Keep all three controlled, avoid elemental ground effects, and focus one guardian at a time if the group needs to reduce incoming pressure.",
    "Taunt/control the guardians and keep dangerous fronts away from the group.",
    "Expect mixed elemental damage while multiple guardians are active.",
    "Focus or cleave depending group strength; do not stand in ground AoE.",
    "[Council] Control 3 guardians; avoid elemental AoE; focus one if needed.")

-- Blackheart Haven
addDungeon("Blackheart Haven", "base")
addBoss("Iron-Heel", "Blackheart Haven", "Iron-Heel", {"Iron Heel"},
    "Pirate miniboss with supporting enemies.",
    "Stack and cleave the pirate pack; avoid frontal attacks.",
    "Collect adds and face boss away.",
    "Cover opening pack damage.",
    "AoE the pack.",
    "[Iron-Heel] Stack pirates; cleave.")

addBoss("Atarus", "Blackheart Haven", "Atarus", {},
    "Ogrim boss with acid breath, charge, stomp, and an enrage around 30%.",
    "Avoid the breath/charge/stomp and burn cleanly through execute.",
    "Keep Atarus central, face away, and block breath/heavies.",
    "Watch increased pressure after enrage.",
    "Stay behind and save burst for execute.",
    "[Atarus] Avoid breath/charge/stomp; burn execute.")

addBoss("First Mate Wavecutter", "Blackheart Haven", "First Mate Wavecutter", {"Wavecutter"},
    "Pirate officer with harpy support.",
    "Stack/kill harpies and avoid frontal attacks.",
    "Collect adds on Wavecutter.",
    "Watch ranged harpy damage.",
    "Cleave adds and boss.",
    "[Wavecutter] Stack harpies; cleave.")

addBoss("Roost Mother", "Blackheart Haven", "Roost Mother", {},
    "Hagraven with persistent fire projectiles/ground pressure.",
    "Keep moving out of incoming fire circles without dragging them through teammates.",
    "Hold boss stable in clear space.",
    "Watch spread fire damage.",
    "Maintain damage while moving.",
    "[Roost Mother] Keep moving; don't overlap fire circles.")

addBoss("Hollow Heart", "Blackheart Haven", "Hollow Heart", {},
    "Wraith miniboss with magical AoE.",
    "Avoid ground effects and interrupt if possible.",
    "Hold boss steady.",
    "Watch magical burst.",
    "Burn quickly.",
    "[Hollow Heart] Avoid AoE; burn.")

addBoss("Captain Blackheart", "Blackheart Haven", "Captain Blackheart", {"Blackheart"},
    "Final pirate boss who periodically turns a player into a skeleton while undead adds spawn.",
    "When transformed, survive and avoid danger until your abilities return; everyone else controls adds and keeps pressure on the boss.",
    "Keep Blackheart and adds controlled, especially if healer/tank is transformed.",
    "Be ready to cover roles when someone becomes a skeleton.",
    "Kill dangerous adds and burn boss between transforms.",
    "[Blackheart] Skeleton transform removes skills; survive and cover that role.")

-- Vaults of Madness
addDungeon("Vaults of Madness", "base")
addBoss("The Cursed One", "Vaults of Madness", "The Cursed One", {"Cursed One"},
    "Opening undead boss with magical/add pressure.",
    "Stack adds and avoid ground effects.",
    "Collect adds and face boss safely.",
    "Watch opening group damage.",
    "Cleave adds.",
    "[Cursed One] Stack adds; avoid AoE.")

addBoss("Ulguna Soul-Reaver", "Vaults of Madness", "Ulguna Soul-Reaver", {"Ulguna"},
    "Floating Daedric caster with dangerous magic attacks.",
    "Interrupt/avoid telegraphed casts and stay out of ground AoE.",
    "Keep Ulguna positioned predictably.",
    "Watch ranged burst.",
    "Interrupt and burn.",
    "[Ulguna] Interrupt casts; avoid AoE.")

addBoss("Death's Head", "Vaults of Madness", "Death's Head", {"Deaths Head"},
    "Large skeletal brute with undead adds.",
    "Stay behind and clear/cleave adds.",
    "Face away and gather adds.",
    "Watch tank spikes.",
    "Cleave the pack.",
    "[Death's Head] Stay behind; cleave adds.")

addBoss("Grothdarr", "Vaults of Madness", "Grothdarr", {},
    "Flesh atronach boss surrounded by moving lava hazards.",
    "Keep moving out of lava and avoid frontal attacks.",
    "Position Grothdarr in clear space and face away.",
    "Expect steady fire damage.",
    "Stay behind and maintain uptime while moving.",
    "[Grothdarr] Avoid moving lava; stay behind.")

addBoss("Achaeraizur", "Vaults of Madness", "Achaeraizur", {},
    "Daedroth boss with Daedric adds and heavy frontal fire.",
    "Stay behind and control adds.",
    "Face away and stack adds.",
    "Watch fire/add damage.",
    "Cleave adds behind boss.",
    "[Achaeraizur] Stay behind; stack adds.")

addBoss("The Ancient One", "Vaults of Madness", "The Ancient One", {"Ancient One"},
    "Watcher boss with ranged magical attacks and ground effects.",
    "Spread enough to see telegraphs and move out promptly.",
    "Keep boss centered.",
    "Watch ranged burst.",
    "Maintain uptime while dodging AoE.",
    "[Ancient One] Avoid ground/ranged telegraphs.")

addBoss("Iskra the Omen", "Vaults of Madness", "Iskra the Omen", {"Iskra"},
    "Large winged Daedra with heavy frontal and leap/ground pressure.",
    "Stay behind and move out of large telegraphs.",
    "Face away and block heavies.",
    "Watch leap/ground burst.",
    "Stay behind and burn.",
    "[Iskra] Stay behind; avoid large telegraphs.")

addBoss("Mad Architect", "Vaults of Madness", "Mad Architect", {"Architect"},
    "Final lich with repeated magical phases and high group-wide damage.",
    "Stay together enough for healing, avoid ground effects, and react to phase changes rather than tunneling.",
    "Keep boss positioned so the group has clear floor space.",
    "Save strong healing for heavy group-damage phases.",
    "Maintain uptime between mechanics.",
    "[Architect] Avoid AoE; stack for heals during heavy phases.")
