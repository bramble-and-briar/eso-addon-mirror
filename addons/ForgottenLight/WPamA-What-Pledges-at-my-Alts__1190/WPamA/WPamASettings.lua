local WPamA = WPamA
WPamA.LAM = LibAddonMenu2
WPamA.MainMenuPanel = nil

local nvl = WPamA.SF_Nvl
local sp_shift = "      "

function WPamA.isOnlyOneEnabledMode()
  local n, MV = 0, WPamA.SV_Main.isModeVisible
  for i = 0, WPamA.ModeCount - 1 do
    if MV[i] then n = n + 1 end
  end
  return (n < 2)
end -- isOnlyOneEnabledMode end

function WPamA.isOnlyOneEnabledWind()
  local n, WV = 0, WPamA.SV_Main.isWindVisible
  for i = 0, WPamA.WindCount - 1 do
    if WV[i] then n = n + 1 end
  end
  return (n < 2)
end -- isOnlyOneEnabledWind end

local function CreateArrayOfModeChoices()
  local MS, WA = WPamA.ModeSettings, WPamA.i18n.Wind
  local MCC = WPamA.Consts.ModeChoicesArray.Choices
  local MCV = WPamA.Consts.ModeChoicesArray.ChoicesValues
  local MCT = WPamA.Consts.ModeChoicesArray.ChoicesTooltips
  -- the "Nothing to do" choice --
  MCC[1] = WPamA.i18n.OptNamesCorrList[1]
  MCV[1] = 1
  MCT[1] = WPamA.i18n.OptNamesCorrList[1]
  -- the modes list choices --
  for modeInd = 0, #MS do
    local winInd, tabInd = MS[modeInd].WinInd, MS[modeInd].TabInd
    if winInd and tabInd then
      local modeTab = WA[winInd].Tab[tabInd]
      local modeCapt = WA[winInd].Capt
      local modeIcon = MS[modeInd].FavRadMenuIcon or WPamA.Consts.FavRadPlaceholder
      local tblInd = modeInd + 2
      MCC[tblInd] = zo_strformat("|t24:24:<<1>>|t<<2>>", modeIcon, modeTab.A or modeTab.N) -- Mode's name
      MCV[tblInd] = tblInd -- Mode's index + 2
      MCT[tblInd] = modeCapt .. " \\\n" .. MCC[tblInd] -- Mode's tooltip
    end
  end
end -- CreateArrayOfModeChoices end

function WPamA:CreateOptionsPanel()
  local SV = self.SV_Main
  local CO = self.Consts
  local Lang = self.i18n
  local ChrLst = SV.CharsList
  local tinsert = table.insert
  local OptPanel = {
    type = "panel",
    name = "WPamA",
    author = "|c779cff@ForgottenLight|r [EU], |c779cff@TwilightOwl|r [EU]",
    version = self.Version,
    registerForRefresh = true,
    registerForDefaults = true
  } -- OptPanel end
