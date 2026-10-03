-----------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY ASSISTANT LOOT HISTORY WINDOW
-----------------------------------------------------------------------------------------------------------------------------------
IA_LootHistory = ZO_LootHistory_Shared:Subclass ( )
-----------------------------------------------------------------------------------------------------------------------------------
-- CONSTANTS
-----------------------------------------------------------------------------------------------------------------------------------
local GROUP_LOOT_BACKGROUND_COLOR = ZO_ColorDef:New ( "129bad" )
-----------------------------------------------------------------------------------------------------------------------------------
local GetFrameTimeMilliseconds = GetFrameTimeMilliseconds
local GetItemInstanceId = GetItemInstanceId
local GetItemLink = GetItemLink
local GetItemLinkEquipType = GetItemLinkEquipType
local GetItemLinkItemId = GetItemLinkItemId
local GetItemLinkItemType = GetItemLinkItemType
local GetItemLinkSetInfo = GetItemLinkSetInfo
local IsItemLinkSetCollectionPiece = IsItemLinkSetCollectionPiece
local IsItemLockedSetPiece = IsItemLockedSetPiece
local IsItemSetCollectionPieceUnlocked = IsItemSetCollectionPieceUnlocked
local IsItemStolen = IsItemStolen
local CanItemBeUsedToLearn = CanItemBeUsedToLearn
-----------------------------------------------------------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------
local function AnchorActiveEntry ( buffer, entryControl, previousEntry )
  entryControl:ClearAnchors ( )
  if previousEntry then
    if buffer.newestOnTop then
      entryControl:SetAnchor ( BOTTOMRIGHT, previousEntry, TOPRIGHT, 0, buffer.additionalEntrySpacingY )
    else
      entryControl:SetAnchor ( TOPRIGHT, previousEntry, BOTTOMRIGHT, 0, -buffer.additionalEntrySpacingY )
    end
  elseif buffer.newestOnTop then
    entryControl:SetAnchor ( BOTTOMRIGHT, buffer.control, BOTTOMRIGHT, 0, 0 )
  else
    entryControl:SetAnchor ( TOPRIGHT, buffer.control, TOPRIGHT, 0, 0 )
  end
end

