-- Code derived from GodSendPlus, originally by Focus (MIT License).

local ADDON_NAME = "FurnitureShoppingList"
local QUANTITY_DIALOG = "FURNITURE_SHOPPING_LIST_QUANTITY"

-- Public API (for FurnitureCatalogue etc): version, Add, PromptAdd
FurnitureShoppingList = {}
do
  local addOnManager = GetAddOnManager()
  for i = 1, addOnManager:GetNumAddOns() do
    if addOnManager:GetAddOnInfo(i) == ADDON_NAME then
      FurnitureShoppingList.version = addOnManager:GetAddOnVersion(i)
      break
    end
  end
end

local SL_WINDOW = nil
local SL_RECIPIENTS = nil
local SL_ITEMS = nil
local SAVED = nil -- saved vars: SAVED.items[itemId] = quantity
local subtractOwned = false

local RECIPIENTS_SORT_KEYS = {
  ["name"] = {},
  ["need"] = { tiebreaker = "name", isNumeric = true },
  ["price"] = { tiebreaker = "name", isNumeric = true },
}

local ITEMS_SORT_KEYS = {
  ["name"] = {},
  ["quantity"] = { tiebreaker = "name", isNumeric = true },
}

local FurnitureShoppingListWindow = ZO_Object:Subclass()
local FurnitureShoppingListRecipients = ZO_SortFilterList:Subclass()
local FurnitureShoppingListItems = ZO_SortFilterList:Subclass()

local function getLibrary()
  return LibFurnitureCatalogue and LibFurnitureCatalogue.API
end

-- runs fn(LFC) if the catalogue is ready, else once it is
local function withLibrary(fn)
  local LFC = getLibrary()
  if not SAVED then
    return
  elseif not LFC then
    CHAT_SYSTEM:AddMessage(GetString(FSL_REQUIRES_FC))
  elseif LFC.IsReady() then
    fn(LFC)
  elseif not LFC.OnReady(function()
    fn(LFC)
  end) then
    CHAT_SYSTEM:AddMessage(GetString(FSL_DB_NOT_READY))
  end
end

-- furnishing id of an item or its blueprint (link or id), nil unless the catalogue says it's craftable
local function craftableItemId(LFC, itemOrLink)
  local entry = LFC.GetEntry(itemOrLink)
  if entry and next(LFC.GetIngredients(entry.id, entry)) then
    return entry.id
  end
end

-- for the context menus: only a ready catalogue is queried
local function canShopFor(link)
  if not (IsItemLinkPlaceableFurniture(link) or IsItemLinkFurnitureRecipe(link)) then
    return false
  end
  local LFC = getLibrary()
  return LFC ~= nil and LFC.IsReady() and craftableItemId(LFC, link) ~= nil
end

