-- Skillbound_Check.lua : build check.
-- Looks at a build (or the one you wear) and lists what isn't right: a set bonus that
-- isn't complete (4 of 5), two mythics, missing pieces, skills this character can't use,
-- poisons running low, gear that needs repair, food that ran out, the wrong mundus.
-- Each line: { level = "bad" | "warn" | "ok", text }.

local B = Skillbound
local L = B.L
local Items, Capture = B.Items, B.Capture
local Check = {}
B.Check = Check

local POISON_LOW = 20
local REPAIR_BELOW = 15        -- percent
local FOOD_SOON = 5 * 60       -- seconds

local function Add(list, level, text)
    list[#list + 1] = { level = level, text = text }
end

-- pieces per set on the front bar (body + jewelry + front weapons; a two-hander counts 2)
function Check.SetCounts(gear)
    local sets = {}
    for _, s in ipairs(Items.SLOTS) do
        local p = gear[s]
        if p and p.set and not Items.POISON[s] and not Items.BACK[s] then
            local t = sets[p.set] or { n = 0, max = p.max or 5, link = p.link }
            t.n = t.n + ((p.et == EQUIP_TYPE_TWO_HAND) and 2 or 1)
            sets[p.set] = t
        end
    end
    return sets
end

function Check.SetName(link)
    local _, name = GetItemLinkSetInfo(link, false)
    return B.Name(name)
end

-- lines for a build; worn = it's the build you wear now (then live things are checked too)
function Check.Run(build, worn)
    local list = {}
    if not build then return list end
    local parts = build.parts or {}

    if parts.gear and build.gear then
        local sets = Check.SetCounts(build.gear)
        for _, t in pairs(sets) do
            if t.n < t.max and not build.parent then
                Add(list, "warn", L("CHECK_SET", Check.SetName(t.link), t.n, t.max))
            end
        end
        local mythics = 0
        for s, p in pairs(build.gear) do
            if not Items.POISON[s] and Items.IsMythic(p) then mythics = mythics + 1 end
        end
        if mythics > 1 then Add(list, "bad", L("CHECK_MYTHICS", mythics)) end
        for s, p in pairs(build.gear) do
            if Items.POISON[s] then
                local _, _, total = Items.FindPoison(p)
                if total < POISON_LOW then
                    Add(list, total == 0 and "bad" or "warn", L("CHECK_POISON", B.Name(GetItemLinkName(p.link)), total))
                end
            end
        end
    end

    local plan = B.Apply.Plan(build)
    for _, ch in ipairs(plan.changes) do
        if ch.status == "missing" or ch.status == "other" or ch.status == "bank" or ch.status == "bad" then
            Add(list, ch.status == "bank" and "warn" or "bad", ch.text)
        end
    end

    if worn then
        for _, s in ipairs(Items.SLOTS) do
            if not Items.POISON[s] and DoesItemHaveDurability(BAG_WORN, s) then
                local cond = GetItemCondition(BAG_WORN, s)
                if cond < REPAIR_BELOW then
                    Add(list, cond == 0 and "bad" or "warn", L("CHECK_REPAIR", Items.SlotName(s), cond))
                end
            end
        end
        if parts.food and build.food then
            local left = B.Apply.FoodLeft(build.food.id)
            if not left then
                Add(list, "warn", L("CHECK_FOOD_OUT", B.Apply.FoodName(build.food)))
            elseif left < FOOD_SOON then
                Add(list, "warn", L("CHECK_FOOD_SOON", B.Apply.FoodName(build.food), math.ceil(left / 60)))
            end
        end
        if build.mundus and #build.mundus > 0 then
            local now = {}
            for _, id in ipairs(Capture.Mundus()) do now[id] = true end
            for _, id in ipairs(build.mundus) do
                if not now[id] then
                    Add(list, "warn", L("CHECK_MUNDUS", B.Name(GetAbilityName(id))))
                end
            end
        end
    end
    return list
end

-- the build you wear (and its layer), checked; cached for a few seconds
local cache, cacheAt = nil, 0

function Check.Current(force)
    local now = GetFrameTimeSeconds()
    if cache and not force and now - cacheAt < 5 then return cache end
    -- right after login the skills aren't loaded yet: no false "skill missing" warnings
    if SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.IsDataReady and not SKILLS_DATA_MANAGER:IsDataReady() then
        return {}
    end
    local build = B.WornBuild()
    cache = build and Check.Run(build, true) or {}
    local layer = B.Get(B.Char().layer)
    if layer then
        for _, line in ipairs(Check.Run(layer, false)) do cache[#cache + 1] = line end
    end
    cacheAt = now
    return cache
end

-- "bad", "warn" or nil: the worst line of the current build (red / orange dot on the button)
function Check.Level()
    local worst
    for _, line in ipairs(Check.Current()) do
        if line.level == "bad" then return "bad" end
        if line.level == "warn" then worst = "warn" end
    end
    return worst
end

function Check.PrintCurrent()
    local build = B.WornBuild()
    if not build then
        B.Print(L("CHECK_NONE"))
        return
    end
    local lines = Check.Current(true)
    if #lines == 0 then
        B.Print(L("CHECK_ALL_GOOD", build.name))
        return
    end
    B.Print(L("CHECK_HEADER", build.name))
    for _, line in ipairs(lines) do
        B.Print("  " .. B.Dot(line.level == "bad" and B.COLOR.bad or B.COLOR.warn) .. " " .. line.text)
    end
end

function Check.Init()
    local function Dirty() cacheAt = 0 end
    B.callbacks:RegisterCallback("Worn", Dirty)
    B.callbacks:RegisterCallback("InventoryChanged", Dirty)
    B.callbacks:RegisterCallback("BuildsChanged", Dirty)
end
