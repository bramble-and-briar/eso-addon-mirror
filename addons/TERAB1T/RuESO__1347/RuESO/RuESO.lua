local RuESO = {}
RuESO.Flags = { "en", "ru", "de", "fr", "es" }
RuESO.Version = "v48.0"
RuESO.API = 101051
RuESO.Name = "RuESO"
RuESO.DropdownParameters = {
	["ru"] = "Только русский",
	["ruen"] = "Русский+английский",
	["enru"] = "Английский+русский",
	["en"] = "Только английский",
}
RuESO.StringsBackup = {
	["SI_ABILITY_NAME_AND_RANK"] = GetString(SI_ABILITY_NAME_AND_RANK),
	["SI_ABILITY_TOOLTIP_NAME"] = GetString(SI_ABILITY_TOOLTIP_NAME),
	["SI_ITEM_FORMAT_STR_ENCHANT_HEADER_NAMED"] = GetString(SI_ITEM_FORMAT_STR_ENCHANT_HEADER_NAMED),
	["SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER"] = GetString(SI_ITEM_FORMAT_STR_ITEM_TRAIT_HEADER),
	["SI_ITEM_FORMAT_STR_ITEM_TRAIT_WITH_ICON_HEADER"] = GetString(SI_ITEM_FORMAT_STR_ITEM_TRAIT_WITH_ICON_HEADER),
	["SI_ITEM_FORMAT_STR_SET_NAME"] = GetString(SI_ITEM_FORMAT_STR_SET_NAME),
	["SI_TOOLTIP_ITEM_NAME"] = GetString(SI_TOOLTIP_ITEM_NAME),
	["SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT"] = GetString(SI_ITEM_FORMAT_STR_SET_NAME_NO_COUNT),
}

RuESO.Defaults = {
	Anchor = { BOTTOMRIGHT, BOTTOMRIGHT, 0, 7 },
	-- Misc
	ShowNPC = "ru",
	ShowLocations = "ru",
	ShowCraft = "ru",
	-- Abilities
	ShowAbilitiesMenu = "ru",
	ShowAbilitiesTooltip = "ru",
	-- Champion
	ShowChampionTooltip = "ru",
	-- Items
	ShowItemsNamesTooltip = "ru",
	ShowItemsEnchantsTooltip = "ru",
	ShowItemsTraitsTooltip = "ru",
	ShowItemsSetsTooltip = "ru",
	IsUpdateNeeded = true,
	-- Collections
	EnglishSearch = true,
	ShowCollectionsSetsMenu = "ru",
	--ShowTributeCards = "ru",
	Data = {
		ApiVersion = 0,
		AddonVersion = "",
		Abilities = {},
		Items = {},
		Sets = {},
		SetsNames = {},
		Traits = {},
		Potions = {},
		Locations = {},
		CraftAbilities = {},
		Parts = {},
		Prefixes = {},
		Affixes = {},
		EnchantPrefixes = {},
		--TributeCards = {},
	}
}
RuESO.DefaultsCharacter = {
	IsFirstLaunch = true
}
RuESO.Settings = RuESO.Defaults
RuESO.SettingsCharacter = RuESO.DefaultsCharacter

function RuESO_Change(lang)
	if GetCVar("language.2") ~= lang then
		SetCVar("language.2", lang)
	else
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "Вы уже переключены на этот язык.")
	end
end

function RuESO:RefreshUI()
	local flagControl
	local count = 0
	local flagTexture
	for _, flagCode in pairs(self.Flags) do
		flagTexture = "RuESO/textures/"..flagCode..".dds"
		flagControl = GetControl("RuESO_FlagControl_"..tostring(flagCode))
		if flagControl == nil then
			flagControl = CreateControlFromVirtual("RuESO_FlagControl_", RuESOUI, "RuESO_FlagControl", tostring(flagCode))
			GetControl("RuESO_FlagControl_"..flagCode.."Texture"):SetTexture(flagTexture)
			if self:GetLanguage() ~= flagCode then
				flagControl:SetAlpha(0.3)
				if flagControl:GetHandler("OnMouseDown") == nil then flagControl:SetHandler("OnMouseDown", function() RuESO_Change(flagCode) end) end
			end
		end
		flagControl:ClearAnchors()
		flagControl:SetAnchor(LEFT, RuESOUI, LEFT, 14 +count*34, 0)
		count = count + 1
	end
	RuESOUI:SetDimensions(25 +count*34, 50)
	RuESOUI:SetMouseEnabled(true)
