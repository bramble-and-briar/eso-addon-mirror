-- Scrollkeeper Guild Tools Addon
-- ScrollkeeperColorThemes
   
-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

-- Bail out if the framework isn't present
if type(SF) ~= "table" or not SF.initAddon then
  d(SF.func._L("ScrollkeeperColorThemes", "ERROR_FRAMEWORK_MISSING"))
  return
end

-- Initialize module
Scrollkeeper.ColorThemes = Scrollkeeper.ColorThemes or { Name = "ScrollkeeperColorThemes" }
local _addon = Scrollkeeper.ColorThemes

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperColorThemes = Scrollkeeper.ColorThemes

-- 🎨 Define themes with hex values
local themes = {
  Ember = { -- For Dingo
    border = "5c1818",  -- Red borders (title bar)
    header = "EAC76A",  -- Flame gold headers (titles)
    text = "D9772A",    -- Copper text (context menus)
    panel = "811b1b",   -- Dark panels
    accent = "bc9153"   -- Yellow accent
  },
  Forge = { 
    border = "4c4b4b",  -- Dark gray borders
    header = "E1E1E1",  -- Steel headers
    text = "A3A3A3",    -- Medium gray text
    panel = "262424",   -- Very dark panels
    accent = "5C5A57"   -- Iron accent
  },
  Ocean = { -- For Meg
    border = "194174",  -- Blue borders
    header = "6FD3C3",  -- Foam green headers
    text = "33CCCC",    -- Turquoise text
    panel = "153241",   -- Dark blue panels
    accent = "1E6F63"   -- Kelp accent
  },
  Sky = {
    border = "502857",  -- Violet borders
    header = "F2A3C7",  -- Pink headers
    text = "C6B6D9",    -- Lavender text
    panel = "40364A",   -- Twilight panels
    accent = "843356"   -- Rosy accent
  },
  Regalia = { -- For Brady
    border = "702963",  -- Byzantine purple borders
    header = "E4D7A3",  -- Ivory headers
    text = "ADB2BE",    -- Pewter text
    panel = "3A1730",   -- Aubergine panels
    accent = "7F6026"   -- Ochre accent
  },
  Briar = { -- For EU's Rose guilds
    border = "5B2A2A",  -- Rosewood borders
    header = "E6DCCB",  -- Parchment headers
    text = "7C8F55",    -- Olive text
    panel = "9B6A6A",   -- Faded Rose Ash panels
    accent = "5F7F73"   -- Verdigris accent
  },  
  Jungle = { -- For Wookie
    border = "3F4935", -- Olive bark
    header = "C8BD72", -- Filtered sunlight
    text   = "5EAA8A", -- Jade foliage
    panel  = "0B291B", -- Deep forest
    accent = "667F61"  -- Deep sage
  },
}

-- 💾 Settings defaults
local defaults = { currentTheme = "Ember" }

-- Get settings using unified system
local function getSettings()
  return SF.getModuleSettings(_addon.Name, defaults)
end

-- Theme applicator
local function ApplyTheme(name)
  local t = themes[name] or themes.Ember
  
  -- Update framework theme
  if SF.applyThemeFromHex then
    SF.applyThemeFromHex(t)
  end
  
  -- Update all registered windows
  if SF.updateAllThemedWindows then
    SF.updateAllThemedWindows()
  end
end

-- Build dropdown control with submenu
local function buildControls()
  local settings = getSettings()
  
  -- Get theme names
  local themeNames = {
    SF.func._L("ScrollkeeperColorThemes", "THEME_EMBER"),
    SF.func._L("ScrollkeeperColorThemes", "THEME_FORGE"),
    SF.func._L("ScrollkeeperColorThemes", "THEME_OCEAN"),
    SF.func._L("ScrollkeeperColorThemes", "THEME_SKY"),
	SF.func._L("ScrollkeeperColorThemes", "THEME_REGALIA"),
	SF.func._L("ScrollkeeperColorThemes", "THEME_BRIAR"),
	SF.func._L("ScrollkeeperColorThemes", "THEME_JUNGLE")
  }
         
  return {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperColorThemes", "SUBMENU_NAME"),
      controls = {
        {
          type = "description", 
          text = SF.func._L("ScrollkeeperColorThemes", "DESCRIPTION")
        },
        {
          type    = "dropdown",
          name    = SF.func._L("ScrollkeeperColorThemes", "ACTIVE_THEME"),
          tooltip = SF.func._L("ScrollkeeperColorThemes", "ACTIVE_THEME_TOOLTIP"),
          choices = themeNames,
          getFunc = function() 
            return settings.currentTheme
          end,
          setFunc = function(choice)
            settings.currentTheme = choice
            ApplyTheme(choice)
          end,
          default = defaults.currentTheme,
          width   = "half",
        },
        {
          type = "description",
          text = function()
            local current = settings.currentTheme or SF.func._L("ScrollkeeperColorThemes", "STATUS_UNKNOWN")
            return string.format(SF.func._L("ScrollkeeperColorThemes", "CURRENT_THEME"), current)
          end,
        },
        {
          type = "description",
          text = SF.func._L("ScrollkeeperColorThemes", "NOTE")
        }
      }
    }
  }
end

-- ⏳ Initialize
local function initialize()
  local settings = getSettings()
  
  -- Build and register controls
  if SF_Set and SF_Set.RegisterModuleOptions then
    local controls = buildControls()
    if #controls > 0 then
      SF_Set.RegisterModuleOptions(_addon.Name, controls)
    end
  end

  -- Apply current theme
  ApplyTheme(settings.currentTheme)
end

EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  -- Now initialize UI elements
  initialize()
end)

-- Also register for the framework callback
CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)