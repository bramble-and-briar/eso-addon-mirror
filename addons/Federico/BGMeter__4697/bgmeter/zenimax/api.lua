
BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.zenimax = BGMeter.zenimax or {}

local C = BGMeter.zenimax.constants

local A = {}

A.now_ms = GetGameTimeMilliseconds
A.get_api_version = GetAPIVersion
A.get_timestamp = GetTimeStamp
A.get_display_name = GetDisplayName
A.get_char_name = function() return GetUnitName("player") end
A.get_ui_mouse = GetUIMousePosition

A.get_bg_id          = GetCurrentBattlegroundId
A.get_bg_state       = GetCurrentBattlegroundState
A.get_bg_game_type   = GetCurrentBattlegroundGameType
A.get_bg_round_index = GetCurrentBattlegroundRoundIndex
A.is_active_bg       = IsActiveWorldBattleground
A.get_bg_name        = GetBattlegroundName
A.get_bg_team_size   = GetBattlegroundTeamSize
A.get_bg_num_teams   = GetBattlegroundNumTeams
A.get_local_team     = function() return GetUnitBattlegroundTeam("player") end
A.get_result_for_team = GetBattlegroundResultForTeam
A.get_num_rounds     = GetBattlegroundNumRounds
A.get_round_result   = GetCurrentBattlegroundRoundResult
A.get_rounds_won     = GetCurrentBattlegroundRoundsWonByTeam
A.get_team_score     = GetCurrentBattlegroundScore
A.get_team_icon      = function(team)
    local f = GetBattlegroundTeamIcon or ZO_GetBattlegroundTeamIcon
    if not f then return nil end
    return f(team)
end
A.get_team_name      = GetBattlegroundTeamName

A.get_num_objectives          = GetNumObjectives
A.get_objective_ids           = GetObjectiveIdsForIndex
A.is_bg_objective             = IsBattlegroundObjective
A.get_objective_info          = GetObjectiveInfo
A.get_objective_type          = GetObjectiveType
A.get_objective_designation   = GetObjectiveDesignation
A.get_objective_control_state = GetObjectiveControlState
A.get_capture_area_owner      = GetCaptureAreaObjectiveOwner

A.get_num_entries          = GetNumScoreboardEntries
A.get_local_entry_index    = GetScoreboardLocalPlayerEntryIndex
A.get_entry_info           = GetScoreboardEntryInfo
A.get_entry_team           = GetScoreboardEntryBattlegroundTeam
A.get_entry_class          = GetScoreboardEntryClassId
A.get_entry_lives          = GetScoreboardEntryNumLivesRemaining
A.get_entry_score          = GetScoreboardEntryScoreByType
A.get_entry_cumulative     = GetBattlegroundCumulativeScoreForScoreboardEntryByType

A.get_next_entry_medal     = GetNextScoreboardEntryMedalId
A.get_entry_medal_count    = GetScoreboardEntryNumEarnedMedalsById
A.get_medal_info           = GetMedalInfo
A.gen_cumulative_medals    = GenerateCumulativeMedalInfoForScoreboardEntry
A.get_next_cumulative_medal = GetNextBattlegroundCumulativeMedalId
A.get_cumulative_medal_count = GetBattlegroundCumulativeNumEarnedMedalsById

A.get_currency       = GetCurrencyAmount
A.get_currency_icon  = GetCurrencyKeyboardIcon
A.get_alliance_points = function()
    return GetCurrencyAmount(C.CURT_ALLIANCE_POINTS, C.CURRENCY_LOCATION_CHARACTER)
end
A.get_unit_xp        = function() return GetUnitXP("player") end
A.get_unit_xp_max    = function() return GetUnitXPMax("player") end

A.lfg_num_sets     = GetNumActivitySetsByType
A.lfg_set_disabled = IsLFGActivitySetDisabled
A.lfg_set_id       = GetActivitySetIdByTypeAndIndex
A.lfg_set_info     = GetActivitySetInfo
A.lfg_clear_search = ClearActivityFinderSearch
A.lfg_add_set      = AddActivityFinderSetSearchEntry
A.lfg_start        = StartActivityFinderSearch
A.lfg_cancel       = CancelGroupSearches
A.lfg_searching    = IsCurrentlySearchingForGroup
A.lfg_times        = GetLFGSearchTimes
A.lfg_cooldown     = GetLFGCooldownTimeRemainingSeconds
A.lfg_num_requests       = GetNumActivityRequests
A.lfg_request_ids        = GetActivityRequestIds
A.lfg_activity_type      = GetActivityType
A.lfg_set_activity_count = GetNumActivitySetActivities
A.lfg_set_activity_id    = GetActivitySetActivityIdByIndex
A.lfg_current_activity   = GetCurrentLFGActivityId

