Vermilion = Vermilion or {}
Vermilion.Sampler = {}
local M = Vermilion.Sampler

local api = Vermilion.zenimax.api
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local math_floor              = math.floor
local string_format           = string.format

local controls, VIS, REC
local render_current_view

function M.bind(t)
  controls, VIS, REC = t.controls, t.VIS, t.REC
  render_current_view = t.render
end

local prof_enter = Vermilion.Profiler.enter
local prof_exit  = Vermilion.Profiler.exit

local sample_eos_scratch       = { count = 0 }
local sample_eos_abilities     = { count = 0 }
local sample_dtype_groups      = { count = 0 }
local sample_dtype_abilities   = { count = 0 }

local function take_sample(now)
  local edps  = Vermilion.Metrics.eDPS(now)
  local shdps = Vermilion.Metrics.ShDPS(now)
  local crit, noncrit = Vermilion.Metrics.crit_split(now)
  Vermilion.Metrics.eos_groups_into(sample_eos_scratch, now)
  Vermilion.Metrics.eos_abilities_into(sample_eos_abilities, now)
  Vermilion.Metrics.dtype_groups_into(sample_dtype_groups, now)
  Vermilion.Metrics.dtype_abilities_into(sample_dtype_abilities, now)
  Vermilion.Metrics.shield_abilities_into(VIS.sample_shields, now)
  Vermilion.Metrics.targets_into(VIS.sample_targets, now)
  Vermilion.TemporalBuffer.push(now, edps, shdps, crit, noncrit,
                                sample_eos_scratch, sample_eos_abilities,
                                sample_dtype_groups, sample_dtype_abilities,
                                VIS.sample_shields, VIS.sample_targets)
  Vermilion.Resources.sample_into(Vermilion.TemporalBuffer.at(Vermilion.TemporalBuffer.count()))
  if not VIS.res.on and Vermilion.Resources.saw() then VIS.res.on = true end
  if REC.auto and REC.every == 1 then
    local TB = Vermilion.TemporalBuffer
    if TB.count() >= TB.capacity() and TB.halve() then REC.every = 2 end
  end
end

local function on_sample_update()
  prof_enter("graph.sample_tick")
  Vermilion.Hitch.mark("tick")
  local now   = GetGameTimeMilliseconds()
  Vermilion.Pipeline.flush_pending(now)
  REC.tick = REC.tick + 1
  local sampled = REC.tick >= REC.every
  if sampled then
    REC.tick = 0
    take_sample(now)
  end
  Vermilion.DebuffTracker.expire_stale(now)
  Vermilion.Uptime.expire_stale(now)

  local elapsed = math_floor((now - REC.start_ms) / 1000)
  if elapsed ~= REC.last_elapsed then
    REC.last_elapsed = elapsed
    local prefix = Vermilion.AutoRecord.is_auto_session() and "AUTO " or ""
    controls.status:SetText(string_format("%s%d:%02d", prefix, math_floor(elapsed / 60), elapsed % 60))
  end

  if sampled and not controls.window:IsHidden() then
    render_current_view()
  end
  prof_exit("graph.sample_tick")
end

M.tick = on_sample_update
