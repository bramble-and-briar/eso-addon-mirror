-- Rule action "Select quickslot": pick a potion (or any quickslot) on the quickslot wheel while a rule matches.
-- (Tony, 5.17.5: "maybe just a condition setting 'if x buff is up, swap to quickslot number x' -- that's all
-- Comp's Pot Swapper is doing".)
--
-- How Comp's Pot Swapper (Complicative, 1.1.2) does it, read in full: every 100 ms it compares the time left on a buff
-- (GetUnitBuffInfo on the player) with the potion cooldown (GetSlotCooldownInfo(GetCurrentQuickslot(),
-- HOTBAR_CATEGORY_QUICKSLOT_WHEEL)); if the potion is ready before the buff has more than <threshold> s left it selects
-- the "buff" potion's slot, else the other one -- SetCurrentQuickslot(slot), slots 1-8 around the wheel. After you
-- change the quickslot yourself (EVENT_ACTIVE_QUICKSLOT_CHANGED that it didn't cause) it waits 3 s.
-- esoui calls SetCurrentQuickslot from plain UI code (utilitywheel_shared.lua): not a protected function.
--
-- Here: any rule can say "Select quickslot N". Each update the last matching rule's slot wins; it's selected unless
-- it already is, it's empty, or you changed the quickslot yourself in the last 3 s. Rule properties for the pot
-- swapper logic: "Potion cooldown left" and "Buff time left when the potion is ready". Nothing runs (no event, no
-- check) unless a tracker has a quickslot rule.

local DT = DebuffTracker
local QS = {}
DT.Quickslot = QS
local U = DT.Util

local NS = "DebuffTracker5_Quickslot"
QS.MANUAL_PAUSE = 3          -- s after you change the quickslot yourself (Comp's "manual swap delay")
local watching = false
local want = nil
local lastSet, manualAt = nil, -100

local function WheelCategory() return HOTBAR_CATEGORY_QUICKSLOT_WHEEL end

-- seconds left on the cooldown of the selected quickslot (potions share one cooldown)
function QS.Cooldown()
    if type(GetSlotCooldownInfo) ~= "function" or type(GetCurrentQuickslot) ~= "function" then return 0 end
    local remain = GetSlotCooldownInfo(GetCurrentQuickslot(), WheelCategory())
    return math.max(0, (tonumber(remain) or 0) / 1000)
end

local function OnQuickslotChanged()
    if type(GetCurrentQuickslot) ~= "function" then return end
    if GetCurrentQuickslot() ~= lastSet then manualAt = U.Now() end     -- you did it, not us
end

function QS.SetWatched(on)
    on = on == true
    if on == watching then return end
    watching = on
    if on and EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NS, EVENT_ACTIVE_QUICKSLOT_CHANGED, OnQuickslotChanged)
    elseif EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EVENT_MANAGER:UnregisterForEvent(NS, EVENT_ACTIVE_QUICKSLOT_CHANGED)
    end
    want = nil
end
function QS.IsWatched() return watching end

function QS.BeginTick() want = nil end

-- a matching rule asks for this slot (the last one in an update wins)
function QS.Want(slot)
    slot = math.floor(tonumber(slot) or 0)
    if slot >= 1 and slot <= 8 then want = slot end
end

function QS.Apply(now)
    if not watching or not want then return end
    if type(GetCurrentQuickslot) ~= "function" or type(SetCurrentQuickslot) ~= "function" then return end
    if GetCurrentQuickslot() == want then return end
    if now - manualAt < QS.MANUAL_PAUSE then return end
    -- an empty slot: nothing to select
    if type(GetSlotType) == "function" and ACTION_TYPE_NOTHING and GetSlotType(want, WheelCategory()) == ACTION_TYPE_NOTHING then return end
    lastSet = want
    SetCurrentQuickslot(want)
end
