-- -----------------------------------------------------------
-- AddOn Taz's Chat Notifier  by  Tazmyr
-- -----------------------------------------------------------

-- I gratefully acknowledge the contribution of Seerah, sirinsidiator, et al to the Library LibAddonMenu-2.0 - thanks!


-- Initialize Addon
TazChatNotifier = {}
TazChatNotifier.Name = "TazChatNotifier"
TazChatNotifier.Version = "1.29"
TazChatNotifier.Author = "Tazmyr"
TazChatNotifier.SavedVariablesName = "TazChatNotifier_SavedVariables"
TazChatNotifier.SavedVariablesVersion = 1
TazChatNotifier.SavedVariablesNamespace = "TCN"
TCN = TazChatNotifier

-- REMINDER !!!!!!!!!!! reset below prior to release ===============
	TCN.WatchForKeyword		= false			-- when "tc" is found in chat, trigger special block, mostly for focused debugging
	TCN.DebugFlag	    		= false			-- debug flag (there are 2; this and one in Saved Variables)


-- wait to start until addon is fully loaded
local function tcn_OnAddOnLoaded(event, addonName)
	if addonName ~= TCN.Name then return end
	--if loaded, unregister the loaded check
	EVENT_MANAGER:UnregisterForEvent(TCN.Name, EVENT_ADD_ON_LOADED)

	-- Initialize variables ----------------------------------
	-- game
	local CHAT_CHANNEL_GUILD_1      	= CHAT_CHANNEL_GUILD_1		-- value is 12
	local CHAT_CHANNEL_GUILD_2      	= CHAT_CHANNEL_GUILD_2		-- value is 13
	local CHAT_CHANNEL_GUILD_3      	= CHAT_CHANNEL_GUILD_3		-- value is 14
	local CHAT_CHANNEL_GUILD_4      	= CHAT_CHANNEL_GUILD_4		-- value is 15
	local CHAT_CHANNEL_GUILD_5      	= CHAT_CHANNEL_GUILD_5		-- value is 16
	local CHAT_CHANNEL_OFFICER_1		= CHAT_CHANNEL_OFFICER_1
	local CHAT_CHANNEL_OFFICER_2    	= CHAT_CHANNEL_OFFICER_2
	local CHAT_CHANNEL_OFFICER_3    	= CHAT_CHANNEL_OFFICER_3
	local CHAT_CHANNEL_OFFICER_4    	= CHAT_CHANNEL_OFFICER_4
	local CHAT_CHANNEL_OFFICER_5    	= CHAT_CHANNEL_OFFICER_5
	local CHAT_CHANNEL_PARTY        	= CHAT_CHANNEL_PARTY		-- value is 3
	local CHAT_CHANNEL_SAY          	= CHAT_CHANNEL_SAY		-- value is 0
	local CHAT_CHANNEL_WHISPER      	= CHAT_CHANNEL_WHISPER		-- This is actually Whisper INBOUND (value = 2)
	local CHAT_CHANNEL_WHISPER_SENT		= CHAT_CHANNEL_WHISPER_SENT	-- Whisper SENT value = 4
	local CHAT_CHANNEL_YELL         	= CHAT_CHANNEL_YELL		-- value is 1
	local CHAT_CHANNEL_ZONE         	= CHAT_CHANNEL_ZONE		-- value is 31
	local Playsound				= Playsound
	local d                         	= d
	local SOUNDS		        	= SOUNDS
	local IsFriend				= IsFriend
	local GetDisplayName			= GetDisplayName

	-- lua
	local pairs		= pairs
	local ipairs	 	= ipairs
	local string	 	= string

	-- working tables and variables
	local TCN			= TCN
	TCN.Me				= GetDisplayName()	-- get own display name for self-chat check

	-- tables for menus
	TCN.AddonMenu 			= {}
	TCN.AddonMenu.Vars		= {}
	local AddonMenu			= TCN.AddonMenu
	local LAM			= LibAddonMenu2		-- connect to the library; LibAddonMenu-2.0

	-- Sounds library - (2-levels: Name [key], Sound & Descr)
	-- (EX: referred-to such as TCN.SoundsList.None.Sound  or as TCN.SoundsList.None.Descr) 
	TCN.SoundsList = {
		["None"] 		= { ["Sound"] 	= SOUNDS.NONE, 				["Descr"] 	= "Disabled" },
		["Long Drum"] 		= { ["Sound"] 	= SOUNDS.ACHIEVEMENT_AWARDED, 		["Descr"]	= "Long Drumbeat  (Achievement Award)" },
		["Donk"] 		= { ["Sound"] 	= SOUNDS.NEW_NOTIFICATION, 		["Descr"]	= "Donk  (New Notification)" },
		["Single Drumbeat"] 	= { ["Sound"] 	= SOUNDS.BOOK_ACQUIRED,			["Descr"]	= "Single Drumbeat  (Book Acquired)" },
		["KaThunk"] 		= { ["Sound"] 	= SOUNDS.DIALOG_ACCEPT, 		["Descr"]	= "KaThunk  (Dialog Accept)" },
		["ShaaaShinggg"] 	= { ["Sound"] 	= SOUNDS.SKILL_PURCHASED,		["Descr"]	= "Long ShhhaShing  (Skill Purchased)" },
		["Doinnng"] 		= { ["Sound"] 	= SOUNDS.QUEST_FOCUSED,			["Descr"]	= "Doinnng  (Quest Selected)" },
		["kTick"] 		= { ["Sound"] 	= SOUNDS.ABILITY_PICKED_UP, 		["Descr"]	= "kTick  (Ability Picked-up)" },
		["kTinnk"] 		= { ["Sound"] 	= SOUNDS.LOCKPICKING_BREAK,		["Descr"]	= "kTink  (Lockpick Break)" },
		["Thwaf"] 		= { ["Sound"] 	= SOUNDS.ABILITY_SLOT_CLEARED,		["Descr"]	= "Quiet Thwaf  (Ability Slot Cleared)" },
		["Thoomp"] 		= { ["Sound"] 	= SOUNDS.RADIAL_MENU_MOUSEOVER, 	["Descr"]	= "Thoomp  (Radial Menu Mouseover)" },
		["Shhhoooom"] 		= { ["Sound"] 	= SOUNDS.CHAMPION_POINT_GAINED, 	["Descr"]	= "Shhhoooom  (Champion Point Gained)" }
	}
	-- Build menu choices and related tooltip tables
	TCN.SoundOptions = {
		[1]	= "Long Drum",
		[2]	= "Donk",
		[3]	= "Single Drumbeat",
		[4]	= "KaThunk",
		[5]	= "ShaaaShinggg",
		[6]	= "Doinnng",
		[7]	= "kTick",
		[8]	= "kTinnk",
		[9]	= "Thwaf",
		[10]	= "Thoomp",
		[11]	= "Shhhoooom",
		[12]	= "None"
		}

	TCN.SoundTooltips = {
		[1]	= "Long Drumbeat  (Achievement Award)",
		[2]	= "Donk  (New Notification)",
		[3]	= "Single Drumbeat  (Book Acquired)",
		[4]	= "KaThunk  (Dialog Accept)",
		[5]	= "Long ShhhaShing  (Skill Purchased)",
		[6]	= "Doinnng  (Quest Selected)",
		[7]	= "kTick  (Ability Picked-up)",
		[8]	= "kTinnk  (Lockpick Break)",
		[9]	= "Quiet Thwaf  (Ability Slot Cleared)",
		[10]	= "Thoomp  (Radial Menu Mouseover)",
		[11]	= "Shhhoooom  (Champion Point Gained)",
		[12]	= "Disabled"
		}


	TCN.LoadVariables()				-- Get saved variables...
	LoadMenus()						-- Load Menus

	-- Setup Event listener
	EVENT_MANAGER:RegisterForEvent(TCN.Name, EVENT_CHAT_MESSAGE_CHANNEL, PlayDaSound)

