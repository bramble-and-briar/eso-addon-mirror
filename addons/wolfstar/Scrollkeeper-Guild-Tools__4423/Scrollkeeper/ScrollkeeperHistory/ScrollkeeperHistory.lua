-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

if type(SF) ~= "table" then
  d("[ScrollkeeperHistory] ERROR: Framework missing")
  return
end

-- Initialize module
Scrollkeeper.History = Scrollkeeper.History or { Name = "ScrollkeeperHistory" }
local _addon = Scrollkeeper.History

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperHistory = Scrollkeeper.History

-- Prevent multiple initialization
if _addon._initialized then return end

local libScroll = nil

local LibTextFilter = LibTextFilter

local defaults = {
  maxEvents = 5000,
  searchDelay = 300,
  enableColorCoding = true,
  guildSettings = {}, -- guildName -> { enabled, categories }
}

-- Get guilds in display order (respects Guild Reorder if available)
local function getGuildsInOrder()
  local guilds = {}
  
  -- Check if Dolgubon's Guild Reorder is active
  if DolgubonsGuildReorder and type(DolgubonsGuildReorder.keyOrder) == "table" then
    -- keyOrder maps: visual position -> original guild index
    for visualPos = 1, GetNumGuilds() do
      local originalIdx = DolgubonsGuildReorder.keyOrder[visualPos]
      if originalIdx then
        local guildId = GetGuildId(originalIdx)
        local guildName = GetGuildName(guildId)
        if guildName then
          table.insert(guilds, guildName)
        end
      end
    end
  else
    -- Use native client order
    for i = 1, GetNumGuilds() do
      local guildName = GetGuildName(GetGuildId(i))
      if guildName then
        table.insert(guilds, guildName)
      end
    end
  end
  
  return guilds
end

-- Get settings with fallback
local function getSettings()
  -- Try framework method first
  if SF and SF.getModuleSettings and type(SF.getModuleSettings) == "function" then
    local settings = SF.getModuleSettings(_addon.Name, defaults)
    if settings then
      return settings
    end
  end
  
  -- Fallback to direct SavedVariables access
  if not ScrollkeeperHistory_Settings then
    ScrollkeeperHistory_Settings = ZO_DeepTableCopy(defaults)
  end
  
  return ScrollkeeperHistory_Settings
end

-- Get per-guild settings
local function getGuildSettings(guildName)
  if not guildName or type(guildName) ~= "string" or guildName == "" then
    return {
      enabled = false,
      categories = {
        roster = false,
        bankedGold = false,
        bankedItems = false,
        sales = false,
      }
    }
  end
  
  local settings = getSettings()
  if not settings or not settings.guildSettings then
    if settings then
      settings.guildSettings = {}
    else
      return { 
        enabled = false, 
        categories = { roster = false, bankedGold = false, bankedItems = false, sales = false }
      }
    end
  end
  
  if not settings.guildSettings[guildName] then
    settings.guildSettings[guildName] = {
      enabled = true,
      categories = {
        roster = true,
        bankedGold = true,
        bankedItems = true,
        sales = true,
      }
    }
  end
  
  return settings.guildSettings[guildName]
end

-- 🎨 Color mappings for event types
local EVENT_COLORS = {
  roster = {
    [0] = "|c88ccff",  -- Invited (blue)
    [2] = "|c89df88",  -- Joined (green)
    [3] = "|cffe599",  -- Promoted (yellow)
    [4] = "|cffe599",  -- Demoted (yellow)
    [5] = "|cff5656",  -- Left (red)
    [6] = "|cff8888",  -- Kicked (red)
    [10] = "|c88ccff", -- Application Accepted (blue)
  },
  bankedGold = {
    [0] = "|cFFD700",  -- Deposited (gold)
    [1] = "|cF97D48",  -- Withdrawn (orange)
    [2] = "|cC196E4",  -- Kiosk Bid (purple)
    [3] = "|c33FF66",  -- Bid Returned (green)
  },
  bankedItems = {
    [GUILD_HISTORY_BANKED_ITEM_EVENT_ADDED] = "|c6ABED7",
    [GUILD_HISTORY_BANKED_ITEM_EVENT_REMOVED] = "|cdf829e",
  },
  sales = {
    [GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD] = "|c33FF66",
  },
}

local function getEventColor(category, eventType)
  if EVENT_COLORS[category] and EVENT_COLORS[category][eventType] then
    return EVENT_COLORS[category][eventType]
  end
  return "|cFFFFFF"
end

-- Event type names
local function getEventTypeName(category, eventType)
  local names = {
    roster = {
      [0] = SF.func._L("ScrollkeeperHistory", "EVENT_INVITED"),
      [2] = SF.func._L("ScrollkeeperHistory", "EVENT_JOINED"),
      [3] = SF.func._L("ScrollkeeperHistory", "EVENT_PROMOTED"),
      [4] = SF.func._L("ScrollkeeperHistory", "EVENT_DEMOTED"),
      [5] = SF.func._L("ScrollkeeperHistory", "EVENT_LEFT"),
      [6] = SF.func._L("ScrollkeeperHistory", "EVENT_KICKED"),
      [10] = SF.func._L("ScrollkeeperHistory", "EVENT_APP_ACCEPTED"),
    },
    bankedGold = {
      [0] = SF.func._L("ScrollkeeperHistory", "EVENT_GOLD_DEPOSITED"),
      [1] = SF.func._L("ScrollkeeperHistory", "EVENT_GOLD_WITHDRAWN"),
      [2] = SF.func._L("ScrollkeeperHistory", "EVENT_TRADER_BID"),
      [3] = SF.func._L("ScrollkeeperHistory", "EVENT_BID_RETURNED"),
    },
    bankedItems = {
      [0] = SF.func._L("ScrollkeeperHistory", "EVENT_ITEM_DEPOSITED"),
      [1] = SF.func._L("ScrollkeeperHistory", "EVENT_ITEM_WITHDRAWN"),
    },
    sales = {
      [0] = SF.func._L("ScrollkeeperHistory", "EVENT_ITEM_SOLD"),
    },
  }
  
  if names[category] and names[category][eventType] then
    return names[category][eventType]
  end
  return string.format(SF.func._L("ScrollkeeperHistory", "EVENT_UNKNOWN"), tostring(eventType))
end

