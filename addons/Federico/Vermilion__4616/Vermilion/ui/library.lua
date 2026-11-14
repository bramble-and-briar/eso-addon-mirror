Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Library = {}
local M = Vermilion.Library

local string_format = string.format
local math_floor    = math.floor
local d             = d
local api           = Vermilion.zenimax.api
local zc            = Vermilion.zenimax.constants
local zev           = Vermilion.zenimax.events
local Scene         = Vermilion.zenimax.scene
local Sound         = Vermilion.Sound

local ROW_H   = 30
local ROW_GAP = 2
local MAX_ROWS = 10

local C_PIP_HOT   = { r = 0.95, g = 0.78, b = 0.30 }
local C_PIP_NONE  = { r = 0.48, g = 0.45, b = 0.45 }
local C_NAME      = { r = 0.94, g = 0.88, b = 0.86 }
local C_DIM       = { r = 0.60, g = 0.55, b = 0.55 }
local C_SEL       = { r = 1.00, g = 0.62, b = 0.58 }
local VET_ICON    = "EsoUI/Art/LFG/LFG_veteranDungeon_up.dds"
local TICK_OFF    = "EsoUI/Art/Buttons/checkbox_unchecked.dds"
local TICK_ON     = "EsoUI/Art/Buttons/checkbox_checked.dds"
local TICK_X      = 10
local TICK_ROOM   = 20

local controls = {}
local rows = {}
local row_session = {}
local selected = nil
local picked = nil
local pending_sess = nil
local delete_armed = false
local marked = {}
local marked_n = 0
local scroll_off = 0
local drag = { on = false, y0 = 0, off0 = 0 }
local log

local function picked_index()
  if not picked then return nil end
  local SS = Vermilion.SessionStore
  for i = 1, SS.count() do
    if SS.get(i) == picked then return i end
  end
  return nil
end

local function pip_color(sum)
  if (sum.total_damage or 0) <= 0 then return C_PIP_NONE end
  return C_PIP_HOT
end

local function fmt_dur(ms)
  local s = math_floor((ms or 0) / 1000)
  return string_format("%d:%02d", math_floor(s / 60), s % 60)
end

local function fmt_ago(ts)
  local now = api.GetTimeStamp()
  local days = math_floor((now - (ts or now)) / 86400)
  if days <= 0 then return GetString(VERMILION_LIB_TODAY) end
  return days .. "d"
end

local function fmt_date(ts)
  return (api.GetDateStringFromTimestamp and ts and api.GetDateStringFromTimestamp(ts)) or fmt_ago(ts)
end

local function fmt_k(v)
  if v >= 10000 then return string_format("%.0fk", v / 1000) end
  if v >= 1000 then return string_format("%.1fk", v / 1000) end
  return tostring(math_floor(v))
end

local WM = WINDOW_MANAGER
local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local function solidify(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, 0, 0.05)
  return c
end

