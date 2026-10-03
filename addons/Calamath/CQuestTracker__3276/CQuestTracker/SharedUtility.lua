--
-- Calamath's Quest Tracker [CQT]
--
-- Copyright (c) 2022 Calamath
--
-- This software is released under the Artistic License 2.0
-- https://opensource.org/licenses/Artistic-2.0
--

if not CQuestTracker then return end
local CQT = CQuestTracker:SetSharedEnvironment()
-- ---------------------------------------------------------------------------------------
local L = GetString

local function ZoneStoryZoneIdIterator(_, lastZoneId)
	return GetNextZoneStoryZoneId(lastZoneId)
end

-- ---------------------------------------------------------------------------------------
-- Shared Utilities
-- ---------------------------------------------------------------------------------------
local zoneDisplayTypeIconTexture = {
	[ZONE_DISPLAY_TYPE_NONE]			= nil, 
	[ZONE_DISPLAY_TYPE_SOLO]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_instance.dds", 
	[ZONE_DISPLAY_TYPE_DUNGEON]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_groupDungeon.dds", 
	[ZONE_DISPLAY_TYPE_RAID]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_raid.dds", 
	[ZONE_DISPLAY_TYPE_GROUP_DELVE]		= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_groupDelve.dds", 
	[ZONE_DISPLAY_TYPE_GROUP_AREA]		= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_groupArea.dds", 
	[ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON]	= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_dungeon.dds", 
	[ZONE_DISPLAY_TYPE_DELVE]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_delve.dds", 
	[ZONE_DISPLAY_TYPE_HOUSING]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_housing.dds", 
	[ZONE_DISPLAY_TYPE_BATTLEGROUND]	= "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabicon_battlegrounds.dds", 
	[ZONE_DISPLAY_TYPE_ZONE_STORY]		= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_zoneStory.dds", 
	[ZONE_DISPLAY_TYPE_COMPANION]		= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_companion.dds", 
	[ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON]	= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_endlessDungeon.dds", 
	[ZONE_DISPLAY_TYPE_ADVENTURE_ZONE]	= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_adventureZone.dds", 
	[ZONE_DISPLAY_TYPE_SOLO_DUNGEON]	= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_solo_dungeon.dds", 
}
local function GetZoneDisplayTypeIcon(zoneDisplayType)
	return zoneDisplayTypeIconTexture[zoneDisplayType]
end
CQT:RegisterSharedObject("GetZoneDisplayTypeIcon", GetZoneDisplayTypeIcon)

local questTypeIconTexture = {
	[QUEST_TYPE_NONE]				= nil, 
	[QUEST_TYPE_GROUP]				= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_group.dds", 
	[QUEST_TYPE_MAIN_STORY]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_mainStory.dds", 
	[QUEST_TYPE_GUILD]				= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_guild.dds", 
	[QUEST_TYPE_CRAFTING]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_crafting.dds", 
	[QUEST_TYPE_DUNGEON]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_dungeon.dds", 
	[QUEST_TYPE_RAID]				= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_raid.dds", 
	[QUEST_TYPE_AVA]				= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_ava.dds", 
	[QUEST_TYPE_CLASS]				= nil, 
	[QUEST_TYPE_AVA_GROUP]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_avagroup.dds", 
	[QUEST_TYPE_AVA_GRAND]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_avagroup.dds", 
	[QUEST_TYPE_HOLIDAY_EVENT]		= "EsoUI/Art/TreeIcons/Gamepad/achievement_categoryicon_events.dds", 
	[QUEST_TYPE_BATTLEGROUND]		= "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabicon_battlegrounds.dds", 
	[QUEST_TYPE_PROLOGUE]			= "EsoUI/Art/TreeIcons/Gamepad/achievement_categoryicon_prologue.dds", 
	[QUEST_TYPE_UNDAUNTED_PLEDGE]	= "EsoUI/Art/Icons/ServiceMapPins/servicepin_undaunted.dds", 
	[QUEST_TYPE_COMPANION]			= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_companion.dds", 
	[QUEST_TYPE_TRIBUTE]			= "EsoUI/Art/Tribute/Gamepad/gp_tribute_tabicon_tribute.dds", 
	[QUEST_TYPE_SCRIBING]			= "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_indexicon_scribing.dds", 
	[QUEST_TYPE_FAVOR]				= "EsoUI/Art/Journal/Gamepad/gp_questTypeIcon_repeatable_favor.dds", 
	[QUEST_TYPE_TAMRIEL_TALE]		= nil, 
}
local function GetQuestTypeIcon(questType)
	return questTypeIconTexture[questType]
end
CQT:RegisterSharedObject("GetQuestTypeIcon", GetQuestTypeIcon)


