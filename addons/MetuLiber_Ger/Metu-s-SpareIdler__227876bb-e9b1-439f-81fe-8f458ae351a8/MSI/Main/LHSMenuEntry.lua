-- LHSMenuEntry.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

function MSI.InitLHSLibrary()
	MSI.LHS = LibHarvensAddonSettings
	if not MSI.LHS then
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LHS_FAILURE)))
	else
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LHS_SUCCESS)))
	end
end

function MSI.InitLHSMenuPanel()
	if not MSI.LHS then return end

	--************--
	-- Menu Panel
	local optionsTable = MSI.LHS:AddAddon("SpareIdlerOptionsMenu", {
		type = "panel",
		label = GetString(MSI_GAME_MENU_PANEL_LABEL),
		displaylabel = GetString(MSI_GAME_MENU_PANEL_NAME),
		author = "|c990000"..MSI.Author.."|r",
		version = "|cEFEBBE"..MSI.Version.."|r",
		allowRefresh = true,
		allowDefaults = true,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_ADDON_DESCR_ICON)..GetString(MSI_MENU_ADDON_DESCR_TITLE),
		tooltip = GetString(MSI_MENU_ADDON_DESCR_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_ADDON_DESCR_SUMMARY),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--************************--
	-- Allgemeine Einstellung
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_MAIN_OPTIONS_ICON)..GetString(MSI_MENU_MAIN_OPTIONS_TITLE),
		tooltip = GetString(MSI_MENU_MAIN_OPTIONS_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_ADDON_STATE_ICON)..GetString(MSI_TGL_ADDON_STATE_TITLE),
		tooltip = GetString(MSI_TGL_ADDON_STATE_TOOLTIP),
		getFunction = function() return MSI.SVars.IsMSIActive end,
		setFunction = function(value) MSI.SVars.IsMSIActive = value end,
		default = true,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_ACCOUNT_TITLE),
		tooltip = GetString(MSI_TGL_ACCOUNT_TOOLTIP),
		getFunction = function() return MSI.SVars.IsAccountWide end,
		setFunction = function(value) MSI.SVars.IsAccountWide = value 
			MSI.SwitchSavedVars(value) 
			--ReloadUI("ingame") 
			end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_MENU_LIBRARY_ICON)..GetString(MSI_TGL_MENU_LIBRARY_TITLE),
		tooltip = GetString(MSI_TGL_LHS_LIBRARY_TOOLTIP),
		getFunction = function() return MSI.SVars.IsMSIUseLAM end,
		setFunction = function(value) MSI.SVars.IsMSIUseLAM = value 
			ReloadUI("ingame") end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--*************************--
	-- Essentielle Komponenten
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_PRCTCL_FNCTNL_TITLE),
		tooltip = GetString(MSI_MENU_PRCTCL_FNCTNL_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_BOOK_INHIBITER_TITLE),
		tooltip = GetString(MSI_TGL_BOOK_INHIBITER_TOOLTIP),
		getFunction = function() return MSI.SVars.IsBookInhibit end,
		setFunction = function(value) MSI.SVars.IsBookInhibit = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_LAWFUL_BEHAVE_TITLE),
		tooltip = GetString(MSI_TGL_LAWFUL_BEHAVE_TOOLTIP),
		getFunction = function() return MSI.SVars.IsLawfulBehave end,
		setFunction = function(value) MSI.SVars.IsLawfulBehave = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--***********************--
	-- Komfortable Assistenz
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_CMFRT_ASSIST_TITLE),
		tooltip = GetString(MSI_MENU_CMFRT_ASSIST_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_LYCAN_STATE_TITLE),
		tooltip = GetString(MSI_TGL_LYCAN_STATE_TOOLTIP),
		getFunction = function() return MSI.SVars.IsLycanStatus end,
		setFunction = function(value) MSI.SVars.IsLycanStatus = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_RED_HINT_RETICLE_TITLE),
		tooltip = GetString(MSI_TGL_RED_HINT_RETICLE_TOOLTIP),
		getFunction = function() return MSI.SVars.IsDisputeReticle end,
		setFunction = function(value) MSI.SVars.IsDisputeReticle = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_BOLT_UNLOCK_TITLE),
		tooltip = GetString(MSI_TGL_BOLT_UNLOCK_TOOLTIP),
		getFunction = function() return MSI.SVars.IsLockcrackClue end,
		setFunction = function(value) MSI.SVars.IsLockcrackClue = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--***************************--
	-- Beansruchbare Forderungen
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_FLFLLBL_RCVBLS_TITLE),
		tooltip = GetString(MSI_MENU_FLFLLBL_RCVBLS_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_CLAIM_TOME_TITLE),
		tooltip = GetString(MSI_TGL_CLAIM_TOME_TOOLTIP),
		getFunction = function() return MSI.SVars.IsClaimTomePoints end,
		setFunction = function(value) MSI.SVars.IsClaimTomePoints = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_CLAIM_GPRSTS_TITLE),
		tooltip = GetString(MSI_TGL_CLAIM_GPRSTS_TOOLTIP),
		getFunction = function() return MSI.SVars.IsCaimPursuitPts end,
		setFunction = function(value) MSI.SVars.IsCaimPursuitPts = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_HIRELING_MAILS_TITLE),
		tooltip = GetString(MSI_TGL_HIRELING_MAILS_TOOLTIP),
		getFunction = function() return MSI.SVars.IsHirelingMail end,
		setFunction = function(value) MSI.SVars.IsHirelingMail = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--***********************--
	-- Bequemes | Unbequemes
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_CNVNT_UNCNVNT_TITLE),
		tooltip = GetString(MSI_MENU_CNVNT_UNCNVNT_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SKIP_DIALOG_TITLE),
		tooltip = GetString(MSI_TGL_SKIP_DIALOG_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSkipDialogs end,
		setFunction = function(value) MSI.SVars.IsSkipDialogs = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SKIP_IMPORTANT_TITLE),
		tooltip = GetString(MSI_TGL_SKIP_IMPORTANT_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSkipImportant end,
		setFunction = function(value) MSI.SVars.IsSkipImportant = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_USE_COST_DETECT_TITLE),
		tooltip = GetString(MSI_TGL_USE_COST_DETECT_TOOLTIP),
		getFunction = function() return MSI.SVars.IsCostDetection end,
		setFunction = function(value) MSI.SVars.IsCostDetection = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_HARDMODE_DETECT_TITLE),
		tooltip = GetString(MSI_TGL_HARDMODE_DETECT_TOOLTIP),
		getFunction = function() return MSI.SVars.IsHardModeDetect end,
		setFunction = function(value) MSI.SVars.IsHardModeDetect = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--***********************--
	-- Praktische Helferlein
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_PRCTCL_HELPER_TITLE),
		tooltip = GetString(MSI_MENU_PRCTCL_HELPER_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SELL_ALL_JUNK_TITLE),
		tooltip = GetString(MSI_TGL_SELL_ALL_JUNK_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSellALLJunk end,
		setFunction = function(value)
			MSI.SVars.IsSellALLJunk = value
			if value then
				MSI.SVars.IsSellPoison = not value
				MSI.SVars.IsSellOrnJewel = not value
			else
				MSI.SVars.IsSellPoison = value
				MSI.SVars.IsSellOrnJewel = value
			end
		end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SELL_ORN_JEWEL_TITLE),
		tooltip = GetString(MSI_TGL_SELL_ORN_JEWEL_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSellOrnJewel end,
		setFunction = function(value) MSI.SVars.IsSellOrnJewel = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSellALLJunk end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SELL_POISONS_TITLE),
		tooltip = GetString(MSI_TGL_SELL_POISONS_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSellPoison end,
		setFunction = function(value) MSI.SVars.IsSellPoison = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSellALLJunk end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_SELL_STLN_JUNK_TITLE),
		tooltip = GetString(MSI_TGL_SELL_STLN_JUNK_TOOLTIP),
		getFunction = function() return MSI.SVars.IsSellStolenJunk end,
		setFunction = function(value) MSI.SVars.IsSellStolenJunk = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_LAUNDER_STOLEN_TITLE),
		tooltip = GetString(MSI_TGL_LAUNDER_SOTLEN_TOOLTIP),
		getFunction = function() return MSI.SVars.IsLaunderStolen end,
		setFunction = function(value) MSI.SVars.IsLaunderStolen = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--*********************--
	-- Hilfreiche Routinen
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_APPROP_RTINS_TITLE),
		tooltip = GetString(MSI_MENU_APPROP_RTINS_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_FILLET_FISH_TITLE),
		tooltip = GetString(MSI_TGL_FILLET_FISH_TOOLTIP),
		getFunction = function() return MSI.SVars.IsFilletFish end,
		setFunction = function(value) MSI.SVars.IsFilletFish = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_LEARN_CLLCTBL_TITLE),
		tooltip = GetString(MSI_TGL_LEARN_CLLCTBL_TOOLTIP),
		getFunction = function() return MSI.SVars.IsLearnCllctbl end,
		setFunction = function(value) MSI.SVars.IsLearnCllctbl = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_BIND_SETS_TITLE),
		tooltip = GetString(MSI_TGL_BIND_SETS_TOOLTIP),
		getFunction = function() return MSI.SVars.IsBindSetParts end,
		setFunction = function(value) MSI.SVars.IsBindSetParts = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_UNRLL_TRSUREMAP_TITLE),
		tooltip = GetString(MSI_TGL_UNRLL_TRSUREMAP_TOOLTIP),
		getFunction = function() return MSI.SVars.IsUnrollTrsrMap end,
		setFunction = function(value) MSI.SVars.IsUnrollTrsrMap = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_OPEN_ALL_CONTI_TITLE),
		tooltip = GetString(MSI_TGL_OPEN_ALL_CONTI_TOOLTIP),
		getFunction = function() return MSI.SVars.IsOpenContainer end,
		setFunction = function(value) MSI.SVars.IsOpenContainer = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_OPEN_UNOPND_TITLE),
		tooltip = GetString(MSI_TGL_OPEN_UNOPND_TOOLTIP),
		getFunction = function() return MSI.SVars.IsOpenUnopened end,
		setFunction = function(value) MSI.SVars.IsOpenUnopened = value end,
		default = true,
		disable = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--********************--
	-- Zweckmäßge Aspekte
	optionsTable:AddSetting({
		type = MSI.LHS.ST_LABEL,
		label = GetString(MSI_MENU_EXPDNT_ASPCTS_TITLE),
		tooltip = GetString(MSI_MENU_EXPDNT_ASPCTS_TOOLTIP),
	})
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_CHATLOG_MODE_TITLE),
		tooltip = GetString(MSI_TGL_CHATLOG_MODE_TOOLTIP),
		getFunction = function() return MSI.SVars.IsChatLog end,
		setFunction = function(value) MSI.SVars.IsChatLog = value end,
		default = false,
		disable = function() return not MSI.SVars.IsMSIActive or MSI.SVars.IsDebugLog end,
	})
	if GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc) then else
	--*************************--
	-- DEVELOPER BEREICH Start
	--*************************--
	optionsTable:AddSetting({
		type = MSI.LHS.ST_CHECKBOX,
		label = GetString(MSI_TGL_DEBUG_LOG_TITLE),
		tooltip = GetString(MSI_TGL_DEBUG_LOG_TOOLTIP),
		getFunction = function() return MSI.SVars.IsDebug end,
		setFunction = function(value)
			MSI.SVars.IsDebug = value
			if value then MSI.SVars.IsChatLog = not value else MSI.SVars.IsChatLog = value end
		end,
		default = false,
		disable = function()
			return not MSI.SVars.IsMSIActive or
				(GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc))
		end,
	})
	--************************--
	-- DEVELOPER BEREICH ENDE
	--************************--
	end
		
	if GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc) then else
	--*************************--
	-- DEVELOPER BEREICH Start
	--*************************--
		optionsTable:AddSetting({
			type = MSI.LHS.ST_LABEL,
			label = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
		})
		optionsTable:AddSetting({
			type = MSI.LHS.ST_BUTTON,
			label = GetString(MSI_BTN_UNRLL_TRSUREMAP_TITLE),
			tooltip = GetString(MSI_BTN_UNRLL_TRSUREMAP_TOOLTIP),
			clickHandler = function(control) MSI.UnrollRolledTreasureMap() end,
			disable = function() return not MSI.SVars.IsMSIActive end,
		})
		optionsTable:AddSetting({
			type = MSI.LHS.ST_SLIDER,
			label = GetString(MSI_OPT_VAL_SLDR_ONE_TITLE),
			tooltip = GetString(MSI_OPT_VAL_SLDR_ONE_TOOLTIP),
			min = 1,
			max = 7,
			step = 1,
			format = "%.0f", -- No decimal places
			unit = " Schritte",
			getFunction = function() return MSI.SVars.ValNameSliderOne end,
			setFunction = function(value) MSI.SVars.ValNameSliderOne = math.max(0, value)
				MSI.ValNameSliderOne()
			end,
			default = 3,
			readOnly = false,
			disable = function() return not MSI.SVars.IsMSIActive end,
		})
		optionsTable:AddSetting({
			type = MSI.LHS.ST_SLIDER,
			label = GetString(MSI_OPT_VAL_SLDR_TWO_TITLE),
			tooltip = GetString(MSI_OPT_VAL_SLDR_TWO_TOOLTIP),
			min = 0,
			max = 1,
			step = 0.01,
			format = "%.2f",
			unit = "%",
			getFunction = function() return MSI.SVars.ValNameSliderTwo end,
			setFunction = function(value) MSI.SVars.ValNameSliderTwo = math.max(0, value)
				MSI.ValNameSliderTwo()
			end,
			default = 0.07,
			readOnly = false,
			disable = function() return not MSI.SVars.IsMSIActive end,
		})
		-- optionsTable:AddSetting({
		-- type = MSI.LHS.ST_EDIT,
		-- label = "Character Name",
		-- tooltip = "Gib Main-Character Name ein",
		-- textType = TEXT_TYPE_NUMERIC,
		-- maxChars = 10,
		-- getFunction = function() return MSI.SVars.optCharacterName end,
		-- setFunction = function(value) MSI.SVars.optCharacterName = value end,
		-- default = "",
		-- disable = function() return not MSI.SVars.IsMSIActive end,
		-- })
	--************************--
	-- DEVELOPER BEREICH ENDE
	--************************--
	end
end
-- eof