-- needs no catalogue, so stored items keep their names while it is missing; plain style like the material links
local function itemLinkFromId(itemId)
  return string.format("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

-- materials for { [itemId] = quantity }, keyed by material item id: { link = , need = }
local function materialTotals(LFC, items)
  local totals = {}
  for itemId, quantity in pairs(items) do
    local entry = LFC.GetEntry(itemId)
    for link, perItem in pairs(entry and LFC.GetIngredients(itemId, entry) or {}) do
      local materialId = GetItemLinkItemId(link)
      local total = totals[materialId] or { link = link, need = 0 }
      total.need = total.need + perItem * quantity
      totals[materialId] = total
    end
  end
  return totals
end

-- furnishing ids in pasted text, in order, repeats kept. The ids of a line are what follows its last colon, so
-- "FURC LIST: <name>: ...", "FURC FAVES: ..." and a bare "123,456" all count; a line whose rest is not ids is skipped.
-- A colon-less line of ids right after a line with a colon is glued onto it, as FurnitureCatalogue does: the edit box
-- breaks a long pasted line, possibly inside an id.
local function parseListText(text)
  local lines, last = {}, nil
  for rawLine in tostring(text or ""):gmatch("[^\r\n]+") do
    local line = rawLine:match("^%s*(.-)%s*$")
    local tail = line:match(".*:(.*)$")
    local idText = (tail or line):match("^[%d,%s]*$")
    if line == "" then
      -- an empty line neither ends nor continues anything
    elseif not idText then
      last = nil
    elseif last and not tail then
      lines[last] = lines[last] .. idText
    else
      lines[#lines + 1] = idText
      last = tail and #lines or nil
    end
  end
  local ids = {}
  for _, idText in ipairs(lines) do
    for id in idText:gmatch("%d+") do
      ids[#ids + 1] = tonumber(id)
    end
  end
  return ids
end

---Refresh print window content
local refreshOutput

local function refresh()
  if SL_ITEMS then
    SL_ITEMS:RefreshData()
  end
  if SL_RECIPIENTS then
    SL_RECIPIENTS:RefreshData()
  end
  refreshOutput()
end

-- below 1 removes the item
local function setQuantity(itemId, quantity)
  SAVED.items[itemId] = quantity >= 1 and zo_floor(quantity) or nil
  refresh()
end

local function promptQuantity(data)
  ZO_Dialogs_ShowDialog(
    QUANTITY_DIALOG,
    { itemId = data.itemId, quantity = data.quantity },
    { mainTextParams = { data.link } }
  )
end

--TODO: use LibPrice?
local function getMM(itemLink)
  if not MasterMerchant then
    return 0
  end

  local theIID = string.match(itemLink, "|H.-:item:(.-):")
  local itemIndex = MasterMerchant.makeIndexFromLink(itemLink)
  local tipStats = MasterMerchant:toolTipStats(tonumber(theIID), itemIndex, true, true)
  if tipStats.avgPrice then
    return tipStats.avgPrice
  else
    return 0
  end
end

function FurnitureShoppingListWindow:New(control)
  local manager = ZO_Object.New(self)

  manager.control = control

  return manager
end

function FurnitureShoppingListRecipients:New(control)
  local manager = ZO_SortFilterList.New(self, control)

  ZO_ScrollList_AddDataType(manager.list, 1, "FurnitureShoppingListRecipientsRow", 30, function(control, data)
    manager:SetupRow(control, data)
  end)
  ZO_ScrollList_EnableHighlight(manager.list, "ZO_ThinListHighlight")
  ZO_ScrollList_AddCommitOnHeightChange(manager.list)

  manager:SetAlternateRowBackgrounds(true)

  manager.control = control

  manager.mm = GetControl(control, "MM")
  manager.status = GetControl(control, "Status")

  control.container = manager
  manager.masterList = {}
  manager.sortHeaderGroup:SelectHeaderByKey("name")

  return manager
end

function FurnitureShoppingListRecipients:SetupRow(control, data)
  ZO_SortFilterList.SetupRow(self, control, data)

  control:SetHandler("OnMouseUp", function(control, button, upInside, linkText)
    self:OnRowMouseUp(control, button, upInside, linkText)
  end)

  GetControl(control, "Name"):SetText(data.link)
  GetControl(control, "Need"):SetText(data.need)
  GetControl(control, "Price"):SetText(data.price)
end

function FurnitureShoppingListRecipients:BuildMasterList()
  ZO_ClearNumericallyIndexedTable(self.masterList)

  local mm_total = 0

  local LFC = getLibrary()
  local status = nil
  if not LFC then
    status = GetString(FSL_REQUIRES_FC)
  elseif not LFC.IsReady() then
    status = GetString(FSL_DB_NOT_READY)
    LFC.OnReady(refresh)
  elseif SAVED then
    for _, total in pairs(materialTotals(LFC, SAVED.items)) do
      local need = total.need
      if subtractOwned then
        local a, b, c = GetItemLinkStacks(total.link)
        need = zo_max(need - (a + b + c), 0)
      end

      if need > 0 then
        local cost = getMM(total.link) or 0
        local this_row = zo_floor(cost * need)
        mm_total = mm_total + this_row
        table.insert(self.masterList, {
          name = zo_strformat("<<t:1>>", GetItemLinkName(total.link)),
          link = total.link,
          need = need,
          price = this_row,
        })
      end
    end
  end
  self.status:SetText(status or "")
  self.status:SetHidden(status == nil)

  self.mm:SetText((nil ~= MasterMerchant and "MM: " .. mm_total .. "g") or "")
end

function FurnitureShoppingListRecipients:FilterScrollList()
  local scrollData = ZO_ScrollList_GetDataList(self.list)
  ZO_ClearNumericallyIndexedTable(scrollData)

  for i = 1, #self.masterList do
    table.insert(scrollData, ZO_ScrollList_CreateDataEntry(1, self.masterList[i]))
  end
end

function FurnitureShoppingListRecipients:SortScrollList()
  local scrollData = ZO_ScrollList_GetDataList(self.list)
  table.sort(scrollData, function(a, b)
    return ZO_TableOrderingFunction(a.data, b.data, self.currentSortKey, RECIPIENTS_SORT_KEYS, self.currentSortOrder)
  end)
end

function FurnitureShoppingListRecipients:ColorRow(control, data, mouseIsOver) end

function FurnitureShoppingListRecipients:OnRowMouseUp(control, button, upInside, linkText)
  if button == 2 and linkText then
    if not self.unlockSelectionCallback then
      self.unlockSelectionCallback = function()
        self:UnlockSelection()
      end
    end
    SetMenuHiddenCallback(self.unlockSelectionCallback)
    self:LockSelection()
  end
end

function FurnitureShoppingListItems:New(control)
  local manager = ZO_SortFilterList.New(self, control)

  ZO_ScrollList_AddDataType(manager.list, 1, "FurnitureShoppingListItemRow", 30, function(rowControl, data)
    manager:SetupRow(rowControl, data)
  end)
  ZO_ScrollList_EnableHighlight(manager.list, "ZO_ThinListHighlight")
  ZO_ScrollList_AddCommitOnHeightChange(manager.list)
  manager:SetAlternateRowBackgrounds(true)

  manager.masterList = {}
  manager.sortHeaderGroup:SelectHeaderByKey("name")

  return manager
end

function FurnitureShoppingListItems:SetupRow(control, data)
  ZO_SortFilterList.SetupRow(self, control, data)

  -- left click: qty; right click: edit+rm
  control:SetHandler("OnMouseUp", function(_, button, upInside)
    if not upInside then
      return
    end
    if button == MOUSE_BUTTON_INDEX_LEFT then
      promptQuantity(data)
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
      ClearMenu()
      AddCustomMenuItem(GetString(FSL_CHANGE_QUANTITY), function()
        promptQuantity(data)
      end)
      AddCustomMenuItem(GetString(FSL_REMOVE_ITEM), function()
        setQuantity(data.itemId, 0)
      end)
      ShowMenu(control)
    end
  end)

  GetControl(control, "Name"):SetText(data.link)
  GetControl(control, "Quantity"):SetText(data.quantity)
end

function FurnitureShoppingListItems:BuildMasterList()
  ZO_ClearNumericallyIndexedTable(self.masterList)

  for itemId, quantity in pairs(SAVED and SAVED.items or {}) do
    local link = itemLinkFromId(itemId)
    table.insert(
      self.masterList,
      { itemId = itemId, link = link, name = zo_strformat("<<t:1>>", GetItemLinkName(link)), quantity = quantity }
    )
  end
end

FurnitureShoppingListItems.FilterScrollList = FurnitureShoppingListRecipients.FilterScrollList
FurnitureShoppingListItems.ColorRow = FurnitureShoppingListRecipients.ColorRow -- keeps the links' quality colour

function FurnitureShoppingListItems:SortScrollList()
  local scrollData = ZO_ScrollList_GetDataList(self.list)
  table.sort(scrollData, function(a, b)
    return ZO_TableOrderingFunction(a.data, b.data, self.currentSortKey, ITEMS_SORT_KEYS, self.currentSortOrder)
  end)
end

function FurnitureShoppingListItemsRow_OnMouseEnter(control)
  SL_ITEMS:EnterRow(control)
  local data = ZO_ScrollList_GetData(control)
  if data then
    InitializeTooltip(ItemTooltip, control, RIGHT, -5, 0, LEFT)
    ItemTooltip:SetLink(data.link)
  end
end

function FurnitureShoppingListItemsRow_OnMouseExit(control)
  ClearTooltip(ItemTooltip)
  SL_ITEMS:ExitRow(control)
end

function FurnitureShoppingListItems_OnInitialized(self)
  SL_ITEMS = FurnitureShoppingListItems:New(self)
end

function FurnitureShoppingListWindow_Toggle()
  SL_WINDOW.control:SetHidden(not SL_WINDOW.control:IsHidden())
  -- materials are only queried for an open window
  if not SL_WINDOW.control:IsHidden() then
    refresh()
  end
end

function FurnitureShoppingListRecipientsRow_OnMouseEnter(control)
  SL_RECIPIENTS:EnterRow(control)
end

function FurnitureShoppingListRecipientsRow_OnMouseExit(control)
  SL_RECIPIENTS:ExitRow(control)
end

function FurnitureShoppingListLabelField_OnMouseEnter(control)
  if control:WasTruncated() then
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, 0)
    SetTooltipText(InformationTooltip, control:GetText())
  end

  local row = control:GetParent()
  zo_callHandler(row, "OnMouseEnter")
end

function FurnitureShoppingListLabelField_OnMouseExit(control)
  ClearTooltip(InformationTooltip)

  local row = control:GetParent()
  zo_callHandler(row, "OnMouseExit")
end

function FurnitureShoppingListWindowCloseButton_OnClicked(control)
  SL_WINDOW.control:SetHidden(true)
end

function FurnitureShoppingListLabelField_OnLinkMouseUp(control, button, linkText)
  ZO_LinkHandler_OnLinkMouseUp(linkText, button, control)

  local row = control:GetParent()
  zo_callHandler(row, "OnMouseUp", button, true, linkText)
end

function FurnitureShoppingListWindow_OnInitialized(self)
  SL_WINDOW = FurnitureShoppingListWindow:New(self)
end

function FurnitureShoppingListRecipients_OnInitialized(self)
  SL_RECIPIENTS = FurnitureShoppingListRecipients:New(self)
end

function FurnitureShoppingList_ClearButton_OnClicked(control)
  if SAVED then
    ZO_ClearTable(SAVED.items)
  end

  refresh()
end

-- toggles between full mats and the difference
function FurnitureShoppingList_RemoveOwn_OnClicked(control)
  subtractOwned = not subtractOwned
  control:SetText(GetString(subtractOwned and SI_SHOPPINGLIST_FULL or SI_SHOPPINGLIST_OWN))

  SL_RECIPIENTS:RefreshData()
  refreshOutput()
end

--- Adds item to the list, quantity defaults to 1; anything below 1 is ignored. showWindow opens the window once the item is added
local function addItem(itemLink, quantity, showWindow)
  quantity = zo_floor(tonumber(quantity) or 1)
  if quantity < 1 then
    return
  end
  withLibrary(function(LFC)
    local itemId = craftableItemId(LFC, itemLink)
    if not itemId then
      CHAT_SYSTEM:AddMessage(GetString(FSL_NOT_VALID_ITEM))
      return
    end
    setQuantity(itemId, (SAVED.items[itemId] or 0) + quantity)
    if showWindow then
      SL_WINDOW.control:SetHidden(false)
    end -- setQuantity has refreshed both panes
  end)
end

-- no window: callers of the API may add in bulk
function FurnitureShoppingList.Add(itemLink, quantity)
  addItem(itemLink, quantity, false)
end

-- asks for a quantity (prefilled with 1, Enter confirms), then Add
function FurnitureShoppingList.PromptAdd(itemLink)
  ZO_Dialogs_ShowDialog(QUANTITY_DIALOG, { itemLink = itemLink }, { mainTextParams = { itemLink } })
end

-- Print: the list as pages that each fit one chat message or one mail, shown in the output window
local PAGE_LIMIT = { chat = MAX_TEXT_CHAT_INPUT_CHARACTERS, mail = MAIL_MAX_BODY_CHARACTERS }
local PAGE_COUNTER = "(%d/%d)"
local printPages, printPage = {}, 1

-- "FSL (2/4)": what a mail of several is titled; a single one is just "FSL"
local function pageTitle(page, pages)
  return pages > 1 and "FSL " .. PAGE_COUNTER:format(page, pages) or "FSL"
end

-- tokens packed into pages of at most `limit` bytes (pagination on overflow).
-- First one like "FSL (1/4): " so users see where the list starts, the others are just the counter "(2/4): "
local function paginate(tokens, separator, limit, counted)
  local function pack(room)
    local pages, current = {}, nil
    for _, token in ipairs(tokens) do
      if current and #current + #separator + #token <= room then
        current = current .. separator .. token
      else
        pages[#pages + 1] = current
        current = token
      end
    end
    pages[#pages + 1] = current
    return pages
  end
  local pages = pack(limit)
  if counted and #pages > 1 then
    pages = pack(limit - #(pageTitle(999, 999) .. ": "))
    for i, page in ipairs(pages) do
      pages[i] = (i == 1 and pageTitle(i, #pages) or PAGE_COUNTER:format(i, #pages)) .. ": " .. page
    end
  end
  return pages
end

local function showPrintPage()
  printPage = zo_clamp(printPage, 1, zo_max(#printPages, 1))
  FurnitureShoppingListOutputEdit:SetText(printPages[printPage] or "")
  FurnitureShoppingListOutputPage:SetText(printPage .. "/" .. zo_max(#printPages, 1))
  FurnitureShoppingListOutputPrevButton:SetEnabled(printPage > 1)
  FurnitureShoppingListOutputNextButton:SetEnabled(printPage < #printPages)
  FurnitureShoppingListOutputSendButton:SetEnabled(#printPages > 0)
  FurnitureShoppingListOutputSendButton:SetText(
    GetString(SAVED.print.mail and SI_FSL_PRINT_TO_MAIL or SI_FSL_PRINT_TO_CHAT)
  )
end

-- what both panes show, in their order, so "Subtract Owned" applies here too
local function buildPrintPages()
  local options = SAVED.print
  local function shown(row)
    -- bracket style, as chat links look
    return options.links and (row.link:gsub("^|H%d", "|H1")) or row.name
  end
  local tokens = {}
  for _, entry in ipairs(ZO_ScrollList_GetDataList(SL_RECIPIENTS.list)) do
    tokens[#tokens + 1] = shown(entry.data) .. ": " .. entry.data.need
  end
  if options.furnishings and #tokens > 0 then
    local label = GetString(FSL_PRINT_FOR) .. " "
    for _, entry in ipairs(ZO_ScrollList_GetDataList(SL_ITEMS.list)) do
      tokens[#tokens + 1] = label .. entry.data.quantity .. "x " .. shown(entry.data)
      label = ""
    end
  end
  if options.mail then
    printPages = paginate(tokens, "\n", PAGE_LIMIT.mail) -- the subject carries the page number
  else
    printPages = paginate(tokens, ", ", PAGE_LIMIT.chat, true)
  end
  showPrintPage()
end

-- the list changed while the output window is open
function refreshOutput()
  if FurnitureShoppingListOutput and not FurnitureShoppingListOutput:IsHidden() then
    buildPrintPages()
  end
end

function FurnitureShoppingList_Print_OnClicked(control)
  local function checkbox(name, key, label)
    local button = FurnitureShoppingListOutput:GetNamedChild(name)
    ZO_CheckButton_SetLabelText(button, GetString(label))
    ZO_CheckButton_SetCheckState(button, SAVED.print[key] == true)
    ZO_CheckButton_SetToggleFunction(button, function(_, checked)
      SAVED.print[key] = checked
      printPage = 1
      buildPrintPages()
    end)
  end
  checkbox("Links", "links", SI_FSL_PRINT_LINKS)
  checkbox("Furnishings", "furnishings", SI_FSL_PRINT_FURNISHINGS)
  checkbox("Mail", "mail", SI_FSL_PRINT_MAIL)
  printPage = 1
  FurnitureShoppingListOutput:SetHidden(false)
  buildPrintPages()
end

function FurnitureShoppingList_CloseOutput_OnClicked(control)
  FurnitureShoppingListOutput:SetHidden(true)
end

function FurnitureShoppingList_OutputPage_OnClicked(step)
  printPage = printPage + step
  showPrintPage()
end

-- puts the shown page into the chat input or a new mail and moves on; sending stays with the player
function FurnitureShoppingList_OutputSend_OnClicked(control)
  local page = printPages[printPage]
  if not page then
    return
  end
  if not SAVED.print.mail then
    StartChatInput(page)
    FurnitureShoppingList_OutputPage_OnClicked(1)
    return
  end
  local title = pageTitle(printPage, #printPages)
  local function toMail()
    -- don't overwrite a draft; the subject is only set once the body is known to be free
    if MAIL_SEND.body:GetText() ~= "" then
      CHAT_SYSTEM:AddMessage(GetString(FSL_MAIL_NOT_EMPTY))
    else
      MAIL_SEND.subject:SetText(title)
      MAIL_SEND.body:SetText(page)
      FurnitureShoppingList_OutputPage_OnClicked(1)
    end
  end
  if SCENE_MANAGER:IsShowing("mailSend") then
    toMail()
  else
    MAIN_MENU_KEYBOARD:ShowScene("mailSend")
    SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, toMail)
  end
end

function FurnitureShoppingList_OpenImport_OnClicked(control)
  FurnitureShoppingListImportStatus:SetText("")
  FurnitureShoppingListImport:SetHidden(false)
  FurnitureShoppingListImportEdit:TakeFocus()
end

function FurnitureShoppingList_CloseImport_OnClicked(control)
  FurnitureShoppingListImport:SetHidden(true)
end

-- each new furnishing is added once; reports counts only
function FurnitureShoppingList_Import_OnClicked(control)
  local ids = parseListText(FurnitureShoppingListImportEdit:GetText())
  withLibrary(function(LFC)
    local added, duplicates, unknown, notCraftable = 0, 0, 0, 0
    for _, id in ipairs(ids) do
      local entry = LFC.GetEntry(id) -- a blueprint id resolves to its furnishing
      if not entry then
        unknown = unknown + 1
      elseif not next(LFC.GetIngredients(entry.id, entry)) then
        notCraftable = notCraftable + 1
      elseif SAVED.items[entry.id] then
        duplicates = duplicates + 1
      else
        SAVED.items[entry.id] = 1
        added = added + 1
      end
    end
    refresh()
    FurnitureShoppingListImportEdit:SetText("")
    FurnitureShoppingListImportStatus:SetText(
      zo_strformat(GetString(FSL_IMPORT_RESULT), added, duplicates, unknown, notCraftable)
    )
  end)
end

function FurnitureShoppingListAdd_Crafting()
  if not PROVISIONER_FRAGMENT:IsShowing() then
    return
  end
  local li, ri = PROVISIONER:GetSelectedRecipeListIndex(), PROVISIONER:GetSelectedRecipeIndex()
  FurnitureShoppingList.PromptAdd(ZO_LinkHandler_CreateChatLink(GetRecipeResultItemLink, li, ri))
end

function FurnitureShoppingListWindow:InventorySlot_ShowContextMenu(rowControl)
  local bag, slot = ZO_Inventory_GetBagAndIndex(rowControl)
  local slotType = ZO_InventorySlot_GetType(rowControl)

  local link = GetItemLink(bag, slot)

  if link and canShopFor(link) then
    zo_callLater(function()
      AddCustomMenuItem(GetString(FSL_ADD_TO_LIST), function()
        FurnitureShoppingList.PromptAdd(link)
      end)
      ShowMenu(rowControl)
    end, 50)
  end
end

local function OnAddonLoaded(eventCode, addonName)
  if addonName ~= ADDON_NAME then
    return
  end

  SLASH_COMMANDS["/sl"] = FurnitureShoppingListWindow_Toggle
  SLASH_COMMANDS["/fsl"] = FurnitureShoppingListWindow_Toggle

  SAVED = ZO_SavedVars:NewAccountWide("FurnitureShoppingListSV", 1, nil, { items = {}, print = { links = true } })
  SL_ITEMS:RefreshData()

  local window = SL_WINDOW.control
  local function saveFrame()
    SAVED.window =
      { left = window:GetLeft(), top = window:GetTop(), width = window:GetWidth(), height = window:GetHeight() }
  end
  window:SetHandler("OnMoveStop", saveFrame)
  window:SetHandler("OnResizeStop", saveFrame)
  local frame = SAVED.window
  if frame then
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, frame.left, frame.top)
    window:SetDimensions(frame.width, frame.height)
  end

  -- one dialog for both: data.itemLink adds, data.itemId sets that item's quantity (enter 0 to remove an item)
  local dialog = FurnitureShoppingListQuantityDialog
  local title = dialog:GetNamedChild("Title")
  title:SetFont("$(STONE_TABLET_FONT)|28|soft-shadow-thick")
  title:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
  local spinner = ZO_Spinner:New(dialog:GetNamedChild("Spinner"), 1, 9999)
  local edit = dialog:GetNamedChild("SpinnerDisplay")
  edit:SetMaxInputChars(4)
  edit:SetHandler("OnEnter", function()
    edit:LoseFocus() -- spinner takes typed num on focus loss
    ZO_Dialogs_ButtonKeybindPressed("DIALOG_PRIMARY")
  end)
  edit:SetHandler("OnEscape", function()
    ZO_Dialogs_ButtonKeybindPressed("DIALOG_NEGATIVE")
  end)

  local function confirmQuantity()
    -- accepted with the field still focused: take what is typed there
    local typed = tonumber(edit:GetText())
    if typed then
      spinner:SetValue(typed)
    end
    local quantity = spinner:GetValue()
    if dialog.data.itemId then
      setQuantity(dialog.data.itemId, quantity)
    else
      addItem(dialog.data.itemLink, quantity, true) -- an interactive add, so show the result
    end
  end
  ZO_Dialogs_RegisterCustomDialog(QUANTITY_DIALOG, {
    customControl = dialog,
    title = { text = SI_FSL_QUANTITY_TITLE },
    mainText = { text = SI_FSL_QUANTITY_TEXT },
    setup = function(_, data)
      spinner:SetMinMax(data.itemId and 0 or 1, 9999)
      spinner:SetValue(data.quantity or 1, true)
      edit:TakeFocus()
      edit:SelectAll()
    end,
    finishedCallback = function()
      edit:LoseFocus()
    end,
    buttons = {
      { control = dialog:GetNamedChild("Accept"), text = SI_DIALOG_ACCEPT, callback = confirmQuantity },
      { control = dialog:GetNamedChild("Cancel"), text = SI_DIALOG_CANCEL },
    },
  })

  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

  -- stolen magic!!!
  local original_OnLinkMouseUp = ZO_LinkHandler_OnLinkMouseUp
  ZO_LinkHandler_OnLinkMouseUp = function(itemLink, button, control)
    if type(itemLink) == "string" and #itemLink > 0 then
      local handled = LINK_HANDLER:FireCallbacks(
        LINK_HANDLER.LINK_MOUSE_UP_EVENT,
        itemLink,
        button,
        ZO_LinkHandler_ParseLink(itemLink)
      )
      if not handled then
        original_OnLinkMouseUp(itemLink, button, control)
        if button == 2 and itemLink ~= "" then
          if canShopFor(itemLink) then
            AddCustomMenuItem(GetString(FSL_ADD_TO_LIST), function()
              FurnitureShoppingList.PromptAdd(itemLink)
            end)
            ShowMenu(control)
          end
        end
      end
    end
  end

  ZO_PreHook("ZO_InventorySlot_ShowContextMenu", function(rowControl)
    SL_WINDOW:InventorySlot_ShowContextMenu(rowControl)
  end)

  local strip = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,

    {
      name = GetString(FSL_ADD_TO_LIST),
      callback = FurnitureShoppingListAdd_Crafting,
      keybind = "SL_ADD",

      visible = function()
        return PROVISIONER:CanPreviewRecipe(PROVISIONER.recipeTree:GetSelectedData())
      end,
    },
  }

  PROVISIONER_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
    if newState == SCENE_SHOWN then
      KEYBIND_STRIP:AddKeybindButtonGroup(strip)
    elseif newState == SCENE_HIDING then
      KEYBIND_STRIP:RemoveKeybindButtonGroup(strip)
    end
  end)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
