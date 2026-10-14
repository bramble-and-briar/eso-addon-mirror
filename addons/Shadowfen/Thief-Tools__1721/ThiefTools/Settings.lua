--[[
Copyright (c) 2017 Dolores Scott
All rights reserved.
See LICENSE file for terms.
]]
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_TOGGLE', GetString(TT_BINDING_TOGGLE))
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_KILL_TOGGLE', GetString(TT_BINDING_KILL_TOGGLE))
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_AUTOSTEAL_TOGGLE', GetString(TT_BINDING_AUTOSTEAL_TOGGLE))
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_AUTOJUNK_TOGGLE', GetString(TT_BINDING_AUTOJUNK_TOGGLE))
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_LOCK_TOGGLE', GetString(TT_BINDING_LOCK_TOGGLE))
ZO_CreateStringId('SI_BINDING_NAME_THIEFTOOLS_METER_TOGGLE', GetString(TT_BINDING_METER_TOGGLE))

local TT = ThiefTools
local LAM = LibAddonMenu2
local SF = LibSFUtils

local color = SF.hex

local L = GetString


local itemChoices = TT.itemChoices
local qualityChoices = TT.qualityChoices

-- Define translation array
local ModeArray = TT.ModeArray
local QualityModeArray = TT.QualityModeArray

local function divider_full()
	return {
			type = "divider",
			width = "full", --or "half" (optional)
			height = 10,
			alpha = 0.5,
		}
end
local panelData = {
   type = "panel",
   name = TT.name,
	displayName = TT.displayName,
	author = TT.author,
	version = TT.version,
   slashCommand = "/tt.settings",
   registerForRefresh = true,
}

