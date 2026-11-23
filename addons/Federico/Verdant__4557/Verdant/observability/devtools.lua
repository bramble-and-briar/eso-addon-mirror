Verdant = Verdant or {}
local Verdant = Verdant

Verdant.DevTools = {}
local M = Verdant.DevTools

local NOOP = function() end
M.init    = NOOP
M.toggle  = NOOP
M.refresh = NOOP
M.is_open = function() return false end
M.actions = {}

if not Verdant.Constants.DEBUG then return end

local zui   = Verdant.zenimax.ui
local zc    = Verdant.zenimax.constants
local Scene = Verdant.zenimax.scene
local Sound = Verdant.Sound
local WINDOW_MANAGER = zui.WINDOW_MANAGER
local CreateControlFromVirtual = zui.CreateControlFromVirtual
local TOPLEFT, TOPRIGHT, LEFT, RIGHT = zc.TOPLEFT, zc.TOPRIGHT, zc.LEFT, zc.RIGHT
local BOTTOMLEFT, BOTTOMRIGHT, BOTTOM = zc.BOTTOMLEFT, zc.BOTTOMRIGHT, zc.BOTTOM
local CT_CONTROL, CT_LABEL, CT_BACKDROP = zc.CT_CONTROL, zc.CT_LABEL, zc.CT_BACKDROP
local TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT = zc.TEXT_ALIGN_LEFT, zc.TEXT_ALIGN_RIGHT
local GuiRoot = zc.GuiRoot

local ACTIONS = {
  { section = "Encounter log (engine file)" },
  { label = "Encounter log on/off", cmd = "elog", status = "elog",
    tip = "Toggles the game's own combat log. While ON the client appends every event around you to\n" .. Verdant.EncounterLog.FILE_HINT .. "\nIt switches itself off at logout." },
  { label = "Mark this moment", cmd = "mark",
    tip = "Writes an MK line with the wall-clock epoch and the game clock into the running trace and echoes it to chat, so the trace and Encounter.log can be aligned." },

  { section = "Trace" },
  { label = "Trace status",      cmd = "trace" },
  { label = "Trace start",       cmd = "trace start" },
  { label = "Trace stop",        cmd = "trace stop" },
  { label = "Trace save",        cmd = "trace save",  tip = "Stages the capture in SavedVars; flush writes it to disk." },
  { label = "Trace auto on/off", cmd = "trace auto",  tip = "Capture a trace with every recording." },
  { label = "Trace clear",       cmd = "trace clear" },
  { label = "Flush to disk (reloadui)", cmd = "flush" },

  { section = "Reports" },
  { label = "Probe dump (chat)",       cmd = "dump" },
  { label = "Probe save to SavedVars", cmd = "save" },
  { label = "Hitch log (copybox)",     cmd = "hitch" },
  { label = "Buff probe (SavedVars)",  cmd = "buffprobe",
    tip = "Asks the game where every buff in the library comes from (buff type, champion star, mundus, set, skill) and times a pass over every set.\nThe answer goes to SavedVars: reload the UI to write it." },
  { label = "Skill probe (SavedVars)", cmd = "skillprobe",
    tip = "For every healing and shield ability in the library, says which layer gives its category (your choice, the add-on's table, the icon, the skill tree, a champion star) and what each table entry would become without it.\nThe answer goes to SavedVars: reload the UI to write it." },
  { label = "Film cost (copybox)",     cmd = "filmtest",
    tip = "Fills the film to 5, 16 and 30 minutes and measures memory, drawing and a saved session, on the view that is open.\nIt clears the chart: stop the recording and open the window first." },
  { label = "Open copybox",            cmd = "copy" },

  { section = "Diagnostics (chat)" },
  { label = "Diag summary",           cmd = "diag" },
  { label = "Diagnostic report",      cmd = "report" },
  { label = "Diagnostic report + GC", cmd = "report gc" },
  { label = "GC probe 1000 frames",   cmd = "gcprobe 1000", tip = "Allocation per frame on the hot path; the zero-alloc tripwire." },
  { label = "Profiler dump",          cmd = "prof" },
  { label = "Profiler reset",         cmd = "prof reset" },
  { label = "Probe stats",            cmd = "stats" },
  { label = "Probe context",          cmd = "context" },
  { label = "Ping",                   cmd = "ping" },
  { label = "Readout",                cmd = "readout" },
  { label = "Validation",             cmd = "validate" },
  { label = "Unknown skills",         cmd = "skills" },

  { section = "Interface" },
  { label = "Theme gallery", cmd = "themes", tip = "Opens a sample window with every piece of each theme. Nothing in it is wired." },

  { section = "Toggles" },
  { label = "Probe chat echo on",   cmd = "on" },
  { label = "Probe chat echo off",  cmd = "off" },
  { label = "Pixel grid",           cmd = "grid" },
  { label = "Donut probe",          cmd = "donut" },
  { label = "Tide probe",           cmd = "tideprobe", tip = "Draws the tides of the buffs in the window with polygons or rectangles; click the mode to change it." },
  { label = "Log: show recent",     cmd = "log show" },
  { label = "Log: flush to SavedVars", cmd = "log flush" },
  { label = "Clear buffers",        cmd = "clear" },
}
M.actions = ACTIONS

