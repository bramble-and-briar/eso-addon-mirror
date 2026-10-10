AUI.Settings.Minimap = {}

local AUI_MINIMAP_MIN_SIZE = 120
local AUI_MINIMAP_MAX_SIZE = 600
local AUI_MINIMAP_MIN_ALPHA = 0.125
local AUI_MINIMAP_MAX_ALPHA = 1
local AUI_MINIMAP_MIN_PIN_SCALE = 0.5
local AUI_MINIMAP_MAX_PIN_SCALE = 1.5
local AUI_MINIMAP_MIN_PLAYER_PIN_SCALE = 0.5
local AUI_MINIMAP_MAX_PLAYER_PIN_SCALE = 1.5
local AUI_MINIMAP_MIN_GROUP_PIN_SCALE = 0.5
local AUI_MINIMAP_MAX_GROUP_PIN_SCALE = 1.5
local AUI_MINIMAP_MIN_GROUP_LEADER_PIN_SCALE = 0.5
local AUI_MINIMAP_MAX_GROUP_LEADER_PIN_SCALE = 1.5
local AUI_MINIMAP_MIN_FONT_SIZE_LOCATION = 14
local AUI_MINIMAP_MAX_FONT_SIZE_LOCATION = 30
local AUI_MINIMAP_MIN_FONT_SIZE_COORD = 12
local AUI_MINIMAP_MAX_FONT_SIZE_COORD = 30
local originalPinData = AUI.Table.Copy(ZO_MapPin.PIN_DATA)

local g_LAM = LibAddonMenu2
local g_isInit = false
local g_isPreviewShowing = false

local function GetDefaultSettings()
	local defaultSettings =
	{
		enable = true,
		width = 280,
		height= 280, 
		anchor = 
		{
			point = 9,
			relativePoint = 9,
			offsetX = 0,
			offsetY = 0
		},
		["zoom"] = 
		{
			["zone"] = 5,
			["subzone"] = 2,
			["dungeon"] = 1.5,
			["arena"] = 1
	    },
		opacity= 1, 
		showGroupMemberStatus = true,
		pin_player_color = {["r"] = 0.164706,["g"] = 0.741176,["b"] = 1,["a"] = 1},		
		pin_group_leader_normal_color = {["r"] = 1,["g"] = 0.941176,["b"] = 0,["a"] = 1},	
		pin_group_leader_combat_color = {["r"] = 1,["g"] = 0.941176,["b"] = 0,["a"] = 1},	
		pin_group_leader_dead_color = {["r"] = 0.670588,["g"] = 0.670588,["b"] = 0.670588,["a"] = 1},	
		pin_group_leader_friend_normal_color = {["r"] = 1,["g"] = 0.101961,["b"] = 0,["a"] = 1},	
		pin_group_leader_friend_combat_color = {["r"] = 1,["g"] = 0.101961,["b"] = 0,["a"] = 1},	
		pin_group_leader_friend_dead_color = {["r"] = 0.658824,["g"] = 0.709804,["b"] = 1,["a"] = 1},			
		pin_group_member_normal_color = {["r"] = 0.313725,["g"] = 0.313726,["b"] = 1,["a"] = 1},
		pin_group_member_combat_color = {["r"] = 0.313725,["g"] = 0.313726,["b"] = 1,["a"] = 1},
		pin_group_member_dead_color = {["r"] = 0.670588,["g"] = 0.670588,["b"] = 0.670588,["a"] = 1},	
		pin_group_member_friend_normal_color = {["r"] = 0,["g"] = 0.835294,["b"] = 0,["a"] = 1},
		pin_group_member_friend_combat_color = {["r"] = 0,["g"] = 0.835294,["b"] = 0,["a"] = 1},		
		pin_group_member_friend_dead_color = {["r"] = 0.658824,["g"] = 0.709804,["b"] = 1,["a"] = 1},
		pin_quest_zone_color = {["r"] = 0.9294117689,["g"] = 0.6705882549,["b"] = 1,["a"] = 1},
		pin_quest_holiday_color = {["r"] = 1,["g"] = 0.8627451062,["b"] = 0,["a"] = 1},
		pin_quest_normal_color = {["r"] = 0,["g"] = 1,["b"] = 0.5882353187,["a"] = 1},
		pin_quest_mainstory_color = {["r"] = 1.0000000591,["g"] = 0.4509804188,["b"] = 0.3411764908,["a"] = 1},	
		pin_quest_daily_color = {["r"] = 0.4117647111,["g"] = 0.8235294223,["b"] = 1,["a"] = 1},
		pin_quest_repeatable_color = {["r"] = 1.0000000591,["g"] = 0.8784314245,["b"] = 0.5686274846,["a"] = 1},			
		pin_size = 0.750000,
		player_pin_size = 0.875000,
		groupLeader_pin_size = 1.000000,
		group_pin_size = 0.750000,
		theme = "default",
		preview_locationName = true,
		location_FontSize = 20, 
		location_FontColor = {["r"] = 1,["g"] = 0.83,["b"] = 0.6,["a"] = 1}, 
		location_fontArt = "esoui/common/fonts/myingheiprc-w5.slug",
		location_FontStyle = "thick-outline",
		location_Position = "bottom",
		preview_coords = false,
		coords_FontSize = 16, 
		coords_FontColor = {["r"] = 1,["g"] = 0.83,["b"] = 0.6,["a"] = 1}, 
		coords_fontArt = "esoui/common/fonts/myingheiprc-w5.slug",
		coords_FontStyle = "thick-outline",
		coords_Position = "top",
		rotate = false,
		hide_in_combat = false,
		lock_window = false,
	}

	return defaultSettings
