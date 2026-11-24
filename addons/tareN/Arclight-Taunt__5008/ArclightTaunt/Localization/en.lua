-- Canonical English language source for all A.T("English text") calls.
-- Call-site strings are stable keys and the default English text.
-- Refined English text can keep using the same translation keys.
-- The other language files contain display translations only.
local A = ArclightTaunt
A.translations = A.translations or {}
A.translations.en = {
    ["Welcome! Set up your HUD: ESC > Settings > Add-ons > Arclight Taunt."] = "Welcome! Open ESC > Settings > Add-ons > Arclight Taunt. Use Show preview in Quick settings to try the taunt list.",
    ["Highlights your current tracked target. Choose Subtle or Strong under Appearance & readability."] = "Highlights the tracked enemy you are aiming at. Choose Subtle or Strong under Appearance & text.",
    ["more (one)"] = "more",
    ["Freezes preview timers and arrivals. Resume without restarting; ending preview clears pause."] = "Pauses the timers and stops new enemies from appearing in the preview. Resume to pick up where you left off.",
    ["Shows a varied combat preview of the taunt list. Pause it to adjust your setup."] = "Shows sample taunts. To try banners and sounds, choose Test warning under Boss warnings.",
    ["Locked by default. Unlock to drag visible displays; previews and combat tracking keep running."] = "Outside combat, start the relevant preview. Unlock the position, then drag the display.",
    ["Reset only the HUD position to its default."] = "Restores the taunt list’s default position.",
    ["Shows last observed ESO target markers beside names. Updates use direct identification or an unambiguous own taunt. Boss skulls stay separate; Arclight never places markers."] = "Shows the last seen ESO target marker beside each name. Looking at an enemy again can update its marker if Arclight can reliably identify it. Boss skulls are separate.",
    ["Your confirmed taunt on the aimed enemy as a draining circle or bar, without numbers."] = "Shows time left on your confirmed taunt against the enemy under the crosshair. The circle or bar empties as the taunt expires.",
    ["Runs early, expiry, then both with enabled sounds. Click again to stop. Real warnings take priority."] = "Shows the expiry banner even if it’s off in combat. Early warnings and sounds follow your settings. Click again to stop.",
    ["Default: Duel boundary warning. The test plays it if early audio is enabled and no real expiration warning has priority."] = "Defaults to Duel boundary warning. The warning test plays your selected sound if early warning audio is on and no real expiry warning takes priority.",
    ["Narrow bars: Signature (default), segmented Signal or Flat. More via LibMediaProvider. High contrast uses Signature without changing your selection."] = "Choose a texture for narrow bars. Arclight (Signatur) is the default. LibMediaProvider can add more choices. High contrast uses Signatur while keeping your selection.",
    ["Banner on boss taunt expiry. Default: on. No alert after a re-taunt or combat end."] = "Shows a banner when a boss taunt expires. Refreshing the taunt or ending combat clears its warning. Enabled by default.",
    ["Early warning before boss taunt expiry, below the expiration banner when needed. Clears on expiry, re-taunt or recognized death. Default: on; audio optional."] = "Warns before a boss taunt expires. It appears below any active expiry banner and clears when the taunt expires, you refresh it or ESO confirms the target’s death. Enabled by default, with optional sound.",
    ["Removes each enemy by its ID when ESO reports death. Some deaths are not reported; combat end clears remaining entries."] = "Removes an enemy as soon as ESO reports its death. Any remaining entries clear when combat ends.",
    ["Pins highlighted bosses and strong enemies above other targets, expired first. Active entries sort by time. Default: off."] = "Moves enemies selected by boss detection to the top. Expired taunts in that group appear first, followed by active taunts in order of time left. Off by default.",
    ["Opacity of the empty circle or bar track. Countdown fill and light edge stay unchanged."] = "Adjusts the background behind the circle or bar. The moving fill and its light edge keep their opacity.",
    ["Row spacing; target focus reserves at least 2 px without changing this setting. Default: 2 px."] = "Sets the gap between rows. The target outline leaves at least 2 pixels of clearance. The default gap is 2 pixels.",
    ["Sound on expiry, early warning, both or off. Early audio requires early warnings. Expiration has priority; cooldowns are separate."] = "Choose when to play a sound. Early sounds require early warnings. Expiry sounds take priority, and each warning has its own interval between sounds.",
}
-- Compatibility labels for identifiers saved by previous German-based builds.
-- Do not change these keys: existing user selections must survive updates.
A.legacyLabels = {
    ["Allgemeiner Alarm"] = "General alarm",
    ["Countdown-Warnung"] = "Countdown warning",
    ["Duell-Grenzwarnung"] = "Duel boundary warning",
    ["Entdeckt"] = "Detected",
    ["Fähigkeit fehlgeschlagen"] = "Ability failed",
    ["Gesucht"] = "Wanted",
    ["Ohne Textur"] = "No texture",
    ["Prüfung gescheitert"] = "Trial failed",
    ["Questschritt gescheitert"] = "Quest step failed",
    ["Rüstung beschädigt"] = "Armor damaged",
    ["Todesstoß"] = "Killing blow",
    ["Wie Gegnername"] = "Same as enemy name",
}
