-- Set Hunter workshop: named builds, material checks, and one-press making at stations.
-- Nothing is spent until you confirm the review at a station. Any failure stops the queue.

local SH = ESOC_SetHunter
local W = {}
SH.Workshop = W

local I, sv
local DIALOG = "ESOC_SETHUNTER_WORKSHOP"
local RESPONSE_TIMEOUT = 12000
local ENCHANT_DELAY = 1200
local STEP_DELAY = 900

local LEGENDARY = ITEM_FUNCTIONAL_QUALITY_LEGENDARY or 5
local QUALITIES = {
    { name = "Green", data = ITEM_FUNCTIONAL_QUALITY_MAGIC or 2 },
    { name = "Blue", data = ITEM_FUNCTIONAL_QUALITY_ARCANE or 3 },
    { name = "Purple", data = ITEM_FUNCTIONAL_QUALITY_ARTIFACT or 4 },
    { name = "Gold", data = LEGENDARY },
}

-- Glyph item ids, from LibLazyCrafting's enchanting table.
local GLYPHS = {
    armor = {
        { "Health", 26580 }, { "Magicka", 26582 }, { "Stamina", 26588 }, { "Prismatic Defense", 68343 },
    },
    weapon = {
        { "Absorb Magicka", 45868 }, { "Absorb Stamina", 45867 }, { "Absorb Health", 43573 }, { "Flame", 26848 },
        { "Frost", 5365 }, { "Shock", 26844 }, { "Poison", 26587 }, { "Foulness", 26841 },
        { "Decrease Health", 45869 }, { "Crushing", 26845 }, { "Hardening", 5366 }, { "Weakening", 26591 },
        { "Weapon Damage", 54484 }, { "Prismatic Onslaught", 68344 },
    },
    jewelry = {
        { "Magicka Recovery", 26583 }, { "Stamina Recovery", 26589 }, { "Health Recovery", 26581 },
        { "Prismatic Recovery", 166047 }, { "Reduce Spell Cost", 45870 }, { "Reduce Feat Cost", 45871 },
        { "Reduce Skill Cost", 166046 }, { "Increase Magical Harm", 45884 }, { "Increase Physical Harm", 45883 },
        { "Bashing", 45872 }, { "Shielding", 45873 }, { "Potion Boost", 45874 }, { "Potion Speed", 45875 },
    },
}

local function alert(text) pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Set Hunter: " .. text) end

local function callGame(name, ...)
    if IsProtectedFunction and IsProtectedFunction(name) then return pcall(CallSecureProtected, name, ...) end
    return pcall(_G[name], ...)
end

local function glyphGroup(want)
    if want.category == ITEM_TRAIT_TYPE_CATEGORY_JEWELRY then return GLYPHS.jewelry end
    if want.category == ITEM_TRAIT_TYPE_CATEGORY_WEAPON then return GLYPHS.weapon end
    return GLYPHS.armor
end

local function glyphName(glyphId)
    for _, group in pairs(GLYPHS) do
        for _, glyph in ipairs(group) do
            if glyph[2] == glyphId then return glyph[1] end
        end
    end
    return "glyph"
end

local function targetQuality(want) return want.quality or LEGENDARY end

