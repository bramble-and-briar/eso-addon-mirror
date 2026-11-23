
Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.api = {}
local M = Verdant.zenimax.api

M.GetGameTimeMilliseconds = GetGameTimeMilliseconds
M.GetAPIVersion           = GetAPIVersion
M.GetWorldName            = GetWorldName

M.GetString = GetString
M.ReloadUI  = ReloadUI

M.IsUnitGrouped           = IsUnitGrouped
M.StartChatInput          = StartChatInput
M.IsUnitInCombat          = IsUnitInCombat
M.DoesUnitExist           = DoesUnitExist
M.GetGroupSize            = GetGroupSize
M.GetUnitName             = GetUnitName
M.AreUnitsEqual           = AreUnitsEqual
M.GetUnitClassId          = GetUnitClassId
M.ZO_GetClassIcon         = ZO_GetClassIcon
M.GetUnitZone             = GetUnitZone
M.GetTimeStamp            = GetTimeStamp
M.GetUIGlobalScale        = GetUIGlobalScale
M.GetDateStringFromTimestamp = GetDateStringFromTimestamp
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
M.GetLatency              = GetLatency
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
M.GetActiveHotbarCategory                = GetActiveHotbarCategory
M.GetAbilityBaseCostInfo                 = GetAbilityBaseCostInfo
M.GetSlotType                            = GetSlotType
M.GetAbilityIdForCraftedAbilityId        = GetAbilityIdForCraftedAbilityId
M.GetAbilityCost                         = GetAbilityCost
M.GetAbilityCastInfo                     = GetAbilityCastInfo
M.GetPlayerStat                          = GetPlayerStat
M.GetUnitPower                           = GetUnitPower
M.IsUnitDead                             = IsUnitDead
M.GetAbilityName                         = GetAbilityName
M.GetAbilityIcon                         = GetAbilityIcon
M.GetAbilityDescription                  = GetAbilityDescription
M.IsAbilityPassive                       = IsAbilityPassive
M.GetAbilityEffectDescription            = GetAbilityEffectDescription
M.GetNumBuffs                            = GetNumBuffs
M.GetUnitBuffInfo                        = GetUnitBuffInfo
M.GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
M.GetSkillLineId                         = GetSkillLineId
M.GetAbilityBuffType                     = GetAbilityBuffType
M.GetAbilityMundusStoneType              = GetAbilityMundusStoneType
M.IsAbilityPermanent                     = IsAbilityPermanent
M.GetNumChampionDisciplines              = GetNumChampionDisciplines
M.GetChampionDisciplineId                = GetChampionDisciplineId
M.GetChampionDisciplineName              = GetChampionDisciplineName
M.GetNumChampionDisciplineSkills         = GetNumChampionDisciplineSkills
M.GetChampionSkillId                     = GetChampionSkillId
M.GetChampionSkillName                   = GetChampionSkillName
M.GetChampionAbilityId                   = GetChampionAbilityId
M.GetNextItemSetCollectionId             = GetNextItemSetCollectionId
M.GetItemSetName                         = GetItemSetName
M.GetNumItemSetCollectionPieces          = GetNumItemSetCollectionPieces
M.GetItemSetCollectionPieceInfo          = GetItemSetCollectionPieceInfo
M.GetItemSetCollectionPieceItemLink      = GetItemSetCollectionPieceItemLink
M.GetItemLinkSetInfo                     = GetItemLinkSetInfo
M.GetItemLinkSetBonusInfo                = GetItemLinkSetBonusInfo
M.GetBagSize                             = GetBagSize
M.GetItemLink                            = GetItemLink
M.GetNumSkillTypes                       = GetNumSkillTypes
M.GetNumSkillLines                       = GetNumSkillLines
M.GetNumSkillAbilities                   = GetNumSkillAbilities
M.GetSpecificSkillAbilityInfo            = GetSpecificSkillAbilityInfo
M.GetCVar                                = GetCVar

M.SetEncounterLogEnabled = SetEncounterLogEnabled
M.IsEncounterLogEnabled  = IsEncounterLogEnabled
M.GetEncounterLogVersion = GetEncounterLogVersion
M.GetUIMousePosition = GetUIMousePosition
M.IsShiftKeyDown     = IsShiftKeyDown
M.MouseIsOver        = MouseIsOver

function M.chat(line) d(line) end
