-- Provider observations create proposals; they never grant transfer permission.
GridBagsSmartRouting = {}
local M = GridBagsSmartRouting
local MAX_AGE = 7 * 24 * 60 * 60
local BONUS_NAMES = {
    "NON_COMBAT_BONUS_BLACKSMITHING_LEVEL", "NON_COMBAT_BONUS_CLOTHIER_LEVEL",
    "NON_COMBAT_BONUS_ENCHANTING_LEVEL", "NON_COMBAT_BONUS_ALCHEMY_LEVEL",
    "NON_COMBAT_BONUS_PROVISIONING_LEVEL", "NON_COMBAT_BONUS_WOODWORKING_LEVEL",
    "NON_COMBAT_BONUS_JEWELRYCRAFTING_LEVEL",
}

function M:CaptureProfessions()
    local result = {}
    if not GetCraftingSkillLineIndices or not GetNonCombatBonus or not GetSkillLineDynamicInfo then return result end
    for craft, bonusName in ipairs(BONUS_NAMES) do
        local ok, data = pcall(function()
            local kind, line = GetCraftingSkillLineIndices(craft)
            local rank = GetSkillLineDynamicInfo(kind, line)
            local points = 0
            if GetNumSkillAbilities and GetSkillAbilityInfo and GetSkillAbilityUpgradeInfo then
                for index = 1, GetNumSkillAbilities(kind, line) do
                    local _, _, _, passive, _, purchased = GetSkillAbilityInfo(kind, line, index)
                    if passive and purchased then points = points + (GetSkillAbilityUpgradeInfo(kind, line, index) or 1) end
                end
            end
            local tier = _G[bonusName] and GetNonCombatBonus(_G[bonusName])
            if not rank or not tier then return nil end
            local rarityName = craft == 3 and "NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL" or
                (craft == 5 and "NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL")
            local rarity = rarityName and _G[rarityName] and GetNonCombatBonus(_G[rarityName]) or nil
            return { rank = rank, tier = tier, rarity = rarity, passivePoints = points, at = GetTimeStamp() }
        end)
        if ok and data then result[craft] = data end
    end
    return result
end

function M:Fresh(id)
    if id == GridBagsRouting.character then return true end
    local record = GridBagsSnapshots.records[id]
    return record and GetTimeStamp() - record.updatedAt <= MAX_AGE
end

function M:Profile(id)
    return GridBagsRouting.data.profiles[id] or {}
end

function M:ResearchKey(link)
    local lib = LibCharacterKnowledge
    if not lib or not lib.GetSmithingResearchFromItemLink then return nil end
    local ok, craft, line, trait = pcall(lib.GetSmithingResearchFromItemLink, link)
    if ok and craft and line and trait then return table.concat({craft,line,trait}, ":"), craft, line, trait end
end

function M:Duplicate(id, link, research, except)
    local key = research and self:ResearchKey(link)
    local function Matches(other)
        if key then return self:ResearchKey(other) == key end
        if GetItemLinkItemId then return GetItemLinkItemId(other) == GetItemLinkItemId(link) end
        return other == link
    end
    local items
    if id == GridBagsRouting.character then
        items = GridBagsRouting:Scan(id)
    else
        local record = GridBagsSnapshots.records[id]
        items = record and record.items or {}
    end
    for _, item in ipairs(items) do if item.link and Matches(item.link) then return true end end
    for _, p in ipairs(GridBagsRouting.data.plans) do
        if p.id ~= except and p.dest == id and (p.state == "source" or p.state == "bank" or p.state == "review") and Matches(p.link) then return true end
    end
    return false
end

function M:Knowledge(link, id, research)
    local lib = LibCharacterKnowledge
    if not lib or not self:Fresh(id) then return "no-data" end
    if research then
        local key, craft, line, trait = self:ResearchKey(link)
        if not key or not lib.GetSmithingResearchStatusForCharacter then return "invalid" end
        local ok, state, remaining = pcall(lib.GetSmithingResearchStatusForCharacter, craft, line, trait, nil, id)
        if not ok then return "no-data" end
        if state == lib.KNOWLEDGE_KNOWN then return "known" end
        if remaining and remaining > 0 then return "researching" end
        if state == lib.KNOWLEDGE_UNKNOWN then return "unknown" end
        return "no-data"
    end
    if not lib.GetItemKnowledgeForCharacter then return "no-data" end
    local ok, state = pcall(lib.GetItemKnowledgeForCharacter, link, nil, id)
    if not ok then return "no-data" end
    if state == lib.KNOWLEDGE_KNOWN then return "known" end
    if state == lib.KNOWLEDGE_UNKNOWN then return "unknown" end
    return state == lib.KNOWLEDGE_INVALID and "invalid" or "no-data"
end

