local Addon = {}
Addon.Name = "LeadList"
Addon.DisplayName = "Lead List"
Addon.Author = "Irhak"
Addon.Version = "51.0.0"

ILeadList = ILeadList or {}
local ILL = ILeadList


-- Unitlist stuff adapted from Scroll List Example Addon

ILLUnitList = ZO_SortFilterList:Subclass()
ILLUnitList.defaults = {}


ILL.UnitList = nil
ILL.units = {}

ILLUnitList.SORT_KEYS = {
		["Lead"] = {},
		["Zone"] = {tiebreaker="Lead"},
		["Location"] = {tiebreaker="Lead"},
		["Lore"] = {tiebreaker="Lead"},
		["Dug"] = {tiebreaker="Lead"},
		["Set"] = {tiebreaker="Lead"},
		["Expiration"] = {tiebreaker="Lead"}
}

function ILLUnitList:New()
	local units = ZO_SortFilterList.New(self, ILLMainWindow)
	return units
end

function ILLUnitList:Initialize(control)
	ZO_SortFilterList.Initialize(self, control)

	self.sortHeaderGroup:SelectHeaderByKey("Lead")
	--ZO_SortHeader_OnMouseExit(ILLMainWindowHeadersName)

	self.masterList = {}
	ZO_ScrollList_AddDataType(self.list, 1, "ILLUnitRow", 30, function(control, data) self:SetupUnitRow(control, data) end)
	ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")
	self.sortFunction = function(listEntry1, listEntry2) return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, ILLUnitList.SORT_KEYS, self.currentSortOrder) end
	self:RefreshData()
end

function ILLUnitList:BuildMasterList()
	self.masterList = {}
	local units = ILL.units
	for k, v in pairs(units) do
		local data = v
		data["Aid"] = k
		table.insert(self.masterList, data)
	end
end



