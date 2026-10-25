-- Achievements.lua – DungeonFinderPlus
DungeonFinderPlus = DungeonFinderPlus or {}
local DFP = DungeonFinderPlus

----------------------------------------------------------------
-- Rohdaten
----------------------------------------------------------------

-- Normal-Clear-Achievements
local NORMAL = {
    [2]   ={id=294,  isDLC=false, itemSetIDs = {33, 61, 297}},   --Fungal Grotto I
    [3]   ={id=301,  isDLC=false, itemSetIDs = {35, 55, 296}},   --Spindleclutch I
    [4]   ={id=325,  isDLC=false, itemSetIDs = {110, 194, 295}}, --Banished Cells I
    [5]   ={id=78,   isDLC=false, itemSetIDs = {96, 300, 301}},  --Darkshade Caverns I
    [6]   ={id=79,   isDLC=false, itemSetIDs = {29, 194, 299}},  --Wayrest Sewers I
    [7]   ={id=11,   isDLC=false, itemSetIDs = {28, 155, 298}},  --Elden Hollow I
    [8]   ={id=272,  isDLC=false, itemSetIDs = {156, 303, 304}}, --Arx Corinium
    [9]   ={id=80,   isDLC=false, itemSetIDs = {122, 134, 302}}, --Crypt of Hearts I
    [10]  ={id=551,  isDLC=false, itemSetIDs = {158, 159, 160}}, --City of Ash I
    [11]  ={id=357,  isDLC=false, itemSetIDs = {53, 103, 307}},  --Direfrost Keep
    [12]  ={id=391,  isDLC=false, itemSetIDs = {77, 102, 305}},  --Volenfell
    [13]  ={id=81,   isDLC=false, itemSetIDs = {186, 188, 193}}, --Tempest Island
    [14]  ={id=393,  isDLC=false, itemSetIDs = {46, 72, 310}},   --Blessed Crucible
    [15]  ={id=410,  isDLC=false, itemSetIDs = {157, 308, 309}}, --Blackheart Haven
    [16]  ={id=417,  isDLC=false, itemSetIDs = {19, 71, 123}},   --Selene's Web
    [17]  ={id=570,  isDLC=false, itemSetIDs = {91, 124, 311}},  --Vaults of Madness
    [18]  ={id=1562, isDLC=false, itemSetIDs = {33, 61, 297}},   --Fungal Grotto II
    [22]  ={id=1595, isDLC=false, itemSetIDs = {29, 194, 299}},  --Wayrest Sewers II

    [288] ={id=1346, isDLC=true, itemSetIDs = {184, 185, 198}},               --White-Gold Tower
    [289] ={id=1345, isDLC=true, itemSetIDs = {190, 195, 196}},               --Imperial City Prison
    [293] ={id=1504, isDLC=true, itemSetIDs = {258, 259, 260}, motif=1795},   --Ruins of Mazzatun
    [295] ={id=1522, isDLC=true, itemSetIDs = {261, 262, 263}, motif=1796},   --Cradle of Shadows

    [300] ={id=1555, isDLC=false, itemSetIDs = {110, 194, 295}}, --Banished Cells II
    [303] ={id=1579, isDLC=false, itemSetIDs = {28, 155, 298}},  --Elden Hollow II
    [308] ={id=1587, isDLC=false, itemSetIDs = {96, 300, 301}},  --Darkshade Caverns II
    [316] ={id=1571, isDLC=false, itemSetIDs = {35, 55, 296}},   --Spindleclutch II
    [317] ={id=1616, isDLC=false, itemSetIDs = {122, 134, 302}}, --Crypt of Hearts II
    [322] ={id=1603, isDLC=false, itemSetIDs = {158, 159, 160}}, --City of Ash II

    [324] ={id=1690, isDLC=true, itemSetIDs = {338, 339, 340}, motif=2098},   --Bloodroot Forge
    [368] ={id=1698, isDLC=true, itemSetIDs = {335, 336, 337}, motif=2097},   --Falkreath Hold
    [418] ={id=1975, isDLC=true, itemSetIDs = {346, 347, 348}, motif=2189},   --Scalecaller Peak
    [420] ={id=1959, isDLC=true, itemSetIDs = {343, 344, 345}, motif=2190},   --Fang Lair
    [426] ={id=2152, isDLC=true, itemSetIDs = {402, 403, 404}, motif=2318},   --Moon Hunter Keep
    [428] ={id=2162, isDLC=true, itemSetIDs = {399, 400, 401}, motif=2317},   --March of Sacrifices
    [433] ={id=2260, isDLC=true, itemSetIDs = {429, 430, 431}, motif=2503},   --Frostvault
    [435] ={id=2270, isDLC=true, itemSetIDs = {433, 434, 435}, motif=2504},   --Depths of Malatar
    [494] ={id=2415, isDLC=true, itemSetIDs = {452, 453, 454}, motif=2628},   --Moongrave Fane
    [496] ={id=2425, isDLC=true, itemSetIDs = {455, 456, 457}, motif=2629},   --Lair of Maarselok
    [503] ={id=2539, isDLC=true, itemSetIDs = {471, 472, 473}, motif=2747},   --Icereach
    [505] ={id=2549, isDLC=true, itemSetIDs = {474, 475, 476}, motif=2749},   --Unhallowed Grave
    [507] ={id=2694, isDLC=true, itemSetIDs = {516, 517, 518}, motif=2850},   --Stone Garden
    [509] ={id=2704, isDLC=true, itemSetIDs = {513, 514, 515}, motif=2849},   --Castle Thorn
    [591] ={id=2831, isDLC=true, itemSetIDs = {569, 570, 571}, motif=2984},   --Black Drake Villa
    [593] ={id=2841, isDLC=true, itemSetIDs = {572, 573, 574}, motif=2991},   --Cauldron
    [595] ={id=3016, isDLC=true, itemSetIDs = {605, 606, 607}, motif=3097},   --Red Petal Bastion
    [597] ={id=3026, isDLC=true, itemSetIDs = {602, 603, 604}, motif=3094},   --The Dread Cellar
    [599] ={id=3104, isDLC=true, itemSetIDs = {619, 620, 621}, motif=3229},   --Coral Aerie
    [601] ={id=3114, isDLC=true, itemSetIDs = {622, 623, 624}, motif=3228},   --Shipwright's Regret
    [608] ={id=3375, isDLC=true, itemSetIDs = {660, 661, 662}, motif=3422},   --Earthen Root Enclave
    [610] ={id=3394, isDLC=true, itemSetIDs = {663, 664, 665}, motif=3423},   --Graven Deep
    [613] ={id=3468, isDLC=true, itemSetIDs = {680, 681, 682}, motif=3547},   --Bal Sunnar
    [615] ={id=3529, isDLC=true, itemSetIDs = {684, 685, 686}, motif=3546},   --Scrivener's Hall
    [638] ={id=3810, isDLC=true, itemSetIDs = {730, 731, 732}, motif=3921},   --Oathsworn Pit
    [640] ={id=3851, isDLC=true, itemSetIDs = {735, 736, 737}, motif=3922},   --Bedlam Veil
    [855] ={id=4109, isDLC=true, itemSetIDs = {794, 795, 796}, motif=4159},   --Exiled Redoubt
    [857] ={id=4128, isDLC=true, itemSetIDs = {798, 799, 800}, motif=4160},   --Lep Seclusa
    [1037]={id=4311, isDLC=true, itemSetIDs = {825, 826, 827}, motif=nil},    --Naj-Caldeesh
    [1039]={id=4334, isDLC=true, itemSetIDs = {822, 823, 824}, motif=nil},    --Black Gem Foundry
}

