-- English localisation
-- luacheck: push ignore 631
local L = function(k, v)
    ZO_CreateStringId("ARCHIVEHELPER_" .. k, v)
end

L("ADD_AVOID", "Add to avoid list")
L("ALL_BOTH", "All verses and visions acquired")
L("ALL_VISIONS", "All visions acquired")
L("ALL_VERSES", "All verses acquired")
L("ARC_BOSS", "Tho'at Replicanum next")
L("AUDITOR", "Autosummon Loyal Auditor")
L("AUDITOR_NAME", "Loyal Auditor")
L("AVOID", "Avoid")
L("BONUS", "Bonus Levels")
L("BUFF_SELECTED", "<<1>> selected <<2>>")
L("COUNT", "<<1>> of <<2>>")
L("CROSSING_END", "End")
L("CROSSING_KEY", "<<1>> Turn Left - <<2>> Turn Right")
L(
    "CROSSING_INVALID",
    "The Crossing Helper can only be activated within the Treacherous Crossing in the Infinite Archive"
)
L("CROSSING_FAIL", "Locked") -- The Levers are Locked. No-one can cross
L("CROSSING_NO_SOLUTIONS", "No Paths Found")
L("CROSSING_PATHS", "Possible Paths")
L("CROSSING_SLASH", "helper")
L("CROSSING_START", "Start")
L("CROSSING_SUCCESS", "Solved") -- You Solved the Corridor Puzzle
L("CROSSING_TITLE", "Treacherous Crossing Helper")

L(
    "CROSSING_INSTRUCTIONS",
    "Find the switch corresponding to the start of the path and select it in the dropdown below (1 is the leftmost switch, 6 the rightmost)." ..
        " Then, if necessary, find the 2nd step or the end of the path, until only one solution remains."
)
L("CYCLE_BOSS", "Cycle boss next")
L("DEN_TIMER", "<<1[0s remaining/1s remaining/$ds remaining]>>")
L("FABLED", "Fabled")
L("FABLED_MARKER", "Add Target Markers to Fabled")
L(
    "FABLED_TOOLTIP",
    "This feature will not work with Lykeions Fabled Marker addon to avoid both addons trying to mark the same things."
)
L("FLAMESHAPER", "Flame-Shaper")
L("GW", "Gw the Pilferer")
L("GW_MARKER", "Add Target Marker to Gw the Pilferer")
L("GW_PLAY", "Play warning when Gw has been marked")
L("HERD", "Herd the Ghost Lights")
L("HERD_FAIL", "Enough") -- You Did Not Herd Enough Ghostlights
L("HERD_SUCCESS", "Returned") -- You Successfully Returned the Ghostlights
L("MARAUDER_MARKER", "Add Target Markers to Marauders")
L("MARAUDER_INCOMING_PLAY", "Play warning for incoming Marauders")
L("OPTIONAL_LIBS_CHAT", "Archive Helper works best with LibChatMessage installed.")
L("OPTIONAL_LIBS_SHARE", "For Duo mode to work effectively, please install LibDataShare.")
L("PREVENT", "Prevent accidental buff selection")
L("PREVENT_TOOLTIP", "Disables the buff selection briefly when the panel opens to prevent accidental selection.")
L("PROGRESS", "<<1>> criteria advanced. <<2>> remaining.")
L("PROGRESS_ACHIEVEMENT", "Achievement progress")
L("PROGRESS_CHAT", "Show in chat")
L("PROGRESS_SCREEN", "Announce on screen")
L("RANDOM", "<<1>> received <<2>>")
L("REMINDER", "Show boss reminder")
L("REMINDER_QUEST", "Show quest item reminder")
L("REMINDER_QUEST_TEXT", "Don't forget to pick up your quest item!")
L("REMINDER_TOOLTIP", "When selecting verses, show a reminder notice if the next stage is a boss.")
L("REMOVE_AVOID", "Remove from avoid list")
L("REQUIRES", "Requires LibChatMessage")
L("SECONDS", "s")
L("SHARD", "Tho'at Shard")
L("SHARD_IGNORE", "Ignore Shards outside cycle 5")
L("SHARD_MARKER", "Add Target Markers to Tho'at Shards")
L("SHOW_COUNT", "Show Tomeshell count in the Filer's Wing")
L("SHOW_CROSSING_HELPER", "Show Treacherous Crossing helper")
L(
    "SHOW_COUNT_TOOLTIP",
    "For Duo mode to work correctly, the other player must have this addon installed. Both players must also have LibDataShare installed."
)
L("SHOW_ECHO", "Show timer in the Echoing Den")
L("SHOW_SELECTION", "Show buff selection in group chat")
L("SHOW_SELECTION_DISPLAY_NAME", "Use display name")
L("SHOW_SELECTION_DISPLAY_NAME_TOOLTIP", "Use display name instead of character name")
L("SHOW_TERRAIN_WARNING", "Show warnings for terrain damage")
L("SHOW_THEATRE_WARNING", "Show warnings in the Theatre of War")
L("SLASH_MISSING", "missing")
L("STACKS", "Stack count")
L("TOMESHELL", "Tomeshell")
L("TOMESHELL_COUNT", "<<1[0 remaining/1 remaining/$d remaining]>>")
L("USE_AUTO_AVOID", "Use automatic avoids")
L("USE_AUTO_AVOID_TOOLTIP", "Automatically mark verses or visions that are of no use to you due to unslotted skills")
L("WARNING", "Warning: Dropdowns may not refresh without a UI reload")
L("WEREWOLF_BEHEMOTH", "Werewolf Behemoth")

-- keybinds
L("SI_BINDING_NAME_ARCHIVEHELPER_MARK_CURRENT_TARGET", "Mark Current Target")
L("SI_BINDING_NAME_ARCHIVEHELPER_TOGGLE_CROSSING_HELPER", "Toggle Crossing Helper")
L("SI_BINDING_NAME_ARCHIVEHELPER_UNMARK_CURRENT_TARGET", "Unmark Current Target")

-- Marauders
L("MARAUDER_GOTHMAU", "gothmau")
L("MARAUDER_HILKARAX", "hilkarax")
L("MARAUDER_ULMOR", "ulmor")
L("MARAUDER_BITTOG", "bittog")
L("MARAUDER_ZULFIMBUL", "zulfimbul")

-- Zones
L("MAP_TREACHEROUS_CROSSING", "Treacherous Crossing")
L("MAP_HAEFELS_BUTCHERY", "Haefel's Butchery")
L("MAP_FILERS_WING", "Filer's Wing")
L("MAP_ECHOING_DEN", "Echoing Den")
L("MAP_THEATRE_OF_WAR", "Theatre of War")
L("MAP_DESTOZUNOS_LIBRARY", "Destozuno's Library")
-- luacheck: pop
