Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Calib = {}
local M = Vermilion.Calib

M.run     = function() return false end
M.running = function() return false end
M.lines   = function() return {} end

if not Vermilion.Constants.DEBUG then return end

local api            = Vermilion.zenimax.api
local zui            = Vermilion.zenimax.ui
local zc             = Vermilion.zenimax.constants
local zev            = Vermilion.zenimax.events
local now            = api.GetGameTimeMilliseconds
local string_format  = string.format
local string_rep     = string.rep
local math_floor     = math.floor
local collectgarbage = collectgarbage

local UPDATE     = "VermilionCalib"
local PIECES     = 200
local LABELS     = 20
local BATCH      = 1000
local ENOUGH_MS  = 30
local MAX_CALLS  = 200000
local TEXT_KB    = { 1, 6, 36, 100 }
local TEXT_REPS  = 3
local GC_STEPS   = 2000
local POOL_N     = 3000
local POOL_REPS  = 20
local MAKE_N     = 150
local TEMPLATE   = "VermilionGraphLineTemplate"
local FILL       = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local root, edit, holder
local round = 0
local pieces, labels = {}, {}
local tests, out = {}, {}
local index, limit, active = 0, MAX_CALLS, false
local build_ms = 0

local function piece(i) return pieces[i % PIECES + 1] end
local function turn(i) return math_floor(i / PIECES) % 2 end

local function build()
  if root then
    root:SetHidden(false)
    return
  end
  local t0 = now()
  root = zui.WINDOW_MANAGER:CreateTopLevelWindow("VermilionCalibRoot")
  root:SetDimensions(420, 320)
  root:SetAnchor(zc.TOPLEFT, zc.GuiRoot, zc.TOPLEFT, 0, 0)
  root:SetAlpha(0.02)
  root:SetMouseEnabled(false)
  for i = 1, PIECES do
    local p = zui.WINDOW_MANAGER:CreateControl("VermilionCalibPiece" .. i, root, zc.CT_TEXTURE)
    p:SetTexture(FILL)
    p:SetAnchor(zc.TOPLEFT, root, zc.TOPLEFT, (i - 1) % 20 * 20, math_floor((i - 1) / 20) * 20)
    p:SetDimensions(18, 18)
    pieces[i] = p
  end
  build_ms = now() - t0
  for i = 1, LABELS do
    local l = zui.WINDOW_MANAGER:CreateControl("VermilionCalibLabel" .. i, root, zc.CT_LABEL)
    l:SetFont("ZoFontGameSmall")
    l:SetAnchor(zc.TOPLEFT, root, zc.TOPLEFT, 0, 200 + i * 5)
    l:SetDimensions(200, 14)
    labels[i] = l
  end
  edit = zui.CreateControlFromVirtual("VermilionCalibEdit", root, "ZO_DefaultEditMultiLineForBackdrop")
  edit:SetAnchor(zc.TOPLEFT, root, zc.TOPLEFT, 220, 200)
  edit:SetDimensions(190, 110)
  edit:SetMaxInputChars(500000)
  holder = zui.WINDOW_MANAGER:CreateControl("VermilionCalibHolder", root, zc.CT_CONTROL)
  holder:SetHidden(true)
end

local function nothing() end

