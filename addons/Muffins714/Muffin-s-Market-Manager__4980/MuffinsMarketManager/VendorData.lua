----------------------------------------------------------------------
-- Vendor Type Index
----------------------------------------------------------------------
-- Create a local shortcut for global
local MMM = MuffinsMarketManager

MMM.VendorTypes = {
    [1]  = { name = "Alchemist" },
    [2]  = { name = "Armorer" },
    [3]  = { name = "Armsman" },
    [4]  = { name = "Blacksmith", groupLabel = "Crafting Vendor" },
    [5]  = { name = "Brewer" },
    [6]  = { name = "Carpenter", groupLabel = "Crafting Vendor" },
    [7]  = { name = "Chef" },
    [8]  = { name = "Clothier", groupLabel = "Crafting Vendor" },
    [9]  = { name = "Enchanter" },
    [10] = { name = "General Goods" },
    [11] = { name = "Grocer" },
    [12] = { name = "Hall Steward" },
    [13] = { name = "Home Goods Furnisher" },
    [14] = { name = "Innkeeper" },
    [15] = { name = "Leatherworker" },
    [16] = { name = "Magus" },
    [17] = { name = "Merchant" },
    [18] = { name = "Mystic" },
    [19] = { name = "Siege Merchant" },
    [20] = { name = "Stylemaster" },
    [21] = { name = "Tailor" },
    [22] = { name = "Weaponsmith" },
    [23] = { name = "Woodworker" },
}

