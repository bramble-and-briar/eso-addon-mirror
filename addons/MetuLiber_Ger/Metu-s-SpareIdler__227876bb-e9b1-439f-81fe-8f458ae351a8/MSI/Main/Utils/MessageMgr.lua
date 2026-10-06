-- MessageMgr.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

local blendDurations = 789

local MSIMediaList = {
	[1] = [[icon_the_poo.dds]],
	[2] = [[icon_metu_liber.dds]],
	[3] = [[metu_liber.dds]],
	[4] = [[rene_metu.dds]],
}

--****************--
-- Show CenterMsg
local function AnimateCenterMessage(msgDuration, msgIcon, msgText)
	if not CenterMsgDisplay:IsHidden() then return end
	
	local animation0, timeline0 = CreateSimpleAnimation(ANIMATION_ALPHA, CenterMsgDisplay)

	CenterMsgTexture:SetTexture(MSI.Name.."/Media/"..msgIcon)
	CenterMsgTextLabel:SetText(msgText)

	CenterMsgDisplay:SetHidden(false)
	animation0:SetAlphaValues(CenterMsgDisplay:GetAlpha(), 1)
	animation0:SetDuration(blendDurations)

	-- Fade-out after Fade-in
	timeline0:SetHandler('OnStop', function()
		local animation0, timeline0 = CreateSimpleAnimation(ANIMATION_ALPHA, CenterMsgDisplay)

		animation0:SetAlphaValues(CenterMsgDisplay:GetAlpha(), 1)
		animation0:SetDuration(msgDuration)

		timeline0:SetHandler('OnStop', function()
			local animation0, timeline0 = CreateSimpleAnimation(ANIMATION_ALPHA, CenterMsgDisplay)

			animation0:SetAlphaValues(CenterMsgDisplay:GetAlpha(), 0)
			animation0:SetDuration(blendDurations)

			timeline0:SetHandler('OnStop', function()
				CenterMsgDisplay:SetHidden(true)
				MSI.activeDuration = 0
			end)
			timeline0:PlayFromStart()
		end)
		timeline0:PlayFromStart()
	end)
	timeline0:PlayFromStart()
end

--*******************--
-- Animate CenterMsg
function MSI.ShowCenterMsg(msgDuration, msgIcon, msgText)
	if not (MSI.activeDuration == 0) then
		zo_callLater(function() 
			MSI.activeDuration = blendDurations * 2 + msgDuration
			AnimateCenterMessage(msgDuration, msgIcon, msgText)
		end, (blendDurations * 2 + MSI.activeDuration) + (200 + GetLatency()))
	else
		zo_callLater(function() 
			MSI.activeDuration = msgDuration
			AnimateCenterMessage(msgDuration, msgIcon, msgText)
		end, (100 + GetLatency()))
	end
end

function MSI.ShowInitCenterMsg()
	MSI.ShowCenterMsg(4321, [[icon_metu_liber.dds]], GetString(MSI_MENU_ADDON_DESCR_TITLE))
end

--***************--
-- Show Announce
function MSI.ShowAnnounce(msgDelay, msgDuration, msgText)
	local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT)--CSA_CATEGORY_LARGE_TEXT)
	params:SetText(msgText)
	params:SetSound(SOUNDS.INTERACT_WINDOW_OPEN)--SOUNDS.ABILITY_FAILED)
	params:SetLifespanMS(msgDuration)

	if msgDelay ~= 0 then
		zo_callLater(function() return CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params) end, msgDelay + GetLatency())
	else
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
	end
end
--***************--
-- Show AlertMsg
function MSI.ShowAlertMsg(msgText)
	ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, msgText)
end

--**************************--
-- ChatLog DebugLog InfoLog
function MSI.Print(modeValue, message, ...)
	if (modeValue == "c" or modeValue == "chatLog") then
		if MSI.SVars.IsChatLog then
			--df("%s %s", GetString(MSI_ADDON_CHATLOG_TAG), MSI.Colorize(message:format(...)))
			d((GetString(MSI_ADDON_CHATLOG_TAG)..MSI.Colorize(" "..message)):format(...))
		elseif MSI.SVars.IsDebugLog and not MSI.SVars.IsChatLog then
			--df("%s %s", GetString(MSI_ADDON_CHATLOG_TAG), MSI.Colorize(message:format(...)))
			d((GetString(MSI_ADDON_CHATLOG_TAG)..MSI.Colorize(" "..message)):format(...))
		end
	elseif (modeValue == "d" or modeValue == "debugLog") then
		if MSI.SVars.IsDebugLog and not MSI.SVars.IsChatLog then
			--df("%s %s", GetString(MSI_ADDON_DEBUGLOG_TAG), MSI.Colorize(message:format(...)))
			d((GetString(MSI_ADDON_DEBUGLOG_TAG)..MSI.Colorize(" "..message)):format(...))
		end
	elseif (modeValue == "i" or modeValue == "infoLog") then
		--df("%s %s", GetString(MSI_ADDON_INFOLOG_TAG), MSI.Colorize(message:format(...)))
		d((GetString(MSI_ADDON_INFOLOG_TAG)..MSI.Colorize(" "..message)):format(...))
	end
end
--eof