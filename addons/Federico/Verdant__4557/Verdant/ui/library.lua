Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Library = {}
local M = Verdant.Library
local Sound = Verdant.Sound
local Skin  = Verdant.Skin

local string_format = string.format
local math_floor    = math.floor
local d             = d
local api = Verdant.zenimax.api
local zui           = Verdant.zenimax.ui
local zc            = Verdant.zenimax.constants
local zev           = Verdant.zenimax.events
local Scene         = Verdant.zenimax.scene

local ROW_H   = 30
local ROW_GAP = 2
local MAX_ROWS = 10

local C_NAME      = { r = 0.86, g = 0.92, b = 0.88 }
local C_DIM       = { r = 0.55, g = 0.58, b = 0.55 }
local C_SEL       = Verdant.lib.themes.tint("select")
local VET_ICON    = "EsoUI/Art/LFG/LFG_veteranDungeon_up.dds"
local TICK_OFF    = "EsoUI/Art/Buttons/checkbox_unchecked.dds"
local TICK_ON     = "EsoUI/Art/Buttons/checkbox_checked.dds"
local TICK_X      = 7
local TICK_W      = 15
local TICK_ROOM   = 20
local TICK_DIM    = 0.55

local controls = {}
local rows = {}
local row_session = {}
local picked = nil
local pending_sess = nil
local delete_armed = false
local asked_pick, asked_n = nil, 0
local marked = setmetatable({}, { __mode = "k" })
local marked_n = 0
local scroll_off = 0
local drag = { on = false, y0 = 0, off0 = 0 }
local log

local function picked_index()
  local SS = Verdant.SessionStore
  for i = 1, SS.count() do
    if SS.get(i) == picked then return i end
  end
  return nil
end

local function fmt_dur(ms)
  local s = math_floor((ms or 0) / 1000)
  return string_format("%d:%02d", math_floor(s / 60), s % 60)
end

local function fmt_ago(ts)
  local now = Verdant.zenimax.api.GetTimeStamp()
  local days = math_floor((now - (ts or now)) / 86400)
  if days <= 0 then return GetString(VERDANT_LIB_TODAY) end
  return days .. "d"
end

local function fmt_date(ts)
  return (api.GetDateStringFromTimestamp and ts and api.GetDateStringFromTimestamp(ts)) or fmt_ago(ts)
end

local function fmt_k(v)
  if v >= 10000 then return string_format("%.0fk", v / 1000) end
  if v >= 1000 then return string_format("%.1fk", v / 1000) end
  return tostring(v)
end

local WM = WINDOW_MANAGER
local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local function solidify(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, 0, 0.05)
  return c
end