-- Get category name
local function getCategoryDisplayName(category)
  local names = {
    roster = SF.func._L("ScrollkeeperHistory", "CAT_ROSTER"),
    bankedGold = SF.func._L("ScrollkeeperHistory", "CAT_BANK_GOLD"),
    bankedItems = SF.func._L("ScrollkeeperHistory", "CAT_BANK_ITEMS"),
    sales = SF.func._L("ScrollkeeperHistory", "CAT_SALES"),
  }
  return names[category] or SF.func._L("ScrollkeeperHistory", "EVENT_UNKNOWN")
end

-- Format time ago
local function formatTimeAgo(timestamp)
  local now = GetTimeStamp()
  local diff = now - timestamp
  
  if diff < 60 then
    return SF.func._L("ScrollkeeperHistory", "TIME_JUST_NOW")
  elseif diff < 3600 then
    return string.format(SF.func._L("ScrollkeeperHistory", "TIME_MINUTES_AGO"), math.floor(diff / 60))
  elseif diff < 86400 then
    return string.format(SF.func._L("ScrollkeeperHistory", "TIME_HOURS_AGO"), math.floor(diff / 3600))
  elseif diff < 2592000 then
    return string.format(SF.func._L("ScrollkeeperHistory", "TIME_DAYS_AGO"), math.floor(diff / 86400))
  else
    return string.format(SF.func._L("ScrollkeeperHistory", "TIME_MONTHS_AGO"), math.floor(diff / 2592000))
  end
end

-- Format full date/time
local function formatFullDate(timestamp)
  return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

-- Parse event details from cached event data
local function parseEventDetails(event)
  local details = ""
  local info = event.info
  
  if event.category == "roster" then
    -- For joins and leaves, the person's name is already in the Member column
    -- For other roster events, show target in details
    if event.eventType == 0 or event.eventType == 6 or event.eventType == 3 or event.eventType == 4 or event.eventType == 10 then
      local targetName = info.targetDisplayName or info.displayName or ""
      if targetName ~= "" then
        details = targetName
      end
      if (event.eventType == 3 or event.eventType == 4) and info.rankName then
        if details ~= "" then
          details = details .. " " .. SF.func._L("ScrollkeeperHistory", "FORMAT_RANK_ARROW") .. " " .. info.rankName
        else
          details = info.rankName
        end
      end
    end
  elseif event.category == "bankedGold" then
    if info.amount then
      details = string.format(SF.func._L("ScrollkeeperHistory", "FORMAT_GOLD"), ZO_LocalizeDecimalNumber(info.amount))
    end
    if info.kioskName then
      details = details .. " - " .. info.kioskName
    end
  elseif event.category == "bankedItems" then
    if info.itemLink and info.quantity then
      local itemName = GetItemLinkName(info.itemLink)
      if info.quantity > 1 then
        details = string.format(SF.func._L("ScrollkeeperHistory", "FORMAT_QUANTITY_ITEM"), info.quantity, itemName)
      else
        details = itemName
      end
    end
  elseif event.category == "sales" then
    if info.itemLink then
      local itemName = GetItemLinkName(info.itemLink)
      if info.quantity and info.quantity > 1 then
        details = string.format(SF.func._L("ScrollkeeperHistory", "FORMAT_QUANTITY_ITEM"), info.quantity, itemName)
      else
        details = itemName
      end
    end
    if info.price then
      if details ~= "" then
        details = details .. " - "
      end
      details = details .. string.format(SF.func._L("ScrollkeeperHistory", "FORMAT_GOLD"), ZO_LocalizeDecimalNumber(info.price))
    end
    if info.buyerDisplayName then
      details = details .. " " .. string.format(SF.func._L("ScrollkeeperHistory", "FORMAT_SOLD_TO"), info.buyerDisplayName)
    end
  end
  
  return details
end

-- Get display name from event
local function getEventDisplayName(event)
  local info = event.info
  
  if event.category == "roster" then
    return info.actingDisplayName or info.displayName or SF.func._L("ScrollkeeperHistory", "MEMBER_UNKNOWN")
  end
  return info.displayName or info.actingDisplayName or info.sellerDisplayName or SF.func._L("ScrollkeeperHistory", "MEMBER_UNKNOWN")
end

-- Theme update function for history window
local function applyHistoryTheme(window)
  if not window or not SF or not SF.theme then return end
  
  -- Update title bar
  if window.titleBar and window.titleText then
    if SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end
  
  -- Update control panel
  if window.controlPanel and SF.theme.colors and SF.theme.colors.panel then
    local p = SF.theme.colors.panel
    window.controlPanel:SetCenterColor(p[1], p[2], p[3], p[4])
  end
  
  -- Update header panel background
  if window.headerPanel and SF.theme.colors and SF.theme.colors.header then
    local h = SF.theme.colors.header
    window.headerPanel:SetCenterColor(h[1] * 0.3, h[2] * 0.3, h[3] * 0.3, 1)
  end
  
  -- Update column headers
  if SF.applyThemeColor then
    if window.timeHeader then SF.applyThemeColor(window.timeHeader, "header") end
    if window.categoryHeader then SF.applyThemeColor(window.categoryHeader, "header") end
    if window.eventHeader then SF.applyThemeColor(window.eventHeader, "header") end
    if window.memberHeader then SF.applyThemeColor(window.memberHeader, "header") end
    if window.detailsHeader then SF.applyThemeColor(window.detailsHeader, "header") end
  end
end

