local LCCC = LibCodesCommonCode
local Internal = LibExtendedJournalInternal
local Public = LibExtendedJournal
local Controls = Internal.controls


--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------

-- Users of LEJ must override this prior to EVENT_ADD_ON_LOADED; if this is not
-- set, then it means that there are no users of LEJ
Public.Used = false

function Public.Show( descriptor, toggle )
	Internal.LazyInitialize(descriptor)

	if (descriptor and descriptor ~= ZO_MenuBar_GetSelectedDescriptor(Controls.menu)) then
		ZO_MenuBar_SelectDescriptor(Controls.menu, descriptor, true)
		toggle = false
	end

	if (not SCENE_MANAGER:IsShowing(Internal.SCENE_NAME)) then
		SCENE_MANAGER:Push(Internal.SCENE_NAME)
		if (Controls.mainMenu and ZO_MenuBar_GetSelectedDescriptor(Controls.mainMenu) ~= Internal.name) then
			ZO_MenuBar_SelectDescriptor(Controls.mainMenu, Internal.name, true)
		end
		Internal.FixMainMenuCategory()
	elseif (toggle == true) then
		SCENE_MANAGER:ShowBaseScene()
	end
end

function Public.RegisterTab( descriptor, tabData )
	tabData.descriptor = descriptor
	Internal.tabs[descriptor] = tabData

	-- Generate combined title for tooltips and keybinds
	if (tabData.title) then
		tabData.name = table.concat({ Internal.GetString(tabData.title), tabData.subtitle and Internal.GetString(tabData.subtitle) }, ": ")
	end

	-- Initialize keybind
	if (type(tabData.binding) == "string") then
		ZO_CreateStringId("SI_BINDING_NAME_" .. tabData.binding, Internal.GetString(tabData.name))
	end

	-- Register slash commands
	if (type(tabData.slashCommands) == "table") then
		local showTab = function( )
			Public.Show(descriptor)
		end
		for _, command in ipairs(tabData.slashCommands) do
			if (not SLASH_COMMANDS[command]) then
				SLASH_COMMANDS[command] = showTab
			end
		end
	end
end

function Public.GetActiveTab( )
	return Internal.activeTab and Internal.activeTab.descriptor
end

function Public.IsTabActive( descriptor )
	return descriptor == Public.GetActiveTab()
end

function Public.GetFrame( )
	return Controls.frame
end

function Public.InvokeSettings( )
	if (Internal.settingsVisible) then
		LibAddonMenu2:OpenToPanel(Internal.activeTab.settingsPanel)
	end
end


--------------------------------------------------------------------------------
-- Alternate Mode
--------------------------------------------------------------------------------

function Public.SetAlternateMode( callbackMain, callbackList )
	Internal.altMode = callbackMain
	Internal.altModeList = callbackList
end


--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------

function Public.InitializeTooltip( control )
	control = control or ExtendedJournalItemTooltip
	if (Internal.initialized) then
		InitializeTooltip(control, Controls.frame, TOPRIGHT, -100, 0, TOPLEFT)
	end
	return control
end

function Public.ItemTooltip( item, control )
	control = Public.InitializeTooltip(control)
	if (type(item) == "string") then
		control:SetLink(item)
	elseif (type(item) == "table") then
		if (type(item.collectibleId) == "number") then
			control:SetCollectible(item.collectibleId, true, false)
		elseif (type(item.antiquityId) == "number") then
			if (GetAntiquitySetId(item.antiquityId) == 0) then
				control:SetAntiquityLead(item.antiquityId)
			else
				control:SetAntiquitySetFragment(item.antiquityId)
			end
		end
	end
	return control
end

do
	local Extensions = { }

	local function TooltipExtensionAcquire( name )
		name = name or "Default"
		if (not Extensions[name]) then
			Extensions[name] = ExtendedJournalTooltipExtension:New(name)
		end
		return Extensions[name]
	end

	function Public.TooltipExtensionInitialize( showDivider, textLeft, textRight, name, appendExisting )
		return TooltipExtensionAcquire(name):Initialize(showDivider, textLeft, textRight, appendExisting)
	end

	-- Legacy compatibility functions; do not use
	function Public.TooltipExtensionAddSection(...) TooltipExtensionAcquire():AddSection(...) end
	function Public.TooltipExtensionFinalize(...) TooltipExtensionAcquire():Finalize(...) end
end


--------------------------------------------------------------------------------
-- Tooltip Hooking
-- callback( control, functionName, itemLink, sourceContext )
--------------------------------------------------------------------------------

