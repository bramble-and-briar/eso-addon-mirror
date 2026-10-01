-----------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY ASSISTANT
-----------------------------------------------------------------------------------------------------------------------------------
IA_InventoryAssistant = ZO_Object:Subclass ( )
IA_InventoryAssistant.name = "InventoryAssistant"
IA_InventoryAssistant.version = "1.20.260919-beta"
-----------------------------------------------------------------------------------------------------------------------------------
-- DEFAULT SETTINGS
-----------------------------------------------------------------------------------------------------------------------------------
IA_InventoryAssistant.defaults = {
  inventoryAssistantWindowX = 480.0,
  inventoryAssistantWindowY = 110.0,
  inventoryAssistantWindowWidth = 625.0,
  inventoryAssistantWindowHeight = 865.0,
  characters = { },
  inventories = { },
  guildBankId = 0,
  guildBankSnapshotId = 0,
  actionQueue = { 
    lock = { },
    unlock = { },
  },
  onlyUncollected = false,
  onlyDuplicates = false,
  onlyMarkedItems = false,
  onlyLoots = false,
  groupLoots = true,
  lootHistoryEnabled = false,
  lootHistoryLocked = false,
  lootHistoryX = 1200.0,
  lootHistoryY = 500.0,
  lootHistoryMaxEntries = 6,
  lootHistoryNewestOnTop = true,
  lootHistoryRightAligned = false,
  showCrafted = true,
  showBuyable = true,
  showBound = true,
  showMonsterSets = true,
  showFCOISGearSetMarkers = true,
  showFCOISDynamicMarkers = true,
  showNonSetItems = true,
  showItemLevels = true,
  showEnchants = true,
  
  bagNameWidth = 250,
}
-----------------------------------------------------------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------
local EH = LibEventHandler
local menu = LibCustomMenu
local LAM = LibAddonMenu2
-----------------------------------------------------------------------------------------------------------------------------------
local METRICS_ENABLED = false
-----------------------------------------------------------------------------------------------------------------------------------
local m_strformat = string.format
local zo_strformat = zo_strformat
local zo_getSafeId64Key = zo_getSafeId64Key
local GetString = GetString
local GetInterfaceColor = GetInterfaceColor
local GetItemInstanceId = GetItemInstanceId
local GetItemUniqueId = GetItemUniqueId
local GetItemBoPTimeRemainingSeconds = GetItemBoPTimeRemainingSeconds
local GetItemType = GetItemType
local GetItemInfo = GetItemInfo
local GetItemLink = GetItemLink
local GetItemLinkSetInfo = GetItemLinkSetInfo
local GetItemLinkItemId = GetItemLinkItemId
local GetItemLinkItemType = GetItemLinkItemType
local GetItemLinkInfo = GetItemLinkInfo
local GetItemLinkQuality = GetItemLinkQuality
local GetItemLinkName = GetItemLinkName
local GetItemLinkEquipType = GetItemLinkEquipType
local GetItemLinkTraitInfo = GetItemLinkTraitInfo
local GetItemLinkArmorType = GetItemLinkArmorType
local GetItemLinkWeaponType = GetItemLinkWeaponType
local GetItemLinkRequiredLevel = GetItemLinkRequiredLevel
local GetItemLinkRequiredChampionPoints = GetItemLinkRequiredChampionPoints
local GetItemLinkBindType = GetItemLinkBindType
local GetItemReconstructionCurrencyOptionCost = GetItemReconstructionCurrencyOptionCost
local GetNumItemSetCollectionPieces = GetNumItemSetCollectionPieces
local GetNumItemSetCollectionSlotsUnlocked = GetNumItemSetCollectionSlotsUnlocked
local GetItemSetCollectionPieceInfo = GetItemSetCollectionPieceInfo
local GetItemSetCollectionPieceItemLink = GetItemSetCollectionPieceItemLink
local IsItemSetCollectionSlotUnlocked = IsItemSetCollectionSlotUnlocked
local IsItemPlayerLocked = IsItemPlayerLocked
local IsItemStolen = IsItemStolen
local IsItemSetCollectionPieceUnlocked = IsItemSetCollectionPieceUnlocked
local IsItemLinkSetCollectionPiece = IsItemLinkSetCollectionPiece
local IsItemLinkCrafted = IsItemLinkCrafted
-----------------------------------------------------------------------------------------------------------------------------------
local metrics = { }
local function stopwatch_start ( info )
  if METRICS_ENABLED then 
    if not metrics [ info ] then 
      metrics [ info ] = GetGameTimeSeconds ( )
    end
  end
end
local function stopwatch_stop ( info )
  if METRICS_ENABLED then 
    local start = metrics [ info ]
    if start then 
      local elapsed = GetGameTimeSeconds ( ) - start
      d ( m_strformat ( "%s : %f ms", info, elapsed * 1000 ) )
      metrics [ info ] = nil 
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local INT_MAX = 2^32
local SIGNED_INT_MAX = INT_MAX / 2 - 1
-- converts unsigned itemId to signed, don't touch unique ids
local function SignItemId ( itemId )
  if type ( itemId )  == "number" and itemId > SIGNED_INT_MAX then
      itemId = itemId - INT_MAX
  end
  return itemId
end
-----------------------------------------------------------------------------------------------------------------------------------
local ITEMTYPE_NONE = ITEMTYPE_NONE
local function ScanBagSlot ( bagId, slotIndex, epoch, charId )
  local itemType = GetItemType ( bagId, slotIndex )
  local bopTimeRemaining = GetItemBoPTimeRemainingSeconds ( bagId, slotIndex )
  local _, stackCount = GetItemInfo ( bagId, slotIndex )

  local link = GetItemLink ( bagId, slotIndex )
  local isSetItem = GetItemLinkSetInfo ( link )
    
  if itemType ~= ITEMTYPE_NONE then 
    local item = {
      charId = charId,
      bagId = bagId,
      slotIndex = slotIndex,
      itemId = SignItemId ( GetItemInstanceId ( bagId, slotIndex ) ),
      uniqueId = zo_getSafeId64Key ( GetItemUniqueId ( bagId, slotIndex ) ),
      link = link,
      locked = IsItemPlayerLocked ( bagId, slotIndex ),
      stolen = IsItemStolen ( bagId, slotIndex ),
      bopTimeEnds = bopTimeRemaining > 0 and epoch + bopTimeRemaining or 0,
      stackCount = stackCount,
    }
    return item
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function ApplyQueuedItemActions ( item, actionQueue )
  if actionQueue and actionQueue.lock [ item.uniqueId ] and item.bagId and item.slotIndex then
    SetItemIsPlayerLocked ( item.bagId, item.slotIndex, true )
    if IsItemPlayerLocked ( item.bagId, item.slotIndex ) == true then
      actionQueue.lock [ item.uniqueId ] = nil
      item.locked = true
    end
--  d ( m_strformat( "%s  |c666666(%s)|r  lock applied", item.link, item.traitTypeName ) )
  end
  if actionQueue and actionQueue.unlock [ item.uniqueId ] and item.bagId and item.slotIndex then
    SetItemIsPlayerLocked ( item.bagId, item.slotIndex, false )
    if IsItemPlayerLocked ( item.bagId, item.slotIndex ) == false then
      actionQueue.unlock [ item.uniqueId ] = nil
      item.locked = false
    end
--  d ( m_strformat( "%s  |c666666(%s)|r  unlock applied", item.link, item.traitTypeName ) )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function ScanBag ( inventory, bagId, charId, actionQueue )
  local epoch = GetTimeStamp ( )

  if bagId >= BAG_HOUSE_BANK_ONE and bagId <= BAG_HOUSE_BANK_TEN and not IsOwnerOfCurrentHouse ( ) then return end 
  
  if bagId == BAG_GUILDBANK then
    local index = #inventory + 1
    for slotIndex in ZO_IterateBagSlots ( bagId ) do
      local item = ScanBagSlot ( bagId, slotIndex, epoch, charId )
      if item then 
--        table.insert ( inventory, item )
        inventory [ index ] = item
        index = index + 1
      end
    end
  else
    local index = #inventory + 1
    local bagSize = GetBagSize ( bagId ) or 0
    for slotIndex = 0, bagSize - 1 do
      local item = ScanBagSlot ( bagId, slotIndex, epoch, charId )
      if item then 
        ApplyQueuedItemActions ( item, actionQueue )
--        table.insert ( inventory, item )
        inventory [ index ] = item
        index = index + 1
      end
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function BuildInventoryIndex ( inventory )
  local index = { }
  for arrayIndex, item in ipairs ( inventory ) do
    if not index [ item.bagId ] then
      index [ item.bagId ] = { }
    end
    index [ item.bagId ] [ item.slotIndex ] = arrayIndex
  end
  return index
end
-----------------------------------------------------------------------------------------------------------------------------------
local function ScanGroupMemberNames ( groupMembers )
  local groupSize = GetGroupSize ( )
  for i=1, groupSize do
      local characterName = GetUnitName ( "group" .. i )
      local displayName = GetUnitDisplayName ( "group" .. i )
      if characterName and displayName then
        groupMembers [ characterName ] = { characterName = characterName, displayName = displayName, bagName = characterName .. displayName }
      end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
-- This function is borrowed from Rhyono & votan's excellent EnchantedQuality addon
local subIdToQuality = { }
local function GetEnchantQuality ( itemLink )
	local itemId, itemIdSub, enchantSub = itemLink:match ( "|H[^:]+:item:([^:]+):([^:]+):[^:]+:[^:]+:([^:]+):" )
	if not itemId then return 0 end
	enchantSub = tonumber ( enchantSub )
	if enchantSub == 0 and not IsItemLinkCrafted ( itemLink ) then
		local hasSet = GetItemLinkSetInfo ( itemLink, false )
		-- For non-crafted sets, the "built-in" enchantment has the same quality as the item itself
		if hasSet then enchantSub = tonumber ( itemIdSub ) end
	end
	if enchantSub > 0 then
		local quality = subIdToQuality [ enchantSub ]
		if not quality then
			-- Create a fake itemLink to get the quality from built-in function
			local itemLink = m_strformat ( "|H1:item:%i:%i:50:0:0:0:0:0:0:0:0:0:0:0:0:1:1:0:0:10000:0|h|h", itemId, enchantSub )
			quality = GetItemLinkQuality ( itemLink )
			subIdToQuality [ enchantSub ] = quality
		end
		return quality
	end
	return 0
end
-----------------------------------------------------------------------------------------------------------------------------------
local idToEnchantText = { }
local getEnchantText = function ( itemLink )
	local itemId, enchantId = itemLink:match ( "|H[^:]+:item:([^:]+):[^:]+:[^:]+:([^:]+):" )
  itemId = tonumber ( itemId )
  enchantId = tonumber ( enchantId )
  if enchantId == 0 then
    enchantId = itemId
  end
  local cachedText = idToEnchantText [ enchantId ]
  if enchantId and not cachedText then 
    local _, text, _ = GetItemLinkEnchantInfo ( itemLink )
    idToEnchantText [ enchantId ] = text
    cachedText = text
  end
  return cachedText
