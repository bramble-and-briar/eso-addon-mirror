-- Scrollkeeper Guild Tools Addon
-- ScrollkeeperRoster

local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

Scrollkeeper.Roster = Scrollkeeper.Roster or { Name = "ScrollkeeperRoster" }
local _addon = Scrollkeeper.Roster

_G.ScrollkeeperRoster = Scrollkeeper.Roster

-- Helper for trader flip countdown
local secondsUntilFlip = ScrollkeeperFramework_Settings.secondsUntilTraderFlip

-- Settings defaults
local DEFAULTS = {
  showTraderTimer = true,
  tasks = {}, -- Custom tasks: {name, frequency, lastCompleted, enabled, guild}
  guildSettings = {}, -- Per-guild preset task settings
}

-- Preset task definitions
local PRESET_TASK_KEYS = {
  PRESET_REVIEW_APPLICATIONS = {frequency = "1 day(s)"},
  PRESET_CHECK_BANK_DEPOSITS = {frequency = "1 week(s)"},
  PRESET_UPDATE_MOTD = {frequency = "1 week(s)"},
  PRESET_PROMOTE_PROBATIONARY = {frequency = "2 week(s)"},
  PRESET_REVIEW_INACTIVES = {frequency = "1 month(s)"},
}

-- Get localized preset tasks (called after localization is loaded)
local function getPresetTasks()
  local tasks = {}
  for key, data in pairs(PRESET_TASK_KEYS) do
    local localizedName = SF.func._L("ScrollkeeperRoster", key)
    if localizedName and localizedName ~= "" then
      tasks[localizedName] = data
    end
  end
  return tasks
end

-- Parse frequency string like "3 week(s)" into seconds
local function parseFrequencyToSeconds(frequencyStr)
  if not frequencyStr then return 604800 end -- Default 1 week
  
  local num, unit = string.match(frequencyStr, "^(%d+)%s+(.+)$")
  if not num or not unit then
    return 604800 -- Default fallback
  end
  
  num = tonumber(num)
  if not num then return 604800 end
  
  -- Convert unit to base seconds
  local baseSeconds
  if unit == "day(s)" then
    baseSeconds = 86400
  elseif unit == "week(s)" then
    baseSeconds = 604800
  elseif unit == "month(s)" then
    baseSeconds = 2592000
  else
    baseSeconds = 604800 -- Default to weeks
  end
  
  return num * baseSeconds
end

-- Get settings
local function getSettings()
  return SF.getModuleSettings(_addon.Name, DEFAULTS)
end

-- Get per-guild preset task settings
local function getGuildTaskSettings(guildName)
  if not guildName or guildName == "" then
    return {}
  end
  
  local settings = getSettings()
  if not settings.guildSettings then
    settings.guildSettings = {}
  end
  
  if not settings.guildSettings[guildName] then
    settings.guildSettings[guildName] = {
      showTasks = false
    }
    -- Initialize with preset task names
    for presetName, presetData in pairs(getPresetTasks()) do
      settings.guildSettings[guildName][presetName] = {
        enabled = false,
        frequency = presetData.frequency,
        lastCompleted = 0
      }
    end
  end
  
  -- Ensure showTasks exists for existing guilds
  if settings.guildSettings[guildName].showTasks == nil then
    settings.guildSettings[guildName].showTasks = false
  end
  
  return settings.guildSettings[guildName]
end

-- 🎨 Format time until next trader flip, colored by urgency
local function getTraderResetTimeColored()
  local secs = secondsUntilFlip()
  if secs <= 0 then 
    return "|cFF0000" .. SF.func._L("ScrollkeeperRoster", "TIMER_FLIPPING") .. "|r" 
  end
  local h = math.floor(secs / 3600)
  local m = math.floor((secs % 3600) / 60)
  local ts = string.format(SF.func._L("ScrollkeeperRoster", "TIMER_FORMAT"), h, m)
  
  -- COLOR PROGRESSION: Green -> Yellow -> Orange -> Red
  if h >= 24 then
    return "|c00FF00" .. ts .. "|r"  -- Green (24+ hours)
  elseif h >= 6 then
    return "|cFFFF00" .. ts .. "|r"  -- Yellow (6-24 hours)
  elseif h >= 2 then
    return "|cFF8800" .. ts .. "|r"  -- Orange (2-6 hours)
  else
    return "|cFF0000" .. ts .. "|r"  -- Red (< 2 hours)
  end
end

-- Check if a task is due
local function isTaskDue(task)
  if not task or not task.enabled then return false end
  local now = GetTimeStamp()
  local lastCompleted = task.lastCompleted or 0
  local frequency = parseFrequencyToSeconds(task.frequency)
  return (now - lastCompleted) >= frequency
end

-- Get time until task is due (in seconds)
local function getTimeUntilDue(task)
  if not task then return 0 end
  local now = GetTimeStamp()
  local lastCompleted = task.lastCompleted or 0
  local frequency = parseFrequencyToSeconds(task.frequency)
  return math.max(0, (lastCompleted + frequency) - now)
