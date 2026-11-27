local L = MWC.L
MWC.UI = {}

-- The keybinding keeps its first name (MWB_TOGGLE): the game stores the key a player bound under it.
ZO_CreateStringId("SI_BINDING_NAME_MWB_TOGGLE", L.BINDING_TOGGLE)

-- Texts of the windows' fixed controls (UI.xml carries none: they come from the language file).
local CONTROL_TEXTS = {
  MWC_KeyWindowTitle = "KEEP_MATERIALS", MWC_KeyWindowHint = "KEEP_HINT",
  MWC_TotalsWindowTitle = "SESSION_TOTALS", MWC_TotalsWindowHint = "SESSION_TOTALS_HINT",
  MWC_WindowKeyItems = "KEEP_MATERIALS", MWC_WindowDeselectUnprofitable = "DESELECT_KEPT",
  MWC_WindowPanelStatsReset = "RESET_SESSION", MWC_WindowPanelStatsTotals = "BUTTON_SESSION_TOTALS",
  MWC_WindowPanelTurnInWithdraw = "BUTTON_WITHDRAW_READY", MWC_WindowPanelTurnInStart = "BUTTON_START",
  MWC_WindowPanelTurnInDeposit = "BUTTON_DEPOSIT_LEFTOVERS", MWC_WindowPanelTurnInImport = "BUTTON_IMPORT",
  MWC_WindowPanelTurnInNextTitle = "NEXT_STEP",
  MWC_WindowMaterialsToggle = "BUTTON_MATERIALS", MWC_WindowStatsToggle = "BUTTON_STATS",
  MWC_WindowTurnInToggle = "BUTTON_TURN_IN", MWC_WindowCraft = "BUTTON_CRAFT", MWC_WindowStop = "BUTTON_STOP",
  MWC_WindowDepositAll = "BUTTON_DEPOSIT_ALL", MWC_WindowWithdrawAll = "BUTTON_WITHDRAW_ALL",
  MWC_WindowWithdrawMarked = "BUTTON_WITHDRAW_MARKED", MWC_WindowOpenSealed = "BUTTON_OPEN_SEALED",
  MWC_WindowDepositWrits = "BUTTON_DEPOSIT_WRITS", MWC_WindowWithdrawSealed = "BUTTON_WITHDRAW_SEALED",
  MWC_WindowStoreMarked = "BUTTON_STORE_MARKED",
}

local function ApplyControlTexts()
  for name, key in pairs(CONTROL_TEXTS) do
    local control = _G[name]
    if control and L[key] then
      control:SetText(L[key])
    end
  end
end

-- Texts that don't fit (longer translations): the font gets smaller step by step until they do. Only text
-- that overflows is touched, so English keeps its fonts. Buttons always; labels when marked with mwcFit (one-line
-- labels of a fixed width: wrapped hints must not shrink).
local FIT_BUTTON_FONT = "$(BOLD_FONT)|%d|soft-shadow-thick"
local FIT_LABEL_FONT = "$(MEDIUM_FONT)|%d|soft-shadow-thin"
local FIT_SIZES = { 20, 19, 18, 17, 16, 15, 14, 13, 12 }
local FIT_BUTTON_PADDING = 14

-- The text's width on one line: a fixed-width label wraps or cuts it, so its rendered width can't tell.
local function OneLineWidth(label, text)
  local width = label:GetTextWidth()
  local ok, full = pcall(label.GetStringWidth, label, text)
  if ok and type(full) == "number" then
    width = math.max(width, full / (GetUIGlobalScale and GetUIGlobalScale() or 1))
  end
  return width
end

local function FitText(control, label, room, fontPattern)
  local text = label:GetText() or ""
  if text == "" or control.mwcFitText == text then return end
  control.mwcFitText = text
  if room <= 0 or OneLineWidth(label, text) <= room then return end
  local ok, height = pcall(label.GetFontHeight, label)
  local current = ok and type(height) == "number" and height or 99
  for _, size in ipairs(FIT_SIZES) do
    if size < current then
      control:SetFont(string.format(fontPattern, size))
      if OneLineWidth(label, text) <= room then return end
    end
  end
end

local function FitButton(button)
  local label = button.GetLabelControl and button:GetLabelControl()
  if label then
    FitText(button, label, button:GetWidth() - FIT_BUTTON_PADDING, FIT_BUTTON_FONT)
  end
end

-- Every text button and marked label of our windows, the list rows left out.
local function FitTextsIn(control)
  for i = 1, control:GetNumChildren() do
    local child = control:GetChild(i)
    if child and child:GetName() ~= "MWC_WindowList" then
      local kind = child:GetType()
      if kind == CT_BUTTON then
        FitButton(child)
      elseif kind == CT_LABEL and child.mwcFit then
        FitText(child, child, child:GetWidth(), FIT_LABEL_FONT)
      else
        FitTextsIn(child)
      end
    end
  end
end

local function FitButtons()
  for _, name in ipairs({ "MWC_Window", "MWC_KeyWindow", "MWC_TotalsWindow" }) do
    if _G[name] then FitTextsIn(_G[name]) end
  end
end

local ROW_TYPE = 1
local ROW_HEIGHT = 34
local MATERIAL_ROW_HEIGHT = 26
local FOOTER_HEIGHT = 56
-- Narrower would squeeze the name column to nothing once the Set/Style/Trait columns are shown.
local MIN_WIDTH, MIN_HEIGHT = 1100, 560
local PANEL_HEIGHTS = { Materials = 285, Stats = 160, TurnIn = 252 }
-- The Materials panel can be resized by dragging the splitter above it; the list keeps at least this much.
local RESIZABLE_PANELS = { Materials = true }
local MIN_PANEL_HEIGHT, MIN_LIST_HEIGHT = 140, 100
local LIST_TOP = 130
local PANEL_GAP = 6
-- Inventory events come in bursts; refresh once after they calm down.
local REFRESH_DELAY_MS = 400
-- Same order and icons as the game's craft bag tabs.
local TABS = {
  { type = "all", label = L.TAB_ALL, icon = "inventory_tabicon_all" },
  { type = "blacksmithing", label = L.CRAFT_TAB.blacksmithing, icon = "inventory_tabicon_craftbag_blacksmithing" },
  { type = "clothier", label = L.CRAFT_TAB.clothier, icon = "inventory_tabicon_craftbag_clothing" },
  { type = "woodworking", label = L.CRAFT_TAB.woodworking, icon = "inventory_tabicon_craftbag_woodworking" },
  { type = "jewelry", label = L.CRAFT_TAB.jewelry, icon = "inventory_tabicon_craftbag_jewelrycrafting" },
  { type = "alchemy", label = L.CRAFT_TAB.alchemy, icon = "inventory_tabicon_craftbag_alchemy" },
  { type = "enchanting", label = L.CRAFT_TAB.enchanting, icon = "inventory_tabicon_craftbag_enchanting" },
  { type = "provisioning", label = L.CRAFT_TAB.provisioning, icon = "inventory_tabicon_craftbag_provisioning" },
  { type = "sealed", label = L.TAB_SEALED, icon = "inventory_tabicon_quest" },
}
local TAB_ICON_PATH = "esoui/art/inventory/%s_%s.dds"
-- Tabs touch each other (no dead space between them); each has a little clickable padding instead.
local TAB_SPACING = 0
local TAB_ICON_WIDTH = 39
local TAB_PADDING = 10
-- Gap between a checkbox's label and the next control to its right in the toolbar.
local TOOLBAR_GAP = 20
local TOOLBAR_CHECKBOXES = { "IncludeBank", "IncludeBag", "ShowSkipped", "ShowCompleted", "ShowEvent" }
-- Footer action buttons by location and by what the tab lists.
local ALL_ACTIONS = { "Craft", "OpenSealed", "WithdrawMarked", "WithdrawAll", "DepositAll", "WithdrawSealed", "DepositWrits", "StoreMarked", "Stop" }
local ACTIONS = {
  field = { writs = { "Craft" }, sealed = { "OpenSealed" } },
  bank = { writs = { "WithdrawMarked", "WithdrawAll", "DepositAll" }, sealed = { "WithdrawSealed", "DepositWrits" } },
  chest = { writs = { "StoreMarked" }, sealed = { "StoreMarked" } },
}
local PANELS = { "Materials", "Stats", "TurnIn" }
local GOLD = { 0.77, 0.76, 0.62, 1 }

local C = MWC.COLOR
local Color = MWC.Colorize

local window, list, materialsList, panel
local tabControls = {}
local visibleGroups = {}
local visibleSealed = {}
local allGroups = {}
local refreshPending = false
local lastTotals, lastSummary = nil, ""
-- Sealed tab: how many are to be opened and how many more were wanted but don't fit in the bag.
local sealedLimit = nil
local headerTitles = {}
local ApplyHeaderTitles -- defined with the sorting code, used by the layout code above it
local RefreshDeselectButton -- defined next to Refresh

local function Number(value)
  return ZO_CommaDelimitNumber(zo_round(value))
end

local function SetQuality(texture, quality)
  texture:SetColor(GetItemQualityColor(quality):UnpackRGBA())
end

-- Writs table ---------------------------------------------------------------

-- A recipe's writs are shown in up to four rows ("parts"): active quests (writ used, quest open), writs in
-- the bags, handed-in writs, and writs whose quest was abandoned or lost track of. Crafted items go to the
-- active quests first, as they are handed in with them.
local PART_ORDER = { "active", "inventory", "completed", "closed" }

local function ActiveReady(group)
  return group.ready and math.min(group.activeCount, group.ready) or nil
end

local function QueuedReady(group)
  return group.ready and math.max(0, math.min(group.queued, group.ready - group.activeCount)) or nil
end

-- Row tint. Bag writs: red when they can't be crafted, orange when they'd spend a kept material.
local function RowTint(group, part)
  if part == "active" then return "purple" end
  if part == "completed" then return "green" end
  if part == "closed" then return "grey" end
  -- A holiday writ with a problem (a recipe not known) keeps its own look, only dimmed; the red mark on its icon
  -- says why.
  if group.problem and group.event then return nil end
  if group.problem then return "red" end
  if group.kept then return "orange" end
end

local TINT_HEX = { red = C.RED, orange = C.ORANGE, purple = C.PURPLE, green = C.GREEN, grey = C.GREY }

local function NameWithCounters(group, part)
  local tint = RowTint(group, part)
  local text = tint and Color(TINT_HEX[tint], group.name) or group.name
  if part == "active" then
    return text .. " " .. Color(C.PURPLE, string.format(L.ROW_ACTIVE_QUEST, group.activeCount))
  elseif part == "completed" then
    return text .. " " .. Color(C.GREEN, string.format(L.ROW_TURNED_IN, group.completedCount))
  elseif part == "closed" then
    return text .. " " .. Color(C.GREY, string.format("(%d %s)", group.closedCount, group.closedState or "unknown"))
  end
  text = text .. " " .. Color(C.BLUE, "(" .. group.inBank .. ")") .. " " .. Color(C.YELLOW, "(" .. group.inBag .. ")")
  if group.readyBag then
    -- What the crafted items cover for these writs, after the active quests took theirs (bag items first).
    local bag = math.max(0, group.readyBag - group.activeCount)
    local bank = group.readyBank - math.max(0, group.activeCount - group.readyBag)
    text = text .. " " .. Color(C.GREEN, string.format("(%d/%d)", bag, math.max(0, bank)))
  end
  return text .. MWC.Report.Warnings(group, true)
end

-- Vouchers for one writ of the group ("40-47" when its writs differ), shown even for unqueued writs.
local function VoucherText(group)
  if not group.voucherMax then return "—" end
  if group.voucherMin == group.voucherMax then return tostring(group.voucherMax) end
  return string.format("%d-%d", group.voucherMin, group.voucherMax)
end

local function SetReady(row, ready, total)
  local label = row:GetNamedChild("Ready")
  local bar = row:GetNamedChild("ReadyBar")
  local fill = row:GetNamedChild("ReadyFill")
  if not ready then
    label:SetText("—")
    bar:SetHidden(true)
    fill:SetHidden(true)
    return
  end
  local text = string.format("%d/%d", ready, total)
  label:SetText(ready >= total and Color(C.GREEN, text) or text)
  bar:SetHidden(false)
  local width = total > 0 and bar:GetWidth() * ready / total or 0
  fill:SetWidth(width)
  fill:SetHidden(width <= 0)
end

-- A step that can't go further is hidden rather than dimmed: the hover handlers recolor the label, which made
-- dimming unreliable. Hidden controls keep their place, so the columns don't move.
local function SetStepEnabled(label, enabled)
  label:SetHidden(not enabled)
  label:SetMouseEnabled(enabled)
  label:SetColor(unpack(GOLD))
end

local function SetSteps(row, canDecrease, canIncrease)
  SetStepEnabled(row:GetNamedChild("Minus"), canDecrease)
  SetStepEnabled(row:GetNamedChild("Plus"), canIncrease)