function ILLUnitList:FilterScrollList()

	local function passesMajor(data)
	

	
		if ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_ALL] then 
			return true
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_ACTIONABLE] then
			return  not (  ( not data.Repeatable and  data.Dug == 1 ) or ( data.SetId > 0 and data.Dug > ILL.setsminfound[data.SetId] ) )
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_CANSCRY] then
			return data.HaveLead
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_CANFIND] then
			if ( not data.HaveLead and  not ( not data.Repeatable and ( data.Dug == 1 ) ) and not ( data.SetId > 0 and data.Dug > ILL.setsminfound[data.SetId] ) ) then
				return true
			else
				return false
			end
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_MISSINGCODEX] then
			return ( data.Lore > 0 ) 
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_NEVERDUGOUT] then
			return ( data.Dug == 0 ) 
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_GROUPDUNGEONS] then
			return ( ILL.isGroupDungeon[data.Aid] ~= nil )
		elseif ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_LATESTDLC] then
			return ( data.Aid >= ILL.LATESTDLC_FIRSTANTIQUITY and not  ( not data.Repeatable and ( data.Dug == 1 ) ) )
		end
	end



	local function passesZone(data)
	

		local currentZoneIndex = GetCurrentMapZoneIndex()
		local currentZoneId = GetZoneId(currentZoneIndex)
		--artaeum partentzone is summerset...does not work for us
		while not (currentZoneId == ILL.ZONEID_ARTAEUM or GetParentZoneId(currentZoneId) == currentZoneId) do 
			currentZoneId = GetParentZoneId(currentZoneId)
		end
		-- Blackreach Caverns are not coded as Child Zones of Western Skyrim/The Reach. Do it ourselves.
		if currentZoneId == ILL.ZONEID_WSKYRIMCAVERN then currentZoneId = ILL.ZONEID_WSKYRIM end
		if currentZoneId == ILL.ZONEID_THEREACHCAVERN then currentZoneId = ILL.ZONEID_THEREACH end
	
		local currentZoneName = ZO_CachedStrFormat("<<C:1>>",GetZoneNameById(currentZoneId))
		if ILL.savedVars.DropdownChoice["Zone"] == ILL.DropdownData["ChoicesZone"][ILL_DROPDOWN_ZONE_ALL] then 
			return true
		elseif ILL.savedVars.DropdownChoice["Zone"] == ILL.DropdownData["ChoicesZone"][ILL_DROPDOWN_ZONE_CURRENT] then 
			if data.ZoneId < ILL.ZONEID_ALLZONES then 
				return ( data.ZoneId == currentZoneId )
			else
				if data.ZoneId == ILL.ZONEID_ALLZONES or data.ZoneId == ILL.ZONEID_UNKNOWN then 
					return true
				elseif data.ZoneId == ILL.ZONEID_BGS then 
					return false -- its from reward coffers
				elseif data.ZoneId == ILL.ZONEID_ARTAEUM_SUMMERSET then 
					return ( ( currentZoneId == ILL.ZONEID_ARTAEUM ) or ( currentZoneId == ILL.ZONEID_SUMMERSET ))
				elseif data.ZoneId == ILL.ZONEID_EASTMARCH_RIFT then 
					return ( ( currentZoneId == ILL.ZONEID_EASTMARCH) or ( currentZoneId == ILL.ZONEID_RIFT))
				elseif data.ZoneId == ILL.ZONEID_CYRODIIL_IMPERIALCITY then 
					return ( ( currentZoneId == ILL.ZONEID_CYRODIIL) or ( currentZoneId == ILL.ZONEID_IMPERIALCITY))
				elseif data.ZoneId == ILL.ZONEID_GALEN_HIGHISLE then 
					return ( ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_GALEN)) ) or ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_HIGHISLE)) ))
				end
			end
		elseif ILL.savedVars.DropdownChoice["Zone"] == ILL.DropdownData["ChoicesZone"][ILL_DROPDOWN_ZONE_NODLC] then 
			local test =  ILL.zoneType[data.ZoneId] 
			if test == nil or test == ILL.ZONETYPE_CHAPTER or data.ZoneId >= ILL.ZONEID_ALLZONES then
				return true
			else
				return false
			end
		elseif ILL.savedVars.DropdownChoice["Zone"] == ILL.DropdownData["ChoicesZone"][ILL_DROPDOWN_ZONE_LATESTDLC] then
			return ( data.Aid >= ILL.LATESTDLC_FIRSTANTIQUITY and not  ( not data.Repeatable and ( data.Dug == 1 ) ) )
		elseif ILL.savedVars.DropdownChoice["Zone"] == ILL.DropdownData["ChoicesZone"][ILL_DROPDOWN_ZONE_EVENT] then 
			local test =  ILL.zoneType[data.ZoneId] 
			if test == ILL.ZONETYPE_EVENT then
				return true
			else
				return false
			end
		else
			if data.ZoneId < ILL.ZONEID_ALLZONES then 
				return ( data.Zone == ILL.savedVars.DropdownChoice["Zone"] )
			else
				if data.ZoneId == ILL.ZONEID_ALLZONES or data.ZoneId == ILL.ZONEID_UNKNOWN then 
					return true
				elseif data.ZoneId == ILL.ZONEID_BGS then 
					return false -- its from reward coffers
				elseif data.ZoneId == ILL.ZONEID_ARTAEUM_SUMMERSET then 
					return ( ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_ARTAEUM )) ) or ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_SUMMERSET)) ))
				elseif data.ZoneId == ILL.ZONEID_EASTMARCH_RIFT then 
					return ( ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_EASTMARCH)) ) or ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_RIFT)) ))
				elseif data.ZoneId == ILL.ZONEID_CYRODIIL_IMPERIALCITY then 
					return ( ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_CYRODIIL)) ) or ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_IMPERIALCITY)) ))
				elseif data.ZoneId == ILL.ZONEID_GALEN_HIGHISLE then 
					return ( ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_GALEN)) ) or ( ILL.savedVars.DropdownChoice["Zone"] == ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(ILL.ZONEID_HIGHISLE)) ))
				end
			end
		end
	end
	

	local function passesSetType(data)
	
		if ILL.savedVars.DropdownChoice["SetType"] == ILL.DropdownData["ChoicesSetType"][ILL_DROPDOWN_SETTYPE_ALL] then 
			return true
		elseif ILL.savedVars.DropdownChoice["SetType"] == ILL.DropdownData["ChoicesSetType"][ILL_DROPDOWN_SETTYPE_MULTIPART] then  
			local test = ILL.isSet[data.Set]
			if test == nil then
				return true
			else 
				return false
			end
		elseif ILL.savedVars.DropdownChoice["SetType"] == ILL.DropdownData["ChoicesSetType"][ILL_DROPDOWN_SETTYPE_MYTHIC] 
		then  
			--local test = ILL.isMythic[data.SetId]
			if ILL.SETID_2_ITEMID[data.SetId] ~= nil then
				return true
			else 
				return false
			end
		elseif ILL.savedVars.DropdownChoice["SetType"] == ILL.DropdownData["ChoicesSetType"][ILL_DROPDOWN_SETTYPE_NOOBVIOUS] then
			if ILL.savedVars.DropdownChoice["Major"] == ILL.DropdownData["ChoicesMajor"][ILL_DROPDOWN_MAJOR_CANSCRY] then
				return not ( data.Diff == 1 and data.Set == ILL.TREASURE )
			else
				return not ( ( data.Set == ILL.MOTIF_CHAPTER ) or ( data.Diff < 4 and data.Set == ILL.TREASURE ) or ( data.Diff < 2 and data.Set == ILL.FURNISHING ) )
			end
		else 
			return ( data.Set == ILL.savedVars.DropdownChoice["SetType"] )
		end
	end



	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)
	for i = 1, #self.masterList do
		local data = self.masterList[i]
		if passesMajor(data) and passesZone(data) and passesSetType(data) then
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, data))
		end
	end