-- Collect events from cache with filtering
local function collectGuildEvents(guildName, maxEvents, searchTerm, selectedCategory)
  
  if not SF.Data or not SF.Data.getEvents then
    d(SF.func._L("ScrollkeeperHistory", "LOG_DATA_UNAVAILABLE"))
    return {}
  end
  
  local settings = getSettings()
  local guildSettings = getGuildSettings(guildName)
  
  maxEvents = maxEvents or settings.maxEvents
  
  -- Get all events for this guild
  local allEvents = SF.Data.getEvents(guildName, "all", maxEvents * 2)
  
  -- Filter by enabled categories
  local filteredEvents = {}
  for _, event in ipairs(allEvents) do
    if guildSettings.categories[event.category] then
      -- Add parsed details
      event.displayName = getEventDisplayName(event)
      event.details = parseEventDetails(event)
      table.insert(filteredEvents, event)
    end
  end
  
  -- Apply category filter
  if selectedCategory and selectedCategory ~= "all" then
    local categoryFiltered = {}
    for _, event in ipairs(filteredEvents) do
      if event.category == selectedCategory then
        table.insert(categoryFiltered, event)
      end
    end
    filteredEvents = categoryFiltered
  end
  
  -- Apply search filter
  if searchTerm and searchTerm ~= "" then
    local searchFiltered = {}
    for _, event in ipairs(filteredEvents) do
      local eventName = string.lower(getEventTypeName(event.category, event.eventType))
      local memberName = string.lower(event.displayName)
      local details = string.lower(event.details or "")
      
      -- For roster events, also search target name
      local targetName = ""
      if event.category == "roster" and event.info.targetDisplayName then
        targetName = string.lower(event.info.targetDisplayName)
      end
      
      local searchText = eventName .. " " .. memberName .. " " .. details .. " " .. targetName
      
      local matches = false
      if LibTextFilter then
        matches = LibTextFilter:Filter(searchText, string.lower(searchTerm))
      else
        matches = string.find(searchText, string.lower(searchTerm), 1, true) ~= nil
      end
      
      if matches then
        table.insert(searchFiltered, event)
      end
    end
    filteredEvents = searchFiltered
  end
  
  -- Limit results
  if #filteredEvents > maxEvents then
    local limited = {}
    for i = 1, maxEvents do
      limited[i] = filteredEvents[i]
    end
    return limited
  end
  
  return filteredEvents
end

-- LibScroll integration for smooth scrolling
local function setupSmoothScroll(scrollControl, scrollBar, contentHeight, visibleHeight, updateFunc, window)
  if not scrollControl or not scrollBar or not updateFunc or not window then return end
  
  -- Check if LibScroll is available (uses module-level variable)
  if not libScroll or type(libScroll.SetScrollBar) ~= "function" then
    -- d() call removed - already logged during initialization
    -- Fallback to basic mousewheel if LibScroll unavailable
    scrollControl:SetHandler("OnMouseWheel", function(self, delta)
      if not scrollBar:IsHidden() then
        local min, max = scrollBar:GetMinMax()
        local current = scrollBar:GetValue()
        local newValue = zo_clamp(current - (delta * 3), min, max)
        if newValue ~= current then
          scrollBar:SetValue(newValue)
          window.scrollOffset = math.floor(newValue)
          local pendingGeneration = (self.pendingGeneration or 0) + 1
          self.pendingGeneration = pendingGeneration
          zo_callLater(function()
            if self.pendingGeneration == pendingGeneration then
              updateFunc(window)
            end
          end, 16)
        end
      end
    end)
    return
  end
  
  -- Use LibScroll for smooth scrolling
  libScroll:SetScrollBar(scrollControl, scrollBar)
  
  -- Update content dimensions
  local function updateScrollable()
    if not window.allEvents then return end
    local totalRows = #window.allEvents
    local rowHeight = 30
    local actualContentHeight = totalRows * rowHeight
    
    libScroll:SetScrollableSize(scrollControl, actualContentHeight)
  end
  
  -- Register scroll callback
  libScroll:SetScrollCallback(scrollControl, function(offset)
    local rowHeight = 30
    window.scrollOffset = math.floor(offset / rowHeight)
    updateFunc(window)
  end)
  
  -- Store update function on window for external use
  window.updateScrollable = updateScrollable
  
  -- Initial update
  updateScrollable()
end

-- Forward declare for setupMouseWheel
local updateEventList

