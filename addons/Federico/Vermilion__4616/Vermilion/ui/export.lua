Vermilion = Vermilion or {}
Vermilion.Export = {}
local M = Vermilion.Export

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zev = Vermilion.zenimax.events
local Scene = Vermilion.zenimax.scene
local Sound = Vermilion.Sound
local GetString = api.GetString
local string_format = string.format
local table_concat = table.concat

local BUILD_TICK = "VermilionExportBuild"
local MAX_INPUT = 500000
local PAGE_DEFAULT = 24000
local PAGE_MIN = 2000
local RESERVED = 64

local window, edit, body, progress, meter
local pages, page = {}, 1
local text = ""
local page_limit = PAGE_DEFAULT

local function refresh_pager()
  local total = #pages
  local many = total > 1
  VermilionExportPrevBtn:SetHidden(not many)
  VermilionExportNextBtn:SetHidden(not many)
  VermilionExportPart:SetHidden(not many)
  VermilionExportPrevBtn:SetEnabled(page > 1)
  VermilionExportNextBtn:SetEnabled(page < total)
  VermilionExportPart:SetText(string_format(GetString(VERMILION_EXPORT_PART), page, total))
  VermilionExportSize:SetText(string_format(GetString(VERMILION_EXPORT_SIZE), #(pages[page] or "")))
end

local function select_all()
  edit:TakeFocus()
  edit:SelectAll()
end

local function show_page(i)
  page = i
  local p = pages[i] or ""
  edit:SetText(p)
  if #edit:GetText() < #p and page_limit > PAGE_MIN then
    page_limit = math.max(PAGE_MIN, math.floor(page_limit / 2))
    pages = Vermilion.ExportReport.paginate(text, page_limit - RESERVED)
    return show_page(1)
  end
  refresh_pager()
  select_all()
end

local function set_building(on)
  progress:SetHidden(not on)
  body:SetHidden(on)
  VermilionExportSelectBtn:SetEnabled(not on)
end

local function finish(parts)
  zev.unregister_update(BUILD_TICK)
  text = table_concat(parts, "\n")
  pages = Vermilion.ExportReport.paginate(text, page_limit - RESERVED)
  set_building(false)
  show_page(1)
end

function M.open()
  if not Vermilion.Graph.export_available() then return end
  zev.unregister_update(BUILD_TICK)
  VermilionExportWindowTitle:SetText(GetString(VERMILION_EXPORT_TITLE))
  set_building(true)
  Scene.show_top_level(window)
  Sound.play("open")
  local sections = Vermilion.ExportReport.SECTIONS
  local parts, i = {}, 0
  meter.set(GetString(VERMILION_EXPORT_BUILDING), "", 0)
  zev.register_update(BUILD_TICK, 0, function()
    i = i + 1
    local s = sections[i]
    if not s then return finish(parts) end
    local part = s()
    if part ~= "" then parts[#parts + 1] = part end
    meter.set(GetString(VERMILION_EXPORT_BUILDING), string_format("%d / %d", i, #sections), i / #sections)
  end)
end

function M.hide()
  zev.unregister_update(BUILD_TICK)
  if window:IsHidden() then return end
  edit:LoseFocus()
  Sound.play("close")
  Scene.hide_top_level(window)
end

function M.prev_page() if page > 1 then Sound.play("page"); show_page(page - 1) end end
function M.next_page() if page < #pages then Sound.play("page"); show_page(page + 1) end end
function M.on_select_click() Sound.play("click"); select_all() end
function M.pages() return pages, page, page_limit end

function M.copy_test(chars)
  local n = chars or PAGE_DEFAULT
  local lines, size, i = {}, 0, 0
  while size < n do
    i = i + 1
    local l = string_format("%08d ................................................", i)
    lines[i] = l
    size = size + #l + 1
  end
  lines[i + 1] = string_format("END %d", size)
  text = table_concat(lines, "\n")
  pages = { text }
  set_building(false)
  VermilionExportWindowTitle:SetText(string_format("copy test %d", size))
  Scene.show_top_level(window)
  edit:SetText(text)
  refresh_pager()
  select_all()
  return size, #edit:GetText()
end

function M.init()
  window = VermilionExport
  Scene.register_top_level(window)
  window:SetHidden(true)
  Vermilion.Skin.panel(VermilionExportBg)
  Vermilion.Skin.close(VermilionExportCloseBtn)
  Vermilion.Skin.button(VermilionExportSelectBtn, true)
  Vermilion.Skin.icons({ VermilionExportPrevBtn, VermilionExportNextBtn })
  VermilionExportSelectBtn:SetText(GetString(VERMILION_EXPORT_SELECT))
  VermilionExportHint:SetText(GetString(VERMILION_EXPORT_HINT))
  VermilionExportHint:SetColor(0.62, 0.56, 0.54, 1)
  VermilionExportSize:SetColor(0.62, 0.56, 0.54, 1)
  VermilionExportPart:SetColor(0.92, 0.88, 0.84, 1)

  body = VermilionExportBody
  progress = VermilionExportProgress
  Vermilion.Skin.section(body)
  edit = zui.CreateControlFromVirtual("VermilionExportEdit", body, "ZO_DefaultEditMultiLineForBackdrop")
  edit:SetMaxInputChars(MAX_INPUT)
  edit:SetFont("ZoFontChat")
  edit:SetHandler("OnMouseWheel", function(self, delta, _, _, shift)
    if shift then delta = delta * 10 end
    self:SetTopLineIndex(zo_clamp(self:GetTopLineIndex() - delta, 1, self:GetScrollExtents() + 1))
  end)
  edit:SetHandler("OnEscape", function(self) self:LoseFocus() end)
  edit:SetHandler("OnEffectivelyHidden", function(self) self:LoseFocus() end)
  meter = Vermilion.Meter.new("VermilionExportMeter", progress, 0, 0, 320)
end
