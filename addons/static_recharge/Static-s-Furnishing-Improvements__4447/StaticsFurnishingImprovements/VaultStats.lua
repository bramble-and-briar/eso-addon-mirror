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
local LS = LibStatic
local SFI = StaticsFurnishingImprovements


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
------------------------------------------------------------------------------------------------]]--
local VaultStats = {}


--[[------------------------------------------------------------------------------------------------
VaultStats.Initialize()
Inputs:				Parent 															- The parent object containing other required information.  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function VaultStats.Initialize()
  VaultStats.Categories = LS.PairedListNew(
    {"Services", "Conservatory", "Courtyard", "Dining", "Gallery", "Hearth", "Library", "Lighting", "Parlor", "Structures", "Suite", "Undercroft", "Workshop", "Miscellaneous"},
    {25, 12, 6, 5, 9, 8, 4, 11, 3, 13, 2, 7, 10, 14}
  )
  VaultStats.SinglesListPool = {}
  VaultStats.PairsListPool = {}
  VaultStats.eventSpace = "SFIVaultStats"

  -- Session Variables
  VaultStats.showing = false

  local function GetCategoryControls(parentControl)
    local controls = {}
    for index, category in pairs(VaultStats.Categories:GetChoices()) do
      controls[category] = GetControl(parentControl, category)
    end
    return controls
  end

  -- Controls
  VaultStats.C = {}
  local w = GetControl("SFI_Vault_Stats_Window")
  VaultStats.C.Window = w
  VaultStats.C.CloseButton = GetControl(w, "CloseButton")

  local c = GetControl(w, "StorageBar")
  VaultStats.C.StorageBar = GetCategoryControls(c)
  VaultStats.C.StorageBar.Label = GetControl(c, "Label")

  c = GetControl(w, "LegendBar")
  VaultStats.C.LegendBar = GetCategoryControls(c)

  c = GetControl(w, "Singles")
  VaultStats.C.Singles = {}
  VaultStats.C.Singles.Label = GetControl(c, "Label")
  VaultStats.C.Singles.ScrollBox = GetControl(c, "ScrollBox")

  c = GetControl(w, "Pairs")
  VaultStats.C.Pairs = {}
  VaultStats.C.Pairs.Label = GetControl(c, "Label")
  VaultStats.C.Pairs.ScrollBox = GetControl(c, "ScrollBox")

  -- Libraries

  -- Events and Callbacks
  EM:RegisterForEvent(VaultStats.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, VaultStats.UpdateStorageData)
	EM:AddFilterForEvent(VaultStats.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_FURNITURE_VAULT)
	EM:AddFilterForEvent(VaultStats.eventSpace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
  EM:RegisterForEvent(VaultStats.eventSpace, EVENT_PLAYER_ACTIVATED, VaultStats.OnPlayerActivated )

  -- Slash Commands
  SLASH_COMMANDS["/sfivaultstats"] = function() VaultStats.ShowWindow() end

  -- Keybinds
  VaultStats.AddVaultStatsKeybindButton()
  ZO_CreateStringId("SI_BINDING_NAME_SFI_Show_Vault_Stats", "Vault Stats")

  VaultStats.WindowSceneBinding()
  VaultStats.RestoreWindow()

	VaultStats.initialized = true
end


--[[------------------------------------------------------------------------------------------------
VaultStats.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function VaultStats.IsInitialized()
  return VaultStats.initialized
end


--[[------------------------------------------------------------------------------------------------
VaultStats.OnMoveStop()
Inputs:				None
Outputs:			None
Description:	Stores the new window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats.OnMoveStop()
  local sv = SFI.SV
  local c = VaultStats.C
  sv.vaultStatsLeft = c.Window:GetLeft()
	sv.vaultStatsTop = c.Window:GetTop()
end


--[[------------------------------------------------------------------------------------------------
VaultStats.RestoreWindow()
Inputs:				None
Outputs:			None
Description:	Restores the window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats.RestoreWindow()
  local sv = SFI.SV
  local c = VaultStats.C
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
VaultStats.ResetPosition()
Inputs:				None
Outputs:			None
Description:	Resets the window position.
------------------------------------------------------------------------------------------------]]--
function VaultStats.ResetPosition()
  local sv = SFI.SV
  sv.vaultStatsLeft = nil
  sv.vaultStatsTop = nil
  VaultStats.RestoreWindow()
end


--[[------------------------------------------------------------------------------------------------
VaultStats.ShowWindow()
Inputs:				show                                - (optional) forces the window to a shown state if true
Outputs:			None
Description:	Shows/Hides or Toggles the window.
------------------------------------------------------------------------------------------------]]--
function VaultStats.ShowWindow(show)
  local scene = SM:GetCurrentScene()

  if show == nil then
    VaultStats.showing = not VaultStats.showing
  else
    VaultStats.showing = show
  end
    
  if VaultStats.showing then
    VaultStats.C.Window:SetHidden(false)
    SM:SetInUIMode(true)
  else
    VaultStats.C.Window:SetHidden(true)
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats.WindowSceneBinding()
Inputs:				None                                
Outputs:			None
Description:	Binds the vault window to the required scenes.
------------------------------------------------------------------------------------------------]]--
function VaultStats.WindowSceneBinding()
  local c = VaultStats.C

  SFI.Scenes.hud:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING then
      VaultStats.ShowWindow(false)
    end
  end)

  SFI.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING and SFI.SV.vaultAutoShow then
      VaultStats.ShowWindow(true)
    end
  end)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.UpdateStorageData()
Inputs:				None
Outputs:			None
Description:	Updates the vault data.
------------------------------------------------------------------------------------------------]]--
function VaultStats.UpdateStorageData()
  if IsOwnerOfCurrentHouse() then
    local FurnitureCache = SI:GetOrCreateBagCache(BAG_FURNITURE_VAULT)
    local vaultMax = GetBagSize(BAG_FURNITURE_VAULT)
    local Categories = VaultStats.Categories:GetChoices()
    SFI.SV.Data = {}
    SFI.SV.VaultData.Singles = {}
    SFI.SV.BoundUnboundPairs = {}
    local Bound = {}
    local Unbound = {}

    for index, category in pairs(Categories) do
      SFI.SV.Data[category] = {
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
        local category = VaultStats.Categories:GetChoiceByValue(categoryId)
        SFI.Chat:Debug(zo_strformat("furnitureLink: <<1>>, categoryId: <<2>>, category: <<3>>, furnitureIndex: <<4>>", furnitureLink, categoryId, category, furnitureIndex))
        SFI.SV.Data[category].total = SFI.SV.Data[category].total + 1

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
          table.insert(SFI.SV.VaultData.Singles, item)
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
        SFI.SV.Data[category].ratio = SFI.SV.Data[category].total / vaultMax
        SFI.SV.Data[category].percent = SFI.SV.Data[category].ratio * 100
      end
    end

    -- Sort tables by item name
    LS.Sort(SFI.SV.VaultData.Singles, nil, "name")
    LS.Sort(Bound, nil, "name")

    -- find bound/unbound matches
    for _, boundItem in ipairs(Bound) do
      for _, unboundItem in ipairs(Unbound) do
        if boundItem.id == unboundItem.id then
          local pair = {Bound = boundItem, Unbound = unboundItem}
          table.insert(SFI.SV.BoundUnboundPairs, pair)
        end
      end
    end

    SFI.Chat:Debug("Vault Data updated.")
  end
  if not ZO_IsTableEmpty(SFI.SV.Data) then
    VaultStats.UpdateStorageBar()
    VaultStats.UpdateLegendBar()
    VaultStats.UpdateSinglesScrollList()
    VaultStats.UpdatePairsScrollList()
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats.UpdateStorageBar()
Inputs:				None
Outputs:			None
Description:	Updates the visual storage bar.
------------------------------------------------------------------------------------------------]]--
function VaultStats.UpdateStorageBar()
  local vaultMax = GetBagSize(BAG_FURNITURE_VAULT) 
  local vaultUsed = 0
  for i, v in pairs(SFI.SV.Data) do
    vaultUsed = vaultUsed + v.total
  end
  local vaultPercent = math.floor((vaultUsed / vaultMax) * 100)
  
  VaultStats.C.StorageBar.Label:SetText(zo_strformat("<<1>>/<<2>> (<<3>>%)", vaultUsed, vaultMax, vaultPercent))
  for index, category in pairs(VaultStats.Categories:GetChoices()) do
    local data = SFI.SV.Data[category]
    local width = math.floor(data.ratio * 372)
    local c = VaultStats.C.StorageBar[category]
    c:SetWidth(width)
    c:SetHandler("OnMouseEnter", function(self_) VaultStats.ShowTooltip(category) end)
		c:SetHandler("OnMouseExit", function(self_) VaultStats.HideTooltip() end)
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats.UpdateLegendBar()
Inputs:				None
Outputs:			None
Description:	Updates the visual legend bar.
------------------------------------------------------------------------------------------------]]--
function VaultStats.UpdateLegendBar()
  for index, category in pairs(VaultStats.Categories:GetChoices()) do
    local data = SFI.SV.Data[category]
    local c = VaultStats.C.LegendBar[category]
    local label = GetControl(c, "Info")
    label:SetText(zo_strformat("<<1>> (<<2>>%)", data.total, data.percent))
  end
