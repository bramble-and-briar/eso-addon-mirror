local HH = HouseHotkey

local LHAS = LibHarvensAddonSettings

local LRM = LibRadialMenu

local LIBRADIAL_WHEEL = HOTBAR_CATEGORY_MAX_VALUE + 100

local currentSettings

local EntryIndexName

local EntryIndex

local Status

--Credit to LibConsoleDialogs for the technique
local dialogSettings = LHAS.AddonSettings:Subclass()

function HH:CreateDialog(title)
	local options = {
		allowDefaults = true,
		allowRefresh = false
	}
	local dialog = dialogSettings:New(title, options)
	dialog.headerData = {titleText = title}
	return dialog
end

HH.dialogCallStack = {}

local orgSelect = dialogSettings.Select
function dialogSettings:Show()
	LHAS:Initialize()
	if self.container == nil then
		self.container = LHAS.container
		self:InitHandlers()
	end
	if LHAS.scene:IsShowing() and currentSettings then
		HH.dialogCallStack[#HH.dialogCallStack + 1] = currentSettings
	end
	orgSelect(self)
	if self.selected then
		currentSettings = self
	end

	ZO_GamepadGenericHeader_RefreshData(LHAS.scrollList.header, self.headerData)

	if LHAS.scene:IsShowing() then
		self:RefreshSelection()
	else
		SCENE_MANAGER:Push(LHAS.scene:GetName())
	end
end

local wheelOptions = {
  { name = GetString(SI_HOTBARCATEGORY10), data = HOTBAR_CATEGORY_QUICKSLOT_WHEEL},
  { name = GetString(SI_HOTBARCATEGORY13), data = HOTBAR_CATEGORY_ALLY_WHEEL},
  { name = GetString(SI_HOTBARCATEGORY12), data = HOTBAR_CATEGORY_MEMENTO_WHEEL},
  { name = GetString(SI_HOTBARCATEGORY14), data = HOTBAR_CATEGORY_TOOL_WHEEL},
  { name = GetString(SI_HOTBARCATEGORY11), data = HOTBAR_CATEGORY_EMOTE_WHEEL},
}


if LRM ~= nil then
  table.insert(wheelOptions, { name = HH.Lang.LRM_WHEEL, data = LIBRADIAL_WHEEL})
end

local slotOptions = {
      { name = "1 - N", data = 4 },
      { name = "2 - NW", data = 5 },
      { name = "3 - W", data = 6 },
      { name = "4 - SW", data = 7 },
      { name = "5 - S", data = 8 },
      { name = "6 - SE", data = 1 },
      { name = "7 - E", data = 2 },
      { name = "8 - NE", data = 3 },
    }
    
local function getSelectedHouse(data)
    local house
    if data then
      house = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(data.dataSource.collectibleId)
    elseif GAMEPAD_COLLECTIONS_BOOK and GAMEPAD_COLLECTIONS_BOOK.collectionList and GAMEPAD_COLLECTIONS_BOOK.collectionList.list then
      selectedItem = GAMEPAD_COLLECTIONS_BOOK.collectionList.list:GetTargetData()
      if selectedItem and selectedItem.dataSource.categoryData and selectedItem.dataSource.categoryData.IsHousingCategory and not selectedItem.dataSource:IsLocked() then
        house = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(selectedItem.dataSource.collectibleId)
      end
    end
    return house
end

HH.selectedHouse = nil
HH.selectedTourHouse = nil

function HH.createPopup(targetHouse, owner)
  if type(targetHouse) == "function" then
    house = targetHouse()
  else
    house = targetHouse
  end

  local HH_Lang = HH.Lang
  local UseExterior = false
  local Name, Icon, IconName, Category, CategoryName, SlotNum
  
  local panel = HH:CreateDialog(HH.Lang.HOTBAR_OPTIONS)

  panel:AddSetting {
    type = LHAS.ST_LABEL,
    label = function()
      return HH_Lang.CREATE_QUICKSLOT
    end,
  }

  panel:AddSetting {
    type = LHAS.ST_LABEL,
    label = function()
      if house and house:GetFormattedName() then
        return "|cebc034"..house:GetFormattedName().."|r"
      end
      return ""
    end,
  }
  panel:AddSetting {
    type = LHAS.ST_LABEL,
    label = function()
      if owner then
        return "|c695d5c"..owner.."|r\r\n"
      end
      return ""
    end,
  }
  
  panel:AddSetting({
    type = LHAS.ST_DROPDOWN,
    label = HH_Lang.WHEEL_CATEGORY,
    items = wheelOptions,
    getFunction = function() return CategoryName or GetString(SI_HOTBARCATEGORY10) end,
    setFunction = function(var, itemName, itemData)
      CategoryName = itemName
      Category = tonumber(itemData.data)
      panel:UpdateControls()
    end,
    default = GetString(SI_HOTBARCATEGORY10),
  })
  
  panel:AddSetting {
      type = LHAS.ST_DROPDOWN,
      label = HH_Lang.WHEEL_SLOT,
      items = function()
        if Category == LIBRADIAL_WHEEL and LRM ~= nil then
          local slotsObj = {}
          for i = 1, LRM.vars.numSlots do 
            table.insert(slotsObj, { name = tostring(i), data = i })
          end
          return slotsObj
        else
          return slotOptions
        end
      end,
      getFunction = function() return EntryIndexName end,
      setFunction = function(var, itemName, itemData)
        EntryIndexName = itemName
        EntryIndex = tonumber(itemData.data)
      end,
    }
  
  panel:AddSetting({
    type = LHAS.ST_ICONPICKER,
    label = HH_Lang.WHEEL_ICON,
    items = HH.IconList,
    getFunction = function() return Icon  end,
    setFunction = function(var, iconIndex, iconPath)
      IconName = iconPath
      Icon = iconIndex
    end,
  })
  
  panel:AddSetting {
    type = LHAS.ST_EDIT,
    label = HH_Lang.WHEEL_NAME,
    getFunction = function() return Name or house:GetFormattedName() or "" end,
    setFunction = function(text) Name = text end,
    default = house:GetFormattedName()
  }
  
  panel:AddSetting({
    type = LHAS.ST_CHECKBOX,
    label = HH.Lang.HOUSE_EXTERIOR,
    default = false,
    setFunction = function(state)
        UseExterior = state
    end,
    getFunction = function()
        return UseExterior
    end,
    disable = function()
      return owner ~= "self"
    end
  })
  
  panel:AddSetting {
    type = LHAS.ST_BUTTON,
    label = HH_Lang.WHEEL_APPLY,
    buttonText = HH_Lang.WHEEL_APPLY,
    clickHandler  = function()
      HH.SV.Command[Category or HOTBAR_CATEGORY_QUICKSLOT_WHEEL][EntryIndex or 4] = {
        ["name"] = Name or house:GetFormattedName(),
        ["icon"] = IconName or HH.IconList[1],
        ["house"] = house:GetReferenceId(),
        ["exterior"] = UseExterior or false,
        ["houseName"] = house:GetFormattedName(),
        ["houseOwner"] = house.owner or owner or "self",
        ["slotNum"] = EntryIndex
      }
      Status = HH.Lang.STATUS_ADDED
      HH.assignHouse:UpdateControls()
      HH.settingsPanel:UpdateControls()
    end
  }
  panel:AddSetting {
    type = LHAS.ST_LABEL,
    label = function()
      return Status or " "
    end
  }
  HH.assignHouse = panel
end

function HH.AddAssignHouse(newState)
    HH.assign = {
      alignment = KEYBIND_STRIP_ALIGN_RIGHT,
      {

          name = HH.Lang.ADD_TO_HOTBAR,
          keybind = "UI_SHORTCUT_LEFT_STICK",
          visible = function()
            if GAMEPAD_COLLECTIONS_BOOK.currentList and GAMEPAD_COLLECTIONS_BOOK.currentList.list then 
              selectedItem = GAMEPAD_COLLECTIONS_BOOK:GetCurrentTargetData()
              if selectedItem then
                local house = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(selectedItem.dataSource.collectibleId)
                if house and not house:IsLocked() and selectedItem.dataSource.categoryData.IsHousingCategory then
                  return true
                end
              end
            end
            return false
          end,
          callback = function()
              HH.assignHouse:Show()
          end,
        },
      }
    KEYBIND_STRIP:AddKeybindButtonGroup(HH.assign)
    GAMEPAD_COLLECTIONS_BOOK.currentList.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if not HH.assignHouse or HH.selectedHouse ~= getSelectedHouse(selectedData) then
          HH.selectedHouse = getSelectedHouse(selectedData)
          HH.createPopup(HH.selectedHouse, "self")
        end
        KEYBIND_STRIP:UpdateKeybindButtonGroup(HH.assign)
    end)
