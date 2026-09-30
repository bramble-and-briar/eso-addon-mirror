ElderScrollsOfAlts = {
    name            = "ElderScrollsOfAlts",	-- Matches folder and Manifest file names.
    displayName     = "Elder Scrolls of Alts",
    version         = "2.00.10",			-- A nuisance to match to the Manifest.
    author          = "Echomap",
    color           = "DDFFEE",			 -- Used in menu titles and so on.
    menuName        = "ElderScrollsOfAlts_Options", -- Unique identifier for menu object.
    SV_VERSION_NAME = 1,
    --HOME_FONT_BASE  = "ZoFontWinT2",
    --HOME_FONT_SEL   = "ZoFontGameLargeBold",
    maxCompanions            = 12,
    maxCompanionLevel        = 20,
    defaultMaxViewButtons    = 5,
    defaultMaxLines          = 12,
    defaultFieldWidthForName = 180,
    defaultFieldHeight       = 30,
    defaultFieldYOffset      = -10, -- -10
    defaultView     = GetString(ESOA_VIEW_HOME),
    defaultSearch   = "Name",
    CATEGORY_ALL    = "All",
    CATEGORY_EU     = "EU",
    CATEGORY_US     = "NA",
    BITE_WERE_ABILITY  = GetString(ESOA_BITE_WERE_ABILITY),
    BITE_WERE_COOLDOWN = GetString(ESOA_BITE_WERE_COOLDOWN),
    BITE_VAMP_ABILITY  = GetString(ESOA_BITE_VAMP_ABILITY),
    BITE_VAMP_COOLDOWN = GetString(ESOA_BITE_VAMP_COOLDOWN),
    rgbaWhite   = {
      ["r"] = 1,
      ["g"] = 1,
      ["b"] = 1,
      ["a"] = 0.9,
    },
    view            = {},
    -- Saved Settings
    savedVariables  = {},
    altData         = {},	
	reloaded    = "load_reload",
	manualload  = "load_manual",
	startupload = "load_startup",
	FONT_TYPE	 	= 1,
	FONT_STYLE		= 2,
	FONT_SIZE		= 3,
	FONT_WEIGHT		= 4,
	esoaFontBold = {
		[1] = "$(BOLD_FONT)",
		[2] = "",
		[3] = "$(KB_18)",
		[4] = "soft-shadow-thick",
	},
	esoaFontGame = {
		[1] = "$(MEDIUM_FONT)",
		[2] = "",
		[3] = "$(KB_18)",
		[4] = "soft-shadow-thin",
	},
	esoaFontPaper = {
		[1] = "$(ANTIQUE_FONT)",
		[2] = "",
		[3] = "$(KB_20)",
		[4] = "soft-shadow-thick",
	}, 
	esoaFontButton = {
		[1] = "$(BOLD_FONT)",
		[2] = "",
		[3] = "$(KB_16)",
		[4] = "soft-shadow-thick",
	},
}

--ZO_SORT_ORDER_UP, --ZO_SORT_ORDER_DOWN
local defaultSettings = {
  sversion			= ElderScrollsOfAlts.version,
  currentView      	= GetString(ESOA_VIEW_HOME),
  currentsort      	= { },
  fieldWidthForName = 180,
  window     = {
      ["minimized"] = false,
      ["shown"]     = false,
      ["top"]       = 100,
      ["left"]      = 100,
      ["width"]     = 830,
      ["height"]    = 325,
  },
  uibutton    = {
    ["shown"] = true,
    ["top"]   = 200,
    ["left"]  = 200,
  },
  selected = {
    --["charactername"] = nil,
  },
  allowsaveoddviewnames = false,
  pvpwarnings = true
}
local defaultSettings2 = {
  sversion   = ElderScrollsOfAlts.version,
}

local defaultSettingsGlobal = {
  debug        = false,
  beta         = false,
  showpercents = true  -- show partial numbers for skills etc
}