end

function ILLUnitList:SortScrollList()
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	table.sort(scrollData, self.sortFunction)
end




local function getColorCode(intvalue)

	if intvalue == 1 then 
		return ILL.GREEN_TEXT 
	elseif intvalue == 2 then
		return ILL.BLUE_TEXT
	elseif intvalue == 3 then
		return ILL.PURPLE_TEXT
	elseif intvalue == 4 then
		return ILL.GOLD_TEXT
	elseif intvalue == 5 then
		return ILL.ORANGE_TEXT	
	else
		return ILL.DEFAULT_TEXT
	end
end	

local function formatExpiration(leadtimeleft)

	local ltld = 33
	local ltlh = 0
	local ltlm = 0
	local ltls = 0
	ltld = math.floor(leadtimeleft/86400)
	ltlh = math.floor( (leadtimeleft - ltld*86400)/3600)
	ltlm = math.floor( (leadtimeleft - ltld*86400 - ltlh*3600)/60)
	return string.format("%dd %dh %dm", ltld, ltlh, ltlm)
end

local function colorizeExpiration(leadtimeleft)

	if leadtimeleft < 3600 then
		return ILL.RED_TEXT
	elseif leadtimeleft < 86400 then
		return ILL.ORANGE_TEXT
	elseif leadtimeleft < 604800 then
		return ILL.YELLOW_TEXT
	else
		return ILL.GREEN_TEXT
	end
end