-- Veteran-Clear- und Meta-Achievements
local VETERAN = {
    [19]  ={id=421,  hm=448,  tt=446,  nd=1572, tri=nil,  isDLC=false, itemSetIDs = {35, 55, 296, 163}}, --Spindleclutch II
    [20]  ={id=1549, hm=1554, tt=1552, nd=1553, tri=nil,  isDLC=false, itemSetIDs = {110, 194, 295, 170}}, --Banished Cells I
    [21]  ={id=464,  hm=467,  tt=465,  nd=1588, tri=nil,  isDLC=false, itemSetIDs = {96, 300, 301, 166}}, --Darkshade Caverns II
    [23]  ={id=1573, hm=1578, tt=1576, nd=1577, tri=nil,  isDLC=false, itemSetIDs = {28, 155, 298, 167}}, --Elden Hollow I
    [261] ={id=1610, hm=1615, tt=1613, nd=1614, tri=nil,  isDLC=false, itemSetIDs = {122, 134, 302, 168}}, --Crypt of Hearts I
    [267] ={id=878,  hm=1114, tt=1108, nd=1107, tri=nil,  isDLC=false, itemSetIDs = {158, 159, 160, 169}}, --City of Ash II
    [268] ={id=880,  hm=1303, tt=1128, nd=1129, tri=nil,  isDLC=true, itemSetIDs = {190, 195, 196, 164}},  --Imperial City Prison
    [287] ={id=1120, hm=1279, tt=1275, nd=1276, tri=nil,  isDLC=true, itemSetIDs = {184, 185, 198, 183}},  --White-Gold Tower
    [294] ={id=1505, hm=1506, tt=1507, nd=1508, tri=nil,  isDLC=true, itemSetIDs = {258, 259, 260, 256}, motif=1795},  --Ruins of Mazzatun
    [296] ={id=1523, hm=1524, tt=1525, nd=1526, tri=nil,  isDLC=true, itemSetIDs = {261, 262, 263, 257}, motif=1796},  --Cradle of Shadows
    [299] ={id=1556, hm=1561, tt=1559, nd=1560, tri=nil,  isDLC=false, itemSetIDs = {33, 61, 297, 266}}, --Fungal Grotto I
    [301] ={id=545,  hm=451,  tt=449,  nd=1564, tri=nil,  isDLC=false, itemSetIDs = {110, 194, 295, 170}}, --Banished Cells II
    [302] ={id=459,  hm=463,  tt=461,  nd=1580, tri=nil,  isDLC=false, itemSetIDs = {28, 155, 298, 167}}, --Elden Hollow II
    [304] ={id=1629, hm=1634, tt=1632, nd=1633, tri=nil,  isDLC=false, itemSetIDs = {77, 102, 305, 276}}, --Volenfell
    [305] ={id=1604, hm=1609, tt=1607, nd=1608, tri=nil,  isDLC=false, itemSetIDs = {156, 303, 304, 271}}, --Arx Corinium
    [306] ={id=1589, hm=1594, tt=1592, nd=1593, tri=nil,  isDLC=false, itemSetIDs = {29, 194, 299, 270}}, --Wayrest Sewers I
    [307] ={id=678,  hm=681,  tt=679,  nd=1596, tri=nil,  isDLC=false, itemSetIDs = {29, 194, 299, 165}}, --Wayrest Sewers II
    [309] ={id=1581, hm=1586, tt=1584, nd=1585, tri=nil,  isDLC=false, itemSetIDs = {96, 300, 301, 268}}, --Darkshade Caverns I
    [310] ={id=1597, hm=1602, tt=1600, nd=1601, tri=nil,  isDLC=false, itemSetIDs = {158, 159, 160, 272}}, --City of Ash I
    [311] ={id=1617, hm=1622, tt=1620, nd=1621, tri=nil,  isDLC=false, itemSetIDs = {186, 188, 193, 275}}, --Tempest Island
    [312] ={id=343,  hm=342,  tt=340,  nd=1563, tri=nil,  isDLC=false, itemSetIDs = {33, 61, 297, 162}}, --Fungal Grotto II
    [313] ={id=1635, hm=1640, tt=1638, nd=1639, tri=nil,  isDLC=false, itemSetIDs = {19, 71, 123, 279}}, --Selene's Web
    [314] ={id=1653, hm=1658, tt=1656, nd=1657, tri=nil,  isDLC=false, itemSetIDs = {91, 124, 311, 280}}, --Vaults of Madness
    [315] ={id=1565, hm=1570, tt=1568, nd=1569, tri=nil,  isDLC=false, itemSetIDs = {35, 55, 296, 267}}, --Spindleclutch I
    [318] ={id=876,  hm=1084, tt=941,  nd=942,  tri=nil,  isDLC=false, itemSetIDs = {122, 134, 302, 168}}, --Crypt of Hearts II
    [319] ={id=1623, hm=1628, tt=1626, nd=1627, tri=nil,  isDLC=false, itemSetIDs = {53, 103, 307, 274}}, --Direfrost Keep
    [320] ={id=1641, hm=1646, tt=1644, nd=1645, tri=nil,  isDLC=false, itemSetIDs = {46, 72, 310, 278}}, --Blessed Crucible
    [321] ={id=1647, hm=1652, tt=1650, nd=1651, tri=nil,  isDLC=false, itemSetIDs = {157, 308, 309, 277}}, --Blackheart Haven
    [325] ={id=1691, hm=1696, tt=1694, nd=1695, tri=nil,  isDLC=true, itemSetIDs = {338, 339, 340, 341}, motif=2098},  --Bloodroot Forge
    [369] ={id=1699, hm=1704, tt=1702, nd=1703, tri=nil,  isDLC=true, itemSetIDs = {335, 336, 337, 342}, motif=2097},  --Falkreath Hold
    [419] ={id=1976, hm=1981, tt=1979, nd=1980, tri=1983, isDLC=true, itemSetIDs = {346, 347, 348, 350}, motif=2189},  --Scalecaller Peak
    [421] ={id=1960, hm=1965, tt=1963, nd=1964, tri=2102, isDLC=true, itemSetIDs = {343, 344, 345, 349}, motif=2190},  --Fang Lair
    [427] ={id=2153, hm=2154, tt=2155, nd=2156, tri=2159, isDLC=true, itemSetIDs = {402, 403, 404, 398}, motif=2318},  --Moon Hunter Keep
    [429] ={id=2163, hm=2164, tt=2165, nd=2166, tri=2168, isDLC=true, itemSetIDs = {399, 400, 401, 397}, motif=2317},  --March of Sacrifices
    [434] ={id=2261, hm=2262, tt=2263, nd=2264, tri=2267, isDLC=true, itemSetIDs = {429, 430, 431, 432}, motif=2503},  --Frostvault
    [436] ={id=2271, hm=2272, tt=2273, nd=2274, tri=2276, isDLC=true, itemSetIDs = {433, 434, 435, 436}, motif=2504},  --Depths of Malatar
    [495] ={id=2416, hm=2417, tt=2418, nd=2419, tri=2422, isDLC=true, itemSetIDs = {452, 453, 454, 458}, motif=2628},  --Moongrave Fane
    [497] ={id=2426, hm=2427, tt=2428, nd=2429, tri=2431, isDLC=true, itemSetIDs = {455, 456, 457, 459}, motif=2629},  --Lair of Maarselok
    [504] ={id=2540, hm=2541, tt=2542, nd=2543, tri=2546, isDLC=true, itemSetIDs = {471, 472, 473, 478}, motif=2747},  --Icereach
    [506] ={id=2550, hm=2551, tt=2552, nd=2553, tri=2555, isDLC=true, itemSetIDs = {474, 475, 476, 479}, motif=2749},  --Unhallowed Grave
    [508] ={id=2695, hm=2755, tt=2697, nd=2698, tri=2701, isDLC=true, itemSetIDs = {516, 517, 518, 534}, motif=2850},  --Stone Garden
    [510] ={id=2705, hm=2706, tt=2707, nd=2708, tri=2710, isDLC=true, itemSetIDs = {513, 514, 515, 535}, motif=2849},  --Castle Thorn
    [592] ={id=2832, hm=2833, tt=2834, nd=2835, tri=2838, isDLC=true, itemSetIDs = {569, 570, 571, 577}, motif=2984},  --Black Drake Villa
    [594] ={id=2842, hm=2843, tt=2844, nd=2845, tri=2847, isDLC=true, itemSetIDs = {572, 573, 574, 578}, motif=2991},  --Cauldron
    [596] ={id=3017, hm=3018, tt=3019, nd=3020, tri=3023, isDLC=true, itemSetIDs = {605, 606, 607, 608}, motif=3097},  --Red Petal Bastion
    [598] ={id=3027, hm=3028, tt=3029, nd=3030, tri=3032, isDLC=true, itemSetIDs = {602, 603, 604, 609}, motif=3094},  --The Dread Cellar
    [600] ={id=3105, hm=3153, tt=3107, nd=3108, tri=3111, isDLC=true, itemSetIDs = {619, 620, 621, 632}, motif=3229},  --Coral Aerie
    [602] ={id=3115, hm=3154, tt=3117, nd=3118, tri=3120, isDLC=true, itemSetIDs = {622, 623, 624, 633}, motif=3228},  --Shipwright's Regret
    [609] ={id=3376, hm=3377, tt=3378, nd=3379, tri=3381, isDLC=true, itemSetIDs = {660, 661, 662, 666}, motif=3422},  --Earthen Root Enclave
    [611] ={id=3395, hm=3396, tt=3397, nd=3398, tri=3400, isDLC=true, itemSetIDs = {663, 664, 665, 667}, motif=3423},  --Graven Deep
    [614] ={id=3469, hm=3470, tt=3471, nd=3472, tri=3474, isDLC=true, itemSetIDs = {680, 681, 682, 683}, motif=3547},  --Bal Sunnar
    [616] ={id=3530, hm=3531, tt=3532, nd=3533, tri=3535, isDLC=true, itemSetIDs = {684, 685, 686, 687}, motif=3546},  --Scrivener's Hall
    [639] ={id=3811, hm=3812, tt=3813, nd=3814, tri=3816, isDLC=true, itemSetIDs = {730, 731, 732, 734}, motif=3921},  --Oathsworn Pit
    [641] ={id=3852, hm=3853, tt=3854, nd=3855, tri=3857, isDLC=true, itemSetIDs = {735, 736, 737, 738}, motif=3922},  --Bedlam Veil
    [856] ={id=4110, hm=4111, tt=4112, nd=4113, tri=4115, isDLC=true, itemSetIDs = {794, 795, 796, 797}, motif=4159},  --Exiled Redoubt
    [858] ={id=4129, hm=4130, tt=4131, nd=4132, tri=4134, isDLC=true, itemSetIDs = {798, 799, 800, 801}, motif=4160},  --Lep Seclusa
    [1038]={id=4312, hm=4313, tt=4314, nd=4315, tri=4317, isDLC=true, itemSetIDs = {825, 826, 827, 829}, motif=nil}, --Naj-Caldeesh
    [1040]={id=4335, hm=4336, tt=4337, nd=4338, tri=4340, isDLC=true, itemSetIDs = {822, 823, 824, 828}, motif=nil}, --Black Gem Foundry
}

