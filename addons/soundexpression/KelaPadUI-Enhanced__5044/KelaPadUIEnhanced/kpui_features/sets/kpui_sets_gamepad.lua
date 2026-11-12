local colors = kpuiConst.Colors

KELA_SETS_LIST_PIN_NAME = ""
KELA_LAST_SELECTED_DATA = {}
KELA_SETS_FIRST_SHOW = true

-- Override the core set-name format through the supported string API.
-- SI_ITEM_FORMAT_STR_SET_NAME is a numeric string ID and must not be reassigned.
SafeAddString(SI_ITEM_FORMAT_STR_SET_NAME, "<<1>> (<<2>>/<<3>>)", 6)

-- KELA_SETS
local Kela_Sets = ZO_Gamepad_ParametricList_Screen:Subclass()
local KELA_SETS_ROW_DROPSOURCE = 1
local KELA_SETS_ROW_DROPOBTAINABLE = 2
local KELA_SETS_ROW_DROPBONUS = 3
local KELA_SETS_ROW_DROPBOUND = 4
local KELA_SETS_ROW_DROPZONE = 5
local KELA_SETS_ROW_DROPDLC = 6

KELA_SETS_DIALOG_ITEM_WEAPON = 1
KELA_SETS_DIALOG_ITEM_LIGHTARMOR = 2
KELA_SETS_DIALOG_ITEM_MEDIUMARMOR = 3
KELA_SETS_DIALOG_ITEM_HEAVYARMOR = 4
KELA_SETS_DIALOG_ITEM_JEWELRY = 5
KELA_SETS_DIALOG_ITEM_UNIQUE = 6

--KELA_SETS_LIST
--maximum width - 1150
KELA_GAMEPAD_SETS_LIST_NAME_WIDTH = 340
KELA_GAMEPAD_SETS_LIST_OBTAINABLEITEMS_WIDTH = 220
KELA_GAMEPAD_SETS_LIST_SETTYPE_WIDTH = 130
KELA_GAMEPAD_SETS_LIST_SOURCE_WIDTH = 320
KELA_GAMEPAD_SETS_LIST_DLC_WIDTH = 180
KELA_LIST_DATA = 1
local KELA_LIST_TEMPLATE = "Kela_Sets_List_Row_Gamepad"
local KELA_LIST_ENTRY_SORT_KEYS =
{
    ["setName"] 				= { },
    ["setObtainableItemsSort"] 	= { tiebreaker = "setName", tieBreakerSortOrder = ZO_SORT_ORDER_UP, caseInsensitive = true },
    ["setTypeNameSort"] 		= { tiebreaker = "setName", tieBreakerSortOrder = ZO_SORT_ORDER_UP, caseInsensitive = true },
    ["setZoneNames"]			= { tiebreaker = "setName", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
    ["setDLCName"]  			= { tiebreaker = "setName", tieBreakerSortOrder = ZO_SORT_ORDER_UP },
	["keysByIndex"] 			= {
									[1] = "setName",
									[2] = "setObtainableItemsSort",
									[3] = "setTypeNameSort",
									[4] = "setZoneNames",
									[5] = "setDLCName",
									},
}

local noChoiceOrToMap = false
KelaSetsMasterListInitialized = false

local KelaSetsSourceToType = {
	["ALLSOURCES"] = {
		LIBSETS_SETTYPE_ARENA,
		LIBSETS_SETTYPE_BATTLEGROUND,
		LIBSETS_SETTYPE_CRAFTED,
		LIBSETS_SETTYPE_CYRODIIL,
		LIBSETS_SETTYPE_DAILYRANDOMDUNGEONANDICREWARD,
		LIBSETS_SETTYPE_DUNGEON,
		LIBSETS_SETTYPE_IMPERIALCITY,
		LIBSETS_SETTYPE_MONSTER,
		LIBSETS_SETTYPE_OVERLAND,
		LIBSETS_SETTYPE_SPECIAL,
		LIBSETS_SETTYPE_TRIAL,
		LIBSETS_SETTYPE_MYTHIC,
	},
	["WORLD"] = {
		LIBSETS_SETTYPE_OVERLAND,
		LIBSETS_SETTYPE_MYTHIC,
	},
	["DUNGEONS"] = {
		LIBSETS_SETTYPE_DAILYRANDOMDUNGEONANDICREWARD,
		LIBSETS_SETTYPE_DUNGEON,
	},
	["CRAFT"] = {
		LIBSETS_SETTYPE_CRAFTED,
	},
	["MONSTERSETS"] = {
		LIBSETS_SETTYPE_MONSTER,
	},
	["TRIALS"] = {
		LIBSETS_SETTYPE_ARENA,
		LIBSETS_SETTYPE_TRIAL,
	},
	["PVP"] = {
		LIBSETS_SETTYPE_BATTLEGROUND,
		LIBSETS_SETTYPE_CYRODIIL,
		LIBSETS_SETTYPE_IMPERIALCITY,
	},
	["OTHER"] = {
		LIBSETS_SETTYPE_SPECIAL,
		LIBSETS_SETTYPE_MYTHIC,
	},
}
local KelaSetObtainable = {
	ARMOR_LIGHT = 1,
	ARMOR_MEDIUM = 2,
	ARMOR_HEAVY = 3,
	ARMOR_COMPLECT = 4,
    WEAPON_INCOMPLECT = 5,
    WEAPON = 6,
	JEWELRY_INCOMPLECT = 7,
	JEWELRY = 8,
}
local KelaSetBonusGroup = {
	MAGICKA = 1,
	HEALTH = 2,
	STAMINA = 3,
	SPELL = 4,
	WEAPON = 5,
    RESIST = 6,
}
local DerivedStatsForBonusGroup = {
	["SI_DERIVEDSTATS1"] = KelaSetBonusGroup.WEAPON,
	["SI_DERIVEDSTATS2"] = KelaSetBonusGroup.WEAPON,
	["SI_DERIVEDSTATS3"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS4"] = KelaSetBonusGroup.MAGICKA,
	["SI_DERIVEDSTATS5"] = KelaSetBonusGroup.MAGICKA,
	["SI_DERIVEDSTATS6"] = KelaSetBonusGroup.MAGICKA,
	["SI_DERIVEDSTATS7"] = KelaSetBonusGroup.HEALTH,
	["SI_DERIVEDSTATS8"] = KelaSetBonusGroup.HEALTH,
	["SI_DERIVEDSTATS9"] = KelaSetBonusGroup.HEALTH,
	["SI_DERIVEDSTATS10"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS11"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS12"] = KelaSetBonusGroup.MAGICKA,
	["SI_DERIVEDSTATS13"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS14"] = KelaSetBonusGroup.RESIST,
	-- ["SI_DERIVEDSTATS15"] = KelaSetBonusGroup.,
	["SI_DERIVEDSTATS16"] = KelaSetBonusGroup.WEAPON,
	-- ["SI_DERIVEDSTATS17"] = KelaSetBonusGroup.,
	-- ["SI_DERIVEDSTATS18"] = KelaSetBonusGroup.,
	-- ["SI_DERIVEDSTATS19"] = KelaSetBonusGroup.,
	["SI_DERIVEDSTATS20"] = KelaSetBonusGroup.RESIST,
	-- ["SI_DERIVEDSTATS21"] = KelaSetBonusGroup.,
	["SI_DERIVEDSTATS22"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS23"] = KelaSetBonusGroup.SPELL,
	["SI_DERIVEDSTATS24"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS25"] = KelaSetBonusGroup.SPELL,
	["SI_DERIVEDSTATS26"] = KelaSetBonusGroup.RESIST,
	-- ["SI_DERIVEDSTATS27"] = KelaSetBonusGroup.,
	-- ["SI_DERIVEDSTATS28"] = KelaSetBonusGroup.,
	["SI_DERIVEDSTATS29"] = KelaSetBonusGroup.STAMINA,
	["SI_DERIVEDSTATS30"] = KelaSetBonusGroup.STAMINA,
	["SI_DERIVEDSTATS31"] = KelaSetBonusGroup.STAMINA,
	["SI_DERIVEDSTATS32"] = KelaSetBonusGroup.WEAPON,
	["SI_DERIVEDSTATS33"] = KelaSetBonusGroup.WEAPON,
	["SI_DERIVEDSTATS34"] = KelaSetBonusGroup.SPELL,
	["SI_DERIVEDSTATS35"] = KelaSetBonusGroup.WEAPON,
	-- ["SI_DERIVEDSTATS36"] = KelaSetBonusGroup.,
	["SI_DERIVEDSTATS37"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS38"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS39"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS40"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS41"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS42"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS43"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS44"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS45"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS46"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS47"] = KelaSetBonusGroup.RESIST,
	["SI_DERIVEDSTATS48"] = KelaSetBonusGroup.STAMINA,
	["SI_DERIVEDSTATS49"] = KelaSetBonusGroup.STAMINA,
	["SI_DERIVEDSTATS50"] = KelaSetBonusGroup.STAMINA,
}

-- KELA_SETS_LIST
local Kela_Sets_List = ZO_GamepadInteractiveSortFilterList:Subclass()

function Kela_Sets_List:New(...)
    return ZO_GamepadInteractiveSortFilterList.New(self, ...)
end

function Kela_Sets_List:Initialize(control)
    ZO_GamepadInteractiveSortFilterList.Initialize(self, control)
    self:SetEmptyText(GetString(KELA_SETS_LIST_EMPTYTEXT))
	ZO_ScrollList_AddDataType(self.list, KELA_LIST_DATA, KELA_LIST_TEMPLATE, 38, function(control, data) self:SetupKelaListEntry(control, data) end)
	self:SetMasterSetsList() 
	self.comparedSetData = false
	self.showInfoTooltip = true
    self:SetupSort(KELA_LIST_ENTRY_SORT_KEYS, "setName", ZO_SORT_ORDER_UP)
	ZO_ScrollList_SetAutoSelect(self, true)
	self:InitializeSetDialog()

	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP.control:ClearAnchors()
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP.control:SetAnchor(TOPLEFT, KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP.control, TOPRIGHT, 0, 0) 
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP.control:SetAnchor(BOTTOMLEFT, KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP.control, BOTTOMRIGHT, 0, 0) 
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP2.control:ClearAnchors()
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP2.control:SetAnchor(TOPLEFT, KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP.control, TOPRIGHT, 0, 0) 
	KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP2.control:SetAnchor(BOTTOMLEFT, KPUI_GAMEPAD_TOOLTIPS.tooltips.KPUI_GAMEPAD_COMPARE_TOOLTIP.control, BOTTOMRIGHT, 0, 0) 

	self.KelaKeyBindSetsList = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		keybind = "DIALOG_TERTIARY",		-- set comparison
		name = GetString(KELA_SETSLIST_HEADER_NAME),
		callback =  function()
			KELA_SETS_LIST.compareView = not KELA_SETS_LIST.compareView
			control.refreshTooltipFunction (control.itemData)
		end,
		visible = function()
			return ZO_Dialogs_IsShowingDialog("KELA_SETS_LIST_DIALOG") and control.isKelaDialogSetItemsDropdown
		end,
	}

	if (not KEYBIND_STRIP:HasKeybindButton(self.KelaKeyBindSetsList)) then
		KEYBIND_STRIP:AddKeybindButton(self.KelaKeyBindSetsList)
	end

	
end

function Kela_Sets_List:InitializeHeader()
    local contentHeaderData = 
    {
        titleText = "",
        data1HeaderText = "",
        data2HeaderText = "",
        data3HeaderText = "",
    }
    ZO_GamepadInteractiveSortFilterList.InitializeHeader(self, contentHeaderData)
end
function Kela_Sets_List:InitializeKeybinds()

    local keybindDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,	
            name = "KPUI Sets " .. GetString(SI_GAMEPAD_SELECT_OPTION),
			keybind = "UI_SHORTCUT_PRIMARY",
			visible = function()
					local data = ZO_ScrollList_GetSelectedData(self.list)
					if data then return data.setID ~= "" end
                end,
            callback = function()
					KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
					KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP)
		            ZO_Dialogs_ShowPlatformDialog("KELA_SETS_LIST_DIALOG")
                end,
        },

        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,	
            name = GetString(KELA_SETSKEY_COMPARE),
			keybind = "UI_SHORTCUT_SECONDARY",
			visible = function()
					local data = ZO_ScrollList_GetSelectedData(self.list)
					if data then return data.setID ~= "" end
                end,
            callback = function()
					local data = ZO_ScrollList_GetSelectedData(self.list)
					KELA_SETS_LIST.comparedSetData = data
					KPUI_GAMEPAD_TOOLTIPS:LayoutSetTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, data)	
					KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
                end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,	
            name = GetString(KELA_SETSKEY_CLEARCOMPARE),
			keybind = "UI_SHORTCUT_QUATERNARY",
			visible = function()
					return KELA_SETS_LIST.comparedSetData ~= false
                end,
            callback = function()
					local data = ZO_ScrollList_GetSelectedData(self.list)
					KELA_SETS_LIST.comparedSetData = false
					KPUI_GAMEPAD_TOOLTIPS:LayoutSetTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, data)	
					KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)		
                end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,	
            name = GetString(KELA_SETSKEY_CLEARCOMPARE),
			keybind = "UI_SHORTCUT_LEFT_SHOULDER",
			ethereal = true,
			visible = function()
					return true
                end,
            callback = function()
					self:SetNextSortKey(false)
                end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,	
            name = GetString(KELA_SETSKEY_CLEARCOMPARE),
			keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
			ethereal = true,
			visible = function()
					return true
                end,
            callback = function()
					self:SetNextSortKey(true)
				end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,	
            name = function()
					if self.showInfoTooltip then
						return GetString(SI_WORLD_MAP_ACTION_HIDE_INFORMATION)
					else
						return GetString(SI_WORLD_MAP_ACTION_SHOW_INFORMATION)
					end
				end,
			keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function()
					self.showInfoTooltip = not self.showInfoTooltip
					if self.showInfoTooltip then
						local data = ZO_ScrollList_GetSelectedData(self.list)
						if not data then data = KELA_LAST_SELECTED_DATA end
						self:OnSelectionChanged(nil, data)
					else
						KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP)
					end
					KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)		
				end,
        }		
    }
	
    ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(keybindDescriptor, GAME_NAVIGATION_TYPE_BUTTON, self:GetBackKeybindCallback())
    self:SetKeybindStripDescriptor(keybindDescriptor)
    ZO_GamepadInteractiveSortFilterList.InitializeKeybinds(self)

        local keybind  =
        -- clear search on the page
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,	
            name = GetString(KELA_SETSKEY_CLEARSEARCH),
			keybind = "UI_SHORTCUT_TERTIARY",
			visible = function()
					return self:GetCurrentSearch() ~= ""
                end,
            callback = function()
					self:ClearFilterScrollList(true)
					self:UpdateKeybinds()
                end,
        }
	self:AddUniversalKeybind(keybind)
	
