 
-- Name    : Vestige's Epic Quest
-- Author  : @Masteroshi430
 
VEQ = VEQ or {}
 
-- Load libraries
local LAM = LibAddonMenu2 
local LMP = LibMediaProvider
local libDialog = LibDialog
 
 
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER
local QUEST_TIMER_TEXT_COLOR = "#ffaf61"
local QUEST_TIMER_TEXT = ""
-- ***********************************************************
-- Register Dialogs
-- ***********************************************************
libDialog:RegisterDialog("VEQ", "TrackerUnlocked", "Vestige's Epic Quest is Unlocked","Tracker is currently unlocked, while unlocked you will not be able to use mouse functions.  Position the tracker where you want it on your UI, and go to Global Settings to Lock Background Position, or you can lock it now. \n\nDo you wish to lock it now?", function() VEQ.CMD_ToggleLock() end, nil)
--libDialog:RegisterDialog("VEQ","RemoveQuest",VEQ.RemoveDialog,function() Abandon(VEQ.Remove_idx) end,nil)
 
-- ***********************************************************
-- Register Fonts
-- ***********************************************************
 
LMP:Register("font", "ESO Standard Font", "$(MEDIUM_FONT)")
LMP:Register("font", "ESO Book Font", "$(ANTIQUE_FONT)")
LMP:Register("font", "ESO Tablet Font", "$(STONE_TABLET_FONT)")
 
-- -------------------------------
--  Save & Load User Variables
----------------------------------
-- Init defaults vars
local Step_Type_And = QUEST_STEP_TYPE_AND -- 1
local Step_Type_End = QUEST_STEP_TYPE_END -- 3
local Step_Type_OR = QUEST_STEP_TYPE_OR  -- 2
 
local Step_Vis_Hidden = QUEST_STEP_VISIBILITY_HIDDEN -- 2
local Step_Vis_Hint = QUEST_STEP_VISIBILITY_HINT -- 0
local Step_Vis_Optional = QUEST_STEP_VISIBILITY_OPTIONAL -- 1
 
 
VEQ.CyrodiilNumZoneIndex = 37
--**REMOVE 1.3**VEQ.QuestTimer="Quest Time"
 
 
VEQ.DEBUG = 0
 
SLASH_COMMANDS["/veq_debug1"] = VEQ.CMD_DEBUG1
SLASH_COMMANDS["/veq_debug2"] = VEQ.CMD_DEBUG2
SLASH_COMMANDS["/veq_debug3"] = VEQ.CMD_DEBUG3
SLASH_COMMANDS["/veq_debug4"] = VEQ.CMD_DEBUG4
SLASH_COMMANDS["/veq_resetpos"] = VEQ.CMD_Position
SLASH_COMMANDS["/veq_lock"] = VEQ.CMD_ToggleLock
 
 
VEQ.CyrodiilNumZoneIndex = 37
VEQ.QuestTimer="Quest Time"
 
VEQ.totalMiniQuests = 0
 
 
 
 
 
 
-- Build and structure the box  ?? Did AddNewUIBox cause the issue with missings steps ??
 
function VEQ.AddNewUIBox()
 
	if not VEQ.box[VEQ.boxmarker] then
		local dir = VEQ.SavedVars.DirectionBox
		local myboxdirection = BOTTOMLEFT
		if dir == "BOTTOM" then
			myboxdirection = BOTTOMLEFT
		elseif dir == "TOP" then
			myboxdirection = TOPLEFT
		end
		-- Create Contener box
		VEQ.box[VEQ.boxmarker] = WM:CreateControl(nil, VEQ.bg, CT_CONTROL) -- CT_LABEL
		VEQ.box[VEQ.boxmarker]:ClearAnchors()
		if VEQ.boxmarker == 1 then
			VEQ.box[VEQ.boxmarker]:SetAnchor(TOPLEFT,VEQ.boxqtimer, myboxdirection, 0, -15)
		else
			VEQ.box[VEQ.boxmarker]:SetAnchor(TOPLEFT,VEQ.box[VEQ.boxmarker-1],myboxdirection,0,0)
		end
		VEQ.box[VEQ.boxmarker]:SetResizeToFitDescendents(true)
		-- Create Icon Box
		VEQ.icon[VEQ.boxmarker] = WM:CreateControl(nil, VEQ.bg, CT_TEXTURE)
		VEQ.icon[VEQ.boxmarker]:ClearAnchors()
		VEQ.icon[VEQ.boxmarker]:SetAnchor(TOPRIGHT,VEQ.box[VEQ.boxmarker],TOPLEFT,0,0)
		VEQ.icon[VEQ.boxmarker]:SetDimensions(VEQ.SavedVars.QuestIconSize, VEQ.SavedVars.QuestIconSize)
		VEQ.icon[VEQ.boxmarker]:SetDrawLayer(1)
		-- Create Title Box
		VEQ.textbox[VEQ.boxmarker] = WM:CreateControl(nil, VEQ.box[VEQ.boxmarker] , CT_LABEL)
		VEQ.textbox[VEQ.boxmarker]:ClearAnchors()
		VEQ.textbox[VEQ.boxmarker]:SetAnchor(CENTER,VEQ.box[VEQ.boxmarker],CENTER,0,0)
		VEQ.textbox[VEQ.boxmarker]:SetDrawLayer(1)
	end
end
 
 
 
 
 
 
 
 
-- Add New quest Title & icon
function VEQ.AddNewTitle(qindex, qlevel, qname, qtype, qzone, qfocusedzoneval)
 
	-- Generate a new box if not exist one
	VEQ.AddNewUIBox()
	-- Refresh content
 
	VEQ.box[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
	VEQ.textbox[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.TitlePadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.TitlePadding,-1)
	VEQ.textbox[VEQ.boxmarker]:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.TitleFont), VEQ.SavedVars.TitleSize, VEQ.SavedVars.TitleStyle))
 
	-- if VEQ.SavedVars.PositionLockOption == true then
		if not VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
			VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(true)
		end
		VEQ.textbox[VEQ.boxmarker]:SetHandler("OnMouseDown", function(self, click)
			VEQ.MouseController(click, qindex, qname)
		end)
	-- else
		-- if VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
			-- VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(false)
		-- end
		-- VEQ.textbox[VEQ.boxmarker]:SetHandler()
	-- end	
 
	local CurrentFocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,qindex,0)
	if CurrentFocusedQuest == true then
		VEQ.box[VEQ.boxmarker]:SetAlpha(1)
		VEQ.currentAssistedArea = VEQ.currentAreaBox
		if VEQ.SavedVars.QuestIconOption then
			VEQ.icon[VEQ.boxmarker]:SetColor(VEQ.SavedVars.QuestIconColor.r,VEQ.SavedVars.QuestIconColor.g,VEQ.SavedVars.QuestIconColor.b,VEQ.SavedVars.QuestIconColor.a)
			VEQ.icon[VEQ.boxmarker]:SetHidden(false)
			VEQ.currenticon = qindex
		else
			VEQ.icon[VEQ.boxmarker]:SetHidden(true)
		end
	else
		--VEQ.icon[VEQ.boxmarker]:SetHidden(true)
		if VEQ.SavedVars.QuestIconOption then
			VEQ.icon[VEQ.boxmarker]:SetColor(VEQ.SavedVars.QuestIconColor.r,VEQ.SavedVars.QuestIconColor.g,VEQ.SavedVars.QuestIconColor.b,VEQ.SavedVars.QuestIconColor.a)
			VEQ.icon[VEQ.boxmarker]:SetHidden(false)
			--VEQ.currenticon = qindex
		else
			VEQ.icon[VEQ.boxmarker]:SetHidden(true)
		end
		
		if VEQ.QuestsNoFocusOption == false then
			VEQ.box[VEQ.boxmarker]:SetAlpha(1)
		else
			if VEQ.FocusedQuestAreaNoTrans == true and qfocusedzoneval == 1 then
				VEQ.box[VEQ.boxmarker]:SetAlpha(1)
			else
				VEQ.box[VEQ.boxmarker]:SetAlpha(VEQ.SavedVars.QuestsNoFocusTransparency/100)
			end
		end	
	end
	-- Set qname to add in quest type if selected
	-- sub first two lines with saved vars item
 
	 local classID = GetUnitClassId("player")
	 local alliance = GetUnitAlliance("player")
	 local allianceColor = GetAllianceColor(alliance)
 
	 --repeatType = GetJournalQuestRepeatType(qindex)
	 local qname, backgroundText, activeStepText, activeStepType, activeStepTrackerOverrideText, completed, tracked, qlevel, pushed, qtype, qInstanceDisplayType = GetJournalQuestInfo(qindex)
	 --local qzone, qobjective, qzoneidx, qPoiIndex = GetJournalQuestLocationInfo(qindex)
	 --local normalizedX, normalizedZ, poiPinType, icon = GetPOIMapInfo(qPoiIndex)
 
	 --poiType = GetPOIType(qPoiIndex)
	--if VEQ.QuestsHybridOption == false or VEQ.QuestsAreaOption == false then
	
	
	local qRepeatType = GetJournalQuestRepeatType(qindex)
	
	if qRepeatType == QUEST_REPEAT_NOT_REPEATABLE then
		 VEQ.icon[VEQ.boxmarker]:SetColor(1,1,1,1) 
	else
	    VEQ.icon[VEQ.boxmarker]:SetColor(107/255,182/255,181/255,1) -- repeatable green
    end	
	
	    if qInstanceDisplayType == ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON then 
		       VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_endlessdungeon.dds")
		elseif qInstanceDisplayType == ZONE_DISPLAY_TYPE_ADVENTURE_ZONE then 
		       VEQ.icon[VEQ.boxmarker]:SetTexture("EsoUI/Art/Icons/mapKey/mapKey_adventureZone.dds")
    elseif qtype == QUEST_TYPE_AVA or qtype == QUEST_TYPE_AVA_GRAND or qtype == QUEST_TYPE_AVA_GROUP then -- 64*64 icons
		    if alliance == ALLIANCE_ALDMERI_DOMINION then
			   VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/stats/alliancebadge_aldmeri.dds")
            elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then
			   VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/stats/alliancebadge_daggerfall.dds") 
            elseif alliance == ALLIANCE_EBONHEART_PACT then
			   VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/stats/alliancebadge_ebonheart.dds")
            else 
			   VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_keep_complete.dds")
            end 
			VEQ.icon[VEQ.boxmarker]:SetColor(allianceColor:UnpackRGB())
        elseif qtype == QUEST_TYPE_UNDAUNTED_PLEDGE then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_undaunted.dds")
		elseif qtype == QUEST_TYPE_GUILD then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/guildranks/guild_rankicon_misc10_large.dds")
			if VEQ.GetQuestLine(qname) then
			    local guildIcon = VEQ.GetQuestLine(qname)
				if guildIcon == VEQ.mylanguage.lang_tracker_type_dark_brotherhood then
				    VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_darkbrotherhood.dds")
				elseif guildIcon == VEQ.mylanguage.lang_tracker_type_thieves_guild then
				    VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_thievesguild.dds")
				elseif guildIcon == VEQ.mylanguage.lang_tracker_type_mages_guild then
				     VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_magesguild.dds")
				elseif guildIcon == VEQ.mylanguage.lang_tracker_type_fighters_guild then
				     VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_fightersguild.dds")
				elseif guildIcon == VEQ.mylanguage.lang_tracker_type_undaunted then
				     VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_undaunted.dds")
				elseif guildIcon == VEQ.mylanguage.lang_tracker_type_psijic_order then
				     VEQ.icon[VEQ.boxmarker]:SetTexture("VEQ/art/icons/white_psijic_64.dds") 
				end
			end   
		elseif qtype == QUEST_TYPE_MAIN_STORY then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/tutorial/poi_soloinstance_complete.dds") 
		elseif qtype == QUEST_TYPE_CLASS then
		    VEQ.icon[VEQ.boxmarker]:SetTexture(ZO_GetGamepadClassIcon(classID)) 
		elseif qtype == QUEST_TYPE_COMPANION then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/dye/gamepad/dye_tabicon_companioncostumedye.dds")
		elseif qtype == QUEST_TYPE_PROLOGUE then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/treeicons/gamepad/achievement_categoryicon_prologue.dds")
		elseif qtype == QUEST_TYPE_CRAFTING then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/tutorial/poi_crafting_complete.dds")
		elseif qtype == QUEST_TYPE_GROUP then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_grouparea.dds")
		elseif qtype == QUEST_TYPE_DUNGEON then
         if qInstanceDisplayType == ZONE_DISPLAY_TYPE_SOLO  then 
			      VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_solotrial_complete.dds") 
         elseif qInstanceDisplayType == ZONE_DISPLAY_TYPE_SOLO_DUNGEON  then 
			      VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/journal/gamepad/gp_journal_quest_solo_dungeon.dds") 
         else 
			      VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_groupinstance_complete.dds")
			   end
		elseif qtype == QUEST_TYPE_RAID then
            VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_raiddungeon_complete.dds") 
		elseif qtype == QUEST_TYPE_BATTLEGROUND then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_group_battleground_complete.dds")
		elseif qtype == QUEST_TYPE_HOLIDAY_EVENT then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/mapkey/mapkey_events.dds")
		elseif qtype == QUEST_TYPE_QA_TEST then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/journal/u26_progress_digsite_unknown_complete.dds")
		elseif qtype == QUEST_TYPE_TRIBUTE then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/servicemappins/servicepin_talesoftribute.dds")
		elseif qtype == QUEST_TYPE_SCRIBING then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/crafting/gamepad/gp_crafting_menuicon_scribing.dds")
		elseif qtype == QUEST_TYPE_TAMRIEL_TALE then
			VEQ.icon[VEQ.boxmarker]:SetTexture("VEQ/art/icons/tamriel_tales_wide.dds")
		elseif qtype == QUEST_TYPE_FAVOR then
			VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/journal/gamepad/gp_questtypeicon_repeatable_favor.dds")
    elseif qtype == QUEST_TYPE_NONE then
			if qInstanceDisplayType == ZONE_DISPLAY_TYPE_RAID  then 
			    VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/icons/poi/poi_raiddungeon_complete.dds")
			else
				VEQ.icon[VEQ.boxmarker]:SetTexture("esoui/art/writadvisor/advisor_trackedpin_icon.dds") -- regular quest pin
			end
		end

		
		--hide quest icon if it is the same as the previous one  
		if CurrentFocusedQuest == true then  
		     VEQ.previousIconType = qtype
		else
		    if qtype == VEQ.previousIconType then
			   VEQ.icon[VEQ.boxmarker]:SetHidden(true)
			end
			
			VEQ.previousIconType = qtype
		end
 
	--end
	VEQ.textbox[VEQ.boxmarker]:SetText(qname)
	VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TitleColor.r, VEQ.SavedVars.TitleColor.g, VEQ.SavedVars.TitleColor.b, VEQ.SavedVars.TitleColor.a)
	VEQ.textbox[VEQ.boxmarker]:SetAnchor(CENTER,VEQ.box[VEQ.boxmarker],CENTER,0,0)
	VEQ.boxmarker = VEQ.boxmarker + 1
