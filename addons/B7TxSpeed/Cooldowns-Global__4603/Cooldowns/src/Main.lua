-- -----------------------------------------------------------------------------
-- Cooldowns
-- Author:  @g4rr3t[NA], @nogetrandom[EU], @B7TxSpeed[EU]
-- Created: May 5, 2018
--
-- Track cooldowns for various sets
--
-- Main.lua
-- -----------------------------------------------------------------------------
Cool                  = {}
Cool.name             = "Cooldowns"
Cool.version          = "2.5.3"
Cool.dbVersion        = 1
Cool.slash            = "/cool"
Cool.prefix           = "[Cooldowns] "
Cool.inMenu           = false
Cool.HUDHidden        = false
Cool.inventoryHidden  = true
Cool.HUDUIHidden      = false
Cool.ForceShow        = false
Cool.hideInMenu	      = false
Cool.isInCombat       = false
Cool.isDead           = false
Cool.playerID         = 0
Cool.hasJorvuld	      = false
Cool.resTrackerOn     = false
Cool.JorvuldIds       = {
		-- Sets
		[93120]  = true, -- Master Architecht
		[93442]  = true, -- War Machine
		[93125]  = true, -- Inventor's Guard
		[93444]  = true, -- Automated Defense
		[150974] = true, -- Drake's Rush
		[154830] = true, -- Saxhleel
		[107141] = true, -- Olorime
		[109084] = true, -- Olorime (perfected)
		[113509] = true, -- Steadfast Hero
		[121878] = true, -- Yolnahkriin
		-- Synergies
		[121059] = true, -- Major Berserk (Storm Atronarch synergy)
		-- Passives
		[61685]  = true, -- Minor Sorcery (templar passive)
		[62320]  = true, -- Minor Prophecy (sorc passive)
		-- [137986] = true,
		-- [135923] = true,
}

Cool.spaulderTrack    = false

local EM = EVENT_MANAGER

-- -----------------------------------------------------------------------------
-- Level of debug output
-- 1: Low    - Basic debug info, show core functionality
-- 2: Medium - More information about skills and addon details
-- 3: High   - Everything
Cool.debugMode = 0
-- -----------------------------------------------------------------------------

function Cool:Trace(debugLevel, ...)
  if debugLevel <= Cool.debugMode then
    local message = zo_strformat(...)
    d(Cool.prefix .. message)
  end
end

-- -----------------------------------------------------------------------------
-- Startup
-- -----------------------------------------------------------------------------

function Cool.Initialize(event, addonName)
  if addonName ~= Cool.name then return end

  Cool:Trace(1, "Cool Loaded")
  EM:UnregisterForEvent(Cool.name, EVENT_ADD_ON_LOADED)

  -- Populate default settings for sets
  Cool.Defaults:Generate()

  -- Account-wide: Sets and synergy prefs
  Cool.preferences            = ZO_SavedVars:NewAccountWide("CooldownsVariables", Cool.dbVersion, nil, Cool.Defaults.Get())

  -- Per-Character: Synergy display status
  -- Other synergy preferences are still account-wide
  Cool.character              = ZO_SavedVars:New("CooldownsVariables", Cool.dbVersion, nil, Cool.Defaults.GetCharacter())
  Cool.Settings.Upgrade()

  -- Use saved debugMode value
  Cool.debugMode              = Cool.preferences.debugMode

  SLASH_COMMANDS[Cool.slash]  = Cool.UI.SlashCommand

  -- Update initial combat/dead state
  -- In the event that UI is loaded mid-combat or while dead
  Cool.isInCombat             = IsUnitInCombat("player")
  Cool.isDead                 = IsUnitDead("player")
  Cool.UI.ToggleHUD()

  Cool.Settings.Init()
  Cool.Tracking.RegisterEvents()
  Cool.Tracking.EnableSynergiesFromPrefs()
  Cool.Tracking.EnablePassivesFromPrefs()
  -- Disable CP at startup for now
  -- Cool.Tracking.EnableCPFromPrefs()

  -- Configure and register LibEquipmentBonus
  local LEB                   = LibEquipmentBonus
  local Equip                 = LEB:Init(Cool.name)
  Equip:Register(Cool.Tracking.EnableTrackingForSet, Cool.Tracking.EnableTrackingForCP)

  Cool:Trace(2, "Finished Initialize()")
end

-- -----------------------------------------------------------------------------
-- Event Hooks
-- -----------------------------------------------------------------------------

EM:RegisterForEvent(Cool.name, EVENT_ADD_ON_LOADED, Cool.Initialize)
