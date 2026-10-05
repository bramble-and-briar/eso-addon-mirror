-- Skillbound_Armory.lua : import the game's own Armory builds (2026-10-01).
-- The Armory (a house station) keeps builds the game can read anywhere: its gear (where the
-- pieces are now), both skill bars, the champion bar and the outfit. Each one becomes a
-- normal Skillbound build ("Armory: <name>"), so it can be worn without the station.
-- API from esoui armorybuilddata.lua / armory_manager.lua: GetNumUnlockedArmoryBuilds,
-- GetArmoryBuildName, GetArmoryBuildEquipSlotInfo(build, equipSlot) -> state, bag, slot,
-- GetArmoryBuildSlotBoundId(build, slot, hotbarCategory), GetArmoryBuildEquippedOutfitIndex.
-- Unverified in-game; every call is pcall-guarded.

local B = Skillbound
local L = B.L
local Items, Capture = B.Items, B.Capture
local Armory = {}
B.Armory = Armory

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

function Armory.Count()
    return Try(GetNumUnlockedArmoryBuilds) or 0
end

function Armory.Name(i)
    local name = Try(GetArmoryBuildName, i)
    if not name or name == "" then name = L("ARMORY_UNNAMED", i) end
    return B.Name(name)
end

function Armory.Import(i)
    local b = {
        id = B.NewId(), name = L("ARMORY_BUILD_NAME", Armory.Name(i)), classId = GetUnitClassId("player"),
        owner = B.Char().name, created = GetTimeStamp(), parts = {}, gear = {}, skills = {},
    }
    -- gear: where each piece is now
    for _, s in ipairs(Items.SLOTS) do
        local _, bag, slot = Try(GetArmoryBuildEquipSlotInfo, i, s)
        if bag and slot and GetItemId(bag, slot) ~= 0 then
            local p = Items.Info(GetItemLink(bag, slot))
            if not Items.POISON[s] then p.uid = Items.Uid(bag, slot) end
            b.gear[s] = p
        end
    end
    -- skill bars
    for _, cat in ipairs(Capture.BARS) do
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local id = Try(GetArmoryBuildSlotBoundId, i, slot, cat)
            if id and id ~= 0 then
                b.skills[cat] = b.skills[cat] or {}
                b.skills[cat][slot] = { id = id, name = B.Name(GetAbilityName(id)), line = Capture.LineOf(id) }
            end
        end
    end
    -- champion bar
    local cp = {}
    for slot = 1, 12 do
        local id = Try(GetArmoryBuildSlotBoundId, i, slot, HOTBAR_CATEGORY_CHAMPION)
        if id and id ~= 0 then cp[slot] = id end
    end
    if next(cp) then b.cp = { slots = cp } end
    -- outfit
    local outfit = Try(GetArmoryBuildEquippedOutfitIndex, i)
    if outfit then
        b.outfit = { index = outfit, name = GetOutfitName and outfit ~= 0 and Try(GetOutfitName, GAMEPLAY_ACTOR_CATEGORY_PLAYER, outfit) or nil }
    end
    b.parts.gear = next(b.gear) ~= nil
    b.parts.skills = next(b.skills) ~= nil
    b.parts.cp = b.cp ~= nil
    b.parts.outfit = b.outfit ~= nil
    if not (b.parts.gear or b.parts.skills or b.parts.cp) then
        B.Print(L("ARMORY_EMPTY", Armory.Name(i)))
        return
    end
    B.sv.builds[b.id] = b
    B.callbacks:FireCallbacks("BuildsChanged")
    B.Print(L("ARMORY_IMPORTED", b.name))
    if B.UI and B.UI.Select then B.UI.Select(b.id) end
end

function Armory.Menu(anchor)
    ClearMenu()
    local n = Armory.Count()
    if n == 0 then
        AddMenuItem(B.Colorize(B.COLOR.dim, L("ARMORY_NONE")), function() end)
    end
    for i = 1, n do
        AddMenuItem(Armory.Name(i), function() Armory.Import(i) end)
    end
    ShowMenu(anchor)
end