local function sortedPieces()
    local pieces = {}
    for setId, goal in pairs(I.ActiveSets()) do
        for pieceId, want in pairs(goal.wants) do
            pieces[#pieces + 1] = { setId = setId, id = pieceId, want = want, label = I.ShortName(want) }
        end
    end
    table.sort(pieces, function(a, b)
        if a.setId ~= b.setId then return a.setId < b.setId end
        local orderA, orderB = I.PieceOrder(a.want), I.PieceOrder(b.want)
        if orderA ~= orderB then return orderA < orderB end
        return a.id < b.id
    end)
    return pieces
end

---------------------------------------------------------------------------
-- Materials
---------------------------------------------------------------------------
local function newBudget()
    local budget = { mats = {}, short = {}, crystals = 0, space = GetNumBagFreeSlots(BAG_BACKPACK) or 0 }
    if CURT_CHAOTIC_CREATIA then
        budget.crystals = GetCurrencyAmount(CURT_CHAOTIC_CREATIA, GetCurrencyPlayerStoredLocation(CURT_CHAOTIC_CREATIA)) or 0
    end
    return budget
end

local function reagent(budget, skill, quality)
    local key = skill .. ":" .. quality
    if not budget.mats[key] then
        local name, _, have = GetSmithingImprovementItemInfo(skill, quality)
        budget.mats[key] = { name = zo_strformat("<<t:1>>", name or "material"), have = have or 0 }
    end
    return budget.mats[key], key
end

local function upgradeCosts(budget, skill, fromQuality, toQuality)
    local costs = {}
    for quality = fromQuality, toQuality - 1 do
        local entry = reagent(budget, skill, quality)
        costs[#costs + 1] = { entry = entry, need = GetSmithingGuaranteedImprovementItemAmount(skill, quality) or 0 }
    end
    return costs
end

-- Spends from the budget only if the whole job is affordable; otherwise records what is short.
local function trySpend(budget, crystals, costs)
    local ok = crystals <= budget.crystals
    for _, cost in ipairs(costs) do
        if cost.need > cost.entry.have then ok = false end
    end
    if ok then
        budget.crystals = budget.crystals - crystals
        for _, cost in ipairs(costs) do cost.entry.have = cost.entry.have - cost.need end
        return true
    end
    if crystals > budget.crystals then budget.short.crystals = (budget.short.crystals or 0) + crystals - budget.crystals end
    for _, cost in ipairs(costs) do
        if cost.need > cost.entry.have then
            budget.short[cost.entry.name] = (budget.short[cost.entry.name] or 0) + cost.need - cost.entry.have
        end
    end
    return false
end

local function shortText(short)
    local parts = {}
    if short.crystals then parts[#parts + 1] = short.crystals .. " crystals" end
    local names = {}
    for name in pairs(short) do
        if name ~= "crystals" then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do parts[#parts + 1] = short[name] .. " " .. name end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Plans
---------------------------------------------------------------------------
function W.PlanReconstruction()
    local budget = newBudget()
    local plan = { kind = "transmute", jobs = {}, blocked = {}, crystals = 0, budget = budget }
    for _, piece in ipairs(sortedPieces()) do
        local state, have, count = I.PieceStatus(piece.setId, piece.id, piece.want)
        if state == "reconstruct" then
            local trait = I.TargetTrait(piece.want)
            local cost = I.CrystalCost(piece.setId)
            for _ = 1, count - have do
                if trait == 0 then
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": choose a trait"
                elseif not cost then
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": can't be reconstructed"
                elseif not IsTraitKnownForItem(piece.id, trait) then
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": this character hasn't researched " .. I.TraitName(trait)
                elseif budget.space < 1 then
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": no free bag slot"
                else
                    local link = GetItemSetCollectionPieceItemLink(piece.id, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
                    local minimum = GetItemLinkFunctionalQuality(link)
                    local quality = math.max(minimum, targetQuality(piece.want))
                    local costs = upgradeCosts(budget, GetItemLinkCraftingSkillType(link), minimum, quality)
                    if trySpend(budget, cost, costs) then
                        plan.crystals = plan.crystals + cost
                        budget.space = budget.space - 1
                        plan.jobs[#plan.jobs + 1] = { pieceId = piece.id, trait = trait, quality = quality, label = piece.label }
                    else
                        plan.blocked[#plan.blocked + 1] = piece.label .. ": not enough materials"
                    end
                end
            end
        end
    end
    return plan
end

-- The copies you are carrying or wearing in the right trait, best quality first, up to the number wanted.
local function ownedCopies(piece)
    local trait = I.TargetTrait(piece.want)
    local copies = {}
    for _, bag in ipairs({ BAG_WORN, BAG_BACKPACK }) do
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemId(bag, slot) ~= 0 then
                local link = GetItemLink(bag, slot)
                if I.SetIdOf(link) == piece.setId then
                    local equip, armor, weapon = I.LinkShape(link)
                    if I.SameShape(piece.want, equip, armor, weapon) and (trait == 0 or GetItemLinkTraitType(link) == trait) then
                        copies[#copies + 1] = { bag = bag, slot = slot, link = link, quality = GetItemLinkFunctionalQuality(link) }
                    end
                end
            end
        end
    end
    table.sort(copies, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    for index = #copies, (piece.want.count or 1) + 1, -1 do copies[index] = nil end
    return copies
end

function W.PlanImprovement(skill)
    local budget = newBudget()
    local plan = { kind = "improve", skill = skill, jobs = {}, blocked = {}, crystals = 0, budget = budget }
    for _, piece in ipairs(sortedPieces()) do
        local target = targetQuality(piece.want)
        for _, copy in ipairs(ownedCopies(piece)) do
            if copy.quality < target and GetItemLinkCraftingSkillType(copy.link) == skill then
                if trySpend(budget, 0, upgradeCosts(budget, skill, copy.quality, target)) then
                    plan.jobs[#plan.jobs + 1] = {
                        bag = copy.bag, slot = copy.slot, uniqueId = GetItemUniqueId(copy.bag, copy.slot),
                        target = target, label = piece.label,
                    }
                else
                    plan.blocked[#plan.blocked + 1] = piece.label .. ": not enough materials"
                end
            end
        end
    end
    return plan
end

local function enchantHeader(link)
    local ok, _, header = pcall(GetItemLinkEnchantInfo, link)
    if ok then return header end
    return nil
end

local function glyphLink(glyphId)
    local lib = LibLazyCrafting
    if lib and LLC_GetEnchantingResultItemLinkByAttributes then
        local ok, link = pcall(LLC_GetEnchantingResultItemLinkByAttributes, true, 160, W.EnchantIdFor(glyphId), 5)
        if ok then return link end
    end
    return nil
end

function W.EnchantIdFor(glyphId)
    local lib = LibLazyCrafting
    if not lib or not lib.glyphEssenceIdInfo then return nil end
    for _, row in ipairs(lib.glyphEssenceIdInfo) do
        if row[3] == glyphId then return row[1] end
        if row[4] == glyphId then return row[2] end
    end
    return nil
end

local function alreadyEnchanted(copy, glyphId)
    local uniqueId = Id64ToString(GetItemUniqueId(copy.bag, copy.slot))
    if sv.enchanted[uniqueId] == glyphId then return true end
    local wanted = glyphLink(glyphId)
    if not wanted then return false end
    local current, target = enchantHeader(copy.link), enchantHeader(wanted)
    return current ~= nil and current ~= "" and current == target
end

-- A gold, CP160 glyph of this type in your backpack that isn't already spoken for.
local function findGlyph(glyphId, bagSlot, used)
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if not used[slot] and GetItemId(BAG_BACKPACK, slot) == glyphId then
            local link = GetItemLink(BAG_BACKPACK, slot)
            local _, glyphCp = GetItemLinkGlyphMinLevels(link)
            if glyphCp == 160 and GetItemLinkFunctionalQuality(link) == LEGENDARY
                and CanItemTakeEnchantment(bagSlot.bag, bagSlot.slot, BAG_BACKPACK, slot) then
                return slot
            end
        end
    end
    return nil
end

local function runeLink(itemId)
    return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

-- Runes can be in the backpack, bank or craft bag (where the slot number is the item id).
local function findRune(itemId)
    if BAG_VIRTUAL and GetItemId(BAG_VIRTUAL, itemId) == itemId then return BAG_VIRTUAL, itemId end
    for _, bag in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemId(bag, slot) == itemId then return bag, slot end
        end
    end
    return nil
end

-- The character's Potency Improvement and Aspect Improvement ranks must allow the rune.
local function runeSkillProblem(itemId)
    local bag, slot = findRune(itemId)
    if not bag then return nil end
    local _, _, runeType, rankRequirement, rarityRequirement = GetItemCraftingInfo(bag, slot)
    if not runeType or DoesRunePassRequirements(runeType, rankRequirement, rarityRequirement) then return nil end
    if runeType == ENCHANTING_RUNE_POTENCY then return "needs higher Potency Improvement" end
    if runeType == ENCHANTING_RUNE_ASPECT then return "needs higher Aspect Improvement" end
    return nil
end

local function reserveRunes(glyphId, reserved)
    local lib = LibLazyCrafting
    local enchantId = W.EnchantIdFor(glyphId)
    if not lib or not enchantId or not lib.EnchantAttributesToGlyphIds then return false, "LibLazyCrafting is needed" end
    local ok, potency, essence, aspect = pcall(lib.EnchantAttributesToGlyphIds, true, 160, enchantId, 5)
    if not ok or not potency or not essence or not aspect then return false, "unknown glyph" end
    local ids = { potency, essence, aspect }
    for _, id in ipairs(ids) do
        local have = GetItemLinkInventoryCount(runeLink(id), INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG) or 0
        if have - (reserved[id] or 0) < 1 then return false, "missing runes" end
    end
    for _, id in ipairs(ids) do
        local problem = runeSkillProblem(id)
        if problem then return false, problem end
    end
    for _, id in ipairs(ids) do reserved[id] = (reserved[id] or 0) + 1 end
    return true
end

function W.PlanGlyphs()
    local plan = { kind = "glyph", jobs = {}, blocked = {}, crystals = 0, budget = newBudget() }
    local usedGlyphs, reserved = {}, {}
    for _, piece in ipairs(sortedPieces()) do
        local glyphId = piece.want.enchant
        if glyphId then
            for _, copy in ipairs(ownedCopies(piece)) do
                if not alreadyEnchanted(copy, glyphId) then
                    local job = {
                        bag = copy.bag, slot = copy.slot, uniqueId = GetItemUniqueId(copy.bag, copy.slot),
                        glyphId = glyphId, label = piece.label, glyphName = glyphName(glyphId),
                    }
                    local glyphSlot = findGlyph(glyphId, copy, usedGlyphs)
                    if glyphSlot then
                        usedGlyphs[glyphSlot] = true
                        job.glyphSlot = glyphSlot
                        plan.jobs[#plan.jobs + 1] = job
                    else
                        local ok, reason = false, "no free bag slot"
                        -- Each glyph is applied right after crafting, so one free slot is enough for the queue
                        if plan.budget.space >= 1 then ok, reason = reserveRunes(glyphId, reserved) end
                        if ok then
                            job.craft = true
                            plan.jobs[#plan.jobs + 1] = job
                        else
                            plan.blocked[#plan.blocked + 1] = piece.label .. " " .. job.glyphName .. ": " .. reason
                        end
                    end
                end
            end
        end
    end
    return plan
end

-- Gold upgrade materials for the whole build: pieces you still need, plus pieces you own below gold.
function W.GoldTotals()
    local totals, order = {}, {}
    local function add(skill, copies)
        if copies < 1 then return end
        local key = skill
        if not totals[key] then
            local name, _, have = GetSmithingImprovementItemInfo(skill, LEGENDARY - 1)
            totals[key] = { skill = skill, name = zo_strformat("<<t:1>>", name or "gold material"), have = have or 0, need = 0 }
            order[#order + 1] = key
        end
        totals[key].need = totals[key].need + copies * (GetSmithingGuaranteedImprovementItemAmount(skill, LEGENDARY - 1) or 0)
    end
    for _, piece in ipairs(sortedPieces()) do
        if targetQuality(piece.want) >= LEGENDARY then
            local _, have, count = I.PieceStatus(piece.setId, piece.id, piece.want)
            local link = GetItemSetCollectionPieceItemLink(piece.id, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
            local skill = GetItemLinkCraftingSkillType(link)
            if GetItemLinkFunctionalQuality(link) < LEGENDARY then add(skill, count - have) end
            local below = {}
            for _, copy in ipairs(ownedCopies(piece)) do
                if copy.quality < LEGENDARY then
                    local copySkill = GetItemLinkCraftingSkillType(copy.link)
                    below[copySkill] = (below[copySkill] or 0) + 1
                end
            end
            for copySkill, copies in pairs(below) do add(copySkill, copies) end
        end
    end
    local list = {}
    for _, key in ipairs(order) do list[#list + 1] = totals[key] end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local KUTA = 45854

-- One Kuta for each gold glyph the build still has to craft. Gold CP160 glyphs you already carry are used first.
function W.KutaNeeded()
    local spare, need = {}, 0
    for _, piece in ipairs(sortedPieces()) do
        local glyphId = piece.want.enchant
        if glyphId then
            if spare[glyphId] == nil then
                spare[glyphId] = 0
                for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
                    if GetItemId(BAG_BACKPACK, slot) == glyphId then
                        local link = GetItemLink(BAG_BACKPACK, slot)
                        local _, glyphCp = GetItemLinkGlyphMinLevels(link)
                        if glyphCp == 160 and GetItemLinkFunctionalQuality(link) == LEGENDARY then spare[glyphId] = spare[glyphId] + 1 end
                    end
                end
            end
            local missing = piece.want.count or 1
            for _, copy in ipairs(ownedCopies(piece)) do
                if alreadyEnchanted(copy, glyphId) then missing = missing - 1 end
            end
            local fromBag = math.min(math.max(missing, 0), spare[glyphId])
            spare[glyphId] = spare[glyphId] - fromBag
            need = need + math.max(missing, 0) - fromBag
        end
    end
    return need
end

-- Every gold material with how many you have and how many this build will use.
-- Jewelry's Chromium Plating only appears when the build needs it.
function W.GoldMaterials()
    local used = {}
    for _, entry in ipairs(W.GoldTotals()) do used[entry.skill] = entry.need end
    local rows = {}
    for _, skill in ipairs({ CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING }) do
        local name, _, have = GetSmithingImprovementItemInfo(skill, LEGENDARY - 1)
        rows[#rows + 1] = { name = zo_strformat("<<t:1>>", name or "gold material"), have = have or 0, use = used[skill] or 0 }
    end
    local link = runeLink(KUTA)
    local kutaName = GetItemLinkName(link)
    rows[#rows + 1] = {
        name = zo_strformat("<<t:1>>", kutaName and kutaName ~= "" and kutaName or "Kuta"),
        have = GetItemLinkInventoryCount(link, INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG) or 0,
        use = W.KutaNeeded(),
    }
    if (used[CRAFTING_TYPE_JEWELRYCRAFTING] or 0) > 0 then
        local name, _, have = GetSmithingImprovementItemInfo(CRAFTING_TYPE_JEWELRYCRAFTING, LEGENDARY - 1)
        rows[#rows + 1] = { name = zo_strformat("<<t:1>>", name or "gold material"), have = have or 0, use = used[CRAFTING_TYPE_JEWELRYCRAFTING] }
    end
    local any = false
    for _, row in ipairs(rows) do any = any or row.use > 0 end
    return any and rows or {}
end

local function materialRowText(row)
    local text = row.name .. ": have " .. row.have .. ", use " .. row.use
    if row.use > row.have then text = text .. " (short " .. (row.use - row.have) .. ")" end
    return text
end

-- Shown on the side panel, so you know before walking to a station.
function W.PanelLines()
    local lines = {}
    local ok, plan = pcall(W.PlanReconstruction)
    if ok and (#plan.jobs > 0 or #plan.blocked > 0) then
        if #plan.jobs > 0 then
            lines[#lines + 1] = I.Colour("66DD66", "Transmute: " .. #plan.jobs .. " ready, " .. plan.crystals .. " crystals")
        end
        local short = shortText(plan.budget.short)
        if short ~= "" then lines[#lines + 1] = I.Colour("F0A040", "Short: " .. short) end
        -- Trait and bag problems matter as much as materials, so show each kind once
        local shown = {}
        for _, reason in ipairs(plan.blocked) do
            local text = string.match(reason, ": (.+)$") or reason
            if text ~= "not enough materials" and not shown[text] then
                shown[text] = true
                lines[#lines + 1] = I.Colour("F0A040", reason)
            end
        end
    end
    local goldOk, gold = pcall(W.GoldMaterials)
    if goldOk and #gold > 0 then
        lines[#lines + 1] = "Gold materials:"
        for _, row in ipairs(gold) do
            local colour = row.use == 0 and "AAAAAA" or (row.have >= row.use and "66DD66" or "F0A040")
            lines[#lines + 1] = I.Colour(colour, materialRowText(row))
        end
    end
    if #lines > 0 then table.insert(lines, 1, "") end
    return lines
end

---------------------------------------------------------------------------
-- Running a queue. One action at a time; any problem stops everything.
---------------------------------------------------------------------------
local run

local function finish(message)
    -- Never leave a glyph waiting in the library's queue to be crafted on a later visit
    if run and run.glyphRef and W.llc and W.llc.cancelItemByReference then
        pcall(W.llc.cancelItemByReference, W.llc, run.glyphRef)
    end
    run = nil
    if message then alert(message) end
    pcall(SH.MarkAllDirty)
    pcall(SH.Refresh)
end

local function waitFor(event)
    run.waiting = event
    run.token = (run.token or 0) + 1
    local token = run.token
    zo_callLater(function()
        if run and run.token == token and run.waiting then finish("stopped, the game didn't respond") end
    end, RESPONSE_TIMEOUT)
end

local function sameItem(job)
    return GetItemId(job.bag, job.slot) ~= 0 and GetItemUniqueId(job.bag, job.slot) == job.uniqueId
end

local STEP = {}

function STEP.transmute(job)
    if GetInteractionType() ~= INTERACTION_RETRAIT then return false, "you left the station" end
    if (GetNumBagFreeSlots(BAG_BACKPACK) or 0) < 1 then return false, "your bags are full" end
    waitFor("reconstruct")
    local ok, result = callGame("RequestItemReconstruction", job.pieceId, job.trait, job.quality, CURT_CHAOTIC_CREATIA)
    if not ok or result == false then return false, "the game refused the reconstruction" end
    job.done = true
    return true
end

function STEP.improve(job)
    if GetCraftingInteractionType() ~= run.plan.skill then return false, "you left the station" end
    if not sameItem(job) then return false, job.label .. " moved" end
    local quality = GetItemLinkFunctionalQuality(GetItemLink(job.bag, job.slot))
    if quality >= job.target then
        job.done = true
        return W.Next()
    end
    local boosters = GetSmithingGuaranteedImprovementItemAmount(run.plan.skill, quality)
    if GetSmithingImprovementChance(job.bag, job.slot, boosters, run.plan.skill) < 100 then
        return false, job.label .. " isn't at a 100% chance"
    end
    local _, _, have = GetSmithingImprovementItemInfo(run.plan.skill, quality)
    if (have or 0) < boosters then return false, "not enough materials for " .. job.label end
    waitFor("craft")
    local ok = callGame("ImproveSmithingItem", job.bag, job.slot, boosters)
    if not ok then return false, "the game refused the improvement" end
    return true
end

local function applyGlyph(job)
    if not sameItem(job) then return false, job.label .. " moved" end
    if not job.glyphSlot or not CanItemTakeEnchantment(job.bag, job.slot, BAG_BACKPACK, job.glyphSlot) then
        return false, "the glyph doesn't fit " .. job.label
    end
    local before = GetItemLink(job.bag, job.slot)
    local ok = callGame("EnchantItem", job.bag, job.slot, BAG_BACKPACK, job.glyphSlot)
    if not ok then return false, "the game refused the enchant" end
    run.token = (run.token or 0) + 1
    local token = run.token
    zo_callLater(function()
        if not run or run.token ~= token then return end
        if GetItemLink(job.bag, job.slot) == before then return finish("the enchant on " .. job.label .. " didn't apply") end
        sv.enchanted[Id64ToString(job.uniqueId)] = job.glyphId
        job.done = true
        local continued, reason = W.Next()
        if continued == false then finish(reason) end
    end, ENCHANT_DELAY)
    return true
end

function STEP.glyph(job)
    if GetCraftingInteractionType() ~= CRAFTING_TYPE_ENCHANTING then return false, "you left the station" end
    if not job.craft then return applyGlyph(job) end
    if not W.llc then return false, "LibLazyCrafting is needed" end
    if (GetNumBagFreeSlots(BAG_BACKPACK) or 0) < 1 then return false, "your bags are full" end
    waitFor("glyph")
    -- The argument after the reference is a linked gear request, so it must stay empty (quantity defaults to 1)
    run.glyphRef = "SetHunter" .. job.glyphId
    local ok = pcall(W.llc.CraftEnchantingGlyphDesiredResult, W.llc, true, 160, job.glyphId, 5, true, run.glyphRef)
    if not ok then return false, "couldn't start the glyph" end
    return true
end

function W.Next()
    if not run then return true end
    run.index = run.index or 1
    while run.plan.jobs[run.index] and run.plan.jobs[run.index].done do run.index = run.index + 1 end
    local job = run.plan.jobs[run.index]
    if not job then
        finish("finished " .. #run.plan.jobs .. (#run.plan.jobs == 1 and " piece" or " pieces"))
        return true
    end
    return STEP[run.plan.kind](job)
end

function W.IsBusy() return run ~= nil end

local function start(plan)
    if run or #plan.jobs == 0 then return end
    run = { plan = plan }
    local ok, reason = W.Next()
    if ok == false then finish("stopped: " .. tostring(reason)) end
end

-- The game needs a moment to finish its crafting animation before the next action.
local function continueRun()
    if not run then return end
    run.waiting = nil
    run.token = (run.token or 0) + 1
    local token = run.token
    zo_callLater(function()
        if not run or run.token ~= token then return end
        local ok, reason = W.Next()
        if ok == false then finish("stopped: " .. tostring(reason)) end
    end, STEP_DELAY)
end

function W.OnReconstructResponse(result)
    if not run or run.waiting ~= "reconstruct" then return end
    if result ~= RECONSTRUCT_RESPONSE_SUCCESS then return finish("stopped, the game refused that reconstruction") end
    continueRun()
end

function W.OnCraftCompleted()
    if run and run.waiting == "craft" then continueRun() end
end

function W.OnStationClosed()
    if run then finish("stopped because you left the station") end
    W.reviewPlan = nil
    if SH.Training then SH.Training.OnStationClosed() end
end

function W.OnLazyCraft(event, station, result)
    if SH.Training and SH.Training.OnLazyCraft(event, station, result) then return end
    if not run or run.waiting ~= "glyph" then return end
    if event == LLC_CRAFT_SUCCESS then
        local job = run.plan.jobs[run.index]
        run.waiting, run.glyphRef = nil, nil
        run.token = (run.token or 0) + 1
        local token = run.token
        zo_callLater(function()
            if not run or run.token ~= token then return end
            -- Don't take a glyph another piece in this queue is already using
            local used = {}
            for _, other in ipairs(run.plan.jobs) do
                if other ~= job and other.glyphSlot and not other.done then used[other.glyphSlot] = true end
            end
            local slot = findGlyph(job.glyphId, job, used)
            if not slot then return finish("couldn't find the new glyph") end
            job.glyphSlot, job.craft = slot, nil
            local ok, reason = W.Next()
            if ok == false then finish("stopped: " .. tostring(reason)) end
        end, STEP_DELAY)
    elseif event == LLC_INSUFFICIENT_MATERIALS or event == LLC_INSUFFICIENT_SKILL or event == LLC_ENCHANTMENT_FAILED then
        finish("stopped, the glyph couldn't be crafted")
    end
end

---------------------------------------------------------------------------
-- The review: one press makes everything listed
---------------------------------------------------------------------------
local QUALITY_NAME = {}
for _, quality in ipairs(QUALITIES) do QUALITY_NAME[quality.data] = quality.name end

function W.ReviewText(plan)
    local lines = {}
    for _, job in ipairs(plan.jobs) do
        if plan.kind == "transmute" then
            lines[#lines + 1] = job.label .. ": " .. I.TraitName(job.trait) .. ", " .. (QUALITY_NAME[job.quality] or "base")
        elseif plan.kind == "improve" then
            lines[#lines + 1] = job.label .. ": improve to " .. (QUALITY_NAME[job.target] or "target")
        else
            lines[#lines + 1] = job.label .. ": " .. (job.craft and "craft and apply " or "apply ") .. job.glyphName
        end
    end
    if plan.crystals > 0 then lines[#lines + 1] = "\nCost: " .. plan.crystals .. " transmute crystals" end
    if plan.kind == "glyph" then
        for _, job in ipairs(plan.jobs) do
            if job.craft then lines[#lines + 1] = "\nCrafted glyphs are gold CP160 and use your runes."; break end
        end
    end
    local goldOk, gold = pcall(W.GoldMaterials)
    if goldOk and #gold > 0 then
        lines[#lines + 1] = "\nGold materials for the whole build:"
        for _, row in ipairs(gold) do lines[#lines + 1] = materialRowText(row) end
    end
    if #plan.blocked > 0 then
        lines[#lines + 1] = "\nCan't make yet:"
        for _, reason in ipairs(plan.blocked) do lines[#lines + 1] = reason end
    end
    return table.concat(lines, "\n")
end

function W.Offer(plan)
    if not I.opts.offerAtStations or run then return end
    if #plan.jobs == 0 then
        if #plan.blocked > 0 then alert(plan.blocked[1]) end
        return
    end
    W.reviewPlan = plan
    ZO_Dialogs_ShowGamepadDialog(DIALOG, { plan = plan })
end

function W.ConfirmReview()
    local plan = W.reviewPlan
    W.reviewPlan = nil
    if plan then start(plan) end
end

local function registerDialog()
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Set Hunter" },
        mainText = { text = function(dialog) return W.ReviewText(dialog.data.plan) end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Make all", callback = function() W.ConfirmReview() end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL, callback = function() W.reviewPlan = nil end },
        },
    })
end

---------------------------------------------------------------------------
-- Builds page: Settings > Add-Ons > Set Hunter Builds
---------------------------------------------------------------------------
-- The current list is what you're working on. Saved builds are separate copies: nothing changes
-- them except Save changes, Rename and Delete, so editing or clearing the list can't lose one.
local function cleanName(name)
    if type(name) ~= "string" then return nil end
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then return nil end
    return name
end

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function currentBuild() return sv.builds[sv.activeBuild] end

local function pieceCount(build)
    local count = 0
    for _, goal in pairs(build.sets) do
        for _ in pairs(goal.wants) do count = count + 1 end
    end
    return count
end

local function piecesText(count) return count .. (count == 1 and " piece" or " pieces") end

function W.CurrentName() return sv.loadedBuild or "your list" end

function W.HasChanges()
    local current = currentBuild()
    local saved = sv.loadedBuild and sv.savedBuilds[sv.loadedBuild]
    if saved then return not same(current, saved) end
    return next(current.sets) ~= nil
end

function W.PanelTitle()
    if not sv.loadedBuild then return nil end
    return sv.loadedBuild .. (W.HasChanges() and " (unsaved)" or "")
end

function W.StatusText()
    local count = pieceCount(currentBuild())
    if sv.loadedBuild then
        return "Current list: " .. sv.loadedBuild .. ", " .. piecesText(count)
            .. (W.HasChanges() and " (unsaved changes)" or " (saved)")
    end
    if count == 0 then return "Current list: empty" end
    return "Current list: " .. piecesText(count) .. " (not saved yet)"
end

function W.SavedNames()
    local names = {}
    for name in pairs(sv.savedBuilds) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- Scrolling a console dropdown only changes this choice. Nothing loads until you press Load.
function W.PickedSaved()
    if W.pickedSaved and sv.savedBuilds[W.pickedSaved] then return W.pickedSaved end
    if sv.loadedBuild and sv.savedBuilds[sv.loadedBuild] then return sv.loadedBuild end
    return W.SavedNames()[1]
end

function W.SavedText(name)
    local build = name and sv.savedBuilds[name]
    if not build then return "No saved builds yet. Set up your list, then use Save as new build." end
    local sets = {}
    for setId in pairs(build.sets) do sets[#sets + 1] = zo_strformat("<<t:1>>", GetItemSetName(setId)) end
    table.sort(sets)
    local text = name .. ": " .. piecesText(pieceCount(build))
    if #sets > 0 then text = text .. "\n" .. table.concat(sets, "\n") end
    return text
end

function W.SaveAsNew(name)
    name = cleanName(name)
    if not name then return false end
    if sv.savedBuilds[name] then
        alert("a build called " .. name .. " already exists")
        return false
    end
    if next(currentBuild().sets) == nil then
        alert("add some pieces before saving")
        return false
    end
    sv.savedBuilds[name] = SH.DeepCopy(currentBuild())
    sv.loadedBuild, W.pickedSaved = name, name
    SH.Refresh()
    alert("saved " .. name)
    return true
end

function W.CanSaveChanges()
    return sv.loadedBuild ~= nil and next(currentBuild().sets) ~= nil and W.HasChanges()
end

-- An empty list never overwrites a build. To get rid of one, use Delete.
function W.SaveChanges()
    if not W.CanSaveChanges() then return false end
    sv.savedBuilds[sv.loadedBuild] = SH.DeepCopy(currentBuild())
    SH.Refresh()
    alert("saved " .. sv.loadedBuild)
    return true
end

function W.LoadSaved(name)
    local build = name and sv.savedBuilds[name]
    if not build then return false end
    if W.IsBusy() then
        alert("wait for the current job to finish")
        return false
    end
    sv.loadedBuild, W.pickedSaved, W.selected = name, name, nil
    SH.SetCurrentBuild(SH.DeepCopy(build))
    alert("loaded " .. name)
    return true
end

function W.OfferLoad(onDone)
    local name = W.PickedSaved()
    if not name then return alert("no saved builds yet") end
    if W.HasChanges() and next(currentBuild().sets) ~= nil then
        ZO_Dialogs_ShowGamepadDialog(DIALOG .. "_LOAD", { name = name, onDone = onDone })
    elseif W.LoadSaved(name) and onDone then
        onDone()
    end
end

function W.RenameSaved(newName)
    local oldName = W.PickedSaved()
    newName = cleanName(newName)
    if not oldName or not newName or newName == oldName then return false end
    if sv.savedBuilds[newName] then
        alert("a build called " .. newName .. " already exists")
        return false
    end
    sv.savedBuilds[newName], sv.savedBuilds[oldName] = sv.savedBuilds[oldName], nil
    if sv.loadedBuild == oldName then sv.loadedBuild = newName end
    W.pickedSaved = newName
    SH.Refresh()
    return true
end

-- Your current list stays as it is, just no longer linked to a saved build.
function W.DeleteSaved(name)
    if not name or not sv.savedBuilds[name] then return false end
    sv.savedBuilds[name] = nil
    if sv.loadedBuild == name then sv.loadedBuild = nil end
    if W.pickedSaved == name then W.pickedSaved = nil end
    SH.Refresh()
    return true
end

---------------------------------------------------------------------------
-- The active build
---------------------------------------------------------------------------
local function activeBuild() return sv.builds[sv.activeBuild] end

-- Empties the current list. Saved builds, items and locks are left alone.
function W.ClearSets()
    if run then
        alert("wait for the current job to finish")
        return false
    end
    local count = SH.ClearActiveSets()
    sv.loadedBuild, W.selected, W.reviewPlan = nil, nil, nil
    alert("cleared " .. piecesText(count) .. " from your current list")
    return true
end

-- The main settings page is created before the workshop starts, so this must be safe before Init
function W.HasSets() return I ~= nil and next(I.ActiveSets()) ~= nil end

function W.OfferClearSets(onDone)
    if not W.HasSets() then return alert("your current list is already empty") end
    ZO_Dialogs_ShowGamepadDialog(DIALOG .. "_CLEAR", { unsaved = W.HasChanges(), onDone = onDone })
end

local function selectedPiece()
    local pieces = sortedPieces()
    for _, piece in ipairs(pieces) do
        if piece.id == W.selected then return piece end
    end
    return pieces[1]
end

local function createBuildsPage()
    local LHAS = LibHarvensAddonSettings
    if not LHAS or not LHAS.AddAddon then return end
    local page = LHAS:AddAddon("Set Hunter Builds", { allowDefaults = false, allowRefresh = true })
    local function redraw() pcall(function() page:UpdateControls() end) end

    local function savedItems()
        local items = {}
        for _, name in ipairs(W.SavedNames()) do items[#items + 1] = { name = name, data = name } end
        if #items == 0 then items[1] = { name = "No saved builds", data = "" } end
        return items
    end
    local function pieceItems()
        local items = {}
        for _, piece in ipairs(sortedPieces()) do
            local setName = zo_strformat("<<t:1>>", GetItemSetName(piece.setId))
            items[#items + 1] = { name = piece.label .. " - " .. setName, data = piece.id }
        end
        if #items == 0 then items[1] = { name = "No pieces yet", data = 0 } end
        return items
    end
    local function nameFor(items, value, fallback)
        for _, item in ipairs(items) do
            if item.data == value then return item.name end
        end
        return fallback
    end
    local function defaultKey(piece)
        if piece.want.category == ITEM_TRAIT_TYPE_CATEGORY_WEAPON then return "weaponTrait" end
        if piece.want.category == ITEM_TRAIT_TYPE_CATEGORY_JEWELRY then return "jewelryTrait" end
        return "armorTrait"
    end
    local function defaultLabel(piece)
        local value = piece and I.opts[defaultKey(piece)] or 0
        return "Default (" .. (value == 0 and "any trait" or I.TraitName(value)) .. ")"
    end
    local function traitItems()
        local piece = selectedPiece()
        local items = { { name = defaultLabel(piece), data = -1 }, { name = "Any trait", data = 0 } }
        if not piece then return items end
        local key = "armorTrait"
        if piece.want.category == ITEM_TRAIT_TYPE_CATEGORY_WEAPON then key = "weaponTrait" end
        if piece.want.category == ITEM_TRAIT_TYPE_CATEGORY_JEWELRY then key = "jewelryTrait" end
        for _, suffix in ipairs(I.TRAITS[key]) do
            local value = _G[I.PREFIX[key] .. suffix]
            if value then items[#items + 1] = { name = GetString("SI_ITEMTRAITTYPE", value), data = value } end
        end
        return items
    end
    local function enchantItems()
        local items = { { name = "Keep current", data = 0 } }
        local piece = selectedPiece()
        if piece then
            for _, glyph in ipairs(glyphGroup(piece.want)) do items[#items + 1] = { name = glyph[1], data = glyph[2] } end
        end
        return items
    end
    local function changed() SH.MarkAllDirty(); SH.Refresh(); redraw() end
    local function canHaveTwo(want)
        return want.equip == EQUIP_TYPE_RING or (want.equip == EQUIP_TYPE_ONE_HAND and want.weapon ~= WEAPONTYPE_SHIELD)
    end
    local function defaultTraitDropdown(label, key)
        local function items()
            local list = { { name = "Any trait", data = 0 } }
            for _, suffix in ipairs(I.TRAITS[key]) do
                local value = _G[I.PREFIX[key] .. suffix]
                if value then list[#list + 1] = { name = GetString("SI_ITEMTRAITTYPE", value), data = value } end
            end
            return list
        end
        return {
            type = LHAS.ST_DROPDOWN, label = label, items = items,
            tooltip = "Used by every piece whose own Trait is set to Default.",
            getFunction = function() return nameFor(items(), I.opts[key], "Any trait") end,
            setFunction = function(_, _, item) I.opts[key] = I.DropdownValue(item, I.opts[key]); changed() end,
        }
    end
    page:AddSettings({
        { type = LHAS.ST_SECTION, label = "Current list" },
        { type = LHAS.ST_LABEL, label = function() return W.StatusText() end },
        {
            type = LHAS.ST_EDIT, label = "Save as new build",
            tooltip = "Stores a copy of your current list under this name. You can then change or clear the list without affecting it.",
            getFunction = function() return "" end,
            setFunction = function(value) if W.SaveAsNew(value) then redraw() end end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Save changes to this build", buttonText = "Save changes",
            tooltip = function()
                if sv.loadedBuild then return "Updates " .. sv.loadedBuild .. " to match your current list." end
                return "Load a saved build first, or use Save as new build."
            end,
            disable = function() return not W.CanSaveChanges() end,
            clickHandler = function() if W.SaveChanges() then redraw() end end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Clear all sets", buttonText = "Clear all",
            tooltip = "Empties your current list in one go. Saved builds and your items aren't touched, and pieces already locked stay locked.",
            disable = function() return not W.HasSets() end,
            clickHandler = function() W.OfferClearSets(redraw) end,
        },
        { type = LHAS.ST_SECTION, label = "Saved builds" },
        {
            type = LHAS.ST_DROPDOWN, label = "Saved build", items = savedItems,
            tooltip = function() return W.SavedText(W.PickedSaved()) end,
            getFunction = function() return W.PickedSaved() or "No saved builds" end,
            setFunction = function(_, _, item)
                local name = I.DropdownValue(item, "")
                if name ~= "" then W.pickedSaved = name end
                pcall(function()
                    GAMEPAD_TOOLTIPS:LayoutSettingTooltip(GAMEPAD_LEFT_TOOLTIP, W.SavedText(W.PickedSaved()), "")
                end)
            end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Load this build", buttonText = "Load",
            tooltip = "Puts this saved build into your current list. The saved copy stays as it is.",
            disable = function() return W.PickedSaved() == nil end,
            clickHandler = function() W.OfferLoad(redraw) end,
        },
        {
            type = LHAS.ST_EDIT, label = "Rename this build",
            disable = function() return W.PickedSaved() == nil end,
            getFunction = function() return "" end,
            setFunction = function(value) if W.RenameSaved(value) then redraw() end end,
        },
        {
            type = LHAS.ST_BUTTON, label = "Delete this build", buttonText = "Delete",
            tooltip = "Permanently removes this saved build. Your items and current list aren't touched.",
            disable = function() return W.PickedSaved() == nil end,
            clickHandler = function()
                local name = W.PickedSaved()
                if not name then return end
                ZO_Dialogs_ShowGamepadDialog(DIALOG .. "_DELETE", { name = name, onConfirm = function()
                    W.DeleteSaved(name); redraw()
                end })
            end,
        },
        { type = LHAS.ST_SECTION, label = "Default traits" },
        defaultTraitDropdown("Armor", "armorTrait"),
        defaultTraitDropdown("Weapons", "weaponTrait"),
        defaultTraitDropdown("Jewelry", "jewelryTrait"),
        { type = LHAS.ST_SECTION, label = "Piece" },
        {
            type = LHAS.ST_DROPDOWN, label = "Piece to edit", items = pieceItems,
            getFunction = function()
                local piece = selectedPiece()
                return piece and nameFor(pieceItems(), piece.id, "No pieces yet") or "No pieces yet"
            end,
            setFunction = function(_, _, item) W.selected = I.DropdownValue(item, W.selected); redraw() end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Trait", items = traitItems,
            getFunction = function()
                local piece = selectedPiece()
                if not piece or piece.want.trait == nil then return defaultLabel(piece) end
                return nameFor(traitItems(), piece.want.trait, defaultLabel(piece))
            end,
            setFunction = function(_, _, item)
                local piece = selectedPiece()
                if not piece then return end
                local value = I.DropdownValue(item, -1)
                if value == -1 then piece.want.trait = nil else piece.want.trait = value end
                changed()
            end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "How many", items = { { name = "1", data = 1 }, { name = "2", data = 2 } },
            tooltip = "Two matching pieces, for rings and one-handed weapons.",
            disable = function()
                local piece = selectedPiece()
                return not piece or not canHaveTwo(piece.want)
            end,
            getFunction = function()
                local piece = selectedPiece()
                return tostring(piece and piece.want.count or 1)
            end,
            setFunction = function(_, _, item)
                local piece = selectedPiece()
                if piece and canHaveTwo(piece.want) then
                    piece.want.count = I.DropdownValue(item, 1)
                    changed()
                end
            end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Quality", items = QUALITIES,
            getFunction = function()
                local piece = selectedPiece()
                return QUALITY_NAME[piece and targetQuality(piece.want) or LEGENDARY]
            end,
            setFunction = function(_, _, item)
                local piece = selectedPiece()
                if piece then piece.want.quality = I.DropdownValue(item, LEGENDARY); changed() end
            end,
        },
        {
            type = LHAS.ST_DROPDOWN, label = "Enchant", items = enchantItems,
            tooltip = "Crafted glyphs are gold CP160. Crafting needs LibLazyCrafting and your runes.",
            getFunction = function()
                local piece = selectedPiece()
                if not piece or not piece.want.enchant then return "Keep current" end
                return glyphName(piece.want.enchant)
            end,
            setFunction = function(_, _, item)
                local piece = selectedPiece()
                if not piece then return end
                local value = I.DropdownValue(item, 0)
                piece.want.enchant = value ~= 0 and value or nil
                changed()
            end,
        },
        { type = LHAS.ST_SECTION, label = "Stations" },
        {
            type = LHAS.ST_CHECKBOX, label = "Offer to make pieces at stations", default = true,
            tooltip = "Show a review when you open a transmute, crafting or enchanting station. Nothing is spent until you press Make all.",
            getFunction = function() return I.opts.offerAtStations end,
            setFunction = function(value) I.opts.offerAtStations = value end,
        },
    })
end

---------------------------------------------------------------------------
-- Start up
---------------------------------------------------------------------------
local SMITHING_SKILLS = {}
for _, skill in ipairs({ CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING }) do
    SMITHING_SKILLS[skill] = true
end

local function offerSoon(makePlan)
    zo_callLater(function()
        local ok, plan = pcall(makePlan)
        if ok and plan then pcall(W.Offer, plan) end
    end, 700)
end

function W.Init()
    I = SH.internal
    sv = I.sv
    sv.enchanted = sv.enchanted or {}
    -- Champion Points, saved skills and weapon bars were removed, so drop what older versions saved
    for _, builds in ipairs({ sv.builds, sv.savedBuilds }) do
        for _, build in pairs(builds) do
            build.cp, build.cpPicks, build.useCp, build.skills = nil, nil, nil, nil
            for _, goal in pairs(build.sets) do
                for _, want in pairs(goal.wants) do want.bar = nil end
            end
        end
    end
    if I.opts.offerAtStations == nil then I.opts.offerAtStations = true end

    registerDialog()
    ZO_Dialogs_RegisterCustomDialog(DIALOG .. "_DELETE", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Delete build" },
        mainText = { text = function(dialog) return "Permanently delete the saved build \"" .. dialog.data.name .. "\"? Your items and current list aren't touched." end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Delete", callback = function(dialog) dialog.data.onConfirm() end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })
    ZO_Dialogs_RegisterCustomDialog(DIALOG .. "_LOAD", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Load build" },
        mainText = { text = function(dialog)
            return "Your current list has unsaved changes. Load \"" .. dialog.data.name .. "\" and replace them?"
        end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Load", callback = function(dialog)
                if W.LoadSaved(dialog.data.name) and dialog.data.onDone then dialog.data.onDone() end
            end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })
    ZO_Dialogs_RegisterCustomDialog(DIALOG .. "_CLEAR", {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = "Clear all sets" },
        mainText = { text = function(dialog) return (dialog.data.unsaved and "Your current list has unsaved changes. " or "")
            .. "Empty the current list? Saved builds and your items aren't touched." end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Clear all", callback = function(dialog)
                if W.ClearSets() and dialog.data.onDone then dialog.data.onDone() end
            end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })
    createBuildsPage()

    if LibLazyCrafting and LibLazyCrafting.AddRequestingAddon then
        local ok, requester = pcall(LibLazyCrafting.AddRequestingAddon, LibLazyCrafting, "ESOCSetHunter", true, function(...)
            pcall(W.OnLazyCraft, ...)
        end)
        if ok then W.llc = requester end
    end

    if SH.Training then SH.Training.Init() end

    local name = "ESOCSetHunterWorkshop"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_RETRAIT_STATION_INTERACT_START, function() offerSoon(W.PlanReconstruction) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CRAFTING_STATION_INTERACT, function(_, skill)
        if SMITHING_SKILLS[skill] then
            offerSoon(function()
                -- A training kit with work at this station comes first
                if SH.Training and SH.Training.OfferHere(skill) then return nil end
                return W.PlanImprovement(skill)
            end)
        elseif skill == CRAFTING_TYPE_ENCHANTING then
            offerSoon(W.PlanGlyphs)
        end
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_END_CRAFTING_STATION_INTERACT, function() W.OnStationClosed() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_RECONSTRUCT_RESPONSE, function(_, result) W.OnReconstructResponse(result) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CRAFT_COMPLETED, function() W.OnCraftCompleted() end)
end