--Commands, help/debug/beta/testdata/deltestdata
function ElderScrollsOfAlts.SlashCommandHandler(text)
	ElderScrollsOfAlts.debugMsg("SlashCommandHandler: " , text)
	local options = {}
	local searchResult = { string.match(text,"^(%S*)%s*(.-)$") }
	for i,v in pairs(searchResult) do
		if (v ~= nil and v ~= "") then
		    options[i] = string.lower(v)
		end
	end

  if #options == 0 then
    ElderScrollsOfAlts.outputMsg("/esoa <commands> where command can be, gui, help, debug, resetviews, showentries")
  elseif options[1] == "gui" then
    ElderScrollsOfAlts.ShowGuiByChoice()
  elseif options[1] == "help" then
    ElderScrollsOfAlts.ShowHelp()
	elseif options[1] == "debug" then
		local dg = ElderScrollsOfAlts.altData.debug
		ElderScrollsOfAlts.altData.debug = not dg
		ElderScrollsOfAlts.outputMsg("ElderScrollsOfAlts: Debug = " .. tostring(ElderScrollsOfAlts.altData.debug) )
		ElderScrollsOfAlts.savedVariables.debug = ElderScrollsOfAlts.altData.debug
	elseif options[1] == "beta" then
		local dg = ElderScrollsOfAlts.altData.beta
		ElderScrollsOfAlts.altData.beta = not dg
		ElderScrollsOfAlts.outputMsg("ElderScrollsOfAlts: Beta = " .. tostring(ElderScrollsOfAlts.altData.beta) )
		--ElderScrollsOfAlts.savedVariables.beta = ElderScrollsOfAlts.altData.beta
    --ElderScrollsOfAlts.LoadSettings()
  elseif options[1] == "savebuttondata" then --test
    ElderScrollsOfAlts:ButtonFrameOnMoveStop()--test
  elseif options[1] == "testdata" then--test
    ElderScrollsOfAlts:LoadTestData1()--test
  elseif options[1] == "testlaunder" then--test
	ElderScrollsOfAlts:TestLaunder()
  elseif options[1] == "deltestdata" then--test 
    ElderScrollsOfAlts:DelTestData1()     --test
  elseif options[1] == "changefont" then--test
    ElderScrollsOfAlts:ChangeESOAFontGame() --test
  elseif options[1] == "testtime1" then--test
    ElderScrollsOfAlts:TestTime1() --test
  elseif options[1] == "resetviews" then
    ElderScrollsOfAlts:ResetUIViews()     
  elseif options[1] == "showentries" then
    ElderScrollsOfAlts:ListAllAllowedViewEntries()   
  elseif options[1] == "forcesavedata" then
    ElderScrollsOfAlts.SavePlayerDataForGui(ElderScrollsOfAlts.manualload)
  elseif options[1] == "forceloaddata" then
    ElderScrollsOfAlts:LoadPlayerDataForGui()
  elseif options[1] == "showcpbar" then
    ElderScrollsOfAlts:SetupCPBar(true)
  elseif options[1] == "hidecpbar" then
    ElderScrollsOfAlts:HideCPBar()
  elseif options[1] == "resetorder" then
    ElderScrollsOfAlts:ResetPlayerOrder()
  else
    ElderScrollsOfAlts.ShowHelp()
  end
end

function ElderScrollsOfAlts.ShowHelp()
    ElderScrollsOfAlts.outputMsg("/esoa <commands> where command can be, gui, help, debug, beta, resetviews, showentries, forcesavedata, forceloaddata")
    ElderScrollsOfAlts.outputMsg("showentries: prints allowable view entries. resetviews: sets the views back to default. ")
end

-- EVENT
function ElderScrollsOfAlts.OnChampionPerksStateChange(oldState,newState)
    if newState == SCENE_SHOWING then
      ElderScrollsOfAlts.HideAll()--ESOA_ButtonFrame
    elseif newState == SCENE_HIDDEN then
      ElderScrollsOfAlts.ShowUIButton()--ESOA_ButtonFrame
      ElderScrollsOfAlts.CollectCP()
      ElderScrollsOfAlts.SetupCPBar()
    end
end

-- EVENT
--EVENT_CHAMPION_PURCHASE_RESULT (number eventCode, ChampionPurchaseResult result)
function ElderScrollsOfAlts.OnChampionPurchaseResult(eventCode, result)
  ElderScrollsOfAlts:CollectCP()
  ElderScrollsOfAlts:SetupCPBar()
end
--EVENT_CHAMPION_POINT_UPDATE (number eventCode, string unitTag, number oldChampionPoints, number currentChampionPoints)
function ElderScrollsOfAlts.OnChampionPointUpdate(eventCode, unitTag, oldChampionPoints, currentChampionPoints)
  d("CPU: " .. tostring(unitTag))
