--* ZOS API surface used by Vermilion. functions are
--* forwarded by value (M.X = X), captured at module load. This is the same
--* call cost as the bare global with the wrapper benefit of a namespace.
--* Consumers may local-cache hot-path entries:
--*   local GetGameTimeMs = Vermilion.zenimax.api.GetGameTimeMilliseconds
--? This may not be necessary, however I found it cleaner to have all API calls explicitly go through the wrapper for readability.

Vermilion = Vermilion or {}
Vermilion.zenimax = Vermilion.zenimax or {}
local Vermilion = Vermilion

Vermilion.zenimax.api = {}
local M = Vermilion.zenimax.api

M.GetGameTimeMilliseconds = GetGameTimeMilliseconds
M.GetFrameDeltaMilliseconds = GetFrameDeltaMilliseconds
M.GetAPIVersion           = GetAPIVersion
M.GetWorldName            = GetWorldName

M.GetString = GetString

M.IsUnitGrouped           = IsUnitGrouped
M.IsUnitInCombat          = IsUnitInCombat
M.GetGroupSize            = GetGroupSize
M.GetUnitName             = GetUnitName
M.GetUnitDisplayName      = GetUnitDisplayName
M.GetUnitClass            = GetUnitClass
M.GetUnitRace             = GetUnitRace
M.GetUnitLevel            = GetUnitLevel
M.GetUnitChampionPoints   = GetUnitChampionPoints
M.GetUnitAlliance         = GetUnitAlliance

M.GetCurrentMapZoneIndex  = GetCurrentMapZoneIndex
M.GetZoneNameByIndex      = GetZoneNameByIndex

M.GetSlotName                            = GetSlotName
M.GetSlotBoundId                         = GetSlotBoundId
M.GetSlotAbilityCost                     = GetSlotAbilityCost
M.GetAbilityBaseCostInfo                 = GetAbilityBaseCostInfo
M.GetSlotType                            = GetSlotType
M.GetAbilityIdForCraftedAbilityId        = GetAbilityIdForCraftedAbilityId
M.GetAbilityCost                         = GetAbilityCost
M.GetAbilityCastInfo                     = GetAbilityCastInfo
M.IsUnitDead                             = IsUnitDead
M.GetDuelInfo                            = GetDuelInfo
M.GetPlayerStat                          = GetPlayerStat
M.GetActiveHotbarCategory                = GetActiveHotbarCategory
M.GetUnitPower                           = GetUnitPower
M.GetAbilityName                         = GetAbilityName
M.GetAbilityIcon                         = GetAbilityIcon
M.GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
M.GetSkillLineId                         = GetSkillLineId
M.GetAbilityDescription                  = GetAbilityDescription
M.IsAbilityPassive                       = IsAbilityPassive

M.GetUnitZone      = GetUnitZone
M.GetTimeStamp     = GetTimeStamp
M.GetDateStringFromTimestamp = GetDateStringFromTimestamp
M.AreUnitsEqual    = AreUnitsEqual
M.DoesUnitExist    = DoesUnitExist
M.ReloadUI         = ReloadUI
M.StartChatInput   = StartChatInput
M.SetEncounterLogEnabled = SetEncounterLogEnabled
M.IsEncounterLogEnabled  = IsEncounterLogEnabled
M.GetEncounterLogVersion = GetEncounterLogVersion
M.GetUIMousePosition = GetUIMousePosition
M.IsShiftKeyDown     = IsShiftKeyDown
M.GetUIGlobalScale   = GetUIGlobalScale
M.MouseIsOver        = MouseIsOver

M.GetCurrentZoneDungeonDifficulty = GetCurrentZoneDungeonDifficulty
M.GetMapContentType         = GetMapContentType
M.IsActiveWorldBattleground = IsActiveWorldBattleground
M.GetCurrentBattlegroundId  = GetCurrentBattlegroundId
M.GetBattlegroundTeamSize   = GetBattlegroundTeamSize
M.IsPlayerInRaid            = IsPlayerInRaid
M.IsPlayerInEndlessDungeon  = IsPlayerInEndlessDungeon
M.IsInCyrodiil              = IsInCyrodiil
M.IsInImperialCity          = IsInImperialCity
M.GetCurrentZoneHouseId     = GetCurrentZoneHouseId
M.GetZoneId                 = GetZoneId
M.GetUnitZoneIndex          = GetUnitZoneIndex
