-- Crafting observations select concrete proposals. They never authorize a move.
GridBagsCrafting = { names = { "Blacksmithing", "Clothing", "Enchanting", "Alchemy", "Provisioning", "Woodworking", "Jewelry" } }
local F = GridBagsCrafting
local M, R = GridBagsSmartRouting, GridBagsRouting
local MAX_AGE = 7 * 86400
F.names[0] = "All profession materials"
F.names[8], F.names[9] = "Style materials", "Trait materials"
local TYPES = {
    BLACKSMITHING_MATERIAL={1}, BLACKSMITHING_RAW_MATERIAL={1}, BLACKSMITHING_BOOSTER={1},
    CLOTHIER_MATERIAL={2}, CLOTHIER_RAW_MATERIAL={2}, CLOTHIER_BOOSTER={2},
    ENCHANTING_RUNE_ASPECT={3}, ENCHANTING_RUNE_ESSENCE={3}, ENCHANTING_RUNE_POTENCY={3},
    REAGENT={4}, POTION_BASE={4}, POISON_BASE={4}, INGREDIENT={5}, FLAVORING={5}, SPICE={5},
    WOODWORKING_MATERIAL={6}, WOODWORKING_RAW_MATERIAL={6}, WOODWORKING_BOOSTER={6},
    JEWELRYCRAFTING_MATERIAL={7}, JEWELRYCRAFTING_RAW_MATERIAL={7}, JEWELRYCRAFTING_BOOSTER={7},
    JEWELRYCRAFTING_RAW_BOOSTER={7},
}
local FURNISHING = { "BLACKSMITHING", "CLOTHIER", "ENCHANTING", "ALCHEMY", "PROVISIONING", "WOODWORKING", "JEWELRYCRAFTING" }

function F:FurnishingProfession(link)
    if not GetItemLinkItemType then return nil end
    local kind,specialized=GetItemLinkItemType(link)
    if not ITEMTYPE_FURNISHING_MATERIAL or kind~=ITEMTYPE_FURNISHING_MATERIAL then return nil end
    for craft,name in ipairs(FURNISHING)do
        local value=_G["SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_"..name]
        if value and specialized==value then return craft end
    end
end

function F:AutomaticFurnitureRoute(link,source,dest)
    local craft=self:FurnishingProfession(link)
    if not craft then return true end
    if source~=R.BANK and self:Role(source,craft).crafter then return false,"Furniture material retained by its "..self.names[craft].." crafter"end
    if dest==R.BANK or not self:Role(dest,craft).crafter then return false,"Furniture material requires its own "..self.names[craft].." crafter; use a manual or recipe-specific move for exceptions"end
    return true
end

function F:Role(id, craft)
    local p = M:Profile(id)
    local specific = p.crafts and p.crafts[craft]
    if specific then return specific end
    return { crafter = p.crafter == true, researcher = p.researcher == true, learner = p.learner == true, priority = p.priority or 100 }
end

function F:Skills(id)
    if id == R.character then
        local frame = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()
        if frame and self.skillFrame == frame then return self.liveSkills end
        self.liveSkills = M:CaptureProfessions(); self.skillFrame = frame
        return self.liveSkills
    end
    local rec = GridBagsSnapshots.records[id]
    return M:Fresh(id) and rec and rec.professions or nil
end

local function ItemKey(link)
    return GetItemLinkItemId and GetItemLinkItemId(link) or link
end

