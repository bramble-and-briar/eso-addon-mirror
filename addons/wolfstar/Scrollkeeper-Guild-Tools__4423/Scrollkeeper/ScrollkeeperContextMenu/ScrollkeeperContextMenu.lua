-- Scrollkeeper Guild Tools Addon
-- ScrollkeeperContextMenu
 
-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

-- Initialize module
Scrollkeeper.ContextMenu = Scrollkeeper.ContextMenu or { Name = "ScrollkeeperContextMenu" }
local _addon = Scrollkeeper.ContextMenu

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperContextMenu = Scrollkeeper.ContextMenu

-- Prevent multiple initialization
if _addon._initialized then
  return
end

-- Framework shortcuts
local SF     = ScrollkeeperFramework
local SF_Set = ScrollkeeperFramework_Settings
if type(SF) ~= "table" then
  d("[ScrollkeeperContextMenu] " .. SF.func._L("ScrollkeeperContextMenu", "SF_UNAVAILABLE"))
  return
end

-- 💾 Settings defaults
local defaults = {
  enabled     = true,
  chatNewMail = true,
  chatInvite  = true,
  guildInvite = true,
  logConversations = false,
}

-- Get settings using unified system
local function getSettings()
  return SF.getModuleSettings(_addon.Name, defaults)
end

-- Store originals for safe hooking
local origChatMenu, origMailOnUp, origRosterOnUp

-- Helpers
local function addSeparator()
  AddMenuItem(" ", function() end)
end

-- Common header for all Scrollkeeper submenus
local function contextHead()
  local L = function(k)
    if SF.func and SF.func._L then
      return SF.func._L(_addon.Name, k)
    end
    return k
  end
  addSeparator()
  
  -- Apply theme color to the header
  local headerColor = (SF.getThemeColorHex and SF.getThemeColorHex("header")) or "F5D980"
  AddMenuItem("|c" .. headerColor .. SF.func._L("ScrollkeeperContextMenu", "SCROLLKEEPER_TOOLS") .. "|r", function() end, MENU_ADD_OPTION_LABEL)
  addSeparator()
end

-- 📬 Guild invitation submenu with themed guild names
local function guildInvite(displayName)
  local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"
  
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    if DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_INVITE) then
      local guildName = GetGuildName(guildId)
      AddMenuItem(
        string.format("|c%s%s|r", textColor, string.format(SF.func._L("ScrollkeeperContextMenu", "INVITE_TO"), guildName)),
        function() GuildInvite(guildId, displayName) end
      )
    end
  end
end

-- Helper function to detect and set current guild
local function updateWindowGuildSelection(window)
  if not window or not window.guildCombo then return end
  
  -- Try to detect the guild currently open in the roster scene
  local currentGuildId = nil
  if GUILD_ROSTER_MANAGER and GUILD_ROSTER_MANAGER.guildId then
    currentGuildId = GUILD_ROSTER_MANAGER.guildId
  end
  
  if currentGuildId then
    local guildName = GetGuildName(currentGuildId)
    if guildName then
      window.guildCombo:SetSelectedItem(guildName)
      window.selectedGuild = currentGuildId
    end
  end
