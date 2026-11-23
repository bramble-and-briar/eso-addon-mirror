Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Sampler = {}
local M = Verdant.Sampler

local GetGameTimeMilliseconds = Verdant.zenimax.api.GetGameTimeMilliseconds
local math_floor    = math.floor
local string_format = string.format

local controls, STATE, render_current_view
local REC = { every = 1, tick = 0, auto = false }

function M.bind(t)
  controls, STATE, render_current_view = t.controls, t.STATE, t.render
end

function M.begin(every, auto)
  REC.every, REC.tick, REC.auto = every, 0, auto
end

local prof_enter = Verdant.Profiler.enter
local prof_exit  = Verdant.Profiler.exit

local sample_ehps_groups = { count = 0 }
local sample_mps_groups  = { count = 0 }
local sample_ehps_abilities = { count = 0 }
local sample_mps_abilities  = { count = 0 }

local function take_sample(now)
  local ehps = Verdant.Metrics.eHPS(now)
  local mps  = Verdant.Metrics.MPS(now)
  local crit, noncrit = Verdant.Metrics.eHPS_crit_split(now)
  Verdant.Metrics.eHPS_by_group_into(sample_ehps_groups, now)
  Verdant.Metrics.MPS_by_group_into(sample_mps_groups, now)
  Verdant.Metrics.eHPS_by_ability_into(sample_ehps_abilities, now)
  Verdant.Metrics.MPS_by_ability_into(sample_mps_abilities, now)
  local d_group = Verdant.Metrics.D_group(now)
  local ohps    = Verdant.Metrics.OHPS(now)
  Verdant.TemporalBuffer.push(now, ehps, mps, crit, noncrit,
                              sample_ehps_groups, sample_mps_groups,
                              sample_ehps_abilities, sample_mps_abilities, d_group, ohps,
                              Verdant.Metrics.RMag(now), Verdant.Metrics.RSta(now))
  Verdant.Resources.sample_into(Verdant.TemporalBuffer.at(Verdant.TemporalBuffer.count()))
  if REC.auto and REC.every == 1 then
    local TB = Verdant.TemporalBuffer
    if TB.count() >= TB.capacity() and TB.halve() then REC.every = 2 end
  end
end

local function on_sample_update()
  prof_enter("graph.sample_tick")
  Verdant.Hitch.mark("tick")
  local now = GetGameTimeMilliseconds()
  REC.tick = REC.tick + 1
  local sampled = REC.tick >= REC.every
  if sampled then
    REC.tick = 0
    take_sample(now)
  end
  Verdant.BuffTracker.expire_stale(now)
  Verdant.AutoRecord.note_bosses()

  local elapsed = math_floor((now - STATE.recording_start) / 1000)
  local prefix  = Verdant.AutoRecord.is_auto_session() and "AUTO " or ""
  controls.status:SetText(string_format("%s%d:%02d", prefix, math_floor(elapsed / 60), elapsed % 60))

  if sampled and not controls.window:IsHidden() then
    Verdant.Hitch.mark("render")
    render_current_view()
  end
  prof_exit("graph.sample_tick")
end

M.tick = on_sample_update
