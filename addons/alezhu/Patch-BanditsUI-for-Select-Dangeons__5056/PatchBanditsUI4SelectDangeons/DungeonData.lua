-- PatchBanditsUI4SelectDangeons: Dungeon Database & Helper Functions
PatchBUI = PatchBUI or {}

PatchBUI.DungeonData = {
    [148]  = {name = "Arx Corinium",        normal = 272,  quest = 4202, vet = 1604, hm = 1609, pledge = 5288},
    [1389] = {name = "Bal Sunnar",           normal = 3468, quest = 6896, vet = 3469, hm = 3470, pledge = 6897},
    [1471] = {name = "Bedlam Veil",          normal = 3851, quest = 7155, vet = 3852, hm = 3853, pledge = 7156},
    [1228] = {name = "Black Drake Villa",    normal = 2831, quest = 6576, vet = 2832, hm = 2833, pledge = 6577},
    [38]   = {name = "Blackheart Haven",     normal = 410,  quest = 4589, vet = 1647, hm = 1652, pledge = 5305},
    [64]   = {name = "Blessed Crucible",     normal = 393,  quest = 4469, vet = 1641, hm = 1646, pledge = 5306},
    [973]  = {name = "Bloodroot Forge",      normal = 1690, quest = 5889, vet = 1691, hm = 1696, pledge = 6053},
    [1201] = {name = "Castle Thorn",         normal = 2704, quest = 6507, vet = 2705, hm = 2706, pledge = 6508},
    [176]  = {name = "City of Ash I",        normal = 551,  quest = 4778, vet = 1597, hm = 1602, pledge = 5290},
    [681]  = {name = "City of Ash II",       normal = 1603, quest = 5120, vet = 878,  hm = 1114, pledge = 5381},
    [1301] = {name = "Coral Aerie",          normal = 3104, quest = 6740, vet = 3105, hm = 3153, pledge = 6741},
    [848]  = {name = "Cradle of Shadows",    normal = 1522, quest = 5702, vet = 1523, hm = 1524, pledge = 5780},
    [130]  = {name = "Crypt of Hearts I",    normal = 80,   quest = 4379, vet = 1610, hm = 1615, pledge = 5283},
    [932]  = {name = "Crypt of Hearts II",   normal = 1616, quest = 5113, vet = 876,  hm = 1084, pledge = 5284},
    [63]   = {name = "Darkshade Caverns I",  normal = 78,   quest = 4145, vet = 1581, hm = 1586, pledge = 5274},
    [930]  = {name = "Darkshade Caverns II", normal = 1587, quest = 4641, vet = 464,  hm = 467,  pledge = 5275},
    [1081] = {name = "Depths of Malatar",    normal = 2270, quest = 6251, vet = 2271, hm = 2272, pledge = 6252},
    [449]  = {name = "Direfrost Keep",       normal = 357,  quest = 4346, vet = 1623, hm = 1628, pledge = 5291},
    [1360] = {name = "Earthen Root Enclave", normal = 3375, quest = 6835, vet = 3376, hm = 3377, pledge = 6836},
    [126]  = {name = "Elden Hollow I",       normal = 11,   quest = 4336, vet = 1573, hm = 1578, pledge = 5276},
    [931]  = {name = "Elden Hollow II",      normal = 1579, quest = 4675, vet = 459,  hm = 463,  pledge = 5277},
    [1496] = {name = "Exiled Redoubt",       normal = 4109, quest = 7235, vet = 4110, hm = 4111, pledge = 7236},
    [974]  = {name = "Falkreath Hold",       normal = 1698, quest = 5891, vet = 1699, hm = 1704, pledge = 6054},
    [1009] = {name = "Fang Lair",            normal = 1959, quest = 6064, vet = 1960, hm = 1965, pledge = 6155},
    [1080] = {name = "Frostvault",           normal = 2260, quest = 6249, vet = 2261, hm = 2262, pledge = 6250},
    [283]  = {name = "Fungal Grotto I",      normal = 294,  quest = 3993, vet = 1556, hm = 1561, pledge = 5247},
    [934]  = {name = "Fungal Grotto II",     normal = 1562, quest = 4303, vet = 343,  hm = 342,  pledge = 5248},
    [1361] = {name = "Graven Deep",          normal = 3394, quest = 6837, vet = 3395, hm = 3396, pledge = 6838},
    [1152] = {name = "Icereach",             normal = 2539, quest = 6414, vet = 2540, hm = 2541, pledge = 6415},
    [678]  = {name = "Imperial City Prison", normal = 1345, quest = 5136, vet = 880,  hm = 1303, pledge = 5382},
    [1123] = {name = "Lair of Maarselok",    normal = 2425, quest = 6351, vet = 2426, hm = 2427, pledge = 6352},
    [1497] = {name = "Lep Seclusa",          normal = 4128, quest = 7237, vet = 4129, hm = 4130, pledge = 7238},
    [1055] = {name = "March of Sacrifices",  normal = 2162, quest = 6188, vet = 2163, hm = 2164, pledge = 6189},
    [1052] = {name = "Moon Hunter Keep",     normal = 2152, quest = 6186, vet = 2153, hm = 2154, pledge = 6187},
    [1122] = {name = "Moongrave Fane",       normal = 2415, quest = 6349, vet = 2416, hm = 2417, pledge = 6350},
    [1470] = {name = "Oathsworn Pit",        normal = 3810, quest = 7105, vet = 3811, hm = 3812, pledge = 7106},
    [1267] = {name = "Red Petal Bastion",    normal = 3016, quest = 6683, vet = 3017, hm = 3018, pledge = 6684},
    [843]  = {name = "Ruins of Mazzatun",    normal = 1504, quest = 5403, vet = 1505, hm = 1506, pledge = 5636},
    [1010] = {name = "Scalecaller Peak",     normal = 1975, quest = 6065, vet = 1976, hm = 1981, pledge = 6154},
    [1390] = {name = "Scrivener's Hall",     normal = 3529, quest = 7027, vet = 3530, hm = 3531, pledge = 7028},
    [31]   = {name = "Selene's Web",         normal = 417,  quest = 4733, vet = 1635, hm = 1640, pledge = 5307},
    [1302] = {name = "Shipwright's Regret",  normal = 3114, quest = 6742, vet = 3115, hm = 3154, pledge = 6743},
    [144]  = {name = "Spindleclutch I",      normal = 301,  quest = 4054, vet = 1565, hm = 1570, pledge = 5260},
    [936]  = {name = "Spindleclutch II",     normal = 1571, quest = 4555, vet = 421,  hm = 448,  pledge = 5273},
    [1197] = {name = "Stone Garden",         normal = 2694, quest = 6505, vet = 2695, hm = 2755, pledge = 6506},
    [131]  = {name = "Tempest Island",       normal = 81,   quest = 4538, vet = 1617, hm = 1622, pledge = 5301},
    [380]  = {name = "The Banished Cells I", normal = 325,  quest = 4107, vet = 1549, hm = 1554, pledge = 5244},
    [935]  = {name = "The Banished Cells II",normal = 1555, quest = 4597, vet = 545,  hm = 451,  pledge = 5246},
    [1229] = {name = "The Cauldron",         normal = 2841, quest = 6578, vet = 2842, hm = 2843, pledge = 6579},
    [1268] = {name = "The Dread Cellar",     normal = 3026, quest = 6685, vet = 3027, hm = 3028, pledge = 6686},
    [1153] = {name = "Unhallowed Grave",     normal = 2549, quest = 6416, vet = 2550, hm = 2551, pledge = 6417},
    [11]   = {name = "Vaults of Madness",    normal = 570,  quest = 4822, vet = 1653, hm = 1658, pledge = 5309},
    [22]   = {name = "Volenfell",            normal = 391,  quest = 4432, vet = 1629, hm = 1634, pledge = 5303},
    [146]  = {name = "Wayrest Sewers I",     normal = 79,   quest = 4246, vet = 1589, hm = 1594, pledge = 5278},
    [933]  = {name = "Wayrest Sewers II",    normal = 1595, quest = 4813, vet = 678,  hm = 681,  pledge = 5282},
    [688]  = {name = "White-Gold Tower",     normal = 1346, quest = 5342, vet = 1120, hm = 1279, pledge = 5431},
    [1551] = {name = "Naj-Caldeesh",         normal = 4311, quest = 7320, vet = 4312, hm = 4313, pledge = 7321},
    [1552] = {name = "Black Gem Foundry",    normal = 4334, quest = 7323, vet = 4335, hm = 4336, pledge = 7324},
}