A.get_ava_rank          = function() return GetUnitAvARank("player") end
A.get_ava_rank_points   = function() return GetUnitAvARankPoints("player") end
A.get_ava_points_needed = GetNumPointsNeededForAvARank
A.get_ava_rank_icon     = GetAvARankIcon
A.get_ava_rank_name     = GetAvARankName
A.get_gender            = function() return GetUnitGender("player") end
A.get_cp_earned      = GetPlayerChampionPointsEarned

A.is_player_in_ava_world = IsPlayerInAvAWorld
A.is_in_ava_zone         = IsInAvAZone
A.get_zone_name          = function() return GetUnitZone("player") end

A.query_bg_leaderboard      = QueryBattlegroundLeaderboardData
A.get_bg_leaderboard_local  = GetBattlegroundLeaderboardLocalPlayerInfo
A.get_player_mmr            = GetPlayerMMRByType
A.does_bg_impact_mmr        = DoesCurrentBattlegroundImpactMMR

A.is_veterancy_season_active = IsVeterancySeasonActive
A.get_season_name            = GetCurrentVeterancySeasonName
A.get_season_time_remaining  = GetCurrentVeterancySeasonTimeRemainingS
A.get_season_id              = GetCurrentVeterancySeasonId
A.is_in_veterancy_zone       = IsInVeterancyProgressionZone
A.get_unit_veterancy_rank    = function() return GetUnitVeterancyRank("player") end
A.get_veterancy_rank_title   = GetVeterancyRankTitle
A.get_veterancy_rank_icon    = GetVeterancyRankIcon
A.get_veterancy_large_icon   = GetVeterancyLargeRankIcon

A.get_active_ref_track_ids   = GetActiveReferenceTrackIdsForRewardTrackType
A.get_ref_track_index        = GetReferenceTrackIndex
A.get_reward_track_id_from_ref = GetRewardTrackIdFromReferenceTrackId
A.get_info_for_reward_track  = GetInfoForRewardTrack
A.get_tier_total_progress    = GetTotalProgressAtRewardTrackTier
A.get_num_base_tiers         = GetNumBaseTiersForRewardTrack
A.has_repeatable_tier        = HasInfinitelyRepeatableTierForRewardTrack
A.get_repeatable_tier        = GetInfinitelyRepeatableTierForRewardTrack
A.get_repeatable_claimed     = GetRewardTrackInfinitelyRepeatableRewardClaimedState
A.get_num_rewards_at_tier    = GetNumRewardsAtRewardTrackTier
A.get_reward_claimed_state   = GetRewardTrackRewardClaimedState
A.has_unclaimed_rewards      = HasUnclaimedRewardTrackRewards
A.claim_all_rewards          = ClaimAllRewardTrackRewards

A.get_map_player_position    = GetMapPlayerPosition
A.set_map_to_player          = SetMapToPlayerLocation
A.map_matches_player         = DoesCurrentMapMatchMapForPlayerLocation
A.get_current_map_id         = GetCurrentMapId
A.get_map_name               = GetMapName
A.get_map_num_tiles          = GetMapNumTiles
A.get_map_tile_texture       = GetMapTileTexture
A.get_group_size             = GetGroupSize
A.get_group_unit_tag         = GetGroupUnitTagByIndex
A.get_unit_name              = GetUnitName
A.get_unit_display_name      = GetUnitDisplayName
A.get_unit_veterancy_rank_of = function(tag) return GetUnitVeterancyRank(tag) end
A.get_unit_ava_rank_of       = function(tag) return GetUnitAvARank(tag) end
A.get_unit_bg_team           = function(tag) return GetUnitBattlegroundTeam(tag) end
A.is_unit_player             = function(tag) return IsUnitPlayer(tag) end
A.are_units_equal            = AreUnitsEqual
A.get_objective_pin_info     = GetObjectivePinInfo
A.world_map_showing          = ZO_WorldMap_IsWorldMapShowing

BGMeter.zenimax.api = A
