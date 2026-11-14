Vermilion = Vermilion or {}
Vermilion.Assign = {}
local M = Vermilion.Assign

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local GetString               = api.GetString
local GetAbilityName          = api.GetAbilityName
local WINDOW_MANAGER          = zui.WINDOW_MANAGER
local CreateControlFromVirtual = zui.CreateControlFromVirtual
local math_floor              = math.floor
local math_ceil               = math.ceil
local string_format           = string.format
local table_concat            = table.concat

local log = Vermilion.Log.for_module("assign")

local TOPLEFT     = zc.TOPLEFT
local TOPRIGHT    = zc.TOPRIGHT
local BOTTOMRIGHT = zc.BOTTOMRIGHT
local LEFT        = zc.LEFT
local RIGHT       = zc.RIGHT
local CENTER      = zc.CENTER
local GuiRoot     = zc.GuiRoot
local CT_TEXTURE  = zc.CT_TEXTURE
local CT_LABEL    = zc.CT_LABEL
local CT_CONTROL  = zc.CT_CONTROL
local TEXT_ALIGN_LEFT   = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER

local SkillColors = Vermilion.SkillColors

local function hex(c)
  return string_format("%02X%02X%02X",
    math_floor(c.r * 255 + 0.5), math_floor(c.g * 255 + 0.5), math_floor(c.b * 255 + 0.5))
end

local function colored_label(key)
  local c = SkillColors.group_color(key)
  return "|c" .. hex(c) .. SkillColors.group_label(key) .. "|r"
end

-- layout constants 
local ROW_H            = 30
local FALLBACK_MAXROWS = 8
local FLYOUT_PAD       = 6
local FLYOUT_ENTRY_H   = 16
local FLYOUT_COL_W     = 158
local FLYOUT_COLS      = 2

-- state
local controls  = {}
local row_pool
local active_id
local pending   = {}
local open_flyout_for
local assign_active

local function row_factory(row, counter)
  local nm = "VermilionAssignRow" .. counter
  row:SetMouseEnabled(false)

  local icon = WINDOW_MANAGER:CreateControl(nm .. "Icon", row, CT_TEXTURE)
  icon:SetDimensions(24, 24)
  icon:SetAnchor(LEFT, row, LEFT, 2, 0)
  row.vm_icon = icon

  local pick = CreateControlFromVirtual(nm .. "Pick", row, "ZO_DefaultButton")
  pick:SetDimensions(130, 24)
  pick:SetAnchor(RIGHT, row, RIGHT, 0, 0)
  Vermilion.Skin.button(pick)
  pick:SetHandler("OnClicked", function() open_flyout_for(row) end)
  row.vm_pick = pick

  local name = WINDOW_MANAGER:CreateControl(nm .. "Name", row, CT_LABEL)
  name:SetFont("ZoFontGame")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetAnchor(LEFT,  icon, RIGHT, 8, 0)
  name:SetAnchor(RIGHT, pick, LEFT, -8, 0)
  name:SetColor(0.92, 0.92, 0.92, 1)
  row.vm_name = name
end

local function row_reset(row)
  row:SetHidden(true)
  row:ClearAnchors()
end

local function build_flyout()
  local fly    = controls.flyout
  local groups = SkillColors.groups_ordered()
  local n      = #groups
  local rows_per_col = math_ceil(n / FLYOUT_COLS)

  for i = 1, n do
    local g   = groups[i]
    local col = math_floor((i - 1) / rows_per_col)
    local r   = (i - 1) % rows_per_col
    local e = WINDOW_MANAGER:CreateControl("VermilionAssignFlyoutE" .. i, fly, CT_LABEL)
    e:SetFont("ZoFontGameSmall")
    e:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    e:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    e:SetDimensions(FLYOUT_COL_W, FLYOUT_ENTRY_H)
    e:SetAnchor(TOPLEFT, fly, TOPLEFT, FLYOUT_PAD + col * FLYOUT_COL_W, FLYOUT_PAD + r * FLYOUT_ENTRY_H)
    e:SetText(g.label)
    e:SetColor(g.r, g.g, g.b, 1)
    e:SetDrawLayer(DL_OVERLAY)
    e:SetDrawLevel(103)
    e:SetMouseEnabled(true)

    local key = g.key
    local cr, cg, cb = g.r, g.g, g.b
    e:SetHandler("OnMouseUp",    function() assign_active(key) end)
    e:SetHandler("OnMouseEnter", function(self) self:SetColor(1, 1, 1, 1) end)
    e:SetHandler("OnMouseExit",  function(self) self:SetColor(cr, cg, cb, 1) end)
  end

  fly:SetDimensions(FLYOUT_PAD * 2 + FLYOUT_COLS * FLYOUT_COL_W,
                    FLYOUT_PAD * 2 + rows_per_col * FLYOUT_ENTRY_H)
