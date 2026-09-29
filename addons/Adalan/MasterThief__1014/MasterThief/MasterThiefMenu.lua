--[[
Created by: Adalan@Aruntas
Support, Fixes, Improvements by: WolfStar07
--]]

if not MasterThief then
    MasterThief = {}
end

-- Local reference for performance
local MT = MasterThief

----------------------------------------
-- Default Settings and Values
----------------------------------------
-- Initialize RecipeQualities later when strings are available
MasterThief.RecipeQualities = nil

function MasterThief:InitializeRecipeQualities()
	if not MasterThief.RecipeQualities then
		MasterThief.RecipeQualities = {
			GetString(MT_RECIPE_COLOR_GREEN),
			GetString(MT_RECIPE_COLOR_BLUE),
			GetString(MT_RECIPE_COLOR_PURPLE),
			GetString(MT_RECIPE_COLOR_GOLD),
		}
	end
end

MasterThief.OptionsDefault = 
{
	--Turn on/off Messagebox to move
	MoveMsgbox = false,	
	--Announce specials as OnScreen-Messages (recipes and motifs)
	SpecialOnScreenMsg = true,	
	--Announce specials as Chat-Message (recipes and motifs)
	SpecialChatMsg = true,		
	--Announce regular message as Chat-Message
	RegularChatMsg = true,
	--Announce useless items as Chat-Message (on pickpocking only)
	AnnounceUselessItem = false,
	--MessageBox delay
	MessageBoxDelay = 2000,
	--WindowPosition
	left = 100,
	top = 100,
	-- min. free slots left till warning
	MinFreeSlots = 1,
	-- min sell price to auto steal an item into the bag
	MinSellPrice = 30,
	-- Announce BE CAREFUL every time you are not far enough from your destination
	AnnounceBeCareful = true,
	-- Set the minimum quality level of a recipe to get autolooted. Unknown recipes below the given level will still be autolooted
	MinRecipeQuality = 2,
	-- Announce already known recipes on chat
	AnnounceKnownRecipes = true,
	-- Announce items sells or transfers at fence on chat
	AnnounceSellsTransfers = true,
	-- Announce max fence sell/transfer limits
	AnnounceMaxFencerLimits = false,
	-- to remember, what was set in SYSTEM-SETTING for stolen items (not used in own menu-options)
	SYSTEM_AutolootStolenItems = "",
	-- exclude this char on recipe compares (just the other chars)
	compareMyRecipes = true,
	-- loot all known recipes below set quality level
	LootUnknownRecipesBelowLevel = false,
	-- enable disable autoloot by lootlist
	lootlist = true,
	-- companion rapport protection
	CompanionWarnActions = true,
	CompanionBlockActions = true,
	CompanionAutoDismiss = false,
	-- show the reticle-anchored pickpocket count display
	PickpocketCounterEnabled = true,
}

MasterThief.StolenValuesDefault = 
{
	-- stolen gold sold at fencer
	stolenValuesTotal = 0,
	-- paid bounty total
	paidBountyTotal = 0,
}

----------------------------------------
-- Recipe Quality Helper Functions
----------------------------------------

function MasterThief:GetMinRecipeQuality(idx)
	self:InitializeRecipeQualities()  -- Ensure initialized
	return MasterThief.RecipeQualities[idx]
end

function MasterThief:SetMinRecipeQuality(sValue)
	for i=1,#MasterThief.RecipeQualities do
		if(string.lower(MasterThief.RecipeQualities[i]) == string.lower(sValue)) then
			MasterThief.SavedVarsOptions.MinRecipeQuality = i
		end
	end
end

----------------------------------------
-- Check if CreateMessageBox exists in UI file
----------------------------------------
function MasterThief:CheckUILoaded()
	return MasterThief.CreateMessageBox ~= nil
end

