-- Compact acquisition facts adapted from UESP. See SourceAttribution.txt.
-- Encoded text stays small at load; source records are decoded only on demand.
local Sources={}
TamrielCollections.antiquityFurnitureSources=Sources
local data=[=[
77|3|Glenumbra|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Glenumbra Pathfinder.|||||
78|19|Stormhaven|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Stormhaven Pathfinder.|||||
79|20|Rivenspire|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Rivenspire Pathfinder.|||||
80|104|Alik'r Desert|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Alik'r Desert Pathfinder.|||||
81|92|Bangkorai|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Bangkorai Pathfinder.|||||
82|41|Stonefalls|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Stonefalls Pathfinder.|||||
83|57|Deshaan|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Deshaan Pathfinder.|||||
84|117|Shadowfen|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Shadowfen Pathfinder.|||||
85|101|Eastmarch|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Eastmarch Pathfinder.|||||
86|103|The Rift|Buy from innkeepers or general goods merchants for 1,000 gold. Requires The Rift Pathfinder.|||||
87|381|Auridon|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Auridon Pathfinder.|||||
88|383|Grahtwood|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Grahtwood Pathfinder.|||||
89|108|Greenshade|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Greenshade Pathfinder.|||||
90|58|Malabal Tor|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Malabal Tor Pathfinder.|||||
91|382|Reaper's March|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Reaper's March Pathfinder.|||||
93|684|Wrothgar|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Wrothgar Pathfinder.|||||
94|849|Vvardenfell|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Morrowind Pathfinder.|||||
95|1011|Summerset|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Summerset Pathfinder.|||||
96|726|Murkmire|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Murkmire Pathfinder.|||||
97|1086|Northern Elsweyr|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Northern Elsweyr Pathfinder.|||||
98|1133|Southern Elsweyr|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Pellitine Pathfinder.|||||
249|684|Old Orsinium|Mobs in Old Orsinium|Old Orsinium||||
250|347|Coldharbour|Any crafting node|||||
251|108|Greenshade|Chopping wood nodes|||||
252|58|Malabal Tor|Loot safeboxes, chests, Troves, senche, Crimson Cove bosses, Commander Faldethil or jewelry nodes.|||||
253|101,58,1160,684|Mammoths in several zones|Overland Mammoths or Timber Mammoths in:; Eastmarch; Malabal Tor; Western Skyrim; Wrothgar|||||
254|117|Arx Corinium|Group Dungeon boss Sellistrix the Lamia Queen in Arx Corinium||Arx Corinium|||
255|1011|Summerset|Gryphons|||||
256|20|Rivenspire|Blacksmithing ore nodes; Jewlery ore nodes|||||
257|58|Malabal Tor|Thieves Troves; Safeboxes; World Bosses in Malabal Tor; Public Dungeon bosses in Crimson Cove|||||
258|181|Cyrodiil settlement quests|Settlement Quest rewards in Cyrodiil|||||
259|888|Craglorn|Safeboxes, Treasure Chests and Thieves Troves; Fishing; Mobs; Blacksmithing ore nodes|||||
260|816|Hew's Bane|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Wood nodes; Enchanting Runestone nodes|||||
261|281|Bal Foyen|Safeboxes , Treasure Chests|||||
262|3|Glenumbra|Treasure Chests|||||
263|535|Betnikh|Overland mobs|||||
264|1160,1161|Western Skyrim / Blackreach|Loot enemies in Western Skyrim or Blackreach, including overland and instanced areas.|||||
265|381|Auridon|Treasure Chests|||||
266|980|Clockwork City|Fishing in oily fishing holes|||||
267|849|Vvardenfell|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Public Dungeon and World Bosses; Delve Bosses; Clothing nodes|||||
268|849|Vivec City daily quests|Hall of Justice daily quest reward|Vivec City||||
269|1133|Southern Elsweyr|Backpacks and containers (urns, etc)|||||
270|726|Murkmire|All loot tables in Murkmire|||||
271|19|Stormhaven|Safeboxes, Treasure Chests and Thieves Troves; Public Dungeon bosses in Bonesnap Ruins; Dolmen Bosses; Mobs; Any crafting node|||||
272|101|Eastmarch|Loot containers, enemies, Ammabani's Pride/Hall of the Dead bosses, cloth nodes or runestones.|||||
273|280|Bleakrock Isle|Overland mobs|||||
274|104|Alik'r Desert|Safeboxes|||||
275|281|Bal Foyen|Safeboxes, Treasure Chests and Thieves Troves; Blacksmithing ore nodes; Wood nodes|||||
276|383|Grahtwood|Loot containers, enemies, Root Sunder Ruins/Elden Hollow I bosses, ore or cloth nodes.|||||
277|823|Gold Coast|World Boss Limenauruus in Tribune's Folly; Overland Minotaurs|||||
278|584,643|Imperial City / Sewers|Loot chests, enemies or bosses in the Imperial City districts and sewers.|||||
279||PvP reward containers|PvP Rewards:; Battlemaster Rivyn's Reward Box; "Rewards for the Worthy" mail|||||1
280|57|Deshaan|Safeboxes|||||
281|19|Stormhaven|Psijic portals; Alchemy nodes; Enchanting Runestones nodes|||||
282|41|Stonefalls|Safeboxes and Treasure Chests; Overland mobs; Public Dungeon bosses in Crow's Wood; World Bosses|||||
283|537|Khenarthi's Roost|Psijic portals; Enchanting Runestones nodes|||||
284|382|Reaper's March|Safeboxes|||||
285|381|Auridon|Loot safeboxes, chests, Troves, enemies, Toothmaul Gully/Dolmen bosses, ore or wood nodes.|||||
286|347|Coldharbour|World and Public Dungeon bosses; Treasure Chests; Psijic portals; Enchanting Runestones nodes; Chopping wood nodes|||||
287|101,103,58,1160,181|Large beasts in several zones|Loot giants, mammoths, sabre cats or bristlebacks in the listed lead-source zones.|||||
288|1086|Northern Elsweyr|Dragons|||||
289|823|Depths of Malatar|Group Dungeon boss Symphony of Blades in Depths of Malatar||Depths of Malatar|||
290|181,584,643|Cyrodiil / Imperial City|Loot chests, enemies and bosses in Cyrodiil or the Imperial City, including the sewers.|||||
291|535|Betnikh|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Crafting nodes|||||
292|280|Bleakrock Isle|Loot safeboxes, chests, Thieves Troves, enemies, quest bosses or crafting nodes.|||||
293|534|Stros M'Kai|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Bosses; Fishing|||||
294|103|The Rift|Safeboxes, Treasure Chests and Thieves Troves; Public Dungeon bosses; Delve bosses; Any mob; Clothing nodes|||||
295|1133|Southern Elsweyr|Dragons|||||
296|537|Khenarthi's Roost|Clothing nodes; Thieves Troves and Treasure Chests|||||
297|181,584|Cyrodiil / Imperial City|Treasure Chests in Cyrodiil; Bosses in the Imperial City districts|||||
298|1160,1161|Western Skyrim / Blackreach|Loot containers, mobs, bosses, Labyrinthian/Nchuthnkarst, Harrowstorms or runestones in Western Skyrim/Blackreach.|||||
299|684|Wrothgar|Safeboxes, Treasure Chests and Thieves Troves; Public Dungeon bosses; Blacksmithing ore nodes; Wood nodes|||||
300|20|Rivenspire|Loot safeboxes, chests, Troves, Obsidian Scar bosses, Psijic Portals, cloth/wood nodes or Crypt of Hearts II mobs.|||||
301|92|Bangkorai|Loot safeboxes, chests, Troves, enemies, bosses, Psijic Portals, cloth or wood nodes.|||||
302|816|Abah's Landing daily quests|Reward containers for completing Thieves Guild daily quests|Abah's Landing||||
303|108|Greenshade|Loot safeboxes, chests, Troves, Rulanyil's Fall bosses, Tarcyr or Maheelius at Reconnaissance Camp.|||||
307|534|Stros M'Kai|Treasure Chests; Overland mobs; Mobs inside Bthzark|||||
308|888|Craglorn trials|Final boss of any Craglorn Trial||Aetherian Archive,Hel Ra Citadel,Sanctum Ophidia|||
312|823|Gold Coast|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Gold Coast Pathfinder.|||||
313|888|Craglorn|Buy the lead from a Craglorn innkeeper or general goods merchant for 1,000 gold.|||||
314|347|Cicero Eudoxius / Hollow City|Buy the lead from Cicero Eudoxius at Cicero's Food & General Goods in the Hollow City.|The Hollow City||||
315|816|Hew's Bane|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Hew's Bane Pathfinder.|||||
353|1207|The Reach|Safeboxes, Treasure Chests and Thieves Troves; Harrowstorms; Harvesting nodes|||||
354|1207|The Reach|Harrowstorms|||||
355|1207|The Reach|Buy from innkeepers or general goods merchants for 1,000 gold. Requires The Reach Pathfinder.|||||
359|1160|Western Skyrim|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Western Skyrim Pathfinder.|||||
375|1261|Blackwood|Safeboxes, Treasure Chests and Thieves Troves; World and Public Dungeon bosses; Harvesting nodes|||||
376|1261|Leyawiin daily quests|Reward container from Daily Quests in Blackwood.|Leyawiin||||
380|1261|Blackwood|Buy from innkeepers or general goods merchants for 1,000 gold. Requires Blackwood Pathfinder.|||||
401|1261|Blackwood|Southwest of the Stonewastes Wayshrine, inside a reed tent next to an extinguished fire.|||0.596923|0.789068|
402|1261|Blackwood|Inside the Eastern Path tunnel north of Vunalk Wayshrine, behind a shrine.|||||
403|1261|Blackwood|Inside a destroyed shack east of the broken elevated walkway over the road at the north edge of Stonewastes.|||0.638|0.796|
404|1261|Blackwood|Southeast of The Shattered Xanmeer World Boss.|||0.585692|0.857414|
405|1261|Blackwood|East of Leyawiin: cross the bridge, turn southeast; look under rocks by a skeleton and backpack.|||0.30566|0.5739799999999999|
406|1261|Blackwood|South of Glenbridge, next to a tent at a campsite east of the road.|||0.662593|0.66772|
407|1261|Blackwood|Next to a boat southeast of Tidewater Cave.|||0.317385|0.699704|
408|1261|Blackwood|North of the Vunalk Wayshrine, inside a destroyed hut in the middle of the lake.|||0.814|0.635|
409|1261|Blackwood|Northeast wall outside of The Silent Halls Public Dungeon, next to a dig site with a shovel.|||0.580079|0.6293949999999999|
410|1261|Blackwood|Southeast of the Xeemhok's Lagoon World Boss, in a destroyed hut next to a skeleton|||0.817871|0.794914|
411|1261|Blackwood|Ruined cart southeast of the Blueblood Wayshrine|||0.372559|0.674805|
412|1261|Blackwood|Enter Duchess's Private Study via the trapdoor north of Gideon; check the broken alcove.|||||
413|1261|Blackwood|Northwest of the Xi-Tsei Delve, close to a boat.|||0.489256|0.7546390000000001|
414|1261|Blackwood|Southwest of White Stallion Inn, staying to the north side of the brook, inside a cave against the cliff walls.|||0.165042|0.47753999999999996|
415|1261|Blackwood|South of the White Stallion Inn, next to a skeleton by the water.|||0.206289|0.45653900000000003|
433|1283,1286|Fargrave / Deadlands|Safeboxes in Fargrave, The Deadlands|||||
434|1286|The Deadlands|Wandering Bosses in the Deadlands|||||
435|1286,1283|Deadlands / Fargrave merchants|Buy from Deadlands traveling merchants or Haj-Mere in Fargrave for 1,000 gold. Requires Deadlands Pathfinder.|||||
452|1286,1261|Atoll of Immolation|Loot the reward chest after defeating Havocrel Duke of Storms, the final boss in Atoll of Immolation.|||||
453|1286|The Deadlands|Enchanting Rune nodes in the Deadlands|||||
499|1318|High Isle|Northeast of Amenos Station, on a small island in a lake. Inside an "Old Pot"|||0.766479|0.411987|
500|1318|High Isle|North of Amenos Station, on a "Textured Bowl" in the third compartment from the left in the lowest row|||0.676636|0.391968|
501|1318|High Isle|Skulltooth Coast on Amenos, from "Rusty Food Handling Tongs" behind the shipwreck in the water|||0.661987|0.229248|
502|1318|High Isle|Northeast beach on All Flags Islet. Found on a "Time-worn Stone" behind a rock on the beach, between two parts of a shipwreck|||0.355225|0.62793|
503|1318|High Isle|North of Stonelore Falls in the bay, inside an "Olden Breton Teapot" next to a boulder|||0.214722|0.5090330000000001|
504|1318|High Isle|East of Castle Navire, found on a "Damaged Woven Strainer" next to a tree, close to the road|||0.229248|0.782715|
505|1318|High Isle|Southwest of Dufort Shipyard Wayshrine is a small lava lake. The lead is on the "Blazing Stones" right of the stairs behind a rock|||0.54834|0.606689|
506|1318|High Isle|Pick up the Druidic Butcher Knife northwest of Tor Draioch, west uphill from the volcanic vent.|||0.480957|0.6337889999999999|
507|1318|High Isle|North end of High Isle, inside an "Ancient Cleaning Tools" box next to a tree|||0.392456|0.397705|
508|1318|High Isle|West of Spriggan's Crown, in a "Stained Water Jug" on the beach close to a tree|||0.288|0.886|
510|1318|Gonfalon Bay daily quests|Daily Quest reward coffers in Gonfalon Bay, High Isle|Gonfalon Bay||||
511|1318|Dreadsail Reef|Any enemy in Dreadsail Reef trial||Dreadsail Reef|||
512|1318|High Isle|Buy from traveling merchants or Lennoc Spennard for 1,000 gold. Requires High Isle Pathfinder.|||||
535|1383|Vastyr merchants|Buy the lead from Archimbert Vygrant or Hyaidouna in Vastyr.|Vastyr||||
536|1383|Galen|All Loot Tables in Galen|||||
537|1383|Ghost Haven Bay|Hadolid Broodmother in Ghost Haven Bay public dungeon|Ghost Haven Bay||||
547|1283|Fargrave innkeepers|Buy from a Fargrave innkeeper for 1,000 gold. Requires Hero of Fargrave.|||||
548|1383|Vastyr daily quests|Galen Reward Coffer|Vastyr||||
549|19|Wayrest Sewers II|Allene Pellingare and Varaine Pellingare in Wayrest Sewers II group dungeon||Wayrest Sewers II|||
577|1413,1414|Telvanni / Apocrypha merchants|Buy from innkeepers or traveling merchants in Telvanni Peninsula/Apocrypha. Requires Necrom Pathfinder.|||||
601|1413,1414|Telvanni / Apocrypha merchants|Buy from innkeepers or traveling merchants in Telvanni Peninsula/Apocrypha. Requires Hero of Necrom.|||||
602,603,604,605,606,607,609,610,611|1413,1414|Telvanni Peninsula / Apocrypha|Apocrypha and Telvanni Peninsula Treasure Maps|||||
608|1413,1414|Telvanni Peninsula / Apocrypha|All loot tables in Apocrypha and Telvanni Peninsula|||||
612|1414|Quires Wind|Defeat Cipher Gelon in Quires Wind, Apocrypha.|Quires Wind||||
613|1413|Nightmare Den|Defeat the boss in Nightmare Den, Telvanni Peninsula.|Nightmare Den||||
614|980|Halls of Regulation|Defeat the Steadfast Regulator in Halls of Regulation, Clockwork City.|Halls of Regulation||||
615|1413|Telvanni Peninsula|From "Sizzling Rocks" south of Sailenmora|||0.466|0.675|
616|1413|Telvanni Peninsula|From "Runic Rock" on the east side of the bridge leading to Kemel-Ze|||0.362|0.344|
617|1413|Telvanni Peninsula|From "Damaged Reagent Rack" along the rocks behind the northeastern house in Ald Isra|||0.272|0.45199999999999996|
618|1413|Telvanni Peninsula|From "Damaged Funneling Mechanism" on the north bank of the river above Sailenmora|||0.446|0.47|
619|1413|Telvanni Peninsula|From "Leaky Crucible" on an island east of Kemel-Ze|||0.42|0.30600000000000005|
620|1413|Telvanni Peninsula|From "Unusual Mortar" northwest of Tel Dreloth|||0.529|0.657|
621|1413|Telvanni Peninsula|From "Shattered Desiccator" in southwest Alavelis|||0.41|0.813|
622|1413|Telvanni Peninsula|From "Clogged Retort" on an island south of Ald Isra|||0.224|0.5469999999999999|
623|1413|Telvanni Peninsula|From "Questionable Burette" on the south bank of the river above Sailenmora|||0.434|0.506|
624|1413|Telvanni Peninsula|From "Vacuum Filtration Apparatus" along the rocks north of the Padomaic Crest Wayshrine|||0.54|0.542|
633|382|Reaper's March|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Dolmen Bosses; World Bosses|||||
634|3|Glenumbra|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; World Bosses; Dolmens|||||
635|104|Alik'r Desert|Safeboxes, Treasure Chests and Thieves Troves; Overland mobs; Dolmen Bosses; World Bosses|||||
636|57|Deshaan|Chest in Forgotten Crypts; Dark Anchor Boss; Treasure Map; World Boss; Safeboxes|||||
637|117|Shadowfen|All loot tables|||||
638|823|Gold Coast|All loot tables in the Gold Coast|||||
639|980|Clockwork City|All Clockwork City loot tables|||||
640|1011|Summerset|Treasure Chest;Any mob in Summerset zones;Public Dungeon boss Nolore Stieve in Karnwasten|||||
641|1086|Northern Elsweyr|All loot tables in Northern Elsweyr|||||
642|1133|Southern Elsweyr|Treasure Chest;Random mob|||||
643|1283,1286|Fargrave / Deadlands|Thieves Troves;Safeboxes in Fargrave;Mobs in Atoll of Immolation|||||
647,648,649,650,651,652,653,654,655,656,657,658,659,660,661,662,663,664,665,666,667,668|1414|Infinite Archive|Loot Infinite Archive chests, Gw the Pilferer or Marauders.|Infinite Archive|Infinite Archive|||
687|1443|Skingrad / West Weald merchants|Buy from West Weald innkeepers or general goods merchants for 1,000 gold. Requires Gold Road Pathfinder.|Skingrad||||
688,689,690,691,692,693,694,696,697,698|1443|West Weald|West Weald Treasure Maps|||||
695|1443|West Weald|West Weald Thieves Troves, Safeboxes, chests, treasure map chests, containers and backpacks; West Weald enemies|||||
699|1443|Silorn|Bosses in Silorn|Silorn||||
700|1443|Lake Olo|Oakenclaw World Boss at Lake Olo|Lake Olo||||
701|1443|Fyrelight Cave|Scourgetail in Fyrelight Cave|Fyrelight Cave||||
702|1443|Nonungalo|Shattered Shard Boss in Nonungalo|Nonungalo||||
703|1443|Fall's Glade|Spinner Urthrendir World Boss at Fall's Glade|Fall's Glade||||
739|1502|Solstice|Any Solstice loot table (including trial)|||||
740,741,742,743,744,745,746,765,769,770,771,772,773|1502|Solstice|Solstice Treasure Maps|||||
750|1502|Solstice|Buy the lead from a Solstice innkeeper for 1,000 gold.|||||
759|1502|Lair of the Black Worm|Riuzzan the Ravenous - Boss in Lair of the Black Worm|Lair of the Black Worm||||
760|1502|Calindvale Gardens|Infested Lurcher - Boss in Calindvale Gardens Public Dungeon|Calindvale Gardens||||
761|1502|Zyv-Elehk Ritual Site|Ghishzor at Zyv-Elehk Ritual Site|Zyv-Elehk Ritual Site||||
762|1502|Sea and Sword Lodge|Sea and Sword Lodge delve boss|Sea and Sword Lodge||||
763|1502|Soulcaller's Haunt|Soulcaller's Haunt World Boss|Soulcaller's Haunt||||
764|1502|Solstice|Public Dungeon Bosses on Solstice; Ossein Cage mobs|||||
766|1502|Solstice|Solstice mobs; Thieves Troves|||||
767|1502|Xul-Katama|Delve Boss from Xul-Katama|Xul-Katama||||
768|1502|Lair of Wo-Xeeth|Lair of Wo-Xeeth World Boss|Lair of Wo-Xeeth||||
779||Night Market|Defeat Calamitous Dunegorger, Calamitous Roksa the Warped or Calamitous Wailing Bedina in the Night Market.|||||
784,785,786,787,788|3,816|Glenumbra / Hew's Bane|Thieves Troves in Glenumbra and Hew's Bane; Heists|||||
789|3|Glenumbra|World Bosses at The Wolf's Camp|||||
790|3|Red Petal Bastion|Prior Thierric Sarazen, final boss in Red Petal Bastion||Red Petal Bastion|||
791|3|Glenumbra|Vampire Hunt Dynamic Encounter in Glenumbra|||||
792|41|Bilsa's Delivery|Bilsa's Delivery Dynamic Encounter in Stonefalls|||||
796||High Seas of Tamriel|High Seas of Tamriel ship battle reward|||||1
797,798,799,800,801,802,803||High Seas of Tamriel|High Seas of Tamriel event|||||1
]=]
local index,cache=nil,{}
local function List(value,numbers)
    local out={}
    for item in value:gmatch('[^,]+')do out[#out+1]=numbers and tonumber(item)or item end
    return out
end
function Sources.Get(id)
    if cache[id]~=nil then return cache[id]or nil end
    if not index then
        index={}
        for ids,payload in data:gmatch('([^\n|]+)|([^\n]+)')do
            for item in ids:gmatch('%d+')do index[tonumber(item)]=payload end
        end
    end
    local row=index[id]
    if not row then cache[id]=false;return end
    local zones,location,description,poi,nodes,x,y,world=row:match('^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$')
    local source={zones=List(zones,true),location=location,description=description}
    if poi~=''then source.poi=List(poi)end
    if nodes~=''then source.nodes=List(nodes)end
    if x~=''and y~=''then source.x,source.y=tonumber(x),tonumber(y)end
    if world=='1'then source.world=true end
    cache[id]=source;return source
end
