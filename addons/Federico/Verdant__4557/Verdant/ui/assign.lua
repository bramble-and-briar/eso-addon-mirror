Verdant = Verdant or {}
local Verdant = Verdant
Verdant.Assign = {}
local M = Verdant.Assign

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local Scene = Verdant.zenimax.scene
local zev = Verdant.zenimax.events
local GetString               = api.GetString
local GetAbilityName          = api.GetAbilityName
local WINDOW_MANAGER          = zui.WINDOW_MANAGER
local CreateControlFromVirtual = zui.CreateControlFromVirtual
local math_floor              = math.floor
local math_ceil               = math.ceil
local string_format           = string.format
local table_concat            = table.concat

local log = Verdant.Log.for_module("assign")

-- anchor / type constants
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

local SkillColors = Verdant.SkillColors
local function hex(c)
  return string_format("%02X%02X%02X",
    math_floor(c.r * 255 + 0.5), math_floor(c.g * 255 + 0.5), math_floor(c.b * 255 + 0.5))
end

local function colored_label(key)
  local c = SkillColors.group_color(key)
  return "|c" .. hex(c) .. SkillColors.group_label(key) .. "|r"
end


local ROW_H            = 30
local FALLBACK_MAXROWS = 8
local FLYOUT_PAD       = 6
local FLYOUT_ENTRY_H   = 16
local FLYOUT_COL_W     = 158
local FLYOUT_COLS      = 2
local SUGGEST_STEPS = 24
local SUGGEST_S, SUGGEST_V = 0.65, 0.95
local Sound = Verdant.Sound
local Skin  = Verdant.Skin
local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"


local controls  = {}
local row_pool
local active_id
local pending   = {}
local open_flyout_for
local assign_active
local fly_entries = {}
local scroll_off = 0
local newcat_for
local newcat_rgb = { r = 1, g = 1, b = 1 }
local entries = {}
local aliases = {}

local function row_factory(row, counter)
  local nm = "VerdantAssignRow" .. counter
  local icon = WINDOW_MANAGER:CreateControl(nm .. "Icon", row, CT_TEXTURE)
  icon:SetDimensions(24, 24)
  icon:SetAnchor(LEFT, row, LEFT, 2, 0)
  row.vm_icon = icon

  local pick = CreateControlFromVirtual(nm .. "Pick", row, "ZO_DefaultButton")
  pick:SetDimensions(130, 24)
  Skin.button(pick)
  pick:SetAnchor(RIGHT, row, RIGHT, 0, 0)
  zui.handler(pick, "OnClicked", function() open_flyout_for(row) end)
  zui.handler(pick, "OnMouseWheel", function(_, delta) M.on_scroll(delta) end)
  row:SetMouseEnabled(true)
  zui.handler(row, "OnMouseWheel", function(_, delta) M.on_scroll(delta) end)
  row.vm_pick = pick

  local name = WINDOW_MANAGER:CreateControl(nm .. "Name", row, CT_LABEL)
  name:SetFont("ZoFontGame")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetAnchor(LEFT,  icon, RIGHT, 8, 0)
  name:SetAnchor(RIGHT, pick, LEFT, -8, 0)
  name:SetMaxLineCount(1)
  name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  name:SetColor(0.92, 0.92, 0.92, 1)
  row.vm_name = name
end

local function row_reset(row)
  row:SetHidden(true)
  row:ClearAnchors()
end

