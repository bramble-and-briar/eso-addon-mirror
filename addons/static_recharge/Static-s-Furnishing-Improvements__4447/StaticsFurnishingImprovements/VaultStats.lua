--[[------------------------------------------------------------------------------------------------
Title:          Settings
Author:         Static_Recharge
Description:    Creates and controls the settings menu and related saved variables.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local WM = WINDOW_MANAGER
local SM = SCENE_MANAGER
local LCM = LibCustomMenu
local EM = EVENT_MANAGER
local SI = SHARED_INVENTORY


--[[------------------------------------------------------------------------------------------------
VaultStats Class Initialization
VaultStats    													          - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :OnMoveStop()                                  - Stores the new window position.
├─ :RestoreWindow()                               - Restores the window position.
├─ :ResetPosition()                               - Resets the window position.
├─ :ShowWindow()                                  - Shows/Hides or Toggles the window.
├─ :UpdateStorageData()                           - Updates the vault data.
├─ :UpdateStorageBar()                            - Updates the visual storage bar.
├─ :UpdateLegendBar()                             - Updates the legend bar.
├─ :UpdateSinglesScrollList()                     - Updates the singles list.
├─ :UpdatePairsScrollList()                       - Updates the pairs list.
├─ :RemoveItemsFromSinglesList()                  - Removes all of the items in the singles list from the furnishing vault.
├─ :RemoveItemsFromPairsList(bound)               - Removes all of the items in the pairs list from the furnishing vault.
├─ :ShowTooltip(category)                         - Shows the tooltip for the category item.
├─ :HideTooltip()                                 - Hides the category tooltip.
├─ :ShowItemTooltip(link)                         - Shows the tooltip for the indexed item.
├─ :HideItemTooltip()                             - Hides the item tooltip.
├─ :AddVaultStatsKeybindButton()                  - Adds the vault stats keybind to the furniture vault scene.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local VaultStats = {}


--[[------------------------------------------------------------------------------------------------
VaultStats:Initialize(Parent)
Inputs:				Parent 															- The parent object containing other required information.  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function VaultStats:Initialize(Parent)
  self.Parent = Parent
  self.Categories = LibStatic:PairedListNew(
    {"Services", "Conservatory", "Courtyard", "Dining", "Gallery", "Hearth", "Library", "Lighting", "Parlor", "Structures", "Suite", "Undercroft", "Workshop", "Miscellaneous"},
    {25, 12, 6, 5, 9, 8, 4, 11, 3, 13, 2, 7, 10, 14}
  )
  self.SinglesListPool = {}
  self.PairsListPool = {}
  self.eventSpace = "SFIVaultStats"

  -- Session Variables
  self.showing = false

  local function GetCategoryControls(parentControl)
    local controls = {}
    for index, category in pairs(self.Categories:GetChoices()) do
      controls[category] = GetControl(parentControl, category)
    end
    return controls
  end

  -- Controls
  self.C = {}
  local w = GetControl("SFI_Vault_Stats_Window")
  self.C.Window = w
  self.C.CloseButton = GetControl(w, "CloseButton")

  local c = GetControl(w, "StorageBar")
  self.C.StorageBar = GetCategoryControls(c)
  self.C.StorageBar.Label = GetControl(c, "Label")

  c = GetControl(w, "LegendBar")
  self.C.LegendBar = GetCategoryControls(c)

  c = GetControl(w, "Singles")
  self.C.Singles = {}
  self.C.Singles.Label = GetControl(c, "Label")
  self.C.Singles.ScrollBox = GetControl(c, "ScrollBox")

  c = GetControl(w, "Pairs")
  self.C.Pairs = {}
  self.C.Pairs.Label = GetControl(c, "Label")
  self.C.Pairs.ScrollBox = GetControl(c, "ScrollBox")

  -- Libraries

  -- Events and Callbacks
  EM:RegisterForEvent(self.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(...) self:UpdateStorageData() end)
	EM:AddFilterForEvent(self.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_FURNITURE_VAULT)
	EM:AddFilterForEvent(self.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
  EM:RegisterForEvent(self.eventSpace, EVENT_PLAYER_ACTIVATED, function(_, ...) self:OnPlayerActivated(initial) end)

  -- Slash Commands
  SLASH_COMMANDS["/sfivaultstats"] = function() self:ShowWindow() end

  -- Keybinds
  self:AddVaultStatsKeybindButton()
  ZO_CreateStringId("SI_BINDING_NAME_SFI_Deposit_Same_From_House", "Vault Stats")

  self:WindowSceneBinding()
  self:RestoreWindow()

	self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
VaultStats:IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function VaultStats:IsInitialized()
  return self.initialized
end


--[[------------------------------------------------------------------------------------------------
VaultStats:OnMoveStop()
Inputs:				None
Outputs:			None
Description:	Stores the new window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats:OnMoveStop()
  local Parent = self:GetParent()
  local sv = Parent.SV
  local c = self.C
  sv.vaultStatsLeft = c.Window:GetLeft()
	sv.vaultStatsTop = c.Window:GetTop()
end


--[[------------------------------------------------------------------------------------------------
VaultStats:RestoreWindow()
Inputs:				None
Outputs:			None
Description:	Restores the window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats:RestoreWindow()
  local Parent = self:GetParent()
  local sv = Parent.SV
  local c = self.C
  local left = sv.vaultStatsLeft
	local top = sv.vaultStatsTop
	if left ~= nil and top ~= nil then
		c.Window:ClearAnchors()
		c.Window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
  else
    c.Window:ClearAnchors()
    c.Window:SetAnchor(CENTER, GuiRoot, CENTER)
	end
end


--[[------------------------------------------------------------------------------------------------
VaultStats:ResetPosition()
Inputs:				None
Outputs:			None
Description:	Resets the window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats:ResetPosition()
  local Parent = self:GetParent()
  local sv = Parent.SV
  sv.vaultStatsLeft = nil
  sv.vaultStatsTop = nil
  self:RestoreWindow()
end


--[[------------------------------------------------------------------------------------------------
VaultStats:ShowWindow()
Inputs:				show                                - (optional) forces the window to a shown state if true
Outputs:			None
Description:	Shows/Hides or Toggles the window.
------------------------------------------------------------------------------------------------]]--
function VaultStats:ShowWindow(show)
  local Parent = self:GetParent()
  local scene = SM:GetCurrentScene()

  if show == nil then
    self.showing = not self.showing
  else
    self.showing = show
  end
    
  if self.showing then
    self.C.Window:SetHidden(false)
    SM:SetInUIMode(true)
  else
    self.C.Window:SetHidden(true)
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats:WindowSceneBinding()
Inputs:				None                                
Outputs:			None
Description:	Binds the vault window to the required scenes.
------------------------------------------------------------------------------------------------]]--
function VaultStats:WindowSceneBinding()
  local Parent = self:GetParent()
  local c = self.C

  Parent.Scenes.hud:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING then
      self:ShowWindow(false)
    end
  end)

  Parent.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING and Parent.SV.vaultAutoShow then
      self:ShowWindow(true)
    end
  end)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:UpdateStorageData()
Inputs:				None
Outputs:			None
Description:	Updates the vault data.
------------------------------------------------------------------------------------------------]]--
function VaultStats:UpdateStorageData()
  local Parent = self:GetParent()
  if IsOwnerOfCurrentHouse() then
    local FurnitureCache = SI:GetOrCreateBagCache(BAG_FURNITURE_VAULT)
    local vaultMax = GetBagSize(BAG_FURNITURE_VAULT)
    local Categories = self.Categories:GetChoices()
    Parent.SV.Data = {}
    Parent.SV.VaultData.Singles = {}
    Parent.SV.BoundUnboundPairs = {}
    local Bound = {}
    local Unbound = {}

    for index, category in pairs(Categories) do
      Parent.SV.Data[category] = {
        total = 0,
        ratio = 0,
        percent = 0,
      }
    end

    for furnitureIndex, furnitureData in pairs(FurnitureCache) do
      if HasItemInSlot(BAG_FURNITURE_VAULT, furnitureIndex) then
        -- store category data
        local furnitureLink = GetItemLink(BAG_FURNITURE_VAULT, furnitureIndex)
        local categoryId = GetFurnitureDataInfo(GetItemLinkFurnitureDataId(furnitureLink))
        local category = self.Categories:GetChoiceByValue(categoryId)
        Parent.Chat:Debug(zo_strformat("furnitureLink: <<1>>, categoryId: <<2>>, category: <<3>>, furnitureIndex: <<4>>", furnitureLink, categoryId, category, furnitureIndex))
        Parent.SV.Data[category].total = Parent.SV.Data[category].total + 1

        -- store single stack data
        --local icon, stack = GetItemInfo(BAG_FURNITURE_VAULT, furnitureIndex)
        local id = GetItemId(BAG_FURNITURE_VAULT, furnitureIndex)
        local item = {
            link = furnitureLink,
            icon = furnitureData.iconFile,
            id = id,
            stack = furnitureData.stackCount,
            slotIndex = furnitureIndex,
            name = furnitureData.name,
          }
        if item.stack == 1 then
          table.insert(Parent.SV.VaultData.Singles, item)
        end

        -- store bound/unbound data
        local bound = IsItemBound(BAG_FURNITURE_VAULT, furnitureIndex)
        if bound then
          table.insert(Bound, item)
        else
          table.insert(Unbound, item)
        end
      end

      -- add ratio and percent values
      for index, category in pairs(Categories) do
        Parent.SV.Data[category].ratio = Parent.SV.Data[category].total / vaultMax
        Parent.SV.Data[category].percent = Parent.SV.Data[category].ratio * 100
      end
    end

    -- Sort tables by item name
    LibStatic:Sort(Parent.SV.VaultData.Singles, nil, "name")
    LibStatic:Sort(Bound, nil, "name")

    -- find bound/unbound matches
    for _, boundItem in ipairs(Bound) do
      for _, unboundItem in ipairs(Unbound) do
        if boundItem.id == unboundItem.id then
          local pair = {Bound = boundItem, Unbound = unboundItem}
          table.insert(Parent.SV.BoundUnboundPairs, pair)
        end
      end
    end

    Parent.Chat:Debug("Vault Data updated.")
  end
  if not ZO_IsTableEmpty(Parent.SV.Data) then
    self:UpdateStorageBar()
    self:UpdateLegendBar()
    self:UpdateSinglesScrollList()
    self:UpdatePairsScrollList()
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats:UpdateStorageBar()
Inputs:				None
Outputs:			None
Description:	Updates the visual storage bar.
------------------------------------------------------------------------------------------------]]--
function VaultStats:UpdateStorageBar()
  local Parent = self:GetParent()
  local vaultMax = GetBagSize(BAG_FURNITURE_VAULT) 
  local vaultUsed = 0
  for i, v in pairs(Parent.SV.Data) do
    vaultUsed = vaultUsed + v.total
  end
  local vaultPercent = math.floor((vaultUsed / vaultMax) * 100)
  
  self.C.StorageBar.Label:SetText(zo_strformat("<<1>>/<<2>> (<<3>>%)", vaultUsed, vaultMax, vaultPercent))
  for index, category in pairs(self.Categories:GetChoices()) do
    local data = Parent.SV.Data[category]
    local width = math.floor(data.ratio * 372)
    local c = self.C.StorageBar[category]
    c:SetWidth(width)
    c:SetHandler("OnMouseEnter", function(self_) self:ShowTooltip(category) end)
		c:SetHandler("OnMouseExit", function(self_) self:HideTooltip() end)
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats:UpdateLegendBar()
Inputs:				None
Outputs:			None
Description:	Updates the visual legend bar.
------------------------------------------------------------------------------------------------]]--
function VaultStats:UpdateLegendBar()
  local Parent = self:GetParent()
  for index, category in pairs(self.Categories:GetChoices()) do
    local data = Parent.SV.Data[category]
    local c = self.C.LegendBar[category]
    local label = GetControl(c, "Info")
    label:SetText(zo_strformat("<<1>> (<<2>>%)", data.total, data.percent))
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats:UpdateSinglesScrollList()
Inputs:				None
Outputs:			None
Description:	Updates the Singles list.
------------------------------------------------------------------------------------------------]]--
function VaultStats:UpdateSinglesScrollList()
  local Parent = self:GetParent()
	for i,v in pairs(self.SinglesListPool) do
		v:SetHidden(true)
	end
	local parent = self.C.Singles.ScrollBox
	local name = "SFISinglesListEntry"
	local template = "SFIVaultStatsSinglesList"
	for i,v in ipairs(Parent.SV.VaultData.Singles) do
		local c = {}
		if self.SinglesListPool[i] then
			c = self.SinglesListPool[i]
		else
			c = WM:CreateControlFromVirtual(name, parent, template, i)
			c:SetParent(parent:GetNamedChild("ScrollChild"))
			table.insert(self.SinglesListPool, c)
			c:ClearAnchors()
			c:SetAnchor(TOPLEFT, ScrollBoxScrollChild, TOPLEFT, 4, (i-1) * 24)
		end
    local label = c:GetNamedChild("Label")
		label:SetText(zo_strformat("|t100%:100%:<<1>>|t <<2>>", v.icon, v.link))
		c:SetHidden(false)
		c:SetHandler("OnMouseEnter", function(self_) self:ShowItemTooltip(v.link) end)
		c:SetHandler("OnMouseExit", function(self_) self:HideItemTooltip() end)
	end
  self.C.Singles.Label:SetText(zo_strformat("Single Stack Items (<<1>>)", #Parent.SV.VaultData.Singles))
end


--[[------------------------------------------------------------------------------------------------
VaultStats:UpdatePairsScrollList()
Inputs:				None
Outputs:			None
Description:	Updates the Pairs list.
------------------------------------------------------------------------------------------------]]--
function VaultStats:UpdatePairsScrollList()	
  local Parent = self:GetParent()
	for i,v in pairs(self.PairsListPool) do
		v:SetHidden(true)
	end
	local parent = self.C.Pairs.ScrollBox
	local name = "SFIPairsListEntry"
	local template = "SFIVaultStatsBoundUnboundPairsList"
	for i,v in ipairs(Parent.SV.BoundUnboundPairs) do
		local c = {}
		if self.PairsListPool[i] then
			c = self.PairsListPool[i]
		else
			c = WM:CreateControlFromVirtual(name, parent, template, i)
			c:SetParent(parent:GetNamedChild("ScrollChild"))
			table.insert(self.PairsListPool, c)
			c:ClearAnchors()
			c:SetAnchor(TOPLEFT, ScrollBoxScrollChild, TOPLEFT, 4, (i-1) * 24)
		end
    local item = c:GetNamedChild("Item")
    local quantity = c:GetNamedChild("Quantity")
		item:SetText(zo_strformat("|t100%:100%:<<1>>|t <<2>>", v.Bound.icon, v.Bound.link))
    quantity:SetText(zo_strformat("<<1>>/<<2>>", v.Bound.stack, v.Unbound.stack))
		c:SetHidden(false)
    c:SetHandler("OnMouseEnter", function(self_) self:ShowItemTooltip(v.Bound.link) end)
		c:SetHandler("OnMouseExit", function(self_) self:HideItemTooltip() end)
	end
  self.C.Pairs.Label:SetText(zo_strformat("Bound/Unbound Doubled Up Items (<<1>>)", #Parent.SV.BoundUnboundPairs))
end


--[[------------------------------------------------------------------------------------------------
VaultStats:RemoveItemsFromSinglesList()
Inputs:				None
Outputs:			None
Description:	Removes all of the items in the singles list from the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function VaultStats:RemoveItemsFromSinglesList()
  local Parent = self:GetParent()
	local scene = SM:GetCurrentScene()
  if scene ~= Parent.Scenes.furnitureVaultScene then
    Parent.Chat:Msg("Furnishing Vault isn't open.")
    return
  end

  local i = 1
  local bag = BAG_FURNITURE_VAULT
  local list = Parent.SV.VaultData.Singles

  local function tryTransfer()
    if not DoesBagHaveSpaceFor(BAG_BACKPACK, bag, list[i].slotIndex) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
    else
        -- Furniture Vault items can only be transferred to the Backpack.
        -- When the stack count exceeds the maximum stack size, show the
        -- Item Transfer dialog to allow the partial transfer of items.
        -- Other source bags simply show the Item Transfer dialog.
        local showTransferDialog = true
        if IsFurnitureVault(bag) then
            local stackSize, maxStackSize = GetSlotStackSize(bag, list[i].slotIndex)
            if stackSize <= maxStackSize then
                showTransferDialog = false
                if IsProtectedFunction("PickupInventoryItem") then
              CallSecureProtected("PickupInventoryItem", bag, list[i].slotIndex)
            else
              PickupInventoryItem(bag, list[i].slotIndex)
            end
            if IsProtectedFunction("PlaceInTransfer") then
              CallSecureProtected("PlaceInTransfer")
            else
              PlaceInTransfer()
            end
            end
        end

        if showTransferDialog then
            local transferDialog = SYSTEMS:GetObject("ItemTransferDialog")
            transferDialog:StartTransfer(bag, list[i].slotIndex, BAG_BACKPACK)
        end
    end

    ClearCursor()
    i = i + 1
    if i <= #list then
      zo_callLater(tryTransfer, 500)
    end
  end

  zo_callLater(tryTransfer, 500)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:RemoveItemsFromPairsList(bound)
Inputs:				bound                               - if true will extract the bound items.
Outputs:			None
Description:	Removes all of the items in the pairs list from the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function VaultStats:RemoveItemsFromPairsList(bound)
  local Parent = self:GetParent()
	local scene = SM:GetCurrentScene()
  if scene ~= Parent.Scenes.furnitureVaultScene then
    Parent.Chat:Msg("Furnishing Vault isn't open.")
    return
  end

  local i = 1
  local bag = BAG_FURNITURE_VAULT
  local list = Parent.SV.BoundUnboundPairs

  local function tryTransfer()
    if not DoesBagHaveSpaceFor(BAG_BACKPACK, bag, list[i].slotIndex) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
    else
        -- Furniture Vault items can only be transferred to the Backpack.
        -- When the stack count exceeds the maximum stack size, show the
        -- Item Transfer dialog to allow the partial transfer of items.
        -- Other source bags simply show the Item Transfer dialog.
        local showTransferDialog = true
        local index
        if bound then
          index = list[i].Bound.slotIndex
        else
          index = list[i].Unbound.slotIndex
        end
        if IsFurnitureVault(bag) then
            local stackSize, maxStackSize = GetSlotStackSize(bag, index)
            if stackSize <= maxStackSize then
                showTransferDialog = false
                if IsProtectedFunction("PickupInventoryItem") then
              CallSecureProtected("PickupInventoryItem", bag, index)
            else
              PickupInventoryItem(bag, index)
            end
            if IsProtectedFunction("PlaceInTransfer") then
              CallSecureProtected("PlaceInTransfer")
            else
              PlaceInTransfer()
            end
            end
        end

        if showTransferDialog then
            local transferDialog = SYSTEMS:GetObject("ItemTransferDialog")
            transferDialog:StartTransfer(bag, list[i].slotIndex, BAG_BACKPACK)
        end
    end

    ClearCursor()
    i = i + 1
    if i <= #list then
      zo_callLater(tryTransfer, 500)
    end
  end

  zo_callLater(tryTransfer, 500)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:ShowTooltip(category)
Inputs:				index                               - the category to show the info for.
Outputs:			None
Description:	Shows the tooltip for the category item.
------------------------------------------------------------------------------------------------]]--
function VaultStats:ShowTooltip(category)
  local Parent = self:GetParent()
	local total = Parent.SV.Data[category].total
  local percent = Parent.SV.Data[category].percent
  local control = self.C.StorageBar[category]
	ZO_Tooltips_ShowTextTooltip(control, TOP, zo_strformat("<<1>>\n<<2>> (<<3>>%)", category, total, percent))
end


--[[------------------------------------------------------------------------------------------------
VaultStats:HideTooltip()
Inputs:				None
Outputs:			None
Description:	Hides the tooltip.
------------------------------------------------------------------------------------------------]]--
function VaultStats:HideTooltip()
	ZO_Tooltips_HideTextTooltip()
end


--[[------------------------------------------------------------------------------------------------
VaultStats:ShowItemTooltip()
Inputs:				link                                - the link of the item to show
Outputs:			None
Description:	Shows the tooltip for the linked item.
------------------------------------------------------------------------------------------------]]--
function VaultStats:ShowItemTooltip(link)
	InitializeTooltip(ItemTooltip, self.C.Window, RIGHT, -5, 0, LEFT)
	ItemTooltip:SetLink(link)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:HideItemTooltip()
Inputs:				None
Outputs:			None
Description:	Hides the tooltip.
------------------------------------------------------------------------------------------------]]--
function VaultStats:HideItemTooltip()
	ClearTooltip(ItemTooltip)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:AddVaultStatsKeybindButton()
Inputs:				None
Outputs:			None
Description:	Adds the vault stats keybind to the furniture vault scene.
------------------------------------------------------------------------------------------------]]--
function VaultStats:AddVaultStatsKeybindButton()
  local Parent = self:GetParent()
	local furnitureVaultLeftKeybindStrip = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		name = "Vault Stats",
		keybind = "SFI_Deposit_Same_From_House",
		callback = function() self:ShowWindow() end,
	}

	Parent.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING then
			KEYBIND_STRIP:AddKeybindButton(furnitureVaultLeftKeybindStrip)
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButton(furnitureVaultLeftKeybindStrip)
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
VaultStats:OnPlayerActivated(initial)
Inputs:				initial                             - true if first load after login
Outputs:			None
Description:	Updates the vault data when loading into a player owned house.
------------------------------------------------------------------------------------------------]]--
function VaultStats:OnPlayerActivated(initial)
  self:UpdateStorageData()
end


--[[------------------------------------------------------------------------------------------------
VaultStats:GetParent()
Inputs:				None
Outputs:			Parent          										- The parent object of this object.
Description:	Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
function VaultStats:GetParent()
  return self.Parent
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements.VaultStats = VaultStats