end

function HH.HookHouseTours(oldState, newState)
    if (newState == SCENE_FRAGMENT_SHOWING) then
      HH.assignTours = {
      alignment = KEYBIND_STRIP_ALIGN_RIGHT,
      {

          name = HH.Lang.ADD_TO_HOTBAR,
          keybind = "UI_SHORTCUT_LEFT_STICK",
          callback = function()
              HH.assignHouse:Show()
          end,
          visible = function()
            return newState == SCENE_FRAGMENT_SHOWING
          end
        },
      }
    KEYBIND_STRIP:AddKeybindButtonGroup(HH.assignTours)
    ZO_PreHook(HOUSE_TOURS_GAMEPAD, "OnSelectionChanged", function(list, selectedItem, oldSelectedData)
      KEYBIND_STRIP:UpdateKeybindButtonGroup(HH.assignTours)
      if oldSelectedData and oldSelectedData.GetCollectibleData then
        if not HH.assignHouse or HH.selectedTourHouse ~= oldSelectedData:GetCollectibleData() then
          HH.selectedTourHouse = oldSelectedData:GetCollectibleData()
          HH.createPopup(HH.selectedTourHouse, oldSelectedData:GetOwnerDisplayName())
        end
      end
    end)
    elseif (newState == SCENE_FRAGMENT_HIDDEN) and HH.assignTours then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(HH.assignTours)
    end
end