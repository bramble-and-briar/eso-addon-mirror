Verdant = Verdant or {}
local Verdant = Verdant

Verdant.GroupSet = {}

local M = Verdant.GroupSet

local pairs = pairs
local now   = Verdant.zenimax.api.GetGameTimeMilliseconds
local log   = Verdant.Log.for_module("group_set")

local members = {}
local player_unit_id = nil
local since

function M.add(unitId)
  if not unitId or unitId == 0 then return end
  members[unitId] = true
end

function M.set_player(unitId)
  if unitId and unitId ~= 0 then
    if player_unit_id ~= unitId then
      log:info("player unit_id resolved:", unitId)
    end
    player_unit_id = unitId
  end
end

function M.player_id()
  return player_unit_id
end

function M.contains(unitId)
  if not unitId then return false end
  return members[unitId] == true or unitId == player_unit_id
end

function M.reset()
  local n = M.size()
  if n > 0 then log:info("reset: cleared", n, "members") end
  members = {}
  player_unit_id = nil
  since = now()
end

function M.size()
  local n = 0
  for _ in pairs(members) do n = n + 1 end
  return n
end

function M.snapshot()
  local ids = {}
  for uid in pairs(members) do ids[#ids + 1] = uid end
  return { player_unit_id = player_unit_id, member_count = #ids, members = ids, since = since }
end