end
function Kela_Sets_List:GetBackKeybindCallback()
    return function()
		self:Deactivate()
		kelaReColorDescription(false)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP)
        KELA_SETS:ActivateCategories()
    end
end

function Kela_Sets_List:CreateMapPinRows(dialog)
	local firstRow = true

	local function setupRow (control, data, selected, reselectingDuringRebuild, enabled, active)
		ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
		local label = control.label
		label:SetFont("ZoFontGamepad34")
	end

	local function callbackRow(dialog)
		local data = dialog.entryList:GetTargetData()
		if data.mapIndex then

			noChoiceOrToMap = true	
			dialog.info.blockDialogReleaseOnPress = false
			
			SCENE_MANAGER:Push("gamepad_worldMap")
			ZO_WorldMapManager:HandleAutoNavigationMapChange(100)
			zo_callLater(function()
				ZO_WorldMap_SetMapByIndex(data.mapIndex)
			end, 250)
			KELA_SETS_LIST_PIN_NAME = data.pinName
			if data.zoneIndex then
				zo_callLater(function()
					ZO_WorldMap_PanToWayshrine(data.zoneIndex)
				end, 350)
			end

		end
	end

    local data = ZO_ScrollList_GetSelectedData(self.list)
	if data.canTeleport then
		KELA_SETS_LIST_PIN_NAME = ""
		local currentID
		if data.setWayshrinesTrue then
			for i = 1, #data.setWayshrines do
			
				local wayshrineNodeId = data.setWayshrines[i]
				local zoneID = LibSets.GetWayshrinesZoneId(wayshrineNodeId)
				local mapIndex = GetMapIndexByZoneId(zoneID)
				if mapIndex and currentID ~= wayshrineNodeId then 
					local alliance = kelaGetAlliance(zoneID)
					local icon = GetAllianceSymbolIcon(alliance)
					local zName = LibSets.GetZoneName(zoneID)
					if icon then zName = zo_iconFormat(icon, 44, 44).." "..zName end
					local wayshrineName = select(2, GetFastTravelNodeInfo(wayshrineNodeId))
					
					local function GetTemplate()
						if firstRow then		
							firstRow = false			
							return
							{
								template = "Kela_GamepadFullWidthLabelEntryTemplate",
								header = GetString(KELA_SETS_DIALOG_ZONES),
								headerTemplate = "Kela_GamepadMenuEntryFullWidthHeaderTemplate",
								templateData =
								{
									toChat = false,
									setName = data.setName,
									setZoneNames = data.setZoneNames,
									zoneIndex = wayshrineNodeId,
									mapIndex = mapIndex,
									zoneID = zoneID,
									text = zName..": "..wayshrineName,
									setup = setupRow,
									callback = callbackRow,
								},
							}
						else
							return 
							{
								template = "Kela_GamepadFullWidthLabelEntryTemplate",
								templateData =
								{
									toChat = false,
									setName = data.setName,
									setZoneNames = data.setZoneNames,
									zoneIndex = wayshrineNodeId,
									mapIndex = mapIndex,
									zoneID = zoneID,
									text = zName..": "..wayshrineName,
									setup = setupRow,
									callback = callbackRow,
								},
							}
						end
					end						
					
					table.insert(dialog.info.parametricList, GetTemplate())
					currentID = wayshrineNodeId
				end
			end
		else
			if data.setZoneIds then
				for i, zoneID in pairs(data.setZoneIds) do
					local parentZoneID = GetParentZoneId(zoneID)
					local zAlliance = kelaGetAlliance(zoneID)
					local zName = LibSets.GetZoneName(zoneID)
					local parentName = LibSets.GetZoneName(parentZoneID)
					local hasParent = (zName ~= parentName)				
					local pinName = LibSets.GetZoneName(zoneID)
					local zoneIndex = GetZoneIndex(zoneID)
					if hasParent then zoneID = parentZoneID end
					local mapIndex = GetMapIndexByZoneId(zoneID)
					if mapIndex and currentID ~= zoneID then 
						local alliance = kelaGetAlliance(zoneID)
						local icon = GetAllianceSymbolIcon(alliance)

						if zName == parentName then 
							zName = parentName
						else
							local twoLevels = string.find(zName,"I")
							if twoLevels then
								local ind = twoLevels - 1
								zName = parentName..": "..string.sub(zName, 1, ind)
							else
								zName = parentName..": "..zName
							end								
						end

						if icon then zName = zo_iconFormat(icon, 44, 44).." "..zName end


						local function GetTemplate()
							if firstRow then		
								firstRow = false			
								return
								{
									template = "Kela_GamepadFullWidthLabelEntryTemplate",
									header = GetString(KELA_SETS_DIALOG_ZONES),
									headerTemplate = "Kela_GamepadMenuEntryFullWidthHeaderTemplate",
									templateData =
									{
										toChat = false,
										setName = data.setName,
										setZoneNames = data.setZoneNames,
										zoneIndex = zoneIndex,
										mapIndex = mapIndex,
										zoneID = zoneID,
										pinName = pinName,
										text = zName,
										setup = setupRow,
										callback = callbackRow,
									},
								}
							else
								return 
								{
									template = "Kela_GamepadFullWidthLabelEntryTemplate",
									templateData =
									{
										toChat = false,
										setName = data.setName,
										setZoneNames = data.setZoneNames,
										zoneIndex = zoneIndex,
										mapIndex = mapIndex,
										zoneID = zoneID,
										pinName = pinName,
										text = zName,
										setup = setupRow,
										callback = callbackRow,
									},
								}
							end
						end		

						
						table.insert(dialog.info.parametricList, GetTemplate())
						currentID = zoneID
					end
				end	
			end
		end
	end
end

local OldZO_WorldMapPinsGetWayshrinePin = ZO_WorldMapPins.GetWayshrinePin
ZO_WorldMapPins.GetWayshrinePin = function(control, nodeIndex, ...) 
	local pins = control:GetActiveObjects()
	local xLoc, yLoc, reservePin
	for pinKey, pin in pairs(pins) do
		local curIndex = pin:GetFastTravelNodeIndex()
		local known, name, _, _, _, _, poiType, isLocatedInCurrentMap = GetFastTravelNodeInfo(curIndex)
		if curIndex and curIndex == nodeIndex then
			return pin
		elseif KELA_SETS_LIST_PIN_NAME and string.match (string.lower(name), string.lower(KELA_SETS_LIST_PIN_NAME)) then
			return pin	
		elseif curIndex then
			if (poiType == POI_TYPE_WAYSHRINE and poiType ~= POI_TYPE_HOUSE and poiType ~= POI_TYPE_GROUP_DUNGEON) and HasCompletedFastTravelNodePOI(curIndex) then 
				reservePin = pin 
			end
		end
    end
	if reservePin then
		return reservePin
	else
		xLoc, yLoc = ZO_WorldMapContainer:GetCenter() 
		ZO_WorldMap_PanToNormalizedPosition(xLoc, yLoc)	
		return false
	end
end

