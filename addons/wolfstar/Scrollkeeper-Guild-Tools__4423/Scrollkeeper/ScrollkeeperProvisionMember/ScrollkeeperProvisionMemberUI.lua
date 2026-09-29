-- Scrollkeeper Provision Member: Window UI (main window, export window, scrolling)

-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

if type(SF) ~= "table" or type(SF_Set) ~= "table" then
  d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_FRAMEWORK_MISSING"))
  return
end

Scrollkeeper.ProvisionMember = Scrollkeeper.ProvisionMember or { Name = "ScrollkeeperProvisionMember", Version = "1" }
local _addon = Scrollkeeper.ProvisionMember

SF.ProvisionMember = SF.ProvisionMember or {}
local PM = SF.ProvisionMember
PM.Internal = PM.Internal or {}

-- Track scroll position and generate unique control names for member rows
local scrollOffset = 0
local uniqueIdCounter = 0

local function getUniqueControlName(prefix)
  uniqueIdCounter = uniqueIdCounter + 1
  return prefix .. "_" .. tostring(uniqueIdCounter) .. "_" .. tostring(GetTimeStamp())
end

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

-- Theme update function for provision window
local function applyProvisionTheme(window)
  if not window or not SF or not SF.theme then return end

  -- Update outer window border to match theme
  if window.bg and SF.applyThemeColor then
    SF.applyThemeColor(window.bg, "border")
  end
  
  -- Update title bar
  if window.titleBar and window.titleText and SF.applyThemeToTitleBar then
    SF.applyThemeToTitleBar(window.titleBar, window.titleText)
  end

  -- Update header panel background
  if window.headerPanel and SF.theme.colors and SF.theme.colors.header then
    local h = SF.theme.colors.header
    window.headerPanel:SetCenterColor(h[1] * 0.3, h[2] * 0.3, h[3] * 0.3, 1)
  end

  -- Update column headers
  if SF.applyThemeColor then
    if window.nameHeader then SF.applyThemeColor(window.nameHeader, "header") end
    if window.daysHeader then SF.applyThemeColor(window.daysHeader, "header") end
    if window.statusHeader then SF.applyThemeColor(window.statusHeader, "header") end
    if window.notesHeader then SF.applyThemeColor(window.notesHeader, "header") end
    if window.actionsHeader then SF.applyThemeColor(window.actionsHeader, "header") end
    if window.nameSortArrow then SF.applyThemeColor(window.nameSortArrow, "header") end
    if window.daysSortArrow then SF.applyThemeColor(window.daysSortArrow, "header") end
  end

  -- Update stats panel
  if window.statsPanel and SF.theme.colors and SF.theme.colors.panel then
    local p = SF.theme.colors.panel
    window.statsPanel:SetCenterColor(p[1], p[2], p[3], p[4])
  end
  -- Update filter button states with theme
  if window.updateFilterStates then
    window.updateFilterStates()
  end
end

-- Create export text window
local function createExportWindow(exportText)
  local windowName = "ScrollkeeperProvision_ExportWindow"

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
  window:SetAnchor(CENTER, GuiRoot, CENTER, 100, 0) -- Offset from main window
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
  titleBar:SetDimensions(800, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)

  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)

  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)

  -- Create proper editable text area
  local textArea = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  textArea:SetDimensions(780, 480)
  textArea:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 45)
  textArea:SetCenterColor(0.05, 0.05, 0.05, 1)
  textArea:SetEdgeColor(0.3, 0.3, 0.3, 1)
  textArea:SetEdgeTexture("", 1, 1, 0)

  -- Create basic EditBox
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
  selectAllLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_SELECT_ALL"))
  selectAllLabel:SetAnchor(CENTER, selectAllBtn, CENTER, 0, 0)
  selectAllLabel:SetColor(1, 1, 1, 1)

  selectAllBtn:SetHandler("OnClicked", function()
    editBox:SelectAll()
    editBox:TakeFocus()
  end)

  -- Instructions
  local instruction = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  instruction:SetFont("ZoFontGame")
  instruction:SetText(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_INSTRUCTION"))
  instruction:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 10, -5)
  instruction:SetColor(0.8, 0.8, 0.8, 1)

  -- Auto-focus after creation
  zo_callLater(function()
    editBox:SelectAll()
    editBox:TakeFocus()
  end, 100)

  -- Theme the export window
  window.titleBar = titleBar
  window.titleText = title
  window.updateTheme = function()
    if window.bg and SF.applyThemeColor then
      SF.applyThemeColor(window.bg, "border")
    end
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end

  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperProvision_ExportWindow", window.updateTheme)
  end

  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)

  SF.addOrnateFrame(window)
  return window
end

-- Mousewheel scrolling for the provision window's member list
local function setupSmoothScroll(scrollControl, scrollBar, contentHeight, visibleHeight, updateFunc, window)
  if not scrollControl or not scrollBar or not updateFunc or not window then return end
  local pendingGeneration = 0

  scrollControl:SetHandler("OnMouseWheel", function(self, delta)
    if not scrollBar:IsHidden() then
      local min, max = scrollBar:GetMinMax()
      local current = scrollBar:GetValue()
      local newValue = zo_clamp(current - (delta * 3), min, max)
      if newValue ~= current then
        scrollBar:SetValue(newValue)
        window.scrollOffset = math.floor(newValue)
        pendingGeneration = pendingGeneration + 1
        local thisGeneration = pendingGeneration
        zo_callLater(function()
          if thisGeneration == pendingGeneration then
            updateFunc(window)
          end
        end, 16)
      end
    end
  end)
end

-- Create provisional member management window
local function createProvisionWindow()
  local windowName = "ScrollkeeperProvision_Window"

  local existingWindow = GetControl(windowName)
  if existingWindow then
    return existingWindow
  end

  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(1000, 750)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(true)