function ILLUnitList:SetupUnitRow(control, data)

	control.data = data
	control.Lead = GetControl(control, "Lead")
	control.Zone = GetControl(control, "Zone")
	control.Location = GetControl(control, "Location")
	control.Lore = GetControl(control, "Lore")
	control.Dug = GetControl(control, "Dug")
	control.Set = GetControl(control, "Set")
	control.Expiration = GetControl(control, "Expiration")

	local formatbegin = ""
	local formatend = ""
	if ( not data.Repeatable and ( data.Dug == 1 ) ) or ( data.SetId > 0 and data.Dug > ILL.setsminfound[data.SetId] ) then
			formatbegin = "|l0:1:0:-25%:4:000000|l"
			formatend = "|l"
	end
	control.Lead:SetText(formatbegin .. data.Lead .. formatend)
	control.Zone:SetText(formatbegin .. data.Zone .. formatend)
	control.Location:SetText(formatbegin .. data.Location .. formatend)
	control.Lore:SetText(data.Lore)
	control.Dug:SetText(data.Dug)
	control.Set:SetText(formatbegin .. data.Set .. formatend)
	if data.HaveLead then	
		control.Expiration:SetText(formatExpiration(data.Expiration))
	else
		control.Expiration:SetText("")
	end

	control.Lead.normalColor = getColorCode(data.Diff)
	control.Zone.normalColor = getColorCode(data.Diff)
	control.Location.normalColor = getColorCode(data.Diff)
	control.Lore.normalColor = getColorCode(data.Diff)
	control.Dug.normalColor = getColorCode(data.Diff)
	control.Set.normalColor = getColorCode(data.SetQuality)
	control.Expiration.normalColor = colorizeExpiration(data.Expiration)
	
	ZO_SortFilterList.SetupRow(self, control, data)
end


function ILLUnitList:Refresh()
	self:RefreshData()
end


function ILL.HeaderMouseEnter(control, tooltipindex)
	
	if tooltipindex then
            InitializeTooltip(InformationTooltip, control, LEFT, -5, 0)
            SetTooltipText(InformationTooltip, ILL.SORTHEADER_TOOLTIP[tooltipindex])
    end
	
end

function ILL.HeaderMouseExit(control, tooltipindex)

	if tooltipindex then
        ClearTooltip(InformationTooltip)
    end
end

function ILL.RowMouseEnter(control)
	
	if control.data.Aid then
		InitializeTooltip(InformationTooltip, control, LEFT, -5, 0)
		local minX, minY, maxX, maxY = InformationTooltip:GetDimensionConstraints()
		ILL.OrigToolTipMaxX = maxX
		InformationTooltip:SetDimensionConstraints(minX, minY, 500, maxY)
		InformationTooltip:SetAntiquityLead(control.data.Aid)
		InformationTooltip:AddVerticalPadding(6)
		ZO_Tooltip_AddDivider(InformationTooltip)
		InformationTooltip:AddVerticalPadding(10)
		SetTooltipText(InformationTooltip,"|c42D6D1"..ILL.Locations[control.data.Aid][1].."|r")
		InformationTooltip:AddVerticalPadding(10)
		if ILL.Locations[control.data.Aid][2] == ILL.LOCDATA_TYPE_FIXLOCATION then
			InformationTooltip:AddLine(ILL.TOOLTIP_MAPPINS)
			InformationTooltip:AddVerticalPadding(10)
		end
		ZO_Tooltip_AddDivider(InformationTooltip)
		if(ILL.Locations[control.data.Aid][5] ~= nil) then
			InformationTooltip:AddLine(string.format("ID: %d", ILL.Locations[control.data.Aid][5]))
			ZO_Tooltip_AddDivider(InformationTooltip)
		end
		if ILL.SETID_2_ITEMID[control.data.SetId] ~= nil then
			local til = string.format("|H1:item:%d:%d:50:0:0:0:0:0:0:0:0:0:0:0:0:%d:%d:0:0:%d:0|h|h", ILL.SETID_2_ITEMID[control.data.SetId], ITEM_DISPLAY_QUALITY_ARTIFACT, ITEMSTYLE_NONE, 0, 10000)
			local numreq, bonus = GetItemLinkSetBonusInfo(til, false, 1)
			local armortype = GetItemLinkArmorType(til)
			InformationTooltip:AddVerticalPadding(10)
			if armortype == 0 then
				InformationTooltip:AddLine(zo_strformat("<<1>>", GetString("SI_EQUIPTYPE",GetItemLinkEquipType(til)) ))
			else 
				InformationTooltip:AddLine(zo_strformat("<<1>> <<2>>", GetString("SI_ARMORTYPE",armortype), GetString("SI_EQUIPTYPE",GetItemLinkEquipType(til)) ))
			end
			SetTooltipText(InformationTooltip, zo_strformat("<<1>>", bonus))
			InformationTooltip:AddVerticalPadding(6)
			ZO_Tooltip_AddDivider(InformationTooltip)
		end
		
	end	
	ILL.UnitList:Row_OnMouseEnter(control)