function Kela_Sets_List:BuildSetsObtainableItemsData(dialog)

    local data = ZO_ScrollList_GetSelectedData(self.list)
	local setID = data.setID
    
	self.setsObtainableWeaponData:Clear()
	self.setsObtainableLightArmorData:Clear()
	self.setsObtainableMediumArmorData:Clear()
	self.setsObtainableHeavyArmorData:Clear()
	self.setsObtainableJewelryData:Clear()
	self.setsObtainableUniqueData:Clear()
	
	local setWeaponTable = {}
	local setLightArmorTable = {}
	local setMediumArmorTable = {}
	local setHeavyArmorTable = {}
	local setJewelryTable = {}
	local setUniqueWeaponTable = {}
	local setUniqueArmorTable = {}
	local setTableSortKeys = {
		["weapon"] = {
			WEAPONTYPE_SHIELD, 			
			WEAPONTYPE_FIRE_STAFF, 		
			WEAPONTYPE_FROST_STAFF, 		
			WEAPONTYPE_LIGHTNING_STAFF, 
			WEAPONTYPE_HEALING_STAFF,		
			WEAPONTYPE_BOW, 				
			WEAPONTYPE_DAGGER, 			
			WEAPONTYPE_AXE, 				
			WEAPONTYPE_HAMMER, 			
			WEAPONTYPE_SWORD,				
			WEAPONTYPE_TWO_HANDED_AXE, 
			WEAPONTYPE_TWO_HANDED_HAMMER,
			WEAPONTYPE_TWO_HANDED_SWORD,
		},
		["armor"] = {
			EQUIP_TYPE_HEAD, 				
			EQUIP_TYPE_CHEST, 				
			EQUIP_TYPE_SHOULDERS,			
			EQUIP_TYPE_WAIST, 				
			EQUIP_TYPE_HAND, 				
			EQUIP_TYPE_LEGS, 				
			EQUIP_TYPE_FEET, 				
			EQUIP_TYPE_NECK, 				
			EQUIP_TYPE_RING, 				
		},
	}
	local setTableEquipTypeSlot = {
		["weapon"] = {
			[WEAPONTYPE_SHIELD] 			= EQUIP_SLOT_OFF_HAND,
			[WEAPONTYPE_FIRE_STAFF] 		= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_FROST_STAFF] 		= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_LIGHTNING_STAFF] 	= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_HEALING_STAFF] 		= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_BOW] 				= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_DAGGER] 			= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_AXE] 				= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_HAMMER] 			= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_SWORD]				= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_TWO_HANDED_AXE] 	= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_TWO_HANDED_HAMMER]	= EQUIP_SLOT_MAIN_HAND,
			[WEAPONTYPE_TWO_HANDED_SWORD] 	= EQUIP_SLOT_MAIN_HAND,
		},
		["armor"] = {
			[EQUIP_TYPE_HEAD] 				= EQUIP_SLOT_HEAD,
			[EQUIP_TYPE_CHEST] 				= EQUIP_SLOT_CHEST,
			[EQUIP_TYPE_SHOULDERS]			= EQUIP_SLOT_SHOULDERS,
			[EQUIP_TYPE_WAIST] 				= EQUIP_SLOT_WAIST,
			[EQUIP_TYPE_HAND] 				= EQUIP_SLOT_HAND,
			[EQUIP_TYPE_LEGS] 				= EQUIP_SLOT_LEGS,
			[EQUIP_TYPE_FEET] 				= EQUIP_SLOT_FEET,
			[EQUIP_TYPE_NECK] 				= EQUIP_SLOT_NECK,
			[EQUIP_TYPE_RING] 				= EQUIP_SLOT_RING1,
		},
	}

	local setItemIds = LibSets.GetSetItemIds(setID)
	if not setItemIds then return end
	for setItemId, isCorrect in pairs(setItemIds) do
		if setItemId ~= nil and isCorrect == 1 then 
			local itemLink = LibSets.buildItemLink(setItemId)
			local itemType = GetItemLinkItemType(itemLink)
			local armorType = GetItemLinkArmorType(itemLink)
			local weaponType = GetItemLinkWeaponType(itemLink)
			local equipType = GetItemLinkEquipType(itemLink)	
			if itemLink then
				if GetItemLinkFlavorText(itemLink) ~= "" then	-- named items
					if itemType == ITEMTYPE_WEAPON then
						if not setUniqueWeaponTable[weaponType] then
							setUniqueWeaponTable[weaponType] = setItemId
						end
					else
						if not setUniqueArmorTable[equipType] then
							setUniqueArmorTable[equipType] = setItemId
						end
					end
				elseif itemType == ITEMTYPE_ARMOR then
					if armorType == ARMORTYPE_NONE then
						if not setJewelryTable[equipType] then
							setJewelryTable[equipType] = setItemId 
						end
					elseif armorType == ARMORTYPE_LIGHT then
						if not setLightArmorTable[equipType] then
							setLightArmorTable[equipType] = setItemId 
						end
					elseif armorType == ARMORTYPE_MEDIUM then
						if not setMediumArmorTable[equipType] then
							setMediumArmorTable[equipType] = setItemId 
						end
					elseif armorType == ARMORTYPE_HEAVY then
						if not setHeavyArmorTable[equipType] then
							setHeavyArmorTable[equipType] = setItemId 
						end
					end
				elseif itemType == ITEMTYPE_WEAPON then
					if not setWeaponTable[weaponType] then
						setWeaponTable[weaponType] = setItemId 
					end
				end
			end
		end
	end
		
	local gotWeapon = false
	local gotLightArmor = false
	local gotMediumArmor = false
	local gotHeavyArmor = false
	local gotJewelry = false
	local gotUnique = false
	local function addEntries(equipType, equipSlot, itemType, setItemId, entryData)
		if equipType == itemType then
			local itemLink = LibSets.buildItemLink(setItemId)
			local name = GetItemLinkName(itemLink)
			local entry = ZO_ComboBox_Base:CreateItemEntry(name)
			entry.equipSlot = equipSlot
			entry.setItemId = setItemId
			entry.equipType = itemType
			entryData:AddItem(entry)
			return true
		end		
	end
	
	for _, val in pairs(setTableSortKeys["weapon"]) do
		for weaponType, setItemId in pairs(setWeaponTable) do
			local equipSlot = setTableEquipTypeSlot["weapon"][weaponType]
			if gotEntry == addEntries(val, equipSlot, weaponType, setItemId, self.setsObtainableWeaponData) then gotWeapon = true end
		end
		for itemType, setItemId in pairs(setUniqueWeaponTable) do
			local equipSlot = setTableEquipTypeSlot["weapon"][itemType]
			if gotEntry == addEntries(val, equipSlot, itemType, setItemId, self.setsObtainableUniqueData) then gotUnique = true end
		end
	end

	for _, val in pairs(setTableSortKeys["armor"]) do
		for armorType, setItemId in pairs(setLightArmorTable) do
			local equipSlot = setTableEquipTypeSlot["armor"][armorType]
			if gotEntry == addEntries(val, equipSlot, armorType, setItemId, self.setsObtainableLightArmorData) then gotLightArmor = true end
		end
		for armorType, setItemId in pairs(setMediumArmorTable) do
			local equipSlot = setTableEquipTypeSlot["armor"][armorType]
			if gotEntry == addEntries(val, equipSlot, armorType, setItemId, self.setsObtainableMediumArmorData) then gotMediumArmor = true end
		end
		for armorType, setItemId in pairs(setHeavyArmorTable) do
			local equipSlot = setTableEquipTypeSlot["armor"][armorType]
			if gotEntry == addEntries(val, equipSlot, armorType, setItemId, self.setsObtainableHeavyArmorData) then gotHeavyArmor = true end
		end
		for armorType, setItemId in pairs(setJewelryTable) do
			local equipSlot = setTableEquipTypeSlot["armor"][armorType]
			if gotEntry == addEntries(val, equipSlot, armorType, setItemId, self.setsObtainableJewelryData) then gotJewelry = true end
		end
		for itemType, setItemId in pairs(setUniqueArmorTable) do
			local equipSlot = setTableEquipTypeSlot["armor"][itemType]
			if gotEntry == addEntries(val, equipSlot, itemType, setItemId, self.setsObtainableUniqueData) then gotUnique = true end
		end
	end

	if gotWeapon then 
		local obtainableWeaponDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_WEAPON, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableWeaponData, true)
		table.insert(dialog.info.parametricList, obtainableWeaponDropdownEntry) 
	end	
	if gotLightArmor then 
		local obtainableLightArmorDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_LIGHTARMOR, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableLightArmorData, true)
		table.insert(dialog.info.parametricList, obtainableLightArmorDropdownEntry) 
	end
	if gotMediumArmor then 
		local obtainableMediumArmorDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_MEDIUMARMOR, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableMediumArmorData, true)
		table.insert(dialog.info.parametricList, obtainableMediumArmorDropdownEntry) 
	end
	if gotHeavyArmor then 
		local obtainableHeavyArmorDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_HEAVYARMOR, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableHeavyArmorData, true)
		table.insert(dialog.info.parametricList, obtainableHeavyArmorDropdownEntry) 
	end
	if gotJewelry then 
		local obtainableJewelryDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_JEWELRY, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableJewelryData, true)
		table.insert(dialog.info.parametricList, obtainableJewelryDropdownEntry) 
	end
	if gotUnique then 
		local obtainableUniqueDropdownEntry = self:CreateMultiSelectionSetsDropdown(KELA_SETS_DIALOG_ITEM_UNIQUE, GetString(KELA_SETS_ITEM_DROPDOWN_TEXT), self.setsObtainableUniqueData, true)
		table.insert(dialog.info.parametricList, obtainableUniqueDropdownEntry) 
	end

	local function setupRow (control, data, selected, reselectingDuringRebuild, enabled, active)
		ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
		local label = control.label
		label:SetFont("ZoFontGamepad34")
	end

	local listItem = 
    {
        template = "Kela_GamepadFullWidthLabelEntryTemplate",
        templateData = 
		{
			text = GetString(KELA_SETS_DIALOG_SEND).." "..zo_iconFormat("EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_textChat.dds", 44, 44),
			setup = setupRow,
			visible = not self.setIsBoundOnUp, 
			callback = function(dialog)
				if self.itemTableDirty then
					dialog.info.blockDialogReleaseOnPress = false
					CHAT_SYSTEM:StartTextEntry(GetString(KELA_SETS_DIALOG_WTB))
					for basicType, equipTypes in pairs(self.itemsIDToChat) do
						if type(equipTypes) == "table" then
							for equipType, itemID in pairs(equipTypes) do
								local itemLink = LibSets.buildItemLink(itemID, self.currentQualityDropdownIndex + 366)
								ZO_LinkHandler_InsertLink(itemLink)
							end
						end
					end
					local chatSystem = SYSTEMS:GetObject("ChatSystem")
					chatSystem:Maximize()
					noChoiceOrToMap = false			
					KEYBIND_STRIP:AddKeybindButtonGroup(KELA_SETS_LIST.keybindStripDescriptor)
					local data = ZO_ScrollList_GetSelectedData(self.list)
					if data then KPUI_GAMEPAD_TOOLTIPS:LayoutSetTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, data) end
				end
            end,
		},
    }
	table.insert(dialog.info.parametricList, listItem)
end