local function SortActiveEntries ( buffer )
  local activeEntries = buffer.activeEntries
  local entryCount = #activeEntries
  local entryComesBefore = buffer.entryComesBefore
  for i = 2, entryCount do
    local activeEntry = activeEntries [ i ]
    local j = i - 1
    while j >= 1 and entryComesBefore ( activeEntry.entry, activeEntries [ j ].entry ) do
      activeEntries [ j + 1 ] = activeEntries [ j ]
      j = j - 1
    end
    activeEntries [ j + 1 ] = activeEntry
  end

  local previousEntry
  for i = 1, entryCount do
    local entryControl = activeEntries [ i ]
    AnchorActiveEntry ( buffer, entryControl, previousEntry )
    previousEntry = entryControl
  end

  if entryCount > 0 then
    buffer.lastAnchoredEntry = activeEntries [ #activeEntries ]
    buffer.bottomEntry = buffer.newestOnTop and activeEntries [ 1 ] or activeEntries [ #activeEntries ]
  else
    buffer.lastAnchoredEntry = nil
    buffer.bottomEntry = nil
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function DisplayEntry ( self, templateName, entry, entryNumber, hasCurrentEntries )
  local entryControl = self:AcquireEntryObject ( templateName )
  local templateData = self.templates [ templateName ]
  local offsetY = 0
  local HEADER_ITEM = true
  offsetY = self:SetupItem ( HEADER_ITEM, entry.header, templateData.headerTemplateName, templateData.headerSetup, self.headerPools, entryControl, offsetY, HEADER_ITEM )
  local lines = entry.lines
  if lines then
    local hasHeader = entry.header ~= nil
    for i = #lines, 1, -1 do
      offsetY = self:SetupItem ( hasHeader, lines [ i ], templateName, templateData.setup, self.linePools, entryControl, offsetY )
    end
  end
  entry.control = entryControl
  entryControl.entry = entry
  entryControl.setupTimeMS = GetFrameTimeMilliseconds ( )

  if self.newestOnTop then
    self.anchor:Set ( entryControl )
    if hasCurrentEntries then
      if entryNumber == 0 then
        entryControl:SetAnchor ( BOTTOMRIGHT, self.control, BOTTOMRIGHT, 0, 0 )
        self.bottomEntry:SetAnchor ( BOTTOMRIGHT, entryControl, TOPRIGHT, 0, self.additionalEntrySpacingY )
      else
        entryControl:SetAnchor ( BOTTOMRIGHT, self.lastAnchoredEntry, TOPRIGHT, 0, self.additionalEntrySpacingY )
        self.bottomEntry:SetAnchor ( BOTTOMRIGHT, entryControl, TOPRIGHT, 0, self.additionalEntrySpacingY )
      end
    elseif not self.lastAnchoredEntry then
      entryControl:SetAnchor ( BOTTOMRIGHT, self.control, BOTTOMRIGHT, 0, 0 )
    else
      entryControl:SetAnchor ( BOTTOMRIGHT, self.lastAnchoredEntry, TOPRIGHT, 0, self.additionalEntrySpacingY )
    end
  elseif hasCurrentEntries and entryNumber == 0 then
    entryControl:ClearAnchors ( )
    entryControl:SetAnchor ( TOPRIGHT, self.bottomEntry, BOTTOMRIGHT, 0, -self.additionalEntrySpacingY )
  elseif self.lastAnchoredEntry then
    entryControl:ClearAnchors ( )
    entryControl:SetAnchor ( TOPRIGHT, self.lastAnchoredEntry, BOTTOMRIGHT, 0, -self.additionalEntrySpacingY )
  else
    entryControl:ClearAnchors ( )
    entryControl:SetAnchor ( TOPRIGHT, self.control, TOPRIGHT, 0, 0 )
  end

  table.insert ( self.activeEntries, 1, entryControl )
  self.currentNumDisplayedEntries = self.currentNumDisplayedEntries + 1
  self.currentlyFadingEntries = self.currentlyFadingEntries + 1
  local subControl = entryControl:GetChild ( 1 )
  local fadeInDelayFactor = entryNumber * 67
  self:UpdateFadeInDelay ( subControl, fadeInDelayFactor )
  subControl.label:SetAlpha ( 0 )
  subControl.bg:SetAlpha ( 0 )
  subControl.icon:SetAlpha ( 0 )
  subControl.icon:SetScale ( 2 )
  self.lastAnchoredEntry = entryControl
  return entryControl
end
-----------------------------------------------------------------------------------------------------------------------------------
local function DisplayBatches ( self )
  local noMoreEntries = false
  local displayItems = 0
  local hasCurrentEntries = self.currentNumDisplayedEntries > 0
  -- Keep bottomEntry as the previous batch boundary until all new controls are anchored.
  while self:CanDisplayMore ( ) do
    local currentBatch = self.queuedBatches [ 1 ]
    if currentBatch == nil then break end
    for i = currentBatch.iterator, 1, -1 do
      if self:CanDisplayEntry ( ) then
        self:DisplayEntry ( currentBatch [ i ].templateName, currentBatch [ i ].entry, displayItems, hasCurrentEntries )
        displayItems = displayItems + 1
      else
        noMoreEntries = true
        currentBatch.iterator = i
        break
      end
    end
    if noMoreEntries then break end
    table.remove ( self.queuedBatches, 1 )
  end
  SortActiveEntries ( self )
  if displayItems > 0 then
    self.control:SetAlpha ( 1 )
    self.containerStartTimeMs = GetFrameTimeMilliseconds ( )
    self.doesContainsEntries = true
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function SetBufferDirection ( buffer, newestOnTop, entryComesBefore )
  buffer.newestOnTop = newestOnTop
  buffer.entryComesBefore = entryComesBefore
  buffer.DisplayEntry = DisplayEntry
  buffer.DisplayBatches = DisplayBatches
end
-----------------------------------------------------------------------------------------------------------------------------------
local function IsGearLootItem ( itemLinkOrName, lootType )
  if lootType ~= LOOT_TYPE_ITEM then return false end
  local itemType = GetItemLinkItemType ( itemLinkOrName )
  local equipType = GetItemLinkEquipType ( itemLinkOrName )
  return itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON or equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING
end
-----------------------------------------------------------------------------------------------------------------------------------
local function IsNonSetItemLoot ( itemLinkOrName, lootType )
  if lootType ~= LOOT_TYPE_ITEM then return false end
  return not GetItemLinkSetInfo ( itemLinkOrName, false )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function IsUncollectedSetItemLoot ( itemLinkOrName, lootType )
  if lootType ~= LOOT_TYPE_ITEM or not IsItemLinkSetCollectionPiece ( itemLinkOrName ) then return false end
  return not IsItemSetCollectionPieceUnlocked ( GetItemLinkItemId ( itemLinkOrName ) )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function GetEntrySortName ( entry )
  local line = entry.lines [ 1 ]
  local sortName = line.sortName
  if not sortName and line.control then
    sortName = zo_strlower ( line.control.label:GetText ( ) )
    line.sortName = sortName
  end
  return sortName or ""
end
-----------------------------------------------------------------------------------------------------------------------------------
local function EntryComesBefore ( entry, otherEntry )
  local line = entry.lines [ 1 ]
  local otherLine = otherEntry.lines [ 1 ]
  local isGearItem = line.isGearItem == true
  local otherIsGearItem = otherLine.isGearItem == true
  if isGearItem ~= otherIsGearItem then return isGearItem end
  return GetEntrySortName ( entry ) < GetEntrySortName ( otherEntry )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function GetPersistentEntrySortGroup ( entry )
  local entryType = entry.lines [ 1 ].entryType
  if entryType == LOOT_ENTRY_TYPE_EXPERIENCE then return 1 end
  if entryType == LOOT_ENTRY_TYPE_SKILL_EXPERIENCE then return 2 end
  if entryType == LOOT_ENTRY_TYPE_COMPANION_EXPERIENCE then return 3 end
  if entryType == LOOT_ENTRY_TYPE_CURRENCY then return 4 end
  return 5
end
-----------------------------------------------------------------------------------------------------------------------------------
local function PersistentEntryComesBefore ( entry, otherEntry )
  local sortGroup = GetPersistentEntrySortGroup ( entry )
  local otherSortGroup = GetPersistentEntrySortGroup ( otherEntry )
  if sortGroup ~= otherSortGroup then return sortGroup < otherSortGroup end
  if sortGroup == 5 then
    return GetEntrySortName ( entry ) < GetEntrySortName ( otherEntry )
  end
  return false
end
-----------------------------------------------------------------------------------------------------------------------------------
local function AddSortedEntry ( buffer, templateName, lootEntry, entryComesBefore )
  buffer:AddEntry ( templateName, lootEntry )

  local queue = buffer.queue
  local insertedIndex = #queue
  for i = 1, insertedIndex - 1 do
    if entryComesBefore ( lootEntry, queue [ i ] ) then
      for j = insertedIndex, i + 1, -1 do
        queue [ j ] = queue [ j - 1 ]
      end
      queue [ i ] = lootEntry
      return
    end
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function AddSortedNonPersistentEntry ( buffer, templateName, lootEntry )
  AddSortedEntry ( buffer, templateName, lootEntry, EntryComesBefore )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function AddSortedPersistentEntry ( buffer, templateName, lootEntry )
  AddSortedEntry ( buffer, templateName, lootEntry, PersistentEntryComesBefore )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function SetEntryText ( control, data )
  local text = data.text
  if type ( text ) == "function" then
    text = text ( data )
  end
  control.label:SetText ( text )
  if control.looterLabel then
    control.looterLabel:SetText ( data.looterDisplayName or "" )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function ReplaceAnchor ( control, point, relativeTo, relativePoint, offsetX, offsetY )
  control:ClearAnchors ( )
  control:SetAnchor ( point, relativeTo, relativePoint, offsetX, offsetY )
end

-- Entry XML defines the left-facing layout. Set the final geometry directly so
-- pooled controls do not accumulate transformations between uses.
local function ApplyAlignment ( control, rightAligned )
  rightAligned = rightAligned == true
  if control.iaLootHistoryRightAligned == rightAligned then return end

  local icon = control.icon
  local label = control.label
  local background = control.background
  local highlight = control.backgroundHighlight
  local labelAlignment = TEXT_ALIGN_LEFT
  local textureLeft = 0
  local textureRight = 1

  if rightAligned then
    labelAlignment = TEXT_ALIGN_RIGHT
    textureLeft = 1
    textureRight = 0
    ReplaceAnchor ( icon, RIGHT, control, RIGHT, 5, 0 )
    if control.statusIcon then
      ReplaceAnchor ( control.statusIcon, LEFT, icon, RIGHT, 5, 0 )
    end
    if control.looterLabel then
      ReplaceAnchor ( label, TOPRIGHT, control, TOPRIGHT, -45, 5 )
      ReplaceAnchor ( control.looterLabel, TOPRIGHT, label, TOPRIGHT, 0, 20 )
    else
      ReplaceAnchor ( label, RIGHT, icon, LEFT, -10, 0 )
    end
    ReplaceAnchor ( background, TOPRIGHT, control, TOPRIGHT, 50, 0 )
    background:SetAnchor ( BOTTOMLEFT, control, BOTTOMLEFT, -50, 0 )
    if highlight then
      ReplaceAnchor ( highlight, TOPRIGHT, background, TOPRIGHT, 20, 0 )
    end
  else
    ReplaceAnchor ( icon, LEFT, control, LEFT, -5, 0 )
    if control.statusIcon then
      ReplaceAnchor ( control.statusIcon, RIGHT, icon, LEFT, -5, 0 )
    end
    if control.looterLabel then
      ReplaceAnchor ( label, TOPLEFT, control, TOPLEFT, 45, 5 )
      ReplaceAnchor ( control.looterLabel, TOPLEFT, label, TOPLEFT, 0, 20 )
    else
      ReplaceAnchor ( label, LEFT, icon, RIGHT, 10, 0 )
    end
    ReplaceAnchor ( background, TOPLEFT, control, TOPLEFT, -50, 0 )
    background:SetAnchor ( BOTTOMRIGHT, control, BOTTOMRIGHT, 50, 0 )
    if highlight then
      ReplaceAnchor ( highlight, TOPLEFT, background, TOPLEFT, -20, 0 )
    end
  end
  label:SetHorizontalAlignment ( labelAlignment )
  if control.looterLabel then
    control.looterLabel:SetHorizontalAlignment ( labelAlignment )
  end
  background:SetTextureCoords ( textureLeft, textureRight, 0, 0.78125 )
  if highlight then
    highlight:SetTextureCoords ( textureLeft, textureRight, 0, 0.75 )
  end
  control.iaLootHistoryRightAligned = rightAligned
end
-----------------------------------------------------------------------------------------------------------------------------------
-- IMPLEMENTATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:CreateFadingStationaryControlBuffer ( control, fadeLabelAnimationName, fadeIconAnimationName, fadeContainerAnimation, anchor, maxEntries, containerShowTime, containerType )
  local lootStream = ZO_LootHistory_Shared.CreateFadingStationaryControlBuffer ( self, control, fadeLabelAnimationName, fadeIconAnimationName, fadeContainerAnimation, anchor, maxEntries, containerShowTime, containerType )
  local templateData = lootStream.templates [ self.entryTemplate ]
  local stockSetup = templateData.setup
  local stockEqualitySetup = templateData.equalitySetup
  templateData.setup = function ( lineControl, data )
    ApplyAlignment ( lineControl, false )
    stockSetup ( lineControl, data )
    SetEntryText ( lineControl, data )
    self.layoutControls [ lineControl ] = true
    ApplyAlignment ( lineControl, self.rightAligned )
  end
  templateData.equalitySetup = function ( buffer, currentEntry, newEntry )
    stockEqualitySetup ( buffer, currentEntry, newEntry )
    local data = currentEntry.lines [ 1 ]
    if data.control then
      SetEntryText ( data.control, data )
    end
  end
  return lootStream
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetContainerShowTime ( )
  local showTime = self.windowSettings.showTime
  return showTime * 1000
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetPersistentContainerShowTime ( )
  local showTime = self.windowSettings.persistentShowTime
  return showTime * 1000
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetContainerMaxEntries ( )
  return self.windowSettings.maxEntries
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetPersistentContainerMaxEntries ( )
  return self.windowSettings.persistentMaxEntries
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:CreateLootEntry ( lootData )
  if type ( lootData.text ) == "string" then
    lootData.sortName = zo_strlower ( lootData.text )
  end
  if self.currentLootItemIsGear then
    lootData.isGearItem = true
  end
  if self.currentLootItemIsGroupLoot then
    lootData.isGroupLoot = true
    if self.currentLootItemIsOtherGroupLoot then
      lootData.backgroundColor = GROUP_LOOT_BACKGROUND_COLOR
    end
  end
  if lootData.entryType == LOOT_ENTRY_TYPE_ITEM then
    lootData.isSetItem = self.currentLootItemIsSet == true
    lootData.isNonSetItem = not lootData.isSetItem
    lootData.isUncollectedSetItem = self.currentLootItemIsUncollectedSetItem == true
  end
  if self.currentLootItemIsGroupLoot then
    lootData.looterDisplayName = self.currentLootItemLooterDisplayName or ""
  else
    lootData.looterDisplayName = GetDisplayName ( )
  end
  return ZO_LootHistory_Shared.CreateLootEntry ( self, lootData )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:AddExternalLootEntry ( itemLink, quantity, looterDisplayName )
  local currentDisplayName = GetDisplayName ( )
  local isOwnLoot = looterDisplayName and looterDisplayName ~= "" and currentDisplayName and zo_strlower ( looterDisplayName ) == zo_strlower ( currentDisplayName )
  self.currentLootItemIsGroupLoot = true
  self.currentLootItemIsOtherGroupLoot = not isOwnLoot
  self.currentLootItemLooterDisplayName = looterDisplayName
  self:OnNewItemReceived ( itemLink, quantity, nil, LOOT_TYPE_ITEM, nil, GetItemLinkItemId ( itemLink ), false, false, nil, false, false )
  self.currentLootItemIsGroupLoot = nil
  self.currentLootItemIsOtherGroupLoot = nil
  self.currentLootItemLooterDisplayName = nil
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:IsEntryPersistent ( lootEntry )
  local isPersistent = lootEntry.isPersistent
--  if lootEntry.lines [ 1 ].isCraftBagItem == true then
--    isPersistent = true
--  end
  lootEntry.isPersistent = isPersistent
  return isPersistent
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:AddLootEntry ( lootEntry )
  local line = lootEntry.lines [ 1 ]
  local windowSettings = self.windowSettings
  local includeNonSetItems = windowSettings.includeNonSetItems ~= false
  local includeSetItems = windowSettings.includeSetItems ~= false
  local includeGroupLoot = windowSettings.includeGroupLoot == true
  local includeProgression = windowSettings.includeProgression ~= false
  local includeCollectibles = windowSettings.includeCollectibles ~= false
  local includeLeads = windowSettings.includeLeads ~= false
  local includeCrownCrates = windowSettings.includeCrownCrates ~= false
  local includeDefaultPersistentEntries = windowSettings.includeDefaultPersistentEntries ~= false
  local treatUncollectedSetItemsAsPersistent = windowSettings.treatUncollectedSetItemsAsPersistent == true
  local isUncollectedSetItem = line.isUncollectedSetItem == true
  if line.isGroupLoot == true and not includeGroupLoot then return end
  local entryType = line.entryType
  if entryType == LOOT_ENTRY_TYPE_ITEM then
    if line.isNonSetItem == true and not includeNonSetItems then return end
    if line.isSetItem == true and not includeSetItems then return end
  elseif entryType == LOOT_ENTRY_TYPE_MEDAL
      or entryType == LOOT_ENTRY_TYPE_KEEP_REWARD
      or entryType == LOOT_ENTRY_TYPE_TRIBUTE_CARD_UPGRADE then
    if not includeProgression then return end
  elseif entryType == LOOT_ENTRY_TYPE_COLLECTIBLE then
    if not includeCollectibles then return end
  elseif entryType == LOOT_ENTRY_TYPE_ANTIQUITY_LEAD then
    if not includeLeads then return end
  elseif entryType == LOOT_ENTRY_TYPE_CROWN_CRATE then
    if not includeCrownCrates then return end
  end
  if isUncollectedSetItem then
    lootEntry.isPersistent = treatUncollectedSetItemsAsPersistent
  end
  local isDefaultPersistentEntry = lootEntry.isPersistent == true and line.isCraftBagItem ~= true and not isUncollectedSetItem
  if isDefaultPersistentEntry and not includeDefaultPersistentEntries then return end
  if self:IsEntryPersistent ( lootEntry ) then
    AddSortedPersistentEntry ( self.lootStreamPersistent, self.entryTemplate, lootEntry )
  else
    if line.isCraftBagItem == true then
      lootEntry.isPersistent = true
    end
    AddSortedNonPersistentEntry ( self.lootStream, self.entryTemplate, lootEntry )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetBufferControllerType ( persistent, bufferGeneration )
  local generation = bufferGeneration or self.bufferGeneration or 0
  return self.bufferControllerPrefix .. ( persistent and "Persistent" or "" ) .. generation
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:InitializeFragment ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:InitializeFadingControlBuffer ( control )
  local anchor = ZO_Anchor:New ( BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0 )
  local maxEntries = self:GetContainerMaxEntries ( )
  local persistentMaxEntries = self:GetPersistentContainerMaxEntries ( )
  local bufferGeneration = self.bufferGeneration or 0
  self.lootStreamPersistent = self:CreateFadingStationaryControlBuffer ( control:GetNamedChild ( "PersistentContainer" ), "IA_LootHistory_Fade", "IA_LootHistory_IconEntrance", "IA_LootHistory_ContainerFade", anchor, persistentMaxEntries, self:GetPersistentContainerShowTime ( ), self:GetBufferControllerType ( true, bufferGeneration ) )
  self.lootStream = self:CreateFadingStationaryControlBuffer ( control:GetNamedChild ( "Container" ), "IA_LootHistory_Fade", "IA_LootHistory_IconEntrance", "IA_LootHistory_ContainerFade", anchor, maxEntries, self:GetContainerShowTime ( ), self:GetBufferControllerType ( false, bufferGeneration ) )
  SetBufferDirection ( self.lootStreamPersistent, self.newestOnTop ~= false, PersistentEntryComesBefore )
  SetBufferDirection ( self.lootStream, self.newestOnTop ~= false, EntryComesBefore )
  self.lootStreamPersistent:SetAdditionalEntrySpacingY ( -1 )
  self.lootStream:SetAdditionalEntrySpacingY ( -1 )
  self:UpdateFrame ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetEntryTemplate ( )
  local templateNumber = self.showLooter and 2 or 1
  self.entryTemplate = "IA_LootHistoryEntry" .. templateNumber .. "Left"
end
-----------------------------------------------------------------------------------------------------------------------------------
-- Rebuilt buffers must not retain their pooled controls, timelines, or anchor references.
local function DetachControl ( control )
  if control.fadeLabelAndBgTimeline then
    local timeline = control.fadeLabelAndBgTimeline
    timeline:SetHandler ( "OnStop", nil )
    timeline:Stop ( )
    timeline.control = nil
    control.fadeLabelAndBgTimeline = nil
  end
  if control.fadeIconTimeline then
    local timeline = control.fadeIconTimeline
    timeline:SetHandler ( "OnStop", nil )
    timeline:Stop ( )
    timeline.control = nil
    control.fadeIconTimeline = nil
  end
  if control.activeLines then
    ZO_ClearNumericallyIndexedTable ( control.activeLines )
    control.activeLines = nil
  end
  control.entry = nil
  control.key = nil
  control.pool = nil
  control.fadingControlBuffer = nil
  control:ClearAnchors ( )
  control:SetParent ( nil )
  control:SetHidden ( true )
end
-----------------------------------------------------------------------------------------------------------------------------------
local function DetachPoolControls ( pools )
  for _, pool in pairs ( pools or { } ) do
    for _, control in pool:ActiveAndFreeObjectIterator ( ) do
      DetachControl ( control )
    end
    pool.m_Active = { }
    pool.m_Free = { }
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
local function DiscardBuffer ( buffer )
  if not buffer then return end
  if buffer.fadeTimeline then
    local timeline = buffer.fadeTimeline
    timeline:SetHandler ( "OnStop", nil )
    timeline:Stop ( )
    if buffer.control and buffer.control.fadeTimeline == timeline then
      buffer.control.fadeTimeline = nil
    end
    timeline.controlBuffer = nil
    timeline.control = nil
    buffer.fadeTimeline = nil
  end
  buffer:ReleaseAllControls ( )
  DetachPoolControls ( buffer.headerPools )
  DetachPoolControls ( buffer.linePools )
  DetachPoolControls ( buffer.entryPools )
  buffer.activeEntries = { }
  buffer.currentEntries = { }
  buffer.queue = { }
  buffer.queuedBatches = { }
  buffer.queuedTimedEntries = { }
  buffer.lastAnchoredEntry = nil
  buffer.bottomEntry = nil
  buffer.headerPools = { }
  buffer.linePools = { }
  buffer.entryPools = { }
  buffer.templates = { }
  buffer.control = nil
  buffer.anchor = nil
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:RebuildBuffers ( )
  local oldBufferGeneration = self.bufferGeneration or 0
  if self.lootStream then
    EVENT_MANAGER:UnregisterForUpdate ( "ZO_FadingStationaryControlBuffer" .. self:GetBufferControllerType ( false, oldBufferGeneration ) )
    EVENT_MANAGER:UnregisterForUpdate ( "ZO_FadingStationaryControlBuffer" .. self:GetBufferControllerType ( true, oldBufferGeneration ) )
    DiscardBuffer ( self.lootStream )
    DiscardBuffer ( self.lootStreamPersistent )
    self.lootStream = nil
    self.lootStreamPersistent = nil
  end
  self.layoutControls = setmetatable ( { }, { __mode = "k" } )
  self.bufferGeneration = oldBufferGeneration + 1
  self:SetEntryTemplate ( )
  self:InitializeFadingControlBuffer ( self.control )
  self:SetStreamAnchors ( )
  self:UpdateFrame ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetDirection ( newestOnTop )
  self.newestOnTop = newestOnTop
  self:RebuildBuffers ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetAlignment ( rightAligned )
  rightAligned = rightAligned == true
  if self.rightAligned == rightAligned then return end
  self.rightAligned = rightAligned
  for control in pairs ( self.layoutControls or { } ) do
    ApplyAlignment ( control, self.rightAligned )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetShowLooter ( showLooter )
  self.showLooter = showLooter
  self:RebuildBuffers ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetStreamAnchors ( )
  local persistentContainer = self.control:GetNamedChild ( "PersistentContainer" )
  local container = self.control:GetNamedChild ( "Container" )
  persistentContainer:ClearAnchors ( )
  container:ClearAnchors ( )
  if self.newestOnTop then
    persistentContainer:SetAnchor ( BOTTOMRIGHT, self.control, BOTTOMRIGHT )
    container:SetAnchor ( BOTTOMRIGHT, persistentContainer, TOPRIGHT, 0, -1 )
  else
    persistentContainer:SetAnchor ( TOPRIGHT, self.control, TOPRIGHT )
    container:SetAnchor ( TOPRIGHT, persistentContainer, BOTTOMRIGHT, 0, 1 )
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:UpdateFrame ( )
  local maxEntries = self:GetContainerMaxEntries ( )
  local persistentMaxEntries = self:GetPersistentContainerMaxEntries ( )
  self.control:SetDimensions ( 402, math.max ( maxEntries, persistentMaxEntries ) * 50 )
  local frame = self.control:GetNamedChild ( "Frame" )
  frame:SetHidden ( self.locked )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:CanShowItemsInHistory ( )
  return true
end
-----------------------------------------------------------------------------------------------------------------------------------
local icons = {
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CRAFT_BAG]        = "EsoUI/Art/HUD/lootHistory_icon_craftBag.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_STOLEN]           = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_LOCKED_SET_PIECE] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_locked_set_piece.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CAN_LEARN]        = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_can_learn.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_COLLECTIONS]      = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_collections.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_ANTIQUITIES]      = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_antiquities.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CROWN_CRATE]      = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_crownCrates.dds",
}
function IA_LootHistory:GetStatusIcon ( displayType )
  return icons [ displayType ]
end
-----------------------------------------------------------------------------------------------------------------------------------
local highlights = {
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CRAFT_BAG]        = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_STOLEN]           = "EsoUI/Art/HUD/lootHistory_highlight_stolen.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_LOCKED_SET_PIECE] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CAN_LEARN]        = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_COLLECTIONS]      = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_ANTIQUITIES]      = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  [ZO_LOOT_HISTORY_DISPLAY_TYPE_CROWN_CRATE]      = "EsoUI/Art/HUD/lootHistory_highlight.dds",
}
function IA_LootHistory:GetHighlight ( displayType )
  return highlights [ displayType ]
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:GetBonusDropSourceIcon ( bonusDropSource )
  if bonusDropSource == BONUS_DROP_SOURCE_COMPANION then
    return "EsoUI/Art/HUD/lootHistory_bonusDropSourceIcon_companion.dds"
  end
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:SetLocked ( locked )
  self.locked = locked
  self.control:SetMovable ( not locked )
  self.control:SetMouseEnabled ( not locked )
  self:UpdateFrame ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:New ( control, options )
  local lootHistory = ZO_Object.New ( self )
  lootHistory.windowNumber = options.windowNumber
  lootHistory.settings = options.settings
  lootHistory.windowSettings = lootHistory.settings.lootHistory [ lootHistory.windowNumber ]
  lootHistory.eventName = "InventoryAssistantLootHistory" .. lootHistory.windowNumber
  lootHistory.bufferControllerPrefix = "InventoryAssistantLootHistory" .. lootHistory.windowNumber
  lootHistory:Initialize ( control )
  return lootHistory
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:Initialize ( control )
  self.control = control
  self.locked = true
  self.showLooter = self.windowSettings.showLooter == true
  self.rightAligned = self.windowSettings.rightAligned == true
  self.layoutControls = setmetatable ( { }, { __mode = "k" } )
  ZO_LootHistory_Shared.Initialize ( self, control )
  self.hidden = false

  local eventName = self.eventName
  self:SetDirection ( self.windowSettings.newestOnTop ~= false )
  self.control:SetAnchor ( TOPLEFT, GuiRoot, TOPLEFT, self.windowSettings.x, self.windowSettings.y )
  self:SetLocked ( self.settings.lootHistoryLocked )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function ( _, bagId, slotId, isNewItem, itemSound, _, stackCountChange, _, _, _, bonusDropSource )
    if not isNewItem or stackCountChange <= 0 then return end
    local itemLink = GetItemLink ( bagId, slotId )
    if not itemLink or itemLink == "" then return end
    self:OnNewItemReceived ( itemLink, stackCountChange, itemSound, LOOT_TYPE_ITEM, nil, GetItemInstanceId ( bagId, slotId ), bagId == BAG_VIRTUAL, IsItemStolen ( bagId, slotId ), bonusDropSource, IsItemLockedSetPiece ( bagId, slotId ), CanItemBeUsedToLearn ( bagId, slotId ) )
  end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_CURRENCY_UPDATE, function ( _, ... ) self:OnCurrencyUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_EXPERIENCE_GAIN, function ( _, ... ) self:OnExperienceGainUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_SKILL_XP_UPDATE, function ( _, ... ) self:OnSkillExperienceUpdated ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_ANTIQUITY_LEAD_ACQUIRED, function ( _, antiquityId ) self:OnAntiquityLeadAcquired ( antiquityId ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_COMPANION_EXPERIENCE_GAIN, function ( _, ... ) self:OnCompanionExperienceGainUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_COMPANION_RAPPORT_UPDATE, function ( _, ... ) self:OnCompanionRapportUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_MEDAL_AWARDED, function ( _, ... ) self:OnMedalAwarded ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_CROWN_CRATE_QUANTITY_UPDATE, function ( _, lootCrateId, oldCount, newCount ) self:OnCrownCrateQuantityUpdated ( lootCrateId, oldCount, newCount ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_ADVENTURE_ZONE_FACTION_REPUTATION_CHANGED, function ( _, newReputation, deltaReputation ) self:OnAdventureZoneFactionReputationChanged ( newReputation, deltaReputation ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_BATTLEGROUND_STATE_CHANGED, function ( _, _, newState ) if newState == BATTLEGROUND_STATE_FINISHED then self:OnBattlegroundEnteredPostGame ( ) end  end )
  ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback ( "OnCollectibleNotificationNew", function ( _, collectibleId ) self:OnNewCollectibleReceived ( collectibleId ) end )
  TRIBUTE_DATA_MANAGER:RegisterCallback ( "ProgressionUpgradeStatusChanged", function ( ... ) self:OnTributeProgressionUpgradeStatusChanged ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( eventName, EVENT_QUEST_TOOL_UPDATED, function ( _, questIndex, questName, countDelta, questItemIcon, questItemId, questItemName )
    if countDelta > 0 then
      self:OnNewItemReceived ( questItemName, countDelta, nil, LOOT_TYPE_QUEST_ITEM, questItemIcon, questItemId, false, false, BONUS_DROP_SOURCE_NONE, false, false )
    end
  end )
end
-----------------------------------------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:OnMoveStop ( )
  self.windowSettings.x = self.control:GetLeft ( )
  self.windowSettings.y = self.control:GetTop ( )
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory:OnNewItemReceived ( itemLinkOrName, stackCount, itemSound, lootType, questItemIcon, itemId, isVirtual, isStolen, bonusDropSource, isLockedSetPiece, canBeUsedToLearn )
  local isNonSetItem = IsNonSetItemLoot ( itemLinkOrName, lootType )
  local isSetItem = lootType == LOOT_TYPE_ITEM and not isNonSetItem
  local isUncollectedSetItem = IsUncollectedSetItemLoot ( itemLinkOrName, lootType )
  self.currentLootItemIsGear = IsGearLootItem ( itemLinkOrName, lootType )
  self.currentLootItemIsSet = isSetItem
  self.currentLootItemIsUncollectedSetItem = isUncollectedSetItem
  if self.currentLootItemIsGroupLoot and isUncollectedSetItem then
    isLockedSetPiece = true
  end
  ZO_LootHistory_Shared.OnNewItemReceived ( self, itemLinkOrName, stackCount, itemSound, lootType, questItemIcon, itemId, isVirtual, isStolen, bonusDropSource, isLockedSetPiece, canBeUsedToLearn )
  self.currentLootItemIsGear = nil
  self.currentLootItemIsSet = nil
  self.currentLootItemIsUncollectedSetItem = nil
end
-----------------------------------------------------------------------------------------------------------------------------------
-- GLOBAL FUNCTIONS
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory1_OnInitialized ( control )
  IA_LOOT_HISTORY1_CONTROL = control
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory2_OnInitialized ( control )
  IA_LOOT_HISTORY2_CONTROL = control
end
-----------------------------------------------------------------------------------------------------------------------------------
function IA_LootHistory_Shared_OnInitialized ( control )
  control.icon = control:GetNamedChild ( "Icon" )
  control.iconOverlayText = control.icon:GetNamedChild ( "OverlayText" )
  control.label = control:GetNamedChild ( "Label" )
  control.looterLabel = control.label:GetNamedChild ( "LooterLabel" )
  if control.looterLabel then
    control.looterLabel:SetColor ( GetItemQualityColor ( ITEM_DISPLAY_QUALITY_TRASH ):UnpackRGBA ( ) )
  end
  control.background = control:GetNamedChild ( "Bg" )
  control.statusIcon = control:GetNamedChild ( "StatusIcon" ) or control.icon:GetNamedChild ( "StatusIcon" )
  control.backgroundHighlight = control.background:GetNamedChild ( "Highlight" )
  control.iaLootHistoryRightAligned = false
end
-----------------------------------------------------------------------------------------------------------------------------------
