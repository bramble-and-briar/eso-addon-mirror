-- Scrollkeeper Guild Tools 
-- ScrollkeeperFramework

-- 🪞 Local references
Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Framework = Scrollkeeper.Framework or {
  Name = "ScrollkeeperFramework",
  Version = "1.3",
}

-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperFramework = Scrollkeeper.Framework

-- Prevent multiple initialization
if SF._initialized then
  d("[ScrollkeeperFramework] " .. SF.func._L("ScrollkeeperFramework", "ALREADY_INITIALIZED"))
  return
end

-- CRITICAL: Initialize func table immediately	  
SF.func = SF.func or {}

-- Add the _L function with proper fallback behavior
SF.func._L = SF.func._L or function(addonName, localizationName)
  -- Ensure localization table exists
  if not Scrollkeeper.Localization then
    d("[ScrollkeeperFramework] WARNING: Scrollkeeper.Localization table not found!")
    return localizationName or "MISSING_KEY"
  end
  
  -- Check for addon section
  if type(Scrollkeeper.Localization[addonName]) ~= "table" then
    d("[ScrollkeeperFramework] WARNING: No localization for addon: " .. tostring(addonName))
    return localizationName or "MISSING_KEY"
  end
  
  -- Get localized string
  local str = Scrollkeeper.Localization[addonName][localizationName]
  if type(str) == "string" and str ~= "" then
    return str
  end
  
  d("[ScrollkeeperFramework] WARNING: Missing localization key: " .. tostring(addonName) .. "." .. tostring(localizationName))
  return localizationName or "MISSING_KEY"
end

-- Library Integration
SF.Libraries = SF.Libraries or {}

-- Initialize LibDateTime for better timestamp handling
local function initializeDateTime()
  if LibDateTime then
    SF.Libraries.dateTime = LibDateTime
    -- Add helper functions
    SF.func.formatTimestamp = function(timestamp)
      return LibDateTime:Format("short", timestamp)
    end
    SF.func.formatDate = function(timestamp)
      return LibDateTime:Format("date", timestamp)
    end
    return true
  else
    -- Fallback formatting functions
    SF.func.formatTimestamp = function(timestamp)
      return os.date("%m/%d %H:%M", timestamp)
    end
    SF.func.formatDate = function(timestamp)
      return os.date("%Y-%m-%d", timestamp)
    end
    return false
  end
end

-- 📝 Initialize other essential functions
SF.func.getKioskTime = SF.func.getKioskTime or function() return 0 end
SF.func.isStringEmpty = SF.func.isStringEmpty or function(s) return s == nil or s == "" end

-- Add splitToArray function that modules need
SF.func.splitToArray = SF.func.splitToArray or function(text, delimiter)
  if not text or text == '' then return {} end
  
  local pos, arr = 1, {}
  while true do
    local s, e = string.find(text, delimiter, pos, true)
    if not s then break end
    table.insert(arr, text:sub(pos, s - 1))
    pos = e + 1
  end
  table.insert(arr, text:sub(pos))
  return arr
end

-- Add color conversion functions
SF.func.RGBtoHex = SF.func.RGBtoHex or function(r, g, b, list)
  if list then
    r, g, b = list[1], list[2], list[3]
  end
  r = zo_clamp(r or 0, 0, 1)
  g = zo_clamp(g or 0, 0, 1)
  b = zo_clamp(b or 0, 0, 1)
  return string.format("%02X%02X%02X",
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5)
  )
end