-- Create history window
local function createHistoryWindow()
  local windowName = "ScrollkeeperHistory_Window"
  
  -- Ensure no existing window
  local existingWindow = GetControl(windowName)
  if existingWindow then
    existingWindow:SetHidden(true)
    existingWindow:SetParent(nil)
  end
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(1000, 700)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(true)
  
  -- Background
  local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0.1, 0.1, 0.1, 0.95)
  bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  bg:SetEdgeTexture("", 2, 2, 1)
  
  -- Title bar
  local titleBar = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  titleBar:SetDimensions(1000, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperHistory", "WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1) -- Will be themed after window creation
  
  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -5, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function()
    window:SetHidden(true)
    if LibTextFilter then
      LibTextFilter:ClearCachedTokens()
    end
  end)
  
  -- Control panel
  local controlPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  controlPanel:SetDimensions(980, 100)
  controlPanel:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 40)
  controlPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  
  window.controlPanel = controlPanel
  
  -- Guild selector label
  local guildLabel = WINDOW_MANAGER:CreateControl(nil, controlPanel, CT_LABEL)
  guildLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  guildLabel:SetText(SF.func._L("ScrollkeeperHistory", "LABEL_GUILD"))
  guildLabel:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 10, 10)
  guildLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Guild selector background
  local guildDropdownBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_GuildBg", controlPanel, "ZO_ComboBox")
  guildDropdownBg:SetDimensions(250, 30)
  guildDropdownBg:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 10, 30)
  
  local guildCombo = ZO_ComboBox_ObjectFromContainer(guildDropdownBg)
  guildCombo:SetSortsItems(false)
  guildCombo:SetFont("ZoFontGame")
  
  -- Category filter
  local categoryLabel = WINDOW_MANAGER:CreateControl(nil, controlPanel, CT_LABEL)
  categoryLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  categoryLabel:SetText(SF.func._L("ScrollkeeperHistory", "LABEL_CATEGORY"))
  categoryLabel:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 280, 10)
  categoryLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local categoryDropdownBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_CategoryBg", controlPanel, "ZO_ComboBox")
  categoryDropdownBg:SetDimensions(150, 30)
  categoryDropdownBg:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 280, 30)
  
  local categoryCombo = ZO_ComboBox_ObjectFromContainer(categoryDropdownBg)
  categoryCombo:SetSortsItems(false)
  categoryCombo:SetFont("ZoFontGame")
  
  -- Add category options
  local categories = {
    {name = SF.func._L("ScrollkeeperHistory", "CAT_ALL"), value = "all"},
    {name = SF.func._L("ScrollkeeperHistory", "CAT_ROSTER"), value = "roster"},
    {name = SF.func._L("ScrollkeeperHistory", "CAT_BANK_GOLD"), value = "bankedGold"},
    {name = SF.func._L("ScrollkeeperHistory", "CAT_BANK_ITEMS"), value = "bankedItems"},
    {name = SF.func._L("ScrollkeeperHistory", "CAT_SALES"), value = "sales"},
  }
  
  for _, cat in ipairs(categories) do
    local entry = categoryCombo:CreateItemEntry(cat.name, function()
      window.selectedCategory = cat.value
      if window.refreshEvents then
        window:refreshEvents()
      end
    end)
    categoryCombo:AddItem(entry)
  end
  categoryCombo:SetSelectedItem(SF.func._L("ScrollkeeperHistory", "CAT_ALL"))
  window.selectedCategory = "all"
  
  -- Search box
  local searchLabel = WINDOW_MANAGER:CreateControl(nil, controlPanel, CT_LABEL)
  searchLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  searchLabel:SetText(SF.func._L("ScrollkeeperHistory", "LABEL_SEARCH"))
  searchLabel:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 450, 10)
  searchLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local searchBg = WINDOW_MANAGER:CreateControlFromVirtual(nil, controlPanel, "ZO_EditBackdrop")
  searchBg:SetDimensions(300, 30)
  searchBg:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 450, 30)
  
  local searchInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_Search", searchBg, "ZO_DefaultEditForBackdrop")
  searchInput:SetMaxInputChars(50)
  
  -- Results count and status
  local countLabel = WINDOW_MANAGER:CreateControl(windowName .. "_Count", controlPanel, CT_LABEL)
  countLabel:SetFont("ZoFontGameSmall")
  countLabel:SetText(string.format(SF.func._L("ScrollkeeperHistory", "LABEL_EVENTS_COUNT"), 0))
  countLabel:SetAnchor(TOPLEFT, controlPanel, TOPLEFT, 10, 70)
  countLabel:SetColor(0.6, 0.6, 0.6, 1)
  
  local statusLabel = WINDOW_MANAGER:CreateControl(windowName .. "_Status", controlPanel, CT_LABEL)
  statusLabel:SetFont("ZoFontGameSmall")
  statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_READY"))
  statusLabel:SetAnchor(TOPRIGHT, controlPanel, TOPRIGHT, -10, 70)
  statusLabel:SetColor(0.4, 1, 0.4, 1)
  
  -- Scroll container for events
  local scrollContainer = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
  scrollContainer:SetDimensions(980, 510)
  scrollContainer:SetAnchor(TOPLEFT, controlPanel, BOTTOMLEFT, 0, 10)

  -- Headers
  local headerPanel = WINDOW_MANAGER:CreateControl(nil, scrollContainer, CT_BACKDROP)
  headerPanel:SetDimensions(980, 30)
  headerPanel:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, 0)
  headerPanel:SetCenterColor(0.1, 0.1, 0.2, 1)
  
  local timeHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  timeHeader:SetFont("ZoFontGameBold")
  timeHeader:SetText(SF.func._L("ScrollkeeperHistory", "HEADER_TIME"))
  timeHeader:SetAnchor(LEFT, headerPanel, LEFT, 10, 0)
  timeHeader:SetColor(1, 1, 1, 1)
  
  local categoryHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  categoryHeader:SetFont("ZoFontGameBold")
  categoryHeader:SetText(SF.func._L("ScrollkeeperHistory", "HEADER_CATEGORY"))
  categoryHeader:SetAnchor(LEFT, headerPanel, LEFT, 100, 0)
  categoryHeader:SetColor(1, 1, 1, 1)
  
  local eventHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  eventHeader:SetFont("ZoFontGameBold")
  eventHeader:SetText(SF.func._L("ScrollkeeperHistory", "HEADER_EVENT"))
  eventHeader:SetAnchor(LEFT, headerPanel, LEFT, 200, 0)
  eventHeader:SetColor(1, 1, 1, 1)
  
  local memberHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  memberHeader:SetFont("ZoFontGameBold")
  memberHeader:SetText(SF.func._L("ScrollkeeperHistory", "HEADER_MEMBER"))
  memberHeader:SetAnchor(LEFT, headerPanel, LEFT, 380, 0)
  memberHeader:SetColor(1, 1, 1, 1)
  
  local detailsHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  detailsHeader:SetFont("ZoFontGameBold")
  detailsHeader:SetText(SF.func._L("ScrollkeeperHistory", "HEADER_DETAILS"))
  detailsHeader:SetAnchor(LEFT, headerPanel, LEFT, 600, 0)
  detailsHeader:SetColor(1, 1, 1, 1)
  
  -- Scroll bar
  local scrollBar = WINDOW_MANAGER:CreateControl(nil, scrollContainer, CT_SLIDER)
  scrollBar:SetDimensions(16, 465)
  scrollBar:SetAnchor(TOPRIGHT, scrollContainer, TOPRIGHT, 0, 35)
  scrollBar:SetOrientation(ORIENTATION_VERTICAL)
  scrollBar:SetMinMax(0, 100)
  scrollBar:SetValue(0)
  scrollBar:SetThumbTexture("/esoui/art/miscellaneous/scrollbox_elevator.dds", "/esoui/art/miscellaneous/scrollbox_elevator_disabled.dds", nil, 8, 16)
  scrollBar:SetMouseEnabled(true)
  scrollBar:SetHidden(true)

  -- Event list area
  local listArea = WINDOW_MANAGER:CreateControl(nil, scrollContainer, CT_CONTROL)
  listArea:SetDimensions(960, 465)
  listArea:SetAnchor(TOPLEFT, headerPanel, BOTTOMLEFT, 0, 5)
  listArea:SetMouseEnabled(true)
 
  -- Button panel at bottom
  local buttonPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
  buttonPanel:SetDimensions(300, 50)
  buttonPanel:SetAnchor(BOTTOM, window, BOTTOM, 0, -10)

  -- Refresh button
  local refreshBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  refreshBtn:SetDimensions(35, 35)
  refreshBtn:SetAnchor(RIGHT, buttonPanel, CENTER, -40, -5)
  refreshBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_up.dds")
  refreshBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_down.dds")
  refreshBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_over.dds")

  refreshBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperHistory", "TIP_REFRESH"))
  end)
  refreshBtn:SetHandler("OnMouseExit", function() 
    ClearTooltip(InformationTooltip) 
  end)
  
  -- Refresh label
  local refreshLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  refreshLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  refreshLabel:SetText(SF.func._L("ScrollkeeperHistory", "LABEL_REFRESH"))
  refreshLabel:SetAnchor(TOP, refreshBtn, BOTTOM, 0, -3)
  refreshLabel:SetColor(1, 1, 1, 1)

  -- Export button
  local exportBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  exportBtn:SetDimensions(35, 35)
  exportBtn:SetAnchor(LEFT, buttonPanel, CENTER, 40, -5)
  exportBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_up.dds")
  exportBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_down.dds")
  exportBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_over.dds")

  exportBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperHistory", "TIP_EXPORT"))
  end)
  exportBtn:SetHandler("OnMouseExit", function() 
    ClearTooltip(InformationTooltip) 
  end)
  
  -- Export label
  local exportLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  exportLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  exportLabel:SetText(SF.func._L("ScrollkeeperHistory", "LABEL_EXPORT"))
  exportLabel:SetAnchor(TOP, exportBtn, BOTTOM, 0, -3)
  exportLabel:SetColor(1, 1, 1, 1)
  
  -- Store button references
  window.refreshBtn = refreshBtn
  window.exportBtn = exportBtn
  
  -- Store other references for theme updates
  window.guildCombo = guildCombo
  window.categoryCombo = categoryCombo
  window.searchInput = searchInput
  window.countLabel = countLabel
  window.statusLabel = statusLabel
  window.listArea = listArea
  window.scrollBar = scrollBar
  window.eventRows = {}
  window.allEvents = {}
  window.scrollOffset = 0
  
  -- Store theme-related controls
  window.titleBar = titleBar
  window.titleText = title
  window.headerPanel = headerPanel
  window.timeHeader = timeHeader
  window.categoryHeader = categoryHeader
  window.eventHeader = eventHeader
  window.memberHeader = memberHeader
  window.detailsHeader = detailsHeader
  
  -- Register theme update callback
  window.updateTheme = function()
    applyHistoryTheme(window)
  end
  
  -- Register with framework
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperHistory_Window", window.updateTheme)
  end
  
  -- Apply initial theme
  zo_callLater(function()
    applyHistoryTheme(window)
  end, 100)
    
  SF.addOrnateFrame(window)
  return window
