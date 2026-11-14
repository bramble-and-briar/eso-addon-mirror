Vermilion = Vermilion or {}
Vermilion.BackgroundCost = {}
local M = Vermilion.BackgroundCost

M.run = function() end
M.step = function() end
M.running = function() return false end

if not Vermilion.Constants.DEBUG then return end

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events

local UPDATE = "Vermilion_BackgroundCost"
local BASELINE_FRAMES = 120
local SETTLE_FRAMES = 5
local GIVE_UP_FRAMES = 600
local TEXTURE_KB = 342

local probe, active, list, index, deltas, baseline, started, frames, worst, settle, loaded_ms, rows, memory_before

local function median(values)
  table.sort(values)
  return values[math.ceil(#values / 2)] or 0
end

local function begin_texture()
  index = index + 1
  local key = list[index]
  if not key then return false end
  frames, worst, settle, loaded_ms = 0, 0, 0, nil
  started = api.GetGameTimeMilliseconds()
  probe:SetTexture(Vermilion.Skin.background_path(key))
  return true
end

local function finish()
  active = false
  zev.unregister_update(UPDATE)
  probe:SetHidden(true)
  local out = {
    string.format("baseline frame %.1f ms, background in use %s", baseline, Vermilion.Skin.background()),
    string.format("files %d KB each, %d KB all, Lua memory %+.1f KB", TEXTURE_KB, TEXTURE_KB * #list, collectgarbage("count") - memory_before),
  }
  for _, r in ipairs(rows) do out[#out + 1] = r end
  local sv = Vermilion.SavedVars
  sv.debug = sv.debug or {}
  sv.debug.background_cost = out
  Vermilion.CopyBox.show("Vermilion background cost", table.concat(out, "\n"))
end

function M.step()
  if not active then return end
  local delta = api.GetFrameDeltaMilliseconds()
  if baseline == nil then
    deltas[#deltas + 1] = delta
    if #deltas >= BASELINE_FRAMES then
      baseline = median(deltas)
      if not begin_texture() then finish() end
    end
    return
  end
  frames = frames + 1
  if delta > worst then worst = delta end
  if loaded_ms == nil and probe:IsTextureLoaded() then loaded_ms = api.GetGameTimeMilliseconds() - started end
  if loaded_ms ~= nil then settle = settle + 1 end
  if settle >= SETTLE_FRAMES or frames >= GIVE_UP_FRAMES then
    local key = list[index]
    rows[#rows + 1] = string.format("%-10s load %s ms in %d frames, worst frame %d ms, %+.1f ms over baseline",
      key, loaded_ms and tostring(loaded_ms) or "never", frames, worst, worst - baseline)
    if not begin_texture() then finish() end
  end
end

function M.running() return active == true end

function M.run()
  if active then return end
  active = true
  if not probe then
    probe = zui.WINDOW_MANAGER:CreateControl("VermilionBackgroundProbe", zc.GuiRoot, zc.CT_TEXTURE)
    probe:SetDimensions(4, 4)
    probe:SetAnchor(zc.TOPLEFT, zc.GuiRoot, zc.TOPLEFT, 0, 0)
    probe:SetAlpha(0.01)
  end
  probe:SetHidden(false)
  list = {}
  for _, b in ipairs(Vermilion.Skin.backgrounds()) do list[#list + 1] = b.key end
  index, deltas, baseline, rows = 0, {}, nil, {}
  memory_before = collectgarbage("count")
  zev.register_update(UPDATE, 0, M.step)
  d("[Vm] measuring backgrounds, a few seconds")
end
