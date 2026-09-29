-- Scrollkeeper Guild Tools Addon
-- ScrollkeeperNotebookMail

local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

Scrollkeeper.NotebookMail = Scrollkeeper.NotebookMail or { Name = "ScrollkeeperNotebookMail" }
local _addon = Scrollkeeper.NotebookMail

_G.ScrollkeeperNotebookMail = Scrollkeeper.NotebookMail

if type(SF) ~= "table" or not SF.initAddon then
  d("[ScrollkeeperNotebookMail] ERROR: ScrollkeeperFramework missing!")
  return
end

local _addon = {
  Name    = "ScrollkeeperNotebookMail",
}
ScrollkeeperNotebookMail = ScrollkeeperNotebookMail or _addon

-- Prevent multiple initialization
if _addon._initialized then
  d("[ScrollkeeperNotebookMail] Already initialized, skipping...")
  return
end

-- Settings defaults
local defaults = {
  enabled = true,
}

-- Hard-coded mail throttling (not user-configurable)
local MAIL_DELAY = 3100  -- milliseconds between sends

-- Get settings using unified system
local function getSettings()
  return SF.getModuleSettings(_addon.Name, defaults)
end

-- Theme update function for mail window
local function applyMailTheme(window)
  if not window or not SF or not SF.theme then return end
  
  -- Update title bar
  if window.titleBar and window.titleText and SF.applyThemeToTitleBar then
    SF.applyThemeToTitleBar(window.titleBar, window.titleText)
  end
  
  -- Update panels
  if SF.theme.colors then
    local p = SF.theme.colors.panel or {0.05, 0.05, 0.05, 0.8}
    local a = SF.theme.colors.accent or {0.2, 0.3, 0.6, 0.8}

    -- left panel = panel color
    if window.leftPanel then
      window.leftPanel:SetCenterColor(p[1], p[2], p[3], p[4])
    end
    
    -- right panel = accent color
    if window.rightPanel then
      window.rightPanel:SetCenterColor(a[1], a[2], a[3], a[4])
    end

    -- progress panel = slightly dimmed panel color
    if window.progressPanel then
      window.progressPanel:SetCenterColor(p[1] * 0.8, p[2] * 0.8, p[3] * 0.8, p[4])
    end
  end
end

-- Mail sending state
local mailState = {
  sending = false,
  paused = false,
  currentIndex = 1,
  recipients = {},
  failedRecipients = {},
  failedDetails = {},
  mailboxOpen = false,
  subject = "",
  body = "",
  kickAfterMail = false,
  selectedGuildId = nil,
}

