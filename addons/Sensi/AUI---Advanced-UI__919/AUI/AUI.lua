local g_isInit = false
local g_showStartMessage = true

local globalEffectFilter = 
{
	[63601] = true, -- ESO Plus
	[43752] = true, -- Soul Summons
}

local function RunSlashCommand(option)	
	local options = { 
		string.match(option,"^(%S*)%s*(.-)$") 
	}

	if not option or option == "" then
    	d("AUI slash commands: ")
	    d("|ce5e1b4Gold donation:|r |cffffff/aui donate <value>|r")	
		d("|ce5e1b4Refresh Minimap:|r |cffffff/aui minimap refresh|r")	
		d("|ce5e1b4Toggle Minimap:|r |cffffff/aui minimap toggle|r")
	elseif options[1] and options[2]then
		if options[1] == "donate" then
			local value = tonumber(options[2])
			if value and value >= 1000 then
				RequestOpenMailbox()
				QueueMoneyAttachment(tonumber(options[2]))	
				SendMail("@sensi2010", "AUI Donation")
			else			
				d(AUI.L10n.GetString("zero_donate_warning"))
			end
		elseif options[1] == "minimap" then
			if options[2] == "refresh" then
				AUI.Minimap.Refresh()
			elseif options[2] == "toggle" then
				AUI.Minimap.Toggle()
			end
		elseif options[1] == "stresstest" then
			if options[2] == "start" then
				AUI.StressTest.Start()
			elseif options[2] == "stop" then
				AUI.StressTest.Stop()
			end
		end
	end
end

local function Load()
	g_showStartMessage = true
	
	AUI.MainMenu.SetMenuData()	
	AUI.LoadTemplateSettings()

	if AUI.ReloadUIHelper.IsEnabled() then
		AUI.ReloadUIHelper.Load()
	end	
	
	if AUI.UnitFrames.IsEnabled() then
		AUI.UnitFrames.Load()
	end

	if AUI.Combat.IsEnabled() then
		AUI.Combat.Load()	
	end
	
	if AUI.Actionbar.IsEnabled() then
		AUI.Actionbar.Load()
	end
	
	if AUI.Buffs.IsEnabled() then
		AUI.Buffs.Load()
	end	
	
	if AUI.Minimap.IsEnabled() then
		AUI.Minimap.Load()
	else	
		AUI.Minimap.Unload()
	end	

	if AUI.Questtracker.IsEnabled() then
		AUI.Questtracker.Load()
		AUI.Questtracker.Show()
	end
	
	if AUI.FrameMover.IsEnabled() then
		AUI.FrameMover.Load()
	end

	AUI.Keybinding.Create()	
	
	AUI.LoadEvents()
	
	SLASH_COMMANDS["/aui"] = RunSlashCommand
	SLASH_COMMANDS["/advancedui"] = RunSlashCommand
	
	if ZO_LootHistoryControl_Keyboard then
		ZO_LootHistoryControl_Keyboard:SetDrawLayer(DL_OVERLAY)
	end
end

function AUI.GetGlobalEffectFilter()
	return globalEffectFilter
end

function AUI.IsLoaded()
	return g_isInit
end

function AUI.SendStartMessage()
	if g_isInit and g_showStartMessage and AUI.Settings.MainMenu.show_start_message then
		d("|c80c63dAUI|r addon loaded. Type |cffffff/aui|r for more info")
		g_showStartMessage = false
	end
end

function AUI.Minimap.IsEnabled()
	return AUI.Settings.MainMenu.modul_minimap_enabled
end

function AUI.UnitFrames.IsEnabled()
	return AUI.Settings.MainMenu.modul_unit_frames_enabled
end

function AUI.Combat.IsEnabled()
	return AUI.Settings.MainMenu.modul_combat_stats_enabled
end

function AUI.Actionbar.IsEnabled()
	return AUI.Settings.MainMenu.modul_action_bar_enabled
end

function AUI.Buffs.IsEnabled()
	return AUI.Settings.MainMenu.modul_buffs_enabled
end

function AUI.Questtracker.IsEnabled()
	return AUI.Settings.MainMenu.modul_quest_tracker_enabled
end

function AUI.FrameMover.IsEnabled()
	return AUI.Settings.MainMenu.modul_frame_mover_enabled
end

function AUI.ReloadUIHelper.IsEnabled()
	return true
end

EVENT_MANAGER:RegisterForEvent("AUI_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED, 
function(p_eventCode, p_addOnName) 
	if p_addOnName ~= "AUI" or g_isInit then
        return
    end	

	EVENT_MANAGER:UnregisterForEvent("AUI_EVENT_ADD_ON_LOADED", EVENT_ADD_ON_LOADED)
	
	g_isInit = true
	
	Load()
end)