local NAME = "AutoClaimTomePoints"
local TITLE = "Auto-Claim or Hide Tome Challenges"
local SV = nil


--------------------------------------------------------------------------------
-- Auto-Claim
--------------------------------------------------------------------------------

local PendingClaims = { }

local function CheckForAndClaimTomePoints( )
	if (not SV.hideOnly and IsTimedActivitySystemAvailable()) then
		for i = 1, GetNumTimedActivities() do
			if (GetTimedActivityCurrencyRewardInfo(i) == CURT_TOME_POINTS) then
				if (PendingClaims[i]) then
					if (GetTimedActivityNumTimesClaimed(i) > PendingClaims[i]) then
						PendingClaims[i] = nil
						CHAT_ROUTER:AddSystemMessage(string.format("%s – %s", zo_strformat(SI_TIMED_ACTIVITY_CLAIMED_PROGRESS, GetTimedActivityNumTimesClaimed(i), GetTimedActivityTotalNumTimesClaimable(i)), GetTimedActivityName(i)))
					end
				end

				if (not PendingClaims[i] and GetTimedActivityProgress(i) >= GetTimedActivityMaxProgress(i)) then
					PendingClaims[i] = GetTimedActivityNumTimesClaimed(i)
					ClaimTimedActivityReward(i)
				end
			end
		end
	end
end


--------------------------------------------------------------------------------
-- Settings and Initialization
--------------------------------------------------------------------------------

local NOP = nil

local function CheckOperationMode( )
	if (not SV.hideOnly) then
		EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, CheckForAndClaimTomePoints)
		EVENT_MANAGER:RegisterForEvent(NAME, EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED, CheckForAndClaimTomePoints)
		CheckForAndClaimTomePoints()
	else
		EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED)
		EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED)
		NOP = NOP or function() end
		TIMED_ACTIVITIES_MANAGER.GetFirstClaimableTimedActivityForHUDPrompt = NOP
		PLAYER_TO_PLAYER:RemoveFromIncomingQueue(ZO_INTERACT_TYPE.TIMED_ACTIVITY_REWARD)
	end
end

local function InitializeSettings( )
	SV = AutoClaimTomePointsSavedVariables or { }

	local LAM = LibAddonMenu2
	if (LAM) then
		local LANG = GetCVar("Language.2")
		local OPTION_LABEL = { default = "Hide instead of auto-claim", de = "Ausblenden statt Auto-Akzeptieren", es = nil, fr = nil, jp = nil, ru = nil, zh = nil }

        if MyUI_RegisterExternalSection then
            MyUI_RegisterExternalSection(20, "AutoClaimTomePoints", "20. Auto-Claim Tome Points", {
                {type = "checkbox", name = OPTION_LABEL[LANG] or OPTION_LABEL.default,
                 getFunc = function() return SV.hideOnly end,
                 setFunc = function(hideOnly)
                     SV.hideOnly = hideOnly
                     AutoClaimTomePointsSavedVariables = SV
                     CheckOperationMode()
                 end}
            })
        end
	end
end

EVENT_MANAGER:RegisterForEvent(NAME .. "_MyUI", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= "MyUI" then return end
    InitializeSettings()
    EVENT_MANAGER:UnregisterForEvent(NAME .. "_MyUI", EVENT_ADD_ON_LOADED)
end)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
    if not SV then InitializeSettings() end
    CheckOperationMode()
end, true)
