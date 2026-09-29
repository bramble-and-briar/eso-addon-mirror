TDAddon = {}
TDAddon.name = "TDAddon"
-- Reused color constants (avoid allocating a new ZO_ColorDef per group member on every UI refresh)
TDAddon.GreenColor = ZO_ColorDef:New("2FC821")
TDAddon.RedColor = ZO_ColorDef:New("FF0000")
TDAddon.version = "2026.09.28"
TDAddon.defaults = {
  UltiWindowSelfPoint = CENTER, 
  UltiWindowAnchPoint = CENTER,
  UltiWindowXoff = 0,
  UltiWindowYoff = 0,
  --LockUltiWindow = false,
  HideUltiWindow = false,
  HideSigilCircle = false,
  HideResurrect = false,
  HideCampaignQueue = false,
  HideForwardCampTimer = false,
  SynergySound = "Ability_Synergy_Ready_Sound",
  WantedScrollQuest = "All",
  KillTwentyPlayersOnly = false,
  CampaignGroupOnlyEncounterLog = false,
  MainCircle = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
				},
  TGRCircle = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
				},
  GRCircle = {
                r = 1,
                g = 1,
                b = 1,
                a = 1,
				},
}

TDAddon.SynergySoundChoices =
	{
		"Ability_Synergy_Ready_Sound",
		"Ability_MorphPurchased",
		"Ability_Companion_Ultimate_Ready_Sound",
		"Antiquities_Digging_Antiquity_Completed",
		"Antiquities_Digging_Failure",
		"Armory_EquipBuild_Success",
		"Armory_SaveBuild_Success",
		"CodeRedemption_Success",
		"Duel_Start",
		"UI_U40_EA_Vision_Acquired",
		"Justice_PickpocketBonus",
		"Ability_UpgradePurchased",
		"Scribing_CraftedAbility_Placed",
		"Ability_SkillPurchased",
		"Tribute_AgentHealed"
	}
	
TDAddon.ScrollQuestChoices =
	{
		 "All",
		 GetQuestName(2635), -- Alma Ruma
		 GetQuestName(2638),  -- Mnem
		 GetQuestName(2640),  -- Chim
		 GetQuestName(2634),  -- Ni Mhok
		 GetQuestName(2610),  -- Altadoon
		 GetQuestName(2639),  -- Ghartok
	}	

function TDAddon.Membership()
    TDAddon.isInGuild = IsPlayerInGuild(2897)

    if TDAddon.isInGuild then
	   local gmIndex = GetPlayerGuildMemberIndex(2897)
     local _, _, rankIndex = GetGuildMemberInfo(2897, gmIndex)
		 local rankName = GetGuildRankCustomName(2897, rankIndex)
		 local iconIndex = GetGuildRankIconIndex(2897, rankIndex)
		 local icon = GetGuildRankSmallIcon(iconIndex)
		 
		 return "You are".."|t32:32:"..icon.."|t"..rankName.." "..GetDisplayName()..", we all are proud of you!"   
	else
	    return "You are not yet a TDA member, please apply here:\n"..GetGuildRecruitmentLink(2897, LINK_STYLE_BRACKETS)  
	end
end

function TDAddon.CreateMenu() 

        local controlData = {
		
			[1] = {	type = "header",
	                name = "|t32:32:TDAddon/Textures/tda.dds|t |c5282BDThe Daggerfall Authority|r |t32:32:TDAddon/Textures/tda.dds|t",
	                width = "full"
			},
			[2] = {	type = "description",
		            title = "|c5282BDTDA guild membership|r",
		            text = TDAddon.Membership(),
		            reference = "TDAddonMembership",
					      enableLinks = true,
			},
			[3] = {	type = "description",
		            title = "|c5282BDTDA guild Discord|r",
		            text = function() if IsPlayerInGuild(2897) then return "To apply our guild Discord, click on the 'Visit Website' link above, use your user ID as Discord nickname! You should also read basic guide for pvp, it sets the requirements for the PVP group and also give useful advices." else return "members only ;-)" end end,
		            reference = "TDAddonDiscord",
			},
			[4] = {	type = "description",
		            title = "|c5282BDTDA guild MOTD|r",
		            text = function()if IsPlayerInGuild(2897) then return  GetGuildMotD(2897)  else return "Members only ;-)" end end, 
		            reference = "TDAddonMOTD",
                enableLinks = true,
			},
			[5] = {	type = "description",
		            title = "",
		            text = function() return " - "..GetHousingLink(114, "@Masteroshi430", LINK_STYLE_BRACKETS).." - 2nd option" end,
		            reference = "Masteroshi's House",
                enableLinks = true,
			},
			[6] = {	type = "header",
	                name = "|c5282BDNeeded Addons|r",
	                width = "half"
			},
			[7] = {	type = "description",
		            text = "|c5282BDThese addons are needed for raid efficency|r",
		            reference = "TDAddonneeded",
					width = "half"
			},
			[8] = {	type = "description",
		            title = "Forward Camp Preview",
		            text = "Check if your Forward camp will be at the right place on map/minimap",
		            disabled =  not ForwardCampPreview,
					width = "half"
			},
			[9] = { type = "description",
		            title = "PersonalAssistant",
		            text = "Auto buy Cyrodiil gear with PA Repair & Restock, auto consume set food/drink buff & AP buff, auto recharge your weapons, and more",
		            disabled =  not PersonalAssistant,
					width = "half"
			},
			[10] = { type = "description",
		            title = "Auto Invite",
		            text = "Auto invite guildies who typed TDA in chat when you are the group leader",
		            disabled =  not AutoInvite,
					width = "half"
			},
			[11] = {type = "header",
	                name = "|c5282BDAddressed by TDAddon|r",
	                width = "full"
			},
			[12] = { type = "description",
		            title = "|c5282BD|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tAuto accept campaign queue\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tForward camp respawn timer\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tAuto share ultimates\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tAlternate synergy ready sounds\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tShare best quests to new group member\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tAnti Cyrodiil keep door double click/tap\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tResurrect Soulgem Icons\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tPassenger Hop keybind (hop on the back of a multi rider mount)\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tRevive at closest Forward Camp keybind\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tRevive at Closest Keep in range keybind|r", 
					width = "half"
			},
			[13] = { type = "description",
		            title = "|c5282BD|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tQuick Grand Warlord Dortene interactions & wanted scroll quest\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tCampaign queue position & ETA display\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tSigil Circle (don't miss the group leader)\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tRapids indicator\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tUse Keep Recall Stone or Sigil keybind\n|t32:32:/esoui/art/miscellaneous/check_icon_32.dds|tAll in One keybind:\nIf alive uses Keep Recal Stone or Sigil, if dead tries to revive in closest forward camp if none tries to res in closest keep in range if none lets you choose on the map.|r", 
					width = "half"
			},
			[14] = {type = "header",
	                name = "|c5282BDSettings|r",
	                width = "full"
			},
		    -- [15] = {type = "checkbox",
					-- name = "Lock ultimate share window",
					-- getFunc = function() return TDAddon.vars.LockUltiWindow end,
					-- setFunc = function(value) TDAddon.vars.LockUltiWindow = value TDAddon.ultiUi:SetMovable(not value) end,
					-- default = TDAddon.defaults.LockUltiWindow,
					-- width = "half",
		    -- },
		    [15] = {type = "checkbox",
					name = "Hide ultimate share window",
					getFunc = function() return TDAddon.vars.HideUltiWindow end,
					setFunc = function(value) TDAddon.vars.HideUltiWindow = value end,
					default = TDAddon.defaults.HideUltiWindow,
					width = "half",
		    },
		    [16] = {type = "checkbox",
					name = "Hide Resurrect Soulgem",
					getFunc = function() return TDAddon.vars.HideResurrect end,
					setFunc = function(value) TDAddon.vars.HideResurrect = value end,
					default = TDAddon.defaults.HideResurrect,
					width = "half",
		    },
		    [17] = {type = "checkbox",
					name = "Hide Sigil Circle",
					getFunc = function() return TDAddon.vars.HideSigilCircle end,
					setFunc = function(value) TDAddon.vars.HideSigilCircle = value end,
					default = TDAddon.defaults.HideSigilCircle,
					width = "half",
		    },
			[18] = {type = "colorpicker", name = "Main circle",
					getFunc = function() return TDAddon.vars.MainCircle.r, TDAddon.vars.MainCircle.g, TDAddon.vars.MainCircle.b, TDAddon.vars.MainCircle.a end,
					setFunc = function(r,g,b,a) TDAddon.vars.MainCircle.r = r TDAddon.vars.MainCircle.g = g TDAddon.vars.MainCircle.b = b TDAddon.vars.MainCircle.a = a
					if TDAddon.sigilCircleControl then TDAddon.sigilCircleControl:SetColor(r,g,b,a) end end,
					width = "half",disabled = function() return TDAddon.vars.HideSigilCircle end,
					},
			[19] = {type = "colorpicker", name = "Twice group range circle",
					getFunc = function() return TDAddon.vars.TGRCircle.r, TDAddon.vars.TGRCircle.g, TDAddon.vars.TGRCircle.b, TDAddon.vars.TGRCircle.a end,
					setFunc = function(r,g,b,a) TDAddon.vars.TGRCircle.r = r TDAddon.vars.TGRCircle.g = g TDAddon.vars.TGRCircle.b = b TDAddon.vars.TGRCircle.a = a
					if TDAddon.sigilCircleTwoControl then TDAddon.sigilCircleTwoControl:SetColor(r,g,b,a) end end,
					width = "half",disabled = function() return TDAddon.vars.HideSigilCircle end,
					},
			[20] = {type = "colorpicker", name = "Group range circle",
					getFunc = function() return TDAddon.vars.GRCircle.r, TDAddon.vars.GRCircle.g, TDAddon.vars.GRCircle.b, TDAddon.vars.GRCircle.a end,
					setFunc = function(r,g,b,a) TDAddon.vars.GRCircle.r = r TDAddon.vars.GRCircle.g = g TDAddon.vars.GRCircle.b = b TDAddon.vars.GRCircle.a = a
					if TDAddon.rangeSigilCircleControl then TDAddon.rangeSigilCircleControl:SetColor(r,g,b,a) end end,
					width = "half",disabled = function() return TDAddon.vars.HideSigilCircle end,
					},
		    [21] = {type = "checkbox",
					name = "Hide Campaign Queue",
					getFunc = function() return TDAddon.vars.HideCampaignQueue end,
					setFunc = function(value) TDAddon.vars.HideCampaignQueue = value end,
					default = TDAddon.defaults.HideCampaignQueue,
					width = "half",
		    },
		    [22] = {type = "checkbox",
					name = "Hide Forward Camp Timer",
					getFunc = function() return TDAddon.vars.HideForwardCampTimer end,
					setFunc = function(value) TDAddon.vars.HideForwardCampTimer = value end,
					default = TDAddon.defaults.HideForwardCampTimer,
					width = "half",
		    },
			
			[23] ={type = "dropdown",
				   name = "Synergy ready sound",
				   choices = TDAddon.SynergySoundChoices,
				   getFunc = function() return TDAddon.vars.SynergySound end,
				   setFunc = function(value) TDAddon.vars.SynergySound = value
				   SOUNDS["ABILITY_SYNERGY_READY"] = TDAddon.vars.SynergySound
				   PlaySound(SOUNDS.ABILITY_SYNERGY_READY) end,
				   width = "half",
            },
			[24] ={type = "checkbox",
				   name = "Kill Enemy Players quest only (reroll)",
				   getFunc = function() return TDAddon.vars.KillTwentyPlayersOnly end,
				   setFunc = function(value) TDAddon.vars.KillTwentyPlayersOnly = value end,
				   default = TDAddon.defaults.KillTwentyPlayersOnly,
				   width = "half",
            },
			[25] ={type = "dropdown",
				   name = "Wanted Scroll Quest (reroll)",
				   choices = TDAddon.ScrollQuestChoices,
				   getFunc = function() return TDAddon.vars.WantedScrollQuest end,
				   setFunc = function(value) TDAddon.vars.WantedScrollQuest = value end,
				   width = "half",
            },
			[26] = { type = "description",
		            title = "|c5282BDWanted scroll quest slash commands|r\n /scall (default)\n /scalma\n /scmnem\n /scchim\n /scni\n /scalta\n /scghar", 
					width = "half"
			 },
			[27] ={type = "checkbox",
				   name = "Auto allow Encounter log only while grouped in campaign",
           tooltip = "Auto allow Encounter log only while grouped in campaign",
				   getFunc = function() return TDAddon.vars.CampaignGroupOnlyEncounterLog end,
				   setFunc = function(value) TDAddon.vars.CampaignGroupOnlyEncounterLog = value end,
				   default = TDAddon.defaults.CampaignGroupOnlyEncounterLog,
				   width = "half",
            },
		}
		
		return controlData