-- Recipe level requirements are crafting passive tiers, not character level.
-- Ingredient ownership is deliberately not tested: these routes supply missing stock.
function F:CaptureRecipes(force)
    local now = GetTimeStamp()
    if not force and self.recipeCache and now - self.recipeCache.at < 300 then return self.recipeCache end
    local result = { at = now, complete = false, related = {}, usable = {}, known = {}, ready = {} }
    -- Explicit checks: ipairs stops at the first nil.
    if not GetNumRecipeLists or not GetRecipeListInfo or not GetRecipeInfo or not GetNumRecipeTradeskillRequirements
        or not GetRecipeTradeskillRequirement or not GetRecipeIngredientItemLink or not GetItemLinkItemId then return result end
    local skills = M:CaptureProfessions()
    local ok = pcall(function()
        local lists = GetNumRecipeLists()
        if lists < 1 then error("Recipe catalog not available") end
        for list = 1, lists do
            local _, count = GetRecipeListInfo(list)
            for recipe = 1, count do
                local known, _, n, level, quality, _, craft = GetRecipeInfo(list, recipe)
                if type(craft) == "number" and craft >= 1 and craft <= 7 then
                    result.related[craft] = result.related[craft] or {}
                    result.usable[craft] = result.usable[craft] or {}
                    local can = known == true and skills[craft] ~= nil
                    for index = 1, GetNumRecipeTradeskillRequirements(list, recipe) do
                        local profession, tier = GetRecipeTradeskillRequirement(list, recipe, index)
                        local data = skills[profession]
                        if not data or data.tier < tier then can = false end
                    end
                    if (level or 0) > 0 and (not skills[5] or skills[5].tier < level) then can = false end
                    if (quality or 0) > 0 then
                        if not NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL or not GetNonCombatBonus or
                            GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL) < quality then can = false end
                    end
                    if known then result.known[craft] = (result.known[craft] or 0) + 1 end
                    if can then result.ready[craft] = (result.ready[craft] or 0) + 1 end
                    for ingredient = 1, n do
                        local link = GetRecipeIngredientItemLink(list, recipe, ingredient, LINK_STYLE_DEFAULT)
                        local key = ItemKey(link)
                        if not key or key == 0 or link == "" then
                            if known then error("Learned recipe ingredient unavailable") end
                        else
                            result.related[craft][key] = true
                            if can then result.usable[craft][key] = true end
                        end
                    end
                end
            end
        end
        result.complete = true
    end)
    if not ok then result.complete = false; result.usable = {} end
    self.recipeCache = result
    return result
end

function F:Recipes(id)
    if id == R.character then return self:CaptureRecipes() end
    local rec = GridBagsSnapshots.records[id]
    local data = rec and rec.craftingRecipes
    if not data or not data.complete then return nil end
    if GetTimeStamp() - (data.at or 0) > MAX_AGE or not M:Fresh(id) then return nil end
    return data
end

function F:SharedCategory(link, refinedCheck)
    if not GetItemLinkItemType then return nil end
    local kind = GetItemLinkItemType(link)
    if ITEMTYPE_STYLE_MATERIAL and kind == ITEMTYPE_STYLE_MATERIAL then return 8 end
    for _, name in ipairs({"ITEMTYPE_ARMOR_TRAIT","ITEMTYPE_WEAPON_TRAIT","ITEMTYPE_JEWELRY_TRAIT","ITEMTYPE_JEWELRY_RAW_TRAIT"}) do
        if _G[name] and kind == _G[name] then return 9 end
    end
    if not refinedCheck and ITEMTYPE_RAW_MATERIAL and kind == ITEMTYPE_RAW_MATERIAL and GetItemLinkRefinedMaterialItemLink then
        local refined = GetItemLinkRefinedMaterialItemLink(link, LINK_STYLE_DEFAULT)
        if refined and refined ~= "" and refined ~= link then return self:SharedCategory(refined, true) end
    end
end

function F:Related(link, craft, refinedCheck)
    if craft==0 then for profession=1,7 do if self:Related(link,profession)then return true end end;return false end
    local shared = self:SharedCategory(link)
    if shared then return craft == shared end
    if craft == 8 or craft == 9 then return false end
    local kind, specialized
    if GetItemLinkItemType then kind, specialized = GetItemLinkItemType(link) end
    for name, crafts in pairs(TYPES) do
        if _G["ITEMTYPE_" .. name] and kind == _G["ITEMTYPE_" .. name] then
            for _, value in ipairs(crafts) do if craft == value then return true end end
        end
    end
    local furnishing = _G["SPECIALIZED_ITEMTYPE_FURNISHING_MATERIAL_" .. FURNISHING[craft]]
    if furnishing and specialized == furnishing then return true end
    if not refinedCheck and ITEMTYPE_RAW_MATERIAL and kind == ITEMTYPE_RAW_MATERIAL and GetItemLinkRefinedMaterialItemLink then
        local refined = GetItemLinkRefinedMaterialItemLink(link, LINK_STYLE_DEFAULT)
        if refined and refined ~= "" and refined ~= link and self:Related(refined, craft, true) then return true end
    end
    return false