end

-- Forward declare updateEventList so it can be referenced earlier
local updateEventList
local refreshEvents

-- Define updateEventList function
updateEventList = function(window)
  if not window or not window.listArea then return end
  
  local settings = getSettings()
  local rowHeight = 30
  local visibleRows = math.floor(465 / rowHeight)
  
  -- Clear existing rows
  for _, row in ipairs(window.eventRows) do
    if row and row.SetParent then
      row:SetParent(nil)
    end
  end
  window.eventRows = {}
  
  local events = window.allEvents or {}
  local totalRows = #events
  
  -- Show/hide scroll bar
  if totalRows > visibleRows then
    window.scrollBar:SetHidden(false)
    window.scrollBar:SetMinMax(0, math.max(0, totalRows - visibleRows))
  else
    window.scrollBar:SetHidden(true)
    window.scrollBar:SetValue(0)
    window.scrollOffset = 0
  end
  
  -- Update count
  if window.countLabel then
    window.countLabel:SetText(string.format(SF.func._L("ScrollkeeperHistory", "LABEL_EVENTS_COUNT"), totalRows))
  end
  
  -- Create visible rows
  local startIndex = math.max(1, math.min(window.scrollOffset + 1, totalRows))
  local endIndex = math.min(startIndex + visibleRows - 1, totalRows)
  
  for i = startIndex, endIndex do
    local event = events[i]
    if event then
      local rowIndex = i - startIndex
      
      -- Create row
      local row = WINDOW_MANAGER:CreateControl(nil, window.listArea, CT_CONTROL)
      row:SetDimensions(960, rowHeight)
      row:SetAnchor(TOPLEFT, window.listArea, TOPLEFT, 0, rowIndex * rowHeight)
      
      table.insert(window.eventRows, row)
      
      -- Row background
      local rowBg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
      rowBg:SetAnchorFill()
      if rowIndex % 2 == 0 then
        rowBg:SetCenterColor(0.05, 0.05, 0.08, 0.9)
      else
        rowBg:SetCenterColor(0.08, 0.08, 0.12, 0.9)
      end
      
      -- Time
      local timeLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
      timeLabel:SetFont("ZoFontGameSmall")
      timeLabel:SetText(formatTimeAgo(event.timestamp))
      timeLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 10, 5)
      timeLabel:SetColor(0.7, 0.7, 0.7, 1)
      
      -- Tooltip with full timestamp
      timeLabel:SetMouseEnabled(true)
      timeLabel:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
        SetTooltipText(InformationTooltip, formatFullDate(event.timestamp))
      end)
      timeLabel:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
      
      -- Category
      local categoryLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
      categoryLabel:SetFont("ZoFontGameSmall")
      categoryLabel:SetText(getCategoryDisplayName(event.category))
      categoryLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 100, 5)
      categoryLabel:SetColor(0.8, 0.8, 0.8, 1)
      
      -- Event type with color coding
      local eventLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
      eventLabel:SetFont("ZoFontGame")
      local eventName = getEventTypeName(event.category, event.eventType)
      
	  -- Add manual indicator if this is a manual entry
      -- Check both possible locations for manual flag
      local isManual = event.isManual or (event.info and event.info._manualEntry)
      if isManual then
        eventName = eventName .. " ^"
      end
	  
      if settings.enableColorCoding then
        local color = getEventColor(event.category, event.eventType)
        eventLabel:SetText(color .. eventName .. "|r")
      else
        eventLabel:SetText(eventName)
      end
      
      eventLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 200, 5)
	  
	  -- Add tooltip for manual entries
      if isManual then
        eventLabel:SetMouseEnabled(true)
        eventLabel:SetHandler("OnMouseEnter", function(self)
          InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
          local tooltipText = SF.func._L("ScrollkeeperHistory", "MANUAL_ENTRY_TOOLTIP")
          if event.info and event.info._notes then
            tooltipText = tooltipText .. "\n" .. SF.func._L("ScrollkeeperHistory", "NOTES_LABEL") .. ": " .. event.info._notes
          end
          SetTooltipText(InformationTooltip, tooltipText)
        end)
        eventLabel:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
      end
	  
      -- Member name
      local memberLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
      memberLabel:SetFont("ZoFontGame")
      memberLabel:SetText(event.displayName or SF.func._L("ScrollkeeperHistory", "MEMBER_UNKNOWN"))
      memberLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 380, 5)
      memberLabel:SetColor(0.9, 0.9, 0.9, 1)
      
      -- Details
      local detailsLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
	  detailsLabel:SetFont("ZoFontGameSmall")
	  local fullDetailText = event.details or ""
	  local detailText = fullDetailText

	  -- Truncate if too long
	  if string.len(detailText) > 60 then
	    detailText = string.sub(detailText, 1, 57) .. "..."
	  end

	  detailsLabel:SetText(detailText)
	  detailsLabel:SetAnchor(TOPLEFT, row, TOPLEFT, 600, 5)
	  detailsLabel:SetColor(0.7, 0.7, 0.7, 1)

	  -- Add tooltip if truncated
	  if string.len(fullDetailText) > 60 then
	    detailsLabel:SetMouseEnabled(true)
	    detailsLabel:SetHandler("OnMouseEnter", function(self)
		  InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
		  SetTooltipText(InformationTooltip, fullDetailText)
	    end)
	    detailsLabel:SetHandler("OnMouseExit", function() 
		  ClearTooltip(InformationTooltip) 
	    end)
	  end
	  
	  -- Add delete button for manual entries
      if event.isManual or (event.info and event.info._manualEntry) then
        local deleteBtn = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
        deleteBtn:SetDimensions(16, 16)
        deleteBtn:SetAnchor(RIGHT, row, RIGHT, -5, 0)
        deleteBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
        deleteBtn:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
        deleteBtn:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")
        
        deleteBtn:SetHandler("OnMouseEnter", function(self)
          InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
          SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperHistory", "DELETE_MANUAL_ENTRY"))
        end)
        deleteBtn:SetHandler("OnMouseExit", function() 
          ClearTooltip(InformationTooltip) 
        end)
        
        deleteBtn:SetHandler("OnClicked", (function(capturedEvent, capturedGuildName)
          return function()
            -- Delete the manual entry from the data module
            if SF.Data and SF.Data.deleteManualEntry then
              local success = SF.Data.deleteManualEntry(capturedGuildName, capturedEvent.timestamp, capturedEvent.info)
              if success then
                d(SF.func._L("ScrollkeeperHistory", "SUCCESS_DELETED_ENTRY"))
                refreshEvents(window)
              else
                d(SF.func._L("ScrollkeeperHistory", "ERROR_DELETE_FAILED"))
              end
            end
          end
        end)(event, window.selectedGuildName))
      end
    end
	-- Update count
    if window.countLabel then
      window.countLabel:SetText(string.format(SF.func._L("ScrollkeeperHistory", "LABEL_EVENTS_COUNT"), totalRows))
    end
  
    -- Update scrollable size if using LibScroll
    if window.updateScrollable then
      window.updateScrollable()
    end
  end