local function make_row(i)
  local nm = "VerdantLibraryRow" .. i
  local row = WM:CreateControl(nm, controls.list, CT_CONTROL)
  row:SetAnchor(TOPLEFT,  controls.list, TOPLEFT,  0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetAnchor(TOPRIGHT, controls.list, TOPRIGHT, 0, (i - 1) * (ROW_H + ROW_GAP))
  row:SetHeight(ROW_H)
  row:SetMouseEnabled(true)
  zui.handler(row, "OnMouseUp", function() M.on_row_click(i) end)
  zui.handler(row, "OnMouseDoubleClick", function()
    M.on_row_click(i)
    M.on_open_click()
  end)
  zui.handler(row, "OnMouseEnter", function() M.on_row_enter(i) end)
  zui.handler(row, "OnMouseExit", function() M.on_row_exit(i) end)

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

  local kind = WM:CreateControl(nm .. "Kind", row, CT_TEXTURE)
  kind:SetDimensions(22, 22)
  kind:SetAnchor(LEFT, row, LEFT, 7 + TICK_ROOM, 0)
  kind:SetColor(0.85, 0.90, 0.86, 0.95)
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
  Skin.texture(star, "lock_closed")
  star:SetDimensions(14, 14)
  star:SetAnchor(RIGHT, row, RIGHT, -4, 0)
  star:SetHidden(true)

  local tick = WM:CreateControl(nm .. "Tick", row, CT_TEXTURE)
  tick:SetDimensions(TICK_W, TICK_W)
  tick:SetAnchor(LEFT, row, LEFT, TICK_X, 0)

  local tick_hit = WM:CreateControl(nm .. "TickHit", row, CT_CONTROL)
  tick_hit:SetDimensions(TICK_X + TICK_W + 2, ROW_H)
  tick_hit:SetAnchor(LEFT, row, LEFT, 0, 0)
  tick_hit:SetMouseEnabled(true)
  zui.handler(tick_hit, "OnMouseUp", function(_, _, upInside)
    if upInside ~= false then M.on_tick_click(i) end
  end)
  zui.handler(tick_hit, "OnMouseEnter", function() M.on_row_enter(i) end)
  zui.handler(tick_hit, "OnMouseExit", function() M.on_row_exit(i) end)

  return { root = row, bg = bg, sel = sel, hov = hov, vet = vet, kind = kind,
           name = name, stats = stats, when = when, star = star, tick = tick, tick_hit = tick_hit }
end

local HAND_GLYPH  = "|t12:12:EsoUI/Art/Buttons/edit_save_up.dds|t "
local function tint_icon(icon, on)
  icon:SetColor(1, 1, 1, on and 1 or 0.3)
end

local function set_buttons()
  local has = picked ~= nil
  local locked = has and picked.head.locked
  controls.lock_btn:SetText(GetString(locked and VERDANT_LIB_UNLOCK or VERDANT_LIB_LOCK))
  Skin.texture(controls.lock_icon, locked and "lock_open" or "lock_closed")
  controls.open_btn:SetEnabled(has)
  controls.lock_btn:SetEnabled(has)
  local many = marked_n > 0
  local can_delete = many or (has and not locked)
  controls.delete_btn:SetEnabled(can_delete)
  if many then
    controls.delete_btn:SetText(string_format(
      GetString(delete_armed and VERDANT_LIB_CONFIRM_N or VERDANT_LIB_DELETE_N), marked_n))
  else
    controls.delete_btn:SetText(GetString(delete_armed and VERDANT_LIB_CONFIRM or VERDANT_LIB_DELETE))
  end
  tint_icon(controls.open_icon,   has)
  tint_icon(controls.lock_icon,   has)
  tint_icon(controls.delete_icon, can_delete)
end

local function tidy_marks()
  local SS = Verdant.SessionStore
  local live = 0
  for i = 1, SS.count() do
    local sess = SS.get(i)
    if marked[sess] then
      if sess.head.locked then marked[sess] = nil else live = live + 1 end
    end
  end
  marked_n = live
end

local function clear_marks()
  for sess in pairs(marked) do marked[sess] = nil end
  marked_n = 0
end

function M.refresh()
  for i = 1, #rows do
    rows[i].hov:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.05)
    rows[i].sel:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, 0.10)
  end
  local SS = Verdant.SessionStore
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
  controls.empty:SetText(GetString(VERDANT_LIB_EMPTY))
  controls.empty:SetColor(0.5, 0.5, 0.5, 1)

  local want = picked_index()
  local on_screen = false
  local shown = 0
  for i = n - scroll_off, 1, -1 do
    if shown >= MAX_ROWS then break end
    shown = shown + 1
    local row = rows[shown]
    if not row then row = make_row(shown); rows[shown] = row end
    row_session[shown] = i
    if i == want then on_screen = true end
    local sess = SS.get(i)
    local h = sess.head
    row.root:SetHidden(false)
    row.bg:SetColor(1, 1, 1, (shown % 2 == 0) and 0.04 or 0.02)
    row.sel:SetHidden(i ~= want)
    row.name:SetText(SS.title(h))
    row.name:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, 1)
    local sum = h.sum or {}
    row.stats:SetText(string_format("|c94d9eb%s|r  |cf2a0c0%s|r  |c8c948c%s|r",
      fmt_k(sum.avg or 0), fmt_k(sum.peak or 0), fmt_date(h.ts)))
    row.stats:SetColor(1, 1, 1, 1)
    local kind_icon = Verdant.ContentKind.icon(h.kind)
    if kind_icon then row.kind:SetTexture(kind_icon) end
    row.kind:SetHidden(kind_icon == nil)
    row.vet:SetHidden((h.difficulty or 0) ~= Verdant.zenimax.constants.DUNGEON_DIFFICULTY_VETERAN)
    row.when:SetText((h.manual and HAND_GLYPH or "") .. fmt_dur(h.dur_ms))
    row.when:SetColor(C_DIM.r, C_DIM.g, C_DIM.b, 1)
    row.star:SetHidden(not h.locked)
    local on = marked[sess]
    row.tick:SetTexture(on and TICK_ON or TICK_OFF)
    row.tick:SetColor(C_SEL.r, C_SEL.g, C_SEL.b, on and 1 or TICK_DIM)
    row.tick:SetHidden(h.locked == true)
    row.tick_hit:SetHidden(h.locked == true)
  end
  for i = shown + 1, #rows do
    rows[i].root:SetHidden(true)
    row_session[i] = nil
  end
  if not on_screen then picked = nil end
  if delete_armed and (picked ~= asked_pick or marked_n ~= asked_n) then delete_armed = false end
  set_buttons()
  Verdant.Graph.refresh_loaded_status()