end

-- Startup ... register for load event 
EVENT_MANAGER:RegisterForEvent(TCN.Name, EVENT_ADD_ON_LOADED, tcn_OnAddOnLoaded)


-- ========= MAIN PROCESS/FUNCTION:  Process inbound chat - play selected sound for selected/associated channels ==================

function PlayDaSound(event, channelType, fromName, messageText, isCustomerService, fromDisplayName)

	-- debug info? 
	if TCN.DebugFlag or TCN.SavedVariables.Debug then
		d("TCN-Debug: Flag=" .. tostring(TCN.DebugFlag) .. " / SavedVarsDebug:" .. tostring(TCN.SavedVariables.Debug))
		d("TCN-CH-Type=" .. channelType .. "  FromD=" .. fromDisplayName .. "  fromName=" .. fromName .. "  Me=" .. TCN.Me)
		d("TCN-PlayMyChats=" .. tostring(TCN.SavedVariables.PlayMyChats) .. " / DisableAllChatSounds=" .. tostring(TCN.SavedVariables.DisableAllChatSounds))
	end

	-- special debugging...watch for "tc" in chat
	if TCN.WatchForKeyword then
		if string.match(messageText, "tc") then
			d("tc-in-chat-debug:")
			d("SaveByChr=" .. tostring(TCN.SavedVariables.SaveByCharacter))
			d("PlayMyChats=" .. tostring(TCN.SavedVariables.PlayMyChats))
			d("DisableAllChatSounds=" .. tostring(TCN.SavedVariables.DisableAllChatSounds))
			d("SavedVarsDebug=" .. tostring(TCN.SavedVariables.Debug))
			d("Whisper     is Ch " .. tostring(CHAT_CHANNEL_WHISPER))
			d("WhisperSENT is Ch " .. tostring(CHAT_CHANNEL_WHISPER_SENT))
			d("Guild-1     is Ch " .. tostring(CHAT_CHANNEL_GUILD_1))
			d("Guild-2     is Ch " .. tostring(CHAT_CHANNEL_GUILD_2))
			d("Guild-3     is Ch " .. tostring(CHAT_CHANNEL_GUILD_3))
			d("Guild-4     is Ch " .. tostring(CHAT_CHANNEL_GUILD_4))
			d("Guild-5     is Ch " .. tostring(CHAT_CHANNEL_GUILD_5))
			d("Party       is Ch " .. tostring(CHAT_CHANNEL_PARTY))
			d("Say         is Ch " .. tostring(CHAT_CHANNEL_SAY))
			d("Yell        is Ch " .. tostring(CHAT_CHANNEL_YELL))
			d("Zone        is Ch " .. tostring(CHAT_CHANNEL_ZONE))


		end
	end

	-- If DisableAllChatSounds flag is NOT set, proceed ...
	if not TCN.SavedVariables.DisableAllChatSounds then

		-- If chat is from self, allow sound to play? (..based on flag)
		if TCN.SavedVariables.PlayMyChats or TCN.Me ~= fromDisplayName then

			-- Process the selected sound for the channel --------------------------
			-- NOTE: Party chat gets priority, then Friends, then Guilds, Whisper, Say, Yell, and Zone

			if channelType == CHAT_CHANNEL_PARTY and TCN.SavedVariables.OnParty.Enabled and TCN.SavedVariables.OnParty.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnParty.Sound].Sound)
				tcnInChatDebug("OnParty", TCN.SavedVariables.OnParty.Sound)			

			-- OnFriend handling ...
			elseif TCN.SavedVariables.OnFriend.Enabled and IsFriend(fromDisplayName) and TCN.SavedVariables.OnFriend.Sound ~= "None" then

				-- Check for Whisper_Sent and handle separately as Whisper_Sent does not return correct fromDisplayName
				if channelType == CHAT_CHANNEL_WHISPER_SENT then
					if TCN.SavedVariables.PlayMyChats then
						PlaySound(TCN.SoundsList[TCN.SavedVariables.OnFriend.Sound].Sound)				
						tcnInChatDebug("OnFriendOUT", TCN.SavedVariables.OnFriend.Sound)
					end
				else
					-- Play OnFriend sound ...
					PlaySound(TCN.SoundsList[TCN.SavedVariables.OnFriend.Sound].Sound)				
					tcnInChatDebug("OnFriend", TCN.SavedVariables.OnFriend.Sound)
				end

			elseif channelType == CHAT_CHANNEL_GUILD_1 and TCN.SavedVariables.OnGuild1.Enabled and TCN.SavedVariables.OnGuild1.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnGuild1.Sound].Sound)
				tcnInChatDebug("OnGuild1", TCN.SavedVariables.OnGuild1.Sound)

			elseif channelType == CHAT_CHANNEL_GUILD_2 and TCN.SavedVariables.OnGuild2.Enabled and TCN.SavedVariables.OnGuild2.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnGuild2.Sound].Sound)
				tcnInChatDebug("OnGuild2", TCN.SavedVariables.OnGuild2.Sound)

			elseif channelType == CHAT_CHANNEL_GUILD_3 and TCN.SavedVariables.OnGuild3.Enabled and TCN.SavedVariables.OnGuild3.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnGuild3.Sound].Sound)
				tcnInChatDebug("OnGuild3", TCN.SavedVariables.OnGuild3.Sound)

			elseif channelType == CHAT_CHANNEL_GUILD_4 and TCN.SavedVariables.OnGuild4.Enabled and TCN.SavedVariables.OnGuild4.Sound ~= "None"  then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnGuild4.Sound].Sound)
				tcnInChatDebug("OnGuild4", TCN.SavedVariables.OnGuild4.Sound)

			elseif channelType == CHAT_CHANNEL_GUILD_5 and TCN.SavedVariables.OnGuild5.Enabled and TCN.SavedVariables.OnGuild4.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnGuild5.Sound].Sound)
				tcnInChatDebug("OnGuild5", TCN.SavedVariables.OnGuild5.Sound)

				-- SPECIAL handling for Whisper_SENTs ... must test for PlayMyChats, as SENT whispers return the sender as the receiver
			elseif channelType == CHAT_CHANNEL_WHISPER_SENT and TCN.SavedVariables.OnWhisper.Enabled and TCN.SavedVariables.OnWhisper.Sound ~= "None" then
				if  TCN.SavedVariables.PlayMyChats then
					PlaySound(TCN.SoundsList[TCN.SavedVariables.OnWhisper.Sound].Sound)
					tcnInChatDebug("OnWhisper", TCN.SavedVariables.OnWhisper.Sound)
				end
				
			elseif channelType == CHAT_CHANNEL_WHISPER and TCN.SavedVariables.OnWhisper.Enabled and TCN.SavedVariables.OnWhisper.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnWhisper.Sound].Sound)
				tcnInChatDebug("OnWhisper", TCN.SavedVariables.OnWhisper.Sound)

			elseif channelType == CHAT_CHANNEL_SAY and TCN.SavedVariables.OnSay.Enabled and TCN.SavedVariables.OnSay.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnSay.Sound].Sound)
				tcnInChatDebug("OnSay", TCN.SavedVariables.OnSay.Sound)

			elseif channelType == CHAT_CHANNEL_YELL and TCN.SavedVariables.OnYell.Enabled and TCN.SavedVariables.OnYell.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnYell.Sound].Sound)
				tcnInChatDebug("OnYell", TCN.SavedVariables.OnYell.Sound)

			elseif channelType == CHAT_CHANNEL_ZONE and TCN.SavedVariables.OnZone.Enabled and TCN.SavedVariables.OnZone.Sound ~= "None" then
				PlaySound(TCN.SoundsList[TCN.SavedVariables.OnZone.Sound].Sound)
				tcnInChatDebug("OnZone", TCN.SavedVariables.OnZone.Sound)

			elseif TCN.DebugFlag == true or TCN.SavedVariables.Debug then		-- Chat NOT trapped above
					d("TCN: NO enabled channel for this chat. No sound played.")
			end
		end
	end