local function make_row(i)
  local nm = "VermilionLibraryRow" .. i
  local row = WM:CreateControl(nm, controls.list, CT_CONTROL)
  row:SetAnchor(TOPLEFT,  controls.list, TOPLEFT,  0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetAnchor(TOPRIGHT, controls.list, TOPRIGHT, 0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetHeight(ROW_H)
  row:SetMouseEnabled(true)
  row:SetHandler("OnMouseUp", function() M.on_row_click(i) end)
  row:SetHandler("OnMouseDoubleClick", function()
    M.on_row_click(i)
    M.on_open_click()
  end)
  row:SetHandler("OnMouseEnter", function() M.on_row_enter(i) end)
  row:SetHandler("OnMouseExit", function() M.on_row_exit(i) end)

  local bg = WM:CreateControl(nm .. "Bg", row, CT_TEXTURE)
  solidify(bg)
  bg:SetAnchorFill(row)
  bg:SetColor(1, 1, 1, 0.02)

  local hl = WM:CreateControl(nm .. "Hl", row, CT_TEXTURE)
  solidify(hl)
  hl:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
  hl:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
  hl:SetHeight(1)
  hl:SetColor(1, 1, 1, 0.05)

  local sh = WM:CreateControl(nm .. "Sh", row, CT_TEXTURE)
  solidify(sh)
  sh:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
  sh:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
  sh:SetHeight(1)
  sh:SetColor(0, 0, 0, 0.40)

  local hov = WM:CreateControl(nm .. "Hov", row, CT_TEXTURE)
  solidify(hov)
  hov:SetAnchorFill(row)
  hov:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.05)
  hov:SetHidden(true)

  local sel = WM:CreateControl(nm .. "Sel", row, CT_TEXTURE)
  solidify(sel)
  sel:SetAnchorFill(row)
  sel:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.10)
  sel:SetHidden(true)

  local pip = WM:CreateControl(nm .. "Pip", row, CT_TEXTURE)
  solidify(pip)
  pip:SetDimensions(3, ROW_H - 12)
  pip:SetAnchor(LEFT, row, LEFT, 4, 0)

  local kind = WM:CreateControl(nm .. "Kind", row, CT_TEXTURE)
  kind:SetDimensions(22, 22)
  kind:SetAnchor(LEFT, row, LEFT, 7 + TICK_ROOM, 0)
  kind:SetColor(0.92, 0.86, 0.85, 0.95)
  kind:SetHidden(true)

  local vet = WM:CreateControl(nm .. "Vet", row, CT_TEXTURE)
  vet:SetTexture(VET_ICON)
  vet:SetDimensions(13, 13)
  vet:SetAnchor(LEFT, row, LEFT, 31 + TICK_ROOM, 0)
  vet:SetColor(0.95, 0.80, 0.35, 1)
  vet:SetHidden(true)

  local name = WM:CreateControl(nm .. "Name", row, CT_LABEL)
  name:SetFont("ZoFontGameSmall")
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  name:SetDimensions(86, ROW_H)
  name:SetAnchor(LEFT, row, LEFT, 46 + TICK_ROOM, 0)
  name:SetMaxLineCount(1)
  name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

  local stats = WM:CreateControl(nm .. "Stats", row, CT_LABEL)
  stats:SetFont("ZoFontGameSmall")
  stats:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  stats:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  stats:SetDimensions(176, ROW_H)
  stats:SetAnchor(LEFT, row, LEFT, 154, 0)

  local when = WM:CreateControl(nm .. "When", row, CT_LABEL)
  when:SetFont("ZoFontGameSmall")
  when:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  when:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  when:SetDimensions(78, ROW_H)
  when:SetAnchor(RIGHT, row, RIGHT, -20, 0)

  local star = WM:CreateControl(nm .. "Star", row, CT_TEXTURE)
  star:SetTexture("Vermilion/assets/skin/lock_closed.dds")
  star:SetDimensions(15, 15)
  star:SetAnchor(RIGHT, row, RIGHT, -4, 0)
  star:SetHidden(true)

  local tick = WM:CreateControl(nm .. "Tick", row, CT_TEXTURE)
  tick:SetTexture(TICK_OFF)
  tick:SetDimensions(15, 15)
  tick:SetAnchor(LEFT, row, LEFT, TICK_X, 0)
  tick:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.55)
  tick:SetHidden(true)

  local tick_hit = WM:CreateControl(nm .. "TickHit", row, CT_CONTROL)
  tick_hit:SetDimensions(TICK_X + 17, ROW_H)
  tick_hit:SetAnchor(LEFT, row, LEFT, 0, 0)
  tick_hit:SetMouseEnabled(true)
  tick_hit:SetHidden(true)
  tick_hit:SetHandler("OnMouseUp", function(_, _, upInside)
    if upInside ~= false then M.on_tick_click(i) end
  end)
  tick_hit:SetHandler("OnMouseEnter", function() M.on_row_enter(i) end)
  tick_hit:SetHandler("OnMouseExit", function() M.on_row_exit(i) end)

  return { root = row, bg = bg, sel = sel, hov = hov, pip = pip, vet = vet, kind = kind,
           name = name, stats = stats, when = when, star = star, tick = tick, tick_hit = tick_hit }
