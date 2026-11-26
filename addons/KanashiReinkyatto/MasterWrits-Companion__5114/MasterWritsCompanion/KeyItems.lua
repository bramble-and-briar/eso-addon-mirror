-- Keep materials: the materials, traits and styles the user does not want to spend; writs that would spend
-- them are marked orange. The choice is stored per account, forever (not part of the writ session).
MWC.KeyItems = {}

-- Never-touched items are kept only if listed here: Hakeijo, Perfect Roe, Red Lichen.
local DEFAULT_KEPT = { [68342] = true, [64222] = true, [225210] = true }
local ALCHEMY_SOLVENTS = { 64501, 75365 } -- Lorkhan's Tears, Alkahest
local TRAIT_CATEGORIES = {
  blacksmithing = { ITEM_TRAIT_TYPE_CATEGORY_WEAPON, ITEM_TRAIT_TYPE_CATEGORY_ARMOR },
  clothier = { ITEM_TRAIT_TYPE_CATEGORY_ARMOR },
  woodworking = { ITEM_TRAIT_TYPE_CATEGORY_WEAPON, ITEM_TRAIT_TYPE_CATEGORY_ARMOR },
  jewelry = { ITEM_TRAIT_TYPE_CATEGORY_JEWELRY },
}
local STYLED_CRAFTS = { blacksmithing = true, clothier = true, woodworking = true }
local MAX_TRAIT_TYPE = 40

function MWC.KeyItems.ItemKey(itemId)
  return "item:" .. itemId
end

function MWC.KeyItems.IsEnabled(key)
  local choice = MWC.sv.keepItems[key]
  if choice ~= nil then return choice end
  return DEFAULT_KEPT[tonumber(key:match("^item:(%d+)$"))] == true
end

function MWC.KeyItems.SetEnabled(key, enabled)
  MWC.sv.keepItems[key] = enabled
end

-- The trait stone link and the trait name. Trait item indices are trait types shifted by one.
function MWC.KeyItems.TraitStone(traitType)
  if not traitType or traitType == 0 then return nil end
  local link = GetSmithingTraitItemLink(traitType + 1, LINK_STYLE_DEFAULT)
  if not link or link == "" then return nil end
  return link, GetString("SI_ITEMTRAITTYPE", traitType)
end

-- The style material link and the style name; nil for styles without a material.
function MWC.KeyItems.StyleMaterial(styleId)
  if not styleId or styleId == 0 then return nil end
  local link = GetItemStyleMaterialLink(styleId, LINK_STYLE_DEFAULT)
  if not link or link == "" then return nil end
  return link, zo_strformat("<<1>>", GetItemStyleName(styleId))
end

local function ItemEntry(itemId, kind, link, detail)
  link = link or MWC.LinkFromItemId(itemId)
  return {
    key = MWC.KeyItems.ItemKey(itemId), itemId = itemId, link = link, kind = kind,
    name = MWC.ItemName(link), detail = detail or "", quality = GetItemLinkFunctionalQuality(link),
    price = MWC.Price.Of(link),
  }
end

local function Traits(craft)
  local wanted = {}
  for _, category in ipairs(TRAIT_CATEGORIES[craft]) do
    wanted[category] = true
  end
  local entries, seen = {}, {}
  for traitType = 1, MAX_TRAIT_TYPE do
    if wanted[GetItemTraitTypeCategory(traitType)] then
      local link, traitName = MWC.KeyItems.TraitStone(traitType)
      local itemId = link and GetItemLinkItemId(link)
      if itemId and itemId ~= 0 and not seen[itemId] then
        seen[itemId] = true
        table.insert(entries, ItemEntry(itemId, "Trait", link, traitName))
      end
    end
  end
  return entries
end

local function Styles()
  local entries, seen = {}, {}
  for index = 1, GetNumValidItemStyles() do
    local styleId = GetValidItemStyleId(index)
    local link, styleName = MWC.KeyItems.StyleMaterial(styleId)
    local itemId = link and GetItemLinkItemId(link)
    if itemId and not seen[itemId] then
      seen[itemId] = true
      table.insert(entries, ItemEntry(itemId, "Style", link, styleName))
    end
  end
  return entries
