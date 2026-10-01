local function IA_LootHistoryDisplayEntry ( self, templateName, entry, entryNumber, hasCurrentEntries )
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
  if self.newestOnTop and entryNumber == 0 then
    self.bottomEntry = entryControl
  elseif not self.newestOnTop then
    self.bottomEntry = entryControl
  end
  return entryControl
end

local function IA_LootHistoryDisplayBatches ( self )
  local noMoreEntries = false
  local displayItems = 0
  local hasCurrentEntries = self.currentNumDisplayedEntries > 0
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
  if displayItems > 0 then
    self.control:SetAlpha ( 1 )
    self.containerStartTimeMs = GetFrameTimeMilliseconds ( )
    self.doesContainsEntries = true
  end
end

local function IA_LootHistorySetBufferDirection ( buffer, newestOnTop )
  buffer.newestOnTop = newestOnTop
  buffer.DisplayEntry = IA_LootHistoryDisplayEntry
  buffer.DisplayBatches = IA_LootHistoryDisplayBatches
end

function IA_LootHistory_Shared_OnInitialized ( control )
  control.icon = control:GetNamedChild ( "Icon" )
  control.iconOverlayText = control.icon:GetNamedChild ( "OverlayText" )
  control.label = control:GetNamedChild ( "Label" )
  control.background = control:GetNamedChild ( "Bg" )
  control.statusIcon = control:GetNamedChild ( "StatusIcon" ) or control.icon:GetNamedChild ( "StatusIcon" )
  control.backgroundHighlight = control.background:GetNamedChild ( "Highlight" )
end

IA_LootHistory = ZO_LootHistory_Shared:Subclass ( )

function IA_LootHistory:New ( control )
  local lootHistory = ZO_Object.New ( self )
  lootHistory:Initialize ( control )
  return lootHistory
end

function IA_LootHistory:Initialize ( control )
  self.control = control
  self.locked = true
  ZO_LootHistory_Shared.Initialize ( self, control )
  self.hidden = false
end

function IA_LootHistory:InitializeFragment ( )
end

function IA_LootHistory:InitializeFadingControlBuffer ( control )
  local anchor = ZO_Anchor:New ( BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0 )
  local maxEntries = self.settings and self.settings.lootHistoryMaxEntries or 6
  local bufferGeneration = self.bufferGeneration or 0
  self.lootStreamPersistent = self:CreateFadingStationaryControlBuffer ( control:GetNamedChild ( "PersistentContainer" ), "IA_LootHistory_Fade", "IA_LootHistory_IconEntrance", "IA_LootHistory_ContainerFade", anchor, maxEntries, self:GetPersistentContainerShowTime ( ), "InventoryAssistantPersistent" .. bufferGeneration )
  self.lootStream = self:CreateFadingStationaryControlBuffer ( control:GetNamedChild ( "Container" ), "IA_LootHistory_Fade", "IA_LootHistory_IconEntrance", "IA_LootHistory_ContainerFade", anchor, maxEntries, self:GetContainerShowTime ( ), "InventoryAssistant" .. bufferGeneration )
  IA_LootHistorySetBufferDirection ( self.lootStreamPersistent, self.newestOnTop ~= false )
  IA_LootHistorySetBufferDirection ( self.lootStream, self.newestOnTop ~= false )
  self.lootStreamPersistent:SetAdditionalEntrySpacingY ( -1 )
  self.lootStream:SetAdditionalEntrySpacingY ( -1 )
  self:UpdateFrame ( )
end

function IA_LootHistory:SetEntryTemplate ( )
  self.entryTemplate = self.rightAligned and "IA_LootHistoryEntryRight" or "IA_LootHistoryEntryLeft"
end

function IA_LootHistory:RebuildBuffers ( )
  local oldBufferGeneration = self.bufferGeneration or 0
  if self.lootStream then
    self.lootStream:ReleaseAllControls ( )
    self.lootStreamPersistent:ReleaseAllControls ( )
    EVENT_MANAGER:UnregisterForUpdate ( "ZO_FadingStationaryControlBufferInventoryAssistant" .. oldBufferGeneration )
    EVENT_MANAGER:UnregisterForUpdate ( "ZO_FadingStationaryControlBufferInventoryAssistantPersistent" .. oldBufferGeneration )
  end
  self.bufferGeneration = oldBufferGeneration + 1
  self:SetEntryTemplate ( )
  self:InitializeFadingControlBuffer ( self.control )
  self:SetStreamAnchors ( )
  self:UpdateFrame ( )
end

function IA_LootHistory:SetDirection ( newestOnTop )
  self.newestOnTop = newestOnTop
  self:RebuildBuffers ( )
end

function IA_LootHistory:SetAlignment ( rightAligned )
  self.rightAligned = rightAligned
  self:RebuildBuffers ( )
end

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

function IA_LootHistory:UpdateFrame ( )
  local maxEntries = self.settings and self.settings.lootHistoryMaxEntries or 6
  self.control:SetDimensions ( 382, maxEntries * 50 )
  local frame = self.control:GetNamedChild ( "Frame" )
  frame:SetHidden ( self.locked )
end

function IA_LootHistory:CanShowItemsInHistory ( )
  return true
end