function Kela_Sets_List:CreateMultiSelectionSetsDropdown(basicType, multiSelectionText, dropdownData, isDropdownSetToDefaultFn)


	local function refreshDialogSetInfoTooltip (itemData)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP2)	
		local itemLink = LibSets.buildItemLink(itemData.setItemId, self.currentQualityDropdownIndex + 366)
		local equipSlot = itemData.equipSlot
		KPUI_GAMEPAD_TOOLTIPS:LayoutItem(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP, itemLink, NOT_EQUIPPED, NO_CREATOR_NAME, FORCE_FULL_DURABILITY)
		if self.compareView then 
			KPUI_GAMEPAD_TOOLTIPS:LayoutItemStatComparisonItemLink(KPUI_GAMEPAD_COMPARE_TOOLTIP, itemLink, equipSlot)
			local itemLinkCompared =  GetItemLink(BAG_WORN, equipSlot)
			if itemLinkCompared and itemLinkCompared ~= "" then 
				KPUI_GAMEPAD_TOOLTIPS:LayoutBagItem(KPUI_GAMEPAD_COMPARE_TOOLTIP2, BAG_WORN, equipSlot)
			else
				KPUI_GAMEPAD_TOOLTIPS:LayoutDescriptionTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP2, GetString("SI_EQUIPSLOT", equipSlot), GetString(KELA_SETS_DIALOG_COMPARE_WRONGEQUIPSLOT))
			end
		else
			KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP)
			KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP2)
		end
	end
	
	local function hideAllTooltip ()
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP)
		KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_COMPARE_TOOLTIP2)
	end

    return
    {
        template = "ZO_GamepadMultiSelectionDropdownItem",
        templateData = 
        {
            setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                local dropdown = control.dropdown
				dropdown.basicType = basicType
				dropdown.dropdownData = dropdownData
                self.dialogDropdowns[basicType] = dropdown
				dropdown.isKelaDialogSetItemsDropdown = true
				dropdown.m_font = "ZoFontGamepad22"
				dropdown.m_highlightFont = "ZoFontGamepad27"
				dropdown.m_fontRatio = 2
                dropdown:SetNormalColor(ZO_GAMEPAD_COMPONENT_COLORS.UNSELECTED_INACTIVE:UnpackRGB())
                dropdown:SetHighlightedColor(ZO_GAMEPAD_COMPONENT_COLORS.SELECTED_ACTIVE:UnpackRGB())
                dropdown:SetSelectedItemTextColor(selected)
                dropdown:SetSortsItems(false)
                dropdown:SetNoSelectionText(GetString("KELA_SETS_METADATAATTRIBUTE", dropdown.basicType))
                dropdown:SetMultiSelectionTextFormatter(multiSelectionText)				
				dropdown.refreshTooltipFunction = refreshDialogSetInfoTooltip	
				dropdown:RegisterCallback("OnItemSelected", function(itemControl, itemData)
					self.dialogSetItemsDoOne = false
					if not self.DialogSetItemsTooltipOn then
						if itemData.setItemId ~= "" then
							dropdown.itemData = itemData
							dropdown.refreshTooltipFunction(dropdown.itemData)
						end
						self.DialogSetItemsTooltipOn = true
					end
                end)                
                dropdown:RegisterCallback("OnItemDeselected", function(itemControl, itemData)
					if self.DialogSetItemsTooltipOn then 
						self.DialogSetItemsTooltipOn = false
					end
				end)                
                dropdown:RegisterCallback("OnHideDropdown", function(dialog)
					if not self.dialogSetItemsDoOne then
						local dropdownData = dropdown.dropdownData
						KelaRemoveValueByKey(self.itemsIDToChat, dropdown.basicType)
						for i, k in pairs(dropdownData.selectedItems) do
							if (k["equipType"] and k["setItemId"]) then
								KelaSetValueIfNil(self.itemsIDToChat, dropdown.basicType, {})
								KelaSetValueIfNil(self.itemsIDToChat[dropdown.basicType], k["equipType"], {})
								self.itemsIDToChat[dropdown.basicType][k["equipType"]] = k["setItemId"]
							end
						end
						if next(self.itemsIDToChat) == nil then
							self.itemTableDirty = false
						else
							self.itemTableDirty = true
						end
						self.dialogSetItemsDoOne = true
					end
					ZO_GenericGamepadDialog_RefreshKeybinds(self.setDialog)
					hideAllTooltip ()
				end)		
                dropdown:LoadData(dropdownData)
            end,
            callback = function(dialog)
                local targetData = dialog.entryList:GetTargetData()
                local targetControl = dialog.entryList:GetTargetControl()
                targetControl.dropdown:Activate()
            end,
        },
    }
end

function Kela_Sets_List:InitializeSetDialog()
	-- dialog
	self.dialogDropdowns = {}
	self.setIsBoundOnUp = false
	self.compareView = true	
	self.currentQualityDropdownIndex = 3
	
	-- drop-down lists
	self.itemsIDToChat = {}

	noChoiceOrToMap = false

	-- available items
	self.setsObtainableWeaponData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()
	self.setsObtainableLightArmorData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()
	self.setsObtainableMediumArmorData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()
	self.setsObtainableHeavyArmorData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()
	self.setsObtainableJewelryData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()
	self.setsObtainableUniqueData = ZO_MultiSelection_ComboBox_Data_Gamepad:New()

	self.setItemQuallityEntry = 		
	{
		template = "ZO_Gamepad_Dropdown_Item_FullWidth",
		header = GetString(KELA_SETS_DIALOG_REQUEST_HEADER),
		headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate",
		templateData =
		{
			setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
				ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
				local dropdown = control.dropdown
				self.dialogDropdowns[#self.dialogDropdowns + 1] = dropdown
				
				dropdown.m_font = "ZoFontGamepad27"
				dropdown.m_highlightFont = "ZoFontGamepad34"
				dropdown:SetSortsItems(false)
				dropdown:ClearItems()
				local function CreateColorizedLabel(index)
					local color = GetItemQualityColor(index)
					local label = GetString("SI_ITEMQUALITY", index)
					return color:Colorize(label)
				end
				local function UpdateDropdownSelection(dropdown)
					local currentIndex 
					currentIndex = self.currentQualityDropdownIndex
					if currentIndex then
						dropdown:SetSelectedItemText(CreateColorizedLabel(currentIndex + 1))
					else
						dropdown:SetSelectedItemText(CreateColorizedLabel(3))
					end	
				end
				local function SelectSetsQuality(comboBox, name, entry, selectionChange)
					if selectionChange then
						self.currentQualityDropdownIndex = dropdown:GetHighlightedIndex()
					end
				end
				dropdown:AddItem(ZO_ComboBox:CreateItemEntry(CreateColorizedLabel(2), SelectSetsQuality, ZO_COMBOBOX_SUPRESS_UPDATE))
				dropdown:AddItem(ZO_ComboBox:CreateItemEntry(CreateColorizedLabel(3), SelectSetsQuality, ZO_COMBOBOX_SUPRESS_UPDATE))
				dropdown:AddItem(ZO_ComboBox:CreateItemEntry(CreateColorizedLabel(4), SelectSetsQuality, ZO_COMBOBOX_SUPRESS_UPDATE))
				dropdown:AddItem(ZO_ComboBox:CreateItemEntry(CreateColorizedLabel(5), SelectSetsQuality, ZO_COMBOBOX_SUPRESS_UPDATE))
				dropdown:UpdateItems()
				UpdateDropdownSelection(dropdown)
			end,
			callback = function(dialog)
				local targetControl = dialog.entryList:GetTargetControl()
				targetControl.dropdown:Activate()
				targetControl.dropdown:SetHighlightedItem(self.currentQualityDropdownIndex)
			end,
			isDropdown = true,	
		},
	}

    local setupFunction = function(dialog)
		self.setDialog = dialog
		self.itemsIDToChat = {}
		self.DialogSetItemsTooltipOn = false
		self.dialogSetItemsDoOne = false
		self.itemTableDirty = false	
		noChoiceOrToMap = false	
		dialog.info.blockDialogReleaseOnPress = true
		dialog.info.parametricList = {}
		table.insert(dialog.info.parametricList, self.setItemQuallityEntry) 
		self:BuildSetsObtainableItemsData(dialog)
		
		self:CreateMapPinRows(dialog)
        dialog:setupFunc()
    end
	
	-- close lists when leaving the dialog unexpectedly
    local noChoiceCallback = function(dialog)
        noChoiceOrToMap = true
		for i, dropdown in pairs(self.dialogDropdowns) do
			dropdown:Deactivate(true)
		end
	end	

    -- Reset Filters
    local resetFilterButton =
    {
        keybind = "DIALOG_RESET",
        text = KELA_SETS_DIALOG_RESET_FILTERS,
        enabled = function(dialog)
            return self.itemTableDirty
        end,
        callback = function(dialog)
			dialog.info.setup(dialog)
        end,
    }

    ZO_Dialogs_RegisterCustomDialog("KELA_SETS_LIST_DIALOG",
    {
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
		title =
		{
			text = function(dialog)
						local data = ZO_ScrollList_GetSelectedData(KELA_SETS_LIST.list)
						return colors.COLOR_WHITE:Colorize(data.setName)
					end,
		},
		mainText = 
		{
			text = 	function(dialog)
						local data = ZO_ScrollList_GetSelectedData(KELA_SETS_LIST.list)
						local color
						if data.setBindType == 1 then
							color = colors.COLOR_NOTSOON
							self.setIsBoundOnUp = true
						else
							color = colors.COLOR_SOON
							self.setIsBoundOnUp = false
						end
						local text = GetString(KELA_SETS_DIALOG_TEXT).."\n"..GetString(KELA_SETS_BOUNDDROPDOWN_HEADER)..": "..color:Colorize(GetString("KELA_SETSBOUND", data.setBindType))
						return text
					end,
		},	
        setup = setupFunction,
        parametricList = { },
        blockDialogReleaseOnPress = true,
        buttons =
        {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local targetData = dialog.entryList:GetTargetData()
					if targetData and targetData.callback then
						targetData.callback(dialog)
					end
				end,
			},
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback =  function(dialog)
					dialog.info.blockDialogReleaseOnPress = false
					noChoiceOrToMap = false			
					KEYBIND_STRIP:AddKeybindButtonGroup(KELA_SETS_LIST.keybindStripDescriptor)
					local data = ZO_ScrollList_GetSelectedData(self.list)
					if data then KPUI_GAMEPAD_TOOLTIPS:LayoutSetTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, data) end
                end,
            },
            resetFilterButton,
        },
        noChoiceCallback = noChoiceCallback,
    })
end


function Kela_Sets_List:InitializeSearchFilter()
    ZO_GamepadInteractiveSortFilterList.InitializeSearchFilter(self)
    ZO_EditDefaultText_Initialize(self.searchEdit, GetString(KELA_SETS_SEARCHFIELD_DEFAULTTEXT))
end

function Kela_Sets_List:InitializeDropdownFilter()
	ZO_GamepadInteractiveSortFilterList.InitializeDropdownFilter(self)
	local dropdown = self.filterDropdown
	dropdown:ClearItems()
	
	local defaultIndex = 1
	local currentIndex = 0
	
	local changedCallback = nil

	local entry = ZO_ComboBox:CreateItemEntry("---", changedCallback)
	dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
	currentIndex = currentIndex + 1

	entry = ZO_ComboBox:CreateItemEntry(zo_strformat("<<1>>", GetUnitName("player")), changedCallback)
	dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
	currentIndex = currentIndex + 1

	local IGNORE_CALLBACK = true
	dropdown:SelectItemByIndex(defaultIndex, IGNORE_CALLBACK)
	dropdown:GetContainer():SetHidden(currentIndex == 1)		
	
end

function Kela_Sets_List:FilterScrollList()
	self:MainFilterScrollList()
end