end

-- Debug Function for channel processing
function tcnInChatDebug(tChannel, tSound)
	if TCN.DebugFlag == true or TCN.SavedVariables.Debug then
		d("TCN: Played " .. tSound .. " for " .. tChannel)
	end
	
end

-- Load Saved Variables and Set Defaults ======================================
function TCN.LoadVariables()

	-- Set Defaults
	TCN.SavedVars = {}
	TCN.SavedVars.Defaults = {
		["Version"] 			= 1,
		["Debug"] 			= false,
		["SaveByCharacter"]		= false,
		["PlayMyChats"] 		= false,
		["DisableAllChatSounds"] 	= false,
		["Namespace"]			= "TCN",
		["OnGuild1"]			= { ["Enabled"] = true,		["Sound"]	= "ShaaaShinggg" },
		["OnGuild2"]			= { ["Enabled"] = true,		["Sound"]	= "Thoomp" },
		["OnGuild3"]			= { ["Enabled"] = true,		["Sound"]	= "kTick" },
		["OnGuild4"]			= { ["Enabled"] = true,		["Sound"]	= "kTick" },
		["OnGuild5"]			= { ["Enabled"] = true,		["Sound"]	= "kTick" },
		["OnParty"]			= { ["Enabled"] = true,		["Sound"]	= "Single Drumbeat" },
		["OnWhisper"]			= { ["Enabled"] = true,		["Sound"]	= "Long Drum" },
		["OnSay"]			= { ["Enabled"] = true,		["Sound"]	= "kTinnk" },
		["OnZone"]			= { ["Enabled"] = false,	["Sound"]	= "None" },
		["OnYell"]			= { ["Enabled"] = false,	["Sound"]	= "None" },
		["OnFriend"]			= { ["Enabled"] = true,		["Sound"]	= "ShaaaShinggg" }
	}

		
	-- Load/Set Saved Variables ...  
	local profile = nil

	-- Load ACCOUNT saved vars
	TCN.SavedVariables = ZO_SavedVars:NewAccountWide(
		TCN.SavedVariablesName, 
		TCN.SavedVariablesVersion, 
		TCN.SavedVariablesNamespace, 
		TCN.SavedVars.Defaults, 
		profile
		)


	TCN.SavedVariables.SaveByCharacter = false	-- force SaveByCharacter to false
	TCN.SavedVariablesLoaded = true
 