local questBackgroundTexture = {
-- Hard-code here if you want to associate a special background texture with a particular quest.
-- Supported textures: 512px wide gamepad store textures and loading screen textures.

-- Tutorial Quest
	[4961]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_werewolf_firralthel_1x1.dds", 				-- Hircine's Gift
	[4964]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_vampirism_azisathekeeper_1x1.dds", 			-- Scion of the Blood Matron
	[5949]	= "EsoUI/Art/Store/Gamepad/gp_crwn_bullet_mw_pvpbattlegrounds_1x1.dds", 					-- For Glory
	[6130]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_roomtospare_felandedemarie_1x1.dds", 		-- Room to Spare
	[6532]	= "EsoUI/Art/Store/Gamepad/gp_crwn_housing_housingquestgiver_1x1.dds", 						-- Guild Listings
	[6646]	= "EsoUI/Art/LoadingScreens/loadscreen_u30_tutorial_01.dds", 								-- The Gates of Adamant
	[6799]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_talesoftribute_brahgas_1x1.dds", 			-- Tales of Tribute
	[7061]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_endlessarchive_mastermalkhest_1x1.dds", 	-- The Margins of Ire
	[7104]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_scribing_adeptirnardrirnil_1x1.dds", 		-- The Second Era of Scribing.
	[7325]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_subclassing_bahtraathunding_1x1.dds", 		-- A Study in Discipline
	[7494]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_rumorsabound_tillithegossip_1x1.dds", 		-- Rumors Abound
	[7526]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_sagesvault_urli_1x1.dds", 					-- Invitation to Treasures

-- Prologue Quest
	[5935]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_vv_divineconundrum_1x1.dds", 				-- The Missing Prophecy
	[6023]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_cc_ofknivesandlongshadows_1x1.dds", 		-- Of Knives and Long Shadows
	[6097]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_glacierteaser_vanusgalerion_1x1.dds", 				-- Through a Veil Darkly
	[6226]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_mmteaser_1x1.dds", 							-- Ruthless Competition
	[6242]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_mmteaser_1x1.dds", 							-- The Cursed Skull
	[6299]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_announcement2019_1x1.dds", 						-- The Demon Weapon
	[6306]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_announcement2019_1x1.dds", 						-- The Halls of Colossus
	[6395]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_dh_letterfromkasura_1x1.dds", 				-- The Dragonguard's Legacy
	[6398]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_dh_letterfromkasura_1x1.dds",					-- The Horn of Ja'darri
	[6454]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_gm_prologue_1x1.dds", 						-- The Coven Conspiracy
	[6463]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_gm_prologue_1x1.dds", 						-- The Coven Conundrum
	[6549]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_ravenwatchinquiry_1x1.dds", 					-- The Ravenwatch Inquiry
	[6555]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_ravenwatchinquiry_1x1.dds",					-- The Gray Council
	[6612]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_bwd_prologue_mortalstouch_1x1.dds", 		-- A Mortal's Touch
	[6627]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_bwd_prologue_mortalstouch_1x1.dds", 		-- The Emperor's Secret
	[6701]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_rogatinacinna_1x1.dds", 			-- An Apocalyptic Situation
	[6703]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_rogatinacinna_1x1.dds", 			-- The Key and the Cataclyst
	[6751]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_jakarn_ascendingdoubt_1x1.dds", 			-- Ascending Doubt
	[6761]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_jakarn_ascendingdoubt_1x1.dds", 			-- A King's Retreat
	[6843]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_druidlaurel_1x1.dds", 				-- Sojourn of the Druid King
	[6967]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_leramilthewise_1x1.dds", 			-- Eye of Fate
	[7079]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_galsabaru_1x1.dds", 				-- Prisoner of Fate
	[7290]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_princeazah_1x1.dds", 				-- A Guild in Crisis
	[7310]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_prologue_princeazah_1x1.dds", 				-- Justice for the Fallen
	[7168]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_glenthievesguild_skeevernivo_1x1.dds", 		-- The Codex Caper
	[7418]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_sheogorath_noththeunhinged_1x1.dds", 		-- Sheogorath Takes a Holiday

-- Event Quest
	[5635]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_chefdonolon_1x1.dds", 						-- Ache for Cake (2016)
	[5742]	= "EsoUI/Art/Store/Gamepad/gp_crwn_collectable_crowwhistle2017_1x1.dds", 					-- The Witchmother's Bargain
	[5935]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_chefdonolon_1x1.dds", 						-- Ache for Cake (2017)
	[5941]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_jesterseventnote_1x1.dds", 						-- The Jester's Festival
	[6014]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_queststartermidsummer_1x1.dds", 					-- Whitestrake's Mayhem
	[6134]	= "EsoUI/Art/Store/Gamepad/gp_crwn_collectable_newlifefestscroll_1x1.dds",					-- The New Life Festival
	[6168]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_chefdonolon_1x1.dds", 						-- Ache for Cake (2018)
	[6370]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_chefdonolon_1x1.dds", 						-- Ache for Cake (2019)
	[6444]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_event_dragonbounty_1x1.dds", 				-- Dawn of the Dragonguard (charity event)
	[6564]	= "EsoUI/Art/Store/Gamepad/gp_crwn_questgiver_event_gloryoftheundaunted_1x1.dds", 			-- Glory of the Undaunted
	[6629]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_events_philiusdormier_1x1.dds", 			-- A Visit to Elsweyr
	[6638]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_events_philiusdormier_1x1.dds", 			-- Sand, Snow, and Blood
	[6687]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_bountiesofblackwood_chaniljei_1x1.dds", 	-- Bounties of Blackwood
	[6729]	= "EsoUI/Art/Store/Gamepad/gp_crwn_event_daedricwarcelebration_1x1.dds", 					-- Guidance for Guides
	[6749]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_zealofzenithar_amminusvaro_1x1.dds", 		-- The Unrefusable Offer
	[6833]	= "EsoUI/Art/Store/Gamepad/gp_crwn_eventquest_bloodyreunion_1x1.dds", 						-- Bloody Reunion
	[6839]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_heroesofhighisle_philienvisour_1x1.dds", 	-- The Island Tour
	[6851]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_eventquest_baneofdragons_1x1.dds", 			-- Bane of Dragons
	[7029]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_gatesofoblivion_plokun_1x1.dds", 			-- Burdensome Beasts
	[7060]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_secretsofthetelvanni_masterfaras_1x1.dds", 	-- The Telvanni Secret
	[7191]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_apprenticemogh_1x1.dds",  					-- For Cake's Sake
	[7470]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_highseas_baroncaptainolsien_1x1.dds", 		-- Raising the Riotous Redress
	[7475]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_highseas_baroncaptainolsien_1x1.dds", 		-- Bounty of the Abecean Sea

-- Solo Dungeon Quest
	[7509]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_solomos_hanu_1x1.dds", 						-- The Great Hunt
	[7514]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_solomhk_adonatusvarian_1x1.dds", 			-- Moonlight Ascent

-- Event Zone Quest
	[7363]	= "EsoUI/Art/Store/Gamepad/gp_crwn_queststarter_nightmarket_thecurator_1x1.dds", 			-- Those Who Would Rule
}
local function GetQuestBackgroundTexture(questId)
	return questBackgroundTexture[questId]