end
 
 
 
 
 
 
 
 
 
 
 
 
 
-- Check content is used when new content is being added, only add what is not selected to be hidden.  Called by AddNewContent().
-- Done seperate to help keep it cleaner as the options grew.
 
function VEQ.CheckContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	if qcmytype == 2 and VEQ.SavedVars.HideCompleteObjHints == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 3 and VEQ.SavedVars.HideOptionalInfo == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 4 and VEQ.SavedVars.HideCompleteObjHints == false and VEQ.SavedVars.HideOptionalInfo == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 5 then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 6 and VEQ.SavedVars.HideCompleteObjHints == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 7 and VEQ.SavedVars.HideHintsOption == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 8 and VEQ.SavedVars.HideCompleteObjHints == false and VEQ.SavedVars.HideHintsOption == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 9 and VEQ.SavedVars.HideHiddenOptions == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 10 and VEQ.SavedVars.HideCompleteObjHints == false and VEQ.SavedVars.HideHiddenOptions == false and VEQ.HideInfoHintsOption == false then
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	elseif qcmytype == 1 then 
		VEQ.AddNewContent(qcindex, qcstep, qctext, qcmytype, qczone, qcfocusedzoneval, qcJournalText)
	end
end
 
 
 
 
 
 
 
 
-- add new list of quest objectives
function VEQ.AddNewContent(qindex, qstep, qtext, mytype, qzone, qfocusedzoneval, qjournaltext)
	local mytype = mytype
	-- Generate a new box if not exist one
	VEQ.AddNewUIBox()
 
	VEQ.box[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
	VEQ.icon[VEQ.boxmarker]:SetHidden(true)
	VEQ.textbox[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.TextPadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.TextPadding,-1)
	VEQ.textbox[VEQ.boxmarker]:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.TextFont), VEQ.SavedVars.TextSize, VEQ.SavedVars.TextStyle))
 
    local qname = GetJournalQuestName(qindex)
	--if VEQ.SavedVars.PositionLockOption == true then
		if not VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
			VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(true)
		end
		VEQ.textbox[VEQ.boxmarker]:SetHandler("OnMouseDown", function(self, click)
			
			VEQ.MouseController(click, qindex, qname)
		end)
	-- else
		-- if VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
			-- VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(false)
		-- end
		-- VEQ.textbox[VEQ.boxmarker]:SetHandler()
	-- end	
	local CurrentFocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,qindex,0)
 
	-- Quest conditions/steps assigment of mytype
	-- 1  = Objective
	-- 2  = Objective Completed
	-- 3  = Optional Objective 
	-- 4  = Optional Objective Completed
	-- 5  = Objective Or
	-- 6  = Objective Or Completed
	-- 7  = Hint
	-- 8  = Hint Completed
	-- 9  = Hiddewn Hint
	-- 10 = Hidden Hint Completed
	
	-- 3 keeps
	if qname == GetQuestName(3431) and VEQ.CharSavedVars.ThreeKeeps and VEQ.CharSavedVars.ThreeKeeps ~= "" then
	   qtext = string.format("%s\n%s", qtext, VEQ.CharSavedVars.ThreeKeeps)
	-- 9 resources
	elseif qname == GetQuestName(6208) and VEQ.CharSavedVars.NineResources and VEQ.CharSavedVars.NineResources ~= "" then
	    qtext = string.format("%s\n%s", qtext, VEQ.CharSavedVars.NineResources)
	end
	
  -- immersive text
  if qjournaltext and VEQ.SavedVars.HideInfoHintsOption == false and VEQ.SavedVars.HideImmersiveText == false and VEQ.alreadyWroteImmeriveText ~= qjournaltext and mytype ~= 2 and mytype ~= 4 and mytype ~= 6 and mytype ~= 8 and mytype ~= 10 then
	    VEQ.alreadyWroteImmeriveText = qjournaltext
      qjournaltext = string.format("%s\n", qjournaltext)
  else
      qjournaltext = ""
  end
 
	if mytype == 2 then 
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TextCompleteColor.r, VEQ.SavedVars.TextCompleteColor.g, VEQ.SavedVars.TextCompleteColor.b,VEQ.SavedVars.TextCompleteColor.a)
	elseif mytype == 3 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/buttons/gamepad/gp_plus.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TextOptionalColor.r, VEQ.SavedVars.TextOptionalColor.g, VEQ.SavedVars.TextOptionalColor.b, VEQ.SavedVars.TextOptionalColor.a)
	elseif mytype == 4 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/buttons/gamepad/gp_plus.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TextOptionalCompleteColor.r, VEQ.SavedVars.TextOptionalCompleteColor.g, VEQ.SavedVars.TextOptionalCompleteColor.b, VEQ.SavedVars.TextOptionalCompleteColor.a)
	elseif mytype == 5 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TextColor.r, VEQ.SavedVars.TextColor.g, VEQ.SavedVars.TextColor.b, VEQ.SavedVars.TextColor.a)
	elseif mytype == 6 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.CompleteTextColor.r, VEQ.SavedVars.CompleteTextColor.g, VEQ.SavedVars.TextCompleteColor.b, VEQ.SavedVars.TextCompleteColor.a)
	elseif mytype == 7 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s: %s",qjournaltext, VEQ.mylanguage.quest_hint, qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.HintColor.r, VEQ.SavedVars.HintColor.g, VEQ.SavedVars.HintColor.b, VEQ.SavedVars.HintColor.a)
	elseif mytype == 8 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s(%s)", qjournaltext, qtext)) 
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.HintCompleteColor.r, VEQ.SavedVars.HintCompleteColor.g, VEQ.SavedVars.HintCompleteColor.b, VEQ.SavedVars.HintCompleteColor.a)
	elseif mytype == 9 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s(%s)", qjournaltext, qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.HintColor.r, VEQ.SavedVars.HintColor.g, VEQ.SavedVars.HintColor.b, VEQ.SavedVars.HintColor.a)
	elseif mytype == 10 then
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s: %s",qjournaltext, VEQ.mylanguage.quest_hiddenhint, qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.HintCompleteColor.r, VEQ.SavedVars.HintCompleteColor.g, VEQ.SavedVars.HintCompleteColor.b, VEQ.SavedVars.HintCompleteColor.a)
	else
		VEQ.textbox[VEQ.boxmarker]:SetText(string.format("%s%s%s", qjournaltext, zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), qtext))
		VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.TextColor.r, VEQ.SavedVars.TextColor.g, VEQ.SavedVars.TextColor.b, VEQ.SavedVars.TextColor.a)
	end
 
	if CurrentFocusedQuest == true then
		VEQ.box[VEQ.boxmarker]:SetAlpha(1)
	else
		if VEQ.QuestsNoFocusOption == false then
			VEQ.box[VEQ.boxmarker]:SetAlpha(1)
		else
			if CurrentFocusedQuest == true then
				VEQ.box[VEQ.boxmarker]:SetAlpha(1)
			else
				if VEQ.FocusedQuestAreaNoTrans == true and qfocusedzoneval == 1 then
					VEQ.box[VEQ.boxmarker]:SetAlpha(1)
				else
					VEQ.box[VEQ.boxmarker]:SetAlpha(VEQ.SavedVars.QuestsNoFocusTransparency/100)
				end
			end
		end	
	end
 
	VEQ.boxmarker = VEQ.boxmarker + 1
end
 
 
 
 
 
 
 
--=======================================
-- Quest Timer
--=======================================
function VEQ.HideQuestTimer()
	VEQ.boxqtimer:SetHidden(true)
	EM:UnregisterForUpdate("VEQ_Update_Timer")
	VEQ.isTimedQuest = false
	if VEQ.SavedVars.ShowClockOption == true then VEQ.clockInfos:SetHidden(false) end
end
 
function VEQ.UpdateQuestTime(_timerEnd, isPaused, i)

	local RemainingTime = _timerEnd - GetFrameTimeSeconds()
 
	if RemainingTime > 0 then
		local TimeText, NextUpdate = ZO_FormatTime(RemainingTime, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
		VEQ.QuestTimer = string.format("|t24:24:esoui/art/tutorial/timer_icon.dds|t%s", TimeText)
		VEQ.isTimedQuest = true
		-- Should already be done at build of box
		VEQ.boxqtimer:SetColor(VEQ.SavedVars.TimerTitleColor.r, VEQ.SavedVars.TimerTitleColor.g, VEQ.SavedVars.TimerTitleColor.b, VEQ.SavedVars.TimerTitleColor.a)
		--VEQ.ClearQTimer(true)
		VEQ.boxqtimer:SetColor(VEQ.SavedVars.TimerTitleColor.r, VEQ.SavedVars.TimerTitleColor.g, VEQ.SavedVars.TimerTitleColor.b, VEQ.SavedVars.TimerTitleColor.a)
		VEQ.boxqtimer:SetText(VEQ.QuestTimer)
		if VEQ.SavedVars.ShowClockOption == true then VEQ.clockInfos:SetHidden(true) end
		if VEQ.DEBUG == 3 then d(VEQ.QuestTimer) end
	else
		VEQ.HideQuestTimer()
	end
 
end
 
function VEQ.ShowQuestTimer(_timerEnd, isPaused, i)
	--DebugMessage--
	if VEQ.DEBUG == 3 then d("ShowQuestTimer") end
  EM:RegisterForUpdate("VEQ_Update_Timer", 1000, function() VEQ.UpdateQuestTime(_timerEnd, isPaused) end)
	VEQ.isTimedQuest = true
	VEQ.boxqtimer:SetHidden(false)
	VEQ.boxqtimer:SetAlpha(1)
	VEQ.UpdateQuestTime(_timerEnd, isPaused, i)
	if VEQ.SavedVars.ShowClockOption == true then VEQ.clockInfos:SetHidden(true) end
end
 
 
function VEQ.GetQuestTimer(i)
	local TimerStart, _timerEnd, isVisible, isPaused = GetJournalQuestTimerInfo(i) 
  
	--DebugMessage QT
	if VEQ.DEBUG == 3 then 
		d(string.format("**Timer ** QuestTimer: idx %s  Start: %s  End: %s", i, TimerStart, _timerEnd)) 
	end
  
	if isVisible or _timerEnd > GetFrameTimeSeconds() then
		local CurrentFocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,i,0)
		if CurrentFocusedQuest then
			VEQ.isTimedQuest = true
			--VEQ.idxTimedQuest = i
			VEQ.ShowQuestTimer(_timerEnd, isPaused, i)
			VEQ.clockInfos:SetHidden(true)	
		end
	else
		VEQ.isTimedQuest = false
		if VEQ.SavedVars.ShowClockOption == true then
       VEQ.clockInfos:SetHidden(false)
    end
		  --VEQ.boxqtimer:SetHidden(true)
	end
end	
 
 
 
 
 
 
 
-- **************************************************************************************
--            Refresh 
-- **************************************************************************************
 
-- --------------------------------------------------------------------------------------
-- Load Quest Info
-- --------------------------------------------------------------------------------------
 