-- Add HexToRGBA functions
SF.func.HexToRGBA = SF.func.HexToRGBA or function(hex)
  if type(hex) ~= "string" then
    return 1, 1, 1, 1
  end

  -- strip leading '#' if present
  hex = hex:gsub("^#", "")
  local len = #hex

  local r, g, b, a
  if len == 6 then
    a = 255
    r = tonumber(hex:sub(1,2), 16)
    g = tonumber(hex:sub(3,4), 16)
    b = tonumber(hex:sub(5,6), 16)
  elseif len == 8 then
    a = tonumber(hex:sub(1,2), 16)
    r = tonumber(hex:sub(3,4), 16)
    g = tonumber(hex:sub(5,6), 16)
    b = tonumber(hex:sub(7,8), 16)
  else
    -- invalid input, default to white
    return 1, 1, 1, 1
  end

  -- normalize 0—255 → 0—1
  return r / 255, g / 255, b / 255, a / 255
end

-- Scrollkeeper Theme System
-- Theme colors are managed by ScrollkeeperColorThemes module
-- This provides the structure and application functions only
SF.theme = SF.theme or {
  current = "Ember",
  colors = {
    border = {0.36, 0.09, 0.09, 1},   -- Default Ember theme fallback
    header = {0.96, 0.85, 0.50, 1},
    text = {1, 0.6, 0.2, 1},
    panel = {0.51, 0.11, 0.11, 1},
    accent = {0.54, 0.45, 0.33, 1}
  }
}

-- Apply theme colors to any control
function SF.applyThemeColor(control, colorType)
  if not control or not SF.theme or not SF.theme.colors or not SF.theme.colors[colorType] then 
    return 
  end
  
  local color = SF.theme.colors[colorType]
  
  if control.SetColor then
    control:SetColor(color[1], color[2], color[3], color[4])
  elseif control.SetCenterColor then
    control:SetCenterColor(color[1], color[2], color[3], color[4])
  elseif control.SetEdgeColor then
    control:SetEdgeColor(color[1], color[2], color[3], color[4])
  end
end

-- Apply theme to title bar (convenience function)
function SF.applyThemeToTitleBar(titleBar, titleLabel)
  if not titleBar or not SF.theme or not SF.theme.colors then return end
  
  -- Title bar background uses header color darkened
  if titleBar.SetCenterColor then
    local h = SF.theme.colors.header
    titleBar:SetCenterColor(h[1] * 0.5, h[2] * 0.5, h[3] * 0.5, 1)
  end
  
  -- Border uses border color
  if titleBar.SetEdgeColor then
    SF.applyThemeColor(titleBar, "border")
  end
  
  -- Title text uses header color
  if titleLabel then
    SF.applyThemeColor(titleLabel, "header")
  end
end

-- Ornate window frame
 SF.ORNATE_FRAME_TEXTURE = "Scrollkeeper/ScrollkeeperFramework/textures/ui-border_lineonly.dds"
 SF.ORNATE_FRAME_EDGE_W  = 128
 SF.ORNATE_FRAME_EDGE_H  = 16

function SF.addOrnateFrame(window)
  local frame = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  frame:SetAnchorFill(window)
  frame:SetCenterColor(0, 0, 0, 0)
  frame:SetEdgeTexture(SF.ORNATE_FRAME_TEXTURE, SF.ORNATE_FRAME_EDGE_W, SF.ORNATE_FRAME_EDGE_H)
  frame:SetDrawLevel(10)
  
  return frame
end

-- Convert hex to theme color
function SF.setThemeColorFromHex(colorType, hexValue)
  if not SF.theme or not SF.theme.colors or not SF.theme.colors[colorType] then return end
  
  local r, g, b, a = SF.func.HexToRGBA(hexValue)
  SF.theme.colors[colorType] = {r, g, b, a}
end

-- Get theme color as hex string for text coloring
function SF.getThemeColorHex(colorType)
  if not SF.theme or not SF.theme.colors then return "FFFFFF" end
  local color = SF.theme.colors[colorType]
  if not color then return "FFFFFF" end
  
  return SF.func.RGBtoHex(color[1], color[2], color[3])
end

