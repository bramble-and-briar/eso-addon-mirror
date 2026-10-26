BF.BuildRecorder = {}

local LINK_STYLE = LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT or 0

local function AddSlot(slots, slotId, name)
    if slotId ~= nil then table.insert(slots, { id = slotId, name = name }) end
end

local function GetEquipSlots()
    local slots = {}
    AddSlot(slots, EQUIP_SLOT_HEAD, "Head")
    AddSlot(slots, EQUIP_SLOT_SHOULDERS, "Shoulders")
    AddSlot(slots, EQUIP_SLOT_CHEST, "Chest")
    AddSlot(slots, EQUIP_SLOT_HAND, "Hands")
    AddSlot(slots, EQUIP_SLOT_WAIST, "Waist")
    AddSlot(slots, EQUIP_SLOT_LEGS, "Legs")
    AddSlot(slots, EQUIP_SLOT_FEET, "Feet")
    AddSlot(slots, EQUIP_SLOT_NECK, "Neck")
    AddSlot(slots, EQUIP_SLOT_RING1, "Ring 1")
    AddSlot(slots, EQUIP_SLOT_RING2, "Ring 2")
    AddSlot(slots, EQUIP_SLOT_MAIN_HAND, "Main Hand")
    AddSlot(slots, EQUIP_SLOT_OFF_HAND, "Off Hand")
    AddSlot(slots, EQUIP_SLOT_BACKUP_MAIN, "Back Bar Main")
    AddSlot(slots, EQUIP_SLOT_BACKUP_OFF, "Back Bar Off")
    return slots
end

local function HasWornItem(equipSlot)
    if not BAG_WORN then return false end
    if HasItemInSlot then return HasItemInSlot(BAG_WORN, equipSlot) end
    if GetWornItemInfo then
        local slotHasItem = GetWornItemInfo(BAG_WORN, equipSlot)
        return slotHasItem == true
    end
    return false
end

local function GetItemLinkValue(fn, link, fallback)
    if not fn or not link or link == "" then return fallback end
    local ok, value = pcall(fn, link)
    if ok then return value end
    return fallback
end

local function GetSetInfo(link)
    if not GetItemLinkSetInfo or not link or link == "" then return false, "", 0 end
    local ok, hasSet, setName, _, _, _, setId = pcall(GetItemLinkSetInfo, link, false)
    if ok then return hasSet, setName or "", setId or 0 end
    return false, "", 0
end

local function GetTraitInfo(link)
    if not GetItemLinkTraitInfo or not link or link == "" then return 0, "" end
    local ok, traitType, traitDescription = pcall(GetItemLinkTraitInfo, link)
    if ok then return traitType or 0, traitDescription or "" end
    return 0, ""
end

local function BuildGearItem(slot)
    if not HasWornItem(slot.id) then return nil end
    local link = GetItemLink and GetItemLink(BAG_WORN, slot.id, LINK_STYLE) or ""
    local _, _, _, _, _, equipType, itemStyleId, functionalQuality, displayQuality = GetItemInfo(BAG_WORN, slot.id)
    local hasSet, setName, setId = GetSetInfo(link)
    local traitType, traitDescription = GetTraitInfo(link)
    return {
        equipSlot = slot.id,
        slotName = slot.name,
        link = link,
        itemName = GetItemLinkValue(GetItemLinkName, link, "Unknown Item"),
        itemId = GetItemLinkValue(GetItemLinkItemId, link, 0),
        icon = GetItemLinkValue(GetItemLinkIcon, link, ""),
        hasSet = hasSet,
        setName = setName,
        setId = setId,
        traitType = traitType,
        traitDescription = traitDescription,
        enchantId = GetItemLinkValue(GetItemLinkFinalEnchantId, link, 0),
        armorType = GetItemLinkValue(GetItemLinkArmorType, link, 0),
        weaponType = GetItemLinkValue(GetItemLinkWeaponType, link, 0),
        requiredLevel = GetItemLinkValue(GetItemLinkRequiredLevel, link, 0),
        requiredChampionPoints = GetItemLinkValue(GetItemLinkRequiredChampionPoints, link, 0),
        equipType = equipType or 0,
        itemStyleId = itemStyleId or 0,
        functionalQuality = functionalQuality or 0,
        displayQuality = displayQuality or 0,
    }
end

local function RecordGear()
    local gear = {}
    for _, slot in ipairs(GetEquipSlots()) do
        local item = BuildGearItem(slot)
        if item then table.insert(gear, item) end
    end
    return gear
end

local function RecordAttributes()
    return {
        health = GetAttributeSpentPoints and GetAttributeSpentPoints(ATTRIBUTE_HEALTH) or 0,
        magicka = GetAttributeSpentPoints and GetAttributeSpentPoints(ATTRIBUTE_MAGICKA) or 0,
        stamina = GetAttributeSpentPoints and GetAttributeSpentPoints(ATTRIBUTE_STAMINA) or 0,
        unspent = GetAttributeUnspentPoints and GetAttributeUnspentPoints() or 0,
    }
end

