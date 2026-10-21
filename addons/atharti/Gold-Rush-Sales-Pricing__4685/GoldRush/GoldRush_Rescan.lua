local GR = GoldRush

local SECONDS_IN_DAY = 86400
local PROCESSOR_NAME = "GoldRush_Rescan"

local rescanInProgress = false
local rescanEventCount = 0
local rescanSaleCount = 0
local rescanPending = 0

function GR.OnRescanGuildDone()
	rescanPending = rescanPending - 1
	if rescanPending > 0 then return end

	rescanInProgress = false
	GR.SaveSales()
	GR.BuildSalesList()
end

function GR.RescanAllGuilds()
	if rescanInProgress then return end

	rescanInProgress = true
	rescanEventCount = 0
	rescanSaleCount = 0
	rescanPending = 0

	local cutoffTime = GetTimeStamp() - GR.SV.keepDays * SECONDS_IN_DAY

	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName and guildName ~= ""
			and GR.SV.guildProcessorsEnabled[guildName] ~= false then
			local processor = LibHistoire:CreateGuildHistoryProcessor(
				guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, PROCESSOR_NAME)

			if processor then
				rescanPending = rescanPending + 1

				processor:SetAfterEventTime(cutoffTime)
				processor:SetStopOnLastCachedEvent(true)
				processor:SetNextEventCallback(function(event)
					local info = event:GetEventInfo()
					if info.eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
						return
					end

					rescanEventCount = rescanEventCount + 1

					local eventId	= event:GetEventId()
					local timestamp = event:GetEventTimestampS()
					local seller	= info.sellerDisplayName
					local buyer		= "@" .. info.buyerDisplayName
					local quantity	= info.quantity
					local itemLink	= info.itemLink
					local price		= info.price
					local tax		= info.tax

					GR.AddPriceHistory(itemLink, price, quantity, timestamp)
					GR.SV.lastEventIds[guildName] = eventId

					if "@" .. seller == GR.displayName then
						if GR.AddSale(eventId, timestamp, guildName, seller, buyer,
									  quantity, itemLink, price, tax) then
							rescanSaleCount = rescanSaleCount + 1
						end
					end
				end)
				processor:SetOnStopCallback(GR.OnRescanGuildDone)
				processor:Start()
			end
		end
	end

	if rescanPending == 0 then
		rescanInProgress = false
	end
end

SLASH_COMMANDS["/grrescan"] = GR.RescanAllGuilds