end

local HAND_GLYPH  = "|t14:14:Vermilion/assets/skin/save_up.dds|t "
local ICON_LOCK   = "Vermilion/assets/skin/lock_closed.dds"
local ICON_UNLOCK = "Vermilion/assets/skin/lock_open.dds"

local function tint_icon(icon, on, r, g, b)
  icon:SetColor(r, g, b, on and 0.9 or 0.25)
end

local function set_buttons()
  local has = selected ~= nil
  local locked = false
  if has then
    locked = (picked and picked.head.locked) or false
    controls.lock_btn:SetText(locked
      and GetString(VERMILION_LIB_UNLOCK) or GetString(VERMILION_LIB_LOCK))
  else
    controls.lock_btn:SetText(GetString(VERMILION_LIB_LOCK))
  end
  controls.lock_icon:SetTexture(locked and ICON_UNLOCK or ICON_LOCK)
  controls.open_btn:SetEnabled(has)
  controls.lock_btn:SetEnabled(has)
  local many = marked_n > 0
  local can_delete = many or (has and not locked)
  controls.delete_btn:SetEnabled(can_delete)
  if many then
    controls.delete_btn:SetText(string_format(
      GetString(delete_armed and VERMILION_LIB_CONFIRM_N or VERMILION_LIB_DELETE_N), marked_n))
  else
    controls.delete_btn:SetText(delete_armed and GetString(VERMILION_LIB_CONFIRM)
                                              or GetString(VERMILION_LIB_DELETE))
  end
  tint_icon(controls.open_icon,   has, 1.00, 0.62, 0.58)
  tint_icon(controls.lock_icon,   has, 1.00, 0.62, 0.58)
  tint_icon(controls.delete_icon, can_delete, 1.00, 0.45, 0.40)
end

local function tidy_marks()
  local SS = Vermilion.SessionStore
  for sess in pairs(marked) do marked[sess] = false end
  local live = 0
  for i = 1, SS.count() do
    local sess = SS.get(i)
    if marked[sess] == false and not sess.head.locked then
      marked[sess] = true
      live = live + 1
    end
  end
  for sess, on in pairs(marked) do
    if not on then marked[sess] = nil end
  end
  marked_n = live
end

local function clear_marks()
  for sess in pairs(marked) do marked[sess] = nil end
  marked_n = 0
end