function Kela_Sets_List:MainFilterScrollList()
	local tableSources
	local sourceIndex
	if KELA_SETS.CurrentSetsSource then 
		sourceIndex = KELA_SETS.CurrentSetsSource - 1
	else
		sourceIndex = 0
	end
	if sourceIndex == 0 then
		tableSources = KelaSetsSourceToType["ALLSOURCES"]
	elseif sourceIndex == 1 then
		tableSources = KelaSetsSourceToType["WORLD"]
	elseif sourceIndex == 2 then
		tableSources = KelaSetsSourceToType["DUNGEONS"]	
	elseif sourceIndex == 3 then
		tableSources = KelaSetsSourceToType["CRAFT"]
	elseif sourceIndex == 4 then
		tableSources = KelaSetsSourceToType["MONSTERSETS"]
	elseif sourceIndex == 5 then
		tableSources = KelaSetsSourceToType["TRIALS"]
	elseif sourceIndex == 6 then
		tableSources = KelaSetsSourceToType["PVP"]
	elseif sourceIndex == 7 then
		tableSources = KelaSetsSourceToType["OTHER"]
	end
	local obtainableIndex
	if KELA_SETS.CurrentSetsObtainable then 
		obtainableIndex = KELA_SETS.CurrentSetsObtainable - 1
	else
		obtainableIndex = 0
	end
	local bonusIndex
	if KELA_SETS.CurrentSetsBonus then 
		bonusIndex = KELA_SETS.CurrentSetsBonus - 1
	else
		bonusIndex = 0
	end
	local bindIndex
	if KELA_SETS.CurrentSetsBound then 
		bindIndex = KELA_SETS.CurrentSetsBound - 1
	else
		bindIndex = 0
	end
	local zoneIndex
	if KELA_SETS.CurrentSetsZoneID then 
		zoneIndex = KELA_SETS.CurrentSetsZoneID
	else
		zoneIndex = 0
	end
	local dlcIndex
	if KELA_SETS.CurrentSetsDLC then 
		dlcIndex = KELA_SETS.CurrentSetsDLC - 1
	else
		dlcIndex = 0
	end

    local scrollData = ZO_ScrollList_GetDataList(self.list)
    ZO_ClearNumericallyIndexedTable(scrollData)

	local tableFiltered = {}
	local tableFilteredFinal = {}

	local masterList = self:GetMasterList()
	local counts = 0
	
    for _, data in ipairs(masterList) do
		for i, sources in pairs(tableSources) do	
			if data["setSource"] == sources then
				counts = counts + 1
				table.insert(tableFiltered, data)
			end		
		end	
		tableFilteredFinal = tableFiltered
    end
	
	local header1Text = GetString("KELA_SETSSOURCE", sourceIndex).."("..counts..")"
	local filterText = GetString(KELA_SETSLIST_HEADER_FILTER)
	
	
	local header3Text = ""
	local blnFiltered = false
	tableFiltered = {}
	if obtainableIndex ~= 0 then
		local count = 0
		for _, data in ipairs(tableFilteredFinal) do
			for i, otype in pairs(data["setObtainableItemsTable"]) do
				if otype == obtainableIndex then
					table.insert(tableFiltered, data)
					count = count + 1
					break 
				end
			end
		end		
		tableFilteredFinal = tableFiltered
		header3Text = filterText..GetString("KELA_SETSOBTAINABLE", obtainableIndex).." ("..count..")"
		blnFiltered = true
	end

	tableFiltered = {}
	if bonusIndex ~= 0 then
		local count = 0
		for _, data in ipairs(tableFilteredFinal) do
			for i, obonus in pairs(data["setBonusesTable"]) do
				if obonus == bonusIndex then
					table.insert(tableFiltered, data)
					count = count + 1
					break 
				end
			end
		end		
		tableFilteredFinal = tableFiltered
		if blnFiltered then
			header3Text = header3Text..", "..GetString("KELA_SETSBONUSGROUP", bonusIndex).." ("..count..")"
		else
			header3Text = filterText..GetString("KELA_SETSBONUSGROUP", bonusIndex).." ("..count..")"
		end
		blnFiltered = true
	end
	
	tableFiltered = {}
	if bindIndex ~= 0 then
		local count = 0
		for _, data in ipairs(tableFilteredFinal) do
			if data["setBindType"] == bindIndex then
				table.insert(tableFiltered, data)
				count = count + 1
			end
		end		
		tableFilteredFinal = tableFiltered
		if blnFiltered then
			header3Text = header3Text..", "..GetString("KELA_SETSBOUND", bindIndex).." ("..count..")"
		else
			header3Text = filterText..GetString("KELA_SETSBOUND", bindIndex).." ("..count..")"
		end
		blnFiltered = true
	end

	tableFiltered = {}
	if zoneIndex ~= 0 then
		local count = 0
		for _, data in ipairs(tableFilteredFinal) do
			for i, oZone in pairs(data["setParentZonesTable"]) do
				if oZone == zoneIndex then
					table.insert(tableFiltered, data)
					count = count + 1
					break 
				end
			end
		end		
		tableFilteredFinal = tableFiltered
		if blnFiltered then
			header3Text = header3Text..", "..LibSets.GetZoneName(zoneIndex).." ("..count..")"
		else
			header3Text = filterText..LibSets.GetZoneName(zoneIndex).." ("..count..")"
		end
		blnFiltered = true
	end
	
	tableFiltered = {}
	if dlcIndex ~= 0 then
		local count = 0
		for _, data in ipairs(tableFilteredFinal) do
			if data["setDLCID"] == dlcIndex - 1 then
				table.insert(tableFiltered, data)
				count = count + 1
			end
		end		
		tableFilteredFinal = tableFiltered
		if blnFiltered then
			header3Text = header3Text..", "..LibSets.GetDLCName(dlcIndex - 1).." ("..count..")"
		else
			header3Text = filterText..LibSets.GetDLCName(dlcIndex - 1).." ("..count..")"
		end
		blnFiltered = true
	end
	
	tableFiltered = {}
    local searchTerm = self:GetCurrentSearch()
	local header2Text = ""
	if searchTerm ~= "" then 
		local count = 0
		for _, tables in ipairs(tableFilteredFinal) do
			for i, data in pairs(tables) do
				if type(data) == "string" and (string.match(string.lower(data), string.lower(searchTerm))) then
					table.insert(tableFiltered, tables)
					count = count + 1
					break
				end
			end
		end
		tableFilteredFinal = tableFiltered
		header2Text = GetString(KELA_SETSLIST_HEADER_SEARCH)..searchTerm.." ("..count..")"
	end

    for _, data in ipairs(tableFilteredFinal) do
		table.insert(scrollData, ZO_ScrollList_CreateDataEntry(KELA_LIST_DATA, data))
    end	
	
	ZO_SortFilterList.CommitScrollList(self)
	
	self.contentHeaderData.data1HeaderText = header1Text
	self.contentHeaderData.data2HeaderText = header3Text
	self.contentHeaderData.data3HeaderText = header2Text
	ZO_GamepadGenericHeader_RefreshData(self.contentHeader, self.contentHeaderData)

end

function Kela_Sets_List:ClearFilterScrollList(onlySearch)
	if onlySearch then
		KELA_SETS_LIST.searchEdit:SetText("")
	else	-- full reset
		KELA_SETS.CurrentSetsSource = 1
		KELA_SETS.CurrentSetsObtainable = 1
		KELA_SETS.CurrentSetsBonus = 1
		KELA_SETS.CurrentSetsBound = 1
		KELA_SETS.CurrentSetsZoneID = 0
		KELA_SETS.CurrentSetsZone = 1
		KELA_SETS.CurrentSetsDLC = 1
		
		KELA_SETS.currentDropdownSource:SelectItemByIndex(1, true)	
		KELA_SETS.currentDropdownObtainable:SelectItemByIndex(1, true)	
		KELA_SETS.currentDropdownBonus:SelectItemByIndex(1, true)	
		KELA_SETS.currentDropdownBound:SelectItemByIndex(1, true)	
		KELA_SETS.currentDropdownZone:SelectItemByIndex(1, true)	
		KELA_SETS.currentDropdownDLC:SelectItemByIndex(1, true)	

		KELA_SETS_LIST.searchEdit:SetText("")
		KELA_SETS_LIST.list.currentSortKey = "setName"
		KELA_SETS_LIST.list.currentSortOrder = ZO_SORT_ORDER_UP	
		KELA_SETS_LIST.sortHeaderGroup:SelectHeaderByKey(KELA_SETS_LIST.list.currentSortKey, false, true)	
	end
	self:MainFilterScrollList()		
	
	if self:IsActive() then
		local selectedData = ZO_ScrollList_GetSelectedData(self.list)
		if selectedData then
			-- make sure our selection is in view in case there was a large change from a filter
			local NO_CALLBACK = nil
			ZO_ScrollList_ScrollDataIntoView(self.list, ZO_ScrollList_GetSelectedDataIndex(self.list), NO_CALLBACK, ANIMATE_INSTANTLY)
		else
			-- if we've lost our selection and the panelFocalArea is active, then we want to
			-- AutoSelect the next appropriate entry
			ZO_ScrollList_AutoSelectData(self.list, ANIMATE_INSTANTLY)
		end			
	end
	
end


function Kela_Sets_List:SetupKelaListEntry(control, data)
    control.labelName:SetText(data.setName)
	control.labelObtainableItems:SetText(data.setObtainableItems)
	control.labelSetType:SetText(data.setTypeName)
	control.labelSource:SetText(data.setZoneNames)
	control.labelDLC:SetText(data.setDLCName)
end
-- sort-column selection
function Kela_Sets_List:SetNextSortKey(right)
	local curSortKey = KELA_SETS_LIST.currentSortKey
	local nextIndex
	for i, k in pairs(KELA_LIST_ENTRY_SORT_KEYS["keysByIndex"]) do
		if k == curSortKey then 
			if right and i < 5 then
				nextIndex = i + 1
			elseif not right and i > 1 then
				nextIndex = i - 1
			end
			break
		end
	end
	if nextIndex then 
		KELA_SETS_LIST.list.currentSortKey = KELA_LIST_ENTRY_SORT_KEYS["keysByIndex"][nextIndex]
		KELA_SETS_LIST.list.currentSortOrder = ZO_SORT_ORDER_UP	
		KELA_SETS_LIST.sortHeaderGroup:SelectHeaderByKey(KELA_SETS_LIST.list.currentSortKey, false, true)	
	end
end

