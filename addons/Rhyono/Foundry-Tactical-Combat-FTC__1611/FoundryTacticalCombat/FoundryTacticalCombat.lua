--[[----------------------------------------------------------
    FOUNDRY TACTICAL COMBAT
    ----------------------------------------------------------
    FTC is a user interface overhaul designed the replace the Elder Scrolls Online
    interface and provide useful and time-sensitive information about combat events
    allowing players to better respond and react to evolving game situations.

    The add-on features several components:
    (1) Unit Frames
    (2) Buff Tracking
    (3) Combat Log
    (4) Scrolling Combat Text
    (5) Advanced Hotbar
    (6) Damage Statistics
    (7) Group Frames

    Author:   		Atropos / Philgo68 / Demiknight (Dark Brotherhood) / Rhyono (Homestead/Morrowind/HotR/CC/Dragon Bones/Summerset/Wolfhunter/Murkmire/Wrathstone/Elsweyr/Scalebreaker/Dragonhold/Harrowstorm/Greymoor/Stonethorn/Markarth/FoA/Blackwood/Walking Flame/Deadlands)
	  Contributors:	decay2 / Scootworks / Hoft / Antisenil / sirinsidiator / mitbulls / fugue / hypatian / Sharlikran / klarix
    Email:    		atropos@tamrielfoundry.com
    Version:  		1.34
    Updated:  		2026-11-15
  ]]--

--[[----------------------------------------------------------
    INITIALIZATION
  ]]----------------------------------------------------------

-- Core FTC Settings
FTC.addOnName = "FoundryTacticalCombat"
FTC.tag = "FTC"
FTC.modName = "Foundry Tactical Combat"
FTC.version = 1.34
FTC.settings = 0.60
FTC.language = GetCVar("language.2")
FTC.UI = WINDOW_MANAGER:CreateTopLevelWindow("FTC_UI")
FTC.LMW = LibMsgWin

-- Default Components
FTC.Defaults = {
  ["EnableFrames"] = true,
  ["EnableBuffs"] = true,
  ["EnableLog"] = true,
  ["EnableSCT"] = false,
  ["EnableHotbar"] = true,
  ["EnableStats"] = true,
  ["EnableRoleSorting"] = false,
  ["welcomed"] = 0,
}

-- Track component initialization
FTC.init = {}
FTC.fontListChoices = {}

-- Track custom display conditions
FTC.inMenu = false
FTC.inWelcome = false
FTC.move = false

--[[
 * Master Initialization Function
 * --------------------------------
 * Triggered by EVENT_ADD_ON_LOADED
 * --------------------------------
 ]]--
function FTC.Initialize(eventCode, addOnName)

  -- Only set up for FTC
  if (addOnName ~= FTC.addOnName) then return end

  -- Unregister setup event
  EVENT_MANAGER:UnregisterForEvent("FTC", EVENT_ADD_ON_LOADED)

  -- Load Saved Variables
  FTC.Vars = ZO_SavedVars:NewAccountWide('FTC_VARS', (FTC.settings * 100), nil, FTC.Defaults)

  -- Define target frame
  FTC.TARGET_WINDOW = ZO_TargetUnitFramereticleover or UnitFramesRebirth_TargetUnitFramereticleover

  -- Initialize UI Layer
  FTC.UI:Initialize()

  -- Setup Character Management
  FTC.Player:Initialize()
  FTC.Target:Initialize()
  FTC.Group:Initialize()

  -- Setup Damage Management
  FTC.Damage:Initialize()

  -- Unit Frames Component
  if (FTC.Vars.EnableFrames) then FTC.Frames:Initialize() end

  -- Active Buffs Component
  if (FTC.Vars.EnableBuffs) then FTC.Buffs:Initialize() end

  -- Combat Log Component
  if (FTC.Vars.EnableLog) then FTC.Log:Initialize() end

  -- Combat Text Component
  if (FTC.Vars.EnableSCT) then FTC.SCT:Initialize() end

  -- Advanced Hotbar Component
  if (FTC.Vars.EnableHotbar) then FTC.Hotbar:Initialize() end

  -- Combat Statistics
  if (FTC.Vars.EnableStats) then FTC.Stats:Initialize() end

  -- Menu Component
  FTC.Menu:Initialize()

  -- Register Event Handlers
  FTC:RegisterEvents()

  -- Register Slash Command
  SLASH_COMMANDS["/" .. FTC.tag] = FTC.Menu.Slash
  SLASH_COMMANDS["/" .. string.lower(FTC.tag)] = FTC.Menu.Slash

  -- Fire Setup Callback
  CALLBACK_MANAGER:FireCallbacks("FTC_Ready")
end

-- Hook initialization to EVENT_ADD_ON_LOADED
EVENT_MANAGER:RegisterForEvent("FTC", EVENT_ADD_ON_LOADED, FTC.Initialize)