function M.refresh()
  local SS = Vermilion.SessionStore
  local n = SS.count()
  tidy_marks()
  local max_off = (n > MAX_ROWS) and (n - MAX_ROWS) or 0
  if scroll_off > max_off then scroll_off = max_off end
  if scroll_off < 0 then scroll_off = 0 end

  local below = max_off - scroll_off
  controls.scroll_up:SetHidden(scroll_off <= 0)
  controls.scroll_down:SetHidden(below <= 0)
  local track = controls.scroll_track
  if max_off > 0 then
    local th = track:GetHeight()
    local thumb_h = math.floor(th * MAX_ROWS / n + 0.5)
    if thumb_h < 16 then thumb_h = 16 end
    if thumb_h > th then thumb_h = th end
    local thumb_y = math.floor((th - thumb_h) * scroll_off / max_off + 0.5)
    controls.scroll_thumb:SetHeight(thumb_h)
    controls.scroll_thumb:ClearAnchors()
    controls.scroll_thumb:SetAnchor(TOPLEFT, track, TOPLEFT, 0, thumb_y)
    track:SetHidden(false)
  else
    track:SetHidden(true)
  end
  controls.empty:SetHidden(n > 0)
  controls.empty:SetText(GetString(VERMILION_LIB_EMPTY))
  controls.empty:SetColor(0.5, 0.5, 0.5, 1)

  local want = picked_index()
  selected = nil
  local shown = 0
  for i = n - scroll_off, 1, -1 do
    if shown >= MAX_ROWS then break end
    shown = shown + 1
    local row = rows[shown]
    if not row then row = make_row(shown); rows[shown] = row end
    row_session[shown] = i
    if i == want then selected = shown end
    local sess = SS.get(i)
    local h = sess.head
    local sum = h.sum or {}
    local pc = pip_color(sum)
    row.root:SetHidden(false)
    row.bg:SetColor(1, 1, 1, (shown % 2 == 0) and 0.04 or 0.02)
    row.sel:SetHidden(i ~= want)
    row.pip:SetColor(pc.r, pc.g, pc.b, 1)
    row.name:SetText(SS.title(h))
    row.name:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, 1)
    row.stats:SetText(string_format(
      "|cf28c7a%s|r  |cffe0b0%s|r  |c%s%d%%|r  |c9e9490%s|r",
      fmt_k(Vermilion.Metrics.session_avg(sum)), fmt_k(sum.peak or 0),
      "f2c74c",
      math_floor(Vermilion.Metrics.session_crit_rate(sum) * 100 + 0.5),
      fmt_date(h.ts)))
    row.stats:SetColor(1, 1, 1, 1)
    local kind_icon = Vermilion.ContentKind.icon(h.kind)
    if kind_icon then row.kind:SetTexture(kind_icon) end
    row.kind:SetHidden(kind_icon == nil)
    row.vet:SetHidden((h.difficulty or 0) ~= zc.DUNGEON_DIFFICULTY_VETERAN)
    row.when:SetText((h.manual and HAND_GLYPH or "") .. fmt_dur(h.dur_ms))
    row.when:SetColor(C_DIM.r, C_DIM.g, C_DIM.b, 1)
    row.star:SetHidden(not h.locked)
    local on = marked[sess] == true
    row.tick:SetTexture(on and TICK_ON or TICK_OFF)
    row.tick:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, on and 1 or 0.55)
    row.tick:SetHidden(h.locked == true)
    row.tick_hit:SetHidden(h.locked == true)
  end
  for i = shown + 1, #rows do
    rows[i].root:SetHidden(true)
    row_session[i] = nil
  end
  if not selected then
    picked = nil
    delete_armed = false
  end
  set_buttons()
end

function M.on_row_exit(i)
  if rows[i] then rows[i].hov:SetHidden(true) end
end

function M.on_row_enter(i)
  if row_session[i] then rows[i].hov:SetHidden(false) end
end

function M.on_label_focus(on)
  local box = controls.label_box
  if not box then return end
  if on then
    box:SetEdgeColor(1, 1, 1, 1)
    if controls.label_edit.SelectAll then controls.label_edit:SelectAll() end
  else
    box:SetEdgeColor(1, 1, 1, 0.75)
  end
end

local function sync_label_box()
  local edit = controls.label_edit
  if not edit then return end
  local s = selected and picked
  edit:SetText((s and s.head and s.head.label) or "")
  controls.label_btn:SetEnabled(selected ~= nil)
end

local function disarm_delete()
  zev.unregister_update("VermilionLibDisarm")
  if delete_armed then
    delete_armed = false
    set_buttons()
  end
end

local function arm_delete()
  delete_armed = true
  zev.register_update("VermilionLibDisarm", 3000, disarm_delete)
end

function M.on_row_click(i)
  if not row_session[i] then return end
  selected = i
  picked = Vermilion.SessionStore.get(row_session[i])
  disarm_delete()
  for k = 1, #rows do
    rows[k].sel:SetHidden(k ~= i)
  end
  set_buttons()
  sync_label_box()
end

function M.on_tick_click(i)
  local idx = row_session[i]
  local sess = idx and Vermilion.SessionStore.get(idx)
  if not sess or sess.head.locked then return end
  local on = not marked[sess]
  marked[sess] = on or nil
  disarm_delete()
  Sound.play(on and "on" or "off")
  M.refresh()
end

function M.marked_count() return marked_n end

function M.on_label_save()
  local idx = selected and picked_index()
  if not idx then
    Sound.play("deny")
    return
  end
  local text = controls.label_edit:GetText() or ""
  if Vermilion.SessionStore.set_label(idx, text) then
    Sound.play("confirm")
    M.refresh()
    sync_label_box()
    Vermilion.Graph.refresh_loaded_status()
  end