end

open_flyout_for = function(row)
  active_id = row.vm_id
  local fly = controls.flyout
  local btn = row.vm_pick
  fly:ClearAnchors()
  local _, screen_h = GuiRoot:GetDimensions()
  if btn:GetBottom() + fly:GetHeight() > screen_h then
    fly:SetAnchor(BOTTOMRIGHT, btn, TOPRIGHT, 0, -2)
  else
    fly:SetAnchor(TOPRIGHT, btn, BOTTOMRIGHT, 0, 2)
  end
  fly:SetHidden(false)
end

assign_active = function(key)
  local id = active_id
  controls.flyout:SetHidden(true)
  active_id = nil
  if not id then return end
  pending[id] = key
  M.refresh()
end

function M.refresh()
  row_pool:ReleaseAllObjects()
  controls.flyout:SetHidden(true)

  local unknowns = SkillColors.get_unknowns()
  controls.help:SetText("")
  if #unknowns == 0 then
    controls.empty:SetHidden(false)
    return
  end
  controls.empty:SetHidden(true)

  local list   = controls.list
  local lh      = list:GetHeight()
  local max_rows = (lh > 0) and math_floor(lh / ROW_H) or FALLBACK_MAXROWS

  local shown = 0
  for i = 1, #unknowns do
    if i > max_rows then break end
    local u   = unknowns[i]
    local row = row_pool:AcquireObject()
    row.vm_id = u.id
    if u.icon ~= "" then row.vm_icon:SetTexture(u.icon) end
    row.vm_icon:SetHidden(u.icon == "")
    row.vm_name:SetText(u.name)
    local chosen = pending[u.id]
    if chosen then
      row.vm_pick:SetText(colored_label(chosen))
    else
      row.vm_pick:SetText(GetString(VERMILION_ASSIGN_PICK))
    end
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT,  list, TOPLEFT,  0, (i - 1) * ROW_H)
    row:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, (i - 1) * ROW_H)
    row:SetHeight(ROW_H - 2)
    row:SetHidden(false)
    shown = shown + 1
  end

  if #unknowns > shown then
    controls.help:SetText(string_format(GetString(VERMILION_ASSIGN_MORE), #unknowns - shown))
  end
end

local CONFIRM_W       = 420
local CONFIRM_LINE_H  = 26
local CONFIRM_TOP_H   = 44
local CONFIRM_BTM_H   = 44
local CONFIRM_EXTRA   = 3

local function clear_pending()
  for id in pairs(pending) do pending[id] = nil end
end

local function pending_count()
  local n = 0
  for _ in pairs(pending) do n = n + 1 end
  return n
end

local function show_confirm()
  controls.flyout:SetHidden(true)

  local lines = {}
  for id, key in pairs(pending) do
    local name = GetAbilityName(id)
    if not name or name == "" then name = "#" .. id end
    lines[#lines + 1] = name .. "  \226\134\146  " .. colored_label(key)  -- " → "
  end
  table.sort(lines)

  controls.confirm_msg:SetText(table_concat(lines, "\n") .. "\n\n" .. GetString(VERMILION_ASSIGN_CONFIRM_NOTE))

  local h = CONFIRM_TOP_H + (#lines + CONFIRM_EXTRA) * CONFIRM_LINE_H + CONFIRM_BTM_H
  controls.confirm:SetDimensions(CONFIRM_W, h)

  controls.window:SetHidden(true)
  controls.confirm:SetHidden(false)
end

function M.show()
  controls.confirm:SetHidden(true)
  clear_pending()
  controls.window:SetHidden(false)
  M.refresh()
  Vermilion.Sound.play("open")
end

function M.hide()
  controls.flyout:SetHidden(true)
  controls.confirm:SetHidden(true)
  clear_pending()
  if not controls.window:IsHidden() then Vermilion.Sound.play("close") end
  controls.window:SetHidden(true)
  row_pool:ReleaseAllObjects()
end

function M.toggle()
  if controls.window:IsHidden() then M.show() else M.hide() end
end

function M.on_close_click() M.hide() end

function M.on_assign_click()
  if pending_count() == 0 then
    M.hide()
  else
    Vermilion.Sound.play("click")
    show_confirm()
  end
end

function M.on_confirm_no()
  Vermilion.Sound.play("discard")
  controls.confirm:SetHidden(true)
  controls.window:SetHidden(false)
  M.refresh()
end

function M.on_confirm_yes()
  local sv = Vermilion.SavedVars
  for id, key in pairs(pending) do
    SkillColors.set_override(id, key)
    if sv then
      sv.skill_overrides = sv.skill_overrides or {}
      sv.skill_overrides[id] = key
    end
    log:info("committed", id, "->", key)
  end
  Vermilion.Sound.play("confirm")
  controls.confirm:SetHidden(true)
  M.hide()
end

function M.on_move_stop()
  controls.flyout:SetHidden(true)
  local sv = Vermilion.SavedVars
  if not sv or not controls.window then return end
  sv.assign = sv.assign or {}
  sv.assign.x = controls.window:GetLeft()
  sv.assign.y = controls.window:GetTop()
end

function M.init()
  Vermilion.Skin.panel(VermilionAssignPanelBg)
  Vermilion.Skin.panel(VermilionAssignConfirmBg)
  Vermilion.Skin.close(VermilionAssignPanelCloseBtn)
  Vermilion.Skin.button(VermilionAssignPanelAssignBtn, true)
  Vermilion.Skin.button(VermilionAssignConfirmNoBtn)
  Vermilion.Skin.button(VermilionAssignConfirmYesBtn, true)
  controls.window     = VermilionAssignPanel
  controls.title      = VermilionAssignPanelWindowTitle
  controls.help       = VermilionAssignPanelHelpLabel
  controls.list       = VermilionAssignPanelList
  controls.empty      = VermilionAssignPanelListEmpty
  controls.assign_btn = VermilionAssignPanelAssignBtn
  controls.flyout     = VermilionAssignPanelFlyout
  controls.confirm       = VermilionAssignConfirm
  controls.confirm_title = VermilionAssignConfirmTitle
  controls.confirm_msg   = VermilionAssignConfirmMsg
  controls.confirm_yes   = VermilionAssignConfirmYesBtn
  controls.confirm_no    = VermilionAssignConfirmNoBtn

  VermilionAssignPanelFlyoutFill:SetTexture("EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds")
  VermilionAssignPanelFlyoutFill:SetTextureCoords(0, 1, 0, 0.05)
  VermilionAssignPanelFlyoutFill:SetColor(0.070, 0.050, 0.050, 0.985)
  VermilionAssignPanelFlyoutFill:SetDrawLayer(DL_OVERLAY)
  VermilionAssignPanelFlyoutFill:SetDrawLevel(101)
  VermilionAssignPanelFlyoutBg:SetCenterColor(0.085, 0.060, 0.058, 0.98)
  VermilionAssignPanelFlyoutBg:SetEdgeColor(1.00, 0.45, 0.40, 0.85)
  VermilionAssignPanelFlyoutBg:SetDrawLayer(DL_OVERLAY)
  VermilionAssignPanelFlyoutBg:SetDrawLevel(102)
  controls.flyout:SetDrawLevel(100)

  controls.title:SetText(GetString(VERMILION_ASSIGN_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)
  controls.help:SetColor(0.85, 0.70, 0.30, 1)
  controls.empty:SetText(GetString(VERMILION_ASSIGN_EMPTY))
  controls.empty:SetColor(0.45, 0.45, 0.45, 1)
  controls.empty:SetHidden(true)
  controls.assign_btn:SetText(GetString(VERMILION_ASSIGN_DONE))

  controls.confirm_title:SetText(GetString(VERMILION_ASSIGN_CONFIRM_TITLE))
  controls.confirm_title:SetColor(0.92, 0.55, 0.50, 1)
  controls.confirm_msg:SetColor(0.90, 0.90, 0.90, 1)
  controls.confirm_yes:SetText(GetString(VERMILION_ASSIGN_CONFIRM_YES))
  controls.confirm_no:SetText(GetString(VERMILION_ASSIGN_CONFIRM_NO))
  controls.confirm:SetHidden(true)

  row_pool = Vermilion.lib.plot.Pool.new("VermilionAssignRowC", controls.list, CT_CONTROL, row_factory, row_reset)
  build_flyout()

  local sv = Vermilion.SavedVars
  sv.assign = sv.assign or {}
  controls.window:ClearAnchors()
  if sv.assign.x and sv.assign.y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.assign.x, sv.assign.y)
  else
    controls.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  end

  log:info("init: categories=", #SkillColors.groups_ordered())
end