function VEQ.LoadQuestsInfo(i)
	-- *********************************************************************
	-- Builds QuestList
	-- Uses VEQ.DEBUG == 1 for output
	-- *********************************************************************
 
	-- Grab initial quest information
	local qname, backgroundText, activeStepText, activeStepType, activeStepTrackerOverrideText, completed, tracked, qlevel, pushed, qtype, qInstanceDisplayType = GetJournalQuestInfo(i)
		if (qname ~= nil and #qname > 0) then
		-- If valid quest grab the location information and do debug output if needed
			local qzone, qobjective, qzoneidx, qPoiIndex = GetJournalQuestLocationInfo(i)
      VEQ.HideQuestTimer()
			VEQ.GetQuestTimer(i)
			-- Collect infos for table sort
			qzone = #qzone > 0 and zo_strformat(SI_QUEST_JOURNAL_ZONE_FORMAT, qzone) or zo_strformat(SI_QUEST_JOURNAL_GENERAL_CATEGORY)
			--qzone = #qzone > 0 and zo_strformat(SI_QUEST_JOURNAL_ZONE_FORMAT, qzone)
			VEQ.MyPlayerLevel = GetUnitLevel('player')
			VEQ.MyPlayerVLevel = GetUnitChampionPoints('player')
			-- ----------------------------------------------------------
			-- Start of VEQ.QuestList Generation
			-- ----------------------------------------------------------
			if not qzoneidx or qzoneidx == 294967291 then qzoneidx = string.format("misc%s", qtype) end -- handle "miscellaneous" type quests (with no zone id) by quest type for the intelligent multiquest tracker
			VEQ.QuestList[VEQ.varnumquest] = {}
			VEQ.QuestList[VEQ.varnumquest].index = i
			VEQ.QuestList[VEQ.varnumquest].zoneidx = qzoneidx
			VEQ.QuestList[VEQ.varnumquest].zone = qzone
			VEQ.QuestList[VEQ.varnumquest].instanceDisplayType = qInstanceDisplayType or "nil"
			VEQ.QuestList[VEQ.varnumquest].poiIndex = qPoiIndex or "nil"
			VEQ.QuestList[VEQ.varnumquest].level = GetJournalQuestLevel(i)
			VEQ.QuestList[VEQ.varnumquest].name = qname
			VEQ.QuestList[VEQ.varnumquest].type = qtype
			VEQ.QuestList[VEQ.varnumquest].tracked = tracked
 
			local qRepeatType = GetJournalQuestRepeatType(i)
 
			-- My Zone Determinate
			VEQ.QuestList[VEQ.varnumquest].myzone = VEQ.FindMyZone(qzone,qtype,qInstanceDisplayType,qRepeatType,qname,qzoneidx)
 
			-- Check to see if the current quest is current focused quest, set QuestList[x].focusquest to 1 if focused quest else zero.
			if i == VEQ.FocusedQIndex then VEQ.QuestList[VEQ.varnumquest].focusquest = 1 else VEQ.QuestList[VEQ.varnumquest].focusquest = 0 end
			VEQ.QuestList[VEQ.varnumquest].focusedzone = VEQ.FocusedMyZone
			-- focused zone set
			if VEQ.FocusedMyZone == VEQ.QuestList[VEQ.varnumquest].myzone then
				VEQ.QuestList[VEQ.varnumquest].focusedzoneval = 1
			else
				VEQ.QuestList[VEQ.varnumquest].focusedzoneval = 0
			end
 
			--Quest Steps
			VEQ.QuestList[VEQ.varnumquest].step = {}
			local k = 1
			local condcheck2 = {}
			local nbStep = GetJournalQuestNumSteps(i)
 
			for idx=1, nbStep do
 
				-- If active step 
				-- 		QUEST_STEP_TYPE_AND 			= 1
				--		QUEST_STEP_TYPE_BRANCH 			= 4
				--		QUEST_STEP_TYPE_END 			= 3
				--		QUEST_STEP_TYPE_ITERATION_BEGIN = 1
				--		QUEST_STEP_TYPE_ITERATION_END 	= 4
				--		QUEST_STEP_TYPE_OR = 2
				if activeStepType == QUEST_STEP_TYPE_END then
					local goal, dialog, confirmComplete, declineComplete, backgroundText, journalStepText = GetJournalQuestEnding(i)
					if (goal ~= nil and goal ~= "") then
 
						if not VEQ.QuestList[VEQ.varnumquest].step[k] then
							VEQ.QuestList[VEQ.varnumquest].step[k] = {}
						end
						VEQ.QuestList[VEQ.varnumquest].step[k].text = goal
						VEQ.QuestList[VEQ.varnumquest].step[k].mytype = 1
						k = k + 1
					end
				else
					local qstep, visibility, stepType, trackerOverrideText, numConditions = GetJournalQuestStepInfo(i,idx)
					if (qstep ~= nil) then
            local mytype = 1 
						if visibility == nil or visibility == QUEST_STEP_VISIBILITY_HINT or visibility == QUEST_STEP_VISIBILITY_OPTIONAL or visibility == QUEST_STEP_VISIBILITY_HIDDEN then
							--**REMOVE 1.3**if ((visibility == 0 or visibility == 1 or visibility == 2) and VEQ.HideInfoHintsOption == false) then
							if ((visibility == nil or visibility == QUEST_STEP_VISIBILITY_HIDDEN or visibility == QUEST_STEP_VISIBILITY_HINT or visibility == QUEST_STEP_VISIBILITY_OPTIONAL) and VEQ.SavedVars.HideInfoOptionalObjOption == true) then
								-- QUEST_STEP_VISIBILITY_OPTIONAL = 1 Optional
								if visibility == QUEST_STEP_VISIBILITY_OPTIONAL then
									mytype = 3
								-- QUEST_STEP_VISIBILITY_HIDDEN 2
								elseif visibility == QUEST_STEP_VISIBILITY_HIDDEN then
									mytype = 9
								-- QUEST_STEP_VISIBILITY_HINT
								else
									mytype = 7
								end
								if not VEQ.QuestList[VEQ.varnumquest].step[k] then
									  VEQ.QuestList[VEQ.varnumquest].step[k] = {}
								end
								VEQ.QuestList[VEQ.varnumquest].step[k].text = qstep
								VEQ.QuestList[VEQ.varnumquest].step[k].mytype = mytype
 
								k = k + 1
							else
								local checkstep = ""
								--Conditions start
								for m=1, numConditions do
									local conditionText, current, max, isFailCondition, isComplete, isCreditShared = GetJournalQuestConditionInfo(i, idx, m)
 
									if conditionText ~= nil and conditionText ~= "" then
										-- if it is QUEST_STEP_TYPE_OR active step (2) and current step (idx) > nbStep then break out
										if activeStepType == QUEST_STEP_TYPE_OR then
											if idx >= nbStep and idx > 1 then
 
												break;
											end
										end
										-- checkstep starts as "" so not equal to qstep
										-- Quest conditions/steps assigment of mytype
										-- 1  = Objective
										-- 2  = Objective Completed
										-- 3  = Optional
										-- 4  = Optional Completed
										-- 5  = Optional OR Objective
										-- 6  = Optional OR Objective Completed
										-- 7  = Hint
										-- 8  = Hint Completed
										-- 9  = Hidden Hint
										-- 10 = Hidden Hint Completed
										if checkstep ~= qstep then
											if visibility == QUEST_STEP_VISIBILITY_OPTIONAL then
											-- Optional quests infos
												if isComplete ~= true then mytype = 3 else mytype = 4 end
											-- quests hints infos
											elseif visibility == QUEST_STEP_VISIBILITY_HINT then
												if isComplete ~= true then mytype = 7 else mytype = 8 end
											-- hidden quests hints infos
											elseif visibility == QUEST_STEP_VISIBILITY_HIDDEN then
												if isComplete ~= true then mytype = 9 else mytype = 10 end
											end
											-- if anything but nil visibility
											if visibility == QUEST_STEP_VISIBILITY_OPTIONAL or visibility == QUEST_STEP_VISIBILITY_HINT or visibility == QUEST_STEP_VISIBILITY_HIDDEN then
												if not VEQ.QuestList[VEQ.varnumquest].step[k] then
													VEQ.QuestList[VEQ.varnumquest].step[k] = {}
												end
												checkstep = qstep
												table.insert(condcheck2, qstep)
 
												VEQ.QuestList[VEQ.varnumquest].step[k].text = qstep
												VEQ.QuestList[VEQ.varnumquest].step[k].mytype = mytype
												k = k + 1
											end
 
										end
										if checkstep ~= conditionText then
											if isComplete ~= true then
												if visibility == QUEST_STEP_VISIBILITY_OPTIONAL then
													mytype = 3
												elseif visibility == QUEST_STEP_VISIBILITY_HINT then
													mytype = 7
												elseif visibility ==QUEST_STEP_VISIBILITY_HIDDEN then
													mytype = 9
												elseif visibility == nil and stepType == QUEST_STEP_TYPE_OR then
													mytype = 5
												else
													mytype = 1
												end
												local conditionTextClean = conditionText:match("TRACKER GOAL TEXT*")
												local condcheckmulti = true
 
												for key,value in pairs(condcheck2) do
													--if ((value == conditionText and visibility ~= nil) or (value:find(conditionText, 1, true) and visibility ~= nil) or stepType == 2) then
													if ((value == conditionText and visibility ~= nil) or (value:find(conditionText, 1, true) and visibility ~= nil)) then
														condcheckmulti = false
													end
												end
												if conditionTextClean == nil and condcheckmulti == true then
													if not VEQ.QuestList[VEQ.varnumquest].step[k] then
														VEQ.QuestList[VEQ.varnumquest].step[k] = {}
													end
													table.insert(condcheck2, conditionText)
													checkstep = conditionText
 
													VEQ.QuestList[VEQ.varnumquest].step[k].text = conditionText
													VEQ.QuestList[VEQ.varnumquest].step[k].mytype = mytype
                          if qstep ~= "" then
                             VEQ.QuestList[VEQ.varnumquest].step[k].journalText = qstep
                          end
													k = k + 1
												end
											else
												if visibility == QUEST_STEP_VISIBILITY_OPTIONAL then
													mytype = 4
												elseif visibility == QUEST_STEP_VISIBILITY_HINT then
													mytype = 8
												elseif visibility == QUEST_STEP_VISIBILITY_HIDDEN then
													mytype = 10
												elseif visibility == nil and stepType == QUEST_STEP_TYPE_OR then
													mytype = 6
												else
													mytype = 2
												end
												local conditionTextClean = conditionText:match("TRACKER GOAL TEXT*")
												local condcheckmulti = true
 
												for key,value in pairs(condcheck2) do
													--if ((value == conditionText and visibility ~= nil) or (value:find(conditionText, 1, true) and visibility ~= nil) or stepType == 2) then
													if ((value == conditionText and visibility ~= nil) or (value:find(conditionText, 1, true) and visibility ~= nil)) then
														condcheckmulti = false
													end
												end
												if conditionTextClean == nil and condcheckmulti == true then
													if not VEQ.QuestList[VEQ.varnumquest].step[k] then
														VEQ.QuestList[VEQ.varnumquest].step[k] = {}
													end
													checkstep = conditionText
													table.insert(condcheck2, conditionText)
 
													VEQ.QuestList[VEQ.varnumquest].step[k].text = conditionText
													VEQ.QuestList[VEQ.varnumquest].step[k].mytype = mytype
                          if qstep ~= "" then
                             VEQ.QuestList[VEQ.varnumquest].step[k].journalText = qstep
                          end
													k = k + 1
												end
											end
										end
									end
								end
							end
						end
					end
				end
				if VEQ.DEBUG == 1 then d("+") end
			end
 
		VEQ.varnumquest = VEQ.varnumquest + 1
	end
end
 
 
------ add miniquest to table
function VEQ.LoadMiniQuestsInfo(index, uniqueId, name, objective, zone, texture, bagId, slotIndex, zoneId, iconColor, timeLimit) -- hereherehere
 
  if index == 2 or index == 4 or index == 8 or index == 22 or index == 24 then -- 2 is zone todo list, 4 is Rumors, 8 is Tamriel tomes, 22 is Golden pursuits, 24 is community events
 
 
     VEQ.MiniQuestList[uniqueId] = {}
	   VEQ.MiniQuestList[uniqueId].index = index
     VEQ.MiniQuestList[uniqueId].zone = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, zone)
     VEQ.MiniQuestList[uniqueId].objective = objective
     VEQ.MiniQuestList[uniqueId].name = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, name)
	   VEQ.MiniQuestList[uniqueId].texture = texture
	   VEQ.MiniQuestList[uniqueId].bagId = bagId or 0
	   VEQ.MiniQuestList[uniqueId].slotIndex = slotIndex or 0
	   VEQ.MiniQuestList[uniqueId].zoneId = zoneId or 0
	   VEQ.MiniQuestList[uniqueId].iconColor = iconColor or 0
	   VEQ.MiniQuestList[uniqueId].timeLimit = timeLimit or 0
 
  else  -- 1 is inventory, 3 is skyshards, 5 is riding skills, 6 is Backpack upgrade, 7 is Bank space upgrade, 9 is envent tickets, 10 is Transmute crystals
	      -- 11 is free, 12 is activity tracker, 13 is alliance war queue, 14 is poison, 15 is Psijic Time Breaches Helper, 16 is group frames, 17 is dailies/weeklies limit
		  -- 18 is dungeon reward timer, 19 is battleground reward timer, 20 is tribute reward timer, 21 is fishing achievements, 23 is nearly done achievements 
 
     VEQ.MiniQuestList[index] = {}
	   VEQ.MiniQuestList[index].index = index
     VEQ.MiniQuestList[index].zone = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, zone)
     VEQ.MiniQuestList[index].objective = objective
     VEQ.MiniQuestList[index].name = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, name)
	   VEQ.MiniQuestList[index].texture = texture
	   VEQ.MiniQuestList[index].bagId =  0
	   VEQ.MiniQuestList[index].slotIndex = 0
	   VEQ.MiniQuestList[index].zoneId = zoneId or 0
     VEQ.MiniQuestList[index].iconColor = iconColor or 0
	   VEQ.MiniQuestList[index].timeLimit = timeLimit or 0
  end
 
 
   -- update table length
  if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
 
  -- newest added miniquest becomes focused miniquest
  if index ~= 2 and index ~= 8 and index ~= 17 and index ~= 22 and index ~= 24 and index ~= 23 then -- not for 2 (zone todo list), 8 (Tamriel tomes), 17 (repeatable quest counter), 22 (golden pursuits), 24 (community events), 23 achievements
     if index == 4 then
         VEQ.FocusedMiniQuest = uniqueId  -- rumor update becomes focused miniquest
     else
         VEQ.FocusedMiniQuest = index
     end
  end

