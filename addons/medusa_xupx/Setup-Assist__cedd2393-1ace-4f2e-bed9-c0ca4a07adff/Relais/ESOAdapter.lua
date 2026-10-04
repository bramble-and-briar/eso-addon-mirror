-- ESO API boundary. No PC-only aliases, no respec and no item-link substitution.
local R = Relais
local Adapter = {}
Adapter.__index = Adapter

local function Slots()
    return {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_HAND,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET, EQUIP_SLOT_NECK,
        EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
        EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF,
    }
end

local function UID(bag, slot)
    if not GetItemLink(bag, slot, LINK_STYLE_DEFAULT):match("%S") then return "0" end
    return Id64ToString(GetItemUniqueId(bag, slot))
end

local function SkillRange() return GetAssignableAbilityBarStartAndEndSlots() end
local function Categories() return { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP } end

local function Components(value)
    if value == nil then return { gear = true, skills = true, champion = true } end
    if type(value) ~= "table" then return nil end
    for key, enabled in pairs(value) do
        if (key ~= "gear" and key ~= "skills" and key ~= "champion") or type(enabled) ~= "boolean" then return nil end
    end
    local selected = { gear = value.gear == true, skills = value.skills == true, champion = value.champion == true }
    return (selected.gear or selected.skills or selected.champion) and selected or nil
end

local function FormatName(template, name, fallback)
    local value = tostring(name or fallback)
    local formatter = rawget(_G, "zo_strformat")
    if type(formatter) == "function" and template then return formatter(template, value) end
    return value
end

local function ItemName(name) return FormatName(rawget(_G, "SI_TOOLTIP_ITEM_NAME"), name, "cet objet") end
local function SkillName(name) return FormatName(rawget(_G, "SI_ABILITY_NAME"), name, "cette compétence") end

local function OptionalCall(name, ...)
    local callback = rawget(_G, name)
    if type(callback) ~= "function" then return end
    local ok, a, b, c, d, e, f, g = pcall(callback, ...)
    if ok then return a, b, c, d, e, f, g end
end

local function OptionalText(value)
    if type(value) == "string" and value:find("%S") then return value end
end

local function ReadGear(slot)
    local saved = { uid = UID(BAG_WORN, slot), name = ItemName(GetItemName(BAG_WORN, slot)) }
    local link = OptionalText(OptionalCall("GetItemLink", BAG_WORN, slot, LINK_STYLE_DEFAULT))
    if link then
        saved.link = link
        saved.icon = OptionalText(OptionalCall("GetItemLinkIcon", link)) or OptionalText(OptionalCall("GetItemLinkInfo", link))
        local hasSet, setName, _, _, maxCount, setId = OptionalCall("GetItemLinkSetInfo", link, false)
        if hasSet and OptionalText(setName) then
            local ok, formatted = pcall(FormatName, rawget(_G, "SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT"), setName, setName)
            if ok then saved.setName = OptionalText(formatted) end
            saved.setId, saved.setMaxCount = setId, maxCount
        end
        local equipType = OptionalCall("GetItemLinkEquipType", link)
        if equipType ~= nil then saved.twoHanded = equipType == rawget(_G, "EQUIP_TYPE_TWO_HAND") end
    end
    return saved
end