local filtersMenu = {   -- Stolen Items filters
	type = "submenu",
	name = SF.GetIconized(TT_FILTERS_NAME, color.gold),
	tooltip = TT_FILTERS,
	reference = "ThiefToolsFilterMenu",
	controls = {
		{
			type = "checkbox",
			name = SF.GetIconized(TT_AW_NAME,color.bronze),
			tooltip = TT_AW,
			getFunc = function() return TT.options.scope.isFilterAW end,
			setFunc = function(x)
				TT.options.scope.isFilterAW = x
				TT.setOptionsScope()
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end checkbox
		divider_full(),
		-- don't count junk
		{
			type = "checkbox",
			name = TT_NOJUNK_NAME,
			tooltip = TT_NOJUNK,
			getFunc = function() return TT.options.filter.nojunk end,
			setFunc = function(x)
				TT.options.filter.nojunk = x
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end checkbox
		-- ignore below value
		{
			type = "slider",
			name = TT_IGNORE_SCALE_NAME,
			tooltip = TT_IGNORE_SCALE,
			default = 0,
			min = 0,
			max = 200,
			step = 1,
			getFunc = function() return TT.options.filter.ignscale end,
			setFunc = function(x)
				TT.options.filter.ignscale = x
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end slider
		-- junk instead of ignore
		{
			type = "checkbox",
			name = TT_JUNK_INSTEAD_NAME,
			tooltip = TT_JUNK_INSTEAD,
			disable = function() if TT.options.filter.ignscale == 0 then return true end; return false end,
			getFunc = function() return TT.options.filter.autojunkbelow end,
			setFunc = function(x)
				TT.options.filter.autojunkbelow = x
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end checkbox
		-- never junk quality
		{
			type = "dropdown",
			name = TT_NEVER_JUNK_NAME,
			tooltip = TT_NEVER_JUNK,
			scrollable = false,
			choices = qualityChoices,
			getFunc = function() return QualityModeArray[TT.options.filter.never_junk_quality] end,
			setFunc = function(var)
				TT.options.filter.never_junk_quality = QualityModeArray[var]
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
			end,
			width = "full",
		},  -- end dropdown
		-- auto unjunk
		{
			type = "checkbox",
			name = TT_AUTO_UNJUNK,
			tooltip = TT_AUTO_UNJUNK_TT,
			getFunc = function() return TT.options.filter.unjunk end,
			setFunc = function(x)
				TT.options.filter.unjunk = x
			end,
		},  -- end checkbox
		{
			type = "header",
			name = TT_FILTERS_HEADER,
			width = "full",
		},
		{
			type = "description",
			text = TT_FILTER_DESC,
		},
		{
			type = "dropdown",
			name = TT_PROV_RECIPE_NAME,
			tooltip = TT_PROV_RECIPE,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_prov_recipe] end,
			setFunc = function(var)
				TT.options.filter.dest_prov_recipe = ModeArray[var]
				TT.set_recipe_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_FURN_RECIPE_NAME,
			tooltip = TT_FURN_RECIPE,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_furn_recipe] end,
			setFunc = function(var)
				TT.options.filter.dest_furn_recipe = ModeArray[var]
				TT.set_recipe_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_MOTIF_NAME,
			tooltip = TT_MOTIF,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_motif] end,
			setFunc = function(var)
				TT.options.filter.dest_motif = ModeArray[var]
				TT.set_motif_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",	
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_STYLE_NAME,
			tooltip = TT_STYLE,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_style] end,
			setFunc = function(var)
				TT.options.filter.dest_style = ModeArray[var]
				TT.set_style_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",	
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_TRAIT_NAME,
			scrollable = false,
			tooltip = TT_TRAIT,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_trait] end,
			setFunc = function(var)
				TT.options.filter.dest_trait = ModeArray[var]
				TT.set_trait_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",	
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_GEAR_NAME,
			tooltip = TT_GEAR,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_gear] end,
			setFunc = function(var)
				TT.options.filter.dest_gear = ModeArray[var]
				TT.set_gear_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_FENCE)], -- "Fence",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_JEWELRY_NM,
			tooltip = TT_JEWELRY,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_jewelry] end,
			setFunc = function(var)
				TT.options.filter.dest_jewelry = ModeArray[var]
				TT.set_jewelry_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_FURNITURE_NAME,
			tooltip = TT_FURNITURE,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_furnishing] end,
			setFunc = function(var)
				TT.options.filter.dest_furnishing = ModeArray[var]
				TT.set_furnishing_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_LOCKPICK_NAME,
			tooltip = TT_LOCKPICK,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_lockpick] end,
			setFunc = function(var)
				TT.options.filter.dest_lockpick = ModeArray[var]
				TT.set_lockpick_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_SOULGEM_NAME,
			tooltip = TT_SOULGEM,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_soulgem] end,
			setFunc = function(var)
				TT.options.filter.dest_soulgem = ModeArray[var]
				TT.set_soulgem_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_INGREDIENT_NAME,
			tooltip = TT_INGREDIENT,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() 
				return ModeArray[TT.options.filter.dest_ingredient] 
			end,
			setFunc = function(var)
				TT.options.filter.dest_ingredient = ModeArray[var]
				TT.set_ingredient_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_ALCH_SOLVENTS_NM,
			--tooltip = TT_INGREDIENT,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_alch_solvent] end,
			setFunc = function(var)
				TT.options.filter.dest_alch_solvent = ModeArray[var]
				TT.set_alch_solvent_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
		{
			type = "dropdown",
			name = TT_ALCH_REAGENTS_NM,
			tooltip = TT_ALCH_REAGENTS,
			scrollable = false,
			choices = itemChoices,
			getFunc = function() return ModeArray[TT.options.filter.dest_alch_reagent] end,
			setFunc = function(var)
				TT.options.filter.dest_alch_reagent = ModeArray[var]
				TT.set_alch_reagent_handler(TT.options.filter)
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
			default = ModeArray[L(TT_CHOICES_LAUNDER)], -- "Launder",
			width = "half",
		},  -- end dropdown
	},  -- end of controls
}  -- end of submenu - Stolen Items filters