end
 
 
 
function VEQ.DisplayFocusedMiniQuest()
 
		 if VEQ.MiniQuestList == nil or VEQ.totalMiniQuests == 0  then
		   if VEQ.totalMiniQuestmarker then VEQ.totalMiniQuestmarker:SetHidden(true) end
       if VEQ.MQbutton then VEQ.MQbutton:SetHidden(true) end
			 if VEQ.areaMiniQuestmarker then VEQ.areaMiniQuestmarker:SetHidden(true) end
			 if VEQ.titleMiniQuestmarker then VEQ.titleMiniQuestmarker:SetHidden(true) end
			 if VEQ.miniQuestIcon then VEQ.miniQuestIcon:SetHidden(true) end
			 if VEQ.objMiniQuestmarker then VEQ.objMiniQuestmarker:SetHidden(true) end
 
			 if VEQ.boxmarker == nil then -- fix for nil VEQ.boxmarker
		        VEQ.boxmarker = 1 
			      VEQ.AddNewUIBox()
			      VEQ.boxmarker = 2 
			      VEQ.AddNewUIBox()
		   end 
			
       -- background texture
			 if VEQ.textbox[VEQ.boxmarker-1] then
	        VEQ.bgtx:SetDimensions(VEQ.main:GetWidth()+65, (VEQ.textbox[VEQ.boxmarker-1]:GetBottom()-VEQ.main:GetTop())+150) 
       end
 
			 BATTLEGROUND_HUD_FRAGMENT.control:SetAnchor(TOPLEFT, VEQ.textbox[VEQ.boxmarker-1], BOTTOMLEFT, 0, 40) -- move battlegrounds UI at the bottom of VEQ
			 if ZO_EndDunHUDTracker then
			    ZO_EndDunHUDTracker:ClearAnchors()
			    ZO_EndDunHUDTracker:SetAnchor(TOPLEFT, VEQ.textbox[VEQ.boxmarker-1], BOTTOMLEFT, -(VEQ.main:GetWidth()-100), 40) -- move endless dungeon UI at the bottom of VEQ
			 end
			 ZO_HouseInformationTrackerTopLevel:SetAnchor(TOPLEFT, VEQ.textbox[VEQ.boxmarker-1], BOTTOMLEFT, 0, 40) -- move house information UI at the bottom of VEQ
		     return 
		  end
 
       if not VEQ.MiniQuestList[VEQ.FocusedMiniQuest] then 
          if VEQ.MiniQuestList[VEQ.CharSavedVars.lastSelectedMiniquest] then
              VEQ.FocusedMiniQuest = VEQ.CharSavedVars.lastSelectedMiniquest
          else   
              VEQ.FocusedMiniQuest = next(VEQ.MiniQuestList)
          end				
      end 
 
		 if VEQ.boxmarker == nil then -- fix for nil VEQ.boxmarker
		    VEQ.boxmarker = 1 
			  VEQ.AddNewUIBox()
			  VEQ.boxmarker = 2 
			  VEQ.AddNewUIBox()
		 end 
 
 
       local thisQuest = VEQ.MiniQuestList[VEQ.FocusedMiniQuest]
		   local name = thisQuest.name
		   local objective = thisQuest.objective
		   local zone = thisQuest.zone
		   local texture = thisQuest.texture
		   local iconColor = thisQuest.iconColor
		   local index = thisQuest.index
		   local bagId = thisQuest.bagId
		   local slotIndex = thisQuest.slotIndex
		   local zoneId = thisQuest.zoneId
		   
 
		   local boxHeight = 80
		   local child = VEQ.textbox[VEQ.boxmarker-1] or VEQ.textbox[VEQ.boxmarker] or "Failed" -- Solves the old display bug when long quest steps text
		   if child ~= "Failed" then
		       local mWidth, mHeight = child:GetDimensions()
		       boxHeight = (mHeight/2)+60
       end
 
       local totalQuests = GetNumJournalQuests() 
       if not totalQuests or totalQuests == 0 then -- move miniquest list upwards if there is no quests in journal 
              VEQ.bg:SetResizeToFitDescendents(false)
			        boxHeight = 30
       end
 
 
		   -- adds total number of miniquests 
     	VEQ.totalMiniQuestmarker = VEQ.totalMiniQuestmarker or WM:CreateControl(nil,VEQ.bg, CT_LABEL)
		  VEQ.totalMiniQuestmarker:ClearAnchors()
      VEQ.totalMiniQuestmarker:SetHidden(false) 
			--VEQ.totalMiniQuestmarker:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1)
			VEQ.totalMiniQuestmarker:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.ShowJournalInfosFont), VEQ.SavedVars.ShowJournalInfosSize, VEQ.SavedVars.ShowJournalInfosStyle))
			VEQ.totalMiniQuestmarker:SetText(VEQ.totalMiniQuests)
			VEQ.totalMiniQuestmarker:SetColor(VEQ.SavedVars.ShowJournalInfosColor.r, VEQ.SavedVars.ShowJournalInfosColor.g, VEQ.SavedVars.ShowJournalInfosColor.b, VEQ.SavedVars.ShowJournalInfosColor.a)
			VEQ.totalMiniQuestmarker:ClearAnchors()
			VEQ.totalMiniQuestmarker:SetAnchor(LEFT,VEQ.box[VEQ.boxmarker-1],RIGHT,-40,boxHeight-20) 
 
			if not VEQ.SavedVars.ShowNumbMiniQuestOption then VEQ.totalMiniQuestmarker:SetHidden(true) end
 
 
 
      -- next miniquest button
			VEQ.MQbutton = VEQ.MQbutton or CreateControlFromVirtual("michel",VEQ.bg,"ZO_KeybindStripButtonTemplate")
			VEQ.MQbutton:ClearAnchors()
			VEQ.MQbutton:SetAnchor(TOP,VEQ.box[VEQ.boxmarker-1],RIGHT,-VEQ.SavedVars.BgWidth/2,boxHeight-55) -- -150
			VEQ.MQbutton:SetKeybind("VEQ_NEXT_MINI_QUEST")
			VEQ.MQbutton:SetDrawLayer(4)
			VEQ.MQbutton:SetHidden(false)
 
			if not VEQ.SavedVars.ShowMQbuttonOption then VEQ.MQbutton:SetHidden(true) end
 
 
 
      if VEQ.totalMiniQuests < 2 then
			   VEQ.totalMiniQuestmarker:SetHidden(true)
         VEQ.MQbutton:SetHidden(true)
			end
 
 
      VEQ.areaMiniQuestmarkerBox = VEQ.areaMiniQuestmarkerBox or WM:CreateControl(nil, VEQ.bg, CT_CONTROL) --CT_LABEL
			VEQ.areaMiniQuestmarkerBox:ClearAnchors()
			VEQ.areaMiniQuestmarkerBox:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
			VEQ.areaMiniQuestmarkerBox:SetAnchor(LEFT,VEQ.box[VEQ.boxmarker-1],LEFT,0,boxHeight+5) 
			VEQ.areaMiniQuestmarkerBox:SetResizeToFitDescendents(true)
 
			VEQ.areaMiniQuestmarker = VEQ.areaMiniQuestmarker or WM:CreateControl(nil, VEQ.areaMiniQuestmarkerBox, CT_LABEL)
			VEQ.areaMiniQuestmarker:SetHidden(false)
			VEQ.areaMiniQuestmarker:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1)
			VEQ.areaMiniQuestmarker:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), VEQ.SavedVars.QuestsAreaSize, VEQ.SavedVars.QuestsAreaStyle))
			VEQ.areaMiniQuestmarker:SetText(zone)
			VEQ.areaMiniQuestmarker:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)
      VEQ.areaMiniQuestmarker:ClearAnchors()
			VEQ.areaMiniQuestmarker:SetAnchor(CENTER,VEQ.areaMiniQuestmarkerBox,CENTER,0,0)
 
 
			VEQ.titleMiniQuestmarkerBox = VEQ.titleMiniQuestmarkerBox or WM:CreateControl(nil, VEQ.bg, CT_CONTROL)
			VEQ.titleMiniQuestmarkerBox:ClearAnchors()
			VEQ.titleMiniQuestmarkerBox:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
			VEQ.titleMiniQuestmarkerBox:SetAnchor(TOPLEFT,VEQ.areaMiniQuestmarkerBox,BOTTOMLEFT,0,0) 
			VEQ.titleMiniQuestmarkerBox:SetResizeToFitDescendents(true)
 
			VEQ.titleMiniQuestmarker = VEQ.titleMiniQuestmarker or WM:CreateControl(nil, VEQ.titleMiniQuestmarkerBox, CT_LABEL)
			VEQ.titleMiniQuestmarker:SetHidden(false)
			VEQ.titleMiniQuestmarker:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.TitlePadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.TitlePadding,-1)
	    VEQ.titleMiniQuestmarker:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.TitleFont), VEQ.SavedVars.TitleSize, VEQ.SavedVars.TitleStyle))
      VEQ.titleMiniQuestmarker:SetText(name)
      VEQ.titleMiniQuestmarker:SetColor(VEQ.SavedVars.TitleColor.r, VEQ.SavedVars.TitleColor.g, VEQ.SavedVars.TitleColor.b, VEQ.SavedVars.TitleColor.a)
      VEQ.titleMiniQuestmarker:ClearAnchors()
			VEQ.titleMiniQuestmarker:SetAnchor(CENTER, VEQ.titleMiniQuestmarkerBox,CENTER,0,0) 
 
 
			VEQ.miniQuestIconBox = VEQ.miniQuestIconBox or WM:CreateControl(nil, VEQ.bg, CT_CONTROL) -- CT_LABEL
		  VEQ.miniQuestIconBox:ClearAnchors()
		  VEQ.miniQuestIconBox:SetAnchor(TOPRIGHT,VEQ.titleMiniQuestmarkerBox,TOPLEFT,0,0)
		  VEQ.miniQuestIconBox:SetResizeToFitDescendents(true)
 
			VEQ.miniQuestIcon = VEQ.miniQuestIcon or WM:CreateControl(nil,VEQ.miniQuestIconBox, CT_TEXTURE)
		  VEQ.miniQuestIcon:ClearAnchors()
			VEQ.miniQuestIcon:SetDrawLayer(1)
			VEQ.miniQuestIcon:SetHidden(false)
		  VEQ.miniQuestIcon:SetAnchor(CENTER,VEQ.miniQuestIconBox,CENTER,0,0)
		  VEQ.miniQuestIcon:SetDimensions(VEQ.SavedVars.QuestIconSize, VEQ.SavedVars.QuestIconSize)
			if texture then
			   VEQ.miniQuestIcon:SetTexture(texture)
			   if iconColor and iconColor ~= 0 then
			      VEQ.miniQuestIcon:SetColor(iconColor:UnpackRGB()) 
			   else
			      VEQ.miniQuestIcon:SetColor(1,1,1,1)
			   end 
			else
			   VEQ.miniQuestIcon:SetHidden(true)
			end 
 
 
 
			VEQ.objMiniQuestmarkerBox = VEQ.objMiniQuestmarkerBox or WM:CreateControl(nil, VEQ.bg, CT_CONTROL) -- CT_LABEL
		  VEQ.objMiniQuestmarkerBox:ClearAnchors()
			VEQ.objMiniQuestmarkerBox:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
		  VEQ.objMiniQuestmarkerBox:SetAnchor(TOPLEFT,VEQ.titleMiniQuestmarkerBox,BOTTOMLEFT,0,0) 
		  VEQ.objMiniQuestmarkerBox:SetResizeToFitDescendents(true)
 
			VEQ.objMiniQuestmarker = VEQ.objMiniQuestmarker or WM:CreateControl(nil, VEQ.objMiniQuestmarkerBox, CT_LABEL)
			VEQ.objMiniQuestmarker:SetHidden(false)
			VEQ.objMiniQuestmarker:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.TextPadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.TextPadding,-1)
	    VEQ.objMiniQuestmarker:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.TextFont), VEQ.SavedVars.TextSize, VEQ.SavedVars.TextStyle))	
			if objective == "" or index == 2 or index == 8 or index == 17 then -- spare them lives, no bullet for them
			    VEQ.objMiniQuestmarker:SetText(objective)
			else
			    VEQ.objMiniQuestmarker:SetText(string.format("%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), objective))
			end
			
			-- clickable descriptions hereherehere
			if index == 18 then -- Click for dungeon finder Ui
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if IsInGamepadPreferredMode() then
							    ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(DUNGEON_FINDER_MANAGER:GetCategoryData())
                else
                    SCENE_MANAGER:Show("groupMenuKeyboard") -- open LFG menu
                    GROUP_MENU_KEYBOARD:ShowCategory(DUNGEON_FINDER_KEYBOARD:GetFragment()) -- choose category
                end
						 end
				   end)
			elseif index == 19 then -- Click for battleground finder UI
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if IsInGamepadPreferredMode() then
							    ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(BATTLEGROUND_FINDER_MANAGER:GetCategoryData())
                else
							    SCENE_MANAGER:Show("groupMenuKeyboard") -- open LFG menu
							    GROUP_MENU_KEYBOARD:ShowCategory(BATTLEGROUND_FINDER_KEYBOARD:GetFragment()) -- choose category
							  end   
						 end
				   end)
			elseif index == 20 then -- Click for tales of tribute finder UI
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if IsInGamepadPreferredMode() then
							    ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(TRIBUTE_FINDER_MANAGER:GetCategoryData())
							else
							    SCENE_MANAGER:Show("groupMenuKeyboard") -- open LFG menu
							    GROUP_MENU_KEYBOARD:ShowCategory(TRIBUTE_FINDER_KEYBOARD:GetFragment()) -- choose category
							end   
						 end
				   end) 
			elseif index == 4 then -- Click for Rumors UI 
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
								if IsInGamepadPreferredMode() then 
                    QUEST_JOURNAL_GAMEPAD:SetMode(ZO_QUEST_JOURNAL_MODE.RUMORS)
                    SCENE_MANAGER:Show("gamepad_quest_journal")
								else
                    QUEST_JOURNAL_KEYBOARD:SetMode(ZO_QUEST_JOURNAL_MODE.RUMORS)
                    SCENE_MANAGER:Show("questJournal")
								end 
						 end
				   end)
			elseif index == 23 then -- Click for Achievements UI 
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
								if IsInGamepadPreferredMode() then 
                    SCENE_MANAGER:Show("achievementsGamepad")
								else
                    SCENE_MANAGER:Show("achievements")
								end 
						 end
				   end)
			elseif index == 22 then -- Click for Golden Pursuits UI 
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if IsInGamepadPreferredMode() then
							    ZO_ACTIVITY_FINDER_ROOT_GAMEPAD:ShowCategory(PROMOTIONAL_EVENTS_GAMEPAD:GetCategoryData())
                else
                    SCENE_MANAGER:Show("groupMenuKeyboard") -- open LFG menu
                    GROUP_MENU_KEYBOARD:ShowCategory(PROMOTIONAL_EVENTS_KEYBOARD:GetFragment()) -- choose category
                end
						 end
				   end)
			elseif index == 8 then -- Click for Tamriel Tomes UI 
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if IsInGamepadPreferredMode() then
                    --TAMRIEL_TOMES_SCENE_GROUP_GAMEPAD:SetActiveScene("TamrielTomesSceneGamepad")
							     -- SCENE_MANAGER:Show("TamrielTomesSceneGamepad")
                else
                   -- TAMRIEL_TOMES_SCENE_GROUP_KEYBOARD:SetActiveScene("TamrielTomesSceneKeyboard")
							     -- SCENE_MANAGER:Show("TamrielTomesSceneKeyboard")
                    --TAMRIEL_TOMES_MANAGER:OpenTamrielTome( GetActiveReferenceTrackIdsForRewardTrackType(REWARD_TRACK_TYPE_TAMRIEL_TOMES), false)
                end
						 end
				   end)
			elseif index == 2 and bagId ~= 0 and slotIndex ~= 0 then -- Click to start doable writ UI
				   VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				   VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
				     if upInside then
                CallSecureProtected("UseItem", bagId, slotIndex)
						 end
					end)	 
			elseif index == 2 and BMU and zoneId ~= 0 then -- Click to port to treasure / survey with BeamMeUp and leads finder UI if in zone
				     VEQ.objMiniQuestmarker:SetMouseEnabled(true)
				     VEQ.objMiniQuestmarker:SetHandler("OnMouseUp", function(self, button, upInside, ctrl, alt, shift, command)
						 if upInside then
						    if zoneId ~= 0 and zoneId ~= GetZoneId(GetUnitZoneIndex("player")) and BMU then 
							    BMU.sc_porting(zoneId)
							  else
                  if IsInGamepadPreferredMode() then 
                    SYSTEMS:GetObject("mainMenu"):ShowScryableAntiquities()
                  else
                    MAIN_MENU_KEYBOARD:ShowSceneGroup("journalSceneGroup", "antiquityJournalKeyboard")
                    ANTIQUITY_JOURNAL_KEYBOARD:ShowScryable()
                  end 
                end
						 end
				   end) 
			else 
			    VEQ.objMiniQuestmarker:SetMouseEnabled(false)
			end
			
			
			
		  VEQ.objMiniQuestmarker:SetColor(VEQ.SavedVars.TextColor.r, VEQ.SavedVars.TextColor.g, VEQ.SavedVars.TextColor.b, VEQ.SavedVars.TextColor.a)
      VEQ.objMiniQuestmarker:ClearAnchors()
			VEQ.objMiniQuestmarker:SetAnchor(CENTER,VEQ.objMiniQuestmarkerBox,CENTER,0,0)
 
 		  -- background texture 
		  VEQ.bgtx:SetDimensions(VEQ.main:GetWidth()+65, (VEQ.objMiniQuestmarkerBox:GetBottom()-VEQ.main:GetTop())+200)
		
			BATTLEGROUND_HUD_FRAGMENT.control:SetAnchor(TOPLEFT, VEQ.objMiniQuestmarkerBox, BOTTOMLEFT, 0, 80) -- move battlegrounds UI at the bottom of VEQ
			if ZO_EndDunHUDTracker then
			   ZO_EndDunHUDTracker:ClearAnchors()
			   ZO_EndDunHUDTracker:SetAnchor(TOPLEFT, VEQ.objMiniQuestmarkerBox, BOTTOMLEFT, -(VEQ.main:GetWidth()-120), 80) -- move endless dungeon UI at the bottom of VEQ
			end
			ZO_HouseInformationTrackerTopLevel:SetAnchor(TOPLEFT, VEQ.objMiniQuestmarkerBox, BOTTOMLEFT, 0, 80) -- move house information UI at the bottom of VEQ
      