end

function M.on_row_exit(i)
  if rows[i] then rows[i].hov:SetHidden(true) end
end

function M.on_row_enter(i)
  if row_session[i] then rows[i].hov:SetHidden(false) end
end

function M.on_label_focus(on)
  Skin.field(controls.label_box, on)
  if on and controls.label_edit.SelectAll then controls.label_edit:SelectAll() end
end

local function sync_label_box()
  controls.label_edit:SetText((picked and picked.head.label) or "")
  controls.label_btn:SetEnabled(picked ~= nil)
end

local function disarm_delete()
  zev.unregister_update("VerdantLibDisarm")
  asked_pick = nil
  if delete_armed then
    delete_armed = false
    set_buttons()
  end
end

local function arm_delete()
  delete_armed = true
  asked_pick, asked_n = picked, marked_n
  zev.register_update("VerdantLibDisarm", 3000, disarm_delete)
end

function M.on_row_click(i)
  if not row_session[i] then return end
  picked = Verdant.SessionStore.get(row_session[i])
  disarm_delete()
  for k = 1, #rows do
    rows[k].sel:SetHidden(k ~= i)
  end
  set_buttons()
  sync_label_box()
end

function M.on_tick_click(i)
  local idx = row_session[i]
  local sess = idx and Verdant.SessionStore.get(idx)
  if not sess or sess.head.locked then return end
  local on = not marked[sess]
  marked[sess] = on or nil
  Sound.play(on and "on" or "off")
  M.refresh()
end

function M.marked_count() return marked_n end

function M.on_label_save()
  local idx = picked_index()
  if not idx then
    Sound.play("deny")
    return
  end
  local text = controls.label_edit:GetText() or ""
  if Verdant.SessionStore.set_label(idx, text) then
    Sound.play("confirm")
    M.refresh()
    sync_label_box()
  end
end

function M.on_open_click()
  if not picked_index() then return end
  if Verdant.Graph.load_session(picked) then
    Sound.play("page")
    M.hide()
  end
end

function M.on_lock_click()
  local idx = picked_index()
  if not idx then return end
  Verdant.SessionStore.set_locked(idx, not picked.head.locked)
  disarm_delete()
  Sound.play("confirm")
  M.refresh()
end

local function max_offset()
  local n = Verdant.SessionStore.count()
  return (n > MAX_ROWS) and (n - MAX_ROWS) or 0
end

local function set_scroll(off)
  local max_off = max_offset()
  if off < 0 then off = 0 end
  if off > max_off then off = max_off end
  if off ~= scroll_off then
    scroll_off = off
    picked = nil
    disarm_delete()
    M.refresh()
    sync_label_box()
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
  zui.handler(controls.window, "OnUpdate", drag_update)
end

function M.on_thumb_up()
  if not drag.on then return end
  drag.on = false
  zui.handler(controls.window, "OnUpdate", nil)
end

local function asks_first()
  if delete_armed then return false end
  arm_delete()
  Sound.play("deny")
  set_buttons()
  return true
end

function M.on_delete_click()
  local SS = Verdant.SessionStore
  if marked_n > 0 then
    if asks_first() then return end
    disarm_delete()
    Sound.play("discard")
    for i = SS.count(), 1, -1 do
      local sess = SS.get(i)
      if marked[sess] and not sess.head.locked then SS.delete(i) end
    end
    M.refresh()
    sync_label_box()
    return
  end
  local idx = picked_index()
  if not idx or picked.head.locked then return end
  if asks_first() then return end
  disarm_delete()
  Sound.play("discard")
  SS.delete(idx)
  M.refresh()
  sync_label_box()
