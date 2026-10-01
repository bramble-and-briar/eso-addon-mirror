if not ONEFRAME_DISPLAY then ZO_CreateStringId("ONEFRAME_DISPLAY", "Display") end
if not ONEFRAME_ROLES then ZO_CreateStringId("ONEFRAME_ROLES", "Roles") end
if not ONEFRAME_TANK_ROLE then ZO_CreateStringId("ONEFRAME_TANK_ROLE", "Tank") end
if not ONEFRAME_HEALER_ROLE then ZO_CreateStringId("ONEFRAME_HEALER_ROLE", "Healer") end
if not ONEFRAME_DAMAGE_ROLE then ZO_CreateStringId("ONEFRAME_DAMAGE_ROLE", "Damage Dealer") end
if not ONEFRAME_COLOR then ZO_CreateStringId("ONEFRAME_COLOR", "Color") end
if not ONEFRAME_SHOW_STATISTIC then ZO_CreateStringId("ONEFRAME_SHOW_STATISTIC", "Show statistic") end
if not ONEFRAME_NOTHING then ZO_CreateStringId("ONEFRAME_NOTHING", "Nothing") end
if not ONEFRAME_LEVEL_CP then ZO_CreateStringId("ONEFRAME_LEVEL_CP", "Level / Champion Points") end
if not ONEFRAME_GROUP_DPS then ZO_CreateStringId("ONEFRAME_GROUP_DPS", "Group DPS") end
if not ONEFRAME_HEALTH_THOUSANDS then ZO_CreateStringId("ONEFRAME_HEALTH_THOUSANDS", "%.1fk") end
if not ONEFRAME_GENERAL then ZO_CreateStringId("ONEFRAME_GENERAL", "General") end
if not ONEFRAME_ENABLED then ZO_CreateStringId("ONEFRAME_ENABLED", "Enable addon") end
if not ONEFRAME_SORT then ZO_CreateStringId("ONEFRAME_SORT", "Sort group by role") end
if not ONEFRAME_SORT_TIP then ZO_CreateStringId("ONEFRAME_SORT_TIP", "Tanks, healers, damage dealers, then unknown roles. Raid companions retain their native slots. Small-group companion layouts use vanilla order.") end
if not ONEFRAME_INFO then ZO_CreateStringId("ONEFRAME_INFO", "Player information") end
if not ONEFRAME_ACCOUNT then ZO_CreateStringId("ONEFRAME_ACCOUNT", "Show account/display name") end
if not ONEFRAME_CLASS then ZO_CreateStringId("ONEFRAME_CLASS", "Show class icon") end
if not ONEFRAME_LEVEL then ZO_CreateStringId("ONEFRAME_LEVEL", "Show level") end
if not ONEFRAME_CP then ZO_CreateStringId("ONEFRAME_CP", "Show Champion Points") end
if not ONEFRAME_CP_VALUE then ZO_CreateStringId("ONEFRAME_CP_VALUE", "CP %d") end
if not ONEFRAME_LEVEL_VALUE then ZO_CreateStringId("ONEFRAME_LEVEL_VALUE", "%d") end
if not ONEFRAME_COLORS then ZO_CreateStringId("ONEFRAME_COLORS", "Role colors") end
if not ONEFRAME_TANK then ZO_CreateStringId("ONEFRAME_TANK", "Tank color") end
if not ONEFRAME_HEALER then ZO_CreateStringId("ONEFRAME_HEALER", "Healer color") end
if not ONEFRAME_DAMAGE then ZO_CreateStringId("ONEFRAME_DAMAGE", "Damage Dealer color") end
if not ONEFRAME_RESTORE then ZO_CreateStringId("ONEFRAME_RESTORE", "Restore vanilla resource colors") end
if not ONEFRAME_STATS then ZO_CreateStringId("ONEFRAME_STATS", "Combat statistics") end
if not ONEFRAME_DPS then ZO_CreateStringId("ONEFRAME_DPS", "Show DPS") end
if not ONEFRAME_HPS then ZO_CreateStringId("ONEFRAME_HPS", "Show HPS") end
if not ONEFRAME_DPS_LABEL then ZO_CreateStringId("ONEFRAME_DPS_LABEL", "DPS") end
if not ONEFRAME_HPS_LABEL then ZO_CreateStringId("ONEFRAME_HPS_LABEL", "HPS") end
if not ONEFRAME_UNAVAILABLE then ZO_CreateStringId("ONEFRAME_UNAVAILABLE", "—") end
if not ONEFRAME_KILO then ZO_CreateStringId("ONEFRAME_KILO", "%.1fk") end
if not ONEFRAME_MILLION then ZO_CreateStringId("ONEFRAME_MILLION", "%.2fm") end
if not ONEFRAME_HODOR then ZO_CreateStringId("ONEFRAME_HODOR", "Use Hodor Reflexes data") end
if not ONEFRAME_ULTIMATE then ZO_CreateStringId("ONEFRAME_ULTIMATE", "Show shared Ultimate icons") end
if not ONEFRAME_ULTIMATE_TIP then ZO_CreateStringId("ONEFRAME_ULTIMATE_TIP", "Available for every role, independently of DPS/HPS. Hodor shares both bars, not the active bar: show both distinct abilities. Numbers are received Ultimate points. Dim = not ready; bright = ready; neutral = unknown/rounded boundary. No data hides the element. Remote points/cost have a 2-point step. Wait for fresh type and points packets after resets.") end
if not ONEFRAME_HODOR_TIP then ZO_CreateStringId("ONEFRAME_HODOR_TIP", "Read existing shared DPS and effective HPS through Hodor's LibGroupCombatStats dependency. No extra broadcasting. Requires the verified Hodor 2026-05-17 / library 2026-07-26 versions. Missing, stale or incompatible data shows — for other members.") end
if not ONEFRAME_STATS_TIP then ZO_CreateStringId("ONEFRAME_STATS_TIP", "Damage dealers show DPS, healers HPS, tanks neither. Ultimate is independent for all roles. Shared rates take priority; local fallback measures direct outgoing damage/raw healing (not effective HPS), excluding pets, companions and shields. Shared rates expire after 10 seconds and reset with combat/group/zone changes. No measurement = —; received zero = 0.") end
if not ONEFRAME_SHIELDS then ZO_CreateStringId("ONEFRAME_SHIELDS", "Damage shields") end
if not ONEFRAME_SHIELD then ZO_CreateStringId("ONEFRAME_SHIELD", "Show damage shields") end
if not ONEFRAME_SHIELD_COLOR then ZO_CreateStringId("ONEFRAME_SHIELD_COLOR", "Shield color") end
if not ONEFRAME_SHIELD_OPACITY then ZO_CreateStringId("ONEFRAME_SHIELD_OPACITY", "Shield opacity") end
if not ONEFRAME_SHIELD_TIP then ZO_CreateStringId("ONEFRAME_SHIELD_TIP", "Enable enhanced colors on the existing vanilla shield overlay. Disabled restores the vanilla shield presentation; ESO's shields, trauma and healing restrictions remain functional.") end
if not ONEFRAME_INFO_TIP then ZO_CreateStringId("ONEFRAME_INFO_TIP", "Details use a compact line inside the frame; statistics use the bottom. No vanilla frame is resized. Status messages take priority over added text.") end
if not ONEFRAME_INTERACTION_SECTION then ZO_CreateStringId("ONEFRAME_INTERACTION_SECTION", "Interaction") end
if not ONEFRAME_INTERACTION then ZO_CreateStringId("ONEFRAME_INTERACTION", "Enable frame interaction") end
if not ONEFRAME_CONTEXT_MENU then ZO_CreateStringId("ONEFRAME_CONTEXT_MENU", "Right-click context menu") end
if not ONEFRAME_WHISPER then ZO_CreateStringId("ONEFRAME_WHISPER", "Whisper") end
if not ONEFRAME_TRAVEL then ZO_CreateStringId("ONEFRAME_TRAVEL", "Travel to Player") end
if not ONEFRAME_REMOVE then ZO_CreateStringId("ONEFRAME_REMOVE", "Remove from Group") end
if not ONEFRAME_UNSUPPORTED then ZO_CreateStringId("ONEFRAME_UNSUPPORTED", "OneFrame: this ESO UI version is not verified; frame enhancements are disabled.") end
if not ONEFRAME_MISSING then ZO_CreateStringId("ONEFRAME_MISSING", "OneFrame: vanilla frame support is unavailable; enhancements were not attached.") end