local ROW_H, HEAD_H  = 20, 24
local COL_W, COLS    = 300, 2
local PAD_X, TOP_Y   = 14, 44
local FOOT_H         = 28
local ROWS_PER_COL   = 18

local controls
local rows = {}

local function status_text(kind)
  if kind == "elog" then
    return Verdant.EncounterLog.is_enabled() and "ON" or "OFF"
  end
  return ""
end

local function run(cmd)
  if Verdant.slash then Verdant.slash(cmd) end
  Sound.play("click")
  M.refresh()
end

local function describe(e)
  local s = e.tip and (e.tip .. "\n") or ""
  return s .. "runs  " .. Verdant.Constants.SLASH_COMMAND .. " " .. e.cmd
end

local function make_header(win, text, x, y)
  local l = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
  l:SetFont("ZoFontGameSmall")
  l:SetColor(0.46, 0.86, 0.58, 0.90)
  l:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  l:SetAnchor(TOPLEFT, win, TOPLEFT, x, y + 6)
  l:SetDimensions(COL_W - 8, HEAD_H - 6)
  l:SetText(text)
  return l
end

local function make_row(win, e, x, y)
  local r = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
  r:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
  r:SetDimensions(COL_W - 8, ROW_H)
  r:SetMouseEnabled(true)

  local name = WINDOW_MANAGER:CreateControl(nil, r, CT_LABEL)
  name:SetFont("ZoFontGame")
  name:SetColor(0.90, 0.90, 0.90, 1)
  name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  name:SetAnchor(LEFT, r, LEFT, 8, 0)
  name:SetAnchor(RIGHT, r, RIGHT, -96, 0)
  name:SetText(e.label)

  local hint = WINDOW_MANAGER:CreateControl(nil, r, CT_LABEL)
  hint:SetFont("ZoFontGameSmall")
  hint:SetColor(0.45, 0.50, 0.46, 0.9)
  hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  hint:SetAnchor(RIGHT, r, RIGHT, -4, 0)
  hint:SetDimensions(90, ROW_H)

  zui.handler(r, "OnMouseEnter", function(self)
    name:SetColor(0.80, 1.00, 0.86, 1)
    if ZO_Tooltips_ShowTextTooltip then ZO_Tooltips_ShowTextTooltip(self, BOTTOM, describe(e)) end
  end)
  zui.handler(r, "OnMouseExit", function()
    name:SetColor(0.90, 0.90, 0.90, 1)
    if ZO_Tooltips_HideTextTooltip then ZO_Tooltips_HideTextTooltip() end
  end)
  zui.handler(r, "OnMouseUp", function(_, _, upInside) if upInside then run(e.cmd) end end)

  return { control = r, name = name, hint = hint, action = e }
end

