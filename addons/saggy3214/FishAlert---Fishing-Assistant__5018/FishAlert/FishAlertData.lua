-- Fishing achievement data for the Rare Fish Tracker.
--
-- Source: a one-time in-game scan of ESO's achievement and zone data (API 101051, eso.live.12.1.6, 2026-11-01).
-- Each achievement's description names its zone(s), and those names were matched to zone IDs from the
-- same scan. Only IDs live here; achievement names, fish names and progress are read from ESO at runtime.
--
-- Not mapped on purpose: Betnikh (535) and Bal Foyen (281), whose fishing associations are unverified,
-- and meta achievements that are not zone checklists (Fisherman, Master Fisher, Solstice Master Angler,
-- Commemorative Master Angler, Fish Boon Angler).

-- Achievement ID = number of criteria (one per rare fish) seen in the scan, used to validate at runtime
FishAlert.FISHING_ACHIEVEMENTS = {
    [471] = 12,     -- Glenumbra Angler
    [472] = 12,     -- Stormhaven Angler
    [473] = 12,     -- Rivenspire Angler
    [474] = 12,     -- Alik'r Desert Angler
    [475] = 12,     -- Bangkorai Angler
    [477] = 12,     -- Stonefalls Angler
    [478] = 12,     -- Deshaan Angler
    [479] = 12,     -- Shadowfen Angler
    [480] = 12,     -- Eastmarch Angler
    [481] = 12,     -- Rift Angler
    [483] = 12,     -- Auridon Angler
    [484] = 12,     -- Grahtwood Angler
    [485] = 12,     -- Greenshade Angler
    [486] = 12,     -- Malabal Tor Angler
    [487] = 12,     -- Reaper's March Angler
    [489] = 12,     -- Cyrodiil Angler
    [490] = 12,     -- Coldharbour Angler
    [491] = 1,      -- Stros M'Kai Angler
    [492] = 1,      -- Khenarthi's Roost Angler
    [493] = 1,      -- Bleakrock Angler
    [916] = 12,     -- Craglorn Angler
    [1186] = 12,    -- Imperial City Angler
    [1340] = 12,    -- Wrothgar Master Angler
    [1351] = 12,    -- Hew's Bane Master Angler
    [1431] = 12,    -- Gold Coast Master Angler
    [1882] = 12,    -- Morrowind Master Angler
    [2027] = 12,    -- Clockwork City Master Angler
    [2191] = 12,    -- Summerset Master Angler
    [2240] = 3,     -- Artaeum Master Angler
    [2295] = 12,    -- Murkmire Master Angler
    [2412] = 12,    -- Northern Elsweyr Master Angler
    [2566] = 12,    -- Pellitine Master Angler
    [2655] = 12,    -- Western Skyrim Master Angler
    [2861] = 12,    -- The Reach Master Angler
    [2981] = 12,    -- Blackwood Master Angler
    [3144] = 12,    -- Deadlands Master Angler
    [3269] = 12,    -- High Isle Master Angler
    [3500] = 12,    -- Galen Master Angler
    [3636] = 12,    -- Necrom Master Angler
    [3948] = 12,    -- West Weald Master Angler
    [4404] = 12,    -- Western Solstice Master Angler
    [4460] = 12,    -- Eastern Solstice Master Angler
    [4691] = 4,     -- High Seas Master Angler (event fishing holes in Gold Coast)
}

-- Zone ID = fishing achievements shown there, in display order. Zones not listed fall back to their
-- parent zone (delves, sewers), so subzones with their own achievement must be listed explicitly.
FishAlert.ZONE_FISHING_ACHIEVEMENTS = {
    [3] = { 471 },              -- Glenumbra
    [19] = { 472 },             -- Stormhaven
    [20] = { 473 },             -- Rivenspire
    [104] = { 474 },            -- Alik'r Desert
    [92] = { 475 },             -- Bangkorai
    [41] = { 477 },             -- Stonefalls
    [57] = { 478 },             -- Deshaan
    [117] = { 479 },            -- Shadowfen
    [101] = { 480 },            -- Eastmarch
    [103] = { 481 },            -- The Rift
    [381] = { 483 },            -- Auridon
    [383] = { 484 },            -- Grahtwood
    [108] = { 485 },            -- Greenshade
    [58] = { 486 },             -- Malabal Tor
    [382] = { 487 },            -- Reaper's March
    [181] = { 489 },            -- Cyrodiil
    [347] = { 490 },            -- Coldharbour
    [534] = { 491 },            -- Stros M'Kai
    [537] = { 492 },            -- Khenarthi's Roost
    [280] = { 493 },            -- Bleakrock Isle
    [888] = { 916 },            -- Craglorn
    [584] = { 1186 },           -- Imperial City
    [684] = { 1340 },           -- Wrothgar
    [816] = { 1351 },           -- Hew's Bane
    [823] = { 1431, 4691 },     -- Gold Coast, plus High Seas event holes
    [849] = { 1882 },           -- Vvardenfell
    [980] = { 2027 },           -- Clockwork City
    [1011] = { 2191 },          -- Summerset
    [1027] = { 2240 },          -- Artaeum (its parent zone is Summerset)
    [726] = { 2295 },           -- Murkmire
    [1086] = { 2412 },          -- Northern Elsweyr
    [1133] = { 2566 },          -- Southern Elsweyr
    [1160] = { 2655 },          -- Western Skyrim
    [1161] = { 2655 },          -- Blackreach: Greymoor Caverns
    [1207] = { 2861 },          -- The Reach
    [1208] = { 2861 },          -- Blackreach: Arkthzand Cavern
    [1261] = { 2981 },          -- Blackwood
    [1286] = { 3144 },          -- The Deadlands
    [1318] = { 3269 },          -- High Isle
    [1383] = { 3500 },          -- Galen
    [1414] = { 3636 },          -- Telvanni Peninsula
    [1413] = { 3636 },          -- Apocrypha
    [1443] = { 3948 },          -- West Weald
    [1502] = { 4404, 4460 },    -- Solstice (one zone ID covers both halves)
}

