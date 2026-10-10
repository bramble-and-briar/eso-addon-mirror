local LCCC = LibCodesCommonCode
local LEJ = LibExtendedJournal

LEJ.Used = true

LootLog = {
	name = "LootLog",

	title = GetString(SI_LOOTLOG_TITLE),
	url = "https://www.esoui.com/downloads/info1455.html",

	-- Default settings
	defaults = {
		historyHours = 2,
		historyMode = 4,
		historyShowUncollected = false,

		chatMode = 4,
		chatIcons = false,
		chatCraftCount = false,
		chatItemCollector = true,
		chatStaticRecipientColor = {
			enabled = false,
			color = 0x3399FF,
		},

		tradeFlagItemLists = true,
		tradeFlagHideVanilla = false,
		tradeFlagChat = true,
		tradeRequestMode = 1,
		tradeRequestPrefix = "Requesting",
		tradeIncludeBoE = false,
		tradeCommandsCount = 0,

		autoBind = {
			stopTime = 0,
			junk = false,
		},

		antiquityEnabled = true,
		antiquityOnlyMotifs = false,
		antiquityIgnorePartial = false,
		antiquityFlagTradeable = true,
		antiquityMapColors = {
			fullCodex = 0x00FF66,
			incompleteCodex = 0xCCCC00,
			neverFound = 0xCC3333,
		},

		uncollectedColors = {
			lootedPersonal = 0xCC0000,
			lootedGroup = 0xFF9900,
			itemLists = 0xCC0066,
			linkedChat = 0xCCCC00,
		},

		featureRev = 0,
	},

	notable = {
		whitelist = {
			[68342] = true, -- Hakeijo
		--	[114892] = true, -- Mundane Rune
		--	[114895] = true, -- Heartwood
			[139019] = true, -- Powdered Mother of Pearl
			[139020] = true, -- Clam Gall
		--	[150669] = true, -- Chaurus Egg
		--	[150670] = true, -- Vile Coagulant
			[150671] = true, -- Dragon Rheum
		--	[150672] = true, -- Crimson Nirnroot
			[150731] = true, -- Dragon's Blood
			[150789] = true, -- Dragon's Bile
			[166045] = true, -- Indeko
			[197853] = true, -- Abyss-Drenched Folio Volume
		--	[204881] = true, -- Luminous Ink
			[217654] = true, -- Algae-Laden Sunport Pack
			[224357] = true, -- Cultivated Cryptpods
			[224359] = true, -- Fossilized Verminous Bones
		},
		blacklist = {
			[26802] = true, -- Frost Mirriam
			[27059] = true, -- Bervez Juice
			[45853] = true, -- Rekuta
		--	[64487] = true, -- Key Fragment
			[114427] = true, -- Undaunted Plunder
			[139414] = true, -- Slaughterstone
		},
		traits = {
			[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = true,
			[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = true,
			[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = true,
		},
	},

	expirationInterval = 900000, -- 15 minutes
	refreshThrottle = 250, -- 0.25s

	flags = {
		personal = 2,
		notable = 3,
		set = 5,
	},

	refreshLevel = 0,
	refreshPrevious = 0,
	refreshCallbacks = { },

	nameCache = { },
	inventory = {
		lastScan = 0,
	},

	modules = {
		multi = { },
		trade = { },
	}
}
local LootLog = LootLog
local LootLogMulti = LootLog.modules.multi
local LootLogTrade = LootLog.modules.trade

local LMAS = LibMultiAccountSets
local LCK = LibCharacterKnowledge
local LMAC = LibMultiAccountCollectibles

local function OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= LootLog.name) then return end

	EVENT_MANAGER:UnregisterForEvent(LootLog.name, EVENT_ADD_ON_LOADED)

	LootLog.vars = ZO_SavedVars:NewAccountWide("LootLogSavedVariables", 2, nil, LootLog.defaults, nil, "$InstallationWide")

	-- Initialize history
	local server = LCCC.GetServerName()
	if (not LootLogHistory) then LootLogHistory = { } end
	if (not LootLogHistory[server]) then LootLogHistory[server] = { } end
	LootLog.history = LootLogHistory[server]

	-- Initialize LootLogMulti
	LootLogMulti.Initialize(server)

	-- Initialize settings panel
	LootLog.RegisterSettingsPanel()

	-- Cache self-identifiers
	LootLog.self = {
		name = GetUnitName("player"),
		charId = GetCurrentCharacterId(),
		userId = GetDisplayName(),
		you = GetString(SI_LOOTLOG_SELF_IDENTIFIER),
	}

	LCCC.RegisterLinkHandler("llweb", function() RequestOpenUnsafeURL(LootLog.url) end)

	LCCC.RunAfterInitialLoadscreen(function( )
		LootLog.RunOnce()

		-- Garbage collection
		EVENT_MANAGER:RegisterForUpdate(LootLog.name, LootLog.expirationInterval, LootLog.ExpireOldData)
		LootLog.ExpireOldData()

		-- Start monitoring loot
		EVENT_MANAGER:RegisterForEvent(LootLog.name, EVENT_LOOT_RECEIVED, LootLog.OnLootReceived)

		-- Monitor collection changes
		local refresh = function() LootLog.RefreshUI(1) end

		if (LMAS) then
			LMAS.RegisterForCallback(LootLog.name, LMAS.EVENT_COLLECTION_UPDATED, refresh)
		else
			EVENT_MANAGER:RegisterForEvent(LootLog.name, EVENT_ITEM_SET_COLLECTIONS_UPDATED, refresh)
			EVENT_MANAGER:RegisterForEvent(LootLog.name, EVENT_ITEM_SET_COLLECTION_UPDATED, refresh)
		end

		if (LMAC) then
			LMAC.RegisterForCallback(LootLog.name, LMAC.EVENT_COLLECTION_UPDATED, refresh)
		else
			EVENT_MANAGER:RegisterForEvent(LootLog.name, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, refresh)
		end

		if (LCK) then
			LCK.RegisterForCallback(LootLog.name, LCK.EVENT_UPDATE_REFRESH, refresh)
		end
	end)

	LootLog.InitializeHistory()
	LootLog.InitializeMats()

	-- The vanilla inventory indicators need to be hooked before inventory
	-- initialization, which is pre-completion of the initial load screen
	LootLogTrade.CheckFlagHooks()
end

function LootLog.OnLootReceived( eventCode, receivedBy, itemName, quantity, soundCategory, lootType, self, isPickpocketLoot, questItemIcon, itemId, isStolen )
	local notable

	if (lootType == LOOT_TYPE_ITEM) then
		notable = LootLog.IsItemNotable(itemName, itemId)
	elseif (lootType == LOOT_TYPE_COLLECTIBLE) then
		notable = true
		quantity = 1
	elseif (lootType == LOOT_TYPE_ANTIQUITY_LEAD and type(itemId) == "number") then
		itemName = itemId
		notable = true
		quantity = 1
	else
		return
	end

	if (self or notable) then
		LootLog.LogItem(itemName, quantity, notable, (not self) and receivedBy or nil)
	end
end

function LootLog.RunOnce( )
	-- Special one-time actions for fresh installs or upgrades
	local CURRENT_FEATURE_REV = 4

	if (LootLog.vars.featureRev < 2) then
		LootLog.Msg(GetString(SI_LOOTLOG_WELCOME))
	end

	if (LootLog.vars.featureRev == 2 or LootLog.vars.featureRev == 3) then
		-- Filter modes were re-ordered in versions 2.2.0 and 2.2.1
		local translate = { 2, 1, 4, 3, 5, 6, 0 }
		if (LootLog.vars.featureRev == 2) then translate[6] = 0 end
		LootLog.vars.historyMode = translate[LootLog.vars.historyMode]
		LootLog.vars.chatMode = translate[LootLog.vars.chatMode]
	end

	LootLog.vars.featureRev = CURRENT_FEATURE_REV
end

function LootLog.RefreshUI( refreshLevel )
	if (refreshLevel and LootLog.refreshLevel < refreshLevel) then
		LootLog.refreshLevel = refreshLevel
	end

	local previousRefreshRequest = LootLog.refreshPrevious
	LootLog.refreshPrevious = GetGameTimeMilliseconds()

	if (LootLog.refreshPrevious - previousRefreshRequest > LootLog.refreshThrottle) then
		for _, callback in ipairs(LootLog.refreshCallbacks) do
			callback(LootLog.refreshLevel)
		end
		LootLog.refreshLevel = 0
	else
		local name = LootLog.name .. "RefreshThrottle"
		EVENT_MANAGER:UnregisterForUpdate(name)
		EVENT_MANAGER:RegisterForUpdate(name, LootLog.refreshThrottle * 2, LootLog.RefreshUI, true)
	end
end

function LootLog.SetRetentionText( control )
	control:SetText(string.format(GetString(SI_LOOTLOG_HISTORY_LABEL), LootLog.vars.historyHours))
end

function LootLog.IsItemNotable( itemLink, itemId )
	if (not itemId) then
		itemId = GetItemLinkItemId(itemLink)
	end

	if (LootLog.notable.whitelist[itemId]) then
		return true
	elseif (LootLog.notable.blacklist[itemId]) then
		return false
	elseif (LootLog.notable.traits[GetItemLinkTraitType(itemLink)]) then
		return true
	end

	local itemType, specializedItemType = GetItemLinkItemType(itemLink)

	if (GetItemLinkActorCategory(itemLink) == GAMEPLAY_ACTOR_CATEGORY_COMPANION) then
		return GetItemLinkFunctionalQuality(itemLink) >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT
	elseif (itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR) then
		if (GetItemLinkSetInfo(itemLink)) then
			return true
		end
	elseif (specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH or specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STACKABLE) then
		return true
	else
		local quality = GetItemLinkFunctionalQuality(itemLink)
		if ( (quality >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT) or
		     (quality >= ITEM_FUNCTIONAL_QUALITY_ARCANE and (itemType == ITEMTYPE_TROPHY or itemType == ITEMTYPE_COLLECTIBLE or IsItemLinkConsumable(itemLink))) ) then
			return true
		end
	end

	return false
end

function LootLog.Pack( ... )
	-- timestamp, itemLink, quantity, userId, charName, flags
	return string.format("%d;%s;%d;%s;%s;%d", ...)
end

function LootLog.Unpack( entry )
	if (type(entry) == "string") then
		entry = { zo_strsplit(";", entry) }
		entry[1] = tonumber(entry[1]) -- timestamp
		entry[2] = LCCC.FixNumber(entry[2]) -- itemLink
		entry[3] = tonumber(entry[3]) -- quantity
		entry[6] = tonumber(entry[6]) -- flags
	end
	return entry
end

function LootLog.LogItem( itemLink, quantity, notable, receivedBy )
	local timestamp = GetTimeStamp()
	local key = zo_floor(timestamp / 3600)

	if (not LootLog.history[key]) then LootLog.history[key] = { } end

	local personal = not receivedBy
	local userId

	if (personal) then
		userId = LootLog.self.userId
		receivedBy = LootLog.self.name
	else
		userId = LootLog.GetAccountName(receivedBy)
		receivedBy = zo_strformat(SI_PLAYER_NAME, receivedBy)
	end

	local hasSet = GetItemLinkSetInfo(itemLink)

	local flags = 1
	if (personal) then flags = flags * LootLog.flags.personal end
	if (notable) then flags = flags * LootLog.flags.notable end
	if (hasSet) then flags = flags * LootLog.flags.set end

	table.insert(LootLog.history[key], LootLog.Pack(timestamp, itemLink, quantity, userId, receivedBy, flags))

	LootLog.RefreshUI(2)

	local isUncollected, uncollectedColor, uncollectedIcon, ignoreCollectability
	if (LootLog.vars.chatItemCollector) then
		isUncollected, uncollectedColor, uncollectedIcon, ignoreCollectability = LootLogMulti.ShouldFlagAsUncollected(itemLink, personal)
	end

	if ( (LootLog.vars.chatMode > 0 and isUncollected and not ignoreCollectability) or
	     (LootLog.vars.chatMode == 1 and hasSet and personal) or
	     (LootLog.vars.chatMode == 2 and hasSet) or
	     (LootLog.vars.chatMode == 3 and notable and personal) or
	     (LootLog.vars.chatMode == 4 and notable) or
	     (LootLog.vars.chatMode == 5 and personal) or
	     (LootLog.vars.chatMode == 6) ) then
		local formattedIndicator = ""
		local formattedIcon = ""
		local formattedQuantity = ""
		local formattedTrait = ""
		local formattedRecipient = ""

		if (isUncollected) then
			formattedIndicator = string.format("|c%06X%s|r", uncollectedColor, zo_iconFormatInheritColor(uncollectedIcon, 22, 22))
		end

		if (LootLog.vars.chatIcons) then
			formattedIcon = zo_iconTextFormat(LootLog.GetLinkIcon(itemLink), 22, 22, "", false)
		end

		if (quantity > 1) then
			formattedQuantity = string.format("×%d", quantity)
		end

		-- 0xC5C29E = INTERFACE_COLOR_TYPE_TEXT_COLORS:INTERFACE_TEXT_COLOR_NORMAL
		local traitName = LootLog.GetGearTraitName(itemLink)
		if (traitName ~= "") then
			formattedTrait = string.format(" |cC5C29E(%s)|r", traitName)
		elseif (LootLog.vars.chatCraftCount and personal and CanItemLinkBeVirtual(itemLink)) then
			local count = GetItemLinkInventoryCount(itemLink, INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG)
			if (count > 0) then
				formattedTrait = string.format(" |cC5C29E%s%d|r", zo_iconFormat("/esoui/art/tooltips/icon_craft_bag.dds", 20, 20), count)
			end
		end

		if (LootLog.vars.chatMode % 2 == 0 or (isUncollected and not personal)) then
			local recipient

			if (personal) then
				recipient = LootLog.self.you
			elseif (ZO_ShouldPreferUserId() and userId) then
				recipient = string.format("|H0:character:%s|h%s|h", userId, userId)
			else
				recipient = string.format("|H0:character:%s|h%s|h", receivedBy, receivedBy)
			end

			local color
			if (LootLog.vars.chatStaticRecipientColor.enabled) then
				color = LootLog.vars.chatStaticRecipientColor.color
			else
				-- Use the hash of the name for the color so that is random, but consistent
				local hash = HashString(recipient)
				local part = function(n) return BitAnd(BitRShift(hash, n), 0x3FF) / 0x3FF end
				color = LCCC.RGBToInt24(LCCC.HSLToRGB(part(0), part(10) * 0.75 + 0.25, part(20) * 0.4 + 0.45))
			end

			formattedRecipient = string.format(" → |c%06X%s|r", color, recipient)
		end

		LootLog.Msg(string.format(
			"%s%s%s%s%s%s",
			formattedIndicator,
			formattedIcon,
			(type(itemLink) == "string") and itemLink:gsub("^|H0", "|H1", 1) or LootLog.FormatAntiquityLead(itemLink, true),
			formattedQuantity,
			formattedTrait,
			formattedRecipient
		))
	end
end

function LootLog.ExpireOldData( )
	local currentKey = zo_floor(GetTimeStamp() / 3600)
	local expired = false
	for key, _ in pairs(LootLog.history) do
		if (currentKey - key > LootLog.vars.historyHours) then
			LootLog.history[key] = nil
			expired = true
		end
	end

	if (expired) then
		LootLog.RefreshUI(3)
	end
end

function LootLog.ExpireAllData( )
	for key, _ in pairs(LootLog.history) do
		LootLog.history[key] = nil
	end

	LootLog.RefreshUI(3)
end

function LootLog.Msg( text )
	CHAT_ROUTER:AddSystemMessage(string.format("|H0:lootlog|h[%s]|h %s", LootLog.title, text))
end

function LootLog.GetLinkName( link )
	local name = (type(link) == "string") and GetItemLinkName(link) or LootLog.GetAntiquityLeadName(link)

	if (name == "") then
		local id = GetCollectibleIdFromLink(link)
		if (id) then
			name = GetCollectibleName(id)
		end
	end

	return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
end

function LootLog.GetLinkIcon( link )
	if (type(link) == "string") then
		local id = GetCollectibleIdFromLink(link)
		if (id) then
			return GetCollectibleIcon(id)
		else
			return GetItemLinkIcon(link)
		end
	else
		return GetAntiquityLeadIcon()
	end
end

function LootLog.GetGearTraitName( itemLink )
	local traitName = ""
	local itemType = GetItemLinkItemType(itemLink)

	if (itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR) then
		local traitType = GetItemLinkTraitType(itemLink)
		if (traitType ~= ITEM_TRAIT_TYPE_NONE) then
			traitName = GetString("SI_ITEMTRAITTYPE", traitType)
		end
	end

	return traitName
end

function LootLog.GetAntiquityLeadName( antiquityId )
	return zo_strformat(SI_ANTIQUITY_LEAD_NAME_FORMATTER, GetAntiquityName(antiquityId))
end

function LootLog.FormatAntiquityLead( antiquityId, useBrackets )
	local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ANTIQUITY_QUALITY_COLORS, GetAntiquityQuality(antiquityId))
	return string.format(
		useBrackets and "|c%02X%02X%02X[%s]|r" or "|c%02X%02X%02X%s|r",
		r * 255,
		g * 255,
		b * 255,
		LootLog.GetAntiquityLeadName(antiquityId)
	)
end

function LootLog.GetAntiquityRewardLink( antiquityId )
	local setId = GetAntiquitySetId(antiquityId)
	local rewardId = (setId == 0) and GetAntiquityRewardId(antiquityId) or GetAntiquitySetRewardId(setId)
	local link = GetItemRewardItemLink(rewardId)

	if (link == "") then
		local id = GetCollectibleRewardCollectibleId(rewardId)
		if (id > 0) then
			link = GetCollectibleLink(id, LINK_STYLE_DEFAULT)
		end
	end

	return link
end

function LootLog.GetItemLinkCollectionStatus( itemLink )
	-- Returns:
	-- 0: Not a collectible
	-- 1: Collectible and not collected
	-- 2: Collectible and collected

	if (IsItemLinkSetCollectionPiece(itemLink)) then
		if (IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))) then
			return 2
		else
			return 1
		end
	else
		local id = GetItemLinkContainerCollectibleId(itemLink)
		if (id > 0) then
			if (IsCollectibleOwnedByDefId(id)) then
				return 2
			elseif (GetCollectibleCategoryType(id) == COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT and not CanCombinationFragmentBeUnlocked(id)) then
				return 2
			else
				return 1
			end
		end
		return 0
	end