end

function ILL.RowMouseExit(control)

	if control.data.Aid then
		if ILL.OrigToolTipMaxX ~= nil then
			InformationTooltip:SetDimensionConstraints(minX, minY, ILL.OrigToolTipMaxX, maxY)
		end
		ClearTooltip(InformationTooltip)
	end
	ILL.UnitList:Row_OnMouseExit(control)
end


function ILL.AlertsMouseEnter(control)

	InitializeTooltip(InformationTooltip, control, LEFT, -5, 0)
	local minX, minY, maxX, maxY = InformationTooltip:GetDimensionConstraints()
	ILL.OrigToolTipMaxX = maxX
	InformationTooltip:SetDimensionConstraints(minX, minY, 450, maxY)
	
	for i = 1, #ILL.AlertsTooltipmsg do
		InformationTooltip:AddLine(ILL.AlertsTooltipmsg[i])
	end
	
--	InformationTooltip:AddLine(GetAntiquitySetId(776)) --mad god
--	InformationTooltip:AddLine("ZoneId: "..GetZoneId(GetUnitZoneIndex("player"))) --current player zone
--	InformationTooltip:AddLine("MarketId: "..GetZoneId(i))
	
--	InformationTooltip:AddLine("MarketId: "..ILL.debug_get_zone_by_name("night market"))

end

function ILL.debug_get_zone_by_name(search_name)
	temp_i = 0;
	for zoneId = 1, 3000 do
        local name = GetZoneNameById(zoneId)

        if name ~= "" then
            if string.find(string.lower(name), search_name) then
               return zoneId                
            end
        end
    end

end

function ILL.AlertsMouseExit(control)

	if ILL.OrigToolTipMaxX ~= nil then
		InformationTooltip:SetDimensionConstraints(minX, minY, ILL.OrigToolTipMaxX, maxY)
	end
	ClearTooltip(InformationTooltip)
end



-- Combobox stuff adapted with permission from manavortex's fabulous FurnitureCatalogue 
-- who adapted it from LAM which is under Open License

-- show/hide Tooltips for 
function ILL.DropdownShowTooltip(control, dropdownname, reAnchor)
  InitializeTooltip(InformationTooltip, control, BOTTOM, 0, 0, 0)
  InformationTooltip:SetHidden(false)
  InformationTooltip:ClearLines()
  InformationTooltip:AddLine(ILL.DropdownTooltips[dropdownname])
end

function ILL.DropdownHideTooltip(control)
  InformationTooltip:ClearLines()
  InformationTooltip:SetHidden(true)
end