end

-- Define refreshEvents function
refreshEvents = function(window)
  if not window or not window.selectedGuildName then 
    if window and window.statusLabel then
      window.statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_NO_GUILD"))
      window.statusLabel:SetColor(1, 0.8, 0.2, 1)
    end
    return 
  end
  
  if not SF.Data or not SF.Data.getEvents then
    if window.statusLabel then
      window.statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_DATA_NOT_READY"))
      window.statusLabel:SetColor(1, 0.4, 0.4, 1)
    end
    return
  end
  
  local searchTerm = window.searchInput:GetText()
  window.allEvents = collectGuildEvents(
    window.selectedGuildName, 
    getSettings().maxEvents,
    searchTerm,
    window.selectedCategory
  )
  
  window.scrollOffset = 0
  if window.scrollBar then
    window.scrollBar:SetValue(0)
  end
  updateEventList(window)
  
  if window.statusLabel then
    if #window.allEvents == 0 then
      if SF.Data.isReady and SF.Data.isReady() then
        window.statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_NO_EVENTS_CACHE"))
      else
        window.statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_WAITING_LH"))
      end
      window.statusLabel:SetColor(1, 0.8, 0.2, 1)
    else
      window.statusLabel:SetText(string.format(SF.func._L("ScrollkeeperHistory", "STATUS_READY_LOADED"), #window.allEvents))
      window.statusLabel:SetColor(0.4, 1, 0.4, 1)
    end
  end
end

-- Export function
local function exportEvents(window)
  if not window or not window.selectedGuildName or not window.allEvents then
    return SF.func._L("ScrollkeeperHistory", "ERROR_NO_EXPORT")
  end
  
  local exportText = string.format(SF.func._L("ScrollkeeperHistory", "EXPORT_HEADER"), window.selectedGuildName) .. "\n"
  exportText = exportText .. string.format(SF.func._L("ScrollkeeperHistory", "EXPORT_GENERATED"), os.date("%Y-%m-%d %H:%M:%S", GetTimeStamp())) .. "\n"
  
  local categoryName = window.selectedCategory == "all" and SF.func._L("ScrollkeeperHistory", "CAT_ALL") or getCategoryDisplayName(window.selectedCategory)
  exportText = exportText .. string.format(SF.func._L("ScrollkeeperHistory", "EXPORT_CATEGORY"), categoryName) .. "\n"
  exportText = exportText .. string.format(SF.func._L("ScrollkeeperHistory", "EXPORT_TOTAL"), #window.allEvents) .. "\n\n"
  
  for _, event in ipairs(window.allEvents) do
    local eventType = getEventTypeName(event.category, event.eventType)
    -- Check both possible locations for manual flag
    local isManual = event.isManual or (event.info and event.info._manualEntry)
    if isManual then
      eventType = eventType .. " (Manual)"
    end
    local member = event.displayName or SF.func._L("ScrollkeeperHistory", "MEMBER_UNKNOWN")
    local details = event.details or ""
    local timestamp = formatFullDate(event.timestamp)
    
    exportText = exportText .. string.format(SF.func._L("ScrollkeeperHistory", "EXPORT_FORMAT"),
      timestamp,
      getCategoryDisplayName(event.category),
      eventType,
      member,
      details
    ) .. "\n"
  end
  
  return exportText
end

-- Export window creation
local function createExportWindow(exportText)
  local windowName = "ScrollkeeperHistory_ExportWindow"
  
  local existingWindow = GetControl(windowName)
  if existingWindow then
    existingWindow:SetHidden(false)
	-- Update text content
    local textControl = existingWindow.textArea
    if textControl then
      textControl:SetText(exportText)
      zo_callLater(function()
        textControl:SelectAll()
        textControl:TakeFocus()
      end, 100)
    end
    return existingWindow
  end
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(800, 600)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 100, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(false)
  
  local bg = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0.1, 0.1, 0.1, 0.95)
  bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  bg:SetEdgeTexture("", 2, 2, 1)
  
  local titleBar = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  titleBar:SetDimensions(800, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperHistory", "EXPORT_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  local textArea = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  textArea:SetDimensions(780, 480)
  textArea:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 45)
  textArea:SetCenterColor(0.05, 0.05, 0.05, 1)
  textArea:SetEdgeColor(0.3, 0.3, 0.3, 1)
  textArea:SetEdgeTexture("", 1, 1, 0)
  
  local editBox = WINDOW_MANAGER:CreateControl(nil, textArea, CT_EDITBOX)
  editBox:SetAnchor(TOPLEFT, textArea, TOPLEFT, 5, 5)
  editBox:SetAnchor(BOTTOMRIGHT, textArea, BOTTOMRIGHT, -5, -5)
  editBox:SetEditEnabled(true)
  editBox:SetMouseEnabled(true)
  editBox:SetMaxInputChars(100000)
  editBox:SetFont("ZoFontGameSmall")
  editBox:SetMultiLine(true)
  editBox:SetNewLineEnabled(true)
  editBox:SetText(exportText)
  
  window.textArea = editBox
  
  -- Select All button
  local selectAllBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  selectAllBtn:SetDimensions(95, 27)
  selectAllBtn:SetAnchor(BOTTOM, window, BOTTOM, 0, -35)
  local selectAllBtnBg = WINDOW_MANAGER:CreateControl(nil, selectAllBtn, CT_BACKDROP)
  selectAllBtnBg:SetAnchorFill(selectAllBtn)
  ApplyTemplateToControl(selectAllBtnBg, "ZO_DefaultBackdrop")
  if SF.applyThemeColor then
    SF.applyThemeColor(selectAllBtnBg, "accent")
  end
  
  local selectAllLabel = WINDOW_MANAGER:CreateControl(nil, selectAllBtn, CT_LABEL)
  selectAllLabel:SetFont("$(PROSE_ANTIQUE_FONT)|19")
  selectAllLabel:SetText(SF.func._L("ScrollkeeperHistory", "EXPORT_SELECT_ALL"))
  selectAllLabel:SetAnchor(CENTER, selectAllBtn, CENTER, 0, 0)
  selectAllLabel:SetColor(1, 1, 1, 1)
  
  selectAllBtn:SetHandler("OnClicked", function()
    editBox:SelectAll()
    editBox:TakeFocus()
  end)
  
  local instruction = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  instruction:SetFont("ZoFontGame")
  instruction:SetText(SF.func._L("ScrollkeeperHistory", "EXPORT_INSTRUCTION"))
  instruction:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 10, -5)
  instruction:SetColor(0.8, 0.8, 0.8, 1)
  
  zo_callLater(function()
    editBox:SelectAll()
    editBox:TakeFocus()
  end, 100)
  
  -- Theme the export window
  window.titleBar = titleBar
  window.titleText = title
  window.updateTheme = function()
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end
  
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperHistory_ExportWindow", window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)
  SF.addOrnateFrame(window)
  return window
end

-- Initialize window
local function initializeWindow()
  local window = createHistoryWindow()
  if not window then 
    d(SF.func._L("ScrollkeeperHistory", "ERROR_WINDOW_FAILED"))
    return 
  end
  
  -- Store refresh function on window
  window.refreshEvents = function()
    refreshEvents(window)
  end
  
  -- Populate guild dropdown with enabled guilds
  window.populateGuildDropdown = function()
    window.guildCombo:ClearItems()
    
    local settings = getSettings()
    local enabledGuilds = {}
    
  -- Get guilds in proper display order
  local orderedGuilds = getGuildsInOrder()
  
  for _, guildName in ipairs(orderedGuilds) do
    local guildSettings = getGuildSettings(guildName)
    if guildSettings.enabled then
      table.insert(enabledGuilds, guildName)
    end
  end
  
  if #enabledGuilds == 0 then
    local noGuildsEntry = window.guildCombo:CreateItemEntry(
      SF.func._L("ScrollkeeperHistory", "DROPDOWN_NO_GUILDS"), 
      function() end
    )
    window.guildCombo:AddItem(noGuildsEntry)
    window.guildCombo:SetSelectedItem(SF.func._L("ScrollkeeperHistory", "DROPDOWN_NO_GUILDS"))
    
    if window.statusLabel then
      window.statusLabel:SetText(SF.func._L("ScrollkeeperHistory", "STATUS_ENABLE_GUILDS"))
      window.statusLabel:SetColor(1, 0.4, 0.4, 1)
    end
    return
  end
    
  -- Store current selection
  local currentSelection = window.selectedGuildName
  
  -- Add each enabled guild in order
  for _, guildName in ipairs(enabledGuilds) do
    local entry = window.guildCombo:CreateItemEntry(guildName, function()
      window.selectedGuildName = guildName
      refreshEvents(window)
    end)
    window.guildCombo:AddItem(entry)
  end
  
  -- Restore previous selection if it still exists, otherwise select first
  if currentSelection and guildSettings and getGuildSettings(currentSelection).enabled then
    window.selectedGuildName = currentSelection
    window.guildCombo:SetSelectedItem(currentSelection)
  else
    window.selectedGuildName = enabledGuilds[1]
    window.guildCombo:SetSelectedItem(enabledGuilds[1])
  end
  
  -- Load data for selected guild
  refreshEvents(window)
end
  
  -- Initial population
  window.populateGuildDropdown()
  
  -- Search handler with debounce
  local searchTimer = nil
  window.searchInput:SetHandler("OnTextChanged", function()
    if searchTimer then
      zo_removeCallLater(searchTimer)
    end
    searchTimer = zo_callLater(function()
      refreshEvents(window)
    end, getSettings().searchDelay)
  end)
  
  -- Scroll bar handler
  window.scrollBar:SetHandler("OnValueChanged", function(control, value)
    local newOffset = math.floor(value or 0)
    if newOffset ~= window.scrollOffset then
      window.scrollOffset = newOffset
      updateEventList(window)
    end
  end)
  
  -- Setup smooth scrolling with LibScroll (must be after scroll handler is set)
  setupSmoothScroll(window.listArea, window.scrollBar, 465, 465, updateEventList, window)
  
  -- Refresh button handler
  window.refreshBtn:SetHandler("OnClicked", function()
    window.populateGuildDropdown()
    zo_callLater(function()
      refreshEvents(window)
    end, 100)
  end)

  -- Export button handler
  window.exportBtn:SetHandler("OnClicked", function()
    if window.selectedGuildName and window.allEvents and #window.allEvents > 0 then
      local exportText = exportEvents(window)
      createExportWindow(exportText)
    else
      d(SF.func._L("ScrollkeeperHistory", "ERROR_NO_EXPORT"))
    end
  end)
  
  return window
end

-- Build settings controls
local function buildControls()
  local settings = getSettings()
  
  local controls = {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperHistory", "SUBMENU_NAME"),
      controls = {
        {
          type = "description",
          text = SF.func._L("ScrollkeeperHistory", "SETTINGS_DESC")
        },
        {
          type = "header",
          name = SF.func._L("ScrollkeeperHistory", "SETTINGS_DISPLAY")
        },
        {
          type = "slider",
          name = SF.func._L("ScrollkeeperHistory", "SETTINGS_MAX_EVENTS"),
          tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_MAX_EVENTS_TIP"),
          min = 1000,
          max = 30000,
          step = 1000,
          getFunc = function() return settings.maxEvents end,
          setFunc = function(v) settings.maxEvents = v end,
          default = 5000,
        },
        {
          type = "slider",
          name = SF.func._L("ScrollkeeperHistory", "SETTINGS_SEARCH_DELAY"),
          tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_SEARCH_DELAY_TIP"),
          min = 100,
          max = 1000,
          step = 100,
          getFunc = function() return settings.searchDelay end,
          setFunc = function(v) settings.searchDelay = v end,
          default = 300,
        },
        {
          type = "checkbox",
          name = SF.func._L("ScrollkeeperHistory", "SETTINGS_COLOR_CODING"),
          tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_COLOR_CODING_TIP"),
          getFunc = function() return settings.enableColorCoding end,
          setFunc = function(v) settings.enableColorCoding = v end,
          default = true,
        },
      },
    },
  }
  
  -- Add per-guild settings
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    
    if guildName and guildName ~= "" then
      local guildSubmenu = {
        type = "submenu",
        name = guildName,
        controls = {
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_SHOW_GUILD"),
            tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_SHOW_GUILD_TIP"),
            getFunc = function() return getGuildSettings(guildName).enabled end,
            setFunc = function(v) 
              local gs = getGuildSettings(guildName)
              if gs then gs.enabled = v end
            end,
            default = true,
          },
          {
            type = "header",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_CATEGORIES"),
          },
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_ROSTER_EVENTS"),
            tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_ROSTER_EVENTS_TIP"),
            getFunc = function() return getGuildSettings(guildName).categories.roster end,
            setFunc = function(v) 
              local gs = getGuildSettings(guildName)
              if gs and gs.categories then gs.categories.roster = v end
            end,
            disabled = function() return not getGuildSettings(guildName).enabled end,
            default = true,
            width = "half",
          },
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_BANK_GOLD_EVENTS"),
            tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_BANK_GOLD_EVENTS_TIP"),
            getFunc = function() return getGuildSettings(guildName).categories.bankedGold end,
            setFunc = function(v) 
              local gs = getGuildSettings(guildName)
              if gs and gs.categories then gs.categories.bankedGold = v end
            end,
            disabled = function() return not getGuildSettings(guildName).enabled end,
            default = true,
            width = "half",
          },
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_BANK_ITEMS_EVENTS"),
            tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_BANK_ITEMS_EVENTS_TIP"),
            getFunc = function() return getGuildSettings(guildName).categories.bankedItems end,
            setFunc = function(v) 
              local gs = getGuildSettings(guildName)
              if gs and gs.categories then gs.categories.bankedItems = v end
            end,
            disabled = function() return not getGuildSettings(guildName).enabled end,
            default = true,
            width = "half",
          },
          {
            type = "checkbox",
            name = SF.func._L("ScrollkeeperHistory", "SETTINGS_SALES_EVENTS"),
            tooltip = SF.func._L("ScrollkeeperHistory", "SETTINGS_SALES_EVENTS_TIP"),
            getFunc = function() return getGuildSettings(guildName).categories.sales end,
            setFunc = function(v) 
              local gs = getGuildSettings(guildName)
              if gs and gs.categories then gs.categories.sales = v end
            end,
            disabled = function() return not getGuildSettings(guildName).enabled end,
            default = true,
            width = "half",
          },
        },
      }
      
      table.insert(controls[1].controls, guildSubmenu)
    end
  end

  return controls
