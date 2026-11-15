-- Harvest classification adapted from BBCFrenzyHost by FoulMouthxAmazon.
-- Same thresholds and rune quiet-gap logic; independent namespace, no bounty chat spam.
SurveySidekickQuantityFilter = {}
local Q = SurveySidekickQuantityFilter
local ipairs, pairs, select, tostring = ipairs, pairs, select, tostring
local GetFrameTimeSeconds, zo_callLater = GetFrameTimeSeconds, zo_callLater
local table = table
local pending, sequence = {}, 0
local quietMilliseconds = 350
local function normalize(name)
    return tostring(name or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
end
local function isType(itemType, ...)
    for i=1,select("#",...) do local value=select(i,...) if value and itemType==value then return true end end
    return false
end
local function nameSet(names)
    local set={};for _,name in ipairs(names) do set[normalize(name)]=true end;return set
end
local rawNames=nameSet({
    "Iron Ore","Calcinium Ore","High Iron Ore","Orichalcum Ore","Dwarven Ore","Ebony Ore","Galatite Ore","Quicksilver Ore","Voidstone Ore","Rubedite Ore",
    "Rough Maple","Rough Oak","Rough Birch","Rough Ash","Rough Beech","Rough Hickory","Rough Yew","Rough Mahogany","Rough Nightwood","Rough Ruby Ash",
    "Raw Jute","Raw Flax","Raw Cotton","Raw Spidersilk","Raw Ebonthread","Raw Kreshweed","Raw Ironweed","Raw Silverweed","Raw Void Bloom","Raw Ancestor Silk",
    "Rawhide Scraps","Hide Scraps","Shadowhide Scraps","Thick Leather Scraps","Leather Scraps","Fell Hide Scraps","Topgrain Hide Scraps","Iron Hide Scraps","Rubedo Hide Scraps","Superb Hide Scraps",
    "Pewter Dust","Copper Dust","Silver Dust","Electrum Dust","Platinum Dust"
})
local baseNames=nameSet({"Natural Water","Clear Water","Pristine Water","Cleansed Water","Filtered Water","Purified Water","Cloud Mist","Star Dew","Lorkhan's Tears","Grease","Ichor","Slime","Gall","Terebinthine","Pitch-Bile","Tarblack","Night-Oil","Alkahest"})
local reagentNames=nameSet({
    "Blue Entoloma","Stinkhorn","Emetic Russula","Violet Coprinus","Namira's Rot","White Cap","Luminous Russula","Imp Stool",
    "Blessed Thistle","Lady's Smock","Wormwood","Bugloss","Corn Flower","Dragonthorn","Mountain Flower","Columbine","Nirnroot","Water Hyacinth","Nightshade",
    "Butterfly Wing","Torchbug Thorax","Spider Egg","Scrib Jelly","Mudcrab Chitin","Fleshfly Larva","Beetle Scuttle","Dragon's Bile","Dragon's Blood","Dragon Rheum",
    "Clam Gall","Powdered Mother of Pearl","Chaurus Egg","Vile Coagulant","Crimson Nirnroot","Cultivated Cryptpods","Daedra-Blood Maggots","Fossilized Verminous Bones","Winter's Grave Tongue","Winter's Grave Tongues"
})
local runeNames=nameSet({
    "Jejora","Odra","Pojora","Edora","Jaera","Pora","Denara","Rera","Derado","Rekura","Kura","Jode","Notade","Ode","Tade","Jayde","Edode","Pojode","Rekude","Hade","Idode","Pode","Kedeko","Rede","Kude","Jora","Porade","Jera","Jehade","Rejera","Itade","Repora",
    "Ta","Jejota","Denata","Rekuta","Kuta","Oko","Makko","Deni","Okoma","Makkoma","Denima","Kuoko","Rakeipa","Dekeipa","Meip","Haoko","Deteri","Okori","Jaedi","Lire","Oru","Taderi","Makderi","Kaderi","Hakeijo","Indeko"
})
function Q.Category(itemType,name)
    local key=normalize(name)
    -- Solvents are explicitly exempt, including when an item name is used as fallback.
    if baseNames[key] or isType(itemType,ITEMTYPE_POTION_BASE,ITEMTYPE_POISON_BASE) then return nil end
    if isType(itemType,ITEMTYPE_ENCHANTING_RUNE_ASPECT,ITEMTYPE_ENCHANTING_RUNE_ESSENCE,ITEMTYPE_ENCHANTING_RUNE_POTENCY) or runeNames[key] then return "Runes" end
    if isType(itemType,ITEMTYPE_BLACKSMITHING_RAW_MATERIAL,ITEMTYPE_CLOTHIER_RAW_MATERIAL,ITEMTYPE_WOODWORKING_RAW_MATERIAL,ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL) or rawNames[key] then return "Raw materials" end
    if isType(itemType,ITEMTYPE_REAGENT) or reagentNames[key] then return "Alchemy" end
    return nil
end
function Q.Limit(category)
    if category=="Alchemy" then return 3 end
    if category=="Runes" then return 6 end
    if category=="Raw materials" then return 9 end
end
local function sortedBatches()
    local batches={};for _,batch in pairs(pending) do batches[#batches+1]=batch end
    table.sort(batches,function(a,b) return a.sequence<b.sequence end)
    return batches
end
local function finish(batch)
    pending[batch.account]=nil
    local limit=Q.Limit("Runes")
    local blocked=batch.total>limit
    for _,entry in ipairs(batch.entries) do entry.callback(blocked,batch.total,limit) end
end
function Q.FlushReady()
    local now=GetFrameTimeSeconds()*1000
    for _,batch in ipairs(sortedBatches()) do
        if now-batch.lastAt+0.01>=quietMilliseconds then finish(batch) end
    end
end
function Q.FlushAll()
    for _,batch in ipairs(sortedBatches()) do finish(batch) end
end
function Q.QueueRunes(account,quantity,callback)
    local batch=pending[account]
    -- A delayed timer must not merge a later pickup after the quiet period.
    if batch and GetFrameTimeSeconds()*1000-batch.lastAt>=quietMilliseconds then
        finish(batch)
        batch=nil
    end
    if not batch then
        sequence=sequence+1
        batch={account=account,total=0,entries={},sequence=sequence,generation=0}
        pending[account]=batch
    end
    batch.total=batch.total+quantity
    batch.entries[#batch.entries+1]={callback=callback}
    batch.lastAt=GetFrameTimeSeconds()*1000
    batch.generation=batch.generation+1
    local generation=batch.generation
    zo_callLater(function()
        if pending[account]==batch and batch.generation==generation then Q.FlushReady() end
    end,quietMilliseconds)
end
