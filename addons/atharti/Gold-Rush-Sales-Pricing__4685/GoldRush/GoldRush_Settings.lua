local GR = GoldRush
local LAM = LibAddonMenu2

function GR.InitSettings()
	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName and guildName ~= "" and GR.SV.guildProcessorsEnabled[guildName] == nil then
			GR.SV.guildProcessorsEnabled[guildName] = true
		end
	end

	local optionsData = {
		{
		type = "header",
		name = "Features",
		},
		{
			type = "checkbox",
			name = "Price Tooltips",
			tooltip = "Show the average sale price of items in item tooltips. Turning this off erases all recorded price data (requires reload).",
			getFunc = function() return GR.SV.enablePriceTooltips end,
			setFunc = function(value)
				GR.SV.enablePriceTooltips = value
				if not value then
					GR.SV.enableKioskDeals = false
				end
			end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Profit Meter in Guild Store",
			tooltip = "Requires 'Show Price Tooltips' to be enabled. Shows the profit margin compared to the average sale price on guild trader listings.",
			getFunc = function() return GR.SV.enableKioskDeals end,
			setFunc = function(value) GR.SV.enableKioskDeals = value end,
			disabled = function() return not GR.SV.enablePriceTooltips end,
			requiresReload = true,
		},
		{
			type = "header",
			name = "Sale Notifications",
		},
		{
			type = "checkbox",
			name = "Center-Screen Notification",
			tooltip = "Displays a pop‑up announcement in the center of the screen and plays a sound when you sell an item.",
			getFunc = function() return GR.SV.enableSaleNotifications end,
			setFunc = function(value) GR.SV.enableSaleNotifications = value end,
		},
		{
			type = "checkbox",
			name = "Chat Notification",
			tooltip = "Prints a message in the chat window when you sell an item.",
			getFunc = function() return GR.SV.enableSaleNotificationsChat end,
			setFunc = function(value) GR.SV.enableSaleNotificationsChat = value end,
		},
		{
			type = "header",
			name = "Trading Guilds Are...",
		},
	}

	for i = 1, GetNumGuilds() do
		local guildId = GetGuildId(i)
		local guildName = GetGuildName(guildId)
		if guildName and guildName ~= "" then
			table.insert(optionsData, {
				type = "checkbox",
				name = guildName,
				tooltip = "Enable or disable GoldRush's trader history processor for " .. guildName .. ".",
				getFunc = function() return GR.SV.guildProcessorsEnabled[guildName] end,
				setFunc = function(value) GR.SV.guildProcessorsEnabled[guildName] = value end,
				default = true,
				requiresReload = true,
			})
		end
	end

	local panelData = {
		type = "panel",
		name = "Gold Rush",
		displayName = "|cFFD700Gold Rush|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	LAM:RegisterAddonPanel("GoldRushPanel", panelData)
	LAM:RegisterOptionControls("GoldRushPanel", optionsData)
end