end

function RuESO:GetLanguage()
	local lang = GetCVar("language.2")
	
	if lang == "ru" or lang == "de" or lang == "fr" or lang == "es" then return lang end
	return "en"
end

function RuESO:StartupMessage()
	if self.Settings.IsUpdateNeeded and self:IsDBOld() then
		self:ShowMsgBox("Требуется обновление базы", "\n\n\n|ac|t256:256:RuESO/Textures/logo.dds|t\n\n\n\n\n|alБаза оригинальных названий устарела. Обновление займет не больше нескольких минут, и игра может ненадолго зависать в процессе. Если вы не хотите обновлять базу сейчас, в дальнейшем это можно будет сделать в меню:\nESC -> Настройки -> Дополнения (или Модификации) -> RuESO\n\nВ том же разделе вы сможете изменить настройки. Сейчас модификация позволяет отображать оригинальные названия локаций, имена персонажей, информацию о предметах (названия, зачарования, особенности и наборы) и названия способностей.", 1)
	end
	
	if self:IsDBOld() and not self.Settings.IsUpdateNeeded then
		d("База RuESO устарела. Ее можно обновить в настройках модификации: ESC -> Настройки -> Дополнения (или Модификации) -> RuESO")
	end
	
	self:Check()
	
	EVENT_MANAGER:UnregisterForEvent("RuESO_StartupMessage", EVENT_PLAYER_ACTIVATED)
end

function RuESO:MapNameStyle()		
	if self.Settings.ShowLocations == "ruen" or self.Settings.ShowLocations == "enru" then
		ZO_WorldMapCornerTitle:SetFont("ZoFontWinH3")
	else
		ZO_WorldMapCornerTitle:SetFont("ZoFontWinH1")
	end
	
	local scrollData = ZO_ScrollList_GetDataList(ZO_WorldMapLocationsList)
    ZO_ClearNumericallyIndexedTable(scrollData)
	WORLD_MAP_LOCATIONS_DATA:RefreshLocationList()
	WORLD_MAP_LOCATIONS:BuildLocationList()
end

function RuESO:OnInit(eventCode, addOnName)	
	if zo_strlower(addOnName) ~= zo_strlower(self.Name) then return end
	EVENT_MANAGER:UnregisterForEvent("RuESO_OnAddOnLoaded", EVENT_ADD_ON_LOADED)
	
	self.Settings = ZO_SavedVars:NewAccountWide("RuEsoVariables", 1, nil, self.Defaults)
	self.SettingsCharacter = ZO_SavedVars:New("RuEsoVariables", 1, nil, self.DefaultsCharacter)
	
	if self.SettingsCharacter.IsFirstLaunch == true then
		SetSetting(SETTING_TYPE_SUBTITLES, SUBTITLE_SETTING_ENABLED_FOR_NPCS, "true")
		SetSetting(SETTING_TYPE_SUBTITLES, SUBTITLE_SETTING_ENABLED_FOR_VIDEOS, "true")
		self.SettingsCharacter.IsFirstLaunch = false
	end
	
	for _, flagCode in pairs(self.Flags) do
		ZO_CreateStringId("SI_BINDING_NAME_"..string.upper(flagCode), string.upper(flagCode))
	end

	self:RefreshUI()
	
	RuESOUI:ClearAnchors()
	RuESOUI:SetAnchor(self.Settings.Anchor[1], GuiRoot, self.Settings.Anchor[2], self.Settings.Anchor[3], self.Settings.Anchor[4])
	
	self.LAM = RUESO_SETTINGS:New(self)
	
	ZO_CreateStringId("SI_BINDING_NAME_RUESO_EN", "Английский язык")
	ZO_CreateStringId("SI_BINDING_NAME_RUESO_RU", "Русский язык")
	
	if self:GetLanguage() == "ru" then
		RuESO_init()
	end
	
	function ZO_GameMenu_OnShow(control)
		if control.OnShow then
			control.OnShow(control.gameMenu)
			RuESOUI:SetHidden(hidden)
		end
	end
	
	function ZO_GameMenu_OnHide(control)
		if control.OnHide then
			control.OnHide(control.gameMenu)
			RuESOUI:SetHidden(not hidden)
		end
	end
