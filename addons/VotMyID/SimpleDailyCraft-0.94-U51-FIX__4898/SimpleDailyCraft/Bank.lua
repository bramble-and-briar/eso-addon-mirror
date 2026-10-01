local SDC = SimpleDailyCraft
--Connect to quest
SDC.BankTarget = {--[[
  [1] = {
    [1] = ItemId,
    [2] = NumNeed,
    [3] = journalQuestIndex,
    [4] = conditionIndex,
  },
]]}
SDC.Banking = false

--Compatibility with PA
SDC.BankTargetType = {--[[
  [Craft Type] = true
]]}

---------------------
----Tool function----
---------------------

local function ToLink(Id)
  return "|H0:item:"..Id..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

local function ShouldOpenBank(Report)
  local Should = false
  --Anything can take?
  for i = 1, #SDC.BankTarget do
    local Table = SDC.BankItemScan(SDC.BankTarget[i][1], SDC.BankTarget[i][3], SDC.BankTarget[i][4])
    if Table["TotalNum"] >= SDC.BankTarget[i][2] then 
      Should = true
    else
      if Report then SDC.DD(3.1, {ToLink(SDC.BankTarget[i][1])}) end
    end
  end
  return Should
end

-----------------
----Bank Part----
-----------------

--Core for bank work
function SDC.BankCore(scene, _, newstate) --Callback: SceneStateChanged
  --Check Setting
  if not SDC.SV.Bank then return end
  --Check State
  if newstate ~= SCENE_SHOWN then return end
  
  --Interact Part
  if scene.name == "interact" then
    local Type
    --Auto open bank
    if SCENE_MANAGER:IsShowing("interact") then
      local control = WINDOW_MANAGER:GetControlByName("ZO_ChatterOption1")
      Type = control.optionType
    else
      if not SCENE_MANAGER:IsShowing("gamepadInteract") then return end
      Type = GAMEPAD_INTERACTION.itemList.dataList[1].optionType
    end
    --Bank Type
    if Type == 1200 and ShouldOpenBank(true) then
      if IsInteractingWithMyAssistant() then
        if not SDC.SV.OpenBankAssistant then return end
      else
        if not SDC.SV.OpenBank then return end
      end
      SelectChatterOption(1)
    end
    return
  end
  
  --Bank Part
  if scene.name == "bank" then
    if ShouldOpenBank(false) then
      --Something can take
      SDC.Banking = true
      SDC.BankProcess()
    else
      return
    end
  end
end

--Take item from bank
local itemTaked = {}
function SDC.BankProcess()
  --Check Setting
  if not SDC.SV.Bank then 
    SDC.Banking = false
    return
  end
  
  --Check Done or Nothing can take
  if SDC.BankTarget == {} or not ShouldOpenBank(false) then
    --Stop Banking
    SDC.Banking = false
    SDC.DD(9, {})
    --Close bank if set and really take something
    if SDC.SV.CloseBank and itemTaked ~= {} then
      SCENE_MANAGER:Hide("bank")
      SCENE_MANAGER:Hide("gamepad_banking")
    end
    --Push the remain of item taken
    for k, Link in pairs(itemTaked) do
      local _, count = GetItemLinkStacks(Link) --Item left in bank for each kind of link
      SDC.DD(1.2, {Link, count})
    end
    itemTaked = {}
    return
  end
  
  --At least one free slot ?
  if GetNumBagFreeSlots(1) == 0 then
    SDC.DD(8, {})
    --Stop Banking
    SDC.Banking = false
    return
  end

  --Take What
  for i = 1, #SDC.BankTarget do
    --Initial
    local itemId, numNeed, qIndex, cIndex = unpack(SDC.BankTarget[i])
    local bankItem = SDC.BankItemScan(itemId, qIndex, cIndex)
    --Check Number
    if bankItem["TotalNum"] >= numNeed then
      local bankId, bankSlot, itemLink, bankNum = unpack(bankItem["Info"][1])
      local numTake = math.min(numNeed, bankNum)
      --Stack or new slot
      if IsItemLinkStackable(itemLink) and GetItemLinkStacks(itemLink) > 0 then
        for bagSlot = 0, GetBagSize(1) do 
          if itemLink == GetItemLink(1, bagSlot) then
            CallSecureProtected("RequestMoveItem", bankId, bankSlot, 1, bagSlot, numTake)
            itemTaked[itemLink] = itemLink
            return
          end
        end
      else
        CallSecureProtected("RequestMoveItem", bankId, bankSlot, 1, FindFirstEmptySlotInBag(1), numTake)
        itemTaked[itemLink] = itemLink
        return
      end
    end
  end
end

--ItemId and quest index to check target item info
function SDC.BankItemScan(ItemId, a, b) 
  local Table = {
    ["TotalNum"] = 0,
    ["Info"] = {
      --{BagId, SlotId, Link, Num},
      },
    }
  --Look in Bank
  for i = 0, GetBagSize(2) do
    if GetItemId(2, i) == ItemId and DoesItemLinkFulfillJournalQuestCondition(GetItemLink(2, i), a, 1, b, GetItemCreatorName(2, i) == GetUnitName("player")) then
      local count = select(2, GetItemInfo(2, i))
      Table["TotalNum"] = Table["TotalNum"] + count
      table.insert(Table["Info"], {2, i, GetItemLink(2, i), count})
    end
  end
  --Look in PlusBank
  if IsESOPlusSubscriber() then 
    for i = 0, GetBagSize(6) do
      if GetItemId(6, i) == ItemId and DoesItemLinkFulfillJournalQuestCondition(GetItemLink(6, i), a, 1, b, GetItemCreatorName(6, i) == GetUnitName("player")) then
        local count = select(2, GetItemInfo(6, i))
        Table["TotalNum"] = Table["TotalNum"] + count
        table.insert(Table["Info"], {6, i, GetItemLink(6, i), count})
      end
    end
  end
  
  --Nothing find
  if Table["TotalNum"] == 0 then return Table end
  
  --Resort by num
  table.sort(Table["Info"], 
    function(a, b)
      return a[4] < b[4]
    end
  )
  return Table
end