-- Apply full theme from hex values
function SF.applyThemeFromHex(themeData)
  if not themeData or not SF.theme then return end
  for colorType, hexValue in pairs(themeData) do
    SF.setThemeColorFromHex(colorType, hexValue)
  end
  
  -- Notify all registered windows to update
  CALLBACK_MANAGER:FireCallbacks("Scrollkeeper_ThemeChanged")
end

-- Window registration for theme updates
SF.themedWindows = SF.themedWindows or {}

function SF.registerThemedWindow(windowName, updateFunction)
  if not windowName or not updateFunction then return end
  SF.themedWindows[windowName] = updateFunction
end

function SF.updateAllThemedWindows()
  if not SF.themedWindows then return end
  for name, updateFunc in pairs(SF.themedWindows) do
    if type(updateFunc) == "function" then
      local success, err = pcall(updateFunc)
      if not success then
        d("[ScrollkeeperFramework] Error updating themed window " .. name .. ": " .. tostring(err))
      end
    end
  end
end

-- Storage for all queued modules' controls & icons
SF._settings = SF._settings or {}

-- Framework metadata
SF._addon = {
  Name        = "Scrollkeeper",
  Version     = "1.3",
  Author      = "WolfStar07",
  displayName = SF.func._L("ScrollkeeperFramework", "DISPLAY_NAME"),
}

-- Initialize framework settings table
Scrollkeeper.Settings = Scrollkeeper.Settings or {}
local SF_Set = Scrollkeeper.Settings

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperFramework_Settings = Scrollkeeper.Settings

-- 🌟 Module registration functions MUST exist before modules load
function SF.RegisterModuleOptions(modName, controlsTable)
  if not modName or type(controlsTable) ~= "table" then
    d("[ScrollkeeperFramework] ERROR: Invalid module registration: " .. tostring(modName))
    return
  end
  SF._settings[modName] = SF._settings[modName] or {}
  SF._settings[modName].controls = controlsTable
end

-- Alias for modules
SF_Set.RegisterModuleOptions = SF.RegisterModuleOptions

-- Icon registration
function SF_Set:AddModuleIcon(modName, iconPath)
  if not modName then return end
  SF._settings[modName] = SF._settings[modName] or {}
  SF._settings[modName].icon = iconPath
end

-- Register module init callbacks
function SF.initAddon(addonName, callback)
  if not addonName or not callback then return end
  
  local eventId = addonName .. "_Init"
  EVENT_MANAGER:RegisterForEvent(eventId, EVENT_ADD_ON_LOADED, function(_, loadedName)
    if loadedName == addonName then
      local success, error = pcall(callback)
      if not success then
        d("[ScrollkeeperFramework] ERROR initializing " .. addonName .. ": " .. tostring(error))
      end
      EVENT_MANAGER:UnregisterForEvent(eventId, EVENT_ADD_ON_LOADED)
    end
  end)
end

-- Panel factory (single master panel registration)
function SF.setPanel()
  if SF.panel then 
    return SF.panel 
  end
  local LAM2 = LibAddonMenu2
  if not LAM2 then 
    d("[ScrollkeeperFramework] " .. SF.func._L("ScrollkeeperFramework", "LAM2_UNAVAILABLE"))
    return nil
  end

  SF.panel = LAM2:RegisterAddonPanel(SF._addon.Name, {
    type                = "panel",
    name                = SF._addon.Name,
    displayName         = SF._addon.displayName,
    author              = SF._addon.Author,
    version             = SF._addon.Version,
    registerForRefresh  = true,
    registerForDefaults = true,
  })
  
  return SF.panel
end
-- 🌍 Megaserver Detection
local function detectRegion()
  local world = GetWorldName()
  if world:find("NA") or world:find("PTS") then return "NA" end
  if world:find("EU") then return "EU" end
  return "NA"
end
SF._addon.region = detectRegion()

-- Store the normalized megaserver name (PTS maps to NA Megaserver)
local _worldName = GetWorldName() or "NA Megaserver"
SF._addon.megaserver = _worldName:find("EU") and "EU Megaserver" or "NA Megaserver"