end

-- problem: why the writ can't be crafted (a recipe or style not known...): a small red mark over the icon (the
-- game's "new item" mark tinted red, as CraftStore marks what a character still needs), and the reason in the
-- icon's tooltip.
local PROBLEM_ICON = "EsoUI/Art/Inventory/newItem_icon.dds"
local PROBLEM_ICON_SIZE = 18
local PROBLEM_ICON_RGB = { 1, 0.1, 0.1 }

local function SetTypeIcon(row, icon, label, problem)
  local texture = row:GetNamedChild("TypeIcon")
  texture:SetTexture(icon)
  texture:SetHidden(not icon)
  texture.tooltipText = problem and string.format("%s\n%s", label or "", MWC.Colorize(C.RED, problem)) or label
  local mark = row.problemMark
  if not mark then
    if not problem then return end
    mark = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    mark:SetDimensions(PROBLEM_ICON_SIZE, PROBLEM_ICON_SIZE)
    mark:SetAnchor(BOTTOMRIGHT, texture, BOTTOMRIGHT, 6, 4)
    mark:SetTexture(PROBLEM_ICON)
    mark:SetColor(PROBLEM_ICON_RGB[1], PROBLEM_ICON_RGB[2], PROBLEM_ICON_RGB[3], 1)
    mark:SetDrawLayer(DL_OVERLAY)
    row.problemMark = mark
  end
  mark:SetHidden(not (icon and problem))
end

-- Set, Style and Trait columns exist only while gear writs are listed; otherwise the name takes their width.
local GEAR_COLUMNS = { "Set", "Style", "Trait" }
-- Set, Style, Trait and V (vouchers) can be resized by dragging their left border in the header (saved); the
-- recipe name takes what is left, never less than NAME_MIN_WIDTH. Right-click on a border restores the defaults.
local RESIZABLE_COLUMNS = { "Set", "Style", "Trait", "Vouchers" }
local COLUMN_DEFAULT_WIDTH = { Set = 150, Style = 110, Trait = 96, Vouchers = 40 }
local COLUMN_MIN_WIDTH = { Set = 50, Style = 50, Trait = 50, Vouchers = 24 }
local NAME_MIN_WIDTH = 120

local function ColumnWidth(column)
  return MWC.sv.columnWidths and MWC.sv.columnWidths[column] or COLUMN_DEFAULT_WIDTH[column]
end

local function ApplyColumnWidths(row)
  for _, column in ipairs(RESIZABLE_COLUMNS) do
    row:GetNamedChild(column):SetWidth(ColumnWidth(column))
  end
end
local showGearColumns = false

local function LayoutGearColumns(row)
  if row.gearColumnsShown == showGearColumns then return end
  row.gearColumnsShown = showGearColumns
  for _, child in ipairs(GEAR_COLUMNS) do
    row:GetNamedChild(child):SetHidden(not showGearColumns)
  end
  local name = row:GetNamedChild("Name")
  name:ClearAnchors()
  name:SetAnchor(LEFT, row, LEFT, row.nameLeft or 76, 0)
  name:SetAnchor(RIGHT, row:GetNamedChild(showGearColumns and "Set" or "Minus"), LEFT, -10, 0)
end

-- Styled gear writs show a Crown Mimic Stone in the Style cell: bright when it replaces the style material,
-- dim otherwise. Clicking it switches (bag writs only).
local function MimicIcon()
  return (GetItemLinkInfo(MWC.LinkFromItemId(MWC.Gear.MIMIC_STONE_ID)))
end

local function SetGearCells(row, group, part)
  LayoutGearColumns(row)
  ApplyColumnWidths(row)
  row:GetNamedChild("Set"):SetText(group and group.setName or "")
  row:GetNamedChild("Trait"):SetText(group and group.traitName or "")
  local style = row:GetNamedChild("Style")
  local canSwitch = group and group.styled and part == "inventory"
  if group and group.styled and (part == "inventory" or part == "active") then
    style:SetText(string.format("|c%s|t20:20:%s:inheritColor|t|r %s", group.mimic and "FFFFFF" or "4A4A4A",
      MimicIcon(), group.styleName or ""))
  else
    style:SetText(group and group.styleName or "")
  end
  style:SetMouseEnabled(canSwitch and true or false)
end

function MWC.UI.OnStyleClicked(row)
  if MWC.Activity.Current() or not (row.group and row.group.styled and row.part == "inventory") then return end
  MWC.Session.SetMimic(row.group, not row.group.mimic)
end

function MWC.UI.OnStyleEnter(row, label)
  local group = row.group
  if not (group and group.styled) then return end
  ZO_Tooltips_ShowTextTooltip(label, TOP, group.mimic
    and L.MIMIC_ON
    or L.MIMIC_OFF)
end

-- TTC adds its lines to tooltips of real bag slots, so prefer an owned copy of the item.
function MWC.UI.ShowItemTooltip(control, link)
  -- A wider gap keeps the tooltip clear of the window border it would otherwise overlap.
  InitializeTooltip(ItemTooltip, control, LEFT, 32, 0, RIGHT)
  local itemId = GetItemLinkItemId(link)
  if GetSlotStackSize(BAG_VIRTUAL, itemId) > 0 then
    ItemTooltip:SetBagItem(BAG_VIRTUAL, itemId)
    return
  end
  for _, bag in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
    for slot = 0, GetBagSize(bag) - 1 do
      if GetItemId(bag, slot) == itemId then
        ItemTooltip:SetBagItem(bag, slot)
        return
      end
    end
  end
  ItemTooltip:SetLink(link)
end

-- Rows are reused, so the stripe color is set every time: red or orange tint, or the plain stripe.
local TINT_RGB = {
  red = { 0.9, 0.15, 0.15 }, orange = { 0.94, 0.63, 0.16 }, purple = { 0.62, 0.4, 0.95 },
  green = { 0.25, 0.75, 0.3 }, grey = { 0.55, 0.55, 0.55 },
}

local function SetRowBackground(row, odd, tint)
  local bg = row:GetNamedChild("BG")
  local rgb = tint and TINT_RGB[tint]
  if rgb then
    bg:SetColor(rgb[1], rgb[2], rgb[3], odd and 0.22 or 0.16)
    bg:SetHidden(false)
  else
    bg:SetColor(1, 1, 1, 0.04)
    bg:SetHidden(not odd)
  end
end

-- Holiday writ rows: their color on the left (violet: Witches Festival, ice blue: New Life), fading out towards
-- the middle of the row.
local EVENT_GLOW_RGB = {
  witches = { 0.72, 0.45, 1 }, newlife = { 0.45, 0.75, 1 }, deepwinter = { 0.45, 0.75, 1 }, imperial = { 0.45, 0.75, 1 },
}
local EVENT_GLOW_WIDTH, EVENT_GLOW_ALPHA, EVENT_GLOW_DIM_ALPHA = 320, 0.45, 0.4

-- The row's layers are fixed once it has a glow, so it never comes over the icons or the text, whatever order
-- the list draws in: background, then the glow, then the icons (the problem mark is above them).
local function FixRowLayers(row)
  local bg = row:GetNamedChild("BG")
  bg:SetDrawLayer(DL_BACKGROUND)
  bg:SetDrawLevel(0)
  for _, name in ipairs({ "TypeIcon", "Quality" }) do
    local control = row:GetNamedChild(name)
    if control then
      control:SetDrawLayer(DL_CONTROLS)
    end
  end
end

