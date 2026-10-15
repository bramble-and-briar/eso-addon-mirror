local ADDON_NAME  = "LogNPCDialog"

local function SayInMonsterChannel(who, what)
	--	Typo corrections
	what = what:gsub("%.(%a)", ". %1")		-- Add space after “.” if there isn't
	what = what:gsub("  ", " ")				-- Replace double spaces by one
	what = what:gsub(" (%p)", " %1")		-- Just in case, should be already correct
	what = what:gsub("\r\n\r\n", "\r\n")	-- Double new lines look weird in chat

	CHAT_ROUTER:FormatAndAddChatMessage(EVENT_CHAT_MESSAGE_CHANNEL, CHAT_CHANNEL_MONSTER_SAY, who, what, false)
end

local function OverloadSelectChatterOption()
	--	Shared by keyboard (INTERACTION) and gamepad (GAMEPAD_INTERACTION) windows
	--	Keyboard “SelectChatterOptionByIndex” and gamepad list selection both trigger it
	ZO_PreHook(ZO_SharedInteraction, "HandleChatterOptionClicked", function(self, label)
		if not (label.enabled and label.optionIndex) then return end
		local text = label.optionText
		-- if text == nil or not(text) or text == "" then
			-- text = label:GetText() -- With all formatting, icon and number
		-- end
		SayInMonsterChannel(ZO_HIGHLIGHT_TEXT:Colorize(GetUnitName("player")), ZO_HIGHLIGHT_TEXT:Colorize(text))
	end)
end

local function OnDialog()
	--	Call on the next frame
	zo_callLater(function()
		local bodyText
		--	Get text values, correct and add history
		if IsInGamepadPreferredMode() then
			bodyText = ZO_InteractWindow_GamepadContainerText:GetText()
		else
			bodyText = ZO_InteractWindowTargetAreaBodyText:GetText()
		end
		if not(bodyText) or bodyText == "" then return end
		SayInMonsterChannel(GetUnitName("interact"), bodyText)
	end, 1)
end

local function OnAddOnLoaded(eventCode, addonName)
	--	Escape if incorrect
	if addonName ~= ADDON_NAME then return end

	--	Unregister
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

	OverloadSelectChatterOption()

	--	Register to various events
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHATTER_BEGIN,			OnDialog)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_OFFERED,			OnDialog)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_QUEST_COMPLETE_DIALOG,	OnDialog)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CONVERSATION_UPDATED,	OnDialog)
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
