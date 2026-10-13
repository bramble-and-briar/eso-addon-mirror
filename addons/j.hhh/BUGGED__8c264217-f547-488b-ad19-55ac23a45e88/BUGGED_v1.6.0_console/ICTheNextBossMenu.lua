function ICT.initializeSettingsMenu()

	local defaults = {
		timetable = true,
		timetableTop = 0,
		timetableLeft = 0,
        timetableScale = 1.8,
        panelMover = false,
        bossRespawnTimes = {},
		maptimers = false,
		telvarTarget = 0,
		autoBankTelVar = true,
		groupSync = false,
		chatdebug = false,
	}

	local panelData = {
		type = "panel",
		name = "IC Helper by JH",
		displayName = "IC Helper by JH",
		author = "j.hhh",
		version = ICT.version,
	}
	
	local optionsData = {
		{
			type = "description",
			text = GetString(SI_ICTHENEXTBOSS_OPTION_DESCRIPTION)
		},
		{
			type = "divider",
		},
		{
			type = "checkbox",
			name = GetString(SI_ICTHENEXTBOSS_OPTION_TIMETABLE),
			getFunc = function() return ICT.savedVariables.timetable end,
			setFunc = function(value)
						ICT.savedVariables.timetable = value
						if value == true then
							HUD_SCENE:AddFragment(ICT.ui.timetable)
							HUD_UI_SCENE:AddFragment(ICT.ui.timetable)
							ICTTimeTable:SetHidden(false)
						else
							ICTTimeTable:SetHidden(true)
							HUD_SCENE:RemoveFragment(ICT.ui.timetable)
							HUD_UI_SCENE:RemoveFragment(ICT.ui.timetable)
						end
					  end,
			width = "full"
		},
		{
			type = "checkbox",
			name = GetString(SI_ICTHENEXTBOSS_OPTION_MAPTIMERS),
			tooltip = GetString(SI_ICTHENEXTBOSS_OPTION_MAPTIMERS_TOOLTIP),
			getFunc = function() return ICT.savedVariables.maptimers end,
			setFunc = function(value) ICT.savedVariables.maptimers = value end,
			width = "full",
		},
        {
            type = "header",
            name = "Boss-Panel / Gruppensichtungen",
        },
        {
            type = "checkbox",
            name = "Boss-Panel verschieben (Mausmodus)",
            tooltip = "Erlaubt das Ziehen des Panels mit der Maus. Auf PlayStation das Panel ueber die X/Y-Regler verschieben.",
            getFunc = function() return ICT.savedVariables.panelMover end,
            setFunc = function(value)
                ICT.savedVariables.panelMover = value
                ICT.setPanelMover(value)
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Boss-Panel Skalierung (%)",
            tooltip = "Groesse der Boss-Anzeige von 50 bis 400 Prozent.",
            min = 50, max = 400, step = 10,
            getFunc = function() return math.floor((ICT.savedVariables.timetableScale or 1) * 100 + 0.5) end,
            setFunc = function(value)
                ICT.savedVariables.timetableScale = value / 100
                ICT.applyPanelScale()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Boss-Panel X (Pixel)",
            min = 0, max = 3840, step = 10,
            getFunc = function() return ICT.savedVariables.timetableLeft end,
            setFunc = function(value)
                ICT.savedVariables.timetableLeft = math.floor(value)
                ICT.restoreUIPosition()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Boss-Panel Y (Pixel)",
            min = 0, max = 2160, step = 10,
            getFunc = function() return ICT.savedVariables.timetableTop end,
            setFunc = function(value)
                ICT.savedVariables.timetableTop = math.floor(value)
                ICT.restoreUIPosition()
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Panel-Position und Skalierung zuruecksetzen",
            func = function()
                ICT.savedVariables.timetableLeft = 0
                ICT.savedVariables.timetableTop = 0
                ICT.savedVariables.timetableScale = 1.8
                ICT.applyPanelScale()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Timer zuruecksetzen",
            tooltip = "Loescht alle gespeicherten Boss-Respawnzeiten. Danach zeigen alle Bezirke unknown, bis neue Boss-Ereignisse erkannt werden. Der Schalter springt automatisch zurueck.",
            getFunc = function() return false end,
            setFunc = function(value)
                if value then ICT.resetStoredBossTimers() end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Boss-Sichtungen mit Gruppe teilen (experimentell)",
            tooltip = "Erfordert LibGroupBroadcast und dieselbe Addon-Version bei den Gruppenmitgliedern. Beobachtungen gelten 45 Sekunden. Protokoll-ID muss vor Veroeffentlichung reserviert werden.",
            disabled = function() return not ICT.groupProtocolId end,
            getFunc = function() return ICT.savedVariables.groupSync end,
            setFunc = function(value) ICT.savedVariables.groupSync = value end,
            width = "full",
        },
		{
			type = "header",
			name = "Tel Var - Automatische Bank",
		},
		{
			type = "checkbox",
			name = "Tel Var beim Oeffnen der Bank abgleichen",
			tooltip = "Zahlt Tel Var ein oder hebt sie ab, bis du den gewuenschten Betrag bei dir hast. Funktioniert nur an einer Bank.",
			getFunc = function() return ICT.savedVariables.autoBankTelVar end,
			setFunc = function(value) ICT.savedVariables.autoBankTelVar = value end,
			width = "full",
		},
		{
			type = "slider",
			name = "Tel Var bei sich behalten",
			tooltip = "Zielwert fuer die getragenen Tel Var. Ueberschuss wird eingezahlt, fehlender Betrag wird soweit moeglich abgehoben.",
			min = 0,
			max = 10000,
			step = 1000,
			getFunc = function() return math.min(10000, math.max(0, math.floor((tonumber(ICT.savedVariables.telvarTarget) or 0) / 1000 + 0.5) * 1000)) end,
			setFunc = function(value) ICT.savedVariables.telvarTarget = math.min(10000, math.max(0, math.floor(value / 1000 + 0.5) * 1000)) end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Debug",
			getFunc = function() return ICT.savedVariables.chatdebug end,
			setFunc = function(value) ICT.savedVariables.chatdebug = value end,
			width = "full",
		},
	}

	ICT.savedVariables = ZO_SavedVars:NewAccountWide("ICTSV", 1, nil, defaults)
	LibAddonMenu2:RegisterAddonPanel("ICTSCombined", panelData)
	LibAddonMenu2:RegisterOptionControls("ICTSCombined", optionsData)
end