local function createInventoryDropdown(dropdownName)
	local controlName     = string.format("%s%s", "ILL_Dropdown", dropdownName)
	local control       = _G[controlName]
	local dropdownData     = ILL.DropdownData
	local validChoices     = dropdownData[string.format("%s%s", "Choices", dropdownName)]
	local choicesTooltips   = dropdownData[string.format("%s%s", "Tooltips", dropdownName)]
	local comboBox


	control.comboBox = control.comboBox or ZO_ComboBox_ObjectFromContainer(control)
	comboBox = control.comboBox
	comboBox:SetHeight(800)
	local function HideTooltip(control)
	  ClearTooltip(InformationTooltip)
	end


	local function SetupTooltips(comboBox, choicesTooltips)

	  local function ShowTooltip(control)
		InitializeTooltip(InformationTooltip, control, TOPRIGHT, -10, 0, TOPLEFT)
		SetTooltipText(InformationTooltip, control.tooltip)
		InformationTooltipTopLevel:BringWindowToTop()
	  end


	  -- allow for tooltips on the drop down entries
	  local originalShow = comboBox.ShowDropdownInternal
	  comboBox.ShowDropdownInternal = function(comboBox)
		originalShow(comboBox)
		local entries = ZO_Menu.items
		for i = 1, #entries do

		  local entry = entries[i]
		  local control = entries[i].item
		  control.tooltip = choicesTooltips[i]
		  if control.tooltip then
			entry.onMouseEnter = control:GetHandler("OnMouseEnter")
			entry.onMouseExit = control:GetHandler("OnMouseExit")
			ZO_PreHookHandler(control, "OnMouseEnter", ShowTooltip)
			ZO_PreHookHandler(control, "OnMouseExit", HideTooltip)
		  end

		end
	  end

	  local originalHide = comboBox.HideDropdownInternal
	  comboBox.HideDropdownInternal = function(self)
		local entries = ZO_Menu.items
		for i = 1, #entries do
		  local entry = entries[i]
		  local control = entries[i].item
		  control:SetHandler("OnMouseEnter", entry.onMouseEnter)
		  control:SetHandler("OnMouseExit", entry.onMouseExit)
		  control.tooltip = nil
		end
		HideTooltip(self)
		originalHide(self)
	  end
	end

	function OnItemSelect(control, choiceText, somethingElse)
	  local dropdownName = tostring(control.m_name):gsub("ILL_Dropdown", "")
	  ILL.savedVars.DropdownChoice[dropdownName] = choiceText
	  HideTooltip(control)
	  PlaySound(SOUNDS.POSITIVE_CLICK)
	  ILL.UnitList:RefreshData()
	end

	comboBox:SetSortsItems(false)
	local originalShow = comboBox.ShowDropdownInternal

	local choice = validChoices[1]
	if ILL.savedVars.DropdownChoice[dropdownName]  ~= nil then 
		choice = ILL.savedVars.DropdownChoice[dropdownName] 
	else
		ILL.savedVars.DropdownChoice[dropdownName] = choice
	end
	local foundStoredSelected = false
	for i = 1, #validChoices do
		entry = comboBox:CreateItemEntry(validChoices[i], OnItemSelect)
		comboBox:AddItem(entry)
		if validChoices[i] == choice then
			foundStoredSelected = true
			comboBox:SetSelectedItem(validChoices[i])
		end
	end
	if not foundStoredSelected then
		comboBox:SetSelectedItem(validChoices[1])
		ILL.savedVars.DropdownChoice[dropdownName] = validChoices[1]
	end
	SetupTooltips(comboBox, dropdownData["Tooltips"..dropdownName])

	return control
	end



function ILL.setAlerts(d7, d1, h1, totalcm, totalmap, totalea, totalevent)

	local function getAlertsColor(d7, d1, h1)
		if d7 > 0 then return ILL.YELLOW_TEXT:ToHex() end
		if d1 > 0 then return ILL.ORANGE_TEXT:ToHex() end
		if h1 > 0 then return ILL.RED_TEXT:ToHex() end
		return ILL.GREEN_TEXT:ToHex()
	end

	ILL.AlertsTooltipmsg = {}
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_1HOUR, h1))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_1DAY, d1))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_7DAYS, d7))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_TOTALCM, totalcm))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_TOTALMAP, totalmap))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_TOTALEA, totalea))
	table.insert(ILL.AlertsTooltipmsg, string.format(ILL.TOOLTIP_ALERTS_TOTALEVENT, totalevent))
	
	local color = getAlertsColor(d7, d1, h1)
	ILLMainWindowTitleAlerts:SetText(string.format(ILL.LABEL_ALERTS, color, d7, d1, h1, totalcm, 0))
	
end