end

function LootLog.IsItemLinkTradeable( itemLink )
	if (IsItemLinkBound(itemLink) or IsItemLinkReconstructed(itemLink)) then
		return false
	else
		local bindType = GetItemLinkBindType(itemLink)
		if (bindType == BIND_TYPE_ON_PICKUP_BACKPACK) then
			return false
		elseif (bindType == BIND_TYPE_ON_PICKUP) then
			local itemType = GetItemLinkItemType(itemLink)
			return itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR
		else
			return true
		end
	end
end

function LootLog.IsItemLinkUncollected( itemLink, checkInventory )
	if (LootLog.GetItemLinkCollectionStatus(itemLink) == 1) then
		if (checkInventory) then
			LootLog.ScanInventoryForUncollectedItems()
			if (IsItemLinkSetCollectionPiece(itemLink)) then
				return LootLog.inventory.pieces[LootLog.GetItemLinkItemSetCollectionKey(itemLink)] ~= true
			else
				return LootLog.inventory.collectibles[GetItemLinkContainerCollectibleId(itemLink)] ~= true
			end
		else
			return true
		end
	else
		return false
	end
end

function LootLog.ScanInventoryForUncollectedItems( )
	local cooldown = 1000 -- 1s
	local bags = {
		BAG_BACKPACK,
		BAG_BANK,
		BAG_SUBSCRIBER_BANK,
	}

	if (LootLog.inventory.lastScan < GetGameTimeMilliseconds() - cooldown) then
		LootLog.inventory = {
			lastScan = GetGameTimeMilliseconds(),
			pieces = { },
			collectibles = { },
		}

		for _, bag in ipairs(bags) do
			local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(bag)
			for _, item in pairs(bagCache) do
				local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
				if (LootLog.GetItemLinkCollectionStatus(itemLink) == 1) then
					if (IsItemLinkSetCollectionPiece(itemLink)) then
						LootLog.inventory.pieces[LootLog.GetItemLinkItemSetCollectionKey(itemLink)] = true
					else
						LootLog.inventory.collectibles[GetItemLinkContainerCollectibleId(itemLink)] = true
					end
				end
			end
		end
	end