function Kela_Sets_List:SetMasterSetsList()

	if KelaSetsMasterListInitialized == true then return end
	
	local MasterList = {}
    ZO_ClearNumericallyIndexedTable(MasterList)
	local tableSetIDs = LibSets.GetAllSetIds()

	local function GetSetTypeByKela(setID)
		local mayBeRing = LibSets.GetSetItemId(setID, EQUIP_TYPE_RING)		
		local mayBeNeck = LibSets.GetSetItemId(setID, EQUIP_TYPE_NECK)
		local mayBeChest = LibSets.GetSetItemId(setID, EQUIP_TYPE_CHEST)
		local mayBeFeet = LibSets.GetSetItemId(setID, EQUIP_TYPE_FEET)
		local mayBeHand = LibSets.GetSetItemId(setID, EQUIP_TYPE_HAND)
		local mayBeHead = LibSets.GetSetItemId(setID, EQUIP_TYPE_HEAD)
		local mayBeLegs = LibSets.GetSetItemId(setID, EQUIP_TYPE_LEGS)
		local mayBeShoulders = LibSets.GetSetItemId(setID, EQUIP_TYPE_SHOULDERS)
		local mayBeWaist = LibSets.GetSetItemId(setID, EQUIP_TYPE_WAIST)	
		local mayBeOneHand = LibSets.GetSetItemId(setID, EQUIP_TYPE_ONE_HAND)
		local mayBeTwoHand = LibSets.GetSetItemId(setID, EQUIP_TYPE_TWO_HAND)
		local setTypeByKela = ""
		local setTypeByKelaFull = ""
		local setTypeByKelaSort = ""
		local setObtainableItemsTable = {}
		local setColor
		local bindType = nil
		if mayBeChest or mayBeFeet or mayBeHand or mayBeHead or mayBeLegs or mayBeShoulders or mayBeWaist then 
			setTypeByKela = colors.COLOR_WHITE:Colorize(GetString(KELA_SETSTYPE_ARMOR)).." "
			setTypeByKelaSort = GetString(KELA_SETSTYPE_ARMOR).." "
			setTypeByKelaFull = setTypeByKela
			local armorTypesOfSet = LibSets.GetSetArmorTypes(setID)
			local isLight, isMedium, isHeavy
			local blnGot = false
			for key, bool in pairs(armorTypesOfSet) do		
				if bool and key ~= ARMORTYPE_NONE then 

					if key == ARMORTYPE_LIGHT then
						setColor = colors.COLOR_MAGICKA
						setTypeByKela = setTypeByKela..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_LIGHT))
						setTypeByKelaSort = setTypeByKelaSort..GetString(KELA_SETSTYPE_ARMORTYPE_LIGHT)
						if not blnGot then 
							setTypeByKelaFull = setTypeByKelaFull..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_LIGHTFULL))
							blnGot = true
						else
							setTypeByKelaFull = setTypeByKelaFull.."/"..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_LIGHTFULL))
						end
						setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.ARMOR_LIGHT
						isLight = true
					elseif key == ARMORTYPE_MEDIUM then
						setColor = colors.COLOR_STAMINA
						setTypeByKela = setTypeByKela..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_MEDIUM))
						setTypeByKelaSort = setTypeByKelaSort..GetString(KELA_SETSTYPE_ARMORTYPE_MEDIUM)
						if not blnGot then 
							setTypeByKelaFull = setTypeByKelaFull..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_MEDIUMFULL))
							blnGot = true
						else
							setTypeByKelaFull = setTypeByKelaFull.."/"..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_MEDIUMFULL))
						end
						setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.ARMOR_MEDIUM
						isMedium = true
					elseif key == ARMORTYPE_HEAVY then
						setColor = colors.COLOR_HEALTH
						setTypeByKela = setTypeByKela..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_HEAVY))
						setTypeByKelaSort = setTypeByKelaSort..GetString(KELA_SETSTYPE_ARMORTYPE_HEAVY)
						if not blnGot then 
							setTypeByKelaFull = setTypeByKelaFull..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_HEAVYFULL))
							blnGot = true
						else
							setTypeByKelaFull = setTypeByKelaFull.."/"..setColor:Colorize(GetString(KELA_SETSTYPE_ARMORTYPE_HEAVYFULL))
						end
						setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.ARMOR_HEAVY
						isHeavy = true
					end
				end
			end
					
			if isLight and isMedium and isHeavy then 
				setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.ARMOR_COMPLECT
			end
			
			bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeChest, 370))
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeFeet, 370))
			end
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeHand, 370))
			end
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeHead, 370))
			end
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeLegs, 370))
			end
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeShoulders, 370))
			end
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeWaist, 370))
			end
		end
		if mayBeOneHand or mayBeTwoHand then 
			setColor = colors.COLOR_GOLD
			if setTypeByKela == "" then
				setTypeByKela = setColor:Colorize(GetString(KELA_SETSTYPE_WEAPON)) 
				setTypeByKelaSort = GetString(KELA_SETSTYPE_WEAPON)
				setTypeByKelaFull = setTypeByKela
			else
				setTypeByKela = setTypeByKela..", "..setColor:Colorize(GetString(KELA_SETSTYPE_WEAPON))
				setTypeByKelaSort = setTypeByKelaSort..", "..GetString(KELA_SETSTYPE_WEAPON)
				setTypeByKelaFull = setTypeByKelaFull..", "..setColor:Colorize(GetString(KELA_SETSTYPE_WEAPON))				
			end	
			if (mayBeNeck or mayBeRing) or (mayBeChest or mayBeFeet or mayBeHand or mayBeHead or mayBeLegs or mayBeShoulders or mayBeWaist) then 
				setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.WEAPON_INCOMPLECT		
			else
				setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.WEAPON	
			end
			bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeOneHand, 370))
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeTwoHand, 370))
			end
			
		end
		if mayBeNeck or mayBeRing then 
			setColor = colors.COLOR_VIOLET
			if setTypeByKela == "" then
				setTypeByKela = setColor:Colorize(GetString(KELA_SETSTYPE_JEWELRY))
				setTypeByKelaSort = GetString(KELA_SETSTYPE_JEWELRY)
				setTypeByKelaFull = setTypeByKela
			else
				setTypeByKela = setTypeByKela..", "..setColor:Colorize(GetString(KELA_SETSTYPE_JEWELRY))
				setTypeByKelaSort = setTypeByKelaSort..", "..GetString(KELA_SETSTYPE_JEWELRY)
				setTypeByKelaFull = setTypeByKelaFull..", "..setColor:Colorize(GetString(KELA_SETSTYPE_JEWELRY))
			end		
			if (mayBeOneHand or mayBeTwoHand) or (mayBeChest or mayBeFeet or mayBeHand or mayBeHead or mayBeLegs or mayBeShoulders or mayBeWaist) then 
				setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.JEWELRY_INCOMPLECT		
			else
				setObtainableItemsTable[#setObtainableItemsTable + 1] = KelaSetObtainable.JEWELRY	
			end
			bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeNeck, 370))
			if bindType == BIND_TYPE_NONE or bindType == BIND_TYPE_UNSET then 
				bindType = GetItemLinkBindType(LibSets.buildItemLink(mayBeRing, 370))
			end
			
		end
		return setTypeByKelaSort, setTypeByKela, setTypeByKelaFull, setObtainableItemsTable, bindType
	end

	if not tableSetIDs then 
		self:SetMasterList({})
	else
		for setID, isActive in pairs(tableSetIDs) do
			if isActive == true then
				local setData = LibSets.GetSetInfo(setID)
				local setDLCID = setData.dlcId
				local setDLCName = LibSets.GetDLCName(setDLCID)
				local setSource = setData.setType
				local setItemsID = setData[LIBSETS_TABLEKEY_SETITEMIDS]
				local setName = setData[LIBSETS_TABLEKEY_SETNAMES][LibSets.clientLang]
				local setTraits = setData.traitsNeeded
				local setVeteran = setData.veteran
				local setWayshrines = setData.wayshrines
				local setZoneIds = setData.zoneIds
				local setParentZonesTable = {}
				local setBonusesTable = {}
				local setDropMechanic = setData.dropMechanic
				local setTypeName
				local setTypeNameSort
				local setZoneNames
				local canTeleport
				local setWayshrinesTrue = false
				local setObtainableItemsSort, setObtainableItems, setObtainableItemsFull, setObtainableItemsTable, setBindType = GetSetTypeByKela(setID)
				if setBindType == 3 then setBindType = 1 end
				
				if setSource == LIBSETS_SETTYPE_ARENA then
					setTypeName = colors.COLOR_ORANGE:Colorize(GetString(KELA_SETSSOURCE5))
					setTypeNameSort = GetString(KELA_SETSSOURCE5)
				elseif setSource == LIBSETS_SETTYPE_BATTLEGROUND then
					setTypeName = colors.COLOR_BLUE:Colorize(GetString(KELA_SETSSOURCE6))
					setTypeNameSort = GetString(KELA_SETSSOURCE6)
				elseif setSource == LIBSETS_SETTYPE_CRAFTED then
					setTypeName = colors.COLOR_PINK:Colorize(GetString(KELA_SETSSOURCE3).." ("..tostring(setTraits)..")")
					setTypeNameSort = GetString(KELA_SETSSOURCE3).." ("..tostring(setTraits)..")"
				elseif setSource == LIBSETS_SETTYPE_CYRODIIL then
					setTypeName = colors.COLOR_BLUE:Colorize(GetString(KELA_SETSSOURCE6))
					setTypeNameSort = GetString(KELA_SETSSOURCE6)
				elseif setSource == LIBSETS_SETTYPE_DAILYRANDOMDUNGEONANDICREWARD then
					setTypeName = colors.COLOR_TEAL:Colorize(GetString(KELA_SETSSOURCE2))
					setTypeNameSort = GetString(KELA_SETSSOURCE2)
				elseif setSource == LIBSETS_SETTYPE_DUNGEON then
					setTypeName = colors.COLOR_TEAL:Colorize(GetString(KELA_SETSSOURCE2))
					setTypeNameSort = GetString(KELA_SETSSOURCE2)
				elseif setSource == LIBSETS_SETTYPE_IMPERIALCITY then
					setTypeName = colors.COLOR_BLUE:Colorize(GetString(KELA_SETSSOURCE6))
					setTypeNameSort = GetString(KELA_SETSSOURCE6)
				elseif setSource == LIBSETS_SETTYPE_MONSTER then
					setTypeName = colors.COLOR_BROWN1:Colorize(GetString(KELA_SETSSOURCE4))
					setTypeNameSort = GetString(KELA_SETSSOURCE4)
				elseif setSource == LIBSETS_SETTYPE_OVERLAND then
					setTypeName = colors.COLOR_GREEN:Colorize(GetString(KELA_SETSSOURCE1))
					setTypeNameSort = GetString(KELA_SETSSOURCE1)
				elseif setSource == LIBSETS_SETTYPE_SPECIAL then
					setTypeName = colors.COLOR_MYTHIC:Colorize(GetString(KELA_SETSSOURCE13))
					setTypeNameSort = GetString(KELA_SETSSOURCE13)
				elseif setSource == LIBSETS_SETTYPE_TRIAL then
					setTypeName = colors.COLOR_ORANGE:Colorize(GetString(KELA_SETSSOURCE5))
					setTypeNameSort = GetString(KELA_SETSSOURCE5)
				elseif setSource == LIBSETS_SETTYPE_MYTHIC then
					setTypeName = colors.COLOR_MYTHIC:Colorize(GetString(KELA_SETSSOURCE15))
					setTypeNameSort = GetString(KELA_SETSSOURCE15)
				end
				
				if setVeteran then setName = setName.." ("..colors.COLOR_ORANGE:Colorize(GetString(KELA_SETS_VETERAN))..")" end				

				local itemID = LibSets.GetSetItemId(setID)
				local itemLink = LibSets.buildItemLink(itemID, 370)
				local setBonusesString = ""
				if itemLink then
					local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
					for i=1, numBonuses do
						local _, bonusDescription = GetItemLinkSetBonusInfo(itemLink, false, i)
						-- for search
						if bonusDescription then
							setBonusesString = setBonusesString.."/"..bonusDescription
						end
						-- for filter
						for k=1, 50 do
							if string.match (string.lower(bonusDescription), string.lower(GetString("SI_DERIVEDSTATS", k))) then
								setBonusesTable[#setBonusesTable + 1] = DerivedStatsForBonusGroup["SI_DERIVEDSTATS"..k]
							end
						end
					end		
				end				

				if setZoneIds then
					for i, z in pairs(setZoneIds) do
						local parentZoneID = GetParentZoneId(z)
						if setSource ~= LIBSETS_SETTYPE_SPECIAL then
							local zAlliance = kelaGetAlliance(z)
							local zIcon = GetAllianceSymbolIcon(zAlliance)
							local zName = LibSets.GetZoneName(z)
							local parentName = LibSets.GetZoneName(parentZoneID)
							local hasParent = false
							if zName ~= parentName then 
								hasParent = true
								local pAlliance = kelaGetAlliance(parentZoneID)
								local pIcon = GetAllianceSymbolIcon(pAlliance)
								if pIcon then parentName = parentName..zo_iconFormat(pIcon, 24, 24) end
								local twoLevels = string.find(zName,"I")
								if twoLevels then
									local ind = twoLevels - 1
									zName = string.sub(zName, 1, ind).."("..parentName..")"
								else
									zName = zName.." ("..parentName..")"
								end								
							else
								if zIcon then zName = zName..zo_iconFormat(zIcon, 24, 24) end
							end
							if i == 1 then 
								setZoneNames = zName
							elseif not hasParent then
								if not string.match (setZoneNames, zName) then setZoneNames = setZoneNames..", "..zName end
							end
						end
						
						canTeleport = (GetMapIndexByZoneId(z) or GetMapIndexByZoneId(parentZoneID))

						
						setParentZonesTable[#setParentZonesTable + 1] = parentZoneID
						
					end	
				end
				
				
				-- for search
				local DMText
				local DMTextFull
				if setDropMechanic then 
					local count = 0
					for i, ID in pairs(setDropMechanic) do
						count = count + 1
						local tooltipMechanic, tooltipMechanicFull = LibSets.GetDropMechanicName(ID)
						if count == 1 then
							DMText = tooltipMechanic
							DMTextFull = colors.COLOR_BROWN:Colorize(tostring(count)..".  "..tostring(tooltipMechanicFull))
						else
							DMText = DMText..", "..tooltipMechanic
							DMTextFull = DMTextFull.."\n"..colors.COLOR_BROWN:Colorize(tostring(count)..".  "..tostring(tooltipMechanicFull))
						end
					end
				end					
			
				for i = 1, #setWayshrines do
					if setWayshrines[i] > 0 then
						setWayshrinesTrue = true
						break
					end
				end	
				
				local data = { 
				setID = setID,
				setName = setName,
				setDLCID = setDLCID,
				setDLCName = setDLCName,
				setSource = setSource,
				setObtainableItemsTable = setObtainableItemsTable,
				setBonusesTable = setBonusesTable,
				setBonusesString = setBonusesString,
				setObtainableItems = setObtainableItems,
				setObtainableItemsFull = setObtainableItemsFull,
				setObtainableItemsSort = setObtainableItemsSort,
				setItemsID = setItemsID,
				setTypeName = setTypeName,
				setTypeNameSort = setTypeNameSort,
				setTraits = setTraits,
				setVeteran = setVeteran,
				setBindType = setBindType,
				setWayshrinesTrue = setWayshrinesTrue,
				canTeleport = canTeleport,
				setWayshrines = setWayshrines,
				setZoneIds = setZoneIds,
				setParentZonesTable = setParentZonesTable,
				setZoneNames = setZoneNames,
				setDropMechanic = setDropMechanic,
				DMText = DMText,
				DMTextFull = DMTextFull,
				}
				MasterList[#MasterList + 1] = data
	
			end
		end
		table.sort(MasterList, function (a,b) return (string.lower(a["setName"]) < string.lower(b["setName"])) end)
		self:SetMasterList(MasterList)
		KelaSetsMasterListInitialized = true
    end
end

function Kela_Sets_List:OnSelectionChanged(oldData, newData)
    ZO_GamepadInteractiveSortFilterList.OnSelectionChanged(self, oldData, newData)
	if self.showInfoTooltip then
		if newData then
			KELA_LAST_SELECTED_DATA = ZO_ScrollList_GetSelectedData(self.list)
			kelaReColorDescription(true)
			KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP)
			KPUI_GAMEPAD_TOOLTIPS:LayoutSetTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP, newData)		
			KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
		else
			KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_RIGHT_TOOLTIP)
		end
	end