-- Enhanced getModuleSettings with megaserver support
function SF.getModuleSettings(moduleName, defaults)
  if not moduleName or type(moduleName) ~= "string" then
    d("[ScrollkeeperFramework] ERROR: Invalid module name: " .. tostring(moduleName))
    return {}
  end
  
  if type(ScrollkeeperSettings) ~= "table" then
    ScrollkeeperSettings = {}
  end

  -- Normalize the megaserver key. PTS uses the NA Megaserver key so settings
  -- are shared between live NA and PTS rather than siloed under a PTS-only key.
  local worldName = GetWorldName() or "NA Megaserver"
  local megaserver
  if worldName:find("EU") then
    megaserver = "EU Megaserver"
  else
    megaserver = "NA Megaserver"
  end
  local settingsKey = moduleName .. "_" .. megaserver
  
  -- Return existing megaserver-specific settings, or create defaults
  if not ScrollkeeperSettings[settingsKey] then
    ScrollkeeperSettings[settingsKey] = ZO_DeepTableCopy(defaults or {})
  end
  return ScrollkeeperSettings[settingsKey]
end

-- 📅️ Trader‐flip timing logic
-- Both NA (19:00 UTC) and EU (14:00 UTC) flip at a fixed UTC time year-round.

local function getFlipHourUTC(region)
  if region == "EU" then
    return 14  -- 3pm CET / 4pm CEST — always 14:00 UTC
  end
  return 19    -- NA: 2pm EST / 3pm EDT — always 19:00 UTC
end

-- ⏱️ Public API: seconds until next trader flip (UTC-correct)
function SF_Set.secondsUntilTraderFlip()
  local now = GetTimeStamp()
  local flipUTCsecs = getFlipHourUTC(SF._addon.region) * 3600
  
  -- Get current UTC time components
  local currentHour = tonumber(os.date("!%H", now))
  local currentMin = tonumber(os.date("!%M", now))
  local currentSec = tonumber(os.date("!%S", now))
  local currentDaySeconds = currentHour * 3600 + currentMin * 60 + currentSec
  
  -- Get weekday (0=Sun, 1=Mon, 2=Tue, etc.)
  local weekday = tonumber(os.date("!%w", now))
  
  -- Calculate seconds until next Tuesday at flip hour
  local secondsUntilFlip
  
  if weekday == 2 then
    -- Today is Tuesday
    if currentDaySeconds < flipUTCsecs then
      -- Flip hasn't happened yet today
      secondsUntilFlip = flipUTCsecs - currentDaySeconds
    else
      -- Flip already happened, next is in 7 days
      secondsUntilFlip = (7 * 86400) - currentDaySeconds + flipUTCsecs
    end
  else
    -- Not Tuesday - calculate days until next Tuesday
    local daysUntilTuesday = (2 - weekday + 7) % 7
    if daysUntilTuesday == 0 then
      daysUntilTuesday = 7  -- Next week's Tuesday
    end
    secondsUntilFlip = (daysUntilTuesday * 86400) - currentDaySeconds + flipUTCsecs
  end
  
  return math.max(0, secondsUntilFlip)
end

-- 📦 Master initialization with better error handling
function SF.initialized()
  if SF._initialized then
    return
  end
  
  -- Initialize libraries first
  initializeDateTime()
  
  -- Ensure panel exists
  local panel = SF.setPanel()
  if not panel then
    d("[ScrollkeeperFramework] " .. SF.func._L("ScrollkeeperFramework", "CRITICAL_ERROR"))
    return
  end

  -- Define module order explicitly for consistent settings panel ordering
  local MODULE_ORDER = {
    "ScrollkeeperStandardCommands",
    "ScrollkeeperColorThemes",
    "ScrollkeeperContextMenu",
    "ScrollkeeperData",
	"ScrollkeeperAttendance",
	"ScrollkeeperApplications",
    "ScrollkeeperHistory",
    "ScrollkeeperNotebookMail",
    "ScrollkeeperNotebook",
    "ScrollkeeperProvisionMember",
    "ScrollkeeperRoster",
    "ScrollkeeperWelcome",
  }