end

function F:Qualifies(link, id, craft, scope)
    if scope~="known"and not self:Related(link,craft)then return false,"Material belongs outside this profession; cross-profession ingredients require an explicit known-recipe route","CROSS_PROFESSION_MATERIAL"end
    if scope == "all" then return true end
    local skills = self:Skills(id)
    if not skills or not skills[craft] then return nil, "Destination profession scan is missing or stale", "CRAFT_DATA_MISSING" end
    local recipes = self:Recipes(id)
    if recipes and recipes.complete and recipes.usable[craft] and recipes.usable[craft][ItemKey(link)] then return true end
    if scope == "known" then
        if not recipes or not recipes.complete then return nil, "Destination learned-recipe scan is missing or stale", "RECIPE_DATA_MISSING" end
        return false, "No learned recipe with satisfied skill requirements uses this ingredient", "NO_CRAFTABLE_RECIPE"
    end
    local profession, tier = M:CraftRequirement(link)
    if profession == craft then return skills[craft].tier >= tier, "Destination cannot use this material tier", "MATERIAL_TIER_UNUSABLE" end
    local kind = GetItemLinkItemType and GetItemLinkItemType(link)
    if craft == 3 and ITEMTYPE_ENCHANTING_RUNE_ASPECT and kind == ITEMTYPE_ENCHANTING_RUNE_ASPECT then
        local tier = GetItemLinkRequiredCraftingSkillRank and GetItemLinkRequiredCraftingSkillRank(link)
        local rarity = skills[craft].rarity
        if tier and tier > 0 and rarity then return rarity >= tier, "Destination cannot use this aspect rune quality", "MATERIAL_TIER_UNUSABLE" end
    end
    if (craft == 4 and ITEMTYPE_REAGENT and kind == ITEMTYPE_REAGENT) or
        (craft == 3 and ITEMTYPE_ENCHANTING_RUNE_ESSENCE and kind == ITEMTYPE_ENCHANTING_RUNE_ESSENCE) then return true end
    if craft == 5 and recipes and recipes.complete then return false, "No usable learned recipe uses this ingredient", "NO_CRAFTABLE_RECIPE" end
    return nil, "Usability is unsupported for this material; use an explicit storage rule if desired", "MATERIAL_CHECK_UNSUPPORTED"
end

function F:Best(craft)
    local best, lead, priority, tied, missing
    for id in pairs(R.data.profiles) do
        local role = self:Role(id, craft)
        if role.crafter then
            local skills = self:Skills(id); local data = skills and skills[craft]
            if not data then missing = true
            else
                local p = role.priority or 100
                if not lead or data.rank > lead.rank or (data.rank == lead.rank and data.passivePoints > lead.passivePoints) or
                    (data.rank == lead.rank and data.passivePoints == lead.passivePoints and p < priority) then
                    best, lead, priority, tied = id, data, p, false
                elseif data.rank == lead.rank and data.passivePoints == lead.passivePoints and p == priority then tied = true end
            end
        end
    end
    if missing or tied or not best then return nil, "Lead crafter is missing, stale, undesignated or tied; refresh scans or set profession priorities" end
    return best
end

function F:MatchesSource(rule, link, destination)
    if rule.craft == 8 or rule.craft == 9 then return self:SharedCategory(link) == rule.craft end
    if self:SharedCategory(link)then return false end
    local matched = false
    for craft = 1, 7 do
        local belongs=self:Related(link,craft)
        if not belongs and rule.scope=="known"and rule.craft==craft then
            local dest=destination or rule.dest
            if dest=="@best-crafter"then dest=self:Best(craft)end
            belongs=dest and self:Qualifies(link,dest,craft,"known")==true
        end
        if (rule.craft == 0 or rule.craft == craft) and belongs then
            matched = true
            -- Shared materials stay with the source if it crafts any related selected profession.
            if rule.sourceUnassigned and self:Role(rule.source, craft).crafter then
                return false, "Source is assigned as a " .. self.names[craft] .. " crafter; related materials retained"
            end
        end
    end
    return matched