local function RecordMundus()
    local mundus = {}
    if not GetUnitActiveMundusStoneBuffIndices or not GetUnitBuffInfo then return mundus end
    local indices = { GetUnitActiveMundusStoneBuffIndices("player") }
    for _, buffIndex in ipairs(indices) do
        local buffName, _, _, _, _, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
        table.insert(mundus, {
            name = buffName or "Unknown Mundus",
            icon = icon or "",
            abilityId = abilityId or 0,
            mundusStone = GetAbilityMundusStoneType and GetAbilityMundusStoneType(abilityId or 0) or 0,
        })
    end
    return mundus
end

local function RecordBar(category, label)
    local skills = {}
    if not GetAssignableAbilityBarStartAndEndSlots then return skills end
    local startSlot, endSlot = GetAssignableAbilityBarStartAndEndSlots()
    for slotIndex = startSlot, endSlot do
        local used = IsSlotUsed and IsSlotUsed(slotIndex, category) or false
        if used then
            local actionId = GetSlotBoundId and GetSlotBoundId(slotIndex, category) or 0
            local skillType, skillLineIndex, skillIndex, morphChoice, rank
            if GetSpecificSkillAbilityKeysByAbilityId and actionId and actionId ~= 0 then
                skillType, skillLineIndex, skillIndex, morphChoice, rank = GetSpecificSkillAbilityKeysByAbilityId(actionId)
            end
            local abilityIndex
            if GetNumAbilities and GetAbilityIdByIndex then
                for i = 1, GetNumAbilities() do
                    if GetAbilityIdByIndex(i) == actionId then abilityIndex = i break end
                end
            end
            table.insert(skills, {
                hotbar = label,
                hotbarCategory = category,
                slotIndex = slotIndex,
                actionId = actionId,
                actionType = GetSlotType and GetSlotType(slotIndex, category) or 0,
                name = GetSlotName and GetSlotName(slotIndex, category) or "Unknown Skill",
                texture = GetSlotTexture and GetSlotTexture(slotIndex, category) or "",
                skillType = skillType,
                skillLineIndex = skillLineIndex,
                skillIndex = skillIndex,
                morphChoice = morphChoice,
                rank = rank,
                abilityIndex = abilityIndex,
            })
        end
    end
    return skills
end

local function RecordChampionSkills()
    local skills = {}
    if not GetNumChampionDisciplines or not GetNumChampionDisciplineSkills or not GetChampionSkillId or not GetNumPointsSpentOnChampionSkill then return skills end
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId and GetChampionDisciplineId(disciplineIndex) or disciplineIndex
        for skillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local championSkillId = GetChampionSkillId(disciplineIndex, skillIndex)
            local points = championSkillId and GetNumPointsSpentOnChampionSkill(championSkillId) or 0
            if championSkillId and points and points > 0 then
                table.insert(skills, {
                    championSkillId = championSkillId,
                    disciplineIndex = disciplineIndex,
                    disciplineId = disciplineId,
                    skillIndex = skillIndex,
                    points = points,
                    name = GetChampionSkillName and GetChampionSkillName(championSkillId) or "",
                    skillType = GetChampionSkillType and GetChampionSkillType(championSkillId) or 0,
                })
            end
        end
    end
    return skills
end

local function RecordSkills()
    local skills = {}
    local bars = {
        { category = HOTBAR_CATEGORY_PRIMARY, label = "Front Bar" },
        { category = HOTBAR_CATEGORY_BACKUP, label = "Back Bar" },
    }
    for _, bar in ipairs(bars) do
        for _, skill in ipairs(RecordBar(bar.category, bar.label)) do table.insert(skills, skill) end
    end
    return skills
end

local function RecordChampionSlots()
    local slots = {}
    if not GetAssignableChampionBarStartAndEndSlots then return slots end
    local startSlot, endSlot = GetAssignableChampionBarStartAndEndSlots()
    for slotIndex = startSlot, endSlot do
        local used = IsSlotUsed and IsSlotUsed(slotIndex, HOTBAR_CATEGORY_CHAMPION) or false
        if used then
            table.insert(slots, {
                slotIndex = slotIndex,
                championSkillId = GetSlotBoundId and GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION) or 0,
                name = GetSlotName and GetSlotName(slotIndex, HOTBAR_CATEGORY_CHAMPION) or "Unknown CP",
            })
        end
    end
    return slots
end

function BF.BuildRecorder.RecordCurrentBuild(nameOverride)
    local build = {
        id = BF.MakeBuildId(),
        name = nameOverride or (BF.GetPlayerName() .. " Build"),
        author = BF.GetDisplayAuthor(),
        characterName = BF.GetPlayerName(),
        className = GetUnitClass and GetUnitClass("player") or "",
        classId = GetUnitClassId and GetUnitClassId("player") or 0,
        raceName = GetUnitRace and GetUnitRace("player") or "",
        level = GetUnitLevel and GetUnitLevel("player") or 0,
        championPoints = GetUnitChampionPoints and GetUnitChampionPoints("player") or 0,
        timestamp = GetTimeStamp(),
        gear = RecordGear(),
        attributes = RecordAttributes(),
        mundus = RecordMundus(),
        skills = RecordSkills(),
        championSlots = RecordChampionSlots(),
        championSkills = RecordChampionSkills(),
    }
    build.gearCount = #build.gear
    BF.savedVars.builds[build.id] = build
    BF.Chat(string.format("Recorded build '%s' with %d gear pieces.", build.name, build.gearCount))
    return build
end