end

local DOCK_SIDES = { "bottom", "top" }

local function dock_of()
  return Verdant.Dock.new(controls.window, VerdantGraphWindow, Verdant.Settings.library_place(), DOCK_SIDES)
end

function M.on_move_stop() Verdant.Dock.released(dock_of()) end
function M.is_detached() return Verdant.Dock.is_detached(dock_of()) end
function M.forget_dock() Verdant.Dock.forget(dock_of()) end

local function select_pending()
  for k = 1, #rows do
    if row_session[k] and Verdant.SessionStore.get(row_session[k]) == pending_sess then M.on_row_click(k) end
  end
  pending_sess = nil
end

Verdant.lib.themes.on_change(function()
  if controls.window and not controls.window:IsHidden() then M.refresh() end
end)

function M.show()
  picked = nil
  clear_marks()
  disarm_delete()
  scroll_off = 0
  Verdant.Dock.open(dock_of())
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

function M.on_session_saved(manual)
  if manual then pending_sess = Verdant.SessionStore.get(Verdant.SessionStore.count()) end
  if not controls.window or controls.window:IsHidden() then return end
  scroll_off = 0
  M.refresh()
  select_pending()
  sync_label_box()
end

function M.init()
  log = Verdant.Log.for_module("library")
  controls.window     = VerdantLibrary
  Scene.register_top_level(controls.window)
  controls.title      = VerdantLibraryWindowTitle
  controls.scroll_up  = VerdantLibraryScrollUp
  controls.scroll_down = VerdantLibraryScrollDown
  controls.label_box  = VerdantLibraryLabelBox
  controls.scroll_track = VerdantLibraryScrollTrack
  controls.scroll_thumb = VerdantLibraryScrollTrackThumb
  controls.list       = VerdantLibraryList
  controls.empty      = VerdantLibraryListEmpty
  controls.open_btn   = VerdantLibraryOpenBtn
  controls.lock_btn   = VerdantLibraryLockBtn
  controls.delete_btn = VerdantLibraryDeleteBtn
  controls.open_icon  = VerdantLibraryOpenBtnIcon
  controls.lock_icon  = VerdantLibraryLockBtnIcon
  controls.delete_icon = VerdantLibraryDeleteBtnIcon
  controls.label_edit = VerdantLibraryLabelBoxEdit
  controls.label_btn  = VerdantLibraryLabelBtn
  controls.label_edit:SetDefaultText(GetString(VERDANT_LIB_LABEL_HINT))
  controls.label_btn:SetText(GetString(VERDANT_LIB_LABEL_SAVE))
  controls.label_btn:SetEnabled(false)

  controls.title:SetText(GetString(VERDANT_LIB_TITLE))
  controls.open_btn:SetText(GetString(VERDANT_LIB_OPEN))
  controls.lock_btn:SetText(GetString(VERDANT_LIB_LOCK))
  controls.delete_btn:SetText(GetString(VERDANT_LIB_DELETE))
  Skin.panel(VerdantLibraryBg)
  Skin.close(VerdantLibraryCloseBtn)
  Skin.buttons({ controls.open_btn, controls.lock_btn, controls.delete_btn, controls.label_btn })
  Skin.icon(controls.scroll_up, "arrow_up")
  Skin.icon(controls.scroll_down, "arrow_down")
  Skin.texture(controls.open_icon, "arrow_right_up")
  Skin.texture(controls.delete_icon, "delete")
  Skin.texture(VerdantLibraryScrollTrackBg, "scroll_track")
  Skin.texture(VerdantLibraryScrollTrackThumbTex, "scroll_thumb")
  VerdantLibraryListBg:SetEdgeColor(0.42, 1.00, 0.60, 0.55)
  VerdantLibraryListBg:SetCenterColor(0, 0, 0, 0)
  VerdantLibraryListFill:SetTextureCoords(0, 1, 0, 0.05)
  VerdantLibraryListFill:SetColor(0.055, 0.052, 0.046, 0.92)
  controls.label_box:SetCenterColor(0, 0, 0, 0)
  controls.label_edit:SetDefaultTextColor(0.62, 0.70, 0.64, 0.45)
  M.on_label_focus(false)
  set_buttons()
end