-- dim: writs taken out of the queue (a touch darker; the row's own alpha dims it too). Applied last when a row is
-- set up, after its alpha.
local function SetEventGlow(row, kind, dim)
  local rgb = kind and EVENT_GLOW_RGB[kind]
  local glow = row.eventGlow
  if not glow then
    if not rgb then return end
    FixRowLayers(row)
    glow = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    glow:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    glow:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    glow:SetWidth(EVENT_GLOW_WIDTH)
    glow:SetDrawLayer(DL_BACKGROUND)
    glow:SetDrawLevel(1)
    glow:SetColor(1, 1, 1, 1)
    row.eventGlow = glow
  end
  glow:SetHidden(not rgb)
  if rgb then
    glow:SetVertexColors(VERTEX_POINTS_TOPLEFT + VERTEX_POINTS_BOTTOMLEFT, rgb[1], rgb[2], rgb[3],
      dim and EVENT_GLOW_DIM_ALPHA or EVENT_GLOW_ALPHA)
    glow:SetVertexColors(VERTEX_POINTS_TOPRIGHT + VERTEX_POINTS_BOTTOMRIGHT, rgb[1], rgb[2], rgb[3], 0)
  end
end

local function SetupSealedRow(row, data)
  local sealed = data.sealed
  row.group, row.sealed = nil, sealed
  SetEventGlow(row, nil)
  row:SetAlpha(sealed.enabled and 1 or 0.55)
  SetRowBackground(row, data.odd, nil)
  ZO_CheckButton_SetCheckState(row:GetNamedChild("Check"), sealed.enabled)
  SetQuality(row:GetNamedChild("Quality"), GetItemLinkFunctionalQuality(sealed.link))
  row:GetNamedChild("Name"):SetText(sealed.name
    .. " " .. Color(C.BLUE, "(" .. sealed.inBank .. ")")
    .. " " .. Color(C.YELLOW, "(" .. sealed.inBag .. ")"))
  SetTypeIcon(row, (GetItemLinkInfo(sealed.link)), L.SEALED_WRIT)
  SetGearCells(row, nil, nil)
  local count = string.format("%d/%d", sealed.planned, sealed.inBag)
  row:GetNamedChild("Count"):SetText(sealed.overflow > 0 and Color(C.RED, count) or count)
  SetSteps(row, sealed.planned > 0, sealed.canIncrease)
  SetReady(row, MWC.Sealed.RunProgress(sealed.itemId))
  row:GetNamedChild("Vouchers"):SetText("—")
end

local SetupRowContent

local function SetupRow(row, data)
  SetupRowContent(row, data)
  if data.group then
    SetEventGlow(row, data.group.event, data.part == "inventory" and data.group.queued == 0)
  end
end

SetupRowContent = function(row, data)
  row:GetNamedChild("Check"):SetHidden(false)
  if data.sealed then
    SetupSealedRow(row, data)
    return
  end
  local group, part = data.group, data.part
  row.group, row.part, row.sealed = group, part, nil
  SetRowBackground(row, data.odd, RowTint(group, part))
  SetQuality(row:GetNamedChild("Quality"), group.quality)
  row:GetNamedChild("Name"):SetText(NameWithCounters(group, part))
  SetTypeIcon(row, group.typeIcon, group.typeLabel, group.problem)
  SetGearCells(row, group, part)
  if part == "inventory" then
    row:SetAlpha(group.queued > 0 and 1 or 0.55)
    ZO_CheckButton_SetCheckState(row:GetNamedChild("Check"), group.queued > 0)
    row:GetNamedChild("Count"):SetText(group.inventoryCount == 1 and tostring(group.queued)
      or string.format("%d/%d", group.queued, group.inventoryCount))
    SetSteps(row, group.queued > 0, group.queued < group.inventoryCount)
    SetReady(row, QueuedReady(group), group.queued)
    row:GetNamedChild("Vouchers"):SetText(VoucherText(group))
    return
  end
  -- Past the bag: nothing to queue or skip any more.
  row:SetAlpha(1)
  row:GetNamedChild("Check"):SetHidden(true)
  SetSteps(row, false, false)
  if part == "active" then
    row:GetNamedChild("Count"):SetText(Color(C.PURPLE, group.activeCount))
    SetReady(row, ActiveReady(group), group.activeCount)
    row:GetNamedChild("Vouchers"):SetText(Color(C.PURPLE, VoucherText(group)))
  elseif part == "completed" then
    row:GetNamedChild("Count"):SetText(Color(C.GREEN, group.completedCount))
    SetReady(row, group.completedCount, group.completedCount)
    row:GetNamedChild("Vouchers"):SetText(Color(C.GREEN, VoucherText(group)))
  else
    row:GetNamedChild("Count"):SetText(Color(C.GREY, group.closedCount))
    SetReady(row, nil)
    row:GetNamedChild("Vouchers"):SetText(Color(C.GREY, VoucherText(group)))
  end
end

function MWC.UI.Step(row, delta)
  -- The plan must not change under a running operation.
  if MWC.Activity.Current() then return end
  if row.sealed then
    MWC.Sealed.SetCount(row.sealed, row.sealed.planned + delta)
    return
  end
  if row.part ~= "inventory" then return end
  local group = row.group
  local count = zo_clamp(group.queued + delta, 0, group.inventoryCount)
  if count ~= group.queued then
    MWC.Session.SetSelectedCount(group, count)
  end
end

function MWC.UI.ShowRowMenu(row)
  local group = row.group
  if not group then return end
  ClearMenu()
  if row.part ~= "inventory" then
    AddMenuItem(L.MENU_LINK_WRIT, function() MWC.LinkInChat(group.link) end)
    ShowMenu(row)
    return
  end
  if group.queued < group.inventoryCount then
    AddMenuItem(string.format(L.MENU_QUEUE_ALL, group.inventoryCount),
      function() MWC.Session.SetSelectedCount(group, group.inventoryCount) end)
  end
  if group.recipe then
    local affordable = MWC.Plan.MaxAffordable(group)
    AddMenuItem(string.format(L.MENU_QUEUE_AFFORDABLE, affordable),
      function() MWC.Session.SetSelectedCount(group, affordable) end)
  end
  AddMenuItem(L.MENU_WITHDRAW, function() MWC.Bank.Withdraw({ group }) end)
  AddMenuItem(L.MENU_DEPOSIT, function() MWC.Bank.Deposit({ group }) end)
  AddMenuItem(L.MENU_LINK_WRIT, function() MWC.LinkInChat(group.link) end)
  ShowMenu(row)
end

-- The full set, style and trait names, for cells too narrow to show them.
local function AddGearLine(group)
  if not group.setName then return end
  local parts = { L.TOOLTIP_SET .. group.setName }
  if group.styleName then table.insert(parts, L.TOOLTIP_STYLE .. group.styleName) end
  table.insert(parts, L.TOOLTIP_TRAIT .. (group.traitName or "?"))
  ItemTooltip:AddLine(L.TOOLTIP_PREFIX .. table.concat(parts, "  ·  "), "ZoFontGame", ZO_NORMAL_TEXT:UnpackRGB())
end

function MWC.UI.OnRowEnter(row)
  if not (row.group or row.sealed) then return end
  row:GetNamedChild("Highlight"):SetHidden(false)
  InitializeTooltip(ItemTooltip, row, LEFT, 8, 0, RIGHT)
  if row.sealed then
    ItemTooltip:SetLink(row.sealed.link)
  elseif row.part ~= "inventory" then
    -- The writ item is gone: show it from its saved link, with where it stands.
    local states = { active = { active = true }, completed = { completed = true },
      closed = { abandoned = true, unknown = true } }
    for _, writ in ipairs(row.group.writs) do
      if writ.state and states[row.part][writ.state] then
        ItemTooltip:SetLink(writ.link)
        break
      end
    end
    local lines = {
      active = L.STATE_ACTIVE,
      completed = L.STATE_COMPLETED,
      closed = row.group.closedState == "abandoned" and L.STATE_ABANDONED
        or L.STATE_UNKNOWN,
    }
    ItemTooltip:AddLine(L.TOOLTIP_PREFIX .. lines[row.part], "ZoFontGame", ZO_ColorDef:New(TINT_HEX[RowTint(row.group, row.part)]):UnpackRGB())
    AddGearLine(row.group)
  else
    local writ
    for _, candidate in ipairs(row.group.writs) do
      if not candidate.state then
        writ = candidate
        break
      end
    end
    ItemTooltip:SetBagItem(writ.bag, writ.slot)
    AddGearLine(row.group)
    if row.group.reagentsUnchecked then
      ItemTooltip:AddLine(L.TOOLTIP_PREFIX .. L.TOOLTIP_ALCHEMY_UNCHECKED, "ZoFontGame", ZO_ColorDef:New(C.YELLOW):UnpackRGB())
    end
    if row.group.problem then
      ItemTooltip:AddLine(L.TOOLTIP_PREFIX .. row.group.problem, "ZoFontGame", ZO_ERROR_COLOR:UnpackRGB())
    end
    if row.group.kept then
      local names = {}
      for _, link in ipairs(row.group.kept) do
        table.insert(names, "[" .. MWC.ItemName(link) .. "]")
      end
      ItemTooltip:AddLine(L.TOOLTIP_PREFIX .. L.TOOLTIP_SPENDS_KEPT .. table.concat(names, ", "), "ZoFontGame",
        ZO_ColorDef:New(C.ORANGE):UnpackRGB())
    end
  end
end

function MWC.UI.OnRowExit(row)
  row:GetNamedChild("Highlight"):SetHidden(true)
  ClearTooltip(ItemTooltip)
end

-- Materials panel -----------------------------------------------------------

-- Tabs by material kind; every list is ordered by craft, kind, quality, then name.
local MATERIAL_TABS = { "All", "Base", "Upgrade", "Trait", "Style", "Reagent", "Rune", "Ingredient" }
local KIND_ORDER = { Base = 1, Upgrade = 2, Trait = 3, Style = 4, Reagent = 5, Rune = 6, Ingredient = 7 }
local CRAFT_LABEL = L.CRAFT
local materialTabControls = {}

-- Clicking a column header sorts both material lists by it (again: reverses); the corner button restores
-- the default order: craft, kind, best quality first, name. In the totals window Need and Have hold
-- "used / total" and "left", so they sort by those.
local MATERIAL_SORT_VALUES = {
  Craft = function(m) return m.craftOrder end,
  Name = function(m) return m.sortName end,
  Need = function(m, totals) return totals and m.used or m.need end,
  Have = function(m, totals) return totals and (m.total - m.used) or m.have end,
  Price = function(m) return m.price or -1 end,
  Cost = function(m, totals) return totals and m.totalCost or m.cost end,
}
local MATERIAL_TEXT_COLUMNS = { Craft = true, Name = true }
local MATERIAL_SORT_ARROW = { [true] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortdown.dds|t", [false] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortup.dds|t" }
local materialHeaders = {}

local function DefaultMaterialOrder(a, b)
  if a.craftOrder ~= b.craftOrder then return a.craftOrder < b.craftOrder end
  local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
  if ka ~= kb then return ka < kb end
  if a.quality ~= b.quality then return a.quality > b.quality end
  return a.sortName < b.sortName
end

local function SortMaterials(materials, totals)
  for _, material in ipairs(materials) do
    material.quality = material.quality or GetItemLinkFunctionalQuality(material.link)
    material.sortName = material.sortName or zo_strlower(MWC.ItemName(material.link))
  end
  local sort = MWC.sv.materialsSort
  local value = sort and MATERIAL_SORT_VALUES[sort.column]
  table.sort(materials, function(a, b)
    if value then
      local va, vb = value(a, totals), value(b, totals)
      if va ~= vb then
        if sort.desc then return va > vb end
        return va < vb
      end
    end
    return DefaultMaterialOrder(a, b)
  end)
  return materials
end

local function ApplyMaterialHeaderTitles()
  local sort = MWC.sv.materialsSort
  for _, header in ipairs(materialHeaders) do
    for column, title in pairs(header.titles) do
      local active = sort and sort.column == column
      header.control:GetNamedChild(column):SetText(active and (title .. " " .. MATERIAL_SORT_ARROW[sort.desc]) or title)
    end
  end
end

function MWC.UI.SortMaterialsBy(column)
  local sort = MWC.sv.materialsSort
  if sort and sort.column == column then
    sort.desc = not sort.desc
  else
    MWC.sv.materialsSort = { column = column, desc = not MATERIAL_TEXT_COLUMNS[column] }
  end
  ApplyMaterialHeaderTitles()
  MWC.UI.Refresh("view")
end

function MWC.UI.ResetMaterialsSort()
  MWC.sv.materialsSort = nil
  ApplyMaterialHeaderTitles()
  MWC.UI.Refresh("view")
end

-- Shared by the panel and the totals window: craft, quality bar, icon, colored name, orange tint when kept.
local function SetupMaterialCells(row, data)
  local material = data.material
  row.material = material
  SetRowBackground(row, data.odd, material.key and "orange" or nil)
  row:GetNamedChild("Craft"):SetText(CRAFT_LABEL[material.craft] or "")
  SetQuality(row:GetNamedChild("Quality"), GetItemLinkFunctionalQuality(material.link))
  row:GetNamedChild("Icon"):SetTexture((GetItemLinkInfo(material.link)))
  row:GetNamedChild("Name"):SetText(GetItemQualityColor(GetItemLinkFunctionalQuality(material.link))
    :Colorize("[" .. MWC.ItemName(material.link) .. "]"))
end

local function SetupMaterialRow(row, data)
  local material = data.material
  SetupMaterialCells(row, data)
  row:GetNamedChild("Need"):SetText(Number(material.need))
  local have = Number(material.have)
  row:GetNamedChild("Have"):SetText(material.short and Color(C.RED, have) or have)
  row:GetNamedChild("Price"):SetText(material.price and Number(material.price) or "—")
  row:GetNamedChild("Cost"):SetText(material.price and Number(material.cost) or "—")
end

function MWC.UI.OnMaterialEnter(row)
  if not row.material then return end
  row:GetNamedChild("Highlight"):SetHidden(false)
  MWC.UI.ShowItemTooltip(row, row.material.link)
end

function MWC.UI.OnMaterialClicked(row, button)
  if not row.material then return end
  if button == MOUSE_BUTTON_INDEX_RIGHT then
    MWC.UI.ShowMaterialMenu(row)
  else
    ZO_PopupTooltip_SetLink(row.material.link)
  end
end

function MWC.UI.OnMaterialExit(row)
  row:GetNamedChild("Highlight"):SetHidden(true)
  ClearTooltip(ItemTooltip)
end

function MWC.UI.ShowMaterialMenu(row)
  local material = row.material
  if not material then return end
  ClearMenu()
  AddMenuItem(string.format(L.MENU_SKIP_USING, #material.groups),
    function() MWC.Session.ExcludeGroups(material.groups) end)
  AddMenuItem(L.MENU_LINK, function() MWC.LinkInChat(material.link) end)
  ShowMenu(row)
end

local function RefreshMaterialTabs(counts)
  local current = MWC.sv.materialsTab or "All"
  for _, control in ipairs(materialTabControls) do
    local active = control.tabKey == current
    control:SetText(string.format("%s (%d)", L.KIND[control.tabKey] or control.tabKey, counts[control.tabKey] or 0))
    control:SetColor(unpack(active and { 1, 1, 1, 1 } or GOLD))
    control:GetNamedChild("Underline"):SetHidden(not active)
  end
end

-- When the chosen kind has nothing for these writs (say Reagent after switching to a gear tab), the first
-- kind that has something is shown instead, and stays chosen.
local function EffectiveMaterialsTab(materials)
  local tab = MWC.sv.materialsTab or "All"
  if tab == "All" or #materials == 0 then return tab end
  local present = {}
  for _, material in ipairs(materials) do
    present[material.kind] = true
  end
  if present[tab] then return tab end
  for _, key in ipairs(MATERIAL_TABS) do
    if present[key] then
      MWC.sv.materialsTab = key
      return key
    end
  end
  return tab
end

local function RefreshMaterials(groups)
  local materials = SortMaterials(MWC.Plan.Materials(groups))
  local shortages = MWC.Plan.Shortages(materials)
  local tab = EffectiveMaterialsTab(materials)
  ZO_ScrollList_Clear(materialsList)
  local dataList = ZO_ScrollList_GetDataList(materialsList)
  local counts = { All = #materials }
  local keyCost, totalCost = 0, 0
  for _, material in ipairs(materials) do
    counts[material.kind] = (counts[material.kind] or 0) + 1
    totalCost = totalCost + material.cost
    if material.key then
      keyCost = keyCost + material.cost
    end
    if tab == "All" or material.kind == tab then
      table.insert(dataList, ZO_ScrollList_CreateDataEntry(ROW_TYPE, { material = material, odd = #dataList % 2 == 0 }))
    end
  end
  ZO_ScrollList_Commit(materialsList)
  RefreshMaterialTabs(counts)

  local text
  if not MWC.Price.Available() then
    text = Color(C.YELLOW, L.TTC_MISSING)
  else
    text = string.format(L.MATERIALS_COST, Color(C.ORANGE, L.KEPT), Number(keyCost), Number(totalCost))
  end
  if #shortages > 0 then
    text = text .. Color(C.RED, string.format(L.MATERIALS_MISSING, #shortages))
  end
  panel:GetNamedChild("MaterialsCost"):SetText(text)
end

function MWC.UI.SelectMaterialsTab(key)
  MWC.sv.materialsTab = key
  MWC.UI.Refresh("view")
end

-- Session totals window -------------------------------------------------------
-- Every material the queued writs of the current tab take: spent on what is already crafted, and what is left.

local totalsWindow, totalsList

local function SetupTotalsRow(row, data)
  local material = data.material
  SetupMaterialCells(row, data)
  local usedText = string.format("%s/%s", Number(material.used), Number(material.total))
  row:GetNamedChild("Need"):SetText(material.used >= material.total and Color(C.GREEN, usedText) or usedText)
  row:GetNamedChild("Have"):SetText(Number(material.total - material.used))
  row:GetNamedChild("Price"):SetText(material.price and Number(material.price) or "—")
  row:GetNamedChild("Cost"):SetText(material.price and Number(material.totalCost) or "—")
end

function MWC.UI.RefreshTotals()
  if not totalsWindow or totalsWindow:IsHidden() then return end
  local tab = MWC.sv.tab
  local crafts = tab ~= "all" and { [tab] = true } or nil
  local materials = SortMaterials(MWC.Plan.AddSpent(MWC.Plan.Materials(visibleGroups, true), crafts), true)
  ZO_ScrollList_Clear(totalsList)
  local dataList = ZO_ScrollList_GetDataList(totalsList)
  local usedCost, leftCost = 0, 0
  for i, material in ipairs(materials) do
    usedCost = usedCost + (material.price or 0) * material.used
    leftCost = leftCost + (material.price or 0) * (material.total - material.used)
    table.insert(dataList, ZO_ScrollList_CreateDataEntry(ROW_TYPE, { material = material, odd = i % 2 == 1 }))
  end
  ZO_ScrollList_Commit(totalsList)
  totalsWindow:GetNamedChild("Summary"):SetText(string.format(L.TOTALS_SUMMARY,
    Number(usedCost), Number(leftCost), Number(usedCost + leftCost)))
end

function MWC.UI.ToggleTotals()
  if totalsWindow:IsHidden() then
    totalsWindow:SetHidden(false)
    totalsWindow:BringWindowToTop()
    MWC.UI.RefreshTotals()
  else
    totalsWindow:SetHidden(true)
    ClearTooltip(ItemTooltip)
  end
end

function MWC.UI.SaveTotalsPosition()
  MWC.sv.totalsLeft = totalsWindow:GetLeft()
  MWC.sv.totalsTop = totalsWindow:GetTop()
end

-- Stats panel ---------------------------------------------------------------

-- Rows: writs, vouchers, materials (TTC gold), gold per voucher. Columns: queued, ready, turned in this session.
local STAT_ROWS = { L.STAT_WRITS, L.STAT_VOUCHERS, L.STAT_MATERIALS, L.STAT_GOLD_PER_VOUCHER }
local STAT_COLUMNS = { L.STAT_QUEUED, L.STAT_READY, L.STAT_TURNED_IN }
local STAT_ROW_HEIGHT, STAT_LABEL_WIDTH, STAT_COLUMN_WIDTH = 22, 150, 120
local statCells = {}

local function StatCell(grid, row, column)
  local label = WINDOW_MANAGER:CreateControl(nil, grid, CT_LABEL)
  label:SetFont(row == 0 and "ZoFontGameSmall" or "ZoFontGame")
  label:SetDimensions(column == 0 and STAT_LABEL_WIDTH or STAT_COLUMN_WIDTH, STAT_ROW_HEIGHT)
  label.mwcFit = true
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  label:SetHorizontalAlignment(column == 0 and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT)
  local x = column == 0 and 0 or STAT_LABEL_WIDTH + (column - 1) * STAT_COLUMN_WIDTH
  label:SetAnchor(TOPLEFT, grid, TOPLEFT, x, row * STAT_ROW_HEIGHT)
  return label
end

local function InitStats()
  local grid = panel:GetNamedChild("StatsGrid")
  for column, title in ipairs(STAT_COLUMNS) do
    local header = StatCell(grid, 0, column)
    header:SetColor(unpack(GOLD))
    header:SetText(title)
  end
  for row, title in ipairs(STAT_ROWS) do
    local label = StatCell(grid, row, 0)
    label:SetColor(unpack(GOLD))
    label:SetText(title)
    statCells[row] = {}
    for column = 1, #STAT_COLUMNS do
      statCells[row][column] = StatCell(grid, row, column)
    end
  end
end

local function StatColumn(column, writs, vouchers, materials)
  local values = {
    Number(writs), Number(vouchers) .. " v", Number(materials) .. " g",
    vouchers > 0 and (Number(materials / vouchers) .. " g/v") or "—",
  }
  for row, value in ipairs(values) do
    statCells[row][column]:SetText(value)
  end
end

-- Queued and ready: the writs of the current tab. Turned in: the session journal, for the same crafts.
local function RefreshStats(totals)
  StatColumn(1, totals.writs, totals.vouchers, totals.materials)
  StatColumn(2, totals.ready, totals.readyVouchers, totals.readyMaterials)
  local tab = MWC.sv.tab
  local count, vouchers, materials = MWC.Journal.Completed(tab ~= "all" and { [tab] = true } or nil)
  local gold = 0
  for _, material in pairs(materials) do
    gold = gold + material.amount * (MWC.Price.Of(material.link) or 0)
  end
  StatColumn(3, count, vouchers, gold)
  panel:GetNamedChild("StatsSession"):SetText(MWC.Session.Summary())
end

-- Turn-in panel -----------------------------------------------------------------

local TURN_IN_CRAFTS = { "blacksmithing", "clothier", "woodworking", "jewelry", "alchemy", "enchanting", "provisioning" }
local TURN_IN_COLUMNS = { { key = "craft", title = L.TI_CRAFT, x = 0, width = 120 },
  { key = "quest", title = L.TI_QUEST, x = 125, width = 90 },
  { key = "bag", title = L.TI_BAG, x = 220, width = 60 }, { key = "bank", title = L.TI_BANK, x = 285, width = 60 },
  { key = "notReady", title = L.TI_NOT_READY, x = 350, width = 75 } }
local TURN_IN_ROW_HEIGHT = 22
local turnInCells = {}

local function TurnInCell(parent, row, column)
  local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
  label:SetFont(row == 0 and "ZoFontGameSmall" or "ZoFontGame")
  label:SetDimensions(column.width, TURN_IN_ROW_HEIGHT)
  label.mwcFit = true
  label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  local left = column.key == "craft" or column.key == "quest"
  label:SetHorizontalAlignment(left and TEXT_ALIGN_LEFT or TEXT_ALIGN_RIGHT)
  label:SetAnchor(TOPLEFT, parent, TOPLEFT, column.x, row * TURN_IN_ROW_HEIGHT)
  return label
end

local function InitTurnIn()
  local section = panel:GetNamedChild("TurnIn")
  local tableControl = section:GetNamedChild("Table")
  tableControl:SetWidth(430)
  for _, column in ipairs(TURN_IN_COLUMNS) do
    local header = TurnInCell(tableControl, 0, column)
    header:SetColor(unpack(GOLD))
    header:SetText(column.title)
  end
  for row, craft in ipairs(TURN_IN_CRAFTS) do
    turnInCells[craft] = {}
    for _, column in ipairs(TURN_IN_COLUMNS) do
      turnInCells[craft][column.key] = TurnInCell(tableControl, row, column)
    end
    turnInCells[craft].craft:SetText(CRAFT_LABEL[craft])
  end
  -- Holiday writs (Event checkbox on) get a row of their own under the crafts.
  turnInCells.event = {}
  for _, column in ipairs(TURN_IN_COLUMNS) do
    turnInCells.event[column.key] = TurnInCell(tableControl, #TURN_IN_CRAFTS + 1, column)
  end
  turnInCells.event.craft:SetText(L.TI_HOLIDAY)
  section:GetNamedChild("NextTitle"):SetColor(unpack(GOLD))
  local auto = section:GetNamedChild("AutoHandIn")
  ZO_CheckButton_SetLabelText(auto, L.AUTODELIVERY)
  auto:SetHandler("OnMouseEnter", function(self)
    ZO_Tooltips_ShowTextTooltip(self, LEFT, L.AUTODELIVERY_TOOLTIP)
  end)
  auto:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
  ZO_CheckButton_SetCheckState(auto, false)
  ZO_CheckButton_SetToggleFunction(auto, function(_, checked) MWC.TurnIn.SetAutoHandIn(checked) end)
end

-- The advice and its color: yellow = wait (something is running), green = go hand in at the mediator,
-- blue = bank work, orange = press a button here, grey = nothing to do.
local STEP_COLOR = { wait = C.YELLOW, mediator = C.GREEN, bank = C.BLUE, button = C.ORANGE, idle = C.GREY }

local function NextTurnInStep(totals, event)
  local activity = MWC.Activity.Current()
  if activity then return activity.detail, "wait" end
  local quests = MWC.TurnIn.ActiveCraftingQuests()
  local startable = MWC.TurnIn.StartableCrafts(allGroups)
  local bank = totals.bank + event.bank
  if MWC.Bank.IsPlayerBankOpen() then
    local auto = MWC.TurnIn.IsAutoHandIn()
    if bank > 0 then
      return auto and string.format(L.STEP_TAKING, bank)
        or string.format(L.STEP_PRESS_WITHDRAW, bank), "bank"
    end
    if totals.bag > 0 or event.bag > 0 then
      return auto and L.STEP_CLOSE_BANK_AUTO or L.STEP_CLOSE_BANK, "bank"
    end
    return L.STEP_NOTHING_IN_BANK, "idle"
  end
  if startable > 0 and not MWC.TurnIn.IsAutoHandIn() then
    return string.format(L.STEP_START_MORE, startable), "button"
  end
  if quests > 0 then
    return string.format(L.STEP_MEDIATOR, quests), "mediator"
  end
  if startable > 0 then return string.format(L.STEP_START, startable), "button" end
  if totals.bank > 0 then
    return string.format(L.STEP_OPEN_BANK, totals.bank,
      MWC.TurnIn.IsAutoHandIn() and L.STEP_TAKEN_AT_ONCE or ""), "bank"
  end
  -- Holiday writs in the bank: only once the holiday quest in hand (if any) is dealt with, see EventTurnInStep.
  if event.bank > 0 and not MWC.TurnIn.EventState() then
    return string.format(L.STEP_OPEN_BANK_HOLIDAY, event.bank,
      MWC.TurnIn.IsAutoHandIn() and L.STEP_TAKEN_AT_ONCE or ""), "bank"
  end
  if totals.notReady > 0 then return L.STEP_CRAFT_FIRST, "idle" end
  return L.STEP_ALL_DONE, "idle"
end

-- The holiday quest's line in the Turn in panel (Event checkbox on), or nil.
local function EventTurnInStep()
  local state, name = MWC.TurnIn.EventState()
  if state == "starting" then
    return string.format(L.STEP_EVENT_STARTING, name)
  elseif state == "deliver" then
    return string.format(L.STEP_EVENT_DELIVER, name)
  elseif state == "craft" then
    return string.format(L.STEP_EVENT_CRAFT, name)
  elseif state == "ready" then
    return MWC.TurnIn.IsAutoHandIn() and string.format(L.STEP_EVENT_READY_AUTO, name)
      or string.format(L.STEP_EVENT_READY, name)
  end
end

local EVENT_SHORT_STEP = { starting = L.SHORT_EVENT_STARTING, deliver = L.SHORT_EVENT_DELIVER,
  craft = L.SHORT_EVENT_CRAFT, ready = L.SHORT_EVENT_READY }

-- The same advice in two words, for the progress bar: what to do now in the turn-in loop.
local function ShortTurnInStep(totals, event)
  local startable = MWC.TurnIn.StartableCrafts(allGroups)
  if MWC.Bank.IsPlayerBankOpen() then
    if totals.bank + event.bank > 0 then return L.SHORT_WITHDRAW end
    return startable > 0 and L.SHORT_CLOSE_BANK or L.SHORT_NOTHING_IN_BANK
  end
  if startable > 0 and not MWC.TurnIn.IsAutoHandIn() then return L.SHORT_START end
  if MWC.TurnIn.ActiveCraftingQuests() > 0 then return L.SHORT_MEDIATOR end
  if startable > 0 then return L.SHORT_START end
  if totals.bank > 0 then return L.SHORT_OPEN_BANK end
  local eventStep = EVENT_SHORT_STEP[MWC.TurnIn.EventState() or ""]
  if eventStep then return eventStep end
  if event.bank > 0 then return L.SHORT_OPEN_BANK end
  return totals.notReady > 0 and L.SHORT_CRAFT_REST or L.SHORT_ALL_TURNED_IN
end

-- While the Turn in panel is open, the bar follows the session's hand-ins: turned in / turned in + ready left.
function MWC.UI.TurnInProgress()
  if MWC.sv.panel ~= "TurnIn" or MWC.sv.tab == "sealed" then return nil end
  local _, totals, event = MWC.TurnIn.Counts(allGroups)
  local turned = (MWC.Journal.Completed())
  local active = 0
  for _, group in ipairs(allGroups) do
    active = active + group.activeCount
  end
  local all = turned + active + totals.bag + totals.bank
  return turned, math.max(all, 1), string.format("%s  ·  %d / %d", ShortTurnInStep(totals, event), turned, all)
end

function MWC.UI.ImportQuests()
  local imported, unmatched = MWC.Journal.ImportQuests(allGroups)
  MWC.Print(L.IMPORTED, imported)
  for _, text in ipairs(unmatched) do
    MWC.Print(L.NOT_IMPORTED, text)
  end
  MWC.Marks.Refresh()
  MWC.UI.Refresh()
end

local function SetButtonEnabled(button, enabled)
  button:SetEnabled(enabled)
  button:SetAlpha(enabled and 1 or 0.45)
end

-- While the panel warns about another addon handing in, its setting is looked at every second (one table read):
-- turned off there, the warning goes at once. Nothing runs while there is no warning.
local CONFLICT_WATCH_MS = 1000
local function WatchConflicts(shown)
  local name = MWC.name .. "ConflictWatch"
  EVENT_MANAGER:UnregisterForUpdate(name)
  if not shown then return end
  EVENT_MANAGER:RegisterForUpdate(name, CONFLICT_WATCH_MS, function()
    if not MWC.UI.IsShown() or MWC.sv.panel ~= "TurnIn" then
      EVENT_MANAGER:UnregisterForUpdate(name)
    elseif not MWC.TurnIn.IsAutoHandIn() or #MWC.TurnIn.ConflictingAddons() == 0 then
      EVENT_MANAGER:UnregisterForUpdate(name)
      MWC.UI.Refresh("view")
    end
  end)
end

local function RefreshTurnIn(groups)
  local section = panel:GetNamedChild("TurnIn")
  local byCraft, totals, event = MWC.TurnIn.Counts(groups)
  local active = MWC.TurnIn.ActiveCrafts()
  local progress = MWC.TurnIn.Progress()
  for _, craft in ipairs(TURN_IN_CRAFTS) do
    local counts = byCraft[craft] or { bag = 0, bank = 0, notReady = 0 }
    local cells = turnInCells[craft]
    if progress and progress.craft == craft and not active[craft] then
      cells.quest:SetText(Color(C.YELLOW, L.TI_STARTING))
    elseif active[craft] then
      cells.quest:SetText(Color(C.ORANGE, L.TI_ACTIVE))
    else
      cells.quest:SetText(Color(C.GREY, "—"))
    end
    cells.bag:SetText(counts.bag > 0 and Color(C.GREEN, counts.bag) or Color(C.GREY, "0"))
    cells.bank:SetText(counts.bank > 0 and Color(C.BLUE, counts.bank) or Color(C.GREY, "0"))
    cells.notReady:SetText(Color(C.GREY, counts.notReady))
  end
  local eventCells = turnInCells.event
  for _, cell in pairs(eventCells) do
    cell:SetHidden(not MWC.sv.showEvent)
  end
  if MWC.sv.showEvent then
    local state = MWC.TurnIn.EventState()
    eventCells.quest:SetText(state == "starting" and Color(C.YELLOW, L.TI_STARTING)
      or (state == "deliver" or state == "craft") and Color(C.ORANGE, L.TI_ACTIVE) or Color(C.GREY, "—"))
    eventCells.bag:SetText(event.bag > 0 and Color(C.GREEN, event.bag) or Color(C.GREY, "0"))
    eventCells.bank:SetText(event.bank > 0 and Color(C.BLUE, event.bank) or Color(C.GREY, "0"))
    eventCells.notReady:SetText(Color(C.GREY, event.notReady))
  end
  local _, questCount, unknown = MWC.TurnIn.ActiveCrafts()
  section:GetNamedChild("Info"):SetText(string.format(L.TURNIN_INFO,
    questCount, unknown > 0 and string.format(L.TURNIN_UNKNOWN_CRAFT, unknown) or "", (MWC.Journal.Completed())))
  MWC.TurnIn.CheckFinished(totals, event)
  ZO_CheckButton_SetCheckState(section:GetNamedChild("AutoHandIn"), MWC.TurnIn.IsAutoHandIn())
  local step, kind = NextTurnInStep(totals, event)
  -- The holiday quest: in place of an idle master writ step, else on its own line under it.
  local eventStep = EventTurnInStep()
  if eventStep and kind == "idle" then
    step, kind = eventStep, "mediator"
  elseif eventStep then
    step = step .. "\n" .. Color(C.PURPLE, eventStep)
  end
  local conflicts = MWC.TurnIn.IsAutoHandIn() and MWC.TurnIn.ConflictingAddons() or {}
  if #conflicts > 0 then
    step = step .. "\n" .. Color(C.RED, string.format(L.CONFLICT_PANEL, table.concat(conflicts, ", "))) .. " "
      .. Color(C.BLUE, L.OPEN_ITS_SETTINGS)
  end
  -- With a warning the text is a link to that addon's setting.
  local nextLabel = section:GetNamedChild("Next")
  nextLabel:SetText(Color(STEP_COLOR[kind], step))
  nextLabel:SetMouseEnabled(#conflicts > 0)
  if not nextLabel.linkSet then
    nextLabel.linkSet = true
    nextLabel:SetHandler("OnMouseUp", function(_, button, upInside)
      if upInside and button == MOUSE_BUTTON_INDEX_LEFT then MWC.TurnIn.OpenDolgubonSettings() end
    end)
  end
  WatchConflicts(#conflicts > 0)
  local bankOpen, busy = MWC.Bank.IsPlayerBankOpen(), MWC.Activity.Current() ~= nil
  SetButtonEnabled(section:GetNamedChild("Withdraw"), bankOpen and not busy and totals.bank > 0)
  SetButtonEnabled(section:GetNamedChild("Deposit"), bankOpen and not busy)
  local untracked = #MWC.Journal.UntrackedQuests()
  SetButtonEnabled(section:GetNamedChild("Import"), not busy and untracked > 0)
  local import = section:GetNamedChild("Import")
  import:SetText(untracked > 0 and string.format(L.BUTTON_IMPORT_COUNT, untracked) or L.BUTTON_IMPORT)
  -- Quests outside the session don't reserve their items: make that hard to miss.
  if untracked > 0 then
    import:SetNormalFontColor(ZO_ColorDef:New(C.ORANGE):UnpackRGBA())
  else
    import:SetNormalFontColor(unpack(GOLD))
  end
  local startable = MWC.TurnIn.StartableCrafts(groups)
  SetButtonEnabled(section:GetNamedChild("Start"), not bankOpen and not busy and startable > 0)
  section:GetNamedChild("Start"):SetText(startable > 0 and string.format(L.BUTTON_START_COUNT, startable) or L.BUTTON_START)
end

-- Layout --------------------------------------------------------------------

-- The summary fills the space between the panel toggles and whichever action buttons are visible.
local function LayoutFooter()
  local leftmost
  for _, name in ipairs(ALL_ACTIONS) do
    local button = window:GetNamedChild(name)
    if not button:IsHidden() and (not leftmost or button:GetLeft() < leftmost:GetLeft()) then
      leftmost = button
    end
  end
  local summary = window:GetNamedChild("Summary")
  summary:ClearAnchors()
  if MWC.sv.tab == "sealed" then
    summary:SetAnchor(LEFT, window:GetNamedChild("MaterialsToggle"), LEFT, 4, 0)
  else
    summary:SetAnchor(LEFT, window:GetNamedChild("TurnInToggle"), RIGHT, 16, 0)
  end
  if leftmost then
    summary:SetAnchor(RIGHT, leftmost, LEFT, -12, 0)
  end
end

-- Sealed writs have no materials or stats, so that tab has neither the panels nor their toggles.
-- The saved height of a resizable panel, kept within what the window leaves after the list's minimum.
local function PanelHeight(name)
  local height = RESIZABLE_PANELS[name] and MWC.sv.panelHeights and MWC.sv.panelHeights[name] or PANEL_HEIGHTS[name]
  local maxHeight = window:GetHeight() - LIST_TOP - MIN_LIST_HEIGHT - FOOTER_HEIGHT - PANEL_GAP
  return zo_clamp(height, math.min(MIN_PANEL_HEIGHT, maxHeight), math.max(maxHeight, MIN_PANEL_HEIGHT))
end

local function LayoutPanel()
  local sealedTab = MWC.sv.tab == "sealed"
  local open = not sealedTab and MWC.sv.panel or nil
  panel:SetHidden(not open)
  for _, name in ipairs(PANELS) do
    panel:GetNamedChild(name):SetHidden(open ~= name)
    local toggle = window:GetNamedChild(name .. "Toggle")
    toggle:SetHidden(sealedTab)
    if open == name then
      toggle:SetNormalFontColor(1, 1, 1, 1)
    else
      toggle:SetNormalFontColor(unpack(GOLD))
    end
  end
  local height = open and PanelHeight(open) or 0
  if open then
    panel:SetHeight(height)
  end
  window:GetNamedChild("Splitter"):SetHidden(not (open and RESIZABLE_PANELS[open]))
  local bottom = FOOTER_HEIGHT + (open and (height + PANEL_GAP) or 0)
  list:ClearAnchors()
  list:SetAnchor(TOPLEFT, window:GetNamedChild("Header"), BOTTOMLEFT, 0, 0)
  list:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -8, -bottom)
  LayoutFooter()
end

-- Splitter drag: the panel follows the cursor until the button is released, then the height is saved.
local dragStartY, dragStartHeight

function MWC.UI.OnSplitterDown(splitter)
  local open = MWC.sv.panel
  if not RESIZABLE_PANELS[open] then return end
  local _, y = GetUIMousePosition()
  dragStartY, dragStartHeight = y, PanelHeight(open)
  splitter:SetHandler("OnUpdate", function()
    local _, currentY = GetUIMousePosition()
    MWC.sv.panelHeights = MWC.sv.panelHeights or {}
    MWC.sv.panelHeights[open] = dragStartHeight + (dragStartY - currentY)
    MWC.sv.panelHeights[open] = PanelHeight(open)
    LayoutPanel()
  end)
end

function MWC.UI.OnSplitterUp(splitter)
  splitter:SetHandler("OnUpdate", nil)
  if dragStartY then
    dragStartY = nil
    MWC.UI.Refresh("view")
  end
end

function MWC.UI.TogglePanel(name)
  MWC.sv.panel = MWC.sv.panel ~= name and name or nil
  LayoutPanel()
  MWC.UI.Refresh("view")
end

-- While an operation runs only Stop is offered; otherwise the buttons depend on the location and the tab.
local function LayoutActions()
  local sealedTab = MWC.sv.tab == "sealed"
  local visible = {}
  if MWC.Activity.Current() then
    visible.Stop = true
  else
    local place = MWC.Bank.IsPlayerBankOpen() and "bank" or MWC.Bank.IsHouseChestOpen() and "chest" or "field"
    for _, name in ipairs(ACTIONS[place][sealedTab and "sealed" or "writs"]) do
      visible[name] = true
    end
  end
  for _, name in ipairs(ALL_ACTIONS) do
    window:GetNamedChild(name):SetHidden(not visible[name])
  end
  ApplyHeaderTitles()
  FitButtons()
  LayoutFooter()
end

function MWC.UI.OnBankStateChanged()
  LayoutActions()
  MWC.UI.Refresh("view")
end

-- Refresh -------------------------------------------------------------------

-- The title bar shows the running operation's progress, or otherwise the crafting progress of the tab.
local PROGRESS_GREEN = { ZO_ColorDef:New(0.2, 0.55, 0.2, 1), ZO_ColorDef:New(0.4, 0.85, 0.4, 1) }
local PROGRESS_RED = { ZO_ColorDef:New(0.6, 0.12, 0.12, 1), ZO_ColorDef:New(0.9, 0.25, 0.25, 1) }

-- A stopped operation's problem stays on the bar in red until the next one starts or the bar is clicked.
local function RefreshProgress(totals)
  lastTotals = totals or lastTotals
  local activity = MWC.Activity.Current()
  local outcome = not activity and MWC.Activity.Outcome()
  if outcome and outcome.warning then outcome = nil end
  local done, total, text
  if outcome then
    done, total, text = 1, 1, L.BAR_STOPPED .. outcome.short
  elseif not activity and MWC.UI.TurnInProgress() then
    done, total, text = MWC.UI.TurnInProgress()
  elseif activity then
    done, total = activity.done, math.max(activity.total, 1)
    text = string.format("%s %d / %d", activity.label, activity.done, activity.total)
  elseif MWC.sv.tab == "sealed" then
    if sealedLimit then
      done, total = sealedLimit.planned, sealedLimit.wanted
      text = string.format(L.BAR_INVENTORY_LIMIT, done, total)
    end
  elseif lastTotals and lastTotals.trackedWrits + lastTotals.completed > 0 then
    -- Handed-in writs of the session count as done, so the bar doesn't go back as writs are turned in.
    done = lastTotals.ready + lastTotals.completed
    total = lastTotals.trackedWrits + lastTotals.completed
    if lastTotals.completed > 0 then
      text = string.format(L.BAR_READY_TURNED, lastTotals.ready, lastTotals.completed, total)
    else
      text = string.format(L.BAR_READY, done, total, zo_round(100 * done / total))
    end
  end
  local bar, label = window:GetNamedChild("Progress"), window:GetNamedChild("ProgressText")
  local limited = not activity and not outcome and MWC.sv.tab == "sealed" and sealedLimit ~= nil
  ZO_StatusBar_SetGradientColor(bar, (outcome or limited) and PROGRESS_RED or PROGRESS_GREEN)
  bar:SetHidden(not text)
  label:SetHidden(not text)
  if text then
    bar:SetMinMax(0, total)
    bar:SetValue(math.min(done, total))
    label:SetText(text)
  end
end

local function ShowSummary(text)
  lastSummary = text or lastSummary
  local activity = MWC.Activity.Current()
  local outcome = not activity and MWC.Activity.Outcome()
  window:GetNamedChild("Summary"):SetText(activity and activity.detail
    or outcome and Color(outcome.warning and C.ORANGE or C.RED, outcome.message) or lastSummary)
end

-- The footer line: a note or problem left by the last operation (cut to one line there) is shown whole on hover
-- and goes away on a click.
function MWC.UI.OnSummaryEnter(label)
  local outcome = not MWC.Activity.Current() and MWC.Activity.Outcome()
  if outcome then
    ZO_Tooltips_ShowTextTooltip(label, TOP, outcome.message .. L.BAR_CLICK_DISMISS)
  end
end

function MWC.UI.OnSummaryClicked()
  if MWC.Activity.Outcome() and not MWC.Activity.Current() then
    ZO_Tooltips_HideTextTooltip()
    MWC.Activity.Dismiss()
  end
end

function MWC.UI.OnProgressEnter(bar)
  local outcome = not MWC.Activity.Current() and MWC.Activity.Outcome()
  if outcome and not outcome.warning then
    ZO_Tooltips_ShowTextTooltip(bar, BOTTOM, outcome.message .. L.BAR_CLICK_DISMISS)
  end
end

local function UpdateTabs(groups, sealedRows)
  local counts = { all = 0, sealed = 0 }
  for _, group in ipairs(groups) do
    counts[group.type] = (counts[group.type] or 0) + group.writCount
    counts.all = counts.all + group.writCount
  end
  for _, row in ipairs(sealedRows) do
    counts.sealed = counts.sealed + row.inBag + row.inBank
  end
  for i, tab in ipairs(TABS) do
    local control = tabControls[i]
    local selected = tab.type == MWC.sv.tab
    local count = control:GetNamedChild("Count")
    count:SetText(tostring(counts[tab.type] or 0))
    count:SetColor(1, 1, 1, selected and 1 or 0.6)
    control:GetNamedChild("Icon"):SetTexture(string.format(TAB_ICON_PATH, tab.icon, selected and "down" or "up"))
    control:GetNamedChild("Underline"):SetHidden(not selected)
    control:SetWidth(TAB_ICON_WIDTH + count:GetTextWidth() + TAB_PADDING)
  end
end

function MWC.UI.OnTabEnter(control)
  ZO_Tooltips_ShowTextTooltip(control, BOTTOM, control.tabLabel)
end

function MWC.UI.OnTabExit()
  ZO_Tooltips_HideTextTooltip()
end

-- Header column -> its value for a writ group or a sealed row. Left-click sorts, right-click resets.
local SORT_VALUES = {
  Type = function(item) return string.format("%02d %s", item.typeOrder or 99, item.typeLabel or "") end,
  Name = function(item) return zo_strlower(item.name) end,
  Set = function(item) return zo_strlower(item.setName or "") end,
  Style = function(item) return zo_strlower(item.styleName or "") end,
  Trait = function(item) return zo_strlower(item.traitName or "") end,
  -- Queued: enabled writs first (descending), then by how many are queued.
  Count = function(item)
    if item.queued then return (item.queued > 0 and 1000000 or 0) + item.queued end
    return item.planned or 0
  end,
  Ready = function(item) return item.ready or -1 end,
  Vouchers = function(item) return item.voucherMax or 0 end,
  QualitySort = function(item) return item.quality or 0 end,
}
local TEXT_COLUMNS = { Type = true, Name = true, Set = true, Style = true, Trait = true }
local SORT_ARROW = { [true] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortdown.dds|t", [false] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortup.dds|t" }
-- The narrow Type column shows only an icon: "sortable" when idle, a centered arrow when sorted by it.
local TYPE_SORT_IDLE = "|t20:20:EsoUI/Art/Miscellaneous/list_sortheader_icon_neutral.dds|t"
local TYPE_SORT_ARROW = { [true] = "|t20:20:EsoUI/Art/Miscellaneous/list_sortdown.dds|t", [false] = "|t20:20:EsoUI/Art/Miscellaneous/list_sortup.dds|t" }

local function SortItems(items)
  local sort = MWC.sv.sort
  local value = sort and SORT_VALUES[sort.column]
  if not value then return items end
  local byName = SORT_VALUES.Name
  table.sort(items, function(a, b)
    local va, vb = value(a), value(b)
    if va == vb then return byName(a) < byName(b) end
    if sort.desc then return va > vb end
    return va < vb
  end)
  return items
end

ApplyHeaderTitles = function()
  local header = window:GetNamedChild("Header")
  local sort = MWC.sv.sort
  for child, text in pairs(headerTitles[MWC.sv.tab == "sealed" and "sealed" or "writs"]) do
    local active = sort and sort.column == child
    if child == "Type" and text ~= "" then
      text = active and TYPE_SORT_ARROW[sort.desc] or TYPE_SORT_IDLE
    elseif active and text ~= "" then
      text = text .. " " .. SORT_ARROW[sort.desc]
    end
    header:GetNamedChild(child):SetText(text)
  end
end

function MWC.UI.SortBy(column)
  local sort = MWC.sv.sort
  if sort and sort.column == column then
    sort.desc = not sort.desc
  else
    MWC.sv.sort = { column = column, desc = not TEXT_COLUMNS[column] }
  end
  ApplyHeaderTitles()
  MWC.UI.Refresh("view")
end

function MWC.UI.ResetSort()
  MWC.sv.sort = nil
  ApplyHeaderTitles()
  MWC.UI.Refresh("view")
end

-- Which of a group's rows are shown: bag writs (hidden when all are skipped and Skipped is off), active
-- quests (always), and the history (with Completed on).
local function VisibleParts(group)
  local show = {
    active = group.activeCount > 0,
    inventory = group.inventoryCount > 0 and (MWC.sv.showSkipped or group.queued > 0),
    completed = group.completedCount > 0 and MWC.sv.showCompleted,
    closed = group.closedCount > 0 and MWC.sv.showCompleted,
  }
  local parts = {}
  for _, part in ipairs(PART_ORDER) do
    if show[part] then
      table.insert(parts, part)
    end
  end
  return parts
end

local function VisibleGroups(groups)
  local visible = {}
  for _, group in ipairs(groups) do
    local inTab = MWC.sv.tab == "all" or group.type == MWC.sv.tab
    if inTab and #VisibleParts(group) > 0 then
      table.insert(visible, group)
    end
  end
  return SortItems(visible)
end

local function SummaryText(totals, hasGroups)
  if not (MWC.sv.includeBag or MWC.sv.includeBank) then
    return L.SELECT_BAG_OR_BANK
  end
  if not hasGroups then
    return L.NO_WRITS
  end
  return MWC.Report.BagLine(totals)
end

-- Queued writs on any tab that would spend a material from Keep materials.
local function UnprofitableGroups()
  local groups = {}
  for _, group in ipairs(allGroups) do
    if group.kept and group.queued > 0 then
      table.insert(groups, group)
    end
  end
  return groups
end

-- Shown only while some queued writ would spend a kept material.
RefreshDeselectButton = function()
  local count = #UnprofitableGroups()
  local button = window:GetNamedChild("DeselectUnprofitable")
  button:SetHidden(count == 0)
  button:SetText(string.format(L.DESELECT_KEPT_COUNT, count))
end

function MWC.UI.DeselectUnprofitable()
  if MWC.Activity.Current() then return end
  local groups = UnprofitableGroups()
  if #groups > 0 then
    MWC.Session.SetGroupsSelected(groups, false)
  end
end

-- Turned-in writs count in the progress only while Completed is shown, and then for every recipe of the tab,
-- whether its row is visible or not (rows whose writs are all turned in disappear with Completed off).
local function CompletedInTab()
  if not MWC.sv.showCompleted then return 0 end
  local count = 0
  for _, group in ipairs(allGroups) do
    if MWC.sv.tab == "all" or group.type == MWC.sv.tab then
      count = count + group.completedCount
    end
  end
  return count
end

-- What changed decides how much of the plan is worked out again:
--   true      bag changes, which already marked the crafts they concern (or writs queued/skipped: their craft's
--             part sees it in its signature);
--   {crafts}  only these crafts changed;
--   "view"    only how the list is shown (sort, tab, filters, layout): the plan is kept as it is;
--   nil       anything may have changed (opening the window, settings, the end of an operation): a fresh plan.
-- Anything else (zo_callLater passes its id) counts as nil, so a refresh can be too thorough, never too lax.
function MWC.UI.Refresh(what)
  refreshPending = false
  if what == true then
    MWC.Plan.Touch()
  elseif type(what) == "table" then
    MWC.Plan.MarkDirty(what)
  elseif what ~= "view" then
    MWC.Plan.Invalidate()
  end
  if window:IsHidden() then return end
  MWC.Timed("list refresh", MWC.UI.RefreshNow)
  FitButtons()
end

-- The list is redrawn like a recycler view with a diff: when the rows are the same ones in the same order (same
-- writ groups and parts), their data is swapped in place and only the visible rows are drawn again, keeping the
-- scroll position; only a different set of rows, or a list resized (splitter, window: the number of rows that
-- fit changes), rebuilds the list.
local shownRowKeys, shownWidth, shownHeight = {}, 0, 0

local function ShowRows(rows)
  local keys = {}
  for i, row in ipairs(rows) do
    keys[i] = row.key
  end
  local same = #keys == #shownRowKeys
  for i = 1, #keys do
    if not same then break end
    same = keys[i] == shownRowKeys[i]
  end
  local dataList = ZO_ScrollList_GetDataList(list)
  local width, height = list:GetDimensions()
  if same and #dataList == #rows and width == shownWidth and height == shownHeight then
    for i, row in ipairs(rows) do
      dataList[i].data = row.data
    end
    ZO_ScrollList_RefreshVisible(list)
    return
  end
  ZO_ScrollList_Clear(list)
  for _, row in ipairs(rows) do
    table.insert(dataList, ZO_ScrollList_CreateDataEntry(ROW_TYPE, row.data))
  end
  ZO_ScrollList_Commit(list)
  shownRowKeys, shownWidth, shownHeight = keys, width, height
end

function MWC.UI.RefreshNow()

  local plan = MWC.Plan.Build()
  allGroups = plan.groups
  local sealedRows = MWC.Sealed.Scan()
  UpdateTabs(plan.groups, sealedRows)
  allGroups = plan.groups
  RefreshDeselectButton()

  if MWC.sv.tab == "sealed" then
    showGearColumns = false
    LayoutGearColumns(window:GetNamedChild("Header"))
    visibleGroups, visibleSealed = {}, SortItems(sealedRows)
    local inBag, inBank, planned, overflow, allEnabled = 0, 0, 0, 0, #sealedRows > 0
    local rows = {}
    for i, row in ipairs(sealedRows) do
      inBag, inBank, planned = inBag + row.inBag, inBank + row.inBank, planned + row.planned
      overflow = overflow + row.overflow
      allEnabled = allEnabled and row.enabled
      table.insert(rows, { key = "sealed:" .. row.itemId, data = { sealed = row, odd = i % 2 == 1 } })
    end
    ShowRows(rows)
    ZO_CheckButton_SetCheckState(window:GetNamedChild("HeaderCheck"), allEnabled)
    window:GetNamedChild("OpenSealed"):SetText(string.format(L.BUTTON_OPEN_COUNT, planned))
    local bagSize = GetBagSize(BAG_BACKPACK)
    local used = bagSize - GetNumBagFreeSlots(BAG_BACKPACK)
    ShowSummary(string.format(L.SEALED_SUMMARY, planned, inBag, inBank,
      MWC.Report.BagLine({ used = used, usedAfter = used + planned, bagSize = bagSize, overflow = overflow })))
    sealedLimit = overflow > 0 and { planned = planned, wanted = planned + overflow } or nil
    RefreshProgress(MWC.Plan.Totals({}))
    return
  end

  local groups = VisibleGroups(plan.groups)
  visibleGroups = groups
  showGearColumns = false
  for _, group in ipairs(groups) do
    if group.setName or group.styleName or group.traitName then
      showGearColumns = true
      break
    end
  end
  LayoutGearColumns(window:GetNamedChild("Header"))
  local rows = {}
  for _, group in ipairs(groups) do
    for _, part in ipairs(VisibleParts(group)) do
      table.insert(rows, { key = group.key .. "|" .. part, data = { group = group, part = part, odd = #rows % 2 == 0 } })
    end
  end
  ShowRows(rows)

  local allSelected, anyInBags = true, false
  for _, group in ipairs(groups) do
    if group.inventoryCount > 0 then
      anyInBags = true
      if group.queued < group.inventoryCount then
        allSelected = false
        break
      end
    end
  end
  allSelected = allSelected and anyInBags
  ZO_CheckButton_SetCheckState(window:GetNamedChild("HeaderCheck"), allSelected)

  local totals = MWC.Plan.Totals(groups)
  totals.completed = CompletedInTab()
  ShowSummary(SummaryText(totals, #groups > 0))
  RefreshProgress(totals)
  if MWC.sv.panel == "Materials" then
    RefreshMaterials(groups)
  elseif MWC.sv.panel == "Stats" then
    RefreshStats(totals)
  elseif MWC.sv.panel == "TurnIn" then
    RefreshTurnIn(plan.groups)
  end
  MWC.UI.RefreshTotals()
end

-- Light update for frequent progress ticks; the full Refresh follows inventory changes anyway.
function MWC.UI.OnActivityChanged()
  if not window then return end
  LayoutActions()
  RefreshProgress()
  ShowSummary()
  if MWC.sv.panel == "TurnIn" and MWC.sv.tab ~= "sealed" then
    RefreshTurnIn(allGroups)
  end
  if MWC.sv.tab == "sealed" then
    ZO_ScrollList_RefreshVisible(list)
  end
end

-- While crafting: count items just made into the listed writs and redraw the visible rows only. A full rebuild
-- takes long enough with many writs to hold up the next craft, so it waits for the end of crafting.
function MWC.UI.CountMade(groupKey, amount)
  for _, group in ipairs(allGroups) do
    if group.key == groupKey and group.ready then
      group.have = (group.have or 0) + amount
      group.readyBag = (group.readyBag or 0) + amount
      group.ready = math.min(group.selectedCount, group.have)
      ZO_ScrollList_RefreshVisible(list)
      return
    end
  end
end

-- Bag changes come in floods (banking, trading, looting): the list is rebuilt once they have been quiet for
-- REFRESH_DELAY_MS, and at the latest REFRESH_MAX_WAIT_MS after the first one, not after every half second.
local REFRESH_MAX_WAIT_MS, REFRESH_POLL_MS = 3000, 100
local firstChangeAt, lastChangeAt

local function QueueRefresh()
  if window:IsHidden() or MWC.Activity.IsCrafting() or MWC.TurnIn.InConversation() then return end
  local now = GetGameTimeMilliseconds()
  lastChangeAt = now
  if refreshPending then return end
  refreshPending, firstChangeAt = true, now
  EVENT_MANAGER:RegisterForUpdate(MWC.name .. "UIRefresh", REFRESH_POLL_MS, function()
    local current = GetGameTimeMilliseconds()
    if not refreshPending then
      EVENT_MANAGER:UnregisterForUpdate(MWC.name .. "UIRefresh")
    elseif current - lastChangeAt >= REFRESH_DELAY_MS or current - firstChangeAt >= REFRESH_MAX_WAIT_MS then
      EVENT_MANAGER:UnregisterForUpdate(MWC.name .. "UIRefresh")
      MWC.UI.Refresh(true)
    end
  end)
end

function MWC.UI.WithdrawAll()
  MWC.Bank.Withdraw(visibleGroups)
end

function MWC.UI.DepositAll()
  MWC.Bank.Deposit(visibleGroups)
end

function MWC.UI.SelectTab(tabType)
  MWC.sv.tab = tabType
  LayoutPanel()
  LayoutActions()
  MWC.UI.Refresh("view")
end

-- Like WritWorthy: the window only shows and hides, the mouse cursor is left to the player (the game's own
-- cursor key), so the window can stay open while walking or at a station.
function MWC.UI.Show()
  window:SetHidden(false)
  -- Showing the window refreshes it (OnWindowShown).
end

function MWC.UI.Hide()
  window:SetHidden(true)
  ClearTooltip(ItemTooltip)
end

-- Whether the addon is open is followed from the window itself.
function MWC.UI.IsShown()
  return window ~= nil and not window:IsHidden()
end

function MWC.UI.OnWindowShown()
  MWC.sv.windowOpen = true
  MWC.Marks.Refresh()
  MWC.UI.Refresh()
  if GetCraftingInteractionType() == CRAFTING_TYPE_ALCHEMY then
    zo_callLater(MWC.Craft.LearnAlchemyNames, 0)
  end
end

function MWC.UI.OnWindowHidden()
  MWC.sv.windowOpen = false
  ClearTooltip(ItemTooltip)
end

function MWC.UI.Toggle()
  if window:IsHidden() then
    MWC.UI.Show()
  else
    MWC.UI.Hide()
  end
end

function MWC.UI.SavePosition()
  MWC.sv.left = window:GetLeft()
  MWC.sv.top = window:GetTop()
  MWC.sv.width = window:GetWidth()
  MWC.sv.height = window:GetHeight()
end

function MWC.UI.OnResized()
  MWC.UI.SavePosition()
  LayoutPanel()
  MWC.UI.Refresh("view")
end

-- Opening a crafting station shows that craft's writs.
local TAB_BY_STATION = {
  [CRAFTING_TYPE_BLACKSMITHING] = "blacksmithing", [CRAFTING_TYPE_CLOTHIER] = "clothier",
  [CRAFTING_TYPE_WOODWORKING] = "woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING] = "jewelry",
  [CRAFTING_TYPE_ALCHEMY] = "alchemy", [CRAFTING_TYPE_ENCHANTING] = "enchanting",
  [CRAFTING_TYPE_PROVISIONING] = "provisioning",
}

local function OnStationOpened(_, craftSkill)
  local tab = TAB_BY_STATION[craftSkill]
  if tab and tab ~= MWC.sv.tab and not MWC.Activity.Current() then
    MWC.UI.SelectTab(tab)
  end
end

-- Init ----------------------------------------------------------------------

-- Column border drag: the column's left edge follows the cursor (the columns are laid out from the right).
local function StartColumnDrag(grip, header, column)
  local startX = GetUIMousePosition()
  local startWidth = ColumnWidth(column)
  local maxWidth = startWidth + math.max(0, header:GetNamedChild("Name"):GetWidth() - NAME_MIN_WIDTH)
  grip:SetHandler("OnUpdate", function()
    local x = GetUIMousePosition()
    MWC.sv.columnWidths = MWC.sv.columnWidths or {}
    MWC.sv.columnWidths[column] = zo_clamp(zo_round(startWidth + startX - x), COLUMN_MIN_WIDTH[column], maxWidth)
    ApplyColumnWidths(header)
    ZO_ScrollList_RefreshVisible(list)
  end)
end

local function InitColumnGrips(header)
  for _, column in ipairs(RESIZABLE_COLUMNS) do
    local label = header:GetNamedChild(column)
    local grip = WINDOW_MANAGER:CreateControl(header:GetName() .. column .. "Grip", label, CT_CONTROL)
    grip:SetDimensions(10, ROW_HEIGHT - 8)
    grip:SetAnchor(CENTER, label, LEFT, -4, 0)
    grip:SetMouseEnabled(true)
    local line = WINDOW_MANAGER:CreateControl(nil, grip, CT_TEXTURE)
    line:SetDimensions(2, ROW_HEIGHT - 14)
    line:SetAnchor(CENTER, grip, CENTER, 0, 0)
    line:SetColor(0.85, 0.83, 0.71, 0.35)
    line:SetDrawLayer(DL_OVERLAY)
    grip:SetHandler("OnMouseEnter", function()
      line:SetAlpha(1)
      ZO_Tooltips_ShowTextTooltip(grip, TOP, L.COLUMN_RESIZE_TOOLTIP)
    end)
    grip:SetHandler("OnMouseExit", function()
      line:SetAlpha(0.35)
      ZO_Tooltips_HideTextTooltip()
    end)
    grip:SetHandler("OnMouseDown", function(_, button)
      if button == MOUSE_BUTTON_INDEX_LEFT then StartColumnDrag(grip, header, column) end
    end)
    grip:SetHandler("OnMouseUp", function(_, button, upInside)
      grip:SetHandler("OnUpdate", nil)
      if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
        MWC.sv.columnWidths = nil
        ApplyColumnWidths(header)
        ZO_ScrollList_RefreshVisible(list)
      end
    end)
  end
end

local function StyleHeader(header, titles, hidden)
  header:SetMouseEnabled(false)
  for child, text in pairs(titles) do
    local label = header:GetNamedChild(child)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(unpack(GOLD))
    label:SetText(text)
  end
  for _, child in ipairs(hidden) do
    header:GetNamedChild(child):SetHidden(true)
  end
end

local function InitTabs()
  local container = window:GetNamedChild("Tabs")
  local previous
  for i, tab in ipairs(TABS) do
    local control = CreateControlFromVirtual("$(parent)Tab", container, "MWC_IconTab", i)
    control.tabType = tab.type
    control.tabLabel = tab.label
    control:GetNamedChild("Underline"):SetColor(unpack(GOLD))
    if previous then
      control:SetAnchor(LEFT, previous, RIGHT, TAB_SPACING, 0)
    else
      control:SetAnchor(LEFT, container, LEFT, 0, 0)
    end
    tabControls[i] = control
    previous = control
  end
end

local function InitCheckbox(name, label, settingKey, viewOnly)
  local control = window:GetNamedChild(name)
  ZO_CheckButton_SetLabelText(control, label)
  ZO_CheckButton_SetCheckState(control, MWC.sv[settingKey])
  ZO_CheckButton_SetToggleFunction(control, function(_, checked)
    MWC.sv[settingKey] = checked
    -- Showing holiday writs or not changes which bag writs get marks too.
    if settingKey == "showEvent" then
      MWC.Marks.Refresh()
    end
    MWC.UI.Refresh(viewOnly and "view" or nil)
  end)
end

-- Right to left from the Refresh button, with the same gap after every checkbox label.
local function LayoutToolbar()
  local previous = window:GetNamedChild("Refresh")
  for _, name in ipairs(TOOLBAR_CHECKBOXES) do
    local box = window:GetNamedChild(name)
    box:ClearAnchors()
    box:SetAnchor(RIGHT, previous, LEFT, 0, 0)
    local label = box.label or box:GetNamedChild("Label")
    local labelExtent = label and (label:GetRight() - box:GetRight()) or 0
    box:ClearAnchors()
    box:SetAnchor(RIGHT, previous, LEFT, -(TOOLBAR_GAP + labelExtent), 0)
    previous = box
  end
end

local function InitList()
  ZO_ScrollList_AddDataType(list, ROW_TYPE, "MWC_Row", ROW_HEIGHT, function(row, data)
    if not row.initialized then
      row:GetNamedChild("BG"):SetColor(1, 1, 1, 0.04)
      row:GetNamedChild("Highlight"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.15)
      row:GetNamedChild("ReadyBar"):SetColor(0.32, 0.32, 0.32, 0.9)
      row:GetNamedChild("ReadyFill"):SetColor(0.33, 0.8, 0.33, 1)
      local style = row:GetNamedChild("Style")
      style:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then MWC.UI.OnStyleClicked(row) end
      end)
      style:SetHandler("OnMouseEnter", function(label) MWC.UI.OnStyleEnter(row, label) end)
      style:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
      ZO_CheckButton_SetToggleFunction(row:GetNamedChild("Check"), function(_, checked)
        if MWC.Activity.Current() then
          MWC.UI.Refresh("view")
        elseif row.sealed then
          MWC.Sealed.SetEnabled(row.sealed.itemId, checked)
        else
          MWC.Session.SetSelectedCount(row.group, checked and row.group.inventoryCount or 0)
        end
      end)
      row.initialized = true
    end
    SetupRow(row, data)
  end)

  headerTitles.writs = {
    Name = string.format(L.HEADER_RECIPE, Color(C.BLUE, L.HEADER_BANK), Color(C.YELLOW, L.HEADER_BAG),
      Color(C.GREEN, L.HEADER_BAG_BANK)),
    Type = "sortable", QualitySort = L.HEADER_QUALITY, Set = L.HEADER_SET, Style = L.HEADER_STYLE,
    Trait = L.HEADER_TRAIT, Count = L.HEADER_QUEUED, Ready = L.HEADER_READY, Vouchers = L.HEADER_VOUCHERS,
  }
  headerTitles.sealed = {
    Name = string.format(L.HEADER_SEALED, Color(C.BLUE, L.HEADER_BANK), Color(C.YELLOW, L.HEADER_BAG)),
    Type = "", QualitySort = "", Set = "", Style = "", Trait = "", Count = L.HEADER_TO_OPEN, Ready = L.HEADER_OPENED,
    Vouchers = "",
  }
  local header = window:GetNamedChild("Header")
  -- The quality strip has no header of its own: a small "Q" label sorts by it, the recipe title moves aside.
  local qualitySort = WINDOW_MANAGER:CreateControl(header:GetName() .. "QualitySort", header, CT_LABEL)
  qualitySort:SetDimensions(34, ROW_HEIGHT)
  qualitySort:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  qualitySort:SetAnchor(LEFT, header, LEFT, 62, 0)
  header.nameLeft = 98
  header.gearColumnsShown = nil
  LayoutGearColumns(header)
  ApplyColumnWidths(header)
  InitColumnGrips(header)
  StyleHeader(header, headerTitles.writs, { "BG", "Quality", "TypeIcon", "Minus", "Plus", "ReadyBar", "ReadyFill" })
  for column in pairs(SORT_VALUES) do
    local label = header:GetNamedChild(column)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
      if not upInside then return end
      if button == MOUSE_BUTTON_INDEX_RIGHT then
        MWC.UI.ResetSort()
      else
        MWC.UI.SortBy(column)
      end
    end)
  end
  -- In rows the Ready label sits above its progress bar; the header has no bar, so center it like the others.
  local ready = header:GetNamedChild("Ready")
  ready:ClearAnchors()
  ready:SetAnchor(LEFT, header:GetNamedChild("Plus"), RIGHT, 20, 0)
  ready:SetHeight(ROW_HEIGHT)
  ZO_CheckButton_SetToggleFunction(window:GetNamedChild("HeaderCheck"), function(_, checked)
    if MWC.Activity.Current() then
      MWC.UI.Refresh("view")
    elseif MWC.sv.tab == "sealed" then
      MWC.Sealed.SetAllEnabled(visibleSealed, checked)
    else
      MWC.Session.SetGroupsSelected(visibleGroups, checked)
    end
  end)
end

-- Clickable column titles plus a reset button in the left corner, where the quality bar sits in rows.
local function InitMaterialHeader(header, titles)
  StyleHeader(header, titles, { "BG", "Quality", "Icon" })
  for column in pairs(titles) do
    local label = header:GetNamedChild(column)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
      if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
        MWC.UI.SortMaterialsBy(column)
      end
    end)
  end
  local reset = WINDOW_MANAGER:CreateControl(header:GetName() .. "SortReset", header, CT_BUTTON)
  reset:SetDimensions(20, 20)
  reset:SetAnchor(LEFT, header, LEFT, 0, 0)
  reset:SetNormalTexture("EsoUI/Art/Miscellaneous/list_sortheader_icon_neutral.dds")
  reset:SetHandler("OnClicked", MWC.UI.ResetMaterialsSort)
  reset:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, L.MATERIALS_DEFAULT_ORDER) end)
  reset:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
  table.insert(materialHeaders, { control = header, titles = titles })
  ApplyMaterialHeaderTitles()
end

local function InitMaterials()
  materialsList = panel:GetNamedChild("MaterialsList")
  ZO_ScrollList_AddDataType(materialsList, ROW_TYPE, "MWC_MaterialRow", MATERIAL_ROW_HEIGHT, function(row, data)
    if not row.initialized then
      row:GetNamedChild("BG"):SetColor(1, 1, 1, 0.04)
      row:GetNamedChild("Highlight"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.15)
      row.initialized = true
    end
    SetupMaterialRow(row, data)
  end)
  InitMaterialHeader(panel:GetNamedChild("MaterialsHeader"),
    { Craft = L.COLUMN_CRAFT, Name = L.COLUMN_MATERIAL, Need = L.COLUMN_NEED, Have = L.COLUMN_HAVE,
      Price = L.COLUMN_TTC_PRICE, Cost = L.COLUMN_TOTAL })
  local container = panel:GetNamedChild("MaterialsTabs")
  local previous
  for i, key in ipairs(MATERIAL_TABS) do
    local control = CreateControlFromVirtual("$(parent)Tab", container, "MWC_TextTab", i)
    control.tabKey = key
    control:SetWidth(118)
    control.mwcFit = true
    control:GetNamedChild("Underline"):SetColor(unpack(GOLD))
    if previous then
      control:SetAnchor(LEFT, previous, RIGHT, 0, 0)
    else
      control:SetAnchor(LEFT, container, LEFT, 0, 0)
    end
    materialTabControls[i] = control
    previous = control
  end
end

local function InitTotals()
  totalsWindow = MWC_TotalsWindow
  totalsWindow:GetNamedChild("Solid"):SetColor(0, 0, 0, 0.85)
  totalsList = totalsWindow:GetNamedChild("List")
  ZO_ScrollList_AddDataType(totalsList, ROW_TYPE, "MWC_MaterialRow", MATERIAL_ROW_HEIGHT, function(row, data)
    if not row.initialized then
      row:GetNamedChild("BG"):SetColor(1, 1, 1, 0.04)
      row:GetNamedChild("Highlight"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.15)
      row.initialized = true
    end
    SetupTotalsRow(row, data)
  end)
  InitMaterialHeader(totalsWindow:GetNamedChild("Header"),
    { Craft = L.COLUMN_CRAFT, Name = L.COLUMN_MATERIAL, Need = L.COLUMN_USED_TOTAL, Have = L.COLUMN_LEFT,
      Price = L.COLUMN_TTC_PRICE, Cost = L.COLUMN_TOTAL_COST })
  if MWC.sv.totalsLeft then
    totalsWindow:ClearAnchors()
    totalsWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, MWC.sv.totalsLeft, MWC.sv.totalsTop)
  end
end

-- The addon's windows draw on the highest tier and layer (UI.xml), which put the game's tooltips and the
-- right-click menu under them. Those are raised to the same tier and layer one level higher, so they show above
-- the windows they belong to (and above every other window, as tooltips should).
-- Drawing order ---------------------------------------------------------------------------------------------
-- Our windows draw on the highest tier and layer, above the game's UI: main window 1 < Keep materials,
-- Session totals 2. Tooltips and menus go above them (10). Game windows are otherwise never changed for good:
-- only while one the addon opened itself is up (see WithDialogOnTop), and put back exactly afterwards.
local LEVEL_MAIN, LEVEL_SMALL, LEVEL_OWN_DIALOG, LEVEL_POPUP = 1, 2, 9, 10

local function SetLevel(control, level)
  control:SetDrawTier(DT_HIGH)
  control:SetDrawLayer(DL_OVERLAY)
  control:SetDrawLevel(level)
end

local function RaisePopups()
  for _, name in ipairs({ "ItemTooltip", "InformationTooltip", "ComparativeTooltip1", "ComparativeTooltip2",
      "PopupTooltip", "ZO_Menu" }) do
    local control = _G[name]
    local owner = control and control.GetOwningWindow and control:GetOwningWindow()
    if owner then
      SetLevel(owner, LEVEL_POPUP)
    end
  end
end

function MWC.UI.ApplyLayers()
  SetLevel(MWC_Window, LEVEL_MAIN)
  SetLevel(MWC_KeyWindow, LEVEL_SMALL)
  SetLevel(MWC_TotalsWindow, LEVEL_SMALL)
end

-- RULE: every game dialog the addon opens itself (a confirmation...) is shown through MWC.UI.WithDialogOnTop,
-- so it is never under our windows. While it is up, the game's dialog windows and whatever top-level window
-- became visible after `show` are lifted above ours; once all of them are closed, each gets back exactly the
-- tier, layer and level it had. Game windows that aren't dialogs (mail, the browser link prompt) are opened
-- with our window hidden instead.
local SETTLE_CHECKS_MS = { 0, 100, 300, 700, 1500 }
local WATCH_MS, WATCH_LIMIT_MS = 300, 600000
local raised = {}

local function VisibleTopLevels()
  local visible = {}
  for i = 1, GuiRoot:GetNumChildren() do
    local child = GuiRoot:GetChild(i)
    if child and not child:IsHidden() then
      visible[child] = true
    end
  end
  return visible
end

local function Raise(control)
  local name = control:GetName() or ""
  if raised[control] or name:find("^MWC_") then return end
  raised[control] = { control:GetDrawTier(), control:GetDrawLayer(), control:GetDrawLevel() }
  MWC.Log("Dialog on top: %s", name)
  SetLevel(control, LEVEL_OWN_DIALOG)
end

local function RestoreRaised()
  for control, was in pairs(raised) do
    control:SetDrawTier(was[1])
    control:SetDrawLayer(was[2])
    control:SetDrawLevel(was[3])
  end
  raised = {}
end

local function IsDialogWindow(control)
  local name = control:GetName() or ""
  return name:find("Dialog", 1, true) and not name:find("Gamepad", 1, true)
end

function MWC.UI.WithDialogOnTop(show)
  local before = VisibleTopLevels()
  show()
  local function RaiseNew()
    for control in pairs(VisibleTopLevels()) do
      if not before[control] or IsDialogWindow(control) then Raise(control) end
    end
  end
  for _, delay in ipairs(SETTLE_CHECKS_MS) do
    zo_callLater(RaiseNew, delay)
  end
  -- Levels go back only after the last check, and only once everything raised is closed again.
  local waited = 0
  local name = MWC.name .. "DialogWatch"
  EVENT_MANAGER:UnregisterForUpdate(name)
  EVENT_MANAGER:RegisterForUpdate(name, WATCH_MS, function()
    waited = waited + WATCH_MS
    if waited < WATCH_LIMIT_MS then
      if waited <= SETTLE_CHECKS_MS[#SETTLE_CHECKS_MS] then return end
      for control in pairs(raised) do
        if not control:IsHidden() then return end
      end
    end
    EVENT_MANAGER:UnregisterForUpdate(name)
    RestoreRaised()
  end)
end

-- Feedback (the letter next to the title): an in-game mail to the author on their megaserver (offered only
-- there: mail can't reach another server), or the comments on the addon's ESOUI page.
local FEEDBACK_TO, FEEDBACK_SERVER = "@KanashiReinkyatto", "EU Megaserver"
local FEEDBACK_URL = "https://www.esoui.com/downloads/info5114-MasterWritsCompanion.html#comments"

local function MailAuthors()
  -- The mail window is a game window: ours would cover it.
  MWC.UI.Hide()
  local subject = "MasterWrits Companion " .. MWC.VERSION
  local ok = MAIL_SEND and MAIL_SEND.ComposeMailTo and pcall(MAIL_SEND.ComposeMailTo, MAIL_SEND, FEEDBACK_TO, subject)
  if not ok then
    SCENE_MANAGER:Show("mailSend")
  end
end

function MWC.UI.ShowFeedbackMenu(control)
  ZO_Tooltips_HideTextTooltip()
  ClearMenu()
  if GetWorldName() == FEEDBACK_SERVER then
    AddMenuItem(L.FEEDBACK_MAIL, MailAuthors)
  end
  AddMenuItem(L.FEEDBACK_ESOUI, function()
    -- The game's link prompt can't be lifted reliably: our window steps aside for it.
    MWC.UI.Hide()
    RequestOpenUnsafeURL(FEEDBACK_URL)
  end)
  ShowMenu(control)
end

function MWC.UI.Init()
  ApplyControlTexts()
  RaisePopups()
  MWC.UI.ApplyLayers()
  window = MWC_Window
  list = window:GetNamedChild("List")
  panel = window:GetNamedChild("Panel")
  panel:GetNamedChild("BG"):SetColor(0, 0, 0, 0.25)
  window:GetNamedChild("Solid"):SetColor(0, 0, 0, 0.85)
  window:GetNamedChild("Stop"):SetNormalFontColor(1, 0.35, 0.35, 1)

  InitTabs()
  InitList()
  InitMaterials()
  InitTotals()
  InitTurnIn()
  InitStats()
  InitCheckbox("IncludeBag", L.CHECK_BAG, "includeBag")
  InitCheckbox("IncludeBank", L.CHECK_BANK, "includeBank")
  InitCheckbox("ShowSkipped", L.CHECK_SKIPPED, "showSkipped", true)
  InitCheckbox("ShowCompleted", L.CHECK_COMPLETED, "showCompleted", true)
  -- Holiday writs come into the plan itself (the bags are read again).
  InitCheckbox("ShowEvent", L.CHECK_EVENT, "showEvent")
  LayoutToolbar()
  LayoutPanel()
  LayoutActions()

  window:SetDimensionConstraints(MIN_WIDTH, MIN_HEIGHT, GuiRoot:GetWidth(), GuiRoot:GetHeight())
  if MWC.sv.width then
    window:SetDimensions(math.max(MWC.sv.width, MIN_WIDTH), math.max(MWC.sv.height, MIN_HEIGHT))
  end
  if MWC.sv.left then
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, MWC.sv.left, MWC.sv.top)
  end
  local title = string.format("MasterWrits Companion |c999999v%s|r", MWC.VERSION)
  window:GetNamedChild("Title"):SetText(title)

  EVENT_MANAGER:RegisterForEvent(MWC.name .. "UI", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, QueueRefresh)
  EVENT_MANAGER:RegisterForEvent(MWC.name .. "UI", EVENT_CRAFTING_STATION_INTERACT, OnStationOpened)
end