-- Add function to save failure log to notebook:
local function saveFailureLog()
  if not ScrollkeeperNotebook or not ScrollkeeperNotebook.saveNote then
    d(SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_NO_NOTEBOOK") or "Notebook not available for failure log")
    return
  end
  
  -- Build failure log content
  local logContent = (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_TITLE") or "Mail Send Failure Report") .. "\n"
  logContent = logContent .. string.format((SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_DATE") or "Date: %s"), os.date("%Y-%m-%d %H:%M:%S", GetTimeStamp())) .. "\n"
  logContent = logContent .. string.format((SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_SUBJECT_LINE") or "Subject: %s"), mailState.subject) .. "\n"
  logContent = logContent .. string.format("\n" .. (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_TOTAL_SENT") or "Total Sent: %d"), #mailState.recipients - #mailState.failedRecipients) .. "\n"
  logContent = logContent .. string.format((SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_TOTAL_FAILED") or "Total Failed: %d"), #mailState.failedRecipients) .. "\n\n"
  logContent = logContent .. (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_FAILED_LIST") or "Failed Recipients:") .. "\n"
  logContent = logContent .. (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_SEPARATOR") or string.rep("-", 50)) .. "\n"
  
  for i, failureInfo in ipairs(mailState.failedDetails) do
    logContent = logContent .. string.format("%d. %s - %s\n", i, failureInfo.recipient, failureInfo.reason)
  end
  
  logContent = logContent .. (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_SEPARATOR") or string.rep("-", 50)) .. "\n\n"
  logContent = logContent .. (SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_BODY_HEADER") or "Original Message Body:") .. "\n"
  logContent = logContent .. mailState.body
  
  -- Get localized tags
  local tagMailLog = SF.func._L("ScrollkeeperNotebookMail", "TAG_MAIL_LOG") or "mail-log"
  local tagFailures = SF.func._L("ScrollkeeperNotebookMail", "TAG_FAILURES") or "failures"
  
  -- Save to notebook with localized title
  local logTitleFormat = SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_TITLE_FORMAT") or "Mail Failures - %s"
  local logTitle = string.format(logTitleFormat, os.date("%m/%d %H:%M", GetTimeStamp()))
  local success = ScrollkeeperNotebook:saveNote(logTitle, logContent, {tagMailLog, tagFailures})
  
  if success then
    d(string.format(SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_SAVED") or "Failure log saved: %s", logTitle))
  else
    d(SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_SAVE_FAILED") or "Failed to save failure log")
  end
  
  -- Clear failure details for next send
  mailState.failedDetails = {}
end

-- Check if player has permission to remove members from a guild
local function canKickFromGuild(guildId)
  if not guildId then return false end
  
  local playerIndex = GetPlayerGuildMemberIndex(guildId)
  if not playerIndex then return false end
  
  local _, _, rankIndex = GetGuildMemberInfo(guildId, playerIndex)
  if not rankIndex then return false end
  
  return DoesGuildRankHavePermission(guildId, rankIndex, GUILD_PERMISSION_REMOVE)
end

-- Enhanced mail sending functions
local function sendNextMail()
  if mailState.paused or not mailState.sending or mailState.currentIndex > #mailState.recipients then
    mailState.sending = false
    return
  end
  
  local recipient = mailState.recipients[mailState.currentIndex]
  if not recipient then
    mailState.sending = false
    return
  end
  
  -- Update UI safely
  local progressLabel = GetControl("ScrollkeeperMail_Window_ProgressLabel")
  local recipientLabel = GetControl("ScrollkeeperMail_Window_RecipientLabel")
  if progressLabel then
    progressLabel:SetText("Sending " .. mailState.currentIndex .. "/" .. #mailState.recipients)
  end
  if recipientLabel then
    recipientLabel:SetText("To: " .. recipient)
  end
  
  -- Send mail
  if not mailState.mailboxOpen then
    RequestOpenMailbox()
  else
    QueueMoneyAttachment(0)
    SendMail(recipient, mailState.subject, mailState.body)
  end
end

local function onMailSendSuccess()
  if not mailState.sending then return end
  
  local statusLabel = GetControl("ScrollkeeperMail_Window_StatusLabel")
  if statusLabel then
    statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "SUCCESS") or "Success")
    statusLabel:SetColor(0.4, 1, 0.4, 1)
  end
  
  -- NEW: Kick member if option is enabled
  if mailState.kickAfterMail and mailState.selectedGuildId then
    local recipient = mailState.recipients[mailState.currentIndex]
    if recipient and canKickFromGuild(mailState.selectedGuildId) then
      -- Find the member index
      local memberFound = false
      for i = 1, GetNumGuildMembers(mailState.selectedGuildId) do
        local memberName = GetGuildMemberInfo(mailState.selectedGuildId, i)
        if memberName == recipient then
          GuildRemove(mailState.selectedGuildId, memberName)
          d(string.format(SF.func._L("ScrollkeeperNotebookMail", "MEMBER_KICKED") or "Kicked: %s", recipient))
          memberFound = true
          break
        end
      end
      if not memberFound then
        d(string.format(SF.func._L("ScrollkeeperNotebookMail", "MEMBER_NOT_FOUND") or "Could not find member %s in guild roster", recipient))
      end
    end
  end
  
  mailState.currentIndex = mailState.currentIndex + 1
  
  if mailState.currentIndex <= #mailState.recipients then
    zo_callLater(sendNextMail, MAIL_DELAY)
  else
    -- Completed successfully
    if #mailState.failedRecipients > 0 then
      saveFailureLog()
    end
    mailState.sending = false
    CloseMailbox()
    
    local progressLabel = GetControl("ScrollkeeperMail_Window_ProgressLabel")
    if progressLabel then
      local successCount = #mailState.recipients - #mailState.failedRecipients
      local failCount = #mailState.failedRecipients
      local completedText = SF.func._L("ScrollkeeperNotebookMail", "COMPLETED")
      if completedText and type(completedText) == "string" then
        progressLabel:SetText(string.format(completedText, successCount, failCount))
      else
        progressLabel:SetText(string.format("Completed: %d sent, %d failed", successCount, failCount))
      end
    end
    
    -- Show failed recipients if any
    if #mailState.failedRecipients > 0 then
      d("[ScrollkeeperMail] Failed to send to: " .. table.concat(mailState.failedRecipients, ", "))
    end
    
    -- Update buttons
    local window = GetControl("ScrollkeeperMail_Window")
    if window and window.updateButtons then
      window.updateButtons(false)
    end
  end
end

local function onMailSendFailed(_, reason)
  if not mailState.sending then return end
  
  local recipient = mailState.recipients[mailState.currentIndex]
  
  -- Check if this recipient was already marked as failed (prevent duplicates)
  local alreadyFailed = false
  for _, failedRecip in ipairs(mailState.failedRecipients) do
    if failedRecip == recipient then
      alreadyFailed = true
      break
    end
  end
  
  if recipient and not alreadyFailed then
    table.insert(mailState.failedRecipients, recipient)
  
    -- Store detailed failure information
    local reasonText = "Unknown error"
    if reason == MAIL_SEND_RESULT_RECIPIENT_NOT_FOUND then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "RECIPIENT_NOT_FOUND") or "Recipient not found"
    elseif reason == MAIL_SEND_RESULT_FAIL_MAILBOX_FULL then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "MAILBOX_FULL") or "Mailbox full"
    elseif reason == MAIL_SEND_RESULT_FAIL_IGNORED then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "IGNORED") or "Sender ignored"
    elseif reason == MAIL_SEND_RESULT_FAIL_BLANK_MAIL then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "BLANK_MAIL") or "Blank mail"
    else
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "UNKNOWN_ERROR") or "Unknown error"
    end
    
    table.insert(mailState.failedDetails, {
      recipient = recipient,
      reason = reasonText,
      timestamp = GetTimeStamp(),
      subject = mailState.subject,
      body = mailState.body
    })
    
    -- Log immediately for debugging
    d(string.format("[ScrollkeeperMail] Failed to send to %s: %s", recipient or "unknown", reasonText))
  end
  
  -- Update UI safely with nil checks
  local statusLabel = GetControl("ScrollkeeperMail_Window_StatusLabel")
  if statusLabel then
    local failedText = SF.func._L("ScrollkeeperNotebookMail", "FAILED") or "Failed"
    local reasonText = "Unknown error"
    
    if reason == MAIL_SEND_RESULT_RECIPIENT_NOT_FOUND then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "RECIPIENT_NOT_FOUND") or "Recipient not found"
    elseif reason == MAIL_SEND_RESULT_FAIL_MAILBOX_FULL then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "MAILBOX_FULL") or "Mailbox full"
    elseif reason == MAIL_SEND_RESULT_FAIL_IGNORED then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "IGNORED") or "Sender ignored"
    elseif reason == MAIL_SEND_RESULT_FAIL_BLANK_MAIL then
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "BLANK_MAIL") or "Blank mail"
    else
      reasonText = SF.func._L("ScrollkeeperNotebookMail", "UNKNOWN_ERROR") or "Unknown error"
    end
    
    statusLabel:SetText(failedText .. ": " .. reasonText)
    statusLabel:SetColor(1, 0.4, 0.4, 1)
  end
  
  -- Move to next recipient
  mailState.currentIndex = mailState.currentIndex + 1
  
  if mailState.currentIndex <= #mailState.recipients then
    zo_callLater(sendNextMail, MAIL_DELAY)
  else
    -- Completed with failures - save failure log
    if #mailState.failedRecipients > 0 then
      saveFailureLog()
    end
    
    mailState.sending = false
    CloseMailbox()
    
    local progressLabel = GetControl("ScrollkeeperMail_Window_ProgressLabel")
    if progressLabel then
      local successCount = #mailState.recipients - #mailState.failedRecipients
      local failCount = #mailState.failedRecipients
      local completedText = SF.func._L("ScrollkeeperNotebookMail", "COMPLETED")
      if completedText and type(completedText) == "string" then
        progressLabel:SetText(string.format(completedText, successCount, failCount))
      else
        progressLabel:SetText(string.format("Completed: %d sent, %d failed", successCount, failCount))
      end
    end
    
    local window = GetControl("ScrollkeeperMail_Window")
    if window and window.updateButtons then
      window.updateButtons(false)
    end
  end
end

local function onMailboxOpened()
  mailState.mailboxOpen = true
  if mailState.sending then
    sendNextMail()
  end
end

local function onMailboxClosed()
  mailState.mailboxOpen = false
end

-- Build recipient list with filters
local function buildRecipientList(guildId, rankFilter, goldFilter)
  local recipients = {}
  
  if not guildId then return recipients end
  
  -- Get donation data if available
  local donationData = {}
  local guildName = GetGuildName(guildId)
  
  if SF.Data and SF.Data.getMemberDonationInfo and guildName then
    for i = 1, GetNumGuildMembers(guildId) do
      local displayName = GetGuildMemberInfo(guildId, i)
      if displayName then
        donationData[displayName] = SF.Data.getMemberDonationInfo(guildName, displayName)
      end
    end
  end
  
  for i = 1, GetNumGuildMembers(guildId) do
    local displayName, _, rankIndex = GetGuildMemberInfo(guildId, i)
    
    if displayName and displayName ~= "" and displayName ~= GetUnitName("player") then
      local passesFilter = true
      
      -- Rank filter
      if rankFilter and rankFilter ~= SF.func._L("ScrollkeeperNotebookMail", "ALL_RANKS") then
        local memberRankName = GetFinalGuildRankName(guildId, rankIndex)
        if memberRankName ~= rankFilter then
          passesFilter = false
        end
      end
      
      if passesFilter then
        table.insert(recipients, displayName)
      end
    end
  end
  
  return recipients
end

-- Gold filter recipients from ProvisionMember
local function buildProvisionMemberList(guildId, filterType)
  local recipients = {}
  
  if not guildId then 
    d("[ScrollkeeperMail] No guild ID provided")
    return recipients 
  end
  
  if not SF.ProvisionMember then 
    d("[ScrollkeeperMail] ProvisionMember module not available")
    return recipients 
  end
  
  local guildName = GetGuildName(guildId)
  if not guildName then 
    d("[ScrollkeeperMail] Could not get guild name for ID: " .. tostring(guildId))
    return recipients 
  end
  
  -- Get provisional members from ProvisionMember module
  local accountKey = "ScrollkeeperProvisionMember_" .. GetDisplayName()
  local settings = SF.getModuleSettings(accountKey, {})
  
  if not settings.taggedMembers then
    d("[ScrollkeeperMail] No tagged members found")
    return recipients
  end
  
  if not settings.taggedMembers[guildName] then
    d("[ScrollkeeperMail] No tagged members found for guild: " .. guildName)
    return recipients
  end
  
  for memberName, data in pairs(settings.taggedMembers[guildName]) do
    if data and type(data) == "table" and data.status ~= "promoted" then
      -- Filter by reason if specified
      if not filterType or filterType == SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_ALL") or 
         (filterType == SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_GOLD") and data.reason == "gold") or
         (filterType == SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_RANK") and (data.reason == "rank" or not data.reason)) then
        table.insert(recipients, memberName)
      end
    end
  end
  
  d(string.format("[ScrollkeeperMail] Found %d provisional members for %s (filter: %s)", 
    #recipients, guildName, filterType or "all"))
  
  return recipients
end

-- Template management functions
local function getMailTemplates()
  if not ScrollkeeperNotebook then return {} end
  
  local settings = SF.getModuleSettings("ScrollkeeperNotebook", {})
  local noteList = settings.noteList or {}
  local allMailNotes = noteList["Mail"] or {}
  
  -- Get localized title format for matching
  local logTitleFormat = SF.func._L("ScrollkeeperNotebookMail", "FAILURE_LOG_TITLE_FORMAT") or "Mail Failures - %s"
  local logTitlePrefix = string.match(logTitleFormat, "^(.-)%%s") or "Mail Failures"
  
  -- Filter to only show templates, not failure logs
  local templates = {}
  for title, noteData in pairs(allMailNotes) do
    local isFailureLog = false
    
    -- Method 1: Check if title starts with failure log prefix
    if string.find(title, "^Mail Failures") then
      isFailureLog = true
    end
    
    -- Method 2: Check tags (check for both hardcoded AND any localized versions)
    if noteData.tags then
      for _, tag in ipairs(noteData.tags) do
        -- Check against hardcoded English tags AND any localized versions
        if tag == "failures" or tag == "mail-log" or 
           tag == "ошибки" or tag == "лог-почты" or
           tag == "fehler" or tag == "post-log" or
           tag == "fallos" or tag == "registro-correo" or
           tag == "échecs" or tag == "journal-courrier" or
           tag == "fallimenti" or tag == "registro-posta" or
           tag == "失敗" or tag == "メールログ" then
          isFailureLog = true
          break
        end
      end
    end
    
    -- Only include if NOT a failure log
    if not isFailureLog then
      templates[title] = noteData
    end
  end
  
  return templates
end

local function saveMailTemplate(title, body, tags)
  if not ScrollkeeperNotebook or not ScrollkeeperNotebook.saveNote then return false end
  
  -- Switch notebook to Mail category
  local notebookSettings = SF.getModuleSettings("ScrollkeeperNotebook", {})
  notebookSettings.settings.defaultCategory = "Mail"
  
  -- Get localized tags
  local tagMail = SF.func._L("ScrollkeeperNotebookMail", "TAG_MAIL") or "mail"
  local tagTemplate = SF.func._L("ScrollkeeperNotebookMail", "TAG_TEMPLATE") or "template"
  
  -- Save the template
  return ScrollkeeperNotebook:saveNote(title, body, tags or {tagMail, tagTemplate})
end

-- Create mail preview window
local function createPreviewWindow()
  local windowName = "ScrollkeeperMail_PreviewWindow"
  
  local existingWindow = GetControl(windowName)
  if existingWindow then
    return existingWindow
  end
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(600, 500)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 100, 0)
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
  titleBar:SetDimensions(600, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperNotebookMail", "PREVIEW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeBtn = WINDOW_MANAGER:CreateControl(nil, titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  -- Mock mail UI
  local mailPanel = WINDOW_MANAGER:CreateControl(nil, window, CT_BACKDROP)
  mailPanel:SetDimensions(580, 440)
  mailPanel:SetAnchor(TOPLEFT, window, TOPLEFT, 10, 45)
  mailPanel:SetCenterColor(0.05, 0.05, 0.05, 0.9)
  mailPanel:SetEdgeColor(0.3, 0.3, 0.3, 1)
  mailPanel:SetEdgeTexture("", 1, 1, 0)
  
  -- Subject label
  local subjectHeaderLabel = WINDOW_MANAGER:CreateControl(nil, mailPanel, CT_LABEL)
  subjectHeaderLabel:SetFont("ZoFontGameBold")
  subjectHeaderLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "SUBJECT_LABEL"))
  subjectHeaderLabel:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 10)
  subjectHeaderLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Subject display
  local subjectDisplay = WINDOW_MANAGER:CreateControl(nil, mailPanel, CT_LABEL)
  subjectDisplay:SetFont("ZoFontGame")
  subjectDisplay:SetText("")
  subjectDisplay:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 30)
  subjectDisplay:SetDimensions(560, 30)
  subjectDisplay:SetColor(1, 1, 1, 1)
  
  -- Body label
  local bodyHeaderLabel = WINDOW_MANAGER:CreateControl(nil, mailPanel, CT_LABEL)
  bodyHeaderLabel:SetFont("ZoFontGameBold")
  bodyHeaderLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "BODY_LABEL"))
  bodyHeaderLabel:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 65)
  bodyHeaderLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Body display area
  local bodyBg = WINDOW_MANAGER:CreateControl(nil, mailPanel, CT_BACKDROP)
  bodyBg:SetDimensions(560, 340)
  bodyBg:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 85)
  bodyBg:SetCenterColor(0.0, 0.0, 0.0, 1)
  bodyBg:SetEdgeColor(0.5, 0.5, 0.5, 1)
  bodyBg:SetEdgeTexture("", 1, 1, 0)
  
  -- Body display with color support
  local bodyDisplay = WINDOW_MANAGER:CreateControl(nil, bodyBg, CT_LABEL)
  bodyDisplay:SetFont("ZoFontGame")
  bodyDisplay:SetAnchor(TOPLEFT, bodyBg, TOPLEFT, 10, 10)
  bodyDisplay:SetDimensions(540, 320)
  bodyDisplay:SetVerticalAlignment(TEXT_ALIGN_TOP)
  bodyDisplay:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  
  -- Store references
  window.subjectDisplay = subjectDisplay
  window.bodyDisplay = bodyDisplay
  
  -- Function to update preview
  window.updatePreview = function(subject, body)
    if subjectDisplay then
      subjectDisplay:SetText(subject or "")
    end
    if bodyDisplay then
      -- Process color codes
      local processedBody = body or ""
      -- ESO uses |cRRGGBB for color codes
      bodyDisplay:SetText(processedBody)
    end
  end
  
  -- Theme the preview window
  window.titleBar = titleBar
  window.titleText = title
  window.updateTheme = function()
    if SF and SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end
  
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperMail_PreviewWindow", window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)
  
  SF.addOrnateFrame(window)
  return window
end

-- Enhanced window creation with proper dropdown integration
local function createMailWindow()
  local windowName = "ScrollkeeperMail_Window"
  
  -- Check if window already exists
  local existingWindow = GetControl(windowName)
  if existingWindow then
    return existingWindow
  end
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(900, 700)
  window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  window:SetMovable(true)
  window:SetMouseEnabled(true)
  window:SetClampedToScreen(true)
  window:SetHidden(true)
  
  -- Background
  local bg = WINDOW_MANAGER:CreateControl(windowName .. "_BG", window, CT_BACKDROP)
  bg:SetAnchorFill()
  bg:SetCenterColor(0.1, 0.1, 0.1, 0.95)
  bg:SetEdgeColor(0.4, 0.4, 0.4, 1)
  bg:SetEdgeTexture("", 2, 2, 1)
  
  -- Title bar
  local titleBar = WINDOW_MANAGER:CreateControl(windowName .. "_TitleBar", window, CT_BACKDROP)
  titleBar:SetDimensions(900, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  local title = WINDOW_MANAGER:CreateControl(windowName .. "_Title", titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperNotebookMail", "WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  local closeBtn = WINDOW_MANAGER:CreateControl(windowName .. "_Close", titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -10, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetHandler("OnClicked", function() window:SetHidden(true) end)
  
  -- Left panel for templates and filters
  local leftPanel = WINDOW_MANAGER:CreateControl(windowName .. "_LeftPanel", window, CT_BACKDROP)
  leftPanel:SetDimensions(280, 620)
  leftPanel:SetAnchor(TOPLEFT, window, TOPLEFT, 5, 40)
  leftPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  leftPanel:SetEdgeColor(0.3, 0.3, 0.3, 1)
  leftPanel:SetEdgeTexture("", 1, 1, 0)
  
  window.leftPanel = leftPanel
  
  -- Template section
  local templateLabel = WINDOW_MANAGER:CreateControl(windowName .. "_TemplateLabel", leftPanel, CT_LABEL)
  templateLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  templateLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "MAIL_TEMPLATES"))
  templateLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 5)
  templateLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Template dropdown
  local templateDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_TemplateDropdown", leftPanel, "ZO_ComboBox")
  templateDropdown:SetDimensions(260, 30)
  templateDropdown:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 25)
  
  local templateCombo = ZO_ComboBox_ObjectFromContainer(templateDropdown)
  templateCombo:SetSortsItems(false)
  templateCombo:SetFont("ZoFontGame")
  
  -- Populate templates
  local function updateTemplateDropdown()
    templateCombo:ClearItems()
    
    local defaultEntry = templateCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "SELECT_TEMPLATE"), function() end)
    templateCombo:AddItem(defaultEntry)
    
    local templates = getMailTemplates()
    for title, template in pairs(templates) do
      local entry = templateCombo:CreateItemEntry(title, function()
        local subjectInput = GetControl(windowName .. "_SubjectInput")
        local bodyInput = GetControl(windowName .. "_BodyInput")
        if subjectInput then subjectInput:SetText(title) end
        if bodyInput then bodyInput:SetText(template.body or "") end
      end)
      templateCombo:AddItem(entry)
    end
    
    templateCombo:SelectItem(defaultEntry)
  end
  
  updateTemplateDropdown()
  
  -- Guild selection
  local guildLabel = WINDOW_MANAGER:CreateControl(windowName .. "_GuildLabel", leftPanel, CT_LABEL)
  guildLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  guildLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "GUILD_LABEL"))
  guildLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 65)
  guildLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local guildDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_GuildDropdown", leftPanel, "ZO_ComboBox")
  guildDropdown:SetDimensions(260, 30)
  guildDropdown:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 85)
  
  local guildCombo = ZO_ComboBox_ObjectFromContainer(guildDropdown)
  guildCombo:SetSortsItems(false)
  guildCombo:SetFont("ZoFontGame")
  
  -- Track selected guild
  window.selectedGuildId = nil
  
  -- Populate guilds
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    if guildName then
      local entry = guildCombo:CreateItemEntry(guildName, function()
        window.selectedGuildId = guildId
        -- Update rank dropdown when guild changes
        local rankDropdown = GetControl(windowName .. "_RankDropdown")
        if rankDropdown and rankDropdown.m_comboBox then
          local rankCombo = rankDropdown.m_comboBox
          rankCombo:ClearItems()
          
          local allEntry = rankCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "ALL_RANKS"), function() end)
          rankCombo:AddItem(allEntry)
          rankCombo:SelectItem(allEntry)
          
          for rankId = 1, GetNumGuildRanks(guildId) do
            local rankName = GetFinalGuildRankName(guildId, rankId)
            if rankName then
              local rankEntry = rankCombo:CreateItemEntry(rankName, function() end)
              rankCombo:AddItem(rankEntry)
            end
          end
        end
      end)
      guildCombo:AddItem(entry)
    end
  end
  
  -- Select first guild by default
  if GetNumGuilds() > 0 then
    local firstGuildId = GetGuildId(1)
    local firstGuildName = GetGuildName(firstGuildId)
    if firstGuildName then
      guildCombo:SetSelectedItem(firstGuildName)
      window.selectedGuildId = firstGuildId
    end
  end
  
  -- Rank filter
  local rankLabel = WINDOW_MANAGER:CreateControl(windowName .. "_RankLabel", leftPanel, CT_LABEL)
  rankLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  rankLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "RANK_FILTER"))
  rankLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 125)
  rankLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local rankDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_RankDropdown", leftPanel, "ZO_ComboBox")
  rankDropdown:SetDimensions(260, 30)
  rankDropdown:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 145)
  
  local rankCombo = ZO_ComboBox_ObjectFromContainer(rankDropdown)
  rankCombo:SetSortsItems(false)
  rankCombo:SetFont("ZoFontGame")
  
  -- Initialize rank dropdown for first guild
  if window.selectedGuildId then
    local allEntry = rankCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "ALL_RANKS"), function() end)
    rankCombo:AddItem(allEntry)
    rankCombo:SelectItem(allEntry)
    
    for rankId = 1, GetNumGuildRanks(window.selectedGuildId) do
      local rankName = GetFinalGuildRankName(window.selectedGuildId, rankId)
      if rankName then
        local entry = rankCombo:CreateItemEntry(rankName, function() end)
        rankCombo:AddItem(entry)
      end
    end
  end
  
  -- Kick after mail option
  local kickLabel = WINDOW_MANAGER:CreateControl(windowName .. "_KickLabel", leftPanel, CT_LABEL)
  kickLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  kickLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "KICK_AFTER_MAIL"))
  kickLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 297)
  kickLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local kickDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_KickDropdown", leftPanel, "ZO_ComboBox")
  kickDropdown:SetDimensions(260, 30)
  kickDropdown:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 317)
  
  local kickCombo = ZO_ComboBox_ObjectFromContainer(kickDropdown)
  kickCombo:SetSortsItems(false)
  kickCombo:SetFont("ZoFontGame")
  
  -- Add options
  local noKickEntry = kickCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "KICK_NO"), function() 
    mailState.kickAfterMail = false 
  end)
  kickCombo:AddItem(noKickEntry)
  
  local yesKickEntry = kickCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "KICK_YES"), function() 
    -- Check permissions before enabling
    if window.selectedGuildId and canKickFromGuild(window.selectedGuildId) then
      mailState.kickAfterMail = true
    else
      mailState.kickAfterMail = false
      kickCombo:SelectItem(noKickEntry)
      d(SF.func._L("ScrollkeeperNotebookMail", "KICK_NO_PERMISSION") or "You don't have permission to remove members from this guild")
    end
  end)
  kickCombo:AddItem(yesKickEntry)
  
  kickCombo:SelectItem(noKickEntry)
  
  -- Provisional Members section
  local provisionLabel = WINDOW_MANAGER:CreateControl(windowName .. "_ProvisionLabel", leftPanel, CT_LABEL)
  provisionLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  provisionLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PROVISIONAL_LABEL"))
  provisionLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 185)
  provisionLabel:SetColor(0.8, 0.8, 0.8, 1)

  -- Provision filter dropdown
  local provisionDropdown = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_ProvisionDropdown", leftPanel, "ZO_ComboBox")
  provisionDropdown:SetDimensions(260, 30)
  provisionDropdown:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 205)

  local provisionCombo = ZO_ComboBox_ObjectFromContainer(provisionDropdown)
  provisionCombo:SetSortsItems(false)
  provisionCombo:SetFont("ZoFontGame")

  -- Add provision filter options
  local allEntry = provisionCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "ALL_PROVISIONAL"), function() end)
  provisionCombo:AddItem(allEntry)

  local goldEntry = provisionCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "GOLD_ONLY"), function() end)
  provisionCombo:AddItem(goldEntry)

  local rankEntry = provisionCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebookMail", "RANK_ONLY"), function() end)
  provisionCombo:AddItem(rankEntry)

  provisionCombo:SelectItem(allEntry)

  -- Use Provisional button
  local useProvisionBtn = WINDOW_MANAGER:CreateControl(windowName .. "_UseProvisionBtn", leftPanel, CT_BUTTON)
  useProvisionBtn:SetDimensions(180, 27)
  useProvisionBtn:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 45, 255)
  local useProvisionBtnBg = WINDOW_MANAGER:CreateControl(nil, useProvisionBtn, CT_BACKDROP)
  useProvisionBtnBg:SetAnchorFill(useProvisionBtn)
  ApplyTemplateToControl(useProvisionBtnBg, "ZO_DefaultBackdrop")
  if SF.applyThemeColor then
    SF.applyThemeColor(useProvisionBtnBg, "accent")
  end

  local useProvisionLabel = WINDOW_MANAGER:CreateControl(nil, useProvisionBtn, CT_LABEL)
  useProvisionLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  useProvisionLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "USE_PROVISIONAL"))
  useProvisionLabel:SetAnchor(CENTER, useProvisionBtn, CENTER, 0, 0)
  useProvisionLabel:SetColor(1, 1, 1, 1)
  useProvisionLabel:SetDimensionConstraints(0, 0, 170, 25)

  useProvisionBtn:SetHandler("OnClicked", function()
    if not window.selectedGuildId then
      local statusLabel = GetControl(windowName .. "_StatusLabel")
      if statusLabel then
        statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_GUILD"))
        statusLabel:SetColor(1, 0.4, 0.4, 1)
      end
      return
    end
    
    local selectedFilter = provisionCombo:GetSelectedItem()
    local filterType = SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_ALL")
    if selectedFilter == SF.func._L("ScrollkeeperNotebookMail", "GOLD_ONLY") then
      filterType = SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_GOLD")
    elseif selectedFilter == SF.func._L("ScrollkeeperNotebookMail", "RANK_ONLY") then
      filterType = SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_RANK")
    end
    
    local provisionRecipients = buildProvisionMemberList(window.selectedGuildId, filterType)
    
    if #provisionRecipients > 0 then
      -- Store the recipients for sending
      window.provisionRecipients = provisionRecipients
      
      local recipientCountLabel = GetControl(windowName .. "_RecipientCount")
      if recipientCountLabel then
        recipientCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "RECIPIENTS"), #provisionRecipients))
      end
      
      local statusLabel = GetControl(windowName .. "_StatusLabel")
      if statusLabel then
        statusLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "PROVISIONAL_SELECTED"), #provisionRecipients))
        statusLabel:SetColor(0.4, 1, 0.4, 1)
      end
      
      -- Auto-fill a template subject for dues reminders
      if filterType == SF.func._L("ScrollkeeperNotebookMail", "PROVISION_FILTER_GOLD") then
        local subjectInput = GetControl(windowName .. "_SubjectInput")
        if subjectInput and window.selectedGuildId then
          local guildName = GetGuildName(window.selectedGuildId)
          if guildName then
            subjectInput:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "DUES_REMINDER_SUBJECT"), guildName))
          end
        end
      end
      
    else
      local statusLabel = GetControl(windowName .. "_StatusLabel")
      if statusLabel then
        statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_PROVISIONAL"))
        statusLabel:SetColor(1, 0.8, 0.4, 1)
      end
    end
  end)

  -- Right panel for mail composition
  local rightPanel = WINDOW_MANAGER:CreateControl(windowName .. "_RightPanel", window, CT_BACKDROP)
  rightPanel:SetDimensions(600, 620)
  rightPanel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -5, 40)
  rightPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  rightPanel:SetEdgeColor(0.3, 0.3, 0.3, 1)
  rightPanel:SetEdgeTexture("", 1, 1, 0)
  
  window.rightPanel = rightPanel
  
  -- Subject input with character count
  local subjectLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SubjectLabel", rightPanel, CT_LABEL)
  subjectLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  subjectLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "SUBJECT_LABEL"))
  subjectLabel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 10, 10)
  subjectLabel:SetColor(1, 1, 1, 1)
  
  local subjectCountLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SubjectCount", rightPanel, CT_LABEL)
  subjectCountLabel:SetFont("ZoFontGameSmall")
  subjectCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "CHAR_COUNT"), 0, 100))
  subjectCountLabel:SetAnchor(TOPRIGHT, rightPanel, TOPRIGHT, -10, 10)
  subjectCountLabel:SetColor(1, 1, 1, 1)
  
  local subjectBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_SubjectBg", rightPanel, "ZO_EditBackdrop")
  subjectBg:SetDimensions(580, 30)
  subjectBg:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 10, 30)
  
  local subjectInput = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_SubjectInput", subjectBg, "ZO_DefaultEditForBackdrop")
  subjectInput:SetMaxInputChars(100)
  
  -- Subject character count handler
  subjectInput:SetHandler("OnTextChanged", function()
    local text = subjectInput:GetText()
    local count = string.len(text)
    subjectCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "CHAR_COUNT"), count, 100))
    if count > 100 then
      subjectCountLabel:SetColor(1, 0.4, 0.4, 1)
    else
      subjectCountLabel:SetColor(1, 1, 1, 1)
    end
  end)
 
  -- Body input with character count
  local bodyLabel = WINDOW_MANAGER:CreateControl(windowName .. "_BodyLabel", rightPanel, CT_LABEL)
  bodyLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  bodyLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "BODY_LABEL"))
  bodyLabel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 10, 70)
  bodyLabel:SetColor(1, 1, 1, 1)
  
  local bodyCountLabel = WINDOW_MANAGER:CreateControl(windowName .. "_BodyCount", rightPanel, CT_LABEL)
  bodyCountLabel:SetFont("ZoFontGameSmall")
  bodyCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "CHAR_COUNT"), 0, 700))
  bodyCountLabel:SetAnchor(TOPRIGHT, rightPanel, TOPRIGHT, -10, 70)
  bodyCountLabel:SetColor(1, 1, 1, 1)
  
  local bodyBg = WINDOW_MANAGER:CreateControl(windowName .. "_BodyBg", rightPanel, CT_BACKDROP)
  bodyBg:SetDimensions(580, 350)
  bodyBg:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 10, 90)
  bodyBg:SetCenterColor(0.0, 0.0, 0.0, 1)
  bodyBg:SetEdgeColor(0.5, 0.5, 0.5, 1)
  bodyBg:SetEdgeTexture("", 1, 1, 0)
  
  local bodyInput = WINDOW_MANAGER:CreateControl(windowName .. "_BodyInput", bodyBg, CT_EDITBOX)
  bodyInput:SetAnchor(TOPLEFT, bodyBg, TOPLEFT, 5, 5)
  bodyInput:SetDimensions(570, 340)
  bodyInput:SetFont("ZoFontGame")
  bodyInput:SetColor(1, 1, 1, 1)
  bodyInput:SetMaxInputChars(700)
  bodyInput:SetMultiLine(true)
  bodyInput:SetEditEnabled(true)
  bodyInput:SetMouseEnabled(true)
  bodyInput:SetHandler("OnMouseUp", function(self) self:TakeFocus() end)
  
  -- Body character count handler
  bodyInput:SetHandler("OnTextChanged", function()
    local text = bodyInput:GetText()
    local count = string.len(text)
    bodyCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "CHAR_COUNT"), count, 700))
    if count > 700 then
      bodyCountLabel:SetColor(1, 0.4, 0.4, 1)
    elseif count > 600 then
      bodyCountLabel:SetColor(1, 0.8, 0.4, 1)
    else
      bodyCountLabel:SetColor(1, 1, 1, 1)
    end
  end)
  
  -- Progress panel
  local progressPanel = WINDOW_MANAGER:CreateControl(windowName .. "_ProgressPanel", rightPanel, CT_BACKDROP)
  progressPanel:SetDimensions(580, 100)
  progressPanel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 10, 450)
  progressPanel:SetCenterColor(0.1, 0.1, 0.1, 0.8)
  progressPanel:SetEdgeColor(0.75, 0.75, 0.75, 1)
  progressPanel:SetEdgeTexture("", 1, 1, 0)
  
  window.progressPanel = progressPanel
  
  local progressLabel = WINDOW_MANAGER:CreateControl(windowName .. "_ProgressLabel", progressPanel, CT_LABEL)
  progressLabel:SetFont("ZoFontGame")
  progressLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "READY_TO_SEND"))
  progressLabel:SetAnchor(TOPLEFT, progressPanel, TOPLEFT, 5, 5)
  progressLabel:SetColor(1, 1, 1, 1)
  
  local recipientLabel = WINDOW_MANAGER:CreateControl(windowName .. "_RecipientLabel", progressPanel, CT_LABEL)
  recipientLabel:SetFont("ZoFontGameSmall")
  recipientLabel:SetText("")
  recipientLabel:SetAnchor(TOPLEFT, progressPanel, TOPLEFT, 5, 25)
  recipientLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local statusLabel = WINDOW_MANAGER:CreateControl(windowName .. "_StatusLabel", progressPanel, CT_LABEL)
  statusLabel:SetFont("ZoFontGameSmall")
  statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "STATUS_READY"))
  statusLabel:SetAnchor(TOPLEFT, progressPanel, TOPLEFT, 5, 45)
  statusLabel:SetColor(0.6, 1, 0.6, 1)
  
  local recipientCountLabel = WINDOW_MANAGER:CreateControl(windowName .. "_RecipientCount", progressPanel, CT_LABEL)
  recipientCountLabel:SetFont("ZoFontGameSmall")
  recipientCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "RECIPIENTS"), 0))
  recipientCountLabel:SetAnchor(TOPLEFT, progressPanel, TOPLEFT, 5, 65)
  recipientCountLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Button panel - horizontal row layout
  local buttonPanel = WINDOW_MANAGER:CreateControl(windowName .. "_ButtonPanel", rightPanel, CT_CONTROL)
  buttonPanel:SetDimensions(580, 70)
  buttonPanel:SetAnchor(BOTTOM, rightPanel, BOTTOM, 0, -5)

  -- Save template button (leftmost)
  local saveBtn = WINDOW_MANAGER:CreateControl(windowName .. "_SaveBtn", buttonPanel, CT_BUTTON)
  saveBtn:SetDimensions(32, 32)
  saveBtn:SetAnchor(LEFT, buttonPanel, LEFT, 55, -10)
  saveBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_up.dds")
  saveBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_down.dds")
  saveBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_over.dds")
  
  -- Save button label placed BELOW the button
  local saveLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SaveLabel", buttonPanel, CT_LABEL)
  saveLabel:SetAnchor(TOP, saveBtn, BOTTOM, 0, 2)
  saveLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  saveLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "SAVE_TEMPLATE"))
  saveLabel:SetColor(1, 1, 1, 1)

  
  saveBtn:SetHandler("OnClicked", function()
    local subject = subjectInput:GetText()
    local body = bodyInput:GetText()
    
    if subject and subject ~= "" and body and body ~= "" then
      if saveMailTemplate(subject, body, {"mail", "template"}) then
        updateTemplateDropdown()
        statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "TEMPLATE_SAVED"))
        statusLabel:SetColor(0.4, 1, 0.4, 1)
      else
        statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "TEMPLATE_FAILED"))
        statusLabel:SetColor(1, 0.4, 0.4, 1)
      end
    else
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NEED_SUBJECT_BODY"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
    end
  end)
  
  -- Preview recipients button (center)
  local previewBtn = WINDOW_MANAGER:CreateControl(windowName .. "_PreviewBtn", buttonPanel, CT_BUTTON)
  previewBtn:SetDimensions(32, 32)
  previewBtn:SetAnchor(LEFT, saveBtn, RIGHT, 110, 0)
  previewBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_friends_up.dds")
  previewBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_friends_down.dds")
  previewBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tabicon_friends_over.dds")
  
  local previewLabel = WINDOW_MANAGER:CreateControl(windowName .. "_PreviewLabel", buttonPanel, CT_LABEL)
  previewLabel:SetAnchor(TOP, previewBtn, BOTTOM, 0, 2)
  previewLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  previewLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PREVIEW_RECIPIENTS"))
  previewLabel:SetColor(1, 1, 1, 1)

  
  previewBtn:SetHandler("OnClicked", function()
    if not window.selectedGuildId then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_GUILD"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    local rankFilter = rankCombo:GetSelectedItem()
    local recipients = buildRecipientList(window.selectedGuildId, rankFilter, window.goldFilter)
    
    recipientCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "RECIPIENTS"), #recipients))
    if #recipients > 0 then
      statusLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebookMail", "RECIPIENTS_FOUND"), #recipients))
      statusLabel:SetColor(0.4, 1, 0.4, 1)
    else
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_MATCH_FILTERS"))
      statusLabel:SetColor(1, 0.8, 0.4, 1)
    end
  end)
  
  -- Mail preview button
  local mailPreviewBtn = WINDOW_MANAGER:CreateControl(windowName .. "_MailPreviewBtn", buttonPanel, CT_BUTTON)
  mailPreviewBtn:SetDimensions(32, 32)
  mailPreviewBtn:SetAnchor(LEFT, previewBtn, RIGHT, 110, 0)
  mailPreviewBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_up.dds")
  mailPreviewBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_down.dds")
  mailPreviewBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_over.dds")
  
  local mailPreviewLabel = WINDOW_MANAGER:CreateControl(windowName .. "_MailPreviewLabel", buttonPanel, CT_LABEL)
  mailPreviewLabel:SetAnchor(TOP, mailPreviewBtn, BOTTOM, 0, 2)
  mailPreviewLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  mailPreviewLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PREVIEW_MAIL"))
  mailPreviewLabel:SetColor(1, 1, 1, 1)
  
  mailPreviewBtn:SetHandler("OnClicked", function()
    local subject = subjectInput:GetText()
    local body = bodyInput:GetText()
    
    if not subject or subject == "" then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_SUBJECT"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    if not body or body == "" then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_BODY"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    local previewWindow = createPreviewWindow()
    if previewWindow then
      previewWindow.updatePreview(subject, body)
      previewWindow:SetHidden(false)
    end
  end)
  
  -- Send button (rightmost)
  local sendBtn = WINDOW_MANAGER:CreateControl(windowName .. "_SendBtn", buttonPanel, CT_BUTTON)
  sendBtn:SetDimensions(32, 32)
  sendBtn:SetAnchor(LEFT, mailPreviewBtn, RIGHT, 110, 0)
  sendBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_up.dds")
  sendBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_down.dds")
  sendBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_over.dds")
  
  -- Send button label positioned BELOW button with proper spacing  
  local sendLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SendLabel", buttonPanel, CT_LABEL)
  sendLabel:SetAnchor(TOP, sendBtn, BOTTOM, 0, 2)
  sendLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  sendLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "SEND_MAIL"))
  sendLabel:SetColor(1, 1, 1, 1)

  
  -- Enhanced send functionality with provisional member support
  sendBtn:SetHandler("OnClicked", function()
    local subject = subjectInput:GetText()
    local body = bodyInput:GetText()
    
    if not subject or subject == "" then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_SUBJECT"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    if not body or body == "" then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_BODY"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    if not window.selectedGuildId then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_GUILD"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    local recipients = {}
    
    -- Check if we're using provisional members
    if window.provisionRecipients and #window.provisionRecipients > 0 then
      recipients = window.provisionRecipients
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "USING_PROVISIONAL"))
    else
      -- Use regular filters
      local rankFilter = rankCombo:GetSelectedItem()
      recipients = buildRecipientList(window.selectedGuildId, rankFilter, window.goldFilter)
    end
    
    if #recipients == 0 then
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "NO_RECIPIENTS"))
      statusLabel:SetColor(1, 0.4, 0.4, 1)
      return
    end
    
    -- Start sending
    mailState.sending = true
    mailState.paused = false
    mailState.currentIndex = 1
    mailState.recipients = recipients
    mailState.failedRecipients = {}
    mailState.subject = subject
    mailState.body = body
	mailState.selectedGuildId = window.selectedGuildId
    
    statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "STARTING"))
    statusLabel:SetColor(0.4, 0.4, 1, 1)
    
    -- Clear provisional recipients after use
    window.provisionRecipients = nil
    
    -- Update buttons
    if window.updateButtons then
      window.updateButtons(true)
    end
    
    -- Start the sending process
    if mailState.mailboxOpen then
      -- Mailbox already open, start immediately
      sendNextMail()
    else
      -- Need to open mailbox first
      RequestOpenMailbox()
    end
  end)
  
  -- Pause/Resume button (replaces send when active)
  local pauseBtn = WINDOW_MANAGER:CreateControl(windowName .. "_PauseBtn", buttonPanel, CT_BUTTON)
  pauseBtn:SetDimensions(32, 32)
  pauseBtn:SetAnchor(LEFT, mailPreviewBtn, RIGHT, 110, 0)
  pauseBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tutorial_idexicon_gettingstarted_up.dds")
  pauseBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tutorial_idexicon_gettingstarted_down.dds")
  pauseBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tutorial_idexicon_gettingstarted_over.dds")
  pauseBtn:SetHidden(true)
  
  local pauseLabel = WINDOW_MANAGER:CreateControl(windowName .. "_PauseLabel", buttonPanel, CT_LABEL)
  pauseLabel:SetAnchor(TOP, pauseBtn, BOTTOM, 0, 2)
  pauseLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  pauseLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PAUSE"))
  pauseLabel:SetColor(1, 1, 1, 1)
  pauseLabel:SetHidden(true)
  
  pauseBtn:SetHandler("OnClicked", function()
    if mailState.sending and not mailState.paused then
      mailState.paused = true
      pauseLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "RESUME"))
      statusLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PAUSED"))
      statusLabel:SetColor(1, 0.8, 0.4, 1)
    elseif mailState.paused then
      mailState.paused = false
      pauseLabel:SetText(SF.func._L("ScrollkeeperNotebookMail", "PAUSE"))
      sendNextMail()
    end
  end)
  
  -- Show/hide pause button based on sending state
  window.updateButtons = function(sending)
    sendBtn:SetHidden(sending)
    sendLabel:SetHidden(sending)
    pauseBtn:SetHidden(not sending)
    pauseLabel:SetHidden(not sending)
  end
  
  -- Store theme references
  window.titleBar = titleBar
  window.titleText = title
  
  -- Register theme update callback
  window.updateTheme = function()
    applyMailTheme(window)
  end
  
  -- Register with framework
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperMail_Window", window.updateTheme)
  end
  
  -- Apply initial theme
  zo_callLater(function()
    applyMailTheme(window)
  end, 100)
  
  SF.addOrnateFrame(window)
  return window