local barMenu = {   -- Status Bar display settings
	type = "submenu",
	name = SF.GetIconized(TT_STATUSBAR_TITLE, color.gold),
	tooltip = TT_STATUSBAR_TITLE,
	controls = {
		{
			type = "checkbox",
			name = SF.GetIconized(TT_AW_NAME,color.bronze),
			tooltip = TT_AW,
			getFunc = function() return TT.options.scope.isBarAW end,
			setFunc = function(x)
				TT.options.scope.isBarAW = x
				TT.options.scope.isDynamicAW = x
				TT.setOptionsScope()
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end checkbox
		divider_full(),
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_ASSASSIN_NAME, nil, "/esoui/art/floatingmarkers/darkbrotherhood_target.dds", color.red),
			tooltip = TT_BAR_ASSASSIN,
			getFunc = function() return TT.options.show.Kill end,
			setFunc = function(x)
				TT.options.show.Kill = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_SNEAKSTEAL_NAME, nil, "/esoui/art/icons/item_generic_coinbag.dds", color.bronze),
			tooltip = TT_BAR_SNEAKSTEAL,
			getFunc = function() return TT.options.show.Loot end,
			setFunc = function(x)
				TT.options.show.Loot = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_GOLD_VALUE_NAME, nil, "/esoui/art/tutorial/guildstore_sell_tabicon_up.dds"),
			tooltip = TT_BAR_GOLD_VALUE,
			getFunc = function() return TT.options.show.Value end,
			setFunc = function(x)
				TT.options.show.Value = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_SELLS_NAME, nil, "/esoui/art/vendor/vendor_tabicon_sell_up.dds"),
			tooltip = TT_BAR_SELLS,
			getFunc = function() return TT.options.show.SellsLeft end,
			setFunc = function(x)
				TT.options.show.SellsLeft = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_LAUNDERS_NAME, nil, "/esoui/art/vendor/vendor_tabicon_sell_down.dds", color.red),
			tooltip = TT_BAR_LAUNDERS,
			getFunc = function() return TT.options.show.LaundersLeft end,
			setFunc = function(x)
				TT.options.show.LaundersLeft = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{ 
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_FENCE_RESET_NAME, nil, "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds", color.bronze),
			tooltip = TT_BAR_FENCE_RESET,
			getFunc = function() return TT.options.show.FenceTimer end,
			setFunc = function(x)
				TT.options.show.FenceTimer = x
				TT:UpdateControls()
			end,
		},
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_BOUNTY_CLOCK_NM, nil, "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds", "FF0000"),
			tooltip = TT_BAR_BOUNTY_CLOCK,
			getFunc = function() return TT.options.show.BountyTimer end,
			setFunc = function(x)
				TT.options.show.BountyTimer = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_BOUNTY_NAME, nil, "/esoui/art/currency/currency_gold.dds", color.red),
			tooltip = TT_BAR_BOUNTY,
			getFunc = function() return TT.options.show.Bounty end,
			setFunc = function(x)
				TT.options.show.Bounty = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{ 
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_CLEMENCY_RESET_NAME, nil, "/esoui/art/miscellaneous/gamepad/gp_icon_timer32.dds", color.fine),
			tooltip = TT_BAR_CLEMENCY_RESET,
			getFunc = function() return TT.options.show.ClemencyTimer end,
			setFunc = function(x)
				TT.options.show.ClemencyTimer = x
				TT:UpdateControls()
			end,
		},
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_AVE_VALUE_NM, nil, "/esoui/art/currency/currency_gold.dds",color.superior),
			tooltip = TT_BAR_AVE_VALUE,
			getFunc = function() return TT.options.show.Average end,
			setFunc = function(x)
				TT.options.show.Average = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_EST_PROFIT_NM, nil, "/esoui/art/vendor/vendor_tabicon_sell_down.dds", color.legendary),
			tooltip = TT_BAR_EST_PROFIT,
			getFunc = function() return TT.options.show.Estimate end,
			setFunc = function(x)
				TT.options.show.Estimate = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = SF.GetIconized(TT_BAR_AVE_QUAL_NM, nil, "/esoui/art/crafting/smithing_tabicon_improve_up.dds"),
			tooltip = TT_BAR_AVE_QUAL,
			getFunc = function() return TT.options.show.Quality end,
			setFunc = function(x)
				TT.options.show.Quality = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = L(TT_BAR_QUAL_GRAPH_NM),
			tooltip = TT_BAR_QUAL_GRAPH,
			getFunc = function() return TT.options.show.QualityBars end,
			setFunc = function(x)
				TT.options.show.QualityBars = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "header",
			name = TT_METER_NAME,
			width = "full",
		},
		{
			type = "description",
			text = TT_METER_DESC,
		},
		{
			type = "checkbox",
			name = TT_METER_HIDE_NAME,
			tooltip = TT_METER_HIDE,
			getFunc = function() return TT.options.display.hideMeter end,
			setFunc = function(x)
				TT.options.display.hideMeter = x
				TT:SavePosition()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_METER_DYNAMIC_NM,
			tooltip = TT_METER_DYNAMIC,
			getFunc = function() return TT.options.dshow.Bounty end,
			setFunc = function(x)
				TT.options.dshow.Bounty = x
				TT.options.dshow.BountyTimer = x
				if x then
					TT:DynamicBountyCheck()
				else
					TT:UpdateControls()
				end
			end,
		},  -- end checkbox
	},  -- end of controls
}  -- end of submenu - Status bar display settings

