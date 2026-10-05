ElmsMarkers = ElmsMarkers or { }

function ElmsMarkers.buildMenu()
	local panelData = {
		type = "panel",
		name = "Elms Markers",
		displayName = "Elms Markers",
		author = "bitrock",
		version = ""..ElmsMarkers.version,
		registerForDefaults = true,
		registerForRefresh = true
	}

	local options = {
		{
			type = "header",
			name = "Settings",
		},
		{
			type = "checkbox",
			name = "Enabled",
			tooltip = "Toggles the UI",
			default = ElmsMarkers.defaults.enabled,
			getFunc = function() 
				return ElmsMarkers.savedVars.enabled
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.enabled = value
				ElmsMarkers.CheckActivation()
			end,
		},
		{
			type = "button",
			name = "Clear Zone",
			tooltip = "This will clear all markers from this zone",
			isDangerous = true,
			func = function(value)
				ElmsMarkers.ClearZone()
			end,
		},
		{
			type = "slider",
			name = "Icon size",
			min = 12,
			max = 192,
			default = ElmsMarkers.defaults.selectedIconSize,
			getFunc = function() 
				return ElmsMarkers.savedVars.selectedIconSize
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.selectedIconSize = value
				ElmsMarkers.CheckActivation()
			end,
		},
		{
			type = "header",
			name = "Group Markers",
		},
		{
			type = "checkbox",
			name = "Subscribe to Group Lead Markers",
			tooltip = "If the Group Lead elects to post a marker to members, this will allow you to opt in to receive the markers automatically as well",
			default = ElmsMarkers.defaults.subscribeToLead,
			getFunc = function() 
				return ElmsMarkers.savedVars.subscribeToLead
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.subscribeToLead = value
				ElmsMarkers.CheckActivation()
			end,
		},
		{
			type = "checkbox",
			name = "Allow Adding Markers from Group Lead",
			tooltip = "Allows the Group Lead to add single markers to your map. Only works while 'Subscribe to Group Lead Markers' is enabled.",
			default = ElmsMarkers.defaults.allowMarkerAdd,
			getFunc = function()
				return ElmsMarkers.savedVars.allowMarkerAdd
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.allowMarkerAdd = value
			end,
		},
		{
			type = "checkbox",
			name = "Allow Removing Markers from Group Lead",
			tooltip = "Allows the Group Lead to remove single markers from your map. Only works while 'Subscribe to Group Lead Markers' is enabled.",
			default = ElmsMarkers.defaults.allowMarkerRemove,
			getFunc = function()
				return ElmsMarkers.savedVars.allowMarkerRemove
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.allowMarkerRemove = value
			end,
		},
		{
			type = "checkbox",
			name = "Subscribe to Group Lead Alerts",
			tooltip = "If the Group Lead elects to publish a rendezvous, this will allow you to opt in to receive the commands as well",
			default = ElmsMarkers.defaults.optIntoCommands,
			getFunc = function()
				return ElmsMarkers.savedVars.optIntoCommands
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.optIntoCommands = value
			end,
		},
		{
			type = "button",
			name = "Share Zone Markers",
			tooltip = "Sends all markers of your current zone to the group. Only works if you are the group leader.",
			func = function(value)
				ElmsMarkers.ShareZoneMarkers()
			end,
			width = "half",
		},
		{
			type = "button",
			name = ElmsMarkers.savedVars.locked and "Reposition UI" or "Lock UI",
			tooltip = "Toggle the ability to reposition UI elements of this addon",
			func = function(value)
				ElmsMarkers.UnlockUI(ElmsMarkers.savedVars.locked)
					 if not ElmsMarkers.savedVars.locked then
								value:SetText("Lock UI")
					 else
								value:SetText("Reposition UI")
					 end
			end,
			width = "half",
		},
		{
			type = "slider",
			name = "Alert Size",
			tooltip = "Sets the Alert Message Size (Use the button above to see the size!)",
			getFunc = function() 
				return ElmsMarkers.savedVars.announcementScale
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.announcementScale = value
				ElmsMarkers.SetScale(ElmsMarkers.UI.announcementBannerLabel, value)
			end,
			min = 0.1,
			max = 2,
			step = 0.1,
			default = ElmsMarkers.defaults.announcementScale,
			width = "full",
 		},
		{
			type = "header",
			name = " Import",
		},
		{
			type = "editbox",
			name = "Config",
			tooltip = "Insert a valid ElmsMarkers string to import new icons into your zone",
			default = ElmsMarkers.defaults.configStringImport,
			isMultiline = true,
			isExtraWide = true,
			getFunc = function() 
				return ElmsMarkers.savedVars.configStringImport
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.configStringImport = value
			end,
		},
		{
			type = "button",
			name = "Import",
			tooltip = "Import a config string for this zone",
			func = function(value)
				ElmsMarkers.ParseImportConfigString()
			end,
		},
		{
			type = "header",
			name = " Export String",
		},
		{
			type = "editbox",
			name = "Config",
			tooltip = "String that describes the icons you have configured to this zone",
			default = ElmsMarkers.defaults.configStringExport,
			isMultiline = true,
			isExtraWide = true,
			getFunc = function() 
				return ElmsMarkers.savedVars.configStringExport
			end,
			setFunc = function(value)
			end,
		},
	}

	LibAddonMenu2:RegisterAddonPanel(ElmsMarkers.name.."Options", panelData)
	LibAddonMenu2:RegisterOptionControls(ElmsMarkers.name.."Options", options)
end