end

-- Slash command registration
local function registerSlashCommand()
  SLASH_COMMANDS["/sgtmail"] = function()
    local settings = getSettings()
    if not settings.enabled then
      d("[ScrollkeeperNotebookMail] Mail module is disabled")
      return
    end

    local window = GetControl("ScrollkeeperMail_Window")
    if not window then
      window = createMailWindow()
      if not window then
        d("[ScrollkeeperNotebookMail] ERROR: Failed to create mail window")
        return
      end
    end

    window:SetHidden(not window:IsHidden())
  end
end

-- Build LAM2 controls with per-guild settings
local function buildControls()
  local settings = getSettings()
  local controls = {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperNotebookMail", "SUBMENU_NAME"),
      controls = {
        { 
          type = "description", 
          text = SF.func._L("ScrollkeeperNotebookMail", "DESCRIPTION"),
        },
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperNotebookMail", "ENABLE_MAIL"),
          tooltip = SF.func._L("ScrollkeeperNotebookMail", "ENABLE_MAIL_TIP"),
          getFunc = function() return settings.enabled end,
          setFunc = function(value)
            settings.enabled = value
            if value then
              registerSlashCommand()
            end
          end,
          default = defaults.enabled,
        },
        {
          type = "button",
          name = SF.func._L("ScrollkeeperNotebookMail", "OPEN_MAIL"),
          tooltip = SF.func._L("ScrollkeeperNotebookMail", "OPEN_MAIL_TIP"),
          func = function()
            if SLASH_COMMANDS["/sgtmail"] then
              SLASH_COMMANDS["/sgtmail"]()
            end
          end,
          width = "half",
        },
      }
    }
  }

  return controls
end

-- Initialize
local function initialize()
  if _addon._initialized then
    return
  end
  
  -- Register controls
  if SF_Set and SF_Set.RegisterModuleOptions then
    local settings = getSettings()
    if settings then
      local controls = buildControls()
      SF_Set.RegisterModuleOptions(_addon.Name, controls)
    end
  end

  local settings = getSettings()
  if settings.enabled then
    registerSlashCommand()
  end
  
  -- Register mail events
  EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_MAIL_SEND_SUCCESS, onMailSendSuccess)
  EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_MAIL_SEND_FAILED, onMailSendFailed)
  EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_MAIL_OPEN_MAILBOX, onMailboxOpened)
  EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_MAIL_CLOSE_MAILBOX, onMailboxClosed)
  
  _addon._initialized = true
end

-- Register for proper initialization
EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  initialize()
end)

CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)