end
 
 
 
 
 
 
 
-- --------------------------------------------------------------------------------------
-- QuestLoop
-- --------------------------------------------------------------------------------------
function VEQ.QuestsLoop()
	VEQ.DisplayedQuests = {}
	local userCurrentZone = zo_strformat(SI_QUEST_JOURNAL_ZONE_FORMAT, GetUnitZone('player'))
	local currentMapZoneIndex = GetCurrentMapZoneIndex()
	local limitnbquests = VEQ.GetNbQuests()
	local nbquests = GetNumJournalQuests()
	local showquests = MAX_JOURNAL_QUESTS
	local valcheck = 0
	local i = 0
	if limitnbquests < MAX_JOURNAL_QUESTS then
		showquests = limitnbquests
	end
	VEQ.FocusedQuestInfo()

 
	-- Display number of quests
	if VEQ.SavedVars.ShowNumbQuestOption == true and nbquests > 0 then
 
	  	VEQ.boxinfos:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.ShowJournalInfosFont), VEQ.SavedVars.ShowJournalInfosSize, VEQ.SavedVars.ShowJournalInfosStyle))
	  	VEQ.boxinfos:SetText(string.format("%s/%s", nbquests, MAX_JOURNAL_QUESTS))
	  	VEQ.boxinfos:SetDrawLayer(1)
		  VEQ.boxinfos:SetColor(VEQ.SavedVars.ShowJournalInfosColor.r, VEQ.SavedVars.ShowJournalInfosColor.g, VEQ.SavedVars.ShowJournalInfosColor.b, VEQ.SavedVars.ShowJournalInfosColor.a)
		  VEQ.boxinfos:SetHidden(false)
	else
		  VEQ.boxinfos:SetHidden(true)
	end


	-- Display time
    if VEQ.SavedVars.ShowClockOption == true then
 	      local Time = os.date("%H:%M:%S")
        VEQ.clockInfos:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.ShowJournalInfosFont), VEQ.SavedVars.ShowJournalInfosSize, VEQ.SavedVars.ShowJournalInfosStyle))
        VEQ.clockInfos:SetText(Time)
		    VEQ.clockInfos:SetDrawLayer(1)
        VEQ.clockInfos:SetColor(VEQ.SavedVars.ShowJournalInfosColor.r, VEQ.SavedVars.ShowJournalInfosColor.g, VEQ.SavedVars.ShowJournalInfosColor.b, VEQ.SavedVars.ShowJournalInfosColor.a)
        VEQ.clockInfos:SetHidden(false)
	else
	    	VEQ.clockInfos:SetHidden(true)
	end
 
 
 
 
	 -- Display T button (change focused quest)
	if VEQ.SavedVars.ShowTbuttonOption == true and nbquests > 1 then
 
        VEQ.Tbutton.Control1:SetHidden(false)
	else
 
		VEQ.Tbutton.Control1:SetHidden(true)
	end
 
 
 
 
	-- Load qtTimerBox
	if VEQ.SavedVars.QuestsShowTimerOption == true then
	VEQ.boxqtimer:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.TimerTitleFont), VEQ.SavedVars.TimerTitleSize, VEQ.SavedVars.TimerTitleStyle))
	VEQ.boxqtimer:SetText("Quest Time")
	VEQ.boxqtimer:SetColor(VEQ.SavedVars.TimerTitleColor.r, VEQ.SavedVars.TimerTitleColor.g, VEQ.SavedVars.TimerTitleColor.b, VEQ.SavedVars.TimerTitleColor.a)
	if VEQ.isTimedQuest == true and qindex == VEQ.FocusedQIndex then
		VEQ.boxqtimer:SetAlpha(1)
	else
		VEQ.boxqtimer:SetAlpha(0)
	end
	end
 
 
	-- 04/07/2026 performance improvement:
	-- This loop used to always scan all MAX_JOURNAL_QUESTS (50) journal slots and call the
	-- IsValidQuestIndex API for every single one, no matter how many quests are actually
	-- active. VEQ.QuestsLoop (and therefore this scan) runs on every VEQ.QuestsListUpdate,
	-- which fires very often during normal play (quest advanced, quest added, level update,
	-- and - via VEQ.SetFocusedQuest - on every EVENT_QUEST_CONDITION_COUNTER_CHANGED, i.e.
	-- practically every kill/loot/gather tick that progresses a quest condition). Since
	-- "nbquests" (GetNumJournalQuests(), the exact number of active journal quests) is already
	-- known above, we can stop scanning as soon as we've found that many valid quests instead
	-- of always walking the full 50 slots. Most players only track a handful of quests at a
	-- time, so this turns a constant 50 API calls + function calls per refresh into a small
	-- number proportional to the player's actual active quest count, on one of the hottest
	-- code paths in the addon.
	local foundQuests = 0
	for i=1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then
			VEQ.LoadQuestsInfo(i)
			foundQuests = foundQuests + 1
			if foundQuests >= nbquests then break end
		end
	end
	
	

 
 
    --- insert quests in table
	-- 04/07/2026 performance improvement:
	-- Only one quest can ever be the currently assisted/focused quest at a time, so once
	-- this loop finds it there is no need to keep scanning the rest of VEQ.QuestList - every
	-- remaining entry is guaranteed to fail the GetTrackedIsAssisted check anyway. Breaking
	-- early avoids pointless GetTrackedIsAssisted calls for the remaining tracked quests on
	-- every VEQ.QuestsLoop pass.
	VEQ.filterzone = {}
	local assistedQuestZoneIndex = 0
	for j,v in pairs(VEQ.QuestList) do
		local valQindex = GetTrackedIsAssisted(TRACK_TYPE_QUEST,v.index,0)
		if valQindex == true then
			assistedQuestZoneIndex = v.zoneidx
			table.insert(VEQ.DisplayedQuests,v)
			break
		end
		--valcheck = VEQ.CheckQuestsToHidden(v.index, v.name, v.type, v.zoneidx, valcheck)
	end
	
	-- reorder by myzone for cleaner display
	table.sort(VEQ.QuestList, function(a,b) 
			if (a.myzone < b.myzone) then
				return true
			elseif (a.myzone > b.myzone) then
				return false
			else
                if (a.type < b.type) then
				    return true
			    elseif (a.type > b.type) then
				    return false
			    end			
			end
	end)
	
		
	if showquests ~= 1 then
		for j,v in pairs(VEQ.QuestList) do
			-- it works just not sure how to use it
			--if IsJournalQuestInCurrentMapZone(v.index) == true then table.insert(VEQ.DisplayedQuests, v) end
			local isOk = true
			--if VEQ.SavedVars.QuestsZoneOption == true then
                
				if assistedQuestZoneIndex == v.zoneidx and not GetTrackedIsAssisted(TRACK_TYPE_QUEST,v.index,0) then  --(IsJournalQuestInCurrentMapZone(v.index) or currentMapZoneIndex == v.zoneidx or userCurrentZone == v.zone)
					isOk = true
				else
					isOk = false
				end
			--end
			-- if VEQ.SavedVars.QuestsZoneMainOption == false and v.type == QUEST_TYPE_MAIN_STORY then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneGuildOption == false and v.type == QUEST_TYPE_GUILD then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneCyrodiilOption == false and v.zoneidx == VEQ.CyrodiilNumZoneIndex then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneClassOption == false and v.type == QUEST_TYPE_CLASS then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneCrafingOption == false and v.type == QUEST_TYPE_CRAFTING then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneGroupOption == false and v.type == QUEST_TYPE_GROUP then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneCrafingOption == false and v.type == QUEST_TYPE_CRAFTING then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneDungeonOption == false and v.type == QUEST_TYPE_DUNGEON then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneAVAOption == false then
				-- if v.type == QUEST_TYPE_AVA then isOk = false end
				-- if v.type == QUEST_TYPE_AVA_GRAND then isOk = false end
				-- if v.type == QUEST_TYPE_AVA_GROUP then isOk = false end
			-- end
			-- if VEQ.SavedVars.QuestsZoneEventOption == false and v.type == QUEST_TYPE_HOLIDAY_EVENT then isOk = false end
			-- if VEQ.SavedVars.QuestsZoneBGOption == false and v.type == QUEST_TYPE_BATTLEGROUND then isOk = false end
 
			if isOk == true then table.insert(VEQ.DisplayedQuests, v)end

			--valcheck = VEQ.CheckQuestsToHidden(v.index, v.name, v.type, v.zoneidx, valcheck)
		end
	end	
	

	
	

	-- Display
	VEQ.zonename = ""
	VEQ.zonetype = ""
	VEQ.filterzonedyn = ""
 
	-- Zone for current focused quest
	for j,v in pairs(VEQ.DisplayedQuests) do
		local valQindex = GetTrackedIsAssisted(TRACK_TYPE_QUEST,v.index,0)
		if valQindex == true then
			VEQ.filterzonedyn = v.zone
			VEQ.PsijicTimeBreachesHelper(v.index) -- update the Psijic Time Breaches Helper on zone change / focused quest change
		end
	end	
 
 
 
	-- draw the displayed quests
	-- quest areas 
	for x,z in pairs(VEQ.DisplayedQuests) do
		local myzone = z.myzone
		
		if VEQ.QuestsAreaOption == true and VEQ.zonename ~= z.myzone then
		--if VEQ.QuestsAreaOption == true then
			VEQ.AddNewUIBox()
			VEQ.box[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
			VEQ.icon[VEQ.boxmarker]:SetHidden(true)
			VEQ.textbox[VEQ.boxmarker]:SetDimensionConstraints(VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1,VEQ.SavedVars.BgWidth-VEQ.SavedVars.QuestsAreaPadding,-1)
			VEQ.textbox[VEQ.boxmarker]:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), VEQ.SavedVars.QuestsAreaSize, VEQ.SavedVars.QuestsAreaStyle))
			VEQ.textbox[VEQ.boxmarker]:SetText(z.myzone)
			VEQ.textbox[VEQ.boxmarker]:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)
			VEQ.currentAreaBox = VEQ.boxmarker
			if VEQ.QuestsNoFocusOption == false then
				VEQ.box[VEQ.currentAreaBox]:SetAlpha(1)
			else
				if VEQ.FocusedQuestAreaNoTrans == true and myzone == VEQ.FocusedZone then
					VEQ.box[VEQ.currentAreaBox]:SetAlpha(1)
				else
					VEQ.box[VEQ.currentAreaBox]:SetAlpha(VEQ.SavedVars.QuestsNoFocusTransparency/100)
				end
			end	
			--if VEQ.SavedVars.PositionLockOption == true then
				if not VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
					VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(true)
				end
				VEQ.textbox[VEQ.boxmarker]:SetHandler("OnMouseDown", function(self, click)
					VEQ.MouseTitleController(click, myzone)
				end)
			-- else
				-- if VEQ.textbox[VEQ.boxmarker]:IsMouseEnabled() then
					-- VEQ.textbox[VEQ.boxmarker]:SetMouseEnabled(false)
				-- end
				-- VEQ.textbox[VEQ.boxmarker]:SetHandler()
			-- end
			VEQ.textbox[VEQ.boxmarker]:SetAnchor(CENTER,VEQ.box[VEQ.boxmarker],CENTER,0,0)
			VEQ.boxmarker = VEQ.boxmarker + 1
			VEQ.zonename = z.myzone
			--VEQ.zonetype = z.type
		end
		
		if VEQ.limitnumquest <= showquests then
			local checkfilter = 1
 
			if VEQ.filterzone[checkfilter] then
				local checkzone = 0
				while VEQ.filterzone[checkfilter] do
            if VEQ.filterzone[checkfilter] == myzone then
              checkzone = 1
            end
            checkfilter = checkfilter + 1
				end
				if checkzone ~= 1 then
					VEQ.AddNewTitle(z.index, z.level, z.name, z.type, z.zone, z.focusedzoneval)
          VEQ.alreadyWroteImmeriveText = nil
					-- hidobj
					local FocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,z.index,0)
					if VEQ.HideObjOption == "Disabled" or (FocusedQuest == true and VEQ.HideObjOption == "Focused Quest") or (z.focusedzoneval == 1 and VEQ.HideObjOption == "Focused Zone") then
						local k=1
						while z.step[k] do
                if z.step[k].text ~= "" then
                  VEQ.CheckContent(z.index, k, z.step[k].text, z.step[k].mytype, z.zone, z.focusedzoneval, z.step[k].journalText)
                end
                k=k+1
						end
					end
					VEQ.limitnumquest = VEQ.limitnumquest + 1
				end
			else
				VEQ.AddNewTitle(z.index, z.level, z.name, z.type, z.zone, z.focusedzoneval)
        VEQ.alreadyWroteImmeriveText = nil 
				-- hidobj
				local FocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,z.index,0)
				if VEQ.HideObjOption == "Disabled" or (FocusedQuest == true and VEQ.HideObjOption == "Focused Quest") or (z.focusedzoneval == 1 and VEQ.HideObjOption == "Focused Zone") then
					local k=1
					while z.step[k] do
              if z.step[k].text ~= "" then
                VEQ.CheckContent(z.index, k, z.step[k].text, z.step[k].mytype, z.zone, z.focusedzoneval, z.step[k].journalText)
              end
              k=k+1
					end
				end
				VEQ.limitnumquest = VEQ.limitnumquest + 1
			end
		end
	end
 
 
 
 
 
	if VEQ.box[VEQ.currentAssistedArea] then
		VEQ.box[VEQ.currentAssistedArea]:SetAlpha(1) 
	end
 
	-- Update Journal and tracker
	--if valcheck == 1 then
		-- Compass Update For 10023
	FOCUSED_QUEST_TRACKER:InitialTrackingUpdate()
	local noUpdate = false
	if BUI then noUpdate = true end
	if noUpdate == false then
		--WorldMap / Minimap Update)
		ZO_WorldMap_UpdateMap()
	end
	--end

	
    VEQ.DisplayFocusedMiniQuest()
 
