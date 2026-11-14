-- KelaPadUI chat context-menu and slash-command additions.
-- Extracted from KelaPadUI.lua; uses KELA_TRIALS_DATA from kpui_data/kpui_data.lua.

local function AddContextMenuItems()
	EVENT_MANAGER:UnregisterForEvent("KelaPadUIEnhanced", EVENT_PLAYER_ACTIVATED)

	local LCM = LibCustomMenu or LibStub("LibCustomMenu", true)
	if not LCM then
		return
	end

	LCM:RegisterPlayerContextMenu(
		function (playerName, rawName)
			AddCustomMenuItem(GetString(SI_SOCIAL_MENU_SEND_MAIL), function() MAIL_MANAGER_GAMEPAD:GetSend():ComposeMailTo(playerName) end)

			AddCustomMenuItem(GetString(SI_SOCIAL_MENU_JUMP_TO_PLAYER), function()
				if IsFriend(playerName) then
					JumpToFriend(playerName)
				elseif IsPlayerInGroup(rawName) then
					JumpToGroupMember(playerName)
				else
					JumpToGuildMember(playerName)
				end
			end)

		end
		, LCM.CATEGORY_EARLY)
	-- lib.CATEGORY_EARLY 		-- is before the first built-in menu entry.
	-- lib.CATEGORY_PRIMARY 	-- is after the first built-in menu entry. And so on.
	-- lib.CATEGORY_SECONDARY
	-- lib.CATEGORY_TERTIARY
	-- lib.CATEGORY_QUATERNARY
	-- lib.CATEGORY_LATE		-- is after built-in menu and default.
end

local function AddChatCommands()
	SLASH_COMMANDS['/keyboardmap'] = function() SCENE_MANAGER:Show("worldMap") end
	SLASH_COMMANDS['/achievementsearch'] = function(s)
		SCENE_MANAGER:Show("achievements")
		ACHIEVEMENTS.contentSearchEditBox:SetText(s)
	end
	SLASH_COMMANDS['/linkachievement'] = function(s)
		local aid = nil
		local trial = KELA_TRIALS_DATA[string.upper(s)]

		if trial then
			-- Get the highest achievement to flex to the group
			if trial.TRI and IsAchievementComplete(trial.TRI) then
				aid = trial.TRI
			elseif trial.HM and IsAchievementComplete(trial.HM) then
				aid = trial.HM
			elseif trial.PHM2 and IsAchievementComplete(trial.PHM2) then
				aid = trial.PHM2
			elseif trial.PHM1 and IsAchievementComplete(trial.PHM1) then
				aid = trial.PHM1
			else
				aid = trial.VET
			end
			ZO_LinkHandler_InsertLink(ZO_LinkHandler_CreateChatLink(GetAchievementLink, aid))
		else
			CHAT_SYSTEM:AddMessage('Use the trial abbreviation, such as vse or vDSR. Highest achievement will be linked.')
			for t, d in pairs(KELA_TRIALS_DATA) do
				CHAT_SYSTEM:AddMessage('   ' .. t .. ' - ' .. d.NAME)
			end
		end
	end
	SLASH_COMMANDS['/linkachiev'] = SLASH_COMMANDS['/linkachievement']
	SLASH_COMMANDS['/link'] = SLASH_COMMANDS['/linkachievement']
end

function KelaSetupChatTools()
	if KelaPadUI.KelaChatToolsInitialized then
		return
	end
	KelaPadUI.KelaChatToolsInitialized = true

	AddChatCommands()
	EVENT_MANAGER:RegisterForEvent("KelaPadUIEnhanced", EVENT_PLAYER_ACTIVATED, AddContextMenuItems)
end
