-- Compact acquisition facts adapted from UESP. See SourceAttribution.txt.
-- Encoded text stays small at load; source records are decoded only on demand.
local Sources={}
TamrielCollections.antiquityExtraSources=Sources
local data=[=[
102|1011|Kinlady Terannil / Rellenthil|Defeat Kinlady Terannil by the river south of Rellenthil.|Rellenthil||||
103|1160|Antiquarian Circle / Solitude|Tutorial antiquity from the Antiquarian Circle introductory quest in Solitude.|Solitude||||
104|1160|Blue Palace / Solitude|Read the Atmoran Tablet in High King Svargrim's chamber in the Blue Palace.|Solitude||||
105|1160|Morthal Barrow|Read the Atmoran Tablet inside Morthal Barrow.|Morthal||||
106|1160|Dragon Bridge|Read the Atmoran Tablet beneath the bridge at Dragon Bridge.|Dragon Bridge||||
107|1161|Nchuthnkarst|Defeat Clockwork Criterion in Nchuthnkarst, Blackreach: Greymoor Caverns.|Nchuthnkarst||||
108|1161|The Scraps|Defeat the Dwarven Spider delve boss in The Scraps.|The Scraps||||
109|1161|Dismantler's Ruin|Defeat Dismantler the Dwarven Colossus in Dark Moon Grotto, Blackreach.|Dismantler's Ruin||||
304,305,306|181|Cyrodiil conquest quests|Open Gladiator's Rucksacks awarded for Cyrodiil conquest daily quests.|||||
310|1160|Antiquarian Circle / Solitude|Excavate all starter green, blue and purple treasures in launch-to-Greymoor zones; collect the coin upstairs in Antiquarian Circle.|Solitude||||
345,346,347,348,349,350,351|1208|Bthar-Zel|Loot enemies in Bthar-Zel, Blackreach: Arkthzand Cavern.|Bthar-Zel||||
352|1208|Arkthzand Cavern|Loot the Inactive Construct beyond the broken bridge south of the Library of Arkthzand.|||||
374|1261|West of Rockgrove|Take the lead from the large grave stake by a tree west of Rockgrove.|||||
436|1286|North of Wretched Spire|Loot Unusual Metal at the base of a tall dead tree north-northeast of Wretched Spire Wayshrine.|||||
509|1318|Northeast of Banished Refuge|Pick up the Druidic Arrows on the cliff northeast of Banished Refuge, beside the waterfall.|||||
516|1283|Fargrave innkeepers|Buy the active Fargrave map lead for 1,000 gold. Requires Hero of Fargrave.|||||
538|849|Forgotten Wastes|Defeat bosses in Forgotten Wastes public dungeon.|Forgotten Wastes||||
539,541|1383|Galen treasure maps|Open chests found using Galen treasure maps.|||||
540|1383|Preserver of Galen|Defeat the wandering Preserver of Galen boss.|||||
550|1383|Galen volcanic vents|Complete volcanic vents in Galen and loot the reward.|||||
551|1383|Grove of the Chimera|Defeat the Endling at Grove of the Chimera.|Grove of the Chimera||||
552|1383|Fauns' Thicket|Defeat Bahltur in Fauns' Thicket.|Fauns' Thicket||||
553|1383|Vastyr daily quests|Open Galen daily quest reward coffers.|Vastyr||||
554|108|City of Ash I|Defeat Razor Master Erthas in City of Ash I.||City of Ash I|||
555|1383|Embervine|Defeat Druid Rerlas in Embervine.|Embervine||||
556|1383|Galen phoenix moths|Harvest phoenix moths in Galen.|||||
581|1413,1414|Bastion Nymic|Loot the final reward chest after completing Bastion Nymic.|||||
582|1413,1414|Telvanni Peninsula / Apocrypha|Fish in Telvanni Peninsula or Apocrypha.|||||
583|41|Fungal Grotto II|Defeat Vila Theran in Fungal Grotto II.||Fungal Grotto II|||
584|849|Matus-Akin Egg Mine|Defeat Th'krak the Tunnel-King in Matus-Akin Egg Mine.|Matus-Akin Egg Mine||||
585|1414|Deepreave Quag|Defeat the boss at Deepreave Quag.|Deepreave Quag||||
586|1413|Telvanni Peninsula|Runestone nodes in Telvanni Peninsula|||||
587||Daily alchemy crafting writs|Open reward containers from daily alchemy crafting writs.|||||1
591|1413|Anchre Egg Mine|Defeat Zaedare the Afflicted in Anchre Egg Mine.|Anchre Egg Mine||||
592|1413|Telvanni Peninsula|Wood nodes in Telvanni Peninsula|||||
593|57|Lady Llarel's Shelter|Defeat Lady Llarel in Lady Llarel's Shelter.|Lady Llarel's Shelter||||
594|41|Fungal Grotto I|Defeat Kra'gh the Dreugh King in Fungal Grotto I.||Fungal Grotto I|||
595|1413,1414|Bastion Nymic|Loot section-boss chests inside Bastion Nymic.|||||
596|1414|Chthon Plaza|Defeat the boss at Chthon Plaza.|Chthon Plaza||||
597|1413|Necrom daily quests|Open Necrom daily quest reward coffers.|Necrom||||
644,645,646,709,710,711,712,713,714,715,716,717,718|1414|Infinite Archive|Loot Infinite Archive chests, Gw the Pilferer or Marauders.|Infinite Archive|Infinite Archive|||
779|1559|Night Market|Defeat Calamitous bosses in the Night Market, or complete the Opulent Ordeal.|||||
780|1559|Night Market|Open Glorious Night Market Reward Coffers from faction dailies, or complete the Opulent Ordeal.|||||
781|1559|Night Market|Defeat Night Market bosses, or complete the Opulent Ordeal.|||||
782|1559|Night Market|Defeat Calamitous Duneripper in the Night Market, or complete the Opulent Ordeal.|||||
783|1559,347|Night Market / Coldharbour|Defeat Brazen bosses in the Night Market, loot Coldharbour enemies, or complete the Opulent Ordeal.|||||
794,795,804,805,806,807,808,809,810,811,812,813||High Seas of Tamriel|Earn lead drops from High Seas of Tamriel event encounters and their rewards.|||||1
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
