-- LAMMenuEntry.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

function MSI.InitLAMLibrary()
	MSI.LAM = LibAddonMenu2
	if not MSI.LAM then
		MSI.Print("c", string.format("%s", GetString(MSI_LOAD_LIB_LAM_FAILURE)))
	else
		MSI.Print("c", string.format("%s", GetString(MSI_LOAD_LIB_LAM_SUCCESS)))
	end
end

function MSI.InitLAMMenuPanel()
	if not MSI.LAM then return end

	--************--
	-- Menu Panel
	local panelData = {
		type = "panel",
		name = GetString(MSI_GAME_MENU_PANEL_LABEL),
		displayName = ZO_HIGHLIGHT_TEXT:Colorize(GetString(MSI_GAME_MENU_PANEL_LABEL)),--GetString(MSI_GAME_MENU_PANEL_NAME),
		author = "|c990000"..MSI.Author.."|r",
		version = "|cEFEBBE"..MSI.Version.."|r",
		website = GetString(MSI_MENU_ADDON_WEB_LINK_URL),
     	registerForRefresh = true,
		registerForDefaults = true,
    }

	local optionsData = setmetatable({}, { __index = table })
	--********************--
	-- AddOn Beschreibung
	optionsData:insert({
		type = "description",
		title = GetString(MSI_MENU_ADDON_DESCR_ICON),
	})
	optionsData:insert({
		type = "button",
		name = GetString(MSI_MENU_ADDON_DESCR_TITLE),
		tooltip = GetString(MSI_MENU_ADDON_DESCR_TOOLTIP).."\n\n"..GetString(MSI_MENU_ADDON_DESCR_CHATCMD),
		reference = "MSIDescriptionRef",
		func = function() RequestOpenUnsafeURL(GetString(MSI_MENU_ADDON_WEB_LINK_URL)) end,
	})
	optionsData:insert({
		type = "description",
		title = GetString(MSI_MENU_ADDON_DESCR_SUMMARY),
		text = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--************************--
	-- Allgemeine Einstellung
	optionsData:insert({
		type = "description",
		title = GetString(MSI_MENU_MAIN_OPTIONS_ICON)..GetString(MSI_MENU_MAIN_OPTIONS_TITLE),
		tooltip = GetString(MSI_MENU_MAIN_OPTIONS_TOOLTIP),
		reference = "MSIAddonOptionsRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsData:insert({
		type = "checkbox",
		name = GetString(MSI_TGL_ADDON_STATE_ICON)..GetString(MSI_TGL_ADDON_STATE_TITLE),
		tooltip = GetString(MSI_TGL_ADDON_STATE_TOOLTIP),
		reference = "MSIAddonStateRef",
		getFunc = function() return MSI.SVars.IsMSIActive end,
		setFunc = function(value) MSI.SVars.IsMSIActive = value 
			MSI.InitModuleEvents() end,
		default = true,
		disabled = false,
	})
	optionsData:insert({
		type = "checkbox",
		name = GetString(MSI_TGL_ACCOUNT_TITLE),
		tooltip = GetString(MSI_TGL_ACCOUNT_TOOLTIP),
		reference = "MSIAccountWideRef",
		getFunc = function() return MSI.SVars.IsAccountWide end,
		setFunc = function(value) MSI.SVars.IsAccountWide = value 
			MSI.SwitchSavedVars(value) 
			--ReloadUI("ingame")
			--CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", MSI.SettingPanel)
			end,
		default = false,
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})

	if GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc) then 
	else--*********************--
	-- DEVELOPER BEREICH START
	--*************************--
	optionsData:insert({
		type = "checkbox",
		name = GetString(MSI_TGL_MENU_LIBRARY_ICON)..GetString(MSI_TGL_MENU_LIBRARY_TITLE),
		tooltip = GetString(MSI_TGL_LAM_LIBRARY_TOOLTIP),
		reference = "MSIUseLAMLibraryRef",
		getFunc = function() return MSI.SVars.IsMSIUseLAM end,
		setFunc = function(value) MSI.SVars.IsMSIUseLAM = value 
			ReloadUI("ingame") end,
		default = true,
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})
	end--*********************--
	-- DEVELOPER BEREICH ENDE
	--************************--
	optionsData:insert({
		type = "description",
		title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
	--*************************--
	-- Essentielle Komponenten
	optionsData:insert({
		type = "description",
		title = GetString(MSI_MENU_PRCTCL_FNCTNL_TITLE),
		tooltip = GetString(MSI_MENU_PRCTCL_FNCTNL_TOOLTIP),
		reference = "MSIEssentiellRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsData:insert({
		type = "checkbox",
		name = GetString(MSI_TGL_BOOK_INHIBITER_TITLE),
		tooltip = GetString(MSI_TGL_BOOK_INHIBITER_TOOLTIP),
		reference = "MSIBookInhibitRef",
		getFunc = function() return MSI.SVars.IsBookInhibit end,
		setFunc = function(value) MSI.SVars.IsBookInhibit = value end,
		default = true,
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsData:insert({
		type = "checkbox",
		name = GetString(MSI_TGL_LAWFUL_BEHAVE_TITLE),
		tooltip = GetString(MSI_TGL_LAWFUL_BEHAVE_TOOLTIP),
		reference = "MSILawFulBehaveRef",
		getFunc = function() return MSI.SVars.IsLawfulBehave end,
		setFunc = function(value) MSI.SVars.IsLawfulBehave = value end,
		default = false,
		disabled = function() return not MSI.SVars.IsMSIActive end,
	})
	optionsData:insert({
		type = "description",
		title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	})
			--***********************--
			-- Komfortable Assistenz
			local assistanceSubData = setmetatable({}, { __index = table })
			assistanceSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_CMFRT_ASSIST_TITLE),
				tooltip = GetString(MSI_MENU_CMFRT_ASSIST_TOOLTIP),
				reference = "MSIAssistanceRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			assistanceSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_LYCAN_STATE_TITLE),
				tooltip = GetString(MSI_TGL_LYCAN_STATE_TOOLTIP),
				reference = "MSIIsLycanStatusRef",
				getFunc = function() return MSI.SVars.IsLycanStatus end,
				setFunc = function(value) MSI.SVars.IsLycanStatus = value 
					MSI.InitModLycanStatus() end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			assistanceSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_RED_HINT_RETICLE_TITLE),
				tooltip = GetString(MSI_TGL_RED_HINT_RETICLE_TOOLTIP),
				reference = "MSIIsDisputeReticleRef",
				getFunc = function() return MSI.SVars.IsDisputeReticle end,
				setFunc = function(value) MSI.SVars.IsDisputeReticle = value 
					MSI.InitModDisputeReticle() end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			assistanceSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_BOLT_UNLOCK_TITLE),
				tooltip = GetString(MSI_TGL_BOLT_UNLOCK_TOOLTIP),
				reference = "MSILockcrackClueRef",
				getFunc = function() return MSI.SVars.IsLockcrackClue end,
				setFunc = function(value) MSI.SVars.IsLockcrackClue = value 
					MSI.InitModLockcrackClue() end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_CMFRT_ASSIST_STITLE),
		tooltip = GetString(MSI_MENU_CMFRT_ASSIST_TOOLTIP),
		reference = "MSIAssistanceSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = assistanceSubData
	})

	-- optionsData:insert({
		-- type = "description",
		-- title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	-- })
			--***************************--
			-- Beansruchbare Forderungen
			local receivablesSubData = setmetatable({}, { __index = table })
			receivablesSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_FLFLLBL_RCVBLS_TITLE),
				tooltip = GetString(MSI_MENU_FLFLLBL_RCVBLS_TOOLTIP),
				reference = "MSIReceivablesRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			receivablesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_CLAIM_TOME_TITLE),
				tooltip = GetString(MSI_TGL_CLAIM_TOME_TOOLTIP),
				reference = "MSIClainTomeRef",
				getFunc = function() return MSI.SVars.IsClaimTomePoints end,
				setFunc = function(value) MSI.SVars.IsClaimTomePoints = value 
					MSI.InitModClaimTomePoints() end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			receivablesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_CLAIM_GPRSTS_TITLE),
				tooltip = GetString(MSI_TGL_CLAIM_GPRSTS_TOOLTIP),
				reference = "MSICaimPursuitRef",
				getFunc = function() return MSI.SVars.IsCaimPursuitPts end,
				setFunc = function(value) MSI.SVars.IsCaimPursuitPts = value 
					MSI.InitModCaimPursuitPoints() end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			receivablesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_HIRELING_MAILS_TITLE),
				tooltip = GetString(MSI_TGL_HIRELING_MAILS_TOOLTIP),
				reference = "MSIHirelingMailRef",
				getFunc = function() return MSI.SVars.IsHirelingMail end,
				setFunc = function(value) MSI.SVars.IsHirelingMail = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_FLFLLBL_RCVBLS_STITLE),
		tooltip = GetString(MSI_MENU_FLFLLBL_RCVBLS_TOOLTIP),
		reference = "MSIReceivablesSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = receivablesSubData
	})

	-- optionsData:insert({
		-- type = "description",
		-- title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	-- })
			--***********************--
			-- Bequemes | Unbequemes
			local convUnconvSubData = setmetatable({}, { __index = table })
			convUnconvSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_CNVNT_UNCNVNT_TITLE),
				tooltip = GetString(MSI_MENU_CNVNT_UNCNVNT_TOOLTIP),
				reference = "MSIConvUnconvRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			convUnconvSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SKIP_DIALOG_TITLE),
				tooltip = GetString(MSI_TGL_SKIP_DIALOG_TOOLTIP),
				reference = "MSISkipDialogsRef",
				getFunc = function() return MSI.SVars.IsSkipDialogs end,
				setFunc = function(value) MSI.SVars.IsSkipDialogs = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			convUnconvSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SKIP_IMPORTANT_TITLE),
				tooltip = GetString(MSI_TGL_SKIP_IMPORTANT_TOOLTIP),
				reference = "MSISkipImportantRef",
				getFunc = function() return MSI.SVars.IsSkipImportant end,
				setFunc = function(value) MSI.SVars.IsSkipImportant = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
			})
			convUnconvSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_USE_COST_DETECT_TITLE),
				tooltip = GetString(MSI_TGL_USE_COST_DETECT_TOOLTIP),
				reference = "MSIUseCostDetectRef",
				getFunc = function() return MSI.SVars.IsCostDetection end,
				setFunc = function(value) MSI.SVars.IsCostDetection = value end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
			})
			convUnconvSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_HARDMODE_DETECT_TITLE),
				tooltip = GetString(MSI_TGL_HARDMODE_DETECT_TOOLTIP),
				reference = "MSIHardModeDetectRef",
				getFunc = function() return MSI.SVars.IsHardModeDetect end,
				setFunc = function(value) MSI.SVars.IsHardModeDetect = value end,
				requiresReload = false,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
			})
			convUnconvSubData:insert({
				type = "editbox",
				name = MSI_LST_BLCKLST_KEYWRDS_TITLE,
				tooltip = MSI_LST_BLCKLST_KEYWRDS_TOOLTIP,
				reference = "MSIKeyWordBlackListRef",
				getFunc = function() return table.concat(MSI.SVars.KeyWordBlackList or {}, "\n") end,
				setFunc = function(value)
				local list = {}
				for line in string.gmatch(value, "[^\r\n]+") do
					table.insert(list, line)
				end
					MSI.SVars.KeyWordBlackList = list
				end,
				isMultiline = true,
				default = "writ\nauftrag\ncommande",
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSkipDialogs end,
			})

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_CNVNT_UNCNVNT_STITLE),
		tooltip = GetString(MSI_MENU_CNVNT_UNCNVNT_TOOLTIP),
		reference = "MSIConvUnconvSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = convUnconvSubData
	})

	-- optionsData:insert({
		-- type = "description",
		-- title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	-- })
			--***********************--
			-- Praktische Helferlein
			local practicalHelperSubData = setmetatable({}, { __index = table })
			practicalHelperSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_PRCTCL_HELPER_TITLE),
				tooltip = GetString(MSI_MENU_PRCTCL_HELPER_TOOLTIP),
				reference = "MSIPracticalHelperRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			practicalHelperSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SELL_ALL_JUNK_TITLE),
				tooltip = GetString(MSI_TGL_SELL_ALL_JUNK_TOOLTIP),
				reference = "MSISellJunkRef",
				getFunc = function() return MSI.SVars.IsSellALLJunk end,
				setFunc = function(value)
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
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			practicalHelperSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SELL_ORN_JEWEL_TITLE),
				tooltip = GetString(MSI_TGL_SELL_ORN_JEWEL_TOOLTIP),
				reference = "MSISellOrnateJewelRef",
				getFunc = function() return MSI.SVars.IsSellOrnJewel end,
				setFunc = function(value) MSI.SVars.IsSellOrnJewel = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSellALLJunk end,
			})
			practicalHelperSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SELL_POISONS_TITLE),
				tooltip = GetString(MSI_TGL_SELL_POISONS_TOOLTIP),
				reference = "MSISellPoisonRef",
				getFunc = function() return MSI.SVars.IsSellPoison end,
				setFunc = function(value) MSI.SVars.IsSellPoison = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive or not MSI.SVars.IsSellALLJunk end,
			})
			practicalHelperSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_SELL_STLN_JUNK_TITLE),
				tooltip = GetString(MSI_TGL_SELL_STLN_JUNK_TOOLTIP),
				reference = "MSISellStolenJunkRef",
				getFunc = function() return MSI.SVars.IsSellStolenJunk end,
				setFunc = function(value) MSI.SVars.IsSellStolenJunk = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			practicalHelperSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_LAUNDER_STOLEN_TITLE),
				tooltip = GetString(MSI_TGL_LAUNDER_SOTLEN_TOOLTIP),
				reference = "MSILaunderStolenJunkRef",
				getFunc = function() return MSI.SVars.IsLaunderStolen end,
				setFunc = function(value) MSI.SVars.IsLaunderStolen = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_PRCTCL_HELPER_STITLE),
		tooltip = GetString(MSI_MENU_PRCTCL_HELPER_TOOLTIP),
		reference = "MSIPracticalHelperSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = practicalHelperSubData
	})
	-- optionsData:insert({
		-- type = "description",
		-- title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	-- })
			--*********************--
			-- Hilfreiche Routinen
			local appropRoutinesSubData = setmetatable({}, { __index = table })
			appropRoutinesSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_APPROP_RTINS_TITLE),
				tooltip = GetString(MSI_MENU_APPROP_RTINS_TOOLTIP),
				reference = "MSIAppropRoutinesRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_FILLET_FISH_TITLE),
				tooltip = GetString(MSI_TGL_FILLET_FISH_TOOLTIP),
				reference = "MSIFilletFishRef",
				getFunc = function() return MSI.SVars.IsFilletFish end,
				setFunc = function(value) MSI.SVars.IsFilletFish = value end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_LEARN_CLLCTBL_TITLE),
				tooltip = GetString(MSI_TGL_LEARN_CLLCTBL_TOOLTIP),
				reference = "MSILearnCollectiblesRef",
				getFunc = function() return MSI.SVars.IsLearnCllctbl end,
				setFunc = function(value) MSI.SVars.IsLearnCllctbl = value end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_BIND_SETS_TITLE),
				tooltip = GetString(MSI_TGL_BIND_SETS_TOOLTIP),
				reference = "MSIBindSetPartsRef",
				getFunc = function() return MSI.SVars.IsBindSetParts end,
				setFunc = function(value) MSI.SVars.IsBindSetParts = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_UNRLL_TRSUREMAP_TITLE),
				tooltip = GetString(MSI_TGL_UNRLL_TRSUREMAP_TOOLTIP),
				reference = "MSIUnrollTreasureMapRef",
				getFunc = function() return MSI.SVars.IsUnrollTrsrMap end,
				setFunc = function(value) MSI.SVars.IsUnrollTrsrMap = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "description",
				title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
				enableLinks	= false,
				width = "full",
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_OPEN_ALL_CONTI_TITLE),
				tooltip = GetString(MSI_TGL_OPEN_ALL_CONTI_TOOLTIP),
				reference = "MSIOpenContainerRef",
				getFunc = function() return MSI.SVars.IsOpenContainer end,
				setFunc = function(value) MSI.SVars.IsOpenContainer = value end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			appropRoutinesSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_OPEN_UNOPND_TITLE),
				tooltip = GetString(MSI_TGL_OPEN_UNOPND_TOOLTIP),
				reference = "MSIOpensUnopenedRef",
				getFunc = function() return MSI.SVars.IsOpenUnopened end,
				setFunc = function(value) MSI.SVars.IsOpenUnopened = value end,
				default = true,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_APPROP_RTINS_STITLE),
		tooltip = GetString(MSI_MENU_APPROP_RTINS_TOOLTIP),
		reference = "MSIAppropRoutinesSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = appropRoutinesSubData
	})

	-- optionsData:insert({
		-- type = "description",
		-- title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
	-- })
			--********************--
			-- Zweckmäßge Aspekte
			local expedientAspectsSubData = setmetatable({}, { __index = table })
			expedientAspectsSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_EXPDNT_ASPCTS_TITLE),
				tooltip = GetString(MSI_MENU_EXPDNT_ASPCTS_TOOLTIP),
				reference = "MSIExpedientAspectsRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			expedientAspectsSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_CHATLOG_MODE_TITLE),
				tooltip = GetString(MSI_TGL_CHATLOG_MODE_TOOLTIP),
				reference = "MSIChatLogRef",
				getFunc = function() return MSI.SVars.IsChatLog end,
				setFunc = function(value) MSI.SVars.IsChatLog = value end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive or MSI.SVars.IsDebugLog end,
			})

			if GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc) then 
			else--*********************--
			-- DEVELOPER BEREICH START
			--*************************--
			expedientAspectsSubData:insert({
				type = "checkbox",
				name = GetString(MSI_TGL_DEBUG_LOG_TITLE),
				tooltip = GetString(MSI_TGL_DEBUG_LOG_TOOLTIP),
				reference = "MSIBebugLogRef",
				getFunc = function() return MSI.SVars.IsDebugLog end,
				setFunc = function(value) MSI.SVars.IsDebugLog = value
					if value then MSI.SVars.IsChatLog = not value 
							 else MSI.SVars.IsChatLog = value end end,
				default = false,
				disabled = function() return not MSI.SVars.IsMSIActive or
					(GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc)) end,
			})
			end--*********************--
			-- DEVELOPER BEREICH ENDE
			--************************--

	optionsData:insert({
		type = "submenu",
		name = GetString(MSI_MENU_EXPDNT_ASPCTS_STITLE),
		tooltip = GetString(MSI_MENU_EXPDNT_ASPCTS_TOOLTIP),
		reference = "MSIExpedientAspectsSubRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
		disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = expedientAspectsSubData
	})

	if GetUnitDisplayName("player") ~= DecorateDisplayName(MSI.DevAcc) then 
	else--*********************--
	-- DEVELOPER BEREICH START
	--*************************--
			local devTestsSubData = setmetatable({}, { __index = table })
			devTestsSubData:insert({
				type = "description",
				title = GetString(MSI_MENU_DEV_TESTS_TITLE),
				tooltip = GetString(MSI_MENU_DEV_TESTS_TOOLTIP),
				reference = "MSISubMenuDescriptRef",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "button",
				name = GetString(MSI_BTN_UNRLL_TRSUREMAP_TITLE),
				tooltip = GetString(MSI_BTN_UNRLL_TRSUREMAP_TOOLTIP),
				reference = "MSIUnrollAllTreasureMapRef",
				func = function(control) MSI.UnrollRolledTreasureMap() end,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "description",
				title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
			})
			devTestsSubData:insert({
				type = "slider",
				name = GetString(MSI_OPT_VAL_SLDR_ONE_TITLE),
				tooltip = GetString(MSI_OPT_VAL_SLDR_ONE_TOOLTIP),
				reference = "MSIValNameSliderOneRef",
				getFunc = function() return MSI.SVars.ValNameSliderOne end,
				setFunc = function(value) MSI.SVars.ValNameSliderOne = value
					MSI.ValNameSliderOne() end,
				min = 1,
				max = 7,
				step = 1,
				default = 3,
				readOnly = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "slider",
				name = GetString(MSI_OPT_VAL_SLDR_TWO_TITLE),
				tooltip = GetString(MSI_OPT_VAL_SLDR_TWO_TOOLTIP),
				reference = "MSINameSliderTwoRef",
				getFunc = function() return MSI.SVars.ValNameSliderTwo end,
				setFunc = function(value) MSI.SVars.ValNameSliderTwo = value
					MSI.ValNameSliderTwo() end,
				min = 0,
				max = 1,
				step = 0.01,
				decimals = 2,
				default = 0.07,
				readOnly = false,
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "description",
				title = GetString(MSI_GAME_MENU_PANEL_DIVIDER),
			})
			devTestsSubData:insert({
				type = "editbox",
				name = GetString(MSI_OPT_VAL_WHITE_LIST_TITLE),
				tooltip = GetString(MSI_OPT_VAL_WHITE_LIST_TOOLTIP),
				reference = "MSINameWhiteListRef",
				getFunc = function() return MSI.SVars.ValNameWhiteList end,
				setFunc = function(value) MSI.SVars.ValNameWhiteList = value end,
				isMultiline = true,
				textType = TEXT_TYPE_ALPHABETIC,
				maxChars = 1024,
				default = "",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "editbox",
				name = GetString(MSI_OPT_VAL_BLACK_LIST_TITLE),
				tooltip = GetString(MSI_OPT_VAL_BLACK_LIST_TOOLTIP),
				reference = "MSINameBlackListRef",
				getFunc = function() return MSI.SVars.ValNameBlackList end,
				setFunc = function(value) MSI.SVars.ValNameBlackList = value end,
				isMultiline = false,
				textType = TEXT_TYPE_NUMERIC,
				maxChars = 4,
				default = "",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})
			devTestsSubData:insert({
				type = "editbox",
				name = GetString(MSI_OPT_VAL_TEXT_FIELD_TITLE),
				tooltip = GetString(MSI_OPT_VAL_TEXT_FIELD_TOOLTIP),
				reference = "MSINameTextFieldRef",
				getFunc = function() return MSI.SVars.ValNameTextField end,
				setFunc = function(value) MSI.SVars.ValNameTextField = value end,
				isMultiline = true,
				textType = TEXT_TYPE_ALL,
				maxChars = 2048,
				default = "Buchstaben, Zahlen & Symbole",
				disabled = function() return not MSI.SVars.IsMSIActive end,
			})

	optionsData:insert({
        type = "submenu",
        name = GetString(MSI_MENU_DEV_TESTS_STITLE),
        tooltip = GetString(MSI_MENU_DEV_TESTS_TOOLTIP),
		reference = "MSIDevTestsRef",
		disabled = function() return not MSI.SVars.IsMSIActive end,
        disabledLabel = function() return not MSI.SVars.IsMSIActive end,
		controls = devTestsSubData
	})
	end--*********************--
	-- DEVELOPER BEREICH ENDE
	--************************--

	MSI.panel = MSI.LAM:RegisterAddonPanel("LAMMenuEntry", panelData)				
				MSI.LAM:RegisterOptionControls("LAMMenuEntry", optionsData)
	if MSI.panel then 
		LibAddonMenu2:OpenToPanel(MSI.panel)
	else
		MSI.Print("d", string.format("%s", "|cFF0000MSI Panel nicht gefunden!|r"))
	end

end
-- eof