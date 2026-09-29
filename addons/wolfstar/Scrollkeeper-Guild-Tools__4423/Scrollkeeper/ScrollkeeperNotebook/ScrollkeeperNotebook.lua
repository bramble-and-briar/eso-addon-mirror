-- Scrollkeeper Guild Tools Addon
-- ScrollkeeperNotebook

-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

local LibTextFilter = LibTextFilter

if type(SF) ~= "table" or not SF.initAddon then
  d(SF.func._L("ScrollkeeperNotebook", "ERROR_FRAMEWORK_MISSING"))
  return
end

-- Initialize module
Scrollkeeper.Notebook = Scrollkeeper.Notebook or { Name = "ScrollkeeperNotebook" }
local _addon = Scrollkeeper.Notebook

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperNotebook = Scrollkeeper.Notebook

if type(SF) ~= "table" or not SF.initAddon then
  d(SF.func._L("ScrollkeeperNotebook", "ERROR_FRAMEWORK_MISSING"))
  return
end

ScrollkeeperNotebook = ScrollkeeperNotebook or _addon

-- Prevent multiple initialization
if _addon._initialized then
  d(SF.func._L("ScrollkeeperNotebook", "ERROR_ALREADY_INIT"))
  return
end

-- Settings defaults
local defaults = {
  noteList = {},  -- This will store: noteList[categoryName][noteTitle] = noteData
  settings = {
    enabled            = true,
    enableSearchFilter = true,
    lockWindow         = false,
    defaultCategory    = SF.func._L("ScrollkeeperNotebook", "CAT_GENERAL"),
  },
}

-- Get settings using unified system
local function getSettings()
  return SF.getModuleSettings(_addon.Name, defaults)
end

-- Guild mail compose injection
local gmInjected = false

local ZOS_GM_SUBJECT_FIELD = "ZO_GuildMailManagementSendSubjectField"
local ZOS_GM_BODY_FIELD    = "ZO_GuildMailManagementSendBodyField"
local ZOS_GM_COMPOSE_ROOT  = "ZO_GuildMailManagementSend"
local GUILD_MAIL_MAX_SUBJECT = 45

-- 🔁 Utilities
local function parseTags(tagString)
  if not tagString then return {} end
  local tags = {}
  for tag in string.gmatch(tagString, "[^,%s]+") do
    table.insert(tags, tag)
  end
  return tags
end

local function getCategory()
  local settings = getSettings()
  return settings.settings.defaultCategory or SF.func._L("ScrollkeeperNotebook", "CAT_GENERAL")
end

-- Note management with proper filtering
local currentNoteList = {}
local filteredNotes = {}

-- Forward declaration
local updateNoteDropdown

-- Enhanced loadNoteIntoEditor function
local function loadNoteIntoEditor(note)
  if not note then 
    note = {
      title = SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"), 
      body = "", 
      tags = {}
    }
  end
  
  local titleInput = GetControl("ScrollkeeperNotebook_TitleInput")
  local bodyInput = GetControl("ScrollkeeperNotebook_BodyInput")
  local tagInput = GetControl("ScrollkeeperNotebook_TagInput")
  
  if titleInput then 
    titleInput:SetText(note.title or "")
    titleInput:LoseFocus()
    -- Trigger character count update
    if titleInput:GetHandler("OnTextChanged") then
      titleInput:GetHandler("OnTextChanged")()
    end
  end
  if bodyInput then 
    bodyInput:SetText(note.body or "")
    bodyInput:LoseFocus()
    -- Resize content and scroll back to top
    zo_callLater(function()
      local win = GetControl("ScrollkeeperNotebook_Window")
      if win and win.resizeBodyToContent then win.resizeBodyToContent() end
    end, 50)
    if bodyInput:GetHandler("OnTextChanged") then
      bodyInput:GetHandler("OnTextChanged")()
    end
  end
  if tagInput then 
    local tagString = ""
    if note.tags and type(note.tags) == "table" then
      tagString = table.concat(note.tags, ", ")
    end
    tagInput:SetText(tagString)
    tagInput:LoseFocus()
  end
end

-- Enhanced refreshNoteList function
local function refreshNoteList()
  local settings = getSettings()
  local category = getCategory()
  
  -- Determine if we're searching all categories
  local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
  local searchAllCategories = (category == allCategoriesKey)
  
  -- Build the note list to search
  if searchAllCategories then
    -- Combine all categories
    currentNoteList = {}
    for cat, notes in pairs(settings.noteList) do
      for title, note in pairs(notes) do
        -- Store with category info for display
        local noteWithCat = {}
        for k, v in pairs(note) do
          noteWithCat[k] = v
        end
        noteWithCat.category = cat
        currentNoteList[title] = noteWithCat
      end
    end
  else
    currentNoteList = settings.noteList[category] or {}
  end
  
  -- Apply search filter if enabled
  local searchTerm = ""
  local searchInput = GetControl("ScrollkeeperNotebook_SearchInput")
  if searchInput then
    searchTerm = searchInput:GetText():lower()
  end
  
  filteredNotes = {}
  for title, note in pairs(currentNoteList) do
    local matches = true
    
    if settings.settings.enableSearchFilter and searchTerm ~= "" then
      if LibTextFilter then
        local tagText = ""
        if note.tags then
          tagText = table.concat(note.tags, " "):lower()
        end
        local searchText = title:lower() .. " " .. (note.body or ""):lower() .. " " .. tagText
        matches = LibTextFilter:Filter(searchText, searchTerm)
      else
        local titleMatch = title:lower():find(searchTerm, 1, true)
        local bodyMatch = (note.body or ""):lower():find(searchTerm, 1, true)
        local tagMatch = false

        if note.tags then
          for _, tag in ipairs(note.tags) do
            if tag:lower():find(searchTerm, 1, true) then
              tagMatch = true
              break
            end
          end
        end

        matches = titleMatch or bodyMatch or tagMatch
      end
    end
    
    if matches then
      table.insert(filteredNotes, {title = title, note = note})
    end
  end
  
  -- Sort by title
  table.sort(filteredNotes, function(a, b) return a.title < b.title end)
  
  -- Update count label
  local countLabel = GetControl("ScrollkeeperNotebook_CountLabel")
  if countLabel then
    local totalNotes = 0
    for _ in pairs(currentNoteList) do
      totalNotes = totalNotes + 1
    end
    countLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTES_COUNT"), #filteredNotes, totalNotes))
  end
  
  -- Update dropdown
  updateNoteDropdown()
end

