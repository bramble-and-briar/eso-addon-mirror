-----------------------------------------------------------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------------------------------------------------------
local IA_GENERIC_ROW = 1
local IA_HEADER_ROW  = 2
local IA_ITEM_ROW    = 3

local IA_UNCOLLECTED_SET_ICON = "esoui/art/inventory/inventory_locked_set_piece_icon.dds"

local IA_SET_COLLECTION_TILE_TEMPLATE = "ZO_ItemSetCollectionPieceTile_Keyboard_Control"
local IA_SET_COLLECTION_TILE_SIZE = ZO_ITEM_SET_COLLECTION_PIECE_TILE_KEYBOARD_DIMENSIONS
local IA_SET_COLLECTION_TILE_PADDING = 4
local IA_SET_COLLECTION_TILES_PER_ROW = 4
local IA_SET_COLLECTION_TOOLTIP_MIN_WIDTH = 300
local IA_SET_COLLECTION_TOOLTIP_SIDE_PADDING = 16
local IA_SET_COLLECTION_TOOLTIP_BOTTOM_PADDING = 16
local IA_SET_COLLECTION_TOOLTIP_HEADER_HEIGHT = 56

local function IA_InventoryAssistantList_SetTooltipDimensions ( width, height )
  IA_CharacterTooltip:SetDimensions ( width, height )
  IA_CharacterTooltipTopLevel:SetDimensions ( width, height )
end

local function IA_InventoryAssistantList_AutoFitSetCollectionTooltip ( tilePool, fallbackHeight )
  local tooltipTop = IA_CharacterTooltip:GetTop ( )
  local maxBottom = IA_CharacterTooltipProgress:GetBottom ( )

  for _, tileControl in pairs ( tilePool:GetActiveObjects ( ) ) do
    local tileBottom = tileControl:GetBottom ( )
    if tileBottom and tileBottom > maxBottom then
      maxBottom = tileBottom
    end
  end

  if tooltipTop and maxBottom and maxBottom > tooltipTop then
    local autoHeight = zo_ceil ( maxBottom - tooltipTop + IA_SET_COLLECTION_TOOLTIP_BOTTOM_PADDING )
    IA_CharacterTooltip:SetHeight ( autoHeight )
    IA_CharacterTooltipTopLevel:SetHeight ( autoHeight )
  else
    IA_CharacterTooltip:SetHeight ( fallbackHeight )
    IA_CharacterTooltipTopLevel:SetHeight ( fallbackHeight )
  end
end

local function IA_InventoryAssistantList_QueueSetCollectionTooltipAutoFit ( tilePool, fallbackHeight )
  -- First render pass can report stale bounds for newly created pooled controls.
  zo_callLater ( function ( )
    if not IA_CharacterTooltip:IsHidden ( ) then
      IA_InventoryAssistantList_AutoFitSetCollectionTooltip ( tilePool, fallbackHeight )
    end
  end, 0 )
end

local function IA_InventoryAssistantList_GetSetCollectionTilePool ( )
  if not IA_CharacterTooltip.pieceTilePool then
    local tilePool = ZO_ControlPool:New ( IA_SET_COLLECTION_TILE_TEMPLATE, IA_CharacterTooltipPieces, "PieceTile" )
    tilePool:SetCustomResetBehavior ( ZO_DefaultGridTileEntryReset )
    IA_CharacterTooltip.pieceTilePool = tilePool
  end
  return IA_CharacterTooltip.pieceTilePool
end

local function IA_InventoryAssistantList_GetSetCollectionPieceData ( setId )
  local pieceDataList = { }
  if not setId or setId == 0 then
    return pieceDataList
  end

  local numPieces = GetNumItemSetCollectionPieces ( setId ) or 0
  for pieceIndex = 1, numPieces do
    local pieceId, slot = GetItemSetCollectionPieceInfo ( setId, pieceIndex )
    if pieceId and slot then
      local pieceData = ITEM_SET_COLLECTIONS_DATA_MANAGER:GetOrCreateItemSetCollectionPieceData ( pieceId, slot )
      if pieceData then
        table.insert ( pieceDataList, pieceData )
      end
    end
  end

  return pieceDataList
end

local function IA_InventoryAssistantList_HasSetCollectionData ( equipSlots )
  local setId = equipSlots and equipSlots.setId
  if not setId or setId == 0 then
    return false
  end

  local numPieces = GetNumItemSetCollectionPieces ( setId ) or 0
  return numPieces > 0
end