MMM.VendorMap = {
    -- LURE (itemType 16)
    -- [42877] = { vendorType = 14, price = 15 }, -- simple bait (Innkeeper)

    -- LOCKPICK (itemType 22)
    [30357] = { vendorType = 14, price = 9 }, -- Lockpick (Innkeeper)

    -- RECIPE (itemType 29)
    [119403] = { vendorType = 6, price = 270 },  -- Blueprint: Common Table, Slanted (Carpenter)
    [119367] = { vendorType = 6, price = 270 },  -- Blueprint: Common Washtub, Empty (Carpenter)
    [119344] = { vendorType = 6, price = 150 },  -- Blueprint: Rough Box, Boarded (Carpenter)
    [119348] = { vendorType = 6, price = 150 },  -- Blueprint: Rough Container, Cargo (Carpenter)
    [119342] = { vendorType = 6, price = 150 },  -- Blueprint: Rough Crate, Bolted (Carpenter)
    [119317] = { vendorType = 6, price = 150 },  -- Blueprint: Rough Crate, Reinforced (Carpenter)
    [119338] = { vendorType = 6, price = 150 },  -- Blueprint: Rough Platform, Stage (Carpenter)
    [121091] = { vendorType = 6, price = 270 },  -- Blueprint: Stool, Carved (Carpenter)
    [119391] = { vendorType = 7, price = 270 },  -- Design: Common Candle, Set (Chef)
    [119325] = { vendorType = 11, price = 150 }, -- Design: Rough Bag, Burlap (Grocer)
    [119389] = { vendorType = 4, price = 270 },  -- Diagram: Common Platter, Serving (Blacksmith)
    [119331] = { vendorType = 4, price = 150 },  -- Diagram: Rough Bowl, Common (Blacksmith)
    [121059] = { vendorType = 4, price = 150 },  -- Diagram: Rough Cup, Empty (Blacksmith)
    [119328] = { vendorType = 4, price = 150 },  -- Diagram: Rough Hatchet, Practical (Blacksmith)
    [119330] = { vendorType = 4, price = 150 },  -- Diagram: Rough Knife, Butcher (Blacksmith)
    [115908] = { vendorType = 8, price = 270 },  -- Pattern: Breton Bed, Bunk (Clothier)
    [119362] = { vendorType = 8, price = 270 },  -- Pattern: Common Basket, Tall (Clothier)
    [119350] = { vendorType = 8, price = 150 },  -- Pattern: Rough Bedroll, Basic (Clothier)
    [119314] = { vendorType = 8, price = 150 },  -- Pattern: Rough Stretcher, Military (Clothier)
    [46049] = { vendorType = 5, price = 1350 },  -- Recipe: Aetherial Tea (Brewer)
    [45899] = { vendorType = 7, price = 540 },   -- Recipe: Alik'r Beets with Goat Cheese (Chef)
    [46051] = { vendorType = 5, price = 1350 },  -- Recipe: Arenthian Brandy (Brewer)
    [45968] = { vendorType = 7, price = 1350 },  -- Recipe: Argonian Saddle-Cured Rabbit (Chef)
    [45889] = { vendorType = 7, price = 270 },   -- Recipe: Baked Apples (Chef)
    [45912] = { vendorType = 7, price = 270 },   -- Recipe: Baked Potato (Chef)
    [45913] = { vendorType = 7, price = 270 },   -- Recipe: Banana Surprise (Chef)
    [45984] = { vendorType = 5, price = 540 },   -- Recipe: Barley Nectar (Brewer)
    [45946] = { vendorType = 7, price = 540 },   -- Recipe: Battaglir Chowder (Chef)
    [46000] = { vendorType = 5, price = 540 },   -- Recipe: Bitterlemon Tea (Brewer)
    [46030] = { vendorType = 5, price = 1080 },  -- Recipe: Blue Road Marathon (Brewer)
    [45971] = { vendorType = 5, price = 270 },   -- Recipe: Bog-Iron Ale (Brewer)
    [45900] = { vendorType = 7, price = 540 },   -- Recipe: Breton Pork Sausage (Chef)
    [45887] = { vendorType = 7, price = 270 },   -- Recipe: Carrot Soup (Chef)
    [45935] = { vendorType = 7, price = 270 },   -- Recipe: Chicken Breast (Chef)
    [45929] = { vendorType = 7, price = 810 },   -- Recipe: Chorrol Corn on the Cob (Chef)
    [45907] = { vendorType = 7, price = 810 },   -- Recipe: Cinnamon Grape Jelly (Chef)
    [45972] = { vendorType = 5, price = 270 },   -- Recipe: Clarified Syrah Wine (Brewer)
    [46048] = { vendorType = 5, price = 1350 },  -- Recipe: Comely Wench Whiskey (Brewer)
    [45958] = { vendorType = 7, price = 1080 },  -- Recipe: Cyrodilic Cornbread (Chef)
    [45931] = { vendorType = 7, price = 810 },   -- Recipe: Cyrodilic Pumpkin Fritters (Chef)
    [45930] = { vendorType = 7, price = 810 },   -- Recipe: Elinhir Roast Antelope (Chef)
    [45974] = { vendorType = 5, price = 540 },   -- Recipe: Eltheric Hooch (Brewer)
    [68192] = { vendorType = 7, price = 1620 },  -- Recipe: Firsthold Fruit and Cheese Plate (Chef)
    [45888] = { vendorType = 7, price = 270 },   -- Recipe: Fishy Stick (Chef)
    [45982] = { vendorType = 5, price = 270 },   -- Recipe: Four-Eye Grog (Brewer)
    [45969] = { vendorType = 7, price = 1350 },  -- Recipe: Fresh Apples and Eidar Cheese (Chef)
    [45905] = { vendorType = 7, price = 810 },   -- Recipe: Garlic Mashed Potatoes (Chef)
    [45925] = { vendorType = 7, price = 540 },   -- Recipe: Garlic Pumpkin Seeds (Chef)
    [45993] = { vendorType = 5, price = 540 },   -- Recipe: Ginger Wheat Beer (Brewer)
    [45978] = { vendorType = 5, price = 1080 },  -- Recipe: Gods-Blind-Me (Brewer)
    [45988] = { vendorType = 5, price = 270 },   -- Recipe: Golden Lager (Brewer)
    [45992] = { vendorType = 5, price = 540 },   -- Recipe: Gossamer Mazte (Brewer)
    [46050] = { vendorType = 5, price = 1350 },  -- Recipe: Grandpa's Bedtime Tonic (Brewer)
    [45936] = { vendorType = 7, price = 270 },   -- Recipe: Grape Preserves (Chef)
    [68219] = { vendorType = 5, price = 1620 },  -- Recipe: Hagraven's Tonic (Brewer)
    [45953] = { vendorType = 7, price = 810 },   -- Recipe: Hare in Garlic Sauce (Chef)
    [68195] = { vendorType = 7, price = 1620 },  -- Recipe: Hearty Garlic Corn Chowder (Chef)
    [45975] = { vendorType = 5, price = 540 },   -- Recipe: Honey Rye (Brewer)
    [45952] = { vendorType = 7, price = 810 },   -- Recipe: Jerall View Inn Carrot Cake (Chef)
    [46052] = { vendorType = 5, price = 1350 },  -- Recipe: Khenarthi's Wings Chai (Brewer)
    [45990] = { vendorType = 5, price = 270 },   -- Recipe: Lemon Flower Mazte (Brewer)
    [68191] = { vendorType = 7, price = 1620 },  -- Recipe: Lilmoth Garlic Hagfish (Chef)
    [45959] = { vendorType = 7, price = 1080 },  -- Recipe: Mammoth Snout Pie (Chef)
    [46002] = { vendorType = 5, price = 810 },   -- Recipe: Maormer Tea (Brewer)
    [68213] = { vendorType = 5, price = 1620 },  -- Recipe: Markarth Mead (Brewer)
    [45981] = { vendorType = 5, price = 270 },   -- Recipe: Mazte (Brewer)
    [45985] = { vendorType = 5, price = 540 },   -- Recipe: Mermaid Whiskey (Brewer)
    [45965] = { vendorType = 7, price = 1350 },  -- Recipe: Millet-Stuffed Pork Loin (Chef)
    [45994] = { vendorType = 5, price = 810 },   -- Recipe: Mulled Wine (Brewer)
    [68216] = { vendorType = 5, price = 1620 },  -- Recipe: Muthsera's Remorse (Brewer)
    [45995] = { vendorType = 5, price = 810 },   -- Recipe: Nereid Wine (Brewer)
    [45923] = { vendorType = 7, price = 540 },   -- Recipe: Nibenese Garlic Carrots (Chef)
    [45970] = { vendorType = 5, price = 270 },   -- Recipe: Nut Brown Ale (Brewer)
    [45966] = { vendorType = 7, price = 1350 },  -- Recipe: Orcrest Garlic Apple Jelly (Chef)
    [45901] = { vendorType = 7, price = 540 },   -- Recipe: Pellitine Tomato Rice (Chef)
    [45967] = { vendorType = 7, price = 1350 },  -- Recipe: Pickled Carrot Slurry (Chef)
    [45980] = { vendorType = 5, price = 270 },   -- Recipe: Red Rye Beer (Brewer)
    [45948] = { vendorType = 7, price = 540 },   -- Recipe: Redoran Peppered Melon (Chef)
    [45934] = { vendorType = 7, price = 270 },   -- Recipe: Roast Corn (Chef)
    [45977] = { vendorType = 5, price = 810 },   -- Recipe: Rye-in-your-Eye (Brewer)
    [46018] = { vendorType = 5, price = 540 },   -- Recipe: Seaflower Tea (Brewer)
    [45906] = { vendorType = 7, price = 810 },   -- Recipe: Senchal Curry Fish and Rice (Chef)
    [46053] = { vendorType = 5, price = 1350 },  -- Recipe: Sipping Imga Tonic (Brewer)
    [45960] = { vendorType = 7, price = 1080 },  -- Recipe: Skyrim Jazbay Crostata (Chef)
    [45987] = { vendorType = 5, price = 810 },   -- Recipe: Sorry, Honey Lager (Brewer)
    [45976] = { vendorType = 5, price = 810 },   -- Recipe: Sour Mash (Brewer)
    [46012] = { vendorType = 5, price = 810 },   -- Recipe: Spiceberry Chai (Brewer)
    [45986] = { vendorType = 5, price = 810 },   -- Recipe: Spiced Mazte (Brewer)
    [45954] = { vendorType = 7, price = 810 },   -- Recipe: Stormhold Baked Bananas (Chef)
    [45989] = { vendorType = 5, price = 270 },   -- Recipe: Surilie Syrah Wine (Brewer)
    [46020] = { vendorType = 5, price = 810 },   -- Recipe: Torval Mint Tea (Brewer)
    [46010] = { vendorType = 5, price = 540 },   -- Recipe: Treacleberry Tea (Brewer)
    [46004] = { vendorType = 5, price = 1080 },  -- Recipe: Two-Zephyr Tea (Brewer)
    [45947] = { vendorType = 7, price = 540 },   -- Recipe: Venison Pasty (Chef)
    [45964] = { vendorType = 7, price = 1350 },  -- Recipe: West Weald Corn Chowder (Chef)
    [45924] = { vendorType = 7, price = 540 },   -- Recipe: Whiterun Cheese-Baked Trout (Chef)

    -- STYLE MAT (itemType 44)
    [33252] = { vendorType = 4, price = 15 }, -- Adamantite (Blacksmith)
    [33194] = { vendorType = 4, price = 15 }, -- Bone (Blacksmith)
    [33256] = { vendorType = 4, price = 15 }, -- Corundum (Blacksmith)
    [33257] = { vendorType = 4, price = 15 }, -- Manganese (Blacksmith)
    [33251] = { vendorType = 4, price = 15 }, -- Molybdenum (Blacksmith)
    [33255] = { vendorType = 4, price = 15 }, -- Moonstone (Blacksmith)
    [33254] = { vendorType = 4, price = 15 }, -- Nickel (Blacksmith)
    [33253] = { vendorType = 4, price = 15 }, -- Obsidian (Blacksmith)
    [33258] = { vendorType = 4, price = 15 }, -- Starmetal (Blacksmith)
    [33150] = { vendorType = 4, price = 15 }, -- flint (Blacksmith)

    -- AVA REPAIR (itemType 47)
    [204483] = { vendorType = 19, price = 90 }, -- Cyrodiil Repair Kit (Siege Merchant)

    -- ENCHANTING (itemType 51)
    [45812] = { vendorType = 16, price = 87 },   -- Denara (Magus)
    [45814] = { vendorType = 16, price = 96 },   -- Derado (Magus)
    [45822] = { vendorType = 16, price = 66 },   -- Edode (Magus)
    [45809] = { vendorType = 16, price = 72 },   -- Edora (Magus)
    [45825] = { vendorType = 16, price = 84 },   -- Hade (Magus)
    [45826] = { vendorType = 16, price = 87 },   -- Idode (Magus)
    [68340] = { vendorType = 16, price = 2508 }, -- Itade (Magus)
    [45810] = { vendorType = 16, price = 78 },   -- Jaera (Magus)
    [45821] = { vendorType = 16, price = 60 },   -- Jayde (Magus)
    [64508] = { vendorType = 16, price = 111 },  -- Jehade (Magus)
    [45806] = { vendorType = 16, price = 54 },   -- Jejora (Magus)
    [45857] = { vendorType = 16, price = 51 },   -- Jera (Magus)
    [45817] = { vendorType = 16, price = 30 },   -- Jode (Magus)
    [45855] = { vendorType = 16, price = 30 },   -- Jora (Magus)
    [45828] = { vendorType = 16, price = 96 },   -- Kedeko (Magus)
    [45830] = { vendorType = 16, price = 105 },  -- Kude (Magus)
    [45816] = { vendorType = 16, price = 105 },  -- Kura (Magus)
    [45818] = { vendorType = 16, price = 42 },   -- Notade (Magus)
    [45819] = { vendorType = 16, price = 51 },   -- Ode (Magus)
    [45807] = { vendorType = 16, price = 60 },   -- Odra (Magus)
    [45827] = { vendorType = 16, price = 93 },   -- Pode (Magus)
    [45823] = { vendorType = 16, price = 72 },   -- Pojode (Magus)
    [45808] = { vendorType = 16, price = 66 },   -- Pojora (Magus)
    [45811] = { vendorType = 16, price = 84 },   -- Pora (Magus)
    [45856] = { vendorType = 16, price = 42 },   -- Porade (Magus)
    [45829] = { vendorType = 16, price = 99 },   -- Rede (Magus)
    [64509] = { vendorType = 16, price = 111 },  -- Rejera (Magus)
    [45824] = { vendorType = 16, price = 78 },   -- Rekude (Magus)
    [45815] = { vendorType = 16, price = 99 },   -- Rekura (Magus)
    [68341] = { vendorType = 16, price = 2508 }, -- Repora (Magus)
    [45813] = { vendorType = 16, price = 93 },   -- Rera (Magus)
    [45820] = { vendorType = 16, price = 54 },   -- Tade (Magus)
}

