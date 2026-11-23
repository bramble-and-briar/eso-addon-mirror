--[[

  " ... my only aspiration is that death finds me alive "
                              — Indio Solari · Jan 17, 1949 – Jun 5, 2026

]]

Verdant = Verdant or {}
local Verdant = Verdant

local SLASH_COMMANDS          = SLASH_COMMANDS
local d                       = d
local string_format           = string.format
local string_lower            = string.lower
local string_match            = string.match
local string_gmatch           = string.gmatch
local api                     = Verdant.zenimax.api
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local GetString               = api.GetString
local GetWorldName            = api.GetWorldName

local KNOWN_FILTERS = {
  heal=true, shield=true, shield_raw=true, heal_abs=true,
  damage=true, effect=true, effect_self=true,
  cast=true, combat=true, group=true, all=true,
}

local function print_readout()
  local r = Verdant.Metrics.contribution(GetGameTimeMilliseconds())
  local denom_label, denom_val
  if r.mode == "group" then
    denom_label, denom_val = "Dgrp", r.D_group
  else
    denom_label, denom_val = "Oslf", r.O_self
  end
  d("[V] " .. string_format(GetString(VERDANT_READOUT_LINE),
    r.mode, r.eHPS, r.MPS, r.EMS, denom_label, denom_val,
    r.C_self, r.C_heal, r.C_shield))
end

