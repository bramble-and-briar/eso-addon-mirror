--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
AoM.KnownLibraries = AoM.CreateKnownTable([==[
ArkadiusTradeToolsSalesData01	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData01
ArkadiusTradeToolsSalesData02	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData02
ArkadiusTradeToolsSalesData03	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData03
ArkadiusTradeToolsSalesData04	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData04
ArkadiusTradeToolsSalesData05	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData05
ArkadiusTradeToolsSalesData06	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData06
ArkadiusTradeToolsSalesData07	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData07
ArkadiusTradeToolsSalesData08	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData08
ArkadiusTradeToolsSalesData09	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData09
ArkadiusTradeToolsSalesData10	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData10
ArkadiusTradeToolsSalesData11	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData11
ArkadiusTradeToolsSalesData12	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData12
ArkadiusTradeToolsSalesData13	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData13
ArkadiusTradeToolsSalesData14	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData14
ArkadiusTradeToolsSalesData15	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData15
ArkadiusTradeToolsSalesData16	20000	2.0.0	1752	101041	Arkadius' Trade Tools	ArkadiusTradeToolsSalesData16
AUI_FightData		3.993	919	101051	AUI - Advanced UI	AUI_FightData
blox		1.0.0	4004		LibFonts	blox
CombatInsightsFightData	10200	1.2.2	3730	101046	CombatInsightsFightData	CombatInsightsFightData
CombatMetricsFightData	22	1.7.8	1360	101048	CombatMetricsFightData	CombatMetricsFightData
CustomCompassPins	138	1.38	185	101045 101046	CustomCompassPins	CustomCompassPins
DariansUtilities	10807	1.7.7	2373	101051	Combat Metronome (GCD Tracker) - beta	DariansUtilities
DsRPlayerDBData	100	2026.04.29	3776	101048 101049	DsR GuildRoster (Loot-/ Inventory, Stickerbook, PvP, PersonalAssistant, BuffTracker and more)	DsRPlayerDBData
esoa_datastore	110	2.00.10	2070	100030 100031	ElderScrollsOfAlts	esoa_datastore
FCOAccessibility	20300	2.3	3586	101050 101051	FCO Accessibility	FCOAccessibility
GankProbability		1.0.0	3890	101041 101042	Gank Probability	GankProbability
GS00Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS00Data
GS01Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS01Data
GS02Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS02Data
GS03Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS03Data
GS04Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS04Data
GS05Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS05Data
GS06Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS06Data
GS07Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS07Data
GS08Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS08Data
GS09Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS09Data
GS10Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS10Data
GS11Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS11Data
GS12Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS12Data
GS13Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS13Data
GS14Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS14Data
GS15Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS15Data
GS16Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS16Data
GS17Data	100	3.8.33	2753	101049 101050	Master Merchant 3.0	GS17Data
Lib3D	312	2.2.2	2475	100029 100030	RdK Group Tool	Lib3D
LibAchievementsArchive	102041	1.2.4.1	3321	101050 101051	LibAchievementsArchive	LibAchievementsArchive
libAddonKeybinds	6	6	1253	101048 101049	libAddonKeybinds	libAddonKeybinds
LibAddonMenu-2.0	43	2.0 r43	7	101049 101050	LibAddonMenu-2.0	LAM
LibAddonMenuOrderListBox	15	15	3080	101050 101051	LibAddonMenu-2.0 - OrderListBox widget	LibAddonMenu-2.0 - OrderListBox widget
LibAddonMenuSoundSlider	6	6	3346	101048 101049	LibAddonMenu-2.0 - Sound slider widget	LibAddonMenu-2.0 - Sound slider widget
LibAkaUtils	22	22	3683	101045	LibAkaUtils	LibAkaUtils
LibAlchemy	27	2.7	2618	101051 101052	LibAlchemy	LibAlchemy
LibAlchemyStation	345	3.4.5	2628	101037 101038	LibAlchemyStation	LAS
LibAnimation-1.0	23	2.3	54	101032 101033	LibAnimation-1.0	LibAnimation-1.0
LibAPH	26100717	2026.10.07.17.24	4917	101051 101052	LibAPH	LibAPH
LibArmorInsulation	22	2.7.11	4709	101050 101051	LibArmorInsulation	LibArmorInsulation
LibAsync	30105	3.1.5	2125	101051 101052	LibAsync	LibAsync
LibBase64		1.0	3795	101040	LibBase64	LibBase64
LibBinaryEncode	34	1.34	1647	101033	LibBinaryEncode	LBE
LibBitSet	1	0.0.1	3960	101043	LibBitSet	LibBitSet
LibBSCWizardBridge	2	1.0.1	4644	101048 101049 101050	LibBSCWizardBridge	LibBSCWizardBridge
LibCharacter	8	0.0.8	2806	100035 101031	LibCharacter	LibCharacter
LibCharacterKnowledge	301020	3.1.2	3317	101050 101051	LibCharacterKnowledge	LCK
LibCharacterKnowledgeZHPatch	200001	2.0.0.1	3899	101042	LibCharacterKnowledgeZHPatch	LibCharacterKnowledgeZHPatch
LibChatMenuButton	1006	1.6	3805	101042	LibChatMenuButton	LibChatMenuButton
LibChatMessage	120	1.2.3	2382	101050	LibChatMessage	LCMsg
LibCInteraction	10100	2.2.9	3276	101041 101042	CQuestTracker	LibCInteraction
LibCombat	89	89	2528	101049 101050	LibCombat	LibCombat
LibCombatAlerts	8052	0.8.5.2	4225	101051	LibCombatAlerts	LCA
LibConsoleDialogs	10004	1.0.4.2	4106	101047 101048	LibConsoleDialogs	LibConsoleDialogs
LibCopyWindow	4	0.0.4	2853	100035 101031	LibCopyWindow	LibCopyWindow
LibCovetousCountess	103	1.03	3266	101049 101050	LibCovetousCountess	LibCovetousCountess
LibCPieMenu	10503	1.5.3	3088	101041 101042	CShortcutPieMenu	LibCPieMenu
LibCrypto	2	1.1	4010	101044	LibCrypto	LibCrypto
LibCSA	210	2.30	1355	101040 101041	RaidNotifier Updated	LibCSA
LibCustomIcons	20261012	2026-10-12	4161	101049 101050	LibCustomIcons	LCI
LibCustomMenu	730	7.3.0	1146	101044 101045	LibCustomMenu	LCM
LibCustomNames	20261012	2026-10-12	4155	101049 101050	LibCustomNames	LCN
LibDailyReset	19	1.9	4424	101050	LibDailyReset	LibDailyReset
LibDataEncode	2	2	3980	101044 101045	LibDataEncode	LibDataEncode
LibDataPacker	1005000	v5	4082	101050	LibDataPacker	LibDataPacker
LibDataShare	20250314	2025.03.14	3297	101044 101045	LibDataShare (deprecated)	LibDataShare
LibDataStructures	20241206	2024.12.06	4001	101044	LibDataStructures	LibDataStructures
LibDateTime	32	1.2.0	2277	101045 101046	LibDateTime	LDT
LibDebugLogger	307	2.6.2	2275	101050	LibDebugLogger	LDL
LibDelayedHandler	2	0.0.2	2807	100033 100034	LibDelayedHandler	LibDelayedHandler
LibDialog	127	1.27	1931	101039 101040	LibDialog	LibDialog
LibDungeonFinder	120	1.2.0	4600	101049 101050	LibDungeonFinder	LibDungeonFinder
LibDynamicMail	24	0.2.4	4379	101050 101051	LibDynamicMail	LibDynamicMail
LibEmote	1013	1.13	3715	101049	LibEmote	LibEmote
LibEnchantingStation	234	2.3.5	2437	100033 100034	LibEnchantingStation	LibEnchantingStation
LibEsoHubPrices	20	2026.10.12.02.54	4095	101051	LibEsoHubPrices	LibEsoHubPrices
LibEventHandler	1314	1.3.14	1452	101050 101051	LorePlay Forever	LibEventHandler
LibExecutionQueue	202	3.8.33	2753	101049 101050	Master Merchant 3.0	LibExecutionQueue
LibExoYsUtilities	9	9	3363	101049	LibExoYsUtilities	LibExoYsUtilities
LibExtendedJournal	205031	2.5.3.1	4031	101050 101051	LibExtendedJournal	LibExtendedJournal
LibExtendedSavedVars	107	107	4755	101050 101051	LibExtendedSavedVars	LibExtendedSavedVars
LibFBCommon	1007	1.0.7	3977	101049	LibFBCommon	LibFBCommon
LibFeedback		1.32	2079	100027 100028	LibFeedback	LibFeedback
LibFilters-3.0	350	3.0r5.0	2343	101048 101049	LibFilters-3.0	LF3
LibFLEncode	2	1.1.9	1563	101046 101047 101048 101049	LibFLEncode	LibFLEncode
LibFloatingIcons		0.2	3599	101045	LibFloatingIcons	LibFloatingIcons
LibFonts	10000	1.0.0	4004	101044	LibFonts	LibFonts
LibFoodDrinkBuff	19	19	1902	101049 101050	LibFoodDrinkBuff	LibFoodDrinkBuff
LibFurnitureCatalogue	1002000	1.2.0	4804	101051 101052	LibFurnitureCatalogue	LibFurnitureCatalogue
LibGamepad	107	1.0.8	4441	101049	LibGamepad	LibGamepad
LibGamepadContextMenuBridge	151	1.5.1	4432	101048 101049	[Beta] LibGamepadContextMenuBridge v1.5.1 - gamepad context actions for LibCustomMenu	LibGamepadContextMenuBridge
LibGamepadOptions	7	0.2.4	4614	101049 101050	LibGamepadOptions	LibGamepadOptions
LibGetText	12	1.0.3	2276	101045 101046	LibGetText	LibGetText
LibGPS	73	3.3.3	601	101045 101046	LibGPS	LibGPS
LibGroupBroadcast	95	2.0.0	1337	101048 101049	LibGroupBroadcast	LibGroupBroadcast
LibGroupCombatStats	20261004	2026-10-04	4024	101046 101047	LibGroupCombatStats	LibGroupCombatStats
LibGroupPotionCooldowns	20260111	2026-01-11	4190	101046 101047	LibGroupPotionCooldowns	LibGroupPotionCooldowns
LibGroupResources	95	2.0.0	4402	101048 101049	LibGroupResources	LibGroupResources
LibGroupUIReload	95	2.0.0	4403	101048 101049	LibGroupUIReload	LibGroupUIReload
LibGuardArrow	100	1.0.1	3553	100036	LibGuardArrow	LibGuardArrow
LibGuildRoster	104	1.0.4	2784	101049 101050	LibGuildRoster	LibGuildRoster
LibGuildStore	105	3.8.33	2753	101049 101050	Master Merchant 3.0	LibGuildStore
LibHandler	3	0.0.3	3156	101033 101034	LibHandler	LibHandler
LibHarvensAddonSettings	20200	2.2.0	584	101050 101051	LibHarvensAddonSettings	LHAS
LibHistoire	1103	2.7.1	2817	101050	LibHistoire	LibHistoire
LibId64	28	1.0.1	3585	101045 101046	LibId64	LibId64
LibImplex	24	24	4108	101049	LibImplex	LibImplex
LibInteriorDetection	44	1.3.7	4816	101051 101052	LibInteriorDetection	LibInteriorDetection
LibItemLink	940	9.4.0	3855	100031 100032	LibItemLink	LibItemLink
LibItemLinkDecoder	103	1.03	3265	101049 101050	LibItemLinkDecoder	LibItemLinkDecoder
LibItemSets	100010	1.0.1	4753	101050 101051	LibItemSets	LibItemSets
LibJson		1.0	3794	101040	LibJson	LibJson
LibKeepTooltip	1101000	1.0.1	4037	101046	LibKeepTooltip	LibKeepTooltip
LibLanguage	49	49	2837	101052 101051	LibLanguage	LibLanguage
LibLazyCrafting	4042	4.042	1594	101050 101051	LibLazyCrafting	LLC
LibLeadDrop	10000	1.0.0	4413	101048 101049	LibLeadDrop	LibLeadDrop
LibLootSummary	30106	3.1.6	2363	101047 101048	LibLootSummary	LibLootSummary
LibLoreLibraryCesarska		1.0.1	4459	101049	LibLoreLibraryCesarska	LibLoreLibraryCesarska
LibLuaCodeWindow	2	1.1	4124	101045	LibLuaCodeWindow	LibLuaCodeWindow
LibLuaInts	101	1.1	3796	101040	LibLuaInts	LibLuaInts
LibLuaLexer	1	1.1	4124	101045	LibLuaCodeWindow	LibLuaLexer
LibMainMenu-2.0	40500	4.5.0	2118	101049 101050	LibMainMenu-2.0	LMM2
LibMapData	122	1.22	3353	101049 101050	LibMapData	MapData
LibMapPing	1240	2.1.0	1302	101045 101046	LibMapPing	MapPing
LibMapPins-1.0	10047	1.0 r47	563	101045 101046	LibMapPins	MapPins
LibMapThemer	2	1.1.6	3742	101041 101042 101043	LibMapThemer Updated (U50)	LibMapThemer
LibMarify	1217	1.2.17	2542	101036	LibMarify	LibMarify
LibMediaProvider	39	1.1 r39	56	101051	LibMediaProvider	LibMedia
LibMediaProvider-1.0	34	1.1 r39	56	101046	LibMediaProvider-1.0	LibMediaProvider-1.0
LibMousePointer	10000	1.0.0	4518	101048 101049	LibMousePointer	LibMousePointer
LibMsgWin-1.0	11	1.0 r11	802	100031 100032	LibMsgWin-1.0	LibMsgWin-1.0
LibMultiAccountAchievements	101041	1.1.4.1	3925	101050 101051	LibMultiAccountAchievements	LibMultiAccountAchievements
LibMultiAccountCollectibles	102051	1.2.5.1	3320	101050 101051	LibMultiAccountCollectibles	LibMultiAccountCollectibles
LibMultiAccountSets	400031	4.0.3.1	2843	101050 101051	LibMultiAccountSets	LibMultiAccountSets
LibMultiIcon	104	1.04	3267	101049	LibMultiIcon	LibMultiIcon
LibMultilingualName	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName
LibMultilingualName_de	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_de
LibMultilingualName_en	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_en
LibMultilingualName_es	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_es
LibMultilingualName_fr	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_fr
LibMultilingualName_jp	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_jp
LibMultilingualName_ru	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_ru
LibMultilingualName_zh	10248	1.2.48	2666	101049 101050	LibMultilingualName	LibMultilingualName_zh
LibNeuralNetworks		1.0.0	3881	101041 101042	LibNeuralNetworks - Machine Learning	LibNeuralNetworks
LibNotification	15	1.1.0	1224	101045 101046	LibNotification	LNotify
LibObserve		1.0	3922	101042	LibObserve	LibObserve
LibOT	3	3.3.5	2254	101049 101050	SnapShot [ DEPRECATED]	LibOT
LibPanicida	2000000	2.0.0	4349	101048	LibPanicida	LibPanicida
LibPotionBuff	3	2.2.2	2475		RdK Group Tool	LibPotionBuff
LibPrice	70530	7.53	2204	101045 101046	LibPrice	LibPrice
LibPriceCache	10105	v.1.1.7	4494	101049	LibPriceCache	LibPriceCache
LibPromises	37	1.1.2	2274	101045 101046	LibPromises	LibPromises
LibQRCode	46	1.0.8	4102	101046	LibQRCode	LibQRCode
LibQuestData	279	2.79	2625	101048 101049	LibQuestData	LibQuestData
LibQuestStatus	100030	1.0.3	4573	101050 101051	LibQuestStatus	LibQuestStatus
LibRadialMenu	9	9	4297	101050	LibRadialMenu	LibRadialMenu
LibrarianDeprecation		3.18	188	101038	Librarian Book Manager	LibrarianDeprecation
LibRecipe	112	1.12	3927	101048 101049	LibRecipe	LibRecipe
LibResearch	43	4.0r3	517	101042 101043	libResearch	libResearch
LibSavedVars	60101	6.1.1	2161	101052 101051	LibSavedVars	LSV
LibSaveToDisk	102	1.3g r6	1993	100033 100034	LibSaveToDisk	LibSaveToDisk
LibScroll	2	2	1151	100033 100034	LibScroll	LibScroll
LibScrollableMenu	20407	2.47	3546	101051 101052	LibScrollableMenu	LSM
LibScrollList	4	4	4609	101050	LibScrollList	LibScrollList
LibSeasonalEventManager	1	1.3	3670	101040 101038	LibSeasonalEventManager	LibSeasonalEventManager
LibServerResetTime	200000	2.0.0	4427	101049 101050	LibServerResetTime	LibServerResetTime
LibSetDetection	5	5.0	3338	101050	LibSetDetection	LibSetDetection
LibSets	9040	0.9.4	2241	101051 101052	LibSets	LibSets
LibSFUtils	78	78	2231	101052 101051	LibSFUtils	LSFU
LibShifterBox	700	0.7.0	2444	101045 101046	LibShifterBox	LibShifterBox
LibSimpleArrow	100	1.0.0	4251	101047	LibSimpleArrow	LibSimpleArrow
LibSimpleArrowModS	100	0.1.6	3616	100030	LibSimpleArrowModS	LibSimpleArrowModS
LibSimpleArrowSlip	100	1.4.3	3879	100030	Lucent Citadel	LibSimpleArrowSlip
LibSimpleSavedVars	3	0.0.3	2805	100035 101031	LibSimpleSavedVars	LibSimpleSavedVars
LibSkillBlocker	110	1.1.0	2863	101048 101049	LibSkillBlocker	LibSkillBlocker
LibSkillsFactory	26	26	3649	101050	LibSkillsFactory	LibSkillsFactory
LibSlashCommander	45	1.2.0	1508	101045 101046	LibSlashCommander	LibSlashCommander
LibSort	200	2.r1	540	100027 100028	LibSort	LibSort
LibSprint	20260522	2026.05.03	3827	101050	LibSprint	LibSprint
LibStatic	2	2.0.0	4367	101049	LibStatic	LibStatic
LibStub	7	1.0 r7	44	100030 100031	LibStub	LibStub
LibSubzones	1	v22	4112	101048	ImperialCartographer	LibSubzones
LibSurfaceTools	8	8	4584	101049	LibSurfaceTools	LibSurfaceTools
LibTableFunctions-1.0	101	1.0.1	2624	100030	LibTableFunctions-1.0	LibTableFunctions-1.0
LibTarget		1.0.0	4830	101049	LibTarget	LibTarget
LibTeamShadows	10303	1.3.3	4669	101050 101051	LibTeamshadows	LibTeamShadows
LibTextFilter	13	1.0.7	1311	101045 101046	LibTextFilter	LibTextFilter
LibTextFormat	19	0.1.9	4380	101050 101051	LibTextFormat	LibTextFormat
LibTraitResearch	105	1.05	3264	101049 101050	LibTraitResearch	LibTraitResearch
LibTreasure	24	24	3227	101049	LibTreasure	LibTreasure
LibUespQuestData	20260709	2026-07-09	2484	101050	LibUespQuestData	LibUespQuestData
LibUndauntedPledges	102020	1.2.2	3946	101046 101047	LibUndauntedPledges	LibUndauntedPledges
LibUnits2	103	1.0.3	4250	101050	LibUnits2	LibUnits2
LibUnitTracker	15	0.1.5	2815	101033 101034	LibUnitTracker	LibUnitTracker
LibVectorMath	1	1.0.0	4114	101045 101046	LibVectorMath	LibVectorMath
LibWorldEvents	250	2.5.0	2473	101047	LibWorldEvents	LibWorldEvents
LibWorldMapInfoTab	127	1.2.7	1568	100033 100034	LibWorldMapInfoTab	LibWorldMapInfoTab
LibZone	901	9.1	2171	101051 101052	LibZone	LibZone
LibZoneTemp	23	2.3.19	4708	101051 101052	LibZoneTemp	LibZoneTemp
LPC	10105	v.1.1.7	4494	101049	LibPriceCache	LPC
LPC01	10103	v.1.1.7	4494	101049	LibPriceCache	LPC01
LPC02	10103	v.1.1.7	4494	101049	LibPriceCache	LPC02
LPC03	10103	v.1.1.7	4494	101049	LibPriceCache	LPC03
LPC04	10103	v.1.1.7	4494	101049	LibPriceCache	LPC04
LuiData	7231	7.2.3.1	4373	101051 101052	LuiData	LuiData
LuiMedia	7134	7.1.3.4	4374	101051 101052	LuiMedia	LuiMedia
MM00Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM00Data
MM01Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM01Data
MM02Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM02Data
MM03Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM03Data
MM04Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM04Data
MM05Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM05Data
MM06Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM06Data
MM07Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM07Data
MM08Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM08Data
MM09Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM09Data
MM10Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM10Data
MM11Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM11Data
MM12Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM12Data
MM13Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM13Data
MM14Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM14Data
MM15Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM15Data
MM16Data	331	1.03	3334	101047 101048	Importers for Master Merchant 3.0	MM16Data
NodeDetection	113	3.16.12	57	101049 101050	NodeDetection	NodeDetection
ShoppingList		0.19.4	4775	101050 101051	Shopping List	ShoppingList
Taneth	31	1.1.0	3584	101044 101045	Taneth - Testing Framwork	Taneth
united		1.0.0	4004		LibFonts	united
ustring	1	1.0 r1	3736	101039 101040	ustring	ustring
]==])