local warnMenu = {
	type = "submenu",
	name = SF.GetIconized(TT_WARNINGS_NAME, color.gold),
	tooltip = TT_WARNINGS,
	controls = {
		{
			type = "checkbox",
			name = SF.GetIconized(TT_AW_NAME,color.bronze),
			tooltip = TT_AW,
			getFunc = function() return TT.options.scope.isWarnAW end,
			setFunc = function(x)
				TT.options.scope.isWarnAW = x
				TT.setOptionsScope()
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
			end,
		},  -- end checkbox
		divider_full(),
		{
			type = "slider",
			name = TT_FENCESLOTS_NAME,
			tooltip = TT_FENCESLOTS,
			min = 0,
			max = 20,
			step = 1,
			default = 0,
			getFunc = function() return TT.options.warns.fenceleft end,
			setFunc = function(x)
				TT.options.warns.fenceleft = x
				TT:checkFenceSlotsWarning(INVENTORY_BACKPACK)
			end,
		},  -- end checkbox
	    {
			type = "slider",
			name = TT_SLOTSLEFT_NAME,
			tooltip = TT_SLOTSLEFT,
			min = 0,
			max = 20,
			step = 1,
			default = 0,
			getFunc = function() return TT.options.warns.slotsleft end,
			setFunc = function(x)
				TT.options.warns.slotsleft = x
				TT:checkFreeSlotsWarning(INVENTORY_BACKPACK)
			end,
			requiresReload = false,
		},  -- end slider
	},  -- end of controls
} -- end of submenu - Warnings
	