end
--EVENT_UNSPENT_CHAMPION_POINTS_CHANGED (number eventCode)
function ElderScrollsOfAlts.OnChampionUnspentPointsChange(eventCode)
  d("CUPC: " .. tostring(eventCode))
end

--TODO ElderScrollsOfAlts.view.writskey = "writs"
    
-- EVENT
--EVENT_QUEST_COMPLETE (number eventCode, string questName, number level, number previousExperience, number currentExperience, number championPoints, QuestType questType, InstanceDisplayType instanceDisplayType)
function ElderScrollsOfAlts.OnQuestComplete(eventCode, questName, level, previousExperience, currentExperience, championPoints, questType, instanceDisplayType)
  if(QUEST_TYPE_CRAFTING==questType) then
    ElderScrollsOfAlts.debugMsg("Finished Crafting Quest with name='"..questName.."'")
    ElderScrollsOfAlts:SaveTrackingDataComplete("writs",questName,true)
  end
end


-- COMPANIONS --
------------------------------
-- EVENT_COMPANION_ACTIVATED (*integer* _companionId_)
function ElderScrollsOfAlts.OnCompanionActivated(eventCode, companionId)
  ElderScrollsOfAlts.debugMsg( "OnCompanionActivated: eventCode: '", eventCode, "' companionId='", tostring(companionId), "'")
  local cname = GetCompanionName(companionId) --is there a RawName, so can have w/o the gender ctrl char?
  local characterGender = GetGenderFromNameDescriptor(cname)
  if(characterGender~=nil) then
	local indexstart = string.find(cname,"%^")
    --d("indexstart:"..indexstart)
	if(indexstart~= nil and indexstart>0) then
		cname = cname:sub(1, indexstart-1)
	end
  end
  --d("cname:"..cname)
  local defcompanionId = GetActiveCompanionDefId() -- this right ID?
  ElderScrollsOfAlts.debugMsg( "OnCompanionActivated: defcompanionId: '", defcompanionId, "'") 
  if(defcompanionId ~= companionId) then
	ElderScrollsOfAlts.outputMsg( "OnCompanionActivated: WARNING: defcompanionId=", defcompanionId, " where companionId=",companionId) 
  end
  local level, currentExperience = GetActiveCompanionLevelInfo()
  --local [CompanionRapportLevel|#CompanionRapportLevel]* _rapportLevel_ = GetActiveCompanionRapportLevel()
  --GetActiveCompanionRapportLevelDescription
  local currentRapport = GetActiveCompanionRapport()
  local xplevel = GetNumExperiencePointsInCompanionLevel(level+1)
  ElderScrollsOfAlts:CollectCompanionDataRapport(companionId, tostring(cname), currentRapport)
  ElderScrollsOfAlts:CollectCompanionDataLevel(companionId, tostring(cname), level, currentExperience, xplevel)
end
  
------------------------------
-- EVENT_COMPANION_DEACTIVATED ( )
function ElderScrollsOfAlts.OnCompanionDeactivated(eventCode)
  ElderScrollsOfAlts.debugMsg( "OnCompanionDeactivated: eventCode: '", tostring(eventCode), "'")
  --
end

------------------------------
-- EVENT_COMPANION_RAPPORT_UPDATE (*integer* _companionId_, *integer* _previousRapport_, *integer* _currentRapport_)
function ElderScrollsOfAlts.OnCompanionRapportUpdate(eventCode, companionId, previousRapport, currentRapport )
  ElderScrollsOfAlts.debugMsg( "OnCompanionRapportUpdate: eventCode: '", eventCode, 
    "' companionId='", tostring(companionId), "' warningType: '" , tostring(warningType), 
    "' previousRapport: '", (previousRapport), "' currentRapport: '", (currentRapport), "'" )
  local cname = GetCompanionName(companionId)
  ElderScrollsOfAlts:CollectCompanionDataRapport(companionId, tostring(cname), currentRapport)
end

------------------------------
-- EVENT_COMPANION_SKILL_LINE_ADDED (** _skillLineId_)
function ElderScrollsOfAlts.OnCompanionSkilllineAdded(eventCode, skillLineId)
  ElderScrollsOfAlts.debugMsg( "OnCompanionSkilllineAdded: eventCode: '", eventCode, "' skillLineId='", tostring(skillLineId), "'")  
  local companionId = GetActiveCompanionDefId() -- this right ID?
  local cname       = GetCompanionName(companionId)
  local slName      = GetSkillLineNameById(skillLineId)
  ElderScrollsOfAlts:CollectCompanionDataSkillLine(companionId, tostring(cname), skillLineId, slName )
end

------------------------------
-- EVENT_COMPANION_SKILL_RANK_UPDATE (*integer* _skillLineId_, *luaindex* _rank_)
function ElderScrollsOfAlts.OnCompanionSkillRankUpdate(eventCode, skillLineId, rank )
  ElderScrollsOfAlts.debugMsg( "OnCompanionSkillRankUpdate: eventCode: '", eventCode, "' skillLineId='", tostring(skillLineId), "' rank: '", (rank), "'" )
  local companionId = GetActiveCompanionDefId() -- this right ID?
  local cname       = GetCompanionName(companionId)
  local slName      = GetSkillLineNameById(skillLineId)
  ElderScrollsOfAlts:CollectCompanionDataSkillRank(companionId, tostring(cname), skillLineId, slName, rank )
end

------------------------------
-- EVENT_COMPANION_EXPERIENCE_GAIN (*integer* _companionId_, *integer* _level_, *integer* _previousExperience_, *integer* _currentExperience_)
-- OnCompanionExperienceUpdate: eventCode: '131785' companionId: '13' level='16' prevExp: '27922'' currExp: '28059'
function ElderScrollsOfAlts.OnCompanionExperienceUpdate(eventCode, companionId, level, prevExp, currExp )
  ElderScrollsOfAlts.debugMsg( "OnCompanionExperienceUpdate: eventCode: '", eventCode, "' companionId: '", companionId, "' level='", tostring(level), "' prevExp: '", (prevExp), "'", "' currExp: '", (currExp), "'" )
  --
  local cname = GetCompanionName(companionId) --is there a RawName, so can have w/o the gender ctrl char?
  local characterGender = GetGenderFromNameDescriptor(cname)
  if(characterGender~=nil) then
	local indexstart = string.find(cname,"%^")
	if(indexstart~= nil and indexstart>0) then
		cname = cname:sub(1, indexstart-1)
	end
  end
  local level, currentExperience = GetActiveCompanionLevelInfo()
  local xplevel = GetNumExperiencePointsInCompanionLevel(level+1)
  ElderScrollsOfAlts:CollectCompanionDataLevel(companionId, tostring(cname), level, currentExperience, xplevel)
  --
end


-- COMPANIONS --

--------------------------------
-- SETUP  setup event handling
-- Called from OnAddOnLoaded
function ElderScrollsOfAlts.SetupDefaultDefaults()
  ElderScrollsOfAlts.view.accountnamecurrrent = GetDisplayName()
  if(ElderScrollsOfAlts.altData.playersorderlast == nil) then
    ElderScrollsOfAlts.altData.playersorderlast = 0
  end
  if(ElderScrollsOfAlts.savedVariables.allowsaveoddviewnames == nil) then
    ElderScrollsOfAlts.savedVariables.allowsaveoddviewnames = false
  end
  --
  -- Create view of account list
  ElderScrollsOfAlts.view.accountnames = {}
  if(ESOADatastore~=nil) then
	local list = ESOADatastore.getAccountList()
	local aString = "Account Name(s):["
	for account, serverdata in pairs(list) do
		--bar.account = dServer
		--bar.server  = dName
		ElderScrollsOfAlts.debugMsg("Account Name(s): Added= account=" , account )
		aString = aString .. account .. ","
		table.insert(ElderScrollsOfAlts.view.accountnames, account)
	end
	aString = aString .. "]"
	ElderScrollsOfAlts.outputMsg( aString )
  else 
	ElderScrollsOfAlts.outputMsg("Account Name: Added=" , ElderScrollsOfAlts.view.accountnamecurrrent )
    table.insert(ElderScrollsOfAlts.view.accountnames, ElderScrollsOfAlts.view.accountnamecurrrent)
  end
  --
  ElderScrollsOfAlts.view.pauseactivesave = false
  if(ElderScrollsOfAlts.view.viewkeyXlate==nil) then
    ElderScrollsOfAlts.view.viewkeyXlate = {}
    ElderScrollsOfAlts.view.viewkeyXlate["Assault"]       = GetString(ESOA_FULL_ASSAULT)
    ElderScrollsOfAlts.view.viewkeyXlate["Support"]       = GetString(ESOA_FULL_SUPPORT)
    ElderScrollsOfAlts.view.viewkeyXlate["Legerdemain"]   = GetString(ESOA_FULL_LEGER)
    ElderScrollsOfAlts.view.viewkeyXlate["Soul Magic"]    = GetString(ESOA_FULL_SOUL)
    ElderScrollsOfAlts.view.viewkeyXlate["Werewolf"]      = GetString(ESOA_FULL_WERE)
    ElderScrollsOfAlts.view.viewkeyXlate["Vampire"]       = GetString(ESOA_FULL_VAMP)
    ElderScrollsOfAlts.view.viewkeyXlate["Fighters Guild"] = GetString(ESOA_FULL_FIGHT)
    ElderScrollsOfAlts.view.viewkeyXlate["Mages Guild"]    = GetString(ESOA_FULL_MAGE)
    ElderScrollsOfAlts.view.viewkeyXlate["Undaunted"]      = GetString(ESOA_FULL_UNDAUNTED)
    ElderScrollsOfAlts.view.viewkeyXlate["Thieves Guild"]  = GetString(ESOA_FULL_THIEF)
    ElderScrollsOfAlts.view.viewkeyXlate["Dark Brotherhood"] = GetString(ESOA_FULL_DARK)
    ElderScrollsOfAlts.view.viewkeyXlate["Psijic Order"]   = GetString(ESOA_FULL_PSIJ)
    ElderScrollsOfAlts.view.viewkeyXlate["Scrying"]        = GetString(ESOA_FULL_SCRY)
    ElderScrollsOfAlts.view.viewkeyXlate["Excavation"]     = GetString(ESOA_FULL_EXCAV)  
    
    ElderScrollsOfAlts.view.viewkeyXlate["blacksmithing"] = GetString(ESOA_FULL_SMTH)  
    ElderScrollsOfAlts.view.viewkeyXlate["alchemy"]       = GetString(ESOA_FULL_ALC)  
    ElderScrollsOfAlts.view.viewkeyXlate["woodworking"]   = GetString(ESOA_FULL_WOOD)  
    ElderScrollsOfAlts.view.viewkeyXlate["jewelry"]       = GetString(ESOA_FULL_JC)  
    ElderScrollsOfAlts.view.viewkeyXlate["enchanting"]    = GetString(ESOA_FULL_ENCH)  
    ElderScrollsOfAlts.view.viewkeyXlate["provisioning"]  = GetString(ESOA_FULL_PROV)  
    ElderScrollsOfAlts.view.viewkeyXlate["clothing"]      = GetString(ESOA_FULL_CLTH)
  end
end

------------------------------
-- SETUP:
function ElderScrollsOfAlts.CheckInitialData()
	ElderScrollsOfAlts.debugMsg("CheckInitialData:"," Called!")
	--
	ElderScrollsOfAlts.CheckUIData()
	if(ElderScrollsOfAlts.altData.lastVersion==nil or ElderScrollsOfAlts.altData.lastVersion~=ElderScrollsOfAlts.version) then
		--upgrade?
		ElderScrollsOfAlts.outputMsg("UPGRADE: Please, backup your savedvariables before a reload or logout!!")
		ElderScrollsOfAlts.altData.lastVersion = ElderScrollsOfAlts.version
	end
	ElderScrollsOfAlts.debugMsg("CheckInitialData:"," Done!")
end

--------------------------------
-- SETUP  setup event handling
-- Called from OnAddOnLoaded
function ElderScrollsOfAlts.DelayedStart()
  ElderScrollsOfAlts.SetupDefaultColors()
  ElderScrollsOfAlts.SetupDefaultDefaults()
  --ElderScrollsOfAlts:InitializeCharts()
  ElderScrollsOfAlts.SavePlayerDataForGui(ElderScrollsOfAlts.startupload) -- DATA
  ElderScrollsOfAlts.InitializeGui()
  ElderScrollsOfAlts:RestoreUI()
  -- LMM Settings menu in Settings.lua.
  ElderScrollsOfAlts.LoadSettings()
  ElderScrollsOfAlts.LoadSettings2()
  --fix
  ElderScrollsOfAlts.savedVariables.selected.character = nil
  
  --[[	Bandits User Interface Side Panel ]]--
  if(BUI~=nil and BUI.Vars~=nil and not ElderScrollsOfAlts.view.buisetup) then
    ElderScrollsOfAlts.view.buisetup= true
    local content = {
      {
      icon		= "/esoui/art/tutorial/inventory_tabicon_quickslot_up.dds",
      tooltip	=  GetString(SI_ESOA_SHOW),
      --context	= Context menu function (optional),
      func		= function() ElderScrollsOfAlts:DoUiButtonClicked() end,
      enabled	= function() return not ElderScrollsOfAlts end,
      },
      --{icon="",tooltip="",func=function()end,enabled=true},	--Button 2, etc.
    }
    BUI.PanelAdd(content)
  end  
  --
  CHAMPION_PERKS_SCENE:RegisterCallback('StateChange',ElderScrollsOfAlts.OnChampionPerksStateChange)    
  --
  ElderScrollsOfAlts.debugMsg(ElderScrollsOfAlts.name , GetString(SI_ESOA_MESSAGE)) 
  ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
      ElderScrollsOfAlts.name .. GetString(SI_ESOA_MESSAGE)) -- Top-right alert.