local function ReadCurrentProfile(strict)
    local profile = { gear = {}, skills = {}, champion = {}, schema = 1 }
    for _, slot in ipairs(Slots()) do profile.gear[slot] = ReadGear(slot) end
    local first, last = SkillRange()
    for _, category in ipairs(Categories()) do
        local bar = {}
        for slot = first, last do
            local id = GetSlotBoundId(slot, category)
            local kind = GetSlotType(slot, category)
            local saved = { id = id, type = kind, name = SkillName(GetSlotName(slot, category)),
                icon = OptionalText(OptionalCall("GetSlotTexture", slot, category)) }
            if id ~= 0 then
                if kind == ACTION_TYPE_CRAFTED_ABILITY then
                    local a, b, c
                    if strict then a, b, c = GetCraftedAbilityActiveScriptIds(id)
                    else a, b, c = OptionalCall("GetCraftedAbilityActiveScriptIds", id) end
                    if strict or a ~= nil then saved.scripts = { a, b, c } end
                elseif kind == ACTION_TYPE_ABILITY then
                    if strict then
                        local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id)
                        if not progression then return nil, "Cette barre spéciale ne peut pas être mémorisée." end
                        saved.morph = progression:GetMorphSlot()
                    else
                        local manager = rawget(_G, "SKILLS_DATA_MANAGER")
                        if manager then
                            local ok, morph = pcall(function()
                                local progression = manager:GetProgressionDataByAbilityId(id)
                                return progression and progression:GetMorphSlot()
                            end)
                            if ok then saved.morph = morph end
                        end
                    end
                elseif strict then return nil, "Cette barre spéciale ne peut pas être mémorisée." end
            end
            bar[slot] = saved
        end
        profile.skills[category] = bar
    end
    local start, finish = GetAssignableChampionBarStartAndEndSlots()
    for slot = start, finish do profile.champion[slot] = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) end
    return profile
end

function Adapter.New() return setmetatable({}, Adapter) end
function Adapter:Now() return GetGameTimeMilliseconds() end

function Adapter:IsReady(components)
    local selected = Components(components)
    if not selected then return false, "Choisis les composants du setup à charger." end
    if R.bankTransfer ~= nil then return false, "Attends la fin du transfert bancaire." end
    if not IsPlayerActivated() then return false, "En attente de la fin du chargement." end
    if IsUnitDeadOrReincarnating("player") then return false, "En attente de la résurrection." end
    if IsUnitInCombat("player") then return false, "En attente de la sortie de combat." end
    local category = GetActiveHotbarCategory()
    if category ~= HOTBAR_CATEGORY_PRIMARY and category ~= HOTBAR_CATEGORY_BACKUP then
        return false, "En attente du retour aux barres normales."
    end
    if selected.skills and SKILLS_AND_ACTION_BAR_MANAGER:DoesSkillPointAllocationModeBatchSave() then
        return false, "Termine ou annule la réinitialisation des compétences."
    end
    if selected.skills and SKILL_POINT_ALLOCATION_MANAGER:IsAnyChangePending() then
        return false, "Termine les modifications de points de compétences."
    end
    if selected.champion and CHAMPION_PERKS and type(CHAMPION_PERKS.IsInRespecMode) == "function" and CHAMPION_PERKS:IsInRespecMode() then
        return false, "Termine ou annule la réinitialisation des points Champion."
    end
    if selected.champion and CHAMPION_DATA_MANAGER and CHAMPION_DATA_MANAGER:HasUnsavedChanges() then
        return false, "Termine les modifications de points Champion."
    end
    if selected.champion and CHAMPION_PERKS and CHAMPION_PERKS.championBar and CHAMPION_PERKS:HasUnsavedChanges() then
        return false, "Termine les modifications manuelles de la barre Champion."
    end
    local active = R.engine and R.engine.active
    local inflight = active and active.operation and active.operation.accepted
    local request = inflight and active or R.engine and (R.engine.pending or active)
    local profile = request and request.profile
    if selected.champion and profile and profile.champion and not (inflight and active.operation.value.kind == "champion") then
        local changes = false
        for slot, id in pairs(profile.champion) do
            if GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) ~= id then changes = true; break end
        end
        if changes and GetChampionPurchaseAvailability() ~= CHAMPION_PURCHASE_SUCCESS then
            return false, "En attente de la disponibilité des étoiles Champion (délai du jeu)."
        end
    end
    return true
end

