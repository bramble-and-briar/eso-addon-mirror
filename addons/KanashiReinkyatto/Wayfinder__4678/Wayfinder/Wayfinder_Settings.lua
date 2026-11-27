-------------------------------------------------------------------------------
-- Wayfinder_Settings
-- LibAddonMenu-2.0 settings panel
-------------------------------------------------------------------------------

Wayfinder = Wayfinder or {}

Wayfinder.Defaults = {
	enableOpenMap       = true,
	enableNearbyPlayers = true,
	enableMapButton     = true,
	enableTravelMenu    = true,
	lockMapButton       = true,
	mapButtonHidden     = false,
	mapButtonPollIntervalSec = 5,
	enableRecentTeleportIndicator = true,
	recentTeleportGreenMin = 5,
	recentTeleportGrayMin  = 15,
	recentTeleportClearOnLeave = true,
	recentTeleportGreenColor  = { r = 0.2,    g = 0.8,    b = 0.2 },
	recentTeleportYellowColor = { r = 0.8,    g = 0.8,    b = 0.2 },
	recentTeleportGrayColor   = { r = 0.4667, g = 0.4667, b = 0.4667 },
}

function Wayfinder.InitSettings()
	Wayfinder.SV = ZO_SavedVars:NewAccountWide("WayfinderSV", 1, nil, Wayfinder.Defaults, GetWorldName())

	local LAM = LibAddonMenu2
	if not LAM then return end

	local panelData = {
		type               = "panel",
		name               = "|cD9A441Wayfinder|r",
		displayName        = "|cD9A441Wayfinder|r",
		author             = "|cFF77CCKanashiReinkyatto|r",
		version            = "1.2.0",
		slashCommand       = "/wayfinder",
		registerForRefresh = true,
	}
	LAM:RegisterAddonPanel("WayfinderPanel", panelData)

	local optionsData = {
		{
			type = "header",
			name = "Map",
		},
		{
			type    = "checkbox",
			name    = "Open delve/public dungeon maps from pins",
			tooltip = "Adds an Open Map option (or a floor switcher for multi-level delves/public dungeons) when clicking a public dungeon or delve pin on the world map",
			getFunc = function() return Wayfinder.SV.enableOpenMap end,
			setFunc = function(v) Wayfinder.SV.enableOpenMap = v end,
		},
		{
			type    = "checkbox",
			name    = "Players inside delves/dungeons on hover/click",
			tooltip = "Show who's already inside a delve/public dungeon on hover, and allow teleporting in to them by clicking the pin",
			getFunc = function() return Wayfinder.SV.enableNearbyPlayers end,
			setFunc = function(v) Wayfinder.SV.enableNearbyPlayers = v end,
		},
		{
			type    = "submenu",
			name    = "Players in Zone",
			tooltip = "The map button that shows and teleports to friends/guild/group members.",
			controls = {
				{
					type    = "checkbox",
					name    = "Show button",
					tooltip = "Show a button on the world map for teleporting to group members, friends, and guildmates.",
					getFunc = function() return Wayfinder.SV.enableMapButton end,
					setFunc = function(v)
						Wayfinder.SV.enableMapButton = v
						if Wayfinder.RefreshMapButton then Wayfinder.RefreshMapButton() end
					end,
				},
				{
					type    = "slider",
					name    = "Update interval (seconds)",
					tooltip = "How often the addon rescans your group/friends/guilds for this list, including while hovering pins on the map. Lowering this value can affect performance on lower-end systems.",
					min     = 1,
					max     = 30,
					step    = 1,
					getFunc = function() return Wayfinder.SV.mapButtonPollIntervalSec end,
					setFunc = function(v) Wayfinder.SV.mapButtonPollIntervalSec = v end,
				},
				{
					type    = "checkbox",
					name    = "Lock UI",
					tooltip = "When unlocked, a drag handle appears next to the map button so you can reposition it",
					getFunc = function() return Wayfinder.SV.lockMapButton end,
					setFunc = function(v)
						Wayfinder.SV.lockMapButton = v
						if Wayfinder.RefreshMapButton then Wayfinder.RefreshMapButton() end
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton end,
				},
				{
					type = "header",
					name = "Teleport Indicator",
				},
				{
					type    = "checkbox",
					name    = "Show indicator",
					tooltip = "Show a colored dot next to each player indicating how recently you teleported to them in this zone.",
					getFunc = function() return Wayfinder.SV.enableRecentTeleportIndicator end,
					setFunc = function(v) Wayfinder.SV.enableRecentTeleportIndicator = v end,
					disabled = function() return not Wayfinder.SV.enableMapButton end,
				},
				{
					type = "header",
					name = "Recent teleports",
				},
				{
					type    = "slider",
					name    = "Ends after (minutes)",
					tooltip = "How long a teleport remains \"recent\" before changing to the \"Older\" indicator. Can't be set at or above \"Older teleports\" below - that one gets pushed up automatically to keep it valid.",
					min     = 1,
					max     = 30,
					step    = 1,
					getFunc = function() return Wayfinder.SV.recentTeleportGreenMin end,
					setFunc = function(v)
						Wayfinder.SV.recentTeleportGreenMin = v
						if Wayfinder.SV.recentTeleportGrayMin <= v then
							Wayfinder.SV.recentTeleportGrayMin = v + 1
						end
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
				{
					type    = "colorpicker",
					name    = "Color",
					tooltip = "Dot color for a recent teleport.",
					getFunc = function()
						local c = Wayfinder.SV.recentTeleportGreenColor
						return c.r, c.g, c.b
					end,
					setFunc = function(r, g, b)
						Wayfinder.SV.recentTeleportGreenColor = { r = r, g = g, b = b }
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
				{
					type = "header",
					name = "Older teleports",
				},
				{
					type    = "slider",
					name    = "Ends after (minutes)",
					tooltip = "How long a teleport remains \"older\" before changing to the \"Oldest\" indicator. Can't be set at or below \"Recent teleports\" above - won't go lower than that plus one minute.",
					min     = 1,
					max     = 60,
					step    = 1,
					getFunc = function() return Wayfinder.SV.recentTeleportGrayMin end,
					setFunc = function(v)
						local minAllowed = Wayfinder.SV.recentTeleportGreenMin + 1
						Wayfinder.SV.recentTeleportGrayMin = zo_max(v, minAllowed)
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
				{
					type    = "colorpicker",
					name    = "Color",
					tooltip = "Dot color for an older teleport.",
					getFunc = function()
						local c = Wayfinder.SV.recentTeleportYellowColor
						return c.r, c.g, c.b
					end,
					setFunc = function(r, g, b)
						Wayfinder.SV.recentTeleportYellowColor = { r = r, g = g, b = b }
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
				{
					type = "header",
					name = "Oldest teleports",
				},
				{
					type    = "colorpicker",
					name    = "Color",
					tooltip = "Dot color used after the \"Older\" time limit, or if you've never teleported to that player.",
					getFunc = function()
						local c = Wayfinder.SV.recentTeleportGrayColor
						return c.r, c.g, c.b
					end,
					setFunc = function(r, g, b)
						Wayfinder.SV.recentTeleportGrayColor = { r = r, g = g, b = b }
					end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
				{
					type    = "checkbox",
					name    = "Reset indicator when player leaves the zone",
					tooltip = "Removes a player from the \"recently teleported\" list as soon as they're no longer seen in that zone, instead of keeping the dot until it ages out on its own. Can help if you're using this feature to look for new instances of a specific location, since it won't hold onto a stale \"already visited\" mark for someone who's moved on.",
					getFunc = function() return Wayfinder.SV.recentTeleportClearOnLeave end,
					setFunc = function(v) Wayfinder.SV.recentTeleportClearOnLeave = v end,
					disabled = function() return not Wayfinder.SV.enableMapButton or not Wayfinder.SV.enableRecentTeleportIndicator end,
				},
			},
		},
		{
			type = "header",
			name = "Chat",
		},
		{
			type    = "checkbox",
			name    = "Travel to Player (right-click menu)",
			tooltip = "Show 'Travel to Player' option when right-clicking a player name in chat",
			getFunc = function() return Wayfinder.SV.enableTravelMenu end,
			setFunc = function(v) Wayfinder.SV.enableTravelMenu = v end,
		},
	}

	LAM:RegisterOptionControls("WayfinderPanel", optionsData)
end