--===========================================--
--== Section with static elements of panel ==--
--===========================================--
  local WPamAOptions = {
--> 1 General Options
--    { type = "header",
--     name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptGeneralHdr),
--    },
    { type = "divider", width = "full" },
    { type = "submenu",
     name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptGeneralHdr),
     tooltip = nvl(Lang.OptGeneralHdrF,Lang.OptGeneralHdr),
     controls = {
        { type = "dropdown",
         name = Lang.OptCharsOrder,
         tooltip = nvl(Lang.OptCharsOrderF,Lang.OptCharsOrder),
         choices = Lang.CharsOrderList,
         getFunc = function() return WPamA.GetVal_CharsOrder() end,
         setFunc = function(value) WPamA.SetVal_CharsOrder(value) end,
         requiresReload = true,
         default = Lang.OptCharsOrder[1] },
        { type = "checkbox",
         name = Lang.OptAlwaysMaxWinX,
         tooltip = nvl(Lang.OptAlwaysMaxWinXF,Lang.OptAlwaysMaxWinX),
         getFunc = function() return SV.AlwaysMaxWinX end,
         setFunc = function(value) WPamA.SetVal_AlwaysMaxWinX(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptLocation,
         tooltip = nvl(Lang.OptLocationF,Lang.OptLocation),
         getFunc = function() return SV.ShowLoc end,
         setFunc = function(value) WPamA.SetVal_ShowLoc(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptENDungeon,
         tooltip = nvl(Lang.OptENDungeonF,Lang.OptENDungeon),
         getFunc = function() return SV.ENDung end,
         setFunc = function(value) WPamA.SetVal_ENDung(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptDontShowNone,
         tooltip = nvl(Lang.OptDontShowNoneF,Lang.OptDontShowNone),
         getFunc = function() return SV.DontShowNone end,
         setFunc = function(value) WPamA.SetVal_DontShowNone(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptTitleToolTip,
         tooltip = nvl(Lang.OptTitleToolTipF,Lang.OptTitleToolTip),
         getFunc = function() return SV.TitleToolTip end,
         setFunc = function(value) WPamA.SetVal_TitleToolTip(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptHintUncomplPlg,
         tooltip = nvl(Lang.OptHintUncomplPlgF,Lang.OptHintUncomplPlg),
         getFunc = function() return SV.HintUncompletedPledges end,
         setFunc = function(value) WPamA.SetVal_HintUncompletedPledges(value) end,
         default = false },
        { type = "dropdown",
         name = Lang.OptLargeCalend,
         tooltip = nvl(Lang.OptLargeCalendF,Lang.OptLargeCalend),
         choices = { zo_strformat(SI_MAIL_READ_EXPIRES_LABEL, CO.CalendRowCnt[1]),   --  8 days
                     zo_strformat(SI_MAIL_READ_EXPIRES_LABEL, CO.CalendRowCnt[2]),   -- 15 days
                     zo_strformat(SI_MAIL_READ_EXPIRES_LABEL, CO.CalendRowCnt[3]) }, -- 30 days
         choicesValues = {1, 2, 3},
         getFunc = function() return SV.LargeCalend end,
         setFunc = function(value) WPamA.SetVal_LargeCalend(value) end,
         default = 1 },
        { type = "dropdown",
         name = Lang.OptDateFrmt,
         tooltip = nvl(Lang.OptDateFrmtF,Lang.OptDateFrmt),
         choices = Lang.DateFrmtList,
         getFunc = function() return WPamA.GetVal_DateFrmt() end,
         setFunc = function(value) WPamA.SetVal_DateFrmt(value) end,
         default = Lang.DateFrmtList[Lang.DateFrmt or 1] },
        { type = "checkbox",
         name = sp_shift .. Lang.OptShowTime,
         tooltip = nvl(Lang.OptShowTimeF,Lang.OptShowTime),
         getFunc = function() return SV.ShowTime end,
         setFunc = function(value) WPamA.SetVal_ShowTime(value) end,
         default = true },
        { type = "dropdown",
         name = Lang.OptTrialAvl,
         tooltip = nvl(Lang.OptTrialAvlF,Lang.OptTrialAvl),
         choices = Lang.OptTimerList,
         getFunc = function() return WPamA.GetVal_TrialAvl() end,
         setFunc = function(value) WPamA.SetVal_TrialAvl(value) end,
         default = Lang.OptTimerList[1] },
        { type = "dropdown",
         name = Lang.OptLFGRndAvl,
         tooltip = nvl(Lang.OptLFGRndAvlF,Lang.OptLFGRndAvl),
         choices = Lang.OptTimerList,
         getFunc = function() return WPamA.GetVal_LFGRndAvl() end,
         setFunc = function(value) WPamA.SetVal_LFGRndAvl(value) end,
         default = Lang.OptTimerList[1] },
        { type = "checkbox",
         name = Lang.OptDontShowReady,
         tooltip = nvl(Lang.OptDontShowReadyF,Lang.OptDontShowReady),
         getFunc = function() return SV.LFGRndDontShowSt end,
         setFunc = function(value) WPamA.SetVal_LFGRndDontShowSt(value) end,
         default = false },
        { type = "slider",
         name = Lang.OptRndDungDelay,
         tooltip = nvl(Lang.OptRndDungDelayF,Lang.OptRndDungDelay),
         getFunc = function() return SV.RndDungDelay end,
         setFunc = function(value) SV.RndDungDelay = value end,
         default = CO.RndDungDelayDef,
         min     = CO.RndDungDelayMin,
         max     = CO.RndDungDelayMax,
         step    = 1,
         advanced= true },
        { type = "checkbox",
         name = Lang.OptShowMonsterSetTT,
         tooltip = nvl(Lang.OptShowMonsterSetTTF,Lang.OptShowMonsterSetTT),
         getFunc = function() return SV.ShowMonsterSet end,
         setFunc = function(value) WPamA.SetVal_ShowMonsterSet(value) end,
         default = true },
        { type = "dropdown",
         name = Lang.OptCurrencyValThres,
         tooltip = nvl(Lang.OptCurrencyValThresF,Lang.OptCurrencyValThres),
         choices = { GetString(SI_GAMEPAD_CURRENCY_SELECTOR_HUNDREDS_NARRATION),        -- "Hundreds"
                     GetString(SI_GAMEPAD_CURRENCY_SELECTOR_THOUSANDS_NARRATION),       -- "Thousands"
                     GetString(SI_GAMEPAD_CURRENCY_SELECTOR_TEN_THOUSANDS_NARRATION) }, -- "Ten Thousands"
         choicesValues = {999, 9999, 99999},
         getFunc = function() return SV.CurrencyValueThreshold end,
         setFunc = function(value) WPamA.SetVal_CurrencyValueThreshold(value) end,
         default = 99999 },
        { type = "dropdown",
         name = Lang.OptDynEncounterNotify,
         tooltip = nvl(Lang.OptDynEncounterNotifyF,Lang.OptDynEncounterNotify),
         choices = { GetString(SI_ACTIONBARSETTINGCHOICE0),   -- "Don't Show"
                     GetString(SI_ACTIONBARSETTINGCHOICE2),   -- "Automatic"
                     GetString(SI_ACTIONBARSETTINGCHOICE1) }, -- "Always Show"
         choicesValues = {0, 1, 2},
         getFunc = function() return SV.DynEncounterNotifyMode end,
         setFunc = function(value) SV.DynEncounterNotifyMode = value end,
         default = 1 },
        { type = "dropdown",
         name = Lang.OptCompanionRapport,
         tooltip = nvl(Lang.OptCompanionRapportF,Lang.OptCompanionRapport),
         choices = Lang.OptCompanionRprtList,
         choicesValues = {1, 2},
         getFunc = function() return SV.CompanionRapportMode end,
         setFunc = function(value) WPamA.SetVal_CompanionRapportMode(value) end,
         default = 1 },
        { type = "checkbox",
         name = sp_shift .. Lang.OptCompanionRprtMax,
         tooltip = nvl(Lang.OptCompanionRprtMaxF,Lang.OptCompanionRprtMax),
         getFunc = function() return SV.CompanionRapportShowMax end,
         setFunc = function(value) WPamA.SetVal_CompanionRapportShowMax(value) end,
         disabled = function() return (SV.CompanionRapportMode > 1) end,
         default = true },
        { type = "dropdown",
         name = Lang.OptCompanionEquip,
         tooltip = nvl(Lang.OptCompanionEquipF,Lang.OptCompanionEquip),
         choices = Lang.OptCompanionEquipList,
         choicesValues = {1, 2, 3, 4},
         getFunc = function() return SV.CompanionEquipMode end,
         setFunc = function(value) WPamA.SetVal_CompanionEquipMode(value) end,
         default = 1 },
        { type = "checkbox",
         name = Lang.OptMouseModeUI,
         tooltip = nvl(Lang.OptMouseModeUIF,Lang.OptMouseModeUI),
         getFunc = function() return SV.ShowMouseMode end,
         setFunc = function(value) SV.ShowMouseMode = value end,
         default = false },
        { type = "submenu",
         name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptCharNamesMenu),
         tooltip = nvl(Lang.OptCharNamesMenuF,Lang.OptCharNamesMenu),
         controls = {
            { type = "checkbox",
             name = Lang.OptCharNameColor,
             tooltip = nvl(Lang.OptCharNameColorF,Lang.OptCharNameColor),
             getFunc = function() return SV.CharNamesInColors end,
             setFunc = function(value) WPamA.SetVal_CharNamesInColors(value) end,
             default = true },
            { type = "dropdown",
             name = Lang.OptCharNameAlign,
             tooltip = nvl(Lang.OptCharNameAlignF,Lang.OptCharNameAlign),
             choices = Lang.OptNamesAlignList,
             choicesValues = {TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT}, -- 0, 1, 2
             getFunc = function() return SV.CharNamesAlignment end,
             setFunc = function(value) WPamA.SetVal_CharNamesAlignment(value) end,
             default = TEXT_ALIGN_LEFT },
            { type = "dropdown",
             name = Lang.OptCorrLongNames,
             tooltip = nvl(Lang.OptCorrLongNamesF,Lang.OptCorrLongNames),
             choices = Lang.OptNamesCorrList,
             choicesValues = {0, 1, 2, 3},
             getFunc = function() return SV.CharNamesCorrMode end,
             setFunc = function(value) WPamA.SetVal_CharNamesCorrMode(value) end,
             default = 0 },
            { type = "editbox",
             name = sp_shift .. Lang.OptNamesCorrRepl[1],
             getFunc = function() return SV.CharNamesMaskFrom end,
             setFunc = function(text) WPamA.SetVal_CharNamesMaskFrom(text) end,
             disabled = function() return (SV.CharNamesCorrMode ~= 3) end,
             default = "" },
            { type = "editbox",
             name = sp_shift .. Lang.OptNamesCorrRepl[2],
             getFunc = function() return SV.CharNamesMaskTo end,
             setFunc = function(text) WPamA.SetVal_CharNamesMaskTo(text) end,
             disabled = function() return (SV.CharNamesCorrMode ~= 3) end,
             default = "" },
         }, -- controls end
        }, -- CharNames submenu end
     }, -- controls end
    },
--> 2 Option and Mode settings
    { type = "divider", width = "full" },
    { type = "submenu",
     name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptModeSetHdr),
     tooltip = nvl(Lang.OptModeSetHdrF,Lang.OptModeSetHdr),
     controls = {
        { type = "description",
         title = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptAutoActionsHdr),
         text = "",
         width = "full" },
        { type = "checkbox",
         name = Lang.OptAutoTakeUpPledges,
         tooltip = nvl(Lang.OptAutoTakeUpPledgesF,Lang.OptAutoTakeUpPledges),
         getFunc = function() return SV.AutoTakePledges end,
         setFunc = function(value) SV.AutoTakePledges = value end,
         default = false },
        { type = "dropdown",
         name = Lang.OptAutoTakeDBSupplies,
         tooltip = nvl(Lang.OptAutoTakeDBSuppliesF,Lang.OptAutoTakeDBSupplies),
         choices = Lang.OptAutoTakeDBList,
         choicesValues = {1, 2},
         getFunc = function() return WPamA.CurChar.ShSupplier.Mode or 1 end,
         setFunc = function(value) WPamA.CurChar.ShSupplier.Mode = value end,
         default = 1 },
        { type = "dropdown",
         name = sp_shift .. Lang.OptChoiceDBSupplies,
         tooltip = nvl(Lang.OptChoiceDBSuppliesF,Lang.OptChoiceDBSupplies),
         choices = Lang.OptDBSuppliesList,
         choicesValues = {1, 2, 3, 4},
         getFunc = function() return WPamA.ShadowySupplierOption() end,
         setFunc = function(value) WPamA.ShadowySupplierOption(value) end,
         default = 1 },
        { type = "checkbox",
         name = Lang.OptAutoChargeWeapon,
         tooltip = nvl(Lang.OptAutoChargeWeaponF,Lang.OptAutoChargeWeapon),
         getFunc = function() return SV.AutoChargeWeapon end,
         setFunc = function(value) SV.AutoChargeWeapon = value end,
         default = false },
        { type = "slider",
         name = sp_shift .. Lang.OptAutoChargeThreshold,
         tooltip = nvl(Lang.OptAutoChargeThresholdF,Lang.OptAutoChargeThreshold),
         getFunc = function() return SV.AutoChargeThreshold end,
         setFunc = function(value) SV.AutoChargeThreshold = value end,
         disabled = function() return (not SV.AutoChargeWeapon) end,
         min = 1, max = 5, step = 1, advanced = true,
         default = 3 },
        { type = "checkbox",
         name = Lang.OptAutoCallEyeInfinite,
         tooltip = nvl(Lang.OptAutoCallEyeInfiniteF,Lang.OptAutoCallEyeInfinite),
         getFunc = function() return SV.AutoCallEyeInfinite end,
         setFunc = function(value) SV.AutoCallEyeInfinite = value end,
         disabled = function() return not IsCollectibleUnlocked(WPamA.EndlessDungeons.EyeOfInfinite.C) end,
         default = false },
        -------------------
        { type = "divider", width = "full" },
        { type = "description",
         title = ZO_HIGHLIGHT_TEXT:Colorize( zo_strformat("<<1>><<2>><<3>>",
                 GetString(SI_TIMED_ACTIVITIES_TITLES),                         -- "Challenges"
                 GetString(SI_LIST_AND_SEPARATOR),                              -- " and "
                 GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS) ) ), -- "Golden Pursuits"
         text = "",
         width = "full" },
--[[
        { type = "dropdown",
         name = Lang.OptEndeavorRewardMode,
         tooltip = nvl(Lang.OptEndeavorRewardModeF,Lang.OptEndeavorRewardMode),
         choices = Lang.OptEndeavorRewardList,
         choicesValues = {1, 2, 3},
         getFunc = function() return SV.EndeavorRewardMode end,
         setFunc = function(value) WPamA.SetVal_EndeavorRewardMode(value) end,
         default = 1 },
--]]
        { type = "checkbox",
         name = Lang.OptEndeavorChatMsg,
         tooltip = nvl(Lang.OptEndeavorChatMsgF,Lang.OptEndeavorChatMsg),
         getFunc = function() return SV.EndeavorProgressInChat.Enabled end,
         setFunc = function(value) SV.EndeavorProgressInChat.Enabled = value end,
         default = false },
        { type = "dropdown",
         name = sp_shift .. Lang.OptEndeavorChatChnl,
         tooltip = nvl(Lang.OptEndeavorChatChnlF,Lang.OptEndeavorChatChnl),
         choices = self.ChatChannelChoices.Choices,
         choicesValues = self.ChatChannelChoices.ChoicesValues,
         getFunc = function() return SV.EndeavorProgressInChat.Channel end,
         setFunc = function(value) SV.EndeavorProgressInChat.Channel = value end,
         disabled = function() return (not SV.EndeavorProgressInChat.Enabled) end,
         default = self.ChatChannelChoices.ChoicesValues[1] },
        { type = "checkbox",
         name = Lang.OptEndeavorAutoClaim,
         tooltip = nvl(Lang.OptEndeavorAutoClaimF,Lang.OptEndeavorAutoClaim),
         getFunc = function() return SV.AutoClaimEndeavorReward end,
         setFunc = function(value) SV.AutoClaimEndeavorReward = value end,
         default = false },
        { type = "checkbox",
         name = Lang.OptEndeavorHideCompl,
         tooltip = nvl(Lang.OptEndeavorHideComplF,Lang.OptEndeavorHideCompl),
         getFunc = function() return SV.EndeavorHideCompleted end,
         setFunc = function(value) WPamA.SetVal_EndeavorHideCompleted(value) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptPursuitChatMsg,
         tooltip = nvl(Lang.OptPursuitChatMsgF,Lang.OptPursuitChatMsg),
         getFunc = function() return SV.PursuitProgressInChat.Enabled end,
         setFunc = function(value) SV.PursuitProgressInChat.Enabled = value end,
         default = false },
        { type = "checkbox",
         name = sp_shift .. Lang.OptPursuitChatCamp,
         tooltip = nvl(Lang.OptPursuitChatCampF,Lang.OptPursuitChatCamp),
         getFunc = function() return SV.PursuitProgressInChat.CampRewardEarned or false end,
         setFunc = function(value) SV.PursuitProgressInChat.CampRewardEarned = value end,
         disabled = function() return (not SV.PursuitProgressInChat.Enabled) end,
         default = false },
        { type = "dropdown",
         name = sp_shift .. Lang.OptEndeavorChatChnl,
         tooltip = nvl(Lang.OptPursuitChatChnlF,Lang.OptEndeavorChatChnl),
         choices = self.ChatChannelChoices.Choices,
         choicesValues = self.ChatChannelChoices.ChoicesValues,
         getFunc = function() return SV.PursuitProgressInChat.Channel end,
         setFunc = function(value) SV.PursuitProgressInChat.Channel = value end,
         disabled = function() return (not SV.PursuitProgressInChat.Enabled) end,
         default = self.ChatChannelChoices.ChoicesValues[1] },
        { type = "colorpicker",
         name = sp_shift .. Lang.OptEndeavorChatColor,
         tooltip = nvl(Lang.OptEndeavorChatColorF,Lang.OptEndeavorChatColor),
         getFunc = function()
                     local r, g, b, a = ZO_ColorDef.HexToFloats(SV.PursuitProgressInChat.Color)
                     return r, g, b, a
                   end,
         setFunc = function(r, g, b, a)
                     SV.PursuitProgressInChat.Color = ZO_ColorDef.FloatsToHex(r, g, b, a)
                   end,
         disabled = function() return (not SV.PursuitProgressInChat.Enabled) end,
         default = {r = 238 / 255, g = 238 / 255, b = 200 / 255, a = 1},
         width = "full" },
        { type = "checkbox",
         name = Lang.OptPursuitAutoClaim,
         tooltip = nvl(Lang.OptPursuitAutoClaimF,Lang.OptPursuitAutoClaim),
         getFunc = function() return SV.AutoClaimPursuitReward end,
         setFunc = function(value) SV.AutoClaimPursuitReward = value end,
         default = false },
        -------------------
        { type = "divider", width = "full" },
        { type = "description",
         title = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptLFGPHdr),
         text = "",
         width = "full" },
        { type = "checkbox",
         name = Lang.OptLFGPOnOff,
         tooltip = nvl(Lang.OptLFGPOnOffF,Lang.OptLFGPOnOff),
         getFunc = function() return SV.AllowLFGP end,
         setFunc = function(value) WPamA.SetVal_AllowLFGP(value) end,
         default = false },
        { type = "dropdown",
         name = sp_shift .. Lang.OptLFGPMode,
         tooltip = nvl(Lang.OptLFGPModeF,Lang.OptLFGPMode),
         choices = Lang.OptLFGPModeList,
         getFunc = function() return WPamA.GetVal_ModeLFGP() end,
         setFunc = function(value) WPamA.SetVal_ModeLFGP(value) end,
         disabled = function() return (not SV.AllowLFGP) end,
         default = Lang.OptLFGPModeList[1] },
        { type = "checkbox",
         name = sp_shift .. Lang.OptLFGPIgnPledge,
         tooltip = nvl(Lang.OptLFGPIgnPledgeF,Lang.OptLFGPIgnPledge),
         getFunc = function() return SV.LFGPIgnorePledge end,
         setFunc = function(value) SV.LFGPIgnorePledge = value end,
         disabled = function() return (not SV.AllowLFGP) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptLFGPModeRoult,
         tooltip = nvl(Lang.OptLFGPModeRoultF,Lang.OptLFGPModeRoult),
         getFunc = function() return SV.ModeLFGPRoulette end,
         setFunc = function(value) WPamA.SetVal_ModeLFGPRoulette(value) end,
         disabled = function() return (not SV.AllowLFGP) end,
         default = false },
        { type = "checkbox",
         name = Lang.OptLFGPAlert,
         tooltip = nvl(Lang.OptLFGPAlertF,Lang.OptLFGPAlert),
         getFunc = function() return SV.LFGPAlert end,
         setFunc = function(value) SV.LFGPAlert = value end,
         disabled = function() return (not SV.AllowLFGP) end,
         default = true },
        { type = "checkbox",
         name = Lang.OptLFGPChat,
         tooltip = nvl(Lang.OptLFGPChatF,Lang.OptLFGPChat),
         getFunc = function() return SV.LFGPChat end,
         setFunc = function(value) SV.LFGPChat = value end,
         disabled = function() return (not SV.AllowLFGP) end,
         default = false },
     }, -- controls end
    },