end


--[[------------------------------------------------------------------------------------------------
VaultStats.UpdateSinglesScrollList()
Inputs:				None
Outputs:			None
Description:	Updates the Singles list.
------------------------------------------------------------------------------------------------]]--
function VaultStats.UpdateSinglesScrollList()
	for i,v in pairs(VaultStats.SinglesListPool) do
		v:SetHidden(true)
	end
	local parent = VaultStats.C.Singles.ScrollBox
	local name = "SFISinglesListEntry"
	local template = "SFIVaultStatsSinglesList"
	for i,v in ipairs(SFI.SV.VaultData.Singles) do
		local c = {}
		if VaultStats.SinglesListPool[i] then
			c = VaultStats.SinglesListPool[i]
		else
			c = WM:CreateControlFromVirtual(name, parent, template, i)
			c:SetParent(parent:GetNamedChild("ScrollChild"))
			table.insert(VaultStats.SinglesListPool, c)
			c:ClearAnchors()
			c:SetAnchor(TOPLEFT, ScrollBoxScrollChild, TOPLEFT, 4, (i-1) * 24)
		end
    local label = c:GetNamedChild("Label")
		label:SetText(zo_strformat("|t100%:100%:<<1>>|t <<2>>", v.icon, v.link))
		c:SetHidden(false)
		c:SetHandler("OnMouseEnter", function(self_) VaultStats.ShowItemTooltip(v.link) end)
		c:SetHandler("OnMouseExit", function(self_) VaultStats.HideItemTooltip() end)
	end
  VaultStats.C.Singles.Label:SetText(zo_strformat("Single Stack Items (<<1>>)", #SFI.SV.VaultData.Singles))
end


--[[------------------------------------------------------------------------------------------------
VaultStats.UpdatePairsScrollList()
Inputs:				None
Outputs:			None
Description:	Updates the Pairs list.
------------------------------------------------------------------------------------------------]]--
function VaultStats.UpdatePairsScrollList()
	for i,v in pairs(VaultStats.PairsListPool) do
		v:SetHidden(true)
	end
	local parent = VaultStats.C.Pairs.ScrollBox
	local name = "SFIPairsListEntry"
	local template = "SFIVaultStatsBoundUnboundPairsList"
	for i,v in ipairs(SFI.SV.BoundUnboundPairs) do
		local c = {}
		if VaultStats.PairsListPool[i] then
			c = VaultStats.PairsListPool[i]
		else
			c = WM:CreateControlFromVirtual(name, parent, template, i)
			c:SetParent(parent:GetNamedChild("ScrollChild"))
			table.insert(VaultStats.PairsListPool, c)
			c:ClearAnchors()
			c:SetAnchor(TOPLEFT, ScrollBoxScrollChild, TOPLEFT, 4, (i-1) * 24)
		end
    local item = c:GetNamedChild("Item")
    local quantity = c:GetNamedChild("Quantity")
		item:SetText(zo_strformat("|t100%:100%:<<1>>|t <<2>>", v.Bound.icon, v.Bound.link))
    quantity:SetText(zo_strformat("<<1>>/<<2>>", v.Bound.stack, v.Unbound.stack))
		c:SetHidden(false)
    c:SetHandler("OnMouseEnter", function(self_) VaultStats.ShowItemTooltip(v.Bound.link) end)
		c:SetHandler("OnMouseExit", function(self_) VaultStats.HideItemTooltip() end)
	end
  VaultStats.C.Pairs.Label:SetText(zo_strformat("Bound/Unbound Doubled Up Items (<<1>>)", #SFI.SV.BoundUnboundPairs))
end


--[[------------------------------------------------------------------------------------------------
VaultStats.RemoveItemsFromSinglesList()
Inputs:				None
Outputs:			None
Description:	Removes all of the items in the singles list from the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function VaultStats.RemoveItemsFromSinglesList()
	local scene = SM:GetCurrentScene()
  if scene ~= SFI.Scenes.furnitureVaultScene then
    SFI.Chat:Msg("Furnishing Vault isn't open.")
    return
  end

  local i = 1
  local bag = BAG_FURNITURE_VAULT
  local list = SFI.SV.VaultData.Singles

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

      ClearCursor()
      i = i + 1
      if i <= #list then
        zo_callLater(tryTransfer, 500)
      end
    end
  end

  zo_callLater(tryTransfer, 500)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.RemoveItemsFromPairsList(bound)
Inputs:				bound                               - if true will extract the bound items.
Outputs:			None
Description:	Removes all of the items in the pairs list from the furnishing vault.
------------------------------------------------------------------------------------------------]]--
function VaultStats.RemoveItemsFromPairsList(bound)
	local scene = SM:GetCurrentScene()
  if scene ~= SFI.Scenes.furnitureVaultScene then
    SFI.Chat:Msg("Furnishing Vault isn't open.")
    return
  end

  local i = 1
  local bag = BAG_FURNITURE_VAULT
  local list = SFI.SV.BoundUnboundPairs

  local function tryTransfer()
    local index
    if bound then
      index = list[i].Bound.slotIndex
    else
      index = list[i].Unbound.slotIndex
    end

    if not DoesBagHaveSpaceFor(BAG_BACKPACK, bag, index) then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_INVENTORY_ERROR_INVENTORY_FULL)
    else
      -- Furniture Vault items can only be transferred to the Backpack.
      -- When the stack count exceeds the maximum stack size, show the
      -- Item Transfer dialog to allow the partial transfer of items.
      -- Other source bags simply show the Item Transfer dialog.
      local showTransferDialog = true
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
          transferDialog:StartTransfer(bag, index, BAG_BACKPACK)
      end

      ClearCursor()
      i = i + 1
      if i <= #list then
        zo_callLater(tryTransfer, 500)
      end
    end
  end

  zo_callLater(tryTransfer, 500)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.ShowTooltip(category)
Inputs:				index                               - the category to show the info for.
Outputs:			None
Description:	Shows the tooltip for the category item.
------------------------------------------------------------------------------------------------]]--
function VaultStats.ShowTooltip(category)
	local total = SFI.SV.Data[category].total
  local percent = SFI.SV.Data[category].percent
  local control = VaultStats.C.StorageBar[category]
	ZO_Tooltips_ShowTextTooltip(control, TOP, zo_strformat("<<1>>\n<<2>> (<<3>>%)", category, total, percent))
end


--[[------------------------------------------------------------------------------------------------
VaultStats.HideTooltip()
Inputs:				None
Outputs:			None
Description:	Hides the tooltip.
------------------------------------------------------------------------------------------------]]--
function VaultStats.HideTooltip()
	ZO_Tooltips_HideTextTooltip()
end


--[[------------------------------------------------------------------------------------------------
VaultStats.ShowItemTooltip()
Inputs:				link                                - the link of the item to show
Outputs:			None
Description:	Shows the tooltip for the linked item.
------------------------------------------------------------------------------------------------]]--
function VaultStats.ShowItemTooltip(link)
	InitializeTooltip(ItemTooltip, VaultStats.C.Window, RIGHT, -5, 0, LEFT)
	ItemTooltip:SetLink(link)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.HideItemTooltip()
Inputs:				None
Outputs:			None
Description:	Hides the tooltip.
------------------------------------------------------------------------------------------------]]--
function VaultStats.HideItemTooltip()
	ClearTooltip(ItemTooltip)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.AddVaultStatsKeybindButton()
