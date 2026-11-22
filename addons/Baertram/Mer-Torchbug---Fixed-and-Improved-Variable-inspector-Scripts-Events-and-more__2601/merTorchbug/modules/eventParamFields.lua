-- Do not edit by hand. Regenerate with: php ESO API docs. parser
-- Last generation date: 20261122 01:29
-- Number of events: 1052
-- eventParamFieldsByName: 1609
local tbug = TBUG or SYSTEMS:GetSystem("merTorchbug")

tbug.eventParamFieldsByName = {
    ["EVENT_ABILITY_LIST_CHANGED"] = {},
    ["EVENT_ABILITY_PROGRESSION_RANK_UPDATE"] = {
        { "progressionIndex", "luaindex" },
        { "rank", "integer" },
        { "maxRank", "integer" },
        { "morph", "integer" },
    },
    ["EVENT_ABILITY_PROGRESSION_RESULT"] = {
        { "reason", "AbilityProgressionResult" },
    },
    ["EVENT_ABILITY_PROGRESSION_XP_UPDATE"] = {
        { "progressionIndex", "luaindex" },
        { "lastRankXP", "integer" },
        { "nextRankXP", "integer" },
        { "currentXP", "integer" },
        { "atMorph", "bool" },
    },
    ["EVENT_ABILITY_REQUIREMENTS_FAIL"] = {
        { "errorId", "integer" },
    },
    ["EVENT_ACCEPT_SHARED_QUEST_RESPONSE"] = {},
    ["EVENT_ACCOUNT_EMAIL_ACTIVATION_EMAIL_SENT"] = {},
    ["EVENT_ACHIEVEMENTS_COMPLETED_ON_UPGRADE_TO_ACCOUNT_WIDE"] = {
        { "numAchievementsCompleteOnUpgrade", "integer" },
    },
    ["EVENT_ACHIEVEMENTS_SEARCH_RESULTS_READY"] = {},
    ["EVENT_ACHIEVEMENTS_UPDATED"] = {},
    ["EVENT_ACHIEVEMENT_AWARDED"] = {
        { "name", "string" },
        { "points", "integer" },
        { "id", "integer" },
        { "link", "string" },
    },
    ["EVENT_ACHIEVEMENT_TRACKING_UPDATE"] = {
        { "trackedAchievementId", "integer" },
        { "trackedCriterionIndex", "luaindex:nilable" },
    },
    ["EVENT_ACHIEVEMENT_UPDATED"] = {
        { "id", "integer" },
    },
    ["EVENT_ACTION_BAR_IS_RESPECCABLE_BAR_STATE_CHANGED"] = {
        { "isRepeccableBarState", "bool" },
    },
    ["EVENT_ACTION_BAR_LOCKED_REASON_CHANGED"] = {
        { "actionBarLockedReason", "ActionBarLockedReason" },
    },
    ["EVENT_ACTION_LAYER_POPPED"] = {
        { "layerIndex", "luaindex" },
        { "activeLayerIndex", "luaindex" },
    },
    ["EVENT_ACTION_LAYER_PUSHED"] = {
        { "layerIndex", "luaindex" },
        { "activeLayerIndex", "luaindex" },
    },
    ["EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED"] = {
        { "didActiveHotbarChange", "bool" },
        { "shouldUpdateAbilityAssignments", "bool" },
        { "activeHotbarCategory", "HotBarCategory" },
    },
    ["EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED"] = {},
    ["EVENT_ACTION_SLOT_ABILITY_USED"] = {
        { "actionSlotIndex", "luaindex" },
    },
    ["EVENT_ACTION_SLOT_ABILITY_USED_WRONG_WEAPON"] = {
        { "weaponConfigType", "WeaponConfigType" },
    },
    ["EVENT_ACTION_SLOT_EFFECTS_CLEARED"] = {},
    ["EVENT_ACTION_SLOT_EFFECT_UPDATE"] = {
        { "hotbar", "HotBarCategory" },
        { "actionSlot", "luaindex" },
    },
    ["EVENT_ACTION_SLOT_STATE_UPDATED"] = {
        { "actionSlotIndex", "luaindex" },
    },
    ["EVENT_ACTION_SLOT_UPDATED"] = {
        { "actionSlotIndex", "luaindex" },
    },
    ["EVENT_ACTION_UPDATE_COOLDOWNS"] = {},
    ["EVENT_ACTIVE_COMPANION_STATE_CHANGED"] = {
        { "newState", "CompanionState" },
        { "oldState", "CompanionState" },
    },
    ["EVENT_ACTIVE_DAEDRIC_ARTIFACT_CHANGED"] = {
        { "artifactId", "integer:nilable" },
    },
    ["EVENT_ACTIVE_DISPLAY_CHANGED"] = {},
    ["EVENT_ACTIVE_MOUNT_CHANGED"] = {},
    ["EVENT_ACTIVE_QUEST_TOOL_CHANGED"] = {
        { "journalIndex", "luaindex" },
        { "toolIndex", "luaindex" },
    },
    ["EVENT_ACTIVE_QUEST_TOOL_CLEARED"] = {},
    ["EVENT_ACTIVE_QUICKSLOT_CHANGED"] = {
        { "actionSlotIndex", "luaindex" },
    },
    ["EVENT_ACTIVE_VETERANCY_SEASON_UPDATED"] = {},
    ["EVENT_ACTIVE_WEAPON_PAIR_CHANGED"] = {
        { "activeWeaponPair", "ActiveWeaponPair" },
        { "locked", "bool" },
    },
    ["EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE"] = {},
    ["EVENT_ACTIVITY_FINDER_COOLDOWNS_UPDATE"] = {},
    ["EVENT_ACTIVITY_FINDER_STATUS_UPDATE"] = {
        { "result", "ActivityFinderStatus" },
    },
    ["EVENT_ACTIVITY_QUEUE_RESULT"] = {
        { "result", "ActivityQueueResult" },
    },
    ["EVENT_ADDONS_DISABLED_STATE_CHANGED"] = {
        { "forceDisabled", "bool" },
    },
    ["EVENT_ADD_ONS_LOADED"] = {},
    ["EVENT_ADD_ON_LOADED"] = {
        { "addonName", "string" },
    },
    ["EVENT_ADVENTURE_ZONE_FACTION_CHOSEN"] = {
        { "newFaction", "AdventureZoneFaction" },
    },
    ["EVENT_ADVENTURE_ZONE_FACTION_REPUTATION_CHANGED"] = {
        { "newReputation", "integer" },
        { "deltaReputation", "integer" },
    },
    ["EVENT_ADVENTURE_ZONE_FACTION_STANDING_UPDATE_RECEIVED"] = {},
    ["EVENT_ADVENTURE_ZONE_WORLD_EVENT_INIT"] = {},
    ["EVENT_ADVENTURE_ZONE_WORLD_EVENT_STARTS_SOON"] = {},
    ["EVENT_AGENT_CHAT_ACCEPTED"] = {},
    ["EVENT_AGENT_CHAT_DECLINED"] = {},
    ["EVENT_AGENT_CHAT_FORCED"] = {},
    ["EVENT_AGENT_CHAT_REQUESTED"] = {},
    ["EVENT_AGENT_CHAT_TERMINATED"] = {},
    ["EVENT_ALLIANCE_POINT_UPDATE"] = {
        { "alliancePoints", "integer" },
        { "playSound", "bool" },
        { "difference", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_ALL_GUI_SCREENS_RESIZED"] = {},
    ["EVENT_ALL_GUI_SCREENS_RESIZE_STARTED"] = {},
    ["EVENT_ANIMATION_NOTE"] = {
        { "animNote", "string" },
    },
    ["EVENT_ANTIQUITIES_UPDATED"] = {},
    ["EVENT_ANTIQUITY_DIGGING_ACTIVE_SKILL_USE_RESULT"] = {
        { "result", "DiggingActiveSkillUseResult" },
    },
    ["EVENT_ANTIQUITY_DIGGING_ANTIQUITY_UNEARTHED"] = {},
    ["EVENT_ANTIQUITY_DIGGING_BONUS_LOOT_UNEARTHED"] = {},
    ["EVENT_ANTIQUITY_DIGGING_DIG_POWER_REFUND"] = {},
    ["EVENT_ANTIQUITY_DIGGING_EXIT_RESPONSE"] = {
        { "accept", "bool" },
    },
    ["EVENT_ANTIQUITY_DIGGING_GAME_OVER"] = {
        { "gameOverFlags", "DiggingGameOverFlags" },
    },
    ["EVENT_ANTIQUITY_DIGGING_MOUSE_OVER_ACTIVE_SKILL_CHANGED"] = {
        { "mousedOverSkill", "DiggingActiveSkills:nilable" },
    },
    ["EVENT_ANTIQUITY_DIGGING_NUM_RADARS_REMAINING_CHANGED"] = {
        { "numRadarsRemaining", "integer" },
    },
    ["EVENT_ANTIQUITY_DIGGING_READY_TO_PLAY"] = {},
    ["EVENT_ANTIQUITY_DIG_SITES_UPDATED"] = {
        { "antiquityId", "integer" },
    },
    ["EVENT_ANTIQUITY_DIG_SPOT_DIG_POWER_CHANGED"] = {
        { "digPower", "integer" },
    },
    ["EVENT_ANTIQUITY_DIG_SPOT_DURABILITY_CHANGED"] = {
        { "durability", "integer" },
    },
    ["EVENT_ANTIQUITY_DIG_SPOT_STABILITY_CHANGED"] = {
        { "stability", "integer" },
    },
    ["EVENT_ANTIQUITY_JOURNAL_SHOW_SCRYABLE"] = {},
    ["EVENT_ANTIQUITY_LEAD_ACQUIRED"] = {
        { "antiquityId", "integer" },
    },
    ["EVENT_ANTIQUITY_SCRYING_RESULT"] = {
        { "result", "AntiquityScryingResult" },
    },
    ["EVENT_ANTIQUITY_SEARCH_RESULTS_READY"] = {},
    ["EVENT_ANTIQUITY_SELECTED_TOOL_CHANGED"] = {},
    ["EVENT_ANTIQUITY_SHOW_CODEX_ENTRY"] = {
        { "antiquityId", "integer" },
    },
    ["EVENT_ANTIQUITY_TRACKING_INITIALIZED"] = {},
    ["EVENT_ANTIQUITY_TRACKING_UPDATE"] = {
        { "trackedAntiquityId", "integer" },
    },
    ["EVENT_ANTIQUITY_UPDATED"] = {
        { "antiquityId", "integer" },
    },
    ["EVENT_APP_GUI_HIDDEN_STATE_CHANGED"] = {
        { "hidden", "bool" },
    },
    ["EVENT_ARMORY_BUILDS_FULL_UPDATE"] = {},
    ["EVENT_ARMORY_BUILD_CHAMPION_SLOTS_MODIFIED"] = {},
    ["EVENT_ARMORY_BUILD_COUNT_UPDATED"] = {},
    ["EVENT_ARMORY_BUILD_OPERATION_STARTED"] = {
        { "operationType", "ArmoryBuildOperationType" },
        { "buildIndex", "luaindex" },
    },
    ["EVENT_ARMORY_BUILD_RESTORE_RESPONSE"] = {
        { "result", "ArmoryBuildRestoreResult" },
        { "buildIndex", "luaindex" },
    },
    ["EVENT_ARMORY_BUILD_SAVE_RESPONSE"] = {
        { "result", "ArmoryBuildSaveResult" },
        { "buildIndex", "luaindex" },
    },
    ["EVENT_ARMORY_BUILD_UPDATED"] = {
        { "buildIndex", "luaindex" },
    },
    ["EVENT_ARTIFACT_CONTROL_STATE"] = {
        { "artifactName", "string" },
        { "keepId", "integer" },
        { "characterName", "string" },
        { "playerAlliance", "Alliance" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "campaignId", "integer" },
        { "displayName", "string" },
    },
    ["EVENT_ARTIFACT_SCROLL_STATE_CHANGED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "objectiveName", "string" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "originalOwnerAlliance", "Alliance" },
        { "holderAlliance", "Alliance" },
        { "lastHolderAlliance", "Alliance" },
        { "capturedAtKeepId", "integer" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_ARTIFICIAL_EFFECT_ADDED"] = {
        { "artificialEffectId", "integer" },
    },
    ["EVENT_ARTIFICIAL_EFFECT_REMOVED"] = {
        { "artificialEffectId", "integer" },
    },
    ["EVENT_ASSIGNED_CAMPAIGN_CHANGED"] = {
        { "newAssignedCampaignId", "integer" },
    },
    ["EVENT_ATTRIBUTE_RESPEC_RESULT"] = {
        { "result", "RespecResult" },
    },
    ["EVENT_ATTRIBUTE_UPGRADE_UPDATED"] = {},
    ["EVENT_AUTO_MAP_NAVIGATION_TARGET_SET"] = {},
    ["EVENT_AVAILABLE_DISPLAY_DEVICES_CHANGED"] = {},
    ["EVENT_AVENGE_KILL"] = {
        { "avengedCharacterName", "string" },
        { "killedCharacterName", "string" },
        { "avengedDisplayName", "string" },
        { "killedDisplayName", "string" },
    },
    ["EVENT_BACKGROUND_LIST_FILTER_COMPLETE"] = {
        { "taskId", "integer" },
    },
    ["EVENT_BANKED_CURRENCY_UPDATE"] = {
        { "currency", "CurrencyType" },
        { "newValue", "integer" },
        { "oldValue", "integer" },
    },
    ["EVENT_BANKED_MONEY_UPDATE"] = {
        { "newValue", "integer" },
        { "oldValue", "integer" },
    },
    ["EVENT_BANK_DEPOSIT_NOT_ALLOWED"] = {},
    ["EVENT_BANK_IS_FULL"] = {},
    ["EVENT_BATTLEGROUND_INACTIVITY_WARNING"] = {},
    ["EVENT_BATTLEGROUND_KILL"] = {
        { "killedPlayerCharacterName", "string" },
        { "killedPlayerDisplayName", "string" },
        { "killedPlayerBattlegroundTeam", "BattlegroundTeam" },
        { "killingPlayerCharacterName", "string" },
        { "killingPlayerDisplayName", "string" },
        { "killingPlayerBattlegroundTeam", "BattlegroundTeam" },
        { "battlegroundKillType", "BattlegroundKillType" },
        { "killingAbilityId", "integer" },
    },
    ["EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED"] = {
        { "battlegroundType", "BattlegroundLeaderboardType" },
    },
    ["EVENT_BATTLEGROUND_MMR_LOSS_REDUCED"] = {
        { "reductionReason", "BattlegroundMMRBonusType" },
    },
    ["EVENT_BATTLEGROUND_RULESET_CHANGED"] = {},
    ["EVENT_BATTLEGROUND_SCOREBOARD_UPDATED"] = {},
    ["EVENT_BATTLEGROUND_SHUTDOWN_TIMER"] = {
        { "enabled", "bool" },
    },
    ["EVENT_BATTLEGROUND_STATE_CHANGED"] = {
        { "previousState", "BattlegroundState" },
        { "currentState", "BattlegroundState" },
    },
    ["EVENT_BEGIN_CUTSCENE"] = {},
    ["EVENT_BEGIN_LOCKPICK"] = {},
    ["EVENT_BEGIN_SIEGE_CONTROL"] = {},
    ["EVENT_BEGIN_SIEGE_UPGRADE"] = {},
    ["EVENT_BOSSES_CHANGED"] = {
        { "forceReset", "bool" },
    },
    ["EVENT_BROADCAST"] = {
        { "message", "string" },
    },
    ["EVENT_BUYBACK_RECEIPT"] = {
        { "itemLink", "string" },
        { "itemQuantity", "integer" },
        { "money", "integer" },
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_BUY_RECEIPT"] = {
        { "entryName", "string" },
        { "entryType", "StoreEntryType" },
        { "entryQuantity", "integer" },
        { "money", "integer" },
        { "specialCurrencyType1", "CurrencyType" },
        { "specialCurrencyInfo1", "string" },
        { "specialCurrencyQuantity1", "integer" },
        { "specialCurrencyType2", "CurrencyType" },
        { "specialCurrencyInfo2", "string" },
        { "specialCurrencyQuantity2", "integer" },
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_CADWELL_PROGRESSION_LEVEL_CHANGED"] = {
        { "progressionLevel", "integer" },
    },
    ["EVENT_CAMPAIGN_ALLIANCE_LOCK_ACTIVATED"] = {
        { "campaignId", "integer" },
        { "wasLockedToAlliance", "Alliance" },
    },
    ["EVENT_CAMPAIGN_ALLIANCE_LOCK_PENDING"] = {
        { "campaignId", "integer" },
        { "lockedToAlliance", "Alliance" },
        { "timeLeftS", "integer" },
    },
    ["EVENT_CAMPAIGN_ASSIGNMENT_RESULT"] = {
        { "result", "CampaignReassignmentErrorReason" },
    },
    ["EVENT_CAMPAIGN_EMPEROR_CHANGED"] = {
        { "campaignId", "integer" },
    },
    ["EVENT_CAMPAIGN_HISTORY_WINDOW_CHANGED"] = {},
    ["EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED"] = {
        { "campaignId", "integer" },
        { "alliance", "Alliance" },
    },
    ["EVENT_CAMPAIGN_QUEUE_JOINED"] = {
        { "campaignId", "integer" },
        { "isGroupMember", "bool" },
        { "willLockToAlliance", "Alliance" },
    },
    ["EVENT_CAMPAIGN_QUEUE_LEFT"] = {
        { "campaignId", "integer" },
        { "isGroup", "bool" },
    },
    ["EVENT_CAMPAIGN_QUEUE_POSITION_CHANGED"] = {
        { "campaignId", "integer" },
        { "isGroup", "bool" },
        { "position", "integer" },
    },
    ["EVENT_CAMPAIGN_QUEUE_STATE_CHANGED"] = {
        { "campaignId", "integer" },
        { "isGroup", "bool" },
        { "state", "CampaignQueueRequestStateType" },
    },
    ["EVENT_CAMPAIGN_SCORE_DATA_CHANGED"] = {},
    ["EVENT_CAMPAIGN_SELECTION_DATA_CHANGED"] = {},
    ["EVENT_CAMPAIGN_STATE_INITIALIZED"] = {
        { "campaignId", "integer" },
    },
    ["EVENT_CAMPAIGN_UNASSIGNMENT_RESULT"] = {
        { "result", "UnassignCampaignResult" },
    },
    ["EVENT_CAMPAIGN_UNDERPOP_BONUS_CHANGE_NOTIFICATION"] = {
        { "campaignId", "integer" },
    },
    ["EVENT_CANCEL_GROUND_TARGET_MODE"] = {},
    ["EVENT_CANCEL_MOUSE_REQUEST_DESTROY_ITEM"] = {},
    ["EVENT_CANCEL_REQUEST_CONFIRM_USE_ITEM"] = {},
    ["EVENT_CANNOT_CROUCH_WHILE_CARRYING_ARTIFACT"] = {
        { "artifactName", "string" },
    },
    ["EVENT_CANNOT_DO_THAT_WHILE_DEAD"] = {},
    ["EVENT_CANNOT_DO_THAT_WHILE_HIDDEN"] = {},
    ["EVENT_CAPS_LOCK_STATE_CHANGED"] = {
        { "capsLockEnabled", "bool" },
    },
    ["EVENT_CAPTURE_AREA_SPAWNED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "pinType", "MapDisplayPinType" },
        { "hasMoved", "bool" },
    },
    ["EVENT_CAPTURE_AREA_STATE_CHANGED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "objectiveName", "string" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "owningAlliance", "Alliance" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_CAPTURE_AREA_STATUS"] = {
        { "keepId", "integer" },
        { "objectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "capturePoolValue", "integer" },
        { "capturePoolMax", "integer" },
        { "capturingPlayers", "integer" },
        { "contestingPlayers", "integer" },
        { "owningAlliance", "Alliance" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_CAPTURE_FLAG_STATE_CHANGED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "objectiveName", "string" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "originalOwnerAlliance", "Alliance" },
        { "holderAlliance", "Alliance" },
        { "lastHolderAlliance", "Alliance" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_CARRIED_CURRENCY_UPDATE"] = {
        { "currency", "CurrencyType" },
        { "newValue", "integer" },
        { "oldValue", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_CHAMPION_LEVEL_ACHIEVED"] = {
        { "wasChampionSystemUnlocked", "bool" },
    },
    ["EVENT_CHAMPION_POINT_GAINED"] = {
        { "championPointsDelta", "integer" },
    },
    ["EVENT_CHAMPION_POINT_UPDATE"] = {
        { "unitTag", "string" },
        { "oldChampionPoints", "integer" },
        { "currentChampionPoints", "integer" },
    },
    ["EVENT_CHAMPION_PURCHASE_RESULT"] = {
        { "result", "ChampionPurchaseResult" },
    },
    ["EVENT_CHAMPION_SYSTEM_UNLOCKED"] = {},
    ["EVENT_CHATTER_BEGIN"] = {
        { "optionCount", "integer" },
        { "debugSource", "integer" },
    },
    ["EVENT_CHATTER_END"] = {},
    ["EVENT_CHAT_CATEGORY_COLOR_CHANGED"] = {
        { "categoryId", "integer" },
        { "red", "number" },
        { "green", "number" },
        { "blue", "number" },
    },
    ["EVENT_CHAT_LOG_TOGGLED"] = {
        { "opened", "bool" },
    },
    ["EVENT_CHAT_MESSAGE_CHANNEL"] = {
        { "channelType", "ChannelType" },
        { "fromName", "string" },
        { "text", "string" },
        { "isCustomerService", "bool" },
        { "fromDisplayName", "string" },
    },
    ["EVENT_CLAIM_REWARD_RESULT"] = {
        { "result", "ClaimRewardResult" },
    },
    ["EVENT_CLEAR_NEW_ON_ALL_SKILL_LINES"] = {},
    ["EVENT_CLIENT_INTERACT_RESULT"] = {
        { "result", "ClientInteractResult" },
        { "interactTargetName", "string" },
    },
    ["EVENT_CLOSE_BANK"] = {},
    ["EVENT_CLOSE_GUILD_BANK"] = {},
    ["EVENT_CLOSE_STORE"] = {},
    ["EVENT_CLOSE_TRADING_HOUSE"] = {},
    ["EVENT_COLLECTIBLES_SEARCH_RESULTS_READY"] = {},
    ["EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED"] = {},
    ["EVENT_COLLECTIBLE_BLACKLIST_UPDATED"] = {},
    ["EVENT_COLLECTIBLE_CATEGORY_NEW_STATUS_CLEARED"] = {
        { "categoryId", "integer" },
    },
    ["EVENT_COLLECTIBLE_DYE_DATA_UPDATED"] = {
        { "collectibleId", "integer" },
    },
    ["EVENT_COLLECTIBLE_NEW_STATUS_CLEARED"] = {
        { "collectibleId", "integer" },
    },
    ["EVENT_COLLECTIBLE_NOTIFICATION_NEW"] = {
        { "collectibleId", "integer" },
        { "notificationId", "integer" },
    },
    ["EVENT_COLLECTIBLE_NOTIFICATION_REMOVED"] = {
        { "notificationId", "integer" },
        { "collectibleId", "integer" },
    },
    ["EVENT_COLLECTIBLE_RENAME_ERROR"] = {
        { "errorReason", "NamingError" },
    },
    ["EVENT_COLLECTIBLE_REQUEST_BROWSE_TO"] = {
        { "collectibleId", "integer" },
    },
    ["EVENT_COLLECTIBLE_SET_IN_WATER_ALERT"] = {},
    ["EVENT_COLLECTIBLE_UPDATED"] = {
        { "id", "integer" },
    },
    ["EVENT_COLLECTIBLE_USER_FLAGS_UPDATED"] = {
        { "collectibleId", "integer" },
        { "oldFlags", "integer" },
        { "newFlags", "integer" },
    },
    ["EVENT_COLLECTIBLE_USE_RESULT"] = {
        { "result", "CollectibleUsageBlockReason" },
        { "isAttemptingActivation", "bool" },
    },
    ["EVENT_COLLECTION_UPDATED"] = {},
    ["EVENT_COMBAT_EVENT"] = {
        { "result", "ActionResult" },
        { "isError", "bool" },
        { "abilityName", "string" },
        { "abilityGraphic", "integer" },
        { "abilityActionSlotType", "ActionSlotType" },
        { "sourceName", "string" },
        { "sourceType", "CombatUnitType" },
        { "targetName", "string" },
        { "targetType", "CombatUnitType" },
        { "hitValue", "integer" },
        { "powerType", "CombatMechanicFlags" },
        { "damageType", "DamageType" },
        { "log", "bool" },
        { "sourceUnitId", "integer" },
        { "targetUnitId", "integer" },
        { "abilityId", "integer" },
        { "overflow", "integer" },
    },
    ["EVENT_COMPANION_ACTIVATED"] = {
        { "companionId", "integer" },
    },
    ["EVENT_COMPANION_DEACTIVATED"] = {},
    ["EVENT_COMPANION_EXPERIENCE_GAIN"] = {
        { "companionId", "integer" },
        { "level", "integer" },
        { "previousExperience", "integer" },
        { "currentExperience", "integer" },
    },
    ["EVENT_COMPANION_RAPPORT_UPDATE"] = {
        { "companionId", "integer" },
        { "previousRapport", "integer" },
        { "currentRapport", "integer" },
        { "adjustmentAmountType", "CompanionRapportAdjustmentAmount" },
    },
    ["EVENT_COMPANION_SKILLS_FULL_UPDATE"] = {
        { "isInit", "bool" },
    },
    ["EVENT_COMPANION_SKILL_LINE_ADDED"] = {
        { "skillLineId", "integer" },
    },
    ["EVENT_COMPANION_SKILL_RANK_UPDATE"] = {
        { "skillLineId", "integer" },
        { "rank", "luaindex" },
    },
    ["EVENT_COMPANION_SKILL_XP_UPDATE"] = {
        { "skillLineId", "integer" },
        { "reason", "integer" },
        { "rank", "luaindex" },
        { "previousXP", "integer" },
        { "currentXP", "integer" },
    },
    ["EVENT_COMPANION_SUMMON_RESULT"] = {
        { "summonResult", "CompanionSummonResult" },
        { "companionId", "integer" },
    },
    ["EVENT_COMPANION_ULTIMATE_FAILURE"] = {
        { "reason", "CompanionUltimateFailureReason" },
        { "companionName", "string" },
    },
    ["EVENT_CONFIRM_INTERACT"] = {
        { "dialogTitle", "string" },
        { "dialogBody", "string" },
        { "acceptText", "string" },
        { "cancelText", "string" },
    },
    ["EVENT_CONSOLE_ADDONS_DISABLED_STATE_CHANGED"] = {
        { "consoleAddonsDisabled", "bool" },
    },
    ["EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED"] = {},
    ["EVENT_CONSOLE_ADD_ONS_SAVED_VARIABLES_LIMIT_REACHED"] = {},
    ["EVENT_CONSOLE_INFO_RECEIVED"] = {
        { "requestKey", "integer" },
        { "displayName", "string" },
        { "consoleId", "id64" },
        { "success", "bool" },
    },
    ["EVENT_CONSOLE_TEXT_VALIDATION_RESULT"] = {
        { "key", "integer" },
        { "valid", "bool" },
    },
    ["EVENT_CONSOLIDATED_SMITHING_ITEM_SET_SEARCH_RESULTS_READY"] = {},
    ["EVENT_CONSOLIDATED_STATION_ACTIVE_SET_UPDATED"] = {},
    ["EVENT_CONSOLIDATED_STATION_SETS_UPDATED"] = {
        { "craftingStationFurnitureId", "id64" },
    },
    ["EVENT_CONTROLLER_CONNECTED"] = {},
    ["EVENT_CONTROLLER_DISCONNECTED"] = {},
    ["EVENT_CONVERSATION_FAILED_INVENTORY_FULL"] = {},
    ["EVENT_CONVERSATION_FAILED_UNIQUE_ITEM"] = {},
    ["EVENT_CONVERSATION_UPDATED"] = {
        { "conversationBodyText", "string" },
        { "conversationOptionCount", "integer" },
    },
    ["EVENT_CORONATE_EMPEROR_NOTIFICATION"] = {
        { "campaignId", "integer" },
        { "emperorCharacterName", "string" },
        { "emperorAlliance", "Alliance" },
        { "emperorDisplayName", "string" },
    },
    ["EVENT_CRAFTED_ABILITY_LOCK_STATE_CHANGED"] = {
        { "craftedAbilityDefId", "integer" },
        { "isUnlocked", "bool" },
        { "isFromInit", "bool" },
    },
    ["EVENT_CRAFTED_ABILITY_RESET"] = {
        { "craftedAbilityDefId", "integer" },
        { "totalNumReset", "integer" },
        { "isLastReset", "bool" },
    },
    ["EVENT_CRAFTED_ABILITY_SCRIPT_LOCK_STATE_CHANGED"] = {
        { "craftedAbilityScriptDefId", "integer" },
        { "isUnlocked", "bool" },
    },
    ["EVENT_CRAFTED_ABILITY_SEARCH_RESULTS_READY"] = {},
    ["EVENT_CRAFTING_STATION_INTERACT"] = {
        { "craftSkill", "TradeskillType" },
        { "sameStation", "bool" },
        { "craftMode", "CraftingInteractionMode" },
    },
    ["EVENT_CRAFT_BAG_AUTO_TRANSFER_NOTIFICATION_CLEARED"] = {},
    ["EVENT_CRAFT_COMPLETED"] = {
        { "craftSkill", "TradeskillType" },
    },
    ["EVENT_CRAFT_FAILED"] = {
        { "tradeskillResult", "TradeskillResult" },
    },
    ["EVENT_CRAFT_STARTED"] = {
        { "craftSkill", "TradeskillType" },
        { "context", "CraftingProcessContext" },
    },
    ["EVENT_CREATE_GUILD_MAIL_RESULT"] = {
        { "result", "GuildMailerResult" },
    },
    ["EVENT_CROWN_CRATES_SYSTEM_STATE_CHANGED"] = {
        { "crownCratesSystemState", "LootCratesSystemState" },
    },
    ["EVENT_CROWN_CRATE_INVENTORY_UPDATED"] = {},
    ["EVENT_CROWN_CRATE_OPEN_RESPONSE"] = {
        { "crownCrateId", "integer" },
        { "response", "LootCrateOpenResponse" },
    },
    ["EVENT_CROWN_CRATE_QUANTITY_UPDATE"] = {
        { "crateId", "integer" },
        { "newCount", "integer" },
        { "oldCount", "integer" },
    },
    ["EVENT_CROWN_GEM_UPDATE"] = {
        { "crownGemAmount", "integer" },
        { "difference", "integer" },
        { "reason", "CurrencyChangeReason" },
    },
    ["EVENT_CROWN_UPDATE"] = {
        { "crownAmount", "integer" },
        { "difference", "integer" },
        { "reason", "CurrencyChangeReason" },
    },
    ["EVENT_CURRENCY_CAPS_CHANGED"] = {},
    ["EVENT_CURRENCY_UPDATE"] = {
        { "currencyType", "CurrencyType" },
        { "currencyLocation", "CurrencyLocation" },
        { "newAmount", "integer" },
        { "oldAmount", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_CURRENT_CAMPAIGN_CHANGED"] = {
        { "newCurrentCampaignId", "integer" },
    },
    ["EVENT_CURRENT_SUBZONE_LIST_CHANGED"] = {},
    ["EVENT_CURSOR_DROPPED"] = {
        { "type", "MouseContentType" },
        { "param1", "integer" },
        { "param2", "integer" },
        { "param3", "integer" },
        { "param4", "integer" },
        { "param5", "integer" },
        { "param6", "integer" },
    },
    ["EVENT_CURSOR_PICKUP"] = {
        { "type", "MouseContentType" },
        { "param1", "integer" },
        { "param2", "integer" },
        { "param3", "integer" },
        { "param4", "integer" },
        { "param5", "integer" },
        { "param6", "integer" },
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_CUSTOMER_SERVICE_FEEDBACK_SUBMITTED"] = {
        { "responseMessage", "string" },
        { "success", "bool" },
    },
    ["EVENT_CUSTOMER_SERVICE_TICKET_SUBMITTED"] = {
        { "responseMessage", "string" },
        { "success", "bool" },
    },
    ["EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED"] = {
        { "daedricArtifactId", "integer" },
    },
    ["EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "BattlegroundQueryContextType" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "holderAlliance", "Alliance" },
        { "lastHolderAlliance", "Alliance" },
        { "pinType", "MapDisplayPinType" },
        { "daedricArtifactId", "integer" },
        { "lastObjectiveControlState", "ObjectiveControlState" },
    },
    ["EVENT_DAILY_LOGIN_MONTH_CHANGED"] = {},
    ["EVENT_DAILY_LOGIN_REWARDS_CLAIMED"] = {},
    ["EVENT_DAILY_LOGIN_REWARDS_UPDATED"] = {},
    ["EVENT_DEFERRED_SETTING_REQUEST_COMPLETED"] = {
        { "settingSystemType", "SettingSystemType" },
        { "settingId", "integer" },
        { "success", "bool" },
        { "result", "integer" },
    },
    ["EVENT_DELETE_GUILD_MAIL_RESULT"] = {
        { "result", "GuildMailerResult" },
    },
    ["EVENT_DELETE_MAIL_RESPONSE"] = {
        { "mailId", "id64" },
        { "success", "bool" },
    },
    ["EVENT_DEPOSE_EMPEROR_NOTIFICATION"] = {
        { "campaignId", "integer" },
        { "emperorCharacterName", "string" },
        { "emperorAlliance", "Alliance" },
        { "abdication", "bool" },
        { "emperorDisplayName", "string" },
    },
    ["EVENT_DIRECT_PURCHASE_CHECK_USER_PURCHASE_ELIGIBILITY_RESULT"] = {
        { "result", "DirectPurchaseCheckUserPurchaseEligibilityResult" },
    },
    ["EVENT_DIRECT_PURCHASE_PURCHASE_SKU_RESULT"] = {
        { "skuId", "integer" },
        { "result", "DirectPurchasePurchaseSkuResult" },
    },
    ["EVENT_DIRECT_PURCHASE_QUERY_CATALOG_COMPLETE"] = {
        { "result", "DirectPurchaseQueryCatalogResult" },
        { "queryId", "integer" },
    },
    ["EVENT_DISABLED_ACTIVITIES_UPDATE"] = {},
    ["EVENT_DISABLE_SIEGE_AIM_ABILITY"] = {},
    ["EVENT_DISABLE_SIEGE_FIRE_ABILITY"] = {},
    ["EVENT_DISABLE_SIEGE_PACKUP_ABILITY"] = {},
    ["EVENT_DISCOVERY_EXPERIENCE"] = {
        { "areaName", "string" },
        { "level", "integer" },
        { "previousExperience", "integer" },
        { "currentExperience", "integer" },
        { "championPoints", "integer" },
    },
    ["EVENT_DISGUISE_STATE_CHANGED"] = {
        { "unitTag", "string" },
        { "disguiseState", "DisguiseState" },
    },
    ["EVENT_DISPLAY_ACTIVE_COMBAT_TIP"] = {
        { "activeCombatTipId", "integer" },
    },
    ["EVENT_DISPLAY_ALERT"] = {
        { "alertText", "string" },
        { "soundId", "string" },
    },
    ["EVENT_DISPLAY_ANNOUNCEMENT"] = {
        { "primaryText", "string" },
        { "secondaryText", "string" },
        { "iconFilename", "string" },
        { "soundId", "string" },
        { "lifespanMS", "integer" },
        { "category", "CenterScreenAnnouncementCategory" },
    },
    ["EVENT_DISPLAY_TUTORIAL"] = {
        { "tutorialIndex", "luaindex" },
    },
    ["EVENT_DISPLAY_TUTORIAL_WITH_ANCHOR"] = {
        { "tutorialIndex", "luaindex" },
        { "anchor", "AnchorPosition" },
        { "offsetX", "number" },
        { "offsetY", "number" },
    },
    ["EVENT_DISPOSITION_UPDATE"] = {
        { "unitTag", "string" },
    },
    ["EVENT_DUEL_COUNTDOWN"] = {
        { "startTimeMS", "integer" },
    },
    ["EVENT_DUEL_FINISHED"] = {
        { "duelResult", "DuelResult" },
        { "wasLocalPlayersResult", "bool" },
        { "opponentCharacterName", "string" },
        { "opponentCrossplayDisplayName", "string" },
        { "opponentAlliance", "Alliance" },
        { "opponentGender", "Gender" },
        { "opponentClassId", "integer" },
        { "opponentRaceId", "integer" },
        { "opponentPlatformDisplayName", "string" },
    },
    ["EVENT_DUEL_INVITE_ACCEPTED"] = {},
    ["EVENT_DUEL_INVITE_CANCELED"] = {},
    ["EVENT_DUEL_INVITE_DECLINED"] = {},
    ["EVENT_DUEL_INVITE_FAILED"] = {
        { "reason", "DuelInviteFailReason" },
        { "targetCharacterName", "string" },
        { "targetCrossplayDisplayName", "string" },
        { "targetPlatformDisplayName", "string" },
    },
    ["EVENT_DUEL_INVITE_RECEIVED"] = {
        { "inviterCharacterName", "string" },
        { "inviterCrossplayDisplayName", "string" },
        { "timeRemainingMS", "integer" },
        { "inviterPlatformDisplayName", "string" },
    },
    ["EVENT_DUEL_INVITE_REMOVED"] = {},
    ["EVENT_DUEL_INVITE_SENT"] = {
        { "inviteeCharacterName", "string" },
        { "inviteeCrossplayDisplayName", "string" },
        { "inviteePlatformDisplayName", "string" },
    },
    ["EVENT_DUEL_NEAR_BOUNDARY"] = {
        { "isInWarningArea", "bool" },
    },
    ["EVENT_DUEL_STARTED"] = {},
    ["EVENT_DURANGO_ACCOUNT_PICKER_RETURNED"] = {},
    ["EVENT_DYEING_STATION_INTERACT_END"] = {},
    ["EVENT_DYEING_STATION_INTERACT_START"] = {},
    ["EVENT_DYES_SEARCH_RESULTS_READY"] = {},
    ["EVENT_DYE_STAMP_USE_FAIL"] = {
        { "reason", "DyeStampUseResult" },
    },
    ["EVENT_EFFECTS_FULL_UPDATE"] = {},
    ["EVENT_EFFECT_CHANGED"] = {
        { "changeType", "EffectResult" },
        { "effectSlot", "integer" },
        { "effectName", "string" },
        { "unitTag", "string" },
        { "beginTime", "number" },
        { "endTime", "number" },
        { "stackCount", "integer" },
        { "iconName", "string" },
        { "deprecatedBuffType", "string" },
        { "effectType", "BuffEffectType" },
        { "abilityType", "AbilityType" },
        { "statusEffectType", "StatusEffectType" },
        { "unitName", "string" },
        { "unitId", "integer" },
        { "abilityId", "integer" },
        { "sourceType", "CombatUnitType" },
    },
    ["EVENT_ENABLE_SIEGE_AIM_ABILITY"] = {},
    ["EVENT_ENABLE_SIEGE_FIRE_ABILITY"] = {},
    ["EVENT_ENABLE_SIEGE_PACKUP_ABILITY"] = {},
    ["EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_CHOICES_RECEIVED"] = {},
    ["EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_REROLL_FAILED"] = {
        { "errorReason", "EndlessDungeonBuffSelectorRerollError" },
    },
    ["EVENT_ENDLESS_DUNGEON_BUFF_STACK_COUNT_UPDATED"] = {
        { "buffType", "EndlessDungeonBuffType" },
        { "abilityId", "integer" },
        { "stackCount", "integer" },
    },
    ["EVENT_ENDLESS_DUNGEON_COMPLETED"] = {
        { "flags", "integer" },
    },
    ["EVENT_ENDLESS_DUNGEON_CONFIRM_COMPANION_SUMMONING"] = {
        { "collectibleId", "integer" },
    },
    ["EVENT_ENDLESS_DUNGEON_COUNTER_VALUE_CHANGED"] = {
        { "counterType", "EndlessDungeonCounterType" },
        { "counterValue", "integer" },
    },
    ["EVENT_ENDLESS_DUNGEON_INITIALIZED"] = {
        { "endlessDungeonId", "integer" },
        { "flags", "integer" },
        { "completed", "bool" },
    },
    ["EVENT_ENDLESS_DUNGEON_LEADERBOARD_DATA_RECEIVED"] = {
        { "endlessDungeonGroupType", "EndlessDungeonGroupType" },
        { "endlessDungeonId", "integer" },
    },
    ["EVENT_ENDLESS_DUNGEON_LEADERBOARD_PLAYER_DATA_CHANGED"] = {},
    ["EVENT_ENDLESS_DUNGEON_NEW_BEST_SCORE"] = {
        { "endlessDungeonName", "string" },
        { "score", "integer" },
        { "isWeekly", "bool" },
    },
    ["EVENT_ENDLESS_DUNGEON_OF_THE_WEEK_TURNOVER"] = {},
    ["EVENT_ENDLESS_DUNGEON_RESET_BEST_SCORE"] = {
        { "endlessDungeonName", "string" },
        { "isWeekly", "bool" },
    },
    ["EVENT_ENDLESS_DUNGEON_SCORE_UPDATED"] = {
        { "currentScore", "integer" },
        { "reason", "EndlessDungeonPointReason" },
    },
    ["EVENT_ENDLESS_DUNGEON_STARTED"] = {},
    ["EVENT_END_CRAFTING_STATION_INTERACT"] = {
        { "craftSkill", "TradeskillType" },
        { "craftMode", "CraftingInteractionMode" },
    },
    ["EVENT_END_CUTSCENE"] = {},
    ["EVENT_END_FAST_TRAVEL_INTERACTION"] = {},
    ["EVENT_END_FAST_TRAVEL_KEEP_INTERACTION"] = {},
    ["EVENT_END_KEEP_GUILD_CLAIM_INTERACTION"] = {},
    ["EVENT_END_KEEP_GUILD_RELEASE_INTERACTION"] = {},
    ["EVENT_END_SIEGE_CONTROL"] = {},
    ["EVENT_END_SOUL_GEM_RESURRECTION"] = {},
    ["EVENT_ENLIGHTENED_STATE_GAINED"] = {},
    ["EVENT_ENLIGHTENED_STATE_LOST"] = {},
    ["EVENT_ENTER_GROUND_TARGET_MODE"] = {},
    ["EVENT_ESO_PLUS_FREE_TRIAL_NOTIFICATION_CLEARED"] = {},
    ["EVENT_ESO_PLUS_FREE_TRIAL_STATUS_CHANGED"] = {
        { "hasFreeTrial", "bool" },
    },
    ["EVENT_EXPERIENCE_GAIN"] = {
        { "reason", "ProgressReason" },
        { "level", "integer" },
        { "previousExperience", "integer" },
        { "currentExperience", "integer" },
        { "championPoints", "integer" },
    },
    ["EVENT_EXPERIENCE_UPDATE"] = {
        { "unitTag", "string" },
        { "currentExp", "integer" },
        { "maxExp", "integer" },
        { "reason", "ProgressReason" },
    },
    ["EVENT_EXPIRING_MARKET_CURRENCY_NOTIFICATION"] = {},
    ["EVENT_EXPIRING_MARKET_CURRENCY_NOTIFICATION_CLEARED"] = {},
    ["EVENT_EXPIRING_MARKET_CURRENCY_STATE_UPDATED"] = {
        { "expiringMarketCurrencyState", "ExpiringMarketCurrencyState" },
    },
    ["EVENT_FAST_TRAVEL_KEEP_NETWORK_LINK_CHANGED"] = {
        { "linkIndex", "luaindex" },
        { "linkType", "FastTravelLinkType" },
        { "owningAlliance", "Alliance" },
        { "oldLinkType", "FastTravelLinkType" },
        { "oldOwningAlliance", "Alliance" },
        { "isLocal", "bool" },
    },
    ["EVENT_FAST_TRAVEL_KEEP_NETWORK_UPDATED"] = {},
    ["EVENT_FAST_TRAVEL_NETWORK_UPDATED"] = {
        { "nodeIndex", "luaindex" },
    },
    ["EVENT_FEEDBACK_REQUESTED"] = {
        { "feedbackId", "integer" },
    },
    ["EVENT_FEEDBACK_TOO_FREQUENT_SCREENSHOT"] = {},
    ["EVENT_FINESSE_RANK_CHANGED"] = {
        { "unitTag", "string" },
        { "rankNum", "luaindex" },
        { "name", "string" },
        { "xpBonus", "integer" },
        { "loot", "bool" },
    },
    ["EVENT_FISHING_LURE_CLEARED"] = {},
    ["EVENT_FISHING_LURE_SET"] = {
        { "fishingLure", "luaindex" },
    },
    ["EVENT_FIXED_BROADCAST"] = {
        { "broadcastType", "BroadcastType" },
        { "arg1", "integer" },
    },
    ["EVENT_FOLLOWER_SCENE_FINISHED_FRAGMENT_TRANSITION"] = {
        { "messageOrigin", "SceneManagerMessageOrigin" },
        { "sceneName", "string" },
        { "sequenceNumber", "integer" },
    },
    ["EVENT_FORCE_DISABLED_ADDONS_UPDATED"] = {},
    ["EVENT_FORCE_RESPEC"] = {
        { "respecType", "RespecType" },
    },
    ["EVENT_FORWARD_CAMPS_UPDATED"] = {},
    ["EVENT_FORWARD_CAMP_RESPAWN_TIMER_BEGINS"] = {
        { "durationMS", "integer" },
    },
    ["EVENT_FORWARD_TRANSCRIPT_TO_TEXT_CHAT_ACCESSIBILITY_SETTING_CHANGED"] = {},
    ["EVENT_FRIEND_ADDED"] = {
        { "displayName", "string" },
    },
    ["EVENT_FRIEND_CHARACTER_CHAMPION_POINTS_CHANGED"] = {
        { "displayName", "string" },
        { "characterName", "string" },
        { "championRank", "integer" },
    },
    ["EVENT_FRIEND_CHARACTER_INFO_RECEIVED"] = {
        { "displayName", "string" },
        { "hasCharacter", "bool" },
        { "characterName", "string" },
        { "zoneName", "string" },
        { "classType", "integer" },
        { "alliance", "Alliance" },
        { "level", "integer" },
        { "championPoints", "integer" },
    },
    ["EVENT_FRIEND_CHARACTER_LEVEL_CHANGED"] = {
        { "displayName", "string" },
        { "characterName", "string" },
        { "level", "integer" },
    },
    ["EVENT_FRIEND_CHARACTER_UPDATED"] = {
        { "displayName", "string" },
    },
    ["EVENT_FRIEND_CHARACTER_ZONE_CHANGED"] = {
        { "displayName", "string" },
        { "characterName", "string" },
        { "zoneName", "string" },
    },
    ["EVENT_FRIEND_DISPLAY_NAME_CHANGED"] = {
        { "oldDisplayName", "string" },
        { "newDisplayName", "string" },
    },
    ["EVENT_FRIEND_NOTE_UPDATED"] = {
        { "displayName", "string" },
        { "note", "string" },
    },
    ["EVENT_FRIEND_PLAYER_STATUS_CHANGED"] = {
        { "displayName", "string" },
        { "characterName", "string" },
        { "oldStatus", "PlayerStatus" },
        { "newStatus", "PlayerStatus" },
    },
    ["EVENT_FRIEND_REMOVED"] = {
        { "displayName", "string" },
    },
    ["EVENT_FULLSCREEN_MODE_CHANGED"] = {},
    ["EVENT_FURNITURE_ITEMS_TRANSFERRED_TO_FURNITURE_VAULT"] = {
        { "numEligibleSlotsTransferred", "integer" },
        { "numEligibleSlots", "integer" },
    },
    ["EVENT_GAMEPAD_PREFERRED_MODE_CHANGED"] = {
        { "gamepadPreferred", "bool" },
    },
    ["EVENT_GAMEPAD_TYPE_CHANGED"] = {
        { "gamepadType", "GamepadType" },
    },
    ["EVENT_GAMEPAD_USE_KEYBOARD_CHAT_CHANGED"] = {
        { "useKeyboardChat", "bool" },
    },
    ["EVENT_GAME_CAMERA_ACTIVATED"] = {},
    ["EVENT_GAME_CAMERA_CHARACTER_FRAMING_STARTED"] = {},
    ["EVENT_GAME_CAMERA_DEACTIVATED"] = {},
    ["EVENT_GAME_CAMERA_UI_MODE_CHANGED"] = {},
    ["EVENT_GAME_CREDITS_READY"] = {},
    ["EVENT_GAME_FOCUS_CHANGED"] = {
        { "hasFocus", "bool" },
    },
    ["EVENT_GENERIC_SELECTION_PROMPT_HIDE"] = {},
    ["EVENT_GENERIC_SELECTION_PROMPT_SHOW"] = {},
    ["EVENT_GIFTING_GRACE_PERIOD_STARTED"] = {},
    ["EVENT_GIFTING_UNLOCKED_STATUS_CHANGED"] = {
        { "isGiftingUnlocked", "bool" },
    },
    ["EVENT_GIFTS_UPDATED"] = {},
    ["EVENT_GIFT_ACTION_RESULT"] = {
        { "action", "GiftBoxAction" },
        { "result", "GiftBoxActionResult" },
        { "giftId", "id64" },
    },
    ["EVENT_GLOBAL_MOUSE_DOWN"] = {
        { "button", "MouseButtonIndex" },
        { "ctrl", "bool" },
        { "alt", "bool" },
        { "shift", "bool" },
        { "command", "bool" },
    },
    ["EVENT_GLOBAL_MOUSE_UP"] = {
        { "button", "MouseButtonIndex" },
        { "ctrl", "bool" },
        { "alt", "bool" },
        { "shift", "bool" },
        { "command", "bool" },
    },
    ["EVENT_GRAVEYARD_USAGE_FAILURE"] = {},
    ["EVENT_GROUPING_TOOLS_FIND_REPLACEMENT_NOTIFICATION_NEW"] = {},
    ["EVENT_GROUPING_TOOLS_FIND_REPLACEMENT_NOTIFICATION_REMOVED"] = {},
    ["EVENT_GROUPING_TOOLS_LFG_JOINED"] = {
        { "locationName", "string" },
    },
    ["EVENT_GROUPING_TOOLS_NO_LONGER_LFG"] = {},
    ["EVENT_GROUPING_TOOLS_READY_CHECK_CANCELLED"] = {
        { "reason", "LFGReadyCheckCancelReason" },
    },
    ["EVENT_GROUPING_TOOLS_READY_CHECK_UPDATED"] = {},
    ["EVENT_GROUP_ADD_ON_DATA_RECEIVED"] = {
        { "senderUnitTag", "string" },
        { "data1", "integer" },
        { "data2", "integer" },
        { "data3", "integer" },
        { "data4", "integer" },
        { "data5", "integer" },
        { "data6", "integer" },
        { "data7", "integer" },
        { "data8", "integer" },
    },
    ["EVENT_GROUP_CAMPAIGN_ASSIGNMENTS_CHANGED"] = {},
    ["EVENT_GROUP_ELECTION_FAILED"] = {
        { "failureReason", "GroupElectionFailure" },
        { "descriptor", "string" },
    },
    ["EVENT_GROUP_ELECTION_NOTIFICATION_ADDED"] = {},
    ["EVENT_GROUP_ELECTION_NOTIFICATION_REMOVED"] = {},
    ["EVENT_GROUP_ELECTION_PROGRESS_UPDATED"] = {},
    ["EVENT_GROUP_ELECTION_REQUESTED"] = {
        { "descriptor", "string" },
    },
    ["EVENT_GROUP_ELECTION_RESULT"] = {
        { "electionResult", "GroupElectionResult" },
        { "descriptor", "string" },
    },
    ["EVENT_GROUP_FINDER_APPLICATION_RECEIVED"] = {
        { "applicantCharId", "id64" },
    },
    ["EVENT_GROUP_FINDER_APPLY_TO_GROUP_LISTING_RESULT"] = {
        { "result", "GroupFinderActionResult" },
    },
    ["EVENT_GROUP_FINDER_CREATE_GROUP_LISTING_RESULT"] = {
        { "result", "GroupFinderActionResult" },
    },
    ["EVENT_GROUP_FINDER_GROUP_LISTING_ATTAINED_ROLES_CHANGED"] = {},
    ["EVENT_GROUP_FINDER_JOIN_GROUP_FAILED"] = {
        { "groupListingIndex", "luaindex" },
    },
    ["EVENT_GROUP_FINDER_LONG_SEARCH_WARNING"] = {},
    ["EVENT_GROUP_FINDER_MAX_SEARCHABLE"] = {},
    ["EVENT_GROUP_FINDER_MEMBER_ALERT"] = {
        { "alert", "GroupFinderMemberAlert" },
    },
    ["EVENT_GROUP_FINDER_REFRESH_SEARCH"] = {},
    ["EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_APPLICATION"] = {},
    ["EVENT_GROUP_FINDER_REMOVE_GROUP_LISTING_RESULT"] = {
        { "result", "RemoveGroupListingReason" },
    },
    ["EVENT_GROUP_FINDER_RESOLVE_GROUP_LISTING_APPLICATION_RESULT"] = {
        { "result", "ResolveGroupListingApplicationResponse" },
    },
    ["EVENT_GROUP_FINDER_SEARCH_COMPLETE"] = {
        { "result", "GroupFinderActionResult" },
        { "searchId", "integer" },
    },
    ["EVENT_GROUP_FINDER_SEARCH_COOLDOWN_UPDATE"] = {
        { "cooldownMs", "integer" },
    },
    ["EVENT_GROUP_FINDER_SEARCH_UPDATED"] = {
        { "searchId", "integer" },
    },
    ["EVENT_GROUP_FINDER_STATUS_UPDATED"] = {
        { "status", "GroupFinderStatus" },
    },
    ["EVENT_GROUP_FINDER_UPDATE_APPLICATIONS"] = {},
    ["EVENT_GROUP_FINDER_UPDATE_GROUP_LISTING_RESULT"] = {
        { "result", "GroupFinderActionResult" },
    },
    ["EVENT_GROUP_INVITE_ACCEPT_RESPONSE_TIMEOUT"] = {},
    ["EVENT_GROUP_INVITE_RECEIVED"] = {
        { "inviterCharacterName", "string" },
        { "inviterDisplayName", "string" },
    },
    ["EVENT_GROUP_INVITE_REMOVED"] = {},
    ["EVENT_GROUP_INVITE_RESPONSE"] = {
        { "inviterName", "string" },
        { "response", "GroupInviteResponse" },
        { "inviterDisplayName", "string" },
    },
    ["EVENT_GROUP_LISTING_INFO_REQUEST_COMPLETE"] = {
        { "groupListingId", "integer" },
    },
    ["EVENT_GROUP_MEMBER_ACCOUNT_NAME_UPDATED"] = {
        { "unitTag", "string" },
        { "accountName", "string" },
    },
    ["EVENT_GROUP_MEMBER_CONNECTED_STATUS"] = {
        { "unitTag", "string" },
        { "isOnline", "bool" },
    },
    ["EVENT_GROUP_MEMBER_IN_REMOTE_REGION"] = {
        { "unitTag", "string" },
        { "isInRemoteRegion", "bool" },
    },
    ["EVENT_GROUP_MEMBER_JOINED"] = {
        { "memberCharacterName", "string" },
        { "memberDisplayName", "string" },
        { "isLocalPlayer", "bool" },
    },
    ["EVENT_GROUP_MEMBER_LEFT"] = {
        { "memberCharacterName", "string" },
        { "reason", "GroupLeaveReason" },
        { "isLocalPlayer", "bool" },
        { "isLeader", "bool" },
        { "memberDisplayName", "string" },
        { "actionRequiredVote", "bool" },
    },
    ["EVENT_GROUP_MEMBER_POSITION_REQUEST_COMPLETE"] = {
        { "taskId", "integer" },
        { "charId", "id64" },
        { "isGroupLeader", "bool" },
        { "isBreadcrumb", "bool" },
        { "teleportNPCId", "integer" },
        { "waypointId", "integer" },
    },
    ["EVENT_GROUP_MEMBER_ROLE_CHANGED"] = {
        { "unitTag", "string" },
        { "newRole", "LFGRole" },
    },
    ["EVENT_GROUP_MEMBER_SUBZONE_CHANGED"] = {},
    ["EVENT_GROUP_NOTIFICATION_MESSAGE"] = {
        { "messageId", "integer" },
    },
    ["EVENT_GROUP_OPERATION_RESULT"] = {
        { "result", "GroupOperationResult" },
    },
    ["EVENT_GROUP_SUPPORT_RANGE_UPDATE"] = {
        { "unitTag", "string" },
        { "status", "bool" },
    },
    ["EVENT_GROUP_TYPE_CHANGED"] = {
        { "largeGroup", "bool" },
    },
    ["EVENT_GROUP_UPDATE"] = {},
    ["EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED"] = {
        { "isVeteranDifficulty", "bool" },
    },
    ["EVENT_GUILD_BANKED_MONEY_UPDATE"] = {
        { "newBankedMoney", "integer" },
        { "oldBankedMoney", "integer" },
    },
    ["EVENT_GUILD_BANK_DESELECTED"] = {},
    ["EVENT_GUILD_BANK_ITEMS_READY"] = {},
    ["EVENT_GUILD_BANK_ITEM_ADDED"] = {
        { "slotId", "integer" },
        { "addedByLocalPlayer", "bool" },
        { "itemSoundCategory", "ItemUISoundCategory" },
        { "isLastUpdateForMessage", "bool" },
    },
    ["EVENT_GUILD_BANK_ITEM_REMOVED"] = {
        { "slotId", "integer" },
        { "addedByLocalPlayer", "bool" },
        { "itemSoundCategory", "ItemUISoundCategory" },
        { "isLastUpdateForMessage", "bool" },
    },
    ["EVENT_GUILD_BANK_OPEN_ERROR"] = {
        { "reason", "GuildBankResult" },
    },
    ["EVENT_GUILD_BANK_SELECTED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_BANK_TRANSFER_ERROR"] = {
        { "reason", "GuildBankResult" },
    },
    ["EVENT_GUILD_BANK_UPDATED_QUANTITY"] = {
        { "slotId", "integer" },
    },
    ["EVENT_GUILD_CLAIM_KEEP_CAMPAIGN_NOTIFICATION"] = {
        { "campaignId", "integer" },
        { "keepId", "integer" },
        { "guildName", "string" },
        { "playerName", "string" },
    },
    ["EVENT_GUILD_CLAIM_KEEP_RESPONSE"] = {
        { "response", "ClaimKeepResultType" },
        { "keepId", "integer" },
    },
    ["EVENT_GUILD_DATA_LOADED"] = {},
    ["EVENT_GUILD_DESCRIPTION_CHANGED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_FINDER_APPLICATION_RESPONSE"] = {
        { "guildId", "integer" },
        { "result", "GuildApplicationResponse" },
    },
    ["EVENT_GUILD_FINDER_APPLICATION_RESULTS_GUILD"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_FINDER_APPLICATION_RESULTS_PLAYER"] = {},
    ["EVENT_GUILD_FINDER_BLACKLIST_RESPONSE"] = {
        { "guildId", "integer" },
        { "accountName", "string" },
        { "result", "GuildBlacklistResponse" },
    },
    ["EVENT_GUILD_FINDER_BLACKLIST_RESULTS"] = {},
    ["EVENT_GUILD_FINDER_GUILD_APPLICATIONS_VIEWED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_FINDER_GUILD_NEW_APPLICATIONS"] = {
        { "guildId", "integer" },
        { "numApplications", "integer" },
    },
    ["EVENT_GUILD_FINDER_LONG_SEARCH_WARNING"] = {},
    ["EVENT_GUILD_FINDER_PLAYER_APPLICATIONS_CHANGED"] = {
        { "numApplications", "integer" },
    },
    ["EVENT_GUILD_FINDER_PROCESS_APPLICATION_RESPONSE"] = {
        { "guildId", "integer" },
        { "accountName", "string" },
        { "result", "GuildProcessApplicationResponse" },
    },
    ["EVENT_GUILD_FINDER_SEARCH_COMPLETE"] = {
        { "searchId", "integer" },
    },
    ["EVENT_GUILD_FINDER_SEARCH_COOLDOWN_UPDATE"] = {
        { "cooldownMs", "integer" },
    },
    ["EVENT_GUILD_HISTORY_CATEGORY_UPDATED"] = {
        { "guildId", "integer" },
        { "eventCategory", "GuildHistoryEventCategory" },
        { "flags", "GuildHistoryCategoryUpdateFlags" },
    },
    ["EVENT_GUILD_HISTORY_REFRESHED"] = {},
    ["EVENT_GUILD_ID_CHANGED"] = {
        { "unitTag", "string" },
        { "oldGuildId", "integer" },
        { "newGuildId", "integer" },
    },
    ["EVENT_GUILD_INFO_REQUEST_COMPLETE"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_INVITES_INITIALIZED"] = {},
    ["EVENT_GUILD_INVITE_ADDED"] = {
        { "guildId", "integer" },
        { "guildName", "string" },
        { "guildAlliance", "Alliance" },
        { "inviterDisplayName", "string" },
    },
    ["EVENT_GUILD_INVITE_PLAYER_SUCCESSFUL"] = {
        { "playerName", "string" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_INVITE_REMOVED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_INVITE_TO_BLACKLISTED_PLAYER"] = {
        { "playerName", "string" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_KEEP_ATTACK_UPDATE"] = {
        { "channel", "ChannelType" },
        { "numGuardsKilled", "integer" },
        { "numAttackers", "integer" },
        { "location", "string" },
    },
    ["EVENT_GUILD_KEEP_CLAIM_UPDATED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_KIOSK_ACTIVE_BIDS_RESPONSE"] = {
        { "guildId", "integer" },
        { "result", "SocialActionResult" },
    },
    ["EVENT_GUILD_KIOSK_CONSIDER_BID_START"] = {},
    ["EVENT_GUILD_KIOSK_CONSIDER_BID_STOP"] = {},
    ["EVENT_GUILD_KIOSK_CONSIDER_PURCHASE_START"] = {},
    ["EVENT_GUILD_KIOSK_CONSIDER_PURCHASE_STOP"] = {},
    ["EVENT_GUILD_KIOSK_ERROR"] = {
        { "reason", "GuildKioskResult" },
    },
    ["EVENT_GUILD_KIOSK_RESULT"] = {
        { "guildKioskResult", "GuildKioskResult" },
    },
    ["EVENT_GUILD_LEVEL_CHANGED"] = {
        { "guildId", "integer" },
        { "level", "integer" },
    },
    ["EVENT_GUILD_LOST_KEEP_CAMPAIGN_NOTIFICATION"] = {
        { "campaignId", "integer" },
        { "keepId", "integer" },
        { "guildName", "string" },
    },
    ["EVENT_GUILD_MAIL_UPDATE"] = {},
    ["EVENT_GUILD_MEMBER_ADDED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
    },
    ["EVENT_GUILD_MEMBER_CHARACTER_CHAMPION_POINTS_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "characterName", "string" },
        { "championRank", "integer" },
    },
    ["EVENT_GUILD_MEMBER_CHARACTER_LEVEL_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "characterName", "string" },
        { "level", "integer" },
    },
    ["EVENT_GUILD_MEMBER_CHARACTER_UPDATED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
    },
    ["EVENT_GUILD_MEMBER_CHARACTER_ZONE_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "characterName", "string" },
        { "zone", "string" },
    },
    ["EVENT_GUILD_MEMBER_DEMOTE_SUCCESSFUL"] = {
        { "playerName", "string" },
        { "newRankIndex", "integer" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_MEMBER_NOTE_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "note", "string" },
    },
    ["EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "oldStatus", "integer" },
        { "newStatus", "integer" },
    },
    ["EVENT_GUILD_MEMBER_PROMOTE_SUCCESSFUL"] = {
        { "playerName", "string" },
        { "newRankIndex", "integer" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_MEMBER_RANK_CHANGED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "rankIndex", "luaindex" },
    },
    ["EVENT_GUILD_MEMBER_REMOVED"] = {
        { "guildId", "integer" },
        { "displayName", "string" },
        { "characterName", "string" },
    },
    ["EVENT_GUILD_MOTD_CHANGED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_NAME_AVAILABLE"] = {},
    ["EVENT_GUILD_PLAYER_RANK_CHANGED"] = {
        { "guildId", "integer" },
        { "rankIndex", "luaindex" },
        { "guildRankChangeAction", "GuildRankChangeAction" },
    },
    ["EVENT_GUILD_RANKS_CHANGED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_RANK_CHANGED"] = {
        { "guildId", "integer" },
        { "rankIndex", "luaindex" },
    },
    ["EVENT_GUILD_RECRUITMENT_INFO_UPDATED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_RELEASE_KEEP_CAMPAIGN_NOTIFICATION"] = {
        { "campaignId", "integer" },
        { "keepId", "integer" },
        { "guildName", "string" },
        { "playerName", "string" },
    },
    ["EVENT_GUILD_RELEASE_KEEP_RESPONSE"] = {
        { "response", "ReleaseKeepResultType" },
    },
    ["EVENT_GUILD_SELF_JOINED_GUILD"] = {
        { "guildServerId", "integer" },
        { "characterName", "string" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_SELF_LEFT_GUILD"] = {
        { "guildServerId", "integer" },
        { "characterName", "string" },
        { "guildId", "integer" },
    },
    ["EVENT_GUILD_TRADER_HIRED_UPDATED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_GUI_HIDDEN"] = {
        { "guiName", "string" },
        { "hidden", "bool" },
    },
    ["EVENT_GUI_UNLOADING"] = {
        { "guiName", "string" },
    },
    ["EVENT_GUI_WORLD_PARTICLE_EFFECT_READY"] = {
        { "particleEffectId", "integer" },
    },
    ["EVENT_HELP_INITIALIZED"] = {},
    ["EVENT_HELP_SEARCH_RESULTS_READY"] = {},
    ["EVENT_HERALDRY_CUSTOMIZATION_END"] = {},
    ["EVENT_HERALDRY_CUSTOMIZATION_START"] = {},
    ["EVENT_HERALDRY_FUNDS_UPDATED"] = {},
    ["EVENT_HERALDRY_SAVED"] = {},
    ["EVENT_HIDE_BOOK"] = {},
    ["EVENT_HIDE_OBJECTIVE_STATUS"] = {},
    ["EVENT_HIGH_FALL_DAMAGE"] = {},
    ["EVENT_HOLIDAYS_CHANGED"] = {},
    ["EVENT_HOTBAR_SLOT_CHANGE_REQUESTED"] = {
        { "newAbilityId", "integer" },
        { "actionSlotIndex", "luaindex" },
        { "hotbarCategory", "HotBarCategory" },
    },
    ["EVENT_HOTBAR_SLOT_STATE_UPDATED"] = {
        { "actionSlotIndex", "luaindex" },
        { "hotbarCategory", "HotBarCategory" },
    },
    ["EVENT_HOTBAR_SLOT_UPDATED"] = {
        { "actionSlotIndex", "luaindex" },
        { "hotbarCategory", "HotBarCategory" },
        { "justUnlocked", "bool" },
    },
    ["EVENT_HOT_BAR_RESULT"] = {
        { "reason", "HotBarResult" },
    },
    ["EVENT_HOUSE_FURNITURE_COUNT_UPDATED"] = {
        { "houseId", "integer" },
        { "furnitureCount", "integer" },
    },
    ["EVENT_HOUSE_TOURS_CURRENT_HOUSE_LISTING_UPDATED"] = {},
    ["EVENT_HOUSE_TOURS_HOUSE_RECOMMENDATION_COUNT_UPDATED"] = {
        { "houseId", "integer" },
        { "recommendationCount", "integer" },
    },
    ["EVENT_HOUSE_TOURS_LISTING_OPERATION_COOLDOWN_STATE_CHANGED"] = {
        { "isOnCooldown", "bool" },
    },
    ["EVENT_HOUSE_TOURS_LISTING_OPERATION_RESPONSE"] = {
        { "operationType", "HouseToursListingOperationType" },
        { "houseId", "integer" },
        { "result", "HouseTourListingResult" },
    },
    ["EVENT_HOUSE_TOURS_LISTING_OPERATION_STARTED"] = {
        { "operationType", "HouseToursListingOperationType" },
        { "houseId", "integer" },
    },
    ["EVENT_HOUSE_TOURS_LISTING_RECOMMENDED_NOTIFICATIONS_UPDATED"] = {},
    ["EVENT_HOUSE_TOURS_SAVE_FAVORITE_OPERATION_COMPLETE"] = {
        { "operationType", "HouseTourFavoriteOperationType" },
        { "result", "HouseTourSaveFavoriteResult" },
        { "ownerDisplayName", "string" },
        { "houseId", "integer" },
    },
    ["EVENT_HOUSE_TOURS_SAVE_RECOMMENDATION_OPERATION_COMPLETE"] = {
        { "result", "HouseTourSaveRecommendationResult" },
    },
    ["EVENT_HOUSE_TOURS_SEARCH_COMPLETE"] = {
        { "listingType", "HouseTourListingType" },
        { "result", "HouseTourRequestListingsResult" },
        { "searchId", "integer" },
    },
    ["EVENT_HOUSE_TOURS_SEARCH_COOLDOWN_COMPLETE"] = {},
    ["EVENT_HOUSE_TOURS_STATUS_UPDATED"] = {},
    ["EVENT_HOUSING_ADD_PERMISSIONS_CANT_ADD_SELF"] = {},
    ["EVENT_HOUSING_ADD_PERMISSIONS_FAILED"] = {
        { "userGroup", "HousePermissionUserGroup" },
        { "attemptedName", "string" },
    },
    ["EVENT_HOUSING_EDITOR_COMMAND_RESULT"] = {
        { "result", "HousingEditorCommandResult" },
    },
    ["EVENT_HOUSING_EDITOR_LINK_TARGET_CHANGED"] = {},
    ["EVENT_HOUSING_EDITOR_MODE_CHANGED"] = {
        { "oldMode", "HousingEditorMode" },
        { "newMode", "HousingEditorMode" },
    },
    ["EVENT_HOUSING_EDITOR_REQUEST_RESULT"] = {
        { "requestResult", "HousingRequestResult" },
    },
    ["EVENT_HOUSING_FURNITURE_MOVED"] = {
        { "furnitureId", "id64" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_DATA_CHANGED"] = {
        { "furnitureId", "id64" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_NODES_RESTORED"] = {
        { "furnitureId", "id64" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_NODE_ADDED"] = {
        { "furnitureId", "id64" },
        { "pathIndex", "luaindex" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_NODE_MOVED"] = {
        { "furnitureId", "id64" },
        { "pathIndex", "luaindex" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_NODE_REMOVED"] = {
        { "furnitureId", "id64" },
        { "pathIndex", "luaindex" },
    },
    ["EVENT_HOUSING_FURNITURE_PATH_STARTING_NODE_INDEX_CHANGED"] = {
        { "furnitureId", "id64" },
        { "startingPathIndex", "luaindex" },
    },
    ["EVENT_HOUSING_FURNITURE_PLACED"] = {
        { "furnitureId", "id64" },
        { "collectibleId", "integer" },
    },
    ["EVENT_HOUSING_FURNITURE_REMOVED"] = {
        { "furnitureId", "id64" },
        { "collectibleId", "integer" },
    },
    ["EVENT_HOUSING_FURNITURE_RETRIEVE_TO_BAG_CHANGED"] = {
        { "bagId", "Bag" },
    },
    ["EVENT_HOUSING_FURNITURE_STATE_CHANGED"] = {
        { "furnitureId", "id64" },
        { "objectStateIndex", "integer" },
        { "previousObjectStateId", "integer" },
        { "triggeredByFurnitureId", "id64" },
        { "reason", "HousingSetStateReason" },
    },
    ["EVENT_HOUSING_LOAD_PERMISSIONS_RESULT"] = {
        { "loadResult", "HousingLoadPermissionsResult" },
    },
    ["EVENT_HOUSING_OCCUPANT_ARRIVED"] = {
        { "crossplayDisplayName", "string" },
        { "characterName", "string" },
        { "platformDisplayName", "string" },
    },
    ["EVENT_HOUSING_OCCUPANT_DEPARTED"] = {
        { "crossplayDisplayName", "string" },
        { "characterName", "string" },
        { "platformDisplayName", "string" },
    },
    ["EVENT_HOUSING_PATH_NODE_SELECTION_CHANGED"] = {},
    ["EVENT_HOUSING_PERMISSIONS_CHANGED"] = {
        { "userGroup", "HousePermissionUserGroup" },
    },
    ["EVENT_HOUSING_PERMISSIONS_SAVE_COMPLETE"] = {},
    ["EVENT_HOUSING_PERMISSIONS_SAVE_PENDING"] = {},
    ["EVENT_HOUSING_PLAYER_INFO_CHANGED"] = {
        { "wasOwner", "bool" },
        { "permissionsChanged", "bool" },
        { "oldVisitorRole", "HousingVisitorRole" },
    },
    ["EVENT_HOUSING_POPULATION_CHANGED"] = {
        { "newPopulation", "integer" },
        { "previousPopulation", "integer" },
    },
    ["EVENT_HOUSING_PREVIEW_INSPECTION_STATE_CHANGED"] = {
        { "isPreviewInspectionEnabled", "bool" },
    },
    ["EVENT_HOUSING_PRIMARY_RESIDENCE_SET"] = {
        { "houseId", "integer" },
    },
    ["EVENT_HOUSING_TARGET_FURNITURE_CHANGED"] = {},
    ["EVENT_IGNORE_ADDED"] = {
        { "displayName", "string" },
    },
    ["EVENT_IGNORE_NOTE_UPDATED"] = {
        { "displayName", "string" },
        { "note", "string" },
    },
    ["EVENT_IGNORE_ONLINE_CHARACTER_CHANGED"] = {
        { "displayName", "string" },
    },
    ["EVENT_IGNORE_REMOVED"] = {
        { "displayName", "string" },
    },
    ["EVENT_IMPACTFUL_HIT"] = {},
    ["EVENT_INCOMING_FRIEND_INVITE_ADDED"] = {
        { "displayName", "string" },
    },
    ["EVENT_INCOMING_FRIEND_INVITE_NOTE_UPDATED"] = {
        { "displayName", "string" },
        { "message", "string" },
    },
    ["EVENT_INCOMING_FRIEND_INVITE_REMOVED"] = {
        { "displayName", "string" },
    },
    ["EVENT_INPUT_LANGUAGE_CHANGED"] = {},
    ["EVENT_INPUT_TYPE_CHANGED"] = {
        { "isGamepad", "bool" },
    },
    ["EVENT_INSTANCE_KICK_TIME_UPDATE"] = {
        { "timeRemainingMs", "integer" },
    },
    ["EVENT_INTERACTION_ENDED"] = {
        { "interactType", "InteractionType" },
        { "cancelContext", "InteractCancelContext" },
    },
    ["EVENT_INTERACT_BUSY"] = {},
    ["EVENT_INTERACT_VO_PLAYING_STATE_UPDATED"] = {},
    ["EVENT_INTERFACE_SETTING_CHANGED"] = {
        { "settingSystemType", "SettingSystemType" },
        { "settingId", "integer" },
    },
    ["EVENT_INTRO_GAMEPLAY_EXPERIENCE_JUMP_RESULT"] = {
        { "result", "IntroGameplayExperienceJumpResult" },
    },
    ["EVENT_INVENTORY_BAG_CAPACITY_CHANGED"] = {
        { "previousCapacity", "integer" },
        { "currentCapacity", "integer" },
        { "previousUpgrade", "integer" },
        { "currentUpgrade", "integer" },
    },
    ["EVENT_INVENTORY_BANK_CAPACITY_CHANGED"] = {
        { "previousCapacity", "integer" },
        { "currentCapacity", "integer" },
        { "previousUpgrade", "integer" },
        { "currentUpgrade", "integer" },
    },
    ["EVENT_INVENTORY_BOUGHT_BAG_SPACE"] = {
        { "numberOfSlots", "integer" },
    },
    ["EVENT_INVENTORY_BOUGHT_BANK_SPACE"] = {
        { "numberOfSlots", "integer" },
    },
    ["EVENT_INVENTORY_BUY_BAG_SPACE"] = {
        { "cost", "integer" },
    },
    ["EVENT_INVENTORY_BUY_BANK_SPACE"] = {
        { "cost", "integer" },
    },
    ["EVENT_INVENTORY_CLOSE_BUY_SPACE"] = {},
    ["EVENT_INVENTORY_EQUIP_MYTHIC_FAILED"] = {
        { "bagId", "Bag" },
        { "mythicSlotIndex", "integer" },
    },
    ["EVENT_INVENTORY_FULL_UPDATE"] = {},
    ["EVENT_INVENTORY_IS_FULL"] = {
        { "numSlotsRequested", "integer" },
        { "numSlotsFree", "integer" },
    },
    ["EVENT_INVENTORY_ITEMS_AUTO_TRANSFERRED_TO_CRAFT_BAG"] = {},
    ["EVENT_INVENTORY_ITEM_DESTROYED"] = {
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_INVENTORY_ITEM_USED"] = {
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_INVENTORY_SINGLE_SLOT_UPDATE"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
        { "isNewItem", "bool" },
        { "itemSoundCategory", "ItemUISoundCategory" },
        { "inventoryUpdateReason", "integer" },
        { "stackCountChange", "integer" },
        { "triggeredByCharacterName", "string:nilable" },
        { "triggeredByDisplayName", "string:nilable" },
        { "isLastUpdateForMessage", "bool" },
        { "bonusDropSource", "BonusDropSource" },
    },
    ["EVENT_INVENTORY_SLOT_LOCKED"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
    },
    ["EVENT_INVENTORY_SLOT_UNLOCKED"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
    },
    ["EVENT_ITEM_COMBINATION_RESULT"] = {
        { "itemCombinationResult", "ItemCombinationResult" },
    },
    ["EVENT_ITEM_LAUNDER_RESULT"] = {
        { "result", "ItemLaunderResult" },
    },
    ["EVENT_ITEM_ON_COOLDOWN"] = {},
    ["EVENT_ITEM_PREVIEW_READY"] = {},
    ["EVENT_ITEM_REPAIR_FAILURE"] = {
        { "reason", "ItemRepairReason" },
    },
    ["EVENT_ITEM_SET_COLLECTIONS_SEARCH_RESULTS_READY"] = {},
    ["EVENT_ITEM_SET_COLLECTIONS_UPDATED"] = {},
    ["EVENT_ITEM_SET_COLLECTION_SLOT_NEW_STATUS_CLEARED"] = {
        { "itemSetId", "integer" },
        { "itemSetCollectionSlot", "id64" },
    },
    ["EVENT_ITEM_SET_COLLECTION_UPDATED"] = {
        { "itemSetId", "integer" },
        { "slotsJustUnlockedMask", "id64" },
    },
    ["EVENT_ITEM_SLOT_CHANGED"] = {
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_JUMP_FAILED"] = {
        { "reason", "JumpResult" },
    },
    ["EVENT_JUSTICE_BEING_ARRESTED"] = {
        { "quitGame", "bool" },
    },
    ["EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED"] = {
        { "oldBounty", "integer" },
        { "newBounty", "integer" },
        { "isInitialize", "bool" },
    },
    ["EVENT_JUSTICE_FENCE_UPDATE"] = {
        { "sellsUsed", "integer" },
        { "laundersUsed", "integer" },
    },
    ["EVENT_JUSTICE_GOLD_PICKPOCKETED"] = {
        { "goldAmount", "integer" },
    },
    ["EVENT_JUSTICE_GOLD_REMOVED"] = {
        { "goldAmount", "integer" },
    },
    ["EVENT_JUSTICE_INFAMY_UPDATED"] = {
        { "oldInfamy", "integer" },
        { "newInfamy", "integer" },
        { "oldInfamyLevel", "InfamyThresholdsType" },
        { "newInfamyLevel", "InfamyThresholdsType" },
    },
    ["EVENT_JUSTICE_NOW_KOS"] = {},
    ["EVENT_JUSTICE_NO_LONGER_KOS"] = {},
    ["EVENT_JUSTICE_PICKPOCKET_FAILED"] = {},
    ["EVENT_JUSTICE_STOLEN_ITEMS_REMOVED"] = {},
    ["EVENT_KEEPS_INITIALIZED"] = {},
    ["EVENT_KEEP_ALLIANCE_OWNER_CHANGED"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
        { "owningAlliance", "Alliance" },
        { "oldOwningAlliance", "Alliance" },
    },
    ["EVENT_KEEP_END_INTERACTION"] = {},
    ["EVENT_KEEP_GATE_STATE_CHANGED"] = {
        { "keepId", "integer" },
        { "open", "bool" },
    },
    ["EVENT_KEEP_GUILD_CLAIM_UPDATE"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
    },
    ["EVENT_KEEP_INITIALIZED"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
    },
    ["EVENT_KEEP_IS_PASSABLE_CHANGED"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
        { "isPassable", "bool" },
    },
    ["EVENT_KEEP_PIECE_DIRECTIONAL_ACCESS_CHANGED"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
        { "directionalAccess", "KeepPieceDirectionalAccess" },
    },
    ["EVENT_KEEP_RESOURCE_UPDATE"] = {
        { "keepId", "integer" },
    },
    ["EVENT_KEEP_START_INTERACTION"] = {},
    ["EVENT_KEEP_UNDER_ATTACK_CHANGED"] = {
        { "keepId", "integer" },
        { "battlegroundContext", "integer" },
        { "underAttack", "bool" },
    },
    ["EVENT_KEYBINDINGS_LOADED"] = {},
    ["EVENT_KEYBINDING_CLEARED"] = {
        { "layerIndex", "luaindex" },
        { "categoryIndex", "luaindex" },
        { "actionIndex", "luaindex" },
        { "bindingIndex", "luaindex" },
    },
    ["EVENT_KEYBINDING_SET"] = {
        { "layerIndex", "luaindex" },
        { "categoryIndex", "luaindex" },
        { "actionIndex", "luaindex" },
        { "bindingIndex", "luaindex" },
        { "keyCode", "KeyCode" },
        { "mod1", "KeyCode" },
        { "mod2", "KeyCode" },
        { "mod3", "KeyCode" },
        { "mod4", "KeyCode" },
    },
    ["EVENT_KEYBIND_DISPLAY_MODE_CHANGED"] = {
        { "keybindDisplayMode", "KeybindDisplayMode" },
    },
    ["EVENT_KILL_LOCATIONS_UPDATED"] = {},
    ["EVENT_LEADERBOARD_SCORE_NOTIFICATION_ADDED"] = {
        { "notificationId", "integer" },
    },
    ["EVENT_LEADERBOARD_SCORE_NOTIFICATION_REMOVED"] = {
        { "notificationId", "integer" },
    },
    ["EVENT_LEADER_TO_FOLLOWER_SYNC"] = {
        { "messageOrigin", "SceneManagerMessageOrigin" },
        { "syncType", "RemoteSceneSyncType" },
        { "currentSceneName", "string" },
        { "nextSceneName", "string" },
        { "sequenceNumber", "integer" },
        { "currentSceneFragmentsComplete", "bool" },
    },
    ["EVENT_LEADER_UPDATE"] = {
        { "leaderTag", "string" },
    },
    ["EVENT_LEAVE_CAMPAIGN_QUEUE_RESPONSE"] = {
        { "response", "LeaveCampaignQueueResponseType" },
    },
    ["EVENT_LEAVE_RAM_ESCORT"] = {},
    ["EVENT_LEVEL_UPDATE"] = {
        { "unitTag", "string" },
        { "level", "integer" },
    },
    ["EVENT_LEVEL_UP_REWARD_CHOICE_UPDATED"] = {},
    ["EVENT_LEVEL_UP_REWARD_UPDATED"] = {},
    ["EVENT_LINKED_WORLD_POSITION_CHANGED"] = {},
    ["EVENT_LOCAL_PLAYER_MODEL_REBUILT"] = {},
    ["EVENT_LOCKPICK_BREAK_PREVENTED"] = {},
    ["EVENT_LOCKPICK_BROKE"] = {
        { "inactivityLengthMs", "integer" },
    },
    ["EVENT_LOCKPICK_FAILED"] = {},
    ["EVENT_LOCKPICK_SUCCESS"] = {},
    ["EVENT_LOGOUT_DEFERRED"] = {
        { "deferMilliseconds", "integer" },
        { "quitRequested", "bool" },
    },
    ["EVENT_LOGOUT_DISALLOWED"] = {
        { "quitRequested", "bool" },
    },
    ["EVENT_LOOT_CLOSED"] = {},
    ["EVENT_LOOT_ITEM_FAILED"] = {
        { "reason", "LootItemResult" },
        { "itemLink", "string" },
    },
    ["EVENT_LOOT_RECEIVED"] = {
        { "receivedBy", "string" },
        { "itemName", "string" },
        { "quantity", "integer" },
        { "soundCategory", "ItemUISoundCategory" },
        { "lootType", "LootItemType" },
        { "self", "bool" },
        { "isPickpocketLoot", "bool" },
        { "questItemIcon", "string" },
        { "itemId", "integer" },
        { "isStolen", "bool" },
    },
    ["EVENT_LOOT_UPDATED"] = {},
    ["EVENT_LORE_BOOK_ALREADY_KNOWN"] = {
        { "bookTitle", "string" },
    },
    ["EVENT_LORE_BOOK_COLLECTION_LEARNED"] = {
        { "categoryIndex", "luaindex" },
        { "collectionIndex", "luaindex" },
        { "numBooksLearned", "integer" },
    },
    ["EVENT_LORE_BOOK_LEARNED"] = {
        { "categoryIndex", "luaindex" },
        { "collectionIndex", "luaindex" },
        { "bookIndex", "luaindex" },
        { "guildIndex", "luaindex" },
        { "isMaxRank", "bool" },
    },
    ["EVENT_LORE_BOOK_LEARNED_SKILL_EXPERIENCE"] = {
        { "categoryIndex", "luaindex" },
        { "collectionIndex", "luaindex" },
        { "bookIndex", "luaindex" },
        { "guildIndex", "luaindex" },
        { "skillType", "SkillType" },
        { "skillLineIndex", "luaindex" },
        { "rank", "luaindex" },
        { "previousXP", "integer" },
        { "currentXP", "integer" },
    },
    ["EVENT_LORE_COLLECTION_COMPLETED"] = {
        { "categoryIndex", "luaindex" },
        { "collectionIndex", "luaindex" },
        { "guildIndex", "luaindex" },
        { "isMaxRank", "bool" },
    },
    ["EVENT_LORE_COLLECTION_COMPLETED_SKILL_EXPERIENCE"] = {
        { "categoryIndex", "luaindex" },
        { "collectionIndex", "luaindex" },
        { "guildIndex", "luaindex" },
        { "skillType", "SkillType" },
        { "skillLineIndex", "luaindex" },
        { "rank", "luaindex" },
        { "previousXP", "integer" },
        { "currentXP", "integer" },
    },
    ["EVENT_LORE_LIBRARY_INITIALIZED"] = {},
    ["EVENT_LOW_FALL_DAMAGE"] = {},
    ["EVENT_LUA_ERROR"] = {
        { "error", "string" },
        { "errorCode", "integer" },
    },
    ["EVENT_MAIL_ATTACHED_MONEY_CHANGED"] = {
        { "moneyAmount", "integer" },
    },
    ["EVENT_MAIL_ATTACHMENT_ADDED"] = {
        { "attachmentSlot", "luaindex" },
    },
    ["EVENT_MAIL_ATTACHMENT_REMOVED"] = {
        { "attachmentSlot", "luaindex" },
    },
    ["EVENT_MAIL_CLOSE_MAILBOX"] = {},
    ["EVENT_MAIL_COD_CHANGED"] = {
        { "codAmount", "integer" },
    },
    ["EVENT_MAIL_INBOX_UPDATE"] = {},
    ["EVENT_MAIL_LISTS_INITIALIZED"] = {},
    ["EVENT_MAIL_LISTS_UPDATED"] = {},
    ["EVENT_MAIL_NUM_UNREAD_CHANGED"] = {
        { "numUnread", "integer" },
    },
    ["EVENT_MAIL_OPEN_MAILBOX"] = {},
    ["EVENT_MAIL_READABLE"] = {
        { "mailId", "id64" },
    },
    ["EVENT_MAIL_REMOVED"] = {
        { "mailId", "id64" },
    },
    ["EVENT_MAIL_SEND_FAILED"] = {
        { "reason", "SendMailResult" },
    },
    ["EVENT_MAIL_SEND_SUCCESS"] = {
        { "playerName", "string" },
    },
    ["EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE"] = {
        { "result", "MailTakeAttachmentResult" },
        { "category", "MailCategory" },
        { "headersRemoved", "bool" },
    },
    ["EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS"] = {
        { "mailId", "id64" },
    },
    ["EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS"] = {
        { "mailId", "id64" },
    },
    ["EVENT_MAIL_WITH_ATTACHMENTS_AVAILABLE"] = {
        { "hasAttachments", "bool" },
        { "hasExpiringAttachments", "bool" },
    },
    ["EVENT_MAP_PING"] = {
        { "pingEventType", "MapPingEventType" },
        { "pingType", "MapDisplayPinType" },
        { "pingTag", "string" },
        { "offsetX", "number" },
        { "offsetY", "number" },
        { "isLocalPlayerOwner", "bool" },
    },
    ["EVENT_MARKET_ANNOUNCEMENT_UPDATED"] = {
        { "shouldShow", "bool" },
        { "isLocked", "bool" },
    },
    ["EVENT_MARKET_PRODUCTS_UNLOCKED"] = {},
    ["EVENT_MARKET_PRODUCTS_UNLOCKED_NOTIFICATIONS_CLEARED"] = {},
    ["EVENT_MARKET_PRODUCT_AVAILABILITY_UPDATED"] = {
        { "displayGroup", "MarketDisplayGroup" },
    },
    ["EVENT_MARKET_PURCHASE_RESULT"] = {
        { "purchaseResult", "MarketPurchasableResult" },
        { "tutorialProductId", "integer" },
        { "wasGift", "bool" },
    },
    ["EVENT_MARKET_STATE_UPDATED"] = {
        { "displayGroup", "MarketDisplayGroup" },
        { "marketState", "MarketState" },
    },
    ["EVENT_MATCH_TRADING_HOUSE_ITEM_NAMES_COMPLETE"] = {
        { "id", "integer" },
        { "numResults", "integer" },
        { "backgroundDurationMS", "integer" },
    },
    ["EVENT_MAX_CHARACTER_SLOTS_CHANGED"] = {
        { "newMaxCharacterSlots", "integer" },
    },
    ["EVENT_MEDAL_AWARDED"] = {
        { "medalId", "integer" },
        { "name", "string" },
        { "iconFilename", "string" },
        { "value", "integer" },
    },
    ["EVENT_MOD_BROWSER_SEARCH_COMPLETE"] = {
        { "result", "ModBrowserRequestListingsResult" },
        { "searchId", "integer" },
    },
    ["EVENT_MOD_INSTALL_STATE_CHANGED"] = {
        { "installState", "ModInstallState" },
    },
    ["EVENT_MOD_LISTING_DEPENDENCIES_LOAD_COMPLETE"] = {
        { "listingIndex", "luaindex" },
        { "result", "ModBrowserLoadDependenciesResult" },
    },
    ["EVENT_MOD_LISTING_IMAGE_LOAD_COMPLETE"] = {
        { "listingIndex", "luaindex" },
        { "imageIndex", "luaindex" },
        { "result", "ModBrowserLoadImageResult" },
    },
    ["EVENT_MOD_LISTING_RELEASE_NOTE_LOAD_COMPLETE"] = {
        { "listingIndex", "luaindex" },
        { "releaseIndex", "luaindex" },
        { "result", "ModBrowserLoadReleaseNoteResult" },
    },
    ["EVENT_MOD_LISTING_REPORT_SUBMITTED"] = {
        { "result", "ModBrowserListingReportResult" },
    },
    ["EVENT_MONEY_UPDATE"] = {
        { "newMoney", "integer" },
        { "oldMoney", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_MOST_RECENT_GAMEPAD_TYPE_CHANGED"] = {
        { "mostRecentGamepadType", "GamepadType" },
    },
    ["EVENT_MOUNTED_STATE_CHANGED"] = {
        { "mounted", "bool" },
    },
    ["EVENT_MOUNT_FAILURE"] = {
        { "reason", "MountFailureReason" },
        { "arg1", "integer" },
    },
    ["EVENT_MOUNT_INFO_UPDATED"] = {},
    ["EVENT_MOUSE_REQUEST_ABANDON_QUEST"] = {
        { "journalIndex", "luaindex" },
        { "name", "string" },
    },
    ["EVENT_MOUSE_REQUEST_DESTROY_ITEM"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
        { "itemCount", "integer" },
        { "name", "string" },
        { "needsConfirm", "bool" },
    },
    ["EVENT_MOUSE_REQUEST_DESTROY_ITEM_FAILED"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
        { "itemCount", "integer" },
        { "name", "string" },
        { "reason", "integer" },
    },
    ["EVENT_MULTIPLE_RECIPES_LEARNED"] = {
        { "numRecipesUnlocked", "integer" },
    },
    ["EVENT_MURDERBALL_STATE_CHANGED"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "objectiveName", "string" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "holderAlliance", "Alliance" },
        { "lastHolderAlliance", "Alliance" },
        { "holderRawCharacterName", "string" },
        { "holderDisplayName", "string" },
        { "lastHolderRawCharacterName", "string" },
        { "lastHolderDisplayName", "string" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_NEW_DAILY_LOGIN_REWARD_AVAILABLE"] = {},
    ["EVENT_NEW_HIRELING_CORRESPONDENCE_RECEIVED"] = {},
    ["EVENT_NEW_MOVEMENT_IN_UI_MODE"] = {},
    ["EVENT_NON_COMBAT_BONUS_CHANGED"] = {
        { "nonCombatBonus", "NonCombatBonusType" },
        { "oldValue", "integer" },
        { "newValue", "integer" },
    },
    ["EVENT_NOT_ENOUGH_MONEY"] = {},
    ["EVENT_NO_DAEDRIC_PICKUP_AS_EMPEROR"] = {},
    ["EVENT_NO_DAEDRIC_PICKUP_WHEN_STEALTHED"] = {},
    ["EVENT_NO_INTERACT_TARGET"] = {},
    ["EVENT_OBJECTIVES_UPDATED"] = {},
    ["EVENT_OBJECTIVE_COMPLETED"] = {
        { "zoneIndex", "luaindex" },
        { "poiIndex", "luaindex" },
        { "level", "integer" },
        { "previousExperience", "integer" },
        { "currentExperience", "integer" },
        { "championPoints", "integer" },
    },
    ["EVENT_OBJECTIVE_CONTROL_STATE"] = {
        { "objectiveKeepId", "integer" },
        { "objectiveObjectiveId", "integer" },
        { "battlegroundContext", "integer" },
        { "objectiveName", "string" },
        { "objectiveType", "ObjectiveType" },
        { "objectiveControlEvent", "ObjectiveControlEvent" },
        { "objectiveControlState", "ObjectiveControlState" },
        { "objectiveParam1", "integer" },
        { "objectiveParam2", "integer" },
        { "pinType", "MapDisplayPinType" },
    },
    ["EVENT_OPEN_ARMORY_MENU"] = {},
    ["EVENT_OPEN_BANK"] = {
        { "bankBag", "Bag" },
    },
    ["EVENT_OPEN_COMPANION_MENU"] = {},
    ["EVENT_OPEN_FENCE"] = {
        { "allowSell", "bool" },
        { "allowLaunder", "bool" },
    },
    ["EVENT_OPEN_GUILD_BANK"] = {},
    ["EVENT_OPEN_HOUSE_STORE"] = {},
    ["EVENT_OPEN_STORE"] = {},
    ["EVENT_OPEN_TIMED_ACTIVITIES"] = {},
    ["EVENT_OPEN_TRADING_HOUSE"] = {},
    ["EVENT_OPEN_TRIAL_PROGRESSION_SCREEN"] = {},
    ["EVENT_OPEN_UI_SYSTEM"] = {
        { "system", "UISystem" },
        { "param1", "integer" },
    },
    ["EVENT_OUTFITS_INITIALIZED"] = {},
    ["EVENT_OUTFIT_CHANGE_RESPONSE"] = {
        { "response", "ApplyOutfitChangesResult" },
        { "actorCategory", "GameplayActorCategory" },
        { "outfitIndex", "luaindex" },
    },
    ["EVENT_OUTFIT_EQUIP_RESPONSE"] = {
        { "actorCategory", "GameplayActorCategory" },
        { "response", "EquipOutfitResult" },
    },
    ["EVENT_OUTFIT_RENAME_RESPONSE"] = {
        { "response", "SetOutfitNameResult" },
        { "actorCategory", "GameplayActorCategory" },
        { "outfitIndex", "luaindex" },
    },
    ["EVENT_OUTGOING_FRIEND_INVITE_ADDED"] = {
        { "displayName", "string" },
    },
    ["EVENT_OUTGOING_FRIEND_INVITE_REMOVED"] = {
        { "displayName", "string" },
    },
    ["EVENT_OVERLAND_DIFFICULTY_CHANGED"] = {
        { "newValue", "OverlandDifficultyType" },
    },
    ["EVENT_OVERLAND_DIFFICULTY_DISABLED_BY_SERVER_CHANGED"] = {
        { "newValue", "bool" },
    },
    ["EVENT_PATH_FINDING_NETWORK_LINK_CHANGED"] = {},
    ["EVENT_PENDING_CURRENCY_REWARD_CACHED"] = {
        { "currencyType", "CurrencyType" },
        { "currencyLocation", "CurrencyLocation" },
        { "amount", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_PENDING_EXPERIENCE_REWARD_CACHED"] = {
        { "reason", "ProgressReason" },
        { "amount", "integer" },
    },
    ["EVENT_PENDING_INTERACTION_CANCELLED"] = {},
    ["EVENT_PERSONALITY_CHANGED"] = {},
    ["EVENT_PICKPOCKET_STATE_UPDATED"] = {},
    ["EVENT_PLATFORMS_LIST_LOADED"] = {
        { "server", "ConsoleServerChoice" },
    },
    ["EVENT_PLATFORM_ACHIEVEMENT_TRIGGERED"] = {},
    ["EVENT_PLATFORM_STORE_DIALOG_FINISHED"] = {
        { "result", "PlatformStoreDialogResult" },
    },
    ["EVENT_PLAYER_ACTIVATED"] = {
        { "initial", "bool" },
    },
    ["EVENT_PLAYER_ACTIVELY_ENGAGED_STATE"] = {
        { "isActivelyEngaged", "bool" },
    },
    ["EVENT_PLAYER_ALIVE"] = {},
    ["EVENT_PLAYER_COMBAT_STATE"] = {
        { "inCombat", "bool" },
    },
    ["EVENT_PLAYER_DEACTIVATED"] = {},
    ["EVENT_PLAYER_DEAD"] = {},
    ["EVENT_PLAYER_DEATH_INFO_UPDATE"] = {},
    ["EVENT_PLAYER_DEATH_REQUEST_FAILURE"] = {},
    ["EVENT_PLAYER_EMOTE_FAILED_PLAY"] = {
        { "failure", "PlayerEmotePlayFailure" },
    },
    ["EVENT_PLAYER_IN_PIN_AREA_CHANGED"] = {
        { "pinType", "MapDisplayPinType" },
        { "param1", "integer" },
        { "param2", "integer" },
        { "param3", "integer" },
        { "playerIsInside", "bool" },
    },
    ["EVENT_PLAYER_NOT_SWIMMING"] = {},
    ["EVENT_PLAYER_QUEUED_FOR_CYCLIC_RESPAWN"] = {},
    ["EVENT_PLAYER_REINCARNATED"] = {},
    ["EVENT_PLAYER_STATUS_CHANGED"] = {
        { "oldStatus", "PlayerStatus" },
        { "newStatus", "PlayerStatus" },
    },
    ["EVENT_PLAYER_STUNNED_STATE_CHANGED"] = {
        { "playerStunned", "bool" },
    },
    ["EVENT_PLAYER_SWIMMING"] = {},
    ["EVENT_PLAYER_TELEPORTED_LOCALLY"] = {},
    ["EVENT_PLAYER_TITLES_UPDATE"] = {},
    ["EVENT_PLEDGE_OF_MARA_OFFER"] = {
        { "targetCharacterName", "string" },
        { "isSender", "bool" },
        { "targetDisplayName", "string" },
    },
    ["EVENT_PLEDGE_OF_MARA_OFFER_REMOVED"] = {},
    ["EVENT_PLEDGE_OF_MARA_RESULT"] = {
        { "reason", "PledgeOfMaraResult" },
        { "targetCharacterName", "string" },
        { "targetDisplayName", "string" },
    },
    ["EVENT_POIS_INITIALIZED"] = {},
    ["EVENT_POI_DISCOVERED"] = {
        { "zoneIndex", "luaindex" },
        { "poiIndex", "luaindex" },
    },
    ["EVENT_POI_UPDATED"] = {
        { "zoneIndex", "luaindex" },
        { "poiIndex", "luaindex" },
    },
    ["EVENT_POWER_UPDATE"] = {
        { "unitTag", "string" },
        { "powerIndex", "luaindex" },
        { "powerType", "CombatMechanicFlags" },
        { "powerValue", "integer" },
        { "powerMax", "integer" },
        { "powerEffectiveMax", "integer" },
    },
    ["EVENT_PREPARE_FOR_JUMP"] = {
        { "zoneName", "string" },
        { "zoneDescription", "string" },
        { "loadingTexture", "string" },
        { "zoneDisplayType", "ZoneDisplayType" },
    },
    ["EVENT_PREVIEW_COLLECTIBLE_ACTION_RESET"] = {},
    ["EVENT_PROFILE_CARD_DIALOG_CLOSED"] = {},
    ["EVENT_PROFILE_CARD_DIALOG_OPENED"] = {},
    ["EVENT_PROFILE_DURANGO_SIGNED_OUT"] = {},
    ["EVENT_PROFILE_LOGIN_REQUESTED"] = {},
    ["EVENT_PROFILE_LOGIN_RESULT"] = {
        { "isSuccess", "bool" },
        { "error", "ProfileLoginError" },
    },
    ["EVENT_PROFILE_ORBIS_SIGNED_OUT"] = {},
    ["EVENT_PROFILE_SAVELOAD_FAIL"] = {
        { "failReason", "string" },
    },
    ["EVENT_PROFILE_SAVELOAD_REQUESTED"] = {},
    ["EVENT_PROFILE_SAVELOAD_SUCCESSFUL"] = {},
    ["EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED"] = {
        { "campaignKey", "id64" },
        { "activityIndex", "luaindex" },
        { "previousProgress", "integer" },
        { "newProgress", "integer" },
        { "rewardFlags", "PromotionalEventRewardFlags" },
    },
    ["EVENT_PROMOTIONAL_EVENTS_ACTIVITY_TRACKING_UPDATED"] = {
        { "trackedCampaignKey", "id64" },
        { "trackedActivityIndex", "luaindex" },
    },
    ["EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED"] = {},
    ["EVENT_PROMOTIONAL_EVENTS_REWARDS_CLAIMED"] = {
        { "campaignKey", "id64" },
    },
    ["EVENT_PVP_KILL_FEED_DEATH"] = {
        { "killLocation", "string" },
        { "killerPlayerDisplayName", "string" },
        { "killerPlayerCharacterName", "string" },
        { "killerPlayerAlliance", "Alliance" },
        { "killerPlayerRank", "integer" },
        { "victimPlayerDisplayName", "string" },
        { "victimPlayerCharacterName", "string" },
        { "victimPlayerAlliance", "Alliance" },
        { "victimPlayerRank", "integer" },
        { "isKillLocation", "bool" },
    },
    ["EVENT_QUEST_ADDED"] = {
        { "journalIndex", "luaindex" },
        { "questName", "string" },
        { "objectiveName", "string" },
    },
    ["EVENT_QUEST_ADVANCED"] = {
        { "journalIndex", "luaindex" },
        { "questName", "string" },
        { "isPushed", "bool" },
        { "isComplete", "bool" },
        { "mainStepChanged", "bool" },
        { "hideAnnouncement", "bool" },
    },
    ["EVENT_QUEST_COMPLETE"] = {
        { "questName", "string" },
        { "level", "integer" },
        { "previousExperience", "integer" },
        { "currentExperience", "integer" },
        { "championPoints", "integer" },
        { "questType", "QuestType" },
        { "zoneDisplayType", "ZoneDisplayType" },
    },
    ["EVENT_QUEST_COMPLETE_ATTEMPT_FAILED_INVENTORY_FULL"] = {},
    ["EVENT_QUEST_COMPLETE_DIALOG"] = {
        { "journalIndex", "luaindex" },
    },
    ["EVENT_QUEST_CONDITION_COUNTER_CHANGED"] = {
        { "journalIndex", "luaindex" },
        { "questName", "string" },
        { "conditionText", "string" },
        { "conditionType", "QuestConditionType" },
        { "currConditionVal", "integer" },
        { "newConditionVal", "integer" },
        { "conditionMax", "integer" },
        { "isFailCondition", "bool" },
        { "stepOverrideText", "string" },
        { "isPushed", "bool" },
        { "isComplete", "bool" },
        { "isConditionComplete", "bool" },
        { "isStepHidden", "bool" },
        { "isConditionCompleteStatusChanged", "bool" },
        { "isConditionCompletableBySiblingStatusChanged", "bool" },
    },
    ["EVENT_QUEST_CONDITION_OVERRIDE_TEXT_CHANGED"] = {
        { "journalIndex", "luaindex" },
    },
    ["EVENT_QUEST_LIST_UPDATED"] = {},
    ["EVENT_QUEST_LOG_IS_FULL"] = {},
    ["EVENT_QUEST_OFFERED"] = {},
    ["EVENT_QUEST_OPTIONAL_STEP_ADVANCED"] = {
        { "text", "string" },
    },
    ["EVENT_QUEST_POSITION_REQUEST_COMPLETE"] = {
        { "taskId", "integer" },
        { "pinType", "MapDisplayPinType" },
        { "xLoc", "number" },
        { "yLoc", "number" },
        { "areaRadius", "number" },
        { "insideCurrentMapWorld", "bool" },
        { "isBreadcrumb", "bool" },
        { "teleportNPCId", "integer" },
        { "waypointId", "integer" },
        { "symbolicState", "QuestPinPositionSymbolicState" },
        { "additionalSymbolicLocX", "number" },
        { "additionalSymbolicLocY", "number" },
    },
    ["EVENT_QUEST_REMOVED"] = {
        { "isCompleted", "bool" },
        { "journalIndex", "luaindex" },
        { "questName", "string" },
        { "zoneIndex", "luaindex" },
        { "poiIndex", "luaindex" },
        { "questID", "integer" },
    },
    ["EVENT_QUEST_SHARED"] = {
        { "questId", "integer" },
    },
    ["EVENT_QUEST_SHARE_REMOVED"] = {
        { "questId", "integer" },
    },
    ["EVENT_QUEST_SHARE_RESULT"] = {
        { "shareTargetCharacterName", "string" },
        { "shareTargetDisplayName", "string" },
        { "questName", "string" },
        { "result", "QuestShareResult" },
    },
    ["EVENT_QUEST_SHOW_JOURNAL_ENTRY"] = {
        { "journalIndex", "luaindex" },
    },
    ["EVENT_QUEST_TIMER_PAUSED"] = {
        { "journalIndex", "luaindex" },
        { "isPaused", "bool" },
    },
    ["EVENT_QUEST_TIMER_UPDATED"] = {
        { "journalIndex", "luaindex" },
    },
    ["EVENT_QUEST_TOOL_UPDATED"] = {
        { "journalIndex", "luaindex" },
        { "questName", "string" },
        { "countDelta", "integer" },
        { "iconFilename", "string" },
        { "questItemId", "integer" },
        { "name", "string" },
    },
    ["EVENT_QUEUE_FOR_CAMPAIGN_RESPONSE"] = {
        { "response", "QueueForCampaignResponseType" },
        { "parameter", "integer" },
    },
    ["EVENT_RAID_LEADERBOARD_DATA_RECEIVED"] = {
        { "raidCategory", "RaidCategory" },
        { "raidId", "integer" },
    },
    ["EVENT_RAID_LEADERBOARD_PLAYER_DATA_CHANGED"] = {},
    ["EVENT_RAID_OF_THE_WEEK_INFO_RECEIVED"] = {},
    ["EVENT_RAID_OF_THE_WEEK_TURNOVER"] = {},
    ["EVENT_RAID_PARTICIPATION_UPDATE"] = {},
    ["EVENT_RAID_REVIVE_COUNTER_UPDATE"] = {
        { "currentCounter", "integer" },
        { "countDelta", "integer" },
    },
    ["EVENT_RAID_TIMER_STATE_UPDATE"] = {},
    ["EVENT_RAID_TRIAL_COMPLETE"] = {
        { "trialName", "string" },
        { "score", "integer" },
        { "totalTime", "integer" },
    },
    ["EVENT_RAID_TRIAL_FAILED"] = {
        { "trialName", "string" },
        { "score", "integer" },
    },
    ["EVENT_RAID_TRIAL_NEW_BEST_SCORE"] = {
        { "trialName", "string" },
        { "score", "integer" },
        { "isWeekly", "bool" },
    },
    ["EVENT_RAID_TRIAL_RESET_BEST_SCORE"] = {
        { "trialName", "string" },
        { "isWeekly", "bool" },
    },
    ["EVENT_RAID_TRIAL_SCORE_UPDATE"] = {
        { "scoreUpdateReason", "RaidPointReason" },
        { "scoreAmount", "integer" },
        { "totalScore", "integer" },
    },
    ["EVENT_RAID_TRIAL_STARTED"] = {
        { "trialName", "string" },
        { "weekly", "bool" },
    },
    ["EVENT_RAM_ESCORT_COUNT_UPDATE"] = {
        { "numEscorts", "integer" },
    },
    ["EVENT_RANDOM_DICE_ROLL"] = {
        { "crossplayDisplayName", "string" },
        { "characterName", "string" },
        { "maxValue", "integer" },
        { "numDice", "integer" },
        { "modifier", "integer" },
        { "rollResult", "integer" },
        { "platformDisplayName", "string" },
    },
    ["EVENT_RANDOM_MOUNT_SETTING_CHANGED"] = {
        { "playerRandomMountType", "RandomMountType" },
        { "companionRandomMountType", "RandomMountType" },
    },
    ["EVENT_RANDOM_RANGE_ROLL"] = {
        { "crossplayDisplayName", "string" },
        { "characterName", "string" },
        { "minValue", "integer" },
        { "maxValue", "integer" },
        { "rollResult", "integer" },
        { "platformDisplayName", "string" },
    },
    ["EVENT_RANK_POINT_UPDATE"] = {
        { "unitTag", "string" },
        { "rankPoints", "integer" },
        { "difference", "integer" },
    },
    ["EVENT_RECALL_KEEP_USE_RESULT"] = {
        { "result", "KeepRecallStoneUseResult" },
    },
    ["EVENT_RECIPE_ALREADY_KNOWN"] = {},
    ["EVENT_RECIPE_LEARNED"] = {
        { "recipeListIndex", "luaindex" },
        { "recipeIndex", "luaindex" },
    },
    ["EVENT_RECONSTRUCT_RESPONSE"] = {
        { "responseCode", "ReconstructResponse" },
    },
    ["EVENT_RECONSTRUCT_STARTED"] = {},
    ["EVENT_REMOTE_SCENE_REQUEST"] = {
        { "messageOrigin", "SceneManagerMessageOrigin" },
        { "requestType", "RemoteSceneRequestType" },
        { "sceneName", "string" },
    },
    ["EVENT_REMOTE_TOP_LEVEL_CHANGE"] = {
        { "messageOrigin", "SceneManagerMessageOrigin" },
        { "requestType", "RemoteSceneRequestType" },
    },
    ["EVENT_REMOVE_ACTIVE_COMBAT_TIP"] = {
        { "activeCombatTipId", "integer" },
        { "result", "ActiveCombatTipConditionResult" },
    },
    ["EVENT_REMOVE_TUTORIAL"] = {
        { "tutorialIndex", "luaindex" },
    },
    ["EVENT_REQUEST_ALERT"] = {
        { "alertCategory", "UIAlertCategory" },
        { "soundId", "string" },
        { "message", "string" },
    },
    ["EVENT_REQUEST_CONFIRM_USE_ITEM"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
    },
    ["EVENT_REQUEST_CROWN_GEM_TUTORIAL"] = {},
    ["EVENT_REQUEST_SHOW_GAMEPAD_CHAPTER_UPGRADE"] = {
        { "chapterUpgradeId", "integer" },
    },
    ["EVENT_REQUEST_SHOW_GIFT_INVENTORY"] = {},
    ["EVENT_REQUIREMENTS_FAIL"] = {
        { "errorId", "integer" },
    },
    ["EVENT_RESEND_VERIFICATION_EMAIL_RESULT"] = {
        { "success", "bool" },
    },
    ["EVENT_RESUME_FROM_SUSPEND"] = {},
    ["EVENT_RESURRECT_REQUEST"] = {
        { "requesterCharacterName", "string" },
        { "timeLeftToAccept", "integer" },
        { "requesterDisplayName", "string" },
    },
    ["EVENT_RESURRECT_REQUEST_REMOVED"] = {},
    ["EVENT_RESURRECT_RESULT"] = {
        { "targetCharacterName", "string" },
        { "result", "ResurrectResult" },
        { "targetDisplayName", "string" },
    },
    ["EVENT_RETICLE_HIDDEN_UPDATE"] = {
        { "hidden", "bool" },
    },
    ["EVENT_RETICLE_TARGET_CHANGED"] = {},
    ["EVENT_RETICLE_TARGET_COMPANION_CHANGED"] = {},
    ["EVENT_RETICLE_TARGET_PLAYER_CHANGED"] = {},
    ["EVENT_RETRAIT_RESPONSE"] = {
        { "responseCode", "RetraitResponse" },
    },
    ["EVENT_RETRAIT_STARTED"] = {},
    ["EVENT_RETRAIT_STATION_INTERACT_START"] = {},
    ["EVENT_RETURNING_PLAYER_DAILY_LOGIN_REWARD_CLAIMED"] = {},
    ["EVENT_REVEAL_ANTIQUITY_DIG_SITES_ON_MAP"] = {
        { "antiquityId", "integer" },
    },
    ["EVENT_REVENGE_KILL"] = {
        { "killedCharacterName", "string" },
        { "killedDisplayName", "string" },
    },
    ["EVENT_REWARD_TRACK_PROGRESS_GAINED"] = {
        { "rewardTrackType", "RewardTrackType" },
        { "trackId", "integer" },
        { "previousTier", "luaindex" },
        { "newTier", "luaindex" },
        { "newProgress", "integer" },
    },
    ["EVENT_REWARD_TRACK_REWARDS_CLAIMED"] = {
        { "rewardTrackType", "RewardTrackType" },
        { "trackId", "integer" },
        { "highestRewardClaimed", "luaindex" },
        { "numRepeatableRewardsClaimed", "integer" },
    },
    ["EVENT_REWARD_TRACK_REWARD_CLAIMED"] = {
        { "rewardTrackType", "RewardTrackType" },
        { "trackId", "integer" },
        { "tier", "luaindex" },
        { "rewardComponent", "RewardTrackComponent" },
        { "rewardIndex", "luaindex" },
        { "isFallback", "bool" },
        { "numRepeatableRewardsClaimed", "integer" },
    },
    ["EVENT_REWARD_TRACK_SETTINGS_UPDATE_RECEIVED"] = {},
    ["EVENT_REWARD_TRACK_STARTED"] = {
        { "rewardTrackType", "RewardTrackType" },
        { "trackId", "integer" },
    },
    ["EVENT_REWARD_TRACK_UPDATE_RECEIVED"] = {},
    ["EVENT_RIDING_SKILL_IMPROVEMENT"] = {
        { "ridingSkillType", "RidingTrainType" },
        { "previous", "integer" },
        { "current", "integer" },
        { "source", "RidingTrainSource" },
    },
    ["EVENT_RUMORS_UPDATED"] = {},
    ["EVENT_RUMOR_COMPLETED"] = {
        { "rumorId", "integer" },
    },
    ["EVENT_RUMOR_ENDING_INITIATED"] = {
        { "rumorId", "integer" },
        { "rumorEndingId", "integer" },
    },
    ["EVENT_RUMOR_NEW_STATUS_CLEARED"] = {
        { "rumorId", "integer" },
    },
    ["EVENT_RUMOR_STARTED"] = {
        { "rumorId", "integer" },
    },
    ["EVENT_RUMOR_START_FAILED"] = {
        { "rumorId", "integer" },
        { "reason", "StartRumorFailReason" },
    },
    ["EVENT_RUMOR_UPDATED"] = {
        { "rumorId", "integer" },
    },
    ["EVENT_SAVE_DATA_COMPLETE"] = {},
    ["EVENT_SAVE_DATA_START"] = {},
    ["EVENT_SAVE_GUILD_RANKS_RESPONSE"] = {
        { "guildId", "integer" },
        { "result", "SocialActionResult" },
    },
    ["EVENT_SCREENSHOT_SAVED"] = {
        { "directory", "string" },
        { "filename", "string" },
    },
    ["EVENT_SCREEN_RESIZED"] = {
        { "width", "integer" },
        { "height", "integer" },
    },
    ["EVENT_SCRIBING_DISABLED"] = {},
    ["EVENT_SCRIBING_ERROR_RESULT"] = {
        { "result", "ScribingErrorResult" },
    },
    ["EVENT_SCRIBING_ITEM_USE_RESULT"] = {
        { "result", "ScribingItemUseResult" },
    },
    ["EVENT_SCRIPTED_WORLD_EVENT_INVITE"] = {
        { "eventId", "integer" },
        { "scriptedEventName", "string" },
        { "inviterName", "string" },
        { "questName", "string" },
    },
    ["EVENT_SCRIPTED_WORLD_EVENT_INVITE_REMOVED"] = {
        { "eventId", "integer" },
    },
    ["EVENT_SCRIPT_ACCESS_VIOLATION"] = {
        { "protectedFunctionName", "string" },
    },
    ["EVENT_SCRYING_ACTIVE_SKILL_USE_RESULT"] = {
        { "result", "ScryingActiveSkillUseResult" },
    },
    ["EVENT_SCRYING_EXIT_RESPONSE"] = {
        { "accept", "bool" },
    },
    ["EVENT_SECURE_3D_RENDER_MODE_CHANGED"] = {
        { "enabled", "bool" },
    },
    ["EVENT_SECURE_RENDER_MODE_CHANGED"] = {
        { "enabled", "bool" },
    },
    ["EVENT_SELECT_FROM_USER_LIST_DIALOG_RESULT"] = {
        { "hasResult", "bool" },
        { "displayName", "string" },
        { "consoleId", "id64" },
    },
    ["EVENT_SELL_RECEIPT"] = {
        { "itemName", "string" },
        { "itemQuantity", "integer" },
        { "money", "integer" },
    },
    ["EVENT_SET_SUBTITLE"] = {
        { "subtitleText", "string" },
    },
    ["EVENT_SHOW_BOOK"] = {
        { "bookTitle", "string" },
        { "body", "string" },
        { "mediumId", "integer" },
        { "showTitle", "bool" },
        { "bookId", "integer" },
    },
    ["EVENT_SHOW_DAILY_LOGIN_REWARDS_SCENE"] = {},
    ["EVENT_SHOW_PREGAME_GUI_IN_STATE"] = {
        { "desiredStateName", "string" },
    },
    ["EVENT_SHOW_SPECIFIC_HELP_PAGE"] = {
        { "helpCategoryIndex", "luaindex" },
        { "helpIndex", "luaindex" },
    },
    ["EVENT_SHOW_SUBTITLE"] = {
        { "channelType", "ChannelType" },
        { "speakerName", "string" },
        { "text", "string" },
    },
    ["EVENT_SHOW_TREASURE_MAP"] = {
        { "treasureMapIndex", "luaindex" },
    },
    ["EVENT_SHOW_WORLD_MAP"] = {},
    ["EVENT_SHOW_ZONE_STORIES_SCENE"] = {
        { "zoneId", "integer" },
    },
    ["EVENT_SIEGE_BUSY"] = {
        { "siegeName", "string" },
    },
    ["EVENT_SIEGE_CONTROL_ANOTHER_PLAYER"] = {
        { "siegeName", "string" },
    },
    ["EVENT_SIEGE_CREATION_FAILED_CLOSEST_DOOR_ALREADY_HAS_RAM"] = {},
    ["EVENT_SIEGE_CREATION_FAILED_NO_VALID_DOOR"] = {},
    ["EVENT_SIEGE_FIRE_FAILED_COOLDOWN"] = {},
    ["EVENT_SIEGE_FIRE_FAILED_RETARGETING"] = {},
    ["EVENT_SIEGE_PACK_FAILED_INVENTORY_FULL"] = {},
    ["EVENT_SIEGE_PACK_FAILED_NOT_CREATOR"] = {},
    ["EVENT_SKILLS_FULL_UPDATE"] = {},
    ["EVENT_SKILL_BUILD_SELECTION_UPDATED"] = {},
    ["EVENT_SKILL_LINE_ADDED"] = {
        { "skillType", "SkillType" },
        { "skillLineIndex", "luaindex" },
        { "advised", "bool" },
    },
    ["EVENT_SKILL_POINTS_CHANGED"] = {
        { "pointsBefore", "integer" },
        { "pointsNow", "integer" },
        { "partialPointsBefore", "integer" },
        { "partialPointsNow", "integer" },
        { "skillPointChangeReason", "SkillPointReason" },
    },
    ["EVENT_SKILL_RANK_UPDATE"] = {
        { "skillType", "SkillType" },
        { "skillLineIndex", "luaindex" },
        { "rank", "luaindex" },
    },
    ["EVENT_SKILL_RESPEC_RESULT"] = {
        { "result", "RespecResult" },
    },
    ["EVENT_SKILL_STYLE_DISABLED_BY_SERVER"] = {
        { "isDisabled", "bool" },
    },
    ["EVENT_SKILL_XP_UPDATE"] = {
        { "skillType", "SkillType" },
        { "skillLineIndex", "luaindex" },
        { "reason", "integer" },
        { "rank", "luaindex" },
        { "previousXP", "integer" },
        { "currentXP", "integer" },
    },
    ["EVENT_SKYSHARDS_UPDATED"] = {},
    ["EVENT_SLD_SAVE_LOAD_ERROR"] = {
        { "errorType", "SaveLoadDialogError" },
    },
    ["EVENT_SLOT_IS_LOCKED_FAILURE"] = {
        { "bagId", "Bag" },
        { "slotIndex", "integer" },
    },
    ["EVENT_SMITHING_TRAIT_RESEARCH_CANCELED"] = {
        { "craftingSkillType", "TradeskillType" },
        { "researchLineIndex", "luaindex" },
        { "traitIndex", "luaindex" },
    },
    ["EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED"] = {
        { "craftingSkillType", "TradeskillType" },
        { "researchLineIndex", "luaindex" },
        { "traitIndex", "luaindex" },
    },
    ["EVENT_SMITHING_TRAIT_RESEARCH_STARTED"] = {
        { "craftingSkillType", "TradeskillType" },
        { "researchLineIndex", "luaindex" },
        { "traitIndex", "luaindex" },
    },
    ["EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED"] = {},
    ["EVENT_SOCIAL_DATA_LOADED"] = {},
    ["EVENT_SOCIAL_ERROR"] = {
        { "error", "SocialActionResult" },
    },
    ["EVENT_SOUL_GEM_ITEM_CHARGE_FAILURE"] = {
        { "reason", "SoulGemItemChargingReason" },
    },
    ["EVENT_SPAM_WARNING"] = {
        { "spamType", "SpamWarningType" },
    },
    ["EVENT_SPECTACLE_EVENT_PHASE_UPDATED"] = {
        { "spectacleId", "integer" },
        { "oldActivePhaseId", "integer" },
        { "newActivePhaseId", "integer" },
        { "isInitialUpdate", "bool" },
    },
    ["EVENT_SPECTACLE_EVENT_UPDATED"] = {
        { "spectacleId", "integer" },
    },
    ["EVENT_STABLE_INTERACT_END"] = {},
    ["EVENT_STABLE_INTERACT_START"] = {},
    ["EVENT_STACKED_ALL_ITEMS_IN_BAG"] = {
        { "bagId", "Bag" },
    },
    ["EVENT_START_ATTRIBUTE_RESPEC"] = {
        { "allocationMode", "AttributePointAllocationMode" },
        { "paymentType", "RespecPaymentType" },
    },
    ["EVENT_START_ATTRIBUTE_RESPEC_CAST"] = {},
    ["EVENT_START_FAST_TRAVEL_INTERACTION"] = {
        { "nodeIndex", "luaindex" },
    },
    ["EVENT_START_FAST_TRAVEL_KEEP_INTERACTION"] = {
        { "keepId", "integer" },
    },
    ["EVENT_START_KEEP_GUILD_CLAIM_INTERACTION"] = {},
    ["EVENT_START_KEEP_GUILD_RELEASE_INTERACTION"] = {},
    ["EVENT_START_SKILL_RESPEC"] = {
        { "allocationMode", "SkillPointAllocationMode" },
        { "paymentType", "RespecPaymentType" },
    },
    ["EVENT_START_SKILL_RESPEC_CAST"] = {},
    ["EVENT_START_SOUL_GEM_RESURRECTION"] = {
        { "durationMs", "integer" },
    },
    ["EVENT_START_WAIT_SPINNER"] = {},
    ["EVENT_STATS_UPDATED"] = {
        { "unitTag", "string" },
    },
    ["EVENT_STEALTH_STATE_CHANGED"] = {
        { "unitTag", "string" },
        { "stealthState", "StealthState" },
    },
    ["EVENT_STOP_ANTIQUITY_DIGGING"] = {},
    ["EVENT_STOP_WAIT_SPINNER"] = {},
    ["EVENT_STORE_FAILURE"] = {
        { "reason", "StoreFailure" },
        { "errorStringId", "integer" },
        { "reasonParam1", "integer" },
    },
    ["EVENT_STUCK_BEGIN"] = {},
    ["EVENT_STUCK_CANCELED"] = {},
    ["EVENT_STUCK_COMPLETE"] = {},
    ["EVENT_STUCK_ERROR_ALREADY_IN_PROGRESS"] = {},
    ["EVENT_STUCK_ERROR_INVALID_LOCATION"] = {},
    ["EVENT_STUCK_ERROR_IN_COMBAT"] = {},
    ["EVENT_STUCK_ERROR_ON_COOLDOWN"] = {},
    ["EVENT_STYLE_LEARNED"] = {
        { "itemStyleId", "integer" },
        { "chapterIndex", "integer" },
        { "isDefaultRacialStyle", "bool" },
    },
    ["EVENT_SUBSCRIBER_BANK_IS_LOCKED"] = {},
    ["EVENT_SYNERGY_ABILITY_CHANGED"] = {},
    ["EVENT_SYSTEM_HELP_OPENED"] = {},
    ["EVENT_SYSTEM_MENU_CLOSED"] = {},
    ["EVENT_SYSTEM_MENU_OPENED"] = {},
    ["EVENT_TAMRIEL_TOMES_END_OF_SEASON_RECAP_AVAILABLE"] = {},
    ["EVENT_TAMRIEL_TOME_PURCHASE_RESULT"] = {
        { "tomeId", "integer" },
        { "purchaseResult", "TamrielTomePurchaseResult" },
    },
    ["EVENT_TARGET_CHANGED"] = {
        { "unitTag", "string" },
    },
    ["EVENT_TARGET_MARKER_UPDATE"] = {},
    ["EVENT_TELVAR_STONE_UPDATE"] = {
        { "newTelvarStones", "integer" },
        { "oldTelvarStones", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_TIMED_ACTIVITIES_REROLL_PRICE_RESET"] = {},
    ["EVENT_TIMED_ACTIVITIES_UPDATED"] = {},
    ["EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED"] = {
        { "index", "luaindex" },
        { "previousProgress", "integer" },
        { "currentProgress", "integer" },
        { "complete", "bool" },
    },
    ["EVENT_TIMED_ACTIVITY_REROLL_RESULT"] = {
        { "result", "TamrielTomeChallengeRerollResult" },
        { "index", "luaindex:nilable" },
    },
    ["EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED"] = {},
    ["EVENT_TIMED_ACTIVITY_TRACKING_UPDATED"] = {
        { "timedActivityEncodedId", "id64" },
    },
    ["EVENT_TITLE_UPDATE"] = {
        { "unitTag", "string" },
    },
    ["EVENT_TOGGLE_HELP"] = {},
    ["EVENT_TRACKED_ZONE_STORY_ACTIVITY_COMPLETED"] = {
        { "zoneId", "integer" },
        { "zoneCompletionType", "ZoneCompletionType" },
        { "activityId", "integer" },
    },
    ["EVENT_TRACKING_UPDATE"] = {},
    ["EVENT_TRADE_ACCEPT_FAILED_NOT_ENOUGH_MONEY"] = {},
    ["EVENT_TRADE_BAR_UPDATE"] = {
        { "tradeBarAmount", "integer" },
        { "difference", "integer" },
        { "reason", "CurrencyChangeReason" },
    },
    ["EVENT_TRADE_CANCELED"] = {
        { "cancelerName", "string" },
    },
    ["EVENT_TRADE_CONFIRMATION_CHANGED"] = {
        { "who", "TradeParticipant" },
        { "level", "integer" },
    },
    ["EVENT_TRADE_ELEVATION_FAILED"] = {
        { "reason", "TradeActionResult" },
        { "itemName", "string" },
    },
    ["EVENT_TRADE_FAILED"] = {
        { "reason", "TradeActionResult" },
    },
    ["EVENT_TRADE_INVITE_ACCEPTED"] = {},
    ["EVENT_TRADE_INVITE_CANCELED"] = {},
    ["EVENT_TRADE_INVITE_CONSIDERING"] = {
        { "inviterCharacterName", "string" },
        { "inviterCrossplayDisplayName", "string" },
        { "inviterPlatformDisplayName", "string" },
    },
    ["EVENT_TRADE_INVITE_DECLINED"] = {},
    ["EVENT_TRADE_INVITE_FAILED"] = {
        { "reason", "TradeActionResult" },
        { "inviteeCharacterName", "string" },
        { "inviteeDisplayName", "string" },
    },
    ["EVENT_TRADE_INVITE_REMOVED"] = {},
    ["EVENT_TRADE_INVITE_WAITING"] = {
        { "inviteeCharacterName", "string" },
        { "inviteeCrossplayDisplayName", "string" },
        { "inviteePlatformDisplayName", "string" },
    },
    ["EVENT_TRADE_ITEM_ADDED"] = {
        { "who", "TradeParticipant" },
        { "tradeIndex", "luaindex" },
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_TRADE_ITEM_ADD_FAILED"] = {
        { "reason", "TradeActionResult" },
        { "itemName", "string" },
    },
    ["EVENT_TRADE_ITEM_REMOVED"] = {
        { "who", "TradeParticipant" },
        { "tradeIndex", "luaindex" },
        { "itemSoundCategory", "ItemUISoundCategory" },
    },
    ["EVENT_TRADE_ITEM_UPDATED"] = {
        { "who", "TradeParticipant" },
        { "tradeIndex", "luaindex" },
    },
    ["EVENT_TRADE_MONEY_CHANGED"] = {
        { "who", "TradeParticipant" },
        { "money", "integer" },
    },
    ["EVENT_TRADE_SUCCEEDED"] = {},
    ["EVENT_TRADING_HOUSE_AWAITING_RESPONSE"] = {
        { "responseType", "TradingHouseResult" },
    },
    ["EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE"] = {
        { "pendingPurchaseIndex", "luaindex:nilable" },
    },
    ["EVENT_TRADING_HOUSE_ERROR"] = {
        { "errorCode", "TradingHouseResult" },
    },
    ["EVENT_TRADING_HOUSE_OPERATION_TIME_OUT"] = {
        { "responseType", "TradingHouseResult" },
    },
    ["EVENT_TRADING_HOUSE_PENDING_ITEM_UPDATE"] = {
        { "slotId", "integer" },
        { "isPending", "bool" },
    },
    ["EVENT_TRADING_HOUSE_RESPONSE_RECEIVED"] = {
        { "responseType", "TradingHouseResult" },
        { "result", "TradingHouseResult" },
    },
    ["EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT"] = {
        { "responseType", "TradingHouseResult" },
    },
    ["EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE"] = {
        { "cooldownMilliseconds", "integer" },
    },
    ["EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED"] = {
        { "guildId", "integer" },
    },
    ["EVENT_TRADING_HOUSE_STATUS_RECEIVED"] = {},
    ["EVENT_TRAIT_LEARNED"] = {
        { "itemName", "string" },
        { "itemTrait", "string" },
    },
    ["EVENT_TRIAL_FEATURE_RESTRICTED"] = {
        { "restrictionType", "TrialAccountRestrictionType" },
    },
    ["EVENT_TRIAL_PROGRESSION_ATTUNEMENT_CHANGED"] = {},
    ["EVENT_TRIAL_PROGRESSION_POINTS_CHANGED"] = {
        { "previousPoints", "integer" },
        { "newPoints", "integer" },
    },
    ["EVENT_TRIBUTE_CAMPAIGN_CHANGE"] = {
        { "campaignKey", "id64" },
    },
    ["EVENT_TRIBUTE_CLUB_EXPERIENCE_GAINED"] = {
        { "currentXP", "integer" },
        { "deltaXP", "integer" },
    },
    ["EVENT_TRIBUTE_CLUB_INIT"] = {
        { "success", "bool" },
    },
    ["EVENT_TRIBUTE_CLUB_RANK_CHANGED"] = {
        { "newClubRank", "TributeClubRank" },
    },
    ["EVENT_TRIBUTE_EXIT_RESPONSE"] = {
        { "accept", "bool" },
    },
    ["EVENT_TRIBUTE_GAME_FLOW_STATE_CHANGE"] = {
        { "flowState", "TributeGameFlowState" },
    },
    ["EVENT_TRIBUTE_INVITE_ACCEPTED"] = {},
    ["EVENT_TRIBUTE_INVITE_CANCELED"] = {},
    ["EVENT_TRIBUTE_INVITE_DECLINED"] = {},
    ["EVENT_TRIBUTE_INVITE_FAILED"] = {
        { "reason", "TributeMatchEvent" },
        { "targetCharacterName", "string" },
        { "targetDisplayName", "string" },
    },
    ["EVENT_TRIBUTE_INVITE_RECEIVED"] = {
        { "inviterCharacterName", "string" },
        { "inviterDisplayName", "string" },
        { "timeRemainingMS", "integer" },
    },
    ["EVENT_TRIBUTE_INVITE_REMOVED"] = {},
    ["EVENT_TRIBUTE_INVITE_SENT"] = {
        { "inviteeCharacterName", "string" },
        { "inviteeDisplayName", "string" },
    },
    ["EVENT_TRIBUTE_LEADERBOARD_DATA_RECEIVED"] = {
        { "leaderboardType", "TributeLeaderboardType" },
    },
    ["EVENT_TRIBUTE_LEADERBOARD_RANK_RECEIVED"] = {
        { "leaderboardType", "TributeLeaderboardType" },
    },
    ["EVENT_TRIBUTE_PATRONS_SEARCH_RESULTS_READY"] = {},
    ["EVENT_TRIBUTE_PATRON_PROGRESSION_DATA_CHANGED"] = {
        { "patronId", "integer:nilable" },
    },
    ["EVENT_TRIBUTE_PLAYER_CAMPAIGN_INIT"] = {
        { "campaignKey", "id64" },
        { "success", "bool" },
        { "isActive", "bool" },
    },
    ["EVENT_TRIBUTE_PLAYER_TURN_STARTED"] = {
        { "isLocalPlayer", "bool" },
    },
    ["EVENT_TUTORIALS_RESET"] = {},
    ["EVENT_TUTORIAL_SYSTEM_ENABLED_STATE_CHANGED"] = {
        { "enabled", "bool" },
    },
    ["EVENT_TUTORIAL_TRIGGER_COMPLETED"] = {
        { "tutorialTrigger", "TutorialTrigger" },
    },
    ["EVENT_UI_ERROR"] = {
        { "stringId", "integer" },
    },
    ["EVENT_ULTIMATE_ABILITY_COST_CHANGED"] = {
        { "cost", "integer" },
        { "ultimateResource", "integer" },
    },
    ["EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED"] = {
        { "unitTag", "string" },
        { "unitAttributeVisual", "UnitAttributeVisual" },
        { "statType", "DerivedStats" },
        { "attributeType", "Attributes" },
        { "powerType", "CombatMechanicFlags" },
        { "value", "number" },
        { "maxValue", "number" },
        { "sequenceId", "integer" },
    },
    ["EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED"] = {
        { "unitTag", "string" },
        { "unitAttributeVisual", "UnitAttributeVisual" },
        { "statType", "DerivedStats" },
        { "attributeType", "Attributes" },
        { "powerType", "CombatMechanicFlags" },
        { "value", "number" },
        { "maxValue", "number" },
        { "sequenceId", "integer" },
    },
    ["EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED"] = {
        { "unitTag", "string" },
        { "unitAttributeVisual", "UnitAttributeVisual" },
        { "statType", "DerivedStats" },
        { "attributeType", "Attributes" },
        { "powerType", "CombatMechanicFlags" },
        { "oldValue", "number" },
        { "newValue", "number" },
        { "oldMaxValue", "number" },
        { "newMaxValue", "number" },
        { "sequenceId", "integer" },
    },
    ["EVENT_UNIT_CHARACTER_NAME_CHANGED"] = {
        { "unitTag", "string" },
    },
    ["EVENT_UNIT_CREATED"] = {
        { "unitTag", "string" },
    },
    ["EVENT_UNIT_DEATH_STATE_CHANGED"] = {
        { "unitTag", "string" },
        { "isDead", "bool" },
    },
    ["EVENT_UNIT_DESTROYED"] = {
        { "unitTag", "string" },
    },
    ["EVENT_UNLOCKED_DYES_UPDATED"] = {},
    ["EVENT_UNSPENT_CHAMPION_POINTS_CHANGED"] = {},
    ["EVENT_UNSUCCESSFUL_REQUEST_RESULT"] = {
        { "resultMessage", "string" },
    },
    ["EVENT_UPDATE_BUYBACK"] = {},
    ["EVENT_UPDATE_GUI_LOADING_PROGRESS"] = {
        { "guiName", "string" },
        { "assetsLoaded", "integer" },
        { "assetsTotal", "integer" },
    },
    ["EVENT_VENGEANCE_ACTION_RESULT"] = {
        { "vengeanceActionResult", "VengeanceActionResult" },
    },
    ["EVENT_VENGEANCE_EXIT_LOADOUT_SWAP_SUBZONE"] = {},
    ["EVENT_VENGEANCE_LOADOUT_ROLE_UPDATED"] = {},
    ["EVENT_VENGEANCE_PERKS_UPDATED"] = {},
    ["EVENT_VETERAN_DIFFICULTY_CHANGED"] = {
        { "unitTag", "string" },
        { "isDifficult", "bool" },
    },
    ["EVENT_VIBRATION"] = {
        { "duration", "integer" },
        { "coarseMotor", "number" },
        { "fineMotor", "number" },
        { "leftTriggerMotor", "number" },
        { "rightTriggerMotor", "number" },
        { "debugSourceInfo", "string" },
    },
    ["EVENT_VIDEO_PLAYBACK_CANCEL_STARTED"] = {},
    ["EVENT_VIDEO_PLAYBACK_COMPLETE"] = {},
    ["EVENT_VIDEO_PLAYBACK_CONFIRM_CANCEL"] = {},
    ["EVENT_VIDEO_PLAYBACK_ERROR"] = {
        { "errorReason", "VideoPlaybackErrorReason" },
    },
    ["EVENT_VISUAL_LAYER_CHANGED"] = {},
    ["EVENT_VOICE_CHANNEL_AVAILABLE"] = {
        { "channelName", "string" },
        { "muted", "bool" },
        { "joined", "bool" },
        { "transmit", "bool" },
    },
    ["EVENT_VOICE_CHANNEL_JOINED"] = {
        { "channelName", "string" },
    },
    ["EVENT_VOICE_CHANNEL_LEFT"] = {
        { "channelName", "string" },
    },
    ["EVENT_VOICE_CHANNEL_UNAVAILABLE"] = {
        { "channelName", "string" },
    },
    ["EVENT_VOICE_CHAT_ACCESSIBILITY_SETTING_CHANGED"] = {},
    ["EVENT_VOICE_CHAT_TRANSCRIPT"] = {
        { "channelName", "string" },
        { "fromName", "string" },
        { "text", "string" },
        { "fromDisplayName", "string" },
    },
    ["EVENT_VOICE_DEVICE_INFO"] = {
        { "deviceName", "string" },
        { "isInput", "bool" },
        { "isCurrent", "bool" },
    },
    ["EVENT_VOICE_MUTE_LIST_UPDATED"] = {},
    ["EVENT_VOICE_TRANSMIT_CHANNEL_CHANGED"] = {
        { "channelName", "string" },
    },
    ["EVENT_VOICE_USER_JOINED_CHANNEL"] = {
        { "channelName", "string" },
        { "displayName", "string" },
        { "characterName", "string" },
        { "isSpeaking", "bool" },
    },
    ["EVENT_VOICE_USER_LEFT_CHANNEL"] = {
        { "channelName", "string" },
        { "displayName", "string" },
    },
    ["EVENT_VOICE_USER_SPEAKING"] = {
        { "channelName", "string" },
        { "displayName", "string" },
        { "characterName", "string" },
        { "speaking", "bool" },
    },
    ["EVENT_WEAPON_PAIR_LOCK_CHANGED"] = {
        { "locked", "bool" },
    },
    ["EVENT_WEAPON_SWAP_LOCKED"] = {
        { "swapLevel", "integer" },
    },
    ["EVENT_WEB_BROWSER_CLOSED"] = {},
    ["EVENT_WEB_BROWSER_OPENED"] = {},
    ["EVENT_WEREWOLF_STATE_CHANGED"] = {
        { "werewolf", "bool" },
    },
    ["EVENT_WORLD_EVENTS_INITIALIZED"] = {},
    ["EVENT_WORLD_EVENT_ACTIVATED"] = {
        { "worldEventInstanceId", "integer" },
    },
    ["EVENT_WORLD_EVENT_ACTIVE_LOCATION_CHANGED"] = {
        { "worldEventInstanceId", "integer" },
        { "oldWorldEventLocationId", "integer" },
        { "newWorldEventLocationId", "integer" },
    },
    ["EVENT_WORLD_EVENT_DEACTIVATED"] = {
        { "worldEventInstanceId", "integer" },
    },
    ["EVENT_WORLD_EVENT_PARTICIPATION_BEGIN"] = {
        { "worldEventInstanceId", "integer" },
        { "stepDefId", "integer" },
    },
    ["EVENT_WORLD_EVENT_PARTICIPATION_END"] = {
        { "worldEventInstanceId", "integer" },
    },
    ["EVENT_WORLD_EVENT_STEP_CHANGED"] = {
        { "worldEventInstanceId", "integer" },
        { "newStepDefId", "integer" },
    },
    ["EVENT_WORLD_EVENT_STEP_PROGRESS_CHANGED"] = {
        { "worldEventInstanceId", "integer" },
        { "stepDefId", "integer" },
        { "newCurrentProgress", "integer" },
        { "newMaxProgress", "integer" },
    },
    ["EVENT_WORLD_EVENT_UNIT_CHANGED_PIN_TYPE"] = {
        { "worldEventInstanceId", "integer" },
        { "unitTag", "string" },
        { "oldPinType", "MapDisplayPinType" },
        { "newPinType", "MapDisplayPinType" },
    },
    ["EVENT_WORLD_EVENT_UNIT_CREATED"] = {
        { "worldEventInstanceId", "integer" },
        { "unitTag", "string" },
    },
    ["EVENT_WORLD_EVENT_UNIT_DESTROYED"] = {
        { "worldEventInstanceId", "integer" },
        { "unitTag", "string" },
    },
    ["EVENT_WRIT_VOUCHER_UPDATE"] = {
        { "newWritVouchers", "integer" },
        { "oldWritVouchers", "integer" },
        { "reason", "CurrencyChangeReason" },
        { "reasonSupplementaryInfo", "integer" },
    },
    ["EVENT_ZONE_CHANGED"] = {
        { "zoneName", "string" },
        { "subZoneName", "string" },
        { "newSubzone", "bool" },
        { "zoneId", "integer" },
        { "subZoneId", "integer" },
    },
    ["EVENT_ZONE_CHANNEL_CHANGED"] = {},
    ["EVENT_ZONE_COLLECTIBLE_REQUIREMENT_FAILED"] = {
        { "requiredCollectible", "integer" },
        { "message", "string" },
    },
    ["EVENT_ZONE_SCORING_CHANGED"] = {},
    ["EVENT_ZONE_STORY_ACTIVITY_TRACKED"] = {},
    ["EVENT_ZONE_STORY_ACTIVITY_TRACKING_INIT"] = {},
    ["EVENT_ZONE_STORY_ACTIVITY_UNTRACKED"] = {},
    ["EVENT_ZONE_STORY_QUEST_ACTIVITY_TRACKED"] = {
        { "questIndex", "luaindex" },
    },
    ["EVENT_ZONE_UPDATE"] = {
        { "unitTag", "string" },
        { "newZoneName", "string" },
    },
}