end

-- Format time remaining for a task (percentage-based color coding)
local function formatTimeRemaining(seconds, frequency)
  if seconds <= 0 then
    return "|cFF0000" .. SF.func._L("ScrollkeeperRoster", "TASK_STATUS_OVERDUE") .. "|r"
  end
  
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  
  -- Calculate percentage of time remaining
  local freqSeconds = parseFrequencyToSeconds(frequency)
  local percentRemaining = (seconds / freqSeconds) * 100
  
  -- Color based on percentage: Green > 25%, Yellow 10-25%, Orange 5-10%, Red < 5%
  local color
  if percentRemaining > 25 then
    color = "|c00FF00"  -- Green
  elseif percentRemaining > 10 then
    color = "|cFFFF00"  -- Yellow
  elseif percentRemaining > 5 then
    color = "|cFF8800"  -- Orange
  else
    color = "|cFF0000"  -- Red
  end
  
  if days > 0 then
    return string.format("%s%dd %dh|r", color, days, hours)
  elseif hours > 0 then
    return string.format("%s%dh|r", color, hours)
  else
    return string.format("%s%dm|r", color, math.floor(seconds / 60))
  end
end

-- Mark a task as completed
local function completeTask(taskData)
  if not taskData then return false end
  
  local task = taskData.task
  if not task then return false end
  
  local settings = getSettings()
  
  -- Handle preset tasks
  if task.isPreset then
    local guildTasks = getGuildTaskSettings(task.guild)
    if guildTasks and guildTasks[task.name] then
      guildTasks[task.name].lastCompleted = GetTimeStamp()
      d(string.format("|cFFD700[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "TASK_COMPLETED"), task.name))
      return true
    end
  -- Handle custom tasks
  elseif taskData.index and settings.tasks[taskData.index] then
    settings.tasks[taskData.index].lastCompleted = GetTimeStamp()
    d(string.format("|cFFD700[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "TASK_COMPLETED"), settings.tasks[taskData.index].name))
    return true
  end
  
  return false
end

-- Add a new custom task
local function addCustomTask(name, frequency, guild)
  local settings = getSettings()
  table.insert(settings.tasks, {
    name = name,
    frequency = frequency or "1 week(s)",
    lastCompleted = GetTimeStamp(),
    enabled = true,
    guild = guild or "",
    isCustom = true
  })
  local guildText = guild == "" and "All Guilds" or guild
  d(string.format("|cFFD700[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "TASK_ADDED"), name, guildText))
end

-- Remove a custom task
local function removeTask(taskIndex)
  local settings = getSettings()
  if settings.tasks[taskIndex] then
    local taskName = settings.tasks[taskIndex].name
    table.remove(settings.tasks, taskIndex)
    d(string.format("|cFFD700[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "TASK_REMOVED"), taskName))
    return true
  end
  return false
end

-- Get ALL tasks for current guild (presets + custom)
local function getTasksForCurrentGuild()
  local settings = getSettings()
  local currentGuildId = GUILD_ROSTER_MANAGER and GUILD_ROSTER_MANAGER:GetGuildId()
  
  if not currentGuildId then 
    return {} 
  end
  
  local currentGuildName = GetGuildName(currentGuildId)
  local tasks = {}
  
  -- Add preset tasks ONLY for this specific guild
  local guildTasks = getGuildTaskSettings(currentGuildName)
  for presetName, presetData in pairs(guildTasks) do
    if type(presetData) == "table" and presetData.enabled and presetData.frequency then
      table.insert(tasks, {
        index = nil,
        task = {
          name = presetName,
          frequency = presetData.frequency,
          lastCompleted = presetData.lastCompleted,
          enabled = true,
          guild = currentGuildName,
          isCustom = false,
          isPreset = true
        }
      })
    end
  end
  
  for i, task in ipairs(settings.tasks) do
    if task and task.enabled and task.isCustom then
      local taskGuild = task.guild or ""
      if taskGuild == "" or taskGuild == currentGuildName then
        table.insert(tasks, {index = i, task = task})
      end
    end
  end
  
  return tasks
end

-- Forward declaration
local updateTaskPanel
local createTraderTimer

-- Counter for unique control names
local taskWindowCounter = 0

-- Create task removal window
local function createTaskRemovalWindow()
  local settings = getSettings()
  local windowName = "ScrollkeeperRoster_RemovalWindow"
  
  -- Check if window exists and just show it, or create new one
  local existingWindow = GetControl(windowName)
  if existingWindow then
    -- Window exists, need to rebuild task list - just hide and recreate below
    -- We can't reuse because task list has changed
    -- Increment window name to avoid duplicate
    local counter = 1
    while GetControl(windowName .. "_" .. counter) do
      counter = counter + 1
    end
    windowName = windowName .. "_" .. counter
  end
  
  -- Create window
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(500, 450)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(false)
  
  -- Background
  local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0.1, 0.1, 0.1, 0.95)
  bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  bg:SetEdgeTexture("", 2, 2, 1)
  
  -- Title bar
  local titleBar = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  titleBar:SetDimensions(500, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperRoster", "REMOVE_CUSTOM_TASK"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeTitleBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeTitleBtn:SetDimensions(25, 25)
  closeTitleBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeTitleBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeTitleBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  -- Warning text
  local warning = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  warning:SetFont("ZoFontGameBold")
  warning:SetText(SF.func._L("ScrollkeeperRoster", "REMOVE_WARNING"))
  warning:SetColor(1, 0.3, 0.3, 1)
  warning:SetAnchor(TOP, window, TOP, 0, 50)
  warning:SetDimensions(460, 60)
  warning:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  warning:SetVerticalAlignment(TEXT_ALIGN_TOP)
  
  -- Instruction text
  local instruction = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  instruction:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  instruction:SetText(SF.func._L("ScrollkeeperRoster", "REMOVE_INSTRUCTION"))
  instruction:SetAnchor(TOP, warning, BOTTOM, 0, 20)
  instruction:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Task list scroll area
  local scrollBg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  scrollBg:SetDimensions(460, 220)
  scrollBg:SetAnchor(TOP, instruction, BOTTOM, 0, 15)
  scrollBg:SetCenterColor(0.05, 0.05, 0.05, 0.9)
  scrollBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
  scrollBg:SetEdgeTexture("", 2, 1, 0)
  
  -- Create buttons for each custom task
  local yOffset = 10
  for i, task in ipairs(settings.tasks) do
    if task.isCustom then
      local taskIndex = i
      local guildText = task.guild == "" and "All Guilds" or task.guild
      local displayName = string.format("%s (%s) - %s", task.name, task.frequency, guildText)
      
      -- Button background
      local btnBg = WINDOW_MANAGER:CreateControl(nil, scrollBg, CT_BACKDROP)
      btnBg:SetDimensions(440, 32)
      btnBg:SetAnchor(TOP, scrollBg, TOP, 0, yOffset)
      btnBg:SetCenterColor(0.15, 0.15, 0.15, 1)
      btnBg:SetEdgeColor(0.4, 0.4, 0.4, 1)
      btnBg:SetEdgeTexture("", 1, 1, 0)
      
      local btn = WINDOW_MANAGER:CreateControl(nil, btnBg, CT_BUTTON)
      btn:SetAnchorFill()
      btn:SetNormalFontColor(1, 1, 1, 1)
      btn:SetMouseOverFontColor(1, 0.3, 0.3, 1)
      btn:SetFont("ZoFontGame")
      btn:SetText(displayName)
      btn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      
      btn:SetHandler("OnClicked", function()
        removeTask(taskIndex)
        window:SetHidden(true)
        
        -- Refresh settings panel and task panel
        if SF_Set and SF_Set.RefreshSettings then
          zo_callLater(function()
            SF_Set.RefreshSettings()
          end, 100)
        end
      end)
      
      yOffset = yOffset + 37
    end
  end
  
  local cancelBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  cancelBtn:SetDimensions(35, 35)
  cancelBtn:SetAnchor(BOTTOM, window, BOTTOM, 0, -30)
  cancelBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_up.dds")
  cancelBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_down.dds")
  cancelBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_over.dds")
  
  local cancelLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  cancelLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  cancelLabel:SetText(SF.func._L("ScrollkeeperRoster", "REMOVE_WINDOW_CANCEL"))
  cancelLabel:SetAnchor(TOP, cancelBtn, BOTTOM, 0, 2)
  cancelLabel:SetColor(1, 1, 1, 1)
  
  cancelBtn:SetHandler("OnClicked", function()
    window:SetHidden(true)
  end)
  
  -- Apply theme
  window.updateTheme = function()
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(titleBar, title)
    end
  end
  
  if SF.registerThemedWindow then
    SF.registerThemedWindow(windowName, window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)

  window.titleBar = titleBar
  window.titleText = title
  SF.addOrnateFrame(window)
  return window
end

-- Create task management window
local function createTaskManagementWindow()
  taskWindowCounter = taskWindowCounter + 1
  local windowName = "ScrollkeeperRoster_TaskWindow_" .. taskWindowCounter
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(500, 350)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(false)
  
  -- Background
  local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0.1, 0.1, 0.1, 0.95)
  bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  bg:SetEdgeTexture("", 2, 2, 1)
  
  -- Title bar
  local titleBar = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  titleBar:SetDimensions(500, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  -- Task Name
  local nameLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  nameLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  nameLabel:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_NAME_LABEL"))
  nameLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 50)
  nameLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local nameBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_NameBg", window, "ZO_EditBackdrop")
  nameBg:SetDimensions(460, 30)
  nameBg:SetAnchor(TOPLEFT, nameLabel, BOTTOMLEFT, 0, 5)
  
  local nameInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_NameInput", nameBg, "ZO_DefaultEditForBackdrop")
  nameInput:SetMaxInputChars(100)
  
  -- Frequency (Number + Unit)
  local freqLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  freqLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  freqLabel:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_FREQ_LABEL"))
  freqLabel:SetAnchor(TOPLEFT, nameBg, BOTTOMLEFT, 0, 15)
  freqLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Number input
  local freqNumBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_FreqNumBg", window, "ZO_EditBackdrop")
  freqNumBg:SetDimensions(100, 30)
  freqNumBg:SetAnchor(TOPLEFT, freqLabel, BOTTOMLEFT, 0, 5)
  
  local freqNumInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_FreqNumInput", freqNumBg, "ZO_DefaultEditForBackdrop")
  freqNumInput:SetMaxInputChars(3)
  freqNumInput:SetText("1")
  
  -- Unit dropdown
  local freqUnitBg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  freqUnitBg:SetDimensions(150, 30)
  freqUnitBg:SetAnchor(LEFT, freqNumBg, RIGHT, 10, 0)
  freqUnitBg:SetCenterColor(0.1, 0.1, 0.1, 1)
  freqUnitBg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  freqUnitBg:SetEdgeTexture("", 1, 1, 0)
  
  local freqUnitDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_FreqUnitDropdown", freqUnitBg, "ZO_ComboBox")
  freqUnitDropdown:SetAnchorFill()
  
  local freqUnitCombo = ZO_ComboBox_ObjectFromContainer(freqUnitDropdown)
  freqUnitCombo:SetSortsItems(false)
  
  local units = {"day(s)", "week(s)", "month(s)"}
  for _, unit in ipairs(units) do
    local entry = freqUnitCombo:CreateItemEntry(unit, function() end)
    freqUnitCombo:AddItem(entry)
  end
  freqUnitCombo:SetSelectedItem("week(s)")
  
  -- Guild selection
  local guildLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  guildLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  guildLabel:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_GUILD_LABEL"))
  guildLabel:SetAnchor(TOPLEFT, freqNumBg, BOTTOMLEFT, 0, 15)
  guildLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local guildBg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  guildBg:SetDimensions(460, 30)
  guildBg:SetAnchor(TOPLEFT, guildLabel, BOTTOMLEFT, 0, 5)
  guildBg:SetCenterColor(0.1, 0.1, 0.1, 1)
  guildBg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  guildBg:SetEdgeTexture("", 1, 1, 0)
  
  local guildDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_GuildDropdown", guildBg, "ZO_ComboBox")
  guildDropdown:SetAnchorFill()
  
  local guildCombo = ZO_ComboBox_ObjectFromContainer(guildDropdown)
  guildCombo:SetSortsItems(false)
  
  window.selectedGuilds = {}
  
  -- Add "All Guilds" option
  local allEntry = guildCombo:CreateItemEntry("All Guilds", function()
    window.selectedGuilds = {}
    guildCombo:SetSelectedItem("All Guilds")
  end)
  guildCombo:AddItem(allEntry)
  
  -- Add each guild
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    if guildName then
      local entry = guildCombo:CreateItemEntry(guildName, (function(fullGuildName)
        return function()
          if window.selectedGuilds[fullGuildName] then
            window.selectedGuilds[fullGuildName] = nil
          else
            window.selectedGuilds[fullGuildName] = true
          end
          
          local count = 0
          for _ in pairs(window.selectedGuilds) do count = count + 1 end
          if count == 0 then
            guildCombo:SetSelectedItem("All Guilds")
          else
            guildCombo:SetSelectedItem(string.format("%d selected", count))
          end
        end
      end)(guildName))
      guildCombo:AddItem(entry)
    end
  end
  
  guildCombo:SelectFirstItem()
  
  -- Buttons
  local addBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  addBtn:SetDimensions(35, 35)
  addBtn:SetAnchor(BOTTOM, window, BOTTOM, -100, -30)
  addBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_up.dds")
  addBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_down.dds")
  addBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_over.dds")
  
  local addLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  addLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  addLabel:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_ADD"))
  addLabel:SetAnchor(TOP, addBtn, BOTTOM, 0, 2)
  addLabel:SetColor(1, 1, 1, 1)
  
  addBtn:SetHandler("OnClicked", function()
    local taskName = nameInput:GetText()
    if not taskName or taskName == "" then
      d("|cFF5555[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "ERROR_NO_TASK_NAME"))
      return
    end
    
    local freqNum = tonumber(freqNumInput:GetText())
    if not freqNum or freqNum <= 0 then
      d("|cFF5555[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "ERROR_INVALID_FREQ_NUMBER"))
      return
    end
    
    local freqUnit = freqUnitCombo:GetSelectedItem()
    if not freqUnit or freqUnit == "" then
      d("|cFF5555[ScrollkeeperRoster]|r " .. SF.func._L("ScrollkeeperRoster", "ERROR_NO_FREQ_UNIT"))
      return
    end
    
    -- Convert to frequency string: "3 week(s)" format
    local frequency = string.format("%d %s", freqNum, freqUnit)
    
    -- Get selected guilds
    local guilds = {}
    for guildName, _ in pairs(window.selectedGuilds) do
      table.insert(guilds, guildName)
    end
    
    -- Add task for each guild (or once if no guilds specified)
    if #guilds == 0 then
      addCustomTask(taskName, frequency, "")
    else
      for _, guild in ipairs(guilds) do
        addCustomTask(taskName, frequency, guild)
      end
    end
    
    -- Clear form
    nameInput:SetText("")
    freqNumInput:SetText("1")
    window.selectedGuilds = {}
    guildCombo:SelectFirstItem()
    freqUnitCombo:SetSelectedItem("week(s)")
    
    window:SetHidden(true)
    
    -- Refresh task panel AND settings panel
    zo_callLater(function()
      if updateTaskPanel then 
        updateTaskPanel() 
      end
      if SF_Set and SF_Set.RefreshSettings then
        SF_Set.RefreshSettings()
      end
    end, 200)
  end)
  
  local cancelBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  cancelBtn:SetDimensions(35, 35)
  cancelBtn:SetAnchor(BOTTOM, window, BOTTOM, 100, -30)
  cancelBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_up.dds")
  cancelBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_down.dds")
  cancelBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_over.dds")
  
  local cancelLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  cancelLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  cancelLabel:SetText(SF.func._L("ScrollkeeperRoster", "TASK_WINDOW_CANCEL"))
  cancelLabel:SetAnchor(TOP, cancelBtn, BOTTOM, 0, 2)
  cancelLabel:SetColor(1, 1, 1, 1)
  
  cancelBtn:SetHandler("OnClicked", function()
    window:SetHidden(true)
  end)
  
  -- Apply theme
  window.updateTheme = function()
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(titleBar, title)
    end
  end
  
  if SF.registerThemedWindow then
    SF.registerThemedWindow(windowName, window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)
  
  window.titleBar = titleBar
  window.titleText = title
  SF.addOrnateFrame(window)
  return window
end

-- Create task panel (wrapping row along bottom)
local function createTaskPanel()
  local guildFrame = ZO_GuildRoster
  if not guildFrame then return end
  
  local settings = getSettings()

  -- Check if current guild has tasks enabled
  local currentGuildId = GUILD_ROSTER_MANAGER and GUILD_ROSTER_MANAGER:GetGuildId()
  if not currentGuildId then
    if guildFrame.scrollkeeperTaskPanel then
      guildFrame.scrollkeeperTaskPanel:SetHidden(true)
    end
    return
  end
  
  local currentGuildName = GetGuildName(currentGuildId)
  local guildSettings = getGuildTaskSettings(currentGuildName)
  
  -- Hide if THIS SPECIFIC GUILD has tasks disabled
  if not guildSettings.showTasks then
    if guildFrame.scrollkeeperTaskPanel then
      guildFrame.scrollkeeperTaskPanel:SetHidden(true)
    end
    return
  end
  
  -- Create panel if it doesn't exist
  if not guildFrame.scrollkeeperTaskPanel then
    local panel = WINDOW_MANAGER:CreateControl("ScrollkeeperTaskPanel", guildFrame, CT_CONTROL)
    panel:SetDimensions(1200, 60)
    panel:SetAnchor(BOTTOMLEFT, guildFrame, BOTTOMLEFT, 15, -10)
    
    panel.taskLabels = {}
    guildFrame.scrollkeeperTaskPanel = panel
    
    -- Update tasks every 5 minutes
    EVENT_MANAGER:RegisterForUpdate("ScrollkeeperTaskPanel", 300000, function()
      if not panel:IsHidden() then
        updateTaskPanel()
      end
    end)
  end
  
  guildFrame.scrollkeeperTaskPanel:SetHidden(false)
  updateTaskPanel()
end

local function setupGuildRosterHook()
  -- Hook the roster manager's SetGuildId to detect guild changes
  if GUILD_ROSTER_MANAGER then
    ZO_PreHook(GUILD_ROSTER_MANAGER, "SetGuildId", function(self, guildId)
      -- Refresh both timer and task panel when guild changes
      zo_callLater(function()
        if createTraderTimer then createTraderTimer() end
        if updateTaskPanel then createTaskPanel() end
      end, 100)
    end)
  end
  
  -- Also hook the scene showing to ensure everything updates on initial roster view
  if GUILD_ROSTER_SCENE then
    GUILD_ROSTER_SCENE:RegisterCallback("StateChange", function(oldState, newState)
      if newState == SCENE_SHOWING then
        zo_callLater(function()
          if createTraderTimer then createTraderTimer() end
          if updateTaskPanel then createTaskPanel() end
        end, 200)
      end
    end)
  end
end

-- Update task panel (wrapping row display with right-click to remove)
updateTaskPanel = function()
  local guildFrame = ZO_GuildRoster
  if not guildFrame or not guildFrame.scrollkeeperTaskPanel then
    return
  end
  
  local panel = guildFrame.scrollkeeperTaskPanel
  
  -- Clear existing labels
  for _, label in ipairs(panel.taskLabels) do
    label:SetHidden(true)
  end
  
  local tasks = getTasksForCurrentGuild()
  
  if not tasks or #tasks == 0 then 
    return 
  end
  
  -- Sort: urgency
  table.sort(tasks, function(a, b)
    if not a or not a.task then return false end
    if not b or not b.task then return true end
    local aDue = isTaskDue(a.task)
    local bDue = isTaskDue(b.task)
    if aDue ~= bDue then return aDue end
    return getTimeUntilDue(a.task) < getTimeUntilDue(b.task)
  end)
  
  local xOffset = 0
  local yOffset = 5
  local labelIndex = 1
  local maxWidth = 1180
  
  for _, taskData in ipairs(tasks) do
    if taskData and taskData.task and taskData.task.enabled then
      local task = taskData.task
	  
      local label = panel.taskLabels[labelIndex]
      if not label then
        label = WINDOW_MANAGER:CreateControl(nil, panel, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetMouseEnabled(true)
        
        -- Left-click to complete, right-click to remove
        label:SetHandler("OnMouseUp", function(self, button)
          if button == MOUSE_BUTTON_INDEX_LEFT then
            completeTask(self.taskData)
            updateTaskPanel()
          elseif button == MOUSE_BUTTON_INDEX_RIGHT then
            -- Right-click to remove custom tasks only
            if self.isCustom and self.taskIndex then
              removeTask(self.taskIndex)
              updateTaskPanel()
            else
              d("|cFF8800[Roster]|r " .. SF.func._L("ScrollkeeperRoster", "ERROR_PRESET_REMOVE"))
            end
          end
        end)
        
        -- Tooltip
        label:SetHandler("OnMouseEnter", function(self)
          InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
          local tooltipText = SF.func._L("ScrollkeeperRoster", "TASK_TOOLTIP_LEFT")
		  tooltipText = tooltipText .. "\n\n" .. SF.func._L("ScrollkeeperRoster", "TASK_COLOR_LEGEND")
          if self.isCustom then
            tooltipText = tooltipText .. "\n" .. SF.func._L("ScrollkeeperRoster", "TASK_TOOLTIP_RIGHT")
          end
          SetTooltipText(InformationTooltip, tooltipText)
        end)
        label:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
		
        table.insert(panel.taskLabels, label)
      end
      
      label.taskIndex = taskData.index
      label.isCustom = task.isCustom
      label.taskData = taskData -- Store entire taskData for completion
      
      local timeRemaining = getTimeUntilDue(task)
      local taskText = string.format("%s: %s", task.name, formatTimeRemaining(timeRemaining, task.frequency))
      label:SetText(taskText)
      
      local labelWidth = label:GetTextWidth()
      
      -- Check if we need to wrap to next line
      if xOffset + labelWidth > maxWidth and xOffset > 0 then
        xOffset = 0
        yOffset = yOffset + 25
      end
      
      label:SetAnchor(LEFT, panel, LEFT, xOffset, yOffset)
      label:SetHidden(false)
      
      xOffset = xOffset + labelWidth + 40
      labelIndex = labelIndex + 1
    end
  end
end

-- Create trader timer display on guild roster
local function createTraderTimer()
  local guildFrame = ZO_GuildRoster
  if not guildFrame then return end
  
  local settings = getSettings()
  if not settings.showTraderTimer then
    -- Hide timer if it exists and setting is disabled
    if guildFrame.scrollkeeperTimer then
      guildFrame.scrollkeeperTimer:SetHidden(true)
    end
    return
  end
  
  -- Create timer label if it doesn't exist
  if not guildFrame.scrollkeeperTimer then
    local timer = WINDOW_MANAGER:CreateControl("ScrollkeeperTraderTimer", guildFrame, CT_LABEL)
    timer:SetFont("ZoFontWinH4")
    timer:SetAnchor(TOPRIGHT, guildFrame, TOPRIGHT, -15, 3)
    timer:SetMouseEnabled(true)
    timer:SetHandler("OnMouseEnter", function(self)
      InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
      SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperRoster", "TOOLTIP_FULL"))
    end)
    timer:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    guildFrame.scrollkeeperTimer = timer

    local lastSecondsUntilFlip = nil

    -- Update every 10 seconds for responsiveness
    EVENT_MANAGER:RegisterForUpdate("ScrollkeeperTraderTimer", 10000, function()
      local currentSettings = getSettings()
      if not (timer and not timer:IsHidden() and currentSettings.showTraderTimer) then return end

      local secs = secondsUntilFlip()

      -- Detect the flip transition: if we just crossed zero, force an extra
      -- immediate refresh so the timer never gets stuck on a stale countdown
      if lastSecondsUntilFlip and lastSecondsUntilFlip <= 60 and secs > 3000 then
        -- Flip just happened — update right now
        timer:SetText(string.format(SF.func._L("ScrollkeeperRoster", "TIMER_LABEL"), getTraderResetTimeColored()))
      end

      lastSecondsUntilFlip = secs
      timer:SetText(string.format(SF.func._L("ScrollkeeperRoster", "TIMER_LABEL"), getTraderResetTimeColored()))
    end)
  end
  
  -- Always show and update timer (not just on creation)
  guildFrame.scrollkeeperTimer:SetHidden(false)
  guildFrame.scrollkeeperTimer:SetText(string.format(SF.func._L("ScrollkeeperRoster", "TIMER_LABEL"), getTraderResetTimeColored()))
end

-- Build controls
local function buildControls()
  local settings = getSettings()

  local controls = {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperRoster", "SUBMENU_NAME"),
      controls = {
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperRoster", "SETTING_TRADER_TIMER"),
          tooltip = SF.func._L("ScrollkeeperRoster", "SETTING_TRADER_TIMER_TIP"),
          getFunc = function() return settings.showTraderTimer end,
          setFunc = function(v)
            settings.showTraderTimer = v
            createTraderTimer()
          end,
          default = DEFAULTS.showTraderTimer,
          width = "full",
        },
        {
          type = "header",
          name = SF.func._L("ScrollkeeperRoster", "TASKS_HEADER"),
        },
        {
          type = "description",
          text = SF.func._L("ScrollkeeperRoster", "TASKS_DESCRIPTION")
        },
      }
    }
  }

  -- Add preset tasks per guild
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    
    if guildName then
      local guildSubmenu = {
        type = "submenu",
        name = guildName,
        controls = {
          {
            type = "description",
            text = string.format(SF.func._L("ScrollkeeperRoster", "GUILD_CONFIG_DESC"), guildName)
          },
          -- Per-guild enable toggle
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperRoster", "GUILD_TASKS_ENABLE"),
            tooltip = SF.func._L("ScrollkeeperRoster", "GUILD_TASKS_ENABLE_TIP"),
            getFunc = (function(gName)
              return function()
                local gt = getGuildTaskSettings(gName)
                return gt.showTasks or false
              end
            end)(guildName),
            setFunc = (function(gName)
              return function(v)
                local gt = getGuildTaskSettings(gName)
                gt.showTasks = v
                zo_callLater(createTaskPanel, 100)
              end
            end)(guildName),
            width = "full",
            default = false,
          },
          {
            type = "header",
            name = SF.func._L("ScrollkeeperRoster", "PRESET_TASKS_HEADER")
          }
        }
      }
      
      -- Initialize guild settings
      local guildTasks = getGuildTaskSettings(guildName)
      
      -- Add each preset task for this guild
      for presetName, presetData in pairs(getPresetTasks()) do
        
        -- Ensure preset exists in guild settings
        if not guildTasks[presetName] then
          guildTasks[presetName] = {
            enabled = false,
            frequency = presetData.frequency,
            lastCompleted = 0
          }
        end
        
        -- Checkbox to enable/disable
        table.insert(guildSubmenu.controls, {
          type = "checkbox",
          name = presetName,
          getFunc = (function(gName, pName)
            return function()
              local gt = getGuildTaskSettings(gName)
              return gt[pName] and gt[pName].enabled or false
            end
          end)(guildName, presetName),
          setFunc = (function(gName, pName)
            return function(v)
              local gt = getGuildTaskSettings(gName)
              if gt[pName] then
                gt[pName].enabled = v
                -- START THE TIMER when enabling a task for the first time
                if v and gt[pName].lastCompleted == 0 then
                  gt[pName].lastCompleted = GetTimeStamp()
                end
                zo_callLater(createTaskPanel, 100)
              end
            end
          end)(guildName, presetName),
          disabled = (function(gName)
            return function()
              local gt = getGuildTaskSettings(gName)
              return not gt.showTasks
            end
          end)(guildName),
          width = "full",
        })
        
        -- Frequency - Number input
        table.insert(guildSubmenu.controls, {
          type = "editbox",
          name = SF.func._L("ScrollkeeperRoster", "FREQUENCY_NUMBER"),
          tooltip = SF.func._L("ScrollkeeperRoster", "FREQUENCY_NUMBER_TIP"),
          getFunc = (function(gName, pName)
            return function()
              local gt = getGuildTaskSettings(gName)
              if gt[pName] and gt[pName].frequency then
                local num = string.match(gt[pName].frequency, "^(%d+)")
                return num or "1"
              end
              return "1"
            end
          end)(guildName, presetName),
          setFunc = (function(gName, pName)
            return function(v)
              local gt = getGuildTaskSettings(gName)
              if gt[pName] then
                local num = tonumber(v) or 1
                local _, unit = string.match(gt[pName].frequency, "^(%d+)%s+(.+)$")
                unit = unit or "week(s)"
                gt[pName].frequency = string.format("%d %s", num, unit)
                zo_callLater(createTaskPanel, 100)
              end
            end
          end)(guildName, presetName),
          disabled = (function(gName, pName)
            return function()
              local gt = getGuildTaskSettings(gName)
              return not gt.showTasks or not (gt[pName] and gt[pName].enabled)
            end
          end)(guildName, presetName),
          width = "half",
          isMultiline = false,
        })
        
        -- Frequency - Unit dropdown
        table.insert(guildSubmenu.controls, {
          type = "dropdown",
          name = SF.func._L("ScrollkeeperRoster", "FREQUENCY_UNIT"),
          choices = {"day(s)", "week(s)", "month(s)"},
          getFunc = (function(gName, pName)
            return function()
              local gt = getGuildTaskSettings(gName)
              if gt[pName] and gt[pName].frequency then
                local _, unit = string.match(gt[pName].frequency, "^(%d+)%s+(.+)$")
                return unit or "week(s)"
              end
              return "week(s)"
            end
          end)(guildName, presetName),
          setFunc = (function(gName, pName)
            return function(v)
              local gt = getGuildTaskSettings(gName)
              if gt[pName] then
                local num = string.match(gt[pName].frequency, "^(%d+)")
                num = tonumber(num) or 1
                gt[pName].frequency = string.format("%d %s", num, v)
                zo_callLater(createTaskPanel, 100)
              end
            end
          end)(guildName, presetName),
          disabled = (function(gName, pName)
            return function()
              local gt = getGuildTaskSettings(gName)
              return not gt.showTasks or not (gt[pName] and gt[pName].enabled)
            end
          end)(guildName, presetName),
          width = "half",
        })
      end
      
      table.insert(controls[1].controls, guildSubmenu)
    end
  end
  
  -- Custom tasks
  table.insert(controls[1].controls, {
    type = "header",
    name = SF.func._L("ScrollkeeperRoster", "CUSTOM_TASKS"),
  })
  
  table.insert(controls[1].controls, {
    type = "description",
    text = SF.func._L("ScrollkeeperRoster", "CUSTOM_TASKS_DESC")
  })
  
  table.insert(controls[1].controls, {
    type = "button",
    name = SF.func._L("ScrollkeeperRoster", "ADD_CUSTOM_TASK"),
    func = function()
      createTaskManagementWindow()
    end,
    width = "half",
  })
  
  -- Only show Remove button if there are custom tasks
  local hasCustomTasks = false
  for _, task in ipairs(settings.tasks) do
    if task.isCustom then
      hasCustomTasks = true
      break
    end
  end
  
  if hasCustomTasks then
    table.insert(controls[1].controls, {
      type = "button",
      name = SF.func._L("ScrollkeeperRoster", "REMOVE_CUSTOM_TASK"),
      tooltip = SF.func._L("ScrollkeeperRoster", "REMOVE_CUSTOM_TASK_TIP"),
      func = function()
        createTaskRemovalWindow()
      end,
      width = "half",
      warning = SF.func._L("ScrollkeeperRoster", "REMOVE_WARNING"),
    })
  end
  
  -- List existing custom tasks (display only, no inline remove buttons)
  for i, task in ipairs(settings.tasks) do
    if task.isCustom then
      local taskIndex = i
      local guildText = task.guild == "" and "All Guilds" or task.guild
      local displayName = string.format("%s (%s) - %s", task.name, task.frequency, guildText)
      
      table.insert(controls[1].controls, {
        type = "checkbox",
        name = displayName,
        getFunc = (function(idx)
          return function()
            local currentSettings = getSettings()
            return currentSettings.tasks[idx] and currentSettings.tasks[idx].enabled or false
          end
        end)(taskIndex),
        setFunc = (function(idx)
          return function(v)
            local currentSettings = getSettings()
            if currentSettings.tasks[idx] then
              currentSettings.tasks[idx].enabled = v
              createTaskPanel()
            end
          end
        end)(taskIndex),
        width = "full",
      })
    end
  end
  
  return controls
end

-- 🔗 Initialize
local function initialize()
  local settings = getSettings()
  
  -- Register controls IMMEDIATELY
  if SF_Set and SF_Set.RegisterModuleOptions then
    local controls = buildControls()
    if controls and #controls > 0 then
      SF_Set.RegisterModuleOptions(_addon.Name, controls)
    end
  end

  -- Create UI elements with delay
  zo_callLater(function()
    -- Create trader timer first
    if settings.showTraderTimer then
      createTraderTimer()
    end
    
    -- Initial task panel creation
    createTaskPanel()
    
    -- Set up guild roster hook LAST (after both functions exist)
    setupGuildRosterHook()
  end, 1000)
end

-- Register for proper initialization
EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  -- Now initialize UI elements
  initialize()
end)

CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)