local displayMenu = {   -- Display Submenu
	type = "submenu",
	name = SF.GetIconized(TT_DISPLAY_NAME, color.bronze),
	tooltip = TT_DISPLAY,
	controls = {
		{
			type = "checkbox",
			name = TT_LOCKUI_NAME,
			tooltip = TT_LOCKUI,
			getFunc = function() return TT.options.display.locked end,
			setFunc = function(x)
				TT.options.display.locked = x
				TT:lockWindow()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_AUTO_LOCK_NAME,
			tooltip = TT_AUTO_LOCK,
			getFunc = function() return TT.options.display.autoLock end,
			setFunc = function(x)
				TT.options.display.autoLock = x
				TT:SavePosition()
			end,
		},  -- end checkbox
		{
			type = "header",
			name = TT_SECTION_DISP_NM,
			width = "full",
		},
		{
			type = "description",
			text = TT_SECTION_DISP,
		},
		{
			type = "slider",
			name = TT_SCALE_NAME,
			tooltip = TT_SCALE_NAME,
			min = 75,
			max = 200,
			step = 1,
			getFunc = function() return TT.options.display.scale*100 end,
			setFunc = function(x)
				TT.options.display.scale = x/100
				TT.window:SetScale(1)
				TT:UpdateControls()
				TT.window:SetScale(x/100)
			end,
			requiresReload = true,
		},  -- end slider
		{
			type = "checkbox",
			name = TT_BACKGROUND_NAME,
			tooltip = TT_BACKGROUND,
			getFunc = function() return TT.options.show.Background end,
			setFunc = function(x)
				TT.options.show.Background = x
				TT:UpdateControls()
			end,
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_MENUS_NAME,
			tooltip = TT_HIDE_IN_MENUS,
			getFunc = function() return TT.options.display.hide_on_menu end,
			setFunc = function(x)
				TT.options.display.hide_on_menu = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_IA_NAME,
			tooltip = TT_HIDE_IN_IA,
			default = true,
			getFunc = function() return TT.options.display.hide_on_IA end,
			setFunc = function(x)
				TT.options.display.hide_on_IA = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_DUNG_NAME,
			tooltip = TT_HIDE_IN_DUNG,
			default = true,
			getFunc = function() return TT.options.display.hide_on_Dung end,
			setFunc = function(x)
				TT.options.display.hide_on_Dung = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_TRIAL_NAME,
			tooltip = TT_HIDE_IN_TRIAL,
			default = true,
			getFunc = function() return TT.options.display.hide_on_Trial end,
			setFunc = function(x)
				TT.options.display.hide_on_Trial = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_ARENA_NAME,
			tooltip = TT_HIDE_IN_ARENA,
			default = true,
			getFunc = function() return TT.options.display.hide_on_Arena end,
			setFunc = function(x)
				TT.options.display.hide_on_Arena = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
		{
			type = "checkbox",
			name = TT_HIDE_IN_PUBDGN_NAME,
			tooltip = TT_HIDE_IN_PUBDGN,
			default = true,
			getFunc = function() return TT.options.display.hide_on_PublicDungeon end,
			setFunc = function(x)
				TT.options.display.hide_on_PublicDungeon = x
				TT.window:SetHidden(x)
			end
		},  -- end checkbox
	},  -- end controls
}  -- end submenu Display
    
local charSection = {
    {
        type = "header",
        name = SF.GetIconized(WMGH_GUILDS_SECTION_NM, color.gold), -- or string id or function returning a string
        width = "full", --or "half" (optional)
    },
    {
        type = "checkbox",
        name = L(TT_NOT_THIEF), -- or string id or function returning a string
        getFunc = function() return TT.options.chartt.not_thief end,
        setFunc = function(value) 
            TT.options.chartt.not_thief = value 
            local w = TT.window

            TT.options.display.hidden = value
            --w:SetHidden(not value)
			w:SetHidden(value)

			TT:CalcStolenGoods()
			TT:UpdateDisplay()
			TT:UpdateControls()          
        end,
        tooltip = L(TT_NOT_THIEF_TT),
        width = "full", -- or "half" (optional)
    },
    divider_full(),
}
    
local optionsTable = {
    {
        type = "checkbox",
        name = L(TT_NOT_THIEF), -- or string id or function returning a string
        getFunc = function() return TT.options.chartt.not_thief end,
        setFunc = function(value) 
            TT.options.chartt.not_thief = value 
            local w = TT.window

            if not value then
				TT:CalcStolenGoods()
				TT:UpdateDisplay()
				TT:UpdateControls()
            end

            TT.options.display.hidden = not value
            --w:SetHidden(value)
			w:SetHidden(value)
        end,
        tooltip = L(TT_NOT_THIEF_TT),
        width = "full", -- or "half" (optional)
    },
    divider_full(),
    filtersMenu,
    barMenu,
    warnMenu,
-- 
    displayMenu
}   -- end optionsTable

function TT:RegisterSettings()
   LAM:RegisterAddonPanel("ThiefToolsOptions", panelData)
   LAM:RegisterOptionControls("ThiefToolsOptions", optionsTable)
end
