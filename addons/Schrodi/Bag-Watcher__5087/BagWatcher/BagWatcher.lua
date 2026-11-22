EVENT_MANAGER:RegisterForEvent("BagWatcher", EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= "BagWatcher" then return end
	
	WINDOW_MANAGER:CreateControl("BagWatcher_BagSpace", ZO_PerformanceMeters, CT_LABEL)
	BagWatcher_BagSpace:SetDimensions(75, 40)
	BagWatcher_BagSpace:ClearAnchors()
	BagWatcher_BagSpace:SetAnchor(LEFT, ZO_PerformanceMetersLatencyMeter, RIGHT, -10, 0)
	BagWatcher_BagSpace:SetFont("ZoFontWinT2")
	BagWatcher_BagSpace:SetColor(1, 1, 1, 1)
	BagWatcher_BagSpace:SetHorizontalAlignment(0)
	BagWatcher_BagSpace:SetVerticalAlignment(1)
	BagWatcher_BagSpace:SetText("")
	BagWatcher_BagSpace:SetMouseEnabled(true)
	BagWatcher_BagSpace:SetHandler("OnMouseEnter", function(control) ZO_Tooltips_ShowTextTooltip(ZO_PerformanceMeters, LEFT, "Available bag space") end)
	BagWatcher_BagSpace:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
	
	ZO_PerformanceMeters:SetWidth(200)
	ZO_PerformanceMetersBg:SetWidth(335)
	ZO_PerformanceMetersFramerateMeter:ClearAnchors()
	ZO_PerformanceMetersFramerateMeter:SetAnchor(LEFT, ZO_PerformanceMeters, LEFT, 20, 0)
	ZO_PerformanceMetersLatencyMeter:ClearAnchors()
	ZO_PerformanceMetersLatencyMeter:SetAnchor(LEFT, ZO_PerformanceMetersFramerateMeter, RIGHT, -3, 0)
	
	local function OnBagSpace()
		local free = GetNumBagFreeSlots(BAG_BACKPACK)
		local color
		if free > 50 then
			color = "|cFFFFFF"
		elseif free > 15 then
			color = "|cFFdd22"
		else
			color = "|cFF2222"
		end
		BagWatcher_BagSpace:SetText("|t16:16:/esoui/art/tooltips/icon_bag.dds|t " .. color .. free .. "|r")
	end
	
	-- Bag changes often come in bursts (Take All from mail, opening a container, deconstructing
	-- a stack), so the number is refreshed once, shortly after the last change.
	local REFRESH_DELAY_MS = 100
	local REFRESH_NAME = "BagWatcherRefresh"
	local function QueueRefresh()
		EVENT_MANAGER:UnregisterForUpdate(REFRESH_NAME)
		EVENT_MANAGER:RegisterForUpdate(REFRESH_NAME, REFRESH_DELAY_MS, function()
			EVENT_MANAGER:UnregisterForUpdate(REFRESH_NAME)
			OnBagSpace()
		end)
	end

	-- Single-slot updates are the only one of these events with a bag id, so only they get
	-- the backpack filter. Before, every event (full inventory update, loot received, item
	-- used) was registered with a bag filter it has no parameter for, which can keep it from
	-- ever firing, and the number then stayed stale until the next single-slot change.
	EVENT_MANAGER:RegisterForEvent("BagWatcherSlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, QueueRefresh)
	EVENT_MANAGER:AddFilterForEvent("BagWatcherSlot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	EVENT_MANAGER:RegisterForEvent("BagWatcherFull", EVENT_INVENTORY_FULL_UPDATE, QueueRefresh)
	EVENT_MANAGER:RegisterForEvent("BagWatcherCapacity", EVENT_INVENTORY_BAG_CAPACITY_CHANGED, QueueRefresh)
	EVENT_MANAGER:RegisterForEvent("BagWatcherActivated", EVENT_PLAYER_ACTIVATED, QueueRefresh)

	local PERFORMANCE_METERS_SetLatency = PERFORMANCE_METERS.SetLatency
	local r, g, b, a = 204/255, 204/255, 170/255, 1
	function PERFORMANCE_METERS:SetLatency(latency)
		PERFORMANCE_METERS_SetLatency(PERFORMANCE_METERS, latency)
		ZO_PerformanceMetersLatencyMeterBars:SetColor(r, g, b, a)
	end
		
	OnBagSpace()
end)