end

function F:RecipientSuggestions(link, source)
    local entries, supported = {}, false
    for craft = 1, 7 do
        local native=self:Related(link,craft)
        if native or not self:SharedCategory(link)then
            supported = supported or native
            local lead = self:Best(craft)
            for id in pairs(R.data.profiles) do
                if id ~= source and self:Role(id, craft).crafter then
                    local known = self:Qualifies(link, id, craft, "known")
                    local scope = known == true and "known" or "usable"
                    if self:Qualifies(link, id, craft, scope) == true then
                        supported=true
                        entries[#entries+1] = {id=id,craft=craft,scope=scope,lead=id==lead,cross=not native}
                    end
                end
            end
        end
    end
    table.sort(entries,function(a,b)
        if a.craft ~= b.craft then return a.craft < b.craft end
        if a.lead ~= b.lead then return a.lead end
        return R:Name(a.id) < R:Name(b.id)
    end)
    return entries, supported
end

-- All allocations, including pending/review work, consume source stock before storage fallback.
function F:Allocated(source, item)
    return R:Allocated(source,item)
end

function F:Generate(rule, items)
    R.materialClaims = R.materialClaims or {}
    local dest, targetError = rule.dest
    if dest == "@best-crafter" then dest, targetError = self:Best(rule.craft) end
    for _, item in ipairs(items) do
        local matches, sourceReason = self:MatchesSource(rule, item.link,dest)
        if sourceReason then rule.reason,rule.reasonCode=sourceReason,"SOURCE_IS_CRAFTER" end
        if matches and item.blocked then rule.reason,rule.reasonCode=item.blockedReason or "Matching item is locked, stolen or character-bound",item.blockedCode or "SOURCE_PROTECTED" end
        if not item.blocked and matches then
            local key = rule.source .. ":" .. tostring(item.uid)
            local guard = R:Protection(rule.source, item.link)
            local free = R:RuleAvailable(rule,items,item)
            if guard.blocked then rule.reason,rule.reasonCode="Source protected: Never export","SOURCE_PROTECTED"
            elseif free<=0 then rule.reason,rule.reasonCode="No unallocated units remain after existing plans, reservations, Keep limits and the per-stack cap","SOURCE_ALLOCATED" end
            local claimed = R.materialClaims and R.materialClaims[key]
            local furnitureAllowed,furnitureReason=self:AutomaticFurnitureRoute(item.link,rule.source,dest)
            if not furnitureAllowed and rule.scope~="known"then
                claimed=true;rule.reason,rule.reasonCode=furnitureReason,"FURNITURE_KEEPER"
            end
            if not guard.blocked and free > 0 and not claimed then
                local allowed, reason, code
                if dest then allowed, reason, code = self:Qualifies(item.link, dest, rule.craft, rule.scope)
                else reason, code = targetError, "CRAFT_DATA_MISSING" end
                -- Unknown evidence holds stock against broad fallback. Known ineligibility may fall back.
                if allowed == nil or (allowed and dest == rule.source) then
                    R.materialClaims[key] = true
                    rule.reason = reason or "Source is already the selected crafter; keeping its materials"
                    rule.reasonCode = code or "SOURCE_IS_CRAFTER"
                elseif allowed then
                    local qty = free
                    local cross=rule.scope=="known"and (not self:Related(item.link,rule.craft)or not furnitureAllowed)
                    local plan, err = R:Add({ source=rule.source, dest=dest, link=item.link, name=item.name, uid=item.uid,
                        qty=qty, mode=cross and "ask"or rule.mode, rule=rule.id, bound=item.bound, maxStack=item.maxStack, available=item.qty,
                        smart=rule.scope ~= "all" and {kind="materials",craft=rule.craft,scope=rule.scope} or nil })
                    if not plan then rule.reason = err end
                else rule.reason, rule.reasonCode = reason, code end
            end
        end
    end
end
