-- ESO Adventurer Suite - Generated architecture inventory
-- Baseline: 0.29.779. This file declares ownership only; it does not alter feature behavior.
ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach
EPC.ArchitectureInventory = EPC.ArchitectureInventory or { files = {} }
local I = EPC.ArchitectureInventory

I.files["AbilityOverlays.lua"] = { subsystem="combat-ui", role="module", owner="AbilityOverlays", unifiedPublicMethods=true, noDualActionBarOwnership=true }
I.files["ActiveQuest.lua"] = { subsystem="hud", role="module", unifiedPublicMethods=true }
I.files["Activities.lua"] = { subsystem="feature", role="module" }
I.files["ActivityRunHistory.lua"] = { subsystem="feature", role="module" }
I.files["Advisor.lua"] = { subsystem="feature", role="module" }
I.files["AlchemyPotionMaker.lua"] = { subsystem="feature", role="module" }
I.files["AllianceRank.lua"] = { subsystem="pvp", role="module" }
I.files["AntiquityAssistant.lua"] = { subsystem="antiquities", role="module" }
I.files["AntiquityKnownDigSpawns.lua"] = { subsystem="antiquities", role="module" }
I.files["AntiquityLeadData.lua"] = { subsystem="antiquities", role="module" }
I.files["AntiquityLeadFinder.lua"] = { subsystem="antiquities", role="module" }
I.files["Architecture/Diagnostics.lua"] = { subsystem="architecture", role="module" }
I.files["Architecture/HudVisibility.lua"] = { subsystem="architecture", role="module" }
I.files["Architecture/HudEditor.lua"] = { subsystem="architecture", role="module", owner="NativeHUDEditor", nativeEditHud=true }
I.files["Architecture/Lifecycle.lua"] = { subsystem="architecture", role="module" }
I.files["Architecture/Runtime.lua"] = { subsystem="architecture", role="module", exactNameOwnership=true, }
I.files["Architecture/Validation.lua"] = { subsystem="architecture", role="module", owner="Validation" }
I.files["AttributeOptimizer.lua"] = { subsystem="feature", role="module" }
I.files["BankGridUnifiedV2.lua"] = { subsystem="inventory", role="module", owner="BankGridUnifiedV2", absorbedPatches=11, unifiedSortOwner=true, unifiedRefreshPolicy=true }
I.files["BattlegroundFinder.lua"] = { subsystem="pvp", role="module" }
I.files["Bindings.xml"] = { subsystem="feature", role="layout" }
I.files["BossMechanicsAssistant.lua"] = { subsystem="combat", role="module" }
I.files["BossMechanicsData.lua"] = { subsystem="combat", role="module" }
I.files["BugCatcher.lua"] = { subsystem="core", role="module" }
I.files["ChallengeDifficultyOverlay.lua"] = { subsystem="hud", role="module" }
I.files["ChampionOptimizer.lua"] = { subsystem="feature", role="module" }
I.files["ChampionOverlay.lua"] = { subsystem="hud", role="module" }
I.files["CharacterGearScreen.lua"] = { subsystem="equipment", role="module", owner="CharacterGearScreen", unifiedPublicMethods=true }
I.files["Clock.lua"] = { subsystem="hud", role="module" }
I.files["Combat.lua"] = { subsystem="combat", role="module", unifiedPublicMethods=true }
I.files["CombatPresentation.lua"] = { subsystem="combat", role="module" }
I.files["CommunityData/SuiteCommunityAD.lua"] = { subsystem="resource-data", role="module" }
I.files["CommunityData/SuiteCommunityDC.lua"] = { subsystem="resource-data", role="module" }
I.files["CommunityData/SuiteCommunityDLC.lua"] = { subsystem="resource-data", role="module" }
I.files["CommunityData/SuiteCommunityEP.lua"] = { subsystem="resource-data", role="module" }
I.files["CommunityData/SuiteCommunityNF.lua"] = { subsystem="resource-data", role="module" }
I.files["CompanionOptimizer.lua"] = { subsystem="feature", role="module" }
I.files["CompassFocusedInfoOverlay.lua"] = { subsystem="hud", role="module" }
I.files["Compatibility.lua"] = { subsystem="core", role="module" }
I.files["ControllerSupport.lua"] = { subsystem="core", role="module" }
I.files["Core.lua"] = { subsystem="core", role="module" }
I.files["CraftingInventoryGrid.lua"] = { subsystem="inventory", role="module" }
I.files["CraftingMaterialHunt.lua"] = { subsystem="world-map", role="module" }
I.files["Data.lua"] = { subsystem="feature", role="module" }
I.files["DualActionBar.lua"] = { subsystem="combat-ui", role="module", owner="DualActionBar", unifiedPublicMethods=true }
I.files["DungeonChestFinder.lua"] = { subsystem="feature", role="module" }
I.files["DungeonFinder.lua"] = { subsystem="group-finder", role="module" }
I.files["DungeonHistory.lua"] = { subsystem="feature", role="module" }
I.files["EASArchiveHelper/bootstrap.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/data/abilities.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/data/defaults.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/init.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/languages/en.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/misc/achievements.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/misc/alarms.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/misc/events.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/misc/markers.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/misc/utility.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/ui/buffSelector.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/ui/icons.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EASArchiveHelper/ui/ui.lua"] = { subsystem="infinite-archive", role="module" }
I.files["EdgeInfoBar.lua"] = { subsystem="hud", role="module" }
I.files["EnchantPlus.lua"] = { subsystem="inventory", role="module" }
I.files["EncounterReminders.lua"] = { subsystem="feature", role="module" }
I.files["Endgame.lua"] = { subsystem="feature", role="module" }
I.files["EndgameMeta.lua"] = { subsystem="feature", role="module" }
I.files["Engine.lua"] = { subsystem="core", role="module" }
I.files["FinderSuite.lua"] = { subsystem="group-finder", role="module" }
I.files["GameModeReport.lua"] = { subsystem="combat", role="module" }
I.files["GearLoadoutOverlay.lua"] = { subsystem="equipment", role="module" }
I.files["GearOptimizer.lua"] = { subsystem="equipment", role="module" }
I.files["GoldenPursuits.lua"] = { subsystem="hud", role="module" }
I.files["GroupFinderPlusIntegration.lua"] = { subsystem="group-finder", role="module" }
I.files["GroupFinderPlusSettings.lua"] = { subsystem="group-finder", role="settings-extension", owner="Settings" }
I.files["GroupLootNotifier.lua"] = { subsystem="feature", role="module" }
I.files["InfiniteArchiveOverlay.lua"] = { subsystem="hud", role="module", unifiedPublicMethods=true }
I.files["InventoryGrid.lua"] = { subsystem="inventory", role="module", owner="InventoryGrid", authoritativeNativeCategoryRefresh=true, authoritativeNativeCategoryApply=true, authoritativeNativeCategoryCollect=true, authoritativeNativeLinkResolver=true, directCellDragOwner=true }
I.files["InventoryRepairTab.lua"] = { subsystem="inventory", role="module" }
I.files["Journal.lua"] = { subsystem="feature", role="module" }
I.files["LoadoutManager.lua"] = { subsystem="equipment", role="module" }
I.files["Localization.lua"] = { subsystem="localization", role="module" }
I.files["LocalizationRuntime.lua"] = { subsystem="localization", role="module" }
I.files["LoreBooks/Data/Data.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Data/Serialization.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Data/ZoneCache.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/EASLoreLibrary.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/EASLoreLibraryData.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Main/PinTypes.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Main/QuestDependent.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Main/Settings.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Main/Utils.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/CompassPins.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/MapPinController.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/MapPins.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/MarkerPin.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/ProximityPinSet.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/WorldPins.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/Pins/WorldPins.xml"] = { subsystem="lorebooks", role="layout" }
I.files["LoreBooks/UI/FilterMenu.lua"] = { subsystem="lorebooks", role="module" }
I.files["LoreBooks/UI/LoreLibraryMenu.lua"] = { subsystem="lorebooks", role="module" }
I.files["MailColorPicker.lua"] = { subsystem="feature", role="module" }
I.files["Maintenance.lua"] = { subsystem="feature", role="module" }
I.files["MarketPriceChecker.lua"] = { subsystem="market", role="module" }
I.files["MarketPriceSettings.lua"] = { subsystem="market", role="settings-extension", owner="Settings" }
I.files["MasterAchievementTracker.lua"] = { subsystem="feature", role="module" }
I.files["MerchantFenceCategoryBar.lua"] = { subsystem="inventory", role="module" }
I.files["MiniMap.lua"] = { subsystem="world-map", role="module", unifiedPublicMethods=true }
I.files["ModernAppUI.lua"] = { subsystem="feature", role="module" }
I.files["NativeLootChatLayout.lua"] = { subsystem="feature", role="module" }
I.files["NativeNotificationOverlay.lua"] = { subsystem="hud", role="module" }
I.files["OverlandDifficulty.lua"] = { subsystem="feature", role="module" }
I.files["PerformanceOverlay.lua"] = { subsystem="hud", role="module" }
I.files["PlayerRequestOverlay.lua"] = { subsystem="hud", role="module" }
I.files["PvP.lua"] = { subsystem="pvp", role="module" }
I.files["PvPCombatRuntime.lua"] = { subsystem="combat", role="module" }
I.files["PvPCompassRuntime.lua"] = { subsystem="pvp", role="module" }
I.files["PvPSettings.lua"] = { subsystem="pvp", role="settings-extension", owner="Settings" }
I.files["PvPWorldRuntime.lua"] = { subsystem="pvp", role="module" }
I.files["QuestFinder.lua"] = { subsystem="feature", role="module" }
I.files["QuickslotOverlay.lua"] = { subsystem="combat-ui", role="module", unifiedPublicMethods=true }
I.files["RecipeStyleLearner.lua"] = { subsystem="feature", role="module" }
I.files["ReleaseMetadata.lua"] = { subsystem="core", role="module" }
I.files["RepairCostOverlay.lua"] = { subsystem="hud", role="module" }
I.files["ResourcePins.lua"] = { subsystem="world-map", role="module", unifiedPublicMethods=true }
I.files["ResourcePinsWorld.xml"] = { subsystem="world-map", role="layout" }
I.files["Reticle.lua"] = { subsystem="combat-ui", role="module" }
I.files["Role.lua"] = { subsystem="feature", role="module" }
I.files["RotationAssistant.lua"] = { subsystem="combat-ui", role="module", unifiedPublicMethods=true }
I.files["RuntimePerformanceController.lua"] = { subsystem="performance", role="module", owner="RuntimePerformance", consolidatedModules=1, unifiedActivationOwner=true, unifiedCombatStateOwner=true, unifiedTeamTimerOwner=true, sharedRuntimeOwnership=true, exactNameRuntimeOwnership=true }
I.files["SelfTest.lua"] = { subsystem="core", role="module" }
I.files["SetJournal.lua"] = { subsystem="feature", role="module" }
I.files["Settings.lua"] = { subsystem="settings", role="module", owner="Settings", extensionRegistry=true }
I.files["SkillMeta.lua"] = { subsystem="feature", role="module" }
I.files["SkillMorphCompare.lua"] = { subsystem="feature", role="module" }
I.files["SkillMorphCompare.xml"] = { subsystem="feature", role="layout" }
I.files["SkillPointFinder.lua"] = { subsystem="feature", role="module" }
I.files["SkillPointFinderData.lua"] = { subsystem="feature", role="module" }
I.files["StableTimer.lua"] = { subsystem="hud", role="module" }
I.files["SynergyOverlay.lua"] = { subsystem="combat-ui", role="module" }
I.files["TargetBuild.lua"] = { subsystem="feature", role="module" }
I.files["TeamVisibility.lua"] = { subsystem="feature", role="module" }
I.files["TeleporterSuiteExclusives.lua"] = { subsystem="world-map", role="module" }
I.files["TickTracker.lua"] = { subsystem="unit-frames", role="module" }
I.files["Travel.lua"] = { subsystem="world-map", role="module", unifiedPublicMethods=true }
I.files["TreasureLocator.lua"] = { subsystem="world-map", role="module" }
I.files["UI.lua"] = { subsystem="feature", role="module" }
I.files["UnitFrames.lua"] = { subsystem="unit-frames", role="module", unifiedPublicMethods=true }
I.files["UtilitySuite.lua"] = { subsystem="feature", role="module" }
I.files["WayshrineAutoMessage.lua"] = { subsystem="feature", role="module" }

