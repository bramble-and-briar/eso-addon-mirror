--[[

  " ... my only aspiration is that death finds me alive "
                              — Indio Solari · Jan 17, 1949 – Jun 5, 2026

]]

Vermilion = Vermilion or {}
local Vermilion = Vermilion

local SLASH_COMMANDS          = SLASH_COMMANDS
local d                       = d
local string_format           = string.format
local string_lower            = string.lower
local string_match            = string.match
local api                     = Vermilion.zenimax.api
local GetString               = api.GetString
local GetWorldName            = api.GetWorldName

local function on_slash(input)
  local DEBUG = Vermilion.Constants.DEBUG
  input = input or ""
  local cmd = string_match(string_lower(input), "^%s*(%S+)") or ""


  if DEBUG then
    if cmd == "trace" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "start" then Vermilion.Trace.start()
      elseif sub == "stop" then Vermilion.Trace.stop()
      elseif sub == "save" then Vermilion.Trace.save(Vermilion.SavedVars)
      elseif sub == "clear" then Vermilion.Trace.clear(Vermilion.SavedVars) d("[trace] cleared")
      elseif sub == "auto" then
        local on = not Vermilion.Trace.auto_enabled(Vermilion.SavedVars)
        Vermilion.Trace.set_auto(Vermilion.SavedVars, on)
        d("[trace] auto-trace while recording: " .. (on and "ON" or "OFF"))
      else
        local ring = Vermilion.SavedVars.traces
        d("[trace] " .. Vermilion.Trace.status_line()
          .. "  auto=" .. (Vermilion.Trace.auto_enabled(Vermilion.SavedVars) and "ON" or "OFF")
          .. "  staged=" .. tostring(ring and #ring or 0)
          .. "  (subcmd: start | stop | save | clear | auto)")
      end
      return
    elseif cmd == "sound" then
      Vermilion.Sound.audition(string_match(input, "^%s*%S+%s*(.*)$"))
      return
    elseif cmd == "autorec" then
      for _, line in ipairs(Vermilion.AutoRecord.report_lines()) do d("[Vm] " .. line) end
      return
    elseif cmd == "grid" then
      local on = not Vermilion.Graph.pixel_grid()
      Vermilion.Graph.set_pixel_grid(on)
      d("[Vm] pixel grid: " .. (on and "on" or "off"))
      return
    elseif cmd == "bgcost" then
      Vermilion.BackgroundCost.run()
      return
    elseif cmd == "sessions" then
      for _, line in ipairs(Vermilion.SessionStore.report_lines()) do d("[Vm] " .. line) end
      return
    elseif cmd == "flush" then
      d("[Vm] writing SavedVariables to disk")
      Vermilion.zenimax.api.ReloadUI()
      return
    elseif cmd == "on" then
      Vermilion.Probe.set_enabled(true)
      d("[Vm] " .. GetString(VERMILION_PROBE_ON))
      return
    elseif cmd == "off" then
      Vermilion.Probe.set_enabled(false)
      d("[Vm] " .. GetString(VERMILION_PROBE_OFF))
      return
    elseif cmd == "dump" then

      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "chat" then Vermilion.Probe.dump()
      else Vermilion.CopyBox.show("Vermilion Dump", Vermilion.Probe.dump_report()) end
      return
    elseif cmd == "suspects" then

      Vermilion.CopyBox.show("Vermilion Source Audit", Vermilion.Probe.suspects_report()) ; return
    elseif cmd == "stats" then
      Vermilion.Probe.print_stats() ; return
    elseif cmd == "report" then

      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      Vermilion.Diagnostics.full_report(sub == "gc" or sub == "full") ; return
    elseif cmd == "filmtest" then
      local TB = Vermilion.TemporalBuffer
      if TB.is_recording() or VermilionGraphWindow:IsHidden() then d("[filmtest] open the window and stop recording first") return end
      local list = {}
      for m in string.gmatch(input, "(%d+)") do list[#list + 1] = tonumber(m) end
      if #list == 0 then list = { 8, 20, 30, 45, 60 } end
      Vermilion.CopyBox.show("Vermilion film test", Vermilion.FilmTest.run(list, GetGameTimeMilliseconds)) ; return
    elseif cmd == "copytest" then
      local size, got = Vermilion.Export.copy_test(tonumber(string.match(input, "(%d+)")))
      d(string.format("[copytest] sent %d, box holds %d", size, got)) ; return
    elseif cmd == "gcprobe" then

      local n = tonumber(string_match(input, "^%s*%S+%s+(%d+)")) or 1000
      Vermilion.Diagnostics.gc_probe(n) ; return
    elseif cmd == "prof" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "reset" then Vermilion.Profiler.reset(); d("[prof] reset")
      else Vermilion.Profiler.dump_to_chat() end
      return
    elseif cmd == "calib" then
      if Vermilion.Calib.run() then
        d("[Vm] measuring what each call into the game costs, a few seconds with short stalls")
      else
        d("[Vm] the calibration is already running")
      end
      return
    elseif cmd == "hitch" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "reset" then
        Vermilion.Hitch.reset()
        d("[Vm] hitch log cleared")
        return
      end
      local lines = Vermilion.Hitch.lines()
      for _, line in ipairs(lines) do d("[Vm] " .. line) end
      Vermilion.CopyBox.show("Vermilion hitch", table.concat(lines, "\n"))
      return
    elseif cmd == "log" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "flush" then
        local n = Vermilion.Log.flush()
        d("[log] flushed " .. tostring(n) .. " records to SavedVars.debug.log")
      elseif sub == "show" then
        Vermilion.Log.show_recent(20)
      elseif sub == "clear" then
        Vermilion.Log.clear(); d("[log] cleared")
      else
        local cur, cap = Vermilion.Log.size()
        d("[log] size " .. cur .. "/" .. cap .. "  (subcmd: flush | show | clear)")
      end
      return
    elseif cmd == "validate" then
      Vermilion.Validation.dump_to_chat() ; return
    elseif cmd == "copy" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "clear" then Vermilion.CopyBox.clear()
      elseif sub == "hide" then Vermilion.CopyBox.hide()
      else Vermilion.CopyBox.show("Vermilion Copy", "") end
      return
    elseif cmd == "skills" then
      Vermilion.SkillColors.print_unknown() ; return
    elseif cmd == "basic" then

      local id = tonumber(string_match(input, "^%s*%S+%s+(%d+)"))
      if id and id > 0 then
        Vermilion.SkillColors.set_override(id, "basic")
        local sv = Vermilion.SavedVars
        if sv then sv.skill_overrides = sv.skill_overrides or {} ; sv.skill_overrides[id] = "basic" end
        d("[Vm] tagged " .. id .. " -> basic (light/heavy attack)")
      else
        d("[Vm] usage: /vermilion basic <abilityId>")
      end
      return
    elseif cmd == "tag" then

      local id    = tonumber(string_match(input, "^%s*%S+%s+(%d+)"))
      local group = string_match(input, "^%s*%S+%s+%d+%s+(%S+)")
      if id and id > 0 and group and Vermilion.SkillColors.set_override(id, group) then
        local sv = Vermilion.SavedVars
        if sv then sv.skill_overrides = sv.skill_overrides or {} ; sv.skill_overrides[id] = group end
        d("[Vm] tagged " .. id .. " -> " .. group)
      else
        d("[Vm] usage: /vermilion tag <abilityId> <group>")
        d("[Vm] groups: " .. table.concat(Vermilion.SkillColors.group_names(), ", "))
      end
      return
    elseif cmd == "clear" then
      Vermilion.Probe.clear()
      Vermilion.Metrics.reset()
      Vermilion.Diagnostics.reset()
      d("[Vm] " .. GetString(VERMILION_BUFFER_CLEARED))
      return
    elseif cmd == "dev" then
      Vermilion.DevTools.toggle() ; return
    elseif cmd == "castprobe" then
      Vermilion.CopyBox.show("Vermilion Cast Probe", table.concat(Vermilion.Casts.probe_lines(), "\n"))
      return
    elseif cmd == "elog" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      local EL = Vermilion.EncounterLog
      if sub == "on" then EL.set_enabled(true)
      elseif sub == "off" then EL.set_enabled(false)
      elseif sub ~= "status" then EL.toggle() end
      d("[Vm] " .. EL.status_line())
      Vermilion.DevTools.refresh()
      return
    elseif cmd == "mark" then
      local label = string_match(input, "^%s*%S+%s+(.-)%s*$") or ""
      d("[Vm] " .. Vermilion.Trace.mark(label))
      return
    end
  end

  if cmd == "graph" then
    Vermilion.Graph.toggle() ; return
  end

  if cmd == "lib" then
    Vermilion.Library.toggle() ; return
  end

  if cmd == "help" then
    d(GetString(VERMILION_HELP_HEADER))
    d(GetString(VERMILION_HELP_GRAPH))
    d(GetString(VERMILION_HELP_LIB))
    d(GetString(VERMILION_HELP_HELP))
    return
  end

  Vermilion.Graph.toggle()
end

local function on_addon_loaded()
  local C   = Vermilion.Constants
  local Log = Vermilion.Log.for_module("bootstrap")


  local world = GetWorldName()
  local sv_defaults = { graph = {}, temporal = {}, copybox = {}, settings = {}, skill_overrides = {}, logo = {}, log_lamp = {} }
  if C.DEBUG then sv_defaults.probe = {} end
  Vermilion.SavedVars = Vermilion.zenimax.savedvars.new_account_wide(
    C.SV_TABLE, C.SV_VERSION, world, sv_defaults)


  Vermilion.SkillColors.load_persisted(Vermilion.SavedVars)
  Vermilion.Skin.load_background(Vermilion.SavedVars.settings.background)

  Log:info("savedvars opened: world=", world, "version=", C.SV_VERSION)


  if C.DEBUG then Vermilion.Probe.init() end
  Vermilion.GC.init()          -- GC pacing (ported): smooth the incremental collector
  Vermilion.Hitch.init()
  Vermilion.Pipeline.init()
  Vermilion.Ultimate.init()
  Vermilion.Resources.init()
  Vermilion.Casts.init()
  Vermilion.Restores.init()
  Vermilion.SessionStore.init()
  Vermilion.Trace.init()
  Vermilion.Logo.init()
  Vermilion.LogLamp.init()
  Vermilion.Settings.init()
  Vermilion.DevTools.init()
  Vermilion.Graph.init()
  Vermilion.AutoRecord.init()
  Vermilion.Assign.init()
  Vermilion.Library.init()
  Vermilion.About.init()
  Vermilion.Export.init()
  Vermilion.Visibility.init()

  Vermilion.slash = on_slash
  SLASH_COMMANDS[C.SLASH_COMMAND] = on_slash

  Log:info("loaded v" .. C.VERSION, "DEBUG=" .. tostring(C.DEBUG))
  d("[Vm] " .. string_format(GetString(VERMILION_LOADED), C.VERSION, C.SLASH_COMMAND))
end

Vermilion.zenimax.events.register_addon_loaded(Vermilion.Constants.ADDON_NAME, on_addon_loaded)