-- Initialize window variables
  window.selectedGuild = nil
  window.activeFilter = "all"
  window.memberRows = {}
  window.highlightedMembers = {}
  window.viewingHighlighted = false
  window.sortColumn = "days"
  window.sortDirection = "asc"

  -- Background and title bar
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
  title:SetText(SF.func._L("ScrollkeeperProvisionMember", "WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)

  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)

  -- Guild selection dropdown
  local guildLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  guildLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  guildLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "SELECT_GUILD"))
  guildLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 50)
  guildLabel:SetColor(1, 1, 1, 1)

  local guildDropdown = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_ComboBox")
  guildDropdown:SetDimensions(300, 30)
  guildDropdown:SetAnchor(TOPLEFT, guildLabel, TOPRIGHT, 10, -5)

  local guildCombo = ZO_ComboBox_ObjectFromContainer(guildDropdown)
  guildCombo:SetSortsItems(false)
  guildCombo:SetFont("ZoFontGame")

  -- Filter buttons
  local filterLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  filterLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  filterLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "FILTER_LABEL"))
  filterLabel:SetAnchor(LEFT, guildDropdown, RIGHT, 20, 5)
  filterLabel:SetColor(1, 1, 1, 1)

  -- All members filter button
  local allBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  allBtn:SetDimensions(40, 40)
  allBtn:SetAnchor(LEFT, filterLabel, RIGHT, 10, -2)

  -- Background for all button
  local allBg = WINDOW_MANAGER:CreateControl(nil, allBtn, CT_BACKDROP)
  allBg:SetAnchorFill()
  allBg:SetCenterColor(0.3, 0.3, 0.4, 1) -- Darker background for active state
  allBg:SetEdgeColor(0.3, 0.3, 0.4, 1)
  allBg:SetEdgeTexture("", 2, 2, 1)

  local allLabel = WINDOW_MANAGER:CreateControl(nil, allBtn, CT_LABEL)
  allLabel:SetAnchor(CENTER, allBtn, CENTER, 0, 0)
  allLabel:SetFont("ZoFontGameBold")
  allLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "FILTER_ALL"))
  allLabel:SetColor(1, 1, 1, 1)

  -- Probation filter button
  local probationBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  probationBtn:SetDimensions(40, 40)
  probationBtn:SetAnchor(LEFT, allBtn, RIGHT, 10, 0)

  local probationBg = WINDOW_MANAGER:CreateControl(nil, probationBtn, CT_BACKDROP)
  probationBg:SetAnchorFill()
  probationBg:SetCenterColor(0.1, 0.1, 0.2, 1) -- Inactive state
  probationBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
  probationBg:SetEdgeTexture("", 2, 2, 1)

  local probationIcon = WINDOW_MANAGER:CreateControl(nil, probationBtn, CT_TEXTURE)
  probationIcon:SetDimensions(24, 24)
  probationIcon:SetAnchor(CENTER, probationBtn, CENTER, 0, 0)
  probationIcon:SetTexture("/esoui/art/guild/tabicon_roster_up.dds")

  -- Add tooltip for probation button
  probationBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "FILTER_PROBATION_ICON_TIP"))
  end)
  probationBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Gold filter button
  local goldBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  goldBtn:SetDimensions(40, 40)
  goldBtn:SetAnchor(LEFT, probationBtn, RIGHT, 10, 0)

  local goldBg = WINDOW_MANAGER:CreateControl(nil, goldBtn, CT_BACKDROP)
  goldBg:SetAnchorFill()
  goldBg:SetCenterColor(0.1, 0.1, 0.2, 1) -- Inactive state
  goldBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
  goldBg:SetEdgeTexture("", 2, 2, 1)

  local goldIcon = WINDOW_MANAGER:CreateControl(nil, goldBtn, CT_TEXTURE)
  goldIcon:SetDimensions(24, 24)
  goldIcon:SetAnchor(CENTER, goldBtn, CENTER, 0, 0)
  goldIcon:SetTexture("/esoui/art/currency/currency_gold.dds")
  goldIcon:SetColor(1, 0.8, 0.2, 1)

  -- Add tooltip for gold button
  goldBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "FILTER_GOLD_ICON_TIP"))
  end)
  goldBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Inactive filter button
  local inactiveBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  inactiveBtn:SetDimensions(40, 40)
  inactiveBtn:SetAnchor(LEFT, goldBtn, RIGHT, 10, 0)

  local inactiveBg = WINDOW_MANAGER:CreateControl(nil, inactiveBtn, CT_BACKDROP)
  inactiveBg:SetAnchorFill()
  inactiveBg:SetCenterColor(0.1, 0.1, 0.2, 1)
  inactiveBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
  inactiveBg:SetEdgeTexture("", 2, 2, 1)

  local inactiveIcon = WINDOW_MANAGER:CreateControl(nil, inactiveBtn, CT_TEXTURE)
  inactiveIcon:SetDimensions(24, 24)
  inactiveIcon:SetAnchor(CENTER, inactiveBtn, CENTER, 0, 0)
  inactiveIcon:SetTexture("/esoui/art/tutorial/timer_icon.dds")
  inactiveIcon:SetColor(0.6, 0.6, 0.6, 1)

  inactiveBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "FILTER_INACTIVE_TIP"))
  end)
  inactiveBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Donor filter button
  local donorBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  donorBtn:SetDimensions(40, 40)
  donorBtn:SetAnchor(LEFT, inactiveBtn, RIGHT, 10, 0)

  local donorBg = WINDOW_MANAGER:CreateControl(nil, donorBtn, CT_BACKDROP)
  donorBg:SetAnchorFill()
  donorBg:SetCenterColor(0.1, 0.1, 0.2, 1)
  donorBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
  donorBg:SetEdgeTexture("", 2, 2, 1)

  local donorIcon = WINDOW_MANAGER:CreateControl(nil, donorBtn, CT_TEXTURE)
  donorIcon:SetDimensions(24, 24)
  donorIcon:SetAnchor(CENTER, donorBtn, CENTER, 0, 0)
  donorIcon:SetTexture("/esoui/art/icons/servicemappins/servicepin_bank.dds")

  donorBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "FILTER_DONOR_TIP"))
  end)
  donorBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
  window.allBg = allBg
  window.probationBg = probationBg
  window.goldBg = goldBg
  window.inactiveBg = inactiveBg
  window.donorBg = donorBg

  -- Function to update filter button states with theme colors
  local function updateFilterStates()
    if not window then return end

    -- Get theme colors or use defaults
    local accentColor = {0.3, 0.3, 0.4, 1}
    local inactiveColor = {0.15, 0.15, 0.2, 1}
    local borderColor = {0.4, 0.4, 0.4, 1}

    if SF and SF.theme and SF.theme.colors then
      if SF.theme.colors.accent then
        accentColor = {SF.theme.colors.accent[1], SF.theme.colors.accent[2], SF.theme.colors.accent[3], 1}
      end
      if SF.theme.colors.border then
        borderColor = {SF.theme.colors.border[1], SF.theme.colors.border[2], SF.theme.colors.border[3], 1}
        inactiveColor = {borderColor[1] * 0.3, borderColor[2] * 0.3, borderColor[3] * 0.3, 1}
      end
    end

    -- Update all button states based on active filter
    local filters = {
      {name = "all", bg = window.allBg},
      {name = "rank", bg = window.probationBg},
      {name = "gold", bg = window.goldBg},
      {name = "inactive", bg = window.inactiveBg},
      {name = "donor", bg = window.donorBg}
    }

    for _, filter in ipairs(filters) do
      if filter.bg then
        if window.activeFilter == filter.name then
          filter.bg:SetCenterColor(accentColor[1], accentColor[2], accentColor[3], accentColor[4])
          filter.bg:SetEdgeColor(accentColor[1], accentColor[2], accentColor[3], 1)
        else
          filter.bg:SetCenterColor(inactiveColor[1], inactiveColor[2], inactiveColor[3], inactiveColor[4])
          filter.bg:SetEdgeColor(borderColor[1], borderColor[2], borderColor[3], 1)
        end
      end
    end
  end

  -- Store the function on window so it can be called elsewhere
  window.updateFilterStates = updateFilterStates

  -- Stats panel
  local statsPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  statsPanel:SetDimensions(960, 60)
  statsPanel:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 90)
  statsPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  statsPanel:SetEdgeColor(1, 1, 1, 1)
  statsPanel:SetEdgeTexture("", 1, 1, 0)

  window.statsPanel = statsPanel
  local statsLabel = WINDOW_MANAGER:CreateControl(nil, statsPanel, CT_LABEL)
  statsLabel:SetFont("ZoFontGame")
  statsLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "STATUS_SELECT_GUILD"))
  statsLabel:SetAnchor(TOPLEFT, statsPanel, TOPLEFT, 10, 10)
  statsLabel:SetColor(1, 1, 1, 1)

  -- Member list area
  local listPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  listPanel:SetDimensions(960, 470)
  listPanel:SetAnchor(TOPLEFT, statsPanel, BOTTOMLEFT, 0, 10)
  listPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  listPanel:SetEdgeColor(0.1, 0.1, 0.1, 0.95)
  listPanel:SetEdgeTexture("", 1, 1, 0)

  -- Column headers
  local headerPanel = WINDOW_MANAGER:CreateControl(nil, listPanel, CT_BACKDROP)
  headerPanel:SetDimensions(960, 30)
  headerPanel:SetAnchor(TOPLEFT, listPanel, TOPLEFT, 0, 0)
  headerPanel:SetCenterColor(0.1, 0.1, 0.2, 1)
  headerPanel:SetEdgeColor(1, 1, 1, 1)
  headerPanel:SetEdgeTexture("", 1, 1, 0)

  -- Non-sortable headers
  local statusHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  statusHeader:SetFont("ZoFontGameBold")
  statusHeader:SetText(SF.func._L("ScrollkeeperProvisionMember", "STATUS"))
  statusHeader:SetAnchor(LEFT, headerPanel, LEFT, 420, 0)
  statusHeader:SetColor(1, 1, 1, 1)

  local notesHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  notesHeader:SetFont("ZoFontGameBold")
  notesHeader:SetText(SF.func._L("ScrollkeeperProvisionMember", "NOTES"))
  notesHeader:SetAnchor(LEFT, headerPanel, LEFT, 600, 0)
  notesHeader:SetColor(1, 1, 1, 1)

  local actionsHeader = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_LABEL)
  actionsHeader:SetFont("ZoFontGameBold")
  actionsHeader:SetText(SF.func._L("ScrollkeeperProvisionMember", "ACTIONS"))
  actionsHeader:SetAnchor(LEFT, headerPanel, LEFT, 800, 0)
  actionsHeader:SetColor(1, 1, 1, 1)

  -- Sortable Name header - needs to be a button for clicking
  local nameHeaderBtn = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_BUTTON)
  nameHeaderBtn:SetDimensions(200, 25)
  nameHeaderBtn:SetAnchor(LEFT, headerPanel, LEFT, 25, 0)
  nameHeaderBtn:SetMouseEnabled(true)

  local nameHeaderLabel = WINDOW_MANAGER:CreateControl(nil, nameHeaderBtn, CT_LABEL)
  nameHeaderLabel:SetFont("ZoFontGameBold")
  nameHeaderLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "MEMBER_NAME"))
  nameHeaderLabel:SetAnchor(LEFT, nameHeaderBtn, LEFT, 0, 0)
  nameHeaderLabel:SetColor(1, 1, 1, 1)

  local nameSortArrow = WINDOW_MANAGER:CreateControl(nil, nameHeaderBtn, CT_LABEL)
  nameSortArrow:SetFont("ZoFontGameBold")
  nameSortArrow:SetText("")
  nameSortArrow:SetAnchor(LEFT, nameHeaderLabel, RIGHT, 5, 0)
  nameSortArrow:SetColor(1, 1, 1, 1)

  -- Sortable Days header - needs to be a button for clicking
  local daysHeaderBtn = WINDOW_MANAGER:CreateControl(nil, headerPanel, CT_BUTTON)
  daysHeaderBtn:SetDimensions(60, 25)
  daysHeaderBtn:SetAnchor(LEFT, headerPanel, LEFT, 340, 0)
  daysHeaderBtn:SetMouseEnabled(true)

  local daysHeaderLabel = WINDOW_MANAGER:CreateControl(nil, daysHeaderBtn, CT_LABEL)
  daysHeaderLabel:SetFont("ZoFontGameBold")
  daysHeaderLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "DAYS"))
  daysHeaderLabel:SetAnchor(LEFT, daysHeaderBtn, LEFT, 0, 0)
  daysHeaderLabel:SetColor(1, 1, 1, 1)

  local daysSortArrow = WINDOW_MANAGER:CreateControl(nil, daysHeaderBtn, CT_LABEL)
  daysSortArrow:SetFont("ZoFontGameBold")
  daysSortArrow:SetText(ZO_SORT_ORDER_UP_ICON)
  daysSortArrow:SetAnchor(LEFT, daysHeaderLabel, RIGHT, 5, 0)
  daysSortArrow:SetColor(1, 1, 1, 1)

  -- Scrollable content area
  local scrollContainer = WINDOW_MANAGER:CreateControl(nil, listPanel, CT_CONTROL)
  scrollContainer:SetDimensions(960, 420)
  scrollContainer:SetAnchor(TOPLEFT, headerPanel, BOTTOMLEFT, 0, 5)
  scrollContainer:SetMouseEnabled(true)

  -- Scroll bar
  local scrollBar = WINDOW_MANAGER:CreateControl(nil, listPanel, CT_SLIDER)
  scrollBar:SetDimensions(16, 420)
  scrollBar:SetAnchor(TOPRIGHT, listPanel, TOPRIGHT, -3, 35)
  scrollBar:SetOrientation(ORIENTATION_VERTICAL)
  scrollBar:SetMinMax(0, 100)
  scrollBar:SetValue(0)
  scrollBar:SetThumbTexture("/esoui/art/miscellaneous/scrollbox_elevator.dds", "/esoui/art/miscellaneous/scrollbox_elevator_disabled.dds", nil, 8, 16)
  scrollBar:SetMouseEnabled(true)
  scrollBar:SetHidden(true)

  -- Button panel
  local buttonPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
  buttonPanel:SetDimensions(960, 90)
  buttonPanel:SetAnchor(BOTTOM, window, BOTTOM, 0, -30)

  -- Calculate centered positions for 6 buttons
  local buttonWidth = 35
  local buttonSpacing = 100
  local totalWidth = 6 * buttonWidth + 5 * buttonSpacing
  local startX = (960 - totalWidth) / 2

  -- Row 1: Main action buttons
  local refreshBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  refreshBtn:SetDimensions(buttonWidth, buttonWidth)
  refreshBtn:SetAnchor(TOPLEFT, buttonPanel, TOPLEFT, startX, 10)
  refreshBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_up.dds")
  refreshBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_down.dds")
  refreshBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/help_tabicon_feedback_over.dds")

  local refreshLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  refreshLabel:SetAnchor(TOP, refreshBtn, BOTTOM, 0, 2)
  refreshLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  refreshLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_REFRESH"))
  refreshLabel:SetColor(1, 1, 1, 1)

  local exportBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  exportBtn:SetDimensions(buttonWidth, buttonWidth)
  exportBtn:SetAnchor(LEFT, refreshBtn, RIGHT, buttonSpacing, 0)
  exportBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_up.dds")
  exportBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_down.dds")
  exportBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/clipboard_over.dds")

  local exportLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  exportLabel:SetAnchor(TOP, exportBtn, BOTTOM, 0, 2)
  exportLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  exportLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_EXPORT"))
  exportLabel:SetColor(1, 1, 1, 1)

  local scanBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  scanBtn:SetDimensions(buttonWidth, buttonWidth)
  scanBtn:SetAnchor(LEFT, exportBtn, RIGHT, buttonSpacing, 0)
  scanBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/campaign_tabicon_history_up.dds")
  scanBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/campaign_tabicon_history_down.dds")
  scanBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/campaign_tabicon_history_over.dds")

  local scanLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  scanLabel:SetAnchor(TOP, scanBtn, BOTTOM, 0, 2)
  scanLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  scanLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_SCAN"))
  scanLabel:SetColor(1, 1, 1, 1)

  -- Row 2: Bulk operation buttons
  local highlightedBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  highlightedBtn:SetDimensions(buttonWidth, buttonWidth)
  highlightedBtn:SetAnchor(LEFT, scanBtn, RIGHT, buttonSpacing, 0)
  highlightedBtn:SetNormalTexture("/esoui/art/mainmenu/menubar_journal_up.dds")
  highlightedBtn:SetPressedTexture("/esoui/art/mainmenu/menubar_journal_down.dds")
  highlightedBtn:SetMouseOverTexture("/esoui/art/mainmenu/menubar_journal_over.dds")

  local highlightedLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  highlightedLabel:SetAnchor(TOP, highlightedBtn, BOTTOM, 0, 2)
  highlightedLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  highlightedLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_VIEW_SELECTED"))
  highlightedLabel:SetColor(1, 1, 1, 1)

  local promoteAllBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  promoteAllBtn:SetDimensions(buttonWidth, buttonWidth)
  promoteAllBtn:SetAnchor(LEFT, highlightedBtn, RIGHT, buttonSpacing, 0)
  promoteAllBtn:SetNormalTexture("/esoui/art/buttons/pointsplus_up.dds")
  promoteAllBtn:SetPressedTexture("/esoui/art/buttons/pointsplus_down.dds")
  promoteAllBtn:SetMouseOverTexture("/esoui/art/buttons/pointsplus_over.dds")

  local promoteAllLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  promoteAllLabel:SetAnchor(TOP, promoteAllBtn, BOTTOM, 0, 2)
  promoteAllLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  promoteAllLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_PROMOTE_ALL"))
  promoteAllLabel:SetColor(1, 1, 1, 1)

  local removeAllBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  removeAllBtn:SetDimensions(buttonWidth, buttonWidth)
  removeAllBtn:SetAnchor(LEFT, promoteAllBtn, RIGHT, buttonSpacing, 0)
  removeAllBtn:SetNormalTexture("/esoui/art/buttons/pointsminus_up.dds")
  removeAllBtn:SetPressedTexture("/esoui/art/buttons/pointsminus_down.dds")
  removeAllBtn:SetMouseOverTexture("/esoui/art/buttons/pointsminus_over.dds")

  local removeAllLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  removeAllLabel:SetAnchor(TOP, removeAllBtn, BOTTOM, 0, 2)
  removeAllLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  removeAllLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_REMOVE_ALL"))
  removeAllLabel:SetColor(1, 1, 1, 1)

  -- Mail integration button
  local mailBtn = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_BUTTON)
  mailBtn:SetDimensions(buttonWidth, buttonWidth)
  mailBtn:SetAnchor(TOP, buttonPanel, TOP, 0, 55) -- Position in second row, center
  mailBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_up.dds")
  mailBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_down.dds")
  mailBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_over.dds")

  local mailLabel = WINDOW_MANAGER:CreateControl(nil, buttonPanel, CT_LABEL)
  mailLabel:SetAnchor(TOP, mailBtn, BOTTOM, 0, 2)
  mailLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  mailLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_MAIL_SELECTED"))
  mailLabel:SetColor(1, 1, 1, 1)

  -- Mail button handler
  mailBtn:SetHandler("OnClicked", function()
    if not window.selectedGuild then
      d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_NO_GUILD_SELECTED"))
      return
    end

    -- Check if ScrollkeeperNotebookMail is available
    if not SLASH_COMMANDS["/sgtmail"] then
      d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_MAIL_UNAVAILABLE"))
      return
    end

    -- Get the members to mail based on current view
    local membersToMail = {}
    local settings = PM.Internal.getSettings()

    if settings and settings.taggedMembers and settings.taggedMembers[window.selectedGuild] then
      local guildMembers = settings.taggedMembers[window.selectedGuild]

      for memberName, data in pairs(guildMembers) do
        if data and type(data) == "table" and data.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
          local shouldInclude = false

          if window.viewingHighlighted then
          shouldInclude = window.highlightedMembers[memberName] == true
        else
          if window.activeFilter == "all" or
             (window.activeFilter == "rank" and (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") or not data.reason)) or
             (window.activeFilter == "gold" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD")) or
             (window.activeFilter == "inactive" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE")) or
             (window.activeFilter == "donor" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR")) then
            shouldInclude = true
          end
        end

          if shouldInclude then
            table.insert(membersToMail, memberName)
          end
        end
      end
    end

    if #membersToMail == 0 then
      d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_NO_MEMBERS_TO_MAIL"))
      return
    end

    -- Open the mail window
    SLASH_COMMANDS["/sgtmail"]()

    -- Wait for the mail window to be created and then set up the recipients
    zo_callLater(function()
      local mailWindow = GetControl("ScrollkeeperMail_Window")
      if mailWindow then
        -- Set the provisional recipients list
        mailWindow.provisionRecipients = membersToMail

        -- Update the guild selection to match
        local guildDropdown = GetControl("ScrollkeeperMail_Window_GuildDropdown")
        if guildDropdown and guildDropdown.m_comboBox then
          guildDropdown.m_comboBox:SetSelectedItem(window.selectedGuild)
          mailWindow.selectedGuildId = nil

        -- Find the guild ID for the selected guild name
          for i = 1, GetNumGuilds() do
            local guildId = GetGuildId(i)
            if GetGuildName(guildId) == window.selectedGuild then
              mailWindow.selectedGuildId = guildId
              break
            end
          end
        end

      -- Update the recipient count display
        local recipientCountLabel = GetControl("ScrollkeeperMail_Window_RecipientCount")
        if recipientCountLabel then
          recipientCountLabel:SetText(string.format(SF.func._L("ScrollkeeperProvisionMember", "MAIL_RECIPIENT_COUNT"), #membersToMail))
        end

      -- Set status
        local statusLabel = GetControl("ScrollkeeperMail_Window_StatusLabel")
        if statusLabel then
          statusLabel:SetText(string.format(SF.func._L("ScrollkeeperProvisionMember", "MAIL_STATUS"), #membersToMail))
          statusLabel:SetColor(0.4, 1, 0.4, 1)
        end

      -- Auto-fill subject if it's gold filter
        if window.activeFilter == "gold" then
          local subjectInput = GetControl("ScrollkeeperMail_Window_SubjectInput")
          if subjectInput then
            subjectInput:SetText(string.format(SF.func._L("ScrollkeeperProvisionMember", "MAIL_SUBJECT_GOLD"), window.selectedGuild))
          end
        end

        d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_MAIL_OPENED"), #membersToMail, window.selectedGuild))
      else
        d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_MAIL_WINDOW_FAILED"))
      end
    end, 500)
  end)

  -- Add tooltip
  mailBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    local tooltipText
    if window.viewingHighlighted then
      local count = 0
      for _ in pairs(window.highlightedMembers) do count = count + 1 end
      tooltipText = string.format(SF.func._L("ScrollkeeperProvisionMember", "BTN_MAIL_SELECTED_TIP_HIGHLIGHTED"), count)
    else
      tooltipText = SF.func._L("ScrollkeeperProvisionMember", "BTN_MAIL_SELECTED_TIP_FILTERED")
    end
    SetTooltipText(InformationTooltip, tooltipText)
  end)
  mailBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Clear member rows function
  local function clearMemberRows()
    for _, row in ipairs(window.memberRows) do
      if row and row.SetParent then
        row:SetParent(nil)
      end
    end
    window.memberRows = {}
  end

  -- Enhanced member list with proper clicking and days calculation
  local function updateMemberList()
    if not window.selectedGuild then
      clearMemberRows()
      return
    end

    local settings = PM.Internal.getSettings()
    if not settings or not settings.taggedMembers then
      clearMemberRows()
      return
    end

    local guildMembers = settings.taggedMembers[window.selectedGuild] or {}
    local rowHeight = 30
    local visibleRows = math.floor(420 / rowHeight)
	
	local guildId = nil
    for i = 1, GetNumGuilds() do
      if GetGuildName(GetGuildId(i)) == window.selectedGuild then
        guildId = GetGuildId(i)
        break
      end
    end

    local daysOfflineByMember = {}
    if guildId then
      for i = 1, GetNumGuildMembers(guildId) do
        local memberDisplayName, _, _, _, secondsOffline = GetGuildMemberInfo(guildId, i)
        if memberDisplayName then
          daysOfflineByMember[memberDisplayName] = math.floor(secondsOffline / 86400)
        end
      end
    end

-- Build member list
local memberList = {}
for memberName, data in pairs(guildMembers) do
  if data and type(data) == "table" then
    local shouldInclude = false

    if window.viewingHighlighted then
      shouldInclude = window.highlightedMembers[memberName] == true
    else
      -- Fix the filter logic
      if window.activeFilter == "all" then
        -- Show ALL tracked members regardless of reason
        shouldInclude = (data.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED"))
      elseif window.activeFilter == "rank" then
        shouldInclude = (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") or not data.reason)
      elseif window.activeFilter == "gold" then
        shouldInclude = (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD"))
      elseif window.activeFilter == "inactive" then
        shouldInclude = (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE"))
      elseif window.activeFilter == "donor" then
        shouldInclude = (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR"))
      end
    end

    if shouldInclude then
      table.insert(memberList, {name = memberName, data = data})
    end
  end
end

-- Sort the member list based on current settings
    if window.sortColumn == "days" then
      table.sort(memberList, function(a, b)
        local aValue = 0
        local bValue = 0

        if a.data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
          aValue = daysOfflineByMember[a.name] or 0
        else
          aValue = math.floor((GetTimeStamp() - (a.data.actualJoinTime or a.data.joinDate or 0)) / 86400)
        end

        if b.data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
          bValue = daysOfflineByMember[b.name] or 0
        else
          bValue = math.floor((GetTimeStamp() - (b.data.actualJoinTime or b.data.joinDate or 0)) / 86400)
        end

        if window.sortDirection == "asc" then
          return aValue < bValue
        else
          return aValue > bValue
        end
      end)
    elseif window.sortColumn == "name" then
      table.sort(memberList, function(a, b)
        local nameA = (a.name or ""):lower()
        local nameB = (b.name or ""):lower()
        if window.sortDirection == "asc" then
          return nameA < nameB
        else
          return nameA > nameB
        end
      end)
    end

    local totalRows = #memberList

    -- Show/hide scroll bar
    if totalRows > visibleRows then
      scrollBar:SetHidden(false)
      scrollBar:SetMinMax(0, math.max(0, totalRows - visibleRows))
    else
      scrollBar:SetHidden(true)
      scrollBar:SetValue(0)
      window.scrollOffset = 0
    end

  -- Clear existing rows
  clearMemberRows()

    -- Create visible rows
    local displayRow = 0
    local startIndex = math.max(1, math.min(scrollOffset + 1, totalRows))
    local endIndex = math.min(startIndex + visibleRows - 1, totalRows)

    for i = startIndex, endIndex do
      local member = memberList[i]
      if member then
        local memberName = member.name
        local data = member.data

        -- Create row with unique name
        local rowControl = WINDOW_MANAGER:CreateControl(getUniqueControlName("Row"), scrollContainer, CT_CONTROL)
        rowControl:SetDimensions(940, rowHeight)
        rowControl:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, displayRow * rowHeight)

        table.insert(window.memberRows, rowControl)

        -- Row background with highlighting support and click handling
        local rowBg = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_BACKDROP)
        rowBg:SetAnchorFill()

        local isHighlighted = window.highlightedMembers[memberName]
        if isHighlighted then
          -- Use theme accent color for highlights
          if SF and SF.theme and SF.theme.colors and SF.theme.colors.accent then
            local accent = SF.theme.colors.accent
            rowBg:SetCenterColor(accent[1] * 0.8, accent[2] * 0.8, accent[3] * 0.8, 1)
            rowBg:SetEdgeColor(accent[1], accent[2], accent[3], 1)
            rowBg:SetEdgeTexture("", 2, 2, 1)
          else
            rowBg:SetCenterColor(0.5, 0.3, 0.1, 1)
            rowBg:SetEdgeColor(0.7, 0.5, 0.2, 1)
            rowBg:SetEdgeTexture("", 2, 2, 1)
          end
        elseif displayRow % 2 == 0 then
          rowBg:SetCenterColor(0.05, 0.05, 0.08, 0.9)
        else
          rowBg:SetCenterColor(0.08, 0.08, 0.12, 0.9)
        end

        -- Make entire row clickable with proper event handling
        rowControl:SetMouseEnabled(true)
        rowControl:SetHandler("OnMouseUp", function(self, button, upInside)
          if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            -- Prevent event bubbling to child controls
            if window.highlightedMembers[memberName] then
              window.highlightedMembers[memberName] = nil
            else
              window.highlightedMembers[memberName] = true
            end
            updateMemberList() -- Refresh to show highlight changes
            return true -- Consume the event
          end
        end)

        -- Also make the background clickable as backup
        rowBg:SetMouseEnabled(true)
        rowBg:SetHandler("OnMouseUp", function(self, button, upInside)
          if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            if window.highlightedMembers[memberName] then
              window.highlightedMembers[memberName] = nil
            else
              window.highlightedMembers[memberName] = true
            end
            updateMemberList()
            return true
          end
        end)

        -- Reason icon
        local reasonIcon = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_TEXTURE)
        reasonIcon:SetDimensions(20, 20)
        reasonIcon:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 2, 7)

        if data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
          reasonIcon:SetTexture("/esoui/art/guild/guild_tradinghouseaccess.dds")
          reasonIcon:SetColor(1, 0.8, 0.2, 1)
        elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
          reasonIcon:SetTexture("/esoui/art/tutorial/timer_icon.dds")
          reasonIcon:SetColor(0.6, 0.6, 0.6, 1)
        elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
          reasonIcon:SetTexture("/esoui/art/icons/servicemappins/servicepin_bank.dds")
        else
          reasonIcon:SetTexture("/esoui/art/tutorial/tabicon_roster_up.dds")
        end

        -- Member name
        local nameLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        nameLabel:SetFont("ZoFontGame")
        nameLabel:SetText(memberName)
        nameLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 25, 5)
        nameLabel:SetColor(1, 1, 1, 1)

        -- Days calculation - show different data based on reason
        local daysSince = ""
        local daysColor = {0.8, 0.8, 0.8, 1}  -- Default gray

        if data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") or not data.reason then
          -- Probation members: show days since join
          if guildId then
            local calculatedDays, source = PM.Internal.getAccurateDaysSinceJoin(guildId, window.selectedGuild, memberName, data)

            if calculatedDays then
              daysSince = tostring(calculatedDays)

              -- Color code by days
              if calculatedDays <= 7 then
                daysColor = {0.4, 1, 0.4, 1} -- Green for new
              elseif calculatedDays <= 21 then
                daysColor = {1, 0.8, 0.4, 1} -- Orange for medium
              else
                daysColor = {1, 0.4, 0.4, 1} -- Red for old
              end

              -- Add source indicator to the display
              if source == SF.func._L("ScrollkeeperProvisionMember", "SOURCE_AMT") then
                daysSince = daysSince .. "*"
              elseif source == SF.func._L("ScrollkeeperProvisionMember", "SOURCE_HISTOIRE") then
                daysSince = daysSince .. "~"
              elseif source == SF.func._L("ScrollkeeperProvisionMember", "SOURCE_DONATION") then
                daysSince = daysSince .. "?"
              elseif source == SF.func._L("ScrollkeeperProvisionMember", "SOURCE_TAGGED") then
                daysSince = daysSince .. "!"
              end
            else
              daysSince = SF.func._L("ScrollkeeperProvisionMember", "DAYS_UNKNOWN")
              daysColor = {0.6, 0.6, 0.6, 1}
            end
          else
            daysSince = SF.func._L("ScrollkeeperProvisionMember", "DAYS_ERROR")
            daysColor = {1, 0.4, 0.4, 1}
          end

        elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
          -- Inactive members: show days offline
        local daysOffline = daysOfflineByMember[memberName]
        if daysOffline then
          daysSince = tostring(daysOffline) .. "d"
          if daysOffline >= 90 then
            daysColor = {1, 0.2, 0.2, 1}
          elseif daysOffline >= 60 then
            daysColor = {1, 0.4, 0.4, 1}
          else
            daysColor = {1, 0.6, 0.4, 1}
          end
        else
          daysSince = SF.func._L("ScrollkeeperProvisionMember", "DAYS_UNKNOWN")
          daysColor = {0.6, 0.6, 0.6, 1}
        end

        elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
          -- Gold filter members: leave blank or show "N/A"
          daysSince = "-"
          daysColor = {0.6, 0.6, 0.6, 1}

        elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
          -- Donor members: leave blank or show "N/A"
          daysSince = "-"
          daysColor = {0.6, 0.6, 0.6, 1}

        else
          -- Unknown reason
          daysSince = "-"
          daysColor = {0.6, 0.6, 0.6, 1}
        end

        local daysLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        daysLabel:SetFont("ZoFontGame")
        daysLabel:SetText(daysSince)
        daysLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 340, 5)
        daysLabel:SetColor(daysColor[1], daysColor[2], daysColor[3], daysColor[4])

        -- Add tooltip to explain the symbols
        daysLabel:SetMouseEnabled(true)
        daysLabel:SetHandler("OnMouseEnter", (function(reason, days)
          return function(self)
            InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)

            local tooltipText = ""

            -- Different tooltip based on reason
            if reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
              tooltipText = "Days Offline\n\n"
              tooltipText = tooltipText .. "Shows how many days this member has been offline.\n"
              tooltipText = tooltipText .. "Higher numbers indicate longer inactivity."

            elseif reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") or not reason then
              tooltipText = SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_HEADER")

              if string.find(days, "%*") then
                tooltipText = tooltipText .. "|c00FF00" .. SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_AMT") .. "|r\n"
              elseif string.find(days, "~") then
                tooltipText = tooltipText .. "|c88FF88" .. SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_HISTOIRE") .. "|r\n"
              elseif string.find(days, "%?") then
                tooltipText = tooltipText .. "|cFFFF88" .. SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_DONATION") .. "|r\n"
              elseif string.find(days, "!") then
                tooltipText = tooltipText .. "|cFFAA88" .. SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_TAGGED") .. "|r\n"
              else
                tooltipText = tooltipText .. SF.func._L("ScrollkeeperProvisionMember", "TIP_DAYS_VALIDATED") .. "\n"
              end

              if not AMT_Available and days ~= SF.func._L("ScrollkeeperProvisionMember", "DAYS_NA") then
                tooltipText = tooltipText .. "\n|cFFFF00" .. SF.func._L("ScrollkeeperProvisionMember", "TIP_INSTALL_AMT") .. "|r"
              end

            else
              tooltipText = "N/A - Not applicable for this filter type"
            end

            SetTooltipText(InformationTooltip, tooltipText)
          end
        end)(data.reason, daysSince))
        daysLabel:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

        -- Status
        local statusLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        statusLabel:SetFont("ZoFontGame")
        statusLabel:SetText(data.status or SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROVISIONAL"))
        statusLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 420, 5)
        statusLabel:SetColor(0.8, 0.8, 0.8, 1)

        -- Notes with proper positioning, color coding, and truncation
        local notes = data.notes or ""
        local noteColor = {0.7, 0.7, 0.7, 1}  -- Default gray

        -- Color code notes based on content
        if string.find(notes:lower(), "donated:") or string.find(notes:lower(), "total donated:") then
          noteColor = {0.4, 1, 0.4, 1}  -- Green for donation info
        elseif string.find(notes:lower(), "offline:") then
          noteColor = {1, 0.6, 0.4, 1}  -- Orange for offline info
        elseif string.find(notes:lower(), "no donations") then
          noteColor = {1, 0.4, 0.4, 1}  -- Red for no donations
        end

        -- Truncate long notes
        local displayNotes = notes
        if string.len(notes) > 25 then
          displayNotes = string.sub(notes, 1, 22) .. "..."
        end

        local notesLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        notesLabel:SetFont("ZoFontGame")
        notesLabel:SetText(displayNotes)
        notesLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 600, 5)
        notesLabel:SetColor(noteColor[1], noteColor[2], noteColor[3], noteColor[4])

        -- Add tooltip if notes were truncated
        if string.len(notes) > 25 then
          notesLabel:SetMouseEnabled(true)
          notesLabel:SetHandler("OnMouseEnter", (function(fullNotes)
            return function(self)
              InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
              SetTooltipText(InformationTooltip, fullNotes)
            end
          end)(notes))
          notesLabel:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        end

        -- Action buttons with tooltips and selection functionality
        local promoteBtn = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_BUTTON)
        promoteBtn:SetDimensions(24, 24)
        promoteBtn:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 800, 5)
        promoteBtn:SetNormalTexture("/esoui/art/buttons/accept_up.dds")
        promoteBtn:SetPressedTexture("/esoui/art/buttons/accept_down.dds")
        promoteBtn:SetMouseOverTexture("/esoui/art/buttons/accept_over.dds")

        -- Add tooltip based on filter type
        promoteBtn:SetHandler("OnMouseEnter", function(self)
          InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)

          local tooltipText
          if data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
            tooltipText = string.format("Open roster to review/kick %s (inactive member)", memberName)
          elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
            tooltipText = string.format("Open roster to review %s (pending donation)", memberName)
          elseif data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
            tooltipText = string.format("Open roster to promote %s (valued contributor)", memberName)
          else
            -- Default for probationary rank
            tooltipText = string.format(SF.func._L("ScrollkeeperProvisionMember", "TIP_REVIEW_PROMOTE"), memberName)
          end

          SetTooltipText(InformationTooltip, tooltipText)
        end)
        promoteBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

        -- Promote button highlights member and then promotes
        promoteBtn:SetHandler("OnClicked", (function(name, guildName)
          return function()
            -- Find the guild ID
            local guildId = nil
            for j = 1, GetNumGuilds() do
              if GetGuildName(GetGuildId(j)) == guildName then
                guildId = GetGuildId(j)
                break
              end
            end

            if guildId then
              -- Open guild roster to the correct guild
              SCENE_MANAGER:Show("guildRoster")
              zo_callLater(function()
                if GUILD_ROSTER_MANAGER then
                  GUILD_ROSTER_MANAGER:SetGuildId(guildId)
                end
              end, 200)

              d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_OPENING_ROSTER_PROMOTE"), name))
            else
              d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_NO_GUILD_ID"), guildName))
            end
          end
        end)(memberName, window.selectedGuild))

        local removeBtn = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_BUTTON)
        removeBtn:SetDimensions(24, 24)
        removeBtn:SetAnchor(LEFT, promoteBtn, RIGHT, 15, 0)
        removeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
        removeBtn:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
        removeBtn:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")

        -- Add tooltip
        removeBtn:SetHandler("OnMouseEnter", function(self)
          InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
          SetTooltipText(InformationTooltip, string.format(SF.func._L("ScrollkeeperProvisionMember", "TIP_REMOVE"), memberName))
        end)
        removeBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

        -- Capture memberName in closure
        removeBtn:SetHandler("OnClicked", (function(name)
          return function()
            if PM.removeMember(window.selectedGuild, name, "Removed via UI") then
              d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_REMOVED"), name))
              -- Remove from highlighted list if present
              window.highlightedMembers[name] = nil
              zo_callLater(function()
                if window.updateStats then window.updateStats() end
                updateMemberList()
              end, 100)
            end
          end
        end)(memberName))

        displayRow = displayRow + 1
      end
    end
	
	-- Update scrollable size if using LibScroll
    if window.updateScrollable then
      window.updateScrollable()
    end
  end

  -- Scroll bar handler
  scrollBar:SetHandler("OnValueChanged", function(control, value)
    local newOffset = math.floor(value or 0)
    if newOffset ~= scrollOffset then
      scrollOffset = newOffset
      updateMemberList()
    end
  end)

  -- Update statistics display
  local updateStats
  updateStats = function()
    if not window.selectedGuild then
      statsLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "STATUS_SELECT_GUILD"))
      return
    end

    local settings = PM.Internal.getSettings()
    if not settings or not settings.taggedMembers then
      statsLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "STATUS_NO_TRACKING"))
      return
    end

    local guildMembers = settings.taggedMembers[window.selectedGuild] or {}

  -- Count by reason
  local reasonCounts = {
    [SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK")] = 0,
    [SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD")] = 0,
    [SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE")] = 0,
    [SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR")] = 0,
  }
  local totalActive = 0
  local promoted = 0

  for _, data in pairs(guildMembers) do
    if data and type(data) == "table" then
      if data.status == SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
        promoted = promoted + 1
      else
        totalActive = totalActive + 1
        local reason = data.reason or SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK")
        reasonCounts[reason] = (reasonCounts[reason] or 0) + 1
      end
    end
  end

  local statsText = string.format(
    "%s | Total: %d | Rank: %d | Gold: %d | Inactive: %d | Donor: %d | Promoted: %d",
    window.selectedGuild,
    totalActive,
    reasonCounts[SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK")],
    reasonCounts[SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD")],
    reasonCounts[SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE")],
    reasonCounts[SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR")],
    promoted
  )
  
  statsLabel:SetText(statsText)
end

  -- Update filter button visual states
  local function updateFilterButtonStates()
    local accent = SF and SF.theme and SF.theme.colors and SF.theme.colors.accent or {0.3, 0.3, 0.4, 1}
    local inactive = {0.1, 0.1, 0.2, 1}

    -- Reset all buttons to inactive or accent depending on activeFilter
    window.allBg:SetCenterColor(unpack(window.activeFilter == "all" and accent or inactive))
    window.probationBg:SetCenterColor(unpack(window.activeFilter == "rank" and accent or inactive))
    window.goldBg:SetCenterColor(unpack(window.activeFilter == "gold" and accent or inactive))

    -- Make active button visually stronger (explicit override)
    if window.activeFilter == "all" then
      window.allBg:SetCenterColor(0.3, 0.3, 0.4, 1)
    elseif window.activeFilter == "rank" then
      window.probationBg:SetCenterColor(0.3, 0.3, 0.4, 1)
    elseif window.activeFilter == "gold" then
      window.goldBg:SetCenterColor(0.3, 0.3, 0.4, 1)
    end
  end

  -- Filter button handlers
  allBtn:SetHandler("OnClicked", function()
    window.activeFilter = "all"
    scrollOffset = 0
    scrollBar:SetValue(0)
    if window.updateFilterStates then window.updateFilterStates() end
    if window.updateMemberList then window.updateMemberList() end
  end)

  probationBtn:SetHandler("OnClicked", function()
    window.activeFilter = "rank"
    scrollOffset = 0
    scrollBar:SetValue(0)
    if window.updateFilterStates then window.updateFilterStates() end
    if window.updateMemberList then window.updateMemberList() end
  end)

  goldBtn:SetHandler("OnClicked", function()
    window.activeFilter = "gold"
    scrollOffset = 0
    scrollBar:SetValue(0)
    if window.updateFilterStates then window.updateFilterStates() end
    if window.updateMemberList then window.updateMemberList() end
  end)

  inactiveBtn:SetHandler("OnClicked", function()
    window.activeFilter = "inactive"
    scrollOffset = 0
    scrollBar:SetValue(0)
    if window.updateFilterStates then window.updateFilterStates() end
    if window.updateMemberList then window.updateMemberList() end
  end)

  donorBtn:SetHandler("OnClicked", function()
    window.activeFilter = "donor"
    scrollOffset = 0
    scrollBar:SetValue(0)
    if window.updateFilterStates then window.updateFilterStates() end
    if window.updateMemberList then window.updateMemberList() end
  end)

  -- Populate guild dropdown
  local function populateGuildDropdown()
  guildCombo:ClearItems()

  -- Get guilds in proper display order
  local orderedGuilds = getGuildsInOrder()
  local trackedGuilds = {}
  
  for _, guildName in ipairs(orderedGuilds) do
    local guildSettings = PM.Internal.getGuildSettings(guildName)
    if guildSettings and guildSettings.enabled then
      table.insert(trackedGuilds, guildName)
    end
  end

  if #trackedGuilds == 0 then
    local noGuildsEntry = guildCombo:CreateItemEntry(SF.func._L("ScrollkeeperProvisionMember", "DROPDOWN_NO_GUILDS"), function() end)
    guildCombo:AddItem(noGuildsEntry)
    guildCombo:SelectItem(noGuildsEntry)
    return
  end

  -- Store current selection
  local currentSelection = window.selectedGuild
  
  for _, guildName in ipairs(trackedGuilds) do
    local entry = guildCombo:CreateItemEntry(guildName, function()
      window.selectedGuild = guildName
      scrollOffset = 0
      scrollBar:SetValue(0)
      window.highlightedMembers = {} -- Clear selections when switching guilds
      updateStats()
      updateMemberList()
    end)
    guildCombo:AddItem(entry)
  end

  -- Restore previous selection if it still exists, otherwise select first guild
  if currentSelection then
    local stillExists = false
    for _, guildName in ipairs(trackedGuilds) do
      if guildName == currentSelection then
        stillExists = true
        break
      end
    end
    
    if stillExists then
      window.selectedGuild = currentSelection
      guildCombo:SetSelectedItem(currentSelection)
    else
      window.selectedGuild = trackedGuilds[1]
      guildCombo:SetSelectedItem(trackedGuilds[1])
    end
  else
    window.selectedGuild = trackedGuilds[1]
    guildCombo:SetSelectedItem(trackedGuilds[1])
  end
  
  updateStats()
  updateMemberList()
end

-- Name header click handler
  nameHeaderBtn:SetHandler("OnClicked", function()
    if window.sortColumn == "name" then
      window.sortDirection = window.sortDirection == "asc" and "desc" or "asc"
    else
      window.sortColumn = "name"
      window.sortDirection = "asc"
    end

    nameSortArrow:SetText(window.sortDirection == "asc" and ZO_SORT_ORDER_UP_ICON or ZO_SORT_ORDER_DOWN_ICON)
    daysSortArrow:SetText("")

    updateMemberList()
  end)

  -- Days header click handler
  daysHeaderBtn:SetHandler("OnClicked", function()
    if window.sortColumn == "days" then
      window.sortDirection = window.sortDirection == "asc" and "desc" or "asc"
    else
      window.sortColumn = "days"
      window.sortDirection = "asc"
    end

    daysSortArrow:SetText(window.sortDirection == "asc" and ZO_SORT_ORDER_UP_ICON or ZO_SORT_ORDER_DOWN_ICON)
    nameSortArrow:SetText("")

    updateMemberList()
  end)

  -- Store functions on window for external access
  window.updateStats = updateStats
  window.updateMemberList = updateMemberList
  window.populateGuildDropdown = populateGuildDropdown
  window.headerPanel = headerPanel
  
-- Setup smooth scrolling with LibScroll
  setupSmoothScroll(scrollContainer, scrollBar, 415, 415, updateMemberList, window)
  
  -- Button handlers
  refreshBtn:SetHandler("OnClicked", function()
    -- Re-evaluate existing members against current donation data
    if window.selectedGuild then
      local reEvaluated = PM.reEvaluateMembers(window.selectedGuild)
      if reEvaluated > 0 then
        d(string.format("Re-evaluated and removed %d members who now meet gold requirements", reEvaluated))
      end
    end

    scrollOffset = 0
    scrollBar:SetValue(0)
    window.viewingHighlighted = false
    window.highlightedMembers = {}
    populateGuildDropdown()
    zo_callLater(function()
      updateStats()
      updateMemberList()
    end, 100)
    d(SF.func._L("ScrollkeeperProvisionMember", "LOG_REFRESHED"))
  end)

  refreshBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_REFRESH_TIP"))
  end)
  refreshBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  exportBtn:SetHandler("OnClicked", function()
    if window.selectedGuild then
      local exportText = PM.exportMembers(
        window.selectedGuild,
        window.activeFilter,
        window.viewingHighlighted,
        window.highlightedMembers
      )
      createExportWindow(exportText)
    else
      d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_NO_GUILD_SELECTED"))
    end
  end)

  exportBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_EXPORT_TIP"))
  end)
  exportBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  scanBtn:SetHandler("OnClicked", function()
    -- Check if data is ready first
    if not SF.Data or not SF.Data.isReady or not SF.Data.isReady() then
      d("|cFF0000[ProvisionMember]|r " .. SF.func._L("ScrollkeeperProvisionMember", "ERROR_DATA_NOT_READY"))
      return
    end

    d("|cFFD700[ProvisionMember]|r " .. SF.func._L("ScrollkeeperProvisionMember", "LOG_STARTING_SCAN"))
    PM.manualScan()

    zo_callLater(function()
      populateGuildDropdown()
      updateStats()
      updateMemberList()
      d("|c00FF00[ProvisionMember]|r " .. SF.func._L("ScrollkeeperProvisionMember", "LOG_SCAN_COMPLETE_SHORT"))
    end, 2000)
  end)

  scanBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_SCAN_TIP"))
  end)
  scanBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Bulk operation button handlers with proper highlighting logic
  highlightedBtn:SetHandler("OnClicked", function()
    window.viewingHighlighted = not window.viewingHighlighted
    scrollOffset = 0
    scrollBar:SetValue(0)

    if window.viewingHighlighted then
      highlightedLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_VIEW_ALL"))
      highlightedLabel:SetColor(1, 0.8, 0.2, 1) -- Orange when active
    else
      highlightedLabel:SetText(SF.func._L("ScrollkeeperProvisionMember", "BTN_VIEW_SELECTED"))
      highlightedLabel:SetColor(1, 1, 1, 1) -- White when inactive
    end

    updateMemberList()

    local highlightedCount = 0
    for _ in pairs(window.highlightedMembers) do highlightedCount = highlightedCount + 1 end
    d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_FILTER_MODE"),
      window.viewingHighlighted and "Selected" or "All", highlightedCount))
  end)

  highlightedBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_VIEW_SELECTED_TIP"))
  end)
  highlightedBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  -- Bulk open roster to review / promote selected members
  promoteAllBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_PROMOTE_ALL_TIP"))
  end)

  promoteAllBtn:SetHandler("OnMouseExit", function(self)
    ClearTooltip(InformationTooltip)
  end)

  promoteAllBtn:SetHandler("OnClicked", function()
    ClearTooltip(InformationTooltip)
    local highlightedCount = 0
    for _ in pairs(window.highlightedMembers) do
      highlightedCount = highlightedCount + 1
    end

    if highlightedCount == 0 then
      d(SF.func._L("ScrollkeeperProvisionMember", "STATUS_NO_SELECTED"))
      return
    end

    -- Find the guild ID for the selected guild
    local guildId = nil
    for j = 1, GetNumGuilds() do
      if GetGuildName(GetGuildId(j)) == window.selectedGuild then
        guildId = GetGuildId(j)
        break
      end
    end

    if guildId then
      -- Open guild roster and set guild
      SCENE_MANAGER:Show("guildRoster")
      zo_callLater(function()
        if GUILD_ROSTER_MANAGER then
          GUILD_ROSTER_MANAGER:SetGuildId(guildId)
        end
      end, 200)

      -- Log the members we intend to act on
      local memberList = {}
      for memberName, _ in pairs(window.highlightedMembers) do
        table.insert(memberList, memberName)
      end
      d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_OPENING_ROSTER_BULK"),
        #memberList, table.concat(memberList, ", ")))
    else
      d(SF.func._L("ScrollkeeperProvisionMember", "LOG_NO_GUILD_ID_SIMPLE"))
    end

    local removedCount = 0
    for memberName, _ in pairs(window.highlightedMembers) do
      if PM.removeMember(window.selectedGuild, memberName, "Bulk removed via UI") then
        removedCount = removedCount + 1
      end
    end

    window.highlightedMembers = {}

    zo_callLater(function()
      if window.updateStats then window.updateStats() end
      updateMemberList()
    end, 100)

    d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_BULK_REMOVED"), removedCount))
  end)

  removeAllBtn:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperProvisionMember", "BTN_REMOVE_ALL_TIP"))
  end)
  removeAllBtn:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  removeAllBtn:SetHandler("OnClicked", function()
    local highlightedCount = 0
    for _ in pairs(window.highlightedMembers) do
      highlightedCount = highlightedCount + 1
    end

    if highlightedCount == 0 then
      d(SF.func._L("ScrollkeeperProvisionMember", "STATUS_NO_SELECTED_REMOVE"))
      return
    end

    local removedCount = 0
    for memberName, _ in pairs(window.highlightedMembers) do
      if PM.removeMember(window.selectedGuild, memberName, "Bulk removed via UI") then
        removedCount = removedCount + 1
      end
    end

    window.highlightedMembers = {}

    zo_callLater(function()
      if window.updateStats then window.updateStats() end
      updateMemberList()
    end, 100)

    d(string.format(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_BULK_REMOVED"), removedCount))
  end)

-- Store theme-related references
  window.titleBar = titleBar
  window.titleText = title
  window.headerPanel = headerPanel
  window.nameHeader = nameHeaderLabel
  window.daysHeader = daysHeaderLabel
  window.nameSortArrow = nameSortArrow
  window.daysSortArrow = daysSortArrow
  window.statusHeader = statusHeader
  window.notesHeader = notesHeader
  window.actionsHeader = actionsHeader

  -- Store filter state update function
  window.updateFilterStates = updateFilterStates

  -- Call it initially
  updateFilterStates()

  -- Register theme update callback
  window.updateTheme = function()
    applyProvisionTheme(window)
  end

  -- Register with framework
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperProvision_Window", window.updateTheme)
  end

  -- Apply initial theme
  zo_callLater(function()
    applyProvisionTheme(window)
  end, 100)

  -- Add OnShow handler for the open message
  window:SetHandler("OnShow", function()
    -- Refresh guild list when opening
    if window.populateGuildDropdown then
      window.populateGuildDropdown()
    end
    
    -- Show message about scanning
    d(string.format("|cFFD700[ProvisionMember]|r %s", 
      SF.func._L("ScrollkeeperProvisionMember", "WINDOW_OPENED_MESSAGE") or 
      "Window opened. Use the Scan button to check for members needing tracking."))
  end)
  
   populateGuildDropdown()
  SF.addOrnateFrame(window)
   return window
end

-- Export so Commands.lua (and any other PM file) can build the window
PM.Internal.CreateWindow = createProvisionWindow