----------------------------------------
-- Create MasterThief Addon-SettingsMenu
----------------------------------------
function MasterThief:CreateSettingsMenu()
	local LAM = LibAddonMenu2
	--Register the Options panel with LAM
	local panelData = 
	{
    	type = "panel",
     	name = "MasterThief",
		author = "Adalan, WolfStar07",
		version = MasterThief.version,
	}
	LAM:RegisterAddonPanel("MasterThiefOptions", panelData)

	--Set the actual panel data
	local optionsData = {
		{
			type = "description",
			title = nil,
			text = "|cF1C013"..GetString(MT_MISC_MASTERTHIEF_COMMANDS).."|r\n/|cF1C013masterthief|r: "..GetString(MT_MISC_MASTERTHIEF_LISTCOMMANDS),
			width = "full",
		},	
    	{
          type = "checkbox",
          name = GetString(MT_SHOW_MESSAGEBOX_NAME),
          tooltip = GetString(MT_SHOW_MESSAGEBOX_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.MoveMsgbox end,
          setFunc = function(value) MasterThief.SavedVarsOptions.MoveMsgbox = value ctlMasterThiefLabel:SetText("MasterThief") MasterThief:ShowMsgBox(value) end,
          width = "full",
    	},
    	{
          type = "slider",
		  min = 1000,
		  max = 10000,		  
          name = GetString(MT_MESSAGE_DELAY_NAME),
          tooltip = GetString(MT_MESSAGE_DELAY_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.MessageBoxDelay end,
          setFunc = function(value) MasterThief.SavedVarsOptions.MessageBoxDelay = value end,
          width = "full",
    	},		
    	{
          type = "slider",
		  min = 0,
		  max = 20,				  
          name = GetString(MT_FREE_SLOTS_LEFT_LIMIT_NAME),
          tooltip = GetString(MT_FREE_SLOTS_LEFT_LIMIT_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.MinFreeSlots  end,
          setFunc = function(value) MasterThief.SavedVarsOptions.MinFreeSlots = value end,
          width = "full",
    	},
    	{
          type = "slider",
		  min = 0,
		  max = 1000,	
          name = GetString(MT_MIN_SELL_PRICE_AUTOLOOT_NAME),
          tooltip = GetString(MT_MIN_SELL_PRICE_AUTOLOOT_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.MinSellPrice  end,
          setFunc = function(value) MasterThief.SavedVarsOptions.MinSellPrice = value end,
          width = "full",
    	},
		{
			type = "dropdown",
			name = GetString(MT_RECIPE_QUALITY_NAME),
			tooltip = GetString(MT_RECIPE_QUALITY_TEXT),
			choices = MasterThief.RecipeQualities,
	        getFunc = function() return MasterThief:GetMinRecipeQuality(MasterThief.SavedVarsOptions.MinRecipeQuality) end,
			setFunc = function(value) MasterThief:SetMinRecipeQuality(value) end,
			width = "full",
		},
    	{
          type = "checkbox",
          name = GetString(MT_LOOT_UNKNOWN_RECIPES_NAME),
          tooltip = GetString(MT_LOOT_UNKNOWN_RECIPES_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.LootUnknownRecipesBelowLevel end,
          setFunc = function(value) MasterThief.SavedVarsOptions.LootUnknownRecipesBelowLevel = value end,
          width = "full",
    	},		
    	{
          type = "checkbox",
          name = GetString(MT_EXCLUDE_COMPARE_NAME),
          tooltip = GetString(MT_EXCLUDE_COMPARE_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.compareMyRecipes end,
          setFunc = function(value) MasterThief.SavedVarsOptions.compareMyRecipes = value if (value) then MasterThief:SaveKnownRecipes(nil, false) else MasterThief:SaveKnownRecipes(nil, false) end end,
          width = "full",
    	},
    	{
          type = "checkbox",
          name = GetString(MT_AUTOLOOT_FROM_LOOTLIST_NAME),
          tooltip = GetString(MT_AUTOLOOT_FROM_LOOTLIST_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.lootlist end,
          setFunc = function(value) MasterThief.SavedVarsOptions.lootlist = value end,
          width = "full",
    	},
    	{
          type = "checkbox",
          name = GetString(MT_PICKPOCKET_COUNTER_NAME),
          tooltip = GetString(MT_PICKPOCKET_COUNTER_TEXT),
          getFunc = function() return MasterThief.SavedVarsOptions.PickpocketCounterEnabled end,
          setFunc = function(value) MasterThief:SetPickpocketCounterEnabled(value) end,
          width = "full",
    	},		
    	{
			type = "submenu",
			name = GetString(MT_SUB_ANNOUNCE_NAME),
			tooltip = GetString(MT_SUB_ANNOUNCE_TEXT),	
			controls = {		
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_ONSCREENMSG_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_ONSCREENMSG_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.SpecialOnScreenMsg end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.SpecialOnScreenMsg = value end,
				  width = "full",
				},
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_SPECIALS_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_SPECIALS_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.SpecialChatMsg  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.SpecialChatMsg = value end,
				  width = "full",
				},		
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_REGULAR_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_REGULAR_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.RegularChatMsg  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.RegularChatMsg = value end,
				  width = "full",
				},		
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_USELESS_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_USELESS_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.AnnounceUselessItem  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.AnnounceUselessItem = value end,
				  width = "full",
				},
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_BECAREFUL_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_BECAREFUL_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.AnnounceBeCareful  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.AnnounceBeCareful = value end,
				  width = "full",
				},
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_KNOWN_RECIPES_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_KNOWN_RECIPES_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.AnnounceKnownRecipes  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.AnnounceKnownRecipes = value end,
				  width = "full",
				},
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_SELLS_TRANSFERS_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_SELLS_TRANSFERS_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.AnnounceSellsTransfers  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.AnnounceSellsTransfers = value end,
				  width = "full",
				},
				{
				  type = "checkbox",
				  name = GetString(MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_NAME),
				  tooltip = GetString(MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_TEXT),
				  getFunc = function() return MasterThief.SavedVarsOptions.AnnounceMaxFencerLimits  end,
				  setFunc = function(value) MasterThief.SavedVarsOptions.AnnounceMaxFencerLimits = value end,
				  width = "full",
				},				
			},
		},
		{
			type = "submenu",
			name = GetString(MT_COMP_MENU_SUBMENU_NAME),
			tooltip = GetString(MT_COMP_MENU_SUBMENU_TOOLTIP),
			controls = {
				{
					type = "checkbox",
					name = GetString(MT_COMP_MENU_WARN_NAME),
					tooltip = GetString(MT_COMP_MENU_WARN_TOOLTIP),
					getFunc = function() return MasterThief.SavedVarsOptions.CompanionWarnActions end,
					setFunc = function(value) MasterThief.SavedVarsOptions.CompanionWarnActions = value end,
					width = "full",
				},
				{
					type = "checkbox",
					name = GetString(MT_COMP_MENU_BLOCK_NAME),
					tooltip = GetString(MT_COMP_MENU_BLOCK_TOOLTIP),
					getFunc = function() return MasterThief.SavedVarsOptions.CompanionBlockActions end,
					setFunc = function(value) MasterThief.SavedVarsOptions.CompanionBlockActions = value end,
					width = "full",
				},
				{
					type = "checkbox",
					name = GetString(MT_COMP_MENU_AUTODISMISS_NAME),
					tooltip = GetString(MT_COMP_MENU_AUTODISMISS_TOOLTIP),
					getFunc = function() return MasterThief.SavedVarsOptions.CompanionAutoDismiss end,
					setFunc = function(value) MasterThief.SavedVarsOptions.CompanionAutoDismiss = value end,
					width = "full",
				},
			},
		},
	}
	LAM:RegisterOptionControls("MasterThiefOptions", optionsData)
end