----------------------------------------------------------------
-- Records aus Normal/Vet automatisch matchen
----------------------------------------------------------------

local records = {}

local function buildRecords()
    if #records > 0 then return end

    local vetList = {}
    for _, v in pairs(VETERAN) do
        vetList[#vetList+1] = v
    end

    local function isSubset(sub, sup)
        if not (sub and sup) then return false end
        for _, sid in ipairs(sub) do
            local found = false
            for _, vsid in ipairs(sup) do
                if vsid == sid then
                    found = true
                    break
                end
            end
            if not found then return false end
        end
        return true
    end

    for _, n in pairs(NORMAL) do
        local matchedVet = nil
        for _, v in ipairs(vetList) do
            if isSubset(n.itemSetIDs, v.itemSetIDs) then
                matchedVet = v
                break
            end
        end

        records[#records+1] = {
            normal = n.id,
            vet    = matchedVet and matchedVet.id or nil,
            hm     = matchedVet and matchedVet.hm or nil,
            tt     = matchedVet and matchedVet.tt or nil,
            nd     = matchedVet and matchedVet.nd or nil,
            tri    = matchedVet and matchedVet.tri or nil,
            motif  = (matchedVet and matchedVet.motif) or n.motif,
            isDLC  = (matchedVet and matchedVet.isDLC ~= nil) and matchedVet.isDLC or n.isDLC,
        }
    end
end

local function ensureRecords()
    if #records == 0 then
        buildRecords()
    end
end

----------------------------------------------------------------
-- Lookup API
----------------------------------------------------------------

-- Lookup per einzelner Activity-ID 
function DFP.GetDungeonAchievementsByActivityId(activityId)
    ensureRecords()
    if not activityId then return nil end
    
    local n = NORMAL[activityId]
    local v = VETERAN[activityId]
    
    if not (n or v) then return nil end
    
    return {
        normal = n and n.id or nil,          
        vet    = v and v.id or nil,                  
        hm     = v and v.hm or nil,                   
        tt     = v and v.tt or nil,
        nd     = v and v.nd or nil,
        tri    = v and v.tri or nil,
        motif  = (v and v.motif) or (n and n.motif),
        isDLC  = (v and v.isDLC ~= nil) and v.isDLC or (n and n.isDLC),
    }
end

-- Wrapper für beide Activity-IDs (Normal + Veteran zusammengeführt)
function DFP.GetDungeonAchievementsForActivity(normalActId, vetActId)
    local out = {}

    -- Normal-Achievement
    if normalActId then
        local n = NORMAL[normalActId]  
        if n then
            out.normal = n.id
            out.motif  = n.motif
            out.isDLC  = n.isDLC
        end
    end

    -- Veteran + Sonder-Achievements
    if vetActId then
        local v = VETERAN[vetActId]  
        if v then
            out.vet   = v.id
            out.hm    = v.hm
            out.tt    = v.tt
            out.nd    = v.nd
            out.tri   = v.tri
            if v.motif ~= nil then out.motif = v.motif end
            if v.isDLC ~= nil then out.isDLC = v.isDLC end
        end
    end

    if not next(out) then
        return nil
    end
    return out
end

DFP.AchievementRecords = records