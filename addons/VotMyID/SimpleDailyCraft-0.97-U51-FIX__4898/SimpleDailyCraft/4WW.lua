local SDC = SimpleDailyCraft

SDC.MasterNpcName = ""
SDC.IsCommit = true

--The treated info, each table contain different type writs that will be commited in one round
SDC.RunList = {
--[[
    [1] = {
      ["ui_type"_1] = WWDate[i]
      ["ui_type"_2] = ...
    },
    [2] = ...
    ...
]]
} 
-- The raw info from WritWorthy
--[[
  WWDate[i] = {
    ["item_link"] = ItemLink,
    ["ui_is_completed"] = bool,
    ["ui_type"] = Type String,
    ...
  },
]]
--Tool fun
local function InRange(x, z, Table)
  if Table == nil then return false end
  for i = 1, #Table do
    if x > Table[i][1] and x < Table[i][3] and z > Table[i][2] and z < Table[i][4] then 
      return true 
    end
  end
  return false
end

local function IsMasterWrit(Name)
  for i = 1, #SDC.WritId do
    local TargetName = GetItemLinkName(SDC.WritId[i]):gsub("%^.+", "")
    if Name:lower() == TargetName:lower() then
      return true 
    end
  end
  return false
end

--Start Here
function SDC.WritCycle()
--Check undone master
  if SDC.UndoneMaster then
    SDC.DD(15, {})
    SDC.DD(0)
    return
  end
--Bridge Var
  WritWorthyUI_Refresh()
  local WWList = WritWorthy.InventoryList.inventory_data_list
  local DoneList = {}
--Check done
  for i = 1, #WWList do
    if WWList[i]["ui_is_completed"] then --Done
      if IsMasterWrit(GetItemLinkName(WWList[i]["item_link"]):gsub("%^.+", ""):lower()) then --Normal master writs
        table.insert(DoneList, WWList[i]) 
      end
    end
  end
  --No master writ done
  if DoneList[1] == nil then SDC.DD(12) return end 
--Divide same type writs into different rounds
  SDC.RunList = {{}}
  for a = 1, #DoneList do
    --Use item name of writ, not the type supporte by WW
    local Type = GetItemLinkName(DoneList[a]["item_link"]):gsub("%^.+", ""):lower() 
    local NeedNew = true
    for b = 1, #SDC.RunList do
      if not SDC.RunList[b][Type] then
        SDC.RunList[b][Type] = DoneList[a]
        NeedNew = false
        break
      end
    end
    if NeedNew then table.insert(SDC.RunList, {[Type] = DoneList[a]}) end
  end
  --TotalNum, TotalRound
  SDC.DD(13, {#DoneList, #SDC.RunList}) 
  --Check Journal free slot
  local MaxQ = 1
  for i = 1, #SDC.RunList do
    if #SDC.RunList[i] > MaxQ then MaxQ = #SDC.RunList[i] end
  end
  if MaxQ > (25 - GetNumJournalQuests()) then
    SDC.DD(14, {MaxQ})
    SDC.DD(0)
    SDC.WWEnd() --Reset
    return
  end
  --Build cycle
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.WWCore) --Every interact window close, check current round writ left, and turn it to commit state
  EVENT_MANAGER:RegisterForUpdate("SDCWWDect", 200, SDC.WWDect)   --Detect if it should be stopped
  --Start
  INTERACTION:CloseChatter()
  GAMEPAD_INTERACTION:CloseChatter()
end

local RoundCount = 0
function SDC.WWCore(scene, _, newstate)
  if (scene.name ~= "interact" and scene.name ~= "gamepadInteract") or newstate ~= SCENE_HIDDEN then return end
  local Table = SDC.RunList[1]
  --Check Finish
  if not Table and not SDC.IsCommit then --No writ to read and no quest to commit, so it'S done.
    SDC.WWDect(true)
    return
  end
  --Is quest commit state done?
  --Turn to false, when find that the optionType of the chatteroption1 was 600 (shop).
  --That mean all writs commited, and go into next round.
  if SDC.IsCommit then return end 
  --UseItem stat
  SDC.Key(true) --Unbind the key for interact to avoid touch npc too early
  for k, Writ in pairs(Table) do  --Check unread writ
    for b = 0, GetBagSize(1) do  --Recheck slot for safe
      if GetItemLink(1, b) == Writ["item_link"] then
        CallSecureProtected("UseItem", 1, b)
        SDC.RunList[1][k] = nil
        return
      end
    end
  end
  --Nothing to read but Table exist, so turn into commit
  --Commit quest state
  SDC.IsCommit = true --Commit state marker
  SDC.Key() --Allow to interact with npc
  
  RoundCount = RoundCount + 1
  PlaySound("Enchanting_PotencyRune_Removed")
  SDC.DD(18, {RoundCount})
  
  table.remove(SDC.RunList, 1) --Step into next round, and wait SDC.IsCommit -> false after committing all writ.
  if not SDC.RunList[1] then SDC.LastRound = true end --The final round for commit
end

function SDC.WWDect(Finish)
  --Finish all
  if Finish == true then 
    SDC.WWEnd()
    SDC.DD(16)
    return
  end
  --Error with picking up undone writ
  if SDC.UndoneMaster then 
    SDC.WWEnd()
    SDC.DD(15)
    SDC.DD(0)
    return
  end 
  --Out of range
  local Map, x, _, z = GetUnitWorldPosition("player")
  if not InRange(x, z, SDC.MasterPostion[Map]) then 
    SDC.WWEnd()
    SDC.DD(17)
    SDC.DD(0)
    return
  end
end
--Reset everything for this file
function SDC.WWEnd()
  --Reset var
  RoundCount = 0
  SDC.IsCommit = true
  SDC.LastRound = false
  SDC.RunList = {}
  SDC.Key()
  --Unregister
  EVENT_MANAGER:UnregisterForUpdate("SDCWWDect")
  SCENE_MANAGER:UnregisterCallback("SceneStateChanged", SDC.WWCore)
end
--To unbind/rebind the key for interact
function SDC.Key(IsUnbind)
  if SDC.CV.Key[1] then --Need to restore keybind
    for i = 1, 4 do
      CallSecureProtected("BindKeyToAction", unpack(SDC.CV.Key[i]))
    end
    SDC.CV.Key = {}
  else
    if not IsUnbind then return end
    for i = 1, 4 do
      local k1, k2, k3, k4, k5 = GetActionBindingInfo(1, 5, 1, i)
      SDC.CV.Key[i] = {1, 5, 1, i, k1, k2, k3, k4, k5}
    end
    CallSecureProtected("UnbindAllKeysFromAction", 1, 5, 1)
  end
end