-- Update dropdown with filtered notes
updateNoteDropdown = function()
  local dropdownControl = GetControl("ScrollkeeperNotebook_NoteDropdown")
  if not dropdownControl or not dropdownControl.m_comboBox then return end
  
  local comboBox = dropdownControl.m_comboBox
  comboBox:ClearItems()
  
  -- Add "Select Note" as first option
  local selectEntry = comboBox:CreateItemEntry(SF.func._L("ScrollkeeperNotebook", "DROPDOWN_SELECT"), function() 
    loadNoteIntoEditor({
      title = SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"), 
      body = "", 
      tags = {}
    })
  end)
  comboBox:AddItem(selectEntry)
  
  -- Add filtered notes
  for _, noteData in ipairs(filteredNotes) do
    local entry = comboBox:CreateItemEntry(noteData.title, function()
      loadNoteIntoEditor(noteData.note)
    end)
    comboBox:AddItem(entry)
  end
  
  if #filteredNotes == 0 and next(currentNoteList) then
    local noResultsEntry = comboBox:CreateItemEntry(SF.func._L("ScrollkeeperNotebook", "DROPDOWN_NO_MATCHES"), function() end)
    comboBox:AddItem(noResultsEntry)
  end
end

-- ✅ Public API
function _addon:saveNote(title, body, tagList, meta)
  if not title or title == "" then return false end
  
  local settings = getSettings()
  local category = getCategory()
  local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
  
  
  -- If "All Categories" is selected, use the default category instead
  if category == allCategoriesKey then
    category = SF.func._L("ScrollkeeperNotebook", "CAT_GENERAL") or "General"
  end
  
  -- Allow overriding category via meta
  if meta and meta.category then
    category = meta.category
  end
  
  settings.noteList[category] = settings.noteList[category] or {}
  settings.noteList[category][title] = {
    title = title,
    body  = body or "",
    tags  = tagList or {},
    meta  = meta or {},
    timestamp = GetTimeStamp(),
  }
  refreshNoteList()
  
  -- Update category dropdown when a new category might have been created
  local window = GetControl("ScrollkeeperNotebook_Window")
  if window then
    if window.updateCategoryDropdown then
      window.updateCategoryDropdown()
    end
  end
  
  return true
end

function _addon:loadNote(title)
  local settings = getSettings()
  local category = getCategory()
  local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
  
  -- If viewing all categories, search across all of them
  if category == allCategoriesKey then
    for cat, notes in pairs(settings.noteList) do
      if notes[title] then
        return notes[title]
      end
    end
    return nil
  end
  
  return settings.noteList[category] and settings.noteList[category][title]
end

function _addon:deleteNote(title)
  if not title then return false end
  local settings = getSettings()
  local category = getCategory()
  local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
  
  -- If viewing all categories, search across all of them
  if category == allCategoriesKey then
    for cat, notes in pairs(settings.noteList) do
      if notes[title] then
        settings.noteList[cat][title] = nil
        refreshNoteList()
        
        -- Update category dropdown to remove empty categories
        local window = GetControl("ScrollkeeperNotebook_Window")
        if window and window.updateCategoryDropdown then
          window.updateCategoryDropdown()
        end
        
        return true
      end
    end
    return false
  end
  
  if settings.noteList[category] and settings.noteList[category][title] then
    settings.noteList[category][title] = nil
    refreshNoteList()
    
    -- Update category dropdown to remove empty categories
    local window = GetControl("ScrollkeeperNotebook_Window")
    if window and window.updateCategoryDropdown then
      window.updateCategoryDropdown()
    end
    
    return true
  end
  return false
end

-- Opens the notebook window and loads the given note (if it exists)
function _addon:openNoteWindowFor(title)
  local window = GetControl("ScrollkeeperNotebook_Window")
  if not window then
    d("|cFF5555" .. SF.func._L("ScrollkeeperNotebook", "ERROR_WINDOW_NOT_INIT") .. "|r")
    return
  end

  window:SetHidden(false)
  zo_callLater(function()
    local note = self:loadNote(title)
    if note then
      local titleInput = GetControl("ScrollkeeperNotebook_TitleInput")
      local bodyInput  = GetControl("ScrollkeeperNotebook_BodyInput")
      if titleInput then titleInput:SetText(note.title or "") end
      if bodyInput then bodyInput:SetText(note.body or "") end
    else
      d(string.format("|cFFAA55" .. SF.func._L("ScrollkeeperNotebook", "ERROR_NO_NOTE_ENTRY") .. "|r", title))
    end
  end, 100)
end

-- Log a conversation to notebook
function _addon:logConversation(playerName, conversationText, channelName)
  if not playerName or not conversationText then return false end
  
  local timestamp = os.date("%Y-%m-%d %H:%M:%S", GetTimeStamp())
  local channelTag = channelName and (" [" .. channelName .. "]") or ""
  
  -- Try to load existing note
  local existing = self:loadNote(playerName)
  
  if existing then
    -- Append to existing note
    local separator = "\n" .. string.rep("-", 50) .. "\n"
    local newEntry = timestamp .. channelTag .. ":\n" .. conversationText
    existing.body = existing.body .. separator .. newEntry
    
    -- Update tags to include "conversation"
    if existing.tags and type(existing.tags) == "table" then
      local hasTag = false
      for _, tag in ipairs(existing.tags) do
        if tag == "conversation" then hasTag = true break end
      end
      if not hasTag then
        table.insert(existing.tags, "conversation")
      end
    else
      existing.tags = {"conversation"}
    end
    
    self:saveNote(playerName, existing.body, existing.tags, existing.meta)
  else
    -- Create new note
    local body = timestamp .. channelTag .. ":\n" .. conversationText
    self:saveNote(playerName, body, {"conversation", "chat"}, { category = "Chat" })
  end
  
  return true
end

