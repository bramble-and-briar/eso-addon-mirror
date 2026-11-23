Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ContentKind = {}
local M = Verdant.ContentKind

local ARENAS = {
  [635]  = "Dragonstar Arena",
  [677]  = "Maelstrom Arena",
  [1082] = "Blackrose Prison",
  [1227] = "Vateshran Hollows",
}

M.ICON = {
  dungeon = "EsoUI/Art/Icons/mapKey/mapKey_groupInstance.dds",
  trial   = "EsoUI/Art/Icons/mapKey/mapKey_raidDungeon.dds",
  arena   = "EsoUI/Art/Icons/mapKey/mapKey_soloInstance.dds",
  archive = "EsoUI/Art/Icons/mapKey/mapKey_endlessDungeon.dds",
  bg      = "EsoUI/Art/Battlegrounds/battlegrounds_tabIcon_battlegrounds_up.dds",
  bgc     = "EsoUI/Art/Inventory/inventory_tabIcon_trophy_up.dds",
  ava     = "EsoUI/Art/Campaign/campaign_tabIcon_summary_up.dds",
  house   = "EsoUI/Art/Icons/mapKey/mapKey_housing.dds",
  world   = "EsoUI/Art/Icons/mapKey/mapKey_adventureZone.dds",
}

local FAIL = "Verdant_ContentKind"
local told = false

local function failed(err)
  local zev = Verdant.zenimax.events
  local line = nil
  if not told then
    told = true
    line = string.format(Verdant.zenimax.api.GetString(VERDANT_CONTENT_KIND_FAILED), zev.error_label(FAIL))
  end
  zev.fail(FAIL, err, line)
end

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then
    failed(v)
    return nil
  end
  return v
end

function M.detect()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if call(api.IsActiveWorldBattleground) then
    local id   = call(api.GetCurrentBattlegroundId)
    local size = id and call(api.GetBattlegroundTeamSize, id)
    return (size == 4) and "bgc" or "bg"
  end
  if call(api.IsPlayerInEndlessDungeon) then return "archive" end
  if call(api.IsPlayerInRaid) then return "trial" end
  if call(api.IsInCyrodiil) or call(api.IsInImperialCity) then return "ava" end
  local house = call(api.GetCurrentZoneHouseId)
  if house and house ~= 0 then return "house" end
  local content = call(api.GetMapContentType)
  if content == zc.MAP_CONTENT_DUNGEON then
    local zone = call(api.GetZoneId, call(api.GetUnitZoneIndex, "player"))
    if zone and ARENAS[zone] then return "arena" end
    return "dungeon"
  end
  if content == zc.MAP_CONTENT_AVA then return "ava" end
  if content == zc.MAP_CONTENT_BATTLEGROUND then return "bg" end
  return "world"
end

function M.icon(kind) return kind and M.ICON[kind] or nil end

function M.arena_name(zone_id) return ARENAS[zone_id] end