-- Build ONE master controls array from ALL modules IN ORDER
local allControls = {
  { type = "description", text = SF.func._L("ScrollkeeperFramework", "HEADER_DESC") },
  {
    type = "button",
    name = SF.func._L("ScrollkeeperFramework", "DONATE_BUTTON"),
    tooltip = SF.func._L("ScrollkeeperFramework", "DONATE_TOOLTIP"),

    func = function()
      -- Open mail interface with pre-filled donation
      local function prepareMail()
        if MAIL_SEND then
          MAIL_SEND.to:SetText("@WolfStar07")
          MAIL_SEND.subject:SetText("Scrollkeeper Donation")
          MAIL_SEND.body:SetText("Thank you for this amazing addon!")
          MAIL_SEND:SetMoneyAttachmentMode()
          MAIL_SEND:AttachMoney(0, 1000)
        end
      end
      
      if MAIL_SEND then
        MAIL_SEND:ClearFields()
      end
      
      if SCENE_MANAGER:IsShowing("mailSend") then
        prepareMail()
      else
        SCENE_MANAGER:Show("mailSend")
        zo_callLater(prepareMail, 100)
      end
    end,
    width = "half",
  },
}

  -- Collect controls from each module in order
  local modulesFound = 0
  for _, modName in ipairs(MODULE_ORDER) do
    local data = SF._settings[modName]
    if data and data.controls and type(data.controls) == "table" then
      for _, control in ipairs(data.controls) do
        if type(control) == "table" then
          table.insert(allControls, control)
        end
      end
      modulesFound = modulesFound + 1
	else
    end
  end
  
  -- Add unordered modules
  for modName, data in pairs(SF._settings) do
    local found = false
    for _, orderedName in ipairs(MODULE_ORDER) do
      if orderedName == modName then
        found = true
        break
      end
    end
    if not found and data.controls and type(data.controls) == "table" then
      for _, control in ipairs(data.controls) do
        if type(control) == "table" then
          table.insert(allControls, control)
        end
      end
      modulesFound = modulesFound + 1
    end
  end

  -- Register ALL controls in ONE call to LibAddonMenu2
  if LibAddonMenu2 and #allControls > 2 then
    local success, error = pcall(function()
      LibAddonMenu2:RegisterOptionControls(SF._addon.Name, allControls)
    end)
    
    if success then
    else
      d("[ScrollkeeperFramework] " ..SF.func._L("ScrollkeeperFramework", "ERROR_REGISTERING") .. tostring(error))
    end
  else
      d("[ScrollkeeperFramework] " .. SF.func._L("ScrollkeeperFramework", "LAM2_UNAVAILABLE"))
  end
  
  -- Expose modules for inter-module communication
  SF.notebook = ScrollkeeperNotebook
  -- SF.Data = ScrollkeeperData
  SF.roster = ScrollkeeperRoster
  SF.history = ScrollkeeperHistory
  
  SF._initialized = true
end