-- Enhanced integration with Guild Tools
local function injectIntoGuildMailCompose()
  if gmInjected then return end

  local subjectField = GetControl(ZOS_GM_SUBJECT_FIELD)
  local bodyField    = GetControl(ZOS_GM_BODY_FIELD)
  if not subjectField or not bodyField then
    d("[ScrollkeeperNotebook] WARNING: guild mail compose controls not found, injection skipped.")
    return
  end

  local composeRoot  = GetControl(ZOS_GM_COMPOSE_ROOT) or subjectField:GetParent():GetParent()
  local rankSelector = GetControl(ZOS_GM_RANK_SELECTOR)

  if not GetControl("ScrollkeeperNotebook_GuildMailTemplates") then
    local templateDropdown = WINDOW_MANAGER:CreateControlFromVirtual(
      "ScrollkeeperNotebook_GuildMailTemplates", composeRoot, "ZO_ComboBox")
    templateDropdown:SetAnchor(BOTTOMLEFT, GetControl(ZOS_GM_SUBJECT_FIELD), TOPLEFT, 65, -10)
    templateDropdown:SetDimensions(198, 30)

    local templateCombo = ZO_ComboBox_ObjectFromContainer(templateDropdown)
    templateCombo:SetSortsItems(true)
    templateCombo:SetFont("ZoFontGame")
    templateCombo:SetSpacing(3)

    local isPopulating = false
	local lastSelectedTemplate = ""

    local function refreshGuildMailTemplates()
      isPopulating = true
      templateCombo:ClearItems()

      local placeholder = templateCombo:CreateItemEntry(
        SF.func._L("ScrollkeeperNotebook", "MAIL_DROPDOWN_SELECT"), function() end)
      templateCombo:AddItem(placeholder)

      local settings  = getSettings()
      local mailCat   = SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")
      local mailNotes = settings.noteList and settings.noteList[mailCat]
      local lastSel   = lastSelectedTemplate
      local lastEntry = nil
      local count     = 0

      if mailNotes then
        for title, note in pairs(mailNotes) do
          if type(note) == "table" and note.body then
            local isLog = string.find(title, "^Mail Failures") ~= nil
            if note.tags then
              for _, tag in ipairs(note.tags) do
                if tag == "failures" or tag == "mail-log" then isLog = true end
              end
            end
            if not isLog then
              count = count + 1
              local capturedTitle = title
              local capturedNote  = note
              local entry = templateCombo:CreateItemEntry(title, function()
                if isPopulating then return end
                subjectField:SetText(string.sub(capturedTitle, 1, GUILD_MAIL_MAX_SUBJECT))
                bodyField:SetText(capturedNote.body or "")
                lastSelectedTemplate = capturedTitle
              end)
              templateCombo:AddItem(entry)
              if title == lastSel then lastEntry = entry end
            end
          end
        end
      end

      if count == 0 then
        templateCombo:AddItem(templateCombo:CreateItemEntry(
          SF.func._L("ScrollkeeperNotebook", "GUILDMAIL_NO_TEMPLATES"), function() end))
      end

      templateCombo:SelectItem(lastEntry or placeholder)
      isPopulating = false
    end

    _addon.refreshGuildMailTemplates = refreshGuildMailTemplates
	gmInjected = true 
    refreshGuildMailTemplates()
  else
    GetControl("ScrollkeeperNotebook_GuildMailTemplates"):SetHidden(false)
    if _addon.refreshGuildMailTemplates then _addon.refreshGuildMailTemplates() end
  end
end

local function hookGuildMailScene()
  local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene("guildRecruitmentKeyboard")
  if not scene then
    zo_callLater(hookGuildMailScene, 2000)
    return
  end

  scene:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING then
      if not gmInjected then
        injectIntoGuildMailCompose()
      elseif _addon.refreshGuildMailTemplates then
        local dd = GetControl("ScrollkeeperNotebook_GuildMailTemplates")
        if dd then dd:SetHidden(false) end
        _addon.refreshGuildMailTemplates()
      end
    end
  end)
end

-- Enhanced integration with native mail client
local function integrateWithMailClient()
  local mailSendScene = SCENE_MANAGER and SCENE_MANAGER:GetScene("mailSend")
  if not mailSendScene then
    zo_callLater(integrateWithMailClient, 2000)
    return
  end

  -- Delete old controls if they exist
  local existingControl = GetControl("ScrollkeeperNotebook_MailTemplates")
  if existingControl then
    existingControl:SetHidden(true)
    existingControl:SetParent(nil)
  end
  local existingLabel = GetControl("ScrollkeeperNotebook_MailTemplatesLabel")
  if existingLabel then
    existingLabel:SetHidden(true)
    existingLabel:SetParent(nil)
  end

  local templateDropdown = WINDOW_MANAGER:CreateControlFromVirtual("ScrollkeeperNotebook_MailTemplates", ZO_MailSend, "ZO_ComboBox")
  templateDropdown:SetDimensions(225, 30)
  templateDropdown:SetAnchor(BOTTOMLEFT, ZO_MailSendSubjectField, TOPLEFT, 87, -5)

  local templateCombo = ZO_ComboBox_ObjectFromContainer(templateDropdown)
  templateCombo:SetSortsItems(false)
  templateCombo:SetFont("ZoFontGame")
  templateCombo:SetSpacing(4)

  _addon.mailTemplateCombo = templateCombo

  local function updateMailTemplates()
    templateCombo:ClearItems()

    local defaultEntry = templateCombo:CreateItemEntry(SF.func._L("ScrollkeeperNotebook", "MAIL_DROPDOWN_SELECT"), function() end)
    templateCombo:AddItem(defaultEntry)

    local settings = getSettings()
    if settings and settings.noteList and settings.noteList[SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")] then
      local mailNotes = settings.noteList[SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")]
      for title, note in pairs(mailNotes) do
        if type(note) == "table" and note.title and note.body then
          local isFailureLog = string.find(title, "^Mail Failures") ~= nil
          if note.tags then
            for _, tag in ipairs(note.tags) do
              if tag == "failures" or tag == "mail-log" then isFailureLog = true break end
            end
          end
          if not isFailureLog then
            local entry = templateCombo:CreateItemEntry(title, function()
              if ZO_MailSendSubjectField then ZO_MailSendSubjectField:SetText(title) end
              if ZO_MailSendBodyField then ZO_MailSendBodyField:SetText(note.body or "") end
            end)
            templateCombo:AddItem(entry)
          end
        end
      end
    end

    templateCombo:SelectItem(defaultEntry)
  end

  _addon.updateMailTemplates = updateMailTemplates
  updateMailTemplates()

  mailSendScene:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWING then
      updateMailTemplates()
    end
  end)
end

-- Theme update function for notebook window
local function applyNotebookTheme(window)
  if not window or not SF or not SF.theme then return end
  
  -- Update title bar
  if window.titleBar and window.titleText then
    if SF.applyThemeToTitleBar then
      SF.applyThemeToTitleBar(window.titleBar, window.titleText)
    end
  end
  
  -- Update panels with different color channels
  if SF.theme.colors then
    local p = SF.theme.colors.panel or {0.05, 0.05, 0.05, 0.8}
    local a = SF.theme.colors.accent or {0.2, 0.3, 0.6, 0.8}

    if window.leftPanel then
      window.leftPanel:SetCenterColor(p[1], p[2], p[3], p[4])
    end
    if window.rightPanel then
      window.rightPanel:SetCenterColor(a[1], a[2], a[3], a[4])
    end
  end
end

-- Create mail preview window for notebook
local function createNotebookPreviewWindow()
  local windowName = "ScrollkeeperNotebook_PreviewWindow"
  
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
  title:SetText(SF.func._L("ScrollkeeperNotebook", "PREVIEW_TITLE"))
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
  subjectHeaderLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTE_TITLE"))
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
  bodyHeaderLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTE_CONTENT"))
  bodyHeaderLabel:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 65)
  bodyHeaderLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Body display area with scroll
  local bodyContainer = WINDOW_MANAGER:CreateControl(nil, mailPanel, CT_CONTROL)
  bodyContainer:SetDimensions(560, 340)
  bodyContainer:SetAnchor(TOPLEFT, mailPanel, TOPLEFT, 10, 85)
  
  local bodyBg = WINDOW_MANAGER:CreateControl(nil, bodyContainer, CT_BACKDROP)
  bodyBg:SetDimensions(540, 340)
  bodyBg:SetAnchor(TOPLEFT, bodyContainer, TOPLEFT, 0, 0)
  bodyBg:SetCenterColor(0.0, 0.0, 0.0, 1)
  bodyBg:SetEdgeColor(0.5, 0.5, 0.5, 1)
  bodyBg:SetEdgeTexture("", 1, 1, 0)
  
  -- Read-only edit box with scrolling
  local bodyDisplay = WINDOW_MANAGER:CreateControl(nil, bodyBg, CT_EDITBOX)
  bodyDisplay:SetFont("ZoFontGame")
  bodyDisplay:SetAnchor(TOPLEFT, bodyBg, TOPLEFT, 10, 10)
  bodyDisplay:SetDimensions(510, 320)
  bodyDisplay:SetColor(1, 1, 1, 1)
  bodyDisplay:SetMaxInputChars(10000)
  bodyDisplay:SetMultiLine(true)
  bodyDisplay:SetEditEnabled(false)  -- Read-only
  bodyDisplay:SetMouseEnabled(true)
  
  -- Add scrollbar
  local scrollbar = WINDOW_MANAGER:CreateControl(nil, bodyContainer, CT_SLIDER)
  scrollbar:SetDimensions(16, 340)
  scrollbar:SetAnchor(TOPRIGHT, bodyContainer, TOPRIGHT, 0, 0)
  scrollbar:SetOrientation(ORIENTATION_VERTICAL)
  scrollbar:SetThumbTexture("/esoui/art/miscellaneous/scrollbox_elevator.dds", "/esoui/art/miscellaneous/scrollbox_elevator_disabled.dds", nil, 8, 16)
  scrollbar:SetMouseEnabled(true)
  
  -- Mousewheel scrolling for preview
  bodyDisplay:SetHandler("OnMouseWheel", function(self, delta)
    local text = self:GetText()
    local textLength = string.len(text)
    local cursorPosition = self:GetCursorPosition()
    
    if delta > 0 then
      self:SetCursorPosition(math.max(0, cursorPosition - 50))
    else
      self:SetCursorPosition(math.min(textLength, cursorPosition + 50))
    end
  end)
  
  -- Auto show/hide scrollbar based on content length
  local function updateScrollbar()
    local text = bodyDisplay:GetText() or ""
    if string.len(text) > 8000 then
      scrollbar:SetHidden(false)
    else
      scrollbar:SetHidden(true)
    end
  end
  
  -- Store references
  window.subjectDisplay = subjectDisplay
  window.bodyDisplay = bodyDisplay
  window.updateScrollbar = updateScrollbar
  
  -- Function to update preview
  window.updatePreview = function(subject, body)
    if subjectDisplay then
      subjectDisplay:SetText(subject or "")
    end
    if bodyDisplay then
      bodyDisplay:SetText(body or "")
      -- Update scrollbar visibility
      if window.updateScrollbar then
        window.updateScrollbar()
      end
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
    SF.registerThemedWindow("ScrollkeeperNotebook_PreviewWindow", window.updateTheme)
  end
  
  zo_callLater(function()
    if window.updateTheme then window.updateTheme() end
  end, 100)
  
  SF.addOrnateFrame(window)
  return window