end

function M.on_open_click()
  local idx = selected and picked_index()
  if not idx then return end
  local sess = Vermilion.SessionStore.get(idx)
  if sess and Vermilion.Graph.load_session(sess) then
    Sound.play("page")
    M.hide()
  end
end

function M.on_lock_click()
  local idx = selected and picked_index()
  if not idx then return end
  local s = Vermilion.SessionStore.get(idx)
  if s then
    Vermilion.SessionStore.set_locked(idx, not s.head.locked)
    Sound.play("confirm")
    M.refresh()
  end
end

local function max_offset()
  local n = Vermilion.SessionStore.count()
  return (n > MAX_ROWS) and (n - MAX_ROWS) or 0
end

local function set_scroll(off)
  local max_off = max_offset()
  if off < 0 then off = 0 end
  if off > max_off then off = max_off end
  if off ~= scroll_off then
    scroll_off = off
    selected = nil
    picked = nil
    delete_armed = false
    M.refresh()
  end
end

function M.on_scroll(delta)
  local dir = (delta and delta < 0) and 1 or -1
  set_scroll(scroll_off + dir)
end

function M.on_track_click()
  if drag.on then return end
  local track = controls.scroll_track
  local _, my = api.GetUIMousePosition()
  local th = track:GetHeight()
  if th <= 0 then return end
  local rel = (my - track:GetTop()) / th
  set_scroll(math.floor(rel * (max_offset() + 1)))
end

local function drag_update()
  if not drag.on then return end
  local track = controls.scroll_track
  local free = track:GetHeight() - controls.scroll_thumb:GetHeight()
  local max_off = max_offset()
  if free <= 0 or max_off <= 0 then return end
  local _, my = api.GetUIMousePosition()
  set_scroll(drag.off0 + math.floor((my - drag.y0) * max_off / free + 0.5))
end

function M.on_thumb_down()
  local _, my = api.GetUIMousePosition()
  drag.on, drag.y0, drag.off0 = true, my, scroll_off
  controls.window:SetHandler("OnUpdate", drag_update)
end

function M.on_thumb_up()
  if not drag.on then return end
  drag.on = false
  controls.window:SetHandler("OnUpdate", nil)
end

local function delete_marked()
  if not delete_armed then
    arm_delete()
    Sound.play("deny")
    set_buttons()
    return
  end
  disarm_delete()
  Sound.play("discard")
  local SS = Vermilion.SessionStore
  for i = SS.count(), 1, -1 do
    local sess = SS.get(i)
    if marked[sess] and not sess.head.locked then SS.delete(i) end
  end
  M.refresh()
  sync_label_box()
  Vermilion.Graph.refresh_loaded_status()
end

function M.on_delete_click()
  if marked_n > 0 then
    delete_marked()
    return
  end
  local idx = selected and picked_index()
  if not idx then return end
  local s = Vermilion.SessionStore.get(idx)
  if s and s.head.locked then return end
  if not delete_armed then
    arm_delete()
    Sound.play("deny")
    set_buttons()
    return
  end
  disarm_delete()
  Sound.play("discard")
  Vermilion.SessionStore.delete(idx)
  selected = nil
  picked = nil
  M.refresh()
  Vermilion.Graph.refresh_loaded_status()
end

local dock

local function dock_of()
  if not dock then
    local sv = Vermilion.SavedVars
    sv.settings = sv.settings or {}
    sv.settings.library_dock = sv.settings.library_dock or {}
    dock = Vermilion.Dock.new(controls.window, VermilionGraphWindow, sv.settings.library_dock, { "bottom", "top" })
  end
  return dock
end

function M.on_move_stop() Vermilion.Dock.released(dock_of()) end
function M.is_detached() return Vermilion.Dock.is_detached(dock_of()) end
function M.forget_dock() Vermilion.Dock.forget(dock_of()) end