do
	local registrants, sourceContext

	function Public.HookItemTooltips( callback )
		if (registrants) then
			table.insert(registrants, callback)
		else
			registrants = { callback }

			local TooltipHook = function( control, functionName, linkFunction, sourceParam1, sourceParam2 )
				if (control and linkFunction) then
					ZO_PostHook(control, functionName, function( self, ... )
						local itemLink = linkFunction(...)
						sourceContext = LCCC.PrepareScratchTable(sourceContext)
						if (sourceParam1) then sourceContext[sourceParam1] = select(1, ...) end
						if (sourceParam2) then sourceContext[sourceParam2] = select(2, ...) end
						for _, fn in ipairs(registrants) do
							fn(control, functionName, itemLink, sourceContext)
						end
					end)
				end
			end

			local ItemLinkPassthrough = function( itemLink )
				return itemLink
			end

			TooltipHook(PopupTooltip, "SetLink", ItemLinkPassthrough)
			TooltipHook(ItemTooltip, "SetLink", ItemLinkPassthrough)
			TooltipHook(ItemTooltip, "SetWornItem", function(slot, bagId) return GetItemLink(bagId, slot) end, "slotIndex", "bagId")
			TooltipHook(ItemTooltip, "SetBagItem", GetItemLink, "bagId", "slotIndex")
			TooltipHook(ItemTooltip, "SetTradeItem", GetTradeItemLink, "who", "tradeIndex")
			TooltipHook(ItemTooltip, "SetBuybackItem", GetBuybackItemLink)
			TooltipHook(ItemTooltip, "SetStoreItem", GetStoreItemLink)
			TooltipHook(ItemTooltip, "SetAttachedMailItem", GetAttachedItemLink, "mailId", "attachIndex")
			TooltipHook(ItemTooltip, "SetLootItem", GetLootItemLink, "lootId")
			TooltipHook(ItemTooltip, "SetReward", LCCC.GetRewardLink)
			TooltipHook(ItemTooltip, "SetQuestReward", GetQuestRewardItemLink)
			TooltipHook(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
			TooltipHook(ItemTooltip, "SetTradingHouseListing", GetTradingHouseListingItemLink)
			TooltipHook(ItemTooltip, "SetItemSetCollectionPieceLink", ItemLinkPassthrough)
			TooltipHook(ItemTooltip, "SetCollectible", ItemLinkPassthrough)
			TooltipHook(ItemTooltip, "SetPlacedFurniture", GetPlacedFurnitureLink)
			TooltipHook(ZO_SmithingTopLevelCreationPanelResultTooltip, "SetPendingSmithingItem", GetSmithingPatternResultLink, "patternIndex")
		end
	end
end


--------------------------------------------------------------------------------
-- Tooltip Colors
--------------------------------------------------------------------------------

do
	local Defaults, Current = {
		[1] = { -- Items, fragments, etc.
			[1] = 0x00FF00, -- Yes (compatible with LCK.KNOWLEDGE_KNOWN)
			[2] = 0xFF0000, -- No (compatible with LCK.KNOWLEDGE_UNKNOWN)
			[3] = 0xFFFF00, -- Partial
		},
		[2] = { -- Accounts, characters, etc.
			[0] = 0x333333, -- No data (compatible with LCK.KNOWLEDGE_NODATA)
			[1] = 0x3399FF, -- Yes (compatible with LCK.KNOWLEDGE_KNOWN)
			[2] = 0x777766, -- No (compatible with LCK.KNOWLEDGE_UNKNOWN)
		},
	}

	local function Validate( m, n )
		return (m == 1 and (n == 1 or n == 2 or n == 3)) or (m == 2 and (n == 0 or n == 1 or n == 2))
	end

	function Internal.LoadTooltipColors( )
		Current = LibExtendedJournalTooltipColors or { }
		Current[1] = Current[1] or { }
		Current[2] = Current[2] or { }
	end

	function Public.GetTooltipColor( m, n )
		if (Validate(m, n)) then
			return Current[m][n] or Defaults[m][n]
		end
		return 0
	end

	function Public.GetTooltipColorUnpacked( ... )
		return LCCC.Int24ToRGB(Public.GetTooltipColor(...))
	end

	function Public.SetTooltipColor( m, n, color, ... )
		if (Validate(m, n)) then
			local g, b = ...
			if (type(g) == "number" and type(b) == "number") then
				color = LCCC.RGBToInt24(color, ...)
			end
			if (Defaults[m][n] ~= color) then
				Current[m][n] = color
				LibExtendedJournalTooltipColors = Current
			else
				Current[m][n] = nil
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Wrapper for ZO_ComboBox:SelectItemByIndex
--------------------------------------------------------------------------------

function Public.SelectComboBoxItemByIndex( object, index, ... )
	if (type(index) ~= "number" or index < 1 or index > object:GetNumItems()) then
		index = 1
	end
	object:SelectItemByIndex(index, ...)
end