end

function RuESO:IsDBOld()
	local rsv = self.Settings.Data
	if not rsv.ApiVersion or not rsv.AddonVersion or (rsv.ApiVersion ~= GetAPIVersion()) or (rsv.AddonVersion ~= self.Version) then
		return true
	else
		return false
	end
end

function RuESO:CloseMsgBox()
	ZO_Dialogs_ReleaseDialog("RuESODialog", false)
end

function RuESO:ShowMsgBox(title, msg, typ)

	local callback = {}

	callback = {
		[1] = 
		{
			keybind = "DIALOG_PRIMARY",
			text = "Обновить базу",
			callback =
				function ()
					RuESO_Dump()
				end,
            clickSound = SOUNDS.DIALOG_ACCEPT,
		},
		[2] =
		{
			keybind = "DIALOG_NEGATIVE",
            text = "Отмена", 
			callback =
				function ()
					self.Settings.IsUpdateNeeded = false
				end,
            clickSound = SOUNDS.DIALOG_DECLINE,
		},
	}
	
	local confirmDialog = 
	{
		canQueue = true,
		onlyQueueOnce = true,
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
		title = { text = title },
		mainText = { text = msg },
		buttons = callback
	}
	
	ZO_Dialogs_RegisterCustomDialog("RuESODialog", confirmDialog)
	self:CloseMsgBox()
	
	--if IsInGamepadPreferredMode() then
	--	zo_callLater(function()
	--		ZO_Dialogs_ShowGamepadDialog("RuESODialog")
	--	end, 500)
	--else
		ZO_Dialogs_ShowDialog("RuESODialog")
	--end
end

function RuESO_init()
	
	if not RuESO:IsDBOld() then
		
		if RuESO.Settings.ShowLocations ~= "ru" and RuESO_doubleNamesLocations then
			LFGDoubleNames(RuESO)
			RuESO_doubleNamesLocations(RuESO)
		end
		
		if RuESO.Settings.ShowNPC ~= "ru" and RuESO_doubleNamesNPC then
			RuESO_doubleNamesNPC(RuESO)
		end
		
		if RuESO.Settings.ShowCraft ~= "ru" and RuESO_doubleNamesBoth then
			RuESO_doubleNamesBoth(RuESO)
		end
		
		if (RuESO.Settings.ShowAbilitiesMenu ~= "ru" or RuESO.Settings.ShowAbilitiesTooltip ~= "ru") and RuESO_doubleNamesAbilities then
			RuESO_doubleNamesAbilities(RuESO)
		end
		
		if (RuESO.Settings.ShowChampionMenu ~= "ru" or RuESO.Settings.ShowChampionTooltip ~= "ru") and RuESO_doubleNamesChampion then
			RuESO_doubleNamesChampion(RuESO)
		end
		
		if (RuESO.Settings.ShowItemsNamesTooltip ~= "ru" or RuESO.Settings.ShowItemsEnchantsTooltip ~= "ru" or RuESO.Settings.ShowItemsTraitsTooltip ~= "ru" or RuESO.Settings.ShowItemsSetsTooltip ~= "ru") and RuESO_doubleNamesItems then
			RuESO_doubleNamesItems(RuESO)
		end
		
		if (RuESO.Settings.EnglishSearch or RuESO.Settings.ShowCollectionsSetsMenu ~= "ru") and RuESO_doubleNamesCollections then
			RuESO_doubleNamesCollections(RuESO)
			ITEM_SET_COLLECTIONS_DATA_MANAGER:SortTopLevelCategories()
			ITEM_SET_COLLECTIONS_DATA_MANAGER:FireCallbacks("CollectionsUpdated")
		end
	end