local function build()
  local win = WINDOW_MANAGER:CreateTopLevelWindow("VerdantDevPanel")
  local cols = math.min(COLS, math.ceil(#ACTIONS / ROWS_PER_COL))
  local body_h = 0
  local col, used = 1, 0
  local placed = {}
  for _, e in ipairs(ACTIONS) do
    local h = e.section and HEAD_H or ROW_H
    if used + h > ROWS_PER_COL * ROW_H and col < cols then col, used = col + 1, 0 end
    placed[#placed + 1] = { e = e, col = col, y = used }
    used = used + h
    if used > body_h then body_h = used end
  end

  win:SetDimensions(PAD_X * 2 + COL_W * cols, TOP_Y + body_h + FOOT_H + 8)
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 240, 140)
  win:SetClampedToScreen(true)
  win:SetMovable(true)
  win:SetMouseEnabled(true)
  win:SetHidden(true)
  zui.handler(win, "OnMoveStop", function()
    local sv = Verdant.SavedVars
    if not sv then return end
    sv.debug = sv.debug or {}
    sv.debug.devtools_x = win:GetLeft()
    sv.debug.devtools_y = win:GetTop()
  end)

  local bg = WINDOW_MANAGER:CreateControl("$(parent)Bg", win, CT_BACKDROP)
  bg:SetAnchorFill(win)
  bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 6)
  bg:SetCenterTexture("EsoUI/Art/Tooltips/UI-TooltipCenter.dds")
  bg:SetInsets(6, 6, -6, -6)
  bg:SetCenterColor(0.62, 1.00, 0.74, 1.0)
  bg:SetEdgeColor(0.42, 1.00, 0.60, 1.0)

  local title = WINDOW_MANAGER:CreateControl("$(parent)Title", win, CT_LABEL)
  title:SetFont("ZoFontWindowTitle")
  title:SetColor(0.55, 0.95, 0.68, 1)
  title:SetAnchor(TOPLEFT, win, TOPLEFT, 16, 10)
  title:SetText("Verdant Developer")

  local ver = WINDOW_MANAGER:CreateControl("$(parent)Version", win, CT_LABEL)
  ver:SetFont("ZoFontGameSmall")
  ver:SetColor(0.45, 0.50, 0.46, 0.9)
  ver:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ver:SetAnchor(TOPRIGHT, win, TOPRIGHT, -34, 12)
  ver:SetDimensions(160, 14)
  ver:SetText("DEBUG build  ·  v" .. Verdant.Constants.VERSION)

  local close = CreateControlFromVirtual("$(parent)Close", win, "ZO_CloseButton")
  close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 8)
  zui.handler(close, "OnClicked", function() M.toggle() end)

  for _, p in ipairs(placed) do
    local x = PAD_X + (p.col - 1) * COL_W
    local y = TOP_Y + p.y
    if p.e.section then
      make_header(win, p.e.section, x, y)
    else
      rows[#rows + 1] = make_row(win, p.e, x, y)
    end
  end

  local foot = WINDOW_MANAGER:CreateControl("$(parent)Foot", win, CT_LABEL)
  foot:SetFont("ZoFontGameSmall")
  foot:SetColor(0.45, 0.50, 0.46, 0.9)
  foot:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  foot:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD_X, -10)
  foot:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PAD_X, -10)
  foot:SetText("click a row to run it  ·  chat output stays in chat, reports open the copybox  ·  never ships: DEBUG only")

  controls = { window = win, title = title, foot = foot }

  local sv = Verdant.SavedVars and Verdant.SavedVars.debug
  if sv and sv.devtools_x and sv.devtools_y then
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.devtools_x, sv.devtools_y)
  end
  Scene.register_top_level(win)
end

function M.refresh()
  if not controls then return end
  for _, r in ipairs(rows) do
    local e = r.action
    if e.status then
      r.hint:SetText(status_text(e.status))
      r.hint:SetColor(0.95, 0.80, 0.20, 1)
    else
      r.hint:SetText(e.cmd)
    end
  end
end

function M.init()
  build()
  M.refresh()
end

function M.toggle()
  if not controls then build() end
  local win = controls.window
  if win:IsHidden() then
    M.refresh()
    Scene.show_top_level(win)
    win:BringWindowToTop()
    Sound.play("open")
  else
    Scene.hide_top_level(win)
    Sound.play("close")
  end
end

function M.is_open()
  return controls ~= nil and not controls.window:IsHidden()
end

function M.rows() return rows end
