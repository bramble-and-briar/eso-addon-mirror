function ALF.outputInitMessage()
  ALF.msgGold( ALF.NAME .. " v" .. ALF.VERSION .. " initialized." )
end

function ALF.msgGold( text )
    -- d("|c" .. ALF.COLOR_GOLD .. text .. "|r")
end

function ALF.onAddonLoad(eventCode, name)

	if name ~= ALF.NAME then return end
	ALF.savedVars = ZO_SavedVars:NewAccountWide(ALF.VARIABLES, 1, nil, nil, GetWorldName(), nil)
	AwesomeGuildStore:RegisterCallback( AwesomeGuildStore.callback.AFTER_FILTER_SETUP, function() ALF.initAGS() end)
	EVENT_MANAGER:UnregisterForEvent(ALF.NAME, EVENT_ADD_ON_LOADED)

	zo_callLater( ALF.outputInitMessage, 1000 )
end


EVENT_MANAGER:RegisterForEvent(ALF.NAME, EVENT_ADD_ON_LOADED, ALF.onAddonLoad)