end

-- Food and drink recipes only: furnishing recipes share the same lists but use other materials.
-- The game lists ingredients only for known recipes.
local FOOD_TYPES = { [ITEMTYPE_FOOD] = true, [ITEMTYPE_DRINK] = true }

local function ProvisioningIngredients()
  local entries, seen = {}, {}
  for listIndex = 1, GetNumRecipeLists() do
    local _, numRecipes = GetRecipeListInfo(listIndex)
    for recipeIndex = 1, numRecipes do
      local _, _, numIngredients = GetRecipeInfo(listIndex, recipeIndex)
      local result = GetRecipeResultItemLink(listIndex, recipeIndex, LINK_STYLE_DEFAULT)
      if result ~= "" and FOOD_TYPES[GetItemLinkItemType(result)] then
        for i = 1, numIngredients do
          local link = GetRecipeIngredientItemLink(listIndex, recipeIndex, i, LINK_STYLE_DEFAULT)
          local itemId = GetItemLinkItemId(link)
          if itemId ~= 0 and not seen[itemId] then
            seen[itemId] = true
            table.insert(entries, ItemEntry(itemId, "Ingredient", link))
          end
        end
      end
    end
  end
  return entries
end

-- Everything that can matter for one craft's writs.
function MWC.KeyItems.Catalog(craft)
  local entries = {}
  if craft == "alchemy" then
    for _, id in ipairs(MWC.Alchemy.ReagentIds()) do
      table.insert(entries, ItemEntry(id, "Reagent"))
    end
    for _, id in ipairs(ALCHEMY_SOLVENTS) do
      table.insert(entries, ItemEntry(id, "Solvent"))
    end
  elseif craft == "enchanting" then
    for _, rune in ipairs(MWC.Enchanting.WritRunes()) do
      table.insert(entries, ItemEntry(rune.itemId, rune.kind))
    end
  elseif craft == "provisioning" then
    entries = ProvisioningIngredients()
  else
    entries = {}
    for _, material in ipairs(MWC.Gear.CatalogMaterials(craft)) do
      table.insert(entries, ItemEntry(material.itemId, material.kind))
    end
    for _, entry in ipairs(Traits(craft)) do
      table.insert(entries, entry)
    end
    if STYLED_CRAFTS[craft] then
      table.insert(entries, ItemEntry(MWC.Gear.MIMIC_STONE_ID, "Style"))
      for _, entry in ipairs(Styles()) do
        table.insert(entries, entry)
      end
    end
  end
  for _, entry in ipairs(entries) do
    entry.enabled = MWC.KeyItems.IsEnabled(entry.key)
  end
  return entries
end

-- Key items window -----------------------------------------------------------

MWC.KeyWindow = {}