function M:Learners(link, source, research)
    if research and GridBagsGearRouting then
        local entries,_,noData=GridBagsGearRouting:ResearchCandidates(link,source)
        return entries,noData
    end
    local entries, noData = {}, false
    for id, profile in pairs(GridBagsRouting.data.profiles) do
        local craft
        if research then local key; key, craft = self:ResearchKey(link)
        elseif GetItemLinkRecipeCraftingSkillType then craft = GetItemLinkRecipeCraftingSkillType(link) end
        local role = craft and GridBagsCrafting and GridBagsCrafting:Role(id, craft) or profile
        if id ~= source and role[research and "researcher" or "learner"] then
            local state = self:Knowledge(link, id, research)
            if state == "unknown" and not self:Duplicate(id, link, research) then
                entries[#entries + 1] = { id = id, priority = role.priority or 100 }
            elseif state == "no-data" then noData = true end
        end
    end
    table.sort(entries, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        -- Stable identity only orders equal user priorities; automatic crafter ties are held separately.
        return tostring(a.id) < tostring(b.id)
    end)
    return entries, noData
end

function M:CraftRequirement(link)
    if not GetItemLinkItemType or not GetItemLinkRequiredCraftingSkillRank then return nil end
    local kind = GetItemLinkItemType(link)
    local types = {
        { "ITEMTYPE_BLACKSMITHING_MATERIAL", 1 }, { "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", 1 },
        { "ITEMTYPE_CLOTHIER_MATERIAL", 2 }, { "ITEMTYPE_CLOTHIER_RAW_MATERIAL", 2 },
        { "ITEMTYPE_WOODWORKING_MATERIAL", 6 }, { "ITEMTYPE_WOODWORKING_RAW_MATERIAL", 6 },
        { "ITEMTYPE_JEWELRYCRAFTING_MATERIAL", 7 }, { "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", 7 },
        { "ITEMTYPE_POTION_BASE", 4 }, { "ITEMTYPE_POISON_BASE", 4 }, { "ITEMTYPE_ENCHANTING_RUNE_POTENCY", 3 },
    }
    for _, entry in ipairs(types) do
        if _G[entry[1]] and kind == _G[entry[1]] then
            local required = GetItemLinkRequiredCraftingSkillRank(link)
            if required and required > 0 then return entry[2], required end
        end
    end
end

function M:Crafter(link, source)
    local craft, required = self:CraftRequirement(link)
    if not craft then return nil, "This material has no supported tier eligibility check; choose its recipient manually." end
    local best, bestData, bestPriority, tied, missing
    for id, profile in pairs(GridBagsRouting.data.profiles) do
        if GridBagsCrafting then profile = GridBagsCrafting:Role(id, craft) end
        local record = GridBagsSnapshots.records[id]
        local data = record and record.professions and record.professions[craft]
        if id == GridBagsRouting.character then data = self:CaptureProfessions()[craft] end
        if profile.crafter and (not data or not self:Fresh(id)) then missing = true end
        if profile.crafter and data and self:Fresh(id) then
            local priority = profile.priority or 100
            local better = not bestData or data.rank > bestData.rank or
                (data.rank == bestData.rank and data.passivePoints > bestData.passivePoints) or
                (data.rank == bestData.rank and data.passivePoints == bestData.passivePoints and priority < bestPriority)
            if better then best, bestData, bestPriority, tied = id, data, priority, false
            elseif data.rank == bestData.rank and data.passivePoints == bestData.passivePoints and priority == bestPriority then tied = true end
        end
    end
    GridBagsRouting.data.tierHolds = GridBagsRouting.data.tierHolds or {}
    if not best or tied or missing then
        GridBagsRouting.data.tierHolds[link] = "Crafter evidence missing, stale or tied"
        return nil, "Missing/stale designated-crafter data, or a tied lead. Refresh profiles, set priorities or choose manually."
    end
    if bestData.tier < required then
        GridBagsRouting.data.tierHolds[link] = "Lead crafter cannot use this tier yet"
        return nil, "Lead " .. GridBagsRouting:Name(best) .. " cannot use tier " .. required .. ". Keep this material in the bank."
    end
    GridBagsRouting.data.tierHolds[link] = nil
    if best == source then return nil, "The source is already the lead crafter. Keep its usable materials here, or choose another recipient manually." end
    return best, nil, { kind = "craft", craft = craft, tier = required },
        string.format("Profession rank %d, passive investment %d, usable tier %d", bestData.rank, bestData.passivePoints, bestData.tier)
end

function M:Eligible(plan,observed)
    local rule = plan.rule and GridBagsRouting:Rule(plan.rule)
    if rule and rule.material and rule.craft>=1 and rule.craft<=7 and rule.scope~="known"and not GridBagsCrafting:SharedCategory(plan.link)and not GridBagsCrafting:Related(plan.link,rule.craft)then
        return false,"This ordinary profession rule cannot send another profession's material; review the delivery and use an explicit known-recipe route if needed","CROSS_PROFESSION_MATERIAL"
    end
    if plan.state == "source" and rule and rule.material and rule.craft <= 7 and GridBagsCrafting:SharedCategory(plan.link) then
        return false, "Shared style/trait material now uses a separate category; cancel this unstarted delivery and use a Style or Trait materials rule", "SHARED_CATEGORY_CHANGED"
    end
    if not plan.smart then return true end
    if plan.smart.kind=="gatherRecipe"then return GridBagsRecipeGather:Eligible(plan)end
    if plan.smart.kind=="deconstruct"then return GridBagsGearRouting:EligibleDeconstruction(plan,observed)end
    if plan.smart.kind=="research"and plan.smart.profileResearch then
        local ok,reason,code=GridBagsGearRouting:EligibleResearch(plan)
        if not ok then return false,reason,code end
    end
    if plan.smart.kind == "materials" then
        local ok, reason, code = GridBagsCrafting:Qualifies(plan.link, plan.dest, plan.smart.craft, plan.smart.scope)
        return ok == true, reason, code
    end
    if plan.smart.kind == "craft" then
        local data
        if plan.dest == GridBagsRouting.character then data = self:CaptureProfessions()[plan.smart.craft]
        else
            local record = GridBagsSnapshots.records[plan.dest]
            data = self:Fresh(plan.dest) and record and record.professions and record.professions[plan.smart.craft]
        end
        if not data then return false, "Destination crafting data is missing or stale", "CRAFT_DATA_MISSING" end
        if data.tier < plan.smart.tier then return false, "Destination crafter cannot use this material tier yet", "MATERIAL_TIER_UNUSABLE" end
        return true
    end
    local research = plan.smart.kind == "research"
    local state = self:Knowledge(plan.link, plan.dest, research)
    if state == "no-data" then return false, "Destination knowledge record is missing or stale", "KNOWLEDGE_NO_DATA" end
    if state == "known" then return false, research and "Recipient already knows this trait" or "Recipient already knows this recipe or plan", "ALREADY_KNOWN" end
    if state == "researching" then return false, "Recipient is already researching this trait", "RESEARCH_IN_PROGRESS" end
    if state ~= "unknown" then return false, "Item has no supported learning classification", "NOT_LEARNABLE" end
    if self:Duplicate(plan.dest, plan.link, research, plan.id) then return false, "Recipient already has a matching copy or planned delivery", "DUPLICATE_DELIVERY" end
    return true
end

function M:GenerateLearning(rule, items)
    local R = GridBagsRouting
    local learners, noData = self:Learners(rule.link, rule.source, rule.strategy == "research")
    rule.reason = noData and "Some learner records are missing/stale; those characters are held for review" or
        (#learners == 0 and "No eligible missing knowledge; existing copies/plans or known items retained" or nil)
    R.data.learningHolds = R.data.learningHolds or {}
    R.data.learningHolds[rule.link] = R.data.learningHolds[rule.link] or noData or nil
    local guard = R:Protection(rule.source, rule.link)
    if guard.blocked then return end
    local keep = R:KeepFloor(rule.source,rule.link)
    local sourceProfile = self:Profile(rule.source)
    local craft
    if rule.strategy == "research" then local key; key, craft = self:ResearchKey(rule.link)
    elseif GetItemLinkRecipeCraftingSkillType then craft = GetItemLinkRecipeCraftingSkillType(rule.link) end
    if craft and GridBagsCrafting then sourceProfile = GridBagsCrafting:Role(rule.source, craft) end
    if rule.source ~= R.BANK and sourceProfile[rule.strategy == "research" and "researcher" or "learner"] then
        local state = self:Knowledge(rule.link, rule.source, rule.strategy == "research")
        if state == "no-data" then R.data.learningHolds[rule.link] = true; return end
        if state == "unknown" then keep = math.max(keep, 1) end
    end
    local free = R:Total(items, rule.link) - keep - (rule.source == R.BANK and R:Reserved(rule.link) or 0)
    for _, candidate in ipairs(learners) do
        if free < 1 then break end
        for _, item in ipairs(items) do
            if item.link == rule.link and not item.blocked then
                local allocated = 0
                for _, p in ipairs(R.data.plans) do
                    if p.source == rule.source and p.uid == item.uid and p.link == rule.link and (p.state == "source" or p.state == "bank") then allocated = allocated + p.remaining end
                end
                if allocated < item.qty then
                    local p = R:Add({ source = rule.source, dest = candidate.id, link = rule.link, name = rule.name,
                        uid = item.uid, qty = 1, mode = rule.mode, rule = rule.id, maxStack = item.maxStack,
                        smart = {kind = rule.strategy == "research" and "research" or "recipe"}, available = item.qty })
                    if p then free = free - 1 end
                    break
                end
            end
        end
    end
end