function Adapter:ResolveSkill(saved)
    if saved.id == 0 then return nil, nil, 0 end
    local skill
    if saved.type == ACTION_TYPE_CRAFTED_ABILITY then
        local skillType, line, index = GetSkillAbilityIndicesFromCraftedAbilityId(saved.id)
        if skillType then skill = SKILLS_DATA_MANAGER:GetSkillDataByIndices(skillType, line, index) end
        if skill and saved.scripts then
            local a, b, c = GetCraftedAbilityActiveScriptIds(saved.id)
            if a ~= saved.scripts[1] or b ~= saved.scripts[2] or c ~= saved.scripts[3] then
                return nil, "Les scripts ont changé : " .. SkillName(saved.name)
            end
        end
        if skill then return skill, nil, saved.id end
    else
        local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(saved.id)
        skill = progression and progression:GetSkillData()
        if skill then
            local current = skill:GetCurrentProgressionData()
            if not current or current:GetMorphSlot() ~= saved.morph then
                return nil, "Le morphe a changé : " .. SkillName(saved.name)
            end
            return skill, nil, current:GetAbilityId()
        end
    end
    return nil, "Compétence introuvable : " .. SkillName(saved.name)
end

function Adapter:Capture()
    local ready, problem = self:IsReady()
    if not ready then return nil, problem end
    if SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges() then
        return nil, "Attends la validation de tes dernières compétences."
    end
    return ReadCurrentProfile(true)
end

function Adapter:Preview() return ReadCurrentProfile(false) end

local function OptionalMethod(object, name, ...)
    if not object then return end
    local arguments = { ... }
    local ok, value = pcall(function()
        local method = object[name]
        if type(method) == "function" then return method(object, unpack(arguments)) end
    end)
    if ok then return value end
end

local function ChampionAvailable(id, slot)
    if id == 0 then return true end
    if type(id) ~= "number" or id < 0 or id ~= math.floor(id) then return false end
    local data = CHAMPION_DATA_MANAGER:GetChampionSkillData(id)
    return data ~= nil and data:IsTypeSlottable() and data:IsPurchased()
        and WouldChampionSkillNodeBeUnlocked(id, GetNumPointsSpentOnChampionSkill(id))
        and data:GetChampionDisciplineData():GetId() == GetRequiredChampionDisciplineIdForSlot(slot, HOTBAR_CATEGORY_CHAMPION)
end

