LazyCrown=LazyCrown or {}
LazyCrown.later=LazyCrown.later or {}
table.insert(LazyCrown.later,{name="Group.lua",code=[=[
LazyCrown = LazyCrown or {}
local G = {}
LazyCrown.Group = G
local function Results(ok, ...)
if ok then return ... end
end
local function Safe(fn, ...)
if not fn then return nil end
return Results(pcall(fn, ...))
end
local ULTS = {
barrier = { 38573, 40237, 40239 },
rez = { 115410, 118367, 118379 },
negate = { 27706, 28341, 28348 },
}
local KIND_OF = {}
for kind, ids in pairs(ULTS) do for _, id in ipairs(ids) do KIND_OF[id] = kind end end
local function KindOf(id)
if KIND_OF[id] then return KIND_OF[id] end
local base = Safe(function()
local progression = SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(id)
return progression:GetSkillData():GetMorphData(MORPH_SLOT_BASE):GetAbilityId()
end)
return base and KIND_OF[base]
end
local function OwnUltimates()
local slot = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
local ids = {}
for _, bar in ipairs({ HOTBAR_CATEGORY_PRIMARY or 0, HOTBAR_CATEGORY_BACKUP or 1 }) do
local id = Safe(GetSlotBoundId, slot, bar)
if id and id ~= 0 then table.insert(ids, id) end
end
return ids
end
local lgcs
function G.Init()
local lib = LibGroupCombatStats
if lgcs then return end
if lib and lib.RegisterAddon then lgcs = Safe(lib.RegisterAddon, "LazyCrown", {}) end
end
function G.Sharing()
return lgcs ~= nil
end
local function SharedUltimates(tag)
if not lgcs then return nil end
local data = Safe(lgcs.GetUnitULT, lgcs, tag)
if type(data) ~= "table" then return nil end
local ids = {}
for _, id in ipairs({ data.ult1ID or 0, data.ult2ID or 0 }) do if id ~= 0 then table.insert(ids, id) end end
if #ids == 0 then return nil end
return ids
end
local function IsMe(tag)
return tag == "player" or Safe(AreUnitsEqual, tag, "player") == true
end
function G.Members()
local n = Safe(GetGroupSize) or 0
if n == 0 then return { "player" }, 0 end
local here, away = {}, 0
local myZone = Safe(GetUnitZoneIndex, "player")
for i = 1, n do
local tag = Safe(GetGroupUnitTagByIndex, i)
if tag then
local online = IsMe(tag) or Safe(IsUnitOnline, tag) ~= false
local zone = Safe(GetUnitZoneIndex, tag)
local sameZone = zone == nil or myZone == nil or zone == myZone
local sameInstance = Safe(IsGroupMemberInSameInstanceAsPlayer, tag) ~= false
if IsMe(tag) or (online and sameZone and sameInstance) then
table.insert(here, tag)
else
away = away + 1
end
end
end
if #here == 0 then here = { "player" } end
return here, away
end
function G.Size()
return #(G.Members())
end
function G.Tally()
local here, away = G.Members()
local t = { size = #here, away = away, tank = 0, healer = 0, dps = 0, barrier = 0, rez = 0, negate = 0, sharing = 0 }
for _, tag in ipairs(here) do
local role = tag == "player" and Safe(GetSelectedLFGRole) or Safe(GetGroupMemberSelectedRole, tag)
if role == (LFG_ROLE_TANK or 2) then t.tank = t.tank + 1
elseif role == (LFG_ROLE_HEAL or 4) then t.healer = t.healer + 1
else t.dps = t.dps + 1 end
local ults
if IsMe(tag) then ults = OwnUltimates() else ults = SharedUltimates(tag) end
if ults then
t.sharing = t.sharing + 1
local seen = {}
for _, id in ipairs(ults) do
local kind = KindOf(id)
if kind and not seen[kind] then seen[kind] = true; t[kind] = t[kind] + 1 end
end
end
end
return t
end
local function Count(n, one, many)
return string.format("%d %s", n, n == 1 and one or many)
end
function G.Line(t)
t = t or G.Tally()
return string.format("Group size %d: %s, %s, %d DPS. Barrier %d, Necro rez %d, Negate %d.", t.size,
Count(t.tank, "tank", "tanks"), Count(t.healer, "healer", "healers"), t.dps, t.barrier, t.rez, t.negate)
end
G._internal = { ULTS = ULTS, KindOf = KindOf, OwnUltimates = OwnUltimates }
]=]})