-- Chat menu button integration
local function setupChatMenuButtons()
  if not LibChatMenuButton then
    d("[ScrollkeeperFramework] " .. SF.func._L("ScrollkeeperFramework", "CHAT_BUTTONS_DISABLED"))
    return
  end
  
  -- Open all windows button
  local windowButton = LibChatMenuButton.addChatButton(
    "ScrollkeeperWindows",
    "Scrollkeeper/ScrollkeeperFramework/textures/roster_windows_up.dds",
    SF.func._L("ScrollkeeperFramework", "OPEN_ALL_WINDOWS"),
    function()
      -- Position offset from top-left
      local baseX, baseY = 50, 50
      local offsetX = 50
      
      -- Check if any windows are open
      local anyOpen = false
      local windows = {
        GetControl("ScrollkeeperNotebook_Window"),
        GetControl("ScrollkeeperHistory_Window"),
        GetControl("ScrollkeeperProvision_Window"),
        GetControl("ScrollkeeperMail_Window")
      }
      
      for _, win in ipairs(windows) do
        if win and not win:IsHidden() then
          anyOpen = true
          break
        end
      end
      
      if anyOpen then
        -- Close all windows
        for _, win in ipairs(windows) do
          if win then win:SetHidden(true) end
        end
      else
        -- Open all windows - call slash commands to create windows if needed
        if SLASH_COMMANDS["/sgtnote"] then
          SLASH_COMMANDS["/sgtnote"]()
          zo_callLater(function()
            local notebook = GetControl("ScrollkeeperNotebook_Window")
            if notebook then
              notebook:SetHidden(false)
              notebook:ClearAnchors()
              notebook:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, baseX, baseY)
            end
          end, 50)
        end
        
        if SLASH_COMMANDS["/sgthistory"] then
          SLASH_COMMANDS["/sgthistory"]()
          zo_callLater(function()
            local history = GetControl("ScrollkeeperHistory_Window")
            if history then
              history:SetHidden(false)
              history:ClearAnchors()
              history:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, baseX + offsetX, baseY + offsetX)
            end
          end, 50)
        end
        
        if SLASH_COMMANDS["/sgtprovision"] then
          SLASH_COMMANDS["/sgtprovision"]()
          zo_callLater(function()
            local provision = GetControl("ScrollkeeperProvision_Window")
            if provision then
              provision:SetHidden(false)
              provision:ClearAnchors()
              provision:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, baseX + offsetX * 2, baseY + offsetX * 2)
            end
          end, 50)
        end
        
        if SLASH_COMMANDS["/sgtmail"] then
          SLASH_COMMANDS["/sgtmail"]()
          zo_callLater(function()
            local mail = GetControl("ScrollkeeperMail_Window")
            if mail then
              mail:SetHidden(false)
              mail:ClearAnchors()
              mail:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, baseX + offsetX * 3, baseY + offsetX * 3)
            end
          end, 50)
        end
      end
    end
  )
  
  if windowButton then
    windowButton:show()
  end
  
  -- Settings button
  local settingsButton = LibChatMenuButton.addChatButton(
    "ScrollkeeperSettings",
    "Scrollkeeper/ScrollkeeperFramework/textures/housing_indexicon_library_up.dds",
    SF.func._L("ScrollkeeperFramework", "OPEN_SETTINGS"),
    function()
      if LibAddonMenu2 then
        LibAddonMenu2:OpenToPanel(SF.panel)
      end
    end
  )
  
  if settingsButton then
    settingsButton:show()
  end
end

-- Wait for LibChatMenuButton to be available
local CHAT_BUTTON_RETRY_LIMIT = 5
local chatButtonRetryCount = 0
local function trySetupChatButtons()
  if LibChatMenuButton then
    setupChatMenuButtons()
  elseif chatButtonRetryCount < CHAT_BUTTON_RETRY_LIMIT then
    chatButtonRetryCount = chatButtonRetryCount + 1
    -- Try again in 2 seconds
    zo_callLater(trySetupChatButtons, 2000)
  end
end

-- Kick off the framework's own initialization
SF.initAddon(SF._addon.Name, function()

  -- Critical: Delay to ensure all modules have registered their controls
  zo_callLater(function()
    -- Fire callback FIRST to let modules register
    CALLBACK_MANAGER:FireCallbacks("Scrollkeeper_Initialized")

    -- THEN build the panel after modules have registered
    zo_callLater(function()
      SF.initialized()
    end, 500) -- Give modules 500ms to register
  end, 8000)

  -- Start trying to add chat buttons after other addons load
  zo_callLater(trySetupChatButtons, 10000)
  
end)