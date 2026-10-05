-- Skillbound_Fix.lua : "Fix it" for the Gear check page (2026-10-01).
--   Repair: worn pieces under sv.fix.repairAt % with repair kits from your bag, up to 100 %
--           (one kit after another while it still isn't full).
--   Recharge: worn weapons under sv.fix.chargeAt % with filled soul gems from your bag (full).
--   Bank: the worn build's pieces that are in the bank come out (only while the bank is open).
--   Auto (0.6.0): sv.fix.autoRepair / autoCharge do the same by themselves, out of combat, as
--           soon as something drops under its threshold (no question, no window).
-- Everything runs through the same step queue as Wear (waits out of combat, checks each step).
-- Unverified API guesses (from esoui source / other addons): IsItemRepairKit,
-- RepairItemWithRepairKit, IsItemChargeable, GetChargeInfoForItem, IsItemSoulGem,
-- ChargeItemWithSoulGem. Each call is pcall-guarded.

local B = Skillbound
local L = B.L
local Items = B.Items
local Fix = {}
B.Fix = Fix

Fix.DEFAULT_REPAIR_AT = 60     -- % condition: below = worth repairing
Fix.DEFAULT_CHARGE_AT = 30     -- % charge: below = worth recharging
Fix.MIN_AT, Fix.MAX_AT = 5, 100   -- (100 = anything that isn't full)

local function Cfg()
    B.sv.fix = B.sv.fix or {}
    return B.sv.fix
end
function Fix.RepairAt() return zo_clamp(Cfg().repairAt or Fix.DEFAULT_REPAIR_AT, Fix.MIN_AT, Fix.MAX_AT) end
function Fix.ChargeAt() return zo_clamp(Cfg().chargeAt or Fix.DEFAULT_CHARGE_AT, Fix.MIN_AT, Fix.MAX_AT) end
function Fix.SetRepairAt(v) Cfg().repairAt = zo_clamp(zo_round(v), Fix.MIN_AT, Fix.MAX_AT) end
function Fix.SetChargeAt(v) Cfg().chargeAt = zo_clamp(zo_round(v), Fix.MIN_AT, Fix.MAX_AT) end
function Fix.AutoRepair() return Cfg().autoRepair == true end
function Fix.AutoCharge() return Cfg().autoCharge == true end

local WEAPONS = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

-- bag slots holding something that passes test(bag, slot)
local function FindInBag(test)
    local list = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slot) ~= 0 and test(BAG_BACKPACK, slot) then
            list[#list + 1] = { slot = slot, count = GetSlotStackSize(BAG_BACKPACK, slot) }
        end
    end
    return list
end

local function Kits() return FindInBag(function(bag, slot) return Try(IsItemRepairKit, bag, slot) == true end) end
local function Gems() return FindInBag(function(bag, slot) return Try(IsItemSoulGem, SOUL_GEM_TYPE_FILLED, bag, slot) == true end) end

local function Count(list)
    local n = 0
    for _, e in ipairs(list) do n = n + (e.count or 1) end
    return n
end

-- the picture of the kits / filled gems in your bag (the first one found) and how many there are;
-- remembered (sv.fix.kitIcon / gemIcon) so an empty bag can still show it greyed
local function BagIcon(list, key)
    local e = list[1]
    if e then
        local icon = GetItemInfo(BAG_BACKPACK, e.slot)
        if icon and icon ~= "" then Cfg()[key] = icon end
    end
    return Cfg()[key], Count(list)
end
function Fix.KitIcon() return BagIcon(Kits(), "kitIcon") end
function Fix.GemIcon() return BagIcon(Gems(), "gemIcon") end

-- the game's own sounds for it (as when you repair / recharge from the inventory)
local function Sound(name)
    local s = SOUNDS and SOUNDS[name]
    if s then PlaySound(s) end
end

-- what's worn right now: lowest condition, lowest weapon charge, what could be fixed
function Fix.Status()
    local s = { minCond = 100, minCharge = 100, repair = {}, charge = {} }
    local repairAt, chargeAt = Fix.RepairAt(), Fix.ChargeAt()
    for _, slot in ipairs(Items.SLOTS) do
        if not Items.POISON[slot] and GetItemId(BAG_WORN, slot) ~= 0 and DoesItemHaveDurability(BAG_WORN, slot) then
            local c = GetItemCondition(BAG_WORN, slot)
            if c < s.minCond then s.minCond = c end
            if c < repairAt then s.repair[#s.repair + 1] = slot end
        end
    end
    for _, slot in ipairs(WEAPONS) do
        if GetItemId(BAG_WORN, slot) ~= 0 and Try(IsItemChargeable, BAG_WORN, slot) then
            local charges, max = Try(GetChargeInfoForItem, BAG_WORN, slot)
            if charges and max and max > 0 then
                local pct = math.floor(charges / max * 100)
                if pct < s.minCharge then s.minCharge = pct end
                if pct < chargeAt then s.charge[#s.charge + 1] = slot end
            end
        end
    end
    s.kits = Count(Kits())
    s.gems = Count(Gems())
    return s
end

-- repairs one piece up to 100 %: a kit, wait for the game, another kit while it isn't full
-- (a kit that changed nothing three times in a row = stop; out of kits after one = fine)
local function RepairStep(slot)
    return {
        label = L("FIX_REPAIRING", Items.SlotName(slot)),
        delay = 150, maxTries = 14,
        run = function(step)
            local cond = GetItemCondition(BAG_WORN, slot)
            if cond >= 100 then return "done" end
            if step.last then
                if cond <= step.last then
                    step.stuck = (step.stuck or 0) + 1
                    if step.stuck >= 3 then return "fail", L("STEP_FAILED", step.label) end
                else
                    step.stuck = 0
                end
            end
            local kit = Kits()[1]
            if not kit then
                if step.last and cond > step.first then return "done" end   -- used every kit there was
                return "fail", L("FIX_NO_KITS")
            end
            step.first = step.first or cond
            step.last = cond
            Try(RepairItemWithRepairKit, BAG_WORN, slot, BAG_BACKPACK, kit.slot)
            Sound("INVENTORY_ITEM_REPAIR")
            step.waitMs = 700
            return "wait"
        end,
    }
end

local function ChargeStep(slot)
    return {
        label = L("FIX_CHARGING", Items.SlotName(slot)),
        run = function(step)
            local c, max = Try(GetChargeInfoForItem, BAG_WORN, slot)
            if not c or not max or max == 0 or c >= max then return "done" end
            local gem = Gems()[1]
            if not gem then return "fail", L("FIX_NO_GEMS") end
            Try(ChargeItemWithSoulGem, BAG_WORN, slot, BAG_BACKPACK, gem.slot)
            Sound("INVENTORY_ITEM_APPLY_CHARGE")
            step.check = function()
                local now = Try(GetChargeInfoForItem, BAG_WORN, slot)
                return now and now > c
            end
            return "check"
        end,
    }
end

local function Report(key)
    return { label = "", run = function() B.Print(L(key)) return "done" end }
end

function Fix.Repair()
    local s = Fix.Status()
    if #s.repair == 0 then B.Print(L("FIX_NOTHING_REPAIR")) return end
    if s.kits == 0 then B.Print(L("FIX_NO_KITS")) return end
    local steps = {}
    for _, slot in ipairs(s.repair) do steps[#steps + 1] = RepairStep(slot) end
    steps[#steps + 1] = Report("FIX_DONE")
    B.Apply.RunSteps({ name = L("FIX_REPAIR") }, steps, { silent = true })
end

function Fix.Recharge()
    local s = Fix.Status()
    if #s.charge == 0 then B.Print(L("FIX_NOTHING_CHARGE")) return end
    if s.gems == 0 then B.Print(L("FIX_NO_GEMS")) return end
    local steps = {}
    for _, slot in ipairs(s.charge) do steps[#steps + 1] = ChargeStep(slot) end
    steps[#steps + 1] = Report("FIX_DONE")
    B.Apply.RunSteps({ name = L("FIX_RECHARGE") }, steps, { silent = true })
end

-- everything that can be fixed right now, one queue
function Fix.All()
    local s = Fix.Status()
    local steps = {}
    if s.kits > 0 then
        for _, slot in ipairs(s.repair) do steps[#steps + 1] = RepairStep(slot) end
    end
    if s.gems > 0 then
        for _, slot in ipairs(s.charge) do steps[#steps + 1] = ChargeStep(slot) end
    end
    local worn = B.WornBuild()
    local bank = worn and IsBankOpen() and B.Bank
    if #steps == 0 then
        if bank then B.Bank.TakeOut(worn) else B.Print(L("FIX_NOTHING")) end
        return
    end
    steps[#steps + 1] = Report("FIX_DONE")
    -- the bank goes last: Bank.TakeOut starts its own queue (which would end this one)
    if bank then
        steps[#steps + 1] = { label = "", run = function()
            if IsBankOpen() then B.Bank.TakeOut(worn) end
            return "done"
        end }
    end
    B.Apply.RunSteps({ name = L("FIX_ALL") }, steps, { silent = true })
end

-- ---------------------------------------------------------------------------
-- Auto repair / recharge: checked a moment after a worn piece loses condition or a weapon
-- loses charge, after every fight and after loading screens. Only out of combat, never while a
-- build is being put on. One short chat line says what it did. If something stays under its
-- threshold afterwards (no fitting kit, the game refused), it rests 5 minutes before trying again
-- (no chat spam after every fight).

local restUntil = 0

local function AutoCheck()
    local repair, charge = Fix.AutoRepair(), Fix.AutoCharge()
    if not (repair or charge) then return end
    if GetFrameTimeSeconds() < restUntil then return end
    if B.Apply.IsRunning() or IsUnitInCombat("player") or IsUnitDeadOrReincarnating("player") then return end
    local s = Fix.Status()
    local steps, nRepair, nCharge = {}, 0, 0
    if repair and s.kits > 0 then
        for _, slot in ipairs(s.repair) do
            steps[#steps + 1] = RepairStep(slot)
            nRepair = nRepair + 1
        end
    end
    if charge and s.gems > 0 then
        for _, slot in ipairs(s.charge) do
            steps[#steps + 1] = ChargeStep(slot)
            nCharge = nCharge + 1
        end
    end
    if #steps == 0 then return end
    steps[#steps + 1] = { label = "", run = function()
        local after = Fix.Status()
        if (repair and #after.repair > 0) or (charge and #after.charge > 0) then
            restUntil = GetFrameTimeSeconds() + 300
        end
        B.Print(L("FIX_AUTO_DONE", nRepair, nCharge))
        B.callbacks:FireCallbacks("FixDone")
        return "done"
    end }
    B.Apply.RunSteps({ name = L("FIX_AUTO") }, steps, { silent = true })
end

function Fix.AutoSoon(ms)
    B.EM:UnregisterForUpdate("Skillbound_FixAuto")
    B.EM:RegisterForUpdate("Skillbound_FixAuto", ms or 1500, function()
        B.EM:UnregisterForUpdate("Skillbound_FixAuto")
        AutoCheck()
    end)
end

-- a switch or a slider changed: try again right away (also after a rest)
function Fix.SettingsChanged()
    restUntil = 0
    Fix.AutoSoon(300)
end

function Fix.Init()
    local cfg = Cfg()
    if cfg.repairAt == nil then cfg.repairAt = Fix.DEFAULT_REPAIR_AT end
    if cfg.chargeAt == nil then cfg.chargeAt = Fix.DEFAULT_CHARGE_AT end
    B.EM:RegisterForEvent("Skillbound_FixWorn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        function(_, bagId, _, _, _, reason)
            if bagId ~= BAG_WORN then return end
            if reason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE or reason == INVENTORY_UPDATE_REASON_ITEM_CHARGE then
                Fix.AutoSoon(1500)
            end
        end)
    B.EM:AddFilterForEvent("Skillbound_FixWorn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    B.EM:RegisterForEvent("Skillbound_FixCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then Fix.AutoSoon(1500) end
    end)
    B.EM:RegisterForEvent("Skillbound_FixLogin", EVENT_PLAYER_ACTIVATED, function() Fix.AutoSoon(4000) end)
end
