-- ClaimPoints.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

--*******************--
-- Claim Tome Points
local PendingClaimsTP = {}
local RESPONSE_TIME_LIMIT_TP = 2500

local function CheckForAndClaimTomePoints()
if not MSI.SVars.IsClaimTomePoints then return end
	if (IsTimedActivitySystemAvailable()) then
		for i = 1, GetNumTimedActivities() do
			if (GetTimedActivityCurrencyRewardInfo(i) == CURT_TOME_POINTS and GetTimedActivityProgress(i) >= GetTimedActivityMaxProgress(i)) then
				local msTP = PendingClaimsTP[i] or 0
				PendingClaimsTP[i] = GetGameTimeMilliseconds()
				if (PendingClaimsTP[i] - msTP > RESPONSE_TIME_LIMIT_TP) then
					ClaimTimedActivityReward(i)
				end
			end
		end
	end
end

local function CheckForTomePointClaimResult(_, currencyType, _, _, _, reason)
if not MSI.SVars.IsClaimTomePoints then return end
	if (currencyType == CURT_TOME_POINTS and reason == CURRENCY_CHANGE_REASON_REWARD) then
		for i, msTP in pairs(PendingClaimsTP) do
			if (GetGameTimeMilliseconds() - msTP <= RESPONSE_TIME_LIMIT_TP) then
				MSI.Print("c", string.format("%s %s", MSI.Colorize(zo_strformat(SI_TIMED_ACTIVITY_CLAIMED_PROGRESS, GetTimedActivityNumTimesClaimed(i), GetTimedActivityTotalNumTimesClaimable(i))), MSI.Colorize(GetTimedActivityName(i))))
				MSI.ShowCenterMsg(2468, [[icon_info.dds]], string.format("%s %s", MSI.Colorize(zo_strformat(SI_TIMED_ACTIVITY_CLAIMED_PROGRESS, GetTimedActivityNumTimesClaimed(i), GetTimedActivityTotalNumTimesClaimable(i))), MSI.Colorize(GetTimedActivityName(i))))
			end
		end
		PendingClaimsTP = {}
	end
end

--*******************--
-- Claim Golden Pursuits
local PendingClaimsGP = {}
local RESPONSE_TIME_LIMIT_GP = 2500

local function CheckForAndClaimGoldenPursuits()
if not MSI.SVars.IsCaimPursuitPts then return end
	if (not IsPromotionalEventSystemLocked()) then
		for i = 1, GetNumActivePromotionalEventCampaigns() do
			local campaignKey = GetActivePromotionalEventCampaignKey(i)
			if (ShouldPromotionalEventCampaignBeVisible(campaignKey) and IsAnyPromotionalEventCampaignRewardClaimable(campaignKey)) then
				local key = Id64ToString(campaignKey)
				local msGP = PendingClaimsGP[key] or 0
				PendingClaimsGP[key] = GetGameTimeMilliseconds()
				if (PendingClaimsGP[key] - msGP > RESPONSE_TIME_LIMIT_GP) then
					TryClaimAllAvailablePromotionalEventCampaignRewards(campaignKey)
				end
			end
		end
	end
end

local function CheckForGoldenPursuitClaimResult(_, campaignKey)
if not MSI.SVars.IsCaimPursuitPts then return end
	local key = Id64ToString(campaignKey)
	if (GetGameTimeMilliseconds() - (PendingClaimsGP[key] or 0) <= RESPONSE_TIME_LIMIT_GP) then
		MSI.Print("c", MSI.Colorize(GetString(SI_PROMOTIONAL_EVENT_REWARD_CLAIMED_ANNOUNCEMENT)))
		MSI.ShowCenterMsg(2468, [[icon_info.dds]], MSI.Colorize(GetString(SI_PROMOTIONAL_EVENT_REWARD_CLAIMED_ANNOUNCEMENT)))
		PendingClaimsGP[key] = nil
	end
end

--*******************--
-- Claim Tome Points
function MSI.InitModClaimTomePoints()
	local function UnRegModuleTomeEvents()
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."ClaimTome", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."ClaimTome", EVENT_CURRENCY_UPDATE)
		
	end
	local function RegModuleTomeEvents()
		UnRegModuleTomeEvents()
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."ClaimTome", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, CheckForAndClaimTomePoints)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."ClaimTome", EVENT_CURRENCY_UPDATE, CheckForTomePointClaimResult)
		
	end
	if MSI.SVars.IsClaimTomePoints and MSI.SVars.IsMSIActive then
		RegModuleTomeEvents()
		CheckForAndClaimTomePoints()
		--MSI.Print("d", "Modul enabled!! ClaimTomePoints Event registered")
	elseif not MSI.SVars.IsClaimTomePoints or not MSI.SVars.IsMSIActive then
		UnRegModuleTomeEvents()
		--MSI.Print("d", "Modul disabled!! ClaimTomePoints Event unregistered")
	else
		UnRegModuleTomeEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! ClaimTomePoints Event unregistered")
	end
end

--**********************--
-- Claim Pursuit Points
function MSI.InitModCaimPursuitPoints()
	local function UnRegModuleGoldenPursuitsEvents()
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."ClaimPursuit", EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."ClaimPursuit", EVENT_PROMOTIONAL_EVENTS_REWARDS_CLAIMED)
		
	end
	local function RegModuleGoldenPursuitsEvents()
		UnRegModuleGoldenPursuitsEvents()
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."ClaimPursuit", EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED, CheckForAndClaimGoldenPursuits)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."ClaimPursuit", EVENT_PROMOTIONAL_EVENTS_REWARDS_CLAIMED, CheckForGoldenPursuitClaimResult)
		
	end
	if MSI.SVars.IsCaimPursuitPts and MSI.SVars.IsMSIActive then
		RegModuleGoldenPursuitsEvents()
		CheckForAndClaimGoldenPursuits()
		--MSI.Print("d", "Modul enabled!! CaimPursuitPoints Event registered")
	elseif not MSI.SVars.IsCaimPursuitPts or not MSI.SVars.IsMSIActive then
		UnRegModuleGoldenPursuitsEvents()
		--MSI.Print("d", "Modul disabled!! CaimPursuitPoints Event unregistered")
	else
		UnRegModuleGoldenPursuitsEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! CaimPursuitPoints Event unregistered")
	end
end
--eof