end

function CreateOptions()
	local optionsTable = 
	{
		{
			type = "header",
			name = AUI_TXT_COLOR_HEADER:Colorize(AUI.L10n.GetString("general"))
		},
		{
			type = "checkbox",
			name = AUI.L10n.GetString("acount_wide"),
			tooltip = AUI.L10n.GetString("acount_wide_tooltip"),
			getFunc = function() return AUI.Settings.MainMenu.modul_minimap_account_wide end,
			setFunc = function(value)
				if value ~= nil then
					if value ~= AUI.Settings.MainMenu.modul_minimap_account_wide then
						AUI.Settings.MainMenu.modul_minimap_account_wide = value
						ReloadUI()
					else
						AUI.Settings.MainMenu.modul_minimap_account_wide = value
					end						
				end
			end,
			default = true,
			width = "full",
			warning = AUI.L10n.GetString("reloadui_warning_tooltip"),
		},			
		{
			type = "checkbox",
			name = AUI.L10n.GetString("preview"),
			tooltip = AUI.L10n.GetString("preview_tooltip"),
			getFunc = function() return g_isPreviewShowing end,
			setFunc = function(value)
				if value ~= nil then
					if value == true then
						AUI.Minimap.Show()
					else
						AUI.Minimap.Hide()
					end
					
					g_isPreviewShowing = value
				end
			end,
			default = g_isPreviewShowing,
			width = "full",
		},		
		{
			type = "checkbox",
			name = AUI.L10n.GetString("lock_window"),
			tooltip = AUI.L10n.GetString("lock_window_tooltip"),
			getFunc = function() return AUI.Settings.Minimap.lock_window end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.lock_window = value
				end
			end,
			default = GetDefaultSettings().lock_window,
			width = "full",
		},		
		{
			type = "slider",
			name = AUI.L10n.GetString("width"),
			tooltip = AUI.L10n.GetString("width_tooltip"),
			min = AUI_MINIMAP_MIN_SIZE,
			max = AUI_MINIMAP_MAX_SIZE,
			step = 2,
			getFunc = function() return AUI.Settings.Minimap.width end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Minimap.width = value
					AUI.Minimap.UI.Update()
					AUI.Minimap.Refresh()
					AUI.Minimap.Pin.RefreshPins()
				end
			end,
			default = GetDefaultSettings().width,
			width = "half",			
		},	
		{
			type = "slider",
			name = AUI.L10n.GetString("height"),
			tooltip = AUI.L10n.GetString("height_tooltip"),
			min = AUI_MINIMAP_MIN_SIZE,
			max = AUI_MINIMAP_MAX_SIZE,
			step = 2,
			getFunc = function() return AUI.Settings.Minimap.height end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Minimap.height = value
					AUI.Minimap.UI.Update()
					AUI.Minimap.Refresh()
					AUI.Minimap.Pin.RefreshPins()
				end
			end,
			default = GetDefaultSettings().height,
			width = "half",			
		},	
		{
			type = "slider",
			name = AUI.L10n.GetString("opacity"),
			tooltip = AUI.L10n.GetString("opacity_tooltip"),
			min = AUI_MINIMAP_MIN_ALPHA,
			max = AUI_MINIMAP_MAX_ALPHA,
			step = 0.0625,
			getFunc = function() return AUI.Settings.Minimap.opacity end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.opacity = value
					AUI.Minimap.UI.Update()
				end
			end,
			default = GetDefaultSettings().opacity,
			width = "full",			
		},			
		{
			type = "slider",
			name = AUI.L10n.GetString("pin_size"),
			tooltip = AUI.L10n.GetString("pin_size_tooltip"),
			min = AUI_MINIMAP_MIN_PIN_SCALE,
			max = AUI_MINIMAP_MAX_PIN_SCALE,
			step = 0.0625,
			getFunc = function() return AUI.Settings.Minimap.pin_size end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Minimap.pin_size = value
					AUI.Minimap.Pin.RefreshPins()
				end
			end,
			default = GetDefaultSettings().pin_size,
			width = "full",			
		},
		{
			type = "slider",
			name = AUI.L10n.GetString("player_pin_size"),
			tooltip = AUI.L10n.GetString("player_pin_size_tooltip"),
			min = AUI_MINIMAP_MIN_PLAYER_PIN_SCALE,
			max = AUI_MINIMAP_MAX_PLAYER_PIN_SCALE,
			step = 0.0625,
			getFunc = function() return AUI.Settings.Minimap.player_pin_size end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Minimap.player_pin_size = value
					AUI.Minimap.Pin.RefreshPlayer()	
				end
			end,
			default = GetDefaultSettings().player_pin_size,
			width = "full",			
		},	
		{
			type = "slider",
			name = AUI.L10n.GetString("group_leader_pin_size"),
			tooltip = AUI.L10n.GetString("group_leader_pin_size_tooltip"),
			min = AUI_MINIMAP_MIN_GROUP_LEADER_PIN_SCALE,
			max = AUI_MINIMAP_MAX_GROUP_LEADER_PIN_SCALE,
			step = 0.0625,
			getFunc = function() return AUI.Settings.Minimap.groupLeader_pin_size end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.groupLeader_pin_size = value
					AUI.Minimap.Pin.RefreshPins()
				end
			end,
			default = GetDefaultSettings().groupLeader_pin_size,
			width = "full",			
		},		
		{
			type = "slider",
			name = AUI.L10n.GetString("group_member_pin_size"),
			tooltip = AUI.L10n.GetString("group_member_pin_size_tooltip"),
			min = AUI_MINIMAP_MIN_GROUP_PIN_SCALE,
			max = AUI_MINIMAP_MAX_GROUP_PIN_SCALE,
			step = 0.0625,
			getFunc = function() return AUI.Settings.Minimap.group_pin_size end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Minimap.group_pin_size = value
					AUI.Minimap.Pin.RefreshPins()
				end	
			end,
			default = GetDefaultSettings().group_pin_size,
			width = "full",			
		},	
		{
			type = "colorpicker",
			name = AUI.L10n.GetString("player_pin_color"),
			tooltip = AUI.L10n.GetString("player_pin_color_tooltip"),
			getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_player_color):UnpackRGBA() end,
			setFunc = function(r,g,b,a) 
				AUI.Settings.Minimap.pin_player_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
				AUI.Minimap.Pin.SetPinData()
				AUI.Minimap.Pin.RefreshPlayer()							
			end,
			default = GetDefaultSettings().pin_player_color,
			width = "full",
		},	
		{
			type = "checkbox",
			name = AUI.L10n.GetString("rotate"),
			tooltip = AUI.L10n.GetString("minimap_rotate_tooltip"),
			getFunc = function() return AUI.Settings.Minimap.rotate end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.rotate = value
					AUI.Minimap.Pin.RefreshPins()
					AUI.Minimap.Refresh()
				end
			end,
			default = GetDefaultSettings().rotate,
			width = "full",
			warning = AUI.L10n.GetString("minimap_rotate_warning"),
		},			
		{
			type = "checkbox",
			name = AUI.L10n.GetString("hide_in_combat"),
			tooltip = AUI.L10n.GetString("minimap_hide_in_combat_tooltip"),
			getFunc = function() return AUI.Settings.Minimap.hide_in_combat end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.hide_in_combat = value
				end
			end,
			default = GetDefaultSettings().hide_in_combat,
			width = "full",
		},	
		{
			type = "checkbox",
			name = AUI.L10n.GetString("show_group_member_status"),
			tooltip = AUI.L10n.GetString("show_group_member_status_tooltip"),
			getFunc = function() return AUI.Settings.Minimap.showGroupMemberStatus end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Minimap.showGroupMemberStatus = value
					AUI.Minimap.Pin.SetPinData()
					AUI.Minimap.Pin.RefreshGroupPins()
				end
			end,
			default = GetDefaultSettings().showGroupMemberStatus,
			width = "full",
		},					
		{		
			type = "submenu",
			name = AUI_TXT_COLOR_SUBMENU:Colorize(AUI.L10n.GetString("zoom")),
			controls = 
			{			
				{
					type = "slider",
					name = AUI.L10n.GetString("zone"),
					tooltip = AUI.L10n.GetString("zoom_zone_tooltip"),
					min = AUI_MINIMAP_MIN_ZOOM_ZONE,
					max = AUI_MINIMAP_MAX_ZOOM_ZONE,
					step = 0.0625,
					getFunc = function() return  AUI.Settings.Minimap.zoom["zone"] end,
					setFunc = function(value) 
						if value ~= nil then
							AUI.Settings.Minimap.zoom["zone"] = value								
							AUI.Minimap.Refresh()
						end
					end,
					default = GetDefaultSettings().zoom["zone"],
					width = "half",
				},		
				{
					type = "slider",
					name = AUI.L10n.GetString("subzone"),
					tooltip = AUI.L10n.GetString("zoom_subzone_tooltip"),
					min = AUI_MINIMAP_MIN_ZOOM_SUBZONE,
					max = AUI_MINIMAP_MAX_ZOOM_SUBZONE,
					step = 0.0625,
					getFunc = function() return AUI.Settings.Minimap.zoom["subzone"] end,
					setFunc = function(value)
						if value ~= nil then
							AUI.Settings.Minimap.zoom["subzone"] = value											
							AUI.Minimap.Refresh()
						end
					end,
					default = GetDefaultSettings().zoom["subzone"],
					width = "half",		
						
				},
				{
					type = "slider",
					name = AUI.L10n.GetString("dungeon"),
					tooltip = AUI.L10n.GetString("zoom_dungeon_tooltip"),
					min = AUI_MINIMAP_MIN_ZOOM_DUNGEON,
					max = AUI_MINIMAP_MAX_ZOOM_DUNGEON,
					step = 0.0625,
					getFunc = function() return AUI.Settings.Minimap.zoom["dungeon"] end,
					setFunc = function(value)
						if value ~= nil then
							AUI.Settings.Minimap.zoom["dungeon"] = value	
							AUI.Minimap.Refresh()
						end
					end,
					default = GetDefaultSettings().zoom["dungeon"],
					width = "half",	
				},
				{
					type = "slider",
					name = AUI.L10n.GetString("arena_pvp"),
					tooltip = AUI.L10n.GetString("zoom_arena_pvp_tooltip"),
					min = AUI_MINIMAP_MIN_ZOOM_ARENA,
					max = AUI_MINIMAP_MAX_ZOOM_ARENA,
					step = 0.0625,
					getFunc = function() return AUI.Settings.Minimap.zoom["arena"] end,
					setFunc = function(value) 
						if value ~= nil then
							AUI.Settings.Minimap.zoom["arena"] = value	
							AUI.Minimap.Refresh()
						end
					end,
					default = GetDefaultSettings().zoom["arena"],
					width = "half",	
				},				
			}
		},		
		{		
			type = "submenu",
			name = AUI_TXT_COLOR_SUBMENU:Colorize(AUI.L10n.GetString("text")),
			controls = 
			{			
				{
					type = "header",
					name = AUI.L10n.GetString("location_name")
				},
				{
					type = "checkbox",
					name = AUI.L10n.GetString("show"),
					tooltip = AUI.L10n.GetString("show_location_name_tooltip"),
					getFunc = function() return AUI.Settings.Minimap.preview_locationName end,
					setFunc = function(value)
						if value ~= nil then
							AUI.Settings.Minimap.preview_locationName = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = GetDefaultSettings().preview_locationName,
					width = "full",
				},		
				{
					type = "colorpicker",
					name =  AUI.L10n.GetString("font_color"),
					tooltip =  AUI.L10n.GetString("font_color_tooltip"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.location_FontColor):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.location_FontColor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.UI.Update()
					end,
					default = GetDefaultSettings().location_FontColor,
					width = "full",
				},
				{
					type = "slider",
					name = AUI.L10n.GetString("font_size"),
					tooltip = AUI.L10n.GetString("font_size_tooltip"),
					min = AUI_MINIMAP_MIN_FONT_SIZE_LOCATION ,
					max = AUI_MINIMAP_MAX_FONT_SIZE_LOCATION ,
					step = 1,
					getFunc = function() return AUI.Settings.Minimap.location_FontSize end,
					setFunc = function(value) 
						if value ~= nil then
							AUI.Settings.Minimap.location_FontSize = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = GetDefaultSettings().location_FontSize,
					width = "full",
				},		
				{
					type = "dropdown",
					name = AUI.L10n.GetString("font_art"),
					tooltip = AUI.L10n.GetString("font_art_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetFontTypeList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), AUI.Settings.Minimap.location_fontArt) end,
					setFunc = function(value) 	
						value = AUI.Table.GetKey(AUI.Menu.GetFontTypeList(), value)	
						if value ~= nil then
							AUI.Settings.Minimap.location_fontArt = value
							AUI.Minimap.UI.Update()
						end	
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), GetDefaultSettings().location_fontArt),
				},
				{
					type = "dropdown",
					name = AUI.L10n.GetString("font_style"),
					tooltip = AUI.L10n.GetString("font_style_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetFontStyleList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetFontStyleList(), AUI.Settings.Minimap.location_FontStyle) end,
					setFunc = function(value) 
						value = AUI.Table.GetKey(AUI.Menu.GetFontStyleList(), value)					
						if value ~= nil then
							AUI.Settings.Minimap.location_FontStyle = value
							AUI.Minimap.UI.Update()
						end	
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetFontStyleList(), GetDefaultSettings().location_FontStyle),
				},		
				{
					type = "dropdown",
					name = AUI.L10n.GetString("text_position"),
					tooltip = AUI.L10n.GetString("text_position_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetTopAndBottomList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetTopAndBottomList(), AUI.Settings.Minimap.location_Position) end,
					setFunc = function(value) 
						value = AUI.Table.GetKey(AUI.Menu.GetTopAndBottomList(), value)					
						if value ~= nil then
							AUI.Settings.Minimap.location_Position = value
							AUI.Minimap.UI.Update()
						end						
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetTopAndBottomList(), GetDefaultSettings().location_Position),					
				},
				{
					type = "header",
					name = AUI.L10n.GetString("coords")
				},				
				{
					type = "checkbox",
					name = AUI.L10n.GetString("show"),
					tooltip = AUI.L10n.GetString("show_player_coords_tooltip"),
					getFunc = function() return AUI.Settings.Minimap.preview_coords end,
					setFunc = function(value)
						if value ~= nil then
							AUI.Settings.Minimap.preview_coords = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = GetDefaultSettings().preview_coords,
					width = "full",
				},		
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("font_color"),
					tooltip = AUI.L10n.GetString("font_color_tooltip"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.coords_FontColor):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.coords_FontColor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.UI.Update()
					end,
					default = GetDefaultSettings().coords_FontColor,
					width = "full",
				},
				{
					type = "slider",
					name = AUI.L10n.GetString("font_size"),
					tooltip = AUI.L10n.GetString("font_size_tooltip"),
					min = AUI_MINIMAP_MIN_FONT_SIZE_COORD,
					max = AUI_MINIMAP_MAX_FONT_SIZE_COORD,
					step = 1,
					getFunc = function() return AUI.Settings.Minimap.coords_FontSize end,
					setFunc = function(value)
						if value ~= nil then
							AUI.Settings.Minimap.coords_FontSize = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = GetDefaultSettings().coords_FontSize,
					width = "full",
				},		
				{
					type = "dropdown",
					name = AUI.L10n.GetString("font_art"),
					tooltip = AUI.L10n.GetString("font_art_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetFontTypeList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), AUI.Settings.Minimap.coords_fontArt) end,
					setFunc = function(value) 		
						value = AUI.Table.GetKey(AUI.Menu.GetFontTypeList(), value)					
						if value ~= nil then
							AUI.Settings.Minimap.coords_fontArt = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), GetDefaultSettings().coords_fontArt),	
				},				
				{
					type = "dropdown",
					name = AUI.L10n.GetString("font_style"),
					tooltip = AUI.L10n.GetString("font_style_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetFontStyleList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetFontStyleList(), AUI.Settings.Minimap.coords_FontStyle) end,
					setFunc = function(value) 	
						value = AUI.Table.GetKey(AUI.Menu.GetFontStyleList(), value)					
						if value ~= nil then
							AUI.Settings.Minimap.coords_FontStyle = value
							AUI.Minimap.UI.Update()
						end
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetFontStyleList(), GetDefaultSettings().coords_FontStyle),						
				},		
				{
					type = "dropdown",
					name = AUI.L10n.GetString("text_position"),
					tooltip = AUI.L10n.GetString("text_position_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Menu.GetTopAndBottomList(), "value"),
					getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetTopAndBottomList(), AUI.Settings.Minimap.coords_Position) end,
					setFunc = function(value) 
						value = AUI.Table.GetKey(AUI.Menu.GetTopAndBottomList(), value)					
						if value ~= nil then
							AUI.Settings.Minimap.coords_Position = value
							AUI.Minimap.UI.Update()
						end					
					end,
					default = AUI.Table.GetValue(AUI.Menu.GetTopAndBottomList(), GetDefaultSettings().coords_Position),	
				},				
			}
		},
		{		
			type = "submenu",
			name = AUI_TXT_COLOR_SUBMENU:Colorize(AUI.L10n.GetString("pin_colors")),
			controls = 
			{			
				{
					type = "header",
					name = AUI.L10n.GetString("group_leader")
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("normal"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_normal_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_normal_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_normal_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("combat"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_combat_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_combat_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_combat_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("dead"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_dead_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_dead_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_dead_color,
					width = "full",
				},	
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("normal") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_friend_normal_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_friend_normal_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_friend_normal_color,
					width = "full",
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("combat") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_friend_combat_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_friend_combat_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_friend_combat_color,
					width = "full",
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("dead") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_leader_friend_dead_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_leader_friend_dead_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_leader_friend_dead_color,
					width = "full",
				},	
				{
					type = "header",
					name = AUI.L10n.GetString("group_members")
				},	
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("normal"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_normal_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_normal_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_normal_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("combat"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_combat_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_combat_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_combat_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("dead"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_dead_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_dead_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_dead_color,
					width = "full",
				},	
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("normal") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_friend_normal_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_friend_normal_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_friend_normal_color,
					width = "full",
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("combat") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_friend_combat_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_friend_combat_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_friend_combat_color,
					width = "full",
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("friend") .. " (" .. AUI.L10n.GetString("dead") .. ")",
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_group_member_friend_dead_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_group_member_friend_dead_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshGroupPins()
					end,
					default = GetDefaultSettings().pin_group_member_friend_dead_color,
					width = "full",
				},	
				{
					type = "header",
					name = AUI.L10n.GetString("quests")
				},					
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("normal"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_normal_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_normal_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_normal_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("zone"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_zone_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_zone_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_zone_color,
					width = "full",
				},
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("holiday"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_holiday_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_holiday_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_holiday_color,
					width = "full",
				},					
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("mainstory"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_mainstory_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_mainstory_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_mainstory_color,
					width = "full",
				},				
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("daily"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_daily_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_daily_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_daily_color,
					width = "full",
				},			
				{
					type = "colorpicker",
					name = AUI.L10n.GetString("repeatable"),
					getFunc = function() return AUI.Color.GetColorDefFromNamedRGBA(AUI.Settings.Minimap.pin_quest_repeatable_color):UnpackRGBA() end,
					setFunc = function(r,g,b,a) 
						AUI.Settings.Minimap.pin_quest_repeatable_color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
						AUI.Minimap.Pin.SetPinData()
						AUI.Minimap.Pin.RefreshPins()
					end,
					default = GetDefaultSettings().pin_quest_repeatable_color,
					width = "full",
				},						
			}
		},
		{		
			type = "submenu",
			name = AUI_TXT_COLOR_SUBMENU:Colorize(AUI.L10n.GetString("themes")),
			controls = 
			{			
				{
					type = "dropdown",
					name = AUI.L10n.GetString("template"),
					tooltip = AUI.L10n.GetString("template_tooltip"),
					choices = AUI.Table.GetChoiceList(AUI.Minimap.Theme.GetNameList(), "value"),
					getFunc = function() 
						return AUI.Table.GetValue(AUI.Minimap.Theme.GetNameList(), AUI.Settings.Minimap.theme)	
					end,
					setFunc = function(value) 
						if value ~= nil then
							value = AUI.Table.GetKey(AUI.Minimap.Theme.GetNameList(), value)
							if AUI.Settings.Minimap.theme ~= value then
								AUI.Settings.Minimap.theme = value
								AUI.Minimap.UI.Update()						
							end
						end							
					end,
					default = AUI.Table.GetValue(AUI.Minimap.Theme.GetNameList(), GetDefaultSettings().theme)
				},			
			}
		},
	}
	
	return optionsTable
end

function AUI.Minimap.LoadSettings()
	if g_isInit then
		return
	end
	
	g_isInit = true
	
	if AUI.Settings.MainMenu.modul_minimap_account_wide then
		AUI.Settings.Minimap = ZO_SavedVars:NewAccountWide("AUI_Minimap", 10, nil, GetDefaultSettings())
	else
		AUI.Settings.Minimap = ZO_SavedVars:New("AUI_Minimap", 10, nil, GetDefaultSettings())
	end	
	
	local panelData = 
	{
		type = "panel",
		name = AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("minimap_module_name") .. ")",
		displayName = "|cFFFFB0" .. AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("minimap_module_name") .. ")",
		author = AUI_TXT_COLOR_AUTHOR:Colorize(AUI_MINIMAP_AUTHOR),
		version = AUI_TXT_COLOR_VERSION:Colorize(AUI_MINIMAP_VERSION),
		slashCommand = "/auiminimap",
		registerForRefresh = true,
		registerForDefaults = true,
	}	
	
	g_LAM:RegisterOptionControls("AUI_Menu_Minimap", CreateOptions())
	g_LAM:RegisterAddonPanel("AUI_Menu_Minimap", panelData)
end