local function trimmed_name()
  local name = tostring(controls.newcat_edit:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function existing(name)
  local ck = SkillColors.custom_key(name)
  if SkillColors.is_custom(ck) then return ck end
  local low = name:lower()
  for _, g in ipairs(SkillColors.groups_ordered()) do
    if g.label:lower() == low then return g.key end
  end
  return nil
end

local function distance(a, r, g, b)
  local dr, dg, db = a.r - r, a.g - g, a.b - b
  return 2 * dr * dr + 4 * dg * dg + 3 * db * db
end

local function nearest(c)
  local best, best_d
  for _, g in ipairs(SkillColors.groups_ordered()) do
    local d = distance(g, c.r, c.g, c.b)
    if not best_d or d < best_d then best, best_d = g.key, d end
  end
  return best
end

local function hsv(h, sat, val)
  local i = math_floor(h * 6)
  local f = h * 6 - i
  local p, q, t = val * (1 - sat), val * (1 - f * sat), val * (1 - (1 - f) * sat)
  i = i % 6
  if i == 0 then return val, t, p end
  if i == 1 then return q, val, p end
  if i == 2 then return p, val, t end
  if i == 3 then return p, q, val end
  if i == 4 then return t, p, val end
  return val, p, q
end

local function suggestion()
  local groups = SkillColors.groups_ordered()
  local br, bg, bb = hsv(0, SUGGEST_S, SUGGEST_V)
  local best_d
  for i = 0, SUGGEST_STEPS - 1 do
    local r, g, b = hsv(i / SUGGEST_STEPS, SUGGEST_S, SUGGEST_V)
    local d
    for _, grp in ipairs(groups) do
      local x = distance(grp, r, g, b)
      if not d or x < d then d = x end
    end
    if d and (not best_d or d > best_d) then br, bg, bb, best_d = r, g, b, d end
  end
  return br, bg, bb
end

local function refresh_newcat()
  local c = newcat_rgb
  local name = trimmed_name()
  controls.newcat_sample:SetColor(c.r, c.g, c.b, 1)
  controls.newcat_preview:SetText(name ~= "" and name or GetString(VERDANT_ASSIGN_NEW_TITLE))
  controls.newcat_preview:SetColor(c.r, c.g, c.b, 1)
  local key = name ~= "" and existing(name) or nil
  local note
  if key and SkillColors.is_custom(key) then
    note = string_format(GetString(VERDANT_ASSIGN_NEW_RECOLOR), colored_label(key))
  elseif key then
    note = string_format(GetString(VERDANT_ASSIGN_NEW_TAKEN), colored_label(key))
  else
    local near = nearest(c)
    note = near and string_format(GetString(VERDANT_ASSIGN_NEW_NEAREST), colored_label(near)) or ""
  end
  controls.newcat_note:SetText(note)
end

local function open_newcat()
  newcat_for = active_id
  active_id = nil
  controls.flyout:SetHidden(true)
  newcat_rgb.r, newcat_rgb.g, newcat_rgb.b = suggestion()
  controls.newcat_edit:SetText("")
  refresh_newcat()
  controls.newcat:SetHidden(false)
end

local function picked(r, g, b)
  controls.window:SetDrawTier(zc.DT_HIGH)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
  newcat_rgb.r, newcat_rgb.g, newcat_rgb.b = r, g, b
  refresh_newcat()
end

local picked_door = zev.guard("Verdant_ColorPicked", picked)

function M.on_newcat_pick()
  local c = newcat_rgb
  controls.window:SetDrawTier(zc.DT_MEDIUM)
  if not zui.pick_color(picked_door, c.r, c.g, c.b) then
    controls.window:SetDrawTier(zc.DT_HIGH)
    Sound.play("deny")
    controls.newcat_note:SetText(GetString(VERDANT_ASSIGN_NEW_NOPICKER))
    return
  end
  Sound.play("click")
end

local function build_flyout()
  local fly    = controls.flyout
  local groups = SkillColors.groups_ordered()
  local n      = #groups + 1
  local rows_per_col = math_ceil(n / FLYOUT_COLS)

  for i = 1, n do
    local col = math_floor((i - 1) / rows_per_col)
    local r   = (i - 1) % rows_per_col
    local e = fly_entries[i]
    if not e then
      e = WINDOW_MANAGER:CreateControl("VerdantAssignFlyoutE" .. i, fly, CT_LABEL)
      e:SetDrawLayer(DL_OVERLAY)
      e:SetDrawLevel(103)
      e:SetFont("ZoFontGameSmall")
      e:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      e:SetVerticalAlignment(TEXT_ALIGN_CENTER)
      e:SetDimensions(FLYOUT_COL_W, FLYOUT_ENTRY_H)
      e:SetMouseEnabled(true)
      fly_entries[i] = e
    end
    e:ClearAnchors()
    e:SetAnchor(TOPLEFT, fly, TOPLEFT, FLYOUT_PAD + col * FLYOUT_COL_W, FLYOUT_PAD + r * FLYOUT_ENTRY_H)
    e:SetHidden(false)
    if i <= #groups then
      local g = groups[i]
      local key = g.key
      local cr, cg, cb = g.r, g.g, g.b
      e:SetText(g.label)
      e:SetColor(cr, cg, cb, 1)
      zui.handler(e, "OnMouseUp",    function() assign_active(key) end)
      zui.handler(e, "OnMouseEnter", function(self) self:SetColor(1, 1, 1, 1) end)
      zui.handler(e, "OnMouseExit",  function(self) self:SetColor(cr, cg, cb, 1) end)
    else
      e:SetText(GetString(VERDANT_ASSIGN_NEW))
      e:SetColor(0.85, 0.70, 0.36, 1)
      zui.handler(e, "OnMouseUp",    function() Sound.play("click"); open_newcat() end)
      zui.handler(e, "OnMouseEnter", function(self) self:SetColor(1, 1, 1, 1) end)
      zui.handler(e, "OnMouseExit",  function(self) self:SetColor(0.85, 0.70, 0.36, 1) end)
    end
  end
  for i = n + 1, #fly_entries do fly_entries[i]:SetHidden(true) end

  fly:SetDimensions(FLYOUT_PAD * 2 + FLYOUT_COLS * FLYOUT_COL_W,
                    FLYOUT_PAD * 2 + rows_per_col * FLYOUT_ENTRY_H)
end

local function build_newcat()
  local panel = controls.newcat
  local pick = CreateControlFromVirtual("VerdantAssignNewCatPick", panel, "ZO_DefaultButton")
  pick:SetDimensions(120, 22)
  pick:SetAnchor(TOPLEFT, panel, TOPLEFT, 10, 38)
  pick:SetFont("ZoFontGameSmall")
  pick:SetText(GetString(VERDANT_ASSIGN_NEW_COLOR))
  Skin.button(pick)
  zui.handler(pick, "OnClicked", function() M.on_newcat_pick() end)
  controls.newcat_pick = pick

  local rim = WINDOW_MANAGER:CreateControl("VerdantAssignNewCatSampleRim", panel, CT_TEXTURE)
  rim:SetTexture(FILL_TEXTURE)
  rim:SetTextureCoords(0, 1, 0, 0.05)
  rim:SetDimensions(22, 22)
  rim:SetAnchor(TOPLEFT, panel, TOPLEFT, 138, 38)
  Skin.label(rim, "metal", 0.6)
  local sample = WINDOW_MANAGER:CreateControl("VerdantAssignNewCatSample", panel, CT_TEXTURE)
  sample:SetTexture(FILL_TEXTURE)
  sample:SetTextureCoords(0, 1, 0, 0.05)
  sample:SetDimensions(18, 18)
  sample:SetAnchor(TOPLEFT, panel, TOPLEFT, 140, 40)
  controls.newcat_sample = sample

  local preview = WINDOW_MANAGER:CreateControl("VerdantAssignNewCatPreview", panel, CT_LABEL)
  preview:SetFont("ZoFontGameBold")
  preview:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  preview:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  preview:SetAnchor(TOPLEFT, panel, TOPLEFT, 168, 38)
  preview:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -10, 38)
  preview:SetHeight(22)
  preview:SetMaxLineCount(1)
  preview:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  controls.newcat_preview = preview

  local note = WINDOW_MANAGER:CreateControl("VerdantAssignNewCatNote", panel, CT_LABEL)
  note:SetFont("ZoFontGameSmall")
  note:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  note:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  note:SetAnchor(TOPLEFT, panel, TOPLEFT, 10, 64)
  note:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -10, 64)
  note:SetHeight(22)
  note:SetMaxLineCount(1)
  note:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  Skin.label(note, "dim")
  controls.newcat_note = note