end



-- MENU's ==================================================================================

-- function called by each sound assignment in menus to play sound selected and assign to saved variables
function tcnSetSoundPlaySound(OnTrigger, Choice)
	
	TCN.SavedVariables[OnTrigger].Sound = Choice		-- save to Saved Variabled
	if Choice ~="None" then
		PlaySound(TCN.SoundsList[Choice].Sound)	-- Play selected sound	
	end

	if TCN.DebugFlag or TCN.SavedVariables.Debug then
		d("Setting " .. OnTrigger .. " to: " .. Choice)
	end

	return Choice
end

-- Load menus

function LoadMenus()
	-- Load panel header
	local panelData = {
    	type = "panel",
    	name = "Taz's Chat Notifier",
    	displayName = "Taz's Chat Notifier",
    	author = TCN.Author,
    	version = TCN.Version,
    	registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
    	registerForDefaults = true	--boolean (optional) (will set all options controls back to default values)
	}

	local LAM = LibAddonMenu2
	LAM:RegisterAddonPanel(TCN.Name, panelData)
	
-- Load options table
	local optionsTable = {
		[1] = {
			type 	= "header",
			name 	= "Options",
			width 	= "full"
			},

		[2] = {
			type 	= "checkbox",
			name 	= "Disable All Chat Sounds?",
			tooltip = "If Yes, Overrides all settings below, essentially disabling this addon.",
			width 	= "full",
			default = TCN.SavedVars.Defaults.DisableAllChatSounds,
			getFunc = function() return TCN.SavedVariables.DisableAllChatSounds end,
			setFunc = function(var) TCN.SavedVariables.DisableAllChatSounds = var end
			},
		[3] = {
        		type 	= "checkbox",
        		name 	= "Play sound on MY chats if triggered below?",
			tooltip = "Should *your* chats trigger sounds in the channels below?",
	        	width 	= "full",
			default = TCN.SavedVars.Defaults.PlayMyChats,
			getFunc = function() return TCN.SavedVariables.PlayMyChats end,
			setFunc = function(var) TCN.SavedVariables.PlayMyChats = var end
    			},
		[4] = {
			type 	= "header",
			name 	= "=== Chat Channels & Sound-to-Play ===",
			width	= "full"
			},
		[5] = {
			type 	= "description",
			title 	= "Important: === Inbound Chat Priorities ===",
			text 	= "Sound will play for the FIRST qualified entry BELOW that is ENABLED and the Sound is other than *None*."
			},
		[6] = {
			type = "checkbox",
			name = "On Party (Group)",
			tooltip = "Enable Sound for Party (Group) chats?",
			getFunc = function() return TCN.SavedVariables.OnParty.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnParty.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnParty.Enabled,
			width = "full"
			},
		[7] = {
			type = "dropdown",
			name = " -- On Party (Group) Sound",
			tooltip = "Sound to play for Party (Group) chat.",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnParty.Sound,
			getFunc = function() return TCN.SavedVariables.OnParty.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnParty", SoundChoice) end,
			width = "full"
			},
		[8] = {type = "divider"},
		[9] = {
			type = "checkbox",
			name = "On Friend",
			tooltip = "Enable Sound for chats from Friends?",
			getFunc = function() return TCN.SavedVariables.OnFriend.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnFriend.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnFriend.Enabled,
			width = "full"
			},
		[10] = {
			type = "dropdown",
			name = " -- On Friend Sound",
			tooltip = "Sound to play for chats from Friends",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnFriend.Sound,
			getFunc = function() return TCN.SavedVariables.OnFriend.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnFriend", SoundChoice) end,
			width = "full"
			},
		[11] = {type = "divider"},
		[12] = {
			type = "checkbox",
			name = "On Guild 1",
			tooltip = "Enable Sound for chats from Guild 1?",
			getFunc = function() return TCN.SavedVariables.OnGuild1.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnGuild1.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnGuild1.Enabled,
			width = "full"
			},
		[13] = {
			type = "dropdown",
			name = " -- On Guild 1 Sound",
			tooltip = "Sound to play for chats from Guild 1",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnGuild1.Sound,
			getFunc = function() return TCN.SavedVariables.OnGuild1.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnGuild1", SoundChoice) end,
			width = "full"
			},
		[14] = {type = "divider"},
		[15] = {
			type = "checkbox",
			name = "On Guild 2",
			tooltip = "Enable Sound for chats from Guild 2?",
			getFunc = function() return TCN.SavedVariables.OnGuild2.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnGuild2.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnGuild2.Enabled,
			width = "full"
			},
		[16] = {
			type = "dropdown",
			name = " -- On Guild 2 Sound",
			tooltip = "Sound to play for chats from Guild 2",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnGuild2.Sound,
			getFunc = function() return TCN.SavedVariables.OnGuild2.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnGuild2", SoundChoice) end,
			width = "full"
			},
		[17] = {type = "divider"},
		[18] = {
			type = "checkbox",
			name = "On Guild 3",
			tooltip = "Enable Sound for chats from Guild 3?",
			getFunc = function() return TCN.SavedVariables.OnGuild3.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnGuild3.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnGuild3.Enabled,
			width = "full"
			},
		[19] = {
			type = "dropdown",
			name = " -- On Guild 3 Sound",
			tooltip = "Sound to play for chats from Guild 3",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnGuild3.Sound,
			getFunc = function() return TCN.SavedVariables.OnGuild3.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnGuild3", SoundChoice) end,
			width = "full"
			},
		[20] = {type = "divider"},
		[21] = {
			type = "checkbox",
			name = "On Guild 4",
			tooltip = "Enable Sound for chats from Guild 4?",
			getFunc = function() return TCN.SavedVariables.OnGuild4.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnGuild4.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnGuild4.Enabled,
			width = "full"
			},
		[22] = {
			type = "dropdown",
			name = " -- On Guild 4 Sound",
			tooltip = "Sound to play for chats from Guild 4",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnGuild4.Sound,
			getFunc = function() return TCN.SavedVariables.OnGuild4.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnGuild4", SoundChoice) end,
			width = "full"
			},
		[23] = {type = "divider"},
		[24] = {
			type = "checkbox",
			name = "On Guild 5",
			tooltip = "Enable Sound for chats from Guild 5?",
			getFunc = function() return TCN.SavedVariables.OnGuild5.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnGuild5.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnGuild5.Enabled,
			width = "full"
			},
		[25] = {
			type = "dropdown",
			name = " -- On Guild 5 Sound",
			tooltip = "Sound to play for chats from Guild 5",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnGuild5.Sound,
			getFunc = function() return TCN.SavedVariables.OnGuild5.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnGuild5", SoundChoice) end,
			width = "full"
			},
		[26] = {type = "divider"},
		[27] = {
			type = "checkbox",
			name = "On Whisper",
			tooltip = "Enable Sound for Whispers?",
			getFunc = function() return TCN.SavedVariables.OnWhisper.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnWhisper.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnWhisper.Enabled,
			width = "full"
			},
		[28] = {
			type = "dropdown",
			name = " -- On Whispers Sound",
			tooltip = "Sound to play for Whispers",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnWhisper.Sound,
			getFunc = function() return TCN.SavedVariables.OnWhisper.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnWhisper", SoundChoice) end,
			width = "full"
			},
		[29] = {type = "divider"},
		[30] = {
			type = "checkbox",
			name = "On Say",
			tooltip = "Enable Sound for Say chat?",
			getFunc = function() return TCN.SavedVariables.OnSay.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnSay.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnSay.Enabled,
			width = "full"
			},
		[31] = {
			type = "dropdown",
			name = " -- On Say Sound",
			tooltip = "Sound to play for Say chat",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnSay.Sound,
			getFunc = function() return TCN.SavedVariables.OnSay.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnSay", SoundChoice) end,
			width = "full"
			},
		[32] = {type = "divider"},
		[33] = {
			type = "checkbox",
			name = "On Yell",
			tooltip = "Enable Sound for Yell chat?",
			getFunc = function() return TCN.SavedVariables.OnYell.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnYell.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnYell.Enabled,
			width = "full"
			},
		[34] = {
			type = "dropdown",
			name = " -- On Yell Sound",
			tooltip = "Sound to play for Yell chat",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnYell.Sound,
			getFunc = function() return TCN.SavedVariables.OnYell.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnYell", SoundChoice) end,
			width = "full"
			},
		[35] = {type = "divider"},
		[36] = {
			type = "checkbox",
			name = "On Zone",
			tooltip = "Enable Sound for Zone chat?",
			getFunc = function() return TCN.SavedVariables.OnZone.Enabled end,
			setFunc = function(var) TCN.SavedVariables.OnZone.Enabled = var end,
			default = TCN.SavedVars.Defaults.OnZone.Enabled,
			width = "full"
			},
		[37] = {
			type = "dropdown",
			name = " -- On Zone Sound",
			tooltip = "Sound to play for Zone chat",
			choices = TCN.SoundOptions,
			choicesTooltips = TCN.SoundTooltips,
			default = TCN.SavedVars.Defaults.OnZone.Sound,
			getFunc = function() return TCN.SavedVariables.OnZone.Sound end,
			setFunc = function(SoundChoice) return tcnSetSoundPlaySound("OnZone", SoundChoice) end,
			width = "full"
			},
		[38] = {
			type 	= "header",
			name 	= "---- Debugging Options----",
			width	= "full"
			},
		[39] = {
			type = "checkbox",
			name = "Show Debug Messages?",
			tooltip = "Set to Yes will chatter your chat box with debug info. Best left OFF.",
			getFunc = function() return TCN.SavedVariables.Debug end,
			setFunc = function(var) TCN.SavedVariables.Debug = var end,
			default = TCN.SavedVars.Defaults.Debug,
			width = "full"
			},

		}

	LAM:RegisterOptionControls(TCN.Name, optionsTable)
	
end

	