-- Skillbound_Bank.lua : "Take out" a build's gear (only what's in the bank) while the bank
-- is open (used by the build menu and the Gear check tab).
-- Items move one by one (each move is checked), like everything Skillbound changes.

local B = Skillbound
local L = B.L
local Items = B.Items
local Bank = {}
B.Bank = Bank

local function MoveStep(fromBag, fromSlot, uid, toBags, label)
    return {
        label = label,
        delay = 150,
        run = function(step)
            if not IsBankOpen() then return "fail", L("BANK_CLOSED") end
            Items.MarkDirty()
            local e = Items.Index().byUid[uid]
            if not e then return "done" end
            for _, bag in ipairs(toBags) do
                if e.bag == bag then return "done" end
            end
            for _, bag in ipairs(toBags) do
                local free = FindFirstEmptySlotInBag(bag)
                if free then
                    CallSecureProtected("RequestMoveItem", e.bag, e.slot, bag, free, 1)
                    step.check = function()
                        Items.MarkDirty()
                        local now = Items.Index().byUid[uid]
                        return now and now.bag == bag
                    end
                    return "check"
                end
            end
            return "fail", L(toBags[1] == BAG_BACKPACK and "BAG_FULL" or "BANK_FULL")
        end,
    }
end

local function Report(key)
    return {
        label = "",
        run = function()
            B.Print(L(key))
            return "done"
        end,
    }
end

function Bank.TakeOut(build)
    if not build or not IsBankOpen() then return end
    local steps, used = {}, {}
    for _, s in ipairs(Items.SLOTS) do
        local p = build.gear and build.gear[s]
        if p and not Items.POISON[s] then
            local f = Items.Find(p, used)
            if f and f.e then
                if f.e.uid then used[f.e.uid] = true end
                if f.kind == "bank" then
                    steps[#steps + 1] = MoveStep(f.e.bag, f.e.slot, f.e.uid, { BAG_BACKPACK }, Items.SlotName(s))
                end
            end
        end
    end
    if #steps == 0 then
        B.Print(L("BANK_NOTHING_OUT", build.name))
        return
    end
    B.Print(L("BANK_TAKING", #steps, build.name))
    steps[#steps + 1] = Report("BANK_DONE")
    B.Apply.RunSteps({ name = build.name }, steps, { silent = true })
end