end

function RuESO_SaveAnchor()
	local isValidAnchor, point, relativeTo, relativePoint, offsetX, offsetY = RuESOUI:GetAnchor()
	if isValidAnchor then
		RuESO.Settings.Anchor = { point, relativePoint, offsetX, offsetY }
	end
end

function RuESO:MagicReplace(str, what, with)
    what = zo_strgsub(what, "[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    with = zo_strgsub(with, "[%%]", "%%%%")
    return zo_strgsub(str, what, with)
end

function RuESO:DumpRu()
	local rsv = RuESO.Settings.Data
	
	for i = 1, 300000 do

		local hasSet, setName = GetItemLinkSetInfo(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i)) 
		
		if hasSet then
			rsv.SetsNames[ZO_CachedStrFormat("<<z:1>>", setName)] = i
		end
	end
	
	for i = 1, #ruesoLinks do
		rsv.Potions[zo_strlower(GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", ruesoLinks[i])))] = ruesoLinks[i]
	end
	
	for i = 1, #ruesoParts do
		rsv.Parts[ZO_CachedStrFormat("<<z:1>>", GetItemLinkName(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", ruesoParts[i])))] = ruesoParts[i]
	end
	
	for i = 1, #ruesoEnchantPrefixes do
		rsv.EnchantPrefixes[RuESO:MagicReplace(zo_strlower(GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", ruesoEnchantPrefixes[i]))), " " .. GetItemLinkName("|H1:item:5364:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"), "")] = ruesoEnchantPrefixes[i]
	end
	
	for i = 1, #ruesoPrefixes do
		local str = RuESO:MagicReplace(ZO_CachedStrFormat("<<z:1>>", GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", ruesoPrefixes[i]))), " " .. ZO_CachedStrFormat("<<z:1>>", GetItemLinkName("|H1:item:" .. string.match(ruesoPrefixes[i], "^(%d+):") .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")), "")
		rsv.Prefixes[str:sub(1, #str - 4)] = ruesoPrefixes[i]
	end
	
	for i = 1, #ruesoAffixes do
		rsv.Affixes[RuESO:MagicReplace(ZO_CachedStrFormat("<<z:1>>", GetItemLinkName(string.format("|H1:item:43533:0:0:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", ruesoAffixes[i]))), ZO_CachedStrFormat("<<z:1>>", GetItemLinkName("|H1:item:43533:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")) .. " ", "")] = ruesoAffixes[i]
	end
	
	-- Locations
	
	local backupLocations = RuESO.Settings.ShowLocations
	RuESO.Settings.ShowLocations = "ru"
	
	local zonesCount = GetNumZones()
	for i = 1, zonesCount do
		local locationName = ZO_CachedStrFormat("<<z:1>>", GetZoneNameByIndex(i))
		if locationName then
			rsv.Locations[locationName] = string.format("zone:%d:0", i)
		end
		
		local POIsCount = GetNumPOIs(i)
		for j = 1, POIsCount do
			local locationName = ZO_CachedStrFormat("<<z:1>>", GetPOIInfo(i, j))
			if locationName then
				rsv.Locations[locationName] = string.format("poi:%d:%d", i, j)
			end
		end
	end
	
	local fastTravelNodesCount = GetNumFastTravelNodes()
	for i = 1, fastTravelNodesCount do
		local _, locationName = GetFastTravelNodeInfo(i)
		if locationName then
			rsv.Locations[ZO_CachedStrFormat("<<z:1>>", locationName)] = string.format("ft:%d:0", i)
		end
	end
	
	for i = 1, 1000 do
		local locationName = ZO_CachedStrFormat("<<z:1>>", GetKeepName(i))
		if locationName then
			rsv.Locations[locationName] = string.format("keep:%d:0", i)
		end
	end
	
	RuESO.Settings.ShowLocations = backupLocations
	
	RuESO.Settings["enDump"] = true
	SetCVar("language.2", "en")
end

function RuESO:DumpEn()
	local rsv = RuESO.Settings.Data
	
	-- Items
	
	for i = 1, 300000 do
		local itemName = GetItemLinkName(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i))
		
		if itemName and itemName ~= "" and not string.match(itemName, "_") then
			rsv.Items[i] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, itemName)
		end

		local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", i))
		
		if hasSet then
			rsv.Sets[setId] = setName
		end

		--[[local _, enchantHeader = GetItemLinkEnchantInfo("|H1:item:" .. i .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
		local enchantId = GetItemLinkFinalEnchantId("|H1:item:" .. i .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")

		if enchantHeader and enchantHeader ~= "" and enchantHeader ~= "Enchantment" then
			rsv.Enchants[enchantId] = RuESO:MagicReplace(enchantHeader, " Enchantment", "")
		end]]
	end
	
	-- Tribute Cards
	
	--[[for i = 1, 1000 do
		local cardName = GetTributeCardName(i)
		
		if cardName and cardName ~= "" then
			rsv.TributeCards[i] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, cardName)
		end
	end]]
	
	-- Set Names
	
	for index,value in pairs(rsv.SetsNames) do
		local hasSet, setName = GetItemLinkSetInfo(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value))
		rsv.SetsNames[index] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, setName)
	end
	
	-- Alchemy
	
	for index,value in pairs(rsv.Potions) do
		rsv.Potions[index] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value)))
	end
	
	-- Item Parts
	
	for index,value in pairs(rsv.Parts) do
		rsv.Parts[index] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value)))
	end
	
	-- Enchantment Prefixes
	
	for index,value in pairs(rsv.EnchantPrefixes) do
		rsv.EnchantPrefixes[index] = ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, RuESO:MagicReplace(GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value)), " " .. GetItemLinkName("|H1:item:5364:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"), ""))
	end
	
	-- Item Prefixes
	
	for index,value in pairs(rsv.Prefixes) do
		rsv.Prefixes[index] = RuESO:MagicReplace(ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(string.format("|H1:item:%s:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value))), " " .. ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName("|H1:item:" .. string.match(value, "^(%d+):") .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")), "")
	end
	
	-- Item Affixes
	
	for index,value in pairs(rsv.Affixes) do
		rsv.Affixes[index] = RuESO:MagicReplace(ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(string.format("|H1:item:43533:0:0:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", value))), ZO_CachedStrFormat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName("|H1:item:43533:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")) .. " ", "")
	end
	
	-- Locations
	
	for index,value in pairs(rsv.Locations) do
		local locType, locId, locSubId = string.match(value, "^(.*):(%d+):(%d+)$")
		
		if locType and locId and locSubId then
			if locType == "zone" then
				rsv.Locations[index] = ZO_CachedStrFormat(SI_ZONE_NAME, GetZoneNameByIndex(locId))
			elseif locType == "poi" then
				rsv.Locations[index] = ZO_CachedStrFormat(SI_ZONE_NAME, GetPOIInfo(locId, locSubId))
			elseif locType == "keep" then
				rsv.Locations[index] = ZO_CachedStrFormat(SI_ZONE_NAME, GetKeepName(locId))
			elseif locType == "ft" then
				local _, locationName = GetFastTravelNodeInfo(locId)
				rsv.Locations[index] = ZO_CachedStrFormat(SI_ZONE_NAME, locationName)
			end
		end
	end
	
	-- Traits
	
	for i = 1, 100 do
		local traitName = GetString("SI_ITEMTRAITTYPE", i)
		
		if traitName and traitName ~= "" then
			rsv.Traits[i] = traitName
		end
	end
	
	-- Abilities
	
	local numSkillTypes = GetNumSkillTypes()
	
	for i = 1, numSkillTypes do
		local numSkillLines = GetNumSkillLines(i)
		
		for j = 1, numSkillLines do
			local numSkillAbilities = GetNumSkillAbilities(i, j)
			
			for k = 1, numSkillAbilities do
				
				local _, _, _, passive = GetSkillAbilityInfo(i, j, k)
				
				if passive then
					for l = 1,GetNumPassiveSkillRanks(i, j, k) do
						local currentMorphId = GetSpecificSkillAbilityInfo(i, j, k, 0, l)
						rsv.Abilities[currentMorphId] = GetAbilityName(currentMorphId)
					end
				else
					local currentMorphId = GetSpecificSkillAbilityInfo(i, j, k, 0, 1)
					rsv.Abilities[currentMorphId] = GetAbilityName(currentMorphId)
					
					local currentMorphId = GetSpecificSkillAbilityInfo(i, j, k, 1, 1)
					rsv.Abilities[currentMorphId] = GetAbilityName(currentMorphId)
					
					local currentMorphId = GetSpecificSkillAbilityInfo(i, j, k, 2, 1)
					rsv.Abilities[currentMorphId] = GetAbilityName(currentMorphId)
				end
			end
		end
	end
	
	for key,value in pairs(ruesoCompanionAbilities) do
		rsv.Abilities[key] = GetAbilityName(key)
	end

	for i = 1, GetNumChampionDisciplines() do
		for j = 1, GetNumChampionDisciplineSkills(i) do
			rsv.Abilities[GetChampionAbilityId(GetChampionSkillId(i, j))] = GetChampionSkillName(GetChampionSkillId(i, j))
		end
	end
	
	RuESO.Settings["enDump"] = nil
	RuESO.Settings["success"] = true
	
	rsv.ApiVersion = GetAPIVersion()
	rsv.AddonVersion = RuESO.Version
	RuESO.Settings.IsUpdateNeeded = true,
	
	SetCVar("language.2", "ru")