local function on_slash(input)
  local DEBUG = Verdant.Constants.DEBUG
  input = input or ""
  local cmd = string_match(string_lower(input), "^%s*(%S+)") or ""

  if DEBUG then
    if cmd == "on" then
      Verdant.Probe.set_enabled(true)
      d("[V] " .. GetString(VERDANT_PROBE_ON))
      return
    elseif cmd == "off" then
      Verdant.Probe.set_enabled(false)
      d("[V] " .. GetString(VERDANT_PROBE_OFF))
      return
    elseif cmd == "filter" then
      local val = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if KNOWN_FILTERS[val] then
        Verdant.Probe.set_filter(val)
        d("[V] " .. string_format(GetString(VERDANT_FILTER_SET), val))
      else
        d("[V] " .. string_format(GetString(VERDANT_FILTER_UNKNOWN), val))
      end
      return
    elseif cmd == "metric" then
      local val = string_match(input, "^%s*%S+%s+(%S+)") or ""
      if Verdant.Mode.set(val) then
        d("[V] " .. string_format(GetString(VERDANT_METRIC_SET), val))
      else
        d("[V] " .. string_format(GetString(VERDANT_METRIC_UNKNOWN), val))
      end
      return
    elseif cmd == "readout" then
      print_readout() ; return
    elseif cmd == "dump" then
      Verdant.Probe.dump() ; return
    elseif cmd == "stats" then
      Verdant.Probe.print_stats() ; return
    elseif cmd == "context" then
      Verdant.Probe.print_context() ; return
    elseif cmd == "ping" then
      Verdant.Probe.print_ping() ; return
    elseif cmd == "tag" then
      local val = string_match(input, "^%s*%S+%s+(.+)$")
      if val then val = val:gsub("%s+$", "") end
      Verdant.Probe.set_tag(val)
      d("[V] session tag: " .. (val or "(cleared)"))
      return
    elseif cmd == "save" then
      Verdant.Probe.persist_to_savedvars(Verdant.SavedVars)
      d("[V] " .. GetString(VERDANT_DUMP_SAVED))
      return
    elseif cmd == "trace" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "start" then Verdant.Trace.start()
      elseif sub == "stop" then Verdant.Trace.stop()
      elseif sub == "save" then Verdant.Trace.save(Verdant.SavedVars)
      elseif sub == "clear" then Verdant.Trace.clear(Verdant.SavedVars) d("[trace] cleared")
      elseif sub == "auto" then
        local on = not Verdant.Trace.auto_enabled(Verdant.SavedVars)
        Verdant.Trace.set_auto(Verdant.SavedVars, on)
        d("[trace] auto-trace while recording: " .. (on and "ON" or "OFF"))
      else
        local ring = Verdant.SavedVars.traces
        d("[trace] " .. Verdant.Trace.status_line()
          .. "  auto=" .. (Verdant.Trace.auto_enabled(Verdant.SavedVars) and "ON" or "OFF")
          .. "  staged=" .. tostring(ring and #ring or 0) .. "/3"
          .. "  (subcmd: start | stop | save | clear | auto)")
      end
      return
    elseif cmd == "sound" then
      Verdant.Sound.audition(string_match(input, "^%s*%S+%s*(.*)$"))
      return
    elseif cmd == "flush" then
      d("[V] writing SavedVariables to disk")
      Verdant.zenimax.api.ReloadUI()
      return
    elseif cmd == "diag" then
      Verdant.Diagnostics.print_diag() ; return
    elseif cmd == "report" then

      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      Verdant.Diagnostics.full_report(sub == "gc" or sub == "full") ; return
    elseif cmd == "gcprobe" then

      local n = tonumber(string_match(input, "^%s*%S+%s+(%d+)")) or 1000
      Verdant.Diagnostics.gc_probe(n) ; return
    elseif cmd == "prof" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "reset" then Verdant.Profiler.reset(); d("[prof] reset")
      else Verdant.Profiler.dump_to_chat() end
      return
    elseif cmd == "log" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "flush" then
        local n = Verdant.Log.flush()
        d("[log] flushed " .. tostring(n) .. " records to SavedVars.debug.log")
      elseif sub == "show" then
        Verdant.Log.show_recent(20)
      elseif sub == "clear" then
        Verdant.Log.clear(); d("[log] cleared")
      else
        local cur, cap = Verdant.Log.size()
        d("[log] size " .. cur .. "/" .. cap .. "  (subcmd: flush | show | clear)")
      end
      return
    elseif cmd == "validate" then
      Verdant.Validation.dump_to_chat() ; return
    elseif cmd == "copy" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "clear" then Verdant.CopyBox.clear()
      elseif sub == "hide" then Verdant.CopyBox.hide()
      else Verdant.CopyBox.show("Verdant Copy", "") end
      return
    elseif cmd == "skills" then
      Verdant.SkillColors.print_unknown() ; return
    elseif cmd == "donut" then
      Verdant.DonutProbe.toggle() ; return
    elseif cmd == "tideprobe" then
      Verdant.TideProbe.toggle() ; return
    elseif cmd == "buffprobe" then
      Verdant.BuffProbe.run() ; return
    elseif cmd == "skillprobe" then
      Verdant.SkillProbe.run() ; return
    elseif cmd == "clear" then
      Verdant.Probe.clear()
      Verdant.Metrics.reset()
      Verdant.ShieldRegistry.reset()
      Verdant.Coverage.reset()
      Verdant.GroupSet.reset()
      Verdant.Diagnostics.reset()
      d("[V] " .. GetString(VERDANT_BUFFER_CLEARED))
      return
    elseif cmd == "dev" then
      Verdant.DevTools.toggle() ; return
    elseif cmd == "themes" then
      Verdant.ThemeGallery.toggle() ; return
    elseif cmd == "filmtest" then
      if Verdant.TemporalBuffer.is_recording() or not Verdant.Visibility.get("graph") then
        d("[filmtest] open the window and stop recording first")
        return
      end
      local lengths = {}
      for minutes in string_gmatch(input, "(%d+)") do lengths[#lengths + 1] = tonumber(minutes) end
      if #lengths == 0 then lengths = { 5, 16, 30 } end
      Verdant.CopyBox.show("Verdant film test", Verdant.FilmTest.run(lengths, GetGameTimeMilliseconds))
      return
    elseif cmd == "elog" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      local EL = Verdant.EncounterLog
      if sub == "on" then EL.set_enabled(true)
      elseif sub == "off" then EL.set_enabled(false)
      elseif sub ~= "status" then EL.toggle() end
      d("[V] " .. EL.status_line())
      Verdant.DevTools.refresh()
      return
    elseif cmd == "mark" then
      local label = string_match(input, "^%s*%S+%s+(.-)%s*$") or ""
      d("[V] " .. Verdant.Trace.mark(label))
      return
    end
  end

  if cmd == "graph" then
    Verdant.Graph.toggle() ; return
  end

  if cmd == "lib" then
    Verdant.Library.toggle() ; return
  end

  if cmd == "card" then
    d("[V] card " .. Verdant.Graph.card_state())
    return
  end
  if cmd == "grid" then
    local on = not Verdant.Graph.pixel_grid()
    Verdant.Graph.set_pixel_grid(on)
    d("[V] pixel grid: " .. (on and "on" or "off"))
    return
  end
  if cmd == "hitch" then
    local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
    if sub == "reset" then Verdant.Hitch.reset(); d("[V] hitch log cleared") return end
    local lines = Verdant.Hitch.lines()
    for _, line in ipairs(lines) do d("[V] " .. line) end
    Verdant.CopyBox.show("Verdant hitch", table.concat(lines, "\n"))
    return
  end

  if cmd == "errors" then
    local events = Verdant.zenimax.events
    if events.error_count() == 0 then
      d("[V] " .. GetString(VERDANT_ERRORS_NONE))
      return
    end
    for _, line in ipairs(events.error_lines()) do d("[V] " .. line) end
    return
  end

  if cmd == "help" then
    d(GetString(VERDANT_HELP_HEADER))
    d(GetString(VERDANT_HELP_TOGGLE))
    d(GetString(VERDANT_HELP_LIB))
    d(GetString(VERDANT_HELP_HITCH))
    d(GetString(VERDANT_HELP_ERRORS))
    d(GetString(VERDANT_HELP_GRID))
    d(GetString(VERDANT_HELP_CARD))
    d(GetString(VERDANT_HELP_HELP))
    return
  end

  Verdant.Graph.toggle()
end

local function on_addon_loaded()
  local C   = Verdant.Constants
  local Log = Verdant.Log.for_module("bootstrap")

  local world = GetWorldName()
  Verdant.SavedVars = Verdant.zenimax.savedvars.new_account_wide(
    C.SV_TABLE, C.SV_VERSION, world,
    { probe = {}, temporal = {}, copybox = {}, settings = {}, skill_overrides = {}, custom_groups = {}, logo = {}, assign = {}, library = {},
      buff_answers = {} })

  Verdant.SkillColors.load_persisted(Verdant.SavedVars)
  Verdant.BuffCatalog.bind(Verdant.SavedVars.buff_answers)
  Verdant.StorageReport.attach(Verdant.SavedVars)

  if Verdant.SavedVars.settings then
    Verdant.SavedVars.settings.font_scale = nil
  end
  Log:info("savedvars opened: world=", world, "version=", C.SV_VERSION)

  if C.DEBUG then Verdant.Probe.init() end
  Verdant.Trace.init()
  Verdant.SessionStore.init()
  Verdant.GC.init()            -- GC pacing (ported): smooth the incremental collector
  Verdant.Hitch.init()
  Verdant.Pipeline.init()
  Verdant.Ultimate.init()
  Verdant.Resources.init()
  Verdant.Casts.init()
  Verdant.Restores.init()
  Verdant.Logo.init()
  Verdant.LogLamp.init()
  Verdant.Settings.init()
  Verdant.DevTools.init()
  Verdant.Graph.init()
  Verdant.Watch.init()
  Verdant.BuffWatch.init()
  Verdant.AutoRecord.init()
  Verdant.Assign.init()
  Verdant.Library.init()
  Verdant.Export.init()
  Verdant.About.init()
  Verdant.Visibility.init()

  Verdant.slash = on_slash
  SLASH_COMMANDS[C.SLASH_COMMAND] = Verdant.zenimax.events.guard(C.SLASH_COMMAND, on_slash)

  Log:info("loaded v" .. C.VERSION, "DEBUG=" .. tostring(C.DEBUG))
end

Verdant.zenimax.events.register_addon_loaded(Verdant.Constants.ADDON_NAME, on_addon_loaded)
