--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
AoM.KnownConsoleLibraries = AoM.CreateConsoleTable([==[
AAAConsoleUIShim		1	101050 101051	ACUS	user562x	35468315-d34f-4779-b62b-ccb35919ce0f
CustomCompassPins	137	1.37	101045 101046	CustomCompassPins	Sharlikran	3c805ef7-47fe-43a7-b480-52342549e9f4
LibAddonMenu-2.0	44	2.0r44	101049 101050	LibAddonMenu	sirinsidiator	04141a46-3d9c-4b14-aa0e-d841090d128c
LibAlchemy	18	1.8	101045 101046	LibAlchemy	Sharlikran	48762aef-8240-473f-aef5-17d1b5d5b9b6
LibAPH	26100717	2026.10.07.17.24	101051 101052	LibAPH	APH0NlC	dac0d37e-2d2f-4813-a148-6198c2d54687
LibAsync	30106	LibAsync-3.1.6-2026-10-04T142628	101049 101050	dev sandbox	clubwratt	436f6695-4798-423f-b276-d8c46cbd938e
LibCharacterKnowledge	301020	3.1.2	101050 101051	LibCharacterKnowledge	code65536	ec23fab6-f620-4366-90ab-82e8702a62bb
LibChatMessage	120	1.2.3	101050	LibChatMessage	sirinsidiator	37466506-930a-44cb-864d-2bd760f24da7
LibCInteraction	10402	1.4.2	101047	LibCInteraction	Calamath	49a3eac1-a81d-43dc-8b84-097b6d7ee558
LibCombat2	8	8	101046	LibCombat2	SolinurAddons	96103ec3-3c4e-4865-be32-cc3b57df04d0
LibCombatAlerts	8052	0.8.5.2	101051	LibCombatAlerts	code65536	756d3118-70ee-4ed7-a49e-5217da36e5fe
LibConsoleDialogs	10004	1.0.4.2c	101048 101049	LibConsoleDialogs	votan73	73752f6e-3ac5-4ecd-9bfe-b71c1b926c3b
LibConsoleLogger	300	LibConsoleLogger-0.3.0-2026-10-05T235159	101050	LibConsoleLogger	clubwratt	6bd5f4ac-b518-489a-b1b8-31811650b446
LibConsoleMenu	115	0.15.12	101050 101051	LibConsoleMenu	Fluazinam	dec0fe25-b1d4-4adf-b351-101e44def098
LibCovetousCountess	103	1.03	101049 101050	LibCovetousCountess	Delte	29f1ad04-65ea-4a2b-9e23-8ccb597a8556
LibCustomMenu	730	7.3.1	101048	LibCustomMenu	mYoda01	fff7f7e3-b518-4545-9e96-a4f6c2a28dea
LibCustomNames	20261012	2026-10-12	101049 101050	LibCustomNames	m00nyONE	5eaa0d91-47f8-4c5e-8673-db3ab518a752
LibDateTime	32	1.2.0	101045 101046	LibDateTime	sirinsidiator	fc98f3c0-0b5a-4797-aaa4-379955c3310c
LibDebugLogger	307	2.6.2	101050	LibDebugLogger	sirinsidiator	031ddfc1-c44d-4452-ab48-42b7c429bc81
LibDynamicMail	024	0.2.4	101050 101051	LibDynamicMail	saranicole1980	d98298fa-549a-4a02-ad04-7c3f0dc92445
LibGamepad	107	1.0.8	101049	LibGamepad	YeOldeDragon	37661fa7-7702-4eeb-b3ed-7e840aa17647
LibGamepadTooltipFilters	1000	1.0.2	101047	LibGamepadTooltipFilters	Gamer_sa22	bfb99a77-93cb-42e1-944b-d139b38724f4
LibGetText	12	1.0.3	101045 101046	LibGetText	sirinsidiator	4dda84ba-7458-4a69-890d-1c7dd830474f
LibGPS	73	3.3.3	101045 101046	LibGPS	sirinsidiator	e54271d9-a6d8-4004-8e2a-6f8ddb3a4045
LibGroupBroadcast	95	2.0.0	101048 101049	LibGroupBroadcast	sirinsidiator	39644437-95e9-414a-adf6-578b31771ea0
LibGroupCombatStats	20261004	2026-10-04	101046 101047	LibGroupCombatStats	m00nyONE	25cfa10b-66f5-4e8c-9d1a-1c452491665f
LibGroupPotionCooldowns	20260111	2026-01-11-fix	101046 101047	LibGroupPotionCooldowns	m00nyONE	c75ace9c-ba19-4bce-b7b1-4793854c4754
LibGroupResources	95	2.0.0	101048 101049	LibGroupResources	sirinsidiator	f55094d7-29e8-4a43-a3f5-bd748dda7c09
LibGroupUIReload	95	2.0.0	101048 101049	LibGroupUIReload	sirinsidiator	e06117c8-dc48-479b-aa35-08555712f2ef
LibHarvensAddonSettings	20200	2.2.0	101049 101050	LibHarvensAddonSettings	votan73	ff73a91e-28b3-476c-be2b-ac5e47d079eb
LibHistoire	1103	2.7.1	101050	LibHistoire	sirinsidiator	f7fc3e7c-b17d-47bd-915b-40c09291efb0
LibId64	28	1.0.1	101045 101046	LibId64	sirinsidiator	0faeb5c6-5fc7-48bc-91c6-61d863d7bf6e
LibItemLinkDecoder	103	1.03	101049 101050	LibItemLinkDecoder	Delte	03b27b8e-253d-4288-ba88-4340d56faeac
LibItemSets	100010	1.0.1	101050 101051	LibItemSets	code65536	d85860ca-4b0a-47c6-8a0b-45472e2f1878
LibLazyCrafting	4042	4.042	101050 101051	LibLazyCrafting	Dolgubon	60c046e9-d8e1-4cb9-8df9-fafeebb3c000
LibLoreLibraryCesarska		1.0.1	101049	LibLoreLibraryCesarska	tomkolp	35674482-a2ce-4dfb-86f8-519b941a350a
LibMapPing	1240	2.1.0	101045 101046	LibMapPing	sirinsidiator	f6e1e99b-174a-401e-8acf-d4a7e6e2c352
LibMapPins-1.0	10047	1.47	101045 101046	LibMapPins	Sharlikran	fe11caef-4426-405c-bb46-3c3ca893703b
LibMediaProvider	39	1.1 r39	101051	LibMediaProvider	Calamath	0fa32336-8528-4747-9b01-ccba9408f654
LibMessagePlugin	110	1.1.31	101049 101050	LibMessagePlugin	SugaComa	90c97baa-6170-421f-bd23-7fd88500168d
LibMousePointer	10000	1.0.0	101049 101050	LibMousePointer	votan73	de9c92f2-729c-45e6-8071-0155852da2c0
LibNotification	15	1.1.0	101045 101046	LibNotification	sirinsidiator	68111c3f-410f-4318-b9ec-582b8c68c374
LibPrice	70460	7.46	101045 101046	LibPrice	Sharlikran	0a54c8f7-e3e1-46e5-ab7f-3c7ee2bb5e7d
LibPromises	37	1.1.2	101045 101046	LibPromises	sirinsidiator	eb221fca-fa24-44ac-9fab-6ee0f8cba1e0
LibQRCode	046	1.0.8	101046	LibQRCode	RoyalTonberry	da93c9ce-04e0-4acf-a62a-16e23c1e8d06
LibQuestStatus	100020	1.0.2	101050 101051	LibQuestStatus	code65536	df55d66d-d19b-41dd-99a2-8d385916f4a1
LibRadialMenu	9	9	101050	LibRadialMenu	M0R	f3dd1d3e-85df-448d-8d84-fdf6545dbebb
LibRecipe	103	1.03	101045 101046	LibRecipe	Sharlikran	17071a4b-f373-41fa-8874-778672bae73c
LibSavedVars	60100	6.1-beta1	101050 101051	LibSavedVars	Shadowfen7	d1a95060-4ee7-4fc9-a0f1-681fe479c5b9
LibServerResetTime	200000	2.0.0	101049 101050	LibServerResetTime	code65536	d1e62d86-1a34-4727-8221-e23b1c5b7616
LibSideQuestPins		v4	101048	Side Quests	0mniX	1ac2188b-1200-476b-a90c-6561a7d3b52a
LibSlashCommander	45	1.2.0	101045 101046	LibSlashCommander	sirinsidiator	c0ae2cd5-69de-4e29-8be3-1607be88e54a
LibTextFilter	13	1.0.7	101045 101046	LibTextFilter	sirinsidiator	e2dbb014-9ae4-408e-9617-05161b5c9650
LibTextFormat	019	0.1.9	101050 101051	LibTextFormat	saranicole1980	cec7b602-5dc0-4af0-a949-cd5483dc7329
LibTraitResearch	105	1.05	101049 101050	LibTraitResearch	Delte	deb4d4a9-52ea-4c0d-b446-dbcf31a7d437
LibUndauntedPledges	102020	1.2.2	101046 101047	LibUndauntedPledges	code65536	9a183ede-4e80-4f0b-bf0c-13843831d603
LibZone	0901	9.01	101051 101052	LibZone	Baertram_ESOUI	271c1d87-b92b-4c7e-b1c6-199f8a56c776
LuiData	7231	7.2.3.1	101051 101052	LuiData	Dack.Janiels	9bb39b20-896b-4b23-a901-0c9d110edac7
LuiMedia	7134	7.1.3.4	101051 101052	LuiMedia	Dack.Janiels	0b695623-5ffb-4700-835c-fa628fdcb1ba
LuXhrysLibExtendedInventory	008	0.8a	101050	LibExtendedInventory	Xhrysanth	28dff940-503c-4c6c-8921-044ad6e35a86
LuXhrysLibItemLinkPreview	001	0.1a	101050	LibItemLinkPreview	Xhrysanth	075222fe-7845-484e-a060-69ddb8d571d8
SPFLib		1.0.0	101048 101049 101050	SPFLib	Springpeace2575	9d474e3f-7d1b-46fc-9b81-3949ad0f70e5
]==])