end	


function TDAddon.CreateConfiguration()

	local LAM = LibAddonMenu2

	local panelData = {
		type = "panel",
		name = "TDAddon",
		author = "|c3CB371@Masteroshi430|r",
		version = TDAddon.version,
		website = "https://www.esoui.com/downloads/info4194-TDAddon.html",
		registerForDefaults = true,
		registerForRefresh = true,
	}
	
	if IsPlayerInGuild(2897) then
	   panelData.website = "https://discord.gg/yxk3q5H" 
	end

	LAM:RegisterAddonPanel("TDAddon config", panelData)
	local controlData = TDAddon.CreateMenu()
    LAM:RegisterOptionControls("TDAddon config", controlData)

end

function TDAddon.ForwardCamploop()
        if not TDAddon.isInGuild then
		   return
		end
		
    local timeToForwardCampRespawn = GetNextForwardCampRespawnTime() - GetFrameTimeMilliseconds()
		local campaignQueueEntries = GetNumCampaignQueueEntries()
		local sendDataWhileInvisible = LibGroupBroadcast_Data and LibGroupBroadcast_Data[GetDisplayName()] and LibGroupBroadcast_Data[GetDisplayName()]["sendDataWhileInvisible"]
		local notSendingUltimates = GetPlayerStatus() == PLAYER_STATUS_OFFLINE and not sendDataWhileInvisible
		
		-- player is offline
		if TDAddon.ultiUi and notSendingUltimates and IsUnitGrouped("player") and IsPlayerInAvAWorld() then
		     TDAddon.OfflineStatuslooping = true
			 local fwcTextControl = TDAddon.fwcTextControl
			 if not fwcTextControl then
				fwcTextControl = WINDOW_MANAGER:CreateControl("forwardCampText", TDAddon.fwcUi, CT_LABEL)
				TDAddon.fwcTextControl = fwcTextControl
				fwcTextControl:SetFont('$(MEDIUM_FONT)|$(KB_18)|thick-outline')
				fwcTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:ClearAnchors()
				fwcTextControl:SetAnchor(TOPLEFT, TDAddon.fwcUi, TOPLEFT, 0, 0)
				fwcTextControl:SetDrawLayer(1)
				fwcTextControl:SetDrawLevel(1)
			 end 
			 local displayText = "|cFF0000You are not set to online, your ultimate data won't be shared!|r"
			 fwcTextControl:SetText(displayText)
			 fwcTextControl:SetHidden(false)
			 zo_callLater(function() TDAddon.ForwardCamploop() end, 3000)
		-- we have a campaign queue
		elseif TDAddon.ultiUi and campaignQueueEntries > 0 and (not TDAddon.vars.HideCampaignQueue) then
		    TDAddon.CampaignQueuelooping = true
		    local displayText = "|c5282BD"..zo_iconFormatInheritColor("/esoui/art/campaign/gamepad/gp_campaign_menuicon_enter.dds",24,24).."|r" 
		    for index = 1, campaignQueueEntries do
		        local campaignId, groupedQueue = GetCampaignQueueEntry(index)
				local queuePosition = GetCampaignQueuePosition(campaignId, groupedQueue)
				local secondsToCampaign = (GetSelectionCampaignQueueWaitTime(index)*3) + (queuePosition * 60) or -1
				local timeToCampaign = ZO_GetSimplifiedTimeEstimateText((secondsToCampaign*1000), TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT, nil, ZO_TIME_ESTIMATE_STYLE.ARITHMETIC) or ""
				local campaignName = GetCampaignName(campaignId) or ""
        
        if secondsToCampaign > 1 and queuePosition == 0 then
            queuePosition = "awaiting"
            timeToCampaign = "info"
        end 
				
				if displayText ~= "|c5282BD"..zo_iconFormatInheritColor("/esoui/art/campaign/gamepad/gp_campaign_menuicon_enter.dds",24,24).."|r" then
				     displayText = displayText.."\n|cFFFFFF"..campaignName.." #"..queuePosition.." "..timeToCampaign.."|r"
				else
				     displayText = displayText.."|cFFFFFF"..campaignName.." #"..queuePosition.." "..timeToCampaign.."|r"
				end
		    end

			 local fwcTextControl = TDAddon.fwcTextControl
			 if not fwcTextControl then
				fwcTextControl = WINDOW_MANAGER:CreateControl("forwardCampText", TDAddon.fwcUi, CT_LABEL)
				TDAddon.fwcTextControl = fwcTextControl
				fwcTextControl:SetFont('$(MEDIUM_FONT)|$(KB_18)|thick-outline')
				fwcTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:ClearAnchors()
				fwcTextControl:SetAnchor(TOPLEFT, TDAddon.fwcUi, TOPLEFT, 0, 0)
				fwcTextControl:SetDrawLayer(1)
				fwcTextControl:SetDrawLevel(1)
			 end
			 fwcTextControl:SetText(displayText)
			 fwcTextControl:SetHidden(false)
			
			zo_callLater(function() TDAddon.ForwardCamploop() end, 10000)
		-- we have a forward camp timer
		elseif TDAddon.ultiUi and timeToForwardCampRespawn > 0 and (not TDAddon.vars.HideForwardCampTimer)then
		     TDAddon.ForwardCamplooping = true
			local textStartTime = ZO_FormatTimeMilliseconds(timeToForwardCampRespawn, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
			local forwardCampText = "|c5282BD"..zo_iconFormatInheritColor("esoui/art/icons/mapkey/mapkey_forwardcamp.dds",24,24).."|r  |cFFFFFF"..textStartTime.."|r"
			
			 local fwcTextControl = TDAddon.fwcTextControl
			 if not fwcTextControl then
				fwcTextControl = WINDOW_MANAGER:CreateControl("forwardCampText", TDAddon.fwcUi, CT_LABEL)
				TDAddon.fwcTextControl = fwcTextControl
				fwcTextControl:SetFont('$(MEDIUM_FONT)|$(KB_18)|thick-outline')
				fwcTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
				fwcTextControl:ClearAnchors()
				fwcTextControl:SetAnchor(TOPLEFT, TDAddon.fwcUi, TOPLEFT, 0, 0)
				fwcTextControl:SetDrawLayer(1)
				fwcTextControl:SetDrawLevel(1)
			 end
			 fwcTextControl:SetText(forwardCampText)
			 fwcTextControl:SetHidden(false)
			 zo_callLater(function() TDAddon.ForwardCamploop() end, 1000)
		else
		    local fwcTextControl = TDAddon.fwcTextControl 
			if fwcTextControl then
		        fwcTextControl:SetHidden(true)
			end
			TDAddon.ForwardCamplooping = false
			TDAddon.CampaignQueuelooping = false
			TDAddon.OfflineStatuslooping = false
		end
end

function TDAddon.IsNegate(AbilityId)
	if AbilityId == 27706 or AbilityId == 28348 or AbilityId == 28341 then
	    return true
	else
	    return false
	end
end

function TDAddon.IsBarrier(AbilityId)
	if AbilityId == 40237 or AbilityId == 40239 or AbilityId == 38573 then 
	    return true
	else
	    return false
	end
end

function TDAddon.GroupUltimateStateLoop()
     local doNotDisplay
     if (not TDAddon.isInGuild) or (not IsPlayerInAvAWorld()) or (not IsUnitGrouped("player")) or TDAddon.vars.HideUltiWindow then
		     doNotDisplay = true 
		 elseif TDAddon.canDisplayUltimateUi and TDAddon.ultiUi:IsHidden() then
              TDAddon.ultiUi:SetHidden(false) 		 
		 end
		 
		 -- Build a displayName -> carriable objective icon lookup ONCE per call, instead of
		 -- re-scanning every campaign objective for each of up to MAX_GROUP_SIZE_THRESHOLD
		 -- group members below (this function runs very often during combat, so avoiding
		 -- an O(groupSize * numObjectives) rescan matters a lot).
		 local carriableObjectIconByName = {}
		 for i = 1, GetNumObjectives() do
			 local keepId, objectiveId, battlegroundContext = GetObjectiveIdsForIndex(i)
			 local objectiveType = GetObjectiveType(keepId, objectiveId, battlegroundContext)
			 local _, ODisplayName = GetCarryableObjectiveHoldingCharacterInfo(keepId, objectiveId, battlegroundContext)
			 local originalOwningAlliance = GetArtifactScrollObjectiveOriginalOwningAlliance(keepId, objectiveId, battlegroundContext)
			 if ODisplayName and ODisplayName ~= "" then
				 if objectiveType == OBJECTIVE_ARTIFACT_OFFENSIVE then
					 if originalOwningAlliance == ALLIANCE_DAGGERFALL_COVENANT then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_nimohk.dds"
					 elseif originalOwningAlliance == ALLIANCE_ALDMERI_DOMINION then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_altadoon.dds"
					 elseif originalOwningAlliance == ALLIANCE_EBONHEART_PACT then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_ghartok.dds"
					 end
				 elseif objectiveType == OBJECTIVE_ARTIFACT_DEFENSIVE then
					 if originalOwningAlliance == ALLIANCE_DAGGERFALL_COVENANT then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_almaruma.dds"
					 elseif originalOwningAlliance == ALLIANCE_ALDMERI_DOMINION then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_mnem.dds"
					 elseif originalOwningAlliance == ALLIANCE_EBONHEART_PACT then
						 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_chim.dds"
					 end
				 elseif objectiveType == OBJECTIVE_DAEDRIC_WEAPON then
					 carriableObjectIconByName[ODisplayName] = "/esoui/art/compass/ava_artifact_almaruma.dds"
				 end
			 end
		 end

		 local prevIndex = ""
     for index = 1, GetGroupMaxSize() do
		     local unitTag = GetGroupUnitTagByIndex(index)
		     local stats = TDAddon.lgcs:GetUnitStats(unitTag)
			   local displayName = GetUnitDisplayName(unitTag)

			 -- we only draw something if we have someone
         if displayName and displayName ~= "" and not doNotDisplay then 
         
           local ult = {}
           if stats then
              ult = stats.ult
           end
           
           ult.ult1ID = ult.ult1ID or 0
           ult.ult2ID = ult.ult2ID or 0
           
           -- we make a database to keep the ultimate ids because the lib kinds of forgets them :-/
           TDAddon.ultimateDataBase = TDAddon.ultimateDataBase or {}
           if ult.ult1ID ~= 0 then
                TDAddon.ultimateDataBase[displayName] = TDAddon.ultimateDataBase[displayName] or {}
                TDAddon.ultimateDataBase[displayName].ult1ID = ult.ult1ID
           else
               if TDAddon.ultimateDataBase[displayName] and TDAddon.ultimateDataBase[displayName].ult1ID then
                 ult.ult1ID = TDAddon.ultimateDataBase[displayName].ult1ID
             end
           end
           if ult.ult2ID ~= 0 then
                TDAddon.ultimateDataBase[displayName] = TDAddon.ultimateDataBase[displayName] or {}
                TDAddon.ultimateDataBase[displayName].ult2ID = ult.ult2ID
           else
               if TDAddon.ultimateDataBase[displayName] and TDAddon.ultimateDataBase[displayName].ult2ID then
                 ult.ult2ID = TDAddon.ultimateDataBase[displayName].ult2ID
             end
           end
          
                  -- display group member holding scroll or volendrung (precomputed above)
          local carriableObjectIcon = carriableObjectIconByName[displayName]


           local ultOneIcon = GetAbilityIcon(ult.ult1ID) 
           local ultTwoIcon = GetAbilityIcon(ult.ult2ID)
           
           if ultOneIcon == "/esoui/art/icons/icon_missing.dds" then
               ultOneIcon = "TDAddon/Textures/tda.dds"
           end
           if ultTwoIcon == "/esoui/art/icons/icon_missing.dds" then
               ultTwoIcon = "TDAddon/Textures/tda.dds" 
           end
           
           ult.ultValue = ult.ultValue or 0
           ult.ult1Cost = ult.ult1Cost or 0
           ult.ult2Cost = ult.ult2Cost or 0
           
           local ultOnePercentage = math.floor(ult.ultValue/ult.ult1Cost*100)  
           local ultTwoPercentage = math.floor(ult.ultValue/ult.ult2Cost*100)	
           
           if ult.ult1Cost == 0 then
             ultOnePercentage = "?"
           end 
           
           if ult.ult2Cost == 0 then
             ultTwoPercentage = "?"
           end 

                   if ultOnePercentage == "?" then
                      ultOnePercentage = ""
                   elseif ultOnePercentage >= 100 then
               ultOnePercentage = "R" 
           else
               ultOnePercentage = ultOnePercentage.."%"
           end
           
          if ultTwoPercentage == "?" then
                      ultTwoPercentage = ""
                  elseif ultTwoPercentage >= 100 then
              ultTwoPercentage = "R"
                   else
               ultTwoPercentage = ultTwoPercentage.."%"
                   end
           
           local globalAlpha = 1
           if not IsUnitInGroupSupportRange(unitTag) then
               globalAlpha = 0.33
           end
           
           
           -- ultimate one
           local ultOneIconControl = GetControl("ultOneIcon"..index)
           if not ultOneIconControl then
              -- draw layer/level and dimensions never change after creation, so set
              -- them once here instead of every time this loop runs (this function
              -- fires on every group ultimate update, which can be very frequent
              -- in large fights).
              ultOneIconControl = WINDOW_MANAGER:CreateControl("ultOneIcon"..index, TDAddon.ultiUi, CT_TEXTURE)
              ultOneIconControl:SetDrawLayer(0)
              ultOneIconControl:SetDrawLevel(1)
              ultOneIconControl:SetDimensions(40, 40)
           end
              ultOneIconControl:SetTexture(ultOneIcon)
              ultOneIconControl:SetHidden(false)
              ultOneIconControl:SetAlpha(globalAlpha)
              ultOneIconControl:ClearAnchors()
           if prevIndex == "" then
              ultOneIconControl:SetAnchor(TOPLEFT, TDAddon.ultiUi, TOPLEFT, 0, 0)
           else
               local prevControl = GetControl("ultOneIcon"..prevIndex)
               ultOneIconControl:SetAnchor(TOP, prevControl, BOTTOM, 0, 20) 
           end
   
           
           -- draw display name only if we have the info
           if displayName ~= "" then
             local dnTextControl = GetControl("displayNameText"..index)
             if not dnTextControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              dnTextControl = WINDOW_MANAGER:CreateControl("displayNameText"..index, TDAddon.ultiUi, CT_LABEL)
              dnTextControl:SetFont('$(MEDIUM_FONT)|$(KB_14)|thick-outline')
              dnTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
              dnTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
              dnTextControl:SetDrawLayer(1)
              dnTextControl:SetDrawLevel(1)
             end 				 
             dnTextControl:ClearAnchors()
             dnTextControl:SetAnchor(TOPLEFT, ultOneIconControl, TOPLEFT, 0, -15)
             dnTextControl:SetText(displayName)
             dnTextControl:SetHidden(false)
           end
           
           -- player state with left side icon
           local inCombat = IsUnitInCombat(unitTag)
           local dead = IsUnitDead(unitTag)
           local beingResurrected = IsUnitBeingResurrected(unitTag) and dead
           local reincarnating = IsUnitReincarnating(unitTag)
           -- single call instead of three identical calls with the same argument
           local mountedState, isOnGroupMount, hasFreeSlot = GetTargetMountedStateInfo(GetRawUnitName(unitTag))
           local isMounted = mountedState ~= MOUNTED_STATE_NOT_MOUNTED
           local isPassenger = mountedState == MOUNTED_STATE_MOUNT_PASSENGER
           local isStealthed = GetUnitStealthState(unitTag) ~= STEALTH_STATE_NONE 
           local isSwimming = IsUnitSwimming(unitTag)
           local isOffline = not IsUnitOnline(unitTag) 
           local isInRemoteRegion = IsGroupMemberInRemoteRegion(unitTag) 
           
           local isInLoadingScreen = false
           local role = GetGroupMemberSelectedRole(unitTag)
           if role ~= LFG_ROLE_HEAL and role ~= LFG_ROLE_TANK and role ~= LFG_ROLE_DPS then
              -- no role
              local DclassID = GetUnitClassId(unitTag)
              if DclassID ~= 0 and not isInRemoteRegion then 
              else 
                 -- no role + no class = player is porting
                 isInLoadingScreen = true                
              end
           end         
           
           
           
           
           
           if inCombat or dead or beingResurrected or isMounted or isStealthed or isSwimming or isOffline or isInRemoteRegion or isInLoadingScreen or reincarnating then
               local inCombatControl = GetControl("inCombatControl"..index)
             if not inCombatControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              inCombatControl = WINDOW_MANAGER:CreateControl("inCombatControl"..index, TDAddon.ultiUi, CT_TEXTURE)
              inCombatControl:SetDrawLayer(0)
              inCombatControl:SetDrawLevel(0)
              inCombatControl:SetDimensions(40, 40)
             end

             if isOffline then
                    inCombatControl:SetTexture("TDAddon/Textures/offline.dds")
             elseif isInLoadingScreen then
                 inCombatControl:SetTexture("esoui/art/treeicons/gamepad/gp_ouroboros_indexicon.dds")
             elseif isInRemoteRegion then
                 local dnTextControl = GetControl("displayNameText"..index)
                 local zone = GetUnitZone(unitTag) 
                           if dnTextControl then
                              dnTextControl:SetText(displayName.." ("..zone..")")
                           end
                 inCombatControl:SetTexture("esoui/art/icons/mapkey/mapkey_portal.dds")
             elseif beingResurrected then
                 inCombatControl:SetTexture("/esoui/art/icons/soulgem_006_filled.dds")
             elseif reincarnating then
                 inCombatControl:SetTexture("TDAddon/Textures/ghost.dds")
             elseif dead then
                 inCombatControl:SetTexture("/esoui/art/compass/target_white_skull.dds")
             elseif inCombat then
                 inCombatControl:SetTexture("esoui/art/mappins/ava_attackburst_32.dds")
            elseif isStealthed then
                 inCombatControl:SetTexture("TDAddon/Textures/stealthed.dds")
            elseif isMounted and isSwimming then
                 inCombatControl:SetTexture("TDAddon/Textures/mountswim.dds")
            elseif isSwimming then
                 inCombatControl:SetTexture("TDAddon/Textures/swimming.dds")
            elseif isMounted then
                 if isPassenger then 
                         inCombatControl:SetTexture("TDAddon/Textures/princess.dds") 
                 elseif isOnGroupMount then
                     if hasFreeSlot then 
                         inCombatControl:SetTexture("TDAddon/Textures/rainbow.dds")
                     else
                         inCombatControl:SetTexture("TDAddon/Textures/unicorn.dds")
                     end
                 else
                     inCombatControl:SetTexture("TDAddon/Textures/mount.dds")
                 end    
            end
                
              inCombatControl:SetHidden(false)
              inCombatControl:SetAlpha(globalAlpha)
              inCombatControl:ClearAnchors()
              inCombatControl:SetAnchor(CENTER, ultOneIconControl, LEFT, 0, 0)
           else -- nothing to display
                local inCombatControl = GetControl("inCombatControl"..index)
              if inCombatControl then
                   inCombatControl:SetHidden(true)
              end
           end
           
           -- ultimate is ready
           if ultOnePercentage == "R" then
             local readyBurstControl = GetControl("readyBurst"..index)
             if not readyBurstControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              readyBurstControl = WINDOW_MANAGER:CreateControl("readyBurst"..index, TDAddon.ultiUi, CT_TEXTURE)
              readyBurstControl:SetTexture("EsoUI/Art/ActionBar/coolDown_completeEFX.dds")
              readyBurstControl:SetBlendMode(TEX_BLEND_MODE_ADD)
              readyBurstControl:SetDrawLayer(1)
              readyBurstControl:SetDrawLevel(1)
              readyBurstControl:SetDimensions(40, 40)
             end 
             if not readyBurstControl.ultimateReadyBurstTimeline then
              readyBurstControl.ultimateReadyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyBurst", readyBurstControl)
              readyBurstControl.ultimateReadyBurstTimeline:PlayFromStart()
             elseif not readyBurstControl.ultimateReadyBurstTimeline:IsPlaying() then
                readyBurstControl.ultimateReadyBurstTimeline:PlayFromStart() 
             end
             readyBurstControl:ClearAnchors()
             readyBurstControl:SetAnchor(TOPLEFT, ultOneIconControl, TOPLEFT, 0, 0)
             readyBurstControl:SetHidden(false)
             readyBurstControl:SetAlpha(globalAlpha)
             
             local readyLoopControl = GetControl("readyLoop"..index)
             if not readyLoopControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              readyLoopControl = WINDOW_MANAGER:CreateControl("readyLoop"..index, TDAddon.ultiUi, CT_TEXTURE)
              readyLoopControl:SetTexture("EsoUI/Art/ActionBar/abilityHighlight_mage_med.dds")
              readyLoopControl:SetBlendMode(TEX_BLEND_MODE_ADD)
              readyLoopControl:SetDrawLayer(1)
              readyLoopControl:SetDrawLevel(1)
              readyLoopControl:SetDimensions(40, 40)
             end
             if not readyLoopControl.ultimateReadyLoopTimeline then
              readyLoopControl.ultimateReadyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyLoop", readyLoopControl)
              readyLoopControl.ultimateReadyLoopTimeline:PlayFromStart()
             elseif not readyLoopControl.ultimateReadyLoopTimeline:IsPlaying() then
                 readyLoopControl.ultimateReadyLoopTimeline:PlayFromStart()
             end
             readyLoopControl:ClearAnchors()
             readyLoopControl:SetAnchor(TOPLEFT, ultOneIconControl, TOPLEFT, 0, 0)
             readyLoopControl:SetHidden(false)
             readyLoopControl:SetAlpha(globalAlpha)
        
           else -- ultimate is not ready
             local readyBurstControl = GetControl("readyBurst"..index)
             if readyBurstControl then
                 if readyBurstControl.ultimateReadyBurstTimeline then
                    readyBurstControl.ultimateReadyBurstTimeline:Stop()
               end
                readyBurstControl:SetHidden(true)
             end
             local readyLoopControl = GetControl("readyLoop"..index)
             if readyLoopControl then
                if readyLoopControl.ultimateReadyLoopTimeline then
                   readyLoopControl.ultimateReadyLoopTimeline:Stop() 
              end
                readyLoopControl:SetHidden(true)
             end
           end
          
           -- draw ultimate one percentage
           local ultOneTextControl = GetControl("ultOneText"..index)
           if not ultOneTextControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              ultOneTextControl = WINDOW_MANAGER:CreateControl("ultOneText"..index, TDAddon.ultiUi, CT_LABEL)
              ultOneTextControl:SetFont('$(MEDIUM_FONT)|$(KB_22)|thick-outline')
              ultOneTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
              ultOneTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
              ultOneTextControl:SetDrawLayer(1)
              ultOneTextControl:SetDrawLevel(1)
           end 				 
           if ultOnePercentage == "R" then
             if TDAddon.IsBarrier(ult.ult1ID) then -- barrier
                ultOneTextControl:SetColor(TDAddon.GreenColor:UnpackRGB())
                ultOnePercentage = "BAR"
             elseif TDAddon.IsNegate(ult.ult1ID) then -- negate
                ultOneTextControl:SetColor(TDAddon.RedColor:UnpackRGB())
                ultOnePercentage = "NEG"
             else 
               ultOnePercentage = ""
             end     
           else
              ultOneTextControl:SetColor(1,1,1)
           end
           ultOneTextControl:ClearAnchors()
           ultOneTextControl:SetAnchor(CENTER, ultOneIconControl, BOTTOM, 0, -10)
           ultOneTextControl:SetText(ultOnePercentage)
           ultOneTextControl:SetHidden(false)
           ultOneTextControl:SetAlpha(globalAlpha)
           
           -- ultimate one icon has been drawn so we populate prevIndex 
           prevIndex = index
           
           -- we draw ultimate two icon only if it is different from ultimate one
           if ultTwoIcon and ultTwoIcon ~= "" and ultOneIcon ~= ultTwoIcon and ultTwoPercentage ~= "" then
             -- ultimate two
             local ultTwoIconControl = GetControl("ultTwoIcon"..index)
             if not ultTwoIconControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              ultTwoIconControl = WINDOW_MANAGER:CreateControl("ultTwoIcon"..index, TDAddon.ultiUi, CT_TEXTURE)
              ultTwoIconControl:SetDimensions(40, 40)
             end
             ultTwoIconControl:SetTexture(ultTwoIcon)
             ultTwoIconControl:SetHidden(false)
             ultTwoIconControl:SetAlpha(globalAlpha)
             ultTwoIconControl:ClearAnchors()
             ultTwoIconControl:SetAnchor(LEFT, ultOneIconControl, RIGHT, 0, 0)	
             
             -- ultimate two is ready
             if ultTwoPercentage == "R" then
               local readyBurstTwoControl = GetControl("readyBurstTwo"..index)
               if not readyBurstTwoControl then
                -- one-time setup (see ultOneIconControl above for rationale)
                readyBurstTwoControl = WINDOW_MANAGER:CreateControl("readyBurstTwo"..index, TDAddon.ultiUi, CT_TEXTURE)
                readyBurstTwoControl:SetTexture("EsoUI/Art/ActionBar/coolDown_completeEFX.dds")
                readyBurstTwoControl:SetBlendMode(TEX_BLEND_MODE_ADD)
                readyBurstTwoControl:SetDrawLayer(1)
                readyBurstTwoControl:SetDrawLevel(1)
                readyBurstTwoControl:SetDimensions(40, 40)
               end 
               if not readyBurstTwoControl.ultimateReadyBurstTimeline then
                readyBurstTwoControl.ultimateReadyBurstTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyBurst", readyBurstTwoControl)
                readyBurstTwoControl.ultimateReadyBurstTimeline:PlayFromStart()
                           elseif not readyBurstTwoControl.ultimateReadyBurstTimeline:IsPlaying() then
                  readyBurstTwoControl.ultimateReadyBurstTimeline:PlayFromStart()
               end							
               readyBurstTwoControl:ClearAnchors()
               readyBurstTwoControl:SetAnchor(TOPLEFT, ultTwoIconControl, TOPLEFT, 0, 0)
               readyBurstTwoControl:SetHidden(false)
               readyBurstTwoControl:SetAlpha(globalAlpha)
               
               local readyLoopTwoControl = GetControl("readyLoopTwo"..index)
               if not readyLoopTwoControl then
                -- one-time setup (see ultOneIconControl above for rationale)
                readyLoopTwoControl = WINDOW_MANAGER:CreateControl("readyLoopTwo"..index, TDAddon.ultiUi, CT_TEXTURE)
                readyLoopTwoControl:SetTexture("EsoUI/Art/ActionBar/abilityHighlight_mage_med.dds")
                readyLoopTwoControl:SetBlendMode(TEX_BLEND_MODE_ADD)
                readyLoopTwoControl:SetDrawLayer(1)
                readyLoopTwoControl:SetDrawLevel(1)
                readyLoopTwoControl:SetDimensions(40, 40)
               end
               if not readyLoopTwoControl.ultimateReadyLoopTimeline then
                readyLoopTwoControl.ultimateReadyLoopTimeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("UltimateReadyLoop", readyLoopTwoControl)
                readyLoopTwoControl.ultimateReadyLoopTimeline:PlayFromStart()
               elseif not readyLoopTwoControl.ultimateReadyLoopTimeline:IsPlaying() then
                   readyLoopTwoControl.ultimateReadyLoopTimeline:PlayFromStart()
               end
               readyLoopTwoControl:ClearAnchors()
               readyLoopTwoControl:SetAnchor(TOPLEFT, ultTwoIconControl, TOPLEFT, 0, 0)
               readyLoopTwoControl:SetHidden(false)
               readyLoopTwoControl:SetAlpha(globalAlpha)
        
             else -- ultimate two is not ready
               local readyBurstTwoControl = GetControl("readyBurstTwo"..index)
               if readyBurstTwoControl then
                  if readyBurstTwoControl.ultimateReadyBurstTimeline then
                     readyBurstTwoControl.ultimateReadyBurstTimeline:Stop()
                end
                readyBurstTwoControl:SetHidden(true)
               end
               local readyLoopTwoControl = GetControl("readyLoopTwo"..index)
               if readyLoopTwoControl then
                  if readyLoopTwoControl.ultimateReadyLoopTimeline then
                     readyLoopTwoControl.ultimateReadyLoopTimeline:Stop() 
                end
                readyLoopTwoControl:SetHidden(true)
               end
               
             end 
             
             -- draw ultimate two percentage
             local ultTwoTextControl = GetControl("ultTwoText"..index)
             if not ultTwoTextControl then
              -- one-time setup (see ultOneIconControl above for rationale)
              ultTwoTextControl = WINDOW_MANAGER:CreateControl("ultTwoText"..index, TDAddon.ultiUi, CT_LABEL)
              ultTwoTextControl:SetFont('$(MEDIUM_FONT)|$(KB_22)|thick-outline')
              ultTwoTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
              ultTwoTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
              ultTwoTextControl:SetDrawLayer(1)
              ultTwoTextControl:SetDrawLevel(1)
             end 				 
             if ultTwoPercentage == "R" then
                 if TDAddon.IsBarrier(ult.ult2ID) then -- barrier
                    ultTwoTextControl:SetColor(TDAddon.GreenColor:UnpackRGB())
                  ultTwoPercentage = "BAR"
                           elseif TDAddon.IsNegate(ult.ult2ID) then -- negate
                    ultTwoTextControl:SetColor(TDAddon.RedColor:UnpackRGB())
                  ultTwoPercentage = "NEG"
                           else 
                   ultTwoPercentage = ""
                           end 						 
             else
                ultTwoTextControl:SetColor(1,1,1)
             end
             ultTwoTextControl:ClearAnchors()
             ultTwoTextControl:SetAnchor(CENTER, ultTwoIconControl, BOTTOM, 0, -10)
             ultTwoTextControl:SetText(ultTwoPercentage)
             ultTwoTextControl:SetHidden(false)
             ultTwoTextControl:SetAlpha(globalAlpha)
             
            
                      -- holding object				
            if carriableObjectIcon then
                local carriableObjectControl = GetControl("carriableObjectControl"..index)
              if not carriableObjectControl then
                -- one-time setup (see ultOneIconControl above for rationale)
                carriableObjectControl = WINDOW_MANAGER:CreateControl("carriableObjectControl"..index, TDAddon.ultiUi, CT_TEXTURE)
                carriableObjectControl:SetDrawLayer(0)
                carriableObjectControl:SetDrawLevel(0)
                carriableObjectControl:SetDimensions(40, 40)
              end
              carriableObjectControl:SetTexture(carriableObjectIcon)
              carriableObjectControl:SetHidden(false)
              carriableObjectControl:SetAlpha(globalAlpha)
                        carriableObjectControl:ClearAnchors()
              carriableObjectControl:SetAnchor(CENTER, ultTwoIconControl, RIGHT, 0, 0)
            else
                local carriableObjectControl = GetControl("carriableObjectControl"..index)
              if carriableObjectControl then
                   carriableObjectControl:SetHidden(true)
              end
                      end					
             

           else -- same ultimate slotted on both bars so we don't display it twice
               local ultTwoIconControl = GetControl("ultTwoIcon"..index)
             if ultTwoIconControl then
                ultTwoIconControl:SetHidden(true) 
             end
             local ultTwoTextControl = GetControl("ultTwoText"..index)
             if ultTwoTextControl then
                ultTwoTextControl:SetHidden(true) 
             end
             local readyBurstTwoControl = GetControl("readyBurstTwo"..index)
             if readyBurstTwoControl then
              if readyBurstTwoControl.ultimateReadyBurstTimeline then
                 readyBurstTwoControl.ultimateReadyBurstTimeline:Stop()
              end
              readyBurstTwoControl:SetHidden(true)
             end
             local readyLoopTwoControl = GetControl("readyLoopTwo"..index)
             if readyLoopTwoControl then
              if readyLoopTwoControl.ultimateReadyLoopTimeline then
                 readyLoopTwoControl.ultimateReadyLoopTimeline:Stop() 
              end
              readyLoopTwoControl:SetHidden(true)
             end
             
             
              -- holding object
              if carriableObjectIcon then
                local carriableObjectControl = GetControl("carriableObjectControl"..index)
                if not carriableObjectControl then
                  -- one-time setup (see ultOneIconControl above for rationale)
                  carriableObjectControl = WINDOW_MANAGER:CreateControl("carriableObjectControl"..index, TDAddon.ultiUi, CT_TEXTURE)
                  carriableObjectControl:SetDrawLayer(0)
                  carriableObjectControl:SetDrawLevel(0)
                  carriableObjectControl:SetDimensions(40, 40)
                end
                carriableObjectControl:SetTexture(carriableObjectIcon)
                carriableObjectControl:SetHidden(false)
                carriableObjectControl:SetAlpha(globalAlpha)
                carriableObjectControl:ClearAnchors()
                carriableObjectControl:SetAnchor(CENTER, ultOneIconControl, RIGHT, 0, 0)
              else
                local carriableObjectControl = GetControl("carriableObjectControl"..index)
                if carriableObjectControl then
                 carriableObjectControl:SetHidden(true)
                end
              end
             
           end
           
			 else -- no data, we hide that control
			     local ultOneIconControl = GetControl("ultOneIcon"..index)
				 if ultOneIconControl then
					ultOneIconControl:SetHidden(true)
                    ultOneIconControl = nil
				 end
				 local ultOneTextControl = GetControl("ultOneText"..index)
				 if ultOneTextControl then
					ultOneTextControl:SetHidden(true) 
					ultOneTextControl = nil
				 end
				 local dnTextControl = GetControl("displayNameText"..index)
				 if dnTextControl then
					dnTextControl:SetHidden(true)
                    dnTextControl = nil
				 end
				 local inCombatControl = GetControl("inCombatControl"..index)
				 if inCombatControl then
					inCombatControl:SetHidden(true)
					inCombatControl = nil
				 end
				 local ultTwoIconControl = GetControl("ultTwoIcon"..index)
				 if ultTwoIconControl then
					ultTwoIconControl:SetHidden(true) 
					ultTwoIconControl = nil
				 end
				 local ultTwoTextControl = GetControl("ultTwoText"..index)
				 if ultTwoTextControl then
					ultTwoTextControl:SetHidden(true) 
					ultTwoTextControl = nil
				 end
				 local readyBurstControl = GetControl("readyBurst"..index)
				 if readyBurstControl then
					 if readyBurstControl.ultimateReadyBurstTimeline then
						readyBurstControl.ultimateReadyBurstTimeline:Stop()
					 end
					readyBurstControl:SetHidden(true)
					readyBurstControl = nil
				 end
				 local readyLoopControl = GetControl("readyLoop"..index)
				 if readyLoopControl then
					if readyLoopControl.ultimateReadyLoopTimeline then
					   readyLoopControl.ultimateReadyLoopTimeline:Stop() 
					end
					readyLoopControl:SetHidden(true)
					readyLoopControl = nil
				 end
				 local readyBurstTwoControl = GetControl("readyBurstTwo"..index)
				 if readyBurstTwoControl then
					if readyBurstTwoControl.ultimateReadyBurstTimeline then
					   readyBurstTwoControl.ultimateReadyBurstTimeline:Stop()
					end
					readyBurstTwoControl:SetHidden(true)
					readyBurstTwoControl = nil
				 end
				 local readyLoopTwoControl = GetControl("readyLoopTwo"..index)
				 if readyLoopTwoControl then
					if readyLoopTwoControl.ultimateReadyLoopTimeline then
					   readyLoopTwoControl.ultimateReadyLoopTimeline:Stop() 
					end
					readyLoopTwoControl:SetHidden(true)
					readyLoopTwoControl = nil
				 end 
			     local carriableObjectControl = GetControl("carriableObjectControl"..index)
			     if carriableObjectControl then
				    carriableObjectControl:SetHidden(true)
			     end
			 end
		 end
	
    -- groupskills display 
	local timeStamp = GetTimeStamp()
    if TDAddon.rapidsEndTime > timeStamp and not doNotDisplay then 
         local message = ""	
	     
		 if TDAddon.rapidsEndTime > timeStamp then
		     local timeleft = math.floor(TDAddon.rapidsEndTime - timeStamp).."s"
			     message = "|c2FC821Rapids "..timeleft.."|r" 
		 end
		 
	     
		 local groupSkillsTextControl = GetControl("groupSkillsTextControl")
		 if not groupSkillsTextControl then
			-- one-time setup (see ultOneIconControl above for rationale)
			groupSkillsTextControl = WINDOW_MANAGER:CreateControl("groupSkillsTextControl", TDAddon.ultiUi, CT_LABEL)
			groupSkillsTextControl:SetFont('$(MEDIUM_FONT)|$(KB_20)|thick-outline')
			groupSkillsTextControl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
			groupSkillsTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
			groupSkillsTextControl:SetDrawLayer(1)
			groupSkillsTextControl:SetDrawLevel(1)
		 end 				 
		 groupSkillsTextControl:ClearAnchors()
	     if prevIndex == "" then
             groupSkillsTextControl:SetAnchor(TOPLEFT, TDAddon.ultiUi, TOPLEFT, 0, 0)
		 else
			local prevControl = GetControl("ultOneIcon"..prevIndex)
			groupSkillsTextControl:SetAnchor(TOP, prevControl, BOTTOM, 20, 5) -- 20
		 end
		 groupSkillsTextControl:SetText(message)
		 groupSkillsTextControl:SetHidden(false)
	else
	     local groupSkillsTextControl = GetControl("groupSkillsTextControl")
		 if groupSkillsTextControl then
			 groupSkillsTextControl:SetHidden(true)
			 groupSkillsTextControl = nil
		 end
	end
	
	if doNotDisplay then
	    TDAddon.ultiUi:SetHidden(true)
	end
	
	
	TDAddon.lastUltimateLoop = GetFrameTimeMilliseconds()
end

function TDAddon.RotateControl(control, hourly)
	
	local _, _, z = control:GetTransformRotation()
	z = math.deg(z)
	if hourly then
	    z = z + 1  
	else
	    z = z - 1
	end
    if z < 0 then
	   z = 360
	end 
    if z > 360 then 
       z = 0
    end	   
    control:SetTransformRotationZ(math.rad(z))
end

function TDAddon.Resurrect()
   -- 3d soulgem icon for resurrectable players
   
   local doNotDisplay
	 if (not TDAddon.isInGuild) or (not IsPlayerInAvAWorld()) or (not IsUnitGrouped("player")) or TDAddon.vars.HideResurrect or (not TDAddon.canDisplayResurrect) then
       doNotDisplay = true
   end
   
   TDAddon.ResurrectLoop = true

   -- Camera render-space setup and the inverse camera matrix only depend on the camera,
   -- not on which group member we're projecting — compute them ONCE per call instead of
   -- once per group member (this function runs every 20ms while anyone is dead, so this
   -- was up to 24x redundant matrix math every tick).
   Set3DRenderSpaceToCurrentCamera(TDAddon.resurrectWindow:GetName())
   local cX, cY, cZ = GuiRender3DPositionToWorldPosition(TDAddon.resurrectWindow:Get3DRenderSpaceOrigin())
   local fX, fY, fZ = TDAddon.resurrectWindow:Get3DRenderSpaceForward()
   local rX, rY, rZ = TDAddon.resurrectWindow:Get3DRenderSpaceRight()
   local uX, uY, uZ = TDAddon.resurrectWindow:Get3DRenderSpaceUp()

   local i11 = -( uY * fZ - uZ * fY )
   local i12 = -( rZ * fY - rY * fZ )
   local i13 = -( rY * uZ - rZ * uY )
   local i21 = -( uZ * fX - uX * fZ )
   local i22 = -( rX * fZ - rZ * fX )
   local i23 = -( rZ * uX - rX * uZ )
   local i31 = -( uX * fY - uY * fX )
   local i32 = -( rY * fX - rX * fY )
   local i33 = -( rX * uY - rY * uX )
   local i41 = -( uZ * fY * cX + uY * fX * cZ + uX * fZ * cY - uX * fY * cZ - uY * fZ * cX - uZ * fX * cY )
   local i42 = -( rX * fY * cZ + rY * fZ * cX + rZ * fX * cY - rZ * fY * cX - rY * fX * cZ - rX * fZ * cY )
   local i43 = -( rZ * uY * cX + rY * uX * cZ + rX * uZ * cY - rX * uY * cZ - rY * uZ * cX - rZ * uX * cY )

   local uiW, uiH = GuiRoot:GetDimensions()

   local gotOne
   for index = 1, MAX_GROUP_SIZE_THRESHOLD do
		   local unitTag = GetGroupUnitTagByIndex(index)
       if (not doNotDisplay) and IsUnitDead(unitTag) and (not IsUnitBeingResurrected(unitTag)) and (not DoesUnitHaveResurrectPending(unitTag)) and (not AreUnitsEqual(unitTag, "player")) then 
        
         local resurrectControl = GetControl("resurrectControl"..index)
            if not resurrectControl then
               -- One-time setup: texture/dimensions/clamp never change frame-to-frame,
               -- so they're set once here instead of on every 20ms tick, for every dead
               -- group member (this loop runs at ~50Hz while anyone is dead).
               resurrectControl = WINDOW_MANAGER:CreateControl("resurrectControl"..index, TDAddon.resurrectWindow, CT_TEXTURE)
               resurrectControl:SetTexture("/esoui/art/icons/soulgem_006_filled.dds")
               resurrectControl:SetClampedToScreen(true)
               resurrectControl:SetDimensions(50, 50)
            end  
            
        -- The maths here come from the Ody Support Icons addon (thanks guys!)

        -- get resurrectable group member coordinates
        local _, wpx, wpy, wpz =  GetUnitRawWorldPosition(unitTag) 
        wpy = wpy + 100
         
         -- calculate resurrectable group member view position
        local pX = wpx * i11 + wpy * i21 + wpz * i31 + i41
        local pY = wpx * i12 + wpy * i22 + wpz * i32 + i42
        local pZ = wpx * i13 + wpy * i23 + wpz * i33 + i43
        
          -- calculate distance
        local dX, dY, dZ = wpx - cX, wpy - cY, wpz - cZ
        local dist = 1 + zo_sqrt( dX * dX + dY * dY + dZ * dZ )
        
        -- calculate resurrectable group member screen position
        local w, h = GetWorldDimensionsOfViewFrustumAtDepth(pZ)
        local x, y = pX * uiW / w, -pY * uiH / h
       
       
         if dist < 8000 and pZ > 0  then -- Twice the group support range & in front		
             gotOne = true
             resurrectControl:SetHidden(false)
             resurrectControl:ClearAnchors()
             resurrectControl:SetAnchor(CENTER, GuiRoot, CENTER, x, y) 
             TDAddon.RotateControl(resurrectControl,true)             
         else
              -- not in range, we hide
              if resurrectControl then
                 resurrectControl:SetHidden(true)
                 resurrectControl = nil
              end
         end
 
       else
            local resurrectControl = GetControl("resurrectControl"..index)
            if resurrectControl then
              resurrectControl:SetHidden(true)
              resurrectControl = nil
            end
 
       end
   end
   
   -- Only clear the guard when the chain actually stops (nobody left to display).
   -- Clearing it unconditionally here let CheckEverySecond spawn a brand new,
   -- independent 50Hz self-perpetuating chain every second someone stayed dead,
   -- stacking indefinitely on top of already-running chains (matches the correct
   -- pattern already used in SigilCircleLoop below).
   if gotOne then
      zo_callLater(function() TDAddon.Resurrect() end, 20)
   else
      TDAddon.ResurrectLoop = false
   end
end

function TDAddon.SigilCircle()

     local doNotDisplay
	 if (not TDAddon.isInGuild) or (not IsPlayerInAvAWorld()) or (not IsUnitGrouped("player")) or TDAddon.vars.HideSigilCircle then
            doNotDisplay = true
	 elseif TDAddon.canDisplaySigilCircle and TDAddon.sigilCircle:IsHidden() then
		  TDAddon.sigilCircle:SetHidden(false) 		 
	 end

	local GLUT = GetGroupLeaderUnitTag() 
	if DoesUnitExist(GLUT) and (not IsUnitGroupLeader("player")) and not IsGroupMemberInRemoteRegion(GLUT) and not doNotDisplay then
	   TDAddon.SigilCircleLoop = true
	   
	   -- The maths here come from the Ody Support Icons addon (thanks guys!)
	   
		-- prepare render space
		Set3DRenderSpaceToCurrentCamera(TDAddon.sigilCircle:GetName())

		-- retrieve camera world position and orientation vectors
		local cX, cY, cZ = GuiRender3DPositionToWorldPosition(TDAddon.sigilCircle:Get3DRenderSpaceOrigin())
		local fX, fY, fZ = TDAddon.sigilCircle:Get3DRenderSpaceForward()
		local rX, rY, rZ = TDAddon.sigilCircle:Get3DRenderSpaceRight()
		local uX, uY, uZ = TDAddon.sigilCircle:Get3DRenderSpaceUp()

		-- calculate inverse camera matrix
		local i11 = -( uY * fZ - uZ * fY )
		local i12 = -( rZ * fY - rY * fZ )
		local i13 = -( rY * uZ - rZ * uY )
		local i21 = -( uZ * fX - uX * fZ )
		local i22 = -( rX * fZ - rZ * fX )
		local i23 = -( rZ * uX - rX * uZ )
		local i31 = -( uX * fY - uY * fX )
		local i32 = -( rY * fX - rX * fY )
		local i33 = -( rX * uY - rY * uX )
		local i41 = -( uZ * fY * cX + uY * fX * cZ + uX * fZ * cY - uX * fY * cZ - uY * fZ * cX - uZ * fX * cY )
		local i42 = -( rX * fY * cZ + rY * fZ * cX + rZ * fX * cY - rZ * fY * cX - rY * fX * cZ - rX * fZ * cY )
		local i43 = -( rZ * uY * cX + rY * uX * cZ + rX * uZ * cY - rX * uY * cZ - rY * uZ * cX - rZ * uX * cY ) 
	   
		-- screen dimensions
		local uiW, uiH = GuiRoot:GetDimensions()

        -- get group leader coordinates
	    local _, wpx, wpy, wpz =  GetUnitRawWorldPosition(GLUT) 
		wpy = wpy + 100
	   
	   -- calculate group leader view position
		local pX = wpx * i11 + wpy * i21 + wpz * i31 + i41
		local pY = wpx * i12 + wpy * i22 + wpz * i32 + i42
		local pZ = wpx * i13 + wpy * i23 + wpz * i33 + i43
		
	    -- calculate distance
		local dX, dY, dZ = wpx - cX, wpy - cY, wpz - cZ
		local dist = 1 + zo_sqrt( dX * dX + dY * dY + dZ * dZ )
		
		-- calculate group leader screen position
		local w, h = GetWorldDimensionsOfViewFrustumAtDepth(pZ)
		local x, y = pX * uiW / w, -pY * uiH / h

		
		-- if group leader is in front
        if pZ > 0 then
		   local sigilCircleControl = TDAddon.sigilCircleControl
		   if not sigilCircleControl then
				-- One-time setup: texture/dimensions/clamp/color never change frame-to-frame,
				-- so they are set once here instead of on every 20ms tick (this loop runs at
				-- ~50Hz during Cyrodiil fights, so avoiding redundant SetTexture/SetColor/
				-- SetDimensions calls on every tick meaningfully cuts UI-toolkit overhead).
				sigilCircleControl = WINDOW_MANAGER:CreateControl("sigilCircleControl", TDAddon.sigilCircle, CT_TEXTURE)
				TDAddon.sigilCircleControl = sigilCircleControl
				sigilCircleControl:SetTexture("TDAddon/Textures/circle.dds")
				sigilCircleControl:SetClampedToScreen(true)
				sigilCircleControl:SetDimensions(300, 300)
				sigilCircleControl:SetColor(TDAddon.vars.MainCircle.r, TDAddon.vars.MainCircle.g, TDAddon.vars.MainCircle.b, TDAddon.vars.MainCircle.a)
				if GetUnitDisplayName("player") == "@Yökarhu" then
					sigilCircleControl:SetClampedToScreen(false)
				end
		   end
		   sigilCircleControl:SetHidden(false)
		   sigilCircleControl:ClearAnchors()
		   sigilCircleControl:SetAnchor(CENTER, TDAddon.sigilCircle, CENTER, x, y) 
		   TDAddon.RotateControl(sigilCircleControl,false)
		   
		   if dist < 8000 then -- Twice the group support range
			   local sigilCircleTwoControl = TDAddon.sigilCircleTwoControl
			   if not sigilCircleTwoControl then
					-- One-time setup (see sigilCircleControl above for rationale).
					sigilCircleTwoControl = WINDOW_MANAGER:CreateControl("sigilCircleTwoControl", TDAddon.sigilCircle, CT_TEXTURE)
					TDAddon.sigilCircleTwoControl = sigilCircleTwoControl
					sigilCircleTwoControl:SetTexture("TDAddon/Textures/circle.dds")
					sigilCircleTwoControl:SetClampedToScreen(true)
					sigilCircleTwoControl:SetDimensions(400, 400)
					sigilCircleTwoControl:SetColor(TDAddon.vars.TGRCircle.r, TDAddon.vars.TGRCircle.g, TDAddon.vars.TGRCircle.b, TDAddon.vars.TGRCircle.a)
					if GetUnitDisplayName("player") == "@Yökarhu" then
						sigilCircleTwoControl:SetClampedToScreen(false)
					end
			   end
			   sigilCircleTwoControl:SetHidden(false)
			   sigilCircleTwoControl:ClearAnchors()
			   sigilCircleTwoControl:SetAnchor(CENTER, TDAddon.sigilCircle, CENTER, x, y) 
			   TDAddon.RotateControl(sigilCircleTwoControl,false)
		   else
				local sigilCircleTwoControl = TDAddon.sigilCircleTwoControl
				if sigilCircleTwoControl then
					sigilCircleTwoControl:SetHidden(true)
				end	
		   end
		   
		  if IsUnitInGroupSupportRange(GLUT) then  -- group support range = 4000
			   local rangeSigilCircleControl = TDAddon.rangeSigilCircleControl
			   if not rangeSigilCircleControl then
					-- One-time setup (see sigilCircleControl above for rationale).
					rangeSigilCircleControl = WINDOW_MANAGER:CreateControl("rangeSigilCircleControl", TDAddon.sigilCircle, CT_TEXTURE)
					TDAddon.rangeSigilCircleControl = rangeSigilCircleControl
					rangeSigilCircleControl:SetTexture("TDAddon/Textures/sigil_runecircle_01.dds")
					rangeSigilCircleControl:SetClampedToScreen(true)
					rangeSigilCircleControl:SetDimensions(360, 360) 
					rangeSigilCircleControl:SetColor(TDAddon.vars.GRCircle.r, TDAddon.vars.GRCircle.g, TDAddon.vars.GRCircle.b, TDAddon.vars.GRCircle.a)
					if GetUnitDisplayName("player") == "@Yökarhu" then
						rangeSigilCircleControl:SetClampedToScreen(false)
					end
			   end
			   rangeSigilCircleControl:SetHidden(false)
			   rangeSigilCircleControl:ClearAnchors()
			   rangeSigilCircleControl:SetAnchor(CENTER, TDAddon.sigilCircle, CENTER, x, y) 
			   TDAddon.RotateControl(rangeSigilCircleControl,true)
		  else 
		       local rangeSigilCircleControl = TDAddon.rangeSigilCircleControl
			   if rangeSigilCircleControl then
					rangeSigilCircleControl:SetHidden(true)
			   end
		  end
		   local turnBackControl = TDAddon.turnBackControl
		   if turnBackControl then
				turnBackControl:SetHidden(true)
		   end
	   else -- group leader is behind
	      if dist > 8000 then
				local sigilCircleTwoControl = TDAddon.sigilCircleTwoControl
				if sigilCircleTwoControl then
					sigilCircleTwoControl:SetHidden(true)
				end	
          end	
		  
	      if not IsUnitInGroupSupportRange(GLUT) then
		       local rangeSigilCircleControl = TDAddon.rangeSigilCircleControl
			   if rangeSigilCircleControl then
					rangeSigilCircleControl:SetHidden(true)
			   end
	      end
		  if not IsUnitDead(GLUT) then
			   local turnBackControl = TDAddon.turnBackControl
			   if not turnBackControl then
					-- One-time setup (see sigilCircleControl above for rationale). This
					-- control's anchor is also fixed at (0,0), so it never needs re-anchoring.
					turnBackControl = WINDOW_MANAGER:CreateControl("turnBackControl", TDAddon.sigilCircle, CT_TEXTURE)
					TDAddon.turnBackControl = turnBackControl
					turnBackControl:SetTexture("TDAddon/Textures/turnback.dds")
					turnBackControl:SetClampedToScreen(true)
					turnBackControl:SetAlpha(0.5)
					turnBackControl:ClearAnchors()
					turnBackControl:SetAnchor(CENTER, TDAddon.sigilCircle, CENTER, 0, 0) 
					turnBackControl:SetDimensions(250, 250)
			   end
			   turnBackControl:SetHidden(false)
			   TDAddon.RotateControl(turnBackControl,true)
		 else
			   local turnBackControl = TDAddon.turnBackControl
			   if turnBackControl then
					turnBackControl:SetHidden(true)
			   end
		 end
	   end
	   
	   zo_callLater(function() TDAddon.SigilCircle() end, 20)
	else
        local sigilCircleControl = TDAddon.sigilCircleControl
		if sigilCircleControl then
			sigilCircleControl:SetHidden(true)
			sigilCircleControl = nil
		end	
        local sigilCircleTwoControl = TDAddon.sigilCircleTwoControl
		if sigilCircleTwoControl then
			sigilCircleTwoControl:SetHidden(true)
			sigilCircleTwoControl = nil
		end	
	    local rangeSigilCircleControl = TDAddon.rangeSigilCircleControl
	    if rangeSigilCircleControl then
			 rangeSigilCircleControl:SetHidden(true)
			 rangeSigilCircleControl = nil
	    end
	    local turnBackControl = TDAddon.turnBackControl
	    if turnBackControl then
			turnBackControl:SetHidden(true)
			turnBackControl = nil
	    end
		
		TDAddon.sigilCircle:SetHidden(true)
		TDAddon.SigilCircleLoop = false
	end
end

-- get skill used info
function TDAddon.BuffCheck(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
	
	-- successful
	if result ~= 2240 then 
	    return
	end

    local oneTriggered = false

    -- Got rapids?
	if abilityId == 61736 then
	    local majorExpeditionIndex
		for i = 1, GetNumBuffs("player") do   	
			 local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, deprecatedBuffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", i)
			 if abilityId == 61736 then
				majorExpeditionIndex = i
			 end
			 if majorExpeditionIndex and majorExpeditionIndex == i-1 and abilityId == 61735 then
			    local duration = timeEnding - timeStarted
                TDAddon.rapidsEndTime = GetTimeStamp() + duration
                oneTriggered = true	
			 end
		end
	end

	if oneTriggered then
	   TDAddon.GroupUltimateStateLoop()
    end	
end

function TDAddon.PassengerHop()
    local _, isRidingGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(GetUnitNameHighlightedByReticle())
    if IsUnitGrouped("reticleover") and isRidingGroupMount and hasFreePassengerSlot then
       UseMountAsPassenger(GetUnitNameHighlightedByReticle())
    end
end

function TDAddon.HandleChatter(questOffer, questComplete)
    if not IsInCyrodiil() then return end
	
	local titleUIToUse
	if IsConsoleUI() then
		titleUIToUse = ZO_InteractWindow_GamepadTitle
	else
		titleUIToUse = ZO_InteractWindowTargetAreaTitle
	end
	
	local optionCount = GetChatterOptionCount()
    if optionCount == 0 then return end

	local optionString, optionType = GetChatterOption(1)
    if zo_plainstrfind(titleUIToUse:GetText(),"Dortene") then
	    if questComplete then  
	        CompleteQuest()
		elseif questOffer then
		    AcceptOfferedQuest()
			zo_callLater(function() TDAddon.CheckScrollQuest() end, 500) 
		elseif optionType == CHATTER_START_NEW_QUEST_BESTOWAL then
			SelectChatterOption(1)
		elseif optionType == CHATTER_START_COMPLETE_QUEST then
			SelectChatterOption(1)
		end
	elseif zo_plainstrfind(titleUIToUse:GetText(),"Bounty Mission Board") and TDAddon.vars.KillTwentyPlayersOnly then
	    if questComplete then  
			-- for i=1, MAX_JOURNAL_QUESTS do
				-- if IsValidQuestIndex(i) then
					-- local questName = GetJournalQuestInfo(i)
						-- if questName == GetQuestName(2759) then
							   TDAddon.vars.nextBMBreset = GetTimeStamp() + GetTimeUntilNextDailyLoginRewardClaimS()
						-- end
				-- end
			-- end
		
	        CompleteQuest()
			
		elseif questOffer then
		    AcceptOfferedQuest()
			zo_callLater(function() TDAddon.CheckMissionBoardQuest() end, 500) 
		elseif optionType == CHATTER_START_NEW_QUEST_BESTOWAL then
			SelectChatterOption(1)
		elseif optionType == CHATTER_START_COMPLETE_QUEST then
			SelectChatterOption(1)
		end
	elseif zo_plainstrfind(titleUIToUse:GetText(),"Scouting Mission Board") then
	    if questComplete then  
	        CompleteQuest()
		elseif questOffer then
		    AcceptOfferedQuest()
		elseif optionType == CHATTER_START_NEW_QUEST_BESTOWAL then
			SelectChatterOption(1)
		elseif optionType == CHATTER_START_COMPLETE_QUEST then
			SelectChatterOption(1)
		end	
	end
end


-- auto accept jump to campaign
function TDAddon.AutoacceptQueue(code, campaignId, isGroup, CampaignQueueRequestStateType)
    if not TDAddon.isInGuild then
		   return
	end
	if CampaignQueueRequestStateType ==  CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then
	    ConfirmCampaignEntry(campaignId, isGroup, true) 
	end 
end





-- save ultimate window position after a drag and drop 
function TDAddon.saveUltiWindowPosition( window )
    local _, sP, _, aP, x, y = window:GetAnchor()
    TDAddon.vars.UltiWindowAnchPoint = aP
    TDAddon.vars.UltiWindowSelfPoint = sP
    TDAddon.vars.UltiWindowXoff = x
    TDAddon.vars.UltiWindowYoff = y
end

function TDAddon.ShareQuests()
 
    local shareableCyroQuests = {}
    
    if IsInCyrodiil() then
      shareableCyroQuests[GetQuestName(3226)] = true -- roe	
      shareableCyroQuests[GetQuestName(3246)] = true -- roe lumber
      shareableCyroQuests[GetQuestName(6215)] = true -- 9 res
      shareableCyroQuests[GetQuestName(6214)] = true -- 3 keeps
      shareableCyroQuests[GetQuestName(2759)] = true -- kill 20 enemies
    elseif IsInImperialCity() then
      shareableCyroQuests[GetQuestName(5500)] = true -- Dousing the Fires of Industry
      shareableCyroQuests[GetQuestName(5498)] = true -- Historical Accuracy 
      shareableCyroQuests[GetQuestName(5492)] = true -- The Lifeblood of an Empire
      shareableCyroQuests[GetQuestName(5495)] = true -- Priceless Treasures
      shareableCyroQuests[GetQuestName(5491)] = true -- Speaking For The Dead
      shareableCyroQuests[GetQuestName(5501)] = true -- Watch Your Step
      shareableCyroQuests[GetQuestName(2759)] = true -- kill 20 enemies
    end    


	for i=1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then
			local questName = GetJournalQuestInfo(i)
			if shareableCyroQuests[questName] then
			   ShareQuest(i)
			   --d("|c5282BD[TDAddon]|r sharing "..questName)
			end
		end
	end
end

function TDAddon.CheckScrollQuest()
	
	local numScrolls = 0
    -- Scrolls we have in keeps
	local numObjectives = GetNumObjectives()
	for i = 1, numObjectives do
	    local okeepId, objectiveId, obgContext = GetAvAObjectiveKeysByIndex(i)
	    local thatKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(okeepId, objectiveId, obgContext)

		if thatKeep ~= 0 then -- by the way we count number of scrolls for each alliance 
           local keepAlliance = GetKeepAlliance(thatKeep, BGQUERY_LOCAL)  	
           if keepAlliance == ALLIANCE_DAGGERFALL_COVENANT then
		      numScrolls = numScrolls + 1 
		   end
		end
	end
	
	-- we get our own scrolls first
	if numScrolls < 2 then
	   return 
	end

    local scrollQuests = {}
    scrollQuests[GetQuestName(2635)] =  {wanted = GetQuestName(2635) == TDAddon.vars.WantedScrollQuest}  -- Alma Ruma	
	scrollQuests[GetQuestName(2638)] =  {wanted = GetQuestName(2638) == TDAddon.vars.WantedScrollQuest}  -- Mnem
	scrollQuests[GetQuestName(2640)] =  {wanted = GetQuestName(2640) == TDAddon.vars.WantedScrollQuest}  -- Chim
	scrollQuests[GetQuestName(2634)] =  {wanted = GetQuestName(2634) == TDAddon.vars.WantedScrollQuest}  -- Ni Mhok
	scrollQuests[GetQuestName(2610)] =  {wanted = GetQuestName(2610) == TDAddon.vars.WantedScrollQuest}  -- Altadoon
	scrollQuests[GetQuestName(2639)] =  {wanted = GetQuestName(2639) == TDAddon.vars.WantedScrollQuest}  -- Ghartok	

	for i=1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then
			local questName = GetJournalQuestInfo(i)
			if scrollQuests[questName] then
			   if TDAddon.vars.WantedScrollQuest ~= "All" and not scrollQuests[questName].wanted then
			       AbandonQuest(i)
				   d("|c5282BD[TDAddon]|r abandonned "..questName.. " because you want "..TDAddon.vars.WantedScrollQuest)
			   else
			       d("|c5282BD[TDAddon]|r "..questName.." started!")
			   end
			end
		end
	end
end

function TDAddon.CheckMissionBoardQuest()

    TDAddon.vars.nextBMBreset = TDAddon.vars.nextBMBreset or 0

     local missionBoardQuests = {}
     missionBoardQuests[GetQuestName(5228)] =  true -- DK
     missionBoardQuests[GetQuestName(6011)] =  true -- Ward
     missionBoardQuests[GetQuestName(5234)] =  true -- sorc
     missionBoardQuests[GetQuestName(5231)] =  true -- nb
     missionBoardQuests[GetQuestName(6390)] =  true -- necro
     missionBoardQuests[GetQuestName(5221)] =  true -- templars
	 missionBoardQuests[GetQuestName(7067)] =  true -- arcanists
     missionBoardQuests[GetQuestName(2759)] =  true -- enemy players
	 
	 local newDay = false
	 if TDAddon.vars.nextBMBreset < GetTimeStamp() then
	     newDay = true
	 end
	 
     
	for i=1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then
			local questName = GetJournalQuestInfo(i)
			if TDAddon.vars.KillTwentyPlayersOnly and missionBoardQuests[questName] then
				if questName ~= GetQuestName(2759) and newDay then
					   AbandonQuest(i)
					   d("|c5282BD[TDAddon]|r abandonned "..questName.." because you want "..GetQuestName(2759))
				else
				       d("|c5282BD[TDAddon]|r "..questName.." started!")
				end
			end
		end
	end
end



function TDAddon.GoToBase()
     local itemId = 0
     local bag = BAG_BACKPACK
     
     if IsCurrentCampaignVengeanceRuleset() then -- in vengeance
         itemId = 220376
         bag = BAG_VENGEANCE
     elseif IsInImperialCity() then -- in Imperial City
         itemId = 68347  
     elseif IsInCampaign() then -- in Cyrodiil
         itemId = 141731
     else
         return
     end

     for i = 1, GetBagSize(bag) do
        local thisItemId = GetItemId(bag, i)
        if thisItemId == itemId then
         
        	local usable, usableOnlyFromActionSlot = IsItemUsable(bag, i)
	        local canInteract = CanInteractWithItem(bag, i)
	        local canUseItem = usable and not usableOnlyFromActionSlot and canInteract
        
           if canUseItem then
			         local success = CallSecureProtected("UseItem", bag, i)
		       end
           break
        end
     end
end

function TDAddon.GetClosestForwardCamp()
  local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
  local closestDistance = 9999999
  local playerX, playerY = GetMapPlayerPosition("player")
  local index
  for i = 1, GetNumForwardCamps(bgContext) do 
      local _, normalizedX, normalizedY, _, useable = GetForwardCampPinInfo(bgContext, i)
      --Forward camp radius = 0.026000000536442
      if useable then
         local distance = zo_sqrt((playerX - normalizedX) ^ 2 + (playerY - normalizedY) ^ 2)
         if distance < closestDistance then
            closestDistance = distance
            index = i
         end
      end
  end

  if index then
      TDAddon.closestForwardCampIndex = index
  else
      TDAddon.closestForwardCampIndex = nil
  end
end  

function TDAddon.GetClosestKeep()
  local bgContext = ZO_WorldMap_GetBattlegroundQueryType()
  local closestDistance = 9999999
  local playerX, playerY = GetMapPlayerPosition("player")
  local id
  local radius = 0.06500000134 -- 2.5 times the forward camp radius for the keep to be interesting to res in
  for i = 1, GetNumKeeps() do 
      local keepId, accessible, normalizedX, normalizedY = GetKeepTravelNetworkNodeInfo(i, bgContext)
      
      if CanRespawnAtKeep(keepId) then
         local distance = zo_sqrt((playerX - normalizedX) ^ 2 + (playerY - normalizedY) ^ 2)
         if distance <= radius and distance < closestDistance then
            closestDistance = distance
            id = keepId
         end
      end
  end

  if id then
      TDAddon.closestKeepId = id
  else
      TDAddon.closestKeepId = nil
  end
end

function TDAddon.RespawnToClosestCamp()
      if TDAddon.closestForwardCampIndex then
          RespawnAtForwardCamp(TDAddon.closestForwardCampIndex)
      else
          ZO_WorldMap_ShowAvARespawns()
          ZO_WorldMap_ShowWorldMap()
      end
end

function TDAddon.RespawnToClosestKeep()
      if TDAddon.closestKeepId then
           RespawnAtKeep(TDAddon.closestKeepId)
      else
          ZO_WorldMap_ShowAvARespawns()
          ZO_WorldMap_ShowWorldMap()
      end
end

function TDAddon.AllInOne()
    if IsUnitDead("player") then
        if TDAddon.closestForwardCampIndex then
             RespawnAtForwardCamp(TDAddon.closestForwardCampIndex)
        elseif TDAddon.closestKeepId then
             RespawnAtKeep(TDAddon.closestKeepId)
        else
            ZO_WorldMap_ShowAvARespawns()
            ZO_WorldMap_ShowWorldMap()
        end
    else
        TDAddon.GoToBase()
    end
end

-- every second checks
function TDAddon.CheckEverySecond()
  if not TDAddon.isInGuild then
		   return
	end
    local FrameTimeMilliseconds = GetFrameTimeMilliseconds()
    local timeStamp = GetTimeStamp()
    TDAddon.lastUltimateLoop = TDAddon.lastUltimateLoop or FrameTimeMilliseconds
	
  local isInCampaign = IsInCampaign()
	local grouped = IsUnitGrouped("player")
	local sendDataWhileInvisible = LibGroupBroadcast_Data and LibGroupBroadcast_Data[GetDisplayName()] and LibGroupBroadcast_Data[GetDisplayName()]["sendDataWhileInvisible"]
	local notSendingUltimates = GetPlayerStatus() == PLAYER_STATUS_OFFLINE and not sendDataWhileInvisible
	
	-- forward camp respawn timer & campaign queue check
	if (GetNextForwardCampRespawnTime() > FrameTimeMilliseconds and (not TDAddon.ForwardCamplooping)) or (GetNumCampaignQueueEntries() > 0 and (not TDAddon.CampaignQueuelooping))
	or ((not TDAddon.OfflineStatuslooping) and grouped and IsPlayerInAvAWorld() and notSendingUltimates) then 
		TDAddon.ForwardCamploop()
	end	
	
	-- rechecks ultimate bar 
    if (not TDAddon.vars.HideUltiWindow) and ((TDAddon.lastUltimateLoop + 2000 > FrameTimeMilliseconds) or TDAddon.rapidsEndTime > timeStamp) then
	   TDAddon.GroupUltimateStateLoop()
	end
	
	-- Sigil Circle
	if (not TDAddon.vars.HideSigilCircle) and (not TDAddon.SigilCircleLoop) and grouped and (not IsUnitGroupLeader("player")) then         
	   TDAddon.SigilCircle()
	end
  
  -- resurrect
  if (not TDAddon.vars.HideResurrect) and grouped and (not TDAddon.ResurrectLoop) then
     TDAddon.Resurrect()
  end
  
  -- respawn
  if isInCampaign and IsUnitDead("player") then
     TDAddon.GetClosestForwardCamp()
     TDAddon.GetClosestKeep()
     
     local _, _, _, _, _, isAVADeath = GetDeathInfo()
     
     if TDAddon.closestKeepId and isAVADeath then
         if TDAddon.keepButton then
             TDAddon.keepButton:SetHidden(false)
             TDAddon.keepButton:SetText(GetString(SI_BINDING_NAME_TDADDON_RESPAWN_KEEP).." ("..GetKeepName(TDAddon.closestKeepId)..")")
             TDAddon.keepButton:ClearAnchors()
             TDAddon.keepButton:SetAnchor(BOTTOM, GetControl("ZO_DeathTwoButton"), TOP, 0, 0)
         else
             TDAddon.keepButton = CreateControlFromVirtual("keepButton", GetControl("ZO_Death"), "ZO_KeybindStripButtonTemplate")
             TDAddon.keepButton:ClearAnchors()
             TDAddon.keepButton:SetAnchor(BOTTOM, GetControl("ZO_DeathTwoButton"), TOP, 0, 0)
             TDAddon.keepButton:SetKeybind("TDADDON_RESPAWN_KEEP")
             TDAddon.keepButton:SetText(GetString(SI_BINDING_NAME_TDADDON_RESPAWN_KEEP).." ("..GetKeepName(TDAddon.closestKeepId)..")")
             TDAddon.keepButton:SetHidden(false)
         end
     else
         if TDAddon.keepButton then
            TDAddon.keepButton:SetHidden(true)
            TDAddon.keepButton:SetText(GetString(SI_BINDING_NAME_TDADDON_RESPAWN_KEEP))
         end
     end
     
     if TDAddon.closestForwardCampIndex and isAVADeath then 
         local clampTo = GetControl("ZO_DeathTwoButton")
         local bottom = BOTTOM
         local top = TOP
         if TDAddon.keepButton then
             clampTo = TDAddon.keepButton
             bottom = BOTTOMLEFT
             top = TOPLEFT
         end
         
         if TDAddon.campButton then
              TDAddon.campButton:SetHidden(false)
              TDAddon.campButton:ClearAnchors()
              TDAddon.campButton:SetAnchor(bottom, clampTo, top, 0, 0)
         else
              TDAddon.campButton = CreateControlFromVirtual("campButton", GetControl("ZO_Death"), "ZO_KeybindStripButtonTemplate")
              TDAddon.campButton:ClearAnchors()
              TDAddon.campButton:SetAnchor(bottom, clampTo, top, 0, 0)
              TDAddon.campButton:SetKeybind("TDADDON_RESPAWN_CAMP")
              TDAddon.campButton:SetText(GetString(SI_BINDING_NAME_TDADDON_RESPAWN_CAMP))
              TDAddon.campButton:SetHidden(false)
         end
     else
         if TDAddon.campButton then
            TDAddon.campButton:SetHidden(true)
         end
     end
  
  end
	
  local logEnabled = IsEncounterLogEnabled()
	-- autoshare interesting Cyro quests to new group members + auto enable encounterlog
	if grouped then
	    TDAddon.lastGroupSize = TDAddon.lastGroupSize or 1
      local groupSize = GetGroupSize() or 1
      if groupSize > TDAddon.lastGroupSize and isInCampaign then 
           TDAddon.ShareQuests()
      end 
      if TDAddon.vars.CampaignGroupOnlyEncounterLog and isInCampaign and not logEnabled then
         SetEncounterLogEnabled(true)
         d("|c5282BD[TDAddon]|r Encounter Log auto enabled")
      end
      TDAddon.lastGroupSize = groupSize
	else
      TDAddon.lastGroupSize = 1
      if TDAddon.vars.CampaignGroupOnlyEncounterLog and logEnabled then 
         SetEncounterLogEnabled(false)
         d("|c5282BD[TDAddon]|r Encounter Log auto disabled")
      end
  end
end


local function OnAddonLoaded(event, addonName)
	if addonName == TDAddon.name then
       TDAddon.vars = ZO_SavedVars:NewAccountWide("TDAVars", 2, nil, TDAddon.defaults)
       TDAddon.CreateConfiguration()
	   
		TDAddon.ultiUi = GetControl("TDAddon_ultiUi")
		TDAddon.ultiUi:SetDimensions(80, 480)
		TDAddon.ultiUi:SetMouseEnabled(true)
		--if TDAddon.vars.LockUltiWindow then
		    TDAddon.ultiUi:SetMovable(false)
		--else
		  --  TDAddon.ultiUi:SetMovable(true)
		--end
		TDAddon.ultiUi:SetClampedToScreen(true)
		--TDAddon.ultiUi:SetHandler("OnMoveStop", TDAddon.saveUltiWindowPosition) 
    TDAddon.ultiUi:ClearAnchors()
    --TDAddon.ultiUi:SetAnchor(TDAddon.vars.UltiWindowSelfPoint or TOPLEFT, GuiRoot, TDAddon.vars.UltiWindowAnchPoint or CENTER, TDAddon.vars.UltiWindowXoff, TDAddon.vars.UltiWindowYoff)
		
		-- forward camp container
		TDAddon.fwcUi = GetControl("TDAddon_fwcUi")
		TDAddon.fwcUi:SetClampedToScreen(true)
    TDAddon.fwcUi:SetDimensions(80, 80)
		TDAddon.fwcUi:ClearAnchors()
		--TDAddon.fwcUi:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, 0, 40)
    
    HUD_MANAGER:RegisterKeyboardElement(TDAddon.ultiUi, "TDAddon ultimate bar", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) -- for Keyboard UI 
    HUD_MANAGER:RegisterGamepadElement(TDAddon.ultiUi, "TDAddon ultimate bar", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) --for Gamepad UI
    
    HUD_MANAGER:RegisterKeyboardElement(TDAddon.fwcUi, "TDAddon Forward camp & Queue", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) -- for Keyboard UI 
    HUD_MANAGER:RegisterGamepadElement(TDAddon.fwcUi, "TDAddon Forward camp & Queue", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) --for Gamepad UI
		
		-- sigil circle
		TDAddon.sigilCircle = WINDOW_MANAGER:CreateTopLevelWindow("TDAddon_sigilCircle")
		TDAddon.sigilCircle:SetClampedToScreen(true)	
	  TDAddon.sigilCircle:SetAnchorFill(GuiRoot)
    TDAddon.sigilCircle:Create3DRenderSpace()
        
 		-- resurrect window
		TDAddon.resurrectWindow = WINDOW_MANAGER:CreateTopLevelWindow("TDAddon_resurrectWindow")
		TDAddon.resurrectWindow:SetClampedToScreen(true)	
	  TDAddon.resurrectWindow:SetAnchorFill(GuiRoot)
    TDAddon.resurrectWindow:Create3DRenderSpace()
		
		if GetUnitDisplayName("player") == "@Yökarhu" then
		    TDAddon.sigilCircle:SetClampedToScreen(false)
		end
		
	   EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, TDAddon.AutoacceptQueue)
	   --EVENT_QUEUE_FOR_CAMPAIGN_RESPONSE (*[QueueForCampaignResponseType|#QueueForCampaignResponseType]* _response_)
	   -- Filter combat events natively (engine-side) so BuffCheck only fires for the
	   -- one ability/result we actually care about, instead of every combat event
	   -- in range (critical in large Cyrodiil fights where this event can fire
	   -- thousands of times per second unfiltered).
	   EVENT_MANAGER:AddFilterForEvent(TDAddon.name, EVENT_COMBAT_EVENT,
	       REGISTER_FILTER_COMBAT_RESULT, 2240, -- matches the result check already inside BuffCheck
	       REGISTER_FILTER_ABILITY_ID, 61736,
	       REGISTER_FILTER_UNIT_TAG, "player")
	   EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_COMBAT_EVENT, TDAddon.BuffCheck)
	   
	   -- ultimate share
	   TDAddon.lgcs = LibGroupCombatStats.RegisterAddon(TDAddon.name,{"ULT"})
		 if not TDAddon.lgcs then
			 d("|c5282BD[TDAddon]|r Failed to register addon with LibGroupCombatStats.")
			 return
		 end
		
	   TDAddon.lgcs:RegisterForEvent(LibGroupCombatStats.EVENT_GROUP_ULT_UPDATE, TDAddon.GroupUltimateStateLoop)
	   EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_GROUP_MEMBER_JOINED, TDAddon.GroupUltimateStateLoop)
	   EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_CHATTER_BEGIN, function() TDAddon.HandleChatter(false, false) end)
       EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_QUEST_OFFERED, function() TDAddon.HandleChatter(true, false) end)
       EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_QUEST_COMPLETE_DIALOG, function() TDAddon.HandleChatter(false, true) end)	   
	   
	   SOUNDS["ABILITY_SYNERGY_READY"] = TDAddon.vars.SynergySound 
	   
	   local hudScene = SCENE_MANAGER:GetScene("hud")
       hudScene:RegisterCallback("StateChange", function(oldState, newState)
		   if newState == SCENE_HIDDEN and SCENE_MANAGER:GetNextScene():GetName() ~= "hudui" then 
				 TDAddon.ultiUi:SetHidden(true)
				 TDAddon.fwcUi:SetHidden(true)
				 TDAddon.sigilCircle:SetHidden(true)
				 TDAddon.canDisplayUltimateUi = false
				 TDAddon.canDisplaySigilCircle = false
         TDAddon.canDisplayResurrect = false 
		   elseif IsPlayerInAvAWorld() and IsUnitGrouped("player") then
				 if (not TDAddon.vars.HideUltiWindow) then
					 TDAddon.ultiUi:SetHidden(false)
					 TDAddon.fwcUi:SetHidden(false)
					 TDAddon.canDisplayUltimateUi = true
				 end	 
				 TDAddon.canDisplayResurrect = true
				 if (not TDAddon.vars.HideSigilCircle) then
				    TDAddon.canDisplaySigilCircle = true
				    TDAddon.sigilCircle:SetHidden(false)
				 end
		   else
		         TDAddon.canDisplayUltimateUi = true
				     TDAddon.canDisplaySigilCircle = true
             TDAddon.canDisplayResurrect = true
				 if IsPlayerInAvAWorld() or TDAddon.CampaignQueuelooping then
				     TDAddon.fwcUi:SetHidden(false) 
				 end
		   end
       end)
	   
	   EVENT_MANAGER:RegisterForUpdate("CheckEverySecond", 1000, TDAddon.CheckEverySecond)
	   TDAddon.isInGuild = IsPlayerInGuild(2897)
	   TDAddon.rapidsEndTime = 0
	   
	   
	   SLASH_COMMANDS["/scall"] = function()
			TDAddon.vars.WantedScrollQuest = "All"
			d("|c5282BD[TDAddon]|r set wanted scroll quest to all")
       end
	   
	   SLASH_COMMANDS["/scalma"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2635)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2635))
       end	 

	   SLASH_COMMANDS["/scmnem"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2638)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2638))
       end 
	   
	   SLASH_COMMANDS["/scchim"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2640)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2640))
       end 	   

	   SLASH_COMMANDS["/scni"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2634)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2634))
       end

	   SLASH_COMMANDS["/scalta"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2610)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2610))
       end

	   SLASH_COMMANDS["/scghar"] = function()
			TDAddon.vars.WantedScrollQuest = GetQuestName(2639)
			d("|c5282BD[TDAddon]|r set wanted scroll quest to "..GetQuestName(2639))
       end

	   	---------------------------------------------------------------------------------------------
		-- START OF SYNERGY HACK
		-- (REMOVE PROMPT FOR PURIFY)
		---------------------------------------------------------------------------------------------
		-- function ZO_Synergy:OnSynergyAbilityChanged()
			-- local hasSynergy, synergyName, iconFilename, prompt = GetCurrentSynergyInfo()

			-- if hasSynergy then
			   -- if IsPlayerInAvAWorld() and IsUnitGrouped("player") and synergyName == GetAbilityName(22269) then
				  -- return
			   -- end
			 
				-- if self.lastSynergyName ~= synergyName then
					-- PlaySound(SOUNDS.ABILITY_SYNERGY_READY)

					-- if prompt == "" then
						-- prompt = zo_strformat(SI_USE_SYNERGY, synergyName)
					-- end
					-- self.action:SetText(prompt)
					-- self.lastSynergyName = synergyName
				-- end
				
				-- self.icon:SetTexture(iconFilename)

				-- SHARED_INFORMATION_AREA:SetHidden(self, false)
			-- else
				-- SHARED_INFORMATION_AREA:SetHidden(self, true)
				-- self.lastSynergyName = nil
			-- end
		-- end
		
		---------------------------------------------------------------------------------------------
		-- END OF SYNERGY HACK
		---------------------------------------------------------------------------------------------

		
	   	---------------------------------------------------------------------------------------------
		-- START OF INTERACTION
		-- (500ms cooldown to avoid double Cyrodiil keep door double click/tap)
		---------------------------------------------------------------------------------------------
		
		-- Stops interaction if...
		local WHEEL_MANAGER = INTERACTIVE_WHEEL_MANAGER
		local orgInteract = WHEEL_MANAGER.StartInteraction
		WHEEL_MANAGER.StartInteraction = function(...)
			-- -- 500ms cooldown to avoid double tap/click
			if IsPlayerInAvAWorld() and TDAddon.LastStartInterraction and GetFrameTimeMilliseconds() < TDAddon.LastStartInterraction + 500 then
			   return true
			end
			TDAddon.LastStartInterraction = GetFrameTimeMilliseconds()
			
		    return orgInteract(...)
    end
		
		---------------------------------------------------------------------------------------------
		-- END OF INTERACTION HACK
		---------------------------------------------------------------------------------------------
	end


end	


EVENT_MANAGER:RegisterForEvent(TDAddon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