end


---KELA_SETS---------------------------------------------------------------
---------------------------------------------------------------------------
function Kela_Sets:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function Kela_Sets:Initialize(control)
    KELA_SETS_SCENE = ZO_Scene:New("kelaSets", SCENE_MANAGER)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, nil, KELA_SETS_SCENE)
    local kelaSetsFragment = ZO_FadeSceneFragment:New(control)
    KELA_SETS_SCENE:AddFragment(kelaSetsFragment)
    self.headerData = {
        titleText = GetString(KELA_MAINMENU_SETS),
    }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    local list = self:GetMainList()
    list:SetHandleDynamicViewProperties(true)
end

function Kela_Sets:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Select
        {
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = "KPUI Sets 2 " .. GetString(SI_GAMEPAD_SELECT_OPTION),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
					local row = self:GetMainList():GetSelectedIndex()
					if row == KELA_SETS_ROW_DROPSOURCE or row == KELA_SETS_ROW_DROPOBTAINABLE or row == KELA_SETS_ROW_DROPBONUS or row == KELA_SETS_ROW_DROPBOUND or row == KELA_SETS_ROW_DROPZONE or row == KELA_SETS_ROW_DROPDLC then
						self:ActivateSetsDropdown(row)
					end	
					KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
                end,
        },
        -- Clear filter
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,	
            name = GetString(KELA_SETSKEY_CLEARFILTER),
			keybind = "UI_SHORTCUT_TERTIARY",
			visible = function()
					local filterDirty = (self.CurrentSetsSource ~= 1 or self.CurrentSetsObtainable ~= 1 or self.CurrentSetsBonus ~= 1 or self.CurrentSetsBound ~= 1 or self.CurrentSetsZone ~= 1 or self.CurrentSetsDLC ~= 1 or KELA_SETS_LIST:GetCurrentSearch() ~= "")
					return filterDirty
                end,
            callback = function()
					KELA_SETS_LIST:ClearFilterScrollList()
				    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
                end,
        },
        -- Activate list
        {
            alignment = KEYBIND_STRIP_ALIGN_CENTER,	
            name = GetString(KELA_SETSKEY_VIEW),
			keybind = "UI_SHORTCUT_INPUT_RIGHT",
            callback = function()
					self:ActivateSetsList()
                end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self:GetMainList())
end

-- jump to the last selected list entry
local GetDataTypeInfo
do
    local advanceCursorOperation = ZO_ScrollList_AdvanceCursor_Operation:New()
    local lineBreakOperation = ZO_ScrollList_LineBreak_Operation:New()

    function GetDataTypeInfo(self, typeId)
        if typeId == ZO_SCROLL_LIST_OPERATION_ADVANCE_CURSOR then
            return advanceCursorOperation
        elseif typeId == ZO_SCROLL_LIST_OPERATION_LINE_BREAK then
            return lineBreakOperation
        end
    
        return self.dataTypes[typeId]
    end
end
local function CanSelectData(self, index)
    local dataEntry = self.data[index]
    if dataEntry == nil then
        return false
    end
    local dataTypeInfo = GetDataTypeInfo(self, dataEntry.typeId)
    return dataTypeInfo.selectable
end
function Kela_TrySelectLastData(self, onScrollCompleteCallback, shouldAnimateInstantly)
	for i = #self.data, 1, -1 do
        if CanSelectData(self, i) and (KELA_LAST_SELECTED_DATA == self.data[i].data)then
            ZO_ScrollList_SelectDataAndScrollIntoView(self, self.data[i].data, onScrollCompleteCallback, false)
            return true
        end
    end
    return false
end
---------------------------------------------------

function Kela_Sets:ActivateSetsList()
	KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP)	
    KELA_SETS:DeactivateCurrentList()
	KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
	Kela_TrySelectLastData(KELA_SETS_LIST.list)
    KELA_SETS_LIST:Activate()	
end
function Kela_Sets:ActivateCategories()
	KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    self:ActivateCurrentList()
end

function SelectSetsSource(comboBox, name, entry, selectionChange)
	if selectionChange then
		KELA_SETS.CurrentSetsSource = KELA_SETS.currentDropdownSource:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function SelectSetsObtainable(comboBox, name, entry, selectionChange)	
	if selectionChange then
		KELA_SETS.CurrentSetsObtainable = KELA_SETS.currentDropdownObtainable:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function SelectSetsBonus(comboBox, name, entry, selectionChange)	
	if selectionChange then
		KELA_SETS.CurrentSetsBonus = KELA_SETS.currentDropdownBonus:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function SelectSetsBound(comboBox, name, entry, selectionChange)
	if selectionChange then
		KELA_SETS.CurrentSetsBound = KELA_SETS.currentDropdownBound:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function SelectSetsZone(comboBox, name, entry, selectionChange)
	if selectionChange then
		KELA_SETS.CurrentSetsZoneID = entry.index
		KELA_SETS.CurrentSetsZone = KELA_SETS.currentDropdownZone:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function SelectSetsDLC(comboBox, name, entry, selectionChange)
	if selectionChange then
		KELA_SETS.CurrentSetsDLC = KELA_SETS.currentDropdownDLC:GetHighlightedIndex()
		KELA_SETS_LIST:MainFilterScrollList()
	end
end
function Kela_Sets:ActivateMainList()
    local mainList = self:GetMainList()
    if not mainList:IsActive() then
        mainList:Activate()
        KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    end
end
function Kela_Sets:DeactivateMainList()
    local mainList = self:GetMainList()
	if mainList:IsActive() then
        mainList:Deactivate()
        local selectedControl = mainList:GetSelectedControl()
        if selectedControl and selectedControl.pointLimitedSpinner then
            selectedControl.pointLimitedSpinner:SetActive(false)
        end
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    end
end
function Kela_Sets:ActivateSetsDropdown(row)
	local currentIndex 
	local currentDropdown
	if row == KELA_SETS_ROW_DROPSOURCE then
		currentIndex = self.CurrentSetsSource
		currentDropdown = self.currentDropdownSource
	elseif row == KELA_SETS_ROW_DROPOBTAINABLE then
		currentIndex = self.CurrentSetsObtainable
		currentDropdown = self.currentDropdownObtainable
	elseif row == KELA_SETS_ROW_DROPBONUS then
		currentIndex = self.CurrentSetsBonus
		currentDropdown = self.currentDropdownBonus
	elseif row == KELA_SETS_ROW_DROPBOUND then
		currentIndex = self.CurrentSetsBound
		currentDropdown = self.currentDropdownBound
	elseif row == KELA_SETS_ROW_DROPZONE then
		currentIndex = self.CurrentSetsZone
		currentDropdown = self.currentDropdownZone
	elseif row == KELA_SETS_ROW_DROPDLC then
		currentIndex = self.CurrentSetsDLC
		currentDropdown = self.currentDropdownDLC
	end
	if currentDropdown ~= nil then
        self:DeactivateMainList()
        currentDropdown:Activate()
		if not currentIndex then currentIndex = 1 end
		currentDropdown:SetHighlightedItem(currentIndex)
    end
end
function Kela_Sets:OnDropdownDeactivated()
    self:ActivateMainList()