I.files["Architecture/Inventory.lua"] = { subsystem="architecture", role="module", owner="Inventory" }
I.files["FurnishingVault.lua"] = { subsystem="inventory", role="module", owner="FurnishingVault" }
I.files["HouseStorage.lua"] = { subsystem="inventory", role="module", owner="HouseStorage", sharedScenePolicy=true }

function I:GetSummary()
 local out={total=0,patches=0,subsystems={}}
 for _,v in pairs(self.files) do out.total=out.total+1; if v.role=="patch" then out.patches=out.patches+1 end; out.subsystems[v.subsystem]=(out.subsystems[v.subsystem] or 0)+1 end
 return out
end

-- Verified architecture audit metadata (0.29.779 baseline)
I.audit = {
  baseline = "0.29.779",
  productionLuaXml = 246,
  patchFiles = 94,
  currentManifestLuaXml = 152,
  currentLoadedPatchFiles = 0,
  repositoryStandalonePatchFiles = 0,
  -- Repo-wide loaded-file scan: public methods still redefined later in-file.
  -- These are internal wrapper stacks, not standalone patch files.
  -- Repo-wide loaded-file scan: all historical public-method override stacks
  -- have been flattened behind one stable public owner per method.
  remainingInternalOverrideHotspots = 0,
  internalOverrideHotspots = {},
  sampledRuntimeFiles = 20,
  sampledDirectEvents = 117,
  sampledDirectUpdates = 38,
  sampledOnUpdateReferences = 13,
  sampledSceneCallbacks = 6,
  sampledHooks = 9,
  sampledAddonLoadedReferences = 13,
}

function I:GetAudit()
 return self.audit
end