local function IA_InventoryAssistantList_GetSetReconstructionTransmuteCost ( setId )
  if not setId or setId == 0 then
    return nil
  end

  local cost = GetItemReconstructionCurrencyOptionCost ( setId, CURT_CHAOTIC_CREATIA )
  return cost and cost > 0 and cost or nil
end

local function IA_InventoryAssistantList_LayoutSetCollectionTooltip ( equipSlots )
  local setId = equipSlots and equipSlots.setId
  local setName = equipSlots and equipSlots.setName
  local tilePool = IA_InventoryAssistantList_GetSetCollectionTilePool ( )
  tilePool:ReleaseAllObjects ( )

  local pieceDataList = IA_InventoryAssistantList_GetSetCollectionPieceData ( setId )
  local tileCount = #pieceDataList
  local columns = tileCount > 0 and zo_min ( IA_SET_COLLECTION_TILES_PER_ROW, tileCount ) or 1
  local rows = tileCount > 0 and zo_ceil ( tileCount / IA_SET_COLLECTION_TILES_PER_ROW ) or 1
  local tileStride = IA_SET_COLLECTION_TILE_SIZE + IA_SET_COLLECTION_TILE_PADDING

  for index, pieceData in ipairs ( pieceDataList ) do
    local tileControl = tilePool:AcquireObject ( )
    local column = ( index - 1 ) % IA_SET_COLLECTION_TILES_PER_ROW
    local row = zo_floor ( ( index - 1 ) / IA_SET_COLLECTION_TILES_PER_ROW )
    tileControl:SetAnchor ( TOPLEFT, IA_CharacterTooltipPieces, TOPLEFT, column * tileStride, row * tileStride )
    ZO_DefaultGridTileEntrySetup ( tileControl, pieceData )
  end

  local width = columns * IA_SET_COLLECTION_TILE_SIZE + ( columns - 1 ) * IA_SET_COLLECTION_TILE_PADDING
  local height = rows * IA_SET_COLLECTION_TILE_SIZE + ( rows - 1 ) * IA_SET_COLLECTION_TILE_PADDING
  IA_CharacterTooltipPieces:SetDimensions ( width, height )

  local tooltipWidth = zo_max ( IA_SET_COLLECTION_TOOLTIP_MIN_WIDTH, width + IA_SET_COLLECTION_TOOLTIP_SIDE_PADDING * 2 )
  local tooltipHeight = IA_SET_COLLECTION_TOOLTIP_HEADER_HEIGHT + height + IA_SET_COLLECTION_TOOLTIP_BOTTOM_PADDING
  IA_InventoryAssistantList_SetTooltipDimensions ( tooltipWidth, tooltipHeight )
  IA_InventoryAssistantList_AutoFitSetCollectionTooltip ( tilePool, tooltipHeight )
  IA_InventoryAssistantList_QueueSetCollectionTooltipAutoFit ( tilePool, tooltipHeight )

  IA_CharacterTooltipTitle:SetText ( setName )

  local numPieces = GetNumItemSetCollectionPieces ( setId ) or 0
  local numUnlocked = ( setId and setId ~= 0 ) and ( GetNumItemSetCollectionSlotsUnlocked ( setId ) or 0 ) or 0
  if numPieces > 0 then
    local transmuteCost = IA_InventoryAssistantList_GetSetReconstructionTransmuteCost ( setId )
    if transmuteCost then
      IA_CharacterTooltipProgress:SetText ( string.format ( "%d/%d collected", numUnlocked, numPieces ) )
      IA_CharacterTooltipCost:SetText ( string.format ( "|c66CCFF%d |t20:20:esoui/art/currency/currency_seedcrystal_32.dds|t|r", transmuteCost ) )
    else
      IA_CharacterTooltipProgress:SetText ( string.format ( "%d/%d collected", numUnlocked, numPieces ) )
      IA_CharacterTooltipCost:SetText ( "" )
    end
  else
    IA_CharacterTooltipProgress:SetText ( "No set collection data" )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY ASSISTANT SCROLLING ITEM LIST