function ILL.toggleILL(extra)

	if ILLMainWindow:IsHidden() then
		ILL.units = {}
		ILL.setsminfound = {}
		local i = GetNextAntiquityId()
		local foundalreadytable = {}
		local zonestable = {}
		local settypetable = {}
		local d7, d1, h1 = 0, 0, 0
		local totalcm, totalmap, totalea, totalevent = 0, 0, 0, 0
		local test =""
		while i  do
			local havelead = DoesAntiquityHaveLead(i)
			local azoneid = GetAntiquityZoneId(i)
			local azone = ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(azoneid))
			local aname = ZO_CachedStrFormat("<<C:1>>",GetAntiquityName(i))
			local aquality = GetAntiquityQuality(i)
			local setid = GetAntiquitySetId(i)
			local setname = ZO_CachedStrFormat("<<C:1>>", GetAntiquitySetName(setid))
			local setquality = GetAntiquitySetQuality(setid)
			local diff = GetAntiquityDifficulty(i)
			local numrecovered = GetNumAntiquitiesRecovered(i)
			local repeatable = IsAntiquityRepeatable(i)
			if setid > 0 then 
				if ILL.setsminfound[setid] == nil or ( ILL.setsminfound[setid] > numrecovered and not havelead ) then 
					ILL.setsminfound[setid] = numrecovered 
				end
			end
			if setid == 22 then repeatable = false end
			if i == 310 or ( i > 498 and i < 509 ) or (i > 614 and i < 625) then repeatable = false end -- ZOS returns true for this Lead even though it is not repeatable...overwrite
			if i == 248 and numrecovered == 1 then havelead = false end -- ZOS didnt clean up character data when fixing multi-purple Eyevea Bug
			local loreleft =  GetNumAntiquityLoreEntries(i) - GetNumAntiquityLoreEntriesAcquired(i)
			totalcm = totalcm + loreleft
			if ILL.Locations[i] == nil then
				ILL.Locations[i] = { ILL.UNKNOWN, ILL.UNKNOWN, ILL.UNKNOWN, "FALSE",}
			end
			if ILL.Locations[i][1]==ILL.LOCDATA_LONG_TREASUREMAP then totalmap = totalmap + loreleft end
			if ILL.Locations[i][1]==ILL.ENDLESSARCHIVE then totalea = totalea + loreleft end
			if ILL.Locations[i][2]==ILL.LOCDATA_TYPE_EVENT_ZONE then totalevent = totalevent + loreleft end
			local leadtimeleft = GetAntiquityLeadTimeRemainingSeconds(i)
			-- to avoid high skill level boosting difficulty messing up our coloring
			-- some gold rarety leads are difficulty 5, here we need to keep difficulty
			if diff < 5 and ( i < 401 or i > 415 ) then 
				diff = aquality
			end
			if havelead then -- some expiration timers come back 0 for a couple of days set to 33
				if ( leadtimeleft == 0 ) then leadtimeleft = 2851200 end
				if leadtimeleft < 3600 then h1 = h1 + 1 
				elseif leadtimeleft < 86400 then d1 = d1 + 1
				elseif leadtimeleft < 604800 then d7 = d7 + 1
				end
			else -- Some Find Locations are different From Scry Location, switch scry for find location
				if ILL.FindScryDifferentZones[i] ~= nil then
					local findzoneid = ILL.FindScryDifferentZones[i]
					local findzonename = ""
					if findzoneid < ILL.ZONEID_ALLZONES then 
						findzonename = ZO_CachedStrFormat("<<C:1>>", GetZoneNameById(findzoneid))
					else
					    findzonename = ILL.ZONENAME_SPECIAL[findzoneid]
					end
					azone = findzonename
					azoneid = findzoneid
				end
			end
			local rewardid = GetAntiquityRewardId(i)
			local rewardtype = GetCollectibleCategoryType(GetCollectibleRewardCollectibleId(rewardid))
			if setname == "" and rewardid > 0 then
				setquality = GetAntiquityQuality(i)
				setname = REWARDS_MANAGER:GetRewardContextualTypeString(rewardid)
				if setname == "Motif Chapter" then setquality = 3 end
			end