end
-- Manual donation logging window
local donationWindowCounter = 0
local function createDonationWindow(displayName)
  local windowName = "ScrollkeeperContextMenu_DonationWindow"
  
  -- Reuse existing window if present
  local existingWindow = GetControl(windowName)
  if existingWindow then
    existingWindow:SetHidden(false)
    
    -- Update ALL player-specific data
    existingWindow.currentPlayerName = displayName
    
    -- Update player name label
    local playerLabel = existingWindow.playerLabel
    if playerLabel then
      playerLabel:SetText(displayName)
    end
    
    -- Clear previous inputs
    if existingWindow.valueInput then existingWindow.valueInput:SetText("") end
    if existingWindow.notesInput then existingWindow.notesInput:SetText("") end
    
    -- Update guild selection when reusing window
    updateWindowGuildSelection(existingWindow)
    return existingWindow
  end
  
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
  title:SetText(SF.func._L("ScrollkeeperContextMenu", "DONATION_WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  -- Player name display
  local playerHeader = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  playerHeader:SetFont("ZoFontGameBold")
  playerHeader:SetText(SF.func._L("ScrollkeeperContextMenu", "DONATION_PLAYER"))
  playerHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 20, 50)
  playerHeader:SetColor(0.8, 0.8, 0.8, 1)
  
  local playerLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  playerLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  playerLabel:SetText(displayName)
  playerLabel:SetAnchor(TOPLEFT, playerHeader, BOTTOMLEFT, 0, 5)
  playerLabel:SetColor(1, 1, 1, 1)
  window.playerLabel = playerLabel
  
  -- Store the current player name on the window object
  window.currentPlayerName = displayName
  
  -- Guild selector
  local guildHeader = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  guildHeader:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  guildHeader:SetText(SF.func._L("ScrollkeeperProvisionMember", "SELECT_GUILD"))
  guildHeader:SetAnchor(TOPLEFT, playerLabel, BOTTOMLEFT, 0, 15)
  guildHeader:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Create backdrop for guild dropdown
  local guildDropdownBg = WINDOW_MANAGER:CreateControl(windowName .. "_GuildBg", window, CT_BACKDROP)
  guildDropdownBg:SetDimensions(460, 30)
  guildDropdownBg:SetAnchor(TOPLEFT, guildHeader, BOTTOMLEFT, 0, 5)
  guildDropdownBg:SetCenterColor(0.1, 0.1, 0.1, 1)
  guildDropdownBg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  guildDropdownBg:SetEdgeTexture("", 1, 1, 0)
  
  local guildComboBox = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_GuildCombo", guildDropdownBg, "ZO_ComboBox")
  guildComboBox:SetAnchorFill()
  
  local guildCombo = ZO_ComboBox_ObjectFromContainer(guildComboBox)
  guildCombo:SetSortsItems(false)
  guildCombo:SetFont("ZoFontGame")
  
  -- Store guildCombo on window object BEFORE using it
  window.guildCombo = guildCombo

  -- Populate guild dropdown
  window.selectedGuild = nil

  -- Try to detect the guild currently open in the roster scene
  local currentGuildId = nil
  if GUILD_ROSTER_MANAGER and GUILD_ROSTER_MANAGER.guildId then
    currentGuildId = GUILD_ROSTER_MANAGER.guildId
  end

  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    if guildName then
      local entry = guildCombo:CreateItemEntry(guildName, function()
        window.selectedGuild = guildId
      end)
      guildCombo:AddItem(entry)

      -- Auto-select the guild that's open in the roster scene
      if currentGuildId and guildId == currentGuildId then
        guildCombo:SetSelectedItem(guildName)
        window.selectedGuild = guildId
      elseif not currentGuildId and not window.selectedGuild then
        -- Fallback to first guild if roster not open
        window.selectedGuild = guildId
        guildCombo:SetSelectedItem(guildName)
      end
    end
  end

  -- Set up guild roster sync AFTER window.guildCombo is defined
  ZO_PreHook(GUILD_ROSTER_MANAGER, "SetGuildId", function(_, newGuildId)
    if window and not window:IsHidden() and window.guildCombo then
      local name = GetGuildName(newGuildId)
      if name then
        window.guildCombo:SetSelectedItem(name)
        window.selectedGuild = newGuildId
      end
    end
  end)
  
  -- Donation type selector
  local typeHeader = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  typeHeader:SetFont("$(PROSE_ANTIQUE_FONT)|16")
  typeHeader:SetText(SF.func._L("ScrollkeeperContextMenu", "DONATION_TYPE_LABEL"))
  typeHeader:SetAnchor(TOPLEFT, guildDropdownBg, BOTTOMLEFT, 0, 15)
  typeHeader:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Create backdrop for type dropdown
  local typeDropdownBg = WINDOW_MANAGER:CreateControl(windowName .. "_TypeBg", window, CT_BACKDROP)
  typeDropdownBg:SetDimensions(460, 30)
  typeDropdownBg:SetAnchor(TOPLEFT, typeHeader, BOTTOMLEFT, 0, 5)
  typeDropdownBg:SetCenterColor(0.1, 0.1, 0.1, 1)
  typeDropdownBg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  typeDropdownBg:SetEdgeTexture("", 1, 1, 0)
  
  local typeComboBox = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_TypeCombo", typeDropdownBg, "ZO_ComboBox")
  typeComboBox:SetAnchorFill()
  
  local typeCombo = ZO_ComboBox_ObjectFromContainer(typeComboBox)
  typeCombo:SetSortsItems(false)
  typeCombo:SetFont("ZoFontGame")
  
  window.donationType = "gold"
  local goldEntry = typeCombo:CreateItemEntry(SF.func._L("ScrollkeeperContextMenu", "DONATION_TYPE_GOLD"), function()
    window.donationType = "gold"
  end)
  typeCombo:AddItem(goldEntry)
  typeCombo:SetSelectedItem(SF.func._L("ScrollkeeperContextMenu", "DONATION_TYPE_GOLD"))
  
  local itemEntry = typeCombo:CreateItemEntry(SF.func._L("ScrollkeeperContextMenu", "DONATION_TYPE_ITEMS"), function()
    window.donationType = "items"
  end)
  typeCombo:AddItem(itemEntry)
  
  -- Value input
  local valueHeader = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  valueHeader:SetFont("$(PROSE_ANTIQUE_FONT)|16")
  valueHeader:SetText(SF.func._L("ScrollkeeperContextMenu", "DONATION_VALUE_LABEL"))
  valueHeader:SetAnchor(TOPLEFT, typeDropdownBg, BOTTOMLEFT, 0, 15)
  valueHeader:SetColor(0.8, 0.8, 0.8, 1)
  
  valueHeader:SetMouseEnabled(true)
  valueHeader:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperContextMenu", "DONATION_VALUE_TIP"))
  end)
  valueHeader:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
  
  local valueBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_ValueBg", window, "ZO_EditBackdrop")
  valueBg:SetDimensions(460, 30)
  valueBg:SetAnchor(TOPLEFT, valueHeader, BOTTOMLEFT, 0, 5)
  
  local valueInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_ValueInput", valueBg, "ZO_DefaultEditForBackdrop")
  valueInput:SetMaxInputChars(10)
  valueInput:SetText("")
  window.valueInput = valueInput
  
  -- Notes input
  local notesHeader = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  notesHeader:SetFont("$(PROSE_ANTIQUE_FONT)|16")
  notesHeader:SetText(SF.func._L("ScrollkeeperContextMenu", "DONATION_NOTES_LABEL"))
  notesHeader:SetAnchor(TOPLEFT, valueBg, BOTTOMLEFT, 0, 15)
  notesHeader:SetColor(0.8, 0.8, 0.8, 1)
  
  notesHeader:SetMouseEnabled(true)
  notesHeader:SetHandler("OnMouseEnter", function(self)
    InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 0)
    SetTooltipText(InformationTooltip, SF.func._L("ScrollkeeperContextMenu", "DONATION_NOTES_TIP"))
  end)
  notesHeader:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
  
  local notesBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_NotesBg", window, "ZO_EditBackdrop")
  notesBg:SetDimensions(460, 30)
  notesBg:SetAnchor(TOPLEFT, notesHeader, BOTTOMLEFT, 0, 5)
  
  local notesInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_NotesInput", notesBg, "ZO_DefaultEditForBackdrop")
  notesInput:SetMaxInputChars(100)
  notesInput:SetText("")
  window.notesInput = notesInput
  
  -- Buttons
  local recordBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  recordBtn:SetDimensions(35, 35)
  recordBtn:SetAnchor(BOTTOM, window, BOTTOM, -100, -30)
  recordBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_up.dds")
  recordBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_down.dds")
  recordBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_over.dds")
  
  local recordLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  recordLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  recordLabel:SetText(SF.func._L("ScrollkeeperContextMenu", "BTN_RECORD_DONATION"))
  recordLabel:SetAnchor(TOP, recordBtn, BOTTOM, 0, 2)
  recordLabel:SetColor(1, 1, 1, 1)
  
  recordBtn:SetHandler("OnClicked", function()
    local amount = tonumber(window.valueInput:GetText())
    if not amount or amount <= 0 then
      d("|cFF0000" .. SF.func._L("ScrollkeeperContextMenu", "ERROR_INVALID_AMOUNT") .. "|r")
      return
    end
    
    if not window.selectedGuild then
      d("|cFF0000" .. SF.func._L("ScrollkeeperProvisionMember", "ERROR_NO_GUILD_SELECTED") .. "|r")
      return
    end
    
    -- Validate that SF.Data and the function exist
    if not SF or not SF.Data or not SF.Data.logManualDonation then
      d("|cFF0000ScrollkeeperData module or logManualDonation function not available|r")
      return
    end
    
    -- Use the stored currentPlayerName instead of closure variable
    local currentPlayer = window.currentPlayerName
    if not currentPlayer or currentPlayer == "" then
      d("|cFF0000Error: No player name set|r")
      return
    end
    
    -- Get guild NAME from guild ID
    local guildName = GetGuildName(window.selectedGuild)
    if not guildName then
      d("|cFF0000Error: Could not get guild name for selected guild|r")
      return
    end
    -- Log the donation
    local notes = window.notesInput:GetText()
    if notes == "" then notes = nil end
    
    local success = SF.Data.logManualDonation(
      guildName,  -- Use guild NAME not guild ID
      currentPlayer,
      amount,
      window.donationType or "gold",
      notes
    )
    
    if success then
      d("|c00FF00" .. string.format(SF.func._L("ScrollkeeperContextMenu", "SUCCESS_DONATION_LOGGED"), amount, currentPlayer) .. "|r")
      window:SetHidden(true)
    else
      d("|cFF0000Failed to log donation - check debug output|r")
    end
  end)
  
  local cancelBtn = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
  cancelBtn:SetDimensions(35, 35)
  cancelBtn:SetAnchor(BOTTOM, window, BOTTOM, 100, -30)
  cancelBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_up.dds")
  cancelBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_down.dds")
  cancelBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_ignored_over.dds")
  
  local cancelLabel = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
  cancelLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  cancelLabel:SetText(SF.func._L("ScrollkeeperContextMenu", "BTN_CANCEL"))
  cancelLabel:SetAnchor(TOP, cancelBtn, BOTTOM, 0, 2)
  cancelLabel:SetColor(1, 1, 1, 1)
  
  cancelBtn:SetHandler("OnClicked", function()
    window:SetHidden(true)
  end)
  
  -- Theme the window
  window.titleBar = titleBar
  window.titleText = title
  window.updateTheme = function()
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end
  
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperContextMenu_DonationWindow", window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)
  
  SF.addOrnateFrame(window)
  return window