end
-- Armor Enchants
local ArmorEnchants = {
  [ getEnchantText ( "|H0:item:69893:369:50:26580:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Health", icon = "/esoui/art/icons/enchantment_armor_healthboost.dds" },
  [ getEnchantText ( "|H0:item:69893:369:50:26582:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Magicka", icon = "/esoui/art/icons/enchantment_armor_magickaboost.dds" },
  [ getEnchantText ( "|H0:item:69893:369:50:26588:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Stamina", icon = "/esoui/art/icons/enchantment_armor_staminaboost.dds" },
  [ getEnchantText ( "|H0:item:69893:369:50:68343:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Prismatic", icon = "/esoui/art/icons/crafting_enchantment_036.dds" },
}
-- Weapon Enchants
local WeaponEnchants = {
  [ getEnchantText ( "|H0:item:69775:369:50:43573:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Absorb Health", icon = "/esoui/art/icons/enchantment_weapon_healthabsorbtion.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:45868:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Absorb Magicka", icon = "/esoui/art/icons/enchantment_weapon_magickaabsorbtion.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:45867:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Absorb Stamina", icon = "/esoui/art/icons/enchantment_weapon_staminaabsorption.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26845:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Crushing", icon = "/esoui/art/icons/enchantment_weapon_reducearmor.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:45869:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Oblivion", icon = "/esoui/art/icons/enchantment_weapon_decreasehealth.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26848:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Flame", icon = "/esoui/art/icons/enchantment_weapon_fireessence.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26841:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Disease", icon = "/esoui/art/icons/enchantment_weapon_diseaseessence.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:5365:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Frost", icon = "/esoui/art/icons/enchantment_weapon_frostessence.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:5366:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Hardening", icon = "/esoui/art/icons/enchantment_weapon_damageshield.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26587:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Poison", icon = "/esoui/art/icons/enchantment_weapon_poisonessence.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:68344:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Prismatic", icon = "/esoui/art/icons/crafting_enchantment_035.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26844:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Shock", icon = "/esoui/art/icons/enchantment_weapon_shockessence.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:26591:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Weakening", icon = "/esoui/art/icons/enchantment_weapon_weakeningenchant.dds" },
  [ getEnchantText ( "|H0:item:69775:369:50:54484:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h" ) ] = { text = "Weapon Damage", icon = "/esoui/art/icons/enchantment_weapon_berserking.dds" },
}
-- Jewelry Enchants
local JewelryEnchants = {
  [ getEnchantText ( "|H0:item:69276:363:50:45872:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Bashing", icon = "/esoui/art/icons/enchantment_jewelry_increasebashdamage.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45885:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Decrease Physical Harm", icon = "/esoui/art/icons/enchantment_jewelry_decreasephysicaldamage.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45886:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Decrease Spell Harm", icon = "/esoui/art/icons/enchantment_jewelry_decreasespelldamage.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26847:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Disease Resist", icon = "/esoui/art/icons/enchantment_jewelry_diseaseresist.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26849:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Flame Resist", icon = "/esoui/art/icons/enchantment_jewelry_fireresist.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:5364:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Frost Resist", icon = "/esoui/art/icons/enchantment_jewelry_frostresist.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26581:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Health Recovery", icon = "/esoui/art/icons/enchantment_jewelry_healthregen.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45884:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Spell Damage", icon = "/esoui/art/icons/enchantment_jewelry_increasespelldamage.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45883:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Weapon Damage", icon = "/esoui/art/icons/enchantment_jewelry_increaseweapondamage.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26583:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Magicka Recovery", icon = "/esoui/art/icons/enchantment_jewelry_magickaregen.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26586:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Poison Resist", icon = "/esoui/art/icons/enchantment_jewelry_poisonresist.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45874:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Potion Boost", icon = "/esoui/art/icons/enchantment_jewelry_potionpotency.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45875:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Potion Speed", icon = "/esoui/art/icons/enchantment_jewelry_increasepotionspeed.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45871:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Reduce Stamina Cost", icon = "/esoui/art/icons/enchantment_jewelry_reducefeatcosts.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45870:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Reduce Spell Cost", icon = "/esoui/art/icons/enchantment_jewelry_reducespellcosts.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:45873:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Reduce Bash Cost", icon = "/esoui/art/icons/enchantment_jewelry_decreasebashblockcost.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:43570:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Shock Resist", icon = "/esoui/art/icons/enchantment_jewelry_shockresist.dds" },
  [ getEnchantText ( "|H0:item:69276:363:50:26589:369:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h" ) ] = { text = "Stamina Recovery", icon = "/esoui/art/icons/enchantment_jewelry_staminaregen.dds" },
}
-----------------------------------------------------------------------------------------------------------------------------------
local sortOrderTable1 = {
  [EQUIP_TYPE_HEAD]              =  10,
  [EQUIP_TYPE_SHOULDERS]         =  20,
  [EQUIP_TYPE_CHEST]             =  30,
  [EQUIP_TYPE_LEGS]              =  40,
  [EQUIP_TYPE_WAIST]             =  50,
  [EQUIP_TYPE_HAND]              =  60,
  [EQUIP_TYPE_FEET]              =  70,
  [EQUIP_TYPE_NECK]              =  80,
  [EQUIP_TYPE_RING]              =  81,
}
local sortOrderTable2 = {
  [ARMORTYPE_LIGHT]              = 1,
  [ARMORTYPE_MEDIUM]             = 2,
  [ARMORTYPE_HEAVY]              = 3,
}
local sortOrderTable3 = {
  [WEAPONTYPE_FIRE_STAFF]        = 500,
  [WEAPONTYPE_LIGHTNING_STAFF]   = 501,
  [WEAPONTYPE_FROST_STAFF]       = 502,
  [WEAPONTYPE_HEALING_STAFF]     = 503,
  [WEAPONTYPE_BOW]               = 510,
  [WEAPONTYPE_AXE]               = 520,
  [WEAPONTYPE_HAMMER]            = 521,
  [WEAPONTYPE_SWORD]             = 522,
  [WEAPONTYPE_DAGGER]            = 523,
  [WEAPONTYPE_SHIELD]            = 530,
  [WEAPONTYPE_TWO_HANDED_AXE]    = 540,
  [WEAPONTYPE_TWO_HANDED_HAMMER] = 541,
  [WEAPONTYPE_TWO_HANDED_SWORD]  = 542,
}
-----------------------------------------------------------------------------------------------------------------------------------
local cache = { }
local function LoadInventory ( inventory, static, sets, materials, others )
  for i, v in ipairs ( inventory ) do
    local slot = cache [ v.uniqueId ]
    
    if not slot then
      local link = v.link
      local itemType, specializedItemType = GetItemLinkItemType ( link )
      local name = GetItemLinkName ( link )
      local quality = GetItemLinkQuality ( link )
      local icon, _, _, equipType, itemStyleId = GetItemLinkInfo ( link )
      local isSetItem, setName, numBonuses, numEquipped, maxEquipped, setId = GetItemLinkSetInfo ( link, false )
      local traitType = GetItemLinkTraitInfo ( link )
      local armorType = GetItemLinkArmorType ( link )
      local weaponType = GetItemLinkWeaponType ( link )
      
      slot = {
        itemId = v.itemId,
        uniqueId = v.uniqueId,
        link = v.link,
        bopTimeEnds = v.bopTimeEnds,
        
        itemType = itemType,
        specializedItemType = specializedItemType,
        
        icon = icon,
        equipType = equipType,
        itemStyleId = itemStyleId,
        quality = quality,
        name = name,
        
        isSetItem = isSetItem,
        setName = setName,
        numBonuses = numBonuses,
        numEquipped = numEquipped,
        maxEquipped = maxEquipped,
        setId = setId,
      
        equipTypeName = GetString ( "SI_EQUIPTYPE", equipType ) or "",
        traitType = traitType,
        traitTypeName = GetString ( "SI_ITEMTRAITTYPE", traitType ) or "",
        armorType = armorType,
        armorTypeName = GetString ( "SI_ARMORTYPE", armorType ) or "",
        weaponType = weaponType,
        weaponTypeName = GetString ( "SI_WEAPONTYPE", weaponType ) or "",
        
        requiredLevel = GetItemLinkRequiredLevel ( link ),
        requiredChampionPoints = GetItemLinkRequiredChampionPoints ( link ),
        
        sortOrder = ( sortOrderTable1 [ equipType ] or 0 ) + ( sortOrderTable2 [ armorType ] or 0 ) + ( sortOrderTable3 [ weaponType ] or 0 ),
      }
      
      if slot.itemType == ITEMTYPE_ARMOR and slot.equipType ~= EQUIP_TYPE_NECK and slot.equipType ~= EQUIP_TYPE_RING then
        slot.category = "Armor"
        slot.subcategory = m_strformat ( "%s %s", slot.armorTypeName, slot.equipTypeName )
      elseif slot.itemType == ITEMTYPE_ARMOR and ( slot.equipType == EQUIP_TYPE_NECK or slot.equipType == EQUIP_TYPE_RING ) then
        slot.category = "Jewellery"
        slot.subcategory = slot.equipTypeName
      elseif slot.itemType == ITEMTYPE_WEAPON then
        slot.category = "Weapon"
        slot.subcategory = m_strformat ( "%s %s", slot.equipTypeName, slot.weaponTypeName )
      end
      local levelKey = m_strformat ( "%d:%d", slot.requiredLevel or 0, slot.requiredChampionPoints or 0 )
      if slot.category == "Armor" then
        slot.itemkey = m_strformat ( "Armor:%d:%d:%s", slot.equipType or 0, slot.armorType or 0, levelKey )
      elseif slot.category == "Jewellery" then
        slot.itemkey = m_strformat ( "Jewellery:%d:%s", slot.equipType or 0, levelKey )
      elseif slot.category == "Weapon" then
        slot.itemkey = m_strformat ( "Weapon:%d:%d:%s", slot.equipType or 0, slot.weaponType or 0, levelKey )
      else
        slot.itemkey = m_strformat ( "%s:%s:%s", slot.category or "", slot.subcategory or "", levelKey )
      end
      slot.setName = zo_strformat ( "<<1>>", slot.setName )
      
      slot.charId = v.charId
      slot.bagId = v.bagId
      slot.slotIndex = v.slotIndex
      slot.locked = v.locked
      slot.stackCount = v.stackCount
      slot.stolen = v.stolen

      local enchant = ""
      if ( slot.armorType ~= ARMORTYPE_NONE or slot.weaponType ~= WEAPONTYPE_NONE or slot.equipType == EQUIP_TYPE_RING or slot.equipType == EQUIP_TYPE_NECK ) then
        local y = getEnchantText ( v.link )
        if y then 
          local x = ArmorEnchants [ y ] or WeaponEnchants [ y ] or JewelryEnchants [ y ]
          if x then
            local r,g,b,a = GetInterfaceColor ( INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, GetEnchantQuality ( slot.link ) )
            enchant = m_strformat( "  |c%02X%02X%02X(%s)|r", zo_floor ( r * 255 ) , zo_floor ( g * 255 ), zo_floor ( b * 255 ), x.text )
          end
        end
      end
      slot.enchant = enchant
      
      if v.uniqueId then 
        cache [ v.uniqueId ] = slot
      end
    end
    
    if not static then 
      slot.charId = v.charId
      slot.bagId = v.bagId
      slot.slotIndex = v.slotIndex
      slot.locked = v.locked
      slot.stackCount = v.stackCount
      slot.stolen = v.stolen

      slot.quality = GetItemLinkQuality ( slot.link )      

      local enchant = ""
      if ( slot.armorType ~= ARMORTYPE_NONE or slot.weaponType ~= WEAPONTYPE_NONE or slot.equipType == EQUIP_TYPE_RING or slot.equipType == EQUIP_TYPE_NECK ) then
        local y = getEnchantText ( v.link )
        if y then 
          local x = ArmorEnchants [ y ] or WeaponEnchants [ y ] or JewelryEnchants [ y ]
          if x then
            local r,g,b,a = GetInterfaceColor ( INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, GetEnchantQuality ( slot.link ) )
            enchant = m_strformat( "  |c%02X%02X%02X(%s)|r", zo_floor ( r * 255 ) , zo_floor ( g * 255 ), zo_floor ( b * 255 ), x.text )
          end
        end
      end
      slot.enchant = enchant
    end
    
    if slot.isSetItem then 
      if not sets [ slot.setName ] then
        table.insert ( sets, slot.setName )
        sets [ slot.setName ] = { }
      end
      table.insert ( sets [ slot.setName ], slot )
      if not sets [ slot.setName ][ slot.itemkey ] then
        sets [ slot.setName ][ slot.itemkey ] = { }
      end
      table.insert ( sets [ slot.setName ] [ slot.itemkey ], slot )
    else
      local itemTypeText = GetString ( "SI_ITEMTYPE", slot.itemType ) or ""
      local itemSubTypeText = GetString ( "SI_SPECIALIZEDITEMTYPE", slot.specializedItemType ) or ""
      local category = "__UNKNOWN__"
      if ( itemTypeText == itemSubTypeText or itemSubTypeText == "" ) then
        category = itemTypeText
      else
        category = m_strformat ( "%s - %s", itemTypeText , itemSubTypeText )
      end
      if not others [ category ] then
        table.insert ( others, category )
        others [ category ] = { }
      end
      table.insert ( others [ category ], slot )
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function GetSetCount ( sets )
  sets = sets or { }
  return #sets
end
-----------------------------------------------------------------------------------------------------------------------------------
local function GetItemCount ( sets, allsets )
  sets = sets or { }
  allsets = allsets or { }
  local count = 0
  for i,v in ipairs ( sets ) do
    count = count + #allsets [ v ]
  end
  return count
end
-----------------------------------------------------------------------------------------------------------------------------------
local function GetEquipSlotData ( setitems )
  setitems = setitems or { }
  local setId = nil
  local setName = nil
  local head = 0
  local headIcon = "esoui/art/characterwindow/gearslot_head.dds"
  local shoulders = 0
  local shouldersIcon = "esoui/art/characterwindow/gearslot_shoulders.dds"
  local hands = 0
  local handsIcon = "esoui/art/characterwindow/gearslot_hands.dds"
  local legs = 0
  local legsIcon = "esoui/art/characterwindow/gearslot_legs.dds"
  local chest = 0
  local chestIcon  = "esoui/art/characterwindow/gearslot_chest.dds"
  local belt = 0
  local beltIcon = "esoui/art/characterwindow/gearslot_belt.dds"
  local feet = 0
  local feetIcon = "esoui/art/characterwindow/gearslot_feet.dds"
  local neck = 0
  local neckIcon  = "esoui/art/characterwindow/gearslot_neck.dds"
  local ring = 0
  local ringIcon = "esoui/art/characterwindow/gearslot_ring.dds"
  local mainHand = 0
  local mainHandIcon = "esoui/art/characterwindow/gearslot_mainhand.dds"
  local offHand = 0
  local offHandIcon = "esoui/art/characterwindow/gearslot_offhand.dds"
  for i, v in ipairs ( setitems ) do
    if not setId and type ( v.setId ) == "number" and v.setId > 0 then
      setId = v.setId
    end
    if not setName and v.setName and v.setName ~= "" then
      setName = v.setName
    end

    if type ( v.bagId ) == "number" then
      if v.equipType == EQUIP_TYPE_HEAD then
        head = head + 1
        headIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_SHOULDERS then
        shoulders = shoulders + 1
        shouldersIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_HAND then
        hands = hands + 1
        handsIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_LEGS then
        legs = legs + 1
        legsIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_CHEST then
        chest = chest + 1
        chestIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_WAIST then
        belt = belt + 1
        beltIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_FEET then
        feet = feet + 1
        feetIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_NECK then
        neck = neck + 1
        neckIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_RING then
        ring = ring + 1
        ringIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_MAIN_HAND or v.equipType == EQUIP_TYPE_ONE_HAND or v.equipType == EQUIP_TYPE_TWO_HAND then
        mainHand = mainHand + 1
        mainHandIcon = v.icon
      elseif v.equipType == EQUIP_TYPE_OFF_HAND then
        offHand = offHand + 1
        offHandIcon = v.icon
      end
    end
  end
  return {
    setId = setId,
    setName = setName,
    head = head, headIcon = headIcon,
    shoulders = shoulders, shouldersIcon = shouldersIcon,
    hands = hands, handsIcon = handsIcon,
    legs = legs, legsIcon = legsIcon,
    chest = chest, chestIcon = chestIcon,
    belt = belt, beltIcon = beltIcon,
    feet = feet, feetIcon = feetIcon,
    neck = neck, neckIcon = neckIcon,
    ring = ring, ringIcon = ringIcon,
    mainHand = mainHand, mainHandIcon = mainHandIcon,
    offHand = offHand, offHandIcon = offHandIcon,
  }
end
-----------------------------------------------------------------------------------------------------------------------------------
local sortKeys = {
  setName = { tiebreaker = "sortOrder" },
  sortOrder = { tiebreaker = "quality", isNumeric = true },
  quality = { tiebreaker = "traitTypeName" },
  traitTypeName = { tiebreaker = "name" },
  name = { tiebreaker = "bagId" },
  bagId = { },
}
local sortFunction = function( entry1, entry2 )
  return ZO_TableOrderingFunction ( entry1, entry2, "setName", sortKeys, ZO_SORT_ORDER_UP )
end
local sortKeys2 = {
  setName = { tiebreaker = "quality" },
  quality = { tiebreaker = "traitTypeName" },
  traitTypeName = { tiebreaker = "name" },
  name = { tiebreaker = "bagId" },
  bagId = { },
}
local sortFunction2 = function( entry1, entry2 )
  return ZO_TableOrderingFunction ( entry1, entry2, "setName", sortKeys2, ZO_SORT_ORDER_UP )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function AddOrderedUniqueValue ( bucket, seen, key, order, value )
  if not value or value == "" then return end
  if seen [ key ] then return end

  seen [ key ] = true
  table.insert ( bucket, { order = order, value = value } )
end

local function GetSetReconstructionTransmuteCost ( setId )
  if not setId or setId == 0 then return nil end

  local cost = GetItemReconstructionCurrencyOptionCost ( setId, CURT_CHAOTIC_CREATIA )
  return cost > 0 and cost or nil
end

local function BuildSetCollectionTooltipData ( itemLink )
  local isSetItem, _, _, _, _, setId = GetItemLinkSetInfo ( itemLink, false )
  if not isSetItem or not setId or setId == 0 then return nil end

  local numPieces = GetNumItemSetCollectionPieces ( setId )
  if not numPieces or numPieces == 0 then return nil end

  local groups = {
    { title = "Light Armor", items = { }, missing = { }, seen = { } },
    { title = "Medium Armor", items = { }, missing = { }, seen = { } },
    { title = "Heavy Armor", items = { }, missing = { }, seen = { } },
    { title = "Jewelry", items = { }, missing = { }, seen = { } },
    { title = "Weapons", items = { }, missing = { }, seen = { } },
  }

  local armorOrder = {
    [ EQUIP_TYPE_HEAD ] = 10,
    [ EQUIP_TYPE_SHOULDERS ] = 20,
    [ EQUIP_TYPE_CHEST ] = 30,
    [ EQUIP_TYPE_HAND ] = 40,
    [ EQUIP_TYPE_WAIST ] = 50,
    [ EQUIP_TYPE_LEGS ] = 60,
    [ EQUIP_TYPE_FEET ] = 70,
  }
  local jewelryOrder = {
    [ EQUIP_TYPE_NECK ] = 10,
    [ EQUIP_TYPE_RING ] = 20,
  }
  local weaponOrder = {
    [ WEAPONTYPE_DAGGER ] = 10,
    [ WEAPONTYPE_AXE ] = 20,
    [ WEAPONTYPE_HAMMER ] = 30,
    [ WEAPONTYPE_SWORD ] = 40,
    [ WEAPONTYPE_TWO_HANDED_AXE ] = 50,
    [ WEAPONTYPE_TWO_HANDED_HAMMER ] = 60,
    [ WEAPONTYPE_TWO_HANDED_SWORD ] = 70,
    [ WEAPONTYPE_BOW ] = 80,
    [ WEAPONTYPE_HEALING_STAFF ] = 90,
    [ WEAPONTYPE_FIRE_STAFF ] = 100,
    [ WEAPONTYPE_FROST_STAFF ] = 110,
    [ WEAPONTYPE_LIGHTNING_STAFF ] = 120,
    [ WEAPONTYPE_SHIELD ] = 130,
  }

  local function GetWeaponLabel ( equipType, weaponType )
    local baseLabel = GetString ( "SI_WEAPONTYPE", weaponType ) or ""
    if weaponType == WEAPONTYPE_AXE
       or weaponType == WEAPONTYPE_HAMMER
       or weaponType == WEAPONTYPE_SWORD
       or weaponType == WEAPONTYPE_TWO_HANDED_AXE
       or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER
       or weaponType == WEAPONTYPE_TWO_HANDED_SWORD then
      if equipType == EQUIP_TYPE_TWO_HAND then
        return "2H " .. baseLabel
      else
        return "1H " .. baseLabel
      end
    end
    return baseLabel
  end

  local function AddGroupItem ( groupIndex, key, order, value, unlocked )
    local group = groups [ groupIndex ]
    if not group then return end
    local target = unlocked and group.items or group.missing
    AddOrderedUniqueValue ( target, group.seen, key, order, value )
  end

  for i = 1, numPieces do
    local pieceId, slot = GetItemSetCollectionPieceInfo ( setId, i )
    if pieceId and slot then
      local pieceLink = GetItemSetCollectionPieceItemLink ( pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE )
      local equipType = GetItemLinkEquipType ( pieceLink )
      local pieceItemType = GetItemLinkItemType ( pieceLink )
      local armorType = GetItemLinkArmorType ( pieceLink )
      local weaponType = GetItemLinkWeaponType ( pieceLink )
      local unlocked = IsItemSetCollectionSlotUnlocked ( setId, slot )

      if pieceItemType == ITEMTYPE_ARMOR and armorOrder [ equipType ] then
        local armorGroupIndex = armorType == ARMORTYPE_LIGHT and 1 or armorType == ARMORTYPE_MEDIUM and 2 or armorType == ARMORTYPE_HEAVY and 3 or nil
        if armorGroupIndex then
          local label = GetString ( "SI_EQUIPTYPE", equipType ) or ""
          AddGroupItem ( armorGroupIndex, m_strformat ( "A:%d:%d", armorType, equipType ), armorOrder [ equipType ], label, unlocked )
        end
      elseif pieceItemType == ITEMTYPE_ARMOR and jewelryOrder [ equipType ] then
        local label = GetString ( "SI_EQUIPTYPE", equipType ) or ""
        AddGroupItem ( 4, m_strformat ( "J:%d", equipType ), jewelryOrder [ equipType ], label, unlocked )
      elseif pieceItemType == ITEMTYPE_WEAPON and weaponType ~= WEAPONTYPE_NONE then
        local label = GetWeaponLabel ( equipType, weaponType )
        AddGroupItem ( 5, m_strformat ( "W:%d", weaponType ), weaponOrder [ weaponType ] or weaponType + 1000, label, unlocked )
      end
    end
  end

  local hasAnyData = false
  for _, group in ipairs ( groups ) do
    table.sort ( group.items, function ( a, b ) return a.order < b.order end )
    table.sort ( group.missing, function ( a, b ) return a.order < b.order end )
    if #group.items > 0 or #group.missing > 0 then
      hasAnyData = true
    end
  end

  if not hasAnyData then return nil end

  return {
    setId = setId,
    numUnlocked = GetNumItemSetCollectionSlotsUnlocked ( setId ) or 0,
    numPieces = numPieces,
    groups = groups,
  }
end

local function ToValueList ( orderedList )
  local values = { }
  for _, entry in ipairs ( orderedList ) do
    table.insert ( values, entry.value )
  end
  return values
end

local function AddSetCollectionTooltipSummary ( tooltip, itemLink )
  if not tooltip or not itemLink then return end

  local data = BuildSetCollectionTooltipData ( itemLink )
  if not data then return end

  local percent = zo_floor ( ( data.numUnlocked / data.numPieces ) * 100 + 0.5 )
  local transmuteCost = GetSetReconstructionTransmuteCost ( data.setId )

  local transmuteText = ""
  if transmuteCost then
    transmuteText = m_strformat ( "|c66CCFF%d |t20:20:EsoUI/Art/Currency/gamepad/gp_currencyicon_chaoticcreatia.dds|t|r", transmuteCost )
  end

  ZO_Tooltip_AddDivider ( tooltip )
  if transmuteText ~= "" then
    tooltip:AddLine ( m_strformat ( "|cA0A0A0%d/%d (%d%%)|r\t%s", data.numUnlocked, data.numPieces, percent, transmuteText ), "", 1, 1, 1 )
  else
    tooltip:AddLine ( m_strformat ( "|cA0A0A0%d/%d (%d%%)|r", data.numUnlocked, data.numPieces, percent ), "", 1, 1, 1 )
  end

  for _, group in ipairs ( data.groups ) do
    local collected = table.concat ( ToValueList ( group.items ), ", " )
    local missing = table.concat ( ToValueList ( group.missing ), ", " )
    if collected ~= "" or missing ~= "" then
      tooltip:AddLine ( m_strformat ( "|cFFFFFF%s|r", string.upper ( group.title ) ), "", 1, 1, 1 )
      if collected ~= "" then
        tooltip:AddLine ( m_strformat ( "|c00FF00%s|r", collected ), "", 1, 1, 1 )
      end
      if missing ~= "" then
        tooltip:AddLine ( m_strformat ( "|cFF4C4C%s|r", missing ), "", 1, 1, 1 )
      end
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:New ( control )
  local inventoryAssistant = ZO_Object.New ( self )
  inventoryAssistant:Initialize ( control )
  return inventoryAssistant
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:Initialize ( control )
  EH:RegisterForEvent ( self.name, EVENT_ADD_ON_LOADED, function ( event, addonName )
      if addonName ~= self.name then return end
      EH:UnregisterForEvent ( self.name, EVENT_ADD_ON_LOADED )

      self.settings = ZO_SavedVars:NewAccountWide ( "InventoryAssistantSettings", 1, nil, self.defaults )
      self.async = LibAsync:Create ( self.name ) 
      
      self.onlyUncollected = self.settings.onlyUncollected
      self.onlyDuplicates = self.settings.onlyDuplicates
      self.onlyMarkedItems = self.settings.onlyMarkedItems
      self.onlyLoots = self.settings.onlyLoots
      self.groupLoots = self.settings.groupLoots
      self.showCrafted = self.settings.showCrafted
      self.showBuyable = self.settings.showBuyable
      self.showBound = self.settings.showBound
      self.showMonsterSets = self.settings.showMonsterSets
      self.showFCOISGearSetMarkers = self.settings.showFCOISGearSetMarkers
      self.showFCOISDynamicMarkers = self.settings.showFCOISDynamicMarkers
      self.showNonSetItems = self.settings.showNonSetItems
      self.showItemLevels = self.settings.showItemLevels
      self.showEnchants = self.settings.showEnchants
      
      self.onlyCP160 = false
      self.onlyNonCP160 = false

      self.dirtyFlags = { }
      self.dirtyDebounceMs = 250
      self.dirtyLogPending = false
      self.currentCharacterInventoryIndex = nil

      self.groupMembers = { }
      ScanGroupMemberNames ( self.groupMembers )
      
      if FCOIS and not FCOIS.addonVars.gSettingsLoaded then
        FCOIS.LoadUserSettings()
      end
    
      self:InitializeSettingsMenu ( )
      self:InitializeWindow ( control )
      if self.settings.lootHistoryEnabled then
        self.lootHistory = IA_LootHistory:New ( IA_LOOT_HISTORY_CONTROL )
        self.lootHistory:OnInitialized ( self.settings )
        IA_LOOT_HISTORY_CONTROL:SetHidden ( false )
      end
      self:InitializeHooks ( control )
      
      EH:RegisterForEvent ( self.name, EVENT_PLAYER_ACTIVATED, function ( ) self:Rescan ( ); self:Refresh ( --[[reload]] true, --[[preserveScrollPosition]] false ) end )

      EH:RegisterForEvent ( self.name, EVENT_LOOT_RECEIVED, function ( ... ) self:OnLootReceived ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GROUP_MEMBER_JOINED, function ( ... ) self:OnGroupChanged ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GROUP_MEMBER_LEFT, function ( ... ) self:OnGroupChanged ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function ( ... ) self:OnInventorySingleSlotUpdate ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_ITEM_SET_COLLECTION_UPDATED, function ( ... ) self:OnItemSetCollectionUpdated ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_OPEN_BANK, function ( ... ) self:OnOpenBank ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GUILD_BANK_ITEMS_READY, function ( ... ) self:OnGuildBankItemsReady ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GUILD_BANK_ITEM_ADDED, function ( ... ) self:OnGuildBankItemAdded ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GUILD_BANK_ITEM_REMOVED, function ( ... ) self:OnGuildBankItemRemoved ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GUILD_BANK_UPDATED_QUANTITY, function ( ... ) self:OnGuildBankUpdatedQuantity ( ... ) end )
      EH:RegisterForEvent ( self.name, EVENT_GUILD_SELF_LEFT_GUILD, function ( ... ) self:OnGuildSelfLeftGuild ( ... ) end )

      SLASH_COMMANDS[ "/ia" ] = function ( ... ) self:HandleSlashCommand ( ... ) end
    end )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:InitializeWindow ( control )
  self.window = control

  self.window:SetHidden( true )
  self.window:SetAnchor ( TOPLEFT, GuiRoot, TOPLEFT, self.settings.inventoryAssistantWindowX, self.settings.inventoryAssistantWindowY )
  self.window:SetDimensions ( self.settings.inventoryAssistantWindowWidth, self.settings.inventoryAssistantWindowHeight )
  
  self.list = IA_InventoryAssistantList:New ( self.window, self.window:GetNamedChild ( "WindowCanvas" ) )
  self.searchbox = self.window:GetNamedChild ( "WindowCanvasSearchBox" )
  self.searchbox:SetHandler ( "OnTextChanged", function ( ) 
    if not self.window:IsControlHidden ( ) then
      self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
    end      
  end )
  self.searchbox:SetHandler ( "OnEnter", function ( )
    if not self.window:IsControlHidden ( ) then
      self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
    end      
  end )
  self.searchbox:SetHandler ( "OnEscape", function ( ) 
      if self.searchbox:GetText ( ) ~= "" then
        self.searchbox:SetText ( "" )
      else
        self:ToggleWindow ( )
      end
    end )
    self.searchbox:SetHandler ( "OnTab", function ( ) 
        self:ToggleWindow ( )
    end )
	self.search = ZO_StringSearch:New ( )

  self.window:SetHandler ( "OnMoveStop", function ( )
      self.settings.inventoryAssistantWindowX = self.window:GetLeft ( )
      self.settings.inventoryAssistantWindowY = self.window:GetTop ( )
    end )

  self.window:SetHandler ( "OnResizeStop", function ( )
      self.settings.inventoryAssistantWindowWidth = self.window:GetWidth ( )
      self.settings.inventoryAssistantWindowHeight = self.window:GetHeight ( )
      ZO_ScrollList_Commit ( self.list.list )
    end )

end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:InitializeHooks ( control )
  local originalSearchText = nil
  
  local updateSearchFilter = function ( itemLink )
    local searchText
    local isSetItem, setName = GetItemLinkSetInfo ( itemLink, false )
    local itemName = GetItemLinkName ( itemLink )
    if IsShiftKeyDown() then
      if not originalSearchText then
        originalSearchText = self.searchbox:GetText ( )
      end
      if isSetItem then
        searchText = zo_strformat ( "<<1>>", setName )
      else
        searchText = zo_strformat ( "<<1>>", itemName )
      end
      if searchText and self.searchbox:GetText ( ) ~= searchText then 
        self.searchbox:SetText ( searchText )
      end
    end
  end
  
  local originalSetBagItem = ItemTooltip.SetBagItem
  ItemTooltip.SetBagItem_IA = originalSetBagItem
  ItemTooltip.SetBagItem = function ( tooltip, bagId, slotIndex, ... )
--          d ( "SetBagItem called", tooltip, bagId, slotIndex, ... )
      originalSetBagItem ( tooltip, bagId, slotIndex, ... )
      local itemLink = GetItemLink ( bagId, slotIndex, LINK_STYLE_DEFAULT )
      updateSearchFilter ( itemLink )
  end
  
  local originalSetLink = ItemTooltip.SetLink
  ItemTooltip.SetLink_IA = originalSetLink
  ItemTooltip.SetLink = function ( tooltip, itemLink, ... )
--          d ( "SetLink called", ... )
      originalSetLink ( tooltip, itemLink, ... )
      updateSearchFilter ( itemLink )
  end
  
  local originalSetTradingHouseListing = ItemTooltip.SetTradingHouseListing
  ItemTooltip.SetTradingHouseListing = function ( tooltip, slotIndex, ... )
--          d ( "SetTradingHouseListing called", tooltip, slotIndex, ... )
      originalSetTradingHouseListing ( tooltip, slotIndex, ... )
      local itemLink = GetTradingHouseListingItemLink ( slotIndex )
      updateSearchFilter ( itemLink )
  end
  
  local originalSetTradingHouseItem = ItemTooltip.SetTradingHouseItem
  ItemTooltip.SetTradingHouseItem = function ( tooltip, slotIndex, ... )
--          d ( "SetTradingHouseItem called", tooltip, slotIndex, ... )
      originalSetTradingHouseItem ( tooltip, slotIndex, ... )
      local itemLink = GetTradingHouseSearchResultItemLink ( slotIndex )
      updateSearchFilter ( itemLink )
  end
  
  ZO_PreHookHandler ( ItemTooltip, "OnHide", function ( tooltip, ... )
    if originalSearchText then
--          originalSearchText = self.searchbox:SetText ( originalSearchText )
      originalSearchText = nil
    end
  end )

  local originalPopupSetLink = PopupTooltip.SetLink
  PopupTooltip.SetLink_IA = originalPopupSetLink
  PopupTooltip.SetLink = function ( tooltip, itemLink, ... )
--          d ( "SetLink called", ... )
      originalPopupSetLink ( tooltip, itemLink, ... )
      updateSearchFilter ( itemLink )
      if self.window:IsControlHidden ( ) and IsShiftKeyDown ( ) then
        self:ToggleWindow ( --[[grabFocus]] false )
      end
  end

  if FCOIS then 
    local originalFCOISFilterBasics = FCOIS.FilterBasics
    FCOIS.FilterBasics = function ( onlyPlayer, ... )
--          d ( "SetLink called", ... )
        originalFCOISFilterBasics ( onlyPlayer, ... )
        if not self.window:IsControlHidden ( ) then
          self.list:RefreshVisible ( )
        end
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:InitializeSettingsMenu ( )
  local guildBankChoices = { "Disabled" }
  local guildBankChoiceValues = { 0 }
  local selectedGuildFound = self.settings.guildBankId == 0

  for guildIndex = 1, GetNumGuilds ( ) do
    local guildId = GetGuildId ( guildIndex )
    table.insert ( guildBankChoices, zo_strformat ( "<<1>>", GetGuildName ( guildId ) ) )
    table.insert ( guildBankChoiceValues, guildId )

    if guildId == self.settings.guildBankId then
      selectedGuildFound = true
    end
  end

  if not selectedGuildFound then
    self.settings.guildBankId = 0
  end

  self:RescanGuildBank ( )

  self.settingsPanel = LAM:RegisterAddonPanel ( self.name, {
    type = "panel",
    name = "Inventory Assistant",
    author = "zsban",
    version = self.version,
    registerForRefresh = true,
    registerForDefaults = true,
  } )
  
  local options = { }
  table.insert ( options, {
    type = "header",
    name = "General Settings",
    width = "full",
  } )
  table.insert ( options, {
    type = "dropdown",
    name = "Guild bank to scan",
    tooltip = "The selected guild bank will be scanned. Select Disabled to turn off guild bank scanning.",
    choices = guildBankChoices,
    choicesValues = guildBankChoiceValues,
    default = 0,
    getFunc = function ( ) return self.settings.guildBankId end,
    setFunc = function ( guildId )
      if self.settings.guildBankId == guildId then return end

      self.settings.guildBankId = guildId
      self:RescanAndRefreshGuildBank ( )
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "description",
    text = "Default state of the filter options after login or /reloadui:",
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show only uncollected set items",
    default = false,
    getFunc = function ( ) return self.settings.onlyUncollected end,
    setFunc = function ( value )
      self.settings.onlyUncollected, self.onlyUncollected = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show only duplicates",
    default = false,
    getFunc = function ( ) return self.settings.onlyDuplicates end,
    setFunc = function ( value )
      self.settings.onlyDuplicates, self.onlyDuplicates = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show only marked items",
    default = false,
    getFunc = function ( ) return self.settings.onlyMarkedItems end,
    setFunc = function ( value ) 
      self.settings.onlyMarkedItems, self.onlyMarkedItems = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show FCOIS gear set marker icons",
    default = true,
    getFunc = function ( ) return self.settings.showFCOISGearSetMarkers end,
    setFunc = function ( value ) 
      self.settings.showFCOISGearSetMarkers, self.showFCOISGearSetMarkers = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show FCOIS dynamic marker icons",
    default = true,
    getFunc = function ( ) return self.settings.showFCOISDynamicMarkers end,
    setFunc = function ( value ) 
      self.settings.showFCOISDynamicMarkers, self.showFCOISDynamicMarkers = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show only loots",
    default = false,
    getFunc = function ( ) return self.settings.onlyLoots end,
    setFunc = function ( value ) 
      self.settings.onlyLoots, self.onlyLoots = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show group loots",
    default = true,
    getFunc = function ( ) return self.settings.groupLoots end,
    setFunc = function ( value ) 
      self.settings.groupLoots, self.groupLoots = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] true, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show crafted sets",
    default = true,
    getFunc = function ( ) return self.settings.showCrafted end,
    setFunc = function ( value ) 
      self.settings.showCrafted, self.showCrafted = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show tradeable sets",
    default = true,
    getFunc = function ( ) return self.settings.showBuyable end,
    setFunc = function ( value ) 
      self.settings.showBuyable, self.showBuyable = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show bound sets",
    default = true,
    getFunc = function ( ) return self.settings.showBound end,
    setFunc = function ( value ) 
      self.settings.showBound, self.showBound = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show monster sets",
    default = true,
    getFunc = function ( ) return self.settings.showMonsterSets end,
    setFunc = function ( value ) 
      self.settings.showMonsterSets, self.showMonsterSets = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show other items",
    default = true,
    getFunc = function ( ) return self.settings.showNonSetItems end,
    setFunc = function ( value ) 
      self.settings.showNonSetItems, self.showNonSetItems = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "header",
    name = "Loot History (beta)",
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Enable loot history",
    requiresReload = true,
    default = true,
    getFunc = function ( ) return self.settings.lootHistoryEnabled end,
    setFunc = function ( value ) self.settings.lootHistoryEnabled = value end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Lock loot history window",
    default = true,
    getFunc = function ( ) return self.settings.lootHistoryLocked end,
    setFunc = function ( value )
      self.settings.lootHistoryLocked = value
      self.lootHistory:SetLocked ( value )
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "slider",
    name = "Maximum loot history entries",
    min = 1,
    max = 10,
    step = 1,
    default = 6,
    getFunc = function ( ) return self.settings.lootHistoryMaxEntries end,
    setFunc = function ( value )
      self.settings.lootHistoryMaxEntries = value
      self.lootHistory:RebuildBuffers ( )
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "dropdown",
    name = "Loot history direction",
    choices = { "Up", "Down" },
    choicesValues = { true, false },
    default = true,
    getFunc = function ( ) return self.settings.lootHistoryNewestOnTop end,
    setFunc = function ( value )
      self.settings.lootHistoryNewestOnTop = value
      self.lootHistory:SetDirection ( value )
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "dropdown",
    name = "Loot history alignment",
    choices = { "Left", "Right" },
    choicesValues = { false, true },
    default = false,
    getFunc = function ( ) return self.settings.lootHistoryRightAligned end,
    setFunc = function ( value )
      self.settings.lootHistoryRightAligned = value
      self.lootHistory:SetAlignment ( value )
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "header",
    name = "Window Settings",
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show non CP160 item levels",
    default = true,
    getFunc = function ( ) return self.settings.showItemLevels end,
    setFunc = function ( value ) 
      self.settings.showItemLevels, self.showItemLevels = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "checkbox",
    name = "Show item enchantments",
    default = true,
    getFunc = function ( ) return self.settings.showEnchants end,
    setFunc = function ( value ) 
      self.settings.showEnchants, self.showEnchants = value, value
      if not self.window:IsControlHidden ( ) then
        self:Refresh ( --[[reload]] false, --[[preserveScrollPosition]] false )
      end
    end,
    width = "full",
  } )
  table.insert ( options, {
    type = "slider",
    name = "Bag name width",
    default = 250,
    min = 50,
    max = 450,
    step = 10,
    getFunc = function ( ) return self.settings.bagNameWidth end,
    setFunc = function ( value ) 
      self.settings.bagNameWidth = value 
      if not self.window:IsControlHidden ( ) then
        self.list:RefreshVisible ( )
      end
    end,
    width = "full",
  } )
  
  LAM:RegisterOptionControls ( self.name, options )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:HandleSlashCommand ( command )
  self:ToggleWindow ( ) 
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGroupChanged ( )
  ScanGroupMemberNames ( self.groupMembers )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:MarkDirty ( flag )
  if not self.dirtyFlags then
    self.dirtyFlags = { }
  end
  self.dirtyFlags [ flag ] = true
  self:ScheduleDirtyLogFlush ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:ScheduleDirtyLogFlush ( )
  local updateId = self.name .. "_DirtyLogFlush"
  if self.dirtyLogPending then
    EVENT_MANAGER:UnregisterForUpdate ( updateId )
  else
    self.dirtyLogPending = true
  end

  EVENT_MANAGER:RegisterForUpdate ( updateId, self.dirtyDebounceMs, function ( )
    EVENT_MANAGER:UnregisterForUpdate ( updateId )
    self.dirtyLogPending = false
    self:FlushDirtyFlagsLog ( )
  end )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:FlushDirtyFlagsLog ( )
  local dirty = self.dirtyFlags or { }
  local labels = { }

  if dirty.inventory then table.insert ( labels, "inventory" ) end
  if dirty.bank then table.insert ( labels, "bank" ) end
  if dirty.house then table.insert ( labels, "house" ) end
  if dirty.collection then table.insert ( labels, "collection" ) end

--  if #labels > 0 then
--    d ( m_strformat ( "IA dirty flags: %s", table.concat ( labels, ", " ) ) )
--  end

  self.dirtyFlags = { }

  if self.window and not self.window:IsControlHidden ( ) then
    local inventoryChanged = dirty.inventory or dirty.bank or dirty.house
    self.async:Cancel ( )
    self:Refresh ( --[[reload]] inventoryChanged, --[[preserveScrollPosition]] true )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:IsActiveStorageBag ( bagId )
  if not IsBankOpen ( ) then return false end

  local bankingBag = GetBankingBag ( )
  if bankingBag == BAG_BANK then
    return bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK
  end

  return bagId == bankingBag
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:RescanCurrentCharacter ( )
  local currentCharId = zo_strformat ( "<<1>>", GetCurrentCharacterId ( ) )
  local bag = { }
  ScanBag ( bag, BAG_WORN, currentCharId, self.settings.actionQueue )
  ScanBag ( bag, BAG_BACKPACK, currentCharId, self.settings.actionQueue )
  self.settings.inventories [ currentCharId ] = bag
  self.currentCharacterInventoryIndex = {
    characterId = currentCharId,
    inventory = bag,
    slots = BuildInventoryIndex ( bag ),
  }
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:UpdateCurrentCharacterSlot ( bagId, slotIndex )
  local currentCharId = zo_strformat ( "<<1>>", GetCurrentCharacterId ( ) )
  local inventory = self.settings.inventories [ currentCharId ]
  if not inventory then
    self:RescanCurrentCharacter ( )
    return
  end

  local currentIndex = self.currentCharacterInventoryIndex
  if not currentIndex or currentIndex.characterId ~= currentCharId or currentIndex.inventory ~= inventory then
    currentIndex = {
      characterId = currentCharId,
      inventory = inventory,
      slots = BuildInventoryIndex ( inventory ),
    }
    self.currentCharacterInventoryIndex = currentIndex
  end

  local bagIndex = currentIndex.slots [ bagId ]
  local itemIndex = bagIndex and bagIndex [ slotIndex ]
  local item = ScanBagSlot ( bagId, slotIndex, GetTimeStamp ( ), currentCharId )

  if item then
    ApplyQueuedItemActions ( item, self.settings.actionQueue )
  end

  if itemIndex then
    if item then
      inventory [ itemIndex ] = item
    else
      local lastIndex = #inventory
      local lastItem = inventory [ lastIndex ]
      if itemIndex ~= lastIndex then
        inventory [ itemIndex ] = lastItem
        currentIndex.slots [ lastItem.bagId ] [ lastItem.slotIndex ] = itemIndex
      end
      inventory [ lastIndex ] = nil
      bagIndex [ slotIndex ] = nil
    end
  elseif item then
    if not bagIndex then
      bagIndex = { }
      currentIndex.slots [ bagId ] = bagIndex
    end
    local newIndex = #inventory + 1
    inventory [ newIndex ] = item
    bagIndex [ slotIndex ] = newIndex
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:RescanBank ( )
  local bank = { }
  ScanBag ( bank, BAG_BANK, nil, self.settings.actionQueue )
  ScanBag ( bank, BAG_SUBSCRIBER_BANK, nil, self.settings.actionQueue )
  self.settings.inventories [ "bank" ] = bank
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:RescanHouseBank ( bagId )
  local chest = { }
  local previousChest = self.settings.inventories [ "chest" ] or { }

  for _, item in ipairs ( previousChest ) do
    if item.bagId ~= bagId then
      table.insert ( chest, item )
    end
  end

  ScanBag ( chest, bagId, nil, self.settings.actionQueue )
  self.settings.inventories [ "chest" ] = chest
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnInventorySingleSlotUpdate ( eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange )
--  d ( m_strformat ( "IA event: EVENT_INVENTORY_SINGLE_SLOT_UPDATE (bag=%s slot=%s reason=%s stackDelta=%s)", tostring ( bagId ), tostring ( slotIndex ), tostring ( updateReason ), tostring ( stackCountChange ) ) )
  if bagId == BAG_BACKPACK or bagId == BAG_WORN then
    self:UpdateCurrentCharacterSlot ( bagId, slotIndex )
    self:MarkDirty ( "inventory" )
  elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
    if self:IsActiveStorageBag ( bagId ) then
      self:RescanBank ( )
      self:MarkDirty ( "bank" )
    end
  elseif bagId >= BAG_HOUSE_BANK_ONE and bagId <= BAG_HOUSE_BANK_TEN then
    if self:IsActiveStorageBag ( bagId ) then
      self:RescanHouseBank ( bagId )
      self:MarkDirty ( "house" )
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnItemSetCollectionUpdated ( eventCode )
--  d ( "IA event: EVENT_ITEM_SET_COLLECTION_UPDATED" )
  self:MarkDirty ( "collection" )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnOpenBank ( eventCode, bankBag )
--  d ( "IA event: EVENT_OPEN_BANK" )
  if bankBag == BAG_BANK then
    self:RescanBank ( )
    self:MarkDirty ( "bank" )
  elseif bankBag >= BAG_HOUSE_BANK_ONE and bankBag <= BAG_HOUSE_BANK_TEN then
    self:RescanHouseBank ( bankBag )
    self:MarkDirty ( "house" )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGuildSelfLeftGuild ( eventCode, guildId )
  if guildId == self.settings.guildBankId then
    self.async:Cancel ( )
    self:RescanAndRefreshGuildBank ( )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGuildBankItemsReady ( eventCode )
--  d ( "IA event: EVENT_GUILD_BANK_ITEMS_READY" )
  self:RescanAndRefreshGuildBank ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGuildBankItemAdded ( eventCode, slotIndex )
--  d ( m_strformat ( "IA event: EVENT_GUILD_BANK_ITEM_ADDED (slot=%s)", tostring ( slotIndex ) ) )
  self:RescanAndRefreshGuildBank ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGuildBankItemRemoved ( eventCode, slotIndex )
--  d ( m_strformat ( "IA event: EVENT_GUILD_BANK_ITEM_REMOVED (slot=%s)", tostring ( slotIndex ) ) )
  self:RescanAndRefreshGuildBank ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnGuildBankUpdatedQuantity ( eventCode, slotIndex )
--  d ( m_strformat ( "IA event: EVENT_GUILD_BANK_UPDATED_QUANTITY (slot=%s)", tostring ( slotIndex ) ) )
  self:RescanAndRefreshGuildBank ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:OnLootReceived ( eventCode, lootedBy, itemLink, quantity, itemSound, lootType, selfLoot )
--  d ( lootedBy .. " looted " .. itemLink .. "  ( " .. quantity .." )" )
  
  if selfLoot then return end
  local isSetItem = GetItemLinkSetInfo ( itemLink )
  if not isSetItem then return end
  
  if not self.settings.inventories [ "grouploot" ] then 
    self.settings.inventories [ "grouploot" ] = { }
  end
  
  local characterName = zo_strformat ( "<<1>>", lootedBy )
  local bagName = self.groupMembers [ characterName ] and self.groupMembers [ characterName ].bagName or characterName
  
  local epoch = GetTimeStamp ( )
  local bopTimeRemaining = 2 * 60 * 60 -- 2 hours
  local item = {
    bagId = bagName,
    link = itemLink,
    bopTimeEnds = epoch + bopTimeRemaining,
  }
  table.insert ( self.settings.inventories [ "grouploot" ], item )

end
-----------------------------------------------------------------------------------------------------------------------------------
-- IMPLEMENTATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:ToggleWindow ( grabFocus )
  self.async:Cancel ( )
  self.window:SetHidden( not self.window:IsControlHidden ( ) )
  if not self.window:IsControlHidden ( ) then
--    self.async:Call( function ( )
      self:Rescan ( )
      self:Refresh ( --[[reload]] true, --[[preserveScrollPosition]] false )
--	end )
    if grabFocus then
      self.searchbox:TakeFocus ( )
      SetGameCameraUIMode ( true )
    end
  else
--    self.async:Call( function ( )
      self.list:Reset ( )
      self.list:RefreshData ( )
--    SetGameCameraUIMode ( false )
--    end )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:IsGuildMember ( guildId )
  if guildId == 0 then return false end

  for guildIndex = 1, GetNumGuilds ( ) do
    if GetGuildId ( guildIndex ) == guildId then
      return true
    end
  end

  return false
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:RescanGuildBank ( )
  local guildId = self.settings.guildBankId
  local snapshotChanged = false

  if guildId ~= 0 and not self:IsGuildMember ( guildId ) then
    self.settings.guildBankId = 0
    guildId = 0
  end

  if guildId == 0 then
    snapshotChanged = self.settings.inventories [ "guild" ] ~= nil or self.settings.guildBankSnapshotId ~= 0
    self.settings.inventories [ "guild" ] = nil
    self.settings.guildBankSnapshotId = 0
    return snapshotChanged
  end

  if self.settings.guildBankSnapshotId ~= guildId then
    snapshotChanged = self.settings.inventories [ "guild" ] ~= nil or self.settings.guildBankSnapshotId ~= 0
    self.settings.inventories [ "guild" ] = nil
    self.settings.guildBankSnapshotId = 0
  end

  if GetSelectedGuildBankId ( ) ~= guildId then
    return snapshotChanged
  end

  local guild = { }
  ScanBag ( guild, BAG_GUILDBANK )
  self.settings.inventories [ "guild" ] = guild
  self.settings.guildBankSnapshotId = guildId
  return true
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:RescanAndRefreshGuildBank ( )
  local snapshotChanged = self:RescanGuildBank ( )

  if snapshotChanged and self.window and not self.window:IsControlHidden ( ) then
    self:Refresh ( --[[reload]] true, --[[preserveScrollPosition]] true )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:Rescan ( )
  self.settings.characters = { }
  for charNum=1, GetNumCharacters ( ), 1 do
		local name, gender, level, classId, raceId, alliance, charId, locationId = GetCharacterInfo ( charNum )
    self.settings.characters [ charId ] = zo_strformat( "<<1>>", name )
	end

  self:RescanCurrentCharacter ( )

  if IsBankOpen ( ) then
    local bankingBag = GetBankingBag ( )
    if bankingBag == BAG_BANK then
      self:RescanBank ( )
    elseif bankingBag >= BAG_HOUSE_BANK_ONE and bankingBag <= BAG_HOUSE_BANK_TEN then
      self:RescanHouseBank ( bankingBag )
    end
  end
  
  if self.settings.inventories [ "grouploot" ] then
    local grouploots = { }
    for i,v in ipairs ( self.settings.inventories [ "grouploot" ] ) do
      if v.bopTimeEnds and v.bopTimeEnds > GetTimeStamp ( ) then
        table.insert ( grouploots, v )
      end
    end
    self.settings.inventories [ "grouploot" ] = grouploots 
  end

end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:Reload ( suppressProgress )
  local list = self.list
  local sets = { }
  local materials = { }
  local others = { }
  local selectedGuildId = self.settings.guildBankId
  local selectedGuildIsMember = selectedGuildId ~= 0 and self:IsGuildMember ( selectedGuildId )

  if selectedGuildId ~= 0 and not selectedGuildIsMember then
    self.settings.guildBankId = 0
    self.settings.inventories [ "guild" ] = nil
    self.settings.guildBankSnapshotId = 0
  end

  local function ShowLoadProgress ( text )
    if suppressProgress then return end

    list:Reset ( )
    list:AddText ( { text = text } )
    list:RefreshData ( )
  end
    
  local c = self.async:Call( function ( ) end )

  c:Then( function ( )
    local loadText = "Loading inventories "
    ShowLoadProgress ( loadText )
    
    for k, v in pairs ( self.settings.characters ) do
      if self.settings.inventories[ k ] then
        c:Call( function ( )
          local currentCharId = zo_strformat( "<<1>>", GetCurrentCharacterId ( ) )
          local static = currentCharId ~= k
          
          stopwatch_start ( "Loading inventory of " .. self.settings.characters[ k ] .. " " .. (static and "static" or "dynamic") )
          
          loadText = loadText .. "."
          ShowLoadProgress ( loadText )
          LoadInventory ( self.settings.inventories[ k ], --[[static]] static, sets, materials, others )
          
          stopwatch_stop ( "Loading inventory of " .. self.settings.characters[ k ] .. " " .. (static and "static" or "dynamic") )
        end )
      end
    end 
    if self.settings.inventories[ "bank" ] then
      c:Call( function ( )
        stopwatch_start ( "Loading bank inventory" )
        
        loadText = loadText .. "."
        ShowLoadProgress ( loadText )
        LoadInventory ( self.settings.inventories[ "bank" ], --[[static]] false, sets, materials, others )
        
        stopwatch_stop ( "Loading bank inventory" )
      end )
    end
    if self.settings.inventories[ "chest" ] then
      c:Call( function ( )
        stopwatch_start ( "Loading house chest inventory" )
        
        loadText = loadText .. "."
        ShowLoadProgress ( loadText )
        LoadInventory ( self.settings.inventories[ "chest" ], --[[static]] false, sets, materials, others )
        
        stopwatch_stop ( "Loading house chest inventory" )
      end )
    end
    if selectedGuildIsMember
       and self.settings.guildBankSnapshotId == selectedGuildId
       and self.settings.inventories[ "guild" ] then
      c:Call( function ( )
        stopwatch_start ( "Loading guild bank inventory" )
        
        loadText = loadText .. "."
        ShowLoadProgress ( loadText )
        LoadInventory ( self.settings.inventories[ "guild" ], --[[static]] false, sets, materials, others )
        
        stopwatch_stop ( "Loading guild bank inventory" )
      end )
    end
    if self.settings.inventories[ "grouploot" ] then
      c:Call( function ( )
        stopwatch_start ( "Loading group loots" )
        
        loadText = loadText .. "."
        ShowLoadProgress ( loadText )
        LoadInventory ( self.settings.inventories[ "grouploot" ], --[[static]] false, sets, materials, others )
        
        stopwatch_stop ( "Loading group loots" )
      end )
    end
  end )

  c:Then( function ( )
    stopwatch_start ( "Sorting inventory" )
    
    local bopTradeableSets = { }
    for _,set in ipairs ( sets ) do
      for _,item in ipairs ( sets[ set ] ) do
        if item.bopTimeEnds and item.bopTimeEnds > GetTimeStamp ( ) then
          if ( self.groupLoots or type ( item.bagId ) == "number" ) then 
            table.insert ( bopTradeableSets, set )
          end
        end
      end
    end
    
    table.sort ( bopTradeableSets )
    table.sort ( sets )
    table.sort ( materials )
    table.sort ( others )
    
    self.sets = { }
    for i,v in ipairs ( bopTradeableSets ) do
      if not self.sets[ v ] then
        table.insert ( self.sets, v )
        self.sets[ v ] = sets[ v ]
      end
    end
    for i,v in ipairs ( sets ) do
      if not self.sets[ v ] then
        table.insert ( self.sets, v )
        self.sets[ v ] = sets[ v ]
      end
    end
    
    self.others = { }
    for i,v in ipairs ( others ) do
      if not self.others[ v ] then
        table.insert ( self.others, v )
        self.others[ v ] = others[ v ]
      end
    end

    stopwatch_stop ( "Sorting inventory" )
  end )
  
  return c
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:GetItemMarkers ( itemId, uniqueId, bagId, stolen )
  local markers = { }
  if FCOIS and itemId and uniqueId then 
    local dynamicIconCount = FCOIS.numVars.gFCONumDynamicIcons
    local fcoisIconCount = FCOIS.numVars.gFCONumFilterIcons

    local iconCount = fcoisIconCount
    if not self.showFCOISDynamicMarkers then 
      iconCount = iconCount - dynamicIconCount
    end
    
    local fcois_Textures = FCOIS.textureVars.MARKER_TEXTURES
    for i = 1, iconCount, 1 do
      local icon = FCOIS.settingsVars.settings.icon [ i ]
      local isMarked = FCOIS.markedItems[ i ][ itemId ] or FCOIS.markedItems[ i ][ uniqueId ] or false
      if ( not self.showFCOISGearSetMarkers and ( i == FCOIS_CON_ICON_GEAR_1 or i == FCOIS_CON_ICON_GEAR_2 or i == FCOIS_CON_ICON_GEAR_3 or i == FCOIS_CON_ICON_GEAR_4 or i == FCOIS_CON_ICON_GEAR_5 ) ) then
        isMarked = false
      end
      if isMarked and icon then
        local markerIcon = fcois_Textures [ icon.texture ]
        local markerColor = icon.color
        table.insert ( markers, { icon = markerIcon, color = markerColor } )
      end
    end
  end
  
  if type ( bagId ) == "string" then
    table.insert ( markers, { icon = "esoui/art/contacts/social_status_afk.dds", color = { r=1, g=1, b=1, a=1 } } )
  end
  
  if stolen then
    table.insert ( markers, { icon = "esoui/art/inventory/inventory_stolenItem_icon.dds", color = { r=1, g=1, b=1, a=1 } } )
  end

  return markers
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant:Refresh ( reload, preserveScrollPosition )
  local list = self.list
  local scrollList = list.list
  local scrollValue

  if preserveScrollPosition then
    scrollValue = ZO_ScrollList_GetScrollValue ( scrollList )
  end

  scrollList.timeline:Stop ( )
  
  local c
  if reload then 
    local suppressProgress = preserveScrollPosition == true
    c = self:Reload ( suppressProgress )
  else 
    c = self.async:Call( function ( ) end )
  end
  
  local onlyUncollected = self.onlyUncollected
  local onlyDuplicates = self.onlyDuplicates
  local onlyMarkedItems = self.onlyMarkedItems
  local onlyLoots = self.onlyLoots
  local groupLoots = self.groupLoots
  local showCrafted = self.showCrafted
  local showBuyable = self.showBuyable
  local showBound = self.showBound
  local showMonsterSets = self.showMonsterSets
  local showNonSetItems = self.showNonSetItems
  
  c:Then( function ( )
    stopwatch_start ( "Populating UI" )
        
    local set_search_keywords = { }
    local name_search_keywords = { }
    local trait_search_keywords = { }
    local nottrait_search_keywords = { }
    local bag_search_keywords = { }
    local searchtext = self.searchbox:GetText ( ):lower ( )
    for w in searchtext:gmatch ( "%S+" ) do
      if w:sub ( 1, 2 ) == "t:" then
        table.insert ( trait_search_keywords, w:sub ( 3 ) )
      elseif w:sub ( 1, 3 ) == "nt:" then
        table.insert ( nottrait_search_keywords, w:sub ( 4 ) )
      elseif w:sub ( 1, 2 ) == "b:" then
        table.insert ( bag_search_keywords, w:sub ( 3 ) )
      else
        table.insert ( set_search_keywords, w )
        table.insert ( name_search_keywords, w )
      end
    end
    
    local sets = self.sets or { }
    local others = self.others or { }

    local totalShownSets = 0
    local totalShownItems = 0
    local summary = { text = m_strformat ( "%s sets, %s items", totalShownSets, totalShownItems ) }
    list:Reset ( )
    list:AddText ( summary )

    for i,setName in ipairs ( sets ) do
      local setitems = self.sets[ setName ] or { }
      local setItemBuckets = self.sets[ setName ]
      table.sort ( setitems, sortFunction )
      
      local header = { text1 = "%s (%d items)", text2 = "%s (%d of %d items)", name = setName, itemCount = #setitems, showCount = 0, color = ZO_DEFAULT_TEXT }
      local headerPrinted = false
      local bopTradeable = false

      for i, item in ipairs ( setitems ) do
        if item.bopTimeEnds and item.bopTimeEnds > GetTimeStamp ( ) then
          if ( groupLoots or type ( item.bagId ) == "number" ) then 
            bopTradeable = true
          end
        end
        
        local isCrafted = IsItemLinkCrafted ( item.link )
        local isBuyable = ( GetItemLinkBindType ( item.link ) ~= BIND_TYPE_ON_PICKUP and GetItemLinkBindType ( item.link ) ~= BIND_TYPE_ON_PICKUP_BACKPACK )
		local isUncollected = IsItemLinkSetCollectionPiece ( item.link ) and not IsItemSetCollectionPieceUnlocked( GetItemLinkItemId ( item.link ) ) or false
        
        local include1 = true
        local setNameLower = item.setName:lower ( )
        for k,w in ipairs ( set_search_keywords ) do
          if not setNameLower:find ( w, 1, true ) then
            include1 = false
            break
          end
        end
        local include2 = true
        local itemNameLower = item.name:lower ( )
        for k,w in ipairs ( name_search_keywords ) do
          if not itemNameLower:find ( w, 1, true ) then
            include2 = false
            break
          end
        end
        
        if ( include1 or include2 ) and ( 
          ( showCrafted and isCrafted ) or 
          ( showBuyable and isBuyable and not isCrafted ) or 
          ( showMonsterSets and not isBuyable and item.maxEquipped == 2 and item.numBonuses ~= 1 ) or 
          ( showBound and not isBuyable and not ( item.maxEquipped == 2 and item.numBonuses ~= 1 ) )
        ) then 
          item.markers = self:GetItemMarkers ( item.itemId, item.uniqueId, item.bagId, item.stolen )
          
          item.groupLoot = false
          local bagName = ""
          if type ( item.bagId ) == "string" then
            bagName = m_strformat ( "|c0CD0FF%s|r", item.bagId )
            item.groupLoot = true
          elseif item.bagId == BAG_WORN then
            bagName = ( self.settings.characters[ item.charId ] or item.charId or "???" ) .. " (worn)"
--            table.insert ( item.markers, { icon = ZO_KEYBOARD_IS_EQUIPPED_ICON, color = { r=1, g=1, b=1, a=1 } } )
          elseif item.bagId == BAG_BACKPACK then
            bagName = self.settings.characters[ item.charId ] or item.charId
          elseif item.bagId == BAG_BANK or item.bagId == BAG_SUBSCRIBER_BANK then
            bagName = "Bank"
          elseif item.bagId >= BAG_HOUSE_BANK_ONE and item.bagId <= BAG_HOUSE_BANK_TEN then
            bagName = GetCollectibleNickname ( GetCollectibleForHouseBankBag ( item.bagId ) )
            if bagName == "" then
              bagName = GetCollectibleName ( GetCollectibleForHouseBankBag ( item.bagId ) )
            end 
            bagName = zo_strformat ( "<<1>>", bagName )
          elseif item.bagId == BAG_GUILDBANK then
            bagName = "Guild Bank"
          end
          item.bagName = bagName
          
          local match_trait = #trait_search_keywords == 0 and true or false
          for k,w in ipairs ( trait_search_keywords ) do
            if string.sub ( item.traitTypeName:lower ( ), 1, w:len ( ) ) == w then
              match_trait = true
            end
          end
          
          local match_nottrait = true
          for k,w in ipairs ( nottrait_search_keywords ) do
            if w ~= "" and string.sub ( item.traitTypeName:lower ( ), 1, w:len ( ) ) == w then
              match_nottrait = false
            end
          end
          
          local match_bag = #bag_search_keywords == 0 and true or false
          for k,w in ipairs ( bag_search_keywords ) do
            if string.sub ( bagName:lower ( ), 1, w:len ( ) ) == w then
              match_bag = true
            end
          end
          
          if ( onlyLoots and item.bopTimeEnds and item.bopTimeEnds > GetTimeStamp ( ) ) or not onlyLoots then
            local level, isNonCP160 = "", false
            if ( item.armorType ~= ARMORTYPE_NONE or item.weaponType ~= WEAPONTYPE_NONE or item.equipType == EQUIP_TYPE_RING or item.equipType == EQUIP_TYPE_NECK
              or item.itemType == ITEMTYPE_GLYPH_ARMOR or item.itemType == ITEMTYPE_GLYPH_JEWELRY or item.itemType == ITEMTYPE_GLYPH_WEAPON 
              or item.itemType == ITEMTYPE_FOOD or item.itemType == ITEMTYPE_DRINK or item.itemType == ITEMTYPE_POTION or item.itemType == ITEMTYPE_POISON
            ) then 
              if ( item.requiredChampionPoints == 0 and item.requiredLevel > 0 ) then
                if not ( item.itemType == ITEMTYPE_FOOD or item.itemType == ITEMTYPE_DRINK or item.itemType == ITEMTYPE_POTION or item.itemType == ITEMTYPE_POISON ) then
                  level = m_strformat ( "|t24:24:inventoryassistant/ui/level_normal.dds|t%d  ", item.requiredLevel )
                  isNonCP160 = true
                elseif ( item.requiredLevel > 1 ) then
                  level = m_strformat ( "|t24:24:inventoryassistant/ui/level_normal.dds|t%d  ", item.requiredLevel )
                  isNonCP160 = true
                end
              elseif ( item.requiredChampionPoints < 160 and item.requiredLevel == 50 and not ( item.itemType == ITEMTYPE_FOOD or item.itemType == ITEMTYPE_DRINK or item.itemType == ITEMTYPE_POTION or item.itemType == ITEMTYPE_POISON ) ) then
                level = m_strformat ( "|t24:24:inventoryassistant/ui/level_champion.dds|t%d  ", item.requiredChampionPoints )
                isNonCP160 = true
              elseif ( item.requiredChampionPoints < 150 and item.requiredLevel == 50 and ( item.itemType == ITEMTYPE_FOOD or item.itemType == ITEMTYPE_DRINK or item.itemType == ITEMTYPE_POTION or item.itemType == ITEMTYPE_POISON ) ) then
                level = m_strformat ( "|t24:24:inventoryassistant/ui/level_champion.dds|t%d  ", item.requiredChampionPoints )
                isNonCP160 = true
              end
            end
            if not self.showItemLevels then
              level = ""
            end
            local enchant = self.showEnchants and item.enchant or ""
            
            if match_bag and match_trait and match_nottrait 
               and ( ( groupLoots and item.groupLoot ) or not item.groupLoot )
               and ( ( onlyMarkedItems and #item.markers > 0 and not item.groupLoot ) or not onlyMarkedItems )
               and ( ( onlyUncollected and isUncollected ) or not onlyUncollected )
               and ( ( self.onlyNonCP160 and isNonCP160 ) or not self.onlyNonCP160 )
               and ( ( self.onlyCP160 and not isNonCP160 ) or not self.onlyCP160 ) then
              local threshold = item.equipType == EQUIP_TYPE_RING and 2 or 1
              local duplicateBucket = setItemBuckets and setItemBuckets[ item.itemkey ]
              local duplicateCount = duplicateBucket and #duplicateBucket or 0
              
              if not headerPrinted and ( not onlyDuplicates or duplicateCount > threshold ) then  
                list:AddHeader( header, GetEquipSlotData ( setitems ) )
                headerPrinted = true
                totalShownSets = totalShownSets + 1
              end

              if duplicateCount > threshold then 
                list:AddData( m_strformat ( "%s%s|r  |cFFCC00*|r  (%s)%s", level, item.link, item.traitTypeName, enchant ), item, item.icon, item.link, level, item.bagName, item.itemId, item.uniqueId )
                header.showCount = header.showCount + 1
                totalShownItems = totalShownItems + 1
              elseif not onlyDuplicates then 
                list:AddData( m_strformat ( "%s%s|r  (%s)%s", level, item.link, item.traitTypeName, enchant ), item, item.icon, item.link, level, item.bagName, item.itemId, item.uniqueId )
                header.showCount = header.showCount + 1
                totalShownItems = totalShownItems + 1
              end
            end
          end
        end
      end
      if bopTradeable then
        header.text1 = m_strformat ( "|c0CD0FF%s|r", header.text1 )
        header.text2 = m_strformat ( "|c0CD0FF%s|r", header.text2 )
      end
    end
    
    if totalShownSets == GetSetCount ( self.sets ) and totalShownItems == GetItemCount ( self.sets, self.sets ) then
      summary.text = m_strformat ( "%d sets, %d set items", totalShownSets, totalShownItems )
    else
      summary.text = m_strformat ( "%d of %d sets, %d of %d set items", totalShownSets, GetSetCount ( self.sets ), totalShownItems, GetItemCount ( self.sets, self.sets ) )
    end

    if showNonSetItems then 
      for i1,v1 in ipairs ( others ) do
        local otheritems = self.others[ v1 ] or { }
        table.sort ( otheritems, sortFunction2 )
        
        local header = { text1 = "%s (%d items)", text2 = "%s (%d of %d items)", name = v1, itemCount = #otheritems, showCount = 0, color = ZO_DEFAULT_TEXT }
        local headerPrinted = false

        for i, v in ipairs ( otheritems ) do
          local isCrafted = IsItemLinkCrafted ( v.link )
          local isBuyable = ( GetItemLinkBindType ( v.link ) ~= BIND_TYPE_ON_PICKUP and GetItemLinkBindType ( v.link ) ~= BIND_TYPE_ON_PICKUP_BACKPACK )
          
          local include1 = true
          local setNameLower = v1:lower ( )
          for k,w in ipairs ( set_search_keywords ) do
            if not setNameLower:find ( w, 1, true ) then
              include1 = false
              break
            end
          end
          local include2 = true
          local itemNameLower = v.name:lower ( )
          for k,w in ipairs ( name_search_keywords ) do
            if not itemNameLower:find ( w, 1, true ) then
              include2 = false
              break
            end
          end

          if ( include1 or include2 )  then 
            v.markers = self:GetItemMarkers ( v.itemId, v.uniqueId, v.bagId, v.stolen )
            
            v.groupLoot = false
            local bagName = ""
            if type ( v.bagId ) == "string" then
              bagName = m_strformat ( "|c0CD0FF%s|r", v.bagId )
              v.groupLoot = true
            elseif v.bagId == BAG_WORN then
              bagName = ( self.settings.characters[ v.charId ] or v.charId or "???" ) .. " (worn)"
--              table.insert ( v.markers, { icon = ZO_KEYBOARD_IS_EQUIPPED_ICON, color = { r=1, g=1, b=1, a=1 } } )
            elseif v.bagId == BAG_BACKPACK then
              bagName = self.settings.characters[ v.charId ] or v.charId
            elseif v.bagId == BAG_BANK or v.bagId == BAG_SUBSCRIBER_BANK then
              bagName = "Bank"
            elseif v.bagId >= BAG_HOUSE_BANK_ONE and v.bagId <= BAG_HOUSE_BANK_TEN then
              bagName = GetCollectibleNickname ( GetCollectibleForHouseBankBag ( v.bagId ) )
              if bagName == "" then
                bagName = GetCollectibleName ( GetCollectibleForHouseBankBag ( v.bagId ) )
              end 
              bagName = zo_strformat ( "<<1>>", bagName )
            elseif v.bagId == BAG_GUILDBANK then
              bagName = "Guild Bank"
            end
            v.bagName = bagName
            
            local match_trait = #trait_search_keywords == 0 and true or false
            for k,w in ipairs ( trait_search_keywords ) do
              if string.sub ( v.traitTypeName:lower ( ), 1, w:len ( ) ) == w then
                match_trait = true
              end
            end
            
            local match_nottrait = true
            for k,w in ipairs ( nottrait_search_keywords ) do
              if w ~= "" and string.sub ( v.traitTypeName:lower ( ), 1, w:len ( ) ) == w then
                match_nottrait = false
              end
            end
            
            local match_bag = #bag_search_keywords == 0 and true or false
            for k,w in ipairs ( bag_search_keywords ) do
              if string.sub ( bagName:lower ( ), 1, w:len ( ) ) == w then
                match_bag = true
              end
            end
            
            if ( onlyLoots and v.bopTimeEnds and v.bopTimeEnds > GetTimeStamp ( ) ) or not onlyLoots then
              local level, isNonCP160 = "", false
              if ( v.armorType ~= ARMORTYPE_NONE or v.weaponType ~= WEAPONTYPE_NONE or v.equipType == EQUIP_TYPE_RING or v.equipType == EQUIP_TYPE_NECK
                or v.itemType == ITEMTYPE_GLYPH_ARMOR or v.itemType == ITEMTYPE_GLYPH_JEWELRY or v.itemType == ITEMTYPE_GLYPH_WEAPON 
                or v.itemType == ITEMTYPE_FOOD or v.itemType == ITEMTYPE_DRINK or v.itemType == ITEMTYPE_POTION or v.itemType == ITEMTYPE_POISON
              ) then 
                if ( v.requiredChampionPoints == 0 and v.requiredLevel > 0 ) then
                  if not ( v.itemType == ITEMTYPE_FOOD or v.itemType == ITEMTYPE_DRINK or v.itemType == ITEMTYPE_POTION or v.itemType == ITEMTYPE_POISON ) then
                    level = m_strformat ( "|t24:24:inventoryassistant/ui/level_normal.dds|t%d  ", v.requiredLevel )
                    isNonCP160 = true
                  elseif ( v.requiredLevel > 1 ) then
                    level = m_strformat ( "|t24:24:inventoryassistant/ui/level_normal.dds|t%d  ", v.requiredLevel )
                    isNonCP160 = true
                  end
                elseif ( v.requiredChampionPoints < 160 and v.requiredLevel == 50 and not ( v.itemType == ITEMTYPE_FOOD or v.itemType == ITEMTYPE_DRINK or v.itemType == ITEMTYPE_POTION or v.itemType == ITEMTYPE_POISON ) ) then
                  level = m_strformat ( "|t24:24:inventoryassistant/ui/level_champion.dds|t%d  ", v.requiredChampionPoints )
                  isNonCP160 = true
                elseif ( v.requiredChampionPoints < 150 and v.requiredLevel == 50 and ( v.itemType == ITEMTYPE_FOOD or v.itemType == ITEMTYPE_DRINK or v.itemType == ITEMTYPE_POTION or v.itemType == ITEMTYPE_POISON ) ) then
                  level = m_strformat ( "|t24:24:inventoryassistant/ui/level_champion.dds|t%d  ", v.requiredChampionPoints )
                  isNonCP160 = true
                end
              end
              if not self.showItemLevels then
                level = ""
              end
              local enchant = self.showEnchants and v.enchant or ""
              
              if match_bag and match_trait and match_nottrait 
                 and ( ( groupLoots and v.groupLoot ) or not v.groupLoot )
                 and ( ( onlyMarkedItems and #v.markers > 0 and not v.groupLoot ) or not onlyMarkedItems )
                 and ( ( self.onlyNonCP160 and isNonCP160 ) or not self.onlyNonCP160 )
                 and ( ( self.onlyCP160 and not isNonCP160 ) or not self.onlyCP160 ) then
                
                if not headerPrinted then  
                  list:AddHeader( header )
                  headerPrinted = true
                end
                
                if v.stackCount and v.stackCount > 1 then
                  if ( v.traitType and v.traitType ~= 0 ) then 
                    list:AddData( m_strformat ( "%s%s|r  (%d)  (%s)%s", level, v.link, v.stackCount, v.traitTypeName, enchant ), v, v.icon, v.link, level, v.bagName, v.itemId, v.uniqueId )
                  else
                    list:AddData( m_strformat ( "%s%s|r  (%d)%s", level, v.link, v.stackCount, enchant ), v, v.icon, v.link, level, v.bagName, v.itemId, v.uniqueId )
                  end
                else
                  if ( v.traitType and v.traitType ~= 0 ) then 
                    list:AddData( m_strformat ( "%s%s|r  (%s)%s", level, v.link, v.traitTypeName, enchant ), v, v.icon, v.link, level, v.bagName, v.itemId, v.uniqueId )
                  else
                    list:AddData( m_strformat ( "%s%s|r%s", level, v.link, enchant ), v, v.icon, v.link, level, v.bagName, v.itemId, v.uniqueId )
                  end
                end
                header.showCount = header.showCount + 1
              end
            end
          end
        end
      end
    end

    stopwatch_stop ( "Populating UI" )
  end )
  c:Then( function ( ) 
    stopwatch_start ( "Refreshing UI" )
    list:RefreshData ( )
    local targetScrollValue = preserveScrollPosition and scrollValue or 0
    local currentScrollValue = ZO_ScrollList_GetScrollValue ( scrollList )
    if targetScrollValue ~= currentScrollValue then
      ZO_ScrollList_ScrollRelative ( scrollList, targetScrollValue - currentScrollValue, nil, true )
    end
    stopwatch_stop ( "Refreshing UI" )
  end )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- GLOBAL FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant_AddSetCollectionTooltipSummary ( tooltip, itemLink )
  AddSetCollectionTooltipSummary ( tooltip, itemLink )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistant_OnInitialize ( control )
  IA_INVENTORY_ASSISTANT = IA_InventoryAssistant:New ( control )
end
-----------------------------------------------------------------------------------------------------------------------------------