--			if i >= ILL.LATESTDLC_FIRSTANTIQUITY then -- debug out for new antiquities on pts--
--				d(string.format("%i, %s, %s, %i, %s", i, aname, azone, setid, setname))
--			end
			if  azone ~= "" then 
			local location = ILL.Locations[i][3]
				ILL.units[i] = {Lead=aname, Zone=azone, ZoneId=azoneid, Location=location, Diff=diff, Lore=loreleft, Dug=numrecovered, Set=setname, SetId=setid, Expiration=leadtimeleft, SetQuality=setquality, HaveLead=havelead, Repeatable=repeatable}
			end
			-- update our zone and set/type collector tables. first time only.
			if not ILL.alreadyrun then 
				if foundalreadytable[azone] == nil and azoneid < ILL.ZONEID_ALLZONES then --dont want fake zones in dropdown
					foundalreadytable[azone] = azone 
					table.insert(zonestable, azone)
				end
				if foundalreadytable[setname] == nil then 
					foundalreadytable[setname] = setname 
					table.insert(settypetable, setname)
				end
			end
			i = GetNextAntiquityId(i)
		end
		-- Populate our Filter Combobox datastructure with our collector tables
		if not ILL.alreadyrun then 
			ILL.alreadyrun = true
	
			local ttmsg
			table.sort(zonestable)
			for a,zone in pairs(zonestable) do
				table.insert(ILL.DropdownData["ChoicesZone"],zone)
				--ttmsg = string.format(ILL.DropdownData["TooltipsZoneGenerated"], zone)
				--table.insert(ILL.DropdownData["TooltipsZone"], ttmsg)
			end
			table.sort(settypetable)
			for a,settype in pairs(settypetable) do
				table.insert(ILL.DropdownData["ChoicesSetType"], settype)
				--ttmsg = string.format(ILL.DropdownData["TooltipsSetTypeGenerated"], settype)
				--table.insert(ILL.DropdownData["TooltipsSetType"], ttmsg)
			end
		end
		ILL.setAlerts(d7,d1,h1, totalcm, totalmap, totalea, totalevent)
		ILL.UnitList:RefreshData()
		
		ILLMainWindowFreerunnerFreerunner_alert:SetText(ILL.FREERUNNER_INFO)
	end	
	SCENE_MANAGER:ToggleTopLevel(ILLMainWindow)
end 

function ILL.onLoad(eventCode, name)
	if name ~= Addon.Name then return end
	ILL.savedVars = ZO_SavedVars:NewAccountWide("ILeadListVars", 1, nil, nil)
	if ILL.savedVars.DropdownChoice == nil then 
		ILL.savedVars.DropdownChoice = {} 
		ILL.savedVars.DropdownChoice["Major"] = ILL.DropdownData["ChoicesMajor"][1]
		ILL.savedVars.DropdownChoice["Zone"] = ILL.DropdownData["ChoicesZone"][1]
		ILL.savedVars.DropdownChoice["SetType"] = ILL.DropdownData["ChoicesSetType"][1]
	end

	ILL.UnitList = ILLUnitList:New()

	ILL.toggleILL()
	ILLMainWindow:SetHidden(true)
	
	createInventoryDropdown("Major")
	createInventoryDropdown("Zone")
	createInventoryDropdown("SetType")
	SCENE_MANAGER:RegisterTopLevel(ILLMainWindow, false)
	EVENT_MANAGER:UnregisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED)
end

SLASH_COMMANDS["/leadlist"] = ILL.toggleILL
SLASH_COMMANDS["/leads"] = ILL.toggleILL
ZO_CreateStringId("SI_BINDING_NAME_TOGGLE_LEAD_LIST", ILL.KEYBINDINGTEXT)
EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED, ILL.onLoad)