local function select_pending()
  if not pending_sess then return end
  for k = 1, #rows do
    if row_session[k] and Vermilion.SessionStore.get(row_session[k]) == pending_sess then
      M.on_row_click(k)
      break
    end
  end
  pending_sess = nil
end

function M.show()
  selected = nil
  picked = nil
  clear_marks()
  disarm_delete()
  scroll_off = 0
  Vermilion.Dock.open(dock_of())
  M.refresh()
  select_pending()
  sync_label_box()
  Scene.show_top_level(controls.window)
  controls.window:BringWindowToTop()
  Sound.play("open")
end

function M.hide()
  M.on_thumb_up()
  if controls.window:IsHidden() then return end
  clear_marks()
  disarm_delete()
  Sound.play("close")
  Scene.hide_top_level(controls.window)
end

function M.toggle()
  if controls.window:IsHidden() then M.show() else M.hide() end
end

function M.row_index(i) return row_session[i] end

function M.on_session_saved(manual)
  if manual then pending_sess = Vermilion.SessionStore.get(Vermilion.SessionStore.count()) end
  if not controls.window or controls.window:IsHidden() then return end
  scroll_off = 0
  M.refresh()
  select_pending()
  sync_label_box()
end

function M.init()
  log = Vermilion.Log.for_module("library")
  controls.window     = VermilionLibrary
  Scene.register_top_level(controls.window)
  controls.window:SetHidden(true)
  controls.title      = VermilionLibraryWindowTitle
  controls.scroll_up  = VermilionLibraryScrollUp
  controls.scroll_down = VermilionLibraryScrollDown
  controls.label_box  = VermilionLibraryLabelBox
  controls.scroll_track = VermilionLibraryScrollTrack
  controls.scroll_thumb = VermilionLibraryScrollTrackThumb
  controls.list       = VermilionLibraryList
  controls.empty      = VermilionLibraryListEmpty
  controls.open_btn   = VermilionLibraryOpenBtn
  controls.lock_btn   = VermilionLibraryLockBtn
  controls.delete_btn = VermilionLibraryDeleteBtn
  controls.open_icon  = VermilionLibraryOpenBtnIcon
  controls.lock_icon  = VermilionLibraryLockBtnIcon
  controls.delete_icon = VermilionLibraryDeleteBtnIcon
  controls.label_edit = VermilionLibraryLabelBoxEdit
  controls.label_btn  = VermilionLibraryLabelBtn
  controls.label_edit:SetDefaultText(GetString(VERMILION_LIB_LABEL_HINT))
  controls.label_btn:SetText(GetString(VERMILION_LIB_LABEL_SAVE))
  controls.label_btn:SetEnabled(false)

  controls.title:SetText(GetString(VERMILION_LIB_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)
  controls.open_btn:SetText(GetString(VERMILION_LIB_OPEN))
  controls.lock_btn:SetText(GetString(VERMILION_LIB_LOCK))
  controls.delete_btn:SetText(GetString(VERMILION_LIB_DELETE))
  set_buttons()
  Vermilion.Skin.panel(VermilionLibraryBg)
  Vermilion.Skin.close(VermilionLibraryCloseBtn)
  Vermilion.Skin.buttons({ VermilionLibraryOpenBtn, VermilionLibraryLockBtn, VermilionLibraryDeleteBtn, VermilionLibraryLabelBtn })
  VermilionLibraryListBg:SetEdgeColor(1.00, 0.45, 0.40, 0.55)
  VermilionLibraryListBg:SetCenterColor(0, 0, 0, 0)
  VermilionLibraryListFill:SetTextureCoords(0, 1, 0, 0.05)
  VermilionLibraryListFill:SetColor(0.055, 0.046, 0.046, 0.92)
  Vermilion.Skin.frame(controls.label_box)
  controls.label_box:SetCenterColor(0, 0, 0, 0)
  controls.label_edit:SetDefaultTextColor(0.70, 0.62, 0.62, 0.45)
  Vermilion.Skin.icons({ VermilionLibraryScrollUp, VermilionLibraryScrollDown })
  M.on_label_focus(false)
  set_buttons()
end