end

function RuESO:Check()

	local rsv = RuESO.Settings

	if GetCVar("language.2") == "en" and rsv["enDump"] ~= nil then
		RuESO:DumpEn()
	end
	
	if GetCVar("language.2") == "ru" and rsv["ruDump"] ~= nil then
		rsv["ruDump"] = nil
		RuESO:DumpRu()
	end
	
	if rsv["success"] ~= nil then
		rsv["success"] = nil
	end
end

function RuESO:IsAddonRunning(addonName)
    local manager = GetAddOnManager()
    for i = 1, manager:GetNumAddOns() do
        local name, _, _, _, _, state = manager:GetAddOnInfo(i)
        if name == addonName and state == ADDON_STATE_ENABLED then
            return true
        end
    end
    return false
end

function RuESO_Dump()
	local rsd = RuESO.Settings.Data
	rsd.Sets = {}
	rsd.SetsNames = {}
	rsd.Potions = {}
	rsd.Traits = {}
	rsd.Abilities = {}
	rsd.Items = {}
	rsd.Parts = {}
	rsd.Prefixes = {}
	rsd.Affixes = {}
	rsd.EnchantPrefixes = {}
	rsd.Locations = RuESO_getLocations()
	rsd.CraftAbilities = RuESO_getCraftAbilities()
	
	if GetCVar("language.2") == "ru" then
		RuESO:DumpRu()
	else
		RuESO.Settings["ruDump"] = true
		SetCVar("language.2", "ru")
	end
end

--[[ function RuESO_Dump_Dev()
	local rsd = RuESO.Settings.Data
	
	if not rsd.Companions then
		rsd.Companions = {}
	end
	
	local numSkillTypes = GetNumSkillTypes()
	
	for i = 1, numSkillTypes do
		local numSkillLines = GetNumCompanionSkillLines(i)
		
		for j = 1, numSkillLines do
			local skillLineId = GetCompanionSkillLineId(i, j)
			local numSkillAbilities = GetNumAbilitiesInCompanionSkillLine(skillLineId)
			
			for k = 1, numSkillAbilities do
				local currentAbilityId = GetCompanionAbilityId(skillLineId, k)
				rsd.Companions[currentAbilityId] = GetAbilityName(currentAbilityId)
			end
		end
	end
end ]]

EVENT_MANAGER:RegisterForEvent("RuESO_OnAddOnLoaded", EVENT_ADD_ON_LOADED, function(_event, _name) RuESO:OnInit(_event, _name) end)
EVENT_MANAGER:RegisterForEvent("RuESO_StartupMessage", EVENT_PLAYER_ACTIVATED, function(...) RuESO:StartupMessage() end)
