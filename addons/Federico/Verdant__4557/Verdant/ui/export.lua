Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Export = {}
local M = Verdant.Export

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zev = Verdant.zenimax.events
local Scene = Verdant.zenimax.scene
local Sound = Verdant.Sound
local Skin = Verdant.Skin
local GetString = api.GetString
local math_floor = math.floor
local string_format = string.format
local table_concat = table.concat

local BUILD_TICK = "VerdantExportBuild"
local MAX_INPUT = 500000
local PAGE_DEFAULT = 24000
local PAGE_MIN = 2000
local RESERVED = 64
local WHEEL_FAST = 10

local window, edit, body, progress, meter
local pages, page = {}, 1
local text = ""
local page_limit = PAGE_DEFAULT

local function refresh_pager()
  local total = #pages
  local many = total > 1
  VerdantExportPrevBtn:SetHidden(not many)
  VerdantExportNextBtn:SetHidden(not many)
  VerdantExportPart:SetHidden(not many)
  VerdantExportPrevBtn:SetEnabled(page > 1)
  VerdantExportNextBtn:SetEnabled(page < total)
  VerdantExportPart:SetText(string_format(GetString(VERDANT_EXPORT_PART), page, total))
  VerdantExportSize:SetText(string_format(GetString(VERDANT_EXPORT_SIZE), #pages[page]))
end

local function select_all()
  edit:TakeFocus()
  edit:SelectAll()
end

local function show_page(i)
  page = i
  local p = pages[i]
  edit:SetText(p)
  if #edit:GetText() < #p and page_limit > PAGE_MIN then
    page_limit = math.max(PAGE_MIN, math_floor(page_limit / 2))
    pages = Verdant.ExportReport.paginate(text, page_limit - RESERVED)
    return show_page(1)
  end
  refresh_pager()
  select_all()
end

local function set_building(on)
  progress:SetHidden(not on)
  body:SetHidden(on)
  VerdantExportSelectBtn:SetEnabled(not on)
end

local function finish(parts)
  zev.unregister_update(BUILD_TICK)
  text = table_concat(parts, "\n")
  pages = Verdant.ExportReport.paginate(text, page_limit - RESERVED)
  set_building(false)
  show_page(1)
end

function M.open()
  if not Verdant.Graph.fight_available() then return end
  zev.unregister_update(BUILD_TICK)
  set_building(true)
  Scene.show_top_level(window)
  Sound.play("open")
  local sections = Verdant.ExportReport.SECTIONS
  local parts, i = {}, 0
  meter.set(GetString(VERDANT_EXPORT_BUILDING), "", 0)
  zev.register_update(BUILD_TICK, 0, function()
    i = i + 1
    local s = sections[i]
    if not s then return finish(parts) end
    local part = s()
    if part ~= "" then parts[#parts + 1] = part end
    meter.set(GetString(VERDANT_EXPORT_BUILDING), string_format("%d / %d", i, #sections), i / #sections)
  end)
end

function M.hide()
  zev.unregister_update(BUILD_TICK)
  if window:IsHidden() then return end
  edit:LoseFocus()
  Sound.play("close")
  Scene.hide_top_level(window)
end

function M.prev_page()
  if page > 1 then
    Sound.play("page")
    show_page(page - 1)
  end
end

function M.next_page()
  if page < #pages then
    Sound.play("page")
    show_page(page + 1)
  end
end

function M.on_select_click()
  Sound.play("click")
  select_all()
end

function M.pages() return pages, page, page_limit end

local function on_wheel(self, delta, _, _, shift)
  if shift then delta = delta * WHEEL_FAST end
  local top = self:GetTopLineIndex() - delta
  local last = self:GetScrollExtents() + 1
  if top < 1 then top = 1 elseif top > last then top = last end
  self:SetTopLineIndex(top)
end

local function give_keyboard_back(self) self:LoseFocus() end

function M.init()
  window = VerdantExport
  Scene.register_top_level(window)
  Skin.panel(VerdantExportBg)
  Skin.close(VerdantExportCloseBtn)
  Skin.button(VerdantExportSelectBtn, true)
  Skin.icon(VerdantExportPrevBtn, "arrow_left")
  Skin.icon(VerdantExportNextBtn, "arrow_right")
  VerdantExportWindowTitle:SetText(GetString(VERDANT_EXPORT_TITLE))
  VerdantExportSelectBtn:SetText(GetString(VERDANT_EXPORT_SELECT))
  VerdantExportHint:SetText(GetString(VERDANT_EXPORT_HINT))
  Skin.label(VerdantExportHint, "dim")
  Skin.label(VerdantExportSize, "dim")
  Skin.label(VerdantExportPart, "text")

  body = VerdantExportBody
  progress = VerdantExportProgress
  Skin.section(body)
  edit = zui.CreateControlFromVirtual("VerdantExportEdit", body, "ZO_DefaultEditMultiLineForBackdrop")
  edit:SetMaxInputChars(MAX_INPUT)
  edit:SetFont("ZoFontChat")
  zui.handler(edit, "OnMouseWheel", on_wheel)
  zui.handler(edit, "OnEscape", give_keyboard_back)
  zui.handler(edit, "OnEffectivelyHidden", give_keyboard_back)
  meter = Verdant.Meter.new("VerdantExportMeter", progress, 0, 0, 320)
end