----------------------------------------------------------------------
-- Furnishing Vendor Map
----------------------------------------------------------------------
MMM.FurnishingMap = {

    -- Alik'r Desert
    [118168] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 500 }, -- Block, Carved Stone
    [117955] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Box, Slatted
    [117959] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Container, Shipping
    [117931] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate Lid
    [117957] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate, Cracked
    [117958] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate, Empty
    [117930] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate, Open
    [117953] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate, Sealed
    [117928] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Crate, Sturdy
    [117986] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Plank, Long
    [117987] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Planks, Narrow
    [117989] = { npcName = "Rohzika", zone = "Kozanset, Alik'r Desert", price = 100 }, -- Rough Planks, Wide

    -- Auridon
    [120652] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Boulder, Flat Lichen
    [120651] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Boulder, Grey Saddle
    [120648] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Boulder, Lichen Covered
    [120672] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 1000 },  -- Hedge, Green Short
    [120673] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 2500 },  -- Hedge, Large Horseshoe
    [120671] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 1250 },  -- Hedge, Small Horseshoe
    [120674] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 1250 },  -- Hedge, Tall Green
    [121005] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 3000 },  -- Hedge, Wall Arc
    [120653] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Rock, Slanted Lichen
    [120663] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Saplings, Healthy Forest
    [120662] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Saplings, Squat Forest
    [120661] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Saplings, Young Forest
    [120655] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Stone, Slanted Lichen
    [120654] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Stone, Slanted Rough
    [120656] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 },   -- Stones, Gray Mossy
    [120675] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 2000 },  -- Topiary, Manicured Evergreen
    [120676] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 1000 },  -- Topiary, Pruned Evergreen
    [120658] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 250 },   -- Tree, Forked Sturdy
    [120668] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 10000 }, -- Tree, Squat Pink Cherry
    [120669] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 10000 }, -- Tree, Squat White Cherry
    [120670] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 250 },   -- Tree, Sturdy Jungle
    [120664] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 15000 }, -- Tree, Tiered Light Cherry
    [120665] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 15000 }, -- Tree, Tiered Pink Cherry
    [120666] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 25000 }, -- Tree, Tiered White Cherry
    [120657] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 15000 }, -- Tree, Twisted Pink Cherry
    [120667] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 12000 }, -- Tree, Twisted White Cherry
    [120659] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 250 },   -- Trees, Crooked Swamp

    -- Bal Foyen
    [120622] = { npcName = "Frohilde Snow-Hair", zone = "Dhalmora, Bal Foyen", price = 600 }, -- Vines, Clustered Ivy

    -- Bangkorai
    [120449] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Bush, Desert Scrub
    [120461] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 500 }, -- Cactus, Desert Vine
    [120457] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Pebble, Smooth Desert
    [120452] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Pebble, Smooth Grey
    [120460] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Plant, Green Water
    [120450] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Plant, Squat Yucca
    [120462] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Plant, Tall Flowering Yucca
    [120440] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Rocks, Scattered Weathered
    [120454] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Rocks, Stacked Desert
    [120438] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Rocks, Stacked Weathered
    [120459] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Shrub, Browncrub
    [120458] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 250 }, -- Shrub, Speckled Forest
    [120451] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Stone, Smooth Grey
    [120455] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Stone, Tapered Desert
    [120439] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Stone, Tapered Weathered
    [120453] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 250 }, -- Tree, Hardened Juniper
    [120448] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Tree, Old Juniper
    [120445] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Tree, Sturdy Juniper
    [120446] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Tree, Young Juniper
    [120441] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 }, -- Saplings, Short Highland

    -- Blackwood
    [175725] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 250 },  -- Leyawiin Carpet, Small Worn
    [175723] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 350 },  -- Leyawiin Carpet, Threadbare
    [175727] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 2000 }, -- Leyawiin Palisade, Reinforced
    [175724] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 350 },  -- Leyawiin Rug, Worn
    [175722] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 75 },   -- Leyawiin Socks, Pair
    [175721] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 100 },  -- Leyawiin Trousers, Strewn
    [175720] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 250 },  -- Leyawiin Wheel, Splintered Axle
    [175774] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 4000 }, -- Leyawiin Windowbox, Irises
    [175773] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 4500 }, -- Leyawiin Windowbox, Yellow Daisies
    [175771] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 300 },  -- Tree, Bent Blackwood Elm
    [175770] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 1000 }, -- Tree, Branching Blackwood Pine
    [175772] = { npcName = "Barnabe Cariveau", zone = "Leyawiin, Blackwood", price = 350 },  -- Tree, Forked Blackwood Elm

    -- Coldharbour
    [130273] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 5000 }, -- Boulder, Coldharbour Fan
    [130274] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 5000 }, -- Boulder, Coldharbour Shard
    [130275] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 5000 }, -- Boulder, Coldharbour Spikes
    [130276] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 250 },  -- Rocks, Coldharbour Cluster
    [131421] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 250 },  -- Saplings, Withered Thicket
    [130279] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 2500 }, -- Tree, Petrified Ashen
    [130278] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 5000 }, -- Tree, Strong Withered
    [130277] = { npcName = "Krrztrrb", zone = "The Hollow City, Coldharbour", price = 5000 }, -- Tree, Towering Withered

    -- Craglorn
    [120964] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Boulder, Craggy Heap
    [120963] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Boulder, Jagged Crag
    [120552] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Bush, Flowering Scrub
    [120555] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Flowers, Healthy Goldenrod
    [120551] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Plant, Healthy Sage
    [120977] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Plant, Strong Sage
    [120966] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Rock, Craggy Rubble
    [120539] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Rock, Jagged Craggy
    [120973] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Sapling, Cliffside
    [120983] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Sapling, Mountain
    [120971] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Sapling, Tall Scrub
    [120553] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Sapling, Young Scrub
    [120972] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Saplings, Desert
    [120976] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Saplings, Juniper Cluster
    [120981] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Shrub, Desert Scrub
    [120967] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Stone, Angled Grey
    [120975] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Tree, Angled Ash
    [120543] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 6000 },  -- Tree, Blooming Crabapple
    [120548] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Tree, Heavy Ash
    [120549] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Tree, Large Twisted Ash
    [120547] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Tree, Leaning Ash
    [120970] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 13000 }, -- Tree, Sturdy Crabapple
    [120545] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Tree, Sturdy Summer
    [120974] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 100 },   -- Tree, Twisted
    [120550] = { npcName = "Krrztrrb", zone = "Belkarth, Craglorn", price = 250 },   -- Trees, Paired Evergreens

    -- Deshaan
    [120567] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 250 }, -- Bush, Vibrant Barberry
    [120566] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Fern Plant, Healthy Green
    [120574] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 250 }, -- Mushroom, Huge Chanterelle
    [120568] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 250 }, -- Mushrooms, Tall Chanterelle
    [120571] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Pebble, Stacked Grey
    [120564] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Pebbles, Stacked Weathered
    [120572] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Rocks, Jagged Set
    [120563] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Stone, Jagged Grey
    [120570] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 100 }, -- Stone, Slanted Grey

    -- Eastmarch
    [132215] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Boulder, Granite Cap
    [132213] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Boulder, Granite Chunk
    [132214] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Boulder, Granite Slab
    [132211] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Ferns, Mountain Cluster
    [132217] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Rock, Granite Chunk
    [117978] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 100 },  -- Rough Rod, Fishing
    [117979] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 100 },  -- Rough Spear, Fishing
    [132209] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Sapling, Foothills Pine
    [132212] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Shrub, Mountain Thistle
    [132220] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Stones, Granite Cluster
    [132219] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Stones, Granite Group
    [132218] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Stones, Granite Pair
    [132210] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 2500 }, -- Tree, Ancient Cedar
    [132207] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Tree, Ancient Mountain Pine
    [132208] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Tree, Foothills Pine
    [132205] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 250 },  -- Tree, Hardy Cedar
    [132206] = { npcName = "Frohilde Snow-Hair", zone = "Fort Amol, Eastmarch", price = 1000 }, -- Tree, Towering Mountain Pine

    -- Fargrave
    [181598] = { npcName = "Nif", zone = "Fargrave", price = 300 }, -- Bush, Low Redleaf Cluster
    [181597] = { npcName = "Nif", zone = "Fargrave", price = 300 }, -- Bush, Sharp Underbrush
    [134942] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Bushes, Withered Cluster
    [182213] = { npcName = "Nif", zone = "Fargrave", price = 250 }, -- Fargrave Canopy
    [182217] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Fargrave Clutter, Papers
    [182220] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Fargrave Flag, Long
    [182218] = { npcName = "Nif", zone = "Fargrave", price = 85 },  -- Fargrave Flag, Regular
    [182219] = { npcName = "Nif", zone = "Fargrave", price = 75 },  -- Fargrave Flag, Short
    [182214] = { npcName = "Nif", zone = "Fargrave", price = 300 }, -- Fargrave Flags, String
    [182215] = { npcName = "Nif", zone = "Fargrave", price = 250 }, -- Fargrave Pennants, Long String
    [182216] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Fargrave Pennants, String
    [181593] = { npcName = "Nif", zone = "Fargrave", price = 250 }, -- Log, Charred Oak
    [125616] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Pebble, Volcanic Chunk
    [181596] = { npcName = "Nif", zone = "Fargrave", price = 300 }, -- Plant Cluster, Maroon Aloe
    [181595] = { npcName = "Nif", zone = "Fargrave", price = 500 }, -- Plant, Harrada Root
    [181594] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Rock, Volcanic Boulder
    [181587] = { npcName = "Nif", zone = "Fargrave", price = 250 }, -- Tree, Charred Oak
    [181592] = { npcName = "Nif", zone = "Fargrave", price = 500 }, -- Tree, Deadlands Pine
    [181588] = { npcName = "Nif", zone = "Fargrave", price = 400 }, -- Tree, Old Charred Oak
    [181591] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Tree, Short Charred Pine
    [181590] = { npcName = "Nif", zone = "Fargrave", price = 250 }, -- Tree, Tall Charred Pine
    [181589] = { npcName = "Nif", zone = "Fargrave", price = 100 }, -- Tree, Young Charred Oak

    -- Galen
    [187780] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 200 },  -- Boulder, Large Mossy Limestone
    [187779] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 100 },  -- Boulder, Small Limestone
    [192400] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 4500 }, -- Druidic Planter, Sunflowers
    [187814] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 1000 }, -- Flowers, Butterweed
    [187783] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 3000 }, -- Flowers, Daylily Cluster
    [192399] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 300 },  -- Flowers, Galen Sea Daffodil
    [192396] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 400 },  -- Flowers, Sunflower Cluster
    [192395] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 4000 }, -- Flowers, Sunflower Patch
    [192398] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 125 },  -- Plant, Galen Agave
    [192394] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 200 },  -- Sapling, Galen Beech
    [187784] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 2000 }, -- Shrub Cluster, Gorse
    [187856] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 2500 }, -- Tree, Conical Cypress
    [187782] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 700 },  -- Tree, Forked Cypress
    [192393] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 3500 }, -- Tree, Large Galen Beech
    [192397] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 425 },  -- Tree, Large Galen Pine
    [187781] = { npcName = "Ormax Lemaitre", zone = "Gonfalon Bay, Galen", price = 3000 }, -- Tree, Tall Conical Cypress

    -- Glenumbra
    -- These are achievement furnitures
    --[[
    [126649] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 50000 },  -- Banner of the Fire Drakes
    [126712] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 50000 },  -- Banner of the Pit Daemons
    [126650] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 50000 },  -- Banner of the Storm Lords
    [126646] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 25000 },  -- Standard of the Fire Drakes
    [126648] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 25000 },  -- Standard of the Pit Daemons
    [126647] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 25000 },  -- Standard of the Storm Lords
    [126713] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 100000 }, -- Tapestry of the Fire Drakes
    [126715] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 100000 }, -- Tapestry of the Pit Daemons
    [126714] = { npcName = "Fabio Previa", zone = "Glenumbra", price = 100000 }, -- Tapestry of the Storm Lords
    ]]
    -------------------------
    [225031] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 500 },   -- Boulder, Angular Mossy Striated
    [120706] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Boulder, Giant Mossy
    [120705] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Boulder, Mossy Grey
    [120707] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Boulder, Mossy Weathered
    [225030] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 500 },   -- Boulder, Round Mossy Striated
    [130309] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Boulder, Swampy Growth
    [225029] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Boulders, Mossy Cluster
    [224922] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Breton Panel, Wood
    [224921] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Breton Support Beam, Wood
    [225034] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 20000 }, -- Cave Doorway, Mossy Vine-Covered
    [132221] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 5000 },  -- Lily Pads, Swamp Cluster
    [130287] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Log, Fallen Laurel
    [130288] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Log, Fallen Pine
    [130286] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Log, Rotten Bog
    [225032] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Logs, Unprocessed
    [120708] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Rocks, Craggy Set
    [130307] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Rocks, Swampy Slab
    [224880] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 50 },    -- Rope, Short Twisted
    [224882] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 50 },    -- Rope, Thin Knotted
    [224879] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Rope, Twisted
    [225036] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 450 },   -- Rough Crates, Cargo Shipment
    [225037] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 300 },   -- Rough Crates, Stack
    [225035] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 2000 },  -- Ruined Floor, Stonework
    [120711] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Sapling, Young Birch
    [120716] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Saplings, Autumn Cluster
    [130304] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Saplings, Marsh Cluster
    [120717] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Shrub, Autumn Forest
    [120718] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Shrub, Dense Forest
    [130303] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Shrub, Swamp Sprig
    [120720] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Shrubs, Small Berry
    [130305] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Stone, Mossy Swamp
    [130306] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Stones, Gray Swampy
    [225038] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 300 },   -- Stones, Loose Rubble
    [130292] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Stump, Fetid Swamp
    [130289] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Stump, Mossy Cypress
    [130290] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Stump, Rotten Hollow
    [130291] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Stump, Rotten Pine
    [130315] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 7500 },  -- Tree, Ancient Rotten
    [130310] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 7500 },  -- Tree, Dead Marsh
    [130312] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 2500 },  -- Tree, Dead Pine
    [130311] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 5000 },  -- Tree, Dead Swamp
    [225033] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 25000 }, -- Tree, Giant Climbing Wyrdbloom
    [130313] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 5000 },  -- Tree, Gnarled Marsh
    [120713] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 250 },   -- Tree, Towering Autumn Birch
    [130314] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 2500 },  -- Tree, Withered Marsh
    [121011] = { npcName = "Rohzika", zone = "Daggerfall, Glenumbra", price = 100 },   -- Trees, Young Autumn Birch

    -- Grahtwood
    [120725] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Boulder, Mossy Crag
    [117984] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Dark Stone
    [117983] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Light Stone
    [117995] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Stone Brick
    [117993] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Stone Chunk
    [117992] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Stone Section
    [117961] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Block, Woodcutter's
    [117985] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Bread, Morsel
    [117965] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Campfire, Doused
    [117968] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Clothesline, Full
    [117970] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Clothesline, Half
    [117969] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Clothesline, Long
    [117972] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Clothesline, Short
    [117973] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Crate, Dry
    [117964] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Firepit, Doused
    [117981] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Firewood, Smoldering
    [117976] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Hay Bed, Covered
    [117975] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Hay Bed, Sloppy
    [117974] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Hay Bed, Tidy
    [117988] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Planks, Platform
    [117966] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Tarp, Oversized
    [117967] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Rough Tarp, Standard
    [121285] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 25000 }, -- Tree, Ancient Banyan
    [121286] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 5000 },  -- Tree, Giant Cypress
    [121287] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 5000 },  -- Tree, Towering Cypress
    [119578] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 100 },   -- Tree, Towering Palm Cluster
    [120741] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 250 },   -- Tree, Towering Wax Palm
    [120742] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 25000 }, -- Tree, Twisted Banyan
    [121288] = { npcName = "Maladdiq", zone = "Redfur Trading Post, Grahtwood", price = 250 },   -- Trees, Mossy Murkmire Cluster

    -- Greenshade
    [120587] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Boulder, Flat Grey
    [120586] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Boulder, Moss Covered
    [120597] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Fern Plant, Vibrant
    [120599] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Fern, Healthy Green
    [120595] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Fern, Lush
    [120600] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Fern, Young Healthy
    [120598] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Plants, Low Weeds
    [120588] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Rock, Slanted Algae
    [120590] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Rocks, Smooth Set
    [120592] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Saplings, Highland Cluster
    [120593] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Saplings, Twin Highland
    [120589] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 100 }, -- Stone, Slanted Weathered
    [120591] = { npcName = "Maladdiq", zone = "Marbruk, Greenshade", price = 250 }, -- Tree, Vibrant Privet

    -- High Isle
    [165809] = { npcName = "Miruza", zone = "Gonfalon Bay, High Isle", price = 250 }, -- Firelogs, White Pine
    [165810] = { npcName = "Miruza", zone = "Gonfalon Bay, High Isle", price = 750 }, -- Logs, Twice-Split
    [187780] = { npcName = "Miruza", zone = "Gonfalon Bay, High Isle", price = 200 }, -- Boulder, Large Mossy Limestone
    [187779] = { npcName = "Miruza", zone = "Gonfalon Bay, High Isle", price = 100 }, -- Boulder, Small Limestone

    -- Malabal Tor
    [120529] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern Cluster, Healthy
    [120531] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern Fronds, Healthy Green
    [120530] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern Fronds, Sunburnt
    [120527] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern Plant, Green Curly
    [120528] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern Plant, Sturdy Mature
    [120640] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern, Budding Forest
    [120641] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Fern, Low Red
    [120642] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Mushroom, Brown Gilled
    [120534] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 250 }, -- Mushrooms, Bruising Webcap
    [120532] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Mushrooms, Poison Pax Cluster
    [120533] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Mushrooms, Poison Pax Group
    [120638] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Rock, Slanted Weathered
    [120523] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Rocks, Mossy Cluster
    [120524] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Rocks, Mossy Set
    [120639] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 100 }, -- Stones, Smooth Mossy
    [120525] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 250 }, -- Tree, Mossy Swamp
    [120643] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 750 }, -- Vines, Curtain Ivy
    [120645] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 750 }, -- Vines, Draped Ivy
    [120644] = { npcName = "Maladdiq", zone = "Vulkwasten, Malabal Tor", price = 600 }, -- Vines, Lush Ivy

    -- Murkmire
    [145551] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 450 },  -- Murkmire Kiln, Derelict
    [145414] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 250 },  -- Plant Cluster, Marsh Saplings
    [145557] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 350 },  -- Plant Cluster, Spadeleaf
    [145417] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 250 },  -- Plant, Bramblebrush
    [145413] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 350 },  -- Plant, Marsh Palm
    [145419] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 400 },  -- Plant, Marshfrond
    [145547] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 1250 }, -- Plant, Moorstalk Hive
    [145416] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 300 },  -- Plant, Purple Spadeleaf
    [145420] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 400 },  -- Plant, Thorny Swamp Lily
    [145418] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 250 },  -- Plant, Young Marshfrond
    [145425] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 250 },  -- Rock, Mossy Marsh
    [145424] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 750 },  -- Rocks, Mossy Marsh Cluster
    [145422] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 450 },  -- Tree Cluster, Young Sycamore
    [145421] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 350 },  -- Tree, Marsh Cypress
    [145423] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 4000 }, -- Tree, Mire Mangrove
    [145415] = { npcName = "Adosa Veralor", zone = "Lilmoth, Murkmire", price = 2000 }, -- Tree, Mossy Sycamore

    -- Reaper's March
    [120511] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Bush, Mountain Scrub
    [120690] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Fern Plant, Hardy
    [120510] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Fern Plant, Sturdy Towering
    [120512] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Fern, Fragile
    [120521] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Fern, Withering
    [120691] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Fern, Young Sunburnt
    [120703] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 4000 }, -- Khajiit Column, Spiked
    [120561] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Plant, Jungle Leaf
    [120697] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Plant, Leafy Sprouts
    [120560] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Plant, Squat Jungle Leaf
    [120562] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Plant, Towering Jungle Leaf
    [120699] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 250 },  -- Platform, Weathered Dock
    [120700] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Post, Barnacle Covered
    [120558] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Sapling, Eucalyptus Scrub
    [120515] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Shrub, Lanky Highland
    [120522] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 100 },  -- Shrub, Tender Privet
    [121282] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 5000 }, -- Tree, Ancient Jungle
    [121283] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 250 },  -- Tree, Healthy Jungle
    [120519] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 250 },  -- Tree, Healthy Privet
    [120687] = { npcName = "Maladdiq", zone = "Rawl'kha, Reaper's March", price = 250 },  -- Tree, Sturdy Shade

    -- Rivenspire
    [120580] = { npcName = "Rohzika", zone = "Shornhelm, Rivenspire", price = 250 }, -- Flower, Healthy Hibiscus
    [120579] = { npcName = "Rohzika", zone = "Shornhelm, Rivenspire", price = 250 }, -- Flower, Stout Hibiscus
    [120576] = { npcName = "Rohzika", zone = "Shornhelm, Rivenspire", price = 100 }, -- Sapling, Fragile Aspen
    [120578] = { npcName = "Rohzika", zone = "Shornhelm, Rivenspire", price = 100 }, -- Sapling, Young Aspen

    -- Shadowfen
    [120630] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Pebble, Stacked Lichen
    [120631] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Pebble, Stacked Mossy
    [120632] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Pebbles, Stacked Mossy
    [120637] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Plant, Dry Spike
    [120627] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Rocks, Stacked Angular
    [120628] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Stone, Slanted Mossy
    [120629] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 100 }, -- Stone, Smooth Mossy
    [120636] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 250 }, -- Tree, Mud Palm
    [120634] = { npcName = "Frohilde Snow-Hair", zone = "Alten Corimont, Shadowfen", price = 250 }, -- Tree, Towering Swamp Palm

    -- Solstice
    [220347] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 20000 }, -- Amethyst Crystals, Purple Patch
    [220346] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 5000 },  -- Amethyst Crystals, Small Purple Patch
    [220348] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 20000 }, -- Amethyst Crystals, Small Teal Patch
    [220349] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 5000 },  -- Amethyst Crystals, Teal Cluster
    [214496] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 500 },   -- Boulder, Horizontal Sandstone
    [214495] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 500 },   -- Boulder, Vertical Sandstone
    [214498] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 3000 },  -- Clam Shell, Large
    [214497] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 3000 },  -- Conch, Large Spiny
    [220362] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 250 },   -- Debris Pile, Sea-Tossed Flotsam
    [214500] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 500 },   -- Driftwood, Large Gnarled
    [214501] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 250 },   -- Driftwood, Large Trunk
    [220353] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 450 },   -- Driftwood, Spindly
    [217631] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 450 },   -- Flower Curtain, Summertide
    [217630] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 1500 },  -- Flower Patch, Summertide
    [214511] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 2500 },  -- Flowering Gorse, Purple
    [217629] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 450 },   -- Flowers, Climbing Summertide
    [217628] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 1500 },  -- Flowers, Large Climbing Summertide
    [214512] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 250 },   -- Grass, Beach Cluster
    [220357] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 400 },   -- Mammoth Grass, Patch
    [214510] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 500 },   -- Plant Cluster, Majesty Palm
    [220356] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 25000 }, -- Plant Cluster, Tamanu
    [214509] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 350 },   -- Plant, Majesty Palm
    [220352] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 500 },   -- Platform, Cut Stone
    [214499] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 450 },   -- Sapling, Banana
    [220358] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 3000 },  -- Sapling, Magenta Summertide
    [214507] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 300 },   -- Sapling, Royal Palm
    [214508] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 350 },   -- Sapling, Sierra Palm
    [214503] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 300 },   -- Sapling, Thatch Palm
    [220360] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 4000 },  -- Sapling, Violet Branched Summertide
    [220361] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 3500 },  -- Sapling, Violet Leaning Summertide
    [220359] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 3500 },  -- Saplings, Magenta Summertide Cluster
    [214493] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 90000 }, -- Solstice Bismuth, Gigantic Deposit I
    [214494] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 90000 }, -- Solstice Bismuth, Gigantic Deposit II
    [220351] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 1000 },  -- Southern Sea Trilobite Shell, Large
    [220350] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 300 },   -- Stones, Limestone Cluster
    [220354] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 5000 },  -- Tree, Flowering Red Poinsettia
    [214505] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 4500 },  -- Tree, Gigantic Water Chestnut
    [214504] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 4500 },  -- Tree, Large Water Chestnut
    [214506] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 1000 },  -- Tree, Royal Palm
    [220355] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 5000 },  -- Tree, Sturdy Tamanu
    [214502] = { npcName = "Sabione Adrard", zone = "Sunport, Solstice", price = 1000 },  -- Tree, Thatch Palm

    -- Southern Elsweyr
    [151821] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 150 },  -- Desert Grass, Patch
    [151820] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Desert Grass, Tall
    [151804] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Elsweyr Pillar, Rough Wooden
    [151805] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 350 },  -- Elsweyr Rack, Poles
    [151803] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 250 },  -- Elsweyr Wagon Wheel, Ironshod
    [151819] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 350 },  -- Flower Patch, Prairie-Fire
    [151817] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 250 },  -- Flowers, Daedra Thorn
    [151815] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 250 },  -- Flowers, Desert Sunrise
    [153684] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Plant Cluster, Keet Fern
    [153681] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 150 },  -- Plant Cluster, Palmetto
    [153680] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 300 },  -- Plant Cluster, Tenmar Dija
    [153683] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 150 },  -- Plant Cluster, Zahmia
    [151816] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Plant, Flowering Thorned Succulent
    [153682] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Plant, Tropical Bush
    [151807] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Rock Field, Ancient Stone
    [151806] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Rubble Pile, Ancient Stone
    [151813] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 350 },  -- Sapling, Desert Acacia
    [151818] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 250 },  -- Shrub, Yellow Necklacepod
    [153679] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 400 },  -- Tree, Anequine Acacia Arching
    [153688] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 300 },  -- Tree, Anequine Acacia Forking
    [151810] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 400 },  -- Tree, Branched Succulent
    [151814] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 550 },  -- Tree, Desert Acacia
    [151812] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 350 },  -- Tree, Engulfing Termite Mound
    [151808] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 100 },  -- Tree, Fan Palm
    [151811] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 400 },  -- Tree, Tall Iroko
    [151809] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 250 },  -- Trees, Fan Palm Cluster
    [153677] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 400 },  -- Trees, Shade Palm Cluster
    [153678] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 400 },  -- Trees, Towering Palm Cluster
    [151823] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 300 },  -- Vines, Dragonfire Ivy Climber
    [151822] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 450 },  -- Vines, Dragonfire Ivy Swath
    [156677] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 750 },  -- Vines, Verdant Ivy Climber
    [156678] = { npcName = "Zadraska", zone = "Senchal, Southern Elsweyr", price = 1250 }, -- Vines, Verdant Ivy Swath

    -- Stonefalls
    [121028] = { npcName = "Frohilde Snow-Hair", zone = "Ebonheart, Stonefalls", price = 1300 },  -- Hedge, Dense Low Wall
    [120680] = { npcName = "Frohilde Snow-Hair", zone = "Ebonheart, Stonefalls", price = 2500 },  -- Topiary, Fragile Cypress
    [120681] = { npcName = "Frohilde Snow-Hair", zone = "Ebonheart, Stonefalls", price = 1100 },  -- Topiary, Pruned Cypress
    [120677] = { npcName = "Frohilde Snow-Hair", zone = "Ebonheart, Stonefalls", price = 15000 }, -- Tree, Autumn Cherry Blossom

    -- Stormhaven
    [120582] = { npcName = "Rohzika", zone = "Wayrest, Stormhaven", price = 20000 }, -- Tree, Yellowing Oak

    -- Summerset
    [139122] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Bush, Summerset Spruce
    [139107] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Coral Shelf, Flat
    [139108] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Coral Shelf, Large
    [139127] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Hedge, Overgrown
    [139128] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Hedge, Overgrown Long
    [139112] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Border, Boulders
    [139113] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Border, Pebbles
    [139111] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Border, Stones
    [139114] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Retaining Wall, Curved
    [139116] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Retaining Wall, Long
    [139115] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Retaining Wall, Short
    [139109] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Shelf, Curved
    [139110] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Limestone Shelf, Large
    [139117] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Limestone Stairway, Natural
    [139126] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Sapling, Ginkgo
    [139121] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Sapling, Growing Shade
    [139132] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Sapling, Sea Grapes
    [139124] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Sapling, Summerset Spruce
    [139120] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Sapling, Young Shade
    [139130] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Saplings, Mangrove
    [141819] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 500 },  -- Shrub, Blooming Sunbird
    [141818] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Shrubs, Dormant Sunbird Cluster
    [141817] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 750 },  -- Tree, Ancient Ginkgo
    [139125] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 2000 }, -- Tree, Blooming Ginkgo
    [141816] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 500 },  -- Tree, Ginkgo
    [139134] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Tree, Sea Grapes
    [139131] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Tree, Solitary Mangrove
    [139123] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Tree, Summerset Spruce
    [139136] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Tree, Twin Poplar
    [139119] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Tree, Upstretched Shade
    [139118] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 250 },  -- Tree, Wide-Trunked Shade
    [139129] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Tree, Young Mangrove
    [139135] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Tree, Young Poplar
    [139133] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Tree, Young Sea Grapes
    [141824] = { npcName = "Unwoltil", zone = "Alinor, Summerset", price = 100 },  -- Vines, Sun-Bronzed Ivy Cluster

    -- Telvanni Peninsula
    [198463] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 500 },   -- Apocrypha Boulder
    [198470] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 450 },   -- Apocrypha Coral, Teal Tube
    [197642] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 1200 },  -- Apocrypha Plant, Anemone Cluster
    [198464] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 2000 },  -- Apocrypha Plant, Chromatic Succulent
    [198465] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 150 },   -- Apocrypha Plant, Feather Fern Cluster
    [198466] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 150 },   -- Apocrypha Plant, Ink-Grass
    [197641] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 2000 },  -- Apocrypha Plant, Suckerleaf
    [198467] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 24000 }, -- Apocrypha Tree, Blue Spore
    [198469] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 4000 },  -- Apocrypha Tree, Branched Green Spore
    [197640] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 500 },   -- Apocrypha Tree, Fossilized
    [197639] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 20000 }, -- Apocrypha Tree, Spore
    [198468] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 7000 },  -- Apocrypha Tree, Teal Spiral
    [197643] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 5000 },  -- Boulder, Apocrypha Fossil
    [198476] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 1000 },  -- Bridge, Reclaimed Wood
    [197634] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 500 },   -- Mushroom, Dual Mauve Dusk
    [197635] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 4000 },  -- Mushroom, Gilled Mauve Dusk
    [198471] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 400 },   -- Mushroom, Russet Chanterelle Pair
    [198473] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 3000 },  -- Mushroom, Tall Green Morel Pair
    [197638] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 500 },   -- Mushroom, Tall Russet Chanterelle
    [198472] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 500 },   -- Mushrooms, Gilled Dusk Cluster
    [197636] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 2000 },  -- Plants, Guar Cabbage Cluster
    [197637] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 1500 },  -- Plants, Lava Pitcher Patch
    [198477] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 300 },   -- Platform, Reclaimed Wood Square
    [198478] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 300 },   -- Platform, Reclaimed Wood Triangle
    [198475] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 50 },    -- Post, Reclaimed Wood
    [198474] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 300 },   -- Stairway, Reclaimed Wood
    [197633] = { npcName = "Murkholg", zone = "Necrom, Telvanni Peninsula", price = 2500 },  -- Tree, Large Gnarled Laurel

    -- The Brass Fortress
    [134304] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 1000 }, -- Boulder, Basalt Slab
    [134292] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Boulder, Metallic Rubble
    [134293] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Boulder, Metallic Shard
    [134305] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 1000 }, -- Clockwork Junk Heap, Small
    [134303] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Rock, Basalt Slab
    [134296] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 1000 }, -- Rocks, Sintered Cluster
    [134294] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 1000 }, -- Rocks, Sintered Column
    [134295] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 1000 }, -- Rocks, Sintered Pile
    [134297] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Grating, Narrow
    [134298] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Grating, Wide
    [134301] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Plate, Ornate
    [134299] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Plate, Plain
    [134300] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Plate, Wide
    [134302] = { npcName = "Mulvise Valyn", zone = "The Brass Fortress", price = 500 },  -- Scavenged Support, Straight

    -- The Reach
    [171383] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 400 },  -- Dwarven Broom, Restored
    [171384] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Dwarven Loaf Pan, Rectangular
    [171385] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 100 },  -- Dwarven Plate, Salvaged Decorative
    [165820] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 100 },  -- Fern, Sting-Vine
    [165817] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Log, Fallen Winter Pine
    [165822] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Plant Cluster, Haafingar Underbrush
    [171386] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 2000 }, -- Reachfolk Banner, Markarth
    [165819] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 300 },  -- Sapling, White Pine
    [165821] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Shrub, Wild Basil
    [165824] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 300 },  -- Tree, Mountain Mahogany
    [165825] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 1000 }, -- Tree, Twisted Mountain Mahogany
    [165818] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 900 },  -- Tree, White Pine
    [165815] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 900 },  -- Tree, Winter Pine
    [165816] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 300 },  -- Tree, Young Aspen
    [165823] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Tree, Young Mountain Mahogany
    [165814] = { npcName = "Averio Brassac", zone = "Markarth, The Reach", price = 250 },  -- Tree, Young Winter Pine

    -- The Rift
    [120492] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Boulder, Flat Weathered
    [120496] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Fern, Dead
    [120494] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Pebble, Stacked Weathered
    [120493] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Rock, Slanted Tan
    [120500] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Sapling, Tender Autumn
    [120499] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Sapling, Tender Harvest
    [120495] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 100 }, -- Saplings, Budding Red

    -- Vvardenfell
    [125481] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 500 },   -- Boulder, Volcanic Column
    [125483] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 500 },   -- Boulder, Volcanic Plug
    [125587] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 15000 }, -- Mushroom, Funnel Caps
    [125588] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushroom, Lanky Erupted Stinkcap
    [125593] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 25000 }, -- Mushroom, Netch Shield Platform
    [125594] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 20000 }, -- Mushroom, Netch Shield Tower
    [125599] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushroom, Spongecap Button
    [125602] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushroom, Stinkcap Button
    [125601] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushroom, Stinkcap Sprout
    [125604] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushroom, Sturdy Milkcap
    [125612] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 22500 }, -- Mushrooms, Funnel Cap Cluster
    [125614] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 750 },   -- Mushrooms, Netch Hide Shade
    [125638] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 100 },   -- Rock, Volcanic Chunk
    [125639] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 100 },   -- Rock, Volcanic Slab
    [125641] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 250 },   -- Sapling, Forked Ashland
    [125642] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 250 },   -- Sapling, Lanky Ash Laurel
    [125644] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 250 },   -- Sapling, Tall Ashland
    [125645] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 250 },   -- Saplings, Ashland
    [125643] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 250 },   -- Saplings, Sturdy Ash Laurel
    [125673] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 500 },   -- Tree, Lanky Poplar
    [125677] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 40000 }, -- Tree, Rooted Ashland
    [125676] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 50000 }, -- Tree, Rooted Cedar
    [125678] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 500 },   -- Tree, Sturdy Poplar
    [125679] = { npcName = "Uzipa", zone = "Vivec City, Vvardenfell", price = 500 },   -- Trees, Poplar Cluster

    -- West Weald
    [204774] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 100 },   -- Boulder, Colovian Highland
    [204769] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 250 },   -- Bush, Autumn Oak
    [204770] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 250 },   -- Bush, Autumn Oak Cluster
    [204767] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 600 },   -- Bush, Squat Maple
    [217941] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 450 },   -- Colovian Well, Destroyed Dawnwood
    [217940] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 4500 },  -- Colovian Well, Overgrown Dawnwood
    [211514] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 100 },   -- Fern, Small Mammoth Leaf
    [211513] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Fern, Tall Mammoth Leaf
    [211516] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 5000 },  -- Hosta, Orange
    [204773] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 450 },   -- Leaf Pile, Autumn
    [211507] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 1000 },  -- Quarry Stone, Large
    [211508] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Quarry Stone, Small
    [204762] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Sapling, Autumn Maple
    [204760] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Sapling, Autumn Oak
    [204768] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Sapling, Young Autumn Maple
    [204772] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 100 },   -- Sawdust Pile, Logging
    [211515] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 200 },   -- Shrub Cluster, Large Red Boxwood
    [204765] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 250 },   -- Shrub, Juniper Cluster
    [204771] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 100 },   -- Stump, Old Maple
    [204761] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 500 },   -- Tree, Autumn Aspen
    [204763] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 1000 },  -- Tree, Autumn Conical Cypress
    [217939] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 4500 },  -- Tree, Braided Dawnwood
    [211509] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 20000 }, -- Tree, Curled Dawnwood
    [204756] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 20000 }, -- Tree, Giant Autumn Maple
    [217970] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 24000 }, -- Tree, Giant Dawnwood Canopy
    [204757] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 25000 }, -- Tree, Giant Dawnwood Growth
    [204758] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 2500 },  -- Tree, Giant Oak
    [204759] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 5000 },  -- Tree, Healthy Willow
    [217938] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 3000 },  -- Tree, Hooked Dawnwood
    [211510] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 15000 }, -- Tree, Sheltering Dawnwood
    [211512] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 2500 },  -- Tree, Small Willow
    [204766] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 250 },   -- Tree, Squat Cypress
    [204764] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 250 },   -- Tree, Tall Autumn Conical Cypress
    [204810] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 1500 },  -- Tree, Towering Slim Autumnal Cypress
    [204811] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 1500 },  -- Tree, Towering Slim Cypress
    [211511] = { npcName = "Mahei-Jekka", zone = "Skingrad, West Weald", price = 25000 }, -- Tree, Twisted Dawnwood

    -- Western Skyrim
    [165811] = { npcName = "Masela", zone = "Solitude, Western Skyrim", price = 100 }, -- Solitude Fence, Stick
    [217665] = { npcName = "Masela", zone = "Solitude, Western Skyrim", price = 100 }, -- Solitude Fence, Stick Curved
    [165812] = { npcName = "Masela", zone = "Solitude, Western Skyrim", price = 250 }, -- Solitude Fence, Stick Triple
    [165813] = { npcName = "Masela", zone = "Solitude, Western Skyrim", price = 250 }, -- Solitude Wagon Wheel, Heavy

    -- Sold by multiple in multiple locations used shortest length
    [120998] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Block, Wood Cutting
    [117994] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Rough Block, Stone Slab
    [117971] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Rough Clothesline, Post
    [117980] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Rough Firewood, Fireplace
    [117982] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Rough Firewood, Stack
    [117977] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 100 }, -- Rough Stool, Round
    [117990] = { npcName = "Maladdiq", zone = "Skywatch, Auridon", price = 250 }, -- Tea Table, Carved

    -- Sold by single in multiple locations used shortest length
    [120502] = { npcName = "Frohilde Snow-Hair", zone = "Riften, The Rift", price = 1000 },    -- Flower, Grandmother Hibiscus
    [121284] = { npcName = "Frohilde Snow-Hair", zone = "Mournhold, Deshaan", price = 250 },   -- Dark Elf Column Lantern
    [120621] = { npcName = "Frohilde Snow-Hair", zone = "Dhalmora, Bal Foyen", price = 250 },  -- Plant, Red Aloe
    [120620] = { npcName = "Frohilde Snow-Hair", zone = "Dhalmora, Bal Foyen", price = 250 },  -- Plant, Red Aloe Succulent
    [120618] = { npcName = "Frohilde Snow-Hair", zone = "Dhalmora, Bal Foyen", price = 5000 }, -- Tree, Gnarled Ashflower
    [120619] = { npcName = "Frohilde Snow-Hair", zone = "Dhalmora, Bal Foyen", price = 7500 }, -- Tree, Twisted Ashflower
    [120444] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 },             -- Sapling, Tall Highland
    [120442] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 },             -- Saplings, Squat Highland
    [120443] = { npcName = "Rohzika", zone = "Evermore, Bangkorai", price = 100 },             -- Saplings, Strong Highland
}