end

-- Enhanced Chat right-click menu with proper context handling
local function hookedChat(self, displayName, rawName)
  
  -- Call original function FIRST, then add our menu items
  if origChatMenu and origChatMenu ~= hookedChat then
    origChatMenu(self, displayName, rawName)
  end
  
  -- Get settings and validate
  local settings = getSettings()
  if not settings or not settings.enabled or not displayName or displayName == "" then
    return
  end
  
  -- Add our context menu items
  if settings.chatNewMail or settings.chatInvite then
    contextHead()
    
    if settings.chatNewMail then
      local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"
      AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "NEW_MAIL") .. "|r", function()
        if SCENE_MANAGER then
          SCENE_MANAGER:Show("mailSend")
          zo_callLater(function()
            if ZO_MailSendToField then
              ZO_MailSendToField:SetText(displayName)
            end
          end, 100)
        end
      end)
    end
    
    if settings.chatInvite then
      guildInvite(displayName)
    end
    
    addSeparator()
  end
  
  -- Notebook integration
  if ScrollkeeperNotebook then
    local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"

    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "OPEN_NOTE") .. "|r", function()
      if ScrollkeeperNotebook.openNoteWindowFor then
        ScrollkeeperNotebook:openNoteWindowFor(displayName)
      else
        d("|cFF5555" .. SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_NOT_FOUND") .. "|r")
      end
    end)

    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "CREATE_NOTE") .. "|r", function()
      if not ScrollkeeperNotebook then
        d("|cFF5555" .. SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_NOT_FOUND") .. "|r")
        return
      end
      ScrollkeeperNotebook:saveNote(displayName, "", {"chat"})
      d("|cAADDFF" .. string.format(SF.func._L("ScrollkeeperContextMenu", "NOTE_CREATED"), displayName) .. "|r")
    end)
  end
  
  -- Conversation logging (if enabled and pChat available)
  if settings.logConversations and pChat then
    local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"
    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "LOG_CONVERSATION") .. "|r", function()
      if not ScrollkeeperNotebook then
        d("|cFF5555" .. SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_NOT_FOUND") .. "|r")
        return
      end
      
      -- Get recent messages from this player from pChat history
      if pChat.db and pChat.db.LineStrings and #pChat.db.LineStrings > 0 then
        local conversationLines = {}
        local displayNameLower = displayName:lower()
        
        -- Search backwards through last 100 messages
        local startIdx = math.max(1, #pChat.db.LineStrings - 100)
        for i = #pChat.db.LineStrings, startIdx, -1 do
          local line = pChat.db.LineStrings[i]
          if line then
            -- Check multiple fields for the player name
            local rawFrom = (line.rawFrom or ""):lower()
            local rawLine = (line.rawLine or ""):lower()
            local rawMessage = (line.rawMessage or ""):lower()
            
            -- Match in any of these fields
            if rawFrom:find(displayNameLower, 1, true) or 
               rawLine:find(displayNameLower, 1, true) or
               rawMessage:find(displayNameLower, 1, true) then
              
              -- Use the pre-formatted line if available, otherwise build it
              local logEntry = line.rawLine or ""
              if logEntry == "" then
                local timestamp = line.rawTimestamp and os.date("%H:%M", line.rawTimestamp) or ""
                local channel = line.channel or "?"
                local message = line.rawMessage or line.rawText or ""
                logEntry = string.format("[%s] [%s] %s", timestamp, tostring(channel), message)
              end
              
              table.insert(conversationLines, 1, logEntry)
              if #conversationLines >= 20 then break end
            end
          end
        end
        
        if #conversationLines > 0 then
          local conversation = table.concat(conversationLines, "\n")
          ScrollkeeperNotebook:logConversation(displayName, conversation, "Chat")
          d("|cAADDFF" .. string.format(SF.func._L("ScrollkeeperContextMenu", "CONVERSATION_LOGGED"), #conversationLines, displayName) .. "|r")
        else
          d("|cFFAA55" .. string.format(SF.func._L("ScrollkeeperContextMenu", "NO_CONVERSATION"), displayName .. "|r"))
        end
      else
        d("|cFFAA55pChat chat history not available or empty|r")
      end
    end)
  end
 
  -- Manual donation logging - MUST check if Data module has the function
  if SF and SF.Data and type(SF.Data.logManualDonation) == "function" then
    local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"
    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "LOG_DONATION") .. "|r", function()
      createDonationWindow(displayName)
    end)
  end
 
  -- Show menu with proper backdrop
  ShowMenu(self, nil, MENU_TYPE_CUSTOM)
end

-- Guild roster context menu hook
local function hookedRoster(self, control, button, upInside)
  if origRosterOnUp then
    origRosterOnUp(self, control, button, upInside)
  end

  if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end
  local settings = getSettings()
  if not settings or not settings.enabled then return end
  
  local data = ZO_ScrollList_GetData(control)
  if not data or not data.displayName then return end

  contextHead()

  local displayName = data.displayName
  local textColor = (SF.getThemeColorHex and SF.getThemeColorHex("text")) or "FFFFFF"
  
  -- Notebook integration
  if ScrollkeeperNotebook then
    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "GO_TO_NOTEBOOK") .. "|r", function()
      if ScrollkeeperNotebook and ScrollkeeperNotebook.openNoteWindowFor then
        ScrollkeeperNotebook:openNoteWindowFor(displayName)
      else
        d("|cFF5555" .. SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_NOT_FOUND") .. "|r")
      end
    end)

    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "MAKE_NOTE") .. "|r", function()
      if not ScrollkeeperNotebook then
        d("|cFF5555" .. SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_NOT_FOUND") .. "|r")
        return
      end

      local existing = ScrollkeeperNotebook:loadNote(displayName)
      if existing then
        d("|cFFAA55" .. string.format(SF.func._L("ScrollkeeperContextMenu", "NOTE_EXISTS"), displayName) .. "|r")
      else
        ScrollkeeperNotebook:saveNote(displayName, "", {"roster"})
        d("|cAADDFF" .. string.format(SF.func._L("ScrollkeeperContextMenu", "NOTE_CREATED"), displayName) .. "|r")
      end
    end)
  end
  
  -- Manual donation logging - MUST check if Data module has the function
  if SF and SF.Data and type(SF.Data.logManualDonation) == "function" then
    AddMenuItem("|c" .. textColor .. SF.func._L("ScrollkeeperContextMenu", "LOG_DONATION") .. "|r", function()
      createDonationWindow(displayName)
    end)
  end
  
  addSeparator()
  
  -- Guild invite options (if enabled)
  if settings.guildInvite then
    guildInvite(displayName)
  end
  
  ShowMenu(control, nil, MENU_TYPE_CUSTOM)