end

-- Slash command
SLASH_COMMANDS["/sgthistory"] = function()
  local window = GetControl("ScrollkeeperHistory_Window")
  if not window then
    window = initializeWindow()
    if not window then
      d(SF.func._L("ScrollkeeperHistory", "ERROR_WINDOW_FAILED"))
      return
    end
  end
  
  if window then
    window:SetHidden(not window:IsHidden())
    if not window:IsHidden() and window.selectedGuildName then
      refreshEvents(window)
    end
  end
end

-- Initialize
local function initialize()
  if _addon._initialized then return end

  -- Initialize LibScroll reference
  libScroll = LibScroll
  if not libScroll then
    d(SF.func._L("ScrollkeeperHistory", "LOG_LIBSCROLL_NOT_FOUND"))
  end
   
  local settings = getSettings()
  if not settings then return end
  
  if not settings.guildSettings then
    settings.guildSettings = {}
  end
  
  -- Pre-initialize guild settings
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    if guildName and guildName ~= "" then
      getGuildSettings(guildName)
    end
  end
  
  -- Register with framework
  if SF_Set and SF_Set.RegisterModuleOptions then
    local controls = buildControls()
    SF_Set.RegisterModuleOptions(_addon.Name, controls)
  end
  
  _addon._initialized = true
  d(SF.func._L("ScrollkeeperHistory", "SUCCESS_READY"))
end

-- Keep the same callback registration as before
CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)

EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function(_, initial)
  if not initial then return end
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  
  zo_callLater(function()
    if not _addon._initialized then
      d(SF.func._L("ScrollkeeperHistory", "LOG_FALLBACK_INIT"))
      initialize()
    end
  end, 10000)
end)