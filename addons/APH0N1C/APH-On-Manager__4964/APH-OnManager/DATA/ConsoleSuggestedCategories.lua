--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
AoM.ConsoleSuggestedCategories = AoM.CreateConsoleValueTable([==[
AAAConsoleUIShim	Libraries
AllAP	PvP
AltBossBar	Unit Mods
AlternateDeathRecap	Combat Mods
AltGroupFrames	Unit Mods
AM0RAutoInv	Discontinued & Outdated
AmIBlockingPlus	Plug-Ins & Patches
Andy	Utility Mods
AntiAllCaps	Chat Mods
AntiDismount	Utility Mods
ArchdruidTracker	Casting Bars, Cooldowns
ArmoryRoleSwitcher	Character Advancement
ArtaeumGroupTool	PvP
Atlas	Map, Coords, Compasses
AutoClaimGoldenPursuits	Bags, Bank, Inventory
AutoClaimTomePoints	Bags, Bank, Inventory
AutoComplete	Chat Mods
AutoGuildWelcome	Group, Guild & Friends
AutoInteract	Miscellaneous
AutoLuaMemoryCleaner	Utility Mods
AutoReadyCheck	Miscellaneous
AutoResearch	TradeSkill Mods
AwesomeGuildStore	Auction House & Vendors
BagSpaceIndicator	Bags, Bank, Inventory
BAHelp	Sorcerer
BeamMeUp	Map, Coords, Compasses
BetterScoreboard	PvP
BlockItemUsage	Bags, Bank, Inventory
CanThisBeCraftedAtHome	Developer Utilities
CBookFontStylist	Graphic UI Mods
CCSentinel	Discontinued & Outdated
CCTracker	Discontinued & Outdated
CharacterBoundItemHider	Bags, Bank, Inventory
CircularMinimap	Plug-Ins & Patches
CombatAlerts	Combat Mods
CombatTopHealthbar	Action Bar Mods
CrowdednESO	Utility Mods
CrutchAlerts	Raid Mods
CustomCompassPins	Libraries
Destinations	Map, Coords, Compasses
DolgubonsLazySetCrafter	TradeSkill Mods
DolgubonsLazyWritCreator	TradeSkill Mods
DryzlerElderGeekNetLore	Map, Coords, Compasses
DWAllianceRankProgress	Character Advancement
EsoAR	Unofficial game translations
EsoKR	Unofficial game translations
EsoTR	Unofficial game translations
ExoYsCruxTracker	Arcanist
EyeOnKeep	PvP
FCOLockpicker	Miscellaneous
FunKillFeed	PvP
GamePadHelper	Graphic UI Mods
GamepadInventoryTweaks	Bags, Bank, Inventory
GamepadStayMounted	Game Controller
GamepadUITweaks	Game Controller
GCDMonitor	Casting Bars, Cooldowns
GoldLedger	Bags, Bank, Inventory
GroupBuffPanels	Buff, Debuff, Spell
GroupKillFeed	PvP
GroupResources	Graphic UI Mods
GrumpysLarcenistTracker	Utility Mods
HideAntiquariansEyePrompt	Miscellaneous
HideGroupNecro	Graphic UI Mods
HodorReflexes	Combat Mods
HouseHotkey	Miscellaneous
IAHelper	Combat Mods
ImprovedAttributeBars	Info, Plug-in Bars
ImprovedNightMarketHUD	Info, Plug-in Bars
InsatiableHungerBlocker	Combat Mods
InstaQ	Discontinued & Outdated
ItalianScrollsOnline	Unofficial game translations
KillCount	PvP
LazyHorseFeed	Character Advancement
LibAddonMenu-2.0	Libraries
LibAlchemy	Libraries
LibAPH	Libraries
LibAsync	Libraries
LibCharacterKnowledge	Libraries
LibChatMessage	Libraries
LibCInteraction	Libraries
LibCombat2	Libraries
LibCombatAlerts	Libraries
LibConsoleDialogs	Libraries
LibConsoleLogger	Libraries
LibConsoleMenu	Libraries
LibCovetousCountess	Libraries
LibCustomMenu	Libraries
LibCustomNames	Libraries
LibDateTime	Libraries
LibDebugLogger	Libraries
LibDynamicMail	Libraries
LibGamepad	Libraries
LibGamepadTooltipFilters	Libraries
LibGetText	Libraries
LibGPS	Libraries
LibGroupBroadcast	Libraries
LibGroupCombatStats	Libraries
LibGroupPotionCooldowns	Libraries
LibGroupResources	Libraries
LibGroupUIReload	Libraries
LibHarvensAddonSettings	Libraries
LibHistoire	Libraries
LibId64	Libraries
LibItemLinkDecoder	Libraries
LibItemSets	Libraries
LibLazyCrafting	Libraries
LibLoreLibraryCesarska	Libraries
LibMapPing	Libraries
LibMapPins-1.0	Libraries
LibMediaProvider	Libraries
LibMessagePlugin	Libraries
LibMousePointer	Libraries
LibNotification	Libraries
LibPrice	Libraries
LibPromises	Libraries
LibQRCode	Libraries
LibQuestStatus	Libraries
LibRadialMenu	Libraries
LibRecipe	Libraries
LibSavedVars	Libraries
LibServerResetTime	Libraries
LibSideQuestPins	Libraries
LibSlashCommander	Libraries
LibTextFilter	Libraries
LibTextFormat	Libraries
LibTraitResearch	Libraries
LibUndauntedPledges	Libraries
LibVotansAddonList	Utility Mods
LibZone	Libraries
LiveAchiever	Character Advancement
LootLog	Bags, Bank, Inventory
LoreBooks	Map, Coords, Compasses
LoreLibrary	Map, Coords, Compasses
LoreTooltips	ToolTip
LuiData	Libraries
LuiExtended	Graphic UI Mods
LuiMedia	Libraries
LuXhrysLibExtendedInventory	Libraries
LuXhrysLibItemLinkPreview	Libraries
LycanMeter	Action Bar Mods
LykeionsAwareWolf	Combat Mods
LykeionsHomeSweetHome	Character Advancement
M0RMarkers	Raid Mods
MapPins	Map, Coords, Compasses
MARA	Miscellaneous
MasterThief	Miscellaneous
Medic	Utility Mods
MemoryUsage	Developer Utilities
Meterskull	Buff, Debuff, Spell
MiatsTickTracker	Casting Bars, Cooldowns
MoreTargetInformation	Graphic UI Mods
MSPAINTUI	Graphic UI Mods
MuchSmarterAutoLoot	Bags, Bank, Inventory
MuteyPacrooti	Miscellaneous
NumbersOnDummyOnly	Info, Plug-in Bars
OffBalanceTracker	Combat Mods
Olorime	Buff, Debuff, Spell
OneAPHaTime	Bags, Bank, Inventory
OneMorRockgrove	Combat Mods
PairsWellWithCheese	RolePlay
PermMemento	Miscellaneous
PetHealth	Unit Mods
PinAutoResizer	Map, Coords, Compasses
PinKiller	Map, Coords, Compasses
PointsofColor	Map, Coords, Compasses
ProvisioningWatcher	Buff, Debuff, Spell
PullCard	Raid Mods
QAutoConfirm	Discontinued & Outdated
QcellDreadsailReefHelper	Combat Mods
RanckorsBaggage	Bags, Bank, Inventory
RareFishTracker	Info, Plug-in Bars
RoaringOpportunist	Casting Bars, Cooldowns
Roomba	Bags, Bank, Inventory
SatiatedHunger	Combat Mods
ShogrinUI	UI Media
SkyShards	Map, Coords, Compasses
SmartLooter	Bags, Bank, Inventory
SPFLib	Libraries
StaggerTracker	Plug-Ins & Patches
STARS	Beta-version AddOns
StoneTalker	Casting Bars, Cooldowns
SulXan	Buff, Debuff, Spell
SurveyResetMarker	Map, Coords, Compasses
SynergyCooldown	Combat Mods
SynergyPriority	Combat Mods
TorigaCam	Miscellaneous
TorigaHUD	Graphic UI Mods
TradeSkills	TradeSkill Mods
TraitCraft	TradeSkill Mods
TurningTide	Casting Bars, Cooldowns
UnchainedHelper	Combat Mods
UndauntedDaily	Miscellaneous
UnderPressure	Tank
VCAP2	Beta-version AddOns
VersesAndVisions	Character Advancement
VestigeMirror	Miscellaneous
VotansFisherman	TradeSkill Mods
VotansMiniMap	Map, Coords, Compasses
WeaveDelays	Action Bar Mods
WizardsWardrobe	Action Bar Mods
YeOldeInfos	Info, Plug-in Bars
ZoneMountSwitcher	RolePlay
]==])