end
 
 
 
function VEQ.QuestsListUpdate(eventCode) 
	if (VEQ.SavedVars and VEQ.SavedVars.BgOption ~= nil and eventCode ~= nil) then
 
		--Coding tofix Quest Lock Bug, may use it to more intelligently set the next focused quest
		-- 131092 remove++++131093 complete--tracking update
		if eventCode == 131092 then 
			VEQ.ForcedFocusedQuest(0) 
		end
 
		VEQ.QuestList = {}
		VEQ.currentAreaBox = 0
		VEQ.currentAssistedArea = 0
		VEQ.varnumquest = 1
		VEQ.limitnumquest = 1
		VEQ.boxmarker = 1
		if VEQ.SavedVars.QuestsFilter then
			VEQ.filterzone = VEQ.SavedVars.QuestsFilter
			if VEQ.QuestsHideZoneOption == true then VEQ.CleanFilterZone() end
		elseif not VEQ.filterzone then
			VEQ.filterzone = {}
		end		
 
		-- Clear the other created boxes
		VEQ.ClearBoxes(VEQ.boxmarker)
		-- List All Quests		
		VEQ.QuestsLoop()
 
	end
	  -- EM:UnregisterForEvent("VEQ", EVENT_PLAYER_ACTIVATED) -- commenting fixes U51 vanilla quest tracker reappearing
end
 
 
 
 
 
