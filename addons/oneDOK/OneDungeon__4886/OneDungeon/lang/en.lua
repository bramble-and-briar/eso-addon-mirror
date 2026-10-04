-- English base/fallback. ESO may load this twice on English clients.
if not ONEDUNGEON_DUNGEON then ZO_CreateStringId("ONEDUNGEON_DUNGEON", "Dungeon") end
if not ONEDUNGEON_QUEST then ZO_CreateStringId("ONEDUNGEON_QUEST", "Quest") end
if not ONEDUNGEON_CLEAR then ZO_CreateStringId("ONEDUNGEON_CLEAR", "Vet") end
if not ONEDUNGEON_HARD_MODE then ZO_CreateStringId("ONEDUNGEON_HARD_MODE", "HM") end
if not ONEDUNGEON_TRIFECTA then ZO_CreateStringId("ONEDUNGEON_TRIFECTA", "Trifecta") end
if not ONEDUNGEON_TRI_HEADER then ZO_CreateStringId("ONEDUNGEON_TRI_HEADER", "Tri") end
if not ONEDUNGEON_QUEST_LEGEND then ZO_CreateStringId("ONEDUNGEON_QUEST_LEGEND", "<<1>> — story quest not completed.\n<<2>> — today's Undaunted Pledge.\n<<3>> — accepted Undaunted Pledge.") end
if not ONEDUNGEON_VETERAN_CLEAR then ZO_CreateStringId("ONEDUNGEON_VETERAN_CLEAR", "Veteran Clear") end
if not ONEDUNGEON_HARD_MODE_TITLE then ZO_CreateStringId("ONEDUNGEON_HARD_MODE_TITLE", "Hard Mode") end
if not ONEDUNGEON_NORMAL then ZO_CreateStringId("ONEDUNGEON_NORMAL", "Normal") end
if not ONEDUNGEON_VETERAN then ZO_CreateStringId("ONEDUNGEON_VETERAN", "Veteran") end
if not ONEDUNGEON_COMPLETED then ZO_CreateStringId("ONEDUNGEON_COMPLETED", "Completed") end
if not ONEDUNGEON_INCOMPLETE then ZO_CreateStringId("ONEDUNGEON_INCOMPLETE", "Not completed") end
if not ONEDUNGEON_UNAVAILABLE then ZO_CreateStringId("ONEDUNGEON_UNAVAILABLE", "Not available for this dungeon") end
if not ONEDUNGEON_UNKNOWN then ZO_CreateStringId("ONEDUNGEON_UNKNOWN", "Unknown / could not determine") end
if not ONEDUNGEON_MISSING then ZO_CreateStringId("ONEDUNGEON_MISSING", "Difficulty not available") end
if not ONEDUNGEON_SEARCHING then ZO_CreateStringId("ONEDUNGEON_SEARCHING", "Selection is locked while searching for a group.") end
if not ONEDUNGEON_STORY_ACTIVE then ZO_CreateStringId("ONEDUNGEON_STORY_ACTIVE", "Quest") end
if not ONEDUNGEON_STORY_UNFINISHED then ZO_CreateStringId("ONEDUNGEON_STORY_UNFINISHED", "Quest*") end
if not ONEDUNGEON_TODAY then ZO_CreateStringId("ONEDUNGEON_TODAY", "Today") end
if not ONEDUNGEON_ACTIVE then ZO_CreateStringId("ONEDUNGEON_ACTIVE", "Pledge") end
if not ONEDUNGEON_STORY_ACTIVE_TIP then ZO_CreateStringId("ONEDUNGEON_STORY_ACTIVE_TIP", "Dungeon story quest is active.") end
if not ONEDUNGEON_STORY_UNFINISHED_TIP then ZO_CreateStringId("ONEDUNGEON_STORY_UNFINISHED_TIP", "Dungeon story quest is not completed. Availability and prerequisites have not been verified.") end
if not ONEDUNGEON_TODAY_TIP then ZO_CreateStringId("ONEDUNGEON_TODAY_TIP", "Today's Undaunted Pledge (built-in rotation, aligned to the server's daily reset).") end
if not ONEDUNGEON_ACTIVE_TIP then ZO_CreateStringId("ONEDUNGEON_ACTIVE_TIP", "An Undaunted Pledge for this dungeon is in your quest journal.") end
if not ONEDUNGEON_QUEST_UNKNOWN then ZO_CreateStringId("ONEDUNGEON_QUEST_UNKNOWN", "Story quest: unknown.") end
if not ONEDUNGEON_PLEDGE_UNKNOWN then ZO_CreateStringId("ONEDUNGEON_PLEDGE_UNKNOWN", "Today's pledge: unknown. The built-in schedule does not cover this API version or server time is unavailable.") end
if not ONEDUNGEON_ACTIVE_UNKNOWN then ZO_CreateStringId("ONEDUNGEON_ACTIVE_UNKNOWN", "Active pledge: could not resolve the pledge quest ID.") end
if not ONEDUNGEON_ACHIEVEMENT_UNKNOWN then ZO_CreateStringId("ONEDUNGEON_ACHIEVEMENT_UNKNOWN", "The built-in catalog has no verified achievement mapping for this dungeon, or ESO could not resolve its ID.") end
if not ONEDUNGEON_ALL_HARD_MODES then ZO_CreateStringId("ONEDUNGEON_ALL_HARD_MODES", "All listed Hard Mode achievements are required.") end
if not ONEDUNGEON_SCOPE then ZO_CreateStringId("ONEDUNGEON_SCOPE", "Completion uses ESO's achievement scope (usually account-wide).") end
if not ONEDUNGEON_FALLBACK then ZO_CreateStringId("ONEDUNGEON_FALLBACK", "OneDungeon: original dungeon list restored. Use /onedungeon debug for details.") end
if not ONEDUNGEON_NORMAL_SHORT then ZO_CreateStringId("ONEDUNGEON_NORMAL_SHORT", "N") end
if not ONEDUNGEON_VETERAN_SHORT then ZO_CreateStringId("ONEDUNGEON_VETERAN_SHORT", "V") end

if not ONEDUNGEON_UNAVAILABLE_SYMBOL then ZO_CreateStringId("ONEDUNGEON_UNAVAILABLE_SYMBOL", "—") end
if not ONEDUNGEON_UNKNOWN_SYMBOL then ZO_CreateStringId("ONEDUNGEON_UNKNOWN_SYMBOL", "?") end
if not ONEDUNGEON_COMMAND_HELP then ZO_CreateStringId("ONEDUNGEON_COMMAND_HELP", "/onedungeon debug | dump | refresh") end