end

-- Chat and roster hooks with proper error handling
local function hookContextMenus()
  
  -- Chat menu hook
  if CHAT_SYSTEM and CHAT_SYSTEM.ShowPlayerContextMenu then
    origChatMenu = CHAT_SYSTEM.ShowPlayerContextMenu
    CHAT_SYSTEM.ShowPlayerContextMenu = hookedChat
  end
  
  -- Guild roster hook
  if GUILD_ROSTER_KEYBOARD and GUILD_ROSTER_KEYBOARD.GuildRosterRow_OnMouseUp then
    origRosterOnUp = GUILD_ROSTER_KEYBOARD.GuildRosterRow_OnMouseUp
    GUILD_ROSTER_KEYBOARD.GuildRosterRow_OnMouseUp = hookedRoster
  end
end

-- 🏛️ Build LibAddonMenu2 controls
local function buildControls()
  local settings = getSettings()
  
  return {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperContextMenu", "SUBMENU_NAME"),
      controls = {
        {
          type = "description",
		  text = SF.func._L("ScrollkeeperContextMenu", "DESCRIPTION"),
        },
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperContextMenu", "MASTER_ENABLE"),
          tooltip = SF.func._L("ScrollkeeperContextMenu", "MASTER_ENABLE_TIP"),
          getFunc = function() return settings.enabled end,
          setFunc = function(v)
            settings.enabled = v
            if v then
              hookContextMenus()
            end
          end,
          default = defaults.enabled,
        },
        { type = "header", name = SF.func._L("ScrollkeeperContextMenu", "CHAT_HEADER")},
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperContextMenu", "NEW_MAIL"),
          tooltip = SF.func._L("ScrollkeeperContextMenu", "NEW_MAIL_TIP"),
          getFunc = function() return settings.chatNewMail end,
          setFunc = function(v) settings.chatNewMail = v end,
          disabled = function() return not settings.enabled end,
          default = defaults.chatNewMail,
        },
		{
		  type    = "checkbox",
		  name    = SF.func._L("ScrollkeeperContextMenu", "LOG_CONVERSATIONS"),
		  tooltip = SF.func._L("ScrollkeeperContextMenu", "LOG_CONVERSATIONS_TIP"),
		  getFunc = function() return settings.logConversations end,
		  setFunc = function(v) settings.logConversations = v end,
		  disabled = function() 
			return not settings.enabled or not pChat 
		  end,
		  warning = function()
			if not pChat then
			  return SF.func._L("ScrollkeeperContextMenu", "PCHAT_WARNING")
			end
			return nil
		  end,
		  default = defaults.logConversations,
		},
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperContextMenu", "GUILD_INVITE"),
          tooltip = SF.func._L("ScrollkeeperContextMenu", "GUILD_INVITE_TIP"),
          getFunc = function() return settings.chatInvite end,
          setFunc = function(v) settings.chatInvite = v end,
          disabled = function() return not settings.enabled end,
          default = defaults.chatInvite,
        },
        { type = "header", name = SF.func._L("ScrollkeeperContextMenu", "ROSTER_HEADER")},
		{
		  type    = "description",
		  text    = SF.func._L("ScrollkeeperContextMenu", "ROSTER_DESC"),
		},
		{
		  type    = "checkbox",
		  name    = SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_CONTEXT"),
		  tooltip = SF.func._L("ScrollkeeperContextMenu", "NOTEBOOK_CONTEXT_TIP"),
		  getFunc = function() return settings.enabled end,
		  setFunc = function(v)
		    settings.enabled = v
			if v then
			  hookContextMenus()
			end
		  end,
		  default = defaults.enabled,
		},
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperContextMenu", "ROSTER_INVITE"),
          tooltip = SF.func._L("ScrollkeeperContextMenu", "ROSTER_INVITE_TIP"),
          getFunc = function() return settings.guildInvite end,
          setFunc = function(v) settings.guildInvite = v end,
          disabled = function() return not settings.enabled end,
          default = defaults.guildInvite,
        },
      }
    }
  }
end

-- Initialize
local function initialize()
  if _addon._initialized then return end
  
  -- Register controls
  if SF_Set and SF_Set.RegisterModuleOptions then
    local controls = buildControls()
    SF_Set.RegisterModuleOptions(_addon.Name, controls)
  end
  
  -- Hook the context menus with delay to ensure UI is ready
  local settings = getSettings()
  if settings.enabled then
    hookContextMenus()
  end

  _addon._initialized = true
end

-- Register for proper initialization
EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  initialize()
end)

CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)