Inputs:				None
Outputs:			None
Description:	Adds the vault stats keybind to the furniture vault scene.
------------------------------------------------------------------------------------------------]]--
function VaultStats.AddVaultStatsKeybindButton()
	local furnitureVaultLeftKeybindStrip = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		name = "Vault Stats",
		keybind = "SFI_Deposit_Same_From_House",
		callback = function() VaultStats.ShowWindow() end,
	}

	SFI.Scenes.furnitureVaultScene:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWING then
			KEYBIND_STRIP:AddKeybindButton(furnitureVaultLeftKeybindStrip)
		elseif newState == SCENE_HIDDEN then
			KEYBIND_STRIP:RemoveKeybindButton(furnitureVaultLeftKeybindStrip)
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
VaultStats.OnPlayerActivated(initial)
Inputs:				initial                             - true if first load after login
Outputs:			None
Description:	Updates the vault data when loading into a player owned house.
------------------------------------------------------------------------------------------------]]--
function VaultStats.OnPlayerActivated(eventCode, initial)
  VaultStats.UpdateStorageData()
end


--[[------------------------------------------------------------------------------------------------
VaultStats.GetParent()
Inputs:				None
Outputs:			Parent          										- The parent object of this object.
Description:	Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
function VaultStats.GetParent()
  return VaultStats.Parent
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements.VaultStats = VaultStats