----------------------------------
--          Start & Menu
----------------------------------
function VEQ.Init(eventCode, addOnName)
 
 
	if addOnName == "VEQ" then
		-- Create & load defaults vars
		VEQ.box = {}
		VEQ.icon = {}
		VEQ.textbox = {}
		VEQ.currenticon = nil
		if not VEQ.SavedVars then
			VEQ.SavedVars = ZO_SavedVars:NewAccountWide("VEQSavedVars", 5, nil, VEQ.defaults) or VEQ.defaults
		end
 
		if not VEQ.CharSavedVars then
			VEQ.CharSavedVars = ZO_SavedVars:NewCharacterIdSettings("VEQSavedVars", 5, nil, VEQ.charDefaults) or VEQ.charDefaults
		end
 
		-- Create the UI boxes
		-- Main Box
		VEQ.main = GetControl("VEQ main")
		VEQ.main:ClearAnchors()
		--VEQ.main:SetDimensions(200,40)
		VEQ.main:SetDrawLayer(1)
		VEQ.main:SetResizeToFitDescendents(true)
		VEQ.main:SetAlpha(1)
    
    HUD_MANAGER:RegisterKeyboardElement(VEQ.main, "Vestige's Epic Quest", { defaultAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, 200, 200) }, COMPASS_OPTIONS) -- for Keyboard UI 
    HUD_MANAGER:RegisterGamepadElement(VEQ.main, "Vestige's Epic Quest", { defaultAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, 200, 200) }, COMPASS_OPTIONS) --for Gamepad UI
		
 
		-- Main Background
		VEQ.bg = WM:CreateControl(nil, VEQ.main, CT_STATUSBAR)
		VEQ.bg:ClearAnchors()
		VEQ.bg:SetAnchor(TOPLEFT, VEQ.main, TOPLEFT, 0, 0)
		--VEQ.bg:SetDimensions(200,40)
		VEQ.bg:SetDrawLayer(1)
		VEQ.bg:SetResizeToFitDescendents(true)
		VEQ.bg:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
		

		-- Journal Infos (number of quests / max quests)
		VEQ.boxinfos = WM:CreateControl(nil, VEQ.bg , CT_LABEL)
		VEQ.boxinfos:ClearAnchors()
		VEQ.boxinfos:SetAnchor(TOPRIGHT,VEQ.bg,TOPRIGHT,0,0) --VEQ.boxinfos:SetAnchor(TOPRIGHT,VEQ.bg,TOPRIGHT,-5,0)
		--VEQ.boxinfos:SetDimensions(40,40)
		VEQ.boxinfos:SetDrawLayer(4)
		VEQ.boxinfos:SetMouseEnabled(true)
		VEQ.boxinfos:SetHandler("OnMouseDown", function(self, button)
			if  button == 1 or button == 2 or button == 3 then
				VEQ.SwitchDisplayMode()
			end
		end)
 
 
		-- Clock Infos
		VEQ.clockInfos = WM:CreateControl(nil, VEQ.bg , CT_LABEL)
		VEQ.clockInfos:ClearAnchors()
		VEQ.clockInfos:SetAnchor(TOPLEFT,VEQ.bg,TOPLEFT,0,0)  -- TOPLEFT,VEQ.bg,TOPRIGHT,-295,0
		--VEQ.clockInfos:SetDimensions(100,40)
		VEQ.clockInfos:SetDrawLayer(4)
 
 
		-- T button
    VEQ.Tbutton = CreateTopLevelWindow("whatever") 
	  VEQ.Tbutton.Control1 = CreateControlFromVirtual("robert",VEQ.bg,"ZO_KeybindStripButtonTemplate")
	  VEQ.Tbutton.Control1:ClearAnchors()
	  VEQ.Tbutton.Control1:SetAnchor(CENTER,VEQ.bg,TOPRIGHT,-VEQ.SavedVars.BgWidth/2,5)
	  VEQ.Tbutton.Control1:SetKeybind("ASSIST_NEXT_TRACKED_QUEST")
    VEQ.Tbutton.Control1:SetDrawLayer(4)	
    VEQ.Tbutton.Control1:SetResizeToFitDescendents(true)
 
 
		-- Quest Timer Box
		VEQ.boxqtimer = WM:CreateControl(nil, VEQ.bg , CT_LABEL)
		VEQ.boxqtimer:ClearAnchors()
		VEQ.boxqtimer:SetAnchor(TOPLEFT,VEQ.bg,TOPLEFT,0,0)
		VEQ.boxqtimer:SetDimensions(100,40)
		VEQ.boxqtimer:SetDimensionConstraints(VEQ.SavedVars.BgWidth,-1,VEQ.SavedVars.BgWidth,-1)
		VEQ.boxqtimer:SetDrawLayer(1)
 
 
 
		--if VEQ.SavedVars.BgOption == true then
		--	VEQ.bg:SetColor(VEQ.SavedVars.BgColor.r,VEQ.SavedVars.BgColor.g,VEQ.SavedVars.BgColor.b,VEQ.SavedVars.BgColor.a)
		--elseif VEQ.SavedVars.BgGradientOption == true then
			-- VEQ.bg:SetGradientColors(VEQ.SavedVars.BgColor.r,VEQ.SavedVars.BgColor.g,VEQ.SavedVars.BgColor.b,VEQ.SavedVars.BgColor.a,0,0,0,0)
		--else
			VEQ.bg:SetColor(0,0,0,0)
		--end
		
		-- Backgroud texture
    VEQ.bgtx = WM:CreateControl(nil, VEQ.main, CT_TEXTURE)
    VEQ.bgtx:ClearAnchors()
    VEQ.bgtx:SetExcludeFromResizeToFitExtents(true) 
    VEQ.bgtx:SetAnchor(TOPLEFT, VEQ.main, TOPLEFT, -60, -60)
    VEQ.bgtx:SetDrawTier(0)
    VEQ.bgtx:SetDrawLayer(0)
    VEQ.bgtx:SetDrawLevel(0)
    VEQ.bgtx:SetTexture("esoui/art/miscellaneous/centerscreen_left.dds")

 
 
		-- -----------------------------------------------------------------------
		-- initial settings based on saved vars values on initial
		-- -----------------------------------------------------------------------
		VEQ.CreateSettings()
		-- Prior to verson 1.5 savedvars would have had the HideObjOtion to True/False this should fix that and set toggle right.
		if VEQ.SavedVars.HideObjOption == true or VEQ.SavedVars.HideObjOption == false then 
			VEQ.SetHideObjOption("Disabled") 
		end
 
		-- Post setting ShowQuestTimer settings
		if VEQ.SavedVars.ShowQuestTimer == true then VEQ.HideQuestTimer() end
		-- Set vars for load keybind values
		VEQ.LoadKeybindInfo()
		--
		if VEQ.SavedVars.QuestsHideZoneOption == true then 
			VEQ.QuestsHideZoneOption = true
			VEQ.AutoFilterZone()
		else
			if VEQ.SavedVars.QuestsFilter then
				VEQ.filterzone = VEQ.SavedVars.QuestsFilter
				if VEQ.QuestsHideZoneOption == true then VEQ.CleanFilterZone() end
			elseif not VEQ.filterzone then
				VEQ.filterzone = {}
			end		
			VEQ.QuestsHideZoneOption = false
			VEQ.QuestsListUpdate(1)
		end
 
		EM:UnregisterForEvent(EVENT_ADD_ON_LOADED)
		--EVENT_QUEST_OPTIONAL_STEP_ADVANCED = 131091
 
		-- UPDATES with EVENTS				
		--EVENT_PLAYER_ACTIVATED = 589824
 
				--Only these??
		--EVENT_QUEST_CONDITION_COUNTER_CHANGED
		--EVENT_QUEST_ADDED
		--EVENT_PLAYER_ACTIVATED
		--EVENT_QUEST_ADVANCED
		--EVENT_LEVEL_UPDATE
		EM:RegisterForEvent("VEQ", EVENT_PLAYER_ACTIVATED, function(code) VEQ.QuestsListUpdate(code) zo_callLater(function() VEQ.CheckMode()  end, 1000) end) --> EC:131072 Update after zoning
		--EVENT_QUEST_REMOVED = 131092
		EM:RegisterForEvent("VEQ", EVENT_QUEST_REMOVED,
		   function(eventCode, isCompleted, _, questName, _, _, questId)
         local _, questType = GetCompletedQuestInfo(questId)
         if isCompleted == true and questType == QUEST_TYPE_FAVOR then
           VEQ.CharSavedVars.LastFavorResetTime = VEQ.CharSavedVars.LastFavorResetTime or {}
           
           if questId == 7477 or questId == 7469 or questId == 7513 then -- last favor of the series we remove the saved variable for it to not show again 
               VEQ.CharSavedVars.LastFavorResetTime[VEQ.KillTheRubbish(questName)] = nil
           else
               VEQ.CharSavedVars.LastFavorResetTime[VEQ.KillTheRubbish(questName)] = GetTimeStamp() + GetTimeUntilNextDailyLoginRewardClaimS()
           end
           
           VEQ.AvailableFavors = VEQ.AvailableFavors or {}
           VEQ.AvailableFavors[questName] = false
           VEQ.CheckRepeatableLimit("favors")
		     elseif isCompleted == true then
              VEQ.CheckRepeatableLimit("complete")
         else
              VEQ.CheckRepeatableLimit("removed")
         end
         
		     if GetNumJournalQuests() == 0 then  VEQ.QuestsListUpdate(131092) end -- update quest list if no more quest following a quest remove
           end)
		EM:RegisterForEvent("VEQ", EVENT_LEVEL_UPDATE, VEQ.QuestsListUpdate)
		--EVENT_QUEST_ADVANCED = 131090
		EM:RegisterForEvent("VEQ", EVENT_QUEST_ADVANCED, VEQ.QuestsListUpdate) --> EC:131090
		--EVENT_QUEST_OPTIONAL_STEP_ADVANCED = 131091
		EM:RegisterForEvent("VEQ", EVENT_QUEST_OPTIONAL_STEP_ADVANCED, VEQ.QuestsListUpdate)
		--EVENT_QUEST_COMPLETE = 131093		
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_COMPLETE, function() VEQ.CheckRepeatableLimit("complete") end) -- EC:131093 
 
		EM:RegisterForEvent("VEQ", EVENT_QUEST_ADDED, function(eventCode, qindex, qname, qstep)
		VEQ.CheckRepeatableLimit("added")
		-- 04/07/2026 performance improvement:
		-- EVENT_QUEST_TIMER_UPDATED fires roughly once per second for the whole
		-- duration any quest timer is active (escort quests, zone events, dolmens, etc.).
		-- It was previously bound straight to VEQ.QuestsListUpdate, which triggers a full
		-- rebuild of the entire tracker every single tick: re-reading all MAX_JOURNAL_QUESTS
		-- journal slots (VEQ.QuestsLoop -> VEQ.LoadQuestsInfo), destroying/recreating every
		-- UI box (VEQ.ClearBoxes/VEQ.AddNewUIBox), re-sorting VEQ.QuestList and redrawing all
		-- titles/objectives (VEQ.AddNewTitle/VEQ.CheckContent) - all just to refresh a countdown
		-- number that VEQ.GetQuestTimer/VEQ.UpdateQuestTime already update on their own each
		-- second via the lightweight "VEQ_Update_Timer" EM:RegisterForUpdate loop.
		-- Routing the event to VEQ.GetQuestTimer(journalIndex) instead keeps the timer text
		-- accurate while avoiding an unnecessary full quest-list/UI rebuild every second a
		-- timer is running, which noticeably reduces CPU/GC load during timed quests.
		EM:RegisterForEvent("VEQ", EVENT_QUEST_TIMER_UPDATED, function(eventCode, journalIndex) VEQ.GetQuestTimer(journalIndex) end)
		EM:RegisterForEvent("VEQ", EVENT_QUEST_TIMER_PAUSED, function(eventCode, journalIndex) VEQ.GetQuestTimer(journalIndex) end)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_LIST_UPDATED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_TRACKING_UPDATE, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_CONDITION_COUNTER_CHANGED, VEQ.QuestsListUpdate)
 
			-- Auto Share Quests
			local PlayerIsGrouped = IsUnitGrouped('player')
			if PlayerIsGrouped and VEQ.SavedVars.AutoShare == true and qindex ~= nil then
				if GetIsQuestSharable(qindex) then
					ShareQuest(qindex)
					d(string.format("%s: %s", VEQ.mylanguage.lang_console_autoshare, qname))
				end
			end			
			-- Auto Focus
			VEQ.SetFocusedQuest(qindex)  -- setting shared quest
		end) --> EC:131078 add quest
 
		EM:RegisterForEvent("VEQ", EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(eventCode, qindex, questName, _, _, _, newCounter)
		   local check = zo_iconTextFormatNoSpace("esoui/art/miscellaneous/check_icon_32.dds",20,20,"")
		-- 3 keeps
		   if questName == GetQuestName(3431) then
		      if newCounter == 0 or newCounter == 3 then 
			      VEQ.CharSavedVars.ThreeKeeps = ""
		      elseif newCounter == 1 then
			      VEQ.CharSavedVars.ThreeKeeps = string.format("%s%s %s", check, newCounter, GetPlayerActiveSubzoneName())
			  elseif VEQ.CharSavedVars.ThreeKeeps and VEQ.CharSavedVars.ThreeKeeps ~= "" then
			      VEQ.CharSavedVars.ThreeKeeps = string.format("%s\n%s%s %s", VEQ.CharSavedVars.ThreeKeeps, check, newCounter, GetPlayerActiveSubzoneName())
			  end
		-- 9 resources
		   elseif questName == GetQuestName(6208) then
		      if newCounter == 0 or newCounter == 9 then 
			       VEQ.CharSavedVars.NineResources = ""
		      elseif newCounter == 1 then
			       VEQ.CharSavedVars.NineResources = string.format("%s%s %s", check, newCounter, GetPlayerActiveSubzoneName())
			  elseif VEQ.CharSavedVars.NineResources and VEQ.CharSavedVars.NineResources ~= "" then
			       VEQ.CharSavedVars.NineResources = string.format("%s\n%s%s %s", VEQ.CharSavedVars.NineResources, check, newCounter, GetPlayerActiveSubzoneName())
			  end
		   end
        		
		VEQ.SetFocusedQuest(qindex) 
		end)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_CONDITION_COUNTER_CHANGED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_ACTIVE_QUEST_TOOL_CHANGED, VEQ.QuestsListUpdate)
 
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_POSITION_REQUEST_COMPLETE, CheckEventVEQ) -- EC:131100
		--EM:RegisterForEvent("VEQ", EVENT_TRACKING_UPDATE, CheckEventVEQ)
		--EM:RegisterForEvent("VEQ", EVENT_OBJECTIVES_UPDATED, VEQ.QuestsListUpdate) --> why EC:131208 ???
		--EM:RegisterForEvent("VEQ", EVENT_OBJECTIVE_COMPLETED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_ACTIVE_QUEST_TOOL_CHANGED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_ACTIVE_QUEST_TOOL_CLEARED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_TOOL_UPDATED, VEQ.QuestsListUpdate) 
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_SHARE_UPDATE, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_SHOW_JOURNAL_ENTRY, VEQ.QuestsListUpdate)
		EM:RegisterForEvent("VEQ", EVENT_QUEST_COMPLETE_DIALOG, VEQ.QuestsListUpdate) 
		EM:RegisterForEvent("VEQ", EVENT_QUEST_COMPLETE_EXPERIENCE, VEQ.QuestsListUpdate)		
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_OFFERED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_SHARED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_SHARE_REMOVED, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_LOG_IS_FULL, VEQ.QuestsListUpdate)
		--EM:RegisterForEvent("VEQ", EVENT_QUEST_COMPLETE_ATTEMPT_FAILED_INVENTORY_FULL, VEQ.QuestsListUpdate)
		--EVENT_QUEST_ADDED = 131079
		--EVENT_QUEST_ADVANCED = 131090
 
		--EVENT_QUEST_ADDED 131079
		--EVENT_QUEST_ADVANCED 131090
		--EVENT_QUEST_COMPLETE 131093
		--EVENT_QUEST_COMPLETE_ATTEMPT_FAILED_INVENTORY_FULL 131094
		--EVENT_QUEST_COMPLETE_DIALOG 131089
		--EVENT_QUEST_CONDITION_COUNTER_CHANGED 131085
		--EVENT_QUEST_LIST_UPDATED 131083
		--EVENT_QUEST_LOG_IS_FULL 131084
		--EVENT_QUEST_OFFERED 131080
		--EVENT_QUEST_OPTIONAL_STEP_ADVANCED 131091
		--EVENT_QUEST_POSITION_REQUEST_COMPLETE 131100
		--EVENT_QUEST_REMOVED 131092
		--EVENT_QUEST_SHARED 131081
		--EVENT_QUEST_SHARE_REMOVED 131082
		--EVENT_QUEST_SHOW_JOURNAL_ENTRY 131097
		--EVENT_QUEST_TIMER_PAUSED 131087
		--EVENT_QUEST_TIMER_UPDATED 131088
		--EVENT_QUEST_TOOL_UPDATED 131086
		--EVENT_ACTIVE_QUEST_TOOL_CHANGED = 131098
		--EVENT_ACTIVE_QUEST_TOOL_CLEARED = 131099
		--EVENT_TRACKING_UPDATE = 131096
		--EVENT_OBJECTIVES_UPDATED = 131269
		--EVENT_OBJECTIVE_COMPLETED = 131095
		--EVENT_QUEST_SHOW_JOURNAL_ENTRY = 131097
 
		-- Called when a slot in your inventory is modified
		SHARED_INVENTORY:RegisterCallback("SlotRemoved", VEQ.SlotRemoved)
		SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", VEQ.SlotUpdated) 
		
 
		-- called on activity finder status update
		EM:RegisterForEvent("VEQ", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, VEQ.activityTracker)
		
		-- called on groupfinder updates
		EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT, function() VEQ.groupFinder() --[[ d("EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT")--]] end) -- user created listing
		EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT, function() VEQ.groupFinder() --[[d("EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT")--]] end) -- user updated listing
		--EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT, function() VEQ.groupFinder() d("EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT") end) -- user removed listing EVENT_GROUP_FINDER_UPDATE_APPLICATIONS trigger before
		--EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT, function() VEQ.groupFinder() d("EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT") end) -- you applied, EVENT_GROUP_MEMBER_JOINED also triggers 
        --EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION, function() VEQ.groupFinder() d("EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION") end) -- you left application to go to group EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT triggers before		
		EM:RegisterForEvent("VEQ", EVENT_GROUP_FINDER_UPDATE_APPLICATIONS, function() VEQ.groupFinder() --[[d("EVENT_GROUP_FINDER_UPDATE_APPLICATIONS")--]] end) -- member applied/removed ? 
		-- nothing from GROUP_FINDER triggers when users adds to or leave group
		EM:RegisterForEvent("VEQ", EVENT_GROUP_MEMBER_JOINED, function() VEQ.groupFinder() --[[d("EVENT_GROUP_MEMBER_JOINED")--]] end)
        EM:RegisterForEvent("VEQ", EVENT_GROUP_MEMBER_LEFT, function() VEQ.groupFinder() --[[d("EVENT_GROUP_MEMBER_LEFT")--]] end)

		
		EM:RegisterForEvent("VEQ", EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED, VEQ.activityTracker)
		EM:RegisterForEvent("VEQ", EVENT_GROUPING_TOOLS_READY_CHECK_CANCELLED, VEQ.activityTracker)
 
 
		-- Called when you get a new lead
		EM:RegisterForEvent("VEQ", EVENT_ANTIQUITY_LEAD_ACQUIRED, VEQ.CheckLeads)
 
		-- Called when you finish digging
		EM:RegisterForEvent("VEQ", EVENT_ANTIQUITY_DIGGING_EXIT_RESPONSE, function() VEQ.CharSavedVars.LastExcavationTime = GetTimeStamp() VEQ.CheckLeads() end )
 
		-- Called when you upgrade a riding skill or when you purchase more bag space
		EM:RegisterForEvent("VEQ", EVENT_RIDING_SKILL_IMPROVEMENT, function() VEQ.CheckRidingSkillTimer() VEQ.UpdateInventory()  end) 
 
		-- Called when dungeon is over
		EM:RegisterForEvent("VEQ", EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, VEQ.delayedCheckDungeonRewardTimer)
 
		-- Called when a battleground state changed
		--EM:RegisterForEvent("VEQ8", EVENT_BATTLEGROUND_STATE_CHANGED, VEQ.delayedCheckBattlegroundRewardTimer)
 
		-- Called when a tribute game state changed
		EM:RegisterForEvent("VEQ", EVENT_TRIBUTE_GAME_FLOW_STATE_CHANGE, VEQ.delayedCheckTributeRewardTimer)
 
		-- Called when your gold amount changes
		EM:RegisterForEvent("VEQ", EVENT_MONEY_UPDATE, VEQ.CheckBackpackBankUpgrade)
 
		-- Called when your Tamriel Tomes progress changes
		EM:RegisterForEvent("VEQ", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, VEQ.CheckTamrielTomes)
    EM:RegisterForEvent("VEQ", EVENT_TIMED_ACTIVITY_TRACKING_UPDATED, VEQ.CheckTamrielTomes)
 
		-- Called when the Tamriel Tomes list is modified (new stuff)
		EM:RegisterForEvent("VEQ", EVENT_TIMED_ACTIVITIES_UPDATED, VEQ.ResetTamrielTomes)
    
    -- called when rumors update
    EM:RegisterForEvent("VEQ", EVENT_RUMOR_UPDATED, VEQ.Rumors)
 
		-- Called when a currency updates
		EM:RegisterForEvent("VEQ", EVENT_CURRENCY_UPDATE, VEQ.CheckCurrencies)
 
		-- Called when a zone story updates
		--EM:RegisterForEvent("VEQ", EVENT_ZONE_STORY_ACTIVITY_TRACKED, VEQ.zoneStoryTracker)
		--EM:RegisterForEvent("VEQ", EVENT_ZONE_STORY_ACTIVITY_UNTRACKED, VEQ.zoneStoryTracker)
		--EM:RegisterForEvent("VEQ", EVENT_ZONE_STORY_ACTIVITY_TRACKING_INIT, VEQ.zoneStoryTracker)
 
		EM:RegisterForEvent("VEQ", EVENT_ZONE_CHANGED, function()
		   local zoneName = GetZoneNameById(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap())
			 if zoneName and zoneName ~= VEQ.lastZoneName and ZO_WorldMap:IsHidden() then
				  VEQ.zoneStoryTracker()
				  VEQ.mapCompletion(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap(), true)
				  VEQ.lastZoneName = zoneName
         
          -- remove the Nirncrux counters out of Craglorn 
          if ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap() ~= 888 then
             local updated = false
             -- create table if it doesn't exist
             VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}
             if VEQ.PerUniqueIdList["fortifiedNirncrux"] then 
                VEQ.PerUniqueIdList["fortifiedNirncrux"] = nil
                updated = true
             end
             if VEQ.PerUniqueIdList["potentNirncrux"] then 
                VEQ.PerUniqueIdList["potentNirncrux"] = nil
                updated = true
             end
             if updated == true then
                VEQ.updatePerZoneDisplay()
             end
          end
			 end
		end)
		
		-- POI completion
		EM:RegisterForEvent("VEQ", EVENT_POI_UPDATED, function() VEQ.mapCompletion(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()) end )
		
 
		-- alliance war
		EM:RegisterForEvent("VEQ", EVENT_CAMPAIGN_QUEUE_LEFT, VEQ.AllianceWarQueue)
		EM:RegisterForEvent("VEQ", EVENT_CAMPAIGN_QUEUE_JOINED, VEQ.AllianceWarQueue)
 
		-- skyshards
		EM:RegisterForEvent("VEQ", EVENT_SKYSHARDS_UPDATED, function() local playerPosX, playerPosZ = LibGPS3:LocalToGlobal(GetMapPlayerPosition("player")) VEQ.CheckSkyshardDistance(playerPosX, playerPosZ) end)
 
		-- combat state
		EM:RegisterForEvent("VEQ", EVENT_PLAYER_COMBAT_STATE, VEQ.CombatState)
		
		-- Golden pursuits 
		EM:RegisterForEvent("VEQ", EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED, function() if VEQ.SavedVars.GoldenPursuits then VEQ.GoldenPursuits() end end )
		EM:RegisterForEvent("VEQ", EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED, function() if VEQ.SavedVars.GoldenPursuits then VEQ.GoldenPursuits() end end )
		EM:RegisterForEvent("VEQ", EVENT_HOUSING_POPULATION_CHANGED, function(_, new, prev) if VEQ.SavedVars.GoldenPursuits and new > prev then VEQ.GoldenPursuits() end end) 
		EM:RegisterForEvent("VEQ", EVENT_PROMOTIONAL_EVENTS_REWARDS_CLAIMED, function() if VEQ.SavedVars.GoldenPursuits then VEQ.GoldenPursuits() end end )
		
		-- Community events
		EM:RegisterForEvent("VEQ", EVENT_SPECTACLE_EVENT_UPDATED, function() if VEQ.SavedVars.CommunityEvents then VEQ.CommunityEvents() end end )
		
		
		-- Shadowy Suppliers
		EM:RegisterForEvent("VEQ", EVENT_CHATTER_END, function() if VEQ.SavedVars.ShadowySuppliers then VEQ.CheckShadowySuppliers() end end )
		
		-- Dragonguard Supply Chest
		EM:RegisterForEvent("VEQ", EVENT_CLIENT_INTERACT_RESULT, function(_, result, targetName) if result == CLIENT_INTERACT_RESULT_SUCCESS and targetName == VEQ.mylanguage.lang_dragonguard_supply_chest then VEQ.CheckDragonguardSupplyChest() end end )

		-- weeklies (trial of the week)
		EM:RegisterForEvent("VEQ", EVENT_RAID_OF_THE_WEEK_INFO_RECEIVED, VEQ.RaidOfTheWeek)
		EM:RegisterForEvent("VEQ", EVENT_RAID_OF_THE_WEEK_TURNOVER, VEQ.RaidOfTheWeek)
		
		-- achievements
		EM:RegisterForEvent("VEQ", EVENT_ACHIEVEMENT_UPDATED, function(_,id) VEQ.GetNearlyDoneAchievement(id) if VEQ.SavedVars.CommunityEvents then VEQ.CommunityEvents() end end )
		EM:RegisterForEvent("VEQ", EVENT_ACHIEVEMENT_AWARDED, function(_,_, _, id) VEQ.GetNearlyDoneAchievement(id) if VEQ.SavedVars.CommunityEvents then VEQ.CommunityEvents() end end )
    EM:RegisterForEvent("VEQ", EVENT_ACHIEVEMENT_TRACKING_UPDATE, function(_,id) VEQ.GetNearlyDoneAchievement(id) end )
    
    -- activity finder status
    EM:RegisterForEvent("VEQ", EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_,AFStatus) VEQ.AFStatus = AFStatus end )
		
		
		EM:RegisterForEvent("VEQ", EVENT_LOOT_RECEIVED, function(_,receivedBy,_,_,_,_,_,_,_,itemId) 
		    if VEQ.SavedVars.FishingAchievements and GetRawUnitName("player") == receivedBy then  
            VEQ.Fishing(itemId)
        end
    end)
    
      -- -- cancel achievement tracker show
      -- local achFragment = ACHIEVEMENT_TRACKER_FRAGMENT
      -- ZO_PreHook(achFragment, "Show", function(self)
           -- return true 
      -- end)
			
      -- -- cancel zone story tracker show
      -- local zoneFragment = ZONE_STORY_TRACKER_FRAGMENT
      -- ZO_PreHook(zoneFragment, "Show", function(self)
           -- return true 
      -- end)
      
			
		-- if VEQ.SavedVars.PositionLockOption == false then
			-- libDialog:ShowDialog("VEQ", "TrackerUnlocked", data)
		-- end
 
      zo_callLater(function() VEQ.checkInventoryOnStartup() end, 4900)
	    zo_callLater(function() VEQ.zoneStoryTracker() VEQ.mapCompletion(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()) end, 5000)
	    zo_callLater(function() VEQ.CheckCurrencies() end, 5100)
	    zo_callLater(function() VEQ.CheckLeads() end, 5200)

		
		if VEQ.SavedVars.GoldenPursuits then zo_callLater(function() VEQ.GoldenPursuits() end, 5300) end 
		if VEQ.SavedVars.TributeRewardTimer then zo_callLater(function() VEQ.CheckTributeRewardTimer() end, 5400) end
		if VEQ.SavedVars.DungeonRewardTimer then zo_callLater(function() VEQ.CheckDungeonRewardTimer() end, 5450) end
		if VEQ.SavedVars.BattlegroundRewardTimer then zo_callLater(function() VEQ.CheckBattlegroundRewardTimer() end, 5500) end
		if VEQ.SavedVars.ShadowySuppliers then zo_callLater(function() VEQ.CheckShadowySuppliers() end, 5550) end
		zo_callLater(function() VEQ.checkResetTime() end, 5600)
		zo_callLater(function() VEQ.RaidOfTheWeek() end, 5650)
		zo_callLater(function() VEQ.GetNearlyDoneAchievement() end, 5700)
    if VEQ.SavedVars.Rumors then zo_callLater(function() VEQ.Rumors() end, 5750) end
		if VEQ.SavedVars.Stable then zo_callLater(function() VEQ.CheckRidingSkillTimer() end, 5800) end
		zo_callLater(function() VEQ.groupFinder() end, 5850)
 
	else
		return
	end
 