--> 3 RGLA Options
--    { type = "header",
--     name = ZO_HIGHLIGHT_TEXT:Colorize("RGLA"),
--    },
    { type = "divider", width = "full" },
    { type = "submenu",
     name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.OptRGLAHdr),
     tooltip = nvl(Lang.OptRGLAHdrF,Lang.OptRGLAHdr),
     controls = {
        { type = "checkbox",
         name = Lang.OptRGLAQAutoShare,
         tooltip = nvl(Lang.OptRGLAQAutoShareF,Lang.OptRGLAQAutoShare),
         getFunc = function() return SV.AutoShare end,
         setFunc = function(value) SV.AutoShare = value end,
         default = true },
        { type = "checkbox",
         name = sp_shift .. Lang.OptRGLAQAlert,
         tooltip = nvl(Lang.OptRGLAQAlertF,Lang.OptRGLAQAlert),
         getFunc = function() return SV.QAlert end,
         setFunc = function(value) SV.QAlert = value end,
         disabled = function() return (not SV.AutoShare) end,
         default = true },
        { type = "checkbox",
         name = sp_shift .. Lang.OptRGLAQChat,
         tooltip = nvl(Lang.OptRGLAQChatF,Lang.OptRGLAQChat),
         getFunc = function() return SV.QChat end,
         setFunc = function(value) SV.QChat = value end,
         disabled = function() return (not SV.AutoShare) end,
         default = false },
        { type = "checkbox",
         name = sp_shift .. Lang.OptRGLABossKilled,
         tooltip = nvl(Lang.OptRGLABossKilledF,Lang.OptRGLABossKilled),
         getFunc = function() return SV.BossKilled end,
         setFunc = function(value) SV.BossKilled = value end,
         disabled = function() return (not SV.AutoShare) end,
         default = true },
     }, -- controls end
    },