local ROW_TYPE, ROW_HEIGHT = 1, 28
local GOLD = { 0.77, 0.76, 0.62, 1 }
local TAB_ICON_PATH = "esoui/art/inventory/%s_%s.dds"
local TABS = {
  { type = "blacksmithing", label = "Blacksmithing", icon = "inventory_tabicon_craftbag_blacksmithing" },
  { type = "clothier", label = "Clothing", icon = "inventory_tabicon_craftbag_clothing" },
  { type = "woodworking", label = "Woodworking", icon = "inventory_tabicon_craftbag_woodworking" },
  { type = "jewelry", label = "Jewelry crafting", icon = "inventory_tabicon_craftbag_jewelrycrafting" },
  { type = "alchemy", label = "Alchemy", icon = "inventory_tabicon_craftbag_alchemy" },
  { type = "enchanting", label = "Enchanting", icon = "inventory_tabicon_craftbag_enchanting" },
  { type = "provisioning", label = "Provisioning", icon = "inventory_tabicon_craftbag_provisioning" },
}
local HEADER_TITLES = { On = "On", Name = "Item", Detail = "Trait/Style", Kind = "Kind", QualityText = "Quality", Price = "TTC price" }
local SORT_VALUES = {
  On = function(entry) return entry.enabled and 1 or 0 end,
  Name = function(entry) return zo_strlower(entry.name) end,
  Detail = function(entry) return zo_strlower(entry.detail) end,
  Kind = function(entry) return entry.kind end,
  QualityText = function(entry) return entry.quality end,
  Price = function(entry) return entry.price or -1 end,
}
local TEXT_COLUMNS = { Name = true, Detail = true, Kind = true }
local SORT_ARROW = { [true] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortdown.dds|t", [false] = "|t14:14:EsoUI/Art/Miscellaneous/list_sortup.dds|t" }

local window, list
local tabControls = {}

-- Checked first, then the best quality, then by name, unless a column was clicked.
local function SortEntries(entries)
  local sort = MWC.sv.keySort
  local value = sort and SORT_VALUES[sort.column]
  local byName = SORT_VALUES.Name
  table.sort(entries, function(a, b)
    if value then
      local va, vb = value(a), value(b)
      if va ~= vb then
        if sort.desc then return va > vb end
        return va < vb
      end
    else
      if a.enabled ~= b.enabled then return a.enabled end
      if a.quality ~= b.quality then return a.quality > b.quality end
    end
    return byName(a) < byName(b)
  end)
end

local function ApplyHeaderTitles()
  local header = window:GetNamedChild("Header")
  local sort = MWC.sv.keySort
  for column, text in pairs(HEADER_TITLES) do
    local arrow = sort and sort.column == column and (" " .. SORT_ARROW[sort.desc]) or ""
    header:GetNamedChild(column):SetText(text .. arrow)
  end
end

-- Keeping an item changes only the writs of the crafts that use it; one no craft can be told for refreshes all.
local function RefreshFor(entry)
  local crafts = MWC.Plan.CraftsOfItem(entry.link)
  MWC.UI.Refresh(#crafts > 0 and crafts or nil)
end

local function SetupRow(row, entry)
  row.entry = entry
  row:SetAlpha(entry.enabled and 1 or 0.55)
  ZO_CheckButton_SetCheckState(row:GetNamedChild("Check"), entry.enabled)
  local color = GetItemQualityColor(entry.quality)
  row:GetNamedChild("Quality"):SetColor(color:UnpackRGBA())
  row:GetNamedChild("Icon"):SetTexture((GetItemLinkInfo(entry.link)))
  row:GetNamedChild("Name"):SetText(color:Colorize("[" .. entry.name .. "]"))
  row:GetNamedChild("Detail"):SetText(entry.detail)
  row:GetNamedChild("Kind"):SetText(entry.kind)
  row:GetNamedChild("QualityText"):SetText(color:Colorize(GetString("SI_ITEMQUALITY", entry.quality)))
  row:GetNamedChild("Price"):SetText(entry.price and ZO_CommaDelimitNumber(zo_round(entry.price)) or "—")
end

function MWC.KeyWindow.Refresh()
  if window:IsHidden() then return end
  local entries = MWC.KeyItems.Catalog(MWC.sv.keyTab)
  SortEntries(entries)
  ZO_ScrollList_Clear(list)
  local dataList = ZO_ScrollList_GetDataList(list)
  for i, entry in ipairs(entries) do
    table.insert(dataList, ZO_ScrollList_CreateDataEntry(ROW_TYPE, { entry = entry, odd = i % 2 == 1 }))
  end
  ZO_ScrollList_Commit(list)

  for i, tab in ipairs(TABS) do
    local selected = tab.type == MWC.sv.keyTab
    tabControls[i]:GetNamedChild("Icon"):SetTexture(string.format(TAB_ICON_PATH, tab.icon, selected and "down" or "up"))
    tabControls[i]:GetNamedChild("Underline"):SetHidden(not selected)
  end
  ApplyHeaderTitles()
end

function MWC.KeyWindow.SelectTab(tabType)
  MWC.sv.keyTab = tabType
  MWC.KeyWindow.Refresh()
end

function MWC.KeyWindow.OnRowEnter(row)
  if not row.entry then return end
  row:GetNamedChild("Highlight"):SetHidden(false)
  MWC.UI.ShowItemTooltip(row, row.entry.link)
end

function MWC.KeyWindow.OnRowExit(row)
  row:GetNamedChild("Highlight"):SetHidden(true)
  ClearTooltip(ItemTooltip)
end

-- Left click toggles the item; right click links it in chat (hovering already shows its tooltip).
function MWC.KeyWindow.OnRowClicked(row, button)
  local entry = row.entry
  if not entry then return end
  if button == MOUSE_BUTTON_INDEX_RIGHT then
    MWC.LinkInChat(entry.link)
  else
    entry.enabled = not entry.enabled
    MWC.KeyItems.SetEnabled(entry.key, entry.enabled)
    SetupRow(row, entry)
    RefreshFor(entry)
  end
end

function MWC.KeyWindow.Show()
  window:SetHidden(false)
  window:BringWindowToTop()
  MWC.KeyWindow.Refresh()
end

function MWC.KeyWindow.Hide()
  window:SetHidden(true)
  ClearTooltip(ItemTooltip)
end

function MWC.KeyWindow.Toggle()
  if window:IsHidden() then
    MWC.KeyWindow.Show()
  else
    MWC.KeyWindow.Hide()
  end
end

function MWC.KeyWindow.SavePosition()
  MWC.sv.keyLeft = window:GetLeft()
  MWC.sv.keyTop = window:GetTop()
end

local function SortBy(column, reset)
  if reset then
    MWC.sv.keySort = nil
  elseif MWC.sv.keySort and MWC.sv.keySort.column == column then
    MWC.sv.keySort.desc = not MWC.sv.keySort.desc
  else
    MWC.sv.keySort = { column = column, desc = not TEXT_COLUMNS[column] }
  end
  MWC.KeyWindow.Refresh()
end

function MWC.KeyWindow.Init()
  window = MWC_KeyWindow
  list = window:GetNamedChild("List")
  window:GetNamedChild("Solid"):SetColor(0, 0, 0, 0.85)

  ZO_ScrollList_AddDataType(list, ROW_TYPE, "MWC_KeyRow", ROW_HEIGHT, function(row, data)
    if not row.initialized then
      row:GetNamedChild("BG"):SetColor(1, 1, 1, 0.04)
      row:GetNamedChild("Highlight"):SetColor(GOLD[1], GOLD[2], GOLD[3], 0.15)
      ZO_CheckButton_SetToggleFunction(row:GetNamedChild("Check"), function(_, checked)
        local entry = row.entry
        MWC.KeyItems.SetEnabled(entry.key, checked)
        entry.enabled = checked
        SetupRow(row, entry)
        RefreshFor(entry)
      end)
      row.initialized = true
    end
    row:GetNamedChild("BG"):SetHidden(not data.odd)
    SetupRow(row, data.entry)
  end)

  local header = window:GetNamedChild("Header")
  header:SetMouseEnabled(false)
  for _, child in ipairs({ "BG", "Check", "Quality", "Icon" }) do
    header:GetNamedChild(child):SetHidden(true)
  end
  for column in pairs(HEADER_TITLES) do
    local label = header:GetNamedChild(column)
    label:SetFont("ZoFontGameSmall")
    label:SetColor(unpack(GOLD))
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
      if upInside then SortBy(column, button == MOUSE_BUTTON_INDEX_RIGHT) end
    end)
  end

  local container = window:GetNamedChild("Tabs")
  local previous
  for i, tab in ipairs(TABS) do
    local control = CreateControlFromVirtual("$(parent)Tab", container, "MWC_KeyTab", i)
    control.tabType, control.tabLabel = tab.type, tab.label
    control:GetNamedChild("Underline"):SetColor(unpack(GOLD))
    if previous then
      control:SetAnchor(LEFT, previous, RIGHT, 0, 0)
    else
      control:SetAnchor(LEFT, container, LEFT, 0, 0)
    end
    tabControls[i] = control
    previous = control
  end

  if MWC.sv.keyLeft then
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, MWC.sv.keyLeft, MWC.sv.keyTop)
  end
end
