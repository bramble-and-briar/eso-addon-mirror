EVENT_MANAGER:RegisterForEvent("HideAntiquariansEyePrompt", EVENT_PLAYER_ACTIVATED, function( )
	PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_PLAYER_IN_PIN_AREA_CHANGED) -- Disable the event that resets the decline state
	PLAYER_TO_PLAYER.digSiteEyeDeclined = true                                    -- Decline all future prompts
	PLAYER_TO_PLAYER:RemoveFromIncomingQueue(ZO_INTERACT_TYPE.DIG_SITE_EYE)       -- Dismiss any existing prompts
end, true)
