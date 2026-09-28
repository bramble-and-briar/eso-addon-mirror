-- Local instances of Global tables --
local PA = PersonalAssistant
local PAC = PA.Constants
local PACO = PA.Consume
local PAHF = PA.HelperFunctions

-- ---------------------------------------------------------------------------------------------------------------------

local function NextPoison()

   local slotIndex = nil
   local maxedPoisonStacks = 0
   local minPoisonStacks = 9999999
   
   local PACOMenuFunctions = PA.MenuFunctions.PAConsume
   --Check if the functionality is turned on within the addon
   local smallStacksFirst = PACOMenuFunctions.getAutoConsumePoisonSmallStacksFirstSetting()
   local yourLevel = GetUnitLevel("player")
   
   local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
   if smallStacksFirst then
     for i, itemData in pairs(bagCache) do
        if itemData.itemType == ITEMTYPE_POISON and GetItemRequiredLevel(BAG_BACKPACK, i) <= yourLevel then
          local itemStacks = itemData.stackCount
          if itemStacks < minPoisonStacks and itemStacks ~= 0 then
             minPoisonStacks = itemStacks
             slotIndex = i
          end
        end
     end
  else
     for i, itemData in pairs(bagCache) do
        if itemData.itemType == ITEMTYPE_POISON and GetItemRequiredLevel(BAG_BACKPACK, i) <= yourLevel then
          local itemStacks = itemData.stackCount
          if itemStacks > maxedPoisonStacks then
             maxedPoisonStacks = itemStacks
             slotIndex = i
          end
        end
     end
  end
  
  return slotIndex
end

-- --------------------------------------------------------------------------------------------------------------------

local function CheckPoison()

    if not IsPlayerActivated() or IsCurrentCampaignVengeanceRuleset() then return end
	
	local level = GetUnitLevel("player")

	
	if IsUnitInCombat("player") then
		return
	else
		-- check if poison slots are equipped after combat
          local _, stack, _, _, _, _, _, _ = GetItemInfo(BAG_WORN, EQUIP_SLOT_POISON)
	      local _, backStack, _, _, _, _, _, _ = GetItemInfo(BAG_WORN, EQUIP_SLOT_BACKUP_POISON)

		  if stack and stack ~= 0 then
		      if backStack and backStack ~= 0 then
			  elseif level >= 15 then
                  local theNext = NextPoison()
			       if theNext then
				       local itemLink = PAHF.getFormattedItemLink(BAG_BACKPACK, theNext)
					   local itemLinkExt = PAHF.getIconExtendedItemLink(itemLink)
					   local stacks = GetSlotStackSize(BAG_BACKPACK, theNext)
				       EquipItem(BAG_BACKPACK, theNext, EQUIP_SLOT_BACKUP_POISON)
					   PACO.println(GetString(SI_PA_CHAT_CONSUME_POISON_BACKUP)..stacks.." x "..itemLinkExt)
				   end
			  end
		  else
              local theNext = NextPoison()
		      if theNext then
				   local itemLink = PAHF.getFormattedItemLink(BAG_BACKPACK, theNext)
				   local itemLinkExt = PAHF.getIconExtendedItemLink(itemLink)
				   local stacks = GetSlotStackSize(BAG_BACKPACK, theNext)
			       EquipItem(BAG_BACKPACK, theNext, EQUIP_SLOT_POISON)
				   PACO.println(GetString(SI_PA_CHAT_CONSUME_POISON_MAIN)..stacks.." x "..itemLinkExt)
			  end
		  end
		
	end
	
end


-- ---------------------------------------------------------------------------------------------------------------------
-- Export
PA.Consume = PA.Consume or {}
PA.Consume.CheckPoison = CheckPoison