-- Inspection reads the current character and never prepares or sends a change.
-- Set counts are a comparison of the stored pieces, not a promise of active buffs.
function Adapter:InspectProfile(profile)
    local result = { gear = {}, skills = {}, champion = {}, sets = {}, summary = {
        missingGear = 0, differentGear = 0, differentSkills = 0, differentChampion = 0,
        unavailableSkills = 0, unavailableChampion = 0, blockers = {},
    } }
    local summary = result.summary
    local function Block(entry, message)
        entry.available, entry.problem = false, message
        summary.blockers[#summary.blockers + 1] = message
    end
    profile = type(profile) == "table" and profile or {}
    local inventoryOK, inventory = pcall(self.Inventory, self)
    if not inventoryOK then inventory = {} end
    local actualGear, gearSeen = {}, {}
    for _, slot in ipairs(Slots()) do
        local saved = type(profile.gear) == "table" and profile.gear[slot] or nil
        local entry = { uid = saved and saved.uid, name = ItemName(saved and saved.name),
            link = saved and saved.link, icon = saved and saved.icon, setName = saved and saved.setName,
            available = false, equipped = false, different = true, missing = false, empty = saved and saved.uid == "0" or false }
        result.gear[slot] = entry
        if entry.empty then entry.name = "Emplacement vide" end
        if OptionalText(entry.link) then
            entry.icon = OptionalText(OptionalCall("GetItemLinkIcon", entry.link)) or entry.icon
        end
        local ok, problem = pcall(function()
            actualGear[slot] = ReadGear(slot)
            entry.equipped = saved ~= nil and actualGear[slot].uid == saved.uid
            entry.different = not entry.equipped
            if not saved or type(saved.uid) ~= "string" then return "Équipement sauvegardé invalide. Réenregistre ce setup." end
            local item = inventory[saved.uid]
            if saved.uid == "0" then entry.available = true; return end
            if gearSeen[saved.uid] then return "Un objet est affecté à deux emplacements : " .. entry.name end
            gearSeen[saved.uid] = true
            if not item then entry.missing = true; return "Objet absent du sac : " .. entry.name end
            if not IsEquipable(item.bag, item.slot) then return "Objet impossible à équiper : " .. entry.name end
            entry.available = true
            local link = OptionalText(OptionalCall("GetItemLink", item.bag, item.slot, LINK_STYLE_DEFAULT))
            entry.link = link or entry.link
            entry.icon = OptionalText(OptionalCall("GetItemLinkIcon", entry.link)) or OptionalText(OptionalCall("GetItemLinkInfo", entry.link)) or entry.icon
            local hasSet, name, _, _, maximum, setId = OptionalCall("GetItemLinkSetInfo", entry.link, false)
            if hasSet and OptionalText(name) then
                entry.setName = FormatName(rawget(_G, "SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT"), name, name)
                entry.setId, entry.setMaxCount = setId, maximum
            end
        end)
        if not ok then Block(entry, "Impossible de lire cet objet. Réessaie après le chargement.")
        elseif problem then Block(entry, problem) end
        if entry.missing then summary.missingGear = summary.missingGear + 1 end
        if entry.different then summary.differentGear = summary.differentGear + 1 end
    end
    local first, last = SkillRange()
    for _, category in ipairs(Categories()) do
        local bar, seen = {}, {}
        result.skills[category] = bar
        for slot = first, last do
            local saved = type(profile.skills) == "table" and type(profile.skills[category]) == "table" and profile.skills[category][slot] or nil
            local entry = { id = saved and saved.id, type = saved and saved.type, name = SkillName(saved and saved.name),
                icon = saved and saved.icon, available = false, equipped = false, different = true, empty = saved and saved.id == 0 or false }
            bar[slot] = entry
            if entry.empty then entry.name = "Emplacement vide" end
            if saved and saved.id ~= 0 then
                if saved.type == ACTION_TYPE_CRAFTED_ABILITY then
                    entry.icon = OptionalText(OptionalCall("GetCraftedAbilityIcon", saved.id)) or entry.icon
                elseif saved.type == ACTION_TYPE_ABILITY then
                    entry.icon = OptionalText(OptionalCall("GetAbilityIcon", saved.id)) or entry.icon
                end
            end
            local ok, problem = pcall(function()
                if not saved or type(saved.id) ~= "number" then return "Compétence sauvegardée invalide. Réenregistre ce setup." end
                local skill, why, expected = self:ResolveSkill(saved)
                if why then return why end
                entry.equipped = self:Satisfied({ kind = "skill", slot = slot, category = category, saved = saved, expected = expected })
                entry.different = not entry.equipped
                local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(category)
                if saved.id ~= 0 then
                    entry.icon = entry.icon or (saved.type == ACTION_TYPE_ABILITY and OptionalText(OptionalCall("GetAbilityIcon", expected)) or nil)
                    if seen[expected] then return "Compétence présente deux fois sur une barre : " .. entry.name end
                    seen[expected] = true
                    if not skill:IsPurchased() or skill:IsPassive() or not skill:GetSkillLineData():IsActive() then return "Compétence indisponible : " .. entry.name end
                    if entry.different and hotbar:GetExpectedSkillSlotResult(slot, skill) ~= HOT_BAR_RESULT_SUCCESS then return "Compétence impossible à placer : " .. entry.name end
                    local previous = hotbar:FindSlotMatchingSkill(skill)
                    if entry.different and previous and previous ~= slot and hotbar:GetExpectedSlotEditResult(previous) ~= HOT_BAR_RESULT_SUCCESS then
                        return "L'ancien emplacement de cette compétence est verrouillé : " .. entry.name
                    end
                elseif entry.different and hotbar:GetExpectedSlotEditResult(slot) ~= HOT_BAR_RESULT_SUCCESS then
                    return "Un emplacement de compétence est verrouillé."
                end
                entry.available = true
            end)
            if not ok then Block(entry, "Impossible de lire cette compétence. Réessaie après le chargement.")
            elseif problem then Block(entry, problem) end
            if not entry.available then summary.unavailableSkills = summary.unavailableSkills + 1 end
            if entry.different then summary.differentSkills = summary.differentSkills + 1 end
        end
    end
    local start, finish = GetAssignableChampionBarStartAndEndSlots()
    local championSeen = {}
    for slot = start, finish do
        local id = type(profile.champion) == "table" and profile.champion[slot] or nil
        local entry = { id = id, name = "Emplacement Champion vide", available = false, equipped = false, different = true, empty = id == 0 }
        result.champion[slot] = entry
        local ok, problem = pcall(function()
            if type(id) ~= "number" then return "Étoiles Champion sauvegardées invalides. Réenregistre ce setup." end
            if id ~= 0 then
                entry.name = SkillName(OptionalText(OptionalCall("GetChampionSkillName", id)) or "cette étoile Champion")
                local data = CHAMPION_DATA_MANAGER:GetChampionSkillData(id)
                entry.icon = OptionalMethod(OptionalMethod(data, "GetChampionDisciplineData"), "GetPointPoolIcon")
            end
            entry.equipped = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) == id
            entry.different = not entry.equipped
            if not ChampionAvailable(id, slot) then return "Étoile Champion indisponible : " .. entry.name end
            if id ~= 0 and championSeen[id] then return "Une étoile Champion est affectée deux fois : " .. entry.name end
            if id ~= 0 then championSeen[id] = true end
            entry.available = true
        end)
        if not ok then Block(entry, "Impossible de lire cette étoile Champion. Réessaie après le chargement.")
        elseif problem then Block(entry, problem) end
        if not entry.available then summary.unavailableChampion = summary.unavailableChampion + 1 end
        if entry.different then summary.differentChampion = summary.differentChampion + 1 end
    end
    for _, category in ipairs(Categories()) do
        local counts = {}
        local function Add(item, field, slot)
            if not item or item.uid == "0" or not OptionalText(item.link) then return end
            local hasSet, name, _, _, maximum, setId = OptionalCall("GetItemLinkSetInfo", item.link, false)
            if not hasSet or not OptionalText(name) then return end
            local key = setId and setId > 0 and setId or name
            local row = counts[key]
            if not row then
                row = { id = setId, name = FormatName(rawget(_G, "SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT"), name, name), count = 0, targetCount = 0, maxCount = maximum }
                counts[key] = row
            end
            local equipType = OptionalCall("GetItemLinkEquipType", item.link)
            local main = slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_BACKUP_MAIN
            row[field] = row[field] + (main and equipType ~= nil and equipType == rawget(_G, "EQUIP_TYPE_TWO_HAND") and 2 or 1)
        end
        for _, slot in ipairs(Slots()) do
            local weapon = slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_OFF_HAND or slot == EQUIP_SLOT_BACKUP_MAIN or slot == EQUIP_SLOT_BACKUP_OFF
            local included = not weapon or (category == HOTBAR_CATEGORY_PRIMARY and (slot == EQUIP_SLOT_MAIN_HAND or slot == EQUIP_SLOT_OFF_HAND))
                or (category == HOTBAR_CATEGORY_BACKUP and (slot == EQUIP_SLOT_BACKUP_MAIN or slot == EQUIP_SLOT_BACKUP_OFF))
            if included then Add(result.gear[slot], "targetCount", slot); Add(actualGear[slot], "count", slot) end
        end
        local rows = {}
        for _, row in pairs(counts) do rows[#rows + 1] = row end
        table.sort(rows, function(a, b) return a.name == b.name and tostring(a.id) < tostring(b.id) or a.name < b.name end)
        result.sets[category] = rows
    end
    result.canApply = #summary.blockers == 0
    result.problem = summary.blockers[1]
    return result
end

function Adapter:Inventory()
    local items = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local id = UID(BAG_BACKPACK, slot)
        if id ~= "0" then items[id] = { bag = BAG_BACKPACK, slot = slot } end
    end
    for _, slot in ipairs(Slots()) do
        local id = UID(BAG_WORN, slot)
        if id ~= "0" then items[id] = { bag = BAG_WORN, slot = slot } end
    end
    return items
end

function Adapter:BuildPlan(profile, components)
    local selected = Components(components)
    if not selected then return nil, "Choisis les composants du setup à charger." end
    if (selected.gear and type(profile.gear) ~= "table") or (selected.skills and type(profile.skills) ~= "table") then
        return nil, "Sauvegarde incomplète : réenregistre ce setup."
    end
    if selected.skills and SKILLS_AND_ACTION_BAR_MANAGER:HasAnyPendingChanges() then
        return nil, "Des compétences sont déjà en cours de modification. Réessaie après validation."
    end
    local plan = {}
    if selected.gear then
        local items, seen, removals, removalCount = self:Inventory(), {}, {}, 0
        local gearChanges = false
        for _, slot in ipairs(Slots()) do
            local saved = profile.gear[slot]
            if not saved or type(saved.uid) ~= "string" then return nil, "Équipement sauvegardé invalide." end
            if UID(BAG_WORN, slot) ~= saved.uid then gearChanges = true end
            if saved.uid ~= "0" then
                if seen[saved.uid] then return nil, "Un objet est affecté à deux emplacements." end
                seen[saved.uid] = true
                local item = items[saved.uid]
                if not item then return nil, "Objet absent du sac : " .. ItemName(saved.name) end
                if not IsEquipable(item.bag, item.slot) then return nil, "Objet impossible à équiper : " .. ItemName(saved.name) end
                if item.bag == BAG_WORN and item.slot ~= slot and not removals[item.slot] then
                    removals[item.slot] = true
                    removalCount = removalCount + 1
                    table.insert(plan, { kind = "unequip", slot = item.slot, uid = saved.uid, label = ItemName(saved.name) })
                end
            end
        end
        -- Remove a changing mythic before equipping a mythic in another slot.
        for _, slot in ipairs(Slots()) do
            local current = UID(BAG_WORN, slot)
            if current ~= "0" and current ~= profile.gear[slot].uid and not removals[slot] and
               GetItemLinkDisplayQuality(GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then
                removals[slot] = true
                removalCount = removalCount + 1
                table.insert(plan, { kind = "unequip", slot = slot, uid = current, label = ItemName(GetItemName(BAG_WORN, slot)) })
            end
        end
        local emptyCount = 0
        for _, slot in ipairs(Slots()) do
            if profile.gear[slot].uid == "0" and UID(BAG_WORN, slot) ~= "0" and not removals[slot] then
                emptyCount = emptyCount + 1
            end
        end
        local requiredSpace = math.max(gearChanges and 2 or 0, removalCount + emptyCount)
        if GetNumBagFreeSlots(BAG_BACKPACK) < requiredSpace then
            return nil, "Libère " .. tostring(requiredSpace) .. " places dans le sac pour ce changement."
        end
        for _, slot in ipairs(Slots()) do
            local saved = profile.gear[slot]
            if saved.uid ~= "0" and UID(BAG_WORN, slot) ~= saved.uid then
                table.insert(plan, { kind = "equip", slot = slot, uid = saved.uid,
                    beforeUID = removals[slot] and "0" or UID(BAG_WORN, slot), label = ItemName(saved.name) })
            end
        end
        for _, slot in ipairs(Slots()) do
            if profile.gear[slot].uid == "0" and UID(BAG_WORN, slot) ~= "0" and not removals[slot] then
                table.insert(plan, { kind = "unequip", slot = slot, uid = UID(BAG_WORN, slot), label = "emplacement vide" })
            end
        end
    end
    if selected.skills then
        local first, last = SkillRange()
        for _, category in ipairs(Categories()) do
            local bar = profile.skills[category]
            if type(bar) ~= "table" then return nil, "Barre de compétences manquante." end
            local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(category)
            local abilities = {}
            for slot = first, last do
                local saved = bar[slot]
                if not saved or type(saved.id) ~= "number" then return nil, "Compétence sauvegardée invalide." end
                local skill, problem, expected = self:ResolveSkill(saved)
                if problem then return nil, problem end
                local op = { kind = "skill", slot = slot, category = category, saved = saved, expected = expected, label = SkillName(saved.name) }
                local matches = self:Satisfied(op)
                if saved.id ~= 0 then
                    if abilities[expected] then return nil, "Compétence présente deux fois sur une barre." end
                    abilities[expected] = true
                    if not skill:IsPurchased() or skill:IsPassive() or not skill:GetSkillLineData():IsActive() then
                        return nil, "Compétence indisponible : " .. SkillName(saved.name)
                    end
                    if not matches and hotbar:GetExpectedSkillSlotResult(slot, skill) ~= HOT_BAR_RESULT_SUCCESS then
                        return nil, "Compétence impossible à placer : " .. SkillName(saved.name)
                    end
                    local previousSlot = hotbar:FindSlotMatchingSkill(skill)
                    if not matches and previousSlot and previousSlot ~= slot and hotbar:GetExpectedSlotEditResult(previousSlot) ~= HOT_BAR_RESULT_SUCCESS then
                        return nil, "L'ancien emplacement de cette compétence est verrouillé : " .. SkillName(saved.name)
                    end
                elseif not matches and hotbar:GetExpectedSlotEditResult(slot) ~= HOT_BAR_RESULT_SUCCESS then
                    if GetSlotBoundId(slot, category) ~= 0 then return nil, "Un emplacement de compétence est verrouillé." end
                end
                if not matches then table.insert(plan, op) end
            end
        end
    end
    if selected.champion and type(profile.champion) ~= "table" then return nil, "Étoiles Champion absentes. Réenregistre ce setup." end
    if selected.champion then
        local start, finish = GetAssignableChampionBarStartAndEndSlots()
        local championSeen = {}
        for slot = start, finish do
            local id = profile.champion[slot]
            if type(id) ~= "number" then return nil, "Étoiles Champion sauvegardées invalides." end
            if id ~= 0 then
                if not ChampionAvailable(id, slot) then
                    return nil, "Une étoile Champion n'est plus disponible. Réenregistre ce setup."
                end
                if championSeen[id] then return nil, "Une étoile Champion est affectée deux fois." end
                championSeen[id] = true
            end
        end
        local op = { kind = "champion", slots = profile.champion, label = "étoiles Champion", timeoutMs = 35000 }
        if not self:Satisfied(op) then
            PrepareChampionPurchaseRequest(false)
            for slot, id in pairs(op.slots) do AddHotbarSlotToChampionPurchaseRequest(slot, id) end
            local result = GetExpectedResultForChampionPurchaseRequest()
            if result ~= CHAMPION_PURCHASE_SUCCESS then
                return nil, "Les étoiles Champion ne peuvent pas être appliquées. Termine leurs modifications puis réessaie."
            end
            table.insert(plan, op)
        end
    end
    -- Accepted asynchronous requests must settle before another request is sent.
    -- Repeating an accepted unequip could otherwise remove an item equipped later.
    for _, op in ipairs(plan) do op.retryAccepted = false end
    return plan
end

function Adapter:Satisfied(op)
    if op.kind == "equip" then return UID(BAG_WORN, op.slot) == op.uid end
    if op.kind == "unequip" then return UID(BAG_WORN, op.slot) == "0" end
    if op.kind == "skill" then
        if op.saved.id == 0 then return GetSlotBoundId(op.slot, op.category) == 0 end
        if GetSlotType(op.slot, op.category) ~= op.saved.type then return false end
        local actual = GetSlotBoundId(op.slot, op.category)
        if op.saved.type == ACTION_TYPE_CRAFTED_ABILITY then return actual == op.saved.id end
        -- Some skills expose a second-cast/proc ID. Compare the mapped skill and
        -- morph rather than treating that transient ID as a failed assignment.
        local actualProgression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(actual)
        local wanted, problem = self:ResolveSkill(op.saved)
        return not problem and actualProgression ~= nil and
            actualProgression:GetSkillData() == wanted and actualProgression:GetMorphSlot() == op.saved.morph
    end
    if op.kind == "champion" then
        for slot, id in pairs(op.slots) do
            if GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) ~= id then return false end
        end
        return true
    end
    return false
end

function Adapter:Perform(op, components)
    local ready, problem = self:IsReady(components)
    if not ready then return false, problem end
    if op.kind == "equip" then
        local item = self:Inventory()[op.uid]
        if not item then return false, "Objet disparu du sac : " .. op.label end
        if item.bag ~= BAG_BACKPACK then return false, "Objet encore équipé ailleurs : " .. op.label end
        local current = UID(BAG_WORN, op.slot)
        if op.beforeUID and current ~= "0" and current ~= op.beforeUID then
            return false, "L'équipement de cet emplacement a changé. Vérifie ton setup avant de réessayer."
        end
        RequestEquipItem(item.bag, item.slot, BAG_WORN, op.slot)
    elseif op.kind == "unequip" then
        local current = UID(BAG_WORN, op.slot)
        if current == "0" then return true end
        if op.uid and current ~= op.uid then
            return false, "L'objet à retirer a changé. Vérifie ton setup avant de réessayer."
        end
        if GetNumBagFreeSlots(BAG_BACKPACK) < 1 then return false, "Le sac est plein." end
        RequestUnequipItem(BAG_WORN, op.slot)
    elseif op.kind == "skill" then
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(op.category)
        if op.saved.id == 0 then
            if hotbar:GetExpectedSlotEditResult(op.slot) ~= HOT_BAR_RESULT_SUCCESS then
                return false, "Cet emplacement de compétence est momentanément verrouillé. Réessaie après l'avoir déverrouillé."
            end
            hotbar:ClearSlot(op.slot)
        else
            local skill, why, expected = self:ResolveSkill(op.saved)
            if not skill or why then return false, why end
            if expected ~= op.expected then return false, "La compétence a changé pendant le chargement du setup." end
            if hotbar:GetExpectedSkillSlotResult(op.slot, skill) ~= HOT_BAR_RESULT_SUCCESS then
                return false, "Compétence momentanément verrouillée : " .. op.label
            end
            local previousSlot = hotbar:FindSlotMatchingSkill(skill)
            if previousSlot and previousSlot ~= op.slot and hotbar:GetExpectedSlotEditResult(previousSlot) ~= HOT_BAR_RESULT_SUCCESS then
                return false, "L'ancien emplacement de cette compétence est verrouillé. Réessaie après l'avoir déverrouillé."
            end
            hotbar:AssignSkillToSlot(op.slot, skill)
        end
    elseif op.kind == "champion" then
        PrepareChampionPurchaseRequest(false)
        for slot, id in pairs(op.slots) do AddHotbarSlotToChampionPurchaseRequest(slot, id) end
        local result = GetExpectedResultForChampionPurchaseRequest()
        if result ~= CHAMPION_PURCHASE_SUCCESS then
            return false, "Les étoiles Champion ont été refusées. Termine leurs modifications puis réessaie."
        end
        SendChampionPurchaseRequest()
    else return false, "Étape inconnue." end
    return true
end

function Adapter:Verify(profile, components)
    local selected = Components(components)
    if not selected then return false, "Choisis les composants du setup à charger." end
    if selected.gear then
        for _, slot in ipairs(Slots()) do
            local saved = profile.gear[slot]
            if UID(BAG_WORN, slot) ~= saved.uid then return false, "Équipement non confirmé : " .. ItemName(saved.name) end
        end
    end
    if selected.skills then
        local first, last = SkillRange()
        for _, category in ipairs(Categories()) do
            for slot = first, last do
                local saved = profile.skills[category][slot]
                local _, problem, expected = self:ResolveSkill(saved)
                if problem then return false, problem end
                if not self:Satisfied({ kind = "skill", slot = slot, category = category, saved = saved, expected = expected }) then
                    return false, "Compétence non confirmée : " .. SkillName(saved.name)
                end
            end
        end
    end
    if selected.champion then
        if type(profile.champion) ~= "table" then return false, "Étoiles Champion absentes. Réenregistre ce setup." end
        local first, last = GetAssignableChampionBarStartAndEndSlots()
        for slot = first, last do
            if not ChampionAvailable(profile.champion[slot], slot) then
                return false, "Une étoile Champion n'est plus disponible. Réenregistre ce setup."
            end
        end
        if not self:Satisfied({ kind = "champion", slots = profile.champion }) then return false, "Étoiles Champion non confirmées." end
    end
    return true
end

R.AdapterClass = Adapter