end

-- Enhanced window creation with proper sizing and layout
local function createNotebookWindow()
  local windowName = "ScrollkeeperNotebook_Window"
  
  -- Check if window already exists
  local existingWindow = GetControl(windowName)
  if existingWindow then
    d(SF.func._L("ScrollkeeperNotebook", "ERROR_WINDOW_EXISTS"))
    return existingWindow
  end
  
  local window = WINDOW_MANAGER:CreateTopLevelWindow(windowName)
  window:SetDimensions(800, 600)
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
  titleBar:SetDimensions(800, 35)
  titleBar:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
  titleBar:SetCenterColor(0.2, 0.2, 0.3, 1)
  titleBar:SetEdgeColor(0.4, 0.4, 0.4, 1)
  titleBar:SetEdgeTexture("", 1, 1, 0)
  
  -- Title text
  local title = WINDOW_MANAGER:CreateControl(windowName .. "_Title", titleBar, CT_LABEL)
  title:SetFont("$(PROSE_ANTIQUE_FONT)|22|soft-shadow-thin")
  title:SetText(SF.func._L("ScrollkeeperNotebook", "WINDOW_TITLE"))
  title:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
  title:SetColor(1, 1, 1, 1)
  
  -- Close button
  local closeBtn = WINDOW_MANAGER:CreateControl(windowName .. "_Close", titleBar, CT_BUTTON)
  closeBtn:SetDimensions(25, 25)
  closeBtn:SetAnchor(RIGHT, titleBar, RIGHT, -5, 0)
  closeBtn:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
  closeBtn:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
  closeBtn:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")
  closeBtn:SetHandler("OnClicked", function()
    window:SetHidden(true)
    if LibTextFilter then
      LibTextFilter:ClearCachedTokens()
    end
  end)
  
  -- Left panel for note management
  local leftPanel = WINDOW_MANAGER:CreateControl(windowName .. "_LeftPanel", window, CT_BACKDROP)
  leftPanel:SetDimensions(280, 520)
  leftPanel:SetAnchor(TOPLEFT, window, TOPLEFT, 5, 40)
  leftPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  leftPanel:SetEdgeColor(0.3, 0.3, 0.3, 1)
  leftPanel:SetEdgeTexture("", 1, 1, 0)
  
  window.leftPanel = leftPanel
  
  -- Search box
  local searchLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SearchLabel", leftPanel, CT_LABEL)
  searchLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  searchLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_SEARCH"))
  searchLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 5)
  searchLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local searchBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_SearchBg", leftPanel, "ZO_EditBackdrop")
  searchBg:SetDimensions(260, 25)
  searchBg:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 25)
  
  local searchInput = WINDOW_MANAGER:CreateControlFromVirtual("ScrollkeeperNotebook_SearchInput", searchBg, "ZO_DefaultEditForBackdrop")
  searchInput:SetHandler("OnTextChanged", function() 
    zo_callLater(refreshNoteList, 100)
  end)
  
  -- Category dropdown
  local categoryLabel = WINDOW_MANAGER:CreateControl(windowName .. "_CategoryLabel", leftPanel, CT_LABEL)
  categoryLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  categoryLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_CATEGORY"))
  categoryLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 55)
  categoryLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  -- Create category dropdown control
  local categoryDropdownControl = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_CategoryDropdown", leftPanel, CT_CONTROL)
  categoryDropdownControl:SetDimensions(260, 30)
  categoryDropdownControl:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 75)
  
  local categoryDropdownBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_CategoryDropdownBg", categoryDropdownControl, "ZO_ComboBox")
  categoryDropdownBg:SetAnchorFill()
  
  local categoryCombo = ZO_ComboBox_ObjectFromContainer(categoryDropdownBg)
  categoryCombo:SetSortsItems(false)
  categoryCombo:SetFont("ZoFontGame")
  
  -- Function to populate category dropdown
  local function updateCategoryDropdown()
    categoryCombo:ClearItems()
    
    -- Add "All Categories" option first
    local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
    local allCategoriesEntry = categoryCombo:CreateItemEntry(allCategoriesKey, function()
      local settings = getSettings()
      settings.settings.defaultCategory = allCategoriesKey
      refreshNoteList()
      if updateNoteDropdown then updateNoteDropdown() end
    end)
    categoryCombo:AddItem(allCategoriesEntry)
    
    -- Collect all categories (excluding the special "All Categories" key)
    local categories = {}
    local settings = getSettings()
    local allCategoriesKey = SF.func._L("ScrollkeeperNotebook", "CAT_ALL_CATEGORIES") or "All Categories"
    for cat, notes in pairs(settings.noteList) do
      -- Count notes in this category
      local noteCount = 0
      for _ in pairs(notes) do
        noteCount = noteCount + 1
      end
      
      if cat ~= allCategoriesKey and cat ~= "" and noteCount > 0 then
        table.insert(categories, cat)
      else
      end
    end
    table.sort(categories)
    
    -- Add each category
    for _, cat in ipairs(categories) do
      local entry = categoryCombo:CreateItemEntry(cat, function()
        local settings = getSettings()
        settings.settings.defaultCategory = cat
        refreshNoteList()
        if updateNoteDropdown then updateNoteDropdown() end
      end)
      categoryCombo:AddItem(entry)
    end
    
    -- Select current category or "All Categories" if not found
    local currentCategory = getCategory()
    local indexToSelect = 1  -- Default to "All Categories"
    
    -- If current category is not "All Categories", try to find it
    if currentCategory ~= allCategoriesKey then
      for i, cat in ipairs(categories) do
        if cat == currentCategory then
          indexToSelect = i + 1  -- +1 because "All Categories" is at index 1
          break
        end
      end
    end
    
    categoryCombo:SelectItemByIndex(indexToSelect, true)
  end
  
  -- Initial population will happen after window is shown
  -- (defer to avoid calling undefined function)
  zo_callLater(function()
    if window.updateCategoryDropdown then
      window.updateCategoryDropdown()
    end
  end, 50)
  
  -- Store reference for later updates
  window.updateCategoryDropdown = updateCategoryDropdown
  
  -- Dropdown section
  local noteLabel = WINDOW_MANAGER:CreateControl(windowName .. "_NoteLabel", leftPanel, CT_LABEL)
  noteLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  noteLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_SAVED_NOTES"))
  noteLabel:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 105)
  noteLabel:SetColor(0.8, 0.8, 0.8, 1)
  
  local countLabel = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_CountLabel", leftPanel, CT_LABEL)
  countLabel:SetFont("ZoFontGameSmall")
  countLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTES_SIMPLE"), 0))
  countLabel:SetAnchor(TOPRIGHT, leftPanel, TOPRIGHT, -5, 105)
  countLabel:SetColor(0.75, 0.75, 0.75, 1)
  
  -- Dropdown creation with unique names to avoid conflicts
  local dropdownControl = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_NoteDropdown", leftPanel, CT_CONTROL)
  dropdownControl:SetDimensions(260, 30)
  dropdownControl:SetAnchor(TOPLEFT, leftPanel, TOPLEFT, 5, 125)
  
  local dropdownBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_DropdownBg", dropdownControl, "ZO_ComboBox")
  dropdownBg:SetAnchorFill()
  
  local comboBox = ZO_ComboBox_ObjectFromContainer(dropdownBg)
  if comboBox then
    comboBox:SetSortsItems(false)
    comboBox:SetFont("ZoFontGame")
    comboBox:SetSpacing(4)
    dropdownControl.m_comboBox = comboBox
    
    local defaultEntry = comboBox:CreateItemEntry(SF.func._L("ScrollkeeperNotebook", "DROPDOWN_SELECT"), function() 
      loadNoteIntoEditor({
        title = SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"), 
        body = "", 
        tags = {}
      })
    end)
    comboBox:AddItem(defaultEntry)
    comboBox:SelectItem(defaultEntry)
  else
    d(SF.func._L("ScrollkeeperNotebook", "ERROR_DROPDOWN_FAILED"))
  end	
		  
  -- Right panel for note editing
  local rightPanel = WINDOW_MANAGER:CreateControl(windowName .. "_RightPanel", window, CT_BACKDROP)
  rightPanel:SetDimensions(500, 520)
  rightPanel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -5, 40)
  rightPanel:SetCenterColor(0.05, 0.05, 0.05, 0.8)
  rightPanel:SetEdgeColor(0.3, 0.3, 0.3, 1)
  rightPanel:SetEdgeTexture("", 1, 1, 0)
  
  window.rightPanel = rightPanel
  
  -- Note title input with character count
  local titleLabel = WINDOW_MANAGER:CreateControl(windowName .. "_TitleLabel", rightPanel, CT_LABEL)
  titleLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  titleLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTE_TITLE"))
  titleLabel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 5)
  titleLabel:SetColor(1, 1, 1, 1)
  
  local titleCountLabel = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_TitleCount", rightPanel, CT_LABEL)
  titleCountLabel:SetFont("ZoFontGameSmall")
  titleCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "CHAR_COUNT_TITLE"), 0))
  titleCountLabel:SetAnchor(TOPRIGHT, rightPanel, TOPRIGHT, -5, 5)
  titleCountLabel:SetColor(1, 1, 1, 1)
  
  local titleBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_TitleBg", rightPanel, "ZO_EditBackdrop")
  titleBg:SetDimensions(490, 25)
  titleBg:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 25)
  
  local titleInput = WINDOW_MANAGER:CreateControlFromVirtual("ScrollkeeperNotebook_TitleInput", titleBg, "ZO_DefaultEditForBackdrop")
  titleInput:SetMaxInputChars(100)
  titleInput:SetText(SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"))
  
  -- Update title character count
  titleInput:SetHandler("OnTextChanged", function()
    local text = titleInput:GetText()
    local count = string.len(text)
    titleCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "CHAR_COUNT_TITLE"), count))
    if count > 100 then
      titleCountLabel:SetColor(1, 0.4, 0.4, 1) -- Red if over limit
    else
      titleCountLabel:SetColor(1, 1, 1, 1) -- Normal gray
    end
  end)
  
  -- Tags input
  local tagLabel = WINDOW_MANAGER:CreateControl(windowName .. "_TagLabel", rightPanel, CT_LABEL)
  tagLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  tagLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_TAGS"))
  tagLabel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 55)
  tagLabel:SetColor(1, 1, 1, 1)
  
  local tagBg = WINDOW_MANAGER:CreateControlFromVirtual(windowName .. "_TagBg", rightPanel, "ZO_EditBackdrop")
  tagBg:SetDimensions(490, 25)
  tagBg:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 75)

  local tagInput = WINDOW_MANAGER:CreateControlFromVirtual("ScrollkeeperNotebook_TagInput", tagBg, "ZO_DefaultEditForBackdrop")
  tagInput:SetMaxInputChars(200)
  
  -- Note body input with character count
  local bodyLabel = WINDOW_MANAGER:CreateControl(windowName .. "_BodyLabel", rightPanel, CT_LABEL)
  bodyLabel:SetFont("$(PROSE_ANTIQUE_FONT)|18")
  bodyLabel:SetText(SF.func._L("ScrollkeeperNotebook", "LABEL_NOTE_CONTENT"))
  bodyLabel:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 105)
  bodyLabel:SetColor(1, 1, 1, 1)
  
  local bodyCountLabel = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_BodyCount", rightPanel, CT_LABEL)
  bodyCountLabel:SetFont("ZoFontGameSmall")
  bodyCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "CHAR_COUNT_BODY"), 0))
  bodyCountLabel:SetAnchor(TOPRIGHT, rightPanel, TOPRIGHT, -5, 105)
  bodyCountLabel:SetColor(1, 1, 1, 1)
  
  -- Body area: bordered backdrop containing a ZO_ScrollContainer + editbox
  local BODY_W = 490
  local BODY_H = 320
  local SCROLLBAR_W = 16
  local EDITBOX_W = BODY_W - SCROLLBAR_W - 10  -- 10px = left pad(5) + right gap(5)

  local bodyBg = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_BodyBg", rightPanel, CT_BACKDROP)
  bodyBg:SetDimensions(BODY_W, BODY_H)
  bodyBg:SetAnchor(TOPLEFT, rightPanel, TOPLEFT, 5, 125)
  bodyBg:SetCenterColor(0.0, 0.0, 0.0, 1)
  bodyBg:SetEdgeColor(0.5, 0.5, 0.5, 1)
  bodyBg:SetEdgeTexture("", 1, 1, 0)

  -- ZO_ScrollContainer handles clipping and drives the scrollbar automatically
  local scrollContainer = WINDOW_MANAGER:CreateControlFromVirtual(
    "ScrollkeeperNotebook_BodyScroll", bodyBg, "ZO_ScrollContainer")
  scrollContainer:SetDimensions(BODY_W - 4, BODY_H - 4)  -- small inset so border shows
  scrollContainer:SetAnchor(TOPLEFT, bodyBg, TOPLEFT, 2, 2)

  -- The scroll child is the editbox's parent; its height will grow with text.
  -- ZO_ScrollContainer names it "ScrollChild" internally — use GetNamedChild
  local scrollChild = scrollContainer:GetNamedChild("ScrollChild")
  if not scrollChild then
    -- Last resort: iterate direct children to find the scroll child control
    for i = 1, scrollContainer:GetNumChildren() do
      local child = scrollContainer:GetChild(i)
      if child then scrollChild = child break end
    end
  end

  if not scrollChild then
    d("|cFF5555ScrollkeeperNotebook: failed to get scroll child — body area unavailable|r")
    return window
  end
  -- Editbox lives inside the scroll child
  local bodyInput = WINDOW_MANAGER:CreateControl(
    "ScrollkeeperNotebook_BodyInput", scrollChild, CT_EDITBOX)
  bodyInput:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 5, 5)
  bodyInput:SetDimensions(EDITBOX_W, BODY_H - 4)  -- initial height; grows below
  bodyInput:SetFont("ZoFontGame")
  bodyInput:SetColor(1, 1, 1, 1)
  bodyInput:SetMaxInputChars(5000)
  bodyInput:SetMultiLine(true)
  bodyInput:SetText(SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_BODY"))
  bodyInput:SetEditEnabled(true)
  bodyInput:SetMouseEnabled(true)
  
  -- ZoFontGame renders at ~22px line height. We use 24 to ensure we always
  -- overestimate rather than underestimate, which prevents top-clipping.
  local LINE_HEIGHT = 24
  local MIN_HEIGHT  = BODY_H - 4
  -- Average char width for ZoFontGame at this editbox width.
  -- Using 6.5px (narrower than reality) means we assume more wrapping,
  -- producing more lines -> taller scroll child -> no top clipping.
  local AVG_CHAR_W  = 6.5

  local function resizeBodyToContent()
    local text = bodyInput:GetText() or ""
    local lineW = math.floor(EDITBOX_W / AVG_CHAR_W)
    local lines = 0
    for segment in (text .. "\n"):gmatch("([^\n]*)\n") do
      -- Each explicit line is at least 1 row; longer lines wrap
      lines = lines + math.max(1, math.ceil((#segment + 1) / lineW))
    end
    -- Extra 20% buffer on top of the calculated height as a safety margin
    local newH = math.max(MIN_HEIGHT, math.ceil(lines * LINE_HEIGHT * 1.2) + 20)
    bodyInput:SetHeight(newH)
    scrollChild:SetHeight(newH + 20)
  end

  local function resizeAndResetScroll()
    resizeBodyToContent()
    if scrollContainer.ScrollToTop then
      scrollContainer:ScrollToTop()
    elseif scrollContainer.scroll and scrollContainer.scroll.SetVerticalScroll then
      scrollContainer.scroll:SetVerticalScroll(0)
    else
      -- Universal fallback: re-anchor the scroll child to the top of the container
      scrollChild:ClearAnchors()
      scrollChild:SetAnchor(TOPLEFT, scrollContainer, TOPLEFT, 0, 0)
    end
  end
  
  -- Allow clicking to edit
  bodyInput:SetHandler("OnMouseUp", function(self, button, upInside)
    if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
      self:TakeFocus()
    end
  end)
  
  -- Store references for note loading to work
  window.bodyInput = bodyInput
  window.bodyScrollContainer = scrollContainer
  window.resizeBodyToContent = resizeAndResetScroll  -- used by loadNoteIntoEditor

  -- Update body character count and resize scroll child on text change
  bodyInput:SetHandler("OnTextChanged", function()
    local text = bodyInput:GetText()
    local count = string.len(text)

    -- Delay resize so ESO finishes laying out text before we measure
    zo_callLater(resizeBodyToContent, 50)

    -- Update character count label
    bodyCountLabel:SetText(string.format(SF.func._L("ScrollkeeperNotebook", "CHAR_COUNT_BODY"), count))
    if count > 5000 then
      bodyCountLabel:SetColor(1, 0.4, 0.4, 1) -- Red if over limit
    elseif count > 4500 then
      bodyCountLabel:SetColor(1, 0.8, 0.4, 1) -- Orange if close to limit
    else
      bodyCountLabel:SetColor(1, 1, 1, 1) -- Normal white
    end
  end)
  
  -- Button panel
  local buttonPanel = WINDOW_MANAGER:CreateControl(windowName .. "_ButtonPanel", rightPanel, CT_CONTROL)
  buttonPanel:SetDimensions(490, 60)
  buttonPanel:SetAnchor(BOTTOM, rightPanel, BOTTOM, 0, -10)
  
  -- Save button
  local saveBtn = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_SaveBtn", buttonPanel, CT_BUTTON)
  saveBtn:SetDimensions(32, 32)
  saveBtn:SetAnchor(LEFT, buttonPanel, LEFT, 40, -10)
  saveBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_up.dds")
  saveBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_down.dds")
  saveBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/giftmessageicon_over.dds")
  saveBtn:SetHandler("OnClicked", function()
    local title = titleInput:GetText()
    local body = bodyInput:GetText()
    local tags = parseTags(tagInput:GetText())
    
    -- Use first tag as category if provided
    local meta = nil
    if tags and #tags > 0 then
      meta = { category = tags[1] }
    end
    
    if title and title ~= "" then
      if _addon:saveNote(title, body, tags, meta) then
        d(string.format(SF.func._L("ScrollkeeperNotebook", "SUCCESS_NOTE_SAVED"), title))
        refreshNoteList()
      else
        d(SF.func._L("ScrollkeeperNotebook", "ERROR_SAVE_FAILED"))
      end
    else
      d(SF.func._L("ScrollkeeperNotebook", "ERROR_NO_TITLE"))
    end
  end)
  
  -- Save button label - positioned BELOW the button
  local saveLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SaveLabel", buttonPanel, CT_LABEL)
  saveLabel:SetAnchor(TOP, saveBtn, BOTTOM, 0, 5)
  saveLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  saveLabel:SetText(SF.func._L("ScrollkeeperNotebook", "BTN_SAVE"))
  saveLabel:SetColor(1, 1, 1, 1)
  saveLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  
  -- New button
  local newBtn = WINDOW_MANAGER:CreateControl(windowName .. "_NewBtn", buttonPanel, CT_BUTTON)
  newBtn:SetDimensions(32, 32)
  newBtn:SetAnchor(LEFT, saveBtn, RIGHT, 60, 0)
  newBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_up.dds")
  newBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_down.dds")
  newBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/vendor_tabicon_buyback_over.dds")
  newBtn:SetHandler("OnClicked", function()
    titleInput:SetText(SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"))
    bodyInput:SetText("")
    tagInput:SetText("")
    titleInput:TakeFocus()
  end)
  
  -- New button label - positioned BELOW the button
  local newLabel = WINDOW_MANAGER:CreateControl(windowName .. "_NewLabel", buttonPanel, CT_LABEL)
  newLabel:SetAnchor(TOP, newBtn, BOTTOM, 0, 5)
  newLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  newLabel:SetText(SF.func._L("ScrollkeeperNotebook", "BTN_NEW"))
  newLabel:SetColor(1, 1, 1, 1)
  newLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  
  -- Delete button
  local deleteBtn = WINDOW_MANAGER:CreateControl(windowName .. "_DeleteBtn", buttonPanel, CT_BUTTON)
  deleteBtn:SetDimensions(30, 30)
  deleteBtn:SetAnchor(LEFT, newBtn, RIGHT, 60, 0)
  deleteBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/inventory_tabicon_trash_up.dds")
  deleteBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/inventory_tabicon_trash_down.dds")
  deleteBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/inventory_tabicon_trash_over.dds")
  deleteBtn:SetHandler("OnClicked", function()
    local title = titleInput:GetText()
    if title and title ~= "" then
      if _addon:deleteNote(title) then
        titleInput:SetText(SF.func._L("ScrollkeeperNotebook", "DEFAULT_NOTE_TITLE"))
        bodyInput:SetText("")
        tagInput:SetText("")
      end
    end
  end)
  
  -- Delete button label - positioned BELOW the button
  local deleteLabel = WINDOW_MANAGER:CreateControl(windowName .. "_DeleteLabel", buttonPanel, CT_LABEL)
  deleteLabel:SetAnchor(TOP, deleteBtn, BOTTOM, 0, 5)
  deleteLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  deleteLabel:SetText(SF.func._L("ScrollkeeperNotebook", "BTN_DELETE"))
  deleteLabel:SetColor(1, 1, 1, 1)
  deleteLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  
  -- Save as Mail Template button
  local saveMailBtn = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_SaveMailBtn", buttonPanel, CT_BUTTON)
  saveMailBtn:SetDimensions(32, 32)
  saveMailBtn:SetAnchor(LEFT, deleteBtn, RIGHT, 60, 0)
  saveMailBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_up.dds")
  saveMailBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_down.dds")
  saveMailBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/mail_tabicon_compose_over.dds")
  saveMailBtn:SetHandler("OnClicked", function()
    local title = titleInput:GetText()
    local body  = bodyInput:GetText()
    local tags  = parseTags(tagInput:GetText())
    if title and title ~= "" then
      -- force into Mail category
      local settings = getSettings()
      settings.noteList[SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")] = settings.noteList[SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")] or {}
      settings.noteList[SF.func._L("ScrollkeeperNotebook", "CAT_MAIL")][title] = {
        title     = title,
        body      = body or "",
        tags      = tags or {},
        meta      = { category = SF.func._L("ScrollkeeperNotebook", "CAT_MAIL") },
        timestamp = GetTimeStamp(),
      }
      d(string.format(SF.func._L("ScrollkeeperNotebook", "SUCCESS_TEMPLATE_SAVED"), title))
      refreshNoteList()
      -- Refresh the guild mail template dropdown immediately if injected
      if _addon.refreshGuildMailTemplates then
        _addon.refreshGuildMailTemplates()
      end
    else
      d(SF.func._L("ScrollkeeperNotebook", "ERROR_TEMPLATE_NO_TITLE"))
    end
  end)
  
  -- Preview mail template button
  local previewMailBtn = WINDOW_MANAGER:CreateControl("ScrollkeeperNotebook_PreviewMailBtn", buttonPanel, CT_BUTTON)
  previewMailBtn:SetDimensions(32, 32)
  previewMailBtn:SetAnchor(LEFT, saveMailBtn, RIGHT, 60, 0)
  previewMailBtn:SetNormalTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_up.dds")
  previewMailBtn:SetPressedTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_down.dds")
  previewMailBtn:SetMouseOverTexture("Scrollkeeper/ScrollkeeperFramework/textures/tradinghouse_listings_tabicon_over.dds")
  
  previewMailBtn:SetHandler("OnClicked", function()
    local title = titleInput:GetText()
    local body = bodyInput:GetText()
    
    if not title or title == "" then
      d(SF.func._L("ScrollkeeperNotebook", "ERROR_NO_TITLE"))
      return
    end
    
    if not body or body == "" then
      d(SF.func._L("ScrollkeeperNotebook", "ERROR_NO_BODY") or "Please enter some text in the body")
      return
    end
    
    -- Create/show preview window
    local previewWindow = createNotebookPreviewWindow()
    if previewWindow then
      previewWindow.updatePreview(title, body)
      previewWindow:SetHidden(false)
    end
  end)

  local previewMailLabel = WINDOW_MANAGER:CreateControl(windowName .. "_PreviewMailLabel", buttonPanel, CT_LABEL)
  previewMailLabel:SetAnchor(TOP, previewMailBtn, BOTTOM, 0, 5)
  previewMailLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  previewMailLabel:SetText(SF.func._L("ScrollkeeperNotebook", "BTN_PREVIEW_MAIL"))
  previewMailLabel:SetColor(1, 1, 1, 1)
  previewMailLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

  local saveMailLabel = WINDOW_MANAGER:CreateControl(windowName .. "_SaveMailLabel", buttonPanel, CT_LABEL)
  saveMailLabel:SetAnchor(TOP, saveMailBtn, BOTTOM, 0, 5)
  saveMailLabel:SetFont("$(PROSE_ANTIQUE_FONT)|17")
  saveMailLabel:SetText(SF.func._L("ScrollkeeperNotebook", "BTN_SAVE_MAIL"))
  saveMailLabel:SetColor(1, 1, 1, 1)
  saveMailLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
  
  -- Store references for theme updates
  window.titleBar = titleBar
  window.titleText = title
  
  -- Register theme update callback
  window.updateTheme = function()
    applyNotebookTheme(window)
  end
  
  -- Register with framework
  if SF and SF.registerThemedWindow then
    SF.registerThemedWindow("ScrollkeeperNotebook_Window", window.updateTheme)
  end
  
  -- Apply initial theme
  zo_callLater(function()
    applyNotebookTheme(window)
  end, 100)
  
  SF.addOrnateFrame(window)
  return window
end

-- 🧱 UI Initialization
local function initializeNotebookUI()
  local settings = getSettings()
  if not settings.settings.enabled then 
    return 
  end
  
  local window = createNotebookWindow()
  if not window then
    return
  end
  
  -- Register slash command
  SLASH_COMMANDS["/sgtnote"] = function()
    local settings = getSettings()
    if not settings.settings.enabled then 
      d(SF.func._L("ScrollkeeperNotebook", "ERROR_DISABLED"))
      return 
    end
    
    local window = GetControl("ScrollkeeperNotebook_Window")
    if window then
      window:SetHidden(not window:IsHidden())
      if not window:IsHidden() then
        refreshNoteList()
      end
    end
  end

  -- Initial refresh
  refreshNoteList()
  
  -- Integrate with mail client
  integrateWithMailClient()
  -- Inject into ZOS guild mail compose
  hookGuildMailScene()
end

-- ⚙️ Build the LibAddonMenu-2.0 settings controls
local function buildControls()
  local settings = getSettings()
  return {
    {
      type = "submenu",
      name = SF.func._L("ScrollkeeperNotebook", "SUBMENU_NAME"),
      controls = {
        {
          type = "description",
          text = SF.func._L("ScrollkeeperNotebook", "DESC_MAIN")
        },
        {
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperNotebook", "SETTING_ENABLE"),
          tooltip = SF.func._L("ScrollkeeperNotebook", "SETTING_ENABLE_TIP"),
          getFunc = function() return settings.settings.enabled end,
          setFunc = function(v)
            settings.settings.enabled = v
            if v then
              initializeNotebookUI()
            else
              local window = GetControl("ScrollkeeperNotebook_Window")
              if window then window:SetHidden(true) end
            end
          end,
          default = defaults.settings.enabled,
        },
		{
          type    = "checkbox",
          name    = SF.func._L("ScrollkeeperNotebook", "SETTING_SEARCH"),
          tooltip = SF.func._L("ScrollkeeperNotebook", "SETTING_SEARCH_TIP"),
          getFunc = function() return settings.settings.enableSearchFilter end,
          setFunc = function(v) 
            settings.settings.enableSearchFilter = v
            refreshNoteList()
          end,
          default = defaults.settings.enableSearchFilter,
        },
        {
          type = "button",
          name = SF.func._L("ScrollkeeperNotebook", "BTN_OPEN_NOTEBOOK"),
          tooltip = SF.func._L("ScrollkeeperNotebook", "TIP_OPEN_NOTEBOOK"),
          func = function()
            if SLASH_COMMANDS["/sgtnote"] then
              SLASH_COMMANDS["/sgtnote"]()
            end
          end,
          width = "half",
        },
        {
          type    = "editbox",
          name    = SF.func._L("ScrollkeeperNotebook", "SETTING_DEFAULT_CATEGORY"),
          tooltip = SF.func._L("ScrollkeeperNotebook", "SETTING_DEFAULT_CATEGORY_TIP"),
          getFunc = function() return settings.settings.defaultCategory end,
          setFunc = function(v) 
            settings.settings.defaultCategory = v 
            local categoryInput = GetControl("ScrollkeeperNotebook_CategoryInput")
            if categoryInput then categoryInput:SetText(v) end
            refreshNoteList()
          end,
          width   = "full",
          default = defaults.settings.defaultCategory,
        },
        {
          type = "description",
          text = SF.func._L("ScrollkeeperNotebook", "DESC_MAIL_TEMPLATES")
        },
      }
    }
  }
end

-- 📝 Register with Scrollkeeper & inject our settings
local function initialize()
  if _addon._initialized then
    return
  end

  -- Correct parameter order - module name first, then controls
  if SF_Set and SF_Set.RegisterModuleOptions then
    local controls = buildControls()
    SF_Set.RegisterModuleOptions(_addon.Name, controls)
  end

  local settings = getSettings()
  if settings.settings.enabled then
    initializeNotebookUI()
  end
  
  _addon._initialized = true
end

EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED, function()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_PLAYER_ACTIVATED)
  initialize()
end)
CALLBACK_MANAGER:RegisterCallback("Scrollkeeper_Initialized", initialize)