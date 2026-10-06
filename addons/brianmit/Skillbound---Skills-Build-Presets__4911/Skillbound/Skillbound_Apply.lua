-- Skillbound_Apply.lua : wearing a build.
-- Plan(build) works out what will change (shown in the window before you wear it):
-- every piece with where it is ("in your bag", "in the bank", "on Anna", "a copy in
-- another trait"), the skills, champion stars, food... Run(plan) does it step by step
-- through a queue that waits while you're in combat, dead or blocking, and checks
-- that each step really happened (with a retry). Before it starts, what you wear now
-- is saved as "Before <build>", so Undo brings it back.

local B = Skillbound
local L = B.L
local Items, Capture = B.Items, B.Capture
local Apply = {}
B.Apply = Apply

local ACTOR = GAMEPLAY_ACTOR_CATEGORY_PLAYER
local CP_COOLDOWN = 31          -- seconds between champion bar changes (the game's limit)
local TICK_MS = 100

local running                   -- the plan being worn: { build, steps, i, problems, opts }
local cpReadyAt = 0
local cpResult                  -- result of the last champion purchase (nil = still waiting)
local skipCpAnimation = false

local function Now() return GetFrameTimeMilliseconds() end

-- ---------------------------------------------------------------------------
-- Skills

local function SkillByName(name)
    if not name or name == "" then return nil end
    local want = zo_strlower(name)
    for _, typeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, lineData in typeData:SkillLineIterator() do
            for _, skillData in lineData:SkillIterator() do
                local ok, found, prog = pcall(function()
                    if skillData:IsPassive() then return nil end
                    for _, m in ipairs({ MORPH_SLOT_BASE, MORPH_SLOT_MORPH_1, MORPH_SLOT_MORPH_2 }) do
                        local p = skillData:GetProgressionData(m)
                        if p and zo_strlower(B.Name(p:GetName())) == want then return skillData, p end
                    end
                    if skillData.GetName and zo_strlower(B.Name(skillData:GetName())) == want then return skillData end
                end)
                if ok and found then return found, prog end
            end
        end
    end
end

-- skillData, progressionData, problem ("missing", "notLearned", "otherMorph" or nil)
function Apply.FindSkill(entry)
    if not SKILLS_DATA_MANAGER then return nil, nil, "missing" end
    local p = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(entry.id)
    local skillData = p and p:GetSkillData()
    if not skillData and entry.crafted and GetCraftedAbilityRepresentativeAbilityId then
        local ok, rep = pcall(GetCraftedAbilityRepresentativeAbilityId, entry.crafted)
        p = ok and rep and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(rep) or nil
        skillData = p and p:GetSkillData()
    end
    if not skillData then skillData, p = SkillByName(entry.name) end
    if not skillData then return nil, nil, "missing" end
    if not skillData:IsPurchased() then return skillData, p, "notLearned" end
    if p and skillData.GetPointAllocatorProgressionData then
        local cur = skillData:GetPointAllocatorProgressionData()
        if cur and cur.GetAbilityId and p.GetAbilityId and cur:GetAbilityId() ~= p:GetAbilityId() then
            return skillData, p, "otherMorph"
        end
    end
    return skillData, p
end

local function SkillSlotted(hotbar, slot, skillData, entry)
    local data = hotbar:GetSlotData(slot)
    if data and data.EqualsSkillData and skillData then
        local ok, same = pcall(data.EqualsSkillData, data, skillData)
        if ok then return same end
    end
    local cat = hotbar.hotbarCategory or hotbar:GetHotbarCategory()
    local id = GetSlotBoundId(slot, cat)
    return id == entry.id or (entry.crafted and id == entry.crafted)
end

function Apply.SkillProblemText(entry, problem)
    if problem == "missing" then
        if entry.line then return L("SKILL_NO_LINE", entry.name, entry.line) end
        return L("SKILL_MISSING", entry.name)
    elseif problem == "notLearned" then
        return L("SKILL_NOT_LEARNED", entry.name)
    elseif problem == "otherMorph" then
        return L("SKILL_OTHER_MORPH", entry.name)
    end
end

-- ---------------------------------------------------------------------------
-- Champion

local CP_ERRORS = {
    [CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN or -1] = "CP_ERR_COOLDOWN",
    [CHAMPION_PURCHASE_IN_COMBAT or -2] = "CP_ERR_COMBAT",
    [CHAMPION_PURCHASE_CP_DISABLED or -3] = "CP_ERR_DISABLED",
    [CHAMPION_PURCHASE_IN_NOCP_CAMPAIGN or -4] = "CP_ERR_DISABLED",
    [CHAMPION_PURCHASE_IN_NOCP_BATTLEGROUND or -5] = "CP_ERR_DISABLED",
    [CHAMPION_PURCHASE_CHAMPION_NOT_UNLOCKED or -6] = "CP_ERR_LOCKED",
}

local function CPError(code)
    local key = CP_ERRORS[code]
    if key then return L(key) end
    return L("CP_ERR_CODE", tostring(code))
end

function Apply.CPUnlocked()
    return GetPlayerChampionPointsEarned and GetPlayerChampionPointsEarned() > 0
end

-- the stars of the build that aren't slotted now (only slots the build holds)
local function CPChanges(slots)
    local list = {}
    for i = 1, 12 do
        local id = slots[i]
        if id and GetSlotBoundId(i, HOTBAR_CATEGORY_CHAMPION) ~= id then list[#list + 1] = i end
    end
    return list
end

function Apply.CPCooldownLeft()
    return math.max(0, cpReadyAt - GetFrameTimeSeconds())
end


-- ---------------------------------------------------------------------------
-- Food

local function HasBuff(abilityId)
    for i = 1, GetNumBuffs("player") do
        if select(11, GetUnitBuffInfo("player", i)) == abilityId then return true end
    end
    return false
end

-- every buff id learned for a food (the first one + all seen with it, see Capture)
local function FoodIds(itemId)
    local ids = {}
    if B.sv.foodBuffs[itemId] then ids[B.sv.foodBuffs[itemId]] = true end
    for id in pairs((B.sv.foodBuffSet or {})[itemId] or {}) do ids[id] = true end
    return ids
end

-- seconds left on the food buff of this food (nil = not running). 1.0.0: any of its learned
-- buff ids counts; and when you (or Skillbound) ate it, its known duration counts too, so a
-- running buff is never eaten over again (switching builds re-ate it before)
function Apply.FoodLeft(itemId)
    local ids = FoodIds(itemId)
    local now = GetFrameTimeSeconds()
    local best
    for i = 1, GetNumBuffs("player") do
        local _, _, timeEnding, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        if ids[id] then
            local left = math.max(0, timeEnding - now)
            if not best or left > best then best = left end
        end
    end
    if best then return best end
    local t = B.Char().foodTimes and B.Char().foodTimes[itemId]
    if t and t.at and t.dur then
        local left = t.at + t.dur - GetTimeStamp()
        if left > 0 then return left end
    end
    if next(ids) then return nil end
    -- buff not learned yet: any long buff (20 min to 3 hours) that isn't a mundus counts as food
    -- (1.0.0: was 50 min to ~2 h; a 2 h food could be missed, and after /reloadui the game can
    -- report a buff's start as the reload, so its "length" looks shorter)
    for i = 1, GetNumBuffs("player") do
        local _, timeStarted, timeEnding, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        local length = timeEnding - timeStarted
        if length >= 1200 and length <= 10800 and timeEnding - now > 0 and not Capture.MUNDUS[id] then
            return math.max(0, timeEnding - now)
        end
    end
    return nil
end

local function FindInBag(bag, itemId)
    for slot in ZO_IterateBagSlots(bag) do
        if GetItemId(bag, slot) == itemId then return bag, slot end
    end
end

-- another food's buff is running (one Skillbound has learned, not this food's): food you picked
-- yourself, or a teammate's trial food. Skillbound never eats over it (0.6.7).
function Apply.OtherFoodRunning(itemId)
    local mine = FoodIds(itemId)
    local known = {}
    for _, abilityId in pairs(B.sv.foodBuffs) do known[abilityId] = true end
    for _, set in pairs(B.sv.foodBuffSet or {}) do
        for abilityId in pairs(set) do known[abilityId] = true end
    end
    for i = 1, GetNumBuffs("player") do
        local id = select(11, GetUnitBuffInfo("player", i))
        if known[id] and not mine[id] then return true end
    end
    return false
end

-- Skillbound eats something itself: your buffs before, the item, and 1.5 s later every long buff
-- that's new (or renewed) belongs to that food (learned for good, so its running buff is known)
function Apply.EatFood(bag, slot, itemId, link)
    local before = {}
    for i = 1, GetNumBuffs("player") do
        local _, _, timeEnding, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
        before[id] = timeEnding
    end
    CallSecureProtected("UseItem", bag, slot)
    B.Later(function()
        for i = 1, GetNumBuffs("player") do
            local _, timeStarted, timeEnding, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
            local length = (timeEnding or 0) - (timeStarted or 0)
            if length >= 20 * 60 and not Capture.MUNDUS[id] and (before[id] == nil or timeEnding > before[id] + 60) then
                Capture.LearnFoodBuff(itemId, link, id, length)
            end
        end
    end, 1500, "food learning")
end

-- how many of this item are in the backpack
function Apply.BagCount(itemId)
    local n = 0
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        if GetItemId(BAG_BACKPACK, slot) == itemId then n = n + GetSlotStackSize(BAG_BACKPACK, slot) end
    end
    return n
end

function Apply.FoodName(food)
    if food.link and food.link ~= "" then return B.Name(GetItemLinkName(food.link)) end
    local bag, slot = FindInBag(BAG_BACKPACK, food.id)
    if bag then return B.Name(GetItemName(bag, slot)) end
    return L("FOOD_UNKNOWN")
end

-- ---------------------------------------------------------------------------
-- Plan: what will change

local function Change(plan, part, status, text, icon)
    plan.changes[#plan.changes + 1] = { part = part, status = status, text = text, icon = icon }
    if status == "missing" or status == "other" or status == "bank" or status == "bad" then
        plan.problems = plan.problems + 1
    end
end

local function PieceName(link)
    if not link or link == "" then return "?" end
    return B.Name(GetItemLinkName(link))
end

local function Colored(link)
    local q = GetItemLinkDisplayQuality(link)
    local c = GetItemQualityColor(q)
    return c:Colorize(PieceName(link))
end

local function WornMythicSlot(exceptSlot)
    for _, s in ipairs(Items.SLOTS) do
        if s ~= exceptSlot and not Items.POISON[s] then
            local link = GetItemLink(BAG_WORN, s)
            if link ~= "" and GetItemLinkDisplayQuality(link) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE then return s end
        end
    end
end

local function PlanGear(build, plan)
    local gear = build.gear or {}
    local idx = Items.Index()
    local found, used = {}, {}
    -- exact pieces first, so a copy never takes a piece another slot really wants
    for _, s in ipairs(Items.SLOTS) do
        local p = gear[s]
        if p and not Items.POISON[s] and p.uid and idx.byUid[p.uid] then
            found[s] = { e = idx.byUid[p.uid], exact = true, kind = Items.Kind(idx.byUid[p.uid].bag) }
            used[p.uid] = true
        end
    end
    for _, s in ipairs(Items.SLOTS) do
        local p = gear[s]
        if p and not Items.POISON[s] and not found[s] then
            local f = Items.Find(p, used)
            if f and f.e and f.e.uid then used[f.e.uid] = true end
            found[s] = f or false
        end
    end

    local weaponsChange = false
    for _, s in ipairs(Items.SLOTS) do
        local p = gear[s]
        if p and Items.POISON[s] then
            local link = GetItemLink(BAG_WORN, s)
            if link == "" or GetItemLinkItemId(link) ~= p.id then
                local bag = Items.FindPoison(p)
                if bag then
                    Change(plan, "gear", "ok", L("CHANGE_PUT_ON", Items.SlotName(s), Colored(p.link)), GetItemLinkIcon(p.link))
                    plan.gearSteps[#plan.gearSteps + 1] = { slot = s, poison = p }
                else
                    Change(plan, "gear", "missing", L("CHANGE_NO_POISON", Colored(p.link)), GetItemLinkIcon(p.link))
                end
            end
        elseif p then
            local f = found[s]
            local here = f and f.e and f.e.bag == BAG_WORN and f.e.slot == s
            if not here then
                local icon = GetItemLinkIcon(p.link)
                if not f then
                    Change(plan, "gear", "missing", L("CHANGE_MISSING", Items.SlotName(s), Colored(p.link)), icon)
                elseif f.other then
                    Change(plan, "gear", "other", L(f.copy and "CHANGE_OTHER_COPY" or "CHANGE_OTHER_CHAR",
                        Items.SlotName(s), Colored(p.link), f.other), icon)
                elseif f.kind == "bank" and not IsBankOpen() then
                    Change(plan, "gear", "bank", L("CHANGE_IN_BANK", Items.SlotName(s), Colored(p.link)), icon)
                else
                    local text = L("CHANGE_PUT_ON", Items.SlotName(s), Colored(f.e.link))
                    local status = "ok"
                    if not f.exact then
                        status = "sub"
                        text = text .. " " .. L(f.otherTrait and "CHANGE_COPY_TRAIT" or "CHANGE_COPY")
                    end
                    Change(plan, "gear", status, text, icon)
                    plan.gearSteps[#plan.gearSteps + 1] = { slot = s, uid = f.e.uid, piece = p,
                        mythic = Items.IsMythic(Items.EntryInfo(f.e)) }
                    if Items.WEAPON[s] then weaponsChange = true end
                end
            end
        end
    end
    plan.weaponsChange = weaponsChange
end

local function PlanSkills(build, plan)
    for _, cat in ipairs(Capture.BARS) do
        local bar = build.skills and build.skills[cat]
        if bar then
            local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(cat)
            for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
                local entry = bar[slot]
                if entry then
                    local skillData, _, problem = Apply.FindSkill(entry)
                    local icon = GetAbilityIcon(entry.id)
                    if problem == "missing" or problem == "notLearned" then
                        Change(plan, "skills", "bad", Apply.SkillProblemText(entry, problem), icon)
                    elseif not SkillSlotted(hotbar, slot, skillData, entry) then
                        local text = L(cat == HOTBAR_CATEGORY_BACKUP and "CHANGE_SKILL_BACK" or "CHANGE_SKILL_FRONT",
                            entry.name, slot == Capture.ULT_SLOT and L("SLOT_ULT") or tostring(slot - 2))
                        if problem == "otherMorph" then text = text .. " " .. L("CHANGE_OTHER_MORPH") end
                        Change(plan, "skills", problem and "sub" or "ok", text, icon)
                        plan.skillSteps[#plan.skillSteps + 1] = { cat = cat, slot = slot, entry = entry }
                    end
                end
            end
        end
    end
end

local function PlanCP(build, plan)
    local cp = build.cp
    if not cp then return end
    if not Apply.CPUnlocked() then
        Change(plan, "cp", "bad", L("CP_ERR_LOCKED"))
        return
    end
    local changes = CPChanges(cp.slots or {})
    for _, i in ipairs(changes) do
        local id = cp.slots[i]
        local name = B.Name(GetChampionSkillName(id))
        if (GetNumPointsSpentOnChampionSkill(id) or 0) > 0 then
            Change(plan, "cp", "ok", L("CHANGE_STAR", name))
        else
            Change(plan, "cp", "bad", L("CHANGE_STAR_NO_POINTS", name))
        end
    end
    if #changes > 0 then plan.cpStep = { slots = cp.slots } end
end

local function PlanFood(build, plan)
    local food = build.food
    if not food or not B.sv.eatFood then return end
    if Apply.FoodLeft(food.id) then return end
    if Apply.OtherFoodRunning(food.id) then return end   -- (never over another food's buff)
    local name = Apply.FoodName(food)
    if FindInBag(BAG_BACKPACK, food.id) then
        Change(plan, "food", "ok", L("CHANGE_EAT", name))
        plan.foodStep = food
    else
        Change(plan, "food", "bad", L("CHANGE_NO_FOOD", name))
    end
end

local function QuickSlotted(i, q)
    local cat = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    if q.kind == "item" then
        local link = GetSlotItemLink and GetSlotItemLink(i, cat) or ""
        return link ~= "" and GetItemLinkItemId(link) == q.id
    end
    return GetSlotBoundId(i, cat) == q.id
end

local function PlanQuick(build, plan)
    if not build.quick or not HOTBAR_CATEGORY_QUICKSLOT_WHEEL then return end
    local n = 0
    for i, q in pairs(build.quick) do
        -- (mementos / collectibles can't be put on the wheel by addons: left alone, see QuickStep)
        if q.kind == "item" and not QuickSlotted(i, q) then
            if q.kind == "item" and not FindInBag(BAG_BACKPACK, q.id) then
                Change(plan, "quick", "bad", L("CHANGE_QUICK_MISSING", PieceName(q.link)))
            else
                n = n + 1
                plan.quickSteps[#plan.quickSteps + 1] = { i = i, q = q }
            end
        end
    end
    if n > 0 then Change(plan, "quick", "ok", L("CHANGE_QUICK", n)) end
end

local function TitleIndex(name)
    if not GetNumTitles then return nil end
    for i = 1, GetNumTitles() do
        if GetTitle(i) == name then return i end
    end
end

local function PlanLooks(build, plan)
    local o = build.outfit
    if o and GetEquippedOutfitIndex and (GetEquippedOutfitIndex(ACTOR) or 0) ~= (o.index or 0) then
        Change(plan, "outfit", "ok", L("CHANGE_OUTFIT", o.name or L("OUTFIT_NONE")))
        plan.outfitStep = o
    end
    local t = build.title
    if t and t.name and t.name ~= "" and GetCurrentTitleIndex then
        local index = TitleIndex(t.name)
        if not index then
            Change(plan, "title", "bad", L("CHANGE_NO_TITLE", t.name))
        elseif GetCurrentTitleIndex() ~= index then
            Change(plan, "title", "ok", L("CHANGE_TITLE", t.name))
            plan.titleStep = index
        end
    end
    if build.collect and GetActiveCollectibleByType then
        for _, c in ipairs(Capture.COLLECT) do
            local id = c.type and build.collect[c.type]
            if id then
                local ok, active = pcall(GetActiveCollectibleByType, c.type, ACTOR)
                if ok and active ~= id then
                    if IsCollectibleUnlocked(id) then
                        Change(plan, "collect", "ok", L("CHANGE_COLLECT", L(c.key), B.Name(GetCollectibleName(id))))
                        plan.collectSteps[#plan.collectSteps + 1] = id
                    else
                        Change(plan, "collect", "bad", L("CHANGE_NO_COLLECT", B.Name(GetCollectibleName(id))))
                    end
                end
            end
        end
    end
end

local function PlanCompanion(build, plan)
    local c = build.companion
    if not c then return end
    if not (HasActiveCompanion and HasActiveCompanion()) then
        Change(plan, "companion", "bad", L("CHANGE_NO_COMPANION"))
        return
    end
    local idx = Items.Index()
    for s, p in pairs(c.gear or {}) do
        local worn = Items.Uid(BAG_COMPANION_WORN, s)
        if p.uid ~= worn then
            local e = p.uid and idx.byUid[p.uid]
            if e and e.bag == BAG_BACKPACK then
                Change(plan, "companion", "ok", L("CHANGE_COMPANION_GEAR", Colored(p.link)), GetItemLinkIcon(p.link))
                plan.companionSteps[#plan.companionSteps + 1] = { uid = p.uid, slot = s }
            else
                Change(plan, "companion", "missing", L("CHANGE_COMPANION_MISSING", Colored(p.link)), GetItemLinkIcon(p.link))
            end
        end
    end
    for slot, e in pairs(c.skills or {}) do
        if GetSlotBoundId(slot, HOTBAR_CATEGORY_COMPANION) ~= e.id then
            Change(plan, "companion", "ok", L("CHANGE_COMPANION_SKILL", e.name), GetAbilityIcon(e.id))
            plan.companionSteps[#plan.companionSteps + 1] = { skill = e, slot = slot }
        end
    end
end

-- Everything that wearing this build would change, without changing anything.
function Apply.Plan(build)
    local plan = {
        build = build, changes = {}, problems = 0,
        gearSteps = {}, skillSteps = {}, quickSteps = {}, collectSteps = {}, companionSteps = {},
    }
    local parts = build.parts or {}
    local readers = {
        { "gear", PlanGear }, { "skills", PlanSkills }, { "cp", PlanCP }, { "food", PlanFood },
        { "quick", PlanQuick }, { "companion", PlanCompanion },
    }
    for _, r in ipairs(readers) do
        if parts[r[1]] then
            local ok, err = pcall(r[2], build, plan)
            if not ok then Change(plan, r[1], "bad", L("PLAN_FAILED", tostring(err))) end
        end
    end
    if parts.outfit or parts.title or parts.collect then
        local looks = {
            outfit = parts.outfit and build.outfit or nil,
            title = parts.title and build.title or nil,
            collect = parts.collect and build.collect or nil,
        }
        local ok, err = pcall(PlanLooks, looks, plan)
        if not ok then Change(plan, "outfit", "bad", L("PLAN_FAILED", tostring(err))) end
    end
    return plan
end

-- ---------------------------------------------------------------------------
-- Steps. step.run(step) returns:
--   "done"          next step
--   "check"         wait until step.check() is true (step.timeout ms, then one retry)
--   "wait", why     run again a bit later (step.waitMs), up to step.maxTries times
--   "fail", why     note the problem, go on with the next step

local function Step(label, run, extra)
    local s = { label = label, run = run, delay = 250 }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

local function SheatheStep()
    return Step(L("STEP_SHEATHE"), function(step)
        if ArePlayerWeaponsSheathed() then return "done" end
        if not step.toggled then
            step.toggled = true
            TogglePlayerWield()
        end
        step.check = ArePlayerWeaponsSheathed
        step.timeout = 2500
        return "check"
    end, { delay = 150 })
end

local function UnequipMythicStep(slot)
    return Step(L("STEP_MYTHIC"), function(step)
        if GetItemLink(BAG_WORN, slot) == "" then return "done" end
        local free = FindFirstEmptySlotInBag(BAG_BACKPACK)
        if not free then return "fail", L("BAG_FULL") end
        CallSecureProtected("RequestMoveItem", BAG_WORN, slot, BAG_BACKPACK, free, 1)
        step.check = function() return GetItemLink(BAG_WORN, slot) == "" end
        return "check"
    end, { delay = 300 })
end

local function GearStep(g)
    if g.poison then
        return Step(Items.SlotName(g.slot), function(step)
            local bag, slot = Items.FindPoison(g.poison)
            if not bag then return "fail", L("CHANGE_NO_POISON", PieceName(g.poison.link)) end
            EquipItem(bag, slot, g.slot)
            step.check = function()
                local link = GetItemLink(BAG_WORN, g.slot)
                return link ~= "" and GetItemLinkItemId(link) == g.poison.id
            end
            return "check"
        end, { slot = g.slot })
    end
    return Step(Items.SlotName(g.slot), function(step)
        Items.MarkDirty()
        local e = Items.Index().byUid[g.uid]
        if not e then return "fail", L("ITEM_GONE", Items.SlotName(g.slot)) end
        if e.bag == BAG_WORN and e.slot == g.slot then return "done" end
        if e.bag == BAG_BANK or e.bag == BAG_SUBSCRIBER_BANK then
            if not IsBankOpen() then return "fail", L("CHANGE_IN_BANK", Items.SlotName(g.slot), PieceName(e.link)) end
            local free = FindFirstEmptySlotInBag(BAG_BACKPACK)
            if not free then return "fail", L("BAG_FULL") end
            CallSecureProtected("RequestMoveItem", e.bag, e.slot, BAG_BACKPACK, free, 1)
            step.waitMs = 400
            return "wait"
        end
        EquipItem(e.bag, e.slot, g.slot)
        step.check = function() return Items.Uid(BAG_WORN, g.slot) == g.uid end
        return "check"
    end, { delay = 200, maxTries = 6, slot = g.slot })
end

local function SkillStep(sk)
    return Step(sk.entry.name, function()
        local skillData, _, problem = Apply.FindSkill(sk.entry)
        if not skillData or problem == "missing" or problem == "notLearned" then
            return "fail", Apply.SkillProblemText(sk.entry, problem or "missing")
        end
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(sk.cat)
        if SkillSlotted(hotbar, sk.slot, skillData, sk.entry) then return "done" end
        local result = hotbar:GetExpectedSkillSlotResult(sk.slot, skillData)
        if result ~= HOT_BAR_RESULT_SUCCESS then
            local why = GetString("SI_HOTBARRESULT", result)
            return "fail", L("SKILL_CANT_SLOT", sk.entry.name, why ~= "" and why or tostring(result))
        end
        hotbar:AssignSkillToSlot(sk.slot, skillData)
        return "done"
    end, { delay = 80, cat = sk.cat, skillSlot = sk.slot })
end

local function CPStep(cpStep, plan)
    return Step(L("PART_CP"), function(step)
        if #CPChanges(cpStep.slots) == 0 then return "done" end
        if Apply.CPCooldownLeft() > 0 then
            step.waitMs, step.maxTries = 1000, 40
            running.cpWait = true
            return "wait"
        end
        running.cpWait = false
        PrepareChampionPurchaseRequest(false)
        local any = false
        for _, i in ipairs(CPChanges(cpStep.slots)) do
            local id = cpStep.slots[i]
            if (GetNumPointsSpentOnChampionSkill(id) or 0) > 0 then
                AddHotbarSlotToChampionPurchaseRequest(i, id)
                any = true
            end
        end
        if not any then return "done" end
        if GetExpectedResultForChampionPurchaseRequest then
            local expected = GetExpectedResultForChampionPurchaseRequest()
            if expected == CHAMPION_PURCHASE_CHAMPION_BAR_ON_COOLDOWN then
                step.waitMs, step.maxTries = 2000, 40
                return "wait"
            elseif expected ~= CHAMPION_PURCHASE_SUCCESS then
                return "fail", CPError(expected)
            end
        end
        skipCpAnimation = not (CHAMPION_PERKS_SCENE and CHAMPION_PERKS_SCENE:IsShowing())
        cpResult = nil
        SendChampionPurchaseRequest()
        step.check = function() return cpResult ~= nil end
        step.after = function()
            if cpResult == CHAMPION_PURCHASE_SUCCESS then return true end
            return false, CPError(cpResult)
        end
        step.timeout = 5000
        return "check"
    end, { maxTries = 40 })
end

local function FoodStep(food)
    return Step(L("PART_FOOD"), function()
        if Apply.FoodLeft(food.id) then return "done" end
        local bag, slot = FindInBag(BAG_BACKPACK, food.id)
        if not bag then return "fail", L("CHANGE_NO_FOOD", Apply.FoodName(food)) end
        if Apply.OtherFoodRunning(food.id) then return "done" end   -- (checked again right before eating)
        Apply.EatFood(bag, slot, food.id, food.link or GetItemLink(bag, slot))
        return "done"
    end, { delay = 500 })
end

-- Quickslot wheel (1.0.0 fix): only ITEMS (potions, food...) can be put back, through the
-- protected call. SelectSlotSimpleAction (mementos, collectibles) is a PRIVATE game function:
-- even reading its name from an addon throws "Attempt to access a private function" (that's
-- what printed a stack trace in chat). Those entries are skipped, never touched.
local quickLocked = false   -- the game refused the protected call once: don't try again this session

local function QuickStep(qs)
    local cat = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
    return Step(L("PART_QUICK"), function(step)
        if QuickSlotted(qs.i, qs.q) then return "done" end
        if qs.q.kind ~= "item" or quickLocked then return "done" end
        local bag, slot = FindInBag(BAG_BACKPACK, qs.q.id)
        if not bag then return "fail", L("CHANGE_QUICK_MISSING", PieceName(qs.q.link)) end
        local ok, allowed = pcall(CallSecureProtected, "SelectSlotItem", bag, slot, qs.i, cat)
        if not ok or allowed == false then
            quickLocked = true
            return "fail", L("QUICK_LOCKED")
        end
        step.check = function() return QuickSlotted(qs.i, qs.q) end
        step.timeout = 1500
        return "check"
    end, { delay = 120 })
end

local function OutfitStep(o)
    return Step(L("PART_OUTFIT"), function()
        if (o.index or 0) == 0 then
            UnequipOutfit(ACTOR)
        else
            EquipOutfit(ACTOR, o.index)
        end
        return "done"
    end, { delay = 400 })
end

local function TitleStep(index)
    return Step(L("PART_TITLE"), function()
        SelectTitle(index)
        return "done"
    end)
end

local function CollectStep(id)
    return Step(B.Name(GetCollectibleName(id)), function()
        UseCollectible(id, ACTOR)
        return "done"
    end, { delay = 1200 })
end

local function CompanionStep(cs)
    if cs.skill then
        return Step(cs.skill.name, function()
            local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(HOTBAR_CATEGORY_COMPANION)
            if not hotbar then return "fail", L("CHANGE_NO_COMPANION") end
            hotbar:AssignSkillToSlotByAbilityId(cs.slot, cs.skill.id)
            return "done"
        end, { delay = 80 })
    end
    return Step(L("PART_COMPANION"), function(step)
        if not HasActiveCompanion() then return "fail", L("CHANGE_NO_COMPANION") end
        Items.MarkDirty()
        local e = Items.Index().byUid[cs.uid]
        if not e then return "fail", L("ITEM_GONE", L("PART_COMPANION")) end
        RequestEquipItem(e.bag, e.slot, BAG_COMPANION_WORN)
        step.check = function() return Items.Uid(BAG_COMPANION_WORN, cs.slot) == cs.uid end
        return "check"
    end, { delay = 250 })
end

-- the plan as a list of steps, in a safe order
local function MakeSteps(plan)
    local steps = {}
    local function Add(s) steps[#steps + 1] = s end
    -- steps whose items make the game play a sound (muted with the quiet switch)
    local function Noisy(s) s.noisy = true Add(s) end
    if plan.weaponsChange then Add(SheatheStep()) end
    -- a second mythic can't be worn: take the old one off first
    for _, g in ipairs(plan.gearSteps) do
        if g.mythic then
            local other = WornMythicSlot(g.slot)
            if other then Noisy(UnequipMythicStep(other)) end
            break
        end
    end
    for _, g in ipairs(plan.gearSteps) do Noisy(GearStep(g)) end
    for _, sk in ipairs(plan.skillSteps) do Add(SkillStep(sk)) end
    if plan.cpStep then Add(CPStep(plan.cpStep, plan)) end
    if plan.foodStep then Noisy(FoodStep(plan.foodStep)) end
    for _, qs in ipairs(plan.quickSteps) do Noisy(QuickStep(qs)) end
    if plan.outfitStep then Noisy(OutfitStep(plan.outfitStep)) end
    if plan.titleStep then Add(TitleStep(plan.titleStep)) end
    for _, id in ipairs(plan.collectSteps) do Noisy(CollectStep(id)) end
    for _, cs in ipairs(plan.companionSteps) do Noisy(CompanionStep(cs)) end
    return steps
end

-- ---------------------------------------------------------------------------
-- Runner

local function Ready()
    if IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then return false end
    if IsBlockActive and IsBlockActive() then return false end
    return true
end

-- Quiet switch (1.0.2): the game itself plays an item's sound when it's put on the quickslot
-- wheel or equipped (a potion = drinking, food = eating, a poison = liquid, armor = clank). That
-- happens in the engine, not in its Lua, so it can't be hooked: instead the sound-effect and
-- interface volumes go to 0 while the steps run and come back right after. The old values are
-- kept in sv.soundMuted until restored, so a crash or /reloadui mid-switch can't leave you muted.
-- Never muted while waiting out a fight (you'd lose the combat sounds).
local AUDIO_KEYS = { "AUDIO_SETTING_SFX_VOLUME", "AUDIO_SETTING_UI_VOLUME" }
local QUIET_START_MS = 200
local unmuteAt   -- frame time to restore at (a short tail: the last item sound comes a moment later)

local function Unmute()
    unmuteAt = nil
    B.EM:UnregisterForUpdate("Skillbound_Unmute")
    local saved = B.sv.soundMuted
    if not saved then return end
    B.sv.soundMuted = nil
    for key, value in pairs(saved) do
        if _G[key] then pcall(SetSetting, SETTING_TYPE_AUDIO, _G[key], value) end
    end
end

local function Mute()
    if B.sv.soundMuted then return end   -- (already muted)
    if not (B.sv.quietSwap and SETTING_TYPE_AUDIO and GetSetting and SetSetting) then return end
    local saved = {}
    for _, key in ipairs(AUDIO_KEYS) do
        if _G[key] then
            local ok, value = pcall(GetSetting, SETTING_TYPE_AUDIO, _G[key])
            if ok and value then saved[key] = value end
        end
    end
    if not next(saved) then return end
    B.sv.soundMuted = saved
    for key in pairs(saved) do pcall(SetSetting, SETTING_TYPE_AUDIO, _G[key], "0") end
end

local function UnmuteSoon(ms)
    if not B.sv.soundMuted then return end
    unmuteAt = GetFrameTimeMilliseconds() + (ms or 600)
    B.EM:RegisterForUpdate("Skillbound_Unmute", 100, function()
        if unmuteAt and GetFrameTimeMilliseconds() >= unmuteAt then Unmute() end
    end)
end

Apply.Unmute = Unmute

local Finish

local function NextStep(r, delay)
    local step = r.steps[r.i]
    r.i = r.i + 1
    r.nextAt = Now() + (delay or 0)
    -- the window flashes the slot that just changed (step.slot = gear slot, step.cat + step.skillSlot = skill)
    if step and not step.failed then B.callbacks:FireCallbacks("StepDone", step) end
    B.callbacks:FireCallbacks("ApplyProgress")
end

local function FailStep(r, step, why)
    r.problems[#r.problems + 1] = why or L("STEP_FAILED", step.label or "?")
    step.failed = true
    B.callbacks:FireCallbacks("StepFailed", step)
    NextStep(r, step.delay)
end

local function Tick()
    local r = running
    if not r then
        B.EM:UnregisterForUpdate("Skillbound_Apply")
        return
    end
    if not Ready() then
        if B.sv.soundMuted then Unmute() end   -- (a fight: your sound back while it waits)
        if not r.waiting then
            r.waiting = true
            if not r.opts.silent then B.Print(L("WAIT_COMBAT", r.build.name)) end
            B.callbacks:FireCallbacks("ApplyProgress")
        end
        return
    end
    r.waiting = false
    local now = Now()
    if r.nextAt and now < r.nextAt then return end
    local step = r.steps[r.i]
    if not step then
        Finish(r)
        return
    end
    -- quiet switch: muted right before an item step (the first step waits QUIET_START_MS, so your
    -- click's own sound plays out), back on once no item step is left
    if step.noisy then
        if not B.sv.soundMuted then Mute() end
        unmuteAt = nil
    elseif B.sv.soundMuted and not unmuteAt then
        local more = false
        for k = r.i, #r.steps do if r.steps[k].noisy then more = true break end end
        if not more or step.waitMs then UnmuteSoon() end
    end
    if step.state == "check" then
        local ok, done = pcall(step.check)
        if ok and done then
            step.state = nil
            if step.after then
                local good, why = step.after()
                if not good then FailStep(r, step, why) return end
            end
            NextStep(r, step.delay)
        elseif now > step.deadline then
            step.state = nil
            step.retried = (step.retried or 0) + 1
            if step.retried > 1 then FailStep(r, step, L("STEP_FAILED", step.label)) end
        end
        return
    end
    step.tries = (step.tries or 0) + 1
    local ok, result, why = pcall(step.run, step)
    if not ok then
        -- (first line only: the game's message can carry a whole stack trace)
        local msg = tostring(result):match("^[^\n]*") or "?"
        B.ReportError("step " .. tostring(step.label), result, true)   -- (kept for /sb errors; the step line says it already)
        FailStep(r, step, L("STEP_ERROR", step.label or "?", msg))
    elseif result == "done" then
        NextStep(r, step.delay)
    elseif result == "check" then
        step.state = "check"
        step.deadline = now + (step.timeout or 3000)
    elseif result == "wait" then
        if step.tries > (step.maxTries or 12) then
            FailStep(r, step, why or L("STEP_FAILED", step.label))
        else
            r.nextAt = now + (step.waitMs or 300)
            B.callbacks:FireCallbacks("ApplyProgress")
        end
    else
        FailStep(r, step, why)
    end
end

Finish = function(r)
    running = nil
    B.EM:UnregisterForUpdate("Skillbound_Apply")
    UnmuteSoon()
    Items.MarkDirty()
    local b = r.build
    if r.opts.silent then
        for _, p in ipairs(r.problems) do B.Print(p) end
    else
        local c = B.Char()
        if not r.opts.undo then
            if b.parent and B.Get(b.parent) then
                c.layer = b.id
            else
                c.worn, c.layer = b.id, nil
            end
        end
        if #r.problems == 0 then
            B.Announce(L(r.opts.undo and "UNDONE" or "WORN", b.name))
        else
            B.Announce(L("WORN_PROBLEMS", b.name, #r.problems), true)
            for _, p in ipairs(r.problems) do B.Print("  " .. p) end
        end
        -- remember the stats this build gives (after the game has added everything up)
        if not r.opts.undo and not b.parent and #r.problems == 0 and B.sv.builds[b.id] then
            B.Later(function()
                b.stats = Capture.Stats()
                B.callbacks:FireCallbacks("BuildsChanged")
            end, 2500)
        end
    end
    B.callbacks:FireCallbacks("ApplyProgress")
    B.callbacks:FireCallbacks("Worn", b)
end

function Apply.IsRunning() return running ~= nil end

-- progress for the button: build, done steps, all steps, waiting (combat / cooldown)
function Apply.Progress()
    if not running then return nil end
    return running.build, running.i - 1, #running.steps, running.waiting or running.cpWait
end

function Apply.Cancel()
    if running then
        running = nil
        B.EM:UnregisterForUpdate("Skillbound_Apply")
        UnmuteSoon(0)
        B.callbacks:FireCallbacks("ApplyProgress")
    end
end

-- What you wear now (the parts the build will change), to undo with "Back to previous".
local function Snapshot(build)
    local parts = {}
    for k, v in pairs(build.parts or {}) do parts[k] = v end
    local snap = { name = L("UNDO_NAME", build.source or build.name), source = build.source or build.name, parts = parts, undo = true }
    for part, on in pairs(parts) do
        if on then snap[part] = Capture.Read(part) end
    end
    return snap
end

function Apply.RunSteps(build, steps, opts)
    if running then Apply.Cancel() end
    running = { build = build, steps = steps, i = 1, problems = {}, opts = opts or {} }
    if B.sv.quietSwap and not B.sv.soundMuted and steps[1] and steps[1].noisy then running.nextAt = Now() + QUIET_START_MS end
    B.EM:RegisterForUpdate("Skillbound_Apply", TICK_MS, Tick)
    B.callbacks:FireCallbacks("ApplyProgress")
    Tick()
end

function Apply.Run(plan, opts)
    opts = opts or {}
    local build = plan.build
    local steps = MakeSteps(plan)
    if #steps == 0 then
        local c = B.Char()
        if not opts.undo and not opts.silent then
            if build.parent and B.Get(build.parent) then c.layer = build.id else c.worn, c.layer = build.id, nil end
        end
        if not opts.silent then
            if plan.problems > 0 then
                B.Announce(L("WORN_PROBLEMS", build.name, plan.problems), true)
                for _, ch in ipairs(plan.changes) do B.Print("  " .. ch.text) end
            else
                B.Announce(L("ALREADY_WORN", build.name))
            end
        end
        B.callbacks:FireCallbacks("Worn", build)
        return
    end
    if not opts.undo and not opts.silent then
        B.Char().undo = Snapshot(build)
    end
    -- problems that are already known (missing pieces...) are listed at the end too
    Apply.RunSteps(build, steps, opts)
    for _, ch in ipairs(plan.changes) do
        if ch.status == "missing" or ch.status == "other" or ch.status == "bank" or ch.status == "bad" then
            running.problems[#running.problems + 1] = ch.text
        end
    end
end

-- Wear a build. opts.preview: show "what will change" first (only from the window).
function Apply.Wear(build, opts)
    if not build then return end
    opts = opts or {}
    -- the prebuff's skills are on the bar: put yours back first, else the prebuff would put the
    -- old skills back later, over the build you're wearing now
    if B.Prebuff and B.Prebuff.IsActive() then B.Prebuff.Restore() end
    local plan = Apply.Plan(build)
    -- nothing would change: no preview panel, just "you're wearing it already"
    if opts.preview and B.sv.showChanges and #plan.changes > 0 and B.UI and B.UI.ShowChanges then
        B.UI.ShowChanges(plan)
        return
    end
    if not opts.silent and not Ready() then B.Print(L("WAIT_COMBAT", build.name)) end
    Apply.Run(plan, opts)
end

function Apply.Undo()
    local snap = B.Char().undo
    if not snap then
        B.Print(L("NO_UNDO"))
        return
    end
    local plan = Apply.Plan(snap)
    -- undoing again goes back to where you were (so undo works like a toggle)
    local back = Snapshot(snap)
    Apply.Run(plan, { undo = true })
    B.Char().undo = back
end

-- ---------------------------------------------------------------------------
-- Auto eat (0.6.1): a build with "Eat in dungeons" (b.foodAuto) eats its food when you arrive
-- in a dungeon, trial, delve or other instance and its buff isn't running; while you stay
-- inside it eats again (after a fight, checked every 30 s). Never in combat, never while a build
-- is going on. 0.6.7: renews once less than sv.foodRenewMin minutes are left (so it doesn't run
-- out mid-fight), and never eats over another food's buff.

local lastEat, warnedNoFood = 0, false

local function InInstance()
    if IsUnitInDungeon and IsUnitInDungeon("player") then return true end
    if IsPlayerInRaid and IsPlayerInRaid() then return true end
    if GetCurrentZoneDungeonDifficulty then
        local ok, d = pcall(GetCurrentZoneDungeonDifficulty)
        if ok and d and d ~= 0 then return true end
    end
    return false
end

-- the build whose food counts: the layer you wear if it has one, else the build
local function FoodBuild()
    local c = B.Char()
    local layer = B.Get(c.layer)
    if layer and layer.foodAuto and layer.food then return layer end
    return B.Get(c.worn)
end

Apply.InInstance = InInstance
Apply.FoodBuild = FoodBuild

function Apply.AutoEat()
    local b = FoodBuild()
    if not (b and b.foodAuto and b.parts and b.parts.food and b.food and b.food.id) then return end
    if not InInstance() then return end
    if running or IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then return end
    local left = Apply.FoodLeft(b.food.id)
    if left and left > (B.sv.foodRenewMin or 0) * 60 then return end
    if Apply.OtherFoodRunning(b.food.id) then return end   -- (only one food buff runs at a time: that one's yours)
    if GetFrameTimeSeconds() - lastEat < 20 then return end   -- (the buff takes a moment to show)
    local bag, slot = FindInBag(BAG_BACKPACK, b.food.id)
    if not bag then
        if not warnedNoFood then B.Print(L("AUTO_EAT_NONE", Apply.FoodName(b.food))) end
        warnedNoFood = true
        return
    end
    lastEat = GetFrameTimeSeconds()
    Apply.EatFood(bag, slot, b.food.id, b.food.link or GetItemLink(bag, slot))
    B.Print(L("AUTO_EAT_DONE", Apply.FoodName(b.food)))
end

-- ---------------------------------------------------------------------------
-- Poison refill: an empty poison slot gets the next stack of the same poison
-- (after combat; the game doesn't allow equipping in combat).

local lastPoison = {}

local function OnWornChanged(_, bagId, slotId)
    if bagId ~= BAG_WORN or not Items.POISON[slotId] then return end
    local link = GetItemLink(BAG_WORN, slotId)
    if link ~= "" then
        lastPoison[slotId] = link
        return
    end
    local old = lastPoison[slotId]
    if not old or not B.sv.refillPoison or running then return end
    local entry = { id = GetItemLinkItemId(old), link = old }
    if not Items.FindPoison(entry) then return end
    Apply.RunSteps({ name = L("PART_POISON") }, { GearStep({ slot = slotId, poison = entry }) }, { silent = true })
end

function Apply.Init()
    -- (a switch was cut off by /reloadui, a crash or logging out while muted: volume back first)
    Unmute()
    B.Capture.Init()
    B.EM:RegisterForEvent("Skillbound_CP", EVENT_CHAMPION_PURCHASE_RESULT, function(_, result)
        cpResult = result
        if result == CHAMPION_PURCHASE_SUCCESS then
            cpReadyAt = GetFrameTimeSeconds() + CP_COOLDOWN
        end
    end)
    -- the champion screen's star animation errors when it isn't open (same fix as Wizard's Wardrobe)
    if CHAMPION_PERKS and CHAMPION_PERKS.StartStarConfirmAnimation then
        ZO_PreHook(CHAMPION_PERKS, "StartStarConfirmAnimation", function()
            if skipCpAnimation then
                skipCpAnimation = false
                return true
            end
        end)
    end
    for _, s in ipairs({ EQUIP_SLOT_POISON, EQUIP_SLOT_BACKUP_POISON }) do
        local link = GetItemLink(BAG_WORN, s)
        if link ~= "" then lastPoison[s] = link end
    end
    -- auto eat: on arrival (after the loading screen), after fights, every 30 s, after wearing a build
    B.EM:RegisterForEvent("Skillbound_AutoEat", EVENT_PLAYER_ACTIVATED, function()
        warnedNoFood = false
        B.Later(Apply.AutoEat, 3000)
    end)
    B.EM:RegisterForEvent("Skillbound_AutoEatCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then B.Later(Apply.AutoEat, 1500) end
    end)
    B.EM:RegisterForUpdate("Skillbound_AutoEatTick", 30000, Apply.AutoEat)
    B.callbacks:RegisterCallback("Worn", function() B.Later(Apply.AutoEat, 1500) end)
    B.EM:RegisterForEvent("Skillbound_Poison", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornChanged)
    B.EM:AddFilterForEvent("Skillbound_Poison", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
end