-- Check if story quest for dungeon is uncompleted
function PatchBUI.IsQuestUncompleted(zoneId)
    if not zoneId then return false end
    local info = PatchBUI.DungeonData[zoneId]
    if info and info.quest then
        local completedName = GetCompletedQuestInfo(info.quest)
        if completedName == nil or completedName == "" then
            return true
        end
        return false
    end
    return false
end

-- Check if dungeon is available (purchased / unlocked)
function PatchBUI.IsDungeonAvailable(data)
    if not data then return false end

    -- Check direct isLocked boolean
    if data.isLocked == true then return false end

    -- Check IsLocked method on node data
    if type(data.IsLocked) == "function" then
        local ok, locked = pcall(data.IsLocked, data)
        if ok and locked then return false end
    end

    -- Check Activity Finder root manager
    if ZO_ACTIVITY_FINDER_ROOT_MANAGER and type(ZO_ACTIVITY_FINDER_ROOT_MANAGER.IsLocationLocked) == "function" then
        local ok, locked = pcall(ZO_ACTIVITY_FINDER_ROOT_MANAGER.IsLocationLocked, ZO_ACTIVITY_FINDER_ROOT_MANAGER, data)
        if ok and locked then return false end
    end

    return true
end

-- Determine whether Veteran difficulty is selected in the Group section
function PatchBUI.IsVeteranGroupDifficulty()
    if ZO_ConvertToIsVeteranDifficulty and ZO_GetEffectiveDungeonDifficulty then
        return ZO_ConvertToIsVeteranDifficulty(ZO_GetEffectiveDungeonDifficulty())
    end
    if ZO_GetEffectiveDungeonDifficulty and DUNGEON_DIFFICULTY_VETERAN then
        return ZO_GetEffectiveDungeonDifficulty() == DUNGEON_DIFFICULTY_VETERAN
    end
    if IsUnitGrouped and IsUnitGrouped("player") and IsGroupUsingVeteranDifficulty then
        return IsGroupUsingVeteranDifficulty()
    end
    if IsUnitUsingVeteranDifficulty then
        return IsUnitUsingVeteranDifficulty("player")
    end
    return false
end

-- Returns container index (2 = Normal, 3 = Veteran)
function PatchBUI.GetTargetContainerIndex()
    return PatchBUI.IsVeteranGroupDifficulty() and 3 or 2
end

-- Get active Undaunted pledges from quest journal
function PatchBUI.GetJournalPledges()
    local pledges = {}
    local haveQuest = false
    for i = 1, MAX_JOURNAL_QUESTS do
        local name, _, _, stepType, _, completed, _, _, _, questType, instanceType = GetJournalQuestInfo(i)
        if name and name ~= "" and not completed and questType == QUEST_TYPE_UNDAUNTED_PLEDGE and instanceType == INSTANCE_TYPE_GROUP then
            pledges[name] = (stepType ~= QUEST_STEP_TYPE_AND)
            if stepType == QUEST_STEP_TYPE_AND then
                haveQuest = true
            end
        end
    end
    return pledges, haveQuest
end