--============================================--
--== Section with dynamic elements of panel ==--
--============================================--
  } -- WpamaOptions end
--> 4 Enable / Disable Chars
--  tinsert( WPamAOptions, { type = "header",
--          name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.CharsOnOffHdr) } )
  tinsert( WPamAOptions, { type = "divider",
          width = "full" } )
  tinsert( WPamAOptions, { type = "description",
          title = nil,
          text = Lang.CharsOnOffNote,
          width = "full" } )
  tinsert( WPamAOptions, { type = "submenu",
          name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.CharsOnOffHdr),
          tooltip = nvl(Lang.CharsOnOffHdrF,Lang.CharsOnOffHdr),
          controls = {} } )
  local SubmenuCtrl = WPamAOptions[#WPamAOptions].controls -- link to last submenu
  for i = 1, #ChrLst do
    if ChrLst[i] ~= nil then -- ignore empty chars
      tinsert( SubmenuCtrl, { type = "checkbox",
       name = ChrLst[i].Name,
       tooltip = zo_strformat(Lang.OptCharOnOffTtip, ChrLst[i].Name),
       getFunc = function() return ChrLst[i].isVisible end,
       setFunc = function(value) WPamA.SetVal_CharVisible(i, value) end,
       default = true } )
    end
  end
--> 5 Enable / Disable Modes
--  tinsert( WPamAOptions, { type = "header",
--          name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.ModesOnOffHdr) } )
  tinsert( WPamAOptions, { type = "divider",
          width = "full" } )
  tinsert( WPamAOptions, { type = "description",
          title = nil,
          text = Lang.ModesOnOffNote,
          width = "full" } )
  tinsert( WPamAOptions, { type = "submenu",
          name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.ModesOnOffHdr),
          tooltip = nvl(Lang.ModesOnOffHdrF,Lang.ModesOnOffHdr),
          controls = {} } )
  SubmenuCtrl = WPamAOptions[#WPamAOptions].controls -- link to last submenu
-- 0 = "Characters" 1 = "Calendar" 2 = "WWBosses"
-- 3 = "Miscellaneous" 4 = "Skills: Class & Guild" 5 = "Skills: Craft"
-- 6 = Trials 7 = Random Dungeons 8 = VvardenfellWBosses 9 = GoldCoastWBosses
-- 10 = "Seasonal Festivals" 13 = "Riding Skill"
  for j = 0, WPamA.WindCount-1 do
    local lng = Lang.Wind[j]
    local WSj = WPamA.WindSettings[j]
    if lng ~= nil and WSj ~= nil then -- ignore empty windows
      tinsert( SubmenuCtrl, { type = "divider", width = "full" } )
      --tinsert( SubmenuCtrl, { type = "header", name = lng.Capt } )
      tinsert( SubmenuCtrl, { type = "checkbox",
        name = zo_strformat( "|c779cff<<1>>|r", string.upper(lng.Capt) ),
        tooltip = zo_strformat(Lang.OptWindOnOffTtip, lng.Capt),
        getFunc = function() return SV.isWindVisible[j] end,
        setFunc = function(value) WPamA.SetVal_WindVisible(j, value) end,
        disabled = function()
                     return ( SV.isWindVisible[j] and WPamA.isOnlyOneEnabledWind() )
                   end,
        default = true } )
      for k = 1, WPamA.TabBCount do
        local i = WSj.Mds[k]
        if i ~= nil and lng.Tab[k] ~= nil then -- ignore empty modes
          tinsert( SubmenuCtrl, { type = "checkbox",
            name = lng.Tab[k].N .. nvl(lng.Tab[k].A,""),
            tooltip = zo_strformat(Lang.OptModeOnOffTtip, lng.Capt .. "\\" .. lng.Tab[k].N),
            getFunc = function() return SV.isModeVisible[i] end,
            setFunc = function(value) WPamA.SetVal_ModeVisible(i, value) end,
            disabled = function()
                         return ( SV.isModeVisible[i] and WPamA.isOnlyOneEnabledMode() )
                       end,
            default = self.ModeSettings[i].isVisibleDef } )
        end
      end
    end
  end
--> 6 Custom Mode Keybindings
  CreateArrayOfModeChoices()
  tinsert( WPamAOptions, { type = "divider",
          width = "full" } )
  tinsert( WPamAOptions, { type = "description",
          title = nil,
          text = Lang.CustomModeKbdNote,
          width = "full" } )
  tinsert( WPamAOptions, { type = "submenu",
          name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.CustomModeKbdHdr),
          tooltip = nvl(Lang.CustomModeKbdHdrF,Lang.CustomModeKbdHdr),
          controls = {} } )
  SubmenuCtrl = WPamAOptions[#WPamAOptions].controls -- link to last submenu
  local MCC = CO.ModeChoicesArray.Choices
  local MCV = CO.ModeChoicesArray.ChoicesValues
  local MCT = CO.ModeChoicesArray.ChoicesTooltips
  for i = 1, CO.CustomKeybindsMax do
    tinsert( SubmenuCtrl, { type = "dropdown",
      name = zo_strformat(Lang.OptCustomModeKbd, i),
--      tooltip = nvl(Lang.OptCustomModeKbdF,Lang.OptCustomModeKbd),
      choices = MCC,
      choicesValues = MCV,
      choicesTooltips = MCT,
      width = "full",
      scrollable = true,
      getFunc = function() return WPamA.SV_Main.CustomModeKeybinds[i] or 1 end,
      setFunc = function(value) WPamA.SV_Main.CustomModeKeybinds[i] = value end,
      disabled = false,
      default = 1 } )
  end
--> 7 Reset Chars
--    { type = "header",
--     name = ZO_HIGHLIGHT_TEXT:Colorize(Lang.ResetChar)
--    },
  tinsert( WPamAOptions, { type = "divider",
          width = "full" } )
  if Lang.ResetCharNote then
    tinsert( WPamAOptions, { type = "description",
            title = nil,
            text = Lang.ResetCharNote,
            width = "full" } )
  end
  tinsert( WPamAOptions, { type = "button",
          name = "   " .. Lang.ResetChar .. "   ",
          tooltip = nvl(Lang.ResetCharF,Lang.ResetChar),
          isDangerous = true,
          warning = Lang.ResetCharWarn,
          width = "half",
          func = function() WPamA.DoResetCharacters() end } )

  -- Register Option Controls
  self.MainMenuPanel = self.LAM:RegisterAddonPanel("WPamA_Panel", OptPanel)
  self.LAM:RegisterOptionControls("WPamA_Panel", WPamAOptions)
end -- -= CreateOptionsPanel end =-