end

------------------------------
-- 
function ElderScrollsOfAlts:MigrateSavedSettingsOnly()
	-- copy player to account
	-- remove players data
	-- data migrated?
end

-- EVENT
function ElderScrollsOfAlts.OnPlayerLoaded(e)
  --ElderScrollsOfAlts.debugMsg("OnPlayerLoaded:", " called") 
  --EVENT_MANAGER:UnregisterForEvent(ElderScrollsOfAlts.name, EVENT_PLAYER_ACTIVATED)
  --ElderScrollsOfAlts.debugMsg("OnPlayerLoaded:", " done")
end

-- EVENT
-- Player can be unloaded on zone change, reload, etc, but not called on QUIT/Crash
-- EVENT_PLAYER_DEACTIVATED
function ElderScrollsOfAlts.OnPlayerUnloaded(event)
  --ElderScrollsOfAlts.debugMsg("OnPlayerUnloaded:", " called")
  --zo_callLater(ElderScrollsOfAlts.SavePlayerDataForGui, 3000)-- DATA
  ElderScrollsOfAlts.SavePlayerDataForGui(ElderScrollsOfAlts.reloaded)
  --ElderScrollsOfAlts.debugMsg("OnPlayerUnloaded:", " done")
end

-- EVENT
function ElderScrollsOfAlts.OnAddOnLoaded(event, addonName)
  if addonName ~= ElderScrollsOfAlts.name then return end
  EVENT_MANAGER:UnregisterForEvent(ElderScrollsOfAlts.name, EVENT_ADD_ON_LOADED)
  CHAMPION_PERKS_SCENE:UnregisterCallback('StateChange',ElderScrollsOfAlts.OnChampionPerksStateChange)
  --(savedVariableTable, version, namespace, defaults, profile, displayName, characterName)
  ElderScrollsOfAlts.savedVariables = ZO_SavedVars:New("ElderScrollsOfAltsSavedVariables", ElderScrollsOfAlts.SV_VERSION_NAME, nil, defaultSettings)
  --(savedVariableTable, version, namespace, defaults, profile, displayName)
  ElderScrollsOfAlts.altData = ZO_SavedVars:NewAccountWide("ESOA_AltData", ElderScrollsOfAlts.SV_VERSION_NAME, nil, defaultSettingsGlobal)
  -- Try a New Multi Account Wide Format!
  --local namespace = nil
  --local profile = nil
  --local displayName = "ESOA"
  --ElderScrollsOfAlts.altData = ZO_SavedVars:NewAccountWide("ESOA_AltData", ElderScrollsOfAlts.SV_VERSION_NAME, namespace, defaultSettingsGlobal, profile,displayName)
  --
  --TODO ElderScrollsOfAlts:MigrateSavedSettingsOnly()
  --
  ElderScrollsOfAlts.allowedViewEntriesLC = {}
  for kName, kVal in pairs(ElderScrollsOfAlts.allowedViewEntries) do
    ElderScrollsOfAlts.allowedViewEntriesLC[kName] = kVal
  end
  --check/setup a bit earlier
  ElderScrollsOfAlts.CheckInitialData()
  ElderScrollsOfAlts.SetupDefaultDefaults()
  ElderScrollsOfAlts.SetupDefaultColors()
  zo_callLater(ElderScrollsOfAlts.DelayedStart, 3000)
  local eventNamespace = nil
  ------------------------------
  --EVENT_CHAMPION_PURCHASE_RESULT (number eventCode, ChampionPurchaseResult result)
  EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name,	EVENT_CHAMPION_PURCHASE_RESULT, ElderScrollsOfAlts.OnChampionPurchaseResult)
    ------------------------------
  --EVENT_QUEST_COMPLETE (number eventCode, string questName, number level, number previousExperience, number currentExperience, number championPoints, QuestType questType, InstanceDisplayType instanceDisplayType)
  EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_QUEST_COMPLETE, ElderScrollsOfAlts.OnQuestComplete)
  --EVENT_QUEST_ADDED (number eventCode, number journalIndex, string questName, string objectiveName)
  --EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_QUEST_ADDED, ElderScrollsOfAlts.OnQuestAdded)
  --EVENT_QUEST_REMOVED (number eventCode, boolean isCompleted, number journalIndex, string questName, number zoneIndex, number poiIndex, number questID)
  --EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_QUEST_REMOVED, ElderScrollsOfAlts.OnQuestRemoved)
  --EVENT_QUEST_ADVANCED (number eventCode, number journalIndex, string questName, boolean isPushed, boolean isComplete, boolean mainStepChanged)
  --EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_QUEST_ADVANCED, ElderScrollsOfAlts.OnQuestAdvanced)
  --companions
  --OnCompanionXX
  ------------------------------
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_ACTIVATED"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_ACTIVATED, ElderScrollsOfAlts.OnCompanionActivated )
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_DEACTIVATED"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_DEACTIVATED, ElderScrollsOfAlts.OnCompanionDeactivated )
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_RAPPORT_UPDATE"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_RAPPORT_UPDATE, ElderScrollsOfAlts.OnCompanionRapportUpdate )
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_SKILL_LINE_ADDED"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_SKILL_LINE_ADDED, ElderScrollsOfAlts.OnCompanionSkilllineAdded )
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_SKILL_RANK_UPDATE"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_SKILL_RANK_UPDATE, ElderScrollsOfAlts.OnCompanionSkillRankUpdate )
  
  eventNamespace = ElderScrollsOfAlts.name.."EVENT_COMPANION_EXPERIENCE_GAIN"
  EVENT_MANAGER:RegisterForEvent(eventNamespace,	EVENT_COMPANION_EXPERIENCE_GAIN, ElderScrollsOfAlts.OnCompanionExperienceUpdate )
  
  
  ------------------------------
  
  -- Slash commands must be lowercase. Set to nil to disable.
  SLASH_COMMANDS["/elderScrollsOfAlts"] = ElderScrollsOfAlts.SlashCommandHandler
  SLASH_COMMANDS["/esoa"] = ElderScrollsOfAlts.SlashCommandHandler
  -- Reset autocomplete cache to update it.
  --dunno, 'SLASH_COMMAND_AUTO_COMPLETE' doesnt work anymore?
  --SLASH_COMMAND_AUTO_COMPLETE:InvalidateSlashCommandCache()
  --debugMsg(ElderScrollsOfAlts.name .. GetString(SI_NEW_ADDON_MESSAGE2)) -- Prints to chat.
end


-- When any addon is loaded, but before UI (Chat) is loaded.
EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_ADD_ON_LOADED, ElderScrollsOfAlts.OnAddOnLoaded)
--
EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_PLAYER_DEACTIVATED, ElderScrollsOfAlts.OnPlayerUnloaded)
-- When player is ready, after everything has been loaded. (after addon loaded)
EVENT_MANAGER:RegisterForEvent(ElderScrollsOfAlts.name, EVENT_PLAYER_ACTIVATED, ElderScrollsOfAlts.OnPlayerLoaded)

--------------------------------
--EOF
--------------------------------