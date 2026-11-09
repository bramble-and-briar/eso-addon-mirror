-- CPPresets.lua
-- One-tap Champion Point presets, aimed at new characters: for each tree it unlocks the path to
-- four "main" slottable stars, maxes them, fills every remaining point into passive stars, and
-- slots the four main stars. Stars are named, then looked up in the live game, so the presets
-- survive ID changes; anything not found is reported instead of guessed.
--
-- Each tree lists main stars in priority order: the first four that exist and can be afforded are
-- used, the rest are backups. "fill" lists passive stars to fill first; after that, any remaining
-- points go into other reachable passive stars.

ESOC_CPPresets = ESOC_CPPresets or {}
local CP = ESOC_CPPresets

CP.presets = {
    {
        name = "Single-target DPS",
        desc = "Trials and boss fights: damage against one target.",
        warfare = { main = { "Deadly Aim", "Master-at-Arms", "Fighting Finesse", "Backstabber", "Thaumaturge", "Exploiter" },
                    fill = { "Precision", "Piercing", "Wrathful Strikes", "Battle Mastery", "Mighty", "Flawless Ritual" } },
        fitness = { main = { "Boundless Vitality", "Rejuvenation", "Celerity", "Fortified", "Strategic Reserve" },
                    fill = { "Hero's Vigor", "Mystic Tenacity", "Tireless Guardian", "Defiance", "Sprinter", "Hasty" } },
        craft   = { main = { "Steed's Blessing", "Rationer", "Liquid Efficiency", "Treasure Hunter", "Gilded Fingers" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall" } },
    },
    {
        name = "AoE DPS",
        desc = "Dungeons, trash packs and overland: damage to groups.",
        warfare = { main = { "Biting Aura", "Thaumaturge", "Master-at-Arms", "Fighting Finesse", "Deadly Aim", "Exploiter" },
                    fill = { "Precision", "Piercing", "Wrathful Strikes", "Battle Mastery", "Mighty", "Flawless Ritual" } },
        fitness = { main = { "Boundless Vitality", "Rejuvenation", "Celerity", "Fortified", "Strategic Reserve" },
                    fill = { "Hero's Vigor", "Mystic Tenacity", "Tireless Guardian", "Defiance", "Sprinter", "Hasty" } },
        craft   = { main = { "Steed's Blessing", "Rationer", "Liquid Efficiency", "Treasure Hunter", "Gilded Fingers" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall" } },
    },
    {
        name = "Tank",
        desc = "Survive, hold aggro, keep resources up for blocking.",
        warfare = { main = { "Enlivening Overflow", "Unassailable", "Duelist's Rebuff", "Riposte", "From the Brink", "Foresight" },
                    fill = { "Ironclad", "Arcane Supremacy", "Battle Mastery", "Tireless Discipline" } },
        fitness = { main = { "Bastion", "Fortified", "Boundless Vitality", "Rejuvenation", "Strategic Reserve", "Spirit Mastery" },
                    fill = { "Defiance", "Hero's Vigor", "Mystic Tenacity", "Tireless Guardian", "Bracing Anchor", "Fortification" } },
        craft   = { main = { "Steed's Blessing", "Rationer", "Liquid Efficiency", "Treasure Hunter", "Gilded Fingers" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall" } },
    },
    {
        name = "Healer",
        desc = "Stronger heals and shields, buffs for the group.",
        warfare = { main = { "Hope Infusion", "Enlivening Overflow", "From the Brink", "Foresight", "Salve of Renewal", "Swift Renewal" },
                    fill = { "Rejuvenator", "Soothing Tide", "Focused Mending", "Swift Renewal", "Tireless Discipline" } },
        fitness = { main = { "Boundless Vitality", "Rejuvenation", "Celerity", "Fortified", "Spirit Mastery", "Strategic Reserve" },
                    fill = { "Hero's Vigor", "Mystic Tenacity", "Tireless Guardian", "Defiance", "Sprinter", "Hasty" } },
        craft   = { main = { "Steed's Blessing", "Rationer", "Liquid Efficiency", "Treasure Hunter", "Gilded Fingers" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall" } },
    },
    {
        name = "Solo / questing",
        desc = "Overland, quests and solo content: damage, self-healing, more loot.",
        warfare = { main = { "Biting Aura", "Reaving Blows", "Master-at-Arms", "Fighting Finesse", "Thaumaturge", "Deadly Aim" },
                    fill = { "Precision", "Piercing", "Wrathful Strikes", "Battle Mastery", "Mighty" } },
        fitness = { main = { "Boundless Vitality", "Rejuvenation", "Celerity", "Strategic Reserve", "Fortified" },
                    fill = { "Hero's Vigor", "Sprinter", "Hasty", "Mystic Tenacity", "Tireless Guardian", "Defiance" } },
        craft   = { main = { "Steed's Blessing", "Treasure Hunter", "Gilded Fingers", "Homemaker", "Rationer", "Liquid Efficiency" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall", "Reel Technique" } },
    },
    {
        name = "PvP",
        desc = "Cyrodiil and battlegrounds: burst, survival, mobility.",
        warfare = { main = { "Fighting Finesse", "Deadly Aim", "Backstabber", "Reaving Blows", "Thaumaturge", "Master-at-Arms" },
                    fill = { "Precision", "Piercing", "Battle Mastery", "Mighty", "Ironclad" } },
        fitness = { main = { "Boundless Vitality", "Pain's Refuge", "Fortified", "Rejuvenation", "Bastion", "Slippery", "Celerity" },
                    fill = { "Defiance", "Hero's Vigor", "Mystic Tenacity", "Tireless Guardian", "Sprinter", "Hasty" } },
        craft   = { main = { "Steed's Blessing", "Rationer", "Liquid Efficiency", "Fade Away", "Treasure Hunter" },
                    fill = { "Gifted Rider", "War Mount", "Steadfast Enchantment", "Breakfall" } },
    },
}

---------------------------------------------------------------------------
-- Reading the live constellations
---------------------------------------------------------------------------
local function safe(fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

local function norm(name)
    -- compare names loosely: lowercase, letters and digits only (handles ' vs ’ and "Master-at-Arms")
    local s = name or ""
    local ok, formatted = pcall(zo_strformat, "<<1>>", s)
    if ok and type(formatted) == "string" then s = formatted end
    return (s:lower():gsub("[^%a%d]", ""))
end

-- Builds { [treeKey] = { id = disciplineId, name, skills = {id -> info}, byName = {norm -> id} } }
function CP.ReadTrees()
    local keys = {
        [CHAMPION_DISCIPLINE_TYPE_COMBAT or -1] = "warfare",
        [CHAMPION_DISCIPLINE_TYPE_CONDITIONING or -2] = "fitness",
        [CHAMPION_DISCIPLINE_TYPE_WORLD or -3] = "craft",
    }
    local trees = {}
    for di = 1, (safe(GetNumChampionDisciplines) or 0) do
        local discId = safe(GetChampionDisciplineId, di)
        local key = discId and keys[safe(GetChampionDisciplineType, discId)]
        if key then
            local tree = { id = discId, name = safe(GetChampionDisciplineName, discId) or key, skills = {}, byName = {}, order = {} }
            local function add(id)
                if not id or id == 0 or tree.skills[id] then return end
                local jumps = {}
                if safe(DoesChampionSkillHaveJumpPoints, id) then
                    jumps = { safe(GetChampionSkillJumpPoints, id) }
                end
                local info = {
                    id = id,
                    name = safe(GetChampionSkillName, id) or tostring(id),
                    slottable = safe(CanChampionSkillTypeBeSlotted, safe(GetChampionSkillType, id)) and true or false,
                    root = safe(IsChampionSkillRootNode, id) and true or false,
                    max = safe(GetChampionSkillMaxPoints, id) or 0,
                    saved = safe(GetNumPointsSpentOnChampionSkill, id) or 0,
                    jumps = (#jumps > 0) and jumps or nil,
                    links = {},
                }
                tree.skills[id] = info
                tree.order[#tree.order + 1] = id
                tree.byName[norm(info.name)] = id
            end
            for si = 1, (safe(GetNumChampionDisciplineSkills, di) or 0) do
                local id = safe(GetChampionSkillId, di, si)
                add(id)
                if id and safe(IsChampionSkillClusterRoot, id) then
                    for _, member in ipairs({ safe(GetChampionClusterSkillIds, id) }) do add(member) end
                end
            end
            -- links (both directions) plus cluster membership
            local function link(a, b)
                if a ~= b and tree.skills[a] and tree.skills[b] then
                    tree.skills[a].links[b] = true
                    tree.skills[b].links[a] = true
                end
            end
            for _, id in ipairs(tree.order) do
                for _, other in ipairs({ safe(GetChampionSkillLinkIds, id) }) do link(id, other) end
                if safe(IsChampionSkillClusterRoot, id) then
                    for _, member in ipairs({ safe(GetChampionClusterSkillIds, id) }) do link(id, member) end
                end
            end
            tree.unspent = safe(GetNumUnspentChampionPoints, discId) or 0
            trees[key] = tree
        end
    end
    return trees
end

---------------------------------------------------------------------------
-- Planning
---------------------------------------------------------------------------
-- Allowed point values for a star, ascending
local function allowedValues(info)
    if info.jumps then
        local v = {}
        for _, j in ipairs(info.jumps) do v[#v + 1] = j end
        table.sort(v)
        return v
    end
    local v = {}
    for p = 0, info.max do v[#v + 1] = p end
    return v
end

-- Smallest allowed value >= the current points that unlocks the star
local function unlockValue(info)
    for _, p in ipairs(allowedValues(info)) do
        if p > 0 and p >= info.pending and safe(WouldChampionSkillNodeBeUnlocked, info.id, p) then return p end
    end
    return nil
end

-- Largest allowed value we can afford (current pending + budget)
local function bestValue(info, budget)
    local best = info.pending
    for _, p in ipairs(allowedValues(info)) do
        if p > best and p - info.pending <= budget then best = p end
    end
    return best
end

local function isUnlocked(info)
    return info.pending > 0 and safe(WouldChampionSkillNodeBeUnlocked, info.id, info.pending) and true or false
end

local function canTakePoints(tree, info)
    if info.root or isUnlocked(info) then return true end
    for other in pairs(info.links) do
        if isUnlocked(tree.skills[other]) then return true end
    end
    return false
end

-- Shortest path of locked stars from something reachable to the target (BFS over links)
local function pathTo(tree, targetId)
    local start, prev, queue, seen = nil, {}, {}, {}
    for _, id in ipairs(tree.order) do
        local info = tree.skills[id]
        if info.root or isUnlocked(info) then
            queue[#queue + 1] = id
            seen[id] = true
        end
    end
    local head = 1
    while head <= #queue do
        local id = queue[head]
        head = head + 1
        if id == targetId then start = id break end
        for other in pairs(tree.skills[id].links) do
            if not seen[other] then
                seen[other] = true
                prev[other] = id
                queue[#queue + 1] = other
            end
        end
    end
    if not start then return nil end
    local path, cur = {}, targetId
    while cur do
        table.insert(path, 1, cur)
        cur = prev[cur]
    end
    return path
end

-- Plan one tree. Returns { main = {ids}, missing = {names}, spend = {id -> points}, spent, left }
local function planTree(tree, spec)
    for _, info in pairs(tree.skills) do info.pending = info.saved end
    local budget = tree.unspent
    local plan = { main = {}, missing = {}, skipped = {} }

    local function unlockPath(targetId)
        local path = pathTo(tree, targetId)
        if not path then return false end
        -- cost first, so we never half-unlock a path we can't finish
        local cost = 0
        for _, id in ipairs(path) do
            local info = tree.skills[id]
            if not isUnlocked(info) then
                local v = unlockValue(info)
                if not v then return false end
                cost = cost + (v - info.pending)
            end
        end
        if cost > budget then return false end
        for _, id in ipairs(path) do
            local info = tree.skills[id]
            if not isUnlocked(info) then
                local v = unlockValue(info)
                budget = budget - (v - info.pending)
                info.pending = v
            end
        end
        return true
    end

    -- 1. the four main stars: unlock their paths
    for _, name in ipairs(spec.main) do
        if #plan.main >= 4 then break end
        local id = tree.byName[norm(name)]
        local info = id and tree.skills[id]
        if not info or not info.slottable then
            plan.missing[#plan.missing + 1] = name
        elseif unlockPath(id) then
            plan.main[#plan.main + 1] = id
        else
            plan.skipped[#plan.skipped + 1] = name
        end
    end
    -- 2. max the main stars
    for _, id in ipairs(plan.main) do
        local info = tree.skills[id]
        local v = bestValue(info, budget)
        budget = budget - (v - info.pending)
        info.pending = v
    end
    -- 3. preferred passive stars, then every other reachable passive star
    local function fill(id)
        local info = tree.skills[id]
        if not info or info.slottable or budget <= 0 or not canTakePoints(tree, info) then return false end
        local v = bestValue(info, budget)
        if v > info.pending then
            budget = budget - (v - info.pending)
            info.pending = v
            return true
        end
        return false
    end
    for _, name in ipairs(spec.fill or {}) do
        local id = tree.byName[norm(name)]
        if id then
            if not canTakePoints(tree, tree.skills[id]) then unlockPath(id) end
            fill(id)
        end
    end
    local progress = true
    while budget > 0 and progress do
        progress = false
        for _, id in ipairs(tree.order) do
            if fill(id) then progress = true end
        end
    end

    plan.spend = {}
    plan.spent = 0
    for _, id in ipairs(tree.order) do
        local info = tree.skills[id]
        if info.pending ~= info.saved then
            plan.spend[id] = info.pending
            plan.spent = plan.spent + (info.pending - info.saved)
        end
    end
    plan.left = budget
    return plan
end

-- Plan a whole preset: { warfare = plan, fitness = plan, craft = plan }, trees
function CP.Plan(preset)
    local trees = CP.ReadTrees()
    local plans = {}
    for _, key in ipairs({ "warfare", "fitness", "craft" }) do
        if trees[key] and preset[key] then plans[key] = planTree(trees[key], preset[key]) end
    end
    return plans, trees
end

---------------------------------------------------------------------------
-- Applying: one purchase request, like the game's own Champion screen
---------------------------------------------------------------------------
function CP.Apply(plans, trees)
    local availability = safe(GetChampionPurchaseAvailability)
    if availability and CHAMPION_PURCHASE_SUCCESS and availability ~= CHAMPION_PURCHASE_SUCCESS then
        return false, availability
    end
    PrepareChampionPurchaseRequest(false)
    for key, plan in pairs(plans) do
        for id, points in pairs(plan.spend) do AddSkillToChampionPurchaseRequest(id, points) end
    end
    -- slot the main stars into the bar slots that belong to each tree
    for slot = 1, 12 do
        local requiredDisc = safe(GetRequiredChampionDisciplineIdForSlot, slot, HOTBAR_CATEGORY_CHAMPION)
        for key, plan in pairs(plans) do
            if trees[key].id == requiredDisc then
                plan.nextSlot = (plan.nextSlot or 0) + 1
                local id = plan.main[plan.nextSlot]
                if id then AddHotbarSlotToChampionPurchaseRequest(slot, id) end
            end
        end
    end
    for _, plan in pairs(plans) do plan.nextSlot = nil end
    SendChampionPurchaseRequest()
    return true
end

-- Structured summary per tree, for the menu screen:
-- { key, name, unspent, spent, left, slots = { {name, points} }, passivePoints, passiveStars, missing, skipped }
function CP.Summary(plans, trees)
    local out = {}
    for _, key in ipairs({ "warfare", "fitness", "craft" }) do
        local plan, tree = plans[key], trees[key]
        local s = { key = key, name = tree and tree.name or key, unspent = tree and tree.unspent or 0,
                    spent = 0, left = 0, slots = {}, passivePoints = 0, passiveStars = 0, missing = {}, skipped = {} }
        if plan then
            s.spent, s.left, s.missing, s.skipped = plan.spent, plan.left, plan.missing, plan.skipped
            local isMain = {}
            for _, id in ipairs(plan.main) do
                local info = tree.skills[id]
                isMain[id] = true
                s.slots[#s.slots + 1] = { name = info.name, points = plan.spend[id] or info.saved }
            end
            for id, points in pairs(plan.spend) do
                if not isMain[id] then
                    s.passivePoints = s.passivePoints + (points - tree.skills[id].saved)
                    s.passiveStars = s.passiveStars + 1
                end
            end
        end
        out[#out + 1] = s
    end
    return out
end

-- Human-readable summary lines for the screen
function CP.Describe(preset, plans, trees)
    local lines = { preset.desc, "" }
    local labels = { warfare = "Warfare (blue)", fitness = "Fitness (red)", craft = "Craft (green)" }
    for _, key in ipairs({ "warfare", "fitness", "craft" }) do
        local plan, tree = plans[key], trees[key]
        if plan then
            local names = {}
            for _, id in ipairs(plan.main) do names[#names + 1] = tree.skills[id].name end
            lines[#lines + 1] = string.format("%s: %d points", labels[key], plan.spent)
            lines[#lines + 1] = "   Slots: " .. (#names > 0 and table.concat(names, ", ") or "(none affordable yet)")
            if #plan.missing > 0 then lines[#lines + 1] = "   Not found in game: " .. table.concat(plan.missing, ", ") end
            if #plan.skipped > 0 then lines[#lines + 1] = "   Not enough points yet: " .. table.concat(plan.skipped, ", ") end
        end
    end
    return lines
end