end

function M.on_newcat_create()
  local name = trimmed_name()
  if name == "" then
    Sound.play("deny")
    controls.newcat_note:SetText(GetString(VERDANT_ASSIGN_NEW_EMPTY))
    return
  end
  local taken = existing(name)
  if taken and not SkillColors.is_custom(taken) then
    Sound.play("deny")
    refresh_newcat()
    return
  end
  local c   = newcat_rgb
  local key = SkillColors.custom_key(name)
  if not SkillColors.add_group(key, name, c.r, c.g, c.b) then
    Sound.play("deny")
    return
  end
  local sv = Verdant.SavedVars
  if sv then
    sv.custom_groups = sv.custom_groups or {}
    sv.custom_groups[key] = { label = name, r = c.r, g = c.g, b = c.b }
  end
  log:info("custom group", key, name)
  Sound.play("confirm")
  controls.newcat:SetHidden(true)
  build_flyout()
  if newcat_for then
    pending[newcat_for] = key
    newcat_for = nil
    M.refresh()
  end
end

function M.on_newcat_cancel()
  newcat_for = nil
  controls.newcat:SetHidden(true)
  Sound.play("discard")
end

function M.open_newcat_for_test(id)
  active_id = id
  open_newcat()
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

local function gather()
  for i = #entries, 1, -1 do entries[i] = nil end
  for k in pairs(aliases) do aliases[k] = nil end
  local skills = SkillColors.get_unknowns()
  local buffs = Verdant.BuffOrigin.unknowns()
  if #buffs > 0 and #skills > 0 then entries[#entries + 1] = { head = GetString(VERDANT_ASSIGN_SEC_SKILLS) } end
  for i = 1, #skills do entries[#entries + 1] = skills[i] end
  if #buffs > 0 then entries[#entries + 1] = { head = GetString(VERDANT_ASSIGN_SEC_BUFFS) } end
  for i = 1, #buffs do
    entries[#entries + 1] = buffs[i]
    aliases[buffs[i].id] = buffs[i].ids
  end
  return entries
end

local function paint_row(row, u)
  if u.head then
    row.vm_id = nil
    row.vm_icon:SetHidden(true)
    row.vm_pick:SetHidden(true)
    row.vm_name:SetText(u.head)
    Skin.label(row.vm_name, "metal")
    return
  end
  row.vm_id = u.id
  row.vm_pick:SetHidden(false)
  if u.icon ~= "" then row.vm_icon:SetTexture(u.icon) end
  row.vm_icon:SetHidden(u.icon == "")
  row.vm_name:SetText(u.name)
  Skin.label(row.vm_name, "text")
  local chosen = pending[u.id]
  if chosen then
    row.vm_pick:SetText(colored_label(chosen))
  else
    row.vm_pick:SetText(GetString(VERDANT_ASSIGN_PICK))
  end
end

function M.refresh()
  row_pool:ReleaseAllObjects()
  controls.flyout:SetHidden(true)

  local unknowns = gather()
  controls.help:SetText("")
  if #unknowns == 0 then
    controls.empty:SetHidden(false)
    return
  end
  controls.empty:SetHidden(true)

  local list   = controls.list
  local lh      = list:GetHeight()
  local max_rows = (lh > 0) and math_floor(lh / ROW_H) or FALLBACK_MAXROWS

  local max_off = (#unknowns > max_rows) and (#unknowns - max_rows) or 0
  if scroll_off > max_off then scroll_off = max_off end
  if scroll_off < 0 then scroll_off = 0 end
  local shown = 0
  for i = 1, #unknowns do
    local slot = i - scroll_off
    if slot > max_rows then break end
    if slot >= 1 then
      local row = row_pool:AcquireObject()
      paint_row(row, unknowns[i])
      row:ClearAnchors()
      row:SetAnchor(TOPLEFT,  list, TOPLEFT,  0, (slot - 1) * ROW_H)
      row:SetAnchor(TOPRIGHT, list, TOPRIGHT, 0, (slot - 1) * ROW_H)
      row:SetHeight(ROW_H - 2)
      row:SetHidden(false)
      shown = shown + 1
    end
  end

  local rest = #unknowns - scroll_off - shown
  if rest > 0 or scroll_off > 0 then
    controls.help:SetText(string_format(GetString(VERDANT_ASSIGN_MORE), rest, scroll_off))
  end
end

function M.on_scroll(delta)
  local dir = (delta and delta < 0) and 1 or -1
  local before = scroll_off
  scroll_off = scroll_off + dir
  M.refresh()
  if scroll_off ~= before then Sound.play("click") end
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
    lines[#lines + 1] = name .. "  \226\134\146  " .. colored_label(key)
  end
  table.sort(lines)

  controls.confirm_msg:SetText(table_concat(lines, "\n") .. "\n\n" .. GetString(VERDANT_ASSIGN_CONFIRM_NOTE))


  local h = CONFIRM_TOP_H + (#lines + CONFIRM_EXTRA) * CONFIRM_LINE_H + CONFIRM_BTM_H
  controls.confirm:SetDimensions(CONFIRM_W, h)

  controls.window:SetHidden(true)
  controls.confirm:SetHidden(false)
end

function M.show_reset_scroll()
  scroll_off = 0
end

function M.show()
  controls.confirm:SetHidden(true)
  clear_pending()
  Scene.show_top_level(controls.window)
  M.refresh()
end

function M.hide()
  controls.flyout:SetHidden(true)
  controls.confirm:SetHidden(true)
  clear_pending()
  Scene.hide_top_level(controls.window)
  row_pool:ReleaseAllObjects()
  Verdant.Settings.refresh_unknown()
end

function M.toggle()
  if controls.window:IsHidden() then M.show() else M.hide() end
end

function M.on_close_click() M.hide() end

function M.on_assign_click()
  if pending_count() == 0 then
    M.hide()
  else
    show_confirm()
  end
end

function M.on_confirm_no()
  controls.confirm:SetHidden(true)
  controls.window:SetHidden(false)
  M.refresh()
end

function M.on_confirm_yes()
  local sv = Verdant.SavedVars
  for first, key in pairs(pending) do
    local ids = aliases[first] or { first }
    for i = 1, #ids do
      local id = ids[i]
      SkillColors.set_override(id, key)
      if sv then
        sv.skill_overrides = sv.skill_overrides or {}
        sv.skill_overrides[id] = key
      end
      log:info("committed", id, "->", key)
    end
  end
  controls.confirm:SetHidden(true)
  M.hide()
  Verdant.Graph.rerender()
end

local function catalog_done()
  if controls.window:IsHidden() or not controls.flyout:IsHidden() or not controls.newcat:IsHidden() then return end
  M.refresh()
end

function M.on_move_stop()
  controls.flyout:SetHidden(true)
  local sv = Verdant.SavedVars
  if not sv or not controls.window then return end
  sv.assign = sv.assign or {}
  sv.assign.x = controls.window:GetLeft()
  sv.assign.y = controls.window:GetTop()
end

-- ── init ────────────────────────────────────────────────────────────────────
function M.init()
  controls.window     = VerdantAssignPanel
  Scene.register_top_level(controls.window)
  controls.title      = VerdantAssignPanelWindowTitle
  controls.help       = VerdantAssignPanelHelpLabel
  controls.list       = VerdantAssignPanelList
  controls.empty      = VerdantAssignPanelListEmpty
  controls.assign_btn = VerdantAssignPanelAssignBtn
  controls.flyout     = VerdantAssignPanelFlyout
  controls.confirm       = VerdantAssignConfirm
  controls.confirm_title = VerdantAssignConfirmTitle
  controls.confirm_msg   = VerdantAssignConfirmMsg
  controls.confirm_yes   = VerdantAssignConfirmYesBtn
  controls.confirm_no    = VerdantAssignConfirmNoBtn
  controls.newcat        = VerdantAssignPanelNewCat
  controls.newcat_edit   = VerdantAssignPanelNewCatNameBoxEdit
  controls.newcat_create = VerdantAssignPanelNewCatCreateBtn
  controls.newcat_cancel = VerdantAssignPanelNewCatCancelBtn


  Skin.panel(VerdantAssignPanelBg)
  Skin.close(VerdantAssignPanelCloseBtn)
  Skin.button(controls.assign_btn, true)
  Skin.button(controls.newcat_create, true)
  Skin.button(controls.newcat_cancel)
  Skin.button(controls.confirm_yes, true)
  Skin.button(controls.confirm_no)

  VerdantAssignPanelFlyoutFill:SetTexture("EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds")
  VerdantAssignPanelFlyoutFill:SetTextureCoords(0, 1, 0, 0.05)
  VerdantAssignPanelFlyoutFill:SetColor(0.062, 0.058, 0.050, 0.985)
  VerdantAssignPanelFlyoutFill:SetDrawLayer(DL_OVERLAY)
  VerdantAssignPanelFlyoutFill:SetDrawLevel(101)
  VerdantAssignPanelFlyoutBg:SetCenterColor(0.075, 0.070, 0.062, 0.98)
  VerdantAssignPanelFlyoutBg:SetEdgeColor(0.42, 1.00, 0.60, 0.85)
  VerdantAssignPanelFlyoutBg:SetDrawLayer(DL_OVERLAY)
  VerdantAssignPanelFlyoutBg:SetDrawLevel(102)
  controls.flyout:SetDrawLevel(100)
  controls.confirm:SetDrawTier(DT_HIGH)
  Skin.panel(VerdantAssignConfirmBg)

  controls.title:SetText(GetString(VERDANT_ASSIGN_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)
  controls.help:SetColor(0.85, 0.70, 0.30, 1)
  controls.empty:SetText(GetString(VERDANT_ASSIGN_EMPTY))
  controls.empty:SetColor(0.45, 0.45, 0.45, 1)
  controls.empty:SetHidden(true)
  controls.assign_btn:SetText(GetString(VERDANT_ASSIGN_DONE))

  controls.confirm_title:SetText(GetString(VERDANT_ASSIGN_CONFIRM_TITLE))
  controls.confirm_title:SetColor(0.55, 0.85, 0.55, 1)
  controls.confirm_msg:SetColor(0.90, 0.90, 0.90, 1)
  controls.confirm_yes:SetText(GetString(VERDANT_ASSIGN_CONFIRM_YES))
  controls.confirm_no:SetText(GetString(VERDANT_ASSIGN_CONFIRM_NO))
  controls.confirm:SetHidden(true)

  row_pool = Verdant.lib.plot.Pool.new("VerdantAssignRowC", controls.list, CT_CONTROL, row_factory, row_reset)
  Skin.section(VerdantAssignPanelNewCatBg)
  VerdantAssignPanelNewCatTitle:SetText(GetString(VERDANT_ASSIGN_NEW_TITLE))
  Skin.label(VerdantAssignPanelNewCatTitle, "metal")
  controls.newcat_edit:SetDefaultText(GetString(VERDANT_ASSIGN_NEW_NAME))
  controls.newcat_create:SetText(GetString(VERDANT_ASSIGN_CREATE))
  controls.newcat_cancel:SetText(GetString(VERDANT_ASSIGN_CANCEL))
  controls.newcat:SetHidden(true)
  build_newcat()
  zui.handler(controls.newcat_edit, "OnTextChanged", function() refresh_newcat() end)
  controls.list:SetMouseEnabled(true)
  zui.handler(controls.list, "OnMouseWheel", function(_, delta) M.on_scroll(delta) end)
  build_flyout()
  Verdant.BuffCatalog.on_done(catalog_done)

  local sv = Verdant.SavedVars
  sv.assign = sv.assign or {}
  controls.window:ClearAnchors()
  if sv.assign.x and sv.assign.y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.assign.x, sv.assign.y)
  else
    controls.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  end

  log:info("init: categories=", #SkillColors.groups_ordered())
end
