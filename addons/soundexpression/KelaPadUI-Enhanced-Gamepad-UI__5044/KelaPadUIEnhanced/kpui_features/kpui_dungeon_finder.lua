-- KelaPadUI dungeon-finder and pledge enhancements.
-- Extracted from KelaPadUI.lua; this is the retained working Undaunted/pledge functionality.

function GetGoalPledges()
	local pledgeQuests = {}

	for i = 1, MAX_JOURNAL_QUESTS do
		local name,_,activeStepText,stepType,activeStepTrackerOverrideText,completed,_,_,_,questType,instanceType=GetJournalQuestInfo(i)

		if name and questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
			local trimmedName = string.match(name, "^Pledge: (.+)$")
			pledgeQuests[trimmedName] = " [|c4DB8FF ACTIVE |r]"
			if activeStepTrackerOverrideText ~= "" then
				pledgeQuests[trimmedName] = " [|c66FF66 " .. activeStepTrackerOverrideText .. " |r]" -- " [|c66FF66 READY TO TURN IN |r]"
			end
		end
	end

	return pledgeQuests
end

-- Today's pledge rotation for the dashboard: an ordered list of
-- { giver, dungeon, status } where status is the player's current pledge state
-- string (nil when the pledge is not in the journal).
function KelaGetPledgeReport(skipJournalScan)
	local DailyPledges={
		[1]={	--Maj
			name = "Maj",
			{en="Fungal Grotto I",		}, --1
			{en="Banished Cells II",	},
			{en="Darkshade Caverns I",	},
			{en="Elden Hollow II",		},
			{en="Wayrest Sewers I",		},
			{en="Spindleclutch II",		},
			{en="Banished Cells I",		},
			{en="Fungal Grotto II",		},
			{en="Spindleclutch I",		},
			{en="Darkshade Caverns II",	},
			{en="Elden Hollow I",		},
			{en="Wayrest Sewers II",	},
			shift=0
		},
		[2]={	--Glirion
			name = "Glirion",
			{en="Selene's Web",		    }, --1
			{en="City of Ash II",		},
			{en="Crypt of Hearts I",	},
			{en="Volenfell",			},
			{en="Blessed Crucible I",	},
			{en="Direfrost Keep I",		},
			{en="Vaults of Madness",	},
			{en="Crypt of Hearts II",	},
			{en="City of Ash I",		},
			{en="Tempest Island",		},
			{en="Blackheart Haven",		},
			{en="Arx Corinium",		    },
			shift=0
		},
		[3]={	--Urgarlag
			name = "Urgarlag",
			{en="Imperial City Prison",	}, --1
			{en="Ruins of Mazzatun",	},
			{en="White-Gold Tower",		},
			{en="Cradle of Shadows",	},
			{en="Bloodroot Forge",		},
			{en="Falkreath Hold",		},
			{en="Fang Lair",			},
			{en="Scalecaller Peak",		},
			{en="Moon Hunter Keep",		},
			{en="March of Sacrifices",	},
			{en="Depths of Malatar",	},
			{en="Frostvault",			},
			{en="Moongrave Fane",		},
			{en="Lair of Maarselok",	},
			{en="Icereach",			    },
			{en="Unhallowed Grave",		},
			{en="Stone Garden",		    },
			{en="Castle Thorn",		    },
			{en="Black Drake Villa",	},
			{en="The Cauldron",		    },
			{en="Red Petal Bastion",	},
			{en="The Dread Cellar",		},
			{en="Coral Aerie",			},
			{en="Shipwright's Regret",  },
			{en="Earthen Root Enclave",	},
			{en="Graven Deep",		    },
			{en="Bal Sunnar",           },
			{en="Scrivener's Hall",		},
			{en="Oathsworn Pit",        },
			{en="Bedlam Veil",		    },
			{en="Exiled Redoubt",       },
			{en="Lep Seclusa",		    },
			{en="Black Gem Foundry",    },
			{en="Naj-Caldeesh",		    },
			shift=0
		},
	}

	-- Set the pledge cycle start day - 204 day rotation with 34 Urgarlag quests
	-- Account for different reset times in EU (3am UTC) and NA (10am UTC)
	local pledgecyclestartday = 1509962399 -- 2017-11-06
	local currentdaystart = GetTimeStamp() + GetTimeUntilNextDailyLoginRewardClaimS() - 86400
	local day = math.floor(GetDiffBetweenTimeStamps(currentdaystart, pledgecyclestartday) / 86400)
	local pledgeQuests = skipJournalScan and {} or GetGoalPledges() -- Get active pledges
	local report = {}

	for npc=1,3 do
		local dp = DailyPledges[npc]
		local pledge = dp[1 + ((day + dp.shift) % #dp)].en
		report[npc] = { giver = dp.name, dungeon = pledge, status = pledgeQuests[pledge] }
	end

	return report, pledgeQuests
end

-- /pledges chat output, unchanged.
local function show_pledges()
	local report, pledgeQuests = KelaGetPledgeReport()
	local todaysPledges = {}

	CHAT_SYSTEM:AddMessage("|cFFD700Today's Daily Pledges|r")
	for _, entry in ipairs(report) do
		todaysPledges[entry.dungeon] = entry.giver
		CHAT_SYSTEM:AddMessage("|cAAAAAA  " .. entry.giver .. ":|r |cFFFFFF" .. entry.dungeon .. "|r" .. (entry.status or ""))
	end

	local printedHeader = false
	for key, value in pairs(pledgeQuests) do
		if not todaysPledges[key] then
			if not printedHeader then
				CHAT_SYSTEM:AddMessage("|c66FF66Active Pledges not from Today|r")
				printedHeader = true
			end
			CHAT_SYSTEM:AddMessage("|cFFFFFF  " .. key .. "|r" .. value)
		end
	end
end


local function Add_Enhanced_DungeonFinder_Info()

	local DUNGEON_ZONES = { -- zone id's of dungeons.
		BC1 =  380, BC2 =  935, EH1 =  126, EH2 =  931, CA1 =  176, CA2 =  681,
		TI  =  131, SW  =   31, SC1 =  144, SC2 =  936, WS1 =  146, WS2 =  933,
		CH1 =  130, CH2 =  932, VF  =   22, BH  =   38, FG1 =  283, FG2 =  934,
		DC1 =   63, DC2 =  930, AC  =  148, DK  =  449, BC  =   64, VM  =   11,
		ICP =  678, WGT =  688, CS  =  848, RM  =  843, BF  =  973, FH  =  974,
		FL  = 1009, SP  = 1010, MHK = 1052, MOS = 1055, DoM = 1081, FV  = 1080,
		LM  = 1123, MF  = 1122, IR  = 1152, UG  = 1153, SG  = 1197, CT  = 1201,
		BDV = 1228, TC  = 1229, RPB = 1267, TDC = 1268, CA  = 1301, SR  = 1302,
		ERE = 1360, GD  = 1361, BS  = 1389, SH =  1390, OP  = 1470, BV  = 1471,
		ER = 1496, LS = 1497, NC = 1551, BGF = 1552
	}
	local DUNGEON_QUESTS = { -- quest id's of dungeons that award skillpoints
		BC1 = 4107,	BC2 = 4597,	EH1 = 4336,	EH2 = 4675,	CA1 = 4778,	CA2 = 5120,
		TI  = 4538,	SW  = 4733,	SC1 = 4054,	SC2 = 4555,	WS1 = 4246,	WS2 = 4813,
		CH1 = 4379,	CH2 = 5113,	VF  = 4432,	BH  = 4589,	FG1 = 3993,	FG2 = 4303,
		DC1 = 4145,	DC2 = 4641,	AC  = 4202,	DK  = 4346,	BC  = 4469,	VM  = 4822,
		ICP = 5136,	WGT = 5342,	CS  = 5702,	RM  = 5403,	BF  = 5889,	FH  = 5891,
		FL  = 6064,	SP  = 6065,	MHK = 6186,	MOS = 6188,	DoM = 6251,	FV  = 6249,
		LM  = 6351,	MF  = 6349,	IR  = 6414,	UG  = 6416,	SG  = 6505,	CT  = 6507,
		BDV = 6576,	TC  = 6578,	RPB = 6683,	TDC = 6685,	CA  = 6740,	SR  = 6742,
		ERE = 6835,	GD  = 6837,	BS  = 6896,	SH  = 7027,	OP  = 7105,	BV  = 7155,
		ER = 7235, LS = 7237, NC = 7320, BGF = 7323
	}
	local DUNGEON_STATUS_BY_ZONE = {}
	for k, v in pairs(DUNGEON_ZONES) do
		DUNGEON_STATUS_BY_ZONE[v] = GetCompletedQuestInfo(DUNGEON_QUESTS[k])-- ~= "" and 1 or 0 --returns something if completed
	end


	SecurePostHook(ZO_ActivityFinderTemplate_Gamepad, "RefreshSingularSectionPanel", function( self )
		local NAVIGATION_MODES = {CATEGORIES = 1,RANDOM_ENTRIES = 2,SPECIFIC_ENTRIES = 3,}
		if self.navigationMode ~= NAVIGATION_MODES.CATEGORIES then
			local currentList = self:GetCurrentList()
			if currentList then
				local targetData = currentList:GetTargetData()
				if targetData then
					local entryData = targetData.data
					if not entryData.isRoleSelector and (entryData.activityType==2 or entryData.activityType==3) then
						local zid = entryData.zoneId
						if zid then
							
							-- Match zone ID to the quest ID and get updated data, if its not stored already
							if DUNGEON_STATUS_BY_ZONE[zid] == nil or DUNGEON_STATUS_BY_ZONE[zid] == "" then
								for k, v in pairs(DUNGEON_ZONES) do
									if v == zid and DUNGEON_STATUS_BY_ZONE[v] == "" or DUNGEON_STATUS_BY_ZONE[v] == nil then
										DUNGEON_STATUS_BY_ZONE[v] = GetCompletedQuestInfo(DUNGEON_QUESTS[k]) -- ~= "" and 1 or 0 --returns something if completed
									end
								end
							end
							
							local spquest = "|c008000COMPLETED|r"
							if DUNGEON_STATUS_BY_ZONE[zid] == "" or DUNGEON_STATUS_BY_ZONE[zid] == nil then
								spquest = "|cFF6666INCOMPLETE|r" --RED
							end
							local newText = "\n\n"
							local qText = ""
							if DUNGEON_STATUS_BY_ZONE[zid] ~= "" then qText = " - " .. DUNGEON_STATUS_BY_ZONE[zid] end
							newText = newText .. "Skillpoint Quest: " .. spquest .. qText .. "\n"
							
							-- Note if this is an active undaunted quest
							local pledgeQuests = GetGoalPledges()
							for k, v in pairs(pledgeQuests) do
								if k == entryData.rawName or "The "..k == entryData.rawName then -- entryData.nameGamepad, entryData.nameKeyboard
									newText = newText .. "\nPledge Status: " .. v
								end
							end

							self.descriptionLabel:SetText(entryData.description .. newText)
						end

					end
				end
			end
		end
	end)

end


function KelaShowPledges()
    show_pledges()
end

function KelaSetupDungeonFinder()
    Add_Enhanced_DungeonFinder_Info()
end

SLASH_COMMANDS["/pledges"] = function()
    KelaShowPledges()
end
SLASH_COMMANDS["/pledge"] = function()
    KelaShowPledges()
end