end

function LootLog.GetItemLinkItemSetCollectionKey( itemLink )
	return string.format(
		"%d:%s",
		select(6, GetItemLinkSetInfo(itemLink)),
		Id64ToString(GetItemLinkItemSetCollectionSlot(itemLink))
	)
end

function LootLog.GetAccountName( character )
	local accountName = LootLog.nameCache[character]

	if (not accountName) then
		for i = 1, GetGroupSize() do
			local unitTag = GetGroupUnitTagByIndex(i)
			if (LCCC.MatchStrings(GetRawUnitName(unitTag), character)) then
				accountName = GetUnitDisplayName(unitTag)
				LootLog.nameCache[character] = accountName
				break
			end
		end
	end

	return accountName or "@"
end

function LootLog.RegisterSettingsPanel( )
	local LAM = LCCC.GetLibAddonMenu()

	if (LAM) then
		local panelId = "LootLogSettings"

		LootLog.settingsPanel = LAM:RegisterAddonPanel(panelId, {
			type = "panel",
			name = LootLog.title,
			version = LCCC.FormatVersion(LCCC.GetAddOnVersion(LootLog.name)),
			author = "@code65536",
			website = LootLog.url,
			donation = LootLog.url .. "#donate",
			registerForRefresh = true,
		})

		--------
		-- Loot notifications in chat
		--------

		local chatModes = { }
		local chatModeLabels = { }
		for i = 0, 6 do
			table.insert(chatModes, i)
			table.insert(chatModeLabels, GetString("SI_LOOTLOG_MODE", i))
		end

		local ChatIsDisabled = function( )
			return LootLog.vars.chatMode == 0
		end

		--------
		-- Request link
		--------

		local requestModes = { }
		local requestModeLabels = { }
		for i = 0, 2 do
			table.insert(requestModes, i)
			table.insert(requestModeLabels, GetString("SI_LOOTLOG_SETTING_TRADEREQ", i))
		end

		--------
		-- Color pickers and icon previews
		--------

		local Colors = {
			data = { },
			GetGlobalName = function( key )
				return "LootLogSettings_" .. key
			end,
		}

		Colors.UpdatePreview = function( key )
			local control = _G[Colors.GetGlobalName(key)]
			if (control and control.preview) then
				local data = Colors.data[key]
				control.preview:SetColor(LCCC.Int24ToRGBA(data.setting[data.priority or key]))
			end
		end

		Colors.MakePicker = function( key, name, tooltip, disabledKey, group, namePrefix, icon )
			local setting = group and LootLog.vars[group] or LootLog.vars.uncollectedColors
			if (namePrefix) then
				name = string.format("%s: %s", GetString(namePrefix), GetString(name))
			end
			local picker = {
				type = "colorpicker",
				name = name,
				tooltip = tooltip,
				getFunc = function() return LCCC.Int24ToRGB(setting[key]) end,
				setFunc = function(...)
					setting[key] = LCCC.RGBToInt24(...)
					Colors.UpdatePreview(key)
					LootLog.RefreshUI(1)
				end,
				reference = Colors.GetGlobalName(key),
			}
			if (disabledKey) then
				picker.disabled = function() return not LootLog.vars[disabledKey] end
			end
			Colors.data[key] = { setting = setting, icon = icon }
			return picker
		end

		Colors.MakePickerTreasureMaps = function( key, name )
			return Colors.MakePicker(key, name, nil, "antiquityEnabled", "antiquityMapColors", SI_SPECIALIZEDITEMTYPE100, "LootLog/art/antiquities-general.dds")
		end

		Colors.CreatePreviews = function( panel )
			if (panel == LootLog.settingsPanel) then
				CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", Colors.CreatePreviews)
				for key, data in pairs(Colors.data) do
					local control = _G[Colors.GetGlobalName(key)]
					if (control and control.color and not control.preview) then
						control.preview = WINDOW_MANAGER:CreateControl(nil, control.color, CT_TEXTURE)
						control.preview:SetTexture(data.icon or "LootLog/art/uncollected.dds")
						control.preview:SetDimensions(22, 22)
						control.preview:SetAnchor(LEFT, control.thumb, RIGHT, 10)
					end
					Colors.UpdatePreview(key)
				end
			end
		end
		CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", Colors.CreatePreviews)

		--------
		-- Put it all together
		--------

		LAM:RegisterOptionControls(panelId, {
			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LOOTLOG_SECTION_HISTORY,
			},
			--------------------
			{
				type = "slider",
				name = SI_LOOTLOG_SETTING_HISTORY,
				min = 1,
				max = 24,
				getFunc = function() return LootLog.vars.historyHours end,
				setFunc = function(hours) LootLog.vars.historyHours = hours end,
			},
			--------------------
			{
				type = "button",
				name = SI_LOOTLOG_SETTING_CLEAR,
				func = LootLog.ExpireAllData,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LOOTLOG_SECTION_CHAT,
			},
			--------------------
			{
				type = "dropdown",
				name = SI_LOOTLOG_SETTING_CHATMODE,
				choices = chatModeLabels,
				choicesValues = chatModes,
				getFunc = function() return LootLog.vars.chatMode end,
				setFunc = function(mode) LootLog.vars.chatMode = mode end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_CHATICONS,
				getFunc = function() return LootLog.vars.chatIcons end,
				setFunc = function(enabled) LootLog.vars.chatIcons = enabled end,
				disabled = ChatIsDisabled,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_CHATSTOCK,
				getFunc = function() return LootLog.vars.chatCraftCount end,
				setFunc = function(enabled) LootLog.vars.chatCraftCount = enabled end,
				disabled = ChatIsDisabled,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_CHATUNC,
				tooltip = SI_LOOTLOG_SETTING_CHATUNCTT,
				getFunc = function() return LootLog.vars.chatItemCollector end,
				setFunc = function(enabled) LootLog.vars.chatItemCollector = enabled end,
				disabled = ChatIsDisabled,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_CHATRCLR,
				getFunc = function() return LootLog.vars.chatStaticRecipientColor.enabled end,
				setFunc = function(enabled) LootLog.vars.chatStaticRecipientColor.enabled = enabled end,
				disabled = ChatIsDisabled,
			},
			--------------------
			{
				type = "colorpicker",
				name = "",
				getFunc = function() return LCCC.Int24ToRGB(LootLog.vars.chatStaticRecipientColor.color) end,
				setFunc = function(...) LootLog.vars.chatStaticRecipientColor.color = LCCC.RGBToInt24(...) end,
				disabled = function() return LootLog.vars.chatMode == 0 or not LootLog.vars.chatStaticRecipientColor.enabled end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LOOTLOG_SECTION_TRADE,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_TRADEITLS,
				tooltip = SI_LOOTLOG_SETTING_TRADEILTT,
				getFunc = function() return LootLog.vars.tradeFlagItemLists end,
				setFunc = function( enabled )
					LootLog.vars.tradeFlagItemLists = enabled
					LootLogTrade.CheckFlagHooks()
				end,
			},
			--------------------
			{
				type = "checkbox",
				name = string.format("|u40:0::%s|u", GetString(SI_LOOTLOG_SETTING_TRADEHBGI)),
				getFunc = function() return LootLog.vars.tradeFlagHideVanilla end,
				setFunc = function( enabled )
					LootLog.vars.tradeFlagHideVanilla = enabled
					LootLogTrade.CheckFlagHooks()
				end,
				disabled = function() return not LootLog.vars.tradeFlagItemLists end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_TRADELINK,
				getFunc = function() return LootLog.vars.tradeFlagChat end,
				setFunc = function( enabled )
					LootLog.vars.tradeFlagChat = enabled
					if (enabled) then
						LootLogTrade.HookIncomingChat()
					end
				end,
			},
			--------------------
			{
				type = "dropdown",
				name = string.format("|u40:0::%s|u", GetString(SI_LOOTLOG_SETTING_TRADEREQ)),
				choices = requestModeLabels,
				choicesValues = requestModes,
				getFunc = function() return LootLog.vars.tradeRequestMode end,
				setFunc = function(mode) LootLog.vars.tradeRequestMode = mode end,
				disabled = function() return not LootLog.vars.tradeFlagChat end,
			},
			--------------------
			{
				type = "editbox",
				name = string.format("|u40:0::%s|u", GetString(SI_LOOTLOG_SETTING_TRADEREQM)),
				getFunc = function() return LootLog.vars.tradeRequestPrefix end,
				setFunc = function(text) LootLog.vars.tradeRequestPrefix = text end,
				disabled = function() return not (LootLog.vars.tradeFlagChat and LootLog.vars.tradeRequestMode > 0) end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_TRADEBE,
				tooltip = SI_LOOTLOG_SETTING_TRADEBETT,
				getFunc = function() return LootLog.vars.tradeIncludeBoE end,
				setFunc = function(enabled) LootLog.vars.tradeIncludeBoE = enabled end,
			},

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_MAP_INFO_MODE_ANTIQUITIES,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_ANTIQUITY,
				getFunc = function() return LootLog.vars.antiquityEnabled end,
				setFunc = function( enabled )
					LootLog.vars.antiquityEnabled = enabled
					if (enabled) then
						LootLog.HookAntiquityTooltips()
					end
				end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_ONLYMOTIF,
				getFunc = function() return LootLog.vars.antiquityOnlyMotifs end,
				setFunc = function(enabled) LootLog.vars.antiquityOnlyMotifs = enabled end,
				disabled = function() return not LootLog.vars.antiquityEnabled end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_NOPARTIAL,
				getFunc = function() return LootLog.vars.antiquityIgnorePartial end,
				setFunc = function(enabled) LootLog.vars.antiquityIgnorePartial = enabled end,
				disabled = function() return not LootLog.vars.antiquityEnabled end,
			},
			--------------------
			{
				type = "checkbox",
				name = SI_LOOTLOG_SETTING_TRADELEAD,
				getFunc = function() return LootLog.vars.antiquityFlagTradeable end,
				setFunc = function(enabled) LootLog.vars.antiquityFlagTradeable = enabled end,
				disabled = function() return not LootLog.vars.antiquityEnabled end,
			},
			--------------------
			Colors.MakePickerTreasureMaps("fullCodex", SI_LOOTLOG_SETTING_ACLRFULL),
			Colors.MakePickerTreasureMaps("incompleteCodex", SI_LOOTLOG_SETTING_ACLRINC),
			Colors.MakePickerTreasureMaps("neverFound", SI_LOOTLOG_SETTING_ACLRNEVER),

			--------------------------------------------------------------------
			{
				type = "header",
				name = SI_LOOTLOG_SECTION_UNCCOLORS,
			},
			--------------------
			Colors.MakePicker("lootedPersonal", SI_LOOTLOG_SETTING_UCLRPERS),
			Colors.MakePicker("lootedGroup", SI_LOOTLOG_SETTING_UCLRGRP),
			Colors.MakePicker("linkedChat", SI_LOOTLOG_SETTING_UCLRCHAT, nil, "tradeFlagChat"),
			Colors.MakePicker("itemLists", SI_LOOTLOG_SETTING_UCLRITLS, SI_LOOTLOG_SETTING_TRADEILTT, "tradeFlagItemLists"),

			--------------------------------------------------------------------
			unpack(LootLogMulti.BuildSettings(Colors))
		})
	end
end

function LootLog.OpenSettingsPanel( )
	if (LootLog.settingsPanel) then
		LibAddonMenu2:OpenToPanel(LootLog.settingsPanel)
	end
end

function LootLog.ChatCommandsReference( )
	RequestOpenUnsafeURL("http://eso.code65536.com/addons/lootlog/#chatcommands")
end

EVENT_MANAGER:RegisterForEvent(LootLog.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