local function add(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function define()
  if #tests > 0 then return end
  local TL = zc.TOPLEFT
  add("an empty Lua call", function(i) nothing(i) end)
  add("reading the clock", function() now() end)
  add("SetHidden, changing", function(i) piece(i):SetHidden(turn(i) == 1) end)
  add("SetHidden, same value", function(i) piece(i):SetHidden(false) end)
  add("SetColor, changing", function(i) piece(i):SetColor(0.25 + 0.5 * turn(i), 0.5, 0.5, 1) end)
  add("SetColor, same value", function(i) piece(i):SetColor(0.25, 0.5, 0.5, 1) end)
  add("ClearAnchors and SetAnchor, moving", function(i)
    local p = piece(i)
    p:ClearAnchors()
    p:SetAnchor(TL, root, TL, i % 20 * 20 + turn(i), math_floor(i % PIECES / 20) * 20)
  end)
  add("ClearAnchors and SetAnchor, same place", function(i)
    local p = piece(i)
    p:ClearAnchors()
    p:SetAnchor(TL, root, TL, i % 20 * 20, math_floor(i % PIECES / 20) * 20)
  end)
  add("SetWidth and SetHeight, changing", function(i)
    local p = piece(i)
    p:SetWidth(17 + turn(i))
    p:SetHeight(17 + turn(i))
  end)
  add("SetWidth and SetHeight, same size", function(i)
    local p = piece(i)
    p:SetWidth(18)
    p:SetHeight(18)
  end)
  add("SetDrawLevel, changing", function(i) piece(i):SetDrawLevel(2 + turn(i)) end)
  add("SetDrawLevel, same value", function(i) piece(i):SetDrawLevel(2) end)
  add("SetText on a label, changing", function(i) labels[i % LABELS + 1]:SetText((turn(i) == 1) and "12345" or "54321") end)
  add("SetText on a label, same text", function(i) labels[i % LABELS + 1]:SetText("12345") end)
  add("a rectangle put away and drawn again, changed", function(i)
    local p = piece(i)
    p:SetHidden(true)
    p:ClearAnchors()
    p:SetAnchor(TL, root, TL, i % 20 * 20 + turn(i), math_floor(i % PIECES / 20) * 20)
    p:SetWidth(17 + turn(i))
    p:SetHeight(18)
    p:SetDrawLevel(3)
    p:SetColor(0.25 + 0.5 * turn(i), 0.5, 0.5, 1)
    p:SetHidden(false)
  end)
  add("a rectangle put away and drawn again, the same", function(i)
    local p = piece(i)
    p:SetHidden(true)
    p:ClearAnchors()
    p:SetAnchor(TL, root, TL, i % 20 * 20, math_floor(i % PIECES / 20) * 20)
    p:SetWidth(18)
    p:SetHeight(18)
    p:SetDrawLevel(3)
    p:SetColor(0.25, 0.5, 0.5, 1)
    p:SetHidden(false)
  end)
end

local function measure(fn)
  local calls, t0, elapsed = 0, now(), 0
  repeat
    for i = calls + 1, calls + BATCH do fn(i) end
    calls = calls + BATCH
    elapsed = now() - t0
  until elapsed >= ENOUGH_MS or calls >= limit
  return calls, elapsed
end

local function line(name, calls, elapsed)
  if elapsed <= 0 then
    return string_format("%-50s under %.3f us   (%d calls in less than 1 ms)", name, 1000 / calls, calls)
  end
  return string_format("%-50s %9.3f us   (%d calls in %d ms)", name, elapsed * 1000 / calls, calls, elapsed)
end

local function plain() return {} end

local function pool_line(name, pool)
  for _ = 1, POOL_N do pool:AcquireObject() end
  pool:ReleaseAllObjects()
  local t0 = now()
  for _ = 1, POOL_REPS do
    for _ = 1, POOL_N do pool:AcquireObject() end
    pool:ReleaseAllObjects()
  end
  local took = now() - t0
  out[#out + 1] = string_format("%-50s %9.2f ms each   (%d in %d ms)", string_format("%s, %d pieces out and back", name, POOL_N), took / POOL_REPS, POOL_REPS, took)
end

local function fresh(kind, i) return "VermilionCalibMade" .. round .. kind .. i end

local function make_line(name, make)
  local t0 = now()
  for i = 1, MAKE_N do make(i) end
  local took = now() - t0
  out[#out + 1] = string_format("%-50s %9.3f ms each   (%d in %d ms)", name, took / MAKE_N, MAKE_N, took)
end

local function makes()
  local wm, TL = zui.WINDOW_MANAGER, zc.TOPLEFT
  make_line("a texture made with a name, nothing set", function(i) wm:CreateControl(fresh("Bare", i), root, zc.CT_TEXTURE) end)
  make_line("a texture made without a name, nothing set", function() wm:CreateControl("", root, zc.CT_TEXTURE) end)
  make_line("a texture with a name, and its texture set", function(i) wm:CreateControl(fresh("Tex", i), root, zc.CT_TEXTURE):SetTexture(FILL) end)
  make_line("a texture with a name, placed and sized", function(i)
    local c = wm:CreateControl(fresh("Placed", i), root, zc.CT_TEXTURE)
    c:SetAnchor(TL, root, TL, i, 0)
    c:SetDimensions(18, 18)
  end)
  make_line("a texture with a name under a hidden parent", function(i) wm:CreateControl(fresh("Under", i), holder, zc.CT_TEXTURE) end)
  make_line("a line made from the template", function(i) zui.CreateControlFromVirtual(fresh("Line", i), root, TEMPLATE) end)
  make_line("a label made with a name, and its font set", function(i) wm:CreateControl(fresh("Label", i), root, zc.CT_LABEL):SetFont("ZoFontGameSmall") end)
end

local function extras()
  out[#out + 1] = string_format("%-50s %9.3f ms each   (%d in %d ms)", "CreateControl of a texture, with its first anchor", build_ms / PIECES, PIECES, build_ms)
  for k = 1, #TEXT_KB do
    local text = string_rep("a line of the debug log, fifty characters long.... ", TEXT_KB[k] * 20)
    local t0 = now()
    for _ = 1, TEXT_REPS do edit:SetText(text) end
    local took = now() - t0
    out[#out + 1] = string_format("%-50s %9.2f ms each   (%d in %d ms)", string_format("edit box SetText of %d KB", TEXT_KB[k]), took / TEXT_REPS, TEXT_REPS, took)
  end
  edit:SetText("")
  local worst, t0 = 0, now()
  for _ = 1, GC_STEPS do
    local a = now()
    collectgarbage("step", 2)
    local d = now() - a
    if d > worst then worst = d end
  end
  local took = now() - t0
  out[#out + 1] = string_format("%-50s %9.3f us   worst %d ms   (%d in %d ms)", "one step of the collector, as every frame takes", took * 1000 / GC_STEPS, worst, GC_STEPS, took)
  local kb = collectgarbage("count")
  t0 = now()
  collectgarbage("collect")
  out[#out + 1] = string_format("%-50s %9d ms   (Lua held %.1f MB before, %.1f MB after)", "a full collection", now() - t0, kb / 1024, collectgarbage("count") / 1024)
  if zui.ZO_ObjectPool then
    pool_line("the game's pool", zui.ZO_ObjectPool:New(plain, nothing))
  end
  pool_line("the add-on's pool", Vermilion.lib.plot.Pool.of(plain, nothing))
  makes()
end

local function finish()
  active = false
  zev.unregister_update(UPDATE)
  root:SetHidden(true)
  Vermilion.Log.write("info", "calib", out)
  Vermilion.Log.flush()
  Vermilion.CopyBox.show("Vermilion calibration", table.concat(out, "\n"))
end

local function step()
  index = index + 1
  local t = tests[index]
  if t then
    local calls, elapsed = measure(t.fn)
    out[#out + 1] = line(t.name, calls, elapsed)
    return
  end
  extras()
  finish()
end

function M.running() return active end
function M.lines() return out end

function M.run(max_calls)
  if active then return false end
  active = true
  limit = max_calls or MAX_CALLS
  round = round + 1
  index = 0
  out = { string_format("calibration of game calls, %s, API %s", api.GetWorldName and api.GetWorldName() or "?", tostring(api.GetAPIVersion and api.GetAPIVersion() or "?")) }
  build()
  define()
  zev.register_update(UPDATE, 0, step)
  return true
end