end
 
 
-- Load only when game starts or /reloadui
EM:RegisterForEvent("VEQ", EVENT_ADD_ON_LOADED, VEQ.Init)


-- check scene change for hiding UI
SecurePostHook(SCENE_MANAGER, "OnSceneStateChange", function()
     zo_callLater(function() VEQ.CheckMode()  end, 100)
end)


SecurePostHook(ZO_Tracker , "SetTrackTypeAssisted", function() 
     VEQ.CheckFocusedQuest()
end)

 
-- Update every 1 second
EM:RegisterForUpdate("ClockUpdate", 1000, function()
  if not IsPlayerActivated() then return end
 
	if VEQ.SavedVars.ShowClockOption == true then
   	   local Time = os.date("%H:%M:%S")
       VEQ.clockInfos:SetText(Time)
	end
  
  -- 04/07/2026 performance improvement:
  -- This handler runs every second for every player, forever, regardless of settings.
  -- It used to unconditionally call GetMapPlayerPosition("player") and run the result
  -- through LibGPS3:LocalToGlobal() every tick, even though the only thing that ever
  -- consumes playerPosX/playerPosZ is the Skyshards distance check right below, which is
  -- itself gated behind VEQ.SavedVars.Skyshards. LibGPS3's local-to-global conversion does
  -- real work (zone data lookups/math), so paying that cost once per second for players who
  -- don't even have Skyshard tracking enabled was pure waste on a code path that never stops
  -- running. Gating the whole block behind the same VEQ.SavedVars.Skyshards check used by its
  -- only caller removes that per-second cost entirely for anyone with the feature turned off.
  if VEQ.SavedVars.Skyshards then
    local playerPosX, playerPosZ = LibGPS3:LocalToGlobal(GetMapPlayerPosition("player"))
    if VEQ.playerPositionAtLastSkyshardDistanceX ~= playerPosX or VEQ.playerPositionAtLastSkyshardDistanceZ ~= playerPosZ then VEQ.CheckSkyshardDistance(playerPosX, playerPosZ) end
  end
  
	if VEQ.AFStatus then
     VEQ.activityTracker()
  else
      VEQ.AFStatus = GetActivityFinderStatus()
  end 
  
	if VEQ.isInAllianceWarWaitingQueue then VEQ.AllianceWarQueue() end 
	if VEQ.SavedVars.GroupFrames then 
	   VEQ.GroupFrames() 
	   if IsUnitGrouped("player") and VEQ.MiniQuestList[16] and VEQ.FocusedMiniQuest ~= 16 and IsUnitInCombat("player") then -- force group frames as focused when in group and in combat
	       VEQ.FocusedMiniQuest = 16
		     VEQ.DisplayFocusedMiniQuest()
	   end
	end
	
	VEQ.UpdateTimeLimitForFocusedMiniQuest()
  VEQ.UpdatebackgroundOpacity()
end)
 
 
 