function IA_LootHistory:GetStatusIcon ( displayType )
  local icons = {
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CRAFT_BAG] = "EsoUI/Art/HUD/lootHistory_icon_craftBag.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_STOLEN] = "EsoUI/Art/Inventory/inventory_stolenItem_icon.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_LOCKED_SET_PIECE] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_locked_set_piece.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CAN_LEARN] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_can_learn.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_COLLECTIONS] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_collections.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_ANTIQUITIES] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_antiquities.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CROWN_CRATE] = "EsoUI/Art/HUD/Keyboard/lootHistory_icon_crownCrates.dds",
  }
  return icons [ displayType ]
end

function IA_LootHistory:GetHighlight ( displayType )
  local highlights = {
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CRAFT_BAG] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_STOLEN] = "EsoUI/Art/HUD/lootHistory_highlight_stolen.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_LOCKED_SET_PIECE] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CAN_LEARN] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_COLLECTIONS] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_ANTIQUITIES] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
    [ZO_LOOT_HISTORY_DISPLAY_TYPE_CROWN_CRATE] = "EsoUI/Art/HUD/lootHistory_highlight.dds",
  }
  return highlights [ displayType ]
end

function IA_LootHistory:GetBonusDropSourceIcon ( bonusDropSource )
  if bonusDropSource == BONUS_DROP_SOURCE_COMPANION then
    return "EsoUI/Art/HUD/lootHistory_bonusDropSourceIcon_companion.dds"
  end
end

function IA_LootHistory:SetLocked ( locked )
  self.locked = locked
  self.control:SetMovable ( not locked )
  self.control:SetMouseEnabled ( not locked )
  self:UpdateFrame ( )
end

function IA_LootHistory:OnMoveStop ( )
  self.settings.lootHistoryX = self.control:GetLeft ( )
  self.settings.lootHistoryY = self.control:GetTop ( )
end

function IA_LootHistory:OnInitialized ( settings )
  self.settings = settings
  self.rightAligned = settings.lootHistoryRightAligned == true
  self:SetDirection ( settings.lootHistoryNewestOnTop ~= false )
  self:RebuildBuffers ( )
  self.control:SetAnchor ( TOPLEFT, GuiRoot, TOPLEFT, settings.lootHistoryX, settings.lootHistoryY )
  self:SetLocked ( settings.lootHistoryLocked )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function ( _, bagId, slotId, isNewItem, itemSound, _, stackCountChange, _, _, _, bonusDropSource )
    if not isNewItem or stackCountChange <= 0 then return end
    local itemLink = GetItemLink ( bagId, slotId )
    if not itemLink or itemLink == "" then return end
    self:OnNewItemReceived ( itemLink, stackCountChange, itemSound, LOOT_TYPE_ITEM, nil, GetItemInstanceId ( bagId, slotId ), bagId == BAG_VIRTUAL, IsItemStolen ( bagId, slotId ), bonusDropSource, IsItemLockedSetPiece ( bagId, slotId ), CanItemBeUsedToLearn ( bagId, slotId ) )
  end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_CURRENCY_UPDATE, function ( _, ... ) self:OnCurrencyUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_EXPERIENCE_GAIN, function ( _, ... ) self:OnExperienceGainUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_SKILL_XP_UPDATE, function ( _, ... ) self:OnSkillExperienceUpdated ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_ANTIQUITY_LEAD_ACQUIRED, function ( _, antiquityId ) self:OnAntiquityLeadAcquired ( antiquityId ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_COMPANION_EXPERIENCE_GAIN, function ( _, ... ) self:OnCompanionExperienceGainUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_COMPANION_RAPPORT_UPDATE, function ( _, ... ) self:OnCompanionRapportUpdate ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_MEDAL_AWARDED, function ( _, ... ) self:OnMedalAwarded ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_CROWN_CRATE_QUANTITY_UPDATE, function ( _, lootCrateId, oldCount, newCount ) self:OnCrownCrateQuantityUpdated ( lootCrateId, oldCount, newCount ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_ADVENTURE_ZONE_FACTION_REPUTATION_CHANGED, function ( _, newReputation, deltaReputation ) self:OnAdventureZoneFactionReputationChanged ( newReputation, deltaReputation ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_BATTLEGROUND_STATE_CHANGED, function ( _, _, newState )
    if newState == BATTLEGROUND_STATE_FINISHED then self:OnBattlegroundEnteredPostGame ( ) end
  end )
  ZO_COLLECTIBLE_DATA_MANAGER:RegisterCallback ( "OnCollectibleNotificationNew", function ( _, collectibleId ) self:OnNewCollectibleReceived ( collectibleId ) end )
  TRIBUTE_DATA_MANAGER:RegisterCallback ( "ProgressionUpgradeStatusChanged", function ( ... ) self:OnTributeProgressionUpgradeStatusChanged ( ... ) end )
  EVENT_MANAGER:RegisterForEvent ( "InventoryAssistantLootHistory", EVENT_QUEST_TOOL_UPDATED, function ( _, questIndex, questName, countDelta, questItemIcon, questItemId, questItemName )
    if countDelta > 0 then
      self:OnNewItemReceived ( questItemName, countDelta, nil, LOOT_TYPE_QUEST_ITEM, questItemIcon, questItemId, false, false, BONUS_DROP_SOURCE_NONE, false, false )
    end
  end )
end

function IA_LootHistory_OnInitialized ( control )
  IA_LOOT_HISTORY_CONTROL = control
end
