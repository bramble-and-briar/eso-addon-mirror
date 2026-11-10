-- Presets.lua
-- The Champion Point logic for CP Presets: the starter presets, reading the live constellations,
-- planning a preset for this character, applying it in one purchase request, and saving the
-- character's current points and slotted stars as a preset of the player's own.
--
-- Starter presets: for each tree they unlock the path to four "main" slottable stars, max them, fill
-- every remaining point into passive stars, and slot the four main stars. On a character with points
-- already spent they are rebuilt from zero (a respec, which costs gold) unless the preset only adds
-- points. The star choices are general community picks, not maths for one character.
--
-- Your own presets restore exactly what you saved. If that means taking points out of stars the
-- character has already bought, it needs a respec (gold, like the game's own Champion screen). On a
-- character with fewer points, slotted stars come first, then the other stars, biggest first.
--
-- Stars are stored by name and ID and looked up in the live game, so presets survive ID changes;
-- anything not found is reported instead of guessed.

ESOC_CPP = ESOC_CPP or {}
local CP = ESOC_CPP
local TREE_KEYS = { "warfare", "fitness", "craft" }
CP.TREE_KEYS = TREE_KEYS

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
        name = "Heavy attacks",
        desc = "Builds that deal most of their damage with heavy attacks.",
        warfare = { main = { "Deadly Aim", "Master-at-Arms", "Fighting Finesse", "Biting Aura", "Exploiter", "Backstabber" },
                    fill = { "Wrathful Strikes", "Precision", "Piercing", "Mighty", "Battle Mastery", "Flawless Ritual" } },
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
-- Calls a game function, returning nil instead of failing. Passes back every return value: jump
-- points and link lists can be longer than five.
local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if results[1] then return unpack(results, 2, table.maxn(results)) end
    return nil
end
CP.safe = safe

local function fmt(s)
    local ok, r = pcall(zo_strformat, "<<1>>", s or "")
    if ok and type(r) == "string" then return r end
    return tostring(s or "")
end
CP.fmt = fmt

local function norm(name)
    -- compare names loosely: lowercase, letters and digits only (handles ' vs ’ and "Master-at-Arms")
    return (fmt(name):lower():gsub("[^%a%d]", ""))
end

-- Builds { [treeKey] = { id = disciplineId, name, skills = {id -> info}, byName = {norm -> id}, order, unspent, savedTotal } }
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
            local tree = { id = discId, name = fmt(safe(GetChampionDisciplineName, discId) or key), skills = {}, byName = {}, order = {} }
            local function add(id)
                if not id or id == 0 or tree.skills[id] then return end
                local jumps = {}
                if safe(DoesChampionSkillHaveJumpPoints, id) then
                    jumps = { safe(GetChampionSkillJumpPoints, id) }
                end
                local info = {
                    id = id,
                    name = fmt(safe(GetChampionSkillName, id) or tostring(id)),
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
            tree.savedTotal = 0
            for _, id in ipairs(tree.order) do tree.savedTotal = tree.savedTotal + tree.skills[id].saved end
            trees[key] = tree
        end
    end
    return trees
end

-- A star entry is a name (starter presets) or { name, id, points } (your own presets)
local function resolve(tree, entry)
    local name, id = entry, nil
    if type(entry) == "table" then name, id = entry.name, entry.id end
    local found = name and tree.byName[norm(name)]
    if not found and id and tree.skills[id] then found = id end
    return found, name or tostring(id)
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

-- Largest allowed value we can afford (current pending + budget), never above cap
local function bestValue(info, budget, cap)
    local best = info.pending
    for _, p in ipairs(allowedValues(info)) do
        if p > best and p - info.pending <= budget and (not cap or p <= cap) then best = p end
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

-- Shortest path of stars from something reachable to the target (BFS over links). With "allowed",
-- only those stars may be used, so a saved preset is rebuilt along its own path.
local function pathTo(tree, targetId, allowed)
    local found, prev, queue, seen = false, {}, {}, {}
    local function ok(id) return not allowed or allowed[id] or isUnlocked(tree.skills[id]) end
    for _, id in ipairs(tree.order) do
        local info = tree.skills[id]
        if (info.root or isUnlocked(info)) and ok(id) then
            queue[#queue + 1] = id
            seen[id] = true
        end
    end
    local head = 1
    while head <= #queue do
        local id = queue[head]
        head = head + 1
        if id == targetId then found = true break end
        for other in pairs(tree.skills[id].links) do
            if not seen[other] and ok(other) then
                seen[other] = true
                prev[other] = id
                queue[#queue + 1] = other
            end
        end
    end
    if not found then
        if allowed then return pathTo(tree, targetId, nil) end
        return nil
    end
    local path, cur = {}, targetId
    while cur do
        table.insert(path, 1, cur)
        cur = prev[cur]
    end
    return path
end

-- Plan one tree. With respec, the tree is planned from zero with every point the character has in it.
-- Returns { main = {ids}, missing, skipped, short, spend = {id -> points}, spent, left, respec }
local function planTree(tree, spec, respec)
    for _, info in pairs(tree.skills) do
        info.base = respec and 0 or info.saved
        info.pending = info.base
    end
    local budget = tree.unspent + (respec and tree.savedTotal or 0)
    local plan = { main = {}, missing = {}, notSlottable = {}, skipped = {}, short = 0, respec = respec and true or false }

    -- resolve every named star first; your own presets also carry the points to restore
    local caps, allowed = {}, nil
    local function resolveList(list)
        local out = {}
        for _, entry in ipairs(list or {}) do
            local id, name = resolve(tree, entry)
            if not id then
                if spec.custom then plan.missing[#plan.missing + 1] = name end
            else
                out[#out + 1] = { id = id, name = name }
                if spec.custom and type(entry) == "table" then
                    caps[id] = entry.points
                    allowed = allowed or {}
                    allowed[id] = true
                end
            end
        end
        return out
    end
    local mains, fills = {}, resolveList(spec.fill)
    for _, entry in ipairs(spec.main or {}) do
        local id, name = resolve(tree, entry)
        mains[#mains + 1] = { id = id, name = name, entry = entry }
        if id and spec.custom and type(entry) == "table" then
            caps[id] = entry.points
            allowed = allowed or {}
            allowed[id] = true
        end
    end

    local function unlockPath(targetId)
        local path = pathTo(tree, targetId, allowed)
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
    for _, m in ipairs(mains) do
        if #plan.main >= 4 then break end
        local info = m.id and tree.skills[m.id]
        if not info then
            plan.missing[#plan.missing + 1] = m.name
        elseif not info.slottable then
            if spec.custom then
                plan.notSlottable[#plan.notSlottable + 1] = info.name
            else
                -- a starter pick the game no longer lets you slot (some Craft stars became
                -- passive): it still gets points, first among the passives
                table.insert(fills, 1, { id = m.id, name = info.name })
            end
        elseif unlockPath(m.id) then
            plan.main[#plan.main + 1] = m.id
        else
            plan.skipped[#plan.skipped + 1] = m.name
        end
    end
    -- 2. max the main stars (or restore their saved points)
    for _, id in ipairs(plan.main) do
        local info = tree.skills[id]
        local v = bestValue(info, budget, caps[id])
        budget = budget - (v - info.pending)
        info.pending = v
    end
    -- 3. the listed stars, then (starter presets only) every other reachable passive star
    local function fill(id)
        local info = tree.skills[id]
        if not info or budget <= 0 or not canTakePoints(tree, info) then return false end
        if info.slottable and not spec.custom then return false end
        local v = bestValue(info, budget, caps[id])
        if v > info.pending then
            budget = budget - (v - info.pending)
            info.pending = v
            return true
        end
        return false
    end
    for _, f in ipairs(fills) do
        if not canTakePoints(tree, tree.skills[f.id]) then unlockPath(f.id) end
        fill(f.id)
    end
    if not spec.custom then
        local progress = true
        while budget > 0 and progress do
            progress = false
            for _, id in ipairs(tree.order) do
                if fill(id) then progress = true end
            end
        end
    end

    -- 4. starter presets: any slot still empty takes another unlocked slottable star, biggest first
    if not spec.custom and #plan.main < 4 then
        local isMain, extra = {}, {}
        for _, id in ipairs(plan.main) do isMain[id] = true end
        for _, id in ipairs(tree.order) do
            local info = tree.skills[id]
            if info.slottable and not isMain[id] and isUnlocked(info) then extra[#extra + 1] = info end
        end
        table.sort(extra, function(a, b) return a.pending > b.pending end)
        for _, info in ipairs(extra) do
            if #plan.main >= 4 then break end
            plan.main[#plan.main + 1] = info.id
        end
    end

    plan.spend = {}
    plan.spent = 0
    for _, id in ipairs(tree.order) do
        local info = tree.skills[id]
        if (respec and info.pending > 0) or (not respec and info.pending ~= info.saved) then
            plan.spend[id] = info.pending
        end
        plan.spent = plan.spent + (info.pending - info.base)
        if caps[id] and info.pending < caps[id] then plan.short = plan.short + (caps[id] - info.pending) end
    end
    plan.left = budget
    return plan
end

-- Turns one tree of a saved preset into a plan spec: slotted stars are the main stars (in slot
-- order), every other star with points is filled, biggest first.
local function customSpec(saved)
    saved = saved or {}
    local pointsOf, isSlotted = {}, {}
    for _, s in ipairs(saved.stars or {}) do pointsOf[s.id or s.name] = s.points end
    local slots = {}
    for _, s in ipairs(saved.slots or {}) do slots[#slots + 1] = s end
    table.sort(slots, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    local main = {}
    for _, s in ipairs(slots) do
        isSlotted[s.id or s.name] = true
        main[#main + 1] = { name = s.name, id = s.id, points = pointsOf[s.id or s.name] or 0 }
    end
    local fill = {}
    for _, s in ipairs(saved.stars or {}) do
        if not isSlotted[s.id or s.name] then fill[#fill + 1] = s end
    end
    table.sort(fill, function(a, b) return (a.points or 0) > (b.points or 0) end)
    return { main = main, fill = fill, custom = true }
end

-- Does applying this saved preset mean taking points out of a star? Then it needs a respec.
function CP.NeedsRespec(preset, trees)
    for _, key in ipairs(TREE_KEYS) do
        local tree, saved = trees[key], preset[key]
        if tree then
            local target = {}
            for _, s in ipairs(saved and saved.stars or {}) do
                local id = resolve(tree, s)
                if id then target[id] = s.points end
            end
            for id, info in pairs(tree.skills) do
                if info.saved > (target[id] or 0) then return true end
            end
        end
    end
    return false
end

-- A respec plan that only adds points needs no respec: send it as a plain purchase instead.
local function dropRespecIfAdditive(plans, trees)
    for key, plan in pairs(plans) do
        for id, info in pairs(trees[key].skills) do
            if info.pending < info.saved then return true end
        end
    end
    for key, plan in pairs(plans) do
        local tree = trees[key]
        plan.respec, plan.spend, plan.spent = false, {}, 0
        for _, id in ipairs(tree.order) do
            local info = tree.skills[id]
            info.base = info.saved
            if info.pending ~= info.saved then plan.spend[id] = info.pending end
            plan.spent = plan.spent + (info.pending - info.saved)
        end
    end
    return false
end

-- Plan a whole preset: returns { warfare = plan, fitness = plan, craft = plan }, trees, respec
-- Your own presets respec only when they must take points out of a star. Starter presets are built
-- from zero with all the character's points (a respec) whenever points are already spent, unless the
-- result only adds points.
function CP.Plan(preset)
    local trees = CP.ReadTrees()
    local respec
    if preset.custom then
        respec = CP.NeedsRespec(preset, trees)
    else
        respec = false
        for _, key in ipairs(TREE_KEYS) do
            if trees[key] and trees[key].savedTotal > 0 then respec = true end
        end
    end
    local plans = {}
    for _, key in ipairs(TREE_KEYS) do
        if trees[key] and preset[key] then
            local spec = preset.custom and customSpec(preset[key]) or preset[key]
            plans[key] = planTree(trees[key], spec, respec)
        end
    end
    if respec and not preset.custom then respec = dropRespecIfAdditive(plans, trees) end
    return plans, trees, respec
end

---------------------------------------------------------------------------
-- Applying: one purchase request, like the game's own Champion screen
---------------------------------------------------------------------------
function CP.RespecCost() return safe(GetChampionRespecCost) or 0 end
function CP.Gold() return safe(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0 end

-- Returns true when sent, or false and a CHAMPION_PURCHASE_* result (or a message)
function CP.Apply(plans, trees, respec)
    local availability = safe(GetChampionPurchaseAvailability)
    if availability and CHAMPION_PURCHASE_SUCCESS and availability ~= CHAMPION_PURCHASE_SUCCESS then
        return false, availability
    end
    if respec and CP.Gold() < CP.RespecCost() then
        return false, "not enough gold for the respec (" .. CP.RespecCost() .. " gold)"
    end
    PrepareChampionPurchaseRequest(respec and true or false)
    for _, key in ipairs(TREE_KEYS) do
        local plan = plans[key]
        if plan then
            for id, points in pairs(plan.spend) do AddSkillToChampionPurchaseRequest(id, points) end
        end
    end
    -- slot the main stars into the bar slots that belong to each tree
    local nextSlot = {}
    for slot = 1, 12 do
        local requiredDisc = safe(GetRequiredChampionDisciplineIdForSlot, slot, HOTBAR_CATEGORY_CHAMPION)
        for _, key in ipairs(TREE_KEYS) do
            local plan = plans[key]
            if plan and trees[key] and trees[key].id == requiredDisc then
                nextSlot[key] = (nextSlot[key] or 0) + 1
                local id = plan.main[nextSlot[key]]
                if id then AddHotbarSlotToChampionPurchaseRequest(slot, id) end
            end
        end
    end
    if type(GetExpectedResultForChampionPurchaseRequest) == "function" then
        local expected = safe(GetExpectedResultForChampionPurchaseRequest)
        if expected and CHAMPION_PURCHASE_SUCCESS and expected ~= CHAMPION_PURCHASE_SUCCESS then
            return false, expected
        end
    end
    SendChampionPurchaseRequest()
    return true
end

---------------------------------------------------------------------------
-- Your own presets: save the character's current points and slotted stars
---------------------------------------------------------------------------
function CP.Capture()
    local trees = CP.ReadTrees()
    local preset = { custom = true, points = 0 }
    for _, key in ipairs(TREE_KEYS) do
        local tree = trees[key]
        local t = { stars = {}, slots = {} }
        if tree then
            for _, id in ipairs(tree.order) do
                local info = tree.skills[id]
                if info.saved > 0 then
                    t.stars[#t.stars + 1] = { name = info.name, id = id, points = info.saved }
                    preset.points = preset.points + info.saved
                end
            end
        end
        preset[key] = t
    end
    for slot = 1, 12 do
        local disc = safe(GetRequiredChampionDisciplineIdForSlot, slot, HOTBAR_CATEGORY_CHAMPION)
        local id = safe(GetSlotBoundId, slot, HOTBAR_CATEGORY_CHAMPION)
        if id and id ~= 0 then
            for _, key in ipairs(TREE_KEYS) do
                local tree = trees[key]
                if tree and tree.id == disc and tree.skills[id] then
                    local slots = preset[key].slots
                    slots[#slots + 1] = { slot = slot, id = id, name = tree.skills[id].name }
                end
            end
        end
    end
    return preset, trees
end

---------------------------------------------------------------------------
-- Summaries for the screen
---------------------------------------------------------------------------
-- { key, name, unspent, spent, left, respec, slots = { {name, points} }, passivePoints, passiveStars, missing, skipped, short }
function CP.Summary(plans, trees)
    local out = {}
    for _, key in ipairs(TREE_KEYS) do
        local plan, tree = plans[key], trees[key]
        local s = { key = key, name = tree and tree.name or key, unspent = tree and tree.unspent or 0,
                    spent = 0, left = 0, slots = {}, passivePoints = 0, passiveStars = 0, missing = {}, skipped = {}, short = 0 }
        if plan and tree then
            s.spent, s.left, s.missing, s.skipped, s.short, s.respec = plan.spent, plan.left, plan.missing, plan.skipped, plan.short, plan.respec
            s.notSlottable = plan.notSlottable
            local isMain = {}
            for _, id in ipairs(plan.main) do
                local info = tree.skills[id]
                isMain[id] = true
                s.slots[#s.slots + 1] = { name = info.name, points = info.pending }
            end
            for _, id in ipairs(tree.order) do
                local info = tree.skills[id]
                if not isMain[id] and info.pending > info.base then
                    s.passivePoints = s.passivePoints + (info.pending - info.base)
                    s.passiveStars = s.passiveStars + 1
                end
            end
        end
        out[#out + 1] = s
    end
    return out
end

-- What a saved preset holds, in the same shape (for the "save" row and for the preset's own record)
function CP.CaptureSummary(preset, trees)
    local out = {}
    for _, key in ipairs(TREE_KEYS) do
        local t, tree = preset[key] or {}, trees and trees[key]
        local s = { key = key, name = tree and tree.name or key, total = 0, slots = {}, otherPoints = 0, otherStars = 0 }
        local pointsOf, slotted = {}, {}
        for _, star in ipairs(t.stars or {}) do
            pointsOf[star.id or star.name] = star.points
            s.total = s.total + (star.points or 0)
        end
        for _, slot in ipairs(t.slots or {}) do
            slotted[slot.id or slot.name] = true
            s.slots[#s.slots + 1] = { name = slot.name, points = pointsOf[slot.id or slot.name] or 0 }
        end
        for _, star in ipairs(t.stars or {}) do
            if not slotted[star.id or star.name] then
                s.otherPoints = s.otherPoints + (star.points or 0)
                s.otherStars = s.otherStars + 1
            end
        end
        out[#out + 1] = s
    end
    return out
end