end
function Kela_Sets:UpdateDropdownSelection(dropdown, row)
    local currentIndex 
	if row == KELA_SETS_ROW_DROPSOURCE then
		currentIndex = self.CurrentSetsSource
		if currentIndex then
			dropdown:SetSelectedItemText(GetString("KELA_SETSSOURCE", currentIndex - 1))
		else
			dropdown:SetSelectedItemText(GetString("KELA_SETSSOURCE", 0))
		end	
	elseif row == KELA_SETS_ROW_DROPOBTAINABLE then
		currentIndex = self.CurrentSetsObtainable
		if currentIndex then
			dropdown:SetSelectedItemText(GetString("KELA_SETSOBTAINABLE", currentIndex - 1))
		else
			dropdown:SetSelectedItemText(GetString("KELA_SETSOBTAINABLE", 0))
		end		
	elseif row == KELA_SETS_ROW_DROPBONUS then
		currentIndex = self.CurrentSetsBonus
		if currentIndex then
			dropdown:SetSelectedItemText(GetString("KELA_SETSBONUSGROUP", currentIndex - 1))
		else
			dropdown:SetSelectedItemText(GetString("KELA_SETSBONUSGROUP", 0))
		end		
	elseif row == KELA_SETS_ROW_DROPBOUND then
		currentIndex = self.CurrentSetsBound
		if currentIndex then
			dropdown:SetSelectedItemText(GetString("KELA_SETSBOUND", currentIndex - 1))
		else
			dropdown:SetSelectedItemText(GetString("KELA_SETSBOUND", 0))
		end		
	elseif row == KELA_SETS_ROW_DROPZONE then
		currentIndex = self.CurrentSetsZoneID		
		if currentIndex and currentIndex ~= 0 then
			local zoneName = LibSets.GetZoneName(currentIndex)
			dropdown:SetSelectedItemText(zoneName)
		else
			dropdown:SetSelectedItemText(GetString(KELA_SETSZONE0))
		end		
	elseif row == KELA_SETS_ROW_DROPDLC then
		currentIndex = self.CurrentSetsDLC
		if currentIndex and currentIndex ~= 1 then
			local dlcName = LibSets.GetDLCName(currentIndex - 2)
			dropdown:SetSelectedItemText(dlcName)
		else
			dropdown:SetSelectedItemText(GetString(KELA_SETSDLC0))
		end		
	end
end
function Kela_Sets:SetCurrentDropdown(dropdown, row)
	dropdown:ClearItems()
	if row == KELA_SETS_ROW_DROPSOURCE then
		self.currentDropdownSource = dropdown
		for k=0, 7 do		
			local sourceName = GetString("KELA_SETSSOURCE", k)
			local entry = ZO_ComboBox:CreateItemEntry(tostring(sourceName), SelectSetsSource, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = k
			dropdown:AddItem(entry)
		end
	elseif row == KELA_SETS_ROW_DROPOBTAINABLE then
		self.currentDropdownObtainable = dropdown
		for k=0, 8 do		
			local obtainableName = GetString("KELA_SETSOBTAINABLE", k)
			local entry = ZO_ComboBox:CreateItemEntry(tostring(obtainableName), SelectSetsObtainable, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = k
			dropdown:AddItem(entry)
		end
	elseif row == KELA_SETS_ROW_DROPBONUS then
		self.currentDropdownBonus = dropdown
		for k=0, 6 do		
			local bonusName = GetString("KELA_SETSBONUSGROUP", k)
			local entry = ZO_ComboBox:CreateItemEntry(tostring(bonusName), SelectSetsBonus, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = k
			dropdown:AddItem(entry)
		end
	elseif row == KELA_SETS_ROW_DROPBOUND then
		self.currentDropdownBound = dropdown
		for k=0, 2 do		
			local boundName = GetString("KELA_SETSBOUND", k)
			local entry = ZO_ComboBox:CreateItemEntry(tostring(boundName), SelectSetsBound, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = k
			dropdown:AddItem(entry)
		end
	elseif row == KELA_SETS_ROW_DROPZONE then
		self.currentDropdownZone = dropdown
		local zoneName = GetString(KELA_SETSZONE0)
		local entry = ZO_ComboBox:CreateItemEntry(tostring(zoneName), SelectSetsZone, ZO_COMBOBOX_SUPRESS_UPDATE)
		entry.index = 0
		dropdown:AddItem(entry)
		for i, zoneData in ZONE_STORIES_MANAGER:ZoneListIterator() do
			local zoneName = zoneData.name
			entry = ZO_ComboBox:CreateItemEntry(tostring(zoneName), SelectSetsZone, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = zoneData.id
			dropdown:AddItem(entry)
		end
	elseif row == KELA_SETS_ROW_DROPDLC then
		self.currentDropdownDLC = dropdown
		local tableDLC = LibSets.GetAllDLCIds()
		local dlcName = GetString(KELA_SETSDLC0)
		local entry = ZO_ComboBox:CreateItemEntry(tostring(dlcName), SelectSetsDLC, ZO_COMBOBOX_SUPRESS_UPDATE)
		entry.index = 0
		dropdown:AddItem(entry)
		for i = 1, #tableDLC + 1 do 
			local dlcName = LibSets.GetDLCName(i-1)
			entry = ZO_ComboBox:CreateItemEntry(tostring(dlcName), SelectSetsDLC, ZO_COMBOBOX_SUPRESS_UPDATE)
			entry.index = i
			dropdown:AddItem(entry)
		end
	end
	dropdown:UpdateItems()
	self:UpdateDropdownSelection(dropdown, row)	
end
function KelaSourceDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPSOURCE)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end
function KelaObtainableDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPOBTAINABLE)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end
function KelaBonusDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPBONUS)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end
function KelaBoundDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPBOUND)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end
function KelaZoneDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPZONE)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end
function KelaDLCDropdown_Setup(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    control.dropdown:SetSortsItems(false)
    KELA_SETS:SetCurrentDropdown(control.dropdown, KELA_SETS_ROW_DROPDLC)
    control.dropdown:SetDeactivatedCallback(KELA_SETS.OnDropdownDeactivated, KELA_SETS)
    control.dropdown:SetSelectedItemTextColor(selected)
end

do
    local function AddEntry(row, list, name, header, icon)
		if row == KELA_SETS_ROW_DROPSOURCE then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaSourceDropdownTemplate", data)
		elseif row == KELA_SETS_ROW_DROPOBTAINABLE then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaObtainableDropdownTemplate", data)	
		elseif row == KELA_SETS_ROW_DROPBONUS then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaBonusDropdownTemplate", data)	
		elseif row == KELA_SETS_ROW_DROPBOUND then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaBoundDropdownTemplate", data)	
		elseif row == KELA_SETS_ROW_DROPZONE then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaZoneDropdownTemplate", data)	
		elseif row == KELA_SETS_ROW_DROPDLC then
			local data = ZO_GamepadEntryData:New("")
			data.row = row
			data:SetHeader(GetString(header))
			list:AddEntryWithHeader("KelaDLCDropdownTemplate", data)	
		end
    end
		
    function Kela_Sets:PopulateList()
        local list = self:GetMainList()
        list:Clear()
		-- add templates to the list
		list:AddDataTemplate("KelaSourceDropdownTemplate", KelaSourceDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaSourceDropdownTemplate", KelaSourceDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")		
		list:AddDataTemplate("KelaObtainableDropdownTemplate", KelaObtainableDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaObtainableDropdownTemplate", KelaObtainableDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")	
		list:AddDataTemplate("KelaBonusDropdownTemplate", KelaBonusDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaBonusDropdownTemplate", KelaBonusDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")	
		list:AddDataTemplate("KelaBoundDropdownTemplate", KelaBoundDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaBoundDropdownTemplate", KelaBoundDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")	
		list:AddDataTemplate("KelaZoneDropdownTemplate", KelaZoneDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaZoneDropdownTemplate", KelaZoneDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
		list:AddDataTemplate("KelaDLCDropdownTemplate", KelaDLCDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader("KelaDLCDropdownTemplate", KelaDLCDropdown_Setup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadMenuEntryHeaderTemplate")
		-- add rows
		AddEntry(KELA_SETS_ROW_DROPSOURCE, list, nil, KELA_SETS_SOURCEDROPDOWN_HEADER)
		AddEntry(KELA_SETS_ROW_DROPOBTAINABLE, list, nil, KELA_SETS_OBTAINABLEDROPDOWN_HEADER)
		AddEntry(KELA_SETS_ROW_DROPBONUS, list, nil, KELA_SETS_BONUSDROPDOWN_HEADER)
		AddEntry(KELA_SETS_ROW_DROPBOUND, list, nil, KELA_SETS_BOUNDDROPDOWN_HEADER)
		AddEntry(KELA_SETS_ROW_DROPZONE, list, nil, KELA_SETS_ZONEDROPDOWN_HEADER)
		AddEntry(KELA_SETS_ROW_DROPDLC, list, nil, KELA_SETS_DLCDROPDOWN_HEADER)
		list:Commit()
    end
end

function Kela_Sets:OnSelectionChanged(list, selectedData, oldSelectedData)
     KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
end

function Kela_Sets:OnShowing()
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
	if KelaSetsMasterListInitialized == false then KELA_SETS_LIST:SetMasterSetsList() end

	if KELA_SETS_FIRST_SHOW then 
		KELA_SETS_LIST:Deactivate()
		if not KELA_SETS.CurrentSetsSource then KELA_SETS.CurrentSetsSource = 1 end
		if not KELA_SETS.CurrentSetsObtainable then KELA_SETS.CurrentSetsObtainable = 1 end
		if not KELA_SETS.CurrentSetsBonus then KELA_SETS.CurrentSetsBonus = 1 end
		if not KELA_SETS.CurrentSetsBound then KELA_SETS.CurrentSetsBound = 1 end
		if not KELA_SETS.CurrentSetsZone then KELA_SETS.CurrentSetsZone = 1 end
		if not KELA_SETS.CurrentSetsDLC then KELA_SETS.CurrentSetsDLC = 1 end
		KELA_SETS_LIST:MainFilterScrollList()	
		KELA_SETS_FIRST_SHOW = false
	end

	if noChoiceOrToMap then
		self:ActivateSetsList()
		noChoiceOrToMap = false
	end

	KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)

end

function Kela_Sets:OnHiding()

	KPUI_GAMEPAD_TOOLTIPS:ClearTooltip(KPUI_GAMEPAD_LEFT_DIALOG_TOOLTIP)	

	-- close drop-down lists
    if self.currentDropdownSource and self.currentDropdownSource:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownSource:Deactivate(BLOCK_CALLBACK)
    end
    if self.currentDropdownObtainable and self.currentDropdownObtainable:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownObtainable:Deactivate(BLOCK_CALLBACK)
    end
    if self.currentDropdownBonus and self.currentDropdownBonus:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownBonus:Deactivate(BLOCK_CALLBACK)
    end
    if self.currentDropdownBound and self.currentDropdownBound:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownBound:Deactivate(BLOCK_CALLBACK)
    end
    if self.currentDropdownZone and self.currentDropdownZone:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownZone:Deactivate(BLOCK_CALLBACK)
    end
    if self.currentDropdownDLC and self.currentDropdownDLC:IsActive() then
        local BLOCK_CALLBACK = true
        self.currentDropdownDLC:Deactivate(BLOCK_CALLBACK)
    end
	KELA_SETS:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(KELA_SETS.keybindStripDescriptor)
	KELA_SETS_LIST:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(KELA_SETS_LIST.keybindStripDescriptor)
end
function Kela_Sets:PerformUpdate()
    self:PopulateList()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    self.headerData.titleText = GetString(KELA_MAINMENU_SETS)
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
end

-- XML Functions
function Kela_Sets_OnInitialize(control)
    KELA_SETS = Kela_Sets:New(control)
	SYSTEMS:RegisterGamepadObject("kelaSets", KELA_SETS)
end

function Kela_Sets_List_OnInitialize(control)
    KELA_SETS_LIST = Kela_Sets_List:New(control)
end