-----------------------------------------------------------------------------------------------------------------------------------
IA_InventoryAssistantList = ZO_SortFilterList:Subclass ( )
-----------------------------------------------------------------------------------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:New ( frame, control )
	local inventoryAssistantList = ZO_SortFilterList.New ( self, control )
	inventoryAssistantList:Setup ( frame, control )
	return inventoryAssistantList
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:Setup ( frame, control )
  self.frame = frame
	ZO_ScrollList_AddDataType ( self.list, IA_GENERIC_ROW, "IA_GenericRow", 30, function ( control, data ) self:SetupGenericRow ( control, data ) end )
	ZO_ScrollList_AddDataType ( self.list, IA_HEADER_ROW, "IA_HeaderRow", 40, function ( control, data ) self:SetupHeaderRow ( control, data ) end )
	ZO_ScrollList_AddDataType ( self.list, IA_ITEM_ROW, "IA_ItemRow", 30, function ( control, data ) self:SetupItemRow ( control, data ) end )
	ZO_ScrollList_EnableHighlight ( self.list, "ZO_ThinListHighlight" )
	self:SetAlternateRowBackgrounds ( false )
  self:Reset ( )
  self:RefreshData ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:SetupGenericRow ( control, data )
  control.list = self
	control.data = data
	control:GetNamedChild ( "Name" ).normalColor = ZO_DEFAULT_TEXT
  control:GetNamedChild ( "Name" ):SetText ( data.text )
	ZO_SortFilterList.SetupRow ( self, control, data )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:SetupHeaderRow ( control, data )
  control.list = self
	control.data = data
	control:GetNamedChild ( "Name" ).normalColor = data.header.color 
  if data.header.itemCount == data.header.showCount then 
    control:GetNamedChild ( "Name" ):SetText ( string.format ( data.header.text1, data.header.name, data.header.itemCount ) )
  else
    control:GetNamedChild ( "Name" ):SetText ( string.format ( data.header.text2, data.header.name, data.header.showCount, data.header.itemCount ) )
  end
	ZO_SortFilterList.SetupRow ( self, control, data )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:SetupItemRow ( control, data )
  control.list = self
	control.data = data
	control:GetNamedChild ( "Name" ).nonRecolorable = true
	control:GetNamedChild ( "Name" ):SetText ( data.name )

  control:GetNamedChild ( "Bag" ).nonRecolorable = true
	control:GetNamedChild ( "Bag" ):SetText( data.bagName )
  control:GetNamedChild ( "Bag" ):SetDimensionConstraints ( 0, 0, IA_INVENTORY_ASSISTANT.settings.bagNameWidth, 0 )
    
  control:GetNamedChild ( "Level" ).nonRecolorable = true
--	control:GetNamedChild ( "Level" ):SetText ( data.level )