-- Rare fish item IDs per achievement, used only to color fish names by their item quality.
-- Source: a one-time in-game scan of item IDs 1-300,000 on the same client (2026-11-01). Each ID is an item ESO
-- classes as a rare fish whose name matched exactly one criterion of that achievement (ignoring case).
-- These are sets, not ordered lists: fish are paired with criteria by name at runtime, never by position.
FishAlert.FISHING_ACHIEVEMENT_FISH = {
    [471] = { 42898, 42899, 42900, 42901, 45384, 45385, 45422, 45423, 45460, 45461, 45498, 45499 },  -- Glenumbra Angler
    [472] = { 42902, 42903, 42904, 42905, 45400, 45401, 45438, 45439, 45476, 45477, 45514, 45515 },  -- Stormhaven Angler
    [473] = { 42906, 42907, 42908, 42909, 45394, 45395, 45432, 45433, 45470, 45471, 45508, 45509 },  -- Rivenspire Angler
    [474] = { 42910, 42911, 42912, 42913, 45368, 45369, 45406, 45407, 45444, 45445, 45482, 45483 },  -- Alik'r Desert Angler
    [475] = { 42914, 42915, 42916, 42917, 45372, 45373, 45410, 45411, 45448, 45449, 45486, 45487 },  -- Bangkorai Angler
    [477] = { 42879, 42880, 42881, 42949, 45398, 45399, 45436, 45437, 45475, 45512, 45513, 54368 },  -- Stonefalls Angler
    [478] = { 42882, 42883, 42884, 42885, 45380, 45381, 45418, 45419, 45456, 45457, 45494, 45495 },  -- Deshaan Angler
    [479] = { 42886, 42887, 42888, 42889, 45396, 45397, 45434, 45435, 45472, 45474, 45510, 45511 },  -- Shadowfen Angler
    [480] = { 42890, 42891, 42892, 42893, 45382, 45383, 45420, 45421, 45458, 45459, 45496, 45497 },  -- Eastmarch Angler
    [481] = { 42894, 42895, 42896, 42897, 45402, 45403, 45440, 45441, 45478, 45480, 45516, 45517 },  -- Rift Angler
    [483] = { 42918, 42919, 42920, 42921, 45370, 45371, 45408, 45409, 45446, 45447, 45484, 45485 },  -- Auridon Angler
    [484] = { 42922, 42923, 42924, 42925, 45386, 45414, 45424, 45425, 45462, 45463, 45500, 45501 },  -- Grahtwood Angler
    [485] = { 42926, 42927, 42928, 42929, 45388, 45389, 45426, 45427, 45464, 45465, 45502, 45503 },  -- Greenshade Angler
    [486] = { 42930, 42931, 42932, 42933, 45390, 45391, 45428, 45429, 45466, 45467, 45504, 45505 },  -- Malabal Tor Angler
    [487] = { 42934, 42935, 42936, 42937, 45392, 45393, 45430, 45431, 45468, 45469, 45506, 45507 },  -- Reaper's March Angler
    [489] = { 42938, 42939, 42940, 42941, 45378, 45379, 45416, 45417, 45454, 45455, 45492, 45493 },  -- Cyrodiil Angler
    [490] = { 42942, 42943, 42944, 42945, 45374, 45375, 45412, 45413, 45450, 45451, 45488, 45489 },  -- Coldharbour Angler
    [491] = { 42946 },  -- Stros M'Kai Angler
    [492] = { 42948 },  -- Khenarthi's Roost Angler
    [493] = { 42947 },  -- Bleakrock Angler
    [916] = { 55264, 55265, 55266, 55267, 55268, 55269, 55270, 55271, 55272, 55273, 55274, 55275 },  -- Craglorn Angler
    [1186] = { 68144, 68145, 68146, 68147, 68148, 68149, 68150, 68151, 68152, 68153, 68154, 68155 },  -- Imperial City Angler
    [1340] = { 68156, 68157, 68158, 68159, 68160, 68161, 68162, 68163, 68164, 68165, 68166, 68167 },  -- Wrothgar Master Angler
    [1351] = { 71767, 71768, 71769, 71771, 71773, 71774, 71775, 71776, 71777, 71778 },  -- Hew's Bane Master Angler
    [1431] = { 79678, 79679, 79680, 79681, 79682, 79683, 79684, 79685, 79686, 79687, 79688, 79689 },  -- Gold Coast Master Angler
    [1882] = { 126081, 126082, 126083, 126084, 126085, 126086, 126087, 126088, 126089, 126090, 126091, 126092 },  -- Morrowind Master Angler
    [2027] = { 133564, 133565, 133566, 133567, 133568, 133569, 133570, 133571, 133572, 133573, 133574, 133575 },  -- Clockwork City Master Angler
    [2191] = { 138828, 138829, 138830, 138831, 138832, 138833, 138834, 138835, 138836, 138837, 138838, 138839 },  -- Summerset Master Angler
    [2240] = { 139013, 139014, 139015 },  -- Artaeum Master Angler
    [2295] = { 145582, 145583, 145584, 145585, 145586, 145587, 145588, 145589, 145590, 145591, 145592, 145593 },  -- Murkmire Master Angler
    [2412] = { 147936, 147937, 147938, 147939, 147940, 147941, 147942, 147943, 147944, 147945, 147946, 147947 },  -- Northern Elsweyr Master Angler
    [2566] = { 153815, 153817, 153818, 153819, 153820, 153821, 153822, 153823, 153824, 153825, 153826 },  -- Pellitine Master Angler
    [2655] = { 161192, 161193, 161194, 161195, 161196, 161197, 161198, 161199, 161200, 161201, 161202, 161203 },  -- Western Skyrim Master Angler
    [2861] = { 171264, 171265, 171269, 171270, 171314, 171315, 171316, 171317, 171318, 171319, 171320, 171321 },  -- The Reach Master Angler
    [2981] = { 173575, 173576, 173578, 173579, 173580, 173582, 173583, 173584, 173586, 173587, 173588, 173590 },  -- Blackwood Master Angler
    [3144] = { 181439, 181440, 181441, 181442, 181443, 181444, 181445, 181446, 181447, 181448, 181449, 181450 },  -- Deadlands Master Angler
    [3269] = { 187923, 187924, 187925, 187926, 187927, 187928, 187929, 187930, 187931, 187932, 187933, 187934 },  -- High Isle Master Angler
    [3500] = { 190871, 190872, 190873, 190874, 190875, 190876, 190877, 190878, 190879, 190880, 190881, 190882 },  -- Galen Master Angler
    [3636] = { 197854, 197855, 197856, 197857, 197858, 197859, 197860, 197861, 197862, 197863, 197864, 197865 },  -- Necrom Master Angler
    [3948] = { 207928, 207929, 207930, 207931, 207932, 207933, 207934, 207935, 207936, 207937, 207938, 207939 },  -- West Weald Master Angler
    [4404] = { 217638, 217639, 217640, 217641, 217642, 217643, 217644, 217645, 217646, 217647, 217648, 217649 },  -- Western Solstice Master Angler
    [4460] = { 223775, 223776, 223777, 223778, 223779, 223780, 223781, 223782, 223783, 223784, 223785, 223786 },  -- Eastern Solstice Master Angler
    [4691] = { 227163, 227164, 227165, 227166 },  -- High Seas Master Angler
}

-- Evidence-based pairings for three criteria whose ESO text doesn't match any item name (a cut-off name,
-- a misspelling, and a renamed fish). They are not name-verified: each fills the only gap in its
-- achievement's consecutive item ID block. A pairing applies only when the achievement ID and the raw
-- criterion text match exactly, and the item still is a rare fish of the recorded quality.
-- These three pairings are not yet confirmed in-game; rarity coloring is confirmed for name-matched fish.
FishAlert.FISH_CRITERION_EXCEPTIONS = {
    [1351] = {
        ["Sparking Anglermout (Salt)"] = { itemId = 71770, quality = ITEM_DISPLAY_QUALITY_ARCANE },    -- Sparking Anglermouth
        ["Begger Shark (Salt)"] = { itemId = 71772, quality = ITEM_DISPLAY_QUALITY_MAGIC },           -- Beggar Shark
    },
    [2566] = {
        ["Senchal River Perch (River)"] = { itemId = 153816, quality = ITEM_DISPLAY_QUALITY_MAGIC },  -- Elsweyr River Perch
    },
}