end
CQT:RegisterSharedObject("GetQuestBackgroundTexture", GetQuestBackgroundTexture)


-- Hard-code here for missing link in GetCollectibleIdForZone table or for past DLC collectible that was incorporated into the base game for marketing reasons.
local collectibleLinkedZoneStoryId = {
	[593]	= 849, -- Vvardenfell for Morrowind DLC
}
for zoneStoryZoneId in ZoneStoryZoneIdIterator do
	local collectibleId = GetCollectibleIdForZone(GetZoneIndex(zoneStoryZoneId))
	if collectibleId ~= 0 then
		collectibleLinkedZoneStoryId[collectibleId] = zoneStoryZoneId
	end
end
local function GetCollectibleLinkedZoneStoryZoneId(collectibleId)
	return collectibleLinkedZoneStoryZoneId[collectibleId]
end
CQT:RegisterSharedObject("GetCollectibleLinkedZoneStoryZoneId", GetCollectibleLinkedZoneStoryZoneId)


-- Hard-code here for quests linked to the DLC collectibles.
local questLinkedCollectibleId = {
-- TODO: Each time a new prologue quest is introduced in the future, hard-code the associated DLC collectibleId to the table.
-- prologue quests
	[5935]	= 593, 
	[6023]	= 1240, 
	[6097]	= 5107, 
	[6226]	= 5755, 
	[6242]	= 5755, 
	[6299]	= 5843, 
	[6306]	= 5843, 
	[6395]	= 6920, 
	[6398]	= 6920, 
	[6454]	= 7466, 
	[6463]	= 7466, 
	[6549]	= 8388, 
	[6555]	= 8388, 
	[6612]	= 8659, 
	[6627]	= 8659, 
	[6701]	= 9365, 
	[6703]	= 9365, 
	[6751]	= 10053, 
	[6761]	= 10053, 
	[6843]	= 10660, 
	[6967]	= 10475, 
	[7079]	= 11871, 
	[7290]	= 13439, 
	[7310]	= 13439, 
	[7168]	= 14772, 
	[7418]	= 14776, 
}
local function GetQuestLinkedCollectibleId(questId)
	return questLinkedCollectibleId[questId]
end
CQT:RegisterSharedObject("GetQuestLinkedCollectibleId", GetQuestLinkedCollectibleId)

local function GetQuestLinkedCollectibleName(questId)
	return GetCollectibleName(questLinkedCollectibleId[questId])
end
CQT:RegisterSharedObject("GetQuestLinkedCollectibleName", GetQuestLinkedCollectibleName)

local function GetQuestLinkedZoneStoryZoneId(questId)
	local collectibleId = GetQuestLinkedCollectibleId(questId)
	local zoneStoryZoneId = collectibleId and GetCollectibleLinkedZoneStoryZoneId(collectibleId)
	return zoneStoryZoneId or GetZoneStoryZoneIdForZoneId(GetParentZoneId(GetQuestZoneId(questId)))
end
CQT:RegisterSharedObject("GetQuestLinkedZoneStoryZoneId", GetQuestLinkedZoneStoryZoneId)