--[[
  if data.item.groupLoot then
    control:GetNamedChild ( "Icon" ):SetAlpha ( 0.5 )
    control:GetNamedChild ( "Name" ):SetAlpha ( 0.5 )
    control:GetNamedChild ( "Bag" ):SetAlpha ( 0.5 )
    control:GetNamedChild ( "Tradeable" ):SetAlpha ( 0.5 )
  else
    control:GetNamedChild ( "Icon" ):SetAlpha ( 1 )
    control:GetNamedChild ( "Name" ):SetAlpha ( 1 )
    control:GetNamedChild ( "Bag" ):SetAlpha ( 1 )
    control:GetNamedChild ( "Tradeable" ):SetAlpha ( 1 )
  end
]]--

  control:GetNamedChild ( "Marker" ).nonRecolorable = true
  control:GetNamedChild ( "Marker" ):SetHidden ( true )
  control:GetNamedChild ( "Marker" ):ClearIcons ( ) 
  data.item.markers = IA_INVENTORY_ASSISTANT:GetItemMarkers ( data.item.itemId, data.item.uniqueId, data.item.bagId, data.item.stolen )
  if IsItemLinkSetCollectionPiece ( data.item.link ) and not IsItemSetCollectionPieceUnlocked ( GetItemLinkItemId ( data.item.link ) ) then
    table.insert ( data.item.markers, { icon = IA_UNCOLLECTED_SET_ICON, color = { r=1, g=1, b=1, a=1 } } )
  end
  if data.item.markers and #data.item.markers > 0 then
    for _, v in ipairs ( data.item.markers ) do
      control:GetNamedChild ( "Marker" ):AddIcon ( v )
    end
    control:GetNamedChild ( "Marker" ):SetHidden ( false )
  end
  if data.icon then
    control:GetNamedChild ( "Icon" ):SetTexture ( data.icon )
    control:GetNamedChild ( "Icon" ):SetHidden ( false )
  else
    control:GetNamedChild ( "Icon" ):SetHidden ( true )
    control:GetNamedChild ( "Icon" ):SetTexture ( nil )
  end
  if data.item.bopTimeEnds and data.item.bopTimeEnds > GetTimeStamp ( ) then
    control:GetNamedChild ( "Tradeable" ):SetHidden ( false )
  else
    control:GetNamedChild ( "Tradeable" ):SetHidden ( true )
  end
  if data.item.locked then
    control:GetNamedChild ( "Marker" ):SetHidden ( true )
    if IA_INVENTORY_ASSISTANT.settings.actionQueue.unlock [ data.item.uniqueId ] then
      control:GetNamedChild ( "Marker" ):AddIcon ( { icon = ZO_KEYBOARD_LOCKED_ICON, color = { r=0.33, g=0.33, b=0.33, a=1 } } )
    else
      control:GetNamedChild ( "Marker" ):AddIcon ( { icon = ZO_KEYBOARD_LOCKED_ICON, color = { r=1, g=1, b=1, a=1 } } )
    end
    control:GetNamedChild ( "Marker" ):SetHidden ( false )
  elseif IA_INVENTORY_ASSISTANT.settings.actionQueue.lock [ data.item.uniqueId ] then 
    control:GetNamedChild ( "Marker" ):SetHidden ( true )
    control:GetNamedChild ( "Marker" ):AddIcon ( { icon = ZO_KEYBOARD_LOCKED_ICON, color = { r=0.33, g=0.33, b=0.33, a=1 } } )
    control:GetNamedChild ( "Marker" ):SetHidden ( false )
  end
	ZO_SortFilterList.SetupRow ( self, control, data )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- LIST MANIPULATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:Reset ( )
	local scrollData = ZO_ScrollList_GetDataList ( self.list )
	ZO_ClearNumericallyIndexedTable ( scrollData )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:AddText ( data )
	local scrollData = ZO_ScrollList_GetDataList ( self.list )
	table.insert ( scrollData, ZO_ScrollList_CreateDataEntry ( IA_GENERIC_ROW, data ) )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:AddHeader ( header, equipSlots )
	local scrollData = ZO_ScrollList_GetDataList ( self.list )
	local data = { header = header, equipSlots = equipSlots }
	table.insert ( scrollData, ZO_ScrollList_CreateDataEntry ( IA_HEADER_ROW, data ) )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:AddData ( text, item, icon, itemLink, level, bagName, itemId, uniqueId )
	local scrollData = ZO_ScrollList_GetDataList ( self.list )
	local data = { item = item, name = text, icon = icon, itemLink = itemLink, level = level, bagName = bagName, itemId = itemId, uniqueId = uniqueId }
	table.insert ( scrollData, ZO_ScrollList_CreateDataEntry ( IA_ITEM_ROW, data ) )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- FILTERING
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:DisableFilters ( )
  self.isFilteringEnabled = false
  self:RefreshFilters ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:EnableFilters ( )
  self.isFilteringEnabled = true
  self:RefreshFilters ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList:FilterScrollList ( )
  if self.isFilteringEnabled then 
    d( "FilterScrollList called" )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList_OnMouseEnter ( control )
	control.list:Row_OnMouseEnter ( control )
  if control.data.itemLink then 
    InitializeTooltip ( ItemTooltip, control.list.frame, TOPLEFT, 0, 0, TOPRIGHT )
    local item = control.data.item
    local currentCharacterId = zo_strformat ( "<<1>>", GetCurrentCharacterId ( ) )
    local slotStillMatches = item.charId == currentCharacterId
      and ( item.bagId == BAG_BACKPACK or item.bagId == BAG_WORN )
      and zo_getSafeId64Key ( GetItemUniqueId ( item.bagId, item.slotIndex ) ) == item.uniqueId

    if slotStillMatches then
      ItemTooltip.SetBagItem_IA ( ItemTooltip, item.bagId, item.slotIndex )
    else
      ItemTooltip.SetLink_IA ( ItemTooltip, control.data.itemLink )
    end
--    IA_InventoryAssistant_AddSetCollectionTooltipSummary ( ItemTooltip, control.data.itemLink )

  elseif control.data.equipSlots and IA_InventoryAssistantList_HasSetCollectionData ( control.data.equipSlots ) then
    InitializeTooltip ( IA_CharacterTooltip, control.list.frame, TOPLEFT, 0, 0, TOPRIGHT )
    IA_InventoryAssistantList_LayoutSetCollectionTooltip ( control.data.equipSlots )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_InventoryAssistantList_OnMouseExit ( control )
	control.list:Row_OnMouseExit ( control )
	ClearTooltip ( ItemTooltip )
  ClearTooltip ( IA_CharacterTooltip )
  if IA_CharacterTooltip.pieceTilePool then
    IA_CharacterTooltip.pieceTilePool:ReleaseAllObjects ( )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
